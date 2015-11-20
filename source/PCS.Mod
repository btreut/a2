(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCS; (** AUTHOR "prk"; PURPOSE "Parallel Compiler: scanner"; *)

	IMPORT
		Streams, Texts, UTF8Strings, StringPool, PCM;

	CONST
		Trace = FALSE;

		MaxStrLen* = 256;
		MaxIdLen = 32;

	TYPE
		Name* = StringPool.Index;
		String* = ARRAY MaxStrLen OF CHAR;

		Buffer = POINTER TO ARRAY OF CHAR;

		Token* = SHORTINT;

	CONST
		Eot* = 0X;
		ObjectMarker = 020X;

		(* numtyp values *)
		char* = 1; integer* = 2; longinteger* = 3; real* = 4; longreal* = 5;
(*	Oberon-1
	ProgTools.Enum 0 *
		null
		times slash div mod and
		plus minus or eql neq  lss leq gtr geq in is
		arrow period comma
		colon upto rparen rbrak rbrace
		of then do to by
		lparen lbrak lbrace
		not
		becomes
		number nil true false string
		ident semicolon bar end else
		elsif until if case while
		repeat for loop with exit passivate return
		refines implements
		array definition object record pointer begin code
		const type var procedure import
		module eof
		~

	OberonX
	ProgTools.Enum 0 *
		null

		times times0 times1 times2 times3 times4 times5 times6 times7
		slash slash0 slash1 slash2 slash3 slash4 slash5 slash6 slash7
		div mod and

		plus plus0 plus1 plus2 plus3 plus4 plus5 plus6 plus7
		minus minus0 minus1 minus2 minus3 minus4 minus5 minus6 minus7
		or

		eql neq  lss leq gtr geq in is

		arrow period comma
		colon upto rparen rbrak rbrace
		of then do to by
		lparen lbrak lbrace
		not percent backslash
		becomes
		number nil self true false string
		ident semicolon bar end else
		elsif until if case while
		repeat for loop with exit passivate
		return array record pointer begin code
		const type var procedure import
		module eof
		~

*)
	null* =   0; times* =   1; slash* =   2; div* =   3; mod* =   4; and* =   5;
	plus* =   6; minus* =   7; or* =   8; eql* =   9; neq* =  10; lss* =  11;
	leq* =  12; gtr* =  13; geq* =  14; in* =  15; is* =  16; arrow* =  17;
	period* =  18; comma* =  19; colon* =  20; upto* =  21; rparen* =  22;
	rbrak* =  23; rbrace* =  24; of* =  25; then* =  26; do* =  27; to* =  28;
	by* =  29; lparen* =  30; lbrak* =  31; lbrace* =  32; not* =  33;
	becomes* =  34; number* =  35; nil* =  36; true* =  37; false* =  38;
	string* =  39; ident* =  40; semicolon* =  41; bar* =  42; end* =  43;
	else* =  44; elsif* =  45; until* =  46; if* =  47; case* =  48; while* =  49;
	repeat* =  50; for* =  51; loop* =  52; with* =  53; exit* =  54;
	passivate* =  55; return* =  56; refines* =  57; implements* =  58;
	array* =  59; definition* =  60; object* =  61; record* =  62; pointer* =  63;
	begin* =  64; code* =  65; const* =  66; type* =  67; var* =  68;
	procedure* =  69; import* =  70; module* =  71; eof* =  72; finally* = 73;
	(** fof special operators on arrays >> *)
	backslash* = 74; (* a \ b *)
	scalarproduct* = 75; (*  a +* b  *)
	elementproduct* = 76;   (* a .* b *)
	elementquotient* = 77;  (* a ./ b *)
	dtimes*=78;  (* a ** b *)
	transpose*=79;  (* A` *)
	eeql*=80;  (* a .= b *)
	eneq*=81; (* a .# b *)
	elss* = 82; (* a .< b *)
	eleq* = 83;  (* a .<= b *)
	egtr* = 84; (* a .> b *)
	egeq* = 85;  (* a .>= b *)
	qmark*=86;   (* ? *)
	(** << fof  *)

VAR
	opTable: ARRAY 86 OF Name; (* opTable: ARRAY 73 OF Name;*)
	reservedChar-, newChar: ARRAY 256 OF BOOLEAN;

TYPE
	Scanner* = OBJECT
		VAR
			buffer: Buffer;
			pos: LONGINT;	(*pos in buffer*)
			ch-: CHAR;	(**look-ahead *)
			name-: Name;
			str*: String;
			numtyp-: INTEGER; (* 1 = char, 2 = integer, 3 = real, 4 = longreal *)
			intval-: LONGINT;	(* integer value or string length *)
			longintval-: HUGEINT;
			realval-: REAL;
			lrlval-: LONGREAL;
			numStartPos, numEndPos: LONGINT;
			curpos-, errpos-: LONGINT;	(*pos in text*)
			isNummer: BOOLEAN;

			(* fof 070731 *)
			lcase-,ucase-: BOOLEAN;  (* lcase=true: recognize lowercase keywords , ucase=true: recognize uppercase keywords*)
			firstId: BOOLEAN;  n1: CHAR;

		PROCEDURE err(n: INTEGER);
		BEGIN PCM.Error(n, errpos, "")
		END err;

		PROCEDURE NextChar*;
		BEGIN
			(*REPEAT*)
				IF pos < LEN(buffer) THEN
					ch := buffer[pos]; INC(pos)
				ELSE
					ch := Eot
				END;
			(*UNTIL (ch # ObjectMarker);*)

			IF newChar[ORD(ch)] THEN INC(curpos) END; (* curpos := pos; *)
		END NextChar;

		PROCEDURE SkipUntilNextEnd*(VAR sym: SHORTINT);
		BEGIN
			WHILE (sym # eof) & (sym # end) DO
				IF ch = Eot THEN sym := eof
				ELSIF ch <= ' ' THEN NextChar;
				ELSE Identifier (sym, FALSE);
					IF ucase & (str = "END") OR ~ucase & (str = "end") THEN sym := end END;
				END;
			END;
		END SkipUntilNextEnd;

		PROCEDURE Str(VAR sym: SHORTINT);
			VAR i: INTEGER; och: CHAR;
		BEGIN i := 0; och := ch;
			LOOP NextChar;
				IF ch = och THEN EXIT END ;
				IF ch < " " THEN err(3); EXIT END ;
				IF i = MaxStrLen-1 THEN err(241); EXIT END ;
				str[i] := ch; INC(i)
			END ;
			NextChar; str[i] := 0X; intval := i + 1;
			IF intval = 2 THEN
				sym := number; numtyp := 1; intval := ORD(str[0])
			ELSE sym := string
			END
		END Str;

		PROCEDURE Identifier(VAR sym: SHORTINT; check: BOOLEAN);
			VAR i: LONGINT;
		BEGIN i := 0;
			REPEAT
				str[i] := ch; INC(i); NextChar
(*			UNTIL ((ch < "0") OR ("9" < ch)) & (CAP(ch) < "A") OR ("Z" < CAP(ch)) & (ch # '_') OR (i = MaxIdLen); *)
			UNTIL reservedChar[ORD(ch)] OR (i = MaxIdLen);
			IF i = MaxIdLen THEN IF check THEN err(240) END; DEC(i) END ;
			str[i] := 0X; sym := ident;
		END Identifier;

		PROCEDURE Number;
		VAR i, m, n, d, e: INTEGER; dig: ARRAY 24 OF CHAR; f: LONGREAL; expCh: CHAR; neg: BOOLEAN; longintval: HUGEINT;

			PROCEDURE Ten(e: INTEGER): LONGREAL;
				VAR x, p: LONGREAL;
			BEGIN x := 1; p := 10;
				WHILE e > 0 DO
					IF ODD(e) THEN x := x*p END;
					e := e DIV 2;
					IF e > 0 THEN p := p*p END (* prevent overflow *)
				END;
				RETURN x
			END Ten;

			PROCEDURE Ord(ch: CHAR; hex: BOOLEAN): INTEGER;
			BEGIN (* ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") *)
				IF ch <= "9" THEN RETURN ORD(ch) - ORD("0")
				ELSIF hex THEN RETURN ORD(ch) - ORD("A") + 10
				ELSE err(2); RETURN 0
				END
			END Ord;

		BEGIN (* ("0" <= ch) & (ch <= "9") *)
			i := 0; m := 0; n := 0; d := 0;
			LOOP (* read mantissa *)
				IF ("0" <= ch) & (ch <= "9") OR (d = 0) & ("A" <= ch) & (ch <= "F") THEN
					IF (m > 0) OR (ch # "0") THEN (* ignore leading zeros *)
						IF n < LEN(dig) THEN dig[n] := ch; INC(n) END;
						INC(m)
					END;
					NextChar; INC(i)
				ELSIF ch = "." THEN NextChar;
					IF ch = "." THEN (* ellipsis *) ch := 7FX; EXIT
					ELSIF d = 0 THEN (* i > 0 *) d := i
					ELSE err(2)
					END
				ELSE EXIT
				END
			END; (* 0 <= n <= m <= i, 0 <= d <= i *)
			IF d = 0 THEN (* integer *)
				IF n = m THEN intval := 0; i := 0; longintval := 0;
					IF ch = "X" THEN (* character *) NextChar; numtyp := char;
						IF PCM.LocalUnicodeSupport & (n <= 8) THEN
							IF (n = 8) & (dig[0] > "7") THEN (* prevent overflow *) intval := -1 END;
							WHILE i < n DO intval := intval*10H + Ord(dig[i], TRUE); INC(i) END
						ELSIF ~PCM.LocalUnicodeSupport & (n <= 2) THEN
							WHILE i < n DO intval := intval*10H + Ord(dig[i], TRUE); INC(i) END
						ELSE err(203)
						END
					ELSIF ch = "H" THEN (* hexadecimal *) NextChar; numtyp := longinteger;
						IF n > PCM.MaxHHDig THEN err (203) END;
						WHILE i < n DO d := Ord(dig[i], TRUE); INC(i);
							longintval := longintval * 10H + d
						END;
						intval := SHORT (longintval);
						IF intval = longintval THEN numtyp := integer END;
					ELSE (* decimal *) numtyp := longinteger;
						WHILE i < n DO d := Ord(dig[i], FALSE); INC(i);
							longintval := longintval * 10 + d;
							IF longintval < 0 THEN err(203) END;
						END;
						intval := SHORT (longintval);
						IF intval = longintval THEN numtyp := integer END;
					END
				ELSE err(203)
				END
			ELSE (* fraction *)
				f := 0; e := 0; expCh := "E";
				WHILE n > 0 DO (* 0 <= f < 1 *) DEC(n); f := (Ord(dig[n], FALSE) + f)/10 END;
				IF (ch = "E") OR (ch = "D") THEN expCh := ch; NextChar; neg := FALSE;
					IF ch = "-" THEN neg := TRUE; NextChar
					ELSIF ch = "+" THEN NextChar
					END;
					IF ("0" <= ch) & (ch <= "9") THEN
						REPEAT n := Ord(ch, FALSE); NextChar;
							IF e <= (MAX(INTEGER) - n) DIV 10 THEN e := e*10 + n
							ELSE err(203)
							END
						UNTIL (ch < "0") OR ("9" < ch);
						IF neg THEN e := -e END
					ELSE err(2)
					END
				END;
				DEC(e, i-d-m); (* decimal point shift *)
				IF expCh = "E" THEN numtyp := real;
					IF (1-PCM.MaxRExp < e) & (e <= PCM.MaxRExp) THEN
						IF e < 0 THEN realval := SHORT(f / Ten(-e))
						ELSE realval := SHORT(f * Ten(e))
						END
					ELSE err(203)
					END
				ELSE numtyp := longreal;
					IF (1-PCM.MaxLExp < e) & (e <= PCM.MaxLExp) THEN
						IF e < 0 THEN lrlval := f / Ten(-e)
						ELSE lrlval := f * Ten(e)
						END
					ELSE err(203)
					END
				END
			END;
			SELF.longintval := longintval;
		END Number;

		PROCEDURE GetNumAsString*(VAR val: ARRAY OF CHAR);
		VAR i, l: LONGINT;
		BEGIN
			(*Strings.Copy(buffer^, numStartPos, numEndPos-numStartPos, val);*)
			IF isNummer THEN
				i := 0; l := LEN(val)-1;
				WHILE (i < numEndPos-numStartPos) & (i < l) DO
					val[i] := buffer[numStartPos + i];
					INC(i);
				END;
			END;
			val[i] := 0X
		END GetNumAsString;

		PROCEDURE Get*(VAR s: SHORTINT);

			PROCEDURE Comment;	(* do not read after end of file *)
				VAR dump: BOOLEAN;
			BEGIN NextChar;
				IF ch = "#" THEN dump := TRUE; PCM.LogWLn END;	(* implementation-specific feature *)
				LOOP
					LOOP
						WHILE ch = "(" DO NextChar;
							IF ch = "*" THEN Comment ELSIF dump THEN PCM.LogW ("(") END
						END ;
						IF ch = "*" THEN NextChar; EXIT END ;
						IF ch = Eot THEN EXIT END ;
						IF dump THEN PCM.LogW (ch) END;
						NextChar
					END ;
					IF ch = ")" THEN NextChar; EXIT END ;
					IF dump THEN PCM.LogW ("*") END;
					IF ch = Eot THEN err(5); EXIT END
				END
			END Comment;

		BEGIN
			REPEAT
				WHILE ch <= " " DO (*ignore control characters*)
					IF ch = Eot THEN
						IF Trace THEN
							PCM.LogWLn; PCM.LogWStr("Scan ");
							PCM.LogWNum((*curpos*)pos); 			(*reader version*)
							PCM.LogWHex(eof)
						END;
						s := eof; RETURN
					ELSE NextChar
					END
				END ;
				(* errpos := (*curpos*)pos-1;			(*reader version*) *)
				errpos := curpos - 1;
				isNummer := FALSE;
				CASE ch OF   (* ch > " " *)
					| 22X, 27X  : Str(s)
					| "#"  : s := neq; NextChar
					| "&"  : s :=  and; NextChar
					| "("  : NextChar;
									 IF ch = "*" THEN Comment; (*GlobalGet; RETURN*) s := -1;		(*allow recursion without reentrancy*)
										 ELSE s := lparen
									 END
					| ")"  : s := rparen; NextChar
					| "*"  : NextChar; IF ch = "*" THEN NextChar;  s := dtimes;  ELSE s := times END; (* fof *)
					| "+"  : NextChar;  IF ch = "*" THEN NextChar;  s := scalarproduct;  ELSE s := plus END;  (* fof *)
					| ","  : s := comma; NextChar
					| "-"  : s :=  minus; NextChar
					| "."  : NextChar;
						IF ch = "." THEN NextChar; s := upto
						(** fof >> *)
						ELSIF ch = "*" THEN
							NextChar;  s := elementproduct (*fof*)
						ELSIF ch = "/" THEN
							NextChar;  s := elementquotient
						ELSIF ch="=" THEN
							NextChar; s := eeql
						ELSIF ch="#" THEN
							NextChar; s := eneq
						ELSIF ch=">" THEN
							NextChar;
							IF ch="=" THEN
							s := egeq; NextChar;
							ELSE
							s := egtr
							END;
						ELSIF ch="<" THEN
							NextChar;
							IF ch="=" THEN
							s := eleq; NextChar;
							ELSE
							s := elss
							END;
							(** << fof  *)
						ELSE s := period END
					| "/"  : s :=  slash; NextChar
					(** fof >> *)
					| "\":     s := backslash;  NextChar
					| "`":	s := transpose; NextChar;
					| "?": s := qmark; NextChar;
					(** << fof  *)
					| "0".."9": isNummer := TRUE; numStartPos := pos-1; Number; numEndPos := pos-1; s := number
					| ":"  : NextChar;
									 IF ch = "=" THEN NextChar; s := becomes ELSE s := colon END
					| ";"  : s := semicolon; NextChar
					| "<"  : NextChar;
									 IF ch = "=" THEN NextChar; s := leq; ELSE s := lss; END
					| "="  : s :=  eql; NextChar
					| ">"  : NextChar;
									 IF ch = "=" THEN NextChar; s := geq; ELSE s := gtr; END
						(* fof 070731 *)
					| "A".."Z":
					Identifier(s, TRUE);  n1 := str[0];
					IF ucase THEN
					n1 := str[0];
						CASE n1 OF
						| "A":
								IF str = "ARRAY" THEN s := array
								ELSIF str = "AWAIT" THEN s := passivate
								END
						| "B":
								IF str = "BEGIN" THEN s := begin
								ELSIF str = "BY" THEN s := by
								END
						| "C":
								IF str = "CONST" THEN s := const
								ELSIF str = "CASE" THEN s := case
								ELSIF str = "CODE" THEN s := code
								END
						| "D":
								IF str = "DO" THEN s := do
								ELSIF str = "DIV" THEN s := div
								ELSIF str = "DEFINITION" THEN s := definition
								END
						| "E":
								IF str = "END" THEN s := end
								ELSIF str = "ELSE" THEN s := else
								ELSIF str = "ELSIF" THEN s := elsif
								ELSIF str = "EXIT" THEN s := exit
								END
						| "F":
								IF str = "FALSE" THEN s := false
								ELSIF str = "FOR" THEN s := for
								ELSIF str = "FINALLY" THEN s := finally
								END
						| "I":
								IF str = "IF" THEN s := if
								ELSIF str = "IN" THEN s := in
								ELSIF str = "IS" THEN s := is
								ELSIF str = "IMPORT" THEN s := import
								ELSIF str = "IMPLEMENTS" THEN s := implements
								END
						| "L":
								IF str = "LOOP" THEN s := loop END
						| "M":
								IF str = "MOD" THEN s := mod
								ELSIF str = "MODULE" THEN s := module;  lcase := FALSE; (* fof *)
								END
						| "N":
								IF str = "NIL" THEN s := nil
								END
						| "O":
								IF str = "OR" THEN s := or
								ELSIF str = "OF" THEN s := of
								ELSIF str = "OBJECT" THEN s := object
								END
						| "P":
								IF str = "PROCEDURE" THEN s := procedure
								ELSIF str = "POINTER" THEN s := pointer
								END
						| "R":
								IF str = "RECORD" THEN s := record
								ELSIF str = "REPEAT" THEN s := repeat
								ELSIF str = "RETURN" THEN s := return
								ELSIF str = "REFINES" THEN s := refines
								END
						| "T":
								IF str = "THEN" THEN s := then
								ELSIF str = "TRUE" THEN s := true
								ELSIF str = "TO" THEN s := to
								ELSIF str = "TYPE" THEN s := type
								END
						| "U":
								IF str = "UNTIL" THEN s := until END
						| "V":
								IF str = "VAR" THEN s := var END
						| "W":
								IF str = "WHILE" THEN s := while
								ELSIF str = "WITH" THEN s := with
								END
					(* fof 070731 *)
						ELSE
						END;
					END;
					| "a".."z":
				Identifier(s, TRUE);
				IF lcase THEN
					n1 := str[0];
					CASE n1 OF
									| "a":   IF str = "array" THEN s := array
											ELSIF str = "await" THEN s := passivate
											END
								| "b":   IF str = "begin" THEN s := begin
											ELSIF str = "by" THEN s := by
											END
								| "c":   IF str = "const" THEN s := const
											ELSIF str = "case" THEN s := case
											ELSIF str = "code" THEN s := code
											END
								| "d":   IF str = "do" THEN s := do
											ELSIF str = "div" THEN s := div
											ELSIF str = "definition" THEN s := definition
											END
								| "e":   IF str = "end" THEN s := end
											ELSIF str = "else" THEN s := else
											ELSIF str = "elsif" THEN s := elsif
											ELSIF str = "exit" THEN s := exit
											END
								| "f":    IF str = "false" THEN s := false
											ELSIF str = "for" THEN s := for
											ELSIF str = "finally" THEN s := finally
											END
								| "i":    IF str = "if" THEN s := if
											ELSIF str = "in" THEN s := in
											ELSIF str = "is" THEN s := is
											ELSIF str = "import" THEN s := import
											ELSIF str = "implements" THEN s := implements
											END
								| "l":    IF str = "loop" THEN s := loop END
								| "m":  IF str = "mod" THEN s := mod
											ELSIF str = "module" THEN s := module; ucase := FALSE;
											END
								| "n":   IF str = "nil" THEN s := nil
											END
								| "o":   IF str = "or" THEN s := or
											ELSIF str = "of" THEN s := of
											ELSIF str = "object" THEN s := object
											END
								| "p":   IF str = "procedure" THEN s := procedure
											ELSIF str = "pointer" THEN s := pointer
											END
								| "r":    IF str = "record" THEN s := record
											ELSIF str = "repeat" THEN s := repeat
											ELSIF str = "return" THEN s := return
											ELSIF str = "refines" THEN s := refines
											END
								| "t":   IF str = "then" THEN s := then
											ELSIF str = "true" THEN s := true
											ELSIF str = "to" THEN s := to
											ELSIF str = "type" THEN s := type
											END
								| "u":   IF str = "until" THEN s := until END
								| "v":   IF str = "var" THEN s := var END
								| "w":  IF str = "while" THEN s := while
											ELSIF str = "with" THEN s := with
											END
								ELSE
								END;
								IF firstId & (s # module) THEN  lcase := FALSE;  s := ident  END;
							END
					| "["  : s := lbrak; NextChar
					| "]"  : s := rbrak; NextChar
					| "^"  : s := arrow; NextChar
					| "{"  : s := lbrace; NextChar
					| "|"  : s := bar; NextChar
					| "}"  : s := rbrace; NextChar
					| "~"  : s := not; NextChar
					| 7FX  : s := upto; NextChar
				ELSE s := null; NextChar;
				END ;
			UNTIL s >= 0;
			firstId := FALSE; (*fof*)

			IF s = ident THEN StringPool.GetIndex(str, name) END;

			IF Trace THEN
				PCM.LogWLn; PCM.LogWStr("Scan ");
				PCM.LogWNum(errpos); PCM.LogWHex(s);
			END;
		END Get;

		PROCEDURE IsOperatorValid*(): BOOLEAN;
		VAR
			ch0, ch1, ch2: CHAR;
		BEGIN
			ch0 := str[0]; ch1 := str[1]; ch2 := str[2];
			CASE str[0] OF
			| "=", "#", "&": RETURN ch1 = 0X
			| "<", ">": RETURN (ch1 = 0X) OR ((ch1 = "=") & (ch2 = 0X))  	(* <, <=, >, >= *)
			| "I": RETURN str= "IN"  	(* IN *)
			| "D": RETURN str="DIV"  	(* DIV *)
			| "M": RETURN str="MOD"  	(* MOD *)
			| "O": RETURN str="OR"  	(* OR *)
			| "+":  RETURN (ch1=0X) OR (ch2=0X) & (ch1="*")
			| "-":  RETURN (ch1=0X)
			| "*":  RETURN (ch1=0X) OR (ch2=0X) & (ch1="*")
			| "/" : RETURN (ch1=0X)
			| "~": RETURN (ch1=0X)
			| ":": RETURN str=":="
			| "[": RETURN str = "[]" (* Indexer *)
			| "\": RETURN ch1=0X
			| "`": RETURN ch1=0X
			| ".": RETURN (str=".=") OR (str=".#") OR (str=".<") OR (str=".>") OR (str=".<=") OR (str=".>=") OR (str=".*") OR (str = "./");
			ELSE RETURN FALSE
			END;
		END IsOperatorValid;

	END Scanner;

	PROCEDURE GetOpName*(op: SHORTINT; VAR name: Name);
	BEGIN
		name := opTable[op];
	END GetOpName;

	(** Create a new scanner at the same position *)
	PROCEDURE ForkScanner* (s: Scanner): Scanner;
	VAR t: Scanner;
	BEGIN
		NEW(t);
		t^ := s^;
		RETURN t
	END ForkScanner;
(*
	PROCEDURE SaveBuffer(b: Buffer);
		VAR f: Files.File; r: Files.Rider;
	BEGIN
		f := Files.New("SillyFile.bin");
		f.Set(r, 0);
		f.WriteBytes(r, b^, 0, LEN(b^));
		Files.Register(f);
	END SaveBuffer;
*)
	PROCEDURE NewScanner(b: Buffer;  pos, curpos: LONGINT): Scanner;
	VAR s: Scanner;
	BEGIN
(*
		SaveBuffer(b);
*)
		NEW(s);
		s.buffer := b;
		s.pos := pos;
		s.curpos := curpos;
		s.ch := " ";
		s.lcase := TRUE;  s.ucase := TRUE; s.firstId := TRUE; (* fof 070731 *)
		RETURN s
	END NewScanner;

	PROCEDURE InitWithText*(t: Texts.Text; pos: LONGINT): Scanner;
		VAR buffer: Buffer; len, i, j, ch: LONGINT; r: Texts.TextReader;
		bytesPerChar: LONGINT;
	BEGIN
		t.AcquireRead;
		len := t.GetLength();
		bytesPerChar := 2;
		NEW(buffer, len * bytesPerChar);	(* UTF8 encoded characters use up to 5 bytes *)
		NEW(r, t);
		r.SetPosition(pos);
		j := 0;
		FOR i := 0 TO len-1 DO
			r.ReadCh(ch);
			WHILE ~UTF8Strings.EncodeChar(ch, buffer^, j) DO
					(* buffer too small *)
				INC(bytesPerChar);
				ExpandBuf(buffer, bytesPerChar * len);
			END;
		END;
		t.ReleaseRead;
		RETURN NewScanner(buffer, pos, 0);
	END InitWithText;

	PROCEDURE ExpandBuf(VAR oldBuf: Buffer; newSize: LONGINT);
	VAR newBuf: Buffer; i: LONGINT;
	BEGIN
		IF LEN(oldBuf^) >= newSize THEN RETURN END;
		NEW(newBuf, newSize);
		FOR i := 0 TO LEN(oldBuf^)-1 DO
			newBuf[i] := oldBuf[i];
		END;
		oldBuf := newBuf;
	END ExpandBuf;

	PROCEDURE InitWithReader*(r: Streams.Reader; size, pos: LONGINT): Scanner;
		VAR buffer: Buffer; read: LONGINT;
	BEGIN
		NEW(buffer, size);
		r.Bytes(buffer^, 0, size, read);
		RETURN NewScanner(buffer, 0, pos)
	END InitWithReader;

(*
	PROCEDURE InitReservedCharsOld;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(reservedChar)-1 DO
			IF (CHR(i) < "0") OR ("9" < CHR(i)) & (CHR(i) < "A") OR ("Z"< CHR(i)) & (CHR(i) < "a") OR ("z" < CHR(i)) THEN
				reservedChar[i] := TRUE;
			ELSE
				reservedChar[i] := FALSE;
			END;
		END;
	END InitReservedCharsOld;
*)

	PROCEDURE InitReservedChars;
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(reservedChar)-1 DO
			reservedChar[i] := ((CHR(i) < '0') OR ('9' < CHR(i))) & (CAP(CHR(i)) < "A") OR ("Z" < CAP(CHR(i))) & (CHR(i) # '_')
		END;
	END InitReservedChars;

	PROCEDURE InitNewChar;
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(newChar)-1 DO
			(* UTF-8 encoded characters with bits 10XXXXXX do not start a new unicode character *)
			IF (i < 80H) OR (i > 0BFH) THEN
				newChar[i] := TRUE;
			ELSE
				newChar[i] := FALSE;
			END
		END
	END InitNewChar;

	PROCEDURE CreateOperatorTable;
	BEGIN
		opTable[becomes] := StringPool.GetIndex1(":=");
		opTable[times] := StringPool.GetIndex1("*");
		opTable[slash] := StringPool.GetIndex1("/");
		opTable[div] := StringPool.GetIndex1("DIV");
		opTable[mod] := StringPool.GetIndex1("MOD");
		opTable[and] := StringPool.GetIndex1("&");
		opTable[plus] := StringPool.GetIndex1("+");
		opTable[minus] := StringPool.GetIndex1("-");
		opTable[or] := StringPool.GetIndex1("OR");
		opTable[eql] := StringPool.GetIndex1("=");
		opTable[neq] := StringPool.GetIndex1("#");
		opTable[lss] := StringPool.GetIndex1("<");
		opTable[leq] := StringPool.GetIndex1("<=");
		opTable[gtr] := StringPool.GetIndex1(">");
		opTable[geq] := StringPool.GetIndex1(">=");
		opTable[in] := StringPool.GetIndex1("IN");
		opTable[not] := StringPool.GetIndex1("~");
		(** fof >> *)
		opTable[backslash] := StringPool.GetIndex1( "\" );
		opTable[scalarproduct] := StringPool.GetIndex1( "+*" );
		opTable[elementproduct] := StringPool.GetIndex1( ".*" );
		opTable[elementquotient] := StringPool.GetIndex1( "./" );
		opTable[dtimes] := StringPool.GetIndex1( "**");
		opTable[eeql] := StringPool.GetIndex1( ".=");
		opTable[eneq] := StringPool.GetIndex1( ".#");
		opTable[elss] := StringPool.GetIndex1( ".<");
		opTable[eleq] := StringPool.GetIndex1( ".<=");
		opTable[egtr] := StringPool.GetIndex1( ".>");
		opTable[egeq] := StringPool.GetIndex1( ".>=");
		(** << fof  *)
	END CreateOperatorTable;

BEGIN
	IF Trace THEN PCM.LogWLn; PCM.LogWStr("PCS.Trace on") END;
	CreateOperatorTable;
	InitReservedChars;
	InitNewChar;
END PCS.
(*
	28.12.02	prk	InitWithReader, remove VAR (reader is passed as reference anyway)
	05.02.02	prk	PCS takes Streams.Reader as parameter, let PC handle the Oberon Text format
	18.01.02	prk	AosFS used instead of Files
	27.06.01	prk	StringPool cleaned up
	21.06.01	prk	using stringpool index instead of array of char
	12.06.01	prk	Interfaces
	26.04.01	prk	separation of RECORD and OBJECT in the parser
*)
