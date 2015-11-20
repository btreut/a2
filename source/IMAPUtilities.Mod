MODULE IMAPUtilities; (** AUTHOR "retmeier"; PURPOSE "some useful procedures for the IMAP client"; *)

(*! to do: IMAPUtilities.getRFC822Date seems one weekday off, on thursday it says: Fri, 28 May 2015 21:15:04 +0100*)

IMPORT
	Dates, Strings, Classes := TFClasses, Streams, KernelLog, UTF8Strings, Texts, TextUtilities, WMEditors;

CONST
	CR = 0DX; LF = 0AX; SP = 32;

VAR
	base64Table: ARRAY 128 OF LONGINT;
	index: LONGINT;

TYPE

	String = Strings.String;

	Address* = POINTER TO RECORD (** according to RFC 2060 *)
		realName*: String;
		namePart*: String; (** in front of @ *)
		domainPart*: String (** behind @: namePart@domainPart *)
	END;

PROCEDURE ParseAddresses*(string: String; VAR addresses: Classes.List);
VAR
	address: Address;
	r: Streams.StringReader;
	w: Streams.Writer;
	buffer: Strings.Buffer;
	s: String;
	c: CHAR;
	i, j: LONGINT;
BEGIN
	NEW(addresses);
	NEW(buffer, 16);
	w := buffer.GetWriter();
	NEW(r, Strings.Length(string^));
	r.Set(string^);
	r.SkipWhitespace();
	r.Char(c);
	WHILE(c # 0X) DO
		NEW(address);
		WHILE (c # ",") & (c # 0X) DO
			w.Char(c);
			r.Char(c);
		END;
		s := buffer.GetString();
		i := 0;
		WHILE (s^[i] # 0X) & (s^[i] # "@") & (s^[i] # "<") DO
			INC(i);
		END;
		IF s^[i] = 0X THEN
			KernelLog.String("Address Format invalid"); KernelLog.Ln();
			RETURN;
		END;

		NEW(address);
		IF s^[i] = "@" THEN
			address.realName := Strings.NewString("");
			NEW(address.namePart, i+1);
			Strings.Copy(s^, 0, i, address.namePart^);
			j := Strings.Length(s^) - i;
			NEW(address.domainPart, j);
			Strings.Copy(s^, i+1, j-1, address.domainPart^);
		ELSE (* s^[i] = "<" *)
			NEW(address.realName, i+1);
			Strings.Copy(s^, 0, i, address.realName^);
			Strings.Trim(address.realName^, " ");
			j := i;
			WHILE (s^[j] # 0X) & (s^[j] # "@") DO
				INC(j);
			END;
			IF s^[j] = 0X THEN
				KernelLog.String("Address Format invalid"); KernelLog.Ln();
				RETURN;
			END;
			NEW(address.namePart, j-i);
			Strings.Copy(s^, i+1, j-i-1, address.namePart^);
			i := j;
			WHILE(s^[i] # 0X) & (s^[i] # ">") DO
				INC(i);
			END;
			IF s^[i] = 0X THEN
				KernelLog.String("Address Format invalid"); KernelLog.Ln();
				RETURN;
			END;
			NEW(address.domainPart, i-j);
			Strings.Copy(s^, j + 1, i - j - 1, address.domainPart^);
		END;
		addresses.Add(address);
		buffer.Clear();
		r.SkipWhitespace();
		r.Char(c);
	END;
END ParseAddresses;

PROCEDURE AddressesToString*(list: Classes.List; VAR string: String);
VAR
	address: Address;
	p: ANY;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	i: LONGINT;
	s: String;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	i := 0;
	WHILE i < list.GetCount() DO
		p := list.GetItem(i);
		address := p(Address);
		AddressToString(address, s);
		w.String(s^);
		w.String(", ");
		INC(i);
	END;
	string := buffer.GetString();
	Strings.Trim(string^, " ");
	Strings.TrimRight(string^, ",");
END AddressesToString;

PROCEDURE AddressToString*(address: Address; VAR string: String);
VAR
	buffer: Strings.Buffer;
	w: Streams.Writer;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();

	IF (address.realName # NIL) & (StringLength(address.realName^) > 0) THEN
		w.String(address.realName^);
		w.String(" <");
	END;
	w.String(address.namePart^);
	w.String("@");
	w.String(address.domainPart^);
	IF (address.realName # NIL) & (StringLength(address.realName^) > 0) THEN
		w.String(">");
	END;
	string := buffer.GetString();
END AddressToString;

(* Strings that are longer then a certain limit must be passed as VAR-parameters so Strings.Length cannot be used. *)
PROCEDURE StringLength*(VAR string: ARRAY OF CHAR): LONGINT;
VAR len: LONGINT;
BEGIN
	len := 0; WHILE (string[len] # 0X) DO INC(len) END;
	RETURN len
END StringLength;

(* Strings that are longer then a certain limit must be passed as VAR-parameters so Strings.Copy cannot be used. *)
PROCEDURE StringCopy*(VAR s: ARRAY OF CHAR; index, count: LONGINT; VAR result: ARRAY OF CHAR);
VAR i, l: LONGINT;
BEGIN
	i := 0; l := LEN(result)-1;
	WHILE (i < count) & (i < l) DO
		result[i] := s[index+i];
		INC(i)
	END;
	result[i] := 0X
END StringCopy;

(* Returns TRUE if string contains subString as a sub-String *)
PROCEDURE StringContains*(string, subString: String): BOOLEAN;
VAR
	pos: LONGINT;
BEGIN
	FOR pos := 0 TO StringLength(string^) - 1 BY 1 DO
		IF StringStartsWith(subString^, pos, string^) THEN
			RETURN TRUE;
		END;
	END;
	RETURN FALSE;
END StringContains;

(* Tests if string s starts with the specified prefix beginning a specified index *)
PROCEDURE StringStartsWith*(VAR prefix : ARRAY OF CHAR; toffset : LONGINT; VAR s : ARRAY OF CHAR) : BOOLEAN;
VAR
	lenString, lenPrefix, i : LONGINT;
BEGIN
	lenString := StringLength(s);
	lenPrefix := StringLength(prefix);
	IF (toffset < 0) OR (toffset > lenString - lenPrefix) THEN
		RETURN FALSE;
	END;
	FOR i := 0 TO lenPrefix-1 DO
		IF prefix[i] # s[toffset + i] THEN RETURN FALSE; END;
	END;
	RETURN TRUE;
END StringStartsWith;

(* Strings.Uppercase doesn't work for me... *)
PROCEDURE UpperCase*(VAR s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (s[i] # 0X) DO
		IF (s[i] > "9") OR (s[i]  < "0") THEN
			s[i] := CAP(s[i]);
		END;
		INC(i)
	END
END UpperCase;

(* Strings that are longer then a certain limit must be passed as VAR-parameters so TextUtilities.StrToInt cannot be used. *)
PROCEDURE StrToText*(text : Texts.Text; pos : LONGINT; VAR string : ARRAY OF CHAR);
VAR r : Streams.StringReader;
	i, m: LONGINT;
	tempUCS32 : ARRAY 1024 OF Texts.Char32;
	ch, last : Texts.Char32;
BEGIN
	text.AcquireWrite;
	NEW(r, LEN(string));
	m := LEN(tempUCS32) - 1;
	r.SetRaw(string, 0, LEN(string));
	i := 0;
	REPEAT
		IF TextUtilities.GetUTF8Char(r, ch) THEN
			IF i = m THEN tempUCS32[i] := 0; text.InsertUCS32(pos, tempUCS32); INC(pos, m); i := 0 END;
			IF (last # ORD(0DX)) OR (ch # ORD(0AX)) THEN
				IF ch = ORD(0DX) THEN tempUCS32[i] := ORD(0AX)
				ELSE tempUCS32[i] := ch
				END;
				INC(i)
			END;
			last := ch
		END
	UNTIL (r.res # Streams.Ok);
	tempUCS32[i] := 0; text.InsertUCS32(pos, tempUCS32);
	text.ReleaseWrite
END StrToText;

(** Text to UTF8 string. Objects and attributes are lost. *)
PROCEDURE TextToStr*(text : Texts.Text; VAR string :String);
VAR
	i, l, pos : LONGINT;
	r : Texts.TextReader;
	ch : Texts.Char32;
	ok : BOOLEAN;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	s: ARRAY 7 OF CHAR;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	text.AcquireRead;
	NEW(r, text);
	i := 0; l := text.GetLength(); pos := 0; ok := TRUE;
	WHILE (i < l) & ok DO
		r.ReadCh(ch);
		IF (ch > 0) THEN
			pos := 0;
			ok := UTF8Strings.EncodeChar(ch, s, pos);
			w.String(s);
		END;
		INC(i)
	END;
	text.ReleaseRead;
	string := buffer.GetString();
END TextToStr;

PROCEDURE SetEditorText*(editor: WMEditors.Editor; string: String);
VAR
	text: Texts.Text;
	newString: String;
BEGIN
	NEW(text);
	newString := NewString(string^);
	StrToText(text, 0, newString^);
	editor.SetText(text);
END SetEditorText;

(* Strings that are longer then a certain limit must be passed as VAR-parameters so Strings.NewString cannot be used. *)
PROCEDURE NewString*(VAR str : ARRAY OF CHAR) : String;
VAR l : LONGINT; s : String;
BEGIN
	l := StringLength(str) + 1;
	NEW(s, l);
	COPY(str, s^);
	RETURN s
END NewString;

PROCEDURE MakeQuotedString*(VAR s: Strings.String);
VAR
	i, count, len: LONGINT;
	new: Strings.String;
BEGIN
	(* count the number of the characters " and \ because we want to send a quoted string *)
	i := 0;
	count := 0;
	len := StringLength(s^);
	WHILE i < len DO
		IF s^[i] = 22X THEN INC(count); END;
		IF s^[i] = "\" THEN INC(count); END;
		INC(i);
	END;
	NEW(new, len + 3 + count);
	new[0] := 22X;
	i := 0;
	count := 0;
	WHILE i < len DO
		IF s^[i] = 22X THEN
			new[i + count + 1] := "\";
			new[i + count + 2] := 22X;
			INC(count);
		ELSIF s^[i] = "\" THEN
			new[i + count + 1] := "\";
			new[i + count + 2] := "\";
			INC(count);
		ELSE
			new[i + count + 1] := s^[i];
		END;
		INC(i);
	END;
	new[i + count + 1] := 22X;
	new[i + count + 2] := 0X;
	s := new;
END MakeQuotedString;

(* transforms the string s which is in Base64 Transfer-Encoding to its normal representation *)
PROCEDURE decodeBase64*(VAR s: ARRAY OF CHAR): String;
VAR
	buf: Strings.Buffer;
	string: String;
	w: Streams.Writer;
	i: LONGINT;
	sum, value, factor: LONGINT;
BEGIN
	NEW(buf, 16);
	w := buf.GetWriter();
	i := 0;
	sum := 0;
	factor := 64*64*64;
	WHILE i < StringLength(s) DO

		IF base64Table[ORD(s[i])] = -1 THEN
			INC(i);
		ELSIF base64Table[ORD(s[i])] = 64 THEN
			(* finish *)
			IF factor =  64 THEN
				(* decode 1 CHAR *)
				value := sum DIV (256*256);
				w.Char(CHR(value));
			ELSE
				(* decode 2 CHARs *)
				value := sum DIV (256*256);
				w.Char(CHR(value));
				sum := sum MOD (256*256);

				value := sum DIV 256;
				w.Char(CHR(value));
			END;
			i := StringLength(s);
		ELSE
			sum := sum + factor*base64Table[ORD(s[i])];
			IF factor = 1 THEN
				value := sum DIV (256*256);

				w.Char(CHR(value));
				sum := sum MOD (256*256);
				value := sum DIV 256;

				w.Char(CHR(value));
				sum := sum MOD 256;

				w.Char(CHR(sum));

				sum := 0;
				factor := 64*64*64;
			ELSE
				factor := factor DIV 64;
			END;
			INC(i);
		END;
	END;
	string := buf.GetString();
	RETURN string;
END decodeBase64;

(* transforms the string s which is in QuotedPrintable Transfer-Encoding to its normal representation *)
PROCEDURE decodeQuotedPrintable*(VAR s: ARRAY OF CHAR): String;
VAR
	buf: Strings.Buffer;
	string: String;
	w: Streams.Writer;
	i: LONGINT;
	value: LONGINT;
BEGIN
	NEW(buf, 16);
	w := buf.GetWriter();
	i := 0;
	WHILE i < StringLength(s) DO
		IF ORD(s[i]) = 61 THEN
			IF (s[i+1] = 0DX) & (s[i+2] = 0AX) THEN
			ELSE
				IF (s[i+1] >= "0") & (s[i+1] <= "9") THEN
					value := 16 * (ORD(s[i+1]) - ORD("0"));
				ELSIF (s[i+1] >= "A") & (s[i+1] <= "F") THEN
					value := 16 * (ORD(s[i+1]) - ORD("A") + 10);
				END;

				IF (s[i+2] >= "0") & (s[i+2] <= "9") THEN
					value := value + (ORD(s[i+2]) - ORD("0"));
				ELSIF (s[i+2] >= "A") & (s[i+2] <= "F") THEN
					value := value + (ORD(s[i+2]) - ORD("A") + 10);
				END;
				w.Char(CHR(value));
			END;
			i := i + 3;
		ELSE
			w.Char(s[i]);
			INC(i);
		END;
	END;
	string := buf.GetString();
	RETURN string;
END decodeQuotedPrintable;

PROCEDURE encodeQuotedPrintable*(VAR string: String);
VAR
	i, count, value: LONGINT;
	c: CHAR;
	chars: ARRAY 17 OF CHAR;
	buf: Strings.Buffer;
	w: Streams.Writer;
BEGIN
	Strings.Copy("0123456789ABCDEF", 0, 16, chars);
	NEW(buf, 16);
	w := buf.GetWriter();

	i := 0;
	count := 0;
	c := string^[i];
	WHILE c # 0X DO
		IF (ORD(c) < 33) OR (ORD(c) = 61) OR (ORD(c) > 127) THEN
			w.Char("=");
			value := ORD(c) DIV 16;
			w.Char(chars[value]);
			value := ORD(c) MOD 16;
			w.Char(chars[value]);
			count := count + 3;
		ELSE
			w.Char(c);
			INC(count);
		END;

		IF count > 72 THEN
			w.Char("=");
			w.Char(CR);
			w.Char(LF);
			count := 0;
		END;

		INC(i);
		c := string^[i];
	END;
	string := buf.GetString();
END encodeQuotedPrintable;

PROCEDURE encodeXML*(VAR s: ARRAY OF CHAR): String;
VAR
	temp: String;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	i: LONGINT;
	c: CHAR;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	i := 0;
	WHILE i < StringLength(s) DO
		c := s[i];
		IF c = "&" THEN
			w.String("&amp;");
		ELSIF c = "<" THEN
			w.String("&lt;");
		ELSIF c = ">" THEN
			w.String("&gt;");
		ELSIF c = "'" THEN
			w.String("&apos;");
		ELSIF c = '"' THEN
			w.String("&quot");
		ELSE
			w.Char(c);
		END;
		INC(i);
	END;
	temp := buffer.GetString();
	RETURN temp;
END encodeXML;

PROCEDURE replaceEncodedHeaderWord*(VAR buf: ARRAY OF CHAR);
VAR
	i, j, k: LONGINT;
	buffer, res: Strings.Buffer;
	writer, resWriter: Streams.Writer;
	charset, text, string: String;
	encoding: CHAR;
BEGIN
	NEW(buffer,16);
	NEW(res, 16);
	writer := buffer.GetWriter();
	resWriter := res.GetWriter();
	i := 0;
	WHILE i < (StringLength(buf)) DO
		IF (buf[i] = "=") & (buf[i+1] = "?") THEN
			i := i + 2;
			(* read charset *)
			WHILE (buf[i] # "?") & (i < StringLength(buf)) DO
				writer.Char(buf[i]);
				INC(i);
			END;
			IF buf[i] # "?" THEN
				RETURN;
			END;

			charset := buffer.GetString();
			Strings.UpperCase(charset^);
			charset := Strings.NewString(charset^);
			buffer.Clear();

			INC(i);
			encoding := buf[i];
			INC(i);

			IF buf[i] # "?" THEN
				RETURN;
			END;
			INC(i);
			WHILE (buf[i] # "?") & (i < StringLength(buf)) DO
				writer.Char(buf[i]);
				INC(i);
			END;
			text := buffer.GetString();
			text := Strings.NewString(text^);
			buffer.Clear();

			IF buf[i] # "?" THEN RETURN END;
			INC(i);
			IF buf[i] # "=" THEN RETURN END;
			INC(i);

			IF (encoding = "Q") OR (encoding = "q") THEN
				(* replace "-" by SPACE *)
				k := 0;
				WHILE k < StringLength(text^) DO
					IF (text^[k]) = "_" THEN text^[k] := CHR(SP); END;
					INC(k);
				END;
				string := decodeQuotedPrintable(text^);
			ELSIF (encoding = "B") OR (encoding = "b")  THEN
				string := decodeBase64(text^);
			END;

			IF charset^ = "UTF-8" THEN
				resWriter.String(string^);
			ELSIF charset^ = "ISO-8859-1" THEN
				j := StringLength(string^);
				NEW(text, 6*j + 1);
				UTF8Strings.ASCIItoUTF8(string^, text^);
				resWriter.String(text^);
			ELSE (* assume US-ASCII *)
				j := StringLength(string^);
				NEW(text, 6*j + 1);
				UTF8Strings.ASCIItoUTF8(string^, text^);
				resWriter.String(text^);
			END;
		ELSE
			resWriter.Char(buf[i]);
			INC(i);
		END;
	END;
	string := res.GetString();
	StringCopy(string^, 0, StringLength(string^), buf);
END replaceEncodedHeaderWord;

PROCEDURE replaceEncodedFolderName*(VAR name: String);
VAR
	i: LONGINT;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	utf8: ARRAY 7 OF CHAR;
	state: LONGINT;
	value, pos: LONGINT;
	r: BOOLEAN;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	i := 0;
	WHILE i < StringLength(name^) DO
		IF (name^[i] = "&") & (name^[i+1] = "-") THEN
			w.Char("&");
			i := i + 2;
		ELSIF name^[i] = "&" THEN
			INC(i);
			state := 0;
			pos := 0;
			WHILE name^[i] # "-" DO
				IF (state = 0) OR (state = 1) OR (state = 3) OR (state = 4) OR (state = 6) THEN
					value := base64Table[ORD(name^[i])];
					INC(state);
				ELSIF state = 2 THEN
					value := value * 64 + base64Table[ORD(name^[i])];
					r := UTF8Strings.EncodeChar(value DIV 4, utf8, pos);
					w.String(utf8);
					value := value MOD 4;
					INC(state);
				ELSIF state = 5 THEN
					value := value * 64 + base64Table[ORD(name^[i])];
					r := UTF8Strings.EncodeChar(value DIV 16, utf8, pos);
					w.String(utf8);
					value := value MOD 16;
					INC(state);
				ELSIF state = 7 THEN
					value := value * 64 + base64Table[ORD(name^[i])];
					r := UTF8Strings.EncodeChar(value, utf8, pos);
					w.String(utf8);
					value := 0;
					state := 0;
				END;
				INC(i);
			END;
			INC(i);

		ELSE
			w.Char(name^[i]);
			INC(i);
		END;
	END;

	name := buffer.GetString();
END replaceEncodedFolderName;

(* This procedure returns a string that is a valid string for the date field in an RFC822 message header *)
PROCEDURE getRFC822Date*():String;
VAR
	year, week : LONGINT;
	dayOfWeek: LONGINT;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	answer: String;
	dayTable: ARRAY 25 OF CHAR;
	monthTable: ARRAY 37 OF CHAR;
	td : Dates.DateTime;
BEGIN
	(* was: dayTable := "MonTueWedThuFriSatSun"; but: ISO 8601  week day is (Monday=1, ....Sunday=7) *)
	dayTable := "SunMonTueWedThuFriSatSun";
	monthTable := "JanFebMarAprMayJunJulAugSepOctNovDec";
	NEW(buffer, 16);
	w := buffer.GetWriter();

	td := Dates.Now();
	Dates.WeekDate(td, year, week, dayOfWeek);

	w.Char(dayTable[dayOfWeek*3]); w.Char(dayTable[dayOfWeek*3+1]); w.Char(dayTable[dayOfWeek*3+2]); w.String(", ");
	w.Int(td.day,0); w.Char(" ");
	w.Char(monthTable[(td.month-1)*3]); w.Char(monthTable[(td.month-1)*3+1]); w.Char(monthTable[(td.month-1)*3+2]); w.Char(" ");
	w.Int(year, 0); w.Char(" ");

	IF td.hour < 10 THEN w.Char("0"); END;
	w.Int(td.hour, 0);
	w.Char(":");
	IF td.minute < 10 THEN w.Char("0");END;
	w.Int(td.minute,0);
	w.Char(":");
	IF td.second < 10 THEN w.Char("0"); END;
	w.Int(td.second,0);
	w.String(" +0100");

	answer := buffer.GetString();

	RETURN answer;
END getRFC822Date;

BEGIN
	(* create decoding table *)
	FOR index := 0 TO 127 DO
		base64Table[index] := -1;
	END;

	FOR index := 48 TO 57 DO
		base64Table[index] := index + 4;
	END;
	FOR index := 65 TO 90 DO
		base64Table[index] := index - 65;
	END;
	FOR index := 97 TO 122 DO
		base64Table[index] := index - 71;
	END;
	base64Table[43] := 62;
	base64Table[44] := 63; (* for replaceEncodedFolderName the BASE64 Encoding uses "," instead of "/" *)
	base64Table[47] := 63;
	base64Table[61] := 64;
END IMAPUtilities.