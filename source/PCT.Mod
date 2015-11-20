(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCT; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: symbol table"; *)

IMPORT
	SYSTEM, KernelLog, StringPool, Strings, PCM, PCS,Diagnostics;

CONST
	MaxPlugins = 4;

	(** Error Codes *)
	Ok* = 0;
	DuplicateSymbol* = 1;
	NotAType* = 53;
	IllegalPointerBase* = 57;
	RecursiveType* = 58;
	IllegalValue* = 63;
	IllegalType* = 88;	(** open array not allowed here *)
	IllegalArrayBase* = 89;
	IllegalMixture* = 91;  (* fof mixture of enhanced arrays and traditional arrays not allowed: forbidden ARRAY OF ARRAY [*] OF ...  *)
	ParameterMismatch* = 115;
	ReturnMismatch* = 117;
	DuplicateOperator* = 139;
	ImportCycle* = 154;
	MultipleInitializers* = 144;
	NotImplemented* = 200;
	ObjectOnly* = 249;
	InitializerOutsideObject* = 253;
	IndexerNotVirtual* = 991;

	(** Reserved Names *)
	BodyNameStr* = "@Body";
	SelfNameStr* = "@Self";
	AnonymousStr* = "@NoName";
	PtrReturnTypeStr* = "@PtrReturnType"; (* ug *)
	AssignIndexer*= "@AssignIndexer";
	ReadIndexer*= "@ReadIndexer";

	AwaitProcStr = "@AwaitProc"; (* ug *)
	HiddenProcStr ="@tmpP"; (* ug *)

	(**Search.mode*)
	local* = 0;

	(**Scope.state*)
	structdeclared* = 1;	(** all structures declared *)
	structshallowallocated *= 2; (* fof *)
	structallocated* = 3;	(** all structures allocated (size set) *)
	procdeclared* = 4;	(** all procedures declared *)
	hiddenvarsdeclared* = 5; (** all proc. calls returning pointers or delegates as hidden variables declared *)    (* ug *)
	modeavailable* = 6;	(** body mode available (ACTIVE, EXCLUSIVE) *)
	complete* = 7;	(** code available *)

	(** Access Flags *)
	HiddenRW* = 0;		(** can neither read nor write symbol in same module *)   (* ug *)
	InternalR* = 1;		(** can read symbol in same module *)
	InternalW* = 2;		(** can write symbol in same module *)
	ProtectedR* = 3;	(** can read symbol in type extentions *)
	ProtectedW* = 4;	(** can write symbol in type extentions *)
	PublicR* = 5;		(** can read everywhere *)
	PublicW* = 6;		(** can write everywhere *)

	Hidden* = {HiddenRW};	(* ug *)
	Internal* = {InternalR, InternalW};
	Protected* = {ProtectedR, ProtectedW};
	Public* = {PublicR, PublicW};

	(**Array.mode*)
	static* = 1; open* = 2;

	(** Record.mode *)
	exclusive* = 0; active* = 1; safe* = 2; class* = 16; interface* = 17;

	(** Symbol .flags / all *)
	used* = 16;	(**object is accessed*)
	written*=17; (* object has been written to *) (** fof 070731 *)

	(** Symbol .flags / Proc only *)
	Constructor* = 1;
	Inline* = 2;	(** inline proc *)
	copy* = 3;	(** copy of a method defined in a superinterface *)
	NonVirtual* = 7;	(** Non-virtual method, cannot be overridden *)
	Operator* = 10;
	Indexer *= 11;
	RealtimeProc* = PCM.RealtimeProc; (* = 21 *) (* realtime procedure that is not allowed to allocate memory nor to wait on locks or conditions *)

	(** Symbol .flags / Variable only *)
	(**PCM.Untraced = 4 -> PCT.Variable only*)

	(** Parameter .flags *)
	WinAPIParam* = PCM.WinAPIParam;  (* = 13 *) (* ejz *)
	CParam* = PCM.CParam;   (* = 14 *) (* fof for Linux *)
	(** Calling Conventions *)
	OberonCC* = 1;  OberonPassivateCC* = 2;  WinAPICC* = 3; (* ejz *) CLangCC* = 4;   (* fof for Linux *)

	(** Struct flags *)
	StaticMethodsOnly* = 5;			(** Delegate / restriction, static methods only *)
	SystemType* = 6;				(** Record / hidden system type descs (pointer to array of pointers/descriptors), allocated by need *)
	RealtimeProcType* = PCM.RealtimeProcType; (* = 8 *)	(** realtime property of delegates and static procedure types *)

	(** Scope.flags *)
	Overloading* = 31;	(**Modules only: duplicate entries allowed (applies to all scopes in the module)*)
	AutodeclareSelf* = 30;	(**Methods only: self is automatically allocated when the method is created*)
	SuperclassAvailable* = 29;	(**Records only: Superclass available before (or by a different thread) the actual one is entered*)
	CanSkipAllocation* = 28; 	(** Records only: the pointer only is used, record allocation can be skipped (no need to wait for StructComplete *)
	RealtimeScope* = 27;		(** direct or indirect owner of scope is a realtime procedure, i.e. within scope no memory allocation, no locking and no await are allowed *)

VAR
	BodyName-, SelfName-, Anonymous-, PtrReturnType- (* ug *) : LONGINT;	(** indexes to stringpool *)

	(*debug/trace counters*)
	AWait, ANoWait: LONGINT;

TYPE
	StringIndex* = StringPool.Index;

	(** Symbol Table Structures *)

	Struct* = POINTER TO RECORD
		owner-: Type;	(* canonical name of structure, if any *)
		size*: PCM.Attribute;		(* back-end: size information *)
		sym*: PCM.Attribute;		(* fingerprinting information *)
		flags-: SET;
	END;

	Symbol* = OBJECT
		VAR
			name-: StringIndex;	(**string-pool index*)
			vis-: SET;
			type*: Struct;
			adr*, sym*: PCM.Attribute;	(**allocation and fingerprinting information*)
			flags*: SET;
			sorted-: Symbol;
			inScope-: Scope;
			dlink*: Symbol;	(* chain for user defined purposes *)
			info*: ANY;	(** user defined data *)
			pos-: LONGINT;   (*fof 070731 *)

		PROCEDURE Use;
		BEGIN INCL(flags, used)
		END Use;

		(** fof 070731 >> *)
		PROCEDURE Write;
		BEGIN
			INCL(flags,written);
		END Write;
		(** << fof  *)

	END Symbol;

	Node* = OBJECT
		VAR
			pos*: LONGINT;
	END Node;


	Scope* = OBJECT
		VAR
			state-: SHORTINT;
			flags-: SET;
			ownerID-: ADDRESS;	(** process owning this scope*)
			module-: Module;	(** module owning this scope *)
			sorted-, last-: Symbol;	(** objects in the scope; last is the last object inserted *)
			firstValue-, lastValue-: Value;
			firstVar-, lastVar-: Variable;
			firstHiddenVar-, lastHiddenVar-: Variable;  (* ug *) (** variables denoting proc. calls that return pointers, not inserted in sorted list of all symbols *)
			firstProc-, lastProc-: Proc;
			firstType-, lastType-: Type;
			parent-: Scope;
			code*: PCM.Attribute;
			imported-: BOOLEAN;	(*cached information*)
			valueCount-, varCount-, procCount-, typeCount-: LONGINT;	(** variables/procedures in this scope. *)
			tmpCount: LONGINT; (* ug *)


		PROCEDURE Await*(state: SHORTINT);
		BEGIN {EXCLUSIVE}
			IF SELF.state >= state THEN INC(ANoWait) ELSE INC(AWait) END;
			AWAIT(SELF.state >= state)	(** remove EXCLUSIVE, not needed*)
		END Await;

		PROCEDURE ChangeState(state: SHORTINT);
		BEGIN {EXCLUSIVE}
			ASSERT((ownerID = 0) OR (ownerID = PCM.GetProcessID()), 500);(* global scope has no process id (=0) since different processes may insert elements here, cf. procedure Init *)
			ASSERT(SELF.state < state, 501);
			SELF.state := state
		END ChangeState;

		PROCEDURE CreateSymbol*(name: StringIndex; vis: SET; type: Struct; VAR res: LONGINT);
			VAR o: Symbol;
		BEGIN
			NEW(o);
			InitSymbol(o, name, vis, type);
			Insert(SELF, o, res);
		END CreateSymbol;

		PROCEDURE CreateValue*(name: StringIndex; vis: SET; c: Const; pos: LONGINT; (*fof*) VAR res: LONGINT);
			VAR v: Value;
		BEGIN
			v := NewValue(name, vis, c); v.pos := pos; (*fof*)
			Insert(SELF, v, res);
			IF res = Ok THEN
				INC(valueCount);
				IF lastValue = NIL THEN firstValue := v ELSE lastValue.nextVal := v END;
				lastValue := v
			END
		END CreateValue;

		PROCEDURE CreateType*(name: StringIndex;  vis: SET;  type: Struct; pos: LONGINT; (*fof*) VAR res: LONGINT);
			VAR t: Type;
		BEGIN
			NEW(t);
			InitType(t, name, vis, type); t.pos := pos; (*fof*)
			Insert(SELF, t, res);
			IF res = Ok THEN
				INC(typeCount);
				IF lastType = NIL THEN firstType := t ELSE lastType.nextType := t END;
				lastType := t
			END
		END CreateType;

		PROCEDURE CreateAlias*(ov: Variable; type: Struct; (* scope: Scope; extern: BOOLEAN; *) VAR res: LONGINT);
			VAR v: Alias;
		BEGIN
			NEW(v); v.name := ov.name; v.vis := ov.vis; v.type := type;
			v.obj := ov; v.level := ov.level;
			(* v.extern := extern; *)
			(* ov.alias := v; *)
			Insert((* scope *) SELF, v, res)
		END CreateAlias;

		PROCEDURE CreateVar*(name: StringIndex;  vis, flags: SET;  type: Struct; pos: LONGINT; (*fof*)  info: ANY; (* ug *) VAR res: LONGINT);
		BEGIN  HALT(99)	(*abstract*)
		END CreateVar;

		PROCEDURE CreateProc*(name: StringIndex;  vis, flags: SET;  scope: (*Proc*)Scope;  return: Struct; pos: LONGINT; (*fof*) VAR res: LONGINT);
		BEGIN  HALT(99)	(*abstract*)
		END CreateProc;

		(* ug *)
		PROCEDURE CreateHiddenVarName*(VAR name: StringPool.Index);
			VAR s1, s: ARRAY 256 OF CHAR;
		BEGIN
			Strings.IntToStr(tmpCount, s1);
			Strings.Concat(HiddenProcStr, s1, s);
			StringPool.GetIndex(s, name);
			INC(tmpCount)
		END CreateHiddenVarName;

		(* ug *)
		PROCEDURE CreateAwaitProcName*(VAR name: StringPool.Index; count: LONGINT);
			VAR s1, s: ARRAY 256 OF CHAR;
		BEGIN
			Strings.IntToStr(count, s1);
			Strings.Concat(AwaitProcStr, s1, s);
			StringPool.GetIndex(s, name)
		END CreateAwaitProcName;

		(* ug *)
		PROCEDURE FindHiddenVar*(pos: LONGINT; info: ANY): Variable;
			VAR p: Variable; s: Scope;
		BEGIN
			s := SELF;
			WHILE s IS WithScope DO s := s.parent END;
			p := s.firstHiddenVar;
			WHILE (p # NIL) & ((p.pos # pos) OR (p.info # info)) DO p := p.nextVar END;
			RETURN p
		END FindHiddenVar;

	END Scope;

	WithScope* = OBJECT (Scope)
	VAR
		withGuard*, withSym*: Symbol;

		(* ug *)
		PROCEDURE CreateVar*(name: StringIndex;  vis, flags: SET;  type: Struct; pos: LONGINT; (*fof*)  info: ANY; VAR res: LONGINT);
		VAR s: Scope;
		BEGIN
			s := parent;
			WHILE s IS WithScope DO s := s.parent END;
			s.CreateVar(name, vis, flags, type, pos, info, res)
		END CreateVar;

	END WithScope;

	ProcScope* = OBJECT(Scope)
		VAR
			ownerS-: Delegate;
			ownerO-: Proc;
			firstPar-, lastPar-: Parameter;
			formalParCount-, 			(* number of formal parameters *) (* ug *)
			parCount-: LONGINT;		(* number of total parameters, including PtrReturnType and SELF parameters *)
			cc-: LONGINT;
			returnParameter-: ReturnParameter; (* fof, for access to the return parameter in procedures*)

		PROCEDURE &Init*; (* ejz *)
		BEGIN
			cc := OberonCC
		END Init;

		PROCEDURE SetCC*(cc: LONGINT);
		BEGIN
			SELF.cc := cc
		END SetCC;

		PROCEDURE CreateVar*(name: StringIndex;  vis, flags: SET;  type: Struct; pos: LONGINT; (*fof*) info: ANY; (*ug*) VAR res: LONGINT);
			VAR v: LocalVar;
		BEGIN
			NEW(v); v.pos := pos; (*fof*)
			InitSymbol(v, name, vis, type);
			v.flags := flags;
			v.info := info; (* ug *)
			v.level := ownerO.level;
			CheckVar(v, {static, open}, {static, open} (* fof *) ,res);
			IF (v.type IS Array) & (v.type(Array).mode IN {open}) & ~v.type(Array).isDynSized THEN
				res := IllegalType; v.type := UndefType;
			END;
			IF vis = Hidden THEN (* ug *)
				IF lastHiddenVar = NIL THEN firstHiddenVar := v ELSE lastHiddenVar.nextVar := v END;
				lastHiddenVar := v; INCL(v.vis,PublicW); (* fof: may be overwritten by any caller (otherwise results in readonly designator in PCB yielding errors) *)
				res := Ok
			ELSE
				Insert(SELF, v, res);
				IF res = Ok THEN
					INC(varCount);
					IF lastVar = NIL THEN firstVar := v ELSE lastVar.nextVar := v END;
					lastVar := v
				END
			END
		END CreateVar;

		PROCEDURE ReversePars*; (* ejz *)
			VAR p, next: Parameter;
		BEGIN
			p := firstPar; firstPar := NIL; lastPar := p;
			WHILE p # NIL DO
				next := p.nextPar;
				p.nextPar := firstPar; firstPar := p;
				p := next
			END
		END ReversePars;

		PROCEDURE CreatePar*(vis: SET;  ref: BOOLEAN;  name: StringIndex;  flags: SET;  type: Struct; pos: LONGINT;   (*fof 070731 *) VAR res: LONGINT);
			VAR p: Parameter;

			(* ug *)
			PROCEDURE IsHiddenPar(name: StringIndex): BOOLEAN;
			BEGIN
				IF (name = PtrReturnType) OR (name = SelfName) THEN
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			END IsHiddenPar;

		BEGIN
			NEW(p); p.pos := pos;   (*fof*)
			InitSymbol(p, name, vis, type);
			CheckVar(p, {static, open}, {static, open} (* fof *),res);
			p.flags := flags;
			p.ref := ref;
			Insert(SELF, p, res);
			IF res = Ok THEN
				INC(parCount);
				IF ~IsHiddenPar(name) THEN INC(formalParCount) END; (* ug *)
				IF lastPar = NIL THEN firstPar := p ELSE lastPar.nextPar := p END;
				lastPar := p
			END
		END CreatePar;

		(** fof >> *)
		PROCEDURE CreateReturnPar*(type: Struct; VAR res: LONGINT);
		(* if return type of the function admits it, create the return parameter *)
		VAR v: ReturnParameter; RetName: StringIndex;
		BEGIN
			IF (type IS EnhArray) OR (type IS Tensor) OR (type IS Pointer) THEN
				NEW(v);  RetName := (* ownerO.name *) StringPool.GetIndex1("RETURNPARAMETER"); (*! very unclean, for testing purposes *)
				InitSymbol(v,RetName,{},type);
				Insert(SELF,v,res);
				v.ref :=  TRUE; (* ~(type IS Tensor);  *)
				returnParameter := v;
			END;
		END CreateReturnPar;
		(** << fof  *)

		PROCEDURE CreateProc*(name: StringIndex;  vis, flags: SET;  scope: (*Proc*)Scope;  return: Struct; pos: LONGINT; (*fof*) VAR res: LONGINT);
			VAR p: Proc;
		BEGIN
			p := NewProc(vis, name, flags, scope(ProcScope), return, res);
			p.pos := pos; (*fof*)
			Insert(SELF, p, res);
			IF res = Ok THEN
				INC(procCount);
				IF lastProc = NIL THEN firstProc := p ELSE lastProc.nextProc := p END;
				lastProc := p
			END
		END CreateProc;

	END ProcScope;

	RecScope* = OBJECT(Scope)
		VAR
			owner-: Record;
			body-, initproc-: Method;
			firstMeth-, lastMeth-: Method;
			totalVarCount-, totalProcCount-: LONGINT;	(**var/proc count including base type (overwritten method are counted only once)*)

		PROCEDURE CreateVar*(name: StringIndex;  vis, flags: SET;  type: Struct; pos: LONGINT; (*fof*) info : ANY; (*ug*) VAR res: LONGINT);
			VAR f: Field; obj: Symbol;
		BEGIN
			ASSERT(vis # Hidden);
			IF CheckForRecursion(type, owner) THEN
				res := RecursiveType;
				type := Int32 (*NoType -> trap in TypeSize*)
			END;
			NEW(f); f.pos := pos; (*fof*) InitSymbol(f, name, vis, type); f.flags := flags; CheckVar(f, {static},  {static, open} (* fof *) ,res);
			f.info := info; (* ug *)
			IF (SuperclassAvailable IN flags) & (owner.brec # NIL) THEN	(*import: already ok*)
				obj := Find(SELF, owner.brec.scope, name, structdeclared, FALSE);
				IF obj # NIL THEN  res := DuplicateSymbol END
			END;
			Insert(SELF, f, res);
			IF res = Ok THEN
				INC(varCount);
				IF lastVar = NIL THEN firstVar := f ELSE lastVar.nextVar := f END;
				lastVar := f
			END
		END CreateVar;

		PROCEDURE CreateProc*(name: StringIndex;  vis, flags: SET;  scope: (*Proc*)Scope;  return: Struct; pos: LONGINT; (*fof*) VAR res: LONGINT);
			VAR m: Method;
		BEGIN
			m := NewMethod(vis, name, flags, scope(ProcScope), return, owner, pos, res);
			m.pos := pos; (* fof *)
			Insert(SELF, m, res);
			IF res = Ok THEN
				INC(procCount);
				IF lastMeth = NIL THEN
					firstProc := m; firstMeth := m
				ELSE
					lastMeth.nextProc := m; lastMeth.nextMeth := m
				END;
				lastProc := m;
				lastMeth := m
			END
		END CreateProc;

		PROCEDURE IsProtected* (): BOOLEAN;
		VAR scope: RecScope;
		BEGIN scope := SELF;
			WHILE (scope # NIL) & (scope.owner.mode * {exclusive, active} = {}) DO
				IF scope.owner.brec # NIL THEN scope := scope.owner.brec.scope ELSE scope := NIL END;
			END;
			RETURN scope # NIL;
		END IsProtected;

	END RecScope;

(** fof >> *)
	CustomArrayScope* = OBJECT (RecScope)
	END CustomArrayScope;
(** << fof  *)

	ModScope* = OBJECT(Scope)
		VAR
			owner-: Module;
			records-: Record;
			nofRecs-: INTEGER;

		PROCEDURE CreateVar*(name: StringIndex;  vis, flags: SET;  type: Struct; pos: LONGINT; (*fof*) info: ANY; (*ug*) VAR res: LONGINT);
			VAR v: GlobalVar;
		BEGIN
			NEW(v); v.pos := pos; (*fof*) InitSymbol(v, name, vis, type); v.flags := flags; CheckVar(v, {static}, {static, open} (* fof *) ,res);
			v.info := info; (* ug *)
			IF vis = Hidden THEN (* ug *)
				IF lastHiddenVar = NIL THEN firstHiddenVar := v ELSE lastHiddenVar.nextVar := v END;
				lastHiddenVar := v; INCL(v.vis,PublicW); (* fof: may be overwritten by any caller (otherwise results in readonly designator in PCB yielding errors) *)
				res := Ok
			ELSE
				Insert(SELF, v, res);
				IF res = Ok THEN
					INC(varCount);
					IF lastVar = NIL THEN firstVar := v ELSE lastVar.nextVar := v END;
					lastVar := v
				END
			END
		END CreateVar;

		PROCEDURE CreateProc*(name: StringIndex;  vis, flags: SET;  scope: (*Proc*)Scope;  return: Struct; pos: LONGINT; (*fof*) VAR res: LONGINT);
			VAR p: Proc;
		BEGIN
			p := NewProc(vis, name, flags, scope(ProcScope), return, res);
			p.pos := pos; (* fof *)
			Insert(SELF, p, res);
			IF res = Ok THEN
				INC(procCount);
				IF lastProc = NIL THEN firstProc := p ELSE lastProc.nextProc := p END;
				lastProc := p
			END;
		END CreateProc;

		PROCEDURE AddModule*(alias: StringIndex; m: Module; pos: LONGINT; (* fof *) VAR res: LONGINT);
		BEGIN
			Insert(SELF, NewModule(alias, TRUE, m.flags, m.scope), res);
			m.pos := pos; (* fof *)
		END AddModule;

	END ModScope;

	(** ------------ Structures ----------------- *)

	Basic* = POINTER TO RECORD (Struct)
	END;

	Array* = POINTER TO RECORD (Struct)
		mode-: SHORTINT;	(** array size: static, open *)
		base-: Struct;			(** element type *)
		len-: LONGINT;		(** array size (iff mode=static) *)

		opendim-: LONGINT;
		isDynSized*: BOOLEAN;
	END;

	(** fof >> *)
	EnhArray* = POINTER TO RECORD (Struct)
		mode-: SHORTINT;  	(** array size: static, open *)
		base-: Struct;   			(** element type, if more dimensional array then of type EnhArray *)
		len-: LONGINT;  		  (** array size (iff mode=static) *)
		inc-: LONGINT;   		  (** increment of this dimension  (iff mode = static) *)

		dim-: LONGINT;  		 (* number of dimensions *)
		opendim-: LONGINT;   (** number of open dimensions *)
	END;

	Tensor* = POINTER TO RECORD (Struct)
		(** type is always open *)
		base-: Struct;  (** no size or geometry information available at compile time *)
	END;

	(** << fof  *)

	Record* = POINTER TO RECORD (Struct)
		scope-: RecScope;	(** record contents *)
		brec-: Record;			(**base record*)
		btyp-: Struct;			(** base type, for dynamic records = Pointer to brec*)
		ptr-: Pointer;			(** dynamic type*)
		intf-: POINTER TO Interfaces;
		mode*(*-*): SET;
		prio*: LONGINT;	(**body priority (mode = active)*)
		imported-: BOOLEAN;
		link-: Record;	(** Module.records, embedded list *)
		(*td*: PCM.Attribute;	(**type descriptor*) in PCBT.RecSize*)
		pvused*, pbused*: BOOLEAN;	(*what features of the record are used, to decide which fp to use [pvfp/pbfp]*)
	END;

	(** fof >> *)
	CustomArray*= POINTER  TO RECORD (Record)
		dim-: LONGINT;
		etyp: Struct;
	END;
	(** << fof  *)

	Pointer* = POINTER TO RECORD (Struct)
		base-: Struct;
		baseA-: Array;
		baseR-: Record;
	END;

	Interface* = Pointer;	(*pointer to record, mode = interface*)
	Interfaces* = ARRAY OF Interface;

	Delegate* = POINTER TO RECORD (Struct)
		return-: Struct;				(** return type, or NoType *)
		scope-: ProcScope;		 (** parameter list *)
	END;

	(** ------------ Symbols ------------------ *)
	Const* = POINTER TO RECORD
		type-: Struct;
		int-: LONGINT;
		real-: LONGREAL;
		long-: HUGEINT;
		set-: SET;
		bool-: BOOLEAN;
		ptr-: ANY;
		str-: POINTER TO PCS.String;  (** int = strlen *)
		owner-: Value;
	END;

	(** fof >> *)
	ConstArray* = POINTER TO RECORD (Const) (* array of constants, denoted as [[1,2,3],[4,5,6]] *)
		data-: POINTER TO ARRAY OF CHAR;      (* array data as array of Bytes *)
		len-: POINTER TO ARRAY OF LONGINT;   (* array geometry. Dimension encoded in LEN(len) *)
	END;
	(** << fof  *)

	Value* = OBJECT (Symbol)
	VAR
		const-: Const;
		nextVal-: Value;	(** next value in scope (by insertion order) *)
	END Value;

	Variable* = OBJECT (Symbol)
	VAR
		level-: SHORTINT;	(**LocalVar and Parameter only*)
		nextVar-: Variable;	(** next variable in scope (by insertion order) *)
	END Variable;

	GlobalVar* = OBJECT (Variable)
	END GlobalVar;

	LocalVar* = OBJECT (Variable)
	END LocalVar;

(** fof >> *)
	ReturnParameter*=  OBJECT (Variable) VAR ref-: BOOLEAN;  END ReturnParameter;
(** << fof  *)

	Parameter* = OBJECT (Variable)
	VAR
		ref-: BOOLEAN;
		nextPar-: Parameter;	(** next parameter in scope (by insertion order) *)
	END Parameter;

	Field* = OBJECT(Variable)
	END Field;

	Alias* = OBJECT (Variable)	(**type-casted variable*)
	VAR
		extern: BOOLEAN;
		obj-: Variable
	END Alias;

	Proc* = OBJECT (Symbol)
	VAR
		scope-: ProcScope;
		nextProc-: Proc;
		level-: SHORTINT;
	END Proc;

	Method* = OBJECT (Proc)
	VAR
		super-: Method;
		boundTo-: Record;
		self-: Parameter;
		nextMeth-: Method;
	END Method;

	Type* = OBJECT (Symbol)
		VAR
			nextType-: Type;

		PROCEDURE Use;
		BEGIN
			Use^;
			IF (type.owner # SELF) &			(* aliased *)
				(*imported*)						  (* only imported modules are in the use list *)
				(PublicR IN type.owner.vis)	(* exported *)
			THEN  type.owner.Use END
		END Use;
	END Type;

	Module* = OBJECT (Symbol)
		VAR
			context*, label*: StringIndex;
			scope-: ModScope;
			imported-, sysImported-: BOOLEAN;
			imports*: ModuleArray;	(** directly and indirectly imported modules, no duplicates allowed, no aliases *)
			directImps*: ModuleArray;	(** only directly imported modules **)

			next: Module;

		PROCEDURE AddImport*(m: Module);
			VAR i: LONGINT;
		BEGIN
			ASSERT(m = m.scope.owner);
			IF (imports = NIL) OR (imports[LEN(imports)-1] # NIL) THEN ExtendModArray(imports) END;
			i := 0;
			WHILE imports[i] # NIL DO INC(i) END;
			imports[i] := m
		END AddImport;

		PROCEDURE AddDirectImp*(m: Module);
			VAR i: LONGINT;
		BEGIN
			ASSERT(m = m.scope.owner);
			IF (directImps = NIL) OR (directImps[LEN(directImps)-1] # NIL) THEN ExtendModArray(directImps) END;
			i := 0;
			WHILE directImps[i] # NIL DO INC(i) END;
			directImps[i] := m
		END AddDirectImp;

		PROCEDURE Use;
		BEGIN
			INCL(flags, used);
			IF SELF # scope.owner THEN INCL(scope.owner.flags, used) END
		END Use;

	END Module;

	ModuleArray* = POINTER TO ARRAY OF Module;
	ModuleDB* = Module;


	(** ImportPlugin: import new module. If self # NIL, do self.AddImport(new) (must be done there to break recursive imports) *)
	ImporterPlugin* = PROCEDURE (self: Module;  VAR new: Module;  name: StringIndex);


VAR
	Byte-, Bool-, Char8-, Char16-, Char32-: Struct;
	Int8-, Int16-, Int32-, Int64-, Float32-, Float64-: Struct;
	Set-, Ptr-, String-, NilType-, NoType-, UndefType-, Address*, SetType*, Size*: Struct;
	NumericType-: ARRAY 6 OF Basic;	(**Int8 .. Float64*)
	CharType-: ARRAY 3 OF Basic;	(** Char8 .. Char32 *)
	Allocate*: PROCEDURE(context, scope: Scope; hiddenVarsOnly: BOOLEAN); (* ug *)
	PreAllocate*, PostAllocate*: PROCEDURE (context, scope: Scope); (* ug *)
	Universe-, System-: Module;
	True-, False-: Const;
	SystemAddress-, SystemSize-: Type;
	AddressSize*, SetSize*: LONGINT;

	import: ARRAY MaxPlugins OF ImporterPlugin;
	nofImportPlugins: LONGINT;

	database*: ModuleDB;	(**collection of modules, first is sentinel*)


	(** ---------------- Helper Functions --------------------- *)

	(** ExtendModArray - Double structure size, copy elements into new structure *)

	PROCEDURE ExtendModArray*(VAR a: ModuleArray);
		VAR b: ModuleArray; i: LONGINT;
	BEGIN
		IF a = NIL THEN  NEW(a, 16)
		ELSE
			NEW(b, 2*LEN(a));
			FOR i := 0 TO LEN(a)-1 DO	b[i] := a[i]	END;
			a := b
		END
	END ExtendModArray;

	(** ---------------- Type Compatibility Functions -------------- *)

	PROCEDURE IsCardinalType*(t: Struct): BOOLEAN;
	BEGIN	RETURN (t = Int8) OR (t = Int16) OR (t = Int32) OR (t = Int64)
	END IsCardinalType;

	PROCEDURE IsFloatType*(t: Struct): BOOLEAN;
	BEGIN	RETURN (t = Float32) OR (t = Float64)
	END IsFloatType;

	PROCEDURE IsCharType*(t: Struct): BOOLEAN;
	BEGIN RETURN (t = Char8) OR (t = Char16) OR (t = Char32)
	END IsCharType;

	PROCEDURE IsPointer*(t: Struct): BOOLEAN;
	BEGIN  RETURN (t = Ptr) OR (t = NilType) OR (t IS Pointer)
	END IsPointer;

(* ug: new procedure *)
(* This procedure was necessary to insert because the parser must know whether a type contains pointers at the state PCT.structdeclared.
    The procedure PCV.TypeSize computes the size of a type and as a side effect sets the field containPtrs of the size object. However, this occurs
    sometimes too late for the parser, namely at the state change to PCT.structallocated.
    It is the programmer's responsability not to call the following procedure before t's scope has reached PCT.structdeclared. *)
	PROCEDURE ContainsPointer*(t: Struct): BOOLEAN;
		VAR b: BOOLEAN; f: Variable;
	BEGIN
		IF (t IS Pointer) OR (t = Ptr)  THEN  (* PTR/ANY, generic object type or open array *)
			RETURN TRUE
		ELSIF t IS Record THEN
			WITH t: Record DO
				IF t.brec # NIL THEN
					b:= ContainsPointer(t.brec)
				END;
				f := t.scope.firstVar;
				WHILE (f # NIL) & ~b DO
					b := ContainsPointer(f.type);
					f := f.nextVar
				END
			END;
			RETURN b
		ELSIF (t IS Array) & (t(Array).mode = static) THEN
			RETURN ContainsPointer(t(Array).base)
		ELSIF (t IS Delegate) & ~(StaticMethodsOnly IN t.flags) THEN
			RETURN TRUE
		ELSE RETURN FALSE
		END
	END ContainsPointer;

	PROCEDURE IsStaticDelegate*(t: Struct): BOOLEAN;
	BEGIN RETURN (t IS Delegate) & (StaticMethodsOnly IN t.flags)
	END IsStaticDelegate;

	PROCEDURE IsDynamicDelegate*(t: Struct): BOOLEAN;
	BEGIN RETURN (t IS Delegate) & ~(StaticMethodsOnly IN t.flags)
	END IsDynamicDelegate;

	PROCEDURE IsRecord*(t: Struct): BOOLEAN;
	BEGIN
		RETURN (t IS Record);
	END IsRecord;

	PROCEDURE IsBasic*(t: Struct): BOOLEAN;
	BEGIN
		RETURN (t IS Basic);
	END IsBasic;

	PROCEDURE BasicTypeDistance*(from, to: Basic): LONGINT;
		VAR i, j: LONGINT;
	BEGIN
		IF IsCharType(from) THEN
			i := 0; j := LEN(CharType);
			WHILE (i < LEN(CharType)) & (CharType[i] # from) DO  INC(i)  END;
			REPEAT  DEC(j)  UNTIL (j < i) OR (CharType[j] = to);
		ELSE
			i := 0; j := LEN(NumericType);
			WHILE (i < LEN(NumericType)) & (NumericType[i] # from) DO  INC(i)  END;
			REPEAT  DEC(j)  UNTIL (j < i) OR (NumericType[j] = to);
		END;
		RETURN j - i
	END BasicTypeDistance;

	PROCEDURE RecordTypeDistance*(from, to: Record): LONGINT;
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (from # NIL) & (from # to) DO  from := from.brec; INC(i)  END;
		IF from = NIL THEN  i := -1  END;
		RETURN i
	END RecordTypeDistance;

	PROCEDURE PointerTypeDistance*(from, to: Pointer): LONGINT;
	BEGIN
		IF ~((to.base IS Record) & (from.base IS Record)) THEN
			RETURN -1;
		ELSE
			RETURN RecordTypeDistance(from.baseR, to.baseR);
		END;
	END PointerTypeDistance;

	PROCEDURE ArrayTypeDistance*(from, to: Array): LONGINT;
		VAR i: LONGINT;
	BEGIN
		i := -1;
		IF from = to THEN
			i := 0
		ELSIF (from.mode = static) & (to.mode IN {open}) THEN
			i := TypeDistance(from.base, to.base);
			IF i >= 0 THEN INC(i) END
		ELSIF (from.mode = open) & (to.mode = open) THEN
			i := TypeDistance(from.base, to.base);
		END;
		RETURN i
	END ArrayTypeDistance;

	PROCEDURE TypeDistance*(from, to: Struct): LONGINT;
		VAR i: LONGINT; ptr: Pointer;
	BEGIN
		i := -1;
		IF from = to THEN
			i := 0
		ELSIF (to IS Array) & (to(Array).mode = open) & (to(Array).base = Byte) THEN
			i := 1
		ELSIF (from = String) THEN
			IF (to IS Array) & (to(Array).mode = open) & (to(Array).base = Char8) THEN  i := 1  END
		ELSIF (from = Char8) THEN
			IF (to IS Array) & (to(Array).mode = open) & (to(Array).base = Char8) THEN  i := 1
			ELSIF to = Byte THEN i := 1 END
		ELSIF (from = Int8) & (to = Byte) THEN
			i := 1
		ELSIF (from = NilType) THEN
			IF (to = Ptr) OR (to IS Pointer) OR (to IS Delegate) THEN i := 1 END
		ELSIF (from = NoType) THEN
			IF (to IS Delegate) THEN i := 1 END	(*special case: procedure -> proctype, not resolved yet*)
		ELSIF (from IS Basic) THEN
			IF to IS Basic THEN  i := BasicTypeDistance(from(Basic), to(Basic)) END
		ELSIF (from IS Array) THEN
			IF to IS Array THEN i := ArrayTypeDistance(from(Array), to(Array)) END
		ELSIF (from IS Record) THEN
			IF to IS Record THEN i := RecordTypeDistance(from(Record), to (Record)) END
		ELSIF (from IS Pointer) THEN
			ptr := from(Pointer);
			IF (to = Ptr) THEN i := 1
			ELSIF to IS Pointer THEN i := PointerTypeDistance(ptr, to(Pointer))
			(* ELSE i := TypeDistance(ptr.base, to); *)
			END
		(*no procedure test, procedure must be the same*)
		END;
		RETURN i
	END TypeDistance;

	PROCEDURE SignatureDistance*(from, to: Parameter): LONGINT;
		VAR i, res: LONGINT;
	BEGIN
		i := 0;
		WHILE (from # NIL) & (to # NIL) DO
			res := TypeDistance(from.type, to.type);
			IF res = -1 THEN  RETURN -1  END;
			INC(i, res);
			from := from.nextPar; to := to.nextPar
		END;
		RETURN i
	END SignatureDistance;

	PROCEDURE SignatureDistance0*(parCount: LONGINT; CONST pars: ARRAY OF Struct;  to: Parameter): LONGINT;
		VAR i, res, res0: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < parCount) DO
			res0 := TypeDistance(pars[i], to.type);
			IF res0 = -1 THEN  RETURN MAX(LONGINT)  END;
			INC(res, res0);
			to := to.nextPar;
			INC(i)
		END;
		ASSERT((to = NIL) OR (to.name = SelfName));
		RETURN res
	END SignatureDistance0;

	PROCEDURE IsLegalReturnType(t: Struct): BOOLEAN;
	BEGIN
		RETURN (t = NoType) OR (t IS Basic) OR IsPointer(t)
				OR (t IS Record) OR (t IS Array) (* & (t(Array).mode = static) *) OR (t IS Delegate) OR (t IS EnhArray) OR (t IS Tensor) (* fof *)
	END IsLegalReturnType;

	PROCEDURE ParameterMatch*(Pa, Pb: Parameter;  VAR faulty: Symbol): BOOLEAN;
	BEGIN
		faulty := NIL;
		IF Pa = Pb THEN RETURN TRUE END;
		WHILE (Pa # NIL) & (Pb # NIL) DO
			IF ((Pa.ref # Pb.ref) OR (Pa.flags * {PCM.ReadOnly} # Pb.flags * {PCM.ReadOnly}) OR ~EqualTypes(Pa.type, Pb.type)) & ((Pa.name # SelfName) OR (Pb.name # SelfName)) THEN
				faulty := Pa; RETURN FALSE
			END;
			Pa := Pa.nextPar;  Pb := Pb.nextPar;
		END;
		RETURN
			((Pa = NIL) OR (Pa.name = SelfName)) & ((Pb = NIL) OR (Pb.name = SelfName))
	END ParameterMatch;

	PROCEDURE EqualTypes*(Ta, Tb: Struct): BOOLEAN;
	VAR  dummy: Symbol;
	BEGIN

(* << Alexey, comparison of enhanced arrays and tensors *)

		IF Ta = Tb THEN
			RETURN TRUE;
		ELSIF Ta IS EnhArray THEN
			IF (Tb IS EnhArray) & (Ta(EnhArray).mode = Tb(EnhArray).mode) & (Ta(EnhArray).dim = Tb(EnhArray).dim) THEN
				IF Ta(EnhArray).mode = static THEN
					IF (Ta(EnhArray).len = Tb(EnhArray).len) & (Ta(EnhArray).inc = Tb(EnhArray).inc) & (EqualTypes(Ta(EnhArray).base,Tb(EnhArray).base)) THEN
						RETURN TRUE;
					END;
				ELSE
					IF (Ta(EnhArray).opendim = Tb(EnhArray).opendim) & EqualTypes(Ta(EnhArray).base,Tb(EnhArray).base) THEN
						RETURN TRUE;
					END;
				END;
			END;
		ELSIF Ta IS Tensor THEN
			IF (Tb IS Tensor) & (EqualTypes(Ta(Tensor).base,Tb(Tensor).base)) THEN
				RETURN TRUE;
			END;
		ELSIF Ta IS CustomArray THEN
			KernelLog.String('Custom arrays are not yet implemented!'); KernelLog.Ln;
		ELSIF (Ta IS Array) & (Tb IS Array) & (Ta(Array).mode = open) & (Tb(Array).mode = open) & EqualTypes(Ta(Array).base, Tb(Array).base) THEN
			RETURN TRUE;
		ELSIF (Ta IS Delegate) & (Tb IS Delegate) & ParameterMatch(Ta(Delegate).scope.firstPar, Tb(Delegate).scope.firstPar, dummy) & (Ta(Delegate).return = Tb(Delegate).return) THEN
			RETURN TRUE;
		END;

		RETURN FALSE;

(* >> Alexey*)

(*	commented by Alexey
		RETURN
		(* rule 1 *)	(Ta = Tb) OR
		(* rule 2*)	(Ta IS Array) & (Tb IS Array) &
							(Ta(Array).mode = open) & (Tb(Array).mode = open) &
							EqualTypes(Ta(Array).base, Tb(Array).base) OR
		(* rule 3*)	(Ta IS Delegate) & (Tb IS Delegate) &
								ParameterMatch(Ta(Delegate).scope.firstPar, Tb(Delegate).scope.firstPar, dummy) &
								(Ta(Delegate).return = Tb(Delegate).return)
*)
	END EqualTypes;

	PROCEDURE CheckForRecursion(type, banned: Struct): BOOLEAN;
	VAR res: BOOLEAN; brec: Record; f: Variable;
	BEGIN
		res := FALSE;
		IF type = NIL THEN
			(*skip*)
		ELSIF type = banned THEN
			res := TRUE
		ELSIF type IS Record THEN
			brec := type(Record).brec;
			IF brec # NIL THEN
				res := CheckForRecursion(brec, banned);
				IF ~res & (brec.scope # NIL) THEN
					f := brec.scope.firstVar;
					WHILE (f # NIL) & ~res DO
						res := CheckForRecursion(f.type, banned);
						f := f.nextVar;
					END
				END
			END
		ELSIF type IS Array THEN
			res := CheckForRecursion(type(Array).base, banned)
		END;
		RETURN res
	END CheckForRecursion;

	(* CompareSignature - res < 0 ==> s1 < s1; used for sorting overloaded procedures *)

	PROCEDURE CompareSignature(s1, s2: Parameter): LONGINT;
		VAR res: LONGINT;

		PROCEDURE GetInfo(t: Struct;  VAR m: Module;  VAR o: Symbol);
		BEGIN
			m := NIL;
			o := t.owner;
			IF (o = NIL) & (t IS Record) & (t(Record).ptr # NIL) THEN o := t(Record).ptr.owner END;
			IF (o # NIL) & (o.inScope # NIL) THEN
				m := o.inScope.module
			END
		END GetInfo;

		PROCEDURE CompareType(t1, t2: Struct): LONGINT;
		VAR
			m1, m2: Module;
			o1, o2: Symbol;
			res: LONGINT;
		BEGIN
			GetInfo(t1, m1,o1);
			GetInfo(t2, m2, o2);

			IF (t1 IS Array) & (t2 IS Array) THEN
				IF (t1(Array).mode = open) & ~(t2(Array).mode = open) THEN
					res := 1;
				ELSIF ~(t1(Array).mode = open) & (t2(Array).mode = open) THEN
					res := -1;
				ELSIF (t1(Array).mode = static) & (t2(Array).mode = static) THEN
					IF t1(Array).len > t2(Array).len THEN
						res := 1;
					ELSIF t1(Array).len < t2(Array).len THEN
						res := -1;
					ELSE
						res := CompareType(t1(Array).base, t2(Array).base);
					END;
				ELSE
					res := CompareType(t1(Array).base, t2(Array).base);
				END;
			ELSIF (t1 IS EnhArray) & (t2 IS EnhArray) THEN
				IF (t1(EnhArray).mode = open) & ~(t2(EnhArray).mode = open) THEN
					res := 1;
				ELSIF ~(t1(EnhArray).mode = open) & (t2(EnhArray).mode = open) THEN
					res := -1;
				ELSIF (t1(EnhArray).mode = static) & (t2(EnhArray).mode = static) THEN
					IF t1(EnhArray).len > t2(EnhArray).len THEN
						res := 1;
					ELSIF t1(EnhArray).len < t2(EnhArray).len THEN
						res := -1;
					ELSE
						res := CompareType(t1(EnhArray).base, t2(EnhArray).base);
					END;
				ELSE
					res := CompareType(t1(EnhArray).base, t2(EnhArray).base);
				END;
			ELSIF (t1 IS Pointer) & (t2 IS Pointer) THEN
				res := CompareType(t1(Pointer).base, t2(Pointer).base);
			ELSIF m1 = m2 THEN
				IF o1 = o2 THEN res := 0;
				ELSIF o1 = NIL THEN res := -1
				ELSIF o2 = NIL THEN res := 1
				ELSE res := StringPool.CompareString(o1.name, o2.name)
				END
			ELSIF m1 = NIL THEN res := -1
			ELSIF m2 = NIL THEN res := 1
			ELSE res := StringPool.CompareString(m1.name, m2.name)
			END;
			RETURN res;
		END CompareType;

	BEGIN
		IF s1 = s2 THEN res :=  0	(* both are NIL *)
		ELSIF s1 = NIL THEN res := -1
		ELSIF s2 = NIL THEN res := 1
		ELSIF s1.type = s2.type THEN res := CompareSignature(s1.nextPar, s2.nextPar)
		ELSE
(*
			GetInfo(s1.type, m1, o1);
			GetInfo(s2.type, m2, o1);
			IF m1 = m2 THEN
				IF o1 = o2 THEN res := CompareSignature(s1.nextPar, s2.nextPar)
				ELSIF o1 = NIL THEN res := -1
				ELSIF o2 = NIL THEN res := 1
				ELSE res := StringPool.CompareString(o1.name, o2.name)
				END
			ELSIF m1 = NIL THEN res := -1
			ELSIF m2 = NIL THEN res := 1
			ELSE res := StringPool.CompareString(m1.name, m2.name)
			END
*)
			res := CompareType(s1.type, s2.type);
			IF res = 0 THEN res := CompareSignature(s1.nextPar, s2.nextPar); END
		END;
		RETURN res
	END CompareSignature;

	(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
	PROCEDURE GetProcedureAllowed*(scope : ProcScope; returnType : Struct) : BOOLEAN;

		PROCEDURE TypeAllowed(type : Struct) : BOOLEAN;
		BEGIN
			RETURN (type = NoType) OR (type IS Record) OR ((type IS Pointer) & (type(Pointer).baseR # NIL));
		END TypeAllowed;

	BEGIN
		RETURN
			((scope.formalParCount = 0) & TypeAllowed(returnType)) OR
			((scope.formalParCount = 1) & TypeAllowed(scope.firstPar.type) & TypeAllowed(returnType)) OR
			((scope.formalParCount = 1) & (scope.firstPar.type = Ptr) & (returnType = Ptr)); (*  TO BE REMVOED REMOVE ANY->ANY *)
	END GetProcedureAllowed;

	(** ------------ Scope Related Functions  ------------------ *)

	PROCEDURE SetOwner*(scope: Scope);
	BEGIN  scope.ownerID := PCM.GetProcessID()
	END SetOwner;

	PROCEDURE InitScope*(scope, parent: Scope; flags: SET; imported: BOOLEAN);
	BEGIN
		ASSERT(scope.parent = NIL, 500);
		ASSERT(flags - {Overloading, AutodeclareSelf, SuperclassAvailable, CanSkipAllocation, RealtimeScope} = {}, 501);
		scope.parent := parent; scope.imported := imported; scope.flags := flags;
		IF (parent # NIL) & (RealtimeScope IN parent.flags) THEN
			INCL(scope.flags, RealtimeScope) (* ug: RealtimeScope flag is inherited from parent scope *)
		END;
		IF ~(scope IS ModScope) THEN scope.module := parent.module END
		(*
			Note: don't call SetOwner: this can cause a race condition, as usually the
			parent creates the scope and the child fills it. The checking of the parent may
			happen before the child has taken possession of the scope
		*)
	END InitScope;

	PROCEDURE Insert(scope: Scope; obj: Symbol; VAR res: LONGINT);
	VAR  p, q: Symbol; d: LONGINT;
	BEGIN
		ASSERT((scope.ownerID = 0) OR (PCM.GetProcessID() = scope.ownerID), 501); (*fof  global scope has no process id (=0) since different processes may insert elements here, cf. procedure Init *)
		(* ASSERT(scope.state < complete, 502); *)
		IF (scope.state >= complete) & (scope IS ModScope) THEN
			res := ImportCycle;
			RETURN;
		END;
		(* ASSERT((scope.state < structdeclared) OR (obj IS Proc), 503); *)
		obj.inScope := scope;
		obj.sorted := NIL;
		scope.last := obj;
		IF (obj.name # Anonymous) THEN
			p := scope.sorted; q := NIL;
			WHILE (p # NIL) & (StringPool.CompareString(p.name, obj.name) < 0) DO  q := p; p := p.sorted  END;
			IF (p = NIL) OR (p.name # obj.name) THEN
				(* ok *)
			ELSIF (Overloading IN scope.module.scope.flags) OR ((Operator IN obj.flags)  & ~(Indexer IN obj.flags) ) THEN
				IF obj IS Proc THEN
					WITH obj: Proc DO
						IF ~(p IS Proc) THEN q := p; p := p.sorted END;
						d := 1;
						WHILE (d > 0) & (p # NIL) & (p.name = obj.name) DO
							d := CompareSignature(p(Proc).scope.firstPar, obj.scope.firstPar);
							IF d > 0 THEN q := p; p := p.sorted END
						END;
						IF d = 0 THEN
							IF Operator IN obj.flags THEN
								res := DuplicateOperator
							ELSE
								res := DuplicateSymbol
							END
						END
					END
				ELSIF ~(p IS Proc) THEN
					res := DuplicateSymbol
				END
			ELSE
					res := DuplicateSymbol
			END;
			IF res = Ok THEN
				obj.sorted := p;
				IF q = NIL THEN scope.sorted := obj ELSE q.sorted := obj END
			END
		END
	END Insert;

	PROCEDURE Lookup(scope: Scope; name: StringIndex): Symbol;
	VAR  p: Symbol;
	BEGIN
		(* it is cheaper to traverse the whole list, than to compare the strings *)
		p := scope.sorted;
		WHILE (p # NIL) & (p.name # name) DO  p := p.sorted  END;
		IF (p = NIL) OR (p.name # name) THEN
			p := NIL
		ELSE
			p.Use;
		END;
		RETURN p
	END Lookup;

	(* ug *)
	PROCEDURE HiddenVarExists*(scope: Scope; info: ANY): BOOLEAN;
		VAR v: Variable;
	BEGIN
		v := scope.firstHiddenVar;
		WHILE (v # NIL) & ((v.vis # Hidden) OR (v.info # info)) DO v := v.nextVar END;
		RETURN v # NIL
	END HiddenVarExists;

	PROCEDURE IsVisible(vis: SET; current, search: Scope;  localsearch: BOOLEAN): BOOLEAN;
		VAR res: BOOLEAN; rec, tmp: Record;
	BEGIN
		res := FALSE;
		IF HiddenRW IN vis THEN (* ug *)
			res := FALSE
		ELSIF current = search THEN
			res := TRUE
		ELSIF PublicR IN vis THEN
			res := TRUE
		ELSIF (InternalR IN vis) & (current.module = search.module) THEN
			res := TRUE
		ELSIF (ProtectedR IN vis) THEN
			IF localsearch THEN
				res := TRUE
			ELSE
				WHILE (current # NIL) & ~(current IS RecScope) DO  current := current.parent  END;
				IF current # NIL THEN
					rec := search(RecScope).owner;
					tmp := current(RecScope).owner;
					WHILE (tmp # NIL) & (tmp # rec) DO  tmp := tmp.brec  END;
					res := tmp # NIL
				END
			END
		END;
		RETURN res
	END IsVisible;

	(** Find -
		findAny -> if FALSE and duplicatesAllowed, find the first non-procedure
		mark -> mark the object as used
	*)

	PROCEDURE Find*(current, search: Scope;  name: StringIndex;  mode: SHORTINT; mark: BOOLEAN): Symbol;
		VAR p: Symbol; rec: Record; backtrack: Scope; localsearch, restrict: BOOLEAN;
	BEGIN
		restrict := FALSE;
		IF current = search THEN
			localsearch := TRUE;
			p := Lookup(Universe.scope, name)
		END;
		IF (p = NIL) & (search IS RecScope) THEN
			rec := search(RecScope).owner;
			IF localsearch THEN  backtrack := search.parent  END	(*allow search outside the record hierarchy*)
		END;

		WHILE (p = NIL) & (search # NIL) DO
			IF (mode # local) & (PCM.GetProcessID() # search.ownerID) THEN
				search.Await(mode)
			END;
			p := Lookup(search, name);

			IF (p # NIL) & IsVisible(p.vis, current, search, localsearch) & (~restrict OR (search IS ModScope) OR (p IS Type) OR (p IS Value))THEN
				(*skip*)
			ELSIF rec # NIL THEN
				p := NIL;
				rec := rec.brec;
				IF rec = NIL THEN
					search := backtrack;
					restrict := TRUE;
				ELSE
					search := rec.scope
				END
			ELSE
				p := NIL;
				search := search.parent;
				IF (search # NIL) & (search IS RecScope) THEN
					rec := search(RecScope).owner;
					backtrack := search.parent
				END
			END
		END;
		IF mark & (p # NIL) THEN p.Use END;
		RETURN p
	END Find;


	PROCEDURE FindIndexer*(scope: RecScope; name: StringIndex): Method;
	VAR s: Symbol;
	BEGIN
		IF scope = NIL THEN RETURN NIL END;
		s := Lookup(scope, name);
		IF (s # NIL) & (s IS Method) THEN RETURN s(Method) ELSE
			IF scope.owner.brec # NIL THEN
				RETURN FindIndexer(scope.owner.brec.scope, name)
			ELSE
				RETURN NIL
			END
		END
	END FindIndexer;


	PROCEDURE FindOperator*(current, search: Scope; parents: BOOLEAN; name: StringIndex; CONST pars: ARRAY OF Struct; parCount (*ug*), pos: LONGINT): Proc;
	VAR
		p: Symbol;
		hitProc: Proc;
		hitScope: Scope;
		dist, hit, i: LONGINT;
		hitClash, localDone: BOOLEAN;
	BEGIN
		localDone := FALSE;
		hitClash := FALSE;
		hit := MAX(LONGINT);
		hitProc := NIL;
		i := 0;

		IF (PCM.GetProcessID() # search.ownerID) THEN search.Await(procdeclared) END;

		WHILE ~localDone DO
			p := Lookup(search, name);
			WHILE (p # NIL) & (p.name = name) DO
				IF (p IS Proc) & (p(Proc).scope.formalParCount = parCount) THEN (* ug *)
					IF IsVisible(p.vis, current, search, current = search) THEN
						dist := Distance(pars, p(Proc).scope.firstPar, parCount (* ug *));
						(* dist := SignatureDistance0(parCount, pars, p(Proc).scope.firstPar); *)
						IF dist >= MAX(LONGINT) THEN
							(* operator not applicable *)
						ELSIF dist < hit THEN
							hitProc := p(Proc);
							hitScope := search;
							hit := dist;
							hitClash := FALSE;
						ELSIF (dist = hit) & (hitScope = search) THEN
							(* two operators with equal distance found *)
							hitClash := TRUE;
							(* PCM.Error(139, pos, " (local)"); *)
						END
					END;
				END;
				p := p.sorted;
			END;
			IF search # search.module.scope THEN
				search := search.parent;
			ELSE
				localDone := TRUE;
			END;
		END;
		IF hitClash & (hit = 0) THEN
			PCM.Error(139, pos, " (local)");
		END;
		IF (search(ModScope).owner.imports # NIL) & (hit > 0) & (parents) THEN
			(*
			PrintString(search(ModScope).owner.name); KernelLog.String(" imports:"); KernelLog.Ln;
			FOR i := 0 TO LEN(search(ModScope).owner.imports^) - 1 DO
				IF search(ModScope).owner.imports[i] # NIL THEN
					KernelLog.String(" "); PrintString(search(ModScope).owner.imports[i].name); KernelLog.Ln;
				ELSE
					KernelLog.String(" NIL");
				END;
			END;
			*)
			i := 0;
			WHILE (i < LEN(search(ModScope).owner.imports^)) & (search(ModScope).owner.imports[i] # NIL) DO
				IF (PCM.GetProcessID() # search(ModScope).owner.imports[i].scope.ownerID) THEN search.Await(procdeclared) END;
				p := Lookup(search(ModScope).owner.imports[i].scope, name);
				WHILE (p # NIL) & (p.name = name) DO
					IF (p IS Proc) & (p(Proc).scope.formalParCount = parCount) (* ug *) THEN
						IF IsVisible(p.vis, current, search(ModScope).owner.imports[i].scope, current = search(ModScope).owner.imports[i].scope) THEN
							dist := Distance(pars, p(Proc).scope.firstPar, parCount (* ug *));
							(* dist := SignatureDistance0(parCount, pars, p(Proc).scope.firstPar); *)
							IF dist >= MAX(LONGINT) THEN
								(* operator not applicable *)
							ELSIF dist < hit THEN
								hitProc := p(Proc);
								hit := dist;
								hitClash := FALSE;
							ELSIF (dist = hit) & (hitProc.inScope.module # current.module) THEN
								(* if best operator (hitProc) is not defined in local module, then error: operator not unique *)
								PCM.Error(139, pos, "");
							END
						END;
					END;
					p := p.sorted;
				END;
				INC(i);
			END;
		END;
		IF hitClash THEN
			PCM.Error(139, pos, " (local)");
		END;
		RETURN hitProc;
	END FindOperator;

	PROCEDURE PrintString*(s: StringPool.Index);
	VAR str: PCS.String;
	BEGIN
		StringPool.GetString(s, str);
		KernelLog.String(str);
	END PrintString;

	PROCEDURE Distance(CONST pars: ARRAY OF Struct; param: Parameter; parCount: LONGINT (* ug *)): LONGINT;
	VAR dist, res, i: LONGINT;
		baseA, baseF: Struct;
	BEGIN
		dist := 0;
		FOR i := 0 TO parCount-1 DO (* ug *)
			IF (pars[i] = NilType) OR (param.type = NilType) THEN
				RETURN MAX(LONGINT);
			END;
			res := TypeDistance(pars[i], param.type);
			IF res = -1 THEN
				(* no match *)
				RETURN MAX(LONGINT);
			END;
			IF (param.ref) & (res # 0) & ~(param.type IS Array) THEN
				(* actual and formal types of VAR parameter must be identical *)
				RETURN MAX(LONGINT);
			END;
			IF (param.ref) & (res # 0) & (param.type IS Array) & (pars[i] IS Array)THEN
				(* maybe the only difference is an open array ... go down the array chain *)
				baseA := pars[i](Array).base;	(* actual parameter *)
				baseF := param.type(Array).base;	(* formal parameter *)
				WHILE (baseA IS Array) & (baseF IS Array) DO
						baseA := baseA(Array).base;
						baseF := baseF(Array).base;
				END;
				IF TypeDistance(baseA, baseF) # 0 THEN
					RETURN MAX(LONGINT);
				END;
			END;
			INC(dist, res);
			param := param.nextPar;
		END;
		RETURN dist;
	END Distance;

	PROCEDURE FindProcedure*(current, search: Scope;  name: StringIndex;  parCount: LONGINT;  CONST pars: ARRAY OF Struct; identicSignature, mark: BOOLEAN): Proc;
		VAR p: Symbol; hitProc: Proc; rec: Record; backtrack: Scope; localsearch: BOOLEAN; totCount, hit, dist: LONGINT;
	BEGIN
		IF identicSignature THEN hit := 1 ELSE hit := MAX(LONGINT) END;
		localsearch := current = search;
		totCount := parCount;
		IF (search IS RecScope) THEN
			INC(totCount);	(* include SELF *)
			rec := search(RecScope).owner;
			IF localsearch THEN backtrack := search.parent  END	(*allow search outside the record hierarchy*)
		END;

		WHILE (hit # 0) & (search # NIL) DO
			IF (PCM.GetProcessID() # search.ownerID) THEN search.Await(procdeclared) END;
			p := Lookup(search, name);

			WHILE (p # NIL) & (p.name = name) DO
				IF IsVisible(p.vis, current, search, localsearch) & (p IS Proc) THEN
					WITH p: Proc DO
						IF (totCount = p.scope.parCount) THEN
							dist := SignatureDistance0(parCount, pars, p.scope.firstPar);
							IF dist < hit THEN
								hitProc := p; hit := dist
							END
						END
					END
				END;
				p := p.sorted
			END;

			IF (hit = 0) THEN
				(*skip*)
			ELSIF rec # NIL THEN
				rec := rec.brec;
				IF rec # NIL THEN search := rec.scope ELSE search := backtrack; totCount := parCount END
			ELSE
				search := search.parent;
				IF (search # NIL) & (search IS RecScope) THEN
					rec := search(RecScope).owner;
					backtrack := search.parent
				END
			END
		END;
		IF mark & (hitProc # NIL) THEN hitProc.Use END;
		RETURN hitProc
	END FindProcedure;

	PROCEDURE FindSameSignature*(search: Scope; name: StringIndex; par: Parameter; identic: BOOLEAN): Proc;
		VAR i: LONGINT; parlist: ARRAY 32 OF Struct;
	BEGIN
		WHILE (par # NIL) & (par.name # SelfName) DO
			parlist[i] := par.type; INC(i);
			par := par.nextPar
		END;
		RETURN FindProcedure(search, search, name, i, parlist, identic, FALSE)
	END FindSameSignature;

	PROCEDURE CheckInterfaceImpl(rec, int: Record; VAR res: LONGINT);
		VAR m: Proc; o (* , faulty *): Symbol;
	BEGIN
		m := int.scope.firstProc;
		WHILE m # NIL DO
			o := FindSameSignature(rec.scope, m.name, m.scope.firstPar, TRUE);
			IF o = NIL THEN
				res := 290
(*
			ELSIF ~ParameterMatch(m.scope.firstPar, o(Method).scope.firstPar, faulty) THEN
				res := 115
*)
			ELSIF m.type # o.type THEN
				res := 117
			END;
			m := m.nextProc
		END
	END CheckInterfaceImpl;

	PROCEDURE StateStructShallowAllocated*(scope: Scope); (* fof *)
	VAR state: LONGINT;
	BEGIN
		state := scope.state;
		IF scope.state < structshallowallocated THEN
			scope.ChangeState(structshallowallocated);
		ELSE
			HALT(100);
		END;
	END StateStructShallowAllocated;


	PROCEDURE ChangeState*(scope: Scope;  state: SHORTINT;  pos: LONGINT);
	VAR  rec, r, int: Record; rscope: RecScope; mth: Method; i, res: LONGINT;
	BEGIN
		WHILE scope.state < state DO
			CASE scope.state+1 OF
			|  structdeclared:
			|  structshallowallocated:
					IF scope.imported THEN
						Allocate(NIL, scope, FALSE) 					(* ug: hiddenVarsOnly = FALSE *)
					ELSE
						Allocate(scope.module.scope, scope, FALSE)	(* ug: hiddenVarsOnly = FALSE *)
					END;
			|  structallocated: (* automatically increment after structshallowallocated *)
			|  procdeclared:
					IF (scope IS RecScope) THEN
						rscope := scope(RecScope); rec := rscope.owner;
						rscope.totalProcCount := rscope.procCount;
						IF (rec.brec # NIL) & ~rec.brec.imported THEN
							rec.brec.scope.Await(procdeclared);
						END;
						IF ~(SuperclassAvailable IN scope.flags) & (rec.brec # NIL) THEN
							INC(rscope.totalProcCount, rec.brec.scope.procCount);
							mth := rscope.firstMeth;
							WHILE mth# NIL DO
								IF ~(NonVirtual IN mth.flags) THEN
									mth.super := FindOverwrittenMethod(rec, mth.name, mth.scope,res); ASSERT(res = Ok)
								END;
								IF mth.super # NIL THEN DEC(rscope.totalProcCount); mth.Use END;
								mth := mth.nextMeth
							END
						END;
						IF (res = 0) & (rscope.initproc = NIL) THEN
							REPEAT  rec := rec.brec  UNTIL  (rec = NIL) OR (rec.scope.initproc # NIL);
							IF rec # NIL THEN  rscope.initproc := rec.scope.initproc  END;
						END;
						rec := rscope.owner; r := rec;
						IF (res = 0) & ~(interface IN r.mode) THEN
							WHILE (r # NIL) & (res = 0) DO
								FOR i := 0 TO LEN(r.intf)-1 DO
									int := r.intf[i].baseR;
									IF ~int.imported THEN
										int.scope.Await(procdeclared);
									END;
									CheckInterfaceImpl(rec, int, res)
								END;
								r := r.brec;
							END
						END;
						IF res # 0 THEN PCM.Error(res, pos, "") END
					END;
					PostAllocate(NIL, scope)
			|  hiddenvarsdeclared:
					IF scope.imported THEN
						Allocate(NIL, scope, TRUE) 					(* ug: hiddenVarsOnly = TRUE *)
					ELSE
						Allocate(scope.module.scope, scope, TRUE)	(* ug: hiddenVarsOnly = TRUE *)
					END;
			|  modeavailable:
			|  complete:
			END;
			scope.ChangeState(scope.state+1)
		END
	END ChangeState;

	PROCEDURE Import*(self: Module;  VAR new: Module;  name: StringIndex);
		VAR i: LONGINT;
	BEGIN
		new := NIL;
		IF name = System.name THEN
			new := System;
			IF self # NIL THEN self.sysImported := TRUE END
		ELSIF (self # NIL) & (self.imports # NIL) THEN
			i := 0;
			WHILE (i < LEN(self.imports)) & (self.imports[i] # NIL) & (self.imports[i].name # name) DO
				INC(i)
			END;
			IF (i < LEN(self.imports)) & (self.imports[i] # NIL) THEN
				new := self.imports[i];
			END
		END;
		IF new = NIL THEN
			new := Retrieve(database, name);
			IF (new # NIL) & (self # NIL) THEN self.AddImport(new) END;
		END;
		i := 0;
		WHILE (new = NIL) & (i < nofImportPlugins) DO
			import[i](self, new, name);
			INC(i);
			IF (PCM.CacheImports IN PCM.parserOptions) & (new # NIL) THEN
				Register(database, new);
			END
		END;
	END Import;

	PROCEDURE TraverseScopes*(top: Scope;  proc: PROCEDURE(s: Scope));
	VAR s: Scope; lastType: Struct; t: Type; v: Variable; p: Proc;

		PROCEDURE ExtractScope(o: Symbol): Scope;
			VAR type: Struct; s: Scope;
		BEGIN
			type := o.type;
			LOOP
				IF (type.owner # NIL) & (type.owner # o) THEN
					EXIT
				ELSIF type IS Array THEN
					type := type(Array).base
				ELSIF type IS Pointer THEN
					type := type(Pointer).base
				ELSE
					IF (type IS Record) & ~(interface IN type(Record).mode) THEN s := type(Record).scope END;
					EXIT
				END
			END;
			RETURN s
		END ExtractScope;

	BEGIN
		top.Await(complete);
		IF top IS ModScope THEN  proc(top)  END;

		t := top.firstType;
		WHILE t # NIL DO
			s := ExtractScope(t);
			IF s # NIL THEN TraverseScopes(s, proc); proc(s) END;
			t := t.nextType
		END;
		v := top.firstVar;
		WHILE v # NIL DO
			IF v.type # lastType THEN
				lastType := v.type;
				s := ExtractScope(v);
				IF s # NIL THEN TraverseScopes(s, proc); proc(s) END
			END;
			v := v.nextVar
		END;
		p := top.firstProc;
		WHILE p # NIL DO
			s := p.scope;
			TraverseScopes(s, proc); proc(s);
			p := p.nextProc
		END;
	END TraverseScopes;

	PROCEDURE AddRecord*(scope: Scope;  rec: Record);
	VAR mod: ModScope;
	BEGIN {EXCLUSIVE}
		mod := scope.module.scope;
		rec.link := mod.records; mod.records := rec;
		INC(mod.nofRecs);
	END AddRecord;

	PROCEDURE CommitParList(scope: ProcScope;  level: SHORTINT);
		VAR p: Parameter;
	BEGIN
		p := scope.firstPar;
		WHILE p # NIL DO
			p.level := level; p := p.nextPar
		END
	END CommitParList;
	(** ------------ Const Creation ------------------- *)

	PROCEDURE GetIntType*(i: LONGINT): Struct;
		VAR type: Struct;
	BEGIN
		IF (MIN(SHORTINT) <= i) & (i <= MAX(SHORTINT)) THEN  type := Int8
		ELSIF (MIN(INTEGER) <= i) & (i <= MAX(INTEGER)) THEN  type := Int16
		ELSE  type := Int32
		END;
		RETURN type
	END GetIntType;

	PROCEDURE GetCharType*(i: LONGINT): Struct;
		VAR type: Struct;
	BEGIN
		IF PCM.LocalUnicodeSupport THEN
			IF (0 > i) OR (i > 0FFFFH) THEN type := Char32
			ELSIF (i > 0FFH) THEN type := Char16
			ELSE type := Char8
			END;
			RETURN type
		ELSE
			RETURN Char8
		END;
	END GetCharType;

	PROCEDURE NewIntConst*(i: LONGINT; type: Struct): Const;
	VAR c: Const;
	BEGIN NEW(c); c.int := i; c.type := type; RETURN c
	END NewIntConst;

	PROCEDURE NewInt64Const*(i: HUGEINT): Const;
	VAR c: Const;
	BEGIN NEW(c); c.long := i; c.type := Int64; RETURN c
	END NewInt64Const;

	PROCEDURE NewBoolConst(b: BOOLEAN): Const;
	VAR c: Const;
	BEGIN  NEW(c);  c.bool := b; c.type := Bool;  RETURN c
	END NewBoolConst;

	PROCEDURE NewSetConst*(s: SET): Const;
	VAR c: Const;
	BEGIN  NEW(c);  c.set := s; c.type := Set;  RETURN c
	END NewSetConst;

	PROCEDURE NewFloatConst*(r: LONGREAL; type: Struct): Const;
	VAR c: Const;
	BEGIN
		ASSERT((type = Float32) OR (type = Float64));
		NEW(c); c.real := r;  c.type := type;  RETURN c
	END NewFloatConst;

	PROCEDURE NewStringConst*(CONST str: ARRAY OF CHAR): Const;
	VAR c: Const;  len: LONGINT;
	BEGIN
		len := 0;
		WHILE str[len] # 0X DO  INC(len)  END;
		NEW(c); NEW(c.str); c.int := len+1; COPY(str, c.str^); c.type := String; RETURN c
	END NewStringConst;

	PROCEDURE NewPtrConst*(p: ANY; type: Struct): Const;
		VAR c: Const;
	BEGIN  NEW(c);  c.ptr := p;  c.type := type;  RETURN c
	END NewPtrConst;

(** fof >> *)

	PROCEDURE MakeArrayType*(len: ARRAY OF LONGINT; dim: LONGINT; base: Struct; basesize: LONGINT): Struct;
	VAR inc: LONGINT; a: EnhArray; i,res: LONGINT;
	BEGIN
		inc := basesize;
		FOR i := dim - 1 TO 0 BY -1 DO
			NEW( a );
			InitStaticEnhArray( a, len[i], base, {static}, res );   (* temporary ! *)
			a.inc := inc;  inc := inc * len[i];
			base := a;
		END;
		RETURN base
	END MakeArrayType;


	PROCEDURE NewArrayConst*( VAR data: ARRAY OF SYSTEM.BYTE;   len: ARRAY OF LONGINT;  dim: LONGINT;  base: Struct; basesize: LONGINT): Const;
	(* create new array constant with dimension LEN(len) und shape len of base type base with size basesize (defined in PCBT) *)
	VAR c: ConstArray;  i, lencheck: LONGINT;  a: EnhArray;
		res: LONGINT;  inc: LONGINT;
	BEGIN

		ASSERT( dim <= LEN( len ) );  NEW( c );
		NEW( c.data, LEN( data ) );
		SYSTEM.MOVE( ADDRESSOF( data[0] ), ADDRESSOF( c.data[0] ), LEN( data ) );
		NEW( c.len, dim );
		SYSTEM.MOVE( ADDRESSOF( len[0] ),   ADDRESSOF( c.len[0] ),  SIZEOF( LONGINT ) * dim );

		lencheck := 1;  inc := basesize;
		FOR i := dim - 1 TO 0 BY -1 DO
			NEW( a );
			InitStaticEnhArray( a, len[i], base, {static}, res );   (* temporary ! *)
			a.inc := inc;  inc := inc * len[i];
			lencheck := lencheck * len[i];  base := a;
		END;
		ASSERT( lencheck * basesize = LEN( data ) );
		c.type := base;  RETURN c;
	END NewArrayConst;
(** << fof  *)

	(** ------------ Structure Creation ------------------- *)

	PROCEDURE CheckArrayBase(a: Array; allowedMode: SET; VAR res: LONGINT);
	VAR  base: Array;
	BEGIN
		ASSERT(a.base # NIL, 500);
		IF CheckForRecursion(a.base, a) THEN
			res := RecursiveType;
			a.base := NoType
		END;
		IF (a.base IS Array) THEN
			base := a.base(Array);
			IF ~(base.mode IN allowedMode) THEN
				res := IllegalArrayBase; a.base := Char8
			ELSE
				a.opendim := base.opendim
			END
		(** fof >> *)
		ELSIF a.base IS EnhArray THEN  (* mixture of enharrys and arrays is forbidden *)  (*fof*)
			res := IllegalMixture;
		(** << fof  *)
		END;
	END CheckArrayBase;

(** fof >> *)
	PROCEDURE CheckEnhArrayBase( a: EnhArray;   allowedMode: SET;  VAR res: LONGINT );
	VAR base: EnhArray;
	BEGIN
		ASSERT( a.base # NIL , 500 );
		IF CheckForRecursion( a.base, a ) THEN
			res := RecursiveType;  a.base := NoType
		END;
		IF (a.base IS EnhArray) THEN
			base := a.base( EnhArray );
			IF ~(base.mode IN allowedMode) THEN
				res := IllegalArrayBase;  a.base := Char8
			ELSE a.opendim := base.opendim;  a.dim := base.dim
			END
		ELSIF a.base IS Array THEN  (* mixture of enharrys and arrays is forbidden *)
			res := IllegalMixture;
		ELSE a.opendim := 0;  a.dim := 0;
		END;
	END CheckEnhArrayBase;

	PROCEDURE ElementType*( a: Struct ): Struct;
	BEGIN
		IF a IS EnhArray THEN
			WHILE (a IS EnhArray) DO a := a( EnhArray ).base;  END;
		ELSIF a IS Tensor THEN a := a( Tensor ).base;
		END;
		RETURN a;
	END ElementType;
(** << fof  *)

	PROCEDURE InitOpenArray*(a: Array;  base: Struct; VAR res: LONGINT);
	BEGIN
		res := Ok;
		a.mode := open; a.base := base;
		CheckArrayBase(a, {static, open}, res);
		INC(a.opendim);
	END InitOpenArray;

	PROCEDURE InitStaticArray*(a: Array; len: LONGINT; base: Struct; VAR res: LONGINT);
	BEGIN
		res := Ok;
		a.mode := static; a.len := len; a.base := base;
		IF len < 0 THEN  res := IllegalValue; a.len := 1  END;
		CheckArrayBase(a, {static}, res);
	END InitStaticArray;

(** fof >> *)
	PROCEDURE InitTensor*( a: Tensor;  base: Struct;  VAR res: LONGINT );
	BEGIN
		res := Ok;  a.base := base;  (* any checks ? *)
	END InitTensor;

	PROCEDURE InitOpenEnhArray*( a: EnhArray;  base: Struct;  allow: SET; VAR res: LONGINT );   (*fof*)
	BEGIN
		res := Ok;  a.mode := open;  a.base := base;  a.len := 0;
		CheckEnhArrayBase( a, allow, res );  INC( a.opendim );
		INC( a.dim );
		(* it is not allowed to mix open and static arrays *)
	END InitOpenEnhArray;

	PROCEDURE InitStaticEnhArray*( a: EnhArray;   len: LONGINT;   base: Struct;  allow: SET;   VAR res: LONGINT );   (*fof*)
	BEGIN
		res := Ok;  a.mode := static;  a.len := len;  a.base := base;
		IF len < 0 THEN res := IllegalValue;  a.len := 1 END;
		CheckEnhArrayBase( a, allow, res );  INC( a.dim );
		(* it is not allowed to mix open and static arrays *)
	END InitStaticEnhArray;

	PROCEDURE SetEnhArrayLen*( a: EnhArray;  len: LONGINT );   (* len is write protected, programmers must know what they are doing *)
	BEGIN
		a.len := len;
	END SetEnhArrayLen;

	PROCEDURE SetEnhArrayInc*( a: EnhArray;  inc: LONGINT );   (* inc is write protected, programmers must know what they are doing *)
	BEGIN
		a.inc := inc;
	END SetEnhArrayInc;

	PROCEDURE BuildOpenArray*( base: Struct; dim: LONGINT ): Struct;
	VAR a: EnhArray;  res: LONGINT;
	BEGIN
		IF dim > 0 THEN
			base := BuildOpenArray( base, dim - 1 );  NEW( a );
			InitOpenEnhArray( a, base, {open}, res );  RETURN a;
		ELSE RETURN base;
		END;
	END BuildOpenArray;

	PROCEDURE BuildTensor*( base: Struct ): Tensor;
	VAR a: Tensor;  res: LONGINT;
	BEGIN
		NEW( a );  InitTensor( a, base, res );  RETURN a;
	END BuildTensor;
(** << fof  *)

	PROCEDURE CopyMethods(scope: RecScope; CONST intf: Interfaces; isImported: BOOLEAN);
		VAR i, res: LONGINT; rs: RecScope; s: ProcScope; m: Method; par: Parameter;
			f: SET;
	BEGIN
		i := 0;
		WHILE (i < LEN(intf)) & (intf[i] # NIL) DO
			rs := intf[i].baseR.scope;
			IF ~isImported THEN rs.Await(procdeclared) END;
			m := rs.firstMeth;
			WHILE m # NIL DO
				NEW(s); InitScope(s, scope, {AutodeclareSelf}, FALSE); SetOwner(s);
				par := m.scope.firstPar;
				WHILE (par # m.scope.lastPar) DO
					s.CreatePar(par.vis, par.ref, par.name, par.flags, par.type, 0 (*fof *), res); ASSERT(res = 0);
					par := par.nextPar
				END;
				f := m.flags;
				scope.CreateProc(m.name, m.vis, m.flags-{used}+{copy}, s, m.type, 0(*fof*), res);
				IF res = 1 THEN
					KernelLog.String("CopyMethods: Duplicate Interface Method"); KernelLog.Ln;
					res := 0
				END;
				ASSERT(res = 0);
				m := m.nextMeth;
			END;
			INC(i);
		END;
	END CopyMethods;

	PROCEDURE InitRecord*(r: Record;  base: Struct;  CONST intf: Interfaces; scope: RecScope;  isInterface, isImported, isDynamic: BOOLEAN; VAR res: LONGINT);
		VAR i: LONGINT;
	BEGIN
		res := Ok;
		ASSERT(base # NIL, 500);
		ASSERT(scope # NIL, 501);
		ASSERT((scope.owner = NIL) OR (scope.owner = r), 502);
		(*r.ptr := NIL;*) r.brec := NIL; r.btyp := base; r.scope := scope;
		scope.owner := r; r.imported := isImported;
		IF isInterface THEN
			INCL(r.mode, interface);
			CopyMethods(scope, intf, isImported)
		END;
		IF base IS Pointer THEN
			base := base(Pointer).base;
			IF ~isDynamic THEN res := ObjectOnly END
		END;
		IF base IS Record THEN
			IF isInterface THEN res := 601(*NotImplemented*) END;
			IF CheckForRecursion(base, r) THEN
				res := RecursiveType;
				base := NoType
			END;
			WITH base: Record DO
				RecordSizeUsed(base);
				r.brec := base
			END
		ELSIF (base # NoType) & (SuperclassAvailable IN scope.flags) THEN
			res := NotAType;
			r.btyp := NoType
		END;
		i := 0;
		WHILE (i < LEN(intf)) & (intf[i] # NIL) DO
			IF ~(interface IN intf[i].baseR.mode) THEN res := 602(*NotImplemented*)  END;
			INC(i)
		END;
		NEW(r.intf, i);
		WHILE (i > 0) DO  DEC(i); r.intf[i] := intf[i]  END
	END InitRecord;

	PROCEDURE NewRecord*(base: Struct;  scope: RecScope;  flags: SET; imported: BOOLEAN; VAR res: LONGINT): Record;
	VAR  r: Record; intf: ARRAY 1 OF Interface;
	BEGIN
		ASSERT(flags - {SystemType} = {}, 500);
		res := Ok;
		NEW(r); InitRecord(r, base, intf, scope, FALSE, imported, FALSE, res);
		r.flags := flags;
		NEW(r.intf, 0);
		RETURN r
	END NewRecord;

(** fof >> *)
	PROCEDURE InitCustomArray*(r: CustomArray;  base: Struct;  dim: LONGINT;scope: CustomArrayScope; VAR res: LONGINT);
	VAR i: LONGINT;intf: ARRAY 1 OF Interface;
	BEGIN
		InitRecord(r,NoType, intf, scope, FALSE, FALSE, FALSE, res);
		r.dim := dim;  r.etyp := base;
	END InitCustomArray;

	PROCEDURE NewCustomArray*(base: Struct; dim: LONGINT;  scope: CustomArrayScope;  VAR res: LONGINT): Pointer;
	VAR  p: Pointer;  r: CustomArray;
	BEGIN
		res := Ok;
		ASSERT(base # NIL, 500);
		ASSERT(scope # NIL, 501);
		NEW(p); NEW(r); InitCustomArray(r, base, dim, scope, res);
		r.ptr := p; p.base := r; p.baseR := r;
		RETURN p
	END NewCustomArray;
(** << fof  *)

	PROCEDURE NewClass*(base: Struct;  CONST implements: Interfaces;  scope: RecScope;  imported: BOOLEAN; VAR res: LONGINT): Pointer;
	VAR  p: Pointer;  r: Record;
	BEGIN
		res := Ok;
		ASSERT(base # NIL, 500);
		ASSERT(scope # NIL, 501);
		NEW(p); NEW(r); InitRecord(r, base, implements, scope, FALSE, imported, TRUE, res);
		INCL(r.mode, class);
		r.ptr := p; p.base := r; p.baseR := r;
(*
		IF (r.brec # NIL) & ~(class IN r.brec.mode) THEN PCM.Error(pos, 200, "base class is not a class")  END;
*)
		RETURN p
	END NewClass;

	PROCEDURE NewInterface*(CONST implements: Interfaces;  scope: RecScope;  imported: BOOLEAN; VAR res: LONGINT): Pointer;
	VAR  p: Pointer;  r: Record;
	BEGIN
		res := Ok;
		ASSERT(scope # NIL, 501);
		NEW(p); NEW(r);
		r.ptr := p; p.base := r; p.baseR := r;
		InitRecord(r, NoType, implements, scope, TRUE, imported, TRUE, res);
		RETURN p
	END NewInterface;

	PROCEDURE InitPointer*(ptr: Pointer;  base: Struct; VAR res: LONGINT);
	BEGIN
		res := Ok;
		ASSERT(base # NIL, 500);
		ASSERT(ptr.base = NIL, 501);
		ptr.base := base;
		IF (base IS Record) THEN
			WITH base: Record DO
				ptr.baseR := base;
				IF (base.ptr = NIL) & (base.owner = NIL) & (base.scope = NIL) THEN	(*rec not initialized yet!*)
					base.ptr := ptr;
					(*PCM.LogWLn; PCM.LogWStr("PCT.InitPointer: setting record.ptr");*)
				END
			END
		ELSIF base IS Array THEN
			ptr.baseA := base(Array);
		ELSE
			res := IllegalPointerBase;
			ptr.base := UndefType;
		END;

(*
		ELSIF ~((base = UndefType) OR  (base IS Array)) THEN
			res := IllegalPointerBase;
			ptr.base := UndefType
		ELSE
			ptr.baseA := base(Array)
		END;
*)
	END InitPointer;

	PROCEDURE InitDelegate*(p: Delegate; return: Struct;  scope: ProcScope; flags: SET; VAR res: LONGINT);
	BEGIN
		ASSERT(return # NIL, 500);
		ASSERT(scope # NIL, 501);
		ASSERT(scope.ownerS = NIL, 502);
		ASSERT(scope.ownerO = NIL, 503);
		ASSERT(flags - {StaticMethodsOnly, RealtimeProcType (* ug *), WinAPIParam, CParam(* fof for Linux *)} = {}, 504); (* ejz *)
		p.return := return; p.scope := scope; scope.ownerS := p;
		p.flags := flags;
		IF ~IsLegalReturnType(return) THEN
			res := 603(*NotImplemented*); p.return := NoType
		END;
		ASSERT(p.scope # NIL, 504);
		CommitParList(scope, 0)
	END InitDelegate;

	(** ------------ Symbol Creation ------------------- *)

	PROCEDURE InitSymbol*(o: Symbol; name: StringIndex;  vis: SET;  type: Struct);
	BEGIN ASSERT(o # NIL); o.name := name; o.type := type; o.vis := vis
	END InitSymbol;

	PROCEDURE InitType*(t: Type; name: StringIndex;  vis: SET;  type: Struct);	(** for PCOM object comparison - don't insert in scope *)
	BEGIN
		InitSymbol(t, name, vis, type);
		IF type.owner = NIL THEN type.owner := t END;
	END InitType;

	PROCEDURE NewValue*(name: StringIndex;  vis: SET;  c: Const): Value;	(** for PCOM object comparison - don't insert in scope *)
	VAR v: Value;
	BEGIN
		NEW(v); InitSymbol(v, name, vis, c.type); v.const := c;
		IF c.owner = NIL THEN  c.owner := v  END;
		RETURN v
	END NewValue;

	PROCEDURE CheckVar(v: Variable; allowedArray: SET; allowedEnhArray: SET;   (* fof *) VAR res: LONGINT);
	BEGIN
		IF (v.type IS Array) & ~(v.type(Array).mode IN allowedArray) THEN
			res := IllegalType; v.type := UndefType
(*
		ELSIF (v.vis - Internal # {}) & ((v.type = Char16) OR (v.type = Char32)) THEN
			res := 200; v.vis := Internal
*)
		(** fof >> *)
		ELSIF (v.type IS EnhArray) &   ~(v.type( EnhArray ).mode IN allowedEnhArray) THEN
			res := IllegalType;  v.type := UndefType
		(** << fof  *)
		END;
	END CheckVar;

	PROCEDURE NewGlobalVar*(vis: SET;  name: LONGINT;  flags: SET;  type: Struct; VAR res: LONGINT): GlobalVar;	(** for PCOM object comparison - don't insert in scope *)
	VAR  v: GlobalVar;
	BEGIN
		res := Ok;
		NEW(v); InitSymbol(v, name, vis, type); v.flags := flags; CheckVar(v, {static}, {static} (* fof *) ,res); RETURN v
	END NewGlobalVar;

	PROCEDURE InitProc(p: Proc; vis: SET;  name: StringIndex;  scope: ProcScope;  return: Struct; VAR res: LONGINT);
	VAR o: Proc;
	BEGIN
		ASSERT(return # NIL, 500);
		ASSERT(scope # NIL, 501);
		ASSERT(scope.ownerS = NIL, 502);
		ASSERT(scope.ownerO = NIL, 503);
		InitSymbol(p, name, vis, return); p.scope := scope; scope.ownerO := p;
		IF ~IsLegalReturnType(return) THEN
			res := 604(*NotImplemented*); p.type := NoType
		(** fof >> *)
		ELSIF ~IsBasic(return) THEN
			p.scope.CreateReturnPar(return,res);
		END;
	(** << fof  *)
		p.level := 0;
		IF (scope.parent IS ProcScope) THEN
			o := scope.parent(ProcScope).ownerO;
			p.level := o.level+1
		END;
		CommitParList(scope, p.level);
		IF scope.imported THEN PreAllocate(NIL, scope) ELSE PreAllocate(scope.module.scope, scope) END
	END InitProc;

	PROCEDURE NewProc*(vis: SET;  name: StringIndex;  flags: SET;  scope: ProcScope;  return: Struct; VAR res: LONGINT): Proc;	(** for PCOM object comparison - don't insert in scope *)
	VAR p: Proc; i: LONGINT;
	BEGIN
		res := Ok;
		NEW(p); InitProc(p, vis, name, scope, return, res);

		IF flags - {Inline, Operator, RealtimeProc} # {} THEN
			res := 605(*NotImplemented*)
		END;
		IF RealtimeProc IN flags THEN INCL(p.scope.flags, RealtimeScope) END; (* ug: realtime property of procedure is copied to scope *)
		p.flags := flags;
		RETURN p
	END NewProc;

	PROCEDURE FindOverwrittenMethod(owner: Record; name: StringPool.Index; mscope: ProcScope; VAR res: LONGINT): Method;
		VAR pars: ARRAY 32 OF Struct; i, parCount: LONGINT; obj: Symbol; super: Method; par: Parameter;
	BEGIN
		IF owner.brec # NIL THEN
			IF Overloading IN owner.brec.scope.module.scope.flags THEN
				ASSERT(mscope.lastPar.name = SelfName);
				parCount := mscope.parCount-1;
				i := 0; par := mscope.firstPar;
				WHILE i < parCount DO pars[i] := par.type; INC(i); par := par.nextPar END;
				ASSERT(par = mscope.lastPar);
				obj := FindProcedure(owner.scope, owner.brec.scope, name, parCount, pars, TRUE, FALSE);
			ELSE
				obj := Find(owner.scope, owner.brec.scope, name, procdeclared, FALSE)
			END;
			IF obj # NIL THEN
				IF obj IS Method THEN  super := obj(Method)  ELSE  res := DuplicateSymbol  END
			END
		END;
		RETURN super
	END FindOverwrittenMethod;

	PROCEDURE NewMethod(vis: SET;  name: StringIndex;  flags: SET;  scope: ProcScope;  return: Struct;  boundTo: Record; pos: LONGINT; VAR res: LONGINT): Method;
	VAR p: Method;  faulty: Symbol; initializer: BOOLEAN;
	BEGIN
		res := Ok;
		ASSERT(boundTo # NIL, 500);
		initializer := FALSE;
		IF Constructor IN flags THEN
			initializer := TRUE; EXCL(flags, Constructor); vis := Public
		END;
		NEW(p);
		IF Indexer IN flags THEN
			IF flags -{copy, NonVirtual, Operator, Indexer, Inline} # {} THEN res := 606(*NotImplemented*) END;
		ELSE
			IF flags -{copy, NonVirtual, RealtimeProc} # {} THEN res := 606(*NotImplemented*) END;
		END;

		p.boundTo := boundTo;

		IF (SuperclassAvailable IN boundTo.scope.flags) & ~(NonVirtual IN flags) THEN
			p.super := FindOverwrittenMethod(boundTo, name, scope, res);
			IF (p.super # NIL) & (RealtimeProc IN p.super.flags) THEN	(* realtime property of superclass method is inherited *)
				INCL(flags, RealtimeProc)
			END;
			IF (p.super # NIL) THEN (* export if supermethod has been exported *)
				IF (p.super.vis * Public # {}) & (vis*Public = {}) THEN
					vis := vis + p.super.vis;
					(*
					PCM.Warning(Diagnostics.Invalid,pos,"auto-export of overwritten exported method");
					*)
				END;
			END;
		END;
		IF AutodeclareSelf IN scope.flags THEN
			IF (boundTo.ptr # NIL) & ((p.super = NIL) OR ~p.super.self.ref) THEN
				IF name = 0 THEN
					PCM.LogWLn; PCM.LogWStr("PtrSelf "); PCM.LogWStr0(name); PCM.LogWNum(name);
					HALT(MAX(INTEGER))
				END;
				scope.CreatePar(Internal, FALSE, SelfName, {}, boundTo.ptr, 0,(* fof *)  res)
			ELSE
				PCM.LogWLn; PCM.LogWStr("RecSelf "); PCM.LogWStr0(name); PCM.LogWNum(name);
				HALT(MAX(INTEGER));
				scope.CreatePar(Internal, TRUE, SelfName, {}, boundTo, 0,(* fof *)  res)
			END
		END;
		p.self := scope.last(Parameter);
		ASSERT(p.self.name = SelfName);

		InitProc(p, vis, name, scope, return, res);	(*InitProc creates the param-list, thus self must be already allocated*)
		IF RealtimeProc IN flags THEN INCL(p.scope.flags, RealtimeScope) END; (* ug: realtime property of method is copied to scope *)
		p.flags := flags;

		IF p.super # NIL THEN
			p.Use;
			IF (Indexer IN flags) & (Inline IN p.super.flags) THEN
				res := 992
			ELSIF ~ParameterMatch(scope.firstPar, p.super.scope.firstPar, faulty) THEN
				res := ParameterMismatch
			ELSIF ~EqualTypes(return, p.super.type) THEN
				res := ReturnMismatch
			END
		END;

		IF p.name = BodyName THEN
			IF (boundTo.scope.body = NIL) & ((boundTo.ptr # NIL) OR ~(SuperclassAvailable IN boundTo.scope.flags)) THEN
				boundTo.scope.body := p
			ELSE
				res := ObjectOnly
			END
		ELSIF initializer THEN
			IF boundTo.scope.initproc # NIL THEN
				res := MultipleInitializers
			ELSIF (boundTo.ptr = NIL) & (SuperclassAvailable IN boundTo.scope.flags) THEN
				res := InitializerOutsideObject
			ELSE
				boundTo.scope.initproc := p
			END
		END;
		RETURN p
	END NewMethod;

	PROCEDURE NewModule*(name: StringIndex;  imported: BOOLEAN;  flags: SET;  scope: ModScope): Module;
	VAR  m: Module;
	BEGIN
		ASSERT(scope # NIL, 500);
		ASSERT(flags - {used} = {}, 501);
		NEW(m);
		m.name :=  name;
		m.scope := scope; m.imported := imported; scope.module := m;
		m.vis := Internal;
		IF scope.owner = NIL THEN
			scope.owner := m;
			IF imported THEN  PreAllocate(NIL, scope)  ELSE  PreAllocate(scope, scope)  END
		ELSE
			m.adr := scope.owner.adr;	(*avoid replication of adr!*)
			m.sym := scope.owner.sym
		END;
		m.flags := flags;
		RETURN m
	END NewModule;

	(** ---------------- Special Functions --------------------- *)

	PROCEDURE SetMode*(scope: Scope;  mode: LONGINT; VAR res: LONGINT);
	BEGIN
		res := Ok;
		IF mode = exclusive THEN
			WHILE scope IS ProcScope DO  scope := scope.parent  END;
			IF scope IS RecScope THEN
				INCL(scope(RecScope).owner.mode, mode)
			END
		ELSIF (mode IN {safe, active}) & (scope IS ProcScope) THEN
			WITH scope: ProcScope DO
				IF scope.ownerO.name = BodyName THEN
					INCL(scope.ownerO(Method).boundTo.mode, mode)
				ELSE
					res := 607(*NotImplemented*)
				END
			END
		ELSE
			res := 608(*NotImplemented*)
		END
	END SetMode;

	PROCEDURE SetProcFlag*(scope: Scope; flag: LONGINT; VAR res: LONGINT);
	BEGIN
		IF (flag = RealtimeProc) & (scope IS ProcScope) THEN
			WITH scope: ProcScope DO
				IF scope.ownerO.name = BodyName THEN
					INCL(scope.ownerO.flags, flag);
					INCL(scope.flags, RealtimeScope) (* Realtime property is propagated to scope *)
				ELSE
					res := 607 (* NotImplemented *)
				END
			END
		ELSE
			res := 608 (* NotImplemented *)
		END
	END SetProcFlag;

	PROCEDURE IsRealtimeScope*(scope: Scope): BOOLEAN;
	BEGIN
		RETURN RealtimeScope IN scope.flags
	END IsRealtimeScope;

	PROCEDURE RecordSizeUsed*(rec: Record);
	BEGIN rec.pbused := TRUE;
		IF rec.owner # NIL THEN
			rec.owner.Use
		ELSIF (rec.ptr # NIL) & (rec.ptr.owner # NIL) THEN
			rec.ptr.owner.Use
		END
	END RecordSizeUsed;

(** fof 070731 >> *)
	PROCEDURE Written*(s: Symbol);
	BEGIN
		s.Write();
	END Written;

	PROCEDURE RemoveWarning*(s: Symbol);
	BEGIN
		s.pos := 0;
	END RemoveWarning;

(** << fof  *)

	PROCEDURE GetTypeName*(type: Struct;  VAR name: ARRAY OF CHAR);
	BEGIN
		name[0] := 0X;
		IF type.owner # NIL THEN
			StringPool.GetString(type.owner.name, name)
		ELSIF (type IS Record) THEN
			WITH type: Record DO
				IF type.ptr # NIL THEN GetTypeName(type.ptr, name) END
			END
		END;
	END GetTypeName;

	(** GetScopeName - return the name of the scope owner *)

	PROCEDURE GetScopeName*(scope: Scope;  VAR name: ARRAY OF CHAR);
	BEGIN
		IF scope IS ProcScope THEN
			StringPool.GetString(scope(ProcScope).ownerO.name, name)
		ELSIF scope IS RecScope THEN
			GetTypeName(scope(RecScope).owner, name)
		ELSIF scope IS ModScope THEN
			StringPool.GetString(scope(ModScope).owner.name, name)
		ELSE
			HALT(99)
		END
	END GetScopeName;

	(** ---------------- Module Database ------------------- *)

	(* Register - add a module to the database *)

	PROCEDURE Register*(root: ModuleDB; m: Module);
		VAR  p, q: Module;
	BEGIN
		q := root; p := root.next;
		WHILE (p # NIL) & (StringPool.CompareString(p.name, m.name) < 0) DO  q := p; p := p.next  END;
		IF (p = NIL) OR (p.name # m.name) THEN
			m.next := p;
			q.next := m
		ELSE
			HALT(99)	(*duplicate entry*)
		END
	END Register;

	(* Unregister - remove a module from the database *)

	PROCEDURE Unregister*(root: ModuleDB; name: StringPool.Index);
		VAR p: Module;
	BEGIN {EXCLUSIVE}
		p := root;
		WHILE (p.next # NIL) & (p.next.name # name) DO  p := p.next  END;
		IF p.next # NIL THEN
			p.next := p.next.next
		END
	END Unregister;

	(* Retrieve - find a module in the database *)

	PROCEDURE Retrieve*(root: ModuleDB; name: StringPool.Index): Module;
		VAR p: Module;
	BEGIN
		p := root.next;
		WHILE (p # NIL) & (StringPool.CompareString(p.name, name) < 0) DO  p := p.next  END;
		IF (p = NIL) OR (p.name # name) THEN
			RETURN NIL
		ELSE
			RETURN p
		END
	END Retrieve;

	(* Enumerate - Traverse database *)

	PROCEDURE Enumerate*(root: ModuleDB; EnumProc: PROCEDURE {DELEGATE} (m: Module));
		VAR p: Module;
	BEGIN
		p := root.next;
		WHILE (p # NIL) DO  EnumProc(p); p := p.next  END
	END Enumerate;

	PROCEDURE InitDB*(VAR root: ModuleDB);
	BEGIN NEW(root)
	END InitDB;

	(** ---------------- Plug-in Management ------------------- *)

	PROCEDURE AddImporter*(p: ImporterPlugin);
		VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO nofImportPlugins-1 DO ASSERT(import[i] # p) END;
		import[nofImportPlugins] := p;
		INC(nofImportPlugins)
	END AddImporter;

	PROCEDURE RemoveImporter*(p: ImporterPlugin);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < nofImportPlugins) & (import[i] # p) DO INC(i) END;
		ASSERT(i < nofImportPlugins);
		DEC(nofImportPlugins);
		IF i # nofImportPlugins THEN import[i] := import[nofImportPlugins] END;
		import[nofImportPlugins] := NIL
	END RemoveImporter;

	(* ---------------- Module Initialisation ------------------- *)

	PROCEDURE DummyAllocate(context, scope: Scope; hiddenVarsOnly: BOOLEAN (* ug *));
	END DummyAllocate;

	(* ug *)
	PROCEDURE DummyPrePostAllocate(context, scope: Scope);
	END DummyPrePostAllocate;

	PROCEDURE NewBasic(m: Module; CONST name: ARRAY OF CHAR): Basic;
	VAR b: Basic; res: LONGINT;
	BEGIN
		NEW(b);
		m.scope.CreateType(StringPool.GetIndex1(name), Public, b, 0 (* fof *), res); ASSERT(res = Ok);
		RETURN b
	END NewBasic;

	PROCEDURE Init;
	VAR  scope: ModScope; idx: StringIndex; res: LONGINT;
	BEGIN
		InitDB(database);
		BodyName := StringPool.GetIndex1(BodyNameStr);
		SelfName := StringPool.GetIndex1(SelfNameStr);
		Anonymous := StringPool.GetIndex1(AnonymousStr);
		PtrReturnType := StringPool.GetIndex1(PtrReturnTypeStr); (* ug *)

		NEW(scope); InitScope(scope, NIL, {}, TRUE); scope.ownerID := 0; (*fof: global scope modified by PCB.Body => not guaranteed to be the same process ! *)
		idx := StringPool.GetIndex1("Universe");
		Universe := NewModule(idx, TRUE, {}, scope);
		NEW(scope); InitScope(scope, NIL, {}, TRUE); scope.ownerID := 0;  (*fof:  global scope modified by PCB.Body => not guaranteed to be the same process ! *)
		idx := StringPool.GetIndex1("SYSTEM");
		System := NewModule(idx, TRUE, {}, scope);
		(* don't commit scopes, leave this to PCB who will insert data *)

		Byte := NewBasic(System, "BYTE");
		Bool := NewBasic(Universe, "BOOLEAN");
		CharType[0] := NewBasic(Universe, "CHAR"); Char8 := CharType[0];
		IF PCM.LocalUnicodeSupport THEN
			Universe.scope.CreateType(StringPool.GetIndex1("CHAR8"), Public, Char8, 0(*fof*), res); ASSERT(res = Ok);
			CharType[1] := NewBasic(Universe, "CHAR16"); Char16 := CharType[1];
			CharType[2] := NewBasic(Universe, "CHAR32"); Char32 := CharType[2]
		END;
		NumericType[0] := NewBasic(Universe, "SHORTINT"); Int8 := NumericType[0];
		NumericType[1] := NewBasic(Universe, "INTEGER"); Int16 := NumericType[1];
		NumericType[2] := NewBasic(Universe, "LONGINT"); Int32 := NumericType[2];
		NumericType[3] := NewBasic(Universe, "HUGEINT"); Int64 := NumericType[3];
		NumericType[4] := NewBasic(Universe, "REAL"); Float32 := NumericType[4];
		NumericType[5]:= NewBasic(Universe, "LONGREAL"); Float64 := NumericType[5];
		Set := NewBasic(Universe, "SET");
		Ptr := NewBasic(Universe, "ANY");
		NEW(String);
		NEW(NilType);
		NEW(NoType);
		NEW(UndefType);
		True := NewBoolConst(TRUE);
		False := NewBoolConst(FALSE);

		(* actual size will be patched later *)
		System.scope.CreateType (StringPool.GetIndex1("ADDRESS"), Public, Int32, 0, res); ASSERT(res = Ok);
		SystemAddress := System.scope.lastType;

		(* actual size will be patched later *)
		System.scope.CreateType (StringPool.GetIndex1("SIZE"), Public, Int32, 0, res); ASSERT(res = Ok);
		SystemSize := System.scope.lastType;

	END Init;

BEGIN
	PreAllocate := DummyPrePostAllocate; (* ug *) Allocate := DummyAllocate; PostAllocate := DummyPrePostAllocate; (* ug *)
	Init
END PCT.

(**
	Notes:

	ImportPlugins:
		1. must call self.AddImport(new); done in the loader to break possible recursive import cycles

		the import procedure first look into the list of already imported modules (self.imports), otherwise
		calls the loaders.
*)

(*
	Symbol Table.

	scope states:
	            description                    searching from child
	none
	checking	all declarations parsed        allowed, to parent if declaration
	declared	declarations allocated
	            variables allocated, locally declared types sized

	complete	procedure parsed + allocated


	Scoping, object visibility rules and invariants

	Oberon: a symbol must be declared before its use. The symbol in the nearest scope
	is used. Exceptions: pointer to.

	Active Oberon: The symbol in the nearest scope is used.

	This compiler: The symbol in the nearest scope is used. Exception: local scope, a
	symbol must be declared before its use or in a parent scope. Exception: pointers.
	Also declaration sequence as in Oberon: first const/type/var, then procs

	Implications:
		* no fixups needed (but for pointers)
		* record structures cannot be recursive.
		* check on declaration
		* allows early continuation in parsing

	Known problems:
		* during declaration parsing, search upper scope only for declarations, not
			procedures (declarations cannot reference a procedure). Delay check for
			shadowing.
		* during procedure parsing, search upper scope for every symbol
		* mutual reference: record inside a procedure needs a symbol in parent scope:
			procedure cannot allocate its own data as long as record (fields) are not
			completly parsed, but this can only happen when procedure declarations are
			allocated. Workaround: state "declared" and "allocated". "declared" allows
			search of symbols.
		* Allocation / TypeSize:
			records can be linked before they are allocated.

	HowTo:
		Find has a "required state" tag.

		POINTER TO -> local
		in declaration in a Record -> declared
		in declaration otherwise -> allocated
		in implementation -> complete

	Allocation/Procedure:
		call -> adr: on procedure allocation
		vars/params: on scope declarations, only by self+children (parsed only after allocated)

	Module:
		const/type: on module allocation
		vars/: on scope declaration

	Record:
		struct/td: on allocation
		fields: on complete (restrict access!) -> by record parser self
		methods: on complete -> by record parser self


Database:

1 Register, duplicate entries

Special errors:
	601	InitRecord	interface base is a record
	602	InitRecord	interface is no interface
	603	InitDelegate	illegal return type
	604	InitProc	illegal return type
	605	NewProc	unknown flags
	606	NewMethod	unknown flags
	607	SetMode	only body can be safe or active
	608	SetMode	unknown flag
*)


(*
	03.08.03	prk	remove trace trap thrown when base type of record or object did not exists
	28.12.02	prk	NonVirtual flag added
	02.04.02	prk	CreateVar/Proc: if insert fails, don't add the the mod scope's non-sorted lists
	18.03.02	prk	CreateVar/Proc/Par: if insert fails, don't add the the scope's non-sorted lists
	22.02.02	prk	unicode support
	05.02.02	prk	PCT.Find cleanup
	31.01.02	prk	Find: procedure local objects must not see the local variables of the procedure
	22.11.01	prk	improved flag handling
	19.11.01	prk	definitions
	17.11.01	prk	more flexible type handling of integer constants
	16.11.01	prk	constant folding of reals done with maximal precision
	15.11.01	prk	ptr field added to Const, NewPtrConst
	13.11.01	prk	lookup with signature improved
	22.10.01	prk	Insert, invariant check simplified
	20.10.01	prk	ParameterMatch, fail if number of parameters differ
	05.09.01	prk	CanSkipAllocation flag for record scopes
	29.08.01	prk	PCT functions: return "res" instead of taking "pos"
	27.08.01	prk	PCT.Insert removed, use Create procedures instead
	27.08.01	prk	scope.unsorted list removed; use var, proc, const and type lists instead
	17.08.01	prk	overloading
	09.08.01	prk	Symbol Table Loader Plugin
	11.07.01	prk	support for fields and methods with same name in scope
	06.07.01	prk	mark object explicitly
	05.07.01	prk	import interface redesigned
	04.07.01	prk	scope flags added, remove imported
	02.07.01	prk	access flags, new design
	28.06.01	prk	add var and proc counters to scope
	27.06.01	prk	StringPool cleaned up
	27.06.01	prk	ProcScope.CreatePar added
	21.06.01	prk	using stringpool index instead of array of char
	19.06.01	prk	module database
	15.06.01	prk	support for duplicate scope entries
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	13.06.01	prk	ProcScope, parameter list added to avoid parameter testing
	12.06.01	prk	Interfaces
	06.06.01	prk	use string pool for object names
	17.05.01	prk	Delegates
	08.05.01	prk	PCT interface cleanup. Use InitX instead of New*, allows type extension
	26.04.01	prk	separation of RECORD and OBJECT in the parser
	26.04.01	prk	RecordUse, mark type as used too (a type can be allocated even if never referenced directly)
	20.04.01	prk	don't accept static arrays with negative length
	02.04.01	prk	interface cleanup
	29.03.01	prk	Java imports
	22.02.01	prk	self reference for methods: use pointer-based self if possible (i.e. if object is dynamic and method
								definitions in super-class is not record-based).
	22.02.01	prk	delegates
*)