MODULE FoxIntermediateObjectFile; (** AUTHOR ""; PURPOSE "Intermediate Object File Writer"; *)

IMPORT
	Formats := FoxFormats, Sections := FoxSections, IntermediateCode := FoxIntermediateCode, ObjectFile,
	Files, Strings, Options, Diagnostics, TextualSymbolFile := FoxTextualSymbolFile, Streams, Basic := FoxBasic,
	SyntaxTree := FoxSyntaxTree,  D := Debugging, Global := FoxGlobal, Parser := FoxIntermediateParser, Commands,  KernelLog, Backend := FoxBackend;

CONST
	Trace = FALSE;
	DeveloperVersion=TRUE;
	Version=2;

TYPE ObjectFileFormat* = OBJECT (Formats.ObjectFileFormat)
	VAR prefix, extension: Files.FileName; textual: BOOLEAN;

		PROCEDURE & InitObjectFileFormat*;
		BEGIN
			Init;
			prefix := ""; extension := ".Fil";
		END InitObjectFileFormat;

		PROCEDURE ExportModuleTextual(module: Sections.Module; writer: Streams.Writer);
		VAR
			section: Sections.Section;
			intermediateCodeSection: IntermediateCode.Section;
			i: LONGINT;
		BEGIN
			(* prepare sections for output *)
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				ASSERT(section IS IntermediateCode.Section);
				intermediateCodeSection := section(IntermediateCode.Section);
				intermediateCodeSection.SetResolved(NIL); (* remove generated binary code *)
				intermediateCodeSection.DeleteComments (* remove comments *)
			END;
			module.Dump(writer)
		END ExportModuleTextual;

		PROCEDURE ExportModuleBinary(module: Sections.Module; w: Streams.Writer; poolMap: ObjectFile.PoolMap);
		VAR
			section: Sections.Section;
			intermediateCodeSection: IntermediateCode.Section;

			PROCEDURE SectionName(sectionName: ObjectFile.SegmentedName);
			VAR name: ObjectFile.SectionName; i,num: LONGINT;
			BEGIN
				i := 0;
				REPEAT
					num := poolMap.Get(sectionName[i]);
					w.RawNum(num);
					INC(i);
				UNTIL (i = LEN(sectionName)) OR (num < 0);
			END SectionName;

			PROCEDURE WriteOperand(CONST operand: IntermediateCode.Operand);

				PROCEDURE Type(t: IntermediateCode.Type);
				BEGIN
					w.RawSInt(t.form);
					w.RawInt(t.sizeInBits);
				END Type;

				PROCEDURE RegisterClass(c: IntermediateCode.RegisterClass);
				BEGIN
					w.RawSInt(c.class);
					w.RawInt(c.number);
				END RegisterClass;

			BEGIN
				Type(operand.type);
				w.RawNum(operand.mode);
				CASE operand.mode OF
				IntermediateCode.Undefined:
				|IntermediateCode.ModeMemory:
						IF operand.register # IntermediateCode.None THEN
							w.RawNum(0);
							w.RawNum(operand.register);
							w.RawNum(operand.offset);
						ELSIF operand.symbol.name # "" THEN
							w.RawNum(1);
							SectionName(operand.symbol.name);
							w.RawNum(operand.symbolOffset);
							w.RawNum(operand.offset);
						ELSE
							w.RawNum(2);
							w.RawHInt(operand.intValue)
						END;
				|IntermediateCode.ModeRegister:
					w.RawNum(operand.register);
					RegisterClass(operand.registerClass);
					w.RawNum(operand.offset);
				|IntermediateCode.ModeImmediate:
					IF operand.symbol.name # "" THEN
						w.RawNum(0);
						SectionName(operand.symbol.name);
						w.RawNum(operand.symbolOffset);
						w.RawNum(operand.offset);
					ELSE
						w.RawNum(1);
						IF operand.type.form IN IntermediateCode.Integer THEN
							w.RawHInt(operand.intValue);
						ELSE
							w.RawLReal(operand.floatValue);
						END;
					END;
				|IntermediateCode.ModeString:
					w.RawNum(Strings.Length(operand.string^));
					w.RawString(operand.string^);
				|IntermediateCode.ModeNumber:
					w.RawHInt(operand.intValue);
				END;

			END WriteOperand;

			PROCEDURE WriteInstruction(CONST instr: IntermediateCode.Instruction);
			BEGIN
				w.RawNum(instr.opcode);
				IF instr.opcode = IntermediateCode.special THEN w.RawNum(instr.subtype) END;
				WriteOperand(instr.op1);
				WriteOperand(instr.op2);
				WriteOperand(instr.op3);
			END WriteInstruction;

			PROCEDURE WriteSection(section: IntermediateCode.Section);
			VAR i: LONGINT;
			BEGIN
				w.RawLInt(section.type);
				SectionName(section.name);
				w.RawBool(section.fixed);
				w.RawNum(section.positionOrAlignment);
				w.RawNum(section.priority);
				w.RawNum(section.fingerprint);
				w.RawNum(section.bitsPerUnit);

				w.RawNum(section.pc);
				FOR i := 0 TO section.pc-1 DO
					WriteInstruction(section.instructions[i]);
				END;
			END WriteSection;

			PROCEDURE SectionList(list: Sections.SectionList);
			VAR section: Sections.Section;i: LONGINT;
			BEGIN
				w.RawNum(list.Length());
				FOR i := 0 TO list.Length() - 1 DO
					section := list.GetSection(i);
					WriteSection(section(IntermediateCode.Section));
				END;
			END SectionList;

			PROCEDURE Imports(imports: Sections.NameList);
			VAR name: SyntaxTree.IdentifierString;i: LONGINT;
			BEGIN
				w.RawNum(imports.Length());
				FOR i := 0 TO imports.Length()-1 DO
					name := imports.GetName(i);
					w.RawString(name);
				END;
			END Imports;

		BEGIN
			w.RawString(module.moduleName);
			w.RawString(module.platformName);

			Imports(module.imports);

			SectionList(module.allSections);
		END ExportModuleBinary;

		PROCEDURE Export*(module: Formats.GeneratedModule; symbolFileFormat: Formats.SymbolFileFormat): BOOLEAN;
		VAR
			filename: Files.FileName;
			file: Files.File;
			writer: Files.Writer;
			poolMap: ObjectFile.PoolMap;
		BEGIN
			IF Trace THEN D.String(">>> export intermediate object file"); D.Ln END;

			IF ~(module IS Sections.Module) THEN
				diagnostics.Error(module.moduleName, Diagnostics.Invalid, Diagnostics.Invalid, "generated module format does not match object file format");
				RETURN FALSE;
			END;

			IF prefix # "" THEN Files.JoinPath(prefix, module.moduleName, filename); ELSE COPY (module.moduleName, filename); END;
			Files.JoinExtension(filename, extension, filename);

			IF Trace THEN D.String(">>> filename: "); D.String(filename); D.Ln END;

			file := Files.New(filename);
			IF file = NIL THEN
				diagnostics.Error(module.moduleName, Diagnostics.Invalid,Diagnostics.Invalid, "failed to open object file for writting");
				RETURN FALSE
			END;

			Files.OpenWriter(writer, file, 0);
			IF textual THEN
				WriteHeader(writer, FALSE, module(Sections.Module).allSections, poolMap);
				ExportModuleTextual(module(Sections.Module),writer);
			ELSE
				WriteHeader(writer, TRUE, module(Sections.Module).allSections, poolMap);
				ExportModuleBinary(module(Sections.Module),writer, poolMap);
			END;
			writer.Update;
			file.Update;
			Files.Register(file);

			RETURN TRUE
		END Export;

		PROCEDURE ImportModuleBinary(r: Streams.Reader; module: Sections.Module; system: Global.System; poolMap: ObjectFile.PoolMap): BOOLEAN;
		VAR
			section: Sections.Section;
			name: ObjectFile.SectionName;
			addressType: IntermediateCode.Type;

			PROCEDURE SectionName(VAR sectionName: ObjectFile.SegmentedName);
			VAR name: ObjectFile.SectionName; i, num: LONGINT;
			BEGIN
				i := 0;
				REPEAT
					r.RawNum(num);
					sectionName[i] := poolMap.Get(num);
					INC(i);
				UNTIL (i = LEN(sectionName)) OR (num < 0);
				WHILE i < LEN(sectionName) DO
					sectionName[i] := -1; INC(i);
				END;
			END SectionName;

			PROCEDURE ReadOperand(VAR operand: IntermediateCode.Operand);
			VAR type: IntermediateCode.Type; mode, subMode: LONGINT; register: LONGINT; registerClass: IntermediateCode.RegisterClass;
				offset: LONGINT; int: HUGEINT; real: LONGREAL; name: ObjectFile.SegmentedName; symbolOffset: LONGINT;
				string: Strings.String; len: LONGINT;
				symbolSection: Sections.Section;

				PROCEDURE Type(VAR t: IntermediateCode.Type);
				VAR form: SHORTINT; sizeInBits: INTEGER;
				BEGIN
					r.RawSInt(form);
					r.RawInt(sizeInBits);
					IntermediateCode.InitType(t, form, sizeInBits)
				END Type;

				PROCEDURE RegisterClass(VAR c: IntermediateCode.RegisterClass);
				VAR class: SHORTINT; number: INTEGER;
				BEGIN
					r.RawSInt(class);
					r.RawInt(number);
					IntermediateCode.InitRegisterClass(c, class, number)
				END RegisterClass;

			BEGIN
				Type(type);
				IntermediateCode.SetType(operand, type);
				r.RawNum(mode);
				CASE mode OF
				IntermediateCode.Undefined:
					IntermediateCode.InitOperand(operand); (* no operand *)
				|IntermediateCode.ModeMemory:
						r.RawNum(subMode);
						IF subMode = 0 THEN
							r.RawNum(register);
							r.RawNum(offset);
							IntermediateCode.InitRegister(operand, addressType, IntermediateCode.GeneralPurposeRegister, register);
						ELSIF subMode = 1 THEN
							SectionName(name);
							r.RawNum(symbolOffset);
							r.RawNum(offset);
							IntermediateCode.InitAddress(operand, addressType, name, 0, symbolOffset);
						ELSE
							offset := 0;
							ASSERT(subMode = 2);
							r.RawHInt(int);
							IntermediateCode.InitImmediate(operand, addressType, int);
						END;
						IntermediateCode.InitMemory(operand, type, operand, offset);
				|IntermediateCode.ModeRegister:
					r.RawNum(register); RegisterClass(registerClass); r.RawNum(offset);
					IntermediateCode.InitRegister(operand, type, registerClass, register);
					IntermediateCode.AddOffset(operand, offset);
				|IntermediateCode.ModeImmediate:
					r.RawNum(subMode);
					IF subMode = 0 THEN (* ?? *)
						SectionName(name);
						r.RawNum(symbolOffset);
						r.RawNum(offset);
						IntermediateCode.InitAddress(operand, type, name, 0, symbolOffset);
						IntermediateCode.AddOffset(operand, offset);
					ELSE
						ASSERT(subMode = 1);
						IF operand.type.form IN IntermediateCode.Integer THEN
							r.RawHInt(int);
							IntermediateCode.InitImmediate(operand, type, int);
						ELSE
							r.RawLReal(real);
							IntermediateCode.InitFloatImmediate(operand, type, real);
						END;
					END;
				|IntermediateCode.ModeString:
					r.RawNum(len);
					NEW(string, len);
					r.RawString(string^);
					IntermediateCode.InitString(operand, string);
				|IntermediateCode.ModeNumber:
					r.RawHInt(int);
					IntermediateCode.InitNumber(operand, int)
				END;
			END ReadOperand;

			PROCEDURE ReadInstruction(section: IntermediateCode.Section);
			VAR opcode, subtype: LONGINT; instruction: IntermediateCode.Instruction; op1, op2, op3: IntermediateCode.Operand;
			BEGIN
				r.RawNum(opcode);
				IF opcode = IntermediateCode.special THEN r.RawNum(subtype) END;

				ReadOperand(op1);
				ReadOperand(op2);
				ReadOperand(op3);
				IntermediateCode.InitInstruction(instruction, 0, SHORTINT(opcode), op1, op2, op3);
				IntermediateCode.SetSubType(instruction, SHORTINT(subtype));
				section.Emit(instruction);
			END ReadInstruction;

			PROCEDURE ReadSection(sectionList: Sections.SectionList);
			VAR section: IntermediateCode.Section;
				isDefinition: BOOLEAN;
				name: Basic.SegmentedName;
				symbol: SyntaxTree.Symbol;
				comment: BOOLEAN;
				type: LONGINT;
				fixed: BOOLEAN;
				positionOrAlignment, priority, fingerprint, bitsPerUnit: LONGINT;
				pc,i: LONGINT;
			BEGIN
				r.RawLInt(type);
				SectionName(name);
				r.RawBool(fixed);
				r.RawNum(positionOrAlignment);
				r.RawNum(priority);
				r.RawNum(fingerprint);
				r.RawNum(bitsPerUnit);

				section := IntermediateCode.NewSection(sectionList, SHORTINT(type), name, NIL, FALSE); (* keeps section if already present *)				
				IF bitsPerUnit < 0 THEN (* unknown *)
					IF (type = Sections.VarSection) OR (type = Sections.ConstSection) THEN
						bitsPerUnit := system.dataUnit
					ELSE
						(*bitsPerUnit := system.codeUnit*)
						(*Unit is already set.*)						
					END;
				END;
				section.SetBitsPerUnit(bitsPerUnit);
				section.SetFingerprint(fingerprint);
				section.SetPriority(INTEGER(priority));
				section.SetPositionOrAlignment(fixed, positionOrAlignment);

				r.RawNum(pc);
				FOR i := 0 TO pc-1 DO
					ReadInstruction(section);
				END;
			END ReadSection;

			PROCEDURE SectionList(list: Sections.SectionList);
			VAR section: Sections.Section; length,i: LONGINT;
			BEGIN
				r.RawNum(length);
				FOR i := 0 TO length - 1 DO
					ReadSection(list);
				END;
			END SectionList;

			PROCEDURE Imports(imports: Sections.NameList);
			VAR name: SyntaxTree.IdentifierString; length,i: LONGINT;
			BEGIN
				r.RawNum(length);
				FOR i := 0 TO length-1 DO
					r.RawString(name);
					imports.AddName(name);
				END;
			END Imports;

		BEGIN
			addressType := IntermediateCode.UnsignedIntegerType(system.addressSize);
			r.RawString(name); module.SetModuleName(name);
			r.RawString(name); module.SetPlatformName(name);
			Imports(module.imports);
			SectionList(module.allSections);
			RETURN TRUE
		END ImportModuleBinary;

		PROCEDURE ImportModuleTextual(r: Streams.Reader; module: Sections.Module; system: Global.System): BOOLEAN;
		BEGIN
			RETURN Parser.ParseReader(r, diagnostics, module)
		END ImportModuleTextual;

		PROCEDURE Import*(CONST moduleName: ARRAY OF CHAR; system: Global.System): Sections.Module;
		VAR module: Sections.Module; file: Files.File; reader: Files.Reader; binary: BOOLEAN; filename: Files.FileName; poolMap: ObjectFile.PoolMap;
		BEGIN
			IF prefix # "" THEN Files.JoinPath(prefix, moduleName, filename); ELSE COPY (moduleName, filename); END;
			Files.JoinExtension(filename, extension, filename);

			file := Files.Old(filename);
			IF file = NIL THEN RETURN NIL END;
			NEW(reader, file, 0);
			ReadHeader(reader, binary, poolMap);
			NEW(module, NIL, system);
			IF binary & ImportModuleBinary(reader, module, system, poolMap) OR  ~binary & ImportModuleTextual(reader, module, system) THEN
				RETURN module
			ELSE
				RETURN NIL
			END;
		END Import;

		PROCEDURE DefineOptions* (options: Options.Options);
		BEGIN
			options.Add(0X,"objectFileExtension",Options.String);
			options.Add(0X,"objectFilePrefix",Options.String);
			options.Add(0X,"textualObjectFile",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions* (options: Options.Options);
		BEGIN
			IF ~options.GetString("objectFileExtension",extension) THEN extension := "Fil"; END;
			IF ~options.GetString("objectFilePrefix",prefix) THEN prefix := ""; END;
			textual := options.GetFlag("textualObjectFile");
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN TextualSymbolFile.Get();
		END DefaultSymbolFileFormat;

		PROCEDURE GetExtension(VAR ext: ARRAY OF CHAR);
		BEGIN COPY(extension, ext)
		END GetExtension;

		PROCEDURE SetExtension(CONST ext: ARRAY OF CHAR);
		BEGIN COPY(ext, extension)
		END SetExtension;
		
	END ObjectFileFormat;

	PROCEDURE Get*(): Formats.ObjectFileFormat;
	VAR intermediateObjectFileFormat: ObjectFileFormat;
	BEGIN NEW(intermediateObjectFileFormat); RETURN intermediateObjectFileFormat
	END Get;

	PROCEDURE ReadHeader(reader: Streams.Reader; VAR binary: BOOLEAN; VAR poolMap: ObjectFile.PoolMap);
	VAR ch: CHAR; version: LONGINT; string: ARRAY 32 OF CHAR; i,j,pos,size: LONGINT; name: ObjectFile.SectionName;
	BEGIN
		reader.String(string);
		binary := string="FoxILB";
		IF ~binary THEN ASSERT(string="FoxILT") END;
		reader.SkipWhitespace;
		reader.Char(ch); ASSERT(ch='v');
		reader.Int(version,FALSE);
		IF version < Version THEN KernelLog.String("warning: old object file encountered"); KernelLog.Ln END;
		reader.Char(ch); ASSERT(ch='.');
		IF ~binary THEN reader.SkipWhitespace
		ELSE
			NEW(poolMap, 64);
			poolMap.Read(reader);
		END;
	END ReadHeader;

	PROCEDURE WriteHeader(writer: Streams.Writer; binary: BOOLEAN; sections: Sections.SectionList; VAR poolMap: ObjectFile.PoolMap);
	VAR p1,p2, size,i: LONGINT; section: Sections.Section; fixups: LONGINT; fixupList: ObjectFile.Fixups;

		PROCEDURE ProcessOperand(CONST operand: IntermediateCode.Operand);
		BEGIN
			IF operand.symbol.name # "" THEN
				poolMap.PutSegmentedName(operand.symbol.name)
			END;
		END ProcessOperand;

		PROCEDURE ProcessInstruction(CONST instruction: IntermediateCode.Instruction);
		BEGIN
			ProcessOperand(instruction.op1);
			ProcessOperand(instruction.op2);
			ProcessOperand(instruction.op3);
		END ProcessInstruction;

		PROCEDURE ProcessSection(section: IntermediateCode.Section);
		VAR i: LONGINT; index: LONGINT;
		BEGIN
			IF section.resolved # NIL THEN
				poolMap.PutSegmentedName(section.name);
				FOR i := 0 TO section.pc-1 DO
					ProcessInstruction(section.instructions[i]);
				END;
			END;
		END ProcessSection;

	BEGIN
		IF binary THEN writer.String("FoxILB");
		ELSE writer.String("FoxILT");
		END;
		writer.Char(' ');
		writer.Char('v'); writer.Int(Version,0); writer.Char(".");
		IF ~binary THEN writer.Ln
		ELSE
			NEW(poolMap,512);
			poolMap.BeginWriting(writer);
			FOR i := 0 TO sections.Length()-1 DO
				section := sections.GetSection(i);
				ProcessSection(section(IntermediateCode.Section));
			END;
			poolMap.EndWriting;
		END;
	END WriteHeader;


	(* test code to display --not public *)
	PROCEDURE Show*(context: Commands.Context);
	VAR
		fileName: Files.FileName; file: Files.File; reader: Files.Reader; writer: Streams.Writer;
		section: ObjectFile.Section; binary: BOOLEAN; poolMap, poolMapDummy: ObjectFile.PoolMap;
		objectFile: ObjectFileFormat; module: Sections.Module; backend: Backend.Backend;
		extension: Files.FileName;
	BEGIN
		IF DeveloperVersion THEN
			IF context.arg.GetString(fileName) THEN
				backend := Backend.GetBackendByName("TRM");
				Files.SplitExtension(fileName, fileName, extension); 
				NEW(objectFile);
				IF extension # "" THEN objectFile.SetExtension(extension) END;
				module := objectFile.Import(fileName, backend.GetSystem());
				writer := Basic.GetWriter(Basic.GetDebugWriter(fileName));
				objectFile.ExportModuleTextual(module, writer);
				writer.Update;
			ELSE
				context.error.String("no file specificed"); context.error.Ln
			END;
		ELSE HALT(200)
		END;
	END Show;

END FoxIntermediateObjectFile.

SystemTools.FreeDownTo FoxIntermediateObjectFile ~
FoxIntermediateObjectFile.Show TRMRuntime  ~

			(* test code to compare ..
			backend: Backend.Backend;
			IF prefix # "" THEN Files.JoinPath(prefix, module.moduleName, filename); ELSE COPY (module.moduleName, filename); END;
			Files.JoinExtension(filename, "fil2", filename);
			file := Files.New(filename);
			backend := Backend.GetBackendByName("TRM");
			Files.OpenWriter(writer, file, 0);
			module := Import(module.moduleName, backend.GetSystem());
			ExportModuleTextual(module(Sections.Module), writer);
			writer.Update;
			Files.Register(file);
			*)

