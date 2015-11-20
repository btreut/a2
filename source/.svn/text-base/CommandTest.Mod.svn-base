MODULE CommandTest; (** AUTHOR "negelef"; PURPOSE "Simple command tester"; *)

IMPORT Commands, TestSuite, Streams, Files, Diagnostics;

TYPE Tester = OBJECT (TestSuite.Tester)

	VAR command: ARRAY 256 OF CHAR;
	VAR tempname: Files.FileName;

	PROCEDURE Handle (reader: Streams.Reader; position: LONGINT; CONST name: ARRAY OF CHAR): INTEGER;
	VAR res: LONGINT; msg: ARRAY 128 OF CHAR; result: INTEGER; file: Files.File; writer: Files.Writer;
	BEGIN
		result := TestSuite.Failure;
		file := Files.New (tempname);
		IF file # NIL THEN
			Files.OpenWriter (writer, file, 0);
			IF file # NIL THEN
				Streams.Copy (reader, writer);
				writer.Update;
				Files.Register (file);
				Commands.Call (command, {Commands.Wait}, res, msg);
				IF res = Commands.Ok THEN result := TestSuite.Positive ELSE result := TestSuite.Negative END;
			END;
		END;
	FINALLY
		RETURN result;
	END Handle;

END Tester;

(** Verbose output:	CompileTest.Test Command TempFile TestFile ~ *)
(** Regression test:	CompileTest.Test Command TempFile TestFile ResultFile ~ *)
PROCEDURE Test* (context: Commands.Context);
VAR diagnostics: Diagnostics.StreamDiagnostics; tester: Tester; report: TestSuite.StreamReport;
BEGIN
	NEW (diagnostics, context.error);
	NEW (tester, diagnostics);
	NEW (report, context.out);
	IF ~context.arg.GetString (tester.command) OR ~context.arg.GetString (tester.tempname) THEN
		context.result := Commands.CommandParseError;
		RETURN;
	END;
	TestSuite.Drive (context, tester);
	tester.Print (report);
END Test;

END CommandTest.

SystemTools.Free CommandTest ~
