MODULE Modules;	(** AUTHOR "pjm"; PURPOSE "Modules and types"; *)

IMPORT SYSTEM, Trace, Machine, Heaps, Runtime;

CONST
	Ok* = 0;

	AddressSize = SIZEOF (ADDRESS);	(* architecture dependent size of addresses in bytes *)

	MaxTags* = 16;	(* in type descriptor *)

	(** type descriptor field offsets relative to root (middle) *)
	Tag0Ofs* = -AddressSize * 2;	(** first tag *)
	Mth0Ofs* = Tag0Ofs - AddressSize*MaxTags;	(** first method *)
	Ptr0Ofs* = AddressSize;	(** first pointer offset *)

	MaxObjFormats = 5;	(* maximum number of object file formats installed *)

	(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)
	ProtTypeBit* = Heaps.ProtTypeBit;

	None* = 0; PowerDown* = 1; Reboot* = 2;

	ClearCode = TRUE;

	InitTableLen = 1024;
	InitPtrTableLen = 2048;

	DefaultContext* = "A2";
	NoLoader=3400;

	TraceBoot=FALSE;

TYPE
	(* definitions for object-model loader support *)
	Name* = ARRAY 32 OF CHAR;
	DynamicName* = POINTER {UNSAFE} TO ARRAY 256 OF CHAR;
	
	Command* = RECORD
		(* Fields exported for initialization by loader/linker only! Consider read-only! *)
		name*: Name; (* name of the procedure *)
		argTdAdr*, retTdAdr* : ADDRESS; (* address of type descriptors of argument and return type, 0 if no type *)
		entryAdr* : ADDRESS; (* entry address of procedure *)
	END;

	ExportDesc* = RECORD
		fp*: ADDRESS;
		name* {UNTRACED}: DynamicName;
		adr*: ADDRESS;
		exports*: LONGINT;
		dsc* {UNTRACED}: ExportArray
	END;
	ExportArray* = POINTER {UNSAFE} TO ARRAY OF ExportDesc;

	Bytes* = POINTER TO ARRAY OF CHAR;

	TerminationHandler* = PROCEDURE;

	
	EntryType*=RECORD
		(* classes:
			0: no Type
			1:  ObjectType
			2:	NilType
			3:	AnyType
			4:	ByteType
			5:	AddressType
			6:	SizeType
			7:	BooleanType
			8:	SetType
			9:	CharacterType
			10:	RangeType
			11:	SignedInteger
			12:	UnsignedIntegerType
			13:	FloatType
			14:	ComplexType
			15: StringType
			16: EnumerationType
			17: ArrayType
			18: MathArrayType
			19: PointerType
			20: PortType
			21: RecordType
			22: CellType
			23: ProcedureType		 
		*)
		class*: SHORTINT; 
		(* size in bits *)
		size*: INTEGER;
		type*: ADDRESS; (* type descriptor or additional information *)
	END;

	FieldEntry*= RECORD
		name*: DynamicName; (*! change to dynamic name ? *)
		offset*: SIZE; (* offset of this type *)
		type*: EntryType;
		flags*: SET;
	END;
	FieldEntries*= POINTER TO ARRAY OF FieldEntry;
	ProcedureEntries*=POINTER TO ARRAY OF ProcedureEntry;
	
	ProcedureEntry*=RECORD
		name*: DynamicName; 
		address*: ADDRESS;
		size*: SIZE;
		parameters*: FieldEntries;
		variables*: FieldEntries;
		procedures*: ProcedureEntries;
		returnType*: EntryType;
	END;

	TypeDesc* = POINTER TO RECORD   (* ug: adapt constant TypeDescRecSize if this type is changed !!! *)
		descSize: LONGINT;
		sentinel: LONGINT;	(* = MPO-4 *)
		tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
		flags*: SET;
		mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
		name*: Name;
		fields*: POINTER TO ARRAY OF FieldEntry;
		procedures*: POINTER TO ARRAY OF ProcedureEntry;
	END;

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

	PtrTable* = POINTER TO ARRAY OF ADDRESS;

	ProcOffsetEntry* = RECORD
		data*: ProcTableEntry;	(* code offsets of procedures *)
		startIndex*: LONGINT;	(* index into global ptrOffsets table *)
	END;

	ProcOffsetTable* = POINTER TO ARRAY OF ProcOffsetEntry;

	Module* = OBJECT (Heaps.RootObject)	(* cf. Linker0 & Heaps.WriteType *)
		VAR
			next*: Module;	(** once a module is published, all fields are read-only *)
			name*: Name;
			init, published: BOOLEAN;
			refcnt*: LONGINT; (* counts loaded modules that import this module *)
			sb*: ADDRESS; (* reference address between constants and local variables *)
			entry*: POINTER TO ARRAY OF ADDRESS;
			command*: POINTER TO ARRAY OF Command;
			ptrAdr*: POINTER TO ARRAY OF ADDRESS;
			typeInfo*: POINTER TO ARRAY OF TypeDesc;	(* traced explicitly in FindRoots *)
			module*: POINTER TO ARRAY OF Module; (* imported modules: for reference counting *)
			procTable*: ProcTable; (* information inserted by loader, removed after use in Publish *)
			ptrTable*: PtrTable;  (* information inserted by loader, removed after use in Publish *)
			data*, code*, staticTypeDescs* (* ug *), refs*: Bytes;
			export*: ExportDesc;
			term*: TerminationHandler;
			exTable*: ExceptionTable;
			noProcs*: LONGINT;	(* used for removing proc offsets when unloading module *)
			firstProc*: ADDRESS; (* procedure with lowest PC in module, also used for unloading *)
			maxPtrs*: LONGINT;
			crc*: LONGINT;
			body*: PROCEDURE;

		PROCEDURE FindRoots;	(* override *)
		VAR i: LONGINT; ptr: ANY; (* moduleName: Name; *) false: BOOLEAN;
		BEGIN
			false := FALSE; IF false THEN BEGIN{EXCLUSIVE} END END; (* trick to make a module a protected record ... *)
			IF published THEN	(* mark global pointers *)
				(* moduleName := name; *)
				FOR i := 0 TO LEN(ptrAdr) - 1 DO
					SYSTEM.GET (ptrAdr[i], ptr);
					IF ptr # NIL THEN Heaps.Mark(ptr) END
				END;
				Heaps.AddRootObject(next);
				(* all other fields are being traversed by Mark of the Garbage Collector *)
			END;
		END FindRoots;

	END Module;

	LoaderProc* = PROCEDURE (CONST name, fileName: ARRAY OF CHAR; VAR res: LONGINT;
			VAR msg: ARRAY OF CHAR): Module;	(** load an object file *)

VAR
	extension-: ARRAY MaxObjFormats, 8 OF CHAR;
	loader: ARRAY MaxObjFormats OF LoaderProc;
	numLoaders: LONGINT;
	kernelProc*: ARRAY 11 OF ADDRESS;	(** kernel call addresses for loader *)

	freeRoot*: Module;	(** list of freed modules (temporary) *)

	(* the following two variables are initialized by Linker *)
	root-: Module;	(** list of modules (read-only) *)
	initBlock: ANY;	(* placeholder - anchor for module init code (initialized by linker) *)
	procOffsets-: ProcOffsetTable;	(* global table containing procedure code offsets and pointer offsets, sorted in ascending order of procedure code offsets *)
	numProcs: LONGINT;			(* number of entries in procOffsets *)
	ptrOffsets-: PtrTable;
	numPtrs: LONGINT;
	shutdown*: LONGINT;	(** None, Reboot, PowerDown *)
	trace: BOOLEAN;
	register: RECORD
		first, last: Module;
	END;

(** Register a module loader. *)

PROCEDURE AddLoader*(CONST ext: ARRAY OF CHAR; proc: LoaderProc);
BEGIN
	Machine.Acquire(Machine.Modules);
	ASSERT(numLoaders < MaxObjFormats);
	loader[numLoaders] := proc;
	COPY(ext, extension[numLoaders]);
	ASSERT(ext = extension[numLoaders]);	(* no overflow *)
	INC(numLoaders);
	Machine.Release(Machine.Modules)
END AddLoader;

(** Remove a module loader. *)
PROCEDURE RemoveLoader*(CONST ext: ARRAY OF CHAR; proc: LoaderProc);
VAR i, j: LONGINT;
BEGIN
	Machine.Acquire(Machine.Modules);
	i := 0;
	WHILE (i # numLoaders) & ((loader[i] # proc) OR (extension[i] # ext)) DO INC(i) END;
	IF i # numLoaders THEN
		FOR j := i TO numLoaders - 2 DO
			loader[j] := loader[j + 1]; extension[j] := extension[j + 1];
		END;
		loader[numLoaders - 1] := NIL; extension[numLoaders - 1] := "";
		DEC(numLoaders)
	END;
	Machine.Release(Machine.Modules)
END RemoveLoader;

(** Append string from to to, truncating on overflow. *)
PROCEDURE Append*(CONST from: ARRAY OF CHAR; VAR to: ARRAY OF CHAR);
VAR i, j, m: LONGINT;
BEGIN
	j := 0; WHILE to[j] # 0X DO INC(j) END;
	m := LEN(to)-1;
	i := 0; WHILE (from[i] # 0X) & (j # m) DO to[j] := from[i]; INC(i); INC(j) END;
	to[j] := 0X
END Append;


(** Add a module to the pool of accessible modules, or return named module. *)
PROCEDURE Publish*(VAR m: Module; VAR new: BOOLEAN);
VAR n: Module; i: LONGINT; a: ANY;
BEGIN
	(*
	ASSERT((m.code # NIL) & (LEN(m.code^) > 0));
	*)
	Machine.Acquire(Machine.Modules);
	n := root; WHILE (n # NIL) & (n.name # m.name) DO 	n := n.next END;
	IF n # NIL THEN	(* module with same name exists, return it and ignore new m *)
		m := n; new := FALSE
	ELSE
		IF TraceBoot THEN
			Machine.Acquire(Machine.TraceOutput);
			Trace.String("publish "); Trace.String(m.name);
			(*
			a := m;
			IF a IS Heaps.RootObject THEN Trace.String(" IS RootObj") END;
			IF a IS Module THEN Trace.String(" IS Module"); END;
			*)
			Trace.Ln;
			Machine.Release(Machine.TraceOutput);
		END;
		m.published := TRUE;
		m.next := root; root := m;
		m.refcnt := 0;
		(*! reactivate: does not work with statically linked image 		
		SortProcTable(m);
		InsertProcOffsets(m.procTable, m.ptrTable, m.maxPtrs);


		(*! yes: used, cf. ThisModuleByAdr *)
		m.procTable := NIL; m.ptrTable := NIL; (* not used any more as entered in global variable *)
		*)
		
		IF m.module # NIL THEN
		FOR i := 0 TO LEN(m.module)-1 DO INC(m.module[i].refcnt) END;
		END;

		new := TRUE;
	END;
	Machine.Release(Machine.Modules)
END Publish;

(*
(* runtime call for new compiler -- called by body of loaded module *)
PROCEDURE PublishThis*(m: Module): BOOLEAN;
VAR new: BOOLEAN; i:LONGINT; module: Module;
BEGIN
	IF m = SELF THEN
		RETURN Runtime.InsertModule(SYSTEM.VAL(ADDRESS,m))
	END;
	Publish(m,new);
	RETURN new
END PublishThis;
*)

PROCEDURE Initialize*(VAR module: Module);
VAR new: BOOLEAN;
BEGIN
	Publish (module, new);
	IF new THEN
		IF module.body # NIL THEN
			Machine.FlushDCacheRange(ADDRESSOF(module.code[0]), LEN(module.code));
			module.body
		END;
		module.init := TRUE;
	END;
END Initialize;

VAR callagain: BOOLEAN;

PROCEDURE Initialize0*(module: Module);
VAR new: BOOLEAN;
BEGIN
	(* module MUST have been removed from register list and must not have been initialized yet *)
	ASSERT(module.next = NIL);
	Publish (module, new);
	callagain := FALSE;
	IF new THEN
		IF module.name = "Objects" THEN
			callagain := TRUE;
			module.init := TRUE;
		END;
		IF module.body # NIL THEN module.body END;
		IF callagain THEN
			PublishRegisteredModules (* does not return on intel architecture. Returns on ARM but looses procedure stack frame: we are not allowed to refer to local variables after this *)
		ELSE
			module.init := TRUE;
		END;
	END;
END Initialize0;

(** Return the named module or NIL if it is not loaded yet. *)
PROCEDURE ModuleByName*(CONST name: ARRAY OF CHAR): Module;
VAR m: Module;
BEGIN
	Machine.Acquire(Machine.Modules);
	m := root; WHILE (m # NIL) & (m.name # name) DO m := m.next END;
	Machine.Release(Machine.Modules);
	RETURN m
END ModuleByName;

(* Generate a module file name. *)
PROCEDURE GetFileName(CONST name, extension: ARRAY OF CHAR; VAR fileName: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
	i := 0; WHILE name[i] # 0X DO fileName[i] := name[i]; INC(i) END;
	j := 0; WHILE extension[j] # 0X DO fileName[i] := extension[j]; INC(i); INC(j) END;
	fileName[i] := 0X
END GetFileName;

	PROCEDURE SortProcTable(m: Module);
		VAR i, j, min : LONGINT;

		PROCEDURE Max(a,b: LONGINT): LONGINT;
		BEGIN
			IF a > b THEN RETURN a ELSE RETURN b END;
		END Max;


		PROCEDURE SwapProcTableEntries(p, q : LONGINT);
		VAR procentry : ProcTableEntry;
			k, i, basep, baseq: LONGINT; ptr: SIZE;
		BEGIN
			k := Max(m.procTable[p].noPtr, m.procTable[q].noPtr);
			IF k > 0 THEN (* swap entries in ptrTable first *)
				basep := p * m.maxPtrs; baseq := q * m.maxPtrs;
				FOR i := 0 TO k - 1 DO
					ptr := m.ptrTable[basep + i];
					m.ptrTable[basep + i] := m.ptrTable[baseq + i];
					m.ptrTable[baseq + i] := ptr
				END
			END;
			procentry := m.procTable[p];
			m.procTable[p] := m.procTable[q];
			m.procTable[q] := procentry
		END SwapProcTableEntries;

		PROCEDURE NormalizePointerArray;
		VAR ptrTable: PtrTable; i,j,k: LONGINT;
		BEGIN
			NEW(ptrTable, m.maxPtrs*m.noProcs);
			k := 0;
			FOR i := 0 TO LEN(m.procTable)-1 DO
				FOR j := 0 TO m.procTable[i].noPtr-1 DO
					ptrTable[i*m.maxPtrs+j] := m.ptrTable[k];
					INC(k);
				END;
			END;
			m.ptrTable := ptrTable;
		END NormalizePointerArray;


	BEGIN
		NormalizePointerArray;
		FOR i := 0 TO m.noProcs - 2 DO
			min := i;
			FOR j := i + 1 TO m.noProcs - 1 DO
				IF m.procTable[j].pcFrom < m.procTable[min].pcFrom THEN min:= j END
			END;
			IF min # i THEN SwapProcTableEntries(i, min) END
		END
	END SortProcTable;

	PROCEDURE SelectionSort(exTable: ExceptionTable);
	VAR
		p, q, min: LONGINT;
		entry: ExceptionTableEntry;
	BEGIN
		FOR p := 0 TO LEN(exTable) - 2 DO
			min := p;
			FOR q := p + 1 TO LEN(exTable) - 1 DO
				IF exTable[min].pcFrom > exTable[q].pcFrom THEN min := q END;
				entry := exTable[min]; exTable[min] := exTable[p]; exTable[p] := entry;
			END
		END
	END SelectionSort;

(** Load the module if it is not already loaded. *)	(* Algorithm J. Templ, ETHZ, 1994 *)
PROCEDURE ThisModule*(CONST name: ARRAY OF CHAR; VAR res: LONGINT; VAR msg: ARRAY OF CHAR): Module;
TYPE Body = PROCEDURE;
VAR m, p: Module; fileName: ARRAY 64 OF CHAR; body: Body; new: BOOLEAN; i: LONGINT;
BEGIN
	res := Ok; msg[0] := 0X; m := ModuleByName(name);
	IF m = NIL THEN
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String(">"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		IF numLoaders = 0 THEN
			res := NoLoader; m := NIL;
		ELSE
			i:= 0;
			REPEAT
				GetFileName(name, extension[i], fileName);
				m := loader[i](name, fileName, res, msg);
				INC(i);
			UNTIL (m # NIL) OR (i=numLoaders);
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("?"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		p := m;
		IF (m # NIL) & ~m.published THEN	(* no race on m.published, as update is done below in Publish *)
			Initialize(m);
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			IF m = NIL THEN
				Trace.String("could not load "); Trace.StringLn(name)
			ELSIF ~m.published THEN
				Trace.String("not published "); Trace.StringLn(name)
			ELSE
				Trace.String("<"); Trace.StringLn (name);
			END;
			Machine.Release (Machine.TraceOutput);
		END;
	END;
	RETURN m
END ThisModule;

(** Return the module that contains code address pc or NIL if not found. Can also return freed modules. Non-blocking version for reflection *)
PROCEDURE ThisModuleByAdr0*(pc: ADDRESS): Module;
VAR m: Module; cbase, dbase: ADDRESS; i: LONGINT; found: BOOLEAN; list: LONGINT;
BEGIN
	list := 0; found := FALSE;
	REPEAT
		CASE list OF
			0: m := root
			|1: m := freeRoot
		END;
		WHILE (m # NIL) & ~found DO
			IF m.procTable # NIL THEN
				i := 0;
				WHILE ~found & (i<LEN(m.procTable)) DO
					IF (m.procTable[i].pcFrom <= pc) & (pc <m.procTable[i].pcLimit) THEN
						found := TRUE;
					END;
					INC(i);
				END;
			END;
			IF ~found THEN
				m := m.next;
			END;
		END;
		INC(list)
	UNTIL found OR (list=2);
	RETURN m
END ThisModuleByAdr0;

(** Return the module that contains code address pc or NIL if not found. Can also return freed modules. *)
PROCEDURE ThisModuleByAdr*(pc: ADDRESS): Module;
VAR m: Module; cbase, dbase: ADDRESS; i: LONGINT; found: BOOLEAN; list: LONGINT;
BEGIN
	Machine.Acquire(Machine.Modules);
	m := ThisModuleByAdr0(pc);
	Machine.Release(Machine.Modules);
	RETURN m
END ThisModuleByAdr;

CONST ModuleInitTimeout = HUGEINT(3000000000); (* Timeout for waiting until a module get initialized, 3 seconds for 1 GHz CPU *)

(*	Retrieve a procedure given a module name, the procedure name and some type information (kernel call) *)
PROCEDURE GetProcedure*(CONST moduleName, procedureName : ARRAY OF CHAR; argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
VAR module : Module; ignoreMsg : ARRAY 32 OF CHAR; i, res : LONGINT; t: HUGEINT;
BEGIN
	module := ThisModule(moduleName, res, ignoreMsg);
	IF (res = Ok) THEN
		(*! 
			module body must have been called (see note at the end of this module);
			return NIL if the module does not get initialized within the specified timeout
		*)
		IF ~module.init THEN
			t := Machine.GetTimer();
			WHILE ~module.init & (Machine.GetTimer() - t < ModuleInitTimeout) DO END;
			IF ~module.init THEN (* timeout has expired *)
				RETURN;
			END;
		END;

		Machine.Acquire(Machine.Modules);
		i := 0; entryAdr := Heaps.NilVal;
		WHILE (entryAdr = Heaps.NilVal) & (i # LEN(module.command^)) DO
			IF (module.command[i].name = procedureName) & (module.command[i].argTdAdr = argTdAdr) & (module.command[i].retTdAdr = retTdAdr) THEN
				entryAdr := module.command[i].entryAdr;
			END;
			INC(i)
		END;
		Machine.Release(Machine.Modules);
	END;
END GetProcedure;

(** Return the named type *)
PROCEDURE ThisType*(m: Module; CONST name: ARRAY OF CHAR): TypeDesc;
VAR i: LONGINT; type: TypeDesc;
BEGIN
	Machine.Acquire(Machine.Modules);
	i := 0;
	WHILE (i < LEN(m.typeInfo)) & (m.typeInfo[i].name # name) DO INC(i) END;
	IF i = LEN(m.typeInfo) THEN
		type := NIL
	ELSE
		type := m.typeInfo[i]
	END;
	Machine.Release(Machine.Modules);
	RETURN type
END ThisType;

PROCEDURE ThisTypeByAdr*(adr: ADDRESS; VAR m: Module; VAR t: TypeDesc);
BEGIN
	IF adr # 0 THEN
		Machine.Acquire(Machine.Modules);
		SYSTEM.GET (adr + Heaps.TypeDescOffset, adr);
		t := SYSTEM.VAL(TypeDesc, adr);
		m := t.mod;
		Machine.Release(Machine.Modules)
	ELSE
		m := NIL; t := NIL
	END
END ThisTypeByAdr;

(** create a new object given its type descriptor *)
PROCEDURE NewObj*(t : TypeDesc; isRealtime: BOOLEAN) : ANY;
VAR x : ANY;
BEGIN
	Heaps.NewRec(x, SYSTEM.VAL (ADDRESS, t.tag), isRealtime);
	RETURN x;
END NewObj;

(** return the type descriptor of an object *)
PROCEDURE TypeOf*(obj : ANY): TypeDesc;
VAR
	m : Module;
	t : TypeDesc;
	adr : ADDRESS;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.TypeDescOffset, adr);
	ThisTypeByAdr(adr, m, t);
	RETURN t;
END TypeOf;

PROCEDURE FindPos(key: ADDRESS; VAR pos: LONGINT): BOOLEAN;
VAR l, r, x: LONGINT; isHit: BOOLEAN;
BEGIN
	IF numProcs > 0 THEN
		l := 0; r := numProcs - 1;
		REPEAT
			x := (l + r) DIV 2;
			IF key < procOffsets[x].data.pcFrom THEN r := x - 1 ELSE l := x + 1 END;
			isHit := ((procOffsets[x].data.pcFrom <= key) & (key < procOffsets[x].data.pcLimit));
		UNTIL isHit OR (l > r);
		IF isHit THEN
			pos := x;
			RETURN TRUE
		END;
	END;
	RETURN FALSE
END FindPos;

(** searches for the given pc in the global ProcKeyTable, if found it returns the corresponding data element *)
PROCEDURE FindProc*(pc: ADDRESS; VAR data: ProcTableEntry; VAR index: LONGINT; VAR success: BOOLEAN);
VAR x: LONGINT;
BEGIN
	success := FindPos(pc, x);
	IF success THEN
		data := procOffsets[x].data;
		index := procOffsets[x].startIndex
	END
END FindProc;

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
			isHit := ((x = 0) OR (procOffsets[x - 1].data.pcLimit <= entry.pcFrom)) & (entry.pcLimit <= procOffsets[x].data.pcFrom);
		UNTIL isHit OR (l > r);
		IF isHit THEN
			pos := x; success := TRUE
		ELSE
			IF (x = numProcs - 1) & (procOffsets[x].data.pcLimit <= entry.pcFrom) THEN
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
	IF procTable # NIL THEN
		FOR i := 0 TO LEN(procTable) - 1 DO
			num := num + procTable[i].noPtr
		END;
	END;
	RETURN num
END NumTotalPtrs;


(* insert the procedure code offsets and pointer offsets of a single module into the global table *)
PROCEDURE InsertProcOffsets(procTable: ProcTable; ptrTable: PtrTable; maxPtr: LONGINT);
VAR success: BOOLEAN; i, j, pos, poslast, newLen, num,numberPointer: LONGINT;
	temp: ADDRESS;
	newProcOffsets: ProcOffsetTable; newPtrOffsets: PtrTable;
	ptrOfsLen,procOfsLen: LONGINT;
BEGIN
	(* this procedure is called by procedure Publish only and is protected by the Machine.Modules lock *)
	IF procTable=NIL THEN RETURN END;
	IF ptrTable=NIL THEN RETURN END;
	IF LEN(procTable) > 0 THEN
		IF procOffsets = NIL THEN procOfsLen := 0 ELSE procOfsLen := LEN(procOffsets) END;
		IF numProcs + LEN(procTable) > procOfsLen THEN
			newLen := procOfsLen + InitTableLen;
			WHILE numProcs + LEN(procTable) > newLen DO newLen := newLen + InitTableLen END;
			NEW(newProcOffsets, newLen);
			FOR i := 0 TO numProcs - 1 DO
				newProcOffsets[i] := procOffsets[i]
			END;
			procOffsets := newProcOffsets
		END;
		num := NumTotalPtrs(procTable);
		IF ptrOffsets = NIL THEN ptrOfsLen := 0 ELSE ptrOfsLen := LEN(ptrOffsets) END;
		IF numPtrs + num > ptrOfsLen THEN
			newLen := ptrOfsLen + InitPtrTableLen;
			WHILE numPtrs + num > newLen DO newLen := newLen + InitPtrTableLen END;
			NEW(newPtrOffsets, newLen);
			FOR i := 0 TO numPtrs - 1 DO
				newPtrOffsets[i] := ptrOffsets[i]
			END;
			ptrOffsets := newPtrOffsets
		END;
		success := FindInsertionPos(procTable[0], pos); success := success & FindInsertionPos(procTable[LEN(procTable) - 1], poslast);
		IF (~success) OR (pos # poslast) THEN Machine.Release(Machine.Modules); HALT(2001) END;

		FOR i := numProcs - 1 TO pos BY -1 DO procOffsets[i + LEN(procTable)] := procOffsets[i] END;
		numberPointer := 0;
		FOR i := 0 TO LEN(procTable) - 1 DO
			procOffsets[pos + i].data := procTable[i];
			procOffsets[pos + i].startIndex := numPtrs; (* this field is never accessed in case of procTable[i].noPtr = 0, so we may as well put numPtrs in there *)
			FOR j := 0 TO procTable[i].noPtr - 1 DO
				(*
				temp := ptrTable[numberPointer]; INC(numberPointer);
				*)
				temp := ptrTable[i * maxPtr + j];
				ptrOffsets[numPtrs + j] := temp;
			END;
			numPtrs := numPtrs + procTable[i].noPtr;
		END;
		numProcs := numProcs + LEN(procTable);
	END
END InsertProcOffsets;

(** deletes a sequence of entries given in procTable from the global procOffsets table - the table remains sorted,
	this procedure is called within AosLocks.AosModules, so no lock is taken here. *)
PROCEDURE DeleteProcOffsets(firstProcPC: ADDRESS; noProcsInMod: LONGINT);
VAR pos, i, noPtrsInMod, oldIndex: LONGINT; success: BOOLEAN;
BEGIN
	IF noProcsInMod > 0 THEN
		success := FindPos(firstProcPC, pos);
		IF success THEN
			(* delete entries in ptrOffsets first *)
			noPtrsInMod := 0;
			FOR i := pos TO pos + noProcsInMod - 1 DO
				noPtrsInMod := noPtrsInMod + procOffsets[i].data.noPtr
			END;
			oldIndex := procOffsets[pos].startIndex;
			FOR i := procOffsets[pos].startIndex + noPtrsInMod TO numPtrs - 1 DO
				ptrOffsets[i - noPtrsInMod] := ptrOffsets[i]
			END;
			numPtrs := numPtrs - noPtrsInMod;
			(* delete entries in procOffsets *)
			FOR i := pos + noProcsInMod TO numProcs - 1 DO
				procOffsets[i - noProcsInMod] := procOffsets[i]
			END;
			numProcs := numProcs - noProcsInMod;
			(* adjust startIndex of procOffsets entries greater than those that have been deleted *)
			FOR i := 0 TO numProcs - 1 DO
				IF procOffsets[i].startIndex > oldIndex THEN
					procOffsets[i].startIndex := procOffsets[i].startIndex - noPtrsInMod
				END
			END;
		ELSE
			Trace.String("corrupt global procOffsets table"); Trace.Ln;
			Machine.Release(Machine.Modules);
			HALT(2000)
		END
	END
END DeleteProcOffsets;

(** Install procedure to execute when module is freed or shut down. The handler can distinguish the two cases by checking Modules.shutdown. If it is None, the module is being freed, otherwise the system is being shut down or rebooted. Only one handler may be installed per module. The last handler installed is active. *)
PROCEDURE InstallTermHandler*(h: TerminationHandler);
VAR m: Module;
BEGIN
	m := ThisModuleByAdr(SYSTEM.VAL (ADDRESS, h));
	IF m # NIL THEN
		m.term := h	(* overwrite existing handler, if any *)
	END
END InstallTermHandler;

(** Free a module. The module's termination handler, if any, is called first. Then all objects that have finalizers in this module are finalized (even if they are still reachable). Then the module's data and code are invalidated. *)
PROCEDURE FreeModule*(CONST name: ARRAY OF CHAR; VAR res: LONGINT; VAR msg: ARRAY OF CHAR);
VAR p, m: Module; term: TerminationHandler; i: LONGINT;
BEGIN
	m := ModuleByName(name);
	IF (m # NIL) & (m.refcnt = 0) THEN	(* will be freed below *)
		IF m.term # NIL THEN	(* call termination handler *)
			term := m.term; m.term := NIL; term	(* may trap *)
		END;
		Heaps.CleanupModuleFinalizers(ADDRESSOF(m.code[0]), LEN(m.code), m.name)
	END;
	res := Ok; msg[0] := 0X;
	Machine.Acquire(Machine.Modules);
	Trace.String("Acquired Machine.Modules x"); Trace.Ln;
	p := NIL; m := root;
	WHILE (m # NIL) & (m.name # name) DO p := m; m := m.next END;
	Trace.String("Acquired Machine.Modules y"); Trace.Ln;

	IF m # NIL THEN
		Trace.String("found module"); Trace.Ln;
		IF m.refcnt = 0 THEN	(* free the module *)
			FOR i := 0 TO LEN(m.module)-1 DO DEC(m.module[i].refcnt) END;
			m.init := FALSE;	(* disallow ThisCommand *)
			Append("?", m.name);
			(* move module to free list *)
			IF p = NIL THEN root := root.next ELSE p.next := m.next END;
			m.next := freeRoot; freeRoot := m;
			(* clear global pointers and code *)
			IF m.ptrAdr # NIL THEN
				Trace.String("ptradr del"); Trace.Ln;
				FOR i := 0 TO LEN(m.ptrAdr)-1 DO SYSTEM.PUT (m.ptrAdr[i], NIL) END;
			END;
			IF ClearCode & (m.code # NIL) THEN
				Trace.String("clear code"); Trace.Ln;
				FOR i := 0 TO LEN(m.code)-1 DO m.code[i] := 0CCX END
			END;
			Trace.String("clear code f"); Trace.Ln;
			(* remove references to module data *)
			m.published := FALSE;
			m.entry := NIL; m.command := NIL; m.ptrAdr := NIL;
			(* do not clear m.type or m.module, as old heap block tags might reference type descs indirectly. *) (* m.staticTypeDescs, m.typeInfo ??? *)
			(* do not clear m.data or m.code, as they are used in ThisModuleByAdr (for debugging). *)
			(* do not clear m.refs, as they are used in Traps (for debugging). *)
			m.export.dsc := NIL; m.exTable := NIL;
			(*Trace.String("delete proc offsets"); Trace.Ln;
			DeleteProcOffsets(m.firstProc, m.noProcs);
			*)
		ELSE
			res := 1901;	(* can not free module in use *)
			COPY(name, msg); Append(" reference count not zero", msg)
		END
	ELSE
		res := 1902;	(* module not found *)
		COPY(name, msg); Append(" not found", msg)
	END;
	Machine.Release(Machine.Modules)
END FreeModule;

(** Shut down all modules by calling their termination handlers and then call Machine.Shutdown. *)
PROCEDURE Shutdown*(code: LONGINT);
VAR m: Module; term: TerminationHandler;
BEGIN
	IF code # None THEN
		LOOP
			Machine.Acquire(Machine.Modules);
			m := root; WHILE (m # NIL) & (m.term = NIL) DO m := m.next END;
			IF m # NIL THEN term := m.term; m.term := NIL END;
			Machine.Release(Machine.Modules);
			IF m = NIL THEN EXIT END;
			IF trace THEN
				Machine.Acquire (Machine.TraceOutput);
				Trace.String("TermHandler "); Trace.StringLn (m.name);
				Machine.Release (Machine.TraceOutput);
			END;
			term	(* if this causes exception or hangs, another shutdown call will retry *)
		END;
		(* clean up finalizers *)
		m := root;
		WHILE m # NIL DO
			IF LEN(m.code)>0 THEN
				Heaps.CleanupModuleFinalizers(ADDRESSOF(m.code[0]), LEN(m.code), m.name)
			END;
			m := m.next
		END;
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.StringLn ("Modules.Shutdown finished");
			Machine.Release (Machine.TraceOutput);
		END;
		Machine.Shutdown(code = Reboot)	(* does not return *)
	END
END Shutdown;

(* Is this PC handled in the corresponding module. deep = scan the whole stack. *)
PROCEDURE IsExceptionHandled*(VAR pc, fp: ADDRESS; deep: BOOLEAN): BOOLEAN;
VAR
	handler: ADDRESS;
BEGIN
	IF deep THEN
		handler := GetExceptionHandler(pc);
		IF handler # -1 THEN (* Handler in the current PAF *)
			RETURN TRUE
		ELSE
			WHILE (fp # 0) & (handler = -1) DO
				SYSTEM.GET (fp + 4, pc);
				pc := pc - 1; 	(* CALL instruction, machine dependant!!! *)
				handler := GetExceptionHandler(pc);
				SYSTEM.GET (fp, fp) (* Unwind PAF *)
			END;
			IF handler = -1 THEN RETURN FALSE 	ELSE pc := handler; RETURN TRUE END
		END
	ELSE
		RETURN GetExceptionHandler(pc) # -1
	END
END IsExceptionHandled;

(* Is this PC handled in the corresponding module. If the PC is handled the PC of the
	handler is return else -1 is return. There is no problem concurrently accessing this
	procedure, there is only reading work. *)
PROCEDURE GetExceptionHandler*(pc: ADDRESS): ADDRESS;
VAR
	m: Module;

	PROCEDURE BinSearch(exTable: ExceptionTable; key: ADDRESS): ADDRESS;
	VAR
		x, l, r: LONGINT;
	BEGIN
		l := 0; r:=LEN(exTable) - 1;
		REPEAT
			x := (l + r) DIV 2;
			IF key < exTable[x].pcFrom THEN r := x - 1 ELSE l := x + 1 END;
		UNTIL ((key >= exTable[x].pcFrom) & (key < exTable[x].pcTo) ) OR (l > r);

		IF (key >= exTable[x].pcFrom) & (key < exTable[x].pcTo) THEN
			RETURN exTable[x].pcHandler;
		ELSE
			RETURN -1;
		END
	END BinSearch;

BEGIN
	m := ThisModuleByAdr(pc);
	IF (m # NIL) & (m.exTable # NIL) & (LEN(m.exTable) > 0) THEN
		RETURN BinSearch(m.exTable, pc);
	END;
	RETURN -1;
END GetExceptionHandler;

(** fof: to make custom solutions to the race process, described below, possible. This is not a solution to the generic problem !! *)
PROCEDURE Initialized*(m: Module): BOOLEAN;
BEGIN
	RETURN m.init;
END Initialized;

(** Return the specified kernel procedure address. *)
PROCEDURE GetKernelProc*(num: LONGINT): ADDRESS;
VAR adr: ADDRESS;
BEGIN
	adr := kernelProc[253-num];
	ASSERT(adr # 0);
	RETURN adr
END GetKernelProc;

PROCEDURE Register- (module {UNTRACED}: Module);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF register.first = NIL THEN
		register.first := module;
	ELSE
		register.last.next := module;
	END;
	register.last := module;
END Register;

PROCEDURE PublishRegisteredModules;
VAR m {UNTRACED}, prev {UNTRACED}, cur {UNTRACED}: Module; module, import: SIZE;
BEGIN
	WHILE register.first # NIL DO
		m := register.first;
		register.first := m.next;
		m.next := NIL;
		IF m.module # NIL THEN
			FOR import := 0 TO LEN (m.module) - 1 DO
				IF ~m.module[import].published THEN
					ASSERT(register.first # NIL);
					prev := NIL;
					cur := register.first;
					WHILE (cur # NIL) & (cur # m.module[import]) DO
						prev := cur;
						cur := cur.next
					END;
					(*ASSERT(cur = m.module[import]);*)
					ASSERT(cur = m.module[import]);
					IF prev = NIL THEN
						register.first := cur.next
					ELSE
						prev.next := cur.next;
					END;
					cur.next := NIL;
					Initialize0 (m.module[import]);
				END
			END;
		END;
		Initialize0 (m);
	END;
END PublishRegisteredModules;

(* procedure that will be called last in a linked kernel *)
PROCEDURE {FINAL} Main;
BEGIN
	Machine.Init;
	Trace.String("publish registered modules"); Trace.Ln;
	PublishRegisteredModules;
END Main;

PROCEDURE Init;
VAR
	newArr: PROCEDURE (VAR p: ANY; elemTag: ADDRESS; numElems, numDims: SIZE; isRealtime: BOOLEAN);
	newSys: PROCEDURE (VAR p: ANY; size: SIZE; isRealtime: BOOLEAN);
	newRec: PROCEDURE (VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
	getProcedure: PROCEDURE(CONST m, p : ARRAY OF CHAR; argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
	s: ARRAY 4 OF CHAR;
	module: Module; new: BOOLEAN; i: LONGINT;
BEGIN
	(* root and initBlock are initialized by the linker *)
	shutdown := None;
	newArr := Heaps.NewArr;
	newSys := Heaps.NewSys;
	newRec := Heaps.NewRec;
	getProcedure := GetProcedure;
	kernelProc[0] := SYSTEM.VAL (ADDRESS, newRec);	(* 253 *)
	kernelProc[1] := SYSTEM.VAL (ADDRESS, newSys);	(* 252 *)
	kernelProc[2] := SYSTEM.VAL (ADDRESS, newArr);	(* 251 *)
	kernelProc[3] := 0;	(* 250 *)
	kernelProc[4] := 0;	(* 249 *)
	kernelProc[5] := 0;	(* 248 *)
	kernelProc[6] := 0;	(* 247 *)
	kernelProc[7] := 0;	(* 246 *)
	kernelProc[8] := 0;	(* 245 *)
	kernelProc[9] := 0;	(* 244 *)
	kernelProc[10] := SYSTEM.VAL(ADDRESS, getProcedure);	(* 243 *)
	numLoaders := 0;
	freeRoot := NIL;
	Machine.GetConfig("TraceModules", s);
	trace := (s[0] = "1");
	(*
	FOR i := 0 TO Runtime.modules-1 DO
		module := SYSTEM.VAL(Module,Runtime.kernelModule[i]);
		IF TraceBoot THEN
			Trace.String("publishing module ");
			Trace.String(module.name); Trace.Ln;
		END;
		Publish(module,new);
		ASSERT(new,112233);
	END;
	*)
	(*
	module := SYSTEM.VAL(Module,SELF);
	Publish(module,new);
	*)
END Init;

BEGIN
	Init;
END Modules.

(*
19.03.1998	pjm	Started
06.10.1998	pjm	FreeModule

Note:
o GetProcedure race: process A calls ThisModule, the module is published, but before its body has finished executing, process B calls GetProcedure, causing the assert (m.init) to fail. Process B should perhaps wait in this case until the body has executed, or GetProcedure should return NIL (but that will just move the race to the user).
*)
