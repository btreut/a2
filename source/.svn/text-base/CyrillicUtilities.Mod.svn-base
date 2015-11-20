MODULE CyrillicUtilities; (** AUTHOR "SAGE"; PURPOSE "Cyrillic charsets text utilities"; *)

(*
	History:
	21/07/2010 - SAGE:	Calculate the range of unicode char codes on hash table construction,
									and check that input unicode char is within this range on encoding.
									Bug 'Code present in table, but not used in current encoding' fixed.
									Optimizations.
	20/07/2010 - SAGE:	Common hash table used for 5 Cyrillic encodings. Less memory usage.
									Potential ability to handle up to 31 encodings in common hash table
									with little grow of memory usage for every next encoding.
	09/01/2009 - SAGE:	Initialisation on demand. Cleanup
	24/07/2008 - SAGE:	Adapted to recent changes in A2
	07/01/2007 - SAGE:	Formed as one AosCyrillicUtilities module
	07/12/2006 - SAGE:	Added iso-8859-5 table
	24/09/2006 - SAGE:	Unicode to char conversion speed improved by using hash tables
*)

IMPORT

	KernelLog, Codecs, Streams, Texts, Commands;

CONST

	(* Prime number for hash table *)
	PRIME = 977;

	(* Available encoding tables  *)
	CP1251 = 0;
	KOI8R = CP1251 + 1;
	KOI8U = KOI8R + 1;
	CP866 = KOI8U + 1;
	ISO88595 = CP866 + 1;
	ENCODINGS_HIGH = ISO88595;

	CR = 0DX; LF = 0AX;

TYPE

	Char32 = Texts.Char32;

	StaticTable = ARRAY 256 OF Char32;

	HashTable  = ARRAY PRIME OF
		RECORD
			ucs32: Char32;
			encodings: SET;
			ch: ARRAY ENCODINGS_HIGH + 1 OF CHAR;
		END;

	LowBound = ARRAY ENCODINGS_HIGH + 1 OF INTEGER;

	CP1251Decoder = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		text : Texts.Text;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("CP1251 Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR i, m: LONGINT;
			tempUCS32 : ARRAY 1024 OF Char32;
			ch, last : CHAR;
		BEGIN
			errors := FALSE;
			res := Codecs.ResFailed;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			SELF.in := in;

			NEW(text);
			text.AcquireWrite;
			m := LEN(tempUCS32) - 1;
			i := 0;
			REPEAT
				in.Char(ch);
				IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
				IF (last # CR) OR (ch # LF) THEN
					IF ch = CR THEN tempUCS32[i] := ORD(LF)
					ELSE tempUCS32[i] := cp1251[ORD(ch)]
					END;
					INC(i)
				END;
				last := ch
			UNTIL (in.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);
			res := Codecs.ResOk;
			text.ReleaseWrite
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text
		END GetText;

	END CP1251Decoder;

	CP1251Encoder = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("CP1251 Encoder Error: output stream is NIL");
			ELSE SELF.out := out
			END
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR r : Texts.TextReader; ch : Texts.Char32; i : LONGINT;
			c: CHAR;
		BEGIN
			res :=  -1;
			text.AcquireRead;
			NEW(r, text);
			FOR i := 0 TO text.GetLength() - 1 DO
				r.ReadCh(ch);

				IF ch < aLowBound[CP1251] THEN
					out.Char(CHR(ch))
				ELSIF hashSearch(CP1251, FALSE, ch, c) THEN
					out.Char(c)
				END;

			END;
			out.Update;
			text.ReleaseRead;
			res := Codecs.ResOk
		END WriteText;

	END CP1251Encoder;

	KOI8RDecoder = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		text : Texts.Text;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("KOI8-R Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR i, m: LONGINT;
			(*r : Files.Reader;*)
			tempUCS32 : ARRAY 1024 OF Char32;
			ch, last : CHAR;
		BEGIN
			errors := FALSE;
			res := Codecs.ResFailed;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			SELF.in := in;

			NEW(text);
			text.AcquireWrite;
			m := LEN(tempUCS32) - 1;
			i := 0;
			REPEAT
				in.Char(ch);
				IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
				IF (last # CR) OR (ch # LF) THEN
					IF ch = CR THEN tempUCS32[i] := ORD(LF)
					ELSE tempUCS32[i] := koi8r[ORD(ch)]
					END;
					INC(i)
				END;
				last := ch
			UNTIL (in.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);
			res := Codecs.ResOk;
			text.ReleaseWrite
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text;
		END GetText;

	END KOI8RDecoder;

	KOI8REncoder = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("KOI8-R Encoder Error: output stream is NIL")
			ELSE SELF.out := out
			END;
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR r : Texts.TextReader; ch : Texts.Char32; i : LONGINT;
			c: CHAR;
		BEGIN
			res :=  -1;
			text.AcquireRead;
			NEW(r, text);
			FOR i := 0 TO text.GetLength() - 1 DO
				r.ReadCh(ch);

				IF ch < aLowBound[KOI8R] THEN
					out.Char(CHR(ch))
				ELSIF hashSearch(KOI8R, FALSE, ch, c) THEN
					out.Char(c)
				END;

			END;
			out.Update;
			text.ReleaseRead;
			res := Codecs.ResOk
		END WriteText;

	END KOI8REncoder;

	KOI8UDecoder = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		text : Texts.Text;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("KOI8-U Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR i, m: LONGINT;
			tempUCS32 : ARRAY 1024 OF Char32;
			ch, last : CHAR;
		BEGIN
			errors := FALSE;
			res := Codecs.ResFailed;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			SELF.in := in;

			NEW(text);
			text.AcquireWrite;
			m := LEN(tempUCS32) - 1;
			i := 0;
			REPEAT
				in.Char(ch);
				IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
				IF (last # CR) OR (ch # LF) THEN
					IF ch = CR THEN tempUCS32[i] := ORD(LF)
					ELSE tempUCS32[i] := koi8u[ORD(ch)]
					END;
					INC(i)
				END;
				last := ch
			UNTIL (in.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);
			res := Codecs.ResOk;
			text.ReleaseWrite
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text
		END GetText;

	END KOI8UDecoder;

	KOI8UEncoder = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("KOI8-U Encoder Error: output stream is NIL")
			ELSE SELF.out := out
			END
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR r : Texts.TextReader; ch : Texts.Char32; i : LONGINT;
			c: CHAR;
		BEGIN
			res :=  -1;
			text.AcquireRead;
			NEW(r, text);
			FOR i := 0 TO text.GetLength() - 1 DO
				r.ReadCh(ch);

				IF ch < aLowBound[KOI8U] THEN
					out.Char(CHR(ch))
				ELSIF hashSearch(KOI8U, FALSE, ch, c) THEN
					out.Char(c)
				END;

			END;
			out.Update;
			text.ReleaseRead;
			res := Codecs.ResOk
		END WriteText;

	END KOI8UEncoder;

	CP866Decoder = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		text : Texts.Text;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("CP-866 Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR i, m: LONGINT;
			tempUCS32 : ARRAY 1024 OF Char32;
			ch, last : CHAR;
		BEGIN
			errors := FALSE;
			res := Codecs.ResFailed;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			SELF.in := in;

			NEW(text);
			text.AcquireWrite;
			m := LEN(tempUCS32) - 1;
			i := 0;
			REPEAT
				in.Char(ch);
				IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
				IF (last # CR) OR (ch # LF) THEN
					IF ch = CR THEN tempUCS32[i] := ORD(LF)
					ELSE tempUCS32[i] := cp866[ORD(ch)]
					END;
					INC(i)
				END;
				last := ch
			UNTIL (in.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);
			res := Codecs.ResOk;
			text.ReleaseWrite
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text
		END GetText;

	END CP866Decoder;

	CP866Encoder = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("CP-866 Encoder Error: output stream is NIL")
			ELSE SELF.out := out
			END;
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR r : Texts.TextReader; ch : Texts.Char32; i : LONGINT;
			c: CHAR;
		BEGIN
			res :=  -1;
			text.AcquireRead;
			NEW(r, text);
			FOR i := 0 TO text.GetLength() - 1 DO
				r.ReadCh(ch);

				IF ch < aLowBound[CP866] THEN
					out.Char(CHR(ch))
				ELSIF hashSearch(CP866, FALSE, ch, c) THEN
					out.Char(c)
				END

			END;
			out.Update;
			text.ReleaseRead;
			res := Codecs.ResOk
		END WriteText;

	END CP866Encoder;

	ISO88595Decoder = OBJECT(Codecs.TextDecoder)
	VAR errors : BOOLEAN;
		in : Streams.Reader;
		text : Texts.Text;

		PROCEDURE Error(CONST x : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("ISO-8859-5 Decoder Error: ");
			KernelLog.String(x); KernelLog.Ln;
			errors := TRUE
		END Error;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR i, m: LONGINT;
			tempUCS32 : ARRAY 1024 OF Char32;
			ch, last : CHAR;
		BEGIN
			errors := FALSE;
			res := Codecs.ResFailed;
			IF in = NIL THEN Error("Input Stream is NIL"); RETURN; END;
			SELF.in := in;

			NEW(text);
			text.AcquireWrite;
			m := LEN(tempUCS32) - 1;
			i := 0;
			REPEAT
				in.Char(ch);
				IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
				IF (last # CR) OR (ch # LF) THEN
					IF ch = CR THEN tempUCS32[i] := ORD(LF)
					ELSE tempUCS32[i] := iso88595[ORD(ch)]
					END;
					INC(i)
				END;
				last := ch
			UNTIL (in.res # Streams.Ok);
			tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);
			res := Codecs.ResOk;
			text.ReleaseWrite
		END Open;

		PROCEDURE GetText*() : Texts.Text;
		BEGIN
			RETURN text
		END GetText;

	END ISO88595Decoder;

	ISO88595Encoder = OBJECT(Codecs.TextEncoder)
	VAR out: Streams.Writer;

		PROCEDURE Open*(out : Streams.Writer);
		BEGIN
			IF out = NIL THEN KernelLog.String("ISO-8859-5 Encoder Error: output stream is NIL")
			ELSE SELF.out := out
			END
		END Open;

		PROCEDURE WriteText*(text : Texts.Text; VAR res : LONGINT);
		VAR r : Texts.TextReader; ch : Texts.Char32; i : LONGINT;
			c: CHAR;
		BEGIN
			res :=  -1;
			text.AcquireRead;
			NEW(r, text);
			FOR i := 0 TO text.GetLength() - 1 DO
				r.ReadCh(ch);

				IF ch < aLowBound[ISO88595] THEN
					out.Char(CHR(ch))
				ELSIF hashSearch(ISO88595, FALSE, ch, c) THEN
					out.Char(c)
				END;

			END;
			out.Update;
			text.ReleaseRead;
			res := Codecs.ResOk
		END WriteText;

	END ISO88595Encoder;

VAR
	aLowBound: LowBound;
	koi8r, koi8u, cp1251, cp866, iso88595: StaticTable;
	hash: HashTable;
	bFirst: BOOLEAN;
	setInitDone: SET;
	nCollisions: LONGINT;
	ucs32Min, ucs32Max: Char32;

	PROCEDURE hashSearch(encoding: SHORTINT; bAddAllowed: BOOLEAN; ucs32: Char32; VAR ch: CHAR): BOOLEAN;
	VAR
		d: INTEGER;
		h: LONGINT;
		bFound, bExit: BOOLEAN;
	BEGIN

		bExit := FALSE;
		bFound := FALSE;
		d := 1;
		h := ucs32 MOD PRIME;

		IF bAddAllowed THEN
			IF bFirst THEN
				bFirst := FALSE;
				ucs32Min := ucs32;
				ucs32Max := ucs32
			ELSE
				ucs32Min := MIN(ucs32Min, ucs32);
				ucs32Max := MAX(ucs32Max, ucs32)
			END
		ELSIF (ucs32 < ucs32Min) OR (ucs32 > ucs32Max) THEN
			bExit := TRUE
		END;

		WHILE ~(bFound OR bExit) DO
			IF hash[h].ucs32 = ucs32 THEN (* match *)
				IF encoding IN hash[h].encodings THEN
					bFound := TRUE;
					ch := hash[h].ch[encoding]
				ELSIF bAddAllowed THEN (* add char in new encoding *)
					bExit := TRUE;
					hash[h].ch[encoding] := ch;
					hash[h].encodings := hash[h].encodings + {encoding}
				ELSE
					(* Code present in table, but not used in current encoding *)
					bExit := TRUE
				END
			ELSIF hash[h].ucs32 = 0 THEN (* new entry *)
				bExit := TRUE;
				IF bAddAllowed THEN
					hash[h].ucs32 := ucs32;
					hash[h].ch[encoding] := ch;
					hash[h].encodings := hash[h].encodings + {encoding}
				END
			ELSE (* collision *)

				INC(nCollisions);

				h := h + d; d := d + 2;
				IF h >= PRIME THEN h := h - PRIME END;

				(* Table owerflow! *)
				IF d = PRIME THEN
					bExit := TRUE;
					ASSERT(d # PRIME)
				END

			END
		END;

		RETURN bFound

	END hashSearch;

	PROCEDURE koi8rInit;
	VAR
		i: INTEGER; b: BOOLEAN;
		c: CHAR;
	BEGIN

		IF ~(KOI8R IN setInitDone) THEN
			setInitDone := setInitDone + {KOI8R};

			FOR i := 0 TO aLowBound[KOI8R] - 1 DO
				koi8r[i] := i
			END;

			koi8r[080H] := 02500H;  (* BOX DRAWINGS LIGHT HORIZONTAL *)
			koi8r[081H] := 02502H;  (* BOX DRAWINGS LIGHT VERTICAL *)
			koi8r[082H] := 0250CH;  (* BOX DRAWINGS LIGHT DOWN AND RIGHT *)
			koi8r[083H] := 02510H;  (* BOX DRAWINGS LIGHT DOWN AND LEFT *)
			koi8r[084H] := 02514H;  (* BOX DRAWINGS LIGHT UP AND RIGHT *)
			koi8r[085H] := 02518H;  (* BOX DRAWINGS LIGHT UP AND LEFT *)
			koi8r[086H] := 0251CH;  (* BOX DRAWINGS LIGHT VERTICAL AND RIGHT *)
			koi8r[087H] := 02524H;  (* BOX DRAWINGS LIGHT VERTICAL AND LEFT *)
			koi8r[088H] := 0252CH;  (* BOX DRAWINGS LIGHT DOWN AND HORIZONTAL *)
			koi8r[089H] := 02534H;  (* BOX DRAWINGS LIGHT UP AND HORIZONTAL *)
			koi8r[08AH] := 0253CH;  (* BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL *)
			koi8r[08BH] := 02580H;  (* UPPER HALF BLOCK *)
			koi8r[08CH] := 02584H;  (* LOWER HALF BLOCK *)
			koi8r[08DH] := 02588H;  (* FULL BLOCK *)
			koi8r[08EH] := 0258CH;  (* LEFT HALF BLOCK *)
			koi8r[08FH] := 02590H;  (* RIGHT HALF BLOCK *)
			koi8r[090H] := 02591H;  (* LIGHT SHADE *)
			koi8r[091H] := 02592H;  (* MEDIUM SHADE *)
			koi8r[092H] := 02593H;  (* DARK SHADE *)
			koi8r[093H] := 02320H;  (* TOP HALF INTEGRAL *)
			koi8r[094H] := 025A0H;  (* BLACK SQUARE *)
			koi8r[095H] := 02022H;  (* BULLET *)
			koi8r[096H] := 0221AH;  (* SQUARE ROOT *)
			koi8r[097H] := 02248H;  (* ALMOST EQUAL TO *)
			koi8r[098H] := 02264H;  (* LESS-THAN OR EQUAL TO *)
			koi8r[099H] := 02265H;  (* GREATER-THAN OR EQUAL TO *)
			koi8r[09AH] := 000A0H;  (* NO-BREAK SPACE *)
			koi8r[09BH] := 02321H;  (* BOTTOM HALF INTEGRAL *)
			koi8r[09CH] := 000B0H;  (* DEGREE SIGN *)
			koi8r[09DH] := 000B2H;  (* SUPERSCRIPT TWO *)
			koi8r[09EH] := 000B7H;  (* MIDDLE DOT *)
			koi8r[09FH] := 000F7H;  (* DIVISION SIGN *)
			koi8r[0A0H] := 02550H;  (* BOX DRAWINGS DOUBLE HORIZONTAL *)
			koi8r[0A1H] := 02551H;  (* BOX DRAWINGS DOUBLE VERTICAL *)
			koi8r[0A2H] := 02552H;  (* BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE *)
			koi8r[0A3H] := 00451H;  (* CYRILLIC SMALL LETTER IO *)
			koi8r[0A4H] := 02553H;  (* BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE *)
			koi8r[0A5H] := 02554H;  (* BOX DRAWINGS DOUBLE DOWN AND RIGHT *)
			koi8r[0A6H] := 02555H;  (* BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE *)
			koi8r[0A7H] := 02556H;  (* BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE *)
			koi8r[0A8H] := 02557H;  (* BOX DRAWINGS DOUBLE DOWN AND LEFT *)
			koi8r[0A9H] := 02558H;  (* BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE *)
			koi8r[0AAH] := 02559H;  (* BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE *)
			koi8r[0ABH] := 0255AH;  (* BOX DRAWINGS DOUBLE UP AND RIGHT *)
			koi8r[0ACH] := 0255BH;  (* BOX DRAWINGS UP SINGLE AND LEFT DOUBLE *)
			koi8r[0ADH] := 0255CH;  (* BOX DRAWINGS UP DOUBLE AND LEFT SINGLE *)
			koi8r[0AEH] := 0255DH;  (* BOX DRAWINGS DOUBLE UP AND LEFT *)
			koi8r[0AFH] := 0255EH;  (* BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE *)
			koi8r[0B0H] := 0255FH;  (* BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE *)
			koi8r[0B1H] := 02560H;  (* BOX DRAWINGS DOUBLE VERTICAL AND RIGHT *)
			koi8r[0B2H] := 02561H;  (* BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE *)
			koi8r[0B3H] := 00401H;  (* CYRILLIC CAPITAL LETTER IO *)
			koi8r[0B4H] := 02562H;  (* BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE *)
			koi8r[0B5H] := 02563H;  (* BOX DRAWINGS DOUBLE VERTICAL AND LEFT *)
			koi8r[0B6H] := 02564H;  (* BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE *)
			koi8r[0B7H] := 02565H;  (* BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE *)
			koi8r[0B8H] := 02566H;  (* BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL *)
			koi8r[0B9H] := 02567H;  (* BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE *)
			koi8r[0BAH] := 02568H;  (* BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE *)
			koi8r[0BBH] := 02569H;  (* BOX DRAWINGS DOUBLE UP AND HORIZONTAL *)
			koi8r[0BCH] := 0256AH;  (* BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE *)
			koi8r[0BDH] := 0256BH;  (* BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE *)
			koi8r[0BEH] := 0256CH;  (* BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL *)
			koi8r[0BFH] := 000A9H;  (* COPYRIGHT SIGN *)
			koi8r[0C0H] := 0044EH;  (* CYRILLIC SMALL LETTER YU *)
			koi8r[0C1H] := 00430H;  (* CYRILLIC SMALL LETTER A *)
			koi8r[0C2H] := 00431H;  (* CYRILLIC SMALL LETTER BE *)
			koi8r[0C3H] := 00446H;  (* CYRILLIC SMALL LETTER TSE *)
			koi8r[0C4H] := 00434H;  (* CYRILLIC SMALL LETTER DE *)
			koi8r[0C5H] := 00435H;  (* CYRILLIC SMALL LETTER IE *)
			koi8r[0C6H] := 00444H;  (* CYRILLIC SMALL LETTER EF *)
			koi8r[0C7H] := 00433H;  (* CYRILLIC SMALL LETTER GHE *)
			koi8r[0C8H] := 00445H;  (* CYRILLIC SMALL LETTER HA *)
			koi8r[0C9H] := 00438H;  (* CYRILLIC SMALL LETTER I *)
			koi8r[0CAH] := 00439H;  (* CYRILLIC SMALL LETTER SHORT I *)
			koi8r[0CBH] := 0043AH;  (* CYRILLIC SMALL LETTER KA *)
			koi8r[0CCH] := 0043BH;  (* CYRILLIC SMALL LETTER EL *)
			koi8r[0CDH] := 0043CH;  (* CYRILLIC SMALL LETTER EM *)
			koi8r[0CEH] := 0043DH;  (* CYRILLIC SMALL LETTER EN *)
			koi8r[0CFH] := 0043EH;  (* CYRILLIC SMALL LETTER O *)
			koi8r[0D0H] := 0043FH;  (* CYRILLIC SMALL LETTER PE *)
			koi8r[0D1H] := 0044FH;  (* CYRILLIC SMALL LETTER YA *)
			koi8r[0D2H] := 00440H;  (* CYRILLIC SMALL LETTER ER *)
			koi8r[0D3H] := 00441H;  (* CYRILLIC SMALL LETTER ES *)
			koi8r[0D4H] := 00442H;  (* CYRILLIC SMALL LETTER TE *)
			koi8r[0D5H] := 00443H;  (* CYRILLIC SMALL LETTER U *)
			koi8r[0D6H] := 00436H;  (* CYRILLIC SMALL LETTER ZHE *)
			koi8r[0D7H] := 00432H;  (* CYRILLIC SMALL LETTER VE *)
			koi8r[0D8H] := 0044CH;  (* CYRILLIC SMALL LETTER SOFT SIGN *)
			koi8r[0D9H] := 0044BH;  (* CYRILLIC SMALL LETTER YERU *)
			koi8r[0DAH] := 00437H;  (* CYRILLIC SMALL LETTER ZE *)
			koi8r[0DBH] := 00448H;  (* CYRILLIC SMALL LETTER SHA *)
			koi8r[0DCH] := 0044DH;  (* CYRILLIC SMALL LETTER E *)
			koi8r[0DDH] := 00449H;  (* CYRILLIC SMALL LETTER SHCHA *)
			koi8r[0DEH] := 00447H;  (* CYRILLIC SMALL LETTER CHE *)
			koi8r[0DFH] := 0044AH;  (* CYRILLIC SMALL LETTER HARD SIGN *)
			koi8r[0E0H] := 0042EH;  (* CYRILLIC CAPITAL LETTER YU *)
			koi8r[0E1H] := 00410H;  (* CYRILLIC CAPITAL LETTER A *)
			koi8r[0E2H] := 00411H;  (* CYRILLIC CAPITAL LETTER BE *)
			koi8r[0E3H] := 00426H;  (* CYRILLIC CAPITAL LETTER TSE *)
			koi8r[0E4H] := 00414H;  (* CYRILLIC CAPITAL LETTER DE *)
			koi8r[0E5H] := 00415H;  (* CYRILLIC CAPITAL LETTER IE *)
			koi8r[0E6H] := 00424H;  (* CYRILLIC CAPITAL LETTER EF *)
			koi8r[0E7H] := 00413H;  (* CYRILLIC CAPITAL LETTER GHE *)
			koi8r[0E8H] := 00425H;  (* CYRILLIC CAPITAL LETTER HA *)
			koi8r[0E9H] := 00418H;  (* CYRILLIC CAPITAL LETTER I *)
			koi8r[0EAH] := 00419H;  (* CYRILLIC CAPITAL LETTER SHORT I *)
			koi8r[0EBH] := 0041AH;  (* CYRILLIC CAPITAL LETTER KA *)
			koi8r[0ECH] := 0041BH;  (* CYRILLIC CAPITAL LETTER EL *)
			koi8r[0EDH] := 0041CH;  (* CYRILLIC CAPITAL LETTER EM *)
			koi8r[0EEH] := 0041DH;  (* CYRILLIC CAPITAL LETTER EN *)
			koi8r[0EFH] := 0041EH;  (* CYRILLIC CAPITAL LETTER O *)
			koi8r[0F0H] := 0041FH;  (* CYRILLIC CAPITAL LETTER PE *)
			koi8r[0F1H] := 0042FH;  (* CYRILLIC CAPITAL LETTER YA *)
			koi8r[0F2H] := 00420H;  (* CYRILLIC CAPITAL LETTER ER *)
			koi8r[0F3H] := 00421H;  (* CYRILLIC CAPITAL LETTER ES *)
			koi8r[0F4H] := 00422H;  (* CYRILLIC CAPITAL LETTER TE *)
			koi8r[0F5H] := 00423H;  (* CYRILLIC CAPITAL LETTER U *)
			koi8r[0F6H] := 00416H;  (* CYRILLIC CAPITAL LETTER ZHE *)
			koi8r[0F7H] := 00412H;  (* CYRILLIC CAPITAL LETTER VE *)
			koi8r[0F8H] := 0042CH;  (* CYRILLIC CAPITAL LETTER SOFT SIGN *)
			koi8r[0F9H] := 0042BH;  (* CYRILLIC CAPITAL LETTER YERU *)
			koi8r[0FAH] := 00417H;  (* CYRILLIC CAPITAL LETTER ZE *)
			koi8r[0FBH] := 00428H;  (* CYRILLIC CAPITAL LETTER SHA *)
			koi8r[0FCH] := 0042DH;  (* CYRILLIC CAPITAL LETTER E *)
			koi8r[0FDH] := 00429H;  (* CYRILLIC CAPITAL LETTER SHCHA *)
			koi8r[0FEH] := 00427H;  (* CYRILLIC CAPITAL LETTER CHE *)
			koi8r[0FFH] := 0042AH;  (* CYRILLIC CAPITAL LETTER HARD SIGN *)

			FOR i := aLowBound[KOI8R] TO 255 DO
				c := CHR(i);
				b := hashSearch(KOI8R, TRUE, koi8r[i], c)
			END

		END

	END koi8rInit;

	PROCEDURE koi8uInit;
	VAR
		i: INTEGER; b: BOOLEAN;
		c: CHAR;
	BEGIN

		IF ~(KOI8U IN setInitDone) THEN
			setInitDone := setInitDone + {KOI8U};

			FOR i := 0 TO aLowBound[KOI8U] - 1 DO
				koi8u[i] := i
			END;

			koi8u[080H] := 02500H; (* BOX DRAWINGS LIGHT HORIZONTAL *)
			koi8u[081H] := 02502H; (* BOX DRAWINGS LIGHT VERTICAL *)
			koi8u[082H] := 0250CH; (* BOX DRAWINGS LIGHT DOWN AND RIGHT *)
			koi8u[083H] := 02510H; (* BOX DRAWINGS LIGHT DOWN AND LEFT *)
			koi8u[084H] := 02514H; (* BOX DRAWINGS LIGHT UP AND RIGHT *)
			koi8u[085H] := 02518H; (* BOX DRAWINGS LIGHT UP AND LEFT *)
			koi8u[086H] := 0251CH; (* BOX DRAWINGS LIGHT VERTICAL AND RIGHT *)
			koi8u[087H] := 02524H; (* BOX DRAWINGS LIGHT VERTICAL AND LEFT *)
			koi8u[088H] := 0252CH; (* BOX DRAWINGS LIGHT DOWN AND HORIZONTAL *)
			koi8u[089H] := 02534H; (* BOX DRAWINGS LIGHT UP AND HORIZONTAL *)
			koi8u[08AH] := 0253CH; (* BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL *)
			koi8u[08BH] := 02580H; (* UPPER HALF BLOCK *)
			koi8u[08CH] := 02584H; (* LOWER HALF BLOCK *)
			koi8u[08DH] := 02588H; (* FULL BLOCK *)
			koi8u[08EH] := 0258CH; (* LEFT HALF BLOCK *)
			koi8u[08FH] := 02590H; (* RIGHT HALF BLOCK *)
			koi8u[090H] := 02591H; (* LIGHT SHADE *)
			koi8u[091H] := 02592H; (* MEDIUM SHADE *)
			koi8u[092H] := 02593H; (* DARK SHADE *)
			koi8u[093H] := 02320H; (* TOP HALF INTEGRAL *)
			koi8u[094H] := 025A0H; (* BLACK SQUARE *)
			koi8u[095H] := 02022H; (* BULLET *)
			koi8u[096H] := 0221AH; (* SQUARE ROOT *)
			koi8u[097H] := 02248H; (* ALMOST EQUAL TO *)
			koi8u[098H] := 02264H; (* LESS-THAN OR EQUAL TO *)
			koi8u[099H] := 02265H; (* GREATER-THAN OR EQUAL TO *)
			koi8u[09AH] := 000A0H; (* NO-BREAK SPACE *)
			koi8u[09BH] := 02321H; (* BOTTOM HALF INTEGRAL *)
			koi8u[09CH] := 000B0H; (* DEGREE SIGN *)
			koi8u[09DH] := 000B2H; (* SUPERSCRIPT TWO *)
			koi8u[09EH] := 000B7H; (* MIDDLE DOT *)
			koi8u[09FH] := 000F7H; (* DIVISION SIGN *)
			koi8u[0A0H] := 02550H; (* BOX DRAWINGS DOUBLE HORIZONTAL *)
			koi8u[0A1H] := 02551H; (* BOX DRAWINGS DOUBLE VERTICAL *)
			koi8u[0A2H] := 02552H; (* BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE *)
			koi8u[0A3H] := 00451H; (* CYRILLIC SMALL LETTER IO *)
			koi8u[0A4H] := 00454H; (* CYRILLIC SMALL LETTER UKRAINIAN IE *)
			koi8u[0A5H] := 02554H; (* BOX DRAWINGS DOUBLE DOWN AND RIGHT *)
			koi8u[0A6H] := 00456H; (* CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I *)
			koi8u[0A7H] := 00457H; (* CYRILLIC SMALL LETTER YI *)
			koi8u[0A8H] := 02557H; (* BOX DRAWINGS DOUBLE DOWN AND LEFT *)
			koi8u[0A9H] := 02558H; (* BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE *)
			koi8u[0AAH] := 02559H; (* BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE *)
			koi8u[0ABH] := 0255AH; (* BOX DRAWINGS DOUBLE UP AND RIGHT *)
			koi8u[0ACH] := 0255BH; (* BOX DRAWINGS UP SINGLE AND LEFT DOUBLE *)
			koi8u[0ADH] := 00491H; (* CYRILLIC SMALL LETTER GHE WITH UPTURN *)
			koi8u[0AEH] := 0255DH; (* BOX DRAWINGS DOUBLE UP AND LEFT *)
			koi8u[0AFH] := 0255EH; (* BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE *)
			koi8u[0B0H] := 0255FH; (* BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE *)
			koi8u[0B1H] := 02560H; (* BOX DRAWINGS DOUBLE VERTICAL AND RIGHT *)
			koi8u[0B2H] := 02561H; (* BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE *)
			koi8u[0B3H] := 00401H; (* CYRILLIC CAPITAL LETTER IO *)
			koi8u[0B4H] := 00404H; (* CYRILLIC CAPITAL LETTER UKRAINIAN IE *)
			koi8u[0B5H] := 02563H; (* BOX DRAWINGS DOUBLE VERTICAL AND LEFT *)
			koi8u[0B6H] := 00406H; (* CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I *)
			koi8u[0B7H] := 00407H; (* CYRILLIC CAPITAL LETTER YI *)
			koi8u[0B8H] := 02566H; (* BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL *)
			koi8u[0B9H] := 02567H; (* BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE *)
			koi8u[0BAH] := 02568H; (* BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE *)
			koi8u[0BBH] := 02569H; (* BOX DRAWINGS DOUBLE UP AND HORIZONTAL *)
			koi8u[0BCH] := 0256AH; (* BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE *)
			koi8u[0BDH] := 00490H; (* CYRILLIC CAPITAL LETTER GHE WITH UPTURN *)
			koi8u[0BEH] := 0256CH; (* BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL *)
			koi8u[0BFH] := 000A9H; (* COPYRIGHT SIGN *)
			koi8u[0C0H] := 0044EH; (* CYRILLIC SMALL LETTER YU *)
			koi8u[0C1H] := 00430H; (* CYRILLIC SMALL LETTER A *)
			koi8u[0C2H] := 00431H; (* CYRILLIC SMALL LETTER BE *)
			koi8u[0C3H] := 00446H; (* CYRILLIC SMALL LETTER TSE *)
			koi8u[0C4H] := 00434H; (* CYRILLIC SMALL LETTER DE *)
			koi8u[0C5H] := 00435H; (* CYRILLIC SMALL LETTER IE *)
			koi8u[0C6H] := 00444H; (* CYRILLIC SMALL LETTER EF *)
			koi8u[0C7H] := 00433H; (* CYRILLIC SMALL LETTER GHE *)
			koi8u[0C8H] := 00445H; (* CYRILLIC SMALL LETTER HA *)
			koi8u[0C9H] := 00438H; (* CYRILLIC SMALL LETTER I *)
			koi8u[0CAH] := 00439H; (* CYRILLIC SMALL LETTER SHORT I *)
			koi8u[0CBH] := 0043AH; (* CYRILLIC SMALL LETTER KA *)
			koi8u[0CCH] := 0043BH; (* CYRILLIC SMALL LETTER EL *)
			koi8u[0CDH] := 0043CH; (* CYRILLIC SMALL LETTER EM *)
			koi8u[0CEH] := 0043DH; (* CYRILLIC SMALL LETTER EN *)
			koi8u[0CFH] := 0043EH; (* CYRILLIC SMALL LETTER O *)
			koi8u[0D0H] := 0043FH; (* CYRILLIC SMALL LETTER PE *)
			koi8u[0D1H] := 0044FH; (* CYRILLIC SMALL LETTER YA *)
			koi8u[0D2H] := 00440H; (* CYRILLIC SMALL LETTER ER *)
			koi8u[0D3H] := 00441H; (* CYRILLIC SMALL LETTER ES *)
			koi8u[0D4H] := 00442H; (* CYRILLIC SMALL LETTER TE *)
			koi8u[0D5H] := 00443H; (* CYRILLIC SMALL LETTER U *)
			koi8u[0D6H] := 00436H; (* CYRILLIC SMALL LETTER ZHE *)
			koi8u[0D7H] := 00432H; (* CYRILLIC SMALL LETTER VE *)
			koi8u[0D8H] := 0044CH; (* CYRILLIC SMALL LETTER SOFT SIGN *)
			koi8u[0D9H] := 0044BH; (* CYRILLIC SMALL LETTER YERU *)
			koi8u[0DAH] := 00437H; (* CYRILLIC SMALL LETTER ZE *)
			koi8u[0DBH] := 00448H; (* CYRILLIC SMALL LETTER SHA *)
			koi8u[0DCH] := 0044DH; (* CYRILLIC SMALL LETTER E *)
			koi8u[0DDH] := 00449H; (* CYRILLIC SMALL LETTER SHCHA *)
			koi8u[0DEH] := 00447H; (* CYRILLIC SMALL LETTER CHE *)
			koi8u[0DFH] := 0044AH; (* CYRILLIC SMALL LETTER HARD SIGN *)
			koi8u[0E0H] := 0042EH; (* CYRILLIC CAPITAL LETTER YU *)
			koi8u[0E1H] := 00410H; (* CYRILLIC CAPITAL LETTER A *)
			koi8u[0E2H] := 00411H; (* CYRILLIC CAPITAL LETTER BE *)
			koi8u[0E3H] := 00426H; (* CYRILLIC CAPITAL LETTER TSE *)
			koi8u[0E4H] := 00414H; (* CYRILLIC CAPITAL LETTER DE *)
			koi8u[0E5H] := 00415H; (* CYRILLIC CAPITAL LETTER IE *)
			koi8u[0E6H] := 00424H; (* CYRILLIC CAPITAL LETTER EF *)
			koi8u[0E7H] := 00413H; (* CYRILLIC CAPITAL LETTER GHE *)
			koi8u[0E8H] := 00425H; (* CYRILLIC CAPITAL LETTER HA *)
			koi8u[0E9H] := 00418H; (* CYRILLIC CAPITAL LETTER I *)
			koi8u[0EAH] := 00419H; (* CYRILLIC CAPITAL LETTER SHORT I *)
			koi8u[0EBH] := 0041AH; (* CYRILLIC CAPITAL LETTER KA *)
			koi8u[0ECH] := 0041BH; (* CYRILLIC CAPITAL LETTER EL *)
			koi8u[0EDH] := 0041CH; (* CYRILLIC CAPITAL LETTER EM *)
			koi8u[0EEH] := 0041DH; (* CYRILLIC CAPITAL LETTER EN *)
			koi8u[0EFH] := 0041EH; (* CYRILLIC CAPITAL LETTER O *)
			koi8u[0F0H] := 0041FH; (* CYRILLIC CAPITAL LETTER PE *)
			koi8u[0F1H] := 0042FH; (* CYRILLIC CAPITAL LETTER YA *)
			koi8u[0F2H] := 00420H; (* CYRILLIC CAPITAL LETTER ER *)
			koi8u[0F3H] := 00421H; (* CYRILLIC CAPITAL LETTER ES *)
			koi8u[0F4H] := 00422H; (* CYRILLIC CAPITAL LETTER TE *)
			koi8u[0F5H] := 00423H; (* CYRILLIC CAPITAL LETTER U *)
			koi8u[0F6H] := 00416H; (* CYRILLIC CAPITAL LETTER ZHE *)
			koi8u[0F7H] := 00412H; (* CYRILLIC CAPITAL LETTER VE *)
			koi8u[0F8H] := 0042CH; (* CYRILLIC CAPITAL LETTER SOFT SIGN *)
			koi8u[0F9H] := 0042BH; (* CYRILLIC CAPITAL LETTER YERU *)
			koi8u[0FAH] := 00417H; (* CYRILLIC CAPITAL LETTER ZE *)
			koi8u[0FBH] := 00428H; (* CYRILLIC CAPITAL LETTER SHA *)
			koi8u[0FCH] := 0042DH; (* CYRILLIC CAPITAL LETTER E *)
			koi8u[0FDH] := 00429H; (* CYRILLIC CAPITAL LETTER SHCHA *)
			koi8u[0FEH] := 00427H; (* CYRILLIC CAPITAL LETTER CHE *)
			koi8u[0FFH] := 0042AH; (* CYRILLIC CAPITAL LETTER HARD SIGN *)

			FOR i := aLowBound[KOI8U] TO 255 DO
				c := CHR(i);
				b := hashSearch(KOI8U, TRUE, koi8u[i], c)
			END

		END

	END koi8uInit;

	PROCEDURE cp1251Init;
	VAR
		i: INTEGER; b: BOOLEAN;
		c: CHAR;
	BEGIN

		IF ~(CP1251 IN setInitDone) THEN
			setInitDone := setInitDone + {CP1251};

			FOR i := 0 TO aLowBound[CP1251] - 1 DO
				cp1251[i] := i
			END;

			cp1251[080H] := 00402H; (* CYRILLIC CAPITAL LETTER DJE *)
			cp1251[081H] := 00403H; (* CYRILLIC CAPITAL LETTER GJE *)
			cp1251[082H] := 0201AH; (* SINGLE LOW-9 QUOTATION MARK *)
			cp1251[083H] := 00453H; (* CYRILLIC SMALL LETTER GJE *)
			cp1251[084H] := 0201EH; (* DOUBLE LOW-9 QUOTATION MARK *)
			cp1251[085H] := 02026H; (* HORIZONTAL ELLIPSIS *)
			cp1251[086H] := 02020H; (* DAGGER *)
			cp1251[087H] := 02021H; (* DOUBLE DAGGER *)
			cp1251[088H] := 020ACH; (* EURO SIGN *)
			cp1251[089H] := 02030H; (* PER MILLE SIGN *)
			cp1251[08AH] := 00409H; (* CYRILLIC CAPITAL LETTER LJE *)
			cp1251[08BH] := 02039H; (* SINGLE LEFT-POINTING ANGLE QUOTATION MARK *)
			cp1251[08CH] := 0040AH; (* CYRILLIC CAPITAL LETTER NJE *)
			cp1251[08DH] := 0040CH; (* CYRILLIC CAPITAL LETTER KJE *)
			cp1251[08EH] := 0040BH; (* CYRILLIC CAPITAL LETTER TSHE *)
			cp1251[08FH] := 0040FH; (* CYRILLIC CAPITAL LETTER DZHE *)
			cp1251[090H] := 00452H; (* CYRILLIC SMALL LETTER DJE *)
			cp1251[091H] := 02018H; (* LEFT SINGLE QUOTATION MARK *)
			cp1251[092H] := 02019H; (* RIGHT SINGLE QUOTATION MARK *)
			cp1251[093H] := 0201CH; (* LEFT DOUBLE QUOTATION MARK *)
			cp1251[094H] := 0201DH; (* RIGHT DOUBLE QUOTATION MARK *)
			cp1251[095H] := 02022H; (* BULLET *)
			cp1251[096H] := 02013H; (* EN DASH *)
			cp1251[097H] := 02014H; (* EM DASH *)
			cp1251[098H] := 098H;
			cp1251[099H] := 02122H; (* TRADE MARK SIGN *)
			cp1251[09AH] := 00459H; (* CYRILLIC SMALL LETTER LJE *)
			cp1251[09BH] := 0203AH; (* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK *)
			cp1251[09CH] := 0045AH; (* CYRILLIC SMALL LETTER NJE *)
			cp1251[09DH] := 0045CH; (* CYRILLIC SMALL LETTER KJE *)
			cp1251[09EH] := 0045BH; (* CYRILLIC SMALL LETTER TSHE *)
			cp1251[09FH] := 0045FH; (* CYRILLIC SMALL LETTER DZHE *)
			cp1251[0A0H] := 000A0H; (* NO-BREAK SPACE *)
			cp1251[0A1H] := 0040EH; (* CYRILLIC CAPITAL LETTER SHORT U *)
			cp1251[0A2H] := 0045EH; (* CYRILLIC SMALL LETTER SHORT U *)
			cp1251[0A3H] := 00408H; (* CYRILLIC CAPITAL LETTER JE *)
			cp1251[0A4H] := 000A4H; (* CURRENCY SIGN *)
			cp1251[0A5H] := 00490H; (* CYRILLIC CAPITAL LETTER GHE WITH UPTURN *)
			cp1251[0A6H] := 000A6H; (* BROKEN BAR *)
			cp1251[0A7H] := 000A7H; (* SECTION SIGN *)
			cp1251[0A8H] := 00401H; (* CYRILLIC CAPITAL LETTER IO *)
			cp1251[0A9H] := 000A9H; (* COPYRIGHT SIGN *)
			cp1251[0AAH] := 00404H; (* CYRILLIC CAPITAL LETTER UKRAINIAN IE *)
			cp1251[0ABH] := 000ABH; (* LEFT-POINTING DOUBLE ANGLE QUOTATION MARK *)
			cp1251[0ACH] := 000ACH; (* NOT SIGN *)
			cp1251[0ADH] := 000ADH; (* SOFT HYPHEN *)
			cp1251[0AEH] := 000AEH; (* REGISTERED SIGN *)
			cp1251[0AFH] := 00407H; (* CYRILLIC CAPITAL LETTER YI *)
			cp1251[0B0H] := 000B0H; (* DEGREE SIGN *)
			cp1251[0B1H] := 000B1H; (* PLUS-MINUS SIGN *)
			cp1251[0B2H] := 00406H; (* CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I *)
			cp1251[0B3H] := 00456H; (* CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I *)
			cp1251[0B4H] := 00491H; (* CYRILLIC SMALL LETTER GHE WITH UPTURN *)
			cp1251[0B5H] := 000B5H; (* MICRO SIGN *)
			cp1251[0B6H] := 000B6H; (* PILCROW SIGN *)
			cp1251[0B7H] := 000B7H; (* MIDDLE DOT *)
			cp1251[0B8H] := 00451H; (* CYRILLIC SMALL LETTER IO *)
			cp1251[0B9H] := 02116H; (* NUMERO SIGN *)
			cp1251[0BAH] := 00454H; (* CYRILLIC SMALL LETTER UKRAINIAN IE *)
			cp1251[0BBH] := 000BBH; (* RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK *)
			cp1251[0BCH] := 00458H; (* CYRILLIC SMALL LETTER JE *)
			cp1251[0BDH] := 00405H; (* CYRILLIC CAPITAL LETTER DZE *)
			cp1251[0BEH] := 00455H; (* CYRILLIC SMALL LETTER DZE *)
			cp1251[0BFH] := 00457H; (* CYRILLIC SMALL LETTER YI *)
			cp1251[0C0H] := 00410H; (* CYRILLIC CAPITAL LETTER A *)
			cp1251[0C1H] := 00411H; (* CYRILLIC CAPITAL LETTER BE *)
			cp1251[0C2H] := 00412H; (* CYRILLIC CAPITAL LETTER VE *)
			cp1251[0C3H] := 00413H; (* CYRILLIC CAPITAL LETTER GHE *)
			cp1251[0C4H] := 00414H; (* CYRILLIC CAPITAL LETTER DE *)
			cp1251[0C5H] := 00415H; (* CYRILLIC CAPITAL LETTER IE *)
			cp1251[0C6H] := 00416H; (* CYRILLIC CAPITAL LETTER ZHE *)
			cp1251[0C7H] := 00417H; (* CYRILLIC CAPITAL LETTER ZE *)
			cp1251[0C8H] := 00418H; (* CYRILLIC CAPITAL LETTER I *)
			cp1251[0C9H] := 00419H; (* CYRILLIC CAPITAL LETTER SHORT I *)
			cp1251[0CAH] := 0041AH; (* CYRILLIC CAPITAL LETTER KA *)
			cp1251[0CBH] := 0041BH; (* CYRILLIC CAPITAL LETTER EL *)
			cp1251[0CCH] := 0041CH; (* CYRILLIC CAPITAL LETTER EM *)
			cp1251[0CDH] := 0041DH; (* CYRILLIC CAPITAL LETTER EN *)
			cp1251[0CEH] := 0041EH; (* CYRILLIC CAPITAL LETTER O *)
			cp1251[0CFH] := 0041FH; (* CYRILLIC CAPITAL LETTER PE *)
			cp1251[0D0H] := 00420H; (* CYRILLIC CAPITAL LETTER ER *)
			cp1251[0D1H] := 00421H; (* CYRILLIC CAPITAL LETTER ES *)
			cp1251[0D2H] := 00422H; (* CYRILLIC CAPITAL LETTER TE *)
			cp1251[0D3H] := 00423H; (* CYRILLIC CAPITAL LETTER U *)
			cp1251[0D4H] := 00424H; (* CYRILLIC CAPITAL LETTER EF *)
			cp1251[0D5H] := 00425H; (* CYRILLIC CAPITAL LETTER HA *)
			cp1251[0D6H] := 00426H; (* CYRILLIC CAPITAL LETTER TSE *)
			cp1251[0D7H] := 00427H; (* CYRILLIC CAPITAL LETTER CHE *)
			cp1251[0D8H] := 00428H; (* CYRILLIC CAPITAL LETTER SHA *)
			cp1251[0D9H] := 00429H; (* CYRILLIC CAPITAL LETTER SHCHA *)
			cp1251[0DAH] := 0042AH; (* CYRILLIC CAPITAL LETTER HARD SIGN *)
			cp1251[0DBH] := 0042BH; (* CYRILLIC CAPITAL LETTER YERU *)
			cp1251[0DCH] := 0042CH; (* CYRILLIC CAPITAL LETTER SOFT SIGN *)
			cp1251[0DDH] := 0042DH; (* CYRILLIC CAPITAL LETTER E *)
			cp1251[0DEH] := 0042EH; (* CYRILLIC CAPITAL LETTER YU *)
			cp1251[0DFH] := 0042FH; (* CYRILLIC CAPITAL LETTER YA *)
			cp1251[0E0H] := 00430H; (* CYRILLIC SMALL LETTER A *)
			cp1251[0E1H] := 00431H; (* CYRILLIC SMALL LETTER BE *)
			cp1251[0E2H] := 00432H; (* CYRILLIC SMALL LETTER VE *)
			cp1251[0E3H] := 00433H; (* CYRILLIC SMALL LETTER GHE *)
			cp1251[0E4H] := 00434H; (* CYRILLIC SMALL LETTER DE *)
			cp1251[0E5H] := 00435H; (* CYRILLIC SMALL LETTER IE *)
			cp1251[0E6H] := 00436H; (* CYRILLIC SMALL LETTER ZHE *)
			cp1251[0E7H] := 00437H; (* CYRILLIC SMALL LETTER ZE *)
			cp1251[0E8H] := 00438H; (* CYRILLIC SMALL LETTER I *)
			cp1251[0E9H] := 00439H; (* CYRILLIC SMALL LETTER SHORT I *)
			cp1251[0EAH] := 0043AH; (* CYRILLIC SMALL LETTER KA *)
			cp1251[0EBH] := 0043BH; (* CYRILLIC SMALL LETTER EL *)
			cp1251[0ECH] := 0043CH; (* CYRILLIC SMALL LETTER EM *)
			cp1251[0EDH] := 0043DH; (* CYRILLIC SMALL LETTER EN *)
			cp1251[0EEH] := 0043EH; (* CYRILLIC SMALL LETTER O *)
			cp1251[0EFH] := 0043FH; (* CYRILLIC SMALL LETTER PE *)
			cp1251[0F0H] := 00440H; (* CYRILLIC SMALL LETTER ER *)
			cp1251[0F1H] := 00441H; (* CYRILLIC SMALL LETTER ES *)
			cp1251[0F2H] := 00442H; (* CYRILLIC SMALL LETTER TE *)
			cp1251[0F3H] := 00443H; (* CYRILLIC SMALL LETTER U *)
			cp1251[0F4H] := 00444H; (* CYRILLIC SMALL LETTER EF *)
			cp1251[0F5H] := 00445H; (* CYRILLIC SMALL LETTER HA *)
			cp1251[0F6H] := 00446H; (* CYRILLIC SMALL LETTER TSE *)
			cp1251[0F7H] := 00447H; (* CYRILLIC SMALL LETTER CHE *)
			cp1251[0F8H] := 00448H; (* CYRILLIC SMALL LETTER SHA *)
			cp1251[0F9H] := 00449H; (* CYRILLIC SMALL LETTER SHCHA *)
			cp1251[0FAH] := 0044AH; (* CYRILLIC SMALL LETTER HARD SIGN *)
			cp1251[0FBH] := 0044BH; (* CYRILLIC SMALL LETTER YERU *)
			cp1251[0FCH] := 0044CH; (* CYRILLIC SMALL LETTER SOFT SIGN *)
			cp1251[0FDH] := 0044DH; (* CYRILLIC SMALL LETTER E *)
			cp1251[0FEH] := 0044EH; (* CYRILLIC SMALL LETTER YU *)
			cp1251[0FFH] := 0044FH; (* CYRILLIC SMALL LETTER YA *)

			FOR i := aLowBound[CP1251] TO 255 DO
				c := CHR(i);
				b := hashSearch(CP1251, TRUE, cp1251[i], c)
			END

		END

	END cp1251Init;

	PROCEDURE cp866Init;
	VAR
		i: INTEGER; b: BOOLEAN;
		c: CHAR;
	BEGIN

		IF ~(CP866 IN setInitDone) THEN
			setInitDone := setInitDone + {CP866};

			FOR i := 0 TO aLowBound[CP866] - 1 DO
				cp866[i] := i
			END;

			cp866[080H] := 00410H; (* CYRILLIC CAPITAL LETTER A *)
			cp866[081H] := 00411H; (* CYRILLIC CAPITAL LETTER BE *)
			cp866[082H] := 00412H; (* CYRILLIC CAPITAL LETTER VE *)
			cp866[083H] := 00413H; (* CYRILLIC CAPITAL LETTER GHE *)
			cp866[084H] := 00414H; (* CYRILLIC CAPITAL LETTER DE *)
			cp866[085H] := 00415H; (* CYRILLIC CAPITAL LETTER IE *)
			cp866[086H] := 00416H; (* CYRILLIC CAPITAL LETTER ZHE *)
			cp866[087H] := 00417H; (* CYRILLIC CAPITAL LETTER ZE *)
			cp866[088H] := 00418H; (* CYRILLIC CAPITAL LETTER I *)
			cp866[089H] := 00419H; (* CYRILLIC CAPITAL LETTER SHORT I *)
			cp866[08AH] := 0041AH; (* CYRILLIC CAPITAL LETTER KA *)
			cp866[08BH] := 0041BH; (* CYRILLIC CAPITAL LETTER EL *)
			cp866[08CH] := 0041CH; (* CYRILLIC CAPITAL LETTER EM *)
			cp866[08DH] := 0041DH; (* CYRILLIC CAPITAL LETTER EN *)
			cp866[08EH] := 0041EH; (* CYRILLIC CAPITAL LETTER O *)
			cp866[08FH] := 0041FH; (* CYRILLIC CAPITAL LETTER PE *)
			cp866[090H] := 00420H; (* CYRILLIC CAPITAL LETTER ER *)
			cp866[091H] := 00421H; (* CYRILLIC CAPITAL LETTER ES *)
			cp866[092H] := 00422H; (* CYRILLIC CAPITAL LETTER TE *)
			cp866[093H] := 00423H; (* CYRILLIC CAPITAL LETTER U *)
			cp866[094H] := 00424H; (* CYRILLIC CAPITAL LETTER EF *)
			cp866[095H] := 00425H; (* CYRILLIC CAPITAL LETTER HA *)
			cp866[096H] := 00426H; (* CYRILLIC CAPITAL LETTER TSE *)
			cp866[097H] := 00427H; (* CYRILLIC CAPITAL LETTER CHE *)
			cp866[098H] := 00428H; (* CYRILLIC CAPITAL LETTER SHA *)
			cp866[099H] := 00429H; (* CYRILLIC CAPITAL LETTER SHCHA *)
			cp866[09AH] := 0042AH; (* CYRILLIC CAPITAL LETTER HARD SIGN *)
			cp866[09BH] := 0042BH; (* CYRILLIC CAPITAL LETTER YERU *)
			cp866[09CH] := 0042CH; (* CYRILLIC CAPITAL LETTER SOFT SIGN *)
			cp866[09DH] := 0042DH; (* CYRILLIC CAPITAL LETTER E *)
			cp866[09EH] := 0042EH; (* CYRILLIC CAPITAL LETTER YU *)
			cp866[09FH] := 0042FH; (* CYRILLIC CAPITAL LETTER YA *)
			cp866[0A0H] := 00430H; (* CYRILLIC SMALL LETTER A *)
			cp866[0A1H] := 00431H; (* CYRILLIC SMALL LETTER BE *)
			cp866[0A2H] := 00432H; (* CYRILLIC SMALL LETTER VE *)
			cp866[0A3H] := 00433H; (* CYRILLIC SMALL LETTER GHE *)
			cp866[0A4H] := 00434H; (* CYRILLIC SMALL LETTER DE *)
			cp866[0A5H] := 00435H; (* CYRILLIC SMALL LETTER IE *)
			cp866[0A6H] := 00436H; (* CYRILLIC SMALL LETTER ZHE *)
			cp866[0A7H] := 00437H; (* CYRILLIC SMALL LETTER ZE *)
			cp866[0A8H] := 00438H; (* CYRILLIC SMALL LETTER I *)
			cp866[0A9H] := 00439H; (* CYRILLIC SMALL LETTER SHORT I *)
			cp866[0AAH] := 0043AH; (* CYRILLIC SMALL LETTER KA *)
			cp866[0ABH] := 0043BH; (* CYRILLIC SMALL LETTER EL *)
			cp866[0ACH] := 0043CH; (* CYRILLIC SMALL LETTER EM *)
			cp866[0ADH] := 0043DH; (* CYRILLIC SMALL LETTER EN *)
			cp866[0AEH] := 0043EH; (* CYRILLIC SMALL LETTER O *)
			cp866[0AFH] := 0043FH; (* CYRILLIC SMALL LETTER PE *)
			cp866[0B0H] := 02591H; (* LIGHT SHADE *)
			cp866[0B1H] := 02592H; (* MEDIUM SHADE *)
			cp866[0B2H] := 02593H; (* DARK SHADE *)
			cp866[0B3H] := 02502H; (* BOX DRAWINGS LIGHT VERTICAL *)
			cp866[0B4H] := 02524H; (* BOX DRAWINGS LIGHT VERTICAL AND LEFT *)
			cp866[0B5H] := 02561H; (* BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE *)
			cp866[0B6H] := 02562H; (* BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE *)
			cp866[0B7H] := 02556H; (* BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE *)
			cp866[0B8H] := 02555H; (* BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE *)
			cp866[0B9H] := 02563H; (* BOX DRAWINGS DOUBLE VERTICAL AND LEFT *)
			cp866[0BAH] := 02551H; (* BOX DRAWINGS DOUBLE VERTICAL *)
			cp866[0BBH] := 02557H; (* BOX DRAWINGS DOUBLE DOWN AND LEFT *)
			cp866[0BCH] := 0255DH; (* BOX DRAWINGS DOUBLE UP AND LEFT *)
			cp866[0BDH] := 0255CH; (* BOX DRAWINGS UP DOUBLE AND LEFT SINGLE *)
			cp866[0BEH] := 0255BH; (* BOX DRAWINGS UP SINGLE AND LEFT DOUBLE *)
			cp866[0BFH] := 02510H; (* BOX DRAWINGS LIGHT DOWN AND LEFT *)
			cp866[0C0H] := 02514H; (* BOX DRAWINGS LIGHT UP AND RIGHT *)
			cp866[0C1H] := 02534H; (* BOX DRAWINGS LIGHT UP AND HORIZONTAL *)
			cp866[0C2H] := 0252CH; (* BOX DRAWINGS LIGHT DOWN AND HORIZONTAL *)
			cp866[0C3H] := 0251CH; (* BOX DRAWINGS LIGHT VERTICAL AND RIGHT *)
			cp866[0C4H] := 02500H; (* BOX DRAWINGS LIGHT HORIZONTAL *)
			cp866[0C5H] := 0253CH; (* BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL *)
			cp866[0C6H] := 0255EH; (* BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE *)
			cp866[0C7H] := 0255FH; (* BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE *)
			cp866[0C8H] := 0255AH; (* BOX DRAWINGS DOUBLE UP AND RIGHT *)
			cp866[0C9H] := 02554H; (* BOX DRAWINGS DOUBLE DOWN AND RIGHT *)
			cp866[0CAH] := 02569H; (* BOX DRAWINGS DOUBLE UP AND HORIZONTAL *)
			cp866[0CBH] := 02566H; (* BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL *)
			cp866[0CCH] := 02560H; (* BOX DRAWINGS DOUBLE VERTICAL AND RIGHT *)
			cp866[0CDH] := 02550H; (* BOX DRAWINGS DOUBLE HORIZONTAL *)
			cp866[0CEH] := 0256CH; (* BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL *)
			cp866[0CFH] := 02567H; (* BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE *)
			cp866[0D0H] := 02568H; (* BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE *)
			cp866[0D1H] := 02564H; (* BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE *)
			cp866[0D2H] := 02565H; (* BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE *)
			cp866[0D3H] := 02559H; (* BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE *)
			cp866[0D4H] := 02558H; (* BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE *)
			cp866[0D5H] := 02552H; (* BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE *)
			cp866[0D6H] := 02553H; (* BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE *)
			cp866[0D7H] := 0256BH; (* BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE *)
			cp866[0D8H] := 0256AH; (* BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE *)
			cp866[0D9H] := 02518H; (* BOX DRAWINGS LIGHT UP AND LEFT *)
			cp866[0DAH] := 0250CH; (* BOX DRAWINGS LIGHT DOWN AND RIGHT *)
			cp866[0DBH] := 02588H; (* FULL BLOCK *)
			cp866[0DCH] := 02584H; (* LOWER HALF BLOCK *)
			cp866[0DDH] := 0258CH; (* LEFT HALF BLOCK *)
			cp866[0DEH] := 02590H; (* RIGHT HALF BLOCK *)
			cp866[0DFH] := 02580H; (* UPPER HALF BLOCK *)
			cp866[0E0H] := 00440H; (* CYRILLIC SMALL LETTER ER *)
			cp866[0E1H] := 00441H; (* CYRILLIC SMALL LETTER ES *)
			cp866[0E2H] := 00442H; (* CYRILLIC SMALL LETTER TE *)
			cp866[0E3H] := 00443H; (* CYRILLIC SMALL LETTER U *)
			cp866[0E4H] := 00444H; (* CYRILLIC SMALL LETTER EF *)
			cp866[0E5H] := 00445H; (* CYRILLIC SMALL LETTER HA *)
			cp866[0E6H] := 00446H; (* CYRILLIC SMALL LETTER TSE *)
			cp866[0E7H] := 00447H; (* CYRILLIC SMALL LETTER CHE *)
			cp866[0E8H] := 00448H; (* CYRILLIC SMALL LETTER SHA *)
			cp866[0E9H] := 00449H; (* CYRILLIC SMALL LETTER SHCHA *)
			cp866[0EAH] := 0044AH; (* CYRILLIC SMALL LETTER HARD SIGN *)
			cp866[0EBH] := 0044BH; (* CYRILLIC SMALL LETTER YERU *)
			cp866[0ECH] := 0044CH; (* CYRILLIC SMALL LETTER SOFT SIGN *)
			cp866[0EDH] := 0044DH; (* CYRILLIC SMALL LETTER E *)
			cp866[0EEH] := 0044EH; (* CYRILLIC SMALL LETTER YU *)
			cp866[0EFH] := 0044FH; (* CYRILLIC SMALL LETTER YA *)
			cp866[0F0H] := 00401H; (* CYRILLIC CAPITAL LETTER IO *)
			cp866[0F1H] := 00451H; (* CYRILLIC SMALL LETTER IO *)
			cp866[0F2H] := 00404H; (* CYRILLIC CAPITAL LETTER UKRAINIAN IE *)
			cp866[0F3H] := 00454H; (* CYRILLIC SMALL LETTER UKRAINIAN IE *)
			cp866[0F4H] := 00407H; (* CYRILLIC CAPITAL LETTER YI *)
			cp866[0F5H] := 00457H; (* CYRILLIC SMALL LETTER YI *)
			cp866[0F6H] := 0040EH; (* CYRILLIC CAPITAL LETTER SHORT U *)
			cp866[0F7H] := 0045EH; (* CYRILLIC SMALL LETTER SHORT U *)
			cp866[0F8H] := 000B0H; (* DEGREE SIGN *)
			cp866[0F9H] := 02022H; (* BULLET *)
			cp866[0FAH] := 000B7H; (* MIDDLE DOT *)
			cp866[0FBH] := 0221AH; (* SQUARE ROOT *)
			cp866[0FCH] := 02116H; (* NUMERO SIGN *)
			cp866[0FDH] := 000A4H; (* CURRENCY SIGN *)
			cp866[0FEH] := 025A0H; (* BLACK SQUARE *)
			cp866[0FFH] := 000A0H; (* NO-BREAK SPACE *)

			FOR i := aLowBound[CP866] TO 255 DO
				c := CHR(i);
				b := hashSearch(CP866, TRUE, cp866[i], c)
			END

		END
	END cp866Init;

	PROCEDURE iso88595Init;
	VAR
		i: INTEGER; b: BOOLEAN;
		c: CHAR;
	BEGIN

		IF ~(ISO88595 IN setInitDone) THEN
			setInitDone := setInitDone + {ISO88595};

			FOR i := 0 TO aLowBound[ISO88595] - 1 DO
				iso88595[i] := i
			END;

			iso88595[0A0H] := 000A0H; (* NO-BREAK SPACE *)
			iso88595[0A1H] := 00401H; (* CYRILLIC CAPITAL LETTER IO *)
			iso88595[0A2H] := 00402H; (* CYRILLIC CAPITAL LETTER DJE *)
			iso88595[0A3H] := 00403H; (* CYRILLIC CAPITAL LETTER GJE *)
			iso88595[0A4H] := 00404H; (* CYRILLIC CAPITAL LETTER UKRAINIAN IE *)
			iso88595[0A5H] := 00405H; (* CYRILLIC CAPITAL LETTER DZE *)
			iso88595[0A6H] := 00406H; (* CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I *)
			iso88595[0A7H] := 00407H; (* CYRILLIC CAPITAL LETTER YI *)
			iso88595[0A8H] := 00408H; (* CYRILLIC CAPITAL LETTER JE *)
			iso88595[0A9H] := 00409H; (* CYRILLIC CAPITAL LETTER LJE *)
			iso88595[0AAH] := 0040AH; (* CYRILLIC CAPITAL LETTER NJE *)
			iso88595[0ABH] := 0040BH; (* CYRILLIC CAPITAL LETTER TSHE *)
			iso88595[0ACH] := 0040CH; (* CYRILLIC CAPITAL LETTER KJE *)
			iso88595[0ADH] := 000ADH; (* SOFT HYPHEN *)
			iso88595[0AEH] := 0040EH; (* CYRILLIC CAPITAL LETTER SHORT U *)
			iso88595[0AFH] := 0040FH; (* CYRILLIC CAPITAL LETTER DZHE *)
			iso88595[0B0H] := 00410H; (* CYRILLIC CAPITAL LETTER A *)
			iso88595[0B1H] := 00411H; (* CYRILLIC CAPITAL LETTER BE *)
			iso88595[0B2H] := 00412H; (* CYRILLIC CAPITAL LETTER VE *)
			iso88595[0B3H] := 00413H; (* CYRILLIC CAPITAL LETTER GHE *)
			iso88595[0B4H] := 00414H; (* CYRILLIC CAPITAL LETTER DE *)
			iso88595[0B5H] := 00415H; (* CYRILLIC CAPITAL LETTER IE *)
			iso88595[0B6H] := 00416H; (* CYRILLIC CAPITAL LETTER ZHE *)
			iso88595[0B7H] := 00417H; (* CYRILLIC CAPITAL LETTER ZE *)
			iso88595[0B8H] := 00418H; (* CYRILLIC CAPITAL LETTER I *)
			iso88595[0B9H] := 00419H; (* CYRILLIC CAPITAL LETTER SHORT I *)
			iso88595[0BAH] := 0041AH; (* CYRILLIC CAPITAL LETTER KA *)
			iso88595[0BBH] := 0041BH; (* CYRILLIC CAPITAL LETTER EL *)
			iso88595[0BCH] := 0041CH; (* CYRILLIC CAPITAL LETTER EM *)
			iso88595[0BDH] := 0041DH; (* CYRILLIC CAPITAL LETTER EN *)
			iso88595[0BEH] := 0041EH; (* CYRILLIC CAPITAL LETTER O *)
			iso88595[0BFH] := 0041FH; (* CYRILLIC CAPITAL LETTER PE *)
			iso88595[0C0H] := 00420H; (* CYRILLIC CAPITAL LETTER ER *)
			iso88595[0C1H] := 00421H; (* CYRILLIC CAPITAL LETTER ES *)
			iso88595[0C2H] := 00422H; (* CYRILLIC CAPITAL LETTER TE *)
			iso88595[0C3H] := 00423H; (* CYRILLIC CAPITAL LETTER U *)
			iso88595[0C4H] := 00424H; (* CYRILLIC CAPITAL LETTER EF *)
			iso88595[0C5H] := 00425H; (* CYRILLIC CAPITAL LETTER HA *)
			iso88595[0C6H] := 00426H; (* CYRILLIC CAPITAL LETTER TSE *)
			iso88595[0C7H] := 00427H; (* CYRILLIC CAPITAL LETTER CHE *)
			iso88595[0C8H] := 00428H; (* CYRILLIC CAPITAL LETTER SHA *)
			iso88595[0C9H] := 00429H; (* CYRILLIC CAPITAL LETTER SHCHA *)
			iso88595[0CAH] := 0042AH; (* CYRILLIC CAPITAL LETTER HARD SIGN *)
			iso88595[0CBH] := 0042BH; (* CYRILLIC CAPITAL LETTER YERU *)
			iso88595[0CCH] := 0042CH; (* CYRILLIC CAPITAL LETTER SOFT SIGN *)
			iso88595[0CDH] := 0042DH; (* CYRILLIC CAPITAL LETTER E *)
			iso88595[0CEH] := 0042EH; (* CYRILLIC CAPITAL LETTER YU *)
			iso88595[0CFH] := 0042FH; (* CYRILLIC CAPITAL LETTER YA *)
			iso88595[0D0H] := 00430H; (* CYRILLIC SMALL LETTER A *)
			iso88595[0D1H] := 00431H; (* CYRILLIC SMALL LETTER BE *)
			iso88595[0D2H] := 00432H; (* CYRILLIC SMALL LETTER VE *)
			iso88595[0D3H] := 00433H; (* CYRILLIC SMALL LETTER GHE *)
			iso88595[0D4H] := 00434H; (* CYRILLIC SMALL LETTER DE *)
			iso88595[0D5H] := 00435H; (* CYRILLIC SMALL LETTER IE *)
			iso88595[0D6H] := 00436H; (* CYRILLIC SMALL LETTER ZHE *)
			iso88595[0D7H] := 00437H; (* CYRILLIC SMALL LETTER ZE *)
			iso88595[0D8H] := 00438H; (* CYRILLIC SMALL LETTER I *)
			iso88595[0D9H] := 00439H; (* CYRILLIC SMALL LETTER SHORT I *)
			iso88595[0DAH] := 0043AH; (* CYRILLIC SMALL LETTER KA *)
			iso88595[0DBH] := 0043BH; (* CYRILLIC SMALL LETTER EL *)
			iso88595[0DCH] := 0043CH; (* CYRILLIC SMALL LETTER EM *)
			iso88595[0DDH] := 0043DH; (* CYRILLIC SMALL LETTER EN *)
			iso88595[0DEH] := 0043EH; (* CYRILLIC SMALL LETTER O *)
			iso88595[0DFH] := 0043FH; (* CYRILLIC SMALL LETTER PE *)
			iso88595[0E0H] := 00440H; (* CYRILLIC SMALL LETTER ER *)
			iso88595[0E1H] := 00441H; (* CYRILLIC SMALL LETTER ES *)
			iso88595[0E2H] := 00442H; (* CYRILLIC SMALL LETTER TE *)
			iso88595[0E3H] := 00443H; (* CYRILLIC SMALL LETTER U *)
			iso88595[0E4H] := 00444H; (* CYRILLIC SMALL LETTER EF *)
			iso88595[0E5H] := 00445H; (* CYRILLIC SMALL LETTER HA *)
			iso88595[0E6H] := 00446H; (* CYRILLIC SMALL LETTER TSE *)
			iso88595[0E7H] := 00447H; (* CYRILLIC SMALL LETTER CHE *)
			iso88595[0E8H] := 00448H; (* CYRILLIC SMALL LETTER SHA *)
			iso88595[0E9H] := 00449H; (* CYRILLIC SMALL LETTER SHCHA *)
			iso88595[0EAH] := 0044AH; (* CYRILLIC SMALL LETTER HARD SIGN *)
			iso88595[0EBH] := 0044BH; (* CYRILLIC SMALL LETTER YERU *)
			iso88595[0ECH] := 0044CH; (* CYRILLIC SMALL LETTER SOFT SIGN *)
			iso88595[0EDH] := 0044DH; (* CYRILLIC SMALL LETTER E *)
			iso88595[0EEH] := 0044EH; (* CYRILLIC SMALL LETTER YU *)
			iso88595[0EFH] := 0044FH; (* CYRILLIC SMALL LETTER YA *)
			iso88595[0F0H] := 02116H; (* NUMERO SIGN *)
			iso88595[0F1H] := 00451H; (* CYRILLIC SMALL LETTER IO *)
			iso88595[0F2H] := 00452H; (* CYRILLIC SMALL LETTER DJE *)
			iso88595[0F3H] := 00453H; (* CYRILLIC SMALL LETTER GJE *)
			iso88595[0F4H] := 00454H; (* CYRILLIC SMALL LETTER UKRAINIAN IE *)
			iso88595[0F5H] := 00455H; (* CYRILLIC SMALL LETTER DZE *)
			iso88595[0F6H] := 00456H; (* CYRILLIC SMALL LETTER BYELORUSSIAN-UKRAINIAN I *)
			iso88595[0F7H] := 00457H; (* CYRILLIC SMALL LETTER YI *)
			iso88595[0F8H] := 00458H; (* CYRILLIC SMALL LETTER JE *)
			iso88595[0F9H] := 00459H; (* CYRILLIC SMALL LETTER LJE *)
			iso88595[0FAH] := 0045AH; (* CYRILLIC SMALL LETTER NJE *)
			iso88595[0FBH] := 0045BH; (* CYRILLIC SMALL LETTER TSHE *)
			iso88595[0FCH] := 0045CH; (* CYRILLIC SMALL LETTER KJE *)
			iso88595[0FDH] := 000A7H; (* SECTION SIGN *)
			iso88595[0FEH] := 0045EH; (* CYRILLIC SMALL LETTER SHORT U *)
			iso88595[0FFH] := 0045FH; (* CYRILLIC SMALL LETTER DZHE U *)

			FOR i := aLowBound[ISO88595] TO 255 DO
				c := CHR(i);
				b := hashSearch(ISO88595, TRUE, iso88595[i], c)
			END

		END
	END iso88595Init;

(* CP1251 File Format *)
PROCEDURE CP1251DecoderFactory*(): Codecs.TextDecoder;
VAR p: CP1251Decoder;
BEGIN
	cp1251Init;
	NEW(p);
	RETURN p
END CP1251DecoderFactory;

PROCEDURE CP1251EncoderFactory*(): Codecs.TextEncoder;
VAR p: CP1251Encoder;
BEGIN
	cp1251Init;
	NEW(p);
	RETURN p
END CP1251EncoderFactory;

(* KOI8R File Format *)
PROCEDURE KOI8RDecoderFactory*(): Codecs.TextDecoder;
VAR p: KOI8RDecoder;
BEGIN
	koi8rInit;
	NEW(p);
	RETURN p
END KOI8RDecoderFactory;

PROCEDURE KOI8REncoderFactory*(): Codecs.TextEncoder;
VAR p: KOI8REncoder;
BEGIN
	koi8rInit;
	NEW(p);
	RETURN p
END KOI8REncoderFactory;

(* KOI8U File Format *)
PROCEDURE KOI8UDecoderFactory*(): Codecs.TextDecoder;
VAR p: KOI8UDecoder;
BEGIN
	koi8uInit;
	NEW(p);
	RETURN p
END KOI8UDecoderFactory;

PROCEDURE KOI8UEncoderFactory*(): Codecs.TextEncoder;
VAR p: KOI8UEncoder;
BEGIN
	koi8uInit;
	NEW(p);
	RETURN p
END KOI8UEncoderFactory;

(* CP866 File Format *)
PROCEDURE CP866DecoderFactory*(): Codecs.TextDecoder;
VAR p: CP866Decoder;
BEGIN
	cp866Init;
	NEW(p);
	RETURN p
END CP866DecoderFactory;

PROCEDURE CP866EncoderFactory*(): Codecs.TextEncoder;
VAR p : CP866Encoder;
BEGIN
	cp866Init;
	NEW(p);
	RETURN p
END CP866EncoderFactory;

(* ISO-8859-5 File Format *)
PROCEDURE ISO88595DecoderFactory*(): Codecs.TextDecoder;
VAR p: ISO88595Decoder;
BEGIN
	iso88595Init;
	NEW(p);
	RETURN p
END ISO88595DecoderFactory;

PROCEDURE ISO88595EncoderFactory*(): Codecs.TextEncoder;
VAR p: ISO88595Encoder;
BEGIN
	iso88595Init;
	NEW(p);
	RETURN p
END ISO88595EncoderFactory;

PROCEDURE Init;
VAR
	i: INTEGER;
BEGIN
	FOR i := 0 TO PRIME - 1 DO
		hash[i].ucs32 := 0;
		hash[i].encodings := {}
	END;
	aLowBound[CP1251] := 080H;
	aLowBound[KOI8R] := 080H;
	aLowBound[KOI8U] := 080H;
	aLowBound[CP866] := 080H;
	aLowBound[ISO88595] := 0A0H;
	setInitDone := {};
	nCollisions := 0;
	bFirst := TRUE;
END Init;

PROCEDURE HashStat*(context: Commands.Context);
VAR
	i, n: INTEGER;
BEGIN
	n := 0;
	FOR i := 0 TO PRIME - 1 DO
		IF hash[i].ucs32 # 0 THEN
			INC(n)
		END
	END;
	IF n = 0 THEN
		context.out.Ln;
		context.out.String("Hash table not yet initialized.");
		context.out.Ln
	ELSE
		context.out.Ln;
		context.out.Int(n, 1);
		context.out.String(" of ");
		context.out.Int(PRIME, 1);
		context.out.String(" hash table cells used. Ratio: ");
		context.out.Float(n / PRIME, 20);
		context.out.Ln;
		context.out.String("Number of collisions: ");
		context.out.Int(nCollisions, 1);
		context.out.Ln
	END
END HashStat;

BEGIN
	Init
END CyrillicUtilities.

SystemTools.Free CyrillicUtilities~
CyrillicUtilities.HashStat ~
