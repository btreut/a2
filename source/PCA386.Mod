(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)


MODULE PCA386; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: i80386 assembler parser and code generator"; *)

	IMPORT
		SYSTEM, Files, StringPool, PCM, PCLIR, PCT, PCS, PCBT, PCP;

(**
	Productions:
	AsmCode = [BlockMode] {AsmLines} END.
	AsmLine = [Label ":"] [Instruction | Definition] CR.
	Instruction = .....
	Definition = (DB | DW | DD) value {"," value}.
*)

	CONST
		FileName = "OPA.Data";

		none = -1;

		(*processor targets*)
		i386 = 0;  i486 = 1;  Pentium = 2;  PentiumPro = 3;
		FPU = 16;  Privileged = 17; MMX = 18; SSE = 19; SSE2 = 20; SSE3=21; SSE4=22;

		(* Own Symbol Table types *)
		StLabel = 0; StFwdLabel = 1;
		StConst = 3; StType = 4; StVar = 5; StVarPar = 6; StGlobal = 7;
		StMod = 11;

		(* Own Addressing modes, also used in the St and Sc *)

		Reg8 = 08H; Reg16 = 10H; Reg32 = 20H;		(* register modes *)
		MReg = 28H;	(* MMX Register *)
		XReg = 29H;	(* XMM Register *)

		RegAL = 09H; RegAX = 11H; RegEAX = 21H;		(* special cases with fixed register *)
		RegDX = 12H; RegCL = 13H;

		Imm8 = 30H;	(* 8bit immediate *)
		Imm16 = 31H;	(* 16bit immediate *)
		Imm32 = 32H;	(* 32bit immediate *)
		SImm8 = 35H;	(* 8bit signed immediate *)
		Imm = 36H;	(* any immediate *)

		Const1 = 33H;								(* special case for rotate/shift *)
		Const3 = 34H;								(* special case for INT 3 *)

			(* register / memory modes *)
		RM = 40H; RM8 = 41H; RM16 = 42H; RM32 = 43H;

		MM = 44H;	(* mm/mm32 or mm/mm64 *)
		MM32 = 45H; MM64 = 46H;

		XMM = 0A0H;	(* xmm/m32 or xmm/m64 or xmm/m128 *)
		XMM32 = 0A1H;	(* xmm/m32 *)
		XMM64 = 0A2H;	(* xmm/m64 *)
		XMM128 = 0A3H;	(* xmm/m128 *)

			(* memory mode *)
		M = 48H; M8 = 49H; M16 = 4AH; M32 = 4BH; M64 = 4CH; M80 = 4DH; M128 = 4EH;
		(*M2 = 4EH;*)

		SReg = 50H;	(* Segment Register *)
		RegCS = 51H; RegDS = 52H; RegES = 53H; RegFS = 54H;
		RegGS = 55H; RegSS = 56H;

			(* Relative modes *)
		Rel8 = 60H; Rel16 = 61H; Rel32 = 62H; FwdJmp = 63H;

			(* Special registers *)
		CRReg = 70H; DRReg = 71H; TRReg = 72H;
		FReg = 80H; FRegST = 81H;

		(* Scanner: ASCII codes *)
		TAB = 09X;
		LF = 0AX;
		CR = 0DX;
		SPACE = 20X;
		(* Scanner: Sym values *)
		ScUndef = 0;
		ScIdent = 1;
		ScSemicolon = 2;	(* ; *)
		ScAt = 3;	(* @ *)
		ScNumber = 4;
		ScComma = 5; 	(* , *)
		ScLBrak = 6;	(* [ *)
		ScRBrak = 7;	(* ] *)
		ScCR = 8;
		ScMult = 9;	(* * *)
		ScEnd = 10;
		ScLabel = 11;
		ScColon = 12;	(* : *)
		ScPlus = 13;
		ScMinus = 14;
		ScDiv = 15;
		ScLPar = 16;
		ScRPar = 17;
		ScString = 18;
		ScPoint = 19;
		ScLBrace = 20;
		ScRBrace = 21;

		(* Structure sizes *)
		NameLen = 32;
		MaxStrLen = 256;
		MnemoLen = 12;

		(* Opcodes modifiers *)
		OmReg = 1;		(* register stored in the RM byte as reg/opcode *)
		OmOp = 2;		(* register added to the opcode *)
		OmRMReg = 3;		(* register stored in the RM byte as r/m and reg/opcode*)
		OmRM = 4;		(* register stored in the RM byte *)

		(* Match evaluation *)
		NoMatch = 0; SizeCast = 1; TypeCast = 2; ConstCast = 3; Hit = 4;

	TYPE
		Name = ARRAY 32 OF CHAR;
		Mnemo = ARRAY MnemoLen OF CHAR;

		(*Symbol: The symbol table. It's an ordered binary tree. First element is root.right *)
		Symbol = POINTER TO SymDesc;
		FixPnt = POINTER TO FixPntDesc;

		InstrDesc = RECORD
					name: Mnemo;
					start, end: INTEGER;	 (* index in the opcode-tab *)
					target: SET;
				END;

		(* Opcode: this structure contains the definition of an opcode, with the
			expected dst/src operands and the information needed to encode it.
			Ex:
				if opc # -1 => modr/m . opc = opc. ( extension of the opcode )
		*)
		OpCode = RECORD
				op: ARRAY 3 OF INTEGER;		(* mode of the dst/src operands, if needed *)
				op0, op1, op2: INTEGER;	   (* opcode *)
				opc: INTEGER;			(* value stored in reg/opcode of modr/m. -1 = none *)
				reg: INTEGER;			(* where is the register stored: none / rm /op *)
			END;

		Operand = RECORD
					mode: LONGINT;		(* the mode: Reg8.... *)
					imm: LONGINT;		(* the constant *)
					disp: LONGINT;
					index, base, reg: INTEGER;
					seg, scale: INTEGER;	(* segment override *)
					obj: Symbol;			(* the jmp label for forward jumps / the object referenced *)
				END;

		SymDesc = RECORD
							typ: LONGINT;
							val, size:  LONGINT;		(* if typ <0 => pos of first use of this label *)
							name: Name;
							left, right, next: Symbol;
							fix: FixPnt;
							obj: PCT.Symbol
					 END;

		FixPntDesc = RECORD
						pc: LONGINT;
						next: FixPnt;
					END;

VAR
	(* Global structures *)
		OpTab: POINTER TO ARRAY OF OpCode;	(* Table with the opcodes *)
		OpTabLen: LONGINT;		(* nof opcodes in the table *)
		InstrTab: POINTER TO ARRAY OF InstrDesc;	(* Table with the instructions !!Hash *)
		InstrTabLen: LONGINT;
		SizeTab: ARRAY 17 OF SHORTINT;		(* size of the oberon types *)
		TargetTab: ARRAY 32 OF RECORD  name: Name;  flag: SET  END;
		TargetCount: LONGINT;

		loaded: BOOLEAN;		(*is the table loaded? Load only at first use*)

(* ------------------------------------------------------------------- *)
(* Special functions *)

	PROCEDURE AND(a,b: LONGINT):LONGINT;
	BEGIN RETURN(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,a) * SYSTEM.VAL(SET,b)))
	END AND;

	PROCEDURE IsFix(name: Mnemo): BOOLEAN;
	BEGIN
		RETURN (
			(name = "MOVLHPS") OR
			(name = "MOVHLPS") OR
			(name = "MASKMOVDQU") OR
			(name = "MASKMOVQ") OR
			(name = "MASKMOVDQU") OR
			(name = "MOVMSKPS") OR
			(name = "PEXTRW") OR
			(name = "PMOVMSKB") OR
			(name = "MOVQ2DQ")
		);
	END IsFix;

(* ------------------------------------------------------------------- *)
(* Addressing Mode functions *)

	PROCEDURE ModeSize(mode: LONGINT): LONGINT;
	BEGIN
		CASE mode OF
		  Imm8, Const1, Const3, Rel8, RegAL, RegCL, Reg8, RM8, M8, SImm8:
				RETURN(1)
		| Imm16, Rel16, RegAX, RegDX, Reg16, RM16, M16, SReg, RegCS, RegDS, RegES, RegFS, RegGS, RegSS:
				RETURN(2)
		| Imm32, Rel32, FwdJmp, RegEAX, Reg32, RM32, M32, MM32, XMM32:
				RETURN(4)
		| M64, MReg, MM64, XMM64:
				RETURN(8)
		| M80:
				RETURN(10)
		| M128, XReg, XMM128:
				RETURN(16);
		| RM, MM, XMM:
				RETURN(0)
		ELSE RETURN(0)
		END
	END ModeSize;

	PROCEDURE ConstSize(i: LONGINT; signed: BOOLEAN):INTEGER;
	BEGIN
		IF (MIN(SHORTINT) <= i) & (MAX(SHORTINT) >= i) OR (~signed & (AND(i,LONGINT(0FFFFFF00H))=0)) THEN
			RETURN(1)
		ELSIF (MIN(INTEGER) <= i) & (MAX(INTEGER) >= i) OR (~signed & (AND(i,LONGINT(0FFFF0000H))=0))THEN
			RETURN(2)
		ELSE
			RETURN(4)
		END
	END ConstSize;

	PROCEDURE IsRegMode(m: LONGINT; strict: BOOLEAN):BOOLEAN;
	BEGIN
		RETURN((m=Reg8)OR(m=Reg16)OR(m=Reg32)OR
			(~strict &((m=RegAL)OR(m=RegAX)OR(m=RegEAX)OR(m=RegDX))))
	END IsRegMode;

	PROCEDURE IsSRegMode(m: LONGINT; strict: BOOLEAN):BOOLEAN;
	BEGIN
		RETURN((m=SReg)OR (~strict &(m=RegCS)OR(m=RegDS)OR(m=RegES)OR
			(m=RegFS)OR(m=RegGS)OR(m=RegSS)))
	END IsSRegMode;

	PROCEDURE IsSpecRegMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN((m=CRReg)OR(m=DRReg)OR(m=TRReg))
	END IsSpecRegMode;

	PROCEDURE IsMMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN((m=M)OR(m=M8)OR(m=M16)OR(m=M32)OR(m=M64)OR(m=M80)OR(m = M128))
	END IsMMode;

	PROCEDURE IsRMMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN((m=RM)OR(m=RM8)OR(m=RM16)OR(m=RM32) (*OR IsMMode(m)*))
	END IsRMMode;

	PROCEDURE IsMMMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN(m=MM)OR(m=MM32)OR(m=MM64)
	END IsMMMode;

	PROCEDURE IsXMMMode(m: LONGINT): BOOLEAN;
	BEGIN
		RETURN (m = XMM) OR (m = XMM32) OR (m = XMM64) OR (m = XMM128)
	END IsXMMMode;

	PROCEDURE IsFRegMode(m: LONGINT; strict: BOOLEAN):BOOLEAN;
	BEGIN
		RETURN((m=FReg) OR (~strict & (m=FRegST)))
	END IsFRegMode;

	PROCEDURE IsRegister(mode: LONGINT): BOOLEAN;
	BEGIN
		RETURN IsRegMode(mode,TRUE) OR IsSRegMode(mode, FALSE) OR IsSpecRegMode(mode) OR (mode = MReg) OR (mode = XReg)
	END IsRegister;

	PROCEDURE NeedModRM(mode, regpos: LONGINT): BOOLEAN;
	BEGIN
		RETURN(IsRMMode(mode) OR IsMMode(mode) OR IsMMMode(mode) OR IsXMMMode(mode) OR
						((regpos = OmReg) OR (regpos =  OmRM) OR (regpos =  OmRMReg)) & IsRegister(mode))
	END NeedModRM;

	PROCEDURE IsImmMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN((m=Imm8)OR(m=Imm16)OR(m=Imm32)OR(m=SImm8)OR(m=Imm))
	END IsImmMode;

	PROCEDURE IsRelMode(m: LONGINT):BOOLEAN;
	BEGIN
		RETURN((m=Rel8)OR(m=Rel16)OR(m=Rel32))
	END IsRelMode;
(*
	PROCEDURE Evaluate(VAR op: Operand; mode: LONGINT): LONGINT;
	BEGIN
		IF mode = op.mode THEN RETURN Hit	(* 80% of the checks, now the 20% special cases *)
		ELSIF IsModRmMode(mode) THEN
			IF IsMMode(op.mode) THEN
				IF ModeSize(op.mode)=ModeSize(mode) THEN RETURN Hit
				ELSIF (op.mode = RM) OR (op.mode = M) THEN RETURN SizeCast
				ELSE RETURN NoMatch END
			ELSIF IsRegMode(op.mode, FALSE) & (ModeSize(op.mode)=ModeSize(mode)) THEN RETURN TypeCast
			ELSE RETURN NoMatch END
		ELSIF IsRegMode(mode,TRUE) THEN	(* cannot be a specific reg (AL,AX,EAX) *)
			IF ModeSize(op.mode)=ModeSize(mode) THEN
				IF IsRegMode(op.mode,TRUE) THEN RETURN Hit
				ELSIF IsRegMode(op.mode, FALSE) THEN RETURN TypeCast
				ELSE RETURN NoMatch END
			ELSE RETURN NoMatch
			END
		ELSIF mode = RegDX THEN
			IF (op.mode = Reg16) & (op.reg = 2) THEN RETURN Hit ELSE RETURN NoMatch END	(* special case for IN/OUT which uses DX *)
		ELSIF mode = RegCL THEN
			IF (op.mode = Reg8) & (op.reg = 1) THEN RETURN Hit ELSE RETURN NoMatch END	(* special case for shift/rotate which uses CL *)
		ELSIF IsRegMode(mode, FALSE) THEN RETURN NoMatch
		ELSIF IsImmMode(mode) THEN
			IF op.mode = Imm THEN
				IF ModeSize(mode)  > ConstSize(op.imm, mode = SImm8) THEN RETURN ConstCast
				ELSIF ModeSize(mode)  = ConstSize(op.imm, mode = SImm8) THEN RETURN Hit
				ELSE RETURN NoMatch END
			ELSIF IsImmMode(op.mode) THEN
				IF ModeSize(mode)  > ModeSize(op.mode) THEN RETURN ConstCast
				ELSIF ModeSize(mode)  = ModeSize(op.mode) THEN RETURN Hit
				ELSE RETURN NoMatch END
			ELSE RETURN NoMatch END
		ELSIF mode = Const1 THEN
			IF IsImmMode(op.mode) & (op.imm = 1) THEN RETURN Hit ELSE RETURN NoMatch END
		ELSIF mode = Const3 THEN
			IF IsImmMode(op.mode) & (op.imm = 3) THEN RETURN Hit ELSE RETURN NoMatch END
		ELSIF IsMMode(mode) THEN
			IF IsMMode(op.mode) THEN
				IF ModeSize(op.mode)=ModeSize(mode) THEN RETURN Hit
				ELSIF (op.mode = M) OR (mode = M) THEN RETURN SizeCast
				ELSE RETURN NoMatch END
			ELSE RETURN NoMatch END
		ELSIF mode = SReg THEN
			IF IsSRegMode(op.mode,FALSE) THEN RETURN Hit ELSE RETURN NoMatch END
		ELSIF IsRelMode(mode) THEN
			IF (mode = Rel32) & (op.mode = FwdJmp) THEN RETURN Hit
			ELSIF IsImmMode(op.mode) THEN
				IF ModeSize(mode) = ConstSize(op.imm, TRUE) (*ModeSize(op.mode)*) THEN RETURN Hit
				ELSIF ModeSize(mode) > ConstSize(op.imm, TRUE) (*ModeSize(op.mode)*) THEN RETURN ConstCast
				ELSE RETURN NoMatch END
			ELSE RETURN NoMatch END
		ELSIF mode = FReg THEN
			IF IsFRegMode(op.mode, TRUE) THEN RETURN Hit
			ELSIF IsFRegMode(op.mode, FALSE) THEN RETURN TypeCast
			ELSE RETURN NoMatch END
		ELSE RETURN NoMatch
		END
	END Evaluate;
*)
	PROCEDURE Evaluate(VAR op: Operand; mode: LONGINT): LONGINT;
	BEGIN
		IF mode = op.mode THEN RETURN Hit	(* 80% of the checks, now the 20% special cases *)
		ELSIF IsRMMode(mode) THEN
			IF IsMMode(op.mode) THEN
				IF ModeSize(op.mode)=ModeSize(mode) THEN RETURN Hit
				ELSIF (op.mode = RM) OR (op.mode = M) THEN RETURN SizeCast
				END
			ELSIF IsRegMode(op.mode, FALSE) & (ModeSize(op.mode)=ModeSize(mode)) THEN RETURN TypeCast
			END
		ELSIF IsRegMode(mode,TRUE) THEN	(* cannot be a specific reg (AL,AX,EAX) *)
			IF ModeSize(op.mode)=ModeSize(mode) THEN
				IF IsRegMode(op.mode,TRUE) THEN RETURN Hit
				ELSIF IsRegMode(op.mode, FALSE) THEN RETURN TypeCast
				END
			END
		ELSIF mode = RegDX THEN
			IF (op.mode = Reg16) & (op.reg = 2) THEN RETURN Hit END	(* special case for IN/OUT which uses DX *)
		ELSIF mode = RegCL THEN
			IF (op.mode = Reg8) & (op.reg = 1) THEN RETURN Hit END	(* special case for shift/rotate which uses CL *)
		ELSIF IsRegMode(mode, FALSE) THEN RETURN NoMatch
		ELSIF IsImmMode(mode) THEN
			IF op.mode = Imm THEN
				IF ModeSize(mode)  > ConstSize(op.imm, mode = SImm8) THEN RETURN ConstCast
				ELSIF ModeSize(mode)  = ConstSize(op.imm, mode = SImm8) THEN RETURN Hit
				END
			ELSIF IsImmMode(op.mode) THEN
				IF ModeSize(mode)  > ModeSize(op.mode) THEN RETURN ConstCast
				ELSIF ModeSize(mode)  = ModeSize(op.mode) THEN RETURN Hit
				END
			END
		ELSIF mode = Const1 THEN
			IF IsImmMode(op.mode) & (op.imm = 1) THEN RETURN Hit END
		ELSIF mode = Const3 THEN
			IF IsImmMode(op.mode) & (op.imm = 3) THEN RETURN Hit END
		ELSIF IsMMode(mode) THEN
			IF IsMMode(op.mode) THEN
				IF ModeSize(op.mode)=ModeSize(mode) THEN RETURN Hit
				ELSIF (op.mode = M) OR (mode = M) THEN RETURN SizeCast
				END
			END
		ELSIF mode = SReg THEN
			IF IsSRegMode(op.mode,FALSE) THEN RETURN Hit END
		ELSIF IsRelMode(mode) THEN
			IF (mode = Rel32) & (op.mode = FwdJmp) THEN RETURN Hit
			ELSIF IsImmMode(op.mode) THEN
				IF ModeSize(mode) = ConstSize(op.imm, TRUE) (*ModeSize(op.mode)*) THEN RETURN Hit
				ELSIF ModeSize(mode) > ConstSize(op.imm, TRUE) (*ModeSize(op.mode)*) THEN RETURN ConstCast
				END
			END
		ELSIF mode = FReg THEN
			IF IsFRegMode(op.mode, TRUE) THEN RETURN Hit
			ELSIF IsFRegMode(op.mode, FALSE) THEN RETURN TypeCast
			END
		ELSIF mode = XMM32 THEN
			IF (op.mode = XReg) OR (op.mode = M32) THEN RETURN Hit
			ELSIF (op.mode = M) THEN RETURN TypeCast
			END
		ELSIF mode = XMM64 THEN
			IF (op.mode = XReg) OR (op.mode = M64) THEN RETURN Hit
			ELSIF (op.mode = M) THEN RETURN TypeCast
			END
		ELSIF mode = XMM128 THEN
			IF (op.mode = XReg) OR (op.mode = M128) THEN RETURN Hit
			ELSIF (op.mode = M) THEN RETURN TypeCast
			END
		ELSIF mode = MM64 THEN
			IF (op.mode = MReg) OR (op.mode = M64) THEN RETURN Hit
			ELSIF (op.mode = M) THEN RETURN TypeCast
			END
		ELSIF mode = MM32 THEN
			IF (op.mode = MReg) OR (op.mode = M32) THEN RETURN Hit
			ELSIF (op.mode = M) THEN RETURN TypeCast
			END
		END;
		RETURN NoMatch	(*fall through*)
	END Evaluate;

	PROCEDURE Match(ind: LONGINT; VAR op: ARRAY OF Operand;  errpos: LONGINT): LONGINT;
		VAR start, end, i, j, k, best: LONGINT;
	BEGIN
		start := InstrTab[ind].start; end := InstrTab[ind].end; ind := -1; best := 0;
		WHILE start < end DO
			i := Evaluate(op[0], OpTab[start].op[0]);
			IF (i = NoMatch) THEN
			ELSE
				j := Evaluate(op[1], OpTab[start].op[1]);
				IF j = NoMatch  THEN i := NoMatch
				ELSE
					k := Evaluate(op[2], OpTab[start].op[2]);
					IF (i < j) & (i < k) THEN
					ELSIF j < k THEN i :=  j
					ELSE i := k
					END
				END
			END;
			IF i # NoMatch THEN
				IF i = Hit THEN ind := start; RETURN ind
				ELSIF i > best THEN ind := start; best := i
				ELSIF (i = best) & (i = SizeCast) THEN PCM.Error(512, errpos, ""); ind := -1; RETURN ind
				END
			END;
			INC(start)
		END;
		IF ind = -1 THEN PCM.Error(501, errpos, "") END;
		RETURN ind
	END Match;

	(* Generates the hash index k for the n-th try. n>=0 *)
	PROCEDURE HashFn(VAR name: ARRAY OF CHAR; VAR k, n: LONGINT);
		VAR i: LONGINT;
	BEGIN
		IF n = 0 THEN
			i := 0; k := 0;
			WHILE name[i] # 0X DO
				k := (k*16 + ORD(name[i])) MOD InstrTabLen; INC(i)
			END;
			n := 1
		ELSE
			k := (k + n) MOD InstrTabLen; INC(n, 1)
		END
	END HashFn;

(* ------------------------------------------------------------------- *)

PROCEDURE Assemble*(scanner: PCS.Scanner;  scope: PCT.Scope;  exported, inlined: BOOLEAN): PCM.Attribute;
VAR
	(*context*)
	asminline: PCLIR.AsmInline;
	first, last: PCLIR.AsmBlock;
	root:  Symbol;	(* symbol table *)

	(*configuration*)
	Target: SET;						(* The target processor*)
	pc: LONGINT;	(* program counter. Should be used only for pc-rel jumps !! *)
	export, inline: BOOLEAN;		(* code is exported / inlined *)

	(* Scanner variables *)
	sym: LONGINT; 	(* last token read *)
	ident: Name;		(* last identifier read *)
	val: LONGINT;	  (* last value read *)
	str: ARRAY MaxStrLen OF CHAR;
	errpos: LONGINT;	(* starting position of the last instruction *)


	PROCEDURE err(n: LONGINT);
	BEGIN PCM.Error(n, errpos, "")
	END err;

	PROCEDURE FindInstruction(VAR name: ARRAY OF CHAR; VAR inx: LONGINT);
		VAR n: LONGINT;
	BEGIN
		n := 0;
		REPEAT
			HashFn(name, inx, n)
		UNTIL (name = InstrTab[inx].name) OR (InstrTab[inx].name[0] = 0X) OR (n >InstrTabLen);
		IF (InstrTab[inx].name[0] = 0X) OR (n >InstrTabLen) THEN inx := -1
		ELSIF (InstrTab[inx].target+Target # Target) THEN	PCM.Error(515, errpos, "")
		END
	END FindInstruction;

	PROCEDURE insert(VAR name: ARRAY OF CHAR; VAR obj: Symbol);
		VAR ob0, ob1: Symbol; d: LONGINT;
	BEGIN ob0 := root; ob1 := ob0.right; d := 1;
		LOOP
			IF ob1 = NIL THEN (*insert undefined label*)
				NEW(ob1); COPY(name, ob1.name); ob1.typ := StFwdLabel;
				ob1.left := NIL; ob1.right := NIL; ob1.fix := NIL; ob1.obj := NIL;
				ob1.next := root.next; root.next := ob1;
				ob1.val := errpos;
				IF d < 0 THEN ob0.left := ob1 ELSE ob0.right := ob1 END;
			ELSIF ob1.name > name THEN d := -1; ob0 := ob1; ob1 := ob1.left
			ELSIF ob1.name < name THEN d :=  1; ob0 := ob1; ob1 := ob1.right
			ELSE (*found, no insertion*) EXIT END
		END;
		obj := ob1
	END insert;

	PROCEDURE ConvertObj(ob: PCT.Symbol): Symbol;
	VAR obj: Symbol; con: PCT.Const;
	BEGIN
		IF ob # NIL THEN
			PCT.RemoveWarning (ob);
			NEW(obj);
			IF ob IS PCT.Variable THEN
				obj.size := ob.type.size(PCBT.Size).size;
				IF ob IS PCT.GlobalVar THEN
					obj.typ := StGlobal; obj.val := 1;
				ELSIF (ob IS PCT.Parameter) & (ob(PCT.Parameter).ref) THEN
					obj.val := ob.adr(PCBT.Variable).offset;
					obj.typ := StVarPar; obj.size := 4
				ELSE
					obj.val := ob.adr(PCBT.Variable).offset;
					obj.typ := StVar
				END
			ELSIF ob IS PCT.Value THEN
				con := ob(PCT.Value).const;
				obj.typ := StConst;
				IF ob.type = PCT.Char8 THEN
					obj.val := con.int
				ELSIF PCT.IsCardinalType(ob.type) THEN
					obj.val := con.int
				ELSE
					PCM.Error(51, errpos, "")
				END
			ELSIF ob IS PCT.Type THEN
				obj.typ := StType; obj.size := ob.type.size(PCBT.Size).size; PCM.Error(514, errpos, "")
			ELSIF ob IS PCT.Module THEN
				obj.typ := StMod
			ELSE
				obj.typ := StConst; obj.val := 0; PCM.Error(514, errpos, "")
			END;
			obj.obj := ob
		END;
		RETURN obj
	END ConvertObj;

	PROCEDURE find(name: Name; VAR obj: Symbol);
		VAR ob0: Symbol; ob : PCT.Symbol; idx: LONGINT;
	BEGIN ob0 := root.right;
		WHILE (ob0 # NIL) & (ob0.name # name) DO
			IF ob0.name > name THEN ob0 := ob0.left ELSE ob0 := ob0.right END
		END;
		obj := ob0;
		IF obj = NIL THEN
			StringPool.GetIndex(name, idx);
			ob := PCT.Find(scope, scope, idx, PCT.procdeclared, TRUE);
			IF ob # NIL THEN  obj := ConvertObj(ob)  ELSE  insert(name, obj)		(* create forward jump *)
			END;
		END;
	END find;

(* ------------------------------------------------------------------- *)
(* Scanner functions *)

	PROCEDURE skipBlanks;
	BEGIN
			(* tf returns 01X when an embedded object is encountered *)
		WHILE (scanner.ch = SPACE) OR (scanner.ch = TAB) OR (scanner.ch = 01X) DO scanner.NextChar END;
		IF scanner.ch = ";" THEN
			WHILE (scanner.ch # CR) & (scanner.ch # LF) DO scanner.NextChar END	(* Skip comments *)
		END
	END skipBlanks;

	PROCEDURE GetIdent(VAR name: Name);
		VAR i: LONGINT;
	BEGIN i := 0; errpos := scanner.curpos - 1;
		REPEAT
			IF i < NameLen-1 THEN name[i] := scanner.ch; INC(i) END;
			scanner.NextChar
		UNTIL ~(("A" <= CAP(scanner.ch)) & (CAP(scanner.ch) <= "Z") OR ("0" <= scanner.ch) & (scanner.ch <= "9"));
		name[i] := 0X
	END GetIdent;

	PROCEDURE Get(VAR sym: LONGINT);

		PROCEDURE Str;
			VAR och: CHAR; i: LONGINT;
		BEGIN
			och := scanner.ch; i := 0;
			LOOP
				scanner.NextChar;
				IF scanner.ch = och THEN EXIT
				ELSIF scanner.ch < " " THEN PCM.Error(3, errpos, ""); EXIT
				ELSIF i = MaxStrLen-1 THEN PCM.Error(241, errpos, ""); EXIT
				END;
				str[i] := scanner.ch; INC(i)
			END;
			scanner.NextChar;
			str[i] := 0X; val := i;
		END Str;

		PROCEDURE Number(VAR intval: LONGINT);
		VAR i, m, n, d: INTEGER; dig: ARRAY 24 OF CHAR;

			PROCEDURE Ord(ch: CHAR; hex: BOOLEAN): INTEGER;
			BEGIN (* ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") *)
				IF ch <= "9" THEN RETURN ORD(ch) - ORD("0")
				ELSIF hex THEN RETURN ORD(ch) - ORD("A") + 10
				ELSE err(2); RETURN 0
				END
			END Ord;

		BEGIN
			i := 0; m := 0; n := 0; d := 0;
			LOOP (* read mantissa *)
				IF ("0" <= scanner.ch) & (scanner.ch <= "9") OR (d = 0) & ("A" <= scanner.ch) & (scanner.ch <= "F") THEN
					IF (m > 0) OR (scanner.ch # "0") THEN (* ignore leading zeros *)
						IF n < LEN(dig) THEN dig[n] := scanner.ch; INC(n) END;
						INC(m)
					END;
					scanner.NextChar; INC(i)
				ELSE EXIT
				END
			END; (* 0 <= n <= m <= i, 0 <= d <= i *)
			IF n = m THEN intval := 0; i := 0;
				IF scanner.ch = "X" THEN (* character *) scanner.NextChar;
					IF n <= 2 THEN
						WHILE i < n DO intval := intval*10H + Ord(dig[i], TRUE); INC(i) END
					ELSE err(203)
					END
				ELSIF scanner.ch = "H" THEN (* hexadecimal *) scanner.NextChar;
					IF n <= PCM.MaxHDig THEN
						IF (n = PCM.MaxHDig) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
						WHILE i < n DO intval := intval*10H + Ord(dig[i], TRUE); INC(i) END
					ELSE err(203)
					END
				ELSE (* decimal *)
					WHILE i < n DO d := Ord(dig[i], FALSE); INC(i);
						IF intval <= (MAX(LONGINT) - d) DIV 10 THEN intval := intval*10 + d
						ELSE err(203)
						END
					END
				END
			ELSE err(203)
			END
		END Number;

	BEGIN
		skipBlanks;
		errpos := scanner.curpos;
		CASE scanner.ch OF
		  "A" .. "Z", "a" .. "z" :
				GetIdent(ident);
				IF scanner.ch = ":" THEN
					scanner.NextChar; sym := ScLabel
        		ELSIF ~scanner.lcase & (ident = "END")  OR scanner.lcase & (ident="end") (* fof *)   THEN
        			sym := ScEnd
        		ELSE
					sym := ScIdent(*; find(ident, obj);
					IF obj # NIL THEN type := SHORT(obj.typ); val := obj.val
					ELSE type := none END*)
				END
		| "0".."9":
				val := 0; sym := ScNumber;
				Number(val);
		| "@": scanner.NextChar; sym := ScAt
		| ",":   scanner.NextChar; sym := ScComma
		| "[":   scanner.NextChar; sym := ScLBrak
		| "]":   scanner.NextChar; sym := ScRBrak
		| "{":   scanner.NextChar; sym := ScLBrace
		| "}":   scanner.NextChar; sym := ScRBrace
		| CR, LF:	scanner.NextChar; sym := ScCR
		| "*":	scanner.NextChar; sym := ScMult
		| "/":	scanner.NextChar; sym := ScDiv
		| "+":	scanner.NextChar; sym := ScPlus
		| "-":	scanner.NextChar; sym := ScMinus
		| "(":   scanner.NextChar; sym := ScLPar
		| ")":   scanner.NextChar; sym := ScRPar
		| ":":	scanner.NextChar; sym := ScColon
		| ".":	scanner.NextChar; sym := ScPoint
		| 22X, 27X: Str; sym := ScString;
		ELSE
			PCM.LogWLn; PCM.LogWStr("PCA: undef char "); PCM.LogWHex(ORD(scanner.ch));
			PCM.LogWStr(" at pos "); PCM.LogWNum(scanner.errpos);
			sym := ScUndef; scanner.NextChar
		END
	END Get;

	PROCEDURE Check(s: LONGINT);
	BEGIN IF sym # s THEN PCM.Error(s, errpos, "") END;
		Get(sym)
	END Check;

	PROCEDURE Qualident(VAR obj: Symbol);
	VAR i: LONGINT; idx: StringPool.Index;
	BEGIN
		obj := NIL;
		IF sym = ScIdent THEN
			IF ident = "SYSTEM" THEN
				IF ~scope.module.sysImported THEN PCM.Error(135, errpos, "") END;
				Get(sym);
				IF sym=ScPoint THEN
					Get(sym);
					IF sym = ScIdent THEN
						i := 0;
						WHILE (i < TargetCount) & (TargetTab[i].name # ident) DO INC(i) END;
						IF i = TargetCount THEN PCM.Error(0, errpos, "")
						ELSE
							NEW(obj); obj.typ := StConst;  obj.val := i
						END
					ELSE PCM.Error(0, errpos, "")
					END;
					Get(sym)
				ELSE PCM.Error(18, errpos, "")
				END
			ELSE
				Get(sym);  find(ident, obj);
				IF (obj#NIL) & (sym=ScPoint) & (obj.typ=StMod) THEN
					Get(sym);
					StringPool.GetIndex(ident, idx);
					obj := ConvertObj(PCT.Find(scope, obj.obj(PCT.Module).scope, idx, PCT.complete, TRUE));
				END;
				IF obj=NIL THEN PCM.Error(0, errpos, "") END
			END
		ELSE PCM.Error(40, errpos, "")
		END
	END Qualident;

	PROCEDURE Expression(VAR x: LONGINT);
		VAR y, op : LONGINT;

		PROCEDURE Factor(VAR x: LONGINT);
		BEGIN
			IF sym = ScNumber THEN x := val; Get(sym)
			ELSIF sym = ScLPar THEN
				Get(sym); Expression(x);
				Check(ScRPar)
			ELSE PCM.Error(601, errpos, "")
			END
		END Factor;

		PROCEDURE Term(VAR x: LONGINT);
			VAR y, op : LONGINT;
		BEGIN
			Factor(x);
			WHILE (sym = ScMult) OR (sym = ScDiv) DO
				op := sym; Get(sym);
				Factor(y);
				IF op = ScMult THEN x := x * y ELSE x := x DIV y END
			END
		END Term;

	BEGIN
		IF sym = ScMinus THEN op := sym; Get(sym); Term(x); x := -x
		ELSE Term(x)
		END;
		WHILE (sym = ScPlus) OR (sym = ScMinus) DO
			op := sym; Get(sym);
			Term(y);
			IF op = ScPlus THEN x := x + y ELSE x := x - y END
		END
	END Expression;

	PROCEDURE GetBaseIndex(VAR o: Operand; VAR size: LONGINT);
		VAR obj: Symbol; isNumber: BOOLEAN; minus: BOOLEAN;
	BEGIN
		o.disp := 0; o.imm := 0;

		WHILE (sym = ScLBrak) OR (sym = ScPlus) OR (sym = ScMinus) DO
			minus := sym = ScMinus;
			Get(sym);
			isNumber := FALSE;
			obj := NIL;
			IF sym = ScIdent THEN find(ident, obj); Get(sym);
			ELSIF sym = ScNumber THEN
				IF o.disp # 0 THEN PCM.Error(506,errpos,""); END;
				isNumber := TRUE; Expression(o.disp);
				IF minus THEN o.disp := -o.disp END;
			ELSE obj := NIL; 	Get(sym);
			END;

			IF isNumber THEN (* already read *)
			ELSIF (obj = NIL)  THEN
				PCM.Error(506,errpos,"");
			ELSIF  (obj.typ = StConst) THEN
				IF o.disp # 0 THEN PCM.Error(506,errpos,""); END;
				o.disp := obj.val;
				IF minus THEN o.disp := -o.disp END;
			ELSIF (obj.typ = StVar) OR (obj.typ = StVarPar) THEN
				IF inline THEN  PCM.Error(518, errpos, "")  END;
				IF o.disp # 0 THEN PCM.Error(506,errpos,""); END;
				o.disp := obj.val; (*o.obj := obj;*)
				IF minus THEN o.disp := -o.disp END;
				IF size = 0 THEN size := obj.size END;
			ELSIF ~IsRegMode(obj.typ, FALSE) OR (ModeSize(obj.typ) # 4) THEN
				PCM.Error(506, errpos, ""); RETURN
			ELSIF minus THEN
				PCM.Error(506, errpos, ""); RETURN
			ELSIF o.base = none THEN
				o.base := SHORT(obj.val);
				IF sym = ScMult THEN		(* This is the index, get the scale *)
					IF o.index # none THEN PCM.Error(509, errpos, ""); RETURN END;
					o.index := SHORT(obj.val); o.base := none;
					Get(sym);
					IF (sym # ScNumber) OR ((val # 1) & (val # 2) & (val # 4) & (val # 8)) THEN
						PCM.Error(508, errpos, ""); RETURN
					END;
					o.scale := SHORT(val);
					Get(sym);
				END;
			ELSIF o.index = none THEN
				o.index := SHORT(obj.val);
				IF sym = ScMult THEN		(* This is the index, get the scale *)
					Get(sym);
					IF (sym # ScNumber) OR ((val # 1) & (val # 2) & (val # 4) & (val # 8)) THEN
						PCM.Error(508, errpos, ""); RETURN
					END;
					o.scale := SHORT(val);
					Get(sym);
				END;

			ELSE PCM.Error(509, errpos, "")
			END;

			IF (sym = ScRBrak) THEN Get(sym) END;

		END; (* WHILE ScLBrak *)
		(* this is not a const but a rm !! *)
		CASE size OF
			  0: o.mode := M
			| 1: o.mode := M8
			| 2: o.mode := M16
			| 4: o.mode := M32
			| 8: o.mode := M64
			| 10: o.mode := M80
			| 16: o.mode := M128
		END;
	END GetBaseIndex;

	PROCEDURE GetOperand(VAR o: Operand);
		VAR obj: Symbol; size: LONGINT;
	BEGIN
		o.reg := none; o.disp := 0; o.base := none; o.index := none; o.imm := 0;
		o.seg := none; o.scale := none; o.obj := NIL;
		size := 0;	(* unknown size *)
		IF sym = ScIdent THEN
			find(ident, obj);
			IF (obj # NIL) & (obj.typ = SReg) THEN
				o.seg := SHORT(obj.val); Get(sym); Check(ScColon);
				IF sym = ScIdent THEN find(ident, obj) END
			END
		END;
		IF (sym = ScIdent) & (obj # NIL) & (obj.typ = StType) THEN
			size := SHORT(obj.size); Get(sym);
			IF (sym # ScIdent) OR (ident # "PTR") THEN (* PCM.Error(511PCM.Error() *)	(* PTR is optional *)
			ELSE Get(sym)
			END;
			IF sym = ScIdent THEN find(ident, obj) END
		END;
		CASE sym OF
		| ScAt:
				Get(sym);
				IF sym # ScNumber THEN PCM.Error(-601, errpos, "") END;
				o.disp := val; o.mode := M;
				Get(sym);
		| ScLBrak:
				GetBaseIndex(o, size);
		| ScIdent, ScNumber, ScMinus:
				IF sym = ScIdent THEN
					IF obj = NIL THEN PCM.Error(500, errpos, ""); RETURN END;
					IF size = 0 THEN size := obj.size END;		(* don't override the xyz PTR command *)
					IF IsRegMode(obj.typ, FALSE) THEN
						o.mode := obj.typ; o.reg := SHORT(obj.val); Get(sym); RETURN
					ELSIF IsSRegMode(obj.typ, FALSE) THEN
						o.mode := obj.typ; o.reg := SHORT(obj.val); Get(sym); RETURN
					ELSIF IsSpecRegMode(obj.typ) THEN
						IF ~(Privileged IN Target) THEN PCM.Error(515, errpos, "") END;
						IF ~(Pentium IN Target) & (obj.typ = CRReg) & (obj.val = 4) THEN PCM.Error(515, errpos, "") END;
						o.mode := obj.typ; o.reg := SHORT(obj.val); Get(sym); RETURN
					ELSIF obj.typ = XReg THEN
						IF ~(SSE IN Target) THEN PCM.Error(515, errpos, "") END;
						o.mode := obj.typ; o.reg := SHORT(obj.val); Get(sym); RETURN
					ELSIF obj.typ = MReg THEN
						IF ~(MMX IN Target) THEN PCM.Error(515, errpos, "") END;
						o.mode := obj.typ; o.reg := SHORT(obj.val); Get(sym); RETURN
					ELSIF IsFRegMode(obj.typ, FALSE) THEN
						o.mode := obj.typ; Get(sym);
						IF sym = ScLPar THEN Expression(size); o.reg := SHORT(size) ELSE o.reg := 0; o.mode := FRegST END;
						RETURN
					ELSIF obj.typ = StLabel THEN
						o.imm := obj.val; o.mode := Rel8; Get(sym); RETURN
					ELSIF obj.typ = StFwdLabel THEN
						o.obj := obj; o.mode := FwdJmp; Get(sym); RETURN
					ELSIF obj.typ = StConst THEN
						o.imm := obj.val; Get(sym);
					ELSIF (obj.typ = StVar) OR (obj.typ = StVarPar) THEN
						IF inline THEN  PCM.Error(518, errpos, "")  END;
						o.imm := obj.val; (*o.obj := obj;*) Get(sym)
					ELSIF (obj.typ = StGlobal) THEN
						o.disp := 012345678H; o.obj := obj;
						CASE size OF
						| 1: o.mode := M8
						| 2: o.mode := M16
						| 4: o.mode := M32
						| 8: o.mode := M64
						| 10: o.mode := M80
						(*| 16: o.mode := M128*)
						ELSE o.mode := M32
						END;
						Get(sym); RETURN		(* Global Var *)
					ELSE PCM.Error(600, errpos, ""); RETURN END
				ELSE Expression(o.imm)
				END;
				CASE size OF
				  1: o.mode := Imm8
				| 2: o.mode := Imm16
				| 4: o.mode := Imm32
				ELSE o.mode := Imm
				END;
				(*
				IF sym = ScLBrak THEN GetBaseIndex(o, size) END;
				*)
		ELSE
			o.mode := none; PCM.Error(511, errpos, "")
		END;  (* CASE sym OF *)
	END GetOperand;

(* ------------------------------------------------------------------- *)
(* Fixpoint handling functions *)

	PROCEDURE CheckLabels;
		VAR obj, obj1, obj2: Symbol;
	BEGIN obj1 := root.next; obj := NIL; (* invert list *)
		WHILE obj1 # NIL DO
			obj2 := obj1.next; obj1.next := obj; obj := obj1; obj1 := obj2
		END;
		WHILE obj # NIL DO
			IF obj.typ = StFwdLabel THEN
				PCM.Error(128, obj.val, "")	(* unsatisfied forward reference *)
			END;
			obj := obj.next
		END
	END CheckLabels;

	PROCEDURE InsertFix(obj: Symbol; pc: LONGINT);
		VAR fix: FixPnt; x: PCLIR.AsmFixup;
	BEGIN
		CASE obj.typ OF
		| StFwdLabel:
			NEW(fix);
			fix.pc := pc;
			fix.next := obj.fix;
			obj.fix := fix
		| StVar, StVarPar, StGlobal:
			IF export & inline THEN  PCM.Error(517, errpos, "")  END;
			NEW(x);
			x.offset := pc; x.adr := obj.obj.adr;
			x.next := asminline.fixup; asminline.fixup := x
		ELSE
			PCM.Error(607, errpos, "")
		END
	END InsertFix;

	PROCEDURE FixDisp(fix: FixPnt);
	VAR  i, offs, disp: LONGINT; cur: PCLIR.AsmBlock;
	BEGIN
		cur := first; offs := fix.pc-4;
		disp := pc - fix.pc;
		FOR i := 0 TO 3 DO
			WHILE offs > cur.len DO
				DEC(offs, cur.len);  cur := cur.next
			END;
			cur.code[offs] := CHR(disp);
			disp := LSH(disp, -8);
			INC(offs);
		END
	END FixDisp;

(* ------------------------------------------------------------------- *)
(* Code Generation functions *)

PROCEDURE PutByte(b: LONGINT);
BEGIN
	(*IF last.len >= LEN(last.code) THEN*)	(*emulate the way OPA works, because of the f**king fingerprint*)
	IF last.len >= 255 THEN
		NEW(last.next);
		last := last.next;
		last.len := 0
	END;
	last.code[last.len] := CHR(b);
	INC(last.len);
	INC(pc)
END PutByte;

PROCEDURE PutBytes(b, size: LONGINT);
BEGIN
	IF last.len >= 256-size THEN	(*emulate the way OPA works, because of the f**king fingerprint*)
		NEW(last.next);
		last := last.next;
		last.len := 0
	END;
	WHILE size > 0 DO
		PutByte(b);
		b := LSH(b, -8);
		DEC(size)
	END
END PutBytes;


PROCEDURE ModRM(VAR modrm: LONGINT; VAR op: Operand; mode, regpos: LONGINT; UseSpecReg, fix: BOOLEAN);
	VAR mod: LONGINT;
BEGIN
	IF (IsRegMode(mode,TRUE) & ~UseSpecReg) OR IsSRegMode(mode, FALSE)
			OR IsSpecRegMode(mode) OR (mode = MReg) OR (mode = XReg) THEN
		(* put reg index into the reg/opcode field *)
		ASSERT(op.reg # none);
		IF regpos = OmRM THEN	(*add to modrm too*)
			ASSERT(modrm = 0);	(*not set yet*)
			modrm := 3 * 40H + op.reg	(* R/M set to op.reg *)
		ELSIF regpos = OmRMReg THEN	(*add to modrm too*)
			ASSERT(modrm = 0);	(*not set yet*)
			modrm := 3 * 40H + op.reg * 9H	(* R/M and Reg/Opcode set to op.reg *)
		ELSE
			IF fix THEN
				(* put 3H into Mod field *)
				modrm := modrm + op.reg + 0C0H;
			ELSE
				modrm := modrm + op.reg * 8H
			END;
		END
	ELSIF NeedModRM(mode, none) OR (IsRegMode(mode,TRUE) & UseSpecReg) THEN
		IF op.reg # none THEN
			(* put reg index into the r/m field, 3H into the Mod field *)
			modrm := modrm + op.reg + 0C0H;
		ELSE
			(* set the mod field *)
			IF (op.disp = 0) & ~((op.base = 5) & (op.index = none)) THEN 	(* avoid case 0[EBP] *)
				mod := 0
			ELSIF ConstSize(op.disp, TRUE)=1 THEN
				mod := 1
			ELSIF (op.base = none) & (op.index = none) THEN
				mod := 0
			ELSE
				mod := 2
			END;
			modrm := modrm + mod * 40H;
			IF op.index # none THEN
				modrm := modrm + 4		(* use the sib byte *)
			ELSIF op.base # none THEN
				modrm := modrm + op.base
			ELSE
				modrm := modrm + 5			(* special case: disp32 *)
			END
		END
	ELSE PCM.Error(1000, errpos, "")
	END
END ModRM;

PROCEDURE SIB(op: Operand): SHORTINT;
	VAR val: LONGINT;
BEGIN
	IF op.index = 4 THEN 	(* ESP not allowed *)
		PCM.Error(501, errpos, "")
	ELSIF op.index # none THEN
		val := op.base + op.index*08H;
		CASE op.scale OF
		  none, 1:
		|2: val := val + 1 * 40H
		|4: val := val + 2 * 40H
		|8: val := val + 3 * 40H
		END
	ELSE
		val := op.base + 04H*08H;
	END;
	RETURN(SHORT(SHORT(val)))
END SIB;

PROCEDURE GenCode(ind: LONGINT; VAR op: ARRAY OF Operand);
	VAR i, instr, opi: LONGINT; name: Mnemo; fixobj: Symbol;
		UseRM, UseImm, UseSpecReg, UseSegReg, UseDisp, fix: BOOLEAN; seg, reg, modrm, sib, imm, immSize, disp: LONGINT;
BEGIN
(* Initialisation *)
	disp := 0;
	IF IsRelMode(op[0].mode) THEN		(* compute the size of the rel operand *)
		CASE ConstSize(op[0].imm-2 - pc, TRUE) OF		(* +2 = place for prefix & opcode0 *)
		  1: op[0].mode := Rel8
		| 2, 4: op[0].mode := Rel32
		END
	END;
	COPY(InstrTab[ind].name, name);
	instr := Match(ind, op, errpos);
	IF instr < 0 THEN RETURN END;	(* no matching opcode found *)

(* Instruction prefix *)
	UseSpecReg := IsSpecRegMode(OpTab[instr].op[0]) OR IsSpecRegMode(OpTab[instr].op[1]);
	UseSegReg := IsSRegMode(OpTab[instr].op[0], FALSE) OR IsSRegMode(OpTab[instr].op[1], FALSE);

	IF ~UseSpecReg & ~UseSegReg &
		(name[0] # "F") & (		(* float instruction always have different opcodes for M16 *)
		((name = "OUT") & (ModeSize(OpTab[instr].op[1]) = 2)) OR
		((name # "OUT") & (ModeSize(OpTab[instr].op[0]) = 2))) THEN	(* 16-bit mode *)
		IF (OpTab[instr].op[0] = Rel16) OR (((name ="LEA")OR(name="OUTS")) & (OpTab[instr].op[1] = RM16)) THEN
			PutByte(67H);	(* operand size prefix *)
		ELSIF (name # "RET") & (name # "ARPL") & (name # "STR") THEN
			PutByte(66H)
		END
	END;

	(* IF (MMX IN InstrTab[ind].target) THEN PutByte(0FH) END; *)

(* prepare the instruction*)
		seg := none; reg := none; modrm := 0; UseRM := FALSE; sib := none;
		UseImm := FALSE; fixobj := NIL;
		UseDisp := FALSE;
		i := 0;
		WHILE (i<3) & (OpTab[instr].op[i] # none) DO
			opi := OpTab[instr].op[i];
			(* segment prefix *)
			IF op[i].seg # none THEN
				IF seg # none THEN PCM.Error(504, errpos, "") ELSE seg := op[i].seg END;
			END;
			(* register to be added to the opcode *)
			IF (OpTab[instr].reg = OmOp) & (IsRegMode(opi, TRUE) OR IsFRegMode(opi, TRUE)) THEN
				reg := op[i].reg
			END;
			(* modrm byte *)
			IF NeedModRM(opi, OpTab[instr].reg) THEN
				IF (i > 0) & IsFix(name) & IsRegister(OpTab[instr].op[i-1]) & IsRegister(OpTab[instr].op[i]) THEN
					fix := TRUE;
(*
					KernelLog.String(name); KernelLog.Ln;
*)
				ELSE
					fix := FALSE;
				END;
				ModRM(modrm, op[i], opi, OpTab[instr].reg, UseSpecReg, fix); UseRM := TRUE;
				IF NeedModRM(opi, none) THEN
					disp := op[i].disp; fixobj := op[i].obj;
					UseDisp := (disp # 0) OR ((op[i].base = 5) & (op[i].index = none))
				END
			END;
			(* sib byte *)
			IF (op[i].index # none) OR (op[i].base = 4) THEN			(* process the escape ESP *)
				ASSERT (sib = none);
				sib := SIB(op[i])
			END;
			IF IsImmMode(opi) OR (IsRelMode(opi) & IsImmMode(op[i].mode)) THEN
				ASSERT( ~UseImm);
				UseImm := TRUE; imm := op[i].imm; immSize := ModeSize(opi)
			END;
			INC(i);
		END;

(* segment override *)
		IF seg # none THEN PutByte(seg) END;

(* opcode *)
		IF reg = none THEN reg := 0 END;
		IF OpTab[instr].op2 # none THEN
			PutByte(OpTab[instr].op0); PutByte(OpTab[instr].op1); PutByte(OpTab[instr].op2 + reg);
		ELSIF OpTab[instr].op1 # none THEN
			PutByte(OpTab[instr].op0); PutByte(OpTab[instr].op1 + reg)
		ELSE
			PutByte(OpTab[instr].op0 + reg)
		END;

	(* modr/m *)
		IF OpTab[instr].opc # none THEN
			ASSERT( AND(modrm, 38H) = 0);		(* reg/opcode field not used *)
			modrm := modrm + OpTab[instr].opc * 8H;
			UseRM := TRUE
		END;
		IF UseRM THEN PutByte(modrm) END;

	(* sib *)
		IF sib # none THEN PutByte(sib) END;

	(* displacement / immediate *)
		IF  UseDisp THEN
			IF fixobj # NIL THEN InsertFix(fixobj, pc) END;
			IF ConstSize(disp, TRUE) = 1 THEN PutByte(disp) ELSE PutBytes(disp, 4) END
		END;
		IF IsRelMode(OpTab[instr].op[0]) & ~IsImmMode(op[0].mode) THEN
			PutBytes(op[0].imm-pc-ModeSize(OpTab[instr].op[0]), ModeSize(OpTab[instr].op[0]));
			IF op[0].mode = FwdJmp THEN InsertFix(op[0].obj, pc) END
		END;
		IF UseImm THEN PutBytes(imm, immSize) END;
END GenCode;

(* ------------------------------------------------------------------- *)
(* Parser functions *)

	PROCEDURE ParseLabel;
		VAR obj: Symbol; fix: FixPnt;
	BEGIN
		ASSERT(sym = ScLabel);		(* Test done by the caller *)
		insert(ident, obj);
		IF obj.typ = StFwdLabel THEN
			fix := obj.fix;
			WHILE fix # NIL DO
				FixDisp(fix); fix := fix.next
			END;
			obj.typ := StLabel; obj.val := pc
		ELSE PCM.Error(512, errpos, "")
		END;
		Get(sym)
	END ParseLabel;

	PROCEDURE ParseInstruction;
		VAR	ind, size: LONGINT; i: LONGINT; op: ARRAY 3 OF Operand; name: Name;
	BEGIN
		(* Read Mnemonic *)
			IF (ident = "DB") OR (ident = "DW") OR (ident = "DD") THEN
				CASE ident[1] OF
				   "B": size := 1
				| "W": size := 2
				| "D": size := 4
				END;
				Get(sym);
				WHILE (sym = ScNumber) OR (sym = ScString) DO
					IF (sym = ScString) & (val = 1) THEN PutBytes(ORD(str[0]), size)
					ELSIF (sym = ScNumber) & (ConstSize(val, FALSE) <= size) THEN PutBytes(val, size)
					ELSE PCM.Error(203, errpos, "")
					END;
					Get(sym);
					IF sym = ScComma THEN Get(sym)
					ELSE RETURN
					END
				END
			ELSIF (ident = "DS") THEN
				Get(sym);
				IF (sym = ScString) THEN
					FOR i := 0 TO val DO PutBytes(ORD(str[i]), 1) END;
					Get(sym)
				ELSE PCM.Error(513, errpos, "")
				END
			ELSE
				FOR i := 0 TO 2 DO op[i].mode := none END;
				FindInstruction(ident, ind);	(* index in the hash tab *)
				COPY(ident, name);
				Get(sym);
				IF ind < 0 THEN PCM.Error(502, errpos, ""); RETURN END;

				name[3] := 0X;
				IF name = "REP" THEN	(* REP/REPE/REPZ/REPNE/REPNZ *)
					GenCode(ind, op);
					IF sym = ScCR THEN Get(sym) END;		(* there should be no label here *)
					FindInstruction(ident, ind);	(* index in the hash tab *)
					Get(sym);
					IF ind < 0 THEN PCM.Error(502, errpos, ""); RETURN END
				END;

				i := 0;
				IF sym # ScCR THEN
					LOOP
						GetOperand(op[i]); INC(i);
						IF sym # ScComma THEN EXIT END;
						Get(sym)
					END
				END;

				GenCode(ind, op);
			END (* IF DB *)
	END ParseInstruction;

	PROCEDURE ParseTarget;
	VAR obj: Symbol;
	BEGIN
		LOOP
			IF sym = ScIdent THEN
				Qualident(obj);
				IF (obj = NIL) THEN PCM.Error(0, errpos, "")
				ELSIF (obj.typ = StConst) THEN
					Target := Target + TargetTab[obj.val].flag
				ELSE PCM.Error(0, errpos, "")
				END
			ELSE PCM.Error(40, errpos, "")
			END;
			IF (sym = ScRBrace) THEN Get(sym); EXIT
			ELSIF sym = ScComma THEN Get(sym)
			ELSIF sym # ScIdent THEN PCM.Error(24, errpos(*rbrace*), ""); EXIT
			ELSE PCM.Error(19, errpos(*Comma*), "")
			END
		END
	END ParseTarget;

(* ------------------------------------------------------------------- *)
(* Initialisation functions *)

	PROCEDURE InsertReg(name: ARRAY OF CHAR; t, v: LONGINT);
		VAR obj: Symbol;
	BEGIN
		insert(name, obj); obj.typ := t; obj.val := v; obj.size := 0
	END InsertReg;

	PROCEDURE InsertType(name: ARRAY OF CHAR; s: LONGINT);
		VAR obj: Symbol;
	BEGIN
		insert(name, obj); obj.typ := StType; obj.val := none; obj.size := s
	END InsertType;

	PROCEDURE Init;
	BEGIN
		(* Internal Symbol-Table *)
			NEW(root);
			root.next := NIL; root.left := NIL; root.right := NIL;
			InsertReg("AL", RegAL, 0); InsertReg("AH", Reg8, 4);
			InsertReg("AX", RegAX, 0); InsertReg("EAX", RegEAX, 0);
			InsertReg("BL", Reg8, 3); InsertReg("BH", Reg8, 7);
			InsertReg("BX", Reg16, 3); InsertReg("EBX", Reg32, 3);
			InsertReg("CL", Reg8, 1); InsertReg("CH", Reg8, 5);
			InsertReg("CX", Reg16, 1); InsertReg("ECX", Reg32, 1);
			InsertReg("DL", Reg8, 2); InsertReg("DH", Reg8, 6);
			InsertReg("DX", Reg16, 2); InsertReg("EDX", Reg32, 2);
			InsertReg("SP", Reg16, 4); InsertReg("ESP", Reg32, 4);
			InsertReg("BP", Reg16, 5); InsertReg("EBP", Reg32, 5);
			InsertReg("SI", Reg16, 6); InsertReg("ESI", Reg32, 6);
			InsertReg("DI", Reg16, 7); InsertReg("EDI", Reg32, 7);
			InsertReg("MMX0", MReg, 0); InsertReg("MMX1", MReg, 1);
			InsertReg("MMX2", MReg, 2); InsertReg("MMX3", MReg, 3);
			InsertReg("MMX4", MReg, 4); InsertReg("MMX5", MReg, 5);
			InsertReg("MMX6", MReg, 6); InsertReg("MMX7", MReg, 7);
			InsertReg("XMM0", XReg, 0); InsertReg("XMM1", XReg, 1);
			InsertReg("XMM2", XReg, 2); InsertReg("XMM3", XReg, 3);
			InsertReg("XMM4", XReg, 4); InsertReg("XMM5", XReg, 5);
			InsertReg("XMM6", XReg, 6); InsertReg("XMM7", XReg, 7);

			InsertReg("CS", RegCS, 1H); InsertReg("SS", RegSS, 2H);
			InsertReg("DS", RegDS, 3H); InsertReg("ES", RegES, 0H);
			InsertReg("FS", RegFS, 4H); InsertReg("GS", RegGS, 5H);

			InsertReg("CR0", CRReg, 0); InsertReg("CR2", CRReg, 2); InsertReg("CR3", CRReg, 3);
			InsertReg("CR4", CRReg, 4);
			InsertReg("DR0", DRReg, 0); InsertReg("DR1", DRReg, 1); InsertReg("DR2", DRReg, 2);
			InsertReg("DR3", DRReg, 3); InsertReg("DR6", DRReg, 6); InsertReg("DR7", DRReg, 7);
			(*InsertReg("TR6", TRReg, 6); InsertReg("TR7", TRReg, 7);*)

			InsertReg("ST0", FReg, 0); InsertReg("ST1", FReg, 1);
			InsertReg("ST2", FReg, 2); InsertReg("ST3", FReg, 3);
			InsertReg("ST4", FReg, 4); InsertReg("ST5", FReg, 5);
			InsertReg("ST6", FReg, 6); InsertReg("ST7", FReg, 7);


			InsertType("BYTE", 1);
			InsertType("WORD", 2);
			InsertType("DWORD", 4);
			InsertType("QWORD", 8);
			InsertType("TBYTE", 10);

		(* Global variables *)
			pc := 0; Target := {}
	END Init;

BEGIN	(*Assemble*)
	IF ~loaded THEN BodyInit END;
	export := exported;  inline := inlined;
	Init;
	NEW(asminline);
	NEW(first);
	last := first; first.len := 0;
	asminline.code := first;
	Get(sym);
	IF sym = ScLBrace THEN
		Get(sym);
		ParseTarget
	ELSE
		Get(sym);
		Target := {}
	END;
	IF Target = {} THEN PCM.Error(516, errpos, ""); Target := {0..31} END;
	WHILE (sym # ScEnd) & (sym # ScUndef) DO
		IF sym = ScLabel THEN ParseLabel END;
		IF sym = ScIdent THEN ParseInstruction END;
		WHILE (sym # ScEnd) & (sym # ScCR) DO
			Get(sym); PCM.Error(510, errpos, "")
		END;
		Get(sym)
	END;
	IF (sym # ScEnd) THEN PCM.Error(PCS.end, errpos, "") END;
	IF ~PCM.error THEN CheckLabels END;	(* check for undefined forward jumps *)
	RETURN asminline
END Assemble;


	PROCEDURE BodyInit;
		VAR s: INTEGER; i: LONGINT; f: Files.File; r: Files.Reader;

		PROCEDURE InsertTarget(name: ARRAY OF CHAR; flag: SET);
		BEGIN
			COPY(name, TargetTab[TargetCount].name);
			TargetTab[TargetCount].flag := flag;
			INC(TargetCount);
		END InsertTarget;

	BEGIN {EXCLUSIVE}
		IF ~loaded THEN
			PCM.LogWLn; PCM.LogWStr("  using ASM add-on / prk");
			f := Files.Old(FileName);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				r.RawInt(s); InstrTabLen := s;  NEW(InstrTab, InstrTabLen);
				FOR i := 0 TO InstrTabLen-1 DO
					r.RawString(InstrTab[i].name);
					IF InstrTab[i].name # "" THEN
						r.RawInt(InstrTab[i].start);
						r.RawInt(InstrTab[i].end);
						r.RawSet(InstrTab[i].target)
					END
				END;
				r.RawInt(s); OpTabLen := s;  NEW(OpTab, OpTabLen);
				FOR i:= 0 TO OpTabLen-1 DO
					r.RawInt(OpTab[i].op[0]); r.RawInt(OpTab[i].op[1]); r.RawInt(OpTab[i].op[2]);
					r.RawInt(OpTab[i].op0); r.RawInt(OpTab[i].op1);
					r.RawInt(OpTab[i].op2);
					r.RawInt(OpTab[i].opc); r.RawInt(OpTab[i].reg)
				END
			ELSE
				PCM.LogWLn; PCM.LogWStr(FileName); PCM.LogWStr(" not found, ASM not ready")
			END;

			SizeTab[0] := 0; SizeTab[1] := 1; SizeTab[2] := 1; SizeTab[3] := 1;
			SizeTab[4] := 1; SizeTab[5] := 2; SizeTab[6] := 4; SizeTab[7] := 4;
			SizeTab[8] := 8; SizeTab[9] := 4; SizeTab[10] := 4; SizeTab[11] := 4;
			SizeTab[12] := 0; SizeTab[13] := 4; SizeTab[14] := 4; SizeTab[15] := 0;
			SizeTab[16] := 8;

			TargetCount := 0;
			InsertTarget("i386", {i386});
			InsertTarget("i486", {i386, i486});
			InsertTarget("Pentium", {i386, i486, Pentium});
			InsertTarget("PentiumPro", {i386, i486, Pentium, PentiumPro});
			InsertTarget("P2", {i386, i486, Pentium, PentiumPro}); (* compatibility with new compiler *)
			InsertTarget("P3", {i386, i486, Pentium, PentiumPro}); (* compatibility with new compiler *)
			InsertTarget("P4", {i386, i486, Pentium, PentiumPro}); (* compatibility with new compiler *)
			InsertTarget("FPU", {FPU});
			InsertTarget("Privileged", {Privileged});
			InsertTarget("MMX", {MMX});
			InsertTarget("SSE", {MMX, SSE});
			InsertTarget("SSE2", {MMX, SSE, SSE2});
			InsertTarget("SSE3", {MMX, SSE, SSE2,SSE3});
			InsertTarget("SSE4", {MMX, SSE, SSE2, SSE3,SSE4});

			loaded := TRUE
		END
	END BodyInit;

	PROCEDURE Install*;
	BEGIN PCP.Assemble := Assemble
	END Install;

BEGIN
	loaded := FALSE;
END PCA386.


(*
	05.02.02	prk	PCT.Find cleanup
	08.11.01	prk	mode to put reg in R/M field added
	05.11.01	prk	MMX instruction set
	23.07.01	prk	IMUL Reg32, Imm8; IMUL Reg32, Imm32 are aliases to IMUL Reg32, RM32, Imm. Fixed (OPA.Data changed)
	11.07.01	prk	use Files+Streams instead of Files
	11.07.01	prk	support for fields and methods with same name in scope
	02.07.01	prk	access flags, new design
	30.05.01	prk	destination (\d) compiler-option to install the back-end
	30.05.01	pjm	support for HUGEINT types (by pjm)
*)