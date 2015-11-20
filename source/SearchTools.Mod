MODULE SearchTools; (** AUTHOR "staubesv"; PURPOSE "Some simple search tools"; *)

IMPORT
	Streams, Commands, Options, Files, Strings, UTF8Strings, Texts, TextUtilities;

TYPE

	SearchString = ARRAY 256 OF CHAR;
	SearchStringUCS = ARRAY 256 OF Texts.Char32;

	Parameters = POINTER TO RECORD
		repeat: BOOLEAN;
		subdirectory: BOOLEAN;
	END;

	PatternParameters = POINTER TO RECORD (Parameters)
		searchString : SearchString;
		replaceString : SearchString;
	END;

	Statistics = OBJECT
	VAR
		nofFiles : LONGINT;
		nofMatches, nofConflicts, nofErrors : LONGINT;

		verbose : BOOLEAN;
		abort : BOOLEAN;

		PROCEDURE &Reset*;
		BEGIN
			nofFiles := 0;
			nofMatches := 0; nofErrors := 0; nofConflicts := 0;
			verbose := FALSE; abort := FALSE;
		END Reset;

		PROCEDURE Show(w : Streams.Writer);
		BEGIN
			w.Int(nofMatches, 0); w.String(" matches of "); w.Int(nofFiles, 0); w.String(" files");
			IF (nofConflicts > 0) THEN w.String(", "); w.Int(nofConflicts, 0); w.String(" conflict(s)"); END;
			IF (nofErrors > 0) THEN w.String(", "); w.Int(nofErrors, 0); w.String(" error(s)"); END;
			w.String("."); w.Ln;
		END Show;

	END Statistics;

	EnumProc = PROCEDURE (CONST filename : Files.FileName; param : Parameters; stats : Statistics; context : Commands.Context);


PROCEDURE FindString(CONST filename : Files.FileName; param : Parameters; stats : Statistics; context : Commands.Context);
VAR text : Texts.Text; pos, format, res : LONGINT; searchString : SearchStringUCS; idx : LONGINT; nbrOfHits : LONGINT;
BEGIN
	ASSERT(param IS PatternParameters);
	nbrOfHits := 0;
	idx := 0;
	WITH param:PatternParameters DO
		UTF8Strings.UTF8toUnicode(param.searchString, searchString, idx);
	END;
	NEW(text);
	TextUtilities.LoadAuto(text, filename, format, res);
	IF (res = 0) THEN
		text.AcquireRead;
		pos := TextUtilities.Pos(searchString, 0, text);
		WHILE (pos > 0) DO
			INC(nbrOfHits);
			pos := TextUtilities.Pos(searchString, pos + 1, text);
		END;
		text.ReleaseRead;
		IF (nbrOfHits > 0) THEN
			INC(stats.nofMatches);
			context.out.String(filename);
			IF stats.verbose THEN
				context.out.String(" ("); context.out.Int(nbrOfHits, 0); context.out.String(" hits"); context.out.String(")");
			END;
			context.out.Ln;
		END;
	ELSE
		INC(stats.nofErrors);
		context.error.String("Coult not load text: "); context.error.String(filename); context.error.Ln;
	END;
END FindString;

PROCEDURE ReplaceString(CONST filename : Files.FileName; param : Parameters; stats : Statistics; context : Commands.Context);
VAR
	text : Texts.Text; pos, format, res : LONGINT;
	searchString, replaceString : SearchStringUCS; idx : LONGINT;
	searchStringLen, replaceStringLen : LONGINT;
	replaceCount : LONGINT;
	conflict : BOOLEAN;

	(* Replace string at position <pos> of length <len> with <replString> *)
	PROCEDURE Replace(pos, len : LONGINT; CONST replString : SearchStringUCS);
	BEGIN
		text.Delete(pos, len);
		text.InsertUCS32(pos, replString);
		len := TextUtilities.UCS32StrLength(replString);
	END Replace;

BEGIN
	ASSERT(param IS PatternParameters);
	replaceCount := 0; conflict := FALSE;
	WITH param:PatternParameters DO
		idx := 0; UTF8Strings.UTF8toUnicode(param.searchString, searchString, idx);
		idx := 0; UTF8Strings.UTF8toUnicode(param.replaceString, replaceString, idx);
	END;
	searchStringLen := TextUtilities.UCS32StrLength(searchString);
	replaceStringLen := TextUtilities.UCS32StrLength(replaceString);
	NEW(text);
	TextUtilities.LoadAuto(text, filename, format, res);
	IF (res = 0) THEN
		text.AcquireWrite;
		pos := TextUtilities.Pos(replaceString, 0, text);
		IF (pos > 0) THEN INC(stats.nofConflicts); conflict := TRUE; END;

		pos := TextUtilities.Pos(searchString, 0, text);
		WHILE (pos > 0) DO
			INC(replaceCount);
			Replace(pos, searchStringLen, replaceString);
			pos := TextUtilities.Pos(searchString, pos + replaceStringLen, text);
		END;
		text.ReleaseWrite;
		IF (replaceCount > 0) THEN
			INC(stats.nofMatches);
			context.out.String(filename);
			IF stats.verbose THEN
				context.out.String(" ("); context.out.Int(replaceCount, 0); context.out.String(" replacements)");
				IF conflict THEN context.out.String(" CONFLICT"); END;
			END;
			context.out.Ln;
			res := -1;
			IF (format = 0) THEN TextUtilities.StoreOberonText(text, filename, res);
			ELSIF (format = 1) THEN TextUtilities.StoreText(text, filename, res);
			ELSIF (format = 2) THEN TextUtilities.ExportUTF8(text, filename, res);
			ELSE
				INC(stats.nofErrors);
				context.error.String("Could not store text: "); context.error.String(filename);
				context.error.String(" (Format unknown)"); context.error.Ln;
			END;
			IF (res # 0) THEN
				INC(stats.nofErrors);
				context.error.String("Could not store text: "); context.error.String(filename); context.error.Ln;
			END;
		END;
	ELSE
		INC(stats.nofErrors);
		context.error.String("Could not load text: "); context.error.String(filename); context.error.Ln;
	END;
END ReplaceString;

(* 	Boyer-Moore match for streams. This procedure opens a file as character stream and does not take special care of formatting information.
	It also doesn't do statistics but just outputs the filename if a match occurs and returns after the first match *)
PROCEDURE FindStringRaw(CONST filename : Files.FileName; param : Parameters; stats : Statistics; context : Commands.Context);
VAR
	r : Files.Reader;
	f : Files.File;
	m: LONGINT;
	p : PatternParameters;
BEGIN
	ASSERT(param IS PatternParameters);
	p := param (PatternParameters);
	m := Strings.Length(p.searchString);
	f := Files.Old(filename);
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);
		SearchPatternRaw(r,NIL, p.searchString);
		IF r.res=0 THEN
			context.out.String(filename); context.out.Ln; context.out.Update;
			RETURN;
		END;
	ELSE
		context.error.String("Could not open file "); context.error.String(filename); context.error.Ln;
		context.error.Update;
	END
END FindStringRaw;


(* 	Boyer-Moore match for streams. This procedure opens a file as character stream and does not take special care of formatting information.
	It also doesn't do statistics but just outputs the filename if a match occurs and returns after the first match.
	If a Streams.Writer is provided, it is fed with the data in the interval before each <pattern> location.
	Postcondition:
	- If pattern is found, r.res=0 and Reader is positioned after <pattern> ; otherwise r.res#0  *)

PROCEDURE SearchPatternRaw*(r : Streams.Reader; w: Streams.Writer; CONST pattern: ARRAY OF CHAR);
VAR
	d : ARRAY 256 OF LONGINT;
	cb : Strings.String;
	pos, cpos, i, j, k, m, shift : LONGINT;
BEGIN
	m := Strings.Length(pattern);
	NEW(cb, m);
	WHILE (r.res = 0 ) & (cpos < m) DO
		cb[cpos] := r.Get();
		INC(cpos);
	END;
	IF r.res = 0 THEN
		FOR i := 0 TO 255 DO d[i] := m END;
		FOR i := 0 TO m-2 DO d[ORD(pattern[i])] := m - i - 1 END;
		i := m;
		LOOP
			j := m; k := i;
			REPEAT DEC(k); DEC(j);
			UNTIL (j < 0) OR (pattern[j] # cb[k MOD m]);
			IF j<0 THEN EXIT END;
			shift := d[ORD(cb[(i-1) MOD m])];
			i := i + shift;
			WHILE (cpos < i) & (r.res = 0) DO
				pos:=cpos MOD m;
				IF w#NIL THEN w.Char(cb[pos]);END;
				cb[pos] := r.Get();
				INC(cpos);
			END;
			IF r.res#0 THEN EXIT END;
		END;
		IF w#NIL THEN w.Update END;
	END;
END SearchPatternRaw;

PROCEDURE Enumerate(CONST path, pattern : ARRAY OF CHAR; param : Parameters; proc : EnumProc; stats : Statistics; context : Commands.Context);
VAR
	enum : Files.Enumerator;
	filename : Files.FileName;
	fileflags : SET;
	time, date, size, nofMatches : LONGINT;
BEGIN
	ASSERT(proc # NIL);
	IF path # "" THEN Files.JoinPath(path, pattern, filename) END;
	NEW(enum); enum.Open(filename, {});
	WHILE enum.GetEntry(filename, fileflags, time, date, size) & ~stats.abort DO
		IF ~(Files.Directory IN fileflags) THEN
			REPEAT
				nofMatches := stats.nofMatches;
				proc(filename, param, stats, context);
			UNTIL ~param.repeat OR (stats.nofMatches = nofMatches);
			context.out.Update; context.error.Update;
			INC(stats.nofFiles);
		END;
	END;
	IF param.subdirectory THEN
	Files.JoinPath(path, "*", filename);
	enum.Open(filename, {});
	WHILE enum.GetEntry(filename, fileflags, time, date, size) & ~stats.abort DO
		IF (Files.Directory IN fileflags) THEN
			Enumerate(filename, pattern, param, proc, stats, context);
		END;
	END;
	END;
	enum.Close;
END Enumerate;

PROCEDURE Unescape (CONST source: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR);
VAR si, di: LONGINT;
BEGIN
	si := 0; di := 0;
	WHILE source[si] # 0X DO
		IF (source[si] = '\') & (source[si + 1] # 0X) THEN
			INC (si);
			CASE source[si] OF
			| 't': dest[di] := 09X;
			| 'n': dest[di] := 0AX;
			| 'r': dest[di] := 0DX;
			| 'w': dest[di] := 20X;
			ELSE dest[di] := source[si];
			END;
		ELSE
			dest[di] := source[si];
		END;
		INC (si); INC (di);
	END;
	dest[di] := 0X;
END Unescape;

(** List all files that match <filePattern> and contain the specified <searchString> *)
PROCEDURE Find*(context : Commands.Context); (** [Optinos] filePattern searchString *)
VAR
	options : Options.Options;
	filePattern, path, pattern : Files.FileName; searchString : SearchString;
	param : PatternParameters;
	stats : Statistics;
BEGIN
	NEW(options);
	options.Add("v", "verbose", Options.Flag);
	options.Add("f", "formatted", Options.Flag);
	options.Add("r", "repeat", Options.Flag);
	options.Add("s", "subdirectory", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN
		filePattern := ""; searchString := "";
		context.arg.SkipWhitespace; context.arg.String(filePattern);
		context.arg.SkipWhitespace; context.arg.String(searchString);
		IF (searchString # "") THEN
			NEW(stats);
			stats.verbose := options.GetFlag("verbose");
			NEW(param);
			param.repeat := options.GetFlag("repeat");
			param.subdirectory := options.GetFlag("subdirectory");
			Unescape(searchString, param.searchString);
			IF stats.verbose THEN
				context.out.String("Searching '"); context.out.String(searchString); context.out.String("' in ");
				context.out.String(filePattern); context.out.String("..."); context.out.Ln; context.out.Update;
			END;
			Files.SplitPath(filePattern, path, pattern);
			IF options.GetFlag("formatted") THEN
				Enumerate(path, pattern, param, FindString, stats, context);
			ELSE
				Enumerate(path, pattern, param, FindStringRaw, stats, context);
			END;
			IF stats.verbose THEN
				stats.Show(context.out);
			END;
		ELSE
			context.error.String("No valid search string parameter"); context.error.Ln;
		END;
	END;
END Find;

(** Replace all occurences of <searchString> by <replaceString> in files matching to <filePattern> *)
PROCEDURE Replace*(context : Commands.Context); (** filePattern searchString replaceString *)
VAR
	options : Options.Options;
	filePattern, path, pattern : Files.FileName; searchString, replaceString : SearchString;
	param : PatternParameters;
	stats : Statistics;
BEGIN
	NEW(options);
	options.Add("v", "verbose", Options.Flag);
	options.Add("r", "repeat", Options.Flag);
	options.Add("s", "subdirectory", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		filePattern := ""; searchString := ""; replaceString := "";
		context.arg.SkipWhitespace; context.arg.String(filePattern);
		context.arg.SkipWhitespace; context.arg.String(searchString);
		context.arg.SkipWhitespace; context.arg.String(replaceString);
		IF (searchString # "") THEN
			WHILE (searchString # "") DO
				context.out.String("Replacing '"); context.out.String(searchString); context.out.String("' by '"); context.out.String(replaceString); context.out.Ln;
				NEW(stats);
				stats.verbose := options.GetFlag("verbose");
				NEW(param);
				param.repeat := options.GetFlag("repeat");
				param.subdirectory := options.GetFlag("subdirectory");
				Unescape(searchString, param.searchString);
				Unescape(replaceString, param.replaceString);
				IF stats.verbose THEN
					context.out.String("Replacing '"); context.out.String(searchString); context.out.String("' by '"); context.out.String(replaceString);
					context.out.String("' in "); context.out.String(filePattern); context.out.String("... "); context.out.Ln;
				END;
				Files.SplitPath(filePattern, path, pattern);
				Enumerate(path, pattern, param, ReplaceString, stats, context);
				IF stats.verbose THEN
					stats.Show(context.out);
				END;
				context.out.String("done."); context.out.Ln;
				context.arg.SkipWhitespace; context.arg.String(searchString);
				context.arg.SkipWhitespace; context.arg.String(replaceString);
			END;
		ELSE
			context.error.String("No valid search string parameter"); context.error.Ln;
		END;
	END;
END Replace;


END SearchTools.

SystemTools.Free SearchTools ~

SearchTools.Find -s -r E:/Highdim/Hardware/*.xml "?{" ~

SearchTools.Find E:/WinaosNewCommands/source/*.Mod Objects  ~
SearchTools.Find E:/WinaosNewCommands/winaos/src/*.Mod Commands  ~

SearchTools.Replace E:/WinaosNewCommands/source/*.Mod AosCommands Commands ~
SearchTools.Replace E:/WinaosNewCommands/winaos/src/*.Mod AosCommands Commands ~

SystemTools.FreeDownTo SearchTools ~
