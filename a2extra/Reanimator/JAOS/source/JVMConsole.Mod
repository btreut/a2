(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMConsole;

IMPORT
		AosOut, AosFS, AosPipes,
		JVMConverter, StringPool,
		UTF8Strings, JT := JVMTypes;

CONST
	ConsoleCapture = FALSE;
	LogCapture = FALSE;

	LogFile = "JVM.Log";
	CLogFile = "JVMConsole.Log";
	BufSize = 1000H;
	
		(** Logging kinds *)
	Failure* = 1; Error* = 2; Warning* = 3; Info* = 4; Status* = 5; Debug* = 6;
	
		(** Logging sources *)
	Compiler* = 1; Linker* = 2; Loader* = 3; VM* = 4; Graphics* = 5; Streams* = 6; Nio* = 7;

TYPE
	LoggingInfo* = RECORD kind*, source*: LONGINT END;

VAR
	ConsoleF, LogF: AosFS.File;	(* Debug *)
	
	(** low-level console functions - don't write to these, use the static functions! *)
	CR*: ARRAY 2 OF CHAR;
	writeLn*: PROCEDURE;
	writeBytes*: PROCEDURE(VAR buf: ARRAY OF CHAR; offset, count: LONGINT);
	
	(** the pipe containing the input characters in UTF8 format *)
	input*: AosPipes.Pipe;
	
	(** low-level logging functions - don't write to these, use the static functions! *)
	ln*: PROCEDURE;
	string*: PROCEDURE(str: ARRAY OF CHAR);
	char*: PROCEDURE(ch: CHAR);
	int*: PROCEDURE (x, n: LONGINT);
	hex*: PROCEDURE (x, w: LONGINT);
	
	kindFilter*, sourceFilter*: SET;
	
VAR
	(* Logging Functions *)
	
	PROCEDURE LogChar(f: AosFS.File; ch: CHAR);
		VAR r: AosFS.Rider;
	BEGIN
		f.Set(r, f.Length());
		f.Write(r, ch);
		f.Update()
	END LogChar;
	
	PROCEDURE LogString(f: AosFS.File; str: ARRAY OF CHAR);
		VAR r: AosFS.Rider; i: LONGINT;
	BEGIN
		f.Set(r, f.Length());
		i := 0;
		WHILE str[i] # 0X DO
			f.Write(r, str[i]); INC(i)
		END;
		f.Update()
	END LogString;
	
	PROCEDURE LogArray(f: AosFS.File; x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR r: AosFS.Rider; i: LONGINT;
	BEGIN
		f.Set(r, f.Length());
		FOR i := 0 TO len-1 DO
			f.Write(r, x[ofs+i])
		END;
		f.Update()
	END LogArray;
	
	(** Console Output Functions *)
	
	PROCEDURE WriteBytes*(VAR buf: ARRAY OF CHAR; offset, count: LONGINT);
	BEGIN
		IF ConsoleCapture THEN LogArray(ConsoleF, 0DX) END;
		IF writeBytes # NIL THEN writeBytes(buf, offset, count) END
	END WriteBytes;
	
	PROCEDURE WriteString*(str: ARRAY OF CHAR);
		VAR i: LONGINT;
	BEGIN
		i := 0; WHILE str[i] # 0X DO INC(i) END;
		WriteBytes(str, 0, i)
	END WriteString;
	
	PROCEDURE WriteInt*(x: LONGINT);
		VAR str: ARRAY 64 OF CHAR;
	BEGIN
		JVMConverter.IntToStr(x, str);
		WriteString(str)
	END WriteInt;

	PROCEDURE WriteLn*;
	BEGIN (*{EXCLUSIVE}*)
		IF ConsoleCapture THEN LogChar(ConsoleF, 0DX) END;
		IF writeLn # NIL THEN writeLn END
	END WriteLn;

	(* Default Console Output Functions *)
	
	PROCEDURE DefaultWriteBytes(VAR buf: ARRAY OF CHAR; offset, count: LONGINT);
		VAR i, res: LONGINT; dummy: BOOLEAN;
	BEGIN
		i := 0;
		WHILE i < count DO
			dummy := UTF8Strings.DecodeChar(buf, offset, res); INC(i);
			IF res > 255 THEN res := ORD("?") ELSIF res = 0AH THEN res := 0DH END;
			AosOut.Char(CHR(res))
		END;
	END DefaultWriteBytes;
	
	PROCEDURE DefaultWriteLn;
	BEGIN
		AosOut.Ln
	END DefaultWriteLn;

	(** Console Logging Functions *)
	
	PROCEDURE LogFilter(VAR info: LoggingInfo): BOOLEAN;
	BEGIN  RETURN (info.kind IN kindFilter) & (info.source IN sourceFilter);
	END LogFilter;
	
	PROCEDURE Ln*(VAR info: LoggingInfo);
	BEGIN
		IF LogCapture THEN LogChar(LogF, 0DX) END;
		IF LogFilter(info) & (ln # NIL) THEN ln END
	END Ln;
	
	PROCEDURE String*(VAR info: LoggingInfo; str: ARRAY OF CHAR);
	BEGIN
		IF LogCapture THEN LogString(LogF, str) END;
		IF LogFilter(info) & (string # NIL) THEN string(str) END
	END String;
	
	PROCEDURE Str*(VAR info: LoggingInfo; str: JT.String);
	VAR  str0: ARRAY 256 OF CHAR;
	BEGIN  JT.JavaToOberonString(str, 0, LEN(str), str0); String(info, str0)
	END Str;
	
	PROCEDURE StrIdx*(VAR info: LoggingInfo; str: StringPool.Index);
	VAR  str0: ARRAY 256 OF CHAR;
	BEGIN  StringPool.GetString(str, str0); String(info, str0)
	END StrIdx;
	
	PROCEDURE QualId*(info: LoggingInfo; class: JT.String; name: JT.String);
	BEGIN  Str(info, class); String(info, "."); Str(info, name)
	END QualId;

	PROCEDURE Char*(VAR info: LoggingInfo; ch: CHAR);
	BEGIN
		IF LogCapture THEN LogString(LogF, "<char>") END;
		IF LogFilter(info) & (char # NIL) THEN char(ch) END
	END Char;
		
	PROCEDURE Int*(VAR info: LoggingInfo; i, w: LONGINT);
	BEGIN
		IF LogCapture THEN LogString(LogF, "<int>") END;
		IF LogFilter(info) & (int # NIL) THEN int(i, w) END
	END Int;
	
	PROCEDURE Hex*(VAR info: LoggingInfo; i, w: LONGINT);
	BEGIN
		IF LogCapture THEN LogString(LogF, "<hex>") END;
		IF LogFilter(info) & (hex # NIL) THEN hex(i, w) END
	END Hex;
	
	(** ConsoleToDefault - send the console output to the default device *)
	
	PROCEDURE ConsoleToDefault*;
	BEGIN
		writeLn := DefaultWriteLn;
		writeBytes := DefaultWriteBytes;
		CR[0] := 0AX; CR[1] := 0X;
	END ConsoleToDefault;
	
	(** ConsoleToNone - send the console output to nowhere *)
	
	PROCEDURE ConsoleToNone*;
	BEGIN
		writeLn := NIL;
		writeBytes := NIL;
	END ConsoleToNone;
	
	(** LogToDefault - send the log to the default device *)
	
	PROCEDURE LogToDefault*;
	BEGIN
		ln := AosOut.Ln;
		string := AosOut.String;
		char := AosOut.Char;
		int := AosOut.Int;
		hex := AosOut.Hex;
	END LogToDefault;
	
	(** LogToNone - send the log to nowhere *)
	
	PROCEDURE LogToNone*;
	BEGIN
		ln := NIL; string := NIL; char := NIL; int := NIL; hex := NIL;
	END LogToNone;
	
	PROCEDURE Init;
		VAR f: AosFS.File;
	BEGIN
		IF ConsoleCapture THEN
			ConsoleF := AosFS.New(CLogFile);
			AosFS.Register(ConsoleF)
		END;
		IF LogCapture THEN
			LogF := AosFS.New(LogFile);
			AosFS.Register(LogF)
		END;
		
		NEW(input, 256);
	END Init;
		
BEGIN
(*
	kindFilter := {Failure, Error, Warning, Status, Debug}; sourceFilter := {0..31};
*)
	kindFilter := {0..31}; sourceFilter := {0..31};
	kindFilter := {Failure, Error, Warning};
	LogToDefault;
	ConsoleToDefault;
	
	IF ConsoleCapture THEN string("JVMConsole: Logging console to "); string(CLogFile); ln END;
	IF LogCapture THEN string("JVMConsole: Logging log to "); string(LogFile); ln END;
	Init
END JVMConsole.

(*
	11.01.04	prk	update to classpath 0.06
	15.08.03	prk	stdin support
	30.07.03	prk	Logging functions, add kind and source; filtering support
	12.02.03	prk	Logging functions, use same interface as AosOut
	02.01.03	prk	Aos 31.12.02 port
	11.01.02	prk	Aos 21.12.01 port
	16.09.01	prk	console redesign; input implemented; JVMByteBuffer removed
	27.05.01	prk	Logging improved
	21.05.01	prk	Store Console to file
	28.03.01	prk	ByteBuffer renamed to JVMByteBuffer
	26.03.01	prk	Adapted for Paco
*)