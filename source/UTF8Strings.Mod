MODULE UTF8Strings;	(** pjm *)

(** UTF-8 encoded 0X-terminated UCS-32 strings. *)

(* Based on UTFStrings.Mod of TF and ISOStrings.Mod of jaco *)

CONST
	CmpLess* = -1; CmpEqual* = 0; CmpGreater* = 1;	 CmpError* = 2; (** results for Compare. *)

VAR
	CodeLength-: ARRAY 256 OF CHAR;	(** UTF-8 encoding length table. *)
	init: LONGINT;

(** -- Help procedures -- *)

(** Encode one UCS-32 value in ucs into one well-formed UTF-8 character at str[p..]. The parameter p is incremented by the number of
	characters needed to encode the UCS-32 value. *)
PROCEDURE EncodeChar*(ucs: LONGINT; VAR str: ARRAY OF CHAR; VAR i: LONGINT): BOOLEAN;
VAR len, j: LONGINT; byte, mask, max: INTEGER;
	buf: ARRAY 6 OF CHAR;
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

(** Decode one well-formed UTF-8 character at str[i..] and return its UCS-32 value in ucs.  When successful, parameter i is incremented to the start of the next UTF-8 character.  Otherwise, parameter i points to the byte where the error was detected (this will also be the next character in the case of a minimal coding error).  Return TRUE iff decoding succeeds. *)

PROCEDURE DecodeChar*(CONST str: ARRAY OF CHAR; VAR i, ucs: LONGINT): BOOLEAN;
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

(** Check whether str is a 0X-terminated well-formed UTF-8 string. *)

PROCEDURE Valid*(CONST str: ARRAY OF CHAR): BOOLEAN;
VAR i, ucs: LONGINT;
BEGIN
	i := 0;
	WHILE DecodeChar(str, i, ucs) DO
		IF ucs = 0 THEN RETURN TRUE END
		(* i already incremented *)
	END;
	RETURN FALSE
END Valid;

(** Return the size of a string in bytes, excluding the terminating 0X.  Another way of seeing this is that the function returns the byte offset of the terminating 0X. *)

PROCEDURE Size*(CONST str: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN
	i := 0; WHILE str[i] # 0X DO INC(i) END;
	RETURN i
END Size;

(** Set the size (in bytes) of a UTF-8 string by setting the terminating 0X.  If the specified size is larger than LEN(str)-1, the size will be set to this.  If the 0X falls in the middle of a UTF-8 character, the string is truncated before this character. *)

PROCEDURE SetSize*(VAR str: ARRAY OF CHAR; size: LONGINT);
VAR i: LONGINT;
BEGIN
	IF size > LEN(str)-1 THEN size := LEN(str)-1 END;
	IF size > 0 THEN	(* make sure last character is valid *)
		i := size-1;	(* last byte of last character *)
		IF str[i] >= 80X THEN	(* starting or middle byte *)
			WHILE ASH(LONG(ORD(str[i])), -6) = 2 DO DEC(i) END;	(* find starting byte *)
			IF i + ORD(CodeLength[ORD(str[i])]) > size THEN size := i END	(* if not complete, truncate *)
		END
	END;
	str[size] := 0X
END SetSize;

(** Return the byte offset of the UTF-8 character with index idx, counting from 0.  If idx is past the end of the string, return the offset of the terminating 0X, and if idx is negative, return 0.  This is also the definition of an UTF-8 index used by the other procedures. *)

PROCEDURE OffsetOfIndex*(CONST str: ARRAY OF CHAR; idx: LONGINT): LONGINT;
VAR i, ch: LONGINT;
BEGIN
	i := 0;
	LOOP	(* find position *)
		IF idx <= 0 THEN EXIT END;
		ch := LONG(ORD(str[i]));
		IF ch = 0 THEN EXIT END;
		DEC(idx); INC(i, LONG(ORD(CodeLength[ch])))
	END;
	RETURN i
END OffsetOfIndex;

(** -- String manipulation. -- *)

(** Return the number of UTF-8 characters in str, excluding the terminating 0X. *)

PROCEDURE Length*(CONST str: ARRAY OF CHAR): LONGINT;
VAR i, len, ch: LONGINT;
BEGIN
	i := 0; len := 0;
	LOOP	(* count characters *)
		ch := LONG(ORD(str[i]));
		IF ch = 0 THEN EXIT END;
		INC(i, LONG(ORD(CodeLength[ch])));
		INC(len)
	END;
	RETURN len
END Length;

(** Copy src to dst.  Unlike COPY, ensure that dst is not truncated in the middle of a UTF-8 character.*)

PROCEDURE Assign*(CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	LOOP	(* copy characters *)
		ch := src[i];
		IF (ch = 0X) OR (i = LEN(dst)) THEN EXIT END;
		dst[i] := ch; INC(i)
	END;
	SetSize(dst, i)
END Assign;

(** Copy at most num UTF-8 characters from src to dst, starting at UTF-8 index idx.  If num is negative, treat it as 0.  *)

PROCEDURE Extract*(CONST src: ARRAY OF CHAR; idx, num: LONGINT; VAR dst: ARRAY OF CHAR);
VAR i, j: LONGINT; ch: CHAR;
BEGIN
	i := OffsetOfIndex(src, idx); j := 0;
	LOOP	(* copy characters *)
		ch := src[i];
		IF (ch = 0X) OR (j = LEN(dst)) THEN EXIT END;
		IF ASH(LONG(ORD(ch)), -6) # 2 THEN DEC(num) END;	(* about to copy a starting byte *)
		IF num < 0 THEN EXIT END;
		dst[j] := ch; INC(i); INC(j)
	END;
	SetSize(dst, j)
END Extract;

(** Delete num UTF-8 characters from str, starting at UTF-8 index idx.  The characters following the deleted characters are shifted down to index idx.  If less than num characters are present at idx, delete all characters up to the end of the string. *)

PROCEDURE Delete*(VAR str: ARRAY OF CHAR; idx, num: LONGINT);
VAR i, j: LONGINT; ch: CHAR;
BEGIN
	i := OffsetOfIndex(str, idx); j := i;
	LOOP	(* skip over deleted characters *)
		ch := str[j];
		IF (num <= 0) OR (ch = 0X) THEN EXIT END;
		INC(j, ORD(CodeLength[ORD(ch)]));
		DEC(num)
	END;
	LOOP	(* copy remaining characters over *)
		str[i] := ch;
		IF ch = 0X THEN EXIT END;
		INC(i); INC(j);
		ch := str[j]
	END
END Delete;

(** Append src to dst. *)

PROCEDURE Append*(CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
VAR i, j: LONGINT; ch: CHAR;
BEGIN
	i := 0; j := Size(dst);
	LOOP	(* copy characters *)
		ch := src[i];
		IF (ch = 0X) OR (j = LEN(dst)) THEN EXIT END;
		dst[j] := ch; INC(i); INC(j)
	END;
	SetSize(dst, j)
END Append;

(** Concatenate src2 onto src1 and copy the result to dst. *)

PROCEDURE Concat*(CONST src1, src2: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
BEGIN
	Assign(src1, dst); Append(src2, dst)
END Concat;

(** Insert src into dst at UTF-8 index idx.  The characters from idx onwards are shifted up to make space for the inserted characters. *)

PROCEDURE Insert*(CONST src: ARRAY OF CHAR; idx: LONGINT; VAR dst: ARRAY OF CHAR);
VAR i, j, m, n: LONGINT; ch: CHAR;
BEGIN
		(* make space in dst for src *)
	n := Size(src); m := Size(dst);
	j := OffsetOfIndex(dst, idx); i := m-1;
	WHILE i >= j DO	(* move dst[j..] up n bytes *)
		IF i+n < LEN(dst) THEN dst[i+n] := dst[i] END;
		DEC(i)
	END;
		(* copy src into space *)
	i := 0;
	LOOP
		ch := src[i];
		IF (ch = 0X) OR (j = LEN(dst)) THEN EXIT END;
		dst[j] := ch; INC(i); INC(j)
	END;
	SetSize(dst, m+n)
END Insert;

(*
operation too obscure
(** Replace the characters of dst starting at UTF-8 index idx with the characters from src. *)

PROCEDURE Replace*(src: ARRAY OF CHAR; idx: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	Delete(dst, idx, Length(src)); Insert(src, idx, dst)
END Replace;
*)

(** Transform a well-formed UTF-8 string into an 8-bit ASCII representation. Characters not present in the ASCII format are replaced
	by 'substitute' if it is # 0X. *)

PROCEDURE UTF8toASCII*(CONST src: ARRAY OF CHAR; substitute: CHAR; VAR dst: ARRAY OF CHAR): LONGINT;
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

(** Transform an 8-bit ASCII string into a well-formed UTF-8 string. *)

PROCEDURE ASCIItoUTF8*(CONST ascii: ARRAY OF CHAR; VAR utf8: ARRAY OF CHAR);
VAR i,j: LONGINT; dummy: BOOLEAN;
BEGIN
	i := 0; j := 0;
	WHILE (ascii[i] # 0X) & EncodeChar(ORD(ascii[i]), utf8, j) DO INC(i) END;
	dummy := EncodeChar(0, utf8, j)
END ASCIItoUTF8;

(** Transform a well-formed UTF-8 string into an array of UCS-32 values, ucs[idx...]. The UCS-32 representation is terminated with a 0 value.
	The parameter idx points to the next free entry after the conversion. *)

PROCEDURE UTF8toUnicode*(CONST utf8: ARRAY OF CHAR; VAR ucs: ARRAY OF LONGINT; VAR idx: LONGINT);
VAR p, l: LONGINT;
BEGIN
	p := 0; l := LEN(ucs)-1;
	WHILE (idx < l) & DecodeChar(utf8, p, ucs[idx]) & (ucs[idx] > 0)  DO INC(idx) END;
	ucs[idx] := 0; INC(idx)
END UTF8toUnicode;

(** Transform a 4-byte, 0-terminated unicode character 'ucs' into a well-formed UTF-8 representation *)

PROCEDURE UnicodetoUTF8*(CONST ucs: ARRAY OF LONGINT; VAR utf8: ARRAY OF CHAR);
VAR b: BOOLEAN; i, p, l: LONGINT;
BEGIN
	b := TRUE; i := 0; p := 0; l := LEN(ucs);
	WHILE (i < l) & b DO
		b := EncodeChar(ucs[i], utf8, p);
		INC(i)
	END
END UnicodetoUTF8;

(** Convert all simple lower-case letters in a well-formed UTF-8 string to upper case. The resulting string is still in UTF-8 form *)

PROCEDURE UpperCase*(CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	WHILE (src[i] # 0X) DO
		IF (src[i] >= "a") & (src[i] <= "z") THEN dst[i] := CAP(src[i]) (* this works because non-ASCII chars have bit 7 set *)
		ELSE dst[i] := src[i]
		END;
		INC(i)
	END;
	dst[i] := 0X
END UpperCase;

(** -- Test procedures -- *)

(** Return TRUE iff Assign can be performed without truncation. *)

PROCEDURE CanAssign*(CONST src, dst : ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN Size(src)+1 <= LEN(dst)
END CanAssign;

(** todo: Return TRUE iff Extract can be performed without truncation, and src contains at least num UTF-8 characters. *)

PROCEDURE CanExtract*(CONST src: ARRAY OF CHAR; idx, num: LONGINT; CONST dst: ARRAY OF CHAR): BOOLEAN;
BEGIN
	HALT(99)
END CanExtract;

(** todo: Return TRUE iff there are num UTF-8 characters to delete at UTF-8 index idx in str. *)

PROCEDURE CanDelete*(CONST str: ARRAY OF CHAR; idx, num: LONGINT);
BEGIN
	HALT(99)
END CanDelete;

(** todo: Return TRUE iff Append can be performed without truncation. *)

PROCEDURE CanAppend*(CONST src: ARRAY OF CHAR; CONST dst: ARRAY OF CHAR): BOOLEAN;
BEGIN
	HALT(99)
END CanAppend;

(** todo: Return TRUE iff Concat can be performed without truncation. *)

PROCEDURE CanConcat*(CONST src1, src2, dst : ARRAY OF CHAR): BOOLEAN;
BEGIN
	HALT(99)
END CanConcat;

(** todo: Return TRUE iff Insert can be performed without truncation. *)

PROCEDURE CanInsert*(CONST src: ARRAY OF CHAR; idx: LONGINT; CONST dst: ARRAY OF CHAR): BOOLEAN;
BEGIN
	HALT(99)
END CanInsert;

(*
(** todo: Return TRUE iff Replace can be performed without truncation. *)

PROCEDURE CanReplace*(src: ARRAY OF CHAR; idx: LONGINT; VAR dst: ARRAY OF CHAR): BOOLEAN;
BEGIN
	HALT(99)
END CanReplace;
*)

(** -- Comparison and searching. -- *)

(** Compare str1 and str2 lexically, and return CmpLess if str1 is less than str2, CmpEqual if str1 and str2 are equal, or CmpGreater if str1 is greater than str2. *)

PROCEDURE Compare*(CONST str1, str2: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	LOOP
		ch := str1[i];
		IF ch # str2[i] THEN EXIT END;
		IF ch = 0X THEN RETURN CmpEqual END;
		INC(i)
	END;
	IF ch < str2[i] THEN RETURN CmpLess ELSE RETURN CmpGreater END
END Compare;

PROCEDURE CompareToUnicode*(CONST utf8 : ARRAY OF CHAR; CONST unicode : ARRAY OF LONGINT) : LONGINT;
VAR len, i, j, char, ucs, result : LONGINT; valid, abort : BOOLEAN;
BEGIN
	len := LEN(unicode);
	i := 0; j := 0; valid := TRUE; abort := FALSE;
	WHILE valid & ~abort & (j < len) DO
		valid := DecodeChar(utf8, i, char);
		ucs := unicode[j];
		abort := (char # ucs) OR (char = 0);
		INC(j);
	END;
	IF valid THEN
		IF (char = 0) & (ucs = 0) THEN result := CmpEqual;
		ELSIF (char < ucs) THEN result := CmpLess;
		ELSE result := CmpGreater;
		END;
	ELSE
		result := CmpError;
	END;
	RETURN result;
END CompareToUnicode;

(*
rather use Oberon = operator
(** Return TRUE iff str1 and str2 are lexically equal. *)

PROCEDURE Equal*(str1, str2: ARRAY OF CHAR): BOOLEAN;
VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	LOOP
		ch := str1[i];
		IF ch # str2[i] THEN RETURN FALSE END;
		IF ch = 0X THEN RETURN TRUE END;
		INC(i)
	END
END Equal;
*)

(** todo: Search forward for the next occurrance of UTF-8 string pat in UTF-8 string str, starting at UTF-8 index startidx.  Return found = TRUE iff the pattern was found.  If found, patidx is the UTF-8 index where the pattern was found, otherwise it is unchanged. *)

PROCEDURE FindNext*(CONST pat, str: ARRAY OF CHAR; startidx: LONGINT; VAR found: BOOLEAN; VAR patidx: LONGINT);
BEGIN
	HALT(99)
END FindNext;

(** todo: Search backward for the previous occurrance of UTF-8 string pat in UTF-8 string str, starting at UTF-8 index startidx.  Return found = TRUE iff the pattern was found.  If found, patidx is the UTF-8 index where the pattern was found (in the range 0..startidx), otherwise it is unchanged. *)

PROCEDURE FindPrev*(CONST pat, str: ARRAY OF CHAR; startidx: LONGINT; VAR found: BOOLEAN; VAR patidx: LONGINT);
BEGIN
	HALT(99)
END FindPrev;

(** Compare str1 and str2 and return different = TRUE iff a difference was found.  If the strings are different, idx is set to the UTF-8 index of the first mismatching character, otherwise it is unchanged. *)

PROCEDURE FindDiff*(CONST str1, str2: ARRAY OF CHAR; VAR different: BOOLEAN; VAR idx: LONGINT);
VAR i, j: LONGINT; ch: CHAR;
BEGIN
	i := 0; j := -1;	(* i is byte position, j is current character index *)
	LOOP
		ch := str1[i];
		IF ASH(LONG(ORD(ch)), -6) # 2 THEN INC(j) END;	(* about to compare a starting byte *)
		IF ch # str2[i] THEN
			different := TRUE; idx := j;
			EXIT
		END;
		IF ch = 0X THEN
			different := FALSE;
			EXIT
		END;
		INC(i)
	END
END FindDiff;

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
END UTF8Strings.

(**
Notes:

This module manages UCS-32 0X-terminated character strings encoded as multi-byte UTF-8 strings.  The UTF-8 encoding is decribed in RFC2279.

A CHAR value in a UTF-8 string can have one of three roles.  First, it can be a 7-bit ASCII character directly encoded as one byte.  Second, it can be the starting byte of a UCS-32 character encoded as 2 to 6 bytes.  Third, it can be a non-starting byte of a UCS-32 character encoded as 2 to 6 bytes.

The role of a CHAR ch is encoded in its top two bits, as follows:
	ASH(ORD(ch), -6) < 2, role is ASCII character (can also test ch < 80X).
	ASH(ORD(ch), -6) = 2, role is non-starting byte of a multi-byte sequence.
	ASH(ORD(ch), -6) = 3, role is starting byte of a multi-byte sequence.

The CodeLength string can be used to find the length of an encoding.  Assuming ch is the starting byte of an encoding, ORD(CodeLength[ORD(ch)]) is the total number of bytes in the encoding.  If ch is not a starting byte, this expression will return 7, indicating an error.

All string input parameters (except in DecodeChar, Valid and SetSize) are assumed to be 0X-terminated, well-formed UTF-8 strings.  All string output parameters produced are also 0X-terminated, well-formed UTF-8 strings.  It is assumed that the LEN of all ARRAY OF CHAR parameters is positive.  Violations of these assumptions may cause run-time exceptions, but not endless loops or memory corruption.

In a secure network application, UTF-8 strings received over the network MUST first be validated, and only used if found to be valid.  The reason is some invalid encodings can be used to code characters in alternate ways, which may bypass security checks, or cause other problems.  See the RFC for more details.

All the procedures truncate the destination string at a UTF-8 character boundary if enough space is not available.  A CanX function can be used to check whether truncation will occur if operation X is performed with the specified parameters.

String constants in Oberon programs are not necessarily well-formed UTF-8 strings, unless they contain only ASCII characters (below 80X).

The Oberon built-in procedure COPY does not necessarily produce a well-formed UTF-8 string, because it can truncate the destination string in the middle of a multi-byte character.  Rather use the Assign procedure from this module.

The Oberon string comparison operators <, <=, =, >=, > can be used on UTF-8 strings for lexical comparisons.
*)

(*
o assume indexes are inside string?  except lengths
*)

Backup.WriteFiles UTF8Strings.Mod ~
