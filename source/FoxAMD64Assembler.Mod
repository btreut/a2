MODULE FoxAMD64Assembler; (**  AUTHOR "fn & fof"; PURPOSE "Oberon Compiler:AMD 64 Assembler";  **)
(* (c) fof ETH Zürich, 2008 *)
(*
	this module has in great portions been taken over  from Florian Negele's PCAAMD64.Mod
*)

IMPORT
	Basic := FoxBasic, Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, InstructionSet := FoxAMD64InstructionSet, Sections := FoxSections,
	BinaryCode := FoxBinaryCode,	SYSTEM, Streams, Strings, Commands, KernelLog, Diagnostics, IntermediateCode := FoxIntermediateCode, ObjectFile
	;

CONST
	Trace= FALSE;

	none* = InstructionSet.none;

	(* rex prefix bit positions *)
	rexB = 0;
	rexX = 1;
	rexR = 2;
	rexW= 3;
	rex = 4;

	(* register indices, the numbers have a meaning in instruction encoding, do not modify *)
	RAX* = 0; EAX*=0; AX*=0; AL*=0;
	RCX* = 1; ECX*=1; CX*=1; CL*=1;
	RDX* = 2;EDX*=2; DX*=2; DL*=2;
	RBX* = 3;EBX*=3; BX*=3; BL*=3;
	RSP* = 4; ESP*=4; SP*=5; SPL*=4; AH*=4;
	RBP* = 5; EBP*=5; BP*=5; BPL*=5; CH*=5;
	RSI* = 6; ESI*=6; SI*=6; SIL*=6; DH*=6;
	RDI* = 7;EDI*=7; DI*=7; DIL*=7; BH*=7;
	R8*= 8; R8D*=8; R8W*=8; R8B*=8;
	R9* = 9;R9D*=9; R9W*=9; R9B*=9;
	R10* = 10;R10D*=10; R10W*=10; R10B*=10;
	R11* = 11;R11D*=11; R11W*=11; R11B*=11;
	R12* = 12;R12D*=12; R12W*=12; R12B*=12;
	R13* = 13;R13D*=13; R13W*=13; R13B*=13;
	R14* = 14;R14D*=14; R14W*=14; R14B*=14;
	R15* = 15;R15D*=15; R15W*=15; R15B*=15;
	RIP* = 16;

	(* segment registers *)
	segES = 0;
	segCS = 1;
	segSS = 2;
	segDS = 3;
	segFS = 4;
	segGS = 5;


	(* sizes *)
	bitsDefault* = 0;
	bits8* = 1;
	bits16* = 2;
	bits32* = 4;
	bits64* = 8;
	bits128* = 16;

	(** constants from InstructionSet **)
	(* instruction encoding *)
	opCode = InstructionSet.opCode;
	modRMExtension= InstructionSet.modRMExtension; modRMBoth= InstructionSet.modRMBoth;
	cb= InstructionSet.cb; cw= InstructionSet.cw; cd= InstructionSet.cd; cp= InstructionSet.cp;
	ib= InstructionSet.ib; iw= InstructionSet.iw; id= InstructionSet.id; iq= InstructionSet.iq;
	rb= InstructionSet.rb; rw= InstructionSet.rw; rd= InstructionSet.rd; rq= InstructionSet.rq;
	mem64Operand= InstructionSet.mem64Operand; mem128Operand= InstructionSet.mem128Operand;
	fpStackOperand= InstructionSet.fpStackOperand; directMemoryOffset= InstructionSet.directMemoryOffset;
	(* limits *)
	maxNumberOperands = InstructionSet.maxNumberOperands;

	(* operand types, values have no meaning but do coincide with symbols in the instruction set module *)
	reg8*= InstructionSet.reg8;
	reg16*= InstructionSet.reg16;
	reg32*= InstructionSet.reg32;
	reg64*= InstructionSet.reg64;
	CRn*=  InstructionSet.CRn;
	DRn*= InstructionSet.DRn;
	segReg*= InstructionSet.segReg;
	mmx*= InstructionSet.mmx;
	xmm*= InstructionSet.xmm;
	mem*=InstructionSet.mem;
	sti*= InstructionSet.sti;
	imm  *= InstructionSet.imm;
	ioffset *=InstructionSet.ioffset;
	pntr1616*= InstructionSet.pntr1616;
	pntr1632*=InstructionSet.pntr1632;


	(* scanner codes *)
	TAB = 09X;
	LF = 0AX;
	CR = 0DX;
	SPACE = 20X;

	(* symbol values *)
	symNone = 0;
	symIdent = 1;
	symLabel = 2;
	symNumber = 3;
	symSemicolon = 4;
	symColon = 5;
	symLn = 6;
	symComma = 7;
	symString = 8;
	symPlus = 9;
	symMinus = 10;
	symTimes = 11;
	symDiv = 12;
	symLParen = 13;
	symRParen = 14;
	symLBrace = 15;
	symRBrace = 16;
	symLBraket = 17;
	symRBraket = 18;
	symPC = 19;
	symPCOffset = 20;
	symNegate = 21;
	symMod = 22;
	symPeriod = 23;
	symAt = 24;
	symEnd = 25;

TYPE
	Name = Scanner.IdentifierString;

	Size = SHORTINT;
	Register* = LONGINT; (* index for InstructionSet.registers *)
	(*
		an implementation of Operands as objects is very elegant but unfortunately also very costly in terms of number of allocations
	*)

	Operand* = RECORD
		type-: SHORTINT; (* reg8..reg64, CRn,DRn, segReg, sti, mmx, xmm, mem, imm, moffset, pntr1616, pntr1632 *)
		(* assembler examples:
			reg8: AL => register = InstructionSet.regAL
			reg16: CX => register = InstructionSet.regCX
			reg32: EBX => register = InstructionSet.regEBX
			reg64: RCX => register = InstructionSet.regRCX
			mem: BYTE [EAX+EBX*4+16] => register = EAX, index = EBX, scale = 4, displacement = 16, size = 8
			imm: DWORD 256 => val = 256, size = 32
		*)
		register-: Register; (* for registers and mem *)
		sizeInBytes-: Size; (* for mem and imm and moffset *)
		segment-,index-: Register; (* registers for mem *)
		scale-, displacement-: LONGINT;  (* for mem *)
		symbol- : ObjectFile.Identifier; (* for imm and mem *)
		symbolOffset-: LONGINT; (* offset in immediate code (source) for a fixup *)

		val-: HUGEINT; (* for imm and moffset  *)
		pc-: LONGINT;

		selector-, offset-: LONGINT; (* for pntr1616 / pntr1632 *)
	END;

	Code* = BinaryCode.Section;

	NamedLabel*= OBJECT
	VAR
		offset: LONGINT;
		name-: SyntaxTree.IdentifierString;
		nextNamedLabel-: NamedLabel;
		index-: LONGINT;

		PROCEDURE &InitNamedLabel(offset: LONGINT; CONST name: ARRAY OF CHAR);
		BEGIN
			SELF.offset := offset;
			COPY(name,SELF.name);
			nextNamedLabel := NIL;
		END InitNamedLabel;

		PROCEDURE SetOffset*(ofs: LONGINT);
		BEGIN SELF.offset := ofs;
		END SetOffset;

	END NamedLabel;

	NamedLabelList*=OBJECT
	VAR first-,last-: NamedLabel; number-: LONGINT;

		PROCEDURE & InitNamedLabelList;
		BEGIN first := NIL; last := NIL; number := 0;
		END InitNamedLabelList;

		PROCEDURE Add*(n: NamedLabel);
		BEGIN
			IF first = NIL THEN first := n ELSE last.nextNamedLabel := n; last.nextNamedLabel := n;  END; last := n; INC(number);
			n.index := number;
		END Add;

		PROCEDURE Find*(CONST name: ARRAY OF CHAR): NamedLabel;
		VAR label: NamedLabel;
		BEGIN
			label := first;
			WHILE (label # NIL) & (label.name # name)  DO
				label := label.nextNamedLabel;
			END;
			RETURN label
		END Find;

	END NamedLabelList;

	Emitter*=OBJECT
	VAR
		code-: Code;
		error-: BOOLEAN;
		diagnostics: Diagnostics.Diagnostics;

		(* overal state *)
		cpuBits: Size; (* supported bit width for this cpu / target *)
		cpuOptions: InstructionSet.CPUOptions;
		dump: Streams.Writer;

		PROCEDURE & InitEmitter*(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics;
			cpuBits := bits32; cpuOptions := {0..31};
			error := FALSE;
		END InitEmitter;

		PROCEDURE SetCode*(code: BinaryCode.Section);
		BEGIN SELF.code := code;
			dump := code.comments
		END SetCode;

		PROCEDURE SetBits* (numberBits: LONGINT): BOOLEAN;
		BEGIN
			CASE numberBits OF
			16: cpuBits := bits16;
			| 32: cpuBits := bits32;
			| 64: cpuBits := bits64;
			ELSE
				Error("number bits not supported");
				RETURN FALSE;
			END;
			RETURN TRUE;
		END SetBits;

		PROCEDURE Error(CONST message: ARRAY OF CHAR);
		VAR msg,name: ARRAY 256 OF CHAR;
		BEGIN
			COPY(message,msg);
			Strings.Append(msg," in ");
			ObjectFile.SegmentedNameToString(code.os.identifier.name,name);
			Strings.Append(msg, name);
			IF diagnostics # NIL THEN
				diagnostics.Error("",Diagnostics.Invalid,Diagnostics.Invalid,msg);
			END;
			error := TRUE;
			IF dump # NIL THEN dump.Update; END;
		END Error;

		PROCEDURE ErrorSS(CONST msg1,msg2: ARRAY OF CHAR);
		VAR message: ARRAY 256 OF CHAR;
		BEGIN
			COPY(msg1,message);
			Strings.Append(message," : ");
			Strings.Append(message, msg2);
			Error(message);
		END ErrorSS;

		PROCEDURE ErrorSI(CONST msg1: ARRAY OF CHAR; mnemonic: LONGINT; CONST operands: ARRAY OF Operand);
		VAR s: Streams.StringWriter; msg: Basic.MessageString;
		BEGIN
			NEW(s,LEN(msg));
			DumpInstruction(s,mnemonic,operands);
			s.String(" @");
			s.Int(code.pc,1);
			s.Get(msg);
			ErrorSS(msg1,msg);
		END ErrorSI;
		
		PROCEDURE AddFixup (mode: SHORTINT; size: SHORTINT; pc: LONGINT; symbol: ObjectFile.Identifier; symbolOffset, displacement: LONGINT);
		VAR fixup: BinaryCode.Fixup; format: BinaryCode.FixupPatterns; id: ObjectFile.Identifier;
		BEGIN
			NEW(format,1);
			format[0].bits:= size*8;
			format[0].offset := 0;
			fixup := BinaryCode.NewFixup(mode,pc,symbol,symbolOffset,displacement,0,format);
			code.fixupList.AddFixup(fixup);
		END AddFixup;


		PROCEDURE EmitInstruction (mnem: LONGINT; VAR operands: ARRAY OF Operand; lastPass: BOOLEAN): BOOLEAN;
		VAR instr, i, oppos, op: LONGINT;
			val: LONGINT;
			regOperand: LONGINT;
			addressOperand: LONGINT;
			regField, modField, rmField: LONGINT;
			scaleField, indexField, baseField: LONGINT;
			free: ARRAY maxNumberOperands OF BOOLEAN;
			byte: LONGINT;
			offset: LONGINT;
			opPrefix, adrPrefix: BOOLEAN;
			segPrefix: LONGINT; rexPrefix: SET;

			bitwidthOptions: SET;
			opcode: ARRAY InstructionSet.maxCodeLength OF InstructionSet.Code;
			pc0: LONGINT;

			debug,temp: LONGINT;

			PROCEDURE FindInstruction(mnem: LONGINT; CONST operands: ARRAY OF Operand): LONGINT;
			VAR instr: LONGINT;
				PROCEDURE MatchesInstruction (): BOOLEAN;
				VAR i: LONGINT;
				BEGIN
					FOR i := 0 TO maxNumberOperands - 1 DO
						IF (i>=LEN(operands)) OR (operands[i].type = none) THEN (* no operand -> check if instruction has no operand here *)
							IF InstructionSet.instructions[instr].operands[i] # none THEN
							RETURN FALSE END;
						ELSIF ~Matches(operands[i],InstructionSet.instructions[instr].operands[i]) THEN (* instruction operand type and this operand do not match *)
							RETURN FALSE
						ELSIF (cpuBits = bits64) & (InstructionSet.optNot64 IN InstructionSet.instructions[instr].bitwidthOptions) THEN (* instruction is invalid in 64 bit mode *)
							RETURN FALSE;
						END;
					END;
					RETURN TRUE;
				END MatchesInstruction;
			BEGIN
				instr := InstructionSet.mnemonics[mnem].firstInstruction;

				WHILE (instr <= InstructionSet.mnemonics[mnem].lastInstruction) & (~MatchesInstruction ()) DO INC (instr); END;

				IF instr > InstructionSet.mnemonics[mnem].lastInstruction THEN
					ErrorSI("invalid combination of opcode and operands", mnem,operands); RETURN none;
				ELSIF InstructionSet.instructions[instr].cpuOptions * cpuOptions # InstructionSet.instructions[instr].cpuOptions THEN
					ErrorSI("invalid instruction for current target", mnem,operands); RETURN none;
				END;

				RETURN instr
			END FindInstruction;

			PROCEDURE GetRegOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO maxNumberOperands -1 DO
					CASE InstructionSet.instructions[instr].operands[i] OF
					InstructionSet.reg8, InstructionSet.reg16, InstructionSet.reg32, InstructionSet.reg64, InstructionSet.xmm, InstructionSet.mmx: RETURN i;
					ELSE
					END;
				END;
				RETURN none;
			END GetRegOperand;

			PROCEDURE GetAddressOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO maxNumberOperands -1 DO
					CASE InstructionSet.instructions[instr].operands[i] OF
					InstructionSet.mem,
					InstructionSet.mem8, InstructionSet.mem16, InstructionSet.mem32, InstructionSet.mem64, InstructionSet.mem128,
					InstructionSet.regmem8, InstructionSet.regmem16, InstructionSet.regmem32, InstructionSet.regmem64,
					InstructionSet.mmxmem32, InstructionSet.mmxmem64,
					InstructionSet.xmmmem32, InstructionSet.xmmmem64, InstructionSet.xmmmem128:
						RETURN i;
					ELSE
					END;
				END;
				RETURN none;
			END GetAddressOperand;

			PROCEDURE GetSpecialOperand (): LONGINT;
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO maxNumberOperands -1 DO
					CASE InstructionSet.instructions[instr].operands[i] OF
					InstructionSet.segReg, InstructionSet.mmx, InstructionSet.xmm, InstructionSet.CRn, InstructionSet.DRn:
						RETURN i;
					ELSE
					END;
				END;
				RETURN none;
			END GetSpecialOperand;

			PROCEDURE ModRM (mod, reg, rm: LONGINT);
			BEGIN
				IF Trace THEN KernelLog.String("ModRM"); KernelLog.Int(mod,1); KernelLog.String(","); KernelLog.Int(reg,1);
					KernelLog.String(","); KernelLog.Int(rm,1); KernelLog.Ln;
				END;

				code.PutByte (mod MOD 4 * 40H + reg MOD 8 * 8H + rm MOD 8);
			END ModRM;

			PROCEDURE SIB (scale, index, base: LONGINT);
			BEGIN code.PutByte (scale MOD 4 * 40H + index MOD 8 * 8H + base MOD 8);
			END SIB;

			PROCEDURE FPOrSSEOperation(instr: LONGINT): BOOLEAN;
			BEGIN
				RETURN {InstructionSet.cpuFPU, InstructionSet.cpuSSE, InstructionSet.cpuSSE2, InstructionSet.cpuSSE3} * InstructionSet.instructions[instr].cpuOptions # {}
			END FPOrSSEOperation;

		BEGIN
			IF (dump # NIL) & (lastPass) THEN
				pc0 := code.pc;
				DumpInstruction(dump,mnem,operands);
				dump.Update;
			END;
			IF Trace THEN
				DumpInstruction(kernelWriter,mnem,operands);
				kernelWriter.Update;
			END;

			instr := FindInstruction(mnem,operands);
			IF instr = none THEN RETURN FALSE END;
			bitwidthOptions := InstructionSet.instructions[instr].bitwidthOptions;
			FOR i := 0 TO InstructionSet.maxCodeLength-1 DO opcode[i] := InstructionSet.instructions[instr].code[i] END;

			opPrefix := FALSE;
			adrPrefix := FALSE;
			segPrefix := none;
			rexPrefix := {};

			IF (InstructionSet.optO16 IN bitwidthOptions) & (cpuBits # bits16) THEN
				IF Trace THEN KernelLog.String(" optO16   "); KernelLog.Ln;  END;
				opPrefix := TRUE;
			END;
			IF (InstructionSet.optO32 IN bitwidthOptions) & (cpuBits = bits16) THEN
				IF Trace THEN KernelLog.String(" optO32   "); KernelLog.Ln;  END;
				opPrefix := TRUE;
			END;
			IF (InstructionSet.optO64 IN bitwidthOptions) & (cpuBits = bits64) THEN
				IF Trace THEN KernelLog.String(" optO64   "); KernelLog.Ln;  END;
				INCL (rexPrefix, rexW)
			END;
			IF InstructionSet.optPOP IN bitwidthOptions THEN
				IF Trace THEN KernelLog.String(" optPOP   "); KernelLog.Ln;  END;
				opPrefix := TRUE;
			END;

			regOperand := GetSpecialOperand ();
			addressOperand := GetAddressOperand ();
			IF regOperand = none THEN
				regOperand := GetRegOperand ();
			END;
			IF addressOperand = none THEN
				addressOperand := GetRegOperand ();
				IF regOperand # none THEN
					temp := InstructionSet.instructions[instr].operands[regOperand];
					IF (temp = xmm) OR (temp = mmx) THEN (* patch case such as PEXTRW EDX, XMM3, 0 *)
						temp := addressOperand; addressOperand := regOperand; regOperand := temp;
					END;
				ELSE
				END;
			END;
			IF mnem = InstructionSet.opMOVQ2DQ THEN (* patch *)
				regOperand := 0; addressOperand :=1;
			END;

			(* KernelLog.String (InstructionSet.mnemonics[mnem].name); KernelLog.Int (regOperand, 10); KernelLog.Int (addressOperand, 10); KernelLog.Ln; *)

			FOR i := 0 TO maxNumberOperands - 1 DO
				IF operands[i].type # none THEN
					IF operands[i].type = mem THEN
						IF Trace THEN KernelLog.String("mem"); KernelLog.Ln; END;
						IF operands[i].segment# none THEN
							IF Trace THEN KernelLog.String(" segment "); KernelLog.Ln; END;
							segPrefix := InstructionSet.RegisterIndex(operands[i].segment);
						END;
						IF operands[i].register# none THEN
							IF Trace THEN KernelLog.String(" register "); KernelLog.Int(operands[i].register,1); KernelLog.Ln;   END;
							IF (InstructionSet.RegisterIndex(operands[i].register) >= 8) THEN
								IF Trace THEN KernelLog.String(" rexprefix "); KernelLog.Ln;   END;
								INCL (rexPrefix, rexB)
							END;
							IF (InstructionSet.RegisterType(operands[i].register) = reg32) & (cpuBits # bits32) THEN
								IF Trace THEN KernelLog.String(" adr prefix "); KernelLog.Ln;   END;
								adrPrefix := TRUE;
							END;
							IF InstructionSet.RegisterType(operands[i].register)=reg16 THEN
								IF cpuBits = bits64 THEN
									ErrorSI("invalid effective address (1)", mnem,operands);
									RETURN FALSE;
								ELSIF cpuBits = bits32 THEN
									IF Trace THEN KernelLog.String(" adr prefix (2) "); KernelLog.Ln;   END;
									adrPrefix := TRUE;
								END;
							END;
						END;
						IF operands[i].index # none THEN
							IF Trace THEN KernelLog.String(" mem index "); KernelLog.Int(operands[i].index,1); KernelLog.Ln; END;
							IF (InstructionSet.RegisterType(operands[i].index)=reg64) & (InstructionSet.RegisterIndex(operands[i].index) >= 8) THEN
								INCL (rexPrefix, rexX)
							END
						END;
						IF (operands[i].sizeInBytes = bits64) & ~(InstructionSet.optD64 IN bitwidthOptions) & ~FPOrSSEOperation(instr) THEN
							IF Trace THEN KernelLog.String(" bits64 "); KernelLog.Ln; END;
							INCL (rexPrefix, rexW)
						END;
						IF InstructionSet.instructions[instr].operands[i] = InstructionSet.moffset64 THEN
							IF Trace THEN KernelLog.String(" moffset64 "); KernelLog.Ln; END;
							adrPrefix := TRUE;
						END;
					ELSIF IsRegisterOperand(operands[i]) (* is register *)   THEN
						IF Trace THEN KernelLog.String("register"); KernelLog.Ln; END;
						IF (operands[i].type = reg64) & ~(InstructionSet.optD64 IN bitwidthOptions) THEN
							IF Trace THEN KernelLog.String(" reg64 "); KernelLog.Ln; END;
							INCL (rexPrefix, rexW)
						END;
						IF InstructionSet.RegisterIndex(operands[i].register) >= 8 THEN
							IF i = addressOperand THEN
								INCL (rexPrefix, rexB)
							ELSIF i = regOperand THEN
								INCL (rexPrefix, rexR)
							END;
						ELSIF (cpuBits = bits64) & (operands[i].type = reg8) & (InstructionSet.RegisterIndex(operands[i].register) >= 4) THEN
							INCL (rexPrefix, rex);
						END;
					END;
				END;
				free[i] := operands[i].type # none;
			END;

			CASE segPrefix OF
			none:
			| segES: code.PutByte (InstructionSet.prfES);
			| segCS: code.PutByte (InstructionSet.prfCS);
			| segSS: code.PutByte (InstructionSet.prfSS);
			| segDS: code.PutByte (InstructionSet.prfDS);
			| segFS: code.PutByte (InstructionSet.prfFS);
			| segGS: code.PutByte (InstructionSet.prfGS);
			END;

			IF opPrefix THEN code.PutByte (InstructionSet.prfOP) END;
			IF adrPrefix THEN code.PutByte (InstructionSet.prfADR) END;

			IF InstructionSet.optPLOCK IN bitwidthOptions THEN code.PutByte (InstructionSet.prfLOCK) END;
			IF InstructionSet.optPREP IN bitwidthOptions THEN code.PutByte (InstructionSet.prfREP) END;
			IF InstructionSet.optPREPN IN bitwidthOptions THEN code.PutByte (InstructionSet.prfREPNE) END;

			IF rexPrefix # {} THEN
				ASSERT(cpuBits = bits64);
				byte := 40H;
				IF rexB IN rexPrefix THEN byte := byte + 1H END;
				IF rexX IN rexPrefix THEN byte := byte + 2H END;
				IF rexR IN rexPrefix THEN byte := byte + 4H END;
				IF rexW IN rexPrefix THEN byte := byte + 8H END;
				code.PutByte (byte);
			END;

			op := 0;

			oppos := 0;
			val := -1;

			WHILE (oppos < LEN(opcode)) & (opcode[oppos] # CHR(none)) DO
				IF opcode[oppos] = CHR(opCode) THEN
					IF Trace THEN KernelLog.String("opcode "); KernelLog.Hex(ORD(opcode[oppos+1]),-2);  END;
					IF val # -1 THEN code.PutByte (val) END;
					INC(oppos);
					val := ORD(opcode[oppos]);
				ELSE
					CASE ORD(opcode[oppos]) OF
					| modRMExtension, modRMBoth:
						IF Trace THEN KernelLog.String(" modRMExtension/Both "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						IF opcode[oppos] = CHR(modRMBoth) (* /r *)  THEN
							regField := InstructionSet.RegisterIndex(operands[regOperand].register) MOD 8;
						ELSE (* /digit *)
							INC(oppos);
							regField := ORD(opcode[oppos]);
							IF Trace THEN KernelLog.String(" digit: "); KernelLog.Int(regField,1); KernelLog.Ln; END;
						END;
						IF IsRegisterOperand(operands[addressOperand]) THEN
							IF Trace THEN KernelLog.String(" isRegisterOperand "); END;
							ModRM (3, regField, InstructionSet.RegisterIndex(operands[addressOperand].register) MOD 8);
						ELSIF (cpuBits = bits16) & (InstructionSet.RegisterType(operands[addressOperand].register) # reg32) THEN
							IF Trace THEN KernelLog.String(" cpuBits=16 "); END;
							IF (operands[addressOperand].scale # 1) OR (operands[addressOperand].symbol.name # "") THEN
								ErrorSI("invalid effective address (2)", mnem,operands);
								RETURN FALSE;
							ELSIF operands[addressOperand].register= none THEN
								IF operands[addressOperand].index =none  THEN
									ErrorSI("invalid effective address (3)", mnem,operands);
									RETURN FALSE;
								END;
								ModRM (0, regField, 6);
								code.PutWord (operands[addressOperand].displacement);
							ELSIF InstructionSet.RegisterType(operands[addressOperand].register) = reg16  THEN
								IF operands[addressOperand].displacement = 0 THEN
									modField := 0;
								ELSIF (operands[addressOperand].displacement >= -80H) & (operands[addressOperand].displacement < 80H) THEN
									modField := 1;
								ELSIF (operands[addressOperand].displacement >= -8000H) & (operands[addressOperand].displacement < 8000H) THEN
									modField := 2;
								ELSE
									Error("value exceeds bounds");
									RETURN FALSE;
								END;

								CASE InstructionSet.RegisterIndex(operands[addressOperand].register) OF
								| RBX:
									IF operands[addressOperand].index = none THEN
										rmField := 7;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RSI THEN
										rmField := 0;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RDI THEN
										rmField := 1;
									ELSE
										ErrorSI("invalid effective address (4)", mnem,operands); RETURN FALSE;
									END
								| RBP:
									IF operands[addressOperand].index = none THEN
										rmField := 6;
										IF modField = 0 THEN modField := 1 END;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RSI THEN
										rmField := 2;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RDI THEN
										rmField := 3;
									ELSE
										ErrorSI("invalid effective address (5)", mnem,operands); RETURN FALSE;
									END
								| RSI:
									IF operands[addressOperand].index = none THEN
										rmField := 4;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RBX THEN
										rmField := 0;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RBP THEN
										rmField := 2;
									ELSE
										ErrorSI("invalid effective address (6)", mnem,operands); RETURN FALSE;
									END;
								| RDI:
									IF operands[addressOperand].index = none THEN
										rmField := 5;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RBX THEN
										rmField := 1;
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].index) = RBP THEN
										rmField := 3;
									ELSE
										ErrorSI("invalid effective address (7)", mnem,operands); RETURN FALSE;
									END;
								ELSE
									ErrorSI("invalid effective address (8)", mnem,operands); RETURN FALSE;
								END;

								ModRM (modField, regField, rmField);

								IF modField = 1 THEN
									code.PutByte (operands[addressOperand].displacement);
								ELSIF modField = 2 THEN
									code.PutWord (operands[addressOperand].displacement);
								END;
							END;
						ELSE (* cpuBits # 16 *)
							ASSERT(operands[addressOperand].type = mem);
							IF Trace THEN KernelLog.String(" cpuBits # 16 "); END;
							IF (operands[addressOperand].register= none) & (operands[addressOperand].index = none) THEN
								IF Trace THEN KernelLog.String(" no register, no index "); END;
								IF operands[addressOperand].scale # 1 THEN
									ErrorSI("invalid effective address (9)", mnem,operands); RETURN FALSE;
								END;
								IF cpuBits = bits64 THEN
									ModRM (0, regField, 4);
									SIB (0, 4, 5);
								ELSE
									ModRM (0, regField, 5);
								END;
								(* fixup must be 8bit wide for linker!
									IF lastPass & (operands[addressOperand].fixup # NIL) THEN
										AddFixup (operands[addressOperand].fixup, pc);
									END;
								*)
								IF lastPass & (operands[addressOperand].symbol.name # "") THEN
									 AddFixup(BinaryCode.Absolute,4,code.pc,operands[addressOperand].symbol, operands[addressOperand].symbolOffset,operands[addressOperand].displacement)
								END;
								code.PutDWord (operands[addressOperand].displacement);
							ELSE
								IF (operands[addressOperand].index # none) THEN
									(* index register available: must use SIB memory reference *)
									IF Trace THEN KernelLog.String(" index "); END;
									IF (InstructionSet.RegisterIndex(operands[addressOperand].index) = RSP) OR (InstructionSet.RegisterIndex(operands[addressOperand].index) = RIP) THEN
										ErrorSI("invalid effective address: unsupported stack / instruction pointer index", mnem,operands); RETURN FALSE;
									END;
									IF (operands[addressOperand].register# none) & (InstructionSet.RegisterIndex(operands[addressOperand].register) = RIP) THEN
										ErrorSI("invalid effective address: unsupported instruction base pointer with index", mnem,operands); RETURN FALSE;
									END;

									CASE operands[addressOperand].scale OF
									1: scaleField := 0;
									| 2: scaleField := 1;
									| 4: scaleField := 2;
									| 8: scaleField := 3;
									ELSE
										ErrorSI("invalid effective address (12)", mnem,operands); RETURN FALSE;
									END;

									rmField := 4; (* indicates usage of SIB byte *)
								ELSE
									(* no index register available *)
									IF Trace THEN KernelLog.String(" no index ") END;
									IF (operands[addressOperand].scale # 1) THEN
										ErrorSI("invalid effective address: scale without index register", mnem,operands); RETURN FALSE;
									END;
									IF operands[addressOperand].register = none THEN (* no index, no base *)
										rmField := 4; (* indicates usage of SIB byte *)
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].register) = RIP THEN
										rmField := 5; (* indicates usage of instruction pointer, must be followed by 32 bit displacement, modField must be 0 *)
									ELSIF InstructionSet.RegisterIndex(operands[addressOperand].register) MOD 8 = RSP THEN
										rmField := 4; (* indicates usage of SIB byte => stack pointer must be referenced in SIB byte *)
									ELSE
										rmField := InstructionSet.RegisterIndex(operands[addressOperand].register) MOD 8; (* any other register can be encoded via modRM field *)
									END;
								END;

								(* IF operands[addressOperand].fixup # NIL THEN
									modField := 2;
									mem fixups only for local variables and parameters
								*)
								IF operands[addressOperand].displacement = 0 THEN
									(* no displacement => modRM = 0 except for base pointer, which must be encoded with (zero) displacement *)
									IF Trace THEN KernelLog.String(" no displacement "); END;
									IF (operands[addressOperand].register # none) & (InstructionSet.RegisterIndex(operands[addressOperand].register) = RBP) THEN
										modField := 1;
									ELSIF  (operands[addressOperand].register # none) & (InstructionSet.RegisterIndex(operands[addressOperand].register) = R13) THEN
										modField := 1;
									ELSE
										modField := 0;
									END;
								ELSIF (operands[addressOperand].register = none) & (operands[addressOperand].index # none) THEN
									modField := 0; (* 32 bit displacement without base register encoded via SIB byte *)
								ELSIF (operands[addressOperand].register # none) & (InstructionSet.RegisterIndex(operands[addressOperand].register) = RIP) THEN
									(* if there is displacement on RIP, we still have to use the modRM = 0 case *)
									IF cpuBits = 64 THEN
										modField := 0;
									ELSE
										Error("invalid effective address: instruction pointer relative addressing only in 64 bit mode")
									END;
								ELSIF (operands[addressOperand].displacement >= -80H) & (operands[addressOperand].displacement < 80H) THEN
									(* 8 bit displacement *)
									modField := 1;
								ELSE
									(* 32 bit displacement *)
									modField := 2;
								END;

								ModRM (modField, regField, rmField);

								IF (rmField = 4) THEN (* must emit SIB encoding scale, index and base (operand.register --> base) *)
									IF operands[addressOperand].index # none THEN
										(* index register present *)
										indexField := InstructionSet.RegisterIndex(operands[addressOperand].index) MOD 8;
									ELSE
										(* no index register *)
										indexField := 4;
									END;

									IF operands[addressOperand].register# none THEN
										(* base register present, can also be the base pointer (5)  *)
										baseField := InstructionSet.RegisterIndex(operands[addressOperand].register) MOD 8;
									ELSE
										(* no register present *)
										debug := operands[addressOperand].register;
										ASSERT(modField = 0);
										baseField := 5;
									END;

									SIB (scaleField, indexField, baseField);
								END;

								IF modField = 0 THEN
									IF rmField = 5 THEN
										IF lastPass & (operands[addressOperand].symbol.name # "") THEN AddFixup(BinaryCode.Absolute,4,code.pc,operands[addressOperand].symbol,operands[addressOperand].symbolOffset,operands[addressOperand].displacement) END;
										code.PutDWord(operands[addressOperand].displacement);
									ELSIF (rmField = 4) & (baseField = 5) THEN (* special case: SIB without base register: mandatory displacement *)
										IF lastPass & (operands[addressOperand].symbol.name # "") THEN AddFixup(BinaryCode.Absolute,4,code.pc,operands[addressOperand].symbol,operands[addressOperand].symbolOffset,operands[addressOperand].displacement) END;
										code.PutDWord(operands[addressOperand].displacement);
									END;
								ELSIF modField = 1 THEN
									IF lastPass & (operands[addressOperand].symbol.name # "") THEN AddFixup(BinaryCode.Absolute,1,code.pc,operands[addressOperand].symbol,operands[addressOperand].symbolOffset,operands[addressOperand].displacement) END;
									code.PutByte(operands[addressOperand].displacement);
								ELSIF modField = 2 THEN
									IF lastPass & (operands[addressOperand].symbol.name # "") THEN AddFixup(BinaryCode.Absolute,4,code.pc,operands[addressOperand].symbol,operands[addressOperand].symbolOffset,operands[addressOperand].displacement) END;
									code.PutDWord (operands[addressOperand].displacement);
								END;
							END;
						END;

					| cb:
						IF Trace THEN KernelLog.String(" cb "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (operands[i].type = ioffset) THEN
								IF Trace THEN KernelLog.String(" ioffset "); END;
								offset := SHORT(operands[i].val - code.pc  - 1);
								IF lastPass & ~ValueInByteRange (offset) THEN
									Error( "value exceeds bounds");
									RETURN FALSE;
								END;
								operands[i].pc := code.pc;
								code.PutByte (offset);
								free[i] := FALSE; i:= maxNumberOperands;
							ELSIF (free[i]) & (operands[i].type = imm) THEN
								IF Trace THEN KernelLog.String(" imm  "); END;
								offset := SHORT (operands[i].val);
								IF lastPass & ~ValueInByteRange (offset) THEN
									Error( "value exceeds bounds");
									RETURN FALSE;
								END;
								operands[i].pc := code.pc;
								code.PutByte (offset);
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| cw:
						IF Trace THEN KernelLog.String(" cw "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (InstructionSet.instructions[instr].operands[i] = InstructionSet.rel16off) THEN
								offset := SHORT(operands[i].val - code.pc  - 2);
								IF lastPass & ~ValueInWordRange (offset) THEN
									Error( "value exceeds bounds");
								END;
								operands[i].pc := code.pc;
								code.PutWord (offset);
								free[i] := FALSE; i:= maxNumberOperands;
							ELSIF (free[i]) & InstructionSet.IsImmediate16(InstructionSet.instructions[instr].operands[i]) THEN
								offset := SHORT (operands[i].val);
								IF lastPass & ~ValueInWordRange (offset) THEN
									Error( "value exceeds bounds");
									RETURN FALSE;
								END;
								operands[i].pc := code.pc;
								code.PutWord (offset);
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| cd:
						IF Trace THEN KernelLog.String(" cd "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (InstructionSet.instructions[instr].operands[i] = InstructionSet.rel32off) THEN
								operands[i].pc := code.pc;

								IF lastPass & (operands[i].symbol.name # "") THEN
									AddFixup(BinaryCode.Relative,4,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement-4);
									code.PutDWord(SHORT(operands[i].val));
								ELSE
									code.PutDWord (SHORT (operands[i].val - code.pc  - 4));
								END;

								free[i] := FALSE; i:= maxNumberOperands;
							ELSIF (free[i]) & InstructionSet.IsImmediate32(InstructionSet.instructions[instr].operands[i])  THEN
								operands[i].pc := code.pc;

								IF lastPass & (operands[i].symbol.name # "") THEN
									AddFixup(BinaryCode.Absolute,4,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement);
								END;
								code.PutDWord (SHORT (operands[i].val));

								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| cp:
						IF Trace THEN KernelLog.String(" cp "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
					| ib:
						IF Trace THEN KernelLog.String(" ib "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (operands[i].type = imm) OR (operands[i].type = ioffset) THEN
								offset := SHORT (operands[i].val);
								IF FALSE & lastPass & ~ValueInByteRange (offset) THEN
									Error( "value exceeds bounds");
									RETURN FALSE;
								END;
								operands[i].pc := code.pc;

								IF lastPass & (operands[i].symbol.name # "") THEN  AddFixup(BinaryCode.Absolute,1,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement) END;

								code.PutByte (SHORT (operands[i].val));
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| iw:
						IF Trace THEN KernelLog.String(" iw "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (operands[i].type = imm) OR (operands[i].type = ioffset) THEN
								operands[i].pc := code.pc;
								code.PutWord (SHORT (operands[i].val));
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| id:
						IF Trace THEN KernelLog.String(" id "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (InstructionSet.instructions[instr].operands[i] = InstructionSet.rel32off) THEN
								operands[i].pc := code.pc;

								IF lastPass & (operands[i].symbol.name # "") THEN AddFixup(BinaryCode.Relative,4,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement-4)  END;

								code.PutDWord (SHORT (operands[i].val - code.pc - 4));
								free[i] := FALSE; i:= maxNumberOperands;
							ELSIF (free[i]) & InstructionSet.IsImmediate32(InstructionSet.instructions[instr].operands[i])  THEN
								operands[i].pc := code.pc;
								IF lastPass & (operands[i].symbol.name # "") THEN AddFixup(BinaryCode.Absolute,4,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement)  END;

								code.PutDWord (SHORT (operands[i].val));
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| iq:
						IF Trace THEN KernelLog.String(" iq "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & InstructionSet.IsImmediate64(InstructionSet.instructions[instr].operands[i])  THEN
								operands[i].pc := code.pc;
								IF lastPass & (operands[i].symbol.name # "") THEN
									 AddFixup(BinaryCode.Absolute,8,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement)
								END;
								code.PutQWord (operands[i].val);
								free[i] := FALSE; i:= maxNumberOperands;
							END
						END;
					| rb, rw, rd, rq:
						IF Trace THEN KernelLog.String(" r* "); END;
						regOperand := GetRegOperand ();
						val := val + InstructionSet.RegisterIndex(operands[regOperand].register) MOD 8;
						code.PutByte (val); val := -1;
						free[regOperand] := FALSE;
					| fpStackOperand:
						IF Trace THEN KernelLog.String(" fp "); END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (operands[i].type = sti) & (InstructionSet.instructions[instr].operands[i] # InstructionSet.st0) THEN
								val := val + InstructionSet.RegisterIndex(operands[i].register);
								code.PutByte (val); val := -1;
								free[i] := FALSE; i:= maxNumberOperands;
							END;
						END;
					| directMemoryOffset:
						IF Trace THEN KernelLog.String(" memoffset "); END;
						IF val # -1 THEN code.PutByte (val); val := -1 END;
						FOR i := 0 TO maxNumberOperands - 1 DO
							IF (free[i]) & (operands[i].type = mem) THEN
								IF cpuBits = bits16 THEN
									code.PutWord (operands[i].displacement);
								ELSE
									IF lastPass & (operands[i].symbol.name # "") THEN
										 AddFixup(BinaryCode.Absolute,4,code.pc,operands[i].symbol,operands[i].symbolOffset,operands[i].displacement)
									END;
									code.PutDWord (operands[i].displacement);
								END;
								free[i] := FALSE; i:= maxNumberOperands;
							END;
						END;
					| mem64Operand, mem128Operand: (* ignored *)
						IF Trace THEN KernelLog.String(" mem64/mem128 "); END;
					ELSE HALT(100) (* decoding error *)
					END;
				END;
				INC(oppos);
				IF Trace THEN KernelLog.Ln; END;
			END;
			IF val # -1 THEN code.PutByte (val) END;
			ASSERT(oppos < LEN(opcode)); (* decoding or representation error otherwise *)

			RETURN TRUE;
		END EmitInstruction;

		PROCEDURE EmitPrefix* (prefix: LONGINT);
		BEGIN code.PutByte (prefix);
		END EmitPrefix;

		PROCEDURE Emit*(mnem: LONGINT; VAR op1,op2,op3: Operand);
		VAR operands: ARRAY maxNumberOperands OF Operand; res: BOOLEAN;
		BEGIN
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			res := EmitInstruction(mnem,operands,TRUE);
			op1 := operands[0];
			op2 := operands[1];
			op3 := operands[2];
		END Emit;

		PROCEDURE EmitAt*(pc: LONGINT;mnem: LONGINT; VAR op1,op2,op3: Operand);
		VAR prevPC: LONGINT; prevDump: Streams.Writer;
		BEGIN
			prevDump := dump;
			dump := NIL;
			prevPC := code.pc;
			code.SetPC(pc);
			Emit(mnem,op1,op2,op3);
			code.SetPC(prevPC);
			dump := prevDump;
		END EmitAt;

		PROCEDURE StartEmitAt*(VAR pc: LONGINT): LONGINT;
		VAR prevPC: LONGINT;
		BEGIN
			prevPC := code.pc;
			dump := NIL;
			code.SetPC(pc);
			RETURN prevPC;
		END StartEmitAt;

		PROCEDURE EndEmitAt*(pc: LONGINT);
		BEGIN
			code.SetPC(pc);
			SELF.dump := code.comments;
		END EndEmitAt;

		PROCEDURE Emit0* (mnem: LONGINT);
		VAR noOperand: Operand;
		BEGIN
			noOperand.type := none;
			Emit(mnem,noOperand,noOperand,noOperand);
		END Emit0;

		PROCEDURE Emit1* (mnem: LONGINT; VAR op1: Operand);
		VAR noOperand: Operand;
		BEGIN
			noOperand.type := none;
			Emit(mnem,op1,noOperand,noOperand);
		END Emit1;

		PROCEDURE Emit2* (mnem: LONGINT; VAR op1, op2: Operand);
		VAR noOperand: Operand;
		BEGIN
			noOperand.type := none;
			Emit(mnem,op1,op2,noOperand);
		END Emit2;

		PROCEDURE Emit3* (mnem: LONGINT; VAR  op1, op2, op3: Operand);
		BEGIN
			Emit(mnem,op1,op2,op3);
		END Emit3;

	END Emitter;

	RegisterMapEntry*= POINTER TO RECORD
		name-: Strings.String;
		register-: LONGINT;
		next: RegisterMapEntry;
	END;

	RegisterMap*= OBJECT
	VAR first: RegisterMapEntry;

		PROCEDURE & Init *;
		BEGIN
			first := NIL
		END Init;

		PROCEDURE Find*(CONST name: ARRAY OF CHAR): LONGINT;
		VAR map: RegisterMapEntry;
		BEGIN
			map := first;
			WHILE (map # NIL) & (map.name^#name) DO map := map.next END;
			IF map = NIL THEN RETURN InstructionSet.none ELSE RETURN map.register END;
		END Find;

		PROCEDURE Add*(name: Strings.String; register: LONGINT);
		VAR map: RegisterMapEntry;
		BEGIN
			NEW(map); map.name := name; map.register := register;
			map.next := first; first := map;
		END Add;

	END RegisterMap;

	Assembly* = OBJECT
	VAR
		(* output *)
		errPos: LONGINT;
		error-: BOOLEAN;
		emitter: Emitter;

		(* overal state *)
		diagnostics: Diagnostics.Diagnostics;
		dump: Streams.Writer;

		(* temporaries *)
		fixup: BinaryCode.Fixup;
		type: SHORTINT;
		currentFixup: Sections.SectionName;
		currentLabel: NamedLabel;
		sourceName: Basic.FileName;

		PROCEDURE & InitAssembly*(diagnostics: Diagnostics.Diagnostics; emit: Emitter);
		BEGIN
			SELF.diagnostics := diagnostics;
			errPos := Diagnostics.Invalid;
			error := FALSE;
			SELF.emitter := emit;
			sourceName := "";
		END InitAssembly;

		PROCEDURE Error( CONST message: ARRAY OF CHAR);
		VAR pos: LONGINT; msg,name: ARRAY 256 OF CHAR;
		BEGIN
			pos := errPos;
			IF (pos = Diagnostics.Invalid) OR (sourceName = "") THEN
				COPY(message,msg);
				Strings.Append(msg," in ");
				ObjectFile.SegmentedNameToString(emitter.code.os.identifier.name, name);
				Strings.Append(msg, name);
				diagnostics.Error(sourceName,errPos,Diagnostics.Invalid,msg);
			ELSE
				diagnostics.Error(sourceName,errPos,Diagnostics.Invalid,message);
			END;
			error := TRUE;
			IF dump # NIL THEN dump.Update; END;
		END Error;

		PROCEDURE ErrorSS(CONST msg1,msg2: ARRAY OF CHAR);
		VAR message: ARRAY 256 OF CHAR;
		BEGIN
			COPY(msg1,message);
			Strings.Append(message," : ");
			Strings.Append(message, msg2);
			Error(message);
		END ErrorSS;


		PROCEDURE Assemble* (reader: Streams.Reader;  orgPos: LONGINT; scope: SyntaxTree.Scope; in: IntermediateCode.Section; out: IntermediateCode.Section; module: Sections.Module; exported, inlined: BOOLEAN;
			map: RegisterMap
		);
		CONST maxPasses = 2;
		VAR
			symbol, reg: LONGINT;
			ident, idents: Name;
			val, times, val2, val3: LONGINT;

			currentLabel: NamedLabel;
			labels: NamedLabelList;

			prevPC: LONGINT;
			pass: LONGINT;
			absoluteMode: BOOLEAN;
			absoluteOffset: LONGINT;
			alignment: LONGINT;
			orgOffset: LONGINT;
			char: CHAR;
			orgReaderPos: LONGINT;
			orgCodePos: LONGINT;
			prevSourceName: Basic.FileName;
			position: LONGINT;
			prevCpuBits: Size;
			prevCpuOptions: InstructionSet.CPUOptions;

			PROCEDURE NextChar;
			BEGIN
				(*
				IF (dump # NIL) & (pass = maxPasses) THEN dump.Char (char) END;
				*)
				reader.Char(char); INC(position);
			END NextChar;

			PROCEDURE SkipBlanks;
			BEGIN
				(* tf returns 01X when an embedded object is encountered *)
				WHILE (char = SPACE) OR (char = TAB) OR (char = 01X) DO NextChar END;
				IF char = ";" THEN
					WHILE (char # CR) & (char # LF) & (char # 0X) DO NextChar END	(* Skip comments *)
				END;
			END SkipBlanks;

			PROCEDURE GetNumber (VAR intval: LONGINT);
			VAR i, m, n: INTEGER; dig: ARRAY 24 OF CHAR;
			BEGIN
				i := 0; m := 0; n := 0;
				WHILE ('0' <= char) & (char <= '9') OR ('A' <= CAP (char)) & (CAP (char) <= 'F') DO
					IF  (m > 0) OR (char # "0") THEN (* ignore leading zeros *)
						IF n < LEN(dig) THEN dig[n] := char; INC(n) END;
						INC(m)
					END;
					NextChar; INC(i)
				END;

				IF n = m THEN intval := 0; i := 0;
					IF (CAP (char) = "H") OR (char = "X") THEN NextChar;
						IF (n = Scanner.MaxHexDigits) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
						WHILE i < n DO intval := intval * 10H + HexOrd (dig[i]); INC(i) END;
					ELSE
						IF (n = Scanner.MaxHugeHexDigits) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
						WHILE i < n DO intval := intval * 10 + Ord (dig[i]); INC(i) END
					END
				END;
			END GetNumber;

			PROCEDURE GetIdentifier;
			VAR i: LONGINT;
			BEGIN
				i := 0;
				REPEAT
					IF i < Scanner.MaxIdentifierLength - 1 THEN
						IF ('0' <= char) & (char <= '9') THEN
							ident[i] := char; idents[i] := char;
						ELSE
							ident[i] := (* CAP *) (char); idents[i] := char; END;
						INC (i);
					END;
					NextChar
				UNTIL ~( ('A' <= CAP(char)) & (CAP(char) <= 'Z') OR ('0' <= char) & (char <= '9') OR (char = '_') );
				ident[i] := 0X; idents[i] := 0X;
			END GetIdentifier;

			PROCEDURE GetString;
			VAR i: LONGINT;
			BEGIN
				i := 0;
				NextChar;
				WHILE (char # "'") & (i < Scanner.MaxIdentifierLength - 1) DO
					ident[i] := char; INC (i);
					NextChar;
				END;
				ident[i] := 0X;
				NextChar;
			END GetString;

			PROCEDURE NextSymbol;
			BEGIN
				SkipBlanks;
				errPos := position- 1;

				CASE char OF
				'A' .. 'Z', 'a' .. 'z', '_' :
					GetIdentifier;
					SkipBlanks;
					IF char = ':' THEN
						NextChar; symbol := symLabel;
					ELSE
						symbol := symIdent;
					END;
				| '0' .. '9':
					GetNumber (val);
					symbol := symNumber;
				| "'": GetString;
					symbol := symString;
				| '.': symbol := symPeriod;
					NextChar;
				| ';': symbol := symSemicolon;
					NextChar;
				| ':': symbol := symColon;
					NextChar;
				| CR, LF: symbol := symLn;
					NextChar;
				| ',': symbol := symComma;
					NextChar;
				| '+': symbol := symPlus;
					NextChar;
				| '-': symbol := symMinus;
					NextChar;
				| '*': symbol := symTimes;
					NextChar;
				| '/': symbol := symDiv;
					NextChar;
				| '%': symbol := symMod;
					NextChar;
				| '~': symbol := symNegate;
					NextChar;
				| '(': symbol := symLParen;
					NextChar;
				| ')': symbol := symRParen;
					NextChar;
				| '[': symbol := symLBraket;
					NextChar;
				| ']': symbol := symRBraket;
					NextChar;
				| '{': symbol := symLBrace;
					NextChar;
				| '}': symbol := symRBrace;
					NextChar;
				| '@': symbol := symAt;
					NextChar;
				| '$': NextChar;
					IF char = '$' THEN
						symbol := symPCOffset; NextChar;
					ELSE
						symbol := symPC;
					END
				| 0X: symbol := symEnd;
				ELSE
					symbol := symNone;
					NextChar;
				END;
			END NextSymbol;

			PROCEDURE SkipLine;
			BEGIN
				WHILE (symbol # symLn) & (symbol # symNone) DO
					NextSymbol;
				END;
			END SkipLine;

			PROCEDURE Ensure (desiredSymbol, errNumber : LONGINT) : BOOLEAN;
			VAR temp: LONGINT;
			BEGIN
				temp := symbol;
				IF symbol = desiredSymbol THEN
					NextSymbol;
					RETURN TRUE;
				ELSE
					Error("other symbol expected");
					RETURN FALSE;
				END;
			END Ensure;


			PROCEDURE GetCPU (cumulateOptions: BOOLEAN): BOOLEAN;
			VAR i: LONGINT;
			BEGIN
				SkipBlanks;
				GetIdentifier;
				Strings.UpperCase(ident);
				i := InstructionSet.FindCPU (ident);
				IF i # InstructionSet.none THEN
					IF cumulateOptions THEN
						emitter.cpuOptions := emitter.cpuOptions + InstructionSet.cpus[i].cpuOptions;
					ELSE
						emitter.cpuOptions := InstructionSet.cpus[i].cpuOptions + InstructionSet.cpuOptions;
					END;
					NextSymbol;
					RETURN TRUE;
				ELSE
					ErrorSS ("cpu unknown",ident);
					emitter.cpuOptions := prevCpuOptions;
					RETURN FALSE;
				END;

			END GetCPU;


			PROCEDURE Factor (VAR x: LONGINT; critical: BOOLEAN; VAR type: SHORTINT): BOOLEAN;
			VAR label: NamedLabel; l: LONGINT;
			BEGIN
				IF symbol = symNumber THEN
					x := val; NextSymbol; RETURN TRUE;
				ELSIF symbol = symPC THEN
					x := (orgOffset + emitter.code.pc ); NextSymbol; RETURN TRUE;
				ELSIF symbol = symPCOffset THEN
					x := orgOffset; NextSymbol; RETURN TRUE;
				ELSIF symbol = symString THEN
					x := 0; l := Strings.Length (ident);
					IF l > 0 THEN INC (x, ORD (ident [0])) END;
					IF l > 1 THEN INC (x, ORD (ident [1])*100H) END;
					IF l > 2 THEN INC (x, ORD (ident [2])*10000H) END;
					IF l > 3 THEN INC (x, ORD (ident [3])*1000000H) END;
					NextSymbol; RETURN TRUE;
				ELSIF symbol = symIdent THEN
					label := labels.Find (idents);
					NextSymbol;
					IF label # NIL THEN
						x := (label.offset );
						type := ioffset;
						currentLabel := label;
						(*
						IF x = MAX(LONGINT) THEN
							x := -label.index;
							currentFixup := in;
						END;
						*)
						RETURN TRUE;
					ELSIF scope # NIL THEN
						IF ~GetValue(idents,x) THEN
							IF  (pass = maxPasses) THEN
								Error("constant expected");
							END;
							RETURN FALSE;
						ELSE
							RETURN TRUE;
						END
					END;

					IF (~critical) & (pass # maxPasses) THEN
						x := 0;
						RETURN TRUE
					END;

					Error("undefined symbol");
					RETURN FALSE;

				ELSIF symbol = symLParen  THEN
					NextSymbol;
					RETURN Expression (x, critical,type) & Ensure (symRParen, 555);
				END;

				Error("parse error in expression");
				RETURN FALSE
			END Factor;

			PROCEDURE Term (VAR x: LONGINT; critical: BOOLEAN; VAR type: SHORTINT): BOOLEAN;
			VAR y, op : LONGINT;
			BEGIN
				IF Factor (x, critical,type) THEN
					WHILE (symbol = symTimes) OR (symbol = symDiv) OR (symbol = symMod) DO
						op := symbol; NextSymbol;
						IF Factor (y, critical,type) THEN
							IF op = symTimes THEN x := x * y
							ELSIF op = symDiv THEN x := x DIV y
							ELSE x := x MOD y
							END;
						ELSE
							RETURN FALSE;
						END;
					END;
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			END Term;

			PROCEDURE Expression (VAR x: LONGINT; critical: BOOLEAN; VAR type: SHORTINT): BOOLEAN;
			VAR y, op : LONGINT;
			BEGIN
				IF symbol = symMinus THEN
					op := symbol; NextSymbol;
					IF Term (x, critical,type) THEN
						x := -x
					ELSE
						RETURN FALSE;
					END;
				ELSIF symbol = symPlus THEN
					op := symbol; NextSymbol;
					IF ~Term (x, critical,type) THEN
						RETURN FALSE;
					END;
				ELSIF symbol = symNegate THEN
					op := symbol; NextSymbol;
					IF Term (x, critical,type) THEN
						x := -x - 1
					ELSE
						RETURN FALSE;
					END;
				ELSIF ~Term (x, critical,type) THEN
					RETURN FALSE;
				END;
				WHILE (symbol = symPlus) OR (symbol = symMinus) DO
					op := symbol; NextSymbol;
					IF Term (y, critical,type) THEN
						IF op = symPlus THEN x := x + y ELSE x := x - y END;
					ELSE
						RETURN FALSE;
					END;
				END;
				RETURN TRUE;
			END Expression;

			PROCEDURE Align(size: LONGINT);
			VAR pc: LONGINT;
			BEGIN
				IF size <= 0 THEN Error("invalid alignment size"); RETURN END;
				pc := emitter.code.pc DIV 8; (* bytes *)
				WHILE pc MOD size # 0 DO
					emitter.code.PutByte(0); 
					INC(pc);
				END;
			END Align;
			

			PROCEDURE PutData (size: Size): BOOLEAN;
			VAR i: LONGINT; type:SHORTINT; ofs: Operand;
			BEGIN
				NextSymbol;

				WHILE symbol # symLn DO

					IF symbol = symString THEN
						i := 0;
						WHILE ident[i] # 0X DO
							emitter.code.PutByte (ORD (ident[i]));
							INC (i);
						END;
						IF size # bits8 THEN
							i := (size ) - i MOD (size );
							WHILE i # 0 DO emitter.code.PutByte (0); DEC (i) END;
						END;
						NextSymbol;
					ELSIF (scope # NIL) & (symbol = symAt) THEN
						NextSymbol;
						IF symbol # symIdent THEN Error("identifier missing") END;
						GetOffsetFixup (idents, ofs);
						NextSymbol;
						IF symbol = symPlus THEN
							NextSymbol;
							IF Expression(i, FALSE, type) THEN
								ofs.displacement := i
							END;
						ELSIF symbol = symMinus THEN
							NextSymbol;
							IF Expression(i, FALSE, type) THEN
								ofs.displacement := - i
							END;
						END;
						IF pass = maxPasses THEN
							emitter.AddFixup(BinaryCode.Absolute, ofs.sizeInBytes, emitter.code.pc, ofs.symbol, ofs.symbolOffset,ofs.displacement);
						END;
						emitter.code.PutBytes (0, size );
					ELSIF Expression (i, FALSE,type) THEN
						emitter.code.PutBytes (i, size );
					ELSE
						RETURN FALSE;
					END;
					IF symbol = symComma THEN
						NextSymbol;
					ELSIF symbol # symLn THEN
						Error("operand missing");
					END
				END;
				Duplicate ((emitter.code.pc - prevPC) , NIL);
				RETURN TRUE;
			END PutData;

			PROCEDURE Duplicate (size: LONGINT; fixup: BinaryCode.Fixup);
			VAR i: LONGINT; buffer: ARRAY 100 OF CHAR; pc: LONGINT;
			BEGIN
				IF times = 1 THEN RETURN END;

				pc := (prevPC );

				IF (dump # NIL) & (pass = maxPasses) THEN dump.Hex (emitter.code.pc, 1); dump.Char (' ') END;
				FOR i := 0 TO size - 1 DO
					buffer[i] := emitter.code.GetByte (pc); INC(pc);
					IF (dump # NIL) & (pass = maxPasses) THEN dump.Hex (ORD (buffer[i]), -2); END;
				END;
				pc := (prevPC );

				IF times > 1 THEN
					WHILE times # 1 DO
						IF fixup # NIL THEN
							HALT(200);
							(*!!
							AddFixup (fixup.adr, pc + fixup.offset - prevPC);
							*)
						END;
						FOR i := 0 TO size - 1 DO
							emitter.code.PutByteAt (pc, ORD (buffer[i])); INC(pc);
							IF (dump # NIL) & (pass = maxPasses) THEN dump.Hex (ORD (buffer[i]), -2); END;
						END;
						DEC (times);
					END;
				ELSE
					times := 1;
				END;

				IF (dump # NIL) & (pass = maxPasses) THEN dump.Ln END;
			END Duplicate;

			PROCEDURE Reserve (size: Size) : BOOLEAN;
			VAR type : SHORTINT;
			BEGIN
				IF Expression (val2, TRUE, type) THEN
					absoluteOffset := absoluteOffset + val2 * size;
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			END Reserve;

			PROCEDURE GetScopeSymbol (CONST ident: ARRAY OF CHAR): SyntaxTree.Symbol;
			VAR sym: SyntaxTree.Symbol; localScope: SyntaxTree.Scope;  identifier: SyntaxTree.Identifier;
			BEGIN
				localScope := scope;
				identifier := SyntaxTree.NewIdentifier(ident);
				IF Trace THEN KernelLog.String("GetScopeSymbol:"); KernelLog.String(ident); KernelLog.Ln; END;
				WHILE (sym = NIL) & (localScope # NIL) DO
					sym := localScope.FindSymbol(identifier);
					localScope := localScope.outerScope
				END;

				IF (sym # NIL) & (sym IS SyntaxTree.Import)  THEN
					NextSymbol;
					IF Ensure(symPeriod,0) & (symbol = symIdent) THEN
						identifier := SyntaxTree.NewIdentifier(idents);
						IF Trace THEN KernelLog.String("GetScopeSymbol  :"); KernelLog.String(idents); KernelLog.Ln; END;
						localScope := sym(SyntaxTree.Import).module.moduleScope;
						sym := NIL;
						WHILE (sym = NIL) & (localScope # NIL) DO
							sym := localScope.FindSymbol(identifier);
							localScope := localScope.outerScope
						END;
					END;
				END;
				IF Trace THEN IF sym = NIL THEN KernelLog.String("not found") ELSE KernelLog.String("found"); END; KernelLog.Ln; END;
				RETURN sym
			END GetScopeSymbol;

			PROCEDURE GetValue(CONST ident: ARRAY OF CHAR; VAR x: LONGINT): BOOLEAN;
			VAR scopeSymbol:SyntaxTree.Symbol;
			BEGIN
				scopeSymbol := GetScopeSymbol (ident);
				IF scopeSymbol = NIL THEN RETURN FALSE
				ELSIF ~(scopeSymbol IS SyntaxTree.Constant) THEN RETURN FALSE
				ELSE
					IF (scopeSymbol.type.resolved IS SyntaxTree.CharacterType) & (scopeSymbol.type.resolved.sizeInBits=8)  THEN
						x := ORD(scopeSymbol(SyntaxTree.Constant).value.resolved(SyntaxTree.CharacterValue).value)
					ELSIF scopeSymbol.type.resolved IS SyntaxTree.IntegerType THEN
						x := scopeSymbol(SyntaxTree.Constant).value.resolved(SyntaxTree.IntegerValue).value
					ELSE
						Error("number expected");
						RETURN FALSE;
					END;
					RETURN TRUE;
				END;
			END GetValue;


			PROCEDURE GetMemFixup (CONST ident: ARRAY OF CHAR; VAR operand: Operand);
			VAR scopeSymbol:SyntaxTree.Symbol;
			BEGIN
				scopeSymbol := GetScopeSymbol (ident);
				IF scopeSymbol = NIL THEN RETURN END;

				IF scopeSymbol IS SyntaxTree.Constant THEN
					RETURN
				END;

				IF inlined & exported THEN
					Error("no symbols may be accessed in exported and inlined procedures");
				END;

				IF  (scopeSymbol IS SyntaxTree.Variable) & (scopeSymbol.scope = module.module.moduleScope) THEN (* global variable. offset not supported *)
					Error("global variables cannot be accessed as memory operands");
				ELSIF (scopeSymbol IS SyntaxTree.Variable) THEN (* local variable *)
					operand.displacement := (scopeSymbol.offsetInBits DIV 8)
				ELSIF (scopeSymbol IS SyntaxTree.Parameter) THEN (* local parameter *)
					operand.displacement := (scopeSymbol.offsetInBits DIV 8)
				ELSE
					RETURN (* ? *)
				END;
				(*! mem.fixup := scopeSymbol.adr; *)
				NextSymbol;
			END GetMemFixup;

			PROCEDURE GetOffsetFixup (CONST ident: ARRAY OF CHAR; VAR operand: Operand);
			VAR scopeSymbol: SyntaxTree.Symbol;name: Basic.SegmentedName; symbol: IntermediateCode.Section;
			BEGIN
				IF labels.Find(ident) # NIL THEN RETURN END;
				scopeSymbol := GetScopeSymbol (ident);
				IF (scopeSymbol = NIL) OR (scopeSymbol IS SyntaxTree.Constant) THEN RETURN END;

				IF inlined & exported THEN
					Error("no symbols may be accessed in exported and inlined procedures");
				END;

				Global.GetSymbolSegmentedName(scopeSymbol,name);
				IF scopeSymbol.scope IS SyntaxTree.ModuleScope THEN
					IF (scopeSymbol IS SyntaxTree.Variable) THEN
						InitMem(operand,IntermediateCode.Bits32,none,0); (* or immediate ?? *)
					ELSIF (scopeSymbol IS SyntaxTree.Procedure) & (scopeSymbol.scope = module.module.moduleScope) THEN
						IF scopeSymbol(SyntaxTree.Procedure).isInline THEN
							Error("fobidden reference to inline call");
						ELSE
							InitOffset32(operand,0); (* or immediate ?? *)
						END;
					ELSIF (scopeSymbol IS SyntaxTree.Procedure) THEN
						InitOffset32(operand,0); (* or immediate ?? *)
					END;
					SetSymbol(operand,name,0,0,0);
				ELSE
					Error("direct access to local variable offset forbidden");
				END;
				operand.sizeInBytes := emitter.cpuBits;
			END GetOffsetFixup;

			(* the following procedure is used to adapt sizes for relative jumps *)
			PROCEDURE AdaptOperandSizes(VAR operands: ARRAY OF Operand);
			VAR i: LONGINT;


				PROCEDURE OffsetSize(val: HUGEINT): SHORTINT;
				BEGIN
					DEC(val,emitter.code.pc);
					IF (val > MIN(SHORTINT)+2) & (val < MAX(SHORTINT)) THEN
						RETURN bits8
					(* We do not support word (16-bit) displacement jumps
					(i.e. prefixing the jump instruction with the `addr16' opcode prefix),
					since the 80386 insists upon masking `%eip' to 16 bits after the word
					displacement is added. *)
					ELSIF (val > MIN(LONGINT)+2) & (val < MAX(LONGINT)-2) THEN
						RETURN bits32
					ELSE
						RETURN bits64
					END;

				END OffsetSize;

			BEGIN
				i := 0;
				WHILE (i< LEN(operands)) & (operands[i].type # none) DO
					IF (operands[i].type = ioffset) & (operands[i].sizeInBytes = bitsDefault)
					THEN
						IF operands[i].symbol.name = "" THEN
							operands[i].sizeInBytes := OffsetSize(operands[i].val);
						ELSE
							operands[i].sizeInBytes := bits32
						END;
					END;
					INC(i)
				END;
			END AdaptOperandSizes;

			PROCEDURE GetInstruction (): BOOLEAN;
			VAR
				mnem, opCount: LONGINT;
				size: Size;
				operands: ARRAY InstructionSet.maxNumberOperands OF Operand;
				prevFixup: BinaryCode.Fixup;
				mem: Operand;
				offset: Operand;
				i: LONGINT;
				type: SHORTINT;
			BEGIN
				mnem := InstructionSet.FindMnemonic (ident);
				IF mnem = InstructionSet.none THEN
					ErrorSS("unkown instruction",idents);
					RETURN FALSE;
				END;

				opCount := 0;
				NextSymbol;

				FOR i := 0 TO LEN(operands)-1 DO
					InitOperand(operands[i]);
				END;

				WHILE (symbol # symLn) & (symbol # symNone) & (symbol # symEnd) DO

					IF symbol = symIdent THEN
						IF (ident = "BYTE") OR (ident = "SHORT") THEN
							size := bits8; NextSymbol;
						ELSIF (ident = "WORD") OR (ident = "NEAR") THEN
							size := bits16; NextSymbol;
						ELSIF ident = "DWORD" THEN
							size := bits32; NextSymbol;
						ELSIF ident = "QWORD" THEN
							size := bits64; NextSymbol;
						ELSIF ident = "TWORD" THEN
							size := bits128; NextSymbol;
						ELSE
							size := bitsDefault;
						END;
					ELSE
						size := bitsDefault;
					END;

					IF symbol = symIdent THEN (* register ?, for example EAX *)
						reg := InstructionSet.FindRegister (ident);
						IF reg = InstructionSet.none THEN
							reg := map.Find(ident)
						END;
						IF reg # InstructionSet.none THEN
							IF size # bitsDefault THEN
								Error ("invalid register size specification"); RETURN FALSE;
							END;
							InitRegister(operands[opCount], reg);
							INC (opCount);
							NextSymbol;
						END;
					ELSE
						reg := InstructionSet.none;
					END;

					IF reg = InstructionSet.none THEN
						IF symbol = symLBraket THEN
							(* mem, written as [....] *)
							NextSymbol;

							InitMem(mem, size, InstructionSet.none,0); (*! ??? *)

							IF symbol = symLabel THEN (* register segment as in [ES:...] *)
								reg := InstructionSet.FindRegister (ident);
								IF reg = InstructionSet.none THEN
									ErrorSS("undefined symbol",idents);
									RETURN FALSE;
								END;
								mem.segment := reg;
								NextSymbol;
							END;

							IF symbol = symIdent THEN (* register, for example [EAX] or [ES:EAX] *)
								reg := InstructionSet.FindRegister (ident);
								IF reg # InstructionSet.none THEN
									mem.register := reg;
									NextSymbol;

									IF symbol = symTimes THEN (* register multiply as in [EAX*4] *)
										NextSymbol;
										IF ~Factor (mem.scale, FALSE,type) THEN
											RETURN FALSE;
										END;
										mem.index := mem.register;
										mem.register :=  InstructionSet.none;
									END;
									IF symbol = symPlus THEN (* register add as in [EAX + EBX]  *)
										NextSymbol;
										IF symbol = symIdent THEN
											reg := InstructionSet.FindRegister (ident);
											IF reg # InstructionSet.none THEN (* maybe it is this: [EAX + EBX * 4] *)
												NextSymbol;
												IF mem.index = InstructionSet.none THEN
													mem.index := reg;
													IF symbol = symTimes THEN
														NextSymbol;
														IF ~Factor (mem.scale, FALSE,type) THEN
															RETURN FALSE;
														END;
													END;
												ELSE
													mem.register := reg;
												END;
											END;
										END;
									END;
								END;
							END;

							IF symbol = symPlus THEN
								NextSymbol;
							END;

							IF (scope # NIL) & (symbol = symIdent) THEN
								GetMemFixup (idents, mem);
							END;

							IF (symbol # symRBraket) & (symbol # symNegate) THEN
								val2 := 0;
								IF ~Expression (val2, FALSE ,type) THEN
									RETURN FALSE;
								END;
								INC (mem.displacement, val2);
							ELSIF (mem.register = InstructionSet.none) & (mem.index = InstructionSet.none)  THEN
								Error("operand missing: no register provided");
								RETURN FALSE;
							END;

							operands[opCount] := mem;
							INC (opCount);


							IF ~Ensure (symRBraket, 556) THEN
								RETURN FALSE;
							END;
						ELSE
							(* number or identifier (symbol) *)
						InitImm(offset,size,0);

							IF (scope # NIL) & (symbol = symIdent) THEN (* identifier: must be a symbol *)
								GetOffsetFixup (idents, offset);
							END;


							IF offset.symbol.name = "" THEN (* nothing could be fixuped, must be a number / constant *)
								type := offset.type; currentFixup := ""; currentLabel := NIL;
								IF ~Expression (val2, FALSE,type) THEN
									RETURN FALSE;
								ELSE
									offset.type := type;
									IF currentFixup # "" THEN
										offset.symbol.name := currentFixup; offset.symbolOffset := val2;
									ELSIF currentLabel # NIL THEN
										IF (offset.sizeInBytes = bitsDefault ) & (val2 > emitter.code.pc) THEN (* forward jump *)
											offset.sizeInBytes := bits32
										END;

										(*
										IF offset.sizeInBytes = bitsDefault THEN
											offset.sizeInBytes := bits32;
										END;
										*)
									END;
								END;
								offset.val := val2;
								IF symbol = symColon THEN (* additional prefixed operand separated by ":", segmentation register *)
									NextSymbol;
									IF ~Expression (val3, FALSE, type) THEN
										RETURN FALSE;
									END;
									InitOffset(operands[opCount],bitsDefault,val3);
									INC (opCount);
								END;
							ELSE
								NextSymbol;
							END;
							operands[opCount] := offset;
							INC (opCount);
						END;
					END;

					IF symbol = symComma THEN
						NextSymbol;
					ELSIF (symbol # symLn) & (symbol # symEnd) THEN
						Error("operand missing");
					END
				END;

				prevFixup := fixup;

				AdaptOperandSizes(operands);

				IF ~emitter.EmitInstruction (mnem, operands, pass = maxPasses) THEN
					RETURN FALSE;
				END;

				IF fixup = prevFixup THEN
					Duplicate ((emitter.code.pc - prevPC) , NIL);
				ELSE
					Duplicate ((emitter.code.pc - prevPC) , fixup);
				END;

				RETURN TRUE;
			END GetInstruction;

			PROCEDURE Reset;
			BEGIN
				position := orgPos;
				reader.SetPos(orgReaderPos);
				emitter.code.SetPC(orgCodePos);
				NextChar;
			END Reset;

			PROCEDURE FindLabels;
			VAR firstInLine : BOOLEAN; label: NamedLabel;
			BEGIN
				IF Trace THEN	KernelLog.String("find labels"); KernelLog.Ln; END;
				LOOP
					NextSymbol;
					IF symbol = symLn THEN
						firstInLine := TRUE;
					ELSIF symbol = symLabel THEN
						IF firstInLine THEN
							IF labels.Find(idents) # NIL THEN
								Error("multiply declared identifier")
							ELSE
								NEW(label,MAX(LONGINT),idents);
								labels.Add(label);
								IF Trace THEN	KernelLog.String("found label"); KernelLog.String(idents); KernelLog.Ln; END;
							END
						END;
					ELSIF symbol = symEnd THEN
						EXIT
					ELSE
						firstInLine := FALSE;
					END;
				END;

			END FindLabels;

			PROCEDURE FixupLabels;
			VAR label: NamedLabel;
			BEGIN
				IF Trace THEN KernelLog.String("patch fixups "); KernelLog.Ln; END;
				fixup := emitter.code.fixupList.firstFixup;
				WHILE fixup # NIL DO
					IF (fixup.symbol.name = in.name) & (fixup.symbolOffset < 0) THEN
						label := labels.first;
						WHILE (label # NIL) & (label.index # -fixup.symbolOffset) DO label := label.nextNamedLabel END;
						(*
						fixup.SetSymbolOffset(label.offset);
						*)
						fixup.SetSymbol(out.name,0,0,label.offset+fixup.displacement);
						IF Trace THEN
							KernelLog.String("patch fixup: ");
							KernelLog.Hex(fixup.offset,1); KernelLog.String(" "); KernelLog.Hex(-fixup.displacement, 1);
							KernelLog.String(" "); KernelLog.Hex(label.offset, 1); KernelLog.Ln;
						END;
					END;
					fixup := fixup.nextFixup;
				END;
			END FixupLabels;

		BEGIN
			prevSourceName := sourceName;
			prevCpuBits := emitter.cpuBits;
			prevCpuOptions := emitter.cpuOptions;

			IF scope # NIL THEN
				sourceName := scope.ownerModule.sourceName;
			END;
			NEW(labels);
			orgReaderPos := reader.Pos();
			orgCodePos := emitter.code.pc;
			NextChar;

			(* first we have to find all labels as their names might collide with symbol names *)
			FindLabels;

			FOR pass := 1 TO maxPasses DO (*! currently  maxPasses = 1 *)
				Reset;
				times := 1;
				prevPC := emitter.code.pc;
				currentLabel := NIL;
				absoluteMode := FALSE;
				orgOffset := 0;

				NextSymbol;

				IF (scope # NIL) THEN
					IF symbol #  symLBrace THEN
						(* treat CPU options as an optional limitation and not vice versa *)
					ELSE
						emitter.cpuOptions := {};
						NextSymbol;

						(* parse code flags such as {SYSTEM.i386 .... } *)
						LOOP
							IF ~Ensure (symIdent, 551) THEN
								RETURN
							END;
							IF ident # "SYSTEM" THEN
								Error("unsupported target identifier");
								RETURN
							END;
							IF symbol # symPeriod THEN
								Error("identifier expected");
								RETURN;
							END;
							IF ~GetCPU (TRUE) THEN
								RETURN;
							END;

							IF symbol = symRBrace THEN
								EXIT
							ELSIF symbol = symComma THEN
								NextSymbol
							ELSE
								Error("target specifier expected");
								RETURN;
							END;
						END;
						NextSymbol;
					END
				END;

				LOOP
					IF symbol = symLn THEN
						NextSymbol;
					ELSIF symbol = symLabel THEN
						currentLabel := labels.Find(idents);
						ASSERT(currentLabel # NIL);
						IF absoluteMode THEN
							currentLabel.SetOffset(absoluteOffset);
						ELSE
							currentLabel.SetOffset(emitter.code.pc)
						END;
						NextSymbol;
					ELSIF symbol = symIdent THEN
						IF ident = "END" THEN
							symbol := symNone;
						ELSIF ident = "BITS" THEN
							NextSymbol;
							IF ~Ensure (symNumber, 553) OR ~emitter.SetBits (val) THEN
								SkipLine;
							ELSE
								NextSymbol;
							END;
						ELSIF ident = "ALIGN" THEN
							NextSymbol;
							IF Expression(alignment, TRUE, type) THEN
								Align(alignment);
							END;
						ELSIF ~(scope # NIL) & (ident = "CPU") THEN
							IF ~GetCPU (FALSE) THEN
								SkipLine;
							END;
						ELSIF ~(scope # NIL) & (ident = "ABSOLUTE") THEN
							absoluteMode := TRUE;
							NextSymbol;
							IF ~Expression (absoluteOffset, TRUE,type) THEN
								SkipLine;
							END;
						ELSIF ~(scope # NIL) & (ident = "ORG") THEN
							NextSymbol;
							IF (orgOffset # 0) OR ~Expression (orgOffset, TRUE,type) THEN
								SkipLine;
							END;
						ELSIF ~(scope # NIL) & (ident = "RESB") THEN
							NextSymbol;
							IF ~Reserve (1) THEN SkipLine END;
						ELSIF ~(scope # NIL) & (ident = "RESW") THEN
							NextSymbol;
							IF ~Reserve (2) THEN SkipLine END;
						ELSIF ~(scope # NIL) & (ident = "RESD") THEN
							NextSymbol;
							IF ~Reserve (4) THEN SkipLine END;
						(*
						ELSIF ident = "EQU" THEN
							IF currentLabel # NIL THEN
								NextSymbol;
								IF Expression (val2, FALSE) THEN
									currentLabel.pc := val2;
									currentLabel.equ := TRUE;
								ELSE
									SkipLine;
								END;
							ELSE
								Error("???");
								RETURN;
							END;
						*)
						ELSIF ident = "TIMES" THEN
							NextSymbol;
							IF ~Expression (times, TRUE,type) THEN
								SkipLine;
							ELSIF times < 0 THEN
								Error("unsupported negative value"); RETURN;
							ELSE
								prevPC := emitter.code.pc;
							END;
						ELSIF ident = "DB" THEN
							IF ~PutData (bits8) THEN SkipLine END;
						ELSIF ident = "DW" THEN
							IF ~PutData (bits16) THEN SkipLine END;
						ELSIF ident = "DD" THEN
							IF ~PutData (bits32) THEN SkipLine END;
						ELSIF ident = "REP" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfREP);
						ELSIF ident = "LOCK" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfLOCK);
						ELSIF ident = "REPE" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfREPE);
						ELSIF ident = "REPZ" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfREPZ);
						ELSIF ident = "REPNE" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfREPNE);
						ELSIF ident = "REPNZ" THEN
							NextSymbol;
							emitter.code.PutByte (InstructionSet.prfREPNZ);
						ELSIF ~GetInstruction () THEN
							SkipLine
						END;
						currentLabel := NIL;
					ELSIF (symbol = symNone) OR (symbol = symEnd) THEN
						EXIT
					ELSE
						Error("identifier expected");
						RETURN;
					END;
				END;
			END;
			(*
			FixupLabels();
			*)
			(*! FixupLabels(labels.first,code) *)
			sourceName := prevSourceName;
			emitter.cpuBits := prevCpuBits;
			emitter.cpuOptions := prevCpuOptions;
		END Assemble;

	END Assembly;

	VAR kernelWriter: Streams.Writer;

	PROCEDURE Ord (ch: CHAR): INTEGER;
	BEGIN RETURN ORD (ch) - ORD ("0")
	END Ord;

	PROCEDURE HexOrd (ch: CHAR): INTEGER;
	BEGIN
	IF ch <= "9" THEN RETURN ORD (ch) - ORD ("0")
		ELSE RETURN ORD (CAP (ch)) - ORD ("A") + 10
		END
	END HexOrd;

	PROCEDURE IsRegisterOperand*(CONST op: Operand): BOOLEAN;
	BEGIN
		RETURN op.type IN {reg8, reg16, reg32, reg64, CRn, DRn, segReg, sti, mmx, xmm}
	END IsRegisterOperand;

	PROCEDURE IsMemoryOperand*(CONST op: Operand): BOOLEAN;
	BEGIN 	RETURN op.type = mem
	END IsMemoryOperand;

	PROCEDURE IsImmediateOperand*(CONST op: Operand): BOOLEAN;
	BEGIN 	RETURN op.type = imm
	END IsImmediateOperand;

	PROCEDURE DumpType*(w: Streams.Writer; type: LONGINT);
	BEGIN
		CASE type OF
			reg8: w.String("reg8")
			|reg16: w.String("reg16");
			|reg32: w.String("reg32");
			|reg64: w.String("reg64");
			|CRn: w.String("CRn");
			|DRn: w.String("DRn");
			|segReg: w.String("segReg");
			|mmx: w.String("mmx");
			|xmm: w.String("xmm");
			|mem: w.String("mem");
			|sti: w.String("sti");
			|imm: w.String("imm");
			|ioffset: w.String("ioffset");
			|pntr1616: w.String("pntr1616");
			|pntr1632: w.String("pntr1632");
		ELSE
			w.String("?"); w.Int(type,1); w.String("?");
		END;
	END DumpType;

	PROCEDURE DumpOperand*(w: Streams.Writer; CONST operand: Operand);
	BEGIN
		CASE operand.type OF
		|reg8, reg16, reg32, reg64, CRn, DRn, segReg, sti, mmx, xmm:
			w.String(InstructionSet.registers[operand.register].name);
		|mem:
			IF operand.sizeInBytes = 1 THEN w.String("BYTE ")
			ELSIF operand.sizeInBytes= 2 THEN w.String("WORD ")
			ELSIF operand.sizeInBytes = 4 THEN w.String("DWORD ")
			ELSIF operand.sizeInBytes = 8 THEN w.String("QWORD ")
			END;
			w.String("[");
			IF operand.register # none THEN
				w.String(InstructionSet.registers[operand.register].name);
				IF operand.index # none THEN w.String("+") END;
			END;
			IF operand.index # none THEN
				w.String(InstructionSet.registers[operand.index].name);
				IF operand.scale # 1 THEN
					w.String("*"); w.Int(operand.scale,1);
				END;
			END;

			IF operand.symbol.name # "" THEN
				Basic.WriteSegmentedName(w, operand.symbol.name);	w.String(":"); w.Int(operand.displacement,1);
				IF operand.symbolOffset # 0 THEN w.String("(@"); w.Int(operand.symbolOffset,1); w.String(")") END;
			ELSIF operand.displacement # 0 THEN
				IF (operand.displacement > 0) & ((operand.register # none) OR (operand.index # none)) THEN w.String("+");END;
				w.Int(operand.displacement,1);
			END;

			w.String("]");
		|imm,ioffset:
			IF operand.symbol.name # "" THEN
				Basic.WriteSegmentedName(w, operand.symbol.name);	w.String(":"); w.Int(operand.displacement,1);
				IF operand.symbolOffset # 0 THEN w.String("(@"); w.Int(operand.symbolOffset,1); w.String(")") END;
			ELSE
				IF (operand.val > MAX(LONGINT)) OR (operand.val < MIN(LONGINT)) THEN
					w.Hex(operand.val,1); w.String("H");
				ELSE
					w.Int(SHORT(operand.val),1);
				END;
			END;
		|pntr1616:
		|pntr1632:
		ELSE
			HALT(100)
		END;


	END DumpOperand;

	PROCEDURE DumpInstruction(w: Streams.Writer; mnemonic: LONGINT; CONST operands: ARRAY OF Operand);
	VAR i: LONGINT;
	CONST DebugSize =  FALSE;
	BEGIN
		IF mnemonic # none THEN
			w.String(InstructionSet.mnemonics[mnemonic].name);
			i := 0;
			WHILE(i<maxNumberOperands) & (operands[i].type # none) DO
				IF i = 0 THEN w.Char(09X) ELSE w.String(", ") END;
				DumpOperand(w,operands[i]);
				IF DebugSize THEN
					w.String("(*"); DumpType(w,operands[i].type); w.String(":"); w.Int(operands[i].sizeInBytes,1); w.String("*)");
				END;
				INC(i);
			END;
			w.String("; ");
		END;

	END DumpInstruction;

	PROCEDURE Matches(CONST operand: Operand; type: InstructionSet.OperandType): BOOLEAN;
		PROCEDURE IsMemReg(regIndex: LONGINT): BOOLEAN;
		BEGIN
			RETURN InstructionSet.RegisterType(regIndex) IN {reg16, reg32, reg64}
		END IsMemReg;
	BEGIN
		CASE operand.type OF
		|reg8:
			CASE type OF
			InstructionSet.reg8, InstructionSet.regmem8:
				RETURN TRUE;
			| InstructionSet.AL, InstructionSet.rAX:
				RETURN InstructionSet.RegisterIndex(operand.register) = RAX;
			| InstructionSet.CL:
				RETURN InstructionSet.RegisterIndex(operand.register) = RCX;
			ELSE
				RETURN FALSE;
			END;
		|reg16:
			CASE type OF
			InstructionSet.reg16, InstructionSet.regmem16:
				RETURN TRUE;
			| InstructionSet.AX, InstructionSet.rAX:
				RETURN InstructionSet.RegisterIndex(operand.register) = RAX;
			| InstructionSet.DX:
				RETURN InstructionSet.RegisterIndex(operand.register) = RDX;
			ELSE
				RETURN FALSE;
			END;
		|reg32:
			CASE type OF
			InstructionSet.reg32, InstructionSet.regmem32:
				RETURN TRUE;
			| InstructionSet.EAX, InstructionSet.rAX:
				RETURN InstructionSet.RegisterIndex(operand.register) = RAX;
			ELSE
				RETURN FALSE;
			END;
		|reg64:
			CASE type OF
			InstructionSet.reg64, InstructionSet.regmem64:
				RETURN TRUE;
			| InstructionSet.RAX, InstructionSet.rAX:
				RETURN InstructionSet.RegisterIndex(operand.register) = RAX;
			ELSE
				RETURN FALSE;
			END;
		|CRn:
			CASE type OF
			InstructionSet.CRn:
				RETURN TRUE;
			| InstructionSet.CR8:
				RETURN InstructionSet.RegisterIndex(operand.register) = 8;
			ELSE
				RETURN FALSE;
			END;
		|DRn:
			RETURN type = InstructionSet.DRn;
		|segReg:
			CASE type OF
			InstructionSet.segReg:
				RETURN TRUE;
			| InstructionSet.ES:
				RETURN InstructionSet.RegisterIndex(operand.register) = segES;
			| InstructionSet.CS:
				RETURN InstructionSet.RegisterIndex(operand.register) = segCS;
			| InstructionSet.SS:
				RETURN InstructionSet.RegisterIndex(operand.register) = segSS;
			| InstructionSet.DS:
				RETURN InstructionSet.RegisterIndex(operand.register) = segDS;
			| InstructionSet.FS:
				RETURN InstructionSet.RegisterIndex(operand.register) = segFS;
			| InstructionSet.GS:
				RETURN InstructionSet.RegisterIndex(operand.register) = segGS;
			ELSE
				RETURN FALSE;
			END
		|sti:
			CASE type OF
			InstructionSet.sti:
				RETURN TRUE;
			| InstructionSet.st0:
				RETURN InstructionSet.RegisterIndex(operand.register) = 0;
			ELSE
				RETURN FALSE;
			END
		|mmx:
			CASE type OF
			InstructionSet.mmx, InstructionSet.mmxmem32, InstructionSet.mmxmem64:
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		|xmm:
			CASE type OF
			InstructionSet.xmm, InstructionSet.xmmmem32, InstructionSet.xmmmem64, InstructionSet.xmmmem128:
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		|mem:
			CASE type OF
			| InstructionSet.mem:
				RETURN TRUE;
			| InstructionSet.mem8:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8);
			| InstructionSet.regmem8:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)) & ((operand.register= none) OR (IsMemReg(operand.register)));
			| InstructionSet.mem16:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16);
			| InstructionSet.regmem16:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16)) & ((operand.register= none) OR (IsMemReg(operand.register)));
			| InstructionSet.mem32:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32);
			| InstructionSet.regmem32, InstructionSet.mmxmem32, InstructionSet.xmmmem32:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32)) & ((operand.register= none) OR (IsMemReg(operand.register)));
			| InstructionSet.mem64:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits64);
			| InstructionSet.regmem64, InstructionSet.mmxmem64, InstructionSet.xmmmem64:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits64)) & ((operand.register= none) OR (IsMemReg(operand.register)));
			| InstructionSet.mem128:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits128);
			| InstructionSet.xmmmem128:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits128)) & ((operand.register= none) OR (IsMemReg(operand.register)));
			| InstructionSet.moffset8:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)) & (operand.register= none);
			| InstructionSet.moffset16:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16)) & (operand.register= none);
			| InstructionSet.moffset32:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32)) & (operand.register= none);
			| InstructionSet.moffset64:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits64)) & (operand.register= none);
			ELSE
				RETURN FALSE;
			END;
		|imm,ioffset:
			CASE type OF
			InstructionSet.one:
				RETURN operand.val = 1
			| InstructionSet.three:
				RETURN operand.val = 3
			| InstructionSet.rel8off:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)
			| InstructionSet.imm8:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)) & (operand.val >= -80H) & (operand.val < 100H)
			| InstructionSet.simm8:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)) & (operand.val >= -80H) & (operand.val < 80H)
			| InstructionSet.uimm8:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits8)) & (operand.val >= 0H) & (operand.val < 100H)
			| InstructionSet.rel16off:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16) & FALSE (* do not allow 16 bit jumps *)
			| InstructionSet.imm16:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16)) & (operand.val >= -8000H) & (operand.val < 10000H)
			| InstructionSet.simm16:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16)) & (operand.val >= -8000H) & (operand.val < 8000H)
			| InstructionSet.uimm16:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits16)) & (operand.val >= 0H) & (operand.val < 10000H)
			| InstructionSet.rel32off:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32) (* & & (operand.val >= -80000000H) & (operand.val < 100000000H)  PACO confused? *)
			| InstructionSet.imm32:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32)) (* & & (operand.val >= -80000000H) & (operand.val < 100000000H)  PACO confused? *)
			| InstructionSet.simm32:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32)) (* & & (operand.val >= -80000000H) & (operand.val < 80000000H)  PACO confused? *)
			| InstructionSet.uimm32:
				RETURN ((operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits32)) & (operand.val >= 0H) (*  & (operand.val < 100000000H)  PACO confused? *)
			| InstructionSet.imm64:
				RETURN (operand.sizeInBytes = bitsDefault) OR (operand.sizeInBytes = bits64)
			ELSE
				RETURN FALSE
			END
		|pntr1616:
			RETURN type = InstructionSet.pntr1616;
		|pntr1632:
			RETURN type = InstructionSet.pntr1632;
		ELSE
			HALT(100)
		END;
	END Matches;

	PROCEDURE ValueInByteRange (value: HUGEINT): BOOLEAN;
	BEGIN RETURN SYSTEM.VAL (SHORTINT, value) = value
	END ValueInByteRange;

	PROCEDURE ValueInWordRange (value: HUGEINT): BOOLEAN;
	BEGIN RETURN SYSTEM.VAL (INTEGER, value) = value
	END ValueInWordRange;


	PROCEDURE InitOperand*(VAR operand: Operand);
	BEGIN
		operand.type := none;
		operand.index := none;
		operand.register:= none;
		operand.segment:= none;
		operand.sizeInBytes := none;
		operand.scale := 1;
		operand.displacement := 0;
		operand.val := 0;
		operand.pc := none;
		operand.symbol.name := "";
		operand.symbol.fingerprint := 0;
		operand.selector := none;
		operand.offset := 0;
	END InitOperand;


	PROCEDURE InitRegister* (VAR operand: Operand; register: Register);
	BEGIN
		InitOperand(operand);
		operand.type := InstructionSet.RegisterType(register);
		operand.register :=register;
		CASE operand.type OF
			reg8,reg16,reg32,reg64,segReg,CRn,DRn,sti,xmm,mmx: (* ok *)
			|InstructionSet.st0: operand.type := InstructionSet.sti;
		ELSE
			HALT(100);
		END;
		operand.sizeInBytes := InstructionSet.registers[register].sizeInBytes
	END InitRegister;

	PROCEDURE NewRegister*(register: Register): Operand;
	VAR operand: Operand;
	BEGIN InitRegister(operand,register); RETURN operand
	END NewRegister;

	PROCEDURE InitMem*(VAR operand: Operand; size: Size; reg: Register; displacement: LONGINT);
	BEGIN
		InitOperand(operand);
		operand.type := mem;
		operand.sizeInBytes := size;
		operand.register:= reg;
		operand.displacement := displacement;
		operand.scale := 1;
	END InitMem;

	PROCEDURE SetIndexScale*(VAR operand: Operand; index: Register;  scale: LONGINT);
	BEGIN
		operand.index := index;
		operand.scale := scale
	END SetIndexScale;

	PROCEDURE NewMem*(size: Size; reg: Register;   displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN
		InitMem(operand,size,reg,displacement); RETURN operand
	END NewMem;

	PROCEDURE InitMem8* (VAR operand: Operand; reg: Register; displacement: LONGINT);
	BEGIN  InitMem (operand, bits8, reg, displacement);
	END InitMem8;

	PROCEDURE NewMem8* (reg: Register; displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN  InitMem8 (operand,reg, displacement); RETURN operand
	END NewMem8;

	PROCEDURE InitMem16* (VAR operand: Operand; reg: Register; displacement: LONGINT);
	BEGIN  InitMem (operand,bits16, reg, displacement);
	END InitMem16;

	PROCEDURE NewMem16* (reg: Register; displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN  InitMem16 (operand,reg, displacement); RETURN operand
	END NewMem16;

	PROCEDURE InitMem32* (VAR operand: Operand; reg: Register; displacement: LONGINT);
	BEGIN  InitMem (operand,bits32, reg, displacement);
	END InitMem32;

	PROCEDURE NewMem32* (reg: Register; displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN  InitMem32 (operand,reg, displacement); RETURN operand
	END NewMem32;

	PROCEDURE InitMem64* (VAR operand: Operand; reg: Register; displacement: LONGINT);
	BEGIN  InitMem (operand,bits64, reg, displacement);
	END InitMem64;

	PROCEDURE NewMem64* (reg: Register; displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN  InitMem64 (operand,reg, displacement); RETURN operand
	END NewMem64;

	PROCEDURE InitMem128* (VAR operand: Operand; reg: Register; displacement: LONGINT);
	BEGIN  InitMem (operand,bits128, reg, displacement);
	END InitMem128;

	PROCEDURE NewMem128* (reg: Register; displacement: LONGINT): Operand;
	VAR operand: Operand;
	BEGIN  InitMem128 (operand,reg, displacement); RETURN operand
	END NewMem128;

	PROCEDURE SetSymbol*(VAR operand: Operand; symbol: Sections.SectionName; fingerprint: LONGINT; symbolOffset, displacement: LONGINT);
	BEGIN
		operand.symbol.name := symbol;
		operand.symbol.fingerprint := fingerprint;
		operand.symbolOffset := symbolOffset; operand.displacement := displacement;
	END SetSymbol;

	PROCEDURE InitImm* (VAR operand: Operand; size: SHORTINT; val: HUGEINT);
	BEGIN InitOperand(operand); operand.type := imm; operand.sizeInBytes := size; operand.val := val;
	END InitImm;

	PROCEDURE InitImm8* (VAR operand: Operand; val: HUGEINT);
	BEGIN InitImm (operand, bits8, val);
	END InitImm8;

	PROCEDURE NewImm8*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitImm8(operand,val); RETURN operand
	END NewImm8;

	PROCEDURE InitImm16* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitImm (operand, bits16, val);
	END InitImm16;

	PROCEDURE NewImm16*(val: HUGEINT): Operand;
	VAR operand:Operand;
	BEGIN InitImm16(operand,val); RETURN operand
	END NewImm16;

	PROCEDURE InitImm32* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitImm (operand, bits32, val);
	END InitImm32;

	PROCEDURE NewImm32*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitImm32(operand,val); RETURN operand
	END NewImm32;

	PROCEDURE InitImm64* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitImm (operand, bits64, val);
	END InitImm64;

	PROCEDURE NewImm64*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitImm64(operand,val); RETURN operand
	END NewImm64;

	PROCEDURE InitOffset* (VAR operand: Operand; size: SHORTINT; val: HUGEINT);
	BEGIN InitOperand(operand); operand.type := ioffset; operand.sizeInBytes := size; operand.val := val;
	END InitOffset;

	PROCEDURE InitOffset8* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitOffset (operand, bits8, val);
	END InitOffset8;

	PROCEDURE NewOffset8*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitOffset8(operand,val); RETURN operand
	END NewOffset8;

	PROCEDURE InitOffset16* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitOffset (operand, bits16, val);
	END InitOffset16;

	PROCEDURE NewOffset16*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitOffset16(operand,val); RETURN operand
	END NewOffset16;

	PROCEDURE InitOffset32* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitOffset (operand, bits32, val);
	END InitOffset32;

	PROCEDURE NewOffset32*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitOffset32(operand,val); RETURN operand
	END NewOffset32;

	PROCEDURE InitOffset64* (VAR operand: Operand; val: HUGEINT);
	BEGIN  InitOffset (operand, bits64, val);
	END InitOffset64;

	PROCEDURE NewOffset64*(val: HUGEINT): Operand;
	VAR operand: Operand;
	BEGIN InitOffset64(operand,val); RETURN operand
	END NewOffset64;

	PROCEDURE InitPntr1616* (VAR operand: Operand; s, o: LONGINT);
	BEGIN InitOperand(operand); operand.type := pntr1616; operand.selector := s; operand.offset := o;
	END InitPntr1616;

	PROCEDURE InitPntr1632* (VAR operand: Operand; s, o: LONGINT);
	BEGIN InitOperand(operand); operand.type := pntr1632; operand.selector := s; operand.offset := o;
	END InitPntr1632;

	PROCEDURE SetSize*(VAR operand: Operand;sizeInBytes: Size);
	BEGIN operand.sizeInBytes := sizeInBytes
	END SetSize;

	PROCEDURE SameOperand*(CONST left,right: Operand): BOOLEAN;
	BEGIN
		IF (left.type # right.type) OR (left.sizeInBytes # right.sizeInBytes) OR (left.symbol # right.symbol) THEN RETURN FALSE END;
		CASE left.type OF
			reg8,reg16,reg32,reg64,segReg,CRn,DRn,sti,xmm,mmx: RETURN left.register = right.register
			| imm,ioffset: RETURN (left.val = right.val) & ((left.symbol.name="") OR (left.displacement = right.displacement))
			| mem:RETURN (left.register = right.register) & (left.displacement = right.displacement) & (left.index = right.index) & (left.scale = right.scale)
			| pntr1616,pntr1632: RETURN (left.selector=right.selector) & (left.offset=right.offset)
		END;
		RETURN FALSE
	END SameOperand;


	PROCEDURE Test*(context: Commands.Context);
	VAR assembly: Emitter;
		(*errorHandler: ErrorHandler; *)
		op1,op2,op3: Operand;
		diagnostics: Diagnostics.StreamDiagnostics;
		code: Code;
		pooledName: Basic.SegmentedName;
		PROCEDURE Op(CONST name: ARRAY OF CHAR): LONGINT;
		BEGIN
			RETURN InstructionSet.FindMnemonic(name)
		END Op;

	BEGIN
		InitOperand(op1); InitOperand(op2); InitOperand(op3);
		NEW(diagnostics,context.error);
		Basic.ToSegmentedName("test", pooledName);
		NEW(code,Sections.CodeSection,8,0,pooledName,TRUE,TRUE);
		NEW(assembly,diagnostics);
		assembly.SetCode(code);
		InitRegister(op1,InstructionSet.regEAX);
		InitImm32(op2,10);
		assembly.Emit2(Op("MOV"),op1,op2);
		context.out.Update;
		code.Dump(context.out);
	END Test;

	BEGIN
		IF Trace THEN
			NEW(kernelWriter,KernelLog.Send,1000);
		END;
	END FoxAMD64Assembler.

OCAMD64Assembler.Test ~

