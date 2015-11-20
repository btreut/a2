MODULE FoxARMBackend; (** AUTHOR ""; PURPOSE "backend for ARM (advanced RISC machines)"; *)

IMPORT
	Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Backend := FoxBackend, Sections := FoxSections,
	IntermediateCode := FoxIntermediateCode, IntermediateBackend := FoxIntermediateBackend, CodeGenerators := FoxCodeGenerators, BinaryCode := FoxBinaryCode,
	SemanticChecker := FoxSemanticChecker, Formats := FoxFormats, Assembler := FoxARMAssembler, InstructionSet := FoxARMInstructionSet,
	SYSTEM, Diagnostics, Streams, Options, Strings, ObjectFile, Scanner := FoxScanner, ObjectFileFormat := FoxGenericObjectFile,
	D := Debugging;

CONST
	Trace = FALSE; (* general trace *)
	DefaultRuntimeModuleName = "ARMRuntime";

	None = -1;

	(* parts of an ARM operand *)
	Low = 0; High = 1;

	(* mnemonics of the ARM instruction set *)
	opADC = InstructionSet.opADC; opADD = InstructionSet.opADD;
	opAND = InstructionSet.opAND; opB = InstructionSet.opB;
	opBIC = InstructionSet.opBIC; opBKPT = InstructionSet.opBKPT;
	opBL = InstructionSet.opBL; opBLX = InstructionSet.opBLX;
	opBX = InstructionSet.opBX; opCDP = InstructionSet.opCDP;
	opCDP2 = InstructionSet.opCDP2; opCLZ = InstructionSet.opCLZ;
	opCMN = InstructionSet.opCMN; opCMP = InstructionSet.opCMP;
	opEOR = InstructionSet.opEOR; opFABSD = InstructionSet.opFABSD;
	opFABSS = InstructionSet.opFABSS; opFADDD = InstructionSet.opFADDD;
	opFADDS = InstructionSet.opFADDS; opFCMPD = InstructionSet.opFCMPD;
	opFCMPED = InstructionSet.opFCMPED; opFCMPES = InstructionSet.opFCMPES;
	opFCMPEZD = InstructionSet.opFCMPEZD; opFCMPEZS = InstructionSet.opFCMPEZS;
	opFCMPS = InstructionSet.opFCMPS; opFCMPZD = InstructionSet.opFCMPZD;
	opFCMPZS = InstructionSet.opFCMPZS; opFCPYD = InstructionSet.opFCPYD;
	opFCPYS = InstructionSet.opFCPYS; opFCVTDS = InstructionSet.opFCVTDS;
	opFCVTSD = InstructionSet.opFCVTSD; opFDIVD = InstructionSet.opFDIVD;
	opFDIVS = InstructionSet.opFDIVS; opFLDD = InstructionSet.opFLDD;
	opFLDMIAD = InstructionSet.opFLDMIAD; opFLDMIAS = InstructionSet.opFLDMIAS;
	opFLDMIAX = InstructionSet.opFLDMIAX; opFLDMDBD = InstructionSet.opFLDMDBD;
	opFLDMDBS = InstructionSet.opFLDMDBS; opFLDMDBX = InstructionSet.opFLDMDBX;
	opFLDS = InstructionSet.opFLDS; opFMACD = InstructionSet.opFMACD;
	opFMACS = InstructionSet.opFMACS; opFMDHR = InstructionSet.opFMDHR;
	opFMDLR = InstructionSet.opFMDLR; opFMRDH = InstructionSet.opFMRDH;
	opFMRDL = InstructionSet.opFMRDL; opFMRS = InstructionSet.opFMRS;
	opFMRX = InstructionSet.opFMRX; opFMSCD = InstructionSet.opFMSCD;
	opFMSCS = InstructionSet.opFMSCS; opFMSR = InstructionSet.opFMSR;
	opFMSTAT = InstructionSet.opFMSTAT; opFMULD = InstructionSet.opFMULD;
	opFMULS = InstructionSet.opFMULS; opFMXR = InstructionSet.opFMXR;
	opFNEGD = InstructionSet.opFNEGD; opFNEGS = InstructionSet.opFNEGS;
	opFNMACD = InstructionSet.opFNMACD; opFNMACS = InstructionSet.opFNMACS;
	opFNMSCD = InstructionSet.opFNMSCD; opFNMSCS = InstructionSet.opFNMSCS;
	opFNMULD = InstructionSet.opFNMULD ; opFNMULS = InstructionSet.opFNMULS;
	opFSITOD = InstructionSet.opFSITOD; opFSITOS = InstructionSet.opFSITOS;
	opFSQRTD = InstructionSet.opFSQRTD; opFSQRTS = InstructionSet.opFSQRTS;
	opFSTD = InstructionSet.opFSTD; opFSTMIAD = InstructionSet.opFSTMIAD;
	opFSTMIAS = InstructionSet.opFSTMIAS; opFSTMIAX = InstructionSet.opFSTMIAX;
	opFSTMDBD = InstructionSet.opFSTMDBD; opFSTMDBS = InstructionSet.opFSTMDBS;
	opFSTMDBX = InstructionSet.opFSTMDBX; opFSTS = InstructionSet.opFSTS;
	opFSUBD = InstructionSet.opFSUBD; opFSUBS = InstructionSet.opFSUBS;
	opFTOSID = InstructionSet.opFTOSID; opFTOSIZD = InstructionSet.opFTOSIZD;
	opFTOSIS = InstructionSet.opFTOSIS; opFTOSIZS = InstructionSet.opFTOSIZS;
	opFTOUID = InstructionSet.opFTOUID; opFTOUIZD = InstructionSet.opFTOUIZD;
	opFTOUIS = InstructionSet.opFTOUIS; opFTOUIZS = InstructionSet.opFTOUIZS;
	opFUITOD = InstructionSet.opFUITOD; opFUITOS = InstructionSet.opFUITOS;
	opLDC = InstructionSet.opLDC; opLDC2 = InstructionSet.opLDC2;
	opLDM = InstructionSet.opLDM; opLDR = InstructionSet.opLDR;
	opLDREX = InstructionSet.opLDREX; opSTREX = InstructionSet.opSTREX;
	opMCR = InstructionSet.opMCR; opMCR2 = InstructionSet.opMCR2;
	opMCRR = InstructionSet.opMCRR; opMLA = InstructionSet.opMLA;
	opMOV = InstructionSet.opMOV; opMRC = InstructionSet.opMRC;
	opMRC2 = InstructionSet.opMRC2; opMRRC = InstructionSet.opMRRC;
	opMRS = InstructionSet.opMRS; opMSR = InstructionSet.opMSR;
	opMUL = InstructionSet.opMUL; opMVN = InstructionSet.opMVN;
	opORR = InstructionSet.opORR; opPLD = InstructionSet.opPLD;
	opQADD = InstructionSet.opQADD; opQDADD = InstructionSet.opQDADD;
	opQDSUB = InstructionSet.opQDSUB; opQSUB = InstructionSet.opQSUB;
	opRSB = InstructionSet.opRSB; opRSC = InstructionSet.opRSC;
	opSBC = InstructionSet.opSBC; opSMLABB = InstructionSet.opSMLABB;
	opSMLABT = InstructionSet.opSMLABT; opSMLAL = InstructionSet.opSMLAL;
	opSMLATB = InstructionSet.opSMLATB; opSMLATT = InstructionSet.opSMLATT;
	opSMLALBB = InstructionSet.opSMLALBB; opSMLALBT = InstructionSet.opSMLALBT;
	opSMLALTB = InstructionSet.opSMLALTB; opSMLALTT = InstructionSet.opSMLALTT;
	opSMLAWB = InstructionSet.opSMLAWB; opSMLAWT = InstructionSet.opSMLAWT;
	opSMULBB = InstructionSet.opSMULBB; opSMULBT = InstructionSet.opSMULBT;
	opSMULTB = InstructionSet.opSMULTB; opSMULTT = InstructionSet.opSMULTT;
	opSMULWB = InstructionSet.opSMULWB; opSMULWT = InstructionSet.opSMULWT;
	opSMULL = InstructionSet.opSMULL; opSTC = InstructionSet.opSTC;
	opSTC2 = InstructionSet.opSTC2; opSTM = InstructionSet.opSTM;
	opSTR = InstructionSet.opSTR; opSUB = InstructionSet.opSUB;
	opSWI = InstructionSet.opSWI; opSWP = InstructionSet.opSWP;
	opTEQ = InstructionSet.opTEQ; opTST = InstructionSet.opTST;
	opUMLAL = InstructionSet.opUMLAL; opUMULL = InstructionSet.opUMULL;

	MaximumFixupDistance = (*4103*) 1024; (* = 2^12-1+8 (maximum distance [in bytes] between a symbol fixup location and an instruction that uses the symbol) *)

	(* builtin backend specific system instructions *)
	GetSP = 0; SetSP = 1;
	GetFP = 2; SetFP = 3;
	GetLNK = 4; SetLNK = 5;
	GetPC = 6; SetPC = 7;
	LDPSR = 8; STPSR = 9;
	LDCPR = 10; STCPR = 11;
	FLUSH = 12;
	NULL = 13; XOR = 14; MULD = 15; ADDC = 16;
	PACK = 17; UNPK = 18;

	UseFPUFlag = "useFPU";

TYPE
	Operand = InstructionSet.Operand;

	Ticket = CodeGenerators.Ticket;

	(* a citation of a symbol, i.e., an ARM instruction that requires a symbol's address *)
	Citation = OBJECT
	VAR
		pc: LONGINT; (* program counter of the ARM instruction *)
		next: Citation;
	END Citation;

	(* a reference to a symbol and offset in IR units that is used by at least one instruction *)
	Reference = OBJECT
	VAR
		firstCitation, lastCitation: Citation; (* linked list of citations *)
		next: Reference;

		PROCEDURE & Init;
		BEGIN
			firstCitation := NIL; lastCitation := NIL; next := NIL;
		END Init;

		PROCEDURE AddCitation(pc: LONGINT);
		VAR
			citation: Citation;
		BEGIN
			NEW(citation); citation.pc := pc; citation.next := NIL;
			IF firstCitation = NIL THEN firstCitation := citation ELSE lastCitation.next := citation END;
			lastCitation := citation
		END AddCitation;

	END Reference;

	ImmediateReference = OBJECT (Reference)
	VAR value: LONGINT;

		PROCEDURE & InitImm(v: LONGINT);
		BEGIN
			Init;
			SELF.value := v;
		END InitImm;

	END ImmediateReference;

	(* a reference to a symbol and offset in IR units that is used by at least one instruction *)
	SymbolReference = OBJECT (Reference)
	VAR
		symbol: Sections.SectionName;
		fingerprint: LONGINT;
		symbolOffset: LONGINT; (* offset to the symbol in IR units *)

		PROCEDURE & InitSym(s: Sections.SectionName; fp: LONGINT; offs: LONGINT);
		BEGIN
			Init;
			SELF.symbol := s; SELF.symbolOffset := offs; fingerprint := fp;
		END InitSym;

	END SymbolReference;

	ListOfReferences = OBJECT
	VAR
		firstReference, lastReference: Reference; (* linked list of all symbol references *)
		referenceCount: LONGINT; (* the number of reference = length of the required fixup block *)
		pcOfFirstCitation: LONGINT; (* the PC of the first instruction that cites a symbol or immediate *)

		PROCEDURE & Init;
		BEGIN
			firstReference := NIL; lastReference := NIL;
			referenceCount := 0;
			pcOfFirstCitation := None;
		END Init;

		PROCEDURE AddSymbol(symbol: Sections.SectionName; fingerprint: LONGINT; symbolOffset: LONGINT; pc: LONGINT);
		VAR
			reference, foundReference: Reference; symbolReference: SymbolReference;
		BEGIN
			(* go through the list of symbol/offset-combinations and check if there already is an entry for the symbol and offset in question *)
			reference := firstReference;
			WHILE reference # NIL DO
				IF reference IS SymbolReference THEN
				WITH reference: SymbolReference DO
					IF (reference.symbol = symbol) & (reference.symbolOffset = symbolOffset) THEN
						foundReference := reference (* an entry already exists *)
					END;
				END;
				END;
				reference := reference.next
			END;

			IF foundReference # NIL THEN
				reference := foundReference
			ELSE
				(* no entry was found for the symbol/offset combination: create a new one *)
				NEW(symbolReference, symbol, fingerprint, symbolOffset);
				reference := symbolReference;

				IF firstReference = NIL THEN firstReference := reference ELSE lastReference.next := reference END;
				lastReference := reference;

				INC(referenceCount)
			END;

			(* add a citation to the reference *)
			reference.AddCitation(pc);

			IF pcOfFirstCitation = None THEN pcOfFirstCitation := pc END
		END AddSymbol;

		PROCEDURE AddImmediate(value: LONGINT; pc: LONGINT);
		VAR
			reference, foundReference: Reference; immediateReference: ImmediateReference;
		BEGIN
			(* go through the list of symbol/offset-combinations and check if there already is an entry for the symbol and offset in question *)
			reference := firstReference;
			WHILE reference # NIL DO
				IF reference IS ImmediateReference THEN
				WITH reference: ImmediateReference DO
					IF (reference.value = value) THEN
						foundReference := reference (* an entry already exists *)
					END;
				END;
				END;
				reference := reference.next
			END;

			IF foundReference # NIL THEN
				reference := foundReference
			ELSE
				(* no entry was found for the symbol/offset combination: create a new one *)
				NEW(immediateReference, value);
				reference := immediateReference;

				IF firstReference = NIL THEN firstReference := reference ELSE lastReference.next := reference END;
				lastReference := reference;

				INC(referenceCount)
			END;

			(* add a citation to the reference *)
			reference.AddCitation(pc);

			IF pcOfFirstCitation = None THEN pcOfFirstCitation := pc END

		END AddImmediate;


	END ListOfReferences;

	PhysicalRegisters* = OBJECT(CodeGenerators.PhysicalRegisters)
	VAR
		toVirtual: ARRAY InstructionSet.NumberRegisters OF Ticket; (* registers real register -> none / reserved / split / blocked / virtual register (>0) *)
		reserved: ARRAY InstructionSet.NumberRegisters OF BOOLEAN;
		unusable: Ticket;
		hint: LONGINT;
		useFPU: BOOLEAN;

		PROCEDURE & InitPhysicalRegisters(supportFramePointer, useFPU, cooperative: BOOLEAN);
		VAR
			i: LONGINT;
			unusable: Ticket;
		BEGIN
			SELF.useFPU := useFPU;

			FOR i := 0 TO LEN(toVirtual) - 1 DO
				toVirtual[i] := NIL;
				reserved[i] := FALSE
			END;
			NEW(unusable);

			(* reserve special purpose registers *)
			toVirtual[InstructionSet.RES] := unusable; (* low part result register *)
			toVirtual[InstructionSet.RESHI] := unusable; (* high part result register *)
			toVirtual[InstructionSet.RESFS] := unusable; (* single precision floatin point result register *)
			toVirtual[InstructionSet.SP] := unusable; (* stack pointer *)
			toVirtual[InstructionSet.FP] := unusable; (* frame pointer *)
			toVirtual[InstructionSet.PC] := unusable; (* program counter *)
			toVirtual[InstructionSet.LR] := unusable; (* link register *)
			toVirtual[InstructionSet.CPSR] := unusable; (* current program state register *)
			toVirtual[InstructionSet.SPSR] := unusable; (* saved program state register *)

			IF cooperative THEN
				toVirtual[InstructionSet.R11] := unusable; (* current activity register *)
			END;

			(* disable coprocessor registers *)
			FOR i := InstructionSet.CR0 TO InstructionSet.CR15 DO toVirtual[i] := unusable END;

			IF ~useFPU THEN
				(* disable single precision VFP registers *)
				FOR i := InstructionSet.SR0 TO InstructionSet.SR15 DO toVirtual[i] := unusable END
			END;

			(* disable double precision VFP registers *)
			FOR i := InstructionSet.DR0 TO InstructionSet.DR15 DO toVirtual[i] := unusable END;

		END InitPhysicalRegisters;

		(** the number of physical registers **)
		PROCEDURE NumberRegisters(): LONGINT;
		BEGIN RETURN InstructionSet.NumberRegisters
		END NumberRegisters;

		(** allocate, i.e., map, a physical register to a ticket **)
		PROCEDURE Allocate(physicalRegisterNumber: LONGINT; ticket: Ticket);
		BEGIN
			ASSERT(~ticket.spilled);
			Assert(toVirtual[physicalRegisterNumber] = NIL,"register already allocated");
			toVirtual[physicalRegisterNumber] := ticket
		END Allocate;

		(** set whether a certain physical register is reserved or not **)
		PROCEDURE SetReserved(physicalRegisterNumber: LONGINT; isReserved: BOOLEAN);
		BEGIN reserved[physicalRegisterNumber] := isReserved
		END SetReserved;

		(** whether a certain physical register is reserved **)
		PROCEDURE Reserved(physicalRegisterNumber: LONGINT): BOOLEAN;
		BEGIN RETURN (physicalRegisterNumber > 0) & reserved[physicalRegisterNumber]
		END Reserved;

		(** free a certain physical register **)
		PROCEDURE Free(physicalRegisterNumber: LONGINT);
		BEGIN
			Assert((toVirtual[physicalRegisterNumber] # NIL), "register not reserved");
			toVirtual[physicalRegisterNumber] := NIL
		END Free;

		(** get the number of the next free physical register for a certain data type
		- if a register hint has been set, it is respected if possible
		**)
		PROCEDURE NextFree(CONST type: IntermediateCode.Type): LONGINT;
		VAR
			result, i: LONGINT;
		BEGIN
			result := None;

			IF (type.form IN IntermediateCode.Integer) OR ~useFPU THEN
				ASSERT(type.sizeInBits <= 32); (* integers of larger size have already been split *)

				(* allocate a regular general purpose ARM register *)
				FOR i := InstructionSet.R0 TO InstructionSet.R15 DO
					IF (toVirtual[i] = NIL) & ((result = None) OR (i = hint)) THEN result := i END
				END

			ELSIF type.form = IntermediateCode.Float THEN
				IF type.sizeInBits = 32 THEN
					(* allocate a single precision VFP register *)
					FOR i := InstructionSet.SR0 TO InstructionSet.SR31 DO
						IF (toVirtual[i] = NIL) & ((result = None) OR (i = hint)) THEN result := i END
					END
				ELSIF type.sizeInBits = 64 THEN
					(* allocate a double precision VFP register *)
					HALT(200); (* not supported yet *)
				ELSE
					HALT(100)
				END

			ELSE
				HALT(100)
			END;

			IF result # None THEN ASSERT(toVirtual[result] = NIL) END;
			RETURN result
		END NextFree;

		(** give the register allocator a hint on what physical register to use next **)
		PROCEDURE AllocationHint(physicalRegisterNumber: LONGINT);
		BEGIN hint := physicalRegisterNumber
		END AllocationHint;

		(** get the ticket that is currently mapped to a certain physical register **)
		PROCEDURE Mapped(physicalRegisterNumber: LONGINT): Ticket;
		BEGIN RETURN toVirtual[physicalRegisterNumber]
		END Mapped;

		(** dump the current register mapping to a stream **)
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
					w.Ln
				END
			END
		END Dump;

	END PhysicalRegisters;

	CodeGeneratorARM = OBJECT(CodeGenerators.GeneratorWithTickets)
	VAR
		runtimeModuleName: SyntaxTree.IdentifierString;
		backend: BackendARM;

		opSP, opFP, opPC, opLR, opRES, opRESHI, opRESFS: InstructionSet.Operand;

		listOfReferences: ListOfReferences;

		spillStackStart, pushChainLength: LONGINT;

		stackSize: LONGINT; (* the size of the current stack frame *)
		stackSizeKnown: BOOLEAN; (* whether the size of the current stack frame is known at compile time *)

		inStackAllocation: BOOLEAN;

		fixupPattern: ObjectFile.FixupPatterns; (* pattern for an absolute 32-bit fixup *)

		PROCEDURE & InitGeneratorARM(CONST runtimeModuleName: SyntaxTree.IdentifierString; diagnostics: Diagnostics.Diagnostics; backend: BackendARM);
		VAR
			physicalRegisters: PhysicalRegisters;
		BEGIN
			SELF.runtimeModuleName := runtimeModuleName;
			SELF.backend := backend;

			IF Trace THEN IF backend.useFPU THEN D.String("use FPU"); D.Ln ELSE D.String("don't use FPU"); D.Ln END END;

			NEW(physicalRegisters, TRUE, backend.useFPU, backend.cooperative);
			InitTicketGenerator(diagnostics, backend.optimize, 2, physicalRegisters);
			error := FALSE;

			inStackAllocation := FALSE;
			pushChainLength := 0;

			opSP := InstructionSet.NewRegister(InstructionSet.SP, None, None, 0);
			opFP := InstructionSet.NewRegister(InstructionSet.FP, None, None, 0);
			opPC := InstructionSet.NewRegister(InstructionSet.PC, None, None, 0);
			opLR := InstructionSet.NewRegister(InstructionSet.LR, None, None, 0);
			opRES := InstructionSet.NewRegister(InstructionSet.RES, None, None, 0);
			opRESHI := InstructionSet.NewRegister(InstructionSet.RESHI, None, None, 0);
			opRESFS := InstructionSet.NewRegister(InstructionSet.RESFS, None, None, 0);

			dump := NIL;

			NEW(fixupPattern, 1);
			fixupPattern[0].offset := 0;
			fixupPattern[0].bits := 32;

			NEW(listOfReferences);


		END InitGeneratorARM;

		(*------------------- overwritten methods ----------------------*)

		(* TODO: revise this *)
		PROCEDURE Section(in: IntermediateCode.Section; out: BinaryCode.Section);
		VAR
			oldSpillStackSize: LONGINT;

			PROCEDURE CheckEmptySpillStack(): BOOLEAN;
			BEGIN
				IF spillStack.Size() # 0 THEN
					Error(inPC,"implementation error, spill stack not cleared");
					IF dump # NIL THEN
						spillStack.Dump(dump);
						tickets.Dump(dump)
					END;
					RETURN FALSE
				ELSE
					RETURN TRUE
				END
			END CheckEmptySpillStack;

		BEGIN
			stackSizeKnown := TRUE;
			stackSize := 0; (* TODO: ok? *)

			tickets.Init; spillStack.Init; listOfReferences.Init;

			Section^(in, out); (* pass 1 *)
			EmitFinalFixupBlock; (* force the emission of fixups for all references *)

			IF stackSizeKnown = FALSE THEN
				tickets.Init; spillStack.Init; listOfReferences.Init;
				out.Reset;
				Section^(in, out); (* pass 2 *)
				EmitFinalFixupBlock (* force the emission of fixups for all references *)
			END;

			IF CheckEmptySpillStack() & (spillStack.MaxSize() > 0) THEN
				listOfReferences.Init;
				oldSpillStackSize := spillStack.MaxSize();
				out.Reset;
				Section^(in, out); (* pass 3 *)
				EmitFinalFixupBlock; (* force the emission of fixups for all references *)
				ASSERT(spillStack.MaxSize() = oldSpillStackSize);
			END;
			IF CheckEmptySpillStack() THEN END
		END Section;

		(* TODO: complete this *)
		(** whether the code generator can generate code for a certain intermediate code intstruction
		if not, the location of a runtime is returned **)
		PROCEDURE Supported(CONST irInstruction: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			CASE irInstruction.opcode OF
			| IntermediateCode.add, IntermediateCode.sub, IntermediateCode.mul, IntermediateCode.abs, IntermediateCode.neg:
				
				IF (irInstruction.opcode = IntermediateCode.mul) & IsInteger(irInstruction.op1) & IsInteger(irInstruction.op2) & (IsComplex(irInstruction.op1) OR IsComplex(irInstruction.op2)) THEN
					result := FALSE;
				ELSE
					result := backend.useFPU & IsSinglePrecisionFloat(irInstruction.op1) OR ~IsFloat(irInstruction.op1)
				END;

			| IntermediateCode.div:
				result := backend.useFPU & IsSinglePrecisionFloat(irInstruction.op1);
				(*
				result := result OR IntermediateCode.IsConstantInteger(irInstruction.op3,value) & PowerOf2(value,exp)
				*)

			| IntermediateCode.conv:
				result := backend.useFPU & (IsSinglePrecisionFloat(irInstruction.op1) OR IsSinglePrecisionFloat(irInstruction.op2)) OR ~IsFloat(irInstruction.op1) & ~IsFloat(irInstruction.op2) (* if no FPU and either operand is a float *)

			| IntermediateCode.mod:
				result := FALSE;
				(*
				result := IntermediateCode.IsConstantInteger(irInstruction.op3,value) & PowerOf2(value,exp)
				*)

			| IntermediateCode.rol, IntermediateCode.ror:
				result := ~IsComplex(irInstruction.op1)

			ELSE
				result := TRUE
			END;

			IF ~result THEN
				COPY(runtimeModuleName, moduleName);
				GetRuntimeProcedureName(irInstruction, procedureName);
			END;
			RETURN result
		END Supported;

		(* determines the name of a runtime procedure to handle a certain IR instruction *)
		PROCEDURE GetRuntimeProcedureName(CONST irInstruction: IntermediateCode.Instruction; VAR resultingName: ARRAY OF CHAR);

			PROCEDURE AppendType(VAR string: ARRAY OF CHAR; type: IntermediateCode.Type);
			VAR
				sizeString: ARRAY 3 OF CHAR;
			BEGIN
				CASE type.form OF
				| IntermediateCode.SignedInteger: Strings.AppendChar(string, 'S')
				| IntermediateCode.UnsignedInteger: Strings.AppendChar(string, 'U')
				| IntermediateCode.Float:Strings.AppendChar(string, 'F')
				ELSE HALT(200)
				END;
				Strings.IntToStr(type.sizeInBits, sizeString); Strings.Append(string, sizeString)
			END AppendType;

		BEGIN
			COPY(IntermediateCode.instructionFormat[irInstruction.opcode].name, resultingName);
			Strings.UpperCaseChar(resultingName[0]);
			AppendType(resultingName, irInstruction.op1.type);
			IF irInstruction.op1.mode # IntermediateCode.Undefined THEN
				IF (irInstruction.op1.type.form # irInstruction.op2.type.form) OR (irInstruction.op1.type.sizeInBits # irInstruction.op2.type.sizeInBits) THEN
					AppendType(resultingName, irInstruction.op2.type);
				END
			END;

			IF Trace THEN D.Ln; D.String(" runtime procedure name: "); D.String(resultingName); D.Ln; D.Update END
		END GetRuntimeProcedureName;

		(* check whether the instruction modifies the stack pointer (outside of a stack allocation )*)
		PROCEDURE CheckStackPointer(CONST destination: Operand);
		BEGIN
			IF stackSizeKnown & ~inStackAllocation THEN
				IF (destination.mode = InstructionSet.modeRegister) & (destination.register = InstructionSet.SP) THEN
					IF dump # NIL THEN dump.String("stackSize unkown"); dump.Ln END;
					stackSizeKnown := FALSE
				END
			END
		END CheckStackPointer;

		(** emit an ARM instruction with an arbitrary amount of operands **)
		PROCEDURE Emit(opCode, condition: LONGINT; flags: SET; CONST operands: ARRAY InstructionSet.MaxOperands OF Operand);
		VAR
		BEGIN
			(* check whether the instruction modifies the stack pointer *)
			CheckStackPointer(operands[0]);

			(*
			(* dump the instruction *)
			IF Trace THEN
				D.String("opCode="); D.Int(opCode, 0); D.Ln;
				D.String("condition="); D.Int(condition, 0); D.Ln;
				D.String("flags="); D.Set(flags); D.Ln;

				FOR i := 0 TO InstructionSet.MaxOperands - 1 DO
					D.String("operand #"); D.Int(i, 0); D.String(": ");
					InstructionSet.DumpOperand(D.Log, operands[i]);
					D.Ln
				END;
				D.Ln;
				D.Ln
			END;
			*)

			(* emit the instruction *)
			InstructionSet.Emit(opCode, condition, flags, operands, out)
		END Emit;

		(** emit an ARM instruction with no operand **)
		PROCEDURE Emit0(opCode: LONGINT);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := emptyOperand;
			operands[1] := emptyOperand;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit0;

		(** emit an ARM instruction with 1 operand **)
		PROCEDURE Emit1(opCode: LONGINT; op: Operand);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op;
			operands[1] := emptyOperand;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit1;

		(** emit an ARM instruction with 2 operands **)
		PROCEDURE Emit2(opCode: LONGINT; op1, op2: Operand);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit2;

		(** emit an ARM instruction with 3 operands **)
		PROCEDURE Emit3(opCode: LONGINT; op1, op2, op3: Operand);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit3;

		(** emit an ARM instruction with 4 operands **)
		PROCEDURE Emit4(opCode: LONGINT; op1, op2, op3, op4: Operand);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			operands[3] := op4;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit4;

		(** emit an ARM instruction with 6 operands **)
		PROCEDURE Emit6(opCode: LONGINT; op1, op2, op3, op4, op5, op6: Operand);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			operands[3] := op4;
			operands[4] := op5;
			operands[5] := op6;
			Emit(opCode, InstructionSet.unconditional, {}, operands)
		END Emit6;

		(** emit an ARM instruction with 2 operands and certain flags **)
		PROCEDURE Emit2WithFlags(opCode: LONGINT; op1, op2: Operand; flags: SET);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;

			Emit(opCode, InstructionSet.unconditional, flags, operands)
		END Emit2WithFlags;

		(** emit an ARM instruction with 3 operands and certain flags **)
		PROCEDURE Emit3WithFlags(opCode: LONGINT; op1, op2, op3: Operand; flags: SET);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, InstructionSet.unconditional, flags, operands)
		END Emit3WithFlags;

		(** emit an ARM instruction with 1 operand and a condition **)
		PROCEDURE Emit1WithCondition(opCode: LONGINT; op1: Operand; condition: LONGINT);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := emptyOperand;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, condition, {}, operands)
		END Emit1WithCondition;

		(** emit an ARM instruction with 2 operands and a condition **)
		PROCEDURE Emit2WithCondition(opCode: LONGINT; op1, op2: Operand; condition: LONGINT);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := emptyOperand;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, condition, {}, operands)
		END Emit2WithCondition;

		(** emit an ARM instruction with 3 operands and a condition **)
		PROCEDURE Emit3WithCondition(opCode: LONGINT; op1, op2, op3: Operand; condition: LONGINT);
		VAR
			operands: ARRAY InstructionSet.MaxOperands OF Operand;
		BEGIN
			ASSERT(InstructionSet.MaxOperands = 6);
			operands[0] := op1;
			operands[1] := op2;
			operands[2] := op3;
			operands[3] := emptyOperand;
			operands[4] := emptyOperand;
			operands[5] := emptyOperand;
			Emit(opCode, condition, {}, operands)
		END Emit3WithCondition;

		(**
		- generate an arbitrary 32 bit value with as few as possible instructions and move the result into a specified target register
		- return the number of instructions required
		- if 'doEmit' is TRUE, emit the instructions
		**)
		PROCEDURE ValueComposition(value: LONGINT; doEmit: BOOLEAN; CONST targetRegister: Operand): LONGINT;
		VAR
			result: LONGINT;
		BEGIN
			IF doEmit THEN ASSERT(targetRegister.mode = InstructionSet.modeRegister) END;

			IF Trace & doEmit THEN D.Ln; D.String("original value: "); DBin(value, -32); D.String(" ("); D.Int(value, 0); D.String(") "); D.Ln; END;

			IF ValueComposition2(value, FALSE, emptyOperand) <= ValueComposition2(-value, FALSE, emptyOperand) + 1 THEN
				(* more efficient to calculate the value directly *)
				result := ValueComposition2(value, doEmit, targetRegister)
			ELSE
				(* more efficient to calculate the negation of the value and then negate it *)
				result := ValueComposition2(-value, doEmit, targetRegister) + 1;
				IF doEmit THEN
					Emit3(opRSB, targetRegister, targetRegister, InstructionSet.NewImmediate(0))
				END
			END;

			ASSERT((result >= 1) & (result <= 4));
			RETURN result
		END ValueComposition;

		(* note: used by 'ValueComposition'. do not call directly *)
		PROCEDURE ValueComposition2(value: LONGINT; doEmit: BOOLEAN; CONST targetRegister: Operand): LONGINT;
		VAR
			immediateOperand: Operand;
			result, position, partialValue, i: LONGINT;
			valueAsSet: SET;
			isFirst: BOOLEAN;
		BEGIN
			IF doEmit THEN ASSERT(targetRegister.mode = InstructionSet.modeRegister) END;

			IF Trace & doEmit THEN D.String("value to use: "); DBin(value, -32); D.String(" ("); D.Int(value, 0); D.String(") "); D.Ln; END;

			IF (value >= 0) & (value <= 255) THEN
				(* directly encodable as ARM immediate *)
				result := 1;
				IF doEmit THEN
					Emit2(opMOV, targetRegister, InstructionSet.NewImmediate(value))
				END
			ELSE
				valueAsSet := SYSTEM.VAL(SET, value);
				result := 0;
				position := 0;
				isFirst := TRUE;
				WHILE position < 32 DO
					IF (position IN valueAsSet) OR (position + 1 IN valueAsSet) THEN

						(* determine partial value for the 8 bit block *)
						partialValue := 0;
						FOR i := 7 TO 0 BY -1 DO
							partialValue := partialValue * 2;
							IF ((position + i) < 32) & ((position + i) IN valueAsSet) THEN INC(partialValue) END
						END;

						IF Trace & doEmit THEN
							D.String("  block found @ "); D.Int(position, 0); D.Ln;
							D.String("  unshifted partialValue: "); DBin(partialValue, -32); D.String(" ("); D.Int(partialValue, 0); D.String(") "); D.Ln;
							D.String("  shifted partialValue: "); DBin(ASH(partialValue, position), -32); D.String(" ("); D.Int(ASH(partialValue, position), 0); D.String(") "); D.Ln;
						END;
						ASSERT(~ODD(position));

						INC(result);
						IF doEmit THEN
							immediateOperand := InstructionSet.NewImmediate(ASH(partialValue, position)); (* TODO: check shift direction *)
							IF isFirst THEN
								Emit2(opMOV, targetRegister, immediateOperand);
								isFirst := FALSE
							ELSE
								Emit3(opADD, targetRegister, targetRegister, immediateOperand)
							END
						END;

						INC(position, 8)
					ELSE
						INC(position, 2)
					END
				END
			END;

			ASSERT((result >= 1) & (result <= 4));
			RETURN result
		END ValueComposition2;

		(** get the physical register number that corresponds to a virtual register number and part **)
		PROCEDURE PhysicalRegisterNumber(virtualRegisterNumber: LONGINT; part: LONGINT): LONGINT;
		VAR
			ticket: Ticket;
			result: LONGINT;
		BEGIN
			IF virtualRegisterNumber = IntermediateCode.FP THEN
				result := InstructionSet.FP
			ELSIF virtualRegisterNumber = IntermediateCode.SP THEN
				result := InstructionSet.SP
			ELSIF virtualRegisterNumber = IntermediateCode.LR THEN
				result := InstructionSet.LR
			ELSIF virtualRegisterNumber = IntermediateCode.AP THEN
				result := InstructionSet.R11
			ELSE
				ticket := virtualRegisters.Mapped(virtualRegisterNumber, part);
				IF ticket = NIL THEN
					result := None
				ELSE
					result := ticket.register
				END
			END;
			RETURN result
		END PhysicalRegisterNumber;

		(** get an ARM memory operand that represents a spill location (from a ticket) **)
		PROCEDURE GetSpillOperand(ticket: Ticket): Operand;
		VAR
			offset: LONGINT;
			result: Operand;
		BEGIN
			ASSERT(ticket.spilled);

			offset := spillStackStart + ticket.offset + 1; (* TODO: check this *)
			ASSERT((0 <= offset) & (offset < InstructionSet.Bits12));

			result := InstructionSet.NewImmediateOffsetMemory(PhysicalRegisterNumber(IntermediateCode.FP, Low), offset, {InstructionSet.Decrement});

			ASSERT(result.mode = InstructionSet.modeMemory);
			RETURN result
		END GetSpillOperand;

		(** get an ARM operand that represents a certain ticket (might be spilled or not) **)
		PROCEDURE OperandFromTicket(ticket: Ticket): Operand;
		VAR
			result: Operand;
		BEGIN
			ASSERT(ticket # NIL);
			IF ticket.spilled THEN
				(* the ticket is spilled *)
				result := GetSpillOperand(ticket)
			ELSE
				result := InstructionSet.NewRegister(ticket.register, None, None, 0)
			END;
			RETURN result
		END OperandFromTicket;

		(** get a free temporary register that holds data of a certain type **)
		PROCEDURE GetFreeRegister(CONST type: IntermediateCode.Type): Operand;
		VAR
			result: Operand;
		BEGIN
			result := OperandFromTicket(TemporaryTicket(IntermediateCode.GeneralPurposeRegister, type));
			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END GetFreeRegister;

		(** get a new free ARM register
		- if a register hint is provided that can hold data of the required type, it is returned instead
		**)
		PROCEDURE GetFreeRegisterOrHint(CONST type: IntermediateCode.Type; CONST registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			IF (registerHint.mode = InstructionSet.modeRegister) & IsRegisterForType(registerHint.register, type) THEN
				result := registerHint
			ELSE
				result := GetFreeRegister(type)
			END;

			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END GetFreeRegisterOrHint;

		(** whether a register can hold data of a certain IR type **)
		PROCEDURE IsRegisterForType(registerNumber: LONGINT; CONST type: IntermediateCode.Type): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF type.form IN IntermediateCode.Integer THEN
				IF type.sizeInBits <= 32 THEN
					result := (registerNumber >= InstructionSet.R0) & (registerNumber <= InstructionSet.R15)
				END
			ELSIF type.form = IntermediateCode.Float THEN
				IF type.sizeInBits = 32 THEN
					result := (registerNumber >= InstructionSet.SR0) & (registerNumber <= InstructionSet.SR31)
				ELSE
					HALT(200)
				END
			ELSE
				HALT(100)
			END;
			RETURN result
		END IsRegisterForType;

		(** get an ARM register that that is set off by a certain amount **)
		PROCEDURE RegisterAfterAppliedOffset(register: Operand; offset: LONGINT; registerHint: Operand): Operand;
		VAR
			result, offsetOperand: Operand;
		BEGIN
			IF offset = 0 THEN
				result := register
			ELSE
				result := GetFreeRegisterOrHint(IntermediateCode.UnsignedIntegerType(32), registerHint);
				offsetOperand := OperandFromValue(ABS(offset), result); (* might be immediate operand or register (tempRegister is given as a register hint) *)
				IF offset > 0 THEN
					Emit3(opADD, result, register, offsetOperand)
				ELSE
					Emit3(opSUB, result, register, offsetOperand)
				END
			END;
			RETURN result
		END RegisterAfterAppliedOffset;

		(** get an ARM register from an IR register
		- use register hint if provided
		**)
		PROCEDURE RegisterFromIrRegister(CONST irRegisterOperand: IntermediateCode.Operand; part: LONGINT; registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			ASSERT(irRegisterOperand.mode = IntermediateCode.ModeRegister);

			result := InstructionSet.NewRegister(PhysicalRegisterNumber(irRegisterOperand.register, part), None, None, 0);
			result := RegisterAfterAppliedOffset(result, irRegisterOperand.offset, registerHint);

			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END RegisterFromIrRegister;

		PROCEDURE Load(targetRegister, memoryOperand: Operand; irType: IntermediateCode.Type);
		BEGIN
			IF (irType.form IN IntermediateCode.Integer) OR ~(backend.useFPU) THEN
				CASE irType.sizeInBits OF
				| 8: Emit2WithFlags(opLDR, targetRegister, memoryOperand, {InstructionSet.flagB}) (* LDRB *)
				| 16: Emit2WithFlags(opLDR, targetRegister, memoryOperand, {InstructionSet.flagH}) (* LDRH *)
				| 32: (* TM*)
					Emit2(opLDR, targetRegister, memoryOperand)
				ELSE HALT(100)
				END
			ELSIF irType.form = IntermediateCode.Float THEN
				ASSERT(irType.sizeInBits = 32, 200);
				Emit2(opFLDS, targetRegister, memoryOperand)
			ELSE
				HALT(100)
			END
		END Load;

		PROCEDURE Store(sourceRegister, memoryOperand: Operand; type: IntermediateCode.Type);
		BEGIN
			IF (type.form IN IntermediateCode.Integer) OR ~backend.useFPU THEN
				CASE type.sizeInBits OF
				| 8: Emit2WithFlags(opSTR, sourceRegister, memoryOperand, {InstructionSet.flagB}) (* STRB *)
				| 16: Emit2WithFlags(opSTR, sourceRegister, memoryOperand, {InstructionSet.flagH}) (* STRH *)
				| 32: Emit2(opSTR, sourceRegister, memoryOperand)
				ELSE HALT(100)
				END
			ELSIF type.form = IntermediateCode.Float THEN
				ASSERT(type.sizeInBits = 32, 200);
				Emit2(opFSTS, sourceRegister, memoryOperand)
			ELSE
				HALT(100)
			END
		END Store;

		(** get an ARM register that contains the address of a symbol/section
		- use register hint if provided **)
		PROCEDURE RegisterFromSymbol(symbol: Sections.SectionName; fingerprint: LONGINT; resolved: Sections.Section; symbolOffset: LONGINT; CONST registerHint: Operand): Operand;
		VAR
			address: LONGINT;
			result: Operand;
			irSection: IntermediateCode.Section;
		BEGIN
			IF resolved # NIL THEN
				irSection := resolved(IntermediateCode.Section);
			END;

			IF (irSection # NIL) & (irSection.resolved # NIL) & (irSection.resolved.os.fixed) THEN
				(* optimization: if the IR section is already resolved and positioned at a fixed location, no fixup is required *)
				address := irSection.resolved.os.alignment + irSection.instructions[symbolOffset].pc;
				result := RegisterFromValue(address, registerHint)
			ELSE
				result := GetFreeRegisterOrHint(IntermediateCode.UnsignedIntegerType(32), registerHint);
				listOfReferences.AddSymbol(symbol, fingerprint, symbolOffset, out.pc);
				Emit2(opLDR, result, InstructionSet.NewImmediateOffsetMemory(opPC.register, 0, {InstructionSet.Increment})); (* LDR ..., [PC, #+???] *)
			END;

			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END RegisterFromSymbol;

		(** get an ARM memory operand from an IR memory operand
		- note that the constraints on memory operands depend on the type of data (e.g., the allowed offset range is more restricted for memory operands on floating point values)
		**)
		PROCEDURE MemoryOperandFromIrMemoryOperand(VAR irMemoryOperand: IntermediateCode.Operand; part: LONGINT; CONST registerHint: Operand): Operand;
		VAR
			baseAddressRegisterNumber, offset: LONGINT;
			indexingMode: SET;
			result, baseAddressRegister, offsetRegister, tempRegister: Operand;
		BEGIN
			ASSERT(irMemoryOperand.mode = IntermediateCode.ModeMemory);

			(* determine base address register *)
			IF irMemoryOperand.register # IntermediateCode.None THEN
				(* case 1: [r1] or [r1 + 7] *)
				ASSERT(irMemoryOperand.symbol.name = "");
				baseAddressRegisterNumber := PhysicalRegisterNumber(irMemoryOperand.register, Low); (* addresses always are in the lower part *)

			ELSIF irMemoryOperand.symbol.name # "" THEN
				(* case 2: [symbol], [symbol:3], [symbol + 7] or [symbol:3 + 7] *)
				Resolve(irMemoryOperand);
				baseAddressRegister := RegisterFromSymbol(irMemoryOperand.symbol.name, irMemoryOperand.symbol.fingerprint, irMemoryOperand.resolved, irMemoryOperand.symbolOffset, registerHint);
				baseAddressRegisterNumber := baseAddressRegister.register

			ELSE
				(* case 3: [123456] *)
				ASSERT(irMemoryOperand.offset = 0);
				baseAddressRegister := RegisterFromValue(LONGINT(irMemoryOperand.intValue), registerHint);
				baseAddressRegisterNumber := baseAddressRegister.register
			END;
			ASSERT(baseAddressRegisterNumber # None);

			(* get offset of part in question *)
			offset := irMemoryOperand.offset + part * 4;

			(* determine indexing mode *)
			IF offset >= 0 THEN indexingMode := {InstructionSet.Increment} ELSE indexingMode := {InstructionSet.Decrement} END;

			IF irMemoryOperand.type.form IN IntermediateCode.Integer THEN
				(* regular ARM memory operand *)
				(*! LDRH supports only 8 bits immediates, while LDR and LDRB support 12 bits immediates *)
				IF ((irMemoryOperand.type.sizeInBits = 16) & (ABS(offset) < 256)) OR ((irMemoryOperand.type.sizeInBits # 16) & (ABS(offset) < InstructionSet.Bits12)) THEN
					(* offset can be encoded directly *)
					result := InstructionSet.NewImmediateOffsetMemory(baseAddressRegisterNumber, ABS(offset), indexingMode)
				ELSE
					(* offset has to be provided in a register *)
					offsetRegister := RegisterFromValue(ABS(offset), emptyOperand);
					result := InstructionSet.NewRegisterOffsetMemory(baseAddressRegisterNumber, offsetRegister.register, None, 0, indexingMode)
				END
			ELSIF irMemoryOperand.type.form = IntermediateCode.Float THEN
				(* VFP memory operand *)
				ASSERT((ABS(offset) MOD 4) = 0);
				IF ABS(offset) >= 1024 THEN
					(* offset cannot be encoded directly _> it has to be provided by means of an adapted base register *)
					tempRegister := RegisterFromValue(ABS(offset), emptyOperand);
					IF offset < 0 THEN
						Emit3(opSUB, tempRegister, tempRegister, baseAddressRegister)
					ELSE
						Emit3(opADD, tempRegister, tempRegister, baseAddressRegister)
					END;
					ReleaseHint(baseAddressRegister.register);
					baseAddressRegister := tempRegister;
					baseAddressRegisterNumber := baseAddressRegister.register;
					offset := 0;
				END;
				result := InstructionSet.NewImmediateOffsetMemory(baseAddressRegisterNumber, ABS(offset), indexingMode)
			ELSE
				HALT(100)
			END;

			ASSERT(result.mode = InstructionSet.modeMemory);
			RETURN result
		END MemoryOperandFromIrMemoryOperand;

		(** get an ARM immediate operand or register from any IR operand
		- if possible, the an immediate is returned
		- if needed, use register hint if provided
		**)
		PROCEDURE RegisterOrImmediateFromIrOperand(VAR irOperand: IntermediateCode.Operand; part: LONGINT; registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			IF IrOperandIsDirectlyEncodable(irOperand, part) THEN
				result := InstructionSet.NewImmediate(ValueOfPart(irOperand.intValue, part))
			ELSE
				result := RegisterFromIrOperand(irOperand, part, registerHint)
			END;
			RETURN result
		END RegisterOrImmediateFromIrOperand;

		(** get an ARM register operand from any IR operand
		- use register hint if provided
		**)
		PROCEDURE RegisterFromIrOperand(VAR irOperand: IntermediateCode.Operand; part: LONGINT; registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			CASE irOperand.mode OF
			| IntermediateCode.ModeRegister:
				ASSERT((irOperand.intValue = 0) & (irOperand.symbol.name = ""));
				result := RegisterFromIrRegister(irOperand, part, registerHint)

			| IntermediateCode.ModeMemory:
				result := GetFreeRegisterOrHint(PartType(irOperand.type, part), registerHint);
				Load(result, MemoryOperandFromIrMemoryOperand(irOperand, part, result), PartType(irOperand.type, part))

			| IntermediateCode.ModeImmediate:
				ASSERT(irOperand.register = IntermediateCode.None);
				IF irOperand.symbol.name # "" THEN
					Resolve(irOperand);
					result := RegisterFromSymbol(irOperand.symbol.name, irOperand.symbol.fingerprint, irOperand.resolved, irOperand.symbolOffset, emptyOperand);
					result := RegisterAfterAppliedOffset(result, irOperand.offset, registerHint);
				ELSE
					ASSERT(irOperand.offset = 0);
					IF IsInteger(irOperand) THEN result := RegisterFromValue(ValueOfPart(irOperand.intValue, part), registerHint)
					ELSIF ~backend.useFPU THEN
						IF IsSinglePrecisionFloat(irOperand) THEN
							result := RegisterFromValue(BinaryCode.ConvertReal(SHORT(irOperand.floatValue)), registerHint)
						ELSE
							result := RegisterFromValue(ValueOfPart(BinaryCode.ConvertLongreal(irOperand.floatValue),part), registerHint);
						END;
					ELSIF IsSinglePrecisionFloat(irOperand) THEN result := SinglePrecisionFloatRegisterFromValue(REAL(irOperand.floatValue), registerHint)
					ELSE HALT(200)
					END

				END

			ELSE
				HALT(100)
			END;

			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END RegisterFromIrOperand;

		(** whether an IR operand is complex, i.e., requires more than one ARM operands to be represented **)
		PROCEDURE IsComplex(CONST irOperand: IntermediateCode.Operand): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			IF (irOperand.type.form IN IntermediateCode.Integer) OR ~backend.useFPU THEN
				result := irOperand.type.sizeInBits > 32 (* integers above 32 bits have to be represented in multiple registers *)
			ELSIF irOperand.type.form = IntermediateCode.Float THEN
				result := FALSE (* for all types of floating point numbers there are dedicated VFP registers *)
			ELSE
				HALT(100)
			END;
			RETURN result
		END IsComplex;

		(** whether an IR operand hold a single precision floating point value **)
		PROCEDURE IsSinglePrecisionFloat(CONST irOperand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN (irOperand.type.sizeInBits = 32) & (irOperand.type.form = IntermediateCode.Float)
		END IsSinglePrecisionFloat;

		(** whether an IR operand hold a single precision floating point value **)
		PROCEDURE IsDoublePrecisionFloat(CONST irOperand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN (irOperand.type.sizeInBits = 64) & (irOperand.type.form = IntermediateCode.Float)
		END IsDoublePrecisionFloat;

		PROCEDURE IsFloat(CONST irOperand: IntermediateCode.Operand): BOOLEAN;
		BEGIN
			RETURN irOperand.type.form = IntermediateCode.Float
		END IsFloat;


		(** whether an IR operand hold am integer value **)
		PROCEDURE IsInteger(CONST irOperand: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN irOperand.type.form IN IntermediateCode.Integer
		END IsInteger;

		PROCEDURE PartType(CONST type: IntermediateCode.Type; part: LONGINT): IntermediateCode.Type;
		VAR
			result: IntermediateCode.Type;
		BEGIN
			GetPartType(type, part, result);
			RETURN result
		END PartType;

		(* the intermediate code type of a part
		- a part type is by definition directly representable in a register *)
		PROCEDURE GetPartType(CONST type: IntermediateCode.Type; part: LONGINT; VAR partType: IntermediateCode.Type);
		BEGIN
			ASSERT((part = Low) OR (part = High));
			IF (type.form = IntermediateCode.Float) & backend.useFPU THEN
				IF part = Low THEN
					partType := type
				ELSE
					partType := IntermediateCode.undef
				END
			ELSIF (type.form IN IntermediateCode.Integer) OR ~backend.useFPU THEN
				IF type.sizeInBits <= 32 THEN
					IF part = Low THEN
						partType := type
					ELSE
						partType := IntermediateCode.undef
					END
				ELSIF type.sizeInBits = 64 THEN
					IF part = Low THEN
						partType := IntermediateCode.NewType(IntermediateCode.UnsignedInteger, 32) (* conceptually the low part is always unsigned *)
					ELSE
						partType := IntermediateCode.NewType(type.form, 32)
					END
				ELSE
					HALT(100)
				END
			ELSE
				HALT(100)
			END
		END GetPartType;

		(** the value of a 32 bit part **)
		PROCEDURE ValueOfPart(value: HUGEINT; part: LONGINT): LONGINT;
		VAR
			result: LONGINT;
		BEGIN
			IF part = Low THEN
				result := LONGINT(value) (* get the 32 least significant bits *)
			ELSIF part = High THEN
				result := LONGINT(ASH(value, -32)) (* get the 32 most significant bits *)
			ELSE
				HALT(100)
			END;
			RETURN result
		END ValueOfPart;

		(** whether a 32 bit value can be directly encoded as an ARM immediate (using a 8-bit base value and 4-bit half rotation) **)
		PROCEDURE ValueIsDirectlyEncodable(value: LONGINT): BOOLEAN;
		VAR
			baseValue, halfRotation: LONGINT;
			result: BOOLEAN;
		BEGIN
			result := InstructionSet.EncodeImmediate(value, baseValue, halfRotation);
			RETURN result
		END ValueIsDirectlyEncodable;

		(* whether an IR operand (or part thereof) can be directly encoded as an ARM immediate *)
		PROCEDURE IrOperandIsDirectlyEncodable(irOperand: IntermediateCode.Operand; part: LONGINT): BOOLEAN;
		BEGIN RETURN
				(irOperand.mode = IntermediateCode.ModeImmediate) &
				(irOperand.symbol.name = "") &
				(irOperand.type.form IN IntermediateCode.Integer) &
				ValueIsDirectlyEncodable(ValueOfPart(irOperand.intValue, part))
		END IrOperandIsDirectlyEncodable;

		(* whether the negation of an IR operand (or part thereof) can be directly encoded as an ARM immediate *)
		PROCEDURE NegatedIrOperandIsDirectlyEncodable(irOperand: IntermediateCode.Operand; part: LONGINT): BOOLEAN;
		BEGIN RETURN
				(irOperand.mode = IntermediateCode.ModeImmediate) &
				(irOperand.symbol.name = "") &
				(irOperand.type.form IN IntermediateCode.Integer) &
				ValueIsDirectlyEncodable(ValueOfPart(-irOperand.intValue, part)) (* note the minus sign *)
		END NegatedIrOperandIsDirectlyEncodable;

		(** generate code for a certain IR instruction **)
		PROCEDURE Generate(VAR irInstruction: IntermediateCode.Instruction);
		BEGIN
			(* CheckFixups; *)
			EmitFixupBlockIfNeeded;

			(*
			IF ((irInstruction.opcode = IntermediateCode.mov) OR (irInstruction.opcode = IntermediateCode.pop)) & (instruction.op1.register <= IntermediateCode.ParameterRegister) THEN
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

			ReserveOperandRegisters(irInstruction.op1, TRUE);
			ReserveOperandRegisters(irInstruction.op2, TRUE);
			ReserveOperandRegisters(irInstruction.op3, TRUE);

			CASE irInstruction.opcode OF
			| IntermediateCode.nop: (* do nothing *)
			| IntermediateCode.mov: EmitMov(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitMov(irInstruction, High) END
			| IntermediateCode.conv: EmitConv(irInstruction)
			| IntermediateCode.call: EmitCall(irInstruction)
			| IntermediateCode.enter: EmitEnter(irInstruction)
			| IntermediateCode.leave: EmitLeave(irInstruction)
			| IntermediateCode.exit: EmitExit(irInstruction)
			| IntermediateCode.return: EmitReturn(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitReturn(irInstruction, High) END;
			| IntermediateCode.result: EmitResult(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitResult(irInstruction, High) END;
			| IntermediateCode.trap: EmitTrap(irInstruction);
			| IntermediateCode.br .. IntermediateCode.brlt: EmitBr(irInstruction)
			| IntermediateCode.pop: EmitPop(irInstruction.op1, Low); IF IsComplex(irInstruction.op1) THEN EmitPop(irInstruction.op1, High) END
			| IntermediateCode.push: IF IsComplex(irInstruction.op1) THEN EmitPush(irInstruction.op1, High) END; EmitPush(irInstruction.op1, Low)
			| IntermediateCode.neg: EmitNeg(irInstruction)
			| IntermediateCode.not: EmitNot(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitNot(irInstruction, High) END
			| IntermediateCode.abs: EmitAbs(irInstruction)
			| IntermediateCode.mul: EmitMul(irInstruction)
			| IntermediateCode.div: EmitDiv(irInstruction)
			| IntermediateCode.mod: EmitMod(irInstruction)
			| IntermediateCode.sub, IntermediateCode.add: EmitAddOrSub(irInstruction)
			| IntermediateCode.and: EmitAnd(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitAnd(irInstruction, High) END
			| IntermediateCode.or: EmitOr(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitOr(irInstruction, High) END
			| IntermediateCode.xor: EmitXor(irInstruction, Low); IF IsComplex(irInstruction.op1) THEN EmitXor(irInstruction, High) END
			| IntermediateCode.shl: EmitShiftOrRotation(irInstruction)
			| IntermediateCode.shr: EmitShiftOrRotation(irInstruction)
			| IntermediateCode.rol: EmitShiftOrRotation(irInstruction)
			| IntermediateCode.ror: EmitShiftOrRotation(irInstruction)
			| IntermediateCode.cas: EmitCas(irInstruction);
			| IntermediateCode.copy: EmitCopy(irInstruction)
			| IntermediateCode.fill: EmitFill(irInstruction, FALSE)
			| IntermediateCode.asm: EmitAsm(irInstruction)
			| IntermediateCode.special: EmitSpecial(irInstruction)
			END;

			ReserveOperandRegisters(irInstruction.op3, FALSE);
			ReserveOperandRegisters(irInstruction.op2 ,FALSE);
			ReserveOperandRegisters(irInstruction.op1, FALSE);

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

		PROCEDURE EmitFinalFixupBlock;
		BEGIN
			IF listOfReferences.referenceCount > 0 THEN
				ASSERT(in.pc > 0);
				IF in.instructions[in.pc - 1].opcode # IntermediateCode.exit THEN
					(* there is no exit instruction at the end of the IR section -> emit a branch that skips the fixup block (in particular used by @BodyStub procedures)*)
					Emit1(opB, InstructionSet.NewImmediate((listOfReferences.referenceCount + 1) * 4 - 8))
				END
			END;
			EmitFixupBlock; (* emit the fixup block *)
		END EmitFinalFixupBlock;

		(* if needed, emit fixup block for all used symbol references
		 - the fixup block is skipped by a branch instruction
		 - afterwards, the list of references is cleared
		*)
		PROCEDURE EmitFixupBlockIfNeeded;
		BEGIN
			IF out.pc - listOfReferences.pcOfFirstCitation + listOfReferences.referenceCount + 1 > MaximumFixupDistance THEN
				Emit1(opB, InstructionSet.NewImmediate((listOfReferences.referenceCount + 1) * 4 - 8)); (* emit branch instruction that skips the fixup block *)
				EmitFixupBlock; (* emit the fixup block *)
				listOfReferences.Init (* clear the list *)
			END
		END EmitFixupBlockIfNeeded;

		(* emit fixup block for all used symbol references, and clear the list *)
		PROCEDURE EmitFixupBlock;
		VAR
			reference: Reference;
			citation: Citation;
			fixup: BinaryCode.Fixup;
			patchValue: LONGINT;
			identifier: ObjectFile.Identifier;
		BEGIN
			IF listOfReferences.referenceCount > 0 THEN
				IF out.comments # NIL THEN
					out.comments.String("REFERENCES BLOCK"); out.comments.String(" (");
					out.comments.Int(listOfReferences.referenceCount, 0);
					out.comments.String(" references):"); out.comments.Ln; out.comments.Update
				END;

				reference := listOfReferences.firstReference;
				WHILE reference # NIL DO
					(* 1. patch all of the citations, i.e., the LDR instructions that use the symbol reference *)
					citation := reference.firstCitation;
					WHILE citation # NIL DO
						patchValue := out.pc - 8 - citation.pc;
						ASSERT((0 <= patchValue) & (patchValue < InstructionSet.Bits12));
						out.PutBitsAt(citation.pc, patchValue, 12);
						citation := citation.next
					END;

					IF reference IS SymbolReference THEN
					WITH reference: SymbolReference DO

						(* alternative version that relies on the fixup mechanism:
						NEW(fixupPattern12, 1);
						fixupPattern12[0].offset := 0;
						fixupPattern12[0].bits := 12;
						fixup := BinaryCode.NewFixup(BinaryCode.Relative, entry.pc, in, 0, out.pc - 8, 0, fixupPattern12); (* TODO: determine the correct displacement *)
						out.fixupList.AddFixup(fixup);
						*)

						(* 2. add an absolute fixup for the symbol reference and emit space *)
						IF out.comments # NIL THEN
							out.comments.String("fixup location for ");
							Basic.WriteSegmentedName(out.comments, reference.symbol);
							out.comments.String(":"); out.comments.Int(reference.symbolOffset, 0);
							out.comments.String(" :"); out.comments.Ln; out.comments.Update
						END;
						identifier.name := reference.symbol;
						identifier.fingerprint := reference.fingerprint;

						fixup := BinaryCode.NewFixup(BinaryCode.Absolute, out.pc, identifier, reference.symbolOffset, 0, 0, fixupPattern);
						out.fixupList.AddFixup(fixup);
						out.PutBits(0, 32);
					END;
					ELSIF reference IS ImmediateReference THEN
					WITH reference: ImmediateReference DO
						IF out.comments # NIL THEN
							out.comments.String("immediate value"); out.comments.Ln; out.comments.Update;
						END;
						out.PutBits(reference.value,32);
					END
					END;

					reference := reference.next
				END
			END
		END EmitFixupBlock;

		(** get an ARM operand that hold a certain value
		- if possible the value is returned as an ARM immediate operand
		- otherwise a register is returned instead (if a register hint is present, it is used) **)
		PROCEDURE OperandFromValue(value: LONGINT; registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			IF ValueIsDirectlyEncodable(value) THEN
				result := InstructionSet.NewImmediate(value)
			ELSE
				result := RegisterFromValue(value, registerHint)
			END;
			RETURN result
		END OperandFromValue;

		(** get a single precision VFP register that holds a certain floating point value **)
		PROCEDURE SinglePrecisionFloatRegisterFromValue(value: REAL; registerHint: Operand): Operand;
		VAR
			intValue, dummy: LONGINT;
			result, temp: Operand;
		BEGIN
			intValue := SYSTEM.VAL(LONGINT, value);
			(* alternative: integerValue := BinaryCode.ConvertReal(value) *)

			temp := GetFreeRegisterOrHint(IntermediateCode.UnsignedIntegerType(32), registerHint);
			dummy := ValueComposition(intValue, TRUE, temp);
			result := GetFreeRegisterOrHint(IntermediateCode.FloatType(32), registerHint);
			Emit2(opFMSR, result, temp);

			ASSERT(result.mode = InstructionSet.modeRegister);
			ASSERT((result.register >= InstructionSet.SR0) & (result.register <= InstructionSet.SR31));
			RETURN result;
		END SinglePrecisionFloatRegisterFromValue;

		(** get an ARM register that holds a certain integer value
		- if a register hint is present, it is used **)
		PROCEDURE RegisterFromValue(value: LONGINT; registerHint: Operand): Operand;
		VAR
			dummy: LONGINT;
			result: Operand;
		BEGIN
			result := GetFreeRegisterOrHint(IntermediateCode.SignedIntegerType(32), registerHint);
			IF ValueComposition(value, FALSE, result) < 3 THEN
				dummy := ValueComposition(value, TRUE, result);
			ELSE
				result := GetFreeRegisterOrHint(IntermediateCode.UnsignedIntegerType(32), registerHint);
				listOfReferences.AddImmediate(value, out.pc);
				Emit2(opLDR, result, InstructionSet.NewImmediateOffsetMemory(opPC.register, 0, {InstructionSet.Increment})); (* LDR ..., [PC, #+???] *)
			END;

			ASSERT(result.mode = InstructionSet.modeRegister);
			ASSERT((result.register >= InstructionSet.R0) & (result.register <= InstructionSet.R15));
			RETURN result
		END RegisterFromValue;

		(** allocate or deallocate on the stack
			- note: updateStackSize is important as intermediate RETURNs should not change stack size
		**)
		PROCEDURE AllocateStack(allocationSize: LONGINT; doUpdateStackSize: BOOLEAN; clear: BOOLEAN);
		VAR
			operand, zero, count: InstructionSet.Operand; i: LONGINT;
		BEGIN
			inStackAllocation := TRUE;
			operand := OperandFromValue(ABS(allocationSize), emptyOperand);
			IF allocationSize > 0 THEN
				IF clear THEN
					zero := InstructionSet.NewRegister(0, None, None, 0);
					Emit2(opMOV, zero , InstructionSet.NewImmediate(0));
					IF allocationSize < 16 THEN
						FOR i := 0 TO allocationSize-1 BY 4 DO
							Emit2(opSTR, InstructionSet.NewRegister(0, None, None, 0), InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Decrement, InstructionSet.PreIndexed}));
						END;
					ELSE
						count := InstructionSet.NewRegister(1, None, None, 0);
						Emit1(opB, InstructionSet.NewImmediate(0)); (* PC offset = 8 !  Jump over immediate *)
						out.PutBits(allocationSize DIV 4, 32);
						Emit2(opLDR, count, InstructionSet.NewImmediateOffsetMemory(InstructionSet.PC, 8+4, {InstructionSet.Decrement}));
						(* label *)
						Emit2(opSTR, zero, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Decrement, InstructionSet.PreIndexed}));
						Emit3WithFlags(opSUB, count, count, InstructionSet.NewImmediate(1),{InstructionSet.flagS});
						Emit1WithCondition(opB, InstructionSet.NewImmediate(-8 -8), InstructionSet.conditionGT); (* label *)
					END;
				ELSE
					Emit3(opSUB, opSP, opSP, operand) (* decreasing SP: allocation *)
				END;
			ELSIF allocationSize < 0 THEN
				Emit3(opADD, opSP, opSP, operand) (* increasing SP: deallocation *)
			END;
			IF doUpdateStackSize THEN stackSize := stackSize + allocationSize END;
			inStackAllocation := FALSE
		END AllocateStack;

		(** whether two ARM operands represent the same physical register **)
		PROCEDURE IsSameRegister(CONST a, b: Operand): BOOLEAN;
		BEGIN RETURN (a.mode = InstructionSet.modeRegister) & (b.mode = InstructionSet.modeRegister) & (a.register = b.register)
		END IsSameRegister;

		(** emit a MOV instruction if the two operands do not represent the same register
		- for moves involving floating point registers special VFP instructions opFCPYS, opFMSR and opFMRS are used
		**)
		PROCEDURE MovIfDifferent(CONST a, b: Operand);
		BEGIN
			IF ~IsSameRegister(a, b) THEN
				ASSERT(a.mode = InstructionSet.modeRegister);

				IF IsRegisterForType(a.register, IntermediateCode.FloatType(32)) THEN
					IF IsRegisterForType(b.register, IntermediateCode.FloatType(32)) THEN
						(* mov float, float: *)
						Emit2(opFCPYS, a, b)
					ELSE
						(* mov float, int: *)
						Emit2(opFMSR, a, b)
					END
				ELSE
					IF IsRegisterForType(b.register, IntermediateCode.FloatType(32)) THEN
						(* mov int, float: *)
						Emit2(opFMRS, a, b)
					ELSE
						(* mov int, int: *)
						Emit2(opMOV, a, b)
					END
				END
			END
		END MovIfDifferent;

		(** acquire an ARM register fr oa IR destination operand part
			- if IR operand is a memory location, get a temporary register (if provided the hinted register is used)
			- if IR operand is an IR register, get the ARM register that is mapped to the corresponding part
		**)
		PROCEDURE AcquireDestinationRegister(CONST irDestinationOperand: IntermediateCode.Operand; part: LONGINT; registerHint: Operand): Operand;
		VAR
			result: Operand;
		BEGIN
			IF irDestinationOperand.mode = IntermediateCode.ModeMemory THEN
				result := GetFreeRegisterOrHint(PartType(irDestinationOperand.type, part), registerHint)
			ELSIF irDestinationOperand.mode = IntermediateCode.ModeRegister THEN
				ASSERT(irDestinationOperand.offset = 0);
				IF virtualRegisters.Mapped(irDestinationOperand.register, part) = NIL THEN TryAllocate(irDestinationOperand, part) END; (* create the mapping if not yet done *)
				result := InstructionSet.NewRegister(PhysicalRegisterNumber(irDestinationOperand.register, part), None, None, 0)
			ELSE
				HALT(100)
			END;

			ASSERT(result.mode = InstructionSet.modeRegister);
			RETURN result
		END AcquireDestinationRegister;

		(** write the content of an ARM register to an IR destination operand (memory location or IR register)
			- afterwards, try to release the register
		**)
		PROCEDURE WriteBack(VAR irDestinationOperand: IntermediateCode.Operand; part: LONGINT; register: Operand);
		VAR
			mappedArmRegister: Operand;
		BEGIN
			ASSERT(register.mode = InstructionSet.modeRegister);

			IF irDestinationOperand.mode = IntermediateCode.ModeMemory THEN
				Store(register, MemoryOperandFromIrMemoryOperand(irDestinationOperand, part, emptyOperand), PartType(irDestinationOperand.type, part))
			ELSIF irDestinationOperand.mode = IntermediateCode.ModeRegister THEN
				ASSERT((virtualRegisters.Mapped(irDestinationOperand.register, part) # NIL)
						OR (irDestinationOperand.register = IntermediateCode.SP)
						OR (irDestinationOperand.register = IntermediateCode.FP)
						OR (irDestinationOperand.register = IntermediateCode.LR)
						OR (irDestinationOperand.register = IntermediateCode.AP));
				mappedArmRegister := InstructionSet.NewRegister(PhysicalRegisterNumber(irDestinationOperand.register, part), None, None, 0);
				MovIfDifferent(mappedArmRegister, register)
			ELSE
				HALT(100)
			END;

			ReleaseHint(register.register)
		END WriteBack;

		PROCEDURE ZeroExtendOperand(operand: Operand; sizeInBits: LONGINT);
		BEGIN
			ASSERT(sizeInBits <= 32);
			IF operand.mode = InstructionSet.modeRegister THEN
				IF sizeInBits = 8 THEN
					Emit3(opAND, operand, operand, InstructionSet.NewImmediate(255)); (* AND reg, reg, 11111111b *)
				ELSIF sizeInBits = 16 THEN
					Emit2(opMOV, operand, InstructionSet.NewRegister(operand.register, InstructionSet.shiftLSL, None, 16));
					Emit2(opMOV, operand, InstructionSet.NewRegister(operand.register, InstructionSet.shiftLSR, None, 16))
				ELSIF sizeInBits = 32 THEN
					(* nothing to do *)
				ELSE
					HALT(100)
				END
			END
		END ZeroExtendOperand;

		PROCEDURE SignExtendOperand(operand: Operand; sizeInBits: LONGINT);
		BEGIN
			ASSERT(sizeInBits <= 32);
			IF operand.mode = InstructionSet.modeRegister THEN
				IF sizeInBits < 32 THEN
					Emit2(opMOV, operand, InstructionSet.NewRegister(operand.register, InstructionSet.shiftLSL, None, 32 - sizeInBits));
					Emit2(opMOV, operand, InstructionSet.NewRegister(operand.register, InstructionSet.shiftASR, None, 32 - sizeInBits))
				END
			END
		END SignExtendOperand;

		(** sign or zero-extends the content of an operand to 32 bits, depending on the IR type **)
		PROCEDURE SignOrZeroExtendOperand(operand: Operand; irType: IntermediateCode.Type);
		BEGIN
			ASSERT(irType.sizeInBits <= 32);
			IF irType.form = IntermediateCode.UnsignedInteger THEN
				ZeroExtendOperand(operand, irType.sizeInBits)
			ELSE
				SignExtendOperand(operand, irType.sizeInBits)
			END
		END SignOrZeroExtendOperand;

		(* ACTUAL CODE GENERATION *)

		PROCEDURE EmitPush(VAR irOperand: IntermediateCode.Operand; part: LONGINT);
		VAR
			register: Operand;
			partType: IntermediateCode.Type;
			(*pc: LONGINT;*)
		BEGIN
			register := RegisterFromIrOperand(irOperand, part, emptyOperand);
			IF ~IsRegisterForType(register.register, IntermediateCode.FloatType(32)) THEN
				Emit2(opSTR, register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Decrement, InstructionSet.PreIndexed}));
			ELSE
				partType := PartType(irOperand.type, part);
				AllocateStack(MAX(4, partType.sizeInBits DIV 8), TRUE,FALSE);
				Store(register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 0, {InstructionSet.Increment}), PartType(irOperand.type, part));
			END;

			(*
			(* optimization for push chains (THIS DOES NOT WORK IF inEmulation) *)
			IF pushChainLength = 0 THEN
				pc := inPC;
				(* search for consecutive push instructions *)
				WHILE (pc < in.pc) & (in.instructions[pc].opcode = IntermediateCode.push) DO
					ASSERT(in.instructions[pc].op1.mode # IntermediateCode.Undefined);
					INC(pushChainLength, MAX(4, in.instructions[pc].op1.type.sizeInBits DIV 8));
					INC(pc)
				END;
				AllocateStack(pushChainLength, TRUE)
			END;

			DEC(pushChainLength, 4); (* for 64 bit operands, this procedure is executed twice -> the push chain will be decremented by 8 bytes *)
			register := RegisterFromIrOperand(irOperand, part, emptyOperand);
			ASSERT(pushChainLength < InstructionSet.Bits12, 100);
			ASSERT((pushChainLength MOD 4) = 0);
			Store(register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, pushChainLength, {InstructionSet.Increment}), PartType(irOperand.type, part))
			*)

		END EmitPush;

		PROCEDURE EmitPop(VAR irOperand: IntermediateCode.Operand; part: LONGINT);
		VAR
			register: Operand; partType: IntermediateCode.Type;
		BEGIN
			register := AcquireDestinationRegister(irOperand, part, emptyOperand);
			IF ~IsRegisterForType(register.register, IntermediateCode.FloatType(32)) THEN
				(*Emit2(opLDR, register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Increment, InstructionSet.PostIndexed}));*)
				Load(register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Increment, InstructionSet.PostIndexed}), PartType(irOperand.type, part));

			ELSE
				Load(register, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 0, {InstructionSet.Increment}), PartType(irOperand.type, part));
				partType := PartType(irOperand.type, part);
				AllocateStack(-MAX(4, partType.sizeInBits DIV 8), TRUE,FALSE);
			END;
			WriteBack(irOperand, part, register)
		END EmitPop;

		PROCEDURE Resolve(VAR op: IntermediateCode.Operand);
		BEGIN
			IF (op.symbol.name # "") & (op.resolved = NIL) THEN op.resolved := module.allSections.FindByName(op.symbol.name) END
		END Resolve;


		(* call <address>, <parSize> *)
		PROCEDURE EmitCall(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			code: BinaryCode.Section;
			fixup, newFixup: BinaryCode.Fixup;
		BEGIN
			Resolve(irInstruction.op1);
			IF (irInstruction.op1.resolved # NIL) & (irInstruction.op1.resolved.type = Sections.InlineCodeSection) THEN
				(* call of an inline procedure: *)

				code := irInstruction.op1.resolved(IntermediateCode.Section).resolved;
				ASSERT(code # NIL); (* TODO: what if section is not yet resolved, i.e., code has not yet been generated? *)

				IF (out.comments # NIL) THEN
					out.comments.String("inlined code sequence:");
					out.comments.Ln;
					out.comments.Update;
				END;

				(* emit the generated code of the other section *)
				out.CopyBits(code.os.bits, 0, code.os.bits.GetSize());

				(* transfer the fixups *)
				fixup := code.fixupList.firstFixup;
				WHILE fixup # NIL DO
					newFixup := BinaryCode.NewFixup(fixup.mode, fixup.offset + code.pc, fixup.symbol, fixup.symbolOffset, fixup.displacement, fixup.scale, fixup.pattern);
					out.fixupList.AddFixup(newFixup);
					fixup := fixup.nextFixup
				END
			ELSE
				(* store the address of the procedure in a register and branch and link there *)
				Emit1(opBLX, RegisterFromIrOperand(irInstruction.op1, Low, emptyOperand));

				(* remove parameters on stack *)
				AllocateStack(-LONGINT(irInstruction.op2.intValue), TRUE, FALSE)
			END
		END EmitCall;

		(* enter <callingConvention>, <pafSize>, <numRegParams> *)
		PROCEDURE EmitEnter(CONST irInstruction: IntermediateCode.Instruction);
		VAR allocationSize: LONGINT;
		BEGIN
			(* store registers for interrupts, if required *)
			IF (irInstruction.op1.intValue = SyntaxTree.InterruptCallingConvention) THEN (* TODO: needed? *)
				(* push R0-R11, FP and LR *)
				Emit2WithFlags(opSTM, opSP, InstructionSet.NewRegisterList(0, {InstructionSet.FP, InstructionSet.LR, 0..11}), {InstructionSet.flagDB, InstructionSet.flagBaseRegisterUpdate});
				Emit2(opMOV, opFP, opSP);
			END;
			stackSize := 0;
			(* allocate space on stack for local variables *)
			allocationSize := LONGINT(irInstruction.op2.intValue);
			Basic.Align(allocationSize, 4); (* 4 byte alignment *)
			AllocateStack(allocationSize, TRUE, backend.initLocals);
			(* allocate space on stack for register spills *)
			spillStackStart := -stackSize; 
			IF spillStack.MaxSize() > 0 THEN AllocateStack(spillStack.MaxSize(), TRUE, FALSE) END
		END EmitEnter;

		(* leave <callingConvention> *)
		PROCEDURE EmitLeave(CONST irInstruction: IntermediateCode.Instruction);
		BEGIN
			(* LDMFD (Full Descending) aka LDMIA (Increment After) *)
			IF (irInstruction.op1.intValue = SyntaxTree.InterruptCallingConvention) THEN
				(* pop R0-R11, FP and LR *)
				Emit2(opMOV, opSP, opFP);
				Emit2WithFlags(opLDM, opSP, InstructionSet.NewRegisterList(0, {InstructionSet.FP, InstructionSet.LR, 0..11}), {InstructionSet.flagIA, InstructionSet.flagBaseRegisterUpdate})
			END
		END EmitLeave;

		(* exit <parSize>, <pcOffset> *)
		PROCEDURE EmitExit(CONST irInstruction: IntermediateCode.Instruction);
		BEGIN
			Emit2(opLDR, opLR, InstructionSet.NewImmediateOffsetMemory(InstructionSet.SP, 4, {InstructionSet.Increment, InstructionSet.PostIndexed}));
			IF (irInstruction.op1.intValue = 0) & (irInstruction.op2.intValue # SyntaxTree.InterruptCallingConvention) THEN
				(* Emit2(opMOV, opPC, opLR) *)
				Emit1(opBX, opLR) (* recommended for better interoperability between ARM and Thumb *)
			ELSE
				IF (irInstruction.op2.intValue = SyntaxTree.InterruptCallingConvention) THEN
					Emit3WithFlags(opSUB, opPC, opLR, InstructionSet.NewImmediate(LONGINT(irInstruction.op1.intValue)),{InstructionSet.flagS})
				ELSE
				(* exit from an ARM interrupt procedure that has a PC offset *)
					Emit3(opSUB, opPC, opLR, InstructionSet.NewImmediate(LONGINT(irInstruction.op1.intValue)))
				END;
			END
		END EmitExit;

		PROCEDURE EmitMov(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			destinationRegister, sourceOperand: Operand;
		BEGIN
			IF irInstruction.op1.mode # IntermediateCode.ModeRegister THEN
				(* optimization: mov [?], r? it is more optimal to determine the source operand first *)
				sourceOperand := RegisterOrImmediateFromIrOperand(irInstruction.op2, part, emptyOperand);

				destinationRegister := GetFreeRegisterOrHint(PartType(irInstruction.op2.type, part), sourceOperand) (* note that the source operand (possibly a register) is used as hint *)
			ELSE
				PrepareSingleSourceOpWithImmediate(irInstruction, part, destinationRegister, sourceOperand);
			END;

			MovIfDifferent(destinationRegister, sourceOperand);
			WriteBack(irInstruction.op1, part, destinationRegister)
		END EmitMov;

		(* BITWISE LOGICAL OPERATIONS *)

		PROCEDURE EmitNot(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			destination, source: Operand;
		BEGIN
			PrepareSingleSourceOpWithImmediate(irInstruction, part, destination, source);
			Emit2(opMVN, destination, source); (* invert bits *)
			WriteBack(irInstruction.op1, part, destination)
		END EmitNot;

		PROCEDURE EmitAnd(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			dummy: BOOLEAN;
			destination, left, right: Operand;
		BEGIN
			PrepareDoubleSourceOpWithImmediate(irInstruction, part, destination, left, right, dummy);
			Emit3(opAND, destination, left, right);
			WriteBack(irInstruction.op1, part, destination)
		END EmitAnd;

		PROCEDURE EmitOr(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			dummy: BOOLEAN;
			destination, left, right: Operand;
		BEGIN
			PrepareDoubleSourceOpWithImmediate(irInstruction, part, destination, left, right, dummy);
			Emit3(opORR, destination, left, right);
			WriteBack(irInstruction.op1, part, destination)
		END EmitOr;

		PROCEDURE EmitXor(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			dummy: BOOLEAN;
			destination, left, right: Operand;
		BEGIN
			PrepareDoubleSourceOpWithImmediate(irInstruction, part, destination, left, right, dummy);
			Emit3(opEOR, destination, left, right);
			WriteBack(irInstruction.op1, part, destination)
		END EmitXor;

		(* ARITHMETIC OPERATIONS *)

		(*
			- TODO: double precision floats
			- note that for operand sizes 8 and 16, the unused bits of the result might be in a unpredictable state (sign/zero-extension is not done on purpose)
		*)
		PROCEDURE EmitAddOrSub(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			destination, left, right: Operand;
			(* registerSR0, registerSR1, registerSR2: Operand; *)
		BEGIN
			IF IsSinglePrecisionFloat(irInstruction.op1) THEN
				ASSERT(backend.useFPU);
				PrepareDoubleSourceOp(irInstruction, Low, destination, left, right);
				IF irInstruction.opcode = IntermediateCode.add THEN
					Emit3(opFADDS, destination, left, right)
				ELSE
					Emit3(opFSUBS, destination, left, right)
				END;
				WriteBack(irInstruction.op1, Low, destination)

			ELSIF IsInteger(irInstruction.op1) THEN
				IF IsComplex(irInstruction.op1) THEN
					EmitPartialAddOrSub(irInstruction, Low, TRUE);
					EmitPartialAddOrSub(irInstruction, High, FALSE)
				ELSE
					EmitPartialAddOrSub(irInstruction, Low, FALSE)
				END

			ELSE
				HALT(200)
			END
		END EmitAddOrSub;

		PROCEDURE EmitPartialAddOrSub(CONST irInstruction: IntermediateCode.Instruction; part: LONGINT; doUpdateFlags: BOOLEAN);
		VAR
			destination, left, right, hint: Operand;
			irDestination, irLeft, irRight: IntermediateCode.Operand;
			operation: LONGINT;
			doSwap, doNegateRight: BOOLEAN;
		BEGIN
			irDestination := irInstruction.op1; irLeft := irInstruction.op2; irRight := irInstruction.op3;

			doSwap := FALSE; doNegateRight := FALSE; (* defaults *)

			IF irInstruction.opcode = IntermediateCode.add THEN
				IF IrOperandIsDirectlyEncodable(irRight, part) THEN
					(* add r0, r1, 16 ~> ADD R0, R1, #16 *)
					operation := opADD
				ELSIF IrOperandIsDirectlyEncodable(irLeft, part) THEN
					(* add r0, 16, r1 ~> ADD R0, R1, #16 *)
					operation := opADD; doSwap := TRUE
				ELSIF NegatedIrOperandIsDirectlyEncodable(irRight, part) THEN
					(* add r0, r1, -16 ~> SUB R0, R1, #16 *)
					operation := opSUB; doNegateRight := TRUE
				ELSIF NegatedIrOperandIsDirectlyEncodable(irLeft, part) THEN
					(* add r0, -16, r1 ~> SUB R0, R1, #16 *)
					operation := opSUB; doSwap := TRUE; doNegateRight := TRUE
				ELSE
					operation := opADD
				END

			ELSIF irInstruction.opcode = IntermediateCode.sub THEN
				IF IrOperandIsDirectlyEncodable(irRight, part) THEN
					(* sub r0, r1, 16 ~> SUB R0, R1, #16 *)
					operation := opSUB
				ELSIF IrOperandIsDirectlyEncodable(irLeft, part) THEN
					(* sub r0, 16, r1 ~> RSB R0, R1, #16 *)
					operation := opRSB; doSwap := TRUE
				ELSIF NegatedIrOperandIsDirectlyEncodable(irRight, part) THEN
					(* sub r0, r1, -16 ~> ADD R0, R1, #16 *)
					operation := opADD; doNegateRight := TRUE
				ELSE
					operation := opSUB
				END

			ELSE
				HALT(100)
			END;

			(* get destination operand *)
			destination := AcquireDestinationRegister(irDestination, part, emptyOperand);

			(* get source operands *)
			IF doSwap THEN SwapIrOperands(irLeft, irRight) END; (* if needed, swap operands *)

			(* TODO: revise this! *)
			IF IsSameRegister(right, destination) THEN hint := destination ELSE hint := emptyOperand END;
			left := RegisterFromIrOperand(irLeft, part, hint);

			IF doNegateRight THEN
				ASSERT(NegatedIrOperandIsDirectlyEncodable(irRight, part));
				right := InstructionSet.NewImmediate(-ValueOfPart(irRight.intValue, part))
			ELSE
				right := RegisterOrImmediateFromIrOperand(irRight, part, emptyOperand)
			END;

			(* if needed, use operation that incorporates carry *)
			IF part # Low THEN
				CASE operation OF
				| opADD: operation := opADC
				| opSUB: operation := opSBC
				| opRSB: operation := opRSC
				ELSE HALT(100)
				END
			END;

			IF doUpdateFlags THEN
				Emit3WithFlags(operation, destination, left, right, {InstructionSet.flagS})
			ELSE
				Emit3(operation, destination, left, right)
			END;

			WriteBack(irDestination, part, destination)
		END EmitPartialAddOrSub;

		PROCEDURE EmitMul(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			destination, left, right: ARRAY 2 OF Operand;
		BEGIN
			IF IsSinglePrecisionFloat(irInstruction.op1) THEN
				ASSERT(backend.useFPU);
				PrepareDoubleSourceOp(irInstruction, Low, destination[Low], left[Low], right[Low]);
				Emit3(opFMULS, destination[Low], left[Low], right[Low]);
				WriteBack(irInstruction.op1, Low, destination[Low])

			ELSIF IsInteger(irInstruction.op1) THEN
				IF IsComplex(irInstruction.op1) THEN
					ASSERT(irInstruction.op1.type.form = IntermediateCode.SignedInteger);
					HALT(200);
					(* TODO: fix signed 64 bit integer multiplication:
					PrepareDoubleSourceOp(irInstruction, Low, destination[Low], left[Low], right[Low]);
					PrepareDoubleSourceOp(irInstruction, High, destination[High], left[High], right[High]);

					Emit4(opSMULL, destination[Low], destination[High], left[Low], right[Low]); (* signed long multiplication *)
					Emit3(opMLA, destination[High], left[Low], right[High]); (* multiply and accumulate *)
					Emit3(opMLA, destination[High], left[High], right[Low]);

					WriteBack(irInstruction.op1, Low, destination[Low]);
					WriteBack(irInstruction.op1, High, destination[High]);
					*)
				ELSE
					(* signed or unsigned integer multiplication: *)
					PrepareDoubleSourceOp(irInstruction, Low, destination[Low], left[Low], right[Low]);
					SignOrZeroExtendOperand(left[Low], irInstruction.op2.type);
					SignOrZeroExtendOperand(right[Low], irInstruction.op3.type);
					Emit3(opMUL, destination[Low], left[Low], right[Low]); (* note that the sign does not matter for the least 32 significant bits *)
					WriteBack(irInstruction.op1, Low, destination[Low])
				END
			ELSE
				HALT(200)
			END
		END EmitMul;

		PROCEDURE EmitDiv(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			destination, left, right: Operand;
		BEGIN
			IF IsSinglePrecisionFloat(irInstruction.op1) THEN
				ASSERT(backend.useFPU);
				PrepareDoubleSourceOp(irInstruction, Low, destination, left, right);
				Emit3(opFDIVS, destination, left, right);
				WriteBack(irInstruction.op1, Low, destination)
			ELSE
				HALT(200)
			END
		END EmitDiv;

		PROCEDURE EmitMod(CONST irInstruction: IntermediateCode.Instruction);
		BEGIN HALT(100) (* handled by a runtime call *)
		END EmitMod;

		PROCEDURE EmitAbs(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			destination, source: ARRAY 2 OF Operand;
			zero: Operand;
		BEGIN
			IF IsInteger(irInstruction.op1) THEN
				zero := InstructionSet.NewImmediate(0);
				IF IsComplex(irInstruction.op1) THEN
					PrepareSingleSourceOpWithImmediate(irInstruction, Low, destination[Low], source[Low]);
					PrepareSingleSourceOpWithImmediate(irInstruction, High, destination[High], source[High]);
					MovIfDifferent(destination[Low], source[Low]);
					MovIfDifferent(destination[High], source[High]);
					(* negate the value if it is negative *)
					IF irInstruction.op2.type.form = IntermediateCode.SignedInteger THEN
						Emit2(opCMP, destination[High], zero); (* note that only the high part has to be looked at to determine the sign *)
						Emit1WithCondition(opB, InstructionSet.NewImmediate(4), InstructionSet.conditionGE); (* BGE #4 = skip the following two instructions if greater or equal *)
						Emit3WithFlags(opRSB, destination[Low], destination[Low], zero, {InstructionSet.flagS}); (* RSBS *)
						Emit3(opRSC, destination[High], destination[High], zero); (* RSC - reverse subtraction with carry *)
					END;
					WriteBack(irInstruction.op1, Low, destination[Low]);
					WriteBack(irInstruction.op1, High, destination[High])
				ELSE
					PrepareSingleSourceOpWithImmediate(irInstruction, Low, destination[Low], source[Low]);
					SignOrZeroExtendOperand(source[Low], irInstruction.op2.type);
					MovIfDifferent(destination[Low], source[Low]);
					(* negate the value if it is negative *)
					IF irInstruction.op2.type.form = IntermediateCode.SignedInteger THEN
						SignExtendOperand(destination[Low], irInstruction.op2.type.sizeInBits);
						Emit2(opCMP, destination[Low], zero);
						Emit3WithCondition(opRSB, destination[Low], destination[Low], zero, InstructionSet.conditionLT)
					END;
					WriteBack(irInstruction.op1, Low, destination[Low])
				END
			ELSIF IsSinglePrecisionFloat(irInstruction.op1) THEN
				ASSERT(backend.useFPU);
				PrepareSingleSourceOp(irInstruction, Low, destination[Low], source[Low]);
				Emit2(opFABSS, destination[Low], source[Low]);
				WriteBack(irInstruction.op1, Low, destination[Low])
			ELSE
				HALT(200)
			END
		END EmitAbs;

		(* TODO: floats *)
		PROCEDURE EmitNeg(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			destination, source: ARRAY 2 OF Operand;
			zero: Operand;
		BEGIN
			IF IsInteger(irInstruction.op1) THEN
				zero := InstructionSet.NewImmediate(0);
				IF IsComplex(irInstruction.op1) THEN
					PrepareSingleSourceOpWithImmediate(irInstruction, Low, destination[Low], source[Low]);
					PrepareSingleSourceOpWithImmediate(irInstruction, High, destination[High], source[High]);
					Emit3WithFlags(opRSB, destination[Low], source[Low], zero, {InstructionSet.flagS}); (* RSBS *)
					Emit3(opRSC, destination[High], source[High], zero); (* RSC - reverse subtraction with carry *)
					WriteBack(irInstruction.op1, Low, destination[Low]);
					WriteBack(irInstruction.op1, High, destination[High])
				ELSE
					PrepareSingleSourceOpWithImmediate(irInstruction, Low, destination[Low], source[Low]);
					SignOrZeroExtendOperand(source[Low], irInstruction.op2.type);
					Emit3(opRSB, destination[Low], source[Low], zero); (* reverse subtraction with zero *)
					WriteBack(irInstruction.op1, Low, destination[Low])
				END
			ELSIF IsSinglePrecisionFloat(irInstruction.op1) THEN
				ASSERT(backend.useFPU);
				PrepareSingleSourceOp(irInstruction, Low, destination[Low], source[Low]);
				Emit2(opFNEGS, destination[Low], source[Low]);
				WriteBack(irInstruction.op1, Low, destination[Low])
			ELSE
				HALT(200)
			END
		END EmitNeg;

		(*
		- note that the ARM instructions ASR, LSL, LSR, ROR, etc. are actually aliases for a MOV with a shifted register operand
		- note that ARM does not support LSL by 32 bits
		- note that for operand sizes 8 and 16, the unused bits of the result might be in a unpredictable state (sign/zero-extension is not done on purpose)
		*)
		PROCEDURE EmitShiftOrRotation(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			shiftAmountImmediate, shiftMode: LONGINT;
			destination, source: ARRAY 2 OF Operand;
			irShiftOperand: IntermediateCode.Operand;
			temp, shiftAmountRegister: Operand;
		BEGIN
			ASSERT(IsInteger(irInstruction.op1), 100); (* shifts are only allowed on integers *)

			destination[Low] := AcquireDestinationRegister(irInstruction.op1, Low, emptyOperand);
			source[Low] := RegisterFromIrOperand(irInstruction.op2, Low, emptyOperand); (* note that the destination register cannot be used as hint for the source *)
			IF IsComplex(irInstruction.op1) THEN
				destination[High] := AcquireDestinationRegister(irInstruction.op1, High, emptyOperand);
				source[High] := RegisterFromIrOperand(irInstruction.op2, High, emptyOperand); (* note that the destination register cannot be used as hint for the source *)
			END;

			irShiftOperand := irInstruction.op3;

			ASSERT((irShiftOperand.type.form = IntermediateCode.UnsignedInteger) & ~IsComplex(irShiftOperand)); (* the shift operand is assumed to be a single part unsigned integer *)

			(* use ARM register or shift immediate to represent IR shift operand *)
			IF (irShiftOperand.mode = IntermediateCode.ModeImmediate) & (irShiftOperand.symbol.name = "") THEN
				shiftAmountImmediate := LONGINT(irShiftOperand.intValue); (* note that at this point the shift amount could also be >= 32 *)
				shiftAmountRegister := emptyOperand;
				ASSERT(shiftAmountImmediate >= 0);
			ELSE
				shiftAmountImmediate := 0;
				shiftAmountRegister := RegisterFromIrOperand(irShiftOperand, Low, emptyOperand);
				ZeroExtendOperand(shiftAmountRegister, irShiftOperand.type.sizeInBits)
			END;

			CASE irInstruction.opcode OF
			| IntermediateCode.ror, IntermediateCode.rol:
				(* rotation: *)
				IF IsComplex(irInstruction.op1) THEN HALT(100) END; (* complex rotations are handled as runtime calls *)

				IF irInstruction.opcode = IntermediateCode.rol THEN
					(* simple left rotation: rotate right with complementary rotation amount, since ARM does not support left rotations *)
					IF shiftAmountRegister.register = None THEN
						shiftAmountImmediate := 32 - shiftAmountImmediate
					ELSE
						IF IsSameRegister(destination[Low], source[Low]) THEN temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) ELSE temp := destination[Low] END;
						Emit3(opRSB, temp, shiftAmountRegister, InstructionSet.NewImmediate(32));
						shiftAmountRegister := temp
					END
				END;

				shiftAmountImmediate := shiftAmountImmediate MOD 32; (* make sure rotation amount is in range 0..31 *)

				IF (shiftAmountRegister.register = None) & (shiftAmountImmediate = 0) THEN
					(* simple rotation by 0: *)
					Emit2(opMOV, destination[Low], source[Low])
				ELSE
					IF irInstruction.op1.type.sizeInBits = 8 THEN
						(* simple 8 bit rotation: *)
						ZeroExtendOperand(source[Low], 8);
						IF IsSameRegister(destination[Low], source[Low]) THEN temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) ELSE temp := destination[Low] END;
						Emit2(opMOV, temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftROR, shiftAmountRegister.register, shiftAmountImmediate));
						Emit3(opORR, temp, temp, InstructionSet.NewRegister(temp.register, InstructionSet.shiftLSR, None, 8));
						Emit3(opORR, temp, temp, InstructionSet.NewRegister(temp.register, InstructionSet.shiftLSR, None, 16));
						Emit3(opORR, destination[Low], temp, InstructionSet.NewRegister(temp.register, InstructionSet.shiftLSR, None, 24))
					ELSIF irInstruction.op1.type.sizeInBits = 16 THEN
						(* simple 16 bit rotation: *)
						ZeroExtendOperand(source[Low], 16);
						IF IsSameRegister(destination[Low], source[Low]) THEN temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) ELSE temp := destination[Low] END;
						Emit2(opMOV, temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftROR, shiftAmountRegister.register, shiftAmountImmediate));
						Emit3(opORR, destination[Low], temp, InstructionSet.NewRegister(temp.register, InstructionSet.shiftLSR, None, 16))
					ELSIF irInstruction.op1.type.sizeInBits = 32 THEN
						(* simple 32 bit rotation: *)
						Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftROR, shiftAmountRegister.register, shiftAmountImmediate))
					ELSE
						HALT(100)
					END
				END

			| IntermediateCode.shl:
				(* left shift: *)
				IF IsComplex(irInstruction.op1) THEN
					(* complex left shift: *)
					IF shiftAmountRegister.register = None THEN
						(* complex left immediate shift: *)
						IF shiftAmountImmediate = 0 THEN
							Emit2(opMOV, destination[High], source[High]);
							Emit2(opMOV, destination[Low], source[Low])
						ELSIF (shiftAmountImmediate > 0) & (shiftAmountImmediate < 32) THEN
							IF ~IsSameRegister(destination[High], source[High]) THEN temp := destination[High] ELSE temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) END;
							Emit2(opMOV, temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSR, None, 32 - shiftAmountImmediate));
							Emit3(opORR, destination[High], temp, InstructionSet.NewRegister(source[High].register, InstructionSet.shiftLSL, None, shiftAmountImmediate));
							Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, None, shiftAmountImmediate))
						ELSIF (shiftAmountImmediate >= 32) & (shiftAmountImmediate < 64) THEN
							Emit2(opMOV, destination[High], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, None, shiftAmountImmediate - 32));
							Emit2(opMOV, destination[Low], InstructionSet.NewImmediate(0))
						ELSIF shiftAmountImmediate >= 64 THEN
							Emit2(opMOV, destination[High], InstructionSet.NewImmediate(0));
							Emit2(opMOV, destination[Low], InstructionSet.NewImmediate(0))
						ELSE
							HALT(100)
						END
					ELSE
						(* complex left register shift: *)
						IF ~IsSameRegister(destination[Low], source[Low]) THEN temp := destination[Low] ELSE temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) END;
						Emit2(opCMP, shiftAmountRegister, InstructionSet.NewImmediate(32));
						(* shiftAmount < 32: *)
						Emit3WithCondition(opRSB, temp, shiftAmountRegister, InstructionSet.NewImmediate(32), InstructionSet.conditionLT);
						Emit2WithCondition(opMOV, temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSR, temp.register, 0), InstructionSet.conditionLT);
						Emit3WithCondition(opORR, destination[High], temp, InstructionSet.NewRegister(source[High].register, InstructionSet.shiftLSL, shiftAmountRegister.register, 0), InstructionSet.conditionLT);
						Emit2WithCondition(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, shiftAmountRegister.register, 0), InstructionSet.conditionLT);
						(* shift amount >= 32: *)
						Emit3WithCondition(opSUB, temp, shiftAmountRegister, InstructionSet.NewImmediate(32), InstructionSet.conditionGE);
						Emit2WithCondition(opMOV, destination[High], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, temp.register, 0), InstructionSet.conditionGE);
						Emit2WithCondition(opMOV, destination[Low], InstructionSet.NewImmediate(0), InstructionSet.conditionGE)
					END
				ELSE
					(* simple left shift: *)
					IF shiftAmountRegister.register = None THEN
						(* simple left immediate shift *)
						IF (shiftAmountImmediate >= 0) & (shiftAmountImmediate < 32) THEN
							Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, None, shiftAmountImmediate)) (* note: LSL has to be in the range 0..31 *)
						ELSIF shiftAmountImmediate >= 32 THEN
							Emit2(opMOV, destination[Low], InstructionSet.NewImmediate(0))
						ELSE
							HALT(100)
						END
					ELSE
						(* simple left register shift: *)
						Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSL, shiftAmountRegister.register, 0))
					END
				END

			| IntermediateCode.shr:
				(* right shift: *)

				(* determine shift mode (depends on if source operand is signed) *)
				IF irInstruction.op1.type.form = IntermediateCode.UnsignedInteger THEN
					(* logical right shift: *)
					shiftMode := InstructionSet.shiftLSR
				ELSE
					(* arithmetic right shift: *)
					shiftMode := InstructionSet.shiftASR
				END;

				IF IsComplex(irInstruction.op1) THEN
					(* complex right shift: *)

					IF shiftAmountRegister.register = None THEN
						(* complex right immediate shift: *)
						IF shiftAmountImmediate = 0 THEN
							Emit2(opMOV, destination[High], source[High]);
							Emit2(opMOV, destination[Low], source[Low])
						ELSIF (shiftAmountImmediate > 0) & (shiftAmountImmediate < 32) THEN
							IF ~IsSameRegister(destination[High], source[High]) THEN temp := destination[High] ELSE temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) END;
							Emit2(opMOV, temp, InstructionSet.NewRegister(source[High].register, InstructionSet.shiftLSL, None, 32 - shiftAmountImmediate));
							Emit3(opORR, destination[Low], temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSR, None, shiftAmountImmediate));
							Emit2(opMOV, destination[High], InstructionSet.NewRegister(source[High].register, shiftMode, None, shiftAmountImmediate))
						ELSIF shiftAmountImmediate >= 32 THEN
							IF shiftAmountImmediate > 64 THEN shiftAmountImmediate := 64 END;
							Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[High].register, shiftMode, None, shiftAmountImmediate - 32));
							Emit2(opMOV, destination[High], InstructionSet.NewRegister(source[High].register, shiftMode, None, 32))
						ELSE
							HALT(100)
						END
					ELSE
						(* complex right register shift: *)
						IF ~IsSameRegister(destination[High], source[High]) THEN temp := destination[High] ELSE temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)) END;
						Emit2(opCMP, shiftAmountRegister, InstructionSet.NewImmediate(32));
						(* shiftAmount < 32: *)
						Emit3WithCondition(opRSB, temp, shiftAmountRegister, InstructionSet.NewImmediate(32), InstructionSet.conditionLT);
						Emit2WithCondition(opMOV, temp, InstructionSet.NewRegister(source[High].register, InstructionSet.shiftLSL, temp.register, 0), InstructionSet.conditionLT);
						Emit3WithCondition(opORR, destination[Low], temp, InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftLSR, shiftAmountRegister.register, 0), InstructionSet.conditionLT);
						Emit2WithCondition(opMOV, destination[High], InstructionSet.NewRegister(source[High].register, shiftMode, shiftAmountRegister.register, 0), InstructionSet.conditionLT);
						(* shift amount >= 32: *)
						Emit3WithCondition(opSUB, temp, shiftAmountRegister, InstructionSet.NewImmediate(32), InstructionSet.conditionGE);
						Emit2WithCondition(opMOV, destination[Low], InstructionSet.NewRegister(source[High].register, shiftMode, temp.register, 0), InstructionSet.conditionGE);
						Emit2WithCondition(opMOV, destination[High], InstructionSet.NewRegister(source[High].register, shiftMode, shiftAmountRegister.register, 0), InstructionSet.conditionGE)
					END
				ELSE
					(* simple right shift: *)
					SignOrZeroExtendOperand(source[Low], irInstruction.op1.type);

					IF shiftAmountRegister.register = None THEN
						(* simple right immediate shift: *)
						IF shiftAmountImmediate > 32 THEN shiftAmountImmediate := 32 END;
						Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, shiftMode, None, shiftAmountImmediate))
					ELSE
						(* simple right register shift: *)
						Emit2(opMOV, destination[Low], InstructionSet.NewRegister(source[Low].register, shiftMode, shiftAmountRegister.register, 0))
					END
				END

			ELSE
				HALT(100)
			END;

			WriteBack(irInstruction.op1, Low, destination[Low]);
			IF IsComplex(irInstruction.op1) THEN WriteBack(irInstruction.op1, High, destination[High]) END
		END EmitShiftOrRotation;

		PROCEDURE EmitAsm(CONST irInstruction: IntermediateCode.Instruction);
		VAR
			reader: Streams.StringReader;
			procedure: SyntaxTree.Procedure;
			scope: SyntaxTree.Scope;
			symbol: SyntaxTree.Symbol;
			assembler: Assembler.Assembler;
			scanner: Scanner.AssemblerScanner;
			len: LONGINT;
		BEGIN
			len := Strings.Length(irInstruction.op1.string^);
			NEW(reader, len);
			reader.Set(irInstruction.op1.string^);

			(* determine scope of the section *)
			symbol := in.symbol;
			IF symbol = NIL THEN
				scope := NIL
			ELSE
				procedure := symbol(SyntaxTree.Procedure);
				scope := procedure.procedureScope
			END;

			NEW(assembler, diagnostics);
			scanner := Scanner.NewAssemblerScanner(module.moduleName(*module.module.sourceName*), reader, LONGINT(irInstruction.op1.intValue) (* ? *), diagnostics);
			assembler.InlineAssemble(scanner, in, scope, module);
			error := error OR assembler.error
		END EmitAsm;

		PROCEDURE EmitSpecial(VAR instruction: IntermediateCode.Instruction);
		VAR
			psrNumber, code, a, b, c, d: LONGINT;
			register, register2, register3, register4, temp, cpOperand, cpRegister1, cpRegister2, opCode1Operand, opCode2Operand: Operand;
		BEGIN
			CASE instruction.subtype OF
			| GetSP: Emit2(opMOV, opRES, opSP)
			| SetSP: Emit2(opMOV, opSP, RegisterOrImmediateFromIrOperand(instruction.op1, Low, emptyOperand))
			| GetFP: Emit2(opMOV, opRES, opFP)
			| SetFP: Emit2(opMOV, opFP, RegisterOrImmediateFromIrOperand(instruction.op1, Low, emptyOperand))
			| GetLNK: Emit2(opMOV, opRES, opLR)
			| SetLNK: Emit2(opMOV, opLR, RegisterOrImmediateFromIrOperand(instruction.op1, Low, emptyOperand))
			| GetPC: Emit2(opMOV, opRES, opPC)
			| SetPC: Emit2(opMOV, opPC, RegisterOrImmediateFromIrOperand(instruction.op1, Low, emptyOperand))
			| LDPSR, STPSR:
				ASSERT(instruction.op1.type.form IN IntermediateCode.Integer);
				IF instruction.op1.mode # IntermediateCode.ModeImmediate THEN
					Error(instruction.textPosition,"first operand must be immediate")
				ELSIF (instruction.op1.intValue < 0) OR (instruction.op1.intValue > 1) THEN
					Error(instruction.textPosition,"first operand must be 0 or 1")
				ELSE
					IF instruction.op1.intValue = 0 THEN
						psrNumber := InstructionSet.CPSR
					ELSE
						psrNumber := InstructionSet.SPSR
					END;
					register := RegisterFromIrOperand(instruction.op2, Low, emptyOperand);
					IF instruction.subtype = LDPSR THEN
						Emit2(opMSR, InstructionSet.NewRegisterWithFields(psrNumber, {InstructionSet.fieldF, InstructionSet.fieldC}), register)
					ELSE
						temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
						Emit2(opMRS, temp, InstructionSet.NewRegister(psrNumber, None, None, 0));
						Emit2(opSTR, temp, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment}))
					END
				END

			| LDCPR, STCPR:
				IF instruction.op1.mode # IntermediateCode.ModeImmediate THEN
					Error(instruction.textPosition,"first operand must be immediate")
				ELSIF (instruction.op2.mode # IntermediateCode.ModeImmediate) THEN
					Error(instruction.textPosition,"second operand must be immediate")
				ELSIF (instruction.op2.intValue < 0) OR (instruction.op2.intValue > 15) THEN
					Error(instruction.textPosition,"second operand must be between 0 or 15")
				ELSE
					code := LONGINT(instruction.op1.intValue); (* code = a00bcdH *)
					a := (code DIV 100000H) MOD 10H; (* opcode1 * 2 *)
					b := (code DIV 100H) MOD 10H; (* coprocessor number *)
					c := (code DIV 10H) MOD 10H; (* opcode2 * 2 *)
					d := code MOD 10H; (* coprocessor register2 number *)

					InstructionSet.InitCoprocessor(cpOperand, InstructionSet.CP0 + b);
					InstructionSet.InitOpcode(opCode1Operand, a DIV 2);
					register := RegisterFromIrOperand(instruction.op3, Low, emptyOperand);
					InstructionSet.InitRegister(cpRegister1, InstructionSet.CR0 + LONGINT(instruction.op2.intValue), None, None, 0);
					InstructionSet.InitRegister(cpRegister2, InstructionSet.CR0 + d, None, None, 0);
					InstructionSet.InitOpcode(opCode2Operand, c DIV 2);

					IF instruction.subtype = LDCPR THEN
						Emit6(opMCR, cpOperand, opCode1Operand, register, cpRegister1, cpRegister2, opCode2Operand)
					ELSE
						temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
						Emit6(opMRC, cpOperand, opCode1Operand, temp, cpRegister1, cpRegister2, opCode2Operand);
						Emit2(opSTR, temp, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment}))
					END
				END

			| FLUSH:
				IF instruction.op1.mode # IntermediateCode.ModeImmediate THEN
					Error(instruction.textPosition,"first operand must be immediate")
				ELSIF (instruction.op1.intValue < 0) OR (instruction.op2.intValue > 0FFH) THEN
					Error(instruction.textPosition,"first operand must be between 0 and 255")
				ELSE
					code := LONGINT(instruction.op1.intValue); (* code = aaa1bbbbB *)
					a := (code DIV 20H) MOD 8; (* coprocessor opcode 2 *)
					b := (code MOD 10H); (* coprocessor register2 number  *)

					(* examples:
					9AH = 10011000B -> MCR p15, 0, R0, c7, c10, 4
					17H = 00010111B -> MCR p15, 0, R0, c7, c7, 0
					*)

					InstructionSet.InitCoprocessor(cpOperand, InstructionSet.CP15);
					InstructionSet.InitOpcode(opCode1Operand, 0);
					InstructionSet.InitRegister(register, InstructionSet.R0, None, None, 0);
					InstructionSet.InitRegister(cpRegister1, InstructionSet.CR7, None, None, 0);
					InstructionSet.InitRegister(cpRegister2, InstructionSet.CR0 + b, None, None, 0);
					InstructionSet.InitOpcode(opCode2Operand, a);

					Emit6(opMCR, cpOperand, opCode1Operand, register, cpRegister1, cpRegister2, opCode2Operand);
					Emit2(opMOV, register, register); (* NOP (register = R0) *)
					Emit2(opMOV, register, register); (* NOP *)
					Emit2(opMOV, register, register); (* NOP *)
					Emit2(opMOV, register, register) (* NOP *)
				END

			| NULL:
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand);
				Emit3(opBIC, register, register, InstructionSet.NewImmediate(LONGINT(80000000H)));
				Emit2(opCMP, register, InstructionSet.NewImmediate(0));
				Emit2WithCondition(opMOV, opRES, InstructionSet.NewImmediate(1), InstructionSet.conditionEQ);
				Emit2WithCondition(opMOV, opRES, InstructionSet.NewImmediate(0), InstructionSet.conditionNE);

			| XOR:
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand);
				register2 := RegisterFromIrOperand(instruction.op2, Low, emptyOperand);
				(*
				register3 := RegisterFromIrOperand(instruction.op3, Low, emptyOperand);
				*)
				Emit3(opEOR, opRES, register, register2);

			| MULD:
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand); (* note that 'register' contains an address *)
				register2 := RegisterFromIrOperand(instruction.op2, Low, emptyOperand);
				register3 := RegisterFromIrOperand(instruction.op3, Low, emptyOperand);
				Emit4(opUMULL, opRES, opRESHI, register2, register3);
				Emit2(opSTR, opRES, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment})); (* JCH: 15.05.2012 *)
				Emit2(opSTR, opRESHI, InstructionSet.NewImmediateOffsetMemory(register.register, 4, {InstructionSet.Increment}))

			| ADDC:
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand);
				register2 := RegisterFromIrOperand(instruction.op2, Low, emptyOperand);
				Emit3(opADC, opRES, register, register2)

			| PACK:
				(* PACK(x, y):
				add y to the binary exponent of y. PACK(x, y) is equivalent to  x := x * 2^y. *)
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand); (*  register = address of x *)
				register2 := RegisterFromIrOperand(instruction.op2, Low, emptyOperand); (*  register2 = value of y *)

				register3 := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)); (* a temporary INTEGER (!) register that is used to store a float *)
				Emit2(opLDR, register3, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment})); (* register3 = value of x *)
				Emit3(opADD, register3, register3, InstructionSet.NewRegister(register2.register, InstructionSet.shiftLSL, None, 23)); (* increase the (biased) exponent of x by y*)
				Emit2(opSTR, register3, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment})) (* store new value of x *)

			| UNPK:
				(* UNPK(x, y):
				remove the binary exponent on x and put it into y. UNPK is the reverse operation of PACK. The resulting x is normalized, i.e. 1.0 <= x < 2.0.
				*)
				register := RegisterFromIrOperand(instruction.op1, Low, emptyOperand); (*  register = address of x *)
				register2 := RegisterFromIrOperand(instruction.op2, Low, emptyOperand); (*  register2 = address of y *)
				register3 := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32)); (* a temporary INTEGER (!) register that is used to store a float *)
				Emit2(opLDR, register3, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment})); (* register3 = value of x *)
				register4 := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
				Emit2(opMOV, register4, InstructionSet.NewRegister(register3.register, InstructionSet.shiftLSR, None, 23)); (* register4 = biased exponent (and sign) of x *)
				Emit3(opSUB, register4, register4, InstructionSet.NewImmediate(127)); (* register4 = exponent of x (biased exponent - 127) *)
				Emit2(opSTR, register4, InstructionSet.NewImmediateOffsetMemory(register2.register, 0, {InstructionSet.Increment})); (* store exponent of x as value for y *)
				Emit3(opSUB, register3, register3, InstructionSet.NewRegister(register4.register, InstructionSet.shiftLSL, None, 23)); (* reduce the biased exponent of x by the value of y *)
				Emit2(opSTR, register3, InstructionSet.NewImmediateOffsetMemory(register.register, 0, {InstructionSet.Increment})) (*  store new value of x *)

			ELSE
				HALT(100)
			END
		END EmitSpecial;

		PROCEDURE EmitBr(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			branchDistance: LONGINT;
			isSwapped: BOOLEAN;
			left, right: ARRAY 2 OF Operand;
			temp: Operand;
			irLeft, irRight: IntermediateCode.Operand;
			fixup,failFixup: BinaryCode.Fixup;
			fixupPatternList: ObjectFile.FixupPatterns;
			identifier: ObjectFile.Identifier;
			hiHit, hiFail, lowHit: LONGINT;

			PROCEDURE JmpDest(branchConditionCode: LONGINT);
			BEGIN
				IF (irInstruction.op1.mode = IntermediateCode.ModeImmediate) & (irInstruction.op1.symbol.name = in.name) & (irInstruction.op1.offset = 0) THEN
				(* branch within same section at a certain IR offset *)

				(* optimization: abort if branch is to the next instruction *)
				IF irInstruction.op1.symbolOffset = inPC + 1 THEN
					IF dump # NIL THEN dump.String("branch to next instruction ignored"); dump.Ln END;
					RETURN
				END;

				IF irInstruction.op1.symbolOffset <= inPC THEN
					(* backward branch: calculate the branch distance *)
					branchDistance := in.instructions[irInstruction.op1.symbolOffset].pc - out.pc - 8;
					ASSERT((-33554432 <= branchDistance) & (branchDistance <= 0) & ((ABS(branchDistance) MOD 4) = 0), 200);
				ELSE
					(* forward branch: the distance is not yet known, use some placeholder and add a relative fixup *)
					branchDistance := -4;

					(* TODO: what about a branch to the next instruction? this would require the fixup meachnism to patch a negative value! (-> -4) *)
					NEW(fixupPatternList, 1);
					fixupPatternList[0].offset := 0;
					fixupPatternList[0].bits := 24;
					identifier.name := in.name;
					identifier.fingerprint := in.fingerprint;
					fixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, identifier, irInstruction.op1.symbolOffset, -8, -2, fixupPatternList);
					out.fixupList.AddFixup(fixup)
				END;
				Emit1WithCondition(opB, InstructionSet.NewImmediate(branchDistance), branchConditionCode)

			ELSE
				(* any other type of branch -> do register branch *)
				Emit1WithCondition(opBX, RegisterFromIrOperand(irInstruction.op1, Low, emptyOperand), branchConditionCode)

			END;

			END JmpDest;

			PROCEDURE Cmp(CONST left, right: InstructionSet.Operand; float: BOOLEAN);
			BEGIN
				IF float THEN
					IF ~backend.useFPU OR IsComplex(irLeft) (* 64 bit *) THEN
						(* floating point comparisons without VFP unit *)
						temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
						Emit3WithFlags(opAND, temp, left, right, {InstructionSet.flagS});
						Emit2(opCMP, temp, InstructionSet.NewImmediate(0));
						Emit1WithCondition(opB, InstructionSet.NewImmediate(4), InstructionSet.conditionLT); (* skip two instructions *)
						Emit2(opCMP, left, right);
						Emit1(opB, InstructionSet.NewImmediate(0)); (* skip one instructions  *)
						Emit2(opCMP, right, left);
					ELSE
						Emit2(opFCMPS, left, right);
						Emit0(opFMSTAT); (* transfer the VFP flags to the standard ARM flags *)
					END
				ELSE
					Emit2(opCMP, left, right);
				END;
			END Cmp;

		BEGIN
			hiFail := None;
			hiHit := None;
			IF irInstruction.opcode = IntermediateCode.br THEN
				(* unconditional branch: *)
				lowHit := InstructionSet.conditionAL

			ELSE
				(* conditional branch: *)
				irLeft := irInstruction.op2; irRight := irInstruction.op3;
				ASSERT((irLeft.type.form = irRight.type.form) & (irLeft.type.sizeInBits = irRight.type.sizeInBits));

				IF IsInteger(irLeft) THEN
					IF IsComplex(irLeft) THEN
						CASE irInstruction.opcode OF
						| IntermediateCode.breq, IntermediateCode.brne: (* left = right, left # right *)
							lowHit := InstructionSet.conditionEQ;

							left[High] := RegisterFromIrOperand(irLeft, High, emptyOperand);
							right[High] := RegisterOrImmediateFromIrOperand(irRight, High, emptyOperand);
							Emit2(opCMP, left[High], right[High]);
							left[Low] := RegisterFromIrOperand(irLeft, Low, left[High]);
							right[Low] := RegisterOrImmediateFromIrOperand(irRight, Low, right[High]);
							Emit2WithCondition(opCMP, left[Low], right[Low], lowHit);
							
							IF irInstruction.opcode = IntermediateCode.brne THEN lowHit := InstructionSet.conditionNE END;

						| IntermediateCode.brlt, IntermediateCode.brge: (* left < right, left >= right *)
							IF irInstruction.opcode = IntermediateCode.brlt THEN lowHit := InstructionSet.conditionLT ELSE lowHit := InstructionSet.conditionGE END;

							ASSERT(irLeft.type.form = IntermediateCode.SignedInteger);
							left[Low] := RegisterFromIrOperand(irLeft, Low, emptyOperand);
							right[Low] := RegisterOrImmediateFromIrOperand(irRight, Low, emptyOperand);
							temp := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
							Emit3WithFlags(opSUB, temp, left[Low], right[Low], {InstructionSet.flagS});
							left[High] := RegisterFromIrOperand(irLeft, High, left[Low]);
							right[High] := RegisterOrImmediateFromIrOperand(irRight, High, right[Low]);
							Emit3WithFlags(opSBC, temp, left[High], right[High], {InstructionSet.flagS}) (* the high part of the subtraction determines the sign *)

						ELSE
							HALT(100)
						END

					ELSE
						ASSERT((irLeft.type.form IN IntermediateCode.Integer) & (irLeft.type.sizeInBits <= 32));

						(* swap operands if beneficial *)
						IF ~IrOperandIsDirectlyEncodable(irRight, Low) & IrOperandIsDirectlyEncodable(irLeft, Low) THEN
							isSwapped := TRUE;
							SwapIrOperands(irLeft, irRight)
						END;

						left[Low] := RegisterFromIrOperand(irLeft, Low, emptyOperand);
						right[Low] := RegisterOrImmediateFromIrOperand(irRight, Low, emptyOperand);

						SignOrZeroExtendOperand(left[Low], irLeft.type);
						SignOrZeroExtendOperand(right[Low], irRight.type);

						Cmp(left[Low], right[Low], FALSE);

						(* determine condition code for the branch (take into consideration that operands could have been swapped) *)
						CASE irInstruction.opcode OF
						| IntermediateCode.breq: (* left = right *) lowHit := InstructionSet.conditionEQ
						| IntermediateCode.brne: (* left # right *) lowHit := InstructionSet.conditionNE
						| IntermediateCode.brlt: (* left < right *)
							IF irInstruction.op2.type.form = IntermediateCode.UnsignedInteger THEN
								IF isSwapped THEN lowHit := InstructionSet.conditionHI ELSE lowHit := InstructionSet.conditionLO END
							ELSE
								IF isSwapped THEN lowHit := InstructionSet.conditionGT ELSE lowHit := InstructionSet.conditionLT END
							END
						| IntermediateCode.brge: (* left >= right *)
							IF irInstruction.op2.type.form = IntermediateCode.UnsignedInteger THEN
								IF isSwapped THEN lowHit := InstructionSet.conditionLS ELSE lowHit := InstructionSet.conditionHS END
							ELSE
								IF isSwapped THEN lowHit := InstructionSet.conditionLE ELSE lowHit := InstructionSet.conditionGE END
							END
						ELSE HALT(100)
						END
					END

				ELSIF IsSinglePrecisionFloat(irLeft) THEN
					left[Low] := RegisterFromIrOperand(irLeft, Low, emptyOperand);
					right[Low] := RegisterFromIrOperand(irRight, Low, emptyOperand);
					Cmp(left[Low], right[Low], TRUE);

					CASE irInstruction.opcode OF
					| IntermediateCode.breq: (* left = right *) lowHit := InstructionSet.conditionEQ
					| IntermediateCode.brne: (* left # right *) lowHit := InstructionSet.conditionNE
					| IntermediateCode.brlt: (* left < right *) lowHit := InstructionSet.conditionLT
					| IntermediateCode.brge: (* left >= right *) lowHit := InstructionSet.conditionGE
					ELSE HALT(100)
					END

				ELSIF IsDoublePrecisionFloat(irLeft) THEN
					CASE irInstruction.opcode OF
					IntermediateCode.breq:
						hiHit := None; hiFail := InstructionSet.conditionNE; lowHit := InstructionSet.conditionEQ
					|IntermediateCode.brne:
						hiHit := InstructionSet.conditionNE; hiFail := None; lowHit := InstructionSet.conditionNE
					|IntermediateCode.brge:
						IF isSwapped THEN
							hiHit := InstructionSet.conditionLT; hiFail := InstructionSet.conditionGT; lowHit := InstructionSet.conditionLS
						ELSE
							hiHit := InstructionSet.conditionGT; hiFail := InstructionSet.conditionLT; lowHit := InstructionSet.conditionHS
						END;
					|IntermediateCode.brlt:
						IF isSwapped THEN
							hiHit := InstructionSet.conditionGT; hiFail := InstructionSet.conditionLT; lowHit := InstructionSet.conditionHI
						ELSE
							hiHit := InstructionSet.conditionLT; hiFail := InstructionSet.conditionGT; lowHit := InstructionSet.conditionLO
						END;
					END;

					(*
						compare hi part (as float)
						if hiHit then br dest
						elsif hiFail then br fail
						else compare low part (as unsigned int)
							if lowHit then br dest
							end
						end,
						fail:
					*)

					(* hi part *)
					left[High] := RegisterFromIrOperand(irLeft, High, emptyOperand);
					right[High] := RegisterOrImmediateFromIrOperand(irRight, High, emptyOperand);
					Cmp(left[High], right[High], TRUE);
					IF hiHit # None THEN
						JmpDest(hiHit)
					END;
					IF hiFail # None THEN
						NEW(fixupPatternList, 1);
						fixupPatternList[0].offset := 0;
						fixupPatternList[0].bits := 24;
						identifier.name := in.name;
						identifier.fingerprint := in.fingerprint;
						failFixup := BinaryCode.NewFixup(BinaryCode.Relative, out.pc, identifier, irInstruction.op1.symbolOffset, -8, -2, fixupPatternList);
						out.fixupList.AddFixup(failFixup);
						Emit1WithCondition(opB, InstructionSet.NewImmediate(branchDistance), hiFail)
					END;

					(* low part *)
					left[Low] := RegisterFromIrOperand(irLeft, Low, emptyOperand);
					right[Low] := RegisterFromIrOperand(irRight, Low, emptyOperand);
					Cmp(left[Low], right[Low], FALSE);
				ELSE
					HALT(200)
				END
			END;

			JmpDest(lowHit);
			IF failFixup # NIL THEN
				failFixup.SetSymbol(in.name, in.fingerprint, 0, out.pc+failFixup.displacement (* displacement offset computed during operand emission, typically -1 *) );
				failFixup.resolved := in;
			END;


		END EmitBr;

		(* TODO: floats *)
		PROCEDURE EmitConv(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			irDestination, irSource: IntermediateCode.Operand;
			destination, source: ARRAY 2 OF Operand;
			temp: Operand;
			partType: IntermediateCode.Type;
		BEGIN
			irDestination := irInstruction.op1; irSource := irInstruction.op2;

			(* prepare operands *)
			destination[Low] := AcquireDestinationRegister(irDestination, Low, emptyOperand); (* TODO: find more optimal register allocation *)
			source[Low] := RegisterOrImmediateFromIrOperand(irSource, Low, destination[Low]);
			IF IsComplex(irDestination) THEN destination[High]:= AcquireDestinationRegister(irDestination, High, emptyOperand) END;
			IF IsComplex(irSource) THEN source[High] := RegisterOrImmediateFromIrOperand(irSource, High, destination[High]) END; (* note that the corresponding destination register is used as hint *)

			IF IsInteger(irDestination) THEN
				(* to integer: *)
				IF IsComplex(irDestination) THEN
					(* to complex integer: *)
					IF IsInteger(irSource) THEN
						(* integer to complex integer: *)
						IF IsComplex(irSource) THEN
							(* complex integer to complex integer: *)
							MovIfDifferent(destination[Low], source[Low]);
							MovIfDifferent(destination[High], source[High]);
						ELSE
							(* non-complex integer to complex integer: *)
							SignOrZeroExtendOperand(source[Low], irSource.type);
							MovIfDifferent(destination[Low], source[Low]);

							IF irDestination.type.form = IntermediateCode.UnsignedInteger THEN
								Emit2(opMOV, destination[High], InstructionSet.NewImmediate(0));
							ELSE
								(* for signed values the high part is set to 0...0 or 1...1, depending on the sign of the low part *)
								Emit2(opMOV, destination[High], InstructionSet.NewRegister(source[Low].register, InstructionSet.shiftASR, None, 32))
							END
						END

					ELSIF IsSinglePrecisionFloat(irSource) THEN
						ASSERT(backend.useFPU);
						(* single precision float to complex integer: *)
						temp := GetFreeRegister(IntermediateCode.FloatType(32));
						IF irDestination.type.form = IntermediateCode.UnsignedInteger THEN
							(* single precision float to non-complex unsigned integer: *)
							Emit2(opFTOUIS, temp, source[Low]);
						ELSE
							(* single precision float to non-complex signed integer: *)
							Emit2(opFTOSIS, temp, source[Low]);
						END;
						Emit2(opFMRS, destination[Low], temp);
						IF irDestination.type.form = IntermediateCode.UnsignedInteger THEN
							Emit2(opMOV, destination[High], InstructionSet.NewImmediate(0));
						ELSE
							(* for signed values the high part is set to 0...0 or 1...1, depending on the sign of the low part *)
							Emit2(opMOV, destination[High], InstructionSet.NewRegister(destination[Low].register, InstructionSet.shiftASR, None, 32))
						END
					ELSE
						(* anything else to complex-integer: *)
						HALT(200)
					END
				ELSE
					(* to non-complex integer: *)
					IF IsInteger(irSource) THEN
						(* integer to non-complex integer: ignore high part of source *)
						GetPartType(irSource.type, Low, partType);
						SignOrZeroExtendOperand(source[Low], partType);
						MovIfDifferent(destination[Low], source[Low])
					ELSIF IsSinglePrecisionFloat(irSource) THEN
						ASSERT(backend.useFPU);
						(* single precision float to non-complex integer: *)
						temp := GetFreeRegister(IntermediateCode.FloatType(32));
						IF irDestination.type.form = IntermediateCode.UnsignedInteger THEN
							(* single precision float to non-complex unsigned integer: *)
							Emit2(opFTOUIS, temp, source[Low]);
						ELSE
							(* single precision float to non-complex signed integer: *)
							Emit2(opFTOSIS, temp, source[Low]);
						END;
						Emit2(opFMRS, destination[Low], temp)
					ELSE
						(* anything to non-complex integer: *)
						HALT(200)
					END
				END

			ELSIF IsSinglePrecisionFloat(irDestination) THEN
				(* to single precision float: *)
			 	IF IsInteger(irSource) THEN
			 		(* integer to single precision float: ignore high part of source *)
			 		temp := GetFreeRegister(IntermediateCode.FloatType(32));
			 		Emit2(opFMSR, temp, source[Low]);
		 			IF irSource.type.form = IntermediateCode.UnsignedInteger THEN
						(* non-complex unsigned integer to single precision float: *)
						Emit2(opFUITOS, destination[Low], temp)
					ELSE
						(* non-complex signed integer to single precision float: *)
						Emit2(opFSITOS, destination[Low], temp)
					END
			 	ELSIF IsSinglePrecisionFloat(irSource) THEN
			 		(* single precision float to single precision float: *)
			 		MovIfDifferent(destination[Low], source[Low])
			 	ELSE
			 		(* anything else to single precision float: *)
			 		HALT(200)
			 	END
			ELSE
				(* to anything else: *)
				HALT(200)
			END;

			WriteBack(irDestination, Low, destination[Low]);
			IF IsComplex(irDestination) THEN WriteBack(irInstruction.op1, High, destination[High]) END
		END EmitConv;

		(** get the register that is dedicated to store a return value of a function **)
		PROCEDURE ResultRegister(part: LONGINT; type: IntermediateCode.Type): InstructionSet.Operand;
		VAR
			result: Operand;
		BEGIN
			IF (type.form IN IntermediateCode.Integer) OR ~(backend.useFPU) THEN
				IF part = Low THEN result := opRES
				ELSIF part = High THEN result := opRESHI
				ELSE HALT(200)
				END
			ELSIF type.form = IntermediateCode.Float THEN
				ASSERT(type.sizeInBits = 32, 200);
				result := opRESFS
			END;
			RETURN result
		END ResultRegister;

		PROCEDURE EmitReturn(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			source: Operand;
		BEGIN
			source := RegisterOrImmediateFromIrOperand(irInstruction.op1, part, ResultRegister(part, irInstruction.op1.type)); (* note: the result register is given as a hint *)
			MovIfDifferent(ResultRegister(part, irInstruction.op1.type), source)
		END EmitReturn;

		PROCEDURE EmitResult(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT);
		VAR
			destinationRegister: Operand;
		BEGIN
			destinationRegister := AcquireDestinationRegister(irInstruction.op1, part, emptyOperand);
			MovIfDifferent(destinationRegister, ResultRegister(part, irInstruction.op1.type));
			WriteBack(irInstruction.op1, part, destinationRegister)
		END EmitResult;

		PROCEDURE EmitTrap(CONST irInstruction: IntermediateCode.Instruction);
		BEGIN
			ASSERT(irInstruction.op1.mode = IntermediateCode.ModeNumber);

			Emit1(opSWI, InstructionSet.NewImmediate(LONGINT(irInstruction.op1.intValue))) (* software interrupt *)
		END EmitTrap;

		PROCEDURE EmitCas(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			addressReg, addressBaseReg, comparandReg, comparandBaseReg, comparatorReg, comparatorBaseReg, tempReg: Operand
		BEGIN
			addressReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
			addressBaseReg := RegisterFromIrOperand(irInstruction.op1, Low, addressReg);
			MovIfDifferent(addressReg, addressBaseReg);
			IF IntermediateCode.OperandEquals (irInstruction.op2, irInstruction.op3) THEN
				Emit2(opLDR, opRES, InstructionSet.NewImmediateOffsetMemory(addressReg.register, 0, {InstructionSet.Increment}));
			ELSE
				comparandReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
				comparandBaseReg := RegisterFromIrOperand(irInstruction.op2, Low, comparandReg);
				MovIfDifferent(comparandReg, comparandBaseReg);
				comparatorReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
				comparatorBaseReg := RegisterFromIrOperand(irInstruction.op3, Low, comparatorReg);
				MovIfDifferent(comparatorReg, comparatorBaseReg);
				Emit2(opLDREX, opRES, addressReg);
				Emit2(opCMP, opRES, comparandReg);
				tempReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
				Emit3WithCondition(opSTREX, tempReg, comparatorReg, addressReg, InstructionSet.conditionEQ);
				Emit2WithCondition(opCMP, tempReg, InstructionSet.NewImmediate(1), InstructionSet.conditionEQ);
				Emit1WithCondition(opB, InstructionSet.NewImmediate (-24), InstructionSet.conditionEQ);
			END;	
		END EmitCas;

		(* possible optimization: use a combination of LDR and LDRB (would be 4x faster on average) *)
		PROCEDURE EmitCopy(VAR irInstruction: IntermediateCode.Instruction);
		VAR
			targetBaseReg, sourceBaseReg, length, lastSourceAddress, currentTargetReg, currentSourceReg, tempReg: Operand;
		BEGIN
			ASSERT((irInstruction.op1.type.form = IntermediateCode.UnsignedInteger) & (irInstruction.op1.type.sizeInBits = 32));
			ASSERT((irInstruction.op2.type.form = IntermediateCode.UnsignedInteger) & (irInstruction.op2.type.sizeInBits = 32));
			ASSERT((irInstruction.op3.type.form = IntermediateCode.UnsignedInteger) & (irInstruction.op3.type.sizeInBits = 32));

			currentTargetReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
			currentSourceReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));

			(* note that the registers that store the current addresses are used as hints: *)
			targetBaseReg := RegisterFromIrOperand(irInstruction.op1, Low, currentTargetReg);
			sourceBaseReg := RegisterFromIrOperand(irInstruction.op2, Low, currentSourceReg);

			MovIfDifferent(currentTargetReg, targetBaseReg);
			MovIfDifferent(currentSourceReg, sourceBaseReg);

			lastSourceAddress := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
			length := RegisterOrImmediateFromIrOperand(irInstruction.op3, Low, lastSourceAddress); (* note that the last source address register is used as hint*)

			Emit3(opADD, lastSourceAddress, sourceBaseReg, length);

			tempReg := GetFreeRegister(IntermediateCode.UnsignedIntegerType(32));
			Emit2WithFlags(opLDR, tempReg, InstructionSet.NewImmediateOffsetMemory(currentSourceReg.register, 1, {InstructionSet.Increment, InstructionSet.PostIndexed}), {InstructionSet.flagB});
			Emit2WithFlags(opSTR, tempReg, InstructionSet.NewImmediateOffsetMemory(currentTargetReg.register, 1, {InstructionSet.Increment, InstructionSet.PostIndexed}), {InstructionSet.flagB});
			Emit2(opCMP, currentSourceReg, lastSourceAddress);
			Emit1WithCondition(opB, InstructionSet.NewImmediate(-20), InstructionSet.conditionLT)
		END EmitCopy;

		PROCEDURE EmitFill(CONST irInstruction: IntermediateCode.Instruction; down: BOOLEAN);
		BEGIN
			HALT(200) (* note that this instruction is not used at the moment *)
		END EmitFill;

		(* PREPARATION OF OPERATIONS *)

		(** swap a pair of IR operands **)
		PROCEDURE SwapIrOperands(VAR left, right: IntermediateCode.Operand);
		VAR
			temp: IntermediateCode.Operand;
		BEGIN
			temp := left;
			left := right;
			right := temp
		END SwapIrOperands;

		PROCEDURE PrepareSingleSourceOp(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT; VAR destinationRegister, sourceOperand: Operand);
		BEGIN
			destinationRegister := AcquireDestinationRegister(irInstruction.op1, part, emptyOperand);
			sourceOperand := RegisterFromIrOperand(irInstruction.op2, part, destinationRegister); (* note that the destination register is used as hint *)
		END PrepareSingleSourceOp;

		PROCEDURE PrepareSingleSourceOpWithImmediate(VAR irInstruction: IntermediateCode.Instruction; part: LONGINT; VAR destinationRegister, sourceOperand: Operand);
		BEGIN
			destinationRegister := AcquireDestinationRegister(irInstruction.op1, part, emptyOperand);
			sourceOperand := RegisterOrImmediateFromIrOperand(irInstruction.op2, part, destinationRegister); (* note that the destination register is used as hint *)
		END PrepareSingleSourceOpWithImmediate;

		PROCEDURE PrepareDoubleSourceOpWithImmediate(CONST irInstruction: IntermediateCode.Instruction; part: LONGINT; VAR destinationRegister, leftSourceOperand, rightSourceOperand: Operand; VAR isSwapped: BOOLEAN);
		VAR
			irDestination, irLeft, irRight: IntermediateCode.Operand;
		BEGIN
			irDestination := irInstruction.op1;
			irLeft := irInstruction.op2;
			irRight := irInstruction.op3;

			destinationRegister:= AcquireDestinationRegister(irDestination, part, emptyOperand);

			(* swap operands such that the right one is an immediate *)
			IF IrOperandIsDirectlyEncodable(irLeft, part) & ~IrOperandIsDirectlyEncodable(irRight, part) THEN
				SwapIrOperands(irLeft, irRight);
				isSwapped := TRUE
			ELSIF IntermediateCode.OperandEquals(irRight, irDestination) THEN
				SwapIrOperands(irLeft, irRight);
				isSwapped := TRUE
			ELSE
				isSwapped := FALSE
			END;

			leftSourceOperand := RegisterFromIrOperand(irLeft, part, destinationRegister); (* the destination register is used as hint *)
			IF IsSameRegister(leftSourceOperand, destinationRegister) THEN
				rightSourceOperand := RegisterOrImmediateFromIrOperand(irRight, part, emptyOperand) (* no hint is provided *)
			ELSE
				rightSourceOperand := RegisterOrImmediateFromIrOperand(irRight, part, destinationRegister)  (* the destination register is again used as hint *)
			END
		END PrepareDoubleSourceOpWithImmediate;

		PROCEDURE PrepareDoubleSourceOp(CONST irInstruction: IntermediateCode.Instruction; part: LONGINT; VAR destinationRegister, leftSourceOperand, rightSourceOperand: Operand);
		VAR
			irDestination, irLeft, irRight: IntermediateCode.Operand;
		BEGIN
			irDestination := irInstruction.op1;
			irLeft := irInstruction.op2;
			irRight := irInstruction.op3;

			destinationRegister:= AcquireDestinationRegister(irDestination, part, emptyOperand);

			IF IntermediateCode.OperandEquals(irRight, irDestination) THEN
				leftSourceOperand := RegisterFromIrOperand(irLeft, part, emptyOperand); (* do not use destination register as hint *)
			ELSE
				leftSourceOperand := RegisterFromIrOperand(irLeft, part, destinationRegister); (* the destination register is used as hint *)
			END;
			IF IsSameRegister(leftSourceOperand, destinationRegister) OR IntermediateCode.OperandEquals(irRight, irDestination) THEN
				rightSourceOperand := RegisterFromIrOperand(irRight, part, emptyOperand) (* no hint is provided *)
			ELSE
				rightSourceOperand := RegisterFromIrOperand(irRight, part, destinationRegister)  (* the destination register is again used as hint *)
			END
		END PrepareDoubleSourceOp;

	END CodeGeneratorARM;

	BackendARM = OBJECT(IntermediateBackend.IntermediateBackend)
	VAR
		cg: CodeGeneratorARM;
		system: Global.System;
		useFPU: BOOLEAN;
		initLocals: BOOLEAN;

		PROCEDURE & InitBackendARM;
		BEGIN
			useFPU := FALSE;
			InitIntermediateBackend;
			SetRuntimeModuleName(DefaultRuntimeModuleName);
			SetNewObjectFile(TRUE,FALSE);
			system := NIL;
			initLocals := TRUE;
			SetHasLinkRegister;
		END InitBackendARM;

		PROCEDURE Initialize(diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; flags: SET; checker: SemanticChecker.Checker; system: Global.System);
		BEGIN
			Initialize^(diagnostics, log, flags, checker, system);
			NEW(cg, runtimeModuleName, diagnostics, SELF)
		END Initialize;

		PROCEDURE EnterCustomBuiltins;
		VAR
			procedureType: SyntaxTree.ProcedureType;
			parameter: SyntaxTree.Parameter;

			PROCEDURE New;
			BEGIN procedureType := SyntaxTree.NewProcedureType(-1, NIL)
			END New;

			PROCEDURE BoolRet;
			BEGIN procedureType.SetReturnType(system.booleanType)
			END BoolRet;

			PROCEDURE IntRet;
			BEGIN procedureType.SetReturnType(Global.Integer32)
			END IntRet;

			PROCEDURE IntPar;
			BEGIN
				parameter := SyntaxTree.NewParameter(-1, procedureType, SyntaxTree.NewIdentifier(""), SyntaxTree.ValueParameter);
				parameter.SetType(Global.Integer32); procedureType.AddParameter(parameter)
			END IntPar;

			PROCEDURE AddressPar;
			BEGIN
				parameter := SyntaxTree.NewParameter(-1, procedureType, SyntaxTree.NewIdentifier(""), SyntaxTree.ValueParameter);
				parameter.SetType(Global.Unsigned32); procedureType.AddParameter(parameter)
			END AddressPar;

			PROCEDURE IntVarPar;
			BEGIN
				parameter := SyntaxTree.NewParameter(-1, procedureType, SyntaxTree.NewIdentifier(""), SyntaxTree.VarParameter);
				parameter.SetType(Global.Integer32); procedureType.AddParameter(parameter)
			END IntVarPar;

			PROCEDURE RealVarPar;
			BEGIN
				parameter := SyntaxTree.NewParameter(-1, procedureType, SyntaxTree.NewIdentifier(""), SyntaxTree.VarParameter);
				parameter.SetType(Global.Float32); procedureType.AddParameter(parameter)
			END RealVarPar;

			PROCEDURE Finish(CONST name: ARRAY OF CHAR; number: SHORTINT);
			BEGIN Global.NewCustomBuiltin(name, system.systemScope, number, procedureType);
			END Finish;

		BEGIN
			New; IntRet; Finish("SP", GetSP);
			New; AddressPar; Finish("SetSP", SetSP);
			New; IntRet; Finish("FP", GetFP);
			New; AddressPar; Finish("SetFP", SetFP);
			New; IntRet; Finish("PC", GetPC);
			New; AddressPar; Finish("SetPC", SetPC);
			New; IntRet; Finish("LNK", GetLNK);
			New; AddressPar; Finish("SetLNK", SetLNK);
			New; IntPar; IntPar;  Finish("LDPSR", LDPSR);
			New; IntPar; IntVarPar; Finish("STPSR", STPSR);
			New; IntPar; IntPar; IntPar; Finish("LDCPR", LDCPR);
			New; IntPar; IntPar; IntVarPar; Finish("STCPR", STCPR);
			New; IntPar; Finish("FLUSH", FLUSH);
			New; BoolRet; IntPar; Finish("NULL", NULL);
			New; IntRet; IntPar; IntPar; Finish("XOR", XOR);
			New; IntVarPar; IntPar; IntPar; Finish("MULD", MULD);
			New; IntVarPar; IntPar; IntPar; Finish("ADDC", ADDC);
			New; RealVarPar; IntPar; Finish("PACK", PACK);
			New; RealVarPar; IntVarPar; Finish("UNPK", UNPK);
		END EnterCustomBuiltins;

		PROCEDURE GetSystem(): Global.System;
		BEGIN
			(* create system object if not yet existing *)
			IF system = NIL THEN

				(* used stack frame layout:

								param 1
								param 2
								...
								param n-1
					FP+8 ->	param n
					FP+4 ->	old LR
					FP ->		old FP
					FP-4 ->	local 1
								local 2
								...
								spill 1
								spill 2
								....
				*)

				(*
				codeUnit, dataUnit = 8, 8
				addressSize = 32
				minVarAlign, maxVarAlign = 32, 32
				minParAlign, maxParAlign = 8, 32
				offsetFirstPar = 32 * 2
				registerParameters = 0
				*)

				NEW(system, 8, 8, 32, (*32*) 8, 32, 8, 32, 32 * 2, 0, cooperative);

				IF oberon07 THEN
					IF Trace THEN D.String("Oberon07"); D.Ln END;
					Global.SetDefaultDeclarations(system, 32) (* each basic type uses at least 32 bits -> INTEGER will be 32 bits long *)
				ELSE
					IF Trace THEN D.String("not Oberon07"); D.Ln END;
					Global.SetDefaultDeclarations(system, 8) (* INTEGER will be 16 bits long *)
				END;

				Global.SetDefaultOperators(system);

				EnterCustomBuiltins
			END;
			RETURN system
		END GetSystem;

		(** whether the code generator can generate code for a certain IR instruction
		if not, where to find the runtime procedure that is to be called instead **)
		PROCEDURE SupportedInstruction(CONST irInstruction: IntermediateCode.Instruction; VAR moduleName, procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			(* only necessary for binary object file format for symbol / module entry in IntermediateBackend *)
			RETURN cg.Supported(irInstruction, moduleName, procedureName);
		END SupportedInstruction;

		(** whether a certain intermediate code immediate value can be directly appear in code
		if not, the value is stored in a const section and loaded from there **)
		PROCEDURE SupportedImmediate(CONST irImmediateOperand: IntermediateCode.Operand): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			(* TODO: remove this *)
			RETURN TRUE; (* tentatively generate all immediates, as symbol fixups are not yet implemented *)

			result := FALSE;
			IF (irImmediateOperand.type.form IN IntermediateCode.Integer) & (irImmediateOperand.type.sizeInBits <= 32) THEN
				(* 32 bit integers *)
				IF cg.ValueIsDirectlyEncodable(LONGINT(irImmediateOperand.intValue)) THEN
					(* the value can be directly encoded as an ARM immediate operand *)
					result := TRUE
				ELSIF cg.ValueComposition(LONGINT(irImmediateOperand.intValue), FALSE, emptyOperand) <= 2 THEN (* TODO: find reasonable limit *)
					(* the value can be generated using a limited amount of intructions *)
					result := TRUE
				END
			END;
			RETURN result
		END SupportedImmediate;

		PROCEDURE GenerateBinary(module: Sections.Module; dump: Streams.Writer);
		VAR
			in: Sections.Section;
			out: BinaryCode.Section;
			name: Basic.SectionName;
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

			(*
			PROCEDURE Resolve(VAR fixup: BinaryCode.Fixup);
			BEGIN
				IF (fixup.symbol.name # "") & (fixup.resolved = NIL) THEN fixup.resolved := module.allSections.FindByName(fixup.symbol.name) END;
			END Resolve;
			
		 	(* recompute fixup positions and assign binary sections *)
		 	PROCEDURE PatchFixups(section: BinaryCode.Section);
			VAR resolved: BinaryCode.Section; fixup: BinaryCode.Fixup; symbolOffset, offsetWithinSection: LONGINT; in: IntermediateCode.Section;
			BEGIN
				fixup := section.fixupList.firstFixup;
				WHILE fixup # NIL DO
					Resolve(fixup);
					IF  (fixup.resolved # NIL) & (fixup.resolved(IntermediateCode.Section).resolved # NIL) THEN
						resolved := fixup.resolved(IntermediateCode.Section).resolved(BinaryCode.Section);
						in := fixup.resolved(IntermediateCode.Section);

						(* TODO: is this correct? *)
						symbolOffset := fixup.symbolOffset;
						ASSERT(fixup.symbolOffset < in.pc);
						IF (fixup.symbolOffset # 0) & (symbolOffset < in.pc) THEN
							offsetWithinSection := in.instructions[fixup.symbolOffset].pc;

							(*
							(* TENTATIVE *)
							D.String("FIXUP PATCH:"); D.Ln;
							D.String("    symbol name: "); fixup.symbol.DumpName(D.Log); D.String("/");
							D.String("    symbol offset: "); D.Int(fixup.symbolOffset, 0); D.Ln;
							D.String("    offsetWithinSection"); D.Int(offsetWithinSection, 0); D.Ln;
							D.String("    fixup.displacement (before)"); D.Int(fixup.displacement, 0); D.Ln; ; D.Ln;
							D.Update;
							*)

							(* remove the fixup's symbol offset (in IR units) and change the displacement (in system units) accordingly: *)
							fixup.SetSymbol(fixup.symbol.name, fixup.symbol.fingerprint, 0, offsetWithinSection + fixup.displacement)
						END
					END;
					fixup := fixup.nextFixup;
				END;
			END PatchFixups;
			*)

		BEGIN
		 	cg.SetModule(module);
		 	cg.dump := dump;

		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
		 		IF in.type = Sections.InlineCodeSection THEN
		 			Basic.SegmentedNameToString(in.name, name);
			 		out := ResolvedSection(in(IntermediateCode.Section));
			 		cg.dump := out.comments;
			 		cg.Section(in(IntermediateCode.Section), out);
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
		 			Basic.SegmentedNameToString(in.name, name);

			 		IF (in.type # Sections.InlineCodeSection) & (in(IntermediateCode.Section).resolved = NIL) THEN
				 		out := ResolvedSection(in(IntermediateCode.Section));
				 		cg.Section(in(IntermediateCode.Section),out);
			 		END
			 	END
			UNTIL initialSectionCount = module.allSections.Length(); (* process remaining sections that have been added during traversal of sections *)

		 	FOR i := 0 TO module.allSections.Length() - 1 DO
			 	in := module.allSections.GetSection(i);
	 			Basic.SegmentedNameToString(in.name, name);
			 	in := module.allSections.GetSection(i);
		 		PatchFixups(in(IntermediateCode.Section).resolved)
		 	END;

			IF cg.error THEN Error("", Diagnostics.Invalid, Diagnostics.Invalid,  "") END
		END GenerateBinary;

		(** create an ARM code module from an intermediate code module **)
		PROCEDURE ProcessIntermediateCodeModule*(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		VAR
			result: Formats.GeneratedModule;
		BEGIN
			ASSERT(intermediateCodeModule IS Sections.Module);
			result := ProcessIntermediateCodeModule^(intermediateCodeModule);

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
			options.Add(0X, UseFPUFlag, Options.Flag);
			options.Add(0X, "noInitLocals", Options.Flag);
			DefineOptions^(options);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		BEGIN
			IF options.GetFlag(UseFPUFlag) THEN useFPU := TRUE END;
			IF options.GetFlag("noInitLocals") THEN initLocals := FALSE END;
			GetOptions^(options);
		END GetOptions;

		PROCEDURE DefaultObjectFileFormat(): Formats.ObjectFileFormat;
		BEGIN RETURN ObjectFileFormat.Get();
		END DefaultObjectFileFormat;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN NIL
		END DefaultSymbolFileFormat;

		(** get the name of the backend **)
		PROCEDURE GetDescription(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "ARM"
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

	END BackendARM;

VAR
	emptyOperand: Operand;

	PROCEDURE Assert(condition: BOOLEAN; CONST message: ARRAY OF CHAR);
	BEGIN ASSERT(condition, 100)
	END Assert;

	PROCEDURE Halt(CONST message: ARRAY OF CHAR);
	BEGIN HALT(100)
	END Halt;

	PROCEDURE PowerOf2(val: HUGEINT;  VAR exp: LONGINT): BOOLEAN;
	BEGIN
		IF val <= 0 THEN RETURN FALSE END;
		exp := 0;
		WHILE ~ODD(val) DO
			val := val DIV 2;
			INC(exp)
		END;
		RETURN val = 1
	END PowerOf2;

	(** get the ARM code section that corresponds to an intermediate code section **)
	PROCEDURE ResolvedSection(irSection: IntermediateCode.Section): BinaryCode.Section;
	VAR
		result: BinaryCode.Section;
	BEGIN
		IF irSection.resolved = NIL THEN
			NEW(result, irSection.type, irSection.priority, 8, irSection.name, irSection.comments # NIL, FALSE);

			(* set fixed position or alignment
			(also make sure that any section has an alignment of at least 4 bytes) *)
			IF ~irSection.fixed & (irSection.positionOrAlignment < 4) THEN
				result.SetAlignment(FALSE, 4)
			ELSE
				result.SetAlignment(irSection.fixed, irSection.positionOrAlignment);
			END;

			irSection.SetResolved(result)
		ELSE
			result := irSection.resolved
		END;
		RETURN result
	END ResolvedSection;

	(** initialize the module **)
	PROCEDURE Init;
	BEGIN InstructionSet.InitOperand(emptyOperand)
	END Init;

	(** get an instance of the ARM backend **)
	PROCEDURE Get*(): Backend.Backend;
	VAR
		result: BackendARM;
	BEGIN
		NEW(result);
		RETURN result
	END Get;

	(* only for testing purposes *)
	PROCEDURE Test*;
	VAR
		codeGenerator: CodeGeneratorARM;
		value, count: LONGINT;
	BEGIN
		NEW(codeGenerator, "", NIL, NIL);
		FOR value := 0 TO 300 BY 1 DO
			count := codeGenerator.ValueComposition(value, FALSE, emptyOperand);
			D.String("value: "); D.Int(value, 0); D.String(" -> "); D.Int(count, 0); D.String(" instructions"); D.Ln;
		END;
		D.Ln; D.Update
	END Test;

	(* TODO: move this to Debugging.Mod or even Streams.Mod *)

	(** write an integer in binary right-justified in a field of at least ABS(w) characters.
		If w < 0 THEN ABS(w) least significant hex digits of 'value' are written (potentially including leading zeros or ones)
	**)
	PROCEDURE DBin*(value: HUGEINT; numberDigits: LONGINT);
	CONST
		MaxBitSize = SIZEOF(HUGEINT) * 8;
	VAR
		i, firstRelevantPos: LONGINT;
		prefixWithSpaces: BOOLEAN;
		chars: ARRAY MaxBitSize OF CHAR;
		prefixChar: CHAR;
	BEGIN
		prefixWithSpaces := numberDigits >= 0;
		numberDigits := ABS(numberDigits);

		(*
		- calculate an array containing the full bitstring
		- determine the position of the first relevant digit
		*)
		firstRelevantPos := 0;
		FOR i := MaxBitSize - 1 TO 0 BY -1 DO
			IF ODD(value) THEN
				chars[i] := '1';
				firstRelevantPos := i (* occurence of a '1' -> changes the first relevant position *)
			ELSE
				chars[i] := '0'
			END;
			value := value DIV 2
		END;

		(* if space prefixing is enabled, limit the number of digits to the relevant digits *)
		IF prefixWithSpaces THEN numberDigits := MAX(numberDigits, MaxBitSize - firstRelevantPos) END;

		IF numberDigits > MaxBitSize THEN
			IF prefixWithSpaces THEN prefixChar := ' ' ELSE prefixChar := chars[0] END; (* use spaces or sign bit *)
			FOR i := 1 TO numberDigits - MaxBitSize DO D.Char(prefixChar) END;
			numberDigits := MaxBitSize
		END;

		ASSERT((numberDigits >= 0) & (numberDigits <= MaxBitSize));
		FOR i := MaxBitSize - numberDigits TO MaxBitSize - 1 DO
			IF prefixWithSpaces & (i < firstRelevantPos) THEN D.Char(' ') ELSE D.Char(chars[i]) END
		END;
		D.Ln;
	END DBin;

BEGIN
	Init;

END FoxARMBackend.

SystemTools.FreeDownTo FoxARMBackend ~
