(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCP; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: parser"; *)

IMPORT
	Machine, Diagnostics, Modules, Objects, Kernel, Strings,
	StringPool,
	PCM, PCS, PCT, PCB, PCC, SYSTEM, PCArrays;

CONST
	(* The Tokens
	ProgTools.Enum PCS
		null
		times slash div mod and
		plus minus or eql neq  lss leq gtr geq in is
		arrow period comma
		colon upto rparen rbrak rbrace
		of then do to by
		lparen lbrak lbrace
		not
		becomes
		number nil true false string
		ident semicolon bar end else
		elsif until if case while
		repeat for loop with exit passivate return
		refines implements
		array definition object record pointer begin code
		const type var procedure import
		module eof
		~
*)
	null = PCS.null; times = PCS.times; slash = PCS.slash; div = PCS.div;
	mod = PCS.mod; and = PCS.and; plus = PCS.plus; minus = PCS.minus;
	or = PCS.or; eql = PCS.eql; neq = PCS.neq; lss = PCS.lss; leq = PCS.leq;
	gtr = PCS.gtr; geq = PCS.geq; in = PCS.in; is = PCS.is; arrow = PCS.arrow;
	period = PCS.period; comma = PCS.comma; colon = PCS.colon; upto = PCS.upto;
	rparen = PCS.rparen; rbrak = PCS.rbrak; rbrace = PCS.rbrace; of = PCS.of;
	then = PCS.then; do = PCS.do; to = PCS.to; by = PCS.by; lparen = PCS.lparen;
	lbrak = PCS.lbrak; lbrace = PCS.lbrace; not = PCS.not; becomes = PCS.becomes;
	number = PCS.number; nil = PCS.nil; true = PCS.true; false = PCS.false;
	string = PCS.string; ident = PCS.ident; semicolon = PCS.semicolon;
	bar = PCS.bar; end = PCS.end; else = PCS.else; elsif = PCS.elsif;
	until = PCS.until; if = PCS.if; case = PCS.case; while = PCS.while;
	repeat = PCS.repeat; for = PCS.for; loop = PCS.loop; with = PCS.with;
	exit = PCS.exit; passivate = PCS.passivate; return = PCS.return;
	refines = PCS.refines; implements = PCS.implements; array = PCS.array;
	definition = PCS.definition; object = PCS.object; record = PCS.record;
	pointer = PCS.pointer; begin = PCS.begin; codeToken = PCS.code; const = PCS.const;
	type = PCS.type; var = PCS.var; procedure = PCS.procedure; import = PCS.import;
	module = PCS.module; eof = PCS.eof; finally = PCS.finally;
	(** fof >> *)
	filler = PCS.qmark;  backslash = PCS.backslash;
	scalarproduct = PCS.scalarproduct;
	elementproduct = PCS.elementproduct;
	elementquotient = PCS.elementquotient;
	transpose = PCS.transpose;  dtimes = PCS.dtimes;
	eeql = PCS.eeql;  eneq = PCS.eneq;  elss = PCS.elss;
	eleq = PCS.eleq;  egtr = PCS.egtr;  egeq = PCS.egeq;

	AllowOverloadedModule = FALSE;
	(* fof removed the mechanism allowing to choose an operator from a module.
		Example: "a :=[myModule1] b;" chooses assignment operator for "a" from module "myModule1".
		My proposal is to generally prohibit multiple occurence of operators by restriction of its definition to the object's defining module.
		For now we do it with this switch.
		Note: if AllowOverloadedModule = TRUE then constant arrays do not work in code. Example A :=[1,2,3] or [1,2,3]+[4,5,6] do then not work.
	*)
	(** << fof  *)


	(*local constants, implementations restrictions*)
	MaxIdentDef = 128;		(*maximal number of IdentDef in a VarDecl*)

TYPE
	IdentDefDesc = RECORD name: PCS.Name; vis: SET END;	(*
		name = (parsed name) OR ("")
		vis = (parsed vis) OR (PCT.Internal)
	*)

VAR
		(** Assembler Plugin *)
	Assemble*: PROCEDURE (scanner: PCS.Scanner;  scope: PCT.Scope;  exported, inlined: BOOLEAN): PCM.Attribute;

		(* cached string constants used by the parser*)
	noname, self, untraced, delegate, overloading,
	exclusive, active, safe, priority, realtime, winapi (* ejz *), clang (*fof for linux *) ,notag (* sz *),
	deltype, hiddenptr, procfld, ptrfld: StringPool.Index;

	NModules, NObjects, NDefinitions, NArrays, NRecords, NPointers, NDelegates, NProcedureTypes,
	NExclusive, NExclusiveMain, NActive,
	NSyncsCount: LONGINT;	(* statistical counters *)

(* ============================================================== *)
(* ------------- The Parser Object ---------------------------------- *)
TYPE
		(* Synchronize a thread with its child processes, await till all left the monitor or timeout *)
	Barrier = OBJECT (Kernel.Timer)
		VAR
			timeout: LONGINT;
			started, ended: LONGINT;

			PROCEDURE & SInit*(timeout: LONGINT);
			BEGIN started := 0; ended := 0; SELF.timeout := timeout*1000; Init;
			END SInit;

			PROCEDURE Enter;
			BEGIN
				Machine.AtomicInc(started);
				Machine.AtomicInc(NSyncsCount);
			END Enter;

			PROCEDURE Exit;
			BEGIN
				Machine.AtomicInc(ended);
				IF started = ended THEN Wakeup END
			END Exit;

			PROCEDURE Await;
			BEGIN Sleep(timeout)
			END Await;

			PROCEDURE Stats(VAR started, inside: LONGINT);
			BEGIN started := SELF.started; inside := SELF.started - SELF.ended
			END Stats;
	END Barrier;


	Parser* = OBJECT

		VAR
			sync: Barrier;
			sym, savedsym: PCS.Token;
			scanner, savedscanner: PCS.Scanner;
			scope, codescope: PCT.Scope;		(*codescope is the scope where the code is defined, where a WITH is used*)
			looplevel, scopelevel: SHORTINT;	(*copy of scope(ProcScope).level or 0 (rec/mod)*)
			forexitcount, forretcount, retcount, fincount: LONGINT;	(*nested for-loops inside a LOOP-statement, used to remove the temp for-counters*)
			curloop: PCB.LoopInfo;
			code: PCC.Code;
			inline: BOOLEAN;
			locked: BOOLEAN;	(*parser inside a locked statement block, set by StatementBlock*)
			unlockOnExit: BOOLEAN;	(* EXCLUSIVE block nested in a LOOP, must unlock when exit is called *)
			die: BOOLEAN;	(*kill the parser*)
			notifyScope: BOOLEAN;	(*notify the parent of current scope that the body mode is available*)
			isRecord: BOOLEAN;	(*cached: scope IS PCT.RecScope*)
			inspect: BOOLEAN;		(* TRUE if body is parsed to find hidden local variables, i.e. procedure calls that return pointers *)

			forwardPtr: ARRAY 128 OF RECORD  ptr: PCT.Pointer; name: PCS.Name  END;
			nofForwardPtr: LONGINT;

		(* --------------------------------------------------------- *)
		(* Parser utilities *)

		PROCEDURE Error(n, pos: LONGINT);
		BEGIN PCM.Error(n, pos, "")
		END Error;

		PROCEDURE Check(x: PCS.Token);
		BEGIN
			IF sym = x THEN scanner.Get(sym) ELSE PCM.Error(x, scanner.errpos, "") END;
		END Check;

		(*	Test whether the current symbol is a semicolon. Report an error if not. In case of multiple semicolons
			the follow each other, report a warning for each occurence *)
		PROCEDURE CheckSemicolons;
		BEGIN
			IF (sym = semicolon) THEN
				scanner.Get(sym);
				IF (sym = semicolon) THEN
					REPEAT
						PCM.Warning(315, scanner.errpos, "");
						scanner.Get(sym);
					UNTIL sym # semicolon;
				END;
			ELSE
				PCM.Error(semicolon, scanner.errpos, "");
			END;
		END CheckSemicolons;

		(* Report an error if the pseudo module SYSTEM is not imported by the specified module *)
		PROCEDURE CheckSysImported(module : PCT.Module);
		BEGIN
			IF ~module.sysImported THEN
				Error(135, scanner.errpos);
			ELSE
				INCL(PCT.System.flags, PCT.used);
			END;
		END CheckSysImported;

		(* --------------------------------------------------------- *)
		(* Active Oberon Language Productions *)
		(* Declaration Section *)

		PROCEDURE TypeModifier(VAR flags: SET;  default, allowed: SET);
		BEGIN
			flags := default;
			IF (sym = lbrace) THEN
				REPEAT
					scanner.Get(sym);
					IF sym # ident THEN
						Error(ident, scanner.errpos)
					ELSIF scanner.name = untraced THEN
						INCL (flags, PCM.Untraced);
					ELSIF scanner.name = delegate THEN
						EXCL (flags, PCT.StaticMethodsOnly);
					ELSIF scanner.name = realtime THEN
						INCL (flags, PCT.RealtimeProcType);
					ELSIF scanner.name = overloading THEN
						INCL (flags, PCT.Overloading);
					ELSIF scanner.name = winapi THEN (* ejz *)
						CheckSysImported(scope.module);
						INCL (flags, PCT.WinAPIParam);
					ELSIF scanner.name = clang THEN  (* fof for Linux *)
						CheckSysImported(scope.module);
						INCL (flags, PCT.CParam);
					ELSE
						Error(0, scanner.errpos); scanner.Get(sym)
					END;
					scanner.Get( sym )
				UNTIL sym # comma;
				IF (flags - allowed # {}) THEN  flags := default; Error(200, scanner.errpos)  END;
				Check(rbrace)
			END;
			IF  (flags = {PCM.Untraced}) THEN
				CheckSysImported(scope.module);
			END;
		END TypeModifier;

		PROCEDURE IdentDef (VAR i: IdentDefDesc;  allowRO: BOOLEAN);			(* IdentDef = ident ["*"|"-"]. *)
		BEGIN
			i.vis := PCT.Internal;
			IF sym = ident THEN
				i.name := scanner.name; scanner.Get(sym)
			ELSE
				i.name := PCT.Anonymous;
				Error(ident, scanner.errpos)
			END;
			IF sym = times THEN
				i.vis := PCT.Public;  scanner.Get(sym)
			ELSIF sym = minus THEN
				IF allowRO THEN
					i.vis := PCT.Internal + {PCT.PublicR}
				ELSE
					i.vis := PCT.Public;  Error(47, scanner.errpos)
				END;
				scanner.Get(sym)
			END;
		END IdentDef;

		PROCEDURE OperatorDef(VAR i: IdentDefDesc; allowRO: BOOLEAN);
		VAR opName: PCS.Name;
		BEGIN
			i.vis:= PCT.Internal;
			opName := StringPool.GetIndex1(scanner.str);
			i.name := opName;
			IF ~scanner.IsOperatorValid() THEN
				PCM.Error(142, scanner.errpos, "");
			END;
			scanner.Get(sym);
			IF sym = times THEN
				i.vis := PCT.Public;
				scanner.Get(sym)
			ELSIF sym = minus THEN
				IF allowRO THEN
					i.vis := PCT.Internal + {PCT.PublicR}
				ELSE
					i.vis := PCT.Public;  Error(47, scanner.errpos)
				END;
				scanner.Get(sym)
			END;
		END OperatorDef;

		PROCEDURE FPSection(scope: PCT.ProcScope; pflags: SET); (* ejz *)
			VAR name: ARRAY 32 OF PCS.Name; i, n, res: LONGINT; VarPar: BOOLEAN;
				pos: ARRAY 32 OF LONGINT; t: PCT.Struct;
			(** fof >> *)
			ConstPar: BOOLEAN;
			(** << fof  *)

		BEGIN
			VarPar := sym = var;
			(** fof 070731 >> *)
			ConstPar := (sym = const);
			IF ConstPar THEN INCL( pflags, PCM.ReadOnly );  END;
			(** << fof  *)

			IF VarPar OR ConstPar (* fof 070731 *) THEN scanner.Get(sym) END;
			n := 0;
			LOOP
				pos[n] := scanner.errpos;
				name[n] := scanner.name;
				(** fof >> *)
				(*! temporary range as parameters, remove !*)
				Check( ident );
				IF sym = upto THEN  (* a..b BY c *)  (* range type fof *)
					IF VarPar THEN PCM.Error( 122, scanner.errpos, "" ) END;
					(*flags[n] := pflags + {rangeflag};*)  INC( n );
					scanner.Get( sym );  pos[n] := scanner.errpos;
					name[n] := scanner.name;
					(* flags[n] := pflags + {rangeflag};*)   INC( n );
					Check( ident );  Check( by );
					pos[n] := scanner.errpos;
					name[n] := scanner.name;  Check( ident );
					(*flags[n] := pflags + {rangeflag};*)

				ELSE (*flags[n] := pflags;  *)
				END;
				(** << fof  *)
				INC(n);
				(*Check(ident);*) (* fof *)
				IF sym # comma THEN EXIT END;
				scanner.Get(sym)
			END;
			Check(colon); Type(t, noname);
			i := 0;
			(* fof 070731 *)
			IF ConstPar & ((t IS PCT.Array) OR (t IS PCT.Record)) THEN VarPar := TRUE;
			END;
			WHILE i < n DO
				scope.CreatePar(PCT.Internal, VarPar, name[i], pflags, t, pos[i],  (* fof *) res); (* ejz *)
				IF res # PCT.Ok THEN PCM.ErrorN(res, pos[i], name[i]) END;
				INC(i)
			END
		END FPSection;

		PROCEDURE FormalPars(scope: PCT.ProcScope; VAR rtype: PCT.Struct; pflags: SET); (* ejz *)
			VAR o: PCT.Symbol; res: LONGINT;
		BEGIN
			rtype := PCT.NoType;
			IF sym = lparen THEN
				scanner.Get(sym);
				IF sym # rparen THEN
					FPSection(scope, pflags); (* ejz *)
					WHILE sym = semicolon DO
						scanner.Get(sym); FPSection(scope, pflags) (* ejz *)
					END;
				END;
				Check(rparen);
				IF sym = colon THEN
					scanner.Get(sym);
					IF sym = object THEN
						rtype := PCT.Ptr;
						scanner.Get(sym)
					ELSIF sym = array THEN
						scanner.Get(sym);
						ArrayType(rtype, FALSE  (* fof *));
					ELSE
						Qualident(o);
						IF (o IS PCT.Type) THEN
							rtype := o.type
						ELSE
							Error(52, scanner.errpos);
							rtype := PCT.UndefType
						END
					END;
					IF (rtype IS PCT.Array) & (rtype(PCT.Array).mode = PCT.open) THEN Error(91, scanner.errpos) END;
(* ug *)				IF (rtype # PCT.UndefType) & PCT.ContainsPointer(rtype) THEN
						scope.CreatePar(PCT.Internal, TRUE, PCT.PtrReturnType, pflags, rtype, 0 (* fof *),  res);
					END
				ELSIF scope.formalParCount = 0 THEN (* fn *)
					PCM.Warning (916, scanner.errpos, "");
				END
			END;
			IF {PCT.CParam, PCT.WinAPIParam} * pflags # {} (* fof for Linux *) THEN scope.ReversePars() END (* ejz *)
		END FormalPars;

		PROCEDURE CheckOperator(scope: PCT.ProcScope; VAR name: PCS.Name; rtype: PCT.Struct; pos: LONGINT);
		VAR
			opStr: ARRAY PCS.MaxStrLen OF CHAR;
			p: PCT.Parameter;
			recScope: PCT.RecScope;

			PROCEDURE CheckCardinality(nofparam: LONGINT): BOOLEAN;
			BEGIN
				CASE opStr[0] OF
				| "+", "-": RETURN (nofparam = 1) OR (nofparam = 2)
				| "~": RETURN (opStr[1] = 0X) & (nofparam = 1)
				| "[": RETURN nofparam > 0
				ELSE RETURN nofparam = 2
				END;
			END CheckCardinality;

		BEGIN
			StringPool.GetString(name, opStr);
			IF ~CheckCardinality(scope.formalParCount) THEN
				Error(143, pos);	(* invalid number of formal parameters *)
			END;
			IF opStr = ":=" THEN
				IF rtype # PCT.NoType THEN
					Error(147, pos);	(* operator ":=" has no return value *)
				END;
				IF ~scope.firstPar.ref THEN
					Error(148, pos);	(* first parameter of ":=" must be VAR *)
				END;
				IF (scope.firstPar.nextPar # NIL) & (scope.firstPar.type = scope.firstPar.nextPar.type) THEN
					PCM.Warning(Diagnostics.Invalid, pos, "Warning: both parameters of identical type");
				END
			ELSIF opStr = "[]" THEN
				IF (scope = NIL) OR (scope.parent = NIL) OR ~(scope.parent IS PCT.RecScope) THEN
					Error(990, pos)	(* operator "[]" only allowed in record scope *)
				ELSE
					recScope := scope.parent(PCT.RecScope);
					IF rtype = PCT.NoType THEN
						name := StringPool.GetIndex1(PCT.AssignIndexer);
					ELSE
						name := StringPool.GetIndex1(PCT.ReadIndexer);
					END
				END

			ELSE
				IF rtype = PCT.NoType THEN
					Error(141, pos);	(* all other operators must have a return value *)
				END
			END;
			p := scope.firstPar;
			WHILE (p # NIL) & PCT.IsBasic(p.type) DO
				p := p.nextPar;
			END;
			(* Ignore "[]" because SELF is an implicit parameter *)
			IF (opStr # "[]") & (p = NIL) THEN
				Error(146, pos);	(* at least one parameter must not be a basic type *)
			END;
		END CheckOperator;

		PROCEDURE RecordType(VAR t: PCT.Struct;  pointed: BOOLEAN);
			VAR recstruct: PCT.Record; ptr: PCT.Pointer; recscope: PCT.RecScope; recparser: RecordParser; bpos, res: LONGINT;
				intf: ARRAY 32 OF PCT.Interface;
		BEGIN
			t := PCT.NoType;
			(* fof removed NOTAG, doesn't have any effect
			IF sym = lbrak THEN
				scanner.Get(sym);
				IF sym = ident THEN
					IF scanner.name # notag THEN Error(scanner.name, scanner.errpos) END
				ELSE Error(scanner.name, scanner.errpos) END;
				scanner.Get(sym); Check(rbrak)
			END;
			*)
			IF sym = lparen THEN scanner.Get(sym); bpos := scanner.errpos; Type(t, noname); Check(rparen) END;
			NEW(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE);
			IF pointed THEN
				ptr := PCT.NewClass(t, intf, recscope, FALSE, res);
				IF res # PCT.Ok THEN Error(res, bpos) END;
				recstruct := ptr.baseR;
				t := ptr
			ELSE
				recstruct := PCT.NewRecord(t, recscope, {}, FALSE, res);
				IF res # PCT.Ok THEN Error(res, bpos) END;
				t := recstruct
			END;
			PCT.AddRecord(scope, recstruct);
			NEW(recparser, sync, recscope, scanner, sym);	(* let the record parser take care of this *)
			SkipScope;
		END RecordType;

		PROCEDURE Interface(): PCT.Interface;
		VAR o: PCT.Symbol; p: PCT.Pointer;
		BEGIN
			Qualident(o);
			IF (o # NIL) & (o IS PCT.Type) & (o.type IS PCT.Pointer) THEN
				p := o.type(PCT.Pointer);
				IF (p.baseR # NIL) & (PCT.interface IN p.baseR.mode) THEN
					RETURN p
				END
			END;
			PCM.Error(200, scanner.errpos, "not a definition");
			RETURN NIL
		END Interface;

		PROCEDURE ObjectType(VAR t: PCT.Struct;  name: StringPool.Index);
			VAR recstruct: PCT.Record; ptr: PCT.Pointer; recscope: PCT.RecScope; parser: ObjectParser; bpos, res, i: LONGINT;
				intf: ARRAY 32 OF PCT.Interface;

		BEGIN
			t := PCT.NoType;
			IF sym = lparen THEN scanner.Get(sym); bpos := scanner.errpos; Type(t, noname); Check(rparen) END;
			IF sym = implements THEN
				INCL(PCM.codeOptions, PCM.UseDefinitions);	(* type declaration -> interface registration *)
				INCL(PCM.codeOptions, PCM.ExportDefinitions);
				scanner.Get(sym);
				i := 1;
				intf[0] := Interface();
				WHILE sym = comma DO
					scanner.Get(sym); intf[i] := Interface(); INC(i)
				END
			END;
			NEW(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE);
			ptr := PCT.NewClass(t, intf, recscope, FALSE, res);
			IF res # PCT.Ok THEN Error(res, bpos) END;
			recstruct := ptr.baseR;
			t := ptr;
			PCT.AddRecord(scope, recstruct);
			NEW(parser, sync, recscope, scanner, sym);	(* let the record parser take care of this *)
			SkipScope;
			IF name # noname THEN
				IF sym # ident THEN
					PCM.ErrorN(ident, scanner.errpos, name)
				ELSIF  name # scanner.name THEN
					PCM.ErrorN(4, scanner.errpos, name);  scanner.Get(sym)
				ELSE
					scanner.Get(sym)
				END
			END
		END ObjectType;

		PROCEDURE DefinitionType(pos: LONGINT;  VAR t: PCT.Struct;  name: StringPool.Index);
		VAR  intf: ARRAY 1 OF PCT.Interface; parser: InterfaceParser; recscope: PCT.RecScope; int: PCT.Interface; res: LONGINT;
		BEGIN
			INCL(PCM.codeOptions, PCM.ExportDefinitions);
			IF sym = refines THEN
				scanner.Get(sym);
				intf[0] := Interface()
			END;
			Check(semicolon);
			NEW(recscope); PCT.SetOwner(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE);
			int := PCT.NewInterface(intf, recscope, FALSE, res);
			IF res # PCT.Ok THEN Error(res, pos) END;
			t := int;
			PCT.AddRecord(scope, int.baseR);
			NEW(parser, sync, recscope, scanner, sym);
			WHILE sym # end DO  scanner.Get(sym)  END;
			scanner.Get(sym);
			IF name # noname THEN
				IF sym # ident THEN
					PCM.ErrorN(ident, scanner.errpos, name)
				ELSIF  name # scanner.name THEN
					PCM.ErrorN(4, scanner.errpos, name);  scanner.Get(sym)
				ELSE
					scanner.Get(sym)
				END
			END
		END DefinitionType;

(** fof >> *)
		PROCEDURE TensorType( VAR t: PCT.Struct );
		VAR aarray: PCT.Tensor;  base: PCT.Struct;  res: LONGINT;
		BEGIN
			Type( base, noname );  NEW( aarray );  t := aarray;  PCT.InitTensor( aarray, base, res );
			IF res # PCT.Ok THEN Error( res, scanner.errpos ) END;
			t := aarray;
		END TensorType;
(** << fof  *)

		PROCEDURE ArrayType (VAR t: PCT.Struct;  enhArray: BOOLEAN (* fof *));
		VAR	index: PCB.Expression;  array: PCT.Array;  pos0, pos, res: LONGINT; base: PCT.Struct;
			(** fof >> *)
			earray: PCT.EnhArray;  first: BOOLEAN;  aarray: PCT.Tensor;
			(** << fof  *)
		BEGIN
			pos0 := scanner.errpos;

			(* fof removed NOTAG, doesn't have any effect
			IF sym = lbrak THEN
				scanner.Get(sym);
				IF sym = ident THEN
					IF scanner.name # notag THEN Error(scanner.name, scanner.errpos) END
				ELSE Error(scanner.name, scanner.errpos) END;
				scanner.Get(sym); Check(rbrak)
			END;
			*)

				(** fof >> *)
			IF (~enhArray) & (sym = lbrak) THEN enhArray := TRUE;  scanner.Get( sym );  first := TRUE ELSE first := FALSE END;

			IF first & (sym = PCS.qmark) THEN
				scanner.Get( sym );  Check( rbrak );  Check( of );  TensorType( t );
			ELSIF enhArray THEN
				IF sym = times THEN scanner.Get( sym );  index := NIL;  ELSE SimpleExpr( index );  END;

				IF sym = rbrak THEN
					scanner.Get( sym );  Check( of );  pos := scanner.errpos;  Type( base, noname );

				ELSIF sym = comma THEN scanner.Get( sym );  pos := scanner.errpos;  ArrayType( base, TRUE )
				ELSE Error( rbrak, scanner.errpos );  t := PCT.UndefType;  RETURN
				END;
				IF index = NIL THEN  (* open enh array *)
					NEW( earray );  t := earray;  PCT.InitOpenEnhArray( earray, base, {PCT.open}, res );
					IF res # PCT.Ok THEN Error( res, pos ) END;
				ELSIF ~PCT.IsCardinalType( index.type ) THEN  (* invalid type *)
					Error( 51, pos );  t := PCT.UndefType
				ELSIF index IS PCB.Const THEN  (* static enh array *)
					NEW( earray );  t := earray;  PCT.InitStaticEnhArray( earray, index( PCB.Const ).con.int, base, {PCT.static}, res );
				ELSE  (* dynamic sized enh array *)
					(* t := PCB.NewDynSizedEnhArray( index, base, res ); *)
					Error( 200, scanner.errpos );  t := PCT.UndefType;  RETURN
				END;
				IF res # PCT.Ok THEN Error( res, pos ) END
			(** << fof  *)
			ELSIF sym = of THEN
				scanner.Get(sym); pos := scanner.errpos; Type(base, noname);
				NEW(array); t := array;
				PCT.InitOpenArray(array, base, res);
				IF res # PCT.Ok THEN Error(res, pos) END
			ELSE
				SimpleExpr(index);
				IF sym = of THEN
					scanner.Get(sym); pos := scanner.errpos; Type(base, noname)
				ELSIF sym = comma THEN
					scanner.Get(sym); pos := scanner.errpos; ArrayType(base, FALSE  (* fof *))
				ELSE
					Error(of, scanner.errpos);  t := PCT.UndefType;
					RETURN
				END;
				IF ~PCT.IsCardinalType(index.type) THEN
					Error(51, pos); t := PCT.UndefType
				ELSIF index IS PCB.Const THEN
					NEW(array); t := array;
					PCT.InitStaticArray(array, index(PCB.Const).con.int, base, res)
				ELSE
					(*fof disabled semi-dynamic array functionality *)
					PCM.Error(50, pos, "");
					t := PCB.NewDynSizedArray(index, base, res)
				END;
				IF res # PCT.Ok THEN Error(res, pos) END
			END
		END ArrayType;

		PROCEDURE PointerType(VAR t: PCT.Struct;  name: StringPool.Index);
			VAR pos, pos1, res: LONGINT; id: PCS.Name; o: PCT.Symbol; ptr: PCT.Pointer;
		BEGIN
			IF sym = record THEN
				scanner.Get(sym);  RecordType(t, TRUE)
			ELSIF sym # ident THEN
				pos1:=scanner.errpos;
				Type(t, noname);
				NEW(ptr); PCT.InitPointer(ptr, t, res); t := ptr;
				IF res # PCT.Ok THEN Error(res, pos1) END
			ELSE	(* ident own handling, because of forwards *)
				id := scanner.name;
				scanner.Get(sym);
				IF sym = period THEN	(* Mod.Type *)
					o := PCT.Find(scope, scope, id, PCT.structdeclared, TRUE);
					IF o = NIL THEN
						Error(0, scanner.errpos);
						o := PCB.unknownObj
					ELSIF o IS PCT.Module THEN
						scanner.Get(sym);
						IF sym = ident THEN
							o := PCT.Find(scope, o(PCT.Module).scope, scanner.name, PCT.complete, TRUE);
							scanner.Get(sym);
							IF o = NIL THEN  Error(0, scanner.errpos); o := PCB.unknownObj  END
						ELSE
							Error(ident, scanner.errpos);
							o := PCB.unknownObj
						END
					END
				ELSE	(* Type *)
					o := PCT.Find(scope, scope, id, PCT.local, TRUE);
				END;
				IF o = NIL THEN
					NEW(ptr);
					forwardPtr[nofForwardPtr].ptr := ptr;
					forwardPtr[nofForwardPtr].name := id;
					INC(nofForwardPtr);
					t := ptr
				ELSIF o IS PCT.Type THEN
					NEW(ptr); PCT.InitPointer(ptr, o.type, res); t := ptr;
					IF res # PCT.Ok THEN Error(res, pos) END
				ELSE
					Error(52, scanner.errpos);  t := PCT.UndefType
				END
			END
		END PointerType;

		PROCEDURE Type (VAR t: PCT.Struct;  name: StringPool.Index);
			VAR o: PCT.Symbol; procscope: PCT.ProcScope;  pos, res: LONGINT;
				proc: PCT.Delegate; sf: SET;
		BEGIN
			pos := scanner.errpos;
			IF sym = array THEN
				Machine.AtomicInc(NArrays);
				scanner.Get(sym);  ArrayType(t, FALSE  (* fof *));
			ELSIF sym = record THEN
				Machine.AtomicInc(NRecords);
				scanner.Get(sym);  RecordType(t, FALSE);
			ELSIF sym = pointer THEN
				Machine.AtomicInc(NPointers);
				scanner.Get(sym); Check(to); PointerType(t, noname);
			ELSIF sym = object THEN
				scanner.Get(sym);
				IF (sym = semicolon) OR (sym = rparen) THEN
					t := PCT.Ptr	(* generic OBJECT *)
				ELSE
					Machine.AtomicInc(NObjects);
					ObjectType(t, name)
				END
			ELSIF sym = definition THEN
				Machine.AtomicInc(NDefinitions);
				scanner.Get(sym);
				DefinitionType(pos, t, name)
			ELSIF sym = procedure THEN
				Machine.AtomicInc(NProcedureTypes);
				scanner.Get(sym);
				TypeModifier(sf, {PCT.StaticMethodsOnly}, {PCT.StaticMethodsOnly, PCT.RealtimeProcType (* ug *), PCT.WinAPIParam, PCT.CParam} (* fof for Linux *) ); (* ejz *)
				IF (sf = {}) OR (sf = {PCT.RealtimeProc}) THEN Machine.AtomicInc(NDelegates) END;
				NEW(procscope); PCT.InitScope(procscope, scope, {}, FALSE); PCT.SetOwner(procscope);
				IF {PCT.CParam, PCT.WinAPIParam} * sf # {} (* fof for Linux *) THEN (* ejz *)
					IF scope IS PCT.ProcScope THEN
						PCM.Error(200, scanner.errpos, "invalid WINAPI proc")
					ELSIF PCT.CParam IN sf THEN (* fof for Linux *)
						procscope.SetCC( PCT.CLangCC )
			    		ELSE
						procscope.SetCC(PCT.WinAPICC)
					END
				END;
				FormalPars (procscope, t, sf - {PCT.StaticMethodsOnly}); (* ejz *)
				NEW(proc); PCT.InitDelegate(proc, t, procscope, sf, res);
				IF res # PCT.Ok THEN Error(res, pos) END;
				t := proc
			ELSE
				Qualident(o);
				IF (o IS PCT.Type) THEN
					t := o.type
				ELSE
					Error(52, scanner.errpos);  t := PCT.UndefType
				END
			END
		END Type;

		PROCEDURE VarDecl;
			VAR id: ARRAY MaxIdentDef OF IdentDefDesc;  pos: ARRAY MaxIdentDef OF LONGINT; (** fof  *) c, n, res: LONGINT;  t: PCT.Struct;  flag: ARRAY MaxIdentDef OF SET;
		BEGIN n := 1;
			pos[0] := scanner.errpos;   (* fof *)
			IdentDef (id[0], TRUE);
			TypeModifier(flag[0], {}, {PCM.Untraced});
			WHILE sym = comma DO
				scanner.Get(sym);
				pos[n] := scanner.errpos; (* fof *)
				IdentDef (id[n], TRUE);
				TypeModifier(flag[n], {}, {PCM.Untraced});
				INC(n)
			END;
			Check(colon); Type(t, noname);
			c := 0;
			WHILE c < n DO
				scope.CreateVar(id[c].name, id[c].vis, flag[c],  t, pos[c], (* fof *) NIL, res); INC(c);
				IF res # PCT.Ok THEN PCM.ErrorN(res, scanner.errpos, id[c-1].name) END
			END;
		END VarDecl;

		PROCEDURE TypeDecl;
			VAR i: IdentDefDesc; pos, res: LONGINT; t: PCT.Struct;
		BEGIN
			pos := scanner.errpos;
			IdentDef(i, FALSE); Check(eql); Type(t, i.name);
			scope.CreateType(i.name, i.vis, t, pos, (*fof*) res);
			IF res # PCT.Ok THEN PCM.ErrorN(res, pos, i.name) END;
		END TypeDecl;

		PROCEDURE ConstDecl;
			VAR i: IdentDefDesc; x: PCB.Const; pos, res: LONGINT;long: HUGEINT;
		BEGIN
			pos := scanner.errpos;
			IdentDef(i, FALSE);  Check(eql);  ConstExpr(x);
			scope.CreateValue(i.name, i.vis, x.con, pos, (*fof*) res);


				IF x.con.type = PCT.Int64 THEN
					long := x.con.long;
					IF long DIV 2 <= LONG(MAX(LONGINT)) THEN
						(*!fof: replace this with a warning once everything is converted *)
						PCM.Error(-1,pos,"unsigned longint is a hugeint -> use SHORT");
					END;
				END;

			IF res # PCT.Ok THEN PCM.ErrorN(res, pos, i.name) END
		END ConstDecl;

		PROCEDURE FixForwards;
		VAR obj: PCT.Symbol; state: SHORTINT; res: LONGINT;
		BEGIN
			state := PCT.structallocated;
			IF isRecord THEN state := PCT.structdeclared END;
			WHILE nofForwardPtr > 0 DO
				DEC(nofForwardPtr);
				obj := PCT.Find(scope, scope, forwardPtr[nofForwardPtr].name, state, TRUE);
				IF obj = NIL THEN
					PCM.ErrorN(128, scanner.errpos, forwardPtr[nofForwardPtr].name); obj := PCB.unknownObj
				END;
				PCT.InitPointer(forwardPtr[nofForwardPtr].ptr, obj.type, res);
				IF res # PCT.Ok THEN Error(res, scanner.errpos) END
			END
		END FixForwards;

		PROCEDURE ListOf(parse: PROCEDURE);
		BEGIN
			scanner.Get(sym);
			WHILE sym = ident DO
				parse;
				CheckSemicolons;
			END
		END ListOf;

		PROCEDURE DeclSeq;
		VAR t: PCT.Struct; name: PCS.Name; pos, res: LONGINT;
		BEGIN
			WHILE sym = definition DO
				pos := scanner.errpos;
				scanner.Get(sym);
				name := scanner.name;
				Check(ident);
				DefinitionType(pos, t, name);
				Check(semicolon);
				scope.CreateType(name, PCT.Public, t, pos(*fof*), res);
				IF res # PCT.Ok THEN PCM.ErrorN(res, pos, name) END
			END;
			LOOP
				IF sym = const THEN
					scanner.Get(sym);
					WHILE sym = ident DO
						ConstDecl;
						CheckSemicolons;
					END
				ELSIF sym = type THEN
					scanner.Get(sym);
					WHILE sym = ident DO
						TypeDecl;
						CheckSemicolons;
					END
				ELSIF sym = var THEN
					scanner.Get(sym);
					WHILE sym = ident DO
						VarDecl;
						CheckSemicolons;
					END
				ELSE
					EXIT
				END
			END;
			FixForwards;
			PCT.ChangeState(scope, PCT.structdeclared, scanner.errpos);
			PCT.ChangeState(scope, PCT.structallocated, scanner.errpos);
			WHILE sym = procedure DO
				scanner.Get(sym); ProcDecl;
				IF sym # end THEN Check(semicolon) END
			END;
			PCT.ChangeState(scope, PCT.procdeclared, scanner.errpos);
			savedsym := sym;
			savedscanner := scanner;
			scanner := PCS.ForkScanner(scanner);
			inspect := TRUE;
			Body(TRUE);  (* suppress = TRUE *)
			scanner := savedscanner;
			sym := savedsym;
			inspect := FALSE;
			PCT.ChangeState(scope, PCT.hiddenvarsdeclared, scanner.errpos);
		END DeclSeq;

		(* --------------------------------------------------------- *)
		(* Active Oberon Language Productions *)
		(* Implementation Section *)

		PROCEDURE Qualident (VAR o: PCT.Symbol);		(*Qualident = [ident "."] ident*)
			(* returns the object or unknownObj *)
			VAR pos: LONGINT;
		BEGIN
			IF sym = ident THEN
				IF scanner.name = self THEN
					o := PCT.Find(scope, scope, PCT.SelfName, PCT.procdeclared,  TRUE)
				ELSIF scope.state >= PCT.procdeclared THEN	(*parsing code*)
					o := PCT.Find(scope, scope, scanner.name, PCT.procdeclared, TRUE)
				ELSIF isRecord THEN
					o := PCT.Find(scope, scope, scanner.name, PCT.structdeclared, TRUE)	(*break scope <-> recordscope cycle*)
				ELSE
					o := PCT.Find(scope, scope, scanner.name, PCT.structallocated, TRUE)
				END;
				pos := scanner.errpos; scanner.Get(sym);
				IF o = NIL THEN
					Error(0, pos); o := PCB.unknownObj
				ELSIF (sym = period) & (o IS PCT.Module) THEN		(*semantic check needed because of language design*)
					scanner.Get(sym);
					IF sym = ident THEN
						o := PCT.Find(scope, o(PCT.Module).scope, scanner.name, PCT.procdeclared(*PCT.complete*), TRUE);
						scanner.Get(sym);
						IF o = NIL THEN Error(0, scanner.errpos);  o := PCB.unknownObj  END;
					ELSE Error(ident, scanner.errpos);
					END
				END
			ELSE o := PCB.unknownObj; Error(ident, scanner.errpos);
			END;
		END Qualident;

		PROCEDURE GetModule(VAR o: PCT.Symbol);
		BEGIN
			IF sym = ident THEN
				o := PCT.Find(scope, scope, scanner.name, PCT.structallocated, TRUE);
			ELSE
				o := PCB.unknownObj; Error(ident, scanner.errpos);
			END;
		END GetModule;

		(** fof >> *)
		PROCEDURE Range( VAR exp, texp, bexp: PCB.Expression ): BOOLEAN;
		VAR isRange: BOOLEAN;
		BEGIN
			exp := NIL;  texp := NIL;  bexp := NIL;

			IF sym = times THEN isRange := TRUE;  scanner.Get( sym );
			ELSIF sym = upto THEN  (* ".." without first argument *)
			ELSE Expr( exp );  isRange := FALSE;
			END;

			IF (sym = upto) THEN
				isRange := TRUE;  scanner.Get( sym );
				IF (sym = ident) & (scanner.name = StringPool.GetIndex1( "MAX" )) THEN
					scanner.Get( sym );
					IF sym = by THEN
						(* Error( 200, scanner.errpos );	*)
						scanner.Get( sym );  Expr( bexp );
					END;
				ELSIF sym = by THEN  (* ".." without second argument *)
					scanner.Get( sym );  Expr( bexp );
				ELSIF (sym = comma) OR (sym = rbrak) OR (sym = rparen) THEN  RETURN TRUE;
				ELSE
					Expr( texp );
					IF sym = by THEN
						(* Error( 200, scanner.errpos );	*)
						scanner.Get( sym );  Expr( bexp );
					END;
				END;
			END;
			RETURN isRange;
		END Range;
	(** << fof  *)

		PROCEDURE ExprList(VAR x: PCB.ExprList);
			VAR y: PCB.Expression;
			texp, bexp: PCB.Expression; z: PCB.Const;  range: BOOLEAN;   (* fof *)
		BEGIN
			(** fof >> *)
			LOOP
				IF Range( y, texp, bexp ) THEN
					IF y = NIL THEN NEW( z, scanner.errpos, PCT.NewIntConst( 0, PCT.Int32 ) );  y := z;  END;
					IF texp = NIL THEN NEW( z, scanner.errpos, PCT.NewIntConst( MAX( LONGINT ), PCT.Int32 ) );  texp := z END;
					IF bexp = NIL THEN NEW( z, scanner.errpos, PCT.NewIntConst( 1, PCT.Int32 ) );  bexp := z END;
					x.Append( y );  x.Append( texp );  x.Append( bexp );
				ELSE x.Append( y );
				END;
				IF sym = comma THEN scanner.Get( sym );  ELSE EXIT END;
			END;   (* loop *)
			(** << fof  *)
			(*
			Expr(y);  x.Append(y);
			WHILE sym = comma DO
				scanner.Get(sym); Expr(y);  x.Append(y)
			END
			*)
		END ExprList;

		PROCEDURE GetGuard(search: PCT.Scope; symbol: PCT.Symbol): PCT.Symbol;
		BEGIN
			WHILE search # NIL DO
				IF search IS PCT.WithScope THEN
					IF search(PCT.WithScope).withSym = symbol THEN
						RETURN search(PCT.WithScope).withGuard;
					END;
				END;
				search := search.parent;
			END;
			RETURN NIL;
		END GetGuard;

		PROCEDURE Designator(VAR x: PCB.Designator);
			VAR o: PCT.Symbol;  exp: PCB.Expression; y: PCB.Designator;
				guard: PCT.Symbol;
				ovlarray: BOOLEAN; m: PCT.Method;
			(** fof >> *)
			texp, bexp: PCB.Expression;   (* from .. to BY by *)
			range: BOOLEAN;  atype: PCT.Struct;  idx: PCB.EnhIndex;  aidx: PCB.AnyIndex;
			(** << fof  *)
		BEGIN
			LOOP
				IF x IS PCB.Var THEN
					guard := GetGuard(scope, x(PCB.Var).obj);
					IF guard # NIL THEN
						x := PCB.NewGuard(scanner.errpos, x, guard, FALSE);
					END;
				ELSIF x IS PCB.Field THEN
					guard := GetGuard(scope, x(PCB.Field).field);
					IF guard # NIL THEN
						x := PCB.NewGuard(scanner.errpos, x, guard, FALSE);
					END
				END;
				IF sym = period THEN
					scanner.Get(sym);
					IF sym = ident THEN
						x := PCB.NewField(codescope, x, scanner.name, scanner.errpos);  scanner.Get(sym)
					ELSE
						Error(ident, scanner.errpos)
					END
				ELSIF sym = lbrak THEN

					ovlarray := FALSE;
					IF x.type IS PCT.Pointer THEN
						IF (x.type(PCT.Pointer).base IS PCT.Record)  THEN
								m := PCT.FindIndexer(x.type(PCT.Pointer).base(PCT.Record).scope, StringPool.GetIndex1(PCT.ReadIndexer));
								IF m = NIL THEN
									m := PCT.FindIndexer(x.type(PCT.Pointer).base(PCT.Record).scope, StringPool.GetIndex1(PCT.AssignIndexer))
								END;
								ovlarray := m # NIL;
						END;
					END;

					IF ovlarray THEN
						RETURN
(** fof >> *)
					ELSIF x.type IS PCT.EnhArray THEN  (* enhanced array treatment *)
						idx := PCB.NewEnhIndex( scanner.errpos, x );  x := idx;
						(* NEW( idx, scanner.errpos, x );  x := idx; *)
						scanner.Get( sym );
						LOOP
							IF Range( exp, texp, bexp ) THEN  (* ranged expression of the form [exp] .. [texp] [BY bexp] *)
								idx.AppendRange( scanner.errpos, exp, texp, bexp );
							ELSE  (* exp is already parsed *)
								idx.AppendIndex( scanner.errpos, exp );
							END;
							IF sym # comma THEN EXIT END;
							scanner.Get( sym )
						END;
						Check( rbrak );  idx.Finish;
					ELSIF x.type IS PCT.Tensor THEN  (* any array treatment *)
						NEW( aidx, scanner.errpos, x );  x := aidx;  scanner.Get( sym );
						LOOP
							IF sym = filler THEN scanner.Get( sym );  aidx.AppendFiller( scanner.errpos );
							ELSIF Range( exp, texp, bexp ) THEN  (* ranged expression of the form [exp] .. [texp] [BY bexp] *)
								(* idx.AppendRange( scanner.errpos, exp, texp, bexp );  *)
								aidx.AppendRange( scanner.errpos, exp, texp, bexp );
							ELSE  (* exp is already parsed *)
								aidx.AppendIndex( scanner.errpos, exp );
							END;
							IF sym # comma THEN EXIT END;
							scanner.Get( sym )
						END;
						Check( rbrak );  aidx.Finish;
(** << fof  *)
					ELSE
						(** fof >> *)
						range := FALSE;  atype := x.type;
						(*IF x IS PCB.Range THEN PCM.Error( -1, scanner.errpos, "ranges cannot be indexed directly" );  END;  *)
						(** << fof  *)
						scanner.Get(sym);
						LOOP
							Expr(exp);  x := PCB.NewIndex(scanner.errpos, x, exp);
							IF sym # comma THEN EXIT END;
							scanner.Get(sym)
						END;
						Check(rbrak)
					END
				ELSIF sym = arrow THEN
					x := PCB.NewDeref(scanner.errpos, x);
					scanner.Get(sym)
				ELSIF (sym = lparen) & PCB.IsInterface(x) THEN
					INCL(PCM.codeOptions, PCM.UseDefinitions);	(* use lookup and call *)
					scanner.Get(sym);
					Qualident(o);
					y := PCB.MakeNode(scanner.errpos, codescope, o);
					Designator(y);
					Check(rparen);
					x := PCB.Interface(x, y)
				(*ELSIF (sym=lparen) & (x IS PCB.Type) THEN
					scanner.Get(sym); Expr(y); Check(rparen);
					x := PCB.NewConversion(scanner.errpos,y,x.type);
					*)
				ELSIF (sym = lparen) & ~x.IsCallable() & (scope.state >= PCT.procdeclared) THEN			(*needs semantic check because of ambiguous language design*)
																															(*in declaration phase only expressions make sense!*)
					scanner.Get(sym); Qualident (o); Check(rparen);
					x:=PCB.NewGuard(scanner.errpos, x, o, FALSE)
				ELSE
					EXIT (* -> ENDLOOP *)
				END;
			END (* LOOP *)
		END Designator;

		PROCEDURE Element(VAR x: PCB.Expression);
			VAR y: PCB.Expression; pos: LONGINT;
		BEGIN
			Expr(x);
			IF sym = upto THEN
				pos:=scanner.errpos;
				scanner.Get(sym); Expr(y); x:=PCB.NewDOp(pos, PCC.setfn, x, y)	(*this operator cannot be overwritten*)
			ELSE
				x := PCB.NewMOp(scanner.errpos, NIL, PCC.setfn, x);	(*this operator cannot be overwritten*)
			END
		END Element;

		PROCEDURE Set(VAR x: PCB.Expression);
			VAR y: PCB.Expression; pos: LONGINT;
		BEGIN
			scanner.Get(sym);
			IF sym # rbrace THEN
				Element(x);
				WHILE sym = comma DO
					pos:=scanner.errpos;
					scanner.Get(sym); Element(y);  x := PCB.NewDOp(pos, plus, x, y);
				END
			ELSE
				x := PCB.NewSetValue(scanner.errpos, {})
			END;
			Check(rbrace)
		END Set;

(** fof >> *)
		PROCEDURE MathArray( VAR x: PCB.Expression );
		(* temporary patch to make array expressions work. This will be improved in the new compiler *)
		VAR array: PCB.ArrayExpression;
			len: ARRAY 32 OF LONGINT;
			dim: LONGINT;  type: PCT.Struct;
			name: ARRAY 256 OF CHAR;
			error: BOOLEAN;
			bytes: POINTER TO ARRAY OF SYSTEM.BYTE;
			pos: LONGINT;  size: LONGINT;

			PROCEDURE Parse( a: PCB.ArrayExpression );
			VAR array: PCB.ArrayExpression; first,aq: PCB.ArrayQ;
			BEGIN
				NEW(aq); first := aq; a.pos := scanner.errpos;
				scanner.Get( sym );
				IF sym = lbrak THEN
					LOOP
						NEW( array );  Parse( array );  aq.e := array; aq.pos := scanner.errpos;
						IF sym = comma THEN
							scanner.Get( sym );
							IF sym # lbrak THEN PCM.Error( lbrak, scanner.errpos, "[ expected" );  EXIT;  END;
							NEW( aq.next );  aq := aq.next;
						ELSE EXIT
						END;
					END;
				ELSE
					LOOP
						aq.pos := scanner.errpos;  Expr( aq.e );
						IF sym = comma THEN scanner.Get( sym );  ELSE EXIT END;
						NEW( aq.next );  aq := aq.next;
					END;
				END;
				Check( rbrak );
				a.SetArray(first);
			END Parse;

			PROCEDURE CheckLens( a: PCB.ArrayQ;  d: LONGINT );
			VAR l, pos: LONGINT;
			BEGIN
				IF d > dim THEN dim := d END;
				l := 0;
				WHILE (a # NIL ) DO
					pos := a.pos;
					IF a.e IS PCB.ArrayExpression THEN  CheckLens( a.e(PCB.ArrayExpression).array, d + 1 ) END;
					a := a.next;  INC( l );
				END;
				IF len[d] = 0 THEN
					(* KernelLog.String("len["); KernelLog.Int(d,0); KernelLog.String("] = "); KernelLog.Int(l,0); KernelLog.Ln; *)
					len[d] := l
				ELSIF len[d] # l THEN PCM.Error( 999, pos, "array dimensions must be of equal size" );
				ELSE  (* KernelLog.String("(len["); KernelLog.Int(d,0); KernelLog.String("] ok)"); KernelLog.Ln; *)
				END;
			END CheckLens;

			PROCEDURE GetType( a: PCB.ArrayQ );
			VAR name: ARRAY 64 OF CHAR;
			BEGIN
				WHILE (a # NIL ) DO
					IF a.e IS PCB.ArrayExpression THEN GetType( a.e(PCB.ArrayExpression).array )
					ELSE
						PCT.GetTypeName( a.e.type, name );
						(* KernelLog.String("Type: "); KernelLog.String(name); KernelLog.Ln; *)
						IF type = NIL THEN type := a.e.type
						ELSIF a.e.type = type THEN  (* ok *)
						ELSIF PCT.IsBasic( a.e.type ) & PCT.IsBasic( type ) THEN
							IF (PCT.TypeDistance( type, a.e.type ) > 0) THEN type := a.e.type END;
						ELSE error := TRUE;  PCM.Error( 999, a.pos, "invalid type" );
						END;
					END;
					a := a.next;
				END;
			END GetType;

			PROCEDURE Convert( a: PCB.ArrayQ );
			VAR e: PCB.Expression;
			BEGIN
				WHILE (a # NIL ) DO
					IF a.e IS PCB.ArrayExpression  THEN Convert( a.e(PCB.ArrayExpression).array ) ELSE e := PCB.NewConversion( a.pos, a.e, type );  a.e := e;  INC( pos );  END;
					a := a.next;
				END;
			END Convert;

			PROCEDURE FillConst( a: PCB.ArrayQ );
			VAR s: SHORTINT;  i: INTEGER;  l: LONGINT;  r: REAL;  x: LONGREAL;  con: PCT.Const;
			BEGIN
				WHILE (a # NIL ) DO
					IF a.e IS PCB.ArrayExpression  THEN FillConst( a.e(PCB.ArrayExpression).array )
					ELSE
						IF a.e IS PCB.Const THEN
							con := a.e( PCB.Const ).con;
							IF type = PCT.Int8 THEN s := SHORT( SHORT( con.int ) );  SYSTEM.MOVE( ADDRESSOF( s ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Int16 THEN i := SHORT( con.int );  SYSTEM.MOVE( ADDRESSOF( i ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Int32 THEN l := con.int;  SYSTEM.MOVE( ADDRESSOF( l ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Float32 THEN r := SHORT( con.real );  SYSTEM.MOVE( ADDRESSOF( r ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Float64 THEN x := con.real;  SYSTEM.MOVE( ADDRESSOF( x ), ADDRESSOF( bytes[pos] ), size );
							ELSE PCM.Error( 200, a.pos, "basic types only" );
							END;
						ELSE
							IF type = PCT.Int8 THEN s := -1;  SYSTEM.MOVE( ADDRESSOF( s ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Int16 THEN i := -1;  SYSTEM.MOVE( ADDRESSOF( i ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Int32 THEN l := -1;  SYSTEM.MOVE( ADDRESSOF( l ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Float32 THEN r := -1;  SYSTEM.MOVE( ADDRESSOF( r ), ADDRESSOF( bytes[pos] ), size );
							ELSIF type = PCT.Float64 THEN x := -1;  SYSTEM.MOVE( ADDRESSOF( x ), ADDRESSOF( bytes[pos] ), size );
							ELSE PCM.Error( 200, a.pos, "basic types only" );
							END;
						END;
						INC( pos, size );
					END;
					a := a.next;
				END;

			END FillConst;

			PROCEDURE IsConst(a: PCB.ArrayQ): BOOLEAN;
			VAR result: BOOLEAN;
			BEGIN
				result := TRUE;
				WHILE (a # NIL) & result DO
					IF a.e IS PCB.ArrayExpression  THEN
						result := IsConst(a.e(PCB.ArrayExpression).array)
					ELSE
						result := a.e IS PCB.Const;
					END;
					a := a.next;
				END;
				RETURN result
			END IsConst;


		BEGIN
			error := FALSE;
			NEW( array);  Parse( array );  dim := -1;  CheckLens( array.array, 0 );
			(*KernelLog.String("dim="); KernelLog.Int(dim+1,0); KernelLog.Ln; *)
			type := NIL;  GetType( array.array );
			IF error THEN RETURN END;
			PCT.GetTypeName( type, name );
			(* KernelLog.String("Common type: "); KernelLog.String(name); KernelLog.Ln; *)
			IF ~error THEN
				Convert( array.array );
				(* KernelLog.String("is const");*)
				IF type = PCT.Int8 THEN size := 1
				ELSIF type = PCT.Int16 THEN size := 2
				ELSIF type = PCT.Int32 THEN size := 4
				ELSIF type = PCT.Float32 THEN size := 4
				ELSIF type = PCT.Float64 THEN size := 8
				END;
				IF IsConst(array.array) THEN
					NEW( bytes, size * pos );  pos := 0;
					FillConst( array.array );
					x := PCB.NewArrayValue( scanner.errpos, bytes^, len, dim + 1, type );
				ELSE
					array.SetType(PCT.MakeArrayType(len,dim+1,type,size));
					x := array;
				END;
			END;

			ASSERT(x#NIL);
		END MathArray;
(** << fof  *)

		PROCEDURE Factor(VAR x: PCB.Expression);
		VAR el: PCB.ExprList;  d, dh: PCB.Designator;  o: PCT.Symbol; h: PCT.Variable; hiddenVarName : StringPool.Index;
			rtype: PCT.Struct; pos: LONGINT; mod: PCT.Symbol; ap: PCB.AnyProc; res : LONGINT;
			m: PCT.Proc;
			pars: ARRAY 1 OF PCB.Expression; (* ug *)
			(** fof >> *)
			c: PCB.ConstDesignator;  y: PCB.Expression;  wasNot: BOOLEAN;
			(** << fof  *)
		BEGIN
			pos := scanner.errpos;
			wasNot := FALSE;   (* fof *)
			IF sym = number THEN
				CASE scanner.numtyp OF
				| PCS.char:	x := PCB.NewIntValue(scanner.errpos, scanner.intval, PCT.GetCharType(scanner.intval))
				| PCS.integer:	x := PCB.NewIntValue(scanner.errpos, scanner.intval, PCT.GetIntType(scanner.intval))
				| PCS.longinteger:	x := PCB.NewLongIntValue(scanner.errpos, scanner.longintval)
				| PCS.real:	x := PCB.NewFloatValue(scanner.errpos, scanner.realval, PCT.Float32)
				| PCS.longreal:	x := PCB.NewFloatValue(scanner.errpos, scanner.lrlval, PCT.Float64)
				END;
				scanner.Get(sym)
			ELSIF sym = string THEN
				x := PCB.NewStrValue(scanner.errpos, scanner.str);  scanner.Get(sym)
			ELSIF sym = nil THEN
				x:=PCB.NewNILValue(scanner.errpos); scanner.Get(sym)
			ELSIF sym = true THEN
				x := PCB.NewBoolValue(scanner.errpos, TRUE);  scanner.Get(sym)
			ELSIF sym = false THEN
				x := PCB.NewBoolValue(scanner.errpos, FALSE);  scanner.Get(sym)
			ELSIF sym = lbrace THEN	(*Set*)
				Set(x)
			(** fof >> *)
			ELSIF sym = lbrak THEN  (* constant array *)
				MathArray( x );
				IF x IS PCB.ArrayExpression THEN
					scope.CreateHiddenVarName(hiddenVarName);
					scope.CreateVar(hiddenVarName, PCT.Hidden, {}, x.type, pos, o, res);
					h := scope.FindHiddenVar(pos, o);
					dh := PCB.MakeNode(scanner.errpos, codescope, h);
					x(PCB.ArrayExpression).d := dh
				END;
			(** << fof  *)
			ELSIF sym = lparen THEN	(*Subexpression*)
				scanner.Get(sym); Expr(x) ; Check(rparen)
			ELSIF (sym=not) THEN
				wasNot := TRUE;   (* fof *)
				scanner.Get(sym);
				IF AllowOverloadedModule &  (* fof *)(sym = lbrak) & ~(PCM.NoOpOverloading IN PCM.parserOptions) THEN
					scanner.Get(sym);
					GetModule(mod);
					scanner.Get(sym);
					Check(rbrak);
				END;
				Factor(y (* fof *));
				IF (PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic((* fof *) y.type) THEN
					x := PCB.NewMOp(scanner.errpos, scope, not, y (* fof *))
				ELSE
					pars[0] := y (* fof *);
					x := CallOperator(not, mod, pars, pos);
				END;
			ELSIF (sym = ident) THEN
				Qualident(o);
				IF o IS PCT.Value THEN
					(** fof >> *)
					IF (o( PCT.Value ).const # NIL ) &
						(o( PCT.Value ).const.type IS PCT.EnhArray) THEN  (* may be used as designator *)
						d := PCB.MakeNode( scanner.errpos, codescope, o );  Designator( d );  x := d;
					ELSE
					(** << fof  *)
					x := PCB.NewValue(scanner.errpos, o)
					END;   (** fof  *)
				ELSE
					IF (sym = lparen) & (o IS PCT.Type) THEN
						scanner.Get(sym);
						Expr(x); Check(rparen);
						x := PCB.NewConversion(scanner.errpos,x,o.type);
					ELSE
						d := PCB.MakeNode(scanner.errpos, codescope, o); Designator(d);
						IF PCB.IsProcReturningPointer(d, rtype) & inspect THEN
							scope.CreateHiddenVarName(hiddenVarName);
							scope.CreateVar(hiddenVarName, PCT.Hidden, {}, rtype, pos, o, res);
						END;
						IF (sym = lparen)  THEN
								el := PCB.NewExprList(scanner.errpos, d);
								scanner.Get(sym);
								IF sym # rparen THEN ExprList(el) END;
								IF PCB.IsProcReturningPointer(d, rtype) THEN
									h := scope.FindHiddenVar(pos, o);
									ASSERT(h # NIL);
									dh := PCB.MakeNode(scanner.errpos, codescope, h);
									el.Append(dh)
								END;
								Check(rparen);
								IF PCT.IsRealtimeScope(scope) & ~PCB.IsRealtimeProc(d, scanner.errpos) THEN Error(160, scanner.errpos) END; (* ug *)
								x := PCB.NewFuncCall(scanner.errpos, d, el, scopelevel);
						ELSIF (sym = lbrak) THEN
								(* Find PCT.ReadIndexer method in scope of the type. *)
								m := PCT.FindIndexer(d.type(PCT.Pointer).base(PCT.Record).scope, StringPool.GetIndex1(PCT.ReadIndexer));
								IF m # NIL THEN
									NEW(ap, scanner.errpos, scope, m, d (* SELF *));
									d := ap;
									el:=PCB.NewExprList(scanner.errpos, d);
									scanner.Get(sym);
									IF sym # rbrak THEN ExprList(el) END;
									Check(rbrak);
									x := PCB.NewFuncCall(scanner.errpos, d, el, scopelevel);
								END
						ELSE x := d
						END
					END
				END;
			ELSE
				Error(13, scanner.errpos); x:=PCB.InvalidExpr;  scanner.Get(sym)
			END;
			(** fof >> *)
			(* suffix *)
			IF sym = PCS.transpose THEN
				IF wasNot THEN  (* transpose operator has higher precedence than not, reevaluate expression: *)
					x := PCB.NewMOp( scanner.errpos, scope, transpose, y );  x := PCB.NewMOp( scanner.errpos, scope, not, x );
				ELSE x := PCB.NewMOp( scanner.errpos, scope, transpose, x );
				END;
				scanner.Get( sym );
			END;
			(** << fof  *)
		END Factor;

		PROCEDURE Term(VAR x: PCB.Expression);
			VAR
				y : PCB.Expression;  op: PCS.Token; pos: LONGINT;
				mod: PCT.Symbol;
				pars: ARRAY 2 OF PCB.Expression; (* ug *)
		BEGIN
			Factor(x);
			WHILE (sym >= times) & (sym <= and) OR (sym >= backslash) & (sym <= egeq) (* fof *) DO
				pos:=scanner.errpos;  op := sym;  scanner.Get(sym);
				mod := NIL;
				IF AllowOverloadedModule &  (* fof *) (sym = lbrak) & ~((PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic(x.type)) THEN
					scanner.Get(sym);
					GetModule(mod);
					scanner.Get(sym);
					Check(rbrak);
				END;
				Factor(y);

				IF (PCM.NoOpOverloading IN PCM.parserOptions) OR (PCT.IsBasic(x.type) & PCT.IsBasic(y.type)) THEN
					x := PCB.NewDOp(pos, op, x, y)
				ELSE
					pars[0] := x; pars[1] := y; (* ug *)
					x := CallOperator(op, mod, pars, pos);
				END
			END
		END Term;

		PROCEDURE CallAssignmentOp(op: PCS.Token; mod: PCT.Symbol; p1: PCB.Designator; p2: PCB.Expression; pos: LONGINT; suppress: BOOLEAN);
		VAR
			pars: ARRAY 2 OF PCT.Struct;
			name: PCS.Name; o: PCT.Symbol; d: PCB.Designator; el: PCB.ExprList;
			parents: BOOLEAN;
			searchScope: PCT.Scope;
		BEGIN
			PCS.GetOpName(op, name);
			IF (mod # NIL) & (mod IS PCT.Module) THEN
				searchScope := mod(PCT.Module).scope;
				parents := FALSE;
			ELSE
				searchScope := scope;
				parents := TRUE;
			END;
			(* o := GetOperator(name, pars^, pos); *)
			pars[0] := p1.type; pars[1] := p2.type;
			o := PCT.FindOperator(scope, searchScope, parents, name, pars, LEN(pars), pos);

			IF o = NIL THEN
				(* Error(137, pos);	(* operator not defined *) *)
				PCB.Assign(code, suppress, p1, p2, FALSE  (*fof*));
			ELSE
				d := PCB.MakeNode(pos, codescope, o);
				Designator(d);
				el := PCB.NewExprList(pos, d);
				el.Append(p1);
				el.Append(p2);
				(* RETURN PCB.NewFuncCall(pos, d, el, scopelevel); *)
				PCB.CallProc(code, suppress, d, el,scopelevel);
			END;
		END CallAssignmentOp;

		PROCEDURE CallOperator(op: PCS.Token; mod: PCT.Symbol; pars: ARRAY OF PCB.Expression; pos: LONGINT): PCB.Expression;
		VAR
			name: PCS.Name; o: PCT.Symbol; d: PCB.Designator; el: PCB.ExprList;
			parents: BOOLEAN;
			searchScope: PCT.Scope;
			args: ARRAY 2 OF PCT.Struct;
			dh: PCB.Designator;  h: PCT.Variable; hiddenVarName : StringPool.Index;
			rtype: PCT.Struct; res, i : LONGINT;
		BEGIN
			PCS.GetOpName(op, name);
			IF (mod # NIL) & (mod IS PCT.Module) THEN
				searchScope := mod(PCT.Module).scope;
				parents := FALSE;
			ELSE
				searchScope := scope;
				parents := TRUE;
			END;
			FOR i := 0 TO LEN(pars)-1 DO
				args[i] := pars[i].type
			END;
			o := PCT.FindOperator(scope, searchScope, parents, name, args, LEN(pars), pos);
			IF o = NIL THEN
				(* Error(137, pos);	(* operator not defined *) *)
				IF LEN(pars) = 1 THEN
					RETURN PCB.NewMOp(pos, scope, op, pars[0])
				ELSE
					RETURN PCB.NewDOp(pos, op, pars[0], pars[1])
				END
			END;
			d := PCB.MakeNode(pos, codescope, o); Designator(d);
			IF PCB.IsProcReturningPointer(d, rtype) & inspect THEN
				scope.CreateHiddenVarName(hiddenVarName);
				scope.CreateVar(hiddenVarName, PCT.Hidden, {}, rtype, pos, o, res);
			END;
			el := PCB.NewExprList(pos, d);
			FOR i := 0 TO LEN(pars)-1 DO
				el.Append(pars[i])
			END;
			IF PCB.IsProcReturningPointer(d, rtype) THEN
				h := scope.FindHiddenVar(pos, o);
				ASSERT(h # NIL);
				dh := PCB.MakeNode(pos, codescope, h);
				el.Append(dh)
			END;
			IF PCT.IsRealtimeScope(scope) & ~PCB.IsRealtimeProc(d, scanner.errpos) THEN Error(160, scanner.errpos) END; (* ug *)
			RETURN PCB.NewFuncCall(pos, d, el, scopelevel);
		END CallOperator;

		PROCEDURE SimpleExpr(VAR x: PCB.Expression);
			VAR y: PCB.Expression;  op: PCS.Token;  pos: LONGINT;
				mod: PCT.Symbol;
				pars1: ARRAY 1 OF PCB.Expression; pars2: ARRAY 2 OF PCB.Expression; (* ug *)
		BEGIN
			IF (sym = plus) OR (sym = minus) THEN
				pos := scanner.errpos;
				op := sym;  scanner.Get(sym);
				IF AllowOverloadedModule &  (* fof *)(sym = lbrak) & ~(PCM.NoOpOverloading IN PCM.parserOptions) THEN
					scanner.Get(sym);
					GetModule(mod);
					scanner.Get(sym);
					Check(rbrak);
				END;
				Term(x);
				IF (PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic(x.type) THEN
					x := PCB.NewMOp(pos, scope, op, x)
				ELSE
					pars1[0] := x;
					x := CallOperator(op, mod, pars1, pos);
				END
			ELSE
				Term(x)
			END;
			WHILE (sym >= plus) & (sym <= or) DO
				pos:=scanner.errpos;
				op := sym;  scanner.Get(sym);
				mod := NIL;
				IF AllowOverloadedModule &  (* fof *) (sym = lbrak) & ~((PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic(x.type)) THEN
					scanner.Get(sym);
					GetModule(mod);
					scanner.Get(sym);
					Check(rbrak);
				END;
				Term(y);
				IF (PCM.NoOpOverloading IN PCM.parserOptions) OR (PCT.IsBasic(x.type) & PCT.IsBasic(y.type)) THEN
					x := PCB.NewDOp(pos, op, x, y)
				ELSE
					pars2[0] := x; pars2[1] := y; (* ug *)
					x := CallOperator(op, mod, pars2, pos);
				END
			END
		END SimpleExpr;

		PROCEDURE Expr(VAR x: PCB.Expression);
			VAR y: PCB.Expression;  op: PCS.Token; pos: LONGINT;
				mod: PCT.Symbol;
				pars : ARRAY 2 OF PCB.Expression; (* ug *)
		BEGIN
			SimpleExpr(x);
			IF (sym >= eql) & (sym <= is) THEN
				pos:=scanner.errpos;
				op := sym;  scanner.Get(sym);
				IF AllowOverloadedModule &  (* fof *)(sym = lbrak) & ~((PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic(x.type)) THEN
					scanner.Get(sym);
					GetModule(mod);
					scanner.Get(sym);
					Check(rbrak);
				END;
				SimpleExpr(y);
				IF (PCM.NoOpOverloading IN PCM.parserOptions) OR (PCT.IsBasic(x.type) & PCT.IsBasic(y.type)) THEN
					x := PCB.NewDOp(pos, op, x, y)
				ELSE
					pars[0] := x; pars[1] := y; (* ug *)
					x := CallOperator(op, mod, pars, pos);
				END
			END
		END Expr;

		PROCEDURE ConstExpr(VAR x: PCB.Const);
			VAR pos: LONGINT; y: PCB.Expression;
		BEGIN
			pos := scanner.errpos;
			Expr(y);
			x := PCB.ConstExpression(pos, y)
		END ConstExpr;

		PROCEDURE Case(body, suppress: BOOLEAN; VAR awaitCount: LONGINT; VAR caseinfo: PCB.CaseInfo);
			VAR x, y: PCB.Const; firstline: BOOLEAN;
		BEGIN
			firstline := TRUE;
			LOOP
				ConstExpr(x);  y := x;
				IF sym = upto THEN
					scanner.Get(sym); ConstExpr(y);
				END;
				PCB.CaseLine(code, suppress, caseinfo, x, y, firstline);
				firstline := FALSE;
				IF sym # comma THEN EXIT END;
				scanner.Get(sym)
			END;
			Check(colon);
			StatementSeq(body, suppress, awaitCount)
		END Case;

		PROCEDURE If(body, suppress: BOOLEAN; VAR awaitCount: LONGINT);
			VAR cond: PCB.Expression; info: PCB.LoopInfo;  ifsuppress, elsifclause: BOOLEAN;
		BEGIN
			(* if/elsif already checked *)
			elsifclause := FALSE;
			LOOP
				Expr(cond); Check(then);
				ifsuppress := PCB.If(code, suppress, info, cond, elsifclause);
				StatementSeq(body, suppress OR ifsuppress, awaitCount);
				IF sym # elsif THEN EXIT END;
				elsifclause := TRUE;
				scanner.Get(sym);
			END;
			IF sym = else THEN
				scanner.Get(sym);
				ifsuppress := PCB.Else(code, suppress, info);
				StatementSeq(body, suppress OR ifsuppress, awaitCount)
			END;
			PCB.EndIf(code, suppress, info);
			Check(end)
		END If;

		PROCEDURE BlockModifier(allowBody, suppress: BOOLEAN; VAR locked: BOOLEAN);
			VAR x: PCB.Const; c, res: LONGINT;
		BEGIN
			IF sym = lbrace THEN
				locked := FALSE;
				IF ~suppress THEN
					scanner.Get(sym);
					LOOP
						IF sym = ident THEN
							IF scanner.name = exclusive  THEN
								Machine.AtomicInc(NExclusive);
								IF allowBody THEN Machine.AtomicInc(NExclusiveMain) END;
								PCT.SetMode(scope, PCT.exclusive, res);
								scanner.Get(sym);
								locked := TRUE
							ELSIF allowBody & (scanner.name = active)  THEN
								Machine.AtomicInc(NActive);
								PCT.SetMode(scope, PCT.active, res);
								scanner.Get(sym)
							ELSIF allowBody & (scanner.name = realtime) THEN
								PCT.SetProcFlag(scope, PCT.RealtimeProc, res);
								scanner.Get(sym)
							ELSIF allowBody & (scanner.name = safe)  THEN
								PCT.SetMode(scope, PCT.safe, res);
								scanner.Get(sym)
							ELSIF allowBody & (scanner.name = priority)  THEN
								scanner.Get(sym);
								IF sym = lparen THEN
									scanner.Get(sym); ConstExpr(x); Check(rparen);
									IF ~PCT.IsCardinalType(x.type) THEN
										c:=0;  Error(51, scanner.errpos)
									ELSIF x.type # PCT.Int8 THEN
										c := 0; Error(220, scanner.errpos)
									ELSE
										c := x.con.int
									END
								ELSE
									c:=0
								END;
								IF isRecord THEN
									scope.parent(PCT.RecScope).owner.prio := c;
								ELSE
									PCM.Error(200, scanner.errpos, "priority only for records")
								END
							ELSE  Error(0, scanner.errpos); scanner.Get(sym) (*skip the ident, probably a typo*)
							END;
							IF res # PCT.Ok THEN Error(res, scanner.errpos); res := 0 END
						ELSE
							Check (ident);
						END;
						IF sym # comma THEN EXIT END;
						scanner.Get(sym)
					END;
					IF PCT.IsRealtimeScope(scope) THEN
						IF isRecord THEN
							scope.parent(PCT.RecScope).owner.prio := Objects.Realtime (* ug: realtime scope enforces priority realtime of active object *)
						END
					END;
					IF locked THEN
						IF PCT.IsRealtimeScope(scope) THEN Error(162, scanner.errpos) END;
					END;
				ELSE
					REPEAT scanner.Get(sym) UNTIL (sym = rbrace) OR (sym = eof);
				END;
				Check(rbrace)
			END
		END BlockModifier;

		PROCEDURE StatementBlock(body, suppress: BOOLEAN; VAR awaitCount: LONGINT);
		VAR  lock: BOOLEAN;
		BEGIN
			(*sym = begin*)
			scanner.Get(sym);
			BlockModifier(body, suppress, lock);
			IF ~inspect & body & notifyScope THEN  PCT.ChangeState(scope.parent, PCT.modeavailable, scanner.errpos)  END;	(*NEW waits for it*)
			IF ~suppress & lock THEN
				IF locked THEN Error(246, scanner.errpos) END;
				locked := TRUE;
				unlockOnExit := looplevel > 0;
				PCB.Lock(code, scope, scanner.errpos, TRUE);
				StatementSeq(body, suppress, awaitCount);
				PCB.Lock(code, scope, scanner.errpos, FALSE);
				unlockOnExit := FALSE;
				locked := FALSE
			ELSE
				StatementSeq(body, suppress, awaitCount)
			END;
			Check(end)
		END StatementBlock;

		PROCEDURE CallNewOnObject (code: PCC.Code;  suppress: BOOLEAN;  proc: PCB.Designator;  params: PCB.ExprList;  curlevel: SHORTINT);
		VAR varName: StringPool.Index; symbol: PCT.Variable; res: LONGINT; parameters: PCB.ExprList; item: PCB.Expression; tempVar: PCB.Designator;
		BEGIN
			symbol := codescope.FindHiddenVar (-PCB.newfn, codescope);
			ASSERT (suppress OR (symbol # NIL));
			IF symbol = NIL THEN
				codescope.CreateHiddenVarName(varName);
				codescope.CreateVar(varName, PCT.Hidden, {}, PCT.Ptr, -PCB.newfn, codescope, res);
				symbol := codescope.lastHiddenVar;
			END;
			symbol.type := params.first.type;
			parameters := PCB.NewExprList (params.pos, proc);
			tempVar := PCB.MakeNode (params.first.pos, codescope, symbol);
			parameters.Append (tempVar); item := params.first.link; WHILE item # NIL DO parameters.Append (item); item := item.link END;
			PCB.CallProc(code, suppress, proc, parameters, scopelevel);
			PCB.Assign (code, suppress, params.first(PCB.Designator), tempVar, FALSE);
		END CallNewOnObject;

		PROCEDURE StatementSeq(body, suppress: BOOLEAN; VAR awaitCount: LONGINT);
			VAR  d, d1: PCB.Designator; x, y: PCB.Expression; c: PCB.Const; o, o1: PCT.Symbol;
				param: PCB.ExprList;  pos, res, stack: LONGINT;
				oldscope: PCT.Scope; s: PCT.WithScope; procscope: PCT.ProcScope;
				awaitparser: AwaitParser;
				loopinfo: PCB.LoopInfo;  caseinfo: PCB.CaseInfo;
				first, ifsuppress, oldUnlockOnExit: BOOLEAN;
				oldforcount, i: LONGINT;
				mod: PCT.Symbol;
				name: StringPool.Index;
				proc: PCT.Proc; procScope: PCT.ProcScope;
				module: PCT.Module; modScope: PCT.ModScope;
				returnPos, temp: POINTER TO ARRAY OF LONGINT;
				ap: PCB.AnyProc; m: PCT.Method; indexer: BOOLEAN;
				sproc: PCB.SProc;
				ae: PCB.ArrayExpression;
				be: PCB.BuiltInEl;
				arrayType: PCT.EnhArray;
				aindex: POINTER TO ARRAY OF LONGINT;

				PROCEDURE AssignIndices(ae: PCB.ArrayExpression; dim: LONGINT);
				VAR a: PCB.ArrayQ; index: PCB.EnhIndex; i,j: LONGINT;
				BEGIN
					a := ae.array;
					i := 0;
					WHILE a # NIL DO
						aindex[dim] := i;
						IF a.e IS PCB.ArrayExpression THEN
							AssignIndices(a.e(PCB.ArrayExpression),dim+1);
						ELSE
							index := PCB.NewEnhIndex(d.pos,d);
							FOR j := 0 TO LEN(aindex)-1 DO
								index.AppendIndex(a.e.pos,PCB.NewIntValue(0,aindex[j],PCT.Int32));
							END;
							PCB.Assign(code,suppress, index, a.e, FALSE);
						END;
						INC(i); a := a.next;
					END;
				END AssignIndices;

		BEGIN
			LOOP
				IF (sym < ident) THEN
					Error(ident, scanner.errpos);
					REPEAT  scanner.Get(sym)  UNTIL  sym >= ident
				ELSIF (sym = semicolon) THEN
					PCM.Warning(315, scanner.errpos, "");
				END;
				pos:=scanner.errpos;
				IF ~suppress THEN PCC.NewInstr(code, pos) END;
				CASE sym OF
				| ident:
						Qualident(o);
						d := PCB.MakeNode(scanner.errpos, codescope, o); Designator(d);

						(* If the leftside of the assignment uses an indexer *)
						indexer := FALSE;
						IF sym = lbrak THEN
								m := PCT.FindIndexer(d.type(PCT.Pointer).base(PCT.Record).scope, StringPool.GetIndex1(PCT.AssignIndexer));
								IF m # NIL THEN
									NEW(ap, scanner.errpos, scope, m, d (* SELF *));
									d := ap;
									param:=PCB.NewExprList(scanner.errpos, d);
									scanner.Get(sym);
									IF sym # rbrak THEN ExprList(param) END;
									Check(rbrak);
									indexer := TRUE;
								END
						END;

						IF sym = becomes THEN
							scanner.Get(sym);
							mod := NIL;
							IF AllowOverloadedModule &  (* fof *)(sym = lbrak) & ~((PCM.NoOpOverloading IN PCM.parserOptions) OR PCT.IsBasic(d.type)) THEN
								scanner.Get(sym);
								GetModule(mod);
								scanner.Get(sym);
								Check(rbrak);
							END;
							Expr(y);

							IF (PCM.NoOpOverloading IN PCM.parserOptions) OR (PCT.IsBasic(d.type) & PCT.IsBasic(y.type)) THEN
								PCB.Assign(code, suppress, d, y, FALSE  (* fof *));
							ELSIF indexer THEN
								param.Append(y);
								IF PCT.IsRealtimeScope(scope) & ~PCB.IsRealtimeProc(d, scanner.errpos) THEN Error(160, scanner.errpos) END; (* ug *)
								PCB.CallProc(code, suppress, d, param, scopelevel)
							ELSE
								CallAssignmentOp(becomes, mod, d, y, scanner.errpos, suppress)
							END
						ELSIF ~indexer THEN
							param:=PCB.NewExprList(scanner.errpos, d);
							IF sym = lparen THEN
								scanner.Get(sym);
								IF sym # rparen THEN  ExprList(param)  END;
								Check(rparen)
							END;
							IF PCT.IsRealtimeScope(scope) & ~PCB.IsRealtimeProc(d, scanner.errpos) THEN Error(160, scanner.errpos) END; (* ug *)
							IF (d IS PCB.SProc) & (d(PCB.SProc).nr = PCB.newfn) & (param.first # NIL) & (param.first.type IS PCT.Pointer) & (param.first.type(PCT.Pointer).baseR # NIL) THEN
								CallNewOnObject (code, suppress, d, param, scopelevel);
							ELSE
								PCB.CallProc(code, suppress, d, param, scopelevel);
							END;
						ELSE
							HALT(MAX(INTEGER));
						END (* if -> proccall *);
						indexer := FALSE;
				| if:
						scanner.Get(sym); If(FALSE, suppress, awaitCount)
				| with:
						first := TRUE;
						REPEAT
							IF (sym = bar) & first THEN
								PCM.Error(end, scanner.errpos, "Oberon-2 WITH not supported");
								first := FALSE
							END;
							scanner.Get(sym);	(*skip with or bar *)
							IF sym = ident THEN
								Qualident(o);
								IF o = NIL THEN  Error(0,  scanner.errpos);  o := PCB.unknownObj  END;
								d:=PCB.MakeNode(scanner.errpos, codescope, o);
							ELSE
								Error(ident, scanner.errpos);  d:=PCB.InvalidDesig
							END;
							Check(colon); Qualident(o1);  d1:=PCB.MakeNode(scanner.errpos, codescope, o1);
							NEW(s); PCT.InitScope(s, scope, {}, FALSE); PCT.SetOwner(s);
							IF (o # NIL) & (o IS PCT.Variable) THEN
									s.withSym := o;
									s.withGuard := o1;
							ELSE
								Error(130, pos);
							END;
							oldscope := scope;  scope := s;
							PCT.ChangeState(s, PCT.complete, scanner.errpos);
							Check(do);
							ifsuppress := PCB.If(code, suppress, loopinfo, PCB.NewMOp(scanner.errpos, NIL, not, PCB.NewDOp(scanner.errpos, is, d, d1)), FALSE);
							PCB.Trap(code, suppress OR ifsuppress, PCM.WithTrap);
							ifsuppress := PCB.Else(code, suppress, loopinfo);
							StatementSeq(FALSE, suppress OR ifsuppress, awaitCount);
							PCB.EndIf(code, suppress, loopinfo);
							scope := oldscope;
						UNTIL sym # bar;
						IF sym = else THEN
							IF first THEN PCM.Error(end, scanner.errpos, "Oberon-2 WITH not supported") END;
							scanner.Get(sym);
							StatementSeq(FALSE, TRUE, awaitCount)
						END;
						Check(end)
				| case:
						scanner.Get(sym); Expr(x); Check(of);
						PCB.Case(code, suppress, caseinfo, x);
						LOOP
							IF sym < bar THEN Case(FALSE, suppress, awaitCount, caseinfo) END;
							IF sym = bar THEN scanner.Get(sym) ELSE EXIT END
						END;
						PCB.CaseElse(code, suppress, caseinfo);
						IF sym = else THEN
							scanner.Get(sym); StatementSeq(FALSE, suppress, awaitCount)
						ELSE
							PCB.Trap(code, suppress, PCM.CaseTrap)
						END;
						PCB.CaseEnd(code, suppress, caseinfo);
						Check(end);
				| while:
						scanner.Get(sym); Expr(x); pos := scanner.errpos; Check(do);
						PCB.While(code, suppress, loopinfo, x);
						StatementSeq(FALSE, suppress, awaitCount); Check(end);
						PCB.EndLoop(code, suppress, loopinfo);
				| repeat:
						PCB.BeginLoop(code, suppress, loopinfo);
						scanner.Get(sym); StatementSeq(FALSE, suppress, awaitCount);  Check(until); Expr(x);
						PCB.Repeat(code, suppress, loopinfo, x);
				| for:
						scanner.Get(sym);
						IF sym = ident THEN
							o:=PCT.Find(scope, scope, scanner.name, PCT.structallocated, TRUE);
							IF o = NIL THEN  Error(0, scanner.errpos);  o := PCB.unknownObj  END;
							d:=PCB.MakeNode(scanner.errpos, codescope, o); scanner.Get(sym)
						ELSE
							Error(ident, scanner.errpos);  d:=PCB.InvalidDesig
						END;
						Check(becomes); Expr(x);
						Check(to); Expr(y);
						IF sym = by THEN  scanner.Get(sym); ConstExpr(c)  ELSE  c:=PCB.NewIntValue(scanner.errpos, 1, PCT.Int8)(*PCB.One*)  END;
						PCB.BeginFor(code, suppress, pos, d, x, y, c, loopinfo);
						stack := PCC.GetStaticSize(d.type);
						INC(stack, (-stack) MOD 4);	(*align*)
						stack := stack DIV 4;
						INC(forexitcount, stack); INC(forretcount, stack);
						Check(do); StatementSeq(FALSE, suppress, awaitCount); Check(end);
						DEC(forexitcount, stack); DEC(forretcount, stack);
						PCB.EndFor(code, suppress, pos, d, c, loopinfo)
				| loop:
						oldforcount := forexitcount; forexitcount := 0;
						loopinfo := curloop;  INC(looplevel);
						oldUnlockOnExit := unlockOnExit; unlockOnExit := FALSE;
						PCB.BeginLoop(code, suppress, curloop);
						scanner.Get(sym); StatementSeq(FALSE, suppress, awaitCount); Check(end);
						PCB.EndLoop(code, suppress, curloop);
						unlockOnExit := oldUnlockOnExit;
						curloop := loopinfo;  DEC(looplevel);
						forexitcount := oldforcount
				| exit:
						pos:=scanner.errpos; scanner.Get(sym);
						IF looplevel = 0 THEN
							Error(exit, scanner.errpos)
						ELSE
							IF unlockOnExit THEN
								PCB.Lock(code, scope, scanner.errpos, FALSE);
							END;
							PCB.Exit(code, suppress, curloop, forexitcount);
							suppress := TRUE
						END
				| return:
						IF returnPos = NIL THEN (* retcount = 0 *)
							NEW(returnPos,128);
							returnPos[0] := scanner.errpos;
						ELSE
							ASSERT(retcount # 0);
							IF retcount >= LEN(returnPos) THEN
								NEW(temp, LEN(returnPos) * 2);
								FOR i := 0 TO LEN(returnPos) - 1 DO
									temp[i] := returnPos[i];
								END;
								returnPos := temp
							END;
							returnPos[retcount] := scanner.errpos
						END;
						scanner.Get(sym);
						IF sym < semicolon THEN  Expr(x);  ELSE  x := NIL  END;
						PCB.Return(code, suppress, codescope, pos, x, locked, forretcount);		(*use the declaration scope!*)
						INC(retcount); suppress := TRUE;
				| passivate:
						IF (~locked) & (~suppress)  THEN
							PCM.Warning(314, scanner.errpos, "");
						END;
						scanner.Get(sym);
						Check(lparen);
						scope.CreateAwaitProcName(name, awaitCount); INC(awaitCount);
						IF inspect THEN
							NEW(procscope); PCT.InitScope(procscope, scope, {}, FALSE);
							PCT.SetOwner(procscope);
							scope.CreateProc(name, PCT.Internal, {}, procscope, PCT.Bool, pos, res);
							NEW(awaitparser, sync, procscope, scanner, sym);
						END;
						Expr(x);		(* ug: instead of not existing SkipExpr() *)
						PCB.Await(code, suppress, scope, pos, name);
						Check(rparen);
						IF PCT.IsRealtimeScope(scope) THEN Error(162, scanner.errpos) END;
				| begin:
						StatementBlock(FALSE, suppress, awaitCount)
				| finally:
						IF ~suppress THEN
							IF body THEN

								IF fincount > 0 THEN
									Error(162, scanner.errpos);
								ELSE
									IF retcount > 0 THEN
										IF returnPos = NIL THEN
											Error(161, scanner.errpos);
										ELSE
											FOR i:= 0 TO LEN(returnPos) - 1 DO
												Error(161, returnPos[i]);
											END;
										END;
									END;
								END;

								IF (fincount = 0) & (retcount = 0) THEN
									IF (scope # NIL) & (scope IS PCT.ProcScope) THEN
										procScope := scope(PCT.ProcScope);
										proc := procScope.ownerO;
										PCB.Finally(pos, code, proc);
									ELSIF (scope # NIL) & (scope IS PCT.ModScope) THEN
										modScope := scope(PCT.ModScope);
										module := modScope.owner;
										PCB.Finally(pos, code, module);
									END;

								END;
							ELSE
								Error(160, scanner.errpos);
							END;
							INC(fincount)
						END;
						scanner.Get(sym); StatementSeq(body, suppress, awaitCount); (* Parse the rest recursive*)
				ELSE
					(* Error(end) *)
				END;

				IF sym = semicolon THEN scanner.Get(sym)
				ELSIF (sym <= ident) OR (if <= sym) & (sym <= return) THEN Error(semicolon, scanner.errpos)
				ELSIF sym = finally THEN
				ELSE EXIT
				END
			END (*loop*)
		END StatementSeq;

		PROCEDURE Body(suppress : BOOLEAN);
		VAR
			owner: PCT.Proc;
			name: ARRAY 32 OF CHAR;
			export: BOOLEAN;
			awaitCount: LONGINT;	(* parsing a body starts with awaitCount = 0 *)
		BEGIN
			IF sym = begin THEN
				IF suppress THEN
					StatementBlock(TRUE, suppress, awaitCount)
				ELSE
					retcount := 0;
					fincount := 0;
					PCT.GetScopeName(scope, name);
					IF inline THEN  Error(200, scanner.errpos)  END;
					code := PCB.Enter(scope);
					StatementBlock(TRUE, suppress, awaitCount);
					IF (scope # NIL) & (scope IS PCT.ProcScope) THEN
						owner := scope(PCT.ProcScope).ownerO;
						IF (owner.type # PCT.NoType) & (retcount = 0) THEN
							PCM.Warning(313, scanner.errpos, "")
						END
					END;
					PCB.Leave(code, scope, FALSE)
				END
			ELSIF sym = codeToken THEN
				IF ~suppress THEN
					INCL(PCT.System.flags, PCT.used);
					export := (scope IS PCT.ModScope) OR
						((scope IS PCT.ProcScope) & (PCT.Public * scope(PCT.ProcScope).ownerO.vis # {}));
					IF Assemble = NIL THEN	(*no assembler installed*)
						PCM.Error(0, scanner.errpos, "no assembler available")
					ELSIF inline THEN
						scope.code := Assemble(scanner, scope, export, TRUE)
					ELSE
						code := PCB.Enter(scope);
						PCB.Inline(code, Assemble(scanner, scope, export, FALSE));
						PCB.Leave(code, scope, TRUE)
					END
				END;
				scanner.SkipUntilNextEnd (sym);
				Check(end)
			ELSE
				IF ~suppress THEN
					code := PCB.Enter(scope);
					PCB.Leave(code, scope, FALSE);
				END;
				IF (sym = var) OR (sym = const) OR (sym = type) THEN
					PCM.Error(43, scanner.errpos, "data decl after proc decl")
				ELSIF (sym # end) THEN
					Error(43, scanner.errpos)
				ELSE
					scanner.Get(sym)
				END
			END
		END Body;

		PROCEDURE ProcDecl;
		VAR
			procparser: ProcedureParser; procscope: PCT.ProcScope; pos, res: LONGINT;
			i: IdentDefDesc; flags: SET; rtype: PCT.Struct; forward, suppress : BOOLEAN;
			opName: PCS.Name; pflags: SET; right: SHORTINT; (* ejz *)
			opStr: ARRAY PCS.MaxStrLen OF CHAR;
		BEGIN
			flags := {}; forward := FALSE; pflags := {}; (* ejz *)
			CASE sym OF
			| minus:
				INCL(flags, PCT.Inline); scanner.Get(sym)
			| and:
				INCL(flags, PCT.Constructor);  scanner.Get(sym)
			| times:
				(*compatibility with Ceres, ignore*)
				scanner.Get(sym);
				PCM.Error(237, scanner.errpos, "")
			| arrow:
				forward := TRUE; scanner.Get(sym);
				PCM.Warning(238, scanner.errpos, "")
			| lbrak, lbrace: (* ejz *)
				IF sym = lbrak THEN right := rbrak ELSE right := rbrace END;
				REPEAT
					scanner.Get(sym);
					IF (sym = ident) & (scanner.name = winapi) THEN
						(* scope proc is winapi *)
						CheckSysImported(scope.module);
						INCL(pflags, PCT.WinAPIParam);
					ELSIF (sym = ident) & (scanner.name = clang) THEN  (* fof for Linux *)
							(* scope proc is c *)
						CheckSysImported(scope.module);
						INCL( pflags, PCT.CParam );
					ELSIF (sym = ident) & (scanner.name = realtime) THEN
						INCL(flags, PCT.RealtimeProc);
					ELSE
						PCM.Error(200, scanner.errpos, "unknown calling convention")
					END;
					scanner.Get(sym);
				UNTIL sym # comma;
				Check(right);
				IF (PCT.RealtimeProc IN flags) & (sym = minus) THEN
					INCL(flags, PCT.Inline); scanner.Get(sym)
				END
			ELSE
			END;
			pos:=scanner.errpos;
			IF PCM.NoOpOverloading IN PCM.parserOptions THEN
				IF (sym = string) OR (sym = number) & (scanner.numtyp = PCS.char) THEN
					suppress := TRUE;
					PCM.Error(200, scanner.errpos, "operators not supported")
				END;
				IdentDef(i, FALSE);
			ELSE
				IF (sym = string) OR (sym = number) & (scanner.numtyp = PCS.char) THEN
					OperatorDef(i, FALSE);
					INCL(flags, PCT.Operator);
					StringPool.GetString(i.name, opStr);
					IF (opStr # "[]") & (scope IS PCT.RecScope) THEN
						PCM.Error(140, scanner.errpos, "");
					ELSIF opStr = "[]" THEN
						INCL(flags, PCT.Indexer)
					END;
				ELSE
					IdentDef(i, FALSE);
				END;
			END;

			NEW(procscope); PCT.InitScope(procscope, scope, {PCT.AutodeclareSelf}, FALSE);
			IF {PCT.CParam, PCT.WinAPIParam} * pflags # {} (* fof for Linux *)  THEN (* ejz *)
				IF scope IS PCT.ProcScope THEN (* ejz *)
					PCM.Error(200, scanner.errpos, "invalid WINAPI proc")
				ELSIF PCT.CParam IN pflags THEN  (* fof for Linux *)
					procscope.SetCC( PCT.CLangCC )
				ELSE
					procscope.SetCC(PCT.WinAPICC)
				END
			END;
			PCT.SetOwner(procscope);
			FormalPars(procscope, rtype, pflags); (* ejz *)
			IF PCT.Operator IN flags THEN CheckOperator(procscope, i.name, rtype, pos) END;
			IF forward THEN RETURN END;	(*don't register this procedure, just ignore it*)
			Check(semicolon);
			scope.CreateProc(i.name, i.vis, flags, procscope, rtype, pos(*fof*), res);
			IF res # PCT.Ok THEN PCM.ErrorN(res, pos, i.name) END;
			NEW(procparser, sync, procscope, PCT.Inline IN flags, scanner, sym);	(*parse the rest of scope*)
			SkipScope;	(* skip the record scope, the other parser is parsing it *)
			IF suppress THEN
				scanner.Get(sym)
			ELSIF (sym = string) OR (sym = number) & (scanner.numtyp = PCS.char) THEN
				opName := StringPool.GetIndex1(scanner.str);
				IF (opName # i.name) & ~(PCT.Indexer IN flags) THEN
					PCM.ErrorN(4, scanner.errpos, i.name)
				ELSIF (PCT.Indexer IN flags) & (scanner.str # "[]") THEN
					PCM.ErrorN(4, scanner.errpos, i.name)
				END;
				scanner.Get(sym);
			ELSIF sym = ident THEN
				IF scanner.name # i.name THEN PCM.ErrorN(4, scanner.errpos, i.name) END;	(*[S8;1;2]*)
				scanner.Get(sym)
			ELSE PCM.ErrorN(ident, scanner.errpos, i.name)
			END
		END ProcDecl;

		PROCEDURE SkipScope;
		VAR cnt: LONGINT;
		BEGIN
			(*skip decl section*)
			WHILE (sym # eof) & (sym # begin) & (sym # end) & (sym # codeToken) DO
				IF (sym = record) THEN
					scanner.Get(sym); SkipScope
				ELSIF (sym = object) THEN
					scanner.Get(sym);
					IF (sym # semicolon) & (sym # rparen) THEN SkipScope END
				ELSIF sym = procedure THEN
					scanner.Get(sym);
					IF sym = lbrace THEN (* allow REALTIME and/or DELEGATE modifier *)
						WHILE sym # rbrace DO scanner.Get(sym) END;
						scanner.Get(sym);
					END;
					IF (sym = and) OR (sym = minus) THEN scanner.Get(sym) END;
					IF (sym = ident) OR (sym = string) OR (sym =  number) & (scanner.numtyp = PCS.char) THEN SkipScope END;
				ELSE
					scanner.Get(sym)
				END
			END;
			(*skip statseq *)
			IF sym = begin THEN
				scanner.Get(sym); cnt := 1;
				WHILE cnt > 0 DO
					IF (sym = if) OR (sym = case) OR (sym = while) OR (sym = for) OR (sym = loop) OR (sym = with) OR (sym = begin) THEN
						INC(cnt)
					ELSIF sym = end THEN
						DEC(cnt)
					ELSIF sym = eof THEN
						cnt := 0
					END;
					scanner.Get(sym)
				END
			ELSIF sym = codeToken THEN
				scanner.SkipUntilNextEnd (sym);
				scanner.Get(sym)
			ELSIF sym = end THEN
				scanner.Get(sym);
			END;
		END SkipScope;
	(** fof >> *)
		PROCEDURE Epilog;
		END Epilog;
	(** << fof  *)

	BEGIN {ACTIVE}
		IF die THEN  sync.Exit;  RETURN  END;
		PCT.SetOwner(scope);
		DeclSeq;
		Body(FALSE);	(* suppress = FALSE *)
		Epilog;   (* fof *)
		PCT.ChangeState(scope, PCT.complete, scanner.errpos);
		sync.Exit
	END Parser;
(** fof >> *)
	CustomArrayParser = OBJECT (Parser)
	VAR
		bodyscope: PCT.ProcScope; old: PCT.Scope;

		PROCEDURE Body(suppress: BOOLEAN);	(*override Parser.Body*)
		BEGIN
			IF sym = begin THEN
				scope := bodyscope; codescope := scope;
				notifyScope := ~suppress;
				Body^(suppress);
				IF inspect THEN		(* body was inspected for hidden variables *)
					PCT.ChangeState(scope, PCT.hiddenvarsdeclared, scanner.errpos)
				ELSE				(* normal code generation *)
					PCT.ChangeState(scope, PCT.complete, scanner.errpos)
				END;
				scope := old; codescope := scope
			ELSE
				IF (sym = var) OR (sym = const) OR (sym = type) THEN
					PCM.Error(43, scanner.errpos, "data decl after proc decl")
				ELSIF (sym # end) THEN
					Error(43, scanner.errpos)
				ELSE
					scanner.Get(sym)
				END
			END
		END Body;

		PROCEDURE DeclSeq;	(* vars and procs are allowed, no const and types *)
		VAR res: LONGINT;
		BEGIN
			LOOP
				(* allow ident w/o var, to minimize the misleading err 83 in the rest of the module *)
				IF (sym = var) OR (sym = ident) THEN
					IF sym = var THEN scanner.Get(sym) ELSE PCM.Error(end, scanner.errpos, "or maybe VAR") END;
					WHILE sym = ident DO
						VarDecl;
						IF sym # end THEN
							CheckSemicolons;
						END;
					END
				ELSIF sym = semicolon THEN
					CheckSemicolons; (* advances to next symbol *)
				ELSE EXIT
				END
			END;
			FixForwards;
			PCT.ChangeState(scope, PCT.structdeclared, scanner.errpos);
			PCT.ChangeState(scope, PCT.structallocated, scanner.errpos);
			WHILE sym = procedure DO
				scanner.Get(sym); ProcDecl;
				IF sym # end THEN Check(semicolon) END
			END;
			IF sym = begin THEN
				old := scope;
				NEW(bodyscope); PCT.InitScope(bodyscope, scope, {PCT.AutodeclareSelf}, FALSE); PCT.SetOwner(bodyscope);
				scope.CreateProc(PCT.BodyName, PCT.Public, {}, bodyscope, PCT.NoType, scanner.errpos(*fof*), res); ASSERT(res = PCT.Ok);
				PCT.ChangeState(scope, PCT.procdeclared, scanner.errpos);    (* ug: must be done explicitly here in order to allow cross method calls of objects *)
				PCT.ChangeState(bodyscope, PCT.procdeclared, scanner.errpos);
				savedsym := sym;
				savedscanner := scanner;
				scanner := PCS.ForkScanner(scanner);
				inspect := TRUE;
				Body(TRUE);  (* suppress = TRUE *)
				scanner := savedscanner;
				sym := savedsym;
				inspect := FALSE
			END
		END DeclSeq;

		PROCEDURE & InitRec*(sync: Barrier; recscope: PCT.CustomArrayScope; s: PCS.Scanner; sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			isRecord := TRUE;
			scope := recscope; codescope := recscope; SELF.sym := sym; scopelevel := 0; looplevel := 0;
			scanner := PCS.ForkScanner(s);
		END InitRec;
	END CustomArrayParser;

(** << fof  *)

	ObjectParser = OBJECT (Parser)
	VAR
		bodyscope: PCT.ProcScope; old: PCT.Scope;

		PROCEDURE Body(suppress: BOOLEAN);	(*override Parser.Body*)
		BEGIN
			IF sym = begin THEN
				scope := bodyscope; codescope := scope;
				notifyScope := ~suppress;
				Body^(suppress);
				IF inspect THEN		(* body was inspected for hidden variables *)
					PCT.ChangeState(scope, PCT.hiddenvarsdeclared, scanner.errpos)
				ELSE				(* normal code generation *)
					PCT.ChangeState(scope, PCT.complete, scanner.errpos)
				END;
				scope := old; codescope := scope
			ELSE
				IF (sym = var) OR (sym = const) OR (sym = type) THEN
					PCM.Error(43, scanner.errpos, "data decl after proc decl")
				ELSIF (sym # end) THEN
					Error(43, scanner.errpos)
				ELSE
					scanner.Get(sym)
				END
			END
		END Body;

		PROCEDURE DeclSeq;	(* vars and procs are allowed, no const and types *)
		VAR res: LONGINT;
		BEGIN
			LOOP
				(* allow ident w/o var, to minimize the misleading err 83 in the rest of the module *)
				IF (sym = var) OR (sym = ident) THEN
					IF sym = var THEN scanner.Get(sym) ELSE PCM.Error(end, scanner.errpos, "or maybe VAR") END;
					WHILE sym = ident DO
						VarDecl;
						IF sym # end THEN
							CheckSemicolons;
						END;
					END
				ELSIF sym = semicolon THEN
					CheckSemicolons; (* advances to next symbol *)
				ELSE EXIT
				END
			END;
			FixForwards;
			PCT.ChangeState(scope, PCT.structdeclared, scanner.errpos);
			PCT.ChangeState(scope, PCT.structallocated, scanner.errpos);
			WHILE sym = procedure DO
				scanner.Get(sym); ProcDecl;
				IF sym # end THEN Check(semicolon) END
			END;
			IF sym = begin THEN
				old := scope;
				NEW(bodyscope); PCT.InitScope(bodyscope, scope, {PCT.AutodeclareSelf}, FALSE); PCT.SetOwner(bodyscope);
				scope.CreateProc(PCT.BodyName, PCT.Public, {}, bodyscope, PCT.NoType, scanner.errpos(*fof*), res); ASSERT(res = PCT.Ok);
				PCT.ChangeState(scope, PCT.procdeclared, scanner.errpos);    (* ug: must be done explicitly here in order to allow cross method calls of objects *)
				PCT.ChangeState(bodyscope, PCT.procdeclared, scanner.errpos);
				savedsym := sym;
				savedscanner := scanner;
				scanner := PCS.ForkScanner(scanner);
				inspect := TRUE;
				Body(TRUE);  (* suppress = TRUE *)
				scanner := savedscanner;
				sym := savedsym;
				inspect := FALSE
			END
		END DeclSeq;

		PROCEDURE & InitRec*(sync: Barrier; recscope: PCT.RecScope; s: PCS.Scanner; sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			isRecord := TRUE;
			scope := recscope; codescope := recscope; SELF.sym := sym; scopelevel := 0; looplevel := 0;
			scanner := PCS.ForkScanner(s);
		END InitRec;
	END ObjectParser;


	RecordParser = OBJECT (Parser)

		PROCEDURE Body(suppress: BOOLEAN);
		BEGIN
			Check(end)
		END Body;

		PROCEDURE DeclSeq;	(* the DeclSeq of a record is a simplified DeclSeq, but nevertheless different *)
		BEGIN
			LOOP
				IF sym = semicolon THEN
					CheckSemicolons; (* advances to next symbol *)
				ELSIF sym = ident THEN VarDecl;
				ELSE EXIT
				END
			END;
			FixForwards;	(*anonymous declaration possible!*)
			PCT.ChangeState(scope, PCT.procdeclared, scanner.errpos);
			PCT.ChangeState(scope, PCT.hiddenvarsdeclared, scanner.errpos)
		END DeclSeq;

		PROCEDURE & InitRec*(sync: Barrier; recscope: PCT.RecScope; s: PCS.Scanner; sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			isRecord := TRUE;
			scope := recscope; codescope := recscope; SELF.sym := sym; scopelevel := 0; looplevel := 0;
			scanner := PCS.ForkScanner(s);
		END InitRec;
	END RecordParser;

	InterfaceParser = OBJECT (Parser)

		PROCEDURE Body(suppress: BOOLEAN);
		BEGIN
			Check(end)
		END Body;

		PROCEDURE DeclSeq;
			VAR name: PCS.Name; procscope: PCT.ProcScope;  t: PCT.Struct; pos, res: LONGINT;
		BEGIN
			WHILE sym = procedure DO
				pos := scanner.errpos;
				scanner.Get(sym);
				name := scanner.name;
				Check(ident);
				NEW(procscope); PCT.InitScope(procscope, scope, {PCT.AutodeclareSelf}, FALSE); PCT.SetOwner(procscope);
				FormalPars (procscope, t, {});
				scope.CreateProc(name, PCT.Public, {}, procscope, t, pos(*fof*), res);
				IF res # PCT.Ok THEN PCM.ErrorN(res, pos, name) END;
				Check(semicolon);
				PCT.ChangeState(procscope, PCT.structdeclared, scanner.errpos)
			END;
			PCT.ChangeState(scope, PCT.procdeclared, scanner.errpos)
		END DeclSeq;

		PROCEDURE & InitRec*(sync: Barrier; recscope: PCT.RecScope; s: PCS.Scanner; sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			isRecord := TRUE;
			scope := recscope; codescope := recscope; SELF.sym := sym; scopelevel := 0; looplevel := 0;
			scanner := PCS.ForkScanner(s);
		END InitRec;
	END InterfaceParser;


	(* Parse a procedure, beginning from the parameters to the END. This only fills the scope,
	the symbol has to be inserted by the caller *)
	ProcedureParser =  OBJECT (Parser)

		PROCEDURE & InitProc*(sync: Barrier; procscope: PCT.ProcScope; inline: BOOLEAN;  VAR s: PCS.Scanner;  sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			SELF.inline := inline;
			scope := procscope; codescope := procscope; scanner := s; SELF.sym := sym;
			scopelevel := procscope.ownerO.level; looplevel := 0;
			scanner := PCS.ForkScanner(s)
		END InitProc;

	END ProcedureParser;


	(* Parse the condition in an AWAIT statement as a separate procedure *)
	AwaitParser = OBJECT(Parser)

		PROCEDURE DeclSeq;
		BEGIN
			PCT.ChangeState(scope, PCT.hiddenvarsdeclared, scanner.errpos)
		END DeclSeq;

		PROCEDURE Body(suppress: BOOLEAN);
		VAR x: PCB.Expression;
		BEGIN
			code := PCB.Enter(scope);
			Expr(x);
			PCB.Return(code, suppress, codescope, scanner.errpos, x, FALSE, 0);		(*use the declaration scope!*)
			PCB.Leave(code, scope, FALSE);
		END Body;

		PROCEDURE &Init*(sync: Barrier; procscope: PCT.ProcScope; VAR s: PCS.Scanner; sym: PCS.Token);
		BEGIN
			sync.Enter; SELF.sync := sync;
			scope := procscope; codescope := procscope; scanner := s; SELF.sym := sym;
			scopelevel := procscope.ownerO.level; looplevel := 0;
			scanner := PCS.ForkScanner(s)
		END Init;

	END AwaitParser;


	ModuleParser = OBJECT (Parser)
		VAR modscope: PCT.ModScope;	(*cached value*)

		PROCEDURE ImportList;
			VAR alias, name: StringPool.Index; new: PCT.Module; res: LONGINT;
		BEGIN
			LOOP
				IF sym # ident THEN Error(ident, scanner.errpos); EXIT END;
				alias := scanner.name;
				scanner.Get(sym);
				IF sym = becomes THEN
					scanner.Get(sym);
					IF sym = ident THEN
						name := scanner.name;
					ELSIF sym = string THEN
						name := StringPool.GetIndex1(scanner.str)	(*scanner.str is read-only and GetIndex has a VAR....*)
					ELSE
						Error(ident, scanner.errpos); EXIT
					END;
					scanner.Get(sym)
				ELSE
					name := alias;
				END;
				IF name # PCT.System.name THEN
					IF sym = in THEN
						scanner.Get(sym);
						CreateContext (name, scanner.name);
						Check (ident);
					ELSE
						CreateContext (name, modscope.owner.context);
					END;
				END;
				PCT.Import(modscope.owner, new, name);
				IF new = NIL THEN
					PCM.ErrorN(152, scanner.errpos, name)
				ELSE
					IF new # PCT.System THEN
						modscope.owner.AddDirectImp(new);
					END;
					modscope.AddModule(alias, new, scanner.errpos, (* fof *) res);	(*must create copy, otherwise list fields get overwritten*)
					IF res # PCT.Ok THEN PCM.ErrorN(res, scanner.errpos, alias) END
				END;
				IF sym = comma THEN scanner.Get(sym)
				ELSE EXIT
				END
			END;
			Check(semicolon)
		END ImportList;

		PROCEDURE ParseInterface;
		VAR  mod: PCT.Module; sf, flags: SET; name, label, context: PCS.Name;
		BEGIN
			IF sym = module THEN scanner.Get(sym);
				IF sym = ident THEN
					name := scanner.name; label := name;
					scanner.Get(sym);
					IF sym = in THEN
						scanner.Get(sym);
						context := scanner.name;
						IF (scanner.str # "Oberon") & (scanner.str # "A2") THEN
							PCM.Error (133, scanner.errpos, scanner.str)
						END;
						Check (ident);
					ELSE
						StringPool.GetIndex (Modules.DefaultContext, context);
					END;
					CreateContext (name, context);
					TypeModifier(sf, {}, {PCT.Overloading});
					PCT.InitScope(scope, NIL, sf, FALSE);
					mod := PCT.NewModule(name, FALSE, flags, modscope);
					mod.context := context; mod.label := label;
					Check(semicolon);
					IF sym = import THEN scanner.Get(sym);  ImportList END
				ELSE Error(ident, scanner.errpos)
				END
			ELSE Error(16, scanner.errpos)
			END;
			die := PCM.error
		END ParseInterface;

		PROCEDURE Await*;
		VAR count, inside: LONGINT;
		BEGIN
			sync.Await;
			sync.Stats(count, inside);
			IF inside > 0 THEN
				PCM.LogWStr(" ("); PCM.LogWNum(inside); PCM.LogW("/"); PCM.LogWNum(count); PCM.LogWStr(")")
			END;
			PCM.error := PCM.error OR (inside > 0)
		END Await;

		PROCEDURE & InitModule*(modscope: PCT.ModScope; s: PCS.Scanner);
			VAR recscope: PCT.RecScope; rec: PCT.Record; res: LONGINT;i, j: LONGINT;   (** fof  *)
		BEGIN
			Machine.AtomicInc(NModules);
			NEW(sync, 10(*timeout*)); sync.Enter;
			scope := modscope;  codescope := modscope;  scanner := s;  s.Get(sym);  scopelevel := 0;  looplevel := 0;
			PCT.SetOwner(scope);
			SELF.modscope := modscope;
			PCArrays.InitScope( modscope );   (* fof *)
			(*predefined variables*)
			scope.CreateVar(PCT.SelfName, PCT.Internal, {PCM.Untraced}, PCT.Ptr, 0, (*fof*) NIL, res);	(*module self, used for module locking*)
			ASSERT(res = PCT.Ok);
			ParseInterface;
			IF ~die THEN
				(*predefined types*)
				NEW(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE); PCT.SetOwner(recscope);
				rec := PCT.NewRecord(PCT.NoType, recscope, {PCT.SystemType}, FALSE, res); ASSERT(res = PCT.Ok);
				scope.CreateType(deltype, PCT.Internal, rec, 0 (*fof*), res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(procfld, PCT.Internal, {}, PCT.Int32, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(self, PCT.Internal, {}, PCT.Ptr, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				PCT.ChangeState(recscope, PCT.complete, scanner.errpos);
				PCC.delegate := rec;

				NEW(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE); PCT.SetOwner(recscope);
				rec := PCT.NewRecord(PCT.NoType, recscope, {PCT.SystemType}, FALSE, res); ASSERT(res = PCT.Ok);
				scope.CreateType(hiddenptr, PCT.Internal, rec, 0 (*fof*), res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(ptrfld, PCT.Internal, {}, PCT.Ptr, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				PCT.ChangeState(recscope, PCT.complete, scanner.errpos);
				PCC.hdptr := rec;
				(** fof >> *)
				(* keyword "RANGE" support
				NEW(recscope); PCT.InitScope(recscope, scope, {PCT.SuperclassAvailable}, FALSE); PCT.SetOwner(recscope);
				rec := PCT.NewRecord(PCT.NoType, recscope, {PCT.SystemType}, FALSE, res); ASSERT(res = PCT.Ok);
				scope.CreateType(StringPool.GetIndex1("RANGE"), PCT.Internal, rec, 0 (*fof*), res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(PCT.Anonymous, PCT.Internal, {}, PCT.Int32, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(PCT.Anonymous, PCT.Internal, {}, PCT.Int32, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(PCT.Anonymous, PCT.Internal, {}, PCT.Int32, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				recscope.CreateVar(PCT.Anonymous, PCT.Internal, {}, PCT.Set, 0 (*fof*) , NIL, res); ASSERT(res = PCT.Ok);
				PCT.ChangeState(recscope, PCT.complete, scanner.errpos);
				PCC.range := rec;
				*)

				FOR i := 0 TO LEN( PCC.anyarr ) - 1 DO
					NEW( recscope );  PCT.InitScope( recscope, scope, {PCT.SuperclassAvailable}, FALSE );  PCT.SetOwner( recscope );  rec := PCT.NewRecord( PCT.NoType, recscope, {PCT.SystemType}, FALSE , res );
					ASSERT( res = PCT.Ok );
					(*scope.CreateType(hiddenptr, PCT.Internal, rec, 0 (*fof*) ,res); ASSERT(res = PCT.Ok);*)
					recscope.CreateVar( ptrfld, PCT.Internal, {}, PCT.Ptr, 0 (*fof*) , NIL, res );
					FOR j := 1 TO 3 + 2 * i DO recscope.CreateVar( PCT.Anonymous, PCT.Internal, {}, PCT.Int32, 0 (*fof*) , NIL, res );  ASSERT( res = PCT.Ok );  END;
					PCT.ChangeState( recscope, PCT.complete, scanner.errpos );  PCC.anyarr[i] := rec;
				END;
				(** << fof  *)
				PCC.topscope := modscope;
			END
		END InitModule;

		(** fof >> *)
		PROCEDURE Epilog;
		VAR res: LONGINT;  sym: PCT.Symbol;  var: PCT.Variable;
		BEGIN
			(* check if the array module has been used in PCArrays. If so then put it into the scope to protect from unloading *)
			IF PCArrays.ArrayModule # NIL THEN  (* must be done here by this process *)
				IF modscope.owner.name = PCArrays.ArrayModuleIdx THEN HALT( 100 ) END;
				modscope.AddModule( PCArrays.ArrayModuleIdx, PCArrays.ArrayModule, 0, res );
				modscope.owner.AddDirectImp( PCArrays.ArrayModule );   (*  makes the use of ArrayBase visible, may be omitted *)
			END;

			Epilog^;
		END Epilog;
	(** << fof  *)

	END ModuleParser;


	(** fof 070731 >> *)
	PROCEDURE InitializationWarning( s: PCT.Symbol );
	VAR par: PCT.Parameter;  name: ARRAY 256 OF CHAR;
	BEGIN
		(*
		IF s # NIL THEN
			StringPool.GetString( s.name, name );
			PCM.LogWStr(name); PCM.LogWLn;
		END;
			*)

		IF (s = NIL) OR (s.pos = 0)  THEN RETURN
		ELSIF s IS PCT.Parameter THEN
			par := s( PCT.Parameter );
			IF ~(PCT.written IN par.flags) THEN
				IF ((par.type IS PCT.Array)
					(*
					OR
					 (par.type IS PCT.Record)
					 *)
					 ) &
					~(PCM.ReadOnly IN par.flags)  THEN
					StringPool.GetString( s.name, name );
					PCM.Warning( 917, par.pos, name );
					PCT.RemoveWarning( par );
				(*
				ELSIF ~(PCM.ReadOnly IN par.flags) & par.ref THEN PCM.Warning( 901, par.pos, "VAR parameter not initialized" );
				 too verbose
				*)
				END;
			END;
		ELSIF s IS PCT.LocalVar THEN
			IF ~(PCT.written IN s.flags) & ({PCT.PublicW} * s.vis = {})  THEN
				StringPool.GetString( s.name, name );
				PCM.Warning( 901, s.pos, name );
				PCT.RemoveWarning(s);
			END;
		ELSIF s IS PCT.GlobalVar  THEN
			IF ~(PCT.written IN s.flags) & ({PCT.PublicW} * s.vis = {}) THEN
				StringPool.GetString( s.name, name );
				PCM.Warning(901,s.pos,name);
				PCT.RemoveWarning(s);
			END;
		END;
	END InitializationWarning;

	PROCEDURE UsageWarning( s: PCT.Symbol );
	VAR name: ARRAY 256 OF CHAR;
	BEGIN
		IF (s = NIL) OR (s.pos = 0) OR (s IS PCT.Parameter)  (* too verbose *) THEN RETURN END;
		IF ~(PCT.used IN s.flags)  &
			(PCT.Public * s.vis = {}) THEN
			StringPool.GetString( s.name, name );
			PCM.Warning( 900, s.pos, name );
			PCT.RemoveWarning( s );
		END;
	END UsageWarning;

	(* Generates a warning if a field has the same name as an inherited field *)
	PROCEDURE SameNameWarning(s : PCT.Symbol);
	VAR
		record : PCT.Record; warned : BOOLEAN;
		name : ARRAY 128 OF CHAR;

		PROCEDURE HasVar(scope : PCT.Scope; var : PCT.Variable) : BOOLEAN;
		VAR v : PCT.Variable;
		BEGIN
			ASSERT((scope # NIL) & (var # NIL));
			v := scope.firstVar;
			LOOP
				IF (v = NIL) OR (v.name = var.name) THEN EXIT; END;
				v := v.nextVar;
			END;
			RETURN v # NIL;
		END HasVar;

	BEGIN
		IF (s = NIL) OR (s.pos = 0) THEN RETURN END;
		IF (s IS PCT.Variable) & (s.inScope # NIL) & (s.inScope IS PCT.RecScope) & (s.inScope(PCT.RecScope).owner # NIL) THEN
			warned := FALSE;
			record := s.inScope(PCT.RecScope).owner.brec;
			WHILE (record # NIL) & (record.scope # NIL)  & (~warned) DO
				IF HasVar(record.scope, s(PCT.Variable)) THEN
					warned := TRUE;
					StringPool.GetString(s.name, name);
					PCM.Warning(914, s.pos, name);
					PCT.RemoveWarning( s );
				END;
				record := record.brec;
			END;
		END;
	END SameNameWarning;

	(* Generates a warning if a symbol is exported but the scope containing it is not *)
	PROCEDURE UselessExportWarning(s : PCT.Symbol);
	VAR recScope : PCT.RecScope; name : ARRAY 128 OF CHAR;
	BEGIN
		IF (s = NIL) OR (s.pos = 0) OR (s.vis * PCT.Public = {}) THEN RETURN; END;
		IF (s.inScope # NIL) THEN
			IF (s.inScope IS PCT.RecScope) THEN
				recScope := s.inScope (PCT.RecScope);
				IF recScope.owner # NIL THEN
					IF ((recScope.owner.owner # NIL) & (recScope.owner.owner.vis * PCT.Public = {})) (* RECORD *)
						OR
						((recScope.owner.ptr # NIL) & (recScope.owner.ptr.owner # NIL) &
						 (recScope.owner.ptr.owner.vis * PCT.Public = {}))  (* POINTER TO RECORD or OBJECT *)
					THEN
						IF (s IS PCT.Method) &
							 ((s(PCT.Method).boundTo.scope(PCT.RecScope).initproc = s) OR
							 	((s(PCT.Method).boundTo.scope(PCT.RecScope).body = s))) THEN
							(* Constructors and bodies are always public *)
							RETURN;
						END;
						IF (s IS PCT.Method) &
							((s(PCT.Method).super = NIL) OR (s(PCT.Method).super.vis * PCT.Public = {}))  THEN
							(* not autoexported *)
							StringPool.GetString(s.name, name);
							PCM.Warning(915, s.pos, name);
							PCT.RemoveWarning(s);
						END;
					END;
				END;
			ELSIF (s IS PCT.Proc) & (s.inScope IS PCT.ProcScope) THEN
				StringPool.GetString(s.name, name);
				PCM.Warning(915, s.pos, name);
				PCT.RemoveWarning(s);
			END;
		END;
	END UselessExportWarning;

	PROCEDURE ScopeWarnings(scope: PCT.Scope);
	VAR s: PCT.Symbol;
	BEGIN
		s := scope.sorted;
		WHILE (s # NIL ) DO
			UsageWarning( s );  InitializationWarning( s );
			SameNameWarning( s );  (* sven stauber *)
			UselessExportWarning( s );
			s := s.sorted;
		END;
	END ScopeWarnings;

	PROCEDURE ImportListWarnings( mod: PCT.Module );
	VAR i: LONGINT;
	BEGIN
		IF mod.sysImported & (PCT.System.flags * {PCT.used} = {}) THEN
			PCM.Warning( 900, PCT.System.pos, "SYSTEM");
		END;
		IF mod.directImps = NIL THEN RETURN END;
		FOR i := 0 TO LEN( mod.directImps ) - 1 DO
			UsageWarning( mod.directImps[i] );
		END;
	END ImportListWarnings;
(** << fof  *)



	PROCEDURE ParseModule*(scope: PCT.ModScope; s: PCS.Scanner);
		VAR parser: ModuleParser; name: StringPool.Index; sym: PCS.Token;
	BEGIN
		(* 	There's one global symbol representing the SYSTEM pseudo module. Clear the used flag before parsing the module
			so we can detect whether SYSTEM is used after parsing *)
		EXCL(PCT.System.flags, PCT.used);

		(* note: can use s directly instead of parser.scanner, because the module parser uses the same scanner *)
		NEW(parser, scope, s);
		parser.Await;

		IF ~parser.die THEN
			IF (PCM.Warnings IN PCM.parserOptions) THEN
				PCT.TraverseScopes(parser.modscope,ScopeWarnings); (*fof*)
				ImportListWarnings( parser.modscope.module );  (*fof*)
			END;

			name := scope.owner(PCT.Module).label;
			IF parser.sym = ident THEN
				IF s.name # name THEN PCM.ErrorN(4, s.errpos, s.name) END;
				s.Get(sym);
				IF sym = period THEN (* s.Get(sym) *)  ELSE PCM.Error(period, s.errpos, "") END;
			ELSE PCM.ErrorN(ident, s.errpos, name)
			END
		END
	END ParseModule;


	PROCEDURE CreateString(VAR idx: StringPool.Index;  str: ARRAY OF CHAR);	(*to insert string constants*)
	BEGIN  StringPool.GetIndex(str, idx)
	END CreateString;

	PROCEDURE CreateContext (VAR name: StringPool.Index; context: StringPool.Index);
	VAR string, temp: ARRAY 64 OF CHAR;
	BEGIN
		StringPool.GetString (context, string);
		IF string # Modules.DefaultContext THEN
			Strings.Append (string, "-");
			StringPool.GetString (name, temp);
			Strings.Append (string, temp);
			StringPool.GetIndex (string, name);
		END;
	END CreateContext;

BEGIN
	CreateString(untraced, "UNTRACED");
	CreateString(delegate, "DELEGATE");
	CreateString(overloading, "OVERLOADING");
	CreateString(self, "SELF");
	CreateString(exclusive, "EXCLUSIVE");
	CreateString(active, "ACTIVE");
	CreateString(safe, "SAFE");
	CreateString(priority, "PRIORITY");
	CreateString(realtime, "REALTIME");
	CreateString(deltype, "@Delegate");
	CreateString(hiddenptr, "@HdPtrDesc");
	CreateString(procfld, "proc");
	CreateString(ptrfld, "ptr");
	CreateString(winapi, "WINAPI"); (* ejz *)
	CreateString( clang, "C" );   (* fof for Linux Version *)
	CreateString(notag, "NOTAG"); (* sz *)
	noname := -1
END PCP.

(*
	08.08.07	sst	Added SameNameWarning, UselessExportWarning & AWAIT not in exclusive block warning
	24.06.03	prk	Check that name after END is the same as declared after MODULE
	21.07.02	prk	EXIT in an exclusive block must release lock
	05.02.02	prk	PCT.Find cleanup
	11.12.01	prk	problem parsing invalid WITH syntax fixed
	22.11.01	prk	improved flag handling
	19.11.01	prk	definitions
	17.11.01	prk	more flexible type handling of integer constants
	16.11.01	prk	constant folding of reals done with maximal precision
	16.11.01	prk	improved error message when operators and Oberon-2 WITH found
	01.11.01	prk	improved error handling for OBJECT without VAR
	14.09.01	prk	PRIORITY modifier, error messages improved
	29.08.01	prk	PCT functions: return "res" instead of taking "pos"
	27.08.01	prk	PCT.Insert removed, use Create procedures instead
	27.08.01	prk	scope.unsorted list removed; use var, proc, const and type lists instead
	17.08.01	prk	overloading
	09.08.01	prk	Symbol Table Loader Plugin
	11.07.01	prk	support for fields and methods with same name in scope
	06.07.01	prk	mark object explicitly
	05.07.01	prk	import interface redesigned
	04.07.01	prk	SkipScope, seek for END in CODE bodies, ignore other keywords
	04.07.01	prk	scope flags added, remove imported
	02.07.01	prk	access flags, new design
	27.06.01	prk	StringPool cleaned up
	27.06.01	prk	ProcScope.CreatePar added
	21.06.01	prk	using stringpool index instead of array of char
	15.06.01	prk	support for duplicate scope entries
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	12.06.01	prk	Interfaces
	30.05.01	prk	destination (\d) compiler-option to install the back-end
	17.05.01	prk	Delegates
	10.05.01	prk	remove temporary for-counter when EXIT inside a for-loop
	08.05.01	prk	PCT interface cleanup. Use InitX instead of New*, allows type extension
	26.04.01	prk	separation of RECORD and OBJECT in the parser
	29.03.01	prk	Java imports
*)