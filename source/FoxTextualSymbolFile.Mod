MODULE FoxTextualSymbolFile; (** AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Symbolfile in- and output"; *)
(* (c) fof ETH Zürich, 2008 *)

IMPORT
	D := Debugging, Basic := FoxBasic,  Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Formats := FoxFormats, Files,Streams,
	Printout := FoxPrintout,Parser:= FoxParser , SemanticChecker := FoxSemanticChecker, InterfaceComparison := FoxInterfaceComparison, Options, Diagnostics;

CONST Trace = FALSE;

TYPE
	TextualSymbolFile = OBJECT (Formats.SymbolFileFormat)
	VAR extension: Basic.FileName; noRedefinition, noModification: BOOLEAN;

		PROCEDURE Import(CONST moduleFileName: ARRAY OF CHAR; importCache: SyntaxTree.ModuleScope): SyntaxTree.Module;
		VAR fileName: Files.FileName; module: SyntaxTree.Module; reader: Streams.Reader; scanner: Scanner.Scanner; parser: Parser.Parser;
			checker: SemanticChecker.Checker;
		BEGIN
			Basic.Concat(fileName,path,moduleFileName,extension);
			IF Trace THEN D.Ln; D.Str("importing "); D.Str(fileName); D.Ln; D.Update;  END;
			reader := Basic.GetFileReader(fileName);
			scanner := Scanner.NewScanner(moduleFileName, reader, 0, diagnostics);
			IF ~scanner.error THEN
				parser := Parser.NewParser(scanner,NIL);
				module := parser.Module();
				IF parser.error THEN module := NIL END;
			END;

			IF (module # NIL) & ~(SyntaxTree.Resolved IN module.state) THEN
				(*! should rather be done by importer *)
				checker := SemanticChecker.NewChecker(NIL,FALSE,FALSE,TRUE,system,SELF,importCache);
				checker.Module(module); (* semantic check *)
				IF checker.error THEN module := NIL END;
			END;

			RETURN module
		END Import;

		PROCEDURE Export(module: SyntaxTree.Module; importCache: SyntaxTree.ModuleScope): BOOLEAN;
		VAR moduleName,fileName: Basic.FileName; writer: Files.Writer; file: Files.File; printer: Printout.Printer; result: BOOLEAN;flags: SET;
		BEGIN
			Global.ModuleFileName(module.name,module.context,moduleName);
			Basic.Concat(fileName,path,moduleName,extension);
			IF Trace THEN D.Ln; D.Str("exporting"); D.Str(fileName); D.Ln; D.Update;  END;

			file := Files.New(fileName);
			IF file = NIL THEN
				IF diagnostics # NIL THEN
					diagnostics.Error(module.sourceName, -1, -1, "could not open export file for writing");
				END;
				result := FALSE;
			ELSE

				flags := {};

				InterfaceComparison.CompareThis(module,SELF,diagnostics,importCache,flags);

				IF noRedefinition OR noModification THEN
					IF (InterfaceComparison.Redefined IN flags) THEN
						diagnostics.Error(module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," no redefinition of symbol file allowed");
						RETURN FALSE;
					END;
				END;
				IF noModification THEN
					IF (InterfaceComparison.Extended IN flags) THEN
						diagnostics.Error(module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," no extension of symbol file allowed");
						RETURN FALSE;
					END;
				END;

				NEW(writer,file,0);
				printer := Printout.NewPrinter(writer, Printout.SymbolFile,FALSE);
				printer.Module(module);
				writer.Update();
				Files.Register(file);
				result := TRUE;
			END;
			RETURN result
		END Export;

		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN
			options.Add(0X,"symbolFileExtension",Options.String);
			options.Add(0X,"noRedefinition",Options.Flag);
			options.Add(0X,"noModification",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		BEGIN
			IF ~options.GetString("symbolFileExtension",extension) THEN extension := ".Sym" END;
			noRedefinition := options.GetFlag("noRedefinition");
			noModification := options.GetFlag("noModification");
		END GetOptions;

	END TextualSymbolFile;

	PROCEDURE Get*(): Formats.SymbolFileFormat;
	VAR symbolFile: TextualSymbolFile;
	BEGIN
		NEW(symbolFile); RETURN symbolFile
	END Get;



END FoxTextualSymbolFile.


