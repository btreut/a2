MODULE PCTest;	(** AUTHOR "negelef"; PURPOSE "PaCo tester"; *)

IMPORT TestSuite, Diagnostics, Streams, PCS, PC, Commands, Modules,
	Strings, CompilerInterface, Texts, TextUtilities, Files;

TYPE
	Tester = OBJECT (TestSuite.Tester)

	VAR
		log: Streams.Writer;
		execute: BOOLEAN;
		options: ARRAY 100 OF CHAR;

	PROCEDURE &InitTester *(log: Streams.Writer; diagnostics: Diagnostics.Diagnostics; execute: BOOLEAN; CONST options: ARRAY OF CHAR);
	BEGIN Init (diagnostics); SELF.log := log; SELF.execute := execute; COPY (options, SELF.options);
	END InitTester;

	PROCEDURE Handle (r: Streams.Reader; pos: LONGINT; CONST name: ARRAY OF CHAR; type: TestSuite.TestType): INTEGER;
	CONST ModuleName = "Test";
	VAR result: INTEGER; error: BOOLEAN; msg: ARRAY 128 OF CHAR; res: LONGINT;
	BEGIN
		result := TestSuite.Failure;
		log.String ("testing: "); log.String (name); log.Ln;
		PC.Module (PCS.InitWithReader (r, 1000, pos), name, options, -1, log, diagnostics, error);
		IF ~error THEN
			IF execute THEN
				Modules.FreeModule (ModuleName, res, msg);
				result := TestSuite.Negative;
				IF Modules.ThisModule (ModuleName, res, msg) # NIL THEN END;
			END;
			result := TestSuite.Positive;
		ELSIF ~execute THEN
			result := TestSuite.Negative;
		END;
	FINALLY
		RETURN result;
	END Handle;

	END Tester;

PROCEDURE DriveTest (context: Commands.Context; execute: BOOLEAN);
VAR diagnostics: Diagnostics.StreamDiagnostics; tester: Tester; report: TestSuite.StreamReport;
BEGIN
	NEW (diagnostics, context.out);
	NEW (tester, context.out, diagnostics, execute, "\s");
	NEW (report, context.out);
	TestSuite.Drive (context, tester);
	tester.Print (report);
END DriveTest;

PROCEDURE Compile* (context: Commands.Context);
BEGIN DriveTest (context, FALSE);
END Compile;

PROCEDURE Execute* (context: Commands.Context);
BEGIN DriveTest (context, TRUE);
END Execute;

(* Interface with PET *)

PROCEDURE DriveTextTests(
	reader: Streams.Reader;
	CONST regrfile: ARRAY OF CHAR;
	execute: BOOLEAN;
	log: Streams.Writer;
	diagnostics: Diagnostics.Diagnostics);
VAR
	tester: Tester; report: TestSuite.StreamReport;
BEGIN
	NEW(tester, log, diagnostics, execute, "\s");
	NEW(report, log);
	TestSuite.DriveByReader(reader, log, regrfile, tester);
	tester.Print(report);
END DriveTextTests;

PROCEDURE ParseTests(
	text : Texts.Text;
	CONST source: ARRAY OF CHAR;
	VAR regrfile: ARRAY OF CHAR;
	VAR r: Streams.Reader;
	diagnostics: Diagnostics.Diagnostics): BOOLEAN;
VAR
	buffer : POINTER TO ARRAY OF CHAR;
	length, pos1, pos2: LONGINT;
	regrbuf: ARRAY Files.PrefixLength+Files.NameLength+20 OF CHAR;
	reader: Streams.StringReader;
BEGIN
	regrfile := "";

	ASSERT((text # NIL) & (diagnostics # NIL));
	text.AcquireRead;
	length := text.GetLength();
	text.ReleaseRead;
	IF length = 0 THEN length := 1 END;
	NEW(buffer, length);
	TextUtilities.TextToStr(text, buffer^);
	(* prepare the reader *)
	NEW(reader, LEN(buffer)); reader.SetRaw(buffer^, 0, LEN(buffer));
	r := reader;

	(* Determine the regression test file *)
	pos1 := 0; pos2 := -1;
	pos1 := Strings.Find(buffer^, 0, "$");
	IF pos1 # -1 THEN
		INC(pos1);
		pos2 := Strings.Find(buffer^, pos1, "$");
	END;
	NEW(reader, LEN(regrbuf));
	WHILE (pos2 # -1) & (regrfile = "") DO
		reader.SetRaw(buffer^, pos1, pos2-pos1);
		reader.SkipWhitespace; reader.String(regrbuf);
		Strings.LowerCase(regrbuf);
		IF Strings.StartsWith2("regression", regrbuf) THEN
			reader.SkipWhitespace; reader.String(regrfile);
		END;

		(* prepare for next iteration *)
		pos1 := pos2;
		INC(pos1);
		pos2 := Strings.Find(buffer^, pos1, "$");
	END;

	ASSERT(r.Pos() = 0);
	RETURN TRUE; (* no checks yet *)
END ParseTests;

PROCEDURE ParseOptions(
	CONST options: ARRAY OF CHAR;
	VAR execute, regression: BOOLEAN;
	CONST regrfile: ARRAY OF CHAR);
VAR
	r: Streams.StringReader;
	opt: ARRAY 20 OF CHAR;
BEGIN
	(* Default values *)
	execute := FALSE;
	regression := FALSE;

	NEW(r, LEN(options));
	r.SetRaw(options, 0, LEN(options));
	WHILE r.res = Streams.Ok DO
		r.SkipWhitespace; r.String(opt);
		IF opt = "\e" THEN execute := TRUE;
		ELSIF opt = "\r" THEN regression := TRUE;
		END;
	END;
END ParseOptions;

PROCEDURE RunTests(
	text : Texts.Text;
	CONST source: ARRAY OF CHAR;
	pos: LONGINT; (* ignore *)
	CONST pc,opt: ARRAY OF CHAR;
	log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	execute, regression: BOOLEAN;
	regrfile: Files.FileName;
	reader: Streams.Reader;
BEGIN
	ASSERT((text # NIL) & (diagnostics # NIL));
	error := ~ParseTests(text, source, regrfile, reader, diagnostics);
	IF ~error THEN
		ParseOptions(opt, execute, regression, regrfile);
		IF ~regression THEN
			regrfile := "";
		END;
		DriveTextTests(reader, regrfile, execute, log, diagnostics);
	END;
	IF error THEN
		log.String(" not done");
	ELSE
		log.String(" done");
	END;
	IF (regrfile = "") & regression THEN
		log.Ln; log.Ln;
		log.String("Warning: Couldn't do regression because there was no file specified!"); log.Ln;
		log.String("Put somewhere in the test file a line like '# $Regression: regressionFileName$'"); log.Ln;
	END;
	log.Update;
END RunTests;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister("TestTool");
END Cleanup;

BEGIN
	CompilerInterface.Register("TestTool", "Run test cases against PC compiler", "Test", RunTests);
	Modules.InstallTermHandler(Cleanup);
END PCTest.

SystemTools.Free PCTest TestSuite~
WMUtilities.Call PCTest.Compile Oberon.Compilation.Test ~	 Verbose testing mode
WMUtilities.Call PCTest.Compile Oberon.Compilation.Test Oberon.Compilation.tmp ~ Regression testing mode
WMUtilities.Call PCTest.Execute Oberon.Execution.Test ~	 Verbose testing mode
WMUtilities.Call PCTest.Execute Oberon.Execution.Test Oberon.Execution.tmp ~ Regression testing mode
