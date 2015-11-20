MODULE XMLScanner;	(** AUTHOR "swalthert"; PURPOSE "XML scanner"; *)

IMPORT
	KernelLog, Streams, Strings, DynamicStrings;

CONST

	(* String pooling settings *)
	Str_ElementName* = 1;
	Str_AttributeName* = 2;
	Str_CharRef* = 10;
	Str_EntityRef* = 11;
	Str_EntityValue* = 12;
	Str_AttributeValue* = 13;
	Str_Comment* = 20;
	Str_ProcessingInstruction* = 21;
	Str_CDataSection* = 22;
	Str_SystemLiteral* = 23;
	Str_PublicLiteral* = 24;
	Str_CharData* = 25;
	Str_Other* = 30;

	(** Scanner: Tokens *)
	Invalid* = -1;
	TagElemStartOpen* = 0;	(** '<' *)
	TagElemEndOpen* = 1;	(** '</' *)
	TagDeclOpen* = 2;	(** '<!NAME' *)
	TagClose* = 3;	(** '>' *)
	TagEmptyElemClose* = 4;	(** '/>' *)
	TagXMLDeclOpen* = 5;	(** '<?xml' *)
	TagPIOpen* = 6;	(** '<?', PITarget := GetStr() *)
	TagPIClose* = 7;	(** '?>' *)
	TagCondSectOpen* = 8;	(** '<![' *)
	TagCondSectClose* = 9;	(** ']]>' *)
	BracketOpen* = 10;	(** '[' *)
	BracketClose* = 11;	(** ']' *)
	ParenOpen* = 12;	(** '(' *)
	ParenClose* = 13;	(** ')' *)
	Comment* = 14;	(** '<!--' chars '-->', chars := GetStr() *)
	CDataSect* = 15;	(** '<![CDATA[' chars ']]>', chars := GetStr() *)
	CharRef* = 16;	(** '&#' number ';' or '&#x' hexnumber ';', number, hexnumber := GetStr() *)
	EntityRef* = 17;	(** '&' name ';', name := GetStr() *)
	ParamEntityRef* = 18;	(** '%' name ';', name := GetStr() *)
	CharData* = 19;	(** chars := GetStr() *)
	Literal* = 20;	(** '"'chars'"' or "'"chars"'", chars := GetStr() *)
	Name* = 21;	(** 	Name ::= (Letter | '_' | ':') {NameChar}
										NameChar ::= Letter | Digit | '.' | '-' | '_' | ':' | CombiningChar | Extender
										chars := GetStr() *)
	Nmtoken* = 22;	(**	Nmtoken ::= NameChar {NameChar}, chars := GetStr() *)
	PoundName* = 23;	(** '#'name, name := GetStr() *)
	Question* = 24;	(** '?' *)
	Asterisk* = 25;	(** '*' *)
	Plus* = 26;	(** '+' *)
	Or* = 27;	(** '|' *)
	Comma* = 28;	(** ',' *)
	Percent* = 29;	(** '%' *)
	Equal* = 30;	(** '=' *)
	Eof* = 31;

	LF = 0AX;
	CR = 0DX;

TYPE
	String = Strings.String;

	Scanner* = OBJECT
		VAR
			sym-: SHORTINT;	(** current token *)
			line-, col-, oldpos, pos: LONGINT;
			reportError*: PROCEDURE {DELEGATE} (pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
			nextCh: CHAR;	(* look-ahead *)
			dynstr: DynamicStrings.DynamicString;	(* buffer for CharData, Literal, Name, CharRef, EntityRef and ParamEntityRef *)
			r : Streams.Reader;
			stringPool : DynamicStrings.Pool;
			stringPooling : SET;

		(** Initialize scanner to read from the given ascii file *)
		PROCEDURE & Init*(r: Streams.Reader);
		BEGIN
			reportError := DefaultReportError;
			SELF.r := r;
			NEW(dynstr);
			line := 1; pos := 0; col := 0;
			stringPool := NIL;
			stringPooling := {};
			NextCh();
		END Init;

		PROCEDURE SetStringPooling*(stringPooling : SET);
		BEGIN
			SELF.stringPooling := stringPooling;
			IF (stringPooling = {}) THEN
				stringPool := NIL;
			ELSIF (stringPool = NIL) THEN
				NEW(stringPool);
			END;
			ASSERT((stringPool = NIL) = (stringPooling = {}));
		END SetStringPooling;

		PROCEDURE Error(CONST msg: ARRAY OF CHAR);
		BEGIN
			sym := Invalid;
			reportError(GetPos(), line, col, msg)
		END Error;

		PROCEDURE NextCh;
		BEGIN
			IF (nextCh = CR) OR (nextCh = LF) THEN INC(line); col := 0;
			ELSE INC(col)
			END;
			IF r.res # Streams.Ok THEN
				nextCh := 0X; sym := Eof
			ELSE
				nextCh := r.Get(); INC(pos);
			END
		END NextCh;

		PROCEDURE ReadTillChar(ch: CHAR);
		BEGIN
			dynstr.Clear;
			WHILE (nextCh # ch) & (sym # Eof) DO
				dynstr.AppendCharacter(nextCh);
				NextCh();
			END;
			IF sym = Eof THEN sym := Invalid END
		END ReadTillChar;

		PROCEDURE SkipWhiteSpaces;
		BEGIN
			WHILE IsWhiteSpace(nextCh) & (sym # Eof) DO
				NextCh()
			END
		END SkipWhiteSpaces;

		PROCEDURE ScanPoundName;
		BEGIN
			dynstr.Clear;
			dynstr.AppendCharacter(nextCh);
			NextCh();
			WHILE (('a' <= nextCh) & (nextCh <= 'z')) OR (('A' <= nextCh) & (nextCh <= 'Z')) OR
				(('0' <= nextCh) & (nextCh <= '9')) OR (nextCh = '.') OR (nextCh = '-') OR (nextCh = '_') OR (nextCh = ':') DO
				dynstr.AppendCharacter(nextCh);
				NextCh();
			END;
			IF sym # Eof THEN sym := PoundName ELSE sym := Invalid END
		END ScanPoundName;

		(* Possible results:
				Name
				Nmtoken
				Invalid	*)
		PROCEDURE ScanNm;
		BEGIN
			SkipWhiteSpaces();
			IF (('0' <= nextCh) & (nextCh <= '9')) OR (nextCh = '.') OR (nextCh = '-') THEN
				sym := Nmtoken
			ELSIF (('a' <= nextCh) & (nextCh <= 'z')) OR (('A' <= nextCh) & (nextCh <= 'Z')) OR (nextCh = '_') OR (nextCh = ':') THEN
				sym := Name
			ELSE
				sym := Invalid; RETURN
			END;
			dynstr.Clear;
			dynstr.AppendCharacter(nextCh);
			NextCh();
			WHILE ((('a' <= nextCh) & (nextCh <= 'z')) OR (('A' <= nextCh) & (nextCh <= 'Z')) OR
					(('0' <= nextCh) & (nextCh <= '9')) OR (nextCh = '.') OR (nextCh = '-') OR (nextCh = '_')
					OR (nextCh = ':')) & (sym # Eof) DO
				dynstr.AppendCharacter(nextCh);
				NextCh();
			END;
			IF sym = Eof THEN sym := Invalid END
		END ScanNm;

		(* Scan Comment after comment open tag '<!--', write characters to dynstr.
				Possible results:
				Invalid
				Comment	*)
		PROCEDURE ScanComment;
		BEGIN
			dynstr.Clear;
			LOOP
				WHILE (nextCh # '-') & (sym # Eof) DO
					dynstr.AppendCharacter(nextCh);
					NextCh()
				END;
				IF nextCh = '-' THEN
					NextCh();
					IF nextCh = '-' THEN
						NextCh();
						IF nextCh = '>' THEN
							NextCh(); sym := Comment; RETURN
						ELSE
							sym := Invalid; RETURN
						END
					ELSE
						dynstr.AppendCharacter('-');
					END
				ELSE
					sym := Invalid; RETURN
				END
			END
		END ScanComment;

		(* Possible results:
				CharData
				TagCDataSectClose
				Invalid	*)
		PROCEDURE ScanCDataSect;
		VAR bc: LONGINT; escape : BOOLEAN;
		BEGIN
			IF sym = Eof THEN
				sym := Invalid;
				RETURN
			END;
			dynstr.Clear;
			LOOP
				WHILE (nextCh # ']') &  (sym # Eof) DO
					dynstr.AppendCharacter(nextCh);
					NextCh()
				END;
				IF nextCh = ']' THEN
					bc := 1; escape := FALSE; NextCh();
					WHILE nextCh = ']' DO
						INC(bc); NextCh();
						IF nextCh = '>' THEN
							NextCh(); escape := TRUE;
						END
					END;
					IF escape THEN
						WHILE (bc > 2) DO
							DEC(bc);
							dynstr.AppendCharacter(']');
						END;
						sym := CDataSect; RETURN
					ELSE
						WHILE (bc > 0) DO
							DEC(bc); dynstr.AppendCharacter(']');
						END;
					END;
				ELSE
					sym := CharData; RETURN
				END
			END
		END ScanCDataSect;

		(* possible results:
			Invalid
			ParamEntityRef *)
		PROCEDURE ScanPEReference;
		BEGIN
			ReadTillChar(';'); NextCh();
			IF sym # Invalid THEN sym := ParamEntityRef END
		END ScanPEReference;

		(* possible results:
			Invalid
			CharRef
			EntityRef *)
		PROCEDURE ScanReference;
		BEGIN
			IF nextCh = '#' THEN
				NextCh();
				ReadTillChar(';'); NextCh();
				IF sym # Invalid THEN sym := CharRef END;
			ELSE
				ReadTillChar(';'); NextCh();
				IF sym # Invalid THEN sym := EntityRef END
			END
		END ScanReference;

		(** possible results:
			Invalid
			TagPIClose
			CharData	*)
		PROCEDURE ScanPInstruction*;
		BEGIN
			IF sym = Eof THEN
				sym := Invalid;
				RETURN
			END;
			dynstr.Clear;
			LOOP
				WHILE (nextCh # '?') & (sym # Eof) DO
					dynstr.AppendCharacter(nextCh);
					NextCh();
				END;
				IF nextCh = '?' THEN
					NextCh();
					IF nextCh = '>' THEN
						sym := TagPIClose; NextCh(); RETURN
					ELSE
						dynstr.AppendCharacter('?');
					END
				ELSIF sym = Eof THEN
					sym := Invalid; RETURN
				ELSE
					sym := CharData; RETURN
				END
			END
		END ScanPInstruction;

		(** Possible results:
			Invalid
			TagPIOpen
			TagCondSectOpen
			TagDeclOpen
			TagXMLDeclOpen
			TagClose
			TagEmptyElemClose
			TagPIClose
			TagCondSectClose
			Comment
			CharRef
			EntityRef
			ParamEntityRef
			Literal
			Name
			Nmtoken
			PoundName
			Question
			Asterisk
			Plus
			Or
			Comma
			Percent
			Equal
			ParenOpen
			ParenClose
			BracketOpen
			BracketClose	*)
		PROCEDURE ScanMarkup*;
		VAR ch: CHAR;
		BEGIN
			SkipWhiteSpaces();
			oldpos := GetPos();
			IF sym = Eof THEN
				sym := Eof; RETURN
			END;
			CASE nextCh OF
			| '<': NextCh();
					IF nextCh = '!' THEN
						NextCh();
						IF nextCh = '-' THEN
							NextCh();
							IF nextCh = '-' THEN
								NextCh(); ScanComment()
							ELSE
								Error("'<!--' expected")
							END
						ELSIF nextCh = '[' THEN
							sym := TagCondSectOpen
						ELSE
							ScanNm();
							IF sym = Name THEN
								sym := TagDeclOpen
							ELSE
								Error("'<!NAME' expected")
							END
						END
					ELSIF nextCh = '?' THEN
						NextCh(); ScanNm();
						IF sym = Name THEN
							sym := TagPIOpen
						ELSE
							Error("'<?' Name expected")
						END
					ELSE
						Error("'<?' Name or '<!--' expected")
					END
			| '/': NextCh();
					IF nextCh = '>' THEN
						NextCh(); sym := TagEmptyElemClose
					ELSE
						sym := Invalid
					END
			| '>': NextCh(); sym := TagClose
			| '%': NextCh();
					IF nextCh = ' ' THEN
						sym := Percent
					ELSE
						ScanPEReference()
					END
			| '?': NextCh();
					IF nextCh = '>' THEN
						NextCh();
						sym := TagPIClose
					ELSE
						sym := Question
					END
			| '*': NextCh(); sym := Asterisk
			| '+': NextCh(); sym := Plus
			| '|': NextCh(); sym := Or
			| ',': NextCh(); sym := Comma
			| '(': NextCh(); sym := ParenOpen
			| ')': NextCh(); sym := ParenClose
			| '[': NextCh(); sym := BracketOpen
			| ']': NextCh();
					IF nextCh = ']' THEN
						NextCh();
						IF nextCh = '>' THEN
							NextCh(); sym := TagCondSectClose
						ELSE
							Error("']]>' expected")
						END
					ELSE
						sym := BracketClose
					END
			| '=': NextCh(); sym := Equal
			| '"', "'": ch := nextCh; NextCh(); ReadTillChar(ch); NextCh();
					IF sym # Invalid THEN sym := Literal END;
			| '#': ScanPoundName()
			ELSE ScanNm()
			END
		END ScanMarkup;

		(** possible results:
			TagElemEndOpen
			TagPIOpen
			TagDocTypeOpen
			CDataSect
			TagElemStartOpen
			Comment
			CharData
			CharRef
			EntityRef
			Eof *)
		PROCEDURE ScanContent*;
		VAR op : LONGINT;
		BEGIN
			op := GetPos();
			SkipWhiteSpaces(); oldpos := GetPos();
			IF sym = Eof THEN nextCh := 0X END;
			CASE nextCh OF
			| 0X: sym := Eof
			| '<': NextCh();
					CASE nextCh OF
					| '/': sym := TagElemEndOpen; NextCh()
					| '?': NextCh(); ScanNm();
							IF (sym = Name) THEN
								IF dynstr.EqualsTo("xml", TRUE) THEN
									sym := TagXMLDeclOpen
								ELSE
									sym := TagPIOpen
								END
							ELSE
								Error("'<? Name' expected")
							END
					| '!': NextCh();
							IF nextCh = '-' THEN
								NextCh();
								IF nextCh = '-' THEN
									NextCh(); ScanComment()
								ELSE
									Error("'<!--' expected")
								END
							ELSIF nextCh = '[' THEN
								NextCh(); ScanNm();
								IF (sym = Name) & dynstr.EqualsTo("CDATA", FALSE) & (nextCh = '[') THEN
									NextCh(); ScanCDataSect()
								ELSE
									Error("'<[CDATA[' expected'")
								END
							ELSE
								ScanNm();
								IF  sym = Name THEN
									sym := TagDeclOpen
								ELSE
									Error("'<!xml' or '<!NAME' expected")
								END
							END
					ELSE
						sym:=TagElemStartOpen
					END
(*			| '?': NextCh();
					IF nextCh = '>' THEN
						NextCh(); sym := TagPIClose
					ELSE
						Error("'?>' expected")
					END
*)			| '&': NextCh(); ScanReference()
			ELSE
				dynstr.Clear;
				REPEAT
					dynstr.AppendCharacter(nextCh);
					NextCh();
				UNTIL (nextCh='<') OR (sym = Eof);
				oldpos := op;
				sym := CharData
			END
		END ScanContent;

		PROCEDURE GetString*(type : LONGINT): String;
		VAR string : String;
		BEGIN
			IF (type IN stringPooling) THEN
				string := stringPool.Get(dynstr);
			ELSE
				string := dynstr.ToArrOfChar();
			END;
			RETURN string;
		END GetString;

		PROCEDURE GetPos*(): LONGINT;
		BEGIN
			RETURN pos - 1
		END GetPos;

		PROCEDURE GetOldPos*(): LONGINT;
		BEGIN
			RETURN oldpos
		END GetOldPos;

	END Scanner;

	PROCEDURE IsWhiteSpace(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (ch = 020X) OR (ch = 9X) OR (ch = 0DX) OR (ch = 0AX)
	END IsWhiteSpace;

	PROCEDURE DefaultReportError(pos, line, col: LONGINT; CONST msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", col "); KernelLog.Int(col, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
		HALT(99)
	END DefaultReportError;

END XMLScanner.