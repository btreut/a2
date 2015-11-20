MODULE FoxIntermediateCode; (** AUTHOR "fof"; PURPOSE "Oberon Compiler Abstract Intermediate Code"; *)
(* Active Oberon Compiler, (c) 2009 Felix Friedrich *)
IMPORT
	Sections := FoxSections, Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, BinaryCode := FoxBinaryCode, Backend := FoxBackend,
	SYSTEM, Streams, Global := FoxGlobal, D := Debugging, ObjectFile;

CONST
	(* operand modes *)
	Undefined*=0;
	ModeRegister*=1; (* register operand *)
	ModeMemory*=2; (* memory operand, may be memory on register or immediate *)
	ModeImmediate*=3; (* immediate number with type, may include section implying a fixup of the immediate *)
	ModeNumber*=4; (* immediate integer number without any type, typically used as meta-information for instructions *)
	ModeString*=5; (* for inline code *)
	ModeRule*=6; (* for inline code with replacements *)

	(* operand classes *)
	Undef* = {Undefined};
	Imm*={ModeImmediate};
	Reg*={ModeRegister};
	RegMem* = {ModeRegister,ModeMemory};
	RegMemImm* = {ModeRegister,ModeMemory,ModeImmediate};
	UndefReg*={Undefined,ModeRegister};
	UndefRegMem*={Undefined, ModeRegister, ModeMemory};
	UndefRule*= {Undefined, ModeRule};
	Num* = {ModeNumber};
	Str*= {ModeString};
	Any = {Undefined, ModeRegister, ModeMemory, ModeImmediate};

	(* operand types *)
	SignedInteger* = 1;
	UnsignedInteger* = 2;
	Integer*= {SignedInteger,UnsignedInteger};
	Float* = 3;

	(* instruction format flags *)
	SameType12*=0; (* type of first operand must match type of second operand *)
	SameType23*=1; (* type of second operand must match type of third operand *)
	Op1IsDestination*=2; (* first operand is a destination operand (=>may not be register with offset) *)
	Commute23*=3; (* second and third operand can be exchanged *)
	SameSize12*=4;

	(* operand sizes in bits *)
	Bits8*=8; Bits16*=16; Bits32*=32; Bits64*=64; Bits128*=128;

	(* register classes *)
	GeneralPurpose*=0;
	Parameter*=1; (* *)


	(* special registers *)
	None*=-1; (* no register assigned *)
	SP*=-2; (* stack pointer *)
	FP*=-3; (* frame pointer *)
	AP*=-4; (* activity pointer *)
	LR*=-5; (* link register *)
	HwRegister*=-32; (* any value below or equal hwreg is a user defined hardware register *)

	(* FoxProgTools.Enum -e -l=8
		nop mov conv call enter exit leave return result trap
		br breq brne brge brlt
		pop push neg not abs
		mul div  mod sub add and or xor shl shr rol ror
		cas copy fill asm data reserve label special NofOpcodes~
	*)
	nop*= 0; mov*= 1; conv*= 2; call*= 3; enter*= 4; exit*= 5; leave*= 6; return*= 7;
	result*= 8; trap*= 9; br*= 10; breq*= 11; brne*= 12; brge*= 13; brlt*= 14; pop*= 15;
	push*= 16; neg*= 17; not*= 18; abs*= 19; mul*= 20; div*= 21; mod*= 22; sub*= 23;
	add*= 24; and*= 25; or*= 26; xor*= 27; shl*= 28; shr*= 29; rol*= 30; ror*= 31;
	cas*= 32; copy*= 33; fill*= 34; asm*= 35; data*= 36; reserve*= 37; label*= 38; special*= 39;
	NofOpcodes*= 40;

	NotYetCalculatedSize = -2;

TYPE
	Type*=RECORD
		form-: SHORTINT; (* SignedInteger, UnsignedInteger or Float *)
		sizeInBits-: INTEGER; (* size in bits *)
		length-: LONGINT; (* vector length, if any. If zero then type is scalar *)
	END;

	RegisterClass*=RECORD
		class-: SHORTINT;
		number-: INTEGER;
	END;

	Rules*= POINTER TO ARRAY OF Operand;

	RegisterMap*= RECORD register*: LONGINT; name*: SyntaxTree.SourceCode END;
	BackendRules*= POINTER TO ARRAY OF RegisterMap;




	Operand* = RECORD
		mode-: SHORTINT; (* Undefined, ModeRegister, ModeImmediate, ModeMemory, ModeNumber or ModeString *)
		type-: Type; (* size and form *)
		register-: LONGINT; (* (virtual) register number, equals None if no register *)
		registerClass-: RegisterClass; (* normal register vs. special registers such as parameter registers *)
		offset-: LONGINT; (* offset on register or immediate symbol, in units *)
		intValue-: HUGEINT; (* integer value, if mode = ModeImmediate and type.form IN Integer or ModeNumber *)
		floatValue-: LONGREAL; (* real value, if mode = ModeImmediate and type.form = Float *)

		symbol-: ObjectFile.Identifier; (* referenced symbol, only valid for mode = ModeImmediate or mode = ModeMemory *)
		symbolOffset-: LONGINT; (* offset in IntermediateCode section, the difference to offset is that symbolOffset needs a resolving to real address offset *)
		resolved*: Sections.Section; (** only cache ! *)

		string-: SyntaxTree.SourceCode; (* string, if Mode = ModeString *)

		rule-: Rules;
	END;

	(*
		OperandMode			Used Fields

		ModeRegister			mode, type, register & offset
		ModeImmediate		mode, type, intValue or floatValue or symbol & offset
		ModeMemory			mode, type, register, offset, intValue or symbol & offset
		ModeNumber			mode, intValue
		ModeString			mode, string
	*)

	Instruction* = RECORD
		opcode-: SHORTINT; (* instruction opcode *)
		subtype-: SHORTINT; (* for special backend instruction *)
		textPosition-: LONGINT; (* for error handling and tracking (findPC) *)
		pc-: LONGINT; (* backend program counter (in bits) for debugging and for label fixups in backend *)
		op1*,op2*,op3*: Operand; (* first operand typically provides the result, if any *)
	END;

	InstructionFormat* = RECORD
		name-: ARRAY 16 OF CHAR; (* name, for assemby and disassembly *)
		op1-,op2-,op3-: SET; (* permitted modes for this kind of instruction *)
		flags-: SET; (* more flags determining restrictions (such as operand type matching etc.) *)
	END;

	Instructions*=POINTER TO ARRAY OF Instruction;


	(** code object *)
	Section*= OBJECT (Sections.Section)
	VAR
		instructions-: Instructions; (* array of instructions *)
		pc-: LONGINT; (* points to next instruction = len *)
		finally-: LONGINT; (* finally section starts at, -1 if none *)
		resolved-, alias-: BinaryCode.Section; (* reference to section containing compiled byte array *) (* TODO: ret rid of that? *)
		aliasOffset-: LONGINT; (* for aliases *)

		comments-: Sections.CommentWriter;
		validPAFEnter-,validPAFExit-: LONGINT; (* begin and end of code section where current PAF (procedure activation frame) is considered valid *)
		sizeInUnits: LONGINT;
		exported-: BOOLEAN;

		PROCEDURE GetPC(): LONGINT;
		BEGIN RETURN pc
		END GetPC;

		PROCEDURE & InitIntermediateSection*(type: SHORTINT; priority: INTEGER; CONST n: Basic.SegmentedName; symbol: SyntaxTree.Symbol; comment: BOOLEAN);
		BEGIN
			InitSection(type,priority,n,symbol); (*InitArray;*) pc := 0; resolved := NIL;
			IF comment THEN NEW(comments,GetPC) ELSE comments := NIL END;
			finally := -1;
			validPAFEnter := 0; validPAFExit := 0;
			sizeInUnits := NotYetCalculatedSize;
			exported := FALSE;
		END InitIntermediateSection;

		PROCEDURE SetExported*(e: BOOLEAN);
		BEGIN
			exported := e
		END SetExported;


		PROCEDURE EnableComments*(enabled: BOOLEAN);
		BEGIN
			IF enabled & (comments = NIL) THEN NEW(comments, GetPC)
			ELSIF ~enabled THEN comments := NIL
			END;
		END EnableComments;

		PROCEDURE EnterValidPAF*;
		BEGIN validPAFEnter := pc
		END EnterValidPAF;

		PROCEDURE ExitValidPAF*;
		BEGIN validPAFExit := pc
		END ExitValidPAF;

		PROCEDURE DeleteComments*;
		BEGIN comments := NIL
		END DeleteComments;

		PROCEDURE SetResolved*(section: BinaryCode.Section);
		BEGIN resolved := section
		END SetResolved;

		PROCEDURE SetAlias*(section: BinaryCode.Section; offset: LONGINT);
		BEGIN
			alias := section; aliasOffset := offset;
		END SetAlias;


		PROCEDURE SetFinally*(atPc: LONGINT);
		BEGIN finally := atPc
		END SetFinally;

		PROCEDURE GetSize*(): LONGINT;
		VAR
			i: LONGINT;
			instruction: Instruction;
		BEGIN
			IF sizeInUnits = NotYetCalculatedSize THEN
				sizeInUnits := Sections.UnknownSize; (* default value *)

				IF bitsPerUnit # Sections.UnknownSize THEN (* only calculate the size if the unit size is known *)
					IF (type = Sections.VarSection) OR (type = Sections.ConstSection) THEN
						sizeInUnits := 0;
						(* go through all instructions *)
						FOR i := 0 TO pc - 1 DO
							instruction := instructions[i];
							CASE instruction.opcode OF
							| data:
								(* TODO: correct? *)
								ASSERT((instruction.op1.mode = ModeImmediate) OR (instruction.op1.mode = ModeMemory));
								ASSERT((instruction.op1.type.sizeInBits MOD bitsPerUnit) = 0);
								INC(sizeInUnits, instruction.op1.type.sizeInBits DIV bitsPerUnit); (* TODO: correct conversion from bits to units? *)

							| reserve:
								ASSERT(instruction.op1.mode = ModeNumber);
								INC(sizeInUnits, LONGINT(instruction.op1.intValue))

							ELSE
								HALT(100); (* a var/const section may not contain any other type of instruction *)
							END
						END
					END
				END

			END;
			RETURN sizeInUnits
		END GetSize;

		PROCEDURE InitArray;
		CONST MinInstructions = 8;
		BEGIN
			IF instructions = NIL THEN NEW(instructions, MinInstructions); END;
			pc := 0;
		END InitArray;


		(* very useful for debugging:
		PROCEDURE Assert*(b: BOOLEAN; CONST s: ARRAY OF CHAR);
		BEGIN
			IF ~b THEN commentWriter.String("ASSERT FAILED: "); commentWriter.String(s); commentWriter.Ln END;
		END Assert;
		*)

		PROCEDURE Emit*(instruction: Instruction);
		VAR new: Instructions;
			op1size,op2size,op3size,op1form,op2form,op3form: LONGINT;
			i: SIZE;
		BEGIN
			op1size := instruction.op1.type.sizeInBits;
			op2size := instruction.op2.type.sizeInBits;
			op3size := instruction.op3.type.sizeInBits;
			op1form := instruction.op1.type.form;
			op2form := instruction.op2.type.form;
			op3form := instruction.op3.type.form;

			IF SameType12 IN instructionFormat[instruction.opcode].flags THEN
				Assert(TypeEquals(instruction.op1.type,instruction.op2.type),"operands 1 and 2 not of same type");
			END;
			IF SameSize12 IN instructionFormat[instruction.opcode].flags THEN
				Assert(instruction.op1.type.sizeInBits*instruction.op1.type.length = instruction.op2.type.sizeInBits*instruction.op2.type.length, "operands 1 and 2 not of same size");
			END;
			IF SameType23 IN instructionFormat[instruction.opcode].flags THEN
				Assert(TypeEquals(instruction.op2.type,instruction.op3.type),"operands 2 and 3 not of same type");
			END;
			IF Op1IsDestination IN instructionFormat[instruction.opcode].flags THEN
				Assert((instruction.op1.mode # ModeRegister) OR (instruction.op1.offset = 0),"destination operand may not be register with nonzero offset");
			END;
			
			Assert(instruction.op1.mode IN instructionFormat[instruction.opcode].op1,"invalid format of op 1");
			Assert(instruction.op2.mode IN instructionFormat[instruction.opcode].op2,"invalid format of op 2");
			Assert(instruction.op3.mode IN instructionFormat[instruction.opcode].op3,"invalid format of op 3");

			Assert(instruction.op1.symbol.name[0] # 0, "not intialized operand 1");
			Assert(instruction.op2.symbol.name[0] # 0, "not intialized operand 2");
			Assert(instruction.op3.symbol.name[0] # 0, "not intialized operand 3");

			IF (instructions = NIL) THEN
				NEW(instructions, 16);
			ELSIF pc = LEN(instructions) THEN
				NEW(new,4*LEN(instructions));
				FOR i := 0 TO LEN(instructions)-1 DO
					new[i] := instructions[i];
				END;
				instructions := new;
			END;
			instruction.pc := pc;
			instructions[pc] := instruction;
			INC(pc);
			sizeInUnits := NotYetCalculatedSize;
		END Emit;

		PROCEDURE EmitAt*(at: LONGINT; instruction: Instruction);
		VAR oldpc: LONGINT;
		BEGIN
			oldpc := pc;
			pc := at; Assert(pc < LEN(instructions),"EmitAt only in existing code");
			Emit(instruction);
			pc := oldpc;
		END EmitAt;

		PROCEDURE Reset*;
		BEGIN
			sizeInUnits := NotYetCalculatedSize;
			pc := 0; 
		END Reset;
		
		PROCEDURE PatchOperands*(pc: LONGINT; op1,op2,op3: Operand);
		BEGIN instructions[pc].op1 := op1; instructions[pc].op2 := op2; instructions[pc].op3 := op3;
		END PatchOperands;

		PROCEDURE PatchAddress*(pc: LONGINT; symbolOffset: LONGINT);
		BEGIN
			ASSERT((br <= instructions[pc].opcode) & (instructions[pc].opcode <= brlt));
			ASSERT(instructions[pc].op1.symbol.name = SELF.name);
			(*
			ASSERT(instr[pc].op1.symbol = SELF);
			*)
			instructions[pc].op1.symbolOffset := symbolOffset;
		END PatchAddress;

		PROCEDURE SetPC*(at: LONGINT; pc: LONGINT);
		BEGIN instructions[at].pc := pc;
		END SetPC;

		PROCEDURE DumpCode*(w: Streams.Writer; from,to: LONGINT);
		VAR
			i: LONGINT;
			c: Sections.Comment;
		BEGIN
			IF comments # NIL THEN
				c := comments.firstComment;
				WHILE(c # NIL) & (c.pos <from) DO
					c := c.nextComment;
				END;
				i := from;
				WHILE(i<=to) DO
					IF (c # NIL) & (c.pos = i) THEN
						c.Dump(w); w.Ln;
						c := c.nextComment;
					END;
					w.Int(i,2); w.String(": ");
					DumpInstruction(w,instructions[i]);
					w.Ln;
					INC(i);
				END;
				IF (c#NIL) & (c.pos = to) THEN
					c.Dump(w); w.Ln;
				END;
			ELSE
				i := from;
				WHILE(i<=to) DO
					w.Int(i,2); w.String(": ");
					DumpInstruction(w,instructions[i]); w.Ln;
					INC(i);
				END;
			END;
		END DumpCode;

		(* inherited method *)
		PROCEDURE Dump(w: Streams.Writer);
		VAR ww: Basic.Writer;
		BEGIN
			IF resolved # NIL THEN
				Dump^(w);
				resolved.Dump(w)
			ELSE
				Dump^(w);
				ww := Basic.GetWriter(w);
				ww.IncIndent;
				ww.Ln;
				DumpCode(ww,0,pc-1);
				ww.DecIndent;
			END;
		END Dump;

	END Section;

	IntermediateBackend*= OBJECT (Backend.Backend)
	VAR
		runtimeModuleName-: SyntaxTree.IdentifierString;

		PROCEDURE SupportedInstruction*(CONST instr: Instruction; VAR moduleName,procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			moduleName := ""; procedureName := "";
			RETURN TRUE
		END SupportedInstruction;

		PROCEDURE SetRuntimeModuleName*(CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, runtimeModuleName);
		END SetRuntimeModuleName;

	END IntermediateBackend;


	VAR
		instructionFormat-: ARRAY NofOpcodes OF InstructionFormat;
		int8-, int16-, int32-, int64-, uint8-, uint16-, uint32-, uint64-, float32-, float64-, undef-: Type;
		GeneralPurposeRegister-: RegisterClass;
		empty: Operand;

	PROCEDURE Assert(condition: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN (*ASSERT(condition);*) IF ~condition THEN D.TraceBack END;
	END Assert;

	(** create a new section in a given section list
		- if the section already exists, reuse the existing section
		note: for compatibility with the old binary object file format, const sections can also be referred to as var sections
	**)
	PROCEDURE NewSection*(list: Sections.SectionList; type: SHORTINT; CONST name: Basic.SegmentedName; syntaxTreeSymbol: SyntaxTree.Symbol; dump: BOOLEAN): Section;
	VAR
		t0: SHORTINT;
		result: Sections.Section;
		section: Section;
	BEGIN
		ASSERT(name[0] > 0); (* must be initialized *)

		IF syntaxTreeSymbol # NIL THEN
			result := list.FindBySymbol(syntaxTreeSymbol);
		END;
		(* search by name *)
		IF result = NIL THEN
			result := list.FindByName(name);
		END;

		IF result # NIL THEN
			section := result(Section);


			(*
			t0 := result.type;
			IF t0 # type THEN
				D.String("section entered twice: "); Basic.WriteSegmentedName(D.Log, name);
				D.String(" type "); D.Int(t0,1); D.String(" --> "); D.Int(type,1); D.Ln
			END;
			*)

			ASSERT(result.name= name);
			(*ASSERT(result.symbol = syntaxTreeSymbol);*)
			RETURN section
		END;

		(* a valid name must be present *)
		ASSERT(name[0] > 0);

		(* create a new section and enter it *)
		NEW(section, type, 0 (* initial priority = 0 *), name, syntaxTreeSymbol, dump);
		IF syntaxTreeSymbol # NIL THEN section.SetFingerprint(syntaxTreeSymbol.fingerprint.shallow) END;
		list.AddSection(section);
		RETURN section
	END NewSection;

	PROCEDURE SameOperand*(CONST left, right: Operand): BOOLEAN;
	VAR mode: LONGINT;
	BEGIN
		mode := left.mode;
		IF (left.type.form =right.type.form) & (left.type.sizeInBits=right.type.sizeInBits) & (left.type.length = right.type.length) & (mode = right.mode) THEN
			CASE mode OF
			ModeRegister: RETURN (left.register = right.register) & (left.offset = right.offset)
			|ModeMemory: RETURN (left.register = right.register) &(left.offset = right.offset) & (left.symbol = right.symbol) & (left.symbolOffset = right.symbolOffset);
			|ModeImmediate:
				IF left.type.form = Float THEN
					RETURN (left.floatValue = right.floatValue) & (left.symbol = right.symbol) & (left.symbolOffset = right.symbolOffset)
				ELSE
					RETURN (left.intValue = right.intValue) & (left.symbol = right.symbol) & (left.symbolOffset = right.symbolOffset)
				END;
			|ModeNumber:
				RETURN left.intValue = right.intValue
			|ModeString:
				RETURN left.string = right.string
			|Undefined: (* nothing *) RETURN TRUE
			END;
		ELSE RETURN FALSE
		END;
	END SameOperand;

	(** check if an operand is valid at a certain location for a given instruction opcode **)
	PROCEDURE CheckOperand*(operand: Operand; opCode, location: LONGINT; VAR message: ARRAY OF CHAR): BOOLEAN;
	VAR
		validOperandModes: SET;
	BEGIN
		validOperandModes := {};
		CASE location OF
		| 0: validOperandModes := instructionFormat[opCode].op1
		| 1: validOperandModes := instructionFormat[opCode].op2
		| 2: validOperandModes := instructionFormat[opCode].op3
		END;
		IF ~(operand.mode IN validOperandModes) THEN
			message := "operand mode mismatch"; RETURN FALSE
		END;

		(* the following code was taken from the previous version of 'PROCEDURE CheckOperand' and adapted: *)
		CASE operand.mode OF
		| Undefined:
		| ModeNumber:
		| ModeMemory:
			IF operand.type.form = Undefined THEN message := "memory type form undefined"; RETURN FALSE END;
			IF operand.type.sizeInBits = 0 THEN message :="memory type size undefined"; RETURN FALSE END;
			IF operand.register # None THEN
				IF operand.symbol.name # "" THEN message :="symbol and register cannot be both set in a memory operand"; RETURN FALSE END
			ELSIF operand.symbol.name # "" THEN
				IF operand.intValue # 0 THEN message :="memory operand on non zero immediate with symbol # NIL"; RETURN FALSE END
			(*ELSE
				IF operand.intValue = 0 THEN message :="memory operand on address 0 zero without register and symbol"; RETURN FALSE END
			*)
			END
		| ModeRegister:
			IF operand.type.form = Undefined THEN message :="register type form undefined"; RETURN FALSE END;
			IF operand.type.sizeInBits = 0 THEN message :="register type size undefined"; RETURN FALSE END;
			IF operand.register = None THEN message :="register undefined in register operand"; RETURN FALSE END
		| ModeImmediate:
			IF operand.symbol.name # "" THEN
				IF operand.intValue # 0 THEN message :="forbidden immediate with symbol and intValue # 0"; RETURN FALSE END;
				IF operand.floatValue # 0 THEN message :="forbidden immediate with symbol and floatValue # 0"; RETURN FALSE END
			END
		| ModeString:
			IF operand.string = NIL THEN message :="nil string in string operand"; RETURN FALSE END
		END;

		RETURN TRUE
	END CheckOperand;

	(** check if an instruction is valid **)
	PROCEDURE CheckInstruction*(instruction: Instruction; VAR message: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		IF (SameType12 IN instructionFormat[instruction.opcode].flags) & ~TypeEquals(instruction.op1.type, instruction.op2.type) THEN
			message := "operands 1 and 2 not of same type";
			RETURN FALSE
		END;
		IF (SameSize12 IN instructionFormat[instruction.opcode].flags) & (instruction.op1.type.sizeInBits # instruction.op2.type.sizeInBits) THEN
			message := "operands 1 and 2 not of same size";
			RETURN FALSE
		END;
		IF (SameType23 IN instructionFormat[instruction.opcode].flags) & ~TypeEquals(instruction.op2.type, instruction.op3.type) THEN
			message := "operands 2 and 3 not of same type";
			RETURN FALSE
		END;
		IF (Op1IsDestination IN instructionFormat[instruction.opcode].flags) & (instruction.op1.mode = ModeRegister) & (instruction.op1.offset # 0) THEN
			message := "destination operand may not be register with nonzero offset";
			RETURN FALSE
		END;
		RETURN TRUE
	END CheckInstruction;

	PROCEDURE DumpRegister*(w: Streams.Writer; registerNumber: LONGINT; CONST registerClass: RegisterClass);
	BEGIN
		IF registerNumber = SP THEN
			w.String("sp")
		ELSIF registerNumber = FP THEN
			w.String("fp")
		ELSIF registerNumber = AP THEN
			w.String("ap")
		ELSIF registerNumber = LR THEN
			w.String("lr")
		ELSIF registerNumber > None THEN
			w.String("r"); w.Int(registerNumber, 0);
			IF registerClass.class = Parameter THEN w.String(":p"); w.Int(registerClass.number,0) END;
		ELSIF registerNumber <= HwRegister THEN
			w.String("h"); w.Int(HwRegister - registerNumber, 0)
		ELSE
			w.String("(invalid register)")
		END
	END DumpRegister;

	PROCEDURE DumpType*(w: Streams.Writer; type: Type);
	BEGIN
		IF type.length > 1 THEN
			w.String("v"); w.Int(type.length,0);
		END;
		CASE type.form OF
			| Undefined: w.String("(invalid type)")
			| UnsignedInteger: w.String("u"); w.Int(type.sizeInBits, 0)
			| SignedInteger: w.String("s"); w.Int(type.sizeInBits, 0)
			| Float: w.String("f"); w.Int(type.sizeInBits, 0)
		END
	END DumpType;

	PROCEDURE DumpOperand*(w: Streams.Writer; CONST operand: Operand );
	VAR i: LONGINT;

		PROCEDURE DumpString(CONST str: ARRAY OF CHAR);
		VAR
			i: LONGINT;
			ch: CHAR;
			newln: BOOLEAN;
		BEGIN
			w.String('"');
			i := 0;
			ch := str[i];
			WHILE ch # 0X DO
				IF (ch = 0DX) OR (ch = 0AX) THEN
					newln := TRUE
				ELSE
					IF newln THEN
						w.Ln;
						newln := FALSE;
					END;
					IF (ch = '"') OR (ch = '\') THEN
					 	w.Char( '\' );
					 	w.Char(ch);
					ELSE
					 	w.Char(ch);
					 END
				 END;
				INC(i);
				ch := str[i];
			END;
			w.String('"');
		END DumpString;

	BEGIN
		IF operand.type.form # Undefined THEN
			DumpType(w,operand.type); w.String(" ");
		END;

		CASE operand.mode OF
		Undefined: w.String("!Undefined");
		|ModeMemory:
				w.String("[");
				IF operand.register # None THEN
					DumpRegister(w,operand.register, operand.registerClass);
					IF operand.offset > 0 THEN w.String("+"); w.Int(operand.offset,1);
					ELSIF operand.offset < 0 THEN w.String("-"); w.Int(-operand.offset,1);
					END;
				ELSIF operand.symbol.name # "" THEN
					Basic.WriteSegmentedName(w,operand.symbol.name);
					IF operand.symbol.fingerprint # 0 THEN w.String("["); w.Hex(operand.symbol.fingerprint,-8); w.String("]"); END;
					w.String(":"); w.Int(operand.symbolOffset,1);
					IF operand.offset > 0 THEN w.String("+"); w.Int(operand.offset, 1);
					ELSIF operand.offset < 0 THEN w.String("-"); w.Int(-operand.offset, 1);
					END;
				ELSE w.Int(SHORT(operand.intValue),1);
				END;
				w.String("]");
		|ModeRegister:
			DumpRegister(w,operand.register, operand.registerClass);
			IF operand.offset > 0 THEN w.String("+"); w.Int(operand.offset,1);
			ELSIF operand.offset < 0 THEN w.String("-"); w.Int(-operand.offset,1);
			END;
		|ModeImmediate:
			IF operand.symbol.name # "" THEN
				Basic.WriteSegmentedName(w,operand.symbol.name);
				IF operand.symbol.fingerprint # 0 THEN w.String("["); w.Hex(operand.symbol.fingerprint,-8); w.String("]"); END;
				w.String(":"); w.Int(operand.symbolOffset,1);
				IF operand.offset > 0 THEN w.String("+"); w.Int(operand.offset, 1);
				ELSIF operand.offset < 0 THEN w.String("-"); w.Int(-operand.offset, 1);
				END
			ELSE
				IF operand.type.form IN Integer THEN
					IF (operand.intValue > MAX(LONGINT)) OR (operand.intValue < MIN(LONGINT)) THEN
						w.String("0");
						w.Hex(operand.intValue,0);
						w.String("H");
					ELSE
						w.Int(SHORT(operand.intValue),1);
					END
				ELSE
					w.Float(operand.floatValue,24);
				END;
			END;
		|ModeString:
			DumpString(operand.string^);
		|ModeNumber: w.Int(SHORT(operand.intValue),1);
		|ModeRule:
			w.String("rules");
			FOR i := 0 TO LEN(operand.rule)-1 DO
				w.String(" "); DumpOperand(w,operand.rule[i]);  w.String(" = "); DumpString(operand.rule[i].string^);
			END;
		END;
		(*
		w.Update();
		CheckOperand(operand);
		*)
	END DumpOperand;

	PROCEDURE TypeEquals*(CONST s1,s2: Type): BOOLEAN;
	BEGIN RETURN (s1.form = s2.form) & (s1.sizeInBits = s2.sizeInBits) & (s1.length = s2.length);
	END TypeEquals;

	PROCEDURE OperandEquals*(CONST s1,s2: Operand) : BOOLEAN;
	BEGIN
		RETURN (s1.mode = s2.mode) & (s1.register = s2.register) & (s1.offset = s2.offset) & (s1.intValue = s2.intValue) & (s1.floatValue = s2.floatValue)
		& (s1.symbol.name = s2.symbol.name) & (s1.string = s2.string) & (s1.symbolOffset = s2.symbolOffset) & TypeEquals(s1.type,s2.type);
	END OperandEquals;

	PROCEDURE Equals*(CONST i1, i2: Instruction):BOOLEAN;
	BEGIN
		IF i1.opcode # i2.opcode THEN RETURN FALSE END;
		IF i1.subtype # i2.subtype THEN RETURN FALSE END;
		IF i1.pc # i2.pc THEN RETURN FALSE END;
		IF ~OperandEquals(i1.op1, i2.op1) THEN RETURN FALSE END;
		IF ~OperandEquals(i1.op2, i2.op2) THEN RETURN FALSE END;
		IF ~OperandEquals(i1.op3, i2.op3) THEN RETURN FALSE END;
		RETURN TRUE
	END Equals;

	PROCEDURE DumpInstruction*(w: Streams.Writer; CONST instr: Instruction);
	BEGIN
		w.String(instructionFormat[instr.opcode].name);
		IF instr.op1.mode # Undefined THEN w.String(" "); DumpOperand(w,instr.op1) END;
		IF instr.op2.mode # Undefined THEN w.String(", "); DumpOperand(w,instr.op2) END;
		IF instr.op3.mode # Undefined THEN w.String(", "); DumpOperand(w,instr.op3) END;
		IF instr.opcode = special THEN w.String(" sub "); w.Int(instr.subtype,1) END;
	END DumpInstruction;

	PROCEDURE InitInstructions;

		PROCEDURE AddFormat(opcode: SHORTINT; CONST name: ARRAY OF CHAR; op1,op2,op3: SET; flags: SET);
		BEGIN
			COPY(name,instructionFormat[opcode].name);
			instructionFormat[opcode].op1 := op1;
			instructionFormat[opcode].op2 := op2;
			instructionFormat[opcode].op3 := op3;
			instructionFormat[opcode].flags := flags
		END AddFormat;

	BEGIN
		(* nop - no operation, may be used for optimisations *)
		AddFormat(nop, "nop", Undef, Undef, Undef, {});
		(* mov dest src - mov content of src to dest, if a third parameter is provided (set to a register),
			it has no meaning for interpreters or execution but provides a "reuse" hint for register allocators *)
		AddFormat(mov, "mov", RegMem, RegMemImm, UndefReg, {SameSize12,Op1IsDestination});
		(* conv dest src - convert src to dest,  type of conversion derived from type of operands *)
		AddFormat(conv, "conv", RegMem, RegMemImm, Undef, {Op1IsDestination});
		(* call adr parSize - procedure call, second operand contains parameter size *)
		AddFormat(call, "call", RegMemImm, Num, Undef,{});
		(* enter cc pafSize - set up procedure activation frame;  op1 = calling convention, op2 = size to be allocated on stack *)
		AddFormat(enter, "enter", Num, Num, Undef ,{});
		(* leave cc - remove paf, does not imply return, op1= calling convention, does not imply exit from procedure *)
		AddFormat(leave, "leave", Num, Undef, Undef ,{});
		(* return value : return value, op1= returned value, if any, does not imply exit from procedure *)
		AddFormat(return,"return",RegMemImm, Undef, Undef,{});
		(* exit parSize pcOffset cc - exit from procedure, op1 = offset that has to be subtracted from return address (e.g., used for ARM interrupt procedures), op2 = calling convention *)
		AddFormat(exit, "exit", Num, Num, Undef,{});
		(* result, store result to operand op1 *)
		AddFormat(result,"result",RegMem,Undef,Undef,{Op1IsDestination});
		(* trap num- interrupt*)
		AddFormat(trap, "trap", Num, Undef, Undef,{});
		(* br op1 - unconditional branch to op1 *)
		AddFormat(br, "br", RegMemImm, Undef, Undef,{});
		(* breq op1 op2 op3- branch to op1 if op2 = op3 *)
		AddFormat(breq, "breq", RegMemImm, RegMemImm, RegMemImm, {SameType23});
		(* brne op1 op2 op3 -  branch to op2 if op2 # op3 *)
		AddFormat(brne, "brne", RegMemImm, RegMemImm, RegMemImm, {SameType23});
		(* brlt op1 op2 op3 - branch to op1 if op2 < op3 , information about sign is derived from operands *)
		AddFormat(brlt, "brlt", RegMemImm, RegMemImm, RegMemImm, {SameType23}); (* sign of comparison is derived from types of op1 and op2 *)
		(* brge op1 op2 op3 - branch to op1 if op2 >= op3 , information about sign is derived from operands *)
		AddFormat(brge, "brge", RegMemImm, RegMemImm, RegMemImm, {SameType23});
		(* pop op1 - pop op1 from stack *)
		AddFormat(pop, "pop", RegMem, Undef, Undef,{Op1IsDestination});
		(* push op1 - push op1 to stack *)
		AddFormat(push, "push", RegMemImm, Undef, Undef,{});
		(* not dest src - invert bit mask *)
		AddFormat(not, "not", RegMem, RegMemImm, Undef,{SameType12,Op1IsDestination});
		(* neg dest src - negate (arithmetic) *)
		AddFormat(neg, "neg", RegMem, RegMemImm, Undef,{SameType12,Op1IsDestination});
		(* abs dest src - absolute value (arithmetic) *)
		AddFormat(abs, "abs", RegMem, RegMemImm, Undef,{SameType12,Op1IsDestination});
		(* mul dest left right - multiply, information about sign and form (integer/float) in operands *)
		AddFormat(mul, "mul", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination,Commute23});
		(* div dest left right - divide, information about sign and form (integer/float) in operands *)
		AddFormat(div, "div", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination});
		(* mod dest left right - modulus, information about sign and form (integer/float) in operands *)
		AddFormat(mod, "mod", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination});
		(* sub dest left right - subtract, information about sign and form (integer/float) in operands *)
		AddFormat(sub, "sub", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination});
		(* add dest left right - add, information about sign and form (integer/float) in operands *)
		AddFormat(add, "add", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination,Commute23});
		(* and dest left right - bitwise and *)
		AddFormat(and, "and", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination,Commute23});
		(* or dest left right - bitwise or *)
		AddFormat(or, "or", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination,Commute23});
		(* xor dest left right - bitwise xor *)
		AddFormat(xor, "xor", RegMem, RegMemImm, RegMemImm,{SameType12,SameType23,Op1IsDestination,Commute23});
		(* shl dest left right - shift left (arithmetic or logical, derived from sign of operands) *)
		AddFormat(shl, "shl", RegMem, RegMemImm, RegMemImm,{SameType12,Op1IsDestination}); (* logical or arithemtic shift, derived from type of operands *)
		(* shr dest left right - shift right (arithmetic or logical, derived from sign of operands)*)
		AddFormat(shr, "shr", RegMem, RegMemImm, RegMemImm,{SameType12,Op1IsDestination});
		(* rol dest left right - rotate left *)
		AddFormat(rol, "rol", RegMem, RegMemImm, RegMemImm,{SameType12,Op1IsDestination});
		(* ror dest left right - rotate right *)
		AddFormat(ror, "ror", RegMem, RegMemImm, RegMemImm,{SameType12,Op1IsDestination});
		(* cas dest old new - compare value at dest with old and store new if equal, previous value in result register *)
		AddFormat(cas, "cas", RegMemImm, RegMemImm, RegMemImm,{SameType23});
		(* copy dest src size - move a block of size op3 units of memory from [op2] to [op1] *)
		AddFormat(copy, "copy", RegMemImm, RegMemImm, RegMemImm,{SameType12,SameType23});
		(* fill dest val size - fill a block of size op2 units of memory from [op1] with value in op3 *)
		AddFormat(fill, "fill", RegMemImm, RegMemImm, RegMemImm,{SameType12});
		(* asm attribute - asm code contained in attribute *)
		AddFormat(asm, "asm", Str, UndefRule, UndefRule,{});
		(* data imm - instruction to build up constants or (global) variables *)
		AddFormat(data, "data", Imm, Undef, Undef,{});
		(* reserve number - instruction to build (global) variables *)
		AddFormat(reserve, "reserve",Num,Undef,Undef,{});
		(* label - pseudo-instruction to reference back to source code positions *)
		AddFormat(label, "label",Num,Undef,Undef,{});
		(* special instruction support for backend addtions *)
		AddFormat(special,"special",Any, Any, Any, {} );
	END InitInstructions;

	PROCEDURE InitInstruction*(VAR instr: Instruction; textPosition: LONGINT; opcode: SHORTINT; op1,op2,op3: Operand);
	VAR format: InstructionFormat; mode1, mode2, mode3: LONGINT; (* debugging *)
	BEGIN
		format := instructionFormat[opcode];
		mode1 := op1.mode;
		mode2 := op2.mode;
		mode3 := op3.mode;
		(*
		Assert(op1.mode IN format.op1,"first operand mode mismatch");
		Assert(op2.mode IN format.op2,"second operand mode mismatch");
		Assert(op3.mode IN format.op3,"third operand mode mismatch");
		*)

		Assert(op1.symbol.name[0] # 0, "not intialized operand 1");
		Assert(op2.symbol.name[0] # 0, "not intialized operand 2");
		Assert(op3.symbol.name[0] # 0, "not intialized operand 3");


		instr.opcode := opcode;
		instr.op1 := op1;
		instr.op2 := op2;
		instr.op3 := op3;
		instr.textPosition := textPosition;
	END InitInstruction;

	PROCEDURE InitInstruction2*(VAR instr: Instruction; textPosition: LONGINT; opcode: SHORTINT; op1,op2: Operand);
	BEGIN
		InitInstruction(instr, textPosition, opcode, op1, op2, empty);
	END InitInstruction2;

	PROCEDURE InitInstruction1*(VAR instr: Instruction; textPosition: LONGINT; opcode: SHORTINT; op1: Operand);
	BEGIN
		InitInstruction(instr, textPosition, opcode, op1, empty, empty);
	END InitInstruction1;

	PROCEDURE InitInstruction0*(VAR instr: Instruction; textPosition: LONGINT; opcode: SHORTINT);
	BEGIN
		InitInstruction(instr, textPosition, opcode, empty, empty, empty);
	END InitInstruction0;

	PROCEDURE SetSubType*(VAR instr: Instruction; subType: SHORTINT);
	BEGIN
		instr.subtype := subType
	END SetSubType;


	PROCEDURE InitOperand*(VAR op: Operand);
	BEGIN
		op.mode := Undefined;
		op.type.form := Undefined; op.type.sizeInBits := Undefined; op.type.length := 1;
		op.register := None; op.offset := 0; op.registerClass := GeneralPurposeRegister;
		op.intValue := 0;
		op.floatValue := 0;
		op.symbol.name := "";
		op.symbol.fingerprint := 0;
		op.symbolOffset := 0;
	END InitOperand;

	PROCEDURE InitRegister*(VAR op: Operand; type: Type; registerClass: RegisterClass;  register: LONGINT);
	BEGIN
		Assert((register >0) OR (register = SP) OR (register = FP) OR (register = AP) OR (register = LR) OR (register <= HwRegister) ,"unmapped register number");
		InitOperand(op);
		op.mode := ModeRegister;
		op.type := type;
		op.registerClass := registerClass;
		op.register := register;
	END InitRegister;

	PROCEDURE Register*(type: Type; registerClass: RegisterClass; register: LONGINT): Operand;
	VAR op: Operand;
	BEGIN InitRegister(op,type,registerClass, register); RETURN op
	END Register;

	PROCEDURE RegisterOffset*(type: Type; registerClass: RegisterClass; register, offset: LONGINT): Operand;
	VAR op: Operand;
	BEGIN InitRegister(op,type,registerClass, register); SetOffset (op, offset); RETURN op
	END RegisterOffset;

	PROCEDURE AddOffset*(VAR op: Operand; offset: LONGINT);
	BEGIN
		Assert((op.mode = ModeRegister) OR (op.mode = ModeMemory) OR (op.mode = ModeImmediate) & (op.type.form IN {SignedInteger, UnsignedInteger}),"offset not on register or integer immediate");
		IF (op.mode = ModeImmediate) & (op.symbol.name = "") THEN
			INC(op.intValue,offset)
		ELSE
			INC(op.offset,offset)
		END
	END AddOffset;

	PROCEDURE SetOffset*(VAR op: Operand; offset: LONGINT);
	BEGIN
		Assert((op.mode = ModeRegister) OR (op.mode = ModeImmediate) & (op.type.form IN {SignedInteger, UnsignedInteger}),"offset not on register or integer immediate");
		op.offset := offset
	END SetOffset;

	PROCEDURE SetSymbol*(VAR op: Operand; symbol: Sections.SectionName; fp: LONGINT);
	BEGIN
		op.symbol.name := symbol;
		op.symbol.fingerprint := fp;
	END SetSymbol;

	PROCEDURE SetIntValue*(VAR op: Operand; intValue: HUGEINT);
	BEGIN op.intValue := intValue
	END SetIntValue;

	PROCEDURE MakeMemory*(VAR op: Operand; type: Type);
	BEGIN
		Assert((op.mode = ModeRegister) & (op.type.length < 2) OR (op.mode = ModeMemory) OR (op.mode = ModeImmediate) & (op.type.form = UnsignedInteger) ,"operand mode not of register or unsigned integer immediate");
		op.type := type;
		op.mode := ModeMemory;
		ASSERT(op.register # 0);
	END MakeMemory;
	
	PROCEDURE MakeAddress*(VAR op: Operand; CONST type: Type);
	BEGIN
		ASSERT(op.mode = ModeMemory);
		IF op.register = None THEN
			op.mode := ModeImmediate;
		ELSE
			op.mode := ModeRegister;
			ASSERT(op.symbol.name = "");
		END;
		op.type := type;
	END MakeAddress;

	PROCEDURE InitAddress*(VAR op: Operand; type: Type; symbol: Sections.SectionName; fp: LONGINT; symbolOffset: LONGINT);
	BEGIN
		Assert(symbol # "","forbidden nil symbol");
		ASSERT(symbol[0] # 0); (* not initialized *)
		InitImmediate(op,type,0); op.symbol.name := symbol; op.symbol.fingerprint := fp; op.type := type; op.symbolOffset := symbolOffset
	END InitAddress;

	PROCEDURE Address*(type: Type; symbol: Sections.SectionName; fp: LONGINT; offset: LONGINT): Operand;
	VAR op: Operand;
	BEGIN InitAddress(op,type,symbol,fp, offset); RETURN op
	END Address;

	PROCEDURE InitMemory*(VAR op:Operand; type: Type; base: Operand; offset: LONGINT);
	BEGIN
		Assert((base.mode = ModeRegister) OR (base.mode = ModeImmediate) & ((offset=0) OR (base.symbol.name#"")),"base operand must be register");
		op := base; INC(op.offset,offset); MakeMemory(op,type);
	END InitMemory;

	PROCEDURE Memory*(type: Type; base: Operand; offset: LONGINT): Operand;
	VAR op: Operand;
	BEGIN InitMemory(op,type,base,offset); RETURN op
	END Memory;

	PROCEDURE IsConstantInteger*(CONST op: Operand; VAR value: HUGEINT): BOOLEAN;
	BEGIN
		IF (op.mode = ModeImmediate) & (op.type.form IN Integer) & (op.symbol.name = "") THEN
			value := op.intValue;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsConstantInteger;


	PROCEDURE InitImmediate*(VAR op: Operand; type: Type; value: HUGEINT);
	BEGIN
		Assert(type.form IN Integer,"operand type does not match value type");
		InitOperand(op); op.mode := ModeImmediate; op.type := type; op.intValue := value;
	END InitImmediate;

	PROCEDURE Immediate*(type: Type; value: LONGINT): Operand;
	VAR op: Operand;
	BEGIN InitImmediate(op,type,value); RETURN op
	END Immediate;

	PROCEDURE InitFloatImmediate*(VAR op: Operand; type: Type; value: LONGREAL);
	BEGIN
		Assert(type.form = Float,"operand type does not match value type");
		InitOperand(op); op.mode := ModeImmediate; op.type := type; op.floatValue := value;
	END InitFloatImmediate;

	PROCEDURE FloatImmediate*(type: Type; value: LONGREAL): Operand;
	VAR op: Operand;
	BEGIN InitFloatImmediate(op,type,value); RETURN op
	END FloatImmediate;

	PROCEDURE InitNumber*(VAR op: Operand; value: HUGEINT);
	BEGIN InitOperand(op); op.mode := ModeNumber; op.intValue := value;
	END InitNumber;

	PROCEDURE Number*(value: HUGEINT): Operand;
	VAR op: Operand;
	BEGIN InitNumber(op,value); RETURN op
	END Number;

	PROCEDURE InitRule*(VAR op: Operand; rules: Rules);
	BEGIN
		InitOperand(op); op.mode := ModeRule; op.rule := rules
	END InitRule;

	PROCEDURE InitString*(VAR op: Operand; string: SyntaxTree.SourceCode);
	BEGIN InitOperand(op); op.mode := ModeString; op.string := string;
	END InitString;

	PROCEDURE SetString*(VAR op: Operand; string: POINTER TO ARRAY OF CHAR);
	BEGIN op.string := string
	END SetString;

	PROCEDURE String*(string: SyntaxTree.SourceCode): Operand;
	VAR op: Operand;
	BEGIN InitString(op,string); RETURN op
	END String;

	PROCEDURE InitType*(VAR type: Type; form: SHORTINT; sizeInBits: INTEGER);
	BEGIN type.form := form; type.sizeInBits := sizeInBits; type.length := 1;
	END InitType;

	PROCEDURE ToVectorType*(VAR type: Type; length: LONGINT);
	BEGIN type.length := length
	END ToVectorType;

	PROCEDURE InitRegisterClass*(VAR registerClass: RegisterClass; class: SHORTINT; number: INTEGER);
	BEGIN registerClass.class := class; registerClass.number := number
	END InitRegisterClass;

	PROCEDURE NewType*(form: SHORTINT; sizeInBits: INTEGER): Type;
	VAR type: Type;
	BEGIN InitType(type, form, sizeInBits); RETURN type
	END NewType;

	PROCEDURE SetType*(VAR op: Operand; CONST type: Type);
	BEGIN op.type := type
	END SetType;

	(** assembler related part *)

	PROCEDURE FindMnemonic*(CONST name: ARRAY OF CHAR): SHORTINT;
	VAR i: SHORTINT;
	BEGIN
		FOR i := 0 TO NofOpcodes-1 DO
			IF name = instructionFormat[i].name THEN
				RETURN i
			END;
		END;
		RETURN None;
	END FindMnemonic;

	PROCEDURE SetRegister*(VAR op: Operand; reg: LONGINT);
	BEGIN
		op.register := reg; ASSERT(reg # 0);
	END SetRegister;

	PROCEDURE DecimalNumber(ch: CHAR; VAR nr: LONGINT): BOOLEAN;
	BEGIN
		IF (ch < "0") OR (ch > "9") THEN RETURN FALSE
		ELSE
			nr := nr *10;
			INC(nr,ORD(ch)-ORD("0"));
			RETURN TRUE
		END;
	END DecimalNumber;

	PROCEDURE Numbers(CONST name: ARRAY OF CHAR; VAR pos: LONGINT; VAR number: LONGINT): BOOLEAN;
	BEGIN
		number := 0;
		IF DecimalNumber(name[pos], number) THEN
			INC(pos);
			WHILE (pos<LEN(name)) & DecimalNumber(name[pos], number) DO INC(pos) END;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END Numbers;

	PROCEDURE Character(CONST name: ARRAY OF CHAR; VAR pos: LONGINT; char: CHAR): BOOLEAN;
	BEGIN
		IF name[pos] = char THEN INC(pos); RETURN TRUE ELSE RETURN FALSE END;
	END Character;

	PROCEDURE DenotesRegister*(CONST name: ARRAY OF CHAR; VAR registerClass: RegisterClass; VAR register: LONGINT): BOOLEAN;
	VAR pos, registerNumber: LONGINT;
	BEGIN
		pos := 0;
		IF Character(name,pos,'r') THEN
			IF Numbers(name,pos,register) THEN
				IF Character(name,pos,0X) THEN registerClass := GeneralPurposeRegister; RETURN TRUE
				ELSIF Character(name,pos,':') & Character(name,pos,'p') & Numbers(name,pos,registerNumber) & Character(name,pos,0X) THEN
					InitRegisterClass(registerClass, Parameter, SHORT(registerNumber));
					RETURN TRUE
				END
			END;
		ELSIF Character(name,pos,'h') THEN
			IF Numbers(name,pos,register) & Character(name,pos,0X) THEN
				register := HwRegister - register; RETURN TRUE
			END;
		ELSIF name = "sp" THEN register := SP; RETURN TRUE
		ELSIF name = "fp" THEN register := FP ; RETURN TRUE
		ELSIF name = "ap" THEN register := AP ; RETURN TRUE
		ELSIF name = "lr" THEN register := LR ; RETURN TRUE
		ELSE RETURN FALSE
		END;
	END DenotesRegister;

	PROCEDURE UnsignedIntegerType*(bits: LONGINT): Type;
	BEGIN
		IF bits = 8 THEN RETURN uint8
		ELSIF bits=16 THEN RETURN uint16
		ELSIF bits=32 THEN RETURN uint32
		ELSIF bits=64 THEN RETURN uint64
		ELSE RETURN NewType(UnsignedInteger, SHORTINT(bits))
		END;
	END UnsignedIntegerType;

	PROCEDURE SignedIntegerType*(bits: LONGINT): Type;
	BEGIN
		IF bits = 8 THEN RETURN int8
		ELSIF bits=16 THEN RETURN int16
		ELSIF bits=32 THEN RETURN int32
		ELSIF bits=64 THEN RETURN int64
		ELSE RETURN NewType(SignedInteger, SHORTINT(bits))
		END;
	END SignedIntegerType;

	PROCEDURE FloatType*(bits: LONGINT): Type;
	BEGIN
		IF bits=32 THEN RETURN float32
		ELSIF bits=64 THEN RETURN float64
		ELSE  RETURN NewType(Float, SHORTINT(bits))
		END;
	END FloatType;

	(** make an integer operand unsigned
	- note that no conversion is done, but only the type is changed **)
	PROCEDURE ToUnsigned*(operand: Operand): Operand;
	VAR
		type: Type;
		result: Operand;
	BEGIN
		ASSERT(operand.type.form IN Integer);
		result := operand;
		result.type.form := UnsignedInteger;
		RETURN result
	END ToUnsigned;

	PROCEDURE DenotesType*(CONST name: ARRAY OF CHAR; VAR type: Type): BOOLEAN;
	VAR
		sizeInBits: LONGINT; pos: LONGINT;
	BEGIN
		pos := 0;
		IF Character(name,pos,'s') THEN
			IF Numbers(name, pos, sizeInBits) & Character(name,pos,0X) & (sizeInBits >0) THEN
				type := SignedIntegerType(sizeInBits); RETURN TRUE
			END;
		ELSIF Character(name,pos,'u') THEN
			IF Numbers(name, pos, sizeInBits) & Character(name,pos,0X) & (sizeInBits >0) THEN
				type := UnsignedIntegerType(sizeInBits); RETURN TRUE
			END;
		ELSIF Character(name,pos, 'f') THEN
			IF Numbers(name, pos, sizeInBits) & Character(name,pos,0X) & (sizeInBits >0) THEN
				type := FloatType(sizeInBits); RETURN TRUE
			END;
		ELSE RETURN FALSE
		END;
	END DenotesType;

	PROCEDURE GetType*(system: Global.System; type: SyntaxTree.Type): Type;
	VAR t: Type;
	BEGIN
		type := type.resolved;
		IF type IS SyntaxTree.CharacterType THEN
			RETURN UnsignedIntegerType(system.SizeOf(type))
		ELSIF type IS SyntaxTree.IntegerType THEN
			IF type(SyntaxTree.IntegerType).signed THEN
				RETURN  SignedIntegerType(system.SizeOf(type))
			ELSE
				RETURN  UnsignedIntegerType(system.SizeOf(type))
			END;
		ELSIF type IS SyntaxTree.FloatType THEN
			RETURN  FloatType(system.SizeOf(type))
		ELSIF type IS SyntaxTree.RangeType THEN
			RETURN GetType(system,system.addressType)
		ELSIF type IS SyntaxTree.BasicType THEN
			IF type IS SyntaxTree.SizeType THEN
				RETURN  SignedIntegerType(system.SizeOf(type))
			ELSE
				RETURN  UnsignedIntegerType(system.SizeOf(type))
			END;
		ELSIF type IS SyntaxTree.PointerType THEN
			RETURN GetType(system,system.addressType)
		ELSIF type IS SyntaxTree.EnumerationType THEN
			RETURN int32
		ELSIF type IS SyntaxTree.ProcedureType THEN
			RETURN GetType(system,system.addressType)
		ELSIF type IS SyntaxTree.MathArrayType THEN
			WITH type: SyntaxTree.MathArrayType DO
				IF type.form = SyntaxTree.Static THEN
					t := GetType(system, type.arrayBase);
					ASSERT(t.length = 1);
					ToVectorType(t, type.staticLength);
					RETURN t
				END;
			END;
			(* TODO: ok to comment out the following assertion?:
			ASSERT(type(SyntaxTree.MathArrayType).form IN {SyntaxTree.Static, SyntaxTree.Tensor}); *)

			RETURN GetType(system,system.addressType);
		ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) THEN
			RETURN GetType(system,system.addressType);
		ELSIF type IS SyntaxTree.PortType THEN
			RETURN GetType(system, system.addressType);
		ELSIF type IS SyntaxTree.CellType THEN
			RETURN GetType(system, system.addressType);
		ELSE
 			HALT(100);
		END;
	END GetType;

BEGIN
	InitInstructions;
	InitType(int8, SignedInteger,8);
	InitType(int16, SignedInteger,16);
	InitType(int32, SignedInteger,32);
	InitType(int64, SignedInteger,64);
	InitType(uint8, UnsignedInteger,8);
	InitType(uint16, UnsignedInteger,16);
	InitType(uint32, UnsignedInteger,32);
	InitType(uint64, UnsignedInteger,64);
	InitType(float32, Float,32);
	InitType(float64, Float,64);
	InitType(undef, Undefined,0);
	InitOperand(empty);
END FoxIntermediateCode.
