MODULE FoxTest;	(** AUTHOR "fof"; PURPOSE "Fox tester"; *)
(* (c) fof ETH Zürich, 2008 *)

IMPORT Basic := FoxBasic, TestSuite, Diagnostics, Streams, Commands, Shell, Options, Files, Strings, Versioning, CompilerInterface, Texts, TextUtilities, Modules;

TYPE
	Command = ARRAY 256 OF CHAR;

	Tester = OBJECT (TestSuite.Tester)
	VAR
		log: Streams.Writer;
		fileLog: Streams.Writer;

		mayTrap: BOOLEAN;
		command, prolog, epilog: Command;
		fileName: Files.FileName;

		PROCEDURE &InitTester (log, logFileWriter: Streams.Writer;  diagnostics: Diagnostics.Diagnostics; mayTrap: BOOLEAN; CONST prolog, command, epilog: Command; CONST fileName: ARRAY OF CHAR);
		BEGIN
			Init (diagnostics); SELF.log := log; SELF.mayTrap := mayTrap; SELF.fileLog := logFileWriter;
			COPY(prolog, SELF.prolog);
			COPY(epilog, SELF.epilog);
			COPY(command, SELF.command);
			COPY(fileName, SELF.fileName);
		END InitTester;

		PROCEDURE Handle (r: Streams.Reader; position: LONGINT; CONST name: ARRAY OF CHAR; type: TestSuite.TestType): INTEGER;
		VAR result: INTEGER; msg: ARRAY 128 OF CHAR; res: LONGINT; f: Files.File; w: Files.Writer; ch: CHAR;
		BEGIN
			result := TestSuite.Failure;
			IF log # NIL THEN log.String ("testing: "); log.String (name); log.String("@"); log.Int(position,0); log.Ln END;

			(* prepare tester input as a file for all test cases *)
			f := Files.New(fileName);
			NEW(w,f,0);
			WHILE r.Available() > 0 DO
				r.Char(ch); w.Char(ch)
			END;
			w.Update;
			Files.Register(f);

			res := Commands.Ok;
			IF prolog # "" THEN
				Commands.Call(prolog, {Commands.Wait}, res, msg);
				IF (res # Commands.Ok) & (log # NIL)  THEN
					log.String("prolog failed: "); log.String(msg); log.Ln;
				END;
			END;

			IF (command # "") & (res = Commands.Ok) THEN
				Commands.Call(command, {Commands.Wait}, res, msg);
				IF res = Commands.Ok THEN
					result := TestSuite.Positive
				ELSIF (res < 3500) & (res >= 3440) THEN (* loader error *)
					result := TestSuite.Failure
				ELSIF ~mayTrap & (res = Commands.CommandTrapped) THEN (* command error, trap *)
					result := TestSuite.Failure
				ELSE
					result := TestSuite.Negative
				END;
				IF (result # type) & (log # NIL) THEN
					log.String (msg); log.Ln;
				END;
			ELSIF (command # "") THEN result := TestSuite.Failure
			END;

			IF epilog # "" THEN
				Commands.Call(epilog, {Commands.Wait}, res, msg);
			END;

			IF fileLog # NIL THEN
				IF result = type THEN
					fileLog.String("success: ")
				ELSE
					fileLog.String("failure: ")
				END;
				fileLog.String(name); fileLog.Ln;
			END;
		FINALLY
			RETURN result;
		END Handle;

	END Tester;

	PROCEDURE GetOptions(): Options.Options;
	VAR options: Options.Options;
	BEGIN
		NEW(options);
		options.Add("p","prolog", Options.String);
		options.Add("e","epilog", Options.String);
		options.Add("c","command", Options.String);
		options.Add("v","verbose",Options.Flag);
		options.Add("t","mayTrap",Options.Flag);
		options.Add("f","fileName",Options.String);
		options.Add("l","logFile",Options.String);
		options.Add("r","result",Options.String);
		RETURN options
	END GetOptions;

	PROCEDURE DriveTest (options: Options.Options; diagnostics: Diagnostics.Diagnostics; reader: Streams.Reader; error, writer: Streams.Writer);
	VAR
		tester: Tester; prolog, epilog, command: Command;
		verbose, mayTrap: BOOLEAN; report: TestSuite.StreamReport; fileName, logFileName: Files.FileName; logFileWriter, log:Streams.Writer;
		testname, resultname: Files.FileName;
		baseOptions: Options.Options; ch: CHAR; string: ARRAY 256 OF CHAR; stringReader: Streams.StringReader;
	BEGIN
		reader.SetPos(0);
		WHILE reader.Available() >0 DO
			reader.SkipWhitespace;
			reader.Char(ch);
			IF (ch = "#") THEN
				IF reader.GetString(string) & Strings.StartsWith("options",0,string) THEN
					reader.Ln(string);
					NEW(stringReader, LEN(string));
					stringReader.Set(string);
					baseOptions := GetOptions();
					IF baseOptions.Parse(stringReader, error) THEN
						Options.Merge(options, baseOptions);
					END;
				ELSE
					reader.SkipLn()
				END;
			ELSE
				reader.SkipLn()
			END;
		END;

		IF ~options.GetString("p", prolog) THEN prolog := "" END;
		IF ~options.GetString("c",  command) THEN command := "" END;
		IF ~options.GetString("e", epilog) THEN epilog := "" END;
		IF ~options.GetString("f", fileName) THEN fileName := "TesterInput.txt" END;
		mayTrap := options.GetFlag("t");
		verbose := options.GetFlag("verbose");

		IF options.GetString("l",logFileName) THEN
			logFileWriter := Versioning.NewLogWriter(logFileName, "Test",testname);
			logFileWriter.Ln;
			logFileWriter.String("prolog= "); logFileWriter.String(prolog); logFileWriter.Ln;
			logFileWriter.String("command= "); logFileWriter.String(command); logFileWriter.Ln;
			logFileWriter.Ln;
		END;
		IF ~options.GetString("r",resultname) THEN resultname := "" END;

		IF verbose THEN log := writer ELSE log := NIL END;
		NEW (tester, log, logFileWriter, diagnostics, mayTrap, prolog, command, epilog, fileName);

		NEW (report, writer);
		reader.SetPos(0);
		TestSuite.DriveByReader(reader, error, resultname, tester);
		tester.Print (report);
		IF logFileWriter # NIL THEN
			NEW(report, logFileWriter);
			tester.Print(report);
			logFileWriter.Update;
			writer.String("testing logged in "); writer.String(logFileName); writer.Ln;
		END;
		writer.Update;
	END DriveTest;

	PROCEDURE Compile* (context: Commands.Context);
	VAR writer: Streams.Writer; options: Options.Options;diagnostics: Diagnostics.StreamDiagnostics; testname: Files.FileName; test: Files.File;
		reader: Files.Reader;
	BEGIN
		IF (context.caller # NIL) & (context.caller IS Shell.Shell) THEN
			writer := context.out
		ELSE
			writer := Basic.GetDebugWriter("Oberon Compiler Test Results")
		END;
		options := GetOptions();
		IF options.Parse(context.arg, context.error) THEN
			NEW (diagnostics, writer);
			IF context.arg.GetString (testname) THEN
				test := Files.Old (testname);
				IF test = NIL THEN
					context.error.String ("Failed to open test file "); context.error.String (testname); context.error.Ln;
					RETURN;
				END;
			ELSE
				context.result := Commands.CommandParseError;
			END;
			Files.OpenReader(reader, test, 0);
			DriveTest (options, diagnostics, reader, context.error, writer);
		END;
	END Compile;

	PROCEDURE GetTextReader(text: Texts.Text): Streams.Reader;
	VAR
		buffer : POINTER TO ARRAY OF CHAR;
		length: LONGINT; reader: Streams.StringReader;
	BEGIN
		ASSERT((text # NIL));
		text.AcquireRead;
		length := text.GetLength();
		text.ReleaseRead;
		IF length = 0 THEN length := 1 END;
		NEW(buffer, length);
		TextUtilities.TextToStr(text, buffer^);
		(* prepare the reader *)
		NEW(reader, LEN(buffer)); reader.SetRaw(buffer^, 0, LEN(buffer));
		RETURN reader
	END GetTextReader;


PROCEDURE RunTests(
	text : Texts.Text;
	CONST source: ARRAY OF CHAR;
	pos: LONGINT; (* ignore *)
	CONST pc,opt: ARRAY OF CHAR;
	log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	reader: Streams.Reader;
	options: Options.Options;
	optionReader: Streams.StringReader;
BEGIN
	ASSERT((text # NIL) & (diagnostics # NIL));
	reader := GetTextReader(text);
	options := GetOptions();
	NEW(optionReader, LEN(opt));
	optionReader.Set(opt);
	IF options.Parse(optionReader, log) THEN
		DriveTest (options, diagnostics, reader, log, log);
	END;
END RunTests;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister("TestTool");
END Cleanup;

BEGIN
	CompilerInterface.Register("TestTool", "Run test cases against Fox compiler", "Test", RunTests);
	Modules.InstallTermHandler(Cleanup);
END FoxTest.

SystemTools.Free FoxTest TestSuite Versioning ~

	FoxTest.Compile 	Oberon.Execution.Test Oberon.Execution.AMD64TestDiff ~

	FoxTest.Compile	Oberon.Compilation.Test Oberon.Compilation.AMD64TestDiff ~

	FoxTest.Compile 	MathVectors.Test MathVectors.Test.Diff ~

	FoxTest.Compile
		--verbose
		--fileName="TesterInput.Mod"
		--prolog="Compiler.Compile TesterInput.Mod"
		--command="SystemTools.Free Test Dummy B A;SystemTools.Load Test"
		--logFile="FoxExecutionTest.Log"
	MathVectors.Test MathVectors.Test.Diff ~
