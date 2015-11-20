MODULE BenchSyntaxHighlighter; (** AUTHOR "staubesv"; PURPOSE "Benchmarks for SyntaxHighlighter"; *)

IMPORT
	Streams, Commands, Options, Dates, Strings, Files, Random, Texts, TextUtilities, SyntaxHighlighter;

CONST
	DefaultHighlighterName = "Oberon";
	DefaultNofIterations = 1000;

PROCEDURE Reader(reader : Texts.TextReader; nofIterations : LONGINT; out : Streams.Writer);
VAR char32 : Texts.Char32; startTime, endTime : Dates.DateTime; i : LONGINT;
BEGIN
	ASSERT((reader # NIL) & (nofIterations > 0) & (out # NIL));
	out.String("Reading text "); out.Int(nofIterations, 0); out.String(" times ... "); out.Update;
	startTime := Dates.Now();
	FOR i := 1 TO nofIterations DO
		reader.SetPosition(0);
		REPEAT
			reader.ReadCh(char32);
		UNTIL reader.eot;
	END;
	endTime := Dates.Now();
	Strings.ShowTimeDifference(startTime, endTime, out); out.Ln;
END Reader;

PROCEDURE Words(reader : Texts.TextReader; highlighter : SyntaxHighlighter.Highlighter; nofIterations : LONGINT; out : Streams.Writer);
VAR
	char32 : Texts.Char32; style : SyntaxHighlighter.Style;
	wordEnd, readerPosition, i : LONGINT;
	startTime, endTime : Dates.DateTime;
BEGIN
	ASSERT((reader # NIL) & (highlighter # NIL) & (nofIterations > 0) & (out # NIL));
	out.String("Match words "); out.Int(nofIterations, 0); out.String(" times ... "); out.Update;
	startTime := Dates.Now();
	FOR i := 1 TO nofIterations DO
		wordEnd := -1;
		reader.SetPosition(0);
		REPEAT
			readerPosition := reader.GetPosition();
			reader.ReadCh(char32);
			IF (readerPosition > wordEnd) & (char32 > 32) THEN
				style := highlighter.GetWordStyle(reader, readerPosition, wordEnd);
				reader.SetPosition(readerPosition);
				reader.ReadCh(char32);
			END;
		UNTIL reader.eot;
	END;
	endTime := Dates.Now();
	Strings.ShowTimeDifference(startTime, endTime, out); out.Ln;
END Words;

PROCEDURE RebuildRegions(reader : Texts.TextReader; highlighter : SyntaxHighlighter.Highlighter; nofIterations : LONGINT; out : Streams.Writer);
VAR
	state : SyntaxHighlighter.State;
	startTime, endTime : Dates.DateTime;
	i : LONGINT;
BEGIN
	ASSERT((reader # NIL) & (highlighter # NIL) & (nofIterations > 0) & (out # NIL));
	state := highlighter.GetState();
	out.String("Rebuild regions "); out.Int(nofIterations, 0); out.String(" times ... "); out.Update;
	startTime := Dates.Now();
	FOR i := 1 TO nofIterations DO
		highlighter.RebuildRegions(reader, state);
	END;
	endTime := Dates.Now();
	Strings.ShowTimeDifference(startTime, endTime, out); out.Ln;
END RebuildRegions;

PROCEDURE RegionLookup(reader : Texts.TextReader; highlighter : SyntaxHighlighter.Highlighter; nofIterations : LONGINT; out : Streams.Writer);
VAR
	style : SyntaxHighlighter.Style;
	state : SyntaxHighlighter.State;
	random : Random.Generator;
	length, position, start, end, i : LONGINT;
	startTime, endTime : Dates.DateTime;
BEGIN
	ASSERT((reader # NIL) & (highlighter # NIL) & (nofIterations > 0) & (out # NIL));
	state := highlighter.GetState();
	NEW(random);
	length := reader.text.GetLength();
	highlighter.RebuildRegions(reader, state);
	out.String("Region lookup"); out.Int(nofIterations, 0); out.String(" times ... "); out.Update;
	startTime := Dates.Now();
	FOR i := 1 TO nofIterations DO
		position := random.Dice(length);
		style := highlighter.GetRegionStyle(position, state, start, end);
	END;
	endTime := Dates.Now();
	Strings.ShowTimeDifference(startTime, endTime, out); out.Ln;
END RegionLookup;

PROCEDURE Full(reader : Texts.TextReader; highlighter : SyntaxHighlighter.Highlighter; nofIterations : LONGINT; out : Streams.Writer);
VAR
	char32 : Texts.Char32; style : SyntaxHighlighter.Style;
	state : SyntaxHighlighter.State;
	startTime, endTime : Dates.DateTime;
	readerPosition, regionStart, regionEnd, lastEnd, i : LONGINT;
BEGIN
	ASSERT((reader # NIL) & (highlighter # NIL) & (nofIterations > 0) & (out # NIL));
	state := highlighter.GetState();
	out.String("Full highlighting "); out.Int(nofIterations, 0); out.String(" times ... "); out.Update;
	startTime := Dates.Now();
	FOR i := 1 TO nofIterations DO
		reader.SetPosition(0);
		lastEnd := -1;
		REPEAT
			readerPosition := reader.GetPosition();
			reader.ReadCh(char32);
			IF (lastEnd < readerPosition) THEN
				style := NIL;
				style := highlighter.GetRegionStyle(readerPosition, state, regionStart, regionEnd);
				IF (style # NIL) THEN
					lastEnd := regionEnd;
				ELSE
					IF (char32 > 32) THEN
						style := highlighter.GetWordStyle(reader, readerPosition, lastEnd);
						reader.SetPosition(readerPosition);
						reader.ReadCh(char32);
					END;
				END;
			END;
		UNTIL reader.eot;
	END;
	endTime := Dates.Now();
	Strings.ShowTimeDifference(startTime, endTime, out); out.Ln;
END Full;

PROCEDURE Indent(writer : Streams.Writer; width : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 1 TO width DO writer.Char(" "); END;
END Indent;

PROCEDURE Bench*(context : Commands.Context); (** [Options] filename [benchmark] ~ *)
VAR
	filename : Files.FileName; highlighterName, benchmark : ARRAY 64 OF CHAR; nofIterations : LONGINT;
	options : Options.Options;
	text : Texts.Text; reader : Texts.TextReader;
	format, res : LONGINT;
	highlighter : SyntaxHighlighter.Highlighter;
BEGIN
	NEW(options);
	options.Add("h", "highlighter"	, Options.String);
	options.Add("n", "nofIterations", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		benchmark := "";
		context.arg.SkipWhitespace; context.arg.String(filename);
		context.arg.SkipWhitespace; context.arg.String(benchmark);
		IF ~options.GetString("highlighter", highlighterName) THEN highlighterName := DefaultHighlighterName; END;
		IF ~options.GetInteger("nofIterations", nofIterations) THEN nofIterations := DefaultNofIterations; END;
		IF (nofIterations > 0) THEN
			highlighter := SyntaxHighlighter.GetHighlighter(highlighterName);
			IF (highlighter # NIL) THEN
				NEW(text);
				TextUtilities.LoadAuto(text, filename, format, res);
				IF (res = 0) THEN
					context.out.String(filename); context.out.String(": ");
					NEW(reader, text);
					text.AcquireRead;
					IF (benchmark = "") THEN
						context.out.Ln;
						Indent(context.out, 4); Reader(reader, nofIterations, context.out); context.out.Update;
						Indent(context.out, 4); Words(reader, highlighter, nofIterations, context.out); context.out.Update;
						Indent(context.out, 4); RebuildRegions(reader, highlighter, nofIterations, context.out); context.out.Update;
						Indent(context.out, 4); RegionLookup(reader, highlighter, nofIterations, context.out); context.out.Update;
						Indent(context.out, 4); Full(reader, highlighter, nofIterations, context.out); context.out.Update;
					ELSIF (benchmark = "reader") THEN
						Reader(reader, nofIterations, context.out);
					ELSIF (benchmark = "words") THEN
						Words(reader, highlighter, nofIterations, context.out);
					ELSIF (benchmark = "rebuildregions") THEN
						RebuildRegions(reader, highlighter, nofIterations, context.out);
					ELSIF (benchmark = "regionlookup") THEN
						RegionLookup(reader, highlighter, nofIterations, context.out);
					ELSIF (benchmark = "full") THEN
						Full(reader, highlighter, nofIterations, context.out);
					ELSE
						context.error.String("Unknown benchmark: "); context.error.String(benchmark); context.error.Ln;
					END;
					text.ReleaseRead;
				ELSE
					context.error.String("Could not open file "); context.error.String(filename);
					context.error.Ln;
				END;
			ELSE
				context.error.String("Highlighter "); context.error.String(highlighterName);
				context.error.String(" not found."); context.error.Ln;
			END;
		ELSE
			context.error.String("Parameter error: {nofIterations > 0}!"); context.error.Ln;
		END;
	END;
END Bench;

PROCEDURE TestScanner*(context : Commands.Context); (** [options] filename highlighterName ~ *)
VAR
	options : Options.Options;
	filename : Files.FileName; highlighterName : ARRAY 64 OF CHAR;
	highlighter : SyntaxHighlighter.Highlighter;
	text : Texts.Text; reader : Texts.TextReader; char32 : Texts.Char32;
	token : SyntaxHighlighter.Token;
	position, format, res : LONGINT;
BEGIN
	NEW(options);
	options.Add("d", "details", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN
		filename := "";
		context.arg.SkipWhitespace; context.arg.String(filename);

		highlighterName := "";
		context.arg.SkipWhitespace; context.arg.String(highlighterName);

		highlighter := SyntaxHighlighter.GetHighlighter(highlighterName);
		IF (highlighter # NIL) THEN
			NEW(text);
			TextUtilities.LoadAuto(text, filename, format, res);
			IF (res = 0) THEN
				context.out.String("Token chain for file "); context.out.String(filename); context.out.String(":"); context.out.Ln;
				text.AcquireRead;
				NEW(reader, text);
				reader.SetPosition(0); position := 0;
				reader.ReadCh(char32);
				REPEAT
					(* skip whitespace *)
					WHILE (char32 <= 32) & ~reader.eot DO reader.ReadCh(char32); INC(position); END;
					IF ~reader.eot THEN
						ASSERT(char32 > 32);
						context.out.Ln; context.out.String("Scan "); context.out.Int(position, 0); context.out.Ln;
						reader.SetPosition(position);
						highlighter.GetToken(reader, position, token);
						context.out.String(" -> ");
						CASE token.type OF
							|SyntaxHighlighter.Type_Invalid: context.out.String("INV");
							|SyntaxHighlighter.Type_Identifier: context.out.String("ID("); context.out.String(token.value);
							|SyntaxHighlighter.Type_Number: context.out.String("NUM("); context.out.String(token.value);
							|SyntaxHighlighter.Type_Token: context.out.String("T("); context.out.String(token.value);
						ELSE
							context.out.String("UNKNOWN");
						END;
						IF (token.type = SyntaxHighlighter.Type_Identifier) OR (token.type = SyntaxHighlighter.Type_Number) OR (token.type = SyntaxHighlighter.Type_Token) THEN
							IF options.GetFlag("details") THEN
								context.out.String(", ");
								context.out.Int(token.startPosition, 0); context.out.String("..");
								context.out.Int(token.endPosition, 0);
							END;
							context.out.String(")");
						END;
						IF (token.type # SyntaxHighlighter.Type_Invalid) THEN
							reader.SetPosition(token.endPosition + 1); position := token.endPosition + 1;
						ELSE
							INC(position);
						END;
						reader.ReadCh(char32);
					END;
				UNTIL reader.eot;
				text.ReleaseRead;
			ELSE
				context.error.String("Could not open file "); context.error.String(filename); context.error.String(", res = ");
				context.error.Int(res, 0); context.error.Ln;
			END;
		ELSE
			context.error.String("Highlighter "); context.error.String(highlighterName); context.error.String(" not found.");
			context.error.Ln;
		END;
	END;
END TestScanner;

END BenchSyntaxHighlighter.

SystemTools.Free BenchSyntaxHighlighter ~

BenchSyntaxHighlighter.Bench Usb.Mod reader ~
BenchSyntaxHighlighter.Bench I386.Machine.Mod reader ~

BenchSyntaxHighlighter.Bench Usb.Mod words ~
BenchSyntaxHighlighter.Bench I386.Machine.Mod words ~

BenchSyntaxHighlighter.Bench Usb.Mod rebuildregions~
BenchSyntaxHighlighter.Bench I386.Machine.Mod rebuildregions ~

BenchSyntaxHighlighter.Bench -n=1000000 Usb.Mod regionlookup~
BenchSyntaxHighlighter.Bench I386.Machine.Mod regionlookup ~

BenchSyntaxHighlighter.Bench Usb.Mod full ~
BenchSyntaxHighlighter.Bench I386.Machine.Mod full ~

BenchSyntaxHighlighter.Bench Usb.Mod  ~
BenchSyntaxHighlighter.Bench I386.Machine.Mod  ~

Tests:

BenchSyntaxHighlighter.TestScanner Test.Mod Oberon ~

BenchSyntaxHighlighter.TestScanner --details Test.Mod Oberon ~

SystemTools.DoCommands
	FSTools.Enumerate *.Mod BenchSyntaxHighlighter.Bench -n=1 <#filename#> ~
	FSTools.Enumerate *.XML BenchSyntaxHighlighter.Bench -n=1 <#filename#> ~
	FSTools.Enumerate *.TOOL BenchSyntaxHighlighter.Bench -n=1 <#filename#> ~
	FSTools.Enumerate *.C BenchSyntaxHighlighter.Bench -n=1 <#filename#> ~
~

