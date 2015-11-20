(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PC; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: main module"; *)

IMPORT
	Commands, Modules, Streams, Files, Configuration, Diagnostics, CompilerInterface,
	Texts, TextUtilities, Strings, UTF8Strings, DynamicStrings, XMLObjects, XML, XMLScanner, XMLParser,
	StringPool, PCM, PCS, PCT, PCP, PCLIR, PCBT, PCOF, PCOM, PCV, PCC;

CONST
	Name = "PACO";
	Description = "Parallel Active Oberon Compiler";
	FileExtension = "MOD";

	DefaultErrorFile = "Errors.XML";
	ErrorTag = "Error";
	ErrCodeAttr = "code";

	(* compiler options: -> PCM *)
	DefCodeOpt = {PCM.ArrayCheck, PCM.AssertCheck, PCM.TypeCheck, PCM.PtrInit, PCM.FullStackInit};
	DefParserOpt = {};
	DefDest = "386";

	Debug = TRUE;

	NoBreakPC = -1;

VAR
	ErrorFile: ARRAY 256 OF CHAR;

TYPE
	StringBuf = ARRAY 256 OF CHAR;

	OptionString* = ARRAY 256 OF CHAR;

VAR
	LastDest: ARRAY 16 OF CHAR; (* last code generator loaded *)

PROCEDURE OutMsg(scanner: PCS.Scanner);
VAR s: PCS.Scanner;  t: PCS.Token; name: StringBuf;
BEGIN
	s := PCS.ForkScanner(scanner);
	s.Get(t);
	IF t = PCS.module THEN
		s.Get(t);
		IF t = PCS.ident THEN
			StringPool.GetString(s.name, name);
			PCM.LogWStr(" compiling "); PCM.LogWStr(PCM.prefix); PCM.LogWStr(name);
			IF PCM.suffix # Modules.extension[0] THEN
				PCM.LogWStr(PCM.suffix)
			ELSIF Modules.ModuleByName(name) # NIL THEN
				PCM.LogWStr(" (in use)")
			END;
			PCM.LogWStr(" ...");
			PCM.LogFlush;
		END;
	END;
END OutMsg;

PROCEDURE Configure(CONST base, dest: ARRAY OF CHAR;  errorIsFatal: BOOLEAN);
VAR name: ARRAY 32 OF CHAR;  i, j: LONGINT;  p: PROCEDURE;
BEGIN
	i := 0;
	WHILE (base[i] # 0X) DO  name[i] := base[i]; INC(i)  END;
	j := 0;
	WHILE dest[j] # 0X DO  name[i] := dest[j]; INC(i); INC(j)  END;
	name[i] := 0X;
	GETPROCEDURE (name, "Install", p);
	IF p # NIL THEN
		p; (*call Install*)
		PCV.SetBasicSizes;
	ELSIF errorIsFatal THEN
		PCM.LogWStr("Cannot install code-generator (no Install procedure)");
		PCM.LogWLn;
		PCM.error := TRUE
	END
END Configure;

PROCEDURE LoadBackEnd(CONST dest: ARRAY OF CHAR);
BEGIN
	COPY(dest, LastDest);
	Configure("PCG", dest, TRUE);
	IF ~PCM.error THEN
		PCP.Assemble := NIL;	(*default = no assembler*)
		Configure("PCA", dest, FALSE)
	END;
END LoadBackEnd;

PROCEDURE GetOptions(r: Streams.Reader; VAR opts: ARRAY OF CHAR);
VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	WHILE opts[i] # 0X DO INC(i) END;
	r.SkipWhitespace;
	ch := r.Peek();
	WHILE (ch = "\") DO
		r.Char(ch); (* skip \ *)
		r.Char(ch);
		WHILE (ch > " ") DO
			opts[i] := ch;  INC(i); r.Char(ch)
		END;
		opts[i] := " "; INC(i);
		r.SkipWhitespace;
		ch := r.Peek()
	END;
	opts[i] := 0X
END GetOptions;

(** Extract input file prefix from global options string, exported for PC.Mod *)
PROCEDURE GetSourcePrefix*(CONST options : OptionString; VAR prefix : ARRAY OF CHAR);
VAR ch, lastCh : CHAR; i : LONGINT;
BEGIN
	prefix := "";
	i := 0; ch := 0X;
	LOOP
		lastCh := ch;
		ch := options[i]; INC(i);
		IF (ch = 0X) OR (i >= LEN(options)) THEN EXIT; END;
		IF (ch = "p") THEN
			IF (i = 0) OR (lastCh = " ") THEN (* be sure that "p" is the first character of an option *)
				SubString(options, i, prefix);
			END;
		END;
	END;
END GetSourcePrefix;

PROCEDURE SubString(CONST options : ARRAY OF CHAR; VAR from : LONGINT; VAR str: ARRAY OF CHAR);
VAR ch: CHAR;  j: LONGINT;
BEGIN
	ASSERT(from < LEN(options));
	ch := options[from]; INC(from); j := 0;
	WHILE (ch # 0X) & (ch # " ") & (from < LEN(options)) & (j < LEN(str)-1) DO
		str[j] := ch; ch := options[from]; INC(j); INC(from);
	END;
	str[j] := 0X;
END SubString;

PROCEDURE ParseOptions(CONST options: ARRAY OF CHAR; VAR prefix, extension, dest, dump, objF: ARRAY OF CHAR;  VAR cOpt, pOpt: SET);
VAR  i: LONGINT;  ch: CHAR; ignore : OptionString;
BEGIN
	(* default options *)
	cOpt := DefCodeOpt;
	pOpt := DefParserOpt;
	COPY("", prefix);
	COPY(Modules.extension[0], extension);
	COPY(DefDest, dest);
	COPY("", dump);
	(* parse options *)
	i := 0;
	REPEAT
		ch := options[i]; INC(i);
		(* fof: note that symmetric difference works as a switch: {1,2}/{2}={1}, {1,2}/{3}={1,2,3} *)
		IF ch = "s" THEN pOpt := pOpt / {PCM.NewSF}
		ELSIF ch = "e" THEN pOpt := pOpt / {PCM.ExtSF}
		ELSIF ch = "n" THEN pOpt := pOpt / {PCM.NoFiles}
		ELSIF ch = "f" THEN pOpt := pOpt / {PCM.Breakpoint}
		ELSIF ch = "o" THEN pOpt := pOpt / {PCM.NoOpOverloading}	(* do NOT allow operator overloading *)
		ELSIF ch = "N" THEN cOpt := cOpt / {PCM.NilCheck}
		ELSIF ch = "c" THEN pOpt := pOpt / {PCM.CacheImports}
		ELSIF ch = "x" THEN cOpt := cOpt / {PCM.ArrayCheck}
		ELSIF ch = "a" THEN cOpt := cOpt / {PCM.AssertCheck}
		ELSIF ch = "z" THEN cOpt := cOpt / {PCM.FullStackInit}
		ELSIF ch = "b" THEN pOpt := pOpt / {PCM.BigEndian}
		ELSIF ch = "." THEN DEC(i); SubString(options, i, extension)
		ELSIF ch = "p" THEN SubString(options, i, ignore);	(* Skip prefix for input filenames (only as global option) *)
		ELSIF ch = "P" THEN SubString(options, i, prefix);	(* Prefix for output filenames *)
		ELSIF ch = "d" THEN SubString(options, i, dest)
		ELSIF ch = "D" THEN SubString(options, i, dump)
		ELSIF ch = "O" THEN cOpt := cOpt / {PCM.Optimize}
		ELSIF ch = "F" THEN SubString(options, i, objF)
		ELSIF ch = "W" THEN pOpt := pOpt / {PCM.Warnings}
		ELSIF ch = "S" THEN pOpt := pOpt / {PCM.SkipOldSFImport}
		ELSIF ch = "M" THEN pOpt := pOpt / {PCM.MultipleModules}
		ELSIF ch = "A" THEN cOpt := cOpt / {PCM.AlignedStack}
		END
	UNTIL ch = 0X;
END ParseOptions;

PROCEDURE EmitScope(scope: PCT.Scope);
VAR name: StringBuf;
BEGIN
	IF (scope.code # NIL) & (scope.code IS PCLIR.Code) THEN
		IF Debug THEN PCT.GetScopeName(scope, name) END;
		PCLIR.Emit(scope.code(PCLIR.Code));
		scope.code := NIL
	END
END EmitScope;

PROCEDURE Module*(scanner: PCS.Scanner; CONST source, options: ARRAY OF CHAR; breakpc: LONGINT; log: Streams.Writer;
	diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	scope: PCT.ModScope; dest, objF: ARRAY 16 OF CHAR;
	size: LONGINT; R: PCM.Rider; new, extend, nofile, skip: BOOLEAN;
	version: CHAR; res: LONGINT;
	str: StringBuf;
	msg: ARRAY 32 OF CHAR;
	finished: BOOLEAN; copyscanner: PCS.Scanner; sym: SHORTINT;
BEGIN {EXCLUSIVE}
	PCM.Init (source, log, diagnostics); (* also resets PCM.count!! *)
	ParseOptions(options, PCM.prefix, PCM.suffix, dest, PCM.dump, objF, PCM.codeOptions, PCM.parserOptions);
	IF dest # LastDest THEN LoadBackEnd(dest) END;

	new := PCM.NewSF IN PCM.parserOptions;
	extend := PCM.ExtSF IN PCM.parserOptions;
	nofile := PCM.NoFiles IN PCM.parserOptions;
	skip := PCM.SkipOldSFImport IN PCM.parserOptions;
	PCM.bigEndian := PCM.BigEndian IN PCM.parserOptions;
	PCM.breakpc := MAX(LONGINT);
	IF PCM.Breakpoint IN PCM.parserOptions THEN
		IF breakpc = NoBreakPC THEN
			PCM.LogWLn; PCM.LogWStr("No PC Selected");
			RETURN
		END;
		PCM.breakpc := breakpc
	END;

	finished := ~ (PCM.MultipleModules IN PCM.parserOptions);

	REPEAT

	OutMsg(scanner);
	new := PCM.NewSF IN PCM.parserOptions;
	extend := PCM.ExtSF IN PCM.parserOptions;
	nofile := PCM.NoFiles IN PCM.parserOptions;
	skip := PCM.SkipOldSFImport IN PCM.parserOptions;
	PCM.bigEndian := PCM.BigEndian IN PCM.parserOptions;
	PCM.breakpc := MAX(LONGINT);
	IF PCM.Breakpoint IN PCM.parserOptions THEN
		IF breakpc = NoBreakPC THEN
			PCM.LogWLn; PCM.LogWStr("No PC Selected");
			RETURN
		END;
		PCM.breakpc := breakpc
	END;

	IF PCLIR.CG.Init() THEN
		NEW(scope); PCT.InitScope(scope, NIL, {}, FALSE);
		PCP.ParseModule(scope, scanner);


		IF ~PCM.error & ~nofile THEN
			version := PCM.FileVersion;
			StringPool.GetString(scope.owner.name, str);
			PCM.Open(str, R, version);
			IF ~(PCM.Breakpoint IN PCM.parserOptions) THEN
				IF PCM.CacheImports IN PCM.parserOptions THEN
					PCT.Unregister(PCT.database, scope.owner.name);
				END;
				PCOM.Export(R, scope.owner, new, extend, skip, msg);
				PCM.LogWStr(msg)
			END;
			IF ~PCM.error THEN
				PCT.TraverseScopes(scope, EmitScope);
				IF objF # "" THEN
					Configure("PCOF", objF, TRUE)
				ELSE
					PCOF.Install
				END;
				IF ~PCM.error & ~(PCM.Breakpoint IN PCM.parserOptions) THEN  PCBT.generate(R, scope, size)  END;
			END
		END;
		IF ~PCM.error THEN
			PCM.LogWStr("  "); PCM.LogWNum(size); PCM.LogWStr(" done ");
			IF PCM.bigEndian THEN  PCM.LogWStr("(BigEndian Mode)") END;
			PCM.LogWLn
		ELSE
			finished := TRUE;
			PCM.LogWStr(" not done"); PCM.LogWLn
		END;
		PCLIR.CG.Done(res); (* ignore res ? *)
	ELSE
		finished := TRUE;
		PCM.LogWLn; PCM.LogWStr("  Code generator not installed");
		PCM.LogWLn; PCM.error := TRUE;
	END;
	PCC.Cleanup;
	error := PCM.error;
	PCM.Reset;
	PCBT.context := NIL;
	PCM.LogFlush;

	copyscanner := PCS.ForkScanner(scanner);
	copyscanner.Get(sym);
	finished := finished OR (sym # PCS.module);

	UNTIL finished

END Module;

(** Compile code contained in t, beginning at position pos *)

PROCEDURE CompileText*(t: Texts.Text; CONST source: ARRAY OF CHAR; pos, pc: LONGINT; CONST opt: ARRAY OF CHAR; log: Streams.Writer;
diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
BEGIN
	IF t = NIL THEN
		log.String ("No text available"); log.Ln; log.Update;
		error := TRUE; RETURN
	END;
	Module(PCS.InitWithText(t, pos), source, opt, pc, log, diagnostics, error);
END CompileText;

PROCEDURE CompileInterface(t: Texts.Text; CONST source: ARRAY OF CHAR; pos: LONGINT; CONST pc,opt: ARRAY OF CHAR; log: Streams.Writer;
diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR pcNum: LONGINT;
BEGIN
	Strings.StrToInt(pc, pcNum);
	CompileText(t,source,pos,pcNum, opt,log, diagnostics, error);
END CompileInterface;


(** Compile file *)

PROCEDURE CompileFile*(CONST name, opt: ARRAY OF CHAR; pc: LONGINT; log: Streams.Writer;
	diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	atu: Texts.Text; format, res: LONGINT;
BEGIN
	NEW(atu);
	TextUtilities.LoadAuto(atu, name, format, res);
	IF res # 0 THEN
		log.String (name); log.String (" not found"); log.Ln; log.Update;
		error := TRUE; RETURN
	END;
	log.String (name);
	Module(PCS.InitWithText(atu, 0), name, opt, pc, log, diagnostics, error);
END CompileFile;

(** Compile ascii file *)

PROCEDURE CompileAsciiFile*(CONST name, opt: ARRAY OF CHAR; pc: LONGINT; log: Streams.Writer;
	diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	f: Files.File; r: Files.Reader;
BEGIN
	f := Files.Old(name);
	IF f = NIL THEN
		log.String (name); log.String (" not found");
		log.Ln; log.Update;
		error := TRUE; RETURN
	END;
	log.String (name);
	Files.OpenReader(r, f, 0);
	Module(PCS.InitWithReader(r, f.Length(),0), name, opt, pc, log, diagnostics, error);
END CompileAsciiFile;

PROCEDURE Compile*(context : Commands.Context);
VAR
	globalOpt, localOpt: OptionString;
	fullname, prefix, filename: ARRAY 256 OF CHAR;
	count: LONGINT;
	error: BOOLEAN;
	diagnostics : Diagnostics.DiagnosticsList;
BEGIN
	PCT.InitDB(PCT.database);
	error := FALSE;
	globalOpt := ""; GetOptions(context.arg, globalOpt);
	GetSourcePrefix(globalOpt, prefix);
	count := 0;
	NEW(diagnostics);
	WHILE  ~context.arg.EOLN() & ~error DO
		context.arg.String(filename);
		IF filename # "" THEN
			INC(count);
			COPY(globalOpt, localOpt);
			GetOptions(context.arg, localOpt);
			COPY(prefix, fullname); Strings.Append(fullname, filename);
			diagnostics.Reset;
			CompileFile(fullname, localOpt, MAX(LONGINT), context.out, diagnostics, error);
			diagnostics.ToStream(context.out, Diagnostics.All);
			PCM.LogFlush;
			IF count MOD 32 = 0 THEN PCT.InitDB(PCT.database) END;
		END
	END;
	PCT.InitDB(PCT.database);
END Compile;

PROCEDURE TrapHandler(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	PCM.LogWStr("could not load error messages: "); PCM.LogWLn;
	PCM.LogWStr(ErrorFile); PCM.LogWStr(" invalid (pos ");
	PCM.LogWNum(pos); PCM.LogWStr(", line ");
	PCM.LogWNum(line); PCM.LogWStr(", row ");
	PCM.LogWNum(row); PCM.LogWStr("   ");
	PCM.LogWStr(msg); PCM.LogWStr(")"); PCM.LogWLn;
END TrapHandler;

(** (Re)load error messages *)
PROCEDURE InitErrMsg*; (** ~ *)
VAR
	f: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; errors: XML.Document;
	e: XML.Element; enum, msgEnum: XMLObjects.Enumerator; p: ANY;
	code, i: LONGINT; str: XML.String;
	dynStr: DynamicStrings.DynamicString;
	r : Files.Reader;
	res : LONGINT;
BEGIN
	Configuration.Get("Paco.ErrorMessages", ErrorFile, res);
	IF (res # Configuration.Ok) THEN ErrorFile := DefaultErrorFile END;
	f := Files.Old(ErrorFile);
	IF f = NIL THEN
		PCM.LogWStr("could not load error messages: ");
		PCM.LogWStr(ErrorFile); PCM.LogWStr(" not found"); PCM.LogWLn;
		RETURN;
	END;
	(* f # NIL *)
	Files.OpenReader(r, f, 0);
	NEW(scanner, r);
	NEW(parser, scanner); parser.reportError := TrapHandler;
	errors := parser.Parse();
	e := errors.GetRoot();
	enum := e.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element);
			str := e.GetName();
			IF str^ = ErrorTag THEN
					(* extract error code *)
				str := e.GetAttributeValue(ErrCodeAttr);
				Strings.StrToInt(str^, code);
					(* extract error message *)
				msgEnum := e.GetContents();
				NEW(dynStr);
				WHILE msgEnum.HasMoreElements() DO
					p := msgEnum.GetNext();
					IF p IS XML.Chars THEN
						str := p(XML.Chars).GetStr();
						dynStr.Append(str^);
					ELSIF p IS XML.CDataSect THEN
						str := p(XML.CDataSect).GetStr();
						dynStr.Append(str^);
					ELSIF p IS XML.CharReference THEN
						NEW(str, 5);
						i := 0;
						IF UTF8Strings.EncodeChar(p(XML.CharReference).GetCode(), str^, i) THEN
							dynStr.Append(str^);
						END;
					ELSE
						(* ignore *)
					END;
				END;
				str := dynStr.ToArrOfChar();
				PCM.SetErrorMsg(code, str^);
				dynStr.Init();
			END;
		END;
	END;
END InitErrMsg;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister(Name);
END Cleanup;

BEGIN
	LastDest := "";
	PCM.LogWStr("Parallel Compiler / prk"); PCM.LogWLn;
	PCV.Install;
	InitErrMsg;
	Modules.InstallTermHandler(Cleanup);
	CompilerInterface.Register(Name, Description, FileExtension, CompileInterface);
END PC.

(*
	21.11.07	fof	new compiler option /M added (multiple modules within one file allowed, MODULE ident .... ident. MODULE ident ... ident. etc.)
	10.08.07	sst	new compiler option /p added
	15.11.06	ug	new compiler option /S added, FileVersion incremented
	25.11.03	mb	added InitErrMsg: read error messages from XML file
	20.09.03	prk	"/Dcode" compiler option added
	24.06.03	prk	Check that name after END is the same as declared after MODULE
	25.02.03	prk	PC split into PC (Aos pure) and PC (Oberon dependent)
*)