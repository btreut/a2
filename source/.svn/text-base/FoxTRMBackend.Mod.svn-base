MODULE FoxTRMBackend; (** AUTHOR "fof"; PURPOSE "backend for the tiny register machine"; *)

IMPORT
	Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Backend := FoxBackend, Sections := FoxSections,
	IntermediateCode := FoxIntermediateCode, IntermediateBackend := FoxIntermediateBackend, BinaryCode := FoxBinaryCode,
	SemanticChecker := FoxSemanticChecker, Formats := FoxFormats, Assembler := FoxTRMAssembler, InstructionSet := FoxTRMInstructionSet,
	SYSTEM, Diagnostics, Streams, Options, Strings, ObjectFile, Scanner := FoxScanner, ObjectFileFormat := FoxIntermediateObjectFile,
	CodeGenerators := FoxCodeGenerators, D := Debugging;

CONST
	TraceFixups = FALSE;
	DefaultRuntimeModuleName = "TRMRuntime";
	HaltIRQNumber=8;
	Registers = 8; None=-1;
	Low=0; High=1;
	FPSupported = TRUE; (* setting this to false increases code size slightly but also reduces register pressure *)

	opAND= InstructionSet.opAND; opBIC* = InstructionSet.opBIC;
	opOR= InstructionSet.opOR; opXOR= InstructionSet.opXOR;
	opADD= InstructionSet.opADD; opFADD = InstructionSet.opFADD; opSUB= InstructionSet.opSUB; opFSUB = InstructionSet.opFSUB;
	opMUL= InstructionSet.opMUL; opFMUL = InstructionSet.opFMUL; opNOT= InstructionSet.opNOT;
	opLDH= InstructionSet.opLDH;
	opMOV= InstructionSet.opMOV; opROR= InstructionSet.opROR;
	opBLR= InstructionSet.opBLR; opBR= InstructionSet.opBR;
	opIRET* = InstructionSet.opIRET; opLD= InstructionSet.opLD;
	opST= InstructionSet.opST; opBL= InstructionSet.opBL;
	opBEQ= InstructionSet.opBEQ; opBNE= InstructionSet.opBNE;
	opBAE= InstructionSet.opBAE; opBB= InstructionSet.opBB;
	opBN= InstructionSet.opBN; opBNN= InstructionSet.opBNN;
	opBO* = InstructionSet.opBO; opBNO* = InstructionSet.opBNO;
	opBA= InstructionSet.opBA; opBBE= InstructionSet.opBBE;
	opBGE= InstructionSet.opBGE; opBLT= InstructionSet.opBLT;
	opBGT= InstructionSet.opBGT; opBLE= InstructionSet.opBLE;
	opBT= InstructionSet.opBT; opBF* = InstructionSet.opBF;
	opSPSR* = InstructionSet.opSPSR;

	VectorSupportFlag = "vectorSupport";
	FloatingPointSupportFlag ="floatingPoint";
	FPSupportFlag = "supportFP";
	PatchSpartan6 ="patchSpartan6";

TYPE
	Operand=InstructionSet.Operand;

	FixupEntry=POINTER TO RECORD
		maxPC: LONGINT;
		fixup: BinaryCode.Fixup;
		next: FixupEntry;
	END;

	ForwardFixupList=OBJECT
	VAR
		first,last: FixupEntry;

		PROCEDURE &Init;
		BEGIN
			first := NIL; last := NIL;
		END Init;

		PROCEDURE Enter(fixup: BinaryCode.Fixup; currentPC: LONGINT; bits: LONGINT);
		VAR entry: FixupEntry; maxPC: LONGINT;
		BEGIN
			maxPC := currentPC + ASH(1,bits-1) -1; (* signed *)
			NEW(entry); entry.fixup := fixup;
			entry.maxPC := maxPC-1; (* one instruction necessary to jump over the instruction *)
			IF first = NIL THEN first := entry; last := entry;
			ELSE
				ASSERT(last.maxPC <= maxPC); (* otherwise we have to insert sorted but this does not seem necessary *)
				last.next := entry;
				last := entry;
			END;
		END Enter;

		PROCEDURE Check(outPC: LONGINT): BinaryCode.Fixup;
		VAR fixup: BinaryCode.Fixup;
		BEGIN
			IF (first # NIL) & (outPC >= first.maxPC) THEN
				fixup := first.fixup;
				IF first = last THEN first := NIL; last := NIL ELSE first := first.next END;
				RETURN fixup;
			ELSE
				RETURN NIL
			END;
		END Check;

	END ForwardFixupList;

	Ticket=CodeGenerators.Ticket;

	PhysicalRegisters*=OBJECT (CodeGenerators.PhysicalRegisters)
	VAR
		toVirtual: ARRAY Registers OF Ticket; (* registers real register -> none / reserved / split / blocked / virtual register (>0) *)
		reserved: ARRAY Registers OF BOOLEAN;
		unusable: Ticket;
		hint: LONGINT;

		PROCEDURE &InitPhysicalRegisters(supportFP: BOOLEAN);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO LEN(toVirtual)-1 DO
				toVirtual[i] := NIL;
				reserved[i] := FALSE;
			END;
			(* reserve stack and base pointer registers *)
			NEW(unusable);
			toVirtual[InstructionSet.SP] := unusable;
			toVirtual[InstructionSet.LR] := unusable;
			IF supportFP THEN
				toVirtual[InstructionSet.FP] := unusable
			END;
		END InitPhysicalRegisters;

		PROCEDURE SupportFP(b: BOOLEAN);
		BEGIN
			IF b THEN toVirtual[InstructionSet.FP] := unusable ELSE toVirtual[InstructionSet.FP] := NIL END;
		END SupportFP;

		PROCEDURE NumberRegisters(): LONGINT;
		BEGIN
			RETURN Registers
		END NumberRegisters;

		PROCEDURE Allocate(index: LONGINT; virtualRegister: Ticket);
		BEGIN
			Assert(toVirtual[index]=NIL,"register already allocated");
			toVirtual[index] := virtualRegister;
			ASSERT(~virtualRegister.spilled);
		END Allocate;

		PROCEDURE SetReserved(index: LONGINT; res: BOOLEAN);
		BEGIN
			reserved[index] := res;
		END SetReserved;

		PROCEDURE Reserved(index: LONGINT): BOOLEAN;
		BEGIN
			RETURN (index>0) & reserved[index]
		END Reserved;

		PROCEDURE Free(index: LONGINT);
		BEGIN
			Assert((toVirtual[index] # NIL),"register not reserved");
			toVirtual[index] := NIL;
		END Free;

		PROCEDURE NextFree(CONST type: IntermediateCode.Type):LONGINT;
		VAR i: LONGINT;
		BEGIN
			ASSERT(type.sizeInBits=32);
			i := 0;
			IF (hint # None) THEN
				IF toVirtual[hint] = NIL THEN i := hint END;
				hint := None
			END;

			WHILE (i<Registers) & (toVirtual[i] # NIL) DO
				INC(i);
			END;
			IF i=Registers THEN i := None END;
			RETURN i;
		END NextFree;

		PROCEDURE AllocationHint(index: LONGINT);
		BEGIN hint := index
		END AllocationHint;

		PROCEDURE Mapped(physical: LONGINT): Ticket;
		BEGIN
			RETURN toVirtual[physical]
		END Mapped;

		PROCEDURE Dump(w: Streams.Writer);
		VAR i: LONGINT; virtual: Ticket;
		BEGIN
			w.String("---- registers ----"); w.Ln;
			FOR i := 0 TO LEN(toVirtual)-1 DO
				virtual := toVirtual[i];
				IF virtual # unusable THEN
					w.String("reg "); w.Int(i,1); w.String(": ");
					IF virtual = NIL THEN w.String("free")
					ELSE	w.String(" r"); w.Int(virtual.register,1);
					END;
					IF reserved[i] THEN w.String("reserved") END;
					w.Ln;
				END;
			END;
		END Dump;

	END PhysicalRegisters;

	CodeGeneratorTRM = OBJECT (CodeGenerators.GeneratorWithTickets)
	VAR
		opSP, opLR, opFP, null, noOperand: InstructionSet.Operand;
		instructionSet: InstructionSet.InstructionSet;

		stackSize, spillStackPosition: LONGINT;
		stackSizeKnown: BOOLEAN;
		inStackAllocation: BOOLEAN;
		runtimeModuleName: SyntaxTree.IdentifierString;

		forwardFixups: ForwardFixupList;
		spillStackStart: LONGINT;
		backend: BackendTRM;
		supportFP: BOOLEAN;
		pushChainLength: LONGINT;
		patchSpartan6: BOOLEAN;

		PROCEDURE SetInstructionSet(instructionSet: InstructionSet.InstructionSet);
		BEGIN
			SELF.instructionSet:=instructionSet;
		END SetInstructionSet;

		PROCEDURE &InitGeneratorTRM(CONST runtime: SyntaxTree.IdentifierString; diagnostics: Diagnostics.Diagnostics; b: BackendTRM; instructionSet: InstructionSet.InstructionSet);
		VAR physicalRegisters: PhysicalRegisters;
		BEGIN
			inStackAllocation := FALSE;
			SELF.runtimeModuleName := runtime;
			SELF.instructionSet:=instructionSet;
			backend := b;
			NEW(physicalRegisters,FALSE);
			InitTicketGenerator(diagnostics, backend.optimize,2,physicalRegisters);
			error := FALSE;
			pushChainLength := 0;
			instructionSet.InitImmediate(null, 0, 0);
			instructionSet.InitOperand(noOperand);
			instructionSet.InitRegister(opSP, InstructionSet.SP);
			instructionSet.InitRegister(opLR, InstructionSet.LR);
			instructionSet.InitRegister(opFP, InstructionSet.FP);

			dump := NIL;
			patchSpartan6 := FALSE;
			NEW(forwardFixups);
		END InitGeneratorTRM;

		PROCEDURE CheckStackPointer(CONST dest: InstructionSet.Operand);
		BEGIN
			IF stackSizeKnown & ~inStackAllocation THEN
				IF(dest.type = InstructionSet.Register) & (dest.register = InstructionSet.SP) THEN
					IF dump # NIL THEN
						dump.String("stack size unknown ") ;
					END;
					stackSizeKnown := FALSE;
				END;
			END;
		END CheckStackPointer;

		PROCEDURE PatchSpartan6;
		VAR i: LONGINT; opx: InstructionSet.Operand;
		BEGIN
			IF patchSpartan6 THEN
				IF (out.os.fixed) & ((out.os.alignment + out.pc) MOD 1024 = 959) THEN
					instructionSet.InitImmediate(opx,0,16);
					instructionSet.Emit(InstructionSet.opBT, opx, emptyOperand, out);
					FOR i := 1 TO 16 DO
						out.PutBits(0,18);
					END;
				END;
			END;
		END PatchSpartan6;

		PROCEDURE Emit(op: LONGINT; CONST op1, op2: InstructionSet.Operand);
		VAR pc: LONGINT;
		BEGIN
			pc := (out.os.alignment + out.pc);
			ASSERT(~patchSpartan6 OR ~out.os.fixed OR ((out.os.alignment + out.pc) MOD 1024 < 960) OR ((out.os.alignment + out.pc) MOD 1024 > 975) );
			
			instructionSet.Emit(op, op1, op2, out);
			(* do this AFTER each instruction because otherwise presumptions on the size of the PC in the generator are wrong *)
			(* note, in general, by the inclusion of the following code, no assumptions are true about the actual size of instructions in code emission
				--> forward jumps do have to be patched in all cases
			*)
			PatchSpartan6;
		END Emit;

		PROCEDURE Emit2(op: LONGINT; CONST op1, op2: InstructionSet.Operand);
		BEGIN
			CheckStackPointer(op1);
			Emit(op, op1, op2);
		END Emit2;

		PROCEDURE Emit2N(op: LONGINT; CONST op1: InstructionSet.Operand; n: LONGINT);
		VAR op2: InstructionSet.Operand;
		BEGIN
			CheckStackPointer(op1);
			instructionSet.InitImmediate(op2,0,n);
			Emit(op, op1, op2);;
		END Emit2N;

		PROCEDURE Emit1(op: LONGINT; CONST op1: InstructionSet.Operand);
		BEGIN
			Emit(op, op1, emptyOperand);
		END Emit1;

		PROCEDURE Emit1N(op: LONGINT; n: LONGINT);
		VAR op1: InstructionSet.Operand;
		BEGIN
			instructionSet.InitImmediate(op1,0,n);
			Emit(op, op1, emptyOperand);
		END Emit1N;

		(*------------------- overwritten methods ----------------------*)
		PROCEDURE Section(in: IntermediateCode.Section; out: BinaryCode.Section);
		VAR oldSpillStackSize: LONGINT;

			PROCEDURE CheckEmptySpillStack(): BOOLEAN;
			BEGIN
				IF spillStack.Size()#0 THEN Error(inPC,"implementation error, spill stack not cleared");
					IF dump # NIL THEN
						spillStack.Dump(dump);
						tickets.Dump(dump);
					END;
				RETURN FALSE ELSE RETURN TRUE END;
			END CheckEmptySpillStack;

		BEGIN
		
		 
		 	
			physicalRegisters(PhysicalRegisters).SupportFP(FPSupported);
			supportFP := FPSupported;
			tickets.Init;
			spillStack.Init;
			stackSizeKnown := TRUE;
			forwardFixups.Init;
			Section^(in,out);

			IF ~stackSizeKnown THEN
				supportFP := TRUE;
				tickets.Init;
				spillStack.Init;
				forwardFixups.Init;
				out.Reset;
				physicalRegisters(PhysicalRegisters).SupportFP(TRUE);
				Section^(in,out);
			END;

			IF CheckEmptySpillStack() & (spillStack.MaxSize() >0) THEN
				forwardFixups.Init;
				oldSpillStackSize := spillStack.MaxSize();
				out.Reset;
				Section^(in,out);
				ASSERT(spillStack.MaxSize() = oldSpillStackSize);
			END;
			IF CheckEmptySpillStack() THEN END;

		END Section;

		PROCEDURE Supported(CONST instr: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		VAR sizeInBits: LONGINT; form: LONGINT; opcode: LONGINT;
		BEGIN
			opcode := instr.opcode;
			form := instr.op1.type.form;
			COPY(runtimeModuleName, moduleName);
			IF opcode = IntermediateCode.conv THEN (* conversions between float and integer types in a library *)
				IF form = IntermediateCode.Float THEN
					IF instr.op2.type.form = IntermediateCode.Float THEN
						IF (instr.op1.type.sizeInBits = 32) & (instr.op2.type.sizeInBits = 64) THEN
							procedureName := "ConvertXR"; RETURN FALSE
						ELSIF (instr.op1.type.sizeInBits = 64) & (instr.op2.type.sizeInBits = 32) THEN
							procedureName := "ConvertRX"; RETURN FALSE
						ELSE HALT(100);
						END;
					ELSE
						ASSERT( instr.op2.type.form = IntermediateCode.SignedInteger);
						IF (instr.op2.type.sizeInBits = 32) THEN
							IF instr.op1.type.sizeInBits = 32 THEN
								procedureName := "ConvertIR"; RETURN FALSE
							ELSIF instr.op1.type.sizeInBits = 64 THEN
								procedureName := "ConvertHR"; RETURN FALSE
							ELSE HALT(100);
							END;
						ELSIF (instr.op2.type.sizeInBits=64) THEN
							IF instr.op1.type.sizeInBits = 32 THEN
								procedureName := "ConvertIX"; RETURN FALSE
							ELSIF instr.op1.type.sizeInBits = 64 THEN
								procedureName := "ConvertHX"; RETURN FALSE
							ELSE HALT(100);
							END;
						ELSE HALT(100);
						END
					END;
				ELSIF instr.op2.type.form = IntermediateCode.Float THEN
					ASSERT(instr.op1.type.form = IntermediateCode.SignedInteger);
					IF (instr.op2.type.sizeInBits = 32) THEN
						IF instr.op1.type.sizeInBits = 32 THEN
							procedureName := "ConvertRI"; RETURN FALSE
						ELSIF instr.op1.type.sizeInBits = 64 THEN
							procedureName := "ConvertRH"; RETURN FALSE
						ELSE HALT(100);
						END;
					ELSIF (instr.op2.type.sizeInBits=64) THEN
						IF instr.op1.type.sizeInBits = 32 THEN
							procedureName := "ConvertXI"; RETURN FALSE
						ELSIF instr.op1.type.sizeInBits = 64 THEN
							procedureName := "ConvertXH"; RETURN FALSE
						ELSE HALT(100);
						END;
					ELSE HALT(100);
					END
				END;
			ELSIF form IN IntermediateCode.Integer THEN
				IF instr.op1.type.sizeInBits = IntermediateCode.Bits64 THEN
					CASE instr.opcode OF
					IntermediateCode.div:	procedureName := "DivH"; RETURN FALSE
					| IntermediateCode.mod: procedureName := "ModH"; RETURN FALSE
					| IntermediateCode.abs: procedureName := "AbsH"; RETURN FALSE;
					| IntermediateCode.shl :
						IF instr.op1.type.form = IntermediateCode.SignedInteger THEN
							procedureName := "AslH"; RETURN FALSE;
						ELSE
							procedureName := "LslH"; RETURN FALSE;
						END;
					| IntermediateCode.shr :
						IF instr.op1.type.form = IntermediateCode.SignedInteger THEN
							procedureName := "AsrH"; RETURN FALSE;
						ELSE
							procedureName := "LsrH"; RETURN FALSE;
						END;
					| IntermediateCode.ror: procedureName := "RorH"; RETURN FALSE;
					| IntermediateCode.rol: procedureName := "RolH"; RETURN FALSE;
					ELSE RETURN TRUE
					END
				ELSIF instr.op1.type.sizeInBits = IntermediateCode.Bits32 THEN
					CASE instr.opcode OF
					IntermediateCode.div:	procedureName := "DivL"; RETURN FALSE
					| IntermediateCode.mod: procedureName := "ModL"; RETURN FALSE
					| IntermediateCode.mul:
						IF (Global.NoMulCapability IN backend.capabilities) THEN  (*mul forbidden*)
							procedureName:="MulL"; RETURN FALSE	
						ELSE
							RETURN TRUE;	
						END
					ELSE
					RETURN TRUE
					END;
				ELSE
					sizeInBits := instr.op1.type.sizeInBits;
					HALT(100)
				END;
			ELSIF (form = IntermediateCode.Float) THEN
				IF instr.op1.type.sizeInBits = IntermediateCode.Bits64 THEN
					CASE instr.opcode OF
						| IntermediateCode.add: procedureName := "AddX"; RETURN FALSE;
						| IntermediateCode.sub: procedureName := "SubX"; RETURN FALSE;
						| IntermediateCode.mul: procedureName := "MulX"; RETURN FALSE;
						| IntermediateCode.div: procedureName := "DivX"; RETURN FALSE
						| IntermediateCode.abs: procedureName := "AbsX"; RETURN FALSE;
					ELSE RETURN TRUE
					END;
				ELSIF instr.op1.type.sizeInBits = IntermediateCode.Bits32 THEN
					CASE instr.opcode OF
						| IntermediateCode.add:
							IF Global.FloatingPointCapability IN backend.capabilities THEN RETURN TRUE
							ELSE procedureName := "AddR"; RETURN FALSE
							END
						| IntermediateCode.sub:
							IF Global.FloatingPointCapability IN backend.capabilities THEN RETURN TRUE
							ELSE procedureName := "SubR"; RETURN FALSE
							END
						| IntermediateCode.mul:
							IF Global.FloatingPointCapability IN backend.capabilities THEN RETURN TRUE
							ELSE procedureName := "MulR"; RETURN FALSE
							END
						| IntermediateCode.div: procedureName := "DivR"; RETURN FALSE
						| IntermediateCode.abs: procedureName := "AbsR"; RETURN FALSE;
					ELSE RETURN TRUE
					END;
				ELSE HALT(100)
				END;
			ELSIF form = IntermediateCode.Undefined THEN
				RETURN TRUE
			ELSE HALT(100)
			END;
			RETURN TRUE
		END Supported;

		(* input: type (such as that of an intermediate operand), output: low and high type (such as in low and high type of an operand) *)
		PROCEDURE GetPartType(CONST type: IntermediateCode.Type; part: LONGINT; VAR typePart: IntermediateCode.Type);
		BEGIN
			ASSERT(type.sizeInBits >0); ASSERT(part < 2);
			IF (part = 0) OR (type.sizeInBits =64) THEN
				IntermediateCode.InitType(typePart,type.form,32);
			ELSE
				typePart := IntermediateCode.undef
			END;
		END GetPartType;

		PROCEDURE GetSpillOperand(ticket: Ticket; VAR mem: Operand);
		VAR offset: LONGINT; register: LONGINT;
		BEGIN
			
			D.String("spill stack used in "); Basic.WriteSegmentedName(D.Log, in.name); D.String(": "); D.Int(inPC,1); D.Ln;
			
			offset :=  spillStackPosition-ticket.offset; (* relative to logical frame pointer ! *)
			register := PhysicalRegister(IntermediateCode.FP,Low,offset);
			instructionSet.InitMemory(mem, register, offset);
		END GetSpillOperand;

		PROCEDURE ToSpillStack(ticket: Ticket);
		VAR mem, reg:Operand;
		BEGIN
			IF dump # NIL THEN dump.String("spill: "); CodeGenerators.DumpTicket(dump,ticket); dump.Ln; END;
			GetSpillOperand(ticket,mem);
			instructionSet.InitRegister(reg,ticket.register);
			Emit2(opST,reg,mem);
		END ToSpillStack;

		PROCEDURE AllocateSpillStack(size: LONGINT);
		BEGIN
		END AllocateSpillStack;

		PROCEDURE ToRegister(ticket: Ticket);
		VAR mem,reg: Operand;
		BEGIN
			IF dump # NIL THEN dump.String("unspill: "); CodeGenerators.DumpTicket(dump,ticket); dump.Ln END;
			GetSpillOperand(ticket,mem);
			instructionSet.InitRegister(reg,ticket.register);
			Emit2(opLD,reg,mem);
		END ToRegister;

		PROCEDURE ExchangeTickets(ticket1,ticket2: Ticket);
		VAR op1,op2,temp: Operand;
		BEGIN
			TicketToOperand(ticket1,op1);
			TicketToOperand(ticket2,op2);
			GetTemporaryRegister(temp);
			IF op1.type = InstructionSet.Register THEN
				ASSERT(op2.type = InstructionSet.Memory);
				Emit2(opMOV,temp,op1);
				Emit2(opLD,op1,op2);
				Emit2(opST,temp,op2);
			ELSE
				ASSERT(op2.type = InstructionSet.Register); ASSERT(op1.type = InstructionSet.Memory);
				Emit2(opMOV,temp,op2);
				Emit2(opLD,op2,op1);
				Emit2(opST,temp,op1);
			END;
			ReleaseHint(temp.register);
			(* spill stack not yet supported *)		
		END ExchangeTickets;

		PROCEDURE CheckFixups;
		VAR  fixup, forward, newFixup: BinaryCode.Fixup; fixupOp: InstructionSet.Operand; checkPC, iterCount: LONGINT;

			PROCEDURE CheckPC(): LONGINT;
			CONST safety=16; (* max number of TRM instructions to emit IR instruction *)
			BEGIN
				IF patchSpartan6 & out.os.fixed & ((out.pc+out.os.alignment) MOD 1024 < 960) & ((out.pc+out.os.alignment) MOD 1024 > 960-safety) THEN
					RETURN out.pc + safety + 16
				ELSE
					RETURN out.pc + safety (* assuming that an IR instruction can be emitted within at most 10 instructions *)
				END;
			END CheckPC;

		BEGIN
			fixup := forwardFixups.Check(CheckPC());
			iterCount:=0;
			WHILE(fixup # NIL) DO
				INC(iterCount);
				IF(iterCount>30) THEN
					D.String("too many iterations in forward fixup");D.Ln;
					HALT(100);
				END;
				(*problem: sometimes causes problems when there are large backwards jumps*)
				(*but is needed for long jumps in general*)
				(*!TODO: sometimes leads to infinite loop in instruction sizes <= 14*)
				(* sometimes, compiler continues to work fine without this section.*)
				(*apparently this section resolves the multihop jumps, but fails if it's supposed to go backward?*)
				IF fixup.symbolOffset < inPC THEN (* already resolved ok *)
				ELSE (* must be handled *)
					IF TraceFixups THEN
						D.String("relative branch fixup bits: ");D.Int(instructionSet.RelativeBranchFixupBits,1);
						D.String(" at inPC="); D.Int(inPC,1); D.String(", outPC="); D.Int(out.pc,1);
						D.String(", symbol offset=");D.Int(fixup.symbolOffset,1);
						D.String(", fixup from outPC = "); D.Int(fixup.offset,1); D.String(" to "); fixup.Dump(D.Log); D.String(" forwarded."); D.Ln;
					END;
					forward := BrForward(opBT);
					(*
					Emit1N(opBT, 1);
					*)
					newFixup := BinaryCode.NewFixup(fixup.mode, out.pc, fixup.symbol, fixup.symbolOffset, 0, 0, NIL);
					fixup.SetSymbol(fixup.symbol.name, fixup.symbol.fingerprint, 0, fixup.displacement+out.pc);
					ASSERT(ABS(out.pc - fixup.displacement) < 512);
					instructionSet.InitFixup(fixupOp,0,newFixup);
					forwardFixups.Enter(newFixup, out.pc, instructionSet.RelativeBranchFixupBits);
					Emit1(opBT, fixupOp);
					SetTarget(forward);
				END;  
				fixup := forwardFixups.Check(CheckPC());
			END;
		END CheckFixups;

		PROCEDURE IsComplex(CONST operand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN (operand.type.sizeInBits > 32)
		END IsComplex;

		PROCEDURE IsFloat(CONST operand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN operand.type.form = IntermediateCode.Float
		END IsFloat;

		PROCEDURE Generate(VAR instruction: IntermediateCode.Instruction);
		VAR opcode: SHORTINT; ticket: Ticket; hwreg, lastUse: LONGINT;
		BEGIN
			CheckFixups;

			(*
			IF ((instruction.opcode = IntermediateCode.mov) OR (instruction.opcode = IntermediateCode.pop)) & (instruction.op1.register <= IntermediateCode.ParameterRegister) THEN
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

			opcode := instruction.opcode;
			CASE opcode OF
			IntermediateCode.nop: (* do nothing *)
			|IntermediateCode.mov:
				EmitMov(instruction.op1,instruction.op2,Low);
				IF IsComplex(instruction.op1) THEN
					EmitMov(instruction.op1,instruction.op2,High)
				END;
			|IntermediateCode.conv: EmitConv(instruction);
			|IntermediateCode.call: EmitCall(instruction);
			|IntermediateCode.enter: EmitEnter(instruction);
			|IntermediateCode.leave: EmitLeave(instruction);
			|IntermediateCode.exit: EmitExit(instruction);
			|IntermediateCode.return:
				EmitReturn(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitReturn(instruction,High)
				END;
			|IntermediateCode.result:
				EmitResult(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitResult(instruction,High)
				END;
			|IntermediateCode.trap: EmitTrap(instruction);
			|IntermediateCode.br .. IntermediateCode.brlt: EmitBr(instruction)
			|IntermediateCode.pop:
				EmitPop(instruction.op1,Low);
				IF IsComplex(instruction.op1) THEN
					EmitPop(instruction.op1,High);
				END;
			|IntermediateCode.push:
				IF IsComplex(instruction.op1) THEN
					EmitPush(instruction.op1,High);
				END;
				EmitPush(instruction.op1,Low);
			|IntermediateCode.neg: EmitNeg(instruction);
			|IntermediateCode.not:
				EmitNot(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitNot(instruction,High)
				END;
			|IntermediateCode.abs: EmitAbs(instruction);
			|IntermediateCode.mul:
				IF IsFloat(instruction.op1) THEN
					EmitFMul(instruction)
				ELSE
					EmitMul(instruction)
				END
			|IntermediateCode.div: EmitDiv(instruction);
			|IntermediateCode.mod: EmitMod(instruction);
			|IntermediateCode.sub:
				IF IsFloat(instruction.op1) THEN
					EmitFSub(instruction)
				ELSE
					EmitSub(instruction)
				END
			|IntermediateCode.add:
				IF IsFloat(instruction.op1) THEN
					EmitFAdd(instruction)
				ELSE
					EmitAdd(instruction)
				END
			|IntermediateCode.and:
				EmitAnd(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitAnd(instruction,High);
				END;
			|IntermediateCode.or:
				EmitOr(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitOr(instruction,High)
				END;
			|IntermediateCode.xor:
				EmitXor(instruction,Low);
				IF IsComplex(instruction.op1) THEN
					EmitXor(instruction,High)
				END;
			|IntermediateCode.shl: EmitShift(instruction);
			|IntermediateCode.shr: EmitShift(instruction);
			|IntermediateCode.rol: EmitShift(instruction);
			|IntermediateCode.ror: EmitShift(instruction);
			|IntermediateCode.copy: EmitCopy(instruction);
			|IntermediateCode.fill: EmitFill(instruction, FALSE);
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


		PROCEDURE TicketToOperand(ticket:Ticket; VAR op: InstructionSet.Operand);
		BEGIN
			ASSERT(ticket # NIL);
			IF ticket.spilled THEN
				GetSpillOperand(ticket,op);
			ELSE
				instructionSet.InitRegister(op,ticket.register)
			END;
		END TicketToOperand;

		(* updateStackSize is important as intermediate RETURNS should not change stack size *)
		PROCEDURE AllocateStack(size: LONGINT; updateStackSize: BOOLEAN);
		VAR  sizeOperand: InstructionSet.Operand;
		BEGIN
			inStackAllocation := TRUE;
			IF size > 0 THEN
				IF size < ASH(1,instructionSet.ImmediateFixupBits) THEN
					instructionSet.InitImmediate(sizeOperand, 0, size)
				ELSE
					ImmediateToOperand(size,Low,FALSE,instructionSet.ImmediateFixupBits,sizeOperand)
				END;
				Emit2(opSUB, opSP, sizeOperand);
				IF updateStackSize THEN INC(stackSize, size) END;
			ELSIF size < 0 THEN
				size := -size;
				IF size < ASH(1,instructionSet.ImmediateFixupBits) THEN
					instructionSet.InitImmediate(sizeOperand, 0, size);
				ELSE
					ImmediateToOperand(size,Low, FALSE, instructionSet.ImmediateFixupBits,sizeOperand);
				END;
				Emit2(opADD, opSP, sizeOperand);
				IF updateStackSize THEN DEC(stackSize, size) END;
			END;
			inStackAllocation := FALSE;
		END AllocateStack;

		PROCEDURE EmitEnter(CONST instr: IntermediateCode.Instruction);
		VAR cc: LONGINT; mem: InstructionSet.Operand;
		BEGIN
			stackSize := 0;
			(*
				stack layout:
				p1
				...
				pm	 													(parameters pushed by caller)
				LR   													(explicitly pushed by frontend because hasLinkRegister = TRUE)
				prev FP <-- FP = logicalFP 	(explicitly pushed by frontend)
				v1
				...
				vn
				spill1	<- logicalFP + spillStackPosition (negative)
				...
				spilln <-- SP
			*)
			cc := SHORT(instr.op1.intValue);
			spillStackPosition := - LONGINT(instr.op2.intValue)-1; (* relative to logical frame pointer ! *)
			AllocateStack(LONGINT(instr.op2.intValue+spillStack.MaxSize()), TRUE);
		END EmitEnter;

		PROCEDURE EmitLeave(CONST instr: IntermediateCode.Instruction);
		VAR cc: LONGINT; mem: InstructionSet.Operand;
		BEGIN
			IF ~supportFP THEN (* frame pointer might have been used *)
				AllocateStack(-stackSize, FALSE);
				Emit2(opMOV, opFP, opSP);
			END;
		END EmitLeave;

		PROCEDURE EmitExit(CONST instr: IntermediateCode.Instruction);
		VAR cc: LONGINT; mem: InstructionSet.Operand;
		BEGIN
			instructionSet.InitMemory(mem, InstructionSet.SP, 0);
			Emit2(opLD, opLR, mem);
			AllocateStack(-1,FALSE);
			Emit1(opBR, opLR);
		END EmitExit;

		PROCEDURE ResultRegister(part: LONGINT): InstructionSet.Operand;
		VAR register: InstructionSet.Operand;
		BEGIN
			IF part = Low THEN instructionSet.InitRegister(register,0)
			ELSE instructionSet.InitRegister(register,1)
			END;
			RETURN register
		END ResultRegister;

		PROCEDURE EmitResult(VAR instr: IntermediateCode.Instruction; part: LONGINT);
		VAR op,result: Operand;
		BEGIN
			AcquireDestinationRegister(instr.op1, part,op);
			result := ResultRegister(part);
			MovIfDifferent(op, result);
			ReleaseDestinationRegister(instr.op1,part,op);
		END EmitResult;

		PROCEDURE EmitReturn(VAR instr: IntermediateCode.Instruction; part: LONGINT);
		VAR op,result: Operand;
		BEGIN
			MakeRegister(instr.op1,part,op);
			result := ResultRegister(part);
			MovIfDifferent(result, op);
		END EmitReturn;

		PROCEDURE EmitMov(VAR vop1,vop2: IntermediateCode.Operand; part: LONGINT);
		VAR left,right: Operand; rightTicket: Ticket; neg: BOOLEAN;
		BEGIN
			rightTicket := NIL;
			IF vop2.mode = IntermediateCode.ModeMemory THEN
				(*GetMemory(vop2,part,right,rightTicket);*) (* done in load *)
			ELSIF ~UnsignedImmediate(vop2,part,instructionSet.ImmediateFixupBits,FALSE,neg,right) THEN
				MakeRegister(vop2,part,right);
				ReleaseHint(right.register);
			END;
			AcquireDestinationRegister(vop1,part,left);
			IF vop2.mode = IntermediateCode.ModeMemory THEN
				Load(vop2,part,left);
			ELSE
				MovIfDifferent(left, right);
			END;
			IF vop1.mode = IntermediateCode.ModeMemory THEN
				Store(vop1,part,left);
			END;
			ReleaseHint(left.register);
		END EmitMov;

		PROCEDURE EmitConv(VAR instr: IntermediateCode.Instruction);
		VAR left,right,temp: Operand;
			srcSize, destSize: LONGINT;
		BEGIN
			srcSize := instr.op2.type.sizeInBits;
			destSize := instr.op1.type.sizeInBits;

			ASSERT( (srcSize = 32) OR (srcSize = 64));
			ASSERT( (destSize = 32) OR (destSize = 64));
			ASSERT(instr.op1.type.form IN IntermediateCode.Integer);
			ASSERT(instr.op2.type.form IN IntermediateCode.Integer);

			IF srcSize >= destSize THEN
				MakeRegister(instr.op2,Low,right);
				ReleaseHint(right.register);
				AcquireDestinationRegister(instr.op1,Low,left);
				MovIfDifferent(left, right);
				ReleaseDestinationRegister(instr.op1,Low, left);
			ELSE
				MakeRegister(instr.op2, Low, right);
				ReleaseHint(right.register);
				AcquireDestinationRegister(instr.op1,Low,left);
				MovIfDifferent(left,right);
				ReleaseDestinationRegister(instr.op1,Low,left);

				IF (instr.op2.type.form = IntermediateCode.SignedInteger) & (instr.op1.type.form = IntermediateCode.SignedInteger) THEN
					GetTemporaryRegister(temp);
					Emit2(opMOV, temp,left);
					AcquireDestinationRegister(instr.op1,High,left);
					Emit2(opMOV, left, temp);
					Emit2N(opROR, temp, 31);
					Emit2N(opAND, temp, 1);
					Emit2(opNOT, left, temp);
					Emit2N(opADD, left, 1);
				ELSE
					AcquireDestinationRegister(instr.op1,High,left);
					Emit2N(opMOV, left, 0);
				END;
				ReleaseDestinationRegister(instr.op1,High,left);
			END;

		END EmitConv;

		PROCEDURE Resolve(VAR op: IntermediateCode.Operand);
		BEGIN
			IF (op.symbol.name # "") & (op.resolved = NIL) THEN
				op.resolved := module.allSections.FindByName(op.symbol.name)
			END;
		END Resolve;


		PROCEDURE EmitCall(VAR instruction: IntermediateCode.Instruction);
		VAR op: InstructionSet.Operand; section: IntermediateCode.Section; code: BinaryCode.Section; symbol: ObjectFile.Identifier;
			fixup, newFixup: BinaryCode.Fixup; pc: LONGINT; regOp: Operand; offset,reloffset: LONGINT;
		BEGIN
			IF (instruction.op1.symbol.name # "") & (instruction.op1.mode # IntermediateCode.ModeMemory) THEN
				Resolve(instruction.op1);
				IF instruction.op1.resolved # NIL THEN
					section :=  instruction.op1.resolved(IntermediateCode.Section);
				END;
				IF (section # NIL) & (section.type = Sections.InlineCodeSection) THEN
					code := section.resolved;
					ASSERT(code # NIL);
					out.CopyBits(code.os.bits, 0, code.os.bits.GetSize());
					fixup := code.fixupList.firstFixup;
					pc := code.pc;
					WHILE (fixup # NIL) DO
						newFixup := BinaryCode.NewFixup(fixup.mode, fixup.offset+pc, fixup.symbol, fixup.symbolOffset, fixup.displacement, fixup.scale, fixup.pattern);
						out.fixupList.AddFixup(newFixup);
						fixup := fixup.nextFixup;
					END;
				ELSE
					IF out.os.fixed THEN (* only if my own address is already known .. *)
						offset := GetSymbolOffset(instruction.op1, symbol);
					ELSE
						offset := instruction.op1.offset;
						Resolve(instruction.op1);
						symbol := instruction.op1.symbol;
					END;
					reloffset := offset - out.pc-out.os.alignment-1;
					IF symbol.name # "" THEN
						fixup := BinaryCode.NewFixup(BinaryCode.Relative,out.pc,symbol, offset, 0, 0, NIL);
						instructionSet.InitFixup(op, 32, fixup);
						Emit1(opBL, op);
					ELSIF (-ASH(1,instructionSet.BranchAndLinkFixupBits-1) <= reloffset) & (reloffset < ASH(1,instructionSet.BranchAndLinkFixupBits-1)) THEN
						ImmediateToOperand(reloffset, Low, TRUE, instructionSet.BranchAndLinkFixupBits,op);
						ASSERT(op.type = InstructionSet.Immediate);
						Emit1(opBL, op);
					ELSE
						GetTemporaryRegister(op);
						ImmediateToOperand(offset, Low, FALSE, instructionSet.ImmediateFixupBits,op);
						ASSERT(op.type = InstructionSet.Register);
						Emit2(opBLR, opLR, op);
					END;
				END;
			ELSE
				MakeRegister(instruction.op1,Low,regOp);
				Emit2(opBLR, opLR, regOp);
			END;
			AllocateStack(-SHORT(instruction.op2.intValue), TRUE)
		END EmitCall;

		PROCEDURE GetImmediate32(val: LONGINT; CONST reg: InstructionSet.Operand; emit: BOOLEAN): LONGINT;
		VAR ops: LONGINT; set: SET;

			PROCEDURE Add(val,pos: LONGINT; VAR first: BOOLEAN): LONGINT;
			VAR imm: InstructionSet.Operand; ops: LONGINT; op: InstructionSet.Operand;
			BEGIN
				instructionSet.InitImmediate(imm, 0, val);
				IF pos # 0 THEN
					IF first THEN
						ops := 2;
						IF emit THEN
							Emit2(opMOV, reg, imm);
							instructionSet.InitImmediate(imm, 0, 32-pos);  (*!TODO: if instruction width is <=13, immediate for ror is so small it can't express this number!*)
							Emit2(opROR, reg, imm);
						END;
					ELSE
						ops := 3;
						IF emit THEN
							GetTemporaryRegister(op);
							Emit2(opMOV, op, imm);
							instructionSet.InitImmediate(imm, 0, 32-pos);
							Emit2(opROR, op, imm);
							Emit2(opADD, reg, op);
							ReleaseHint(op.register);
						END;
					END;
				ELSE
					ops := 1;
					IF emit THEN Emit2(opADD, reg, imm) END;
				END;
				first := FALSE;
				RETURN ops
			END Add;

			PROCEDURE Compute(val: SET): LONGINT;
			VAR v,i: LONGINT; ops: LONGINT; first: BOOLEAN;
			BEGIN
				v := 0; ops := 0; first := TRUE;
				FOR i := 31 TO 0 BY -1 DO
					v := v * 2;
					IF i IN val THEN INC(v) END;
					IF v*2 >= ASH(1,instructionSet.ImmediateFixupBits) THEN
						ops := ops + Add(v,i,first);
						v := 0;
					END;
				END;
				IF v # 0 THEN ops := ops + Add(v,0,first) END;
				RETURN ops
			END Compute;

		BEGIN
			set := SYSTEM.VAL(SET,val);
			ops := Compute(set);
			RETURN ops
		END GetImmediate32;

		PROCEDURE ImmediateToOperand(imm: HUGEINT; part: LONGINT; signed: BOOLEAN; bits: LONGINT; VAR op: Operand);
		VAR immOp: InstructionSet.Operand; maxImmValue, minImmValue : LONGINT;

			PROCEDURE ImmediateToOp32(imm: LONGINT; VAR op: InstructionSet.Operand);
			VAR ops: LONGINT;
			BEGIN
				IF (imm>=0) & (imm < ASH(1,instructionSet.ImmediateFixupBits)) THEN
					instructionSet.InitImmediate(immOp, 0, imm);
					Emit2(opMOV, op, immOp);
				ELSIF (imm <0) & (imm > MIN(LONGINT)) & (ABS(imm) < ASH(1,instructionSet.ImmediateFixupBits)) THEN
					instructionSet.InitImmediate(immOp, 0, 0);
					Emit2(opMOV, op, immOp);
					instructionSet.InitImmediate(immOp, 0, ABS(imm));
					Emit2(opSUB, op, immOp);
				ELSE
					ops := GetImmediate32(imm, op, TRUE);
				END;
			END ImmediateToOp32;

		BEGIN
			IF signed THEN
				minImmValue := -ASH(1,bits-1); maxImmValue := ASH(1,bits-1)-1;
			ELSE
				minImmValue := 0; maxImmValue := ASH(1,bits)-1
			END;
			IF (op.type # InstructionSet.Register) & (imm >=minImmValue) & (imm <=maxImmValue) THEN (* immediate operand *)
				IF part = Low THEN
					instructionSet.InitImmediate(op,0,SHORT(imm));
				ELSE
					instructionSet.InitImmediate(op,0,0);
				END;
			ELSE
				IF op.type # InstructionSet.Register THEN
					GetTemporaryRegister(op);
				END;
				IF part = Low THEN
					ImmediateToOp32(SHORT(imm), op)
				ELSE
					ImmediateToOp32(SHORT(imm DIV 10000H DIV 10000H),op);
				END
			END;
		END ImmediateToOperand;

		PROCEDURE MakeRegister(VAR vop: IntermediateCode.Operand; part: LONGINT; VAR rop: Operand);
		VAR virtualReg: LONGINT; tmp, imm: Operand; offset: LONGINT; symbol: ObjectFile.Identifier;
			sizeInBits: LONGINT;
		BEGIN
			(*InstructionSet.InitOperand(rop); *)
			instructionSet.InitOperand(imm);
			sizeInBits := vop.type.sizeInBits;
			virtualReg := vop.register;

			offset := GetSymbolOffset(vop,symbol);
			CASE vop.mode OF
			IntermediateCode.ModeMemory:
				GetTemporaryRegister(rop);
				Load(vop,part,rop);
			|IntermediateCode.ModeRegister:
				GetRegister(vop,part,rop);
			|IntermediateCode.ModeImmediate:
				IF symbol.name # "" THEN
					instructionSet.InitFixup(tmp, 14, BinaryCode.NewFixup(BinaryCode.Absolute,out.pc,vop.symbol, vop.symbolOffset, vop.offset,0,NIL));
					GetTemporaryRegister(rop);
					Emit2(opMOV, rop, tmp);
				ELSE
					IF vop.type.form IN IntermediateCode.Integer THEN
					ASSERT ((vop.intValue = 0) OR (offset = 0));
						ImmediateToOperand(vop.intValue+offset, part, FALSE, instructionSet.ImmediateFixupBits,rop);
					ELSE ASSERT(vop.type.form = IntermediateCode.Float); ASSERT(vop.type.sizeInBits=32);
						ImmediateToOperand(BinaryCode.ConvertReal(SHORT(vop.floatValue)),part,FALSE,instructionSet.ImmediateFixupBits,rop);
					END;

					IF rop.type # InstructionSet.Register THEN
						GetTemporaryRegister(tmp);
						Emit2(opMOV, tmp, rop);
						rop := tmp
					END;
				END;
			ELSE HALT(200)
			END;
		END MakeRegister;

		(* if the symbol has a statically known offset then return offset and set resulting section to nil, otherwise do not set resulting section to nil *)
		PROCEDURE GetSymbolOffset(VAR vop: IntermediateCode.Operand; VAR sectionName: ObjectFile.Identifier): LONGINT;
		VAR offset: LONGINT; section: Sections.Section;
		BEGIN
			sectionName := vop.symbol;
			Resolve(vop);
			section := vop.resolved; offset := vop.offset;
			IF (section # NIL) & (section(IntermediateCode.Section).resolved # NIL) & (section(IntermediateCode.Section).resolved.os.fixed) THEN
				INC(offset, section(IntermediateCode.Section).resolved.os.alignment);
				INC(offset, section(IntermediateCode.Section).instructions[vop.symbolOffset].pc);
				sectionName.name := "";
			END;
			RETURN offset
		END GetSymbolOffset;

		PROCEDURE GetMemory(VAR vop: IntermediateCode.Operand; part: LONGINT; VAR memoryOperand: InstructionSet.Operand; ticket: Ticket);
		VAR virtualReg: LONGINT; register: LONGINT; registerOperand, temporary: InstructionSet.Operand; symbol: ObjectFile.Identifier;
			offset: LONGINT;
		BEGIN
			virtualReg := vop.register;
			ASSERT(vop.mode = IntermediateCode.ModeMemory);
			offset := GetSymbolOffset(vop, symbol) + part;
			register := PhysicalRegister(vop.register,Low,offset);

			IF register = None THEN
				IF symbol.name = "" THEN
					offset := offset + SHORT(vop.intValue);
				END;
				register := InstructionSet.None;
			END;

			IF (0<=offset) & (offset < ASH(1,instructionSet.MemoryOffsetFixupBits)) THEN
				instructionSet.InitMemory(memoryOperand, register, offset);
			ELSE
				IF ticket = NIL THEN
					ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
				END;
				TicketToOperand(ticket, temporary);
				ImmediateToOperand(offset, Low, FALSE, instructionSet.ImmediateFixupBits,temporary);
				instructionSet.InitRegister(registerOperand,register);
				IF register # InstructionSet.None THEN
					Emit2(opADD,temporary,registerOperand);
				END;
				instructionSet.InitMemory(memoryOperand, temporary.register, 0);
			END;
			IF symbol.name # "" THEN
				instructionSet.AddFixup(memoryOperand, BinaryCode.NewFixup(BinaryCode.Absolute, 0, symbol, vop.symbolOffset, offset, 0, NIL));
			END;
		END GetMemory;

		PROCEDURE Load(VAR vop: IntermediateCode.Operand; part: LONGINT; CONST register: Operand);
		VAR memoryOperand: Operand;
		BEGIN
			ASSERT(register.type = InstructionSet.Register);
			GetMemory(vop,part,memoryOperand,physicalRegisters.Mapped(register.register));
			Emit2(opLD,register,memoryOperand);
		END Load;

		PROCEDURE Store(VAR vop: IntermediateCode.Operand; part: LONGINT; CONST register: Operand);
		VAR memoryOperand: Operand;
		BEGIN
			GetMemory(vop,part,memoryOperand,NIL);
			Emit2(opST,register,memoryOperand);
		END Store;

		PROCEDURE UnsignedImmediate(vop: IntermediateCode.Operand; part: LONGINT; bits: LONGINT; allowNegation: BOOLEAN; VAR neg: BOOLEAN; VAR rop: Operand): BOOLEAN;
		VAR value,offset : LONGINT; symbol: ObjectFile.Identifier;
		BEGIN
			IF (vop.mode = IntermediateCode.ModeImmediate) THEN
				offset := GetSymbolOffset(vop, symbol);
				IF part = Low THEN
					value := SHORT(vop.intValue + offset);
				ELSE
					value := SHORT((vop.intValue + offset) DIV 1000H DIV 1000H);
				END;
				IF symbol.name # "" THEN RETURN FALSE
				ELSIF vop.type.form = IntermediateCode.Float THEN RETURN FALSE
				ELSIF (value >= 0) & (value < ASH(1,bits)) THEN
					instructionSet.InitImmediate(rop, 0, value); neg := FALSE;
					RETURN TRUE
				ELSIF allowNegation & (value <0) & (value # MIN(LONGINT)) & (-value < ASH(1,bits)) THEN
					instructionSet.InitImmediate(rop, 0, -value); neg := TRUE;
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END UnsignedImmediate;


		PROCEDURE HardwareIntegerRegister(index: LONGINT; sizeInBits: LONGINT): LONGINT;
		BEGIN 	RETURN index
		END HardwareIntegerRegister;

		PROCEDURE HardwareFloatRegister(index: LONGINT; sizeInBits: LONGINT): LONGINT;
		BEGIN RETURN index
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
		BEGIN
			RETURN GetTypedHardwareRegister(index, type)
		END ParameterRegister;

		PROCEDURE PhysicalRegister(virtualReg: LONGINT; part: LONGINT; VAR offset: LONGINT): LONGINT;
		VAR register: LONGINT; fpOffset: LONGINT; ticket: Ticket;
		BEGIN
			IF virtualReg = IntermediateCode.FP THEN
				IF stackSizeKnown THEN
					register := InstructionSet.SP;
					INC(offset, stackSize);
				ELSE (* stack size unknown, actually fp must be supported *)
					register := InstructionSet.FP;
				END;
			ELSIF virtualReg = IntermediateCode.SP THEN
				register := InstructionSet.SP;
			ELSIF virtualReg = IntermediateCode.LR THEN
				register := InstructionSet.LR;
			(*!ELSIF virtualReg <= IntermediateCode.ParameterRegister THEN
				register := ParameterRegister(IntermediateCode.ParameterRegister-virtualReg, IntermediateCode.int32);
			*)
			ELSE
				ticket := virtualRegisters.Mapped(virtualReg,part);
				IF ticket = NIL THEN register := None
				ELSE
					UnSpill(ticket);
					register := ticket.register
				END;
			END;
			RETURN register
		END PhysicalRegister;

		PROCEDURE GetRegister(CONST virtual: IntermediateCode.Operand; part:LONGINT; VAR physical: Operand);
		VAR type: IntermediateCode.Type; virtualRegister, physicalRegister: LONGINT;
			tmp,imm: Operand; offset: LONGINT; ticket: Ticket; ops: LONGINT;
		BEGIN
			ASSERT(virtual.mode = IntermediateCode.ModeRegister);
			GetPartType(virtual.type,part,type);

			virtualRegister := virtual.register;

			offset := virtual.offset;
			physicalRegister := PhysicalRegister(virtual.register,part,offset);
			instructionSet.InitRegister(physical, physicalRegister);

			IF offset # 0 THEN
				(*
				offset := virtual.offset;
				*)
				Assert(type.form # IntermediateCode.Float,"forbidden offset on float");
				ReleaseHint(physical.register);
				GetTemporaryRegister(tmp);
				MovIfDifferent(tmp, physical);
				physical := tmp;


				IF (offset >= 0) & (offset < ASH(1,instructionSet.ImmediateFixupBits)) THEN
					instructionSet.InitImmediate(imm, 0, offset);
					Emit2(opADD,physical,imm);
				ELSIF  (offset <0) & (-offset < ASH(1,instructionSet.ImmediateFixupBits)) THEN
					instructionSet.InitImmediate(imm, 0, -offset);
					Emit2(opSUB,physical,imm);
				ELSE
					GetTemporaryRegister(tmp);
					ops := GetImmediate32(offset,tmp,TRUE);
					Emit2(opADD,physical,tmp);
					ReleaseHint(tmp.register);
				END;
			END;
		END GetRegister;

		PROCEDURE IsSameRegister(CONST a, b : InstructionSet.Operand) : BOOLEAN;
		BEGIN
			IF (a.fixup # NIL) OR (b.fixup # NIL) OR (a.type # InstructionSet.Register) OR (b.type # InstructionSet.Register) THEN RETURN FALSE END;
			RETURN a.register = b.register;
		END IsSameRegister;

		PROCEDURE MovIfDifferent(CONST a,b: InstructionSet.Operand);
		BEGIN
			IF ~IsSameRegister(a,b) THEN Emit2(opMOV, a, b) END;
		END MovIfDifferent;


		PROCEDURE AcquireDestinationRegister(CONST vop: IntermediateCode.Operand; part: LONGINT; VAR op: Operand);
		VAR  type: IntermediateCode.Type;
		BEGIN
			GetPartType(vop.type,part,type);
			IF vop.mode = IntermediateCode.ModeMemory THEN
				GetTemporaryRegister(op);
			ELSE
				IF virtualRegisters.Mapped(vop.register,part)=NIL THEN
					TryAllocate(vop,part);
				END;
				GetRegister(vop,part,op);
			END;
		END AcquireDestinationRegister;

		PROCEDURE PrepareOp3(CONST instruction: IntermediateCode.Instruction;part: LONGINT; allowNegation: BOOLEAN; VAR negate: BOOLEAN; VAR dest, left, right: Assembler.Operand);
		VAR vop1,vop2, vop3: IntermediateCode.Operand; op2: InstructionSet.Operand;
			opx: Operand;
		BEGIN
			vop1 := instruction.op1; vop2 := instruction.op2; vop3 := instruction.op3;
			IF (IntermediateCode.Commute23 IN IntermediateCode.instructionFormat[instruction.opcode].flags)  THEN
				IF IntermediateCode.OperandEquals(vop1,vop3)  OR UnsignedImmediate(vop2,part,instructionSet.ImmediateFixupBits,FALSE,negate,right) THEN
					vop3 := instruction.op2; vop2 := instruction.op3;
				END;
			END;
			IF ~UnsignedImmediate(vop3, part, instructionSet.ImmediateFixupBits, allowNegation, negate,right) THEN
				instructionSet.InitOperand(right);
				MakeRegister(vop3,part,right);
			END;
			MakeRegister(vop2,part,op2);
			ReleaseHint(op2.register);
			AcquireDestinationRegister(vop1,part,left);
			dest := left;
			IF ~IsSameRegister(left,op2) THEN
				IF IsSameRegister(left,right) THEN
					GetTemporaryRegister(opx);
					MovIfDifferent(opx, op2);
					dest := left;
					left := opx;
				ELSE
					MovIfDifferent(left, op2);
				END;
			END;
		END PrepareOp3;


		PROCEDURE PrepareFOp3(CONST instruction: IntermediateCode.Instruction; VAR dest, left, right: Assembler.Operand);
		VAR vop1,vop2, vop3: IntermediateCode.Operand; op2: InstructionSet.Operand;
			opx: Operand;
		BEGIN
			vop1 := instruction.op1; vop2 := instruction.op2; vop3 := instruction.op3;
			instructionSet.InitOperand(right);
			MakeRegister(vop3,Low,right);
			MakeRegister(vop2,Low,op2);
			ReleaseHint(op2.register);
			AcquireDestinationRegister(vop1,Low,left);
			dest := left;
			IF ~IsSameRegister(left,op2) THEN
				IF IsSameRegister(left,right) THEN
					GetTemporaryRegister(opx);
					MovIfDifferent(opx, op2);
					dest := left;
					left := opx;
				ELSE
					MovIfDifferent(left, op2);
				END;
			END;
		END PrepareFOp3;

		PROCEDURE PrepareOp2(CONST instruction: IntermediateCode.Instruction;part: LONGINT; allowNegation: BOOLEAN; VAR negate: BOOLEAN; VAR left, right: Assembler.Operand);
		VAR vop1,vop2: IntermediateCode.Operand;
		BEGIN
			vop1 := instruction.op1; vop2 := instruction.op2;
			IF ~UnsignedImmediate(vop2, part, instructionSet.ImmediateFixupBits, allowNegation, negate,right) THEN
				instructionSet.InitOperand(right);
				MakeRegister(vop2,part,right);
			END;
			ReleaseHint(right.register);
			AcquireDestinationRegister(vop1,part,left);
		END PrepareOp2;

		PROCEDURE ReleaseDestinationRegister(VAR vop: IntermediateCode.Operand; part: LONGINT; left: Assembler.Operand);
		BEGIN
			IF vop.mode = IntermediateCode.ModeMemory THEN
				ASSERT(left.type = InstructionSet.Register);
				Store(vop,part,left);
				ReleaseHint(left.register);
			END;
		END ReleaseDestinationRegister;

		PROCEDURE FinishOp(VAR vop: IntermediateCode.Operand; part: LONGINT; dest, left: Assembler.Operand);
		VAR op: Operand;
		BEGIN
			IF vop.mode = IntermediateCode.ModeMemory THEN
				ASSERT(left.type = InstructionSet.Register);
				Store(vop,part,left);
				ReleaseHint(left.register);
			ELSIF dest.register # left.register THEN
				Emit2(opMOV, dest, left);
			END;
		END FinishOp;

		PROCEDURE EmitAdd(VAR instruction: IntermediateCode.Instruction);
		VAR destLow, destHigh, leftLow,rightLow,leftHigh,rightHigh: InstructionSet.Operand;negateLow,negateHigh: BOOLEAN;
			fixup: BinaryCode.Fixup;
		BEGIN
			PrepareOp3(instruction,Low,TRUE,negateLow,destLow, leftLow,rightLow);
			IF IsComplex(instruction.op1) THEN
				PrepareOp3(instruction,High,TRUE,negateHigh,destHigh, leftHigh,rightHigh);
			END;
			IF negateLow THEN Emit2(opSUB,leftLow,rightLow) ELSE Emit2(opADD,leftLow,rightLow) END;
			FinishOp(instruction.op1,Low,destLow, leftLow);
			IF IsComplex(instruction.op1) THEN
				fixup := BrForward(opBB);
				(*
				Emit1N(opBB, 1);
				*)
				Emit2N(opADD, leftHigh, 1);
				SetTarget(fixup);
				IF negateHigh THEN Emit2(opSUB,leftHigh,rightHigh) ELSE Emit2(opADD,leftHigh,rightHigh) END;
				FinishOp(instruction.op1,High,destHigh, leftHigh);
			END;
		END EmitAdd;

		PROCEDURE EmitFAdd(VAR instruction: IntermediateCode.Instruction);
		VAR destLow, destHigh, leftLow, rightLow, leftHigh, rightHigh: Operand; negateLow, negateHigh: BOOLEAN;
		BEGIN
			PrepareFOp3(instruction,destLow, leftLow,rightLow);
			Emit2(opFADD,leftLow,rightLow);
			FinishOp(instruction.op1,Low,destLow, leftLow);
		END EmitFAdd;


		PROCEDURE EmitSub(VAR instruction: IntermediateCode.Instruction);
		VAR destLow, destHigh, leftLow, rightLow, leftHigh, rightHigh: Operand; negateLow, negateHigh: BOOLEAN; fixup: BinaryCode.Fixup;
		BEGIN
			IF (instruction.op1.mode = IntermediateCode.ModeRegister) & (instruction.op1.register = IntermediateCode.SP) &
				(instruction.op2.mode = IntermediateCode.ModeRegister) & (instruction.op2.register = IntermediateCode.SP) &
				(instruction.op3.mode = IntermediateCode.ModeImmediate) & (instruction.op3.symbol.name = "") THEN
					AllocateStack(SHORT(instruction.op3.intValue), TRUE); RETURN
			END;

			PrepareOp3(instruction,Low,TRUE,negateLow, destLow, leftLow,rightLow);
			IF IsComplex(instruction.op1) THEN
				PrepareOp3(instruction,High,TRUE,negateHigh,destHigh, leftHigh,rightHigh);
				IF negateHigh THEN Emit2(opADD,leftHigh,rightHigh) ELSE Emit2(opSUB,leftHigh,rightHigh) END;
			END;
			IF negateLow THEN Emit2(opADD,leftLow,rightLow) ELSE Emit2(opSUB,leftLow,rightLow) END;
			FinishOp(instruction.op1,Low,destLow, leftLow);
			IF IsComplex(instruction.op1) THEN
				fixup := BrForward(opBAE);
				(*
				Emit1N(opBAE, 1);
				*)
				Emit2N(opSUB,leftHigh, 1);
				SetTarget(fixup);
				FinishOp(instruction.op1,High,destHigh, leftHigh)
			END;
		END EmitSub;

		PROCEDURE EmitFSub(VAR instruction: IntermediateCode.Instruction);
		VAR destLow, destHigh, leftLow, rightLow, leftHigh, rightHigh: Operand; negateLow, negateHigh: BOOLEAN;
		BEGIN
			PrepareFOp3(instruction,destLow, leftLow,rightLow);
			Emit2(opFSUB,leftLow,rightLow);
			FinishOp(instruction.op1,Low,destLow, leftLow);
		END EmitFSub;


		PROCEDURE EmitMul(VAR instruction: IntermediateCode.Instruction);
		VAR negate: BOOLEAN;
			op1Low, op2Low, op3Low, op1High, op2High, op3High, destLow, destHigh: Operand;
		BEGIN
			IF ~IsComplex(instruction.op1) THEN
				PrepareOp3(instruction,Low,FALSE,negate,destLow, op1Low,op2Low);
				Emit2(opMUL,op1Low,op2Low);
				FinishOp(instruction.op1,Low,destLow, op1Low)
			ELSE
				AcquireDestinationRegister(instruction.op1,Low,op1Low);
				AcquireDestinationRegister(instruction.op1,High,op1High);
				MakeRegister(instruction.op2,Low,op2Low);
				MakeRegister(instruction.op2,High,op2High);
				MakeRegister(instruction.op3,Low,op3Low);
				MakeRegister(instruction.op3,High,op3High);

				Emit2(opMOV, op1Low, op2Low);
				Emit2(opMUL, op1Low, op3Low);
				Emit1(opLDH, op1High);
				Emit2(opMUL, op2High, op3Low);
				Emit2(opADD, op1High, op2High);
				Emit2(opMUL, op2Low, op3High);
				Emit2(opADD, op1High, op2Low);

				ReleaseDestinationRegister(instruction.op1,Low,op1Low);
				ReleaseDestinationRegister(instruction.op1,High,op1High);
			END;
		END EmitMul;

		PROCEDURE EmitFMul(VAR instruction: IntermediateCode.Instruction);
		VAR destLow, destHigh, leftLow, rightLow, leftHigh, rightHigh: Operand; negateLow, negateHigh: BOOLEAN;
		BEGIN
			PrepareFOp3(instruction,destLow, leftLow,rightLow);
			Emit2(opFMUL,leftLow,rightLow);
			FinishOp(instruction.op1,Low,destLow, leftLow);
		END EmitFMul;

		PROCEDURE EmitDiv(CONST instr: IntermediateCode.Instruction);
		BEGIN
			HALT(100); (*! div is not supported by hardware, must be runtime call -- cf. method Supported *)
		END EmitDiv;

		(* undefined for float and huegint, huegint version as library *)
		PROCEDURE EmitMod(CONST instr: IntermediateCode.Instruction);
		BEGIN
			HALT(100); (*! mod is not supported by hardware, must be runtime call -- cf. method Supported *)
		END EmitMod;

		PROCEDURE EmitAnd(VAR instruction: IntermediateCode.Instruction; part: LONGINT);
		VAR left, right, dest: Operand; negate: BOOLEAN;
		BEGIN
			PrepareOp3(instruction,part,FALSE,negate,dest,left,right);
			Emit2(opAND,left,right);
			FinishOp(instruction.op1, part,dest, left)
		END EmitAnd;

		PROCEDURE EmitOr(VAR instruction: IntermediateCode.Instruction; part: LONGINT);
		VAR left, right, dest: Operand; negate: BOOLEAN;
		BEGIN
			PrepareOp3(instruction,part,FALSE,negate,dest, left,right);
			Emit2(opOR,left,right);
			FinishOp(instruction.op1,part,dest, left)
		END EmitOr;

		PROCEDURE EmitXor(VAR instruction: IntermediateCode.Instruction; part: LONGINT);
		VAR dest, left, right: Operand; negate: BOOLEAN;
		BEGIN
			PrepareOp3(instruction,part,FALSE,negate,dest,left,right);
			Emit2(opXOR,left,right);
			FinishOp(instruction.op1,part,dest,left)
		END EmitXor;

		PROCEDURE GetTemporaryRegister(VAR op: Operand);
		VAR ticket: Ticket;
		BEGIN
			ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
			TicketToOperand(ticket,op);
		END GetTemporaryRegister;

		PROCEDURE EmitShift(VAR instr: IntermediateCode.Instruction);
		VAR op2, op3, dest, imm, one, opx, mask, opx2: Operand; shift: LONGINT; fixup, fixup2: BinaryCode.Fixup;
		BEGIN
			instructionSet.InitOperand(imm); instructionSet.InitOperand(one);

			ASSERT(instr.op1.type.sizeInBits < 64);

			AcquireDestinationRegister(instr.op1, Low, dest);

			MakeRegister(instr.op2, Low, op2);
			(*! caution: do not use dest and op2 / op3 more than once in one line: dest might be source (as in shl $1,1,$1) *)

			IF instr.op3.mode = IntermediateCode.ModeImmediate THEN
				shift := SHORT(instr.op3.intValue) MOD 32;
				IF shift = 0 THEN
					MovIfDifferent(dest, op2);
					Emit2N(opROR, dest, shift);
				ELSE
					CASE instr.opcode OF
					|IntermediateCode.ror:
						MovIfDifferent(dest, op2);
						Emit2N(opROR, dest, shift);
					|IntermediateCode.rol:
						MovIfDifferent(dest, op2);
						Emit2N(opROR, dest, 32-shift);
					|IntermediateCode.shl:
						MovIfDifferent(dest, op2);
						Emit2N(opROR, dest, 32-shift);
						ImmediateToOperand(ASH(1, shift)-1, Low, FALSE, instructionSet.ImmediateFixupBits,imm);
						Emit2(opBIC, dest, imm);
						ReleaseHint(imm.register);
					|IntermediateCode.shr:
						IF instr.op1.type.form # IntermediateCode.SignedInteger THEN
							(* logical shift right *)
							ImmediateToOperand(ASH(1,shift)-1,Low,FALSE,instructionSet.ImmediateFixupBits,imm);
							Emit2(opBIC, op2, imm);
							MovIfDifferent(dest, op2);
							Emit2N(opROR, dest, shift);
							ReleaseHint(imm.register);
						ELSE
							(* arithmetic shift right *)
							ImmediateToOperand(ASH(1,shift)-1,Low,FALSE,instructionSet.ImmediateFixupBits,imm);
							MovIfDifferent(dest, op2);
							Emit2(opOR,dest,dest);
							fixup := BrForward(opBN);
							(*
							Emit1N(opBN, 2); (* if op2 < 0 then skip next two instructions  *)
							*)
							Emit2(opBIC, dest,imm);
							fixup2 := BrForward(opBT);
							(*
							Emit1N(opBT, 1); (* skip next instruction *)
							*)
							SetTarget(fixup);
							Emit2(opOR, dest, imm);
							SetTarget(fixup2);
							Emit2N(opROR, dest, shift);
							ReleaseHint(imm.register);
						END;
					END;
				END;
			ELSE
				MakeRegister(instr.op3, Low, op3);

				CASE instr.opcode OF
				|IntermediateCode.ror:
					Emit2(opROR, op2, op3);
					MovIfDifferent(dest, op2);
				|IntermediateCode.rol:
					GetTemporaryRegister(imm);
					ImmediateToOperand(32, Low, FALSE, instructionSet.ImmediateFixupBits, imm);
					Emit2(opSUB, imm, op3);
					Emit2(opROR, op2, imm);
					MovIfDifferent(dest, op2);
					ReleaseHint(imm.register);
				|IntermediateCode.shl:
					GetTemporaryRegister(imm);
					ImmediateToOperand(32, Low, FALSE, instructionSet.ImmediateFixupBits,imm);
					Emit2(opSUB, imm, op3);
					Emit2(opROR, op2, imm);
					IF IsSameRegister(dest, op2) THEN
						GetTemporaryRegister(op2);
					ELSE
						Emit2(opMOV, dest, op2);
					END;
					(*GetTemporaryRegister(one,32);*)
					ImmediateToOperand(1, Low, FALSE, instructionSet.ImmediateFixupBits, op2);
					Emit2(opROR, op2, imm);
					Emit2N(opSUB, op2, 1);
					Emit2(opBIC, dest, op2);
					ReleaseHint(imm.register);
					ReleaseHint(op2.register);

				|IntermediateCode.shr:
					IF instr.op1.type.form # IntermediateCode.SignedInteger THEN
						GetTemporaryRegister(mask);
						ImmediateToOperand(1, Low, FALSE, instructionSet.ImmediateFixupBits,mask);

						IF IsSameRegister(dest, op3) THEN
							GetTemporaryRegister(opx);
							Emit2(opMOV, opx, op3);
							Emit2(opMOV, dest, op2);
							op3 := opx;
						ELSE
							MovIfDifferent(dest, op2);
						END;

						IF physicalRegisters.NextFree(IntermediateCode.int32)#None THEN
							GetTemporaryRegister(opx2);
						ELSE
							EmitPush(instr.op1,Low); (* save dest *)
							opx2 := dest;
						END;

						Emit2N(opMOV, opx2, 32);
						Emit2(opSUB, opx2, op3);
						Emit2(opROR, mask, opx2);
						Emit2N(opSUB, mask, 1);

						IF opx2.register = dest.register THEN
							EmitPop(instr.op1,Low); (* restore dest *)
						ELSE
							ReleaseHint(opx2.register);
						END;

						Emit2(opBIC, dest, mask);
						Emit2(opROR, dest, op3);

						ReleaseHint(opx.register);
						ReleaseHint(mask.register);
					ELSE
						GetTemporaryRegister(imm);
						ImmediateToOperand(32, Low, FALSE, instructionSet.ImmediateFixupBits, imm);
						Emit2(opSUB, imm, op3);
						GetTemporaryRegister(one);
						ImmediateToOperand(1, Low, FALSE, instructionSet.ImmediateFixupBits, one);
						Emit2(opROR, one, imm);
						Emit2N(opSUB, one, 1);
						Emit2(opOR, op2, op2); (* if negative *)
						fixup := BrForward(opBN);
						(*
						Emit1N(opBN, 2); (* then skip next two instructions  *)
						*)
						Emit2(opBIC, op2,one);
						fixup2 := BrForward(opBT);
						(*
						Emit1N(opBT, 1); (* skip next instruction *)
						*)
						SetTarget(fixup);
						Emit2(opOR, op2, one);
						SetTarget(fixup2);
						Emit2(opROR, op2, op3);
						MovIfDifferent(dest, op2);
						ReleaseHint(imm.register);
						ReleaseHint(one.register);
					END;
				END;
			END;

			ReleaseDestinationRegister(instr.op1, Low, dest);
		END EmitShift;

		PROCEDURE EmitCopy(VAR instr: IntermediateCode.Instruction);
		VAR op1, op2, op3: Operand; mem1, mem2: InstructionSet.Operand; reg: Operand;
			prevSize, i: LONGINT; ticket: Ticket;
		BEGIN
			MakeRegister(instr.op1, Low, op1);
			MakeRegister(instr.op2, Low, op2);
			IF (instr.op3.mode = IntermediateCode.ModeImmediate) & (instr.op3.intValue < 16) THEN
				GetTemporaryRegister(reg);
				FOR i := 0 TO SHORT(instr.op3.intValue)-1 DO
					instructionSet.InitMemory(mem1, op1.register, i);
					instructionSet.InitMemory(mem2, op2.register, i);
					Emit2(opLD, reg, mem2);
					Emit2(opST, reg, mem1);
				END;
				ReleaseHint(reg.register);
			ELSE
				MakeRegister(instr.op3, Low, op3);
				ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
				TicketToOperand(ticket,reg);
				instructionSet.InitMemory(mem1, op1.register, 0);
				instructionSet.InitMemory(mem2, op2.register, 0);

				prevSize := out.pc;
				Emit2(opLD, reg, mem2);
				Emit2(opST, reg, mem1);
				Emit2N(opADD, op1, 1);
				Emit2N(opADD, op2, 1);
				Emit2N(opSUB, op3, 1);

				Emit1N(opBGT, -(out.pc-prevSize+1));
				UnmapTicket(ticket);
			END;
		END EmitCopy;

		PROCEDURE EmitFill(VAR instr: IntermediateCode.Instruction; down: BOOLEAN);
		VAR op1, op2, op3: Operand; mem1: InstructionSet.Operand;
			prevSize: LONGINT; i: LONGINT; ticket: Ticket;
		BEGIN
			MakeRegister(instr.op1, Low, op1);
			MakeRegister(instr.op2, Low, op2);
			IF ~down & (instr.op3.mode = IntermediateCode.ModeImmediate) & (instr.op3.intValue < 16) THEN
				FOR i := 0 TO SHORT(instr.op3.intValue)-1 DO
					instructionSet.InitMemory(mem1, op1.register, i);
					Emit2(opST, op2, mem1);
				END;
			ELSE
				MakeRegister(instr.op3, Low, op3);
				instructionSet.InitMemory(mem1, op1.register, 0);

				prevSize := out.pc;
				Emit2(opST, op2, mem1);
				IF down THEN
					Emit2N(opSUB, op1, 1);
				ELSE
					Emit2N(opADD, op1, 1);
				END;
				Emit2N(opSUB, op3, 1);

				Emit1N(opBGT, -(out.pc-prevSize+1));
				UnmapTicket(ticket);
			END;
		END EmitFill;

		PROCEDURE BrForward(op: LONGINT): BinaryCode.Fixup;
		VAR fixupOp: InstructionSet.Operand; fixup: BinaryCode.Fixup; identifier: ObjectFile.Identifier;
		BEGIN
			identifier.name := in.name;
			identifier.fingerprint := in.fingerprint;
			fixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, identifier, 0,0,0,NIL);
			fixup.resolved := in;
			instructionSet.InitFixup(fixupOp,32,fixup);
			Emit1(op, fixupOp);
			RETURN fixup;
		END BrForward;

		PROCEDURE SetTarget(fixup: BinaryCode.Fixup);
		BEGIN
			fixup.SetSymbol(in.name, in.fingerprint, 0, out.pc+fixup.displacement (* displacement offset computed during operand emission, typically -1 *) );
			fixup.resolved := in;
		END SetTarget;

		PROCEDURE EmitBr (VAR instr: IntermediateCode.Instruction);
		VAR dest, destPC, offset: LONGINT; target: Operand; reverse: BOOLEAN;
			(* jump operands *)  op2, op3: Operand; hiHit, hiFail, lowHit: LONGINT;
				failPC: LONGINT;
					pattern: ObjectFile.FixupPatterns; fixup, failFixup: BinaryCode.Fixup;
					float,negate: BOOLEAN; identifier: ObjectFile.Identifier;

			PROCEDURE JmpDest(brop: LONGINT);
			VAR op1: Operand; fixupOp: InstructionSet.Operand; oldLR, thisPC: Operand; ticket1, ticket2: Ticket;
			BEGIN
				IF instr.op1.mode = IntermediateCode.ModeImmediate THEN
					Assert(instr.op1.symbol.name # "", "branch without symbol destination");
					dest := (instr.op1.symbolOffset); (* this is the offset in the in-data section (intermediate code), it is not byte-relative *)
					destPC := in.instructions[dest].pc + instr.op1.offset;
					offset := destPC - out.pc;
					fixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, instr.op1.symbol, instr.op1.symbolOffset, instr.op1.offset,0,NIL);
					IF (fixup.symbol.name = in.name) & (fixup.symbolOffset > inPC) THEN (* forward jump *)
						forwardFixups.Enter(fixup, out.pc, instructionSet.RelativeBranchFixupBits);
					ELSIF (fixup.symbol.name = in.name) & (fixup.symbolOffset < inPC) THEN (* backward jump *)
						ASSERT(offset < 0); offset := -offset;
						IF offset >= ASH(1,instructionSet.RelativeBranchFixupBits-1)-1 THEN
							(*D.String("fixup too far for immediate fixup, offset=");D.Int(offset,1);D.Ln;*)
						
							(* cannot enter fixup / use immediate jump, jump too far *)
							fixup := BrForward(instructionSet.inverseCondition[brop]); (* jump over absolute branch (skip) *)
							(*
							fixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, in, 0,0,0,NIL);
							InstructionSet.InitFixup(fixupOp,32,fixup);
							Emit1(InstructionSet.inverseCondition[brop], fixupOp); (* jump over absolute branch (skip) *)
							*)
							(* do a relative register jump, an absolute jump would require a fixup with unpredictable size
								=> have to get program counter, misuse BL here:
								MOV Rx, LR
								BL 0; get PC of next line
								MOV Ry, LR
								MOV LR, Rx ; restore LR
								ADD Ry, offset
								BR R2
							 *)
							ticket1 := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
							ticket2 := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
							TicketToOperand(ticket1,oldLR);
							TicketToOperand(ticket2,thisPC);
							Emit2(opMOV,oldLR, opLR);
							Emit1N(opBL,0);
							(* exactly here we have the current PC in LR, so we compute the offset here *)
							offset := out.pc-destPC;
							Emit2(opMOV, thisPC, opLR);
							Emit2(opMOV, opLR, oldLR);
							UnmapTicket(ticket1);
							instructionSet.InitOperand(target);
							ImmediateToOperand(offset,Low,FALSE, instructionSet.ImmediateFixupBits,target);
							Emit2(opSUB, thisPC, target);
							Emit1(InstructionSet.opBR, thisPC);
							ReleaseHint(target.register);
							(* patch fixup for skip long jump code *)
							SetTarget(fixup);
							(*
							fixup.SetSymbol(in, 0, out.pc+fixup.displacement (* displacement offset computed during operand emission, typically -1 *) );
							*)
							RETURN
						END;
					END;
					instructionSet.InitFixup(target, 32, fixup);
					(* fixup mask entered curing  code emission *)
					Emit1(brop, target);
				ELSIF brop = opBT THEN (* register jump, unconditional *)
					MakeRegister(instr.op1,Low,op1);
					Emit1(opBR, op1);
				ELSE
					HALT(100); (* no conditional jump on register implemented *)
				END;
			END JmpDest;

			PROCEDURE Cmp(left, right: InstructionSet.Operand);
			VAR destOp: Operand; ticket: Ticket; fixup, fixup2: BinaryCode.Fixup;
			BEGIN
				IF float THEN
					ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
					TicketToOperand(ticket,destOp);
					Emit2(opMOV, destOp, left);
					Emit2(opAND, destOp, right);
					fixup := BrForward(opBN);
					(*
					Emit1N(opBN, 3);
					*)
					Emit2(opMOV, destOp, left);
					Emit2(opSUB, destOp, right);
					fixup2 := BrForward(opBT);
					SetTarget(fixup);
					(* Emit1N(opBT, 2); *)
					Emit2(opMOV, destOp, right);
					Emit2(opSUB, destOp, left);
					SetTarget(fixup2);
					UnmapTicket(ticket);
				ELSE
					IF (left.register >= 0) & (physicalRegisters.Mapped(left.register) = NIL) THEN
						IF negate THEN
							Emit2(opADD, left, right);
						ELSE
							Emit2(opSUB, left, right);
						END;
					ELSE
						ticket := TemporaryTicket(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32);
						TicketToOperand(ticket,destOp);
						Emit2(opMOV, destOp, left);
						IF negate THEN
							Emit2(opADD, destOp, right);
						ELSE
							Emit2(opSUB, destOp, right);
						END;
						UnmapTicket(ticket);
					END;
				END;
			END Cmp;

		BEGIN
			hiFail := None; hiHit := None; lowHit := None;

			float := instr.op2.type.form = IntermediateCode.Float;
			failPC := 0;

			IF (instr.op1.symbol.name = in.name) & (instr.op1.symbolOffset = inPC +1) THEN (* jump to next instruction can be ignored *)
				IF dump # NIL THEN dump.String("jump to next instruction ignored"); dump.Ln END;
				RETURN
			END;

			IF instr.opcode = IntermediateCode.br THEN
				JmpDest(opBT);
			ELSE
				(*
					conditional branch

					for 32 bit operands quite simple

						cmp left right
						brc(hit) target
						...
						target:
						....

					for 64 bit operands transformed to

						cmp hi(left) hi(right)
						brc(hiHit) target
						brc(hiFail) fail

						cmp low(left) low(right)
						brc(lowHit) target
						fail:
						....
						target:
						.....

				*)

				IF instr.op2.type.sizeInBits # 64 THEN
					CASE instr.opcode OF
					IntermediateCode.breq:
						lowHit := opBEQ;
					|IntermediateCode.brne:
						lowHit := opBNE;
					|IntermediateCode.brge:
						IF instr.op2.type.form IN {IntermediateCode.SignedInteger, IntermediateCode.Float} THEN
							IF reverse THEN lowHit := opBLE ELSE lowHit := opBGE END;
						ELSIF instr.op2.type.form = IntermediateCode.UnsignedInteger THEN
							IF reverse THEN lowHit := opBBE ELSE lowHit := opBAE END;
						END;
					|IntermediateCode.brlt:
						IF instr.op2.type.form IN {IntermediateCode.SignedInteger, IntermediateCode.Float}  THEN
							IF reverse THEN lowHit := opBGT ELSE lowHit := opBLT END;
						ELSIF instr.op2.type.form = IntermediateCode.UnsignedInteger THEN
							IF reverse THEN lowHit := opBA  ELSE lowHit := opBB END;
						END;
					END;
				ELSE
					Assert(instr.op2.type.form # IntermediateCode.UnsignedInteger, "no unsigned integer64 branch implemented");
					CASE instr.opcode OF
					IntermediateCode.breq:
						hiHit := None; hiFail := opBNE; lowHit := opBEQ
					|IntermediateCode.brne:
						hiHit := opBNE; hiFail := None; lowHit := opBNE
					|IntermediateCode.brge:
						IF reverse THEN
							hiHit := opBLT; hiFail := opBGT; lowHit := opBBE
						ELSE
							hiHit := opBGT; hiFail := opBLT; lowHit := opBAE
						END;
					|IntermediateCode.brlt:
						IF reverse THEN
							hiHit := opBGT; hiFail := opBLT; lowHit := opBA
						ELSE
							hiHit := opBLT; hiFail := opBGT; lowHit := opBB
						END;
					END;

					MakeRegister(instr.op2, High, op2); negate := FALSE;
					IF float THEN
						MakeRegister(instr.op3, High, op3)
					ELSIF ~UnsignedImmediate(instr.op3, High, instructionSet.ImmediateFixupBits, TRUE, negate,op3) THEN
						MakeRegister(instr.op3, High, op3)
					END;

					Cmp(op2, op3);
					ReleaseHint(op2.register); ReleaseHint(op3.register);
					float := FALSE; (* lower bits must always be compared as (unsigned) integers *)

					IF hiHit # None THEN
						JmpDest(hiHit);
					END;
					IF hiFail # None THEN
						NEW(pattern,1);
						pattern[0].offset := 0; pattern[0].bits := instructionSet.RelativeBranchFixupBits;
						identifier.name := in.name;
						identifier.fingerprint := in.fingerprint;
						failFixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, identifier, 0, 0, 0 , pattern);
						failFixup.resolved := in;
						instructionSet.InitImmediate(target,32,0);
						instructionSet.AddFixup(target, failFixup);
						Emit1(hiFail, target);
					END;


					(*ReleaseHint(op2.register);
					ReleaseHint(op3.register);*)
				END;

				MakeRegister(instr.op2, Low, op2); negate := FALSE;
				IF float THEN
					MakeRegister(instr.op3, Low, op3)
				ELSIF ~UnsignedImmediate(instr.op3, Low, instructionSet.ImmediateFixupBits, TRUE, negate,op3) THEN
					MakeRegister(instr.op3, Low, op3)
				END;
				Cmp(op2, op3);
				ReleaseHint(op2.register); ReleaseHint(op3.register);
				ASSERT(lowHit # None);
				JmpDest(lowHit);
				IF hiFail # None THEN
					failFixup.SetSymbol(in.name, in.fingerprint, 0, out.pc+failFixup.displacement (* displacement offset computed during operand emission, typically -1 *) );
					failFixup.resolved := in;
				END;
			END;
		END EmitBr;

		PROCEDURE EmitPop(VAR vop: IntermediateCode.Operand; part: LONGINT);
		VAR mem: InstructionSet.Operand; reg: Operand;
		BEGIN
			instructionSet.InitMemory(mem, InstructionSet.SP, 0);
			AcquireDestinationRegister(vop, part, reg);
			Emit2(opLD, reg, mem);
			AllocateStack(-1, TRUE);
			ReleaseDestinationRegister(vop, part, reg);
		END EmitPop;

		PROCEDURE EmitPush(VAR vop: IntermediateCode.Operand; part: LONGINT);
		VAR mem: InstructionSet.Operand; reg: Operand; pc: LONGINT;
		BEGIN
			MakeRegister(vop, part, reg);
			IF pushChainLength = 0 THEN (* check for chain of pushes *)
				pc := inPC+1; pushChainLength := 1;
				WHILE ~inEmulation & (pc < in.pc) & (in.instructions[pc].opcode = IntermediateCode.push) DO
					INC(pc); INC(pushChainLength);
				END;
				AllocateStack(pushChainLength,TRUE);
			END;
			DEC(pushChainLength);
			instructionSet.InitMemory(mem, InstructionSet.SP, pushChainLength);
			Emit2(opST, reg, mem);
		END EmitPush;

		PROCEDURE EmitNeg(VAR instr: IntermediateCode.Instruction);
		VAR  leftLow, leftHigh, rightLow, rightHigh, reg: Operand; neg: BOOLEAN; fixup: BinaryCode.Fixup;
		BEGIN
			IF instr.op1.type.form IN IntermediateCode.Integer THEN
				PrepareOp2(instr,Low,FALSE,neg,leftLow, rightLow);
				Emit2(opNOT, leftLow, rightLow);
				IF IsComplex(instr.op1) THEN
					PrepareOp2(instr,High,FALSE,neg,leftHigh,rightHigh);
					Emit2(opNOT, leftHigh, rightHigh);
				END;
				Emit2N(opADD,leftLow,1);
				FinishOp(instr.op1,Low,leftLow, leftLow);
				IF IsComplex(instr.op1) THEN
					fixup := BrForward(opBB);
					(*
					Emit1N(opBB, 1);
					*)
					Emit2N(opADD, leftHigh, 1);
					SetTarget(fixup);
					FinishOp(instr.op1,High,leftHigh, leftHigh);
				END;
			ELSIF instr.op1.type.form = IntermediateCode.Float THEN
				PrepareOp2(instr,Low,FALSE,neg,leftLow,rightLow);
				IF IsComplex(instr.op1) THEN
					PrepareOp2(instr,High,FALSE,neg,leftHigh,rightHigh);
				END;
				Emit2(opMOV,leftLow,rightLow);
				IF ~IsComplex(instr.op1) THEN
					reg := leftLow
				ELSE ASSERT(instr.op1.type.sizeInBits=64);
					Emit2(opMOV,leftHigh,rightHigh);
					reg := leftHigh;
				END;
				Emit2N(opROR,reg,31);
				Emit2N(opXOR,reg,1);
				Emit2N(opROR,reg,1);
				ReleaseDestinationRegister(instr.op1, Low, leftLow);
				IF IsComplex(instr.op1) THEN
					ReleaseDestinationRegister(instr.op1,High,leftHigh);
				END;
			END;

		END EmitNeg;

		PROCEDURE EmitNot(VAR instr: IntermediateCode.Instruction; part: LONGINT);
		VAR left,right: Operand; negate: BOOLEAN;
		BEGIN
			PrepareOp2(instr,part,FALSE,negate,left,right);
			Emit2(opNOT, left,right);
			FinishOp(instr.op1,part,left,left);
		END EmitNot;

		PROCEDURE EmitAbs(VAR instr: IntermediateCode.Instruction);
		VAR left,right: Operand; neg: BOOLEAN; fixup: BinaryCode.Fixup;
		BEGIN
			PrepareOp2(instr,Low,FALSE,neg,left,right);
			Emit2(opMOV, left, right);
			fixup := BrForward(opBNN);
			(*
			Emit1N(opBNN, 2);
			*)
			Emit2(opNOT, left,right);
			Emit2N(opADD, left, 1);
			SetTarget(fixup);
			FinishOp(instr.op1,Low, left,left);
		END EmitAbs;

		PROCEDURE EmitTrap(CONST instr: IntermediateCode.Instruction);
		VAR reg: Operand; reserve: Ticket;
		BEGIN
			instructionSet.InitRegister(reg, 0);
			ImmediateToOperand(instr.op1.intValue,Low, FALSE, instructionSet.ImmediateFixupBits,reg);

			IF physicalRegisters.Mapped(0)=NIL THEN
				reserve := ReservePhysicalRegister(IntermediateCode.GeneralPurposeRegister,IntermediateCode.int32,0,inPC);
			ELSE
				reserve := NIL
			END;
			GetTemporaryRegister(reg);
			Emit2N(opMOV, reg, HaltIRQNumber);
			Emit2(opBLR, opLR, reg);
			ReleaseHint(reg.register);
			IF reserve # NIL THEN UnmapTicket(reserve) END;
		END EmitTrap;

		PROCEDURE EmitAsm(CONST instr: IntermediateCode.Instruction);
		VAR reader: Streams.StringReader; procedure: SyntaxTree.Procedure; scope: SyntaxTree.Scope;
				len: LONGINT; symbol: SyntaxTree.Symbol; assembler: Assembler.Assembler;
				scanner: Scanner.AssemblerScanner;
		BEGIN
			len := Strings.Length(instr.op1.string^);
			NEW(reader, len);
			reader.Set(instr.op1.string^);
			symbol := in.symbol;
			IF (symbol = NIL) THEN
				scope := NIL
			ELSE
				procedure := symbol(SyntaxTree.Procedure);
				scope := procedure.procedureScope;
			END;

			NEW(assembler, diagnostics, backend.capabilities,instructionSet );
			scanner := Scanner.NewAssemblerScanner(module.moduleName(*module.module.sourceName*), reader, SHORT(instr.op1.intValue), diagnostics);
			assembler.InlineAssemble(scanner, in, scope, module);
			error := error OR assembler.error
		END EmitAsm;

	END CodeGeneratorTRM;

	System = OBJECT (Global.System)

		PROCEDURE SizeOf(type: SyntaxTree.Type): LONGINT;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.BasicType THEN
				IF (type.sizeInBits=64) THEN
					RETURN 64
				ELSE
					RETURN 32
				END
			ELSE RETURN SizeOf^(type)
			END;
		END SizeOf;

	END System;



	BackendTRM = OBJECT (IntermediateBackend.IntermediateBackend)
	VAR
		cg: CodeGeneratorTRM;
		patchSpartan6: BOOLEAN;
		myInstructionSet: InstructionSet.InstructionSet;
		recentInstructionWidth : LONGINT;
		
		PROCEDURE &InitBackendTRM;
		BEGIN
			InitIntermediateBackend;
			SetRuntimeModuleName(DefaultRuntimeModuleName);
			SetNewObjectFile(TRUE,TRUE);
			myInstructionSet:=defaultInstructionSet;
			SetHasLinkRegister;
			recentInstructionWidth := Sections.UnknownSize;
		END InitBackendTRM;

		PROCEDURE Initialize(diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; flags: SET; checker: SemanticChecker.Checker; system: Global.System);
		VAR
		BEGIN
			Initialize^(diagnostics, log, flags, checker, system); (*goes up the inheritance hierarchy all the way to Backend.Mod*)
			
			
			NEW(cg, runtimeModuleName, diagnostics, SELF,myInstructionSet);
			cg.patchSpartan6 := patchSpartan6;
			recentInstructionWidth := Sections.UnknownSize;
		END Initialize;
		
		PROCEDURE SetInstructionWidth* (instructionWidth: LONGINT);  (*override*)
		BEGIN
			IF SELF.instructionWidth # instructionWidth THEN
				SetInstructionWidth^(instructionWidth);
				NEW(myInstructionSet,instructionWidth);
				cg.SetInstructionSet(myInstructionSet);
			END;
		END SetInstructionWidth;
		
		PROCEDURE GetSystem(): Global.System;
		VAR system: System;
		BEGIN
			NEW(system, 18, 32, 32, 32, 32, 32, 32, 0(* parameter offset 0: handled locally *), 0 (* no pass of parameters in registers *) , cooperative);
			Global.SetDefaultDeclarations(system,32);
			Global.SetDefaultOperators(system);
			RETURN system
		END GetSystem;

		PROCEDURE SupportedInstruction(CONST instruction: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			RETURN cg.Supported(instruction, moduleName, procedureName);
		END SupportedInstruction;

		PROCEDURE SupportedImmediate(CONST immediate: IntermediateCode.Operand): BOOLEAN;
		VAR reg: InstructionSet.Operand; int: LONGINT;
		BEGIN
			IF immediate.type.form IN  IntermediateCode.Integer THEN
				IF immediate.type.sizeInBits < 64 THEN
					int := LONGINT(immediate.intValue);
					RETURN ((ABS(int) < ASH(1,myInstructionSet.ImmediateFixupBits)) OR (cg.GetImmediate32(int, reg, FALSE) < 3))
				ELSE
					RETURN (ABS(immediate.intValue) < ASH(1,myInstructionSet.ImmediateFixupBits))
				END;
			ELSE
				RETURN FALSE
			END
		END SupportedImmediate;

		PROCEDURE GenerateBinary(module: Sections.Module; dump: Streams.Writer);
		VAR
			in: Sections.Section;
			out: BinaryCode.Section;
			name: Basic.SectionName;
			procedure: SyntaxTree.Procedure;
			i, j, initialSectionCount: LONGINT;

			PROCEDURE Resolve(VAR fixup: BinaryCode.Fixup);
			BEGIN
				IF (fixup.symbol.name #"") & (fixup.resolved = NIL) THEN
					fixup.resolved := module.allSections.FindByName(fixup.symbol.name)
				END;
			END Resolve;


		 	(* recompute fixup positions and assign binary sections *)
		 	PROCEDURE PatchFixups(section: BinaryCode.Section);
			VAR resolved: BinaryCode.Section; fixup: BinaryCode.Fixup; symbolOffset: LONGINT; in: IntermediateCode.Section;
			BEGIN
				fixup := section.fixupList.firstFixup;
				WHILE fixup # NIL DO
					Resolve(fixup);
					IF  (fixup.resolved # NIL) THEN
						resolved := fixup.resolved(IntermediateCode.Section).resolved(BinaryCode.Section);
						in := fixup.resolved(IntermediateCode.Section);
						symbolOffset := fixup.symbolOffset;
						IF (symbolOffset # 0) & (symbolOffset < in.pc) THEN
							symbolOffset := in.instructions[symbolOffset].pc;
						END;
						fixup.SetSymbol(fixup.symbol.name, fixup.symbol.fingerprint, 0, symbolOffset+fixup.displacement);
					END;
					fixup := fixup.nextFixup;
				END;
			END PatchFixups;

		BEGIN
		 	cg.SetModule(module);
		 	cg.dump := dump;

		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
			 	in(IntermediateCode.Section).EnableComments(trace);
		 		IF in.type = Sections.InlineCodeSection THEN
		 			Basic.SegmentedNameToString(in.name, name);
			 		out := ResolvedSection(in(IntermediateCode.Section));
			 		cg.dump := out.comments;
		 			SetInstructionWidth(out.os.unit);
			 		cg.Section(in(IntermediateCode.Section), out);  (*compilation*)
			 		IF in.symbol # NIL THEN
				 		procedure := in.symbol(SyntaxTree.Procedure);
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
			 		IF (in.type # Sections.InlineCodeSection) (*& (in(IntermediateCode.Section).resolved = NIL) *) THEN
				 		out := ResolvedSection(in(IntermediateCode.Section));
			 			SetInstructionWidth(out.os.unit);
				 		cg.Section(in(IntermediateCode.Section),out);  
			 		END
			 	END
			UNTIL initialSectionCount = module.allSections.Length(); (* process remaining sections that have been added during traversal of sections *)

			(*
		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
			 	IF ~in.IsExternal() THEN
			 		IF in.type # Sections.InlineCodeSection THEN
				 		Basic.SegmentedNameToString(in.name, name);
				 		out := ResolvedSection(in(IntermediateCode.Section));
				 		cg.Section(in(IntermediateCode.Section), out);
			 		END
			 	END;
		 	END;
			*)



		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
		 		PatchFixups(in(IntermediateCode.Section).resolved)
		 	END;

			IF cg.error THEN Error("", Diagnostics.Invalid, Diagnostics.Invalid,  "") END;
		END GenerateBinary;

		(* genasm *)
		PROCEDURE ProcessIntermediateCodeModule*(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		VAR
			result: Formats.GeneratedModule;
		BEGIN
			ASSERT(intermediateCodeModule IS Sections.Module);
			result := ProcessIntermediateCodeModule^(intermediateCodeModule);
			recentInstructionWidth := Sections.UnknownSize;
			
			IF ~error THEN
				GenerateBinary(result(Sections.Module), dump);
				IF dump # NIL THEN
					dump.Ln; dump.Ln;
					dump.String("------------------ binary code -------------------"); dump.Ln;
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
				dump.String("------------------ rescued code (code generation trapped) -------------------"); dump.Ln;
				IF (traceString="") OR (traceString="*") THEN
					result.Dump(dump);
					dump.Update
				ELSE
					Sections.DumpFiltered(dump,result(Sections.Module),traceString);
					dump.Update;
				END
			END;
			RETURN result
		END ProcessIntermediateCodeModule;

		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN
			options.Add(0X,VectorSupportFlag,Options.Flag);
			options.Add(0X,FloatingPointSupportFlag,Options.Flag);
			options.Add(0X,PatchSpartan6, Options.Flag);
			DefineOptions^(options);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		VAR capabilities: SET;
		BEGIN
			capabilities := SELF.capabilities;
			IF options.GetFlag(VectorSupportFlag) THEN INCL(capabilities, Global.VectorCapability) END;
			IF options.GetFlag(FloatingPointSupportFlag) THEN INCL(capabilities, Global.FloatingPointCapability) END;
			IF options.GetFlag(PatchSpartan6) THEN D.String("patchSpartan6=TRUE"); D.Ln; patchSpartan6 := TRUE END;
			SetCapabilities(capabilities);
			GetOptions^(options);
		END GetOptions;

		PROCEDURE DefaultObjectFileFormat(): Formats.ObjectFileFormat;
		BEGIN RETURN ObjectFileFormat.Get();
		END DefaultObjectFileFormat;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN
			RETURN NIL
		END DefaultSymbolFileFormat;

		PROCEDURE GetDescription(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "TRM"
		END GetDescription;

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

		PROCEDURE CheckCodeAddress(VAR adr: LONGINT);
		BEGIN
			IF (patchSpartan6) & (adr MOD 1024 >= 959) (* need one instruction to jump, therefore include 959 in check *) & (adr MOD 1024 <= 975) THEN
				adr := (adr DIV 1024) * 1024 +976;
			END;
		END CheckCodeAddress;
		
		PROCEDURE ResolvedSection(in: IntermediateCode.Section): BinaryCode.Section;
		VAR section: BinaryCode.Section; unit: LONGINT;
		BEGIN
		
			(*VAR and CONST sections go to the data memory, only code sections go to code memory
			    Note that data memory has 32 bit words while code has standard 18.
			*)
			IF in.bitsPerUnit # Sections.UnknownSize THEN
				unit :=  in.bitsPerUnit;
			ELSIF in.type IN {Sections.VarSection, Sections.ConstSection} THEN
				unit := 32;
			ELSE
				IF (recentInstructionWidth # Sections.UnknownSize) THEN
					unit := recentInstructionWidth(* instructionWidth*);
				ELSE
					unit:=18;
				END
				
			END;

			IF in.IsCode() THEN
				recentInstructionWidth := unit;
			END;

			IF in.resolved = NIL THEN
				NEW(section, in.type, in.priority, unit, in.name, in.comments # NIL, FALSE);
				section.SetAlignment(in.fixed, in.positionOrAlignment);
				in.SetResolved(section);
			ELSE
				section := in.resolved
			END;
			RETURN section
		END ResolvedSection;

	END BackendTRM;

	VAR 
	defaultInstructionSet: InstructionSet.InstructionSet;
	emptyOperand: InstructionSet.Operand;

	PROCEDURE Assert(b: BOOLEAN; CONST s: ARRAY OF CHAR);
	BEGIN
		ASSERT(b, 100);
	END Assert;

	PROCEDURE Halt(CONST s: ARRAY OF CHAR);
	BEGIN
		HALT(100);
	END Halt;

	


	PROCEDURE Init;
	BEGIN
		NEW(defaultInstructionSet,18); (*TODO: maybe it's better to have all these init functions outside of instruction set object?*)
		defaultInstructionSet.InitOperand(emptyOperand);
		
	END Init;

	PROCEDURE Get*(): Backend.Backend;
	VAR backend: BackendTRM;
	BEGIN NEW(backend); RETURN backend
	END Get;

BEGIN
	Init;
END FoxTRMBackend.


SystemTools.FreeDownTo FoxTRMBackend  ~
