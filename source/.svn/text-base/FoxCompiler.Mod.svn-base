MODULE Compiler;   (**  AUTHOR "fof & fn"; PURPOSE "Oberon Compiler Command Interface";  **)
(* (c) fof ETH Zürich, 2008 *)

IMPORT
	Basic := FoxBasic, Scanner := FoxScanner, Parser := FoxParser,
	SemanticChecker := FoxSemanticChecker, SyntaxTree := FoxSyntaxTree, Formats := FoxFormats,
	Streams, Commands,Diagnostics, Options, Kernel, Printout := FoxPrintout, Backend := FoxBackend,Strings, Global := FoxGlobal,
	Frontend := FoxFrontend,	Files;

CONST
	(* flags *)
	Print* = 0;
	Silent* = 1;
	Check* = 2;
	TraceError* = 3;
	Info* = 4;
	FindPC* = 5;
	ActiveCellsFlag*=6;
	Warnings*=7;
	ForceModuleBodies*=8;
	UseDarwinCCalls*=9;	(* use Darwin stack alignment for ext. C procedures *)	(*fld*)
	SingleModule*=10;
	Oberon07*=11;
	ChangeCase*=12;
	Cooperative*=13;
	CellsAreObjects*=14;

	DefaultBackend = "AMD";
	DefaultFrontend = "Oberon";

TYPE
	SectionName = ARRAY 256 OF CHAR; (*! move *)

	CompilerOptions*= RECORD
		flags*: SET;
		frontend*: Frontend.Frontend;
		backend*: Backend.Backend;
		symbolFile*: Formats.SymbolFileFormat;
		objectFile*: Formats.ObjectFileFormat;
		findPC*: SectionName;
		documentation*: Backend.Backend;
		srcPath, destPath: Files.FileName;
		replacements: SemanticChecker.Replacement;
	END;

	PROCEDURE ParseReplacements(CONST filename: ARRAY OF CHAR; VAR replacement: SemanticChecker.Replacement; diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR reader: Streams.Reader; r: SemanticChecker.Replacement;
		identifier: SyntaxTree.QualifiedIdentifier;
		scanner: Scanner.Scanner; parser: Parser.Parser; expression: SyntaxTree.Expression;
	BEGIN
		replacement := NIL;
		reader := Basic.GetFileReader(filename);
		IF reader = NIL THEN
			diagnostics.Error (filename, Diagnostics.Invalid, Diagnostics.Invalid, "failed to open");
		ELSE

			NEW(scanner, filename, reader,0, diagnostics);
			NEW(parser, scanner, diagnostics);

			REPEAT (* WHILE parser.Peek(Scanner.Identifier) DO*)
				identifier := parser.QualifiedIdentifier();
				IF parser.Mandatory(Scanner.Equal) THEN
					expression := parser.Expression();
					NEW(r); identifier.GetName(r.name);  r.expression := expression; r.used := FALSE;
					r.next := replacement; replacement := r;
				END;
				WHILE parser.Optional(Scanner.Semicolon) DO END;
			UNTIL ~parser.Peek(Scanner.Identifier); (*END;*)

		END;
		(*done := FALSE;
		WHILE reader.GetString(name) & ~done DO
			IF reader.GetChar(equal) & (equal = "=") & reader.GetString(value) THEN
				NEW(r); r.name := name; r.string := Strings.NewString(value); r.used := FALSE;
				r.next := replacement; replacement := r;
			ELSE done := TRUE;
			END;
		END;
		*)
		RETURN (replacement # NIL)
	END ParseReplacements;


	PROCEDURE Modules*(CONST source: ARRAY OF CHAR; (* source file name, for debugging and better error reports *)
			reader: Streams.Reader; (* reader to read from *)
			position: LONGINT; (* starting position in reader *)
			diagnostics: Diagnostics.Diagnostics; (* error output and status report *)
			log: Streams.Writer;
			CONST options: CompilerOptions;
			VAR importCache: SyntaxTree.ModuleScope): BOOLEAN;
	VAR
		module: SyntaxTree.Module;
		checker: SemanticChecker.Checker;
		warnings: SemanticChecker.Warnings;
		printer: Printout.Printer;
		system: Global.System;
		generatedModule: Formats.GeneratedModule;
		name: SyntaxTree.IdentifierString;
		split: Strings.StringArray;
		sectionOffset: LONGINT;
		flags: SET;

		PROCEDURE FinalMessage(error: BOOLEAN; CONST msg: ARRAY OF CHAR);
		VAR message,name: ARRAY 256 OF CHAR;
		BEGIN
			message := "";
			IF (module # NIL) & (module.context # SyntaxTree.invalidIdentifier) THEN
				Basic.GetString(module.context,message);
				Strings.Append (message, ".");
			ELSE
				message := "";
			END;
			IF (module # NIL) & (module.name # SyntaxTree.invalidIdentifier) THEN
				Basic.GetString(module.name,name);
				Strings.Append (message, name);
			END;
			Strings.Append (message, msg);
			IF error THEN
				IF diagnostics # NIL THEN
					diagnostics.Error (source, Diagnostics.Invalid, Diagnostics.Invalid, message);
				END;
			ELSE
				IF (log # NIL) & ~(Silent IN options.flags) & ~(FindPC IN options.flags) THEN
					log.String("compiling ");
					IF source # "" THEN 	log.String(source); log.String(" => ");	END;
					log.String(message); log.Ln;
					log.Update;
				END;
			END;
		END FinalMessage;

		PROCEDURE PrintModule;
		VAR print: Streams.Writer;
		BEGIN
			print := Basic.GetWriter(Basic.GetDebugWriter("Compiler Debug Output"));
			IF Info IN options.flags THEN
				printer := Printout.NewPrinter(print,Printout.All,Info IN options.flags);
			ELSE
				printer := Printout.NewPrinter(print,Printout.SourceCode,Info IN options.flags);
			END;
			print.Ln; printer.Module(module); print.Ln;
			print.Update;
		END PrintModule;


	BEGIN
		flags := options.flags;
		IF options.findPC # "" THEN EXCL(flags, Warnings) END;
		IF TraceError IN options.flags THEN
			diagnostics := Basic.GetTracingDiagnostics(diagnostics)
		END;

		IF options.backend = NIL THEN
			system := Global.DefaultSystem()
		ELSE
			IF Oberon07 IN options.flags THEN options.backend.SetOberon07 END; (* inform the backend about that the Oberon07 mode, it will return the corresponding Sytem object *)
			system := options.backend.GetSystem();
		END;

		system.SetCellsAreObjects(CellsAreObjects IN flags);

		IF (options.objectFile # NIL) & (options.objectFile.ForceModuleBodies()) THEN INCL(flags, ForceModuleBodies) END;

		options.frontend.Initialize(diagnostics, reader, source, position, ActiveCellsFlag IN flags);
		REPEAT
			(** first phase: scan and parse **)
			module := options.frontend.Parse();
			IF options.frontend.Error() THEN 
				FinalMessage(TRUE," could not be compiled (parser errors).");
				RETURN FALSE;
			END;
			ASSERT(module # NIL);

			IF Check IN flags THEN
				(** second phase: check and resolve symbols **)
				IF (options.symbolFile # NIL) THEN
					options.symbolFile.Initialize(diagnostics,system,options.destPath);
				END;
				checker := SemanticChecker.NewChecker(diagnostics,Info IN flags,UseDarwinCCalls IN flags,Cooperative IN flags,system,options.symbolFile,importCache);
				checker.replacements := options.replacements;
				checker.Module(module);
				IF checker.error THEN
					FinalMessage(TRUE," could not be compiled (checker errors).");
					RETURN FALSE
				ELSIF Warnings IN flags THEN
					warnings := SemanticChecker.NewWarnings(diagnostics);
					warnings.Module(module);
				END;

				IF Print IN flags THEN
					IF ChangeCase IN flags THEN module.SetCase(1-module.case) END;
					PrintModule;
					IF ChangeCase IN flags THEN module.SetCase(1-module.case) END;
				END;

				IF (ActiveCellsFlag IN flags) & ~(CellsAreObjects IN flags) THEN
					Global.GetSymbolName(module,name);
				END;

				(** third phase: generate code, can consist of sub-phases (such as intermediate backend / hardware backend) **)
				IF options.backend # NIL THEN
					options.backend.Initialize(diagnostics, log, flags, checker, system);
					IF options.findPC # "" THEN
						split := Strings.Split(options.findPC,":");
						IF LEN(split)>1 THEN
							Strings.StrToInt(split[1]^,sectionOffset);
							options.backend.FindPC(module, split[0]^,sectionOffset);
							IF options.backend.error THEN
								FinalMessage(TRUE," could not be compiled (backend errors).");
								RETURN FALSE
							ELSE
								RETURN TRUE
							END;
						END;
					END;
					generatedModule := options.backend.ProcessSyntaxTreeModule(module);
					IF options.backend.error THEN
						FinalMessage(TRUE, " could not be compiled (backend errors).");
						RETURN FALSE
					END;
				END;


				(** generate symbol file **)
				IF (options.symbolFile # NIL) & ~options.symbolFile.Export(module, importCache) THEN
					FinalMessage(TRUE, " could not be compiled (symbol File errors).");
					RETURN FALSE
				END;

				(** generate object file **)
				IF options.objectFile # NIL THEN
					options.objectFile.Initialize(diagnostics);
					options.objectFile.SetPath(options.destPath);

					IF options.findPC # "" THEN
						Strings.StrToInt(options.findPC, sectionOffset);
						generatedModule.SetFindPC(sectionOffset);
					END;

					IF generatedModule = NIL THEN
						FinalMessage(TRUE, " could not write object file (nothing generated).");
						RETURN FALSE
					ELSIF ~options.objectFile.Export(generatedModule,options.symbolFile) THEN
						FinalMessage(TRUE, " could not be compiled (object file errors).");
						RETURN FALSE
					END;
				END;



				IF options.documentation # NIL THEN
					options.documentation.Initialize(diagnostics,log, flags,checker,system);
					generatedModule := options.documentation.ProcessSyntaxTreeModule(module);
				END;

				FinalMessage(FALSE, " done.");
			ELSIF Print IN flags THEN
				IF  ChangeCase IN flags THEN module.SetCase(1-module.case) END;
				PrintModule;
				FinalMessage(FALSE, " done.")
			ELSE
				FinalMessage(FALSE, " done.");
			END;
		UNTIL (SingleModule IN flags) OR options.frontend.Done();


		RETURN TRUE;
	END Modules;
	

	
	PROCEDURE GetDefaults(CONST name: ARRAY OF CHAR): Streams.Reader;
	VAR s: Streams.StringReader; platform: Platform;
	BEGIN
		s := NIL;
		platform := GetPlatform(name);
		IF platform # NIL THEN
			NEW(s, LEN(platform.defaults));
			s.Set(platform.defaults);
		END;
		RETURN s;
	END GetDefaults;
	

	PROCEDURE GetOptions*(input: Streams.Reader; error:Streams.Writer; diagnostics: Diagnostics.Diagnostics;
		VAR compilerOptions: CompilerOptions): BOOLEAN;
	VAR options: Options.Options;  name: ARRAY 256 OF CHAR; result: BOOLEAN; position: LONGINT;
	defaults: Streams.Reader;
		parsed: BOOLEAN;

		PROCEDURE Error(CONST error: ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Error("",Diagnostics.Invalid,Diagnostics.Invalid,error);
			END;
		END Error;

	BEGIN
		result := TRUE;
		NEW(options);
		
		options.Add("p","platform",Options.String);
		options.Add(0X,"showOptions",Options.Flag);
		
		options.Add(0X,"print",Options.Flag);
		options.Add(0X,"Print",Options.Flag);
		options.Add(0X,"silent",Options.Flag);
		options.Add("c","check",Options.Flag);
		options.Add("e","traceError",Options.Flag);
		options.Add("I","interface",Options.Flag);
		options.Add("i","info",Options.Flag);
		options.Add(0X,"oberon07",Options.Flag);
		options.Add("b","backend",Options.String);
		options.Add("F","frontEnd",Options.String);
		options.Add("f","findPC",Options.String);
		options.Add(0X,"singleModule",Options.Flag);
		options.Add(0X, "symbolFile", Options.String);
		options.Add(0X, "objectFile", Options.String);
		options.Add(0X,"activeCells", Options.Flag);
		options.Add("w","warnings", Options.Flag);
		options.Add(0X,"darwinHost", Options.Flag);
		options.Add(0X,"hardware", Options.String);
		options.Add("d","documentation", Options.String);
		options.Add("S","srcPath", Options.String);
		options.Add("D","destPath", Options.String);
		options.Add(0X,"replacements", Options.String);
		options.Add(0X,"cooperative", Options.Flag);

		position := input.Pos();
		parsed := options.Parse(input,NIL);
		IF options.GetString("platform", name) THEN
			defaults := GetDefaults(name);
			IF defaults = NIL THEN 	
				error.String("Unknown platform"); error.Ln 
			ELSE
				parsed := options.Parse(defaults, NIL) & parsed;
				input.SetPos(position);
				parsed := options.Parse(input, NIL) & parsed; (* reparse overwrites *)
			END;
		ELSE 
			defaults := NIL;
		END;

		IF options.GetString("b", name) THEN
			IF name = "" THEN compilerOptions.backend := NIL
			ELSE
				compilerOptions.backend := Backend.GetBackendByName(name);
				IF (compilerOptions.backend = NIL)  THEN
					Error("backend could not be installed"); result := FALSE;
				END;
			END;
		ELSE compilerOptions.backend := Backend.GetBackendByName(DefaultBackend);
			IF compilerOptions.backend = NIL THEN Error("default backend could not be installed"); result := FALSE END;
		END;
		
		IF options.GetString("F", name) THEN
			IF name = "" THEN compilerOptions.frontend := NIL
			ELSE
				compilerOptions.frontend := Frontend.GetFrontendByName(name);
				IF (compilerOptions.frontend = NIL)  THEN
					Error("backend could not be installed"); result := FALSE;
				END;
			END;
		ELSE compilerOptions.frontend := Frontend.GetFrontendByName(DefaultFrontend);
			IF compilerOptions.frontend = NIL THEN Error("default frontend could not be installed"); result := FALSE END;
		END;

		IF options.GetString("objectFile",name) THEN
			IF name = "" THEN compilerOptions.objectFile := NIL
			ELSE
				compilerOptions.objectFile := Formats.GetObjectFileFormat(name);
				IF compilerOptions.objectFile = NIL THEN Error("object file format could not be installed"); result := FALSE END;
			END;
		ELSIF compilerOptions.backend # NIL THEN
			compilerOptions.objectFile := compilerOptions.backend.DefaultObjectFileFormat();
		END;

		IF options.GetString("symbolFile",name) THEN
			IF name = "" THEN compilerOptions.symbolFile := NIL
			ELSE
				compilerOptions.symbolFile := Formats.GetSymbolFileFormat(name);
				IF compilerOptions.symbolFile = NIL THEN Error("symbol file format could not be installed"); result := FALSE END;
			END;
		ELSIF compilerOptions.backend # NIL THEN
			compilerOptions.symbolFile := compilerOptions.backend.DefaultSymbolFileFormat();
			IF (compilerOptions.symbolFile = NIL) & (compilerOptions.objectFile # NIL) THEN
				compilerOptions.symbolFile := compilerOptions.objectFile.DefaultSymbolFileFormat();
			END;
		ELSIF compilerOptions.objectFile # NIL THEN
			compilerOptions.symbolFile := compilerOptions.objectFile.DefaultSymbolFileFormat();
		END;


		IF options.GetString("d", name) THEN
			compilerOptions.documentation := Backend.GetBackendByName("Documentation");
			IF (compilerOptions.documentation = NIL)  THEN
				Error("documentation engine could not be installed"); result := FALSE;
			END;
		ELSE
			compilerOptions.documentation := NIL
		END;

		IF options.GetString("replacements", name) THEN
			IF ~ParseReplacements(name, compilerOptions.replacements, diagnostics) THEN
				Error("replacement file could not be opened or is empty"); result := FALSE;
			END;
		ELSE compilerOptions.replacements := NIL
		END;


		IF compilerOptions.backend # NIL THEN compilerOptions.backend.DefineOptions (options); INCL(compilerOptions.flags,Check); END;
		IF compilerOptions.symbolFile # NIL THEN compilerOptions.symbolFile.DefineOptions(options); INCL(compilerOptions.flags,Check) END;
		IF compilerOptions.objectFile # NIL THEN compilerOptions.objectFile.DefineOptions(options); INCL(compilerOptions.flags,Check) END;
		IF compilerOptions.documentation # NIL THEN compilerOptions.documentation.DefineOptions(options) END;

		IF result & ~parsed THEN
			options.Clear;
			IF defaults # NIL THEN
				defaults.SetPos(0);
				parsed := options.Parse(defaults, error);
			END;
			input.SetPos(position);
			result := options.Parse(input,error)
		END;

		IF result THEN
			IF options.GetFlag("print") THEN INCL(compilerOptions.flags, Print) END;
			IF options.GetFlag("Print") THEN INCL(compilerOptions.flags, Print); INCL(compilerOptions.flags, ChangeCase) END;
			IF options.GetFlag("silent") THEN INCL(compilerOptions.flags, Silent) END;
			IF options.GetFlag("check") THEN INCL(compilerOptions.flags, Check) END;
			IF options.GetFlag("traceError") THEN INCL(compilerOptions.flags, TraceError) END;
			IF options.GetFlag("info") THEN INCL(compilerOptions.flags,Info) END;
			IF options.GetString("findPC",compilerOptions.findPC) THEN INCL(compilerOptions.flags,FindPC) END;
			IF options.GetFlag("warnings") THEN INCL(compilerOptions.flags, Warnings) END;
			IF options.GetFlag("darwinHost") THEN INCL(compilerOptions.flags,UseDarwinCCalls) END;	(*fld*)
			IF options.GetFlag("singleModule") THEN INCL(compilerOptions.flags,SingleModule) END;
			IF options.GetFlag("oberon07") THEN INCL(compilerOptions.flags, Oberon07) END;
			IF options.GetFlag("activeCells") THEN INCL(compilerOptions.flags, ActiveCellsFlag) END;
			IF options.GetFlag("cooperative") THEN INCL(compilerOptions.flags, Cooperative) END;
			IF options.GetFlag("cellsAreObjects") THEN INCL(compilerOptions.flags, CellsAreObjects) END;
			IF ~options.GetString("srcPath", compilerOptions.srcPath) THEN compilerOptions.srcPath := "" END;
			IF ~options.GetString("destPath", compilerOptions.destPath) THEN compilerOptions.destPath := "" END;
			IF compilerOptions.backend # NIL THEN compilerOptions.backend.GetOptions (options) END;
			IF compilerOptions.symbolFile # NIL THEN compilerOptions.symbolFile.GetOptions(options) END;
			IF compilerOptions.objectFile # NIL THEN compilerOptions.objectFile.GetOptions(options) END;
			IF compilerOptions.documentation # NIL THEN compilerOptions.documentation.GetOptions(options) END;
		END;
		
		IF options.GetFlag("showOptions") THEN options.Show(error) END;
		RETURN result
	END GetOptions;


	PROCEDURE Compile*(context : Commands.Context);
	VAR
		filename, path, file: Files.FileName;
		error: BOOLEAN;
		diagnostics: Diagnostics.Diagnostics;
		time: LONGINT; reader: Streams.Reader;
		importCache: SyntaxTree.ModuleScope;
		options: CompilerOptions;
		replacement: SemanticChecker.Replacement;
		name: ARRAY 128 OF CHAR;
	BEGIN
		error := FALSE;

		diagnostics := Basic.GetDiagnostics(context.error);
		IF GetOptions(context.arg,context.error,diagnostics,options) THEN

			time := Kernel.GetTicks();
			WHILE Basic.GetStringParameter(context.arg,filename) & ~error DO
				IF options.srcPath # "" THEN
					Files.SplitPath(filename, path, file);
					IF path = "" THEN Files.JoinPath(options.srcPath, file, filename) END;
				END;
				reader := Basic.GetFileReader(filename);

				IF reader = NIL THEN
					diagnostics.Error (filename, Diagnostics.Invalid, Diagnostics.Invalid, "failed to open"); error := TRUE;
				ELSE
					error := ~Modules(filename, reader, 0, diagnostics,context.out, options,  importCache);
				END;
				context.out.Update;
				context.error.Update;
			END;
			IF Silent IN options.flags THEN
				time := Kernel.GetTicks()-time;
				context.out.Ln; context.out.String("compiler elapsed ms"); context.out.Int(time,10);
			END;
			IF ~error THEN
				replacement := options.replacements;
				WHILE replacement # NIL DO
					IF ~replacement.used THEN
						name := replacement.name;
						diagnostics.Warning(name,  Diagnostics.Invalid, Diagnostics.Invalid, " unused replacement.");
					END;
					replacement := replacement.next;
				END;
			END;
		END;
		IF error THEN context.result := -1 ELSE context.result := Commands.Ok END;

	END Compile;

	PROCEDURE CompileReader*(context: Commands.Context; reader: Streams.Reader);
	VAR
		filename: ARRAY 256 OF CHAR;
		error: BOOLEAN;
		diagnostics: Diagnostics.Diagnostics;
		importCache: SyntaxTree.ModuleScope;
		options: CompilerOptions;
	BEGIN
		error := FALSE;
		diagnostics := Basic.GetDiagnostics(context.error);
		IF GetOptions(context.arg,context.error,diagnostics,options) THEN

			IF reader = NIL THEN
				diagnostics.Error (filename, Diagnostics.Invalid, Diagnostics.Invalid, "failed to open"); error := TRUE;
			ELSE
				error := ~Modules(filename, reader, 0, diagnostics, context.out, options, importCache);
			END;
			context.out.Update;
		END;
	END CompileReader;
	
	TYPE 
	Platform = POINTER TO RECORD
		name: ARRAY 32 OF CHAR;
		defaults: ARRAY 256 OF CHAR;
	END;
	
	Platforms = OBJECT(Basic.List)
		PROCEDURE GetPlatform(i: LONGINT): Platform;
		BEGIN
			RETURN Get(i)(Platform);
		END GetPlatform;
	END Platforms;
	
	VAR platforms: Platforms;
	
	PROCEDURE AddPlatform(CONST name: ARRAY OF CHAR; CONST defaults: ARRAY OF CHAR);
	VAR i: LONGINT; platform: Platform;
	BEGIN
		platform := GetPlatform(name);
		IF platform = NIL THEN 
			NEW(platform);
			COPY(name, platform.name);
			platforms.Add(platform);
		END;
		COPY(defaults, platform.defaults);
	END AddPlatform;
	
	PROCEDURE GetPlatform(CONST name: ARRAY OF CHAR): Platform;
	VAR i: LONGINT; platform: Platform;
	BEGIN
		FOR i := 0 TO platforms.Length()-1 DO
			platform := platforms.GetPlatform(i);
			IF platform.name = name THEN
				RETURN platform
			END;
		END;
		RETURN  NIL;
	END GetPlatform;

BEGIN
	NEW(platforms,8);
	(* platform definitions hard coded for the common cases -- maybe (parts of it) should be outsourced to a file ?*)
	AddPlatform("Win32","-b=AMD --objectFile=Binary --symbolFile=Binary --objectFileExtensions=.Obw --symbolFileExtension=.Obw");
	AddPlatform("Win32G","-b=AMD --objectFile=Generic --symbolFile=Textual --newObjectFile --mergeSections --objectFileExtension=.GofW --symbolFileExtension=.SymW");
	AddPlatform("Minos","-b=ARM --objectFile=Generic --newObjectFile --metaData=simple --objectFileExtension=.Goa --symbolFileExtension=.Sya");
	AddPlatform("TRM","-b=TRM --objectFile=Generic --newObjectFile --metaData=simple --objectFileExtension=.GofT --symbolFileExtension=.SymT");
	AddPlatform("TRMI","-b=TRM --objectFile=Intermediate --newObjectFile --metaData=simple --objectFileExtension=.IroT --symbolFileExtension=.IrsT");
	AddPlatform("A2","-b=AMD --objectFile=Binary --objectFileExtension=.Obx --symbolFileExtension=.Obx");
	AddPlatform("A2G","-b=AMD --objectFile=Generic --newObjectFile --mergeSections --objectFileExtension=.GofG --symbolFileExtension=.SymG");
	AddPlatform("A2Coop","-b=AMD --cooperative --objectFile=Generic --newObjectFile --traceModule=Trace --mergeSections");
END Compiler.
