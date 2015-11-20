MODULE FoxDocumentationScanner; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Streams, Diagnostics, D := Debugging;


CONST
	(* scanner constants *)
	EOT* = 0X; LF* = 0AX; CR* = 0DX;
	Trace=FALSE;
TYPE

	Token*= ENUM
		EndOfText*, NewLine*, Header*, Pipe*, LeftItalic*, RightItalic*, LeftBold*, RightBold*, LeftUnderline*, RightUnderline*,
		LinkBegin*, LinkEnd*, Heading*, Number*, LeftDescription*, RightDescription*, Description*,
		Bullet*, Line*, CodeBegin*, CodeEnd*, LabelBegin*, LabelEnd*,
		LineBreak*, Section*, String*
	END;

	String*= POINTER TO ARRAY OF CHAR;

	Symbol*= RECORD
		position*: LONGINT;
		token*: Token;
		level*: LONGINT;
		string*: String;
		stringLength*: LONGINT;
		hasWhitespace*: BOOLEAN;
	END;

	(** scanner reflects the following EBNF
	**)
	Scanner* = OBJECT
	VAR
		(* helper state information *)
		reader: Streams.Reader;   (* source *)
		diagnostics: Diagnostics.Diagnostics;   (* error logging *)

		ch: CHAR;   (* look-ahead character *)
		position-: LONGINT;   (* current position *)
		prevToken: Token;

		(*
			source: name of the source code for reference in error outputs
			reader: input stream
			position: reference position (offset) of the input stream , for error output
			diagnostics: error output object
		*)
		PROCEDURE & InitializeScanner*(reader: Streams.Reader; position: LONGINT; diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.reader := reader;
			SELF.diagnostics := diagnostics;
			ch := " ";
			IF reader = NIL THEN ch := EOT ELSE GetNextCharacter END;
			SELF.position := position;
		END InitializeScanner;

		(** get next character, end of text results in ch = EOT **)
		PROCEDURE GetNextCharacter;
		BEGIN
			ASSERT(ch # EOT);
			reader.Char(ch); INC(position);
		END GetNextCharacter;

		PROCEDURE Peek(): CHAR;
		BEGIN
			RETURN reader.Peek()
		END Peek;

		PROCEDURE BreaksLiteral(): BOOLEAN;
		BEGIN
			CASE ch OF
				"*", "_", "/","#":
					IF IsWhitespace(Peek(),TRUE) THEN RETURN TRUE END; (* right of bold, underline, italics and description *)
				|"]",">","\":
					IF ch = Peek() THEN RETURN TRUE END; (* right of link or label *)
				|"|": RETURN TRUE (* pipe in link or table *)
			ELSE
				RETURN FALSE
			END;
			RETURN FALSE
		END BreaksLiteral;

		PROCEDURE IdentifierStart(ch: CHAR): BOOLEAN;
		BEGIN
			CASE ch OF
				| 'a' .. 'z', 'A' .. 'Z', '_': RETURN TRUE
			ELSE RETURN FALSE
			END;
		END IdentifierStart;

		PROCEDURE AppendCharacter(VAR symbol: Symbol; ch: CHAR);
		VAR s: String;  i: LONGINT;
		BEGIN
			IF symbol.string = NIL THEN NEW(symbol.string,32); symbol.stringLength := 0; END;
			IF symbol.stringLength = LEN(symbol.string)-1 THEN
				s := symbol.string;
				NEW(symbol.string, symbol.stringLength*2);
				FOR i := 0 TO symbol.stringLength DO
					symbol.string[i] := s[i];
				END;
			END;
			symbol.string[symbol.stringLength] := ch;
			INC(symbol.stringLength);
		END AppendCharacter;

		PROCEDURE AppendCharacters(VAR symbol: Symbol; ch: CHAR; number: LONGINT);
		BEGIN
			WHILE number > 0 DO
				AppendCharacter(symbol,ch); DEC(number)
			END;
		END AppendCharacters;

		PROCEDURE ReadLiteral(VAR symbol: Symbol; token: Token);
		BEGIN
			symbol.token := token;
			REPEAT (* consumes at least one character *)
				AppendCharacter(symbol, ch);
				GetNextCharacter;
			UNTIL (ch <= " ") OR BreaksLiteral();
		END ReadLiteral;

		PROCEDURE ReadLiteralWS(VAR symbol: Symbol; token: Token);
		BEGIN
			symbol.token := token;
			REPEAT (* consumes at least one character *)
				AppendCharacter(symbol, ch);
				GetNextCharacter;
			UNTIL (ch <= " ");
		END ReadLiteralWS;

		PROCEDURE ReadCharacters(this: CHAR; min,max: LONGINT; VAR symbol: Symbol; token: Token);
		BEGIN
			symbol.level := 0;
			WHILE (ch = this) DO INC(symbol.level); GetNextCharacter END;
			IF (symbol.level >= min) OR (symbol.level <= max) THEN
				symbol.token := token;
			ELSE
				AppendCharacters(symbol, this, symbol.level);
				ReadLiteral(symbol, Token.String);
			END;
		END ReadCharacters;

		PROCEDURE IsWhitespace(ch: CHAR; includeNewLine: BOOLEAN): BOOLEAN;
		BEGIN
			RETURN (ch <= " ") & (ch # EOT) & (includeNewLine OR (ch # CR) & (ch # LF))
		END IsWhitespace;

		(** get next symbol **)
		PROCEDURE GetNextSymbol*(VAR symbol: Symbol);
		VAR s: Token; prev: CHAR; firstInLine: BOOLEAN;

			PROCEDURE SkipBlanks;
			BEGIN
				WHILE IsWhitespace(ch,FALSE) DO  (*ignore control characters*)
					prev := ch;
					GetNextCharacter
				END;
			END SkipBlanks;

			PROCEDURE ReadCode;
			VAR ending: LONGINT; end:BOOLEAN;
			BEGIN
				ending := 0; end := FALSE;
				REPEAT
					AppendCharacter(symbol, ch);
					IF ch = "}" THEN
						INC(ending);
						GetNextCharacter
					ELSIF (ending = 3) & (ch # "'") & (ch # '"')  (* to allow for referencing '}}}' in descriptions of the documentation *)& (ending = 3) THEN
						end := TRUE
					ELSE
						ending := 0;
						GetNextCharacter
					END;
				UNTIL (ch = EOT) OR end;
				IF end THEN
					symbol.token := Token.CodeEnd;
					DEC(symbol.stringLength,4);
					symbol.string[symbol.stringLength] := 0X
				ELSE
					symbol.token := Token.EndOfText
				END;
			END ReadCode;

			(* return if the current character is preceded by a whitespace and next character is not a whitespace, such as in the beginning of *b o l d*  *)
			PROCEDURE IsLeft(): BOOLEAN;
			BEGIN
				RETURN IsWhitespace(prev,FALSE) & ~IsWhitespace(Peek(),FALSE)
			END IsLeft;

			(* return if the current character is preceded by a non-whitespace and next character is a whitespace, such as at the end of *b o l d*  *)
			PROCEDURE IsRight(): BOOLEAN;
			BEGIN
				RETURN ~IsWhitespace(prev,TRUE) & IsWhitespace(Peek(),TRUE)
			END IsRight;


		BEGIN
			symbol.stringLength := 0;
			symbol.string := NIL;
			symbol.level := 0;
			symbol.position := position;

			prev := ch;
			SkipBlanks;
			firstInLine := prevToken = Token.NewLine;

			symbol.hasWhitespace := IsWhitespace(prev, FALSE);

			IF symbol.token = Token.CodeBegin THEN
				ReadCode;
				RETURN
			END;


			CASE ch OF  (* ch > " " *)
			EOT: symbol.token := Token.EndOfText
			| CR: symbol.token := Token.NewLine; GetNextCharacter; IF ch = LF THEN GetNextCharacter END;
			| LF: symbol.token := Token.NewLine; GetNextCharacter; IF ch = CR THEN GetNextCharacter END;
			|  '|': GetNextCharacter;
				IF (ch = "=") THEN symbol.token := Token.Header; GetNextCharacter ELSE symbol.token := Token.Pipe END;
			|  '/':
				IF IsLeft() THEN  symbol.token := Token.LeftItalic; GetNextCharacter;
				ELSIF IsRight() THEN symbol.token := Token.RightItalic; GetNextCharacter;
				ELSE ReadLiteral( symbol, Token.String)
				END
			|  '_':
				IF IsLeft() THEN  symbol.token := Token.LeftUnderline;GetNextCharacter;
				ELSIF IsRight() THEN symbol.token := Token.RightUnderline;GetNextCharacter;
				ELSE ReadLiteral( symbol, Token.String)
				END
			|  '[': ReadCharacters (ch, 2, 2, symbol, Token.LinkBegin);
			|  ']': ReadCharacters (ch, 2, 2, symbol, Token.LinkEnd);
			|  '=':
				IF firstInLine THEN
					ReadCharacters (ch, 1, 3, symbol, Token.Heading);
					IF IdentifierStart(ch) THEN
						WHILE ~IsWhitespace(ch,TRUE) & (ch#EOT) DO
							AppendCharacter(symbol,ch);
							GetNextCharacter;
						END;
					END;
				ELSE ReadLiteral(symbol, Token.String);
				END;
			|  '#':
				IF firstInLine THEN (* number *)
					ReadCharacters(ch, 1, 3, symbol, Token.Number);
					IF IsWhitespace(ch,FALSE) THEN
						symbol.token := Token.Number;
					ELSIF symbol.level = 1 THEN
						symbol.token := Token.LeftDescription;
					ELSE
						ReadLiteral(symbol, Token.String);
					END;
				ELSE
					IF IsLeft() THEN symbol.token := Token.LeftDescription; symbol.level := 1; GetNextCharacter;
					ELSIF IsRight() THEN symbol.token := Token.RightDescription;GetNextCharacter;
					ELSE ReadLiteral(symbol, Token.String);
					END;
				END;
			|  '*':
				IF firstInLine THEN
					ReadCharacters(ch, 1, 3, symbol, Token.Bullet);
					IF IsWhitespace(ch,FALSE) THEN
						symbol.token := Token.Bullet;
					ELSIF symbol.level = 1 THEN
						symbol.token := Token.LeftBold;
					ELSE
						AppendCharacters(symbol, '*', symbol.level);
						ReadLiteral(symbol, Token.String);
					END;
				ELSE
					IF IsLeft() THEN symbol.token := Token.LeftBold;GetNextCharacter;
					ELSIF  IsRight() THEN symbol.token := Token.RightBold;GetNextCharacter;
					ELSE ReadLiteral(symbol, Token.String);
					END;
				END;
			|  '-':
				IF firstInLine THEN ReadCharacters (ch, 4, MAX(LONGINT), symbol, Token.Line)
				ELSE ReadLiteral(symbol, Token.String);
				END;
			|  '{': ReadCharacters (ch, 3, 3, symbol, Token.CodeBegin);
			|  '}': ReadCharacters (ch, 3, 3, symbol, Token.CodeEnd);
			|  '<':
				ReadCharacters (ch, 2, 2, symbol, Token.LabelBegin);
				IF IsWhitespace(ch, TRUE) & (symbol.level = 2) THEN
					AppendCharacters(symbol,'<',2);
					symbol.token := Token.String
				END;
			|  '>':
				ReadCharacters (ch, 2, 2, symbol, Token.LabelEnd);
				IF IsWhitespace(prev, FALSE) & (symbol.level = 2) THEN
					AppendCharacters(symbol,'>',2);
					ReadLiteral(symbol, Token.String);
				END;
			|  '\':
				ReadCharacters (ch, 2, 2, symbol, Token.LineBreak);
			|  '@': ReadCharacters (ch, 1, 10, symbol, Token.Section);
				IF IdentifierStart(ch) THEN
					WHILE ~IsWhitespace(ch,TRUE) & (ch#EOT) DO
						AppendCharacter(symbol,ch);
						GetNextCharacter;
					END;
				END;
			ELSE
				ReadLiteral(symbol,Token.String)
			END;
			prevToken := symbol.token;

			IF (firstInLine) & (symbol.token = Token.String) & (symbol.stringLength>0) & (symbol.string[symbol.stringLength-1] = ":") THEN
				DEC(symbol.stringLength);
				symbol.string[symbol.stringLength] := 0X;
				symbol.token := Token.Description;
			END;

			IF Trace THEN DumpSymbol(D.Log, symbol); D.Ln END;
		END GetNextSymbol;

	END Scanner;

	PROCEDURE DumpSymbol(w: Streams.Writer; CONST symbol: Symbol);
	BEGIN
		w.String("token: ");
		CASE symbol.token OF
			Token.EndOfText: w.String("EndOfText");
			|Token.NewLine: w.String("NewLine");
			|Token.Header:w.String("Header");
			|Token.Pipe:w.String("Pipe");
			|Token.LeftItalic:w.String("LeftItalic");
			|Token.RightItalic:w.String("RightItalic");
			|Token.LinkBegin:w.String("LinkBegin");
			|Token.LinkEnd:w.String("LinkEnd");
			|Token.Heading:w.String("Heading");
			|Token.Number:w.String("Number");
			|Token.Bullet:w.String("Bullet");
			|Token.LeftBold:w.String("LeftBold");
			|Token.RightBold:w.String("RightBold");
			|Token.LeftUnderline:w.String("LeftUnderline");
			|Token.RightUnderline:w.String("RightUnderline");
			|Token.Line:w.String("Line");
			|Token.CodeBegin:w.String("CodeBegin");
			|Token.CodeEnd:w.String("CodeEnd");
			|Token.LabelBegin:w.String("LabelBegin");
			|Token.LabelEnd:w.String("LabelEnd");
			|Token.LineBreak:w.String("LineBreak");
			|Token.Section:w.String("Section");
			|Token.String:w.String("String");
		END;
	END DumpSymbol;

END FoxDocumentationScanner.
