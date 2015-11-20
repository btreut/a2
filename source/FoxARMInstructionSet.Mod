MODULE FoxARMInstructionSet; (** AUTHOR ""; PURPOSE ""; *)

IMPORT D := Debugging, Commands, Streams, Files, BinaryCode := FoxBinaryCode, Disassembler := FoxDisassembler, BitSets, Options, Strings, ObjectFile;

CONST
	TraceDecode= FALSE;

	None*= -1;

	(* condition codes, values refer to encoding, do not modify *)
	conditionEQ*= 0;
	conditionNE*= 1;
	conditionCS*= 2;
	conditionHS*= 2;
	conditionCC*= 3;
	conditionLO*= 3;
	conditionMI*= 4;
	conditionPL*= 5;
	conditionVS*= 6;
	conditionVC*= 7;
	conditionHI*= 8;
	conditionLS*= 9;
	conditionGE*= 10;
	conditionLT*= 11;
	conditionGT*= 12;
	conditionLE*= 13;
	conditionAL*= 14;
	unconditional*= conditionAL;
	conditionNV*= 15;
	NumberConditionEntries*= 18;

	(* indexing flags, values have no meaning in encoding *)
	Increment*= 0;
	Decrement*= 1;
	PostIndexed*= 2;
	PreIndexed*= 3;

	(* mnemonics, values have no meaning for encoding
		FoxProgTools.Enum -l=4  opADC opADD opAND opB opBIC opBKPT opBL opBLX opBX opCDP opCDP2
		opCLZ opCMN opCMP opEOR
		opFABSD opFABSS opFADDD opFADDS opFCMPD
		opFCMPED opFCMPES opFCMPEZD opFCMPEZS
		opFCMPS opFCMPZD opFCMPZS opFCPYD opFCPYS opFCVTDS opFCVTSD
		opFDIVD opFDIVS opFLDD
		opFLDMIAD opFLDMIAS opFLDMIAX opFLDMDBD opFLDMDBS opFLDMDBX
		opFLDS
		opFMACD opFMACS opFMDHR opFMDLR opFMRDH opFMRDL opFMRS opFMRX
		opFMSCD opFMSCS opFMSR opFMSTAT opFMULD opFMULS opFMXR opFNEGD opFNEGS
		opFNMACD opFNMACS opFNMSCD opFNMSCS opFNMULD opFNMULS
		opFSITOD opFSITOS opFSQRTD opFSQRTS opFSTD opFSTMIAD opFSTMIAS opFSTMIAX opFSTMDBD opFSTMDBS opFSTMDBX
		opFSTS opFSUBD opFSUBS opFTOSID opFTOSIZD opFTOSIS opFTOSIZS opFTOUID opFTOUIZD opFTOUIS opFTOUIZS opFUITOD
		opFUITOS
		opLDC opLDC2 opLDM opLDR opMCR opMCR2
		opMCRR
		opMLA opMOV opMRC opMRC2 opMRRC
		opMRS opMSR opMUL opMVN opORR opPLD opQADD opQDADD opQDSUB opQSUB
		opRSB opRSC opSBC opSMLABB opSMLABT
		opSMLAL
		opSMLATB opSMLATT
		opSMLALBB opSMLALBT opSMLALTB opSMLALTT
		opSMLAWB opSMLAWT
		opSMULBB opSMULBT opSMULTB opSMULTT
		opSMULWB opSMULWT opSMULL
		opSTC opSTC2
		opSTM opSTR opSUB opSWI opSWP opTEQ opTST opUMLAL opUMULL

		NumberMnemonics ~
	*)

	opADC*= 0; opADD*= 1; opAND*= 2; opB*= 3;
	opBIC*= 4; opBKPT*= 5; opBL*= 6; opBLX*= 7;
	opBX*= 8; opCDP*= 9; opCDP2*= 10; opCLZ*= 11;
	opCMN*= 12; opCMP*= 13; opEOR*= 14; opFABSD*= 15;
	opFABSS*= 16; opFADDD*= 17; opFADDS*= 18; opFCMPD*= 19;
	opFCMPED*= 20; opFCMPES*= 21; opFCMPEZD*= 22; opFCMPEZS*= 23;
	opFCMPS*= 24; opFCMPZD*= 25; opFCMPZS*= 26; opFCPYD*= 27;
	opFCPYS*= 28; opFCVTDS*= 29; opFCVTSD*= 30; opFDIVD*= 31;
	opFDIVS*= 32; opFLDD*= 33; opFLDMIAD*= 34; opFLDMIAS*= 35;
	opFLDMIAX*= 36; opFLDMDBD*= 37; opFLDMDBS*= 38; opFLDMDBX*= 39;
	opFLDS*= 40; opFMACD*= 41; opFMACS*= 42; opFMDHR*= 43;
	opFMDLR*= 44; opFMRDH*= 45; opFMRDL*= 46; opFMRS*= 47;
	opFMRX*= 48; opFMSCD*= 49; opFMSCS*= 50; opFMSR*= 51;
	opFMSTAT*= 52; opFMULD*= 53; opFMULS*= 54; opFMXR*= 55;
	opFNEGD*= 56; opFNEGS*= 57; opFNMACD*= 58; opFNMACS*= 59;
	opFNMSCD*= 60; opFNMSCS*= 61; opFNMULD*= 62; opFNMULS*= 63;
	opFSITOD*= 64; opFSITOS*= 65; opFSQRTD*= 66; opFSQRTS*= 67;
	opFSTD*= 68; opFSTMIAD*= 69; opFSTMIAS*= 70; opFSTMIAX*= 71;
	opFSTMDBD*= 72; opFSTMDBS*= 73; opFSTMDBX*= 74; opFSTS*= 75;
	opFSUBD*= 76; opFSUBS*= 77; opFTOSID*= 78; opFTOSIZD*= 79;
	opFTOSIS*= 80; opFTOSIZS*= 81; opFTOUID*= 82; opFTOUIZD*= 83;
	opFTOUIS*= 84; opFTOUIZS*= 85; opFUITOD*= 86; opFUITOS*= 87;
	opLDC*= 88; opLDC2*= 89; opLDM*= 90; opLDR*= 91;
	opMCR*= 92; opMCR2*= 93; opMCRR*= 94; opMLA*= 95;
	opMOV*= 96; opMRC*= 97; opMRC2*= 98; opMRRC*= 99;
	opMRS*= 100; opMSR*= 101; opMUL*= 102; opMVN*= 103;
	opORR*= 104; opPLD*= 105; opQADD*= 106; opQDADD*= 107;
	opQDSUB*= 108; opQSUB*= 109; opRSB*= 110; opRSC*= 111;
	opSBC*= 112; opSMLABB*= 113; opSMLABT*= 114; opSMLAL*= 115;
	opSMLATB*= 116; opSMLATT*= 117; opSMLALBB*= 118; opSMLALBT*= 119;
	opSMLALTB*= 120; opSMLALTT*= 121; opSMLAWB*= 122; opSMLAWT*= 123;
	opSMULBB*= 124; opSMULBT*= 125; opSMULTB*= 126; opSMULTT*= 127;
	opSMULWB*= 128; opSMULWT*= 129; opSMULL*= 130; opSTC*= 131;
	opSTC2*= 132; opSTM*= 133; opSTR*= 134; opSUB*= 135;
	opSWI*= 136; opSWP*= 137; opTEQ*= 138; opTST*= 139;
	opUMLAL*= 140; opUMULL*= 141;
	(* Usual mnemonics, cont'd *)
	opISB* = 142;

	(* NEON mnemonics *)
	opVADD* = 143;
	opVADDL* = 144;
	opVADDW* = 145;
	opVMUL* = 146;
	opVMULL* = 147;
	opVMSR* = 148;
	opVMRS* = 149;
	opVLDR* = 150;
	opVSTR* = 151;
	opVDIV* = 152;
	opVMLA* = 153;
	opVMLS* = 154;
	opVMIN* = 155;
	opVMAX* = 156;
	opVSUB* = 157;
	opVABS* = 158;
	opVABD* = 159;
	
	(* Usual shifts *)
	opLSL* = 160;
	opLSR* = 161;

	(* More NEON *)
	opVLD1* = 162;
	opVST1* = 163;
	opVPADD* = 164;
	opVMOV* = 165;
	
	(* Non NEON Instructions *)
	opSEV* = 166;
	opDSB* = 167;
	opLDREX* = 168;
	opSTREX* = 169;
	opADR* = 170;
	opLDREXB* = 171;
	opSTREXB* = 172;
	opDMB* = 173;
	opCLREX* = 174;
	opREV* = 175;
	opREV16* = 176;
	opUXTH* = 177;
	opWFE* = 178;
	opWFI* = 179;

	NumberMnemonics*= 180;

	MaxOperands* = 6;

	(* flags values have no meaning for encoding
	FoxProgTools.Enum -l= 4
		flagB flagBT flagD flagDA flagDB flagH flagIA flagIB flagL flagS flagSB flagSH flagT
		NumberFlags flagCondition flagUserMode flagBaseRegisterUpdate ~
	*)
	flagB*= 0; flagBT*= 1; flagD*= 2; flagDA*= 3;
	flagDB*= 4; flagH*= 5; flagIA*= 6; flagIB*= 7;
	flagL*= 8; flagS*= 9; flagSB*= 10; flagSH*= 11;
	flagT*= 12;
	(*NumberFlags*= 13;*)
	(* NEON data type flags *)
	flagNEON8bits = 13; flagNEON16bits = 14; flagNEON32bits = 15; flagNEON64bits = 16;
	flagNEONInt = 17; flagNEONSigned = 18; flagNEONUnsigned = 19;
	flagNEONFloat = 20; flagNEONPoly = 21; flagNEONUndef = 22;

	NumberFlags* = 23;

	(* Flags not used *)
	flagCondition*= 23; flagUserMode*= 24;
	flagBaseRegisterUpdate*= 25;	

	NumberInstructions= NumberMnemonics + 19;

	(* encoding types, values have no meaning for encoding
		FoxProgTools.Enum -l=4
			encodingR16 encodingR12 encodingR8 encodingR0
			encodingAddressingMode1
			encodingAddressingMode2
			encodingAddressingMode3
			encodingAddressingMode5
			encodingCoprocessor encodingCR0 encodingCR12 encodingCR16
			encodingOpcode20 encodingOpcode21 encodingOpcode5 encodingOpcode4 encodingSignedImm24 encodingImm24 encodingImm16 encodingRotImm8 encodingRegisterList
			encodingPSR encodingFields
			encodingDR0 encodingDR12 encodingDR16
			encodingFR0 encodingFR12 encodingFR16
			encodingDRegisterList encodingFRegisterList encodingAddressingMode5V
			~
	*)
	encodingR16= 0; encodingR12= 1; encodingR8= 2; encodingR0= 3;
	encodingAddressingMode1= 4; encodingAddressingMode2= 5; encodingAddressingMode3= 6; encodingAddressingMode5= 7;
	encodingCoprocessor= 8; encodingCR0= 9; encodingCR12= 10; encodingCR16= 11;
	encodingOpcode20= 12; encodingOpcode21= 13; encodingOpcode5= 14; encodingOpcode4= 15;
	encodingSignedImm24= 16; encodingImm24= 17; encodingImm16= 18; encodingRotImm8= 19;
	encodingRegisterList= 20; encodingPSR= 21; encodingFields= 22; encodingDR0= 23;
	encodingDR12= 24; encodingDR16= 25; encodingFR0= 26; encodingFR12= 27;
	encodingFR16= 28; encodingDRegisterList= 29; encodingFRegisterList= 30; encodingAddressingMode5V= 31;

	(* NEON operand encoding. *)
	encodingNEONQd = 32; encodingNEONQn = 33; encodingNEONQm = 34;
	encodingNEONDd = 35; encodingNEONDn = 36; encodingNEONDm = 37;
	encodingNEONSd = 38; encodingNEONSn = 39; encodingNEONSm = 40;
	encodingNEONImmAndSize = 41; encodingNEON8bitImm = 42; (*at bit 0 *)
	encodingNEON3bitImm = 43;
	encodingNEONQorDd = 44; encodingNEONQorDn = 45; encodingNEONQorDm = 46;
	encodingNEONDorSd = 47; encodingNEONDorSn = 48; encodingNEONDorSm = 49;
	encodingNEONDRegList = 50; encodingNEONSysReg = 51; encodingNEONSigned8bitImm = 52;
	
	encodingImm7to11 = 53;

	(* NEON instruction mode encoding. These modes are used in EnterNEONInstruction. Values do not matter for encoding.
		The values mean (see the ARM manual):
		encodeNEON...
			...3RegSame: 3 registers of the same type
			...3RegDiff: 3 registers of different types
			...2RegScalar: 2 registers and a scalar
			...2RegShift: 2 registers and a shift
			...2RegMisc: 2 registers miscellanous
			...1RegImm: 1 register and an immediate
			...VFP: VFP operation
			...LS: load and stores
			...Tx32: transfers up to 32bits
			...Tx64: transfers of 64bits
	encodeNEON3RegSame = 0; encodeNEON3RegLong = 1; encodeNEON3RegNarrow = 2; encodeNEON3RegWide = 3;
	encodeNEON2RegScalar = 4; encodeNEON2RegScalarLong = 5;
	encodeNEON2RegShift = 6; encodeNEON2RegShiftNarrow = 7; encodeNEON2RegShiftLong = 8;
	encodeNEON2RegMisc = 9; encodeNEON2RegMiscNarrow = 10; encodeNEON2RegMiscLong = 11;
	encodeNEONVFP = 12; encodeNEONVFP2Reg = 13; encodeNEONVFP1Reg = 14;*)

	(* operand modes
		FoxProgTools.Enum -l= 4 modeImmediate modeRegister modeMemory	modeOpcode modeCoprocessor
			modeRegisterList modeFields modeOption
			~
	*)
	modeImmediate*= 0; modeRegister*= 1; modeMemory*= 2; modeOpcode*= 3;
	modeCoprocessor*= 4; modeRegisterList*= 5; modeRegisterWithFields*= 6; modeOption*= 7;

	(* registers, values have no meaning for encoding *)

	(* regular registers: *)
	R0*= 0; R1*= R0+1; R2*= R0+2; R3*= R0+3; R4*= R0+4; R5*= R0+5; R6*= R0+6; R7*= R0+7;
	R8*= R0+8; R9*= R0+9; R10*= R0+10; R11*= R0+11; R12*= R0+12; R13*= R0+13; R14*= R0+14; R15*= R0+15;

	(* coprocessor registers: *)
	CR0*= 16; CR1*= CR0+1; CR2*= CR0+2; CR3*= CR0+3; CR4*= CR0+4; CR5*= CR0+5; CR6*= CR0+6; CR7*= CR0+7;
	CR8*= CR0+8; CR9*= CR0+9; CR10*= CR0+10; CR11*= CR0+11; CR12*= CR0+12; CR13*= CR0+13; CR14*= CR0+14; CR15*= CR0+15;

	(* VFP double-precision registers: *)
	DR0*= 32; DR1*= DR0+1; DR2*= DR0+2; DR3*= DR0+3; DR4*= DR0+4; DR5*= DR0+5; DR6*= DR0+6; DR7*= DR0+7;
	DR8*= DR0+8; DR9*= DR0+9; DR10*= DR0+10; DR11*= DR0+11; DR12*= DR0+12; DR13*= DR0+13; DR14*= DR0+14; DR15*= DR0+15;
	(* Advanced SIMD doubleword registers *)
	DR16*= DR0+16; DR17*= DR0+17; DR18*= DR0+18; DR19*= DR0+19; DR20*= DR0+20; DR21*= DR0+21; DR22*= DR0+22;
	DR23*= DR0+23; DR24*= DR0+24; DR25*= DR0+25; DR26*= DR0+26; DR27*= DR0+27; DR28*= DR0+28; DR29*= DR0+29;
	DR30*= DR0+30; DR31*= DR0+31;

	(* VFP single-precision registers: *)
	SR0*= 64; SR1*= SR0+1; SR2*= SR0+2; SR3*= SR0+3; SR4*= SR0+4; SR5*= SR0+5; SR6*= SR0+6; SR7*= SR0+7;
	SR8*= SR0+8; SR9*= SR0+9; SR10*= SR0+10; SR11*= SR0+11; SR12*= SR0+12; SR13*= SR0+13; SR14*= SR0+14; SR15*= SR0+15;

	(* progran status registers *)
	CPSR*= 80; SPSR*= 81;

	(* Continue at 82 to skip CPSR and SPSR *)
	SR16*= 82; SR17*= SR0+17; SR18*= SR0+18; SR19*= SR0+19; SR20*= SR0+20; SR21*= SR0+21; SR22*= SR0+22; SR23*= SR0+23;
	SR24*= SR0+24; SR25*= SR0+25; SR26*= SR0+26; SR27*= SR0+27; SR28*= SR0+28; SR29*= SR0+29; SR30*= SR0+30; SR31*= SR0+31;
	
	(* NEON SIMD quadword registers *)
	QR0* = 98; QR1* = QR0 + 1; QR2* = QR0 + 2;QR3* = QR0 + 3; QR4* = QR0 + 4; QR5* = QR0 + 5; QR6* = QR0 + 6;
	QR7* = QR0 + 7; QR8* = QR0 + 8; QR9* = QR0 + 9; QR10* = QR0 + 10; QR11* = QR0 + 11; QR12* = QR0 + 12;
	QR13* = QR0 + 13; QR14* = QR0 + 14; QR15* = QR0 + 15;

	(* NEON System Registers *)
	FPSID* = 114; FPSCR* = 115; FPEXC* = 116;

	(* register aliases *)
	PC*= R15; LR*= R14; SP*= R13; FP*= R12; RESHI *= R1; RES *= R0; RESFS *= SR0;

	NumberRegisters*= 117; (* the number of physical registers *)
	NumberRegisterEntries*= 123; (* the number of register names *)

	(* shifts, do not modify:  nunbers as in encoding*)
	shiftLSL*= 0;
	shiftLSR*= 1;
	shiftASR*= 2;
	shiftROR*= 3;
	shiftRRX*= 4;
	NumberShifts*= 5;

	(* coprocessors, do not modify: number as in encoding *)
	CP0* = 0; CP1* = 1; CP2* = 2; CP3* = 3; CP4* = 4; CP5* = 5; CP6* = 6; CP7* = 7;
	CP8* = 8; CP9* = 9; CP10* = 10; CP11* = 11; CP12* = 12; CP13* = 13; CP14* = 14; CP15* = 15;
	NumberCoprocessors* = 16;

	(* fields, do not modify: number order as in encoding *)
	fieldC* = 0;
	fieldX* = 1;
	fieldS* = 2;
	fieldF* = 3;

	Bits12*=4096;
	Bits10*=1024;
	Bits7*=128;
	Bits5*=32;

	(*
	ArmEncoding *= 0;
	ThumbEncoding *= 1;
	*)

	TYPE
		Name = ARRAY 10 OF CHAR;

		Entry = RECORD
			name: Name;
			number: LONGINT
		END;

		Mnemonic= RECORD
			name: Name;
			number: INTEGER;
			firstInstructionFormat, lastInstructionFormat: LONGINT; (* instructionFormats *)
		END;

		InstructionFormat= RECORD
			mnemonic: INTEGER;
			opcode, mask: SET;
			flags: SET;
			operands: ARRAY MaxOperands OF INTEGER;
			(* NEON specific *)
			isNEON: BOOLEAN;
			Unsigned, Quadword, Length, Float, Operation: SET;
			SizeH: INTEGER; (* The lower bit is SizeH - 1 *)
		END;

		Instruction*= RECORD
			format: LONGINT;
			condition: LONGINT;
			flags: SET;
			operands: ARRAY  MaxOperands OF Operand;
		END;

		Operand*= RECORD
			mode*: INTEGER;
			register*: LONGINT;
			immediate*, shiftImmediate: LONGINT;
			shiftRegister: LONGINT;
			shiftMode: INTEGER;
			offsetImmediate: LONGINT;
			offsetRegister: LONGINT;
			indexing: SET; (* Increment, Decrement, PostIndexed PreIndexed*)
			registerList: SET;
			coprocessor: INTEGER;
			opcode: LONGINT;
			fields: SET;
			option: LONGINT;
			fixup-: BinaryCode.Fixup;
		END;

	VAR
		mnemonics: ARRAY NumberMnemonics OF Mnemonic;
		registerEntries: ARRAY NumberRegisterEntries OF Entry;
		conditionEntries: ARRAY NumberConditionEntries OF Entry;
		flagNames: ARRAY NumberFlags OF Name;
		shiftNames: ARRAY NumberShifts OF Name;
		coprocessorNames: ARRAY NumberCoprocessors OF Name;
		instructionFormats : ARRAY NumberInstructions OF InstructionFormat;

	(** get the number of a register by its name
		- 'None' is returned if no such register exists
	**)
	PROCEDURE RegisterNumberFromName*(registerName: ARRAY OF CHAR): LONGINT;
	VAR
		result, i: LONGINT;
	BEGIN
		Strings.UpperCase(registerName);
		result := None;
		(* go through all registers *)
		FOR i := 0 TO NumberRegisterEntries - 1 DO
			IF registerEntries[i].name = registerName THEN result := registerEntries[i].number END
		END;
		RETURN result
	END RegisterNumberFromName;

	(** get the number of a coprocessor by its name
		- 'None' is returned if no such mode exists
	**)
	PROCEDURE CoprocessorNumberFromName*(coprocessorName: ARRAY OF CHAR): LONGINT;
	VAR
		result, i: LONGINT;
	BEGIN
		Strings.UpperCase(coprocessorName);
		result := None;
		(* go through all coprocessors *)
		FOR i := 0 TO NumberCoprocessors - 1 DO
			IF coprocessorNames[i] = coprocessorName THEN result := i END
		END;
		RETURN result
	END CoprocessorNumberFromName;

	(** get the number of a shift mode by its name
		- 'None' is returned if no such mode exists
	**)
	PROCEDURE ShiftModeNumberFromName*(shiftModeName: ARRAY OF CHAR): LONGINT;
	VAR
		result, i: LONGINT;
	BEGIN
		Strings.UpperCase(shiftModeName);
		result := None;
		(* go through all shift modes *)
		FOR i := 0 TO NumberShifts - 1 DO
			IF shiftNames[i] = shiftModeName THEN result := i END
		END;
		RETURN result
	END ShiftModeNumberFromName;

	PROCEDURE FindMnemonic*(CONST name: ARRAY OF CHAR; VAR mnemonic, condition: LONGINT; VAR flags: SET): BOOLEAN;
	VAR i, pos, flagPos, format: LONGINT;

		PROCEDURE Contains(CONST this: ARRAY OF CHAR): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			ASSERT(this # "");
			i := 0;
			WHILE (name[pos+i] # 0X) & (this[i] # 0X) & (CAP(name[i+pos])= this[i]) DO INC(i) END;
			IF this[i]= 0X THEN
				INC(pos, i);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END Contains;

	BEGIN
		ASSERT(name # "");
		mnemonic := NumberMnemonics;
		REPEAT
			DEC(mnemonic);
			flags := {};
			pos := 0;
			(* find matching mnemonic, not necessarily unique! *)
			WHILE (mnemonic >= 0) & ~Contains(mnemonics[mnemonic].name) DO DEC(mnemonic) END;
			IF mnemonic >= 0 THEN
				flagPos := pos;
				format := mnemonics[mnemonic].firstInstructionFormat;
				(* found mnemonic, check if flags match with at least one format *)
				REPEAT
					ASSERT(instructionFormats[format].mnemonic = mnemonic);
					pos := flagPos;
					(* conditions *)
					IF flagCondition IN instructionFormats[format].flags THEN
						(* read condition *)
						i := NumberConditionEntries-1;
						WHILE (i>= 0) &~Contains(conditionEntries[i].name) DO DEC(i) END;
						IF i # -1 THEN
							INCL(flags, flagCondition);
							condition := conditionEntries[i].number
						ELSE
							condition := conditionAL (* no condition: always execute *)
						END;
					ELSE
						condition := conditionAL
					END;
					(* read flags, have to go downward because of name inclusions  *)
					i := NumberFlags-1;
					WHILE (i>=0) & (name[pos] # 0X) DO
						IF (i IN instructionFormats[format].flags) & Contains(flagNames[i]) THEN INCL(flags, i) END;
						DEC(i);
					END;
					INC(format);
				UNTIL (format > mnemonics[mnemonic].lastInstructionFormat) OR (name[pos] = 0X)
			END;
		UNTIL (mnemonic = None) OR (name[pos] = 0X);

		RETURN (mnemonic # None)
	END FindMnemonic;

	PROCEDURE InitInstruction*(VAR instruction: Instruction);
	VAR i : LONGINT;
	BEGIN
		instruction.format := None;
		instruction.condition := None;
		instruction.flags := {};
		FOR i := 0 TO LEN(instruction.operands)-1 DO
			InitOperand(instruction.operands[i]);
		END;
	END InitInstruction;
	
	(* generate immediate operand with fixup *)
	PROCEDURE InitFixup*(VAR operand: Operand; bits: SHORTINT; fixup: BinaryCode.Fixup (*symbol: Sections.Section; offset, displacement: LONGINT *));
	BEGIN
		operand.mode := modeImmediate;
		operand.immediate := 0;
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
		ASSERT(operand.mode IN {modeImmediate, modeMemory});
		operand.fixup := fixup
	END AddFixup;

	PROCEDURE InitOperand*(VAR operand: Operand);
	BEGIN
		operand.mode := None;
		operand.register := None;
		operand.immediate := 0;
		operand.shiftImmediate := 0;
		operand.shiftRegister := None;
		operand.offsetRegister := None;
		operand.shiftMode := None;
		operand.offsetImmediate := 0;
		operand.indexing := {};
		operand.registerList := {};
		operand.coprocessor := None;
		operand.opcode := 0;
		operand.fields := {};
		operand.fixup := NIL;
	END InitOperand;

	PROCEDURE InitRegister*(VAR operand: Operand; registerNumber: LONGINT; shiftMode: LONGINT; shiftAmountRegisterNumber: LONGINT; shiftImmediate: LONGINT);
	BEGIN
		InitOperand(operand);
		operand.mode := modeRegister;
		operand.register := SHORT(registerNumber);
		operand.shiftMode := SHORT(shiftMode);
		operand.shiftRegister := SHORT(shiftAmountRegisterNumber);
		operand.shiftImmediate := shiftImmediate
	END InitRegister;

	PROCEDURE InitImmediate*(VAR operand: Operand; immediate: LONGINT);
	BEGIN
		InitOperand(operand); operand.mode := modeImmediate;
		operand.immediate := immediate;
	END InitImmediate;

	(* note that this is a memory operand to be used in a load/store instruction *)
	PROCEDURE InitImmediateOffsetMemory*(VAR operand: Operand; register: LONGINT; offset: LONGINT; indexing: SET);
	BEGIN
		InitOperand(operand); operand.mode := modeMemory;
		operand.register := SHORT(register);
		operand.offsetImmediate := offset;
		operand.indexing := indexing;
	END InitImmediateOffsetMemory;

	(* note that this is a memory operand to be used in a load/store instruction *)
	PROCEDURE InitRegisterOffsetMemory*(VAR operand: Operand; register, offsetRegister: LONGINT; shiftMode: LONGINT; shiftImmediate: LONGINT; indexing: SET);
	BEGIN
		InitOperand(operand); operand.mode := modeMemory;
		operand.register := SHORT(register);
		operand.offsetRegister := SHORT(offsetRegister);
		operand.indexing := indexing;
		IF operand.shiftImmediate < 0 THEN
			operand.shiftImmediate := -operand.shiftImmediate;
			INCL(operand.indexing, Decrement);
			EXCL(operand.indexing, Increment);
		END;
		operand.shiftMode := SHORT(shiftMode);
		operand.shiftImmediate := shiftImmediate;
	END InitRegisterOffsetMemory;

	PROCEDURE NewRegister*(registerNumber: LONGINT; shiftMode: LONGINT; shiftAmountRegisterNumber: LONGINT; shiftImmediate: LONGINT): Operand;
	VAR
		result: Operand;
	BEGIN
		InitRegister(result, registerNumber, shiftMode, shiftAmountRegisterNumber, shiftImmediate);
		RETURN result
	END NewRegister;

	PROCEDURE NewImmediate*(immediate: LONGINT): Operand;
	VAR
		result: Operand;
	BEGIN
		InitImmediate(result, immediate);
		RETURN result
	END NewImmediate;

	PROCEDURE NewImmediateOffsetMemory*(register: LONGINT; offset: LONGINT; indexing: SET): Operand;
	VAR
		result: Operand;
	BEGIN
		InitImmediateOffsetMemory(result, register, offset, indexing);
		RETURN result
	END NewImmediateOffsetMemory;

	PROCEDURE NewRegisterOffsetMemory*(register, offsetRegister: LONGINT; shiftMode: LONGINT; shiftImmediate: LONGINT; indexing: SET): Operand;
	VAR
		result: Operand;
	BEGIN
		InitRegisterOffsetMemory(result, register, offsetRegister, shiftMode, shiftImmediate, indexing);
		RETURN result
	END NewRegisterOffsetMemory;

	PROCEDURE NewRegisterList*(registerBase: LONGINT; registerList: SET): Operand;
	VAR
		result: Operand;
	BEGIN
		InitRegisterList(result, registerBase, registerList);
		RETURN result
	END NewRegisterList;

	PROCEDURE InitOption*(VAR operand: Operand; register: LONGINT; option: LONGINT);
	BEGIN
		InitOperand(operand); operand.mode := modeOption;
		operand.register := SHORT(register);
		operand.option := option;
	END InitOption;

	PROCEDURE InitCoprocessor*(VAR operand: Operand; coprocessor: LONGINT);
	BEGIN
		InitOperand(operand); operand.mode := modeCoprocessor;
		operand.coprocessor := SHORT(coprocessor);
	END InitCoprocessor;

	PROCEDURE InitOpcode*(VAR operand: Operand; opcode: LONGINT);
	BEGIN
		InitOperand(operand); operand.mode := modeOpcode;
		operand.opcode := opcode;
	END InitOpcode;

	PROCEDURE InitRegisterList*(VAR operand: Operand; registerBase: LONGINT; registerList: SET);
	BEGIN
		InitOperand(operand); operand.mode := modeRegisterList;
		operand.register := SHORT(registerBase); operand.registerList := registerList;
	END InitRegisterList;

	PROCEDURE InitRegisterWithFields*(VAR operand: Operand; registerNumber: LONGINT; fields: SET);
	BEGIN
		ASSERT((registerNumber = CPSR) OR (registerNumber = SPSR));
		InitOperand(operand);
		operand.mode := modeRegisterWithFields;
		operand.register := registerNumber;
		operand.fields := fields
	END InitRegisterWithFields;

	PROCEDURE NewRegisterWithFields*(registerNumber: LONGINT; fields: SET): Operand;
	VAR
		result: Operand;
	BEGIN
		InitRegisterWithFields(result, registerNumber, fields);
		RETURN result
	END NewRegisterWithFields;

	PROCEDURE MakeInstruction*(VAR instruction: Instruction; mnemonic, condition: LONGINT; flags: SET; CONST operands: ARRAY OF Operand): BOOLEAN;
	VAR
		format: InstructionFormat;
		i, dummyEncoding: LONGINT;
		result: BOOLEAN;

		PROCEDURE OperandMatches(encoding: LONGINT; CONST operand: Operand): BOOLEAN;
		BEGIN
			CASE encoding OF
				|None: RETURN operand.mode = None
				|encodingR16, encodingR12, encodingR8, encodingR0:
					RETURN (operand.mode = modeRegister) & (R0 <= operand.register) & (operand.register <= R15)
				|encodingFR0, encodingFR12, encodingFR16:
					RETURN (operand.mode = modeRegister) & (SR0 <= operand.register) & (operand.register <= SR31)
				|encodingDR0,encodingDR12, encodingDR16:
					RETURN (operand.mode = modeRegister) & (DR0 <= operand.register) & (operand.register <= DR15)
				|encodingCR0, encodingCR12, encodingCR16:
					RETURN (operand.mode = modeRegister) & (CR0 <= operand.register) & (operand.register <= CR15)
				|encodingAddressingMode1:
					RETURN (operand.mode = modeRegister) & (R0 <= operand.register) & (operand.register <= R15)
							OR (operand.mode = modeImmediate)
				|encodingAddressingMode2:
					RETURN (operand.mode = modeMemory)
				|encodingAddressingMode3:
					RETURN (operand.mode = modeMemory)
				|encodingAddressingMode5:
					RETURN (operand.mode = modeMemory) OR (operand.mode = modeOption)
				|encodingAddressingMode5V:
					RETURN (operand.mode = modeMemory)
				|encodingCoprocessor:
					RETURN (operand.mode = modeCoprocessor)
				|encodingFields:
					RETURN operand.mode = modeRegisterWithFields
				|encodingImm16,encodingSignedImm24,encodingImm24,encodingRotImm8, encodingImm7to11:
					RETURN operand.mode = modeImmediate
				|encodingOpcode20,encodingOpcode21,encodingOpcode5,encodingOpcode4:
					RETURN (operand.mode = modeOpcode) OR (operand.mode = None) (* note: missing opcode operand means opcode = 0 *)
				|encodingRegisterList, encodingDRegisterList, encodingFRegisterList:
					RETURN operand.mode = modeRegisterList
				|encodingPSR:
					RETURN (operand.mode = modeRegister) & ((operand.register = CPSR) OR (operand.register = SPSR))
				|encodingNEONQd, encodingNEONQm, encodingNEONQn:
					RETURN (operand.mode = modeRegister) & (QR0 <= operand.register) & (operand.register <= QR15)
				|encodingNEONDd, encodingNEONDm, encodingNEONDn:
					RETURN (operand.mode = modeRegister) & (DR0 <= operand.register) & (operand.register <= DR31)
				|encodingNEONSd, encodingNEONSm, encodingNEONSn:
					RETURN (operand.mode = modeRegister) & (SR0 <= operand.register) & (operand.register <= SR31)
				|encodingNEONQorDd, encodingNEONQorDm, encodingNEONQorDn:
					RETURN (operand.mode = modeRegister) & (((DR0 <= operand.register) & (operand.register <= DR31))
						OR ((QR0 <= operand.register) & (operand.register <= QR15)))
				|encodingNEONDorSd, encodingNEONDorSm, encodingNEONDorSn:
					RETURN (operand.mode = modeRegister) & (((DR0 <= operand.register) & (operand.register <= DR15))
						OR ((SR0 <= operand.register) & (operand.register <= SR31)))
				|encodingNEONImmAndSize, encodingNEON8bitImm, encodingNEON3bitImm, encodingNEONSigned8bitImm:
					RETURN operand.mode = modeImmediate
				|encodingNEONDRegList:
					RETURN operand.mode = modeRegisterList
				|encodingNEONSysReg:
					RETURN (operand.mode = modeRegister) & (FPSID <= operand.register) & (operand.register <= FPEXC)
			ELSE RETURN FALSE
			END;
		END OperandMatches;


		PROCEDURE Matches(CONST format: InstructionFormat): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			IF mnemonic # format.mnemonic THEN 	RETURN FALSE END; (* different mnemonic *)
			IF (instruction.condition # conditionAL) & (instruction.condition # None) & ~(flagCondition IN format.flags) THEN (* not always case for encoding problems of BLX which comes in two forms *)
				RETURN FALSE END; (* unpermitted condition *)
			IF instruction.flags * format.flags # instruction.flags THEN
				RETURN FALSE END; (* unpermitted flags*)
			i := 0;
			WHILE (i<MaxOperands) & OperandMatches(format.operands[i], instruction.operands[i]) DO
				INC(i);
			END;
			RETURN i= MaxOperands;
		END Matches;

	BEGIN
		instruction.condition := condition;
		instruction.flags := flags;
		FOR i := 0 TO LEN(operands)-1 DO
			instruction.operands[i] := operands[i]
		END;
		FOR i := LEN(operands) TO LEN(instruction.operands)-1 DO
			InitOperand(instruction.operands[i]);
		END;

		result := FALSE; i := mnemonics[mnemonic].firstInstructionFormat;
		WHILE (result = FALSE) & (i<=mnemonics[mnemonic].lastInstructionFormat) DO
			format := instructionFormats[i];
			IF Matches(format) THEN
				instruction.format := i;
				result := TRUE
			END;
			INC(i);
		END;

		(* TODO: remove later on: *)
		IF ~result THEN
			D.String("error: did not find matching instruction format for the following mnemonic and operands:"); D.Ln;
			D.String(mnemonics[mnemonic].name); D.Int(mnemonic, 0); D.Ln;
			FOR i := 0 TO LEN(operands) - 1 DO
				D.String("  operand #"); D.Int(i, 0); D.String(":"); D.Ln;
				D.String("    "); DumpOperand(D.Log, instruction.operands[i]); D.Ln; D.Ln
			END
		END;



		RETURN result
	END MakeInstruction;

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

	PROCEDURE RotateRight(val, rot: LONGINT): LONGINT;
	VAR set: SET; i, dest: LONGINT;
	BEGIN
		set := NumberToSet(val);
		dest := 0;
		FOR i := 0 TO 31 DO
			IF i IN set THEN
				INC(dest, ASH(1, (i-rot) MOD 32));
			END;
		END;
		RETURN dest
	END RotateRight;

	PROCEDURE EncodeImmediate*(imm: LONGINT; VAR val,rot: LONGINT): BOOLEAN;
	VAR immSet: SET; i: LONGINT;

		PROCEDURE RotateLeft(set: SET; rot: LONGINT): SET;
		VAR i: LONGINT; result: SET;
		BEGIN
			result := {};
			FOR i := 0 TO 31 DO
				IF i IN set THEN INCL(result,(i+rot) MOD 32) END;
			END;
			RETURN result
		END RotateLeft;

	BEGIN
		immSet := NumberToSet(imm);
		rot := 0;
		WHILE (rot<16) & (immSet*{8..31} # {}) DO
			INC(rot,1); immSet := RotateLeft(immSet,2);
		END;

		val := 0;
		FOR i := 7 TO 0 BY -1 DO
			val := val*2;
			IF i IN immSet THEN INC(val) END;
		END;

		RETURN rot <16
	END EncodeImmediate;


	PROCEDURE Encode(CONST instruction: Instruction; VAR code: LONGINT): BOOLEAN;
	VAR
		format: InstructionFormat; codeSet: SET; i: LONGINT; error: BOOLEAN;
		flags: SET;
	CONST
		P=24; U=23; B=22; W=21; L=20; S=6; H=5;

		PROCEDURE Unsigned(val: LONGINT; from,to: LONGINT);
		VAR i: LONGINT;
		BEGIN
			FOR i := from TO to DO
				IF ODD(val) THEN INCL(codeSet,i) END;
				val := val DIV 2;
			END;
			IF val # 0 THEN error := TRUE END;

			IF error THEN D.TraceBack END
		END Unsigned;

		(* Encode an unsigned value on a non-contiguous set of bits, specifying the order.
			val: value to encode
			positions: array of bit positions, from the lowest to the highest.
		The end of the encoding region is signaled by:
			end of the array
			a position has value 32
		*)
		PROCEDURE SplittedUnsigned(val: LONGINT; positions: ARRAY OF INTEGER);
		VAR
			i, len: LONGINT;
		BEGIN
			ASSERT(LEN(positions) <= 32);
			FOR i := 0 TO LEN(positions) - 1 DO ASSERT(positions[i] <= 32); ASSERT(positions[i] >= 0) END;

			i := 0;
			WHILE (i < LEN(positions)) & (positions[i] # 32) DO INC(i) END;
			len := i;
			(*D.String("Splitted unsigned length: "); D.Int(i, 0); D.Ln;*)
			FOR i := 0 TO len - 1 DO
				IF ODD(val) THEN INCL(codeSet, positions[i]) END;
				val := val DIV 2;
			END;
			IF val # 0 THEN error := TRUE; D.TraceBack END
		END SplittedUnsigned;

		PROCEDURE Bits(val: SET; from,to: LONGINT);
		VAR i: LONGINT;
		BEGIN
			FOR i := from TO to DO
				IF i-from IN val THEN INCL(codeSet,i) END;
			END;
			IF val * {to-from+1..31} # {} THEN error := TRUE END;
		END Bits;

		PROCEDURE Signed(val: LONGINT; from,to: LONGINT);
		VAR i: LONGINT; negate: BOOLEAN;
		BEGIN
			negate := val < 0;
			IF negate THEN val := -val -1 END;
			FOR i := from TO to-1 DO
				IF ODD(val) THEN
					IF  ~negate THEN INCL(codeSet,i) END;
				ELSIF negate THEN
					INCL(codeSet,i)
				END;
				val := val DIV 2;
			END;
			IF negate THEN INCL(codeSet, to) END;
			IF (val # 0) THEN error := TRUE END;
		END Signed;

		PROCEDURE Range(set: SET; VAR first, num: LONGINT): BOOLEAN;
		BEGIN
			i := 0;
			WHILE (i<32) & ~(i IN set) DO INC(i) END;
			first := i;
			WHILE (i<32) & (i IN set) DO INC(i) END;
			num := i-first;
			WHILE (i<32) & ~(i IN set) DO INC(i) END;
			IF i<32 THEN RETURN FALSE ELSE RETURN TRUE END;
		END Range;

		(** check immediate shifts and adopt special rules **)
		PROCEDURE CheckImmediateShifts(VAR shiftMode, shiftImmediate: LONGINT);
		BEGIN
			CASE shiftMode OF
			| None:
				(* no shift -> encode as LSL 0 *)
				shiftMode := shiftLSL;
				shiftImmediate := 0
			| shiftLSL:
				IF shiftImmediate < 0 THEN
					error := TRUE
				ELSIF shiftImmediate > 31 THEN
					D.String("LSL with more than 31 bits"); D.Ln; (* note that LSL 32 is disallowed *)
					error := TRUE
				END
			| shiftLSR, shiftASR:
				IF (shiftImmediate < 0) OR (shiftImmediate > 32) THEN
					error := TRUE
				ELSIF shiftImmediate = 0 THEN
					shiftMode := shiftLSL; (* note that LSR 0, ASR 0 are disallowed -> encode as LSL 0 *)
					shiftImmediate := 0
				ELSIF shiftImmediate = 32 THEN
					shiftImmediate := 0 (* 32 is encoded as 0 in this case! *)
				END
			| shiftROR:
				IF (shiftImmediate < 0) OR (shiftImmediate > 32) THEN
					error := TRUE
				ELSIF (shiftImmediate = 0) OR (shiftImmediate = 32) THEN
					shiftMode := shiftLSL; (* note that ROR 0 has a different meaning -> encode as LSL 0 *)
					shiftImmediate := 0
				END
			| shiftRRX:
				IF shiftImmediate = 1 THEN
					(* RRX is encoded as ROR 0 *)
					shiftMode := shiftROR;
					shiftImmediate := 0
				ELSE
					(* note that only shifts by 1 are allowed *)
					error := TRUE
				END
			ELSE
				HALT(100)
			END
		END CheckImmediateShifts;


		PROCEDURE EncodeOperand(operandEncoding: LONGINT; CONST operand: Operand);
		VAR
			imm, rot, firstRegister, num, shiftMode, shiftImmediate: LONGINT;
			NEONRegisterPos: ARRAY 5 OF INTEGER;
			
			PROCEDURE Fixup(from, to: LONGINT);
			VAR patterns: ObjectFile.FixupPatterns; displacement: LONGINT; mode: SHORTINT;
			BEGIN
				NEW(patterns, 1);
				patterns[0].offset := from; patterns[0].bits := to-from+1;
				
				(*ASSERT(format.mnemonic = opBL); currently only implemented for this case *)
				(*
				IF (opBL <= instructionFormat.mnemonic) & (instructionFormat.mnemonic <= opBF) THEN
				*)
				IF (format.mnemonic = opB) OR (format.mnemonic = opBL) THEN
					mode := BinaryCode.Relative;
					displacement := operand.fixup.displacement - 8;
				ELSE
					mode := BinaryCode.Relative;
					displacement := operand.fixup.displacement;
				END;
					
				(*
				ELSE
					mode := BinaryCode.Absolute;
					displacement := op.fixup.displacement;
				END;
				*)
				operand.fixup.InitFixup(mode, 0, operand.fixup.symbol, operand.fixup.symbolOffset, displacement, -2, patterns);
			END Fixup;
			
		BEGIN
			CASE operandEncoding OF
				|None: error :=  operand.mode # None;
				|encodingR16, encodingR12,encodingR8, encodingR0:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < R0) OR (operand.register > R15) THEN error := TRUE
					END;
					CASE operandEncoding OF
					|encodingR16: Unsigned(operand.register-R0,16,19);
					|encodingR12: Unsigned(operand.register-R0,12,15);
					|encodingR8: Unsigned(operand.register-R0,8,11);
					|encodingR0: Unsigned(operand.register-R0,0,3);
					END;
				|encodingCR0, encodingCR12, encodingCR16:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < CR0) OR (operand.register > CR15) THEN error := TRUE
					END;
					CASE operandEncoding OF
					|encodingCR16: Unsigned(operand.register - CR0,16,19);
					|encodingCR12: Unsigned(operand.register - CR0,12,15);
					|encodingCR0: Unsigned(operand.register - CR0,0,3);
					END;
				|encodingDR0, encodingDR12, encodingDR16:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < DR0) OR (operand.register > DR15) THEN error := TRUE
					END;
					CASE operandEncoding OF
					|encodingDR16: Unsigned(operand.register-DR0,16,19);
					|encodingDR12: Unsigned(operand.register-DR0,12,15);
					|encodingDR0: Unsigned(operand.register-DR0,0,3);
					END;
				|encodingFR0, encodingFR12, encodingFR16:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < SR0) OR (operand.register > SR31) THEN error := TRUE
					END;
					CASE operandEncoding OF
					|encodingFR16: Unsigned((operand.register-SR0) MOD 16,16,19); Unsigned((operand.register-SR0) DIV 16,7,7);
					|encodingFR12: Unsigned((operand.register-SR0) MOD 16,12,15); Unsigned((operand.register-SR0) DIV 16,22,22);
					|encodingFR0: Unsigned((operand.register-SR0) MOD 16,0,3);Unsigned((operand.register-SR0) DIV 16,5,5);
					END;
				|encodingAddressingMode1:
					IF operand.mode = modeImmediate THEN
						INCL(codeSet,25);
						IF ~EncodeImmediate(operand.immediate, imm,rot) THEN
							(*HALT(201);*)
							error := TRUE
						END;
						Unsigned(imm,0,7); Unsigned(rot,8,11);
					ELSIF (operand.mode = modeRegister) & (operand.shiftRegister # None) THEN
						INCL(codeSet,4);
						Unsigned(operand.register-R0,0,3);
						ASSERT(operand.shiftMode # None);
						Unsigned(operand.shiftMode,5,6);
						Unsigned(operand.shiftRegister-R0,8,11);
					ELSIF operand.mode = modeRegister THEN
						shiftMode := operand.shiftMode;
						shiftImmediate := operand.shiftImmediate;
						CheckImmediateShifts(shiftMode, shiftImmediate);
						Unsigned(shiftMode,5,6);
						Unsigned(shiftImmediate,7,11);
						Unsigned(operand.register-R0,0,3)
					ELSE error := TRUE
					END;

				|encodingAddressingMode2:
					IF operand.mode = modeMemory THEN
						IF Increment IN operand.indexing THEN INCL(codeSet,U) ELSE ASSERT(Decrement IN operand.indexing) END;

						IF PreIndexed IN operand.indexing THEN
							INCL(codeSet,W); INCL(codeSet,P)
						ELSIF PostIndexed IN operand.indexing THEN
							(* P bit remains cleared *)
						ELSE
							INCL(codeSet,P)
						END;

						Unsigned(operand.register-R0,16,19);
						IF operand.offsetRegister = None THEN
							Unsigned(operand.offsetImmediate,0,11);
						ELSE
							INCL(codeSet,25);
							shiftMode := operand.shiftMode;
							shiftImmediate := operand.shiftImmediate;
							CheckImmediateShifts(shiftMode, shiftImmediate);
							Unsigned(shiftMode,5,6);
							Unsigned(shiftImmediate,7,11);
							Unsigned(operand.offsetRegister-R0,0,3)
						END;
					ELSE
						error := TRUE
					END;

				|encodingAddressingMode3:
					IF Increment IN operand.indexing THEN INCL(codeSet,U) ELSE ASSERT(Decrement IN operand.indexing) END;
					IF PreIndexed IN operand.indexing THEN INCL(codeSet,W); INCL(codeSet,P)
					ELSIF PostIndexed IN operand.indexing THEN (* P = 0, W= 0 : post indexed addressing *)
					ELSE INCL(codeSet, P); (* P=1, W= 0: offset addressing *)
					END;
					Unsigned(operand.register-R0,16,19);
					IF operand.offsetRegister = None THEN
						INCL(codeSet,B);
						Unsigned(operand.offsetImmediate MOD 16,0,3); Unsigned(operand.offsetImmediate DIV 16,8,11);
					ELSE
						Unsigned(operand.offsetRegister-R0,0,3);
					END
				|encodingAddressingMode5:
					IF Increment IN operand.indexing THEN INCL(codeSet,U) ELSE ASSERT(Decrement IN operand.indexing) END;
					IF PreIndexed IN operand.indexing THEN
						INCL(codeSet,P); INCL(codeSet,W);
					ELSIF PostIndexed IN operand.indexing THEN
						INCL(codeSet,W)
					END;
					IF operand.mode = modeMemory THEN
						IF ~(W IN codeSet) THEN INCL(codeSet,U) END;
						Unsigned(operand.register-R0,16,19);
						Unsigned(operand.offsetImmediate DIV 4,0,7);
					ELSIF operand.mode = modeOption THEN
						Unsigned(operand.register-R0,16,18);
						Unsigned(operand.mode,0,7);
					ELSE error := TRUE
					END;
				|encodingAddressingMode5V:
					IF Increment IN operand.indexing THEN INCL(codeSet,U) ELSE ASSERT(Decrement IN operand.indexing) END;
					Unsigned(operand.register-R0,16,19);
					Unsigned(operand.offsetImmediate DIV 4,0,7);
				|encodingCoprocessor:
					IF operand.mode # modeCoprocessor THEN
						error := TRUE
					END;
					Unsigned(operand.coprocessor,8,11);
				|encodingOpcode20, encodingOpcode21, encodingOpcode5, encodingOpcode4:
					IF operand.mode # modeOpcode THEN
						IF operand.mode = None THEN (* note: missing opcode operand means opcode = 0 *)
							ASSERT(operand.opcode = 0)
						ELSE
							error := TRUE
						END
					END;
					CASE operandEncoding OF
						encodingOpcode20: Unsigned(operand.opcode,20,23);
						|encodingOpcode21: Unsigned(operand.opcode,21,23);
						|encodingOpcode5: Unsigned(operand.opcode,5,7);
						|encodingOpcode4: Unsigned(operand.opcode,4,7);
					END;
				|encodingSignedImm24:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					END;
					IF operand.immediate MOD 4 # 0 THEN error := TRUE END;
					Signed(operand.immediate DIV 4,0,23);
					IF operand.fixup # NIL THEN Fixup(0, 23) END;
				|encodingImm24:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					END;
					Unsigned(operand.immediate,0,23);
				|encodingImm16:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					END;
					Unsigned(operand.immediate MOD 16,0,3); Unsigned(operand.immediate DIV 16,9,19);
				|encodingRotImm8:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					ELSIF ~EncodeImmediate(operand.immediate, imm,rot) THEN
						error := TRUE
					END;
					Unsigned(imm,0,7); Unsigned(rot,8,11);
				|encodingRegisterList:
					IF operand.mode # modeRegisterList THEN
						error := TRUE
					ELSIF operand.register # R0 THEN error := TRUE
					END;
					Bits(operand.registerList,0,15);
				|encodingPSR:
					IF (operand.mode # modeRegister) THEN error := TRUE
					ELSIF ~((operand.mode # CPSR) & (operand.mode # SPSR)) THEN error := TRUE
					END;
					IF operand.register = SPSR THEN
						INCL(codeSet,22);
					END;
				|encodingFields:
					IF operand.mode # modeRegisterWithFields THEN
						error := TRUE
					END;
					IF operand.register = SPSR THEN INCL(codeSet,22)
					ELSIF operand.register # CPSR THEN error := TRUE
					END;
					Bits(operand.fields,16,19);
				|encodingDRegisterList:
					IF operand.mode # modeRegisterList THEN error := TRUE
					ELSIF operand.register # DR0 THEN error := TRUE
					ELSIF ~Range(operand.registerList,firstRegister, num) THEN error := TRUE
					END;
					Unsigned(firstRegister,12,15); Unsigned(num*2,0,7);
				|encodingFRegisterList:
					IF operand.mode # modeRegisterList THEN error := TRUE
					ELSIF operand.register # DR0 THEN error := TRUE
					ELSIF ~Range(operand.registerList,firstRegister, num) THEN error := TRUE
					END;
					Unsigned(firstRegister MOD 2,22,22); Unsigned(num,0,7);
					Unsigned(firstRegister DIV 2,12,15); Unsigned(num,0,7);
				|encodingImm7to11:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					END;
					Unsigned(operand.immediate, 7, 11);

				(* NEON specific operand encodings *)
				|encodingNEONQd, encodingNEONQm, encodingNEONQn:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					(* Check register type for each subcase *)
					ELSIF (operand.register < QR0) OR (operand.register > QR15) THEN error := TRUE
					END;
					CASE operandEncoding OF
						 encodingNEONQd:
						 	NEONRegisterPos[0] := 13;
						 	NEONRegisterPos[1] := 14;
						 	NEONRegisterPos[2] := 15;
						 	NEONRegisterPos[3] := 22;
						|encodingNEONQm:
						 	NEONRegisterPos[0] := 1;
						 	NEONRegisterPos[1] := 2;
						 	NEONRegisterPos[2] := 3;
						 	NEONRegisterPos[3] := 5;
						|encodingNEONQn:
						 	NEONRegisterPos[0] := 17;
						 	NEONRegisterPos[1] := 18;
						 	NEONRegisterPos[2] := 19;
						 	NEONRegisterPos[3] := 7;
					END;
				 	NEONRegisterPos[4] := 32; (* end of encoding *)
				 	SplittedUnsigned(operand.register - QR0, NEONRegisterPos)

				|encodingNEONDd, encodingNEONDm, encodingNEONDn:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < DR0) OR (operand.register > DR31) THEN error := TRUE
					END;
					CASE operandEncoding OF
						 encodingNEONDd:
						 	NEONRegisterPos[0] := 12;
						 	NEONRegisterPos[1] := 13;
						 	NEONRegisterPos[2] := 14;
						 	NEONRegisterPos[3] := 15;
						 	NEONRegisterPos[4] := 22;
						|encodingNEONDm:
						 	NEONRegisterPos[0] := 0;
						 	NEONRegisterPos[1] := 1;
						 	NEONRegisterPos[2] := 2;
						 	NEONRegisterPos[3] := 3;
						 	NEONRegisterPos[4] := 5;
						|encodingNEONDn:
						 	NEONRegisterPos[0] := 16;
						 	NEONRegisterPos[1] := 17;
						 	NEONRegisterPos[2] := 18;
						 	NEONRegisterPos[3] := 19;
						 	NEONRegisterPos[4] := 7;
					END;
				 	SplittedUnsigned(operand.register - DR0, NEONRegisterPos)

				|encodingNEONSd, encodingNEONSm, encodingNEONSn:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < SR0) OR (operand.register > SR31) THEN error := TRUE
					END;
					CASE operandEncoding OF
						 encodingNEONSd:
						 	NEONRegisterPos[0] := 22;
						 	NEONRegisterPos[1] := 12;
						 	NEONRegisterPos[2] := 13;
						 	NEONRegisterPos[3] := 14;
						 	NEONRegisterPos[4] := 15;
						|encodingNEONSm:
						 	NEONRegisterPos[0] := 5;
						 	NEONRegisterPos[1] := 0;
						 	NEONRegisterPos[2] := 1;
						 	NEONRegisterPos[3] := 2;
						 	NEONRegisterPos[4] := 3;
						|encodingNEONSn:
						 	NEONRegisterPos[0] := 7;
						 	NEONRegisterPos[1] := 16;
						 	NEONRegisterPos[2] := 17;
						 	NEONRegisterPos[3] := 18;
						 	NEONRegisterPos[4] := 19;
					END;
				 	SplittedUnsigned(operand.register - SR0, NEONRegisterPos)

				|encodingNEONQorDd, encodingNEONQorDm, encodingNEONQorDn:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (DR0 <= operand.register) & (operand.register <= DR31) THEN
						CASE operandEncoding OF
							 encodingNEONQorDd:
							 	NEONRegisterPos[0] := 12;
							 	NEONRegisterPos[1] := 13;
							 	NEONRegisterPos[2] := 14;
							 	NEONRegisterPos[3] := 15;
							 	NEONRegisterPos[4] := 22;
							|encodingNEONQorDm:
							 	NEONRegisterPos[0] := 0;
							 	NEONRegisterPos[1] := 1;
							 	NEONRegisterPos[2] := 2;
							 	NEONRegisterPos[3] := 3;
							 	NEONRegisterPos[4] := 5;
							|encodingNEONQorDn:
							 	NEONRegisterPos[0] := 16;
							 	NEONRegisterPos[1] := 17;
							 	NEONRegisterPos[2] := 18;
							 	NEONRegisterPos[3] := 19;
							 	NEONRegisterPos[4] := 7;
						END;
						SplittedUnsigned(operand.register - DR0, NEONRegisterPos);
					ELSIF (QR0 <= operand.register) & (operand.register <= QR15) THEN
						CASE operandEncoding OF
							 encodingNEONQorDd:
							 	NEONRegisterPos[0] := 13;
							 	NEONRegisterPos[1] := 14;
							 	NEONRegisterPos[2] := 15;
							 	NEONRegisterPos[3] := 22;
							|encodingNEONQorDm:
							 	NEONRegisterPos[0] := 1;
							 	NEONRegisterPos[1] := 2;
							 	NEONRegisterPos[2] := 3;
							 	NEONRegisterPos[3] := 5;
							|encodingNEONQorDn:
							 	NEONRegisterPos[0] := 17;
							 	NEONRegisterPos[1] := 18;
							 	NEONRegisterPos[2] := 19;
							 	NEONRegisterPos[3] := 7;
						END;
						NEONRegisterPos[4] := 32;
						SplittedUnsigned(operand.register - QR0, NEONRegisterPos);
					ELSE error := TRUE
					END

				|encodingNEONDorSd, encodingNEONDorSm, encodingNEONDorSn:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (DR0 <= operand.register) & (operand.register <= DR15) THEN
						CASE operandEncoding OF
							 encodingNEONDorSd:
							 	NEONRegisterPos[0] := 12;
							 	NEONRegisterPos[1] := 13;
							 	NEONRegisterPos[2] := 14;
							 	NEONRegisterPos[3] := 15;
							 	NEONRegisterPos[4] := 22;
							|encodingNEONDorSm:
							 	NEONRegisterPos[0] := 0;
							 	NEONRegisterPos[1] := 1;
							 	NEONRegisterPos[2] := 2;
							 	NEONRegisterPos[3] := 3;
							 	NEONRegisterPos[4] := 5;
							|encodingNEONDorSn:
							 	NEONRegisterPos[0] := 16;
							 	NEONRegisterPos[1] := 17;
							 	NEONRegisterPos[2] := 18;
							 	NEONRegisterPos[3] := 19;
							 	NEONRegisterPos[4] := 7;
						END;
						SplittedUnsigned(operand.register - DR0, NEONRegisterPos)
					ELSIF (SR0 <= operand.register) & (operand.register <= SR31) THEN
						CASE operandEncoding OF
						 encodingNEONDorSd:
						 	NEONRegisterPos[0] := 22;
						 	NEONRegisterPos[1] := 12;
						 	NEONRegisterPos[2] := 13;
						 	NEONRegisterPos[3] := 14;
						 	NEONRegisterPos[4] := 15;
						|encodingNEONDorSm:
						 	NEONRegisterPos[0] := 5;
						 	NEONRegisterPos[1] := 0;
						 	NEONRegisterPos[2] := 1;
						 	NEONRegisterPos[3] := 2;
						 	NEONRegisterPos[4] := 3;
						|encodingNEONDorSn:
						 	NEONRegisterPos[0] := 7;
						 	NEONRegisterPos[1] := 16;
						 	NEONRegisterPos[2] := 17;
						 	NEONRegisterPos[3] := 18;
						 	NEONRegisterPos[4] := 19;
						END;
						SplittedUnsigned(operand.register - SR0, NEONRegisterPos)
					ELSE error := TRUE
					END

				|encodingNEON8bitImm:
					IF operand.mode # modeImmediate THEN error := TRUE END;
					Unsigned(operand.immediate DIV 4, 0, 7);

				|encodingNEONDRegList:
					IF operand.mode # modeRegisterList THEN error := TRUE
					ELSIF operand.register # DR0 THEN error := TRUE
					ELSIF ~Range(operand.registerList, firstRegister, num) THEN error := TRUE
					END;
					(* First register is encoded as Dd *)
					NEONRegisterPos[0] := 12;
					NEONRegisterPos[1] := 13;
					NEONRegisterPos[2] := 14;
					NEONRegisterPos[3] := 15;
					NEONRegisterPos[4] := 22;
				 	SplittedUnsigned(DR0 + firstRegister, NEONRegisterPos);
					(* bits 8 to 11 specify the length of the list *)
					CASE num OF
						 1: 	Unsigned(7H, 8, 11)
						|2: 	Unsigned(0AH, 8, 11)
						|3: Unsigned(6H, 8, 11)
						|4: Unsigned(2H, 8, 11)
					ELSE
						D.String("Register list too long");
						error := TRUE
					END
				
				|encodingNEONSysReg:
					IF operand.mode # modeRegister THEN error := TRUE
					ELSIF operand.shiftMode # None THEN error := TRUE
					ELSIF (operand.register < FPSID) & (operand.register > FPEXC) THEN error := TRUE
					END;
					
					CASE operand.register OF
						(* FPSID - 0b0; FPSCR - 0b1; FPEXC - 0b1000 at bits 19:16 *)
						 FPSCR: INCL(codeSet, 16)
						|FPEXC: INCL(codeSet, 19)
					END

				|encodingNEONSigned8bitImm:
					IF operand.mode # modeImmediate THEN
						error := TRUE
					END;
					Unsigned(operand.immediate DIV 4,0,7)
			END;

			(* TODO: remove later on: *)
			IF error THEN
				D.String("cannot encode operand:"); D.Ln;
				DumpOperand(D.Log, operand); D.Ln;
				D.String("expected operand encoding: "); D.Int(operandEncoding, 0); D.Ln
			END
		END EncodeOperand;

		(** Manages the encoding of the types and sizes of a NEON instruction. *)
		PROCEDURE EncodeNEONTypes(format: InstructionFormat; instruction: Instruction);
		VAR
			normalSizeEncoding: BOOLEAN;
			i, immOperand: INTEGER;
		BEGIN
			IF ~format.isNEON THEN RETURN END;
			(* Set the Unsigned bit *)
			IF flagNEONUnsigned IN instruction.flags THEN
				codeSet := codeSet + format.Unsigned
			END;
			(* We also set the unsigned bit for positive immediates encoded by encodingNEONSigned8bitimm *)
			FOR i := 0 TO MaxOperands -1 DO
				IF (format.operands[i] = encodingNEONSigned8bitImm) & (instruction.operands[i].immediate >= 0) THEN
					codeSet := codeSet + format.Unsigned
				END
			END;
			
			(* Set the Float bit *)
			IF flagNEONFloat IN instruction.flags THEN
				codeSet := codeSet + format.Float
			END;
			
			(* Set the Q bit *)
			FOR i := 0 TO MaxOperands - 1 DO
				CASE format.operands[i] OF
					 encodingNEONQorDd, encodingNEONQorDm, encodingNEONQorDn:
					 	IF (QR0 <= instruction.operands[i].register) & (instruction.operands[i].register <= QR15) THEN
					 		codeSet := codeSet + format.Quadword
					 	END
					|encodingNEONDorSd, encodingNEONDorSm, encodingNEONDorSn:
						IF (DR0 <= instruction.operands[i].register) & (instruction.operands[i].register <= DR15) THEN
							codeSet := codeSet + format.Quadword
						END
				ELSE
				END
			END;

			(* Check the type of size encoding *)
			normalSizeEncoding := TRUE;
			FOR i := 0 TO MaxOperands - 1 DO
				IF (format.operands[i] = encodingNEONImmAndSize) THEN
				immOperand := i;
				normalSizeEncoding := FALSE
				END
			END;

			IF normalSizeEncoding THEN
				IF format.SizeH # 32 THEN
					(* Set the size bit for usual encoding *)
					IF flagNEON16bits IN instruction.flags THEN
						INCL(codeSet, format.SizeH - 1)
					ELSIF flagNEON32bits IN instruction.flags THEN
						INCL(codeSet, format.SizeH)
					ELSIF flagNEON64bits IN instruction.flags THEN
						INCL(codeSet, format.SizeH);
						INCL(codeSet, format.SizeH - 1);
						(* for floating-points *)
						codeSet := codeSet + format.Operation;
					END
				END
			ELSE
				(* size and imm encoding done here *)
				IF flagNEON8bits IN instruction.flags THEN
					INCL(codeSet, 19);
				ELSIF flagNEON16bits IN instruction.flags THEN
					INCL(codeSet, 18);
				ELSIF flagNEON32bits IN instruction.flags THEN
					INCL(codeSet, 17);
				ELSIF flagNEON64bits IN instruction.flags THEN
					codeSet := codeSet + format.Length
				END
			END;
		END EncodeNEONTypes;

	BEGIN
		error := FALSE;
		IF instruction.format = None THEN error := TRUE
		ELSE
			format := instructionFormats[instruction.format];
			codeSet := format.opcode;
			(*
			D.String(mnemonics[format.mnemonic].name); D.Ln;
			D.String("encoding "); D.Int(instruction.format,1); D.Ln;
			D.Set(codeSet); D.Ln;
			*)
			EncodeNEONTypes(format, instruction);

			IF flagCondition IN format.flags THEN
				Unsigned(instruction.condition,28,31);
			END;
			flags := format.flags * instruction.flags;
			IF flagB IN flags THEN INCL(codeSet,B) END;
			IF flagBT IN flags THEN INCL(codeSet,B); INCL(codeSet,W) END;
			IF flagD IN flags THEN INCL(codeSet,S) END;
			IF flagDA IN flags THEN END;
			IF flagDB IN flags THEN INCL(codeSet,P) END;
			IF flagH IN flags THEN INCL(codeSet,H) END;
			IF flagIA IN flags THEN INCL(codeSet,U) END;
			IF flagIB IN flags THEN INCL(codeSet,U); INCL(codeSet,P) END;
			IF flagL IN flags THEN INCL(codeSet,22) END;
			IF flagS IN flags THEN INCL(codeSet,20) END;
			IF flagSB IN flags THEN INCL(codeSet,S) END;
			IF flagSH IN flags THEN INCL(codeSet,S); INCL(codeSet,H) END;
			IF flagT IN flags THEN END;
			IF flagUserMode IN flags THEN INCL(codeSet,22) END;
			IF flagBaseRegisterUpdate IN flags THEN INCL(codeSet,21) END;
			i := 0;

			WHILE (i < LEN(instruction.operands)) & ~error DO
				EncodeOperand(format.operands[i], instruction.operands[i]);
				(* D.Set(codeSet); D.Ln; *)
				INC(i);
			END;
		END;
		code := SetToNumber(codeSet);

		IF error THEN D.String("cannot encode instruction"); D.Ln END;

		RETURN ~error
	END Encode;

	PROCEDURE Decode(code: LONGINT; VAR instruction: Instruction): BOOLEAN;
	VAR
		instrNr, operandNr: LONGINT; format: InstructionFormat; codeSet: SET;
		P, U, B, W, L, S, H: BOOLEAN; done: BOOLEAN;

		PROCEDURE Match(CONST format: InstructionFormat): BOOLEAN;
		BEGIN
			RETURN codeSet*format.mask= format.opcode*format.mask
		END Match;

		PROCEDURE Bits(from, to: LONGINT): SET;
		VAR i: LONGINT; val: SET;
		BEGIN
			val := {};
			FOR i := from TO to DO
				IF i IN codeSet THEN INCL(val, i-from) END;
			END;
			RETURN val
		END Bits;

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
			IF negative THEN INC(val); val := -val; END;
			RETURN val
		END Signed;

		PROCEDURE DecodeOperand(encoding: LONGINT; VAR operand: Operand): BOOLEAN;
		VAR imm, rot, register, shift, shiftRegister, shiftImm, offsetRegister: LONGINT; indexing: SET; firstRegister, lastRegister: LONGINT;
		BEGIN
			CASE encoding OF
				|None: InitOperand(operand);
				|encodingR16: InitRegister(operand, R0+Unsigned(16, 19), None, None, 0);
				|encodingR12: InitRegister(operand, R0+Unsigned(12, 15), None, None, 0);
				|encodingR8: InitRegister(operand, R0+Unsigned(8, 11), None, None, 0);
				|encodingR0: InitRegister(operand, R0+Unsigned(0, 3), None, None, 0);
				|encodingFR0: InitRegister(operand, SR0+Unsigned(0, 3)+16*Unsigned(5,5), None, None, 0);
				|encodingFR12: InitRegister(operand, SR0+Unsigned(12, 15)+16*Unsigned(22,22), None, None, 0);
				|encodingFR16: InitRegister(operand, SR0+Unsigned(16, 19)+16*Unsigned(7,7), None, None, 0);
				|encodingDR0: InitRegister(operand, DR0+Unsigned(0, 3), None, None, 0);
				|encodingDR12: InitRegister(operand, DR0+Unsigned(12, 15), None, None, 0);
				|encodingDR16: InitRegister(operand, DR0+Unsigned(16, 19), None, None, 0);
				|encodingCR0: InitRegister(operand, CR0+Unsigned(0, 3), None, None, 0);
				|encodingCR12: InitRegister(operand, CR0+Unsigned(12, 15), None, None, 0);
				|encodingCR16: InitRegister(operand, CR0+Unsigned(16, 19), None, None, 0);
				|encodingAddressingMode1:
					IF 25 IN codeSet THEN (* rotate immediate *)
						imm := Unsigned(0, 7); rot := Unsigned(8, 11); imm := RotateRight(imm, rot*2);
						InitImmediate(operand, imm);
					ELSIF 4 IN codeSet THEN (* register register shift *)
						IF 7 IN codeSet THEN RETURN FALSE END;
						(* ASSERT(~(7 IN codeSet)); *)
						shift := Unsigned(5, 6);
						register := Unsigned(0, 3);
						shiftRegister := Unsigned(8, 11);
						imm := 0;
						InitRegister(operand, register, shift, shiftRegister, imm);
					ELSE (* register immediate shift *)
						shiftRegister := None;
						shift := Unsigned(5, 6);
						register := Unsigned(0, 3);
						imm := Unsigned(7, 11);
						IF (shift= 0) & (imm= 0) THEN shift := None END;
						IF (shift= 3) & (imm= 0) THEN shift := shiftRRX END;
						InitRegister(operand, register, shift, shiftRegister, imm);
					END;
				|encodingAddressingMode2:
					IF TraceDecode THEN D.String("AddressMode2"); D.Ln; END;
					indexing := {};
					IF U THEN INCL(indexing, Increment) ELSE INCL(indexing, Decrement) END;
					IF ~P THEN INCL(indexing, PostIndexed)
					ELSIF W THEN INCL(indexing, PreIndexed)
					END;
					register := Unsigned(16, 19);
					IF ~(25 IN codeSet) THEN (* immediate offset *)
						IF TraceDecode THEN D.String("ImmediateOffset"); D.Ln; END;
						imm := Unsigned(0, 11);
						InitImmediateOffsetMemory(operand, register, imm, indexing);
					ELSE (* register offset / scaled register offset *)
						IF (4 IN codeSet)  THEN RETURN FALSE END;
						IF TraceDecode THEN D.String("RegisterOffset"); D.Ln; END;
						offsetRegister := Unsigned(0, 3);
						shift := Unsigned(5, 6);
						shiftImm := Unsigned(7, 11);
						IF (shift= 0) & (shiftImm= 0) THEN shift := None END;
						IF (shiftImm = 0) & (shift IN {shiftLSR, shiftASR}) THEN shiftImm := 32 END;
						IF (shift= shiftROR) & (shiftImm = 0) THEN shift := shiftRRX; shiftImm := 1 END;
						InitRegisterOffsetMemory(operand, register, offsetRegister, shift, shiftImm, indexing);
					END;
				|encodingAddressingMode3:
					indexing := {};
					IF ~S & ~H THEN RETURN FALSE END;
					IF S & ~L THEN RETURN FALSE END;
					(* IF ~P & ~W THEN unpredictable instruction  END; *)
					IF U THEN INCL(indexing, Increment) ELSE INCL(indexing, Decrement) END;
					IF ~P THEN INCL(indexing, PostIndexed)
					ELSIF W THEN INCL(indexing, PreIndexed)
					END;

					register := Unsigned(16, 19);
					IF B THEN (* immediate offset *)
						imm := Unsigned(0, 3)+16*Unsigned(8, 11);
						InitImmediateOffsetMemory(operand, register, imm, indexing);
					ELSE (* register offset *)
						offsetRegister := Unsigned(0, 3);
						InitRegisterOffsetMemory(operand, register, offsetRegister, None, 0, indexing);
					END;
				|encodingAddressingMode5:
					IF U THEN INCL(indexing, Increment) ELSE INCL(indexing, Decrement) END;
					IF P THEN
						IF W THEN INCL(indexing, PreIndexed) END;
					ELSE
						IF W THEN INCL(indexing, PostIndexed) END;
					END;
					IF U OR W THEN
						InitImmediateOffsetMemory(operand, Unsigned(16, 19), Unsigned(0, 7)*4, indexing);
					ELSE
						InitOption(operand, Unsigned(16, 19), Unsigned(0, 7));
					END;
				|encodingAddressingMode5V:
					IF U THEN INCL(indexing,Increment) ELSE INCL(indexing, Decrement) END;
					InitImmediateOffsetMemory(operand,Unsigned(16,19),Unsigned(0,7)*4,indexing);
				|encodingCoprocessor: InitCoprocessor(operand, Unsigned(8, 11));
				|encodingFields: IF 22 IN codeSet THEN register := SPSR ELSE register := CPSR END; InitRegisterWithFields(operand, register,Bits(16, 19));
				|encodingImm16: imm := Unsigned(0, 3)+Unsigned(8, 19)*16; InitImmediate(operand, imm);
				|encodingSignedImm24: imm := Signed(0, 23); InitImmediate(operand, imm*4);
				|encodingImm24: imm := Unsigned(0, 23); InitImmediate(operand, imm);
				|encodingRotImm8: imm := Unsigned(0, 7); rot := Unsigned(8, 11); imm := RotateRight(imm, rot*2); InitImmediate(operand, imm);
				|encodingOpcode20: InitOpcode(operand, Unsigned(20, 23));
				|encodingOpcode21: InitOpcode(operand, Unsigned(21, 23));
				|encodingOpcode5: InitOpcode(operand, Unsigned(5, 7));
				|encodingOpcode4: InitOpcode(operand,Unsigned(4,6));
				|encodingRegisterList: InitRegisterList(operand, R0, Bits(0, 15));
				|encodingDRegisterList: firstRegister := Unsigned(12,15); lastRegister := firstRegister + Unsigned(0,7) DIV 2 -1;
					InitRegisterList(operand, DR0, {firstRegister .. lastRegister});
				|encodingFRegisterList: firstRegister := Unsigned(12,15)*2+Unsigned(22,22); lastRegister := firstRegister + Unsigned(0,7) -1;
					IF lastRegister >= 32 THEN RETURN FALSE END;
					InitRegisterList(operand, SR0, {firstRegister .. lastRegister});
				|encodingPSR: InitRegister(operand, CPSR+Unsigned(22, 22), None, None, 0);
			ELSE (*! should trap *)
				RETURN FALSE
			END;
			RETURN TRUE
		END DecodeOperand;


	BEGIN
		codeSet := NumberToSet(code);
		IF TraceDecode THEN
			D.String("decoding:"); D.Hex(code, -8); D.String(":"); D.Set(codeSet); D.Ln;
		END;
		P := 24 IN codeSet;
		U := 23 IN codeSet;
		B := 22 IN codeSet;
		W := 21 IN codeSet;
		L := 20 IN codeSet;
		S := 6 IN codeSet;
		H := 5 IN codeSet;
		instrNr := 0; done := FALSE;
		WHILE (instrNr<NumberInstructions) & ~done DO
			done := Match(instructionFormats[instrNr]);
			IF done THEN
				InitInstruction(instruction);
				IF TraceDecode THEN
					D.String("format:"); D.Int(instrNr, 1); D.String(":"); D.String(mnemonics[instructionFormats[instrNr].mnemonic].name); D.Ln;
				END;
				instruction.format := instrNr;
				format := instructionFormats[instrNr];

				IF flagCondition IN format.flags THEN
					instruction.condition := Unsigned(28, 31);
					IF TraceDecode THEN
						D.String("condition: "); D.Int(instruction.condition, 1); D.Ln;
					END;
				ELSE
					instruction.condition := None;
				END;
				IF flagB IN format.flags THEN
					IF B & ~P & ~W THEN INCL(instruction.flags, flagB) END;
				END;
				IF flagBT IN format.flags THEN
					IF B & ~P & W THEN INCL(instruction.flags, flagBT) END;
				END;
				IF flagD IN format.flags THEN
					IF S & ~H THEN INCL(instruction.flags, flagD) END;
				END;
				IF flagDA IN format.flags THEN
					IF ~U & ~P THEN INCL(instruction.flags, flagDA) END;
				END;
				IF flagDB IN format.flags THEN
					IF ~U & P THEN INCL(instruction.flags, flagDB) END;
				END;
				IF flagH IN format.flags THEN
					IF ~S & H THEN INCL(instruction.flags, flagH) END;
				END;
				IF flagIA IN format.flags THEN
					IF U & ~P THEN INCL(instruction.flags, flagIA) END;
				END;
				IF flagIB IN format.flags THEN
					IF U & P THEN INCL(instruction.flags, flagDA) END;
				END;
				IF flagL IN format.flags THEN
					IF 22 IN codeSet THEN INCL(instruction.flags, flagL) END;
				END;
				IF flagS IN format.flags THEN
					IF 20 IN codeSet THEN INCL(instruction.flags, flagS) END;
				END;
				IF flagSB IN format.flags THEN
					IF S & ~H THEN INCL(instruction.flags, flagSB) END;
				END;
				IF flagSH IN format.flags THEN
					IF S & H THEN INCL(instruction.flags, flagSH) END;
				END;
				IF flagT IN format.flags THEN
					IF ~B & ~P & ~W THEN INCL(instruction.flags, flagT) END;
				END;
				IF flagUserMode IN format.flags THEN
					IF 22 IN codeSet THEN INCL(instruction.flags, flagUserMode) END
				END;
				IF flagBaseRegisterUpdate IN format.flags THEN
					IF 21 IN codeSet THEN INCL(instruction.flags, flagBaseRegisterUpdate) END
				END;
				operandNr := 0;
				WHILE (operandNr < MaxOperands) & done DO
					done := done & DecodeOperand(format.operands[operandNr], instruction.operands[operandNr]);
					INC(operandNr);
				END;
			END;
			INC(instrNr);
		END;
		RETURN done
	END Decode;

	(* TODO: handle fixups *)
	PROCEDURE EmitInstruction*(CONST instruction: Instruction; code: BinaryCode.Section): BOOLEAN;
	VAR
		encoding: LONGINT;
		(*decoded: Instruction;*)
		
		PROCEDURE PatchFixup(op: Operand);
		BEGIN
			IF op.fixup # NIL THEN
				op.fixup.SetFixupOffset(code.pc);
				code.fixupList.AddFixup(op.fixup);
			END;
		END PatchFixup;

		PROCEDURE PatchFixups;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO LEN(instruction.operands)-1 DO
				PatchFixup(instruction.operands[i]);				
			END;
		END PatchFixups;

	BEGIN
		IF (code.comments # NIL) THEN
			DumpInstruction(code.comments, instruction);
			code.comments.Ln;
			code.comments.Update;
		END;
		IF ~Encode(instruction, encoding) THEN RETURN FALSE END;
		PatchFixups();
		
		(*
		IF (code.comments # NIL) THEN
			IF ~Decode(encoding, decoded) THEN HALT(100) END;
			DumpInstruction(code.comments, decoded);
			code.comments.String(" (decoding of encoding)");
			code.comments.Ln;
			code.comments.Update;
		END;
		*)

		(* PatchFixups(); *)
		code.PutBits(encoding, 32);
		RETURN TRUE;
	END EmitInstruction;

	PROCEDURE Emit*(mnemonic, condition: LONGINT; flags: SET; CONST operands: ARRAY OF Operand; code: BinaryCode.Section);
	VAR instruction: Instruction;
	BEGIN
		IF ~MakeInstruction(instruction, mnemonic, condition, flags, operands) THEN HALT(100) END;
		ASSERT(EmitInstruction(instruction, code));
	END Emit;

	PROCEDURE Init*;
	VAR
		i, instructionCount, conditionEntryCount, registerEntryCount: LONGINT;

		PROCEDURE EnterCoprocessor(number: INTEGER; CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, coprocessorNames[number])
		END EnterCoprocessor;

		PROCEDURE EnterShift(number: INTEGER; CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, shiftNames[number]);
		END EnterShift;

		PROCEDURE EnterRegister(number: INTEGER; CONST name: ARRAY OF CHAR);
		VAR
			registerEntry: Entry;
		BEGIN
			COPY(name, registerEntry.name);
			registerEntry.number := number;
			registerEntries[registerEntryCount] := registerEntry;
			INC(registerEntryCount);
		END EnterRegister;

		PROCEDURE EnterMnemonic(number: INTEGER; CONST name: ARRAY OF CHAR);
		VAR mnemonic: Mnemonic;
		BEGIN
			COPY(name, mnemonic.name);
			mnemonic.number := number;
			mnemonic.firstInstructionFormat := MAX(LONGINT); mnemonic.lastInstructionFormat := MIN(LONGINT);
			mnemonics[number] := mnemonic;
		END EnterMnemonic;

		PROCEDURE EnterInstruction(mnemonic: INTEGER; opcode, mask: SET; flags: SET; op0, op1, op2, op3, op4, op5: INTEGER);
		VAR format: InstructionFormat;
		BEGIN
			format.mnemonic := mnemonic;
			format.opcode := opcode;
			format.mask := mask;
			format.flags := flags;
			format.operands[0] := op0;
			format.operands[1] := op1;
			format.operands[2] := op2;
			format.operands[3] := op3;
			format.operands[4] := op4;
			format.operands[5] := op5;
			format.isNEON := FALSE;

			instructionFormats[instructionCount] := format;
			IF instructionCount < mnemonics[mnemonic].firstInstructionFormat THEN mnemonics[mnemonic].firstInstructionFormat := instructionCount END;
			IF instructionCount > mnemonics[mnemonic].lastInstructionFormat THEN mnemonics[mnemonic].lastInstructionFormat := instructionCount END;

			INC(instructionCount);

		END EnterInstruction;

		PROCEDURE EnterCondition(number: LONGINT; CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, conditionEntries[conditionEntryCount].name);
			conditionEntries[conditionEntryCount].number := number;
			INC(conditionEntryCount);
		END EnterCondition;

		PROCEDURE EnterFlag(number: LONGINT; CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, flagNames[number]);
		END EnterFlag;

		(** Parse an instruction format string. The format is a string representation of the encoding bits.
		Each bit can be represented by 0, 1 or X:
			- 0 means that the bit can be used to identify this instruction and it is not set
			- 1 means that the bit can be used to identify this instruction and it is set
			- X means that the bit cannot be used to identify the instruction.
			- U, S, L, F, o for the corresponding bits
		Whitespaces are ignored.
		The output sets are filled according to the parsing results.
		*)
		PROCEDURE ParseInstructionFormat(CONST format: ARRAY OF CHAR; VAR setBits, diffBits, U, Q, S, L, F, o: SET);
		VAR
			curr, len, count: LONGINT;
		BEGIN
			len := Strings.Length(format) - 1;
			count := 0;
			setBits := {};
			diffBits := {};
			U := {}; Q :={}; S := {}; F := {}; L := {}; F := {}; o := {};

			FOR curr := len TO 0 BY -1 DO
				ASSERT((format[curr] = " ") OR (format[curr] = "1")
					 OR (format[curr] = "0") OR (format[curr] = "X")
					 OR (format[curr] = "U") OR (format[curr] = "Q")
					 OR (format[curr] = "F") OR (format[curr] = "L")
					 OR (format[curr] = "S") OR (format[curr] = "o"));
				CASE format[curr] OF
					 " ":
					|"0": INCL(diffBits, count); INC(count)
					|"1": INCL(setBits, count); INCL(diffBits, count); INC(count)
					|"X": INC(count)
					|"U": INCL(U, count); INC(count)
					|"Q": INCL(Q, count); INC(count)
					|"S": INCL(S, count); INC(count)
					|"L": INCL(L, count); INC(count)
					|"F": INCL(F, count); INC(count)
					|"o": INCL(o, count); INC(count)
				END
			END;
			(* Only allow 32 elements wide formats *)
			ASSERT(count = 32);
			
			(* DEBUG *)
			(*D.String("Parsing results:"); D.Ln;
			D.String("    "); D.String(format); D.Ln;
			D.String("opcode: "); D.Set(setBits); D.Ln;
			D.String("mask:    "); D.Set(diffBits); D.Ln;
			D.String("U:         "); D.Set(U); D.Ln;
			D.String("Q:         "); D.Set(Q); D.Ln;
			D.String("S:          "); D.Set(S); D.Ln;
			D.String("F:          "); D.Set(F); D.Ln;
			D.String("L:          "); D.Set(L); D.Ln;
			D.String("o:          "); D.Set(o); D.Ln;*)
		END ParseInstructionFormat;

		(** Adds the given sets to the corresponding record fields of the last entered instruction. Sets the instruction to be a NEON instruction. *)
		PROCEDURE UpdateNEONInstruction(U, Q, S, L, F, O: SET);
		VAR
			last: LONGINT;
			i: INTEGER;
		BEGIN
			(*ASSERT(instructionCount # 0);*)
			last := instructionCount - 1;
			instructionFormats[last].isNEON := TRUE;
			instructionFormats[last].Unsigned := U;
			instructionFormats[last].Quadword := Q;
			(*instructionFormats[last].Size := S;*)
			instructionFormats[last].Length := L;
			instructionFormats[last].Float := F;
			instructionFormats[last].Operation := O;

			FOR i := 0 TO 31 DO
				IF i IN S THEN
					instructionFormats[last].SizeH := i
				END
			END
		END UpdateNEONInstruction;

		(** Enter a NEON Instruction, using a string format descriptor.
		*)
		PROCEDURE EnterNEONInstruction(mnemonic: INTEGER; CONST format: ARRAY OF CHAR; flags: SET; op0, op1, op2, op3, op4, op5: INTEGER);
		VAR
			opcode, mask, U, Q, S, L, F, o: SET;
			last: LONGINT;
			i: INTEGER;
		BEGIN
			(* Enter instruction *)
			ParseInstructionFormat(format, opcode, mask, U, Q, S, L, F, o);
			EnterInstruction(mnemonic, opcode, mask, flags, op0, op1, op2, op3, op4, op5);

			(* Add NEON specific information *)
			last := instructionCount - 1;
			instructionFormats[last].isNEON := TRUE;
			instructionFormats[last].Unsigned := U;
			instructionFormats[last].Quadword := Q;
			instructionFormats[last].Length := L;
			instructionFormats[last].Float := F;
			instructionFormats[last].Operation := o;
			instructionFormats[last].SizeH := 32;
			FOR i := 0 TO 31 DO
				IF i IN S THEN
					instructionFormats[last].SizeH := i
				END
			END
		END EnterNEONInstruction;

	BEGIN
		EnterShift(shiftLSL, "LSL");
		EnterShift(shiftLSR, "LSR");
		EnterShift(shiftASR, "ASR");
		EnterShift(shiftROR, "ROR");
		EnterShift(shiftRRX, "RRX");
		FOR i := 0 TO NumberShifts-1 DO ASSERT(shiftNames[i] # "") END;

		EnterCoprocessor(CP0, "P0");
		EnterCoprocessor(CP1, "P1");
		EnterCoprocessor(CP2, "P2");
		EnterCoprocessor(CP3, "P3");
		EnterCoprocessor(CP4, "P4");
		EnterCoprocessor(CP5, "P5");
		EnterCoprocessor(CP6, "P6");
		EnterCoprocessor(CP7, "P7");
		EnterCoprocessor(CP8, "P8");
		EnterCoprocessor(CP9, "P9");
		EnterCoprocessor(CP10, "P10");
		EnterCoprocessor(CP11, "P11");
		EnterCoprocessor(CP12, "P12");
		EnterCoprocessor(CP13, "P13");
		EnterCoprocessor(CP14, "P14");
		EnterCoprocessor(CP15, "P15");
		FOR i := 0 TO NumberCoprocessors - 1 DO ASSERT(coprocessorNames[i] # "") END;

		(* enter register names (note that the preferred name, i.e. alias, is entered after the other variants) *)
		registerEntryCount := 0;

		EnterRegister(R0, "RES"); EnterRegister(R0, "R0");
		EnterRegister(R1, "RESHI"); EnterRegister(R1, "R1");
		EnterRegister(R2, "R2");
		EnterRegister(R3, "R3");
		EnterRegister(R4, "R4");
		EnterRegister(R5, "R5");
		EnterRegister(R6, "R6");
		EnterRegister(R7, "R7");
		EnterRegister(R8, "R8");
		EnterRegister(R9, "R9");
		EnterRegister(R10, "R10");
		EnterRegister(R11, "R11");
		EnterRegister(R12, "R12"); EnterRegister(R12, "FP");
		EnterRegister(R13, "R13"); EnterRegister(R13, "SP");
		EnterRegister(R14, "R14"); EnterRegister(R14, "LR");
		EnterRegister(R15, "R15"); EnterRegister(R15, "PC");

		EnterRegister(CR0, "C0");
		EnterRegister(CR1, "C1");
		EnterRegister(CR2, "C2");
		EnterRegister(CR3, "C3");
		EnterRegister(CR4, "C4");
		EnterRegister(CR5, "C5");
		EnterRegister(CR6, "C6");
		EnterRegister(CR7, "C7");
		EnterRegister(CR8, "C8");
		EnterRegister(CR9, "C9");
		EnterRegister(CR10, "C10");
		EnterRegister(CR11, "C11");
		EnterRegister(CR12, "C12");
		EnterRegister(CR13, "C13");
		EnterRegister(CR14, "C14");
		EnterRegister(CR15, "C15");

		EnterRegister(DR0, "D0");
		EnterRegister(DR1, "D1");
		EnterRegister(DR2, "D2");
		EnterRegister(DR3, "D3");
		EnterRegister(DR4, "D4");
		EnterRegister(DR5, "D5");
		EnterRegister(DR6, "D6");
		EnterRegister(DR7, "D7");
		EnterRegister(DR8, "D8");
		EnterRegister(DR9, "D9");
		EnterRegister(DR10, "D10");
		EnterRegister(DR11, "D11");
		EnterRegister(DR12, "D12");
		EnterRegister(DR13, "D13");
		EnterRegister(DR14, "D14");
		EnterRegister(DR15, "D15");

		EnterRegister(SR0, "S0");
		EnterRegister(SR1, "S1");
		EnterRegister(SR2, "S2");
		EnterRegister(SR3, "S3");
		EnterRegister(SR4, "S4");
		EnterRegister(SR5, "S5");
		EnterRegister(SR6, "S6");
		EnterRegister(SR7, "S7");
		EnterRegister(SR8, "S8");
		EnterRegister(SR9, "S9");
		EnterRegister(SR10, "S10");
		EnterRegister(SR11, "S11");
		EnterRegister(SR12, "S12");
		EnterRegister(SR13, "S13");
		EnterRegister(SR14, "S14");
		EnterRegister(SR15, "S15");
		EnterRegister(SR16, "S16");
		EnterRegister(SR17, "S17");
		EnterRegister(SR18, "S18");
		EnterRegister(SR19, "S19");
		EnterRegister(SR20, "S20");
		EnterRegister(SR21, "S21");
		EnterRegister(SR22, "S22");
		EnterRegister(SR23, "S23");
		EnterRegister(SR24, "S24");
		EnterRegister(SR25, "S25");
		EnterRegister(SR26, "S26");
		EnterRegister(SR27, "S27");
		EnterRegister(SR28, "S28");
		EnterRegister(SR29, "S29");
		EnterRegister(SR30, "S30");
		EnterRegister(SR31, "S31");

		EnterRegister(CPSR, "CPSR");
		EnterRegister(SPSR, "SPSR");

		(* NEON Registers *)
		EnterRegister(DR16, "D16");
		EnterRegister(DR17, "D17");
		EnterRegister(DR18, "D18");
		EnterRegister(DR19, "D19");
		EnterRegister(DR20, "D20");
		EnterRegister(DR21, "D21");
		EnterRegister(DR22, "D22");
		EnterRegister(DR23, "D23");
		EnterRegister(DR24, "D24");
		EnterRegister(DR25, "D25");
		EnterRegister(DR26, "D26");
		EnterRegister(DR27, "D27");
		EnterRegister(DR28, "D28");
		EnterRegister(DR29, "D29");
		EnterRegister(DR30, "D30");
		EnterRegister(DR31, "D31");

		EnterRegister(QR0, "Q0");
		EnterRegister(QR1, "Q1");
		EnterRegister(QR2, "Q2");
		EnterRegister(QR3, "Q3");
		EnterRegister(QR4, "Q4");
		EnterRegister(QR5, "Q5");
		EnterRegister(QR6, "Q6");
		EnterRegister(QR7, "Q7");
		EnterRegister(QR8, "Q8");
		EnterRegister(QR9, "Q9");
		EnterRegister(QR10, "Q10");
		EnterRegister(QR11, "Q11");
		EnterRegister(QR12, "Q12");
		EnterRegister(QR13, "Q13");
		EnterRegister(QR14, "Q14");
		EnterRegister(QR15, "Q15");

		EnterRegister(FPSID, "FPSID");
		EnterRegister(FPSCR, "FPSCR");
		EnterRegister(FPEXC, "FPEXC");

		FOR i := 0 TO NumberRegisterEntries-1 DO ASSERT(registerEntries[i].name # "") END;


		(* enter condition names (note that the preferred name, i.e. alias, is entered after the other variants) *)
		conditionEntryCount := 0;
		EnterCondition(conditionEQ, "EQ");
		EnterCondition(conditionNE, "NE");
		EnterCondition(conditionCS, "CS"); EnterCondition(conditionHS, "HS");
		EnterCondition(conditionCC, "CC"); EnterCondition(conditionLO, "LO");
		EnterCondition(conditionMI, "MI");
		EnterCondition(conditionPL, "PL");
		EnterCondition(conditionVS, "VS");
		EnterCondition(conditionVC, "VC");
		EnterCondition(conditionHI, "HI");
		EnterCondition(conditionLS, "LS");
		EnterCondition(conditionGE, "GE");
		EnterCondition(conditionLT, "LT");
		EnterCondition(conditionGT, "GT");
		EnterCondition(conditionLE, "LE");
		EnterCondition(conditionAL, "AL");
		EnterCondition(conditionNV, "NV");
		FOR i := 0 TO NumberConditionEntries-1 DO ASSERT(conditionEntries[i].name # "") END;

		EnterFlag(flagB, "B");
		EnterFlag(flagBT, "BT");
		EnterFlag(flagD, "D");
		EnterFlag(flagDA, "DA");
		EnterFlag(flagDB, "DB");
		EnterFlag(flagH, "H");
		EnterFlag(flagIA, "IA");
		EnterFlag(flagIB, "IB");
		EnterFlag(flagL, "L");
		EnterFlag(flagS, "S");
		EnterFlag(flagSB, "SB");
		EnterFlag(flagSH, "SH");
		EnterFlag(flagT, "T");

		(* NEON flags *)
		EnterFlag(flagNEON8bits, "8");
		EnterFlag(flagNEON16bits, "16");
		EnterFlag(flagNEON32bits, "32");
		EnterFlag(flagNEON64bits, "64");

		EnterFlag(flagNEONInt, ".I");
		EnterFlag(flagNEONSigned, ".S");
		EnterFlag(flagNEONUnsigned, ".U");
		EnterFlag(flagNEONFloat, ".F");
		EnterFlag(flagNEONPoly, ".P");
		EnterFlag(flagNEONUndef, ".X");
		FOR i := 0 TO NumberFlags-1 DO ASSERT(flagNames[i] # "") END;

		EnterMnemonic(opADC, "ADC");
		EnterMnemonic(opADD, "ADD");
		EnterMnemonic(opAND, "AND");
		EnterMnemonic(opB, "B");
		EnterMnemonic(opBIC, "BIC");
		EnterMnemonic(opBKPT, "BKPT");
		EnterMnemonic(opBL, "BL");
		EnterMnemonic(opBLX, "BLX");
		EnterMnemonic(opBX, "BX");
		EnterMnemonic(opCDP, "CDP");
		EnterMnemonic(opCDP2, "CDP2");
		EnterMnemonic(opCLZ, "CLZ");
		EnterMnemonic(opCMN, "CMN");
		EnterMnemonic(opCMP, "CMP");
		EnterMnemonic(opEOR, "EOR");

		EnterMnemonic(opFABSD, "FABSD");
		EnterMnemonic(opFABSS, "FABSS");
		EnterMnemonic(opFADDD, "FADDD");
		EnterMnemonic(opFADDS, "FADDS");
		EnterMnemonic(opFCMPD, "FCMPD");
		EnterMnemonic(opFCMPED, "FCMPED");
		EnterMnemonic(opFCMPES, "FCMPED");
		EnterMnemonic(opFCMPEZD, "FCMPEZD");
		EnterMnemonic(opFCMPEZS, "FCMPEZS");
		EnterMnemonic(opFCMPS, "FCMPDS");
		EnterMnemonic(opFCMPZD, "FCMPZED");
		EnterMnemonic(opFCMPZS, "FCMPZS");
		EnterMnemonic(opFCPYD, "FCPYD");
		EnterMnemonic(opFCPYS, "FCPYS");
		EnterMnemonic(opFCVTDS, "FCVTDS");
		EnterMnemonic(opFCVTSD, "FCVTSD");
		EnterMnemonic(opFDIVD, "FDIVD");
		EnterMnemonic(opFDIVS, "FDIVS");
		EnterMnemonic(opFLDD, "FLDD");
		EnterMnemonic(opFLDMIAD, "FLDMIAD");
		EnterMnemonic(opFLDMIAS, "FLDMIAS");
		EnterMnemonic(opFLDMIAX, "FLDMIAX");
		EnterMnemonic(opFLDMDBD, "FLDMIAD");
		EnterMnemonic(opFLDMDBS, "FLDMIAS");
		EnterMnemonic(opFLDMDBX, "FLDMIAX");
		EnterMnemonic(opFLDS, "FLDS");
		EnterMnemonic(opFMACD, "FMACD");
		EnterMnemonic(opFMACS, "FMACS");
		EnterMnemonic(opFMDHR, "FMDHR");
		EnterMnemonic(opFMDLR, "FMDLR");
		EnterMnemonic(opFMRDH, "FMRDH");
		EnterMnemonic(opFMRDL, "FMRDL");
		EnterMnemonic(opFMRS, "FMRS");
		EnterMnemonic(opFMRX, "FMRX");
		EnterMnemonic(opFMSCD, "FMSCD");
		EnterMnemonic(opFMSCS, "FMSCS");
		EnterMnemonic(opFMSR, "FMSR");
		EnterMnemonic(opFMSTAT, "FMSTAT");
		EnterMnemonic(opFMULD, "FMULD");
		EnterMnemonic(opFMULS, "FMULS");
		EnterMnemonic(opFMXR, "FMXR");
		EnterMnemonic(opFNEGD, "FNEGD");
		EnterMnemonic(opFNEGS, "FNEGS");
		EnterMnemonic(opFNMACD, "FNMACD");
		EnterMnemonic(opFNMACS, "FNMACS");
		EnterMnemonic(opFNMSCD, "FNMSCD");
		EnterMnemonic(opFNMSCS, "FNMSCS");
		EnterMnemonic(opFNMULD, "FNMULD");
		EnterMnemonic(opFNMULS, "FNMULS");
		EnterMnemonic(opFSITOD, "FSITOD");
		EnterMnemonic(opFSITOS, "FSITOS");
		EnterMnemonic(opFSQRTD, "FSQRTD");
		EnterMnemonic(opFSQRTS, "FSQRTS");
		EnterMnemonic(opFSTD, "FSTD");
		EnterMnemonic(opFSTMIAD, "FSTMIAD");
		EnterMnemonic(opFSTMIAS, "FSTMIAS");
		EnterMnemonic(opFSTMIAX, "FSTMIAX");
		EnterMnemonic(opFSTMDBD, "FSTMDBD");
		EnterMnemonic(opFSTMDBS, "FSTMDBS");
		EnterMnemonic(opFSTMDBX, "FSTMDBX");
		EnterMnemonic(opFSTS, "FSTS");
		EnterMnemonic(opFSUBD, "FSUBD");
		EnterMnemonic(opFSUBS, "FSUBS");
		EnterMnemonic(opFTOSID, "FTOSID");
		EnterMnemonic(opFTOSIZD, "FTOSIZD");
		EnterMnemonic(opFTOSIS, "FTOSIS");
		EnterMnemonic(opFTOSIZS, "FTOSIZS");
		EnterMnemonic(opFTOUID, "FTOUID");
		EnterMnemonic(opFTOUIZD, "FTOUIZD");
		EnterMnemonic(opFTOUIS, "FTOUIS");
		EnterMnemonic(opFTOUIZS, "FTOUIZS");
		EnterMnemonic(opFUITOD, "FUITOD");
		EnterMnemonic(opFUITOS, "FUITOS");
		EnterMnemonic(opLDC, "LDC");
		EnterMnemonic(opLDC2, "LDC2");
		EnterMnemonic(opLDM, "LDM");
		EnterMnemonic(opLDR, "LDR");
		EnterMnemonic(opMCR, "MCR");
		EnterMnemonic(opMCR2, "MCR2");
		EnterMnemonic(opMCRR, "MCRR");
		EnterMnemonic(opMLA, "MLA");
		EnterMnemonic(opMOV, "MOV");
		EnterMnemonic(opMRC, "MRC");
		EnterMnemonic(opMRC2, "MRC2");
		EnterMnemonic(opMRRC, "MRRC");
		EnterMnemonic(opMRS, "MRS");
		EnterMnemonic(opMSR, "MSR");
		EnterMnemonic(opMUL, "MUL");
		EnterMnemonic(opMVN, "MVN");
		EnterMnemonic(opORR, "ORR");
		EnterMnemonic(opPLD, "PLD");
		EnterMnemonic(opQADD, "QADD");
		EnterMnemonic(opQDADD, "QDADD");
		EnterMnemonic(opQDSUB, "QDSUB");
		EnterMnemonic(opQSUB, "QSUB");
		EnterMnemonic(opRSB, "RSB");
		EnterMnemonic(opRSC, "RSC");
		EnterMnemonic(opSBC, "SBC");
		EnterMnemonic(opSMLABB, "SMLABB");
		EnterMnemonic(opSMLABT, "SMLABT");
		EnterMnemonic(opSMLATB, "SMLATB");
		EnterMnemonic(opSMLATT, "SMLATT");
		EnterMnemonic(opSMLAL, "SMLAL");
		EnterMnemonic(opSMLALBB, "SMLALBB");
		EnterMnemonic(opSMLALBT, "SMLALBT");
		EnterMnemonic(opSMLALTB, "SMLALTB");
		EnterMnemonic(opSMLALTT, "SMLALTT");
		EnterMnemonic(opSMLAWB, "SMLAWB");
		EnterMnemonic(opSMLAWT, "SMLAWT");
		EnterMnemonic(opSMULBB, "SMULBB");
		EnterMnemonic(opSMULBT, "SMULBT");
		EnterMnemonic(opSMULTB, "SMULTB");
		EnterMnemonic(opSMULTT, "SMULTT");
		EnterMnemonic(opSMULWB, "SMULWB");
		EnterMnemonic(opSMULWT, "SMULWT");
		EnterMnemonic(opSMULL, "SMULL");
		EnterMnemonic(opSTC, "STC");
		EnterMnemonic(opSTC2, "STC2");
		EnterMnemonic(opSTM, "STM");
		EnterMnemonic(opSTR, "STR");
		EnterMnemonic(opSUB, "SUB");
		EnterMnemonic(opSWI, "SWI");
		EnterMnemonic(opSWP, "SWP");
		EnterMnemonic(opTEQ, "TEQ");
		EnterMnemonic(opTST, "TST");
		EnterMnemonic(opUMLAL, "UMLAL");
		EnterMnemonic(opUMULL, "UMULL");

		EnterMnemonic(opISB, "ISB");
		EnterMnemonic(opLSL, "LSL");
		EnterMnemonic(opLSR, "LSR");
		EnterMnemonic(opSEV, "SEV");
		EnterMnemonic(opDSB, "DSB");
		EnterMnemonic(opLDREX, "LDREX");
		EnterMnemonic(opSTREX, "STREX");
		EnterMnemonic(opADR, "ADR");
		EnterMnemonic(opLDREXB, "LDREXB");
		EnterMnemonic(opSTREXB, "STREXB");
		EnterMnemonic(opDMB, "DMB");
		EnterMnemonic(opCLREX, "CLREX");
		EnterMnemonic(opREV, "REV");
		EnterMnemonic(opREV16, "REV16");
		EnterMnemonic(opUXTH, "UXTH");
		EnterMnemonic(opWFE, "WFE");
		EnterMnemonic(opWFI, "WFI");

		(* NEON mnemonics *)
		EnterMnemonic(opVADD, "VADD");
		EnterMnemonic(opVADDL, "VADDL");
		EnterMnemonic(opVADDW, "VADDW");
		EnterMnemonic(opVMUL, "VMUL");
		EnterMnemonic(opVMULL, "VMULL");
		EnterMnemonic(opVMSR, "VMSR");
		EnterMnemonic(opVMRS, "VMRS");
		EnterMnemonic(opVLDR, "VLDR");
		EnterMnemonic(opVSTR, "VSTR");
		EnterMnemonic(opVDIV, "VDIV");
		EnterMnemonic(opVMLA, "VMLA");
		EnterMnemonic(opVMLS, "VMLS");
		EnterMnemonic(opVMIN, "VMIN");
		EnterMnemonic(opVMAX, "VMAX");
		EnterMnemonic(opVSUB, "VSUB");
		EnterMnemonic(opVABS, "VABS");
		EnterMnemonic(opVABD, "VABD");
		EnterMnemonic(opVLD1, "VLD1");
		EnterMnemonic(opVST1, "VST1");
		EnterMnemonic(opVPADD, "VPADD");
		EnterMnemonic(opVMOV, "VMOV");

		FOR i := 0 TO NumberMnemonics-1 DO ASSERT(mnemonics[i].name # "") END;

		instructionCount := 0;
		(*! adapt number of instructions if you enter a new instruction here *)
		FOR i := 0 TO NumberInstructions-1 DO instructionFormats[i].mnemonic := None END;
		EnterInstruction(opADC, {21, 23}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opADD, {23}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opAND, {}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opB, {25, 27}, {24..27}, {flagCondition}, encodingSignedImm24, None, None, None, None, None);
		EnterInstruction(opBIC, {22..24}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opBKPT, {4..6, 21, 24, 29..31}, {4..7, 20..31}, {}, encodingImm16, None, None, None, None, None);
		EnterInstruction(opBL, {24, 25, 27}, {24..27}, {flagCondition}, encodingSignedImm24, None, None, None, None, None);
		EnterInstruction(opBLX, {25, 27..31}, {25..31}, {}, encodingSignedImm24, None, None, None, None, None);
		EnterInstruction(opBLX, {4, 5, 8..19 (* SBO *), 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR0, None, None, None, None, None);
		EnterInstruction(opBX, {4, 21, 8..19 (* SBO *), 24}, {4..7, 20..27}, {flagCondition}, encodingR0, None, None, None, None, None);
		EnterInstruction(opCDP, {25..27}, {4, 24..27}, {flagCondition}, encodingCoprocessor, encodingOpcode20, encodingCR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opCDP2, {25..27}, {4, 24..31}, {}, encodingCoprocessor, encodingOpcode20, encodingCR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opCLZ, {4, 8..11 (* SBO *), 16..19 (* SBO *), 21, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, None, None, None, None);
		EnterInstruction(opCMN, {20..22, 24}, {20..24, 26, 27}, {flagCondition}, encodingR16, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opCMP, {20, 22, 24}, {20..24, 26, 27}, {flagCondition}, encodingR16, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opEOR, {21}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opFABSD, {6,7,8,9,11,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFABSS, {4,6,7,9,11,20,21,23,25,26,27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFADDD, {8,9,11,20,21,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFADDS, {9,11,20,21,25,26,27}, {4,6,8..11,20,21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFCMPD, {6,8,9,11,18,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFCMPED, {6,7,8,9,11,18,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFCMPES, {6,7,9,11,18,20,21,23,25,26,27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFCMPEZD,{6,7,8,9,11,16,17,20,21,23,25,26,27},{4..11,16..27}, {flagCondition}, encodingDR12, None, None, None, None, None);
		EnterInstruction(opFCMPEZS,{6,7,9,11,16,18,20,21,23,25,26,27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, None, None, None, None, None);
		EnterInstruction(opFCMPS, {6,9,11,18,20,21,23,25,26,27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFCMPZD, {6,8,9,11,16,18,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, None, None, None, None, None);
		EnterInstruction(opFCMPZS, {6,9,11,16,18,20,21,23,25,26,27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, None, None, None, None, None);
		EnterInstruction(opFCPYD, {6,8,9,11,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFCPYS, {6,9,11,20,21,23,25,26,27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFCVTDS, {6,7,9,11,16,17,18,20,21,23,25,26,27}, {4,6..11,16..27}, {flagCondition}, encodingDR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFCVTSD, {6,7,8,9,11,16,17,18,20,21,23,25,26,27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFDIVD, {8,9,11,23,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFDIVS, {9,11,23,25,26,27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFLDD, {8,9,11,20,24,26,27}, {8..11,20..22,24..27}, {flagCondition}, encodingDR12, encodingAddressingMode5V, None, None, None, None);
		EnterInstruction(opFLDMIAD, {8,9,11,20,23,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFLDMIAS, {9,11,20,23,26,27}, {8..11,20,23..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingFRegisterList, None, None, None, None);
		EnterInstruction(opFLDMIAX, {8,9,11,20,23,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFLDMDBD, {8,9,11,20,24,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFLDMDBS, {9,11,20,24,26,27}, {8..11,20,23..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingFRegisterList, None, None, None, None);
		EnterInstruction(opFLDMDBX, {8,9,11,20,24,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFLDS, {9,11,20,24,26,27}, {8..11,20..21,24..27}, {flagCondition}, encodingFR12, encodingAddressingMode5V, None, None, None, None);
		EnterInstruction(opFMACD, {8,9,11,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFMACS, {9,11,25..27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFMDHR, {4,8,9,11,21,25,26,27}, {4,7..11,20..27}, {flagCondition}, encodingDR16, encodingR12, None, None, None, None);
		EnterInstruction(opFMDLR, {4,8,9,11,25,26,27}, {4,7..11,20..27}, {flagCondition}, encodingDR16, encodingR12, None, None, None, None);
		EnterInstruction(opFMRDH, {4,8,9,11,20,21,25,26,27}, {4,7..11,20..27}, {flagCondition}, encodingR12, encodingDR16, None, None, None, None);
		EnterInstruction(opFMRDL, {4,8,9,11,20,25,26,27}, {4,7..11,20..27}, {flagCondition}, encodingR12, encodingDR16, None, None, None, None);
		EnterInstruction(opFMRS, {4,9,11,20,25,26,27}, {4,8..11,20..27}, {flagCondition}, encodingR12, encodingFR16, None, None, None, None);
		EnterInstruction(opFMRX, {4,9,11,20..23,25..27}, {4,7..11,20..27}, {flagCondition}, (*!todo*)None, None, None, None, None, None);
		EnterInstruction(opFMSCD, {8,9,11,20,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFMSCS, {9,11,20,25,26,27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFMSR, {4,9,11,25,26,27}, {4,8..11,20..27}, {flagCondition}, encodingFR16, encodingR12, None, None, None, None);
		EnterInstruction(opFMSTAT, {4,9,11,12..16,20..23,25..27}, {4,8..27}, {flagCondition}, None, None, None, None, None, None);
		EnterInstruction(opFMULD, {8,9,11,21,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFMULS, {9,11,21,25,26,27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFMXR, {4,9,11,21..23,25..27}, {4,7..11,20..27}, {flagCondition}, (*!todo*)None, None, None, None, None, None);
		EnterInstruction(opFNEGD, {6,8,9,11,16,20,21,23,25,26,27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFNEGS	, {6,9,11,16,20,21,23,25,26,27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFNMACD, {6,8,9,11,25..27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFNMACS, {6,9,11,25,26,27}, {4,6,8..11,20,21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFNMSCD, {6,8,9,11,20,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFNMSCS, {6,9,11,20,25,26,27}, {4..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFNMULD, {6,8,9,11,21,25,26,27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFNMULS, {6,9,11,21,25,26,27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFSITOD, {6..9,11,19..21,23,25..27}, {4,6..11,16..27}, {flagCondition}, encodingDR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFSITOS, {6,7,9,11,19..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFSQRTD, {6..9,11,16,20,21,23,25..27}, {4..11,16..27}, {flagCondition}, encodingDR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFSQRTS, {6,7,9,11,16,20,21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFSTD, {8,9,11,24,26,27}, {8..11,20..22,24..27}, {flagCondition}, encodingDR12, encodingAddressingMode5V, None, None, None, None);
		EnterInstruction(opFSTMIAD, {8,9,11,23,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFSTMIAS, {9,11,23,26,27}, {8..11,20,23..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingFRegisterList, None, None, None, None);
		EnterInstruction(opFSTMIAX, {8,9,11,23,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFSTMDBD, {8,9,11,24,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate},  encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFSTMDBS, {9,11,24,26,27}, {8..11,20,23..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16,encodingFRegisterList, None, None, None, None);
		EnterInstruction(opFSTMDBX, {8,9,11,24,26,27}, {8..11,20,22..27}, {flagCondition,flagBaseRegisterUpdate}, encodingR16, encodingDRegisterList, None, None, None, None);
		EnterInstruction(opFSTS, {9,11,24,26,27}, {8..11,20,21, 24..27}, {flagCondition}, encodingFR12, encodingAddressingMode5V, None, None, None, None);
		EnterInstruction(opFSUBD, {6,8,9,11,20,21,25..27}, {4..11,20..27}, {flagCondition}, encodingDR12, encodingDR16, encodingDR0, None, None, None);
		EnterInstruction(opFSUBS, {6,9,11,20,21,25,26,27}, {4,6,8..11,20..21,23..27}, {flagCondition}, encodingFR12, encodingFR16, encodingFR0, None, None, None);
		EnterInstruction(opFTOSID, {6,8,9,11,16,18..21,23,25..27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFTOSIZD, {6,7,8,9,11,16,18..21,23,25..27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFTOSIS, {6,9,11,16,18..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFTOSIZS, {6,7,9,11,16,18..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFTOUID, {6,8,9,11,18..21,23,25..27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFTOUIZD, {6,7,8,9,11,18..21,23,25..27}, {4..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingDR0, None, None, None, None);
		EnterInstruction(opFTOUIS, {6,9,11,18..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFTOUIZS, {6,7,9,11,18..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFUITOD, {6,8,9,11,19..21,23,25..27}, {4,6..11,16..27}, {flagCondition}, encodingDR12, encodingFR0, None, None, None, None);
		EnterInstruction(opFUITOS, {6,9,11,19..21,23,25..27}, {4,6..11,16..21,23..27}, {flagCondition}, encodingFR12, encodingFR0, None, None, None, None);
		EnterInstruction(opLDC, {20, 26, 27}, {20, 25..27}, {flagCondition, flagL}, encodingCoprocessor, encodingCR12, encodingAddressingMode5, None, None, None);
		EnterInstruction(opLDC2, {20, 26, 27, 28..31}, {20, 25..27, 28..31}, {flagL}, encodingCoprocessor, encodingCR12, encodingAddressingMode5, None, None, None);
		(*EnterInstruction(opLDM, {20, 27}, {20, 25..27}, {flagCondition, flagIA, flagIB, flagDA, flagDB, flagUserMode, flagBaseRegisterUpdate}, encodingR16, encodingRegisterList, None, None, None, None);*)
		EnterInstruction(opLDM, {20, 27}, {20, 25..27}, {flagCondition, flagIA, flagIB, flagDA, flagDB, flagBaseRegisterUpdate}, encodingR16, encodingRegisterList, None, None, None, None);
		EnterInstruction(opLDR, {20, 26}, {20, 26..27}, {flagCondition, flagB, flagT, flagBT}, encodingR12, encodingAddressingMode2, None, None, None, None);
		EnterInstruction(opLDR, {4, 7, 20}, {4, 7, 20, 25..27}, {flagCondition, flagH, flagSH, flagSB, flagD}, encodingR12, encodingAddressingMode3, None, None, None, None);
		EnterInstruction(opMCR, {4, 25, 26, 27}, {4, 20, 24..27}, {flagCondition}, encodingCoprocessor, encodingOpcode21, encodingR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opMCR2, {4, 25, 26, 27, 28..31}, {4, 20, 24..27, 28..31}, {}, encodingCoprocessor, encodingOpcode21, encodingCR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opMCRR, {22, 26, 27}, {20..27}, {flagCondition}, encodingCoprocessor, encodingOpcode4, encodingR12, encodingR16, encodingCR0, None);
		EnterInstruction(opMLA, {4, 7, 21}, {4..7, 21..27}, {flagCondition, flagS}, encodingR12, encodingR0, encodingR8, encodingR16, None, None);
		EnterInstruction(opMOV, {21, 23, 24}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opMRC, {4, 20, 25, 26, 27}, {4, 20, 24..27}, {flagCondition}, encodingCoprocessor, encodingOpcode21, encodingR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opMRC2, {4, 20, 25, 26, 27, 28..31}, {4, 20, 24..27, 28..31}, {}, encodingCoprocessor, encodingOpcode21, encodingR12, encodingCR16, encodingCR0, encodingOpcode5);
		EnterInstruction(opMRRC, {20, 22, 26, 27}, {20..27}, {flagCondition}, encodingCoprocessor, encodingOpcode4, encodingR12, encodingR16, encodingCR0, None);
		EnterInstruction(opMRS, {24, 16..19 (* SBO *)}, {20, 21, 23..27}, {flagCondition}, encodingR12, encodingPSR, None, None, None, None);
		EnterInstruction(opMSR, {21, 24, 25, 12..15 (* SBO *)}, {20, 21, 23..27}, {flagCondition}, encodingFields, encodingRotImm8, None, None, None, None);
		EnterInstruction(opMSR, {21, 24, 12..15 (* SBO *)}, {4..7, 20, 21, 23..27}, {flagCondition}, encodingFields, encodingR0, None, None, None, None);
		EnterInstruction(opMUL, {4, 7}, {4..7, 21..27}, {flagCondition, flagS}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opMVN, {21..24}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opORR, {23, 24}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opPLD, {28..31, 26, 24, 22, 20, 12..15}, {26..31, 24, 20..22, 12..15}, {flagCondition}, encodingAddressingMode2, None, None, None, None, None);
		EnterInstruction(opQADD, {4, 6, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		EnterInstruction(opQDADD, {4, 6, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		EnterInstruction(opQSUB, {4, 6, 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		EnterInstruction(opQDSUB, {4, 6, 21, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		EnterInstruction(opRSB, {21, 22}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opRSC, {21, 22, 23}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opSBC, {22, 23}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opSMLAL, {4, 7, 21, 22, 23}, {4..7, 21..27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMULL, {4, 7, 22, 23}, {4..7, 21..27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMLABB, {7, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMLABT, {5, 7, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMLATB, {6, 7, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMLATT, {5, 6, 7, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMLALBB, {7, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMLALBT, {5, 7, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMLALTB, {6, 7, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMLALTT, {5, 6, 7, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opSMLAWB, {7, 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMLAWT, {6, 7, 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, encodingR12, None, None);
		EnterInstruction(opSMULBB, {7, 21, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSMULBT, {5, 21, 7, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSMULTB, {6, 7, 21, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSMULTT, {5, 6, 7, 21, 22, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSMULWB, {5, 7, 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSMULWT, {5, 6, 7, 21, 24}, {4..7, 20..27}, {flagCondition}, encodingR16, encodingR0, encodingR8, None, None, None);
		EnterInstruction(opSTC, {26, 27}, {20, 25..27}, {flagCondition, flagL}, encodingCoprocessor, encodingCR12, encodingAddressingMode5, None, None, None);
		EnterInstruction(opSTC2, {26, 27, 28..31}, {20, 25..27, 28..31}, {flagL}, encodingCoprocessor, encodingCR12, encodingAddressingMode5, None, None, None);
		(*EnterInstruction(opSTM, {27}, {20, 25..27}, {flagCondition, flagIA, flagIB, flagDA, flagDB, flagUserMode, flagBaseRegisterUpdate}, encodingR16, encodingRegisterList, None, None, None, None);*)
		EnterInstruction(opSTM, {27}, {20, 25..27}, {flagCondition, flagIA, flagIB, flagDA, flagDB, flagBaseRegisterUpdate}, encodingR16, encodingRegisterList, None, None, None, None);
		EnterInstruction(opSTR, {26}, {20, 26, 27}, {flagCondition, flagB, flagT, flagBT}, encodingR12, encodingAddressingMode2, None, None, None, None);
		EnterInstruction(opSTR, {4, 5, 7}, {4, 7, 20, 25..27}, {flagCondition, flagH, flagSH, flagSB, flagD}, encodingR12, encodingAddressingMode3, None, None, None, None);
		EnterInstruction(opSUB, {22}, {21..24, 26, 27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingAddressingMode1, None, None, None);
		EnterInstruction(opSWI, {24..27}, {24..27}, {flagCondition}, encodingImm24, None, None, None, None, None);
		EnterInstruction(opSWP, {4, 7, 24}, {4..7, 20..27}, {flagCondition}, encodingR12, encodingR0, encodingR16 (*! optional *), None, None, None);
		EnterInstruction(opSWP, {4, 7, 22, 24}, {4..7, 20..27}, {flagCondition, flagB}, encodingR12, encodingR0, encodingR16 (*! optional *), None, None, None);
		EnterInstruction(opTEQ, {20, 21, 24}, {20..24, 26, 27}, {flagCondition}, encodingR16, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opTST, {20, 24}, {20..24, 26, 27}, {flagCondition}, encodingR16, encodingAddressingMode1, None, None, None, None);
		EnterInstruction(opUMLAL, {4, 7, 21, 23}, {4..7, 21..27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);
		EnterInstruction(opUMULL, {4, 7, 23}, {4..7, 21..27}, {flagCondition, flagS}, encodingR12, encodingR16, encodingR0, encodingR8, None, None);

		EnterNEONInstruction(opLDM, "XXXX 100X X101 XXXX 0XXX XXXX XXXX XXXX", {flagCondition, flagIA, flagDA, flagIB, flagDB, flagUserMode}, encodingR16, encodingRegisterList, None, None, None, None);
		EnterNEONInstruction(opSTM, "XXXX 100X X100 XXXX XXXX XXXX XXXX XXXX", {flagCondition, flagIA, flagDA, flagIB, flagDB, flagUserMode}, encodingR16, encodingRegisterList, None, None, None, None);
		EnterNEONInstruction(opISB, "1111 0101 0111 1111 1111 0000 0110 1111", {}, None, None, None, None, None, None);
		EnterNEONInstruction(opLSL, "XXXX 0001 1010 0000 XXXX XXXX X000 XXXX", {flagCondition, flagS}, encodingR12, encodingR0, encodingImm7to11, None, None, None);
		EnterNEONInstruction(opLSL, "XXXX 0001 1010 0000 XXXX XXXX 0001 XXXX", {flagCondition, flagS}, encodingR12, encodingR0, encodingR8, None, None, None);
		EnterNEONInstruction(opLSR, "XXXX 0001 1010 0000 XXXX XXXX X010 XXXX", {flagCondition, flagS}, encodingR12, encodingR0, encodingImm7to11, None, None, None);
		EnterNEONInstruction(opSEV, "XXXX 0011 0010 0000 1111 0000 0000 0100", {flagCondition}, None, None, None, None, None, None);
		EnterNEONInstruction(opDSB, "1111 0101 0111 1111 1111 0000 0100 1111", {}, None, None, None, None, None, None); (* Full System Reset only *)
		EnterNEONInstruction(opLDREX, "XXXX 0001 1001 XXXX XXXX 1111 1001 1111", {flagCondition}, encodingR12, encodingR16, None, None, None, None);
		EnterNEONInstruction(opSTREX, "XXXX  0001 1000 XXXX XXXX 1111 1001 XXXX", {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		(* Only for labels after current instruction *)
		EnterNEONInstruction(opADR, "XXXX 0010 1000 1111 XXXX XXXX XXXX XXXX", {flagCondition}, encodingR12, encodingRotImm8, None, None, None, None);
		EnterNEONInstruction(opLDREXB, "XXXX 0001 1101 XXXX XXXX 1111 1001 1111", {flagCondition}, encodingR12, encodingR16, None, None, None, None);
		EnterNEONInstruction(opSTREXB, "XXXX 0001 1100 XXXX XXXX 1111 1001 XXXX", {flagCondition}, encodingR12, encodingR0, encodingR16, None, None, None);
		EnterNEONInstruction(opDMB, "1111 0101 0111 1111 1111 0000 0101 1111", {}, None, None, None, None, None, None);
		EnterNEONInstruction(opCLREX, "1111 0101 0111 1111 1111 0000 0001 1111", {}, None, None, None, None, None, None);
		EnterNEONInstruction(opREV, "XXXX 0110 1011 1111 XXXX 1111 0011 XXXX", {flagCondition}, encodingR12, encodingR0, None, None, None, None);
		EnterNEONInstruction(opREV16, "XXXX 0110 1011 1111 XXXX 1111 1011 XXXX", {flagCondition}, encodingR12, encodingR0, None, None, None, None);
		EnterNEONInstruction(opUXTH, "XXXX 0110 1111 1111 XXXX XX00 0111 XXXX", {flagCondition}, encodingR12, encodingR0, None, None, None, None);
		EnterNEONInstruction(opWFE, "XXXX 0011 0010 0000 1111 0000 0000 0010", {flagCondition}, None, None, None, None, None, None);
		EnterNEONInstruction(opWFI, "XXXX 0011 0010 0000 1111 0000 0000 0011", {flagCondition}, None, None, None, None, None, None);

		(* NEON instructions *)
		EnterNEONInstruction(opVADD, "1111 0010 0XSS XXXX XXXX 1000 XQX0 XXXX", {flagNEONInt, flagNEON8bits, flagNEON16bits, flagNEON32bits, flagNEON64bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVADD, "1111 0010 0X00 XXXX XXXX 1101 XQX0 XXXX", {flagNEONFloat, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVADD, "XXXX 1110 0X11 XXXX XXXX 101Q X0X0 XXXX", {flagCondition, flagNEONFloat, flagNEON64bits, flagNEON32bits}, encodingNEONDorSd, encodingNEONDorSn, encodingNEONDorSm, None, None, None);
		EnterNEONInstruction(opVADDL, "1111 001U 1XSS XXXX XXXX 0000 X0X0 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQd, encodingNEONDm, encodingNEONDn, None, None, None);
		EnterNEONInstruction(opVADDW, "1111 001U 1XSS XXXX XXXX 0001 X0X0 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQd, encodingNEONQm, encodingNEONDn, None, None, None);
		EnterNEONInstruction(opVMUL, "1111 0010 0XSS XXXX XXXX 1001 XQX1 XXXX", {flagNEONInt, flagNEONUnsigned, flagNEONSigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None); (*! Does not support polynomail types yet *)
		EnterNEONInstruction(opVMUL, "1111 0011 0X00 XXXX XXXX 1101 XQX1 XXXX", {flagNEONFloat, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMUL, "XXXX 1110 0X10 XXXX XXXX 101Q X0X0 XXXX", {flagNEONFloat, flagNEON32bits, flagNEON64bits, flagCondition}, encodingNEONDorSd, encodingNEONDorSm, encodingNEONDorSn, None, None, None);
		EnterNEONInstruction(opVMULL, "1111 001U 1XSS XXXX XXXX 1010 X1X0 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON16bits, flagNEON32bits}, encodingNEONQd, encodingNEONQm, encodingNEONDn, None, None, None);
		EnterNEONInstruction(opVMSR, "XXXX 1110 1110 XXXX XXXX 1010 0001 0000", {flagCondition}, encodingNEONSysReg, encodingR12, None, None, None, None);
		EnterNEONInstruction(opVMRS, "XXXX 1110 1111 XXXX XXXX 1010 0001 0000", {flagCondition}, encodingR12, encodingNEONSysReg, None, None, None, None);
		EnterNEONInstruction(opVLDR, "XXXX 1101 UX01 XXXX XXXX 1011 XXXX XXXX", {flagCondition, flagNEON64bits}, encodingNEONDd, encodingR16, encodingNEONSigned8bitImm, None, None, None);
		EnterNEONInstruction(opVLDR, "XXXX 1101 UX01 XXXX XXXX 1010 XXXX XXXX", {flagCondition, flagNEON32bits}, encodingNEONSd, encodingR16, encodingNEONSigned8bitImm, None, None, None);
		EnterNEONInstruction(opVSTR, "XXXX 1101 UX00 XXXX XXXX 1011 XXXX XXXX", {flagCondition, flagNEON64bits}, encodingNEONDd, encodingR16, encodingNEONSigned8bitImm, None, None, None);
		EnterNEONInstruction(opVSTR, "XXXX 1101 UX00 XXXX XXXX 1010 XXXX XXXX", {flagCondition, flagNEON32bits}, encodingNEONSd, encodingR16, encodingNEONSigned8bitImm, None, None, None);
		EnterNEONInstruction(opVDIV, "XXXX 1110 1X00 XXXX XXXX 101Q X0X0 XXXX", {flagCondition, flagNEONFloat, flagNEON32bits, flagNEON64bits}, encodingNEONDorSd, encodingNEONDorSn, encodingNEONDorSm, None, None, None);
		EnterNEONInstruction(opVMLA, "1111 0010 0XSS XXXX XXXX 1001 XQX0 XXXX", {flagNEONInt, flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMLA, "1111 0010 0X00 XXXX XXXX 1101 XQX1 XXXX", {flagNEONFloat, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMLA, "XXXX 1110 0X00 XXXX XXXX 101Q X0X0 XXXX", {flagCondition, flagNEONFloat, flagNEON64bits, flagNEON32bits}, encodingNEONDorSd, encodingNEONDorSn, encodingNEONDorSm, None, None, None);
		EnterNEONInstruction(opVMLS, "1111 0011 0XSS XXXX XXXX 1001 XQX0 XXXX", {flagNEONInt, flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMLS, "1111 0010 0X10 XXXX XXXX 1101 XQX1 XXXX", {flagNEONFloat, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMLS, "XXXX 1110 0X00 XXXX XXXX 101Q X1X0 XXXX", {flagCondition, flagNEONFloat, flagNEON64bits, flagNEON32bits}, encodingNEONDorSd, encodingNEONDorSn, encodingNEONDorSm, None, None, None);
		EnterNEONInstruction(opVMIN, "1111 001U 0XSS XXXX XXXX 0110 XQX1 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVMAX, "1111 001U 0XSS XXXX XXXX 0110 XQX0 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVSUB, "1111 0011 0XSS XXXX XXXX 1000 XQX0 XXXX", {flagNEONInt, flagNEON8bits, flagNEON16bits, flagNEON32bits, flagNEON64bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		EnterNEONInstruction(opVABS, "1111 0011 1X11 SS01 XXXX 0o11 0QX0 XXXX", {flagNEONSigned, flagNEONFloat,flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDm, None, None, None, None);
		EnterNEONInstruction(opVABD, "1111 001U 0XSS XXXX XXXX 0111 XQX0 XXXX", {flagNEONSigned, flagNEONUnsigned, flagNEON8bits, flagNEON16bits, flagNEON32bits}, encodingNEONQorDd, encodingNEONQorDn, encodingNEONQorDm, None, None, None);
		(* Fixed alignment and list size... not using [] or {} syntax *)
		EnterNEONInstruction(opVLD1, "1111 0100 0X10 XXXX XXXX 1010 SS00 1111", {flagNEON8bits, flagNEON16bits, flagNEON32bits, flagNEON64bits}, encodingNEONDd, encodingR16, None, None, None, None);
		EnterNEONInstruction(opVST1, "1111 0100 0X00 XXXX XXXX 1010 SS00 1111", {flagNEON8bits, flagNEON16bits, flagNEON32bits, flagNEON64bits}, encodingNEONDd, encodingR16, None, None, None, None);

		EnterNEONInstruction(opVPADD, "1111 0011 0X00 XXXX XXXX 1101 X0X0 XXXX", {flagNEON32bits, flagNEONFloat}, encodingNEONDd, encodingNEONDn, encodingNEONDm, None, None, None);
		EnterNEONInstruction(opVMOV, "XXXX 1110 0001 XXXX XXXX 1010 X001 0000", {flagCondition}, encodingR12, encodingNEONSn, None, None, None ,None);
		EnterNEONInstruction(opVMOV, "XXXX 1110 0000 XXXX XXXX 1010 X001 0000", {flagCondition}, encodingNEONSn, encodingR12, None, None, None, None);

		FOR i := 0 TO NumberInstructions-1 DO ASSERT(instructionFormats[i].mnemonic # None)
		END;
	END Init;

	(** dump the name of a condition (the last name entered is preferred) **)
	PROCEDURE DumpConditionName*(w: Streams.Writer; CONST conditionNumber: LONGINT);
	VAR
		i, foundIndex: LONGINT;
	BEGIN
		(* go through all condition names *)
		foundIndex := None;
		FOR i := 0 TO NumberConditionEntries - 1 DO
			IF conditionEntries[i].number = conditionNumber THEN foundIndex := i END
		END;
		ASSERT(foundIndex # None);
		w.String(conditionEntries[foundIndex].name);
	END DumpConditionName;

	(** dump the name of a register (the last name entered is preferred) **)
	PROCEDURE DumpRegisterName*(w: Streams.Writer; registerNumber: LONGINT);
	VAR
		i, foundIndex: LONGINT;
	BEGIN
		(* go through all register names *)
		foundIndex := None;
		FOR i := 0 TO NumberRegisterEntries - 1 DO
			IF registerEntries[i].number = registerNumber THEN foundIndex := i END
		END;
		ASSERT(foundIndex # None);
		w.String(registerEntries[foundIndex].name);
	END DumpRegisterName;

	PROCEDURE DumpOperand*(w: Streams.Writer; CONST operand: Operand);
	VAR i: LONGINT; first: BOOLEAN; mode: LONGINT;
	BEGIN
		mode := operand.mode; (* debugging *)
		CASE operand.mode OF
			| None: w.String("NONE!")
			| modeCoprocessor: w.String("P"); w.Int(operand.coprocessor, 1)

			| modeImmediate: w.String("#"); w.Int(operand.immediate, 1)

			| modeMemory: w.String("[");
				IF operand.register # None THEN
					DumpRegisterName(w, operand.register)
				END;
				IF PostIndexed IN operand.indexing THEN
					w.String("]")
				END;
				w.String(", ");
				IF operand.offsetRegister= None THEN
					w.String("#")
				END;
				IF Decrement IN operand.indexing THEN w.String("-");
				ELSIF Increment IN operand.indexing THEN w.String("+");
				ELSE HALT(100);
				END;
				IF operand.offsetRegister= None THEN
					(*
					w.Hex(operand.offsetImmediate, 1);w.String("H");
					*)
					w.Int(operand.offsetImmediate, 0)
				ELSE
					DumpRegisterName(w, operand.offsetRegister)
				END;
				IF operand.shiftMode # None THEN
					w.String(", ");
					w.String(shiftNames[operand.shiftMode]);
					IF operand.shiftMode # shiftRRX THEN
						w.String(" ");
						IF operand.shiftRegister # None THEN
							DumpRegisterName(w, operand.shiftRegister)
						ELSE
							w.String("#"); w.Int(operand.shiftImmediate, 1);
						END;
					END;
				END;
				IF ~(PostIndexed IN operand.indexing) THEN
					w.String("]");
				END;
				IF PreIndexed IN operand.indexing  THEN w.String("!") END

			| modeOpcode: w.Int(operand.opcode, 0)

			| modeRegister:
				DumpRegisterName(w, operand.register);
				IF (operand.shiftMode # None)  THEN
					w.String(", ");
					w.String(shiftNames[operand.shiftMode]);
					IF operand.shiftMode # shiftRRX THEN
						w.String(" ");
						IF operand.shiftRegister # None THEN
							DumpRegisterName(w, operand.shiftRegister)
						ELSE
							w.String("#"); w.Int(operand.shiftImmediate, 1);
						END;
					END;
				END

			| modeRegisterList:
				w.String("{");first := TRUE;
				FOR i := 0 TO 31 DO
					IF i IN operand.registerList THEN
						IF ~first THEN w.String(", ") ELSE first := FALSE END;
						DumpRegisterName(w, i + operand.register)
					END;
				END;
				w.String("}");

			| modeOption:
				w.String("{"); w.Int(operand.option, 1); w.String("}")

			| modeRegisterWithFields:
				DumpRegisterName(w, operand.register);
				w.String("_");
				IF fieldF IN operand.fields THEN w.String("f") END;
				IF fieldS IN operand.fields THEN w.String("s") END;
				IF fieldX IN operand.fields THEN w.String("x") END;
				IF fieldC IN operand.fields THEN w.String("c") END;
		END;
	END DumpOperand;

	PROCEDURE DumpInstruction*(w: Streams.Writer; CONST instruction: Instruction);
	VAR i: LONGINT;
	BEGIN
		IF instruction.format= None THEN
			w.String("undefined format"); w.Ln;
		ELSE
			w.String(mnemonics[instructionFormats[instruction.format].mnemonic].name);
		END;
		IF (instruction.condition # None) & (instruction.condition # conditionAL) THEN
			DumpConditionName(w, instruction.condition)
		END;
		FOR i := 0 TO NumberFlags-1 DO
			IF i IN instruction.flags THEN
				w.String(flagNames[i]);
			END;
		END;
		i := 0;
		WHILE (i<MaxOperands) & (instruction.operands[i].mode # None) DO
			IF i > 0 THEN w.String(", ") ELSE w.String(" ") END;
			DumpOperand(w, instruction.operands[i]);
			IF (i= 0) & (flagBaseRegisterUpdate IN instruction.flags) THEN w.String("!")
			ELSIF (i= 1) & (flagUserMode IN instruction.flags) THEN w.String("^");
			END;
			INC(i);
		END;
	END DumpInstruction;

	PROCEDURE Test*(context: Commands.Context);
	VAR str: ARRAY 32 OF CHAR; mnemonic: LONGINT; condition: LONGINT; flags: SET; i: LONGINT;
	BEGIN
		IF context.arg.GetString(str) THEN
			IF FindMnemonic(str, mnemonic, condition, flags) THEN
				context.out.String("found: "); context.out.String(mnemonics[mnemonic].name);
				IF condition # None THEN
					context.out.String(":");
					context.out.String(conditionEntries[condition].name);
				END;
				FOR i := 0 TO NumberFlags DO
					IF i IN flags THEN
						context.out.String(":");
						context.out.String(flagNames[i]);
					END;
				END;
			END;
		END;
	END Test;

	PROCEDURE Test2*(context: Commands.Context);
	VAR operands: ARRAY 3 OF Operand; mnemonic: LONGINT; condition: LONGINT; flags: SET; instruction: Instruction;
	BEGIN
		InitRegister(operands[0], R0, None, None, 0);
		InitRegister(operands[1], R1, None, None, 0);
		InitRegister(operands[2], R1, shiftLSR, None, 8);
		IF FindMnemonic("ADDEQ", mnemonic, condition, flags) THEN
			IF MakeInstruction(instruction, mnemonic, condition, flags, operands) THEN
				DumpInstruction(context.out, instruction);
			ELSE
				context.error.String("instruction not found");
			END
		ELSE
			context.error.String("mnemonic not found");
		END;
	END Test2;

	PROCEDURE ReadCode(file: Files.File): BitSets.BitSet;
	VAR r: Files.Reader;  val: LONGINT;bitSet: BitSets.BitSet; adr: LONGINT;
	BEGIN
		IF file = NIL THEN RETURN NIL END;
		adr := 0;
		NEW(r, file, 0);
		NEW(bitSet,0);
		WHILE r.Available()>0 DO
			r.RawLInt(val);
			INC(adr);
			bitSet.Resize(adr*32);
			bitSet.SetBits((adr-1)*32,32,val);
		END;
		RETURN bitSet
	END ReadCode;

	PROCEDURE Disassemble*(context: Commands.Context);
	TYPE
		Disasm = OBJECT (Disassembler.Disassembler)

			PROCEDURE DisassembleInstruction(bitSet: BitSets.BitSet; VAR adr: LONGINT; maxInstructionSize: LONGINT; w:Streams.Writer);
			VAR instruction: Instruction; value: LONGINT; mnemonic: LONGINT;
			BEGIN
				(* maxInstructionSize can be ignored here *)
				value := bitSet.GetBits(adr*8,32);
				IF Decode(value, instruction) THEN
					DumpInstruction(w, instruction);
					mnemonic := instructionFormats[instruction.format].mnemonic;
					IF (mnemonic = opBL) OR (mnemonic = opB) THEN
						WriteReference(instruction.operands[0].immediate+adr+8, TRUE (* points to code section *), w);

					ELSIF (mnemonic = opLDR) OR (mnemonic = opSTR) THEN
						(* LDR? ..., [PC, #...] or STR? ..., [PC, #...] *)
						ASSERT(instruction.operands[1].mode = modeMemory);
						IF (instruction.operands[1].register = PC) & (instruction.operands[1].offsetRegister = None) THEN
							IF Decrement IN instruction.operands[1].indexing THEN 
								value := -instruction.operands[1].offsetImmediate + adr + 8;
							ELSE
								value := instruction.operands[1].offsetImmediate + adr + 8;
							END;
							WriteReference(value, TRUE, w);
							IF value * 8 + 32 < bitSet.GetSize() THEN
								WriteReference(bitSet.GetBits(value * 8, 32) - codeDisplacement, TRUE, w); (* note that data references cannot be resolved like this *)
							END
						END
					END;
				ELSE
					w.String("*** COULD NOT DECODE ***");
				END;
				INC(adr,4);
			END DisassembleInstruction;

		END Disasm;

	VAR disassembler: Disasm; codeFileName, dataFileName, logFileName: Files.FileName; codeFile, logFile: Files.File;code: BitSets.BitSet; options: Options.Options;
		address, offset: LONGINT;
	BEGIN
		IF context.arg.GetString(codeFileName) THEN
			codeFile := Files.Old(codeFileName);
			IF codeFile = NIL THEN context.out.String("file not found "); context.out.String(codeFileName); RETURN END;
			NEW(options);
			options.Add("l","logFile", Options.String);
			options.Add("a","address",Options.Integer);
			options.Add("o","offset",Options.Integer);
			IF options.Parse(context.arg, context.out) THEN
				IF ~options.GetInteger("a", address) THEN address := 0 END;
				NEW(disassembler, context.out);
				code := ReadCode(codeFile);
				IF options.GetString("logFile",logFileName) THEN
					logFile := Files.Old(logFileName);
				ELSE
					logFile := disassembler.GetLogFile(codeFileName)
				END;
				IF options.GetInteger("o",offset) THEN
					disassembler.SetDisplacements(offset,offset)
				END;
				disassembler.Disassemble(code, code, 8,8 , logFile, address);
			END;
		END;
	END Disassemble;


BEGIN Init;
END FoxARMInstructionSet.

SystemTools.FreeDownTo FoxARMInstructionSet ~

FoxARMInstructionSet.Test BLEQSB  ~
FoxARMInstructionSet.Test2 ~
FoxARMInstructionSet.Test3 "E:/Systembau11/WinAos/Work/Minos.boot"  ~
