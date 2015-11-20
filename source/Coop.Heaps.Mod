MODULE Heaps;	(** AUTHOR "pjm/Luc Bläser/U. Glavitsch (ug)"; PURPOSE "Heap management and garbage collector"; *)

(*
	This module contains lots of low-level memory manipulations, which are best
	read together with the memory management data structure documentation.

	Garbage collector using a marking stack with overflow handling,
	References:
		Jones, Lins, Garbage Collection, Section 4.2, Algorithm 4.1
		Knuth, The Art of Computer Programming, Volume 1, Section 2.3.5, Algorithm C
*)

IMPORT SYSTEM, Trace, Machine;

CONST
	Stats* = TRUE;					(* maintain statistical counters *)

	AddressSize = SIZEOF(ADDRESS);

	BlockSize* = 32;			(* power of two, <= 32 for RegisterCandidates *)
	ArrayAlignment = 8;			(* first array element of ArrayBlock and first data element of SystemBlock must be aligned to 0 MOD ArrayAlignment *)
	BlockHeaderSize* = 2 * AddressSize;
	HeapBlockOffset* = - 2 * AddressSize;
	TypeDescOffset* = - AddressSize;

	ProtTypeBit* = 31;			(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)

	FlagsOfs = AddressSize * 3;			(* flags offset in TypeDesc *)
	ModOfs* = AddressSize * 4;			(* moduleAdr offset in TypeDesc *)

	MinPtrOfs = -40000000H;	(* sentinel offset for ptrOfs *)
	MethodEndMarker* = MinPtrOfs;   (* marks the end of the method addresses, used in Info.ModuleDetails *)

	NilVal* = 0;

	NumPriorities* = 6;

TYPE
	RootObject* = OBJECT	(* ref. Linker0 *)
		VAR nextRoot: RootObject;	(* for linking root objects during GC *)
		PROCEDURE FindRoots*;	(** abstract *)
		BEGIN HALT(301) END FindRoots;
	END RootObject;

	ProcessLink* = OBJECT (RootObject)
		VAR next*, prev*: ProcessLink
	END ProcessLink;

	ProcessQueue* = RECORD
		head*, tail*: ProcessLink
	END;

	Finalizer* = PROCEDURE {DELEGATE} (obj: ANY);

	FinalizerNode* = POINTER TO RECORD
		objWeak* (*{UNTRACED}*): ANY;	(* weak reference to checked object *)
		nextFin: FinalizerNode;			(* in finalization list *)
		objStrong*: ANY;				(* strong reference to object to be finalized *)
		finalizer* (*{UNTRACED}*) : Finalizer;(* finalizer, if any. Untraced for the case that a finalizer points to objWeak *)
		finalizerStrong: Finalizer; 		(* strong reference to the object that is referenced by the finalizer, if any *)
	END;

	HeapBlock* = POINTER TO HeapBlockDesc;	(* base object of all heap blocks *)
	HeapBlockDesc* = RECORD
		mark: LONGINT;
		dataAdr-: ADDRESS;
		size-: SIZE;
		nextRealtime: HeapBlock;
	END;

	FreeBlock* = POINTER TO FreeBlockDesc;
	FreeBlockDesc* = RECORD (HeapBlockDesc)
		next: FreeBlock;
	END;

	SystemBlock* = POINTER TO SystemBlockDesc;
	SystemBlockDesc = RECORD  (HeapBlockDesc)
	END;

	RecordBlock* = POINTER TO RecordBlockDesc;
	RecordBlockDesc = RECORD  (HeapBlockDesc)
	END;

	ProtRecBlock* = POINTER TO ProtRecBlockDesc;
	ProtRecBlockDesc* = RECORD  (RecordBlockDesc)
		count*: LONGINT;
		locked*: BOOLEAN;
		awaitingLock*, awaitingCond*: ProcessQueue;
		lockedBy*: ANY;
		lock*: ANY;	(* used by Win32, unused for I386 *)
		waitingPriorities*: ARRAY NumPriorities OF LONGINT;
	END;

	ArrayBlock* = POINTER TO ArrayBlockDesc;
	ArrayBlockDesc = RECORD  (HeapBlockDesc)
	END;

	StaticTypeBlock*= POINTER TO StaticTypeDesc;
	StaticTypeDesc = RECORD
		recSize: SIZE;
		pointerOffsets* {UNTRACED}: PointerOffsets;
	END;

	PointerOffsets = POINTER TO ARRAY OF SIZE;

CONST
	MaxFreeLists = 14;
	FreeListBarrier = 7;
TYPE
	FreeList= RECORD minSize: SIZE; first {UNTRACED}, last{UNTRACED}: FreeBlock END;
	FreeLists = ARRAY MaxFreeLists+1 OF FreeList;
VAR
	GC*: PROCEDURE;	(** activate the garbage collector *)
	realtimeList {UNTRACED}: HeapBlock; (* list of realtime objects - tracing does not harm but is unnecessary *)
	checkRoot: FinalizerNode;	(* list of checked objects (contains weak references to the checked objects) *)
	finalizeRoot: FinalizerNode;	(* objects scheduled for finalization (contains references to scheduled objects) *)

	freeBlockTag, systemBlockTag, recordBlockTag, protRecBlockTag, arrayBlockTag: ADDRESS;  (* same values of type ADDRESS *)

	(** Statistics. Will only be maintained if Stats = TRUE *)

	(** Memory allocation statistics *)
	Nnew- : LONGINT;			(** Number of times NewBlock has been called since system startup *)
	NnewBytes- : HUGEINT;		(** Number of bytes allocated by NewBlock since system startup *)

	(** Garbage collection statistics *)
	Ngc- : LONGINT; 			(** Number of GC cycles since system startup *)

	(** Statistics considering the last GC cyle *)
	Nmark-, Nmarked-, NfinalizeAlive-, NfinalizeDead-: LONGINT;
	NgcCyclesMark-, NgcCyclesLastRun-, NgcCyclesMax-, NgcCyclesAllRuns- : HUGEINT;

	freeBlockFound-, freeBlockNotFound-: LONGINT;

	allocationLogger-: PROCEDURE(p: ANY);

(* for low level debugging of allocation -- beware: errors or traps in allocation logger can produce catastrophy - loggers may not allocate memory  *)
PROCEDURE SetAllocationLogger*(a: PROCEDURE (p:ANY));
BEGIN
	allocationLogger := a
END SetAllocationLogger;

(** Mark - Mark an object and its decendents. Used by findRoots. *)
PROCEDURE Mark* EXTERN "GarbageCollector.Mark" (p: ANY);

(* CheckCandidates - Check which candidates could be pointers, and mark them. (exported for debugging only) *)
PROCEDURE CheckCandidates*;
END CheckCandidates;

(** Return the next scheduled finalizer or NIL if none available. Called by finalizer object in Kernel. *)
PROCEDURE GetFinalizer* (): FinalizerNode;
VAR n: FinalizerNode;
BEGIN
	n := NIL;
	IF finalizeRoot # NIL THEN
		Machine.Acquire(Machine.Heaps);
		n := finalizeRoot;	(* take one finalizer *)
		IF n # NIL THEN
			finalizeRoot := n.nextFin; n.nextFin := NIL;
			IF Stats THEN DEC(NfinalizeDead) END;
		END;
		Machine.Release(Machine.Heaps);
	END;
	RETURN n
END GetFinalizer;

(** Check finalizers registered in the specified module, which is about to be freed or shut down. Remove all finalizer procedures in this module from the finalizer lists so they won't be called any more. *)
PROCEDURE CleanupModuleFinalizers*(codeAdr: ADDRESS; codeLen: SIZE; CONST name: ARRAY OF CHAR);
VAR n, p, t: FinalizerNode; codeEnd: ADDRESS; N1, N2: LONGINT;
BEGIN
	codeEnd := codeAdr + codeLen; N1 := 0; N2 := 0;
	Machine.Acquire(Machine.Heaps);
	n := checkRoot;
	WHILE n # NIL DO	(* iterate over checked list *)
		t := n; n := n.nextFin;
		IF (codeAdr <= SYSTEM.VAL (ADDRESS, t.finalizer)) & (SYSTEM.VAL (ADDRESS, t.finalizer) <= codeEnd) THEN
			IF t = checkRoot THEN checkRoot := t.nextFin ELSE p.nextFin := t.nextFin END;	(* remove from list *)
			IF Stats THEN DEC(NfinalizeAlive) END;
			INC(N1)
		ELSE
			p := t
		END
	END;
	(* also remove finalizers from list, so they won't be called *)
	n := finalizeRoot;
	WHILE n # NIL DO	(* iterate over finalized list *)
		t := n; n := n.nextFin;
		IF (codeAdr <= SYSTEM.VAL (ADDRESS, t.finalizer)) & (SYSTEM.VAL (ADDRESS, t.finalizer) <= codeEnd) THEN
			IF t = finalizeRoot THEN finalizeRoot := t.nextFin ELSE p.nextFin := t.nextFin END;	(* remove from list *)
			IF Stats THEN DEC(NfinalizeDead) END;
			INC(N2)
		ELSE
			p := t
		END
	END;
	Machine.Release(Machine.Heaps);
	IF (N1 # 0) OR (N2 # 0) THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String(name); Trace.Char(" ");
		Trace.Int(N1, 1); Trace.String(" discarded finalizers, ");
		Trace.Int(N2, 1); Trace.StringLn (" pending finalizers");
		Machine.Release (Machine.TraceOutput);
	END
END CleanupModuleFinalizers;

PROCEDURE InvokeGC*;
PROCEDURE Collect EXTERN "GarbageCollector.Collect";
BEGIN Collect;
END InvokeGC;

PROCEDURE LazySweepGC*;
VAR p {UNTRACED}: FreeBlock;
BEGIN
	GC;
END LazySweepGC;

(* initialize a free heap block *)
PROCEDURE InitFreeBlock(freeBlock: FreeBlock; mark: LONGINT; dataAdr: ADDRESS; size: SIZE);
VAR freeBlockAdr: ADDRESS;
BEGIN
	freeBlock.mark := mark;
	freeBlock.dataAdr := dataAdr;
	freeBlock.size := size;
	freeBlock.next := NIL;
	(* initialize heap block header *)
	freeBlockAdr := freeBlock;
	SYSTEM.PUT(freeBlockAdr + TypeDescOffset, freeBlockTag);
	SYSTEM.PUT(freeBlockAdr + HeapBlockOffset, NilVal)
END InitFreeBlock;

PROCEDURE NewBlock EXTERN "Runtime.New" (size: SIZE): ADDRESS;

(** NewSys - Implementation of SYSTEM.NEW. *)
PROCEDURE NewSys*(VAR p: ANY; size: SIZE; isRealtime: BOOLEAN);
VAR blockSize, systemBlockSize: SIZE; systemBlockAdr, dataBlockAdr: ADDRESS;
	systemBlock {UNTRACED}: SystemBlock; pc: ADDRESS;
BEGIN
	systemBlockSize := BlockHeaderSize + SIZEOF(SystemBlockDesc);
	INC(systemBlockSize, (-systemBlockSize) MOD ArrayAlignment); (* round up to multiple of ArrayAlignment to ensure alignment of first data element to 0 MOD ArrayAlignment *)
	blockSize := systemBlockSize + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize);  (* round up to multiple of BlockSize *)

	systemBlockAdr:= NewBlock(blockSize);
	IF systemBlockAdr # 0 THEN
		INC (systemBlockAdr, BlockHeaderSize);
		SYSTEM.PUT(systemBlockAdr + TypeDescOffset, systemBlockTag);
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
		SYSTEM.PUT(systemBlockAdr + HeapBlockOffset,pc);
		dataBlockAdr := systemBlockAdr + systemBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
		SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);		(* no type descriptor *)
		SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, systemBlockAdr);
		systemBlock := SYSTEM.VAL(SystemBlock, systemBlockAdr);
		systemBlock.dataAdr := dataBlockAdr;
		systemBlock.size := blockSize;
		IF isRealtime THEN
			systemBlock.nextRealtime := realtimeList;
			realtimeList := systemBlock
		ELSE
			systemBlock.nextRealtime := NIL
		END;
		p := SYSTEM.VAL(ANY, dataBlockAdr);
		(* clear could be done outside lock because SysBlks are not traced, but for conformity it is done inside the lock *)
		Machine.Fill32(dataBlockAdr, blockSize - systemBlockSize - BlockHeaderSize, 0);	(* clear everything from dataBlockAdr until end of block *)
	ELSE
		p := NIL
	END;
END NewSys;

PROCEDURE SetPC(p: ANY; pc: ADDRESS);
VAR blockAdr: ADDRESS;
BEGIN
	IF p # NIL THEN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, p)+HeapBlockOffset,blockAdr);
		SYSTEM.PUT(blockAdr+HeapBlockOffset, pc);
	END;
END SetPC;

(** NewRec - Implementation of NEW with a record. *)
PROCEDURE NewRec*(VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
VAR flags: SET; size, blockSize: SIZE; typeInfoAdr, recordBlockAdr, dataBlockAdr : ADDRESS;
	recordBlock {UNTRACED}: RecordBlock; pc: ADDRESS;
BEGIN
	SYSTEM.GET (tag - AddressSize, typeInfoAdr);
	SYSTEM.GET (typeInfoAdr + FlagsOfs, flags);
	IF ProtTypeBit IN flags THEN
		NewProtRec(p, tag, isRealtime);
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS), pc);
		SetPC(p,pc);
	ELSE
		SYSTEM.GET(tag, size);
		(* the block size is the sum of the size of the RecordBlock and the DataBlock.
		    Two extra fields per subblock contain the tag and the reference to the heap block *)
		blockSize := BlockHeaderSize + SIZEOF(RecordBlockDesc) + BlockHeaderSize + size;
		INC(blockSize, (-blockSize) MOD BlockSize); 	(* round up to multiple of BlockSize *)

		recordBlockAdr := NewBlock(blockSize);
		IF recordBlockAdr # 0 THEN
			INC (recordBlockAdr, BlockHeaderSize);
			SYSTEM.PUT(recordBlockAdr + TypeDescOffset, recordBlockTag);
			SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
			SYSTEM.PUT(recordBlockAdr + HeapBlockOffset,pc);
			dataBlockAdr := recordBlockAdr + SIZEOF(RecordBlockDesc) + BlockHeaderSize;
			SYSTEM.PUT(dataBlockAdr + TypeDescOffset, tag);
			SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, recordBlockAdr);
			recordBlock := SYSTEM.VAL(RecordBlock, recordBlockAdr);
			(* recordBlock.next and recordBlock.prev already set to NIL by NewBlock *)
			recordBlock.dataAdr := dataBlockAdr;
			recordBlock.size := blockSize;
			IF isRealtime THEN
				recordBlock.nextRealtime := realtimeList;
				realtimeList := recordBlock
			ELSE
				recordBlock.nextRealtime := NIL
			END;

			p := SYSTEM.VAL(ANY, dataBlockAdr);

			(* clear must be done inside lock to ensure all traced pointer fields are initialized to NIL *)
			Machine.Fill32(dataBlockAdr, blockSize - SIZEOF(RecordBlockDesc) - 2 * BlockHeaderSize, 0);	(* clear everything from dataBlockAdr until end of block *)
		ELSE
			p := NIL
		END;
	END;
END NewRec;

(** NewProtRec - Implementation of NEW with a protected record. *)
PROCEDURE NewProtRec*(VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
VAR size, blockSize: SIZE; protRecBlockAdr, dataBlockAdr: ADDRESS;
	protRecBlock {UNTRACED}: ProtRecBlock; i: LONGINT; pc: ADDRESS;
BEGIN
	SYSTEM.GET(tag, size);
	blockSize := BlockHeaderSize + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize); (* round up to multiple of BlockSize *)

	protRecBlockAdr := NewBlock(blockSize);
	IF protRecBlockAdr # 0 THEN
		INC (protRecBlockAdr, BlockHeaderSize);
		SYSTEM.PUT(protRecBlockAdr + TypeDescOffset, protRecBlockTag);
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
		SYSTEM.PUT(protRecBlockAdr + HeapBlockOffset,pc);
		dataBlockAdr := protRecBlockAdr + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize;
		SYSTEM.PUT(dataBlockAdr + TypeDescOffset, tag);
		SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, protRecBlockAdr);
		protRecBlock := SYSTEM.VAL(ProtRecBlock, protRecBlockAdr);
		protRecBlock.dataAdr := dataBlockAdr;
		protRecBlock.size := blockSize;
		IF isRealtime THEN
			protRecBlock.nextRealtime := realtimeList;
			realtimeList := protRecBlock
		ELSE
			protRecBlock.nextRealtime := NIL
		END;
		protRecBlock.count := 0;
		protRecBlock.awaitingLock.head := NIL;
		protRecBlock.awaitingLock.tail := NIL;
		protRecBlock.awaitingCond.head := NIL;
		protRecBlock.awaitingCond.tail := NIL;
		protRecBlock.lockedBy := NIL;
		protRecBlock.lock := NIL;
		FOR i := 0 TO NumPriorities - 1 DO
			protRecBlock.waitingPriorities[i] := 0
		END;
		INC(protRecBlock.waitingPriorities[0]);	(* set sentinel value: assume that idle process with priority 0 waits on this resource *)
		p := SYSTEM.VAL(ANY, dataBlockAdr);

		(* clear must be done inside lock to ensure all traced pointer fields are initialized to NIL *)
		Machine.Fill32(dataBlockAdr, blockSize - SIZEOF(ProtRecBlockDesc) - 2 * BlockHeaderSize, 0);	(* clear everything from dataBlockAdr to end of block *)
	ELSE
		p := NIL
	END;
END NewProtRec;


(** NewArr - Implementation of NEW with an array containing pointers. *)
PROCEDURE NewArr*(VAR p: ANY; elemTag: ADDRESS; numElems, numDims: SIZE; isRealtime: BOOLEAN);
VAR arrayBlockAdr, dataBlockAdr: ADDRESS; arrayBlock {UNTRACED}: ArrayBlock;
	elemSize, arrSize, blockSize, arrayBlockSize, fillSize, size, ptrOfs, arrayDataOffset: SIZE;
	firstElem: ADDRESS; pc: ADDRESS;
BEGIN
	SYSTEM.GET(elemTag, elemSize);
	arrSize := numElems * elemSize;
	IF arrSize = 0 THEN
		NewSys(p, numDims * AddressSize + 3 * AddressSize, isRealtime); (* no data, thus no specific alignment *)
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS), pc);
		SetPC(p,pc);
	ELSE
		ASSERT(BlockHeaderSize MOD ArrayAlignment = 0);
		arrayDataOffset := numDims * AddressSize + 3 * AddressSize;
		INC(arrayDataOffset, (-arrayDataOffset) MOD ArrayAlignment);  (* round up to multiple of ArrayAlignment to ensure that first array element is aligned at 0 MOD ArrayAlignment *)
		SYSTEM.GET(elemTag + AddressSize, ptrOfs);
		IF ptrOfs = MinPtrOfs - AddressSize THEN (* no pointers in element type *)
			size := arrayDataOffset + arrSize;
			NewSys(p, size, isRealtime);
			SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS), pc);
			SetPC(p, pc);
		ELSE
			arrayBlockSize := BlockHeaderSize + SIZEOF(ArrayBlockDesc);
			INC(arrayBlockSize, (-arrayBlockSize) MOD ArrayAlignment); (* do. *)
			blockSize := arrayBlockSize + BlockHeaderSize + (arrayDataOffset + arrSize);
			INC(blockSize, (-blockSize) MOD BlockSize); (* round up to multiple of BlockSize *)
			arrayBlockAdr := NewBlock(blockSize);
			IF arrayBlockAdr # 0 THEN
				INC (arrayBlockAdr, BlockHeaderSize);
				SYSTEM.PUT(arrayBlockAdr + TypeDescOffset, arrayBlockTag);
				SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
				SYSTEM.PUT(arrayBlockAdr + HeapBlockOffset,pc);
				dataBlockAdr := arrayBlockAdr + arrayBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
				SYSTEM.PUT(dataBlockAdr + TypeDescOffset, elemTag);
				SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, arrayBlockAdr);
				arrayBlock := SYSTEM.VAL(ArrayBlock, arrayBlockAdr);
				arrayBlock.dataAdr := dataBlockAdr;
				arrayBlock.size := blockSize;
				IF isRealtime THEN
					arrayBlock.nextRealtime := realtimeList;
					realtimeList := arrayBlock
				ELSE
					arrayBlock.nextRealtime := NIL
				END;

				(* clear data part of array here, since size parameter of Machine.Fill32 must be a multiple of 4. Some fields of the data part are filled below for GC. , *)
				fillSize := blockSize - arrayBlockSize - BlockHeaderSize;
				Machine.Fill32(dataBlockAdr, fillSize, 0); 	(* clear everything from dataBlockAdr until end of block *)

				firstElem := dataBlockAdr + arrayDataOffset;
				SYSTEM.PUT(dataBlockAdr, firstElem + arrSize - elemSize); 	(* lastElem *)
				SYSTEM.PUT(dataBlockAdr + AddressSize, NIL);
				SYSTEM.PUT(dataBlockAdr + 2 * AddressSize, firstElem); 		(* firstElem *)

				p := SYSTEM.VAL(ANY, dataBlockAdr);
			ELSE
				p := NIL
			END;
		END
	END
END NewArr;

PROCEDURE FillStaticType*(VAR staticTypeAddr: ADDRESS; startAddr, typeInfoAdr: ADDRESS; size, recSize: SIZE;
							numPtrs, numSlots: LONGINT);
VAR p, offset: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock;
BEGIN
	Machine.Acquire(Machine.Heaps);

	Machine.Fill32(startAddr, size, 0);	(* clear whole static type, size MOD AddressSize = 0 implicitly, see WriteType in PCOF.Mod *)
	SYSTEM.PUT(startAddr, MethodEndMarker);	(* sentinel *)

	(* methods and tags filled in later *)

	offset := AddressSize * (numSlots + 1 + 1);  (* #methods, max. no. of tags, method end marker (sentinel), pointer to type information*)
	p := startAddr + offset;
	SYSTEM.PUT(p + TypeDescOffset, typeInfoAdr); 	(* pointer to typeInfo *)
	staticTypeBlock := SYSTEM.VAL(StaticTypeBlock, p);
	staticTypeBlock.recSize := recSize;
	staticTypeAddr := p;

	(* create the pointer for the dynamic array of pointer offsets, the dynamic array of pointer offsets is stored in the static type
	    descriptor, it has no header part *)
	INC(p, SIZEOF(StaticTypeDesc));
	IF p MOD (2 * AddressSize) # 0 THEN INC(p, AddressSize) END;
	SYSTEM.PUT(p + 3 * AddressSize, numPtrs); (* internal structure of dynamic array without pointers: the first 3 fields are unused *)
	staticTypeBlock.pointerOffsets := SYSTEM.VAL(PointerOffsets, p); (* the fourth field contains the dimension of the array *)

	(* pointer offsets  filled in later *)

	Machine.Release(Machine.Heaps)
END FillStaticType;

PROCEDURE AddFinalizer*(obj: ANY; n: FinalizerNode);
BEGIN
	n.objWeak := obj; n.objStrong := NIL; n.finalizerStrong := NIL;
	Machine.Acquire(Machine.Heaps);
	n.nextFin := checkRoot; checkRoot := n;
	IF Stats THEN INC(NfinalizeAlive) END;
	Machine.Release(Machine.Heaps)
END AddFinalizer;

(** Compute total heap size, free space and largest free block size in bytes. This is a slow operation. *)
PROCEDURE GetHeapInfo*(VAR total, free, largest: SIZE);
BEGIN
	total := 0; free := 0; largest := 0;
END GetHeapInfo;

(* Init - Initialize the heap. *)
PROCEDURE Init;
BEGIN
	checkRoot := NIL; finalizeRoot := NIL; realtimeList := NIL;

	(* the Type desciptor is generated by the compiler, therefore the linker does not have ot patch anything any more *)
	freeBlockTag := SYSTEM.TYPECODE (FreeBlockDesc);
	systemBlockTag := SYSTEM.TYPECODE (SystemBlockDesc);
	recordBlockTag := SYSTEM.TYPECODE (RecordBlockDesc);
	protRecBlockTag := SYSTEM.TYPECODE (ProtRecBlockDesc);
	arrayBlockTag := SYSTEM.TYPECODE (ArrayBlockDesc);

END Init;

BEGIN
	Init;
END Heaps.


(*
TraceHeap:
0	1	NR NEW record
1	2	NA/NV NEW array
2	4	NS SYSTEM.NEW
3	8	DR deallocate record #
4	16	DA deallocate array #
5	32	DS deallocate sysblk #
6	64	NT NewType
7	128
8	256	FB show free blocks #
9	512	DP deallocate protrec #
10	1024	finalizers
11	2048	live/dead #
12 4096 trace mark stack overflows #

# influences timing
*)

(*
20.03.1998	pjm	Started
17.08.1998	pjm	FindRoots method
18.08.1998	pjm	findPossibleRoots removed, use FindRoots method
09.10.1998	pjm	NewRec with page alignment
21.01.1999	pjm	Mark adapted for AosBuffers
26.01.1999	pjm	Incorporated changes for new compiler
10.11.2000	pjm	Finalizers
26.01.2001	pjm	Removed trapReserve, reimplemented NewBlock
11.11.2004	lb	   Garbage collector with marking stack
19.06.2007	ug	Garbage collector using meta data for stack inspection (cf. Objects)
11.07.2008 	ug	new heap data structures and adaption to GC
*)
