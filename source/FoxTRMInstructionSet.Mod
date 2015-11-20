MODULE FoxTRMInstructionSet; (** AUTHOR "fof"; PURPOSE "Tiny Register Machine Instruction Set"; *)

IMPORT Commands, Options, Streams, Sections := FoxSections, BinaryCode := FoxBinaryCode, Global := FoxGlobal, Basic := FoxBasic, D := Debugging, ObjectFile, Disassembler := FoxDisassembler,
	Files, BitSets;

CONST
	checkMnemonic=TRUE;
	maxMnemonicNameLength=8;
	maxNumberInstructions=100;

	(* 	mnemonics , unsorted
		FoxProgTools.Enum -e -l=8
		opMOV opNOT
		opADD opFADD
		opSUB opFSUB
		opAND opBIC opOR opXOR
		opMUL opFMUL
		opLDH opROR opBLR opBR opSPSR opIRET opLD opST opBL
		opBEQ opBNE opBAE opBB opBN opBNN opBO opBNO opBA opBBE opBGE opBLT opBGT opBLE opBT opBF
		opBZS opBZC opBCS opBCC opBNS opBNC opBVS opBVC opHADD opFHADD
		numberMnemonics
		~
	*)


	(*Variable instruction width related. All other bitcaounts derived.*)
	(*instructionW=24;*) (*Number of bits an instruction word holds. default 18*)
	regselW=3; (*number of bits to select a register. default 3*)
	opcodeW=4;(*Number of bits for the opcode. default 4*)
	conditionW=4; (*Number of bits fot the branch condition*)

	opMOV*= 0; opNOT*= 1; opADD*= 2; opFADD*= 3; opSUB*= 4; opFSUB*= 5; opAND*= 6; opBIC*= 7;
	opOR*= 8; opXOR*= 9; opMUL*= 10; opFMUL*= 11; opLDH*= 12; opROR*= 13; opBLR*= 14; opBR*= 15;
	opSPSR*= 16; opIRET*= 17; opLD*= 18; opST*= 19; opBL*= 20; opBEQ*= 21; opBNE*= 22; opBAE*= 23;
	opBB*= 24; opBN*= 25; opBNN*= 26; opBO*= 27; opBNO*= 28; opBA*= 29; opBBE*= 30; opBGE*= 31;
	opBLT*= 32; opBGT*= 33; opBLE*= 34; opBT*= 35; opBF*= 36; opBZS*= 37; opBZC*= 38; opBCS*= 39;
	opBCC*= 40; opBNS*= 41; opBNC*= 42; opBVS*= 43; opBVC*= 44; opHADD*= 45; opFHADD*= 46; numberMnemonics*= 47;

	(* 	operand format types *)
	None*=-1; (* no operand *)
	Rd=0; (* destination register,  encoded at bits 11..13  *)
	Rs=1; (* source register,  encoded at bits 0..2 *)
	VRd=2; (* vector destination register,  encoded at bits 11..13 *)
	VRs=3; (* vector source register, encoded at bits 0..2  *)
	Imm10=4; (* 10 bit immediate, unsigned, encoded at bits 0..9 *)  (*gets wider with wider instruction word.*)
	SignedImm10=5; (* 10 bit immediate, signed, encoded at bits 0..9 *)
	Imm14=6; (* 14 bit signed immediate, encoded at bits 0..13  *)
	MemRegImm7=7; (* memory operand of the form  [reg +imm] with 7 bit immediate, encoded at reg = 0..2, imm= 3..9  *)
	VRd0=8; (* vector register, being restricted to register number 0 *)






	ZeroRegister* = 7;

	(* operand types *)
	Register*=1;
	Immediate*=2;
	Memory*=3;

	(* special registers *)
	LR*=7; (* pc link register *)
	SP*=6; (* stack pointer register *)
	globalP*=5; (* global variable link register *)
	FP*=4; (* frame pointer register *)

	(*
		registers 0 .. 7 : general purpose registers (integer, 32 bit)
		registers 16..23: vector registers
	*)

TYPE
	OperandType = INTEGER;
	OperandFormatType = INTEGER;
	RegisterIndex = LONGINT;

	InstructionFormat* = RECORD
		mnemonic-: LONGINT;
		code, mask: SET;
		capabilities-: SET; (* what kind of capabilities an architecture must have to support this instruction *)
		op1, op2: OperandFormatType;
	END;

	Mnemonic* = RECORD
		name-: ARRAY maxMnemonicNameLength OF CHAR;
		number-: LONGINT;
		firstInstructionFormat, lastInstructionFormat: LONGINT;
	END;

	NumberedName=RECORD (* for sorting mnemonics *)
		name: ARRAY maxMnemonicNameLength OF CHAR;
		number: LONGINT;
	END;

	Operand*=RECORD
		type-: OperandType;
		size: LONGINT; (* size in bits *)
		register-: RegisterIndex; (* register index *)
		imm-: LONGINT; (* value *)
		fixup-: BinaryCode.Fixup;
	END;

	Instruction*=RECORD
		format-: LONGINT;
		op1-, op2-: Operand;
	END;


	InstructionSet *=OBJECT
		VAR mnemonics-: ARRAY numberMnemonics OF Mnemonic;
		mnemonicsSorted-: ARRAY numberMnemonics OF NumberedName;
		instructionFormats-: ARRAY maxNumberInstructions OF InstructionFormat;
		numberInstructionFormats-: LONGINT;
		inverseCondition-: ARRAY numberMnemonics OF LONGINT;
		instructionW-: LONGINT;

		RelativeBranchFixupBits-: LONGINT;
		BranchAndLinkFixupBits-: LONGINT;
		ImmediateFixupBits-: LONGINT;
		MemoryOffsetFixupBits-: LONGINT;


		PROCEDURE & InitInstructionSet * (instructionWidth: LONGINT);
		BEGIN
			ASSERT(instructionWidth>0);
			instructionW:=instructionWidth;
			RelativeBranchFixupBits:=instructionW-opcodeW-regselW-1;
			BranchAndLinkFixupBits:=instructionW-opcodeW;
			ImmediateFixupBits:=instructionW-opcodeW-regselW-1;
			MemoryOffsetFixupBits:=instructionW-11;  (*!todo: look up how that actually comes to pass*)
			InitInstructions();
		END InitInstructionSet;
		(*
		public functions:
		makeinstruction
		isvalidinstruction
		encode
		decode
		emitinst
		emit
		findmnem
		findreg
		initreg
		initimm
		initmem
		initfix
		addfix
		initop
		dumpop
		dumpinst
		dumpbits
		dumpinsformat
		disas
		*)

	PROCEDURE FindInstructionFormat(mnem: LONGINT; op1, op2: Operand): LONGINT;
	VAR i: LONGINT; instructionFormat: InstructionFormat;

		PROCEDURE Matches(operand: Operand; operandFormatType: OperandType): BOOLEAN;
		BEGIN
			CASE operand.type OF
				Register : RETURN (operandFormatType IN {Rd, Rs}) & (operand.register < 16) OR (operandFormatType IN {VRd,VRs}) & (operand.register >= 16)
				OR (operandFormatType = VRd0) & (operand.register = 16)
				;
				| Immediate : RETURN operandFormatType IN {Imm10, SignedImm10, Imm14};
				| Memory : RETURN (operandFormatType=MemRegImm7);
				| None : RETURN operandFormatType = None;
			END;
		END Matches;

	BEGIN
		i := mnemonics[mnem].firstInstructionFormat;
		WHILE i <= mnemonics[mnem].lastInstructionFormat DO
			instructionFormat := instructionFormats[i];
			IF Matches(op1, instructionFormat.op1) & Matches(op2, instructionFormat.op2) THEN
				RETURN i
			END;
			INC(i);
		END;
		D.String("could not find instruction for "); D.String(mnemonics[mnem].name); D.String(" ");
		DumpOperand(D.Log, op1); D.String(", ");
		DumpOperand(D.Log, op2); D.String(", ");
		D.Ln;

		i := mnemonics[mnem].firstInstructionFormat;
		D.Int(i,0);D.Ln;
		WHILE i <= mnemonics[mnem].lastInstructionFormat DO
		D.Int(i,0);D.Ln;
			instructionFormat := instructionFormats[i];
			IF ~Matches(op1, instructionFormat.op1) THEN
				D.String("op1 doesn't match");
			END;
			IF ~Matches(op2, instructionFormat.op2) THEN
				D.String("op2 doesn't match");
			END;
			IF Matches(op1, instructionFormat.op1) & Matches(op2, instructionFormat.op2) THEN
				D.String("MATCH!");
			ELSE
				D.String("NO MATCH!");
			END;
			D.Log.Ln;
			INC(i);
		END;
		D.Update;

		RETURN None;
	END FindInstructionFormat;

	PROCEDURE MakeInstruction*(VAR instruction: Instruction; mnemonic: LONGINT; op1, op2: Operand);
	VAR instructionFormat: LONGINT;
	BEGIN
		instructionFormat := FindInstructionFormat(mnemonic, op1, op2);
		instruction.format := instructionFormat;
		instruction.op1 := op1;
		instruction.op2 := op2;
	END MakeInstruction;

	PROCEDURE IsValidInstruction*(CONST instruction: Instruction): BOOLEAN;
	BEGIN RETURN instruction.format # None
	END IsValidInstruction;

	PROCEDURE Encode*(CONST instruction: Instruction): LONGINT;
	VAR codeSet: SET; instructionFormat: InstructionFormat; error: BOOLEAN;

		PROCEDURE Unsigned(val: LONGINT; from, to: LONGINT);
		VAR i: LONGINT;
		BEGIN
			ASSERT ( from <= to );
			FOR i := from TO to DO
				IF ODD(val) THEN INCL(codeSet, i) END;
				val := val DIV 2;
			END;
			IF val # 0 THEN error := TRUE END;
			ASSERT(val = 0);
		END Unsigned;

		PROCEDURE Signed(val: LONGINT; from, to: LONGINT);
		VAR i: LONGINT;
		BEGIN
			ASSERT ( from <= to );
			FOR i := from TO to-1 DO
				IF ODD(val) THEN INCL(codeSet, i) END;
				val := val DIV 2;
			END;

			IF val = -1 THEN INCL(codeSet, to)
			ELSIF val # 0 THEN HALT(100) (* overflow *)
			END;
		END Signed;

		PROCEDURE EncodeOperand(op: Operand; type: OperandFormatType);
		VAR imm: LONGINT;

			PROCEDURE Fixup(from, to: LONGINT);
			VAR patterns: ObjectFile.FixupPatterns; displacement: LONGINT; mode: SHORTINT;
			BEGIN
				NEW(patterns, 1);
				patterns[0].offset := from; patterns[0].bits := to-from+1;
				IF (opBL <= instructionFormat.mnemonic) & (instructionFormat.mnemonic <= opBF) THEN
					mode := BinaryCode.Relative;
					displacement := op.fixup.displacement-1;
				ELSE
					mode := BinaryCode.Absolute;
					displacement := op.fixup.displacement;
				END;
				op.fixup.InitFixup(mode, 0, op.fixup.symbol, op.fixup.symbolOffset, displacement, 0, patterns);
			END Fixup;

		BEGIN
			imm := op.imm; (* for debugging *)
			CASE type OF
				None: (* do nothing *)
				|Rd: Unsigned(op.register,instructionW-opcodeW-regselW,instructionW-opcodeW-1);
				|Rs: Unsigned(op.register, 0, regselW-1);
				|VRd: Unsigned(op.register MOD 16,instructionW-opcodeW-regselW,instructionW-opcodeW-1);
				|VRd0: Unsigned(0, instructionW-opcodeW-regselW,instructionW-opcodeW-1);
				|VRs: Unsigned(op.register MOD 16,0,regselW-1);
				|Imm10: Unsigned(op.imm, 0, instructionW-opcodeW-regselW-2);
					IF op.fixup # NIL THEN Fixup(0, instructionW-opcodeW-regselW-2) END;
				|SignedImm10: Signed(op.imm, 0, instructionW-opcodeW-regselW-2);
					IF op.fixup # NIL THEN Fixup(0, instructionW-opcodeW-regselW-2) END;
				|Imm14: Signed(op.imm, 0, BranchAndLinkFixupBits-1);
					IF op.fixup # NIL THEN Fixup(0, BranchAndLinkFixupBits-1) END;
				|MemRegImm7: Unsigned(op.register, 0, 2); Unsigned(op.imm, regselW, instructionW-opcodeW-regselW-2);
					IF op.fixup # NIL THEN Fixup(regselW, instructionW-opcodeW-regselW-2) END;
			END;
			
		END EncodeOperand;

	BEGIN
		ASSERT(instruction.format # None);
		instructionFormat := instructionFormats[instruction.format];
		codeSet := instructionFormat.code;
		EncodeOperand(instruction.op1, instructionFormat.op1);
		EncodeOperand(instruction.op2, instructionFormat.op2);
		RETURN SetToNumber(codeSet);
	END Encode;

	PROCEDURE Decode*(code: LONGINT; VAR instruction: Instruction);
	VAR instructionFormat: InstructionFormat; i: LONGINT; codeSet: SET;

		PROCEDURE Unsigned(from, to: LONGINT): LONGINT;
		VAR val, i: LONGINT;
		BEGIN
			val := 0;
			FOR i := to TO from BY -1 DO
				val := val*2;
				IF i IN codeSet THEN INC(val) END;
			END;
			RETURN val
		END Unsigned;

		PROCEDURE Signed(from, to: LONGINT): LONGINT;
		VAR val, i: LONGINT; negative:BOOLEAN;
		BEGIN
			val := 0;
			negative := to IN codeSet; (* two's complement negate *)
			FOR i := to-1 TO from BY -1 DO
				val := val*2;
				IF (i IN codeSet) THEN
					IF ~negative THEN INC(val) END;
				ELSIF negative THEN
					INC(val)
				END;
			END;
			IF negative THEN INC(val); val := -val END;
			RETURN val
		END Signed;

		PROCEDURE Matches(CONST instructionFormat: InstructionFormat): BOOLEAN;
		BEGIN
			RETURN instructionFormat.mask*codeSet = instructionFormat.code * instructionFormat.mask;
		END Matches;

		PROCEDURE DecodeOperand(VAR op: Operand; type: OperandFormatType);
		BEGIN
			InitOperand(op);
			CASE type OF
				None: op.type := None;
				|Rd: InitRegister(op,Unsigned(instructionW-opcodeW-regselW,instructionW-opcodeW-1));
				|Rs: InitRegister(op,Unsigned(0,regselW-1));
				|VRd: InitRegister(op,Unsigned(instructionW-opcodeW-regselW,instructionW-opcodeW-1)+16);
				|VRs: InitRegister(op,Unsigned(0,regselW-1)+16);
				|Imm10: InitImmediate(op,ImmediateFixupBits,Unsigned(0,ImmediateFixupBits-1));
				|SignedImm10: InitImmediate(op,ImmediateFixupBits,Signed(0,ImmediateFixupBits-1));
				|Imm14: InitImmediate(op,BranchAndLinkFixupBits,Signed(0,BranchAndLinkFixupBits-1));
				|MemRegImm7: InitMemory(op,Unsigned(0,regselW-1), Unsigned(regselW, ImmediateFixupBits-1));  (*load/store offsets*)
			END;
		END DecodeOperand;

	BEGIN
		codeSet := NumberToSet(code);
		i := 0;
		WHILE ~Matches(instructionFormats[i]) DO
			INC(i);
		END;
		instructionFormat := instructionFormats[i];
		instruction.format := i;
		DecodeOperand(instruction.op1, instructionFormat.op1);
		DecodeOperand(instruction.op2, instructionFormat.op2);
	END Decode;

	PROCEDURE EmitInstruction*(CONST instruction: Instruction; mnem: LONGINT; code: BinaryCode.Section);
	VAR encoding: LONGINT;

		PROCEDURE PatchFixup(op: Operand; type: OperandFormatType);
		BEGIN
			IF op.fixup # NIL THEN
				op.fixup.SetFixupOffset(code.pc);
				code.fixupList.AddFixup(op.fixup);
			END;
		END PatchFixup;

		PROCEDURE PatchFixups;
		VAR instructionFormat: InstructionFormat;
		BEGIN
			instructionFormat := instructionFormats[instruction.format];
			PatchFixup(instruction.op1, instructionFormat.op1);
			PatchFixup(instruction.op2, instructionFormat.op2);
		END PatchFixups;

	BEGIN
		IF (code.comments # NIL) THEN
			DumpInstruction(code.comments, instruction);
			code.comments.Ln;
			code.comments.Update;
		END;
		encoding := Encode(instruction);
		PatchFixups();
		code.PutBits(encoding, instructionW);
		(*make sure it is really a section set up to take code and not for example data.*)
		ASSERT(code.os.unit =instructionW); ASSERT(code.os.bits.GetSize() MOD instructionW = 0);
	END EmitInstruction;

	PROCEDURE Emit*(mnem: LONGINT; CONST op1, op2: Operand; code: BinaryCode.Section);
	VAR instruction: Instruction;
	BEGIN
		MakeInstruction(instruction, mnem, op1, op2);
		EmitInstruction(instruction, mnem, code);
	END Emit;

	(* perform a binary search for the index of the specified mnemonic *)
	PROCEDURE FindMnemonic* (CONST mnem: ARRAY OF CHAR): LONGINT;
	VAR l, r, m: LONGINT;
	BEGIN
		(*
		IF mnem = "LD" THEN
			IF vectorSupport THEN RETURN opLD ELSE RETURN opLDS END;
		ELSIF mnem = "ST" THEN
			IF vectorSupport THEN RETURN opST ELSE RETURN opSTS END;
		END;
		*)

		l := 0;
		r := numberMnemonics;
		WHILE l # r DO
			m := (l + r) DIV 2;
			IF mnem < mnemonicsSorted[m].name THEN r := m;
			ELSIF mnem > mnemonicsSorted[m].name THEN l := m + 1;
			ELSE RETURN mnemonicsSorted[m].number;
			END
		END;
		RETURN None;
	END FindMnemonic;

	PROCEDURE FindRegister*(CONST name: ARRAY OF CHAR): SHORTINT;
	BEGIN
		IF name[0] = "R" THEN
			IF name[2] = 0X THEN
				IF ("0" <= name[1]) & (name[1] <= "9") THEN
					RETURN SHORT(ORD(name[1])-ORD("0"));
				ELSE RETURN None
				END;
			ELSIF ("0"<=name[2]) & (name[2] <= "5") THEN
				IF name[1] = "1" THEN
					RETURN SHORT(ORD(name[2])-ORD("0")+10);
				ELSE RETURN None
				END;
			ELSE RETURN None
			END;
		ELSIF name[0] = "V" THEN
			IF name[1] = "R" THEN
				IF ("0" <= name[2]) & (name[2] <= "8") THEN
					RETURN SHORT(ORD(name[2])-ORD("0"))+16;
				ELSIF name[2] = 0X THEN (* VR as shortcut for VR0 *)
					RETURN 16
				ELSE
					RETURN None
				END;
			END;
			RETURN None;
		ELSIF name = "SP" THEN
			RETURN SP
		ELSIF name = "LR" THEN
			RETURN LR
		ELSE
			RETURN None
		END;
	END FindRegister;

	PROCEDURE NumberToSet(code: LONGINT): SET;
	VAR i: LONGINT; set: SET;
	BEGIN
		ASSERT(MAX(SET) >= 31);
		set := {};
		FOR i := 0 TO 31 DO
			IF ODD(code) THEN INCL(set, i) END;
			code := code DIV 2;
		END;
		RETURN set
	END NumberToSet;

	PROCEDURE SetToNumber(set: SET): LONGINT;
	VAR i, num: LONGINT;
	BEGIN
		ASSERT(MAX(SET) >= 31);
		num := 0;
		FOR i := 0 TO 31 DO
			IF i IN set THEN INC(num, ASH(1, i)) END;
		END;
		RETURN num
	END SetToNumber;

	(** setup instruction and mnemonic tables **)
	PROCEDURE InitInstructions;
	VAR curMnemonic: LONGINT;
		checkMnemonics: ARRAY numberMnemonics OF BOOLEAN;
		isimmP,isfloatP,isvecP: LONGINT; (*shorthands for positions iside the instruction word*)
		isSpecialBR:LONGINT;
		opcodeP,capabilityP,currOpCode, brModesP, brCondP:SET;

		PROCEDURE SortMnemonics(lo, hi: LONGINT);
		VAR i, j: LONGINT; x, t: NumberedName;
		BEGIN
			i := lo; j := hi;
			x := mnemonicsSorted[(lo+hi) DIV 2];
			WHILE (i <= j) DO
				WHILE (mnemonicsSorted[i].name < x.name) DO INC(i) END;
				WHILE (x.name <  mnemonicsSorted[j].name) DO DEC(j) END;
				IF (i <= j) THEN
					t := mnemonicsSorted[i]; mnemonicsSorted[i] := mnemonicsSorted[j]; mnemonicsSorted[j] := t;
					INC(i); DEC(j)
				END
			END;
			IF (lo < j) THEN SortMnemonics(lo, j) END;
			IF (i < hi) THEN SortMnemonics(i, hi) END
		END SortMnemonics;

		PROCEDURE AddMnemonic(number: LONGINT; CONST name: ARRAY OF CHAR);
		BEGIN
			ASSERT(number<numberMnemonics);
			IF checkMnemonic THEN checkMnemonics[number] := TRUE END;

			curMnemonic := number;
			COPY (name, mnemonics[number].name);
			COPY (name, mnemonicsSorted[number].name);
			mnemonicsSorted[number].number := number;
			mnemonics[number].firstInstructionFormat := numberInstructionFormats;
		END AddMnemonic;

		PROCEDURE AddAlias(alias,number: LONGINT; CONST name: ARRAY OF CHAR);
		BEGIN
			IF checkMnemonic THEN checkMnemonics[alias] := TRUE END;

			COPY(name, mnemonicsSorted[alias].name);
			COPY(name, mnemonics[alias].name);
			mnemonicsSorted[alias].number := alias;
			mnemonics[alias].firstInstructionFormat := mnemonics[number].firstInstructionFormat;
		END AddAlias;


		PROCEDURE EndMnemonic;
		BEGIN
			mnemonics[curMnemonic].lastInstructionFormat := numberInstructionFormats-1;
		END EndMnemonic;

		PROCEDURE AddInstruction(code, mask: SET; op1, op2: OperandType; capabilities: SET);
		VAR instructionFormat: InstructionFormat;
		BEGIN
			instructionFormat.mnemonic := curMnemonic;
			instructionFormat.code := code;
			instructionFormat.mask := mask;
			instructionFormat.op1 := op1;
			instructionFormat.op2 := op2;
			instructionFormat.capabilities:= capabilities;
			instructionFormats[numberInstructionFormats] := instructionFormat;
			INC(numberInstructionFormats);
		END AddInstruction;

		PROCEDURE CheckMnemonics;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO numberMnemonics-1 DO
				ASSERT(checkMnemonics[i]);
			END;
		END CheckMnemonics;

		PROCEDURE Inverse(mnem1, mnem2: LONGINT);
		BEGIN
			inverseCondition[mnem1] := mnem2;
			inverseCondition[mnem2] := mnem1
		END Inverse;

		(*Turn a number into a set of bits at the start of an instruction word*)
		PROCEDURE makeOpcode(num: LONGINT) :SET;
		VAR shifted: LONGINT;
		BEGIN
			(*left shift then convert to set*)
			shifted:=LSL(num,( instructionW-opcodeW ) );
			RETURN NumberToSet(shifted);
		END makeOpcode;

		PROCEDURE makeCondition(num:LONGINT):SET;
		VAR shifted: LONGINT;
		BEGIN
			shifted:=LSL(num,( instructionW-opcodeW-conditionW) );
			RETURN NumberToSet(shifted);
		END makeCondition;

	BEGIN
		FOR curMnemonic := 0 TO numberMnemonics-1 DO
			checkMnemonics[curMnemonic] := FALSE;
			inverseCondition[curMnemonic] := -1;
		END;

		curMnemonic := -1;
		numberInstructionFormats := 0;

		(*
			oooo ddd 0 nnnnnnnnnn
			oooo ddd 1 xxxxxxxsss
		*)

		
		isimmP:=instructionW-1-opcodeW-regselW; (*18bit inW=> bit 10. If this bit is NOT set, there is an immediate.*)
		isfloatP:=isimmP-2; (*18 bit insW => bit 8*)
		isvecP:=isimmP-1; (*18 bit insW=> bit 9*)
		isSpecialBR:=isimmP;

		opcodeP:={(instructionW-opcodeW)..(instructionW-1)}; (*normally 14..17*)
		capabilityP:={isfloatP-1..isimmP}; (*normally 7..10*)
		brModesP:={(instructionW-opcodeW-regselW-3)..(instructionW-opcodeW-regselW-1)}; (*18bit=> 8..10*)
		brCondP:={(instructionW-opcodeW-4)..(instructionW-opcodeW-1)}; (*18bit => 10..13*)

		(*Note the actual opcode is the first argument in addinstruction, independent of mnemonic number *)

		(*Note: mov with isimm=1 and bit 3 becomes LDH*)
		currOpCode:=makeOpcode(0);
		AddMnemonic(opMOV, "MOV");
		AddInstruction({}, opcodeP+{isimmP}, Rd, Imm10,{});
		AddInstruction({isimmP}, {3}+capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction({isvecP, isimmP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability}); (* TODO index *)
		AddInstruction({isvecP, isimmP}, capabilityP+opcodeP, Rd, VRs,{Global.VectorCapability}); (* TODO index *)
		EndMnemonic;

		(* LDH: oooo = 0000 *)
		AddMnemonic(opLDH, "LDH");
		AddInstruction({3, isimmP}, {3}+capabilityP+opcodeP, Rd, None,{});
		AddInstruction({3, isvecP, isimmP}, {3}+capabilityP+opcodeP, VRd, None,{Global.VectorCapability}); (* TODO index *)
		EndMnemonic;

		(* NOT: oooo = 0001 *)
		currOpCode:=makeOpcode(1);
		AddMnemonic(opNOT, "NOT");
		AddInstruction(currOpCode,						{isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction({isimmP}+currOpCode, 			capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction({isimmP,isfloatP}+currOpCode, 	capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* ADD: oooo = 0010 *)
		currOpCode:=makeOpcode(2);
		AddMnemonic(opADD, "ADD");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* bit 9 indicates a usage of vector registers, bit 8 indicates floating point instructions *)
		AddMnemonic(opFADD, "FADD");
		AddInstruction(currOpCode+{isimmP,isfloatP}, capabilityP+opcodeP, Rd, Rs,{Global.FloatingPointCapability});
		AddInstruction(currOpCode+{isimmP,isfloatP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.FloatingPointCapability,Global.VectorCapability});
		EndMnemonic;

		(*No idea what bit 7 does. Appears to be a capability that is defunct in hardware.*)
		AddMnemonic(opHADD, "HADD");
		AddInstruction(currOpCode+{isimmP,isfloatP,7}, capabilityP+opcodeP, Rd, VRs,{Global.VectorCapability});
		EndMnemonic;

		AddMnemonic(opFHADD, "FHADD");
		AddInstruction(currOpCode+{isimmP,isfloatP,isvecP,7}, capabilityP+opcodeP, Rd, VRs,{Global.FloatingPointCapability, Global.VectorCapability});
		EndMnemonic;

		(* SUB: oooo = 0011 *)
		currOpCode:=makeOpcode(3);
		AddMnemonic(opSUB, "SUB");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		AddMnemonic(opFSUB, "FSUB");
		AddInstruction(currOpCode+{isimmP,isfloatP}, capabilityP+opcodeP, Rd, Rs,{Global.FloatingPointCapability});
		AddInstruction(currOpCode+{isimmP,isfloatP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.FloatingPointCapability, Global.VectorCapability});
		EndMnemonic;

		(* AND: oooo = 0100 *)
		currOpCode:=makeOpcode(4);
		AddMnemonic(opAND, "AND");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* BIC: oooo = 0101 *)
		currOpCode:=makeOpcode(5);
		AddMnemonic(opBIC, "BIC");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isvecP,isimmP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* OR: oooo = 0110 *)
		currOpCode:=makeOpcode(6);
		AddMnemonic(opOR, "OR");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* XOR: oooo = 0111 *)
		currOpCode:=makeOpcode(7);
		AddMnemonic(opXOR, "XOR");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		(* MUL: oooo = 1000 *)
		currOpCode:=makeOpcode(8);
		AddMnemonic(opMUL, "MUL");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, capabilityP+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		EndMnemonic;

		AddMnemonic(opFMUL, "FMUL");
		AddInstruction(currOpCode+{isimmP,isfloatP}, capabilityP+opcodeP, Rd, Rs,{Global.FloatingPointCapability});
		AddInstruction(currOpCode+{isfloatP,isvecP,isimmP}, capabilityP+opcodeP, VRd, VRs,{Global.FloatingPointCapability,Global.VectorCapability});
		EndMnemonic;

		(*opcode 9 wuld be div, is disabled.*)

          (* ROR: oooo = 1010 *)
          currOpCode:=makeOpcode(10);
		AddMnemonic(opROR, "ROR");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, Imm10,{});
		AddInstruction(currOpCode+{isimmP}, {isimmP}+opcodeP, Rd, Rs,{});
		AddInstruction(currOpCode+{isimmP,isvecP}, capabilityP+opcodeP, VRd, VRs,{Global.VectorCapability});
		AddInstruction(currOpCode+{isfloatP,isvecP,isimmP}, capabilityP+opcodeP, VRd0, Rs,{Global.VectorCapability});
		EndMnemonic;

		(* BR: oooo = 1011 *)
		currOpCode:=makeOpcode(11);
		AddMnemonic(opBR, "BR");
		AddInstruction(currOpCode+{isSpecialBR}, brModesP+opcodeP, Rs, None,{});
		EndMnemonic;

		(* SPSR: oooo = 1011 *)
		AddMnemonic(opSPSR, "SPSR");
		AddInstruction(currOpCode, {isSpecialBR}+opcodeP, Imm10, None,{});
		EndMnemonic;

		(* BLR: oooo = 1011 *)
		(* BLR Rd, Rs 	<--> 	Rd := PC+1; PC := Rs *)
		AddMnemonic(opBLR, "BLR");
		AddInstruction(currOpCode+{isSpecialBR,isSpecialBR-1}, brModesP+opcodeP, Rd, Rs,{});
		EndMnemonic;

		(* RTI: oooo = 1011 *)
		AddMnemonic(opIRET, "IRET");
		AddInstruction(currOpCode+{isSpecialBR,isSpecialBR-2}, brModesP+opcodeP, Rs, None,{});
		EndMnemonic;

		(* LD: 1100 ddd xnnnnnnn sss *)
		currOpCode:=makeOpcode(12);
		AddMnemonic(opLD, "LD");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, MemRegImm7,{});
		AddInstruction(currOpCode+{isimmP}, {isimmP}+opcodeP, VRd, MemRegImm7,{Global.VectorCapability});
		EndMnemonic;

          (* ST: 1101 ddd xnnnnnnn sss *)
          currOpCode:=makeOpcode(13);
		AddMnemonic(opST, "ST");
		AddInstruction(currOpCode, {isimmP}+opcodeP, Rd, MemRegImm7,{});
		AddInstruction(currOpCode+{isimmP}, {isimmP}+opcodeP, VRd, MemRegImm7,{Global.VectorCapability});
		EndMnemonic;

		(* BC
			1110 cond nnnnnnnnnn

			cond
			0000	Z	Zero / equal	BEQ
			0001	~Z	Non-zero / unequal	BNE
			0010	C	Carry / above or equal (unsigned)	BAE
			0011	~C	No carry / below (unsigned)	BB
			0100	N	Negative	BN
			0101	~N	Not negative	BNN
			0110	V	Overflow	BO
			0111	~V	No overflow	BNO
			1000	~(~C | Z)	Carry and no zero / above (unsigned)	BA
			1001	~C | Z	No carry or zero / below or equal (unsigned)	BBE
			1010	~(N V)	N=V / greater or equal (signed)	BGE
			1011	N V	N V / less (signed)	BLT
			1100	~((N V) | Z)	greater or equal and ~ZF / greater (signed)	BGT
			1101	(N V) | Z	less or Z / less or equal (signed)	BLE
			1110	TRUE	Always	BT
			1111	FALSE	Never	BF
		*)
		currOpCode:=makeOpcode(14);
		AddMnemonic(opBEQ, "BEQ"); 	AddInstruction(currOpCode+makeCondition(0), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBNE, "BNE"); 	AddInstruction(currOpCode+makeCondition(1), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBAE, "BAE");  	AddInstruction(currOpCode+makeCondition(2), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBB, "BB");      	AddInstruction(currOpCode+makeCondition(3), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBN, "BN");     	AddInstruction(currOpCode+makeCondition(4), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBNN, "BNN"); 	AddInstruction(currOpCode+makeCondition(5), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;

		AddMnemonic(opBO, "BO");     	AddInstruction(currOpCode+makeCondition(6), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBNO, "BNO"); 	AddInstruction(currOpCode+makeCondition(7), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBA, "BA"); 		AddInstruction(currOpCode+makeCondition(8), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBBE, "BBE"); 	AddInstruction(currOpCode+makeCondition(9), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBGE, "BGE"); 	AddInstruction(currOpCode+makeCondition(10), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBLT, "BLT"); 	AddInstruction(currOpCode+makeCondition(11), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBGT, "BGT"); 	AddInstruction(currOpCode+makeCondition(12), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBLE, "BLE"); 	AddInstruction(currOpCode+makeCondition(13), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		
		AddMnemonic(opBT, "BT"); 		AddInstruction(currOpCode+makeCondition(14), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;
		AddMnemonic(opBF, "BF"); 		AddInstruction(currOpCode+makeCondition(15), opcodeP+brCondP, SignedImm10, None,{}); EndMnemonic;

		Inverse(opBEQ, opBNE);
		Inverse(opBAE, opBB);
		Inverse(opBN, opBNN);
		Inverse(opBO, opBNO);
		Inverse(opBA, opBBE);
		Inverse(opBGE, opBLT);
		Inverse(opBGT, opBLE);
		Inverse(opBT, opBF);

		AddAlias(opBZS,opBEQ,"BZS");
		AddAlias(opBZC,opBNE,"BZC");
		AddAlias(opBCS,opBAE,"BCS");
		AddAlias(opBCC,opBB,"BCC");
		AddAlias(opBNS,opBN,"BNS");
		AddAlias(opBNC,opBNN,"BNC");
		AddAlias(opBVS,opBO,"BVS");
		AddAlias(opBVC,opBNO,"BVC");



		(* BL: 1111 nnnnnnnnnnnnnn *)
		currOpCode:=makeOpcode(15);
		AddMnemonic(opBL, "BL");
		AddInstruction(currOpCode, opcodeP, Imm14, None,{});
		EndMnemonic;



		SortMnemonics(0, numberMnemonics-1);


		IF checkMnemonic THEN CheckMnemonics END;
	END InitInstructions;

	PROCEDURE InitRegister*(VAR operand: Operand; reg: LONGINT);
	BEGIN
		operand.type := Register;
		operand.register := SHORT(reg);
	END InitRegister;

	PROCEDURE InitImmediate*(VAR operand: Operand; bits: LONGINT; imm: LONGINT);
	BEGIN
		operand.type := Immediate;
		operand.size := bits;
		operand.imm := imm;
	END InitImmediate;

	PROCEDURE InitMemory*(VAR operand: Operand; reg1: RegisterIndex; imm: LONGINT);
	BEGIN
		operand.type := Memory;
		operand.register := reg1;
		operand.imm := imm;

		IF reg1 < 0 THEN
			operand.register := ZeroRegister;
		END;
	END InitMemory;

	(* generate immediate operand with fixup *)
	PROCEDURE InitFixup*(VAR operand: Operand; bits: SHORTINT; fixup: BinaryCode.Fixup (*symbol: Sections.Section; offset, displacement: LONGINT *));
	BEGIN
		operand.type := Immediate;
		operand.imm := 0;
		operand.size := bits;
		operand.fixup := fixup;
		(*
		operand.fixup := BinaryCode.NewFixup(BinaryCode.Absolute, 0, symbol, offset, displacement, 0, NIL);
		*)
		(*
		operand.symbol := symbol;
		operand.symbolOffset := offset;
		operand.displacement := displacement;
		*)
	END InitFixup;

	PROCEDURE AddFixup*(VAR operand: Operand; fixup: BinaryCode.Fixup);
	BEGIN
		ASSERT(operand.type IN {Immediate, Memory});
		operand.fixup := fixup
	END AddFixup;

	PROCEDURE InitOperand*(VAR operand: Operand);
	BEGIN
		operand.type := None;
		operand.register := None;
		operand.imm := 0;
		operand.fixup := NIL;
		(*
		operand.symbol := NIL;
		operand.symbolOffset := 0;
		operand.displacement := 0;
		*)
	END InitOperand;

	PROCEDURE DumpOperand*(w: Streams.Writer; CONST operand: Operand);
	BEGIN
		IF operand.type = None THEN RETURN END;
		CASE operand.type OF
		Register: IF operand.register >= 16 THEN w.String("V"); END; w.String("R"); w.Int(operand.register MOD 16, 1);
		|Immediate:
			IF operand.fixup # NIL THEN
				operand.fixup.Dump(w);
			ELSE
				w.Int(operand.imm, 1);
			END;
		|Memory:
			w.String("[");
			IF operand.register # 7 THEN
				w.String("R"); w.Int(operand.register, 1);
				IF operand.fixup # NIL THEN w.String("+"); operand.fixup.Dump(w)
				ELSIF operand.imm > 0 THEN w.String("+"); w.Int(operand.imm, 1)
				ELSIF operand.imm < 0 THEN w.String("-"); w.Int(-operand.imm, 1)
				END;
			ELSE
				w.Int(operand.imm, 1)
			END;
			w.String("]");
		END;
	END DumpOperand;

	PROCEDURE DumpInstruction*(w: Streams.Writer; CONST instruction: Instruction);
	VAR instructionFormat: InstructionFormat; first: BOOLEAN;

		PROCEDURE DumpOp(op: Operand);
		BEGIN
			IF op.type = None THEN RETURN END;
			IF first THEN w.String(" "); first := FALSE; ELSE w.String(", ") END;
			DumpOperand(w, op);
		END DumpOp;


	BEGIN
		IF instruction.format = None THEN
			w.String(" no format")
		ELSE
			instructionFormat := instructionFormats[instruction.format];
			w.String(mnemonics[instructionFormat.mnemonic].name);
			first := TRUE;
			DumpOp(instruction.op1);
			DumpOp(instruction.op2);
		END;
	END DumpInstruction;

	PROCEDURE DumpBits*(w: Streams.Writer; set: SET; numberBits: LONGINT);
	VAR i: LONGINT;
	BEGIN
		FOR i := numberBits-1 TO 0 BY -1 DO
			IF i IN set THEN w.String("1") ELSE w.String("0") END;
		END;
	END DumpBits;

	PROCEDURE DumpInstructionFormats*(context: Commands.Context);
	VAR i, j, k, mnemNum: LONGINT; instr: InstructionFormat; first: BOOLEAN; mnemonic: Mnemonic; options: Options.Options; sorted: BOOLEAN;

		PROCEDURE DumpType(type: INTEGER);
		BEGIN
			IF type = None THEN RETURN END;
			IF first THEN context.out.String(" "); first := FALSE; ELSE context.out.String(", ") END;
			CASE type OF
				|Rd: context.out.String("Rd")
				|Rs: context.out.String("Rs")
			     |Imm10: context.out.String("imm10");
			     |SignedImm10: context.out.String("SignedImm10");
				|Imm14: context.out.String("imm14");
				|MemRegImm7: context.out.String("MemRegImm7");
			ELSE
				context.out.String("error: type not found: DumpType ("); context.out.Int(type, 0); context.out.String(")");
				context.out.Ln;
			END;
		END DumpType;

	BEGIN
		NEW(options);
		options.Add("s", "sorted", Options.Flag);
		IF options.Parse(context.arg, context.error) THEN
			sorted := options.GetFlag("s");
			FOR i := 0 TO numberMnemonics-1 DO
				IF sorted THEN
					mnemNum := mnemonicsSorted[i].number
				ELSE
					mnemNum := i
				END;
				mnemonic := mnemonics[mnemNum];

				FOR j := mnemonic.firstInstructionFormat TO mnemonic.lastInstructionFormat DO
					instr := instructionFormats[j];
					ASSERT(mnemNum = instr.mnemonic);
					context.out.Int(j, 2); context.out.String(" ");
					context.out.String(mnemonic.name);
					k := 0; first := TRUE;
					DumpType(instr.op1);
					DumpType(instr.op2);
					context.out.Ln; context.out.String(" mask = "); DumpBits(context.out, instr.mask, 18);
					context.out.Ln; context.out.String(" code = "); DumpBits(context.out, instr.code, 18);
					context.out.Ln;
				END;
			END;
		END;
	END DumpInstructionFormats;



	END InstructionSet;


	PROCEDURE Hex(ch: CHAR): LONGINT;
	BEGIN
		IF (ch <= 'F') & (ch >= 'A') THEN RETURN ORD(ch)-ORD('A')+10
		ELSIF (ch <= 'f') & (ch >= 'a') THEN RETURN ORD(ch)-ORD('a')+10
		ELSIF (ch>='0') & (ch <='9') THEN RETURN ORD(ch)-ORD('0')
		ELSE HALT(100)
		END;
	END Hex;

	PROCEDURE ReadCode(file: Files.File): BitSets.BitSet;
	VAR r: Files.Reader;  val, val2: LONGINT;line: ARRAY 10 OF CHAR; lineNr: LONGINT; bitSet: BitSets.BitSet; i: LONGINT;
	BEGIN
	(*todo: probably screws up on anything but 18 bit double packed*)
		IF file = NIL THEN RETURN NIL END;
		lineNr := 0;
		NEW(r, file, 0);
		NEW(bitSet,0);
		
		
		
		WHILE r.Available()>0 DO
			r.Ln(line);
			val:=0;
			i:=0;
			WHILE ORD(line[i])>0 DO(*read entire line*)
				val:=val*10H;
				val:=val+Hex(line[i]);
				INC(i);				
			END;
			INC(lineNr);
			bitSet.Resize(lineNr*36);(*bitset is treated as series of 36 bit slots into which the individual words fit left aligned.*)
			bitSet.SetBits((lineNr-1)*36,decodeInstance.instructionW,val); (*extract word*)
		END;
		
		RETURN bitSet
	END ReadCode;

	PROCEDURE ReadData(file: Files.File): BitSets.BitSet;
	VAR r: Files.Reader;  val, val2: LONGINT;line: ARRAY 10 OF CHAR; lineNr: LONGINT; bitSet: BitSets.BitSet; i: LONGINT;
	BEGIN
		IF file = NIL THEN RETURN NIL END;
		lineNr := 0;
		NEW(r, file, 0);
		NEW(bitSet,0);
		WHILE r.Available()>0 DO
			r.Ln(line);
			val := 0;
			FOR i := 0 TO 7 DO
				val := val*10H;
				val := val + Hex(line[i]);
			END;
			INC(lineNr);
			bitSet.Resize(lineNr*32);
			bitSet.SetBits((lineNr-1)*32, 32, val);
		END;
		RETURN bitSet
	END ReadData;

	PROCEDURE Disassemble*(context: Commands.Context); 
	TYPE
		Disasm = OBJECT (Disassembler.Disassembler)

			PROCEDURE DisassembleInstruction(bitSet: BitSets.BitSet; VAR adr: LONGINT; maxInstructionSize: LONGINT; w:Streams.Writer);
			VAR instruction: Instruction; value: LONGINT; mnemonic: LONGINT;
			BEGIN
				(* maxInstructionSize can be ignored here *)
				value := bitSet.GetBits(adr*36,decodeInstance.instructionW);    (*bitset treated as series of 36 bit slots, individual words left aligned.*)
				decodeInstance.Decode(value, instruction);
				decodeInstance.DumpInstruction(w, instruction);
				IF instruction.format # None THEN
					mnemonic := decodeInstance.instructionFormats[instruction.format].mnemonic;
					IF (mnemonic >= opBEQ) & (mnemonic <= opBF) OR (mnemonic = opBL) THEN
						WriteReference(instruction.op1.imm+adr+1, TRUE, w);
					ELSIF (mnemonic = opLD) OR (mnemonic = opST) THEN
						IF (instruction.op2.register = ZeroRegister) THEN
							WriteReference(instruction.op2.imm, FALSE, w);
						END;
					END;
				END;
				INC(adr);
			END DisassembleInstruction;

		END Disasm;

	VAR disassembler: Disasm; codeFileName, dataFileName, logFileName: Files.FileName; codeFile, dataFile, logFile: Files.File;code, data: BitSets.BitSet; options: Options.Options;
		address: LONGINT;
		instructionWidth: LONGINT;
	BEGIN
		IF context.arg.GetString(codeFileName) THEN
			codeFile := Files.Old(codeFileName);
			IF codeFile = NIL THEN context.out.String("file not found "); context.out.String(codeFileName); RETURN END;
			IF context.arg.GetString(dataFileName) THEN
				dataFile := Files.Old(dataFileName)
			ELSE
				dataFile := NIL;
			END;
			NEW(options);
			options.Add("l","logFile", Options.String);
			options.Add("a","address",Options.Integer);
			options.Add("w","instructionWidth",Options.Integer);
			IF options.Parse(context.arg, context.out) THEN
				IF ~options.GetInteger("w",instructionWidth) THEN instructionWidth:=18 END;
				TRACE(instructionWidth);
				IF ~options.GetInteger("a", address) THEN address := 0 END;
				NEW(decodeInstance,instructionWidth);
				NEW(disassembler, context.out);
				code := ReadCode(codeFile);
				data := ReadData(dataFile);
				IF options.GetString("logFile",logFileName) THEN
					logFile := Files.Old(logFileName);
				ELSE
					logFile := disassembler.GetLogFile(codeFileName)
				END;
				disassembler.Disassemble(code, data, 36, 32, logFile, address);
			END;
		END;
	END Disassemble;


VAR
	decodeInstance: InstructionSet;
BEGIN
	NEW(decodeInstance,18);
END FoxTRMInstructionSet.

SystemTools.FreeDownTo FoxTRMInstructionSet ~
FoxTRMInstructionSet.DumpInstructionFormats -s ~
FoxTRMInstructionSet.Test ~







FoxTRMInstructionSet.Disassemble disastest.mem ~

FoxTRMInstructionSet.Disassemble ins.mem ~

