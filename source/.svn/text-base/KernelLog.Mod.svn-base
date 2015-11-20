(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE KernelLog; (** AUTHOR "pjm"; PURPOSE "Trace output for booting and debugging"; *)

(* AFI 12.03.2003 - procedure Init modified to obtain trace port info from Aos.Par i.o. being hardcoded. *)

IMPORT SYSTEM, Trace, Machine, Objects;

CONST
	BufSize = 8000;	(* default trace buffer size (usually overriden by System.StartLog or LogWindow.Open *)

VAR
	traceBufDef: ARRAY BufSize OF CHAR;	(* default trace buffer *)
	traceBufAdr: ADDRESS; traceBufSize: SIZE;	(* current trace buffer virtual addresses *)
	traceHead, traceTail: ADDRESS;
	column*: LONGINT;	(** hint for Traps *)

(** Send the specified characters to the trace output (cf. Streams.Sender). *)

PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
VAR next: ADDRESS; c: CHAR;
BEGIN
	INC(len, ofs);	(* len is now end position *)
	Machine.Acquire(Machine.TraceOutput);
	LOOP
		IF ofs >= len THEN EXIT END;
		c := buf[ofs];
		IF c = 0X THEN EXIT END;
		IF c = 0AX THEN column := 0 ELSE INC(column) END;
		next := (traceTail+1) MOD traceBufSize;
		IF next # traceHead THEN
			SYSTEM.PUT8(traceBufAdr+traceTail, c);
			traceTail := next
		ELSE	(* overwrite previous character with overflow signal *)
			SYSTEM.PUT8(traceBufAdr + (traceTail-1) MOD traceBufSize, 3X)
		END;
		Trace.Char (c);
		INC(ofs)
	END;
	Machine.Release(Machine.TraceOutput)
END Send;

(** Write a string to the trace output. *)

PROCEDURE String*(CONST s: ARRAY OF CHAR);
VAR len, n: LONGINT;
BEGIN
	len := 0; n := LEN(s);
	WHILE (len # n) & (s[len] # 0X) DO INC(len) END;
	Send(s, 0, len, FALSE, n)	(* ignore res *)
END String;

(** Skip to the next line on trace output. *)

PROCEDURE Ln*;
BEGIN Char (0DX); Char (0AX);
END Ln;

(** Write a character. *)

PROCEDURE Char*(c: CHAR);
TYPE Str = ARRAY 1 OF CHAR;
BEGIN
	String(SYSTEM.VAL(Str, c))
END Char;

(** Write "x" as a decimal number. "w" is the field width. *)

PROCEDURE Int*(x: HUGEINT; w: LONGINT);
VAR i: SIZE; x0: HUGEINT; a: ARRAY 21 OF CHAR;
BEGIN
	IF x < 0 THEN
		IF x = MIN(HUGEINT) THEN
			DEC(w, 20);
			WHILE w > 0 DO Char(" "); DEC(w) END;
			String ("-9223372036854775808");
			RETURN
		ELSE
			DEC(w); x0 := -x
		END
	ELSE
		x0 := x
	END;
	i := 0;
	REPEAT
		a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
	UNTIL x0 = 0;
	WHILE w > i DO Char(" "); DEC(w) END;
	IF x < 0 THEN Char("-") END;
	REPEAT DEC(i); Char(a[i]) UNTIL i = 0
END Int;

PROCEDURE Boolean*(x : BOOLEAN);
BEGIN
	IF x THEN String("TRUE") ELSE String("FALSE") END
END Boolean;

(** Write "x" as a decimal number with a power-of-two multiplier (K, M or G), followed by "suffix". "w" is the field width, excluding "suffix". *)

PROCEDURE IntSuffix*(x, w: LONGINT; CONST suffix: ARRAY OF CHAR);
CONST K = 1024; M = K*K; G = K*M;
VAR mult: CHAR;
BEGIN
	IF x MOD K # 0 THEN
		Int(x, w)
	ELSE
		IF x MOD M # 0 THEN mult := "K"; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := "M"; x := x DIV M
		ELSE mult := "G"; x := x DIV G
		END;
		Int(x, w-1); Char(mult)
	END;
	String(suffix)
END IntSuffix;
(*
(** Write "x" as a hexadecimal number. The absolute value of "w" is the field width. If "w" is negative, two hex digits are printed (x MOD 100H), otherwise 8 digits are printed. *)

PROCEDURE Hex*(x: HUGEINT; w: LONGINT);
VAR i, j: LONGINT; buf: ARRAY 10 OF CHAR;
BEGIN
	IF w >= 0 THEN j := 8 ELSE j := 2; w := -w END;
	FOR i := j+1 TO w DO Char(" ") END;
	FOR i := j-1 TO 0 BY -1 DO
		buf[i] := CHR(x MOD 10H + 48);
		IF buf[i] > "9" THEN
			buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
		END;
		x := x DIV 10H
	END;
	buf[j] := 0X;
	String(buf)
END Hex;
*)

(**	Write an integer in hexadecimal right-justified in a field of at least ABS(w) characters.
	If w < 0, the w least significant hex digits of x are written (potentially including leading zeros)
*)
PROCEDURE Hex*( x: HUGEINT;  w: LONGINT );
VAR filler: CHAR;  i, maxi, y: LONGINT;  buf: ARRAY 20 OF CHAR; 
BEGIN
	IF w < 0 THEN  filler := '0';  w := -w;  maxi := w  ELSE  filler := ' ';  maxi := 16  END;
	i := 0;
	REPEAT
		y := SHORT( x MOD 10H );
		IF y < 10 THEN  buf[i] := CHR( y + ORD('0') )  ELSE  buf[i] := CHR( y - 10 + ORD('A') )  END;
		x := x DIV 10H;
		INC( i );
	UNTIL (x = 0) OR (i = maxi);
	WHILE w > i DO  Char( filler );  DEC( w )  END;
	REPEAT  DEC( i ); Char( buf[i] )  UNTIL i = 0
END Hex;

(** Write "x" as a hexadecimal address. *)

PROCEDURE Address* (x: ADDRESS);
BEGIN 
	Hex(x, -SIZEOF(ADDRESS)*2)
END Address;

(** Write "x" as a hexadecimal number.  "w" is the field width.  Always prints 16 digits. *)

PROCEDURE HIntHex*(x: HUGEINT; w: LONGINT);
BEGIN
	Hex( x, w )
END HIntHex;

(** Write a block of memory in hex. *)

PROCEDURE Memory*(adr: ADDRESS; size: SIZE);
VAR i, j: ADDRESS; ch: CHAR;
BEGIN
	Char(0EX);	(* "fixed font" *)
	size := adr+size-1;
	FOR i := adr TO size BY 16 DO
		Address (i); Char (' ');
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET(j, ch);
				Hex(ORD(ch), -3)
			ELSE
				String("   ")
			END
		END;
		String(" ");
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET(j, ch);
				IF (ch < " ") OR (ch >= CHR(127)) THEN ch := "." END;
				Char(ch)
			END
		END;
		Ln
	END;
	Char(0FX)	(* "proportional font" *)
END Memory;

(** Write a buffer in hex. *)

PROCEDURE Buffer*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT);
BEGIN
	Memory(ADDRESSOF(buf[ofs]), len)
END Buffer;

(** Write bits (ofs..ofs+n-1) of x in binary. *)

PROCEDURE Bits*(x: SET; ofs, n: LONGINT);
BEGIN
	REPEAT
		DEC(n);
		IF (ofs+n) IN x THEN Char("1") ELSE Char("0") END
	UNTIL n = 0
END Bits;

(** write a set as set *)
PROCEDURE Set*(x: SET);
VAR first: BOOLEAN; i: LONGINT;
BEGIN
	first := TRUE;
	Char("{");
	FOR i := 0 TO MAX(SET) DO
		IF i IN x THEN
			IF ~first THEN Char(",") ELSE first := FALSE END;
			Int(i,1);
		END;
	END;
	Char("}");
END Set;

(** Enter mutually exclusive region for writing, using a fine-grained lock.  This region should be kept as short as possible, and only procedures from KernelLog should be called inside it. *)

PROCEDURE Enter*;
BEGIN
	Machine.Acquire(Machine.KernelLog);
	String("{P cpuid= "); Int(Machine.ID(), 0); String (", pid= "); Int (Objects.GetProcessID (), 0); Char (' ');
END Enter;

(** Exit mutually exclusive region for writing. *)

PROCEDURE Exit*;
BEGIN
	Char("}"); Ln;
	Machine.Release(Machine.KernelLog)
END Exit;

(* Switch to a new tracing buffer, copying the existing data. *)

PROCEDURE SwitchToBuffer(adr: ADDRESS; size: SIZE);
VAR tail: ADDRESS; c: CHAR;
BEGIN
	tail := 0; ASSERT(size > 0);
	WHILE (traceHead # traceTail) & (tail+1 # size) DO	(* source not empty, destination not full *)
		SYSTEM.GET (traceBufAdr + traceHead, c);
		SYSTEM.PUT (adr + tail, c);
		traceHead := (traceHead+1) MOD traceBufSize;
		INC(tail)
	END;
	traceBufAdr := adr; traceBufSize := size;
	traceHead := 0; traceTail := tail
END SwitchToBuffer;

(** Assign a new trace buffer.  Used by a display process. *)

PROCEDURE OpenBuffer*(adr: ADDRESS; size: SIZE): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
	Machine.Acquire(Machine.TraceOutput);
	IF traceBufAdr = ADDRESSOF(traceBufDef[0]) THEN
		SwitchToBuffer(adr, size); ok := TRUE
	ELSE
		ok := FALSE
	END;
	Machine.Release(Machine.TraceOutput);
	RETURN ok
END OpenBuffer;

(** Return output buffer contents.  Used by a display process. *)

PROCEDURE GetBuffer*(VAR val: ARRAY OF CHAR);
VAR i, m: LONGINT;
BEGIN
	i := 0; m := LEN(val)-1;
	Machine.Acquire(Machine.TraceOutput);
	WHILE (i < m) & (traceHead # traceTail) DO
		val[i] := CHR(SYSTEM.GET8(traceBufAdr + traceHead));
		traceHead := (traceHead+1) MOD traceBufSize;
		INC(i)
	END;
	Machine.Release(Machine.TraceOutput);
	val[i] := 0X
END GetBuffer;

(** Close the trace buffer and revert to the default.  Used by a display process. *)

PROCEDURE CloseBuffer*;
BEGIN
	Machine.Acquire(Machine.TraceOutput);
	IF traceBufAdr # ADDRESSOF(traceBufDef[0]) THEN
		SwitchToBuffer(ADDRESSOF(traceBufDef[0]), LEN(traceBufDef))
	END;
	Machine.Release(Machine.TraceOutput)
END CloseBuffer;

BEGIN
	traceBufAdr := ADDRESSOF(traceBufDef[0]);
	traceBufSize := LEN(traceBufDef);
	traceHead := 0; traceTail := 0; column := 0;
END KernelLog.

(**
Notes

This module provides low-level output facilities for Aos.  It is similar to the Out module of Oberon, but it can be called from anywhere, even from active object bodies and interrupt handlers.  It can write to the text display (when not using a graphics mode), a serial port, a memory buffer, or all of the above.  This is controlled by the TraceMode and related config strings (see Aos.Par).

Typically, a memory buffer is used.  The buffer is installed by the LogWindow.Open, or with the System.StartLog command when using Oberon.  The latter is recommended, as it also interprets traps specially and opens a new viewer for them.  The displaying of the buffer is done off-line by the LogWindow or Oberon threads, thereby allowing the procedures here to be called from anywhere.

Control characters:
0X	end of string (can not be printed)
1X	start of trap (if System.StartLog active then trap viewer will be opened and output redirected)
2X	end of trap (if System.StartLog active then it will revert output to the kernel log text)
3X	signal log overflow
9X	TAB (or single space)
0DX	CR (or NL and LF ignored)
0AX	LF (ignored if CR is NL)
0EX	set fixed-width font
0FX	set proportial font (default)
*)

(*
TraceMode:
0	1	Screen
2	4	V24
*)

(*
03.03.1998	pjm	First version
16.06.2000	pjm	Cleaned up
29.11.2000	pjm	buffering
12.06.2001	pjm	moved Flags to Traps, moved SegDesc and TSS to AosFragments
*)
