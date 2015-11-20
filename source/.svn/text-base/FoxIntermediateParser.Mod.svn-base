MODULE FoxIntermediateParser;
IMPORT
	Strings, Diagnostics, D := Debugging, SyntaxTree := FoxSyntaxTree, Scanner := FoxScanner, Sections := FoxSections,
	IntermediateCode := FoxIntermediateCode, Basic := FoxBasic, Streams, Files, Global := FoxGlobal;

CONST
	IntermediateCodeExtension = "Fil"; (* TODO: move to a better place *)
	Trace=FALSE;

TYPE
	MessageString= ARRAY 256 OF CHAR;

	(** the intermediate code parser **)
	IntermediateCodeParser* = OBJECT
	CONST
		Trace = FALSE;
		Strict = TRUE;

	VAR
		diagnostics: Diagnostics.Diagnostics;
		error: BOOLEAN;
		symbol: Scanner.Symbol;
		scanner: Scanner.AssemblerScanner;
		system: Global.System;

		PROCEDURE &Init*(diagnostics: Diagnostics.Diagnostics; s: Global.System);
		BEGIN
			ASSERT(s # NIL); (* a default system object is required in case there is no platform directive *)
			SELF.diagnostics := diagnostics;
			system := s;
			error := FALSE
		END Init;

		PROCEDURE Error(pos: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			error := TRUE;
			IF diagnostics # NIL THEN
				diagnostics.Error(scanner.source^,pos,Diagnostics.Invalid,msg);
			END;

			D.Update;
			IF Trace THEN D.TraceBack END
		END Error;

		PROCEDURE NextSymbol;
		BEGIN error := error OR ~scanner.GetNextSymbol(symbol)
		END NextSymbol;

		PROCEDURE ThisToken(x: LONGINT): BOOLEAN;
		BEGIN
			IF ~error & (symbol.token = x) THEN NextSymbol; RETURN TRUE ELSE RETURN FALSE END;
		END ThisToken;

		PROCEDURE GetIdentifier(VAR pos: LONGINT; VAR identifier: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			pos := symbol.start;
			IF symbol.token # Scanner.Identifier THEN RETURN FALSE
			ELSE COPY(symbol.identifierString,identifier); NextSymbol; RETURN TRUE
			END;
		END GetIdentifier;

		PROCEDURE ExpectToken(x: LONGINT): BOOLEAN;
		VAR
			s: MessageString;
		BEGIN
			IF ThisToken(x) THEN RETURN TRUE
			ELSE
				s := "expected token "; Strings.Append(s,Scanner.tokens[x]); Strings.Append(s," but got "); Strings.Append(s,Scanner.tokens[symbol.token]);
				Error(symbol.start, s);RETURN FALSE
			END;
		END ExpectToken;

		PROCEDURE ThisIdentifier(CONST this: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF ~error & (symbol.token = Scanner.Identifier) & (this = symbol.identifierString) THEN NextSymbol; RETURN TRUE ELSE RETURN FALSE END;
		END ThisIdentifier;

		PROCEDURE ExpectAnyIdentifier(VAR pos: LONGINT; VAR identifier: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF ~GetIdentifier(pos,identifier)THEN Error(pos,"identifier expected"); RETURN FALSE
			ELSE RETURN TRUE
			END;
		END ExpectAnyIdentifier;

		PROCEDURE ExpectIntegerWithSign(VAR integer: LONGINT): BOOLEAN;
		VAR
			result, isNegated: BOOLEAN;
		BEGIN
			isNegated := ThisToken(Scanner.Minus);
			IF ExpectToken(Scanner.Number) & (symbol.numberType = Scanner.Integer) THEN
				IF isNegated THEN
					integer := -symbol.integer
				ELSE
					integer := symbol.integer
				END;
				result := TRUE
			ELSE
				result := FALSE
			END;
			RETURN result
		END ExpectIntegerWithSign;

		PROCEDURE ExpectIntegerWithoutSign(VAR integer: LONGINT): BOOLEAN;
		VAR
			result: BOOLEAN;
		BEGIN
			IF ExpectToken(Scanner.Number) & (symbol.numberType = Scanner.Integer) THEN
				integer := symbol.integer;
				result := TRUE
			ELSE
				result := FALSE
			END;
			RETURN result
		END ExpectIntegerWithoutSign;

		PROCEDURE IgnoreNewLines;
		BEGIN
			WHILE ThisToken(Scanner.Ln) DO END;
		END IgnoreNewLines;

		(* expect the newline or end-of-text symbol *)
		PROCEDURE ExpectLineDelimiter(): BOOLEAN;
		BEGIN
			IF ~error & ((symbol.token = Scanner.Ln) OR (symbol.token = Scanner.EndOfText)) THEN
				NextSymbol;
				RETURN TRUE
			ELSE
				Error(symbol.start, "end of line/text expected");
				RETURN FALSE
			END;
		END ExpectLineDelimiter;

		(** parse an optional line number **)
		PROCEDURE ParseLineNumber(expectedLineNumber: LONGINT);
		VAR
			positionOfLine, specifiedLineNumber: LONGINT;
			message, tempString: MessageString;
		BEGIN
			IF Trace THEN D.String(">>> ParseLineNumber"); D.Ln END;

			positionOfLine := symbol.start;
			IF ThisToken(Scanner.Number) THEN (* note: line numbers are optional *)
				specifiedLineNumber := symbol.integer;
				IF ExpectToken(Scanner.Colon) THEN
					IF Strict & (specifiedLineNumber # expectedLineNumber) THEN
						message := "invalid code line number (";
						Strings.IntToStr(specifiedLineNumber, tempString); Strings.Append(message, tempString);
						Strings.Append(message, " instead of ");
						Strings.IntToStr(expectedLineNumber, tempString); Strings.Append(message, tempString);
						Strings.Append(message, ")");
						Error(positionOfLine, message)
					END
				END
			END
		END ParseLineNumber;

		(** parse an intermediate code operand **)
		PROCEDURE ParseOperand(VAR operand: IntermediateCode.Operand; sectionList: Sections.SectionList);
		VAR
			positionOfOperand, pos, registerNumber, symbolOffset, someLongint, integer: LONGINT;
			someHugeint: HUGEINT;
			hasTypeDescriptor, isMemoryOperand, lastWasIdentifier, isNegated: BOOLEAN;
			someLongreal: LONGREAL;
			identifier: SyntaxTree.IdentifierString;
			type: IntermediateCode.Type;
			sectionOfSymbol: Sections.Section;
			name: Basic.SegmentedName;
			registerClass: IntermediateCode.RegisterClass;
		BEGIN
			IF Trace THEN D.String(">>> ParseOperand"); D.Ln END;

			positionOfOperand := symbol.start;

			(* defaults *)
			hasTypeDescriptor := FALSE;
			isMemoryOperand := FALSE;

			(* consume optional type description *)
			lastWasIdentifier := GetIdentifier(pos, identifier);
			IF lastWasIdentifier & IntermediateCode.DenotesType(identifier, type) THEN
				hasTypeDescriptor := TRUE;
				lastWasIdentifier := GetIdentifier(pos, identifier)
			END;

			(* consume optional memory operand bracket *)
			IF ~lastWasIdentifier THEN
				isMemoryOperand := ThisToken(Scanner.LeftBracket);
				lastWasIdentifier := GetIdentifier(pos, identifier)
			END;

			IF lastWasIdentifier THEN
				IF IntermediateCode.DenotesRegister(identifier, registerClass, registerNumber) THEN
					(* register *)
					IntermediateCode.InitRegister(operand, type, registerClass, registerNumber);
				ELSE
					(* TODO: handle assembly constants *)

					(* symbol name *)
					symbolOffset := 0;

					(* consume optional symbol offset *)
					IF ThisToken(Scanner.Colon) THEN
						IF ExpectIntegerWithSign(integer) THEN
							symbolOffset := integer
						ELSE
							Error(symbol.start, "invalid symbol offset")
						END
					END;

					IF Trace THEN D.String(">>> symbol detected"); D.Ln END;

					Basic.ToSegmentedName(identifier, name);
					IntermediateCode.InitAddress(operand, IntermediateCode.UnsignedIntegerType(system.addressSize), name, 0, symbolOffset)
				END

			ELSIF symbol.token = Scanner.String THEN
				(* string constant *)
				IntermediateCode.InitString(operand, symbol.string);
				NextSymbol

			ELSE
				(* immediate values/numbers *)
				isNegated := ThisToken(Scanner.Minus);
				IF ThisToken(Scanner.Number) THEN
					CASE symbol.numberType OF
					| Scanner.Integer:
						IF isNegated THEN someLongint := -symbol.integer ELSE someLongint := symbol.integer END;
						IF ~hasTypeDescriptor THEN
							(* if no type description was included: use number type *)
							IntermediateCode.InitNumber(operand, someLongint);
						ELSIF type.form = IntermediateCode.Float THEN
							ASSERT(hasTypeDescriptor);
							IntermediateCode.InitFloatImmediate(operand, type, REAL(someLongint))
						ELSE
							ASSERT(hasTypeDescriptor & (type.form IN IntermediateCode.Integer));
							IntermediateCode.InitImmediate(operand, type, someLongint)
						END
					| Scanner.Hugeint:
						IF isNegated THEN someHugeint := - symbol.hugeint ELSE someHugeint := symbol.hugeint END;
						IF ~hasTypeDescriptor THEN
							(* if no type description was included: use number type *)
							IntermediateCode.InitNumber(operand, someHugeint)
						ELSIF type.form = IntermediateCode.Float THEN
							ASSERT(hasTypeDescriptor);
							IntermediateCode.InitFloatImmediate(operand, type, REAL(someHugeint))
						ELSE
							ASSERT(hasTypeDescriptor & (type.form IN IntermediateCode.Integer));
							IntermediateCode.InitImmediate(operand, type, someHugeint)
						END
					| Scanner.Real, Scanner.Longreal:
						IF isNegated THEN someLongreal := -symbol.real ELSE someLongreal := symbol.real END;
						(* if no type description was included: use float type with same amount of bits as address type *)
						IF ~hasTypeDescriptor THEN
							IntermediateCode.InitType(type, IntermediateCode.Float, INTEGER(system.addressSize))
						END;
						IF type.form IN IntermediateCode.Integer THEN
							Error(positionOfOperand, "floating point immediate value not applicable")
						ELSE
							IntermediateCode.InitFloatImmediate(operand, type, someLongreal)
						END
					ELSE HALT(100)
					END
				ELSE
					Error(positionOfOperand, "invalid operand")
				END
			END;

			(* consume optional offset given in system units *)
			IF ThisToken(Scanner.Plus) THEN
				IF ExpectIntegerWithoutSign(integer) THEN
					IntermediateCode.SetOffset(operand, integer)
				ELSE
					Error(symbol.start, "invalid offset")
				END
			ELSIF ThisToken(Scanner.Minus) THEN
				IF ExpectIntegerWithoutSign(integer) THEN
					IntermediateCode.SetOffset(operand, -integer)
				ELSE
					Error(symbol.start, "invalid offset")
				END
			END;

			(* wrap memory operand around current operand if necessary *)
			IF isMemoryOperand & ExpectToken(Scanner.RightBracket) THEN
				IntermediateCode.SetType(operand, IntermediateCode.UnsignedIntegerType(system.addressSize)); (* set the type of the inner operand to the platform's address type *)
				IF ~hasTypeDescriptor THEN
					IntermediateCode.InitType(type, IntermediateCode.SignedInteger, INTEGER(system.addressSize)) (* default: signed integer type of address size *)
				END;
				IntermediateCode.InitMemory(operand, type, operand, 0) (* TODO: add offset? *)
			END
		END ParseOperand;

		(** parse an intermediate code instruction **)
		PROCEDURE ParseInstruction(VAR instruction: IntermediateCode.Instruction; sectionList: Sections.SectionList);
		VAR
			opCode: SHORTINT;
			positionOfInstruction, positionOfOperand, operandNumber: LONGINT;
			operand: IntermediateCode.Operand;
			operands: ARRAY 3 OF IntermediateCode.Operand;
			operandType: IntermediateCode.Type;
			identifier, message, tempString: SyntaxTree.IdentifierString;
		BEGIN
			IF Trace THEN D.String(">>> ParseInstruction"); D.Ln END;

			positionOfInstruction := symbol.start;
			IF ExpectAnyIdentifier(positionOfInstruction, identifier) THEN
				(* TODO: detect labels of the form << labelName: >> *)
				opCode := IntermediateCode.FindMnemonic(identifier);

				IF opCode = IntermediateCode.None THEN
					Error(positionOfInstruction, "unknown mnemonic")
				ELSE
					(* consume all operands *)
					IntermediateCode.InitType(operandType, IntermediateCode.SignedInteger, 32); (* defaults *)
					IntermediateCode.InitOperand(operands[0]);
					IntermediateCode.InitOperand(operands[1]);
					IntermediateCode.InitOperand(operands[2]);

					operandNumber := 0;
					IF ~ThisToken(Scanner.Ln) & ~ThisToken(Scanner.EndOfText) THEN
						REPEAT
							positionOfOperand := symbol.start;
							IF operandNumber > 2 THEN
								Error(positionOfInstruction, "instruction has too many operands")
							ELSE
								ParseOperand(operand, sectionList);
								IF ~error THEN
									IF Strict & ~IntermediateCode.CheckOperand(operand, opCode, operandNumber, message) THEN
										Strings.Append(message, " @ operand ");
										Strings.IntToStr(operandNumber + 1, tempString); Strings.Append(message, tempString);
										Error(positionOfOperand, message)
									END;
									operands[operandNumber] := operand;
									INC(operandNumber)
								END
							END
						UNTIL error OR ~ThisToken(Scanner.Comma);
						IF ~error & ExpectLineDelimiter() THEN END
					END;

					IF ~error THEN
						IntermediateCode.InitInstruction(instruction, positionOfInstruction, opCode, operands[0], operands[1], operands[2]);
						IF Strict & ~IntermediateCode.CheckInstruction(instruction, message) THEN
							Error(positionOfInstruction, message)
						END
					END
				END;

			END
		END ParseInstruction;

		(** parse the content of an intermediate code section
		note: 'sectionList' is the list where referenced sections are found/to be created
		**)
		PROCEDURE ParseSectionContent*(scanner: Scanner.AssemblerScanner; section: IntermediateCode.Section; sectionList: Sections.SectionList);
		VAR
			instruction: IntermediateCode.Instruction;
			lineNumber: LONGINT;
		BEGIN
			IF Trace THEN D.Ln; D.String(">>> ParseSectionContent"); D.Ln END;
			SELF.scanner := scanner;
			IgnoreNewLines;
			lineNumber := 0;
			WHILE ~error & (symbol.token # Scanner.Period) & (symbol.token # Scanner.EndOfText) DO
				(* consume optional line number *)
				ParseLineNumber(lineNumber);
				IF ~error THEN
					ParseInstruction(instruction, sectionList);
					IF ~error THEN
						IF Trace THEN IntermediateCode.DumpInstruction(D.Log, instruction); D.Ln; END;
						section.Emit(instruction);
						INC(lineNumber)
					END;
				END;
				IgnoreNewLines
			END
		END ParseSectionContent;

		(** parse a list of section properties **)
		PROCEDURE ParseSectionProperties(VAR section: IntermediateCode.Section);
		VAR
			positionOfProperty, integer: LONGINT;
		BEGIN
			IF Trace THEN D.Ln; D.String(">>> ParseSectionProperties"); D.Ln END;

			WHILE ~error & (symbol.token # Scanner.EndOfText) & (symbol.token # Scanner.Ln) DO
				positionOfProperty := symbol.start;

				(* fingerprint *)
				IF ThisIdentifier("fingerprint") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						IF (section.fingerprint # 0) & (section.fingerprint # integer) THEN
							Error(positionOfProperty, "incompatible fingerprint");
						ELSE
							section.SetFingerprint(integer);
						END
					ELSE
						Error(positionOfProperty, "invalid fingerprint")
					END

				(* position *)
				ELSIF ThisIdentifier("priority") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						section.SetPriority(SHORT(integer));
					ELSE
						Error(positionOfProperty," invalid priority")
					END;
				(* alignment *)
				ELSIF ThisIdentifier("aligned") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						section.SetPositionOrAlignment(FALSE, integer)
					ELSE
						Error(positionOfProperty, "invalid alignment")
					END

				(* fixed position *)
				ELSIF ThisIdentifier("fixed") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						section.SetPositionOrAlignment(TRUE, integer)
					ELSE
						Error(positionOfProperty, "invalid fixed postion")
					END

				(* unit size of the section in bits *)
				ELSIF ThisIdentifier("unit") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						section.SetBitsPerUnit(integer) (* overwrite default unit size *)
					ELSE
						Error(positionOfProperty, "invalid unit size")
					END

				(* total size of the section in units *)
				ELSIF ThisIdentifier("size") & ExpectToken(Scanner.Equal) THEN
					IF ExpectIntegerWithSign(integer) THEN
						 (* nothing to do (this property is ignored, since the size is calculated from the actual content) *)
					ELSE
						Error(positionOfProperty, "invalid size")
					END

				ELSE
					Error(positionOfProperty, "invalid property")
				END
			END
		END ParseSectionProperties;

		(** parse the content of an intermediate code module **)
		PROCEDURE ParseModuleContent*(scanner: Scanner.AssemblerScanner ; module: Sections.Module (* sectionList: Sections.SectionList; VAR moduleName: SyntaxTree.IdentifierString; VAR backend: Backend.Backend; loader: ModuleLoader*) ): BOOLEAN;
		VAR
			pos, positionOfDirective: LONGINT;
			identifier: Scanner.IdentifierString;
			afterModuleDirective, afterImportsDirective, afterFirstSection, isExternalSection: BOOLEAN;
			sectionType: SHORTINT;
			section: IntermediateCode.Section;
			name: Basic.SegmentedName;
			moduleName: SyntaxTree.IdentifierString;
		BEGIN
			IF Trace THEN D.Ln; D.String(">>> ParseModuleContent"); D.Ln END;

			moduleName := "";
			(*NEW(imports, 128);*)

			ASSERT(scanner # NIL);
			SELF.scanner := scanner;
			NextSymbol; (* read first symbol *)

			(* go through directives *)
			afterModuleDirective := FALSE;
			afterImportsDirective := FALSE;
			afterFirstSection := FALSE;
			IgnoreNewLines;
			WHILE ~error & (symbol.token # Scanner.EndOfText) DO
				positionOfDirective := symbol.start;
				IF ExpectToken(Scanner.Period) & ExpectAnyIdentifier(pos, identifier) THEN
					(* 'module' directive *)
					IF identifier = "module" THEN
						IF afterModuleDirective THEN
							Error(positionOfDirective, "multiple module directives");
						ELSIF ExpectAnyIdentifier(pos, identifier) & ExpectLineDelimiter() THEN
							moduleName := identifier;
							module.SetModuleName(identifier);
							afterModuleDirective := TRUE;
						END

					(* 'platform' directive *)
					ELSIF identifier = "platform" THEN
						IF ~afterModuleDirective THEN
							Error(positionOfDirective, "platform directive must be preceeded by module directive")
						ELSIF ExpectAnyIdentifier(pos, identifier) & ExpectLineDelimiter() THEN
							module.SetPlatformName(identifier);
							(*! check against used backend *)
						ELSIF afterFirstSection THEN
							Error(positionOfDirective, "platform directive not before all sections")
						END

					(* 'imports' directive *)
					ELSIF identifier = "imports" THEN
						IF ~afterModuleDirective THEN
							Error(positionOfDirective, "import directive must be preceeded by module directive")
						ELSIF afterImportsDirective THEN
							Error(positionOfDirective, "multiple import directives")
						ELSIF afterFirstSection THEN
							Error(positionOfDirective, "import directive not before all sections")
						ELSE
							REPEAT
								IF ExpectAnyIdentifier(positionOfDirective, identifier) THEN
									module.imports.AddName(identifier);
									(*
									IF ~loader(identifier) THEN Error(positionOfDirective, "could not import") END;
									*)
								END
							UNTIL error OR ~ThisToken(Scanner.Comma);
							IF ExpectLineDelimiter() THEN
								afterImportsDirective := TRUE
							END
						END

					(* section *)
					ELSE
						(* determine if section is external *)
						IF identifier = "external" THEN
							positionOfDirective := symbol.start;
							IF ExpectToken(Scanner.Period) & ExpectAnyIdentifier(pos, identifier) THEN END;
							isExternalSection := TRUE
						ELSE
							isExternalSection := FALSE
						END;

						IF  ~error THEN
							IF identifier = "code" THEN sectionType := Sections.CodeSection
							ELSIF identifier = "const" THEN sectionType := Sections.ConstSection
							ELSIF identifier = "var" THEN sectionType := Sections.VarSection
							ELSIF identifier = "bodycode" THEN sectionType := Sections.BodyCodeSection
							ELSIF identifier = "inlinecode" THEN sectionType := Sections.InlineCodeSection
							ELSIF identifier = "initcode" THEN sectionType := Sections.InitCodeSection
							ELSE Error(positionOfDirective, "invalid directive or section type")
							END;

							IF ~error & ~afterModuleDirective THEN
								Error(positionOfDirective, "module directive expected first")
							END;

							IF ~error THEN
								IF ExpectAnyIdentifier(pos, identifier) THEN
									Basic.ToSegmentedName(identifier, name);
									section := IntermediateCode.NewSection(module.allSections, sectionType, name, NIL, TRUE); (* keeps section if already present *)

									(* set default unit size for the platform, which depends on the section type *)
									IF (sectionType = Sections.VarSection) OR (sectionType = Sections.ConstSection) THEN
										section.SetBitsPerUnit(system.dataUnit)
									ELSE
										section.SetBitsPerUnit(system.codeUnit)
									END;
									ASSERT(section.bitsPerUnit # Sections.UnknownSize);

									(* consume optional section properties *)
									ParseSectionProperties(section);

									IF ~error & ExpectLineDelimiter() THEN
										ParseSectionContent(scanner, section, module.allSections);
										afterFirstSection := TRUE
									END
								END
							END

						END
					END
				END;
				IgnoreNewLines;
			END;
			RETURN ~error
		END ParseModuleContent;

		(** parse an entire intermediate code module **)
		PROCEDURE ParseModule*(system: Global.System): Sections.Module;
		VAR
			result: Sections.Module;
		BEGIN
			NEW(result, NIL, system); (* note: 1. there is no syntax tree module, 2. the system object to be used is not yet known *)
			IF ParseModuleContent(scanner, result (* result.allSections, moduleName, backend, loader *)) THEN
				IF Trace THEN
					D.String("++++++++++ PARSED MODULE '"); D.String(result.moduleName); D.String("' ++++++++++"); D.Ln;
					result.Dump(D.Log)
				END
			ELSE
				result := NIL
			END
		END ParseModule;
	END IntermediateCodeParser;

	PROCEDURE ParseReader*(reader: Streams.Reader; diagnostics: Diagnostics.Diagnostics; module: Sections.Module): BOOLEAN;
	VAR
		assemblerScanner: Scanner.AssemblerScanner;
		intermediateCodeParser: IntermediateCodeParser;
	BEGIN
		NEW(assemblerScanner, "", reader, 0, diagnostics);
		NEW(intermediateCodeParser, diagnostics, module.system);
		RETURN intermediateCodeParser.ParseModuleContent(assemblerScanner, module)
	END ParseReader;

	PROCEDURE ParseFile*(CONST pathName, moduleName: ARRAY OF CHAR; system: Global.System; diagnostics: Diagnostics.Diagnostics): Sections.Module;
	VAR
		filename: Files.FileName;
		assemblerScanner: Scanner.AssemblerScanner;
		intermediateCodeParser: IntermediateCodeParser;
		reader: Streams.Reader;
		msg: ARRAY 128 OF CHAR;
		module: Sections.Module;
	BEGIN
		(* open corresponding intermediate code file *)
		Files.JoinExtension(moduleName, IntermediateCodeExtension, filename);
		IF pathName # "" THEN Files.JoinPath(pathName, filename, filename) END;
		reader := Basic.GetFileReader(filename);
		IF Trace THEN D.String("FoxIntermediateCodeParser.ParseFile "); D.String(filename); D.Ln END;
		IF reader = NIL THEN
			msg := "failed to open ";
			Strings.Append(msg, filename);
			diagnostics.Error(filename, Diagnostics.Invalid, Diagnostics.Invalid, msg);
			RETURN NIL
		ELSE
			NEW(module, NIL, system);
			IF ParseReader(reader, diagnostics, module) THEN
				RETURN module
			ELSE
				RETURN NIL
			END;
		END;
	END ParseFile;


END FoxIntermediateParser.
