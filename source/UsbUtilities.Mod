MODULE UsbUtilities; (** AUTHOR "staubesv"; PURPOSE "Utility procedures for USB modules"; *)
(**
 * The purpose of this module is to keep the USB boot file small. It duplicates some functionality of the modules
 * UTF8Strings.Mod and Utiltities.Mod, so the USB modules can use it without importing those modules.
 *)

VAR
	CodeLength: ARRAY 256 OF CHAR;	(** UTF-8 encoding length table. *)

TYPE

	AsciiString* = POINTER TO ARRAY OF CHAR;
	UnicodeString*	= POINTER TO ARRAY OF LONGINT;

PROCEDURE Unicode2Ascii*(unicode : UnicodeString) : AsciiString;
VAR utf8, ascii : AsciiString; res : LONGINT;
BEGIN
	IF unicode # NIL THEN
		NEW(utf8, LEN(unicode)+1);  (* +1 because of the 0X string termination *)
		NEW(ascii, LEN(unicode)+1);
		UnicodetoUTF8(unicode^,utf8^);
		res := UTF8toASCII(utf8^, "-", ascii^); (* ignore res *)
	END;
	IF ascii # NIL THEN TrimWS(ascii^); END;
	RETURN ascii;
END Unicode2Ascii;

PROCEDURE DecodeChar(CONST str: ARRAY OF CHAR; VAR i, ucs: LONGINT): BOOLEAN;
VAR len, ch, min: LONGINT;
BEGIN
	IF i < LEN(str) THEN
		ch := LONG(ORD(str[i]));
		IF ch < 80H THEN	(* ASCII *)
			ucs := ch; INC(i);
			RETURN TRUE
		ELSE
			CASE CodeLength[ch] OF
				2X: ucs := ch MOD 20H; len := 2; min := 80H
				|3X: ucs := ch MOD 10H; len := 3; min := 800H
				|4X: ucs := ch MOD 8; len := 4; min := 10000H
				|5X: ucs := ch MOD 4; len := 5; min := 200000H
				|6X: ucs := ch MOD 2; len := 6; min := 4000000H
				ELSE RETURN FALSE	(* non-starting character *)
			END;
			LOOP
				INC(i); DEC(len);
				IF len = 0 THEN RETURN ucs >= min END;
				IF i = LEN(str) THEN EXIT END;
				ch := LONG(ORD(str[i]));
				IF ASH(ch, -6) # 2 THEN EXIT END;
				ucs := ASH(ucs, 6) + ch MOD 40H
			END
		END
	END;
	RETURN FALSE
END DecodeChar;

PROCEDURE EncodeChar(ucs: LONGINT; VAR str: ARRAY OF CHAR; VAR i: LONGINT): BOOLEAN;
VAR len, j: LONGINT; byte, mask, max: INTEGER; buf: ARRAY 6 OF CHAR;
BEGIN
	len := LEN(str);

	IF (ucs <= 7FH) THEN
		IF (i + 1 < len) THEN str[i] := CHR(SHORT(ucs));
			str[i+1] := 0X;
			INC(i)
		ELSE RETURN FALSE
		END
	ELSE
		byte := 0; mask := 7F80H; max := 3FH;

		WHILE (ucs > max) DO
			buf[byte] := CHR(80H + SHORT(ucs MOD 40H)); INC(byte); (* CHR(80H + SHORT(AND(ucs, 3FH))) *)
			ucs := ucs DIV 64; (* LSH(ucs, -6) *)
			mask := mask DIV 2; (* 80H + LSH(mask, -1). Left-most bit remains set after DIV (mask is negative) *)
			max := max DIV 2; (* LSH(max, -1) *)
		END;
		buf[byte] := CHR(mask + SHORT(ucs));

		IF (i + byte + 1 < len) THEN
			FOR j := 0 TO byte DO str[i + j] := buf[byte - j] END;
			str[i+byte+1] := 0X;
			i := i + byte + 1
		ELSE RETURN FALSE
		END
	END;
	RETURN TRUE
END EncodeChar;

PROCEDURE UnicodetoUTF8(CONST ucs: ARRAY OF LONGINT; VAR utf8: ARRAY OF CHAR);
VAR b: BOOLEAN; i, p, l: LONGINT;
BEGIN
	b := TRUE; i := 0; p := 0; l := LEN(ucs);
	WHILE (i < l) & b DO
		b := EncodeChar(ucs[i], utf8, p);
		INC(i)
	END
END UnicodetoUTF8;

PROCEDURE UTF8toASCII(CONST src:  ARRAY OF CHAR; substitute: CHAR; VAR dst: ARRAY OF CHAR): LONGINT;
VAR count, i, len, pos, ucs: LONGINT;
BEGIN
	len := LEN(dst); ucs := -1;
	WHILE (ucs # 0) & DecodeChar(src, pos, ucs) & (i < len) DO
		IF (ucs >= 0) & (ucs < 100H) THEN dst[i] := CHR(ucs); INC(i)
		ELSIF (substitute # 0X) THEN dst[i] := substitute; INC(i); INC(count)
		END
	END;
	RETURN count
END UTF8toASCII;

PROCEDURE InitUTFCodeLength;
VAR init : LONGINT;
BEGIN
	(* 0000 0000-0000 007F  0xxxxxxx *)
	FOR init := 0 TO 7FH DO CodeLength[init] := 1X END;
	(* ???? ????-???? ????  10xxxxxx *)
	FOR init := 80H TO 0BFH DO CodeLength[init] := 7X END;	(* non-starting byte *)
	(* 0000 0080-0000 07FF  110xxxxx 10xxxxxx *)
	FOR init := 0C0H TO 0DFH DO CodeLength[init] := 2X END;
	(* 0000 0800-0000 FFFF  1110xxxx 10xxxxxx 10xxxxxx *)
	FOR init := 0E0H TO 0EFH DO CodeLength[init] := 3X END;
	(* 0001 0000-001F FFFF  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx *)
	FOR init := 0F0H TO 0F7H DO CodeLength[init] := 4X END;
	(* 0020 0000-03FF FFFF  111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx *)
	FOR init := 0F8H TO 0FBH DO CodeLength[init] := 5X END;
	(* 0400 0000-7FFF FFFF  1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx *)
	FOR init := 0FCH TO 0FDH DO CodeLength[init] := 6X END
END InitUTFCodeLength;

PROCEDURE NewString*(CONST str : ARRAY OF CHAR) : AsciiString;
VAR l : LONGINT; s : AsciiString;
BEGIN
	l := Length(str) + 1;
	NEW(s, l);
	COPY(str, s^);
	RETURN s
END NewString;

(* Returns the length of a string (from Strings.Mod) *)
PROCEDURE Length*(CONST string: ARRAY OF CHAR) : LONGINT;
VAR len: LONGINT;
BEGIN
	len := 0; WHILE (string[len] # 0X) DO INC(len) END;
	RETURN len
END Length;

(* Omitts leading and trailing whitespace of string s (from Strings.Mod) *)
PROCEDURE TrimWS*(VAR s : ARRAY OF CHAR);
VAR len, start, i : LONGINT;
BEGIN
	len := Length(s);
	start := 0;
	WHILE (start < len) & (ORD(s[start]) < 33) DO
		INC(start);
	END;
	WHILE (start < len) & (ORD(s[len-1]) < 33) DO
		DEC(len);
	END;
	IF start > 0 THEN
		FOR i := 0 TO len - start - 1 DO
			s[i] := s[start + i];
		END;
		s[i] := 0X;
	ELSE
		s[len] := 0X;
	END;
END TrimWS;

BEGIN
	InitUTFCodeLength;
END UsbUtilities.