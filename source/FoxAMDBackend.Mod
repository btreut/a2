MODULE FoxAMDBackend; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Basic := FoxBasic, Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Backend := FoxBackend, Sections := FoxSections,
	IntermediateCode := FoxIntermediateCode, IntermediateBackend := FoxIntermediateBackend, BinaryCode := FoxBinaryCode,
	InstructionSet := FoxAMD64InstructionSet, Assembler := FoxAMD64Assembler, SemanticChecker := FoxSemanticChecker, Formats := FoxFormats,
	Diagnostics, Streams, Options, Strings, ObjectFileFormat := FoxBinaryObjectFile, 
	Machine, D := Debugging, CodeGenerators := FoxCodeGenerators, ObjectFile;

CONST

	(* constants for the register allocator *)
	none=-1;

	RAX=InstructionSet.regRAX; RCX=InstructionSet.regRCX; RDX=InstructionSet.regRDX; RBX=InstructionSet.regRBX;
	RSP=InstructionSet.regRSP; RBP=InstructionSet.regRBP; RSI=InstructionSet.regRSI; RDI=InstructionSet.regRDI;
	R8=InstructionSet.regR8; 	R9=InstructionSet.regR9; 	R10=InstructionSet.regR10; 	R11=InstructionSet.regR11;
	R12=InstructionSet.regR12; 	R13=InstructionSet.regR13; 	R14=InstructionSet.regR14; 	R15=InstructionSet.regR15;
	EAX=InstructionSet.regEAX; ECX=InstructionSet.regECX; EDX=InstructionSet.regEDX; EBX=InstructionSet.regEBX;
	ESP=InstructionSet.regESP; EBP=InstructionSet.regEBP; ESI=InstructionSet.regESI; EDI=InstructionSet.regEDI;
	R8D=InstructionSet.regR8D; 	R9D=InstructionSet.regR9D; 	R10D=InstructionSet.regR10D; 	R11D=InstructionSet.regR11D;
	R12D=InstructionSet.regR12D; 	R13D=InstructionSet.regR13D; 	R14D=InstructionSet.regR14D; 	R15D=InstructionSet.regR15D;
	AX=InstructionSet.regAX;	CX=InstructionSet.regCX;	DX=InstructionSet.regDX;	BX=InstructionSet.regBX;
	SI=InstructionSet.regSI; DI=InstructionSet.regDI; BP=InstructionSet.regBP; SP=InstructionSet.regSP;
	R8W=InstructionSet.regR8W; 	R9W=InstructionSet.regR9W; 	R10W=InstructionSet.regR10W; 	R11W=InstructionSet.regR11W;
	R12W=InstructionSet.regR12W; 	R13W=InstructionSet.regR13W; 	R14W=InstructionSet.regR14W; 	R15W=InstructionSet.regR15W;
	AL=InstructionSet.regAL;	CL=InstructionSet.regCL;	DL=InstructionSet.regDL;	BL=InstructionSet.regBL;	SIL=InstructionSet.regSIL;
	DIL=InstructionSet.regDIL; BPL=InstructionSet.regBPL; SPL=InstructionSet.regSPL;
	R8B=InstructionSet.regR8B; 	R9B=InstructionSet.regR9B; 	R10B=InstructionSet.regR10B; 	R11B=InstructionSet.regR11B;
	R12B=InstructionSet.regR12B; 	R13B=InstructionSet.regR13B; 	R14B=InstructionSet.regR14B; 	R15B=InstructionSet.regR15B;
	AH=InstructionSet.regAH;	CH=InstructionSet.regCH;	DH=InstructionSet.regDH;	BH=InstructionSet.regBH;
	ST0=InstructionSet.regST0;
	XMM0 = InstructionSet.regXMM0;
	XMM7 = InstructionSet.regXMM7;

	Low=0; High=1;

	FrameSpillStack=TRUE;

VAR registerOperands: ARRAY InstructionSet.numberRegisters OF Assembler.Operand;
	usePool: BOOLEAN;
	 opEAX, opECX, opEDX, opEBX, opESP, opEBP,
	 opESI, opEDI, opAX, opCX, opDX, opBX, opSI, opDI, opAL, opCL, opDL, opBL, opAH, opCH, opDH, opBH,opST0
	 , opRSP, opRBP: Assembler.Operand;

	 unusable,split,blocked,free: CodeGenerators.Ticket;
	 traceStackSize: LONGINT;

TYPE

	Ticket=CodeGenerators.Ticket;

	PhysicalRegisters*=OBJECT (CodeGenerators.PhysicalRegisters)
	VAR
		toVirtual: ARRAY InstructionSet.numberRegisters OF Ticket; (* registers real register -> none / reserved / split / blocked / virtual register (>0) *)
		reserved: ARRAY InstructionSet.numberRegisters OF BOOLEAN;
		hint: LONGINT;
		useFPU: BOOLEAN;

		PROCEDURE &InitPhysicalRegisters(fpu,cooperative: BOOLEAN);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO LEN(toVirtual)-1 DO
				toVirtual[i] := NIL;
				reserved[i] := FALSE;
			END;
			(* reserve stack and base pointer registers *)
			toVirtual[BPL] := unusable;
			toVirtual[SPL] := unusable;
			toVirtual[BP] := unusable;
			toVirtual[SP] := unusable;
			toVirtual[EBP] := unusable;
			toVirtual[ESP] := unusable;
			toVirtual[RBP] := unusable;
			toVirtual[RSP] := unusable;
			hint := none;
			useFPU := fpu
		END InitPhysicalRegisters;

		PROCEDURE AllocationHint(index: LONGINT);
		BEGIN hint := index
		END AllocationHint;

		PROCEDURE NumberRegisters(): LONGINT;
		BEGIN
			RETURN LEN(toVirtual)
		END NumberRegisters;

	END PhysicalRegisters;

	PhysicalRegisters32=OBJECT (PhysicalRegisters) (* 32 bit implementation *)

		PROCEDURE & InitPhysicalRegisters32(fpu,cooperative: BOOLEAN);
		VAR i: LONGINT;
		BEGIN
			InitPhysicalRegisters(fpu,cooperative);
			(* disable registers that are only usable in 64 bit mode *)
			FOR i := 0 TO 31 DO
				toVirtual[i+RAX] := unusable;
			END;
			FOR i := 8 TO 15 DO
				toVirtual[i+AL] := unusable;
				toVirtual[i+AH] := unusable;
				toVirtual[i+EAX] := unusable;
				toVirtual[i+AX] := unusable;
			END;
			FOR i := 4 TO 7 DO
				toVirtual[i+AL] := unusable;
				toVirtual[i+AH] := unusable;
			END;
			FOR i := 0 TO LEN(reserved)-1 DO reserved[i] := FALSE END;
		END InitPhysicalRegisters32;

		PROCEDURE Allocate(index: LONGINT; virtualRegister: Ticket);
		BEGIN
			(*
			D.String("allocate register x : index="); D.Int(index,1); D.Ln;
			*)
			Assert(toVirtual[index] = free,"register already allocated");
			toVirtual[index] := virtualRegister;
			IF index DIV 32 = 2 THEN (* 32 bit *)
				Assert(toVirtual[index MOD 32 + AX] = free,"free register split");
				toVirtual[index MOD 32 + AX] := blocked;
				IF index MOD 32 < 4 THEN
					Assert(toVirtual[index MOD 32 + AL] = free,"register already allocated");
					Assert(toVirtual[index MOD 32 + AH] = free,"register already allocated");
					toVirtual[index MOD 32 + AL] := blocked;
					toVirtual[index MOD 32 + AH] := blocked;
				END;
			ELSIF index DIV 32 = 1 THEN (* 16 bit *)
				Assert(toVirtual[index MOD 8 + EAX] = free,"free register split");
				toVirtual[index MOD 32 + EAX] := split;
				IF index MOD 32 < 4 THEN
					Assert(toVirtual[index MOD 32 + AL] = free,"register already allocated");
					Assert(toVirtual[index MOD 32 + AH] = free,"register already allocated");
					toVirtual[index MOD 32 + AL] := blocked;
					toVirtual[index MOD 32 + AH] := blocked;
				END;
			ELSIF index DIV 32 = 0 THEN (* 8 bit *)
				Assert((toVirtual[index MOD 4 + EAX] = free) OR (toVirtual[index MOD 4 + EAX] = split),"free register blocked");
				Assert((toVirtual[index MOD 4 + AX] = free) OR (toVirtual[index MOD 4 + AX] = split),"free register blocked");
				toVirtual[index MOD 4 + EAX] := split;
				toVirtual[index MOD 4 + AX] := split;
			ELSIF (index >= XMM0) & (index <= XMM7) THEN (* vector register *)
			ELSE Assert( (index >=InstructionSet.regST0) & (index <= InstructionSet.regST7 ),"not a float register"); (* floats *)
			END;
		END Allocate;

		PROCEDURE SetReserved(index: LONGINT; res: BOOLEAN);
		BEGIN
			IF index DIV 32 <=2 THEN
				index := index MOD 16;
				reserved[index+AH] := res;
				reserved[index+AL] := res;
				reserved[index+AX] := res;
				reserved[index+EAX] := res;
			ELSE
				reserved[index] := res;
			END;
		END SetReserved;

		PROCEDURE Reserved(index: LONGINT): BOOLEAN;
		BEGIN
			RETURN (index>0) & reserved[index]
		END Reserved;

		PROCEDURE Free(index: LONGINT);
		VAR x: Ticket;
		BEGIN
			(*
			D.String("free register x : index="); D.Int(index,1); D.Ln;
			*)
			x := toVirtual[index];
			Assert((toVirtual[index] # NIL),"register not reserved");
			toVirtual[index] := free;
			IF index DIV 32 =2  THEN (* 32 bit *)
				Assert(toVirtual[index MOD 32 + AX] = blocked,"reserved register did not block");
				toVirtual[index MOD 32 + AX] := free;
				IF index MOD 32 < 4 THEN
					Assert(toVirtual[index MOD 32 + AL] = blocked,"reserved register did not block");
					Assert(toVirtual[index MOD 32 + AH] = blocked,"reserved register did not block");
					toVirtual[index MOD 32 + AL] := free;
					toVirtual[index MOD 32 + AH] := free;
				END;
			ELSIF index DIV 32 = 1 THEN (* 16 bit *)
				Assert(toVirtual[index MOD 32 + EAX] = split,"reserved register did not split");
				toVirtual[index MOD 32 + EAX] := free;
				IF index MOD 32 < 4 THEN
					Assert(toVirtual[index MOD 32 + AL] = blocked,"reserved register did not block");
					Assert(toVirtual[index MOD 32 + AH] = blocked,"reserved register did not block");
					toVirtual[index MOD 32 + AL] := free;
					toVirtual[index MOD 32 + AH] := free;
				END;
			ELSIF index DIV 32 = 0 THEN (* 8 bit *)
				IF (toVirtual[index MOD 4 + AL] = free) & (toVirtual[index MOD 4 + AH] = free) THEN
					Assert(toVirtual[index MOD 4 + EAX] = split,"reserved register did not split");
					Assert(toVirtual[index MOD 4 + AX] = split,"reserved register did not split");
					toVirtual[index MOD 4 + EAX] := free;
					toVirtual[index MOD 4 + AX] := free;
				END;
			ELSIF (index >= XMM0) & (index <= XMM7) THEN (* vector register *)
			ELSE Assert( (index >=InstructionSet.regST0) & (index <= InstructionSet.regST7 ),"not a float register"); (* floats *)
			END;
		END Free;

		PROCEDURE NextFree(CONST type: IntermediateCode.Type):LONGINT;
		VAR i,sizeInBits,length, form: LONGINT;

			PROCEDURE GetGPHint(offset: LONGINT): LONGINT;
			VAR res: LONGINT;
			BEGIN
				IF (hint # none) & (hint >= AL) & (hint <= EDI) & (toVirtual[hint MOD 32 + offset]=free) & ~Reserved(hint) THEN res := hint MOD 32 + offset ELSE res := none END;
				hint := none;
				RETURN res
			END GetGPHint;

			PROCEDURE GetHint(from,to: LONGINT): LONGINT;
			VAR res: LONGINT;
			BEGIN
				IF (hint # none) & (hint >= from) & (hint <= to) & (toVirtual[hint]=free) & ~Reserved(hint) THEN res := hint ELSE res := none END;
				hint := none;
				RETURN res
			END GetHint;

			PROCEDURE Get(from,to: LONGINT): LONGINT;
			VAR i: LONGINT;
			BEGIN
				i := from;
				IF from <= to THEN
					WHILE (i <= to) & ((toVirtual[i]#free) OR Reserved(i)) DO INC(i) END;
					IF i > to THEN i := none END;
				ELSE
					WHILE (i >=to) & ((toVirtual[i]#free) OR Reserved(i)) DO DEC(i) END;
					IF i < to THEN i := none END;
				END;
				RETURN i
			END Get;

		BEGIN
			length := type.length;
			sizeInBits := type.sizeInBits;
			form := type.form;
			IF (type.length > 1) THEN
				IF (* (type.form = IntermediateCode.Float) &*)  (type.sizeInBits=32) & (type.length =4) THEN
					i := Get(XMM7, XMM0);
				ELSE
					HALT(100)
				END
			ELSIF type.form IN IntermediateCode.Integer THEN
				sizeInBits := type.sizeInBits;
				IF type.sizeInBits = IntermediateCode.Bits8 THEN
					i := GetGPHint(AL);
					IF i = none THEN i := Get(BL, AL) END;
					IF i = none THEN i := Get(BH, AH) END;
				ELSIF type.sizeInBits = IntermediateCode.Bits16 THEN
					i := GetGPHint(AX);
					IF i = none THEN i := Get(DI, SI) END;
					IF i = none THEN i := Get(BX, AX) END;
				ELSIF type.sizeInBits = IntermediateCode.Bits32 THEN
					i := GetGPHint(EAX);
					IF i = none THEN i := Get(EDI,ESI) END;
					IF i = none THEN i := Get(EBX,EAX) END;
				ELSE HALT(100)
				END;
			ELSE
				ASSERT(type.form = IntermediateCode.Float);
				IF useFPU THEN
					i := Get(InstructionSet.regST0, InstructionSet.regST6);
					(* ST7 unusable as it is overwritten during arithmetic instructions *)
				ELSE
					i := GetHint(XMM0, XMM7);
					IF i = none THEN 	i := Get(XMM7, XMM0) END
				END;
			END;
			hint := none; (* reset *)
			RETURN i
		END NextFree;

		PROCEDURE Mapped(physical: LONGINT): Ticket;
		VAR virtual: Ticket;
		BEGIN
			virtual := toVirtual[physical];
			IF virtual = blocked THEN virtual :=  Mapped(physical+32)
			ELSIF virtual = split THEN
				IF physical < 32 THEN virtual := Mapped(physical+16 MOD 32)
				ELSE virtual := Mapped(physical-32)
				END;
			END;

			ASSERT((virtual = free) OR (virtual = unusable) OR (toVirtual[virtual.register] = virtual));
			RETURN virtual
		END Mapped;

		PROCEDURE Dump(w: Streams.Writer);
		VAR i: LONGINT; virtual: Ticket;
		BEGIN
			w.String("; ---- registers ----"); w.Ln;
			FOR i := 0 TO LEN(toVirtual)-1 DO
				virtual := toVirtual[i];
				IF virtual # unusable THEN
					w.String("reg "); w.Int(i,1); w.String(": ");
					IF virtual = free THEN w.String("free")
					ELSIF virtual = blocked THEN w.String("blocked")
					ELSIF virtual = split THEN w.String("split")
					ELSE	w.String(" r"); w.Int(virtual.register,1);
					END;
					IF reserved[i] THEN w.String("reserved") END;
					w.Ln;
				END;
			END;
		END Dump;

	END PhysicalRegisters32;

	PhysicalRegisters64=OBJECT (PhysicalRegisters) (* 64 bit implementation *)

		PROCEDURE & InitPhysicalRegisters64(fpu,cooperative: BOOLEAN);
		BEGIN
			InitPhysicalRegisters(fpu,cooperative);
		END InitPhysicalRegisters64;

		PROCEDURE SetReserved(index: LONGINT; res: BOOLEAN);
		BEGIN
			(*
			IF res THEN D.String("reserve ") ELSE D.String("unreserve ") END;
			D.String("register: index="); D.Int(index,1); D.Ln;
			*)
			IF index DIV 32 <=2 THEN
				index := index MOD 16;
				reserved[index+AH] := res;
				reserved[index+AL] := res;
				reserved[index+AX] := res;
				reserved[index+EAX] := res;
				reserved[index+RAX] := res;
			ELSE
				reserved[index] := res
			END;
		END SetReserved;

		PROCEDURE Reserved(index: LONGINT): BOOLEAN;
		BEGIN
			RETURN reserved[index]
		END Reserved;

		PROCEDURE Allocate(index: LONGINT; virtualRegister: Ticket);
		BEGIN
			(*
			D.String("allocate register x : index="); D.Int(index,1); D.Ln;
			*)
			Assert(toVirtual[index] = free,"register already allocated");
			toVirtual[index] := virtualRegister;
			IF index DIV 32 = 3 THEN (* 64 bit *)
				Assert(toVirtual[index MOD 32 + EAX] = free,"free register split");
				toVirtual[index MOD 32 + EAX] := blocked;
				toVirtual[index MOD 32 + AX] := blocked;
				toVirtual[index MOD 32 + AL] := blocked;
			ELSIF index DIV 32 = 2 THEN (* 32 bit *)
				Assert(toVirtual[index MOD 32 + AX] = free,"free register split");
				toVirtual[index MOD 32 + RAX] := split;
				toVirtual[index MOD 32 + AX] := blocked;
				toVirtual[index MOD 32 + AL] := blocked;
			ELSIF index DIV 32 = 1 THEN (* 16 bit *)
				toVirtual[index MOD 32 + RAX] := split;
				toVirtual[index MOD 32 + EAX] := split;
				toVirtual[index MOD 32 + AL] := blocked;
			ELSIF index DIV 32 = 0 THEN (* 8 bit *)
				toVirtual[index MOD 32 + RAX] := split;
				toVirtual[index MOD 32 + EAX] := split;
				toVirtual[index MOD 32 + AX] := split;
			ELSE Assert( (index >=InstructionSet.regST0) & (index <= InstructionSet.regST7 ),"not a float register"); (* floats *)
			END;
		END Allocate;

		PROCEDURE Free(index: LONGINT);
		BEGIN
			(*
			D.String("release register x : index="); D.Int(index,1); D.Ln;
			*)
			Assert(toVirtual[index]#NIL,"register not reserved");
			toVirtual[index] := free;
			IF index DIV 32 =3  THEN (* 64 bit *)
				Assert(toVirtual[index MOD 32 + EAX] = blocked,"reserved register did not block");
				toVirtual[index MOD 32 + EAX] := free;
				toVirtual[index MOD 32 + AX] := free;
				toVirtual[index MOD 32 + AL] := free;
			ELSIF index DIV 32 =2  THEN (* 32 bit *)
				Assert(toVirtual[index MOD 32 + RAX] = split,"reserved register did not split");
				Assert(toVirtual[index MOD 32 + AX] = blocked,"reserved register did not block");
				Assert(toVirtual[index MOD 32 + AL] = blocked,"reserved register did not block");
				toVirtual[index MOD 32 + RAX] := free;
				toVirtual[index MOD 32 + AX] := free;
				toVirtual[index MOD 32 + AL] := free;
			ELSIF index DIV 32 = 1 THEN (* 16 bit *)
				Assert(toVirtual[index MOD 32 + RAX] = split,"reserved register did not split");
				Assert(toVirtual[index MOD 32 + EAX] = split,"reserved register did not split");
				Assert(toVirtual[index MOD 32 + AL] = blocked,"reserved register did not split");
				toVirtual[index MOD 32 + RAX] := free;
				toVirtual[index MOD 32 + EAX] := free;
				toVirtual[index MOD 32 + AL] := free;
			ELSIF index DIV 32 = 0 THEN (* 8 bit *)
				Assert(toVirtual[index MOD 32 + RAX] = split,"reserved register did not split");
				Assert(toVirtual[index MOD 32 + EAX] = split,"reserved register did not split");
				Assert(toVirtual[index MOD 32 + AX] = split,"reserved register did not split");
				toVirtual[index MOD 32 + RAX] := free;
				toVirtual[index MOD 32 + EAX] := free;
				toVirtual[index MOD 32 + AX] := free;
			ELSE Assert( (index >=InstructionSet.regST0) & (index <= InstructionSet.regST7 ),"not a float register"); (* floats *)
			END;
		END Free;

		PROCEDURE NextFree(CONST type: IntermediateCode.Type): LONGINT;
		VAR i: LONGINT;

			PROCEDURE GetHint(offset: LONGINT): LONGINT;
			VAR res: LONGINT;
			BEGIN
				IF (hint # none) & (toVirtual[hint MOD 32 + offset]=free) & ~Reserved(hint) THEN res := hint ELSE res := none END;
				hint := none;
				RETURN res
			END GetHint;

			PROCEDURE Get(from,to: LONGINT): LONGINT;
			VAR i: LONGINT;
			BEGIN
				i := from;
				IF from <= to THEN
					WHILE (i <= to) & ((toVirtual[i]#free) OR Reserved(i)) DO INC(i) END;
					IF i > to THEN i := none END;
				ELSE
					WHILE (i >=to) & ((toVirtual[i]#free) OR Reserved(i)) DO DEC(i) END;
					IF i < to THEN i := none END;
				END;
				RETURN i
			END Get;

			BEGIN
			IF type.form IN IntermediateCode.Integer THEN
				IF type.sizeInBits = IntermediateCode.Bits8 THEN
					i := GetHint(AL);
					IF i = none THEN
						i := Get(AL,R15B)
					END;
				ELSIF type.sizeInBits = IntermediateCode.Bits16 THEN
					i := GetHint(AX);
					IF i = none THEN
						i := Get(AX,R15W);
					END;
				ELSIF type.sizeInBits = IntermediateCode.Bits32 THEN
					i := GetHint(EAX);
					IF i = none THEN
						i := Get(EAX,R15D);
					END;
				ELSIF type.sizeInBits = IntermediateCode.Bits64 THEN
					i := GetHint(RAX);
					IF i = none THEN
						i := Get(RAX, R15)
					END;
				ELSE HALT(100)
				END;
			ELSE
				ASSERT(type.form = IntermediateCode.Float);
				IF useFPU THEN
					i := Get(InstructionSet.regST0, InstructionSet.regST6);
					(* ST7 unusable as it is overwritten during arithmetic instructions *)
				ELSE
					i := Get(XMM7, XMM0)
				END;
			END;
			RETURN i;
		END NextFree;

		PROCEDURE Mapped(physical: LONGINT): Ticket;
		VAR virtual: Ticket;
		BEGIN
			virtual := toVirtual[physical];
			IF virtual = blocked THEN RETURN Mapped(physical+32) END;
			IF virtual = split THEN RETURN Mapped(physical-32) END;
			RETURN virtual
		END Mapped;

	END PhysicalRegisters64;

	CodeGeneratorAMD64 = OBJECT (CodeGenerators.GeneratorWithTickets)
	VAR
		(* static generator state variables, considered constant during generation *)
		runtimeModuleName: SyntaxTree.IdentifierString;
		cpuBits: LONGINT;
		opBP, opSP, opRA, opRB, opRC, opRD, opRS, opR8, opR9: Assembler.Operand; (* base pointer, stack pointer, register A, depends on cpuBits*)
		BP, SP, RA, RD, RS, RC: LONGINT; (* base pointer and stack pointer register index, depends on cpuBits *)

		emitter: Assembler.Emitter; (* assembler generating and containing the machine code *)
		backend: BackendAMD64;

		(* register spill state *)
		stackSize: LONGINT;
		spillStackStart: LONGINT;

		(* floating point stack state *)
		fpStackPointer: LONGINT; (* floating point stack pointer, increases with allocation, decreases with releasing, used to determine current relative position on stack (as is necessary for intel FP instructions) *)
		(*
			FP register usage scheme:

												sp=1>	FP0 - temp
		sp=0>	FP0 - reg0								FP1 - reg0						sp=0>	FP0 - reg0
				FP1 - reg1								FP2 - reg1								FP1 - reg1
				FP2 - reg2								FP3 - reg2								FP2 - reg2
				FP3 - reg3	 = load op1 =>			FP4 - reg3		= op =>				FP3 - reg3
				FP4 - reg4								FP5 - reg4								FP4 - reg4
				FP5 - reg5								FP6 - reg5								FP5 - reg5
				FP6 - reg6								FP7 - reg6								FP6 - reg6
				FP7 - reg7									(reg7 lost)							FP7 - reg7

		*)

		ap: Ticket;

		(* -------------------------- constructor -------------------------------*)
		PROCEDURE &InitGeneratorAMD64(CONST runtime: SyntaxTree.IdentifierString; diagnostics: Diagnostics.Diagnostics; backend: BackendAMD64);
		VAR physicalRegisters: PhysicalRegisters; physicalRegisters32: PhysicalRegisters32; physicalRegisters64: PhysicalRegisters64;
		BEGIN
			SELF.backend := backend;
			runtimeModuleName := runtime;
			SELF.cpuBits := backend.bits;

			NEW(emitter,diagnostics);
			IF cpuBits=32 THEN
				NEW(physicalRegisters32, backend.forceFPU, backend.cooperative); physicalRegisters := physicalRegisters32; error := ~emitter.SetBits(32);
				opBP := opEBP; opSP := opESP; opRA := opEAX; opRB := opEBX; opRD := opEDI; opRS := opESI; opRC := opECX;
				SP := ESP; BP := EBP; RA := EAX;
				RD := EDI; RS := ESI; RC := ECX;
				ASSERT(~error);
			ELSIF cpuBits=64 THEN
				NEW(physicalRegisters64, backend.forceFPU, backend.cooperative); physicalRegisters := physicalRegisters64; error := ~emitter.SetBits(64);
				opBP := opRBP; opSP := opRSP; opRA := registerOperands[RAX]; opRB := registerOperands[RBX]; opRD := registerOperands[RDI];
				opRS := registerOperands[RSI]; opRC := registerOperands[RCX];
				opR8 := registerOperands[R8]; opR9 := registerOperands[R9];
				SP := RSP; BP := RBP; RA := RAX;
				RD := RDI; RS := RSI; RC := RCX;
				ASSERT(~error);
			ELSE Halt("no register allocator for bits other than 32 / 64 ");
			END;

			fpStackPointer := 0;
			InitTicketGenerator(diagnostics,backend.optimize,2,physicalRegisters);
		END InitGeneratorAMD64;

		(*------------------- overwritten methods ----------------------*)
		PROCEDURE Section(in: IntermediateCode.Section; out: BinaryCode.Section);
		VAR oldSpillStackSize: LONGINT;

			PROCEDURE CheckEmptySpillStack;
			BEGIN
				IF spillStack.Size()#0 THEN Error(inPC,"implementation error, spill stack not cleared") END;
			END CheckEmptySpillStack;

		BEGIN
			spillStack.Init;
			IF backend.cooperative THEN
				ap := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.UnsignedIntegerType(cpuBits),RC,in.pc);
				ap.spillable := FALSE;
			END;
			emitter.SetCode(out);
			Section^(in,out);
			IF FrameSpillStack & (spillStack.MaxSize() >0) THEN
				oldSpillStackSize := spillStack.MaxSize();
				out.Reset;
				CheckEmptySpillStack;
				Section^(in,out);
				ASSERT(spillStack.MaxSize() = oldSpillStackSize);
			END;
			ASSERT(fpStackPointer = 0);
			CheckEmptySpillStack;
			IF backend.cooperative THEN 
				UnmapTicket(ap);
			END;
			error := error OR emitter.error;
		END Section;

		PROCEDURE Supported(CONST instruction: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			COPY(runtimeModuleName, moduleName);
			IF (cpuBits=32) & (instruction.op2.type.sizeInBits = IntermediateCode.Bits64) & (instruction.op2.type.form IN IntermediateCode.Integer) THEN
				CASE instruction.opcode OF
				IntermediateCode.div:
					procedureName := "DivH"; RETURN FALSE
				| IntermediateCode.mul:
					procedureName := "MulH"; RETURN FALSE
				| IntermediateCode.mod :
					procedureName := "ModH"; RETURN FALSE
				| IntermediateCode.abs :
					procedureName := "AbsH"; RETURN FALSE;
				| IntermediateCode.shl :
					IF instruction.op1.type.form = IntermediateCode.SignedInteger THEN
						procedureName := "AslH"; RETURN FALSE;
					ELSE
						procedureName := "LslH"; RETURN FALSE;
					END;
				| IntermediateCode.shr :
					IF instruction.op1.type.form = IntermediateCode.SignedInteger THEN
						procedureName := "AsrH"; RETURN FALSE;
					ELSE
						procedureName := "LsrH"; RETURN FALSE;
					END;
				| IntermediateCode.ror :
					procedureName := "RorH"; RETURN FALSE;
				| IntermediateCode.rol :
					procedureName := "RolH"; RETURN FALSE;
				| IntermediateCode.cas :
					procedureName := "CasH"; RETURN FALSE;
				ELSE RETURN TRUE
				END;
			ELSIF ~backend.forceFPU & (instruction.opcode = IntermediateCode.conv) & (instruction.op1.type.form IN IntermediateCode.Integer) & (instruction.op2.type.form = IntermediateCode.Float)  & IsComplex(instruction.op1) THEN
				IF instruction.op2.type.sizeInBits=32 THEN
					procedureName := "EntierRH"
				ELSE
					procedureName := "EntierXH"
				END;
				RETURN FALSE
			END;
			RETURN TRUE
		END Supported;

		(* input: type (such as that of an intermediate operand), output: low and high type (such as in low and high type of an operand) *)
		PROCEDURE GetPartType(CONST type: IntermediateCode.Type; part: LONGINT; VAR typePart: IntermediateCode.Type);
		BEGIN
			ASSERT(type.sizeInBits >0);
			IF (type.sizeInBits > cpuBits) & (type.form IN IntermediateCode.Integer) THEN
				IntermediateCode.InitType(typePart,type.form,32);
			ELSE ASSERT((type.form IN IntermediateCode.Integer) OR (type.form = IntermediateCode.Float));
				IF part=Low THEN typePart := type ELSE typePart := IntermediateCode.undef END;
			END;
		END GetPartType;

		(* simple move without conversion *)
		PROCEDURE Move(VAR dest, src: Assembler.Operand; CONST type: IntermediateCode.Type);
		BEGIN
			IF type.length > 1 THEN
				IF type.length = 4 THEN
					(*ASSERT(type.form = IntermediateCode.Float);*)
					ASSERT(type.sizeInBits = 32);
					SpecialMove(InstructionSet.opMOVUPS, InstructionSet.opMOVUPS, TRUE, dest, src, type);
				ELSE
					(*
					ASSERT(type.form = IntermediateCode.Float);
					*)
					ASSERT(type.sizeInBits = 64);
					SpecialMove(InstructionSet.opMOVUPD, InstructionSet.opMOVUPS, TRUE, dest, src, type);
				END;
			ELSIF type.form = IntermediateCode.Float THEN
				IF type.sizeInBits = 32 THEN
					SpecialMove(InstructionSet.opMOVSS, InstructionSet.opMOVSS, TRUE, dest, src, type);
				ELSE
					SpecialMove(InstructionSet.opMOVSD, InstructionSet.opMOVSD, TRUE, dest, src, type);
				END;
			ELSE
				SpecialMove(InstructionSet.opMOV, InstructionSet.opMOV, TRUE, dest, src, type);
			END;
		END Move;

		PROCEDURE ToSpillStack(ticket: Ticket);
		VAR op: Assembler.Operand;
		BEGIN
			IF (ticket.type.form = IntermediateCode.Float) & backend.forceFPU THEN
				emitter.Emit1(InstructionSet.opFLD,registerOperands[ticket.register]);
				INC(fpStackPointer);
				GetSpillOperand(ticket,op);
				emitter.Emit1(InstructionSet.opFSTP,op);
				DEC(fpStackPointer);
			ELSE
				GetSpillOperand(ticket,op);
				Move(op, registerOperands[ticket.register], ticket.type)
			END;
		END ToSpillStack;

		PROCEDURE AllocateSpillStack(size: LONGINT);
		BEGIN
			IF ~FrameSpillStack THEN
				AllocateStack(cpuBits DIV 8*size)
			END;
		END AllocateSpillStack;

		PROCEDURE ToRegister(ticket: Ticket);
		VAR op: Assembler.Operand;
		BEGIN
			GetSpillOperand(ticket,op);
			emitter.Emit2(InstructionSet.opMOV,registerOperands[ticket.register],op);
		END ToRegister;

		PROCEDURE ExchangeTickets(ticket1,ticket2: Ticket);
		VAR op1,op2: Assembler.Operand;
		BEGIN
			TicketToOperand(ticket1, op1);
			TicketToOperand(ticket2, op2);
			emitter.Emit2(InstructionSet.opXCHG, op1,op2);
		END ExchangeTickets;

		(*-------------------  particular register mappings / operands  ----------------------*)

		(* returns if a virtual register is mapped to the register set described by virtualRegisterMapping*)
		PROCEDURE MappedTo(CONST virtualRegister: LONGINT; part:LONGINT; physicalRegister: LONGINT): BOOLEAN;
		VAR ticket: Ticket;
		BEGIN
			IF (virtualRegister > 0) THEN
				ticket := virtualRegisters.Mapped(virtualRegister,part);
				RETURN (ticket # NIL) & ~(ticket.spilled) & (ticket.register = physicalRegister)
			ELSIF (virtualRegister = IntermediateCode.FP) THEN
				RETURN physicalRegister= BP
			ELSIF (virtualRegister = IntermediateCode.SP) THEN
				RETURN physicalRegister = SP
			ELSIF (virtualRegister = IntermediateCode.AP) THEN
				ASSERT(backend.cooperative);
				RETURN ~(ap.spilled) & (ap.register = physicalRegister)
			ELSE
				RETURN FALSE
			END;
		END MappedTo;

		PROCEDURE ResultRegister(CONST type: IntermediateCode.Type; part: LONGINT): LONGINT;
		BEGIN
			IF type.form IN IntermediateCode.Integer THEN
				CASE type.sizeInBits OF
					| 64:
						IF cpuBits = 32 THEN
							IF part = Low THEN RETURN EAX
							ELSE RETURN EDX
							END;
						ELSE
							ASSERT(part = Low);
							RETURN RAX
						END;
					| 32: ASSERT(part=Low); RETURN EAX
					| 16: ASSERT(part=Low); RETURN AX
					| 8: ASSERT(part=Low); RETURN AL
				END;
			ELSIF ~backend.forceFPU THEN
				RETURN XMM0
			ELSE ASSERT(type.form = IntermediateCode.Float);ASSERT(part=Low);
				RETURN ST0
			END;
		END ResultRegister;

		(*-------------------  operand reflection ----------------------*)
		PROCEDURE IsMemoryOperand(vop: IntermediateCode.Operand; part: LONGINT): BOOLEAN;
		VAR ticket: Ticket;
		BEGIN
			IF vop.mode = IntermediateCode.ModeMemory THEN RETURN TRUE
			ELSIF vop.mode = IntermediateCode.ModeRegister THEN
				ticket := virtualRegisters.Mapped(vop.register,part);
				RETURN (ticket # NIL) & (ticket.spilled);
			ELSE RETURN FALSE
			END;
		END IsMemoryOperand;

		PROCEDURE IsRegister(CONST vop: IntermediateCode.Operand): BOOLEAN;
		BEGIN
			RETURN (vop.mode = IntermediateCode.ModeRegister) & (vop.offset = 0)
		END IsRegister;

		(* infer intermediate code type from physical operand as far as possible *)
		PROCEDURE PhysicalOperandType(CONST op:Assembler.Operand): IntermediateCode.Type;
		VAR type:IntermediateCode.Type;
		BEGIN
			IF op.type = Assembler.sti THEN
				IntermediateCode.InitType(type, IntermediateCode.Float, op.sizeInBytes*8)
			ELSE
				IntermediateCode.InitType(type, IntermediateCode.SignedInteger, op.sizeInBytes*8)
			END;
			RETURN type
		END PhysicalOperandType;

		(*-------------------  operand generation ----------------------*)
		PROCEDURE GetSpillOperand(ticket: Ticket; VAR op: Assembler.Operand);
		BEGIN
			IF FrameSpillStack THEN
				op := Assembler.NewMem(SHORTINT(ticket.type.sizeInBits*ticket.type.length DIV 8), BP , -(spillStackStart + cpuBits DIV 8 + ticket.offset*cpuBits DIV 8));
			ELSE
				op := Assembler.NewMem(SHORTINT(ticket.type.sizeInBits*ticket.type.length DIV 8),SP , (spillStack.Size()-ticket.offset)*cpuBits DIV 8);
			END;
		END GetSpillOperand;

		PROCEDURE TicketToOperand(ticket: Ticket; VAR op: Assembler.Operand);
		BEGIN
			IF (ticket = NIL) THEN
				Assembler.InitOperand(op)
			ELSIF ticket.spilled THEN
				GetSpillOperand(ticket,op)
			ELSE
				IF ticket.register = none THEN physicalRegisters.Dump(D.Log); tickets.Dump(D.Log); virtualRegisters.Dump(D.Log); D.Update; END;
				ASSERT(ticket.register # none);
				IF (ticket.type.form = IntermediateCode.Float) & backend.forceFPU THEN
					op := registerOperands[ticket.register+fpStackPointer]
				ELSE
					op := registerOperands[ticket.register];
				END;
			END;
		END TicketToOperand;

		PROCEDURE GetTemporaryRegister(type: IntermediateCode.Type; VAR op: Assembler.Operand);
		BEGIN
			TicketToOperand(TemporaryTicket(IntermediateCode.GeneralPurposeRegister,type),op)
		END GetTemporaryRegister;

		PROCEDURE GetImmediateMem(CONST vop: IntermediateCode.Operand; part: LONGINT; VAR imm: Assembler.Operand);
		VAR data: IntermediateCode.Section;pc: LONGINT;
		BEGIN
			data := GetDataSection();
			pc := IntermediateBackend.EnterImmediate(data,vop);
			Assembler.InitMem(imm, SHORT(vop.type.sizeInBits DIV 8) , Assembler.none,0);
			Assembler.SetSymbol(imm,data.name,0,pc,0);
		END GetImmediateMem;

		PROCEDURE GetImmediate(CONST virtual: IntermediateCode.Operand; part: LONGINT; VAR physical: Assembler.Operand; forbidden16Bit: BOOLEAN);
		VAR type: IntermediateCode.Type; temp: Assembler.Operand; size: SHORTINT; value: HUGEINT;

			PROCEDURE IsImm8(value: HUGEINT): BOOLEAN;
			BEGIN
				RETURN (value >= -80H) & (value < 80H)
			END IsImm8;

			PROCEDURE IsImm16(value: HUGEINT): BOOLEAN;
			BEGIN
				RETURN (value >= -8000H) & (value < 10000H)
			END IsImm16;

			PROCEDURE IsImm32(value: HUGEINT): BOOLEAN;
			BEGIN
				value := value DIV 10000H DIV 10000H;
				RETURN (value = 0) OR (value=-1);
			END IsImm32;

		BEGIN
			ASSERT(virtual.mode = IntermediateCode.ModeImmediate);
			GetPartType(virtual.type,part,type);
			IF virtual.type.form IN IntermediateCode.Integer THEN
				IF IsComplex(virtual) THEN
					IF part = High THEN value := SHORT(virtual.intValue DIV 10000H DIV 10000H)
					ELSE value := virtual.intValue
					END;
				ELSE value := virtual.intValue
				END;

				IF virtual.symbol.name # "" THEN size := SHORT(type.sizeInBits DIV 8);
				ELSIF forbidden16Bit & IsImm16(value) & ~(IsImm8(value)) THEN size := Assembler.bits32;
				ELSE size := 0
				END;
				Assembler.InitImm(physical,size ,value);
				IF virtual.symbol.name # "" THEN Assembler.SetSymbol(physical,virtual.symbol.name,virtual.symbol.fingerprint,virtual.symbolOffset,virtual.offset+part*Assembler.bits32) END;
				IF (cpuBits=64) & ((physical.sizeInBytes=8) OR ~IsImm32(value)) THEN
					ASSERT(cpuBits=64);
					GetTemporaryRegister(IntermediateCode.int64,temp);
					emitter.Emit2(InstructionSet.opMOV,temp,physical);
					physical := temp;
				END;
			ELSE
				GetImmediateMem(virtual,part,physical);
			END;
		END GetImmediate;

		PROCEDURE GetMemory(CONST virtual: IntermediateCode.Operand; part: LONGINT; VAR physical: Assembler.Operand);
		VAR type: IntermediateCode.Type; virtualRegister, physicalRegister,offset: LONGINT; ticket,orig: Ticket; dest, source: Assembler.Operand;
		BEGIN
			ASSERT(virtual.mode = IntermediateCode.ModeMemory);
			GetPartType(virtual.type,part,type);

			IF virtual.register # IntermediateCode.None THEN
				virtualRegister := virtual.register;
				IF virtualRegister = IntermediateCode.FP THEN physicalRegister := BP;
				ELSIF virtualRegister = IntermediateCode.SP THEN  physicalRegister := SP;
				ELSE
					IF virtualRegister = IntermediateCode.AP THEN
						ticket := ap;
					ELSE
						ticket := virtualRegisters.Mapped(virtualRegister,Low);
					END;
					IF ticket.spilled THEN
						IF physicalRegisters.Reserved(ticket.register) THEN
							orig := ticket;
							ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateBackend.GetType(module.system,module.system.addressType));
							TicketToOperand(orig,source);
							TicketToOperand(ticket,dest);
							Move(dest,source,PhysicalOperandType(dest));
							physicalRegister := ticket.register;
						ELSE
							UnSpill(ticket);
							physicalRegister := ticket.register;
						END;
					ELSE
						physicalRegister := ticket.register;
					END;
				END;
				offset := virtual.offset;
				ASSERT(virtual.intValue = 0);
			ELSIF virtual.symbol.name # "" THEN
				physicalRegister := Assembler.none;
				offset := virtual.offset;
				ASSERT(virtual.intValue = 0);
			ELSE
				physicalRegister := Assembler.none;
				offset := SHORT(virtual.intValue);
				ASSERT(virtual.offset = 0);
			END;
			Assembler.InitMem(physical, SHORTINT(type.length * type.sizeInBits DIV 8) , physicalRegister, offset+4*part);
			IF virtual.symbol.name # "" THEN
				Assembler.SetSymbol(physical,virtual.symbol.name,virtual.symbol.fingerprint,virtual.symbolOffset,virtual.offset+4*part);
			END;
		END GetMemory;

		PROCEDURE HardwareIntegerRegister(index: LONGINT; sizeInBits: LONGINT): LONGINT;
		BEGIN
			index := index MOD 32;
			sizeInBits := sizeInBits DIV 8;
			WHILE sizeInBits > 1 DO (* jump to register section that corresponds to the number of bits *)
				INC(index,32);
				sizeInBits := sizeInBits DIV 2;
			END;
			RETURN index
		END HardwareIntegerRegister;

		PROCEDURE HardwareFloatRegister(index: LONGINT; sizeInBits: LONGINT): LONGINT;
		BEGIN HALT(200); (* not yet implemented *)
		END HardwareFloatRegister;

		PROCEDURE GetTypedHardwareRegister(index: LONGINT; type: IntermediateCode.Type): LONGINT;
		VAR size: LONGINT;
		BEGIN
			IF type.form IN IntermediateCode.Integer THEN
				RETURN HardwareIntegerRegister(index, type.sizeInBits)
			ELSIF type.form = IntermediateCode.Float THEN
				RETURN HardwareFloatRegister(index, type.sizeInBits)
			ELSE
				HALT(100);
			END;
		END GetTypedHardwareRegister;

		PROCEDURE ParameterRegister(CONST type: IntermediateCode.Type; index: LONGINT): LONGINT;
		VAR physical: LONGINT;
		BEGIN
			CASE index OF
				0: RETURN GetTypedHardwareRegister(RCX,type)
				|1: RETURN GetTypedHardwareRegister(RDX,type)
				|2: RETURN GetTypedHardwareRegister(R8,type)
				|3: RETURN GetTypedHardwareRegister(R9,type)
			END;
			RETURN physical;
		END ParameterRegister;

		PROCEDURE GetRegister(CONST virtual: IntermediateCode.Operand; part:LONGINT; VAR physical: Assembler.Operand; VAR ticket: Ticket);
		VAR type: IntermediateCode.Type; virtualRegister, tempReg: LONGINT;
			tmp,imm: Assembler.Operand; index: LONGINT;
		BEGIN
			ASSERT(virtual.mode = IntermediateCode.ModeRegister);
			GetPartType(virtual.type,part,type);
			virtualRegister := virtual.register;

			IF (virtual.register > 0) THEN
				TicketToOperand(virtualRegisters.Mapped(virtual.register,part), physical);
			ELSIF virtual.register = IntermediateCode.FP THEN
				Assert(part=Low,"forbidden partitioned register on BP");
				physical := opBP;
			ELSIF virtual.register = IntermediateCode.SP THEN
				Assert(part=Low,"forbidden partitioned register on SP");
				physical := opSP;
			(*! done by generic part:
				ELSIF virtual.register <= IntermediateCode.ParameterRegister THEN
				index := IntermediateCode.ParameterRegister - virtualRegister;
				physical := registerOperands[ParameterRegister(index, type)];
			*)
			ELSIF virtual.register = IntermediateCode.AP THEN
				ASSERT(backend.cooperative);
				Assert(part=Low,"forbidden partitioned register on AP");
				TicketToOperand(ap, physical);
			ELSE HALT(100);
			END;

			IF virtual.offset # 0 THEN
				Assert(type.form # IntermediateCode.Float,"forbidden offset on float");
				IF ticket = NIL THEN
					tempReg := ForceFreeRegister(type);
					TicketToOperand(ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,type,tempReg,inPC),tmp);
				ELSE
					TicketToOperand(ticket, tmp);
					ticket := NIL;
				END;
				IF Assembler.IsRegisterOperand(physical) THEN
					Assembler.InitMem(physical,SHORTINT(type.length * type.sizeInBits DIV 8) , physical.register, virtual.offset);
					emitter.Emit2(InstructionSet.opLEA, tmp,physical);
				ELSE
					emitter.Emit2(InstructionSet.opMOV,tmp,physical);
					Assembler.InitImm(imm,0 ,virtual.offset);
					emitter.Emit2(InstructionSet.opADD,tmp,imm);
				END;
				physical := tmp;
			END;
		END GetRegister;


		(* make physical operand from virtual operand, if ticket given then write result into phyiscal register represented by ticket *)
		PROCEDURE MakeOperand(CONST vop: IntermediateCode.Operand; part: LONGINT; VAR op: Assembler.Operand; ticket: Ticket);
		VAR tmp: Assembler.Operand;
		BEGIN
			TryAllocate(vop,part);
			CASE vop.mode OF
				IntermediateCode.ModeMemory: GetMemory(vop,part,op);
				|IntermediateCode.ModeRegister:	GetRegister(vop,part,op,ticket);
				|IntermediateCode.ModeImmediate: GetImmediate(vop,part,op,FALSE);
			END;
			IF ticket # NIL THEN
				TicketToOperand(ticket, tmp);
				emitter.Emit2(InstructionSet.opMOV, tmp, op);
				(* should work but does not
					IF Assembler.IsRegisterOperand(op) THEN ReleaseHint(op.register) END;
				*)
				op := tmp;
			END;
		END MakeOperand;

		(* make physical register operand from virtual operand *)
		PROCEDURE MakeRegister(CONST vop: IntermediateCode.Operand; part: LONGINT; VAR op: Assembler.Operand);
		VAR previous: Assembler.Operand; temp: Ticket;
		BEGIN
			MakeOperand(vop,part,op,NIL);
			IF ~Assembler.IsRegisterOperand(op) THEN
				previous := op;
				temp := TemporaryTicket(vop.registerClass,vop.type);
				TicketToOperand(temp,op);
				IF vop.type.length > 1 THEN
					emitter.Emit2(InstructionSet.opMOVUPS, op, previous);
				ELSE
					Move(op, previous, vop.type);
				END;
			END;
		END MakeRegister;

		(*-------------------  helpers for code generation ----------------------*)

		(* move, potentially with conversion. parameter back used for moving back from temporary operand*)
		PROCEDURE SpecialMove(op, back: LONGINT; canStoreToMemory: BOOLEAN; VAR dest,src: Assembler.Operand; type: IntermediateCode.Type);
		VAR temp: Assembler.Operand; ticket: Ticket;
		BEGIN
			IF Assembler.SameOperand(src,dest) THEN (* do nothing *)
			ELSIF ~Assembler.IsMemoryOperand(dest) OR (~Assembler.IsMemoryOperand(src) & canStoreToMemory) THEN
				emitter.Emit2(op,dest,src);
			ELSE
				ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,type);
				TicketToOperand(ticket,temp);
				emitter.Emit2(op,temp,src);
				emitter.Emit2(back,dest,temp);
				UnmapTicket(ticket);
			END;
		END SpecialMove;

		PROCEDURE AllocateStack(sizeInBytes: LONGINT);
		VAR sizeOp: Assembler.Operand; opcode: LONGINT;
		BEGIN
			ASSERT(sizeInBytes MOD 4 (* (cpuBits DIV 8) *) = 0);
			IF sizeInBytes < 0 THEN
				sizeInBytes := -sizeInBytes; opcode := InstructionSet.opADD;
			ELSIF sizeInBytes > 0 THEN
				opcode := InstructionSet.opSUB;
			ELSE RETURN
			END;
			IF sizeInBytes < 128 THEN sizeOp := Assembler.NewImm8(sizeInBytes);
			ELSE sizeOp := Assembler.NewImm32(sizeInBytes);
			END;
			emitter.Emit2(opcode,opSP,sizeOp);
		END AllocateStack;

		(*-------------------  generation = emit dispatch  / emit procedures ----------------------*)
		PROCEDURE IsFloat(CONST operand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN operand.type.form = IntermediateCode.Float
		END IsFloat;

		PROCEDURE IsComplex(CONST operand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN (operand.type.form IN IntermediateCode.Integer) & (operand.type.sizeInBits > cpuBits)
		END IsComplex;

		PROCEDURE Generate(VAR instruction: IntermediateCode.Instruction);
		VAR opcode: SHORTINT; ticket: Ticket; hwreg, lastUse, i, part: LONGINT;
		BEGIN
			(*!IF ((instruction.opcode = IntermediateCode.mov) OR (instruction.opcode = IntermediateCode.pop)) & (instruction.op1.register <= IntermediateCode.ParameterRegister) THEN
				hwreg := ParameterRegister(IntermediateCode.ParameterRegister-instruction.op1.register, instruction.op1.type);
				Spill(physicalRegisters.Mapped(hwreg));
				lastUse := inPC+1;
				WHILE (lastUse < in.pc) &
					((in.instructions[lastUse].opcode # IntermediateCode.push) OR (in.instructions[lastUse].op1.register # instruction.op1.register)) & (in.instructions[lastUse].opcode # IntermediateCode.call) DO
					INC(lastUse)
				END;
				ticket := ReservePhysicalRegister(instruction.op1.type,hwreg,lastUse);
			END;
			*)
			ReserveOperandRegisters(instruction.op1,TRUE); ReserveOperandRegisters(instruction.op2,TRUE);ReserveOperandRegisters(instruction.op3,TRUE);
			(*TryAllocate(instruction.op1,Low);
			IF IsComplex(instruction.op1) THEN TryAllocate(instruction.op1,High) END;
			*)
			opcode := instruction.opcode;
			CASE opcode OF
			IntermediateCode.nop: (* do nothing *)
			|IntermediateCode.mov:
				IF IsFloat(instruction.op1) OR IsFloat(instruction.op2) THEN
					EmitMovFloat(instruction.op1,instruction.op2)
				ELSE EmitMov(instruction.op1,instruction.op2,Low);
					IF IsComplex(instruction.op1) THEN EmitMov(instruction.op1,instruction.op2, High) END;
				END;
			|IntermediateCode.conv:
				IF IsFloat(instruction.op1) OR IsFloat(instruction.op2) THEN
					EmitConvertFloat(instruction)
				ELSE
					EmitConvert(instruction.op1,instruction.op2,Low);
					IF IsComplex(instruction.op1) THEN EmitConvert(instruction.op1,instruction.op2,High) END;
				END;
			|IntermediateCode.call: EmitCall(instruction);
			|IntermediateCode.enter: EmitEnter(instruction);
			|IntermediateCode.leave: EmitLeave(instruction);
			|IntermediateCode.exit: EmitExit(instruction);
			|IntermediateCode.result:
				IF IsFloat(instruction.op1) & backend.forceFPU THEN
					EmitResultFPU(instruction)
				ELSE
					EmitResult(instruction,Low);
					IF IsComplex(instruction.op1) THEN EmitResult(instruction,High) END;
				END;
			|IntermediateCode.return:
				IF IsFloat(instruction.op1) & backend.forceFPU THEN
					EmitReturnFPU(instruction)
				ELSE
					EmitReturn(instruction,Low);
					IF IsComplex(instruction.op1) THEN EmitReturn(instruction, High) END;
				END;
			|IntermediateCode.trap: EmitTrap(instruction);
			|IntermediateCode.br .. IntermediateCode.brlt: EmitBr(instruction)
			|IntermediateCode.pop:
				IF IsFloat(instruction.op1) THEN
					EmitPopFloat(instruction.op1)
				ELSE
					EmitPop(instruction.op1,Low);
					IF IsComplex(instruction.op1) THEN
						EmitPop(instruction.op1,High)
					END;
				END;
			|IntermediateCode.push:
				IF IsFloat(instruction.op1) THEN
					EmitPushFloat(instruction.op1)
				ELSE
					IF IsComplex(instruction.op1) THEN
						EmitPush(instruction.op1,High);
					END;
					EmitPush(instruction.op1,Low)
				END;
			|IntermediateCode.neg:
				IF IsFloat(instruction.op1) THEN
					IF backend.forceFPU THEN
						EmitArithmetic2FPU(instruction,InstructionSet.opFCHS)
					ELSE
						EmitNegXMM(instruction)
					END;
				ELSE EmitNeg(instruction);
				END;
			|IntermediateCode.not:
				Assert(~IsFloat(instruction.op1),"instruction not supported for float");
				EmitArithmetic2(instruction,Low,InstructionSet.opNOT);
				IF IsComplex(instruction.op1) THEN EmitArithmetic2(instruction, High, InstructionSet.opNOT) END;
			|IntermediateCode.abs:
				IF IsFloat(instruction.op1) THEN
					IF backend.forceFPU THEN
						EmitArithmetic2FPU(instruction,InstructionSet.opFABS)
					ELSE
						EmitAbsXMM(instruction)
					END;
				ELSE EmitAbs(instruction);
				END;
			|IntermediateCode.mul:
				IF IsFloat(instruction.op1) THEN
					IF backend.forceFPU THEN
						EmitArithmetic3FPU(instruction,InstructionSet.opFMUL)
					ELSE
						EmitArithmetic3XMM(instruction, InstructionSet.opMULSS, InstructionSet.opMULSD)
					END;
				ELSE
					EmitMul(instruction);
				END;
			|IntermediateCode.div:
				IF  IsFloat(instruction.op1 )THEN
					IF backend.forceFPU THEN
						EmitArithmetic3FPU(instruction,InstructionSet.opFDIV)
					ELSE
						EmitArithmetic3XMM(instruction, InstructionSet.opDIVSS, InstructionSet.opDIVSD)
					END;
				ELSE
					EmitDivMod(instruction);
				END;
			|IntermediateCode.mod:
				Assert(~IsFloat(instruction.op1),"instruction not supported for float");
				EmitDivMod(instruction);
			|IntermediateCode.sub:
				IF IsFloat(instruction.op1) THEN
					IF backend.forceFPU THEN
						EmitArithmetic3FPU(instruction,InstructionSet.opFSUB)
					ELSE
						EmitArithmetic3XMM(instruction, InstructionSet.opSUBSS, InstructionSet.opSUBSD)
					END;
				ELSE EmitArithmetic3(instruction,Low,InstructionSet.opSUB);
					IF IsComplex(instruction.op1) THEN EmitArithmetic3(instruction, High, InstructionSet.opSBB) END;
				END;
			|IntermediateCode.add:
				IF IsFloat(instruction.op1) THEN
					IF backend.forceFPU THEN
						EmitArithmetic3FPU(instruction,InstructionSet.opFADD)
					ELSE
						EmitArithmetic3XMM(instruction, InstructionSet.opADDSS, InstructionSet.opADDSD)
					END;
				ELSE EmitArithmetic3(instruction,Low,InstructionSet.opADD);
					IF IsComplex(instruction.op1) THEN EmitArithmetic3(instruction, High, InstructionSet.opADC) END;
				END;
			|IntermediateCode.and:
				Assert(~IsFloat(instruction.op1),"operation not defined on float");
				EmitArithmetic3(instruction,Low,InstructionSet.opAND);
				IF IsComplex(instruction.op1) THEN EmitArithmetic3(instruction, High, InstructionSet.opAND) END;
			|IntermediateCode.or:
				Assert(~IsFloat(instruction.op1),"operation not defined on float");
				EmitArithmetic3(instruction,Low,InstructionSet.opOR);
				IF IsComplex(instruction.op1) THEN EmitArithmetic3(instruction, High, InstructionSet.opOR) END;
			|IntermediateCode.xor:
				Assert(~IsFloat(instruction.op1),"operation not defined on float");
				EmitArithmetic3(instruction,Low,InstructionSet.opXOR);
				IF IsComplex(instruction.op1) THEN EmitArithmetic3(instruction, High, InstructionSet.opXOR) END;
			|IntermediateCode.shl: EmitShift(instruction);
			|IntermediateCode.shr: EmitShift(instruction);
			|IntermediateCode.rol: EmitShift(instruction);
			|IntermediateCode.ror: EmitShift(instruction);
			|IntermediateCode.cas: EmitCas(instruction);
			|IntermediateCode.copy: EmitCopy(instruction);
			|IntermediateCode.fill: EmitFill(instruction,FALSE);
			|IntermediateCode.asm: EmitAsm(instruction);
			END;

			ReserveOperandRegisters(instruction.op3,FALSE); ReserveOperandRegisters(instruction.op2,FALSE); ReserveOperandRegisters(instruction.op1,FALSE);

		END Generate;

		PROCEDURE PostGenerate(CONST instruction: IntermediateCode.Instruction);
		VAR ticket: Ticket;
		BEGIN
			TryUnmap(instruction.op3); TryUnmap(instruction.op2); TryUnmap(instruction.op1);
			ticket := tickets.live;
			WHILE (ticket # NIL) & (ticket.lastuse = inPC) DO
				UnmapTicket(ticket);
				ticket := tickets.live
			END;
		END PostGenerate;

		(* enter procedure: generate PAF and clear stack *)
		PROCEDURE EmitEnter(CONST instruction: IntermediateCode.Instruction);
		VAR op1,imm,target: Assembler.Operand; cc,size,numberMachineWords,destPC,firstPC,secondPC,x: LONGINT; body: SyntaxTree.Body; name: Basic.SegmentedName;
		parametersSize: SIZE;
		CONST initialize=TRUE; FirstOffset = 5; SecondOffset = 11; 
		BEGIN
			stackSize := SHORT(instruction.op2.intValue);
			size := stackSize;

			INC(traceStackSize, stackSize);
			
			IF initialize THEN
				(* always including this instruction make trace insertion possible *)
				IF backend.traceable THEN
					emitter.Emit2(InstructionSet.opXOR,opRA,opRA);
				END;
				ASSERT(size MOD opRA.sizeInBytes = 0);
				numberMachineWords := size DIV opRA.sizeInBytes;
				IF numberMachineWords >0  THEN
					IF ~backend.traceable THEN
					emitter.Emit2(InstructionSet.opXOR,opRA,opRA);
					END;
					WHILE numberMachineWords MOD 4 # 0 DO
						emitter.Emit1(InstructionSet.opPUSH, opRA);
						DEC(numberMachineWords);
					END;
					IF numberMachineWords >4 THEN
						Assembler.InitImm(imm, 0, numberMachineWords DIV 4);
						emitter.Emit2(InstructionSet.opMOV, opRB, imm);
						destPC := out.pc;
						emitter.Emit1(InstructionSet.opDEC, opRB);
						emitter.Emit1(InstructionSet.opPUSH, opRA);
						emitter.Emit1(InstructionSet.opPUSH, opRA);
						emitter.Emit1(InstructionSet.opPUSH, opRA);
						emitter.Emit1(InstructionSet.opPUSH, opRA);

						Assembler.InitOffset8(target,destPC);
						emitter.Emit1(InstructionSet.opJNZ, target)
					ELSE
						WHILE numberMachineWords >0  DO
							emitter.Emit1(InstructionSet.opPUSH, opRA);
							DEC(numberMachineWords);
						END;
					END;
				END;
				IF spillStack.MaxSize()>0 THEN (* register spill stack, does not have to be initialized *)
					op1 := Assembler.NewImm32(spillStack.MaxSize()*cpuBits DIV 8);
					emitter.Emit2(InstructionSet.opSUB,opSP,op1);
				END;
			ELSE
				op1 := Assembler.NewImm32(size+ spillStack.MaxSize());
				emitter.Emit2(InstructionSet.opSUB,opSP,op1);
			END;

			IF (cc = SyntaxTree.WinAPICallingConvention) OR (cc = SyntaxTree.CCallingConvention) THEN
				(* the winapi calling convention presumes that all registers except EAX, EDX and ECX are retained by the callee *)
				emitter.Emit1(InstructionSet.opPUSH,opEBX);
				emitter.Emit1(InstructionSet.opPUSH,opEDI);
				emitter.Emit1(InstructionSet.opPUSH,opESI);
			END;
			spillStackStart := stackSize;
		END EmitEnter;

		PROCEDURE EmitLeave(CONST instruction: IntermediateCode.Instruction);
		VAR cc: LONGINT; offset: Assembler.Operand;
		BEGIN
			cc := SHORT(instruction.op1.intValue);
			IF (cc = SyntaxTree.WinAPICallingConvention)  OR (cc = SyntaxTree.CCallingConvention) THEN
				emitter.Emit1(InstructionSet.opPOP,opESI);
				emitter.Emit1(InstructionSet.opPOP,opEDI);
				emitter.Emit1(InstructionSet.opPOP,opEBX);
			END;
		END EmitLeave;

		PROCEDURE EmitExit(CONST instruction: IntermediateCode.Instruction);
		BEGIN
			emitter.Emit0(InstructionSet.opRET);
			IF fpStackPointer # 0 THEN Error(instruction.textPosition,"compiler implementation error: fp stack not cleared") END;
		END EmitExit;

		PROCEDURE EmitReturnFPU(CONST instruction: IntermediateCode.Instruction);
		VAR operand: Assembler.Operand;
		BEGIN
			IF IsRegister(instruction.op1) & MappedTo(instruction.op1.register,Low, ST0) THEN
				(* nothing to do: result is already in return register *)
			ELSE
				MakeOperand(instruction.op1, Low, operand,NIL);
				emitter.Emit1(InstructionSet.opFLD,operand);
				(*
				not necessary to clear from top of stack as callee will clear
				INC(fpStackPointer);
				emitter.Emit1(InstructionSet.opFSTP,registerOperands[ST0+1]);
				DEC(fpStackPointer);
				*)
			END;
		END EmitReturnFPU;

		(* return operand
			store operand in return register or on fp stack
		*)
		PROCEDURE EmitReturn(CONST instruction: IntermediateCode.Instruction; part: LONGINT);
		VAR return,operand: Assembler.Operand;  register: LONGINT; ticket: Ticket; type: IntermediateCode.Type;
		BEGIN
			register := ResultRegister(instruction.op1.type, part);
			IF IsRegister(instruction.op1) & MappedTo(instruction.op1.register,part, register) THEN
				(* nothing to do: result is already in return register *)
			ELSE
				GetPartType(instruction.op1.type,part, type);
				MakeOperand(instruction.op1, part, operand,NIL);
				Spill(physicalRegisters.Mapped(register));
				ticket := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,type,register,inPC);
				TicketToOperand(ticket, return);
				(* Mov takes care of potential register overlaps *)
				Move(return, operand, type);
				UnmapTicket(ticket);
			END;
		END EmitReturn;

		PROCEDURE EmitMovFloat(CONST vdest,vsrc:IntermediateCode.Operand);
		VAR dest,src, espm: Assembler.Operand; sizeInBytes: SHORTINT; vcopy: IntermediateCode.Operand;
		BEGIN
			sizeInBytes := SHORTINT(vdest.type.sizeInBits DIV 8);
			IF vdest.type.form IN IntermediateCode.Integer THEN
				(* e.g. in SYSTEM.VAL(LONGINT, r) *)
				IF vsrc.mode = IntermediateCode.ModeMemory THEN
					vcopy := vsrc; IntermediateCode.SetType(vcopy,vdest.type);
					EmitMov(vdest, vcopy,Low);
					IF IsComplex(vdest) THEN
						EmitMov(vdest,vcopy,High);
					END;
				ELSE
					IF backend.forceFPU THEN
						MakeOperand(vsrc,Low,src,NIL);
						emitter.Emit1(InstructionSet.opFLD,src);
						INC(fpStackPointer);
						IF vdest.mode = IntermediateCode.ModeMemory THEN
							MakeOperand(vdest,Low,dest,NIL);
							Assembler.SetSize(dest,sizeInBytes);
							emitter.Emit1(InstructionSet.opFSTP,dest);
							DEC(fpStackPointer);
						ELSE
							AllocateStack(sizeInBytes);
							Assembler.InitMem(espm, sizeInBytes,SP,0);
							emitter.Emit1(InstructionSet.opFSTP,espm);
							DEC(fpStackPointer);
							MakeOperand(vdest,Low,dest,NIL);
							EmitPop(vdest,Low);
							IF IsComplex(vdest) THEN
								EmitPop(vdest,High);
							END;
						END;
					ELSE
						MakeOperand(vsrc, Low, src, NIL);
						IF vdest.mode = IntermediateCode.ModeMemory THEN
							MakeOperand(vdest, Low, dest, NIL);
							Move(dest, src, vsrc.type);
						ELSE (* need temporary stack argument *)
							AllocateStack(sizeInBytes);
							Assembler.InitMem(espm, sizeInBytes,SP,0);
							Move(espm, src, vsrc.type);
							MakeOperand(vdest,Low,dest,NIL);
							EmitPop(vdest,Low);
							IF IsComplex(vdest) THEN
								EmitPop(vdest,High);
							END;
						END;
					END;
				END;
			ELSIF vsrc.type.form IN IntermediateCode.Integer THEN
				(* e.g. in SYSTEM.VAL(REAL, i) *)
				IF vdest.mode = IntermediateCode.ModeMemory THEN
					vcopy := vdest; IntermediateCode.SetType(vcopy,vsrc.type);
					EmitMov(vcopy, vsrc,Low);
					IF IsComplex(vsrc) THEN
						EmitMov(vcopy,vsrc,High);
					END;
				ELSE
					IF backend.forceFPU THEN
						IF vsrc.mode = IntermediateCode.ModeMemory THEN
							MakeOperand(vsrc,Low,src,NIL);
							Assembler.SetSize(src,sizeInBytes);
							emitter.Emit1(InstructionSet.opFLD,src);
						ELSE
							IF IsComplex(vsrc) THEN
								EmitPush(vsrc,High);
							END;
							EmitPush(vsrc,Low);
							Assembler.InitMem(espm, sizeInBytes,SP,0);
							emitter.Emit1(InstructionSet.opFLD,espm);
							ASSERT(sizeInBytes >0);
							AllocateStack(-sizeInBytes);
						END;
						INC(fpStackPointer);
						MakeOperand(vdest,Low,dest,NIL);
						emitter.Emit1(InstructionSet.opFSTP,dest);
						DEC(fpStackPointer);
					ELSE
						IF vsrc.mode = IntermediateCode.ModeMemory THEN
							MakeOperand(vsrc,Low,src,NIL);
							Assembler.SetSize(src,sizeInBytes);
							MakeOperand(vdest,Low,dest,NIL);
							Move(dest, src, vdest.type);
						ELSE
							IF IsComplex(vsrc) THEN
								EmitPush(vsrc,High);
							END;
							EmitPush(vsrc,Low);
							Assembler.InitMem(espm, sizeInBytes,SP,0);
							MakeOperand(vdest, Low, dest, NIL);
							Move(dest, espm, vdest.type);
							AllocateStack(-sizeInBytes);
						END;
					END;
				END;
			ELSE
				IF backend.forceFPU THEN
					MakeOperand(vsrc,Low,src,NIL);
					emitter.Emit1(InstructionSet.opFLD,src);
					INC(fpStackPointer);
					MakeOperand(vdest,Low,dest,NIL);
					emitter.Emit1(InstructionSet.opFSTP,dest);
					DEC(fpStackPointer);
				ELSE
					MakeOperand(vsrc, Low, src, NIL);
					MakeOperand(vdest, Low, dest, NIL);
					Move(dest, src, vdest.type)
				END;
			END;
		END EmitMovFloat;

		PROCEDURE EmitMov(CONST vdest,vsrc: IntermediateCode.Operand; part: LONGINT);
		VAR op1,op2: Assembler.Operand; tmp: IntermediateCode.Operand;
			t: CodeGenerators.Ticket;
			type: IntermediateCode.Type;
		BEGIN
			IF (vdest.mode = IntermediateCode.ModeRegister) & (vsrc.mode = IntermediateCode.ModeRegister) & (vsrc.offset # 0) THEN
				(* MOV R1, R2+offset => LEA EAX, [EBX+offset] *)
				tmp := vsrc;
				IntermediateCode.MakeMemory(tmp,vsrc.type);
				MakeOperand(tmp,part,op2,NIL);
				(*
				ReleaseHint(op2.register);
				*)
				MakeOperand(vdest,part,op1,NIL);

				t := virtualRegisters.Mapped(vdest.register,part);
				IF (t # NIL) & (t.spilled) THEN
					UnSpill(t); (* make sure this has not spilled *)
					MakeOperand(vdest,part, op1,NIL);
				END;

				emitter.Emit2(InstructionSet.opLEA,op1,op2);
			ELSE
				MakeOperand(vsrc,part,op2,NIL);
				MakeOperand(vdest,part,op1,NIL);
				GetPartType(vsrc.type, part, type);
				Move(op1,op2, type);
			END;
		END EmitMov;

		PROCEDURE EmitConvertFloat(CONST instruction: IntermediateCode.Instruction);
		VAR destType, srcType, dtype: IntermediateCode.Type; dest,src,espm,imm: Assembler.Operand; sizeInBytes, index: LONGINT;
		temp, temp2, temp3, temp4: Assembler.Operand; ticket: Ticket; vdest, vsrc: IntermediateCode.Operand;
		BEGIN
			vdest := instruction.op1; vsrc := instruction.op2;
			srcType := vsrc.type;
			destType := vdest.type;
			IF destType.form = IntermediateCode.Float THEN
				CASE srcType.form OF
				|IntermediateCode.Float: (* just a move *)
					IF backend.forceFPU THEN
						EmitMovFloat(vdest, vsrc);
					ELSE
						MakeOperand(vsrc,Low,src,NIL);
						MakeOperand(vdest, Low, dest, NIL);
						IF srcType.sizeInBits = 32 THEN
							SpecialMove(InstructionSet.opCVTSS2SD, InstructionSet.opMOVSS, FALSE, dest, src, destType)
						ELSE
							SpecialMove(InstructionSet.opCVTSD2SS, InstructionSet.opMOVSD, FALSE, dest, src, destType)
						END;
					END;
				|IntermediateCode.SignedInteger:
					(* put value to stack and then read from stack via Float *)
					IF vsrc.type.sizeInBits < IntermediateCode.Bits32 THEN
						MakeOperand(vsrc,Low,src,NIL);
						ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
						TicketToOperand(ticket,temp);
						emitter.Emit2(InstructionSet.opMOVSX,temp,src);
						IF backend.forceFPU THEN (* via stack *)
							emitter.Emit1(InstructionSet.opPUSH,temp);
							UnmapTicket(ticket);
							sizeInBytes := temp.sizeInBytes;
						ELSE (* via register *)
							espm := temp;
							sizeInBytes := 0
						END;
					ELSIF IsComplex(vsrc) THEN (* via stack *)
						EmitPush(vsrc,High);
						EmitPush(vsrc,Low);
						sizeInBytes := 8
					ELSE
						IF backend.forceFPU THEN (* via stack *)
							EmitPush(vsrc,Low);
							sizeInBytes := SHORTINT(4 (* cpuBits DIV 8*)) (*SHORT(srcType.sizeInBits DIV 8)*);
						ELSE (* via memory or register *)
							sizeInBytes := 0;
							MakeOperand(vsrc,Low,src,NIL);
							IF Assembler.IsImmediateOperand(src) THEN (* use temporary register *)
								ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
								TicketToOperand(ticket,temp);
								emitter.Emit2(InstructionSet.opMOVSX,temp,src);
								espm := temp
							ELSE
								espm := src
							END;
						END
					END;
					IF sizeInBytes > 0 THEN
						Assembler.InitMem(espm, SHORTINT(sizeInBytes),SP,0);
					END;
					IF backend.forceFPU THEN
						emitter.Emit1(InstructionSet.opFILD,espm);
						INC(fpStackPointer);
						ASSERT(sizeInBytes >0);
						Basic.Align(sizeInBytes, 4 (* cpuBits DIV 8*));
						AllocateStack(-sizeInBytes);
						MakeOperand(vdest,Low,dest,NIL);
						emitter.Emit1(InstructionSet.opFSTP,dest);
						DEC(fpStackPointer);
					ELSIF IsComplex(vsrc) THEN
						emitter.Emit1(InstructionSet.opFILD,espm);
						MakeOperand(vdest,Low,dest,NIL);
						IF Assembler.IsMemoryOperand(dest) THEN
							emitter.Emit1(InstructionSet.opFSTP,dest);
						ELSE (* must be register *)
							emitter.Emit1(InstructionSet.opFSTP,espm);
							emitter.Emit2(InstructionSet.opMOVQ,dest,espm);
							IF destType.sizeInBits = 32 THEN
								emitter.Emit2(InstructionSet.opCVTSD2SS, dest,dest);
							END;
						END;
						AllocateStack(-sizeInBytes);
					ELSE
						MakeOperand(vdest,Low,dest,NIL);
						IF destType.sizeInBits = 32 THEN
							emitter.Emit2(InstructionSet.opCVTSI2SS, dest, espm)
						ELSE
							emitter.Emit2(InstructionSet.opCVTSI2SD, dest, espm)
						END;
						AllocateStack(-sizeInBytes);
					END;
				END;
			ELSE
				ASSERT(destType.form IN IntermediateCode.Integer);
				ASSERT(srcType.form = IntermediateCode.Float);
				Assert(vdest.type.form = IntermediateCode.SignedInteger, "no entier as result for unsigned integer");
				MakeOperand(vsrc,Low,src,NIL);
				IF ~backend.forceFPU THEN
					MakeOperand(vdest,Low,dest,ticket);
					GetTemporaryRegister(srcType, temp);
					GetTemporaryRegister(srcType, temp3);
					IF destType.sizeInBits < 32 THEN
						IntermediateCode.InitType(dtype, destType.form, 32);
						GetTemporaryRegister(dtype, temp4);
					ELSE
						dtype := destType;
						temp4 := dest;
					END;
					GetTemporaryRegister(dtype, temp2);
					IF srcType.sizeInBits = 32 THEN
						(* convert truncated -> negative numbers round up !*)
						emitter.Emit2(InstructionSet.opCVTTSS2SI, temp4, src);
						(* back to temporary mmx register *)
						emitter.Emit2(InstructionSet.opCVTSI2SS, temp, temp4);
						(* subtract *)
						emitter.Emit2(InstructionSet.opMOVSS, temp3, src);
						emitter.Emit2(InstructionSet.opSUBSS, temp3, temp);
						(* back to a GP register in order to determine the sign bit *)
					ELSE
						emitter.Emit2(InstructionSet.opCVTTSD2SI, temp4, src);
						emitter.Emit2(InstructionSet.opCVTSI2SD, temp, temp4);
						emitter.Emit2(InstructionSet.opMOVSD, temp3, src);
						emitter.Emit2(InstructionSet.opSUBSD, temp3, temp);
						emitter.Emit2(InstructionSet.opCVTSD2SS, temp3, temp3);
					END;
					emitter.Emit2(InstructionSet.opMOVD, temp2, temp3);
					Assembler.InitImm(imm, 0 ,srcType.sizeInBits-1);
					emitter.Emit2(InstructionSet.opBT, temp2, imm);
					Assembler.InitImm(imm, 0 ,0);
					emitter.Emit2(InstructionSet.opSBB, temp4, imm);


					IF dtype.sizeInBits # destType.sizeInBits THEN
						index := temp4.register;
						CASE destType.sizeInBits OF (* choose low part accordingly *)
							IntermediateCode.Bits8: index := index MOD 32 + AL;
							|IntermediateCode.Bits16: index := index MOD 32 + AX;
							|IntermediateCode.Bits32: index := index MOD 32 + EAX;
						END;
						temp4 := registerOperands[index];
						emitter.Emit2(InstructionSet.opMOV, dest, temp4);
					END

				ELSE
					emitter.Emit1(InstructionSet.opFLD,src); INC(fpStackPointer);
					MakeOperand(vdest,Low,dest,NIL);
					IF destType.sizeInBits = IntermediateCode.Bits64 THEN AllocateStack(12) ELSE AllocateStack(8) END;

					Assembler.InitMem(espm,IntermediateCode.Bits16 DIV 8,SP,0);

					emitter.Emit1(InstructionSet.opFNSTCW,espm);
					emitter.Emit0(InstructionSet.opFWAIT);

					Assembler.InitMem(espm,IntermediateCode.Bits32 DIV 8,SP,0);
					ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
					TicketToOperand(ticket,temp);

					emitter.Emit2(InstructionSet.opMOV,temp,espm);
					imm := Assembler.NewImm32(0F3FFH);
					emitter.Emit2(InstructionSet.opAND,temp,imm);
					imm := Assembler.NewImm32(0400H);
					emitter.Emit2(InstructionSet.opOR,temp,imm);
					Assembler.InitMem(espm,IntermediateCode.Bits32 DIV 8,SP,4);
					emitter.Emit2(InstructionSet.opMOV,espm,temp);
					Assembler.InitMem(espm,IntermediateCode.Bits16 DIV 8,SP,4);
					emitter.Emit1(InstructionSet.opFLDCW,espm);
					IF destType.sizeInBits = IntermediateCode.Bits64 THEN
						Assembler.InitMem(espm,IntermediateCode.Bits64 DIV 8,SP,4);
						emitter.Emit1(InstructionSet.opFISTP,espm);DEC(fpStackPointer);
						emitter.Emit0(InstructionSet.opFWAIT);
					ELSE
						Assembler.InitMem(espm,IntermediateCode.Bits32 DIV 8,SP,4);
						emitter.Emit1(InstructionSet.opFISTP,espm); DEC(fpStackPointer);
						emitter.Emit0(InstructionSet.opFWAIT);
					END;
					Assembler.InitMem(espm,IntermediateCode.Bits16 DIV 8,SP,0);
					emitter.Emit1(InstructionSet.opFLDCW,espm);

					emitter.Emit1(InstructionSet.opPOP,temp);
					UnmapTicket(ticket);

					emitter.Emit1(InstructionSet.opPOP,dest);
					IF IsComplex(vdest) THEN
						MakeOperand(vdest,High,dest,NIL);
						emitter.Emit1(InstructionSet.opPOP,dest);
					END;
				END;
			END;
		END EmitConvertFloat;

		PROCEDURE EmitConvert(CONST vdest, vsrc: IntermediateCode.Operand; part: LONGINT);
		VAR destType, srcType: IntermediateCode.Type; op1,op2: Assembler.Operand; index: LONGINT; nul: Assembler.Operand;
			ticket: Ticket; vop: IntermediateCode.Operand; ediReserved, esiReserved: BOOLEAN;
			eax, edx: Ticket; symbol: ObjectFile.Identifier; offset: LONGINT;
		BEGIN
			GetPartType(vdest.type,part, destType);
			GetPartType(vsrc.type,part,srcType);
			ASSERT(vdest.type.form IN IntermediateCode.Integer);
			ASSERT(destType.form IN IntermediateCode.Integer);
			IF destType.sizeInBits < srcType.sizeInBits THEN (* SHORT *)
				ASSERT(part # High);
				MakeOperand(vdest,part,op1,NIL);
				IF vsrc.mode = IntermediateCode.ModeImmediate THEN
					vop := vsrc;
					IntermediateCode.SetType(vop,destType);
					MakeOperand(vop,part,op2,NIL);
				ELSE
					MakeOperand(vsrc,part,op2,NIL);
					IF Assembler.IsRegisterOperand(op1) & ((op1.register DIV 32 >0) (* not 8 bit register *) OR (op1.register DIV 16 = 0) & (physicalRegisters.Mapped(op1.register MOD 16 + AH)=free) (* low 8 bit register with free upper part *)) THEN
						(* try EAX <- EDI  for dest = AL or AX, src=EDI *)
						index := op1.register;
						CASE srcType.sizeInBits OF
							IntermediateCode.Bits16: index := index MOD 32 + AX;
							|IntermediateCode.Bits32: index := index MOD 32 + EAX;
							|IntermediateCode.Bits64: index := index MOD 32 + RAX;
						END;
						op1 := registerOperands[index];
					ELSE
						(* reserve register with a low part *)
						IF destType.sizeInBits=8 THEN (* make sure that allocated temporary register has a low part with 8 bits, i.e.  exclude ESI or EDI *)
							ediReserved := physicalRegisters.Reserved(EDI);
							esiReserved := physicalRegisters.Reserved(ESI);
							physicalRegisters.SetReserved(EDI,TRUE); physicalRegisters.SetReserved(ESI,TRUE);
							ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,srcType); (* register with low part *)
							physicalRegisters.SetReserved(EDI,ediReserved); physicalRegisters.SetReserved(ESI,esiReserved);
						ELSE
							ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,srcType); (* any register with low part *)
						END;
						MakeOperand(vsrc,part,op2,ticket); (* stores op2 in ticket register *)
						index := op2.register;
						CASE destType.sizeInBits OF (* choose low part accordingly *)
							IntermediateCode.Bits8: index := index MOD 32 + AL;
							|IntermediateCode.Bits16: index := index MOD 32 + AX;
							|IntermediateCode.Bits32: index := index MOD 32 + EAX;
						END;
						op2 := registerOperands[index];
					END;
					Move(op1,op2,PhysicalOperandType(op1));
				END;
			ELSIF destType.sizeInBits > srcType.sizeInBits THEN (* (implicit) LONG *)
				IF part = High THEN
					IF destType.form = IntermediateCode.SignedInteger THEN
						Spill(physicalRegisters.Mapped(EAX));
						eax := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EAX,inPC);
						Spill(physicalRegisters.Mapped(EDX));
						edx := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EDX,inPC);
						IF vsrc.type.sizeInBits < 32 THEN
							MakeOperand(vsrc,Low,op2,NIL);
							SpecialMove(InstructionSet.opMOVSX,InstructionSet.opMOV, FALSE, opEAX,op2,PhysicalOperandType(opEAX));
						ELSE
							MakeOperand(vsrc,Low,op2,eax);
						END;
						emitter.Emit0(InstructionSet.opCDQ);
						MakeOperand(vdest,High,op1,NIL);
						emitter.Emit2(InstructionSet.opMOV,op1,opEDX);
						UnmapTicket(eax); UnmapTicket(edx);
					ELSE
						MakeOperand(vdest,part,op1,NIL);
						IF (vdest.mode = IntermediateCode.ModeRegister) THEN
							emitter.Emit2(InstructionSet.opXOR,op1,op1)
						ELSE
							Assembler.InitImm(nul,0,0);
							emitter.Emit2(InstructionSet.opMOV,op1,nul);
						END;
					END;
				ELSE
					ASSERT(part=Low);
					MakeOperand(vdest,part,op1,NIL);
					MakeOperand(vsrc,part,op2,NIL);
					IF srcType.sizeInBits = destType.sizeInBits THEN
						Move(op1,op2,PhysicalOperandType(op1));
					ELSIF  srcType.form = IntermediateCode.SignedInteger THEN
						IF srcType.sizeInBits=32 THEN (* 64 bits only *)
							ASSERT(cpuBits=64);
							SpecialMove(InstructionSet.opMOVSXD,InstructionSet.opMOV, FALSE, op1,op2,PhysicalOperandType(op1));
						ELSE
							SpecialMove(InstructionSet.opMOVSX,InstructionSet.opMOV, FALSE, op1,op2,PhysicalOperandType(op1));
						END;
					ELSE
						ASSERT(srcType.form = IntermediateCode.UnsignedInteger);
						IF srcType.sizeInBits=32 THEN (* 64 bits only *)
							ASSERT(cpuBits=64);
							IF Assembler.IsRegisterOperand(op1) THEN
								Move( registerOperands[op1.register MOD 32 + EAX], op2,srcType);
							ELSE
								ASSERT(Assembler.IsMemoryOperand(op1));
								symbol := op1.symbol; offset := op1.offset;
								Assembler.InitMem(op1,Assembler.bits32,op1.register, op1.displacement);
								Assembler.SetSymbol(op1,symbol.name,symbol.fingerprint,offset,op1.displacement);
								Move( op1, op2, srcType);
								Assembler.InitMem(op1,Assembler.bits32,op1.register, op1.displacement+Assembler.bits32);
								Assembler.SetSymbol(op1,symbol.name, symbol.fingerprint,offset,op1.displacement);
								Assembler.InitImm(op2,0,0);
								Move( op1, op2,srcType);
							END;
						ELSE
							SpecialMove(InstructionSet.opMOVZX, InstructionSet.opMOV, FALSE, op1, op2,PhysicalOperandType(op1))
						END;
					END;
				END;
			ELSE (* destType.sizeInBits = srcType.sizeInBits) *)
				EmitMov(vdest,vsrc,part);
			END;
		END EmitConvert;

		PROCEDURE EmitResult(CONST instruction: IntermediateCode.Instruction; part: LONGINT);
		VAR result,op: Assembler.Operand; register, highRegister: LONGINT; highReserved: BOOLEAN; type: IntermediateCode.Type;
		BEGIN
			register := ResultRegister(instruction.op1.type,part);
			IF (part = Low) & IsComplex(instruction.op1) THEN
				(* protect upper result (EDX) register *)
				highRegister := ResultRegister(instruction.op1.type, High);
				highReserved := physicalRegisters.Reserved(highRegister);
				physicalRegisters.SetReserved(highRegister,TRUE);
			END;

			result := registerOperands[register];
			MakeOperand(instruction.op1,part,op,NIL);
			GetPartType(instruction.op1.type, part, type);
			Move(op,result,type);

			IF (part = Low) & IsComplex(instruction.op1) THEN
				physicalRegisters.SetReserved(highRegister, highReserved);
			END
		END EmitResult;

		PROCEDURE EmitResultFPU(CONST instruction: IntermediateCode.Instruction);
		VAR op: Assembler.Operand;
		BEGIN

			INC(fpStackPointer); (* callee has left the result on top of stack, don't have to allocate here *)
			MakeOperand(instruction.op1,Low,op,NIL);
			emitter.Emit1(InstructionSet.opFSTP,op);
			DEC(fpStackPointer);
			(*
			UnmapTicket(ticket);
			*)
		END EmitResultFPU;

		PROCEDURE EmitCall(CONST instruction: IntermediateCode.Instruction);
		VAR fixup: Sections.Section;  target, op, parSize: Assembler.Operand;
			code: SyntaxTree.Code; emitterFixup,newFixup: BinaryCode.Fixup; resolved: BinaryCode.Section; pc: LONGINT;
		BEGIN
			IF fpStackPointer # 0 THEN Error(instruction.textPosition,"compiler implementation error: fp stack not cleared before call") END;
			IF instruction.op1.mode = IntermediateCode.ModeImmediate THEN
				fixup := module.allSections.FindByName(instruction.op1.symbol.name);
				IF (fixup # NIL) & (fixup.type = Sections.InlineCodeSection) THEN
					pc := out.pc;
					(* resolved must be available at this point ! *)
					resolved := fixup(IntermediateCode.Section).resolved;
					IF resolved # NIL THEN
						emitter.code.CopyBits(resolved.os.bits,0,resolved.os.bits.GetSize());
						emitterFixup := resolved.fixupList.firstFixup;
						WHILE (emitterFixup # NIL) DO
							newFixup := BinaryCode.NewFixup(emitterFixup.mode,emitterFixup.offset+pc,emitterFixup.symbol,emitterFixup.symbolOffset,emitterFixup.displacement,emitterFixup.scale,emitterFixup.pattern);
							out.fixupList.AddFixup(newFixup);
							emitterFixup := emitterFixup.nextFixup;
						END;
					END;
				ELSE
					Assembler.InitOffset32(target,instruction.op1.intValue);
					Assembler.SetSymbol(target,instruction.op1.symbol.name,instruction.op1.symbol.fingerprint,instruction.op1.offset,0);
					emitter.Emit1(InstructionSet.opCALL,target);
					Assembler.InitOffset32(parSize,instruction.op2.intValue);
					IF parSize.val # 0 THEN emitter.Emit2(InstructionSet.opADD,opSP,parSize) END;
				END;
			ELSE
				MakeOperand(instruction.op1,Low,op,NIL);
				emitter.Emit1(InstructionSet.opCALL,op);
				Assembler.InitOffset32(parSize,instruction.op2.intValue);
				IF parSize.val # 0 THEN emitter.Emit2(InstructionSet.opADD,opSP,parSize) END;
			END;
		END EmitCall;

(*
		register allocation

		instruction dest, src1, src2

		preconditions
			dest is memory operand or dest is register with offset = 0
			src1 and src2 may be immediates, registers with or without offset and memory operands

		1.) translation into two-operand code

			a) dest = src1 (no assumption on src2, src2=src1 is permitted )
				i) dest and src2 are both memory operands or src2 is a register with offset # 0
					alloc temp register
					mov temp, src2
					instruction2 dest, temp
				ii) dest or src2 is not a memory operand
					instruction2 dest, src2
			b) dest = src2
				=>	src2 is not a register with offset # 0
				alloc temp register
				mov dest, src1
				mov temp, src2
				instruction2 dest, temp
			c) dest # src2
				mov dest, src1
				i) dest and src2 are both memory operands or src2 is a register with offset # 0
					allocate temp register
					mov temp, src2
					instruction2 dest, temp
				ii)
					instruction2 dest, src2

		1'.) translation into one operand code
			instruction dest, src1

			a) dest = src1
				=> src1 is not a register with offset # 0
				instruction1 dest
			b) dest # src1
				mov dest, src1
				instruction1 dest

		2.) register allocation
			precondition: src1 and src2 are already allocated

			a) dest is already allocated
				go on according to 1.

			b) dest needs to be allocated
				check if register is free
				i) yes: allocate free register and go on with 1.
				ii) no: spill last register in livelist, map register and go on with 1.
*)

		PROCEDURE PrepareOp3(CONST instruction: IntermediateCode.Instruction;part: LONGINT; VAR left, right: Assembler.Operand; VAR ticket: Ticket);
		VAR vop1,vop2, vop3: IntermediateCode.Operand; op1,op2,op3,temp: Assembler.Operand; type: IntermediateCode.Type;
			t: Ticket;
		BEGIN
			ticket := NIL;
			GetPartType(instruction.op1.type,part,type);
			vop1 := instruction.op1; vop2 := instruction.op2; vop3 := instruction.op3;
			IF IntermediateCode.OperandEquals(vop1,vop3) & (IntermediateCode.Commute23 IN IntermediateCode.instructionFormat[instruction.opcode].flags) THEN
				vop3 := instruction.op2; vop2 := instruction.op3;
			END;
			MakeOperand(vop3,part, op3,NIL);
			IF (vop1.mode = IntermediateCode.ModeRegister) & (~IsMemoryOperand(vop1,part)) & (vop1.register # vop3.register)  THEN
				IF (vop2.mode = IntermediateCode.ModeRegister) & (vop2.register = vop1.register) & (vop2.offset = 0) THEN
					(* same register *)
					MakeOperand(vop1,part, op1,NIL);
				ELSE

					MakeOperand(vop2,part, op2,NIL);
					(*
					ReleaseHint(op2.register);
					*)

					MakeOperand(vop1,part, op1,NIL);
					Move(op1, op2, type);

					t := virtualRegisters.Mapped(vop1.register,part);
					IF (t # NIL) & (t.spilled) THEN
						UnSpill(t); (* make sure this has not spilled *)
						MakeOperand(vop1,part, op1,NIL);
					END;
				END;
				left := op1; right := op3;
			ELSIF IntermediateCode.OperandEquals(vop1,vop2) & (~IsMemoryOperand(vop1,part) OR ~IsMemoryOperand(vop3,part)) THEN
				MakeOperand(vop1,part, op1,NIL);
				left := op1; right := op3;
			ELSE
				MakeOperand(vop1,part, op1,NIL);
				MakeOperand(vop2,part, op2,NIL);
				(*ReleaseHint(op2.register);*)
				ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,type);
				TicketToOperand(ticket,temp);
				Move(temp, op2, type);
				left := temp; right := op3;
			END;
		END PrepareOp3;

		PROCEDURE PrepareOp2(CONST instruction: IntermediateCode.Instruction; part: LONGINT; VAR left: Assembler.Operand;VAR ticket: Ticket);
		VAR op2: Assembler.Operand; imm: Assembler.Operand; sizeInBits: INTEGER; type: IntermediateCode.Type;
		BEGIN
			ticket := NIL;
			GetPartType(instruction.op1.type,part,type);

			IF (instruction.op1.mode = IntermediateCode.ModeRegister) THEN
				MakeOperand(instruction.op1,part,left,NIL);
				MakeOperand(instruction.op2,part,op2,NIL);
				IF (instruction.op2.mode = IntermediateCode.ModeRegister) & (instruction.op2.register = instruction.op1.register) & (instruction.op2.offset = 0) THEN
				ELSE
					Move(left, op2, type);
					IF (instruction.op2.offset # 0) & ~IsMemoryOperand(instruction.op2,part) THEN
						GetPartType(instruction.op2.type,part,type);
						sizeInBits := type.sizeInBits;
						Assembler.InitImm(imm,0,instruction.op2.offset);
						emitter.Emit2(InstructionSet.opADD,left,imm);
					END;
				END;
			ELSIF IntermediateCode.OperandEquals(instruction.op1,instruction.op2) & ((instruction.op1.mode # IntermediateCode.ModeMemory) OR (instruction.op3.mode # IntermediateCode.ModeMemory)) THEN
				MakeOperand(instruction.op1,part,left,NIL);
			ELSE
				MakeOperand(instruction.op2,part, op2,NIL);
				ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,type);
				TicketToOperand(ticket,left);
				Move(left, op2, type);
			END;
		END PrepareOp2;

		PROCEDURE FinishOp(CONST vop: IntermediateCode.Operand; part: LONGINT; left: Assembler.Operand; ticket: Ticket);
		VAR op1: Assembler.Operand;
		BEGIN
			IF ticket # NIL THEN
				MakeOperand(vop,part, op1,NIL);
				Move(op1,left,vop.type);
				UnmapTicket(ticket);
			END;
		END FinishOp;

		PROCEDURE EmitArithmetic3(CONST instruction: IntermediateCode.Instruction; part: LONGINT; opcode: LONGINT);
		VAR left,right: Assembler.Operand; ticket: Ticket;
		BEGIN
			PrepareOp3(instruction, part, left,right,ticket);
			emitter.Emit2(opcode,left,right);
			FinishOp(instruction.op1,part,left,ticket);
		END EmitArithmetic3;

		PROCEDURE EmitArithmetic3XMM(CONST instruction: IntermediateCode.Instruction; op32, op64: LONGINT);
		VAR op: LONGINT;
		BEGIN
			IF instruction.op1.type.sizeInBits = 32 THEN op := op32 ELSE op := op64 END;
			EmitArithmetic3(instruction, Low, op);
		END EmitArithmetic3XMM;

		PROCEDURE EmitArithmetic2(CONST instruction: IntermediateCode.Instruction; part: LONGINT; opcode: LONGINT);
		VAR left:Assembler.Operand;ticket: Ticket;
		BEGIN
			PrepareOp2(instruction,part,left,ticket);
			emitter.Emit1(opcode,left);
			FinishOp(instruction.op1,part,left,ticket);
		END EmitArithmetic2;

		PROCEDURE EmitArithmetic2XMM(CONST instruction: IntermediateCode.Instruction; op32, op64: LONGINT);
		VAR op: LONGINT;
		BEGIN
			IF instruction.op1.type.sizeInBits = 32 THEN op := op32 ELSE op := op64 END;
			EmitArithmetic2(instruction, Low, op);
		END EmitArithmetic2XMM;

		PROCEDURE EmitArithmetic3FPU(CONST instruction: IntermediateCode.Instruction; op: LONGINT);
		VAR op1,op2,op3: Assembler.Operand;
		BEGIN
			MakeOperand(instruction.op2,Low,op2,NIL);
			emitter.Emit1(InstructionSet.opFLD,op2);
			INC(fpStackPointer);

			MakeOperand(instruction.op3,Low,op3,NIL);
			IF instruction.op3.mode = IntermediateCode.ModeRegister THEN
				emitter.Emit2(op,opST0,op3);
			ELSE
				emitter.Emit1(op,op3);
			END;
			MakeOperand(instruction.op1,Low,op1,NIL);
			emitter.Emit1(InstructionSet.opFSTP,op1);
			DEC(fpStackPointer);
		END EmitArithmetic3FPU;

		PROCEDURE EmitArithmetic2FPU(CONST instruction: IntermediateCode.Instruction; opcode: LONGINT);
		VAR op1,op2: Assembler.Operand;
		BEGIN
			MakeOperand(instruction.op2,Low,op2,NIL);
			emitter.Emit1(InstructionSet.opFLD,op2);
			INC(fpStackPointer);
			emitter.Emit0(opcode);
			MakeOperand(instruction.op1,Low,op1,NIL);
			emitter.Emit1(InstructionSet.opFSTP,op1);
			DEC(fpStackPointer);
		END EmitArithmetic2FPU;

		PROCEDURE EmitMul(CONST instruction: IntermediateCode.Instruction);
		VAR op1,op2,op3,temp: Assembler.Operand; ra,rd: Ticket;
		BEGIN
			ASSERT(~IsComplex(instruction.op1));
			ASSERT(instruction.op1.type.form IN IntermediateCode.Integer);
			IF (instruction.op1.type.sizeInBits = IntermediateCode.Bits8) THEN
				Spill(physicalRegisters.Mapped(AL));
				Spill(physicalRegisters.Mapped(AH));
				ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int8,AL,inPC);
				rd := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int8,AH,inPC);
				MakeOperand(instruction.op1,Low,op1,NIL);
				MakeOperand(instruction.op2,Low,op2,ra);
				IF instruction.op3.mode = IntermediateCode.ModeImmediate THEN
					MakeOperand(instruction.op3,Low,op3,rd);
				ELSE
					MakeOperand(instruction.op3,Low,op3,NIL);
				END;
				emitter.Emit1(InstructionSet.opIMUL,op3);
				emitter.Emit2(InstructionSet.opMOV,op1,opAL);
				UnmapTicket(ra);
				UnmapTicket(rd);
			ELSE
				MakeOperand(instruction.op1,Low,op1,NIL);
				MakeOperand(instruction.op2,Low,op2,NIL);
				MakeOperand(instruction.op3,Low,op3,NIL);

				IF ~Assembler.IsRegisterOperand(op1) THEN
					temp := op1;
					ra := TemporaryTicket(instruction.op1.registerClass,instruction.op1.type);
					TicketToOperand(ra,op1);
				END;

				IF Assembler.SameOperand(op1,op3) THEN temp := op2; op2 := op3; op3 := temp END;

				IF Assembler.IsRegisterOperand(op2) OR Assembler.IsMemoryOperand(op2) THEN
					IF Assembler.IsImmediateOperand(op3) THEN
						emitter.Emit3(InstructionSet.opIMUL,op1,op2,op3);
					ELSIF Assembler.IsRegisterOperand(op2) & (op2.register = op1.register) THEN
						IF Assembler.IsRegisterOperand(op3) OR Assembler.IsMemoryOperand(op3) THEN
							emitter.Emit2(InstructionSet.opIMUL,op1,op3);
						ELSE
							rd := TemporaryTicket(instruction.op1.registerClass,instruction.op1.type);
							TicketToOperand(rd,temp);
							Move(temp,op3,instruction.op1.type);
							emitter.Emit2(InstructionSet.opIMUL,op1,temp);
							UnmapTicket(rd);
						END;
					ELSE
						Move(op1,op3,PhysicalOperandType(op1));
						emitter.Emit2(InstructionSet.opIMUL,op1,op2);
					END
				ELSIF Assembler.IsRegisterOperand(op3) OR Assembler.IsMemoryOperand(op3) THEN
					IF Assembler.IsImmediateOperand(op2) THEN
						emitter.Emit3(InstructionSet.opIMUL,op1,op3,op2);
					ELSIF Assembler.IsRegisterOperand(op3) & (op2.register = op1.register) THEN
						IF Assembler.IsRegisterOperand(op2) OR Assembler.IsMemoryOperand(op2) THEN
							emitter.Emit2(InstructionSet.opIMUL,op1,op2);
						ELSE
							rd := TemporaryTicket(instruction.op1.registerClass,instruction.op1.type);
							TicketToOperand(rd,temp);
							Move(temp,op2,instruction.op1.type);
							emitter.Emit2(InstructionSet.opIMUL,op1,temp);
							UnmapTicket(rd);
						END;
					ELSE
						Move(op1,op2,PhysicalOperandType(op1));
						emitter.Emit2(InstructionSet.opIMUL,op1,op3);
					END;
				END;

				IF ra # NIL THEN
					Move(temp,op1,PhysicalOperandType(op1));
					UnmapTicket(ra);
				END;
			END;
		END EmitMul;

		PROCEDURE EmitDivMod(CONST instruction: IntermediateCode.Instruction);
		VAR
			dividend,quotient,remainder,imm,target,memop: Assembler.Operand;
			op1,op2,op3: Assembler.Operand; ra,rd: Ticket;
			size: LONGINT;
		BEGIN
			(*
			In general it must obviously hold that
				a = (a div b) * b + a mod b and
			for all integers a,b#0, and c.

			For positive numbers a and b this holds if
				a div b = max{integer i: i*b <= b} = Entier(a/b)
			and
				a mod b = a-(a div b)*b = min{c >=0: c = a-i*b, integer i}

			Example
				11 div 3 = 3 (3*3 = 9)
				11 mod 3 = 2 (=11-9)

			for negative a there are two definitions for mod possible:
				(i) 	mathematical definition with
					a mod b >= 0:
					a mod b = min{ c >=0: c = a-i*b, integer i} >= 0
					this corresponds with rounding down
					a div b = Entier(a/b) <= a/b
		 		(ii) symmetric definition with
		 			(-a) mod' b = -(a mod' b) and
		 			(-a) div' b = -(a div' b)
		 			corresponding with rounding to zero
		 			a div' b = RoundToZero(a/b)

		 	Examples
		 		(i) -11 div 3 = -4  (3*(-4) = -12)
		 			-11 mod 3 = 1 (=-11-(-12))
		 		(ii) -11 div' 3 = -(11 div 3) = -3 (3*(-3)= -9)
		 			-11 mod' 3 = -2 (=-11-(-9))

		 	The behaviour for negative b can, in the symmetrical case, be deduced as
				(ii)	symmetric definition
					a div' (-b) = (-a) div' b = -(a div' b)
					a mod' (-b) = a- a div' (-b) * (-b) = a mod' b

			In the mathematical case it is not so easy. It turns out that the definitions
				a DIV b = Entier(a/b) = max{integer i:  i*b <= b}
			and
				a MOD b = min { c >=0 : c = a-i*b, integer i} >= 0
			are not compliant with
				a = (a DIV b) * b + a MOD b
			if b <= 0.

			Proof: assume that b<0, then
				a - Entier(a/b) * b >= 0
				<=_> a >= Entier(a/b) * b
				<=> Entier(a/b) >= a/b (contradiction to definition of Entier).

			OBERON ADOPTS THE MATHEMATICAL DEFINITION !

			For integers a and b (b>0) it holds that

				a DIV b = Entier(a/b) <= a/b
				a MOD b = min{ c >=0: c = b-i*a, integer i} = a - a DIV b * b

			The behaviour for b < 0 is explicitely undefined.

			*)



			(*
				AX / regMem8 = AL (remainder AH)
				DX:AX / regmem16 = AX (remainder DX)
				EDX:EAX / regmem32 = EAX (remainder EDX)
				RDX:EAX / regmem64 = RAX (remainder RDX)

				1.) EAX <- source1
				2.) CDQ
				3.) IDIV source2
				3.) SHL EDX
				4.) SBB EAX,1
				result is in EAX
			*)

			MakeOperand(instruction.op2,Low,op2,NIL);
			CASE instruction.op1.type.sizeInBits OF
			IntermediateCode.Bits8:
				Spill(physicalRegisters.Mapped(AL)); ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int8,AL,inPC);
				emitter.Emit2(InstructionSet.opMOV,opAL,op2);
				dividend := opAX;
				quotient := opAL;
				remainder := opAH;
				emitter.Emit0(InstructionSet.opCBW);
			| IntermediateCode.Bits16:
				Spill(physicalRegisters.Mapped(AX)); ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int16,AX,inPC);
				emitter.Emit2(InstructionSet.opMOV,opAX,op2);
				Spill(physicalRegisters.Mapped(DX)); rd := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int16,DX,inPC);
				dividend := opAX;
				quotient := dividend;
				remainder := opDX;
				emitter.Emit0(InstructionSet.opCWD);
			| IntermediateCode.Bits32:
				Spill(physicalRegisters.Mapped(EAX)); ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EAX,inPC);
				emitter.Emit2(InstructionSet.opMOV,opEAX,op2);
				Spill(physicalRegisters.Mapped(EDX)); rd := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EDX,inPC);
				dividend := opEAX;
				quotient := dividend;
				remainder := opEDX;
				emitter.Emit0(InstructionSet.opCDQ);
			| IntermediateCode.Bits64:
				Spill(physicalRegisters.Mapped(RAX)); ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int64,RAX,inPC);
				emitter.Emit2(InstructionSet.opMOV,opRA,op2);
				Spill(physicalRegisters.Mapped(RDX)); rd := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int64,RDX,inPC);
				dividend := opRA;
				quotient := dividend;
				remainder := registerOperands[RDX];
				emitter.Emit0(InstructionSet.opCQO);
			END;
			(* registers might have been changed, so we make the operands now *)
			MakeOperand(instruction.op1,Low,op1,NIL);
			MakeOperand(instruction.op2,Low,op2,NIL);
			MakeOperand(instruction.op3,Low,op3,NIL);
			IF instruction.op3.mode = IntermediateCode.ModeImmediate THEN
				size := instruction.op3.type.sizeInBits DIV 8;
				Basic.Align(size, 4 (* cpuBits DIV 8 *) );
				AllocateStack(size);
				Assembler.InitMem(memop,SHORT(instruction.op3.type.sizeInBits DIV 8),SP,0);
				emitter.Emit2(InstructionSet.opMOV,memop,op3);
				op3 := memop;
			END;
			emitter.Emit1(InstructionSet.opIDIV,op3);

			IF instruction.opcode = IntermediateCode.mod THEN
				imm := Assembler.NewImm8 (0);
				emitter.Emit2(InstructionSet.opCMP, remainder, imm);
				Assembler.InitImm8(target,0);
				emitter.Emit1(InstructionSet.opJGE, target);
				emitter.Emit2( InstructionSet.opADD, remainder, op3);
				emitter.code.PutByteAt(target.pc,(emitter.code.pc -target.pc )-1);
				emitter.Emit2(InstructionSet.opMOV, op1, remainder);
			ELSE
				imm := Assembler.NewImm8 (1);
				emitter.Emit2(InstructionSet.opSHL, remainder, imm);
				imm := Assembler.NewImm8 (0);
				emitter.Emit2(InstructionSet.opSBB, quotient, imm);
				emitter.Emit2(InstructionSet.opMOV, op1, quotient);
			END;

			IF instruction.op3.mode = IntermediateCode.ModeImmediate THEN
				size := instruction.op3.type.sizeInBits DIV 8;
				Basic.Align(size, 4 (* cpuBits DIV 8*) );
				AllocateStack(-size);
			END;
		END EmitDivMod;

		PROCEDURE EmitShift(CONST instruction: IntermediateCode.Instruction);
		VAR
			shift: Assembler.Operand;
			op: LONGINT;
			op1,op2,op3,dest,temporary,op1High,op2High: Assembler.Operand;

			index: SHORTINT; temp: Assembler.Operand;

			left: BOOLEAN;
			ecx,ticket: Ticket;
		BEGIN
			Assert(instruction.op1.type.form IN IntermediateCode.Integer,"must be integer operand");
			IF instruction.op1.type.form = IntermediateCode.UnsignedInteger THEN
				IF instruction.opcode = IntermediateCode.shr THEN op :=  InstructionSet.opSHR; left := FALSE;
				ELSIF instruction.opcode = IntermediateCode.shl THEN  op :=  InstructionSet.opSHL; left := TRUE;
				ELSIF instruction.opcode = IntermediateCode.ror THEN  op := InstructionSet.opROR; left := FALSE;
				ELSIF instruction.opcode = IntermediateCode.rol THEN op := InstructionSet.opROL; left := TRUE;
				END;
			ELSE
				IF instruction.opcode = IntermediateCode.shr THEN op :=  InstructionSet.opSAR; left := FALSE;
				ELSIF instruction.opcode = IntermediateCode.shl THEN op :=  InstructionSet.opSAL; left := TRUE;
				ELSIF instruction.opcode = IntermediateCode.ror THEN op := InstructionSet.opROR; left := FALSE;
				ELSIF instruction.opcode = IntermediateCode.rol THEN op := InstructionSet.opROL; left := TRUE;
				END;
			END;

			IF instruction.op3.mode # IntermediateCode.ModeImmediate THEN
				IF backend.cooperative THEN ap.spillable := TRUE END;
				Spill(physicalRegisters.Mapped(ECX)); 
				ecx := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,ECX,inPC);
			END;

			(*GetTemporaryRegister(instruction.op2.type,dest);*)
			MakeOperand(instruction.op1,Low,op1,NIL);
			IF ~Assembler.IsRegisterOperand(op1) THEN GetTemporaryRegister(instruction.op2.type,dest) ELSE dest := op1 END;
			MakeOperand(instruction.op2,Low,op2,NIL);
			MakeOperand(instruction.op3,Low,op3,NIL);
			IF instruction.op3.mode = IntermediateCode.ModeImmediate THEN
				Assembler.InitImm8(shift,instruction.op3.intValue);
			ELSE
				CASE instruction.op3.type.sizeInBits OF
					IntermediateCode.Bits8: index := CL;
					|IntermediateCode.Bits16: index := CX;
					|IntermediateCode.Bits32: index := ECX;
					|IntermediateCode.Bits64: index := RCX;
				END;

				(*
				IF (physicalRegisters.toVirtual[index] # free) & ((physicalRegisters.toVirtual[index] # instruction.op1.register) OR (instruction.op1.mode # IntermediateCode.ModeRegister)) THEN
					Spill();
					(*
					emitter.Emit1(InstructionSet.opPUSH,opECX);
					ecxPushed := TRUE;
					*)
				END;
				*)
				ticket := virtualRegisters.Mapped(instruction.op3.register,Low);
				IF (instruction.op3.mode # IntermediateCode.ModeRegister) OR (ticket = NIL) OR (ticket.spilled) OR (ticket.register # index) THEN
					emitter.Emit2(InstructionSet.opMOV,registerOperands[index],op3);
				END;
				shift := opCL;
			END;


			IF ~IsComplex(instruction.op1) THEN
				Move(dest,op2,PhysicalOperandType(dest));
				emitter.Emit2 (op, dest,shift);
				Move(op1,dest,PhysicalOperandType(op1));
			ELSIF left THEN
				MakeOperand(instruction.op1,High,op1High,NIL);
				MakeOperand(instruction.op2,High,op2High,NIL);

				IF ~IntermediateCode.OperandEquals(instruction.op1,instruction.op2) THEN
					Move(op1,op2,PhysicalOperandType(op1));
					Move(op1High,op2High,PhysicalOperandType(op1High))
				END;

				IF (instruction.opcode=IntermediateCode.rol) THEN
					(*  |high| <- |low| <- |temp=high| *)
					ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
					TicketToOperand(ticket,temp);

					emitter.Emit2( InstructionSet.opMOV, temp, op1High);
					emitter.Emit3( InstructionSet.opSHLD,op1High, op1, shift);
					emitter.Emit3( InstructionSet.opSHLD, op1, temp, shift);
					UnmapTicket(ticket);
				ELSE
					(* |high| <- |low| *)
					emitter.Emit3( InstructionSet.opSHLD, op1,op1High,shift);
					emitter.Emit2( op, op1,shift);
				END;
			ELSE
				IF ~IntermediateCode.OperandEquals(instruction.op1,instruction.op2) THEN
					Move(op1,op2,PhysicalOperandType(op1))
				END;

				IF instruction.opcode=IntermediateCode.ror THEN
					(*  |temp=low| -> |high| -> |low| *)
					ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
					TicketToOperand(ticket,temp);
					emitter.Emit2( InstructionSet.opMOV, temporary, op1);
					emitter.Emit3( InstructionSet.opSHRD,op1, op1High, shift);
					emitter.Emit3( InstructionSet.opSHRD, op1High, temporary, shift);
					UnmapTicket(ticket);
				ELSE
					(*  |high| -> |low| *)
					emitter.Emit3( InstructionSet.opSHRD, op1,op1High,shift);
					emitter.Emit2( op, op1High, shift);
				END;
			END;
			IF backend.cooperative & (instruction.op3.mode # IntermediateCode.ModeImmediate) THEN
				UnmapTicket(ecx);
				UnSpill(ap);
				ap.spillable := FALSE;
			END;
		END EmitShift;

		PROCEDURE EmitCas(CONST instruction: IntermediateCode.Instruction);
		VAR ra: Ticket; op1,op2,op3,mem: Assembler.Operand; register: LONGINT;
		BEGIN
			CASE instruction.op2.type.sizeInBits OF
			| IntermediateCode.Bits8: register := AL;
			| IntermediateCode.Bits16: register := AX;
			| IntermediateCode.Bits32: register := EAX;
			| IntermediateCode.Bits64: register := RAX;
			END;
			Spill(physicalRegisters.Mapped(register));
			ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,instruction.op2.type,register,inPC);
			IF IntermediateCode.OperandEquals (instruction.op2,instruction.op3) THEN
				MakeOperand(instruction.op1,Low,op1,ra);
				Assembler.InitMem(mem,SHORT(instruction.op1.type.sizeInBits DIV 8),op1.register,0);
				emitter.Emit2(InstructionSet.opMOV,op1,mem);
			ELSE
				MakeOperand(instruction.op2,Low,op2,ra);
				MakeRegister(instruction.op1,Low,op1);
				Assembler.InitMem(mem,SHORT(instruction.op2.type.sizeInBits DIV 8),op1.register,0);
				MakeRegister(instruction.op3,Low,op3);
				emitter.EmitPrefix (InstructionSet.prfLOCK);
				emitter.Emit2(InstructionSet.opCMPXCHG,mem,op3);
			END;
		END EmitCas;

		PROCEDURE EmitCopy(CONST instruction: IntermediateCode.Instruction);
		VAR op1,op2,op3: Assembler.Operand; esi, edi, ecx, t: Ticket; temp,imm: Assembler.Operand; source, dest: IntermediateCode.Operand; size: HUGEINT;
		BEGIN
			IF IntermediateCode.IsConstantInteger(instruction.op3, size) & (size = 4) THEN
				Spill(physicalRegisters.Mapped(ESI));
				Spill(physicalRegisters.Mapped(EDI));
				esi := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,RS,inPC);
				edi := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,RD,inPC);
				MakeOperand(instruction.op1,Low,op1,edi);
				MakeOperand(instruction.op2,Low,op2,esi);
				emitter.Emit0(InstructionSet.opMOVSD);
				UnmapTicket(esi);
				UnmapTicket(edi);
			ELSE
				Spill(physicalRegisters.Mapped(ESI));
				Spill(physicalRegisters.Mapped(EDI));
				IF backend.cooperative THEN ap.spillable := TRUE END;
				Spill(physicalRegisters.Mapped(ECX)); 

				esi := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,RS,inPC);
				edi := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,RD,inPC);
				ecx := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,RC,inPC);

				MakeOperand(instruction.op1,Low,op1,edi);
				MakeOperand(instruction.op2,Low,op2,esi);

				IF (instruction.op1.mode = IntermediateCode.ModeRegister) & (instruction.op1.register = IntermediateCode.SP) &  IntermediateCode.IsConstantInteger(instruction.op3, size) & (size >= 4096)  THEN
					(* special case on stack: copy downwards for possible stack allocation *)
					IF size MOD 4 # 0 THEN
						imm := Assembler.NewImm32(size-1);
						emitter.Emit2(InstructionSet.opADD, opEDI, imm);
						emitter.Emit2(InstructionSet.opADD, opESI, imm);
						imm := Assembler.NewImm32(size MOD 4);
						emitter.Emit2(InstructionSet.opMOV, opECX, imm);
						emitter.Emit0(InstructionSet.opSTD); (* copy down *)
						emitter.EmitPrefix (InstructionSet.prfREP);
						emitter.Emit0(InstructionSet.opMOVSB);
						imm := Assembler.NewImm32(size DIV 4);
						emitter.Emit2(InstructionSet.opMOV, opECX, imm);
						emitter.EmitPrefix (InstructionSet.prfREP);
						emitter.Emit0(InstructionSet.opMOVSD);
					ELSE
						imm := Assembler.NewImm32(size-4);
						emitter.Emit2(InstructionSet.opADD, opEDI, imm);
						emitter.Emit2(InstructionSet.opADD, opESI, imm);
						imm := Assembler.NewImm32(size DIV 4);
						emitter.Emit2(InstructionSet.opMOV, opECX, imm);
						emitter.Emit0(InstructionSet.opSTD); (* copy down *)
						emitter.EmitPrefix (InstructionSet.prfREP);
						emitter.Emit0(InstructionSet.opMOVSD);
					END
				ELSIF  IntermediateCode.IsConstantInteger(instruction.op3, size) THEN
					imm := Assembler.NewImm32(size DIV 4);
					emitter.Emit2(InstructionSet.opMOV, opECX, imm);
					emitter.Emit0(InstructionSet.opCLD); (* copy upwards *)
					emitter.EmitPrefix (InstructionSet.prfREP);
					emitter.Emit0(InstructionSet.opMOVSD);
					IF size MOD 4 # 0 THEN
						imm := Assembler.NewImm32(size MOD 4);
						emitter.Emit2(InstructionSet.opMOV, opECX, imm);
						emitter.EmitPrefix (InstructionSet.prfREP);
						emitter.Emit0(InstructionSet.opMOVSB);
					END;
				(* this does not work in the kernel -- for whatever reasons *)
				ELSIF (instruction.op1.mode = IntermediateCode.ModeRegister) & (instruction.op1.register = IntermediateCode.SP) THEN
					MakeOperand(instruction.op3,Low,op3,ecx);
					t := TemporaryTicket(IntermediateCode.GeneralPurposeRegister, IntermediateCode.int32);
					TicketToOperand(t, temp);
					emitter.Emit2(InstructionSet.opADD, opESI, opECX);
					emitter.Emit2(InstructionSet.opADD, opEDI, opECX);
					imm := Assembler.NewImm8(1);
					emitter.Emit2(InstructionSet.opSUB, opESI, imm);
					emitter.Emit2(InstructionSet.opSUB, opEDI, imm);
					emitter.Emit2(InstructionSet.opMOV, temp, opECX);
					imm := Assembler.NewImm8(3);
					emitter.Emit2(InstructionSet.opAND, opECX, imm);
					emitter.Emit0(InstructionSet.opSTD); (* copy downwards *)
					emitter.EmitPrefix (InstructionSet.prfREP);
					emitter.Emit0(InstructionSet.opMOVSB);
					imm := Assembler.NewImm8(2);
					emitter.Emit2(InstructionSet.opMOV, opECX, temp);
					emitter.Emit2(InstructionSet.opSHR, opECX, imm);
					imm := Assembler.NewImm8(3);
					emitter.Emit2(InstructionSet.opSUB, opESI, imm);
					emitter.Emit2(InstructionSet.opSUB, opEDI, imm);
					emitter.EmitPrefix (InstructionSet.prfREP);
					emitter.Emit0(InstructionSet.opMOVSD);
					emitter.Emit0(InstructionSet.opCLD);
				ELSE
					MakeOperand(instruction.op3,Low,op3,ecx);
					t := TemporaryTicket(IntermediateCode.GeneralPurposeRegister, IntermediateCode.int32);
					TicketToOperand(t, temp);
					emitter.Emit2(InstructionSet.opMOV, temp, opECX);
					imm := Assembler.NewImm8(3);
					emitter.Emit2(InstructionSet.opAND, temp, imm);
					imm := Assembler.NewImm8(2);
					emitter.Emit2(InstructionSet.opSHR, opECX, imm);
					emitter.Emit0(InstructionSet.opCLD); (* copy upwards *)
					emitter.EmitPrefix (InstructionSet.prfREP);
					emitter.Emit0(InstructionSet.opMOVSD);
					emitter.Emit2(InstructionSet.opMOV, opECX, temp);
					emitter.EmitPrefix (InstructionSet.prfREP);
					emitter.Emit0(InstructionSet.opMOVSB);
				END;
				UnmapTicket(esi);
				UnmapTicket(edi);
				UnmapTicket(ecx);
				IF backend.cooperative THEN
					UnSpill(ap);
					ap.spillable := FALSE;
				END;
			END;
		END EmitCopy;


		PROCEDURE EmitFill(CONST instruction: IntermediateCode.Instruction; down: BOOLEAN);
		VAR reg,sizeInBits,i: LONGINT;val, value, size, dest: Assembler.Operand;
			op: LONGINT;
			edi, ecx: Ticket;
		BEGIN
			IF FALSE & (instruction.op2.mode = IntermediateCode.ModeImmediate) & (instruction.op2.symbol.name = "") & (instruction.op2.intValue < 5) THEN
				sizeInBits := instruction.op3.type.sizeInBits;
				IF sizeInBits = IntermediateCode.Bits8 THEN value := opAL;
				ELSIF sizeInBits = IntermediateCode.Bits16 THEN value := opAX;
				ELSIF sizeInBits = IntermediateCode.Bits32 THEN value := opEAX;
				ELSE HALT(200)
				END;
				MakeOperand(instruction.op1,Low,dest,NIL);
				IF instruction.op1.mode = IntermediateCode.ModeRegister THEN reg := dest.register
				ELSE emitter.Emit2(InstructionSet.opMOV,opEDX,dest); reg := EDX;
				END;
				IF (instruction.op3.mode = IntermediateCode.ModeImmediate) & (instruction.op3.type.form IN IntermediateCode.Integer) & (instruction.op3.intValue = 0) THEN
					emitter.Emit2(InstructionSet.opXOR,opEAX,opEAX);
				ELSE
					MakeOperand(instruction.op3,Low,value,NIL);
				END;
				FOR i := 0 TO SHORT(instruction.op2.intValue)-1 DO
					IF down THEN
						Assembler.InitMem(dest,SHORT(SHORT(sizeInBits DIV 8)),reg,-i*sizeInBits DIV 8);
					ELSE
						Assembler.InitMem(dest,SHORT(SHORT(sizeInBits DIV 8 )),reg,i*sizeInBits DIV 8);
					END;
					emitter.Emit2(InstructionSet.opMOV,dest,value);
				END;
			ELSE
				Spill(physicalRegisters.Mapped(EDI));
				IF backend.cooperative THEN ap.spillable := TRUE END;
				Spill(physicalRegisters.Mapped(ECX));
				edi := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EDI,inPC);
				ecx := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,ECX,inPC);

				MakeOperand(instruction.op1,Low,dest,edi);
				MakeOperand(instruction.op2,Low,size,ecx);
				MakeOperand(instruction.op3,Low,value,NIL);
				(*
				emitter.Emit2(InstructionSet.opMOV,opEDI, op1[Low]);
				emitter.Emit2(InstructionSet.opMOV,opECX, op3[Low]);
				*)
				CASE instruction.op3.type.sizeInBits OF
					IntermediateCode.Bits8: val := opAL; op := InstructionSet.opSTOSB;
					|IntermediateCode.Bits16: val := opAX; op := InstructionSet.opSTOSW;
					|IntermediateCode.Bits32: val := opEAX; op := InstructionSet.opSTOSD;
				ELSE Halt("only supported for upto 32 bit integers ");
				END;

				IF (instruction.op3.mode = IntermediateCode.ModeImmediate) & (instruction.op3.type.form IN IntermediateCode.Integer) & (instruction.op3.intValue = 0) THEN
					emitter.Emit2(InstructionSet.opXOR,opEAX,opEAX);
				ELSE
					emitter.Emit2(InstructionSet.opMOV,val,value);
				END;

				IF down THEN
					emitter.Emit0(InstructionSet.opSTD); (* fill downwards *)
				ELSE
					emitter.Emit0(InstructionSet.opCLD); (* fill upwards *)
				END;
				emitter.EmitPrefix (InstructionSet.prfREP);
				emitter.Emit0(op);
				IF down THEN (* needed as calls to windows crash otherwise *)
					emitter.Emit0(InstructionSet.opCLD);
				END;
				UnmapTicket(ecx);
				IF backend.cooperative THEN
					UnSpill(ap);
					ap.spillable := FALSE;
				END;
			END;
		END EmitFill;

		PROCEDURE EmitBr (CONST instruction: IntermediateCode.Instruction);
		VAR dest,destPC,offset: LONGINT; target: Assembler.Operand;hit,fail: LONGINT; reverse: BOOLEAN;
			(* jump operands *)  left,right,temp: Assembler.Operand;
				failOp: Assembler.Operand; failPC: LONGINT;

			PROCEDURE JmpDest(brop: LONGINT);
			BEGIN
				IF instruction.op1.mode = IntermediateCode.ModeImmediate THEN
					IF instruction.op1.symbol.name # in.name THEN
						Assembler.InitOffset32(target,instruction.op1.intValue);
						Assembler.SetSymbol(target,instruction.op1.symbol.name,instruction.op1.symbol.fingerprint,instruction.op1.symbolOffset,instruction.op1.offset);
						emitter.Emit1(brop,target);
					ELSE
						dest := (instruction.op1.symbolOffset); (* this is the offset in the in-data section (intermediate code), it is not byte- *)
						destPC := (in.instructions[dest].pc );
						offset := destPC - (out.pc );
						IF dest > inPC THEN (* forward jump *)
							Assembler.InitOffset32(target,0);
							Assembler.SetSymbol(target,instruction.op1.symbol.name,instruction.op1.symbol.fingerprint,instruction.op1.symbolOffset,instruction.op1.offset);
							emitter.Emit1(brop,target);
						ELSIF ABS(offset)  <= 126 THEN
							Assembler.InitOffset8(target,destPC);
							emitter.Emit1(brop,target);
						ELSE
							Assembler.InitOffset32(target,destPC);
							emitter.Emit1(brop,target);
						END;
					END;
				ELSE
					MakeOperand(instruction.op1,Low,target,NIL);
					emitter.Emit1(brop,target);
				END;
			END JmpDest;

			PROCEDURE CmpFloat;
			BEGIN
				IF backend.forceFPU THEN
					MakeOperand(instruction.op2,Low,left,NIL);
					emitter.Emit1(InstructionSet.opFLD,left); INC(fpStackPointer);
					MakeOperand(instruction.op3,Low,right,NIL);
					emitter.Emit1(InstructionSet.opFCOMP,right); DEC(fpStackPointer);
					emitter.Emit1(InstructionSet.opFNSTSW,opAX);
					emitter.Emit0(InstructionSet.opSAHF);
				ELSE
					MakeRegister(instruction.op2,Low,left);
					MakeOperand(instruction.op3,Low,right,NIL);
					IF instruction.op2.type.sizeInBits = 32 THEN
						emitter.Emit2(InstructionSet.opCOMISS, left, right);
					ELSE
						emitter.Emit2(InstructionSet.opCOMISD, left, right);
					END
				END;
			END CmpFloat;

			PROCEDURE Cmp(part: LONGINT; VAR reverse: BOOLEAN);
			VAR type: IntermediateCode.Type; left,right: Assembler.Operand;
			BEGIN
				IF (instruction.op2.mode = IntermediateCode.ModeImmediate) & (instruction.op3.mode = IntermediateCode.ModeImmediate) THEN
					reverse := FALSE;
					GetPartType(instruction.op2.type,part,type);
					GetTemporaryRegister(type,temp);
					MakeOperand(instruction.op2,part,left,NIL);
					MakeOperand(instruction.op3,part,right,NIL);
					Move(temp,left, type);
					left := temp;
				ELSIF instruction.op2.mode = IntermediateCode.ModeImmediate THEN
					reverse := TRUE;
					MakeOperand(instruction.op2,part,right,NIL);
					MakeOperand(instruction.op3,part,left,NIL);
				ELSIF IsMemoryOperand(instruction.op2,part) & IsMemoryOperand(instruction.op3,part) THEN
					reverse := FALSE;
					GetPartType(instruction.op2.type,part,type);
					GetTemporaryRegister(type,temp);
					MakeOperand(instruction.op2,part,left,NIL);
					MakeOperand(instruction.op3,part,right,NIL);
					Move(temp,right,type);
					right := temp;
				ELSE
					reverse := FALSE;
					MakeOperand(instruction.op2,part,left,NIL);
					MakeOperand(instruction.op3,part,right,NIL);
				END;
				emitter.Emit2(InstructionSet.opCMP,left,right);
			END Cmp;


		BEGIN
			IF (instruction.op1.symbol.name = in.name) & (instruction.op1.symbolOffset = inPC +1) THEN (* jump to next instruction can be ignored *)
				IF dump # NIL THEN dump.String("jump to next instruction ignored"); dump.Ln END;
				RETURN
			END;

			failPC := 0;
			IF instruction.opcode = IntermediateCode.br THEN
				hit := InstructionSet.opJMP
			ELSIF instruction.op2.type.form = IntermediateCode.Float THEN
				CmpFloat;
				CASE instruction.opcode OF
				IntermediateCode.breq:	hit := InstructionSet.opJE;
				|IntermediateCode.brne:hit := InstructionSet.opJNE;
				|IntermediateCode.brge: hit := InstructionSet.opJAE
				|IntermediateCode.brlt: hit := InstructionSet.opJB
				END;
			ELSE
				IF ~IsComplex(instruction.op2) THEN
					Cmp(Low,reverse);
					CASE instruction.opcode OF
					IntermediateCode.breq: hit := InstructionSet.opJE;
					|IntermediateCode.brne: hit := InstructionSet.opJNE;
					|IntermediateCode.brge:
						IF instruction.op2.type.form = IntermediateCode.SignedInteger THEN
							IF reverse THEN hit := InstructionSet.opJLE ELSE hit := InstructionSet.opJGE END;
						ELSIF instruction.op2.type.form = IntermediateCode.UnsignedInteger THEN
							IF reverse THEN hit := InstructionSet.opJBE ELSE hit := InstructionSet.opJAE END;
						END;
					|IntermediateCode.brlt:
						IF instruction.op2.type.form = IntermediateCode.SignedInteger THEN
							IF reverse THEN hit := InstructionSet.opJG ELSE hit := InstructionSet.opJL END;
						ELSIF instruction.op2.type.form = IntermediateCode.UnsignedInteger THEN
							IF reverse THEN hit := InstructionSet.opJA ELSE hit := InstructionSet.opJB END;
						END;
					END;
				ELSE
					Assert(instruction.op2.type.form = IntermediateCode.SignedInteger,"no unsigned integer64");
					Cmp(High,reverse);
					CASE instruction.opcode OF
					IntermediateCode.breq: hit := 0; fail := InstructionSet.opJNE;
					|IntermediateCode.brne: hit := InstructionSet.opJNE; fail := 0;
					|IntermediateCode.brge:
						IF reverse THEN hit := InstructionSet.opJL; fail := InstructionSet.opJG;
						ELSE hit := InstructionSet.opJG; fail := InstructionSet.opJL
						END;
					|IntermediateCode.brlt:
						IF reverse THEN hit := InstructionSet.opJG; fail := InstructionSet.opJL
						ELSE hit := InstructionSet.opJL; fail := InstructionSet.opJG
						END;
					END;
					IF hit # 0 THEN JmpDest(hit)	END;
					IF fail # 0 THEN
						failPC := out.pc; (* to avoid potential value overflow problem, will be patched anyway  *)
						Assembler.InitOffset8(failOp,failPC );
						emitter.Emit1(fail,failOp);
						failPC := failOp.pc;
					END;
					Cmp(Low,reverse);
					CASE instruction.opcode OF
					IntermediateCode.breq: hit := InstructionSet.opJE
					|IntermediateCode.brne: hit := InstructionSet.opJNE
					|IntermediateCode.brge:
						IF reverse THEN hit := InstructionSet.opJBE ELSE hit := InstructionSet.opJAE END;
					|IntermediateCode.brlt:
						IF reverse THEN hit := InstructionSet.opJA ELSE hit := InstructionSet.opJB END;
					END;
				END;
			END;
			JmpDest(hit);
			IF failPC > 0 THEN out.PutByteAt(failPC,(out.pc-failPC)-1); END;
		END EmitBr;

		PROCEDURE EmitPush(CONST vop: IntermediateCode.Operand; part: LONGINT);
		VAR  index: LONGINT; type,cpuType: IntermediateCode.Type; op1: Assembler.Operand; ra: Ticket;
		BEGIN
			GetPartType(vop.type,part,type);
			ASSERT(type.form IN IntermediateCode.Integer);

			IF	vop.mode = IntermediateCode.ModeImmediate THEN (* may not push 16 bit immediate: strange instruction in 32 / 64 bit mode *)
				GetImmediate(vop,part,op1,TRUE);
				emitter.Emit1(InstructionSet.opPUSH,op1);
			ELSIF (type.sizeInBits = cpuBits) THEN
				MakeOperand(vop,part,op1,NIL);
				emitter.Emit1(InstructionSet.opPUSH,op1);
			ELSE
				ASSERT(type.sizeInBits < cpuBits);
				MakeOperand(vop,part,op1,NIL);
				IF Assembler.IsRegisterOperand(op1) & ~((cpuBits=32) & (type.sizeInBits=8) & (op1.register >= AH)) THEN
					index := op1.register MOD 32 + opRA.register;
					emitter.Emit1(InstructionSet.opPUSH, registerOperands[index]);
				ELSE
					WHILE physicalRegisters.Mapped(opRA.register) # free DO Spill(physicalRegisters.Mapped(opRA.register)) END;
					IntermediateCode.InitType(cpuType,IntermediateCode.SignedInteger,SHORT(cpuBits));
					ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,cpuType,opRA.register,inPC);
					CASE type.sizeInBits OF
						8: index := AL
						|16: index := AX
						|32: index := EAX
						|64: index := RAX
					END;
					emitter.Emit2(InstructionSet.opMOV,registerOperands[index],op1);
					emitter.Emit1(InstructionSet.opPUSH,opRA);
					UnmapTicket(ra);
				END;
			END;
		END EmitPush;

		PROCEDURE EmitPop(CONST vop: IntermediateCode.Operand; part: LONGINT);
		VAR  index: LONGINT; type,cpuType: IntermediateCode.Type; op1: Assembler.Operand; ra: Ticket;
		BEGIN
			GetPartType(vop.type,part,type);
			ASSERT(type.form IN IntermediateCode.Integer);

			IF (type.sizeInBits = cpuBits) THEN
				MakeOperand(vop,part,op1,NIL);
				emitter.Emit1(InstructionSet.opPOP,op1);
			ELSE
				ASSERT(type.sizeInBits < cpuBits);
				MakeOperand(vop,part,op1,NIL);
				IF Assembler.IsRegisterOperand(op1) & ~((cpuBits=32) & (type.sizeInBits=8) & (op1.register >= AH)) THEN
					index := op1.register MOD 32 + opRA.register;
					emitter.Emit1(InstructionSet.opPOP, registerOperands[index]);
				ELSE
					WHILE physicalRegisters.Mapped(opRA.register) # free DO Spill(physicalRegisters.Mapped(opRA.register)) END;
					IntermediateCode.InitType(cpuType, IntermediateCode.SignedInteger, SHORT(cpuBits));
					ra := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,cpuType,opRA.register,inPC);
					emitter.Emit1(InstructionSet.opPOP,opRA);
					CASE type.sizeInBits OF
						8: index := AL
						|16: index := AX
						|32: index := EAX
						|64: index := RAX
					END;
					emitter.Emit2(InstructionSet.opMOV, op1, registerOperands[index]);
					UnmapTicket(ra);
				END;
			END;
		END EmitPop;

		PROCEDURE EmitPushFloat(CONST vop: IntermediateCode.Operand);
		VAR sizeInBytes,length: LONGINT; memop: Assembler.Operand; op: Assembler.Operand;
		BEGIN
			MakeOperand(vop,Low,op,NIL);
			length := vop.type.length;
			IF (vop.mode = IntermediateCode.ModeMemory) & (vop.type.sizeInBits*length =cpuBits) THEN
				emitter.Emit1(InstructionSet.opPUSH,op);
			ELSE
				sizeInBytes := vop.type.sizeInBits DIV 8;
				length := vop.type.length;
				AllocateStack(sizeInBytes*length);
				Assembler.InitMem(memop, SHORTINT(sizeInBytes*length),SP,0);
				IF backend.forceFPU THEN
					emitter.Emit1(InstructionSet.opFLD,op); INC(fpStackPointer);
					emitter.Emit1(InstructionSet.opFSTP,memop); DEC(fpStackPointer);
				ELSE
					Move(memop, op, vop.type)
				END
			END;
		END EmitPushFloat;

		PROCEDURE EmitPopFloat(CONST vop: IntermediateCode.Operand);
		VAR sizeInBytes,length: LONGINT; memop: Assembler.Operand; op: Assembler.Operand;
		BEGIN
			sizeInBytes := vop.type.sizeInBits DIV 8;
			length := vop.type.length;
			IF (vop.mode = IntermediateCode.ModeMemory) & (vop.type.sizeInBits*length =cpuBits) THEN
				MakeOperand(vop,Low,op,NIL);
				emitter.Emit1(InstructionSet.opPOP,op);
			ELSE
				Assembler.InitMem(memop, SHORTINT(sizeInBytes*length),SP,0);
				IF backend.forceFPU THEN
					emitter.Emit1(InstructionSet.opFLD,memop);
					INC(fpStackPointer);
					MakeOperand(vop,Low,op,NIL);
					emitter.Emit1(InstructionSet.opFSTP,op);
					DEC(fpStackPointer);
					ASSERT(sizeInBytes > 0);
				ELSE
					MakeOperand(vop,Low,op,NIL);
					Move(op, memop, vop.type)
				END;
				AllocateStack(-sizeInBytes*length);
			END;
		END EmitPopFloat;

		PROCEDURE EmitNeg(CONST instruction: IntermediateCode.Instruction);
		VAR opLow,opHigh: Assembler.Operand; minusOne: Assembler.Operand; ticketLow,ticketHigh: Ticket;
		BEGIN
			IF IsComplex(instruction.op1) THEN
				PrepareOp2(instruction,High,opHigh,ticketHigh);
				PrepareOp2(instruction,Low,opLow,ticketLow);
				emitter.Emit1(InstructionSet.opNOT,opHigh);
				emitter.Emit1(InstructionSet.opNEG,opLow);
				Assembler.InitImm8(minusOne,-1);
				emitter.Emit2(InstructionSet.opSBB,opHigh,minusOne);
				FinishOp(instruction.op1,High,opHigh,ticketHigh);
				FinishOp(instruction.op1,Low,opLow,ticketLow);
			ELSE
				EmitArithmetic2(instruction,Low,InstructionSet.opNEG);
			END;
		END EmitNeg;

		PROCEDURE EmitNegXMM(CONST instruction: IntermediateCode.Instruction);
		VAR temp, op: Assembler.Operand; ticket: Ticket;
		BEGIN
			PrepareOp2(instruction, Low, op, ticket);
			GetTemporaryRegister(instruction.op1.type,temp);
			IF instruction.op1.type.sizeInBits = 32 THEN
				emitter.Emit2(InstructionSet.opXORPS, temp, temp);
				emitter.Emit2(InstructionSet.opSUBPS, temp, op);
				emitter.Emit2(InstructionSet.opMOVAPS, op, temp);
			ELSE
				emitter.Emit2(InstructionSet.opXORPD, temp, temp);
				emitter.Emit2(InstructionSet.opSUBPD, temp, op);
				emitter.Emit2(InstructionSet.opMOVAPS, op, temp);
			END;
			FinishOp(instruction.op1, Low, op, ticket);
		END EmitNegXMM;


		PROCEDURE EmitAbs(CONST instruction: IntermediateCode.Instruction);
		VAR op1,op2: Assembler.Operand; source,imm: Assembler.Operand; eax: Ticket;
		BEGIN
			Assert(~IsComplex(instruction.op1),"complex Abs not supported");
			IF instruction.op1.type.form  = IntermediateCode.SignedInteger THEN
				Spill(physicalRegisters.Mapped(EAX));
				eax := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,EAX,inPC);

				MakeOperand(instruction.op1,Low,op1,NIL);
				MakeOperand(instruction.op2,Low,op2,NIL);

				CASE instruction.op1.type.sizeInBits OF
				| IntermediateCode.Bits8: imm := Assembler.NewImm8 (7); source := opAL;
				| IntermediateCode.Bits16: imm := Assembler.NewImm8 (15); source := opAX;
				| IntermediateCode.Bits32: imm := Assembler.NewImm8 (31); source := opEAX;
				END;
				emitter.Emit2 (InstructionSet.opMOV, source,op2);
				emitter.Emit2 (InstructionSet.opMOV, op1,source);

				emitter.Emit2 (InstructionSet.opSAR, source, imm);
				emitter.Emit2 (InstructionSet.opXOR, op1, source);
				emitter.Emit2 (InstructionSet.opSUB, op1, source);

				UnmapTicket(eax);
			ELSE Halt("Abs does not make sense on unsigned integer")
			END;
		END EmitAbs;

		PROCEDURE EmitAbsXMM(CONST instruction: IntermediateCode.Instruction);
		VAR temp, op: Assembler.Operand; ticket: Ticket;
		BEGIN
			PrepareOp2(instruction, Low, op, ticket);
			GetTemporaryRegister(instruction.op1.type,temp);
			IF instruction.op1.type.sizeInBits = 32 THEN
				emitter.Emit2(InstructionSet.opXORPS, temp, temp);
				emitter.Emit2(InstructionSet.opSUBPS, temp, op);
				emitter.Emit2(InstructionSet.opMAXPS, op, temp);
			ELSE
				emitter.Emit2(InstructionSet.opXORPD, temp, temp);
				emitter.Emit2(InstructionSet.opSUBPD, temp, op);
				emitter.Emit2(InstructionSet.opMAXPD, op, temp);
			END;
			FinishOp(instruction.op1, Low, op, ticket);
		END EmitAbsXMM;

		PROCEDURE EmitTrap(CONST instruction: IntermediateCode.Instruction);
		VAR operand: Assembler.Operand;
		BEGIN
			IF instruction.op1.intValue < 80H THEN
				operand := Assembler.NewImm8(instruction.op1.intValue);
			ELSE
				operand := Assembler.NewImm32(instruction.op1.intValue);
			END;
			emitter.Emit1(InstructionSet.opPUSH, operand);
			emitter.Emit0(InstructionSet.opINT3);
		END EmitTrap;

		PROCEDURE EmitAsm(CONST instruction: IntermediateCode.Instruction);
		VAR reader: Streams.StringReader;  procedure: SyntaxTree.Procedure; scope: SyntaxTree.Scope;
				len: LONGINT; symbol: SyntaxTree.Symbol; assembler: Assembler.Assembly;

			inr, outr: IntermediateCode.Rules;
			string: SyntaxTree.SourceCode;
			i: LONGINT;
			reg, dest: Assembler.Operand;
			map: Assembler.RegisterMap;
			register: LONGINT;
			ticket: Ticket;
		BEGIN
			IF instruction.op2.mode = IntermediateCode.ModeRule THEN	inr := instruction.op2.rule ELSE inr := NIL END;
			IF instruction.op3.mode = IntermediateCode.ModeRule THEN outr := instruction.op3.rule ELSE outr := NIL END;
			string := instruction.op1.string;

			NEW(map);

			IF inr # NIL THEN
				FOR i := 0 TO LEN(inr)-1 DO
					MakeRegister(inr[i], 0, reg);
					ASSERT(map.Find(inr[i].string^) < 0);
					map.Add(inr[i].string, reg.register)
				END;
			END;

			IF outr # NIL THEN
				FOR i := 0 TO LEN(outr)-1 DO
					IF (map.Find(outr[i].string^) < 0) THEN
						GetTemporaryRegister(outr[i].type,reg);
						map.Add(outr[i].string, reg.register)
					END;
				END;
			END;

			len := Strings.Length(string^);
			NEW(reader,len);
			reader.Set(string^);

			symbol := in.symbol;
			procedure := symbol(SyntaxTree.Procedure);
			scope := procedure.procedureScope;
			NEW(assembler,diagnostics,emitter);
			assembler.Assemble(reader,SHORT(instruction.op1.intValue),scope,in,in,module,procedure.access * SyntaxTree.Public # {}, procedure.isInline, map)	;
			error := error OR assembler.error;

			IF outr # NIL THEN
				FOR i := 0 TO LEN(outr)-1 DO
					IF outr[i].mode # IntermediateCode.Undefined THEN
						register := map.Find(outr[i].string^);
						ticket := physicalRegisters.Mapped(register);
						IF ticket.lastuse = inPC THEN UnmapTicket(ticket); physicalRegisters.AllocationHint(register) END; (* try to reuse register here *)
						Assembler.InitRegister(reg, register);
						MakeOperand(outr[i], Low, dest, NIL);
						IF outr[i].type.length > 1 THEN
							SpecialMove(InstructionSet.opMOVUPS,InstructionSet.opMOVUPS, TRUE, dest, reg, outr[i].type)
						ELSE
							Move( dest, reg,outr[i].type)
						END;
					END;
				END;
			END;

			(*
			IntermediateCode.SetString(instruction.op1, string);
			*)
		END EmitAsm;

	END CodeGeneratorAMD64;

	BackendAMD64= OBJECT (IntermediateBackend.IntermediateBackend)
	VAR
		cg: CodeGeneratorAMD64;
		bits: LONGINT;
		traceable: BOOLEAN;
		forceFPU: BOOLEAN;

		PROCEDURE &InitBackendAMD64;
		BEGIN
			InitIntermediateBackend;
			bits := 32;
			forceFPU := FALSE;
		END InitBackendAMD64;

		PROCEDURE Initialize(diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; flags: SET; checker: SemanticChecker.Checker; system: Global.System);
		BEGIN
			Initialize^(diagnostics,log, flags,checker,system); NEW(cg, runtimeModuleName, diagnostics, SELF);
		END Initialize;

		PROCEDURE GetSystem(): Global.System;
		VAR system: Global.System;

			PROCEDURE AddRegister(CONST name: Scanner.IdentifierString; val: LONGINT);
			BEGIN
				Global.NewConstant(name,val,system.shortintType,system.systemScope)
			END AddRegister;

			PROCEDURE AddRegisters;
			BEGIN
				(* system constants *)
				AddRegister("EAX",InstructionSet.regEAX);  AddRegister("ECX", InstructionSet.regECX);
				AddRegister( "EDX", InstructionSet.regEDX);  AddRegister( "EBX", InstructionSet.regEBX);
				AddRegister( "ESP", InstructionSet.regESP);  AddRegister( "EBP", InstructionSet.regEBP);
				AddRegister( "ESI", InstructionSet.regESI);  AddRegister( "EDI", InstructionSet.regEDI);

				AddRegister( "AX", InstructionSet.regAX);  AddRegister( "CX", InstructionSet.regCX);
				AddRegister( "DX", InstructionSet.regDX);  AddRegister( "BX", InstructionSet.regBX);

				AddRegister( "AL", InstructionSet.regAL);  AddRegister( "CL", InstructionSet.regCL);
				AddRegister( "DL", InstructionSet.regDL);  AddRegister( "BL", InstructionSet.regBL);
				AddRegister( "AH", InstructionSet.regAH);  AddRegister( "CH", InstructionSet.regCH);
				AddRegister( "DH", InstructionSet.regDH);  AddRegister( "BH", InstructionSet.regBH);

				AddRegister( "RAX", InstructionSet.regRAX);  AddRegister( "RCX", InstructionSet.regRCX);
				AddRegister( "RDX", InstructionSet.regRDX);  AddRegister( "RBX", InstructionSet.regRBX);
				AddRegister( "RSP", InstructionSet.regRSP);  AddRegister( "RBP", InstructionSet.regRBP);
				AddRegister( "RSI", InstructionSet.regRSI);  AddRegister( "RDI", InstructionSet.regRDI);
				AddRegister( "R8", InstructionSet.regR8);  AddRegister( "R9", InstructionSet.regR9);
				AddRegister( "R10", InstructionSet.regR10);  AddRegister( "R11", InstructionSet.regR11);
				AddRegister( "R12", InstructionSet.regR12);  AddRegister( "R13", InstructionSet.regR13);
				AddRegister( "R14", InstructionSet.regR14);  AddRegister( "R15", InstructionSet.regR15);

				AddRegister( "R8D", InstructionSet.regR8D);  AddRegister( "R9D", InstructionSet.regR9D);
				AddRegister( "R10D", InstructionSet.regR10D);  AddRegister( "R11D", InstructionSet.regR11D);
				AddRegister( "R12D", InstructionSet.regR12D);  AddRegister( "R13D", InstructionSet.regR13D);
				AddRegister( "R14D", InstructionSet.regR14D);  AddRegister( "R15D", InstructionSet.regR15D);

				AddRegister( "R8W", InstructionSet.regR8W);  AddRegister( "R9W", InstructionSet.regR9W);
				AddRegister( "R10W", InstructionSet.regR10W);  AddRegister( "R11W", InstructionSet.regR11W);
				AddRegister( "R12W", InstructionSet.regR12W);  AddRegister( "R13W", InstructionSet.regR13W);
				AddRegister( "R14W", InstructionSet.regR14W);  AddRegister( "R15W", InstructionSet.regR15W);

				AddRegister( "R8B", InstructionSet.regR8B);  AddRegister( "R9B", InstructionSet.regR9B);
				AddRegister( "R10B", InstructionSet.regR10B);  AddRegister( "R11B", InstructionSet.regR11B);
				AddRegister( "R12B", InstructionSet.regR12B);  AddRegister( "R13B", InstructionSet.regR13B);
				AddRegister( "R14B", InstructionSet.regR14B);  AddRegister( "R15B", InstructionSet.regR15B);
			END AddRegisters;

		BEGIN
			IF system = NIL THEN
				IF bits=32 THEN
					NEW(system,8,8,32, 8,32,32,32,64,0,cooperative);
					Global.SetDefaultDeclarations(system,8);
					Global.SetDefaultOperators(system);
				ELSE
					NEW(system,8,8,64,8,64,64,64,128,4 (* parameter registers *),cooperative);
					Global.SetDefaultDeclarations(system,8);
					Global.SetDefaultOperators(system);
				END;
				system.SetRegisterPassCallback(CanPassInRegister);
				AddRegisters
			END;
			RETURN system
		END GetSystem;

		PROCEDURE SupportedInstruction(CONST instruction: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			RETURN cg.Supported(instruction,moduleName,procedureName);
		END SupportedInstruction;

		PROCEDURE GenerateBinary(module: Sections.Module; dump: Streams.Writer);
		VAR
			in: Sections.Section;
			out: BinaryCode.Section;
			name: Basic.SegmentedName;
			procedure: SyntaxTree.Procedure;
			i, j, initialSectionCount: LONGINT;

		 	(* recompute fixup positions and assign binary sections *)
		 	PROCEDURE PatchFixups(section: BinaryCode.Section);
			VAR resolved: BinaryCode.Section; fixup: BinaryCode.Fixup; displacement,symbolOffset: LONGINT; in: IntermediateCode.Section;
				symbol: Sections.Section;
			BEGIN
				fixup := section.fixupList.firstFixup;
				WHILE fixup # NIL DO
					symbol := module.allSections.FindByName(fixup.symbol.name);
					IF  (symbol # NIL) & (symbol(IntermediateCode.Section).resolved # NIL) THEN
						resolved := symbol(IntermediateCode.Section).resolved(BinaryCode.Section);
						in := symbol(IntermediateCode.Section);
						symbolOffset := fixup.symbolOffset;
						IF symbolOffset = in.pc THEN
							displacement := resolved.pc
						ELSIF (symbolOffset # 0) THEN
							ASSERT(in.pc > symbolOffset);
							displacement := in.instructions[symbolOffset].pc;
						ELSE
							displacement := 0;
						END;
						fixup.SetSymbol(fixup.symbol.name,fixup.symbol.fingerprint,0,fixup.displacement+displacement);
					END;
					fixup := fixup.nextFixup;
				END;
			END PatchFixups;

		BEGIN
		 	cg.SetModule(module);

		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
		 		IF in.type = Sections.InlineCodeSection THEN
		 			name := in.name;
			 		out := ResolvedSection(in(IntermediateCode.Section));
			 		cg.Section(in(IntermediateCode.Section),out);
			 		procedure := in.symbol(SyntaxTree.Procedure);
			 		IF procedure.procedureScope.body.code # NIL THEN
				 		procedure.procedureScope.body.code.SetBinaryCode(out.os.bits);
				 	END;
			 	END
		 	END;

			initialSectionCount := 0;
		 	REPEAT
		 		j := initialSectionCount;
		 	 	initialSectionCount := module.allSections.Length() ;

			 	FOR i := j TO initialSectionCount - 1 DO
			 		in := module.allSections.GetSection(i);
			 		IF (in.type # Sections.InlineCodeSection) & (in(IntermediateCode.Section).resolved = NIL) THEN
			 			name := in.name;
				 		out := ResolvedSection(in(IntermediateCode.Section));
				 		cg.Section(in(IntermediateCode.Section),out);
				 		IF out.os.type = Sections.VarSection THEN
				 			IF out.pc = 1 THEN out.SetAlignment(FALSE,1)
				 			ELSIF out.pc = 2 THEN out.SetAlignment(FALSE,2)
				 			ELSIF out.pc > 2 THEN out.SetAlignment(FALSE,4)
				 			END;
				 		ELSIF out.os.type = Sections.ConstSection THEN
				 			out.SetAlignment(FALSE,4);
				 		END;
			 		END
			 	END
			UNTIL initialSectionCount = module.allSections.Length(); (* process remaining sections that have been added during traversal of sections *)

			(*
			FOR i := 0 TO module.allSections.Length() - 1 DO
				in := module.allSections.GetSection(i);
				IF in.kind = Sections.CaseTableKind THEN
			 		IF in(IntermediateCode.Section).resolved = NIL THEN
				 		out := ResolvedSection(in(IntermediateCode.Section));
				 		cg.Section(in(IntermediateCode.Section),out);
				 	END
				 END
		 	END;
			*)

			FOR i := 0 TO module.allSections.Length() - 1 DO
				in := module.allSections.GetSection(i);
		 		PatchFixups(in(IntermediateCode.Section).resolved)
		 	END;

			(*
			FOR i := 0 TO module.allSections.Length() - 1 DO
				in := module.allSections.GetSection(i);
				IF in.kind = Sections.CaseTableKind THEN
			 		PatchFixups(in(IntermediateCode.Section).resolved)
			 	END
		 	END;
			*)

			IF cg.error THEN Error("",Diagnostics.Invalid, Diagnostics.Invalid,"") END;
		END GenerateBinary;

		(* genasm *)
		PROCEDURE ProcessIntermediateCodeModule*(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		VAR
			result: Formats.GeneratedModule;
		BEGIN
			ASSERT(intermediateCodeModule IS Sections.Module);
			result := ProcessIntermediateCodeModule^(intermediateCodeModule);

			IF ~error THEN
				GenerateBinary(result(Sections.Module),dump);
				IF dump # NIL THEN
					dump.Ln; dump.Ln;
					dump.String(";------------------ binary code -------------------"); dump.Ln;
					IF (traceString="") OR (traceString="*") THEN
						result.Dump(dump);
						dump.Update
					ELSE
						Sections.DumpFiltered(dump, result(Sections.Module), traceString);
						dump.Update;
					END
				END;
			END;
			RETURN result
		FINALLY
			IF dump # NIL THEN
				dump.Ln; dump.Ln;
				dump.String("; ------------------ rescued code (code generation trapped) -------------------"); dump.Ln;
				IF (traceString="") OR (traceString="*") THEN
					result.Dump(dump);
					dump.Update
				ELSE
					Sections.DumpFiltered(dump, result(Sections.Module), traceString);
					dump.Update;
				END
			END;
			HALT(100); (* do not continue compiling after trap *)
			RETURN result
		END ProcessIntermediateCodeModule;

		PROCEDURE FindPC(x: SyntaxTree.Module; CONST sectionName: ARRAY OF CHAR; sectionOffset: LONGINT);
		VAR
			section: Sections.Section; binarySection: BinaryCode.Section; label: BinaryCode.LabelList; module: Formats.GeneratedModule;
			i: LONGINT; pooledName: Basic.SegmentedName;
		BEGIN
			module := ProcessSyntaxTreeModule(x);
			Basic.ToSegmentedName(sectionName, pooledName);
			i := 0;
			REPEAT
				section := module(Sections.Module).allSections.GetSection(i);
				INC(i);
			UNTIL (i = module(Sections.Module).allSections.Length()) OR (section.name = pooledName);

			IF section.name # pooledName THEN
				diagnostics.Error(module.module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," could not locate pc");
			ELSE
				binarySection := section(IntermediateCode.Section).resolved;
				label := binarySection.labels;
				WHILE (label # NIL) & (label.offset >= sectionOffset) DO
					label := label.prev;
				END;
				IF label # NIL THEN
					diagnostics.Information(module.module.sourceName,label.position,Diagnostics.Invalid," pc position");
				ELSE
					diagnostics.Error(module.module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," could not locate pc");
				END;
			END;
		END FindPC;

		PROCEDURE CanPassInRegister*(type: SyntaxTree.Type): BOOLEAN;
		VAR length: LONGINT; baseType: SyntaxTree.Type; b: BOOLEAN;
		BEGIN
			b := SemanticChecker.IsStaticMathArray(type, length, baseType) & (baseType IS SyntaxTree.FloatType) & (baseType.sizeInBits = 32) & (length = 4);
			RETURN b
		END CanPassInRegister;


		PROCEDURE GetDescription*(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "AMD";
		END GetDescription;

		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN
			options.Add(0X,"bits",Options.Integer);
			options.Add(0X,"traceable", Options.Flag);
			options.Add(0X,"useFPU", Options.Flag);
			DefineOptions^(options);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		BEGIN
			IF ~options.GetInteger("bits",bits) THEN bits := 32 END;
			traceable := options.GetFlag("traceable");
			forceFPU := options.GetFlag("useFPU");
			GetOptions^(options);
		END GetOptions;

		PROCEDURE DefaultObjectFileFormat(): Formats.ObjectFileFormat;
		BEGIN RETURN ObjectFileFormat.Get();
		END DefaultObjectFileFormat;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN
			RETURN NIL
		END DefaultSymbolFileFormat;

	END BackendAMD64;

	(** the number of regular sections in a section list **)
	PROCEDURE RegularSectionCount(sectionList: Sections.SectionList): LONGINT;
	VAR
		section: Sections.Section;
		i, result: LONGINT;
	BEGIN
		result := 0;
		FOR i := 0 TO sectionList.Length() - 1 DO
			section := sectionList.GetSection(i);
			INC(result)
		END;
		RETURN result
	END RegularSectionCount;

	PROCEDURE Assert(b: BOOLEAN; CONST s: ARRAY OF CHAR);
	BEGIN
		ASSERT(b,100);
	END Assert;

	PROCEDURE Halt(CONST s: ARRAY OF CHAR);
	BEGIN
		HALT(100);
	END Halt;

	PROCEDURE ResolvedSection(in: IntermediateCode.Section): BinaryCode.Section;
	VAR section: BinaryCode.Section;
	BEGIN
		IF in.resolved = NIL THEN
			NEW(section,in.type, in.priority, 8, in.name,in.comments # NIL,FALSE);
			section.SetAlignment(in.fixed, in.positionOrAlignment);
			in.SetResolved(section);
		ELSE
			section := in.resolved
		END;
		RETURN section
	END ResolvedSection;

	PROCEDURE Init;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(registerOperands)-1 DO
			Assembler.InitRegister(registerOperands[i],i);
		END;

		opEAX := registerOperands[EAX];
		opEBX := registerOperands[EBX];
		opECX := registerOperands[ECX];
		opEDX := registerOperands[EDX];
		opESI := registerOperands[ESI];
		opEDI := registerOperands[EDI];
		opEBP := registerOperands[EBP];
		opESP := registerOperands[ESP];
		opRSP := registerOperands[RSP];
		opRBP := registerOperands[RBP];

		opAX := registerOperands[AX];
		opBX := registerOperands[BX];
		opCX := registerOperands[CX];
		opDX := registerOperands[DX];
		opSI := registerOperands[SI];
		opDI := registerOperands[DI];

		opAL := registerOperands[AL];
		opBL := registerOperands[BL];
		opCL := registerOperands[CL];
		opDL := registerOperands[DL];

		opAH := registerOperands[AH];
		opBH := registerOperands[BH];
		opCH := registerOperands[CH];
		opDH := registerOperands[DH];

		opST0 := registerOperands[ST0];

		NEW(unusable); NEW(blocked); NEW(split); free := NIL;

	END Init;

	PROCEDURE Get*(): Backend.Backend;
	VAR backend: BackendAMD64;
	BEGIN NEW(backend); RETURN backend
	END Get;

	PROCEDURE Trace*;
	BEGIN
		TRACE(traceStackSize);
	END Trace;

BEGIN
	traceStackSize := 0;
	Init;
	usePool := Machine.NumberOfProcessors()>1;
END FoxAMDBackend.
