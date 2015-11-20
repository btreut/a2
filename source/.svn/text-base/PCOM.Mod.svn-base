(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCOM; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: symbol file plug-in"; *)


(*
	PaCo, OM Symbol File Generator

	Warning: the SF tags must still be fine-tuned
	- remove SFcproc and fill hole
	- is SFtypSptr used?

	This file doesn't match exactly the OM-Format from mf/tk!

	SymFile   =  {modname} 0X
	             [SFConst {Structure name val}]
	             [SFvar {[SFreadonly] Structure name}]
	             [SFxproc {Structure name ParList}]
	             (* [SFlproc {Structure name ParList}] *)
	             [SFoperator {Structure name ParList}]
	             [SFcproc {Structure name ParList code}]
	             [SFalias {Structure name}]
	             [SFtyp {Structure}]
	             SFEnd.
	 ParList   = {[SFvar] Structure name} SFEnd.
	 Structure = Basic | UserStr | oldstr | modno (name | 0X oldimpstrn).
	 Basic     = SFtypBool .. SFtypNilTyp.
	 UserStr   = [SFinvisible][SFsysflag flag] UserStr2.
	 UserStr2  = (SFtypOpenArr | SFtypDynArr) Structure name
	             | SFtypArray Structure name sizen
	             | SFtypPointer Structure name
	             | SFtypProcTyp Structure name ParList
	             | SFtypRecord Structure name prion flagsn RecStr
	 RecDef    = {[SFreadonly] Structure name}[SFtproc {Structure name ParList}] SFend.

	 name      object name written with 0X compression (last char incremented by 80X)
	           initializers start with "&"
	           record bodies @Body

	 records   invisible fields and methods are exported with name ""
	           prio: any LONGINT
	           flags: SET
	           	bit 0   	Protectable
	           	bit 2       Active
	           	bit 3   	Safe

	 oldstr    internal structure numbering  ]-oo, 0] (!!! OM ]-oo, -1] !!!)
	           on first export of an UserStr, a refnr is assigned, used then for
	           further exports

	 oldimpstr external structure numbering  [0, +oo[
	           on first re-export of a structure, a refnr is assigned and then used
	           for all the succesive exports
	           Every imported module has an own re-export numbering.

	 1, 2, 4:  Size of the value
	 n:        compressed number (WriteNum/ReadNum)

*)


IMPORT
		SYSTEM, Modules, StringPool, PCM, PCS, PCT, PCBT, PCLIR, Diagnostics;

CONST
		Trace = FALSE;
		TraceCalls = FALSE;	(*exported procedures*)
		TraceImport = FALSE;

		StrictChecks = TRUE;	(*some more sanity checks*)

		TraceFPName = "D1";
		TraceFP = TRUE;

		ImportedModuleFlag = {};
(*
		ImportedModuleFlag = {PCT.Overloading};
*)

(*
		ProgTools.Enumerate 01
		SFtypBool SFtypChar8 SFtypInt8 SFtypInt16 SFtypInt32 SFtypInt64
		SFtypFloat32 SFtypFloat64 SFtypSet SFtypString SFtypNoTyp SFtypNilTyp
		SFtypByte SFtypSptr
		SFmod1
		~

		ProgTools.Enum 01
		SFtypBool SFtypChar8 SFtypChar16 SFtypChar32 SFtypInt8 SFtypInt16 SFtypInt32 SFtypInt64
		SFtypFloat32 SFtypFloat64
		SFtypSet SFtypString SFtypNoTyp SFtypNilTyp
		SFtypByte SFtypSptr
		SFmod1
		~
*)

		(* Symbol File Tags *)
		UndefTag = -1;
(*
		SFtypBool=01H; SFtypChar8=02H; SFtypInt8=03H; SFtypInt16=04H; SFtypInt32=05H; SFtypInt64=06H;
		SFtypFloat32=07H; SFtypFloat64=08H; SFtypSet=09H; SFtypString=0AH; SFtypNoTyp=0BH; SFtypNilTyp=0CH;
		SFtypByte=0DH; SFtypSptr=0EH;
		SFmod1=0FH;
*)
		SFtypBool =   1; SFtypChar8 =   2; SFtypChar16 =   3; SFtypChar32 =   4;
		SFtypInt8 =   5; SFtypInt16 =   6; SFtypInt32 =   7; SFtypInt64 =   8;
		SFtypFloat32 =   9; SFtypFloat64 =  10; SFtypSet =  11; SFtypString =  12;
		SFtypNoTyp =  13; SFtypNilTyp =  14; SFtypByte =  15; SFtypSptr =  16;
		SFmod1 =  17;

		SFlastStruct = SFtypSptr;

		SFmodOther=2DH;
		SFtypOpenArr=2EH; SFtypDynArr=2FH; SFtypArray=30H; SFtypPointer=31H; SFtypRecord=32H; SFtypProcTyp=33H;
		SFsysflag=34H; SFinvisible=35H; SFreadonly=36H;  SFobjflag = 37H; (* fof: very (!) bad idea to have same number for two type flags *)
		SFconst=37H; SFvar=38H;
		SFlproc=39H; SFxproc=3AH; SFoperator=3BH; SFtproc=3CH; SFcproc = SFtproc;
		SFalias=3DH; SFtyp=3EH;
		SFend= 3FH;
		(** fof >> *)
		SFtypOpenEnhArr = 40H;  SFtypDynEnhArr = 41H;  SFtypTensor=42H; SFtypStaticEnhArray = 43H;    (*fof*)
		(** << fof  *)
		(* workaround: handle inlined operators *)
		InlineMarker = 0ABH;

		SFdelegate = 5;

		(*Fingerprints/Obj Modes*)
		FPMvar=1; FPMpar=1; FPMvarpar=2; FPMconst=3; FPMfield=4; FPMtype=5; FPMxproc=7; FPMcproc=9;
		FPMmethod=13;
		FPMinit=14;


		(*Fingerprints/Type Forms*)
		FPFbyte = 1;
		FPFbool=2; FPFchar8=3; FPFint8typ=4; FPFint16typ=5; FPFint32typ=6; FPFfloat32typ=7; FPFfloat64typ=8;
		FPFsettyp=9; FPFstringtyp=10;
		FPFnotyp = 12;
		FPFpointer=13; FPFproc=14; FPFcomp=15;
		FPFint64typ=16;
		FPFchar16typ = 17;
		FPFchar32typ = 18;

		FPFbasic=1; FPFstaticarr=2;  FPFdynarr=4;  FPFopenarr=5; FPFrecord=6;

		FPintern=0; FPextern=1; FPexternR=2; FPothervis =3;
		FPfalse=0; FPtrue=1;

		FPhasBody = 2H; FPprotected = 10H; FPactive = 20H;

		FPdelegate = 5; FPsystemType = 6;

		empty = -1; 	(*empty string index*)

		readonly = PCT.Internal + {PCT.PublicR};

TYPE
	ReadStringProc = PROCEDURE (VAR R: PCM.SymReader; VAR string: ARRAY OF CHAR);
	StringBuf = ARRAY 256 OF CHAR;
	ImportList = POINTER TO ARRAY OF StringPool.Index;

	Symbol* = OBJECT (PCM.Attribute)		(*attributes for PCT.Symbol*)
	VAR
			fp*: LONGINT;		(*fingerprint*)
			sibling: PCT.Symbol;
	END Symbol;

	Struct* = OBJECT (PCM.Attribute)		(*attributes for PCT.Struct*)
		VAR
			fp*, pbfp*, pvfp*: LONGINT;		(*fingerprint*)
			fpdone* {UNTRACED} : PCT.Module;	(*module relative to which the fp has been computed*)
			strref*: LONGINT;	(*import: index for struct array*)
			tag: LONGINT;	 (*tag->export/import number*)
			uref*: LONGINT;
			mod*: PCT.Module;		(*defining module*)

		PROCEDURE & Init*(mod: PCT.Module);
		BEGIN	fpdone := NIL;  tag := UndefTag;  fp := 0; pbfp := 0; pbfp := 0;
			IF mod # NIL THEN SELF.mod := mod.scope.owner END	(* canonical representation *)
		END Init;
	END Struct;

	StructArray = POINTER TO ARRAY OF PCT.Struct;

	Module* = OBJECT  (PCM.Attribute)		(*attributes for PCT.Module*)
		VAR
			nofimp: LONGINT;	import: PCT.ModuleArray;		(*import: list of all modules imported by SELF, [0..nofimp[*)
			nofstr: LONGINT;	struct: StructArray;			(*import: list of own structures, [0..nofstr[ *)
			nofreimp: LONGINT;	reimp: StructArray;		(*import of main: list of structs used by main, [0..nofreimp[*)
			expnumber: LONGINT;										(*export of main: this module reference [1..oo[ ; OM uses mode for this*)
			changed: BOOLEAN;										(*self-import: imported obj doesn't exist anymore*)

		PROCEDURE & Init*;
		BEGIN
			changed:=FALSE;
			nofimp:=0;  nofstr:=0;  nofreimp:=0; expnumber:=0;
			NEW(struct, 32);
		END Init;
	END Module;

VAR
		predefStruct: ARRAY SFlastStruct+1 OF PCT.Struct;
(*
		FPvis: ARRAY 5 OF SHORTINT;
*)
		FParray: ARRAY 6 OF SHORTINT;


		altSelf: PCS.Name;	(*predefined strings*)

		Ninterfaces, NpatchPointer0: LONGINT;

(** ========== Symbol Table Checker ============== *)
(** ---------- Fingerprinting -------------- *)
PROCEDURE FPrint(VAR fp: LONGINT; val: LONGINT);
BEGIN fp:=SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ROT(fp, 7)) / SYSTEM.VAL(SET, val))
END FPrint;

PROCEDURE FPrintSet(VAR fp: LONGINT; set: SET);
BEGIN FPrint(fp, SYSTEM.VAL(LONGINT, set))
END FPrintSet;

PROCEDURE FPrintReal(VAR fp: LONGINT; real: REAL);
BEGIN FPrint(fp, SYSTEM.VAL(LONGINT, real))
END FPrintReal;

PROCEDURE FPrintLReal(VAR fp: LONGINT; lr: LONGREAL);
	VAR l, h: LONGINT;
BEGIN
	SYSTEM.GET(ADDRESSOF(lr)+4, l); SYSTEM.GET(ADDRESSOF(lr), h);
	FPrint(fp, l); FPrint(fp, h);
END FPrintLReal;

PROCEDURE FPrintName*(VAR fp: LONGINT; name: ARRAY OF CHAR);
	VAR i: INTEGER; ch: CHAR;
BEGIN i:=0; REPEAT ch:=name[i]; FPrint(fp, ORD(ch)); INC(i) UNTIL ch=0X
END FPrintName;

PROCEDURE FPrintVis(VAR fp: LONGINT; vis: SET);
BEGIN
	IF vis = PCT.Public THEN  FPrint(fp, FPextern)
	ELSIF vis = readonly THEN  FPrint(fp, FPexternR)
	ELSIF vis = PCT.Internal THEN  FPrint(fp, FPintern)
	ELSE
		FPrint(fp, FPothervis + SYSTEM.VAL(LONGINT, vis))
(*
		HALT(99)
*)
	END
END FPrintVis;

PROCEDURE FPrintSign(VAR fp: LONGINT;  par: PCT.Parameter;  self: PCT.Parameter;  ret: PCT.Struct;  current: PCT.Module;
										isOperator: BOOLEAN);

	PROCEDURE FPrintPar(VAR fp: LONGINT;  par: PCT.Parameter;  current: PCT.Module);
	VAR str: StringBuf;
	BEGIN
		IF par.ref THEN  FPrint(fp, FPMvarpar)  ELSE  FPrint(fp, FPMpar)  END;
		IF par.type # NIL THEN FPrintTyp0(par.type, current); FPrint(fp, par.type.sym(Struct).fp) END;
		IF isOperator & (par.type # NIL) & (par.type.owner # NIL) THEN
			StringPool.GetString(par.type.owner.name, str);
			FPrintName(fp, str);
		END;
	END FPrintPar;

BEGIN
	FPrintTyp0(ret, current);  FPrint(fp, ret.sym(Struct).fp);
	IF self # NIL THEN  FPrintPar(fp, self, current)  END;
	WHILE (par#self) DO
		FPrintPar(fp, par, current);
		par:=par.nextPar
	END;
END FPrintSign;

PROCEDURE FPrintMeth(VAR pbfp, pvfp: LONGINT; mth, init, body: PCT.Method;  current: PCT.Module);
	VAR fp: LONGINT; oAttr: Symbol; str: StringBuf;
BEGIN
	IF (mth.vis # PCT.Internal) THEN
		IF mth.sym=NIL  THEN  NEW(oAttr); mth.sym:=oAttr  ELSE  oAttr := mth.sym(Symbol)  END;
		fp:=0;
		FPrint(fp, FPMmethod);
		StringPool.GetString(mth.name, str); FPrintName(fp, str);
		FPrintSign(fp, mth.scope.firstPar, mth.self, mth.type, current, FALSE);
(*
		IF mth = init THEN  FPrint(fp, -1)  END;
*)
		oAttr.fp:=fp;	(* mfix *)
		FPrint(fp, mth.adr(PCBT.Method).mthNo);
		IF mth # body THEN
			FPrint(pbfp, fp); FPrint(pvfp, fp)
		END
	END
END FPrintMeth;

PROCEDURE FPrintRecord(typ: PCT.Record;  current: PCT.Module);
	VAR p: PCT.Symbol; fld: PCT.Variable; adr, i, flags, fp, pbfp, pvfp: LONGINT; tAttr: Struct;  oAttr: Symbol;
			scope: PCT.RecScope; intf: PCT.Interface;
			name: ARRAY 32 OF CHAR; dump: BOOLEAN;
			str: StringBuf;
BEGIN
	IF TraceFP THEN
		PCT.GetTypeName(typ, name); dump := name = TraceFPName
	END;
	tAttr := typ.sym(Struct);
	pvfp := tAttr.fp; pbfp := tAttr.fp;
	IF TraceFP & dump THEN
		PCM.LogWLn; PCM.LogWStr("FPRec, Base "); PCM.LogWHex(pvfp)
	END;
	scope := typ.scope;
	IF typ.intf # NIL THEN
		FOR i := 0 TO LEN(typ.intf)-1 DO
			intf := typ.intf[i];
			FPrintTyp(intf, current);
			tAttr := intf.sym(Struct);
			FPrint(pvfp, tAttr.pvfp);
			FPrint(pbfp, tAttr.pbfp);
		END
	END;
	IF  typ.brec#NIL  THEN
		tAttr := typ.brec.sym(Struct);
		FPrint(pvfp, tAttr.pvfp);
		FPrint(pbfp, tAttr.pbfp);
	END;
	IF TraceFP & dump THEN
		PCM.LogWLn; PCM.LogWStr("FPRec, Init "); PCM.LogWHex(pvfp); PCM.LogWStr(" "); PCM.LogWHex(pbfp)
	END;

	p := scope.sorted;
	WHILE  p # NIL  DO
		IF p IS PCT.Method THEN
			WITH p: PCT.Method DO
			FPrintMeth(pbfp, pvfp, p, scope.initproc, scope.body, current);
				IF TraceFP & dump THEN
					PCM.LogWLn; PCM.LogWStr("FPRec, Mth "); PCM.LogWHex(pvfp); PCM.LogWStr(" "); PCM.LogWHex(pbfp);
					PCM.LogWStr("  "); PCM.LogWStr0(p.name);
					PCM.LogWStr("  ");
					PCM.LogWNum(p.adr(PCBT.Method).mthNo);
					PCM.LogWStr("  ");
					IF p = scope.body THEN PCM.LogWStr("B") END;
					IF p = scope.initproc THEN PCM.LogWStr("&") END
				END
			END
		END;
		p := p.sorted
	END;

	fld := scope.firstVar;
	WHILE  fld#NIL  DO
			FPrintTyp(fld.type, current);
			tAttr := fld.type.sym(Struct);
			IF fld.vis#PCT.Internal THEN fp:=0; FPrint(fp, FPMfield);
				StringPool.GetString(fld.name, str); FPrintName(fp, str);  FPrintVis(fp, fld.vis);
				IF PCM.Untraced IN fld.flags THEN  FPrint(fp, PCM.Untraced)  END;
				FPrint(fp, tAttr.fp);
				IF fld.sym = NIL THEN  NEW(oAttr);  fld.sym := oAttr  ELSE  oAttr := fld.sym(Symbol)  END;
				oAttr.fp:=fp;
				adr := fld.adr(PCBT.Variable).offset;
				FPrint(pbfp, tAttr.pbfp); FPrint(pbfp, adr);
				FPrint(pvfp, tAttr.pvfp);  FPrint(pvfp, adr);
				FPrint(pvfp, fp); FPrint(pbfp, fp);
			ELSE
				fp := 0;
				IF PCM.Untraced IN fld.flags THEN  FPrint(fp, PCM.Untraced)  END;
				FPrint(pvfp, fp)	(* seems an error to me, I would use  FPrint(pvfp, tAttr.fp) *)
			END;
			IF TraceFP & dump THEN
				PCM.LogWLn; PCM.LogWStr("FPRec, Fld "); PCM.LogWHex(pvfp); PCM.LogWStr(" "); PCM.LogWHex(pbfp);
				PCM.LogWStr("  "); PCM.LogWStr0(fld.name);
				PCM.LogWStr("  "); PCM.LogWNum(adr);
			END;
		fld := fld.nextVar
	END;
	IF ~(PCT.exclusive IN typ.mode) & (typ.brec # NIL) & (PCT.exclusive IN typ.brec.mode)THEN
		INCL(typ.mode, PCT.exclusive)
	END;
	flags := 0;
	IF scope.body # NIL THEN  INC(flags,  FPhasBody)  END;
	IF PCT.active IN typ.mode THEN  INC(flags,  FPactive)  END;
	IF PCT.exclusive IN typ.mode THEN  INC(flags, FPprotected)  END;
	FPrint(pbfp, flags);
	IF TraceFP & dump THEN
		PCM.LogWLn; PCM.LogWStr("FPRec, Flg "); PCM.LogWHex(pvfp); PCM.LogWStr(" ");  PCM.LogWHex(pbfp); PCM.LogWHex(flags)
	END;
	tAttr := typ.sym(Struct); tAttr.pbfp := pbfp; tAttr.pvfp := pvfp;	(* replace typ.pbfp with pbfp and typ.pvfp with pvfp *)
END FPrintRecord;

PROCEDURE FPrintTyp0(typ: PCT.Struct;  current: PCT.Module);
(* calculate fingerprint without looking at record fields, private and public fingerprints *)
	VAR fp, i: LONGINT; mode: SHORTINT; rec: PCT.Record; intf: PCT.Interface; tAttr: Struct;  base: PCT.Struct;
		name: ARRAY 32 OF CHAR; dump: BOOLEAN; str: StringBuf;

	PROCEDURE Name;	(*has side effects on the local variables!!!*)
		(* VAR str: StringBuf; *)
	BEGIN
		IF (tAttr.mod # NIL) & (tAttr.mod.scope # current.scope) THEN	(*imported*)
			StringPool.GetString(tAttr.mod.name, str);
			FPrintName(fp, str);
			IF typ.owner#NIL THEN  StringPool.GetString(typ.owner.name, str); FPrintName(fp, str)  ELSE  FPrint(fp, 0)  END
		END;
		IF dump THEN
			PCM.LogWLn; PCM.LogWStr("FPTyp0, Name "); PCM.LogWHex(fp);
			PCM.LogWStr("  "); PCM.LogWStr0(current.name);
			PCM.LogWStr("  "); PCM.LogWStr0(tAttr.mod.name);
			PCM.LogWStr("  "); PCM.LogWStr(str);
		END
	END Name;

BEGIN
	ASSERT(typ#NIL);
	IF ~(typ IS PCT.Basic) & (typ # PCT.String) & (typ # PCT.NilType) & (typ # PCT.NoType) THEN
		IF TraceFP THEN
			PCT.GetTypeName(typ, name);
			dump := name = TraceFPName
		END;
		IF typ.sym=NIL THEN  NEW(tAttr, current); typ.sym:=tAttr
(*
			;PCM.LogWLn; PCM.LogWStr("  struc0 ");
			IF typ.owner # NIL THEN PCM.LogWStr0(typ.owner.name) END
*)
		ELSE  tAttr:=typ.sym(Struct)  END;
		IF tAttr.fpdone # current THEN tAttr.fpdone := NIL END;	(* reset fpdone: fp can be changed without changing it calling through FPSign! *)
		fp:=0;
		IF  typ IS PCT.Pointer  THEN
			FPrint(fp, FPFpointer); FPrint(fp, FPFbasic); ASSERT(typ.flags = {});
			Name;
			tAttr.fp:=fp; base := typ(PCT.Pointer).base;
			FPrintTyp0(base, current); FPrint(tAttr.fp, base.sym(Struct).fp);
		ELSIF  typ IS PCT.Record  THEN
			FPrint(fp, FPFcomp); FPrint(fp, FPFrecord);
			IF PCT.SystemType IN typ.flags THEN FPrint(fp, FPsystemType) END;
			rec := typ(PCT.Record);
			Name;
			tAttr.fp:=fp;
			IF rec.intf # NIL THEN
				FOR i := 0 TO LEN(rec.intf)-1 DO
					intf := rec.intf[i];
					FPrintTyp0(intf, current);
					FPrint(tAttr.fp, intf.sym(Struct).fp)
				END
			END;
			IF rec.brec # NIL THEN FPrintTyp0(rec.brec, current);  FPrint(tAttr.fp, rec.brec.sym(Struct).fp) END;
			IF dump & (rec.brec # NIL) THEN PCM.LogWLn; PCM.LogWStr("FPTyp0, has base ") END
		ELSIF  typ IS PCT.Array  THEN
			WITH typ: PCT.Array DO
				mode := typ.mode;
				FPrint(fp, FPFcomp); FPrint(fp, FParray[mode]); ASSERT(typ.flags = {});
				Name;  tAttr.fp:=fp;
				IF mode IN {PCT.static, PCT.open} THEN
					FPrintTyp0(typ.base, current);
					FPrint(tAttr.fp, typ.base.sym(Struct).fp);
					IF  mode=PCT.static  THEN  FPrint(tAttr.fp, typ.len)  END
				END;
				tAttr.pbfp:=tAttr.fp; tAttr.pvfp:=tAttr.fp
			END
	(** fof >> *)
			ELSIF typ IS PCT.EnhArray THEN  (*fof*)
				WITH typ: PCT.EnhArray DO
					mode := typ.mode;
					FPrint( fp, FPFcomp );  FPrint( fp, FParray[mode] );   (*ASSERT(typ.flags = {});*)
					Name;  tAttr.fp := fp;
					IF mode IN {PCT.static, PCT.open} THEN
						FPrintTyp0( typ.base, current );  FPrint( tAttr.fp, typ.base.sym( Struct ).fp );
						IF mode = PCT.static THEN FPrint( tAttr.fp, typ.len ) END
					END;
					tAttr.pbfp := tAttr.fp;  tAttr.pvfp := tAttr.fp
				END
			ELSIF typ IS PCT.Tensor THEN
				WITH typ: PCT.Tensor DO
					FPrint( fp, FPFcomp );
					Name;  tAttr.fp := fp;
					FPrintTyp0( typ.base, current );  FPrint( tAttr.fp, typ.base.sym( Struct ).fp );
					tAttr.pbfp := tAttr.fp;  tAttr.pvfp := tAttr.fp
				END;
		(** << fof  *)
		ELSIF  typ IS PCT.Delegate THEN
			WITH typ: PCT.Delegate DO
				FPrint(fp, FPFproc); FPrint(fp, FPFbasic);
				IF ~(PCT.StaticMethodsOnly IN typ.flags) THEN FPrint(fp, FPdelegate) END;
				Name;  tAttr.fp:=fp;
				FPrintSign(tAttr.fp, typ.scope.firstPar, NIL,  typ.return, current, FALSE);
				tAttr.pbfp:=tAttr.fp; tAttr.pvfp:=tAttr.fp
			END
		END;
		IF dump THEN
			PCM.LogWLn; PCM.LogWStr("FPTyp0, End "); PCM.LogWHex(tAttr.fp)
		END
	END
END FPrintTyp0;

PROCEDURE FPrintTyp*(typ: PCT.Struct;  current: PCT.Module);
(* fpdone  0: not done yet  >0: done for module fpdone-1  =-1: built in type *)
	VAR tAttr: Struct; name: ARRAY 32 OF CHAR;
BEGIN
	current := current.scope.owner;	(* canonical representation *)
	IF  typ.sym=NIL  THEN  NEW(tAttr, current); typ.sym:=tAttr
(*
			;PCM.LogWLn; PCM.LogWStr("  struct ");
			IF typ.owner # NIL THEN PCM.LogWStr0(typ.owner.name) END
*)
	ELSE  tAttr:=typ.sym(Struct)  END;
	IF ~(typ IS PCT.Basic) & (tAttr.fpdone # current) THEN
		IF TraceCalls THEN
			PCT.GetTypeName(typ, name);
			PCM.LogWLn; PCM.LogWStr("->FPrintTyp "); PCM.LogWStr(name);
		END;
		FPrintTyp0(typ, current);
		IF ~(typ IS PCT.Record) THEN tAttr.fpdone := current END;
		IF typ IS PCT.Pointer THEN FPrintTyp(typ(PCT.Pointer).base, current)
		ELSIF typ IS PCT.Array THEN FPrintTyp(typ(PCT.Array).base, current)
(** fof >> *)
		ELSIF typ IS PCT.EnhArray THEN
			FPrintTyp( typ( PCT.EnhArray ).base, current ) (*fof*)
		ELSIF typ IS PCT.Tensor THEN
			FPrintTyp( typ( PCT.Tensor ).base, current ) (*fof*)
(** << fof  *)
		ELSIF typ IS PCT.Record THEN
			WITH typ: PCT.Record DO
				FPrintTyp(typ.btyp, current);
				IF (typ.brec # NIL) & (typ.brec.sym(Struct).fpdone # current) THEN
					PCT.GetTypeName(typ, name);
	(*
					PCM.LogWLn; PCM.LogWStr("    FPTyp, warning "); PCM.LogWStr(name);
	*)
					FPrintTyp(typ.brec, current)
				END;
				FPrintRecord(typ, current)
			END
		END;
		tAttr.fpdone:=current;
		IF TraceCalls THEN
			PCM.LogWLn; PCM.LogWStr("<-FPrintTyp "); PCM.LogWStr(name);
		END;
		IF TraceFP THEN
			PCT.GetTypeName(typ, name);
			IF name = TraceFPName THEN
				PCM.LogWLn; PCM.LogWStr("FPTyp "); PCM.LogWHex(tAttr.fp);
				PCM.LogWStr(" ");
				PCM.LogWHex(tAttr.pvfp);
				PCM.LogWStr(" ");
				PCM.LogWHex(tAttr.pbfp);
			END
		END
	END;
END FPrintTyp;

(** fof >> *)
	PROCEDURE FPrintConstEnhArray( VAR fp: LONGINT;  val: PCT.Value );
	BEGIN
		IF val.vis # PCT.Internal THEN PCM.Error( -1, -1, "const arrays not fingerprinted yet" )
		END;   (* otherwise a change does not change the module *)
	END FPrintConstEnhArray;
(** << fof  *)

PROCEDURE FPrintObj*(obj: PCT.Symbol;  current: PCT.Module);
	VAR fp, len, pos: LONGINT; con: PCT.Const; oAttr: Symbol;  c: PCLIR.AsmBlock; str: StringBuf;
BEGIN
	current := current.scope.owner;	(* canonical representation *)
(*PCM.LogWLn; PCM.LogWStr("FPrintObj "); PCM.LogWStr(obj.name);*)
	StringPool.GetString(obj.name, str);
	IF TraceCalls THEN
		PCM.LogWLn; PCM.LogWStr("->FPrintObj "); PCM.LogWStr(str);
	END;
	fp:=0;
	IF obj.sym=NIL  THEN  NEW(oAttr); obj.sym:=oAttr  ELSE  oAttr:=obj.sym(Symbol)  END;
	IF obj IS PCT.Value THEN
		FPrint(fp, FPMconst); FPrintName(fp, str); FPrintVis(fp, obj.vis);
		IF obj.type.sym # NIL THEN  (** fof  070731*)
			FPrint(fp, obj.type.sym(Struct).fp);
		END;   (** fof  070731 *)
		FPrint(fp, FPFbasic);
		con:=obj(PCT.Value).const;
		IF  con.type=PCT.Bool  THEN
			IF con.bool  THEN  FPrint(fp, FPtrue)  ELSE  FPrint(fp, FPfalse)  END
		ELSIF  con.type=PCT.Char8  THEN FPrint(fp, con.int)
		ELSIF  con.type=PCT.Int64  THEN FPrintLReal(fp, SYSTEM.VAL(LONGREAL, con.long))
		ELSIF  PCT.IsCardinalType(con.type)  THEN FPrint(fp, con.int)
		ELSIF  con.type=PCT.Set  THEN FPrintSet(fp, con.set)
		ELSIF  con.type=PCT.Float32  THEN FPrintReal(fp, SHORT(con.real))
		ELSIF  con.type=PCT.Float64  THEN FPrintLReal(fp, con.real)
		ELSIF  con.type=PCT.String  THEN FPrintName(fp, con.str^)
(** fof >> *)
		ELSIF con.type IS PCT.EnhArray THEN
			FPrintConstEnhArray( fp, obj( PCT.Value ) );
(** << fof  *)
		ELSE
			HALT(99)
		END
	ELSIF obj IS PCT.GlobalVar THEN
		FPrint(fp, FPMvar); FPrintName(fp, str); FPrintVis(fp, obj.vis);
		FPrintTyp(obj.type, current); FPrint(fp, obj.type.sym(Struct).fp);
	ELSIF (obj IS PCT.Proc)&(obj.vis=PCT.Public) THEN
		WITH obj: PCT.Proc DO
			IF PCT.Inline IN obj.flags THEN
				FPrint(fp, FPMcproc); FPrintName(fp, str); FPrintVis(fp, obj.vis);
				FPrintSign(fp, obj.scope.firstPar, NIL, obj.type, current, PCT.Operator IN obj.flags);
				c := obj.scope.code(PCLIR.AsmInline).code;
				WHILE c # NIL DO
					len := c.len; pos := 0;
					FPrint(fp, len);
					WHILE pos < len DO  FPrint(fp, ORD(c.code[pos])); INC(pos) END;
					c := c.next
				END;
			ELSE
				FPrint(fp, FPMxproc);
				FPrintName(fp, str); FPrintVis(fp, obj.vis);
				FPrintSign(fp, obj.scope.firstPar, NIL, obj.type, current, PCT.Operator IN obj.flags)
			END
		END
	ELSIF obj IS PCT.Type THEN
		FPrint(fp, FPMtype);
		FPrintName(fp, str);
		FPrintVis(fp, obj.vis);
		FPrintTyp(obj.type, current); FPrint(fp, obj.type.sym(Struct).fp);
	END;
	oAttr.fp:=fp;
	IF TraceCalls THEN
		PCM.LogWLn; PCM.LogWStr("<-FPrintObj "); PCM.LogWStr(str);
	END
END FPrintObj;

(* ========== Symbol File Saver ============== *)

PROCEDURE Export*(VAR r: PCM.Rider; M: PCT.Module; new, extend, skipImport: BOOLEAN; VAR msg: ARRAY OF CHAR);
	VAR name: StringBuf;
		oldM: PCT.Module; nofstruct: LONGINT;
		newsym, changed, extended: BOOLEAN; MAttr: Module;
		impList: ImportList;

	PROCEDURE TypeChanged(new, old: PCT.Struct): BOOLEAN;
	VAR  newstr, oldstr: Struct;
	BEGIN
		IF (new IS PCT.Record) THEN	(* if type composition different -> fp different! *)
			newstr := new.sym(Struct);  oldstr := old.sym(Struct);
			RETURN (newstr.pbfp # oldstr.pbfp) OR (newstr.pvfp # oldstr.pvfp)
		ELSIF (new IS PCT.Pointer) THEN
			RETURN TypeChanged(new(PCT.Pointer).base,  old(PCT.Pointer).base)
		ELSIF (new IS PCT.Array) THEN
			RETURN TypeChanged(new(PCT.Array).base,  old(PCT.Array).base)
(** fof >> *)
		ELSIF (new IS PCT.EnhArray) THEN  (*fof*)
			RETURN TypeChanged( new( PCT.EnhArray ).base, old( PCT.EnhArray ).base )
		ELSIF (new IS PCT.Tensor) THEN
			RETURN TypeChanged( new( PCT.Tensor ).base, old( PCT.Tensor ).base )
(** << fof  *)
		END;
		RETURN FALSE
	END TypeChanged;

	PROCEDURE CompareSymbol(new: PCT.Symbol; e, s: BOOLEAN);
		VAR old: PCT.Symbol;  newsym: Symbol;
	BEGIN
		IF Trace THEN PCM.LogWLn; PCM.LogWStr("PCOM.Compare "); PCM.LogWStr0(new.name) END;
		FPrintObj(new, M);	(*always compute the fp, will be used by other compiler components*)
		newsym := new.sym(Symbol);  old := newsym.sibling;
		IF old # NIL THEN	(* an old version exists .... *)
			FPrintObj(old, M);
			(* operators are not checked for changes *)
			IF ~(PCT.Operator IN new.flags) THEN
				IF  (old.sym(Symbol).fp # newsym.fp) OR
					((new IS PCT.Type) OR (new.type IS PCT.Record) & (new.type.owner = NIL)) & TypeChanged(new.type, old.type) THEN
					changed:=TRUE; PCM.ErrorN(402, Diagnostics.Invalid, new.name)
				END
			END
		ELSIF new.vis # PCT.Internal THEN	(*new export*)
			extended:=TRUE; PCM.ErrorN(403, Diagnostics.Invalid, new.name)
		END
	END CompareSymbol;

	PROCEDURE OutParList(p: PCT.Parameter);
	(* export procedure parameters. Methods: self is already exported *)
	BEGIN
		WHILE  (p # NIL) & (p.name # PCT.SelfName)  DO
			IF PCT.WinAPIParam IN p.flags THEN (* ejz *)
				PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.WinAPIParam)
			ELSIF PCT.CParam  IN p.flags THEN (* fof for Linux *)
				PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.CParam)
			END;
			IF  p.ref  THEN  PCM.SymWNum(r, SFvar);  END;
(** fof >> *)
			IF PCM.ReadOnly IN p.flags THEN (* fof *)
				PCM.SymWNum(r, SFreadonly);
			END;
(** << fof  *)
			OutObj(p);
			p := p.nextPar
		END;
		PCM.SymWNum(r,SFend)
	END OutParList;

	PROCEDURE OutConst(c: PCT.Const);
	VAR type: PCT.Struct;
	BEGIN
		type := c.type;
		IF type = PCT.Char8 THEN  PCM.SymWNum(r, c.int)
		ELSIF type = PCT.Int64 THEN PCM.SymWLReal(r, SYSTEM.VAL(LONGREAL, c.long))
		ELSIF PCT.IsCardinalType(type) THEN  PCM.SymWNum(r, c.int)
		ELSIF type = PCT.Float32 THEN  PCM.SymWReal(r, SHORT(c.real))
		ELSIF type = PCT.Float64 THEN  PCM.SymWLReal(r, c.real)
		ELSIF type = PCT.String THEN  PCM.SymWString(r, c.str^)
		ELSIF type = PCT.Bool THEN  PCM.SymWNum(r, SYSTEM.VAL(SHORTINT, c.bool))
		ELSIF type = PCT.Set THEN  PCM.SymWNum(r, SYSTEM.VAL(LONGINT, c.set))
(** fof >> *)
		ELSIF type IS PCT.EnhArray THEN
			PCM.Error( 200, -1, "const arrays cannot be exported yet" );
(** << fof  *)
		ELSE	HALT(99)
		END
	END OutConst;

	PROCEDURE OutImpMod(name: ARRAY OF CHAR; mAttr: Module);
		VAR  m: Module;  index: StringPool.Index;
	BEGIN
		IF mAttr.expnumber = 0 THEN	(*first export from this module*)

			(* PCM.SymWMod(r, name);		(*real name, not alias*) *)
			StringPool.GetIndex(name, index);
			AddImport(impList, index);

(*
			m := mAttr.main.sym(Module);
			ASSERT(mAttr.main = M);
*)
			m := M.sym(Module);
			INC(m.expnumber);
			mAttr.expnumber := m.expnumber;  mAttr.nofreimp := 0
		END
	END OutImpMod;

	PROCEDURE OutRecord(rec: PCT.Record);
		VAR scope: PCT.RecScope; str: StringBuf; fld: PCT.Variable; mth: PCT.Method; first: BOOLEAN;
	BEGIN
		scope := rec.scope;
		PCM.SymWSet(r, rec.mode);
		PCM.SymW(r, CHR(rec.prio));
		fld := scope.firstVar;
		WHILE fld # NIL DO		(*fields*)
			IF  PCM.Untraced IN fld.flags  THEN  PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.Untraced)  END;
			IF  fld.vis=readonly  THEN  PCM.SymWNum(r, SFreadonly)  END;
			OutStruct(fld.type);
			IF  fld.vis=PCT.Internal  THEN PCM.SymWString(r, "")  ELSE  StringPool.GetString(fld.name, str); PCM.SymWString(r, str)  END;
			fld := fld.nextVar
		END;
		mth := scope.firstMeth; first := TRUE;
		WHILE mth # NIL DO		(*methods*)
			IF ~(PCT.copy IN mth.flags) THEN
				IF first THEN PCM.SymWNum(r, SFtproc); first := FALSE END;
				IF PCT.RealtimeProc IN mth.flags THEN PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.RealtimeProc) END; (* ug *)
				OutStruct(mth.type);
				IF  mth.vis = PCT.Internal  THEN PCM.SymWString(r, "") END;
				IF  mth = scope.initproc  THEN  PCM.SymW(r, "&")  END;
				StringPool.GetString(mth.name, str); PCM.SymWString(r, str);

				IF mth.self.ref THEN  PCM.SymWNum(r, SFvar) END;
				OutStruct(mth.self.type);
				PCM.SymWString(r, PCT.SelfNameStr);
				OutParList(mth.scope.firstPar);
				(* Indlined methods: only meant for Indexer *)
				IF (PCT.Inline IN mth.flags) & (PCT.Indexer IN mth.flags) THEN
					PCM.SymWNum(r, InlineMarker);
					OutInline(mth.scope.code);
				END;
			END;
			mth := mth.nextMeth
		END;
		PCM.SymWNum(r, SFend)
	END OutRecord;

	PROCEDURE OutStruct(typ: PCT.Struct);
		VAR  tAttr: Struct;  mAttr: Module;  name: StringBuf;  ptyp: PCT.Delegate;
			i: LONGINT; mname, tname: ARRAY 64 OF CHAR;
	BEGIN
		IF  typ.sym=NIL  THEN  NEW(tAttr, M);  typ.sym:=tAttr
(*
			;PCM.LogWLn; PCM.LogWStr("  outstr ");
			IF typ.owner # NIL THEN PCM.LogWStr0(typ.owner.name) END
*)
		ELSE  tAttr := typ.sym(Struct)  END;
		ASSERT((tAttr.mod = NIL) OR (tAttr.mod = tAttr.mod.scope.owner), 500);
		ASSERT(M = M.scope.owner, 501);
		IF  (tAttr.mod # NIL) & (tAttr.mod # M)  THEN	(*imported, reexport*)
			mAttr := tAttr.mod.sym(Module);
			IF StrictChecks THEN
				i := 0;
				WHILE (M.imports[i].sym # mAttr) DO INC(i)  END;	(*check if in imports -> initialized*)
				StringPool.GetString(M.imports[i].name, mname);
				PCT.GetTypeName(typ, tname);
				i := 0;
				WHILE (mAttr.struct[i] # typ) DO INC(i)  END;	(*check typ in struct -> initialized*)
			END;
			StringPool.GetString(tAttr.mod.name, name); OutImpMod(name, mAttr);
			IF mAttr.expnumber > (SFmodOther - SFmod1) THEN  PCM.SymWNum(r, SFmodOther); PCM.SymWNum(r, mAttr.expnumber-1)
(*
;Out.Ln; Out.String("has more than "); Out.Int(SFmodOther - SFmod1, 0); Out.String("imports ");
*)
			ELSE PCM.SymWNum(r, SFmod1+mAttr.expnumber-1) END;
(*
			IF mAttr.expnumber > 31 THEN  PCM.SymWNum(r, SFmodOther); PCM.SymWNum(r, mAttr.expnumber-1)
			ELSE PCM.SymWNum(r, SFmod1+mAttr.expnumber-1) END;
*)
			IF  tAttr.tag = UndefTag THEN
				StringPool.GetString(typ.owner.name, name);
				PCM.SymWString(r, name);  tAttr.tag := mAttr.nofreimp; INC(mAttr.nofreimp)
			ELSE
				PCM.SymW(r, 0X); PCM.SymWNum(r, tAttr.tag)
			END
		ELSIF  typ IS PCT.Basic THEN  PCM.SymWNum(r, tAttr.tag)
		ELSIF  (typ=PCT.String)OR(typ=PCT.NilType)OR(typ=PCT.NoType) THEN  PCM.SymWNum(r, tAttr.tag)
		ELSIF  tAttr.tag # UndefTag THEN  PCM.SymWNum(r, -tAttr.tag)
		ELSE  tAttr.tag := nofstruct; INC(nofstruct);
			IF (typ.owner # NIL) & (typ.owner.vis = PCT.Internal)  THEN  PCM.SymWNum(r, SFinvisible)
			ELSIF (typ IS PCT.Record) & (typ.owner = NIL) THEN   PCM.SymWNum(r, SFinvisible)	(*inconsistency in symfile*)
			END;
			name:="";
			IF  typ.owner#NIL  THEN  StringPool.GetString(typ.owner.name, name)  END;

			IF  typ IS PCT.Delegate  THEN
				ptyp := typ(PCT.Delegate);
				IF ~(PCT.StaticMethodsOnly IN ptyp.flags) THEN PCM.SymWNum(r, SFsysflag); PCM.SymWNum(r, SFdelegate)  END;
				PCM.SymWNum(r, SFtypProcTyp);  OutStruct(ptyp.return);  PCM.SymWString(r, name);
				PCM.SymWSet(r, ptyp.flags * {PCT.WinAPIParam, PCT.CParam, PCT.RealtimeProcType});
				OutParList(ptyp.scope.firstPar)
			ELSIF  typ IS PCT.Record  THEN
				WITH typ: PCT.Record DO
					ASSERT((typ.btyp=PCT.NoType) OR (typ.btyp IS PCT.Record) OR (typ.btyp IS PCT.Pointer));
					PCM.SymWNum(r, SFtypRecord);
					IF typ.intf # NIL THEN
						IF (LEN(typ.intf) > 0) & ~(PCM.ExportDefinitions IN PCM.codeOptions) THEN PCM.LogWLn; PCM.LogWStr("Warning: exports definitions, but flag not set") END;
						FOR i := 0 TO LEN(typ.intf)-1 DO OutStruct(typ.intf[i]) END
					END;
					OutStruct(typ.btyp);
					PCM.SymWString(r, name);
					PCM.SymWNum(r, 0); (* realtime flags ignored in PACO *)
					OutRecord(typ)
				END
			ELSIF  typ IS PCT.Array  THEN
				WITH typ: PCT.Array DO
					ASSERT(typ.mode IN {PCT.open, PCT.static});
					IF typ.mode=PCT.open THEN
						PCM.SymWNum(r, SFtypOpenArr)
					ELSIF typ.mode=PCT.static THEN
						PCM.SymWNum(r, SFtypArray)
					ELSE HALT(99)
					END;
					OutStruct(typ.base);  PCM.SymWString(r, name);
					PCM.SymWNum(r, 0); (* realtime flags ignored in PACO *)
					IF  typ.mode=PCT.static  THEN  PCM.SymWNum(r, typ.len)  END
				END
(** fof >> *)
			ELSIF typ IS PCT.EnhArray THEN  (*fof*)
				WITH typ: PCT.EnhArray DO
					ASSERT ( typ.mode IN {PCT.open, PCT.static} );
					IF typ.mode = PCT.open THEN PCM.SymWNum( r, SFtypOpenEnhArr )
					ELSIF typ.mode = PCT.static THEN PCM.SymWNum( r, SFtypStaticEnhArray )
					ELSE HALT( 99 )
					END;
					OutStruct( typ.base );
					PCM.SymWString( r, name );
					IF typ.mode = PCT.static THEN PCM.SymWNum( r, typ.len ) END
				END
			ELSIF typ IS PCT.Tensor THEN
				WITH typ: PCT.Tensor DO
					PCM.SymWNum( r, SFtypTensor );
					OutStruct( typ.base ); PCM.SymWString( r, name );
				END;
(** << fof  *)
			ELSIF  typ IS PCT.Pointer  THEN
				PCM.SymWNum(r, SFtypPointer);  OutStruct(typ(PCT.Pointer).base);
				PCM.SymWString(r, name);
				PCM.SymWNum(r, 0); (* realtime flags ignored in PACO *)
			END
		END
	END OutStruct;

	PROCEDURE OutObj(o: PCT.Symbol);
		VAR str: StringBuf;
	BEGIN
		IF  PCM.Untraced IN o.flags  THEN  PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.Untraced)  END;
		IF o.vis = readonly THEN PCM.SymWNum(r, SFreadonly) END;
		OutStruct(o.type);  StringPool.GetString(o.name, str); PCM.SymWString(r, str)
	END OutObj;

	PROCEDURE OutInline(i: PCM.Attribute);
	VAR p: PCLIR.AsmBlock; len, pos, cnt: LONGINT;
	BEGIN
		WITH i: PCLIR.AsmInline DO
			ASSERT(i.fixup = NIL);
			p := i.code;  len := 0;
			WHILE p # NIL DO  INC(len, p.len);  p := p.next END;
			p := i.code;  pos := 0;  cnt := 0;
			IF len = 0 THEN
				PCM.SymW(r, 0X)
			ELSE
				WHILE pos < len DO
					IF cnt = 0 THEN
						cnt := 255;
						IF len < 255 THEN cnt := len END;
						PCM.SymW(r, CHR(cnt))
					END;
					IF pos >= p.len THEN  DEC(len, pos); p := p.next;  pos := 0  END;
					PCM.SymW(r, p.code[pos]);
					INC(pos); DEC(cnt)
				END
			END;
			PCM.SymW(r, 0X)
		END;
	END OutInline;

	PROCEDURE OutModule(m: PCT.Module);
		VAR first: BOOLEAN; i, j: LONGINT; str: StringBuf;
			mm: Module; scope: PCT.ProcScope;
			v: PCT.Variable; p: PCT.Proc; t: PCT.Type; c: PCT.Value; p1, p2, pTmp, t1: PCT.Symbol;
	BEGIN
		ASSERT(m.scope.state >= PCT.procdeclared);

		nofstruct := 0;
		PCM.SymWNum(r, 0);	(*end of imports*)
		IF Trace THEN  PCM.LogWLn; PCM.LogWStr("OM.OutModule/const") END;

		IF m.imports # NIL THEN	(* reset module and structures counters before exporting *)
			i := 0;
			WHILE (i < LEN(m.imports)) & (m.imports[i] # NIL) DO
				IF m.imports[i].sym # NIL THEN
					mm := m.imports[i].sym(Module);

					mm.expnumber := 0;
					mm.nofreimp := 0;
					FOR j := 0 TO mm.nofstr-1 DO
						mm.struct[j].sym(Struct).tag := UndefTag
					END
				ELSE
					PCM.LogWLn; PCM.LogWStr("  no sym: "); PCM.LogWStr0(m.imports[i].name)
				END;
				INC(i)
			END;
		END;

		IF PCM.error THEN RETURN END;		(*symfile is changed*)

		IF {PCT.Overloading} * m.flags # {} THEN
			PCM.SymWNum(r, SFsysflag); PCM.SymWNum(r, SYSTEM.VAL(LONGINT, m.flags * {PCT.Overloading}))
		END;
		p1 := NIL; p2 := NIL; t1 := NIL;
		c := m.scope.firstValue; first := TRUE;
		WHILE c # NIL DO
			IF ~newsym THEN CompareSymbol(c, extend, new) ELSIF c.vis # PCT.Internal THEN  FPrintObj(c, M)  END;
			IF c.vis # PCT.Internal THEN
				IF first THEN PCM.SymWNum(r, SFconst); first := FALSE END;
				OutObj(c);  OutConst(c.const)
			END;
			c := c.nextVal
		END;
		v := m.scope.firstVar; first := TRUE;
		WHILE v # NIL DO
			IF ~newsym THEN CompareSymbol(v, extend, new) ELSIF v.vis # PCT.Internal THEN  FPrintObj(v, M)  END;
			IF v.vis # PCT.Internal THEN
				IF first THEN PCM.SymWNum(r, SFvar); first := FALSE END;
				OutObj(v)
			END;
			v := v.nextVar
		END;
		(* ug: hidden variables are not written to the symbol file, scope.firstHiddenVar is not traversed. *)
		p := m.scope.firstProc; first := TRUE;
		WHILE p # NIL DO
			IF ~newsym THEN CompareSymbol(p, extend, new) ELSIF p.vis # PCT.Internal THEN  FPrintObj(p, M)  END;
			IF (p.vis # PCT.Internal) THEN
				IF ~(PCT.Inline IN p.flags) & ~(PCT.Operator IN p.flags) THEN
					IF first THEN PCM.SymWNum(r, SFxproc); first := FALSE END;
					IF PCT.RealtimeProc IN p.flags THEN PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.RealtimeProc) END; (* ug *)
					OutStruct(p.type); StringPool.GetString(p.name, str); PCM.SymWString(r, str); OutParList(p.scope.firstPar)
				ELSE
					p.dlink := p1; p1 := p
				END
			END;
			p := p.nextProc
		END;
(*
		IF p1 # NIL THEN
			PCM.SymWNum(r, SFcproc);
			REPEAT
				OutStruct(p1.type); StringPool.GetString(p1.name, str); PCM.SymWString(r, str);
				scope := p1(PCT.Proc).scope; OutParList(scope.firstPar); OutInline(scope.code);
				p1 := p1.dlink
			UNTIL p1 = NIL
		END;
*)
		first := TRUE;
		IF p1 # NIL THEN
			REPEAT
				pTmp := p1.dlink;
				IF (PCT.Operator IN p1.flags) THEN
					IF first THEN PCM.SymWNum(r, SFoperator); first := FALSE END;
					OutStruct(p1.type); StringPool.GetString(p1.name, str); PCM.SymWString(r, str);
					scope := p1(PCT.Proc).scope; OutParList(scope.firstPar);
					IF PCT.Inline IN p1.flags THEN PCM.SymWNum(r, InlineMarker); OutInline(scope.code) END;
				ELSE
					p1.dlink := p2; p2 := p1;
				END;
				p1 := pTmp;
			UNTIL p1 = NIL;
		END;
		IF p2 # NIL THEN
			PCM.SymWNum(r, SFcproc);
			REPEAT
				IF PCT.RealtimeProc IN p2.flags THEN PCM.SymWNum(r, SFobjflag); PCM.SymWNum(r, PCM.RealtimeProc) END; (* ug *)
				OutStruct(p2.type); StringPool.GetString(p2.name, str); PCM.SymWString(r, str);
				scope := p2(PCT.Proc).scope; OutParList(scope.firstPar); OutInline(scope.code);
				p2 := p2.dlink;
			UNTIL p2 = NIL;
		END;
		t := m.scope.firstType; first := TRUE;
		WHILE t # NIL DO
			IF ~newsym THEN CompareSymbol(t, extend, new) ELSIF t.vis # PCT.Internal THEN  FPrintObj(t, M)  END;
			IF t.vis # PCT.Internal THEN
				IF t # t.type.owner THEN	(*alias*)
					IF first THEN PCM.SymWNum(r, SFalias); first := FALSE END;
					OutObj(t)
				ELSE
					t.dlink := t1; t1 := t
				END
			END;
			t := t.nextType
		END;
		first := TRUE;
		WHILE t1 # NIL DO
			IF (t1.type.sym=NIL) OR (t1.type.sym(Struct).tag=UndefTag) THEN	(*not exported yet*)
				IF first THEN  PCM.SymWNum(r, SFtyp); first := FALSE  END;
				OutStruct(t1.type)
			END;
			t1 := t1.dlink
		END;

		(* write names of directly imported modules to symbol file *)
		IF m.directImps # NIL THEN
			FOR i := 0 TO LEN(m.directImps^) - 1 DO
				IF m.directImps[i] # NIL THEN
					AddImport(impList, m.directImps[i].name);
				END;
			END;
		END;

		(* add import list *)
		IF impList # NIL THEN
			i := 0;
			WHILE (i < LEN(impList^)-1) & (impList[i] # -1) DO
				StringPool.GetString(impList[i], str);
				PCM.SymWMod(r, str);
				INC(i);
			END
		END;

		IF Trace THEN  PCM.LogWLn; PCM.LogWStr("OM.OutModule/end") END;
		PCM.SymWNum(r, SFend);
	END OutModule;

BEGIN
	ASSERT(M#NIL);
	COPY("", msg);
	IF PCM.error THEN RETURN END;
	StringPool.GetString(M.name, name);
	newsym := FALSE;
	changed := FALSE;
	oldM := NIL;
	IF ~skipImport THEN
		Import(M, oldM, M.name);	(* import self, to check for changes *)
	END;
	IF oldM # NIL THEN
		changed := M.sym(Module).changed
	ELSE
		IF M.sym = NIL THEN NEW(MAttr); M.sym := MAttr; MAttr := NIL END;
		newsym := TRUE
	END;
	(*export*)
	ASSERT(M.flags - ImportedModuleFlag = {});	(*export overrides only if allowed*)
	OutModule(M);
	IF  PCM.error  THEN	RETURN  END;
	PCM.CloseSym(r);		(*commit file*)
	IF changed OR extended  THEN
		IF changed THEN
			IF newsym OR new THEN COPY("  new symbol file", msg) ELSE PCM.Error(155, Diagnostics.Invalid, "") END
		ELSIF extended THEN
			IF extend OR new THEN COPY("  extended symbol file", msg) ELSE PCM.Error(155, Diagnostics.Invalid, "") END
		END
	END
END Export;



(* ========== Symbol File Loader ============== *)

(** Double structure size, copy elements into new structure *)

PROCEDURE ExtendStructArray*(VAR a: StructArray);
	VAR b: StructArray; i: LONGINT;
BEGIN
	IF a=NIL THEN  NEW(a, 16)
	ELSE
		NEW(b, 2*LEN(a));
		FOR i := 0 TO LEN(a)-1 DO	b[i] := a[i]	END;
		a := b
	END
END ExtendStructArray;

PROCEDURE AddImport(VAR list: ImportList; idx: StringPool.Index);
VAR
	i: LONGINT;
	newList: ImportList;
BEGIN
	IF list = NIL THEN
		NEW(list, 16);
		FOR i := 0 TO LEN(list^)-1 DO
			list[i] := -1;
		END;
	END;

	i := 0;
	WHILE (i < LEN(list^)) & (list[i] # -1) & (list[i] # idx) DO INC(i) END;
	IF i >= LEN(list^) THEN
		(* double list and append module index *)
		NEW(newList, 2*LEN(list^));
		FOR i := 0 TO LEN(list^)-1 DO newList[i] := list[i]; END;
		FOR i := LEN(list^) TO LEN(newList^)-1 DO newList[i] := -1 END;
		newList[LEN(list^)] := idx;
		list := newList;
	ELSIF list[i] = -1 THEN
		(* append module index to list *)
		list[i] := idx;
	ELSE
		(* do nothing, module already in list *)
	END;
END AddImport;

(* ReadString - Read a 0X compressed string *)

PROCEDURE ReadString(VAR R: PCM.SymReader; VAR string: ARRAY OF CHAR);
	VAR i: INTEGER; ch: CHAR;
BEGIN i := 0;
	LOOP R.Char(ch);
		IF ch = 0X THEN string[i] := 0X; RETURN
		ELSIF ch < 7FX THEN string[i]:=ch; INC(i)
		ELSIF ch > 7FX THEN string[i] := CHR(ORD(ch)-80H); string[i+1] := 0X; RETURN
		ELSE (* ch = 7FX *) EXIT END
	END;
	LOOP R.Char(ch);
		IF ch = 0X THEN string[i]:=0X; RETURN
		ELSE string[i]:=ch; INC(i) END
	END;
END ReadString;

PROCEDURE ReadStringNoZeroCompress(VAR R: PCM.SymReader; VAR string: ARRAY OF CHAR);
	VAR i: INTEGER; ch: CHAR;
BEGIN
	i := 0;
	REPEAT
		R.Char(ch);
		string[i] := ch; INC(i);
	UNTIL ch = 0X;
END ReadStringNoZeroCompress;

PROCEDURE ReadStrIndex(VAR r: PCM.SymReader; readString: ReadStringProc; VAR s: PCS.Name);
	VAR name: ARRAY 256 OF CHAR;
BEGIN
	(* ReadString(r, name); *)
	readString(r, name);
	IF name = "" THEN
		s := empty
	ELSE
		StringPool.GetIndex(name, s)
	END
END ReadStrIndex;

PROCEDURE ImportComplete(m: PCT.Module);
VAR attr: Module; i: LONGINT;

	PROCEDURE RecordComplete(r: PCT.Record);
	BEGIN
		IF r.brec # NIL THEN  RecordComplete(r.brec)  END;
		PCT.ChangeState(r.scope, PCT.complete, -1)
	END RecordComplete;

BEGIN
	PCT.ChangeState(m.scope, PCT.complete, -1);
	attr := m.sym(Module);
	FOR i := 0 TO attr.nofstr-1 DO
		IF attr.struct[i] IS PCT.Record THEN
			RecordComplete(attr.struct[i](PCT.Record))
		END
	END
END ImportComplete;

(** Import - Symbol Table Loader Plugin *)

PROCEDURE Import*(self: PCT.Module; VAR M: PCT.Module; modname: StringPool.Index);
	VAR
			tag, res, i: LONGINT;  name: PCS.Name;  str: PCT.Struct;  vis: SET; R: PCM.SymReader;
			proc: PCT.Proc;
			scope: PCT.ModScope;
			pscope: PCT.ProcScope;
			selfimport, zeroCompress: BOOLEAN;
			ver: CHAR;
			MAttr: Module;
			flag, flags: SET;
			type: PCT.Type;
			string: ARRAY 256 OF CHAR;
			readString: ReadStringProc;
			importError: BOOLEAN;

		PROCEDURE Assert(cond: BOOLEAN);
		BEGIN
			IF ~cond THEN importError := TRUE END;
		END Assert;

		PROCEDURE EqualNames(s1, s2: PCT.Struct): BOOLEAN;
		VAR res: BOOLEAN;
		BEGIN
			ASSERT(s1 # NIL); ASSERT(s2 # NIL);
			IF (s1 IS PCT.Array) & (s2 IS PCT.Array) THEN
				res := EqualNames(s1(PCT.Array).base, s2(PCT.Array).base);
(** fof >> *)
			ELSIF (s1 IS PCT.EnhArray) & (s2 IS PCT.EnhArray) THEN  (*fof*)
				res := EqualNames( s1( PCT.EnhArray ).base, s2( PCT.EnhArray ).base );
			ELSIF (s1 IS PCT.Tensor) & (s2 IS PCT.Tensor) THEN  (*fof*)
				res := EqualNames( s1( PCT.Tensor ).base, s2( PCT.Tensor ).base );
(** << fof  *)
			ELSIF ~(s1 IS PCT.Array) & ~(s2 IS PCT.Array) & ~(s1 IS PCT.EnhArray) & ~(s2 IS PCT.EnhArray) &~(s1 IS PCT.Tensor) & ~(s2 IS PCT.Tensor) (* fof*) THEN
				IF (s1.owner # NIL) & (s2.owner # NIL) THEN
					res := (s1.owner.name = s2.owner.name);
				ELSE
					res := FALSE;
				END;
			ELSE
				res := FALSE;
			END;
			RETURN res;
		END EqualNames;

		PROCEDURE Insert(scope: PCT.Scope;  obj: PCT.Symbol);
			VAR	old: PCT.Symbol;  OAttr: Symbol;
				p: PCT.Symbol;
				paramProc, paramObj: PCT.Parameter;
				j: LONGINT;
		BEGIN
			ASSERT(selfimport);
			old:=PCT.Find(scope, scope, obj.name, PCT.procdeclared, FALSE);
			(*
				not the correct operator is found: type name is used to search, but not name of module,
					where type is definded (not in symbol file)
				changes in operator signatures are not recognized, only adding and removing of operators
			*)
			IF (old # NIL) & (PCT.Operator IN obj.flags) THEN
				p := old;
				old := NIL;
				WHILE (p # NIL) & (p.name = obj.name) DO
					paramProc := p(PCT.Proc).scope.firstPar;
					paramObj := obj(PCT.Proc).scope.firstPar;

					(* check for equal parameters (only the type names are compared!) *)
					j := 0;
					WHILE (j < p(PCT.Proc).scope.parCount) &
						(p(PCT.Proc).scope.parCount = obj(PCT.Proc).scope.parCount) &
						(p(PCT.Proc).vis = obj(PCT.Proc).vis) &
						(paramProc.ref = paramObj.ref) & EqualNames(paramProc.type, paramObj.type) DO

						paramProc := paramProc.nextPar;
						paramObj := paramObj.nextPar;
						INC(j)
					END;
					IF (j = p(PCT.Proc).scope.parCount) & (p(PCT.Proc).sym = NIL) THEN
						old := p;
						p := NIL
					ELSE
						p := p.sorted
					END
				END
			END;

			IF  old=NIL  THEN
				PCM.ErrorN(401, Diagnostics.Invalid, obj.name);  MAttr.changed:=TRUE
			ELSIF  old.vis#obj.vis  THEN
				PCM.ErrorN(401, Diagnostics.Invalid, obj.name);  MAttr.changed:=TRUE
			ELSE
				ASSERT(old.sym=NIL);
				NEW(OAttr);  old.sym:=OAttr;  OAttr.sibling:=obj
			END
		END Insert;

		PROCEDURE GetImports;
			VAR name: StringPool.Index; M: PCT.Module;
		BEGIN
			ReadStrIndex(R, readString, name);
			WHILE	name # empty	DO
				IF (MAttr.import = NIL) OR (MAttr.nofimp = LEN(MAttr.import)) THEN  PCT.ExtendModArray(MAttr.import)  END;
				PCT.Import(self, M, name);
				IF M = NIL THEN
					PCM.ErrorN(0, 0, name)
				ELSE
					MAttr.import[MAttr.nofimp]:=M;
					IF M.scope.state = 0 THEN	(*fresh import*)
						ImportComplete(M)
					END;
					INC(MAttr.nofimp);  ReadStrIndex(R, readString, name)
				END
			END
		END GetImports;

		PROCEDURE InConst(): PCT.Const;
			VAR i: LONGINT;  r: REAL;  lr: LONGREAL;  str: PCS.String;  set: SET;  c: PCT.Const;
		BEGIN
			CASE	tag	OF
			| SFtypBool:	R.RawNum(i);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / Bool / "); PCM.LogWNum(i) END;
									IF	i = 0	THEN	c := PCT.False	ELSE	c := PCT.True	END
			| SFtypChar8:	R.RawNum(i);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / Char / "); PCM.LogWNum(i) END;
									c := PCT.NewIntConst(i, PCT.Char8)
			| SFtypInt8:	R.RawNum(i);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / SInt / "); PCM.LogWNum(i) END;
									c := PCT.NewIntConst(i, PCT.Int8)
			| SFtypInt16:	R.RawNum(i);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / Int / "); PCM.LogWNum(i) END;
									c := PCT.NewIntConst(i, PCT.Int16)
			| SFtypInt32:	R.RawNum(i);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / LInt / "); PCM.LogWNum(i) END;
									c := PCT.NewIntConst(i, PCT.Int32)
			| SFtypInt64:	R.RawLReal(lr);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / HInt / ") END;
									c := PCT.NewInt64Const(SYSTEM.VAL(HUGEINT, lr))
			| SFtypSet:	R.RawNum(SYSTEM.VAL(LONGINT, set));
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / Set / "); PCM.LogWHex(SYSTEM.VAL(LONGINT, set)) END;
									c := PCT.NewSetConst(set)
			| SFtypFloat32:	R.RawReal(r);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / Real / ") END;
									RETURN PCT.NewFloatConst(r, PCT.Float32)
			| SFtypFloat64:	R.RawLReal(lr);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / LongReal / ") END;
									c := PCT.NewFloatConst(lr, PCT.Float64)
			| SFtypString:	readString(R, str);
									IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("InConst / String / "); PCM.LogWStr(str) END;
									c := PCT.NewStringConst(str)
			| SFtypNilTyp:
			END;
			RETURN c
		END InConst;

		PROCEDURE InParList(upper: PCT.Scope): PCT.ProcScope;
			VAR	s: PCT.ProcScope;  svar, var: BOOLEAN;  name: PCS.Name; styp, str: PCT.Struct; f: LONGINT; flags: SET; (* ejz *)
		BEGIN
			styp := NIL;
			NEW(s); PCT.InitScope(s, upper, {}, TRUE); PCT.SetOwner(s);
			R.RawNum(tag);
			WHILE  tag#SFend  DO
				flags := {}; (* ejz *)
				IF tag = SFobjflag THEN
					R.RawNum(f); R.RawNum(tag);
					IF f = PCM.CParam THEN (* fof for Linux *)
						INCL(flags, PCT.CParam)
					ELSIF f = PCM.WinAPIParam THEN
						INCL(flags,PCT.WinAPIParam)
					ELSE HALT(100)
					END;
				END;
					IF  tag=SFvar  THEN
					var:=TRUE; R.RawNum(tag);
				ELSE var:=FALSE
				END;
(** fof >> *)
				IF tag = SFreadonly THEN  (* var const *)
					INCL(flags,PCM.ReadOnly); R.RawNum(tag);
				END;
(** << fof  *)
				InStruct(str); ReadStrIndex(R, readString, name);
				IF (name = PCT.SelfName) OR (name = altSelf) THEN	(*move SELF to the end of the list / method only*)
					styp := str; svar := var
				ELSE
					s.CreatePar(PCT.Public, var, name, flags, str, 0 (* fof *),  res); (* ASSERT(res = PCT.Ok) *) (* ejz *)
					Assert(res = PCT.Ok);
				END;
				R.RawNum(tag)
			END;
			IF styp # NIL THEN
				s.CreatePar(PCT.Public, svar, PCT.SelfName, {}, styp, 0 (* fof *), res); (* ASSERT(res = PCT.Ok) *)
				Assert(res = PCT.Ok);
			END;
			RETURN s
		END InParList;

		PROCEDURE InRecord(rec: PCT.Record; btyp: PCT.Struct; intf: PCT.Interfaces);
			VAR	mode, vis: SET;  typ: PCT.Struct;  name: PCS.Name;
				mscope: PCT.ProcScope; s: PCT.RecScope;  flags: SET; ch: CHAR;
		BEGIN
			NEW(s);
			PCT.SetOwner(s);
			PCT.InitScope(s, scope, {}, TRUE);
			R.RawNum(SYSTEM.VAL(LONGINT, mode));
			PCT.InitRecord(rec, btyp, intf, s, PCT.interface IN mode, TRUE, TRUE, res); (* ASSERT(res = PCT.Ok); *)
			Assert(res = PCT.Ok);
			rec.mode := mode;
			R.Char(ch);  rec.prio := ORD(ch);
			IF TraceImport THEN
				PCM.LogWLn; PCM.LogWStr("Rec / Mode / "); PCM.LogWHex(SYSTEM.VAL(LONGINT, rec.mode));
				PCM.LogWLn; PCM.LogWStr("Rec / Prio / "); PCM.LogWNum(rec.prio)
			END;
			R.RawNum(tag);
			WHILE  (tag < SFtproc) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)    DO	(*read fields*)
				InObj(name, vis, flags, typ);
				IF  name = empty  THEN vis := PCT.Internal; name := PCT.Anonymous END;
				s.CreateVar(name, vis, flags, typ, 0, (* fof *)NIL, res);
				(* ASSERT(res = PCT.Ok); *)
				Assert(res = PCT.Ok);
				R.RawNum(tag);
			END;
			IF tag=SFtproc THEN
				R.RawNum(tag);
				WHILE  tag#SFend  DO
					InObj(name, vis, flags, typ);
					IF  name = empty  THEN  vis := PCT.Internal; ReadStrIndex(R, readString, name)  END;
					mscope := InParList(s);
					s.CreateProc(name, vis, flags, mscope, typ, 0, (* fof *) res); (* ASSERT(res = PCT.Ok); *)
					Assert(res = PCT.Ok);

					(* This identifies a inlined Indexer *)
					R.RawNum(tag);
					IF tag = InlineMarker THEN
						INCL(flag, PCT.Inline);
						INCL(flag, PCT.Indexer);
						INCL(flag, PCT.Operator);
						mscope.code := InCProc();
						R.RawNum(tag)
					END;

					PCT.ChangeState(mscope, PCT.structdeclared, Diagnostics.Invalid);
				END
			END;
			IF ~selfimport THEN PCT.AddRecord(M.scope, rec) END;
		END InRecord;

		PROCEDURE InStruct(VAR typ: PCT.Struct);
			VAR i, len, strref, typtag, typadr: LONGINT; vis: SET; name: PCS.Name; btyp: PCT.Struct;
				arr: PCT.Array; type: PCT.Type; mod: PCT.Module;  typname: PCS.Name; proc: PCT.Delegate; r, rec: PCT.Record;
				ptr: PCT.Pointer;
				modAttr: Module; tAttr: Struct;
				sysflag: LONGINT; sf: SET;
				intf: ARRAY 32 OF PCT.Interface; c: CHAR;
			earr: PCT.EnhArray; tensor: PCT.Tensor; readonly: LONGINT;  (*fof*)
			flags: LONGINT;
			(*!!! when loading the user structures, no fix is used, but dummy elements !!!*)
		BEGIN
			IF tag <= 0 THEN	(*oldstruct*)
				ASSERT(MAttr.struct[-tag]#NIL);
				(*IF MAttr.struct[-tag] = NIL THEN PCDebug.ToDo(PCM.NotImplemented); RETURN unknownType END;*)
				typ := MAttr.struct[-tag];
				IF TraceImport THEN
					PCM.LogWLn; PCM.LogWStr("InStruct / OldStr "); PCM.LogWNum(-tag)
				END
			ELSIF tag <= SFlastStruct THEN (*BasicStructure*) typ := predefStruct[tag]
				;IF TraceImport THEN
					PCM.LogWLn; PCM.LogWStr("InStruct / Basic ");
					IF typ.owner # NIL THEN PCM.LogWStr0(typ.owner.name) ELSE PCM.LogWNum(tag) END
				END
			ELSIF tag <= SFmodOther THEN (*modno ( structname | 0X oldimpstruct)*)
				IF tag = SFmodOther THEN R.RawNum(tag) ELSE tag := tag-SFmod1 END;	(*tag = [0 .. +oo[ *)
				mod := MAttr.import[tag]; ReadStrIndex(R, readString, typname);
				modAttr := mod.sym(Module);
				IF typname # empty THEN	(*first import of struct*)
					i := 0;
					WHILE (i<modAttr.nofstr) & ((modAttr.struct[i].owner=NIL) OR (modAttr.struct[i].owner.name # typname)) DO INC(i) END;
					IF i<modAttr.nofstr THEN typ := modAttr.struct[i] ELSE typ := PCT.UndefType END;
					IF  (modAttr.reimp = NIL) OR (modAttr.nofreimp = LEN(modAttr.reimp))  THEN  ExtendStructArray(modAttr.reimp)  END;
					modAttr.reimp[modAttr.nofreimp] := typ;  INC(modAttr.nofreimp);
					IF TraceImport THEN
						PCM.LogWLn; PCM.LogWStr("InStruct / Imported "); PCM.LogWStr0(mod.name);
						PCM.LogWStr("."); PCM.LogWStr0(typname);
					END
				ELSE
					R.RawNum(typadr); typ := modAttr.reimp[typadr];
					IF TraceImport THEN
						PCM.LogWLn; PCM.LogWStr("InStruct / Re-Imported "); PCM.LogWStr0(mod.name);
						PCM.LogWStr("."); PCM.LogWStr0(typ.owner.name);
					END
				END
			ELSE (*UserStructure*)
				strref := MAttr.nofstr; INC(MAttr.nofstr);
				IF MAttr.nofstr >= LEN(MAttr.struct) THEN ExtendStructArray(MAttr.struct) END;
				vis := PCT.Public; sysflag := 0;
				IF tag = SFinvisible THEN vis := PCT.Internal; R.RawNum(tag)  END;
				IF tag = SFsysflag THEN R.RawNum(sysflag); R.RawNum(tag)  END;
				typtag := tag; R.RawNum(tag);
				(*first create the structure, to be used in recursive structs*)
				CASE typtag OF
				| SFtypOpenArr,  SFtypArray:
						NEW(arr); typ := arr
(** fof >> *)
				| SFtypOpenEnhArr, SFtypStaticEnhArray:
						NEW( earr );  typ := earr
				| SFtypTensor:
					NEW(tensor); typ := tensor;
(** << fof  *)
				| SFtypPointer:
						NEW(ptr);  typ := ptr
				| SFtypRecord:
						NEW(rec);  typ := rec;
						IF (strref > 0) & (MAttr.struct[strref-1] IS PCT.Pointer) THEN
							ptr := MAttr.struct[strref-1](PCT.Pointer);
							IF ptr.base = NIL THEN
								INC(NpatchPointer0);
								PCT.InitPointer(ptr, rec, res); (* ASSERT(res = PCT.Ok) *)
								Assert(res = PCT.Ok);
							END;
						END;
				| SFtypProcTyp:
						NEW(proc); typ := proc
				END;
				(* ASSERT((sysflag = 0) OR (sysflag = SFdelegate)); *)
				MAttr.struct[strref] := typ;
				NEW(tAttr, M); typ.sym:=tAttr; tAttr.strref := strref;
(*
				IF ~selfimport THEN  tAttr.mod:=M  END;		(*only for imported structures: where from*)
*)
				InStruct(btyp);
				(* now load the struct, late fixes*)
				CASE typtag OF
				| SFtypOpenArr:
						PCT.InitOpenArray(arr, btyp, res); (* ASSERT(res = PCT.Ok); *)
						Assert(res = PCT.Ok);
						ReadStrIndex(R, readString, name);
						R.RawNum(flags); (* realtime flags , ignored in PACO *)
						IF TraceImport THEN
							PCM.LogWLn; PCM.LogWStr("InStruct / User / OpenArr ");
							IF name # empty THEN  PCM.LogWStr0(name) END
						END
(** fof >> *)
				| SFtypOpenEnhArr:
						PCT.InitOpenEnhArray( earr, btyp, {PCT.open}, res );   (* ASSERT(res = PCT.Ok); *)
						Assert( res = PCT.Ok );
						ReadStrIndex( R, readString, name );
						IF TraceImport THEN
							PCM.LogWLn;  PCM.LogWStr( "InStruct / User / OpenEnhArr " );
							IF name # empty THEN PCM.LogWStr0( name ) END
						END
				| SFtypTensor:
					PCT.InitTensor(tensor,btyp,res);
						Assert( res = PCT.Ok );
						ReadStrIndex( R, readString, name );
				| SFtypStaticEnhArray:  (*fof*)
						ReadStrIndex( R, readString, name );  R.RawNum( len );
						PCT.InitStaticEnhArray( earr, len, btyp, {PCT.static}, res );   (* ASSERT(res = PCT.Ok); *)
						Assert( res = PCT.Ok );
						IF TraceImport THEN
							PCM.LogWLn;  PCM.LogWStr( "InStruct / User / Array " );  PCM.LogWNum( len );
							IF name # empty THEN PCM.LogWStr0( name ) END
						END
(** << fof  *)
				| SFtypArray:
						ReadStrIndex(R, readString, name);
						R.RawNum(flags); (* realtime flags , ignored in PACO *)
						R.RawNum(len);
						PCT.InitStaticArray(arr, len, btyp, res); (* ASSERT(res = PCT.Ok); *)
						Assert(res = PCT.Ok);
						IF TraceImport THEN
							PCM.LogWLn; PCM.LogWStr("InStruct / User / Array ");
							PCM.LogWNum(len);
							IF name # empty THEN  PCM.LogWStr0(name) END
						END
				| SFtypPointer:
						IF ptr.base # NIL THEN
							ASSERT(ptr.base = btyp)
						ELSE
							PCT.InitPointer(ptr, btyp, res); (* ASSERT(res = PCT.Ok) *)
							Assert(res = PCT.Ok);
						END;
						ReadStrIndex(R, readString, name);
						R.RawNum(flags); (* realtime flags , ignored in PACO *)
						IF TraceImport THEN
							PCM.LogWLn; PCM.LogWStr("InStruct / User / Pointer ");
							IF name # empty THEN  PCM.LogWStr0(name) END
						END
				| SFtypRecord:
						LOOP
							IF btyp IS PCT.Pointer THEN
								WITH btyp: PCT.Pointer DO
									r := btyp.baseR;
									IF PCT.interface IN r.mode THEN
										INC(Ninterfaces);
										intf[i] := btyp;  INC(i)
									ELSE
										EXIT
									END
								END
							ELSE
								EXIT
							END;
							R.RawNum(tag);
							InStruct(btyp)
						END;
						ReadStrIndex(R, readString, name);
						R.RawNum(flags); (* realtime flags , ignored in PACO *)
						InRecord(rec, btyp, intf);
						IF TraceImport THEN
							PCM.LogWLn; PCM.LogWStr("InStruct / User / Record ");
							IF name # empty THEN  PCM.LogWStr0(name) END
						END
				| SFtypProcTyp:

						ReadStrIndex(R, readString, name);
						R.RawNum(SYSTEM.VAL(LONGINT, sf));
						IF sysflag # SFdelegate THEN INCL (sf, PCT.StaticMethodsOnly) END;
						PCT.InitDelegate(proc, btyp, InParList(scope), sf, res); (* ASSERT(res = PCT.Ok); *)
						Assert(res = PCT.Ok);
						PCT.ChangeState(proc.scope, PCT.structdeclared, -1);
						IF TraceImport THEN
							PCM.LogWLn; PCM.LogWStr("InStruct / User / Proc ");
							IF name # empty THEN  PCM.LogWStr0(name) END
						END
				END;
				IF name # empty THEN
					IF ~selfimport THEN
						scope.CreateType(name, vis, typ, 0(*fof*), res); (* ASSERT(res = PCT.Ok) *)
						Assert(res = PCT.Ok);
					ELSE
						NEW(type); PCT.InitType(type, name, vis, typ); Insert(scope, type)
					END
				END
			END
		END InStruct;

		PROCEDURE InCProc(): PCLIR.AsmInline;
		VAR  inline: PCLIR.AsmInline;  p: PCLIR.AsmBlock;  ch: CHAR;  pos, len: LONGINT;
		BEGIN
			NEW(inline); R.Char(ch);
			REPEAT
				IF p = NIL THEN  NEW(p); inline.code := p  ELSE  NEW(p.next); p := p.next  END;
				len := ORD(ch);  p.len := len;  pos := 0;
				WHILE pos < len DO  R.Char(p.code[pos]); INC(pos)  END;
				R.Char(ch)
			UNTIL ch = 0X;
			RETURN inline
		END InCProc;

		PROCEDURE InObj(VAR idx: PCS.Name;  VAR vis: SET;  VAR flag: SET;  VAR typ: PCT.Struct);
		VAR  f: LONGINT; name: ARRAY 32 OF CHAR;
		BEGIN
			flag := {}; vis:=PCT.Public;
			IF tag=SFobjflag THEN
				R.RawNum(f); R.RawNum(tag);
				IF f = PCM.Untraced THEN flag := {f}
				ELSIF f = PCM.RealtimeProc THEN flag := {PCT.RealtimeProc} (* ug *)
				ELSE PCM.LogWLn; PCM.LogWStr("PCOM.InObj: unknown objflag");
				END
			END;
			IF tag=SFreadonly THEN  R.RawNum(tag); vis := readonly   END;
			InStruct(typ); readString(R, name);
			IF name = "" THEN
				idx := empty
			ELSIF name[0] = "&" THEN
				flag := {PCT.Constructor};
				i := 0; REPEAT  name[i] := name[i+1]; INC(i)  UNTIL name[i] = 0X;
				StringPool.GetIndex(name, idx)
			ELSE
				StringPool.GetIndex(name, idx)
			END;
			IF TraceImport THEN
				PCM.LogWLn; PCM.LogWStr("InObj: "); PCM.LogWStr(name)
			END
		END InObj;

BEGIN
	IF Trace THEN  PCM.LogWLn; PCM.LogWStr("OM.Import") END;
	i := 0;
	M:=NIL;
	selfimport:=FALSE;
	StringPool.GetString(modname, string);
	IF ~PCM.OpenSymFile(string, R, ver, zeroCompress) THEN
		RETURN
	END;
	IF zeroCompress THEN
		readString := ReadString;
	ELSE
		readString := ReadStringNoZeroCompress;
	END;
	IF (self # NIL) & (self.sym = NIL) THEN	(*first import, create symfile related structures*)
		NEW(MAttr); self.sym:=MAttr;
	END;
	IF (self # NIL) & (self.name = modname) THEN
		selfimport:=TRUE;
		M := self;
		MAttr:=M.sym(Module); MAttr.nofreimp:=0; scope:=M.scope;
	ELSE
		NEW(scope);  PCT.SetOwner(scope);
		M := PCT.NewModule(modname, TRUE, {}, scope);
		NEW(MAttr); M.sym:=MAttr
	END;
	IF ~selfimport & (self # NIL) THEN self.AddImport(M) END;
	IF (ver = PCM.FileVersion) OR (ver=PCM.FileVersionOC) THEN
		R.RawSet(flags);
	ELSE
		PCM.Error(151, Diagnostics.Invalid, ""); M := NIL; RETURN
	END;

	GetImports;
	IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("Import "); PCM.LogWStr(string) END;
	FOR i := 0 TO MAttr.nofimp-1 DO
		ASSERT(MAttr.import # NIL, 500);
		ASSERT(MAttr.import[i] # NIL, 501);
		ASSERT(MAttr.import[i].sym # NIL, 502);
		MAttr.import[i].sym(Module).nofreimp := 0
	END;	(*reset reimports*)
	R.RawNum(tag);
	flag := {};
	IF tag = SFsysflag THEN
		R.RawNum(SYSTEM.VAL(LONGINT, flag)); R.RawNum(tag);
	END;
	IF ~selfimport THEN PCT.InitScope(scope, NIL, flag, TRUE) END;
	IF	tag=SFconst	THEN R.RawNum(tag);
		WHILE	(tag < SFvar) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InObj(name, vis, flag, str);
			IF ~selfimport THEN
				scope.CreateValue(name, vis, InConst(), 0, (* fof *) res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			ELSE
				Insert(scope, PCT.NewValue(name, vis, InConst()))
			END;
			R.RawNum(tag)
		END
	END;
	IF Trace THEN  PCM.LogWLn; PCM.LogWStr("OM.Import var....") END;
	IF	tag=SFvar	THEN	R.RawNum(tag);
		WHILE	(tag < SFxproc) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InObj(name, vis, flag, str);
			IF ~selfimport THEN
				scope.CreateVar(name, vis, flag, str, 0, (* fof *) NIL, res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok)) *)
			ELSE
				Insert(scope, PCT.NewGlobalVar(vis, name, flag, str, res));
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			END;
			R.RawNum(tag)
		END
	END;
	IF Trace THEN  PCM.LogWLn; PCM.LogWStr("OM.Import xproc....") END;
	IF	tag=SFxproc	THEN	R.RawNum(tag);
		WHILE	(tag < (*SFcproc*) SFoperator)  OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InObj(name, vis, flag, str); pscope := InParList(scope);
			IF ~selfimport THEN
				scope.CreateProc(name, vis, flag, pscope, str, 0, (* fof *) res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			ELSE
				proc := PCT.NewProc(vis, name, flag, pscope, str, res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok); *)
				Insert(scope, proc);
			END;
			PCT.ChangeState(pscope, PCT.structdeclared, -1); R.RawNum(tag)
		END
	END;
	IF	tag=SFoperator	THEN	R.RawNum(tag);
		WHILE	(tag < SFcproc) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InObj(name, vis, flag, str); pscope := InParList(scope);
			INCL(flag, PCT.Operator);
			R.RawNum(tag);
			IF tag = InlineMarker THEN
				INCL(flag, PCT.Inline);
				pscope.code := InCProc();
				R.RawNum(tag);
			END;
			IF ~selfimport THEN
				scope.CreateProc(name, vis, flag, pscope, str, 0, (* fof *)res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok); *)
			ELSE
				proc := PCT.NewProc(vis, name, flag, pscope, str, res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok); *)
				Insert(scope, proc);
			END;
			PCT.ChangeState(pscope, PCT.structdeclared, -1);
			(* R.RawNum(tag) *)
		END
	END;
	IF  tag = SFcproc  THEN	R.RawNum(tag);
		WHILE	(tag < SFalias) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InObj(name, vis, flag, str); pscope := InParList(scope);
			INCL(flag, PCT.Inline);
			IF ~selfimport THEN
				scope.CreateProc(name, vis, flag, pscope, str, 0, (* fof *) res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			ELSE
				Insert(scope, PCT.NewProc(vis, name, flag, pscope, str, res));
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			END;
			pscope.code := InCProc();
			PCT.ChangeState(pscope, PCT.structdeclared, -1); R.RawNum(tag)
		END
	END;
	IF	tag=SFalias	THEN	R.RawNum(tag);
		WHILE	(tag < SFtyp) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO
			InStruct(str); ReadStrIndex(R, readString, name);
			IF ~selfimport THEN
				scope.CreateType(name, PCT.Public, str, 0, (* fof *)res);
				Assert(res = PCT.Ok);
				(* ASSERT(res = PCT.Ok) *)
			ELSE
				NEW(type); PCT.InitType(type, name, PCT.Public, str); Insert(scope, type)
			END;
			R.RawNum(tag)
		END
	END;
	IF	tag=SFtyp	THEN	R.RawNum(tag);
		WHILE	(tag < SFend) OR ((SFtypOpenEnhArr <= tag) & (tag <= SFtypStaticEnhArray)) (* fof *)	DO	InStruct(str); R.RawNum(tag)	END
	END;
	IF importError THEN
		M := NIL
	ELSE
		ImportComplete(M)
	END
END Import;

(* ========== Initialisation ============ *)

PROCEDURE Cleanup;
BEGIN PCT.RemoveImporter(Import)
END Cleanup;

PROCEDURE InitBasic(t: PCT.Struct; tag, fp: LONGINT);
	VAR sAttr: Struct;
BEGIN
	NEW(sAttr, NIL);  sAttr.tag := tag;  t.sym := sAttr;  sAttr.fp:=fp;  sAttr.pbfp := fp;
	IF t.size # NIL THEN  sAttr.pvfp := t.size(PCBT.Size).size  ELSE  sAttr.pvfp := tag  END;
	predefStruct[tag] := t;
END InitBasic;

PROCEDURE Init;
BEGIN
	(*Built-In types*)
	InitBasic(PCT.NoType, SFtypNoTyp, FPFnotyp);  PCT.NoType.sym(Struct).pvfp := SFtypNoTyp;
	InitBasic(PCT.Bool, SFtypBool, FPFbool);
	InitBasic(PCT.Char8, SFtypChar8, FPFchar8);
	InitBasic(PCT.Char16, SFtypChar16, FPFchar16typ);
	InitBasic(PCT.Char32, SFtypChar32, FPFchar32typ);
	InitBasic(PCT.Int8, SFtypInt8, FPFint8typ);
	InitBasic(PCT.Int16, SFtypInt16, FPFint16typ);
	InitBasic(PCT.Int32, SFtypInt32, FPFint32typ);
	InitBasic(PCT.Int64, SFtypInt64, FPFint64typ);
	InitBasic(PCT.Float32, SFtypFloat32, FPFfloat32typ);
	InitBasic(PCT.Float64, SFtypFloat64, FPFfloat64typ);
	InitBasic(PCT.Set, SFtypSet, FPFsettyp);
	InitBasic(PCT.String, SFtypString, FPFstringtyp);  PCT.String.sym(Struct).pvfp := SFtypString;
	(*InitBasic(PCT.PtrTyp, 0);*)
	(*not initialized: NilTyp, UndefTyp (have special pvfp)*)

	(*Built-In types, system*)
	InitBasic(PCT.Ptr, SFtypSptr, FPFpointer);
	InitBasic(PCT.Byte, SFtypByte, FPFbyte);

	FParray[PCT.open]:=FPFopenarr; FParray[PCT.static]:=FPFstaticarr;

	PCT.AddImporter(Import);
END Init;

PROCEDURE CreateString(VAR idx: StringPool.Index;  str: ARRAY OF CHAR);	(*to insert string constants*)
BEGIN  StringPool.GetIndex(str, idx)
END CreateString;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init;
	IF Trace THEN PCM.LogWLn; PCM.LogWStr("PCOM.Trace on") END;
	IF TraceImport THEN PCM.LogWLn; PCM.LogWStr("PCOM.TraceImport on") END;

	CreateString(altSelf, "@SELF")
END PCOM.


(*
	15.11.06	ug	Procedure Export with additional parameter skipImport that suppresses the import of the old symbol file
	11.06.02	prk	emit modified symbol file message to main log (not kernel log)
	22.02.02	prk	unicode support
	08.02.02	prk	use Aos instead of Oberon modules
	05.02.02	prk	PCT.Find cleanup
	22.01.02	prk	ToDo list moved to PCDebug
	18.01.02	prk	AosFS used instead of Files
	22.11.01	prk	improved flag handling
	19.11.01	prk	definitions
	17.11.01	prk	more flexible type handling of integer constants
	16.11.01	prk	constant folding of reals done with maximal precision
	14.11.01	prk	include sysflag in fingerprint
	29.08.01	prk	PCT functions: return "res" instead of taking "pos"
	27.08.01	prk	scope.unsorted list removed; use var, proc, const and type lists instead
	17.08.01	prk	overloading
	09.08.01	prk	Symbol Table Loader Plugin
	11.07.01	prk	support for fields and methods with same name in scope
	06.07.01	prk	mark object explicitly
	05.07.01	prk	import interface redesigned
	04.07.01	prk	scope flags added, remove imported
	02.07.01	prk	access flags, new design
	27.06.01	prk	StringPool cleaned up
	27.06.01	prk	ProcScope.CreatePar added
	15.06.01	prk	support for duplicate scope entries
	13.06.01	prk	export of empty inlines fixed
	06.06.01	prk	use string pool for object names
	08.05.01	prk	PCT interface cleanup. Use InitX instead of New*, allows type extension
	26.04.01	prk	separation of RECORD and OBJECT in the parser
	02.04.01	prk	ExtendModArray, ExtendStructArray exported
	30.03.01	prk	object file version changed to 01X
	25.03.01	prk	limited HUGEINT implementation (as abstract type)
	22.02.01	prk	self reference for methods: use pointer-based self if possible (i.e. if object is dynamic and method
								definitions in super-class is not record-based).
*)