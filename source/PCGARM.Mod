(* Paco, Copyright 2000, Patrik Reali, ETH Zurich *)

MODULE PCGARM;	(** be  **)
(**
	Code Emission for StrongARM Processors
*)

IMPORT
	SYSTEM, PCLIR, PCBT, PCM, PCO := PCOARM, RA := PCARMRegisters, PCARMCP, PCAARM, KernelLog;

CONST
	Trace = FALSE;
	TTrace = FALSE;

	INTERNALERROR = 100;
	ErrImplementationRestriction = 101;
	ErrInlineNotAligned = 102;

	RegularIntSize = PCLIR.IntSize -  {PCLIR.Int64};

	(* frequently used constants from PCOARM *)
	AL = PCO.AL;	(* execute condition: always *)
	NE = PCO.NE;	(* execute condition: never *)
	PC = PCO.PC;	(* some special registers *)
	LR = PCO.LR;
	SP = PCO.SP;
	FP = PCO.FP;
	R0 = PCO.R0; R1 = PCO.R1; R2 = PCO.R2; R3 = PCO.R3; R4 = PCO.R4; R5 = PCO.R5; R6 = PCO.R6;
	R7 = PCO.R7; R8 = PCO.R8; R9 = PCO.R9; R10 = PCO.R10; R11 = PCO.R11;

	(* Return registers *)
	RReturn = R0;
	RReturn2 = R1;

	(* PCLIR register sizes that use 2 registers *)
	TwoRegisters = { PCLIR.Int64, PCLIR.Float64 };

	(* Flags in Info.flags *)
	FDst = 0; FSrc1 = 1; FSrc2 = 2; FSrc3 = 3; FVal = 4; FAdr = 5;	(* Fields used in Instruction *)

	(* Extended Opcodes (must not conflict with the opcodes defined in PCLIR !) *)
	none = -1;
	rsub = -2;
	fastenter = -3;
	fastexit = -4;
	nopaf = -5;
	floatCC = -6;

TYPE
	XOpcode = SHORTINT;	(* extended opcode type *)
	XRegister = RECORD
		Low, High: LONGINT;	(* low & high register of value *)
	END;

	Info = OBJECT(PCLIR.InstructionAttribute)
		VAR
			xop: XOpcode; (* extended opcode *)
			flags: SET;
			dst: XRegister; (* physical register(s) holding result.
											Exceptions:
												case: dst.Low contains offset of start of jmpTable
												loadreg: dst.Low = pc of savereg that belongs to this loadreg
									*)
			pos: LONGINT; (* position in code, -1 if unkown *)
			fixup: Info; (* for fixup-lists. *)
			target: BOOLEAN; (* valid for PCLIR.label with val = 0: TRUE if label is a target of a jump *)

		PROCEDURE &Init*;
		BEGIN xop := none; flags:= {}; dst.Low := -1; dst.High := -1; pos := -1; fixup := NIL; target := FALSE
		END Init;
	END Info;

VAR HexTab: ARRAY 16 OF CHAR;
	codeName: ARRAY 32 OF CHAR;
	regs: RA.ARMRegisters;
	pool: PCARMCP.ConstantPool;
	lastLabelPos: LONGINT;

	(* indices of DIV/MOD, Int64 & floating point syscalls in PCLIR.CG.SysCallMap *)
	DivIndex, ModIndex: LONGINT;
	Int64LSH, Int64ASH: LONGINT;
	FAdd, FSub, FMul, FDiv, FNeg, FAbs, FEntier, FIntToReal, FRealToInt, FRealToReal,
	FEq, FLe, FLt, FNe, FGe, FGt, FLongOffset: LONGINT;

	bimboTrace: BOOLEAN;

(* ----------- Helper Functions -----------------*)
PROCEDURE InitHexTab;
VAR i: SHORTINT;
BEGIN
	FOR i := 0 TO 9 DO HexTab[i] := CHR(ORD("0") + i) END;
	FOR i := 0 TO 5 DO HexTab[i+10] := CHR(ORD("A") + i) END
END InitHexTab;

PROCEDURE Write(s: ARRAY OF CHAR);
BEGIN KernelLog.String(s)
END Write;

PROCEDURE WriteLn(s: ARRAY OF CHAR);
BEGIN KernelLog.String(s); KernelLog.Ln
END WriteLn;

PROCEDURE Ln;
BEGIN KernelLog.Ln;
END Ln;

PROCEDURE Int(i: LONGINT);
BEGIN KernelLog.Int(i, 0)
END Int;

PROCEDURE Hex(value, len: LONGINT);
VAR hex:POINTER TO ARRAY OF CHAR; i: LONGINT;
BEGIN
	NEW(hex,len+2);
	FOR i := 1 TO len DO
		hex[len-i] := HexTab[value MOD 16];
		value := value DIV 16
	END;
	hex[len] := "h"; hex[len+1] := 0X;
	Write(hex^)
END Hex;

PROCEDURE Set(s: SET);
VAR i: LONGINT;
BEGIN
	FOR i := 31 TO 0 BY -1 DO
		IF (i IN s) THEN KernelLog.Char("1") ELSE KernelLog.Char("0") END
	END
END Set;

PROCEDURE Bool(b: BOOLEAN);
BEGIN IF b THEN Write("TRUE") ELSE Write("FALSE") END
END Bool;

PROCEDURE ToDo(pc: LONGINT; msg: ARRAY OF CHAR);
BEGIN KernelLog.Int(pc, 5); Write(" TODO: "); WriteLn(msg); HALT(INTERNALERROR);
END ToDo;

PROCEDURE Error(pc: LONGINT; msg: ARRAY OF CHAR);
BEGIN KernelLog.Int(pc, 5); Write(" ERROR: "); WriteLn(msg)
END Error;

(* IsShift - returns TRUE if op is a shift operator *)
PROCEDURE IsShift(op: PCLIR.Opcode): BOOLEAN;
BEGIN RETURN (op = PCLIR.bsh) OR (op = PCLIR.ash) OR (op = PCLIR.rot)
END IsShift;

(*
(* Commutative - returns TRUE if op is a commutative operator *)
PROCEDURE Commutative(op: PCLIR.Opcode): BOOLEAN;
BEGIN RETURN PCLIR.commutative IN PCLIR.InstructionSet[op].flags
END Commutative;
*)

(* Diadic - returns TRUE of op has two operands (only for data-processing instructions) *)
PROCEDURE Diadic(op: PCLIR.Opcode): BOOLEAN;
BEGIN
	RETURN ~((op = PCLIR.not) OR (op = PCLIR.neg) OR (op = PCLIR.abs))
END Diadic;

(* SpecialRegister - returns TRUE iff virtualReg is a special register (i.e., SP, FP, LR, PC or a hardware register) *)
PROCEDURE SpecialRegister(virtualReg: LONGINT): BOOLEAN;
BEGIN RETURN (virtualReg = PCLIR.SP) OR (virtualReg = PCLIR.FP) OR (virtualReg <= PCLIR.HwReg)
END SpecialRegister;

(* MapSpecialRegister - maps a PCLIR special register to a ARM hardware register *)
PROCEDURE MapSpecialRegister(virtualReg: LONGINT): LONGINT;
VAR reg: LONGINT;
BEGIN
	CASE virtualReg OF
	| PCLIR.SP: reg := SP
	| PCLIR.FP: reg := FP
	ELSE
		ASSERT((virtualReg <= PCLIR.HwReg), INTERNALERROR);
		reg :=  PCLIR.HwReg - virtualReg;
		ASSERT((0 <= reg) & (reg < 16), INTERNALERROR)
	END;
	RETURN reg
END MapSpecialRegister;

(* ResolveRegister -  returns a physical register number for a given virtual register *)
PROCEDURE ResolveRegister(code: PCLIR.Code; virtualReg: LONGINT): XRegister;
VAR p: PCLIR.Piece; res: XRegister;
	tiLow, tiHigh, tiSize: LONGINT;
BEGIN
	res.High := -1;
	IF (virtualReg = PCLIR.FP) THEN res.Low := FP
	ELSIF (virtualReg = PCLIR.SP) THEN res.Low := SP
	ELSIF (virtualReg >= 0) THEN
		code.GetPiece(virtualReg, p);
		res := p.instr[virtualReg].info(Info).dst;
		tiLow := res.Low; tiHigh := res.High; tiSize := p.instr[virtualReg].dstSize;
		ASSERT((res.Low # -1) & ((res.High # -1) OR ~(p.instr[virtualReg].dstSize IN TwoRegisters)), INTERNALERROR);
		RETURN res
	ELSE
		Error(-1,"ResolveRegister: invalid virtual register");
		HALT(INTERNALERROR)
	END;
	RETURN res
END ResolveRegister;

(* XResolveRegister -  returns a physical register number & a flag whether it is signed for a given virtual register *)
PROCEDURE XResolveRegister(code: PCLIR.Code; virtualReg: LONGINT; VAR physicalReg: XRegister; VAR signed: BOOLEAN);
VAR p: PCLIR.Piece;
BEGIN
	signed := FALSE;
	IF (virtualReg = PCLIR.FP) THEN physicalReg.Low := FP
	ELSIF (virtualReg = PCLIR.SP) THEN physicalReg.Low := SP
	ELSIF (virtualReg >= 0) THEN
		code.GetPiece(virtualReg, p);
		physicalReg := p.instr[virtualReg].info(Info).dst;
		signed := p.instr[virtualReg].dstSigned;
		ASSERT(physicalReg.Low # -1, INTERNALERROR)
	ELSE
		Error(-1, "ResolveRegister: invalid virtual register");
		HALT(INTERNALERROR)
	END
END XResolveRegister;

(* FindDefinition - returns the instruction that defined the virtual register *)
(* can also be used to get the instruction at pc 'virtualReg' *)
PROCEDURE FindDefinition(code: PCLIR.Code; virtualReg: LONGINT): PCLIR.Instruction;
VAR p: PCLIR.Piece;
BEGIN
	IF (virtualReg >= 0) THEN
		code.GetPiece(virtualReg, p);
		RETURN p.instr[virtualReg]
	ELSE
		Error(-1, "FindDefinition: invalid virtual register");
		HALT(INTERNALERROR)
	END
END FindDefinition;

(* IsLoadStoreSpecial - returns TRUE if LDRH/STRH must be used instead of LDR/STR *)
PROCEDURE IsLoadStoreSpecial(op: PCLIR.Opcode; instr: PCLIR.Instruction): BOOLEAN;
BEGIN RETURN (instr.dstSize = PCLIR.Int16) OR ((instr.dstSize = PCLIR.Int8) & instr.dstSigned & (op = PCLIR.load))
END IsLoadStoreSpecial;

(* LoadConstant - loads 'value' into a register and returns the register. If 'register' # -1, 'register' is used.
	Otherwise, a free register is allocated
 *)
PROCEDURE LoadConstant(pc, register, value, count: LONGINT): LONGINT;
VAR addrMode, address, imm: SET; valid: BOOLEAN; offset: LONGINT;
BEGIN
	IF (register = -1) THEN register := regs.AllocReg(RA.NewIntConst(value), valid, count)
	ELSE regs.SetRegisterContent(register, RA.NewIntConst(value))
	END;

	IF ~valid THEN
		IF (value # 0) THEN
			IF PCO.MakeA1Immediate(value, imm) THEN
				PCO.MOV(AL, PCO.A1Imm, register, imm, {})
			ELSE
				offset := pool.AddConstant(pc, value);
				addrMode := PCO.A2WImmOffset; address := PCO.MakeA2Immediate(addrMode, offset);
				PCO.LDR(AL, addrMode, register, PC, address)
			END
		ELSE
			(*
				rD <- 0
			*)
			PCO.MOV(AL, PCO.A1Imm, register, PCO.A1Immediate0, {})
		END
	END;
	RETURN register
END LoadConstant;

(* InstructionType - returns the type (= size of destination/source register) of an instruction *)
PROCEDURE InstructionType(code: PCLIR.Code; VAR i: PCLIR.Instruction): LONGINT;
VAR d: PCLIR.Instruction;
BEGIN
	IF (FDst IN i.info(Info).flags) THEN RETURN i.dstSize
	ELSIF (FSrc1 IN i.info(Info).flags) THEN
		d := FindDefinition(code, i.src1);
		RETURN d.dstSize
	ELSE HALT(INTERNALERROR)
	END
END InstructionType;

(* Size - returns the number of hardware registers needed to store this data type *)
PROCEDURE Size(type: LONGINT): LONGINT;
BEGIN
	CASE type OF
	|PCLIR.Int8, PCLIR.Int16, PCLIR.Int32, PCLIR.Float32: RETURN 1
	|PCLIR.Int64, PCLIR.Float64: RETURN 2
	ELSE HALT(INTERNALERROR)
	END
END Size;

(* LoadAddress - loads an address into a register 'rAdr' *)
PROCEDURE LoadAddress(rAdr: LONGINT; adr: PCM.Attribute);
VAR offset: LONGINT; addrMode, address: SET;
BEGIN
	IF bimboTrace THEN
		Hex(PCO.GetCodePos(), 8); WriteLn(" LoadAddress");
		IF (PCO.GetCodePos() = 90H) THEN HALT(MAX(INTEGER)) END;
	END;

	IF Trace THEN KernelLog.Enter END;
	IF (adr IS PCBT.GlobalVariable) THEN
		WITH adr: PCBT.GlobalVariable DO
			(* 08.05.02: interface changed again
			IF (adr.next = NIL) THEN (* not in fixup list yet *)
				adr.next := PCBT.context.varEntry; PCBT.context.varEntry := adr
			END;
			*)
			IF bimboTrace OR Trace THEN
				KernelLog.String("GlobalVariable: offset: "); KernelLog.Int(adr.offset, 0);
				KernelLog.String("; module: "); KernelLog.Int(adr.owner.nr, 0);
				KernelLog.String("; entry no: "); KernelLog.Int(adr.entryNo, 0);
				KernelLog.Ln
			END;
			offset := pool.AddAddress(PCO.GetCodePos(), adr);
			addrMode := PCO.A2WImmOffset; address := PCO.MakeA2Immediate(addrMode, offset);
			PCO.LDR(AL, addrMode, rAdr, PC, address)
		END
	ELSIF (adr IS PCBT.Procedure) THEN
		WITH adr: PCBT.Procedure DO
			offset := pool.AddAddress(PCO.GetCodePos(), adr);
			addrMode := PCO.A2WImmOffset; address := PCO.MakeA2Immediate(addrMode, offset);
			PCO.LDR(AL, addrMode, rAdr, PC, address);
			IF Trace THEN
				KernelLog.String("Procedure: imported: ");
				IF (adr.owner # PCBT.context) THEN KernelLog.String("yes") ELSE KernelLog.String("no") END;
				KernelLog.String("; code offset: "); KernelLog.Hex(adr.codeoffset, 8);
				KernelLog.String("; entryNr: "); KernelLog.Int(adr.entryNr, 0);
				KernelLog.String("; fixlist: "); KernelLog.Int(adr.fixlist, 0)
			END
		END
	ELSE
		IF Trace THEN KernelLog.String("Load absolute: unknown type !") END;
		HALT(ErrImplementationRestriction)
	END;
	IF Trace THEN KernelLog.Exit END
END LoadAddress;

(* SystemCall - generate a syscall with number 'nr' *)
PROCEDURE SystemCall(nr: LONGINT);
VAR addrMode, address: SET;
BEGIN
	(*
		LR <- PC + 4
		PC <- MEM[PC-4]
		DATA syscall-address
		...syscall returns here
	*)
	PCO.ADD(AL, PCO.A1Imm, LR, PC, PCO.A1Immediate4, {});
	addrMode := PCO.A2Word + PCO.Offset; address := PCO.MakeA2Immediate(addrMode, -4);
	PCO.LDR(AL, addrMode, PC, PC, address);
	(*
	PCO.DCD(PCBT.context.syscalls[nr]*10000H);
	PCBT.context.syscalls[nr] := (PCO.GetCodePos() - PCO.InstructionSize) DIV 4;
	*)
	(* 08.05.02: interface changed again
	PCBT.AddFixup(PCBT.context.syscalls[nr], PCO.GetCodePos() DIV 4);
	PCO.DCD(0);
	*)
	PCBT.context.UseSyscall(nr, PCO.GetCodePos() DIV 4);
	PCO.DCD(0);
	regs.InvalidateAll
END SystemCall;

(* ----------- Code Generation -----------------*)
(* Init - code generator initialization. Called by PC *)
PROCEDURE Init(): BOOLEAN;
BEGIN
	PCO.Init("ARM.Code");
	NEW(pool);
	RETURN TRUE
END Init;

PROCEDURE Done(VAR res: LONGINT);
BEGIN
	PCO.Close;
	res := 0
END Done;

(* Enter - generate PAF and clear local variables *)
PROCEDURE Enter(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; locsize, i, rS, rC, fixup: LONGINT; adr: PCBT.Procedure;
	addrMode, address, flags: SET;
BEGIN
	PCO.BoP(code.name); (* tracing only: formats output *)
	COPY(code.name, codeName); (* debugging: procedure name is visible *)
	(*bimboTrace := codeName = "MapMemory";
	RA.bimboTrace := codeName = "MapMemory";
	*)
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF PCM.Optimize IN PCM.codeOptions THEN
		flags := {RA.Constants, RA.MemoryStack} (* MemoryAbsolute does not work !!! *)
	ELSE
		flags := {}
	END;
	NEW(regs, 12, flags);
	IF (instr.adr # NIL)  & (instr.adr IS PCBT.Procedure) THEN
		adr := instr.adr(PCBT.Procedure);
		(* 08.05.02: interface changed again
		PCBT.context.AddEntry(adr, info.pos DIV 4); (*adr.codeaddr := info.pos DIV 4;*)
		*)
		PCBT.context.AddOwnProc(adr, info.pos DIV 4);
		fixup := adr.fixlist;
		IF Trace THEN KernelLog.Enter; KernelLog.String(code.name); KernelLog.String(": Procedure Call Fixup:"); KernelLog.Ln END;
		WHILE (fixup # PCBT.FixupSentinel) DO
			IF Trace THEN KernelLog.String("  fixing @ "); KernelLog.Hex(fixup*4, 0); KernelLog.Ln END;
			fixup := PCO.FixCall(fixup*4, (info.pos - fixup*4 - 8) DIV 4)
		END;
		IF Trace THEN KernelLog.Exit END;
		locsize := adr.locsize
	ELSE
		locsize := 0
	END;
	IF (info.xop # fastenter) & (info.xop # nopaf) THEN
		IF (instr.val = PCBT.OberonCC) THEN
			ASSERT(locsize MOD 4 = 0, INTERNALERROR);
			(*
				SP <- SP-4,	 MEM[SP] <- FP,	SP <- SP-4,	 MEM[SP] <- LR
				FP <- SP
			*)
			PCO.STM(AL, PCO.A4DB, SP, { FP, LR }, PCO.A4W); (* save FP and LR *)

			PCO.MOV(AL, PCO.A1Reg, FP, PCO.MakeA1Register(SP), {});	(* set new FP *)
			IF (locsize > 0) THEN
				(*
					rS <- 0
				*)
				rS := LoadConstant(PCO.GetCodePos(), -1, 0, 1);
				addrMode := PCO.A2WImmPreIdxd;
				address := PCO.MakeA2Immediate(addrMode, -4);
				IF (locsize <= 16 ) THEN
					(*
						SP <- SP-4,	MEM[SP] <- rS
					*)
					FOR i := 0 TO locsize DIV 4 - 1 DO	(* set up stack *)
						PCO.STR(AL, addrMode, SP, rS, address)
					END
				ELSE
					(*
						rC <- locsize DIV 4
						SP <- SP-4,	MEM[SP] <- rS
						rC <- rC-1
						BNZ -4
					*)
					rC := LoadConstant(PCO.GetCodePos(), -1, locsize DIV 4, 1);
					PCO.STR(AL, addrMode, SP, rS, address);
					PCO.SUB(AL, PCO.A1Imm, rC, rC, PCO.A1Immediate1, PCO.Sflag);
					PCO.B(PCO.NE, -4);
					regs.SetRegisterContent(rC, RA.NewIntConst(0)); regs.FreeReg(rC)	(* we know that rC = 0 now *)
				END;
				regs.FreeReg(rS)
			END
		ELSIF (instr.val = PCBT.OberonPassivateCC) THEN
			(*
				{ top of the stack: static link }
				SP <- SP-4,	 MEM[SP] <- FP,	SP <- SP-4,	 MEM[SP] <- LR
				FP <- MEM[SP+8] ( = static link)
			*)
			PCO.STM(AL, PCO.A4DB, SP, { FP, LR }, PCO.A4W); (* save FP and LR *)
			addrMode := PCO.A2WImmOffset; address := PCO.MakeA2Immediate(addrMode, 8);
			PCO.LDR(AL, addrMode, FP, SP, address)
		ELSE
			HALT(INTERNALERROR)
		END
	END
END Enter;

(* Exit - destroy PAF and return to caller *)
PROCEDURE Exit(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; rT: LONGINT; imm: SET;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF (info.xop = nopaf) THEN
		(* nothing *)
	ELSIF (info.xop = fastexit) THEN
		(*
			if paramsize > 0:
				SP <- SP + paramsize
			PC <- LR
		*)
		IF (instr.src1 > 0) THEN
			IF PCO.MakeA1Immediate(instr.src1, imm) THEN
				PCO.ADD(AL, PCO.A1Imm, SP, SP, imm, {})
			ELSE
				rT := R3; regs.AllocSpecialReg(rT, NIL, 1);
				rT := LoadConstant(PCO.GetCodePos(), rT, instr.src1, 1);
				PCO.ADD(AL, PCO.A1Reg, SP, SP, PCO.MakeA1Register(rT), {});
				regs.FreeReg(rT)
			END
		END;
		PCO.MOV(AL, PCO.A1Reg, PC, PCO.MakeA1Register(LR), {})
	ELSIF (instr.val = PCBT.OberonCC) THEN
		(*
			SP <- FP
			if paramsize > 0:
				FP <- MEM[SP],	SP <- SP + 4,	LR <- MEM[SP],	SP <- SP + 4
				SP <- SP + paramsize
				MOV PC, LR
			else
				FP <- MEM[SP],	SP <- SP + 4,	PC <- MEM[SP],	SP <- SP + 4
		*)
		PCO.MOV(AL, PCO.A1Reg, SP, PCO.MakeA1Register(FP), {});	(* restore SP *)
		IF (instr.src1 > 0) THEN (* instr.src1 = parsize *)
			PCO.LDM(AL, PCO.A4IA, SP, { FP, LR }, PCO.A4W); (* restore FP and LR *)
			IF PCO.MakeA1Immediate(instr.src1, imm) THEN
				PCO.ADD(AL, PCO.A1Imm, SP, SP, imm, {})
			ELSE
				rT := R3; regs.AllocSpecialReg(rT, NIL, 1);
				rT := LoadConstant(PCO.GetCodePos(), rT, instr.src1, 1);
				PCO.ADD(AL, PCO.A1Reg, SP, SP, PCO.MakeA1Register(rT), {});
				regs.FreeReg(rT)
			END;
			PCO.MOV(AL, PCO.A1Reg, PC, PCO.MakeA1Register(LR), {})
		ELSE
			PCO.LDM(AL, PCO.A4IA, SP, { FP, PC }, PCO.A4W) (* restore FP and LR into PC -> return *)
		END
	ELSIF (instr.val = PCBT.OberonPassivateCC) THEN
		(*
			FP <- MEM[SP],	SP <- SP + 4,	LR <- MEM[SP],	SP <- SP + 4
			SP <- SP + 4
			PC <- LR
		*)
		PCO.LDM(AL, PCO.A4IA, SP, { FP, PC }, PCO.A4W); (* restore FP and LR into PC -> return *)
		PCO.ADD(AL, PCO.A1Imm, SP, SP, PCO.A1Immediate4, {});
		PCO.MOV(AL, PCO.A1Reg, PC, PCO.MakeA1Register(LR), {})
	ELSE
		HALT(INTERNALERROR)
	END;
	regs.FreeAll;
	pool.Flush(PCO.GetCodePos());
	PCO.EoP (* debugging only: formats output *)
END Exit;

PROCEDURE Compare(code: PCLIR.Code; VAR instr: PCLIR.Instruction);
VAR type: LONGINT; rA, rB: XRegister; rT, rBx: LONGINT; valid, dummy: BOOLEAN; imm: SET;
BEGIN
	type := InstructionType(code, instr);

	IF (type IN PCLIR.IntSize) THEN
		rA := ResolveRegister(code, instr.src1);
		rB := ResolveRegister(code, instr.src2);

		IF (instr.op = PCLIR.setf) OR (instr.op =  PCLIR.setnf) OR (instr.op IN {PCLIR.jf, PCLIR.jnf}) THEN
			rT := regs.AllocReg(RA.NewIntConst(1), valid, 1);
			IF ~valid THEN PCO.MOV(AL, PCO.A1Imm, rT, PCO.A1Immediate1, {}) END;

			IF (type = PCLIR.Int64) THEN (* HUGEINT *)
				rBx := regs.AllocReg(NIL, valid, 1);
				dummy := PCO.MakeA1Immediate(32, imm); ASSERT(dummy);
				(*
					rB.Low <= 32 ?
					yes: goto (1)
					no:
						cc <- rA.Low & (1 << rB.Low)
						goto end
					(1):
						rBx <- rB.Low - 32
						cc <- rA.High & (1 << rBx)
					end:
				*)
				PCO.CMP(AL, PCO.A1Imm, rB.Low, imm);
				PCO.B(PCO.GE, 1);
				PCO.TST(PCO.LT, PCO.A1Reg, rA.Low, PCO.MakeA1RegSHIFTReg(rT, rB.Low, PCO.Lsl));
				PCO.B(AL, 1);
				(* (1) *)
				PCO.SUB(PCO.GE, PCO.A1Imm, rBx, rB.Low, imm, {});
				PCO.TST(PCO.GE, PCO.A1Reg, rA.High, PCO.MakeA1RegSHIFTReg(rT, rBx, PCO.Lsl));
				(* end *)
				regs.FreeReg(rBx)
			ELSE	(* # HUGEINT *)
				(*
					cc <- rA.Low & (1 << rB.Low)
				*)
				PCO.TST(AL, PCO.A1Reg, rA.Low, PCO.MakeA1RegSHIFTReg(rT, rB.Low, PCO.Lsl))
			END;
			regs.FreeReg(rT)
		ELSE
			IF (type = PCLIR.Int64) THEN (* HUGEINT *)
				(*
					cc <- rA.High = rB.High
					if equal:
						cc <- rA.Low = rB.Low
				*)
				PCO.CMP(AL, PCO.A1Reg, rA.High, PCO.MakeA1Register(rB.High));
				PCO.CMP(PCO.EQ, PCO.A1Reg, rA.Low, PCO.MakeA1Register(rB.Low))
			ELSE
				(*
					cc <- rA.Low = rB.Low
				*)
				PCO.CMP(AL, PCO.A1Reg, rA.Low, PCO.MakeA1Register(rB.Low))
			END
		END;
		regs.FreeReg(rA.Low); regs.FreeReg(rB.Low)
	ELSE (* type = PCLIR.FloatSize *)
		FloatingPointComparison(code, instr);
		instr.op := PCLIR.je
	END
END Compare;

PROCEDURE Trap(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; cond: SET;
BEGIN
	info := instr.info(Info);

	IF (instr.op # PCLIR.trap) THEN Compare(code, instr) END;

	info.pos := PCO.GetCodePos();
	CASE instr.op OF
	| PCLIR.trap: cond := AL
	| PCLIR.tae: cond := PCO.HI
	| PCLIR.tne: cond := NE
	END;
 	PCO.SWI(cond, instr.val);
 	IF (instr.op = PCLIR.trap) & (instr.val # MAX(INTEGER)) THEN pool.Flush(PCO.GetCodePos()) END
END Trap;

PROCEDURE SaveRegisters(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rs: SET;
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		SP <- SP - (nof register to save)*4, MEM[SP...] <- used registers
	*)
	rs := regs.GetUsedRegisterSet();
	instr.info(Info).flags := rs;
	IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END
END SaveRegisters;

PROCEDURE LoadRegisters(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rs: SET; saveregs: PCLIR.Instruction;
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		SP <- SP + (nof registers saved)*4, registers <- MEM[SP...]
	*)
	saveregs := FindDefinition(code, instr.info(Info).dst.Low);
	rs := saveregs.info(Info).flags;
	IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W); regs.InvalidateAll END
END LoadRegisters;

PROCEDURE Return(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rReturn, rS: XRegister; info: Info; srcDef: PCLIR.Instruction; mode, soLow, soHigh: SET;
BEGIN (* TODO: check if HUGEINTs are returned correctly *)
	info := instr.info(Info);
	info.pos := PCO.GetCodePos();
	(*
		RReturn <- rS.Low
		[RReturn2 <- rS.High]
	*)
	IF (FSrc1 IN info.flags) THEN
		srcDef := FindDefinition(code, instr.src1);
		rS := srcDef.info(Info).dst;
		mode := PCO.A1Reg;
		soLow := PCO.MakeA1Register(rS.Low);
		IF (srcDef.dstSize IN TwoRegisters) THEN
			ASSERT(instr.op = PCLIR.ret, INTERNALERROR); (* we mustn't have a ret2 here *)
			soHigh := PCO.MakeA1Register(rS.High)
		END
	ELSIF (FVal IN info.flags) & PCO.MakeA1Immediate(instr.val, soLow) THEN
		mode := PCO.A1Imm
	ELSE Error(pc, "Can't generate immediate value")
	END;
	CASE instr.op OF
	| PCLIR.ret: rReturn.Low := RReturn; IF (srcDef.dstSize IN TwoRegisters) THEN rReturn.High := RReturn2 END
	| PCLIR.ret2: rReturn.Low := RReturn2
	END;
	IF (FSrc1 IN info.flags) THEN (* free here because rS might be equal to rReturn *)
		regs.FreeReg(rS.Low);
		IF (srcDef.dstSize IN TwoRegisters) THEN regs.FreeReg(rS.High) END
	END;
	regs.AllocSpecialReg(rReturn.Low, NIL, 1);
	IF (srcDef.dstSize IN TwoRegisters) THEN regs.AllocSpecialReg(rReturn.High, NIL, 1) END;
	IF (FVal IN info.flags) OR (rS.Low # rReturn.Low) THEN (* maybe the result is already in the correct register *)
		PCO.MOV(AL, mode, rReturn.Low, soLow, {});
		regs.FreeReg(rReturn.Low) (* -> exit immediately after this instruction or the content of the result register will be lost *)
	END;
	IF (srcDef.dstSize IN TwoRegisters) & (rS.High # rReturn.High) THEN (* maybe the high 4 bytes are in the correct register *)
		PCO.MOV(AL, mode, rReturn.High, soHigh, {});
		regs.FreeReg(rReturn.High)
	END;
END Return;

PROCEDURE Result(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; next: PCLIR.Instruction; rD, rResult: XRegister;
BEGIN (* TODO: check if HUGEINTs are returned correctly *)
	(* TODO check how Floats are 'resulted'. Maybe we should also allocate RReturn2 in the first case below, if instr.dstSize = PCLIR.Float64 *)
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	CASE instr.op OF
	| PCLIR.result: rResult.Low := RReturn; rResult.High := RReturn2;
		next := FindDefinition(code, pc+1);
		IF (next.op = PCLIR.result2) THEN	(* this prevents the register allocator to allocate RReturn2 as rD *)
			regs.AllocSpecialReg(RReturn2, NIL, 1)
		END
	| PCLIR.result2: rResult.Low := RReturn2;
		regs.FreeReg(RReturn2)	(* free the previously allocated register (see above) *)
	END;
	IF (info.dst.Low = -1) THEN
		(* try to avoid the mov *)
		IF regs.IsRegisterFree(rResult.Low) THEN regs.AllocSpecialReg(rResult.Low, NIL, instr.dstCount); rD.Low := rResult.Low
		ELSE rD.Low := regs.AllocDestReg(instr.dstCount)
		END;
		IF (instr.dstSize IN {PCLIR.Int64, PCLIR.Float64}) THEN
			IF (info.dst.High = -1) THEN
				IF regs.IsRegisterFree(rResult.High) THEN regs.AllocSpecialReg(rResult.High, NIL, instr.dstCount); rD.High := rResult.High
				ELSE rD.High := regs.AllocDestReg(instr.dstCount)
				END
			ELSE rD.High := info.dst.High
			END
		ELSE rD.High := -1
		END;
		info.dst := rD
	ELSE rD.Low := info.dst.Low
	END;
	(*
		[rD <- rResult] (if necessary)
	*)
	IF (rD.Low # rResult.Low) THEN
		PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(rResult.Low), {})
	END;
	IF (instr.dstSize = PCLIR.Float64) & (rD.High # rResult.High) THEN
		PCO.MOV(AL, PCO.A1Reg, rD.High, PCO.MakeA1Register(rResult.High), {})
	END
END Result;

PROCEDURE Pop(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; addrMode, address: SET; rD: XRegister;
BEGIN
	(*
		rD.Low <- MEM[SP], SP <- SP + 4
		[rD.High <- MEM[SP], SP <- SP + 4]
	*)
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF (info.dst.Low = -1) THEN rD.Low := regs.AllocDestReg(instr.dstCount); info.dst.Low := rD.Low
	ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
	END;
	IF (instr.dstSize IN TwoRegisters) THEN
		IF (info.dst.High = -1) THEN rD.High := regs.AllocDestReg(instr.dstCount); info.dst.High := rD.High
		ELSE rD.High := info.dst.High
		END
	END;

	addrMode := PCO.A2WImmPostIdxd; address := PCO.MakeA2Immediate(addrMode, 4);
	PCO.LDR(AL, addrMode, rD.Low, SP, address);
	IF (instr.dstSize IN TwoRegisters) THEN
		PCO.LDR(AL, addrMode, rD.High, SP, address)
	END
END Pop;

PROCEDURE Push(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR addrMode, address: SET; rS: XRegister; size: PCLIR.Size;
BEGIN
	(*
		[SP <- SP - 4, MEM[SP] <- rS.High]
		SP <- SP - 4, MEM[SP] <- rS.Low
	*)
	instr.info(Info).pos := PCO.GetCodePos();
	rS := ResolveRegister(code, instr.src1);
	addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
	IF (rS.High # -1) THEN
		PCO.STR(AL, addrMode, SP, rS.High, address); regs.FreeReg(rS.High)
	END;

	IF PCM.bigEndian THEN
		(* dirty hack:
			the caller always stores 4 bytes, but the callee loads the bytes
			according to the size of the type. this works fine with little
			endian machines but fails with big endians. We have to shift
			the parameter value, so that it is located at the right offset
			onto the stack. a better solution would be to store just the
			exact number of bytes.
		*)
		size := PCLIR.SizeOf(code, instr.src1);
		IF (size = PCLIR.Int8) THEN (* SHL instr.src1 by 24 *)
			PCO.MOV(AL, addrMode, rS.Low,  PCO.MakeA1RegSHIFTImm(rS.Low, 24, PCO.Lsl), {});
		ELSIF (size = PCLIR.Int16) THEN (* SHL intr.src1 by 16 *)
			PCO.MOV(AL, addrMode, rS.Low,  PCO.MakeA1RegSHIFTImm(rS.Low, 16, PCO.Lsl), {});
		END;
	END;

	PCO.STR(AL, addrMode, SP, rS.Low, address); regs.FreeReg(rS.Low)
END Push;

PROCEDURE LoadStore(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; rD, tmp: XRegister; rBase, rOffset, offset, deltaOffset, size: LONGINT; addrMode, address: SET;
	signed, twoRegisters, valid, valid2: BOOLEAN; content, content2: RA.Content; instrDef: PCLIR.Instruction;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();

	IF (instr.op = PCLIR.load) THEN
		instrDef := instr;	(* 'instr' determines the type of load *)
		size := instr.dstSize;
		signed := instr.dstSigned
	ELSE (* instr.op = PCLIR.store *)
		IF SpecialRegister(instr.src2) THEN
			size := PCLIR.Int32;	(* store special (hardware) register = store 32bit unsigned *)
			signed := FALSE
		ELSE
			instrDef := FindDefinition(code, instr.src2); (* the source determines the type of store *)
			size := instrDef.dstSize;
			signed := instrDef.dstSigned
		END
	END;

	IF bimboTrace THEN
		Hex(info.pos, 8); Write("h; PC = "); Int(pc); WriteLn("   Load/Store");
		Write("  load: "); Bool(instr.op = PCLIR.load); Ln;
		Write("  size: "); Int(size); Ln;
		Write("  signed: "); Bool(signed); Ln;
	END;

	(* do we need two destination/source registers ? *)
	twoRegisters := size IN TwoRegisters;

	IF bimboTrace THEN
		Write("  2 registers: "); Bool(twoRegisters); Ln;
	END;

	(* generate content records *)
	IF (instr.src1 = PCLIR.Absolute) THEN
		IF bimboTrace THEN
			Write("  absolute addressing: instr.adr = "); Hex(SYSTEM.VAL(LONGINT, instr.adr), 8); Write("; instr.val = "); Int(instr.val); Ln;
		END;
		content := RA.NewMemAddress(instr.adr, 0);
		IF twoRegisters THEN content2 := RA.NewMemAddress(instr.adr, 4) END
	ELSE
		tmp := ResolveRegister(code, instr.src1);
		rBase := tmp.Low;
		IF bimboTrace THEN
			Write("  relative addressing: base register = "); Int(rBase); Write("; instr.val = "); Int(instr.val); Ln;
		END;
		content := RA.NewMemContent(pc, rBase, instr.val, size);
		IF twoRegisters THEN content2 := RA.NewMemContent(pc, rBase, instr.val+4, size) END
	END;

	(* prepare source/destination registers *)
	IF (instr.op = PCLIR.load) THEN (* load: prepare destination register(s) *)
		IF (info.dst.Low = -1) THEN rD.Low := regs.AllocReg(content, valid, instr.dstCount); info.dst.Low := rD.Low
		ELSE rD.Low := info.dst.Low
		END;
		IF twoRegisters THEN
			IF (info.dst.High = -1) THEN rD.High := regs.AllocReg(content2, valid2, instr.dstCount); info.dst.High := rD.High
			ELSE rD.High := info.dst.High
			END;
			deltaOffset := 4	(* 2nd value is at MEM[base + offset + deltaOffset] *)
		ELSE deltaOffset := 0; valid2 := TRUE
		END;
	ELSE (* instr.op = PCLIR.store *) (* store: prepare source register(s) *)
		IF SpecialRegister(instr.src2) THEN
			rD.Low := MapSpecialRegister(instr.src2);
			regs.Invalidate(content)
		ELSE
			rD.Low := instrDef.info(Info).dst.Low;	ASSERT(rD.Low # -1, INTERNALERROR);
			regs.AddRegisterContent(rD.Low, content);
			IF twoRegisters THEN
				rD.High := instrDef.info(Info).dst.High;	ASSERT(rD.High # -1, INTERNALERROR);
				regs.AddRegisterContent(rD.High, content2);
				deltaOffset := 4	(* 2nd value is at MEM[base + offset + deltaOffset] *)
			ELSE deltaOffset := 0
			END
		END
	END;

	(* load value only if necessary / store always *)
	IF ~(valid & valid2) OR (instr.op = PCLIR.store) THEN
		(* change base register if absolute addressing is used *)
		IF (instr.src1 = PCLIR.Absolute) THEN
			rBase := regs.AllocDestReg(1);
			LoadAddress(rBase, instr.adr);
			IF bimboTrace THEN
				Write("  absolute addressing: base register = "); Int(rBase); Ln;
				Write("                                    instr.val = "); Int(instr.val); Ln;
			END;
			(************************ HACK ********************************
				bei absolutem Load (& Store ?) muss der instr.val ignoriert werden. instr.adr ist vom Typ PCBT.GlobalVariable
				und der hat einen Offset adr.offset, welcher denselben Wert hat wie instr.val.
				Der ConstantPool schreibt adr.offset ins Objectfile, was dann nach Addition der StaticBase des Moduls die
				Adresse ergibt. Bei importierten globalen Variablen ist adr.offset = 0. Laut Patrik wird dann der instr.val verwendet,
				um zB auf Arrays zuzugreifen. Allerdings habe ich bis jetzt keine solche Situation kreieren koennen.
				Bis auf Weiteres wird deshalb der instr.val Offset ignoriert.
				(instr.val darf nicht auf 0 gesetzt werden, strange things happen if you do !)

				UPDATE: bei Delegates ist instr.val = adr.offset + 4 beim zweiten Wert. Neue Berechnung ab jetzt darum
					offset := instr.val - adr.offset
			*)
			offset := 0;
			(*IF (instr.val # instr.adr(PCBT.GlobalVariable).offset) THEN
				PCM.LogWStr("HINT in LoadStore: instr.val # adr.offset !!!"); PCM.LogWLn;
				PCM.LogWStr("   instr.val = "); PCM.LogWNum(instr.val); PCM.LogWLn;
				PCM.LogWStr("   adr.offset="); PCM.LogWNum(instr.adr(PCBT.GlobalVariable).offset); PCM.LogWLn;
			END;
			*)
			(*ASSERT(instr.val = instr.adr(PCBT.GlobalVariable).offset);*)
			offset := instr.val - instr.adr(PCBT.GlobalVariable).offset;
			(************************ HACK *******************************)
		ELSE offset := instr.val
		END;
		rOffset := -1;

		IF IsLoadStoreSpecial(instr.op, instrDef) THEN	(* values that use more than one register won't enter here *)
			IF bimboTrace THEN
				WriteLn("  load/store special");
			END;
			CASE size OF
			| PCLIR.Int16: addrMode := PCO.A3Halfword + PCO.Offset
			| PCLIR.Int8: addrMode := PCO.A3Byte + PCO.Offset; ASSERT(signed, INTERNALERROR)
			ELSE HALT(INTERNALERROR)
			END;
			(* the sign does not matter for store instructions *)
			IF (instr.op = PCLIR.load) & signed THEN addrMode := addrMode + PCO.A3Signed
			ELSE addrMode := addrMode + PCO.A3Unsigned
			END;

			(* use immediate offset addressing if possible *)
			IF (ABS(offset) < 100H) THEN	(* LDRH has an 8bit immediate *)
				IF bimboTrace THEN
					WriteLn("  using immediate offset");
				END;
				addrMode := addrMode + PCO.A3Imm;
				address := PCO.MakeA3Immediate(addrMode, offset)
			ELSE
				(* offset too big, use register offset *)
				IF bimboTrace THEN
					WriteLn("  using register offset");
				END;
				rOffset := LoadConstant(PCO.GetCodePos(), -1, ABS(offset), 1);
				addrMode := addrMode + PCO.A3Reg;
				IF (offset < 0) THEN addrMode := addrMode + PCO.IdxSub
				ELSE addrMode := addrMode + PCO.IdxAdd
				END;
				address := PCO.MakeA3Register(rOffset)
			END;

			(* load/store the value *)
			(*
				LDR(H|SB)/STRH	rD, [rBase, offset]
			*)
			IF (instr.op = PCLIR.load) THEN
				PCO.LDRH(AL, addrMode, rD.Low, rBase, address);
				regs.SetRegisterContent(rD.Low, content)
			ELSE PCO.STRH(AL, addrMode, rBase, rD.Low, address)
			END
			;IF bimboTrace THEN
				Write("  coded: addrMode = "); Set(addrMode); Write("; rBase = "); Int(rBase); Write("; rD.Low = "); Int(rD.Low);
				Write("; address = "); Set(address); Ln
			END;
		ELSE
			IF bimboTrace THEN
				WriteLn("  load/store normal");
			END;
			IF (size = PCLIR.Int8) THEN addrMode := PCO.A2Byte + PCO.Offset
			ELSE addrMode := PCO.A2Word + PCO.Offset (* longints, hugeints & floating point values *)
			END;

			(* use immediate offset addressing if possible. *)
			IF ((offset < 0) & (offset > -1000H)) OR ((offset >= 0) & (offset + deltaOffset < 1000H)) THEN (* 12 bit immediate *)
				IF bimboTrace THEN
					WriteLn("  using immediate offset");
				END;
				addrMode := addrMode + PCO.A2Imm;
				address := PCO.MakeA2Immediate(addrMode, offset)
			ELSE
				(* offset too big, use register offset *)
				IF bimboTrace THEN
					WriteLn("  using register offset");
				END;
				rOffset := LoadConstant(PCO.GetCodePos(), -1, ABS(offset), 1);
				addrMode := addrMode + PCO.A2Reg;
				IF (offset < 0) THEN addrMode := addrMode + PCO.IdxSub
				ELSE addrMode := addrMode + PCO.IdxAdd
				END;

				address := PCO.MakeA2Register(rOffset)
			END;

			(* load/store the value *)
			(*
				LDR(B)/STR(B)	rD, [rBase, offset]
			*)
			IF (instr.op = PCLIR.load) THEN
				PCO.LDR(AL, addrMode, rD.Low, rBase, address);
				regs.SetRegisterContent(rD.Low, content)
			ELSE PCO.STR(AL, addrMode, rBase, rD.Low, address)
			END;
			IF twoRegisters THEN (* load/store second word *)
				IF (rOffset = -1) THEN (* immediate offset *)
					address := PCO.MakeA2Immediate(addrMode, offset + 4)
				ELSE (* register offset *)
					PCO.ADD(AL, PCO.A1Imm, rOffset, rOffset, PCO.A1Immediate4, {}); (* add 4 to the offset register *)
					regs.SetRegisterContent(rOffset, RA.NewIntConst(ABS(offset)+4))
				END;
				IF (instr.op = PCLIR.load) THEN
					PCO.LDR(AL, addrMode, rD.High, rBase, address);
					regs.SetRegisterContent(rD.High, content2)
				ELSE PCO.STR(AL, addrMode, rBase, rD.High, address)
				END
			END
			;IF bimboTrace THEN
				Write("  coded: addrMode = "); Set(addrMode); Write("; rBase = "); Int(rBase); Write("; rD.Low = "); Int(rD.Low);
				Write("; address = "); Set(address); Ln
			END;
		END;

		(* free registers *)
		IF (rOffset # -1) THEN regs.FreeReg(rOffset) END;
		regs.FreeReg(rBase);
		IF (instr.op = PCLIR.store) & ~SpecialRegister(instr.src2) THEN
			regs.FreeReg(rD.Low);
			IF twoRegisters THEN regs.FreeReg(rD.High) END
		END
	END
END LoadStore;

(* LoadC - load constant into register *)
PROCEDURE LoadC(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; rD: LONGINT;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF (instr.adr # NIL) THEN
		IF (info.dst.Low = -1) THEN
			rD := regs.AllocDestReg(instr.dstCount); info.dst.Low := rD
		ELSE rD := info.dst.Low
		END;
		LoadAddress(rD, instr.adr);
		(*
			KernelLog.Enter; KernelLog.String("----------->>>>>> LOADC <<<<<<-----------"); KernelLog.Ln;
			KernelLog.String(" pc: "); KernelLog.Hex(instr.info(Info).pos, 8); KernelLog.Ln;
			KernelLog.String(" address loaded into register "); KernelLog.Int(rD, 0); KernelLog.Ln;
			KernelLog.String(" register in instr.info.dst "); KernelLog.Int(instr.info(Info).dst, 0); KernelLog.Ln;
			KernelLog.String("-----------------------------------------"); KernelLog.Ln; KernelLog.Exit;
		*)
		(*
			STRANGE....the constant in the constant pool already contains the offset that needs to be added to adr CHECK THAT !!!!! TODO !!!!!!
			IF PCO.MakeA1Immediate(instr.val, so) THEN
				PCO.ADD(AL, PCO.A1Imm, rD, rD, so, {})
			ELSE
				rT := LoadConstant(PCO.GetCodePos(), -1, instr.val, 1);
				PCO.ADD(AL, PCO.A1Reg, rD, rD, PCO.MakeA1Register(rT), {});
				regs.FreeReg(rT)
			END;
		*)
		(*
			addrMode := PCO.A2WImmOffset; address := PCO.MakeA2Immediate(addrMode, 0);
			PCO.LDR(AL, addrMode, rD, rAdr, address);
			regs.FreeReg(rAdr)
		*)
	ELSIF (instr.dstSize IN PCLIR.IntSize) THEN (* integer constant *)
		(*
			rD <- instr.val
		*)
		info.dst.Low := LoadConstant(PCO.GetCodePos(), info.dst.Low, instr.val, instr.dstCount);
		IF (instr.dstSize = PCLIR.Int64) THEN
			info.dst.High := LoadConstant(PCO.GetCodePos(), info.dst.High, 0, instr.dstCount)
		END
	ELSE ToDo(pc, "Unsupported register size")
	END
END LoadC;

PROCEDURE In(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	Error(pc, "'in' not supported")
END In;

PROCEDURE Out(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	Error(pc, "'out' not supported")
END Out;

PROCEDURE Nop(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		R0 <- R0
	*)
	PCO.MOV(AL, PCO.A1Reg, R0, PCO.MakeA1Register(R0), {})
END Nop;

PROCEDURE Label(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info, f: Info;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF (instr.val = 0) THEN (* it's a branch target *)
		IF (info.fixup # NIL) THEN
			f := info.fixup;
			WHILE (f # NIL) DO
				PCO.FixJump(f.pos, (info.pos - f.pos - 8) DIV 4);
				f := f.fixup
			END
		END;
		IF info.target THEN regs.InvalidateAll END (* invalidate registers if this label is a jump target *)
	ELSE
		PCO.sourcepos := instr.val;
		IF (info.pos >= PCM.breakpc) THEN (* PC.Compile \f support *)
			PCM.Error(400, lastLabelPos, "");
			PCM.breakpc := MAX(LONGINT)
		END;
		lastLabelPos := instr.val
	END;

	IF (instr.op = PCLIR.finallylabel) THEN
		IF (instr.adr # NIL) THEN
			IF (instr.adr IS PCBT.Procedure) THEN
				instr.adr(PCBT.Procedure).finallyOff := info.pos DIV 4;
			ELSIF (instr.adr IS PCBT.Module) THEN
				instr.adr(PCBT.Module).finallyOff := info.pos DIV 4;
			END;
		END;
	END;

END Label;

PROCEDURE JCC(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; cond: SET; target: PCLIR.Instruction; offset: LONGINT;
BEGIN
	info := instr.info(Info);

	IF (instr.op # PCLIR.jmp) THEN Compare(code, instr) END;

	(* info.pos *must* point to the jcc-instruction *)
	info.pos := PCO.GetCodePos();
	CASE instr.op OF
	| PCLIR.je : cond := PCO.EQ
	| PCLIR.jne : cond := PCO.NE
	| PCLIR.jlt : cond := PCO.LT
	| PCLIR.jle : cond := PCO.LE
	| PCLIR.jgt : cond := PCO.GT
	| PCLIR.jge : cond := PCO.GE
	| PCLIR.jb : cond := PCO.LO
	| PCLIR.jbe : cond := PCO.LS
	| PCLIR.ja : cond := PCO.HI
	| PCLIR.jae : cond := PCO.HS
	| PCLIR.jf : cond := PCO.NE
	| PCLIR.jnf : cond := PCO.EQ
	| PCLIR.jmp : cond := AL
	END;

	target := FindDefinition(code, instr.val);
	IF (target.info(Info).pos = -1) THEN (* forward jump *)
		info.fixup := target.info(Info).fixup;
		target.info(Info).fixup := info;
		PCO.B(cond, -1)
	ELSE (* jump target known *)
		offset := (target.info(Info).pos - info.pos - 8) DIV 4;
		PCO.B(cond, offset)
	END;
	IF (cond = AL) THEN pool.Flush(PCO.GetCodePos()) END
END JCC;

PROCEDURE FloatingPointComparison(code: PCLIR.Code; VAR instr: PCLIR.Instruction);
VAR info: Info; long: BOOLEAN; def: PCLIR.Instruction; rA, rB: XRegister; rs, addrMode, address: SET; cmpOp: LONGINT;
BEGIN
	info := instr.info(Info); (* info.pos not needed *)
	long := (InstructionType(code, instr) = PCLIR.Float64);

	(* prepare parameters *)
	ASSERT((FSrc1 IN info.flags) & (FSrc2 IN info.flags), INTERNALERROR);
	def := FindDefinition(code, instr.src1);
	long := def.dstSize = PCLIR.Float64;
	rA.Low := def.info(Info).dst.Low; regs.FreeReg(rA.Low);
	IF long THEN rA.High := def.info(Info).dst.High; regs.FreeReg(rA.High) END;

	def := FindDefinition(code, instr.src2);
	rB.Low := def.info(Info).dst.Low; regs.FreeReg(rB.Low);
	IF long THEN rB.High := def.info(Info).dst.High; regs.FreeReg(rB.High) END;

	(* save registers that are in use *)
	rs := regs.GetUsedRegisterSet();
	IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

	(* push operands (can't use STM because registers are not ordered) *)
	(* push high word first ! *)
	addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
	IF long THEN PCO.STR(AL, addrMode, SP, rA.High, address) END;
	PCO.STR(AL, addrMode, SP, rA.Low, address);
	IF long THEN PCO.STR(AL, addrMode, SP, rB.High, address) END;
	PCO.STR(AL, addrMode, SP, rB.Low, address);

	(* generate system call *)
	CASE instr.op OF
	| PCLIR.je, PCLIR.sete : cmpOp := FEq
	| PCLIR.jne, PCLIR.setne : cmpOp := FNe
	| PCLIR.jlt, PCLIR.setlt : cmpOp := FLt
	| PCLIR.jle, PCLIR.setle : cmpOp := FLe
	| PCLIR.jgt, PCLIR.setgt : cmpOp := FGt
	| PCLIR.jge, PCLIR.setge : cmpOp := FGe
	ELSE HALT(INTERNALERROR) (* invalid comparison *)
	END;
	IF (InstructionType(code, instr) IN TwoRegisters) THEN
		cmpOp := cmpOp + FLongOffset
	END;
	SystemCall(cmpOp);

	(* set condition flags. Result is in R0. 1 = TRUE, 0 = FALSE *)
	PCO.CMP(AL, PCO.A1Imm, RReturn, PCO.A1Immediate1);

	(* restore registers (does not modify flags) *)
	IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W); regs.InvalidateAll END
END FloatingPointComparison;

PROCEDURE Call(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; addrMode, address: SET; adr: PCBT.Procedure;
BEGIN
	PCO.Lock;
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	adr := instr.adr(PCBT.Procedure);
	IF (adr.owner # PCBT.context) THEN (* it's an external call (32bit absolute address) *)
		(*
			LR <- PC + 4
			PC <- MEM[PC-4]
			data: address
			return here
		*)
		IF Trace THEN
			KernelLog.Enter; KernelLog.String("Call: external; pc = "); KernelLog.Hex(info.pos, 0); KernelLog.Exit
		END;
		PCO.ADD(AL, PCO.A1Imm, LR, PC, PCO.A1Immediate4, {});
		addrMode := PCO.A2Word + PCO.Offset; address := PCO.MakeA2Immediate(addrMode, -4);
		PCO.LDR(AL, addrMode, PC, PC, address);
		(*
		PCO.DCD(adr.fixlist*10000H);
		adr.fixlist := (PCO.GetCodePos() - PCO.InstructionSize) DIV 4
		*)
		(* 08.05.02: interface changed again
		PCBT.context.UseProcedure(adr, PCO.GetCodePos() DIV 4);
		PCO.DCD(0)
		*)
		PCBT.context.UseProcedure(adr, PCO.GetCodePos() DIV 4);
		PCO.DCD(0)
	ELSE (* internal calls use BL (26bit signed offset) *)
		(*
			BL address
		*)
		IF (adr.codeoffset = 0) THEN (* address unknown, will be patched later *)
			IF Trace THEN
				KernelLog.Enter; KernelLog.String("Call: address unknown; pc = "); KernelLog.Hex(info.pos, 0);
				KernelLog.String("; fixlist = "); KernelLog.Int(adr.fixlist, 0); KernelLog.Exit
			END;
			PCO.BL(AL, adr.fixlist);
			adr.fixlist := info.pos DIV 4
		ELSE
			IF Trace THEN
				KernelLog.Enter; KernelLog.String("Call: address known; pc = "); KernelLog.Hex(info.pos, 0);
				KernelLog.String("; branch offset = "); KernelLog.Hex((adr.codeoffset*4 - info.pos - 8), 0); KernelLog.Exit
			END;
			PCO.BL(AL, (adr.codeoffset*4 - info.pos - 8) DIV 4)
		END
	END;
	regs.InvalidateAll;
	PCO.Unlock
END Call;

PROCEDURE CallReg(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rAdr: XRegister;
BEGIN
	PCO.Lock;
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		LR <- PC
		PC <- rAdr
		return here
	*)
	rAdr := ResolveRegister(code, instr.src1);
	PCO.MOV(AL, PCO.A1Reg, LR, PCO.MakeA1Register(PC), {});
	PCO.MOV(AL, PCO.A1Reg, PC, PCO.MakeA1Register(rAdr.Low), {});
	regs.FreeReg(rAdr.Low);
	regs.InvalidateAll;
	PCO.Unlock
END CallReg;

PROCEDURE SysCall(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
BEGIN
	PCO.Lock;
	instr.info(Info).pos := PCO.GetCodePos();
	SystemCall(instr.val);
	regs.InvalidateAll;
	PCO.Unlock
END SysCall;

PROCEDURE SetCC(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; true, false: SET; rD: LONGINT; dummy: BOOLEAN;
BEGIN
	info := instr.info(Info);
	Compare(code, instr);
	info.pos := PCO.GetCodePos();

	(*
		false: rD <- 0
		true: rD <- 1
	*)
	CASE instr.op OF
	| PCLIR.je, PCLIR.sete: true := PCO.EQ; false := PCO.NE	(* Compare sets instr.op = PCLIR.je for floating-point comparisons *)
	| PCLIR.setne: true := PCO.NE; false := PCO.EQ
	| PCLIR.setlt: true := PCO.LT; false := PCO.GE
	| PCLIR.setle: true := PCO.LE; false := PCO.GT
	| PCLIR.setgt: true := PCO.GT; false := PCO.LE
	| PCLIR.setge: true := PCO.GE; false := PCO.LT
	| PCLIR.setb: true := PCO.LO; false := PCO.HS
	| PCLIR.setbe: true := PCO.LS; false := PCO.HI
	| PCLIR.seta: true := PCO.HI; false := PCO.LS
	| PCLIR.setae: true := PCO.HS; false := PCO.LO
	| PCLIR.setf: true := PCO.NE; false := PCO.EQ	(* the 'Compare' call above generated a TST (= AND) instruction *)
	| PCLIR.setnf: true := PCO.EQ; false := PCO.NE	(* idem *)
	END;
	IF (info.dst.Low = -1) THEN rD := regs.AllocReg(NIL, dummy, instr.dstCount); info.dst.Low := rD
	ELSE rD := info.dst.Low
	END;
	PCO.MOV(false, PCO.A1Imm, rD, PCO.A1Immediate0, {});
	PCO.MOV(true, PCO.A1Imm, rD, PCO.A1Immediate1, {});
	regs.SetRegisterContent(rD, NIL)
END SetCC;

PROCEDURE Kill(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; i: PCLIR.Instruction; rD,  rPhi, pos, delta: LONGINT; phiFound, killFound: BOOLEAN;
	reg: RA.Register;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	IF (info.dst.Low = -1) THEN (* it's the first kill *)
		IF TTrace THEN Write("KILL: first kill instruction at pos "); Int(pc); Ln END;
		(* get the destination register of the instruction that defines the kill variable *)
		i := FindDefinition(code, instr.src1);
		rD := i.info(Info).dst.Low; ASSERT(rD # -1, INTERNALERROR);
		info.dst.Low := rD;
		IF TTrace THEN
			Write("  rD of defining instruction is "); Int(rD); Ln;
			Write("    use count = "); Int(instr.dstCount); Ln;
			Write("  Searching phi-phunkiton...")
		END;
		(* propagate this destination register 'rD' to the associated phi instruction, the second kill
			instruction and the instruction that defines the kill variable of the second kill *)
		pos := pc+1;
		REPEAT
			i := FindDefinition(code, pos);
			IF (i.op = PCLIR.phi) & ((i.src1 = instr.src1) OR (i.src2 = instr.src1)) THEN
				IF (i.src1 = instr.src1) THEN rPhi := i.src2 ELSE rPhi := i.src1 END;
				i.info(Info).dst.Low := rD; delta := i.dstCount; phiFound := TRUE
			ELSE
				INC(pos); IF TTrace & (pos MOD 10 = 0) THEN Write("("); Int(pos); Write(") ") END
			END
		UNTIL phiFound;
		IF TTrace THEN
			Write("ok. Found at pos "); Int(pos); Ln;
			Write("   use count = "); Int(delta); Ln;
			Write("  Searching second kill instruction...")
		END;
		pos := pc+1;
		REPEAT
			i := FindDefinition(code, pos);
			IF (i.op = PCLIR.kill) & (i.src1 = rPhi) THEN
				IF TTrace THEN Write("ok. Found at pos "); Int(pos); Ln END;
				ASSERT(i.info(Info).dst.Low = -1, INTERNALERROR);
				i.info(Info).dst.Low := rD;
				i := FindDefinition(code, rPhi);
				ASSERT(i.info(Info).dst.Low = -1, INTERNALERROR);
				i.info(Info).dst.Low := rD;
				delta := delta + i.dstCount;
				IF TTrace THEN
					Write("   instr at pos "); Int(rPhi); Write(": rD set to "); Int(rD); Ln;
					Write("   use count = "); Int(i.dstCount); Ln
				END;
				killFound := TRUE
			ELSE
				INC(pos)
			END
		UNTIL killFound;
		(* update use-counters *)
		IF TTrace THEN Write(" updating use count of rD by "); Int(delta); Ln END;
		regs.FixRegisterUse(rD, delta)
	ELSE (* it's the second kill *)
		reg := regs.GetReg(info.dst.Low);
		IF TTrace THEN Write("Second Kill: use count of "); Int(reg.id); Write(" = "); Int(reg.free); Ln END
	END
END Kill;

PROCEDURE Phi(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR reg: XRegister;
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	ASSERT(instr.info(Info).dst.Low # -1, INTERNALERROR);
	reg := ResolveRegister(code, instr.src1); regs.FreeReg(reg.Low);
	reg := ResolveRegister(code, instr.src2); regs.FreeReg(reg.Low)
END Phi;

PROCEDURE LoadSP(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rA: XRegister;
BEGIN
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		SP <- reg
	*)
	rA := ResolveRegister(code, instr.src1);
	PCO.MOV(AL, PCO.A1Reg, SP, PCO.MakeA1Register(rA.Low), {});
	regs.FreeReg(rA.Low)
END LoadSP;

PROCEDURE Copy(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; srcDef: PCLIR.Instruction;

	PROCEDURE CopyRegister(from: LONGINT; VAR to: LONGINT; useCount: LONGINT);
	BEGIN
		IF (regs.GetRegisterUseCount(from) > 1) OR (to # -1) THEN
			(* the source register is sill used or the result is expected to be in a designated register => copy *)
			(*
				rD <- rS
			*)
			IF (to = -1) THEN to := regs.AllocDestReg(useCount) END;
			PCO.MOV(AL, PCO.A1Reg, to, PCO.MakeA1Register(from), {});
			regs.FreeReg(from)
		ELSE (* it's the last use of this register => leave in register, update use count *)
			to := from;
			regs.FixRegisterUse(to, useCount - 1)
		END;
		regs.SetRegisterContent(to, NIL)
	END CopyRegister;

BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	srcDef := FindDefinition(code, instr.src1);
	ASSERT(Size(srcDef.dstSize) = Size(instr.dstSize), INTERNALERROR);

	CopyRegister(srcDef.info(Info).dst.Low, info.dst.Low, instr.dstCount);
	IF (Size(instr.dstSize) = 2) THEN CopyRegister(srcDef.info(Info).dst.High, info.dst.High, instr.dstCount) END
END Copy;

PROCEDURE Conversion(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; srcDef: PCLIR.Instruction; rD: XRegister; op: LONGINT; addrMode, address, rs: SET;
BEGIN (* TODO simplify *)
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	srcDef := FindDefinition(code, instr.src1);
	IF (srcDef.dstSize IN PCLIR.IntSize) THEN
		IF (instr.dstSize IN PCLIR.IntSize) THEN
			(* no special conversion needed for the low register since all data types are extended to 32bit when loaded into a register *)
			IF (regs.GetRegisterUseCount(srcDef.info(Info).dst.Low) > 1) OR (info.dst.Low # -1) THEN
				(* the source register is sill used or the result is expected to be in a designated register => copy *)
				(*
					rD <- rS
				*)
				IF (info.dst.Low = -1) THEN rD.Low := regs.AllocDestReg(instr.dstCount); info.dst.Low := rD.Low
				ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
				END;
				PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(srcDef.info(Info).dst.Low), {});
				regs.FreeReg(srcDef.info(Info).dst.Low)
			ELSE (* it's the last use of this register => leave in register, update use count *)
				info.dst.Low := srcDef.info(Info).dst.Low;
				regs.SetRegisterContent(info.dst.Low, NIL);
				regs.FixRegisterUse(info.dst.Low, instr.dstCount - 1)
			END;

			IF (instr.dstSize = PCLIR.Int64) THEN (* allocate a high register and sign-extend the low register *)
				(*
					rD.High <- 0
					if (rD.Low < 0): rD.High <- NOT rD.High
				*)
				IF (info.dst.High = -1) THEN rD.High := regs.AllocDestReg(instr.dstCount); info.dst.High := rD.High
				ELSE rD.High := info.dst.High; regs.SetRegisterContent(rD.High, NIL)
				END;

				PCO.MOV(AL, PCO.A1Imm, rD.High, PCO.A1Immediate0, {});
				PCO.CMP(AL, PCO.A1Imm, rD.Low, PCO.A1Immediate0);
				PCO.MVN(PCO.LT, PCO.A1Reg, rD.High, PCO.MakeA1Register(rD.High), {})
			ELSIF (srcDef.dstSize = PCLIR.Int64) THEN
				regs.FreeReg(srcDef.info(Info).dst.High) (* overflow check: srcDef.info.dst.High = 0 ? *)
			END
		ELSE (* instr.dstSize IN PCLIR.FloatSize *)
			IF (srcDef.dstSize = PCLIR.Int64) THEN Error(pc, "Conversion Int64 -> [LONG]REAL not supported")
			ELSE (* 32bit Integer -> [LONG]REAL *)
				(* free source register *)
				regs.FreeReg(srcDef.info(Info).dst.Low);

				(* save registers *)
				rs := regs.GetUsedRegisterSet();
				IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

				(* push parameter *)
				addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
				PCO.STR(AL, addrMode, SP, srcDef.info(Info).dst.Low, address);

				(* generate syscall *)
				op := FIntToReal;
				IF (instr.dstSize = PCLIR.Float64) THEN op := op + FLongOffset END;
				SystemCall(op);

				(* store result *)
				IF (info.dst.Low = -1) THEN
					IF regs.IsRegisterFree(RReturn) THEN
						regs.AllocSpecialReg(RReturn, NIL, instr.dstCount); rD.Low := RReturn
					ELSE
						rD.Low := regs.AllocDestReg(instr.dstCount)
					END;
					info.dst.Low := rD.Low
				ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
				END;
				IF (rD.Low # RReturn) THEN
					PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(RReturn), {})
				END;
				IF (instr.dstSize = PCLIR.Float64) THEN
					IF (info.dst.High = -1) THEN
						IF regs.IsRegisterFree(RReturn2) THEN
							regs.AllocSpecialReg(RReturn2, NIL, instr.dstCount); rD.High := RReturn2
						ELSE
							rD.High := regs.AllocDestReg(instr.dstCount)
						END;
						info.dst.High := rD.High
					ELSE rD.High := info.dst.High; regs.SetRegisterContent(rD.High, NIL)
					END;
					IF (rD.High # RReturn2) THEN
						PCO.MOV(AL, PCO.A1Reg, rD.High, PCO.MakeA1Register(RReturn2), {})
					END
				END;

				(* restore saved registers *)
				IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W) END
			END
		END

	ELSE (* srcDef.dstSize IN PCLIR.FloatSize *)
		IF (instr.dstSize = PCLIR.Int64) THEN Error(pc, "Conversion [LONG]REAL -> Int64 not supported")
		ELSIF (instr.dstSize IN PCLIR.IntSize) THEN (* [LONG]REAL -> IntX *)
			(* free source register(s) *)
			regs.FreeReg(srcDef.info(Info).dst.Low);
			IF (srcDef.dstSize = PCLIR.Float64) THEN regs.FreeReg(srcDef.info(Info).dst.High) END;

			(* save registers *)
			rs := regs.GetUsedRegisterSet();
			IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

			(* push parameter(s) *)
			addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
			IF (srcDef.dstSize = PCLIR.Float64) THEN
				PCO.STR(AL, addrMode, SP, srcDef.info(Info).dst.High, address)
			END;
			PCO.STR(AL, addrMode, SP, srcDef.info(Info).dst.Low, address);

			(* generate syscall *)
			op := FRealToInt;
			IF (srcDef.dstSize = PCLIR.Float64) THEN op := op + FLongOffset END;
			SystemCall(op);

			(* store result *)
			IF (info.dst.Low = -1) THEN
				IF regs.IsRegisterFree(RReturn) THEN
					regs.AllocSpecialReg(RReturn, NIL, instr.dstCount); rD.Low := RReturn
				ELSE
					rD.Low := regs.AllocDestReg(instr.dstCount)
				END;
				info.dst.Low := rD.Low
			ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
			END;
			IF (rD.Low # RReturn) THEN
				PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(RReturn), {})
			END;

			(* restore saved registers *)
			IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W) END

		ELSE (* [LONG]REAL -> [LONG]REAL *)
			(* free source register(s) *)
			regs.FreeReg(srcDef.info(Info).dst.Low);
			IF (srcDef.dstSize = PCLIR.Float64) THEN regs.FreeReg(srcDef.info(Info).dst.High) END;

			(* save registers *)
			rs := regs.GetUsedRegisterSet();
			IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

			(* push parameter(s) *)
			addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
			IF (srcDef.dstSize = PCLIR.Float64) THEN
				PCO.STR(AL, addrMode, SP, srcDef.info(Info).dst.High, address)
			END;
			PCO.STR(AL, addrMode, SP, srcDef.info(Info).dst.Low, address);

			(* generate syscall *)
			op := FRealToReal;
			IF (srcDef.dstSize = PCLIR.Float64) THEN op := op + FLongOffset END;
			SystemCall(op);

			(* store result *)
			IF (info.dst.Low = -1) THEN
				IF regs.IsRegisterFree(RReturn) THEN
					regs.AllocSpecialReg(RReturn, NIL, instr.dstCount); rD.Low := RReturn
				ELSE
					rD.Low := regs.AllocDestReg(instr.dstCount)
				END;
				info.dst.Low := rD.Low
			ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
			END;
			IF (rD.Low # RReturn) THEN
				PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(RReturn), {})
			END;
			IF (instr.dstSize = PCLIR.Float64) THEN
				IF (info.dst.High = -1) THEN
					IF regs.IsRegisterFree(RReturn2) THEN
						regs.AllocSpecialReg(RReturn2, NIL, instr.dstCount); rD.High := RReturn2
					ELSE
						rD.High := regs.AllocDestReg(instr.dstCount)
					END;
					info.dst.High := rD.High
				ELSE rD.High := info.dst.High; regs.SetRegisterContent(rD.High, NIL)
				END;
				IF (rD.High # RReturn2) THEN
					PCO.MOV(AL, PCO.A1Reg, rD.High, PCO.MakeA1Register(RReturn2), {})
				END
			END;

			(* restore saved registers *)
			IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W) END
		END
	END
END Conversion;

PROCEDURE BitOp(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rA, rB, rD: XRegister; rT, rBx: LONGINT; addrMode, so: SET; info: Info; dummy: BOOLEAN; imm: SET;
BEGIN
	info := instr.info(Info);
	info.pos := PCO.GetCodePos();
	ASSERT((FSrc1 IN info.flags) & (FSrc2 IN info.flags) & ~(FVal IN info.flags), INTERNALERROR);
	rA := ResolveRegister(code, instr.src1);
	rB := ResolveRegister(code, instr.src2);
	rT := LoadConstant(PCO.GetCodePos(), -1, 1, 1);
	addrMode := PCO.A1ShiftReg;
	IF (info.dst.Low = -1) THEN rD.Low := regs.AllocDestReg(instr.dstCount); info.dst.Low := rD.Low
	ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
	END;

	IF (InstructionType(code, instr) IN RegularIntSize) THEN
		so := PCO.MakeA1RegSHIFTReg(rT, rB.Low, PCO.Lsl);
		CASE instr.op OF
		| PCLIR.bts: PCO.ORR(AL, addrMode, rD.Low, rA.Low, so, {})
		| PCLIR.btc: PCO.BIC(AL, addrMode, rD.Low, rA.Low, so, {})
	 	END
	ELSE
		IF (info.dst.High = -1) THEN rD.Low := regs.AllocDestReg(instr.dstCount); info.dst.High := rD.High
		ELSE rD.High := info.dst.High; regs.SetRegisterContent(rD.High, NIL)
		END;
		rBx := regs.AllocReg(NIL, dummy, 1);
		dummy := PCO.MakeA1Immediate(32, imm); ASSERT(dummy);

		(*
			rB.Low <= 32 ?
			yes: goto (1)
			no:
				rA.Low <- set/clear bit rB.Low in rA.Low
				goto end
			(1):
				rBx <- rB.Low - 32
				rA.High <- set/clear bit rBx in rA.High
			end:
		*)
		PCO.CMP(AL, PCO.A1Imm, rB.Low, imm);
		PCO.B(PCO.GE, 1);
		so := PCO.MakeA1RegSHIFTReg(rT, rB.Low, PCO.Lsl);
		CASE instr.op OF
		| PCLIR.bts: PCO.ORR(AL, addrMode, rD.Low, rA.Low, so, {})
		| PCLIR.btc: PCO.BIC(AL, addrMode, rD.Low, rA.Low, so, {})
	 	END;
		PCO.B(AL, 1);
		(* (1) *)
		PCO.SUB(PCO.GE, PCO.A1Imm, rBx, rB.Low, imm, {});
		so := PCO.MakeA1RegSHIFTReg(rT, rBx, PCO.Lsl);
		CASE instr.op OF
		| PCLIR.bts: PCO.ORR(AL, addrMode, rD.High, rA.High, so, {})
		| PCLIR.btc: PCO.BIC(AL, addrMode, rD.High, rA.High, so, {})
	 	END;
		(* end *)
		regs.FreeReg(rBx)
	END;
	regs.FreeReg(rA.Low); regs.FreeReg(rB.Low); regs.FreeReg(rT)
END BitOp;

PROCEDURE DivMod(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; rs, addrMode, address: SET; rD, rA, rB: XRegister;  op, returnR: LONGINT;
BEGIN
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	(* if this is a floating point DIV/MOD, we are in the wrong place...*)
	IF (instr.dstSize IN PCLIR.FloatSize) THEN
		FloatingPointDPI(code, instr, pc)
	ELSE (* TODO: HUGEINT *)
		(* since the ARM does support neither DIV nor MOD, these are implemented as system calls
			MEM[SP...] <- used registers, SP <- SP + (nof registers saved)*4
			SP <- SP - 4, MEM[SP..SP+3] <- rA
			SP <- SP - 4, MEM[SP..SP+3] <- rB
			LR <- PC + 4
			PC <- MEM[PC-4]
			data: address of div/mod
			rD <- rReturn
			registers <- MEM[SP...], SP <- SP - (nof registers)*4
		*)
		IF (instr.op = PCLIR.div) THEN op := DivIndex; returnR := RReturn (*SyscallDIV. Result in RReturn *)
		ELSE (* instr.op = PCLIR.mod *) op := ModIndex; returnR := RReturn2 (*SyscallMOD. Result in RReturn2 *)
		END;

		ASSERT((FSrc1 IN info.flags) & (FSrc2 IN info.flags), INTERNALERROR);
		rA := ResolveRegister(code, instr.src1);
		rB := ResolveRegister(code, instr.src2);
		ASSERT((rA.High = -1) & (rB.High = -1), ErrImplementationRestriction); (* 64bit DIV/MOD not supported *)
		regs.FreeReg(rA.Low); regs.FreeReg(rB.Low);

		rs := regs.GetUsedRegisterSet();
		IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

		addrMode := PCO.A2WImmPreIdxd;
		address := PCO.MakeA2Immediate(addrMode, -4);
		PCO.STR(AL, addrMode, SP, rA.Low, address);
		PCO.STR(AL, addrMode, SP, rB.Low, address);

		SystemCall(op);

		IF (info.dst.Low = -1) THEN
			IF regs.IsRegisterFree(returnR) THEN
				regs.AllocSpecialReg(returnR, NIL, instr.dstCount); rD.Low := returnR
			ELSE
				rD.Low := regs.AllocDestReg(instr.dstCount)
			END;
			info.dst.Low := rD.Low
		ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
		END;
		IF (rD.Low # returnR) THEN
			PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(returnR), {})
		END;
		IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W); regs.InvalidateAll END
	END
END DivMod;

PROCEDURE DataProcessingInstruction(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rA, rB, rC, rD: XRegister; val, type: LONGINT; info: Info; mode, conl, conr, sol, sor: SET; b, sC: BOOLEAN;
BEGIN
	info := instr.info(Info);
	info.pos := PCO.GetCodePos();
	type := InstructionType(code, instr);

	IF (type IN PCLIR.IntSize) THEN
		rA.Low := -1; rA.High := -1; rB.Low := -1; rB.High := -1; rC.Low := -1; rC.High := -1; rD.Low := -1; rD.High := -1;
		IF (FSrc1 IN info.flags) THEN rA := ResolveRegister(code, instr.src1) END;
		IF (FSrc2 IN info.flags) THEN rB := ResolveRegister(code, instr.src2) END;
		IF (FSrc3 IN info.flags) THEN XResolveRegister(code, instr.src3, rC, sC) END;
		IF (FVal IN info.flags) THEN val := instr.val END;

		IF (info.dst.Low = -1) THEN rD.Low := regs.AllocDestReg(instr.dstCount); info.dst.Low := rD.Low
		ELSE rD.Low := info.dst.Low; regs.SetRegisterContent(rD.Low, NIL)
		END;

		IF (type IN RegularIntSize) THEN
			(*
				rD <- rA op rB/imm [shift ...]
			*)

			mode := PCO.A1Reg; conl := AL; conr := PCO.NE;
			IF (info.xop = none) & ~IsShift(instr.op) THEN
				IF (FSrc2 IN info.flags) THEN sol := PCO.MakeA1Register(rB.Low)
				ELSIF (FVal IN info.flags) THEN mode := PCO.A1Imm; b := PCO.MakeA1Immediate(val, sol); ASSERT(b, INTERNALERROR)
				ELSIF (instr.op = PCLIR.abs) OR (instr.op = PCLIR.neg) OR (instr.op = PCLIR.not) THEN sol := PCO.MakeA1Register(rA.Low)
				ELSE HALT(INTERNALERROR)
				END
			ELSIF (info.xop = rsub) THEN
				ASSERT((instr.op = PCLIR.sub) & (FVal IN info.flags), INTERNALERROR);
				mode := PCO.A1Imm; b := PCO.MakeA1Immediate(val, sol); ASSERT(b, INTERNALERROR)
			ELSE
				PrepareShifterOperands(info.xop, type, info.flags, rB, rC, val, sC, mode, conl, conr, sol, sor);
			END;

			IF (info.xop = PCLIR.rot) & (instr.dstSize < PCLIR.Int32) THEN ROTPrologue(rB.Low, instr.dstSize) END;

			CASE instr.op OF
			| PCLIR.add :
				PCO.ADD(conl, mode, rD.Low, rA.Low, sol, {});
				IF (conr # NE) THEN PCO.ADD(conr, mode, rD.Low, rA.Low, sor, {}) END
			| PCLIR.sub :
				IF (info.xop # rsub) THEN
					PCO.SUB(conl, mode, rD.Low, rA.Low, sol, {});
					IF (conr # NE) THEN PCO.SUB(conr, mode, rD.Low, rA.Low, sor, {}) END
				ELSE
					PCO.RSB(conl, mode, rD.Low, rA.Low, sol, {})
				END;
			| PCLIR.mul :
				ASSERT(conl = AL, ErrImplementationRestriction);
				PCO.MUL(AL, rD.Low, rA.Low, rB.Low, {});
			| PCLIR.and :
				PCO.AND(conl, mode, rD.Low, rA.Low, sol, {});
				IF (conr # NE) THEN PCO.AND(conr, mode, rD.Low, rA.Low, sor, {}) END
			| PCLIR.or:
				PCO.ORR(conl, mode, rD.Low, rA.Low, sol, {});
				IF (conr # NE) THEN PCO.AND(conr, mode, rD.Low, rA.Low, sor, {}) END
			| PCLIR.xor :
				PCO.EOR(conl, mode, rD.Low, rA.Low, sol, {});
				IF (conr # NE) THEN PCO.EOR(conr, mode, rD.Low, rA.Low, sor, {}) END
			| PCLIR.bsh, PCLIR.ash, PCLIR.rot:
				PCO.MOV(conl, mode, rD.Low, sol, {});
				IF (conr # NE) THEN PCO.MOV(conr, mode, rD.Low, sor, {}) END;
			| PCLIR.abs:
				PCO.CMP(AL, PCO.A1Imm, rA.Low, PCO.A1Immediate0);
				PCO.RSB(PCO.LT, PCO.A1Imm, rD.Low, rA.Low, PCO.A1Immediate0, {});
				IF (rA.Low # rD.Low) THEN
					PCO.MOV(PCO.GE, PCO.A1Reg, rD.Low, PCO.MakeA1Register(rA.Low), {})
				END
			| PCLIR.neg:
				PCO.RSB(AL, PCO.A1Imm, rD.Low, rA.Low, PCO.A1Immediate0, {})
			| PCLIR.not:
				PCO.MVN(AL, mode, rD.Low, sol, {})
			ELSE HALT(INTERNALERROR)
			END;

			IF (info.xop = PCLIR.rot) & (instr.dstSize < PCLIR.Int32) THEN ROTEpilogue(rD.Low, type, instr.dstSigned) END;

			IF (FDst IN info.flags) THEN regs.SetRegisterContent(rD.Low, NIL) END;
			IF (FSrc1 IN info.flags) THEN regs.FreeReg(rA.Low) END;
			IF (FSrc2 IN info.flags) THEN regs.FreeReg(rB.Low) END;
			IF (FSrc3 IN info.flags) THEN regs.FreeReg(rC.Low) END
		ELSIF (type = PCLIR.Int64) THEN (* HUGEINT: do not forget Carry Poppins *)
			ASSERT({FDst, FSrc1} * info.flags = {FDst, FSrc1}, INTERNALERROR);
			ASSERT(~(FVal IN info.flags), INTERNALERROR);
			ASSERT((rA.High # -1) & ((rB.High # -1) OR ((instr.op = PCLIR.bsh) OR (instr.op = PCLIR.ash) OR (instr.op = PCLIR.rot))), INTERNALERROR);

			IF (info.dst.High = -1) THEN rD.High := regs.AllocDestReg(instr.dstCount); info.dst.High := rD.High
			ELSE rD.High := info.dst.High; regs.SetRegisterContent(rD.High, NIL)
			END;

			mode := PCO.A1Reg;
			CASE instr.op OF
			| PCLIR.add:
				(*
					rD.Low <- rA.Low + rB.Low
					rD.High <- rA.High + rB.High + carry
				*)
				PCO.ADD(AL, PCO.A1Reg, rD.Low, rA.Low, PCO.MakeA1Register(rB.Low), PCO.Sflag);
				PCO.ADC(AL, PCO.A1Reg, rD.High, rA.High, PCO.MakeA1Register(rB.High), {})
			| PCLIR.sub:
				ASSERT(info.xop # rsub, INTERNALERROR);
				(*
					rD.Low <- rA.Low - rB.Low
					rD.High <- rA.High - rB.High - carry
				*)
				PCO.SUB(AL, PCO.A1Reg, rD.Low, rA.Low, PCO.MakeA1Register(rB.Low), PCO.Sflag);
				PCO.SBC(AL, PCO.A1Reg, rD.High, rA.High, PCO.MakeA1Register(rB.High), PCO.Sflag)
			| PCLIR.mul:
				ASSERT((rD.Low # rA.Low) & (rD.Low # rB.Low) & (rD.High # rA.High) & (rD.High # rB.High), INTERNALERROR);
				(*
					rD <- rA.Low*rB.Low
					rD.High <- rD.High + rA.Low*rB.High
					rD.High <- rD.High + rA.High*rB.Low
				*)
				PCO.UMULL(AL, rD.Low, rD.High, rA.Low, rB.Low, {});
				PCO.MLA(AL, rD.High, rA.Low, rB.High, rD.High, {});
				PCO.MLA(AL, rD.High, rA.High, rB.Low, rD.High, {})
			| PCLIR.and:
				(*
					rD.Low <- rA.Low AND rB.Low
					rD.High <- rB.High AND rB.High
				*)
				PCO.AND(AL, PCO.A1Reg, rD.Low, rA.Low, PCO.MakeA1Register(rB.Low), {});
				PCO.AND(AL, PCO.A1Reg, rD.High, rA.High, PCO.MakeA1Register(rB.High), {})
			| PCLIR.or:
				(*
					rD.Low <- rA.Low OR rB.Low
					rD.High <- rA.High OR rB.High
				*)
				PCO.ORR(AL, PCO.A1Reg, rD.Low, rA.Low, PCO.MakeA1Register(rB.Low), {});
				PCO.ORR(AL, PCO.A1Reg, rD.High, rA.High, PCO.MakeA1Register(rB.High), {})
			| PCLIR.xor:
				(*
					rD.Low <- rA.Low XOR rB.Low
					rD.High <- rA.High XOR rB.High
				*)
				PCO.EOR(AL, PCO.A1Reg, rD.Low, rA.Low, PCO.MakeA1Register(rB.Low), {});
				PCO.EOR(AL, PCO.A1Reg, rD.High, rA.High, PCO.MakeA1Register(rB.High), {})
			| PCLIR.bsh, PCLIR.ash:

			| PCLIR.rot:
				PCM.Error(666, lastLabelPos, "not implemented")
			| PCLIR.abs:
				(*
					rA.High < 0 ?
					no: goto end
					yes:
						rD.Low <- 0 - rA.Low
						rD.High <- 0 - rA.High - carry
					end:
				*)
				PCO.CMP(AL, PCO.A1Imm, rA.High, PCO.A1Immediate0);
				PCO.B(PCO.GE, 1);
				PCO.RSB(AL, PCO.A1Imm, rD.Low, rA.Low, PCO.A1Immediate0, PCO.Sflag);
				PCO.RSC(AL, PCO.A1Imm, rD.High, rA.High, PCO.A1Immediate0, {})
			| PCLIR.neg:
				(*
					rD.Low <- 0 - rA.Low
					rD.High <- 0 - rA.High - carry
				*)
				PCO.RSB(AL, PCO.A1Imm, rD.Low, rA.Low, PCO.A1Immediate0, PCO.Sflag);
				PCO.RSC(AL, PCO.A1Imm, rD.High, rA.High, PCO.A1Immediate0, {})
			| PCLIR.not:
				(*
					rD.Low <- NOT(rA.Low)
					rD.High <- NOT(rA.High)
				*)
				PCO.MVN(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(rA.Low), {});
				PCO.MVN(AL, PCO.A1Reg, rD.High, PCO.MakeA1Register(rA.High), {})
			ELSE HALT(INTERNALERROR)
			END;

			regs.SetRegisterContent(rD.Low, NIL); regs.SetRegisterContent(rD.High, NIL);
			regs.FreeReg(rA.Low); regs.FreeReg(rA.High);
			IF (FSrc2 IN info.flags) THEN
				regs.FreeReg(rB.Low);
				IF (rB.High # -1) THEN regs.FreeReg(rB.High) END
			END
		END
	ELSE
		FloatingPointDPI(code, instr, pc)
	END
END DataProcessingInstruction;

(* GetSHIFTMask - returns a SHIFT mask used to AND a shift value *)
PROCEDURE GetSHIFTMask(size: LONGINT): SET;
VAR imm: SET; b: BOOLEAN;
BEGIN
	CASE size OF
	| PCLIR.Int8: b := PCO.MakeA1Immediate(7, imm)
	| PCLIR.Int16: b := PCO.MakeA1Immediate(15, imm)
	| PCLIR.Int32: b := PCO.MakeA1Immediate(31, imm)
	ELSE HALT(INTERNALERROR)
	END;
	ASSERT(b, INTERNALERROR);
	RETURN imm
END GetSHIFTMask;

PROCEDURE PrepareShifterOperands(xop: PCLIR.Opcode; size: LONGINT; flags: SET; rB, rC: XRegister; val: LONGINT; sC: BOOLEAN;
																VAR mode, conl, conr, sol, sor: SET);
BEGIN
	IF IsShift(xop)  THEN
		IF (FSrc3 IN flags) THEN (* shift by register *)
			mode := PCO.A1ShiftReg; sol := PCO.MakeA1RegSHIFTReg(rB.Low, rC.Low, {});
			IF (xop = PCLIR.bsh) OR (xop = PCLIR.ash) THEN
				IF sC THEN
					conl := PCO.GE; conr := PCO.LT; sor := sol;
					(*
						CC <- CMP rC, 0
					*)
					PCO.CMP(AL, PCO.A1Imm, rC.Low, PCO.A1Immediate0);
				END;
				(* the shift register must be negated if the value is < 0 *)
				(*
					if rC < 0: rC <- -rC
				*)
				PCO.RSB(PCO.LT, PCO.A1Imm, rC.Low, rC.Low, PCO.A1Immediate0, {});
				(* the shift register must be ANDed by a 1F because Intel Aos shifts by value MOD 32 *)
				(*
					rC <- rC AND 1Fh
				*)
				PCO.AND(AL, PCO.A1Imm, rC.Low, rC.Low, PCO.A1Immediate31, {});

				CASE xop OF
				| PCLIR.bsh: sol := sol + PCO.Lsl; sor := sor + PCO.LSR
				| PCLIR.ash: sol := sol + PCO.Lsl; IF sC THEN sor := sor + PCO.Asr ELSE sor := sor + PCO.LSR END;
				END;
				regs.SetRegisterContent(rC.Low, NIL)
			ELSIF (xop = PCLIR.rot) THEN
				conl := AL; sol := sol + PCO.Ror;

				(* prepare ROT register *)
				(*
					rC <- -rC	(ROT 1 in Oberon is Rotate Left, ARM can only rotate right)
					[rC <- rC AND (7|15)] (depends on destination register size)
				*)
				PCO.RSB(AL, PCO.A1Imm, rC.Low, rC.Low, PCO.A1Immediate0, {});
				IF (size < PCLIR.Int32) THEN (* ROR takes only bits 4:0 of rC.Low -> for 32bit values ANDing is not necessary *)
					PCO.AND(AL, PCO.A1Imm, rC.Low, rC.Low, GetSHIFTMask(size), {})
				END;
				regs.SetRegisterContent(rC.Low, NIL)
			END
		ELSE (* shift by immediate *)
			mode := PCO.A1ShiftImm; sol := PCO.MakeA1RegSHIFTImm(rB.Low, ABS(val) MOD 32, {});
			IF (val > 0) THEN
				CASE xop OF
				| PCLIR.bsh, PCLIR.ash: sol := sol + PCO.Lsl
				| PCLIR.rot: sol := PCO.MakeA1RegSHIFTImm(rB.Low, 32-(ABS(val) MOD 32), PCO.Ror)
				END
			ELSIF (val < 0) THEN
				CASE xop OF
				| PCLIR.bsh: sol := sol + PCO.LSR
				| PCLIR.ash: sol := sol + PCO.Asr
				| PCLIR.rot: sol := sol + PCO.Ror
				END
			ELSE (* val = 0 -> do not shift *)
				ASSERT(FSrc2 IN flags, INTERNALERROR);
				mode := PCO.A1Reg; sol := PCO.MakeA1Register(rB.Low)
			END
		END
	ELSE
		HALT(INTERNALERROR)
	END
END PrepareShifterOperands;

(* GetROTShifter - returns an immediate value used to shift a ROT mask *)
PROCEDURE GetROTShifter(size: LONGINT): LONGINT;
BEGIN
	CASE size OF
	| PCLIR.Int8: RETURN 24
	| PCLIR.Int16: RETURN 16
	ELSE HALT(INTERNALERROR)
	END
END GetROTShifter;

(* ROTPrologue - generates ROT prologue code *)
PROCEDURE ROTPrologue(rA, size: LONGINT);
VAR rT, shifter: LONGINT; valid: BOOLEAN;
BEGIN
	(*
		rT <- -1
		rA <- rA AND (rT LSR 24|16)	(depends on size of rA (== size of rD))
	*)
	rT := regs.AllocReg(RA.NewIntConst(-1), valid, 1);
	IF ~valid THEN PCO.MVN(AL, PCO.A1Imm, rT, PCO.A1Immediate0, {}) END;
	shifter := GetROTShifter(size);
	PCO.AND(AL, PCO.A1ShiftImm, rA, rA, PCO.MakeA1RegSHIFTImm(rT, shifter, PCO.LSR), {});
	regs.SetRegisterContent(rA, NIL);
	regs.FreeReg(rT)
END ROTPrologue;

(* ROTEpilogue - generates ROT epilogue code *)
PROCEDURE ROTEpilogue(rD, size: LONGINT; signed: BOOLEAN);
VAR shifter: LONGINT; sm: SET;
BEGIN
	(*
		rD <- rD OR (rD LSR 16)
		rD <- rD OR (rD LSR 8)		(only for 8-bit values)
		rD <- rD OR (rD LSR 24)		(only for 8-bit values)
		rD <- rD LSL 24|16
		rD <- rD ASR|LSR 24|16	(depends on sign & size of rD)
	*)
	PCO.ORR(AL, PCO.A1ShiftImm, rD, rD, PCO.MakeA1RegSHIFTImm(rD, 16, PCO.LSR), {});
	IF (size = PCLIR.Int8) THEN
		PCO.ORR(AL, PCO.A1ShiftImm, rD, rD, PCO.MakeA1RegSHIFTImm(rD, 8, PCO.LSR), {});
		PCO.ORR(AL, PCO.A1ShiftImm, rD, rD, PCO.MakeA1RegSHIFTImm(rD, 24, PCO.LSR), {});
	END;
	shifter := GetROTShifter(size);
	(* PCO.ORR(AL, PCO.A1ShiftImm, rD, rD, PCO.MakeA1RegSHIFTImm(rD, shifter, PCO.LSR), {}); *)
	PCO.MOV(AL, PCO.A1ShiftImm, rD, PCO.MakeA1RegSHIFTImm(rD, shifter, PCO.Lsl), {});
	IF signed THEN sm := PCO.Asr ELSE sm := PCO.LSR END;
	PCO.MOV(AL, PCO.A1ShiftImm, rD, PCO.MakeA1RegSHIFTImm(rD, shifter, sm), {})
END ROTEpilogue;

(* FloatingPointDPI - I like long identifiers like 'FloatingPointDataProcessingInstruction', but Oberon does not ! *)
PROCEDURE FloatingPointDPI(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR rA, rB, rD: XRegister; info: Info; long: BOOLEAN; def: PCLIR.Instruction; rs, addrMode, address: SET; op: LONGINT;
BEGIN
	info := instr.info(Info); (* info.pos already set by DataProcessingInstruction/DivMod *)
	long := (instr.dstSize = PCLIR.Float64);

	(* instr.src1 [, instr.src2] contain(s) the (two) operand(s) *)
	ASSERT((FSrc1 IN info.flags) & ~(FSrc3 IN info.flags) & ~(FVal IN info.flags), INTERNALERROR);
	def := FindDefinition(code, instr.src1);
	rA.Low := def.info(Info).dst.Low; regs.FreeReg(rA.Low);
	IF long THEN rA.High := def.info(Info).dst.High; regs.FreeReg(rA.High) END;

	IF (FSrc2 IN info.flags) THEN
		def := FindDefinition(code, instr.src2);
		rB.Low := def.info(Info).dst.Low; regs.FreeReg(rB.Low);
		IF long THEN rB.High := def.info(Info).dst.High; regs.FreeReg(rB.High) END
	ELSE
		rB.Low := -1; rB.High := -1	(* monoadic instructions *)
	END;

	(* save registers in use *)
	rs := regs.GetUsedRegisterSet();
	IF (rs # {}) THEN PCO.STM(AL, PCO.A4DB, SP, rs, PCO.A4W) END;

	(* push operands (can't use STM because registered are not ordered) *)
	(* push high word first *)
	addrMode := PCO.A2WImmPreIdxd; address := PCO.MakeA2Immediate(addrMode, -4);
	IF long THEN PCO.STR(AL, addrMode, SP, rA.High, address) END;
	PCO.STR(AL, addrMode, SP, rA.Low, address);
	IF Diadic(instr.op) THEN
		IF long THEN PCO.STR(AL, addrMode, SP, rB.High, address) END;
		PCO.STR(AL, addrMode, SP, rB.Low, address)
	END;

	(* generate system call *)
	CASE instr.op OF
	| PCLIR.add: op := FAdd
	| PCLIR.sub: op := FSub
	| PCLIR.mul: op := FMul
	| PCLIR.div: op := FDiv
	| PCLIR.neg: op := FNeg
	| PCLIR.abs: op := FAbs
	ELSE
		op := instr.op; (* make sure we see the opcode in the trap window *)
		HALT(INTERNALERROR) (* undefined/unsupported floating point instruction *)
	END;
	IF long THEN op := op + FLongOffset END;

	SystemCall(op);

	(* allocate destination registers *)
	rD.High := -1;
	IF (info.dst.Low = -1) THEN
		IF regs.IsRegisterFree(RReturn) THEN regs.AllocSpecialReg(RReturn, NIL, instr.dstCount); rD.Low := RReturn
		ELSE
			IF long & regs.IsRegisterFree(RReturn2) THEN (* make sure we don't overwrite RResult2 *)
				regs.AllocSpecialReg(RReturn2, NIL, instr.dstCount); rD.High := RReturn2
			END;
			rD.Low := regs.AllocDestReg(instr.dstCount)
		END;
		info.dst.Low := rD.Low;

		IF long & (rD.High = -1) THEN rD.High := regs.AllocDestReg(instr.dstCount) END;
		info.dst.High := rD.High
	ELSE rD.Low := info.dst.Low; IF long THEN rD.High := info.dst.High END
	END;
	ASSERT((rD.Low # -1) & (~long OR (rD.High # -1)), INTERNALERROR);

	(* copy values if necessary *)
	IF (rD.Low # RReturn) THEN PCO.MOV(AL, PCO.A1Reg, rD.Low, PCO.MakeA1Register(RReturn), {}) END;
	IF long & (rD.High # RReturn2) THEN PCO.MOV(AL, PCO.A1Reg, rD.High, PCO.MakeA1Register(RReturn2), {}) END;

	(* restore registers in use *)
	IF (rs # {}) THEN PCO.LDM(AL, PCO.A4IA, SP, rs, PCO.A4W); regs.InvalidateAll END
END FloatingPointDPI;

PROCEDURE Move(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR reg: XRegister; rT, rT1, rA, rB, rC: LONGINT; dummy: BOOLEAN; addrMode, address: SET;
BEGIN
	PCO.Lock;
	instr.info(Info).pos := PCO.GetCodePos();
	(*
		CC <- rC > 0
	  *rT <- MEM[rA], rA <- rA+1 (if GT)
		MEM[rB] <- rT, rB <- rB+1 (if GT)
		rC <- rC-1 (if GT)
		BGT * (if GT)
	*)
	rT := regs.AllocReg(NIL, dummy, 1);
	reg := ResolveRegister(code, instr.src1); rA := reg.Low;
	reg := ResolveRegister(code, instr.src2); rB := reg.Low;
	reg := ResolveRegister(code, instr.src3); rC := reg.Low;
	(* PCLIR/Paco bugfix:
		according to PCLIR.Mod move is defined as
			move: move from MEM[R1..R1+R3-1] to MEM[R2..R2+R3-1], at end R1':=R1+R3 and R2':=R2+R3
		but if R1 or R2 is a special register (eg. SP/FP) the register must not be incremented, ie. R1':=R1 or R2':=R2
	*)
	IF (rA = SP) OR (rA = FP) THEN
		(*
			rT' <- rA
			(and subst rA = rT)
		*)
		rT1 := regs.AllocReg(NIL, dummy, 1);
		PCO.MOV(AL, PCO.A1Reg, rT1, PCO.MakeA1Register(rA), {});
		rA := rT1
	END;
	IF (rB = SP) OR (rB = FP) THEN
		(*
			rT'' <- rB
			(and subst rB = rT'')
		*)
		rT1 := regs.AllocReg(NIL, dummy, 1);
		PCO.MOV(AL, PCO.A1Reg, rT1, PCO.MakeA1Register(rB), {});
		rB := rT1
	END;
	addrMode := PCO.A2BImmPostIdxd;
	address := PCO.MakeA2Immediate(addrMode, 1);
	PCO.CMP(AL, PCO.A1Imm, rC, PCO.A1Immediate0);
	PCO.LDR(PCO.GT, addrMode, rT, rA, address);
	PCO.STR(PCO.GT, addrMode, rB, rT, address);
	PCO.SUB(PCO.GT, PCO.A1Imm, rC, rC, PCO.A1Immediate1, PCO.Sflag);
	PCO.B(PCO.GT, -5);
	regs.SetRegisterContent(rT, NIL); regs.SetRegisterContent(rA, NIL);
	regs.SetRegisterContent(rB, NIL); regs.SetRegisterContent(rC, RA.NewIntConst(0));
	regs.FreeReg(rT); regs.FreeReg(rA); regs.FreeReg(rB); regs.FreeReg(rC); (* !!! check !!! *)
	PCO.Unlock
END Move;

PROCEDURE Inline(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; i, dummy: LONGINT; inline: PCLIR.AsmInline; block: PCLIR.AsmBlock;
	fixup: PCLIR.AsmFixup; adr: PCM.Attribute; opcode: SET; call: BOOLEAN;
BEGIN
	PCO.Lock;
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	inline := instr.adr(PCLIR.AsmInline);
	block := inline.code;
	WHILE (block # NIL) DO
		FOR i := 0 TO block.len-1 DO PCO.PutChar(block.code[i]) END;
		block := block.next
	END;
	(* fixup addresses of global variables and procedure calls *)
	fixup := inline.fixup;
	WHILE (fixup # NIL) DO
		adr := fixup.adr;
		IF (adr IS PCBT.GlobalVariable) THEN
			WITH adr: PCBT.GlobalVariable DO
				(* 08.05.02: interface changed again
				IF (adr.next = NIL) THEN (* not in fixup list yet *)
					adr.next := PCBT.context.varEntry; PCBT.context.varEntry := adr
				END;
				NEW(l); l.offset := (info.pos + fixup.offset) DIV 4; l.next := adr.link; adr.link := l
				*)
				PCBT.context.UseVariable(adr, (info.pos + fixup.offset) DIV 4)
			END
		ELSIF (adr IS PCBT.Procedure) THEN
			WITH adr: PCBT.Procedure DO
				(* find out if it's a call or a jump *)
				opcode := PCO.GetInstruction(info.pos + fixup.offset) * PCO.BMask;
				IF (opcode = PCO.opB) THEN call := FALSE
				ELSIF (opcode = PCO.opBL) THEN call := TRUE
				ELSE HALT(INTERNALERROR)
				END;

				IF (adr.codeoffset = 0) THEN (* address unknown, will be patched later *)
					IF call THEN dummy := PCO.FixCall(info.pos + fixup.offset, adr.fixlist)
					ELSE PCO.FixJump(info.pos + fixup.offset, adr.fixlist)
					END;
					ASSERT((info.pos + fixup.offset) MOD 4 = 0);
					adr.fixlist := (info.pos + fixup.offset) DIV 4
				ELSE (* address already known *)
					IF call THEN dummy := PCO.FixCall(info.pos + fixup.offset, (adr.codeoffset*4 - (info.pos + fixup.offset) - 8) DIV 4)
					ELSE PCO.FixJump(info.pos + fixup.offset, (adr.codeoffset*4 - (info.pos + fixup.offset) - 8) DIV 4)
					END
				END
			END
		END;
		fixup := fixup.next
	END;
	IF (PCO.GetCodePos() MOD 4 # 0) THEN HALT(ErrInlineNotAligned) END;
	PCO.Unlock;
	regs.InvalidateAll
END Inline;

PROCEDURE Case(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; reg: XRegister; rBase, rIdx, rT, min, max, range, pos, table, i: LONGINT; imm: SET;
	adr: PCBT.GlobalVariable; dummy: BOOLEAN; const: PCBT.ConstArray;
BEGIN
	PCO.Lock;
	info := instr.info(Info); info.pos := PCO.GetCodePos();
	(*
		rIdx <- rIdx - min
		CC <- min <= rIdx <= max ?
		no: b CaseElse/Trap
		PC <-  + rIdx SHL 2
		no: b CaseElse/Trap
	*)

	min := instr.src2; max := instr.src3; range := max-min+1;

	(* allocate case table *)
	table := PCBT.context.constsize; info.dst.Low := table;
	INC(PCBT.context.constsize, SHORT(range*4));
	IF (PCBT.context.constsize > LEN(PCBT.context.const^)) THEN	(* increase const-table *)
		NEW(const, PCBT.context.constsize);
		SYSTEM.MOVE(ADDRESSOF(PCBT.context.const[0]), ADDRESSOF(const[0]), LEN(PCBT.context.const));
		PCBT.context.const := const
	END;

	pos := PCBT.context.constsize-4;
(*
	(* add to fixup list *)
	last := PCBT.context.syscalls[PCBT.casetable]*4;
	PCBT.context.syscalls[PCBT.casetable] := table DIV 4;

	(* fill table *)
	WHILE (pos >= table) DO
		PCBT.context.const[pos+2] := CHR(last DIV 4);
		PCBT.context.const[pos+3] := CHR(last DIV 400H);
		last := pos; DEC(pos, 4)
	END;
*)
(* 08.05.02: interface changed
	FOR i := table TO pos BY 4 DO PCBT.AddFixup(PCBT.context.syscalls[PCBT.casetable], i DIV 4) END;
*)
	FOR i := table TO pos BY 4 DO PCBT.context.UseSyscall(PCBT.casetable, i DIV 4) END;


	(* rIdx := rIdx - min *)
	reg := ResolveRegister(code, instr.src1); rIdx := reg.Low;
	IF (min # 0) THEN
		IF PCO.MakeA1Immediate(ABS(min), imm) THEN
			IF (min < 0) THEN PCO.ADD(AL, PCO.A1Imm, rIdx, rIdx, imm, {})
			ELSE PCO.SUB(AL, PCO.A1Imm, rIdx, rIdx, imm, {})
			END
		ELSE
			rT := LoadConstant(PCO.GetCodePos(), -1, ABS(min), 1);
			IF (min < 0) THEN PCO.ADD(AL, PCO.A2Reg, rIdx, rIdx, PCO.MakeA2Register(rT), {})
			ELSE PCO.SUB(AL, PCO.A2Reg, rIdx, rIdx, PCO.MakeA1Register(rT), {})
			END;
			regs.FreeReg(rT)
		END
	END;

	(* index check: 0 <= rIdx < range *)
	IF PCO.MakeA1Immediate(range, imm) THEN
		PCO.CMP(AL, PCO.A1Imm, rIdx, imm)
	ELSE
		rT := LoadConstant(PCO.GetCodePos(), -1, range, 1);
		PCO.CMP(AL, PCO.A1Reg, rIdx, PCO.MakeA1Register(rT));
		regs.FreeReg(rT)
	END;

	(* not in range: jump to else (will be fixed later) *)
	info.dst.High := PCO.GetCodePos();
	PCO.B(PCO.HS, -1);

	(* generate a new 'variable' for the case table *)
	NEW(adr, PCBT.context); adr.offset := table;

	(* load address of case label into PC *)
	rBase := regs.AllocReg(NIL, dummy, 1);
	LoadAddress(rBase, adr);
	PCO.LDR(AL, PCO.A2WRegOffset + PCO.IdxAdd, PC, rBase, PCO.MakeA2ScaledRegister(rIdx, PCO.Lsl, 2));

	regs.FreeReg(rIdx); regs.FreeReg(rBase); regs.SetRegisterContent(rIdx, NIL); regs.SetRegisterContent(rBase, NIL);
	PCO.Unlock
END Case;

PROCEDURE CaseLabel(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR case: PCLIR.Instruction; PC, offset: LONGINT;
BEGIN
	PC := PCO.GetCodePos(); instr.info(Info).pos := PC;
	case := FindDefinition(code, instr.src1);
	(* address of case table is saved in case.info.dst.Low *)
	offset := case.info(Info).dst.Low + (instr.val - case.src2) * PCO.InstructionSize;
	PCBT.context.const[offset+0] := CHR(PC DIV 4);
	PCBT.context.const[offset+1] := CHR(PC DIV 400H);
	regs.InvalidateAll
END CaseLabel;

PROCEDURE CaseElse(code: PCLIR.Code; VAR instr: PCLIR.Instruction; pc: LONGINT);
VAR info: Info; case: PCLIR.Instruction; adr, i, PC, table: LONGINT;
BEGIN
	PC := PCO.GetCodePos(); info := instr.info(Info); info.pos := PC;
	case := FindDefinition(code, instr.src1);
	table := case.info(Info).dst.Low;

	adr := case.info(Info).dst.High; (* address of branch instruction to ELSE/TRAP *)
	PCO.FixJump(adr, (info.pos - (adr + 8)) DIV 4); (* info.pos is an absolute address, but we need a relative one *)
	(* fix empty case table entries *)
	FOR i := 0 TO case.src3 - case.src2 DO
		IF (PCBT.context.const[table] = 0X) & (PCBT.context.const[table+1] = 0X) THEN
			PCBT.context.const[table+0] := CHR(PC DIV 4);
			PCBT.context.const[table+1] := CHR(PC DIV 400H)
		END;
		INC(table, 4)
	END;
	regs.InvalidateAll
END CaseElse;

PROCEDURE Optimize(code: PCLIR.Code);
TYPE Stack = POINTER TO RECORD
			pc: LONGINT;
			next: Stack;
		END;
VAR i, d, d2, s, t: PCLIR.Piece; info: Info;
	ip, dp, dp2, sp, tmp, val: LONGINT;
	pc: LONGINT;
	op: PCLIR.Opcode;
	ok, imm: BOOLEAN;
	stack, lrStack: Stack;
	type: LONGINT;

	PROCEDURE IncreaseUse(p: PCLIR.Piece; pc: LONGINT);
	VAR usePC: LONGINT; usePiece: PCLIR.Piece;
	BEGIN
		IF (p.instr[pc].suppress) THEN
			(* increase use of registers used by this (now no longer suppressed) instruction *)
			usePC := p.instr[pc].src1;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IncreaseUse(usePiece, usePC)
			END;
			usePC := p.instr[pc].src2;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IncreaseUse(usePiece, usePC)
			END;
			usePC := p.instr[pc].src3;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IncreaseUse(usePiece, usePC)
			END
		END;
		INC(p.instr[pc].dstCount); p.instr[pc].suppress := FALSE
	END IncreaseUse;

	PROCEDURE DecreaseUse(p: PCLIR.Piece; pc: LONGINT);
	VAR usePC: LONGINT; usePiece: PCLIR.Piece;
	BEGIN
		ASSERT(p.instr[pc].dstCount > 0, INTERNALERROR);
		DEC(p.instr[pc].dstCount);
		p.instr[pc].suppress := p.instr[pc].dstCount = 0;
		IF (p.instr[pc].suppress) THEN
			(* decrease use of registers used by this (now suppressed) instruction *)
			usePC := p.instr[pc].src1;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IF (usePiece.instr[usePC].dstCount > 0) THEN
					DecreaseUse(usePiece, usePC)
				END
			END;
			usePC := p.instr[pc].src2;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IF (usePiece.instr[usePC].dstCount > 0) THEN
					DecreaseUse(usePiece, usePC)
				END
			END;
			usePC := p.instr[pc].src3;
			IF (usePC >= 0) THEN
				code.GetPiece(usePC, usePiece);
				IF (usePiece.instr[usePC].dstCount > 0) THEN
					DecreaseUse(usePiece, usePC)
				END
			END
		END
	END DecreaseUse;

	PROCEDURE IsLoadC(VAR i: PCLIR.Instruction): BOOLEAN;
	BEGIN RETURN (i.op = PCLIR.loadc) & (i.adr = NIL)
	END IsLoadC;

	PROCEDURE IsShift(op: PCLIR.Opcode): BOOLEAN;
	BEGIN RETURN (op = PCLIR.bsh) OR (op = PCLIR.ash) OR (op = PCLIR.rot)
	END IsShift;

	PROCEDURE Commutative(op: PCLIR.Opcode): BOOLEAN;
	BEGIN RETURN PCLIR.commutative IN PCLIR.InstructionSet[i.instr[ip].op].flags
	END Commutative;

	PROCEDURE IsAddSub(op: PCLIR.Opcode): BOOLEAN;
	BEGIN RETURN (op = PCLIR.add) OR (op = PCLIR.sub)
	END IsAddSub;

	PROCEDURE IsImmediate(info: Info): BOOLEAN;
	BEGIN RETURN ~(FSrc2 IN info.flags) & (FVal IN info.flags)
	END IsImmediate;

(*
	PROCEDURE IsCondition(op: PCLIR.Opcode): BOOLEAN;
	BEGIN (* {wp: opcodes are sequentially numerated (PCLIR.je...PCLIR.jnf & PCLIR.sete...PCLIR.setnf)} *)
		RETURN ((op >= PCLIR.je) & (op <= PCLIR.jnf)) OR
			(op = PCLIR.tae) OR (op = PCLIR.tne) OR
			((op >= PCLIR.sete) & (op <= PCLIR.setnf));
	END IsCondition;
*)

	PROCEDURE LoadStoreOffset(VAR i: PCLIR.Instruction): LONGINT;
	BEGIN
		IF (i.dstSize = PCLIR.Int16) THEN RETURN 100H	(* halfword accesses have a 8bit immediate *)
		ELSE RETURN 1000H	(* word/byte accesses have a 12bit immediate *)
		END
	END LoadStoreOffset;

	(* Unchanged - returns TRUE if a register is not changed between the definition and the use.
			only hardware registers can be changed, of course.
	*)
	PROCEDURE Unchanged(register, definition, use: LONGINT): BOOLEAN;
	VAR pos, pc: LONGINT; piece: PCLIR.Piece; changed: BOOLEAN;
	BEGIN
		changed := FALSE;
		(* the stack pointer can only be changed by loadsp, push and pop instructions *)
		IF (register = PCLIR.SP) THEN
			pos := definition + 1;
			WHILE (pos < use) & ~changed DO
				pc := pos;
				code.GetPiece(pc, piece);
				op := piece.instr[pc].op;
				changed := (op = PCLIR.loadsp) OR (op = PCLIR.push) OR (op = PCLIR.pop);
				INC(pos)
			END
		END;
		RETURN ~changed
	END Unchanged;

BEGIN
	IF Trace THEN
		KernelLog.Enter; KernelLog.String("Start of Optimize: "); KernelLog.Ln;
	END;
	(* first pass *)
	pc := 0;
	WHILE (pc < code.pc) DO
		ip := pc; code.GetPiece(ip, i); op := i.instr[ip].op;
		IF (i.instr[ip].info(Info) = NIL) THEN
			KernelLog.Enter;
			KernelLog.String("ERROR: instruction has not a valid info field. PC = "); KernelLog.Int(pc, 0);
			KernelLog.Exit;
			HALT(INTERNALERROR)
		END;
		info := i.instr[ip].info(Info);

		(* set fields used by this instruction *)
		CASE PCLIR.InstructionSet[op].format OF
		| PCLIR.form00: (* nothing *)
		| PCLIR.form0C: info.flags := info.flags + { FVal }
		| PCLIR.form01: info.flags := info.flags + { FSrc1 }
		| PCLIR.form10: info.flags := info.flags + { FDst }
		| PCLIR.form1C: info.flags := info.flags + { FDst, FVal } (* TODO: what is this thing with the address ??? *)
		| PCLIR.form11: info.flags := info.flags + { FDst, FSrc1 }
		| PCLIR.form1M:
			IF (i.instr[ip].src1 = PCLIR.Absolute) THEN info.flags := info.flags + { FSrc1, FVal, FAdr }
			ELSE info.flags := info.flags + { FSrc1, FVal }
			END
		| PCLIR.formM1: info.flags := info.flags + { FSrc1, FSrc2, FVal }
		| PCLIR.form02: info.flags := info.flags + { FSrc1, FSrc2 }
		| PCLIR.form12: info.flags := info.flags + { FDst, FSrc1, FSrc2 }
		| PCLIR.form02C: info.flags := info.flags + { FSrc1, FSrc2, FVal }
		| PCLIR.form03: info.flags := info.flags + { FSrc1, FSrc2, FSrc3 }
		| PCLIR.formXX: info.flags := info.flags + { FSrc1, FSrc2, FSrc3 }
		END;

		(* optimize *)
		CASE op OF
		| PCLIR.ret, PCLIR.ret2, PCLIR.not, PCLIR.neg, PCLIR.abs:
			dp := i.instr[ip].src1; IF (dp > 0) THEN code.GetPiece(dp, d) ELSE d := NIL END;
			IF (d # NIL) & IsLoadC(d.instr[dp]) & (d.instr[dp].val >= 0) & (d.instr[dp].val < 100H) THEN
				DecreaseUse(d, dp);
				i.instr[ip].src1 := PCLIR.none;
				i.instr[ip].val := d.instr[dp].val;
				info.flags := info.flags - { FSrc1 } + { FVal };
				IF Trace THEN
					KernelLog.Int(pc, 5); KernelLog.String(": immediate "); KernelLog.String(PCLIR.InstructionSet[op].name);
					KernelLog.String(" generated"); KernelLog.Ln
				END
			END

		| PCLIR.setf, PCLIR.setnf: (* temporary sanity check: preceding instruction must be btt or test *)
			(*
			dp := pc-1; code.GetPiece(dp, d); (* dp can't be < 0, since setf/setnf cannot be the first instruction of a procedure *)
			ASSERT((d.instr[dp].op = PCLIR.btt) OR (d.instr[dp].op = PCLIR.test), INTERNALERROR)
			*)

		| PCLIR.jmp:
			dp := i.instr[ip].val; code.GetPiece(dp, d);
			d.instr[dp].info(Info).target := TRUE;

		| PCLIR.je..PCLIR.jnf:
			type := InstructionType(code, i.instr[ip]);
			dp := i.instr[ip].val; code.GetPiece(dp, d);
			d.instr[dp].info(Info).target := TRUE;

			IF (type IN RegularIntSize) THEN


			ELSIF (type IN PCLIR.FloatSize) THEN

			ELSE (* HUGEINT *)

			END

		| (*PCLIR.cmp, PCLIR.test, *)PCLIR.sub, PCLIR.add, PCLIR.and, PCLIR.or, PCLIR.xor, PCLIR.bsh, PCLIR.ash, PCLIR.rot:
			type := InstructionType(code, i.instr[ip]);

			IF (type IN RegularIntSize) THEN
				dp := i.instr[ip].src1; IF (dp >= 0) THEN code.GetPiece(dp, d) ELSE d := NIL END;
				dp2 := i.instr[ip].src2; IF (dp2 >= 0) THEN code.GetPiece(dp2, d2) ELSE d2 := NIL END;

				(* swap src1,src2 if src1 is immediate value and src2 is not *)
				IF (d # NIL) & (d2 # NIL) & IsLoadC(d.instr[dp]) & ~IsLoadC(d2.instr[dp2]) & Commutative(op) THEN
					(*
						c1 := loadc value
						c2 := register
						res := op c1, c2
						=>
						c1 := loadc value
						c2 := register
						res := op c2, c1
					*)
					tmp := i.instr[ip].src1; i.instr[ip].src1 := i.instr[ip].src2; i.instr[ip].src2 := tmp;
					tmp := dp; dp := dp2; dp2 := tmp;
					t := d; d := d2; d2 := t;
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": src1 is immediate, swap src1-src2"); KernelLog.Ln
					END
				END;

				(* use positive immediate values if possible *)
				IF IsAddSub(op) & (d2 # NIL) & IsLoadC(d2.instr[dp2]) & (d2.instr[dp2].val < 0) THEN
					(*
						c := loadc value (value < 0)
						res := add/sub reg, c
						=>
						c := loadc -value
						res := sub/add reg, c
					*)
					d2.instr[dp2].val := -d2.instr[dp2].val;
					IF (op = PCLIR.add) THEN i.instr[ip].op := PCLIR.sub
					ELSE i.instr[ip].op := PCLIR.add
					END;
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": use negative immediate / swap add-sub"); KernelLog.Ln
					END
				END;

				(* simple use of immediate value *)
				IF (d2 # NIL) & IsLoadC(d2.instr[dp2]) & (((d2.instr[dp2].val >= 0) & (d2.instr[dp2].val < 100H)) OR IsShift(op)) THEN
					(*
						c := loadc value
						res := op reg, c
						=>
						res := op reg, value
					*)
					DecreaseUse(d2, dp2);
					i.instr[ip].src2 := PCLIR.none;
					i.instr[ip].val := d2.instr[dp2].val;
					info.flags := info.flags - { FSrc2 } + { FVal };
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": immediate "); KernelLog.String(PCLIR.InstructionSet[op].name);
						KernelLog.String(" generated"); KernelLog.Ln
					END
				END;

				(* reverse subtract *)
				IF (op = PCLIR.sub) & (d # NIL) & IsLoadC(d.instr[dp]) & ~IsLoadC(d2.instr[dp2]) &
					(d.instr[dp].val >= 0) & (d.instr[dp].val < 100H) THEN
					(*
						c := loadc value
						res := sub c, reg
						=>
						res := sub value, reg
					*)
					DecreaseUse(d, dp);
					i.instr[ip].src1 := i.instr[ip].src2;
					i.instr[ip].src2 := PCLIR.none;
					i.instr[ip].val := d.instr[dp].val;
					info.xop := rsub;
					info.flags := info.flags - { FSrc2 } + { FVal };
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": reverse subtract ");
						KernelLog.String(PCLIR.InstructionSet[op].name); KernelLog.String(" generated"); KernelLog.Ln
					END
				END;

				(* swap src1, src2 if src1 is shift and src2 is not and we don't already have an immediate value *)
				IF (d # NIL) & (d2 # NIL) & IsShift(d.instr[dp].op) & ~IsShift(d2.instr[dp2].op) & Commutative(op) & ~(FVal IN info.flags) THEN
					(*
						c1 := shift
						c2 := ~shift
						res := op c1, c2
						=>
						c1 := shift
						c2 := ~shift
						res := op, c2, c1
					*)
					tmp := i.instr[ip].src1; i.instr[ip].src1 := i.instr[ip].src2; i.instr[ip].src2 := tmp;
					tmp := dp; dp := dp2; dp2 := tmp;
					t := d; d := d2; d2 := t;
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": src1 is shift, swap src1-src2 "); KernelLog.Ln
					END
				END;

				(* try to 'inline' shifts *)
				IF ~(FVal IN info.flags) & (d2 # NIL) & IsShift(d2.instr[dp2].op) THEN
					IF (FVal IN d2.instr[dp2].info(Info).flags) (*OR (op # PCLIR.cmp)*) THEN (* must not be a cmp instruction if it's a register shift ! *)
																																(* Register shifts use condition codes to determine *)
																																(* if it's a shift left or right (c.f. DataProcessingInstruction) *)
						DecreaseUse(d2, dp2);
						i.instr[ip].src2 := d2.instr[dp2].src2;
						sp := d2.instr[dp2].src2; code.GetPiece(sp, s); IncreaseUse(s, sp);
						info.xop := d2.instr[dp2].op;

						IF (FVal IN d2.instr[dp2].info(Info).flags) THEN (* it's an immediate shift *)
							(*
								offset := shift index, value
								element := add base, offset
								=>
								add base, index shift value
							*)
							i.instr[ip].val := d2.instr[dp2].val;
							info.flags := info.flags + { FSrc2, FVal };
							IF Trace THEN
								KernelLog.Int(pc, 5); KernelLog.String(": add base, index ash immediate generated"); KernelLog.Ln
							END
						ELSE (* it's a register shift. Must not be a CMP instruction, but this is already checked above *)
							(*
								offset := shift index, register
								element := add base, offset
								=>
								add base, index shift register
							*)
							i.instr[ip].src3 := d2.instr[dp2].src3;
							sp := d2.instr[dp2].src3; code.GetPiece(sp, s); IncreaseUse(s, sp);
							info.flags := info.flags + { FSrc2, FSrc3 };
							IF Trace THEN
								KernelLog.Int(pc, 5); KernelLog.String(": add base, index ash register generated"); KernelLog.Ln
							END
						END
					END
				END;

				IF IsShift(op) THEN (* shifts must have xop set, base reg must be in src2, shifter must be in src3/value *)
					info.xop := op;
					IF Trace THEN
						KernelLog.Int(pc, 5); KernelLog.String(": shift opcode copied to xop; base register moved to src2")
					END;
					IF (FSrc2 IN info.flags) THEN
						i.instr[ip].src3 := i.instr[ip].src2;
						info.flags := info.flags - { FSrc2 } + { FSrc3 };
						IF Trace THEN KernelLog.String("; shift register moved to src3") END
					END;
					i.instr[ip].src2 := i.instr[ip].src1; i.instr[ip].src1 := PCLIR.none;
					info.flags := info.flags - { FSrc1 } + { FSrc2 };
					IF Trace THEN KernelLog.Ln END
				END
			ELSIF (type IN PCLIR.FloatSize) THEN
				(*
				& (op = PCLIR.cmp) THEN
				(* we do not have a floating point compare thus we have to compare when we know WHAT to compare *)
				(*
					cmp float, float
					jCC somewhere
					=>
					jCC float, float, somewhere
				*)
				dp := pc+1; code.GetPiece(dp, d);
				ASSERT(IsCondition(d.instr[dp].op) & (FSrc1 IN info.flags) & (FSrc2 IN info.flags), INTERNALERROR);
				i.instr[ip].suppress := TRUE;
				d.instr[dp].src1 := i.instr[ip].src1;
				d.instr[dp].src2 := i.instr[ip].src2;
				d.instr[dp].info(Info).xop := floatCC;
				d.instr[dp].info(Info).flags := d.instr[dp].info(Info).flags + { FSrc1, FSrc2 }
				*)
			ELSE (* no optimizations for HUGEINTs so far *)
			END

		| PCLIR.load, PCLIR.store:
			REPEAT (* repeat this step until we cannot inline any more *)
				dp := i.instr[ip].src1; IF (dp >= 0) THEN code.GetPiece(dp, d) ELSE d := NIL END;

				(* d: base register *)
				IF (d # NIL) & IsAddSub(d.instr[dp].op) THEN (* base register is computed by add/sub *)
					ok := TRUE; imm := FALSE;
					IF TTrace THEN KernelLog.Int(pc, 5); KernelLog.String(": load/store: ") END;

					IF IsImmediate(d.instr[dp].info(Info)) THEN val := d.instr[dp].val; imm := TRUE; (* it was an immediate add/sub *)
						IF TTrace THEN KernelLog.String("immediate offset ("); KernelLog.Int(val, 0); KernelLog.String("): ") END
					ELSE (* not an immediate, but maybe a constant that didn't fit into the immediate value *)
						dp2 := d.instr[dp].src2; IF (dp2 >= 0) THEN code.GetPiece(dp2, d2) ELSE d2 := NIL END;

						(* d2: second register of add/sub of definition of base register (d) *)

						IF (d2 # NIL) & IsLoadC(d2.instr[dp2]) & ~(FSrc3 IN d2.instr[dp2].info(Info).flags) THEN (* ignore register shifts (FSrc3 set) *)
							val := d2.instr[dp2].val;
							IF TTrace THEN KernelLog.String("indirect immediate offset ("); KernelLog.Int(val, 0); KernelLog.String(")") END;
							IF (FVal IN d.instr[dp].info(Info).flags) THEN (* d is add/sub with immediate shift *)
								IF TTrace THEN KernelLog.String("with immediate shift") END;
								CASE d.instr[dp].info(Info).xop OF
								| PCLIR.ash: val := ASH(val, d.instr[dp].val)
								| PCLIR.bsh: val := LSH(val, d.instr[dp].val)
								ELSE ok := FALSE
								END
							END;
							IF TTrace THEN KernelLog.String(": ") END
						ELSE ok := FALSE
						END
					END;

					IF (d.instr[dp].op = PCLIR.sub) THEN val := -val END;

					IF ok & (ABS(val + i.instr[ip].val) < LoadStoreOffset(i.instr[ip])) & Unchanged(d.instr[dp].src1, i.instr[ip].src1, pc) THEN
						DecreaseUse(d, dp);
						i.instr[ip].src1 := d.instr[dp].src1;
						i.instr[ip].val := val + i.instr[ip].val;

						(* increase use of new base register *)
						dp := d.instr[dp].src1;
						IF (dp >= 0) THEN
							code.GetPiece(dp, d);
							IncreaseUse(d, dp)
						ELSE (* hardware register (SP, FP) *)
						END;
						IF TTrace THEN KernelLog.String("offset  ="); KernelLog.Int(i.instr[ip].val, 0); KernelLog.Ln END
					ELSE ok := FALSE
					END
				ELSE ok := FALSE
				END
			UNTIL ~ok;

		| PCLIR.saveregs: (* push pc of saveregs on stack *)
			NEW(stack); stack.pc := pc; stack.next := lrStack; lrStack := stack

		| PCLIR.loadregs: (* pc of corresponding saveregs is on top of stack *)
			info.dst.Low := lrStack.pc; lrStack := lrStack.next
		(*
		| PCLIR.enter:
			dp := pc+1; code.GetPiece(dp, d);
			IF (d.instr[dp].op = PCLIR.exit) THEN (* empty procedure *)
				i.instr[ip].info(Info).xop := fastenter;
				d.instr[dp].info(Info).xop := fastexit
			END;
		*)
		| PCLIR.inline:
			dp := pc-1; code.GetPiece(dp, d);
			dp2 := pc+1; code.GetPiece(dp2, d2);
			IF (d # NIL) & (d2 # NIL) & (d.instr[dp].op = PCLIR.enter) & (d2.instr[dp2].op = PCLIR.exit) & (i.instr[ip].adr IS PCAARM.AsmInline) THEN
				(* it's an assembler procedure (not inlined) *)
				IF ~i.instr[ip].adr(PCAARM.AsmInline).paf THEN (* no PAF *)
					d.instr[dp].info(Info).xop := nopaf;
					d2.instr[dp2].info(Info).xop := nopaf
				END
			END
		ELSE (* nothing *)
		END;
		INC(pc)
	END;

	IF Trace THEN
		KernelLog.String("End of Optimize"); KernelLog.Exit
	END
END Optimize;
(*  Debug
(** DumpCode (Debug) - TraverseProc, dumps whole code to global writer W *)

PROCEDURE DumpCode*(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT;  context: ANY);
VAR  op: PCLIR.Opcode;  info: Info; format: SHORTINT; flags: SET;

	PROCEDURE Reg(r: LONGINT);
	BEGIN
		IF r = PCLIR.FP THEN
			Texts.WriteString(PCLIR.W, "FP")
		ELSIF r = PCLIR.SP THEN
			Texts.WriteString(PCLIR.W, "SP")
		ELSIF r <= PCLIR.HwReg THEN
			Texts.WriteString(PCLIR.W, "HW");
			Texts.WriteInt(PCLIR.W, PCLIR.HwReg-r, 0)
		ELSE
			IF PCLIR.Signed(code, r) THEN Texts.Write(PCLIR.W, "S") END;
			Texts.Write(PCLIR.W, PCLIR.RegName[PCLIR.SizeOf(code, r)]);
			Texts.WriteInt(PCLIR.W, r, 0)
		END
	END Reg;

	PROCEDURE Indirect(VAR instr: PCLIR.Instruction);
	VAR offset: LONGINT;
	BEGIN
		IF instr.src1 <= PCLIR.HwReg THEN
			Reg(instr.src1)
		ELSIF instr.src1 = PCLIR.Absolute THEN
			offset := instr.adr(PCBT.GlobalVariable).offset;
			IF (instr.val # offset) THEN offset := offset + (instr.val - offset) END;
			Texts.Write(PCLIR.W, "@"); Texts.WriteInt(PCLIR.W, offset, 0)
		ELSE
			Texts.WriteInt(PCLIR.W, instr.val, 0); Texts.Write(PCLIR.W, "[");
			Reg(instr.src1); Texts.Write(PCLIR.W, "]")
		END
	END Indirect;

	PROCEDURE CaseOpd(src: PCLIR.Register;  min, max: LONGINT);
	BEGIN
		Reg(src); Texts.WriteString(PCLIR.W, "  {"); Texts.WriteInt(PCLIR.W, min, 0);
		Texts.WriteString(PCLIR.W, ", "); Texts.WriteInt(PCLIR.W, max, 0);  Texts.Write(PCLIR.W, "}")
	END CaseOpd;

	PROCEDURE CaseLineOpd(base, val: LONGINT);
	BEGIN
		Texts.WriteInt(PCLIR.W, val, 0); Texts.WriteString(PCLIR.W, "  {");
		Texts.WriteInt(PCLIR.W, base, 0); Texts.WriteString(PCLIR.W, "}")
	END CaseLineOpd;

	PROCEDURE CaseElseOpd(base: LONGINT);
	BEGIN Texts.WriteString(PCLIR.W, "  {"); Texts.WriteInt(PCLIR.W, base, 0); Texts.WriteString(PCLIR.W, "}")
	END CaseElseOpd;

BEGIN
	op := instr.op;  info := instr.info(Info); format := PCLIR.InstructionSet[op].format;
	IF instr.suppress THEN Texts.WriteString(PCLIR.W, "suppr") ELSE Texts.WriteInt(PCLIR.W, pc, 5) END;
	Texts.Write(PCLIR.W, 9X);
	IF (format IN PCLIR.form1X) OR (op = PCLIR.load) THEN
		Texts.WriteInt(PCLIR.W, instr.dstCount, 3);
	ELSE
		Texts.WriteString(PCLIR.W, "   ")
	END;
	Texts.Write(PCLIR.W, 9X);
	Texts.WriteString(PCLIR.W, PCLIR.InstructionSet[op].name); Texts.Write(PCLIR.W, 9X);

	flags := info.flags;

	CASE format OF
	| PCLIR.form00:
	| PCLIR.form0C:
			IF (info.xop = floatCC) THEN
				Texts.WriteString(PCLIR.W, "cmp: ");
				Texts.WriteInt(PCLIR.W, instr.src1, 0);
				Texts.WriteString(PCLIR.W, ", ");
				Texts.WriteInt(PCLIR.W, instr.src2, 0);
				Texts.WriteString(PCLIR.W, " ? -> ")
			END;
			Texts.WriteInt(PCLIR.W, instr.val, 0);
			IF instr.adr # NIL THEN  Texts.WriteString(PCLIR.W, " + @")  END
	| PCLIR.form01:
			Reg(instr.src1)
	| PCLIR.form10:
			Reg(pc)
	| PCLIR.form1C:
			Reg(pc); Texts.WriteString(PCLIR.W, ", "); Texts.WriteInt(PCLIR.W, instr.val, 0)
	| PCLIR.form1M:
			Reg(pc);  Texts.WriteString(PCLIR.W, ", ");  Indirect(instr)
	| PCLIR.form11:
			Reg(pc); Texts.WriteString(PCLIR.W, ", "); Reg(instr.src1)
	| PCLIR.formM1:
			Indirect(instr);  Texts.WriteString(PCLIR.W, ", ");  Reg(instr.src2)
	| PCLIR.form02:
			Reg(instr.src1); Texts.WriteString(PCLIR.W, ", ");
			IF (FSrc2 IN flags) THEN Reg(instr.src2)
			ELSIF (FVal IN flags) THEN Texts.WriteInt(PCLIR.W, instr.val, 0)
			ELSE Texts.WriteString(PCLIR.W, "huga ?")
			END;
	| PCLIR.form12:
			Reg(pc); Texts.WriteString(PCLIR.W, ", "); Reg(instr.src1);
			Texts.WriteString(PCLIR.W, ", ");
			IF (FSrc2 IN flags) THEN
				Reg(instr.src2);
				IF (FSrc3 IN flags) THEN Texts.WriteString(PCLIR.W, ", "); Reg(instr.src3) END;
				IF (FVal IN flags) THEN Texts.WriteString(PCLIR.W, ", "); Texts.WriteInt(PCLIR.W, instr.val, 0) END
			ELSIF (FVal IN flags) THEN Texts.WriteInt(PCLIR.W, instr.val, 0)
			ELSE Texts.WriteString(PCLIR.W, "huga ?")
			END
	| PCLIR.form02C:
			Reg(instr.src1); Texts.WriteString(PCLIR.W, ", "); Reg(instr.src2); Texts.WriteString(PCLIR.W, ", ");
			Texts.WriteInt(PCLIR.W, instr.val, 0)
	| PCLIR.form03:
			Reg(instr.src1); Texts.WriteString(PCLIR.W, ", "); Reg(instr.src2);
			Texts.WriteString(PCLIR.W, ", "); Reg(instr.src3)
	| PCLIR.formXX:
		CASE op OF
		| PCLIR.enter, PCLIR.exit:
				Texts.WriteString(PCLIR.W, "calling convention: ");
				IF (instr.val = PCBT.OberonCC) THEN Texts.WriteString(PCLIR.W, "Oberon");
					IF (instr.adr # NIL) & (instr.adr IS PCBT.Procedure) THEN
						Texts.WriteString(PCLIR.W, "; size of locals: "); Texts.WriteInt(PCLIR.W, instr.adr(PCBT.Procedure).locsize, 0)
					END
				ELSE Texts.WriteString(PCLIR.W, "Passivate")
				END
		| PCLIR.inline: Texts.WriteString(PCLIR.W, ", codesize = "); Texts.WriteInt(PCLIR.W, instr.adr(PCLIR.AsmInline).code.len, 0)
		| PCLIR.case:
				CaseOpd(instr.src1, instr.src2, instr.src3)
		| PCLIR.casel:
				CaseLineOpd(instr.src1, instr.val)
		| PCLIR.casee:
				CaseElseOpd(instr.src1)
		END
	END;
	Texts.WriteLn(PCLIR.W);
END DumpCode;
*)
PROCEDURE InstructionInit(VAR instr: PCLIR.Instruction);
VAR info: Info;
BEGIN NEW(info); instr.info := info
END InstructionInit;

PROCEDURE Install*;
VAR i: PCLIR.Opcode; idx: LONGINT;
BEGIN
	PCLIR.CG.MaxCodeSize := PCO.MaxCodeLength;
	PCLIR.CG.Init := Init;
	PCLIR.CG.Done := Done;
	PCLIR.CG.GetCode := PCO.GetCode;
	PCLIR.CG.Optimize := Optimize;
	PCLIR.CG.ParamAlign := 4;
(*  Debug
	PCLIR.CG.DumpCode := DumpCode;
*)
	PCLIR.Address := PCLIR.Int32;
	PCLIR.Set := PCLIR.Int32;
	PCLIR.SizeType := PCLIR.Int32;
	PCBT.SetNumberOfSyscalls(PCBT.DefaultNofSysCalls+2+2+2*20);
	NEW(PCLIR.CG.SysCallMap, PCBT.NofSysCalls);
	PCLIR.InitDefaultSyscalls;
	idx := PCBT.DefaultNofSysCalls;
	DivIndex := idx; INC(idx);
	ModIndex := idx; INC(idx);
	Int64LSH := idx; INC(idx);
	Int64ASH := idx; INC(idx);
	FAdd := idx; INC(idx);
	FSub := idx; INC(idx);
	FMul := idx; INC(idx);
	FDiv := idx; INC(idx);
	FNeg := idx; INC(idx);
	FAbs := idx; INC(idx);
	FEntier := idx; INC(idx);
	FIntToReal := idx; INC(idx);
	FRealToInt := idx; INC(idx);
	FRealToReal := idx; INC(idx);
	FEq := idx; INC(idx);
	FLe := idx; INC(idx);
	FLt := idx; INC(idx);
	FNe := idx; INC(idx);
	FGe := idx; INC(idx);
	FGt := idx; INC(idx);
	FLongOffset := 20;

	(* cf. Linker/Loader *)
	(* DIV / MOD syscalls *)
	PCLIR.CG.SysCallMap[DivIndex] := CHR(241);
	PCLIR.CG.SysCallMap[ModIndex] := CHR(242);

	(* HUGEINT syscalls *)
	PCLIR.CG.SysCallMap[Int64LSH] := CHR(190);
	PCLIR.CG.SysCallMap[Int64ASH] := CHR(191);

	(* REAL syscalls *)
	PCLIR.CG.SysCallMap[FAdd] := CHR(200);
	PCLIR.CG.SysCallMap[FSub] := CHR(201);
	PCLIR.CG.SysCallMap[FMul] := CHR(202);
	PCLIR.CG.SysCallMap[FDiv] := CHR(203);
	PCLIR.CG.SysCallMap[FNeg] := CHR(204);
	PCLIR.CG.SysCallMap[FAbs] := CHR(205);
	PCLIR.CG.SysCallMap[FEntier] := CHR(206);
	PCLIR.CG.SysCallMap[FIntToReal] := CHR(207);
	PCLIR.CG.SysCallMap[FRealToInt] := CHR(208);
	PCLIR.CG.SysCallMap[FRealToReal] := CHR(209);
	PCLIR.CG.SysCallMap[FEq] := CHR(210);
	PCLIR.CG.SysCallMap[FLe] := CHR(211);
	PCLIR.CG.SysCallMap[FLt] := CHR(212);
	PCLIR.CG.SysCallMap[FNe] := CHR(213);
	PCLIR.CG.SysCallMap[FGe] := CHR(214);
	PCLIR.CG.SysCallMap[FGt] := CHR(215);

	(* LONGREAL syscalls *)
	PCLIR.CG.SysCallMap[FAdd+FLongOffset] := CHR(220);
	PCLIR.CG.SysCallMap[FSub+FLongOffset] := CHR(221);
	PCLIR.CG.SysCallMap[FMul+FLongOffset] := CHR(222);
	PCLIR.CG.SysCallMap[FDiv+FLongOffset] := CHR(223);
	PCLIR.CG.SysCallMap[FNeg+FLongOffset] := CHR(224);
	PCLIR.CG.SysCallMap[FAbs+FLongOffset] := CHR(225);
	PCLIR.CG.SysCallMap[FEntier+FLongOffset] := CHR(226);
	PCLIR.CG.SysCallMap[FIntToReal+FLongOffset] := CHR(227);
	PCLIR.CG.SysCallMap[FRealToInt+FLongOffset] := CHR(228);
	PCLIR.CG.SysCallMap[FRealToReal+FLongOffset] := CHR(229);
	PCLIR.CG.SysCallMap[FEq+FLongOffset] := CHR(230);
	PCLIR.CG.SysCallMap[FLe+FLongOffset] := CHR(231);
	PCLIR.CG.SysCallMap[FLt+FLongOffset] := CHR(232);
	PCLIR.CG.SysCallMap[FNe+FLongOffset] := CHR(233);
	PCLIR.CG.SysCallMap[FGe+FLongOffset] := CHR(234);
	PCLIR.CG.SysCallMap[FGt+FLongOffset] := CHR(235);

	PCLIR.InstructionInit := InstructionInit;
	PCLIR.SetMethods(PCLIR.enter, Enter);
	PCLIR.SetMethods(PCLIR.exit, Exit);
	PCLIR.SetMethods(PCLIR.trap, Trap);
	PCLIR.SetMethods(PCLIR.tae, Trap);
	PCLIR.SetMethods(PCLIR.tne, Trap);
	PCLIR.SetMethods(PCLIR.saveregs, SaveRegisters);
	PCLIR.SetMethods(PCLIR.loadregs, LoadRegisters);
	PCLIR.SetMethods(PCLIR.ret, Return);
	PCLIR.SetMethods(PCLIR.ret2, Return);
	PCLIR.SetMethods(PCLIR.result, Result);
	PCLIR.SetMethods(PCLIR.result2, Result);
	PCLIR.SetMethods(PCLIR.pop, Pop);
	PCLIR.SetMethods(PCLIR.push, Push);
	PCLIR.SetMethods(PCLIR.load, LoadStore);
	PCLIR.SetMethods(PCLIR.loadc, LoadC);
	PCLIR.SetMethods(PCLIR.store, LoadStore);
	PCLIR.SetMethods(PCLIR.in, In);
	PCLIR.SetMethods(PCLIR.out, Out);
	PCLIR.SetMethods(PCLIR.nop, Nop);
	PCLIR.SetMethods(PCLIR.label, Label);
	FOR i := PCLIR.je TO PCLIR.jnf DO
		PCLIR.SetMethods(i, JCC)
	END;
	PCLIR.SetMethods(PCLIR.jmp, JCC);
	PCLIR.SetMethods(PCLIR.call, Call);
	PCLIR.SetMethods(PCLIR.callreg, CallReg);
	PCLIR.SetMethods(PCLIR.syscall, SysCall);
	FOR i := PCLIR.sete TO PCLIR.setnf DO
		PCLIR.SetMethods(i, SetCC)
	END;
	PCLIR.SetMethods(PCLIR.kill, Kill);
	PCLIR.SetMethods(PCLIR.phi, Phi);
	PCLIR.SetMethods(PCLIR.loadsp, LoadSP);

	PCLIR.SetMethods(PCLIR.convs, Conversion);
	PCLIR.SetMethods(PCLIR.convu, Conversion);
	PCLIR.SetMethods(PCLIR.copy, Copy);

	PCLIR.SetMethods(PCLIR.not, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.neg, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.abs, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.bts, BitOp);
	PCLIR.SetMethods(PCLIR.btc, BitOp);
	PCLIR.SetMethods(PCLIR.mul, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.div, DivMod);
	PCLIR.SetMethods(PCLIR.mod, DivMod);
	PCLIR.SetMethods(PCLIR.sub, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.add, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.and, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.or, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.xor, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.ash, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.bsh, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.rot, DataProcessingInstruction);
	PCLIR.SetMethods(PCLIR.move, Move);
	PCLIR.SetMethods(PCLIR.inline, Inline);
	PCLIR.SetMethods(PCLIR.case, Case);
	PCLIR.SetMethods(PCLIR.casel, CaseLabel);
	PCLIR.SetMethods(PCLIR.casee, CaseElse);
END Install;

BEGIN
	bimboTrace := FALSE;
	InitHexTab
END PCGARM.
