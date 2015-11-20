MODULE ARMDecoder;

IMPORT SYSTEM, Decoder, Streams, KernelLog;

CONST

	objFileSuffix = "Oba";
	none = -1;

	(* argument structure *)
	ArgNone = -2;
	ArgImm = 1;
	ArgReg = 2;
	ArgShift = 3;
	ArgRegImm = 11;
	ArgRegReg = 12;
	ArgRegShift = 13;
	ArgRegMem = 14;
	ArgRegRList = 15;
	ArgRegRegImm = 21;
	ArgRegRegReg = 22;
	ArgRegRegShift = 23;
	ArgRegRegMem = 24;
	ArgRegRegRegReg = 31;
	ArgRegRegRegImm = 32;
	ArgRegRegRegShift = 33;
	ArgCProcRegMem = 41;
	ArgCProcImmRegRegRegImm = 42;

	(* registers *)
	FP = 12; SP = 13; LR = 14; PC = 15; CPSR = 16; SPSR = 17;

	(* status register bits *)
	SRegC = 0; SRegX = 1; SRegS = 2; SRegF = 3;

	(* instructions *)
	opUNDEFINED = -2;
	opADC = 1;
	opADD = 2;
	opAND = 3;
	opASR = 4;
	opB = 5;
	opBIC = 6;
	opBKPT = 7;
	opBL = 8;
	opBLX = 9;
	opBX = 10;
	opCDP = 11;
	opCDP2 = 12;
	opCLZ = 13;
	opCMN = 14;
	opCMP = 15;
	opEOR = 16;
	opLDC = 17;
	opLDC2 = 18;
	opLDM = 19;
	opLDR = 20;
	opLDRB = 21;
	opLDRBT = 22;
	opLDRH = 23;
	opLDRSB = 24;
	opLDRSH = 25;
	opLDRT = 26;
	opLSL = 27;
	opLSR = 28;
	opMCR = 29;
	opMCR2 = 30;
	opMLA = 31;
	opMOV = 32;
	opMRC = 33;
	opMRC2 = 34;
	opMRS = 61;
	opMSR = 35;
	opMUL = 36;
	opMVN = 37;
	opORR = 38;
	opROR = 39;
	opRRX = 40;
	opRSB = 41;
	opRSC = 42;
	opSBC = 43;
	opSMLAL = 44;
	opSMULL = 45;
	opSTC = 46;
	opSTC2 = 47;
	opSTM = 48;
	opSTR = 49;
	opSTRB = 50;
	opSTRBT = 51;
	opSTRH = 52;
	opSTRT = 53;
	opSUB = 54;
	opSWI = 55;
	opSWP = 56;
	opSWPB = 62;
	opTEQ = 57;
	opTST = 58;
	opUMLAL = 59;
	opUMULL = 60;

	(* conditions *)
	EQ = 0;
	NE = 1;
	CSHS = 2;
	CCLO = 3;
	MI = 4;
	PL = 5;
	VS = 6;
	VC = 7;
	HI = 8;
	LS = 9;
	GE = 10;
	LT = 11;
	GT = 12;
	LE = 13;
	AL = 14;
	NV = 15;

	(* argument representations *)
	RepInt = 1;
	RepHex = 2;
	RepRelJmp = 10;

	(* immediate reg operations *)
	Lsl = 0;
	LSR = 1;
	Asr = 2;
	Ror = 3;
	RRX = 4;

	(* memory access addressing modes *)
	AddrModeReg = 1;
	AddrModeRegImm = 2;
	AddrModeRegReg = 3;
	AddrModeRegRegScale = 4;
	AddrModeDA = 5;
	AddrModeIA = 6;
	AddrModeDB = 7;
	AddrModeIB = 8;
	RegUpdateNone = 0;
	RegUpdatePre = 1;
	RegUpdatePost = 2;

TYPE
	ARMArg = OBJECT
	END ARMArg;

	ARMArgImm = OBJECT (ARMArg)
		VAR
			imm, rep : LONGINT;
		PROCEDURE &New *(imm, rep : LONGINT);
		BEGIN
			SELF.imm := imm;
			SELF.rep := rep
		END New;
	END ARMArgImm;

	ARMArgReg = OBJECT (ARMArg)
		VAR
			reg : LONGINT;
			isCReg : BOOLEAN; (* coprocessor register? *)
			sregMask : SET; (* for CPSR, SPSR registers *)
		PROCEDURE &New *(reg : LONGINT);
		BEGIN
			SELF.reg := reg;
			isCReg := FALSE
		END New;
	END ARMArgReg;

	ARMArgRList = OBJECT (ARMArg)
		VAR
			regs : SET;
			addrMode : LONGINT;
		PROCEDURE &New *(regs : SET);
		BEGIN
			SELF.regs := regs;
		END New;
	END ARMArgRList;

	ARMArgMem = OBJECT (ARMArg)
		VAR
			addrMode, reg, regOffs, regScale, shift, immOffs : LONGINT;
			width : LONGINT;
			signed, translation : BOOLEAN;
			regUpdate : LONGINT;
		PROCEDURE &New *(adrMode, reg : LONGINT);
		BEGIN
			SELF.addrMode := adrMode;
			SELF.reg := reg;
			width := 4;
			regUpdate := RegUpdateNone;
			signed := FALSE;
			translation := FALSE
		END New;
	END ARMArgMem;

	ARMArgShift = OBJECT (ARMArg)
		VAR
			shiftImmOrReg, operation : LONGINT;
			reg : BOOLEAN;
		PROCEDURE &New *(operation, shiftImmOrReg : LONGINT; reg : BOOLEAN);
		BEGIN
			SELF.operation := operation;
			SELF.shiftImmOrReg := shiftImmOrReg;
			SELF.reg := reg
		END New;
	END ARMArgShift;

	ARMArgCProc = OBJECT (ARMArg)
		VAR
			cproc : LONGINT;
		PROCEDURE &New *(cproc : LONGINT);
		BEGIN
			SELF.cproc := cproc
		END New;

	END ARMArgCProc;

	ARMOpcode = OBJECT (Decoder.Opcode)
	VAR
		argStructure : LONGINT;
		op, cond : LONGINT;
		ccUpdate : BOOLEAN;
		arg1, arg2, arg3, arg4, arg5, arg6 : ARMArg;

		PROCEDURE &New*(proc : Decoder.ProcedureInfo; stream : Streams.Writer);
		BEGIN
			New^(proc, stream);
			instr := -1;
			ccUpdate := FALSE;
			argStructure := none
		END New;

		PROCEDURE PrintOpcodeBytes (w : Streams.Writer);
		BEGIN
			w.Hex(op, 0)
		END PrintOpcodeBytes;

		PROCEDURE PrintInstruction (w : Streams.Writer);
		VAR str : ARRAY 20 OF CHAR; writeCondition, writeLSMAddrMode : BOOLEAN;
		BEGIN
			writeCondition := TRUE; writeLSMAddrMode := FALSE;
			CASE instr OF
				opADC : str := "ADC"
				| opADD : str := "ADD"
				| opAND : str := "AND"
				| opASR : str := "ASR"
				| opB : str := "B"
				| opBIC : str := "BIC"
				| opBKPT : str := "BKPT"
				| opBL : str := "BL"
				| opBLX : str := "BLX"; writeCondition := FALSE
				| opBX : str := "BX"
				| opCDP : str := "CDP"
				| opCDP2 : str := "CDP2"; writeCondition := FALSE
				| opCLZ : str := "CLZ"
				| opCMN : str := "CMN"
				| opCMP : str := "CMP"
				| opEOR : str := "EOR"
				| opLDC : str := "LDC"
				| opLDC2 : str := "LDC2"; writeCondition := FALSE
				| opLDM : str := "LDM"; writeLSMAddrMode := TRUE
				| opLDR : str := "LDR"
				| opLDRB : str := "LDRB"
				| opLDRBT : str := "LDRBT"
				| opLDRH : str := "LDRH"
				| opLDRSB : str := "LDRSB"
				| opLDRSH : str := "LDRSH"
				| opLDRT : str := "LDRT"
				| opLSL : str := "LSL"
				| opLSR : str := "LSR"
				| opMCR : str := "MCR"
				| opMCR2 : str := "MCR2"; writeCondition := FALSE
				| opMLA : str := "MLA"
				| opMOV : str := "MOV"
				| opMRC : str := "MRC"
				| opMRC2 : str := "MRC2"; writeCondition := FALSE
				| opMRS : str := "MRS"
				| opMSR : str := "MSR"
				| opMUL : str := "MUL"
				| opMVN : str := "MVN"
				| opORR : str := "ORR"
				| opROR : str := "ROR"
				| opRRX : str := "RRX"
				| opRSB : str := "RSB"
				| opRSC : str := "RSC"
				| opSBC : str := "SBC"
				| opSMLAL : str := "SMLAL"
				| opSMULL : str := "SMULL"
				| opSTC : str := "STC"
				| opSTC2 : str := "STC2"; writeCondition := FALSE
				| opSTM : str := "STM"; writeLSMAddrMode := TRUE
				| opSTR : str := "STR"
				| opSTRB : str := "STRB"
				| opSTRBT : str := "STRBT"
				| opSTRH : str := "STRH"
				| opSTRT : str := "STRT"
				| opSUB : str := "SUB"
				| opSWI : str := "SWI"
				| opSWP : str := "SWP"
				| opSWPB : str := "SWPB"
				| opTEQ : str := "TEQ"
				| opTST : str := "TST"
				| opUMLAL : str := "UMLAL"
				| opUMULL : str := "UMULL"
				| opUNDEFINED : str := "{UNDEFINED}"
			ELSE
				KernelLog.String("Unknown instr = "); KernelLog.Int(instr, 0); KernelLog.String(", op = "); KernelLog.Hex(op, -1); KernelLog.Ln;
				str := "[unknown]"
			END;
			w.String(str);
			IF writeCondition THEN PrintCondition(w) END;
			IF writeLSMAddrMode THEN PrintLSMAddrMode(w) END;
			IF ccUpdate THEN w.String("  S")
			ELSIF argStructure = ArgRegMem THEN
				w.String("  ");
				IF arg2(ARMArgMem).signed THEN w.Char('S') END;
				IF arg2(ARMArgMem).width = 1 THEN w.Char('B')
				ELSIF arg2(ARMArgMem).width = 2 THEN w.Char('H')
				END;
				IF arg2(ARMArgMem).translation THEN w.Char('T') END;
			END
		END PrintInstruction;

		PROCEDURE PrintCondition (w : Streams.Writer);
		VAR str : ARRAY 6 OF CHAR;
		BEGIN
			w.Char(' ');
			CASE cond OF
				EQ : str := "EQ"
				| NE : str := "NE"
				| CSHS : str := "CS/HS"
				| CCLO : str := "CC/LO"
				| MI : str := "MI"
				| PL : str := "PL"
				| VS : str := "VS"
				| VC : str := "VC"
				| HI : str := "HI"
				| LS : str := "LS"
				| GE : str := "GE"
				| LT : str := "LT"
				| GT : str := "GT"
				| LE : str := "LE"
				| AL : str := ""
				| NV : str := "NV"
			END;
			w.String(str)
		END PrintCondition;

		PROCEDURE PrintLSMAddrMode (w : Streams.Writer);
		VAR str : ARRAY 6 OF CHAR;
		BEGIN
			ASSERT(argStructure = ArgRegRList);
			w.Char(' ');
			CASE arg2(ARMArgRList).addrMode OF
				AddrModeIA : str := "IA"
				| AddrModeIB : str := "IB"
				| AddrModeDA : str := "DA"
				| AddrModeDB : str := "DB"
			ELSE str := ""
			END;
			w.String(str)
		END PrintLSMAddrMode;

		PROCEDURE PrintArguments (w : Streams.Writer);
		BEGIN
			(* KernelLog.String("*argStructure = "); KernelLog.Int(argStructure, 0); KernelLog.String(", instr = "); KernelLog.Int(instr, 0); KernelLog.Ln; *)
			CASE argStructure OF
				ArgNone :
				| ArgImm : WriteImm(arg1(ARMArgImm), w)
				| ArgReg : WriteReg(arg1(ARMArgReg), w)
				| ArgRegReg : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w)
				| ArgRegRList : WriteRegRList(arg1(ARMArgReg), arg2(ARMArgRList), w)
				| ArgRegImm : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteImm(arg2(ARMArgImm), w)
				| ArgRegShift : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteShift(arg2(ARMArgShift), w)
				| ArgRegMem : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteMem(arg2(ARMArgMem), w)
				| ArgRegRegReg : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteReg(arg3(ARMArgReg), w)
				| ArgRegRegImm : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteImm(arg3(ARMArgImm), w)
				| ArgRegRegShift : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteShift(arg3(ARMArgShift), w)
				| ArgRegRegMem : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteMem(arg3(ARMArgMem), w)
				| ArgRegRegRegReg : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteReg(arg3(ARMArgReg), w); w.String(", "); WriteReg(arg4(ARMArgReg), w)
				| ArgRegRegRegImm : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteReg(arg3(ARMArgReg), w); w.String(", "); WriteImm(arg4(ARMArgImm), w)
				| ArgRegRegRegShift : WriteReg(arg1(ARMArgReg), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteReg(arg3(ARMArgReg), w); w.String(", "); WriteShift(arg4(ARMArgShift), w)
				| ArgCProcRegMem : WriteCProc(arg1(ARMArgCProc), w); w.String(", "); WriteReg(arg2(ARMArgReg), w); w.String(", "); WriteMem(arg3(ARMArgMem), w)
				| ArgCProcImmRegRegRegImm : WriteCProc(arg1(ARMArgCProc), w); w.String(", "); WriteImm(arg2(ARMArgImm), w); w.String(", "); WriteReg(arg3(ARMArgReg), w);  w.String(", "); WriteReg(arg4(ARMArgReg), w); w.String(", "); WriteReg(arg5(ARMArgReg), w);  w.String(", "); WriteImm(arg2(ARMArgImm), w)
			ELSE
				KernelLog.String("argStructure = "); KernelLog.Int(argStructure, 0); KernelLog.Ln;
				w.String("{argStructure not specified!}")
			END
		END PrintArguments;

		PROCEDURE WriteImm (immArg : ARMArgImm; w :  Streams.Writer);
			PROCEDURE WriteHex;
			VAR absImm : LONGINT;
			BEGIN
				absImm := immArg.imm;
				IF immArg.rep = RepRelJmp THEN
					(* add opcode position and length of full opcode to immediate argument value *)
					INC(absImm, offset + 4)
				END;
				Hex(absImm, w)
			END WriteHex;

		BEGIN
			IF immArg.rep = RepInt THEN
				w.Int(immArg.imm, 0)
			ELSIF immArg.rep = RepHex THEN
				WriteHex
			ELSE
				w.Int(immArg.imm, 0);
				w.String(" (");
				WriteHex;
				w.Char(')')
			END
		END WriteImm;

		PROCEDURE WriteReg (regArg : ARMArgReg; w : Streams.Writer);
		BEGIN
			IF regArg.isCReg THEN
				w.String("CR"); w.Int(regArg.reg, 0)
			ELSE
				WriteRegSymbol(regArg.reg, w);
				IF regArg.reg >= CPSR THEN
					IF regArg.sregMask * {SRegC} # {} THEN w.String("c") END;
					IF regArg.sregMask * {SRegX} # {} THEN w.String("x") END;
					IF regArg.sregMask * {SRegS} # {} THEN w.String("s") END;
					IF regArg.sregMask * {SRegF} # {} THEN w.String("f") END
				END
			END
		END WriteReg;

		PROCEDURE WriteRegSymbol (reg : LONGINT; w : Streams.Writer);
		BEGIN
			CASE reg OF
				FP : w.String("FP")
				| SP : w.String("SP")
				| LR : w.String("LR")
				| PC : w.String("PC")
				| CPSR : w.String("CPSR")
				| SPSR : w.String("SPSR")
			ELSE
				w.Char('R'); w.Int(reg, 0)
			END
		END WriteRegSymbol;

		PROCEDURE WriteShiftSymbol (op : LONGINT; w : Streams.Writer);
		BEGIN
			CASE op OF
				Lsl : w.String("LSL ")
				| LSR : w.String("LSR ")
				| Asr : w.String("ASR ")
				| Ror : w.String("ROR ")
				| RRX : w.String("RRX ")
			END;
		END WriteShiftSymbol;


		PROCEDURE WriteShift (shiftArg : ARMArgShift; w :  Streams.Writer);
		BEGIN
			WriteShiftSymbol(shiftArg.operation, w);
			IF shiftArg.operation # RRX THEN
				IF shiftArg.reg THEN
					ASSERT(shiftArg.shiftImmOrReg < CPSR);
					WriteRegSymbol(shiftArg.shiftImmOrReg, w)
				ELSE
					w.Char('#');
					Hex(shiftArg.shiftImmOrReg, w)
				END
			END
		END WriteShift;

		PROCEDURE WriteMem (memArg : ARMArgMem; w : Streams.Writer);

			PROCEDURE WriteEnd;
			BEGIN
				IF memArg.regUpdate # RegUpdatePost THEN
					w.Char("]");
					IF memArg.regUpdate = RegUpdatePre THEN w.Char('!') END
				END
			END WriteEnd;
		BEGIN
			w.Char('[');
			WriteRegSymbol(memArg.reg, w);
			IF memArg.regUpdate = RegUpdatePost THEN w.Char(']') END;
			CASE memArg.addrMode OF
				AddrModeReg : w.Char(']')
				| AddrModeRegImm :
					w.String(", #");
					IF memArg.immOffs < 0 THEN w.Char('-'); Hex(-memArg.immOffs, w) ELSE Hex(memArg.immOffs, w) END;
					WriteEnd
				| AddrModeRegReg :
					w.String(", "); WriteRegSymbol(memArg.regOffs, w); WriteEnd
				| AddrModeRegRegScale : w.String(", "); WriteRegSymbol(memArg.regOffs, w); w.String(", "); WriteShiftSymbol(memArg.shift, w); w.String(" #"); w.Int(memArg.regScale, 0); WriteEnd
			END
		END WriteMem;

		PROCEDURE WriteRegRList (regArg : ARMArgReg; rListArg : ARMArgRList; w : Streams.Writer);
		VAR i, lastStart : LONGINT; notFirst : BOOLEAN;

			PROCEDURE PrintRegs (start, end : LONGINT);
			BEGIN
				IF start >= 0 THEN
					IF notFirst THEN w.String(", ") END;
					IF start < end THEN (* print range *)
						WriteRegSymbol(start, w); w.String(" - "); WriteRegSymbol(end, w)
					ELSE (* print single reg *)
						WriteRegSymbol(start, w)
					END;
					notFirst := TRUE
				END
			END PrintRegs;

		BEGIN
			WriteRegSymbol(regArg.reg, w);
			IF rListArg.addrMode # none THEN w.Char('!') END;
			w.String(", {");
			lastStart := -1;
			notFirst := FALSE;
			FOR i := 0 TO PC DO
				IF rListArg.regs * {i} # {} THEN IF lastStart < 0 THEN lastStart := i END
				ELSE
					PrintRegs(lastStart, i-1); lastStart := -1
				END;
			END;
			PrintRegs(lastStart, PC);
			w.Char('}')
		END WriteRegRList;

		PROCEDURE WriteCProc (cProcArg : ARMArgCProc; w : Streams.Writer);
		BEGIN
			w.Char('p'); w.Int(cProcArg.cproc, 0)
		END WriteCProc;
	END ARMOpcode;

	ARMDecoder = OBJECT (Decoder.Decoder)
	VAR
		bit24To27, bit20To23, bit16To19, bit12To15, bit8To11, bit4To7, bit0To3 : LONGINT;

		PROCEDURE NewOpcode() : Decoder.Opcode;
		VAR
			opcode : ARMOpcode;
		BEGIN
			NEW(opcode, currentProc, outputStreamWriter);
			RETURN opcode
		END NewOpcode;

		PROCEDURE DecodeThis(opcode : Decoder.Opcode);
		VAR
			armOpcode : ARMOpcode;
			opSet : SET;
			code, category : LONGINT;
		BEGIN
			armOpcode := opcode(ARMOpcode);
			armOpcode.op := ReadLInt();
			IF bigEndian THEN SwapBytes(armOpcode.op) END;
			opSet := SYSTEM.VAL(SET, armOpcode.op);
			(* KernelLog.String("op = "); KernelLog.Hex(armOpcode.op, 0); KernelLog.String(" -> "); *)

			code := armOpcode.op;
			bit0To3 := code MOD 10H; code := code DIV 10H;	(* split instruction *)
			bit4To7 := code MOD 10H; code := code DIV 10H;
			bit8To11 := code MOD 10H; code := code DIV 10H;
			bit12To15 := code MOD 10H; code := code DIV 10H;
			bit16To19 := code MOD 10H; code := code DIV 10H;
			bit20To23 := code MOD 10H; code := code DIV 10H;
			bit24To27 := code MOD 10H; code := code DIV 10H;
			armOpcode.cond := code MOD 10H;

			category := bit24To27 DIV 2;
			IF armOpcode.cond = 15 THEN
				IF category = 5 THEN
					BranchToThumb(armOpcode, armOpcode.op);
					RETURN
				ELSIF ((category = 7) & (bit24To27 = 0EH)) OR (category = 6) THEN (* not undefined *)
				ELSE
					armOpcode.instr := opUNDEFINED;
					armOpcode.argStructure := ArgNone;
					RETURN
				END
			END;
 			CASE category OF
				0 :
					IF (opSet * {4, 7}) = {4, 7} THEN
						MultipliesExtraLS(armOpcode)
					ELSIF (opSet * {20, 23, 24}) = {24} THEN Miscellaneous(armOpcode)
					ELSE DataProcessing(armOpcode)
					END
				| 1 :
					IF (opSet * {20, 21, 23, 24}) = {21, 24} THEN
						SRegTransfer(armOpcode)
					ELSIF (opSet * {20, 21, 23, 24}) = {24} THEN
						armOpcode.instr := opUNDEFINED;
						armOpcode.argStructure := ArgNone
					ELSE DataProcessing(armOpcode)
					END
				| 2 : LoadStore(armOpcode)
				| 3 :
					IF (opSet * {4}) = {4} THEN
						armOpcode.instr := opUNDEFINED;
						armOpcode.argStructure := ArgNone
					ELSE LoadStore(armOpcode)
					END
				| 4 : LoadStoreMultiple(armOpcode)
				| 5 : Branch(armOpcode)
				| 6 : CoprocLoadStoreDRegTransfer(armOpcode)
				| 7 : KernelLog.String("check2"); KernelLog.Ln;
					IF (opSet * {24}) = {24} THEN SoftwareInterrupt(armOpcode)
					ELSIF (opSet * {4}) = {4} THEN CoprocRegTransfer(armOpcode)
					ELSE CoprocDataProcessing(armOpcode)
					END
			END
		END DecodeThis;

		PROCEDURE DecodeShifterOperand(op : LONGINT; VAR argStructure : LONGINT; VAR arg1, arg2 : ARMArg);
		VAR
			Rm, shiftImmOrReg, operation, mode : LONGINT;
			regOp : BOOLEAN;
			regArg : ARMArgReg;
			immArg : ARMArgImm;
			shiftArg : ARMArgShift;
		BEGIN
			IF (SYSTEM.VAL(SET, op) * {25}) = {25} THEN (* I Bit *)
				argStructure := ArgImm;
				NEW(immArg, ROT(op MOD 100H, -2*bit8To11), RepHex); arg1 := immArg;
			ELSE
				Rm := op MOD 10H;
				NEW(regArg, Rm); arg1 := regArg;
				argStructure := ArgRegShift;
				mode := bit4To7 MOD 8; (* type of register addressing mode *)
				IF mode = 0 THEN (* Register / Logical shift left by immediate *)
					shiftImmOrReg := (op MOD 1000H) DIV 80H;
					IF shiftImmOrReg = 0 THEN argStructure := ArgReg
					ELSE
						NEW(shiftArg, Lsl, shiftImmOrReg, FALSE); arg2 := shiftArg
					END
				ELSIF ((op MOD 1000H) DIV 10H) = 6 THEN (* rotate right with extend *)
					NEW(shiftArg, RRX, 0, FALSE); arg2 := shiftArg
				ELSE
					CASE mode OF
						1 : operation := Lsl
						| 2,3 : operation := LSR
						| 4,5 : operation := Asr
						| 6,7 : operation := Ror
					END;
					IF ODD(mode) THEN
						regOp := TRUE;
						shiftImmOrReg := bit8To11
					ELSE
						regOp := FALSE;
						shiftImmOrReg := (op MOD 1000H) DIV 80H
					END;
					NEW(shiftArg, operation, shiftImmOrReg, regOp); arg2 := shiftArg
				END
			END
		END DecodeShifterOperand;

		PROCEDURE DataProcessing (opcode : ARMOpcode);
		VAR SBit : BOOLEAN; Rn, Rd, type : LONGINT;
			regArg : ARMArgReg; argSh1, argSh2 : ARMArg;
			shStruct : LONGINT;
		BEGIN
			CASE (opcode.op MOD 2000000H) DIV 200000H OF (* opcode *)
				0 : opcode.instr := opAND; type := 3
				| 1 : opcode.instr := opEOR; type := 3
				| 2 : opcode.instr := opSUB; type := 3
				| 3 : opcode.instr := opRSB; type := 3
				| 4 : opcode.instr := opADD; type := 3
				| 5 : opcode.instr := opADC; type := 3
				| 6 : opcode.instr := opSBC; type := 3
				| 7 : opcode.instr := opRSC; type := 3
				| 8 : opcode.instr := opTST; type := 2
				| 9 : opcode.instr := opTEQ; type := 2
				| 10 : opcode.instr := opCMP; type := 2
				| 11 : opcode.instr := opCMN; type := 2
				| 12 : opcode.instr := opORR; type := 3
				| 13 : opcode.instr := opMOV; type := 1
				| 14 : opcode.instr := opBIC; type := 3
				| 15 : opcode.instr := opMVN; type := 1
			END;
			DecodeShifterOperand(opcode.op, shStruct, argSh1, argSh2);
			IF (SYSTEM.VAL(SET, opcode.op) * {20}) = {20} THEN SBit := TRUE ELSE SBit := FALSE END;
			opcode.ccUpdate := SBit & (type # 2);
			Rn := bit16To19;
			Rd := bit12To15;
			IF (type = 1) OR (type = 2) THEN
				opcode.argStructure := shStruct + 10;
				IF type = 1 THEN NEW(regArg, Rd) ELSE NEW(regArg, Rn) END;
				opcode.arg1 := regArg; opcode.arg2 := argSh1; opcode.arg3 := argSh2
			ELSIF type = 3 THEN
				opcode.argStructure := shStruct + 20;
				NEW(regArg, Rd); opcode.arg1 := regArg;
				NEW(regArg, Rn); opcode.arg2 := regArg;
				opcode.arg3 := argSh1; opcode.arg4 := argSh2
			END
		END DataProcessing;

		PROCEDURE Miscellaneous (opcode : ARMOpcode);
		VAR regArg : ARMArgReg; immArg : ARMArgImm;
		BEGIN
			CASE bit4To7 MOD 2 OF
				0 : SRegTransfer(opcode)
				| 1 :
					IF bit20To23 = 6 THEN
						opcode.instr := opCLZ;
						opcode.argStructure := ArgRegReg;
						NEW(regArg, bit12To15); opcode.arg1 := regArg;
						NEW(regArg, bit0To3); opcode.arg2 := regArg
					ELSIF LSH(opcode.op, -20) = 0E12H THEN
						IF bit4To7 = 7 THEN
							opcode.instr := opBKPT;
							NEW(immArg, (((opcode.op MOD 100000) DIV 100H) * 10H) + (opcode.op MOD 10H), RepHex);
							opcode.argStructure := ArgImm;
							opcode.arg1 := immArg
						ELSIF bit4To7 = 1 THEN
							opcode.instr := opBX;
							NEW(regArg, bit0To3); opcode.arg1 := regArg;
							opcode.argStructure := ArgReg
						END
					END
			END
		END Miscellaneous;

		PROCEDURE MultipliesExtraLS (opcode : ARMOpcode);
		VAR op1: LONGINT;
			regA, regB, regC, regD : ARMArgReg;  memArg : ARMArgMem;
			argSh1, argSh2 : ARMArg;
			shStruct : LONGINT;
		BEGIN
			op1 := bit20To23 DIV 2;
			opcode.ccUpdate := (bit20To23 MOD 2) = 1; (* S bit set? *)
			NEW(regA, bit16To19);
			NEW(regB, bit12To15);
			NEW(regC, bit8To11);
			NEW(regD, bit0To3);
			IF bit24To27 = 1 THEN (* SWP/SWPB *)
				NEW(memArg, AddrModeReg, regA.reg);
				opcode.argStructure := ArgRegRegMem;
				opcode.arg1 := regB; opcode.arg2 := regD; opcode.arg3 := memArg;
				IF bit20To23 = 0 THEN opcode.instr := opSWP ELSE opcode.instr := opSWPB END
			ELSE
				opcode.argStructure := ArgRegRegRegReg;
				opcode.arg1 := regB; opcode.arg2 := regA; opcode.arg3 := regD; opcode.arg4 := regC;
				CASE op1 OF
					0 : opcode.instr := opMUL; opcode.argStructure := ArgRegRegReg; opcode.arg1 := regA; opcode.arg2 := regD; opcode.arg3 := regC
					| 1 : opcode.instr := opMLA; opcode.arg1 := regA; opcode.arg2 := regD; opcode.arg3 := regC; opcode.arg4 := regB
					| 3 : opcode.instr := opRSB; opcode.arg1 := regB; opcode.arg2 := regA; DecodeShifterOperand(opcode.op, shStruct, argSh1, argSh2); opcode.argStructure := shStruct + 20; opcode.arg3 := argSh1; opcode.arg4 := argSh2
					| 4 : opcode.instr := opUMULL
					| 5 : opcode.instr := opUMLAL
					| 6 : opcode.instr := opSMULL
					| 7 : opcode.instr := opSMLAL
				END
			END
		END MultipliesExtraLS;

		PROCEDURE SRegTransfer (opcode : ARMOpcode);
		VAR regArg : ARMArgReg; immArg : ARMArgImm;
		BEGIN
			opcode.argStructure := ArgRegReg;
			IF (bit20To23 DIV 4) = 1 THEN NEW(regArg, SPSR) ELSE NEW(regArg, CPSR) END;
			IF (bit20To23 MOD 4) # 2 THEN
				opcode.instr := opMRS;
				opcode.arg2 := regArg;
				NEW(regArg, bit12To15); opcode.arg1 := regArg
			ELSE
				opcode.instr := opMSR;
				regArg.sregMask := SYSTEM.VAL(SET, bit16To19);
				opcode.arg1 := regArg;
				IF (bit24To27 DIV 2) = 1 THEN (* immediate operand *)
					NEW(immArg, ROT(opcode.op MOD 100H, -2*bit8To11), RepHex); (* 8 bit imm rotated by rotate imm *)
					opcode.arg2 := immArg
				ELSE NEW(regArg, bit0To3); opcode.arg2 := regArg
				END
			END
		END SRegTransfer;

		PROCEDURE LoadStore (opcode : ARMOpcode);
		VAR regArg : ARMArgReg; memArg : ARMArgMem;
			P, L, W, B, U : BOOLEAN;
			offset12 : LONGINT;
		BEGIN
			opcode.argStructure := ArgRegMem;
			NEW(regArg, bit12To15); opcode.arg1 := regArg;
			P := bit24To27 MOD 2 = 1;
			L := bit20To23 MOD 2 = 1;
			W := (bit20To23 MOD 4) DIV 2 = 1;
			B := (bit20To23 MOD 8) DIV 4 = 1;
			U := bit20To23 DIV 8 = 1;
			offset12 := opcode.op MOD 1000H;
			(* determine memory location and addressing mode *)
			IF (bit24To27 DIV 2) = 2 THEN (* immediate offset/index *)
				IF offset12 = 0 THEN 	NEW(memArg, AddrModeReg, bit16To19)
				ELSE
					NEW(memArg, AddrModeRegImm, bit16To19);
					IF U THEN memArg.immOffs := offset12 ELSE memArg.immOffs := -offset12 END
				END
			ELSE (* register offset/index *)
				IF (bit4To7 = 0) & (bit8To11 = 0) THEN
					NEW(memArg, AddrModeRegReg, bit16To19); memArg.regOffs := bit0To3
				ELSE
					NEW(memArg, AddrModeRegRegScale, bit16To19); memArg.regOffs := bit0To3;
					memArg.shift :=  (bit4To7 MOD 8) DIV 2;
					memArg.regScale := (opcode.op MOD 1000H) DIV 80H
				END
			END;
			IF L THEN opcode.instr := opLDR ELSE opcode.instr := opSTR END;
			IF  ~P THEN (* P = 0, post index addressing *)
				IF memArg.addrMode # AddrModeReg THEN memArg.regUpdate := RegUpdatePost END;
				memArg.immOffs := opcode.op MOD 1000H;
			ELSE (* P = 1, offset or pre-indexed addressing *)
				IF W THEN (* base register update *)
					memArg.regUpdate := RegUpdatePre;
				END
			END;
			IF W THEN memArg.translation := TRUE END;
			IF B THEN memArg.width := 1 END;
			opcode.arg2 := memArg
		END LoadStore;

		PROCEDURE LoadStoreMultiple (opcode : ARMOpcode);
		VAR regArg : ARMArgReg; regListArg : ARMArgRList;
			P, U, S, W, L : BOOLEAN;
		BEGIN
			P := bit24To27 MOD 2 = 1;
			U := bit20To23 DIV 8 = 1;
			S := (bit20To23 MOD 8) DIV 4 = 1;
			W := (bit20To23 MOD 4) DIV 2 = 1;
			L := bit20To23 MOD 2 = 1;
			IF L THEN opcode.instr := opLDM ELSE opcode.instr := opSTM END;
			NEW(regArg, bit16To19);
			NEW(regListArg, SYSTEM.VAL(SET, opcode.op MOD 10000H));
			IF W THEN
				IF P THEN IF U THEN regListArg.addrMode := AddrModeIB ELSE regListArg.addrMode := AddrModeDB END
				ELSE IF U THEN regListArg.addrMode := AddrModeIA ELSE regListArg.addrMode := AddrModeDA END
				END
			ELSE regListArg.addrMode := none END;
			opcode.argStructure := ArgRegRList;
			opcode.arg1 := regArg;
			opcode.arg2 := regListArg
		END LoadStoreMultiple;

		PROCEDURE Branch (opcode : ARMOpcode);
		VAR immArg : ARMArgImm;
		BEGIN
			IF (SYSTEM.VAL(SET, opcode.op) * {24}) = {24} THEN opcode.instr := opBL
			ELSE opcode.instr := opB
			END;
			opcode.argStructure := ArgImm;
			NEW(immArg, (opcode.op MOD 1000000H), RepRelJmp);
			SignExtension(immArg.imm, 24);
			immArg.imm := (immArg.imm + 1) *4;
			opcode.arg1 := immArg
		END Branch;

		PROCEDURE BranchToThumb (opcode : ARMOpcode; op : LONGINT);
		VAR sImmed24, targetAddr : LONGINT; immArg : ARMArgImm; regArg : ARMArgReg;
		BEGIN
			opcode.instr := opBLX;
			IF opcode.cond = 15 THEN
				sImmed24 := opcode.op MOD 1000000H;
				targetAddr := (bit24To27 MOD 2)*2 + ASH(LSH(sImmed24, 8), -6); (* sign extend *)
				NEW(immArg, targetAddr, RepRelJmp); opcode.arg1 := immArg;
				opcode.argStructure := ArgImm
			ELSE
				NEW(regArg, bit0To3); opcode.arg1 := regArg;
				opcode.argStructure := ArgReg
			END
		END BranchToThumb;

		PROCEDURE CoprocLoadStoreDRegTransfer (opcode : ARMOpcode);
		VAR cProcArg : ARMArgCProc; memArg : ARMArgMem; regArg : ARMArgReg;
			P, U, W, mul4 : BOOLEAN;
		BEGIN
			IF (bit20To23 MOD 2) = 1 THEN opcode.instr := opLDC ELSE opcode.instr := opSTC END;
			P := (bit24To27 MOD 2) = 1; (* P bit *)
			U := (bit20To23 DIV 8) = 1; (* U bit *)
			W := ((bit20To23 MOD 4) DIV 2) = 1; (* W bit *)
			mul4 := TRUE;
			opcode.argStructure := ArgCProcRegMem;
			NEW(memArg, AddrModeRegImm, bit16To19);
			IF P THEN
				memArg.regUpdate := RegUpdatePost;
				IF ~W THEN mul4 := FALSE END (* this is the option argument, therefore it is not multiplied by 4, but represented the same way like a post update offset *)
			ELSE
				IF W THEN memArg.regUpdate := RegUpdatePre
				ELSE memArg.regUpdate := RegUpdateNone
				END
			END;
			IF U THEN memArg.immOffs := (opcode.op MOD 100H) ELSE memArg.immOffs := - (opcode.op MOD 100H) END;
			IF mul4 THEN memArg.immOffs := memArg.immOffs * 4 END;
			NEW(cProcArg, bit8To11); opcode.arg1 := cProcArg;
			NEW(regArg, bit12To15); regArg.isCReg := TRUE;
			opcode.arg1 := cProcArg; opcode.arg2 := regArg; opcode.arg3 := memArg
		END CoprocLoadStoreDRegTransfer;

		PROCEDURE CoprocDataProcessing (opcode : ARMOpcode);
		BEGIN
			CoprocRegTransfer(opcode);
			IF opcode.cond = 15 THEN opcode.instr := opCDP2 ELSE opcode.instr := opCDP END;
			opcode.arg2(ARMArgImm).imm := bit20To23
		END CoprocDataProcessing;

		PROCEDURE CoprocRegTransfer (opcode : ARMOpcode);
		VAR immArg : ARMArgImm; regArg : ARMArgReg; cProcArg : ARMArgCProc;
		BEGIN
			IF (bit20To23 MOD 2) = 1 THEN
				IF opcode.cond = 15 THEN opcode.instr := opMRC2 ELSE opcode.instr := opMRC END
			ELSE
				IF opcode.cond = 15 THEN opcode.instr := opMCR2 ELSE opcode.instr := opMCR END
			END;
			opcode.argStructure := ArgCProcImmRegRegRegImm;
			NEW(cProcArg, bit8To11); opcode.arg1 := cProcArg;
			NEW(immArg, bit20To23 DIV 2, RepInt); opcode.arg2 := immArg; (* opcode-1 *)
			NEW(regArg, bit12To15); opcode.arg3 := regArg;
			NEW(regArg, bit16To19); regArg.isCReg := TRUE; opcode.arg4 := regArg;
			NEW(regArg, bit0To3); regArg.isCReg := TRUE; opcode.arg5 := regArg;
			NEW(immArg, bit4To7 DIV 2, RepInt); opcode.arg6 := immArg
		END CoprocRegTransfer;

		PROCEDURE SoftwareInterrupt (opcode : ARMOpcode);
		VAR immArg : ARMArgImm;
		BEGIN
			NEW(immArg, opcode.op MOD 1000000H, RepHex);
			opcode.instr := opSWI;
			opcode.argStructure := ArgImm;
			opcode.arg1 := immArg
		END SoftwareInterrupt;

		PROCEDURE SignExtension (VAR x : LONGINT; length : LONGINT);
		BEGIN
			ASSERT((length > 0) & (length <= 32));
			x := LSH(x, 32-length);
			x := ASH(x, length-32)
		END SignExtension;
	END ARMDecoder;

VAR
	bigEndian : BOOLEAN;

PROCEDURE SetBigEndian*;
BEGIN
	bigEndian := TRUE;
END SetBigEndian;

PROCEDURE SetLittleEndian*;
BEGIN
	bigEndian := FALSE;
END SetLittleEndian;

PROCEDURE Hex(n: LONGINT; w : Streams.Writer); (* procedure from PCARMDecoder.Mod *)
 	VAR i, j: INTEGER; s, t : ARRAY 10 OF CHAR;
BEGIN
	i := 0;
	REPEAT
		IF n MOD 10H < 10 THEN s[i] := CHR(n MOD 10H +ORD("0")) ELSE s[i] := CHR(n MOD 10H - 10 + ORD("A")) END;
		n := n DIV 10H MOD 10000000H; INC(i);
	UNTIL n = 0;
	j := 0;
	WHILE i>0 DO DEC(i); t[j] := s[i]; INC(j) END; t[j]:="H"; t[j+1] := 0X;
	w.String(t)
END Hex;

PROCEDURE SwapBytes(VAR code: LONGINT);
TYPE Opcode = ARRAY 4 OF CHAR;
VAR opcode: Opcode;
	tmp: CHAR;
BEGIN
	opcode := SYSTEM.VAL(Opcode, code);
	tmp := opcode[0]; opcode[0] := opcode[3]; opcode[3] := tmp;
	tmp := opcode[1]; opcode[1] := opcode[2]; opcode[2] := tmp;
	code := SYSTEM.VAL(LONGINT, opcode);
END SwapBytes;

PROCEDURE ARMDecoderFactory (reader : Streams.Reader) : Decoder.Decoder;
VAR
	armDecoder : ARMDecoder;
BEGIN
	NEW(armDecoder, reader);
	RETURN armDecoder
END ARMDecoderFactory;

PROCEDURE CodeScaleCallback(VAR codeSize: LONGINT);
BEGIN
	codeSize := codeSize * 4
END CodeScaleCallback;

PROCEDURE Init*;
BEGIN
	Decoder.RegisterDecoder("Oba", ARMDecoderFactory, CodeScaleCallback);
	KernelLog.String("ARMDecoder installed."); KernelLog.Ln;
END Init;

BEGIN
	bigEndian := FALSE;
END ARMDecoder.