MODULE FoxInterpreterBackend; (** AUTHOR "fof"; PURPOSE "abstract code interpreter"; *)

IMPORT Basic := FoxBasic, SYSTEM, Diagnostics, Intermediate := FoxIntermediateCode, Sections := FoxSections, SyntaxTree := FoxSyntaxTree, Options,
	IntermediateBackend := FoxIntermediateBackend, Backend := FoxBackend, Global := FoxGlobal, Formats := FoxFormats,
	Trace := KernelLog, Streams, SymbolFileFormat := FoxTextualSymbolFile;

CONST
	StackSize = 1024;
	AddressSize = SIZEOF (ADDRESS);

TYPE
	PC = RECORD
		section: Intermediate.Section;
		index: LONGINT;
	END;

	Int1 = SHORTINT;
	Int2 = INTEGER;
	Int4 = LONGINT;
	Int8 = HUGEINT;
	Float4 = REAL;
	Float8 = LONGREAL;

	Value = RECORD
		int1: Int1;
		int2: Int2;
		int4: Int4;
		int8: Int8;
		float4: Float4;
		float8: Float8;
	END;

	Address = LONGINT;
	Size = LONGINT;
	Memory = POINTER TO ARRAY OF SYSTEM.BYTE;

	Heap = OBJECT
	VAR
		memory: Memory;
		currentSize: Size;

		PROCEDURE &InitMemory;
		BEGIN NEW (memory, 1024); currentSize := 0;
		END InitMemory;

		PROCEDURE Allocate (size: Size): Address;
		VAR address, i: Size; original: Memory;
		BEGIN address := currentSize;
			ASSERT (size >= 0);
			size := ((size + (AddressSize - 1)) DIV AddressSize) * AddressSize;
			INC (currentSize, size);
			IF currentSize > LEN (memory) THEN
				original := memory;
				NEW (memory, LEN (original) * 2);
				FOR i := 0 TO LEN (original) - 1 DO memory[i] := original[i]; END;
			END;
			RETURN address;
		END Allocate;

		PROCEDURE IsValid (address: Address): BOOLEAN;
		BEGIN RETURN (address > 0) & (address < currentSize);
		END IsValid;

		PROCEDURE GetObject (address: Address): OBJECT;
		VAR object: OBJECT;
		BEGIN
			ASSERT (IsValid (address));
			ASSERT (address MOD AddressSize = 0);
			SYSTEM.GET (ADDRESSOF (memory[address]), object); RETURN object;
		END GetObject;

		PROCEDURE PutObject (address: Address; object: OBJECT);
		BEGIN
			ASSERT (IsValid (address));
			ASSERT (address MOD AddressSize = 0);
			SYSTEM.PUT (ADDRESSOF (memory[address]), object);
		END PutObject;

		PROCEDURE GetValue (address: Address; CONST type: Intermediate.Type; VAR value: Value);
		VAR adr: ADDRESS;
		BEGIN
			ASSERT (IsValid (address));
			adr := ADDRESSOF (memory[address]);
			IF type.form = Intermediate.Float THEN
				IF type.sizeInBits= 8 THEN SYSTEM.GET (adr, value.float8);
				ELSE SYSTEM.GET (adr, value.float4); END;
			ELSE
				IF type.sizeInBits= 1 THEN SYSTEM.GET (adr, value.int1);
				ELSIF type.sizeInBits= 2 THEN SYSTEM.GET (adr, value.int2);
				ELSIF type.sizeInBits= 8 THEN SYSTEM.GET (adr, value.int8);
				ELSE SYSTEM.GET (adr, value.int4); END;
			END;
		END GetValue;

		PROCEDURE PutValue (address: Address; CONST type: Intermediate.Type; CONST value: Value);
		VAR adr: ADDRESS;
		BEGIN
			ASSERT (IsValid (address));
			adr := ADDRESSOF (memory[address]);
			IF type.form = Intermediate.Float THEN
				IF type.sizeInBits= 8 THEN SYSTEM.PUT (adr, value.float8);
				ELSE SYSTEM.PUT (adr, value.float4); END;
			ELSE
				IF type.sizeInBits= 1 THEN SYSTEM.PUT (adr, value.int1);
				ELSIF type.sizeInBits= 2 THEN SYSTEM.PUT (adr, value.int2);
				ELSIF type.sizeInBits= 8 THEN SYSTEM.PUT (adr, value.int8);
				ELSE SYSTEM.PUT (adr, value.int4); END;
			END;
		END PutValue;

		PROCEDURE Copy (dest, source, size: Address);
		BEGIN
			ASSERT (IsValid (dest)); ASSERT (IsValid (source));
			WHILE size > 0 DO memory[dest] := memory[source]; INC (dest); INC (source); DEC (size); END;
		END Copy;

		PROCEDURE Fill (dest, size: Address; CONST value: Value; CONST type: Intermediate.Type);
		BEGIN
			ASSERT (IsValid (dest));
			WHILE size > 0 DO PutValue (dest, type, value); INC (dest, type.sizeInBits); DEC (size); END;
		END Fill;

	END Heap;

	Interpreter= OBJECT

	VAR
		backend: InterpreterBackend;
		pc: PC;
		sp, fp: Address;
		registers: ARRAY 16 OF Value;
		addressType: Intermediate.Type;
		trace: Streams.Writer;
		module: Sections.Module;

		PROCEDURE &InitInterpreter (backend: InterpreterBackend; addressSize: SHORTINT; m: Sections.Module);
		BEGIN SELF.backend := backend; pc.section := NIL; pc.index := 0; sp := backend.heap.Allocate (StackSize) + StackSize; fp := sp;
			addressType := Intermediate.NewType (Intermediate.UnsignedInteger, addressSize);
			NEW (trace, Trace.Send, 1);
			SELF.module := m
		END InitInterpreter;

		PROCEDURE Dump (section: Intermediate.Section; address: Address; CONST instruction: Intermediate.Instruction);
		VAR string: Basic.SectionName;
		BEGIN
			Basic.SegmentedNameToString(section.name, string);
			trace.String (string); trace.Char ('@'); trace.Int (address, 0); trace.String (": ");
			Intermediate.DumpInstruction (trace, instruction); trace.Ln; trace.Update;
			Trace.Memory (ADDRESSOF (backend.heap.memory[sp]), StackSize - sp);
		END Dump;

		PROCEDURE AllocateSection (s: Sections.Section);
		VAR i: LONGINT; size: Size; section: Intermediate.Section;
		BEGIN
			size := 0; section := s(Intermediate.Section);
			FOR i := 0 TO section.pc - 1 DO INC (size, GetSizeOf (section.instructions[i])); END;
			IF (section.pc = 0) & (section.type = Sections.CodeSection) THEN size := AddressSize; END;
			section.SetOffset (backend.heap.Allocate (size));
		END AllocateSection;

		PROCEDURE InitializeSection (s: Sections.Section);
		VAR i: LONGINT; address: Address; section: Intermediate.Section;
		BEGIN
			section := s(Intermediate.Section);
			address := section.offset;
			FOR i := 0 TO section.pc - 1 DO
				InitializeInstruction (section.instructions[i], address, section);
				INC (address, GetSizeOf (section.instructions[i]));
			END;
			IF (section.pc = 0) & (section.type = Sections.CodeSection) THEN backend.heap.PutObject (address, section); END;
		END InitializeSection;

		PROCEDURE InitializeInstruction (VAR instruction: Intermediate.Instruction; address: Address; section: Intermediate.Section);
		VAR value: Value;
		BEGIN
			CASE instruction.opcode OF
			| Intermediate.data: Evaluate (instruction.op1, value); backend.heap.PutValue (address, instruction.op1.type, value);
			| Intermediate.reserve:
			ELSE IF address MOD AddressSize = 0 THEN backend.heap.PutObject (address, section); END;
			END;
		END InitializeInstruction;

		PROCEDURE Resolve(VAR op: Intermediate.Operand);
		BEGIN
			IF op.resolved = NIL THEN
				op.resolved := module.allSections.FindByName(op.symbol.name);
			END;
		END Resolve;


		PROCEDURE Designate (VAR operand: Intermediate.Operand): Address;
		VAR address: Address;
		BEGIN
			address := 0;
			IF operand.symbol.name # "" THEN
				Resolve(operand);
				INC (address, operand.resolved.offset);
			END;
			IF operand.register = Intermediate.SP THEN INC (address, sp);
			ELSIF operand.register = Intermediate.FP THEN INC (address, fp);
			(*ELSIF operand.register = Intermediate.Result THEN INC (address, GetAddress (result, addressType));*)
			ELSIF operand.register # Intermediate.None THEN INC (address, GetAddress (registers[operand.register], addressType));
			END;
			RETURN address + operand.offset;
		END Designate;

		PROCEDURE Evaluate (VAR operand: Intermediate.Operand; VAR value: Value);
		VAR address: Address; offset: Value;
		BEGIN
			CASE operand.mode OF
			| Intermediate.ModeRegister:
				IF operand.register = Intermediate.SP THEN SetInteger (value, operand.type, sp);
				ELSIF operand.register = Intermediate.FP THEN SetInteger (value, operand.type, fp);
				(*ELSIF operand.register = Intermediate.Result THEN value := result;*)
				ELSE value := registers[operand.register]; END;
				IF operand.offset # 0 THEN SetInteger (offset, operand.type, operand.offset); Add (value, offset, operand.type); END;
			| Intermediate.ModeImmediate:
				IF operand.symbol.name # "" THEN SetInteger (value, operand.type, Designate (operand));
				ELSIF operand.type.form = Intermediate.Float THEN SetFloat (value, operand.type, operand.floatValue);
				ELSE SetInteger (value, operand.type, operand.intValue); END;
			| Intermediate.ModeMemory:
				address := Designate (operand);
				IF backend.heap.IsValid (address) THEN backend.heap.GetValue (address, operand.type, value); ELSE Error ("invalid load address "); END;
			END;
		END Evaluate;

		PROCEDURE EvaluateAddress (VAR operand: Intermediate.Operand): Address;
		VAR value: Value; address: Address;
		BEGIN
			ASSERT (Intermediate.TypeEquals (operand.type, addressType));
			Evaluate (operand, value); address := GetAddress (value, addressType);
			RETURN address;
		END EvaluateAddress;

		PROCEDURE Store (VAR operand: Intermediate.Operand; CONST value: Value);
		VAR address: Address;
		BEGIN
			CASE operand.mode OF
			| Intermediate.ModeRegister:
				ASSERT (operand.offset = 0);
				IF operand.register = Intermediate.SP THEN sp := GetAddress (value, operand.type);
				ELSIF operand.register = Intermediate.FP THEN fp := GetAddress (value, operand.type);
				(*ELSIF operand.register = Intermediate.Result THEN result := value;*)
				ELSE registers[operand.register] := value; END;
			| Intermediate.ModeMemory:
				address := Designate (operand);
				IF backend.heap.IsValid (address) THEN backend.heap.PutValue (address, operand.type, value); ELSE Error ("invalid store address "); END;
			END;
		END Store;

		PROCEDURE CallSection (section: Intermediate.Section);
		BEGIN Call (section.offset, pc);
		END CallSection;

		PROCEDURE Run;
		BEGIN
			TRACE(pc.section);
			WHILE pc.section # NIL DO
				Execute (pc.section.instructions[pc.index], pc);
				IF pc.index >= pc.section.pc THEN
					IF sp # StackSize THEN Error ("missing return"); END;
					 pc.section := NIL;
				END;
			END;
		END Run;

		PROCEDURE Stop;
		BEGIN pc.index := pc.section.pc;
		END Stop;

		PROCEDURE Error (CONST msg: ARRAY OF CHAR);
		BEGIN backend.Error ("", Diagnostics.Invalid, Diagnostics.Invalid, msg); Stop;
		END Error;

		PROCEDURE Execute (VAR instr: Intermediate.Instruction; VAR pc: PC);
		VAR value, temp: Value; operand: Intermediate.Operand;
		BEGIN
			Dump (pc.section, pc.index, instr);
			CASE instr.opcode OF
			Intermediate.nop:
			|Intermediate.mov: Evaluate (instr.op2, value); Store (instr.op1, value);
			|Intermediate.conv: Evaluate (instr.op2, value); Convert (value, instr.op2.type, instr.op1.type); Store (instr.op1, value);
			|Intermediate.call: Call (EvaluateAddress (instr.op1), pc); RETURN;
			|Intermediate.enter: Intermediate.InitRegister (operand, addressType, Intermediate.GeneralPurposeRegister,  Intermediate.FP); Push (operand); fp := sp; DEC (sp, SHORT (instr.op2.intValue));
			|Intermediate.leave: sp := fp; Intermediate.InitRegister (operand, addressType, Intermediate.GeneralPurposeRegister, Intermediate.FP); Pop (operand);
			|Intermediate.return: Return (pc, SHORT (instr.op2.intValue)); RETURN;
			|Intermediate.trap: Error ("trap"); RETURN;
			|Intermediate.br: Branch (EvaluateAddress (instr.op1), pc); RETURN;
			|Intermediate.breq: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); IF IsEqual (value, temp, instr.op2.type) THEN Branch (EvaluateAddress (instr.op1), pc); RETURN; END;
			|Intermediate.brne: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); IF ~IsEqual (value, temp, instr.op2.type) THEN Branch (EvaluateAddress (instr.op1), pc); RETURN; END;
			|Intermediate.brge: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); IF ~IsLessThan (value, temp, instr.op2.type) THEN Branch (EvaluateAddress (instr.op1), pc); RETURN; END;
			|Intermediate.brlt: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); IF IsLessThan (value, temp, instr.op2.type) THEN Branch (EvaluateAddress (instr.op1), pc); RETURN; END;
			|Intermediate.pop: Pop (instr.op1);
			|Intermediate.push: Push (instr.op1);
			|Intermediate.neg: Evaluate (instr.op2, value); Negate (value, instr.op1.type); Store (instr.op1, value);
			|Intermediate.not: Evaluate (instr.op2, value); Complement (value, instr.op1.type); Store (instr.op1, value);
			|Intermediate.abs: Evaluate (instr.op2, value); Absolute (value, instr.op1.type); Store (instr.op1, value);
			|Intermediate.mul: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Multiply (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.div: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Divide (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.mod: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Modulo (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.sub: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Subtract (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.add: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Add (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.and: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); And (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.or: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Or (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.xor: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); Xor (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.shl: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); ShiftLeft (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.shr: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); ShiftRight (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.rol: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); RotateLeft (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.ror: Evaluate (instr.op2, value); Evaluate (instr.op3, temp); RotateRight (value, temp, instr.op1.type); Store (instr.op1, value);
			|Intermediate.copy: backend.heap.Copy (EvaluateAddress (instr.op1), EvaluateAddress (instr.op2), EvaluateAddress (instr.op3));
			|Intermediate.fill: Evaluate (instr.op3, value); backend.heap.Fill (EvaluateAddress (instr.op1), EvaluateAddress (instr.op2), value, instr.op3.type);
			END;
			INC (pc.index);
		END Execute;

		PROCEDURE Push (VAR operand: Intermediate.Operand);
		VAR value: Value;
		BEGIN
			ASSERT (sp >= operand.type.sizeInBits);
			Evaluate (operand, value);
			DEC (sp, operand.type.sizeInBits);
			backend.heap.PutValue (sp, operand.type, value);
		END Push;

		PROCEDURE Pop (VAR operand: Intermediate.Operand);
		VAR value: Value;
		BEGIN
			ASSERT (sp <= StackSize - operand.type.sizeInBits);
			backend.heap.GetValue (sp, operand.type, value);
			INC (sp, operand.type.sizeInBits);
			Store (operand, value);
		END Pop;

		PROCEDURE Branch (address: Address; VAR pc: PC);
		VAR object: OBJECT;
		BEGIN
			IF backend.heap.IsValid (address) THEN
				object := backend.heap.GetObject (address - address MOD AddressSize);
				pc.section := object(Intermediate.Section);
				pc.index := address- pc.section.offset;
			ELSE
				Error ("invalid branch address");
			END;
		END Branch;

		PROCEDURE Call (address: Address; VAR pc: PC);
		VAR link: Intermediate.Operand;
		BEGIN
			IF pc.section = NIL THEN Intermediate.InitImmediate (link, addressType, 0);
			ELSE Intermediate.InitAddress (link, addressType, pc.section.name, 0, pc.index + 1); END;
			Push (link); Branch (address, pc);
		END Call;

		PROCEDURE Return (VAR pc: PC; size: Address);
		VAR value: Value; link: Address;
		BEGIN
			ASSERT (sp <= StackSize - addressType.sizeInBits- size);
			backend.heap.GetValue (sp, addressType, value);
			INC (sp, addressType.sizeInBits);
			link := GetAddress (value, addressType);
			IF link = 0 THEN pc.index := pc.section.pc;
			ELSE Branch (link, pc); END;
			INC (sp, size)
		END Return;

	END Interpreter;

	InterpreterBackend = OBJECT (IntermediateBackend.IntermediateBackend)
	VAR
		heap: Heap;
		addressSize, setSize: LONGINT;

		PROCEDURE &InitInterpreterBackend;
		BEGIN InitBackend;
		END InitInterpreterBackend;

		PROCEDURE GetSystem(): Global.System;
		VAR system: Global.System;
		BEGIN
			NEW (system, 8, 8, 32, 1, 1, 1, 1, addressSize * 2,0, cooperative);
			Global.SetDefaultDeclarations(system,8);
			Global.SetDefaultOperators(system);
			RETURN system;
		END GetSystem;

		PROCEDURE ProcessSyntaxTreeModule (x: SyntaxTree.Module): Formats.GeneratedModule;
		VAR module: Sections.Module; section: Sections.Section; interpreter: Interpreter;
 		BEGIN
			module := GenerateIntermediate (x, SupportedInstruction, SupportedImmediate);
			NEW (heap); NEW (interpreter, SELF, SHORT (SHORT (addressSize)),module);
			Traverse (module.allSections, interpreter.AllocateSection);
			Traverse (module.allSections, interpreter.InitializeSection);
			IF x.moduleScope.bodyProcedure # NIL THEN
				section := module.allSections.FindBySymbol (x.moduleScope.bodyProcedure);
				IF section # NIL THEN interpreter.CallSection (section(Intermediate.Section)) END;
			END;
			interpreter.Run;
			RETURN NIL
		END ProcessSyntaxTreeModule;
		
		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN DefineOptions^(options);
			options.Add("a","addressSize", Options.Integer);
			options.Add("s","setSize", Options.Integer);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		BEGIN GetOptions^(options);
			IF ~options.GetInteger("addressSize", addressSize) THEN addressSize := 2 END;
			IF ~options.GetInteger("setSize", setSize) THEN setSize := 2 END;
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat*(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get ();
		END DefaultSymbolFileFormat;

	END InterpreterBackend;

	PROCEDURE GetSizeOf (CONST instruction: Intermediate.Instruction): Size;
	BEGIN
		CASE instruction.opcode OF
		| Intermediate.data: RETURN instruction.op1.type.sizeInBits;
		| Intermediate.reserve: ASSERT (SHORT (instruction.op1.intValue) = instruction.op1.intValue); RETURN SHORT (instruction.op1.intValue);
		ELSE RETURN 1;
		END;
	END GetSizeOf;

	PROCEDURE SetInteger (VAR value: Value; CONST type: Intermediate.Type; integer: Int8);
	BEGIN
		ASSERT (type.form # Intermediate.Float);
		IF type.sizeInBits= 1 THEN value.int1 := SHORT (SHORT (SHORT (integer)));
		ELSIF type.sizeInBits= 2 THEN value.int2 := SHORT (SHORT (integer));
		ELSIF type.sizeInBits= 8 THEN value.int8 := integer;
		ELSE value.int4 := SHORT (integer); END;
	END SetInteger;

	PROCEDURE GetAddress (CONST value: Value; CONST type: Intermediate.Type): Address;
	BEGIN
		ASSERT (type.form = Intermediate.UnsignedInteger);
		IF type.sizeInBits= 2 THEN RETURN value.int2;
		ELSIF type.sizeInBits= 8 THEN ASSERT (SHORT (value.int8) = value.int8); RETURN SHORT (value.int8);
		ELSE RETURN value.int4; END;
	END GetAddress;

	PROCEDURE SetFloat (VAR value: Value; CONST type: Intermediate.Type; float: Float8);
	BEGIN
		ASSERT (type.form = Intermediate.Float);
		IF type.sizeInBits= 8 THEN value.float8 := float;
		ELSE value.float4 := SHORT (float); END;
	END SetFloat;

	PROCEDURE Convert (VAR value: Value; CONST from, to: Intermediate.Type);
	VAR val: LONGREAL;
	BEGIN
		IF from.form = Intermediate.Float THEN
			IF from.sizeInBits= 8 THEN val := value.float8; ELSE val := value.float4; END;
		ELSE
			IF from.sizeInBits= 1 THEN val := value.int1;
			ELSIF from.sizeInBits= 2 THEN val := value.int2;
			ELSIF from.sizeInBits= 8 THEN val := value.int8;
			ELSE val := value.int4; END;
		END;
		IF to.form = Intermediate.Float THEN
			IF to.sizeInBits= 8 THEN value.float8 := val; ELSE value.float4 := SHORT (val); END;
		ELSE
			IF to.sizeInBits= 1 THEN value.int1 := SHORT (SHORT (ENTIER (val)));
			ELSIF to.sizeInBits= 2 THEN value.int2 := SHORT (ENTIER (val));
			ELSIF to.sizeInBits= 8 THEN value.int8 := ENTIER (val);
			ELSE value.int4 := ENTIER (val); END;
		END;
	END Convert;

	PROCEDURE Negate (VAR value: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN value.float8 := -value.float8;
			ELSE value.float4 := -value.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN value.int1 := -value.int1;
			ELSIF type.sizeInBits= 2 THEN value.int2 := -value.int2;
			ELSIF type.sizeInBits= 8 THEN value.int8 := -value.int8;
			ELSE value.int4 := -value.int4; END;
		END;
	END Negate;

	PROCEDURE Complement (VAR value: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN value.int1 := SYSTEM.VAL (Int1, -SYSTEM.VAL (SET, value.int1));
			ELSIF type.sizeInBits= 2 THEN value.int2 := SYSTEM.VAL (Int2, -SYSTEM.VAL (SET, value.int2));
			ELSIF type.sizeInBits= 8 THEN value.int8 := SYSTEM.VAL (Int8, -SYSTEM.VAL (SET, value.int8));
			ELSE value.int4 := SYSTEM.VAL (Int4, -SYSTEM.VAL (SET, value.int4)); END;
		END;
	END Complement;

	PROCEDURE Absolute (VAR value: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN value.float8 := ABS (value.float8);
			ELSE value.float4 := ABS (value.float4); END;
		ELSE
			IF type.sizeInBits= 1 THEN value.int1 := ABS (value.int1);
			ELSIF type.sizeInBits= 2 THEN value.int2 := ABS (value.int2);
			(*TRAP: ELSIF type.sizeInBits= 8 THEN value.int8 := ABS (value.int8); *)
			ELSE value.int4 := ABS (value.int4); END;
		END;
	END Absolute;

	PROCEDURE Multiply (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN dest.float8 := dest.float8 * source.float8;
			ELSE dest.float4 := dest.float4 * source.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := dest.int1 * source.int1;
			ELSIF type.sizeInBits= 2 THEN dest.int2 := dest.int2 * source.int2;
			ELSIF type.sizeInBits= 8 THEN dest.int8 := dest.int8 * source.int8;
			ELSE dest.int4 := dest.int4 * source.int4; END;
		END;
	END Multiply;

	PROCEDURE Divide (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN dest.float8 := dest.float8 / source.float8;
			ELSE dest.float4 := dest.float4 / source.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := dest.int1 DIV source.int1;
			ELSIF type.sizeInBits= 2 THEN dest.int2 := dest.int2 DIV source.int2;
			ELSIF type.sizeInBits= 8 THEN dest.int8 := dest.int8 * source.int8;
			ELSE dest.int4 := dest.int4 DIV source.int4; END;
		END;
	END Divide;

	PROCEDURE Modulo (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := dest.int1 MOD source.int1;
			ELSIF type.sizeInBits= 2 THEN dest.int2 := dest.int2 MOD source.int2;
			(*TRAP: ELSIF type.sizeInBits= 8 THEN dest.int8 := dest.int8 MOD source.int8; *)
			ELSE dest.int4 := dest.int4 MOD source.int4; END;
		END;
	END Modulo;

	PROCEDURE Subtract (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN dest.float8 := dest.float8 - source.float8;
			ELSE dest.float4 := dest.float4 - source.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := dest.int1 - source.int1;
			ELSIF type.sizeInBits= 2 THEN dest.int2 := dest.int2 - source.int2;
			ELSIF type.sizeInBits= 8 THEN dest.int8 := dest.int8 - source.int8;
			ELSE dest.int4 := dest.int4 - source.int4; END;
		END;
	END Subtract;

	PROCEDURE Add  (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN dest.float8 := dest.float8 + source.float8;
			ELSE dest.float4 := dest.float4 + source.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := dest.int1 + source.int1;
			ELSIF type.sizeInBits= 2 THEN dest.int2 := dest.int2 + source.int2;
			ELSIF type.sizeInBits= 8 THEN dest.int8 := dest.int8 + source.int8;
			ELSE dest.int4 := dest.int4 + source.int4; END;
		END;
	END Add;

	PROCEDURE And (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := SYSTEM.VAL (Int1, SYSTEM.VAL (SET, dest.int1) * SYSTEM.VAL (SET, source.int1));
			ELSIF type.sizeInBits= 2 THEN dest.int2 := SYSTEM.VAL (Int2, SYSTEM.VAL (SET, dest.int2) * SYSTEM.VAL (SET, source.int2));
			ELSIF type.sizeInBits= 8 THEN dest.int8 := SYSTEM.VAL (Int8, SYSTEM.VAL (SET, dest.int8) * SYSTEM.VAL (SET, source.int8));
			ELSE dest.int4 := SYSTEM.VAL (Int4, SYSTEM.VAL (SET, dest.int4) * SYSTEM.VAL (SET, source.int4)); END;
		END;
	END And;

	PROCEDURE Or (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := SYSTEM.VAL (Int1, SYSTEM.VAL (SET, dest.int1) + SYSTEM.VAL (SET, source.int1));
			ELSIF type.sizeInBits= 2 THEN dest.int2 := SYSTEM.VAL (Int2, SYSTEM.VAL (SET, dest.int2) + SYSTEM.VAL (SET, source.int2));
			ELSIF type.sizeInBits= 8 THEN dest.int8 := SYSTEM.VAL (Int8, SYSTEM.VAL (SET, dest.int8) + SYSTEM.VAL (SET, source.int8));
			ELSE dest.int4 := SYSTEM.VAL (Int4, SYSTEM.VAL (SET, dest.int4) + SYSTEM.VAL (SET, source.int4)); END;
		END;
	END Or;

	PROCEDURE Xor (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := SYSTEM.VAL (Int1, SYSTEM.VAL (SET, dest.int1) / SYSTEM.VAL (SET, source.int1));
			ELSIF type.sizeInBits= 2 THEN dest.int2 := SYSTEM.VAL (Int2, SYSTEM.VAL (SET, dest.int2) / SYSTEM.VAL (SET, source.int2));
			ELSIF type.sizeInBits= 8 THEN dest.int8 := SYSTEM.VAL (Int8, SYSTEM.VAL (SET, dest.int8) / SYSTEM.VAL (SET, source.int8));
			ELSE dest.int4 := SYSTEM.VAL (Int4, SYSTEM.VAL (SET, dest.int4) / SYSTEM.VAL (SET, source.int4)); END;
		END;
	END Xor;

	PROCEDURE ShiftLeft  (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := LSH (dest.int1, source.int1);
			ELSIF type.sizeInBits= 2 THEN dest.int2 := LSH (dest.int2, source.int2);
			ELSIF type.sizeInBits= 8 THEN dest.int8 := LSH (dest.int8, source.int8);
			ELSE dest.int4 := LSH (dest.int4, source.int4); END;
		END;
	END ShiftLeft;

	PROCEDURE ShiftRight (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := LSH (dest.int1, -source.int1);
			ELSIF type.sizeInBits= 2 THEN dest.int2 := LSH (dest.int2, -source.int2);
			ELSIF type.sizeInBits= 8 THEN dest.int8 := LSH (dest.int8, -source.int8);
			ELSE dest.int4 := LSH (dest.int4, -source.int4); END;
		END;
	END ShiftRight;

	PROCEDURE RotateLeft  (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := ROT (dest.int1, source.int1);
			ELSIF type.sizeInBits= 2 THEN dest.int2 := ROT (dest.int2, source.int2);
			ELSIF type.sizeInBits= 8 THEN dest.int8 := ROT (dest.int8, source.int8);
			ELSE dest.int4 := ROT (dest.int4, source.int4); END;
		END;
	END RotateLeft;

	PROCEDURE RotateRight (VAR dest: Value; CONST source: Value; CONST type: Intermediate.Type);
	BEGIN
		IF type.form = Intermediate.Float THEN
			HALT (1234);
		ELSE
			IF type.sizeInBits= 1 THEN dest.int1 := ROT (dest.int1, -source.int1);
			ELSIF type.sizeInBits= 2 THEN dest.int2 := ROT (dest.int2, -source.int2);
			ELSIF type.sizeInBits= 8 THEN dest.int8 := ROT (dest.int8, -source.int8);
			ELSE dest.int4 := ROT (dest.int4, -source.int4); END;
		END;
	END RotateRight;

	PROCEDURE IsEqual  (CONST value1, value2: Value; CONST type: Intermediate.Type): BOOLEAN;
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN RETURN value1.float8 = value2.float8;
			ELSE RETURN value1.float4 = value2.float4; END;
		ELSE
			IF type.sizeInBits= 1 THEN RETURN value1.int1 = value2.int1;
			ELSIF type.sizeInBits= 2 THEN RETURN value1.int2 = value2.int2;
			ELSIF type.sizeInBits= 8 THEN RETURN value1.int8 = value2.int8;
			ELSE RETURN value1.int4 = value2.int4; END;
		END;
	END IsEqual;

	PROCEDURE IsLessThan (CONST value1, value2: Value; CONST type: Intermediate.Type): BOOLEAN;
	BEGIN
		IF type.form = Intermediate.Float THEN
			IF type.sizeInBits= 8 THEN RETURN value1.float8 < value2.float8;
			ELSE RETURN value1.float4 < value2.float4; END;
		ELSIF type.form = Intermediate.UnsignedInteger THEN
			IF type.sizeInBits= 1 THEN IF (value1.int1 >= 0) & (value2.int1 >= 0) OR (value1.int1 < 0) & (value2.int1 < 0) THEN RETURN value1.int1 < value2.int1; ELSE RETURN value1.int1 >= value2.int1; END;
			ELSIF type.sizeInBits= 2 THEN IF (value1.int2 >= 0) & (value2.int2 >= 0) OR (value1.int2 < 0) & (value2.int2 < 0) THEN RETURN value1.int2 < value2.int2; ELSE RETURN value1.int2 >= value2.int2; END;
			ELSIF type.sizeInBits= 8 THEN IF (value1.int8 >= 0) & (value2.int8 >= 0) OR (value1.int8 < 0) & (value2.int8 < 0) THEN RETURN value1.int8 < value2.int8; ELSE RETURN value1.int8 >= value2.int8; END;
			ELSE IF (value1.int4 >= 0) & (value2.int4 >= 0) OR (value1.int4 < 0) & (value2.int4 < 0) THEN RETURN value1.int4 < value2.int4; ELSE RETURN value1.int4 >= value2.int4; END; END;
		ELSE
			IF type.sizeInBits= 1 THEN RETURN value1.int1 < value2.int1;
			ELSIF type.sizeInBits= 2 THEN RETURN value1.int2 < value2.int2;
			ELSIF type.sizeInBits= 8 THEN RETURN value1.int8 < value2.int8;
			ELSE RETURN value1.int4 < value2.int4; END;
		END;
	END IsLessThan;

	PROCEDURE Traverse (list: Sections.SectionList; handle: PROCEDURE {DELEGATE} (section: Sections.Section));
	VAR
		section: Sections.Section;
		i: LONGINT;
	BEGIN
		FOR i := 0 TO list.Length() - 1 DO
			section := list.GetSection(i);
			handle(section)
		END
	END Traverse;

	PROCEDURE Get* (): Backend.Backend;
	VAR backend: InterpreterBackend;
	BEGIN NEW(backend); RETURN backend;
	END Get;

END FoxInterpreterBackend.

SystemTools.Free FoxInterpreterBackend ~
Compiler.Compile -b=Interpreter Test.Mod ~
TextCompiler.CompileSelection -b=Interpreter ~

	MODULE Test;
	VAR a: INTEGER;
	BEGIN 
		a := 0;
		ASSERT(a = 0);
	END Test.
