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
	DebugValue = LONGINT(0DEADDEADH);	(* set non-0 to clear free storage to this value *)

	Stats* = TRUE;					(* maintain statistical counters *)

	AddressSize = SIZEOF(ADDRESS);

	MaxTries = 16;				(* max number of times to try and allocate memory, before trapping *)
	Unmarked = -1;				(* mark value of free blocks *)
	BlockSize* = 32;			(* power of two, <= 32 for RegisterCandidates *)
	ArrayAlignment = 8;			(* first array element of ArrayBlock and first data element of SystemBlock must be aligned to 0 MOD ArrayAlignment *)
	BlockHeaderSize* = 2 * AddressSize;
	HeapBlockOffset* = - 2 * AddressSize;
	TypeDescOffset* = - AddressSize;

	MaxCandidates = 1024;

	MarkStackSize = 1024;		(* maximum stack size for temporary marking *)

	ProtTypeBit* = 31;			(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)

	FlagsOfs = AddressSize * 3;			(* flags offset in TypeDesc *)
	ModOfs* = AddressSize * 4;			(* moduleAdr offset in TypeDesc *)
	TypeNameOfs = AddressSize * 5;		(* type name offset in TypeDesc *)
	ModNameOfs = AddressSize * 2;		(* module name offset in ModuleDesc *)

	MinPtrOfs = -40000000H;	(* sentinel offset for ptrOfs *)
	MethodEndMarker* = MinPtrOfs;   (* marks the end of the method addresses, used in Info.ModuleDetails *)

	NilVal* = 0;

	NumPriorities* = 6;

	HeuristicStackInspectionGC* = 0;
	MetaDataForStackGC* = 1;

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
		objWeak* {UNTRACED}: ANY;	(* weak reference to checked object *)
		nextFin: FinalizerNode;			(* in finalization list *)
		objStrong*: ANY;				(* strong reference to object to be finalized *)
		finalizer* {UNTRACED} : Finalizer;(* finalizer, if any. Untraced for the case that a finalizer points to objWeak *)
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

TYPE
	GCStatus* = OBJECT
		(* the following procedures are overridden in Objects.GCStatusExt. The reason is that shared objects can only be implemented in modules Objects or higher *)

		PROCEDURE SetgcOngoing*(value: BOOLEAN);
		BEGIN
			HALT(2000);
		END SetgcOngoing;

		PROCEDURE  GetgcOngoing*(): BOOLEAN;
		BEGIN
			HALT(2001); RETURN FALSE
		END GetgcOngoing;

		PROCEDURE WaitForGCEnd*;
		BEGIN
			HALT(2002)
		END WaitForGCEnd;

	END GCStatus;

CONST
	MaxFreeLists = 20;
	FreeListBarrier = 7;
TYPE
	FreeList= RECORD minSize: SIZE; first {UNTRACED}, last{UNTRACED}: FreeBlock END;
	FreeLists = ARRAY MaxFreeLists+1 OF FreeList;
VAR
	freeLists: FreeLists;
	GC*: PROCEDURE;	(** activate the garbage collector *)
	initBlock: ANY;	(* anchor for init calls *)
	markStack: ARRAY MarkStackSize OF ADDRESS; (* temporary marking stack *)
	lowestForgotten: ADDRESS; (* lowest forgotten block due to mark stack overflow *)
	markStackHeight: LONGINT; (* current free position in mark stack *)
	currentMarkValue: LONGINT; (* all objects that have this value in their mark field are still used - initial value filled in by linker *)
	sweepMarkValue: LONGINT; (* most recent mark value *)
	sweepBlockAdr: ADDRESS;	(* where to resume sweeping *)
	sweepMemBlock {UNTRACED}: Machine.MemoryBlock; (* where to resume sweeping *)
	candidates: ARRAY MaxCandidates OF ADDRESS; (* procedure stack pointer candidates *)
	numCandidates: LONGINT;
	rootList {UNTRACED}: RootObject;	(* list of root objects during GC - tracing does not harm but is unnecessary *)
	realtimeList {UNTRACED}: HeapBlock; (* list of realtime objects - tracing does not harm but is unnecessary *)
	newSum: SIZE;
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

	gcStatus*: GCStatus;

	GCType*: LONGINT;
	freeBlockFound-, freeBlockNotFound-: LONGINT;
	EnableFreeLists, EnableReturnBlocks, trace-: BOOLEAN;

	allocationLogger-: PROCEDURE(p: ANY);

(* for low level debugging of allocation -- beware: errors or traps in allocation logger can produce catastrophy - loggers may not allocate memory  *)
PROCEDURE SetAllocationLogger*(a: PROCEDURE (p:ANY));
BEGIN
	allocationLogger := a
END SetAllocationLogger;

(* check validity of p *)
PROCEDURE CheckPointer(p: ADDRESS): BOOLEAN;
VAR ret: BOOLEAN; heapBlockAdr, tdAdr: ADDRESS;
BEGIN
	ret := FALSE;
	IF Machine.ValidHeapAddress(p)THEN
		SYSTEM.GET(p + HeapBlockOffset, heapBlockAdr);
		IF Machine.ValidHeapAddress(heapBlockAdr + TypeDescOffset) THEN
			SYSTEM.GET(heapBlockAdr + TypeDescOffset, tdAdr);
			IF (tdAdr = systemBlockTag) OR (tdAdr = recordBlockTag) OR (tdAdr = protRecBlockTag) OR (tdAdr = arrayBlockTag) THEN
				ret := TRUE
			END
		END
	END;
	RETURN ret
END CheckPointer;

PROCEDURE Inspect(blockAdr: ADDRESS);
VAR adr: ADDRESS; heapBlock {UNTRACED}: HeapBlock; rootObj: RootObject; staticTypeBlock {UNTRACED}: StaticTypeBlock;
	block {UNTRACED}: ANY;
BEGIN
	(* ug: check for validity of block is necessary since users may assign values to pointer variables that are not real heap blocks, e.g. by using SYSTEM.VAL or ADDRESSOF *)
	IF (blockAdr = NilVal) OR ~CheckPointer(blockAdr) THEN RETURN END;
	SYSTEM.GET(blockAdr + HeapBlockOffset, heapBlock);
	IF (heapBlock = NIL) OR (heapBlock.mark >= currentMarkValue) THEN RETURN END;

	block := SYSTEM.VAL(ANY, blockAdr);
	heapBlock.mark := currentMarkValue;
	IF Stats THEN INC(Nmarked) END;
	IF (heapBlock IS RecordBlock) OR (heapBlock IS ProtRecBlock) OR (heapBlock IS ArrayBlock) THEN
		IF block IS RootObject THEN
			rootObj := SYSTEM.VAL(RootObject, block);
			rootObj.nextRoot := rootList; rootList := rootObj;	(* link root list *)
		END;
		SYSTEM.GET(blockAdr + TypeDescOffset, staticTypeBlock);
		IF (LEN(staticTypeBlock.pointerOffsets) > 0) OR (heapBlock IS ProtRecBlock) THEN (* not atomic or heapBlock is ProtRecBlock containing awaiting queues *)
			IF markStackHeight # MarkStackSize THEN
				markStack[markStackHeight] := blockAdr; INC(markStackHeight);
			ELSE (* overflow *)
				adr := SYSTEM.VAL(ADDRESS, heapBlock) - BlockHeaderSize; (* lowestForgotten points to block start *)
				IF adr < lowestForgotten THEN lowestForgotten := adr END
			END
		END
	END
END Inspect;

(** Mark - Mark an object and its decendents. Used by findRoots. *)
PROCEDURE Mark*(p: ANY);
VAR orgBlock, block: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock;
	orgHeapBlock {UNTRACED}: HeapBlock;
	currentArrayElemAdr, lastArrayElemAdr: ADDRESS; i: LONGINT;
BEGIN
	IF Stats THEN INC(Nmark) END;
	markStackHeight := 0; 	(* clear mark stack *)
	lowestForgotten := Machine.memBlockTail.endBlockAdr; 	(* sentinel: no overflow has happened *)
	block := p;
	Inspect(block);
	LOOP
		WHILE markStackHeight # 0 DO
			DEC(markStackHeight);
			orgBlock := markStack[markStackHeight];
			SYSTEM.GET(orgBlock + HeapBlockOffset, orgHeapBlock);
			IF orgHeapBlock # NIL THEN
				SYSTEM.GET(orgBlock + TypeDescOffset, staticTypeBlock);
				IF ~(orgHeapBlock IS ArrayBlock) THEN
					FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
						SYSTEM.GET(orgBlock + staticTypeBlock.pointerOffsets[i], block);
						Inspect(block)
					END
				ELSE
					SYSTEM.GET(orgBlock + 2 * AddressSize, currentArrayElemAdr);
					SYSTEM.GET(orgBlock, lastArrayElemAdr);
					IF currentArrayElemAdr > lastArrayElemAdr THEN HALT(100) END;
					WHILE currentArrayElemAdr <= lastArrayElemAdr DO
						FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
							SYSTEM.GET(currentArrayElemAdr + staticTypeBlock.pointerOffsets[i], block);
							Inspect(block)
						END;
						INC(currentArrayElemAdr, staticTypeBlock.recSize);
					END
				END;
				IF orgHeapBlock IS ProtRecBlock THEN
					Inspect(orgHeapBlock(ProtRecBlock).awaitingLock.head);
					(* inspection of orgHeapBlock.awaitingLock.tail implicitly done *)
					Inspect(orgHeapBlock(ProtRecBlock).awaitingCond.head);
					(* inspection of orgHeapBlock.awaitingCond.tail implicity done *)
					Inspect(orgHeapBlock(ProtRecBlock).lockedBy);
					Inspect(orgHeapBlock(ProtRecBlock).lock)
				END
			ELSE
				(* mark stack entry is of type HeapBlock or extended type - this may happen, do nothing in this case *)
			END
		END;
		IF lowestForgotten = Machine.memBlockTail.endBlockAdr THEN EXIT END;
		FindForgottenBlock;
		(* must continue *)
	END;
END Mark;

(* mark heap blocks that could not be marked during regular mark phase because of mark stack overflow *)
PROCEDURE FindForgottenBlock;
VAR memBlock {UNTRACED}, startMemBlock {UNTRACED}: Machine.MemoryBlock; p {UNTRACED}, heapBlock {UNTRACED}: HeapBlock;
	staticTypeBlock {UNTRACED}: StaticTypeBlock;
	blockAdr, currentArrayElemAdr, lastArrayElemAdr, refBlock: ADDRESS;
	isMarkStackEntry, isOverflow: BOOLEAN; i: LONGINT;

BEGIN
	isOverflow := FALSE;
	memBlock := Machine.memBlockHead;
	WHILE (memBlock # NIL) & ~((memBlock.beginBlockAdr <= lowestForgotten) & (lowestForgotten < memBlock.endBlockAdr)) DO
		memBlock := memBlock.next
	END;
	startMemBlock := memBlock;
	WHILE (memBlock # NIL) & ~isOverflow DO
		IF memBlock = startMemBlock THEN
			blockAdr := lowestForgotten;
		ELSE
			blockAdr := memBlock.beginBlockAdr
		END;
		WHILE (blockAdr < memBlock.endBlockAdr) & ~isOverflow DO
			p := SYSTEM.VAL(HeapBlock, blockAdr + BlockHeaderSize);
			IF (p.mark = currentMarkValue) & ((p IS RecordBlock) OR (p IS ProtRecBlock) OR (p IS ArrayBlock)) THEN (* these blocks have outgoing references *)
				isMarkStackEntry := FALSE;
				SYSTEM.GET(p.dataAdr + TypeDescOffset, staticTypeBlock);
				IF ~(p IS ArrayBlock) THEN
					i := 0;
					WHILE ~isMarkStackEntry & (i < LEN(staticTypeBlock.pointerOffsets)) DO
						SYSTEM.GET(p.dataAdr + staticTypeBlock.pointerOffsets[i], refBlock);
						IF refBlock # NilVal THEN
							SYSTEM.GET(refBlock + HeapBlockOffset, heapBlock);
							IF heapBlock.mark < currentMarkValue THEN
								isMarkStackEntry := TRUE
							END
						END;
						INC(i)
					END
				ELSE
					SYSTEM.GET(p.dataAdr + 2 * AddressSize, currentArrayElemAdr);  (* first element *)
					SYSTEM.GET(p.dataAdr, lastArrayElemAdr);
					WHILE ~isMarkStackEntry & (currentArrayElemAdr <= lastArrayElemAdr) DO
						i := 0;
						WHILE ~isMarkStackEntry & (i < LEN(staticTypeBlock.pointerOffsets)) DO
							SYSTEM.GET(currentArrayElemAdr + staticTypeBlock.pointerOffsets[i], refBlock);
							IF refBlock # NilVal THEN
								SYSTEM.GET(refBlock + HeapBlockOffset, heapBlock);
								IF heapBlock.mark < currentMarkValue THEN
									isMarkStackEntry := TRUE
								END
							END;
							INC(i)
						END;
						INC(currentArrayElemAdr, staticTypeBlock.recSize)
					END
				END;
				IF ~isMarkStackEntry & (p IS ProtRecBlock) THEN
					(* check whether awaiting queues are not marked, only queue heads need to be checked, tails will be found as a consequence *)
					IF p(ProtRecBlock).awaitingLock.head # NIL THEN
						SYSTEM.GET(SYSTEM.VAL(ADDRESS, p(ProtRecBlock).awaitingLock.head) + HeapBlockOffset, heapBlock);
						IF heapBlock.mark < currentMarkValue THEN isMarkStackEntry := TRUE END
					END;
					IF p(ProtRecBlock).awaitingCond.head # NIL THEN
						SYSTEM.GET(SYSTEM.VAL(ADDRESS, p(ProtRecBlock).awaitingCond.head) + HeapBlockOffset, heapBlock);
						IF heapBlock.mark < currentMarkValue THEN isMarkStackEntry := TRUE END
					END;
					IF p(ProtRecBlock).lockedBy # NIL THEN
						SYSTEM.GET(SYSTEM.VAL(ADDRESS, p(ProtRecBlock).lockedBy) + HeapBlockOffset, heapBlock);
						IF heapBlock.mark < currentMarkValue THEN isMarkStackEntry := TRUE END
					END;
				END;

				IF isMarkStackEntry THEN (* forgotten block *)
					IF markStackHeight # MarkStackSize THEN
						markStack[markStackHeight] := p.dataAdr;
						INC(markStackHeight)
					ELSE
						isOverflow := TRUE;
						lowestForgotten := blockAdr;
					END
				END
			END;
			blockAdr := blockAdr + p.size;
		END;
		memBlock := memBlock.next;
	END;
	IF ~isOverflow THEN
		lowestForgotten := Machine.memBlockTail.endBlockAdr
	END
END FindForgottenBlock;

PROCEDURE MarkRealtimeObjects;
VAR heapBlock {UNTRACED}: HeapBlock;
BEGIN
	heapBlock := realtimeList;
	WHILE heapBlock # NIL DO
		Mark(SYSTEM.VAL(ANY, heapBlock.dataAdr));
		heapBlock := heapBlock.nextRealtime;
	END;
END MarkRealtimeObjects;

(** WriteType - Write a type name (for tracing only). *)
PROCEDURE WriteType*(t: ADDRESS);	(* t is static type descriptor *)
VAR m: ADDRESS; i: LONGINT; ch: CHAR; name: ARRAY 32 OF CHAR;
BEGIN
	SYSTEM.GET (t + TypeDescOffset, t);
	SYSTEM.GET (t + ModOfs, m);	(* m is only a hint *)
	IF m # NilVal THEN	(* could be a type without module, e.g. a Java class *)
		i := 0; SYSTEM.GET (m + ModNameOfs + i, ch);
		WHILE (ch >= "0") & (ch <= "z") & (i # 32) DO
			Trace.Char(ch);
			INC(i); SYSTEM.GET (m + ModNameOfs + i, ch)
		END
	ELSE
		Trace.String("NIL")
	END;
	Trace.Char(".");
	SYSTEM.MOVE(t + TypeNameOfs, ADDRESSOF(name[0]), 32);
	IF name[0] = 0X THEN Trace.String("-")
	ELSE Trace.String(name)
	END
END WriteType;

(** free list handling **)
PROCEDURE ClearFreeLists;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO MaxFreeLists DO
		freeLists[i].first := NIL;
		freeLists[i].last := NIL
	END;
END ClearFreeLists;

(* insert element in fifo, first = freeList.first; last = freeList.last *)
PROCEDURE AppendFree(VAR freeList: FreeList; block: FreeBlock);
BEGIN
	ASSERT(block.size >= freeList.minSize);
	IF freeList.first = NIL THEN
		freeList.first := block; freeList.last := block
	ELSE
		freeList.last.next := block;
		freeList.last := block;
	END;
	block.next := NIL
END AppendFree;

(* get last element from fifo *)
PROCEDURE GetFree(VAR freeList: FreeList): FreeBlock;
VAR block: FreeBlock;
BEGIN
	IF freeList.first = NIL THEN block := NIL;
	ELSIF freeList.first = freeList.last THEN block := freeList.first; freeList.first := NIL; freeList.last := NIL
	ELSE block := freeList.first; freeList.first := block.next; block.next := NIL
	END;
	RETURN block
END GetFree;

(** insert sorted into queue, no handling of last queue element *)
PROCEDURE InsertSorted(VAR freeList: FreeList; block: FreeBlock);
VAR x: FreeBlock;
BEGIN
	(* keep them ordered to avoid unnecessary splits *)
	x := freeList.first;
	WHILE x # NIL DO
		ASSERT(x # block);
		x := x.next;
	END;

	x := freeList.first;

	IF (x = NIL) OR (block.size <= x.size) THEN
		block.next := x;
		freeList.first := block;
	ELSE
		WHILE (x.next # NIL) & (block.size > x.next.size) DO  x := x.next  END;
		block.next := x.next;
		x.next := block;
	END;
END InsertSorted;

PROCEDURE AppendFreeBlock(block: FreeBlock);
VAR i: LONGINT;
BEGIN
	i := MaxFreeLists;
	WHILE (i > 0) & (freeLists[i].minSize > block.size)  DO  DEC( i )  END;

	IF i < FreeListBarrier THEN
		AppendFree(freeLists[i], block);
	ELSE
		AppendFree(freeLists[i], block);
		(*
		keeping lists sorted has some positive impact on heap utilization
	    but it slows down heap allocation speed:
	    
		InsertSorted(freeLists[i], block);
		*)

	END;
END AppendFreeBlock;

PROCEDURE FindFreeBlock( size: SIZE ): FreeBlock;
VAR prev, block: FreeBlock;  i: LONGINT;
BEGIN
	i := MaxFreeLists;
	WHILE (i > 0) & (freeLists[i].minSize > size)  DO  DEC( i )  END;

	REPEAT
		IF i < FreeListBarrier THEN
			block := GetFree(freeLists[i]);
		ELSE
			block := freeLists[i].first;
			prev := NIL;
			WHILE (block # NIL) & (block.size < size) DO
				prev := block;
				block := block.next;
			END;

			IF block # NIL THEN (* blockize >= size *)
				IF prev = NIL THEN
					freeLists[i].first := block.next;
				ELSE prev.next := block.next
				END;
				IF block = freeLists[i].last THEN
					freeLists[i].last := prev
				END;
				block.next := NIL;
			END;

			(*
			prev := freeLists[i].first;
			WHILE prev # NIL DO
				ASSERT(prev # block);
				prev := prev.next;
			END;
			*)

		END;
		INC( i )
	UNTIL (block # NIL) OR (i > MaxFreeLists);
	RETURN block
END FindFreeBlock;

PROCEDURE GetFreeBlockAndSplit(size: SIZE): FreeBlock;
VAR p,remainder: FreeBlock;
BEGIN
	p := FindFreeBlock(size);
	IF (p # NIL) & (ADDRESS(p.size) > ADDRESS (size)) THEN (* block too big - divide block into two parts: block with required size and remaining free block *)
		ASSERT(ADDRESS(p.size - size) >= BlockHeaderSize + SIZEOF(FreeBlockDesc));
		remainder := SYSTEM.VAL(FreeBlock, SYSTEM.VAL(ADDRESS, p) + size);
		InitFreeBlock(remainder, Unmarked, NilVal, p.size - size);
		AppendFreeBlock(remainder);
		p.size := size;
	END;
	IF p # NIL THEN INC(freeBlockFound) ELSE INC(freeBlockNotFound) END;
	RETURN p
END GetFreeBlockAndSplit;

PROCEDURE GetFreeBlock(size: SIZE; VAR p: FreeBlock);
BEGIN
	IF EnableFreeLists THEN
		IF sweepMarkValue < currentMarkValue THEN
			(*Trace.String("clear free lists and lazy sweep"); Trace.Ln;*)
			ClearFreeLists;
			LazySweep(MAX(LONGINT), p)
		END;
		p := GetFreeBlockAndSplit(size)
	ELSE
		LazySweep(size, p)
	END;
	IF size # MAX(LONGINT) THEN
	INC(throughput, size);
	END;
END GetFreeBlock;

(* Sweep phase *)
PROCEDURE LazySweep(size: SIZE; VAR p: FreeBlock);
VAR 
	lastFreeBlockAdr: ADDRESS; found : BOOLEAN;
	block {UNTRACED}: HeapBlock ; freeBlock{UNTRACED}, lastFreeBlock{UNTRACED}: FreeBlock; blockMark: LONGINT; blockSize: SIZE;
CONST FreeBlockHeaderSize = SIZEOF(FreeBlockDesc) + BlockHeaderSize;
BEGIN
	ASSERT(~EnableFreeLists OR (size = MAX(LONGINT)));
	found := FALSE;
	lastFreeBlockAdr := NilVal;
	lastFreeBlock := NIL;
	IF (sweepMemBlock = NIL) OR (sweepMarkValue < currentMarkValue) THEN (* restart lazy sweep including clearance of lists *)
		(* note that the order of the blocks does not necessarily represent the historical order of insertion
			as they are potentially provided by the underlying host system in with non-increasing address ranges
			blocks are sorted by Machine.Mod in an increased address range order
		*)
		sweepMemBlock := Machine.memBlockHead;
		sweepBlockAdr := Machine.memBlockHead.beginBlockAdr;
		sweepMarkValue := currentMarkValue;
	END;
	WHILE ~found & (sweepMemBlock # NIL) DO
		WHILE ~found & (sweepBlockAdr < sweepMemBlock.endBlockAdr) DO
			block := SYSTEM.VAL(HeapBlock, sweepBlockAdr + BlockHeaderSize); (* get heap block *)
			blockMark := block.mark; (* cache these values since they may be overwritten during concatenation *)
			blockSize := block.size;
			IF (blockMark < sweepMarkValue) THEN
				IF (block IS SystemBlock) OR (block IS RecordBlock) OR (block IS ProtRecBlock) OR (block IS ArrayBlock) THEN
					freeBlock := SYSTEM.VAL(FreeBlock, block);
					InitFreeBlock(freeBlock, Unmarked, NilVal, blockSize); (* convert this block into a free heap block and clear its data *)
					Machine.Fill32(sweepBlockAdr + FreeBlockHeaderSize, blockSize - FreeBlockHeaderSize, DebugValue);
				ELSE
					ASSERT(block IS FreeBlock);
					freeBlock := block(FreeBlock); (* free block has data cleared by definition *)
				END;
				IF lastFreeBlockAdr = NilVal THEN
					lastFreeBlockAdr := sweepBlockAdr;
					lastFreeBlock := freeBlock;
				ELSIF lastFreeBlockAdr + lastFreeBlock.size = sweepBlockAdr THEN
					(* there are two contiguous free blocks - merge them *)
					INC(lastFreeBlock.size,blockSize);
					(* clear header fields of concatenated block *)
					Machine.Fill32(sweepBlockAdr, FreeBlockHeaderSize, DebugValue);
				END
			ELSE
				ASSERT(~(block IS FreeBlock));
			END;
			IF (blockMark >= sweepMarkValue) OR (sweepBlockAdr + blockSize = sweepMemBlock.endBlockAdr) THEN (* no further merging is possible *)
				IF lastFreeBlockAdr # NilVal THEN
					IF ADDRESS(lastFreeBlock.size) >= ADDRESS (size) THEN (* block found - may be too big *)
						p := lastFreeBlock;
						IF ADDRESS(p.size) > ADDRESS (size) THEN (* block too big - divide block into two parts: block with required size and remaining free block *)
							ASSERT(ADDRESS(p.size - size) >= FreeBlockHeaderSize);
							freeBlock := SYSTEM.VAL(FreeBlock, SYSTEM.VAL(ADDRESS, p) + size);
							InitFreeBlock(freeBlock, Unmarked, NilVal, p.size - size);
							p.size := size;
						END;
						sweepBlockAdr := lastFreeBlockAdr + size; (* make sure next lazy sweep continues after block p *)
						found := TRUE;
					ELSIF EnableFreeLists THEN AppendFreeBlock(lastFreeBlock);
					END;
					lastFreeBlockAdr := NilVal;
					lastFreeBlock := NIL;
				END
			END;
			IF ~found THEN sweepBlockAdr := sweepBlockAdr + blockSize END
		END;
		IF ~found THEN
			sweepMemBlock := sweepMemBlock.next;
			IF sweepMemBlock # NIL THEN
				sweepBlockAdr := sweepMemBlock.beginBlockAdr
			ELSE
				sweepBlockAdr := NilVal
			END
		END
	END;
END LazySweep;

PROCEDURE CheckHeap;
VAR memBlock {UNTRACED}: Machine.MemoryBlock; p, refBlock, currentArrayElemAdr, lastArrayElemAdr: ADDRESS;
	heapBlock {UNTRACED}: HeapBlock; staticTypeBlock {UNTRACED}: StaticTypeBlock; i: LONGINT;

	PROCEDURE CheckBlock(block: ADDRESS): BOOLEAN;
	VAR heapBlockAdr: ADDRESS;
	BEGIN
		IF block = NilVal THEN
			RETURN TRUE
		ELSE
			IF (block >= Machine.memBlockHead.beginBlockAdr) & (block < Machine.memBlockTail.endBlockAdr) THEN
				SYSTEM.GET(block + HeapBlockOffset, heapBlockAdr);
				IF (heapBlockAdr >= Machine.memBlockHead.beginBlockAdr) & (heapBlockAdr < Machine.memBlockTail.endBlockAdr) THEN
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			ELSE
				RETURN FALSE
			END
		END
	END CheckBlock;

BEGIN
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		p := memBlock.beginBlockAdr;
		WHILE p < memBlock.endBlockAdr DO
			heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
			IF heapBlock IS SystemBlock THEN
			ELSIF heapBlock IS RecordBlock THEN
				IF heapBlock.dataAdr # NilVal THEN
					SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, staticTypeBlock); ASSERT(staticTypeBlock # NIL);
					FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
						SYSTEM.GET(heapBlock.dataAdr + staticTypeBlock.pointerOffsets[i], refBlock);
						IF ~CheckBlock(refBlock) THEN
							Trace.String("SEVERE ERROR: RecordBlock = "); Trace.Hex(heapBlock.dataAdr, 8);
							Trace.String(" invalid reference at pointer offset = "); Trace.Hex(staticTypeBlock.pointerOffsets[i], 0); Trace.Ln
						END
					END;
					IF heapBlock IS ProtRecBlock THEN
						IF CheckBlock(heapBlock(ProtRecBlock).awaitingLock.head) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingLock.tail) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingCond.head) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingCond.tail) &
							CheckBlock(heapBlock(ProtRecBlock).lockedBy) THEN
						ELSE
							Trace.String("SEVERE ERROR in awaiting queues of block = "); Trace.Hex(heapBlock.dataAdr, 8); Trace.Ln
						END
					END
				ELSE
					Trace.StringLn("SEVERE ERROR: heapBlock.dataAdr = NilVal for RecordBlock or ProtRecBlock")
				END;
			ELSIF heapBlock IS ArrayBlock THEN
				IF heapBlock.dataAdr # NilVal THEN
					SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, staticTypeBlock); ASSERT(staticTypeBlock # NIL);
					SYSTEM.GET(heapBlock.dataAdr + 2 * AddressSize, currentArrayElemAdr);
					SYSTEM.GET(heapBlock.dataAdr, lastArrayElemAdr);
					WHILE currentArrayElemAdr <= lastArrayElemAdr DO
						FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
							SYSTEM.GET(currentArrayElemAdr + staticTypeBlock.pointerOffsets[i], refBlock);
							IF ~CheckBlock(refBlock) THEN
								Trace.String("SEVERE ERROR in ArrayBlock = "); Trace.Hex(currentArrayElemAdr, 8);
								Trace.String(" invalid reference at pointer offset = "); Trace.Hex(staticTypeBlock.pointerOffsets[i], 0); Trace.Ln
							END
						END;
					 	INC(currentArrayElemAdr, staticTypeBlock.recSize)
					 END
				ELSE
					Trace.StringLn("SEVERE ERROR: heapBlock.dataAdr = NilVal for ArrayBlock")
				END
			ELSIF heapBlock IS FreeBlock THEN
			ELSE
				Trace.StringLn("Invalid heap block type")
			END;
			p := p + heapBlock.size;
		END;
		memBlock := memBlock.next
	END
END CheckHeap;

(* CheckCandidates - Check which candidates could be pointers, and mark them. (exported for debugging only) *)
PROCEDURE CheckCandidates*;
CONST MinDataOffset = BlockHeaderSize + SIZEOF(HeapBlockDesc) + BlockHeaderSize; (* minimal offset of data address with respect to block start address *)
VAR i, j, h: LONGINT; p, blockStart, tdAdr: ADDRESS; memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock {UNTRACED}: HeapBlock;
BEGIN
	(* {numCandidates > 0} *)
	(* first sort them in increasing order using shellsort *)
	h := 1;  REPEAT h := h*3 + 1 UNTIL h > numCandidates;
	REPEAT
		h := h DIV 3;  i := h;
		WHILE i < numCandidates DO
			p := candidates[i];  j := i;
			WHILE (j >= h) & (candidates[j-h] > p) DO
				candidates[j] := candidates[j-h];  j := j-h;
			END;
			candidates[j] := p;  INC(i)
		END
	UNTIL h = 1;

	(* sweep phase *)
	i := 0;
	p := candidates[i];
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		blockStart := memBlock.beginBlockAdr;
		WHILE (i < numCandidates) & (blockStart < memBlock.endBlockAdr) DO
			IF p < blockStart + MinDataOffset THEN (* candidate missed *)
				INC(i);
				IF i < numCandidates THEN
					p := candidates[i]
				END
			ELSE
				heapBlock := SYSTEM.VAL(HeapBlock, blockStart + BlockHeaderSize);
				SYSTEM.GET(blockStart + BlockHeaderSize + TypeDescOffset, tdAdr);	(* type descriptor address of heapBlock *)
				IF ~(tdAdr = freeBlockTag) & (p = heapBlock.dataAdr) THEN (* heap block must not be a free block but any other heap block type *)
					Mark(SYSTEM.VAL(ANY, p))
				END;
				blockStart := blockStart + heapBlock.size;
			END
		END;
		memBlock := memBlock.next
	END;
	numCandidates := 0
END CheckCandidates;

(* Check validity of single pointer candidate *)
PROCEDURE Candidate*(p: ADDRESS);
VAR memBlock {UNTRACED}: Machine.MemoryBlock; heapBlockAdr, tdAdr: ADDRESS;
BEGIN
	IF (p >= Machine.memBlockHead.beginBlockAdr) & (p < Machine.memBlockTail.endBlockAdr) THEN
		memBlock := Machine.memBlockHead;
		WHILE memBlock # NIL DO
			IF (p + HeapBlockOffset >= memBlock.beginBlockAdr) & (p + HeapBlockOffset < memBlock.endBlockAdr) THEN
				SYSTEM.GET(p + HeapBlockOffset, heapBlockAdr);
				IF (heapBlockAdr + TypeDescOffset >= memBlock.beginBlockAdr) & (heapBlockAdr + TypeDescOffset < memBlock.endBlockAdr) THEN
					SYSTEM.GET(heapBlockAdr + TypeDescOffset, tdAdr);
					(* check whether tdAdr is a valid type descriptor address *)
					IF (tdAdr = systemBlockTag) OR (tdAdr = recordBlockTag) OR (tdAdr = protRecBlockTag) OR (tdAdr = arrayBlockTag) THEN
						candidates[numCandidates] := p;
						INC(numCandidates);
						IF numCandidates = LEN(candidates) THEN CheckCandidates END
					END
				END
			END;
			memBlock := memBlock.next
		END
	END
END Candidate;

(** RegisterCandidates - Register a block of pointer candidates *)
PROCEDURE RegisterCandidates*(adr: ADDRESS; size: SIZE);
VAR end, p: ADDRESS;
BEGIN
	(* current processor must hold Heaps lock *)
	end := adr + size;
	WHILE adr # end DO
		SYSTEM.GET(adr, p);
		Candidate(p);
		INC(adr, AddressSize)
	END
END RegisterCandidates;

(* Check reachability of finalized objects. *)
PROCEDURE CheckFinalizedObjects;
VAR n, p, t: FinalizerNode; heapBlock {UNTRACED}: HeapBlock;

	PROCEDURE MarkDelegate(p: Finalizer);
	VAR pointer: ANY;
	BEGIN
		SYSTEM.GET(ADDRESSOF(p)+SIZEOF(ADDRESS),pointer);
		IF pointer # NIL THEN Mark(pointer) END;
	END MarkDelegate;

BEGIN
	n := checkRoot;
	WHILE n # NIL DO	(* move unmarked checked objects to finalize list *)
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, n.objWeak) + HeapBlockOffset, heapBlock);
		IF heapBlock.mark < currentMarkValue THEN
			IF n = checkRoot THEN checkRoot := n.nextFin ELSE p.nextFin := n.nextFin END;
			n.objStrong := n.objWeak;	(* anchor the object for finalization *)
			n.finalizerStrong := n.finalizer; (* anchor the finalizer for finalization *)
			t := n.nextFin; n.nextFin := finalizeRoot; finalizeRoot := n; n := t;
			IF Stats THEN DEC(NfinalizeAlive); INC(NfinalizeDead) END
		ELSE
			p := n; n := n.nextFin
		END
	END;
	(* now trace the weak references to keep finalized objects alive during this collection *)
	n := finalizeRoot;
	WHILE n # NIL DO
		MarkDelegate(n.finalizerStrong);
		Mark(n.objStrong); n := n.nextFin
	END;

	n := checkRoot;
	WHILE n # NIL DO (* list of objects that had been marked before entering CheckFinalizedObjects *)
		(* we still have to mark the weak finalizers, as they might have not been marked before  *)
		MarkDelegate(n.finalizer); n := n.nextFin
	END;
END CheckFinalizedObjects;

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

(* Add a root object to the set of traversable objects. If in allocated heap then mark and traverse, if in Module Heap (Bootfile) then only traverse. *)
PROCEDURE AddRootObject*(rootObject: RootObject);
BEGIN
	IF rootObject = NIL THEN (* nothing *)
	ELSIF CheckPointer(rootObject) THEN
		(* object in heap, must be fully marked and traversed *)
		Mark(rootObject)
	ELSE
		(* object in bootfile, traverse as root object only *)
		rootObject.nextRoot := rootList; rootList := rootObject;	(* link root list *)
	END;
END AddRootObject;

(* interruptible garbage collector for native A2 *)
PROCEDURE CollectGarbage*(root : RootObject);
VAR
	obj: RootObject;
	time1, time2: HUGEINT;
	f: FreeBlock;
BEGIN
	 (* do never use any low level locks as the garbage collector process has a very high priority and may thus be blocked by lower level processes -> potential deadlock *)
	(*!
	Do not use windows functionality such as  trace here in general -- can lead to deadlock when stopped processes are in writing to a file
	*)
	(* GC may run only if and only if sweep phase has been completed *)
	IF (sweepMemBlock = NIL) & (sweepMarkValue = currentMarkValue) THEN
		IF Stats THEN
			Nmark := 0; Nmarked := 0;
			INC(Ngc);
			time1 := Machine.GetTimer ();
		END;
		numCandidates := 0;
		rootList := NIL;
		INC(currentMarkValue);
		AddRootObject(root);

		IF GCType = HeuristicStackInspectionGC THEN

			REPEAT
				REPEAT
					IF rootList # NIL THEN	(* check root objects *)
						REPEAT
							obj := rootList;					(* get head object *)
							rootList := rootList.nextRoot;		(* link to next *)
							obj.FindRoots; (* Mark called via AddRootObject, but not for objects in static heap *)
						UNTIL rootList = NIL
					END;
					IF numCandidates # 0 THEN CheckCandidates END
				UNTIL (numCandidates = 0) & (rootList = NIL);
				MarkRealtimeObjects;
				CheckFinalizedObjects;
			UNTIL rootList = NIL;

		ELSIF GCType = MetaDataForStackGC THEN

			REPEAT
				IF rootList # NIL THEN	(* check root objects *)
					REPEAT
						obj := rootList;					(* get head object *)
						rootList := rootList.nextRoot;		(* link to next *)
						obj.FindRoots; (* Mark called via AddRootObject, but not for objects in static heap *)
					UNTIL rootList = NIL
				END;
				MarkRealtimeObjects;
				CheckFinalizedObjects
			UNTIL rootList = NIL;

		ELSE
			HALT(901)	(* wrong GCType constant *)
		END;

		IF Stats THEN
			time2 := Machine.GetTimer ();
			NgcCyclesLastRun := time2 - time1;
			IF NgcCyclesLastRun > NgcCyclesMax THEN NgcCyclesMax := NgcCyclesLastRun; END;
			INC(NgcCyclesAllRuns, NgcCyclesLastRun);
			NgcCyclesMark := NgcCyclesLastRun
		END;

	END;

	IF EnableFreeLists THEN GetFreeBlock(MAX(LONGINT), f) END;

END CollectGarbage;

PROCEDURE InvokeGC*;
BEGIN
	ASSERT(gcStatus # NIL);
	gcStatus.SetgcOngoing(TRUE);
END InvokeGC;

PROCEDURE ReturnBlocks;
VAR memBlock {UNTRACED}, free{UNTRACED}: Machine.MemoryBlock; p: ADDRESS; heapBlock {UNTRACED}: HeapBlock; f: FreeBlock;
BEGIN
	GetFreeBlock(MAX(LONGINT), f);
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		free := NIL;
		p := memBlock.beginBlockAdr;
		heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
		IF (heapBlock IS FreeBlock)  & (p + heapBlock.size = memBlock.endBlockAdr)  THEN
			free := memBlock;
		END;
		memBlock := memBlock.next;
		IF free # NIL THEN
			Machine.FreeMemBlock(free)
		END;
	END;
	sweepMemBlock := NIL; (* restart LazySweep  *)
	ClearFreeLists;
END ReturnBlocks;

PROCEDURE LazySweepGC*;
VAR p {UNTRACED}: FreeBlock;
BEGIN
	(* make sure that lazy sweep phase is finished before invoking a new mark phase *)
	Machine.Acquire(Machine.Heaps);
	(* trying to satisfy a request of MAX(LONGINT) bytes will never succeed - lazy sweep runs until end of heap *)
	GetFreeBlock(MAX(LONGINT), p);
	Machine.Release(Machine.Heaps);
	(* invoke mark phase, mark phase starts at next scheduler interrupt *)
	GC;
	(* return blocks now *)
	Machine.Acquire(Machine.Heaps);
	(* trying to satisfy a request of MAX(LONGINT) bytes will never succeed - lazy sweep runs until end of heap *)
	ReturnBlocks;
	Machine.Release(Machine.Heaps);
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

VAR throughput := 0 : SIZE;

(* NewBlock - Allocate a heap block. {(size MOD BlockSize = 0)}. Caller must hold Heap lock. *)
PROCEDURE NewBlock(size: SIZE): ADDRESS;
VAR try: LONGINT; p {UNTRACED}, freeBlock {UNTRACED}: FreeBlock; memBlock {UNTRACED}: Machine.MemoryBlock;
	beginHeapBlockAdr, endHeapBlockAdr: ADDRESS;

	PROCEDURE CheckPostGC;
	BEGIN
		IF (sweepMarkValue < currentMarkValue) & EnableReturnBlocks THEN (* GC has run but no Sweep yet -- time to do post-gc cleanup *)
			ReturnBlocks
		END;
	END CheckPostGC;

BEGIN
	CheckPostGC;
	try := 1;
	p := NIL;
	IF  (GC = NilGC) OR (throughput < 64*1024*1024) THEN
		GetFreeBlock(size, p);
	ELSE
		throughput := 0;
	END;
	WHILE (p = NIL) & (try <= MaxTries) DO
		Machine.Release(Machine.Heaps);	(* give up control *)
		GC;	(* try to free memory (other processes may also steal memory now) *)
		Machine.Acquire(Machine.Heaps);
		CheckPostGC;
		sweepMemBlock := NIL;
		GetFreeBlock(size, p);
		IF p = NIL THEN
			Machine.ExpandHeap(try, size, memBlock, beginHeapBlockAdr, endHeapBlockAdr);	(* try to extend the heap *)
			IF endHeapBlockAdr > beginHeapBlockAdr THEN
				freeBlock := SYSTEM.VAL(FreeBlock, beginHeapBlockAdr + BlockHeaderSize);
				InitFreeBlock(freeBlock, Unmarked, NilVal, endHeapBlockAdr - beginHeapBlockAdr);
				Machine.SetMemoryBlockEndAddress(memBlock, endHeapBlockAdr); (* end address of expanded block must set after free block is fit in memory block *)
				IF EnableFreeLists THEN AppendFreeBlock(freeBlock)
				ELSE
				sweepMemBlock := memBlock;
				sweepBlockAdr := beginHeapBlockAdr;
				END;
				GetFreeBlock(size, p);
				sweepMemBlock := NIL; (* restart sweep from beginning after having taken big block in order to avoid fragmentation *)
			END;
			INC(try)
		END;
	END;
	IF p # NIL THEN
		IF Stats THEN INC(Nnew); INC(NnewBytes, size) END;
		ASSERT(p.size >= size);
		RETURN p;
	ELSE 	(* try = MaxTries *)
		SYSTEM.HALT(14) 	(* out of memory *)
	END;
END NewBlock;

(** NewSys - Implementation of SYSTEM.NEW. *)
PROCEDURE NewSys*(VAR p: ANY; size: SIZE; isRealtime: BOOLEAN);
VAR blockSize, systemBlockSize: SIZE; systemBlockAdr, dataBlockAdr: ADDRESS;
	systemBlock {UNTRACED}: SystemBlock; pc: ADDRESS;
BEGIN
	systemBlockSize := BlockHeaderSize + SIZEOF(SystemBlockDesc);
	INC(systemBlockSize, (-systemBlockSize) MOD ArrayAlignment); (* round up to multiple of ArrayAlignment to ensure alignment of first data element to 0 MOD ArrayAlignment *)
	blockSize := systemBlockSize + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize);  (* round up to multiple of BlockSize *)

	Machine.Acquire(Machine.Heaps);
	systemBlockAdr:= NewBlock(blockSize);
	IF systemBlockAdr # 0 THEN
		SYSTEM.PUT(systemBlockAdr + TypeDescOffset, systemBlockTag);
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
		SYSTEM.PUT(systemBlockAdr + HeapBlockOffset,pc);
		dataBlockAdr := systemBlockAdr + systemBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
		SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);		(* no type descriptor *)
		SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, systemBlockAdr);
		systemBlock := SYSTEM.VAL(SystemBlock, systemBlockAdr);
		systemBlock.mark := currentMarkValue;
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
	IF allocationLogger # NIL THEN allocationLogger(p) END;
	Machine.Release(Machine.Heaps)
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

		Machine.Acquire(Machine.Heaps);
		recordBlockAdr := NewBlock(blockSize);
		IF recordBlockAdr # 0 THEN
			SYSTEM.PUT(recordBlockAdr + TypeDescOffset, recordBlockTag);
			SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
			SYSTEM.PUT(recordBlockAdr + HeapBlockOffset,pc);
			dataBlockAdr := recordBlockAdr + SIZEOF(RecordBlockDesc) + BlockHeaderSize;
			SYSTEM.PUT(dataBlockAdr + TypeDescOffset, tag);
			SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, recordBlockAdr);
			recordBlock := SYSTEM.VAL(RecordBlock, recordBlockAdr);
			(* recordBlock.next and recordBlock.prev already set to NIL by NewBlock *)
			recordBlock.mark := currentMarkValue;
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
		IF allocationLogger # NIL THEN allocationLogger(p) END;
		Machine.Release(Machine.Heaps)
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

	Machine.Acquire(Machine.Heaps);
	protRecBlockAdr := NewBlock(blockSize);
	IF protRecBlockAdr # 0 THEN
		SYSTEM.PUT(protRecBlockAdr + TypeDescOffset, protRecBlockTag);
		SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
		SYSTEM.PUT(protRecBlockAdr + HeapBlockOffset,pc);
		dataBlockAdr := protRecBlockAdr + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize;
		SYSTEM.PUT(dataBlockAdr + TypeDescOffset, tag);
		SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, protRecBlockAdr);
		protRecBlock := SYSTEM.VAL(ProtRecBlock, protRecBlockAdr);
		protRecBlock.mark := currentMarkValue;
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
		protRecBlock.locked := FALSE;
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
	IF allocationLogger # NIL THEN allocationLogger(p) END;
	Machine.Release(Machine.Heaps)
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
			Machine.Acquire(Machine.Heaps);
			arrayBlockAdr := NewBlock(blockSize);
			IF arrayBlockAdr # 0 THEN
				SYSTEM.PUT(arrayBlockAdr + TypeDescOffset, arrayBlockTag);
				SYSTEM.GET(Machine.CurrentBP()+SIZEOF(ADDRESS),pc);
				SYSTEM.PUT(arrayBlockAdr + HeapBlockOffset,pc);
				dataBlockAdr := arrayBlockAdr + arrayBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
				SYSTEM.PUT(dataBlockAdr + TypeDescOffset, elemTag);
				SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, arrayBlockAdr);
				arrayBlock := SYSTEM.VAL(ArrayBlock, arrayBlockAdr);
				arrayBlock.mark := currentMarkValue;
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
			IF allocationLogger # NIL THEN allocationLogger(p) END;
			Machine.Release(Machine.Heaps)
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
VAR memBlock {UNTRACED}: Machine.MemoryBlock; blockAdr: ADDRESS;
	block {UNTRACED}: HeapBlock;
BEGIN
	Machine.Acquire(Machine.Heaps);
	memBlock := Machine.memBlockHead;
	total := 0; free := 0; largest := 0;
	WHILE memBlock # NIL DO
		total := total + memBlock.endBlockAdr - memBlock.beginBlockAdr;
		blockAdr := memBlock.beginBlockAdr;
		WHILE blockAdr < memBlock.endBlockAdr DO
			block := SYSTEM.VAL(HeapBlock, blockAdr + BlockHeaderSize); (* get heap block *)
			IF (block.mark < currentMarkValue) THEN (* free/unused block encountered *)
				free := free + block.size;
				IF ADDRESS(block.size) > ADDRESS(largest) THEN largest := block.size END
			END;
			blockAdr := blockAdr + block.size;
		END;
		memBlock := memBlock.next
	END;
	Machine.Release(Machine.Heaps)
END GetHeapInfo;

(* NilGC - Default garbage collector. *)
PROCEDURE NilGC;
BEGIN
	HALT(301)	(* garbage collector not available yet *)
END NilGC;

(* Init - Initialize the heap. *)
PROCEDURE Init;
VAR beginBlockAdr, endBlockAdr, freeBlockAdr, p: ADDRESS;
	heapBlock {UNTRACED}: HeapBlock; freeBlock {UNTRACED}: FreeBlock; memBlock {UNTRACED}: Machine.MemoryBlock;
	s: ARRAY 32 OF CHAR; minSize,i: LONGINT;
BEGIN
	Machine.GetConfig("EnableFreeLists", s);
	EnableFreeLists := (s[0] = "1");
	Machine.GetConfig("EnableReturnBlocks", s);
	EnableReturnBlocks := (s[0] = "1");
	IF EnableReturnBlocks THEN Trace.String("Heaps:ReturnBlocks enabled"); Trace.Ln END;
	Machine.GetConfig("TraceHeaps",s);
	trace := (s[0] = "1");

	minSize := 32;
	FOR i := 0 TO MaxFreeLists DO
		freeLists[i].minSize := minSize;
		freeLists[i].first := NIL; freeLists[i].last := NIL;
		IF i < FreeListBarrier THEN  INC( minSize, BlockSize )  ELSE  minSize := 2 * minSize  END
	END;

	GC := NilGC;
	newSum := 0;
	checkRoot := NIL; finalizeRoot := NIL; rootList := NIL; realtimeList := NIL;
	gcStatus := NIL;

	Machine.SetGCParams;
	Machine.GetStaticHeap(beginBlockAdr, endBlockAdr, freeBlockAdr);

	(* the Type desciptor is generated by the compiler, therefore the linker does not have ot patch anything any more *)
	freeBlockTag := SYSTEM.TYPECODE (FreeBlockDesc);
	systemBlockTag := SYSTEM.TYPECODE (SystemBlockDesc);
	recordBlockTag := SYSTEM.TYPECODE (RecordBlockDesc);
	protRecBlockTag := SYSTEM.TYPECODE (ProtRecBlockDesc);
	arrayBlockTag := SYSTEM.TYPECODE (ArrayBlockDesc);

	(* find last block in static heap *)
	p := beginBlockAdr;
	heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
	WHILE p < freeBlockAdr DO
		initBlock := SYSTEM.VAL(ANY, heapBlock.dataAdr);
		p := p + heapBlock.size;
		heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize)
	END;

	ASSERT(p = freeBlockAdr);
	IF endBlockAdr - freeBlockAdr > 0 THEN
		(* initialization of free heap block done here since boot file is only written up to freeBlockAdr *)
		freeBlock := SYSTEM.VAL(FreeBlock, freeBlockAdr + BlockHeaderSize);
		InitFreeBlock(freeBlock, Unmarked, NilVal, endBlockAdr - freeBlockAdr);
		IF EnableFreeLists THEN AppendFreeBlock(freeBlock) END;
		ASSERT(freeBlock.size MOD BlockSize  =  0)
	END;

	currentMarkValue := 1;
	(* extend the heap for one block such that module initialization can continue as long as Heaps.GC is not set validly *)
	Machine.ExpandHeap(1, 1, memBlock, beginBlockAdr, endBlockAdr);	(* try = 1, size = 1 -> the minimal heap block expansion is performed *)
	IF endBlockAdr > beginBlockAdr THEN
		freeBlock := SYSTEM.VAL(FreeBlock, beginBlockAdr + BlockHeaderSize);
		InitFreeBlock(freeBlock, Unmarked, NilVal, endBlockAdr - beginBlockAdr);
		Machine.SetMemoryBlockEndAddress(memBlock, endBlockAdr);
		IF EnableFreeLists THEN AppendFreeBlock(freeBlock) END;
		sweepMarkValue := currentMarkValue;
		sweepMemBlock := memBlock;
		sweepBlockAdr := beginBlockAdr
	END;

END Init;

PROCEDURE SetHeuristic*;
BEGIN
	GCType := HeuristicStackInspectionGC;
	Trace.String("GC mode : heuristic"); Trace.Ln;
END SetHeuristic;

PROCEDURE SetMetaData*;
BEGIN
	GCType := MetaDataForStackGC;
	Trace.String("GC mode : metadata"); Trace.Ln;
END SetMetaData;

BEGIN
	Trace.String("Heaps: Initializing heap...");
	(* The meta data stack inspection is more efficient than the heuristics *)
	SetHeuristic;
	Init;
	Trace.Green; Trace.StringLn("... Ok"); Trace.Default;
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

StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
FSTools.CloseFiles A2.exe ~