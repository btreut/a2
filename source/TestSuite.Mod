MODULE TestSuite; (** AUTHOR "negelef"; PURPOSE "Simple testing framework"; *)

IMPORT Streams, Files, Commands, Strings, TextUtilities, Diagnostics;

CONST
	PositiveTest = 0;
	NegativeTest = 1;

	Positive* = 0;
	Negative* = 1;
	Failure* = 2;

TYPE
	TestType* = INTEGER;
	TestName = ARRAY 100 OF CHAR;

	TestResult* = POINTER TO RECORD
		type-: TestType;
		name-: TestName;
		succeeded-, new-: BOOLEAN;
		next: TestResult
	END;

	TestResultList = RECORD
		first, last: TestResult;
	END;

	Report* = OBJECT

	VAR tests-, succeeded-, succeededThisTime-, failed-, failedThisTime-: INTEGER;

	PROCEDURE Open*;
	END Open;

	PROCEDURE Handle* (result: TestResult);
	END Handle;

	PROCEDURE Close*;
	END Close;

	END Report;

	Tester* = OBJECT

	VAR
		tests, results: TestResultList;
		diagnostics-: Diagnostics.Diagnostics;

	PROCEDURE &Init* (diagnostics: Diagnostics.Diagnostics);
	BEGIN SELF.diagnostics := diagnostics;
	END Init;

	PROCEDURE Process* (r: Streams.Reader);
	VAR type: TestType; name: TestName; line: ARRAY 200 OF CHAR;
		code: Strings.Buffer; writer : Streams.Writer;
		string : Strings.String; reader: Streams.StringReader;
	BEGIN
		NEW (code, 1000); writer := code.GetWriter ();
		ClearList (tests);
		WHILE SkipComment (r) DO
			IF ~ReadType (r, type) OR ~SkipWhitespace (r) OR ~ReadText (r, name) THEN
				diagnostics.Error (name, r.Pos(), Diagnostics.Invalid, "parse error"); RETURN;
			END;
			IF FindResult (tests, name) # NIL THEN
				diagnostics.Error (name, Diagnostics.Invalid, Diagnostics.Invalid, "duplicated test"); RETURN;
			END;
			code.Clear; writer.Reset;
			WHILE SkipLn (r) & Tabulator (r) & ReadText (r, line) DO writer.Char (09X); writer.String (line); writer.Char (0AX); END;
			string := code.GetString ();
			NEW (reader, code.GetLength ());
			reader.Set (string^);
			AddResult (tests, type, name, Handle (reader, r.Pos () - writer.Pos () - 1, name, type) = type);
		END;
	END Process;

	PROCEDURE Handle* (r: Streams.Reader; pos: LONGINT; CONST name: ARRAY OF CHAR; type: TestType): INTEGER;
	END Handle;

	PROCEDURE Print* (report: Report);
	VAR test, result: TestResult;
	BEGIN
		report.tests := 0; report.succeeded := 0; report.succeededThisTime := 0; report.failed := 0; report.failedThisTime := 0;
		report.Open;
		test := tests.first;
		WHILE test # NIL DO
			INC (report.tests); IF test.succeeded THEN INC (report.succeeded) ELSE INC (report.failed) END;
			result := FindResult (results, test.name);
			test.new := (result = NIL) OR (test.succeeded # result.succeeded);
			IF test.new THEN IF test.succeeded THEN INC (report.succeededThisTime) ELSE INC (report.failedThisTime) END END;
			IF (~test.succeeded) OR (test.new) THEN report.Handle (test) END;
			test := test.next;
		END;
		report.Close;
	END Print;

	END Tester;

	StreamReport* = OBJECT (Report)

	VAR w: Streams.Writer; tw: TextUtilities.TextWriter;

		PROCEDURE &InitStreamReport *(w: Streams.Writer);
		BEGIN SELF.w := w; IF w IS TextUtilities.TextWriter THEN tw := w(TextUtilities.TextWriter) ELSE tw := NIL END;
		END InitStreamReport;

		PROCEDURE Open;
		BEGIN w.Ln; Bold; w.String ("Test results:"); Default; w.Ln
		END Open;

		PROCEDURE Green;
		BEGIN IF tw # NIL THEN tw.SetFontColor (000C000FFH); tw.SetFontStyle ({0}) END;
		END Green;

		PROCEDURE Red;
		BEGIN IF tw # NIL THEN tw.SetFontColor (LONGINT(0FF0000FFH)); tw.SetFontStyle ({0}) END;
		END Red;

		PROCEDURE Orange;
		BEGIN IF tw # NIL THEN tw.SetFontColor (LONGINT (0FFC000FFH)); tw.SetFontStyle ({0}) END;
		END Orange;

		PROCEDURE Default;
		BEGIN IF tw # NIL THEN tw.SetFontColor (0000000FFH); tw.SetFontStyle ({}) END;
		END Default;

		PROCEDURE Bold;
		BEGIN IF tw # NIL THEN tw.SetFontStyle ({0}) END;
		END Bold;

		PROCEDURE Handle (test: TestResult);
		BEGIN
			IF test.type = PositiveTest THEN w.String ("positive: ");
			ELSIF test.type = NegativeTest THEN w.String ("negative: ") END;
			w.String (test.name); w.String (": ");
			IF test.succeeded THEN
				Green;
				w.String ("succeeded")
			ELSE
				IF test.new THEN Orange ELSE Red END;
				w.String ("failed")
			END;
			Default; w.Ln
		END Handle;

		PROCEDURE Close;
		BEGIN w.Ln; Bold; w.String ("Summary:"); Default; w.Ln;
			w.String ("number of tests:"); w.Char (9X); w.Int (tests, 0); w.Ln;
			w.String ("successful tests:"); w.Char (9X); IF succeeded = tests THEN Green ELSE Red END; w.Int (succeeded, 0); Default;
			IF succeededThisTime > 0 THEN w.Char (9X); w.Char ('('); w.Char ('+'); w.Int (succeededThisTime, 0); w.Char (')'); END; w.Ln;
			w.String ("failed tests:"); w.Char (9X); w.Char (9X); IF failed = 0 THEN Green ELSE Red END; w.Int (failed, 0); Default;
			IF failedThisTime > 0 THEN w.Char (9X); w.Char ('('); w.Char ('+'); w.Int (failedThisTime, 0); w.Char (')'); END; w.Ln;
		END Close;

	END StreamReport;

(* helper procedures for parsing *)

PROCEDURE SkipComment (r: Streams.Reader): BOOLEAN;
VAR char: CHAR;
BEGIN char := r.Peek (); WHILE (char = '#') OR  (char = 0AX) OR (char = 0DX) DO r.SkipLn; char := r.Peek (); END; RETURN (r.res = Streams.Ok) & (char # 0X);
END SkipComment;

PROCEDURE SkipWhitespace (r: Streams.Reader): BOOLEAN;
BEGIN WHILE r.Peek () = ' ' DO r.SkipBytes (1) END; RETURN r.res = Streams.Ok
END SkipWhitespace;

PROCEDURE SkipLn (r: Streams.Reader): BOOLEAN;
BEGIN WHILE (r.Peek () = 0AX) OR (r.Peek () = 0DX) DO r.SkipBytes (1) END; RETURN r.res = Streams.Ok
END SkipLn;

PROCEDURE ReadType (r: Streams.Reader; VAR type: TestType): BOOLEAN;
VAR c: CHAR; string: ARRAY 10 OF CHAR; i: INTEGER;
BEGIN
	i := 0; r.Char (c);
	WHILE (c # ':') & (i # LEN (string)) DO string[i] := c; INC (i); r.Char (c) END;
	IF i = LEN (string) THEN RETURN FALSE END;
	string[i] := 0X;
	IF string = "positive" THEN type := PositiveTest; RETURN TRUE
	ELSIF string = "negative" THEN type := NegativeTest; RETURN TRUE
	ELSE RETURN FALSE END
END ReadType;

PROCEDURE ReadText (r: Streams.Reader; VAR text: ARRAY OF CHAR): BOOLEAN;
BEGIN r.Ln (text); RETURN r.res = Streams.Ok
END ReadText;

PROCEDURE Tabulator (r: Streams.Reader): BOOLEAN;
BEGIN RETURN (r.Peek () = 09X) & (r.Get () = 09X)
END Tabulator;

PROCEDURE ReadBoolean (r: Streams.Reader; VAR boolean: BOOLEAN): BOOLEAN;
VAR value: LONGINT;
BEGIN r.Int (value, FALSE); boolean := value = 1; RETURN r.res = Streams.Ok
END ReadBoolean;

PROCEDURE ReadResults (r: Streams.Reader; VAR list: TestResultList);
VAR succeeded: BOOLEAN; name: TestName;
BEGIN WHILE ReadBoolean (r, succeeded) & SkipWhitespace (r) & ReadText (r, name) DO AddResult (list, 0, name, succeeded) END
END ReadResults;

PROCEDURE WriteResults (w: Streams.Writer; CONST list: TestResultList);
VAR result: TestResult;
BEGIN result := list.first;
	WHILE result # NIL DO
		IF result.succeeded THEN w.Char ('1') ELSE w.Char ('0') END;
		w.Char (' '); w.String (result.name); w.Ln;
		result := result.next
	END
END WriteResults;

(* test results management *)

PROCEDURE ClearList (VAR list: TestResultList);
BEGIN list.first := NIL; list.last := NIL
END ClearList;

PROCEDURE AddResult (VAR list: TestResultList; type: TestType;  CONST name: ARRAY OF CHAR; succeeded: BOOLEAN);
VAR result: TestResult;
BEGIN NEW (result); COPY (name, result.name); result.succeeded := succeeded; result.new := FALSE; result.next := NIL; result.type := type;
	IF list.first = NIL THEN list.first := result ELSE list.last.next := result END; list.last := result;
END AddResult;

PROCEDURE FindResult (CONST list: TestResultList; CONST name: ARRAY OF CHAR): TestResult;
VAR result: TestResult;
BEGIN result := list.first; WHILE (result # NIL) & (result.name # name) DO result := result.next END; RETURN result
END FindResult;


(* public interface helper *)
PROCEDURE DriveByReader* (reader: Streams.Reader; error: Streams.Writer; CONST resultname: ARRAY OF CHAR; tester: Tester);
VAR resreader: Files.Reader;result: Files.File; writer: Files.Writer;
BEGIN
	IF reader = NIL THEN
		RETURN;
	END;
	ClearList (tester.results);
	IF resultname # "" THEN
		result := Files.Old (resultname);
		IF result # NIL THEN
			NEW (resreader, result, 0); ReadResults (resreader, tester.results)
		END
	END;
	tester.Process (reader);
	IF resultname # "" THEN
		result := Files.New (resultname);
		IF result = NIL THEN
			error.String ("Failed to open result file "); error.String (resultname); error.Ln;
			RETURN;
		ELSE
			NEW (writer, result, 0); WriteResults (writer, tester.tests); writer.Update; Files.Register (result);
		END
	END;
END DriveByReader;

(* public interface helper *)
PROCEDURE Drive* (context: Commands.Context; tester: Tester);
VAR testname, resultname: Files.FileName; test, result: Files.File; reader: Files.Reader; writer: Files.Writer;
BEGIN
	IF context.arg.GetString (testname) THEN
		test := Files.Old (testname);
		IF test = NIL THEN
			context.error.String ("Failed to open test file "); context.error.String (testname); context.error.Ln;
			RETURN;
		END;
	ELSE
		context.result := Commands.CommandParseError;
	END;
	NEW (reader, test, 0);
	IF ~context.arg.GetString (resultname) THEN
		resultname := "";
	END;
	DriveByReader(reader, context.error, resultname, tester);
END Drive;


END TestSuite.
