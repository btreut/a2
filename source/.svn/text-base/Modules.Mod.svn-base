MODULE Modules;	(** AUTHOR "pjm"; PURPOSE "Modules and types"; *)

IMPORT SYSTEM, Trace, Machine, Heaps;

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

TYPE
	(* definitions for object-model loader support *)
	Name* = ARRAY 32 OF CHAR;

	Command* = RECORD
		(* Fields exported for initialization by loader/linker only! Consider read-only! *)
		name*: Name; (* name of the procedure *)
		argTdAdr*, retTdAdr* : ADDRESS; (* address of type descriptors of argument and return type, 0 if no type *)
		entryAdr* : ADDRESS; (* entry address of procedure *)
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

	TypeDesc* = POINTER TO RECORD   (* ug: adapt constant TypeDescRecSize if this type is changed !!! *)
		descSize: LONGINT;
		sentinel: LONGINT;	(* = MPO-4 *)
		tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
		flags*: SET;
		mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
		name*: Name;
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
			crc*: LONGINT; (* crc of the object file -- for unique identification *)

		PROCEDURE FindRoots;	(* override *)
		VAR i: LONGINT; ptr: ANY; moduleName: Name; protRecBlockAdr: ADDRESS; protRecBlock: Heaps.ProtRecBlock;
		BEGIN
			IF published THEN	(* mark global pointers *)
				moduleName := name;
				FOR i := 0 TO LEN(ptrAdr) - 1 DO
					SYSTEM.GET (ptrAdr[i], ptr);
					IF ptr # NIL THEN Heaps.Mark(ptr) END
				END;

				(* mark prot rec fields, for whatever reasons this does not work correctly in the statically linked heap *)
				SYSTEM.GET(SYSTEM.VAL(ADDRESS,SELF)+Heaps.HeapBlockOffset, protRecBlockAdr);
				protRecBlock := SYSTEM.VAL(Heaps.ProtRecBlock, protRecBlockAdr);
				Heaps.Mark(protRecBlock.awaitingLock.head);
				Heaps.Mark(protRecBlock.awaitingCond.head);
				Heaps.Mark(protRecBlock.lockedBy);
				Heaps.Mark(protRecBlock.lock);

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
	ptrOffsetsLock: BOOLEAN;

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
	ASSERT((m.code # NIL) & (LEN(m.code^) > 0));
	Machine.Acquire(Machine.Modules);
	n := root; WHILE (n # NIL) & (n.name # m.name) DO n := n.next END;
	IF n # NIL THEN	(* module with same name exists, return it and ignore new m *)
		m := n; new := FALSE;
		Machine.Release(Machine.Modules);
	ELSE
		m.published := TRUE;
		m.next := root; root := m;
		m.refcnt := 0;
		FOR i := 0 TO LEN(m.module)-1 DO INC(m.module[i].refcnt) END;
		new := TRUE;
		(* another process may still be busy with entering procOffsets in the global table, wait here until not locked *)
		REPEAT UNTIL ~ptrOffsetsLock; (* only one process at a time can check this and only one process at a time can set and reset --> no race problem *)
		ptrOffsetsLock := TRUE;
		Machine.Release(Machine.Modules);
		(* InsertProcOffsets may not be called with the modules lock, cf. comment in InsertProcOffsets *)
		InsertProcOffsets(m.procTable, m.ptrTable, m.maxPtrs);
		m.procTable := NIL; m.ptrTable := NIL; (* not used any more as entered in global variable *)
	END;
END Publish;

(* runtime call for new compiler -- called by body of loaded module *)
PROCEDURE PublishThis*(m: Module): BOOLEAN;
VAR new: BOOLEAN;
BEGIN
	Publish(m,new);
	RETURN new
END PublishThis;

(* runtime call for new compiler -- called by body of loaded module *)
PROCEDURE SetInitialized*(m: Module);
BEGIN
	m.init := TRUE;
END SetInitialized;

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
VAR m, p: Module; fileName: ARRAY 64 OF CHAR; body: Body; new: BOOLEAN; i: LONGINT;
BEGIN
	res := Ok; msg[0] := 0X; m := ModuleByName(name);
	IF m = NIL THEN
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String(">"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		i := 0;
		REPEAT
			GetFileName(name, extension[i], fileName);
			m := loader[i](name, fileName, res, msg);
			INC(i)
		UNTIL (i = numLoaders) OR (m # NIL);
		IF trace THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("?"); Trace.StringLn (name);
			Machine.Release (Machine.TraceOutput);
		END;
		p := m;
		IF (m # NIL) & ~m.published THEN	(* no race on m.published, as update is done below in Publish *)
			Publish(m, new);
			IF new THEN	(* m was successfully published *)
				body := SYSTEM.VAL (Body, ADDRESSOF(m.code[0]));
				body; res := Ok; msg[0] := 0X;
				m.init := TRUE	(* allow ThisCommand *)
			ELSE
				(* m was part of cycle, replaced by existing module *)
			END
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
VAR m: Module; cbase, dbase: ADDRESS; i: LONGINT; found: BOOLEAN;
BEGIN
	i := 0; found := FALSE;
	REPEAT
		CASE i OF
			0: m := root
			|1: m := freeRoot
		END;
		WHILE (m # NIL) & ~found DO
			cbase := ADDRESSOF(m.code[0]); dbase := ADDRESSOF(m.data[0]);
				(* include 1 byte after module in module, therefore <= below *)
			IF (cbase <= pc) & (pc <= cbase + LEN(m.code^)) THEN
				found := TRUE
			ELSIF (dbase <= pc) & (pc <= dbase + LEN(m.data^)) THEN
				found := TRUE
			ELSE
				m := m.next
			END
		END;
		INC(i)
	UNTIL found OR (i = 2);
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
		IF ~module.init THEN (* give the module a chance to initialize, no timer available here, no yield ... *)
			i := 1000000;
			REPEAT DEC(i) UNTIL (i = 0) OR module.init
		END;
		(*
		ASSERT(module.init);	(* module body must have been called (see note at end of module) *)
		*)
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

PROCEDURE FindPos(key: ADDRESS; VAR pos: LONGINT): BOOLEAN;
VAR l, r, x: LONGINT; isHit: BOOLEAN;
BEGIN
	l := 0; r := numProcs - 1;
	REPEAT
		x := (l + r) DIV 2;
		IF key < procOffsets[x].data.pcFrom THEN r := x - 1 ELSE l := x + 1 END;
		isHit := ((procOffsets[x].data.pcFrom <= key) & (key < procOffsets[x].data.pcLimit));
	UNTIL isHit OR (l > r);
	IF isHit THEN
		pos := x;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
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
	FOR i := 0 TO LEN(procTable) - 1 DO
		num := num + procTable[i].noPtr
	END;
	RETURN num
END NumTotalPtrs;

(* insert the procedure code offsets and pointer offsets of a single module into the global table *)
PROCEDURE InsertProcOffsets(procTable: ProcTable; ptrTable: PtrTable; maxPtr: LONGINT);
VAR success: BOOLEAN; i, j, pos, poslast, newLen, num: LONGINT; newProcOffsets: ProcOffsetTable; newPtrOffsets: PtrTable;
BEGIN
	(* this procedure is called by procedure Publish only and is protected by the ptrOffsetsLock lock *)
	(* the Modules lock may not be taken because there is a NEW statement in this procedure:
		- this would violate the locking order precondition of Machine locks (no process holding a lower level lock can aquire a higher level lock) to prevent deadlocks
		- if this is violated (and Machine.strongChecks = FALSE, otherwise trap) then a deadlock can occur in the following subtle way:
			- this process takes the Module lock and stores the current interrupt state and disables interrupt
			- this process temporarily aquires the Heaps lock (no problem)
			- in case of a garbage collection, this process acquires the Objects lock (in Heaps.gcStatus of type Objects.GCStatus)
			- the scheduler is configured to only schedule processes of at least GC priority and normally the timer interrupt is expected to collect all still running processes
			- however, upon releasing the Objects lock, the interrupts are not enabled (because the ModulesLock is still acquired) and therefore the GC process can never be scheduled
			-> deadlock
	*)
	IF LEN(procTable) > 0 THEN
		IF numProcs + LEN(procTable) > LEN(procOffsets) THEN
			newLen := LEN(procOffsets) + InitTableLen;
			WHILE numProcs + LEN(procTable) > newLen DO newLen := newLen + InitTableLen END;
			NEW(newProcOffsets, newLen);
			FOR i := 0 TO numProcs - 1 DO
				newProcOffsets[i] := procOffsets[i]
			END;
			procOffsets := newProcOffsets
		END;
		num := NumTotalPtrs(procTable);
		IF numPtrs + num > LEN(ptrOffsets) THEN
			newLen := LEN(ptrOffsets) + InitPtrTableLen;
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
		FOR i := 0 TO LEN(procTable) - 1 DO
			procOffsets[pos + i].data := procTable[i];
			procOffsets[pos + i].startIndex := numPtrs; (* this field is never accessed in case of procTable[i].noPtr = 0, so we may as well put numPtrs in there *)
			FOR j := 0 TO procTable[i].noPtr - 1 DO
				ptrOffsets[numPtrs + j] := ptrTable[i * maxPtr + j]
			END;
			numPtrs := numPtrs + procTable[i].noPtr;
		END;
		numProcs := numProcs + LEN(procTable);
	END;
	(* release the ptrOffsetLock *)
	ptrOffsetsLock := FALSE;
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
			FOR i := 0 TO LEN(m.ptrAdr)-1 DO SYSTEM.PUT (m.ptrAdr[i], NIL) END;
			IF ClearCode THEN
				FOR i := 0 TO LEN(m.code)-1 DO m.code[i] := 0CCX END
			END;
			(* remove references to module data *)
			m.published := FALSE;
			m.entry := NIL; m.command := NIL; m.ptrAdr := NIL;
			(* do not clear m.type or m.module, as old heap block tags might reference type descs indirectly. *) (* m.staticTypeDescs, m.typeInfo ??? *)
			(* do not clear m.data or m.code, as they are used in ThisModuleByAdr (for debugging). *)
			(* do not clear m.refs, as they are used in Traps (for debugging). *)
			m.export.dsc := NIL; m.exTable := NIL;
			DeleteProcOffsets(m.firstProc, m.noProcs);
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

PROCEDURE Terminate(term: TerminationHandler);
BEGIN
	term
FINALLY
	(* trapped in module finalization -- just bad luck, let's try finalizing *)
END Terminate;


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
			Terminate(term)	(* if this causes hangs, another shutdown call will retry -- is this a good solution ? *)
		END;
		(* clean up finalizers *)
		m := root;
		WHILE m # NIL DO
			Heaps.CleanupModuleFinalizers(ADDRESSOF(m.code[0]), LEN(m.code), m.name);
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


PROCEDURE Init;
VAR
	s: ARRAY 4 OF CHAR;
BEGIN
	(* root and initBlock are initialized by the linker *)
	ptrOffsetsLock := FALSE;
	shutdown := None;
	numLoaders := 0;
	freeRoot := NIL;
	Machine.GetConfig("TraceModules", s);
	trace := (s[0] = "1")
END Init;

BEGIN
	Init
END Modules.

(*
19.03.1998	pjm	Started
06.10.1998	pjm	FreeModule

Note:
o ThisCommand race: process A calls ThisModule, the module is published, but before its body has finished executing, process B calls ThisCommand, causing the assert (m.init) to fail. Process B should perhaps wait in this case until the body has executed, or ThisCommand should return NIL (but that will just move the race to the user).
*)
