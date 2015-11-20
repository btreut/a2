(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCG386; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: Intel 386 code generator"; *)

(**
	Code Emission for i386 Processors
*)

IMPORT
		SYSTEM, KernelLog, PCM, PCO, PCLIR, PCBT;

CONST
	TraceReg = FALSE;
	Experimental = FALSE;

	Huge = TRUE;

	(* i386 Registers, taken from PCO*)
		EAX = 0; ECX = 1; EDX = 2; EBX = 3; ESP = 4; EBP = 5; ESI = 6; EDI = 7; (* 32 bit register *)
		AX = 8; CX = 9; DX = 10; BX = 11; SI = 14; DI = 15; (* 16 bit register *)
		AL = 16; CL = 17; DL = 18; BL = 19; AH = 20; CH = 21; DH = 22; BH = 23; (* 8 bit register *)

	(* Register Groups *)
		Reg32 = {EAX .. EDI};  Reg16 = {AX .. BX, SI, DI};  Reg8L = {AL .. BL};  Reg8H = {AH .. BH};  Reg8 = Reg8L+Reg8H;
		RegI = Reg32 + Reg16 + Reg8;

		RegFP = {24..31};
		Regs = RegI + RegFP;

	(* Register allocation mode *)
		Free = 0;  Splitted = MAX(LONGINT);  Blocked = Splitted-1;

	(* Address.mode *)
		register = 1;  relative = 2;  indexed = 3;  scaled = 4;  absolute = 5;  immediate = 6;
	(*
	mode          value
	0             Rpc
	Register      Rbase
	Relative      [offset + Rbase]
	Indexed       [offset + Rbase + Rindex]
	Scaled        [offset + Rbase + scale*Rindex]
	Absolute      offset + addr (to be patched by the linker)
	Immediate     value

	offset and value are 32-bit if addr is set (will be patched by the linker)
	*)

	(* PCO Definitions, cached *)
	noScale = PCO.noScale;  noBase = PCO.noBase;  noInx = PCO.noInx;  noDisp = PCO.noDisp;  noImm = PCO.noImm;
	none = -1;

	(* Constants for Opcode Tables *)
	left = 0;  right = 1;	(*shifts*)
	intMode = 0;  floatMode = 1;	(*index for JccTable*)

TYPE
	Register = SHORTINT;		(* i386 Register*)

	(*
		Address describes the value used by the instruction in terms of a complex addressing mode.
		instr.addr is the addressing mode that can be used instead of generating addr. In other words,
		a given PCLIR.Register is implemented by the addressing mode instr[vreg].addr.
		Exceptions to this rule:
		1) formM1: instr.addr is the M address (destination). This is no problem, since it is never
			used as source for other instructions.
		2) form1M: if the instruction is not suppressed (i.e. the instruction loads a register with a value,
			because no other instruction could integrate it in a better addressing mode), instr.addr is the
			addressing mode for the source (M). This holds only between the FSM and the code generation,
			after emission of the instruction, instr.addr must be resetted to mode=0.
		3) form1C: same as 2)
		Structure Life:
			InstructionInit
				* form1X to mode=0 (special case meaning register mode with base=pc)
				* initilializes formM1 to the
			Optimize/FSM modify
				* merging instructions into the addressing mode
				* form1M (see above)
			Gen*
				* use addressing mode and set / decrease count
				* use form1M exception (if done) and reset it
	*)

	(*
		Describe the register saved on the stack (e.g. during a call to another procedure)
		* vreg0 = 32-bit / 16-bit register or first 8-bit register
		* vreg1 = second 8-bit register
		* -1 => not used
		The register are pushed in the order given by the array
		Structure used by SaveRegs / RestoreRegs
	*)
	SavedRegistersDesc = ARRAY 8 OF RECORD  vreg0, vreg1, freg: PCLIR.Register  END;
	SavedRegistersType = POINTER TO ARRAY OF SavedRegistersDesc;

	AliveSet = ARRAY 8 OF RECORD
			reg: PCLIR.Register;
			mask: SET
	END;
	AliveSetPtr = POINTER TO AliveSet;

	(*
		Address:
			Label:
				imm = real pc
				disp = embedded fixup chain
	*)
	Address = OBJECT (PCLIR.InstructionAttribute)
	VAR
		mode, scale: SHORTINT;
		base, index: PCLIR.Register;
		imm, imm2, disp: LONGINT;
		addr: PCM.Attribute;
		alias: PCLIR.Register;	(* the current register is an alias of this one *)

		count: LONGINT;	(* emission only - use count; when it reaches 0, it can be deallocated *)
		i386: Register;
		i3862: Register;	(*Huge, second register for 64bit values*)
(*
		alive: AliveSet
*)
	END Address;

	(* RealAddress - Similar to address, used to represent a real addressing mode during code emission *)

	RealAddress = RECORD
		mode: SHORTINT;		(* PCO.Regs / Mem / Imme / MemA *)
		base, index: Register;
		scale: SHORTINT;
		imm, imm2, disp: LONGINT;
		addr: PCM.Attribute;
		size: PCLIR.Size;
		base2: Register;	(*Huge, second register for 64bit values*)
	END;

VAR
	SavedRegisters: SavedRegistersType; (* ARRAY 800 OF SavedRegistersDesc; *)
	SaveLevel: LONGINT;

	CCTableSwitch: SHORTINT;	(*0=Int/1=Float; remind last cmp operation, used for jcc/jncc/setcc because flags are different*)

	(* Conversion Tables *)
	FPSize: ARRAY 7 OF SHORTINT;
	TccOpcode: ARRAY 2 OF SHORTINT;	(*maps Tcc to a Jcc jump that skips the trap*)
	JccOpcode: ARRAY 16, 2 OF SHORTINT;	(* maps PCLIR.jcc to i386 jcc *)
	Jcc2Opcode: ARRAY 16, 3 OF SHORTINT;	(* maps PCLIR.jcc to i386 jcc for HUGEINTS comparisons*)
	Typ1Opcode: ARRAY 5 OF SHORTINT;
	Typ1Opcode2: ARRAY 5 OF SHORTINT;	(*opcodes for the msb of Typ1Operations (Huge) *)
	Group3Opcode: ARRAY 2 OF SHORTINT;	(*maps to neg/not*)
	BitOpcode: ARRAY 2 OF SHORTINT;		(*maps to bts/btc*)
	ShiftOpcode: ARRAY 6, 2 OF SHORTINT;	(*maps to ash/bsh/rot*)

	(* Debug *)
	RegName: ARRAY 8 OF CHAR;
	IReg: ARRAY 24, 4 OF CHAR;

TYPE
	RegSet = ARRAY 8 OF LONGINT;

		VAR
			reg32, reg8: RegSet;
			regFP: RegSet;
			FSP: SHORTINT;	(*F-Stack Top Pointer *)
			(*
				reg8:
					Free: register not used
					> 0: allocated as 8-bit reg for a PCLIR.Register

				reg32:
					Free: register not used (=> both reg8 are also free)
					Splitted: one of both reg8 is in use
					< 0:  allocated as 16-bit reg for a PCLIR.Register
					> 0:  allocated as 32-bit reg for a PCLIR.Register

				regFP:
					Free: register not used
					> 0: allocated for a PCLIR.Register
			*)

		PROCEDURE Assert(cond: BOOLEAN; reason: LONGINT);
		VAR  r32, r8, rFP: RegSet;
		BEGIN
			IF ~cond THEN
				r32 := reg32; r8 := reg8; rFP := regFP;	(* Debug *)
				HALT(100)
			END
		END Assert;

		(* CheckAllFree - Check that all registers are free *)

(*
		PROCEDURE CheckAllFree;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO 7 DO
				Assert(reg32[i] = Free, 1000);
				Assert(regFP[i] = Free, 1001);
			END
		END CheckAllFree;
*)

		(* FreeAll - Free all the registers *)

		PROCEDURE FreeAll;
		VAR  i: LONGINT;
		BEGIN
			FOR i := 0 TO 7 DO
				reg32[i] := Free;  reg8[i] := Free;  regFP[i] := Free;  FSP := -1
			END
		END FreeAll;

		(* GetThisReg - allocate given register (Int only) *)

		PROCEDURE GetThisReg(reg: Register; pc: LONGINT);
		VAR  off8, off32: Register;
		BEGIN
			Assert(reg IN RegI, 1002);
			Assert(pc # 0 , 1003);
			IF reg IN Reg8 THEN
				off8 := reg - AL;  off32 := reg MOD 4;
				Assert((reg32[off32] = Free) OR (reg32[off32] = Splitted), 1004);
				Assert(reg8[off8] = Free, 1005);
				reg32[off32] := Splitted;  reg8[off8] := pc
			ELSE
				off32 := reg MOD 8;
				Assert(reg32[off32] = Free, 1006);
				IF reg IN Reg16 THEN  pc := -pc  END;
				reg32[off32] := pc;
				IF off32 < ESP THEN	(*off32 IN {EAX..EBX}*)
					Assert(reg8[off32+0] = Free, 1007);
					Assert(reg8[off32+4] = Free, 1008);
					reg8[off32+0] := Blocked;
					reg8[off32+4] := Blocked;
				END
			END
		END GetThisReg;

		(* GetReg - Reserve a reg of given size for use by virtual register pc *)

		PROCEDURE GetReg(VAR reg: Register;  size: SHORTINT;  pc: LONGINT;  mask: SET);

			PROCEDURE GetReg8;
			VAR  p: Register;
			BEGIN
				p := BH; reg := 0;
				WHILE p >= AL DO
					IF (p IN mask) & (reg8[p- AL] = Free) THEN
						IF (reg32[p MOD 4] = Splitted) THEN
							reg := p;  p := AL
						ELSIF (reg32[p MOD 4] = Free) & (reg = 0) THEN
							reg := p
						END
					END;
					DEC(p)
				END;
				Assert((reg IN Reg8) & (reg IN mask), 1009);
				reg32[reg MOD 4] := Splitted;  reg8[reg - AL] := pc
			END GetReg8;

			PROCEDURE GetReg32;
			BEGIN
				reg := EBX;
				WHILE ~((reg IN mask) & (reg32[reg] = Free)) & (reg # ESI) DO
					reg := (reg-1) MOD 8
				END;
				GetThisReg(reg, pc)
			END GetReg32;

		BEGIN
			Assert(size IN {1, 2, 4}, 1010);
			Assert(pc # 0 , 1011);
			IF size = 1 THEN  GetReg8
			ELSIF size = 2 THEN  pc := -pc; GetReg32; INC(reg, AX)
			ELSIF size = 4 THEN  GetReg32
			END;
			Assert(reg IN RegI, 1012);
		END GetReg;

		PROCEDURE GetTempReg32(VAR reg: Register);
		BEGIN
			reg := EBX;
			WHILE (reg32[reg] # Free) & (reg # ESI) DO
				reg := (reg-1) MOD 8
			END;
			Assert(reg32[reg] = Free, 1013)
		END GetTempReg32;

		PROCEDURE GetTempReg8(VAR reg: Register;  mask: SET);
		BEGIN
			reg := 7;
			WHILE (reg >= 0) & ((reg8[reg] # Free) OR ~(reg+AL IN mask)) DO  DEC(reg)  END;
(*
			Assert(reg8[reg] = Free, 1014);
*)
			IF reg >= 0 THEN INC(reg, AL) END;
		END GetTempReg8;

		PROCEDURE GetFPReg(VAR reg: Register;  pc: LONGINT);
		BEGIN
			INC(FSP);
			Assert(FSP < 8, 1015);
			regFP[FSP] := pc;
			reg := 24 + FSP;
		END GetFPReg;

		(* FreeReg - Free a register *)

		PROCEDURE FreeReg(reg: Register);
		VAR off8, off32: SHORTINT;
		BEGIN
			Assert(reg IN Regs, 1017);
			IF  reg IN {ESP, EBP} THEN	(*skip, never allocated*)
			ELSIF  reg IN Reg32+Reg16  THEN
				off32 := reg MOD 8;
				Assert(reg32[off32] # Free, 1017);
				Assert(reg32[off32] # Splitted, 1018);
				reg32[off32] := Free;
				IF  off32 < ESP  THEN	(* off32 IN {EAX..EDX} *)
					reg8[off32] := Free;
					reg8[off32+4] := Free
				END
			ELSIF  reg IN Reg8  THEN
				off8 := reg - AL;  off32 := off8 MOD 4;
				Assert(reg8[off8] # Free, 1019);
				Assert(reg32[off32] # Free, 1020);
				reg8[reg MOD 8] := Free;
				IF reg8[(reg+4) MOD 8] = Free THEN  reg32[off32] := Free END
			ELSIF reg IN RegFP THEN
				reg := reg MOD 8;
				Assert((reg = FSP) OR (reg = FSP-1), 1021);
				Assert(regFP[FSP] # Free, 1022);
				regFP[reg] := Free;
				IF reg = FSP THEN
					DEC(FSP);
					IF (FSP >= 0) & (regFP[FSP] = Free) THEN  DEC(FSP)  END
				END
			ELSE
				HALT(99)
			END
		END FreeReg;

		(* Owner -  return virtual reg owning reg or free *)

		PROCEDURE Owner(reg: Register): LONGINT;
		BEGIN
			Assert(reg IN RegI, 1023);
			IF reg IN Reg32+Reg16 THEN
				RETURN ABS(reg32[reg MOD 8])
			ELSIF reg IN Reg8 THEN
				RETURN reg8[reg-AL]
			END;
			HALT(99);
		END Owner;

(* ---------- Helper Procedures -------------- *)

PROCEDURE Dump(VAR instr: PCLIR.Instruction;  info: Address);
BEGIN
	KernelLog.String("instr ="); KernelLog.Ln; KernelLog.Memory(ADDRESSOF(instr.op), 64);
	KernelLog.String("info ="); KernelLog.Ln; KernelLog.Memory(ADDRESSOF(info.mode), 64+32);
END Dump;

PROCEDURE RegisterOverlaps(reg1, reg2: Register): BOOLEAN;
BEGIN
	IF reg1 IN Reg8 THEN  reg1 := reg1 MOD 4  ELSE  reg1 := reg1 MOD 8 END;
	IF reg2 IN Reg8 THEN  reg2 := reg2 MOD 4  ELSE  reg2 := reg2 MOD 8 END;
	RETURN reg1 = reg2
END RegisterOverlaps;

PROCEDURE RegisterSize(reg: Register): SHORTINT;
BEGIN
	IF reg IN Reg32 THEN  RETURN 4
	ELSIF reg IN Reg16 THEN  RETURN 2
	ELSIF reg IN Reg8 THEN  RETURN 1
	END
END RegisterSize;

PROCEDURE MakeMask(reg: Register): SET;
BEGIN
	IF reg = none THEN
		RETURN {}
	ELSIF reg IN {ESI, EDI} THEN
		RETURN {reg}
	ELSIF reg IN RegI THEN
		reg := reg MOD 4;
		RETURN {reg, AX+reg, AL+reg, AH+reg}
	END
END MakeMask;

(* Special Registers *)

 (* RegisterA - Return EAX/AX/AL, depending on the size *)

PROCEDURE RegisterA(size: PCLIR.Size): Register;
BEGIN
	CASE size OF
	|  PCLIR.Int32:  RETURN EAX
	|  PCLIR.Int16:  RETURN AX
	|  PCLIR.Int8:  RETURN AL
	END
END RegisterA;

(* RegisterD - Return EDX / DX / AH, depending on the size (complementary reg) *)

PROCEDURE RegisterD(size: PCLIR.Size): Register;
BEGIN
	CASE size OF
	|  PCLIR.Int8:  RETURN AH
	|  PCLIR.Int16:  RETURN DX
	|  PCLIR.Int32:  RETURN EDX
	END
END RegisterD;

PROCEDURE ConstSize(c: LONGINT; allow16: BOOLEAN): SHORTINT;
BEGIN
	IF (c >= MIN(SHORTINT)) & (c <= MAX(SHORTINT)) THEN
		RETURN 1
	ELSIF allow16 & (c >= MIN(INTEGER)) & (c <= MAX(INTEGER)) THEN
		RETURN 2
	ELSE
		RETURN 4
	END
END ConstSize;

(* Instruction Initialization, plug-in for PCLIR.InstructionInit *)

PROCEDURE InstructionInit(VAR instr: PCLIR.Instruction);
VAR  info: Address;  op: PCLIR.Opcode;
BEGIN
	op := instr.op;
	IF (PCLIR.InstructionSet[op].format IN PCLIR.form1X) OR (op = PCLIR.case) THEN
		NEW(info);  instr.info := info;  instr.suppress := FALSE;  info.alias := none;  info.i386 := none;
	ELSIF (op = PCLIR.label) OR (op = PCLIR.finallylabel) THEN
		NEW(info);  instr.info := info;  instr.suppress := FALSE;  info.disp := none;  info.imm := 0
	ELSIF PCLIR.InstructionSet[op].format = PCLIR.formM1 THEN
		NEW(info);  instr.info := info;  instr.suppress := FALSE;
		IF instr.src1 = PCLIR.Absolute THEN
			info.mode := absolute;  info.disp := instr.val;  info.addr := instr.adr
		ELSE
			info.mode := relative;  info.disp := instr.val;  info.base := instr.src1
		END
	END
END InstructionInit;


(* Code Optimization Procedures *)

(* FSM (Finite State Machine) - Try to remove the current instruction by using a complex addressing mode *)

PROCEDURE FSM(code: PCLIR.Code;  pc: LONGINT;  VAR instr: PCLIR.Instruction;  addr: Address);
VAR  p: PCLIR.Piece;  op: PCLIR.Opcode;  thisreg, nextreg: PCLIR.Register;  i: LONGINT;  info: Address;
BEGIN
	IF thisreg < 0 THEN RETURN END;	(* FP/SP/HwReg terminate search*)
	thisreg := pc;
	nextreg := none;	(* next register to be optimized *)
	op := instr.op;
	IF addr.mode = 0 THEN		(* complete initialization *)
		addr.mode := register;  addr.base := pc
	END;
	IF (instr.dstCount # 1) THEN  op := PCLIR.nop  END;	(*instruction is used more than once: don't simplify; but try other opts*)
	IF (PCLIR.convs<=op) & (op<=PCLIR.copy) & (instr.dstSize = PCLIR.Address) & (instr.src1 >= instr.barrier) THEN
		pc := instr.src1; code.GetPiece(pc, p);
		IF PCLIR.Int32 = p.instr[pc].dstSize THEN
			instr.suppress := TRUE;
			IF addr.base = thisreg THEN  addr.base := instr.src1  ELSE  addr.index := instr.src1  END;
			FSM(code, instr.src1, p.instr[pc], addr);
			RETURN
		END
	END;


	CASE addr.mode OF
	|  register:
		IF (op = PCLIR.load) & (instr.src1 = PCLIR.Absolute) THEN	(*register -> absolute*)
			instr.suppress := TRUE;
			addr.mode := absolute;  addr.disp := instr.val;  addr.addr := instr.adr
		ELSIF (op = PCLIR.loadc) THEN		(*register -> immediate*)
			instr.suppress := TRUE;
			addr.mode := immediate;  addr.imm := instr.val;  addr.addr := instr.adr
		ELSIF (op = PCLIR.load) THEN		(*register -> relative*)
			instr.suppress := TRUE;
			addr.mode := relative;  addr.disp := instr.val;  addr.base := instr.src1;
			nextreg := addr.base;
		END
	| relative:
		IF (op = PCLIR.loadc) THEN	(*relative -> absolute*)
			instr.suppress := TRUE;
			addr.mode := absolute;  addr.disp :=  addr.disp + instr.val;  addr.addr := instr.adr
		ELSIF (op = PCLIR.add) THEN		(*relative -> indexed*)
			instr.suppress := TRUE;
			addr.mode := indexed;  addr.base := instr.src1;  addr.index := instr.src2;
			nextreg := addr.index
		ELSIF (op = PCLIR.mul) OR (op = PCLIR.ash) THEN	(*relative -> scaled, iff const mult*)
			Optimize(code, instr, pc, NIL);
			pc := instr.src2;  code.GetPiece(pc, p);
			info := SYSTEM.VAL(Address, p.instr[pc].info);
			IF (info # NIL) & (info.mode = immediate) & (info.addr = NIL) THEN
				i := info.imm;
				IF op = PCLIR.ash THEN  i := ASH(LONG(LONG(1)), i) END;
				IF  i=1  THEN	(*relative -> relative*)
					instr.suppress := TRUE;
					addr.base := instr.src1;
					nextreg := instr.src1
				ELSIF (i=2) OR (i=4) OR (i=8) THEN
					instr.suppress := TRUE;
					addr.mode := scaled;  addr.base := none;  addr.index := instr.src1;  addr.scale := SHORT(SHORT(i));
					nextreg := instr.src1
				END
			END
		END
	| indexed:
		IF (op = PCLIR.loadc) THEN	(*indexed -> relative*)
			instr.suppress := TRUE;
			IF thisreg = addr.base THEN  addr.base := addr.index  END;
			addr.mode := relative;  addr.disp := addr.disp + instr.val;  addr.index := none;  addr.addr := instr.adr;
			nextreg := addr.base
		ELSIF (op = PCLIR.add) THEN	(*special case, because of lea removal*)
			Optimize(code, instr, pc, NIL);
			pc := instr.src2;  code.GetPiece(pc, p);
			info := SYSTEM.VAL(Address, p.instr[pc].info);
			IF (info # NIL) & (info.mode = immediate) & (info.addr = NIL) THEN
				addr.disp := addr.disp + info.imm;
				IF thisreg = addr.base THEN
					addr.base := instr.src1; nextreg := addr.base
				ELSE
					ASSERT(addr.index = thisreg);
					addr.index := instr.src1; nextreg := addr.index
				END;
				instr.suppress := TRUE
			END
		ELSIF (op = PCLIR.mul) OR (op = PCLIR.ash) THEN	(*indexed -> scaled, iff const mult*)
			Optimize(code, instr, pc, NIL);
			pc := instr.src2;  code.GetPiece(pc, p);
			info := SYSTEM.VAL(Address, p.instr[pc].info);
			IF (info # NIL) & (info.mode = immediate) & (info.addr = NIL) THEN
				i := info.imm;
				IF op = PCLIR.ash THEN  i := ASH(LONG(LONG(1)), i) END;
				IF (i=1) OR (i=2) OR (i=4) OR (i=8) THEN
					instr.suppress := TRUE;
					IF i#1 THEN  addr.mode := scaled;  addr.scale := SHORT(SHORT(i))  END;
					IF thisreg = addr.base THEN  addr.base := addr.index  END;
					addr.index := instr.src1;
					IF (addr.index >= instr.barrier) THEN
						pc := addr.index; code.GetPiece(pc, p); FSM(code, addr.index, p.instr[pc], addr)
					ELSIF (addr.base >= instr.barrier)  THEN
						pc := addr.base; code.GetPiece(pc, p); FSM(code, addr.index, p.instr[pc], addr)
					END
				ELSIF thisreg = addr.index THEN  nextreg := addr.base
				END
			END
		ELSIF thisreg = addr.index THEN  nextreg := addr.base
		END
	| scaled:
		IF (op = PCLIR.loadc) THEN	(*scaled -> relative*)
			instr.suppress := TRUE;
			IF thisreg = addr.base THEN
				addr.addr := instr.adr;  addr.disp := addr.disp + instr.val;  addr.base := none
			ELSIF instr.adr # NIL THEN
				instr.suppress := FALSE	(*undo*)
			ELSIF addr.base # none THEN
				addr.mode := relative;  addr.disp := addr.disp + instr.val * addr.scale; addr.index := none;
				nextreg := addr.base
			ELSE
				addr.mode := absolute;  addr.disp := addr.disp + instr.val * addr.scale
			END
		ELSIF (op = PCLIR.add) THEN	(*special case, because of lea removal*)
			Optimize(code, instr, pc, NIL);
			pc := instr.src2;  code.GetPiece(pc, p);
			info := SYSTEM.VAL(Address, p.instr[pc].info);
			IF (info # NIL) & (info.mode = immediate) & (info.addr = NIL) THEN
				IF thisreg = addr.base THEN
					addr.disp := addr.disp + info.imm;
					addr.base := instr.src1; nextreg := addr.base;
					instr.suppress := TRUE
				ELSIF addr.scale = 1 THEN
					ASSERT(addr.index = thisreg);
					addr.disp := addr.disp + info.imm;
					addr.index := instr.src1; nextreg := addr.index;
					instr.suppress := TRUE
				END
			END
		ELSIF thisreg = addr.index THEN  nextreg := addr.base
		END
	END;
	IF (nextreg >= instr.barrier) THEN
		pc := nextreg; code.GetPiece(pc, p); FSM(code, nextreg, p.instr[pc], addr)
	END
END FSM;

PROCEDURE AliveSetInit(VAR set: AliveSet);
VAR  i: LONGINT;
BEGIN
	FOR i := 0 TO LEN(set)-1 DO
		set[i].reg := none
	END
END AliveSetInit;

PROCEDURE AliveAdd(VAR set: AliveSet;  reg: LONGINT;  size: PCLIR.Size);
VAR i, j: LONGINT; mask: SET;
BEGIN
	IF reg <= 0 THEN RETURN END;
	IF (reg = 0) THEN HALT(MAX(INTEGER)) END;
(*PCM.LogWLn; PCM.LogWStr("Add "); PCM.LogWNum(reg);*)
	i := 0; j := -1;
	WHILE (i < LEN(set)) & (set[i].reg # reg) DO
		IF set[i].reg = none THEN j := i END;
		INC(i)
	END;
	IF (j = -1) THEN
		PCM.LogWLn; PCM.LogWStr("AliveSet.Add: no free space")
	ELSIF (i = LEN(set)) THEN
		set[j].reg := reg;
		CASE size OF
		| PCLIR.Int8:  mask := Reg8
		| PCLIR.Int16:  mask := Reg16
		| PCLIR.Int32:  mask := Reg32
		END;
		set[j].mask := mask
	END;
	(*FOR i := 0 TO LEN(set)-1 DO
		PCM.LogWNum(set[i].reg)
	END;*)
END AliveAdd;

PROCEDURE AliveAddComplex(VAR set: AliveSet;  code: PCLIR.Code;  reg: LONGINT);
VAR pos: LONGINT; p: PCLIR.Piece; info: Address;
BEGIN
	IF reg <= 0 THEN RETURN END;
	pos := reg; code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);
	CASE info.mode OF
	| 0:
(*PCM.LogWLn; PCM.LogWStr("AddComplex / 0 "); PCM.LogWNum(reg);*)
			AliveAdd(set, reg, p.instr[pos].dstSize)
	| register:
			AliveAdd(set, info.base, p.instr[pos].dstSize)
	| relative:
(*PCM.LogWLn; PCM.LogWStr("AddComplex / reg+rel "); PCM.LogWNum(reg);  PCM.LogWNum(info.base);*)
			AliveAdd(set, info.base, PCLIR.Address)
	| indexed, scaled:
			AliveAdd(set, info.base, PCLIR.Address); AliveAdd(set, info.index, PCLIR.Address)
	ELSE
	END
END AliveAddComplex;

PROCEDURE AliveRemove(VAR set: AliveSet;  reg: LONGINT);
VAR i: LONGINT;
BEGIN
(*PCM.LogWLn; PCM.LogWStr("Rem "); PCM.LogWNum(reg);*)
	i := 0;
	WHILE (i < LEN(set)) & (set[i].reg # reg) DO INC(i) END;
	IF i < LEN(set) THEN set[i].reg := none  END;
END AliveRemove;


(* SetRegisterHint - vreg should be implemented by ireg *)

PROCEDURE SetRegisterHint(code: PCLIR.Code;  barrier: LONGINT; vreg: PCLIR.Register;  ireg: Register);
VAR p: PCLIR.Piece; op: PCLIR.Opcode;  info: Address;  size: PCLIR.Size;
BEGIN
	IF (vreg >= 0) & (vreg >= barrier) THEN
		code.GetPiece(vreg, p);
		info := SYSTEM.VAL(Address, p.instr[vreg].info);  ASSERT(info # NIL);
		IF info.i386 = none THEN
			info.i386 := ireg;
			op := p.instr[vreg].op;
			size := PCLIR.SizeOf(code, p.instr[vreg].src1);
			IF size IN PCLIR.FloatSize THEN
				(*skip*)
			ELSIF (PCLIR.convs<=op) & (op<=PCLIR.copy) (*& (PCLIR.NofBytes(p.instr[vreg].dstSize) <= PCLIR.NofBytes(size))*) THEN	(*reduction*)
				IF size = PCLIR.Int64 THEN
					SetRegisterHint2(code, barrier, p.instr[vreg].src1, (ireg MOD 8) + EAX, none)
				ELSE
					SetRegisterHint(code, barrier, p.instr[vreg].src1, (ireg MOD 8) + RegisterA(size))
				END;
			ELSIF (PCLIR.InstructionSet[op].format IN {PCLIR.form11, PCLIR.form12}) & ((op < PCLIR.sete) OR (op > PCLIR.setnf)) THEN
						(* (op >= PCLIR.mul) & (op <= PCLIR.or) THEN	(*ops with dst = src1*)  *)
				SetRegisterHint(code, barrier, p.instr[vreg].src1, ireg)
			END
		END
	END
END SetRegisterHint;

PROCEDURE SetRegisterHint2(code: PCLIR.Code;  barrier: LONGINT; vreg: PCLIR.Register;  ireg, ireg2: Register);
VAR p: PCLIR.Piece; op: PCLIR.Opcode;  info: Address;  size: PCLIR.Size;
BEGIN
	IF (vreg >= 0) & (vreg >= barrier) THEN
		code.GetPiece(vreg, p);
		info := SYSTEM.VAL(Address, p.instr[vreg].info);  ASSERT(info # NIL);
		ASSERT(p.instr[vreg].dstSize = PCLIR.Int64);
		IF info.i386 = none THEN
			info.i386 := ireg; info.i3862 := ireg2;
			op := p.instr[vreg].op;
			size := PCLIR.SizeOf(code, p.instr[vreg].src1);
			IF size IN PCLIR.FloatSize THEN
				(*skip*)
			ELSIF (PCLIR.convs<=op) & (op<=PCLIR.copy) THEN	(*reduction*)
				SetRegisterHint(code, barrier, p.instr[vreg].src1, (ireg MOD 8) + RegisterA(size))
			ELSIF (PCLIR.InstructionSet[op].format IN {PCLIR.form11, PCLIR.form12}) & ((op < PCLIR.sete) OR (op > PCLIR.setnf)) THEN
						(* (op >= PCLIR.mul) & (op <= PCLIR.or) THEN	(*ops with dst = src1*)  *)
				SetRegisterHint2(code, barrier, p.instr[vreg].src1, ireg, ireg2)
			END
		END
	END
END SetRegisterHint2;


(** Optimize - Perform some code optimizations; must be a reverse traversal *)
PROCEDURE Optimize(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT;  context: ANY);
CONST	Full = 1;  Const = 2;  NoConst = 3;	(*Optimization Mode*)
VAR	p: PCLIR.Piece;  copy, pos: LONGINT; op: PCLIR.Opcode; debSrc1, debSrc2: PCLIR.Register; mode: SHORTINT;
	info: Address;  format: LONGINT; size1: PCLIR.Size;
	alive: AliveSetPtr; hint1, hint2: Register;

	PROCEDURE Compact(reg: PCLIR.Register;  mode:  SHORTINT): SHORTINT;
	VAR  p: PCLIR.Piece; pos: LONGINT;  info: Address;  op: PCLIR.Opcode;  mode0: SHORTINT;
	BEGIN
		IF reg >= instr.barrier THEN
			pos := reg; code.GetPiece(pos, p);
			op := p.instr[pos].op;
			info := SYSTEM.VAL(Address, p.instr[pos].info);
			IF (info.mode = 0) &
				((mode = Full) OR ((mode = Const) & (op = PCLIR.loadc)) OR ((mode = NoConst) & (op # PCLIR.loadc))) THEN
				FSM(code, reg, p.instr[pos], info)
			END;
			mode0 := info.mode;
			ASSERT((mode = Full) OR (mode = Const)&(mode0 IN {0, register, immediate}) OR (mode = NoConst)&(mode0#immediate));
			RETURN info.mode
		ELSE
			RETURN register
		END
	END Compact;

	PROCEDURE Unuse(reg: PCLIR.Register);
	VAR  p: PCLIR.Piece; pos: LONGINT;
	BEGIN
		IF reg >= 0 THEN
			pos := reg; code.GetPiece(pos, p);
			DEC(p.instr[pos].dstCount)
		END
	END Unuse;

BEGIN
	op := instr.op;  format := PCLIR.InstructionSet[op].format;
	IF instr.suppress THEN  RETURN  END;
	copy := pc;
	debSrc1 := instr.src1; debSrc2 := instr.src2;	(* Debug *)
	IF Experimental & (context # NIL) THEN
		alive := SYSTEM.VAL(AliveSetPtr, context);
(*
		IF (instr.info # NIL) THEN
			info := SYSTEM.VAL(Address, instr.info);
			info.alive := alive^
		END
*)
	END;

	CASE format OF
	| PCLIR.form00, PCLIR.form0C, PCLIR.formXX:
			(* no optimization *)
	| PCLIR.form10:
			IF instr.op # PCLIR.pop THEN
				instr.suppress := instr.dstCount = 0
			END;
			IF Experimental & (alive # NIL) THEN  AliveRemove(alive^, pc)  END;
	| PCLIR.form1M, PCLIR.form1C:
			(* if this is reached, the instruction is not suppressed -> exception 1 *)
			info := SYSTEM.VAL(Address, instr.info);
			IF ~(info.mode IN {0, register}) THEN  Dump(instr, info) END;
			ASSERT(info.mode IN {0, register});

			IF instr.dstCount = 0 THEN
				IF (format = PCLIR.form1M) & (instr.src1 >= 0) THEN
					Unuse(instr.src1)
				END;
				instr.suppress := TRUE
			ELSIF format = PCLIR.form1C THEN
				info.mode := immediate;  info.imm := instr.val;  info.addr := instr.adr
			ELSIF instr.src1 = PCLIR.Absolute THEN
				info.mode := absolute;  info.disp := instr.val;  info.addr := instr.adr
			ELSE
				info.mode := relative;  info.disp := instr.val;  info.base := instr.src1;
				IF instr.src1 >= instr.barrier THEN
					pc := instr.src1; code.GetPiece(pc, p); FSM(code, instr.src1, p.instr[pc], info)
				END
			END;
			IF Experimental & (alive # NIL) THEN
				AliveRemove(alive^, copy);
				IF ~(info.mode IN {immediate, absolute}) THEN
					AliveAdd(alive^, info.base, PCLIR.Address);
					AliveAdd(alive^, info.index, PCLIR.Address)
				END
			END;
			(*instr.suppress := instr.dstCount = 0*)
	| PCLIR.formM1:
			info := SYSTEM.VAL(Address, instr.info);
			IF instr.src1 >= instr.barrier THEN
				pc := instr.src1; code.GetPiece(pc, p); FSM(code, instr.src1, p.instr[pc], info);
				mode := Compact(instr.src2, Const);
				IF Experimental & (alive # NIL) THEN
					AliveAdd(alive^, info.base, PCLIR.Address);
					AliveAdd(alive^, info.index, PCLIR.Address);
					AliveAdd(alive^, instr.src2, PCLIR.SizeOf(code, instr.src2))
				END
			ELSIF instr.src1 <= PCLIR.HwReg THEN
				info.mode := register;  info.base := instr.src1;
				mode := Compact(instr.src2, Full);
				IF Experimental & (alive # NIL) THEN
					AliveAddComplex(alive^, code, instr.src2)
				END
			ELSE
				mode := Compact(instr.src2, Const);
				IF Experimental & (alive # NIL) THEN
					AliveAdd(alive^, instr.src1, PCLIR.Address);
					AliveAdd(alive^, instr.src2, PCLIR.SizeOf(code, instr.src2))
				END
			END
	| PCLIR.form11:
			size1 := PCLIR.SizeOf(code, instr.src1);
			hint1 := none; hint2 := none;
			IF (instr.dstCount = 0) & (instr.src1 >= 0) THEN
				Unuse(instr.src1);  instr.suppress := TRUE
			ELSIF (op = PCLIR.in) THEN
				hint1 := DX;
			ELSIF (op = PCLIR.convs) OR (op = PCLIR.convu) OR (op = PCLIR.copy) THEN
				IF size1 < instr.dstSize THEN
					mode := Compact(instr.src1, NoConst);
					IF (instr.dstSize = PCLIR.Int64) & (size1 = PCLIR.Int32) THEN hint1 := EAX END
				END
			ELSIF (op = PCLIR.abs) THEN
				IF  size1 IN PCLIR.IntSize  THEN  hint1 := RegisterA(size1)  END
			END;
			IF Experimental & (alive # NIL) THEN
				AliveRemove(alive^, pc);
				IF mode = 0 THEN
					AliveAdd(alive^, instr.src1, size1)
				ELSE
					AliveAddComplex(alive^, code, instr.src1)
				END
			END;
			IF hint1 # none THEN
				SetRegisterHint(code, instr.barrier, instr.src1, hint1)
			END
	| PCLIR.form01:
			hint1 := none;
			size1 := PCLIR.SizeOf(code, instr.src1);
			IF op = PCLIR.kill THEN
				(*skip*)
			ELSIF op = PCLIR.ret THEN
				IF size1 = PCLIR.Int64 THEN
					hint1 := EAX; hint2 := EDX
				ELSIF size1 IN PCLIR.IntSize-{PCLIR.Int64} THEN
					hint1 := RegisterA(size1)
				END
			ELSIF op = PCLIR.ret2 THEN
				ASSERT(size1 IN PCLIR.IntSize);
				hint1 := RegisterD(size1)
			ELSIF op = PCLIR.loadsp THEN
				hint1 := ESP
			ELSIF op = PCLIR.loadfp THEN
				hint1 := EBP
			ELSE
				mode := Compact(instr.src1, Full)
			END;
			IF Experimental & (alive # NIL) THEN
				IF mode = 0 THEN
					AliveAdd(alive^, instr.src1, size1)
				ELSE
					AliveAddComplex(alive^, code, instr.src1)
				END
			END;
			IF hint1 # none THEN
				IF size1 = PCLIR.Int64 THEN
					SetRegisterHint2(code, instr.barrier, instr.src1, hint1, hint2)
				ELSE
					SetRegisterHint(code, instr.barrier, instr.src1, hint1)
				END
			END
	| PCLIR.form02, PCLIR.form12, PCLIR.form02C:
			hint1 := none; hint2 := none;
			IF (op = PCLIR.phi) THEN
				IF instr.src1 > instr.src2 THEN  PCLIR.SwapSources(instr)  END;
				info := SYSTEM.VAL(Address, instr.info);  info.alias := instr.src1;
				pos := instr.src2;  code.GetPiece(pos, p);
				info := SYSTEM.VAL(Address, p.instr[pos].info);  info.alias := instr.src1;
			ELSIF (format = PCLIR.form12) & (instr.dstCount = 0) & (instr.src1 >= 0)  & (instr.src2 >= 0)THEN
				Unuse(instr.src1); Unuse(instr.src2);
				instr.suppress := TRUE
			ELSIF (op >= PCLIR.ash) & (op <= PCLIR.rot) THEN
				ASSERT(PCLIR.NofBytes(PCLIR.SizeOf(code, instr.src2)) = 1);
				IF Compact(instr.src2, Const) # immediate THEN hint2 := CL END
			ELSIF (op = PCLIR.bts) OR (op = PCLIR.btc) THEN
				mode := Compact(instr.src2, Const)
			ELSIF (op = PCLIR.jf) OR (op = PCLIR.jnf) OR (op = PCLIR.setf) OR (op = PCLIR.setnf) THEN
				mode := Compact(instr.src1, NoConst);
				mode := Compact(instr.src2, Const)
			ELSIF (op = PCLIR.div) OR (op = PCLIR.mod) THEN
				mode := Compact(instr.src2, NoConst);
				IF instr.dstSize IN PCLIR.IntSize THEN hint1 := RegisterA(instr.dstSize) (*dividend*) END
			ELSIF (op = PCLIR.out) THEN
				hint1 := DX;
				hint2 := RegisterA(PCLIR.SizeOf(code, instr.src2))
			ELSE
				mode := Compact(instr.src2, Full);
				IF (instr.dstSize = PCLIR.Int64) & (op = PCLIR.mul) THEN
					mode := Compact(instr.src1, NoConst)
				ELSIF (mode IN {0, register}) & (PCLIR.commutative IN PCLIR.InstructionSet[op].flags) THEN
					IF ~(Compact(instr.src1, Full) IN {0, register}) THEN  PCLIR.SwapSources(instr)  END
				ELSIF (mode = immediate) & ((format=PCLIR.form02) OR (op = PCLIR.mul) OR ((op >= PCLIR.sete) & (op <= PCLIR.setnf))) THEN
					mode := Compact(instr.src1, NoConst);
					IF  (mode IN {0, register}) & ((op >= PCLIR.je) & (op <= PCLIR.jnf) OR (op >= PCLIR.sete) & (op <= PCLIR.setnf)) THEN
						size1 := PCLIR.SizeOf(code, instr.src1);
						IF size1 IN PCLIR.IntSize / {PCLIR.Int64} THEN hint1 := RegisterA(size1) END
					END
				END;
				IF (op = PCLIR.mul) & (instr.dstSize IN PCLIR.IntSize-{PCLIR.Int64}) THEN
					hint1 := RegisterA(instr.dstSize) (*dividend*)
				END
			END;
			IF Experimental & (context # NIL) THEN
				IF format = PCLIR.form12 THEN  AliveRemove(alive^, pc)  END;
				AliveAddComplex(alive^, code, instr.src1);
				AliveAddComplex(alive^, code, instr.src2)
			END;
			IF hint1 # none THEN  SetRegisterHint(code, instr.barrier, instr.src1, hint1)  END;
			IF hint2 # none THEN  SetRegisterHint(code, instr.barrier, instr.src2, hint2)  END
	| PCLIR.form03:
			mode := Compact(instr.src3, Const);
			IF Experimental & (context # NIL) THEN
				AliveAdd(alive^, instr.src1, PCLIR.Address);
				AliveAdd(alive^, instr.src2, PCLIR.Address);
				IF mode # immediate THEN
					AliveAdd(alive^, instr.src3, PCLIR.Int32)
				END
			END;
			SetRegisterHint(code, instr.barrier, instr.src1, ESI);
			SetRegisterHint(code, instr.barrier, instr.src2, EDI);
			IF mode # immediate THEN
				SetRegisterHint(code, instr.barrier, instr.src3, ECX)
			END
	END;
(*
	IF Experimental & (context # NIL) THEN
		alive := SYSTEM.VAL(AliveSetPtr, context);
		IF instr.info # NIL THEN
			info := SYSTEM.VAL(Address, instr.info);
			info.alive := alive^
		END;
		AliveSetProcess(alive, code, instr, copy)
	END;
*)
END Optimize;


(* Address Handling Procedures *)

(* UseRegister - use a register; last use frees it *)

PROCEDURE UseRegisterI(VAR instr: PCLIR.Instruction;  VAR reg: Register);		(*shortcut*)
VAR  info: Address;
BEGIN
	info := SYSTEM.VAL(Address, instr.info);  ASSERT(info.mode IN {0, register}, 100);
	DEC(info.count);  reg := info.i386;
	IF info.count <= 0 THEN FreeReg(reg) END;
END UseRegisterI;

PROCEDURE UseRegister(code: PCLIR.Code;  vreg: PCLIR.Register;  VAR reg: Register);
VAR p: PCLIR.Piece;
BEGIN
	IF vreg >= 0 THEN
		code.GetPiece(vreg, p);  UseRegisterI(p.instr[vreg], reg)
	ELSIF vreg = PCLIR.SP THEN
		reg := ESP
	ELSIF vreg = PCLIR.FP THEN
		reg := EBP
	ELSIF (vreg <= PCLIR.HwReg-EAX) & (vreg >= PCLIR.HwReg - BH) THEN
		reg := SHORT(SHORT(PCLIR.HwReg-vreg))
	ELSE HALT(99)	(*paranoid check*)
	END
END UseRegister;

PROCEDURE UseRegisterI2(VAR instr: PCLIR.Instruction;  VAR reg, reg2: Register);		(*shortcut*)
VAR  info: Address;
BEGIN
	info := SYSTEM.VAL(Address, instr.info);
	ASSERT(info.mode IN {0, register}, 100);
	ASSERT(instr.dstSize = PCLIR.Int64, 101);
	DEC(info.count);  reg := info.i386;  reg2 := info.i3862;
	IF info.count <= 0 THEN FreeReg(reg); FreeReg(reg2) END;
END UseRegisterI2;

PROCEDURE UseRegister2(code: PCLIR.Code;  vreg: PCLIR.Register;  VAR reg, reg2: Register);
VAR p: PCLIR.Piece;
BEGIN
	IF vreg >= 0 THEN
		code.GetPiece(vreg, p);  UseRegisterI2(p.instr[vreg], reg, reg2)
	ELSE HALT(99)	(*paranoid check*)
	END
END UseRegister2;

(* UseComplex - use a complex addressing form, free registers after last use *)

PROCEDURE UseComplexI(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  VAR addr: RealAddress);
VAR  info: Address;  adr: PCBT.Procedure;
	PROCEDURE IntelScale(scale: LONGINT): SHORTINT;
	BEGIN
		CASE scale OF
		| 1:  RETURN PCO.Scale1  | 2:  RETURN PCO.Scale2  | 4:  RETURN PCO.Scale4  | 8:  RETURN PCO.Scale8
		END
	END IntelScale;
BEGIN
	info := SYSTEM.VAL(Address, instr.info);
	addr.base := noBase;  addr.base2 := noBase;  addr.index := noInx;  addr.disp := noDisp;
	addr.scale := noScale;  addr.imm := noImm;  addr.addr := info.addr;  addr.size := instr.dstSize;
	CASE info.mode OF
	| 0:
			addr.mode := PCO.Regs;
			addr.addr := NIL;
			IF addr.size = PCLIR.Int64 THEN
				UseRegisterI2(instr, addr.base, addr.base2)
			ELSE
				UseRegisterI(instr, addr.base)
			END
	| register:
			addr.mode := PCO.Regs;
			addr.addr := NIL;
			IF addr.size = PCLIR.Int64 THEN
				UseRegister2(code, info.base, addr.base, addr.base2)
			ELSE
				UseRegister(code, info.base, addr.base)
			END
	| relative:
			addr.mode := PCO.Mem;
			UseRegister(code, info.base, addr.base);
			addr.base2 := addr.base; addr.disp := info.disp;  addr.addr := info.addr;
	|  indexed, scaled:
			addr.mode := PCO.Mem;
			IF (info.base # none) THEN  UseRegister(code, info.base, addr.base)  END;
			addr.base2 := addr.base; addr.disp := info.disp;  addr.addr := info.addr;
			UseRegister(code, info.index, addr.index);
			IF info.mode = scaled THEN  addr.scale := IntelScale(info.scale)  END
	|  absolute:
			addr.mode := PCO.Mem;
			addr.disp := info.disp;  addr.addr := info.addr
	|  immediate:
			addr.mode := PCO.Imme;
			IF instr.dstSize = PCLIR.Int64 THEN addr.base := EAX ELSE addr.base := RegisterA(instr.dstSize) END;
			addr.base2 := addr.base; addr.imm := info.imm;
			IF addr.imm >= 0 THEN addr.imm2 := 0 ELSE addr.imm2 := -1 END;
			IF addr.addr # NIL THEN ASSERT(addr.size = PCLIR.Address) END
	END;
	IF ((addr.mode = PCO.Mem) OR (addr.mode = PCO.Imme)) & (addr.addr # NIL) THEN
		INC(addr.mode, PCO.ForceDisp32)
	END;
	IF (addr.addr # NIL) & (addr.addr IS PCBT.Procedure) THEN
		adr := addr.addr(PCBT.Procedure);
		ASSERT(addr.disp = 0);
		IF (addr.mode = PCO.ImmeA) THEN
			ASSERT(addr.imm = 0)
		ELSIF (addr.mode = PCO.MemA) THEN
			ASSERT(addr.disp = 0)
		ELSE
			HALT(99)
		END;
	END
END UseComplexI;

PROCEDURE UseComplex(code: PCLIR.Code;  vreg: PCLIR.Register; VAR addr: RealAddress);
VAR p: PCLIR.Piece;
BEGIN
	IF vreg >= 0 THEN
		code.GetPiece(vreg, p);  UseComplexI(code, p.instr[vreg], addr)
	ELSE
		addr.mode := PCO.Regs;
		addr.addr := NIL;
		addr.size := PCLIR.Address;	(*used for ESP/EBP*)
		UseRegister(code, vreg, addr.base)
	END
END UseComplex;

(* AllocateRegI - allocate a real register *)

PROCEDURE AllocateRegI(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT): Register;
VAR  pos: LONGINT;  p: PCLIR.Piece;  info, info1: Address;
BEGIN
	info := SYSTEM.VAL(Address, instr.info);
	IF (info.alias # none) THEN	(*this register is aliased*)
		pos := info.alias;  code.GetPiece(pos, p);  info1 := SYSTEM.VAL(Address, p.instr[pos].info);
		info.i386 := info1.i386;
		ASSERT(instr.dstSize = p.instr[pos].dstSize);
		ASSERT(Owner(info.i386) = Free)
	END;
	IF instr.dstSize IN PCLIR.FloatSize THEN
(*
		ASSERT(info.i386 = none);
*)
		GetFPReg(info.i386, pc)
	ELSIF (info.i386 = none) OR (Owner(info.i386) # Free) THEN	(*no hints or hinted reg not free*)
		GetReg(info.i386, PCLIR.NofBytes(instr.dstSize), pc, RegI)
	ELSE
		GetThisReg(info.i386, pc)
	END;
	IF info.count > 0 THEN
	(*fof: If register has been in use before a procedure call and is now re-allocated after call of procedure it is wrong to take the initial count. Instead, the count
		has to be kept as it was before the procedure call *)
	ELSE
	info.count := instr.dstCount;
	END;
	IF info.count <= 0 THEN FreeReg(info.i386) END;
	IF TraceReg THEN  PCM.LogWLn; PCM.LogWNum(pc); PCM.LogWStr(":  ");  PCM.LogWStr(IReg[info.i386])  END;
	RETURN info.i386
END AllocateRegI;

PROCEDURE AllocateReg(code: PCLIR.Code;  vreg: PCLIR.Register): Register;
VAR  pc: LONGINT;  p: PCLIR.Piece;
BEGIN
	pc := vreg;  code.GetPiece(pc, p);
	RETURN AllocateRegI(code, p.instr[pc], vreg);
END AllocateReg;

PROCEDURE AllocateRegI2(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT;  VAR reg, reg2: Register);
VAR  pos: LONGINT;  p: PCLIR.Piece;  info, info1: Address;
BEGIN
	ASSERT(instr.dstSize = PCLIR.Int64);
	info := SYSTEM.VAL(Address, instr.info);
	IF (info.alias # none) THEN	(*this register is aliased*)
		pos := info.alias;  code.GetPiece(pos, p);  info1 := SYSTEM.VAL(Address, p.instr[pos].info);
		info.i386 := info1.i386;
		info.i3862 := info1.i3862;
		ASSERT(instr.dstSize = p.instr[pos].dstSize);
		ASSERT(Owner(info.i386) = Free)
	END;
	IF (info.i386 = none) OR (Owner(info.i386) # Free) THEN	(*no hints or hinted reg not free*)
		GetReg(info.i386, 4, pc, RegI)
	ELSE
		GetThisReg(info.i386, pc)
	END;
	IF (info.i3862 = none) OR (Owner(info.i3862) # Free) THEN	(*no hints or hinted reg not free*)
		GetReg(info.i3862, 4, pc, RegI)
	ELSE
		GetThisReg(info.i3862, pc)
	END;
	reg := info.i386; reg2 := info.i3862;

	info.count := instr.dstCount;
	IF info.count <= 0 THEN FreeReg(info.i386); FreeReg(info.i3862) END;
	IF TraceReg THEN  PCM.LogWLn; PCM.LogWNum(pc); PCM.LogWStr(":  ");  PCM.LogWStr(IReg[info.i386]);  PCM.LogWStr(IReg[info.i3862])  END;
END AllocateRegI2;

(* AllocateThisReg - allocate ireg *)

PROCEDURE AllocateThisRegI(VAR instr: PCLIR.Instruction;  pc: LONGINT;  ireg: Register);
VAR  info: Address;
BEGIN
	ASSERT(PCLIR.NofBytes(instr.dstSize) = RegisterSize(ireg));
	IF ~(ireg IN {ESP, EBP}) THEN  GetThisReg(ireg, pc)  END;
	info := SYSTEM.VAL(Address, instr.info);  info.i386 := ireg;  info.count := instr.dstCount
END AllocateThisRegI;

PROCEDURE AllocateThisReg(code: PCLIR.Code;  vreg: PCLIR.Register;  ireg: Register);
VAR  pc: LONGINT;  p: PCLIR.Piece;
BEGIN
	IF vreg >= 0 THEN
		pc := vreg;  code.GetPiece(pc, p);
		AllocateThisRegI(p.instr[pc], vreg,  ireg)
	ELSIF (vreg = PCLIR.SP) & (ireg = ESP) THEN	(*ok*)
	ELSIF (vreg = PCLIR.FP) & (ireg = EBP) THEN	(*ok*)
	ELSE
		(* HW-Reg must not be a target *)
		HALT(99)	(*paranoid check*)
	END
END AllocateThisReg;

PROCEDURE AllocateThisRegI2(VAR instr: PCLIR.Instruction;  pc: LONGINT;  ireg, ireg2: Register);
VAR  info: Address;
BEGIN
	ASSERT(instr.dstSize = PCLIR.Int64);
	ASSERT(ireg IN Reg32);
	ASSERT(ireg2 IN Reg32);
	IF ~(ireg IN {ESP, EBP}) THEN  GetThisReg(ireg, pc)  END;
	IF ~(ireg2 IN {ESP, EBP}) THEN  GetThisReg(ireg2, pc)  END;
	info := SYSTEM.VAL(Address, instr.info);  info.i386 := ireg;  info.i3862 := ireg2;  info.count := instr.dstCount
END AllocateThisRegI2;

(*
PROCEDURE AllocateThisReg2(code: PCLIR.Code;  vreg: PCLIR.Register;  ireg, ireg2: Register);
VAR  pc: LONGINT;  p: PCLIR.Piece;
BEGIN
	IF vreg >= 0 THEN
		pc := vreg;  code.GetPiece(pc, p);
		AllocateThisRegI2(p.instr[pc], vreg,  ireg, ireg2)
	ELSE
		(* HW-Reg must not be a target *)
		HALT(99)	(*paranoid check*)
	END
END AllocateThisReg2;
*)

(* ReleaseReg - Free reg. If allocated, move to another register *)

PROCEDURE ReleaseReg(code: PCLIR.Code;  reg: Register;  protect: SET);
VAR owner, pos: PCLIR.Register;  mask: SET;  p: PCLIR.Piece;  src: Register;  info: Address;
BEGIN
	ASSERT(~(reg IN {ESP, EBP}));
	mask := RegI - MakeMask(reg) - protect;
	owner := Owner(reg);
	WHILE owner # Free DO
		IF owner = Splitted THEN
			owner := Owner(reg MOD 8 + AL);
			IF owner = Free THEN
				owner := Owner(reg MOD 8 + AH);
				ASSERT(owner # Free)
			END
		ELSIF owner = Blocked THEN
			owner := Owner(reg MOD 4);
			ASSERT(owner # Free)
		END;

		pos := owner;  code.GetPiece(pos, p);
		info := SYSTEM.VAL(Address, p.instr[pos].info);  src := info.i386;
		GetReg(info.i386, RegisterSize(src), owner, mask);
		FreeReg(src);
		PCO.GenMOV(PCO.RegReg, info.i386, src, noInx, noScale, noDisp, noImm);
		IF TraceReg THEN
			PCM.LogWLn; PCM.LogWStr("Spill reg ");
			PCM.LogWNum(owner); PCM.LogWStr(": "); PCM.LogWNum(src); PCM.LogWStr(" -> "); PCM.LogWNum(info.i386)
		END;
		owner := Owner(reg)
	END
END ReleaseReg;

PROCEDURE ForceRegister(code: PCLIR.Code;  VAR reg: Register;  dest: Register;  protect: SET);
BEGIN
	IF reg # dest THEN
		ReleaseReg(code, dest, protect+MakeMask(reg));
		PCO.GenMOV(PCO.RegReg, dest, reg, noInx, noScale, noDisp, noImm);
		reg := dest
	END
END ForceRegister;

PROCEDURE FixAbsolute(adr: PCM.Attribute;  offset: LONGINT);
	(* adr info prepared by UseComplexI *)
BEGIN
	IF adr = NIL THEN
		(*skip*)
	ELSIF adr IS PCBT.GlobalVariable THEN
		PCBT.context.UseVariable(adr(PCBT.GlobalVariable), PCO.pc+offset)
	ELSIF adr IS PCBT.Procedure THEN
		PCBT.context.UseProcedure(adr(PCBT.Procedure), PCO.pc+offset)
	ELSE	HALT(99)
	END
END FixAbsolute;

(* Code Generation Procedures *)

(* GenEnter - Create Procedure activation frame of given size and clear the stack *)

PROCEDURE GenEnter(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  size, L, i: LONGINT;  padr: PCBT.Procedure (* ug *); adr: PCBT.Attribute (* ug *);

	PROCEDURE SetAddress(proc: PCBT.Procedure);
	VAR pos, dw: LONGINT;
	BEGIN
		WITH proc: PCBT.Procedure DO
			IF proc.fixlist # PCBT.FixupSentinel THEN	(*patch the fixlist*)
				pos := proc.fixlist; proc.fixlist := PCBT.FixupSentinel;
				REPEAT
					PCO.GetDWord(pos, dw); PCO.PutDWordAt(pos, PCO.pc - 4 - pos);
					pos := dw
				UNTIL pos = PCBT.FixupSentinel
			END
		END
	END SetAddress;

BEGIN
	IF instr.adr IS PCBT.Procedure THEN (* ug *)
		padr := instr.adr(PCBT.Procedure);
		PCBT.context.AddOwnProc(padr, PCO.pc);
		SetAddress(padr);
		size := padr.locsize;
		adr := padr;
	ELSIF instr.adr IS PCBT.Module THEN
		size := 0;
		adr := instr.adr(PCBT.Module)
	END; (* ug *)
	IF (instr.val = PCBT.OberonCC) OR (instr.val = PCBT.WinAPICC) OR (instr.val= PCBT.CLangCC) (* fof for Linux *) THEN (* ejz *)
		ASSERT(size MOD 4 = 0, 100);
		size := size DIV 4;		(* number of DOUBLE WORDS to be allocated *)
		PCO.GenPUSH(PCO.Regs, EBP, noBase, noInx, noScale, noDisp, noImm);
		PCO.GenMOV(PCO.RegReg, EBP, ESP, noInx, noScale, noDisp, noImm);
		IF (PCM.FullStackInit IN PCM.codeOptions) & (size >= 8) THEN
			PCO.GenMOV(PCO.ImmReg, ECX, noBase, noInx, noScale, noDisp, size DIV 4);
			PCO.GenTyp1 (PCO.XOR, PCO.RegReg, EAX, EAX, noInx, noScale, noDisp, noImm);
			i := size MOD 4;
			WHILE i > 0 DO
				PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);  DEC(i)
			END;
			L := PCO.pc;
			PCO.GenDEC(PCO.ImmReg, ECX, noBase, noInx, noScale, noDisp);
			PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenJcc (PCO.JNZ, L - (PCO.pc + 2))
		ELSIF (PCM.FullStackInit IN PCM.codeOptions) & (size > 0) THEN
			PCO.GenTyp1 (PCO.XOR, PCO.RegReg, EAX, EAX, noInx, noScale, noDisp, noImm);
			WHILE size > 0 DO
				PCO.GenPUSH(PCO.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);  DEC(size)
			END;
		ELSIF size > 0 THEN
			PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, size*4)
		END;
		IF (instr.val = PCBT.WinAPICC) OR (instr.val = PCBT.CLangCC)(* fof for Linux *)  THEN (* ejz *)
			PCO.GenPUSH(PCO.Regs, EBX, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, EDI, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, ESI, noBase, noInx, noScale, noDisp, noImm)
		END
	ELSIF instr.val = PCBT.OberonPassivateCC THEN
		PCO.GenPUSH(PCO.Regs, EBP, noBase, noInx, noScale, noDisp, noImm);
		PCO.GenMOV(PCO.MemReg, EBP, ESP, noInx, noScale, 8, noImm)
	ELSE
		HALT(99)
	END;
	IF adr # NIL THEN adr.SetBeginOffset(PCO.pc) END;
	FreeAll
END GenEnter;

(* GenExit - Remove procedure activation frame, remove the give size of parameters and return to the caller *)

PROCEDURE GenExit(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  size: LONGINT;
BEGIN
	IF instr.adr # NIL  THEN (* ug *)
		instr.adr(PCBT.Attribute).SetEndOffset(PCO.pc)
	END;
	IF (instr.val = PCBT.OberonCC) OR (instr.val = PCBT.WinAPICC) OR (instr.val = PCBT.CLangCC)(* fof for Linux *) THEN (* ejz *)
		size := instr.src1;
		ASSERT(size MOD 4 = 0, 100);
		IF (instr.val = PCBT.WinAPICC) OR (instr.val = PCBT.CLangCC) (* fof for Linux *) THEN (* ejz *)
			PCO.GenPOP(PCO.Regs, ESI, noBase, noInx, noScale, noDisp);
			PCO.GenPOP(PCO.Regs, EDI, noBase, noInx, noScale, noDisp);
			PCO.GenPOP(PCO.Regs, EBX, noBase, noInx, noScale, noDisp)
		END;
		PCO.GenMOV(PCO.RegReg, ESP, EBP, noInx, noScale, noDisp, noImm);
		PCO.GenPOP(PCO.Regs, EBP, noBase, noInx, noScale, noDisp);
		IF instr.val # PCBT.CLangCC THEN  (* fof for Linux *)
		PCO.GenRET(size)
		ELSE (* fof for Linux *)
			PCO.GenRET(0);
		END;
	ELSIF instr.val = PCBT.OberonPassivateCC THEN
		PCO.GenPOP(PCO.Regs, EBP, noBase, noInx, noScale, noDisp);
		PCO.GenRET(4)
	ELSE
		HALT(99)
	END;
	(* CheckAllFree; *)
END GenExit;

(* GenTrap - Implementation for trap, tcc *)

PROCEDURE GenTrap(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  op: PCLIR.Opcode; src1, src2: RealAddress;
BEGIN
	op := instr.op;
	IF op # PCLIR.trap THEN
		UseComplex(code, instr.src1, src1);  UseComplex(code, instr.src2, src2);
		ASSERT(src1.size IN PCLIR.IntSize - {PCLIR.Int64});
		GenCmp1(code, src1, src2);
		PCO.GenJcc(TccOpcode[op-PCLIR.tae], 3)
	END;
	PCO.GenPUSH(PCO.Imme, EAX (*gives size!*), noBase, noInx, noScale, noDisp, instr.val);
	PCO.PutByte(0CCH);		(* INT 3 *)
END GenTrap;

PROCEDURE GetRegSaveSize(): LONGINT;		(* fld *)
VAR s: LONGINT; i: Register;  t: PCLIR.Register;
BEGIN
	s := 0;
	IF FSP >= 0 THEN  s := (FSP+1)*8 END;
	FOR i := EAX TO EDI DO
		IF ~(i IN {EBP, ESP}) THEN
			t := Owner(i);
			IF t # Free THEN  INC( s, 4 ) END
		END
	END;
	RETURN s
END GetRegSaveSize;

PROCEDURE GenSaveRegistersAligned(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);	(* fld *)
VAR rss, gap: LONGINT;
BEGIN
	PCO.GenTyp1( PCO.AND, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, -16 );	(* align stack to 16 byte boundary *)
	rss := GetRegSaveSize();
	gap := (16 - rss MOD 16) MOD 16;
	IF gap # 0 THEN
		PCO.GenTyp1( PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, gap );
	END;
	GenSaveRegisters( code, instr, pc )
END GenSaveRegistersAligned;


(*
	Saved Registers are in the SavedRegisters structure.
	* vreg0: 32/16/8(LSB) bits virtual register pushed
	* vreg1: 8 (MSB) bits virtual register pushed
	* freg: FPU register

	not used = Free
	Warning: vreg0 may be Free but vreg1 not!
*)


PROCEDURE GenSaveRegisters(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR pos, i: Register;  t: PCLIR.Register;
BEGIN
	ASSERT((instr.op = PCLIR.saveregs)OR (instr.op = PCLIR.saveregsaligned) );	(* fld *)
(*PCM.LogWLn; PCM.LogWStr("SaveRegs:");*)
	(*save float regs*)
	pos := 0;
	IF FSP >= 0 THEN	(*allocate Stack*)
		PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, (FSP+1)*8);
		WHILE FSP >= 0 DO
			PCO.GenFSTP(PCO.RegMem, PCO.lReal, ESP, noInx, noScale, 8*FSP);
			SavedRegisters[SaveLevel, FSP].freg := regFP[FSP];
			regFP[FSP] := Free;
			INC(pos); DEC(FSP)
		END
	END;

	pos := 0;
	FOR i := EAX TO EDI DO
		IF ~(i IN {EBP, ESP}) THEN
			t := Owner(i);
			IF t # Free THEN
				IF t = Splitted THEN
					t := Owner(i+AL);
					IF  t # Free  THEN
						FreeReg(i+AL)
					END;
					SavedRegisters[SaveLevel, pos].vreg0 := t;
					t := Owner(i+AH);
					IF t # Free THEN
						FreeReg(i+AH)
					END;
					SavedRegisters[SaveLevel, pos].vreg1 := t
				ELSE
					FreeReg(i);
					SavedRegisters[SaveLevel, pos].vreg0 := t;
					SavedRegisters[SaveLevel, pos].vreg1 := Free
				END;
				PCO.GenPUSH(PCO.Regs, i, noBase, noInx, noScale, noDisp, noImm);
				INC(pos)
			END;
		END
	END;
	FOR i := pos TO 7 DO
		SavedRegisters[SaveLevel, i].vreg0 :=  Free;
		SavedRegisters[SaveLevel, i].vreg1 :=  Free
	END;
	(* CheckAllFree; *)
	(* INC(SaveLevel); *)
	IncSaveLevel;
END GenSaveRegisters;

PROCEDURE GenRestoreRegisters(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR vreg0, vreg1, saved: PCLIR.Register;  reg, dummy: Register;  size, pos: LONGINT;
BEGIN
	ASSERT(instr.op = PCLIR.loadregs);
	DEC(SaveLevel);
	pos := 5;
	WHILE pos >= 0 DO
		vreg0 := SavedRegisters[SaveLevel, pos].vreg0;
		vreg1 := SavedRegisters[SaveLevel, pos].vreg1;
		IF (vreg0 # Free) OR (vreg1 # Free) THEN
			size := 1;
			IF vreg0 # Free THEN
				size := PCLIR.NofBytes(PCLIR.SizeOf(code, vreg0))
			END;
			IF size IN {2, 4} THEN
				(* always pop 32-bit register, even when only 16-bit data required. POP with 16 is troublesome *)
				reg := AllocateReg(code, vreg0) MOD 8
			ELSIF size = 1 THEN	(*A whole 32-bit register must be used for pop; get free reg, without allocating it!*)
				GetTempReg32(reg);
				IF vreg0 # Free THEN  AllocateThisReg(code, vreg0, reg+AL)  END;
				IF vreg1 # Free THEN  AllocateThisReg(code, vreg1, reg+AH)  END
			ELSE HALT(99)
			END;
			PCO.GenPOP(PCO.Regs, reg, noBase, noInx, noScale, noDisp)
		END;
		DEC(pos)
	END;
	IF SavedRegisters[SaveLevel, 0].freg # 0 THEN
		saved := Free;
		IF FSP = 0 THEN
			PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, 8);
			PCO.GenFSTP(PCO.RegMem, PCO.lReal, ESP, noInx, noScale, 0);
			saved := regFP[0];
			FreeReg(24+0)
		END;
		ASSERT(FSP = -1);
		pos := 0;
		WHILE SavedRegisters[SaveLevel, pos].freg # 0 DO
			IF saved # Free THEN
				PCO.GenFLD(PCO.Mem, PCO.lReal, ESP, noInx, noScale, 8*(pos+1))
			ELSE
				PCO.GenFLD(PCO.Mem, PCO.lReal, ESP, noInx, noScale, 8*pos)
			END;
			dummy := AllocateReg(code, SavedRegisters[SaveLevel, pos].freg);
			SavedRegisters[SaveLevel, pos].freg := Free;
			INC(pos)
		END;
		IF saved # Free THEN
			dummy := AllocateReg(code, saved);
			PCO.GenFLD(PCO.Mem, PCO.lReal, ESP, noInx, noScale, 0);
			INC(pos)
		END;
		PCO.GenTyp1(PCO.ADD, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, pos*8)
	END
END GenRestoreRegisters;

PROCEDURE GenPop(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR reg: Register;
BEGIN
	ASSERT(instr.dstSize IN PCLIR.IntSize);
	reg := AllocateRegI(code, instr, pc);
	PCO.GenPOP(PCO.Regs, reg, noBase, noInx, noScale, noDisp)
END GenPop;

(* GenResult - Allocate the registers for functions results (after a call) *)

PROCEDURE GenResult(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  size: PCLIR.Size;  reg: Register;
BEGIN
	size := instr.dstSize;
	IF size IN PCLIR.FloatSize THEN
		reg := AllocateRegI(code, instr, pc)
	ELSIF size = PCLIR.Int64 THEN
		AllocateThisRegI2(instr, pc, EAX, EDX)
	ELSIF instr.op = PCLIR.result THEN
		AllocateThisRegI(instr, pc, RegisterA(size))
	ELSIF instr.op = PCLIR.result2 THEN
		AllocateThisRegI(instr, pc, RegisterD(size))
	ELSE
		HALT(99)
	END
END GenResult;

(* GenReturn - Pass a value to the caller *)

PROCEDURE GenReturn(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  reg: Register;  info: Address;  p: PCLIR.Piece;  pos: LONGINT;  size: PCLIR.Size; src: RealAddress;
BEGIN
	pos := instr.src1;  code.GetPiece(pos, p);  info := SYSTEM.VAL(Address, p.instr[pos].info);
	size := p.instr[pos].dstSize;
	IF size IN PCLIR.FloatSize THEN
		ASSERT(instr.op = PCLIR.ret);
		ASSERT(info.i386 = 24 + FSP)	(*must be ST(0)*)
	ELSIF size = PCLIR.Int64 THEN
		UseComplexI(code, p.instr[pos], src);
		ASSERT(src.mode = PCO.Regs);
		ForceRegister(code, src.base, EAX, {EDX}+MakeMask(src.base2));
		ForceRegister(code, src.base2, EDX, {EAX});
		RETURN
	ELSE
		IF instr.op = PCLIR.ret THEN
			reg := RegisterA(size)
		ELSE
			ASSERT(instr.op = PCLIR.ret2);
			reg := RegisterD(size)
		END;
		IF reg # info.i386 THEN
			ReleaseReg(code, reg, {});
			pc := Owner(info.i386);
			FreeReg(info.i386);
			GetThisReg(reg, pc);
			PCO.GenMOV(PCO.RegReg, reg, info.i386, noInx, noScale, noDisp, noImm);
			info.i386 := reg
		END
	END;
	UseRegisterI(p.instr[pos], reg);	(*ignore, use only to anchor the return register*)
END GenReturn;

(* LoadReg - Load a complex src into a register *)

PROCEDURE LoadReg(reg: Register; src: RealAddress);
BEGIN
	IF reg IN RegFP THEN
		ASSERT(reg-24 = FSP);	(*Top of FPStack*)
		ASSERT(src.mode IN {PCO.Mem, PCO.MemA});
		PCO.GenFLD(src.mode, FPSize[src.size], src.base, src.index, src.scale, src.disp)
	ELSIF (src.mode = PCO.Imme) & (src.addr # NIL) THEN
		PCO.GenLEA(src.addr # NIL, reg, noBase, noInx, noScale, src.imm)
	ELSIF (src.mode = PCO.Imme) & (src.imm = 0)THEN
		PCO.GenTyp1(PCO.XOR, PCO.RegReg, reg, reg, noInx, noScale, noDisp, noImm)
	ELSE
		PCO.GenMOV(src.mode, reg, src.base, src.index, src.scale, src.disp, src.imm)
	END;
	FixAbsolute(src.addr, -4)
END LoadReg;

PROCEDURE LoadRegHi(reg: Register; src: RealAddress);
BEGIN
	ASSERT(reg IN RegI);
	ASSERT((src.mode # PCO.Imme) OR (src.addr = NIL));
	IF (src.mode = PCO.Imme) & (src.imm = 0)THEN
		PCO.GenTyp1(PCO.XOR, PCO.RegReg, reg, reg, noInx, noScale, noDisp, noImm)
	ELSE
		PCO.GenMOV(src.mode, reg, src.base2, src.index, src.scale, src.disp+4, src.imm2)
	END;
	FixAbsolute(src.addr, -4)
END LoadRegHi;

(* GenLoad - Load / Lea implementation *)

PROCEDURE GenLoad(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  addr: RealAddress;  op: PCLIR.Opcode;  reg, reg2: Register;  info: Address;
BEGIN
	op := instr.op;
	ASSERT((op=PCLIR.load) OR (op=PCLIR.loadc));
	IF instr.dstSize = PCLIR.Int64 THEN
		AllocateRegI2(code, instr, pc, reg, reg2);	(*allocate before using to avoid overwriting a register*)
		UseComplexI(code, instr, addr);		(*exception 1, instr.addr contains the source*)
		LoadReg(reg, addr); LoadRegHi(reg2, addr)
	ELSE
		UseComplexI(code, instr, addr);		(*exception 1, instr.addr contains the source*)
		reg := AllocateRegI(code, instr, pc);
		LoadReg(reg, addr)
	END;
	ASSERT(instr.dstSize = addr.size);
	info := SYSTEM.VAL(Address, instr.info);
	info.mode := 0;	(*Register=pc*)
END GenLoad;

PROCEDURE GenLoadSP(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR src: RealAddress;
BEGIN
	UseComplex(code, instr.src1, src);
	IF (src.mode # PCO.Regs) OR (src.base # ESP) THEN	(* source already in ESP *)
		LoadReg(ESP, src);
	END
END GenLoadSP;

PROCEDURE GenLoadFP(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR src: RealAddress;
BEGIN
	UseComplex(code, instr.src1, src);
	IF (src.mode # PCO.Regs) OR (src.base # EBP) THEN	(* source already in EBP *)
		LoadReg(EBP, src);
	END
END GenLoadFP;

PROCEDURE GenStore(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  src, dst: RealAddress;
BEGIN
	ASSERT(instr.op = PCLIR.store, 100);
	UseComplex(code, instr.src2, src);  ASSERT(src.mode IN {PCO.Regs, PCO.Imme, PCO.ImmeA, PCO.Mem, PCO.MemA}, 101);
	UseComplexI(code, instr, dst);  ASSERT(dst.mode IN {PCO.Regs, PCO.Mem, PCO.MemA}, 102);
	ASSERT( ~(dst.mode IN {PCO.Mem, PCO.MemA} ) OR (src.mode IN {PCO.Regs, PCO.Imme, PCO.ImmeA}), 103);
	IF src.size IN PCLIR.FloatSize THEN
		ASSERT(src.mode = PCO.Regs);
		ASSERT(dst.mode # PCO.ImmeA);
		PCO.GenFSTP(dst.mode+(PCO.RegMem-PCO.Mem), FPSize[src.size], dst.base, dst.index, dst.scale, dst.disp);
		FixAbsolute(dst.addr, -4);
		PCO.PutByte(PCO.wWAIT)
	ELSIF src.size = PCLIR.Int64 THEN
		IF dst.mode = PCO.Regs THEN
			HALT(99)
		ELSIF src.mode IN {PCO.Imme, PCO.ImmeA} THEN
			PCO.GenMOV(dst.mode+(PCO.ImmMem-PCO.Mem), src.base, dst.base, dst.index, dst.scale, dst.disp, src.imm);
			FixAbsolute(dst.addr, -4-RegisterSize(src.base));	(*MOV r/m, imm: compensate imm size*)
			FixAbsolute(src.addr, -4);
			PCO.GenMOV(dst.mode+(PCO.ImmMem-PCO.Mem), src.base2, dst.base2, dst.index, dst.scale, dst.disp+4, src.imm2);
			FixAbsolute(dst.addr, -4-RegisterSize(src.base2));	(*MOV r/m, imm: compensate imm size*)
			FixAbsolute(src.addr, -4)
		ELSE
			dst.mode := dst.mode+(PCO.RegMem-PCO.Mem);
			LoadReg(src.base, dst);
			LoadRegHi(src.base2, dst);
		END
	ELSIF dst.mode = PCO.Regs THEN
		LoadReg(dst.base, src);
	ELSIF src.mode IN {PCO.Imme, PCO.ImmeA} THEN
		PCO.GenMOV(dst.mode+(PCO.ImmMem-PCO.Mem), src.base, dst.base, dst.index, dst.scale, dst.disp, src.imm);
		FixAbsolute(dst.addr, -4-RegisterSize(src.base));	(*MOV r/m, imm: compensate imm size*)
		FixAbsolute(src.addr, -4)
	ELSE
		dst.mode := dst.mode+(PCO.RegMem-PCO.Mem);
		LoadReg(src.base, dst);
	END;
END GenStore;

PROCEDURE GenOut(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
	(* src1 = portnr, src2 = value *)
VAR  src: RealAddress;  value, port: Register;
BEGIN
	UseComplex(code,  instr.src2, src); ASSERT(src.mode = PCO.Regs);
	value := RegisterA(src.size);
	ForceRegister(code, src.base, value, {DX});

	UseRegister(code, instr.src1, port);
	ForceRegister(code, port, DX, {value});
	PCO.GenOUT(value)
END GenOut;

PROCEDURE GenIn(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
	(* src1 = portnr *)
VAR  value, port: Register;
BEGIN
	value := RegisterA(instr.dstSize);
	UseRegister(code, instr.src1, port);
	ForceRegister(code, port, DX, {value});
	ReleaseReg(code, value, {DX});
	PCO.GenIN(value);
	AllocateThisRegI(instr, pc, value);
END GenIn;

PROCEDURE GenNop(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
BEGIN  PCO.PutByte(90H)
END GenNop;

PROCEDURE GenLabel(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  info: Address;  next: LONGINT;
BEGIN
	info := SYSTEM.VAL(Address, instr.info);
	info.imm := PCO.pc;
	pc := info.disp;
	WHILE pc > none (*fof # -> > *) DO
		PCO.GetDWord(pc, next);  PCO.PutDWordAt(pc, PCO.pc-pc-4);
		pc := next - 10000H
	END;
	IF instr.val # 0 THEN  PCO.errpos := instr.val  END;

	IF (instr.op = PCLIR.finallylabel) THEN
		IF (instr.adr # NIL) THEN
			IF (instr.adr IS PCBT.Procedure) THEN
				instr.adr(PCBT.Procedure).finallyOff := info.imm;
			ELSIF (instr.adr IS PCBT.Module) THEN
				instr.adr(PCBT.Module).finallyOff := info.imm;
			END;
		END;
	END;

END GenLabel;

PROCEDURE EmitJcc(op: SHORTINT;  dest: LONGINT;  VAR chain: LONGINT);
BEGIN
	IF dest = 0 THEN	(*fwd jmp*)
		PCO.GenJcc(op, chain+10000H);
		chain := PCO.pc-4
	ELSIF PCO.pc - dest <= 126 THEN	(*near jmp*)
		PCO.GenJcc(op, dest - PCO.pc - 2)	(* jcc Rel8:  has 2 bytes*)
	ELSE
		PCO.GenJcc(op, dest - PCO.pc - 6)	(* jcc Rel32:  has 6 bytes*)
	END
END EmitJcc;

PROCEDURE GenJcc(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  info: Address;  pos, fix: LONGINT;  p: PCLIR.Piece;  jcc: SHORTINT; src1, src2: RealAddress;
BEGIN
	UseComplex(code, instr.src1, src1);  UseComplex(code, instr.src2, src2);
	pos := instr.val; code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);
	fix := none;
	IF src1.size = PCLIR.Int64 THEN
		ASSERT((instr.op >= PCLIR.je) & (instr.op <= PCLIR.jge));
		(*compare upper dw*)
		GenCmp2(code, src1, src2);
		jcc := Jcc2Opcode[instr.op-PCLIR.je, 0];	(*hit*)
		IF jcc # 0 THEN EmitJcc(jcc, info.imm, info.disp) END;
		jcc := Jcc2Opcode[instr.op-PCLIR.je, 1];	(*fail*)
		IF jcc # 0 THEN EmitJcc(jcc, 0, fix) END;
		(*compare lower dw*)
		GenCmp1(code, src1, src2);
		jcc := Jcc2Opcode[instr.op-PCLIR.je, 2];	(*hit*)
		EmitJcc(jcc, info.imm, info.disp);
		IF fix # none THEN PCO.PutDWordAt(fix, PCO.pc - fix - 4) END
	ELSIF (instr.op = PCLIR.jf) OR (instr.op = PCLIR.jnf) THEN
		GenBitTest(code, src1, src2);
		jcc := JccOpcode[instr.op-PCLIR.je, CCTableSwitch];
		EmitJcc(jcc, info.imm, info.disp);
	ELSE
		GenCmp1(code, src1, src2);
		jcc := JccOpcode[instr.op-PCLIR.je, CCTableSwitch];
		EmitJcc(jcc, info.imm, info.disp);
	END;
END GenJcc;

PROCEDURE GenJmp(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  info: Address;  pos: LONGINT;  p: PCLIR.Piece;
BEGIN
	pos := instr.val; code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);
	IF info.imm = 0 THEN	(*fwd jmp*)
		PCO.GenJMP(PCO.Imme, noBase, noBase, noInx, noScale, info.disp+10000H);
		info.disp := PCO.pc-4
	ELSIF PCO.pc - info.imm <= 126 THEN	(*near jmp*)
		PCO.GenJMP(PCO.Imme, noBase, noBase, noInx, noScale, info.imm - PCO.pc - 2)
	ELSE
		PCO.GenJMP(PCO.Imme, noBase, noBase, noInx, noScale, info.imm - PCO.pc - 5)
	END
END GenJmp;

PROCEDURE GenCall(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  adr: PCBT.Procedure;
BEGIN
	adr := instr.adr(PCBT.Procedure);
	IF (adr.owner # PCBT.context) THEN	(* external procedure *)
		PCO.GenCALL(PCO.ImmeA, 0, noBase, noInx, noScale, 0);
		PCBT.context.UseProcedure(adr, PCO.pc-4)
	ELSIF adr.codeoffset # 0 THEN
		PCO.GenCALL(PCO.Imme, 0, noBase, noInx, noScale, adr.codeoffset - PCO.pc - 5)
	ELSE	(*local call*)
		PCO.GenCALL(PCO.Imme, 0, noBase, noInx, noScale, adr.fixlist);
		adr.fixlist := PCO.pc-4
(*
	ELSE	(* external procedure *)
		PCO.GenCALL(PCO.ImmeA, 0, noBase, noInx, noScale, 0);
		PCBT.context.UseProcedure(adr, PCO.pc-4)
*)
	END
END GenCall;

PROCEDURE GenCallReg(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  src: RealAddress;  mode: SHORTINT;
BEGIN
	UseComplex(code, instr.src1, src);
	mode := src.mode;
	ASSERT(mode IN {PCO.Regs, PCO.Mem, PCO.MemA});
	PCO.GenCALL(mode, src.base, src.base, src.index, src.scale, src.disp);
	FixAbsolute(src.addr, -4)
END GenCallReg;

PROCEDURE GenSysCall(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
BEGIN
	PCO.GenCALL(PCO.ImmeA, 0, noBase, noInx, noScale, 0);
	PCBT.context.UseSyscall(instr.val, PCO.pc-4)
END GenSysCall;

PROCEDURE GenSetcc(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  reg: Register;  jcc, op: SHORTINT; src1, src2: RealAddress; true1, true2, false: LONGINT;
BEGIN
	UseComplex(code, instr.src1, src1);  UseComplex(code, instr.src2, src2);
	IF src1.size = PCLIR.Int64 THEN
		false := 0; true1 := 0; true2 := 0; (* fof, variables were not initialized, even not implicitly by EmitJcc ! *)
		reg := AllocateRegI(code, instr, pc);
		GenCmp2(code, src1, src2);
		jcc := Jcc2Opcode[instr.op-PCLIR.sete, 0];	(*hit*)
		IF jcc # 0 THEN EmitJcc(jcc, 0, true1) END;
		jcc := Jcc2Opcode[instr.op-PCLIR.sete, 1];	(*fail*)
		IF jcc # 0 THEN EmitJcc(jcc, 0, false) END;
		(*compare lower dw*)
		GenCmp1(code, src1, src2);
		jcc := Jcc2Opcode[instr.op-PCLIR.sete, 2];	(*hit*)
		EmitJcc(jcc, 0, true2);
		IF false # 0 THEN PCO.PutDWordAt(false, PCO.pc - false - 4) END; (* fof: false # none -> false # 0 *)
		PCO.GenTyp1(PCO.XOR, PCO.RegReg, reg, reg, noInx, noScale, noDisp, noImm);
		PCO.GenJMP(PCO.Imme, noBase, noBase, noInx, noScale, 0); false := PCO.pc-1;
		IF true1 # 0 THEN PCO.PutDWordAt(true1, PCO.pc - true1 - 4) END;
		IF true2 # 0 THEN PCO.PutDWordAt(true2, PCO.pc - true2 - 4) END;
		PCO.GenMOV(PCO.ImmReg, reg, reg, noInx, noScale, noDisp, 1);
		PCO.PutByteAt(false, SHORT(SHORT(PCO.pc-false-1)));
	ELSIF (instr.op = PCLIR.setf) OR (instr.op = PCLIR.setnf) THEN
		reg := AllocateRegI(code, instr, pc);
		GenBitTest(code, src1, src2);
		op := JccOpcode[instr.op-PCLIR.sete, CCTableSwitch];
		PCO.GenSetcc(op, PCO.Regs, reg, noInx, noScale, noDisp)
	ELSE
		(*
			WARNING: do not allocate the destination register before GenCmp1.
			GenCmp1 for floats needs AX to store the flags; if the destination is EAX (like when returning
			a comparison) GenCmp1 will spill the register. The result would be still stored in EAX, and
			then could be overwritten with the spilled (but not set) register in GenRet
		*)
		GenCmp1(code, src1, src2);
		reg := AllocateRegI(code, instr, pc);
		op := JccOpcode[instr.op-PCLIR.sete, CCTableSwitch];
		PCO.GenSetcc(op, PCO.Regs, reg, noInx, noScale, noDisp)
	END;
END GenSetcc;

PROCEDURE GenKill(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  pos: LONGINT;  p: PCLIR.Piece;  reg: Register;  info: Address;
BEGIN
	(*kill a register, used in conjunction with phi*)
	pos := instr.src1;  code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);
	UseRegisterI(p.instr[pos], reg);	(*register used*)

	pos := info.alias;
	IF pos # none THEN
		code.GetPiece(pos, p);
		info := SYSTEM.VAL(Address, p.instr[pos].info);
		IF reg # info.i386 THEN
			ReleaseReg(code, info.i386, {});
			PCO.GenMOV(PCO.RegReg, info.i386, reg, noInx, noScale, noDisp, noImm)
		END
	END;
(*
	FreeReg(reg);
*)
END GenKill;

PROCEDURE GenPhi(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  reg: Register;
BEGIN
	reg := AllocateRegI(code, instr, pc)
END GenPhi;

PROCEDURE GenPush(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  dst: RealAddress;  reg: Register;  size: LONGINT;
BEGIN
	UseComplex(code, instr.src1, dst);
	size := PCLIR.NofBytes(dst.size);
	IF dst.mode IN {PCO.Mem, PCO.MemA} THEN
		IF dst.size IN {PCLIR.Int16, PCLIR.Int64, PCLIR.Float32, PCLIR.Float64} THEN  dst.size := PCLIR.Int32  END;
		IF size = 8 THEN INC(dst.disp, 4) END;
		WHILE size > 0 DO
			PCO.GenPUSH(dst.mode, RegisterA(dst.size), dst.base, dst.index, dst.scale, dst.disp, dst.imm);
			FixAbsolute(dst.addr, -4);
			DEC(dst.disp, 4); DEC(size, 4)
		END
	ELSIF dst.size IN PCLIR.FloatSize THEN
		PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, size);	(*allocate*)
		PCO.GenFSTP(PCO.RegMem, FPSize[dst.size], ESP, noInx, noScale, 0);	(*FSTP 0[ESP]*)
	ELSE
		IF dst.size = PCLIR.Int8 THEN
			IF dst.base IN Reg8H THEN
				GetReg(reg, 1, pc, Reg8L);
				PCO.GenMOV(PCO.RegReg, reg, dst.base, noInx, noScale, noDisp, noImm);
				dst.base := reg;
				FreeReg(reg)
			END;
		ELSIF PCLIR.Int16 = dst.size THEN  dst.base := dst.base MOD 8
		END;
		IF dst.size = PCLIR.Int64 THEN
			PCO.GenPUSH(dst.mode, dst.base2, dst.base, dst.index, dst.scale, dst.disp+4, dst.imm2);
			FixAbsolute(dst.addr, -4)
		END;
		PCO.GenPUSH(dst.mode, dst.base, dst.base, dst.index, dst.scale, dst.disp, dst.imm);
		FixAbsolute(dst.addr, -4)
	END
END GenPush;

PROCEDURE IntExpansion(op: PCLIR.Opcode;  src: RealAddress;  dst: Register);
VAR t: SHORTINT;  size: LONGINT;
BEGIN
	size := PCLIR.NofBytes(src.size);
	IF size = 1 THEN  t := 0  ELSE  t := 1  END;
	IF op = PCLIR.convs THEN	(*signed extension*)
		PCO.GenMOVSX(src.mode, t, dst, src.base, src.index, src.scale, src.disp);
		FixAbsolute(src.addr, -4)
	ELSIF RegisterOverlaps(dst, src.base) OR RegisterOverlaps(dst, src.index) THEN
		PCO.GenMOVZX(src.mode, t, dst, src.base, src.index, src.scale, src.disp);
		FixAbsolute(src.addr, -4)
	ELSE
		(* optimize pattern: Pentium Manual, 24.5 /3 (p.24-4)*)
		dst := dst MOD 8;
		PCO.GenTyp1(PCO.XOR, PCO.RegReg, dst, dst, noInx, noScale, noDisp, noImm);
		IF size = 1 THEN INC(dst, AL)  ELSE  INC(dst, AX)  END;
		LoadReg(dst, src);
(*
		PCO.GenMOV(src.mode, dst, src.base, src.index, src.scale, src.disp, src.imm);
*)
	END;
(*
	FixAbsolute(src.addr, -4)
*)
END IntExpansion;

PROCEDURE Entier(dst, dst2: Register; dest64: BOOLEAN);
VAR  reg: Register; size: LONGINT;
BEGIN
	GetTempReg32(reg);
	IF dest64 THEN size := 12 ELSE size := 8 END;
	PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, size);
	PCO.GenFSTCW(ESP, noInx, noScale, 0);
	PCO.PutByte(PCO.wWAIT);
	PCO.GenMOV(PCO.MemReg, reg, ESP, noInx, noScale, 0, noImm);
	PCO.GenTyp1(PCO.AND, PCO.ImmReg, reg, noBase, noInx, noScale, noDisp, 0F3FFH);
	PCO.GenTyp1(PCO.Or, PCO.ImmReg, reg, noBase, noInx, noScale, noDisp, 0400H);
	PCO.GenMOV(PCO.RegMem, reg, ESP, noInx, noScale, 4, noImm);
	PCO.GenFLDCW(ESP, noInx, noScale, 4);
	IF dest64 THEN
		PCO.GenFSTP(PCO.RegMem, PCO.qInt, ESP, noInx, noScale, 4)
	ELSE
		PCO.GenFSTP(PCO.RegMem, PCO.dInt, ESP, noInx, noScale, 4)
	END;
	PCO.PutByte(PCO.wWAIT);
	PCO.GenFLDCW(ESP, noInx, noScale, 0);
	PCO.GenPOP(PCO.Regs, dst, noBase, noInx, noScale, noDisp);
	PCO.GenPOP(PCO.Regs, dst, noBase, noInx, noScale, noDisp);
	IF dest64 THEN PCO.GenPOP(PCO.Regs, dst2, noBase, noInx, noScale, noDisp) END;
END Entier;

PROCEDURE GenConv(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  op: PCLIR.Opcode;  size, bs, bd: LONGINT; reg, reg2, tmp: Register;  src: RealAddress;
BEGIN
	op := instr.op;
	ASSERT((op = PCLIR.convs) OR (op = PCLIR.convu) OR (op = PCLIR.copy));
	UseComplex(code, instr.src1, src);
	bs := PCLIR.NofBytes(src.size); bd := PCLIR.NofBytes(instr.dstSize);
	IF instr.dstSize IN PCLIR.FloatSize THEN
		reg := AllocateRegI(code, instr, pc);
		IF (src.size IN PCLIR.FloatSize) & (src.mode =  PCO.Regs) THEN  RETURN  END;
		IF src.size = PCLIR.Int8 THEN	(* no FILD for byte size available, first expand to double *)
			GetReg(tmp, 4, pc, Reg32);
			FreeReg(tmp);
			IntExpansion(op, src, tmp);
			src.mode := PCO.Regs;  src.base := tmp;  src.size := PCLIR.Int32;
		END;
		IF op = PCLIR.copy THEN  size := instr.dstSize  ELSE  size := src.size  END;
		IF src.mode # PCO.Regs THEN
			PCO.GenFLD(src.mode, FPSize[size], src.base, src.index, src.scale, src.disp);
			FixAbsolute(src.addr, -4);
		ELSIF size IN {PCLIR.Int64, PCLIR.Float64} THEN
			PCO.GenPUSH(PCO.Regs, src.base2, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenPUSH(PCO.Regs, src.base, noBase, noInx, noScale, noDisp, noImm);
			PCO.GenFLD(PCO.Mem, FPSize[size], ESP, noInx, noScale, 0);
			PCO.GenTyp1(PCO.ADD, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, 8)
		ELSE
			PCO.GenPUSH(PCO.Regs, src.base MOD 8, noBase, noInx, noScale, noDisp, noImm);	(*push 32bit reg always*)
			PCO.GenFLD(PCO.Mem, FPSize[size], ESP, noInx, noScale, 0);
			PCO.GenTyp1(PCO.ADD, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4)
		END
	ELSIF src.size IN PCLIR.FloatSize THEN
		IF op = PCLIR.copy THEN
			IF instr.dstSize = PCLIR.Int64 THEN
				AllocateRegI2(code, instr, pc, reg, reg2);
				PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, 8);
				PCO.GenFSTP(PCO.RegMem, PCO.lReal, ESP, noInx, noScale, 0);	(*FSTP quad ptr 0[ESP]*)
				PCO.GenPOP(PCO.Regs, reg, noBase, noInx, noScale, noDisp);
				PCO.GenPOP(PCO.Regs, reg2, noBase, noInx, noScale, noDisp);
			ELSE
				reg := AllocateRegI(code, instr, pc);
				PCO.GenTyp1(PCO.SUB, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4);
				PCO.GenFSTP(PCO.RegMem, PCO.sReal, ESP, noInx, noScale, 0);	(*FSTP double ptr 0[ESP]*)
				IF bd = 2 THEN  reg := reg MOD 8 END;	(*16-> 32 bit*)
				PCO.GenPOP(PCO.Regs, reg, noBase, noInx, noScale, noDisp)
			END
		ELSIF instr.dstSize = PCLIR.Int64 THEN
			AllocateRegI2(code, instr, pc, reg, reg2);
			Entier(reg, reg2, TRUE)
		ELSE
			reg := AllocateRegI(code, instr, pc);
			Entier(reg, none, FALSE)
		END
	ELSIF bd <= bs THEN	(* truncate, dst <= src *)
		ASSERT(src.mode = PCO.Regs, 100);
		reg := src.base;
		IF (bs = bd) OR (bs = 8) & (bd = 4) THEN	(* x -> x *)
			(*skip*)
		ELSIF (bs IN {4, 8}) & (bd = 1) THEN	(* 64/32->8 *)
			INC(reg, AL)
		ELSIF (bs IN {4, 8}) & (bd = 2) THEN	(* 64/32->16 *)
			INC(reg, AX)
		ELSIF (bs = 2) & (bd = 1) THEN	(* 16->8 *)
			INC(reg, AL-AX)
		ELSE
			HALT(99)
		END;
		AllocateThisRegI(instr, pc, reg)
	ELSIF bd = 8 THEN
		IF (Owner(EAX) = Free) & (Owner(EDX) = Free) THEN
			AllocateThisRegI2(instr, pc, EAX, EDX); reg := EAX; reg2 := EDX
		ELSE
			AllocateRegI2(code, instr, pc, reg, reg2)
		END;
		IF bs = 4 THEN
			IF (src.mode # PCO.RegReg) & (src.base # EAX) THEN
				LoadReg(reg, src);
			ELSIF (src.mode = PCO.RegReg) & (src.base # reg) THEN
				PCO.GenMOV(src.mode, reg, src.base, src.index, src.scale, src.disp, noImm)
			END
		ELSE
			IntExpansion(op, src, reg)
		END;
		IF (reg = EAX) & (reg2 = EDX) THEN
			PCO.PutByte(99H)	(* CDQ *)
		ELSE
			PCO.GenMOV(PCO.RegReg, reg2, reg, noInx, noScale, noDisp, noImm);
			PCO.GenShiftRot(PCO.SAR, PCO.ImmReg, reg2, noBase, noInx, noScale, noDisp, 31)
		END
	ELSE
		reg := AllocateRegI(code, instr, pc);
		IntExpansion(op, src, reg)
	END
END GenConv;

PROCEDURE GenNegNot(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR reg, reg2: Register;
BEGIN
	IF instr.dstSize IN PCLIR.FloatSize THEN
		UseRegister(code, instr.src1, reg);
		ASSERT(reg = 25 + FSP, 200);
		ASSERT(instr.op = PCLIR.neg, 201);
		reg := AllocateRegI(code, instr, pc);
		PCO.PutByte(0D9H); PCO.PutByte(0E0H);	(*FCHS*)
	ELSIF instr.dstSize = PCLIR.Int64 THEN
		UseRegister2(code, instr.src1, reg, reg2);
		AllocateThisRegI2(instr, pc, reg, reg2);
		ASSERT(instr.op = PCLIR.neg);
		PCO.GenGroup3(PCO.NEG, PCO.Regs, reg, noBase, noInx, noScale, noDisp);
		PCO.GenTyp1(PCO.ADC, PCO.ImmReg, reg2, noBase, noInx, noScale, noDisp, 0);
		PCO.GenGroup3(PCO.NEG, PCO.Regs, reg2, noBase, noInx, noScale, noDisp)
	ELSE
		UseRegister(code, instr.src1, reg);
		AllocateThisRegI(instr, pc, reg);
		PCO.GenGroup3(Group3Opcode[instr.op-PCLIR.not], PCO.Regs, reg, noBase, noInx, noScale, noDisp)
	END
END GenNegNot;

PROCEDURE GenAbs(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  reg, tmp: Register;  size: LONGINT;
BEGIN
	size := PCLIR.NofBytes(instr.dstSize);
	UseRegister(code, instr.src1, reg);
	IF instr.dstSize IN PCLIR.FloatSize THEN
		ASSERT(reg = 25 + FSP);
		reg := AllocateRegI(code, instr, pc);
		PCO.PutByte(0D9H); PCO.PutByte(0E1H);	(*FABS*)
	ELSE
		CASE size OF
		| 1:
				ForceRegister(code, reg, AL, MakeMask(AH));  tmp := AH;
				PCO.PutByte(66H);  PCO.PutByte(PCO.CBW)
		| 2:
				ForceRegister(code, reg, AX, MakeMask(DX));  tmp := DX;
				PCO.PutByte(66H);  PCO.PutByte(PCO.CWD)
		| 4:
				ForceRegister(code, reg, EAX, MakeMask(EDX));  tmp := EDX;
				PCO.PutByte(PCO.CWD)
		END;
		AllocateThisRegI(instr, pc, reg);
		ReleaseReg(code, tmp, MakeMask(reg));
		PCO.GenTyp1(PCO.XOR, PCO.RegReg, reg, tmp, noInx, noScale, noDisp, noImm);
		PCO.GenTyp1(PCO.SUB, PCO.RegReg, reg, tmp, noInx, noScale, noDisp, noImm)
	END
END GenAbs;

PROCEDURE GenBitOp(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  reg: Register;  src2: RealAddress;  op: SHORTINT;
BEGIN
	UseRegister(code, instr.src1, reg);  AllocateThisRegI(instr, pc, reg);
	UseComplex(code, instr.src2, src2);
	ASSERT(src2.mode IN {PCO.Regs, PCO.Imme});
	op := BitOpcode[instr.op-PCLIR.bts];
	PCO.GenB(op, src2.mode, reg, src2.base, noInx, noScale, noDisp, src2.imm)
END GenBitOp;

PROCEDURE GenBitTest(code: PCLIR.Code;  VAR src1, src2: RealAddress);
	(* Intel: bit number is auto-masked only if source is register!! *)
BEGIN
	ASSERT(src1.mode IN {PCO.Regs, PCO.Mem, PCO.MemA}, 500);
	ASSERT(src2.mode IN {PCO.Regs, PCO.Imme}, 501);
	IF src1.mode = PCO.Regs THEN
		PCO.GenB(PCO.BT, src2.mode, src1.base, src2.base, noInx, noScale, noDisp, src2.imm)
	ELSIF src2.mode = PCO.Regs THEN
		PCO.GenTyp1(PCO.AND, PCO.ImmReg, src2.base, noBase, noInx, noScale, noDisp, 31);
		PCO.GenB(PCO.BT, src1.mode+(PCO.RegMem-PCO.Mem), src2.base, src1.base, src1.index, src1.scale, src1.disp, src2.imm);
		IF src1.addr # NIL THEN  FixAbsolute(src1.addr, -4)  END
	ELSE
		src2.imm := src2.imm MOD 32;
		PCO.GenB(PCO.BT, src1.mode+(PCO.ImmMem-PCO.Mem), noBase, src1.base, src1.index, src1.scale, src1.disp, src2.imm);
		IF src1.addr # NIL THEN FixAbsolute(src1.addr, -5) END
	END
END GenBitTest;

(* GenCmp1 - Compare src1 with src2 *)

PROCEDURE GenCmp1(code: PCLIR.Code; VAR src1, src2: RealAddress);
BEGIN
	CCTableSwitch := intMode;	(*default: integer mode*)
	IF src1.size IN PCLIR.FloatSize THEN
		CCTableSwitch := floatMode;	(*float mode*)
		ASSERT(src1.mode = PCO.Regs);
		IF src2.mode IN {PCO.Mem, PCO.MemA} THEN
			ASSERT(src1.base = 25 + FSP);
			PCO.GenFCOMP(src2.mode, FPSize[src2.size], src2.base, src2.index, src2.scale, src2.disp);
			FixAbsolute(src2.addr, -4)
		ELSIF src1.base > src2.base THEN	(*nice case, cmp ST, ST1*)
			ASSERT(src2.base = 25 + FSP);
			PCO.PutByte(0DEH); PCO.PutByte(0D9H)	(*FCOMPP*)
		ELSE
			(* cmp ST1, ST -> swap registers*)
			ASSERT(src1.base = 25 + FSP);
			ASSERT(src2.base = 26 + FSP);
			PCO.PutByte(0D9H); PCO.PutByte(0C9H);	(*FXCH*)
			PCO.PutByte(0DEH); PCO.PutByte(0D9H)	(*FCOMPP*)
		END;
		ReleaseReg(code, AX, {});
		PCO.PutByte(0DFH); PCO.PutByte(0E0H);	(*FNSTSW AX*)
		PCO.PutByte(09EH);	(*SAHF*)
	ELSIF src1.mode = PCO.Regs THEN
		PCO.GenTyp1(PCO.CMP, src2.mode, src1.base, src2.base, src2.index, src2.scale, src2.disp, src2.imm);
		FixAbsolute(src2.addr, -4)
	ELSIF src1.mode IN {PCO.Mem, PCO.MemA} THEN
		IF src2.mode = PCO.Regs THEN
			PCO.GenTyp1(PCO.CMP, src1.mode+(PCO.RegMem-PCO.Mem), src2.base, src1.base, src1.index, src1.scale, src1.disp, src1.imm);
			FixAbsolute(src1.addr, -4)
		ELSIF src2.mode IN {PCO.Imme, PCO.ImmeA} THEN
			PCO.GenTyp1(PCO.CMP, src1.mode+(PCO.ImmMem-PCO.Mem), src2.base, src1.base, src1.index, src1.scale, src1.disp, src2.imm);
			FixAbsolute(src1.addr, -4-ConstSize(src2.imm, src1.size = PCLIR.Int16));
			FixAbsolute(src2.addr, -4)
		ELSE HALT(99)
		END
	ELSE HALT(99) END;
END GenCmp1;

(* GenCmp2 - Compare higher dw of src1 with src2 *)

PROCEDURE GenCmp2(code: PCLIR.Code; VAR src1, src2: RealAddress);
BEGIN
	ASSERT(src1.size = PCLIR.Int64);
	IF src1.mode = PCO.Regs THEN
		PCO.GenTyp1(PCO.CMP, src2.mode, src1.base2, src2.base2, src2.index, src2.scale, src2.disp+4, src2.imm2);
		FixAbsolute(src2.addr, -4)
	ELSIF src1.mode IN {PCO.Mem, PCO.MemA} THEN
		IF src2.mode = PCO.Regs THEN
			PCO.GenTyp1(PCO.CMP, src1.mode+(PCO.RegMem-PCO.Mem), src2.base2, src1.base2, src1.index, src1.scale, src1.disp+4, src1.imm2);
			FixAbsolute(src1.addr, -4)
		ELSIF src2.mode IN {PCO.Imme, PCO.ImmeA} THEN
			PCO.GenTyp1(PCO.CMP, src1.mode+(PCO.ImmMem-PCO.Mem), src2.base2, src1.base2, src1.index, src1.scale, src1.disp+4, src2.imm2);
			FixAbsolute(src1.addr, -4-ConstSize(src2.imm, src1.size = PCLIR.Int16));
			FixAbsolute(src2.addr, -4)
		ELSE HALT(99)
		END
	ELSE HALT(99) END;
END GenCmp2;

PROCEDURE GenFtyp1(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR src1, src2: RealAddress;  reverse: BOOLEAN;  op: SHORTINT;  reg: Register;
BEGIN
	ASSERT(instr.dstSize IN PCLIR.FloatSize);
	UseComplex(code, instr.src2, src2);  ASSERT(src2.mode IN {PCO.Regs, PCO.Mem, PCO.MemA});		(* higher on FP Stack, first used *)
	UseComplex(code, instr.src1, src1);  ASSERT(src1.mode = PCO.Regs);
	reverse := (src2.mode = PCO.Regs) & (src2.base > src1.base);
	reg := AllocateRegI(code, instr, pc);
	CASE instr.op OF
	|  PCLIR.add:
			op := 0	(*FADD*)
	|  PCLIR.sub:
			IF (src2.mode # PCO.Regs) OR (src2.base < src1.base) THEN
				op := 4
			ELSE
				(*PCM.LogWLn; PCM.LogWStr("GetFtyp1/sub, src2 < src1");*)
				op := 5
			END
	|  PCLIR.mul:
			op := 1
	|  PCLIR.div:
			IF (src2.mode # PCO.Regs) OR (src2.base < src1.base) THEN
				op := 6
			ELSE
				(*PCM.LogWLn; PCM.LogWStr("GetFtyp1/div, src2 > src1");*)
				op := 7
			END
	END;
	IF src2.mode = PCO.Regs THEN
		PCO.GenFtyp1(op, PCO.StRegP, FPSize[instr.dstSize], 1(*ST(1)*), noInx, noScale, noDisp)
	ELSE
		ASSERT(src1.base = 24+FSP);
		PCO.GenFtyp1(op, src2.mode+(PCO.MemSt-PCO.Mem), FPSize[instr.dstSize], src2.base, src2.index, src2.scale, src2.disp);
		IF src2.addr # NIL THEN
			FixAbsolute(src2.addr, -4)
		END
	END
END GenFtyp1;

PROCEDURE GenMul64(src1, src2: RealAddress; dst1, dst2: Register);
	VAR clean: LONGINT;
BEGIN
	ASSERT(dst1 = EAX);
	ASSERT(dst2 = EDX);
(*
	ASSERT(src1.mode # PCO.Imme);
	ASSERT(src1.mode # PCO.ImmeA);
	ASSERT(src2.mode # PCO.Imme);
	ASSERT(src2.mode # PCO.ImmeA);
*)
	clean := 0;
	IF src1.mode = PCO.Regs THEN
		PCO.GenPUSH(PCO.Regs, src1.base2, noBase, noInx, noScale, noDisp, noImm);
		PCO.GenPUSH(PCO.Regs, src1.base, noBase, noInx, noScale, noDisp, noImm);
		src1.mode := PCO.Mem;
		src1.base := ESP; src1.base2 := ESP; src1.index := noInx; src1.scale := noScale; src1.disp := 0;
		INC(clean, 8)
	END;
	IF (src2.mode = PCO.Regs) OR (src2.mode = PCO.Imme) THEN
		PCO.GenPUSH(PCO.Regs, src2.base2, noBase, noInx, noScale, noDisp, noImm);
		PCO.GenPUSH(PCO.Regs, src2.base, noBase, noInx, noScale, noDisp, noImm);
		src2.mode := PCO.Mem;
		src2.base := ESP; src2.base2 := ESP; src2.index := noInx; src2.scale := noScale; src2.disp := 0;
		IF src1.base = ESP THEN INC(src1.disp, 8) END;
		INC(clean, 8)
	END;

	LoadReg(EAX, src1);
	PCO.GenMUL(src2.mode >= PCO.ForceDisp32, EAX, src2.base, src2.index, src2.scale, src2.disp);
(*
	PCO.GenIMUL(src2.mode, TRUE, EAX, src2.base, src2.index, src2.scale, src2.disp, src2.imm);	(* MUL EAX, src2  (shortform -> MUL) *)
*)
	FixAbsolute(src2.addr, -4);

	LoadReg(EBX, src1);
	PCO.GenIMUL(src2.mode, FALSE, EBX, src2.base2, src2.index, src2.scale, src2.disp+4, src2.imm2);	(* IMUL Src1.L, Src2.H *)
	FixAbsolute(src2.addr, -4);
	PCO.GenTyp1(PCO.ADD, PCO.RegReg, EDX, EBX, noInx, noScale, noDisp, noImm);

	LoadReg(EBX, src2);
	PCO.GenIMUL(src1.mode, FALSE, EBX, src1.base2, src1.index, src1.scale, src1.disp+4, src1.imm2);	(* IMUL Src2.L, Src1.H *)
	FixAbsolute(src1.addr, -4);
	PCO.GenTyp1(PCO.ADD, PCO.RegReg, EDX, EBX, noInx, noScale, noDisp, noImm);

	IF clean # 0 THEN
		PCO.GenTyp1(PCO.ADD, PCO.ImmReg, ESP, noBase, noInx, noScale, noDisp, clean)
	END
END GenMul64;

PROCEDURE GenMul(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR size: LONGINT;  reg: Register;  src1, src2: RealAddress;  short, spilled: BOOLEAN;
BEGIN
	spilled := FALSE;
	IF instr.dstSize IN PCLIR.FloatSize THEN
		GenFtyp1(code, instr, pc)
	ELSIF instr.dstSize = PCLIR.Int64 THEN
		UseComplex(code, instr.src1, src1);
		UseComplex(code, instr.src2, src2);
		AllocateThisRegI2(instr, pc, EAX, EDX);
		GenMul64(src1, src2, EAX, EDX)
	ELSE
		size := PCLIR.NofBytes(instr.dstSize);
		UseComplex(code, instr.src1, src1);		(* src1 = complex => src2 = immediate *)
		IF (size = 1) & ((src1.mode # PCO.Regs) OR (src1.base # AL)) THEN	(*8bit, special case, only IMUL AL possible*)
			ReleaseReg(code, AX, MakeMask(src1.base)+MakeMask(src1.index));
			LoadReg(AL, src1);
(*
			PCO.GenMOV(src1.mode, AL, src1.base, src1.index, src1.scale, src1.disp, noImm);
*)
			src1.base := AL;  src1.mode := PCO.Regs;
		END;
		IF (src1.base IN{EBP, ESP}) OR (src1.base = none) OR (src1.mode # PCO.Regs) THEN
			reg := AllocateRegI(code, instr, pc);
		ELSE
			AllocateThisRegI(instr, pc, src1.base);  reg := src1.base
		END;
		UseComplex(code, instr.src2, src2);

		IF (size = 1) & (src2.mode = PCO.Imme) THEN
			GetTempReg8(src2.base, RegI-{AL, AH});
			IF src2.base < 0 THEN	(* no register is available, spill to stack. src1 is AL / dest is AX *)
				KernelLog.String("PCG386: Spilling happens!"); KernelLog.Ln;
				spilled := TRUE;
				PCO.GenPUSH(PCO.Regs, EBX, noBase, noInx, noScale, noDisp, noImm);
				src2.base := BL
			END;
			PCO.GenMOV(PCO.ImmReg, src2.base, noBase, noInx, noScale, noDisp, src2.imm);
			src2.mode := PCO.Regs
		END;

		ASSERT((size # 1) OR (reg = AL));	(*size=1 => reg = AL*)
		short := reg IN {AL, AX, EAX};
		IF src2.mode IN {PCO.Imme, PCO.ImmeA} THEN
			ASSERT(size # 1);
			IF src1.mode = PCO.Regs THEN
				PCO.GenIMUL(src2.mode, short, reg, src1.base, noInx, noScale, noDisp, src2.imm)
			ELSE
				ASSERT(src1.mode IN {PCO.Mem, PCO.MemA});
				ASSERT(src2.mode # PCO.ImmeA);
				PCO.GenIMUL(src1.mode+(PCO.ImmMem-PCO.Mem), short, reg, src1.base, src1.index, src1.scale, src1.disp, src2.imm);
				IF src1.addr # NIL THEN
					FixAbsolute(src1.addr, -4-ConstSize(src2.imm, size = PCLIR.Int16))
				END;
			END;
			IF src2.addr # NIL THEN
				FixAbsolute(src2.addr, -4)
			END
		ELSE
			ASSERT(src1.mode = PCO.Regs, 500);
			ASSERT(reg = src1.base, 501);
			IF (short) & (size # 1) THEN
				(*IF size = 1 THEN ReleaseReg(code, AH, MakeMask(AL)+MakeMask(src2base)+MakeMask(src2.index))*)	(*already freed*)
				short := Owner(EDX) = Free
			END;
			PCO.GenIMUL(src2.mode, short, src1.base, src2.base, src2.index, src2.scale, src2.disp, src2.imm);
			IF src2.addr # NIL THEN
				FixAbsolute(src2.addr, -4)
			END;
			IF spilled THEN
				PCO.GenPOP(PCO.Regs, EBX, noBase, noInx, noScale, noDisp)
			END
		END
	END
END GenMul;

PROCEDURE GenDivMod(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  size: PCLIR.Size;  remainder, dividend, result, temp: Register;  src2: RealAddress;  offs, bytes: LONGINT; dest: SET;
BEGIN
	ASSERT((instr.op = PCLIR.div) OR (instr.op = PCLIR.mod));
	IF instr.dstSize = PCLIR.Int64 THEN
		PCM.Error(200, PCO.errpos, "HUGEINT DIV/MOD");
	ELSIF instr.dstSize IN PCLIR.FloatSize THEN
		GenFtyp1(code, instr, pc)
	ELSE
		size := instr.dstSize;  bytes := PCLIR.NofBytes(size);
		remainder := RegisterD(size);
		dividend := RegisterA(size);
		UseRegister(code, instr.src1, temp);
		dest := MakeMask(remainder)+MakeMask(dividend);
		ForceRegister(code, temp, dividend, dest);

		ReleaseReg(code, remainder, dest);
		UseComplex(code, instr.src2, src2);

		IF instr.op = PCLIR.div THEN
			result := RegisterA(size);	(*quotient*)
		ELSE
			result := RegisterD(size);	(*remainder*)
		END;
		AllocateThisRegI(instr, pc, result);
		IF bytes = 1 THEN
			PCO.PutByte(66H); PCO.PutByte(PCO.CBW)
		ELSE
			IF bytes = 2 THEN  PCO.PutByte(66H)  END;
			PCO.PutByte(PCO.CWD)
		END;

		IF src2.mode = PCO.Regs THEN
			PCO.GenIDIV(PCO.RegReg, src2.base, src2.base, src2.index, src2.scale, src2.disp)
		ELSE
			PCO.GenIDIV(src2.mode, RegisterA(size), src2.base, src2.index, src2.scale, src2.disp);
			IF src2.addr # NIL THEN
				FixAbsolute(src2.addr, -4)
			END
		END;

		(* correction for negative numbers *)
		IF instr.op = PCLIR.div THEN
			PCO.GenShiftRot(PCO.SHL, PCO.ImmReg, remainder, noBase, noInx, noScale, noDisp, 1);
			PCO.GenTyp1(PCO.SBB, PCO.ImmReg, result, noBase, noInx, noScale, noDisp, 0);
		ELSE
			PCO.GenTyp1(PCO.CMP, PCO.ImmReg, remainder, remainder, noInx, noScale, noDisp, 0);
			PCO.GenJcc(PCO.JGE, 0);	(*dummy, fix later*)
			offs := PCO.pc;
			PCO.GenTyp1(PCO.ADD, src2.mode, result, src2.base, src2.index, src2.scale, src2.disp, src2.imm);
			IF src2.addr # NIL THEN
				FixAbsolute(src2.addr, -4)
			END;
			PCO.PutByteAt(offs-1, SHORT(SHORT(PCO.pc-offs)));
		END
	END
END GenDivMod;

PROCEDURE GenTyp1(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR src1, src2: RealAddress; t: Register; lea: BOOLEAN;  info: Address;
BEGIN
	ASSERT(instr.src1 # 0);
	IF instr.dstSize IN PCLIR.FloatSize THEN
		GenFtyp1(code, instr, pc);
	ELSIF instr.dstSize = PCLIR.Int64 THEN
		UseComplex(code, instr.src1, src1);  ASSERT(src1.mode = PCO.Regs);
		UseComplex(code, instr.src2, src2);
		AllocateThisRegI2(instr, pc, src1.base, src1.base2);
		PCO.GenTyp1(Typ1Opcode[instr.op-PCLIR.sub], src2.mode, src1.base, src2.base, src2.index, src2.scale, src2.disp, src2.imm);
		FixAbsolute(src2.addr, -4);
		PCO.GenTyp1(Typ1Opcode2[instr.op-PCLIR.sub], src2.mode, src1.base2, src2.base2, src2.index, src2.scale, src2.disp+4, src2.imm2);
		FixAbsolute(src2.addr, -4);
	ELSE
		info := SYSTEM.VAL(Address, instr.info);
		UseComplex(code, instr.src1, src1);  ASSERT(src1.mode = PCO.Regs);
		UseComplex(code, instr.src2, src2);
		IF (instr.src1 = PCLIR.SP) & (info.i386 = ESP) THEN	(*optimize ESP -> ESP *)
			AllocateThisRegI(instr, pc, src1.base)
		ELSIF (instr.src1 < 0) OR (Owner(src1.base) # Free) THEN	(*don't overwrite hw-reg or registers still in use*)
			t := src1.base;
			src1.base := AllocateReg(code, pc);
			IF (instr.op = PCLIR.add) & (src2.mode = PCO.Imme) THEN
				lea := TRUE
			ELSE
				PCO.GenMOV(PCO.RegReg, src1.base, t, noInx, noScale, noDisp, noImm)
			END
		ELSE
			AllocateThisRegI(instr, pc, src1.base)
		END;
		IF lea & (src2.addr = NIL) & (src2.imm = 0) THEN
			PCO.GenMOV(PCO.RegReg, src1.base, t, noInx, noScale, noDisp, noImm);
		ELSIF lea THEN
			PCO.GenLEA(src2.addr # NIL, src1.base, t, noInx, noScale, src2.imm);
			IF src2.addr # NIL THEN FixAbsolute(src2.addr, -4) END
		ELSIF (src2.mode = PCO.Imme) & (src2.imm = 1) & (instr.op = PCLIR.add) THEN
			PCO.GenINC(PCO.ImmReg, src1.base, noBase, noInx, noScale, noDisp)
		ELSIF (src2.mode = PCO.Imme) & (src2.imm = 1) & (instr.op = PCLIR.sub) THEN
			PCO.GenDEC(PCO.ImmReg, src1.base, noBase, noInx, noScale, noDisp)
		ELSE
			PCO.GenTyp1(Typ1Opcode[instr.op-PCLIR.sub], src2.mode, src1.base, src2.base, src2.index, src2.scale, src2.disp, src2.imm);
			FixAbsolute(src2.addr, -4)
		END
	END
END GenTyp1;

PROCEDURE GenShift(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  op: PCLIR.Opcode;  src, src2, tmp: Register; count: RealAddress;  pos1, pos2: LONGINT; size64: BOOLEAN;
(*
	Note: UseRegister must be done after ForceRegister, otherwise if the source is in ECX a conflict may occour.
*)
BEGIN
	op := instr.op;
	size64 := instr.dstSize = PCLIR.Int64;
	UseComplex(code, instr.src2, count);
	IF count.mode # PCO.Imme THEN ForceRegister(code, count.base, CL, {}) END;
	ASSERT(count.mode # PCO.ImmeA);
	IF size64 THEN
		UseRegister2(code, instr.src1, src, src2);
		AllocateThisRegI2(instr, pc, src, src2);
		IF op = PCLIR.rot THEN
			GetTempReg32(tmp);
			PCO.GenMOV(PCO.RegReg, tmp, src2, noInx, noScale, noDisp, noImm);
		END
	ELSE
		UseRegister(code, instr.src1, src);
		AllocateThisRegI(instr, pc, src)
	END;
	IF count.mode # PCO.Imme THEN	(*generic case: discriminate against count *)
		ASSERT(count.mode = PCO.Regs);
		PCO.GenTyp1(PCO.CMP, PCO.ImmReg, CL, noBase, noInx, noScale, noDisp, 0);
		PCO.GenJcc(PCO.JL, 0);
		pos1 := PCO.pc;
		IF ~size64 THEN
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.RegReg, src, count.base, noInx, noScale, noDisp, noImm);
		ELSIF op = PCLIR.rot THEN
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, TRUE, src, src2, noInx, noScale, noDisp, noImm);
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, TRUE, tmp, src, noInx, noScale, noDisp, noImm);
		ELSE
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, TRUE, src, src2, noInx, noScale, noDisp, noImm);
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.RegReg, src, count.base, noInx, noScale, noDisp, noImm);
		END;
		PCO.GenJMP(PCO.Imme, noBase, noBase, noInx, noScale, 0);
		pos2 := PCO.pc;
		PCO.PutByteAt(pos1-1, SHORT(SHORT(PCO.pc-pos1)));
		PCO.GenGroup3(PCO.NEG, PCO.Regs, count.base, count.base, noInx, noScale, noDisp);
		IF ~size64 THEN
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, right], PCO.RegReg, src, count.base, noInx, noScale, noDisp, noImm);
		ELSIF op = PCLIR.rot THEN
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, TRUE, src, src2, noInx, noScale, noDisp, noImm);
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, TRUE, tmp, src, noInx, noScale, noDisp, noImm);
		ELSE
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, TRUE, src2, src, noInx, noScale, noDisp, noImm);
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, right], PCO.RegReg, src2, count.base, noInx, noScale, noDisp, noImm);
		END;
		PCO.PutByteAt(pos2-1, SHORT(SHORT(PCO.pc-pos2)));
	ELSIF ~size64 THEN
		IF count.imm >= 0 THEN
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src, src, noInx, noScale, noDisp, count.imm)
		ELSE
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, right], PCO.ImmReg, src, src, noInx, noScale, noDisp, -count.imm)
		END;
	ELSIF op = PCLIR.rot THEN	(* 64-bit rot *)
		count.imm := count.imm MOD 64;
		IF (count.imm <= -32) OR (count.imm >= 32) THEN	(* swap registers *)
			FreeReg(src); FreeReg(src2); AllocateThisRegI2(instr, pc, src2, src);
			count.imm := count.imm MOD 32
		END;
		IF count.imm > 0 THEN
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, FALSE, src, src2, noInx, noScale, noDisp, count.imm);
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, FALSE, tmp, src, noInx, noScale, noDisp, count.imm);
		ELSIF count.imm < 0 THEN
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, FALSE, src, src2, noInx, noScale, noDisp, -count.imm);
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, FALSE, tmp, src, noInx, noScale, noDisp, -count.imm);
		ELSE
		END
	ELSE		(* 64-bit shifts *)	(* src2:src, src lower part *)
		IF count.imm >= 32 THEN
			FreeReg(src); FreeReg(src2); AllocateThisRegI2(instr, pc, src2, src);	(* swap registers *)
			PCO.GenTyp1(PCO.XOR, PCO.RegReg, src2, src2, noInx, noScale, noDisp, noImm);	(* xor src, src *)
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src, src, noInx, noScale, noDisp, count.imm-32);
		ELSIF count.imm <= -32 THEN
			IF instr.op = PCLIR.ash THEN
				PCO.GenMOV(PCO.RegReg, src, src2, noInx, noScale, noDisp, noImm);	(* mov l, h *)
				PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src2, src2, noInx, noScale, noDisp, 31);	(*keep sign*)
				PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src, src, noInx, noScale, noDisp, count.imm+32);
			ELSE
				FreeReg(src); FreeReg(src2); AllocateThisRegI2(instr, pc, src2, src);	(* swap registers *)
				PCO.GenTyp1(PCO.XOR, PCO.RegReg, src, src, noInx, noScale, noDisp, noImm);	(* xor src, src *)
				PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src2, src2, noInx, noScale, noDisp, count.imm+32);
			END
		ELSIF count.imm >= 0 THEN
			PCO.GenSHDouble(PCO.Left, PCO.RegReg, FALSE, src, src2, noInx, noScale, noDisp, count.imm);
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, left], PCO.ImmReg, src, src, noInx, noScale, noDisp, count.imm)
		ELSE
			PCO.GenSHDouble(PCO.Right, PCO.RegReg, FALSE, src2, src, noInx, noScale, noDisp, -count.imm);
			PCO.GenShiftRot(ShiftOpcode[instr.op-PCLIR.ash, right], PCO.ImmReg, src2, src2, noInx, noScale, noDisp, -count.imm)
		END
	END;
END GenShift;

PROCEDURE GenMoveDown(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  src, dst: Register;  size: RealAddress;  step: INTEGER;
BEGIN
	UseRegister(code, instr.src1, src); ForceRegister(code, src, ESI, MakeMask(EDI)+MakeMask(ECX));
	UseRegister(code, instr.src2, dst); ForceRegister(code, dst, EDI, MakeMask(ESI)+MakeMask(ECX));
	UseComplex(code, instr.src3, size);
	ASSERT(size.mode # PCO.ImmeA);
	step := PCO.Bit8;
	PCO.PutByte(PCO.STD);
	IF size.mode = PCO.ImmReg THEN
		IF size.imm MOD 4 = 0 THEN
			step := PCO.Bit32;  size.imm := size.imm DIV 4
		ELSIF size.imm MOD 2 = 0 THEN
			step := PCO.Bit16;  size.imm := size.imm DIV 2
		END;
		IF size.imm > 3 THEN
			ReleaseReg(code,  ECX, MakeMask(ESI)+MakeMask(EDI));
			PCO.GenMOV(PCO.ImmReg, ECX, noBase, noInx, noScale, noDisp, size.imm);
			PCO.GenRepString(PCO.MOVS, step)
		ELSE
			WHILE size.imm > 0 DO
				PCO.GenString(PCO.MOVS, step);
				DEC(size.imm)
			END
		END
	ELSE
		ForceRegister(code, size.base, ECX, MakeMask(ESI)+MakeMask(EDI));
		PCO.GenRepString(PCO.MOVS, step);
		PCO.PutByte(PCO.CLD);
	END
END GenMoveDown;

PROCEDURE GenMove(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  src, dst, tmp: Register;  size: RealAddress;  step: INTEGER;
BEGIN
	UseRegister(code, instr.src1, src); ForceRegister(code, src, ESI, MakeMask(EDI)+MakeMask(ECX));
	UseRegister(code, instr.src2, dst); ForceRegister(code, dst, EDI, MakeMask(ESI)+MakeMask(ECX));
	UseComplex(code, instr.src3, size);
	ASSERT(size.mode # PCO.ImmeA);
	step := PCO.Bit8;
	IF size.mode = PCO.ImmReg THEN
		IF size.imm MOD 4 = 0 THEN
			step := PCO.Bit32;  size.imm := size.imm DIV 4
		ELSIF size.imm MOD 2 = 0 THEN
			step := PCO.Bit16;  size.imm := size.imm DIV 2
		END;
		IF size.imm > 3 THEN
			ReleaseReg(code,  ECX, MakeMask(ESI)+MakeMask(EDI));
			PCO.GenMOV(PCO.ImmReg, ECX, noBase, noInx, noScale, noDisp, size.imm);
			PCO.GenRepString(PCO.MOVS, step)
		ELSE
			WHILE size.imm > 0 DO
				PCO.GenString(PCO.MOVS, step);
				DEC(size.imm)
			END
		END
	ELSE
		ForceRegister(code, size.base, ECX, MakeMask(ESI)+MakeMask(EDI));
(* -> experimental*)
		GetTempReg8(tmp, -(MakeMask(ECX)+MakeMask(ESI)+MakeMask(EDI)));
		IF tmp # -1 THEN	(*register found*)
			PCO.GenMOV(PCO.RegReg, tmp, CL, noInx, noScale, noDisp, noImm);
			PCO.GenShiftRot(PCO.SHR, PCO.ImmReg, ECX, noBase, noInx, noScale, noDisp, 2);
			PCO.GenTyp1(PCO.AND, PCO.ImmReg, tmp, noBase, noInx, noScale, noDisp, 3);
			PCO.GenRepString(PCO.MOVS, PCO.Bit32);
			PCO.GenMOV(PCO.RegReg, CL, tmp, noInx, noScale, noDisp, noImm)
		END;
(* <- experimental*)
		PCO.GenRepString(PCO.MOVS, step)
	END
END GenMove;

PROCEDURE GenInline(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  newpc, oldpc, i: LONGINT;  inline: PCLIR.AsmInline;  block: PCLIR.AsmBlock;  fix: PCLIR.AsmFixup;
(*
	c: LONGINT;
*)
BEGIN
(*
	PCM.LogWLn; PCM.LogWStr("Emit Inline.  code = ");
*)
	inline := instr.adr(PCLIR.AsmInline);
	oldpc := PCO.pc;
	block := inline.code;
	WHILE block # NIL DO
(*
		INC(c, block.len);
*)
		FOR i := 0 TO block.len-1 DO PCO.PutByte(ORD(block.code[i])) END;
		block := block.next
	END;
(*
	PCM.LogWNum(c); PCM.LogWStr("  fixups = "); c := 0;
*)
	newpc := PCO.pc; PCO.pc := oldpc;
	fix := inline.fixup;
	WHILE fix # NIL DO
(*
		INC(c);
*)
		PCO.PutDWordAt(PCO.pc+fix.offset, fix.adr(PCBT.GlobalVariable).offset);
		FixAbsolute(fix.adr, fix.offset);
		fix := fix.next
	END;
(*
	PCM.LogWNum(c);
*)
	PCO.pc := newpc
END GenInline;

(* CaseTable Format
	location: at offset "table" in the const section
	CaseTable = ARRAY table size OF RECORD
		pc-offset: INTEGER;	(*address(rel to code base) to jump to*)
		next: INTEGER		(*next entry offset (used by the linker to patch addresses)*)
	END;
*)

PROCEDURE GenCase(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  min, max, range, table: LONGINT;  reg: Register;  adr: PCBT.GlobalVariable;  info: Address;
	const: PCBT.ConstArray;
BEGIN
	min := instr.src2;
	max := instr.src3;
	range := max-min+1;



	(*fof this is not thread safe. Strictly speaking it does not have to be as the generator does not run concurrently
		but it's bad style anyway.
	table := PCBT.context.constsize;
	INC(PCBT.context.constsize, SHORT(range*4));
	IF PCBT.context.constsize > LEN(PCBT.context.const^) THEN
		NEW(const, PCBT.context.constsize);
		SYSTEM.MOVE(ADDRESSOF(PCBT.context.const[0]), ADDRESSOF(const[0]), LEN(PCBT.context.const));
		PCBT.context.const := const
	END;
	PCBT.context.casetablesize := PCBT.context.casetablesize + SHORT(range);
	*)
	(* fof new: *)
	table := PCBT.context.AddCasetable(range);

	IF PCBT.context.syscalls[PCBT.casetable] = NIL THEN PCBT.context.UseSyscall(PCBT.casetable, table) END;

	UseRegister(code, instr.src1, reg);
	IF min # 0 THEN PCO.GenTyp1(PCO.SUB, PCO.ImmReg, reg, noBase, noInx, noScale, noDisp, min) END;
	PCO.GenTyp1(PCO.CMP, PCO.ImmReg, reg, noBase, noInx, noScale, noDisp, range);
	PCO.GenJcc(PCO.JAE, 10000H);

	NEW(adr, PCBT.context); adr.offset := table;
	info := SYSTEM.VAL(Address, instr.info);
	info.addr := adr;	(*case table*)
	info.index := PCO.pc;	(* addr for jmp to else fixup*)

	PCO.GenJMP(PCO.MemA, noBase, noBase, reg, PCO.Scale4, table);

	PCBT.context.UseVariable(adr, PCO.pc-4)
END GenCase;

PROCEDURE GenCaseLine(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  info: Address;  table, pos, offset: LONGINT;  p: PCLIR.Piece;
BEGIN
	pos := instr.src1; code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);
	offset := instr.val - p.instr[pos].src2;	(*val-min*)
	table := info.addr(PCBT.GlobalVariable).offset + offset*4;
	PCBT.context.const[table+0] := CHR(PCO.pc);
	PCBT.context.const[table+1] := CHR(PCO.pc DIV 100H);
	PCBT.context.const[table+2] := CHR(PCO.pc DIV 10000H); 	(* ug *)
	PCBT.context.const[table+3] := CHR(PCO.pc DIV 1000000H)  	(* ug *)
END GenCaseLine;

PROCEDURE GenCaseElse(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT);
VAR  pos, min, max, size, i: LONGINT;  p: PCLIR.Piece;  info: Address;
BEGIN
	pos := instr.src1; code.GetPiece(pos, p);
	info := SYSTEM.VAL(Address, p.instr[pos].info);

	PCO.PutDWordAt(info.index-4, PCO.pc - info.index);		(*patch jump to else*)

	size := (*1 +*) p.instr[pos].src3 - p.instr[pos].src2;
	min := info.addr(PCBT.GlobalVariable).offset;
	max := min + size*4;
	FOR i := min TO max BY 4 DO
		IF (PCBT.context.const[i]=0X) & (PCBT.context.const[i+1]=0X) & (PCBT.context.const[i+2]=0X) & (PCBT.context.const[i+3]=0X)THEN
			PCBT.context.const[i+0] := CHR(PCO.pc);
			PCBT.context.const[i+1] := CHR(PCO.pc DIV 100H);
			PCBT.context.const[i+2] := CHR(PCO.pc DIV 10000H);		(* ug *)
			PCBT.context.const[i+3] := CHR(PCO.pc DIV 1000000H)	(* ug *)
		END
	END
END GenCaseElse;

(* Debug Procedures *)
PROCEDURE DumpCode(code: PCLIR.Code;  VAR instr: PCLIR.Instruction;  pc: LONGINT;  context: ANY);
	VAR op: PCLIR.Opcode;   format: SHORTINT;  info: Address;

	PROCEDURE Reg(r: PCLIR.Register;  expand: BOOLEAN);
	VAR p: PCLIR.Piece; reg: LONGINT;

		PROCEDURE WriteDisp(disp: LONGINT;  abs: BOOLEAN);
		BEGIN
			IF abs THEN
				PCM.LogWStr("@sb");
				IF disp >= 0 THEN  PCM.LogW("+")  END
			END;
			PCM.LogWNum(disp)
		END WriteDisp;

		PROCEDURE ComplexAddress(VAR instr: PCLIR.Instruction; reg: LONGINT);
		VAR  info: Address;  form: LONGINT;
		BEGIN
			info := SYSTEM.VAL(Address, instr.info);
			form := PCLIR.InstructionSet[instr.op].format;
			IF (info = NIL) OR (pc # reg) & ~instr.suppress & (form IN {PCLIR.form1M, PCLIR.form1C}) THEN  Reg(reg, FALSE);  RETURN   END;
			CASE info.mode OF
			|  0:
					Reg(reg, FALSE)
			|  register:
					Reg(info.base, FALSE)
			|  immediate:
					PCM.LogWNum(info.imm)
			|  absolute:
					(*IF showSize THEN WriteSize(W, instr.dstSize) END;*)
					WriteDisp(info.disp, info.addr # NIL)
			|  relative, indexed, scaled:
					(*IF showSize THEN WriteSize(W, instr.dstSize) END;*)
					WriteDisp(info.disp, info.addr # NIL);
					IF info.base # none THEN
						PCM.LogW("["); Reg(info.base, FALSE); PCM.LogW("]")
					ELSE
						ASSERT(info.mode # relative)
					END;
					IF info.mode # relative THEN
						PCM.LogW("["); Reg(info.index, FALSE);
						IF info.mode = scaled THEN  PCM.LogW("*");  PCM.LogWNum(info.scale) END;
						PCM.LogW("]")
					END
			ELSE
				Dump(instr, info);
				HALT(99)
			END
		END ComplexAddress;

	BEGIN
		IF (r > 0) & expand THEN
			reg := r; code.GetPiece(reg, p); ComplexAddress(p.instr[reg], r)
		ELSIF r = PCLIR.FP THEN  PCM.LogWStr("FP")
		ELSIF r = PCLIR.SP THEN  PCM.LogWStr("SP")
		ELSIF (r <= PCLIR.HwReg-EAX) & (r >= PCLIR.HwReg - BH) THEN
			PCM.LogWStr(IReg[PCLIR.HwReg-r])
		ELSE
			PCM.LogW(RegName[PCLIR.SizeOf(code,r)]);
			PCM.LogWNum(r)
		END
	END Reg;

BEGIN
	IF instr.suppress THEN  RETURN  END;
	op := instr.op;  format := PCLIR.InstructionSet[op].format;
	info := SYSTEM.VAL(Address, instr.info);
	PCM.LogWNum(pc);
	PCM.LogW(9X);
(*
	IF (format IN PCLIR.form1X) THEN
		PCM.LogWNum(info.count);
	ELSE
		PCM.LogWStr("   ")
	END;
*)
(*
	IF Experimental THEN
		IF info # NIL THEN
			i := 0;
			WHILE (i < LEN(info.alive)) & (info.alive[i].reg # pc) DO INC(i) END;
			IF i # LEN(info.alive) THEN
				FOR j := 0 TO 23 DO
					IF j IN info.alive[i].mask THEN PCM.LogW("1") ELSE PCM.LogW("0") END
				END
			ELSE
				PCM.LogWStr("------------------------")
			END
		ELSE
			PCM.LogWStr("------------------------")
		END;
		PCM.LogWStr("| ");
		j := 0;
		IF info # NIL THEN
			FOR i := 0 TO LEN(info.alive)-1 DO
				IF info.alive[i].reg # none THEN PCM.LogWNum(info.alive[i].reg); INC(j) END
			END
		ELSE
			PCM.LogWStr("---"); INC(j)
		END;
		FOR i := j TO LEN(info.alive)-1 DO  PCM.LogWStr("   ") END;
	END;
*)
	PCM.LogW(9X);
	PCM.LogWStr(PCLIR.InstructionSet[op].name); PCM.LogW(9X);

	CASE format OF
	| PCLIR.form00:
	| PCLIR.form0C:
			PCM.LogWNum(instr.val)
	| PCLIR.form01:
			Reg(instr.src1, TRUE)
	| PCLIR.form10:
			Reg(pc, FALSE)
	| PCLIR.form1C:
			Reg(pc, FALSE); PCM.LogWStr(", "); PCM.LogWNum(instr.val)
	| PCLIR.form1M:
			Reg(pc, FALSE);  PCM.LogWStr(", ");  Reg(pc, TRUE);  (*Indirect(instr.val, instr.src1)*)
	| PCLIR.form11:
			Reg(pc, FALSE);  PCM.LogWStr(", ");  Reg(instr.src1, TRUE)
	| PCLIR.formM1:
			Reg(pc, TRUE);  PCM.LogWStr(", ");  Reg(instr.src2, TRUE)
	| PCLIR.form02:
			Reg(instr.src1, TRUE);  PCM.LogWStr(", ");  Reg(instr.src2, TRUE)
	| PCLIR.form12:
			Reg(pc, FALSE);  PCM.LogWStr(", ");  Reg(instr.src1, TRUE);
			PCM.LogWStr(", ");  Reg(instr.src2, TRUE)
	| PCLIR.form02C:
			Reg(instr.src1, TRUE);  PCM.LogWStr(", ");  Reg(instr.src2, TRUE);
			PCM.LogWStr(", "); PCM.LogWNum(instr.val)
	| PCLIR.form03:
			Reg(instr.src1, TRUE);  PCM.LogWStr(", ");  Reg(instr.src2, TRUE);
			PCM.LogWStr(", ");  Reg(instr.src3, TRUE)
	| PCLIR.formXX:
		CASE op OF
		| PCLIR.enter, PCLIR.exit, PCLIR.inline:
		| PCLIR.case:
				Reg(instr.src1, TRUE); PCM.LogWStr("  {"); PCM.LogWNum(instr.val);  PCM.LogW("}")
		| PCLIR.casel:
				PCM.LogWNum(instr.val); PCM.LogWStr("  {");
				PCM.LogWNum(instr.src1); PCM.LogWStr("}")
		| PCLIR.casee:
				PCM.LogWStr("  {"); PCM.LogWNum(instr.src1); PCM.LogWStr("}")
		END
	END;
	PCM.LogWLn;
END DumpCode;

PROCEDURE DoOptimize(code: PCLIR.Code);
VAR context: AliveSetPtr;
BEGIN
	IF Experimental THEN
		NEW(context);
		AliveSetInit(context^)
	END;
	code.Traverse(Optimize, TRUE, context)
END DoOptimize;

PROCEDURE IncSaveLevel;
VAR s: SavedRegistersType; i: LONGINT;
BEGIN
	INC(SaveLevel);
	IF SaveLevel >= LEN(SavedRegisters) THEN
		NEW(s, 2*LEN(SavedRegisters));
		FOR i := 0 TO LEN(SavedRegisters)-1 DO
			s[i] := SavedRegisters[i];
		END;
		SavedRegisters := s;
	END;
END IncSaveLevel;

(* Init - Initialize code generator - Installed in PCBT.CG *)

PROCEDURE Init(): BOOLEAN;
BEGIN  PCO.dsize := 0; PCO.pc := 0; CCTableSwitch := intMode;
	SaveLevel := 0;
	NEW(SavedRegisters, 16);
	RETURN TRUE
END Init;

(* Done - Code generator results - Installed in PCBT.CG *)

PROCEDURE Done(VAR result: LONGINT);
BEGIN
	IF PCO.CodeErr THEN result := -1
	ELSE result := 0
	END
END Done;

	PROCEDURE GetCode(VAR codeArr: PCLIR.CodeArray; VAR length, hdrlength, addressFactor: LONGINT);
	BEGIN
		codeArr := PCO.code; length := PCO.pc; hdrlength := PCO.pc; addressFactor := 1
	END GetCode;

(* Module Initialization and Configuration *)

	(* Install - installs the i386 code generator in Paco *)
	PROCEDURE Install*;
	VAR  i: PCLIR.Opcode;
	BEGIN
		PCLIR.CG.Init := Init;
		PCLIR.CG.Done := Done;
		PCLIR.CG.GetCode := GetCode;
		PCLIR.CG.DumpCode := DumpCode;
		PCLIR.CG.Optimize := DoOptimize;
		PCLIR.CG.MaxCodeSize := PCO.MaxCodeLength;
		PCLIR.CG.ParamAlign := 4;
		PCBT.SetNumberOfSyscalls(PCBT.DefaultNofSysCalls);
		NEW(PCLIR.CG.SysCallMap, PCBT.NofSysCalls);
		PCLIR.InitDefaultSyscalls;

		PCLIR.Address := PCLIR.Int32;
		PCLIR.Set := PCLIR.Int32;
		PCLIR.SizeType := PCLIR.Int32;

		PCLIR.InstructionInit := InstructionInit;
		PCLIR.SetMethods(PCLIR.enter, GenEnter);
		PCLIR.SetMethods(PCLIR.exit, GenExit);
		FOR i := PCLIR.trap TO PCLIR.tne DO
			PCLIR.SetMethods(i, GenTrap)
		END;
		PCLIR.SetMethods(PCLIR.saveregs, GenSaveRegisters);
		PCLIR.SetMethods(PCLIR.saveregsaligned, GenSaveRegistersAligned);	(* fld *)
		PCLIR.SetMethods(PCLIR.loadregs, GenRestoreRegisters);
		PCLIR.SetMethods(PCLIR.ret, GenReturn);
		PCLIR.SetMethods(PCLIR.ret2, GenReturn);
		PCLIR.SetMethods(PCLIR.result, GenResult);
		PCLIR.SetMethods(PCLIR.result2, GenResult);
		PCLIR.SetMethods(PCLIR.pop, GenPop);
		PCLIR.SetMethods(PCLIR.load, GenLoad);
		PCLIR.SetMethods(PCLIR.loadc, GenLoad);
		PCLIR.SetMethods(PCLIR.store, GenStore);
		PCLIR.SetMethods(PCLIR.in, GenIn);
		PCLIR.SetMethods(PCLIR.out, GenOut);
		PCLIR.SetMethods(PCLIR.nop, GenNop);
		PCLIR.SetMethods(PCLIR.label, GenLabel);
		PCLIR.SetMethods(PCLIR.finallylabel, GenLabel);
		FOR i := PCLIR.je TO PCLIR.jnf DO
			PCLIR.SetMethods(i, GenJcc)
		END;
		PCLIR.SetMethods(PCLIR.jmp, GenJmp);
		PCLIR.SetMethods(PCLIR.call, GenCall);
		PCLIR.SetMethods(PCLIR.callreg, GenCallReg);
		PCLIR.SetMethods(PCLIR.syscall, GenSysCall);
		FOR i := PCLIR.sete TO PCLIR.setnf DO
			PCLIR.SetMethods(i, GenSetcc)
		END;
		PCLIR.SetMethods(PCLIR.kill, GenKill);
		PCLIR.SetMethods(PCLIR.phi, GenPhi);
		PCLIR.SetMethods(PCLIR.push, GenPush);
		PCLIR.SetMethods(PCLIR.loadsp, GenLoadSP);
		PCLIR.SetMethods(PCLIR.loadfp, GenLoadFP);

		PCLIR.SetMethods(PCLIR.convs, GenConv);
		PCLIR.SetMethods(PCLIR.convu, GenConv);
		PCLIR.SetMethods(PCLIR.copy, GenConv);

		PCLIR.SetMethods(PCLIR.not, GenNegNot);
		PCLIR.SetMethods(PCLIR.neg, GenNegNot);
		PCLIR.SetMethods(PCLIR.abs, GenAbs);
		PCLIR.SetMethods(PCLIR.bts, GenBitOp);
		PCLIR.SetMethods(PCLIR.btc, GenBitOp);
		PCLIR.SetMethods(PCLIR.mul, GenMul);
		PCLIR.SetMethods(PCLIR.div, GenDivMod);
		PCLIR.SetMethods(PCLIR.mod, GenDivMod);
		PCLIR.SetMethods(PCLIR.sub, GenTyp1);
		PCLIR.SetMethods(PCLIR.add, GenTyp1);
		PCLIR.SetMethods(PCLIR.and, GenTyp1);
		PCLIR.SetMethods(PCLIR.or, GenTyp1);
		PCLIR.SetMethods(PCLIR.xor, GenTyp1);

		PCLIR.SetMethods(PCLIR.ash, GenShift);
		PCLIR.SetMethods(PCLIR.bsh, GenShift);
		PCLIR.SetMethods(PCLIR.rot, GenShift);
		PCLIR.SetMethods(PCLIR.move, GenMove);
		PCLIR.SetMethods(PCLIR.moveDown, GenMoveDown);
		PCLIR.SetMethods(PCLIR.inline, GenInline);
		PCLIR.SetMethods(PCLIR.case, GenCase);
		PCLIR.SetMethods(PCLIR.casel, GenCaseLine);
		PCLIR.SetMethods(PCLIR.casee, GenCaseElse);
		PCM.LogWStr("i386 code generator installed"); PCM.LogWLn;
	END Install;

	PROCEDURE Configure;
	VAR i: SHORTINT;
	BEGIN
		TccOpcode[PCLIR.tae-PCLIR.tae] := PCO.JNAE;
		TccOpcode[PCLIR.tne-PCLIR.tae] := PCO.JE;

		JccOpcode[PCLIR.je-PCLIR.je, intMode] := PCO.JE;
		JccOpcode[PCLIR.jne-PCLIR.je, intMode] := PCO.JNE;
		JccOpcode[PCLIR.jlt-PCLIR.je, intMode] := PCO.JL;
		JccOpcode[PCLIR.jle-PCLIR.je, intMode] := PCO.JLE;
		JccOpcode[PCLIR.jgt-PCLIR.je, intMode] := PCO.JG;
		JccOpcode[PCLIR.jge-PCLIR.je, intMode] := PCO.JGE;
		JccOpcode[PCLIR.jb-PCLIR.je, intMode] := PCO.JB;
		JccOpcode[PCLIR.jbe-PCLIR.je, intMode] := PCO.JBE;
		JccOpcode[PCLIR.ja-PCLIR.je, intMode] := PCO.JA;
		JccOpcode[PCLIR.jae-PCLIR.je, intMode] := PCO.JAE;
		JccOpcode[PCLIR.jf-PCLIR.je, intMode] := PCO.JC;
		JccOpcode[PCLIR.jnf-PCLIR.je, intMode] := PCO.JNC;

		JccOpcode[PCLIR.je-PCLIR.je, floatMode] := PCO.JE;
		JccOpcode[PCLIR.jne-PCLIR.je, floatMode] := PCO.JNE;
		JccOpcode[PCLIR.jlt-PCLIR.je, floatMode] := PCO.JB;
		JccOpcode[PCLIR.jle-PCLIR.je, floatMode] := PCO.JBE;
		JccOpcode[PCLIR.jgt-PCLIR.je, floatMode] := PCO.JA;
		JccOpcode[PCLIR.jge-PCLIR.je, floatMode] := PCO.JAE;
		(* jb - jae not defined for FPU *)
		JccOpcode[PCLIR.jf-PCLIR.je, floatMode] := PCO.JC;
		JccOpcode[PCLIR.jnf-PCLIR.je, floatMode] := PCO.JNC;

		Jcc2Opcode[PCLIR.je-PCLIR.je, 0] := 0;
		Jcc2Opcode[PCLIR.je-PCLIR.je, 1] := PCO.JNE;
		Jcc2Opcode[PCLIR.je-PCLIR.je, 2] := PCO.JE;

		Jcc2Opcode[PCLIR.jne-PCLIR.je, 0] := PCO.JNE;
		Jcc2Opcode[PCLIR.jne-PCLIR.je, 1] := 0;
		Jcc2Opcode[PCLIR.jne-PCLIR.je, 2] := PCO.JNE;

		Jcc2Opcode[PCLIR.jlt-PCLIR.je, 0] := PCO.JL;
		Jcc2Opcode[PCLIR.jlt-PCLIR.je, 1] := PCO.JNE;
		Jcc2Opcode[PCLIR.jlt-PCLIR.je, 2] := PCO.JB;

		Jcc2Opcode[PCLIR.jle-PCLIR.je, 0] := PCO.JL;
		Jcc2Opcode[PCLIR.jle-PCLIR.je, 1] := PCO.JNE;
		Jcc2Opcode[PCLIR.jle-PCLIR.je, 2] := PCO.JBE;

		Jcc2Opcode[PCLIR.jgt-PCLIR.je, 0] := PCO.JG;
		Jcc2Opcode[PCLIR.jgt-PCLIR.je, 1] := PCO.JNE;
		Jcc2Opcode[PCLIR.jgt-PCLIR.je, 2] := PCO.JA;

		Jcc2Opcode[PCLIR.jge-PCLIR.je, 0] := PCO.JG;
		Jcc2Opcode[PCLIR.jge-PCLIR.je, 1] := PCO.JNE;
		Jcc2Opcode[PCLIR.jge-PCLIR.je, 2] := PCO.JAE;
(*
		Jcc2Opcode[PCLIR.jb-PCLIR.je, intMode] := PCO.JB;
		Jcc2Opcode[PCLIR.jbe-PCLIR.je, intMode] := PCO.JBE;
		Jcc2Opcode[PCLIR.ja-PCLIR.je, intMode] := PCO.JA;
		Jcc2Opcode[PCLIR.jae-PCLIR.je, intMode] := PCO.JAE;

		Jcc2Opcode[PCLIR.jf-PCLIR.je, intMode] := PCO.JC;
		Jcc2Opcode[PCLIR.jnf-PCLIR.je, intMode] := PCO.JNC;
*)

		Typ1Opcode[PCLIR.sub-PCLIR.sub] := PCO.SUB;
		Typ1Opcode[PCLIR.add-PCLIR.sub] := PCO.ADD;
		Typ1Opcode[PCLIR.and-PCLIR.sub] := PCO.AND;
		Typ1Opcode[PCLIR.or-PCLIR.sub] := PCO.Or;
		Typ1Opcode[PCLIR.xor-PCLIR.sub] := PCO.XOR;
		Typ1Opcode2[PCLIR.sub-PCLIR.sub] := PCO.SBB;
		Typ1Opcode2[PCLIR.add-PCLIR.sub] := PCO.ADC;
		Typ1Opcode2[PCLIR.and-PCLIR.sub] := PCO.AND;
		Typ1Opcode2[PCLIR.or-PCLIR.sub] := PCO.Or;
		Typ1Opcode2[PCLIR.xor-PCLIR.sub] := PCO.XOR;
		Group3Opcode[PCLIR.neg-PCLIR.not] := PCO.NEG;
		Group3Opcode[PCLIR.not-PCLIR.not] := PCO.NOT;
		BitOpcode[PCLIR.bts-PCLIR.bts] := PCO.BTS;
		BitOpcode[PCLIR.btc-PCLIR.bts] := PCO.BTR;
		ShiftOpcode[PCLIR.ash-PCLIR.ash, left] := PCO.SAL;
		ShiftOpcode[PCLIR.ash-PCLIR.ash, right] := PCO.SAR;
		ShiftOpcode[PCLIR.bsh-PCLIR.ash, left] := PCO.SHL;
		ShiftOpcode[PCLIR.bsh-PCLIR.ash, right] := PCO.SHR;
		ShiftOpcode[PCLIR.rot-PCLIR.ash, left] := PCO.ROL;
		ShiftOpcode[PCLIR.rot-PCLIR.ash, right] := PCO.Ror;

		FOR i := 0 TO 6 DO  FPSize[i] := -1  END;
		FPSize[PCLIR.Int16] := PCO.wInt;
		FPSize[PCLIR.Int32] := PCO.dInt;
		FPSize[PCLIR.Int64] := PCO.qInt;
		FPSize[PCLIR.Float32] := PCO.sReal;
		FPSize[PCLIR.Float64] := PCO.lReal;

		SaveLevel := 0;
		RegName[PCLIR.Int8] := "B";
		RegName[PCLIR.Int16] := "W";
		RegName[PCLIR.Int32] := "D";
		RegName[PCLIR.Int64] := "Q";
		RegName[PCLIR.Float32] := "F";
		RegName[PCLIR.Float64] := "G";
		IReg[EAX] := "EAX";  IReg[EBX] := "EBX";  IReg[ECX] := "ECX";  IReg[EDX] := "EDX";
		IReg[ESP] := "ESP";  IReg[EBP] := "EBP";  IReg[EDI] := "EDI";  IReg[ESI] := "ESI";
		IReg[AX] := "AX";  IReg[BX] := "BX";  IReg[CX] := "CX";  IReg[DX] := "DX";
		(*IReg[SP] := "ESP";  IReg[EBP] := "EBP";  IReg[EDI] := "EDI";  IReg[ESI] := "ESI";*)
		IReg[AH] := "AH";  IReg[BH] := "BH";  IReg[CH] := "CH";  IReg[DH] := "DH";
		IReg[AL] := "AL";  IReg[BL] := "BL";  IReg[CL] := "CL";  IReg[DL] := "DL";

	END Configure;

BEGIN  Configure;
	IF TraceReg THEN PCM.LogWLn; PCM.LogWStr("PC386.TraceReg on") END
END PCG386.

(*
	15.11.06	ug	GenCase, GenCaseLine, GenCaseElse adapted such that fixup chain contains 32 bit offsets
	20.09.03	prk	"/Dcode" compiler option added
	03.07.03	prk	setcc with float operands did spill destination register and store in wrong register when result used in return (return of float comparison is wrong)
	02.07.03	prk	bug in setcc with 64bit operands fixed (did trash module body)
	29.06.03	prk	bug in restoreregs fixed (pop 16bit instead of pop 32bit) (found by Vasile Rotaru)
	11.06.02	prk	BIT implemented
	12.04.02	prk	FullStackInit disabling compiler option
	04.04.02	prk	DIV code pattern improved (proposed by pjm)
	02.04.02	prk	Fix in LoadAdr (copy hw-register when load addr of 0[reg])
	18.03.02	prk	PCBT code cleanup and redesign
	20.02.02	be	refinement in the code generator plugin
	10.12.01	prk	ENTIER: rounding mode set to chop, rounding modes caches as globals
	22.11.01	prk	entier simplified
	11.08.01	prk	Fixup and use lists for procedures in PCBT cleaned up
	10.08.01	prk	PCBT.Procedure: imported: BOOLEAN replaced by owner: Module
	06.08.01	prk	make code generator and object file generator indipendent
	06.08.01    prk	Instruction: dst record removed, fields declared directly in instruction
	14.06.01	prk	register spilling for when temporary 8bit registers not available
	13.06.01	prk	GenMove optimized
	30.05.01	prk	destination (\d) compiler-option to install the back-end
	30.05.01	prk	optimize loadsp, try to keep value in ES
	29.05.01    be	syscall structures moved to backend (PCLIR & code generators)
	28.05.01	prk	Bug in local dynamic array allocation fixed
	14.05.01	prk	PCLIR.lea removed
	11.05.01	prk	correct handling of operation with hw-regs; PCLIR.loadsp instruction; PCC stack ops fixed
	11.05.01	prk	When freeing stack, use pop instead of add (up to three words)
	07.05.01	prk	Installable code generators moved to PCLIR; debug function added
	03.05.01	be	Installable code generators
	26.04.01	prk	PCLIR.lea partly removed
	15.03.01	prk	ret2, result2 added
	15.03.01	prk	calldel removed
	22.02.01	prk	delegates
	12.09.00	prk	FP Allocation
	12.09.00	prk	GenLoad for FP
	30.08.00	prk	conv -> convs/convu/copy

* barrier handling in Optimize/FSM
* SetRegisterHint
* Info initialization: Set to register at FSM or at init?
* different semantic for casel

o Debug code
o SetRegisterHint -> introduce "NiceToHave" and "MustBe" modes
o UseComplex: should return a PCO mode, not a PC386 one
o Use RealAddress in PCO to pass parameters

4 optimize (FSM) cascaded convs (e.g. SHORT(SHORT()) )


Assert Values:
	1000	Allocated Register found
	1001	Allocated FP Register found
	1002	Unvalid register requested
	1003	Implementation restriction: pc # 0
	1004	Requested Register is not available (32-bit in use)
	1005	Requested Register is not available (8-bit in use)
	1006	Requested Register is not available
	1007	Sanity check 1
	1008	Sanity check 2
	1009	Could not find a free 8-bit register
	1010	Invalid Register Size
	1011	Implementation restriction: pc # 0
	1012	Could not find a register
	1013	No free regs left
	1014	No free regs left
	1015	FPU Stack Overflow
	1016	Unvalid register requested
	1017	Register is already free
	1018	Register splitted, cannot free
	1019	Register is already free
	1020	Register is already free
	1021	Freed register is not ST(0)/ST(1)
	1022	Register is already free
	1023	Unvalid register requested
*)
