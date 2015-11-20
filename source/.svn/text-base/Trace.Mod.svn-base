MODULE Trace;	(** AUTHOR "fn"; PURPOSE "Low-level trace output based on KernelLog"; *)

IMPORT SYSTEM;

TYPE
	CharProc*= PROCEDURE (c:CHAR);
VAR
	Char*: CharProc;
	Color*: PROCEDURE (c: SHORTINT);

PROCEDURE Enter*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Enter;

PROCEDURE Exit*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Ln;
END Exit;

(** Send the specified characters to the trace output (cf. Streams.Sender). *)
PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN {UNCOOPERATIVE, UNCHECKED} INC (len, ofs); ASSERT (len <= LEN (buf)); WHILE ofs # len DO Char (buf[ofs]); INC (ofs); END; res := 0;
END Send;

(** Skip to the next line on trace output. *)
PROCEDURE Ln*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Char (0DX); Char (0AX);
END Ln;

(** Write a string to the trace output. *)
PROCEDURE String* (CONST s: ARRAY OF CHAR);
VAR i: LONGINT; c: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED} FOR i := 0 TO LEN (s) - 1 DO c := s[i]; IF c = 0X THEN RETURN END; Char (c) END;
END String;

(** Write a string to the trace output and skip to next line. *)
PROCEDURE StringLn* (CONST s: ARRAY OF CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED} String (s); Ln;
END StringLn;

(** Write a character. *)
PROCEDURE Int* (x: HUGEINT; w: LONGINT);
VAR i: SIZE; x0: HUGEINT; a: ARRAY 21 OF CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF x < 0 THEN
		IF x = MIN (HUGEINT) THEN
			DEC (w, 20);
			WHILE w > 0 DO Char (' '); DEC (w) END;
			String ("-9223372036854775808");
			RETURN
		ELSE
			DEC (w); x0 := -x
		END
	ELSE
		x0 := x
	END;
	i := 0;
	REPEAT
		a[i] := CHR (x0 MOD 10 + 30H); x0 := x0 DIV 10; INC (i)
	UNTIL x0 = 0;
	WHILE w > i DO Char (' '); DEC (w) END;
	IF x < 0 THEN Char ('-') END;
	REPEAT DEC (i); Char (a[i]) UNTIL i = 0
END Int;

PROCEDURE Boolean* (x : BOOLEAN);
BEGIN {UNCOOPERATIVE, UNCHECKED} IF x THEN String ("TRUE") ELSE String ("FALSE") END
END Boolean;

(** Write "x" as a decimal number with a power-of-two multiplier (K, M or G), followed by "suffix". "w" is the field width, excluding "suffix". *)
PROCEDURE IntSuffix* (x, w: LONGINT; CONST suffix: ARRAY OF CHAR);
CONST K = 1024; M = K*K; G = K*M;
VAR mult: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF x MOD K # 0 THEN
		Int (x, w)
	ELSE
		IF x MOD M # 0 THEN mult := 'K'; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := 'M'; x := x DIV M
		ELSE mult := 'G'; x := x DIV G
		END;
		Int (x, w-1); Char (mult)
	END;
	String (suffix)
END IntSuffix;

(**
	Write an integer in hexadecimal right-justified in a field of at least ABS(w) characters.
	If w < 0 THEN w least significant hex digits of x are written (possibly including leading zeros)
*)
PROCEDURE Hex*(x: HUGEINT; w: LONGINT );
VAR i: LONGINT;
	buf: ARRAY 2*SIZEOF(HUGEINT)+2 OF CHAR;
	neg: BOOLEAN;
	c: HUGEINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF w >= 0 THEN
		i:= 0;
		IF x < 0 THEN neg := TRUE; x :=-x ELSIF x=0 THEN buf := "0" ELSE neg := FALSE END;
		i := 0;
		REPEAT
			c := x MOD 10H;
			IF c < 10 THEN buf[i] := CHR(c+ORD("0")) ELSE buf[i] := CHR(c-10+ORD("A")) END;
			x := x DIV 10H;
			INC(i);
		UNTIL (i = 2 * SIZEOF(HUGEINT)) OR (x=0);
		IF c > 9 THEN buf[i] := "0"; INC(i) END;
		IF neg THEN buf[i] := "-"; INC(i) END;
		WHILE(w > i) DO Char(" "); DEC(w); END;
		REPEAT DEC(i); Char(buf[i]); UNTIL i=0;
	ELSE
		w := -w;
		WHILE(w>2*SIZEOF(HUGEINT)) DO
			Char(" "); DEC(w);
		END;
		buf[w] := 0X;
		REPEAT
			DEC(w);
			c := x MOD 10H;
			IF c <10 THEN buf[w] := CHR(c+ORD("0")) ELSE buf[w] := CHR(c-10+ORD("A")) END;
			x := x DIV 10H;
		UNTIL w = 0;
		String(buf);
	END;

END Hex;

(** Write "x" as a hexadecimal address *)
PROCEDURE Address* (x: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Hex(x,-2*SIZEOF(ADDRESS));
END Address;

(** Write "x" as a hexadecimal number. "w" is the field width. Always prints 16 digits. *)
PROCEDURE HIntHex* (x: HUGEINT; w: LONGINT);
BEGIN {UNCOOPERATIVE, UNCHECKED} Hex (x, w);
END HIntHex;

(** Write a block of memory in hex. *)
PROCEDURE Memory* (adr: ADDRESS; size: SIZE);
VAR i, j: ADDRESS; ch: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	size := adr+size-1;
	FOR i := adr TO size BY 16 DO
		Address (i); Char (' ');
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET (j, ch);
				Char(' ');
				Hex (ORD (ch), -2)
			ELSE
				Char (' ');
				Char (' ');
				Char (' ');
			END
		END;
		Char (' '); Char (' ');
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET (j, ch);
				IF (ch < ' ') OR (ch >= CHR (127)) THEN ch := '.' END;
				Char (ch)
			END
		END;
		Ln
	END;
END Memory;

(* Write basic stack frame information *)
PROCEDURE StackFrames- (skip, count, size: SIZE);
VAR frame {UNTRACED}: POINTER {UNSAFE} TO RECORD descriptor, previous, caller, parameters: ADDRESS END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	frame := ADDRESS OF frame + SIZE OF ADDRESS;
	WHILE skip # 0 DO
		frame := frame.previous;
		IF frame = NIL THEN RETURN END;
		DEC (skip);
	END;
	WHILE count # 0 DO
		Address (frame.caller); Char (':'); Ln;
		IF frame.previous = NIL THEN RETURN END;
		IF frame.previous - ADDRESS OF frame.descriptor <= size THEN
			Memory (ADDRESS OF frame.parameters, frame.previous - ADDRESS OF frame.descriptor);
		ELSIF size # 0 THEN
			Memory (ADDRESS OF frame.parameters, size); String ("..."); Ln;
		END;
		DEC (count); frame := frame.previous;
	END;
	WHILE frame.previous # NIL DO INC (count); frame := frame.previous END;
	IF count # 0 THEN Char ('+'); Int (count, 0); Ln; END;
END StackFrames;

(** Write a buffer in hex. *)
PROCEDURE Buffer* (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT);
BEGIN {UNCOOPERATIVE, UNCHECKED} Memory (ADDRESSOF (buf[ofs]), len)
END Buffer;

(** Write bits (ofs..ofs+n-1) of x in binary. *)
PROCEDURE Bits* (x: SET; ofs, n: LONGINT);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT
		DEC (n);
		IF (ofs+n) IN x THEN Char ('1') ELSE Char ('0') END
	UNTIL n = 0
END Bits;

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


(** Colors *)
PROCEDURE Blue*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Color (9);
END Blue;

PROCEDURE Green*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Color (10);
END Green;

PROCEDURE Red*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Color (12);
END Red;

PROCEDURE Yellow*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Color (14);
END Yellow;

PROCEDURE Default*;
BEGIN {UNCOOPERATIVE, UNCHECKED} Color (7);
END Default;

PROCEDURE NullChar(c: CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
END NullChar;

PROCEDURE NullColor(c: SHORTINT);
BEGIN {UNCOOPERATIVE, UNCHECKED}
END NullColor;

PROCEDURE Init*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Char := NullChar;
	Color := NullColor;	
END Init;


(*
BEGIN
	Char := NullChar;
	Color := NullColor;
	*)
END Trace.

