MODULE Modules;	(** AUTHOR "pjm"; PURPOSE "Modules and types"; *)

IMPORT SYSTEM, Trace, Machine, Heaps, Environment, Activities, Processors, Queues;

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

	DefaultContext* = "A2";
	NoLoader=3400;

	TraceBoot=TRUE;

TYPE
	(* definitions for object-model loader support *)
	Name* = ARRAY 32 OF CHAR;
	DynamicName* = POINTER {UNSAFE} TO ARRAY OF CHAR;

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
		exports*: LONGINT; (* number of exports referenced by ExportArray *)
		dsc* {UNTRACED}: ExportArray; (* pointer to memory containing a raw array with "exports" entries *)
	END;
	ExportArray* = POINTER {UNSAFE} TO ARRAY OF ExportDesc;

	Bytes* = POINTER TO ARRAY OF CHAR;

	TerminationHandler* = PROCEDURE;

	LongName = ARRAY 64 OF CHAR;
	
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
		name*: LongName; (*! change to dynamic name ? *)
		offset*: SIZE; (* offset of this type *)
		type*: EntryType;
		flags*: SET;
	END;
	FieldEntries*= POINTER TO ARRAY OF FieldEntry;
	ProcedureEntries*=POINTER TO ARRAY OF ProcedureEntry;
	
	ProcedureEntry*=RECORD
		name*: LongName; (*! change to dynamic name ? *)
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

	END Module;

	LoaderProc* = PROCEDURE (CONST name, fileName: ARRAY OF CHAR; VAR res: LONGINT;
			VAR msg: ARRAY OF CHAR): Module;	(** load an object file *)

VAR
	extension-: ARRAY MaxObjFormats, 8 OF CHAR;
	loader: ARRAY MaxObjFormats OF LoaderProc;
	numLoaders: LONGINT;
	kernelProc*: ARRAY 11 OF ADDRESS;	(** kernel call addresses for loader *)

	freeRoot*: Module;	(** list of freed modules (temporary) *)

	root-: Module;	(** list of modules (read-only) *)
	shutdown*: LONGINT;	(** None, Reboot, PowerDown *)
	trace: BOOLEAN;
	register {UNTRACED}: ARRAY 64 OF Module;
	registered: LONGINT;

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
VAR n: Module; i: LONGINT;
BEGIN
	Machine.Acquire(Machine.Modules);
	n := root; WHILE (n # NIL) & (n.name # m.name) DO n := n.next END;
	IF n # NIL THEN	(* module with same name exists, return it and ignore new m *)
		m := n; new := FALSE;
		Machine.Release(Machine.Modules);
	ELSE
		IF TraceBoot THEN
			Machine.Acquire(Machine.TraceOutput);
			Trace.String("publish "); Trace.String(m.name);
			Trace.Ln;
			Machine.Release(Machine.TraceOutput);
		END;
		m.published := TRUE;
		m.next := root; root := m;
		m.refcnt := 0;
		IF m.module # NIL THEN
			FOR i := 0 TO LEN(m.module)-1 DO INC(m.module[i].refcnt) END;
		END;
		new := TRUE;
		Machine.Release(Machine.Modules);
	END;
END Publish;

PROCEDURE Initialize*(VAR module: Module);
VAR new: BOOLEAN;
BEGIN
	Publish (module, new);
	IF new THEN
		IF module.body # NIL THEN module.body END;
		module.init := TRUE;
	END;
END Initialize;

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

(** Load the module if it is not already loaded. *)	(* Algorithm J. Templ, ETHZ, 1994 *)
PROCEDURE ThisModule*(CONST name: ARRAY OF CHAR; VAR res: LONGINT; VAR msg: ARRAY OF CHAR): Module;
TYPE Body = PROCEDURE;
VAR m, p: Module; fileName: ARRAY 64 OF CHAR; i: LONGINT;
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

(** Return the module that contains code address pc or NIL if not found. Can also return freed modules. -- non-blocking variant for Reflection. *)
PROCEDURE ThisModuleByAdr0*(pc: ADDRESS): Module;
VAR m: Module; i: LONGINT; found: BOOLEAN; list: LONGINT;
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
VAR m: Module;
BEGIN
	Machine.Acquire(Machine.Modules);
	m := ThisModuleByAdr0(pc);
	Machine.Release(Machine.Modules);
	RETURN m
END ThisModuleByAdr;

(*	Retrieve a procedure given a module name, the procedure name and some type information (kernel call) *)
PROCEDURE GetProcedure*(CONST moduleName, procedureName : ARRAY OF CHAR; argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
VAR module : Module; ignoreMsg : ARRAY 32 OF CHAR; i, res : LONGINT;
BEGIN
	module := ThisModule(moduleName, res, ignoreMsg);
	IF (res = Ok) THEN
		ASSERT(module.init);	(* module body must have been called (see note at end of module) *)
		IF module.init THEN
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
	p := NIL; m := root;
	WHILE (m # NIL) & (m.name # name) DO p := m; m := m.next END;
	IF m # NIL THEN
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
			IF m # NIL THEN term := m.term; m.term := NIL END; (* finalizer only called once *)
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

PROCEDURE Init;
VAR
	newArr: PROCEDURE (VAR p: ANY; elemTag: ADDRESS; numElems, numDims: SIZE; isRealtime: BOOLEAN);
	newSys: PROCEDURE (VAR p: ANY; size: SIZE; isRealtime: BOOLEAN);
	newRec: PROCEDURE (VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
	getProcedure: PROCEDURE(CONST m, p : ARRAY OF CHAR; argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
	s: ARRAY 4 OF CHAR;
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
END Init;

PROCEDURE Register- (module {UNTRACED}: Module);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	register[registered] := module;
	INC (registered);
END Register;

PROCEDURE PublishRegisteredModules;
VAR m {UNTRACED}: Module; module, import: SIZE;
BEGIN
	Activities.Call (Activities.Idle);
	FOR module := 0 TO registered - 1 DO
		m := register[module];
		IF m.module # NIL THEN
			FOR import := 0 TO LEN (m.module) - 1 DO
				Initialize (m.module[import]);
			END;
		END;
		Initialize (m);
	END;
END PublishRegisteredModules;

PROCEDURE FinalizeModules;
VAR module {UNTRACED}: Module;
PROCEDURE Finalize EXTERN "BaseTypes.Object.Finalize" (module {UNTRACED}: Module);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	module := root;
	WHILE module # NIL DO
		Finalize (module);
		module := module.next;
	END;
END FinalizeModules;

PROCEDURE {FINAL} Main;
PROCEDURE InitializeGC EXTERN "GarbageCollector.Initialize";
PROCEDURE TerminateGC EXTERN "GarbageCollector.Terminate";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	SYSTEM.SetFramePointer (NIL);
	Environment.Initialize;
	InitializeGC;
	Processors.Initialize;
	Activities.Execute (PublishRegisteredModules);
	Processors.Terminate;
	FinalizeModules;
	Activities.Terminate;
	Queues.Terminate;
	Environment.Terminate;
	TerminateGC;
	Environment.Exit (Environment.status);
END Main;

BEGIN
	Init
END Modules.

