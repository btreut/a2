(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCM; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: input and output module"; *)

IMPORT
		SYSTEM,
		KernelLog, Modules, Objects, Streams, Files, Diagnostics,
		StringPool, PCDebug, Strings, Reflection,Machine;

	CONST
		(* value of constant NIL *)
		nilval* = 0;

		(* target machine minimum values of basic types expressed in host machine format: *)
		MinSInt* = -80H;
		MinInt* = -8000H;
		MinLInt* =  LONGINT(80000000H);	(* i386: -2147483648*)

		(* target machine maximum values of basic types expressed in host machine format: *)
		MaxSInt* = 7FH;
		MaxInt* = 7FFFH;
		MaxLInt* = 7FFFFFFFH;	(* i386: 2147483647*)
		MaxSet* = 31;	(* must be >= 15, else the bootstraped compiler cannot run (IN-tests) *)

		(* parametrization of numeric scanner: *)
		MaxHDig* = 8;	(* maximal hexadecimal longint length *)
		MaxHHDig* = 16;	(* maximal hexadecimal hugeint length *)
		MaxRExp* = 38;	(* maximal real exponent *)
		MaxLExp* = 308;	(* maximal longreal exponent *)

		(** code generator options *)
		ArrayCheck* = 0;		(* x - perform array boundary checks *)
		OverflowCheck* = 1;	(* v - perform overflow check *)
		NilCheck* = 2;			(* N - explicit hard-coded nil checks *)
		TypeCheck*= 3;		(* t - perform type checks *)
		PtrInit* = 5;				(* p - initialize pointers to NIL *)
		AssertCheck* = 6;		(* a - evaluate asserts *)
		Optimize* = 13;
		FullStackInit* = 20;		(* z - clear all values on stack *)
		AlignedStack*=21; 		(* A - generate code with stack alignment for unix Aos *)

		ExportDefinitions* = 30;
		UseDefinitions* = 31;

		(** parser options *)
		NewSF* = 16;				(* s - generation of new symbol file allowed *)
		ExtSF* = 17;				(* e - generation of extended symbol file allowed *)
		Breakpoint* = 18;			(* f - find position in code *)
		CacheImports* = 19; 		(* c - Cache imported modules *)
		NoFiles* = 21;				(* n - don't generate files, parse only*)
		NoOpOverloading* = 22;	(* o - do NOT allow operator overloading *)
		BigEndian* = 23;			(* b - generate big endian code, makes only sense together with ARM backend *)
		Warnings* = 24;				(* W - display warnings *)
		SkipOldSFImport* = 25;		(* S - skip old symbol file import in PCOM.Export, avoids compiler error when migrating to new object file *) (* ug *)
		MultipleModules*= 26; 		(* M - allow compilation of multiple modules within one file *)


		(** sysflags and objflags written to and read from symbol file *)
		Untraced* = 4;	(** global vars + fields - weak pointer *)
		WinAPIParam* = 13; (* ejz *)
		CParam*=14; (* fof for linux *)
		ReadOnly* = 15;   (* fof *)
		RealtimeProc* = 21; (* ug *)
		RealtimeProcType* = 21; (* ug *)

		(** compiler generated traps *)
		WithTrap* = 1;
		CaseTrap* = 2;
		ReturnTrap* = 3;
		TypeEqualTrap* = 5;
		TypeCheckTrap* = 6;
		IndexCheckTrap* = 7;
		AssertTrap* = 8;
		ArraySizeTrap* = 9;
		ArrayFormTrap*=10; (* fof: indicates that array cannot be (re-)allocated since shape, type or size does not match *)


			(** file names and extentions *)
		FileTag = 0BBX;				(* same constants are defined in Linker and Loader *)
		NoZeroCompress = 0ADX;	(* do. *)
		FileVersion* = 0B1X;			(* do. *)
		FileVersionOC*=0B2X; (* fof, preparation for new compiler *)

		LocalUnicodeSupport* = TRUE;
		ExportedUnicodeSupport* = FALSE;

		InitErrMsgSize = 300;	(* initial size of array of error messages *)

		MaxErrors = 100;	(* maximum number of diagnostic messages *)
		MaxWarnings = 100;

	TYPE
		SymReader* = Files.Reader;

		Rider* = RECORD
			symmodF, symF, objF, refF: Files.File;
			symmod, sym, obj, ref: Files.Writer;		(*temp modlist, temp symfile, main file*)
		END;

		Attribute* = OBJECT END Attribute;

		ErrorMsgs = POINTER TO ARRAY OF StringPool.Index;

	VAR
		bigEndian*: BOOLEAN;
	(** fof >> *)
	tracebackOnError: BOOLEAN;
	(** << fof  *)

			(** status *)
		codeOptions*, parserOptions*: SET;
		error*: BOOLEAN;		(** actual compilation status *)
		errors, warnings: LONGINT;	(* number of errors and warnings *)
		errMsg: ErrorMsgs;	(*error messages*)

			(** input *)
		breakpc*: LONGINT;	(** code offset to be found or MAX(LONGINT) *)
		breakpos*: LONGINT;	(** text pos corresponding to breakpc (err 400 pos) *)

			(** output *)
		prefix*, suffix*: ARRAY 128 OF CHAR;
			(** procedure to dump (/D option) *)
		dump*: ARRAY 32 OF CHAR;

		source-: Files.FileName;
		log-: Streams.Writer;
		diagnostics-: Diagnostics.Diagnostics;

(** ---------- low level functions --------------------- *)

	PROCEDURE GetProcessID*(): ADDRESS;
	BEGIN
		RETURN SYSTEM.VAL(ADDRESS, Objects.ActiveObject())
	END GetProcessID;


(** ---------- file IO functions --------------------- *)

	PROCEDURE MakeFileName(VAR file: ARRAY OF CHAR; CONST name, prefix, suffix: ARRAY OF CHAR);
		VAR i, j: LONGINT;
	BEGIN
		i := 0; WHILE prefix[i] # 0X DO  file[i] := prefix[i];  INC(i)  END;
		j := 0; WHILE name[j] # 0X DO  file[i+j] := name[j];  INC(j)  END;
		INC(i, j);
		j := 0; WHILE suffix[j] # 0X DO file[i+j] := suffix[j]; INC(j)  END;
		file[i+j] := 0X;
	END MakeFileName;

	PROCEDURE WriteString(w: Streams.Writer; CONST s: ARRAY OF CHAR);
		VAR i: INTEGER; ch: CHAR;
	BEGIN
		i:=0; ch:=s[0];
		WHILE ch # 0X DO
			w.Char(ch); INC(i); ch := s[i];
		END;
		w.Char(0X);
	END WriteString;

	(** OpenSymFile - Open a symfile for reading *)

	PROCEDURE OpenSymFile*(CONST name: ARRAY OF CHAR;  VAR r: SymReader;  VAR version: CHAR; VAR zeroCompress: BOOLEAN): BOOLEAN;
		VAR res: BOOLEAN;  file: Files.FileName;  f: Files.File; dummy: LONGINT; ch: CHAR;
	BEGIN
		res := FALSE; zeroCompress := TRUE;
		MakeFileName(file, name, prefix, suffix);
		f := Files.Old(file);
		IF f # NIL THEN
			Files.OpenReader(r, f, 0);
			r.Char(ch);
			IF ch = FileTag THEN
				r.Char(version);
				IF version = NoZeroCompress THEN
					zeroCompress := FALSE;
					r.Char(version);
				END;
				IF version = FileVersion THEN
				r.RawNum(dummy);	(*skip symfile size*)
				ELSIF version = FileVersionOC THEN
				r.RawLInt(dummy);
				END;
				res := TRUE
			END
		END;
		RETURN res
	END OpenSymFile;

	PROCEDURE SymW*(VAR R: Rider; ch: CHAR);
	BEGIN  R.sym.Char(ch)  END SymW;

	PROCEDURE SymWNum*(VAR R: Rider; i: LONGINT);
	BEGIN  R.sym.RawNum(i)  END SymWNum;

	PROCEDURE SymWSet*(VAR R: Rider; s: SET);
	BEGIN  R.sym.RawNum(SYSTEM.VAL(LONGINT, s))  END SymWSet;

	PROCEDURE SymWString*(VAR R: Rider; CONST str: ARRAY OF CHAR);
	BEGIN  WriteString(R.sym, str)  END SymWString;

	PROCEDURE SymWMod*(VAR R: Rider; CONST str: ARRAY OF CHAR);
	BEGIN  WriteString(R.symmod, str) END SymWMod;

	PROCEDURE SymWReal*(VAR R: Rider; r: REAL);
	BEGIN  R.sym.RawReal(r)  END SymWReal;

	PROCEDURE SymWLReal*(VAR R: Rider; r: LONGREAL);
	BEGIN  R.sym.RawLReal(r)  END SymWLReal;


	PROCEDURE ObjWGetPos*(VAR R: Rider; VAR pos: LONGINT);
	BEGIN pos := R.obj.Pos()
	END ObjWGetPos;

	PROCEDURE ObjW*(VAR R: Rider; ch: CHAR);
	BEGIN  R.obj.Char(ch)
	END ObjW;

	PROCEDURE ObjWNum*(VAR R: Rider; i: LONGINT);
	BEGIN R.obj.RawNum(i)
	END ObjWNum;

	PROCEDURE ObjWInt*(VAR R: Rider; i: INTEGER);
	BEGIN R.obj.RawInt(i)
	END ObjWInt;

	PROCEDURE ObjWIntAt*(VAR R: Rider; pos: LONGINT; i: INTEGER);
		VAR w: Files.Writer;
	BEGIN
		R.obj.Update;
		Files.OpenWriter(w, R.objF, pos);
		w.RawInt(i);
		w.Update
	END ObjWIntAt;

	PROCEDURE ObjWLInt*(VAR R: Rider; i: LONGINT);
	BEGIN R.obj.RawLInt(i)
	END ObjWLInt;

	PROCEDURE ObjWLIntAt*(VAR R: Rider; pos: LONGINT; i: LONGINT);
		VAR w: Files.Writer;
	BEGIN
		R.obj.Update;
		Files.OpenWriter(w, R.objF, pos);
		w.RawLInt(i);
		w.Update
	END ObjWLIntAt;

	PROCEDURE ObjWName*(VAR R: Rider; CONST str: ARRAY OF CHAR);
	BEGIN R.obj.RawString(str)
	END ObjWName;

	PROCEDURE RefW*(VAR R: Rider; ch: CHAR);
	BEGIN R.ref.Char(ch)
	END RefW;

	PROCEDURE RefWNum*(VAR R: Rider; i: LONGINT);
	BEGIN R.ref.RawNum(i)
	END RefWNum;

	PROCEDURE RefWString*(VAR R: Rider; CONST str: ARRAY OF CHAR);
	BEGIN R.ref.RawString(str)
	END RefWString;


	PROCEDURE Open*(CONST name: ARRAY OF CHAR; VAR R: Rider; VAR version: CHAR);
		VAR file: Files.FileName;
	BEGIN
		MakeFileName(file, name, prefix, suffix);
		R.symmodF := Files.New("");
		R.symF := Files.New("");
		R.objF := Files.New(file);
		R.refF := Files.New("");
		Files.OpenWriter(R.symmod, R.symmodF, 0);
		Files.OpenWriter(R.sym, R.symF, 0);
		Files.OpenWriter(R.obj, R.objF, 0);
		Files.OpenWriter(R.ref, R.refF, 0);
		R.obj.Char(FileTag);
		R.obj.Char(NoZeroCompress);
		R.obj.Char(version)
	END Open;

	PROCEDURE AppendFile(f: Files.File;  to: Streams.Writer);
		VAR buffer: ARRAY 1024 OF CHAR;  r: Files.Reader;  read: LONGINT;
	BEGIN
		Files.OpenReader(r, f, 0);
		REPEAT
			r.Bytes(buffer, 0, 1024, read);
			to.Bytes(buffer, 0, read)
		UNTIL read # 1024
	END AppendFile;

	PROCEDURE CloseSym*(VAR R: Rider);
	BEGIN
		R.symmod.Update;	(* flush buffers to file *)
		R.sym.Update;
(*		IF OldFileFormat THEN
			R.obj.RawNum(R.symmod.sent + R.sym.sent);
		ELSE
			R.obj.RawNum(4 + R.symmod.sent + R.sym.sent);
			R.obj.RawSet(codeOptions)
		END; *)
		R.obj.RawNum(4 + R.symmod.sent + R.sym.sent);
		R.obj.RawSet(codeOptions);
		AppendFile(R.symmodF, R.obj);
		AppendFile(R.symF, R.obj)
	END CloseSym;

	PROCEDURE CloseObj*(VAR R: Rider);
	BEGIN
		R.ref.Update;
		AppendFile(R.refF, R.obj);
		R.obj.Update;
		Files.Register(R.objF)
	END CloseObj;

	PROCEDURE RefSize*(VAR R: Rider): LONGINT;
	BEGIN  RETURN R.ref.Pos()
	END RefSize;


(** ---------- text output functions --------------------- *)

	PROCEDURE GetMessage (err: LONGINT; CONST msg: ARRAY OF CHAR; VAR res: ARRAY OF CHAR);
	VAR str: ARRAY 128 OF CHAR;
	BEGIN
		COPY (msg, res);
		IF (errMsg # NIL) & (0 <= err) & (err < LEN(errMsg)) THEN
			StringPool.GetString(errMsg[err], str);
			Strings.Append(res, "  ");
			Strings.Append(res, str);
		END;
	END GetMessage;

	PROCEDURE TraceBackThis( eip, ebp: ADDRESS );   (* do a stack trace back w.r.t. given instruction and frame pointers *)
	BEGIN
		log.Ln;  log.String( "##################" );
		log.Ln;  log.String( "# Debugging.TraceBack #" );
		log.Ln;  log.String( "##################" );
		log.Ln;  Reflection.StackTraceBack( log, eip, ebp, 0, TRUE , FALSE );
		log.Update;
	END TraceBackThis;

	PROCEDURE TraceBack*;   (* do a stack trace back starting at the calling instruction position *)
	BEGIN
		TraceBackThis( Machine.CurrentPC(), Machine.CurrentBP() );
	END TraceBack;

	PROCEDURE Error* (err, pos: LONGINT;  CONST msg: ARRAY OF CHAR);
		VAR str: ARRAY 128 OF CHAR;
	BEGIN {EXCLUSIVE}
		(** fof >> *)
		IF tracebackOnError THEN TraceBack() END;
		(** << fof  *)
		error := error OR (err <= 400) OR (err >= 404);
		IF err = 400 THEN breakpos := pos END;
		GetMessage (err, msg, str);
		IF (err < 400) OR (err > 403) THEN
			INC (errors);
			IF errors > MaxErrors THEN
				RETURN
			ELSIF errors = MaxErrors THEN
				err := Diagnostics.Invalid; pos := Diagnostics.Invalid; str := "too many errors"
			END;
			IF diagnostics # NIL THEN
				diagnostics.Error (source, pos, err, str);
			END;
		ELSE
			IF diagnostics # NIL THEN
				diagnostics.Information (source, pos, err, str);
			END;
		END;
	END Error;

	PROCEDURE ErrorN* (err, pos: LONGINT; msg: StringPool.Index);
		VAR str: ARRAY 256 OF CHAR;
	BEGIN
		StringPool.GetString(msg, str);
		Error(err, pos, str)
	END ErrorN;

	PROCEDURE Warning* (err, pos: LONGINT;  CONST msg: ARRAY OF CHAR);
		VAR str: ARRAY 128 OF CHAR;
	BEGIN {EXCLUSIVE}
		IF ~(Warnings IN parserOptions) THEN RETURN END;
		INC (warnings);
		IF warnings > MaxWarnings THEN
			RETURN
		ELSIF warnings = MaxWarnings THEN
			err := Diagnostics.Invalid; pos := Diagnostics.Invalid; str := "too many warnings"
		ELSE
			GetMessage (err, msg, str);
		END;
		IF diagnostics # NIL THEN
			diagnostics.Warning (source, pos, err, str);
		END;
	END Warning;

	PROCEDURE LogW* (ch: CHAR);
	BEGIN log.Char(ch)
	END LogW;

	PROCEDURE LogWStr* (CONST str: ARRAY OF CHAR);
	BEGIN  log.String(str)
	END LogWStr;

	PROCEDURE LogWStr0* (str: StringPool.Index);
	VAR str0: ARRAY 256 OF CHAR;
	BEGIN
		StringPool.GetString(str, str0); LogWStr(str0)
	END LogWStr0;

	PROCEDURE LogWHex* (i: LONGINT);
	BEGIN log.Hex(i, 0)
	END LogWHex;

	PROCEDURE LogWNum* (i: LONGINT);
	BEGIN log.Int(i, 0)
	END LogWNum;

	PROCEDURE LogWBool* (b: BOOLEAN);
	BEGIN
		IF b THEN LogWStr("TRUE") ELSE LogWStr("FALSE") END
	END LogWBool;

	PROCEDURE LogWType* (p: ANY);
		VAR name: ARRAY 32 OF CHAR;
	BEGIN
		PCDebug.GetTypeName(p, name); LogWStr(name)
	END LogWType;

	PROCEDURE LogWLn*;
	BEGIN log.Ln
	END LogWLn;

	PROCEDURE LogFlush*;
	BEGIN  log.Update
	END LogFlush;

(** ---------- configuration functions --------------------- *)

	(** Init - Prepare module for a new compilation *)

	PROCEDURE Init*(CONST s: ARRAY OF CHAR; l: Streams.Writer; d: Diagnostics.Diagnostics);	(* don't assume Reset is executed *)
	BEGIN
		COPY (s, source);
		log := l;
		IF log = NIL THEN Streams.OpenWriter( log, KernelLog.Send ) END;
		diagnostics := d;
		error := FALSE;
		errors := 0; warnings := 0;
		PCDebug.ResetToDo;
	END Init;

	(** Reset - allow deallocation of structures*)

	PROCEDURE Reset*;
	BEGIN
		PCDebug.ResetToDo;
	END Reset;

	(** SetErrorMsg - Set message for error n *)

	PROCEDURE SetErrorMsg*(n: LONGINT; CONST msg: ARRAY OF CHAR);
	BEGIN
		IF errMsg = NIL THEN NEW(errMsg, InitErrMsgSize) END;
		WHILE LEN(errMsg^) < n DO Expand(errMsg) END;
		StringPool.GetIndex(msg, errMsg[n])
	END SetErrorMsg;

	PROCEDURE Expand(VAR oldAry: ErrorMsgs);
	VAR
		len, i: LONGINT;
		newAry: ErrorMsgs;
	BEGIN
		IF oldAry = NIL THEN RETURN END;
		len := LEN(oldAry^);
		NEW(newAry, len * 2);
		FOR i := 0 TO len-1 DO
			newAry[i] := oldAry[i];
		END;
		oldAry := newAry;
	END Expand;

	PROCEDURE InitMod;
	BEGIN
		PCDebug.ResetToDo
	END InitMod;

PROCEDURE SwapBytes*(VAR p: ARRAY OF SYSTEM.BYTE; offset, len: LONGINT);
VAR i: LONGINT;
	tmp: SYSTEM.BYTE;
BEGIN
	FOR i := 0 TO (len-1) DIV 2 DO
		tmp := p[offset+i];
		p[offset+i] := p[offset+len-1-i];
		p[offset+len-1-i] := tmp;
	END;
END SwapBytes;

	PROCEDURE MakeErrorFile*;
	VAR f: Files.File; w: Files.Writer;
		msg, code: ARRAY 256 OF CHAR; i: LONGINT;
	BEGIN
		f := Files.New("Errors2.XML");
		IF f # NIL THEN
			Files.OpenWriter(w, f, 0);
			WHILE i < LEN(errMsg)-1 DO
				StringPool.GetString(errMsg[i], msg);
				w.String("    <Error code="); w.Char(CHR(34));
				Strings.IntToStr(i, code); w.String(code);
				w.Char(CHR(34)); w.String(">");
				w.String(msg);
				w.String("</Error>");
				w.Ln;
				INC(i);
			END;
			w.Update;
			Files.Register(f);
		ELSE
			KernelLog.String("Could not create file"); KernelLog.Ln;
		END;
	END MakeErrorFile;

(** fof >> *)
	PROCEDURE TracebackOnError*;
	BEGIN
		tracebackOnError := ~tracebackOnError;
		IF tracebackOnError THEN LogWStr( "TracebackOnError=TRUE" );  ELSE LogWStr( "TracebackOnError=FALSE" ) END;
		LogWLn;  LogFlush;
	END TracebackOnError;
(** << fof  *)

BEGIN
	Streams.OpenWriter( log, KernelLog.Send );
	InitMod;
	prefix := "";
	COPY(Modules.extension[0], suffix)
END PCM.

(*
	15.11.06	ug	new compiler option /S added, FileVersion incremented
	20.09.03	prk	"/Dcode" compiler option added
	24.06.03	prk	Remove TDMask (no need to mask typedescriptors)
	22.02.02	prk	unicode support
	22.01.02	prk	cosmetic changes, some constants renamed
	22.01.02	prk	ToDo list moved to PCDebug
	18.01.02	prk	AosFS used instead of Files
	10.12.01	prk	ENTIER: rounding mode set to chop, rounding modes caches as globals
	22.11.01	prk	improved flag handling
	19.11.01	prk	definitions
	23.07.01	prk	read error messages into stringpool
	05.07.01	prk	optional explicit NIL checks
	27.06.01	prk	StringPool cleaned up
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	17.05.01	prk	Delegates
	26.04.01	prk	separation of RECORD and OBJECT in the parser
	25.04.01	prk	array allocation: if length < 0 then trap PCM.ArraySizeTrap
	30.03.01	prk	object file version changed to 01X
	29.03.01	prk	Java imports
*)