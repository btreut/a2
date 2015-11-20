(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Linker0;	(* pjm *)

(* Aos Bootlinfker auxiliary module *)

(* fof: modifications for address sizes other than 4, mainly modified New* Procedures and offsets, tried to get some more documentation into the program text *)

IMPORT SYSTEM, Streams, Files, KernelLog;

CONST
	DefaultExtension = ".Obx";
	HeapSize = 1024*1024 (*630*1024;*);	(* linker heap size *)

	AddressSize = SIZEOF (ADDRESS);
	LenOfs = 3 * AddressSize; (* offset of first array dimension in SysBlk or ArrayBlk *)
	Unmarked = 0; (* mark value of free block *)

	(* fixup identifiers - also see GetKernelProc *)
	MemBlockDescModule = "Machine"; MemBlockDescType = "MemoryBlockDesc";
	ModDescModule = "Modules";  ModDescType = "Module";
	TypeDescModule = "Modules"; TypeDescType = "TypeDesc";
	HdPtrDescModule = "Loader"; HdPtrDescType = "@HdPtrDesc";
	ExportDescModule = "Modules";  ExportDescType = "ExportDesc";
	InitPtrModule = "Modules";  InitPtrName = "initBlock";
	ModRootModule = "Modules";  ModRootName = "root";
	ProcOffsetsName = "procOffsets"; NumProcsName = "numProcs";
	PtrOffsetsName = "ptrOffsets"; NumPtrsName = "numPtrs";
	HeapModule = "Heaps";
	FreeBlockDescType = "FreeBlockDesc"; SystemBlockDescType = "SystemBlockDesc"; RecordBlockDescType = "RecordBlockDesc";
	ProtRecBlockDescType = "ProtRecBlockDesc"; ArrayBlockDescType = "ArrayBlockDesc";
	FreeBlockTagPtrName = "freeBlockTagPtr"; SystemBlockTagPtrName = "systemBlockTagPtr"; RecordBlockTagPtrName = "recordBlockTagPtr";
	ProtRecBlockTagPtrName = "protRecBlockTagPtr"; ArrayBlockTagPtrName = "arrayBlockTagPtr";
	CurrentMarkValueName = "currentMarkValue";
	StartModule = "Objects";  StartCommand = "Terminate";
	MainModule = "BootConsole";

	(* id field temporarily stored in tag field of heap block, fixup in FixupHeapBlockTags *)
	FreeBlockId = 0;
	SystemBlockId = 1;
	RecordBlockId = 2;
	ProtRecBlockId = 3;
	ArrayBlockId = 4;

	ProtectedModule = TRUE;	(* is module descriptor protected? *)

	TraceDump = FALSE;	(* should full dump be displayed? *)
	TraceRefs = TRUE & TraceDump;	(* conservatively look for "missed" internal references? *)
	TraceDuplicates = FALSE & TraceDump;	(* should duplicate relocates be allowed and highlighted? *)

	LogName = "Linker.Log";

	HeaderSize = 40H;		(* HeaderSize MOD BlockSize = 0 *) (* ug *)
	EndBlockOfs = 38H;		(* cf. Machine.GetStaticHeap *)

	NumPriorities* = 6;

TYPE
	AdrTable = POINTER TO ARRAY OF ADDRESS;

(** --- MODULE Heaps --- *)

CONST
	MaxTags* = 16;	(* in type descriptor *)

		(** type descriptor field offsets relative to root (middle) *)
	Tag0Ofs* = -2 * AddressSize;					(** first tag *)
	Mth0Ofs* = Tag0Ofs - AddressSize * MaxTags;	(** first method *)
	Ptr0Ofs* = AddressSize;							(** first pointer offset *)

		(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)
	ProtTypeBit* = 31;

	BlockSize = 32;	(* power of two, <= 32 for RegisterCandidates *)
	ArrayAlignment = 8;
	BlockHeaderSize = 2 * AddressSize;
	HeapBlockOffset = - 2 * AddressSize;
	TypeDescOffset = - AddressSize;

	MinPtrOfs = -40000000H;	(* sentinel offset for ptrOfs *)
	MethodEndMarker* = MinPtrOfs; (* marks the end of the method addresses in the static type descriptor *)

	InitTableLen = 2048 + 256;
	InitPtrTableLen = 2048;

	TypeDescRecSize* = 5 * AddressSize + 32;  (* needs to be changed in case TypeDesc is adapted *)

	NilVal* = 0;

TYPE
	RootObject* = OBJECT
		VAR nextRoot: RootObject;	(* for linking root objects during GC *)
		PROCEDURE FindRoots*;	(** abstract *)
		BEGIN
			HALT(30101)
		END FindRoots;
	END RootObject;

	ProcessLink* = OBJECT (RootObject)
		VAR next*, prev*: ProcessLink
	END ProcessLink;

	ProcessQueue* = RECORD
		head*, tail*: ProcessLink
	END;

	MemoryBlock = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc = RECORD
		next {UNTRACED}: MemoryBlock;
		startAdr: ADDRESS;
		size: SIZE;
		beginBlockAdr, endBlockAdr: ADDRESS
	END;

	HeapBlock = POINTER TO HeapBlockDesc;	(* base object of all heap blocks *)
	HeapBlockDesc = RECORD
		mark: LONGINT;
		dataAdr: ADDRESS;
		size: SIZE;
		nextRealtime: HeapBlock;
	END;

	FreeBlock = POINTER TO FreeBlockDesc;
	FreeBlockDesc = RECORD (HeapBlockDesc)
	END;

	SystemBlock = POINTER TO SystemBlockDesc;
	SystemBlockDesc = RECORD  (HeapBlockDesc)
	END;

	RecordBlock = POINTER TO RecordBlockDesc;
	RecordBlockDesc = RECORD  (HeapBlockDesc)
	END;

	ProtRecBlock* = POINTER TO ProtRecBlockDesc;
	ProtRecBlockDesc* = RECORD  (RecordBlockDesc)
		count*: LONGINT;
		locked*: BOOLEAN;
		awaitingLock*: ProcessQueue;
		awaitingCond*: ProcessQueue;
		lockedBy*: ANY;
		lock*: ANY;	(* field used for Win32 system, unused for I386 *)
		waitingPriorities*: ARRAY NumPriorities OF LONGINT;
	END;

	ArrayBlock = POINTER TO ArrayBlockDesc;
	ArrayBlockDesc = RECORD  (HeapBlockDesc)
	END;

	StaticTypeBlock*= POINTER TO StaticTypeDesc;
	StaticTypeDesc* = RECORD
		recSize: SIZE;
		pointerOffsets* {UNTRACED}: PointerOffsets;
	END;

	PointerOffsets = POINTER TO ARRAY OF SIZE;

(** --- MODULE Modules --- *)

TYPE
		(* definitions for object-model loader support *)
	Name* = ARRAY 32 OF CHAR;

	CommandProc* = PROCEDURE;
	CommandParProc* = PROCEDURE(par: ANY): ANY;

	Command* = RECORD
		name*: Name;
		argTdAdr*, retTdAdr* : ADDRESS;
		entryAdr* : ADDRESS;
	END;

	ExportDesc* = RECORD
		fp*: ADDRESS;
		adr*: ADDRESS;
		exports*: LONGINT;
		dsc*: ExportArray
	END;
	ExportArray* = POINTER TO ARRAY OF ExportDesc;

	Bytes* = POINTER TO ARRAY OF CHAR;

	TerminationHandler* = PROCEDURE;

	ExceptionTableEntry* = RECORD
		pcFrom*: ADDRESS;
		pcTo*: ADDRESS;
		pcHandler*: ADDRESS;
	END;

	ExceptionTable* = POINTER TO ARRAY OF ExceptionTableEntry;

	ProcTableEntry* = RECORD
		pcFrom*, pcLimit*, pcStatementBegin*, pcStatementEnd*: ADDRESS;
		noPtr*: LONGINT;
	END;

	ProcTable* = POINTER TO ARRAY OF ProcTableEntry;

	PtrTable* = POINTER TO ARRAY OF SIZE;

	ProcOffsetEntry* = RECORD
		data*: ProcTableEntry;	(* code offsets of procedures *)
		startIndex: LONGINT;	(* start index into global ptrOffset table *)
	END;

	ProcOffsetTable* = POINTER TO ARRAY OF ProcOffsetEntry;

	Module* = OBJECT (RootObject)	(* cf. Linker0 & Heaps.WriteType *)
		VAR
			next*: Module;
			name*: Name;
			init, published: BOOLEAN;
			refcnt*: LONGINT;
			sb*: ADDRESS;
			entry*: POINTER TO ARRAY OF ADDRESS;
			command*: POINTER TO ARRAY OF Command;
			ptrAdr*: POINTER TO ARRAY OF ADDRESS;
			typeInfo*: POINTER TO ARRAY OF TypeDesc; (* traced explicitly in FindRoots *) (* ug *)
			module*: POINTER TO ARRAY OF Module;
			procTable*: ProcTable; (* information inserted by loader, removed after use in Publish, not used by linker *)
			ptrTable*: PtrTable;  (* information inserted by loader, removed after use in Publish, not used by linker *)
			data*, code*, staticTypeDescs* (* ug *), refs*: Bytes;
			export*: ExportDesc;
			term*: TerminationHandler;
			exTable*: ExceptionTable;
			noProcs*: LONGINT;
			firstProc*: ADDRESS;		(* procedure with lowest PC in module *)
			maxPtrs*: LONGINT;
			crc*: LONGINT;
	END Module;

	TypeDesc* = POINTER TO RECORD   (* ug: adapt constant TypeDescRecSize if this type if this type is changed !!! *)
		descSize: LONGINT;
		sentinel: LONGINT;	(* = MPO-4 *)
		tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
		flags*: SET;
		mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
		name*: Name;
	END;

VAR
	logWriter: Streams.Writer; logFile: Files.File;

	root-: ADDRESS;
	procOffsets {UNTRACED}: ProcOffsetTable;	(* global table containing procedure code offsets and pointer offsets, sorted in ascending order of procedure code offsets *)
	numProcs: LONGINT;			(* number of entries in procOffsets *)
	ptrOffsets {UNTRACED}: PtrTable;			(* global table containing pointer offsets of procedures *)
	numPtrs: LONGINT;				(* number of entries in ptrOffsets *)
	heap-: ANY;
	memBlock {UNTRACED}: MemoryBlock;
	beginMemBlockAdr, endMemBlockAdr: ADDRESS;	(* block boundaries of linker heap (including memory block descriptor) *)
	beginAdr, freeAdr, baseAdr (* fof 071201 *) : ADDRESS;
	heapOfs: SIZE;
	exportTags, relocates: LONGINT;
	exportTagAdr: AdrTable;
	relocateAdr: AdrTable;
	curRelocate: LONGINT;
	refsMissed: LONGINT;
	prefix,suffix: Files.FileName; (* fof 071203 could be long filename *)
	loadObj*: PROCEDURE (name, fileName: ARRAY OF CHAR;  VAR res: LONGINT;
			VAR msg: ARRAY OF CHAR): Module;
	getProcs: ARRAY 9 OF BOOLEAN;
	freeBlockTag, systemBlockTag, recordBlockTag, protRecBlockTag, arrayBlockTag: ADDRESS;
	initBlock {UNTRACED}: ANY;	(* address of init block, i.e. block that contains calls to module bodies *)
	currentMarkValue: LONGINT; (* all objects allocated in the link phase receive this mark value *)


(** --- MODULE Machine --- *)

(** Fill4 - Fill "size" dwords at "destAdr" with "filler". *)

PROCEDURE Fill4 (destAdr: ADDRESS; size: SIZE; filler: LONGINT);
BEGIN
	WHILE size > 0 DO
		SYSTEM.PUT (destAdr, filler);
		INC (destAdr, SIZEOF(LONGINT));
		DEC (size);
	END;
END Fill4;

(** --- MODULE KernelLog --- *)

(** Char - Write a character to the trace output. *)

PROCEDURE Char*(c: CHAR);
BEGIN
	logWriter.Char(c);
END Char;

(** String - Write a string. *)

PROCEDURE String*(CONST s: ARRAY OF CHAR);
BEGIN
	logWriter.String(s);
END String;

(** Ln - Skip to the next line on trace output. *)

PROCEDURE Ln*;
BEGIN
	logWriter.Ln();
END Ln;

(** Int - Write "x" as a decimal number.  "w" is the field width. *)

PROCEDURE Int*(x, w: LONGINT);
BEGIN
	logWriter.Int(x,w);
END Int;

(** Hex - Write "x" as a hexadecimal number. *)

PROCEDURE Hex*(x, w: LONGINT);
BEGIN
	logWriter.Hex(x,w);
END Hex;

(** Address - Write "x" as an address. *)

PROCEDURE Address*(x: ADDRESS);
BEGIN
	logWriter.Address(x);
END Address;

(** Memory - Write a block of memory. *)

PROCEDURE Memory*(adr, size: LONGINT);  (* ug: not yet rewritten using ADDRESS and SIZE *)
VAR i, j, t: LONGINT;  buf: ARRAY 4 OF CHAR;  reset, missed: BOOLEAN;
BEGIN
	(*
	Texts.SetFont(writer, Fonts.This("Courier10.Scn.Fnt"));
	*)
	buf[1] := 0X;  size := adr+size-1;
	reset := FALSE;
	FOR i := adr TO size BY 16 DO
		Hex(i, 9);  missed := FALSE;
		FOR j := i TO i+15 DO
			IF j <= size THEN
				IF curRelocate >= 0 THEN	(* highlighting enabled *)
					IF (j >= relocateAdr[curRelocate]) & (j <= relocateAdr[curRelocate]+3) THEN
						(* Texts.SetColor(writer, 3); *)  reset := TRUE
					ELSIF j = relocateAdr[curRelocate]+4 THEN
						INC(curRelocate);
						IF curRelocate # relocates THEN
							IF j = relocateAdr[curRelocate] THEN
								(* Texts.SetColor(writer, 3);  *) reset := TRUE
							ELSIF TraceDuplicates & (j = relocateAdr[curRelocate]+4) THEN	(* duplicate! *)
								(* Texts.SetColor(writer, 1); *)  reset := TRUE;
								REPEAT
									INC(curRelocate)
								UNTIL (curRelocate = relocates) OR (j # relocateAdr[curRelocate]+4)
							END
						ELSE
							curRelocate := -1
						END
					ELSIF TraceRefs THEN
						IF j <= adr+size-4 THEN	(* heuristic to check if all pointers were seen *)
							SYSTEM.GET(j, t);
							IF (t > beginMemBlockAdr) & (t < freeAdr) THEN
								INC(refsMissed);  missed := TRUE;
								(* Texts.SetColor(writer, 4); *)  reset := TRUE
							END
						END
					END
				END;
				SYSTEM.GET(j, buf[0]);
				Hex(SYSTEM.VAL(SHORTINT, buf[0]), -3);
				(*
				IF reset THEN Texts.SetColor(writer, 15) END
				*)
			ELSE
				buf := "   ";  String(buf);  buf[1] := 0X
			END
		END;
		buf[0] := " ";	String(buf);
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET(j, buf[0]);
				IF (buf[0] < " ") OR (buf[0] >= CHR(127)) THEN
					buf[0] := "."
				END;
				String(buf)
			END
		END;
		IF missed THEN String(" <--missed?") END;
		Ln
	END;
	(*
	Texts.SetFont(writer, Fonts.Default);
	*)
END Memory;

(** Bits - Write bits (ofs..ofs+n-1) of x in binary. *)

PROCEDURE Bits*(x: SET;  ofs, n: LONGINT);
BEGIN
	REPEAT
		DEC(n);
		IF (ofs+n) IN x THEN Char("1") ELSE Char("0") END
	UNTIL n = 0
END Bits;

(** Enter - Enter mutually exclusive region for writing. *)

PROCEDURE Enter*;
BEGIN
	Char("{")
END Enter;

(** Exit - Exit mutually exclusive region for writing. *)

PROCEDURE Exit*;
BEGIN
	Char("}");  Ln
END Exit;

(** --- MODULE Heaps --- *)

(* initialize a free block *)
PROCEDURE InitFreeBlock(freeBlock: FreeBlock; mark: LONGINT; dataAdr: ADDRESS; size: SIZE);
VAR freeBlockAdr: ADDRESS;
BEGIN
	freeBlock.mark := mark;
	freeBlock.dataAdr := dataAdr;
	freeBlock.size := size;
	freeBlock.nextRealtime := NIL;
	(* initialize free block header *)
	freeBlockAdr := SYSTEM.VAL(ADDRESS, freeBlock);
	SYSTEM.PUT(freeBlockAdr + TypeDescOffset, FreeBlockId); (* use temporary constant here, correct tags are filled in by FixupHeapBlockTags *)
	SYSTEM.PUT(freeBlockAdr + HeapBlockOffset, NilVal)
END InitFreeBlock;

(* NewBlock - Allocate a heap block.  {(size MOD BlockSize = 0)} *)

PROCEDURE NewBlock(size: SIZE): ADDRESS;
VAR p, freeBlockAdr: ADDRESS; freeBlock: FreeBlock; blockSize: SIZE;
BEGIN
	ASSERT(size MOD BlockSize = 0);
	freeBlock := SYSTEM.VAL(FreeBlock, freeAdr + BlockHeaderSize);
	blockSize := freeBlock.size;
	p := freeAdr; INC(freeAdr, size);
	ASSERT(freeAdr + BlockHeaderSize  + SIZEOF(FreeBlockDesc) <= memBlock.endBlockAdr); (* there must be space for an empty heap block *)
	freeBlockAdr := freeAdr + BlockHeaderSize;	(* address of remaining free block *)
	freeBlock := SYSTEM.VAL(FreeBlock, freeBlockAdr);
	InitFreeBlock(freeBlock, Unmarked, NilVal, blockSize - size);
	RETURN p
END NewBlock;

(** NewSys - Implementation of SYSTEM.NEW *)

PROCEDURE NewSys*(VAR p: ANY; size: SIZE);
VAR systemBlockSize, blockSize: SIZE; systemBlockAdr, dataBlockAdr: ADDRESS;
	systemBlock: SystemBlock;
BEGIN
	ASSERT((BlockHeaderSize MOD ArrayAlignment = 0));
	systemBlockSize := BlockHeaderSize + SIZEOF(SystemBlockDesc);
	systemBlockSize := ((systemBlockSize + ArrayAlignment - 1) DIV ArrayAlignment) * ArrayAlignment; (* align SystemBlock such that first data element is aligned 0 MOD ArrayAlignment, required for arrays that do not contain pointers *)
	blockSize := systemBlockSize + BlockHeaderSize + size;
	INC(blockSize,(-blockSize) MOD BlockSize);  (* round up to multiple of BlockSize *)

	systemBlockAdr := NewBlock(blockSize) + BlockHeaderSize;
	SYSTEM.PUT(systemBlockAdr + TypeDescOffset, SystemBlockId);	 (* temporary type descriptor value, fixup and relocation are done later *)
	SYSTEM.PUT(systemBlockAdr + HeapBlockOffset, NilVal);
	dataBlockAdr := systemBlockAdr + systemBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
	SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);				(* system blocks have no type descriptor *)
	SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, systemBlockAdr);	(* reference to heap block descriptor *)
	Relocate(dataBlockAdr + HeapBlockOffset);
	systemBlock := SYSTEM.VAL(SystemBlock, systemBlockAdr);
	systemBlock.mark := currentMarkValue;
	systemBlock.dataAdr := dataBlockAdr;
	systemBlock.nextRealtime := NIL; (* no realtime object since SystemBlock during allocation of a module *)
	Relocate(ADDRESSOF(systemBlock.dataAdr));
	Relocate(ADDRESSOF(systemBlock.nextRealtime));
	systemBlock.size := blockSize;
	p := SYSTEM.VAL(ANY, dataBlockAdr);

	Fill4(dataBlockAdr, (blockSize - systemBlockSize - BlockHeaderSize) DIV 4, 0);	(* clear everything from dataBlockAdr until end of block *)
END NewSys;

(* NewRealArr - Implementation of allocation of new real array *)

PROCEDURE NewRealArr*(VAR p: ANY; numElems, elemSize: SIZE; numDims: LONGINT);
VAR arrayBlockAdr, dataBlockAdr, firstElem, elemTag: ADDRESS; arrSize, arrayBlockSize, blockSize, fillSize: SIZE;
	arrayBlock: ArrayBlock;
	arrayDataOffset: SIZE; (* offset from descriptor origin to first element of array, depends on number of dimensions, must be aligned to 0 MOD 8 *)
BEGIN
	elemTag := 0;
	arrSize := numElems * elemSize;
	ASSERT(arrSize > 0);
	ASSERT((BlockHeaderSize MOD ArrayAlignment = 0));
	arrayDataOffset := numDims * AddressSize + 3 * AddressSize;
	INC(arrayDataOffset, (-arrayDataOffset) MOD ArrayAlignment);  (* align here such that first first array element is aligned 0 MOD ArrayAlignment *)
	arrayBlockSize := BlockHeaderSize + SIZEOF(ArrayBlockDesc);
	INC(arrayBlockSize,(-arrayBlockSize) MOD ArrayAlignment);  (* do. *)
	blockSize := arrayBlockSize + BlockHeaderSize + (arrayDataOffset + arrSize);
	INC(blockSize,(-blockSize) MOD BlockSize);(* round up to multiple of BlockSize *)

	arrayBlockAdr := NewBlock(blockSize) + BlockHeaderSize;
	SYSTEM.PUT(arrayBlockAdr + TypeDescOffset, ArrayBlockId);		(* temporary value, fixup and relocation are done later *)
	SYSTEM.PUT(arrayBlockAdr + HeapBlockOffset, NilVal);
	dataBlockAdr := arrayBlockAdr + arrayBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
	SYSTEM.PUT(dataBlockAdr + TypeDescOffset, elemTag);			(* dummy Tag, correct element tag will be filled in later *)
	SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, arrayBlockAdr);	(* reference to heap block descriptor *)
	Relocate(dataBlockAdr + HeapBlockOffset);
	arrayBlock := SYSTEM.VAL(ArrayBlock, arrayBlockAdr);
	arrayBlock.mark := currentMarkValue;
	arrayBlock.dataAdr := dataBlockAdr;
	arrayBlock.nextRealtime := NIL; (* no realtime object since this object is used during allocation of a module *)
	Relocate(ADDRESSOF(arrayBlock.dataAdr));
	Relocate(ADDRESSOF(arrayBlock.nextRealtime));
	arrayBlock.size := blockSize;

	(* clear data part of array, clear everything from dataBlockAdr until end of block, write GC support info after clearing the block *)
	fillSize := blockSize - arrayBlockSize - BlockHeaderSize;
	ASSERT(fillSize MOD 4 = 0);	(* fillSize implicitly is a multiple of 4 *)
	Fill4(dataBlockAdr, fillSize DIV 4, 0);

	firstElem := dataBlockAdr + arrayDataOffset;
	SYSTEM.PUT(dataBlockAdr, firstElem + arrSize - elemSize);	(* lastElemToMark *)
	Relocate(dataBlockAdr);
	SYSTEM.PUT(dataBlockAdr + AddressSize, NIL);				(* reserved for Mark *)
	SYSTEM.PUT(dataBlockAdr + 2 * AddressSize, firstElem);		(* firstElem *)
	Relocate(dataBlockAdr + 2 * AddressSize);

	p := SYSTEM.VAL(ANY, dataBlockAdr);

END NewRealArr;

(* NewTypeDesc - Implementation of allocation of dynamic record *)

PROCEDURE NewTypeDesc*(VAR p: ANY; recSize: SIZE);
VAR blockSize: SIZE; recordBlockAdr, dataBlockAdr: ADDRESS;
	recordBlock: RecordBlock;
BEGIN
	blockSize := BlockHeaderSize + SIZEOF(RecordBlockDesc) + BlockHeaderSize + recSize;
	INC(blockSize, (-blockSize) MOD BlockSize); (* align to multiple of BlockSize *)

	recordBlockAdr := NewBlock(blockSize) + BlockHeaderSize;
	SYSTEM.PUT(recordBlockAdr + TypeDescOffset, RecordBlockId);		 (* temporary tag value, fixup and relocation are done later *)
	SYSTEM.PUT(recordBlockAdr + HeapBlockOffset, NilVal);
	dataBlockAdr := recordBlockAdr + SIZEOF(RecordBlockDesc) + BlockHeaderSize;
	SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);					(* type descriptor tag will be filled in FixupTypeDescTags *)
	SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, recordBlockAdr);		(* reference to heap block descriptor *)
	Relocate(dataBlockAdr + HeapBlockOffset);
	recordBlock := SYSTEM.VAL(RecordBlock, recordBlockAdr);
	recordBlock.mark := currentMarkValue;
	recordBlock.dataAdr := dataBlockAdr;
	recordBlock.nextRealtime := NIL; (* default value NIL since module type descriptors are no realtime objects *)
	Relocate(ADDRESSOF(recordBlock.dataAdr));
	Relocate(ADDRESSOF(recordBlock.nextRealtime));
	recordBlock.size := blockSize;
	p := SYSTEM.VAL(ANY, dataBlockAdr);

	Fill4(dataBlockAdr, (blockSize - SIZEOF(RecordBlockDesc) - 2 * BlockHeaderSize) DIV 4, 0);	(* clear everything from dataBlockAdr to end of blockr *)
END NewTypeDesc;

(* FillStaticType - Implementation of filling static type descriptor *)

PROCEDURE FillStaticType*(VAR staticTypeAddr: ADDRESS; startAddr, typeInfoAdr: ADDRESS; size, recSize: SIZE;
							numPtrs, numSlots: LONGINT);
VAR p, offset: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock;
BEGIN
	Fill4(startAddr, size DIV 4, 0);	(* clear whole static type, size MOD AddressSize = 0 implicitly, see WriteType in PCOF.Mod *)
	SYSTEM.PUT(startAddr, MethodEndMarker); 	(* sentinel *)

	(* methods and tags filled in later *)

	offset := AddressSize * (numSlots + 1 + 1);  (* #methods, max. no. of tags, method end marker (sentinel), pointer to type information*)
	p := startAddr + offset;
	SYSTEM.PUT(p + TypeDescOffset, typeInfoAdr);  (* pointer to typeInfo *)
	Relocate(p + TypeDescOffset);
	staticTypeBlock := SYSTEM.VAL(StaticTypeBlock, p);
	staticTypeBlock.recSize := recSize;
	staticTypeAddr := p;

	(* create the pointer for the dynamic array of pointer, the dynamic array of pointer offsets is stored in the static type
	    descriptor and has no header part *)
	INC(p, SIZEOF(StaticTypeDesc));
	IF p MOD (2 * AddressSize) # 0 THEN INC(p, AddressSize) END;
	ASSERT(p MOD (2 * AddressSize) = 0);
	SYSTEM.PUT(p + 3 * AddressSize, numPtrs); (* internal structure of dynamic array without pointers: the first 3 fields are unused *)
	staticTypeBlock.pointerOffsets := SYSTEM.VAL(PointerOffsets, p); (* the fourth field contains the dimension of the array *)
	Relocate(ADDRESSOF(staticTypeBlock.pointerOffsets));

	(* pointer offsets filled in later *)

END FillStaticType;

(** --- MODULE Modules --- *)

(** Append - Append from to to, truncating on overflow. *)

PROCEDURE Append*(CONST from: ARRAY OF CHAR;  VAR to: ARRAY OF CHAR);
VAR i, j, m: LONGINT;
BEGIN
	j := 0;  WHILE to[j] # 0X DO INC(j) END;
	m := LEN(to)-1;
	i := 0;  WHILE (from[i] # 0X) & (j # m) DO to[j] := from[i];  INC(i);  INC(j) END;
	to[j] := 0X
END Append;

(* Publish - Add a module to the pool of accessible modules, or return named module. *)

PROCEDURE Publish(VAR m: Module;  VAR new: BOOLEAN);
VAR n: Module;  i: LONGINT;
BEGIN
	n := SYSTEM.VAL(Module, root);
	WHILE (n # NIL) & (n.name # m.name) DO n := n.next END;
	IF n # NIL THEN	(* module with same name exists, return it and ignore new m *)
		m := n;  new := FALSE
	ELSE
		m.published := TRUE;
		m.next := SYSTEM.VAL(Module, root);
		root := SYSTEM.VAL(ADDRESS, m);
		m.refcnt := 0;
		FOR i := 0 TO LEN(m.module)-1 DO INC(m.module[i].refcnt) END;
		new := TRUE
	END
END Publish;

(* ModuleByName - Return the named module. *)

PROCEDURE ModuleByName(CONST name: ARRAY OF CHAR): Module;
VAR m: Module;
BEGIN
	m := SYSTEM.VAL(Module, root);
	WHILE (m # NIL) & (m.name # name) DO m := m.next END;
	RETURN m
END ModuleByName;

(* GetFileName - Generate a module file name. *)

PROCEDURE GetFileName(CONST name: ARRAY OF CHAR;  VAR fileName: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
	i := 0;  WHILE prefix[i] # 0X DO fileName[i] := prefix[i];  INC(i) END;
	j := 0;  WHILE name[j] # 0X DO fileName[i] := name[j];  INC(i);  INC(j) END;
	j := 0;  WHILE suffix[j] # 0X DO fileName[i] := suffix[j];  INC(i);  INC(j) END;
	fileName[i] := 0X
END GetFileName;

(** ThisModule - Import a module. *)	(* Algorithm J. Templ, ETHZ, 1994 *)

PROCEDURE ThisModule*(CONST name: ARRAY OF CHAR;  VAR res: LONGINT;  VAR msg: ARRAY OF CHAR): Module;
(* TYPE Body = PROCEDURE; *)
VAR m, p: Module;  fileName: ARRAY 64 OF CHAR;  (*body: Body;*)  new: BOOLEAN;
BEGIN
	res := 0;  msg[0] := 0X;  m := ModuleByName(name);
	IF m = NIL THEN
		GetFileName(name, fileName);
		m := loadObj(name, fileName, res, msg);
		IF (m # NIL) & ~m.published THEN
			p := m;  Publish(m, new);
			IF new THEN	(* m was successfully published *)
				(*body := SYSTEM.VAL(Body, ADDRESSOF(m.code[0]));
				body;  res := 0;  msg[0] := 0X;*)
				m.init := TRUE	(* allow ThisCommand *)
			ELSE
				(* m was part of cycle, replaced by existing module *)
				HALT(99)
			END
		END
	END;
	RETURN m
END ThisModule;

(** Return the named type *)
PROCEDURE ThisType*(m: Module; CONST name: ARRAY OF CHAR): TypeDesc;
VAR i: LONGINT; type: TypeDesc;
BEGIN
	i := 0;
	WHILE (i < LEN(m.typeInfo)) & (m.typeInfo[i].name # name) DO INC(i) END;
	IF i = LEN(m.typeInfo) THEN
		type := NIL
	ELSE
		type := m.typeInfo[i]
	END;
	RETURN type
END ThisType;

(* ug: just for debugging *)
(** WriteType - Write a type name (for tracing only). *)
PROCEDURE WriteType(t: ADDRESS);	(* t is static type descriptor *)
VAR typeDesc: TypeDesc;
BEGIN
	IF t # NilVal THEN
		SYSTEM.GET (t + TypeDescOffset, typeDesc);
		IF typeDesc.mod # NIL THEN
			String(typeDesc.mod.name)
		ELSE
			String("NIL");
		END;
		Char(".");
		String(typeDesc.name)
	ELSE
		String("no type")
	END
END WriteType;

PROCEDURE FindInsertionPos(VAR entry: ProcTableEntry; VAR pos: LONGINT): BOOLEAN;
VAR l, r, x: LONGINT; success, isHit: BOOLEAN;
BEGIN
	pos := -1;
	success := FALSE;
	IF numProcs = 0 THEN (* empty table *)
		pos := 0; success := TRUE
	ELSE
		l := 0; r := numProcs - 1;
		REPEAT
			x := (l + r) DIV 2;
			IF entry.pcLimit < procOffsets[x].data.pcFrom THEN r := x - 1 ELSE l := x + 1 END;
			isHit := ((x = 0) OR (procOffsets[x - 1].data.pcLimit < entry.pcFrom)) & (entry.pcLimit < procOffsets[x].data.pcFrom);
		UNTIL isHit OR (l > r);
		IF isHit THEN
			pos := x; success := TRUE
		ELSE
			IF (x = numProcs - 1) & (procOffsets[x].data.pcLimit < entry.pcFrom) THEN
				pos := x + 1; success := TRUE
			END
		END
	END;
	RETURN success
END FindInsertionPos;

PROCEDURE NumTotalPtrs(procTable: ProcTable): LONGINT;
VAR i, num: LONGINT;
BEGIN
	num := 0;
	FOR i := 0 TO LEN(procTable) - 1 DO
		num := num + procTable[i].noPtr
	END;
	RETURN num
END NumTotalPtrs;

(* insert the procedure code offsets and pointer offsets of a single module into the global table *)
PROCEDURE InsertProcOffsets*(procTable: ProcTable; ptrTable: PtrTable; maxPtr: LONGINT);
VAR success: BOOLEAN; i, j, pos, poslast, num: LONGINT;
BEGIN
	IF LEN(procTable) > 0 THEN
		ASSERT(numProcs + LEN(procTable) <= LEN(procOffsets)); 	(* no reallocation of procOffsets in linker *)
		num := NumTotalPtrs(procTable);
		ASSERT(numPtrs + num  <= LEN(ptrOffsets));					(* no reallocation of ptrOffsets in linker *)
		success := FindInsertionPos(procTable[0], pos); success := success & FindInsertionPos(procTable[LEN(procTable) - 1], poslast);
		ASSERT(success  & (pos = poslast));
		FOR i := numProcs - 1 TO pos BY -1 DO procOffsets[i + LEN(procTable)] := procOffsets[i] END;
		FOR i := 0 TO LEN(procTable) - 1 DO
			procOffsets[pos + i].data := procTable[i];
			procOffsets[pos + i].startIndex := numPtrs; (* this field is never accessed in case of procTable[i].noPtr = 0, so we put numPtrs in there *)
			FOR j := 0 TO procTable[i].noPtr - 1 DO
				ptrOffsets[numPtrs + j] := ptrTable[i * maxPtr + j]
			END;
			numPtrs := numPtrs + procTable[i].noPtr;
		END;
		numProcs := numProcs + LEN(procTable)
	END
END InsertProcOffsets;

(** --- MODULE Linker0 --- *)

(* GrowTable - Grow an address table. *)

PROCEDURE GrowTable(VAR table: AdrTable);
VAR new: AdrTable; i: LONGINT;
BEGIN
	NEW(new, 2*LEN(table));
	FOR i := 0 TO LEN(table)-1 DO new[i] := table[i] END;
	table := new
END GrowTable;

(** Relocate - Record a relocate location. *)

PROCEDURE Relocate*(adr: ADDRESS);
BEGIN
	IF relocates = LEN(relocateAdr) THEN GrowTable(relocateAdr) END;
	relocateAdr[relocates] := adr;  INC(relocates);
	SYSTEM.GET(adr, adr);
	ASSERT((adr = 0) OR (adr > beginMemBlockAdr) & (adr <= freeAdr))
END Relocate;

(** Open - Initialize the log file etc. *)

PROCEDURE Open*(CONST namePrefix,nameSuffix: ARRAY OF CHAR; base: ADDRESS; log: Streams.Writer);
VAR i: LONGINT; w: Files.Writer;
BEGIN
	(* fof 071201 *)
	COPY(namePrefix, prefix);
	IF nameSuffix = "" THEN
		suffix := DefaultExtension
	ELSE
		COPY(nameSuffix, suffix)
	END;
	baseAdr := base;

	InitHeap;

	root := 0;
	freeAdr := memBlock.beginBlockAdr;
	heapOfs := baseAdr - beginAdr;
	exportTags := 0;  relocates := 0;  refsMissed := 0;
	curRelocate := -1;

	IF log # NIL THEN logWriter := log; logFile := NIL ELSE logFile := Files.New(LogName); NEW(w, logFile,0); logWriter := w END;
	FOR i := 0 TO LEN(getProcs) - 1 DO getProcs[i] := FALSE END;

	(* allocate the global tables procOffsets and ptrOffsets in linker heap *)
	NewProcOffsets(procOffsets, InitTableLen);
	numProcs := 0;
	NewPtrOffsets(ptrOffsets, InitPtrTableLen);
	numPtrs := 0;
END Open;

(* RelocateModules - Relocate the module records. *)

PROCEDURE RelocateModules;
VAR adr: ADDRESS; i: LONGINT;  type, hdPtrDescType: TypeDesc;  m: Module;
BEGIN
	type := ThisType(ModuleByName(ModDescModule), ModDescType);
	hdPtrDescType := ThisType(ModuleByName(HdPtrDescModule), HdPtrDescType);
	ASSERT((type # NIL) & (hdPtrDescType # NIL));
	IF ProtectedModule THEN
		INCL(type.flags, ProtTypeBit)	(* flag for dynamic loader *)
	END;
	m := SYSTEM.VAL(Module, root);
	WHILE m # NIL DO
		adr := SYSTEM.VAL(ADDRESS, m);
		SYSTEM.PUT(adr + TypeDescOffset, type.tag);  Relocate(adr + TypeDescOffset);		(* module descriptor tag *)
		IF LEN(m.typeInfo) > 0 THEN	(* type tag only set in case of no. elements > 0 otherwise a SystemBlock with no type tag is used *)
			adr := SYSTEM.VAL(ADDRESS, m.typeInfo);
			SYSTEM.PUT(adr + TypeDescOffset, hdPtrDescType.tag);
			Relocate(adr + TypeDescOffset)
		END;
		IF LEN(m.module) > 0 THEN (* do. *)
			adr := SYSTEM.VAL(ADDRESS, m.module);
			SYSTEM.PUT(adr + TypeDescOffset, hdPtrDescType.tag);
			Relocate(adr + TypeDescOffset)
		END;

		(* relocation of addresses *)

		Relocate(ADDRESSOF(m.next));
		Relocate(m.sb);	(* SELF in const area *)
		Relocate(ADDRESSOF(m.sb));

			(* m.entry in module block *)
		(* m.entry indirect tag already relocated (same as SysBlk) *)
		FOR i := 0 TO LEN(m.entry)-1 DO Relocate(ADDRESSOF(m.entry[i])) END;
		Relocate(ADDRESSOF(m.entry));

			(* m.command in module block *)
		FOR i := 0 TO LEN(m.command)-1 DO
			Relocate(ADDRESSOF(m.command[i].entryAdr));
			IF (m.command[i].argTdAdr > 1) THEN Relocate(ADDRESSOF(m.command[i].argTdAdr)); END;
			IF (m.command[i].retTdAdr > 1) THEN Relocate(ADDRESSOF(m.command[i].retTdAdr)); END;
		END;
		Relocate(ADDRESSOF(m.command));

			(* m.ptrAdr in module block *)
		FOR i := 0 TO LEN(m.ptrAdr)-1 DO Relocate(ADDRESSOF(m.ptrAdr[i])) END;
		Relocate(ADDRESSOF(m.ptrAdr));

			(* m.typeInfo in module block *)
		FOR i := 0 TO LEN(m.typeInfo) - 1 DO
			Relocate(ADDRESSOF(m.typeInfo[i]));
			Relocate(ADDRESSOF(m.typeInfo[i].tag));
			Relocate(ADDRESSOF(m.typeInfo[i].mod))
		END;
		Relocate(ADDRESSOF(m.typeInfo));

			(* m.module in module block *)
		FOR i := 0 TO LEN(m.module)-1 DO Relocate(ADDRESSOF(m.module[i])) END;
		Relocate(ADDRESSOF(m.module));

			(* m.data in module block *)
		Relocate(ADDRESSOF(m.data));

			(* m.code in module block *)
		Relocate(ADDRESSOF(m.code));

			(* m.staticTypeDescs in module block *)
		Relocate(ADDRESSOF(m.staticTypeDescs));

			(* m.refs in module block *)
		Relocate(ADDRESSOF(m.refs));

			(* m.exTable in module block *)
		FOR i := 0 TO LEN(m.exTable)-1 DO
			Relocate(ADDRESSOF(m.exTable[i].pcFrom));
			Relocate(ADDRESSOF(m.exTable[i].pcTo));
			Relocate(ADDRESSOF(m.exTable[i].pcHandler))
		END;
		Relocate(ADDRESSOF(m.exTable));

		Relocate(ADDRESSOF(m.firstProc));

		(*
			(* object model support *)
		ASSERT((m.publics = 0) & (m.privates = 0));	(* not marked *)
		ASSERT(m.import = NIL);	(* not marked *)
		ASSERT(m.struct = NIL);	(* not marked *)
		ASSERT(m.reimp = NIL);	(* not marked *)
		*)
		Relocate(ADDRESSOF(m.export.dsc));	(* descendants relocated via RelocateArray *)
		m := m.next
	END
END RelocateModules;

(* RelocateArrayFields - Fix up a dynamic array. *)

PROCEDURE RelocateArrayFields(tagAdr: ADDRESS);
VAR adr, p, lastElem: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock; i: LONGINT;
BEGIN
	SYSTEM.GET(tagAdr + AddressSize, lastElem);
	SYSTEM.GET(tagAdr + 3 * AddressSize, p);	(* firstElem *)
	SYSTEM.GET(tagAdr, adr);	(* adr is address of static type descriptor (no alignment) *)
	staticTypeBlock := SYSTEM.VAL(StaticTypeBlock, adr);
	LOOP
		FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
			Relocate(p + staticTypeBlock.pointerOffsets[i]);
		END;
		IF p = lastElem THEN EXIT END;
		INC(p, staticTypeBlock.recSize)	(* step to next array element *)
	END
END RelocateArrayFields;

(* RelocateExports - Relocate export arrays. *)

PROCEDURE RelocateExports;
VAR type: TypeDesc;  i: LONGINT;
BEGIN
	type := ThisType(ModuleByName(ExportDescModule), ExportDescType);
	ASSERT(type # NIL);
	FOR i := 0 TO exportTags - 1 DO
		SYSTEM.PUT(exportTagAdr[i], type.tag);
		Relocate(exportTagAdr[i]);
		RelocateArrayFields(exportTagAdr[i]);
	END
END RelocateExports;

(* RelocateProcOffsets - relocate the contents of the global table procOffsets, see InitTable for relocation of the global pointers *)

PROCEDURE RelocateProcOffsets;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO numProcs - 1 DO	(* relocation of code addresses in procOffsets *)
		Relocate(ADDRESSOF(procOffsets[i].data.pcFrom));
		Relocate(ADDRESSOF(procOffsets[i].data.pcLimit));
		Relocate(ADDRESSOF(procOffsets[i].data.pcStatementBegin));
		Relocate(ADDRESSOF(procOffsets[i].data.pcStatementEnd));
	END;
END RelocateProcOffsets;

PROCEDURE FixupTypeDescTags;
VAR type: TypeDesc; i: LONGINT; m: Module; adr: ADDRESS;
BEGIN
	type := ThisType(ModuleByName(TypeDescModule), TypeDescType);
	ASSERT(type # NIL);
	m := SYSTEM.VAL(Module, root);
	WHILE m # NIL DO
		FOR i := 0 TO LEN(m.typeInfo) - 1 DO
			adr := SYSTEM.VAL(ADDRESS, m.typeInfo[i]);
			SYSTEM.PUT(adr + TypeDescOffset, type.tag);
			Relocate(adr + TypeDescOffset);
		END;
		m := m.next
	END
END FixupTypeDescTags;

PROCEDURE FixupHeapBlockTags;
VAR type: TypeDesc; m: Module; heapBlock {UNTRACED}: HeapBlock; adr, heapBlockAdr: ADDRESS; val: LONGINT;
BEGIN
	m := ModuleByName(HeapModule); ASSERT(m # NIL);
	type := ThisType(m, FreeBlockDescType); ASSERT(type # NIL); freeBlockTag := type.tag;
	type := ThisType(m, SystemBlockDescType); ASSERT(type # NIL); systemBlockTag := type.tag;
	type := ThisType(m, RecordBlockDescType); ASSERT(type # NIL); recordBlockTag := type.tag;
	type := ThisType(m, ProtRecBlockDescType); ASSERT(type # NIL); protRecBlockTag := type.tag;
	type := ThisType(m, ArrayBlockDescType); ASSERT(type # NIL); arrayBlockTag := type.tag;
	adr := beginMemBlockAdr;
	WHILE adr < endMemBlockAdr DO
		heapBlockAdr := adr + BlockHeaderSize;
		SYSTEM.GET(heapBlockAdr + TypeDescOffset, val);	(* tag field of heap block p *)
		CASE val OF
			FreeBlockId: SYSTEM.PUT(heapBlockAdr + TypeDescOffset, freeBlockTag);
		|	SystemBlockId: SYSTEM.PUT(heapBlockAdr + TypeDescOffset, systemBlockTag);
		|	RecordBlockId: SYSTEM.PUT(heapBlockAdr + TypeDescOffset, recordBlockTag);
		|	ProtRecBlockId: SYSTEM.PUT(heapBlockAdr + TypeDescOffset, protRecBlockTag);
		|	ArrayBlockId: SYSTEM.PUT(heapBlockAdr + TypeDescOffset, arrayBlockTag);
		END;
		Relocate(heapBlockAdr + TypeDescOffset);
		heapBlock := SYSTEM.VAL(HeapBlock, heapBlockAdr);
		adr := adr + heapBlock.size
	END;
END FixupHeapBlockTags;

(* SortRelocates - Sort the relocates. *)

PROCEDURE SortRelocates;
VAR h, i, j: LONGINT; p: ADDRESS;
BEGIN
	h := 1;  REPEAT h := h*3 + 1 UNTIL h > relocates;
	REPEAT
		h := h DIV 3;  i := h;
		WHILE i < relocates DO
			p := relocateAdr[i];  j := i;
			WHILE (j >= h) & (relocateAdr[j-h] > p) DO
				relocateAdr[j] := relocateAdr[j-h];  j := j-h;
			END;
			relocateAdr[j] := p;  INC(i)
		END
	UNTIL h = 1;
	IF ~TraceDuplicates THEN
		FOR i := 1 TO relocates-1 DO ASSERT(relocateAdr[i-1] < relocateAdr[i]) END	(* sorted, without dups *)
	END
END SortRelocates;

(* GetNum - Get a compressed refblk number. *)

PROCEDURE GetNum(refs: Bytes;  VAR i, num: LONGINT);
VAR n, s: LONGINT;  x: CHAR;
BEGIN
	s := 0;  n := 0;
	x := refs[i];  INC(i);
	WHILE ORD(x) >= 128 DO
		INC(n, ASH(ORD(x) - 128, s));
		INC(s, 7);
		x := refs[i];  INC(i)
	END;
	num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
END GetNum;

(* VarByName - Find a global variable in the reference block. *)

PROCEDURE VarByName(refs: Bytes;  i: LONGINT;  CONST name: ARRAY OF CHAR): SIZE;
VAR mode: CHAR;  j, m, adr, type, t: LONGINT;  s: Name;  found: BOOLEAN;
BEGIN
	m := LEN(refs^);  found := FALSE;
	mode := refs[i];  INC(i);
	WHILE (i < m) & ((mode = 1X) OR (mode = 3X)) & ~found DO	(* var *)
		type := ORD(refs[i]);  INC(i);
		IF (type >= 81H) OR (type = 16H) OR (type = 1DH) THEN
			GetNum(refs, i, t)	(* dim/tdadr *)
		END;
		GetNum(refs, i, adr);
		j := 0;  REPEAT s[j] := refs[i];  INC(i);  INC(j) UNTIL s[j-1] = 0X;
		IF s = name THEN found := TRUE
		ELSIF i < m THEN mode := refs[i];  INC(i)
		END
	END;
	IF found THEN
		ASSERT((mode = 1X) & ((type = 0DH) OR (type = 1DH) OR (type = 06H)))	(* pointer or LInt VAR *)
	ELSE
		adr := 0
	END;
	RETURN SYSTEM.VAL(SIZE, adr)
END VarByName;

(* InitTable - Generate init code for module bodies. *)

PROCEDURE InitTable(diff: SIZE; baseAdr, loadAdr: ADDRESS);
VAR i, n: LONGINT; adr: ADDRESS; m: Module;

	PROCEDURE InitBody(m: Module);
	BEGIN
		IF m = NIL THEN
			(* allocate block for init calls of n modules - each call requires 5 bytes (1 byte for the opcode and 4 bytes for the call address) - and some
			     extra code following it, see body of InitTable *)
			NewSys(initBlock, 5*n + (5+3));  adr := SYSTEM.VAL(ADDRESS, initBlock)
		ELSE
			INC(n);  InitBody(m.next);
			Address(ADDRESSOF(m.code[0])+diff);  Char("H");  Char(" ");
			Address(ADDRESSOF(m.data[0])+diff);  Char("H");  Char(" ");
			String(m.name);  Ln;
			SYSTEM.PUT(adr, 0E8X);	(* CALL *)
			SYSTEM.PUT(adr+1, ADDRESSOF(m.code[0]) - (adr+5));  (* call address *)
			INC(adr, 5)
		END
	END InitBody;

BEGIN
	String("BEGIN");  Ln;
	n := 0;  InitBody(SYSTEM.VAL(Module, root));
	String("END");  Ln;
		(* startup command *)
	m := ModuleByName(StartModule);
	i := 0;  WHILE m.command[i].name # StartCommand DO INC(i) END;
	Address(SYSTEM.VAL(ADDRESS, m.command[i].entryAdr)+diff);  Char(" ");
	String(m.name);  Char(".");  String(StartCommand);  Ln;
	SYSTEM.PUT(adr, 0E8X);	(* CALL *)
	SYSTEM.PUT(adr+1, SYSTEM.VAL(LONGINT, m.command[i].entryAdr) - (adr+5));
	INC(adr, 5);
		(* HALT *)
	SYSTEM.PUT(adr, 6AX);	(* PUSH imm8 *)
	SYSTEM.PUT(adr+1, 0FFX);
	SYSTEM.PUT(adr+2, 0CCX);	(* INT 3 *)

		(* init table *)
	FOR adr := beginAdr TO beginAdr+HeaderSize-1 DO
		SYSTEM.PUT(adr, 0X)
	END;
	IF baseAdr = loadAdr THEN
		SYSTEM.PUT(beginAdr, 0E8X);	(* CALL *)
		SYSTEM.PUT(beginAdr+1, SYSTEM.VAL(ADDRESS, initBlock) - (beginAdr+5))
	ELSE	(* image will relocate itself *)
		adr := beginAdr;
		SYSTEM.PUT(adr, 60X);	(* PUSHAD *)
		INC(adr);
		SYSTEM.PUT(adr, 0BEX);	(* MOV ESI, X *)
		SYSTEM.PUT(adr+1, loadAdr);
		INC(adr, 5);
		SYSTEM.PUT(adr, 0BFX);	(* MOV EDI, X *)
		SYSTEM.PUT(adr+1, baseAdr);
		INC(adr, 5);
		SYSTEM.PUT(adr, 0B9X);	(* MOV ECX, X *)
		SYSTEM.PUT(adr+1, (freeAdr-beginAdr+3) DIV 4);	(* length of image in dwords *)
		INC(adr, 5);
		SYSTEM.PUT(adr, 0FCX);	(* CLD *)
		SYSTEM.PUT(adr+1, 0F3X);	(* REP *)
		SYSTEM.PUT(adr+2, 0A5X);	(* MOVSD *)
		INC(adr, 3);
		SYSTEM.PUT(adr, 61X);	(* POPAD *)
		INC(adr);
		SYSTEM.PUT(adr, 0E8X);	(* CALL *)
		SYSTEM.PUT(adr+1, SYSTEM.VAL(ADDRESS, initBlock) - (adr+5) + (baseAdr-loadAdr));
		INC(adr, 5);
		ASSERT(adr-beginAdr <= EndBlockOfs)	(* not too much code *)
	END;
	SYSTEM.PUT(beginAdr + EndBlockOfs, freeAdr);  Relocate(beginAdr + EndBlockOfs)
END InitTable;

PROCEDURE RootGlobals;
VAR m: Module; i: LONGINT; ofs: SIZE;
BEGIN
	(* root init block pointer *)
	m := ModuleByName(InitPtrModule);
	ASSERT((m.refs[0] = 0F8X) & (m.refs[1] = 0X) & (m.refs[2] = "$") & (m.refs[3] = "$") & (m.refs[4] = 0X));
	i := 5;  ofs := VarByName(m.refs, i, InitPtrName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, initBlock);  Relocate(m.sb + ofs);

	(* module root pointer, pointer to global procOffsets and ptrOffsets table, number of valid entries in procOffsets and ptrOffsets*)
	m := ModuleByName(ModRootModule);
	ASSERT((m.refs[0] = 0F8X) & (m.refs[1] = 0X) & (m.refs[2] = "$") & (m.refs[3] = "$") & (m.refs[4] = 0X));
	i := 5;
	ofs := VarByName(m.refs, i, ModRootName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, root);  Relocate(m.sb + ofs);
	ofs := VarByName(m.refs, i, ProcOffsetsName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, SYSTEM.VAL(ADDRESS, procOffsets)); Relocate(m.sb + ofs);
	ofs := VarByName(m.refs, i, NumProcsName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, numProcs);
	ofs := VarByName(m.refs, i, PtrOffsetsName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, SYSTEM.VAL(ADDRESS, ptrOffsets)); Relocate(m.sb + ofs);
	ofs := VarByName(m.refs, i, NumPtrsName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, numPtrs);

	(* write tag addresses as pointer values since the reference section does not contain variables of type ADDRESS *)
	(* patching of Type Tags not necessary any more -- cf. Module Heaps *)

	m := ModuleByName(HeapModule);
	ASSERT((m.refs[0] = 0F8X) & (m.refs[1] = 0X) & (m.refs[2] = "$") & (m.refs[3] = "$") & (m.refs[4] = 0X));
	i := 5;
	ofs := VarByName(m.refs, i, CurrentMarkValueName); ASSERT(ofs # 0);
	SYSTEM.PUT(m.sb + ofs, currentMarkValue)
END RootGlobals;

(* ScopeInfo - Write information for debugger. *)

PROCEDURE ScopeInfo(diff: SIZE; baseAdr: ADDRESS;  root: Module);
VAR main: ADDRESS;  m: Module;  i: LONGINT;
BEGIN
	m := root;  WHILE (m # NIL) & (m.name # MainModule) DO m := m.next END;
	IF m = NIL THEN main := -1 ELSE main := ADDRESSOF(m.code[0])+diff END;
	IF main = -1 THEN String(MainModule);  String(" not found");  Ln END;
	String("SCOPE.BEGIN 0");  Address(baseAdr);  String("H 0");  Address(main);  Char("H");  Ln;
	m := root;
	WHILE m # NIL DO
		String("  ");  String(m.name);  String(" 0");
		Address(ADDRESSOF(m.code[0])+diff);  String("H 0");
		Hex(LEN(m.code), 8);  String("H 0");
		Address(m.sb);  String("H ");  Int(LEN(m.typeInfo), 1);  Ln;
		FOR i := 0 TO LEN(m.typeInfo)-1 DO
			String("    0");  Hex(-1, 8);  String("H 0");
			Address(SYSTEM.VAL(ADDRESS, m.typeInfo[i].tag)+diff);  Char("H");  Ln
		END;
		m := m.next
	END;
	String("SCOPE.END");  Ln
END ScopeInfo;

(* ug *)
PROCEDURE CheckLinkerHeap; (* ug: for debugging *)
VAR p, tagAdr, typeDescAdr: ADDRESS; heapBlock: HeapBlock;
BEGIN
	(* find last block in static heap *)
	p := beginMemBlockAdr;
	heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
	WHILE p < endMemBlockAdr DO
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, heapBlock) + TypeDescOffset, tagAdr);
		IF tagAdr = freeBlockTag THEN
			String("FreeBlock at adr = "); Address(p); Ln
		ELSIF tagAdr = systemBlockTag THEN
			 String("SystemBlock at adr = "); Address(p); Ln
		ELSIF tagAdr = recordBlockTag THEN
			SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, typeDescAdr);
			String("RecordBlock at adr = "); Address(p); String(" type = "); WriteType(typeDescAdr); Ln
		ELSIF tagAdr = protRecBlockTag THEN
			SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, typeDescAdr);
			String("ProtRecBlock at adr = "); Address(p); String(" type = "); WriteType(typeDescAdr); Ln
		ELSIF tagAdr = arrayBlockTag THEN
			SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, typeDescAdr);
			String("ArrayBlock at adr = "); Address(p); String(" element type = "); WriteType(typeDescAdr); 	Ln
		ELSE
			HALT(9999)
		END;
		p := p + heapBlock.size;
		heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize)
	END
END CheckLinkerHeap;

(** Close - Finalize the log file etc. *)

PROCEDURE Close*(w: Files.Writer;  loadAdr: ADDRESS; res: LONGINT; CONST msg: ARRAY OF CHAR; log: Streams.Writer);
VAR i: LONGINT; adr: ADDRESS; diff: SIZE;  ch: CHAR;
BEGIN
	IF res = 0 THEN
		IF baseAdr = -1 THEN diff := 0 ELSE diff := baseAdr - beginAdr END;
		FixupTypeDescTags;
		InitTable(diff, baseAdr, loadAdr);	(* InitTable call before FixupHeapBlockTags since InitTable creates new heap block, i.e. init block *)
		(* no heap block allocations in linker heap from this point on *)
		memBlock.endBlockAdr := freeAdr;		(* set correct end block address of linker heap *)
		memBlock.size := freeAdr - beginMemBlockAdr;	(* set correct size of whole memory block *)
		FixupHeapBlockTags;			(* FixupHeapBlockTags before RootGlobals since heap block tags will be rooted in boot file *)
		RootGlobals;
		ScopeInfo(diff, baseAdr, SYSTEM.VAL(Module, root));
		RelocateMemoryBlock;
		RelocateModules;
		RelocateProcOffsets;
		RelocateExports;
			(* relocate addresses *)
		FOR i := 0 TO relocates-1 DO
			SYSTEM.GET(relocateAdr[i], adr);
			IF adr # 0 THEN
				IF ~(((adr > beginMemBlockAdr) & (adr <= freeAdr))) THEN
					KernelLog.String("problem with adr in Linker0.Close ");
					KernelLog.Int(beginMemBlockAdr,1);
					KernelLog.String("<=");
					KernelLog.Int(adr,1);
					KernelLog.String("<=");
					KernelLog.Int(freeAdr,1);
					KernelLog.String(" at "); KernelLog.Int(i,1); KernelLog.String(":"); KernelLog.Int(relocates,1);
					KernelLog.String(" Check for fixup duplicates ! ");
					KernelLog.Ln;
				END;
				(*ASSERT((adr > beginMemBlockAdr) & (adr <= freeAdr));*)
				SYSTEM.PUT(relocateAdr[i], adr + diff)
			END
		END;
			(* output *)
		IF TraceDump THEN
			SortRelocates;  curRelocate := 0;	(* for highlighting of relocations *)
			Memory(beginAdr, freeAdr - beginAdr);
			ASSERT(curRelocate  =  -1)	(* all relocations highlighted *)
		END;
		String("  exports: ");  Int(exportTags, 1);  String("  relocates: ");  Int(relocates, 1);
		IF TraceRefs THEN String("  possible missed references: ");  Int(refsMissed, 1) END;
		Ln;

		FOR adr := beginAdr TO freeAdr - 1 DO
			SYSTEM.GET(adr, ch);
			w.Char( ch)
		END;
		FOR adr := 1 TO AddressSize DO
			w.Char(0X)
		END;
		String("Written bytes");  Char(" ");  Address(freeAdr - beginAdr+AddressSize);  Ln
	END;
	String("Result = ");  Int(res, 1);  Char(" ");  String(msg);  Ln; logWriter.Update;

	IF res = 0 THEN
		log.String("Linker0 Ok. #Bytes=  "); log.Address(freeAdr - beginAdr);
		IF logFile # NIL THEN
			log.String(" "); log.String(LogName);
		END;
	ELSE
		log.String( "Error report in ");  log.String( LogName);
	END;
	log.Ln;
	IF logFile # NIL THEN
		logWriter.Update();
		logFile.Update();
		Files.Register(logFile);
		logFile := NIL; logWriter := NIL
	END;
END Close;

(* NewModule - Allocate a module descriptor (protected record) *)

PROCEDURE NewModule*(VAR m: Module);
VAR size, blockSize: SIZE; protRecBlockAdr, dataBlockAdr: ADDRESS;
	protRecBlock: ProtRecBlock; i: LONGINT;
BEGIN
	size := SYSTEM.GET32(SYSTEM.TYPECODE(Module));
	blockSize := BlockHeaderSize +  SIZEOF(ProtRecBlockDesc) + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize); (* round up to multiple of BlockSize *)

	protRecBlockAdr := NewBlock(blockSize) + BlockHeaderSize;
	SYSTEM.PUT(protRecBlockAdr + TypeDescOffset, ProtRecBlockId);
	SYSTEM.PUT(protRecBlockAdr + HeapBlockOffset, NilVal);
	dataBlockAdr := protRecBlockAdr + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize;
	SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);		(* will be set later *)
	SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, protRecBlockAdr);
	Relocate(dataBlockAdr + HeapBlockOffset);
	protRecBlock := SYSTEM.VAL(ProtRecBlock, protRecBlockAdr);
	protRecBlock.mark := currentMarkValue;
	protRecBlock.dataAdr := dataBlockAdr;
	protRecBlock.nextRealtime := NIL; (* default value NIL since module is never a realtime object *)
	Relocate(ADDRESSOF(protRecBlock.dataAdr));
	Relocate(ADDRESSOF(protRecBlock.nextRealtime));
	protRecBlock.size := blockSize;
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
	m := SYSTEM.VAL(Module, dataBlockAdr);

	Fill4(dataBlockAdr, (blockSize - SIZEOF(ProtRecBlockDesc) - 2 * BlockHeaderSize) DIV 4, 0);	(* clear everything except tag & header *)
END NewModule;

(* NewExportDesc - Allocate an export array. *)

PROCEDURE NewExportDesc*(VAR p: ExportArray;  numElems: LONGINT);
VAR adr: ADDRESS; block: ANY;
BEGIN
	NewRealArr(block, numElems, SIZEOF(ExportDesc), 1);
	adr := SYSTEM.VAL(ADDRESS, block);
	SYSTEM.PUT(adr + LenOfs, numElems);
	p := SYSTEM.VAL(ExportArray, block);
	IF exportTags = LEN(exportTagAdr) THEN GrowTable(exportTagAdr) END;
	exportTagAdr[exportTags] := adr + TypeDescOffset;  INC(exportTags);
END NewExportDesc;

PROCEDURE ArraySize*(numElems, elemSize: SIZE; numDims: LONGINT): SIZE;
VAR arrSize, arrayDataOffset: SIZE;
BEGIN
	arrSize := numElems * elemSize;
	arrayDataOffset := numDims * AddressSize + 3 * AddressSize;
	INC(arrayDataOffset,(-arrayDataOffset) MOD ArrayAlignment); (* align to multiple of ArrayAlignment *)
	RETURN arrayDataOffset + arrSize
END ArraySize;

(* NewProcOffsets - Allocate a procedure offset  table *)

PROCEDURE NewProcOffsets(VAR p: ProcOffsetTable; numElems: LONGINT);
VAR adr: ADDRESS; block: ANY;
BEGIN
	NewSys(block, ArraySize(numElems, SIZEOF(ProcOffsetEntry), 1));
	adr := SYSTEM.VAL(ADDRESS, block);
	SYSTEM.PUT(adr + LenOfs, numElems);
	p := SYSTEM.VAL(ProcOffsetTable, block)
END NewProcOffsets;

(* NewPtrOffsets - Allocate a pointer offset table *)

PROCEDURE NewPtrOffsets(VAR p: PtrTable; numElems: LONGINT);
VAR adr: ADDRESS; block: ANY;
BEGIN
	NewSys(block, ArraySize(numElems, SIZEOF(SIZE), 1));
	adr := SYSTEM.VAL(ADDRESS, block);
	SYSTEM.PUT(adr + LenOfs, numElems);
	p := SYSTEM.VAL(PtrTable, block)
END NewPtrOffsets;

(* fit memory block at given start address - relocation of addresses is done later, see RelocateMemoryBlock *)

PROCEDURE FitMemoryBlock(startAdr: ADDRESS; size: SIZE; VAR memBlock: MemoryBlock);
VAR blockSize: SIZE; recordBlock: RecordBlock; recordBlockAdr, dataBlockAdr: ADDRESS;
BEGIN
	blockSize := BlockHeaderSize + SIZEOF(RecordBlockDesc) + BlockHeaderSize + SIZEOF(MemoryBlockDesc);
	INC(blockSize,(-blockSize) MOD BlockSize); (* align to multiple of BlockSize *)

	recordBlockAdr := startAdr + BlockHeaderSize;
	SYSTEM.PUT(recordBlockAdr + TypeDescOffset, RecordBlockId);		(* temporary tag value, fixup and relocation are done later *)
	SYSTEM.PUT(recordBlockAdr + HeapBlockOffset, NilVal);
	dataBlockAdr := recordBlockAdr + SIZEOF(RecordBlockDesc) + BlockHeaderSize;
	SYSTEM.PUT(dataBlockAdr + TypeDescOffset, NilVal);					(* type descriptor tag will be filled in FixupTypeDescTags *)
	SYSTEM.PUT(dataBlockAdr + HeapBlockOffset, recordBlockAdr);		(* reference to heap block descriptor *)
	recordBlock := SYSTEM.VAL(RecordBlock, recordBlockAdr);
	recordBlock.mark := currentMarkValue;
	recordBlock.dataAdr := dataBlockAdr;
	recordBlock.size := blockSize;
	recordBlock.nextRealtime := NIL;

	memBlock := SYSTEM.VAL(MemoryBlock, dataBlockAdr);
	memBlock.next := NIL;
	memBlock.startAdr := NilVal;		(* will be set by Win32.Machine.Mod, unused for I386.Machine.Mod *)
	memBlock.size := 0;				(* do. *)
	memBlock.beginBlockAdr := startAdr + blockSize;
	memBlock.endBlockAdr := startAdr + size;
	ASSERT(memBlock.beginBlockAdr < memBlock.endBlockAdr);
	ASSERT(memBlock.beginBlockAdr MOD BlockSize = 0);
	ASSERT(memBlock.endBlockAdr MOD BlockSize = 0);
END FitMemoryBlock;

(* relocate addresses of memory block *)
PROCEDURE RelocateMemoryBlock;
VAR type: TypeDesc; memBlockAdr: ADDRESS; recordBlock: RecordBlock;
BEGIN
	type := ThisType(ModuleByName(MemBlockDescModule), MemBlockDescType);
	ASSERT(type # NIL);
	memBlockAdr := SYSTEM.VAL(ADDRESS, memBlock);
	SYSTEM.PUT(memBlockAdr + TypeDescOffset, type.tag);
	Relocate(memBlockAdr + TypeDescOffset);
	Relocate(memBlockAdr + HeapBlockOffset);
	SYSTEM.GET(memBlockAdr + HeapBlockOffset, recordBlock);
	(* type descriptor field of record block is relocated in FixupHeapBlockTags *)
	Relocate(ADDRESSOF(recordBlock.dataAdr));
	Relocate(ADDRESSOF(recordBlock.nextRealtime));
	Relocate(ADDRESSOF(memBlock.beginBlockAdr));
	Relocate(ADDRESSOF(memBlock.endBlockAdr))
END RelocateMemoryBlock;

(* InitHeap - Initialize the virtual heap. *)
PROCEDURE InitHeap;
VAR freeBlock: FreeBlock; alignOffset: SIZE;
BEGIN
	SYSTEM.NEW(heap, HeapSize);
	beginMemBlockAdr := SYSTEM.VAL(ADDRESS, heap) + HeaderSize;
	alignOffset := (-beginMemBlockAdr) MOD BlockSize;
	beginMemBlockAdr := beginMemBlockAdr + alignOffset;	(* round up to multiple of BlockSize *)
	beginAdr := beginMemBlockAdr - HeaderSize;
	endMemBlockAdr := beginMemBlockAdr + HeapSize - HeaderSize - alignOffset;
	DEC(endMemBlockAdr, endMemBlockAdr MOD BlockSize);
	ASSERT(beginMemBlockAdr < endMemBlockAdr);
	ASSERT(beginMemBlockAdr MOD BlockSize = 0);
	ASSERT(endMemBlockAdr MOD BlockSize = 0);
	(* represent linker heap as one large memory block that contains a single free heap block *)
	FitMemoryBlock(beginMemBlockAdr, endMemBlockAdr - beginMemBlockAdr, memBlock);
	freeBlock := SYSTEM.VAL(FreeBlock, memBlock.beginBlockAdr + BlockHeaderSize);
	InitFreeBlock(freeBlock, Unmarked, NilVal, memBlock.endBlockAdr - memBlock.beginBlockAdr);
END InitHeap;

(*
	Reference = {OldRef | ProcRef} .
	OldRef = 0F8X offset/n name/s {Variable} .
	ProcRef = 0F9X offset/n nofPars/n RetType procLev/1 slFlag/1 name/s {Variable} .
	RetType = 0X | Var | ArrayType | Record .
	ArrayType = 12X | 14X | 15X .	(* static array, dynamic array, open array *)
	Record = 16X .
	Variable = VarMode (Var | ArrayVar | RecordVar ) offset/n name/s .
	VarMode = 1X | 3X .	(* direct, indirect *)
	Var = 1X .. 0FX .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc, string *)
	ArrayVar = (81X .. 8EX) dim/n .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc *)
	RecordVar = (16X | 1DX) tdadr/n .	(* record, recordpointer *)
*)

(* ProcByName - Find a procedure in the reference block.  Return procedure offset, or -1 if not found. *)

PROCEDURE ProcByName (refs: Bytes;  CONST name: ARRAY OF CHAR): SIZE;
VAR i, j, m, t, pofs: LONGINT;  ch: CHAR;  found: BOOLEAN;
BEGIN
	i := 0;  m := LEN(refs^);  found := FALSE;
	ch := refs[i];  INC(i);
	WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) & ~found DO	(* proc *)
		GetNum(refs, i, pofs);
		IF ch = 0F9X THEN
			GetNum(refs, i, t);	(* nofPars *)
			INC(i, 3)	(* RetType, procLev, slFlag *)
		END;
		j := 0;  WHILE (name[j] = refs[i]) & (name[j] # 0X) DO INC(i);  INC(j) END;
		IF (name[j] = 0X) & (refs[i] = 0X) THEN
			found := TRUE
		ELSE
			WHILE refs[i] # 0X DO INC(i) END;
			INC(i);
			IF i < m THEN
				ch := refs[i];  INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & ((ch = 1X) OR (ch = 3X)) DO	(* var *)
					ch := refs[i];  INC(i);	(* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum(refs, i, t)	(* dim/tdadr *)
					END;
					GetNum(refs, i, t);	(* vofs *)
					REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* vname *)
					ch := refs[i];  INC(i)	(* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END
	END;
	IF ~found THEN pofs := -1 END;
	RETURN SYSTEM.VAL(SIZE, pofs)
END ProcByName;

(* GetProc - Return procedure address. *)

PROCEDURE GetProc(m: Module; i: LONGINT; CONST mod, proc: ARRAY OF CHAR): ADDRESS;
VAR adr: SIZE;
BEGIN
	IF m.name # mod THEN	(* fixup not in current module *)
		m := ModuleByName(mod)	(* must have been loaded already *)
	END;
	adr := ProcByName(m.refs, proc);
	IF  ~getProcs[i] THEN
		String("GetProc "); String(mod); Char("."); String(proc); Address(adr); Ln;
		getProcs[i] := TRUE
	END;
	ASSERT(adr # -1);
	RETURN ADDRESSOF(m.code[0]) + adr
END GetProc;

(* GetKernelProc - Return the specified kernel procedure. *)

PROCEDURE GetKernelProc*(m: Module; num: LONGINT): ADDRESS;
VAR adr: ADDRESS;
BEGIN
	CASE num OF
		|243: adr := GetProc(m, 8, "Modules", "GetProcedure")
		|246: adr := GetProc(m, 1, "Objects", "Unlock")
		|247: adr := GetProc(m, 2, "Objects", "Lock")
		|249: adr := GetProc(m, 3, "Objects", "Await")
		|250: adr := GetProc(m, 4, "Objects", "CreateProcess")
		|251: adr := GetProc(m, 5, "Heaps", "NewArr")
		|252: adr := GetProc(m, 6, "Heaps", "NewSys")
		|253: adr := GetProc(m, 7, "Heaps", "NewRec")
	END;
	RETURN adr
END GetKernelProc;

(** Dump the log text .  Use in case of trap. *)

PROCEDURE WriteLog*;
BEGIN
	logWriter.Update(); logFile.Update(); Files.Register(logFile); logFile := NIL; logWriter := NIL;
	KernelLog.String(LogName); KernelLog.Ln;
END WriteLog;


BEGIN
	suffix := DefaultExtension; prefix := "";
	logFile := NIL; logWriter := NIL;
	currentMarkValue := Unmarked + 1; (* one higher than the mark value of the free block *);
	NEW(relocateAdr, 2048);  NEW(exportTagAdr, 32)
END Linker0.

(*
19.05.98	pjm	Started
23.05.99	pjm	Fixed Find for non-sorted tables
*)

Linker0.Find 10A3C4H

Linker0.WriteLog

SystemTools.Free PELinker Linker1 Linker0 ~
