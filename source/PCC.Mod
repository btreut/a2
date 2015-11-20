(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCC; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: intermediate code generation"; *)

IMPORT
	SYSTEM, PCDebug, PCM, PCBT, PCLIR, PCS, PCT;

CONST
	Trace = FALSE;
	Statistics = FALSE;

	(** operators *)
	setfn* = 200;		(** MOp / DOp: convert to set *)
	absfn* = 201;		(** MOp: absolute value *)
	capfn* = 202;		(** MOp: CAP(x) *)
	oddfn* = 203;		(** MOp: ODD(x) *)

	ashfn* = 204;		(** DOp: ASH *)
	lshfn* = 205;		(** DOp: LSH *)
	rotfn* = 206;		(** DOp: ROT *)

	bitfn* = 207;		(** RelOp: BIT *)

		(*special values*)
	True = 1; False = 0;	(*1-byte constants*)
	Nil = 0;

TYPE
(* ===================================================
    mode   description    adr    level   offs    value   breg  comments
-----------------------------------------------------------------------
    Abs    Absolute Var   -      -       off[sb] len (strings only)

    Var    Local Var      -      nofSL   off[fp]
	       Value Par

    Ref    Ref Par (ind)  -      nofSL   off[fp]

    Const  Constant       -      -       -       value

    Reg    Register       regNo  -       -
                          regNo (procAddr)               self   type = procedure
                          lowVal                         HiVal  type = HUGEINT

    RegRel Reg Relative   regNo  -       offset

    CC     Condition Code cc     tlist/flist	 R1      R2      cc is the type of the last jump

    Proc   Procedure Call

    Case   Case Desc      caseAdr tlist=else


Condition Codes:
	tlist, flist: jmp chains for the true / false threads of control

	cc = none => no comparison has to be done, only the chains are set

Procedure/Delegates handling:
	Procedure:
	mode=proc, type=Ptr

	Delegate:
	mode=Abs/Ref/Var, type=Proc
	mode=Reg, adr=reg with ProcAddr, breg=reg with SelfAddr, type=Proc

    Method() creates a delegate with type=MethodType and

*)
	Item* = RECORD
		mode, level: SHORTINT;
		deref: BOOLEAN;	(* has been dereferenced. For getting the actual type descriptor *)
		adr, offs, value: LONGINT;
		breg, boffs: LONGINT;	(* pointer to the array bound. Valid only if mode = {RegRel} *)
												(* pointer to self. Valid only if method and self is pointer *)
		tlist, flist: LONGINT;	(* jump list, for CC only *)
		proc: PCBT.Procedure;
		var: PCBT.GlobalVariable;
		type-: PCT.Struct;	(** for testing only! *)
	END;

	Label* = LONGINT;

CONST
	(* Item Modes ProgTools.Enum 1 Abs Var Ref Const Reg RegRel CC Proc~ *)
	Abs = 1; Var = 2; Ref = 3; Const = 4; Reg = 5; RegRel = 6;
	CC = 7; Proc = 8; Case = 9;

		(* Condition codes ProgTools.Enum 1 ccNone ccAlways ccNever ccEQ ccNE ccGT ccGE ccLT ccLE ccB ccBE ccA ccAE ccF ccNF ~ *)
	ccNone = 0; ccAlways = 1; ccNever = 2; ccEQ = 3; ccNE = 4; ccGT = 5; ccGE = 6;
	ccLT = 7; ccLE = 8; ccB = 9; ccBE = 10; ccA = 11; ccAE = 12;
	ccF = 13; ccNF = 14;

		(*Useful constants*)
	none* = PCLIR.none;

		(*Type Descriptor Constants in addresses *)
	BaseTypesTable = -2;	(*table with all record extensions*)
	MethodTable = -18;
	IntfMethodTable = 1;
	ArrayFirstElem = 2;	(* first array element *)
	ArrayDimTable = 3;	(* dimension table in dyn arrays *)

	(** fof >> *)
	(* as things have to be pushed to stack anyway it might be wise to differenciate the two cases EnhArray and Tensor i/o making them consistent *)

	TensorFlag* = 0;   (* flag indicating a tensor array *)
	RangeFlag* = 1;   (* flag indicating a range, e.g. an array derived from A[..,..] *)
	StackFlag* = 2;   (* flag indicates temporary result *)

	Descr_PtrOffs* = 0;   (* ptr offset (mainly for GC) *)
	Descr_AdrOffs* = 1;   (* address offset *)
	Descr_FlagsOffs* = 2;   (* flags offset, flag0: size-mutable, for RETURN parameters and built-in functions *)
	Descr_DimOffs* = 3;   (* dimension offset *)
	Descr_SizeOffs* = 4 ;
	Descr_LenOffs* = 5;   (* length offset *)
	Descr_IncOffs* = 6;   (* inc offset *)

	SysDataArrayOffset* = 8;   (* array offset in system block, for 32 byte alignment *)
	ArrDataArrayOffset*= 16; (* array offset in array block, to be compatible with the GC scheme of POINTER TO ARRAY OF ... *)
	(** << fof  *)

	(* flags used for optimizations of operations on small matricies and vectors (Alexey Morozov) *)
	SmallMatrixFlag* = 3; (* flag for identification of a small matrix *)
	SmallVectorFlag* = 3; (* flag for identification of a small vector *)

TYPE
	Code* = PCLIR.Code;

VAR
	(** system types, allocated only when used, set by PCP*)
	delegate*, hdptr*: PCT.Record;
	anyarr*: ARRAY 32 OF PCT.Record;  range*: PCT.Record; (* fof *)
	topscope*: PCT.ModScope;

	CCTab, InvCCTab, SetCCTab: ARRAY 15 OF PCLIR.Opcode;
	InvCC: ARRAY 15 OF SHORTINT;

	MethodType: PCT.Delegate;

	AParArray, AParBasic, AParProc, AParRec: LONGINT;	(* Parameter Kind Count *)
	AAssBasic, AAssRec, AAssArray, AAssProc: LONGINT;	(* Assignment Kind Count *)
	ARetBasic, ARetRec, ARetStaticArray, ARetOpenArray, ARetElse: LONGINT;

(* ---------- Helper Procedures -------------- *)

(*
PROCEDURE DumpItem(VAR x: Item);
BEGIN
	CASE x.mode OF
	|  Var:
			PCM.LogWStr("Var ["); PCM.LogWStr(x.type.owner.name); PCM.LogWStr("] ");
			PCM.LogWNum(x.offs); PCM.LogWStr("[FP]");
	| Ref:
			PCM.LogWStr("Ref ["); PCM.LogWStr(x.type.owner.name); PCM.LogWStr("] ");
			PCM.LogWNum(x.offs); PCM.LogWStr("[FP]");
	| Const:
			PCM.LogWStr("Const [");
			IF x.type = PCT.NilType THEN  PCM.LogWStr("NIL")  ELSE  PCM.LogWStr(x.type.owner.name)  END;
			PCM.LogWStr("] ");  PCM.LogWNum(x.adr)
	| Reg:
			PCM.LogWStr("Reg ["); PCM.LogWStr(x.type.owner.name); PCM.LogWStr("]  Reg");
			PCM.LogWNum(x.adr)
	ELSE
			PCM.LogWStr("unknown mode "); PCM.LogWNum(x.mode)
	END;
	PCM.LogWLn;
END DumpItem;
*)

PROCEDURE IsString(t: PCT.Struct): BOOLEAN;
BEGIN  RETURN (t = PCT.String) OR (t IS PCT.Array) & (t(PCT.Array).base = PCT.Char8)
END IsString;

(*-----------Register Operation----------------*)

(* GetActivationFrame - return a pointer to the procedure activation frame *)

PROCEDURE GetActivationFrame(code: Code;  level: SHORTINT;  VAR reg: LONGINT);
BEGIN
	ASSERT(level >= 0);
	reg := PCLIR.FP;
	WHILE level > 0 DO
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, PCT.AddressSize*2, reg);
		DEC(level)
	END;
END GetActivationFrame;

PROCEDURE Load*(code: Code;  VAR x: Item);
VAR	tmpReg, frame: LONGINT;  y: Item;  tmpType: PCT.Struct;  size: PCBT.Size; name: ARRAY 32 OF CHAR;
BEGIN
	ASSERT( ~(x.type IS PCT.Record), 210);
	ASSERT(~(x.type IS PCT.Array), 212);
	(** fof >> *)
	ASSERT ( ~(x.type IS PCT.EnhArray), 213 );
	(* x.type IS PCT.Tensor allowed: load pointer = deref array *)
	(** << fof  *)
	PCT.GetTypeName(x.type, name);
	size := x.type.size(PCBT.Size);
	IF x.mode = Proc THEN
		PCLIR.EmitLoadAddr(code, x.adr, 0, x.proc);
		PCLIR.EmitLoadConst(code, x.breg, PCLIR.Address, FALSE, 0)
			(* if assigned to a delegate, the self ref is NIL *)
	ELSIF size.type = PCLIR.NoSize THEN
		PCM.LogWLn;
		PCT.GetTypeName(x.type, name); PCM.LogWStr(name);
		PCM.LogWNum(GetStaticSize(x.type));  HALT(99);
	ELSIF x.mode = Reg THEN
		(*already ok*)
	ELSIF (x.type IS PCT.Delegate) & ~(PCT.StaticMethodsOnly IN x.type.flags) THEN
		IF (x.mode = RegRel) OR (x.mode = Abs) OR ((x.mode = Var) & (x.level = 0)) THEN
			tmpType := x.type;
			x.type := PCT.Ptr; y := x;
			Load(code, x);
			INC(y.offs, PCT.AddressSize); Load(code, y); x.breg := y.adr;
			x.type := tmpType
		ELSE
			size := PCT.Ptr.size(PCBT.Size);
			LoadAdr(code, x);
			tmpReg := x.adr;
			PCLIR.EmitLoadRelative(code, size.type, size.signed, x.adr, 0, tmpReg);	(*procAddr*)
			PCLIR.EmitLoadRelative(code, size.type, size.signed, x.breg, PCT.AddressSize, tmpReg);	(*self*)
		END
	ELSIF x.mode = Var THEN
		GetActivationFrame(code, x.level, frame);
		PCLIR.EmitLoadRelative(code, size.type, size.signed, x.adr, x.offs, frame);
	ELSIF x.mode = Ref THEN
		GetActivationFrame(code, x.level, frame);
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, tmpReg, x.offs, frame);
		PCLIR.EmitLoadRelative(code, size.type, size.signed, x.adr, 0, tmpReg);
	ELSIF x.mode = Const THEN
		PCLIR.EmitLoadConst(code, x.adr, size.type, size.signed, x.value);
		IF x.type = PCT.NilType THEN PCLIR.EmitLoadConst(code, x.breg, PCLIR.Address, FALSE, 0) END; (* for delegates *)
	ELSIF x.mode = RegRel THEN
		PCLIR.EmitLoadRelative(code, size.type, size.signed, x.adr, x.offs, x.adr);
	ELSIF x.mode = Abs THEN
		PCLIR.EmitLoadAbsolute(code, size.type, size.signed, x.adr, x.offs, x.var)
	ELSIF x.mode = CC THEN
		LoadCC(code, x)
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented);
	END;
	x.mode := Reg;
	ASSERT(x.mode = Reg, 220);	(*postcondition*)
END Load;

PROCEDURE LoadAdr(code: Code; VAR x: Item);
VAR openarr: BOOLEAN;  temp, frame: LONGINT;
BEGIN
	openarr := (x.type IS PCT.Array) & (x.type(PCT.Array).mode # PCT.static) ;
	IF x.mode = Proc THEN
		PCLIR.EmitLoadAddr(code, x.adr, 0, x.proc)
	ELSIF x.mode = Reg THEN
		PCM.LogWLn; PCM.LogWStr("PCC.LoadAdr, warning: already reg")
	ELSIF (x.mode = Ref) OR (openarr & (x.mode = Var)) THEN
		GetActivationFrame(code, x.level, frame);
		IF openarr THEN
			x.breg := frame;
			x.boffs := x.offs + x.type(PCT.Array).opendim * PCLIR.CG.ParamAlign;	(* offset of dim0 *)
		END;
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, x.adr, x.offs, frame);
	ELSIF x.mode = Var THEN
		GetActivationFrame(code, x.level, frame);
		PCLIR.EmitLoadConst(code, temp, PCLIR.Address, FALSE, x.offs);
		PCLIR.Emit12(code, PCLIR.add, x.adr, frame, temp)
	ELSIF x.mode = RegRel THEN
		IF (x.offs # 0) OR (x.adr < 0) THEN
			PCLIR.EmitLoadConst(code, temp, PCLIR.Address, FALSE, x.offs);
			PCLIR.Emit12(code, PCLIR.add, x.adr, x.adr, temp);
		END
	ELSIF x.mode = Abs THEN
		PCLIR.EmitLoadAddr(code, x.adr, x.offs, x.var)
	ELSIF x.type = PCT.NilType THEN (* ejz *)
		PCLIR.EmitLoadConst(code, x.adr, PCLIR.Address, FALSE, 0)
	(** fof >> *)
	ELSIF (x.mode = Const) & (x.type IS PCT.EnhArray) THEN  (* in constant section *)
		PCLIR.EmitLoadAddr( code, x.adr, x.offs, x.var );
	(** << fof  *)
	ELSE
		HALT(MAX(INTEGER));
		PCM.LogWLn; PCM.LogWStr("LoadAdr, unimplemented mode: "); PCM.LogWNum(x.mode);
		PCDebug.ToDo(PCDebug.NotImplemented);
	END;
	x.mode := Reg;
END LoadAdr;

(** fof >> *)
	PROCEDURE LoadArrayAdr*( code: Code;  VAR descr, array: Item );
	BEGIN
		array := descr;  array.adr := 0;
		IF descr.mode # Reg THEN LoadAdr( code, descr );  END;
		descr.offs := 0;   (*? needed ?? *)
		(*
		IF array.mode = Var THEN  (* tiny optimization for more economical register usage *)
			GetActivationFrame( code, array.level, frame );
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , array.adr,
													 array.offs + Descr_AdrOffs*PCT.AddressSize, frame );

		ELSE
		*)
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , array.adr,
													 Descr_AdrOffs*PCT.AddressSize, descr.adr );
		(*
		END;
		*)
		array.mode := Reg;
		(* space for optimizations:
		IF descr.mode = Reg THEN (* descriptor address already loaded *)
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , array.adr,  Descr_AdrOffs*PCT.AddressSize, descr.adr );
		ELSE
			IF x.mode = Var THEN  (* variable *)
				GetActivationFrame( code, x.level, descr.adr );
				PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , descr.adr,  x.offs + Descr_AdrOffs*PCT.AddressSize, x.breg );
				descr.mode := RegRel;
			ELSIF x.mode = Ref THEN  (* reference parameter *)
				GetActivationFrame( code, x.level, frame );
				PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , descr.adr, x.offs, frame);
				descr.mode := Reg; descr.offs := 0;
				PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , x.adr,  Descr_AdrOffs*PCT.AddressSize, x.breg );
			ELSIF x.mode = RegRel THEN  (* relative access: either already loaded or in record *)
				(* IF x.breg = 0 THEN  (* array in record *)*) (* distinction not needed any more as this procedure is called by Indexer *)
					PCLIR.EmitLoadConst( code, temp, PCLIR.Address, FALSE , 0 );
					PCLIR.Emit12( code, PCLIR.add, x.breg, x.adr, temp );
					PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , x.adr, x.offs + Descr_AdrOffs*PCT.AddressSize, x.adr );
				(* ELSE
					IF (x.offs # 0) OR (x.adr < 0) THEN
						PCLIR.EmitLoadConst( code, temp, PCLIR.Address, FALSE , x.offs + Descr_AdrOffs*PCT.AddressSize );
						PCLIR.Emit12( code, PCLIR.add, x.adr, x.adr, temp );
					END
				END;
				*)
			ELSIF x.mode = Abs THEN  (* global parameter *)
				PCLIR.EmitLoadAddr( code, x.breg, 0, x.var );
				PCLIR.EmitLoadAbsolute( code, PCLIR.Address, FALSE , x.adr, x.offs + Descr_AdrOffs*PCT.AddressSize, x.var );
			ELSE PCDebug.ToDo( PCDebug.NotImplemented );
			END;
		END;
		array.mode := Reg;
		*)
	END LoadArrayAdr;

	PROCEDURE DerefTensor*( code: Code;  VAR x: Item );
	BEGIN
		ASSERT ( x.mode # Reg );
		Load( code, x );  x.offs := 0;  x.mode := RegRel;
	END DerefTensor;
(** << fof  *)

PROCEDURE GetDelegateSelfReg(code: Code;  x: Item;  modeBeforeLoad: LONGINT): PCLIR.Register;
VAR  reg: PCLIR.Register;
BEGIN
	IF modeBeforeLoad = Const THEN
		reg := x.adr
	ELSIF modeBeforeLoad = Proc THEN
		PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, 0)
	ELSIF ~(PCT.StaticMethodsOnly IN x.type.flags) THEN
		reg := x.breg
	ELSE
		HALT(99)
	END;
	RETURN reg
END GetDelegateSelfReg;

PROCEDURE NilCheck(code: Code; VAR x: Item);
VAR zero: PCLIR.Register;
BEGIN
	IF PCM.NilCheck IN PCM.codeOptions THEN
		Load(code, x);
		PCLIR.EmitLoadConst(code, zero, PCLIR.Address, FALSE, 0);
		PCLIR.Emit02C(code, PCLIR.tae, zero, x.adr, -14);
	END
END NilCheck;

(**-----------Item Creation----------------*)

PROCEDURE MakeItem*(VAR x: Item; o: PCT.Symbol;  deltaLevel:  SHORTINT);
BEGIN
	ASSERT(deltaLevel >= 0, 200);
	x.level := deltaLevel;
	x.type := o.type;
	x.breg := 0;   (* fof *)
	IF o IS PCT.GlobalVar THEN
		x.mode := Abs;
		x.var := o.adr(PCBT.GlobalVariable);
		IF x.var.owner = PCBT.context THEN x.offs := x.var.offset ELSE x.offs := 0 END
	ELSIF (o IS PCT.Parameter) & o(PCT.Parameter).ref THEN
		x.mode := Ref;
		x.offs := o.adr(PCBT.Variable).offset
	ELSIF (o IS PCT.Parameter) OR (o IS PCT.LocalVar) THEN
		x.mode := Var;
		x.offs := o.adr(PCBT.Variable).offset
	ELSIF o IS PCT.Proc THEN
		x.mode := Proc;
		x.proc := o.adr(PCBT.Procedure);
		x.type := PCT.Ptr;
	(** fof >> *)
	ELSIF o IS PCT.ReturnParameter THEN
		IF o(PCT.ReturnParameter).ref THEN
			x.mode := Ref;
		ELSE
			x.mode := Var;
		END;
		x.offs := o.adr(PCBT.Variable).offset;
	(** << fof  *)
	ELSE
		HALT(99)
	END
END MakeItem;

PROCEDURE MakeStackItem*(VAR x: Item;  type: PCT.Struct);
BEGIN
	x.mode := RegRel; x.adr := PCLIR.SP;  x.offs := 0;  x.type := type
END MakeStackItem;

PROCEDURE MakeConst*(VAR x: Item;  o: PCT.Const;  type: PCT.Struct);
VAR	t: PCT.Struct;  adr: PCBT.GlobalVariable; r: REAL;  lr: LONGREAL; h: HUGEINT;
BEGIN
	x.mode := Const; t := o.type;
	IF (t = PCT.Int8) OR (t = PCT.Int16) OR (t = PCT.Int32)  THEN
		x.value := o.int
	ELSIF (t=PCT.Int64) & (o.long = SHORT(o.long)) THEN
		x.value := SHORT(o.long);
	ELSIF t = PCT.Bool THEN
		IF o.bool THEN x.value := True ELSE x.value := False END
	ELSIF PCT.IsCharType(t) OR (t = PCT.Byte) THEN
		x.value := o.int
	ELSIF t = PCT.Set THEN
		x.value := SYSTEM.VAL(LONGINT, o.set)
	ELSIF t = PCT.NilType THEN
		x.value := Nil;
	ELSIF PCT.IsFloatType(t) OR (t = PCT.String) OR (t = PCT.Int64) THEN	(*stored in the const section*)
		IF (o.owner = NIL) OR (o.owner.adr = NIL) THEN
			NEW(adr, PCBT.context);
			IF t = PCT.String THEN
				adr.offset := PCBT.context.NewStringConst(o.str^, o.int)
			ELSIF t = PCT.Int64 THEN
				h := o.long;
				adr.offset := PCBT.context.NewConst(h, 8)
			ELSIF t = PCT.Float32 THEN
				r := SHORT(o.real);
				adr.offset := PCBT.context.NewConst(r, 4);
			ELSE
				lr := o.real;
				adr.offset := PCBT.context.NewConst(lr, 8);
			END;
			IF o.owner # NIL THEN  o.owner.adr := adr  END
		ELSE
			adr := o.owner.adr(PCBT.GlobalVariable)
		END;
		x.mode := Abs;  x.var := adr;  x.offs := adr.offset;
		IF t = PCT.String THEN x.value := o.int END;
	(** fof >> *)
	ELSIF t IS PCT.EnhArray THEN
		t := PCT.ElementType( t );
		IF (o.owner = NIL ) OR (o.owner.adr = NIL ) THEN  (* double use *)
			NEW( adr, PCBT.context );
			adr.offset := PCBT.context.NewArrayConst( o( PCT.ConstArray ).data^,  o( PCT.ConstArray ).len^,   t.size( PCBT.Size ).size );
			IF o.owner # NIL THEN o.owner.adr := adr END;
		ELSE adr := o.owner.adr( PCBT.GlobalVariable );
		END;
		x.mode := Const;  x.var := adr;  x.offs := adr.offset;
		(*ASSERT ( type.size # NIL );  *)
	(** << fof  *)
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented)
	END;
	x.type := type
END MakeConst;

PROCEDURE MakeIntConst*(VAR x: Item; val: LONGINT; type: PCT.Struct);
BEGIN
	x.mode := Const; x.value := val; x.type := type
END MakeIntConst;

(** fof >> *)
PROCEDURE MakeSizeConst*(VAR x: Item; val: LONGINT);
BEGIN
	MakeIntConst(x,val,PCT.Size);
END MakeSizeConst;

PROCEDURE SetType*(VAR x: Item; type : PCT.Struct);
BEGIN
	x.type := type;
END SetType;
(** << fof  *)

(* Make TD -  Return an item containing the type descriptor of a record *)

PROCEDURE MakeTD*(VAR x: Item;  type: PCT.Record);
VAR size: PCBT.RecSize;
BEGIN
	x.mode := Abs;
	size := type.size(PCBT.RecSize);
	BEGIN{EXCLUSIVE} (* fof 070920, otherwise size.td might be inserted twice  *)
		IF size.td = NIL THEN
			PCBT.AllocateTD(size);
			IF PCT.SystemType IN type.flags THEN  PCT.AddRecord(topscope, type)  END;
		END;
	END;
	x.var := size.td;
	x.offs := x.var.offset;  x.type := PCT.Ptr
END MakeTD;

(** -----------Type Handling----------------*)

PROCEDURE GetStaticSize*(t: PCT.Struct): LONGINT;
BEGIN  RETURN  t.size(PCBT.Size).size
END GetStaticSize;

PROCEDURE GetArrayBaseSize(code: Code; VAR size: Item; arr: Item);
VAR t: PCT.Struct; len: Item; mode: SHORTINT;  name: ARRAY 32 OF CHAR;
BEGIN
	ASSERT(arr.type IS PCT.Array);
	(** fof >> *)
	IF (arr.type IS PCT.EnhArray) THEN
		t := arr.type( PCT.EnhArray ).base
	ELSE
	t := arr.type(PCT.Array).base;
	END;
	(** << fof  *)
	IF (t IS PCT.Basic) OR (t IS PCT.Record) OR (t IS PCT.Pointer) OR (t IS PCT.Delegate) THEN
		MakeIntConst(size, GetStaticSize(t), PCT.Int32)
	ELSIF t IS PCT.Array THEN
		mode := t(PCT.Array).mode;
		IF mode = PCT.open THEN
			DEC(arr.boffs, PCT.AddressSize); arr.type := t;
			len.mode := RegRel; len.adr := arr.breg; len.offs := arr.boffs; len.type := PCT.Int32;
			GetArrayBaseSize(code, size, arr);
			DOp(code, PCS.times, size, len)
		ELSIF mode = PCT.static THEN
			MakeIntConst(size, GetStaticSize(t), PCT.Int32)
		ELSE
			PCDebug.GetTypeName(t, name); HALT(MAX(INTEGER));
			PCDebug.ToDo(PCDebug.NotImplemented);
			MakeIntConst(size, 4, PCT.Int32)
		END
	(** fof >> *)
	ELSIF t IS PCT.EnhArray THEN
		mode := t( PCT.EnhArray ).mode;
		IF mode = PCT.open THEN
			HALT( 200 );  DEC( arr.boffs, 8 );  arr.type := t;  len.mode := RegRel;
			len.adr := arr.breg;  len.offs := arr.boffs;  len.type := PCT.Int32;
			GetArrayBaseSize( code, size, arr );  DOp( code, PCS.times, size, len );
		ELSIF mode = PCT.static THEN
			MakeSizeConst( size, GetStaticSize( t ))
			(*fof*)
		ELSE
			PCDebug.GetTypeName( t, name );  HALT( MAX( INTEGER ) );
			PCDebug.ToDo( PCDebug.NotImplemented );
			MakeSizeConst( size, PCT.AddressSize )
		END
		(** << fof  *)
	ELSE
		PCDebug.GetTypeName(t, name); HALT(MAX(INTEGER));
		PCDebug.ToDo(PCDebug.NotImplemented);
		MakeIntConst(size, 4, PCT.Int32)
	END
END GetArrayBaseSize;

(* Get dim-th dimension. t # NIL is type of this dimension if already known *)

PROCEDURE ArrayDim(code: Code;  VAR res,  arr: Item;  dim: LONGINT);
VAR c: LONGINT;  t: PCT.Array;
BEGIN
	IF arr.type = PCT.String THEN
		ASSERT(arr.value # 0	);
		MakeIntConst(res, arr.value, PCT.Int32)
	ELSE
		t := arr.type(PCT.Array); c := dim;
		WHILE c > 0 DO  t := t.base(PCT.Array); DEC(c)  END;
		IF t.mode = PCT.static THEN
			MakeIntConst(res, t.len, PCT.Int32)
		ELSE
			ASSERT(t.mode = PCT.open);
			ASSERT(arr.mode IN {Reg, RegRel});
			res.mode := RegRel; res.adr := arr.breg; res.offs := arr.boffs - dim*PCT.AddressSize; res.type := PCT.Int32
		END
	END
END ArrayDim;
(** fof >> *)
	PROCEDURE EnhArrayLen( code: Code;  VAR res, arr: Item;  dim: LONGINT );
	VAR c: LONGINT;  t: PCT.EnhArray;
	BEGIN
		t := arr.type( PCT.EnhArray );  c := dim;
		WHILE c > 0 DO t := t.base( PCT.EnhArray );  DEC( c ) END;
		IF (t.mode = PCT.static) OR (t.len > 0) THEN
			MakeSizeConst( res, t.len);   (* mixture of arrays not allowed, is handled by parser *)
		ELSE
			ASSERT ( t.mode = PCT.open );  ASSERT ( arr.mode IN {Reg, RegRel} );
			res.mode := RegRel;  res.adr := arr.adr;  res.offs :=  Descr_LenOffs*PCT.AddressSize + dim * 2 * PCT.AddressSize;
			res.type := PCT.Int32
		END
	END EnhArrayLen;

	PROCEDURE EnhArrayInc( code: Code;  VAR res, arr: Item;  dim: LONGINT );
	VAR c: LONGINT;  t: PCT.EnhArray;
	BEGIN
		t := arr.type( PCT.EnhArray );  c := dim;
		WHILE c > 0 DO t := t.base( PCT.EnhArray );  DEC( c ) END;
		IF (t.mode = PCT.static) OR (t.inc > 0) THEN
			MakeSizeConst( res, t.inc );   (* mixture of arrays not allowed, is handled by parser *)
		ELSE
			ASSERT ( t.mode = PCT.open );
			ASSERT ( arr.mode IN {Reg, RegRel} );
			res.mode := RegRel;  res.adr := arr.adr;  res.offs :=  Descr_IncOffs*PCT.AddressSize + dim * 2 * PCT.AddressSize;
			res.type := PCT.Int32
		END
	END EnhArrayInc;
(** << fof  *)


PROCEDURE GetTD(code: Code;  r: Item;  VAR td: Item;  superclass: BOOLEAN);
VAR  rec: PCT.Record; level: LONGINT;
BEGIN
	ASSERT((r.type IS PCT.Record) OR (r.type IS PCT.Pointer) OR (r.type = PCT.Ptr), 110);
	IF (r.type IS PCT.Pointer) THEN
		td := r;
		NilCheck(code, td);
		Load(code, td);
		td.mode := RegRel;  td.offs := -PCT.AddressSize;  td.type := PCT.Ptr;
		rec := r.type(PCT.Pointer).baseR;
	ELSIF r.type = PCT.Ptr THEN
		td := r;
		NilCheck(code, td);
		Load(code, td);
		td.mode := RegRel;  td.offs := -PCT.AddressSize;  td.type := PCT.Ptr;
		ASSERT(~superclass, 111);
	ELSIF r.deref THEN	(*this is a dereferenced pointer*)
		td := r;
		LoadAdr(code, td);
		td.mode := RegRel;  td.offs := -PCT.AddressSize;  td.type := PCT.Ptr;
		rec := r.type(PCT.Record);
	ELSIF r.mode = Ref THEN
		td.mode := Var;  td.level := r.level; td.offs := r.offs+PCT.AddressSize;  td.type := PCT.Ptr;
		ASSERT(td.level >= 0);
		rec := r.type(PCT.Record)
	ELSE
		MakeTD(td, r.type(PCT.Record));
		rec := r.type(PCT.Record)
	END;
	IF superclass THEN
		level := rec.size(PCBT.RecSize).level;
		ASSERT(level > 0);
		Load(code, td);
		td.mode := RegRel;  td.offs := BaseTypesTable*PCT.AddressSize - PCT.AddressSize*(level-1);  td.type := PCT.Ptr
	END
END GetTD;

PROCEDURE TypeCheck*(code: Code;  VAR r: Item;  str: PCT.Struct;  trap, equal: BOOLEAN);
VAR  td, ref: Item;  trapNo: LONGINT;  rec: PCT.Record;
BEGIN
	ASSERT((r.type IS PCT.Record) & (str IS PCT.Record) OR PCT.IsPointer(r.type) & (str IS PCT.Pointer), 200);
	IF str IS PCT.Record THEN
		rec := str(PCT.Record)
	ELSE
		rec := str(PCT.Pointer).baseR
	END;
	GetTD(code, r, td, FALSE);  Load(code, td);
	MakeTD(ref, rec);  Load(code, ref);
	IF equal THEN
		trapNo := PCM.TypeEqualTrap;
	ELSE
		td.mode := RegRel;  td.offs := BaseTypesTable * PCT.AddressSize - PCT.AddressSize * rec.size(PCBT.RecSize).level;
		Load(code, td);
		trapNo := PCM.TypeCheckTrap
	END;
	IF trap THEN
		PCLIR.Emit02C(code, PCLIR.tne, td.adr, ref.adr, trapNo);
		r.type := str
	ELSE
		InitCC(r, ccEQ, td.adr, ref.adr)
	END
END TypeCheck;
(** fof >> *)
(* Built-In array increments *)
PROCEDURE Incr*( code: Code;  VAR arr, dim: Item );
VAR res: Item;
BEGIN
	IF arr.type IS PCT.EnhArray THEN
		IF arr.mode IN {Abs, Var, Ref, RegRel, Const} THEN LoadAdr( code, arr ) END;   (* RegRel if in records, Abs when global, Const if constant  *)
		IF dim.mode = Const THEN
			ASSERT ( PCT.IsCardinalType( dim.type ), 201 );
			EnhArrayInc( code, res, arr, dim.value );  arr := res
		ELSE PCDebug.ToDo( PCDebug.NotImplemented )
		END;
	ELSIF arr.type IS PCT.Tensor THEN
		TensorGetInc( code, res, arr, dim, TRUE );  arr := res
	ELSE PCDebug.ToDo( PCDebug.NotImplemented );
	END;
END Incr;

(* Built-In tensor dim *)
PROCEDURE Dim*( code: Code;  VAR arr: Item );
VAR res: Item;
BEGIN
	IF arr.type IS PCT.Tensor THEN TensorGetDim( code, res, arr );  arr := res;
	ELSE PCDebug.ToDo( PCDebug.NotImplemented );
	END;
END Dim;
(** << fof  *)

(* Built-In array len *)

PROCEDURE Len*(code: Code; VAR arr, dim: Item);
VAR res: Item;
BEGIN
	(** fof >> *)
	IF arr.type IS PCT.EnhArray THEN
		IF arr.mode IN {Abs, Var, Ref, RegRel, Const} THEN LoadAdr( code, arr ) END;   (* RegRel if in records, Abs when global, Const if constant  *)
		IF dim.mode = Const THEN
			ASSERT ( PCT.IsCardinalType( dim.type ), 201 );
			EnhArrayLen( code, res, arr, dim.value );  arr := res
		ELSE PCDebug.ToDo( PCDebug.NotImplemented )
		END
	ELSIF arr.type IS PCT.Tensor THEN
		TensorGetLen( code, res, arr, dim, TRUE );  arr := res;
	ELSE
	(** << fof  *)
	ASSERT(arr.type IS PCT.Array, 200);
	IF arr.mode IN {Var, Ref} THEN LoadAdr(code, arr) END;
	IF dim.mode = Const THEN
		ASSERT(PCT.IsCardinalType(dim.type), 201);
		ArrayDim(code, res, arr, dim.value); arr := res
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented)
	END
	END; (* fof *)
END Len;

PROCEDURE GenConv(code: Code;  op: PCLIR.Opcode;  VAR x: Item;  size: PCLIR.Size;  signed: BOOLEAN);
VAR srcsize: PCBT.Size;
BEGIN
	srcsize := x.type.size(PCBT.Size);
	IF (srcsize.type # size) (*OR (srcsize.signed # signed)*) THEN
		PCLIR.EmitConv(code, op, x.adr, size, signed, x.adr)
	END;
END GenConv;

(**-----------Stack Handling --------------------*)

(** Enter - create a procedure activation frame, allocate size bytes local variables *)

PROCEDURE Enter*(code: Code; callconv: LONGINT; adr: PCM.Attribute); (* ejz *)
BEGIN
	PCLIR.EmitEnter(code, callconv, adr) (* ejz *)
END Enter;

(** Leave - remove a procedure activation frame, remove size bytes of parameters *)

PROCEDURE Leave*(code: Code; callconv: LONGINT; proc: PCT.Proc; adr: PCM.Attribute (* ug *)); (* ejz *)
VAR size: LONGINT; padr: PCBT.Procedure (* ug *);
BEGIN
	size := 0;
	IF proc # NIL THEN
		padr := proc.adr(PCBT.Procedure); (* ug *)
		size := padr.parsize - PCLIR.CG.ParamAlign * 2;
		IF (proc.type IS PCT.Record) THEN
			INC(size, PCT.AddressSize * 2)
		ELSIF (proc.type IS PCT.Array) THEN
			IF proc.type(PCT.Array).mode = PCT.open THEN
				size := 0;
			ELSE
				INC(size, PCT.AddressSize);
			END;
		(** fof >> *)
		ELSIF (proc.type IS PCT.EnhArray) THEN
			(* no: the caller clears the stack in all cases
			IF proc.type( PCT.EnhArray ).mode = PCT.open THEN
			ELSE
				INC( size, PCT.AddressSize );
			END;
			*)
		(** << fof  *)
		END
	END;
	PCLIR.EmitExit(code, callconv, size, adr (* ug *)) (* ejz *)
END Leave;

(* StackAllocate - allocate size bytes on the stack, return new top of stack *)

PROCEDURE StackAllocate(code: Code; size: LONGINT; VAR tos: Item);
VAR reg: PCLIR.Register;
BEGIN
	INC(size, (-size) MOD PCLIR.CG.ParamAlign);	(*align up *)
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, size);
	PCLIR.Emit12(code, PCLIR.sub, tos.adr, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.loadsp, tos.adr);
	tos.mode := RegRel; tos.adr := PCLIR.SP; tos.offs := 0; tos.type := PCT.Address
END StackAllocate;

PROCEDURE FreeStack*(code: Code;  type: PCT.Struct);
VAR  size: LONGINT;  reg: PCLIR.Register;
BEGIN
	size := GetStaticSize(type);
	INC(size, (-size) MOD PCLIR.CG.ParamAlign);	(*align*)
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, size);
	PCLIR.Emit12(code, PCLIR.add, reg, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.loadsp, reg);
END FreeStack;

PROCEDURE RemoveArys*(code: Code; aryNbr: LONGINT);
VAR
	reg: PCLIR.Register;
	i: LONGINT;
BEGIN
	ASSERT(aryNbr > 0);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, 0, PCLIR.SP);
	FOR i := 0 TO aryNbr-2 DO
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, 0, reg);
	END;
	PCLIR.Emit01(code, PCLIR.loadsp, reg);
END RemoveArys;

(*
	return statement of procedure that returns open array, calls a procedure that itself returns
	either an open or static array
*)
PROCEDURE ReturnProc(code: Code; x: Item; proc: PCT.Proc);
VAR
	size, dim, len: Item;
	aligned: BOOLEAN;
	parSize, offs, staticSize: LONGINT;
	reg, reg2, reg3, src, base, const, mask: PCLIR.Register;
	type, itemType: PCT.Struct;
BEGIN
	parSize := proc.adr(PCBT.Procedure).parsize;

	LoadAdr(code, x);
		(* compute size *)
	IF x.type(PCT.Array).mode = PCT.static THEN
		dim.mode := Const; dim.value := x.type(PCT.Array).len;
		GetArrayBaseSize(code, size, x);
		DOp(code, PCS.times, size, dim);
		Load(code, size);
		GenConv(code, PCLIR.convu, size, PCLIR.Address, FALSE);
	ELSE
			(* function returns open array *)
		type := proc.type(PCT.Array).base;
		len.mode := Reg; len.type := PCT.Int32;
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, src, 0, PCLIR.SP);
		size.mode := Reg; size.type := PCT.Int32;
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, size.adr, -PCT.AddressSize, src);
		offs := PCT.AddressSize*2;
		WHILE (type # NIL) & (type IS PCT.Array) & (type(PCT.Array).mode = PCT.open) DO
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, len.adr, -offs, src);
			DOp(code, PCS.times, size, len);
			type := type(PCT.Array).base;
			INC(offs, PCT.AddressSize);
		END;
		staticSize := GetStaticSize(type);
		IF staticSize > 1 THEN
			PCLIR.EmitLoadConst(code, len.adr, PCLIR.Int32, FALSE, staticSize);
			DOp(code, PCS.times, size, len);
		END;
	END;

	aligned := (size.mode = Const) & (size.value MOD 4 = 0);

	(* avoid producing wrong code ??? *)
	PCLIR.Emit01(code, PCLIR.push, PCLIR.FP);
	PCLIR.Emit10(code, PCLIR.pop, reg3, PCLIR.Address, FALSE);
	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, parSize + PCT.AddressSize);
	PCLIR.Emit12(code, PCLIR.add, reg2, reg3, const);

		(*allocate*)
	PCLIR.Emit12(code, PCLIR.sub, reg, reg2, size.adr);
	IF ~aligned THEN
		PCLIR.EmitLoadConst(code, mask, PCLIR.Address, FALSE, LONGINT(0FFFFFFFCH));
		PCLIR.Emit12(code, PCLIR.and, reg, reg, mask);
	END;

	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, parSize, PCLIR.FP);
	PCLIR.Emit01(code, PCLIR.push, base);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize, PCLIR.FP);	(* IP *)
	PCLIR.Emit01(code, PCLIR.push, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, 0, PCLIR.FP); 	(* FP *)
	PCLIR.Emit01(code, PCLIR.push, reg3);
	PCLIR.Emit01(code, PCLIR.push, reg);

	itemType := x.type;
	type := proc.type;
	offs := PCT.AddressSize;
	WHILE (type # NIL) & (type IS PCT.Array) & (type(PCT.Array).mode = PCT.open) DO
		IF itemType(PCT.Array).mode = PCT.static THEN
			PCLIR.EmitLoadConst(code, reg3, PCLIR.Int32, FALSE, itemType(PCT.Array).len);
		ELSE
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, -offs, src);
		END;
		PCLIR.EmitStoreRelative(code, -offs, base, reg3);
		INC(offs, PCT.AddressSize);
		itemType := itemType(PCT.Array).base;
		type := type(PCT.Array).base;
	END;

	IF x.type(PCT.Array).mode = PCT.open THEN
		offs := PCT.AddressSize*5;
	ELSE
		offs := PCT.AddressSize*4;
	END;
	PCLIR.EmitLoadConst(code, reg3, PCLIR.Int32, FALSE, offs);
	PCLIR.Emit12(code, PCLIR.add, src, PCLIR.SP, reg3);

		(*move*)
	PCLIR.Emit12(code, PCLIR.add, src, src, size.adr);
	PCLIR.EmitLoadConst(code, const, PCLIR.Int32, FALSE, 1);
	PCLIR.Emit12(code, PCLIR.sub, src, src, const);
	PCLIR.Emit12(code, PCLIR.add, reg, reg, size.adr);
	PCLIR.Emit12(code, PCLIR.sub, reg, reg, const);
	PCLIR.Emit03(code, PCLIR.moveDown, src, reg, size.adr);

		(* set FP *)
	PCLIR.Emit10(code, PCLIR.pop, reg, PCLIR.Address, FALSE);
	PCLIR.EmitLoadConst(code, reg3, PCLIR.Address, FALSE, PCT.AddressSize*3);
	PCLIR.Emit12(code, PCLIR.sub, reg, reg, reg3);
	PCLIR.Emit01(code, PCLIR.loadfp, reg);

		(* restore array base, caller's IP and FP *)
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize*2, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, PCT.AddressSize*2, PCLIR.FP, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, PCT.AddressSize, PCLIR.FP, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, 0, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, 0, PCLIR.FP, reg3);

	PCLIR.Emit01(code, PCLIR.loadsp, PCLIR.FP);
END ReturnProc;

(*
	procedure returns open array
*)
PROCEDURE ReturnArray(code: Code; x: Item; proc: PCT.Proc);
VAR
	size, dim: Item;
	parSize, offs: LONGINT;
	mask, reg, reg2, reg3, base, const: PCLIR.Register;
	begin, end, skipSPSet: Label;
	aligned, skip, smallerStack: BOOLEAN;
	type, itemType: PCT.Struct;
BEGIN
	smallerStack := FALSE;
	parSize := proc.adr(PCBT.Procedure).parsize;

	LoadAdr(code, x);
		(* compute size *)
	IF x.type(PCT.Array).mode = PCT.static THEN
		dim.mode := Const; dim.value := x.type(PCT.Array).len;
		IF ~x.deref THEN
			smallerStack := TRUE;
		END;
	ELSE
		dim.mode := RegRel; dim.adr := x.breg; dim.offs := x.boffs; dim.type := PCT.Int32;
	END;
	GetArrayBaseSize(code, size, x);

	aligned := (size.mode = Const) & (size.value MOD 4 = 0);
	DOp(code, PCS.times, size, dim);
	skip := (size.mode = Const) & (size.value < 4096);
	Load(code, size);
	GenConv(code, PCLIR.convu, size, PCLIR.Address, FALSE);

	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, parSize, PCLIR.FP);
	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, GetDims(proc.type)*PCT.AddressSize + PCT.AddressSize);
	PCLIR.Emit12(code, PCLIR.sub, reg2, base, const);

		(*allocate*)
	(* PCLIR.Emit12(code, PCLIR.sub, reg, PCLIR.SP, size.adr); *)
	PCLIR.Emit12(code, PCLIR.sub, reg, reg2, size.adr);
	IF ~aligned THEN
		PCLIR.EmitLoadConst(code, mask, PCLIR.Address, FALSE, LONGINT(0FFFFFFFCH));
		PCLIR.Emit12(code, PCLIR.and, reg, reg, mask);
	END;

	IF ~smallerStack THEN

		skipSPSet := code.pc;
		PCLIR.Emit02C(code, PCLIR.jle, PCLIR.SP, reg, -1);

		PCLIR.Emit01(code, PCLIR.loadsp, reg);
		IF ~skip THEN
			DefLabel(code, begin);

			PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, 1000H);
			PCLIR.Emit12(code, PCLIR.sub, reg2, reg2, const);

			end := code.pc;
			PCLIR.Emit02C(code, PCLIR.jb, reg2, PCLIR.SP, -1);

			PCLIR.EmitLoadConst(code, const, PCLIR.Int8, FALSE, 1000H);
			PCLIR.EmitStoreRelative(code, 0, reg2, const);

			PCLIR.Emit0C(code, PCLIR.jmp, begin);

			PCLIR.FixList(code, end, code.pc);
			PCLIR.Emit0C(code, PCLIR.label, 0);
		END;

		PCLIR.FixList(code, skipSPSet, code.pc);
		PCLIR.Emit0C(code, PCLIR.label, 0);
	END;

	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, parSize, PCLIR.FP);
	PCLIR.Emit01(code, PCLIR.push, base);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize, PCLIR.FP);	(* IP *)
	PCLIR.Emit01(code, PCLIR.push, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, 0, PCLIR.FP); 	(* FP *)
	PCLIR.Emit01(code, PCLIR.push, reg3);
	PCLIR.Emit01(code, PCLIR.push, reg);

	itemType := x.type;
	type := proc.type;
	offs := 0;
	WHILE (type # NIL) & (type IS PCT.Array) & (type(PCT.Array).mode = PCT.open) DO
		IF itemType(PCT.Array).mode = PCT.static THEN
			PCLIR.EmitLoadConst(code, reg3, PCLIR.Address, FALSE, itemType(PCT.Array).len);
		ELSE
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, x.boffs - offs, x.breg);
		END;
		PCLIR.EmitStoreRelative(code, - PCT.AddressSize - offs, base, reg3);
		INC(offs, PCT.AddressSize);
		itemType := itemType(PCT.Array).base;
		type := type(PCT.Array).base;
	END;

		(*move*)
	PCLIR.Emit12(code, PCLIR.add, x.adr, x.adr, size.adr);
	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, 1);
	PCLIR.Emit12(code, PCLIR.sub, x.adr, x.adr, const);
	PCLIR.Emit12(code, PCLIR.add, reg, reg, size.adr);
	PCLIR.Emit12(code, PCLIR.sub, reg, reg, const);
	PCLIR.Emit03(code, PCLIR.moveDown, x.adr, reg, size.adr);

		(* set FP *)
	PCLIR.Emit10(code, PCLIR.pop, reg, PCLIR.Address, FALSE);
	PCLIR.EmitLoadConst(code, reg3, PCLIR.Address, FALSE, PCT.AddressSize*3);
	PCLIR.Emit12(code, PCLIR.sub, reg, reg, reg3);
	PCLIR.Emit01(code, PCLIR.loadfp, reg);

		(* restore array base, caller's IP and FP *)
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize*2, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, 8, PCLIR.FP, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, PCT.AddressSize, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, 4, PCLIR.FP, reg3);
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg3, 0, PCLIR.SP);
	PCLIR.EmitStoreRelative(code, 0, PCLIR.FP, reg3);

	PCLIR.Emit01(code, PCLIR.loadsp, PCLIR.FP);
END ReturnArray;

(** fof >> *)
(*	procedure returns open enh array *)

	PROCEDURE CopyEnhArray( code: Code;  src, dest: Item;  copy: PCT.Proc );   (* precondition: designators of src and dest are available via src.adr, dest.adr *)
	VAR i: Item;  btype: PCT.Struct;  elementsize: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF dest.mode # Reg THEN LoadAdr( code, dest ) END;
		PCLIR.Emit01( code, PCLIR.push, dest.adr );
		IF src.mode # Reg THEN LoadAdr( code, src ) END;   (* difference to copy tensor: no deref here *)
		PCLIR.Emit01( code, PCLIR.push, src.adr );
		btype := PCT.ElementType( src.type );
		elementsize := btype.size( PCBT.Size ).size;
		PCLIR.EmitLoadConst( code, size, PCLIR.Address, FALSE , elementsize );
		PCLIR.Emit01( code, PCLIR.push, size );  MakeItem( i, copy, 0 );
		Call( code, i );
	END CopyEnhArray;

	PROCEDURE MakeReturnItem*( code: Code;  VAR dst: Item;  proc: PCT.Proc );
	VAR parSize: LONGINT;
	BEGIN
		parSize := proc.adr( PCBT.Procedure ).parsize;  dst.mode := Var;
		dst.offs := parSize;  dst.level := 0;
		dst.type := proc.type;   (* type already checked *)
		LoadAdr( code, dst );
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , dst.adr, 0, dst.adr );
	END MakeReturnItem;
(** << fof  *)

PROCEDURE GetDims*(t: PCT.Struct): LONGINT;
VAR dims: LONGINT;
BEGIN
	IF (t # NIL ) & (t IS PCT.Array) THEN (* fof *)
	WHILE (t # NIL) & (t IS PCT.Array) & (t(PCT.Array).mode = PCT.open) DO
		INC(dims);
		t := t(PCT.Array).base;
	END;
	(** fof >> *) (* necessary ? use dim field instead? *)
	ELSIF (t # NIL ) & (t IS PCT.EnhArray) THEN
		WHILE (t # NIL ) & (t IS PCT.EnhArray) &  (t( PCT.EnhArray ).mode = PCT.open) DO
			INC( dims );  t := t( PCT.EnhArray ).base;
		END;
	END;
	(** << fof  *)
	RETURN dims;
END GetDims;

(** LocalArray - create a local copy of an array passed as a reference *)

PROCEDURE LocalArray*(code: Code;  par: PCT.Parameter);
VAR  x, size, dim: Item;  reg, mask: PCLIR.Register;  aligned: BOOLEAN;  offs: LONGINT;
	reg2, const: PCLIR.Register; begin, end: Label; skip: BOOLEAN;
BEGIN
	ASSERT(~par.ref);
	MakeItem(x, par, 0);  LoadAdr(code, x);  offs := x.offs;
		(*compute size*)
	dim.mode := RegRel;  dim.adr := x.breg;  dim.offs := x.boffs;  dim.type := PCT.Int32;
	GetArrayBaseSize(code, size, x);
	aligned := (size.mode = Const) & (size.value MOD 4 = 0);
	DOp(code, PCS.times, size, dim);
	skip := (size.mode = Const) & (size.value < 4096);
	Load(code, size);
	GenConv(code, PCLIR.convu, size, PCLIR.Address, FALSE);

	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, 0);
	PCLIR.Emit12(code, PCLIR.add, reg2, PCLIR.SP, const);

		(*allocate*)
	PCLIR.Emit12(code, PCLIR.sub, reg, PCLIR.SP, size.adr);
	IF ~aligned THEN
		PCLIR.EmitLoadConst(code, mask, PCLIR.Address, FALSE, LONGINT(0FFFFFFFCH));
		PCLIR.Emit12(code, PCLIR.and, reg, reg, mask);
	END;

	PCLIR.Emit01(code, PCLIR.loadsp, reg);
	IF ~skip THEN

		DefLabel(code, begin);

		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, 1000H);
		PCLIR.Emit12(code, PCLIR.sub, reg2, reg2, const);

		end := code.pc;
		PCLIR.Emit02C(code, PCLIR.jb, reg2, PCLIR.SP, -1);

		PCLIR.EmitLoadConst(code, const, PCLIR.Int8, FALSE, 1000H);
		PCLIR.EmitStoreRelative(code, 0, reg2, const);

		PCLIR.Emit0C(code, PCLIR.jmp, begin);

		PCLIR.FixList(code, end, code.pc);
		PCLIR.Emit0C(code, PCLIR.label, 0);

	END;
		(*move*)
	PCLIR.Emit03(code, PCLIR.move, x.adr, reg, size.adr);
		(*store address*)
	PCLIR.EmitStoreRelative(code, offs, PCLIR.FP, PCLIR.SP)
END LocalArray;

(** fof >> *)
	PROCEDURE LocalEnhArray*( code: Code;  par: PCT.Parameter;    copy: PCT.Proc );
	VAR x, y, size, dim, k: Item;  reg, mask: PCLIR.Register;  aligned: BOOLEAN;  offs: LONGINT;
		reg2, const: PCLIR.Register;  begin, end: Label;  skip: BOOLEAN;  spoffset: LONGINT;  d, c: LONGINT;
		btype: PCT.Struct;

		PROCEDURE CreateLocalArray( VAR spoffset: LONGINT );
		VAR dim: Item;  doffs: LONGINT;  reg, inc: PCLIR.Register;
		BEGIN
			d := x.type( PCT.EnhArray ).dim;  c := d;

			(* stack allocation *)
			PCLIR.EmitLoadConst( code, reg, PCLIR.Address, FALSE , PCT.AddressSize*2 * d + Descr_LenOffs*PCT.AddressSize );
			PCLIR.Emit12( code, PCLIR.sub, reg, PCLIR.SP, reg );
			PCLIR.Emit01( code, PCLIR.loadsp, reg );
			INC( spoffset, 8 * d + Descr_LenOffs*PCT.AddressSize );

			btype := x.type;
			WHILE btype IS PCT.EnhArray DO btype := btype( PCT.EnhArray ).base END;
			PCLIR.EmitLoadConst( code, inc, PCLIR.Address, FALSE , GetStaticSize( btype ) );
			WHILE c > 0 DO  (* set dimensions and increments *)
				DEC( c );  doffs := PCT.AddressSize*2 * (d - 1 - c) + Descr_LenOffs*PCT.AddressSize;
				EnhArrayLen( code, dim, x, c );  Load( code, dim );
				PCLIR.EmitStoreRelative( code, doffs, PCLIR.SP, dim.adr );
				PCLIR.EmitStoreRelative( code, doffs + PCT.AddressSize, PCLIR.SP, inc );
				PCLIR.Emit12( code, PCLIR.mul, inc, inc, dim.adr );
			END;
			PCLIR.EmitLoadConst( code, y.adr, PCLIR.Address, FALSE , spoffset );
			PCLIR.Emit12( code, PCLIR.add, y.adr, PCLIR.SP, y.adr );
			PCLIR.EmitStoreRelative( code, Descr_AdrOffs*PCT.AddressSize, PCLIR.SP, y.adr );   (* store address *)
			PCLIR.EmitLoadConst( code, y.breg, PCLIR.Address, FALSE , -1 );   (* store empty protector (-1) -> may not be overwritten  *)
			PCLIR.EmitStoreRelative( code, Descr_PtrOffs*PCT.AddressSize, PCLIR.SP, y.breg );

			PCLIR.EmitLoadConst( code, y.breg, PCLIR.Address, FALSE , 0 );   (* to have a correct breg register...   *)
			PCLIR.Emit12( code, PCLIR.add, y.breg, PCLIR.SP, y.breg );
			y.boffs := PCT.AddressSize*2 * (d - 1) + Descr_LenOffs*PCT.AddressSize;  y.offs := 0;  y.mode := RegRel;
			y.type := x.type;
		END CreateLocalArray;


	BEGIN
		SaveRegisters( code );
		ASSERT ( ~par.ref );
		MakeItem( x, par, 0 );  x.mode := Ref;  LoadAdr( code, x );  offs := x.offs;

		(*compute size*)
		dim.mode := RegRel;  dim.adr := x.breg;  dim.offs := x.boffs;
		dim.type := PCT.Int32;  GetArrayBaseSize( code, size, x );
		aligned := (size.mode = Const) & (size.value MOD 4 = 0);
		DOp( code, PCS.times, size, dim );
		skip := (size.mode = Const) & (size.value < 4096);  Load( code, size );
		GenConv( code, PCLIR.convu, size, PCLIR.Address, FALSE );

		PCLIR.EmitLoadConst( code, const, PCLIR.Address, FALSE , 0 );
		PCLIR.Emit12( code, PCLIR.add, reg2, PCLIR.SP, const );

		(*allocate*)
		PCLIR.Emit12( code, PCLIR.sub, reg, PCLIR.SP, size.adr );
		IF ~aligned THEN
			PCLIR.EmitLoadConst( code, mask, PCLIR.Address, FALSE , LONGINT(0FFFFFFFCH) );
			PCLIR.Emit12( code, PCLIR.and, reg, reg, mask );
		END;
		PCLIR.Emit01( code, PCLIR.loadsp, reg );
		IF ~skip THEN

			DefLabel( code, begin );

			PCLIR.EmitLoadConst( code, const, PCLIR.Address, FALSE , 1000H );
			PCLIR.Emit12( code, PCLIR.sub, reg2, reg2, const );

			end := code.pc;  PCLIR.Emit02C( code, PCLIR.jb, reg2, PCLIR.SP, -1 );

			PCLIR.EmitLoadConst( code, const, PCLIR.Int8, FALSE , 1000H );
			PCLIR.EmitStoreRelative( code, 0, reg2, const );

			PCLIR.Emit0C( code, PCLIR.jmp, begin );

			PCLIR.FixList( code, end, code.pc );  PCLIR.Emit0C( code, PCLIR.label, 0 );

		END;
		spoffset := 0;
		CreateLocalArray( spoffset );   (* create array descriptor of local array *)

		(* IF ~EnhArrayInlineCopy THEN *)
		CopyEnhArray( code, x, y, copy );
		PCLIR.EmitLoadConst( code, const, PCLIR.Address, FALSE , spoffset );
		PCLIR.Emit12( code, PCLIR.add, const, PCLIR.SP, const );
		PCLIR.Emit01( code, PCLIR.loadsp, const );

		(* now set the correct values on x *)
		d := x.type( PCT.EnhArray ).dim;  c := d;  btype := x.type;
		WHILE btype IS PCT.EnhArray DO btype := btype( PCT.EnhArray ).base END;
		MakeSizeConst( k, GetStaticSize( btype ) );
		WHILE c > 0 DO
			DEC( c );   (* set dimensions and increments *)
			EnhArrayLen( code, dim, x, c );
			Load( code, dim );
			PCLIR.Emit01( code, PCLIR.push, dim.adr );
			SetEnhArrayLen( code, x, k, d, c );
		END;

		(*store address*)
		PCLIR.EmitStoreRelative( code, offs + Descr_AdrOffs*PCT.AddressSize, PCLIR.FP, PCLIR.SP );   (* address *)
		PCLIR.EmitLoadConst( code, const, PCLIR.Address, FALSE , -1 );
		PCLIR.EmitStoreRelative( code, offs + Descr_PtrOffs*PCT.AddressSize, PCLIR.FP, const );   (* protector = -1 ->  may not be overwritten *)

		RestoreRegisters( code );
	END LocalEnhArray;

	PROCEDURE PushStaticArray*( code: Code;  t: PCT.EnhArray);
	VAR size: LONGINT;  reg, reg2: PCLIR.Register;
	BEGIN
		ASSERT ( t.mode = PCT.static );

		size := GetStaticSize( t ) + ((-GetStaticSize( t )) MOD 4); (*  INC( offset, size );  *)
		PCLIR.EmitLoadConst( code, reg, PCLIR.Address, FALSE , size );
		PCLIR.Emit12( code, PCLIR.sub, reg2, PCLIR.SP, reg );
		PCLIR.Emit01( code, PCLIR.loadsp, reg2 );
		PCLIR.Emit01( code, PCLIR.push, PCLIR.SP );
	END PushStaticArray;
(** << fof  *)

(** AllocateLocalArray - create a local dynamic array *)

PROCEDURE AllocateLocalArray*(code: Code;  p: PCT.LocalVar;  size: Item);
VAR x, bsize: Item;  reg, mask: PCLIR.Register;  aligned: BOOLEAN;  offs: LONGINT;
BEGIN
	MakeItem(x, p, 0);  LoadAdr(code, x);  offs := x.offs;
		(*compute size*)
	Load(code, size);
	PCLIR.EmitStoreRelative(code, x.boffs, x.breg, size.adr);	(*set dimension*)
	GetArrayBaseSize(code, bsize, x);
	aligned := (bsize.mode = Const) & (bsize.value MOD 4 = 0);
	DOp(code, PCS.times, size, bsize);
	Load(code, size);
		(*allocate*)
	Convert (code, size, PCT.Address, TRUE);
	PCLIR.Emit12(code, PCLIR.sub, reg, PCLIR.SP, size.adr);
	IF ~aligned THEN
		PCLIR.EmitLoadConst(code, mask, PCLIR.Address, FALSE, LONGINT(0FFFFFFFCH));
		PCLIR.Emit12(code, PCLIR.and, reg, reg, mask)
	END;
	PCLIR.Emit01(code, PCLIR.loadsp, reg);
	PCLIR.EmitStoreRelative(code, offs, PCLIR.FP, PCLIR.SP)
END AllocateLocalArray;

(** PushRetDesc - Push the return descriptor for items with non-primive types *)

PROCEDURE PushRetDesc*(code: Code;  i: Item);
VAR size: LONGINT;  reg: PCLIR.Register;  type: PCT.Struct;
BEGIN
	type := i.type;
	size := GetStaticSize(type);
(*
	ASSERT(size MOD 4 = 0);
*)
	IF type IS PCT.Record THEN
		PCLIR.EmitLoadConst(code, reg, PCLIR.Int32, TRUE, size);
		PCLIR.Emit01(code, PCLIR.push, reg);
	END;
	LoadAdr(code, i);
	PCLIR.Emit01(code, PCLIR.push, i.adr);
END PushRetDesc;

(** PushRetDesc1 - Allocate temporary and push the return descriptor for items with non-primitive types *)

PROCEDURE PushRetDesc1*(code: Code;  fp: PCT.Symbol);
VAR size: LONGINT;  reg, reg2, temp: PCLIR.Register;
BEGIN
	ASSERT((fp IS PCT.Parameter) & ~fp(PCT.Parameter).ref, 500);
	ASSERT((fp.type IS PCT.Record) OR (fp.type IS PCT.Array)OR (fp.type IS PCT.EnhArray) (* fof *), 501);
	size := GetStaticSize(fp.type) + ((-GetStaticSize(fp.type)) MOD PCLIR.CG.ParamAlign);

(*
	ASSERT(size MOD 4 = 0);
*)
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, size);
	PCLIR.Emit12(code, PCLIR.sub, reg2, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.loadsp, reg2);
	IF fp.type IS PCT.Record THEN
		PCLIR.Emit01(code, PCLIR.push, reg);
		PCLIR.EmitLoadConst(code, temp, PCLIR.Address, FALSE, PCT.AddressSize);
		PCLIR.Emit12(code, PCLIR.add, reg, PCLIR.SP, temp);
		PCLIR.Emit01(code, PCLIR.push, reg)
	ELSE
		PCLIR.Emit01(code, PCLIR.push, PCLIR.SP)
	END;
END PushRetDesc1;

(** PushRetDesc2 - Push the current procedure's return descriptor *)

PROCEDURE PushRetDesc2*(code: Code; proc: PCT.Proc);
	VAR parSize: LONGINT; size, dst: Item;
BEGIN
	parSize := proc.adr(PCBT.Procedure).parsize;
	IF proc.type IS PCT.Record THEN
		size.mode := Var; size.offs := parSize+PCT.AddressSize; size.level := 0; size.type := PCT.Int32;
		dst.mode := Var; dst.offs := parSize; dst.level := 0; dst.type := PCT.Int32;
		Load(code, size); PCLIR.Emit01(code, PCLIR.push, size.adr);
		Load(code, dst); PCLIR.Emit01(code, PCLIR.push, dst.adr)
	ELSIF proc.type IS PCT.Array THEN
		dst.mode := Var; dst.offs := parSize; dst.level := 0; dst.type := PCT.Int32;
		Load(code, dst); PCLIR.Emit01(code, PCLIR.push, dst.adr)
	ELSE
		HALT(99)
	END;
END PushRetDesc2;


(*
	increase stack by number of open dimensions + 1,
	push pointer to base (old SP) onto stack
*)
PROCEDURE PushOpenAryRetDesc*(code: Code; t: PCT.Struct);
VAR
	reg, reg2: PCLIR.Register;
	dims: LONGINT;
BEGIN
	dims := GetDims(t);
	(*
	WHILE (t # NIL) & (t IS PCT.Array) & (t(PCT.Array).mode = PCT.open) DO
		INC(dims);
		t := t(PCT.Array).base;
	END;
	*)
	ASSERT(dims > 0);
	INC(dims);
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, dims*PCT.AddressSize);
	PCLIR.Emit12(code, PCLIR.sub, reg2, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.loadsp, reg2);

	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, dims*PCT.AddressSize);
	PCLIR.Emit12(code, PCLIR.add, reg2, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.push, reg2);
END PushOpenAryRetDesc;

PROCEDURE PushStatAryRetDesc*(code: Code; ary: PCT.Struct);
VAR
	size: LONGINT;
	reg, reg2: PCLIR.Register;
BEGIN
	ASSERT(ary IS PCT.Array);
	ASSERT(ary(PCT.Array).mode = PCT.static);
	size := GetStaticSize(ary)  + ((-GetStaticSize(ary)) MOD 4);
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, size);
	PCLIR.Emit12(code, PCLIR.sub, reg2, PCLIR.SP, reg);
	PCLIR.Emit01(code, PCLIR.loadsp, reg2);
	PCLIR.Emit01(code, PCLIR.push, PCLIR.SP);
END PushStatAryRetDesc;

PROCEDURE PushOpenAryParams*(code: Code; formal, actual: PCT.Struct; VAR ofs: LONGINT; parNbr: LONGINT);
VAR
	dims: LONGINT;
	base, const, reg, len: PCLIR.Register;
BEGIN
	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, ofs);
	PCLIR.Emit12(code, PCLIR.add, base, PCLIR.SP, const);
	WHILE parNbr > 1 DO
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, 0, base);
		DEC(parNbr);
	END;
	dims := 1;
	WHILE (formal # NIL) & (formal IS PCT.Array) & (formal(PCT.Array).mode = PCT.open) DO
		IF actual(PCT.Array).mode = PCT.static THEN
			PCLIR.EmitLoadConst(code, len, PCLIR.Address, FALSE, actual(PCT.Array).len);
		ELSE
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, 0, base);
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, len, -(PCT.AddressSize*dims), reg);
		END;
		PCLIR.Emit01(code, PCLIR.push, len);

		INC(dims);
		formal := formal(PCT.Array).base;
		actual := actual(PCT.Array).base;
	END;
	PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, PCT.AddressSize);
	PCLIR.Emit12(code, PCLIR.add, base, base, const);
	PCLIR.Emit01(code, PCLIR.push, base);
	(* INC(ofs, (dims-1)*PCT.AddressSize + PCT.AddressSize); *)
END PushOpenAryParams;

(** fof >> *)
	PROCEDURE PushResultTensor*( code: Code;  proc: PCT.Proc );
	VAR parSize, size: LONGINT;  src: Item;
	BEGIN
		parSize := proc.adr( PCBT.Procedure ).parsize;  src.mode := Var;
		src.offs := parSize;  src.level := 0;
		src.type := PCT.Int32;   (* type already checked *)
		size := PCT.AddressSize;  LoadAdr( code, src );
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , src.adr, 0, src.adr );
		PCLIR.Emit01( code, PCLIR.push, src.adr );
	END PushResultTensor;

	PROCEDURE WriteBackResultTensor*( code: Code;  proc: PCT.Proc );
	VAR parSize, size: LONGINT;  src, dst: Item;
	BEGIN
		parSize := proc.adr( PCBT.Procedure ).parsize;  dst.mode := Var;
		dst.offs := parSize;  dst.level := 0;
		dst.type := PCT.Int32;   (* type already checked *)
		IF (proc.type IS PCT.EnhArray) & (proc.type( PCT.EnhArray ).mode = PCT.open) THEN
			size := Descr_LenOffs*PCT.AddressSize + proc.type( PCT.EnhArray ).dim * 2 *PCT.AddressSize;
			MakeStackItem( src, proc.type );  CopyBlock( code, dst, src, size );
			RevertStack( code, size );
		ELSIF (proc.type IS PCT.Tensor) THEN
			size := 4;  LoadAdr( code, dst );
			PCLIR.Emit10( code, PCLIR.pop, src.adr, PCLIR.Address ,FALSE);
			PCLIR.EmitStoreRelative( code, 0, dst.adr, src.adr );
		ELSE HALT( 200 );
		END;
	END WriteBackResultTensor;

	PROCEDURE WriteBackResult*( code: Code;  proc: PCT.Proc;  VAR spoffset: LONGINT );
	VAR parSize, offset: LONGINT;  dst: Item;  val: PCLIR.Register;
	BEGIN
		parSize := proc.adr( PCBT.Procedure ).parsize;  dst.mode := Var;
		dst.offs := parSize;  dst.level := 0;
		dst.type := PCT.Int32;   (* type already checked *)
		LoadAdr( code, dst );  offset := 0;
		WHILE (spoffset > 0) DO
			PCLIR.Emit10( code, PCLIR.pop, val, PCLIR.Address , FALSE);
			PCLIR.EmitStoreRelative( code, offset, dst.adr, val );  DEC( spoffset, 4 );
			INC( offset, 4 );
		END;
	END WriteBackResult;

	PROCEDURE PrepStackTensor*( code: Code );
	VAR const: PCLIR.Register;
	BEGIN
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 0 );
		PCLIR.Emit01( code, PCLIR.push, const );
	END PrepStackTensor;

	PROCEDURE PrepStackEnhArray*( code: Code;  formal, actual: PCT.Struct );
	VAR size, dims: LONGINT;  top, topStatic, base, const: PCLIR.Register;
		form, act,t: PCT.Struct;  i: LONGINT;
	BEGIN
		act := actual;  form := formal;  dims := 0;
		WHILE (form # NIL ) & (form IS PCT.EnhArray) &
				    ((form( PCT.EnhArray ).mode = PCT.open)) DO
			IF (act IS PCT.EnhArray) THEN
				IF act( PCT.EnhArray ).mode = PCT.open THEN INC( dims );  END;
				act := act( PCT.EnhArray ).base;
			ELSIF (act IS PCT.Tensor) THEN INC( dims )
			END;
			form := form( PCT.EnhArray ).base;
		END;

		IF dims > 0 THEN
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE ,0);
			FOR i := 1 TO dims  DO
				PCLIR.Emit01( code, PCLIR.push, const );
				PCLIR.Emit01( code, PCLIR.push, const );
			END;
			t := PCT.ElementType(act);
			PCLIR.EmitLoadConst(code,const,PCLIR.Int32,FALSE,t.size(PCBT.Size).size);
			PCLIR.Emit01( code, PCLIR.push, const );

			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , dims );
			PCLIR.Emit01( code, PCLIR.push, const );   (* dimension *)
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE ,
												SYSTEM.VAL( LONGINT, {StackFlag} ) );
			PCLIR.Emit01( code, PCLIR.push, const );   (* flag *)
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 0 );
			PCLIR.Emit01( code, PCLIR.push, const );   (* nil address *)
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 0 );
			PCLIR.Emit01( code, PCLIR.push, const );   (* nil protector  *)
		ELSE
			size := GetStaticSize( actual );  INC( size, (-size) MOD 4 );
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , size );
			PCLIR.Emit12( code, PCLIR.sub, top, PCLIR.SP, const );
			PCLIR.Emit01( code, PCLIR.loadsp, top );
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , size );
			PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, const );
			PCLIR.Emit01( code, PCLIR.push, base );
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 4 );
			PCLIR.Emit12( code, PCLIR.add, topStatic, PCLIR.SP, const );
			PCLIR.Emit01( code, PCLIR.push, topStatic );
		END;
	END PrepStackEnhArray;
(** << fof  *)


PROCEDURE PrepStack*(code: Code; formal, actual: PCT.Struct);
VAR
	size, dims: LONGINT;
	top, topStatic, base, const: PCLIR.Register;
	form, act: PCT.Struct;
BEGIN
	act := actual;
	form := formal;
	dims := 0;
	WHILE (form # NIL) & (form IS PCT.Array) & (form(PCT.Array).mode = PCT.open) DO
		IF act(PCT.Array).mode = PCT.open THEN
			INC(dims);
		END;
		form := form(PCT.Array).base;
		act := act(PCT.Array).base;
	END;
	IF dims > 0 THEN
		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, dims*PCT.AddressSize + PCT.AddressSize);
		PCLIR.Emit12(code, PCLIR.sub, top, PCLIR.SP, const);
		PCLIR.Emit01(code, PCLIR.loadsp, top);
		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, dims*PCT.AddressSize + PCT.AddressSize);
		PCLIR.Emit12(code, PCLIR.add, base, PCLIR.SP, const);
		PCLIR.Emit01(code, PCLIR.push, base);
	ELSE
		size := GetStaticSize(actual);
		INC(size, (-size) MOD 4);
		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, size);
		PCLIR.Emit12(code, PCLIR.sub, top, PCLIR.SP, const);
		PCLIR.Emit01(code, PCLIR.loadsp, top);
		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, size);
		PCLIR.Emit12(code, PCLIR.add, base, PCLIR.SP, const);
		PCLIR.Emit01(code, PCLIR.push, base);
		PCLIR.EmitLoadConst(code, const, PCLIR.Address, FALSE, PCT.AddressSize);
		PCLIR.Emit12(code, PCLIR.add, topStatic, PCLIR.SP, const);
		PCLIR.Emit01(code, PCLIR.push, topStatic);
	END;
END PrepStack;

PROCEDURE FixRetDesc*(code: Code; type: PCT.Struct; openAryParams: LONGINT; VAR ofs: LONGINT);
VAR base, reg: PCLIR.Register;
BEGIN
	IF (openAryParams > 0) & ((type IS PCT.Record) OR (type IS PCT.Array)) THEN
		PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, 0, PCLIR.SP);
		WHILE openAryParams > 1 DO
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, base, 0, base);
			DEC(openAryParams);
		END;
		IF type IS PCT.Record THEN
			PCLIR.EmitLoadRelative(code, PCLIR.Int32, FALSE, reg, PCT.AddressSize, base);	(* size *)
			PCLIR.Emit01(code, PCLIR.push, reg);
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, 0, base);	(* link *)
			PCLIR.Emit01(code, PCLIR.push, reg);
			INC(ofs, PCT.AddressSize*2);
		ELSE
			ASSERT(type IS PCT.Array);
			PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, reg, 0, base);	(* link *)
			PCLIR.Emit01(code, PCLIR.push, reg);
			INC(ofs, PCT.AddressSize);
		END;
	END;
END FixRetDesc;

(**-----------Memory Handling------------------*)

PROCEDURE CopyBlock(code: Code;  VAR dst, src: Item;  size: LONGINT);
VAR reg: PCLIR.Register;
BEGIN
	LoadAdr(code, dst);
	IF ~(src.mode IN {Reg, Const}) THEN
		LoadAdr(code, src); src.mode := RegRel; src.offs := 0
	END;
	IF size = 1 THEN
		src.type := PCT.Int8;
		Load(code, src);
		PCLIR.EmitStoreRelative(code, 0, dst.adr, src.adr)
	ELSIF size = 2 THEN
		src.type := PCT.Int16;
		Load(code, src);
		PCLIR.EmitStoreRelative(code, 0, dst.adr, src.adr)
	ELSIF size = 4 THEN
		src.type := PCT.Int32;
		Load(code, src);
		PCLIR.EmitStoreRelative(code, 0, dst.adr, src.adr)
(*
	ELSIF size = 8 THEN
		src.type := PCT.Int32; src2 := src;
		Load(code, src);
		PCLIR.EmitStoreRelative(code, 0, dst.adr, src.adr);
		src2.offs := 4;
		Load(code, src2);
		PCLIR.EmitStoreRelative(code, 4, dst.adr, src2.adr);
*)
	ELSE
		ASSERT(src.mode IN {Reg, RegRel});	(*don't support const case*)
		src.mode := Reg;	(*undo common case*)
		PCLIR.EmitLoadConst(code, reg, PCLIR.Int32, TRUE, size);
		PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, reg)
	END
END CopyBlock;

PROCEDURE MoveBlock*(code: Code;  VAR dstAdr, srcAdr, size: Item);
BEGIN
	ASSERT(dstAdr.type = PCT.Address);
	ASSERT(srcAdr.type = PCT.Address);
	ASSERT(size.type = PCT.Size);
	Load(code, dstAdr); Load(code, srcAdr); Load(code, size);
	PCLIR.Emit03(code, PCLIR.move, srcAdr.adr, dstAdr.adr, size.adr)
END MoveBlock;

PROCEDURE MoveConvertString(code: Code;  VAR src, dst, size: PCLIR.Register; srcSize, dstSize: PCLIR.Size);
	VAR loop, exit: Label; src1, dst1, size1, val, step: PCLIR.Register;
BEGIN
	IF (srcSize = dstSize) THEN
		PCLIR.Emit03(code, PCLIR.move, src, dst, size)
	ELSE
		PCLIR.Emit01(code, PCLIR.kill, src);
		PCLIR.Emit01(code, PCLIR.kill, dst);
		PCLIR.Emit01(code, PCLIR.kill, size);
		DefLabel(code, loop);
		PCLIR.EmitPhi(code, src, src, none);
		PCLIR.EmitPhi(code, dst, dst, none);
		PCLIR.EmitPhi(code, size, size, none);
		PCLIR.EmitLoadConst(code, step, PCLIR.Int32, TRUE, 0);
		exit := code.pc;
		PCLIR.Emit02C(code, CCTab[ccLE], size, step, -1);
			(* move [dst], [src] with convertion *)
		PCLIR.EmitLoadRelative(code, srcSize, FALSE, val, 0, src);
		PCLIR.EmitConv(code, PCLIR.convu, val, dstSize, FALSE, val);
		PCLIR.EmitStoreRelative(code, 0, dst, val);
			(* inc src pointer *)
		PCLIR.EmitLoadConst(code, step, PCLIR.Address, FALSE, PCLIR.NofBytes(srcSize));
		PCLIR.Emit12(code, PCLIR.add, src1, src, step);
		PCLIR.PatchPhi(code, src, src1);
			(* inc dst pointer *)
		PCLIR.EmitLoadConst(code, step, PCLIR.Address, FALSE, PCLIR.NofBytes(dstSize));
		PCLIR.Emit12(code, PCLIR.add, dst1, dst, step);
		PCLIR.PatchPhi(code, dst, dst1);
			(* dec size *)
		PCLIR.EmitLoadConst(code, step, PCLIR.Address, FALSE, 1);
		PCLIR.Emit12(code, PCLIR.sub, size1, size, step);
		PCLIR.PatchPhi(code, size, size1);
			(* jmp loop *)
		PCLIR.Emit01(code, PCLIR.kill, src1);
		PCLIR.Emit01(code, PCLIR.kill, dst1);
		PCLIR.Emit01(code, PCLIR.kill, size1);
		Jmp(code, loop);
		FixJmp(code, exit)
	END
END MoveConvertString;

PROCEDURE MoveString*(code: Code;  VAR src, dst: Item);	(* copy until 0X *)
(*
	Heuristic: perform move with "LEN(dst)" instead of "LEN(dst)-1", because
	usually array sizes are powers of two (thus move can be optimized)
*)
VAR  srcSize, dstSize, cc, zero: Item;  label, exit: Label; srcElemSize, dstElemSize: PCLIR.Size;
BEGIN
	LoadAdr(code, src);  LoadAdr(code, dst);
	ArrayDim(code, srcSize, src, 0);
	ArrayDim(code, dstSize, dst, 0);
	IF src.type = PCT.String THEN srcElemSize := PCLIR.Int8 ELSE srcElemSize := src.type(PCT.Array).base.size(PCBT.Size).type END;
	IF dst.type = PCT.String THEN dstElemSize := PCLIR.Int8 ELSE dstElemSize := dst.type(PCT.Array).base.size(PCBT.Size).type END;
	IF (srcSize.mode = Const) & (dstSize.mode = Const) THEN	(*static sizes*)
		IF (srcSize.value <= dstSize.value) THEN
			Load(code, srcSize);
			MoveConvertString(code, src.adr, dst.adr, srcSize.adr, srcElemSize, dstElemSize)
(*
			PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, srcSize.adr)
*)
		ELSE
			Load(code, dstSize);
			MoveConvertString(code, src.adr, dst.adr, dstSize.adr, srcElemSize, dstElemSize);
(*
			PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, dstSize.adr);
*)
			PCLIR.EmitLoadConst(code, zero.adr, PCLIR.Int8, FALSE, 0);
			(* i do not understand why EmitStoreRelative puts the wrong register ??? *)
			IF PCM.bigEndian THEN
				PCLIR.EmitStoreRelative(code, dstSize.value-1, dst.adr, zero.adr)
			ELSE
				PCLIR.EmitStoreRelative(code, -1, dst.adr, zero.adr)
			END
		END
	ELSE
		Load(code, srcSize);  Load(code, dstSize);
		cc := srcSize;
		RelOp(code, PCS.gtr, cc, dstSize);
		label := -1;  Jcc(code, label, cc);
			(*src <= dst *)
		MoveConvertString(code, src.adr, dst.adr, srcSize.adr, srcElemSize, dstElemSize);
(*
		PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, srcSize.adr);
*)
		exit := -1;  Jmp(code, exit);
		FixJmp(code, label);  PCLIR.Emit0C(code, PCLIR.label, 0);
			(* src > dst *)
		MoveConvertString(code, src.adr, dst.adr, dstSize.adr, srcElemSize, dstElemSize);
(*
		PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, dstSize.adr);
*)
		(* the same problem as above, but here a fix is not easy, so i leave this as an error in the compiler for
		big endian machines. this means: be careful when using the COPY proc *)
		IF ~PCM.bigEndian THEN
			PCLIR.EmitLoadConst(code, zero.adr, PCLIR.Int8, FALSE, 0);
			PCLIR.EmitStoreRelative(code, -1, dst.adr, zero.adr);
		END;
		FixJmp(code, exit);  PCLIR.Emit0C(code, PCLIR.label, 0);
	END
(*
	IF (dstElemSize # PCLIR.Int8) OR (srcElemSize # PCLIR.Int8) THEN
		Load(code, srcSize);
		MoveConvertString(code, srcSize.adr, src.adr, dst.adr, srcElemSize, dstElemSize)
	ELSE
		IF (srcSize.mode = Const) & (dstSize.mode = Const) THEN	(*static sizes*)
			IF (srcSize.value <= dstSize.value) THEN
				Load(code, srcSize);
				PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, srcSize.adr)
			ELSE
				Load(code, dstSize);
				PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, dstSize.adr);
				PCLIR.EmitLoadConst(code, zero.adr, PCLIR.Int8, FALSE, 0);
				PCLIR.EmitStoreRelative(code, -1, dst.adr, zero.adr)
			END
		ELSE
			Load(code, srcSize);  Load(code, dstSize);
			cc := srcSize;
			RelOp(code, PCS.gtr, cc, dstSize);
			label := -1;  Jcc(code, label, cc);
				(*src <= dst *)
			PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, srcSize.adr);
			exit := -1;  Jmp(code, exit);
			FixJmp(code, label);  PCLIR.Emit0C(code, PCLIR.label, 0);
				(* src > dst *)
			PCLIR.Emit03(code, PCLIR.move, src.adr, dst.adr, dstSize.adr);
			PCLIR.EmitLoadConst(code, zero.adr, PCLIR.Int8, FALSE, 0);
			PCLIR.EmitStoreRelative(code, -1, dst.adr, zero.adr);

			FixJmp(code, exit);  PCLIR.Emit0C(code, PCLIR.label, 0);
		END
	END
*)
END MoveString;

PROCEDURE GetHWReg*(code: Code;  VAR x: Item;  reg: SHORTINT);
BEGIN
	LoadAdr(code,x);
	PCLIR.EmitStoreRelative(code, 0, x.adr, PCLIR.HwReg-reg);
END GetHWReg;

PROCEDURE SetHWReg*(code: Code;  VAR x: Item;  reg: SHORTINT);
BEGIN
	Load(code, x);
	PCLIR.EmitStoreReg(code, PCLIR.HwReg-reg, x.adr);
END SetHWReg;

PROCEDURE GetMemory*(code: Code;  VAR adr: Item;  type: PCT.Struct);
BEGIN
	ASSERT(adr.type = PCT.Address);
	Load(code, adr);
	adr.mode := RegRel; adr.offs := 0; adr.type := type;
	Load(code, adr);	(* projection could change the type and thus the move width! *)
END GetMemory;

PROCEDURE WriteHWPort*(code: Code;  VAR x, y: Item);	(** Write y to port x *)
BEGIN
	Load(code, x);
	Load(code, y);
	PCLIR.Emit02(code, PCLIR.out, x.adr, y.adr)
END WriteHWPort;

PROCEDURE ReadHWPort*(code: Code;  VAR x, y: Item);	(** Read y from port x *)
VAR  reg: PCLIR.Register; size: PCBT.Size;
BEGIN
	size := y.type.size(PCBT.Size);
	Load(code, x);
	PCLIR.EmitConv(code, PCLIR.in, reg, size.type, size.signed, x.adr);
	LoadAdr(code, y);
	PCLIR.EmitStoreRelative(code, 0, y.adr, reg)
END ReadHWPort;

(**-----------Boolean Expressions----------------*)

(* InitCC - Create condition code item *)

PROCEDURE InitCC(VAR a: Item; cc: LONGINT; r1, r2: PCLIR.Register);
BEGIN
	a.mode := CC;  a.adr := cc;
	a.value := r1; a.breg := r2;
	a.tlist := none;  a.flist := none;
	a.type := PCT.Bool
END InitCC;

(* LoadCC - load condition into a register *)

PROCEDURE LoadCC(code: Code; VAR a: Item);
VAR	t, f, end: LONGINT;
BEGIN
	ASSERT(a.mode = CC, 110);
	IF (a.tlist = none) & (a.flist = none) THEN	(*no jump links*)
		ASSERT(a.adr # 0);
		ASSERT(a.adr # ccAlways);
		PCLIR.Emit12Sized(code, SetCCTab[a.adr], a.adr, PCLIR.Int8, a.value, a.breg)
	ELSE
		IF a.adr # ccNone THEN
			PCLIR.Emit02C(code, InvCCTab[a.adr], a.value, a.breg, a.flist); a.flist := code.pc -1
		END;
		FixJmp(code, a.tlist);
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		PCLIR.Emit01(code, PCLIR.kill, t);
		end := code.pc;  PCLIR.Emit0C(code, PCLIR.jmp, none);	(*jump to end*)
		FixJmp(code, a.flist);
		PCLIR.EmitLoadConst(code, f, PCLIR.Int8, FALSE, False);
		PCLIR.Emit01(code, PCLIR.kill, f);
		FixJmp(code, end);
		PCLIR.EmitPhi(code, a.adr, t, f)
	END;
	a.mode := Reg
END LoadCC;

(** CondOr - Prepare conditional OR *)

PROCEDURE CondOr*(code: Code; VAR a: Item);
VAR t: LONGINT; jcc: PCLIR.Opcode;
BEGIN
	IF a.mode = CC THEN
		jcc := CCTab[a.adr]
	ELSE
		ASSERT(a.type = PCT.Bool);
		Load(code, a);
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		InitCC(a, ccEQ, a.adr, t); jcc := PCLIR.je
	END;
	IF a.adr # ccNone THEN
		PCLIR.Emit02C(code, jcc, a.value, a.breg, a.tlist); a.tlist := code.pc -1
	END;
	FixJmp(code, a.flist);
	ASSERT(a.flist = none, 220);
END CondOr;

(** CondOr - Conditional OR *)

PROCEDURE Or*(code: Code; VAR a, b: Item);
VAR t, tlist: LONGINT;
BEGIN
	ASSERT(a.mode = CC);
	ASSERT(a.flist = none, 200);
	tlist := a.tlist;
	IF b.mode # CC THEN
		Load(code, b);
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		InitCC(a, ccEQ, b.adr, t)
	ELSE
		a := b;
	END;
	a.tlist := PCLIR.MergeList(code, tlist, a.tlist);
END Or;

(** CondAnd - Prepare Conditional AND *)

PROCEDURE CondAnd*(code: Code; VAR a: Item);
VAR t: LONGINT; jcc: PCLIR.Opcode;
BEGIN
	IF a.mode = CC THEN
		jcc := InvCCTab[a.adr]
	ELSE
		ASSERT(a.type = PCT.Bool);
		Load(code, a);
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		InitCC(a, ccNE, a.adr, t); jcc := PCLIR.jne
	END;
	IF a.adr # ccNone THEN
		PCLIR.Emit02C(code, jcc, a.value, a.breg, a.flist); a.flist := code.pc -1
	END;
	FixJmp(code, a.tlist);
	ASSERT(a.tlist = none, 220);
END CondAnd;

(** And - Conditional AND *)

PROCEDURE And*(code: Code; VAR a, b: Item);
VAR t, flist: LONGINT;
BEGIN
	ASSERT(a.mode = CC);
	ASSERT(a.tlist = none, 200);
	flist := a.flist;
	IF b.mode # CC THEN
		Load(code, b);
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		InitCC(a, ccEQ, b.adr, t)
	ELSE
		a := b
	END;
	a.flist := PCLIR.MergeList(code, flist, a.flist)
END And;

(**-----------Numeric Expressions----------------*)


PROCEDURE MOp*(code: Code;  f: LONGINT;  VAR a: Item);
VAR  reg: PCLIR.Register;  label: Label;  size: PCBT.Size;
BEGIN
	ASSERT(a.mode # Const, 1000);
	CASE f OF
	|  setfn:
			ASSERT(PCT.IsCardinalType(a.type), setfn*10);
			Load(code, a);
			GenConv(code, PCLIR.convs, a, PCLIR.Set, FALSE);
			PCLIR.EmitLoadConst(code, reg, PCLIR.Set, FALSE, 0);
			PCLIR.Emit12(code, PCLIR.bts, a.adr, reg, a.adr);
			a.type := PCT.Set
	|  absfn:
			Load(code, a);
			PCLIR.Emit11(code, PCLIR.abs, a.adr, a.adr)
	|  capfn:
			ASSERT(a.type = PCT.Char8);
			Load(code, a);
			PCLIR.EmitLoadConst(code, reg, PCLIR.Int8, FALSE, 5FH);
			PCLIR.Emit12(code, PCLIR.and, a.adr, a.adr, reg);
	|  oddfn:
			ASSERT(PCT.IsCardinalType(a.type), oddfn);
			size := a.type.size(PCBT.Size);
			Load(code, a);
			PCLIR.EmitLoadConst(code, reg, size.type, size.signed, 1H);
			PCLIR.Emit12(code, PCLIR.and, a.adr, a.adr, reg);
			PCLIR.EmitLoadConst(code, reg, size.type, size.signed, 1H);
			InitCC(a, ccEQ, a.adr, reg);
	| PCS.minus:
			Load(code, a);
			IF PCT.IsCardinalType(a.type) OR PCT.IsFloatType(a.type) THEN
				PCLIR.Emit11(code, PCLIR.neg, a.adr, a.adr)
			ELSIF a.type = PCT.Set THEN
				PCLIR.Emit11(code, PCLIR.not, a.adr, a.adr)
			ELSE
				HALT(99)
			END
	| PCS.not:
			ASSERT(a.type = PCT.Bool);
			IF a.mode = CC THEN
				a.adr := InvCC[a.adr];
				label := a.flist; a.flist := a.tlist; a.tlist := label
			ELSE
				Load(code, a);
				PCLIR.EmitLoadConst(code, reg, PCLIR.Int8, FALSE, False);
				InitCC(a, ccEQ, a.adr, reg)
			END
	END
END MOp;
(** fof >> *)
(*
	PROCEDURE MinMax*( code: Code;  f: LONGINT;  VAR a, b: Item );
	VAR fc: SHORTINT;  temp: PCLIR.Register;  label: LONGINT;  size: PCBT.Size;  cc: Item;
	BEGIN
		IF f = PCS.lss THEN fc := PCLIR.jlt
		ELSIF f = PCS.gtr THEN fc := PCLIR.jgt
		ELSE HALT( 100 );
		END;

		Load( code, a );  Load( code, b );
		PCLIR.Emit02C( code, fc, a.adr, b.adr, none );
		label := code.pc - 1;
		size := a.type.size( PCBT.Size );
		PCLIR.EmitLoadConst( code, temp, size.type, size.signed, 0 );
		PCLIR.Emit12( code, PCLIR.add, a.adr, b.adr, temp );

		PCLIR.FixList( code, label, code.pc );  PCLIR.Emit0C( code, PCLIR.label, 0 );

		PCLIR.Emit01( code, PCLIR.kill, a.adr );
		PCLIR.Emit01( code, PCLIR.kill, b.adr );
	END MinMax;
*)

	PROCEDURE MinMax*( code: Code;  fcc: LONGINT;  VAR a, b: Item );
	VAR fc: SHORTINT; label,end: LONGINT; size: PCBT.Size;reg: LONGINT;
	BEGIN
		IF fcc = PCS.lss THEN fc := PCLIR.jlt
		ELSIF fcc = PCS.gtr THEN fc := PCLIR.jgt
		ELSE HALT( 100 );
		END;
		(* this ugly and complicated thing is needed for compatibility with types such as LONGREAL *)
		(* if done more directly the comparison changes the value of a.adr or does not work at all - has to do with stack-machine nature of the FPU *)
		Load( code, a );  Load( code, b );
		PCLIR.Emit01(code, PCLIR.push, a.adr);
		PCLIR.Emit01(code, PCLIR.push, b.adr);
		(* now reload a and b...*)
		b.adr := PCLIR.SP;
		size := b.type.size( PCBT.Size );
		b.offs := 0;
		b.mode := RegRel;
		Load(code,b);
		a.adr := PCLIR.SP;
		size := a.type.size( PCBT.Size );
		a.offs := size.size;
		a.mode := RegRel;
		Load(code,a);
		label := code.pc ; PCLIR.Emit02C( code, fc, a.adr, b.adr, none );  (* condition fulfilled, jump to fulfilled section *)
		(* not fulfilled  >>> *)
		(* reload a, might be destroyed by comparison *)
		a.adr := PCLIR.SP;
		size := a.type.size( PCBT.Size );
		a.offs := 0;
		a.mode := RegRel;
		Load(code,a);
		PCLIR.Emit01( code, PCLIR.kill, a.adr );
		end := code.pc;  PCLIR.Emit0C(code, PCLIR.jmp, none);	(*jump to end*)
		(* <<< not fulfilled  *)
		FixJmp(code, label);
		(* fulfilled  >>>*)
		(* load a from stack position of b *)
		a.adr := PCLIR.SP;
		size := a.type.size( PCBT.Size );
		a.offs := size.size;
		a.mode := RegRel;
		Load(code,a);
		(*
		KernelLog.String("size="); KernelLog.Int(size.size,10); KernelLog.Ln;
		*)
		PCLIR.Emit01( code, PCLIR.kill, a.adr );
		(*<<< fulfilled *)
		FixJmp(code,end);
		PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, 2*size.size);
		PCLIR.Emit12(code, PCLIR.add, reg, PCLIR.SP, reg);
		PCLIR.Emit01(code, PCLIR.loadsp, reg);
	END MinMax;

	PROCEDURE Swap*( code: Code;  VAR a, b: Item );
	VAR da, db: Item;
	BEGIN
		da := a;  db := b;  Load( code, a );  Load( code, b );  Assign( code, da, b );
		Assign( code, db, a );
	END Swap;
(** << fof  *)

PROCEDURE DOp*(code: Code;  f: LONGINT;  VAR a, b: Item);
VAR reg: PCLIR.Register;  op: PCLIR.Opcode;  exp: LONGINT;

	PROCEDURE PowerOf2(val: LONGINT;  VAR exp: LONGINT): BOOLEAN;
	BEGIN
		IF val <= 0 THEN  RETURN FALSE END;
		exp := 0;
		WHILE ~ODD(val) DO
			val := val DIV 2;
			INC(exp)
		END;
		RETURN val = 1
	END PowerOf2;

BEGIN
	IF (a.mode = Const) & (b.mode = Const) THEN	(*just in case*)
		CASE f OF
		| PCS.minus:  a.value := a.value - b.value
		| PCS.plus: a.value := a.value + b.value
		| PCS.times: a.value := a.value * b.value
		| PCS.div: a.value := a.value DIV b.value
		| PCS.mod: a.value := a.value MOD b.value
		END;
		RETURN
	END;
	CASE f OF
	|  setfn:
			ASSERT(PCT.IsCardinalType(a.type), setfn*10);
			ASSERT(PCT.IsCardinalType(b.type), setfn*10+1);
			IF a.mode = Const THEN
				MakeIntConst(a, LSH(LONG(LONG(-1)), a.value), PCT.Set);
				Load(code, a)
			ELSE
				IF a.mode # Reg THEN  Load(code, a)  END;
				PCLIR.EmitLoadConst(code, reg, PCLIR.Set, FALSE, -1);
				GenConv(code, PCLIR.copy, a, PCLIR.Int8, TRUE);
				PCLIR.Emit12(code, PCLIR.bsh, a.adr, reg, a.adr);	(* 11111111 -> 11111100 *)
				a.type := PCT.Set
			END;
			IF b.mode = Const THEN
				MakeIntConst(b, LSH(LONG(LONG(-1)), b.value-(PCT.SetSize*8 - 1)), PCT.Set);
				Load(code, b)
			ELSE
				IF b.mode # Reg THEN  Load(code, b)  END;
				GenConv(code, PCLIR.copy, b, PCLIR.Int8, TRUE);
				PCLIR.EmitLoadConst(code, reg, PCLIR.Int8, TRUE, PCT.SetSize*8 - 1);
				PCLIR.Emit12(code, PCLIR.sub, b.adr, b.adr, reg);
				PCLIR.EmitLoadConst(code, reg, PCLIR.Set, FALSE, -1);
				PCLIR.Emit12(code, PCLIR.bsh, b.adr, reg, b.adr);
				b.type := PCT.Set
			END;
			op := PCLIR.and
	|  ashfn:
			Convert(code, b, PCT.Int8, FALSE);
			op := PCLIR.ash
	|  lshfn:
			Convert(code, b, PCT.Int8, FALSE);
			op := PCLIR.bsh
	|  rotfn:
			Convert(code, b, PCT.Int8, FALSE);
			op := PCLIR.rot
	|  PCS.minus:
			IF a.type = PCT.Set THEN
				Load(code, b);
				PCLIR.Emit11(code, PCLIR.not, b.adr, b.adr);
				op := PCLIR.and
			ELSE
				op := PCLIR.sub
			END
	|  PCS.plus:
			IF a.type = PCT.Set THEN
				op := PCLIR.or
			ELSE
				op := PCLIR.add
			END
	|  PCS.times:
			IF a.type = PCT.Set THEN
				op := PCLIR.and
			ELSIF (b.mode = Const) & PowerOf2(b.value, exp) THEN
				IF exp = 0 THEN  RETURN  END;	(* x * 1 *)
				MakeIntConst(b, exp, PCT.Char8);
				op := PCLIR.ash
			ELSIF (a.mode = Const) & PowerOf2(a.value, exp) THEN
				a := b;	(*swap*)
				IF exp = 0 THEN  RETURN  END;
				MakeIntConst(b, exp, PCT.Char8);
				op := PCLIR.ash
			ELSE
				op := PCLIR.mul
			END
	|  PCS.div:
			IF (b.mode = Const) & PowerOf2(b.value, exp) THEN
				IF exp = 0 THEN  RETURN  END;	(* x DIV 1 *)
				MakeIntConst(b, -exp, PCT.Char8);
				op := PCLIR.ash
			ELSE
				op := PCLIR.div
			END
	|  PCS.slash:
			IF a.type = PCT.Set THEN
				op := PCLIR.xor
			ELSE
				op := PCLIR.div
			END
	|  PCS.mod:
			IF (b.mode = Const) & PowerOf2(b.value, exp) THEN
				MakeIntConst(b, b.value-1, a.type);
				op := PCLIR.and
			ELSE
				op := PCLIR.mod
			END
	END;
	IF a.mode # Reg THEN  Load(code, a)  END;
	IF b.mode # Reg THEN  Load(code, b)  END;
	PCLIR.Emit12(code, op, a.adr, a.adr, b.adr)
END DOp;

PROCEDURE StringCmp(code: Code; cc: SHORTINT;  VAR cond: Item;  a, b: Item);
VAR  aval, bval, abase, bbase, abase2, bbase2, zero, one, loop, pc: LONGINT;  cctrue, ccfalse: SHORTINT;
BEGIN
	ASSERT(a.mode # Reg, 200);
	ASSERT(b.mode # Reg, 201);
	ASSERT(cc IN {ccEQ, ccNE, ccB, ccBE, ccA, ccAE}, 202);
	cctrue := 0;  ccfalse := 0;
	CASE  cc  OF
	|  ccB, ccBE:
			cctrue := ccB; ccfalse := ccA
	|  ccA, ccAE:
			cctrue := ccA; ccfalse := ccB
	|  ccEQ:
			ccfalse := ccNE
	|  ccNE:
			cctrue := ccNE
	END;

	LoadAdr(code, a);  abase := a.adr;
	LoadAdr(code, b);  bbase := b.adr;
	InitCC(cond, ccNone, none, none);

	PCLIR.Emit01(code, PCLIR.kill, abase);
	PCLIR.Emit01(code, PCLIR.kill, bbase);
	DefLabel(code, loop);
	PCLIR.EmitPhi(code, abase, abase, none);
	PCLIR.EmitPhi(code, bbase, bbase, none);
	PCLIR.EmitLoadRelative(code, PCLIR.Int8, FALSE, aval, 0, abase);
	PCLIR.EmitLoadRelative(code, PCLIR.Int8, FALSE, bval, 0, bbase);

	IF cctrue # 0 THEN
		cond.tlist := code.pc;
		PCLIR.Emit02C(code, CCTab[cctrue], aval, bval, none);	(* Jcc  true *)
	END;
	IF ccfalse # 0 THEN
		cond.flist := code.pc;
		PCLIR.Emit02C(code, CCTab[ccfalse], aval, bval, none);	(* Jcc  false *)
	END;
	PCLIR.EmitLoadConst(code, zero, PCLIR.Int8, FALSE, 0);
	pc := code.pc;
	IF cc IN {ccEQ, ccAE, ccBE} THEN
		PCLIR.Emit02C(code, CCTab[ccEQ], aval, zero, cond.tlist);	(* JE  true *)
		cond.tlist := pc
	ELSE
		PCLIR.Emit02C(code, CCTab[ccEQ], aval, zero, cond.flist);	(*JE false*)
		cond.flist := pc
	END;
	PCLIR.EmitLoadConst(code, one, PCLIR.Address, FALSE, 1);
	PCLIR.Emit12(code, PCLIR.add, abase2, abase, one);
	PCLIR.EmitLoadConst(code, one, PCLIR.Address, FALSE, 1);
	PCLIR.Emit12(code, PCLIR.add, bbase2, bbase, one);
	PCLIR.PatchPhi(code, abase, abase2);
	PCLIR.PatchPhi(code, bbase, bbase2);
	PCLIR.Emit01(code, PCLIR.kill, abase2);
	PCLIR.Emit01(code, PCLIR.kill, bbase2);
	PCLIR.Emit0C(code, PCLIR.jmp, loop);
END StringCmp;

PROCEDURE RelOp*(code: Code; operand: LONGINT; VAR a, b: Item);
VAR  cc: SHORTINT;  string: BOOLEAN;  list: Label;
BEGIN
	IF operand = bitfn THEN
		Convert(code, a, PCT.Int32, FALSE);
		Load(code, a);
		a.mode := RegRel;
		a.offs := 0;
		Load(code, a);
		Convert(code, b, PCT.Int32, TRUE);
		Load(code, b);
		InitCC(a, ccF, a.adr, b.adr)
	ELSIF operand = PCS.in THEN
		ASSERT(a.type = PCT.SetType);
		Load(code, a); Load(code, b);
		InitCC(a, ccF, b.adr, a.adr)
	ELSIF (a.type IS PCT.Delegate) & (b.type IS PCT.Delegate) & ~(PCT.StaticMethodsOnly IN a.type.flags) & ~(PCT.StaticMethodsOnly IN b.type.flags) THEN
		Load(code, a);
		Load(code, b);
		PCLIR.Emit02C(code, PCLIR.jne, a.adr, b.adr, none); list := code.pc - 1;
		IF operand = PCS.eql THEN
			InitCC(a, ccEQ, a.breg, b.breg); a.flist := list
		ELSE
			ASSERT(operand = PCS.neq);
			InitCC(a, ccNE, a.breg, b.breg); a.tlist := list
		END
	ELSE
		string := IsString(a.type) & IsString(b.type);
		IF PCT.IsCharType(a.type) OR string THEN	(*unsigned compare*)
			CASE operand OF
			| PCS.eql:  cc := ccEQ
			| PCS.neq:  cc := ccNE
			| PCS.lss:  cc := ccB
			| PCS.leq:  cc := ccBE
			| PCS.gtr:  cc := ccA
			| PCS.geq:  cc := ccAE
			ELSE HALT(99)
			END
		ELSE
			CASE operand OF
			| PCS.eql:  cc := ccEQ
			| PCS.neq:  cc := ccNE
			| PCS.lss:  cc := ccLT
			| PCS.leq:  cc := ccLE
			| PCS.gtr:  cc := ccGT
			| PCS.geq:  cc := ccGE
			ELSE HALT(99)
			END
		END;
		IF string THEN
			StringCmp(code, cc, a, a, b)
		ELSE
			Load(code, a); Load(code, b);
			InitCC(a, cc, a.adr, b.adr)
		END
	END;
	a.type := PCT.Bool
END RelOp;

(** Convert x to type. typeOnly: change type but not value (SYSTEM.VAL) *)

PROCEDURE Convert*(code: Code;  VAR x: Item;  type: PCT.Struct;  typeOnly: BOOLEAN);
VAR  size: PCBT.Size;
BEGIN
	size := type.size(PCBT.Size);
	IF x.type = type THEN
		(*nothing to do*)
	ELSIF x.mode = Const THEN
		(*nothing to do*)
	ELSIF typeOnly THEN
		IF x.mode = Reg THEN
			GenConv(code, PCLIR.copy, x, size.type, size.signed)
		END;
		IF type IS PCT.Delegate THEN
			IF x.mode # Reg THEN Load(code, x) END;	(*prepare value for assign*)
			IF ~(PCT.StaticMethodsOnly IN type.flags) THEN PCLIR.EmitLoadConst(code, x.breg, PCLIR.Address, FALSE, Nil) END
		END
	ELSIF PCT.IsCardinalType(x.type) OR PCT.IsFloatType(x.type) THEN
		IF x.mode # Reg THEN  Load(code, x)  END;
		GenConv(code, PCLIR.convs, x, size.type, size.signed)
	ELSIF PCM.LocalUnicodeSupport & PCT.IsCharType(x.type) THEN
		IF type = PCT.Byte THEN
			(*skip*)
		ELSIF PCT.IsCardinalType(type) OR PCT.IsCharType(type) THEN
			IF x.mode # Reg THEN  Load(code, x)  END;
			GenConv(code, PCLIR.convu, x, size.type, size.signed)
		ELSE
			PCDebug.ToDo(PCDebug.NotImplemented)
		END
	ELSIF ~PCM.LocalUnicodeSupport & (x.type = PCT.Char8) THEN
		IF PCT.IsCardinalType(type) THEN
			IF GetStaticSize(type) > 1 THEN
				IF x.mode # Reg THEN  Load(code, x)  END;
				GenConv(code, PCLIR.convu, x, size.type, size.signed)
			END
		ELSIF type = PCT.Byte THEN
			(*skip*)
		ELSE
			PCDebug.ToDo(PCDebug.NotImplemented)
		END
	ELSIF (x.type = PCT.Byte) THEN
		IF type = PCT.Char8 THEN
			(*skip*)
		ELSIF PCT.IsCardinalType(type) THEN
			IF x.mode # Reg THEN  Load(code, x)  END;
			GenConv(code, PCLIR.convu, x, size.type, size.signed)
		ELSE
			PCDebug.ToDo(PCDebug.NotImplemented)
		END
	ELSIF PCT.IsPointer(x.type)  THEN
		(*nothing to do. PCB checked that the convertion is allowed*)
	ELSE
(*
PCM.LogWLn; PCM.LogWStr("PCC.Convert: ConvFailed "); PCM.LogWStr(x.type.owner.name);
PCM.LogWStr(" -> "); PCM.LogWStr(type.owner.name);
*)
		PCLIR.Emit00(code, PCLIR.nop);
		PCDebug.ToDo(PCDebug.NotImplemented);
	END;
	x.type := type
END Convert;

(**-----------Designators----------------*)
PROCEDURE Deref*(code: Code; VAR x: Item);
VAR ptr: PCT.Pointer; arr: PCT.Array;
BEGIN
	ptr := x.type(PCT.Pointer);
	NilCheck(code, x);
	IF ptr.baseR # NIL (* IS Record *) THEN
		Load(code, x);
		x.mode := RegRel;  x.offs := 0;  x.type := ptr.baseR;
	ELSIF ptr.baseA # NIL (* IS Array *) THEN
			arr := ptr.baseA;
			Load(code, x);
			x.mode := RegRel;
			x.breg := x.adr;
			IF arr.mode = PCT.open THEN
				x.boffs := ArrayFirstElem * PCT.AddressSize + arr.opendim * PCLIR.CG.ParamAlign;	(*array dimensions*)
			ELSE
				ASSERT(arr.mode = PCT.static);
				x.boffs := ArrayFirstElem * PCT.AddressSize + PCLIR.CG.ParamAlign;
			END;
			x.offs := x.boffs+PCLIR.CG.ParamAlign;  INC(x.offs, (-x.offs) MOD 8);	(* x.offs MOD 8 = 0 *)
			x.type := arr;
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented);
	END;
	x.deref := TRUE
END Deref;

(** fof >> *)
	PROCEDURE Range*( code: Code;  rangeover: PCT.EnhArray;   VAR descr, x, from, to, by: Item;  dim: LONGINT );   (* called by PCB.Range.Emit *)
	VAR type: PCT.EnhArray;  mode: SHORTINT;  one, inc: Item;  oldby: Item;

		PROCEDURE CheckUpper( code: Code;  VAR x, index: Item );
		VAR bound: Item;  type: PCT.EnhArray;  mode: SHORTINT;  label: Label;
		BEGIN
			type := x.type( PCT.EnhArray );  mode := type.mode;

			IF (mode = PCT.static) THEN
				IF index.mode = Const THEN RETURN END;   (*statically checked*)
				MakeSizeConst( bound, type.len )
			ELSE
				ASSERT ( mode = PCT.open );
				bound.mode := RegRel;  bound.adr := descr.adr;
				bound.offs := Descr_LenOffs*PCT.AddressSize + 8 * dim;  bound.type := PCT.Int32;
			END;
			Load( code, index );
			Load( code, bound );
			label := code.pc;
			PCLIR.Emit02C( code, PCLIR.jlt, index.adr, bound.adr, none );
			PCLIR.Emit0C( code, PCLIR.trap, PCM.IndexCheckTrap );
			FixJmp( code, label );
		END CheckUpper;

		PROCEDURE CheckLower( code: Code;  VAR index: Item );
		VAR bound: Item;  label: Label;
		BEGIN
			IF (mode = PCT.static) & (index.mode = Const) THEN RETURN END;   (*statically checked*)
			MakeSizeConst( bound, 0 );
			Load( code, index );  Load( code, bound );
			label := code.pc;
			PCLIR.Emit02C( code, PCLIR.jge, index.adr, bound.adr, none );
			PCLIR.Emit0C( code, PCLIR.trap, PCM.IndexCheckTrap );
			FixJmp( code, label );
		END CheckLower;

		PROCEDURE BoundToZero( code: Code;  VAR x: Item );
		VAR bound: Item;  label: Label;
		BEGIN
			IF x.mode = Const THEN
				IF x.value < 0 THEN x.value := 0 END;
			ELSE
				MakeSizeConst( bound, 0);  Load( code, bound );
				Load( code, x );  label := code.pc;
				PCLIR.Emit02C( code, PCLIR.jge, x.adr, bound.adr, none );
				PCLIR.Emit12( code, PCLIR.xor, x.adr, x.adr, x.adr );
				FixJmp( code, label );
			END;
		END BoundToZero;

	BEGIN
		ASSERT ( x.type IS PCT.EnhArray, 200 );
		ASSERT ( from.type = PCT.Int32, 201 );
		type := x.type( PCT.EnhArray );  mode := type.mode;
		IF mode IN {PCT.static, PCT.open} THEN  (* static or dynamic array, not semi-dynamic *)
			ASSERT ( x.mode IN {Abs, Var, Ref, RegRel, Const, Reg}, 202 );

			IF x.mode # Reg THEN LoadAdr( code, x );
			END;
			MakeSizeConst( one, 1 );
			IF (to.mode = Const) & (to.value = MAX( LONGINT )) THEN
				EnhArrayLen( code, to, descr, dim );  Load( code, to );
			ELSE
				IF (to.mode # Reg) & (to.mode # Const) THEN Load( code, to ) END;
					IF PCM.ArrayCheck IN PCM.codeOptions THEN
					CheckUpper( code, x, to );
				END;
				DOp( code, PCS.plus, to, one );
			END;
			IF PCM.ArrayCheck IN PCM.codeOptions THEN
				CheckLower( code, from );
			END;

			IF (from.mode # Reg) & (from.mode # Const) THEN Load( code, from )
			END;
			IF (from.mode # Const) OR (from.value # 0) THEN
				DOp( code, PCS.minus, to, from );
			END;

			IF (by.mode # Const) OR (by.value # 1) THEN
				oldby := by;   (* might get modified in DOp, this is NOT nice*)
				DOp( code, PCS.minus, to, one );  DOp( code, PCS.div, to, by );
				DOp( code, PCS.plus, to, one );   (* n= (len-1) / by + 1 *)
				by := oldby;
			END;

			IF (rangeover.mode = PCT.static) THEN
				MakeSizeConst( inc, rangeover.inc );
			ELSE
				inc.mode := RegRel;  inc.adr := descr.adr;
				inc.offs := Descr_IncOffs*PCT.AddressSize + 2 * PCT.AddressSize * dim;  inc.type := PCT.Int32;
				Load( code, inc );
			END;

			IF ((inc.mode # Const) OR (inc.value # 1)) &
			    ((from.mode # Const) OR (from.value # 0)) THEN
				DOp( code, PCS.times, from, inc );
			END;
			IF (from.mode # Const) OR (from.value # 0) THEN
				DOp( code, PCS.plus, x, from );
			END;

			IF (by.mode # Const) OR (by.value # 1) THEN
				DOp( code, PCS.times, inc, by );  by := inc;
			ELSE by := inc;
			END;
			IF inc.mode # Reg THEN Load( code, inc );  END;
			PCLIR.Emit01( code, PCLIR.push, inc.adr );   (* inc *)

			BoundToZero( code, to );
			IF to.mode # Reg THEN Load( code, to ) END;
			PCLIR.Emit01( code, PCLIR.push, to.adr );   (* new length *)

			x.mode := RegRel;  x.offs := 0;   (* x.type := type.base; *)
			DEC( x.boffs, 2 * PCT.AddressSize );
		ELSE PCDebug.ToDo( PCDebug.NotImplemented );
		END;
		x.deref := FALSE;
		ASSERT ( x.mode = RegRel, 220 );
	END Range;

	PROCEDURE EIndex*( code: Code;  VAR descr, x, index: Item;  dim: LONGINT (*useInc: BOOLEAN*) );   (* called by PCB.Index.Emit *)
	(* here an additional switch (useInc) can help to optimize w.r.t. fixed increments *)
	VAR type: PCT.EnhArray;  mode: SHORTINT;  inc: Item;

		PROCEDURE IndexCheck( code: Code; VAR index: Item );
		VAR bound: Item;  type: PCT.EnhArray;  mode: SHORTINT;
		BEGIN
			type := x.type( PCT.EnhArray );  mode := type.mode;

			IF (mode = PCT.static) THEN
				IF index.mode = Const THEN RETURN END;   (*statically checked*)
			END;

			EnhArrayLen(code,bound,descr,dim);

			Load( code, index );
			Load( code, bound );
			PCLIR.Emit02C( code, PCLIR.tae, index.adr, bound.adr,  PCM.IndexCheckTrap )

		END IndexCheck;

	BEGIN
		ASSERT ( x.type IS PCT.EnhArray, 200 );
		ASSERT ( index.type = PCT.Int32, 201 );
		type := x.type( PCT.EnhArray );  mode := type.mode;
		IF mode IN {PCT.static, PCT.open} THEN
			ASSERT ( x.mode IN {Abs, Var, Ref, RegRel, Const, Reg}, 202 );
			IF x.mode # Reg THEN LoadAdr( code, x ) END;

			IF PCM.ArrayCheck IN PCM.codeOptions THEN IndexCheck( code, index ) END;

			IF (index.mode # Reg) & (index.mode # Const) THEN
				Load( code, index );
			END;

			EnhArrayInc(code,inc,descr,dim);
			DOp( code, PCS.times, index, inc );
			IF index.mode # Reg THEN Load( code, index ) END;
			GenConv( code, PCLIR.convu, index, PCLIR.Address, FALSE );   (*assume index is > 0 *)
			PCLIR.Emit12( code, PCLIR.add, x.adr, x.adr, index.adr );
			x.mode := RegRel;  x.offs := 0;  x.type := type.base;
		ELSE PCDebug.ToDo( PCDebug.NotImplemented );
		END;
		x.deref := FALSE;
	END EIndex;

	PROCEDURE TensorIndex*( code: Code;  VAR descr, x, index: Item; d: LONGINT);   (* called by PCB.Index.Emit *)
	VAR inc,dim,temp: Item;

		PROCEDURE IndexCheck( code: Code;  VAR index: Item );
		VAR bound: Item;
		BEGIN
			TensorGetLen(code,bound,descr,dim,FALSE);
			Load( code, index );
			PCLIR.Emit02C( code, PCLIR.tae, index.adr, bound.adr, PCM.IndexCheckTrap )
		END IndexCheck;

	BEGIN
		MakeSizeConst(dim,d);
		IF d<0 THEN
			TensorGetDim(code,dim,descr);
			MakeSizeConst(temp,d);
			DOp(code,PCS.plus,dim,temp);
		END;

		ASSERT ( x.type IS PCT.Tensor, 200 );
		ASSERT ( index.type = PCT.Int32, 201 );
		ASSERT ( x.mode IN {Reg, Abs, Var, Ref, RegRel, Const}, 202 );
		IF x.mode # Reg THEN LoadAdr( code, x );  END;
		IF PCM.ArrayCheck IN PCM.codeOptions THEN IndexCheck( code, index ) END;

		IF (index.mode # Reg) THEN
			Load( code, index ) (* fof : was LoadAdr *)
		END;

		TensorGetInc(code,inc,descr,dim,FALSE);
		DOp( code, PCS.times, index, inc );
		GenConv( code, PCLIR.convu, index, PCLIR.Address, FALSE );   (*assume index is > 0 *)
		PCLIR.Emit12( code, PCLIR.add, x.adr, x.adr, index.adr );

		x.mode := RegRel;  x.offs := 0;  x.deref := FALSE;
	END TensorIndex;

	PROCEDURE TensorFiller*(code: Code; VAR descr,x: Item; before,after: LONGINT);
	VAR one,dim,inc,len: Item; loop,exit: Label; beforeI,afterI: Item;
	BEGIN
		TensorGetDim(code,dim,descr);
		MakeSizeConst(afterI,after+1);
		DOp(code,PCS.minus,dim,afterI);

		MakeSizeConst(beforeI,before);
		Load(code,dim); Load(code,beforeI);
		exit := code.pc;
		PCLIR.Emit02C( code, PCLIR.jlt, dim.adr, beforeI.adr, none );
		DefLabel(code,loop);

			(* load inc and len and store inc and len *)

			TensorGetInc(code,inc,descr,dim,FALSE);
			IF inc.mode # Reg THEN Load( code, inc );  END;
			PCLIR.Emit01( code, PCLIR.push, inc.adr );
			TensorGetLen(code,len,descr,dim,FALSE);
			IF len.mode # Reg THEN Load( code, len ) END;
			PCLIR.Emit01( code, PCLIR.push, len.adr );
			MakeSizeConst(one,1);
			DOp(code,PCS.minus,dim,one);

			MakeSizeConst(beforeI,before);Load(code,beforeI);
			PCLIR.Emit02C( code, PCLIR.jge, dim.adr, beforeI.adr, loop );
			FixJmp(code, exit);
			PCLIR.Emit0C(code, PCLIR.label, 0);
	END TensorFiller;

	PROCEDURE TensorRange*( code: Code;  VAR descr, x, from, to, by: Item; d: LONGINT);
	(*! todo: range check for ranges ! *)
	VAR one, inc,dim,temp: Item;  oldby: Item;
	BEGIN
		MakeSizeConst(dim,d);
		IF d<0 THEN
			TensorGetDim(code,dim,descr);
			MakeSizeConst(temp,d);
			DOp(code,PCS.plus,dim,temp);
		END;
		IF x.mode # Reg THEN LoadAdr( code, x );  END;
		MakeSizeConst( one, 1 );
		IF (to.mode = Const) & (to.value = MAX( LONGINT )) THEN
			TensorGetLen(code,to,descr,dim,FALSE);
		ELSE
			IF (to.mode # Reg) & (to.mode # Const) THEN Load( code, to ) END;
			(*! check upper bound *)
			Load( code, to );  Load(code,one); DOp( code, PCS.plus, to, one );
		END;
		(*! check lower bound *)
		IF (from.mode # Reg) & (from.mode # Const) THEN Load( code, from ) END;
		IF (from.mode # Const) OR (from.value # 0) THEN
			DOp( code, PCS.minus, to, from );
		END;

		IF (by.mode # Const) OR (by.value # 1) THEN
			oldby := by;   (* might get modified in DOp, this is NOT nice*)
			DOp( code, PCS.minus, to, one );  DOp( code, PCS.div, to, by );
			DOp( code, PCS.plus, to, one );   (* n= (len-1) / by + 1 *)
			by := oldby;
		END;

		TensorGetInc(code,inc,descr,dim,FALSE);

		IF ((inc.mode # Const) OR (inc.value # 1)) &
		    ((from.mode # Const) OR (from.value # 0)) THEN
			DOp( code, PCS.times, from, inc );
		END;
		IF (from.mode # Const) OR (from.value # 0) THEN
			DOp( code, PCS.plus, x, from );
		END;
		IF (by.mode # Const) OR (by.value # 1) THEN
			DOp( code, PCS.times, inc, by );  by := inc;
		ELSE by := inc;
		END;
		IF inc.mode # Reg THEN Load( code, inc );  END;
		PCLIR.Emit01( code, PCLIR.push, inc.adr );   (* inc *)
		IF to.mode # Reg THEN Load( code, to ) END;
		PCLIR.Emit01( code, PCLIR.push, to.adr );   (* new length *)
		x.mode := RegRel;  x.offs := 0;
	END TensorRange;
(** << fof  *)


PROCEDURE Index*(code: Code; VAR x, index: Item);
VAR size: Item; type: PCT.Array; mode: SHORTINT;

	PROCEDURE IndexCheck(code: Code; VAR x, index: Item);
	VAR bound: Item;
	BEGIN
		type := x.type(PCT.Array); mode := type.mode;
		IF (mode = PCT.static) THEN
			IF index.mode = Const THEN RETURN END;	(*statically checked*)
			MakeIntConst(bound, type.len, PCT.Int32)
		ELSE
			ASSERT(mode = PCT.open);
			bound.mode := RegRel; bound.adr := x.breg; bound.offs := x.boffs; bound.type := PCT.Int32
		END;
		Load(code, index); Load(code, bound);
		PCLIR.Emit02C(code, PCLIR.tae, index.adr, bound.adr, PCM.IndexCheckTrap)
	END IndexCheck;

BEGIN
	ASSERT(x.type IS PCT.Array, 200);
	ASSERT(index.type = PCT.Int32, 201);
	type := x.type(PCT.Array); mode := type.mode;
	IF mode IN {PCT.static, PCT.open} THEN
		ASSERT(x.mode IN {Abs, Var, Ref, RegRel}, 202);

		LoadAdr(code, x);
		IF PCM.ArrayCheck IN PCM.codeOptions THEN IndexCheck(code, x, index) END;

		GetArrayBaseSize(code, size, x);
		DOp(code, PCS.times, index, size);
		IF index.mode # Reg THEN  Load(code, index)  END;
		GenConv(code, PCLIR.convu, index, PCLIR.Address, FALSE);	(*assume index is > 0 *)
		PCLIR.Emit12(code, PCLIR.add, x.adr, x.adr, index.adr);
		x.mode := RegRel; x.offs := 0; x.type := type.base;
		DEC(x.boffs, PCT.AddressSize);
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented);
	END;
	x.deref := FALSE;
	ASSERT(x.mode = RegRel, 220);
END Index;

PROCEDURE Field*(code: Code;  VAR x: Item;  fld: PCT.Field);
BEGIN
	LoadAdr(code, x);
	x.mode := RegRel;  x.breg := 0;   (* fof, to discriminate from adr relocation for arrays *)
	x.offs := fld.adr(PCBT.Variable).offset;  x.type := fld.type;
	x.deref := FALSE
END Field;
(*
PROCEDURE Method*(code: Code;  VAR x: Item;  self: Item;  mth: PCT.Method;  supercall: BOOLEAN);
VAR  mthAdr: PCBT.Method; t: PCLIR.Register;
BEGIN
	IF PCT.IsPointer(self.type) THEN
		Load(code, self); t := self.adr
	END;
	GetTD(code, self, x, supercall);
	Load(code, x);
	mthAdr := mth.adr(PCBT.Method);
	x.mode := Reg;
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, x.adr, MethodTable * PCT.AddressSize - PCT.AddressSize*mthAdr.mthNo, x.adr);
	x.breg := t;
	x.type := MethodType
END Method;
*)
PROCEDURE Method*(code: Code; VAR x: Item; self: Item; mth: PCT.Method; supercall: BOOLEAN);
VAR  mthAdr: PCBT.Method; t: PCLIR.Register; off: LONGINT;
BEGIN
	mthAdr := mth.adr(PCBT.Method);
	IF PCT.IsPointer(self.type) THEN
		Load(code, self); t := self.adr
	END;
	IF PCT.interface IN mth.boundTo.mode THEN
		InterfaceLookup(code, self, mth.boundTo, x);
		off := IntfMethodTable * PCT.AddressSize + PCT.AddressSize*mthAdr.mthNo
	ELSE
		GetTD(code, self, x, supercall);
		off := MethodTable * PCT.AddressSize - PCT.AddressSize*mthAdr.mthNo
	END;
	Load(code, x);
	x.mode := Reg;
	PCLIR.EmitLoadRelative(code, PCLIR.Address, FALSE, x.adr, off, x.adr);
	x.breg := t;
	x.type := MethodType
END Method;

(**-----------System Calls----------------*)

PROCEDURE InterfaceLookup(code: Code; VAR self: Item; intf: PCT.Record; VAR vtable: Item);
	VAR td: Item;
BEGIN
	GetTD(code, self, td, FALSE);
	Load(code, td);
	PCLIR.Emit01(code, PCLIR.push, td.adr);	(* push class descriptor *)
	MakeTD(td, intf);
	Load(code, td);
	PCLIR.Emit01(code, PCLIR.push, td.adr);	(* push interface descriptor *)
	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.interfacelookup);
	vtable.mode := Reg; vtable.type := PCT.Ptr; vtable.proc := NIL;
	PCLIR.Emit10(code, PCLIR.result, vtable.adr, PCLIR.Address(*PCT.Ptr.size(PCBT.Size).size.type*), FALSE);
END InterfaceLookup;

PROCEDURE SysNewRec*(code: Code;  VAR x: Item);	(* NewRec (VAR p: ANY; td: ANY) *)
VAR  ptr: PCT.Pointer;  type: PCT.Record;  td, const: Item;
BEGIN
	ASSERT(x.type IS PCT.Pointer, 200);
	ptr := x.type(PCT.Pointer);
	ASSERT(ptr.baseR # NIL  (* IS PCT.Record *), 201);
	type := ptr.baseR;
	LoadAdr(code, x);  PCLIR.Emit01(code, PCLIR.push, x.adr);	(*1st par: VAR p: PRT *)
	MakeTD(td, type);
	Load(code, td);  PCLIR.Emit01(code, PCLIR.push, td.adr);	(* 2nd par: td: ANY *)
	MakeIntConst(const, False, PCT.Bool);
	Load(code, const);
	PCLIR.Emit01(code, PCLIR.push, const.adr);	(* 3rd par: isRealtime: BOOLEAN *)
	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.newrec);
END SysNewRec;

PROCEDURE SysNewBlock*(code: Code;  x, size: Item);
VAR const: Item;
BEGIN
	Convert(code, size, PCT.Size, FALSE);
	IF x.mode # Reg THEN (* fof *)
	LoadAdr(code, x);
	END; (* fof *)
	PCLIR.Emit01(code, PCLIR.push, x.adr);
	Load(code, size);
	PCLIR.Emit01(code, PCLIR.push, size.adr);
	MakeIntConst(const, False, PCT.Bool);
	Load(code, const);
	PCLIR.Emit01(code, PCLIR.push, const.adr);	(* 3rd par: isRealtime: BOOLEAN *)
	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.newsys)
END SysNewBlock;
(** fof >> *)
	PROCEDURE SysNewEnhArray*( code: Code;  VAR ptr: Item;  btyp: PCT.Struct;  nofElem: Item );
	VAR size, td, const: Item;  bit, reg: PCLIR.Register;  label: Label;  adr: PCLIR.Register;
	BEGIN
		Convert( code, nofElem, PCT.Int32, FALSE );  Load( code, nofElem );

		(* check array length here, because the allocated size may be > 0 even if the length is < 0, e.g. with SysBlocks *)
		PCLIR.EmitLoadConst( code, reg, PCLIR.Int32, TRUE , -1 );
		PCLIR.Emit02C( code, PCLIR.jgt, nofElem.adr, reg, none );
		label := code.pc - 1;  PCLIR.Emit0C( code, PCLIR.trap, PCM.ArraySizeTrap );
		PCLIR.FixList( code, label, code.pc );  PCLIR.Emit0C( code, PCLIR.label, 0 );

		IF ptr.mode # Reg THEN LoadAdr( code, ptr );
		END;

		(* now check if allocation is allowed *)
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , reg, Descr_FlagsOffs*PCT.AddressSize,  ptr.adr );
		PCLIR.EmitLoadConst( code, bit, PCLIR.Address, FALSE ,
											SYSTEM.VAL( LONGINT, {RangeFlag} ) );
		PCLIR.Emit12( code, PCLIR.and, reg, bit, reg );
		PCLIR.EmitLoadConst( code, bit, PCLIR.Address, FALSE , 0 );
		PCLIR.Emit02C( code, PCLIR.tne, reg, bit, PCM.ArrayFormTrap );

		(* locate address of pointer in the descriptor *)
		PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE , Descr_PtrOffs*PCT.AddressSize );
		PCLIR.Emit12( code, PCLIR.add, adr, ptr.adr, adr );

		IF ~btyp.size( PCBT.Size ).containPtrs THEN
			MakeSizeConst( size, GetStaticSize( btyp ) );
			DOp( code, PCS.times, nofElem, size );
			MakeSizeConst( size, SysDataArrayOffset );   (* offset in array data for 32 bit alignment *)
			DOp( code, PCS.plus, size, nofElem );

			(* array allocation as system block *)
			PCLIR.Emit01( code, PCLIR.push, ptr.adr );   (* save address of descriptor *)
			ptr.adr := adr;   (* reference to array ptr element *)
			SysNewBlock( code, ptr, size );
			PCLIR.Emit10( code, PCLIR.pop, ptr.adr, PCLIR.Address, FALSE );   (* restore array descriptor address  *)

			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , adr, Descr_PtrOffs*PCT.AddressSize,
													 ptr.adr );
			PCLIR.EmitLoadConst( code, reg, PCLIR.Address, FALSE ,
												SysDataArrayOffset );   (* data offset in sys array, for alignment to 32 byte *)
			PCLIR.Emit12( code, PCLIR.add, adr, adr, reg );
			PCLIR.EmitStoreRelative( code, Descr_AdrOffs*PCT.AddressSize, ptr.adr, adr );   (* store array adr to adr field *)
		ELSE
			PCLIR.Emit01( code, PCLIR.push, ptr.adr );   (* save address of array descriptor  *)
			ptr.adr := adr;   (* reference to array ptr element *)
			PCLIR.Emit01( code, PCLIR.push, ptr.adr );   (* address to write to *)
			IF btyp IS PCT.Record THEN MakeTD( td, btyp( PCT.Record ) )
			ELSIF btyp IS PCT.Delegate THEN MakeTD( td, delegate );
			ELSE MakeTD( td, hdptr );
			END;
			Load( code, td );
			PCLIR.Emit01( code, PCLIR.push, td.adr );   (* type descriptor address *)
			Load( code, nofElem );  PCLIR.Emit01( code, PCLIR.push, nofElem.adr );   (* length *)

			PCLIR.EmitLoadConst( code, reg, PCLIR.Int32, TRUE , 0 );
			PCLIR.Emit01( code, PCLIR.push, reg );   (* number of dimensions = 0 as we control the dimensions in the array descriptor *)

			MakeIntConst(const, False, PCT.Bool);
			Load(code, const);
			PCLIR.Emit01(code, PCLIR.push, const.adr);	(* parameter isRealtime: BOOLEAN *)
			PCLIR.Emit0C( code, PCLIR.syscall, PCBT.newarr );

			PCLIR.Emit10( code, PCLIR.pop, ptr.adr, PCLIR.Address , FALSE);   (* restore descriptor address *)

			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , adr, 0, ptr.adr );   (*  offset of 0 as for POINTER TO ARRAY OF *)
			PCLIR.EmitLoadConst( code, reg, PCLIR.Address, FALSE ,
												ArrDataArrayOffset );   (* data offset in arr array *)
			PCLIR.Emit12( code, PCLIR.add, adr, adr, reg );
			PCLIR.EmitStoreRelative( code, Descr_AdrOffs*PCT.AddressSize, ptr.adr, adr );   (* array adr = array protector adr, no offset *)
		END;
	END SysNewEnhArray;

	PROCEDURE SysNewDescriptor*( code: Code;  VAR x: Item;  dim: LONGINT );   (* NewRec (VAR p: PTR; td: PTR) *)
	VAR td, const: Item;  dimR, adr, bit, reg: PCLIR.Register;  label, label2: LONGINT;
	BEGIN
		(*
			IF pointer = NIL THEN  allocation
			ELSIF dim(x) = d THEN omit allocation
			ELSIF no tensor flag THEN trap
			END;
		*)
		LoadAdr( code, x );
		PCLIR.Emit01( code, PCLIR.push, x.adr );   (* save reference *)

		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , adr, 0, x.adr );   (* deref *)
		PCLIR.EmitLoadConst( code, dimR, PCLIR.Address, FALSE , 0 );
		label := code.pc;
		PCLIR.Emit02C( code, PCLIR.je, adr, dimR, none );   (* pointer is nil -> jump to allocation *)
		(* pointer not nil *)
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , reg, Descr_DimOffs*PCT.AddressSize, adr );   (* load current dimension *)
		PCLIR.EmitLoadConst( code, dimR, PCLIR.Address, FALSE , dim );
		label2 := code.pc;
		PCLIR.Emit02C( code, PCLIR.je, reg, dimR, none );   (* dimension fits -> don't reallocate (this is not only an optimization, but a rule! ) *)
		(* dimension does not fit *)
		PCLIR.EmitLoadConst( code, dimR, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, {TensorFlag} ) );
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , reg, Descr_FlagsOffs*PCT.AddressSize,  adr );   (* load flags *)
		PCLIR.Emit12( code, PCLIR.and, adr, dimR, reg );
		PCLIR.EmitLoadConst( code, bit, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, {TensorFlag} ) );
		PCLIR.Emit02C( code, PCLIR.tne, adr, bit, PCM.ArrayFormTrap );   (* tensor flag not in descriptor *)
		FixJmp( code, label );
		PCLIR.Emit01( code, PCLIR.push, x.adr );   (*1st par: VAR p: PRT *)
		MakeTD( td, anyarr[dim] );   (* hidden pointer is located at position 0, ok ?? *)
		Load( code, td );
		PCLIR.Emit01( code, PCLIR.push, td.adr );   (* 2nd par: td: PTR *)
		MakeIntConst(const, False, PCT.Bool);
		Load(code, const);
		PCLIR.Emit01(code, PCLIR.push, const.adr);	(* 3rd par: isRealtime: BOOLEAN *)
		PCLIR.Emit0C( code, PCLIR.syscall, PCBT.newrec );  FixJmp( code, label2 );
		PCLIR.Emit10( code, PCLIR.pop, x.adr, PCLIR.Address ,FALSE);
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , x.adr, 0, x.adr );   (* deref *)
	END SysNewDescriptor;

	PROCEDURE TensorSysNew*( code: Code;  VAR descr: Item;  btyp: PCT.Struct;  nofElem: Item;  nofDims: LONGINT );
	VAR size: Item;  reg: PCLIR.Register;  label: Label;   adr: Item;
	BEGIN
		Convert( code, nofElem, PCT.Int32, FALSE );  Load( code, nofElem );

		(* check array length here, because the allocated size may be > 0 even if the length is < 0, e.g. with SysBlocks *)
		PCLIR.EmitLoadConst( code, reg, PCLIR.Int32, TRUE , -1 );
		PCLIR.Emit02C( code, PCLIR.jgt, nofElem.adr, reg, none );
		label := code.pc - 1;  PCLIR.Emit0C( code, PCLIR.trap, PCM.ArraySizeTrap );
		PCLIR.FixList( code, label, code.pc );  PCLIR.Emit0C( code, PCLIR.label, 0 );

		IF ~btyp.size( PCBT.Size ).containPtrs THEN
			size := nofElem;
			DOp( code, PCS.plus, size, nofElem );
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , adr.adr, 0, descr.adr );   (* deref, firt position in record *)
			adr.mode := Reg;  adr.type := PCT.Int32;
			SysNewBlock( code, adr, size );
		ELSE HALT( 200 );
		END;
	END TensorSysNew;
(** << fof  *)


PROCEDURE SysNewArray*(code: Code;  VAR ptr: Item;  btyp: PCT.Struct;  nofElem: Item;  nofDims: LONGINT);
VAR size, offset, td, const: Item;  reg: PCLIR.Register; label: Label;
BEGIN
	Convert(code, nofElem, PCT.Size, FALSE);
	Load(code, nofElem);

	(* check array length here, because the allocated size may be > 0 even if the length is < 0, e.g. with SysBlocks *)
	PCLIR.EmitLoadConst(code, reg, PCLIR.SizeType, TRUE, -1);
	PCLIR.Emit02C(code, PCLIR.jgt, nofElem.adr, reg, none);
	label := code.pc-1;
	PCLIR.Emit0C(code, PCLIR.trap, PCM.ArraySizeTrap);
	PCLIR.FixList(code, label, code.pc);
	PCLIR.Emit0C(code, PCLIR.label, 0);

	IF ~btyp.size(PCBT.Size).containPtrs THEN
		MakeIntConst(size, GetStaticSize(btyp), PCT.Size);
		DOp(code, PCS.times, size, nofElem);
		MakeIntConst(offset, ArrayDimTable * PCT.AddressSize +PCT.AddressSize+PCT.AddressSize*2*(nofDims DIV 2), PCT.Size);
		DOp(code, PCS.plus, size, offset);
		SysNewBlock(code, ptr, size);
	ELSE
		LoadAdr(code, ptr); PCLIR.Emit01(code, PCLIR.push, ptr.adr);
		IF btyp IS PCT.Record THEN
			MakeTD(td, btyp(PCT.Record))
		ELSIF btyp IS PCT.Delegate THEN
			MakeTD(td, delegate);
		ELSE
			MakeTD(td, hdptr);
(*
			ASSERT(PCT.IsPointer(btyp));
			td.mode := Const; td.value := Nil; td.type := PCT.NilType
*)
		END;
		Load(code, td); PCLIR.Emit01(code, PCLIR.push, td.adr);
		Load(code, nofElem);  PCLIR.Emit01(code, PCLIR.push, nofElem.adr);
		PCLIR.EmitLoadConst(code, reg, PCLIR.SizeType, TRUE, nofDims);
		PCLIR.Emit01(code, PCLIR.push, reg);
		MakeIntConst(const, False, PCT.Bool);
		Load(code, const);
		PCLIR.Emit01(code, PCLIR.push, const.adr);	(* 3rd par: isRealtime: BOOLEAN *)
		PCLIR.Emit0C(code, PCLIR.syscall, PCBT.newarr)
	END;
END SysNewArray;

(** fof >> *)
	PROCEDURE SetEnhArrayLen*( code: Code;  VAR ptr, inc: Item;  nofDims, dim: LONGINT );
	VAR offs: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr );  END;   (* is already address ?*)
		Load( code, inc );  offs := Descr_LenOffs*PCT.AddressSize + dim * 8;   (* EnhArrayLenOffset + 8 * (nofDims - 1 - dim);  *)
		PCLIR.Emit10( code, PCLIR.pop, size, PCLIR.Int32 ,FALSE);
		PCLIR.EmitStoreRelative( code, offs, ptr.adr (* ptr.breg*) , size );  INC( offs, 4 );
		PCLIR.EmitStoreRelative( code, offs, ptr.adr (* ptr.breg*) , inc.adr );
		PCLIR.Emit12( code, PCLIR.mul, inc.adr, inc.adr, size );
	END SetEnhArrayLen;

	PROCEDURE SetEnhArrayDim*( code: Code;  VAR ptr: Item;  dim: LONGINT );
	VAR size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr );  END;   (* is already address ?*)
		PCLIR.EmitLoadConst( code, size, PCLIR.Int32, TRUE , dim );
		PCLIR.EmitStoreRelative( code, Descr_DimOffs*PCT.AddressSize, ptr.adr (* ptr.breg*) , size );
	END SetEnhArrayDim;

	PROCEDURE SetEnhArrayFlags*( code: Code;  VAR ptr: Item;  flags: SET );
	VAR offs: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr ) END;
		offs := Descr_FlagsOffs*PCT.AddressSize;
		PCLIR.EmitLoadConst( code, size, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, flags ) );
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, size )
	END SetEnhArrayFlags;

	(* Setting flags used for optimizations of operations on small matrices (Alexey Morozov) *)
	PROCEDURE SetSmallMatrixFlags*(code: Code;  VAR ptr: Item);
	VAR flags_offs, len_offs: LONGINT;  n, len, len1, flags: PCLIR.Register; exit, exit1: Label;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr ) END;
		len_offs := Descr_LenOffs*PCT.AddressSize;
		flags_offs := Descr_FlagsOffs*PCT.AddressSize;

		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,len,len_offs,ptr.adr);
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,8);

		exit := code.pc;
		PCLIR.Emit02C(code,PCLIR.jgt,len,n,none); (* if LEN(x,0) > n then goto exit *)

		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,len1,len_offs+8,ptr.adr);

		exit1 := code.pc;
		PCLIR.Emit02C(code,PCLIR.jne,len1,len,none); (* if LEN(x,1) # LEN(x,0) then goto exit *)

		(*
			set flags
		*)
		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,flags,flags_offs,ptr.adr); (* load current flags from the descriptor *)
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,SYSTEM.VAL(LONGINT,{SmallMatrixFlag}));
		PCLIR.Emit12(code,PCLIR.or,flags,flags,n); (* flags := flags + {SmallMatrixFlag} *)

		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,2);
		PCLIR.Emit12(code,PCLIR.add,len,len,n); (* len := len + 2 *)

		(* n := LSH(1,len) *)
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,1);
		PCLIR.EmitConv(code,PCLIR.copy,len,PCLIR.Int8,TRUE,len);
		PCLIR.Emit12(code,PCLIR.bsh,n,n,len);

		PCLIR.Emit12(code,PCLIR.or,flags,flags,n); (* flags := flags OR n *)

		PCLIR.EmitStoreRelative(code,flags_offs,ptr.adr,flags);

		FixJmp(code,exit);
		FixJmp(code,exit1);
	END SetSmallMatrixFlags;

	(* Setting flags used for optimizations of operations on small vectors (Alexey Morozov) *)
	PROCEDURE SetSmallVectorFlags*(code: Code;  VAR ptr: Item);
	VAR flags_offs, len_offs: LONGINT;  n, len, flags: PCLIR.Register; exit: Label;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr ) END;
		len_offs := Descr_LenOffs*PCT.AddressSize;
		flags_offs := Descr_FlagsOffs*PCT.AddressSize;

		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,len,len_offs,ptr.adr);
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,8);

		exit := code.pc;
		PCLIR.Emit02C(code,PCLIR.jgt,len,n,none); (* if LEN(x,0) > n then goto exit *)

		(*
			set flags
		*)
		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,flags,flags_offs,ptr.adr); (* load current flags from the descriptor *)
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,SYSTEM.VAL(LONGINT,{SmallMatrixFlag}));
		PCLIR.Emit12(code,PCLIR.or,flags,flags,n); (* flags := flags + {SmallMatrixFlag} *)

		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,2);
		PCLIR.Emit12(code,PCLIR.add,len,len,n); (* len := len + 2 *)

		(* n := LSH(1,len) *)
		PCLIR.EmitLoadConst(code,n,PCLIR.Address,FALSE,1);
		PCLIR.EmitConv(code,PCLIR.copy,len,PCLIR.Int8,TRUE,len);
		PCLIR.Emit12(code,PCLIR.bsh,n,n,len);

		PCLIR.Emit12(code,PCLIR.or,flags,flags,n); (* flags := flags OR n *)

		PCLIR.EmitStoreRelative(code,flags_offs,ptr.adr,flags);

		FixJmp(code,exit);
	END SetSmallVectorFlags;

	PROCEDURE SetEnhArraySize*( code: Code;  VAR ptr: Item;  elementsize: LONGINT );
	VAR size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr );  END;   (* is already address ?*)
		PCLIR.EmitLoadConst( code, size, PCLIR.Int32, TRUE , elementsize );
		PCLIR.EmitStoreRelative( code, Descr_SizeOffs*PCT.AddressSize, ptr.adr (* ptr.breg*) , size );
	END SetEnhArraySize;

	PROCEDURE TensorSetAdr*( code: Code;  VAR ptr: Item;  hasPointers: BOOLEAN );
	VAR adr, tmp: LONGINT;
	BEGIN
		IF ptr.mode # Reg THEN DerefTensor( code, ptr );  LoadAdr( code, ptr ) END;
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , adr, 0, ptr.adr );
		IF ~hasPointers THEN
			PCLIR.EmitLoadConst( code, tmp, PCLIR.Int32, TRUE , 8 );   (* align to 32 Byte boundary *)  (*! check! *)
			PCLIR.Emit12( code, PCLIR.add, adr, adr, tmp );
		END;
		PCLIR.EmitStoreRelative( code, Descr_AdrOffs*PCT.AddressSize, ptr.adr, adr );
	END TensorSetAdr;

	PROCEDURE TensorSetDim*( code: Code;  VAR ptr: Item;  nofDims: LONGINT );
	VAR offs: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN DerefTensor( code, ptr );  LoadAdr( code, ptr ) END;
		offs :=   Descr_DimOffs*PCT.AddressSize;
		PCLIR.EmitLoadConst( code, size, PCLIR.Address, FALSE , nofDims );
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, size )
	END TensorSetDim;

	PROCEDURE TensorSetSize*( code: Code;  VAR ptr: Item;  elementsize: LONGINT );
	VAR offs: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN DerefTensor( code, ptr );  LoadAdr( code, ptr ) END;
		offs :=  Descr_SizeOffs*PCT.AddressSize;
		PCLIR.EmitLoadConst( code, size, PCLIR.Address, FALSE , elementsize );
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, size )
	END TensorSetSize;

	PROCEDURE TensorSetFlags*( code: Code;  VAR ptr: Item;  flags: SET );
	VAR offs: LONGINT;  size: PCLIR.Register;
	BEGIN
		IF ptr.mode # Reg THEN DerefTensor( code, ptr );  LoadAdr( code, ptr ) END;
		offs :=   Descr_FlagsOffs*PCT.AddressSize;
		PCLIR.EmitLoadConst( code, size, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, flags ) );
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, size )
	END TensorSetFlags;

	PROCEDURE PopLen*( code: Code;  VAR len: Item );
	BEGIN
		PCLIR.Emit10( code, PCLIR.pop, len.adr, PCLIR.Int32,FALSE );  len.mode := Reg;
	END PopLen;

	PROCEDURE DescriptorSetLen*( code: Code;  VAR ptr, len: Item;  dim: LONGINT );
	VAR offs: LONGINT;
	BEGIN
		IF ptr.mode # Reg THEN  (* DerefTensor( code, ptr ); *) LoadAdr( code, ptr ) END;
		offs :=  Descr_LenOffs*PCT.AddressSize + 8 * dim;
		IF len.mode # Reg THEN Load( code, len ) END;
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, len.adr )
	END DescriptorSetLen;

	PROCEDURE DescriptorSetInc*( code: Code;  VAR ptr, inc: Item;  dim: LONGINT );
	VAR offs: LONGINT;
	BEGIN
		IF ptr.mode # Reg THEN  (* DerefTensor( code, ptr ); *) LoadAdr( code, ptr ) END;
		offs :=  Descr_IncOffs*PCT.AddressSize + 8 * dim;
		IF inc.mode # Reg THEN Load( code, inc ) END;
		PCLIR.EmitStoreRelative( code, offs, ptr.adr, inc.adr )
	END DescriptorSetInc;

	PROCEDURE TensorGetDesc( code: Code;  VAR res, arr, dim: Item;  offs: LONGINT );
	VAR exit, label: LONGINT;  checkptr: BOOLEAN;  a, b: LONGINT;  dynoffs: LONGINT;
	BEGIN
		checkptr := arr.mode # Reg;
		IF checkptr THEN
			DerefTensor( code, arr );
			PCLIR.EmitLoadConst( code, a, PCLIR.Address, FALSE , 0 );
			PCLIR.Emit01( code, PCLIR.kill, a );  label := code.pc;
			PCLIR.Emit02C( code, PCLIR.jne, arr.adr, a, none );  exit := -1;
			Jmp( code, exit );  FixJmp( code, label );  LoadAdr( code, arr );
		END;
		IF dim.mode = Const THEN
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , b,  offs + dim.value * 8, arr.adr );
		ELSE
			IF dim.mode # Reg THEN Load( code, dim ) END;
			PCLIR.EmitLoadConst( code, dynoffs, PCLIR.Address, FALSE , 8 );
			PCLIR.Emit12( code, PCLIR.mul, dynoffs, dynoffs, dim.adr );
			PCLIR.Emit12( code, PCLIR.add, b, dynoffs, arr.adr );
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , b, offs, b );
		END;
		PCLIR.Emit01( code, PCLIR.kill, b );
		IF checkptr THEN
			FixJmp( code, exit );  PCLIR.EmitPhi( code, res.adr, a, b );
			res.mode := Reg;
		ELSE res.adr := b;  res.mode := Reg;
		END;
		res.mode := Reg;  res.type := PCT.Int32;
	END TensorGetDesc;

	PROCEDURE TensorGetDim*( code: Code;  VAR res, arr: Item );
	VAR dim: Item;
	BEGIN
		MakeIntConst( dim, 0 ,PCT.Int32);  TensorGetDesc( code, res, arr, dim, Descr_DimOffs*PCT.AddressSize );
	END TensorGetDim;

	PROCEDURE TensorGetSize*( code: Code;  VAR res, arr: Item );
	VAR dim: Item;
	BEGIN
		MakeIntConst( dim, 0, PCT.Int32 );  TensorGetDesc( code, res, arr, dim, Descr_SizeOffs*PCT.AddressSize );
	END TensorGetSize;

	PROCEDURE TensorGetFlags*( code: Code;  VAR res, arr: Item );
	VAR dim: Item;
	BEGIN
		MakeIntConst( dim, 0, PCT.Int32 );  TensorGetDesc( code, res, arr, dim, Descr_FlagsOffs*PCT.AddressSize );
	END TensorGetFlags;

	PROCEDURE TensorCheckDim( code: Code;  VAR res, arr, dim: Item );
	BEGIN
		Convert( code, dim, PCT.Int32, FALSE );
		TensorGetDim( code, res, arr );
		IF dim.mode # Reg THEN Load( code, dim ) END;
		PCLIR.Emit02C( code, PCLIR.tae, dim.adr, res.adr, PCM.IndexCheckTrap );
	END TensorCheckDim;

	PROCEDURE TensorCheckDims*( code: Code;  VAR x: Item;  dims: LONGINT );
	VAR label: LONGINT;  reg, reg2: PCLIR.Register;  offs: LONGINT;
	BEGIN
		IF x.mode # Reg THEN LoadAdr( code, x );  END;
		offs := Descr_DimOffs*PCT.AddressSize;
		PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , reg, offs, x.adr );
		PCLIR.EmitLoadConst( code, reg2, PCLIR.Int32, TRUE , dims );
		PCLIR.Emit02C( code, PCLIR.je, reg2, reg, none );  label := code.pc - 1;
		PCLIR.Emit0C( code, PCLIR.trap, PCM.ArraySizeTrap );
		PCLIR.FixList( code, label, code.pc );  PCLIR.Emit0C( code, PCLIR.label, 0 );
	END TensorCheckDims;

	PROCEDURE TensorGetLen( code: Code;  VAR res, arr, dim: Item; checkDim: BOOLEAN );
	BEGIN
		IF checkDim THEN
			TensorCheckDim( code, res, arr, dim );
		END;
		TensorGetDesc( code, res, arr, dim, Descr_LenOffs*PCT.AddressSize );
	END TensorGetLen;

	PROCEDURE TensorGetInc( code: Code;  VAR res, arr, dim: Item; checkDim: BOOLEAN);
	BEGIN
		IF checkDim THEN
			TensorCheckDim( code, res, arr, dim );
		END;
		TensorGetDesc( code, res, arr, dim, Descr_IncOffs*PCT.AddressSize );
	END TensorGetInc;

	PROCEDURE StaticPrepStack*( code: Code;  a: Item; tensor: BOOLEAN );
	VAR const, base: LONGINT;   offset: LONGINT;
	BEGIN
		offset := GetStaticSize( a.type);
		IF tensor THEN
			PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 0);
			PCLIR.Emit12( code, PCLIR.add, a.adr, PCLIR.SP, const );
			a.mode := Reg;
			ArrayDescriptorToStack( code, a );
			INC(offset,a.type(PCT.EnhArray).dim*8+Descr_LenOffs*PCT.AddressSize);
		END;
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , offset );
		PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, const );
		PCLIR.Emit01( code, PCLIR.push, base );
	END StaticPrepStack;

	PROCEDURE TensorPrepStack*( code: Code;  a: Item;   ref: BOOLEAN );
	VAR (* const, base: LONGINT;  dim: LONGINT;  offset: LONGINT; *)  offset,const: Item; base: LONGINT;
	BEGIN
		IF a.type IS PCT.Tensor THEN
			LoadAdr(code,a);
			TensorGetDim(code,offset,a);
			MakeSizeConst(const,8);
			DOp(code,PCS.times,offset,const);
			MakeSizeConst(const,Descr_LenOffs*PCT.AddressSize);
			DOp(code,PCS.plus,offset,const);
			Load(code,offset); (* must be loaded here because there might be a modification of the stack pointer down below *)
		ELSE
			MakeSizeConst(offset,a.type( PCT.EnhArray ).dim * 2 * PCT.AddressSize + Descr_LenOffs*PCT.AddressSize);
		END;
		IF ref THEN
			PCLIR.Emit01( code, PCLIR.push, PCLIR.SP );
			MakeSizeConst(const,4);
			DOp(code,PCS.plus,offset,const);
		END;
		Load(code, offset);
		PCLIR.Emit12( code, PCLIR.add, base, offset.adr, PCLIR.SP);
		(* andersrum geht's nicht: PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, offset.adr) falsch: MOV EBX,ESP; ADD EBX,EBX ! *)
		PCLIR.Emit01( code, PCLIR.push, base );
	END TensorPrepStack;

	PROCEDURE EnhArrayPointerToStack*( code: Code;  a: Item );
	VAR const, base: LONGINT;
	BEGIN
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 4 );
		PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, const );
		PCLIR.Emit01( code, PCLIR.push, base );
	END EnhArrayPointerToStack;

	PROCEDURE TensorUseStack*( code: Code;  ofs: LONGINT;  parNbr: LONGINT );
	VAR base, const: PCLIR.Register;
	BEGIN
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , ofs );
		PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, const );
		WHILE parNbr > 1 DO
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , base, 0, base );
			DEC( parNbr );
		END;
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 4 );
		PCLIR.Emit12( code, PCLIR.add, base, base, const );
		PCLIR.Emit01( code, PCLIR.push, base );
	END TensorUseStack;

	PROCEDURE TensorUseStackItem*(code: Code; ofs: LONGINT; parNbr: LONGINT;VAR i: Item;  type: PCT.Struct);
	VAR base, const: PCLIR.Register;
	BEGIN
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , ofs );
		PCLIR.Emit12( code, PCLIR.add, base, PCLIR.SP, const );
		WHILE parNbr > 1 DO
			PCLIR.EmitLoadRelative( code, PCLIR.Address, FALSE , base, 0, base );
			DEC( parNbr );
		END;
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE , 4 );
		PCLIR.Emit12( code, PCLIR.add, base, base, const );
		i.adr := base;
		i.type := type;
		i.mode := Reg;
	END TensorUseStackItem;

(* check dimension of the tensor and push descriptor to stack *)
	PROCEDURE TensorDescriptorToStack*( code: Code;  VAR arr: Item;  dim: LONGINT );
	VAR dest, sizeItem: Item;  size: LONGINT;  type: PCT.Struct;
	BEGIN
		TensorCheckDims( code, arr, dim );   (* invokes trap if arr=NIL or dimension#dim *)
		size := dim * 8 + Descr_LenOffs*PCT.AddressSize;  StackAllocate( code, size, dest );
		LoadAdr( code, dest );   (* to prevent from "Load" in MoveBlock *)
		MakeIntConst( sizeItem, size, PCT.Int32 );  type := arr.type;
		arr.type := PCT.Int32;  MoveBlock( code, dest, arr, sizeItem );
		(* writing of dimension is not necessary as it is always correct in tensor arrays
		MakeIntConst( sizeItem, dim, PCT.Int32 );
		PCLIR.EmitStoreRelative(code, Descr_DimOffs*PCT.AddressSize,PCLIR.SP,sizeItem.adr);
		*)
		arr.type := type;
	END TensorDescriptorToStack;
(** << fof  *)


PROCEDURE SetArrayDim*(code: Code;  VAR ptr: Item;  nofDims, dim: LONGINT);
VAR  offs: LONGINT;  size: PCLIR.Register;
BEGIN
	IF ptr.mode # Reg THEN  Load(code, ptr)  END;
	offs := ArrayDimTable * PCT.AddressSize +PCT.AddressSize*(nofDims-1-dim);
	PCLIR.Emit10(code, PCLIR.pop, size, PCLIR.Address, FALSE);
	PCLIR.EmitStoreRelative(code, offs, ptr.adr, size)
END SetArrayDim;

PROCEDURE SysLock*(code: Code;  self: Item;  lock: BOOLEAN);
VAR const: Item;
BEGIN
	IF self.type IS PCT.Record THEN
		LoadAdr(code, self)
	ELSE
		Load(code, self)
	END;
	PCLIR.Emit01(code, PCLIR.push, self.adr);
	MakeIntConst(const, True, PCT.Bool);
	Load(code, const);
	PCLIR.Emit01(code, PCLIR.push, const.adr);
	IF lock THEN
		PCLIR.Emit0C(code, PCLIR.syscall, PCBT.lock)
	ELSE
		PCLIR.Emit0C(code, PCLIR.syscall, PCBT.unlock)
	END
END SysLock;

PROCEDURE SysStart*(code: Code;  body: PCT.Method;  self: Item);
VAR  mth: Item; rec: PCT.Record;  flags: LONGINT;  reg : PCLIR.Register;
BEGIN
	rec := body.boundTo;
	MakeTD(mth, rec);  Load(code, mth);

	mth.mode := RegRel; mth.type := PCT.Ptr(*body.type*);
	mth.offs := MethodTable * PCT.AddressSize - PCT.AddressSize * body.adr(PCBT.Method).mthNo;
	Load(code, mth);
	IF PCT.active IN rec.mode THEN
		(* Call to Objects.CreateProcess(body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject); *)
		PCLIR.Emit01(code, PCLIR.push, mth.adr);
		PCLIR.EmitLoadConst(code, reg, PCLIR.Int32, TRUE, rec.prio);
		PCLIR.Emit01(code, PCLIR.push, reg);
		flags := 0; (* = {} *)
		IF  PCT.safe IN rec.mode THEN
			flags := 1; (* = {Objects.Restart} *)
		END;
		PCLIR.EmitLoadConst(code, reg, PCLIR.Set, FALSE, flags);
		PCLIR.Emit01(code, PCLIR.push, reg);
		ASSERT(self.type IS PCT.Pointer);
		Load(code, self);
		PCLIR.Emit01(code, PCLIR.push, self.adr);
		PCLIR.Emit0C(code, PCLIR.syscall, PCBT.start)
	ELSE
(*
		PCM.LogWLn; PCM.LogWStr("PCC.SysStart: non-active body!");
		PCM.LogWStr(body.name);
		IF rec.owner # NIL THEN PCM.LogWStr(rec.owner.name)
		ELSIF rec.ptr.owner # NIL THEN PCM.LogWStr(rec.ptr.owner.name)
		END;
*)
		Load(code, self);
		PCLIR.Emit01(code, PCLIR.push, self.adr);
		PCLIR.Emit01(code, PCLIR.callreg, mth.adr)
	END;
END SysStart;

(**
 *	GetProcedure runtime system call
 *
 *	The built-in function GETPROCEDURE(modulename, procedureName : ARRAY OF CHAR; VAR proc : ProcedureVariable) uses this runtime system
 *  	call to be able to retrieve some special procedures by its name and assign them to the VAR parameter proc in a type-safe manner..
 *	These special procedures must be exported from and defined in the module scope and have to following properties:
 *		- at most one formal parameter
 *		- at most one return value
 *		- if present, the type of the formal parameter and/or return value must be either (POINTER TO) RECORD or OBJECT
 *
 *	The system calls target is the kernel procedure
 *  		GetProcedure*(moduleName, procedureName : ARRAY OF CHAR;
 * 			argTdAdr, retTdAdr : ADDRESS; VAR entryAdr : ADDRESS);
 *	where as
 * 		argTdAdr, retTdAdr : Adresses of the type descriptors of the actual parameter and return type (if present)
 *		entryAdr : Entry address of the procedure <proc> specified in GETPROCEDURE(...)
 *)
PROCEDURE SysGetProcedure*(code : Code; moduleName, procedureName, entryAdr : Item; procScope : PCT.ProcScope; returnType : PCT.Struct);

	(* Push address of type descriptor of type <type> on the stack *)
	PROCEDURE PushTD(code : Code; type : PCT.Struct);
	VAR item : Item;
	BEGIN
		ASSERT((type IS PCT.Pointer) OR (type IS PCT.Record));
		IF type IS PCT.Pointer THEN
			MakeTD(item, type(PCT.Pointer).baseR)
		ELSE
			MakeTD(item, type(PCT.Record))
		END;
		Convert(code, item, PCT.Address, TRUE);
		Load(code, item);
		PCLIR.Emit01(code, PCLIR.push, item.adr);
	END PushTD;

	(* Push integer constant on the stack *)
	PROCEDURE PushConstant(code : Code; value : LONGINT);
	VAR item : Item;
	BEGIN
		MakeIntConst(item, value, PCT.Address);
		Load(code, item);
		PCLIR.Emit01(code, PCLIR.push, item.adr);
	END PushConstant;

	(* Push array size and address of the first element on the stack *)
	PROCEDURE PushArrayRef(code : Code; array : Item);
	VAR arraySize : Item;
	BEGIN
		LoadAdr(code, array);
		ArrayDim(code, arraySize, array, 0);
		Load(code, arraySize);
		PCLIR.Emit01(code, PCLIR.push, arraySize.adr); (* put array size on stack (PCT.Int32) *)
		PCLIR.Emit01(code, PCLIR.push, array.adr); (* put address of first array element on stack *)
	END PushArrayRef;

BEGIN
	(* moduleName : ARRAY OF CHAR *)
	PushArrayRef(code, moduleName);

	(* procedureName : ARRAY OF CHAR *)
	PushArrayRef(code, procedureName);

	(* argTdAdr : ADDRESS *)
	IF (procScope.formalParCount = 1) THEN
		IF (procScope.firstPar.type # PCT.Ptr) THEN (* type descriptor for actual parameter available *)
			PushTD(code, procScope.firstPar.type);
		ELSE
			PushConstant(code, 1);
		END;
	ELSE
		PushConstant(code,  0);
	END;

	(* retTdAdr : ADDRESS *)
	IF (returnType # PCT.NoType) THEN (* type descriptor of return value available *)
		IF (returnType # PCT.Ptr) THEN
			PushTD(code, returnType);
		ELSE
			PushConstant(code, 1);
		END;
	ELSE
		PushConstant(code, 0);
	END;

	(* VAR entryAdr : ADDRESS *)
	LoadAdr(code, entryAdr);
	PCLIR.Emit01(code, PCLIR.push, entryAdr.adr);

	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.getprocedure);
END SysGetProcedure;

(**-----------Statements----------------*)

PROCEDURE NewInstr*(code: Code; pos: LONGINT);
BEGIN
	PCLIR.Emit0C(code, PCLIR.label, pos)
END NewInstr;

PROCEDURE Assign*(code: Code; VAR dest, source: Item);
VAR  mode, size: LONGINT;
BEGIN
	IF (dest.type IS PCT.Basic) OR PCT.IsPointer(dest.type) THEN
		IF Statistics THEN INC(AAssBasic) END;
		IF (source.type = PCT.Float32) & (source.mode # Reg) THEN	(*optimize move*)
			dest.type := PCT.Int32; source.type := PCT.Int32
		END;
		IF source.mode = CC THEN  LoadCC(code, source)
		ELSIF source.mode # Reg THEN Load(code, source) END;
		IF dest.mode # Reg THEN		LoadAdr(code, dest); END;   (* fof *)
		PCLIR.EmitStoreRelative(code, 0, dest.adr, source.adr);
	(*fof*)
	ELSIF dest.type = range THEN
		HALT(200); (* not yet implemented *)
		IF PCT.IsCardinalType(source.type) THEN
		ELSIF dest.type = range THEN
		ELSE
			HALT(200);
		END;
	ELSIF dest.type IS PCT.Record THEN
		IF Statistics THEN INC(AAssRec) END;
		PCBT.AllocateTD(dest.type.size(PCBT.RecSize));
		size := GetStaticSize(dest.type);
		CopyBlock(code, dest, source, size)
	ELSIF dest.type IS PCT.Array THEN
		IF Statistics THEN INC(AAssArray) END;
		IF source.type = PCT.String THEN
			IF dest.type(PCT.Array).mode = PCT.open THEN
				MoveString (code, source, dest);
			ELSE
				CopyBlock(code, dest, source, source.value)
			END
		ELSIF source.type = dest.type THEN
			ASSERT(dest.type(PCT.Array).mode = PCT.static);
			size := GetStaticSize(dest.type);
			CopyBlock(code, dest, source, size);
		ELSE
			PCDebug.ToDo(PCDebug.NotImplemented)
		END;
	ELSIF dest.type IS PCT.Delegate THEN
		IF Statistics THEN INC(AAssProc) END;
		mode := source.mode;
		Load(code, source);
		LoadAdr(code, dest);
		PCLIR.EmitStoreRelative(code, 0, dest.adr, source.adr);
		IF ~(PCT.StaticMethodsOnly IN dest.type.flags) THEN
			PCLIR.EmitStoreRelative(code, PCT.AddressSize, dest.adr, GetDelegateSelfReg(code, source, mode))
		END
	(** fof >> *)
	ELSIF (dest.type IS PCT.EnhArray) &  (dest.type( PCT.EnhArray ).mode = PCT.static) THEN
		IF source.type = dest.type THEN
			size := GetStaticSize( dest.type );  CopyBlock( code, dest, source, size );
		ELSE
			HALT( 100 );   (* performed in PCB *)
		END;
	(** << fof  *)
	ELSE
		PCDebug.ToDo(PCDebug.NotImplemented)
	END
END Assign;

PROCEDURE GenTrap*(code: Code; nr: LONGINT);
BEGIN
	PCLIR.Emit0C(code, PCLIR.trap, nr);
	(* TrapCollector.Say(scope, nr);	*)
END GenTrap;

PROCEDURE Return*(code: Code;  x: Item;  proc: PCT.Proc; rtypeAddr: LONGINT (* ug *));
VAR  parSize, mode: LONGINT;  size, dst, hdst: Item;  type: PCT.Struct;	(* ug: hdst stands for hiddendst *)
BEGIN
	type := proc.type;
	IF PCT.ContainsPointer(type) THEN
		hdst.mode := Var; hdst.offs := rtypeAddr; hdst.level := 0; hdst.type := PCT.Address;
	END;
	mode := x.mode;
	IF (type IS PCT.Basic) OR PCT.IsPointer(type) THEN
		IF Statistics THEN INC(ARetBasic) END;
		Load(code, x);
		IF PCT.ContainsPointer(type) THEN
			Load(code, hdst);
			PCLIR.EmitStoreRelative(code, 0, hdst.adr, x.adr);
		END;
		PCLIR.Emit01(code, PCLIR.ret, x.adr)
	ELSIF type IS PCT.Record THEN
		IF Statistics THEN INC(ARetRec) END;
		parSize := proc.adr(PCBT.Procedure).parsize;
		size.mode := Var; size.offs := parSize+PCT.AddressSize; size.level := 0; size.type := PCT.Size;
		dst.mode := Var; dst.offs := parSize; dst.level := 0; dst.type := PCT.Address;
		LoadAdr(code, x); x.type := PCT.Address;
		MoveBlock(code, dst, x, size);
		IF PCT.ContainsPointer(type) THEN
			MoveBlock(code, hdst, x, size);
		END
	ELSIF type IS PCT.Array THEN
		IF type(PCT.Array).mode = PCT.open THEN
			IF Statistics THEN INC(ARetOpenArray) END;
			IF mode = Proc THEN
				ReturnProc(code, x, proc);
			ELSE
				ReturnArray(code, x, proc);
			END;
		ELSE
			IF Statistics THEN INC(ARetStaticArray) END;
			parSize := proc.adr(PCBT.Procedure).parsize;
			MakeIntConst(size, GetStaticSize(proc.type), PCT.Size);
			dst.mode := Var; dst.offs := parSize; dst.level := 0; dst.type := PCT.Address;
			LoadAdr(code, x); x.type := PCT.Address;
			MoveBlock(code, dst, x, size);
			IF PCT.ContainsPointer(type) THEN
				MoveBlock(code, hdst, x, size)
			END
		END
	(** fof >> *)
	ELSIF type IS PCT.EnhArray THEN
			IF type( PCT.EnhArray ).mode = PCT.open THEN
				HALT( 99 );   (* PCB must call ReturnEnhArray *)
			ELSE
				MakeReturnItem(code,dst,proc); dst.type := PCT.Int32;
				MakeIntConst( size, GetStaticSize( proc.type ), PCT.Int32 );
				LoadAdr( code, x );  x.type := PCT.Int32;
				MoveBlock( code, dst, x, size );
			END;
	ELSIF type IS PCT.Tensor THEN
			HALT( 99 );   (* PCB must call ReturnTensor *)
	(** << fof  *)
	ELSE
		IF Statistics THEN INC(ARetElse) END;
		mode := x.mode;
		Load(code, x);
		PCLIR.Emit01(code, PCLIR.ret, x.adr);
		IF (type IS PCT.Delegate) & ~(PCT.StaticMethodsOnly IN type.flags) THEN
			PCLIR.Emit01(code, PCLIR.ret2, GetDelegateSelfReg(code, x, mode));
			Load(code, hdst);
			PCLIR.EmitStoreRelative(code, 4, hdst.adr, GetDelegateSelfReg(code, x, mode)); (* Delegate SELF pointer stored at offset 4 relative to hdst.addr *)
		END
	END
END Return;

PROCEDURE SYScopy*(code: Code;  x, y: Item;  get: BOOLEAN);(* fof remark: called by getfn or putfn in PCB *)
BEGIN
   (** fof >> *)
       (* the following LoadCC  must be called here because otherwise in code produced by procedure Assign the address of destination is loaded
           within a part that might be stepped over while checking OR or & statements.
           example:
               PROCEDURE Test*;
               VAR  d,e,f: BOOLEAN; adr: ADDRESS;
               BEGIN
                   d := TRUE; e := TRUE; adr := ADDRESSOF(f);
                   SYSTEM.PUT(adr, d OR e);
               END Test;
           produces an access violation error.
           *)

      	IF y.mode = CC THEN LoadCC( code, y ) END;
       (** << fof  *)

   IF x.mode # Reg THEN
       x.type := PCT.Ptr;
       Load(code, x)
   ELSE
       GenConv(code, PCLIR.convu, x, PCLIR.Address, FALSE)
   END;
   x.mode := RegRel;  x.offs := 0;  x.type := y.type;
   IF get THEN
       Assign(code, y, x)
   ELSE
       Assign(code, x, y)
   END
END SYScopy;

PROCEDURE SYSaddress*(code: Code;  VAR x: Item);
BEGIN	LoadAdr(code, x);  x.type := PCT.Address
END SYSaddress;

PROCEDURE Inc*(code: Code; VAR x, y: Item; dec: BOOLEAN);(* lb, dk, fof *)
VAR size: PCBT.Size; x2: PCLIR.Register;
BEGIN
	LoadAdr(code, x); size := x.type.size(PCBT.Size);
	PCLIR.EmitLoadRelative(code, size.type, size.signed, x2, 0, x.adr);
	Load(code, y);
	IF dec THEN
	PCLIR.Emit12(code, PCLIR.sub, x2, x2, y.adr);
	ELSE
	PCLIR.Emit12(code, PCLIR.add, x2, x2, y.adr);
	END;
	PCLIR.EmitStoreRelative(code, 0, x.adr, x2)
END Inc;



PROCEDURE Inline*(code: Code;  VAR x: PCM.Attribute);
BEGIN
	PCLIR.EmitInline(code, x);
END Inline;

(* obsolete since May 22, 2007: ug *)
(**-----------Passivate----------------*)
(*
AWAIT (cond);
	....
	jmp afterAwait
passivate(StaticLink: LONGINT):
	enter (passivate calling convention: set SL to EBP, avoid scope switch)
	compute cond
	return cond
afterAwait:
	push EBP
	call passivate
	result R
	cmp R, TRUE
	jeq skip
	syscall passivate
skip:
	....
*)

PROCEDURE AwaitEnter*(code: Code;  VAR adr: PCM.Attribute);
VAR padr: PCBT.Procedure;
BEGIN
	NEW(padr, PCBT.context, FALSE);
	PCLIR.EmitEnter(code, PCBT.OberonPassivateCC, padr);
	adr := padr;
END AwaitEnter;

PROCEDURE AwaitExit*(code: Code;  cond: Item);
BEGIN
	Load(code, cond);
	PCLIR.Emit01(code, PCLIR.ret, cond.adr);
	PCLIR.EmitExit(code, PCBT.OberonPassivateCC, PCT.AddressSize, NIL)
END AwaitExit;

PROCEDURE Await*(code: Code;  self: Item;  adr: PCM.Attribute);
	(* SysAwait (cond, slink, obj, flags) *)
VAR  procAddr: PCBT.Procedure;  res, true: Item;  reg: PCLIR.Register;  label: Label;
BEGIN
	procAddr := adr(PCBT.Procedure);
	PCLIR.Emit01(code, PCLIR.push, PCLIR.FP);	(*static link*)
	PCLIR.EmitCall(code, procAddr);
	Result(code, res, PCT.Bool);
	MakeIntConst(true, True, PCT.Bool);
	RelOp(code, PCS.eql, res, true);
	label := none;
	Jcc(code, label, res);
		(*syscall*)
	PCLIR.EmitLoadAddr(code, reg, 0, procAddr);
	PCLIR.Emit01(code, PCLIR.push, reg);
	PCLIR.Emit01(code, PCLIR.push, PCLIR.FP);
	IF PCT.IsPointer(self.type) THEN
		Load(code, self)
	ELSE
		LoadAdr(code, self)
	END;
	PCLIR.Emit01(code, PCLIR.push, self.adr);
	PCLIR.EmitLoadConst(code, reg, PCLIR.Address, FALSE, False);
	PCLIR.Emit01(code, PCLIR.push, reg);
	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.passivate);
	FixJmp(code, label);
END Await;

(**-----------Control Flow----------------*)

(** PushSL - push the static link (SL), for local procedures only *)

PROCEDURE PushSL*(code: Code;  deltaLevel: SHORTINT);
VAR  reg: LONGINT;
BEGIN
	ASSERT(deltaLevel >= -1);
	GetActivationFrame(code, deltaLevel+1, reg);
	PCLIR.Emit01(code, PCLIR.push, reg)
END PushSL;

(** SaveRegisters - save registers before a procedure call *)

PROCEDURE SaveRegisters*(code: Code);
BEGIN  PCLIR.Emit00(code, PCLIR.saveregs);
END SaveRegisters;

(** RestoreRegisters - restore registers after a procedure call *)

PROCEDURE RestoreRegisters*(code: Code);
BEGIN  PCLIR.Emit00(code, PCLIR.loadregs);
END RestoreRegisters;

PROCEDURE ParamArray(code: Code;  VAR ap: Item;  formaltype: PCT.Struct;  reference, notag: BOOLEAN); (* ejz  *)
VAR  aptype: PCT.Struct;  res, res2: Item;  dim: LONGINT;  fptype: PCT.Array;
BEGIN
	fptype := formaltype(PCT.Array);  aptype := ap.type;
	dim := 0;

	IF  (fptype.mode = PCT.open) OR reference THEN	(* prepare "reference" *)
		LoadAdr(code, ap);
		reference := TRUE
	ELSE
		reference := FALSE;
	END;
	WHILE ~notag & (fptype # NIL) & (fptype.mode = PCT.open) DO (* ejz *)
		IF fptype.base = PCT.Byte THEN
			IF (aptype = PCT.String) THEN
				MakeIntConst(res, ap.value, PCT.Int32)
			ELSIF (aptype IS PCT.Array) THEN
				ArrayDim(code, res, ap, dim);
				MakeIntConst(res2, GetStaticSize(aptype(PCT.Array).base), PCT.Int32);
				DOp(code, PCS.times, res, res2)
			ELSE
				MakeIntConst(res, GetStaticSize(aptype), PCT.Int32);
			END
		ELSE
			IF aptype # PCT.String THEN
				aptype := aptype(PCT.Array).base
			ELSE
				ASSERT(fptype.base = PCT.Char8)
			END;
			ArrayDim(code, res, ap, dim);  INC(dim)
		END;
		Load(code, res);
		PCLIR.Emit01(code, PCLIR.push, res.adr);
		IF  fptype.base IS PCT.Array  THEN  fptype := fptype.base(PCT.Array)  ELSE  fptype := NIL  END
	END;

	IF reference THEN
		PCLIR.Emit01(code, PCLIR.push, ap.adr)
	ELSE
		ASSERT(~notag); (* ejz *)
		dim := GetStaticSize(fptype);
		StackAllocate(code, dim, res);
		CopyBlock(code, res, ap, dim)
	END
END ParamArray;

(** fof >> *)
	PROCEDURE AdrToStack*( code: Code;  VAR ptr: Item );
	VAR size: LONGINT; t: PCT.Struct;
	BEGIN
		IF ptr.mode # Reg THEN LoadAdr( code, ptr ) END;
		IF (ptr.type IS PCT.EnhArray) & (ptr.type(PCT.EnhArray).mode = PCT.open) THEN  (* ensure right dimension in array descriptor *)
			SetEnhArrayDim( code, ptr, ptr.type( PCT.EnhArray ).dim );   (* trick, as this might be not initialized *)
			t := PCT.ElementType(ptr.type);
			size := t.size(PCBT.Size).size;
			SetEnhArraySize(code,ptr,size);
		END;
		PCLIR.Emit01( code, PCLIR.push, ptr.adr );
	END AdrToStack;

	PROCEDURE PushStaticEnhArray*(code: Code; VAR ap: Item;  formaltype: PCT.Struct; reference: BOOLEAN);
	VAR aptype: PCT.Struct;  res: Item;  dim: LONGINT; fptype: PCT.EnhArray;
	BEGIN
		IF ap.mode # Reg THEN LoadAdr(code,ap) END;
		fptype := formaltype( PCT.EnhArray );  aptype := ap.type;
		ASSERT(aptype = fptype);
		IF reference THEN PCLIR.Emit01( code, PCLIR.push, ap.adr )
		ELSE
			dim := GetStaticSize( fptype );
			StackAllocate( code, dim, res );
			CopyBlock( code, res, ap, dim )
		END
	END PushStaticEnhArray;
	PROCEDURE ParamTensor( code: Code;  VAR ap: Item;  formaltype: PCT.Struct;
												  reference: BOOLEAN );
		VAR size: LONGINT; t: PCT.Struct;
BEGIN
		IF reference THEN
		(* caution! var parameter not handled as pointer to pointer to array *)
			LoadAdr( code, ap );
			IF ap.type IS PCT.EnhArray THEN
				SetEnhArrayDim( code, ap, ap.type( PCT.EnhArray ).dim );   (* trick, as this might be not initialized *)
			t := PCT.ElementType(ap.type);
			size := t.size(PCBT.Size).size;
			SetEnhArraySize(code,ap,size);
			END;
			PCLIR.Emit01( code, PCLIR.push, ap.adr );   (* push reference to array reference  *)
		ELSE
			IF ap.type IS PCT.Tensor THEN
				DerefTensor( code, ap );   (* caution! var parameter not handled as pointer to pointer to array *)
			ELSIF ap.type IS PCT.EnhArray THEN
				SetEnhArrayDim( code, ap, ap.type( PCT.EnhArray ).dim );   (* trick, as this might be not initialized *)
				t := PCT.ElementType(ap.type);
			size := t.size(PCBT.Size).size;
			SetEnhArraySize(code,ap,size);
			END;
			IF formaltype IS PCT.Tensor THEN
				ap.offs := 0;   (* report pointer to real position in heap *)
			ELSE
				ASSERT ( formaltype IS PCT.EnhArray, 119 );
			END;
			IF ap.mode # Reg THEN LoadAdr( code, ap );  END;
			PCLIR.Emit01( code, PCLIR.push, ap.adr );   (* push array reference  *)
		END;
	END ParamTensor;

	PROCEDURE RangeDescriptorHead*( code: Code;  VAR ap,dim,descr: Item );
	VAR adr, const: PCLIR.Register;  t: PCT.Struct;
	BEGIN
		t := PCT.ElementType(ap.type);
		PCLIR.EmitLoadConst(code,const,PCLIR.Int32,FALSE,t.size(PCBT.Size).size);
		PCLIR.Emit01( code, PCLIR.push, const );

		Load(code,dim);
		PCLIR.Emit01(code,PCLIR.push,dim.adr);
		PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE ,
											SYSTEM.VAL( LONGINT, {RangeFlag} ) );   (* flags, no reallocation *)
		PCLIR.Emit01( code, PCLIR.push, adr );
		PCLIR.Emit01( code, PCLIR.push, ap.adr );   (* push array reference  *)
		
		IF descr.mode # Reg THEN LoadAdr( code, descr );  END;
		PCLIR.EmitLoadRelative(code,PCLIR.Address,TRUE,adr,Descr_PtrOffs*PCT.AddressSize,descr.adr); (* load current flags from the descriptor *)
		PCLIR.Emit01( code, PCLIR.push, adr );   (*  ptr *)
		(* code only necessary if we want to refer to the array descriptor afterwards.*)
		PCLIR.EmitLoadConst( code, const, PCLIR.Int32, FALSE ,0 (* ap.type(PCT.EnhArray).dim * 8 + Descr_LenOffs*PCT.AddressSize *) );
		PCLIR.Emit12( code, PCLIR.add, ap.adr, PCLIR.SP, const );   (* addr of ap now points to descriptor field on the *)
	END RangeDescriptorHead;

	PROCEDURE ArrayDescriptorToStack*( code: Code;  VAR arr: Item );
	VAR type: PCT.EnhArray;  dest, sizeItem, res: Item;  size: LONGINT;  adr: PCLIR.Register;
		dim: LONGINT;  t: PCT.Struct; const: PCLIR.Register;
	BEGIN
		type := arr.type( PCT.EnhArray );  size := type.dim * 8 + Descr_LenOffs*PCT.AddressSize;
		IF type.mode = PCT.open THEN
			StackAllocate( code, size, dest );  LoadAdr( code, dest );
			LoadAdr( code, arr );  MakeIntConst( sizeItem, size, PCT.Int32 );
			arr.type := PCT.Int32;  MoveBlock( code, dest, arr, sizeItem );
			t := PCT.ElementType(type);
		MakeIntConst( sizeItem, t.size(PCBT.Size).size, PCT.Int32 );
		Load( code, sizeItem ); PCLIR.EmitStoreRelative( code, Descr_SizeOffs*PCT.AddressSize, PCLIR.SP, sizeItem.adr );

			MakeIntConst( sizeItem, type.dim, PCT.Int32 );  Load( code, sizeItem );
			PCLIR.EmitStoreRelative( code, Descr_DimOffs*PCT.AddressSize, PCLIR.SP, sizeItem.adr );
			arr.type := type;
		ELSE
			dim := type.dim;
			WHILE (dim > 0) DO
				DEC( dim );  EnhArrayInc( code, res, arr, dim );  Load( code, res );
				PCLIR.Emit01( code, PCLIR.push, res.adr );   (* push increment *)
				EnhArrayLen( code, res, arr, dim );  Load( code, res );
				PCLIR.Emit01( code, PCLIR.push, res.adr );   (* push len *)
			END;

		t := PCT.ElementType(type);
		PCLIR.EmitLoadConst(code,const,PCLIR.Address,FALSE,t.size(PCBT.Size).size);
		PCLIR.Emit01( code, PCLIR.push, const );

			PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE , type.dim );
			PCLIR.Emit01( code, PCLIR.push, adr );
			PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, {RangeFlag} ) );   (* to protect size *)
			PCLIR.Emit01( code, PCLIR.push, adr );
			IF arr.mode # Reg THEN LoadAdr( code, arr );  END;
			PCLIR.Emit01( code, PCLIR.push, arr.adr );
			PCLIR.Emit01( code, PCLIR.push, arr.adr );
		END;
	END ArrayDescriptorToStack;

	PROCEDURE ParamEnhArray*( code: Code;  VAR ap: Item; formaltype: PCT.Struct;  reference: BOOLEAN;  VAR spoffset: LONGINT );   (*fof*)
	VAR aptype: PCT.Struct;  res, res2: Item;  dim: LONGINT;  fptype: PCT.EnhArray;
		adr,const: PCLIR.Register;  t: PCT.Struct;
	BEGIN

		IF (formaltype IS PCT.EnhArray) THEN  (* otherwise only the pointer is remaining, see PCB.ExprList.Emit *)
			fptype := formaltype( PCT.EnhArray );  aptype := ap.type;  dim := 0;

			IF ((fptype.mode = PCT.open) OR reference) THEN  (* load array reference, if not already loaded  *)
				IF ap.mode # Reg THEN LoadAdr( code, ap );  END;
				reference := TRUE
			END;

			dim := fptype.dim;

			WHILE (dim > 0) DO
				DEC( dim );  EnhArrayInc( code, res2, ap, dim );  Load( code, res2 );
				PCLIR.Emit01( code, PCLIR.push, res2.adr );   (* push increment *)
				INC( spoffset, 4 );  EnhArrayLen( code, res, ap, dim );  Load( code, res );
				PCLIR.Emit01( code, PCLIR.push, res.adr );   (* push len *)
				INC( spoffset, 4 );
			END;

			dim := fptype.dim;
		ELSE
			reference := TRUE;   (* leading dimensions have been written to stack *)
		END;
		t := PCT.ElementType(ap.type);
		PCLIR.EmitLoadConst(code,const,PCLIR.Address,FALSE,t.size(PCBT.Size).size);
		PCLIR.Emit01( code, PCLIR.push, const );

		PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE , dim );   (*! replace by correct overal dimension *)
		PCLIR.Emit01( code, PCLIR.push, adr );
		PCLIR.EmitLoadConst( code, adr, PCLIR.Address, FALSE , SYSTEM.VAL( LONGINT, {} ) );
		PCLIR.Emit01( code, PCLIR.push, adr );  INC( spoffset, 8 );

		IF reference THEN
			LoadArrayAdr( code, ap, res );
			PCLIR.Emit01( code, PCLIR.push, res.adr );   (* push array reference  *)
			INC( spoffset, 4 );
		ELSE
			dim := GetStaticSize( fptype );  StackAllocate( code, dim, res );
			CopyBlock( code, res, ap, dim )
		END;
	END ParamEnhArray;

	PROCEDURE PushStackRelAddress*( code: Code;  offset: LONGINT );
	VAR sp: PCLIR.Register;
	BEGIN
		PCLIR.EmitLoadConst( code, sp, PCLIR.Address, FALSE , offset );
		PCLIR.Emit12( code, PCLIR.add, sp, PCLIR.SP, sp );
		PCLIR.Emit01( code, PCLIR.push, sp );
	END PushStackRelAddress;

	PROCEDURE MakeStackEnhArrayItem*( code: Code;  VAR i: Item;   type: PCT.Struct );   (*fof*)
	VAR a: PCT.Struct;  zero: PCLIR.Register;
		PROCEDURE MakeOpenArray( type: PCT.Struct );
		VAR res: LONGINT;  ea: PCT.EnhArray;
		BEGIN
			IF type IS PCT.EnhArray THEN
				MakeOpenArray( type( PCT.EnhArray ).base );  NEW( ea );
				PCT.InitOpenEnhArray( ea, a, {PCT.open}, res );
				PCT.SetEnhArrayLen( ea, type( PCT.EnhArray ).len );   (* KernelLog.Enter();  KernelLog.String( "MakeOpenArray, len= " );  KernelLog.Int( ea.len, 10 );
				KernelLog.Exit;  *)
				a := ea;
			ELSE a := type;
			END;
		END MakeOpenArray;
	BEGIN
		ASSERT ( type IS PCT.EnhArray );
		MakeOpenArray( type );  i.type := a;
		ASSERT ( a IS PCT.EnhArray );
		i.adr := 0;  i.breg := 0;  i.offs := 0;  i.mode := RegRel;
		PCLIR.EmitLoadConst( code, zero, PCLIR.Address, FALSE , 0 );
		PCLIR.Emit12( code, PCLIR.add, i.adr, zero, PCLIR.SP );   (* PCLIR.Emit12( code, PCLIR.add, i.breg, zero, PCLIR.SP );  *)  (* RegRel -> is loaded later! *)
	END MakeStackEnhArrayItem;
(** << fof  *)

	(* fof for linux *)
	PROCEDURE RevertStack*( code: Code;  offset: LONGINT );
	VAR sp: PCLIR.Register;
	BEGIN
		PCLIR.EmitLoadConst( code, sp, PCLIR.Address, FALSE , offset );
		PCLIR.Emit12( code, PCLIR.add, sp, PCLIR.SP, sp );
		PCLIR.Emit01( code, PCLIR.loadsp, sp );
	END RevertStack;

(** Param -  Push actual parameter on the stack *)

PROCEDURE Param*(code: Code; VAR ap: Item;  formaltype: PCT.Struct;  reference, notag: BOOLEAN); (* ejz *)
VAR res: Item;  mode, size: LONGINT;  name: ARRAY 32 OF CHAR;
BEGIN
	IF (formaltype IS PCT.Basic) OR (formaltype IS PCT.Pointer) THEN
		IF Statistics THEN INC(AParBasic) END;
		IF (ap.type = PCT.Float32) & (ap.mode # Reg) THEN	(*optimize move*)
			ap.type := PCT.Int32
		END;
		IF reference THEN  LoadAdr(code, ap)  ELSE  Load(code, ap)  END;
		PCLIR.Emit01(code, PCLIR.push, ap.adr)
	ELSIF formaltype IS PCT.Record THEN
		IF Statistics THEN INC(AParRec) END;
		IF reference THEN
			IF ~notag THEN (* ejz *)
				GetTD(code, ap, res, FALSE);  Load(code, res);  PCLIR.Emit01(code, PCLIR.push, res.adr)
			END;
			LoadAdr(code, ap);  PCLIR.Emit01(code, PCLIR.push, ap.adr)
		ELSE
			ASSERT(~notag); (* ejz *)
			size := GetStaticSize(formaltype);
			StackAllocate(code, size, res);  CopyBlock(code, res, ap, size)
		END
	ELSIF formaltype IS PCT.Array THEN
		IF Statistics THEN INC(AParArray) END;
		ParamArray(code, ap, formaltype, reference, notag) (* ejz *)
	(** fof >> *)
	ELSIF formaltype IS PCT.EnhArray THEN
		HALT( 100 );   (* ParamEnhArray must be handled directly *)
	ELSIF formaltype IS PCT.Tensor THEN
		ParamTensor( code, ap, formaltype, reference );
	(** << fof  *)
	ELSIF (formaltype IS PCT.Delegate) THEN
		IF Statistics THEN INC(AParProc) END;
		IF reference THEN
			LoadAdr(code, ap)
		ELSE
			mode := ap.mode;
			Load(code, ap);
			IF ~(PCT.StaticMethodsOnly IN formaltype.flags) THEN
				PCLIR.Emit01(code, PCLIR.push, GetDelegateSelfReg(code, ap, mode))
			END
		END;
		PCLIR.Emit01(code, PCLIR.push, ap.adr)
	ELSE
		PCDebug.GetTypeName(formaltype, name);
		PCM.LogWLn; PCM.LogWStr("PCC.Param, unimplemented ");
		PCM.LogWStr(name);
		PCDebug.ToDo(PCDebug.NotImplemented)
	END
END Param;

(** Call - Call procedure *)

PROCEDURE Call*(code: Code; VAR x: Item);
VAR zero: PCLIR.Register; l: Label;
BEGIN
	IF x.mode = Proc THEN
		PCLIR.EmitCall(code, x.proc)
	ELSIF x.type = MethodType THEN	(*method call: self already pushed*)
		ASSERT(x.mode = Reg, 500);
		PCLIR.Emit01(code, PCLIR.callreg, x.adr)
	ELSIF ~(PCT.StaticMethodsOnly IN x.type.flags) THEN
		Load(code, x);
		PCLIR.EmitLoadConst(code, zero, PCLIR.Address, FALSE, 0);
		l := code.pc;
		PCLIR.Emit02C(code, CCTab[ccEQ], x.breg, zero, none);	(*fwd jmp*)
		PCLIR.Emit01(code, PCLIR.push, x.breg);
		PCLIR.FixList(code, l, code.pc);
		PCLIR.Emit0C(code, PCLIR.label, 0);
		PCLIR.Emit01(code, PCLIR.callreg, x.adr)
	ELSE
		Load(code, x);
		PCLIR.Emit01(code, PCLIR.callreg, x.adr)
	END
END Call;

(** Result - Retrieve a result after a Call *)

PROCEDURE Result*(code: Code; VAR x: Item;  type: PCT.Struct);
VAR  size: PCBT.Size;
BEGIN
	IF (type IS PCT.Array) THEN
		x.mode := Proc; x.type := type
	(** fof >> *)
	ELSIF (type IS PCT.EnhArray) THEN x.mode := Proc;  x.type := type;
	ELSIF type IS PCT.Tensor THEN
		x.mode := Proc;  x.type := type;
	(** << fof  *)
	ELSIF ~(type IS PCT.Record) THEN
		size := type.size(PCBT.Size);
		PCLIR.Emit10(code, PCLIR.result, x.adr, size.type, size.signed);
		x.mode := Reg; x.type := type; x.proc := NIL;
		IF (type IS PCT.Delegate) & ~(PCT.StaticMethodsOnly IN type.flags) THEN
			PCLIR.Emit10(code, PCLIR.result2, x.breg, PCLIR.Address, FALSE)
		END
	END
END Result;

PROCEDURE DefFinallyLabel*(code: Code; obj: PCT.Symbol);
BEGIN
	PCLIR.EmitFinallyLabel(code, obj.adr);
END DefFinallyLabel;

(** Define a label *)

PROCEDURE DefLabel*(code: Code; VAR pc: Label);
BEGIN  pc := code.pc; PCLIR.Emit0C(code, PCLIR.label, 0)
END DefLabel;


(** Jump to label. If label is none, then autodefine *)

PROCEDURE Jmp*(code: Code; VAR pc: Label);
BEGIN
	PCLIR.Emit0C(code, PCLIR.jmp, pc);
	pc := code.pc-1
END Jmp;

(** Conditional Jump to label *)

PROCEDURE Jcc*(code: Code; VAR pc: Label; VAR cond: Item);
VAR	reg, t: LONGINT;
BEGIN
	ASSERT(cond.type = PCT.Bool);
	IF cond.mode # CC  THEN
		IF cond.mode # Reg THEN  Load(code, cond)  END;
		reg := cond.adr;
		PCLIR.EmitLoadConst(code, t, PCLIR.Int8, FALSE, True);
		InitCC(cond, ccEQ, reg, t)
	END;
	ASSERT(cond.mode = CC);

	IF pc # none THEN	(*Back. Jmp*)
		PCLIR.FixList(code, cond.tlist, pc);
		IF cond.adr # ccNone THEN PCLIR.Emit02C(code, CCTab[cond.adr], cond.value, cond.breg, pc) END
	ELSIF cond.adr # ccNone THEN
		pc := code.pc;
		PCLIR.Emit02C(code, CCTab[cond.adr], cond.value, cond.breg, cond.tlist)
	ELSE
		pc := cond.tlist
	END;
	FixJmp(code, cond.flist)
END Jcc;

(** Fixup Forward jumps to label *)

PROCEDURE FixJmp*(code: Code; VAR pc: Label);
BEGIN  PCLIR.FixList(code, pc, code.pc); PCLIR.Emit0C(code, PCLIR.label, 0)
END FixJmp;

(** Case Instruction - jump on x *)

PROCEDURE CaseStat*(code: Code;  VAR case: Item;  x: Item);
BEGIN
	case.mode := Case;
	Convert(code, x, PCT.Int32, FALSE);
	Load(code, x);
	PCLIR.EmitCase(code, case.adr, x.adr);
END CaseStat;

PROCEDURE CaseLine*(code: Code;  case: Item;  low, high: LONGINT);
	VAR  i: LONGINT;
BEGIN
	ASSERT(case.mode = Case);
	FOR i := low TO high DO
		PCLIR.EmitCaseLine(code, case.adr, i)
	END
END CaseLine;

PROCEDURE CaseElse*(code: Code;  case: Item);
BEGIN
	ASSERT(case.mode = Case);
	PCLIR.EmitCaseElse(code, case.adr);
END CaseElse;

PROCEDURE InitInterface*(code: Code; rec, intf: PCT.Record);
	VAR x, td, mth, dst: Item; m: PCT.Proc; o: PCT.Symbol;
BEGIN
	ASSERT(intf.ptr # NIL);
	StackAllocate(code, 4, x); x.type := intf.ptr;
	SysNewRec(code, x);
	MakeStackItem(x, PCT.Ptr);
	Load(code, x); x.mode := RegRel; x.offs := 0;
	MakeTD(td, rec);
	Assign(code, x, td);

	m := intf.scope.firstProc;
	WHILE m # NIL DO
		o := PCT.FindSameSignature(rec.scope, m.name, m.scope.firstPar, TRUE);
		IF o # NIL THEN	(*checked in PCT*)
			mth := td; mth.mode := RegRel; mth.offs := MethodTable * PCT.AddressSize - PCT.AddressSize*o.adr(PCBT.Method).mthNo;
			dst := x; dst.mode := RegRel; dst.offs := IntfMethodTable * PCT.AddressSize + PCT.AddressSize*m.adr(PCBT.Method).mthNo;
			Assign(code, dst, mth)
		END;
		m := m.nextProc
	END;
	PCLIR.Emit0C(code, PCLIR.syscall, PCBT.registerinterface)
(*
	FreeStack(code, PCT.Ptr)
*)
END InitInterface;

(**-----------Module Admin----------------*)

PROCEDURE Init;
VAR size: PCBT.Size;
BEGIN
	NEW(size); size.size := 8; size.align := 4; size.containPtrs := TRUE; size.type := PCLIR.Address;
	NEW(MethodType); MethodType.size := size;
END Init;

(** Cleanup - call after each compilation to unlink global structures for garbage collection *)

PROCEDURE Cleanup*;
VAR i: LONGINT; (* fof *)
BEGIN
	delegate := NIL;
	hdptr := NIL;
	topscope := NIL;
	(** fof >> *)
	FOR i := 0 TO LEN( anyarr ) - 1 DO anyarr[i] := NIL;  END;
	(** << fof  *)
END Cleanup;

BEGIN
	CCTab[ccAlways] := PCLIR.jmp; CCTab[ccNever] := PCLIR.nop;
	CCTab[ccEQ] := PCLIR.je; CCTab[ccNE] := PCLIR.jne;
	CCTab[ccLT] := PCLIR.jlt; CCTab[ccLE] := PCLIR.jle;
	CCTab[ccGT] := PCLIR.jgt; CCTab[ccGE] := PCLIR.jge;
	CCTab[ccB] := PCLIR.jb; CCTab[ccBE] := PCLIR.jbe;
	CCTab[ccA] := PCLIR.ja; CCTab[ccAE] := PCLIR.jae;
	CCTab[ccF] := PCLIR.jf; CCTab[ccNF] := PCLIR.jnf;

	InvCCTab[ccAlways] := PCLIR.nop; InvCCTab[ccNever] := PCLIR.jmp;
	InvCCTab[ccEQ] := PCLIR.jne; InvCCTab[ccNE] := PCLIR.je;
	InvCCTab[ccLT] := PCLIR.jge; InvCCTab[ccLE] := PCLIR.jgt;
	InvCCTab[ccGT] := PCLIR.jle; InvCCTab[ccGE] := PCLIR.jlt;
	InvCCTab[ccB] := PCLIR.jae; InvCCTab[ccBE] := PCLIR.ja;
	InvCCTab[ccA] := PCLIR.jbe; InvCCTab[ccAE] := PCLIR.jb;
	InvCCTab[ccF] := PCLIR.jnf; InvCCTab[ccNF] := PCLIR.jf;

	InvCC[ccAlways] := ccNever; InvCC[ccNever] := ccAlways;
	InvCC[ccEQ] := ccNE; InvCC[ccNE] := ccEQ;
	InvCC[ccLT] := ccGE; InvCC[ccLE] := ccGT;
	InvCC[ccGT] := ccLE; InvCC[ccGE] := ccLT;
(*
	InvCC[ccLT] := ccLE; InvCC[ccLE] := ccLT;
	InvCC[ccGT] := ccGE; InvCC[ccGE] := ccGT;
*)
	InvCC[ccB] := ccAE; InvCC[ccBE] := ccA;
	InvCC[ccA] := ccBE; InvCC[ccAE] := ccB;
	InvCC[ccF] := ccNF; InvCC[ccNF] := ccF;

	SetCCTab[ccAlways] := PCLIR.nop; SetCCTab[ccNever] := PCLIR.nop;
	SetCCTab[ccEQ] := PCLIR.sete; SetCCTab[ccNE] := PCLIR.setne;
	SetCCTab[ccLT] := PCLIR.setlt; SetCCTab[ccLE] := PCLIR.setle;
	SetCCTab[ccGT] := PCLIR.setgt; SetCCTab[ccGE] := PCLIR.setge;
	SetCCTab[ccB] := PCLIR.setb; SetCCTab[ccBE] := PCLIR.setbe;
	SetCCTab[ccA] := PCLIR.seta; SetCCTab[ccAE] := PCLIR.setae;
	SetCCTab[ccF] := PCLIR.setf; SetCCTab[ccNF] := PCLIR.setnf;

	Init;

	IF Trace THEN PCM.LogWLn; PCM.LogWStr("PCC.Trace on") END;
	IF Statistics THEN PCM.LogWLn; PCM.LogWStr("PCC.Statistics on") END
END PCC.

(*
	24.06.03	prk	Remove TDMask (no need to mask typedescriptors)
	06.04.03	prk	assigning an static method to a delegate failed (double load, original mode lost); set self to NIL by default
	25.02.03	prk	emit load memory in GetMemory (avoids that SYSTEM.VAL / project changes the size and thus the move)
	28.12.02	prk	touch stack every memory page when copying arrays longer than a memory page
	21.07.02	prk	ODD, reload const to avoid duplicate virtual register use (this seems to confuse the i386 optimizer)
	11.06.02	prk	Access to dimensions in multidimensional dynamic and open arrays corrected
	11.06.02	prk	BIT implemented
	02.04.02	prk	Fix in LoadAdr (copy hw-register when load addr of 0[reg])
	18.03.02	prk	PCBT code cleanup and redesign
	05.02.02	prk	PCT.Find cleanup
	22.11.01	prk	improved flag handling
	02.11.01	prk	fixed return of a function call with non-primitive type
	01.11.01	prk	unlink untraced pointers explicitly
	16.08.01	prk	keep PCBT.Variable offset, ignore for imported vars
	10.08.01	prk	PCBT.Procedure: imported: BOOLEAN replaced by owner: Module
	23.07.01	be	CAP fix
	23.07.01	prk	PushRetDesc, assert removed (too strong)
	23.07.01	prk	new array with a SYSTEM.PTR must call NewArr instead of NewSys
	05.07.01	prk	optional explicit NIL checks
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	06.06.01	prk	use string pool for object names
	28.05.01	prk	Bug in local dynamic array allocation fixed
	17.05.01	prk	Delegates
	14.05.01	prk	PCLIR.lea removed
	11.05.01	prk	correct handling of operation with hw-regs; PCLIR.loadsp instruction; PCC stack ops fixed
	11.05.01	prk	When freeing stack, use pop instead of add (up to three words)
	07.05.01	be	register sign information added in the back-end
	26.04.01	prk	PCLIR.lea partly removed
	25.04.01	prk	array allocation: if length < 0 then trap PCM.ArraySizeTrap
	20.04.01	prk	CAP fixed, HOTBuiltinCAP1.Mod HOTBuiltinCAP2.Mod passed now
	11.04.01	prk	Allow SYSTEM.VAL(static array, int const), used in Raster.Mod
	25.03.01	prk	limited HUGEINT implementation (as abstract type)
	25.03.01	prk	NewSysBlock, NewArray: force sizes to be LInt
	15.03.01	prk	delegates: return
	14.03.01	prk	improved delegates implementation
	13.03.01	prk	delegates fix (parameters)
	13.03.01	prk	Statistics
	22.02.01	prk	delegates
*)