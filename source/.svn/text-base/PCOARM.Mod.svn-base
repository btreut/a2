(* Paco, Copyright 2000, Patrik Reali, ETH Zurich *)

MODULE PCOARM;	(** be  **)

(** Code Generator for ARM. Not concurrent ! *)

IMPORT SYSTEM, Files, PCLIR, PCM(*Trace, PCARMDecoder *), Diagnostics;

CONST
	(*Trace = FALSE; *)

	INTERNALERROR* = 100;
	UNIMPLEMENTED* = 101;
	NONORTHOGONALITYEXCEPTION* = 102;
	ErrBranchOffsetTooBig* = 110;
	ErrImmediateTooSmall* = 111;
	ErrImmediateTooBig* = 112;
	ErrRotateImmTooBig* = 113;
	ErrRotateImmOdd* = 114;
	ErrInvalidRegister* = 115;
	ErrInvalidRegisterSet* = 116;
	ErrInvalidMode* = 117;
	ErrCaseOffsetTooBig* = 118;

	MaxCodeLength* = 256*1024;

	InstructionSize* = 4; (* size of one instruction, in bytes *)

	(** Conditions - instruction is executed if CPSR satisfies the condition *)
	EQ* = { };	(** equal *)
	NE* = { 28 };	(** not equal *)
	CS* = { 29 };	(** carry set *)
	HS* = CS;	(** unsigned higher or same *)
	CC* = { 29, 28 };	(** carry clear *)
	LO* = CC;	(** unsigned lower *)
	MI* = { 30 };	(** minus/negative *)
	PL* = { 30, 28 };	(** plus/positive or zero *)
	VS* = { 30, 29 };	(** overflow *)
	VC* = { 30, 29, 28 };	(** no overflow *)
	HI* = { 31 };	(** unsigned higher *)
	LS* = { 31, 28 };	(** unsigned lower or same *)
	GE* = { 31, 29 };	(** signed greater or equal *)
	LT* = { 31, 29, 28 };	(** signed less than *)
	GT* = { 31, 30 };	(** signed greater than *)
	LE* = { 31, 30, 28 };	(** signed less than or equal *)
	AL* = { 31, 30, 29 };	(** always *)
	CondMask* = { 31, 30, 29, 28 };

	(** Registers *)
	R0* = 0; R1* = 1; R2* = 2; R3* = 3; R4* = 4; R5* = 5; R6* = 6; R7* = 7; R8* = 8; R9* = 9; R10* = 10; R11* = 11;
	FP* = 12;	(** frame pointer *)
	SP* = 13;	(** stack pointer *)
	LR* = 14;	(** return address *)
	PC* = 15;	(** program counter *)
	Registers* = {15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 }; (** valid registers *)
	CPSR* = {};	(** current program status register *)
	SPSR* = { 22 };	(** saved program status register *)
	CR0* = 0; CR1* = 1; CR2* = 2; CR3* = 3; CR4* = 4; CR5* = 5; CR6* = 6; CR7* = 7; CR8* = 8; CR9* = 9; CR10* = 10;
	CR11* = 11; CR12* = 12; CR13* = 13; CR14* = 14; CR15* = 15; (** coprocessor registers *)

	(** PSR flags *)
	PSRc* = { 16 };	(** control fields *)
	PSRx* = { 17 };	(** extension fields *)
	PSRs* = { 18 };	(** status fields *)
	PSRf* = { 19 };	(** flags fields *)

	(** useful Bit-Masks *)
	Mask24* = { 0..23 };
	MaskRd* = { 15, 14, 13, 12 };

	(** Common modifiers *)
	Sflag* = { 20 };	(** if set, the condition codes are updated *)
	Bflag* = { 22 };	(** distinguishes between a SWP and a SWPB instruction *)
	Lflag* = { 22 };	(** LDC/STC: specifies long load/store *)
	Lsl* = { };	(** logical shift left *)
	LSR* = { 5 };	(** logical shift right *)
	Asr* = { 6 };	(** arithmetic shift right *)
	Ror* = { 6, 5 };	(** rotate right *)
	RRX* = Ror;	(** rotate right with extend *)
	ShiftMask = { 6, 5 };
	Load* = { 20 };	(** load *)
	Store* = { };	(** store *)
	IdxAdd* = { 23 };	(** load/store: the index is added to the base register *)
	IdxSub* = { };	(** load/store: the index is subtracted from the base register *)
	Offset* = { 24 };	(** load/store: offset addressing *)
	PreIdxd* = { 24, 21 };	(** load/store: pre-indexed addressing *)
	PostIdxd* = { };	(** laod/store: post-indexed addressing *)

	(** Addressing Mode 1 - Data-processing operands *)
	A1Imm* = { 25 };	(** shifterOperand contains an 8-bit immediate value plus a 4-bit rotate immediate value *)
	A1Reg* =  { };	(** shifterOperand contains a register *)
	A1ShiftImm* = { };	(** shifterOperand contains a register and is shifted by an immeditae *)
	A1ShiftReg* = { 4 }; 	(** shifterOperand contains a register and is shifted by a register *)

	A1Immediate0* = {};	(** prepared immediate values: 0, 1, 2, 4 and 8 *)
	A1Immediate1* = { 0 };
	A1Immediate2* = { 1 };
	A1Immediate4* = { 2 };
	A1Immediate8* = { 3 };
	A1Immediate31* = { 4, 3, 2, 1, 0 };

	(** Addressing Mode 2 - Load and Store Words or Unsigned Byte *)
	A2Mode* = { 26 };	(** load/store word/unsigned byte *)
	A2Word* = { };	(** load/store word *)
	A2Byte* = { 22 };	(** load/store byte *)
	A2Imm* = { };	(** address contains an immediate value *)
	A2Reg* = { 25 };	(** address contains a register *)
	A2WImmOffset* = A2Word + A2Imm + Offset;
	A2WRegOffset* = A2Word + A2Reg + Offset;
	A2BImmOffset* = A2Byte + A2Imm + Offset;
	A2BRegOffset* = A2Byte + A2Reg + Offset;
	A2WImmPreIdxd* = A2Word + A2Imm + PreIdxd;
	A2WRegPreIdxd* = A2Word + A2Reg + PreIdxd;
	A2WImmPostIdxd* = A2Word + A2Imm + PostIdxd;
	A2WRegPostIdxd* = A2Word + A2Reg + PostIdxd;
	A2BImmPostIdxd* = A2Byte + A2Imm + PostIdxd;
	A2BRegPostIdxd* = A2Byte + A2Reg + PostIdxd;
	A2AddrModeMask = { 25, 24, 23, 22, 21 };

	(** Addressing Mode 3 - Miscellaneous Loads and Stores *)
	A3Mode* = { 7, 4 };	(** micellaneous load/store *)
	A3Halfword* = { 5 };	(** load/store halfword *)
	A3Byte* = { };	(** load/store byte *)
	A3Imm* = { 22 };	(** address contains an immediate value *)
	A3Reg* =  { };	(** address contains a register *)
	A3Signed* = { 6 };	(** signed halfword/byte *)
	A3Unsigned* = { };	(** unsigned halfword/byte *)
	A3SHImmOffset* = A3Halfword + A3Imm + A3Signed + Offset;
	A3UHImmOffset* = A3Halfword + A3Imm + A3Unsigned + Offset;
	A3SHRegOffset* = A3Halfword + A3Reg + A3Signed + Offset;
	A3UHRegOffset* = A3Halfword + A3Reg + A3Unsigned + Offset;
	A3SBImmOffset* = A3Byte + A3Imm + A3Signed + Offset;
	A3UBImmOffset* = A3Byte + A3Imm + A3Unsigned + Offset;
	A3SBRegOffset* = A3Byte + A3Reg + A3Signed + Offset;
	A3UBRegOffset* = A3Byte + A3Reg + A3Unsigned + Offset;
	A3AddrModeMask = { 24, 23, 22, 21, 7, 6, 5, 4 };

	(** Addressing Mode 4 - Load and Store Multiple *)
	A4IA* = { 23 };	(** increment after *)
	A4IB* = { 24, 23 };	(** increment before *)
	A4DA* = { }; 	(** decrement after *)
	A4DB* = { 24 };	(** decrement before *)
	A4W* = { 21 };	(** update address register *)
	A4User* = { 22 };	(** load/store user mode registers *)
	A4LDMMask* = { 20 };	(** if this bit is set, it's a LDM (ifffff it's a addressing mode 4 instruction, Hobbes, idiot) *)

	(** Addressing Mode 5 - Load and Store Coprocessor *)
	A5W* = { 21 };	(** update base register *)
	A5Offset* = { };	(** offset addressing *)
	A5PreIdxd* = { 21 };	(** pre-indexed addressing *)
	A5PostIdxd* = { 24, 21 };	(** post-indexed addressing *)
	A5UnIdxd* = { 24 };	(** unindexed addressing *)

	(** Miscellaneous *)
	MSRImmediate* = { 25 };	(** the operand is a 8bit immediate *)
	MSRRegister* = { };	(** the operand is a register *)


	(** Instruction Opcodes *)

	(* data-processing instructions *)
	opADC* = { 23, 21 };
	opADD* = { 23 };
	opAND* = { };
	opBIC* = { 24, 23, 22 };
	opCMN* = { 24, 22, 21, 20 };
	opCMP* = { 24, 22, 20 };
	opEOR* = { 21 };
	opMOV* = { 24, 23, 21 };
	opMVN* = { 24, 23, 22, 21 };
	opORR* = { 24, 23 };
	opRSB* = { 22, 21 };
	opRSC* = { 23, 22, 21 };
	opSBC* = { 23, 22 };
	opSUB* = { 22 };
	opTEQ* = { 24, 21, 20 };
	opTST* =  { 24, 20 };

	opMRS* = { 24, 19, 18, 17, 16 };
	opMSR* =  { 24, 21, 15, 14, 13, 12 };

	(* multiply instructions *)
	opMLA* = { 21, 7, 4 };
	opMUL* = { 7, 4 };
	opSMLAL* = { 23, 22, 21, 7, 4 };
	opSMULL* = { 23, 22, 7, 4 };
	opUMLAL* = { 23, 21, 7, 4 };
	opUMULL* = { 23, 7, 4 };

	(* branch instructions *)
	opB* = { 27, 25 };
	LinkBit* = { 24 };
	opBL* = opB + LinkBit;
	BMask* = { 27, 25, 24 };

	(* load/store instructions *)
	opLDM* = { 27, 20 };
	opLDR* = { 26, 20 };
	opLDRH* = { 20, 7, 4 };
	opSTM* = { 27 };
	opSTR* = { 26 };
	opSTRH* = { 7, 5, 4 };

	(* semaphore instructions *)
	opSWP* = { 24, 7, 4 };

	(* exception-generating instructions *)
	opSWI* = {27, 26, 25, 24 };	(* software interrupt *)
	opBKPT* = { 31, 30, 29, 24, 21, 6, 5, 4 };

	(* coprocessor instructions *)
	opCDP* = { 27, 26, 25 };
	opLDC* = { 27, 26, 20 };
	opMCR* = { 27, 26, 25, 4 };
	opMRC* = { 27, 26, 25, 20, 4 };
	opSTC* = { 27, 26 };



TYPE
	DCDList = POINTER TO RECORD
		pc: LONGINT;
		next: DCDList;
	END;

	Callback* = PROCEDURE {DELEGATE} (pc: LONGINT);

VAR
	(*Trace W: Texts.Writer;
	t: Texts.Text; *)
	AddrMode: ARRAY 5 OF SET; (* contains bitmasks for validity checks *)
	f: Files.File;
	r: Files.Rider;
	start: LONGINT;
	code: PCLIR.CodeArray;
	codelen: LONGINT;
	codeTooLong: BOOLEAN;
	sourcepos*: LONGINT;
	dcd: BOOLEAN;
	codeBarrier: LONGINT;
	codeBarrierCallback: Callback;
	callbackLocked: BOOLEAN;

PROCEDURE GetCodePos*(): LONGINT;
BEGIN RETURN codelen
END GetCodePos;

PROCEDURE GetInstruction*(pos: LONGINT): SET;
VAR factor, i, l: LONGINT;
BEGIN ASSERT(pos < codelen);
	factor := 1;
	FOR i := 0 TO 3 DO
		l := l + ORD(code[pos+i])*factor;
		factor := factor*100H
	END;
	IF PCM.bigEndian THEN PCM.SwapBytes(l, 0, 4) END;

	RETURN SYSTEM.VAL(SET, l)
END GetInstruction;

PROCEDURE GetCode*(VAR codeArr: PCLIR.CodeArray; VAR length, hdrLength, addressFactor: LONGINT);
BEGIN
	codeArr := code; length := codelen; hdrLength := codelen DIV 4; addressFactor := 4
END GetCode;

PROCEDURE Lsh(v, s: LONGINT): SET;
BEGIN RETURN SYSTEM.VAL(SET, LSH(v,s))
END Lsh;

(*
PROCEDURE CheckCondition(c: SET);
BEGIN ASSERT(c - {31, 30, 29, 28} = {})
END CheckCondition;

PROCEDURE CheckAddressingMode(mode: LONGINT; am: SET);
BEGIN ASSERT(am - AddrMode[mode-1] = {})
END CheckAddressingMode;
*)

PROCEDURE CheckReg(register: LONGINT);
BEGIN ASSERT((0 <= register) & (register < 16), ErrInvalidRegister)
END CheckReg;

(*
PROCEDURE CheckRegisterSet(registers: SET);
BEGIN ASSERT (registers - Registers = {}, ErrInvalidRegisterSet)
END CheckRegisterSet;
*)

PROCEDURE CheckImm(imm, max: LONGINT);
BEGIN ASSERT((0 <= imm) & (imm < max), ErrImmediateTooBig)
END CheckImm;

(*
PROCEDURE CheckSignedImm(imm, min, max: LONGINT);
BEGIN ASSERT((min < imm), ErrImmediateTooSmall);
	ASSERT((imm < max), ErrImmediateTooBig)
END CheckSignedImm;
*)

PROCEDURE CheckSet(set, mask: SET);
BEGIN ASSERT(set * (-mask) = {}, ErrInvalidMode)
END CheckSet;

(** Addressing Mode 3 Helpers *)
PROCEDURE MakeA3Immediate*(VAR addrMode: SET; offset: LONGINT): SET;
VAR neg: BOOLEAN; address: SET;
BEGIN
	neg := offset < 0; offset := ABS(offset);
	ASSERT(offset < 100H);
		(* address[11:8] = offset[7:4], address[3:0] = offset[3:0] *)
	address := SYSTEM.VAL(SET, 100H*(offset DIV 10H) + (offset MOD 10H));
	addrMode := addrMode - (A3Imm + IdxAdd + IdxSub);
	addrMode := addrMode + A3Imm;
	IF ~neg THEN addrMode := addrMode + IdxAdd
	ELSE addrMode := addrMode + IdxSub
	END;
	RETURN address
END MakeA3Immediate;

PROCEDURE MakeA3Register*(register: LONGINT): SET;
BEGIN RETURN SYSTEM.VAL(SET, register)
END MakeA3Register;

(**----- Data Processing  Instructions (Addressing Mode 1) -------*)
PROCEDURE MakeA1Immediate*(immediate: LONGINT; VAR imm: SET): BOOLEAN;
VAR rot: LONGINT;
BEGIN
	rot := 0; imm := SYSTEM.VAL(SET, immediate);
	WHILE (rot < 32) & (ODD(rot) OR (imm * { 8..31} # {})) DO
		imm := ROT(imm, 1); INC(rot)
	END;
	IF (rot < 32) THEN
		imm := imm + SYSTEM.VAL(SET, Lsh(rot DIV 2, 8));
		RETURN TRUE
	ELSE
		imm := {};
		RETURN FALSE
	END
END MakeA1Immediate;

PROCEDURE MakeA1Register*(reg: LONGINT): SET;
BEGIN CheckReg(reg);
	RETURN SYSTEM.VAL(SET, reg)
END MakeA1Register;

PROCEDURE MakeA1RegSHIFTReg*(reg, shiftreg: LONGINT; mode: SET): SET;
BEGIN CheckReg(reg); CheckReg(shiftreg); CheckSet(mode, ShiftMask);
	RETURN Lsh(shiftreg, 8) + mode + A1ShiftReg + SYSTEM.VAL(SET, reg)
END MakeA1RegSHIFTReg;

PROCEDURE MakeA1RegSHIFTImm*(reg, imm: LONGINT; mode: SET): SET;
BEGIN CheckReg(reg); CheckImm(imm, 20H); CheckSet(mode, ShiftMask);
	RETURN Lsh(imm, 7) + mode + A1ShiftImm + SYSTEM.VAL(SET, reg)
END MakeA1RegSHIFTImm;

(** ADC - add with carry (rD <- rN + shifterOperand + carry) *)
PROCEDURE ADC*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opADC + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END ADC;

(** ADD -  add (rD <- rN + shifterOperand) *)
PROCEDURE ADD*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opADD + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END ADD;

(** AND - bitwise and (rD <- rN AND shifterOperand) *)
PROCEDURE AND*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN CheckSet(shifterOperand, {0..11});
	Code(cond + opAND + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END AND;

(** BIC - clears bits (rD <- rN AND NOT shifterOperand) *)
PROCEDURE BIC*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opBIC + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END BIC;

(** CMN - compare negative (CC updated based on rN + shifterOperand) *)
PROCEDURE CMN*(cond, addrMode: SET; rN: LONGINT; shifterOperand: SET);
BEGIN Code(cond + opCMN + addrMode + Lsh(rN, 16) + shifterOperand)
END CMN;

(** CMP - compare (CC updateed based on rN - shifterOperand) *)
PROCEDURE CMP*(cond, addrMode: SET; rN: LONGINT; shifterOperand: SET);
BEGIN Code(cond + opCMP + addrMode + Lsh(rN, 16) + shifterOperand)
END CMP;

(** EOR - XOr (rD <- rN XOR shifterOperand) *)
PROCEDURE EOR*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opEOR + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END EOR;

(** MOV - move (rD <- shifterOperand) *)
PROCEDURE MOV*(cond, addrMode: SET; rD: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opMOV + addrMode + Lsh(rD, 12) + shifterOperand + S)
END MOV;

(** MVN - move negative (rD <- NOT shifterOperand) *)
PROCEDURE MVN*(cond, addrMode: SET; rD: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opMVN + addrMode + Lsh(rD, 12) + shifterOperand + S)
END MVN;

(** ORR - bitwise OR (rD <- rN OR shifterOperand) *)
PROCEDURE ORR*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opORR + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END ORR;

(** RSB -  reverse subtract (rD <- shifterOperand - rN) *)
PROCEDURE RSB*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opRSB + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END RSB;

(** RSC -  reverse subtract with carry (rD <- shifterOperand - rN - NOT(carry)) *)
PROCEDURE RSC*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opRSC + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END RSC;

(** SBC - subtract with carry (rD <- rN - shifterOperand - NOT(carry))*)
PROCEDURE SBC*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opSBC + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END SBC;

(** SUB -  subtract (rD <- rN - shifterOperand) *)
PROCEDURE SUB*(cond, addrMode: SET; rD, rN: LONGINT; shifterOperand, S: SET);
BEGIN Code(cond + opSUB + addrMode + Lsh(rN, 16) + Lsh(rD, 12) + shifterOperand + S)
END SUB;

(** TEQ -  test equivalence (CC updated based on rN XOR shifterOperand) *)
PROCEDURE TEQ*(cond, addrMode: SET; rN: LONGINT; shifterOperand: SET);
BEGIN Code(cond + opTEQ + addrMode + Lsh(rN, 16) + shifterOperand)
END TEQ;

(** TST -  test (CC updated based on rN AND shifterOperand) *)
PROCEDURE TST*(cond, addrMode: SET; rN: LONGINT; shifterOperand: SET);
BEGIN Code(cond + opTST + addrMode + Lsh(rN, 16) + shifterOperand)
END TST;

(**----------------------- Multiply  Instructions -----------------------*)
(** MLA - multiply accumulate (rD <- (rM * rS) + rN) *)
PROCEDURE MLA*(cond: SET; rD, rM, rS, rN: LONGINT; S: SET);
BEGIN ASSERT(rD # rM, NONORTHOGONALITYEXCEPTION);
	Code(cond + opMLA + Lsh(rD, 16) + Lsh(rN, 12) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END MLA;

(** MUL - multiply (rD <- rM * rS) *)
PROCEDURE MUL*(cond: SET; rD, rM, rS: LONGINT; S: SET);
BEGIN ASSERT(rD # rM, NONORTHOGONALITYEXCEPTION);
	Code(cond + opMUL + Lsh(rD, 16) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END MUL;

(** SMLAL - signed multiply accumulate long (rDLo <- (rA * rB)[31:0] + rDLo, rDHi <- (rA * rB)[63:32] + rDHi + carry) *)
PROCEDURE SMLAL*(cond: SET; rDHi, rDLo, rM, rS: LONGINT; S: SET);
BEGIN ASSERT((rDHi # rDLo) & (rDHi # rM) & (rDLo # rM), NONORTHOGONALITYEXCEPTION);
	Code(cond + opSMLAL + Lsh(rDHi, 16) + Lsh(rDLo, 12) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END SMLAL;

(** SMULL - signed multiply long (rDLo <- (rM * rS)[31:0], rDHi <- (rM * rS)[63:32]) *)
PROCEDURE SMULL*(cond: SET; rDHi, rDLo, rM, rS: LONGINT; S: SET);
BEGIN ASSERT((rDHi # rDLo) & (rDHi # rM) & (rDLo # rM), NONORTHOGONALITYEXCEPTION);
	Code(cond + opSMULL + Lsh(rDHi, 16) + Lsh(rDLo, 12) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END SMULL;

(** UMLAL - unsigned multiply accumulate long (rDLo <- (rM*rS)[31:0] + rDLo, rDHi <- (rM*rS)[63:32] + rDHi + carry) *)
PROCEDURE UMLAL*(cond: SET; rDLo, rDHi, rM, rS: LONGINT; S: SET);
BEGIN ASSERT((rDHi # rDLo) & (rDHi # rM) & (rDLo # rM), NONORTHOGONALITYEXCEPTION);
	Code(cond + opUMLAL + Lsh(rDHi, 16) + Lsh(rDLo, 12) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END UMLAL;

(** UMULL - unsigned multply long (rDLo <- (rM*rS)[31:0], rDHi <- (rM*rS)[63:32]) *)
PROCEDURE UMULL*(cond: SET; rDLo, rDHi, rM, rS: LONGINT; S: SET);
BEGIN ASSERT((rDHi # rDLo) & (rDHi # rM) & (rDLo # rM), NONORTHOGONALITYEXCEPTION);
	Code(cond + opUMULL + Lsh(rDHi, 16) + Lsh(rDLo, 12) + Lsh(rS, 8) + Lsh(rM, 0) + S)
END UMULL;

(**------------------------- Branch  Instructions  -------------------------*)

(** B - branch to address. (PC <- PC + extS(address << 2)). Hint: PC is 2 instructions ahead *)
PROCEDURE B*(cond: SET; address: LONGINT);
BEGIN ASSERT((ABS(address) < 1000000H), ErrBranchOffsetTooBig);
	ASSERT(cond # {31, 30, 29, 28});
	Code(cond + opB + Mask24*SYSTEM.VAL(SET, address))
END B;

(** BL - branch to address. (LR <- address of instr. after branch instruction, PC <- PC + extS(address << 2))
	Hint: - PC is 2 instructions ahead *)
PROCEDURE BL*(cond: SET; address: LONGINT);
BEGIN Code(cond + opBL + Mask24*SYSTEM.VAL(SET, address))
END BL;

(**------------ Load/Store Instructions (Addressing Modes 2, 3 & 4) --------------*)

PROCEDURE MakeA2Immediate*(VAR addrMode: SET; offset: LONGINT): SET;
VAR neg: BOOLEAN; address: SET;
BEGIN
	neg := offset < 0; offset := ABS(offset);
	ASSERT(offset < 1000H);
	address := SYSTEM.VAL(SET, offset);
	addrMode := addrMode - (A2Imm + IdxAdd + IdxSub);
	addrMode := addrMode + A2Imm;
	IF ~neg THEN addrMode := addrMode + IdxAdd
	ELSE addrMode := addrMode + IdxSub
	END;
	RETURN address
END MakeA2Immediate;

PROCEDURE MakeA2Register*(register: LONGINT): SET;
BEGIN RETURN SYSTEM.VAL(SET, register)
END MakeA2Register;

PROCEDURE MakeA2ScaledRegister*(reg: LONGINT; mode: SET; shift: LONGINT): SET;
BEGIN CheckReg(reg); CheckImm(shift, 20H); CheckSet(mode, ShiftMask);
	RETURN Lsh(shift, 7) + mode + Lsh(reg, 0)
END MakeA2ScaledRegister;

(** LDM - uses Addressing Mode 4 *)
PROCEDURE LDM*(cond, addrMode: SET; rD: LONGINT; registers, W: SET);
BEGIN Code(cond + opLDM + addrMode + Lsh(rD, 16) + registers + W)
END LDM;

(** LDR - uses Addressing Mode 2 *)
PROCEDURE LDR*(cond, addrMode: SET; rD, rAdr: LONGINT; address: SET);
BEGIN Code(cond + opLDR + addrMode + Lsh(rAdr, 16) + Lsh(rD, 12) + address)
END LDR;

(** LDRH - uses Addressing Mode 3 *)
PROCEDURE LDRH*(cond, addrMode: SET; rD, rAdr: LONGINT; address: SET);
BEGIN Code(cond + opLDRH + addrMode + Lsh(rAdr, 16) + Lsh(rD, 12) + address)
END LDRH;

(** STM - uses Addressing Mode 4 *)
PROCEDURE STM*(cond, addrMode: SET; rD: LONGINT; registers, W: SET);
BEGIN Code(cond + opSTM + addrMode + Lsh(rD, 16) + registers + W)
END STM;

(** STR - uses Addressing Mode 2 *)
PROCEDURE STR*(cond, addrMode: SET; rAdr, rS: LONGINT; address: SET);
BEGIN Code(cond + opSTR + addrMode + Lsh(rAdr, 16) + Lsh(rS, 12) + address)
END STR;

(** STRH - uses Addressing Mode 3 *)
PROCEDURE STRH*(cond, addrMode: SET; rAdr, rS: LONGINT; address: SET);
BEGIN ASSERT(address*{6,5}={}, NONORTHOGONALITYEXCEPTION);
	Code(cond + opSTRH + addrMode + Lsh(rAdr, 16) + Lsh(rS, 12) + address)
END STRH;

(**--------------------------- Miscellaneous -----------------------------*)

(** SWI - software interrupt *)
PROCEDURE SWI*(cond: SET; code: LONGINT);
BEGIN CheckImm(code, 1000000H);
	Code(cond + opSWI + Mask24*Lsh(code, 0))
END SWI;

(** DCD - puts a 32bit value into the code *)
PROCEDURE DCD*(value: LONGINT);
BEGIN dcd := TRUE; Code(SYSTEM.VAL(SET, value))
END DCD;

(**--------------------------- Fixup Handling -------------------------------*)
(* Lock - does not allow automatic flushing of the constant pool. Not reentrant. *)
PROCEDURE Lock*;
BEGIN callbackLocked := TRUE
END Lock;

(* Unlock - allows automatic flushing of the constant pool. Not reentrant *)
PROCEDURE Unlock*;
BEGIN callbackLocked := FALSE; CheckCallback
END Unlock;

(* SetConstantPoolBarrier - *)
PROCEDURE SetConstantPoolBarrier*(pc: LONGINT);
BEGIN
	ASSERT((codelen < pc) & (pc < codelen + 1000H) OR (pc = -1), INTERNALERROR);
	codeBarrier := pc
END SetConstantPoolBarrier;

(* SetConstantPoolBarrierCallback - *)
PROCEDURE SetConstantPoolBarrierCallback*(callback: Callback);
BEGIN
	codeBarrierCallback := callback
END SetConstantPoolBarrierCallback;

(* CheckCallback - calls the callback handler if necessary *)
PROCEDURE CheckCallback;
BEGIN
	IF ~callbackLocked & (codeBarrier # -1) & (codeBarrierCallback # NIL) & (codelen >= codeBarrier) THEN
		Lock; (* lock or we'll get a stack overflow due to endless recursion *)
		codeBarrierCallback(codelen);
		Unlock
	END
END CheckCallback;

PROCEDURE ExtractRegister(code: SET; pos: LONGINT): LONGINT;
BEGIN RETURN LSH(SYSTEM.VAL(LONGINT, code), -pos) MOD 10H
END ExtractRegister;

PROCEDURE FixLoad*(pc: LONGINT; address: LONGINT);
VAR b, addrMode, addr: SET; currPos: LONGINT;
BEGIN
	b := GetInstruction(pc);
	currPos := codelen;
	codelen := pc;
	IF (b * opLDR = opLDR) THEN
		addrMode := b * A2AddrModeMask;
		addr := MakeA2Immediate(addrMode, address);
		LDR(b*CondMask, addrMode, ExtractRegister(b, 12), ExtractRegister(b, 16), addr)
	ELSIF (b * opLDRH = opLDRH) THEN
		addrMode := b * A3AddrModeMask;
		addr := MakeA3Immediate(addrMode, address);
		LDRH(b*CondMask, addrMode, ExtractRegister(b, 12), ExtractRegister(b, 16), addr)
	ELSE HALT(INTERNALERROR)
	END;
	codelen := currPos;
END FixLoad;

PROCEDURE FixJump*(pc: LONGINT; address: LONGINT);
VAR b: SET; currPos: LONGINT;
BEGIN
	b := GetInstruction(pc);
	ASSERT(b * opB = opB);
	currPos := codelen;
	codelen := pc;
	B(b*CondMask, address);
	codelen := currPos
END FixJump;

PROCEDURE FixCall*(pc: LONGINT; address: LONGINT): LONGINT;
VAR b: SET; currPos: LONGINT;
BEGIN
	b := GetInstruction(pc);
	ASSERT(b * opBL = opBL);
	currPos := codelen;
	codelen := pc;
	BL(b*CondMask, address);
	codelen := currPos;
	RETURN SYSTEM.VAL(LONGINT, b*Mask24)
END FixCall;

PROCEDURE FixCaseTable*(pc: LONGINT; address: LONGINT);
VAR fixup, currPos: LONGINT;
BEGIN
	ASSERT((address >= 0) & (address < 10000H), ErrCaseOffsetTooBig);
	fixup := SYSTEM.VAL(LONGINT, GetInstruction(pc) * { 16..31 });
	currPos := codelen;
	codelen := pc;
	DCD(fixup + address);
	codelen := currPos
END FixCaseTable;


(**--------------------------- Miscellaneous -------------------------------*)

PROCEDURE Init*(codeFN: ARRAY OF CHAR);
BEGIN
	f := Files.New(codeFN);
	Files.Register(f);
	f.Set(r, 0);
	start := 0;
	IF (code = NIL) THEN NEW(code, MaxCodeLength) END;
	codelen := 0; codeTooLong := FALSE;
	(*Trace IF Trace THEN NEW(t); Texts.Open(t, ""); PCARMDecoder.Init END *)
END Init;

PROCEDURE Code(opcode: SET);
TYPE Bytes= ARRAY 4 OF CHAR;
VAR b: Bytes; i: INTEGER;
BEGIN
	ASSERT(codelen MOD 4 = 0); (* in case PutChar did not write 4x characters *)
	(*Trace IF Trace & dcd THEN
		dcd := FALSE;
		NEW(d); d.pc := codelen;
		IF (dcdLast = NIL) THEN dcdList := d; dcdLast := d
		ELSE dcdLast.next := d; dcdLast := d
		END
	END; *)
	IF (codelen <= MaxCodeLength-4) THEN
		b := SYSTEM.VAL(Bytes, opcode);
		IF PCM.bigEndian THEN PCM.SwapBytes(b, 0, 4) END;
		FOR i := 0 TO 3 DO
			code[codelen] := b[i]; INC(codelen) (* little endian *)
		END;
		CheckCallback
	ELSE
		IF ~codeTooLong THEN	(* report only once *)
			codeTooLong := TRUE;
			PCM.Error(244, sourcepos, "Code too long.")
		END
	END
END Code;

PROCEDURE PutChar*(c: CHAR);
BEGIN
	code[codelen] := c; INC(codelen)
END PutChar;

PROCEDURE Close*;
VAR b: POINTER TO ARRAY OF CHAR;
BEGIN
	IF (codelen > MaxCodeLength) THEN (* code too long *)
		PCM.Error(244, Diagnostics.Invalid, "Code too long.");
	ELSIF (codelen-start > 0) THEN
		NEW(b, codelen-start);
		SYSTEM.MOVE(ADDRESSOF(code[start]), ADDRESSOF(b[0]), codelen-start);
		f.WriteBytes(r, b^, 0, codelen-start);
		Files.Register(f);
	ELSIF (codelen - start < 0) THEN HALT(MAX(INTEGER)) (* show stack*)
	END;
	f := NIL;
END Close;

PROCEDURE BoP*(name: ARRAY OF CHAR);
(* VAR dcd: DCDList; i: LONGINT; b: ARRAY InstructionSize OF CHAR;
BEGIN
	Trace IF Trace THEN
		IF (start # codelen) THEN
			dcd := dcdList;
			WHILE (start < codelen) DO
				FOR i := 0 TO InstructionSize-1 DO b[i] := code[start+i] END;
				PCARMDecoder.Decode(start, SYSTEM.VAL(LONGINT, b), (dcd # NIL) & (dcd.pc = start));
				IF (dcd # NIL) & (dcd.pc = start) THEN dcd := dcd.next END;
				INC(start, InstructionSize)
			END;
			ASSERT(start = codelen);
			dcdList := NIL; dcdLast := NIL
		END;

		IF (name = "") THEN COPY("Module Body", name) END;
		Texts.WriteLn(PCARMDecoder.W);
		Texts.WriteString(PCARMDecoder.W, name); Texts.WriteLn(PCARMDecoder.W);
		Texts.Append(t, PCARMDecoder.W.buf)
	END; *)
END BoP;

PROCEDURE EoP*;
END EoP;

PROCEDURE Dump*;
(* VAR dcd: DCDList; i: LONGINT; b: ARRAY InstructionSize OF CHAR;
BEGIN
	Trace IF Trace THEN
		IF (start # codelen) THEN
			dcd := dcdList;
			WHILE (start < codelen) DO
				FOR i := 0 TO InstructionSize-1 DO b[i] := code[start+i] END;
				PCARMDecoder.Decode(start, SYSTEM.VAL(LONGINT, b), (dcd # NIL) & (dcd.pc = start));
				IF (dcd # NIL) & (dcd.pc = start) THEN dcd := dcd.next END;
				INC(start, InstructionSize)
			END;
			ASSERT(start = codelen);
			dcdList := NIL; dcdLast := NIL;
			Texts.WriteLn(PCARMDecoder.W);
			Texts.WriteString(PCARMDecoder.W, "TRAP"); Texts.WriteLn(PCARMDecoder.W);
			Texts.Append(t, PCARMDecoder.W.buf)
		END;
		Oberon.OpenText("ARM Code", t, 600, 400)
	END *)
END Dump;

BEGIN
	AddrMode[0] := - {};
	AddrMode[1] := - {};
	AddrMode[2] := - {};
	AddrMode[3] := { 24, 23 };
	AddrMode[4] := - {};
	SetConstantPoolBarrier(-1)
END PCOARM.
