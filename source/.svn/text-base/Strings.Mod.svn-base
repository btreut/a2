MODULE Strings; (** AUTHOR "be,tf, staubesv"; PURPOSE "String functions" *)

IMPORT SYSTEM, Streams, Reals, Dates;

CONST
	Ok* = 0;

TYPE
	String* = POINTER TO ARRAY OF CHAR;

	StringArray* = POINTER TO ARRAY OF String;

VAR
	DateFormat*, TimeFormat*: ARRAY 32 OF CHAR;	(** date and time format strings used by DateToStr/TimeToStr *)

TYPE

	(** The stringmaker creates an automatically growing character array from the input with an Streams writer *)
	Buffer* = OBJECT
	VAR
		length : LONGINT;
		data : String;
		w : Streams.Writer;

		PROCEDURE &Init*(initialSize : LONGINT);
		BEGIN
			IF initialSize < 16 THEN initialSize := 256 END;
			NEW(data, initialSize); length := 0;
		END Init;

		PROCEDURE Add*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR newSize, i : LONGINT; n : String;
		BEGIN
			IF length + len + 1 >= LEN(data) THEN
				newSize := Max(LEN(data) * 2, length + len + 1);
				NEW(n, newSize);
				FOR i := 0 TO length - 1 DO n[i] := data[i] END;
				data := n;
			END;
			WHILE len > 0 DO
				data[length] := buf[ofs];
				INC(ofs); INC(length); DEC(len);
			END;
			data[length] := 0X;
			res := Ok;
		END Add;

		(** resets the length of the string to 0. The buffer is reused*)
		PROCEDURE Clear*;
		BEGIN
			data[0] := 0X;
			length := 0
		END Clear;

		(** returns an Streams.Writer to the string *)
		PROCEDURE GetWriter*() : Streams.Writer;
		BEGIN
			IF w = NIL THEN NEW(w, SELF.Add, 256) END;
			RETURN w
		END GetWriter;

		(** returns the number of bytes written to the string. The Streams.Writer is updated *)
		PROCEDURE GetLength*() : LONGINT;
		BEGIN
			IF w # NIL THEN w.Update END;
			RETURN length
		END GetLength;

		(** returns the current string buffer. If the string maker is reused, the content of the string may or may not
			vary. The application might need to copy the returned string. The Streams.Writer is updated *)
		PROCEDURE GetString*() : String;
		BEGIN
			IF w # NIL THEN w.Update END;
			RETURN data
		END GetString;

		PROCEDURE Write*(out : Streams.Writer);
		BEGIN
			IF w # NIL THEN w.Update END;
			out.Bytes(data^, 0, length)
		END Write;

	END Buffer;

(** useful functions *)

PROCEDURE Min*(a,b: LONGINT): LONGINT;
BEGIN IF (a < b) THEN RETURN a ELSE RETURN b END
END Min;

PROCEDURE Max*(a,b: LONGINT): LONGINT;
BEGIN IF (a > b) THEN RETURN a ELSE RETURN b END
END Max;

(** string handling *)

(** returns the length of a string *)
PROCEDURE Length* (CONST string: ARRAY OF CHAR): LONGINT;
VAR len: LONGINT;
BEGIN
	len := 0; WHILE (string[len] # 0X) DO INC(len) END;
	RETURN len
END Length;

(** Find position of character, returns -1 if not found*)
PROCEDURE Find* (CONST string: ARRAY OF CHAR; pos: LONGINT; ch: CHAR): LONGINT;
BEGIN
	WHILE (string[pos] # 0X ) & (string[pos] # ch) DO INC(pos) END;
	IF string[pos] = 0X THEN pos := -1 END;
	RETURN pos
END Find;

(** returns the number of occurences of ch within string *)
PROCEDURE Count* (CONST string: ARRAY OF CHAR; ch: CHAR): LONGINT;
VAR count, pos: LONGINT;
BEGIN
	count := 0; pos := Find (string, 0, ch);
	WHILE pos # -1 DO INC (count); pos := Find (string, pos + 1, ch) END;
	RETURN count
END Count;

(** truncates string to length *)
PROCEDURE Truncate* (VAR string: ARRAY OF CHAR; length: LONGINT);
BEGIN
	IF LEN(string) > length THEN string[length] := 0X END;
END Truncate;

(**
 * Returns the position of the first occurrence of pattern in the string or -1 if no occurrence is found.
 * Rabin-Karp algorithm, adopted from Sedgewick.
 *)
PROCEDURE Pos*(CONST pattern, string: ARRAY OF CHAR): LONGINT;
CONST
	q = 8204957;	(* prime number, {(d+1) * q <= MAX(LONGINT)} *)
	d = 256;			(* number of different characters *)
VAR h1, h2, dM, i, j, m, n: LONGINT; found : BOOLEAN;
BEGIN
	m := Length(pattern); n := Length(string);
	IF (m > n) THEN RETURN -1 END;

	dM := 1; FOR i := 0 TO m-2 DO dM := (d*dM) MOD q END;
	h1 := 0; FOR i := 0 TO m-1 DO h1 := (h1*d + ORD(pattern[i])) MOD q END;
	h2 := 0; FOR i := 0 TO m-1 DO h2 := (h2*d + ORD(string[i])) MOD q END;
	i := 0; found := FALSE;

	IF (h1 = h2) THEN (* verify *)
		j := 0; found := TRUE;
		WHILE (j < m) DO
			IF (string[j] # pattern[j]) THEN found := FALSE; j := m; END; (* hash values are equal, but strings are not *)
			INC(j);
		END;
	END;

	WHILE ~found & (i < n-m) DO
		h2 := (h2 + d*q - ORD(string[i])*dM) MOD q;
		h2 := (h2*d + ORD(string[i+m])) MOD q;
		INC(i);

		IF (h1 = h2) THEN (* verify *)
			j := 0; found := TRUE;
			WHILE (j < m) DO
				IF (string[i + j] # pattern[j]) THEN found := FALSE; j := m; END; (* hash values are equal, but strings are not *)
				INC(j);
			END
		END;
	END;

	IF found THEN
		RETURN i;
	ELSE
		RETURN -1
	END
END Pos;

(** More generic version of Pos. Basically the same search algorithm, but can also perform case-insensitive searching and/or
 * backwards directed searching.
 * Returns the position of the first character of the first occurence of 'pattern' in 'text'  in search direction or -1 if pattern not found *)
PROCEDURE GenericPos*(CONST pattern: ARRAY OF CHAR; from : LONGINT; CONST string: ARRAY OF CHAR; ignoreCase, backwards : BOOLEAN): LONGINT;
CONST
	q = 8204957;	(* prime number, {(d+1) * q <= MAX(LONGINT)} *)
	d = 256;			(* number of different characters *)
VAR ch, chp : CHAR; h1, h2, dM, i, j, patternLength, stringLength: LONGINT; found : BOOLEAN;
BEGIN
	patternLength := Length(pattern); stringLength := Length(string);

	(* check whether the search pattern can be contained in the text regarding the search direction *)
	IF backwards THEN
		IF (patternLength > from + 1) THEN RETURN -1; END;
	ELSE
		IF (from + patternLength > stringLength) THEN RETURN -1; END;
	END;

	dM := 1; FOR i := 0 TO patternLength-2 DO dM := (d*dM) MOD q END;

	(* calculate hash value for search pattern string *)
	h1 := 0; FOR i := 0 TO patternLength-1 DO
		IF backwards THEN
			ch := pattern[patternLength-1-i];
		ELSE
			ch := pattern[i];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h1 := (h1*d + ORD(ch)) MOD q;
	END;

	(* calculate hash value for the first 'patternLength' characters of the text to be searched *)
	h2 := 0; FOR i := 0 TO patternLength-1 DO
		IF backwards THEN
			ch := string[from - i];
		ELSE
			ch := string[from + i];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2*d + ORD(ch)) MOD q;
	END;

	i := from; found := FALSE;

	IF (h1 = h2) THEN (* Hash values match, compare strings *)
		j := 0; found := TRUE;
		WHILE (j < patternLength) DO
			ch := string[from + j];
			chp := pattern[j];
			IF ignoreCase THEN UpperCaseChar(ch); UpperCaseChar(chp); END;
			IF (ch # chp) THEN found := FALSE; j := patternLength; END; (* hash values are equal, but strings are not *)
			INC(j);
		END;
	END;

	LOOP
		(* check wether we're finished *)
		IF found THEN EXIT; END;
		IF backwards THEN
			IF (i < patternLength) THEN EXIT; END;
		ELSE
			IF (i >= stringLength-patternLength) THEN EXIT; END;
		END;

		(* remove last character from hash value *)
		ch := string[i];
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2 + d*q - ORD(ch)*dM) MOD q;

		(* add next character to hash value *)
		IF backwards THEN
			ch := string[i-patternLength];
		ELSE
			ch := string[i+patternLength];
		END;
		IF ignoreCase THEN UpperCaseChar(ch); END;
		h2 := (h2*d + ORD(ch)) MOD q;

		IF backwards THEN DEC(i); ELSE INC(i); END;

		IF (h1 = h2) THEN (* verify *)
			j := 0; found := TRUE;
			WHILE (j < patternLength) DO
				IF backwards THEN
					ch := string[i - patternLength + 1 + j];
				ELSE
					ch := string[i + j];
				END;
				chp := pattern[j];
				IF ignoreCase THEN UpperCaseChar(ch); UpperCaseChar(chp); END;
				IF (ch # chp) THEN found := FALSE; j := patternLength; END; (* hash values are equal, but strings are not *)
				INC(j);
			END
		END;
	END;

	IF found THEN
		IF backwards THEN RETURN i - patternLength + 1;
		ELSE RETURN i;
		END;
	ELSE
		RETURN -1;
	END;
END GenericPos;

(** Simple pattern matching with support for "*" and "?" wildcards  - returns TRUE if name matches mask. Patent pending ;-) *)
PROCEDURE Match*(CONST mask, name: ARRAY OF CHAR): BOOLEAN;
VAR m,n, om, on: LONGINT; f: BOOLEAN;
BEGIN
	m := 0; n := 0; om := -1;
	f := TRUE;
	LOOP
		IF (mask[m] = "*") THEN
			om := m; INC(m);
			WHILE (name[n] # 0X) & (name[n] # mask[m]) DO INC(n) END;
			on := n
		ELSIF (mask[m] = "?") THEN
			IF (name[n] = 0X) THEN f := FALSE; EXIT END;
			INC(m); INC(n)
		ELSE
			IF (mask[m] # name[n]) THEN
				IF (om = -1) THEN f := FALSE; EXIT
				ELSIF (name[n] # 0X) THEN (* try the next position *)
					m := om; n := on + 1;
					IF (name[n] = 0X) THEN f := FALSE; EXIT END
				ELSE
					f := FALSE; EXIT
				END
			ELSE INC(m); INC(n)
			END
		END;
		IF (mask[m] = 0X) & ((name[n] = 0X) OR (om=-1)) THEN EXIT END
	END;
	RETURN f & (name[n] = 0X)
END Match;

(** copies src[soff ... soff + len - 1] to dst[doff ... doff + len - 1] *)
PROCEDURE Move* (CONST src: ARRAY OF CHAR; soff, len: LONGINT; VAR dst: ARRAY OF CHAR; doff: LONGINT);
BEGIN
	(* reverse copy direction in case src and dst denote the same string *)
	IF soff < doff THEN
		INC (soff, len - 1); INC (doff, len - 1);
		WHILE len > 0 DO dst[doff] := src[soff]; DEC (soff); DEC (doff); DEC (len) END
	ELSE
		WHILE len > 0 DO dst[doff] := src[soff]; INC (soff); INC (doff); DEC (len) END
	END;
END Move;

(** concatenates s1 and s2: s := s1 || s2 *)
PROCEDURE Concat* (CONST s1, s2: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
VAR len1, len2 : LONGINT;
BEGIN
	len1 := Length (s1); len2 := Length (s2);
	Move(s2, 0, len2, s, len1);
	Move (s1, 0, len1, s, 0);
	Truncate (s, len1 + len2);
END Concat;

(** concatenates s1 and s2: s := s1 || s2. The resulting string is truncated to the length of s if necessary *)
PROCEDURE ConcatX*(CONST s1, s2 : ARRAY OF CHAR; VAR s : ARRAY OF CHAR);
VAR len1, len2 : LONGINT;
BEGIN
	len1 := Length (s1); len2 := Length (s2);
	IF (len1 + 1 >= LEN(s)) THEN
		COPY(s1, s);
	ELSE
		IF (len1 + len2 + 1 > LEN(s)) THEN
			len2 := LEN(s) - 1 - len1;
		END;
		Move(s2, 0, len2, s, len1);
		Move (s1, 0, len1, s, 0);
		Truncate (s, len1 + len2);
	END;
END ConcatX;

(** appends appendix to s: s := s || appendix *)
PROCEDURE Append* (VAR s: ARRAY OF CHAR; CONST appendix: ARRAY OF CHAR);
BEGIN Concat (s, appendix, s)
END Append;


(** appends appendix to s: s := s || appendix. The resulting string is truncated to the length of s if necessary *)
PROCEDURE AppendX* (VAR s: ARRAY OF CHAR; CONST appendix: ARRAY OF CHAR);
BEGIN ConcatX (s, appendix, s)
END AppendX;

(** appends an integer number to a string *)
PROCEDURE AppendInt*(VAR s: ARRAY OF CHAR; num: LONGINT);
VAR number: ARRAY 16 OF CHAR;
BEGIN
	IntToStr(num,number); Append(s,number);
END AppendInt;


(** appends a character to a string s := s || char *)
PROCEDURE AppendChar*(VAR s: ARRAY OF CHAR; ch: CHAR);
VAR cs: ARRAY 2 OF CHAR;
BEGIN
	cs[0] := ch; cs[1] := 0X; Append(s,cs);
END AppendChar;


(** copies src[index ... index + len-1] to dst *)
PROCEDURE Copy* (CONST src: ARRAY OF CHAR; index, len: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	Move (src, index, len, dst, 0);
	Truncate (dst, len);
END Copy;

(** deletes positions index ... index + count - 1 from 's' *)
PROCEDURE Delete* (VAR s: ARRAY OF CHAR; index, count: LONGINT);
VAR len: LONGINT;
BEGIN
	len := Length (s);
	Move (s, index + count, len - index - count, s, index);
	Truncate (s, len - count);
END Delete;

(** inserts 'src' at position 'index' into 'dst' *)
PROCEDURE Insert* (CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR; index: LONGINT);
VAR slen, dlen: LONGINT;
BEGIN
	slen := Length (src); dlen := Length (dst);
	Move (dst, index, dlen-index, dst, index+slen);
	Move (src, 0, slen, dst, index);
	Truncate (dst, slen + dlen);
END Insert;

(** removes all occurrences of 'c' at the head of 'string' *)
PROCEDURE TrimLeft* (VAR string: ARRAY OF CHAR; c: CHAR);
VAR len, index: LONGINT;
BEGIN
	len := Length (string); index := 0;
	WHILE (index # len) & (string[index] = c) DO INC (index) END;
	Delete (string, 0, index);
END TrimLeft;

(** removes all occurrences of 'c' at the end of 'string' *)
PROCEDURE TrimRight* (VAR string: ARRAY OF CHAR; c: CHAR);
VAR len, index: LONGINT;
BEGIN
	len := Length (string); index := len;
	WHILE (index # 0) & (string[index - 1] = c) DO DEC (index) END;
	Delete (string, index, len - index);
END TrimRight;

(** removes all occurrences of 'c' at both ends of 'string' *)
PROCEDURE Trim* (VAR string: ARRAY OF CHAR; c: CHAR);
BEGIN
	TrimLeft(string, c);
	TrimRight(string, c)
END Trim;

(**
 * Splits 'string' into multiple strings separated by 'separator'.
 * Result properties:
 *	separator = 0X: 	LEN(StringArray) = 1
 *	separator # 0X: 	LEN(StringArray) = 1 + <Number of occurences of 'ch' in 'string'>
 *	StringArray[i] # NIL (0 <= i <= LEN(StringArray)-1)
 *)
PROCEDURE Split*(CONST string : ARRAY OF CHAR; separator : CHAR) : StringArray;
VAR count, index, pos, next: LONGINT; result : StringArray;
BEGIN
	count := Count (string, separator);
	NEW (result, count + 1); pos := 0;
	FOR index := 0 TO count DO
		next := Find (string, pos, separator);
		IF next = -1 THEN next := Length (string) END;
		NEW (result[index], next - pos + 1);
		Copy (string, pos, next - pos, result[index]^);
		pos := next + 1;
	END;
	RETURN result;
END Split;

PROCEDURE Join*(CONST strings : StringArray; startIndex, endIndex : LONGINT; separator : CHAR) : String;
VAR string : String; length, pos, i : LONGINT;
BEGIN
	ASSERT((strings # NIL) & (LEN(strings) >= 1));
	ASSERT((0 <= startIndex) & (startIndex <= endIndex) & (endIndex < LEN(strings)));
	length := 1; (* 0X termination *)
	IF (separator # 0X) THEN length := length + (endIndex - startIndex); END;
	FOR i := startIndex TO endIndex DO
		length := length + Length(strings[i]^);
	END;
	pos := 0;
	NEW(string, length);
	FOR i := startIndex TO endIndex DO
		length := Length(strings[i]^);
		Move(strings[i]^, 0, length, string^, pos);
		pos := pos + length;
		IF (i < endIndex) & (separator # 0X) THEN string[pos] := separator; INC(pos); END;
	END;
	string^[LEN(string)-1] := 0X;
	ASSERT((string # NIL) & (LEN(string) > 0) & (string^[LEN(string)-1] = 0X));
	RETURN string;
END Join;

(** returns the corresponding lower-case letter for "A" <= ch <= "Z" *)
PROCEDURE LOW*(ch: CHAR): CHAR;
BEGIN
	IF (ch >= "A") & (ch <= "Z") THEN RETURN CHR(ORD(ch) - ORD("A") + ORD("a"))
	ELSE RETURN ch
	END
END LOW;

(** converts s to lower-case letters *)
PROCEDURE LowerCase*(VAR s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (s[i] # 0X) DO
		s[i] := LOW(s[i]);
		INC(i)
	END
END LowerCase;

(** returns the corresponding upper-case letter for "a" <= ch <= "z" *)
PROCEDURE UP*(ch : CHAR) : CHAR;
BEGIN
	IF ("a" <= ch) & (ch <= "z") THEN ch := CAP(ch); END;
	RETURN ch;
END UP;

PROCEDURE UpperCaseChar*(VAR ch : CHAR);
BEGIN
	IF ("a" <= ch) & (ch <= "z") THEN ch := CAP(ch); END;
END UpperCaseChar;

(** converts s to upper-case letters *)
PROCEDURE UpperCase*(VAR s: ARRAY OF CHAR);
VAR i: LONGINT; c : CHAR;
BEGIN
	i := 0;
	WHILE (s[i] # 0X) DO
		c := s[i];
		IF ('a' <= c) & (c <= 'z') THEN s[i] := CAP(c) END;
		INC(i)
	END
END UpperCase;

(* ASCII printable characters *)
PROCEDURE IsPrintable*(ch:CHAR):BOOLEAN;
BEGIN
	RETURN (ch>=20X) & (ch<=7EX)
END IsPrintable;


(** conversion functions *)

(** converts a boolean value to a string *)
PROCEDURE BoolToStr*(b: BOOLEAN; VAR s: ARRAY OF CHAR);
CONST True = "True"; False = "False";
BEGIN
	IF b THEN COPY(True, s)
	ELSE COPY(False, s)
	END
END BoolToStr;

(** converts a string to a boolean value: b := CAP(s[0]) = "T" *)
PROCEDURE StrToBool*(CONST s: ARRAY OF CHAR; VAR b: BOOLEAN);
BEGIN b := CAP(s[0]) = "T"
END StrToBool;

(** converts an integer value to a string *)
PROCEDURE IntToStr*(i: LONGINT; VAR s: ARRAY OF CHAR);
VAR j,k: LONGINT; digits: ARRAY 10 OF LONGINT;
BEGIN
	IF (i = MIN(LONGINT)) THEN COPY("-2147483648", s)
	ELSE
		IF (i < 0) THEN i := -i; s[0] := "-"; j := 1
		ELSE j := 0
		END;

		k := 0; digits[k] := 0;
		WHILE (i > 0) DO
			digits[k] := i MOD 10; i := i DIV 10;
			INC(k)
		END;
		IF (k > 0) THEN DEC(k) END; (* no leading "0" *)

		WHILE (k >= 0) DO
			s[j] := CHR(digits[k] + ORD("0"));
			INC(j); DEC(k)
		END;
		s[j] := 0X
	END
END IntToStr;

(** converts a string to an integer. Leading whitespace is ignored *)
(* adopted from Strings.Mod *)
PROCEDURE StrToInt*(CONST str: ARRAY OF CHAR; VAR val: LONGINT);
VAR i, d: LONGINT; neg: BOOLEAN;
BEGIN
	i := 0; WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	neg := FALSE;
	IF (str[i] = "+") THEN INC(i)
	ELSIF (str[i] = "-") THEN neg := TRUE; INC(i)
	END;

	val := 0;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO
		d := ORD(str[i])-ORD("0");
		IF (val <= ((MAX(LONGINT)-d) DIV 10)) THEN val := 10*val+d
		ELSIF neg & (val = 214748364) & (d = 8) & ((str[i+1] < "0") OR (str[i+1] > "9")) THEN
			(* LONGINT range: -2147483648 ... 2147483647 _> need special handling for -2147483648 here *)
			val := MIN(LONGINT); neg := FALSE
		ELSE
			HALT(99)
		END;
		INC(i)
	END;
	IF neg THEN val := -val END
END StrToInt;

(** Convert the substring beginning at position i in str into an integer. Leading whitespace is ignored.
	After the conversion i points to the first character after the integer. *)
(* adopted from Strings.Mod *)
PROCEDURE StrToIntPos*(CONST str: ARRAY OF CHAR; VAR val, i: LONGINT);
VAR noStr: ARRAY 16 OF CHAR;
BEGIN
	WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END;
	val := 0;
	IF str[i] = "-" THEN
		noStr[val] := str[i]; INC(val); INC(i);
		WHILE (str[i] # 0X) & (str[i] <= " ") DO INC(i) END
	END;
	WHILE (str[i] >= "0") & (str[i] <= "9") DO noStr[val] := str[i]; INC(val); INC(i) END;
	noStr[val] := 0X;
	StrToInt(noStr, val)
END StrToIntPos;

(** converts an integer value to a hex string *)
PROCEDURE IntToHexStr*(h : HUGEINT; width: LONGINT; VAR s: ARRAY OF CHAR);
VAR c: CHAR;
BEGIN
	IF (width <= 0) THEN width := 8 END;

	DEC(width); (* opov *)
	s[width+1] := 0X;
	WHILE (width >= 0) DO
		c := CHR(h MOD 10H + ORD("0"));
		IF (c > "9") THEN c := CHR((h MOD 10H - 10) + ORD("A")) END;
		s[width] := c; h := h DIV 10H; DEC(width)
	END
END IntToHexStr;

(** converts a hex string to an integer. Leading whitespace is ignored. res=Ok indicates success, val=0 on failure. *)
PROCEDURE HexStrToInt*(CONST string: ARRAY OF CHAR; VAR val, res: LONGINT);
VAR length, i : LONGINT; ch: CHAR; negative : BOOLEAN;
BEGIN
	length := LEN(string); val := 0; res := -1;
	(* skip whitespace *)
	i := 0; WHILE (i < length) & (string[i] # 0X) & (string[i] <= " ") DO INC(i); END;
	IF (i < length) THEN
		IF (string[i] = "+") OR (string[i] = "-") THEN
			negative := (string[i] = "-"); INC(i);
		ELSE
			negative := FALSE;
		END;
		LOOP
			IF (i >= length) OR (string[i] = 0X) THEN EXIT; END;
			ch := string[i];
			IF (ch >= "0") & (ch <= "9") THEN val := 16 * val + ORD(ch) - ORD("0");
			ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "F") THEN val := 16 * val + ORD(CAP(ch)) - ORD("A") + 10;
			ELSE EXIT;
			END;
			INC(i);
		END;
		IF (i < length) & (string[i] = "H") THEN INC(i); END; (* skip optional "H" *)
		IF (i < length) & (string[i] = 0X) THEN
			IF negative THEN val := -val END;
			res := Ok;
		END;
	END;
END HexStrToInt;

(** converts a real value to a string *)
(* adopted from Strings.Mod *)
PROCEDURE FloatToStr*(x: LONGREAL; n, f, D: LONGINT; VAR str: ARRAY OF CHAR);
VAR pos, len, e, i, h, l: LONGINT; r, z: LONGREAL; d: ARRAY 16 OF CHAR; s: CHAR;

	PROCEDURE Wr(ch: CHAR);
	BEGIN IF pos < len THEN str[pos] := ch; INC(pos) END;
	END Wr;

BEGIN
	len := LEN(str)-1; pos := 0;
	e := Reals.ExpoL(x);
	IF (e = 2047) OR (ABS(D) > 308) THEN
		Wr("N"); Wr("a"); Wr("N")
	ELSE
		IF D = 0 THEN DEC(n, 2) ELSE DEC(n, 7) END;
		IF n < 2 THEN n := 2 END;
		IF f < 0 THEN f := 0 END;
		IF n < f + 2 THEN n := f + 2 END;
		DEC(n, f);
		IF (e # 0) & (x < 0) THEN s := "-"; x := - x ELSE s := " " END;
		IF e = 0 THEN
			h := 0; l := 0; DEC(e, D-1) (* no denormals *)
		ELSE
			e := (e - 1023) * 301029 DIV 1000000; (* ln(2)/ln(10) = 0.301029996 *)
			z := Reals.Ten(e+1);
			IF x >= z THEN x := x/z; INC(e) ELSE x:= x * Reals.Ten(-e) END;
			DEC(e, D-1); i := -(e+f);
			IF i <= 0 THEN r := 5 * Reals.Ten(i) ELSE r := 0 END;
			IF x >= 10 THEN
				x := x * Reals.Ten(-1) + r; INC(e)
			ELSE
				x := x + r;
				IF x >= 10 THEN x := x * Reals.Ten(-1); INC(e) END
			END;
			x := x * Reals.Ten(7); h:= ENTIER(x); x := (x-h) * Reals.Ten(8); l := ENTIER(x)
		END;
		i := 15;
		WHILE i > 7 DO d[i] := CHR(l MOD 10 + ORD("0")); l := l DIV 10; DEC(i) END;
		WHILE i >= 0 DO d[i] := CHR(h MOD 10 + ORD("0")); h := h DIV 10; DEC(i) END;
		IF n <= e THEN n := e + 1 END;
		IF e > 0 THEN
			WHILE n > e DO Wr(" "); DEC(n) END;
			Wr(s); e:= 0;
			WHILE n > 0 DO
				DEC(n);
				IF e < 16 THEN Wr(d[e]); INC(e) ELSE Wr("0") END
			END;
			Wr(".")
		ELSE
			WHILE n > 1 DO Wr(" "); DEC(n) END;
			Wr(s); Wr("0"); Wr(".");
			WHILE (0 < f) & (e < 0) DO Wr("0"); DEC(f); INC(e) END
		END;
		WHILE f > 0 DO
			DEC(f);
			IF e < 16 THEN Wr(d[e]); INC(e) ELSE Wr("0") END
		END;
		IF D # 0 THEN
			IF D < 0 THEN Wr("D"); Wr("-"); D := - D
			ELSE Wr("D"); Wr("+")
			END;
			Wr(CHR(D DIV 100 + ORD("0"))); D := D MOD 100;
			Wr(CHR(D DIV 10 + ORD("0"))); Wr(CHR(D MOD 10 + ORD("0")))
		END
	END;
	str[pos] := 0X
END FloatToStr;

PROCEDURE AddressToStr*(adr : ADDRESS; VAR str : ARRAY OF CHAR);
BEGIN
	IntToHexStr(adr, 2*SIZEOF(ADDRESS), str);
END AddressToStr;

(** converts a string to a real value *)
(* adopted from Strings.Mod *)
PROCEDURE StrToFloat*(CONST s: ARRAY OF CHAR; VAR r: LONGREAL);
VAR p, e: INTEGER; y, g: LONGREAL; neg, negE: BOOLEAN;
BEGIN
	p := 0;
	WHILE (s[p] = " ") OR (s[p] = "0") DO INC(p) END;
	IF s[p] = "-" THEN neg := TRUE; INC(p) ELSE neg := FALSE END;
	WHILE (s[p] = " ") OR (s[p] = "0") DO INC(p) END;

	y := 0;
	WHILE ("0" <= s[p]) & (s[p] <= "9") DO
		y := y * 10 + (ORD(s[p]) - 30H);
		INC(p);
	END;
	IF s[p] = "." THEN
		INC(p); g := 1;
		WHILE ("0" <= s[p]) & (s[p] <= "9") DO
			g := g / 10; y := y + g * (ORD(s[p]) - 30H);
			INC(p);
		END;
	END;
	IF (s[p] = "d") OR (s[p] = "D") OR (s[p] = "e") OR (s[p] = "E") THEN
		INC(p); e := 0;
		IF s[p] = "-" THEN negE := TRUE; INC(p)
		ELSIF s[p] = "+" THEN negE := FALSE; INC(p)
		ELSE negE := FALSE
		END;
		WHILE (s[p] = "0") DO INC(p) END;
		WHILE ("0" <= s[p]) & (s[p] <= "9") DO
			e := e * 10 + (ORD(s[p]) - 30H);
			INC(p);
		END;
		IF negE THEN y := y / Reals.Ten(e)
		ELSE y := y * Reals.Ten(e) END;
	END;
	IF neg THEN y := -y END;
	r := y
END StrToFloat;

(** converts a set to a string *)
(* adopted from Strings.Mod *)
PROCEDURE SetToStr*(set: SET; VAR s: ARRAY OF CHAR);
VAR i, j, k: INTEGER; noFirst: BOOLEAN;
BEGIN
	s[0] := "{"; i := 0; k := 1; noFirst := FALSE;
	WHILE i <= MAX(SET) DO
		IF i IN set THEN
			IF noFirst THEN s[k] := ","; INC(k) ELSE noFirst := TRUE END;
			IF i >= 10 THEN s[k] := CHR(i DIV 10 + 30H); INC(k) END;
			s[k] := CHR(i MOD 10 + 30H); INC(k);
			j := i; INC(i);
			WHILE (i <= MAX(SET)) & (i IN set) DO INC(i) END;
			IF i-2 > j THEN
				s[k] := "."; s[k+1] := "."; INC(k, 2); j := i - 1;
				IF j >= 10 THEN s[k] := CHR(j DIV 10 + 30H); INC(k) END;
				s[k] := CHR(j MOD 10 + 30H); INC(k)
			ELSE i := j
			END
		END;
		INC(i)
	END;
	s[k] := "}"; s[k+1] := 0X
END SetToStr;

(** converts a string to a set *)
(* adopted from Strings.Mod *)
PROCEDURE StrToSet*(CONST str: ARRAY OF CHAR; VAR set: SET);
VAR i, d, d1: INTEGER; dot: BOOLEAN;
BEGIN
	set := {}; dot := FALSE;
	i := 0;
	WHILE (str[i] # 0X) & (str[i] # "}") DO
		WHILE (str[i] # 0X) & ((str[i] < "0") OR ("9" < str[i])) DO INC(i) END;
		d := 0; WHILE ("0" <= str[i]) & (str[i] <= "9") DO d := d*10 + ORD(str[i]) - 30H; INC(i) END;
		IF (str[i] = 0X) THEN RETURN; END;
		IF d <= MAX(SET) THEN INCL(set, d) END;
		IF dot THEN
			WHILE (d1 <= MAX(SET)) & (d1 < d) DO INCL(set, d1); INC(d1) END;
			dot := FALSE
		END;
		WHILE (str[i] = " ") DO INC(i) END;
		IF (str[i] = ".") THEN d1 := d + 1; dot := TRUE END
	END
END StrToSet;

(** converts a time to a string, using the 'TimeFormat' format. C.f. FormatDateTime *)
PROCEDURE TimeToStr*(time: Dates.DateTime; VAR s: ARRAY OF CHAR);
BEGIN FormatDateTime(TimeFormat, time, s)
END TimeToStr;

(** converts a string to a time *)
(* adopted from Strings.Mod *)
PROCEDURE StrToTime*(CONST str: ARRAY OF CHAR; VAR dt: Dates.DateTime);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.hour, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.minute, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.second, i);
	ASSERT(Dates.ValidDateTime(dt));
END StrToTime;

(** converts a date to a string, using the 'DateFormat' format. C.f. FormatDateTime *)
PROCEDURE DateToStr*(date: Dates.DateTime; VAR s: ARRAY OF CHAR);
BEGIN FormatDateTime(DateFormat, date, s)
END DateToStr;

(** Convert a string of the form 'day month year' into an date value. Leading whitespace is ignored. *)
PROCEDURE StrToDate*(CONST str: ARRAY OF CHAR; VAR dt: Dates.DateTime);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.day, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.month, i);
	WHILE (str[i] # 0X) & ((str[i] < "0") OR (str[i] > "9")) DO INC(i) END;
	StrToIntPos(str, dt.year, i);
	ASSERT(Dates.ValidDateTime(dt));
END StrToDate;

(** converts a TDateTime into a string.
	Format rules:
	yyyy	->	four-digit year, e.g. 2001
	yy		->	two-digit year, e.g. 01
	mmmm ->	clear-text month, e.g. May
	mmm  ->  clear-text month, abbreviated, e.g. Sep
	mm	->	two-digit month, e.g. 05
	m		->	month, e.g. 5
	dd		->	two-digit day, e.g. 02
	d		->	day, e.g. 2 or 15
	wwww	-> clear-text week-day, e.g. Monday
	www	->  clear-text week-day, e.g. Mon

	hh		->	two-digit hour, e.g. 08
	h		-> 	hour, e.g. 8
	nn		-> two-digit minute, e.g. 03
	n		-> minute, e.g. 3
	ss		-> two-digit second, e.g. 00
	s		-> second, e.g. 0
	any other characters will be copied 1:1 to the result string

	Examples:
	"yyyy.mm.dd hh:nn:ss"	-> "2002.01.01 17:08:00"
	"yyyyyy.m.ddd"				-> "002002.1.001"
	"wwww, mmmm d, yyyy"			-> "Tuesday, September 11, 2001"
*)
PROCEDURE FormatDateTime*(CONST format: ARRAY OF CHAR; dt: Dates.DateTime; VAR result: ARRAY OF CHAR);
VAR i,k,l,len,n,m,y,w,dw: LONGINT;

	PROCEDURE IntToStr(v, len: LONGINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
	VAR i: LONGINT;
	BEGIN
		FOR i := 1 TO len DO s[pos+len-i] := CHR(ORD("0") + v MOD 10); v := v DIV 10 END;
		INC(pos, len)
	END IntToStr;

BEGIN
	k := 0;
	IF Dates.ValidDateTime(dt) THEN
		i := 0;
		WHILE (format[i] # 0X) DO
			n := 1; WHILE (format[i+n] = format[i]) DO INC(n) END;
			len := n;
			CASE format[i] OF
			|"w": Dates.WeekDate(dt, y, w, dw); DEC(dw);
					IF (len >= 4) THEN len := 10 END;
					l := 0; WHILE (l < len) & (Dates.Days[dw,l] # 0X) DO result[k] := Dates.Days[dw,l]; INC(k); INC(l) END;
			|"y": IntToStr(dt.year, n, result, k);
			|"m": IF (n >= 3) THEN
						m := dt.month-1; ASSERT((m>=0) & (m<12));
						IF (len > 3) THEN len := 12 END;
						l := 0; WHILE (l < len) & (Dates.Months[m,l] # 0X) DO result[k] := Dates.Months[m, l]; INC(k); INC(l) END
					ELSE
						IF (len=1) & (dt.month > 9) THEN len := 2; END;
						IntToStr(dt.month, len, result, k)
					END;
			|"d": IF (len=1) & (dt.day > 9) THEN len := 2 END;
					IntToStr(dt.day, len, result, k);
			|"h": IF (len=1) & (dt.hour > 9) THEN len := 2 END;
					IntToStr(dt.hour, len, result, k);
			|"n": IF (len=1) & (dt.minute > 9) THEN len := 2 END;
					IntToStr(dt.minute, len, result, k);
			|"s": IF (len=1) & (dt.second > 9) THEN len := 2 END;
					IntToStr(dt.second, len, result, k);
			ELSE result[k] := format[i]; INC(k); n := 1
			END;
			INC(i, n)
		END
	END;
	result[k] := 0X
END FormatDateTime;

PROCEDURE ShowTimeDifference*(t1, t2 : Dates.DateTime; out : Streams.Writer);
VAR days, hours, minutes, seconds : LONGINT; show : BOOLEAN;
BEGIN
	Dates.TimeDifference(t1, t2, days, hours, minutes, seconds);
	show := FALSE;
	IF (days > 0) THEN out.Int(days, 0); out.String("d "); show := TRUE; END;
	IF show OR (hours > 0) THEN out.Int(hours, 0); out.String("h "); show := TRUE;  END;
	IF show OR (minutes > 0) THEN out.Int(minutes, 0); out.String("m "); show := TRUE; END;
	out.Int(seconds, 0); out.String("s");
END ShowTimeDifference;

PROCEDURE NewString*(CONST str : ARRAY OF CHAR) : String;
VAR l : LONGINT; s : String;
BEGIN
	l := Length(str) + 1;
	NEW(s, l);
	COPY(str, s^);
	RETURN s
END NewString;

PROCEDURE SetAOC*(CONST str: ARRAY OF CHAR; VAR s: String);
VAR l: LONGINT;
BEGIN
	l := Length(str) + 1;
	IF (s = NIL) OR (LEN(s^) < l) THEN
		NEW(s,l)
	END;
	COPY(str, s^);
END SetAOC;


(* Gets extension of the given name, returns file (without extension) and ext *)
PROCEDURE GetExtension* (CONST name : ARRAY OF CHAR; VAR file, ext: ARRAY OF CHAR);
VAR len, index: LONGINT;
BEGIN
	len := Length (name); index := len;
	WHILE (index # 0) & (name[index- 1] # '.') DO DEC (index) END;
	IF index = 0 THEN
		Copy (name, 0, len, file);
		Truncate (ext, 0);
	ELSE
		Copy (name, 0, index - 1, file);
		Copy (name, index, len - index, ext);
	END
END GetExtension;

(* Returns a new string that is a concatenation of s1 and s2: s := s1 || s2 *)
PROCEDURE ConcatToNew*(CONST s1, s2 : ARRAY OF CHAR) : String;
VAR
	s : String;
BEGIN
	NEW(s, Length(s1) + Length(s2) + 1);
	Concat(s1, s2, s^);
	RETURN s;
END ConcatToNew;

(* Tests if string s ends with the specified suffix *)
PROCEDURE EndsWith*(CONST suffix, s : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN StartsWith(suffix, Length(s)-Length(suffix), s);
END EndsWith;

(* Tests if two strings are equal *)
(* This procedure makes sense, because "proc(..)^ = proc(..)^" is not supported by the compiler! *)
PROCEDURE Equal*(s1, s2 : String) : BOOLEAN;
BEGIN
	ASSERT(s1 # NIL);
	ASSERT(s2 # NIL);
	RETURN s1^ = s2^;
END Equal;

(** Returns TRUE if the 0X-terminated string contains the character 'ch', FALSE otherwise. *)
PROCEDURE ContainsChar*(CONST string : ARRAY OF CHAR; ch : CHAR; ignoreCase : BOOLEAN) : BOOLEAN;
BEGIN
	IF ignoreCase THEN
		RETURN (Find (string, 0, LOW (ch)) # -1) & (Find (string, 0, UP (ch)) # -1)
	ELSE
		RETURN Find (string, 0, ch) # -1
	END
END ContainsChar;

(* Returns the index within string s of the first occurrence of the specified character *)
PROCEDURE IndexOfByte2*(ch : CHAR; CONST s : ARRAY OF CHAR) : LONGINT;
BEGIN
	RETURN IndexOfByte(ch, 0, s);
END IndexOfByte2;

(* Returns the index within string s of the first occurrence of the specified character, starting the search at the specified index *)
PROCEDURE IndexOfByte*(ch : CHAR; fromIndex : LONGINT; CONST s : ARRAY OF CHAR) : LONGINT;
VAR
	lenString, i : LONGINT;
BEGIN
	lenString := Length(s);
	IF fromIndex < 0 THEN
		fromIndex := 0;
	ELSIF fromIndex >= lenString THEN
		RETURN -1;
	END;
	FOR i := fromIndex TO lenString-1 DO
		IF s[i] = ch THEN RETURN i; END;
	END;
	RETURN -1;
END IndexOfByte;

(* Returns the index within string s of the last occurrence of the specified character *)
PROCEDURE LastIndexOfByte2*(ch : CHAR; CONST s : ARRAY OF CHAR) : LONGINT;
BEGIN
	RETURN LastIndexOfByte(ch, Length(s)-1, s);
END LastIndexOfByte2;

(* Returns the index within string s of the last occurrence of the specified character, searching backward starting at the specified index *)
PROCEDURE LastIndexOfByte*(ch : CHAR; fromIndex : LONGINT; CONST s : ARRAY OF CHAR) : LONGINT;
VAR
	lenString, i : LONGINT;
BEGIN
	lenString := Length(s);
	IF fromIndex >= lenString THEN
		fromIndex := lenString - 1;
	END;
	FOR i := fromIndex TO 0 BY -1 DO
		IF s[i] = ch THEN RETURN i; END;
	END;
	RETURN -1;
END LastIndexOfByte;

(* Returns a new string that is a copy of s in lower-case letters *)
PROCEDURE LowerCaseInNew*(CONST s : ARRAY OF CHAR) : String;
VAR
	n : String;
BEGIN
	n := NewString(s);
	LowerCase(n^);
	RETURN n;
END LowerCaseInNew;

(* Tests if string s starts with the specified prefix *)
PROCEDURE StartsWith2*(CONST prefix, s : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN StartsWith(prefix, 0, s);
END StartsWith2;

(* Tests if string s starts with the specified prefix beginning a specified index *)
PROCEDURE StartsWith*(CONST prefix : ARRAY OF CHAR; toffset : LONGINT; CONST s : ARRAY OF CHAR) : BOOLEAN;
VAR
	lenString, lenPrefix, i : LONGINT;
BEGIN
	lenString := Length(s);
	lenPrefix := Length(prefix);
	IF (toffset < 0) OR (toffset > lenString - lenPrefix) THEN
		RETURN FALSE;
	END;
	FOR i := 0 TO lenPrefix-1 DO
		IF prefix[i] # s[toffset + i] THEN RETURN FALSE; END;
	END;
	RETURN TRUE;
END StartsWith;

(* Returns a new string that is a substring of string s *)
PROCEDURE Substring2*(beginIndex : LONGINT; CONST s : ARRAY OF CHAR) : String;
BEGIN
	RETURN Substring(beginIndex, Length(s), s);
END Substring2;

(* Returns a new string that is a substring of string s *)
(* s[endIndex-1] is the last character of the new string *)
PROCEDURE Substring*(beginIndex : LONGINT; endIndex : LONGINT; CONST s : ARRAY OF CHAR) : String;
VAR
	lenString, lenNewString : LONGINT;
	st : String;
BEGIN
	ASSERT(beginIndex >= 0);
	lenString := Length(s);
	ASSERT(endIndex <= lenString);
	lenNewString := endIndex - beginIndex;
	ASSERT(lenNewString >= 0);
	NEW(st, lenNewString + 1);
	Copy(s, beginIndex, lenNewString, st^);
	RETURN st;
END Substring;

(* Omitts leading and trailing whitespace of string s *)
PROCEDURE TrimWS*(VAR s : ARRAY OF CHAR);
VAR
	len, start, i : LONGINT;
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

(* Returns a new string that is a copy of s in upper-case letters *)
PROCEDURE UpperCaseInNew*(CONST s : ARRAY OF CHAR) : String;
VAR n : String;
BEGIN
	n := NewString(s);
	UpperCase(n^);
	RETURN n;
END UpperCaseInNew;

BEGIN
	DateFormat := "dd.mmm.yyyy";
	TimeFormat := "hh:nn:ss"
END Strings.

System.Free Utilities ~

