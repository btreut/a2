MODULE FoxCodeGenerators; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Diagnostics, Sections := FoxSections, Streams, BinaryCode := FoxBinaryCode, IntermediateCode := FoxIntermediateCode,
		IntermediateBackend := FoxIntermediateBackend, SyntaxTree := FoxSyntaxTree, Basic := FoxBasic, Global := FoxGlobal,
		StringPool, Strings, D := Debugging;

CONST
		None=IntermediateCode.None;
		OptimizeRegisterTransfer*=0;
TYPE
	(* ----------------------------------- register allocation ------------------------------------- *)

	AllocationArray=POINTER TO ARRAY OF RECORD
		first, last: LONGINT;
	END;

	RegisterAllocation*=OBJECT
	VAR
		table: AllocationArray;

		PROCEDURE &Init;
		VAR i: LONGINT;
		BEGIN
			IF table = NIL THEN NEW(table,64) END;
			FOR i := 0 TO LEN(table)-1 DO
				table[i].first := MAX(LONGINT);
				table[i].last := MIN(LONGINT);
			END;
		END Init;

		PROCEDURE Grow;
		VAR new: AllocationArray; i: LONGINT;
		BEGIN
			NEW(new,LEN(table)*2);
			FOR i := 0 TO LEN(table)-1 DO
				new[i] := table[i]
			END;
			FOR i := LEN(table) TO LEN(new)-1 DO
				new[i].first := MAX(LONGINT);
				new[i].last := MIN(LONGINT);
			END;
			table := new;
		END Grow;

		PROCEDURE Use(register, pc: LONGINT);
		BEGIN
			IF LEN(table) <= register THEN Grow END;
			IF table[register].first >pc THEN table[register].first := pc END;
			IF table[register].last <pc THEN table[register].last := pc END;
		END Use;

	END RegisterAllocation;

	RegisterEntry* = POINTER TO RECORD
		prev,next: RegisterEntry;
		register: LONGINT;
		registerClass: IntermediateCode.RegisterClass;
		type: IntermediateCode.Type;
	END;

	LiveRegisters*= OBJECT
	VAR first, last, cache: RegisterEntry;

		PROCEDURE &Init;
		BEGIN first := NIL; last := NIL; cache := NIL;
		END Init;

		PROCEDURE AddRegisterEntry(register: LONGINT; class: IntermediateCode.RegisterClass; type: IntermediateCode.Type);
		VAR new: RegisterEntry;
		BEGIN
			(* allocate *)
			IF cache # NIL THEN new := cache; cache := cache.next; ELSE NEW(new) END;
			new.next := NIL; new.prev := NIL;
			(* set *)
			new.register := register; new.registerClass := class; new.type := type;
			(* enter *)
			IF first = NIL THEN
				first := new; last:= new;
			ELSE
				new.next := first;
				first.prev := new;
				first := new
			END;
		END AddRegisterEntry;

		PROCEDURE RemoveRegisterEntry(register: LONGINT);
		VAR this: RegisterEntry;
		BEGIN
			(* search *)
			this := first;
			WHILE (this # NIL) & (this.register # register) DO
				this := this.next;
			END;
			(* remove *)
			IF this = NIL THEN RETURN END;
			IF this = first THEN first := first.next END;
			IF this = last THEN last := last.prev END;
			IF this.prev # NIL THEN this.prev.next := this.next END;
			IF this.next # NIL THEN this.next.prev := this.prev END;
			(* dispose *)
			this.next := cache; cache := this;
		END RemoveRegisterEntry;

	END LiveRegisters;

	GenericCodeGenerator*= OBJECT
	VAR
		diagnostics-: Diagnostics.Diagnostics; (* error stream *)
		module-: Sections.Module;
		dump*: Streams.Writer;
		in-: IntermediateCode.Section; out-: BinaryCode.Section;
		inPC-, outPC-: LONGINT;

		error* : BOOLEAN;
		allocation: RegisterAllocation;
		liveRegisters: LiveRegisters;
		inEmulation-: BOOLEAN;
		optimize: SET;

		(* generic *)
		PROCEDURE & InitGenerator*(diagnostics: Diagnostics.Diagnostics; optimize: BOOLEAN);
		BEGIN
			SELF.module := NIL;
			SELF.diagnostics := diagnostics;
			error := FALSE;
			NEW(allocation); NEW(liveRegisters);
			IF optimize THEN SELF.optimize := {0..31} ELSE SELF.optimize := {} END;
		END InitGenerator;

		PROCEDURE SetModule*(module: Sections.Module); (* needed for inline code for symbol reference *)
		BEGIN
			SELF.module := module;
		END SetModule;

		PROCEDURE Error*(position: LONGINT; CONST message: ARRAY OF CHAR);
		VAR string:Basic.MessageString;
		BEGIN
			IF diagnostics # NIL THEN
				Basic.SegmentedNameToString(in.name, string);
				diagnostics.Error(string, position, Diagnostics.Invalid, message)
			END;
			IF dump # NIL THEN (* to see error in trace output also *)
				dump.String("Error: "); dump.String(message); dump.Ln; dump.Update;
			END;
			error := TRUE;
		END Error;


		(* generic *)
		PROCEDURE Section*(in: IntermediateCode.Section; out: BinaryCode.Section);
		VAR pc: LONGINT; name: Basic.SectionName; instruction: IntermediateCode.Instruction;
			moduleName, procedureName: SyntaxTree.IdentifierString;

			PROCEDURE ResolveLocalFixups;
			VAR fixup, next: BinaryCode.Fixup; dest: LONGINT; msg,string: Basic.MessageString; number: ARRAY 32 OF CHAR;
			BEGIN
				fixup := out.fixupList.firstFixup;
				out.fixupList.InitFixupList;
				WHILE fixup # NIL DO
					next := fixup.nextFixup;
					IF (fixup.symbol.name = in.name) & (fixup.mode = BinaryCode.Relative) THEN (* local relative fixup *)
						IF dump # NIL THEN
							dump.String("local fixup "); dump.Int(fixup.offset,1); dump.String(" <-- ");
							fixup.Dump(dump); dump.Ln; (*dump.Update;*)

						END;
						IF fixup.symbolOffset # 0 THEN
							dest := fixup.symbolOffset;
							dest := in.instructions[dest].pc;
						ELSE
							dest := 0;
						END;
						fixup.SetSymbol(fixup.symbol.name, fixup.symbol.fingerprint, 0, dest+fixup.displacement);
						IF dump # NIL THEN
							dump.String("local fixup resolved: ");
							dump.Int(fixup.offset,1); dump.String(" <-- ");
							fixup.Dump(dump);
							dump.Ln; (*dump.Update;*)
						END;
						IF ~out.ApplyFixup(fixup) THEN
							COPY("fixup out of range: ", msg);
							string := fixup.symbol.name;
							Strings.Append(msg, string);
							Strings.Append(msg, ":");
							Strings.IntToStr(fixup.offset, number);
							Strings.Append(msg, number);
							Error(inPC,msg)
						END
					ELSE
						out.fixupList.AddFixup(fixup);
					END;
					fixup := next;
				END;
			END ResolveLocalFixups;

			PROCEDURE GetRegisterAllocation;
			CONST MaxParameterRegisters=8;
			VAR pc,i: LONGINT; parameterRegisters: ARRAY MaxParameterRegisters OF IntermediateCode.Operand;

				PROCEDURE RegisterUsage(CONST instruction: IntermediateCode.Instruction);
				VAR i: LONGINT;

					PROCEDURE Use(CONST operand: IntermediateCode.Operand);
					VAR i: LONGINT;
					BEGIN
						IF operand.register > 0 THEN
							allocation.Use(operand.register,inPC);
							IF operand.registerClass.class = IntermediateCode.Parameter THEN (* store recent parameter registers *)
								parameterRegisters[operand.registerClass.number] := operand;
							END;
						END;
						IF operand.rule # NIL THEN
							FOR i := 0 TO LEN(operand.rule)-1 DO
								Use(operand.rule[i]);
							END;
						END;
					END Use;
				BEGIN
					Use(instruction.op1);
					Use(instruction.op2);
					Use(instruction.op3);
					IF instruction.opcode = IntermediateCode.call THEN (* mark all currently used parameter registers used in this instruction *)
						FOR i := 0 TO MaxParameterRegisters-1 DO
							Use(parameterRegisters[i]);
							IntermediateCode.InitOperand(parameterRegisters[i]);
						END;
					END;
				END RegisterUsage;
			BEGIN
				allocation.Init;
				FOR i := 0 TO MaxParameterRegisters-1 DO
					IntermediateCode.InitOperand(parameterRegisters[i]);
				END;
				FOR pc := 0 TO in.pc-1 DO
					inPC := pc;
					RegisterUsage(in.instructions[pc]);
				END;
			END GetRegisterAllocation;

			PROCEDURE Optimize;
			TYPE
				Entry= POINTER TO RECORD src, dest: LONGINT; next: Entry END;
			VAR
				pc: LONGINT;
				first: Entry;

				PROCEDURE AddMap(src, dest: LONGINT);
				VAR entry: Entry;
				BEGIN
					NEW(entry); entry.src := src; entry.dest := dest;
					entry.next := first;
					first := entry;
				END AddMap;

				PROCEDURE CheckMapped(VAR instruction: IntermediateCode.Instruction);
				VAR op1, op2, op3: IntermediateCode.Operand;

					PROCEDURE Map(CONST op: IntermediateCode.Operand): IntermediateCode.Operand;
					VAR entry: Entry; res: IntermediateCode.Operand; i: LONGINT;
					BEGIN
						res := op;
						entry := first;
						WHILE entry # NIL DO
							IF op.register = entry.src THEN
								IntermediateCode.SetRegister(res, entry.dest);
							END;
							entry := entry.next;
						END;
						IF op.rule # NIL THEN
							FOR i := 0 TO LEN(op.rule)-1 DO
								op.rule[i] := Map(op.rule[i]);
							END;
						END;
						RETURN res
					END Map;

				BEGIN
					op1 := Map(instruction.op1);
					op2 := Map(instruction.op2);
					op3 := Map(instruction.op3);
					IntermediateCode.InitInstruction(instruction, instruction.textPosition, instruction.opcode, op1, op2, op3);
				END CheckMapped;

				PROCEDURE CheckMov(VAR instruction: IntermediateCode.Instruction);
				VAR i: LONGINT; srcReg, destReg: LONGINT;
				BEGIN
					IF (instruction.opcode = IntermediateCode.mov) & (instruction.op1.mode = IntermediateCode.ModeRegister)
						& (instruction.op2.mode = IntermediateCode.ModeRegister) & IntermediateCode.TypeEquals(instruction.op1.type, instruction.op2.type) THEN
						destReg := instruction.op1.register;
						srcReg := instruction.op2.register;
						IF (destReg >= 0) & (allocation.table[destReg].first = pc) & (srcReg >= 0) & (allocation.table[srcReg].last = pc)  THEN
							AddMap(destReg, srcReg);
							allocation.table[srcReg].last := allocation.table[destReg].last;
							IntermediateCode.InitInstruction0(instruction, instruction.textPosition, IntermediateCode.nop);
						END;
					END;
				END CheckMov;

			BEGIN


				first := NIL;
				FOR pc := 0 TO in.pc-1 DO
					IF OptimizeRegisterTransfer IN optimize THEN
						CheckMapped(in.instructions[pc]);
						CheckMov(in.instructions[pc]);
					END;
				END;
			END Optimize;

			PROCEDURE DumpInstruction(CONST instruction: IntermediateCode.Instruction);
				PROCEDURE Use(CONST operand: IntermediateCode.Operand);
				BEGIN
					IF FirstUse(operand.register)=inPC THEN
						dump.String(" ; +"); IntermediateCode.DumpRegister(dump,operand.register,operand.registerClass);
					END;
					IF LastUse(operand.register)=inPC THEN
						dump.String(" ; -"); IntermediateCode.DumpRegister(dump,operand.register, operand.registerClass);
					END;
				END Use;
			BEGIN
				dump.Int(pc, 1); dump.String(": "); IntermediateCode.DumpInstruction(dump, instruction);
				Use(instruction.op1);
				Use(instruction.op2);
				Use(instruction.op3);
			END DumpInstruction;


			PROCEDURE Emulate(VAR x: IntermediateCode.Instruction; CONST moduleName,procedureName: SyntaxTree.IdentifierString);
			VAR
				parSize: LONGINT; sectionName: Basic.SegmentedName; source: Sections.Section; op: IntermediateCode.Operand;
				instruction: IntermediateCode.Instruction;
				symbol: SyntaxTree.Symbol; fp: LONGINT;
				hasDestination: BOOLEAN;

				PROCEDURE Emit(instruction: IntermediateCode.Instruction; CONST str: ARRAY OF CHAR);
				BEGIN
					IF dump # NIL THEN
						dump.Int(pc, 1); dump.String(" (emulation ");dump.String(str); dump.String(") : "); IntermediateCode.DumpInstruction(dump, instruction); dump.Ln;
					END;
					Generate(instruction);
				END Emit;

				PROCEDURE SaveRegisters;
				VAR op: IntermediateCode.Operand; entry: RegisterEntry;
				BEGIN
					entry := liveRegisters.first;
					WHILE  entry # NIL DO
						IF (FirstUse(entry.register) # pc) & (entry.register # x.op1.register) THEN
							IntermediateCode.InitRegister(op, entry.type,entry.registerClass, entry.register);
							Emit(IntermediateBackend.Push(x.textPosition,op),"save");
						END;
						entry := entry.next;
					END;
				END SaveRegisters;

				PROCEDURE RestoreRegisters;
				VAR op: IntermediateCode.Operand; entry: RegisterEntry; instruction: IntermediateCode.Instruction;
				BEGIN
					entry := liveRegisters.last;
					WHILE  entry # NIL DO
						IF (FirstUse(entry.register) # pc)  & (entry.register # x.op1.register)  THEN
							IntermediateCode.InitRegister(op, entry.type,entry.registerClass, entry.register);
							Emit(IntermediateBackend.Pop(x.textPosition,op),"restore");
						END;
						entry := entry.prev;
					END;
				END RestoreRegisters;

			BEGIN
				inEmulation := TRUE;
				hasDestination := (IntermediateCode.Op1IsDestination IN IntermediateCode.instructionFormat[x.opcode].flags);
				ASSERT(x.op1.mode # IntermediateCode.Undefined);

				(* 	add import to import list -- raw insert, no check.
					checks will be performed by loader or linker -- we assume that a low-level runtime system programmer knows what he is doing
				*)
				SaveRegisters;
				IF ~module.imports.ContainsName(moduleName) THEN module.imports.AddName(moduleName) END;
				parSize := 0;
				IF (x.op1.mode # IntermediateCode.Undefined) & ~hasDestination THEN
					Emit(IntermediateBackend.Push(x.textPosition,x.op1),"par");
					INC(parSize, x.op1.type.sizeInBits);
					Basic.Align(parSize, module.system.addressSize);
				END;
				IF x.op2.mode # IntermediateCode.Undefined THEN
					Emit(IntermediateBackend.Push(x.textPosition,x.op2),"par");
					INC(parSize, x.op2.type.sizeInBits);
					Basic.Align(parSize, module.system.addressSize);
				END;
				IF x.op3.mode # IntermediateCode.Undefined THEN
					Emit(IntermediateBackend.Push(x.textPosition,x.op3),"par");
					INC(parSize, x.op3.type.sizeInBits);
					Basic.Align(parSize, module.system.addressSize);
				END;
				Basic.InitSegmentedName(sectionName);
				Basic.SuffixSegmentedName(sectionName, StringPool.GetIndex1(moduleName));
				Basic.SuffixSegmentedName(sectionName, StringPool.GetIndex1(procedureName));
				IF module.module # NIL THEN
					symbol := IntermediateBackend.GetSymbol(module.module.moduleScope, moduleName, procedureName);
				ELSE
					symbol := NIL
				END;
				IF symbol # NIL THEN fp := symbol.fingerprint.shallow ELSE fp := 0 END;
				IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system,module.system.addressType), sectionName , fp, 0);
				Emit(IntermediateBackend.Call(x.textPosition,op,IntermediateBackend.ToMemoryUnits(module.system,parSize)),"");
				IF hasDestination THEN
					Emit(IntermediateBackend.Result(x.textPosition,x.op1),"");
				END;
				RestoreRegisters;
				inEmulation := FALSE;
			END Emulate;

			PROCEDURE SetLiveness(CONST x: IntermediateCode.Instruction);
			(* currently only used to save registers in instruction emulation *)
				PROCEDURE CheckOperand(CONST operand: IntermediateCode.Operand);
				VAR i: LONGINT;
				BEGIN
					IF (operand.register >= 0) THEN
						IF FirstUse(operand.register) = pc THEN
							liveRegisters.AddRegisterEntry(operand.register, operand.registerClass, operand.type);
						END;
						IF LastUse(operand.register) = pc THEN
							liveRegisters.RemoveRegisterEntry(operand.register);
						END;
					END;
					IF operand.rule # NIL THEN
						FOR i := 0 TO LEN(operand.rule)-1 DO
							CheckOperand(operand.rule[i])
						END;
					END;
				END CheckOperand;

			BEGIN
				CheckOperand(x.op1);
				IF (x.op2.register # x.op1.register) OR (x.op2.rule # NIL) THEN
					CheckOperand(x.op2);
				END;
				IF (x.op3.register # x.op1.register) & (x.op3.register # x.op2.register) OR (x.op3.rule # NIL) THEN
					CheckOperand(x.op3);
				END;
			END SetLiveness;


		BEGIN
			inEmulation := FALSE;
			Basic.SegmentedNameToString(in.name, name);
			SELF.in := in; SELF.out := out;
			dump := out.comments;

			GetRegisterAllocation;
			IF optimize # {} THEN Optimize END;
			Prepare;

			FOR pc := 0 TO in.pc-1 DO
				inPC := pc; outPC := out.pc;
				in.SetPC(pc, outPC);
				IF pc = in.finally THEN out.SetFinally(out.pc) END;
				IF pc = in.validPAFEnter THEN out.EnterValidPAF END;
				IF pc = in.validPAFExit THEN out.ExitValidPAF END;
				instruction := in.instructions[pc];
				SetLiveness(instruction);
				IF dump # NIL THEN DumpInstruction(instruction); dump.Ln END;
				CASE instruction.opcode OF
					IntermediateCode.data: EmitData(instruction);
					|IntermediateCode.reserve: EmitReserve(instruction);
					|IntermediateCode.label: EmitLabel(instruction);
				ELSE
					IF Supported(instruction, moduleName, procedureName) THEN
						Generate(instruction);
						PostGenerate(instruction);
					ELSE
						Emulate(instruction, moduleName, procedureName);
						PostGenerate(instruction);
					END
				END;
			END;

			(*CheckRegistersFree();*)
			ResolveLocalFixups;
		END Section;

		PROCEDURE FirstUse*(virtualRegister: LONGINT): LONGINT;
		BEGIN
			IF (virtualRegister > 0)  THEN RETURN allocation.table[virtualRegister].first ELSE RETURN None END;
		END FirstUse;

		PROCEDURE LastUse*(virtualRegister: LONGINT): LONGINT;
		BEGIN
			IF (virtualRegister > 0)  THEN RETURN allocation.table[virtualRegister].last ELSE RETURN None END;
		END LastUse;

		(*-------------------  procedures that must be overwritten by implementers  ----------------------*)

		(* supported instruction - provision for instruction emulation *)
		PROCEDURE Supported*(CONST instr: IntermediateCode.Instruction; VAR moduleName,procedureName: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			moduleName := ""; procedureName := "";
			RETURN TRUE
		END Supported;

		(* generate procedure - is called for any instruction that cannot be output directly by the generic code generator *)
		PROCEDURE Generate*(VAR instr: IntermediateCode.Instruction);
		BEGIN (*HALT(100); *) (* abstract *)
		END Generate;

		PROCEDURE PostGenerate*(CONST instr: IntermediateCode.Instruction);
		BEGIN
		END PostGenerate;

		(* ---------------------- generically available code emission ------------------------- *)


		PROCEDURE GetDataSection*(): IntermediateCode.Section;
		VAR name: Basic.SegmentedName; section: IntermediateCode.Section;
		BEGIN
			Global.GetModuleSegmentedName(module.module, name);
			Basic.SuffixSegmentedName(name,Basic.MakeString("@Immediates"));
			section := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,NIL,TRUE);
			RETURN section
		END GetDataSection;

		PROCEDURE EmitData(CONST instruction: IntermediateCode.Instruction);
			VAR type: IntermediateCode.Type; fixup: BinaryCode.Fixup; pc: LONGINT;fixupFormat: BinaryCode.FixupPatterns;
		BEGIN
			type := instruction.op1.type;
			pc := out.pc;
			IF type.form IN IntermediateCode.Integer THEN
				out.PutBytes(instruction.op1.intValue,SHORT(type.sizeInBits DIV 8));
			ELSE
				IF type.sizeInBits = IntermediateCode.Bits32 THEN
					out.PutReal(SHORT(instruction.op1.floatValue));
				ELSIF type.sizeInBits = IntermediateCode.Bits64 THEN
					out.PutLongreal(instruction.op1.floatValue);
				ELSE Assert(FALSE,"no floats other than 32 or 64 bit")
				END;
			END;
			IF instruction.op1.symbol.name # "" THEN
				NEW(fixupFormat,1);
				fixupFormat[0].offset := 0;
				fixupFormat[0].bits := type.sizeInBits;
				fixup := BinaryCode.NewFixup(BinaryCode.Absolute,pc,instruction.op1.symbol,instruction.op1.symbolOffset,instruction.op1.offset,0,fixupFormat);
				out.fixupList.AddFixup(fixup);
			END;
		END EmitData;

		PROCEDURE EmitReserve(CONST instruction: IntermediateCode.Instruction);
		VAR sizeInUnits,i: LONGINT;
		BEGIN
			sizeInUnits := SHORT(instruction.op1.intValue);
			ASSERT(sizeInUnits >= 0); (* size is initialized to MIN(LONGINT), this checks if size field has been visited *)
			FOR i := 0 TO sizeInUnits-1 DO
				out.PutBits(0,out.os.unit);
			END;
		END EmitReserve;

		PROCEDURE EmitLabel(CONST instruction: IntermediateCode.Instruction);
		VAR position: LONGINT;
		BEGIN
			position := SHORT(instruction.op1.intValue);
			out.AddLabel(position);
		END EmitLabel;

		PROCEDURE Prepare*;
		BEGIN

		END Prepare;

	END GenericCodeGenerator;

	(* ----------------------- ticket based register allocation ------------------------------------- *)


		(* register mapping scheme
			virtual register number	--> register mapping   = 		part(0)		-->	ticket	<-->	physical register
																											spill offset

																	part(n)		-->	ticket	<-->	physical register
																											spill offset
		*)


	Ticket*=POINTER TO RECORD
		next-: Ticket;
		type-: IntermediateCode.Type;
		class-: IntermediateCode.RegisterClass;
		lastuse-: LONGINT;
		spilled*, spillable*: BOOLEAN;
		register*, offset*: LONGINT;
		parts-: LONGINT;
	END;

	Tickets*=OBJECT
	VAR
		live-: Ticket;
		free: Ticket	;

		PROCEDURE &Init*;
		BEGIN
			live := NIL; free := NIL
		END Init;

		(* enter a new ticket into the list of live tickets, sorted by lastuse *)
		PROCEDURE Enter*(CONST class: IntermediateCode.RegisterClass; CONST type: IntermediateCode.Type; register: LONGINT; spillable, spilled: BOOLEAN; offset: LONGINT; lastuse: LONGINT): Ticket;
		VAR ticket,link: Ticket;
		BEGIN
			ASSERT(~spilled & (register # None) OR spilled & (offset # None));
			ASSERT(spillable OR ~spilled);
			IF free # NIL THEN ticket := free; free := free.next; ticket.next := NIL;
			ELSE NEW(ticket)
			END;
			ticket.type := type;	ticket.class := class; ticket.register := register; ticket.spillable := spillable; ticket.spilled := spilled;	ticket.offset := offset; ticket.lastuse := lastuse; ticket.parts := 0;
			IF (live = NIL) OR (live.lastuse > ticket.lastuse) THEN
				ticket.next := live; live := ticket
			ELSE
				link := live;
				WHILE (link.next # NIL) & (link.next.lastuse < ticket.lastuse) DO
					ASSERT((link.register # ticket.register) OR ticket.spilled);
					link := link.next;
				END;
				IF (link.register=ticket.register) & (~ticket.spilled & ~link.spilled) THEN Dump(D.Log); D.Update; END;
				ASSERT((link.register # ticket.register) OR ticket.spilled OR link.spilled);
				ticket.next := link.next; link.next := ticket;
			END;
			RETURN ticket
		END Enter;

		(* remove ticket from live list *)
		PROCEDURE Remove*(ticket: Ticket);
		VAR link: Ticket;
		BEGIN
			IF live=ticket THEN
				live := live.next;
			ELSE
				link := live;
				WHILE (link.next # NIL) & (link.next # ticket) DO
					link := link.next
				END;
				ASSERT(link.next=ticket);
				link.next := ticket.next;
			END;
			ticket.next := free; free := ticket
		END Remove;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR ticket: Ticket;
		BEGIN
			w.String("---- tickets.live ----- "); w.Ln;
			ticket := live;
			WHILE ticket # NIL DO
				DumpTicket(w,ticket);
				w.Ln;
				ticket := ticket.next;
			END;
		END Dump;

	END Tickets;

	VirtualRegisterMappings=POINTER TO ARRAY OF Ticket;

	VirtualRegisters*=OBJECT
	VAR
		tickets: VirtualRegisterMappings;
		parts: LONGINT;

		firstMapped-, lastMapped-: LONGINT;

		PROCEDURE &Init*(parts: LONGINT);
		VAR i: LONGINT;
		BEGIN
			SELF.parts := parts;
			IF tickets = NIL THEN NEW(tickets,64*parts) END;
			FOR i := 0 TO LEN(tickets)-1 DO
				tickets[i]:=NIL;
			END;
			firstMapped := MAX(LONGINT); lastMapped := -1;
		END Init;

		PROCEDURE Grow;
		VAR new: VirtualRegisterMappings; i: LONGINT;
		BEGIN
			NEW(new,LEN(tickets)*2);
			FOR i := 0 TO LEN(tickets)-1 DO
				new[i] := tickets[i];
			END;
			FOR i := LEN(tickets) TO LEN(new)-1 DO
				new[i]:=NIL;
			END;
			tickets := new;
		END Grow;

		PROCEDURE Mapped*(register: LONGINT; part: LONGINT): Ticket;
		BEGIN
			ASSERT((part >=0) & (part < parts));
			IF (register > 0 ) & (register*parts < LEN(tickets)) THEN RETURN tickets[register * parts + part] ELSE RETURN NIL END;
		END Mapped;

		PROCEDURE SetMapped*(register: LONGINT; part: LONGINT; ticket: Ticket);
		BEGIN
			IF lastMapped < register THEN lastMapped := register END;
			IF firstMapped > register THEN firstMapped := register END;

			ASSERT((part >=0) & (part < parts));
			WHILE (register*parts >= LEN(tickets)) DO Grow END;
			tickets[register*parts+part] := ticket;
			INC(ticket.parts);
		END SetMapped;

		PROCEDURE Unmap*(register: LONGINT);
		VAR i: LONGINT;
		BEGIN
			IF (register > 0) & (register*parts < LEN(tickets)) THEN
				FOR i := 0 TO parts-1 DO
					tickets[register*parts+i] := NIL;
				END;
				IF firstMapped = register THEN
					WHILE (firstMapped * parts < LEN(tickets)) & (firstMapped <= lastMapped) & (Mapped(firstMapped,0)=NIL) DO
						INC(firstMapped);
					END;
				END;
				IF lastMapped = register THEN
					WHILE (lastMapped >= 0) & (lastMapped >= firstMapped) & (Mapped(lastMapped,0) = NIL) DO
						DEC(lastMapped)
					END;
				END;
				IF lastMapped < firstMapped THEN firstMapped := MAX(LONGINT); lastMapped := -1 END;
			END;
		END Unmap;

		PROCEDURE Parts*(): LONGINT;
		BEGIN RETURN parts
		END Parts;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR register,part: LONGINT; ticket: Ticket;
		BEGIN
			w.String("---- virtual register mapping ----- "); w.Ln;
			register := 0;
			WHILE register*parts < LEN(tickets) DO
				FOR part := 0 TO parts-1 DO
					ticket := tickets[register*parts+part];
					IF ticket # NIL THEN
						w.String("register.part "); w.Int(register,1); w.String("."); w.Int(part,1); w.String(": ");
						DumpTicket(w,ticket); w.Ln;
					END;
				END;
				INC(register);
			END;
		END Dump;

	END VirtualRegisters;

	PhysicalRegisters*=OBJECT
	VAR
		PROCEDURE &InitPhysicalRegisters;
		END InitPhysicalRegisters;


		PROCEDURE Allocate*(index: LONGINT; virtualRegister: Ticket);
		END Allocate;

		PROCEDURE Mapped*(physical: LONGINT): Ticket;
		END Mapped;

		PROCEDURE Free*(index: LONGINT);
		END Free;

		PROCEDURE NextFree*(CONST type: IntermediateCode.Type): LONGINT;
		END NextFree;

		(* give a hint for the next register to return by NextFree *)
		PROCEDURE AllocationHint*(index: LONGINT);
		END AllocationHint;

		PROCEDURE SetReserved*(index: LONGINT; res: BOOLEAN);
		BEGIN
		END SetReserved;

		PROCEDURE Reserved*(index: LONGINT): BOOLEAN;
		BEGIN
		END Reserved;

		PROCEDURE Dump*(w: Streams.Writer);
		BEGIN
		END Dump;

		PROCEDURE NumberRegisters*(): LONGINT;
		BEGIN
		END NumberRegisters;


	END PhysicalRegisters;

	CONST 	MaxSpilledRegisters=64;

	TYPE
	SpillStack*=OBJECT
	VAR
		spillStack: ARRAY MaxSpilledRegisters OF Ticket; (* registers of spill stack position to virtual register, none if unused *)
		spillStackSize,maxSpillStackSize: LONGINT;

		PROCEDURE &Init*;
		VAR i: LONGINT;
		BEGIN
			spillStackSize := 0; maxSpillStackSize := 0;
			FOR i := 0 TO LEN(spillStack)-1 DO
				spillStack[i] := NIL;
			END;
		END Init;

		(* return next free spill offset in stack *)
		PROCEDURE NextFree*(): LONGINT;
		VAR i: LONGINT; index: Ticket;
		BEGIN
			i := 0;
			index := spillStack[i];
			WHILE (index # NIL) DO
				INC(i); index := spillStack[i];
			END;
			RETURN i
		END NextFree;

		PROCEDURE Allocate*(offset: LONGINT; ticket: Ticket);
		BEGIN
			spillStack[ticket.offset] := ticket;
			IF spillStackSize <= ticket.offset THEN spillStackSize := ticket.offset+1 END;
			IF maxSpillStackSize < spillStackSize THEN maxSpillStackSize := spillStackSize END;
		END Allocate;

		PROCEDURE Free*(offset: LONGINT);
		BEGIN
			spillStack[offset] := NIL;
			IF offset+1 = spillStackSize THEN (* rewind spillstack *)
				WHILE (offset >= 0) & (spillStack[offset]= NIL) DO
					DEC(offset);
				END;
				spillStackSize := offset+1;
			END;
		END Free;

		PROCEDURE Size*(): LONGINT;
		BEGIN RETURN spillStackSize
		END Size;

		PROCEDURE MaxSize*(): LONGINT;
		BEGIN RETURN maxSpillStackSize
		END MaxSize;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR i: LONGINT;
		BEGIN
			w.String("---- spillstack -----");w.Ln;
			w.String("spillStackSize = "); w.Int(spillStackSize,1); w.Ln;
			w.String("maxSpillStackSze = "); w.Int(maxSpillStackSize,1); w.Ln;
			FOR i := 0 TO spillStackSize-1 DO
				IF spillStack[i]# NIL THEN DumpTicket(w,spillStack[i]);END
			END;
		END Dump;

	END SpillStack;

	GeneratorWithTickets*= OBJECT (GenericCodeGenerator)
	VAR
		physicalRegisters-: PhysicalRegisters; (* physical registers <-> tickets *)
		virtualRegisters-: VirtualRegisters; (* virtual registers --> tickets *)
		tickets-: Tickets;  (* tickets <-> physical registers *)
		spillStack-: SpillStack; (* spill stack offset <-> ticket *)

		(* generic *)
		PROCEDURE & InitTicketGenerator*(diagnostics: Diagnostics.Diagnostics; optimize: BOOLEAN; numberRegisterParts: LONGINT; physicalRegisters: PhysicalRegisters);
		BEGIN
			InitGenerator(diagnostics, optimize);
			NEW(tickets);
			NEW(virtualRegisters,numberRegisterParts);
			NEW(spillStack);
			SELF.physicalRegisters := physicalRegisters;
		END InitTicketGenerator;

		PROCEDURE Section*(in: IntermediateCode.Section; out: BinaryCode.Section);
		VAR ticket: Ticket;
		BEGIN
			virtualRegisters.Init(virtualRegisters.parts);
			Section^(in,out);
		END Section;

		(*-------------------  procedures that must be overwritten by implementers  ----------------------*)

		(* input: type (such as that of an intermediate operand), output: type part *)
		PROCEDURE GetPartType*(CONST type: IntermediateCode.Type; part: LONGINT; VAR typePart: IntermediateCode.Type);
		BEGIN HALT(100); (* abstract *)
		END GetPartType;

		PROCEDURE ToSpillStack*(ticket: Ticket);
		BEGIN HALT(100) (* abstract *)
		END ToSpillStack;

		PROCEDURE AllocateSpillStack*(size: LONGINT);
		BEGIN HALT(100) (* abstract *)
		END AllocateSpillStack;

		PROCEDURE ToRegister*(ticket: Ticket);
		BEGIN HALT(100) (* abstract *)
		END ToRegister;

		PROCEDURE ExchangeTickets*(ticket1,ticket2: Ticket);
		BEGIN HALT(100) (* abstract *)
		END ExchangeTickets;

		PROCEDURE ParameterRegister*(CONST type: IntermediateCode.Type; number: LONGINT): LONGINT;
		BEGIN HALT(100) (* abstract *)
		END ParameterRegister;



		(*---------------------------- ticket handling and register allocation ----------------------------*)

		(* Spill register of a ticket, if any *)
		PROCEDURE Spill*(ticket: Ticket);
		VAR register,offset,size: LONGINT;
		BEGIN
			IF (ticket = NIL) OR ~ticket.spillable OR ticket.spilled THEN RETURN END;
			register := ticket.register;
			offset := spillStack.NextFree();
			ticket.offset := offset;
			size := spillStack.Size();
			IF dump# NIL THEN dump.String("spillstack allocate (1) "); dump.Int(offset,1); dump.Ln; END;
			spillStack.Allocate(offset,ticket);
			size := spillStack.Size()-size;
			ASSERT(size>=0);
			IF size>0 THEN AllocateSpillStack(size) END;

			ToSpillStack(ticket);
			ticket.offset := offset;
			physicalRegisters.Free(register);
			ticket.spilled := TRUE;
		END Spill;

		(* Make sure a ticket reprents a physical register *)
		PROCEDURE UnSpill*(ticket: Ticket);
		VAR mapped:Ticket; register: LONGINT;

			PROCEDURE ExchangeSpill(ticket1, ticket2: Ticket): BOOLEAN;
			BEGIN
				IF ticket1.spilled THEN ASSERT(~ticket2.spilled); RETURN ExchangeSpill(ticket2,ticket1) END;
				IF (ticket1.type.sizeInBits # ticket2.type.sizeInBits)
					OR ~(ticket1.type.form IN IntermediateCode.Integer) OR ~(ticket2.type.form IN IntermediateCode.Integer)
					OR ticket1.spilled THEN
					RETURN FALSE
				END;

				ASSERT(~ticket1.spilled); ASSERT(ticket1.register # None);
				ASSERT(ticket2.spilled); ASSERT((ticket2.register = ticket1.register) OR (ticket2.register = None));

				ExchangeTickets(ticket1,ticket2);

				physicalRegisters.Free(ticket1.register);
				spillStack.Free(ticket2.offset);
				ticket2.register := ticket1.register;
				ticket1.offset := ticket2.offset;
				ticket1.spilled := TRUE;
				ticket2.spilled := FALSE;
				physicalRegisters.Allocate(ticket2.register,ticket2);
				IF dump# NIL THEN dump.String("spillstack allocate (2) "); dump.Int(ticket1.offset,1); dump.Ln; END;
				spillStack.Allocate(ticket1.offset,ticket1);
				RETURN TRUE
			END ExchangeSpill;

			PROCEDURE SpillToRegister(ticket: Ticket; register: LONGINT);
			VAR size: LONGINT;
			BEGIN
				ASSERT(~physicalRegisters.Reserved(ticket.register) OR (register = ticket.register));
				ticket.register := register;
				IF dump # NIL THEN
					dump.String(" allocate register : index="); dump.Int(ticket.register,1); dump.Ln;
				END;
				ToRegister(ticket);
				size := spillStack.Size();
				spillStack.Free(ticket.offset);
				ticket.spilled := FALSE;
				ticket.offset := 0;
				physicalRegisters.Allocate(register,ticket);
				size := spillStack.Size()-size;
				ASSERT(size<=0);
				IF size<0 THEN AllocateSpillStack(size) END;
			END SpillToRegister;

		BEGIN
			IF (ticket = NIL) OR ~ticket.spilled THEN RETURN END;

			register := ticket.register;
			IF register = None THEN
				register := physicalRegisters.NextFree(ticket.type);
				IF register # None THEN (* free register found rightaway*)
					SpillToRegister(ticket, register)
				ELSE
					mapped := GetPreferredSpill(ticket.type);
					IF ~ExchangeSpill(mapped, ticket) THEN
						register := ForceFreeRegister(ticket.type);
						SpillToRegister(ticket, register);
					END;
				END;
			ELSE
				mapped := physicalRegisters.Mapped(register);
				IF mapped = NIL THEN
					SpillToRegister(ticket, register)
				ELSIF ~ExchangeSpill(mapped, ticket) THEN
					WHILE mapped # NIL DO
						Spill(mapped);
						mapped := physicalRegisters.Mapped(ticket.register);
					END;
					SpillToRegister(ticket, register)
				END;
			END;
		END UnSpill;

		PROCEDURE GetPreferredSpill*(CONST type: IntermediateCode.Type): Ticket;
		VAR ticket,spill: Ticket;
			PROCEDURE Spillable(ticket: Ticket; best:BOOLEAN): BOOLEAN;
			BEGIN
				RETURN
					~ticket.spilled & ticket.spillable & (ticket.register # None) 
					& ((ticket.type.form = IntermediateCode.Float) = (type.form = IntermediateCode.Float)) (* don't spill float when int is needed *)
					& (~best OR (ticket.type.sizeInBits = type.sizeInBits))
					& (~physicalRegisters.Reserved(ticket.register))
					(*! check that register is not in use in current instruction*)
			END Spillable;
		BEGIN
			ticket := tickets.live;
			WHILE ticket # NIL DO
				IF Spillable(ticket,TRUE) THEN spill := ticket END;
				ticket := ticket.next
			END;
			IF ticket = NIL THEN
				ticket := tickets.live;
				WHILE ticket # NIL DO
					IF Spillable(ticket,FALSE) THEN spill := ticket END;
					ticket := ticket.next
				END;
			END;
			ASSERT(spill # NIL);
			RETURN spill
		END GetPreferredSpill;

		PROCEDURE ForceFreeRegister*(CONST type:IntermediateCode.Type): LONGINT;
		VAR tempReg: LONGINT; ticket: Ticket;
		BEGIN
			tempReg := physicalRegisters.NextFree(type);
			WHILE tempReg = None DO
				ticket := GetPreferredSpill(type);
				Spill(ticket);
				tempReg := physicalRegisters.NextFree(type);
			END;
			RETURN tempReg
		END ForceFreeRegister;

		PROCEDURE ReservePhysicalRegister*(CONST class: IntermediateCode.RegisterClass; CONST type: IntermediateCode.Type; register: LONGINT; lastUse: LONGINT): Ticket;
		VAR ticket: Ticket;
		BEGIN
			ticket := tickets.Enter(class, type,register,TRUE, FALSE,None,lastUse);
			IF dump # NIL THEN
				dump.String(" allocate register : index="); dump.Int(register,1); dump.Ln;
			END;
			physicalRegisters.Allocate(register, ticket);
			RETURN ticket
		END ReservePhysicalRegister;

		PROCEDURE TemporaryTicket*(CONST class: IntermediateCode.RegisterClass; CONST type: IntermediateCode.Type): Ticket;
		VAR register: LONGINT; ticket: Ticket;
		BEGIN
			IF type.form > IntermediateCode.Undefined THEN
				register := ForceFreeRegister(type);
				ticket := ReservePhysicalRegister(class,type,register,inPC);
				ticket.parts := 1;
			ELSE
				ticket := NIL
			END;
			RETURN ticket
		END TemporaryTicket;

		(*-------------------  register mapping  ----------------------*)

		PROCEDURE MapVirtualRegister*(virtualRegister: LONGINT; class: IntermediateCode.RegisterClass; type: IntermediateCode.Type; part: LONGINT);
		VAR partType: IntermediateCode.Type; lastuse:LONGINT;

			PROCEDURE MapTicket(CONST type: IntermediateCode.Type; lastuse:LONGINT);
			VAR index,offset,size: LONGINT; ticket: Ticket;
			BEGIN
				index := physicalRegisters.NextFree(type);
				IF index # None THEN
					ticket := tickets.Enter(class,type,index,TRUE, FALSE,0,lastuse);
					IF dump # NIL THEN
						dump.String(" allocate register : index="); dump.Int(index,1); dump.Ln;
					END;
					physicalRegisters.Allocate(index,ticket);
					physicalRegisters.SetReserved(index,TRUE);
				ELSE (* spill new ticket rightaway, no phyiscal register assigned yet *)
					offset := spillStack.NextFree();
					ticket := tickets.Enter(class,type,index,TRUE, TRUE,offset,lastuse);
					size := spillStack.Size();
					ticket.offset := offset;
					IF dump# NIL THEN dump.String("spillstack allocate (3) "); dump.Int(offset,1);dump.Ln; END;
					spillStack.Allocate(offset,ticket);
					size := spillStack.Size()-size;
					ASSERT(size>=0);
					IF size>0 THEN AllocateSpillStack(size) END;
				END;
				virtualRegisters.SetMapped(virtualRegister,part,ticket);
			END MapTicket;

			PROCEDURE AllocateThis(index: LONGINT);
			VAR ticket: Ticket;
			BEGIN
				ticket :=  physicalRegisters.Mapped(index);
				IF ticket # NIL THEN Spill(ticket) END;
				ticket := tickets.Enter(class, type, index, TRUE, FALSE,0,lastuse);
				IF dump # NIL THEN
					dump.String(" allocate register : index="); dump.Int(index,1); dump.Ln;
				END;
				physicalRegisters.Allocate(index,ticket);
				physicalRegisters.SetReserved(index, TRUE);
				virtualRegisters.SetMapped(virtualRegister,part,ticket);
			END AllocateThis;

		BEGIN
			IF virtualRegisters.Mapped(virtualRegister,part)=NIL THEN
				lastuse := LastUse(virtualRegister);
				GetPartType(type,part,partType);
				IF partType.form # IntermediateCode.Undefined THEN
					IF class.class = IntermediateCode.Parameter THEN
						AllocateThis(ParameterRegister(partType, class.number));
					ELSE
						MapTicket(partType,lastuse)
					END;
				END;
			END;
		END MapVirtualRegister;

		PROCEDURE ResetTicket(ticket: Ticket);
		BEGIN
			ticket.offset := 0;
			ticket.spilled := FALSE;
			ticket.register := None;
			ticket.parts := 0;
		END ResetTicket;

		PROCEDURE FreeTicket(ticket: Ticket);
		VAR size: LONGINT;
		BEGIN
			IF ticket.spilled THEN
				IF dump # NIL THEN
					dump.String(" free spilled register : ofs="); dump.Int(ticket.offset,1); dump.Ln;
				END;
				size := spillStack.Size();
				spillStack.Free(ticket.offset);
				size := spillStack.Size()-size;
				ASSERT(size<=0);
				IF size<0 THEN AllocateSpillStack(size) END;
			ELSIF ticket.register # None THEN
				IF dump # NIL THEN
					dump.String("free register: index="); dump.Int(ticket.register,1);  dump.Ln;
				END;
				physicalRegisters.SetReserved(ticket.register,FALSE);
				physicalRegisters.Free(ticket.register);
				ASSERT(~physicalRegisters.Reserved(ticket.register));
			END;
		END FreeTicket;

		PROCEDURE RemapTicket(ticket: Ticket);
		VAR size: LONGINT;
		BEGIN
			IF ~ticket.spilled THEN
				IF dump # NIL THEN
					dump.String(" remap register : index="); dump.Int(ticket.register,1); dump.Ln;
				END;
				physicalRegisters.Allocate(ticket.register,ticket);
				physicalRegisters.SetReserved(ticket.register,TRUE);
			ELSE (* spill new ticket rightaway, no phyiscal register assigned yet *)
				size := spillStack.Size();
				IF dump# NIL THEN dump.String("spillstack allocate (4)"); dump.Int(ticket.offset,1); dump.Ln; END;
				spillStack.Allocate(ticket.offset,ticket);
				size := spillStack.Size()-size;
				ASSERT(size>=0);
				IF size>0 THEN AllocateSpillStack(size) END;
			END;
		END RemapTicket;

		(* unmap ticket: free  register or spill stack position and remove ticket from list of live tickets *)
		PROCEDURE UnmapTicket*(ticket: Ticket);
		BEGIN
			IF ticket = NIL THEN RETURN END;
			FreeTicket(ticket);
			tickets.Remove(ticket);
			ResetTicket(ticket);
		END UnmapTicket;

		PROCEDURE TryAllocate*(CONST operand: IntermediateCode.Operand; part: LONGINT);
		BEGIN
			IF (FirstUse(operand.register) = inPC) & (virtualRegisters.Mapped(operand.register,part)=NIL)  THEN
				IF operand.mode = IntermediateCode.ModeMemory THEN
					MapVirtualRegister(operand.register,operand.registerClass,IntermediateCode.GetType(module.system,module.system.addressType),part);
				ELSE
					MapVirtualRegister(operand.register,operand.registerClass, operand.type,part);
				END;
				ASSERT(virtualRegisters.Mapped(operand.register,part)#NIL);
			END;
		END TryAllocate;

		PROCEDURE TryUnmap*(CONST operand: IntermediateCode.Operand);
		VAR ticket: Ticket; part,i: LONGINT;
		BEGIN
			IF (operand.register >=0) & (LastUse(operand.register) = inPC) THEN
				part := 0;
				WHILE (part<virtualRegisters.Parts()) DO
					ticket := virtualRegisters.Mapped(operand.register,part);
					IF (ticket # NIL) THEN
						virtualRegisters.Unmap(operand.register)
					END;
					INC(part);
				END;
			END;
			IF operand.rule # NIL THEN
				FOR i := 0 TO LEN(operand.rule)-1 DO
					TryUnmap(operand.rule[i]);
				END
			END
		END TryUnmap;

		PROCEDURE ReleaseHint*(register: LONGINT);
		VAR ticket: Ticket;
		BEGIN
			IF register >=0 THEN
				ticket := physicalRegisters.Mapped(register);
				IF (ticket # NIL) & (ticket.lastuse <= inPC) THEN
					DEC(ticket.parts); (* to avoid freeing a register that is used at several parts of an operand *)
					IF ticket.parts=0 THEN
						physicalRegisters.SetReserved(register,FALSE);
						UnmapTicket(ticket);
						physicalRegisters.AllocationHint(register);
					END;
				END;
			END;
		END ReleaseHint;

		(* increase usage counter of register mapped by ticket - allocated or not *)
		PROCEDURE ReserveTicketRegister*(ticket: Ticket; reserved: BOOLEAN);
		BEGIN
			IF (ticket#NIL) & (ticket.register # None) THEN
				physicalRegisters.SetReserved(ticket.register,reserved)
			END;
		END ReserveTicketRegister;

		PROCEDURE ReserveOperandRegisters*(CONST operand: IntermediateCode.Operand; reserved: BOOLEAN);
		VAR i: LONGINT; ticket: Ticket;
		BEGIN
			FOR i := 0 TO virtualRegisters.Parts()-1 DO
				ticket := virtualRegisters.Mapped(operand.register,i);
				IF ticket # NIL THEN
					ReserveTicketRegister(ticket,reserved);
					IF operand.mode = IntermediateCode.ModeMemory THEN
						ticket.parts := virtualRegisters.Parts()
					ELSE
						ticket.parts := 1
					END;
				END;
			END;
		END ReserveOperandRegisters;

	END GeneratorWithTickets;

	PROCEDURE Assert(cond: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN ASSERT(cond);
	END Assert;

	PROCEDURE DumpTicket*(w: Streams.Writer; ticket: Ticket);
	BEGIN
		w.String("register "); w.Int(ticket.register,1);
		w.String(" with type ");
		IntermediateCode.DumpType(w,ticket.type);
		IF ticket.spilled THEN w.String(" spilled at "); w.Int(ticket.offset,1) END;
		w.String(" parts "); w.Int(ticket.parts,1);
		w.String(" last use "); w.Int(ticket.lastuse,1);
	END DumpTicket;

END FoxCodeGenerators.
