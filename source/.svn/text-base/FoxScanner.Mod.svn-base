MODULE FoxScanner;   (**  AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Scanner";  **)
(* (c) fof ETH Zürich, 2009 *)

IMPORT Streams, Strings, Diagnostics, Basic := FoxBasic, D := Debugging, Commands, StringPool;

CONST
	Trace = FALSE;   (* debugging output *)

	(* overal scanner limitation *)
	MaxIdentifierLength* = 128;

	(* parametrization of numeric scanner: *)
	MaxHexDigits* = 8;   (* maximal hexadecimal longint length *)
	MaxHugeHexDigits* = 16;   (* maximal hexadecimal hugeint length *)
	MaxRealExponent* = 38;   (* maximal real exponent *)
	MaxLongrealExponent* = 308;   (* maximal longreal exponent *)

	(* scanner constants *)
	EOT* = 0X; LF* = 0AX; CR* = 0DX; TAB* = 09X;

TYPE
	StringType* = Strings.String;
	IdentifierType *= StringPool.Index;
	IdentifierString*= ARRAY MaxIdentifierLength+1 OF CHAR;

CONST

(** tokens *)
	(*
	note: order of tokens is important for the parser, do not modify without looking it up

	FoxProgTools.Enum --export --linefeed=6
    	None
	(* RelationOps: Equal ... Is *)
    	Equal DotEqual Unequal DotUnequal
    	Less DotLess  LessEqual DotLessEqual Greater DotGreater GreaterEqual DotGreaterEqual
    	LessLessQ GreaterGreaterQ Questionmarks ExclamationMarks 
    	In Is
    	(* MulOps: Times ... And *)
    	Times TimesTimes DotTimes PlusTimes Slash Backslash DotSlash Div Mod And
    	(* AddOps: Or ... Minus *)
    	Or Plus Minus
    	(* Prefix Unary Operators Plus ... Not *)
		Not
    	(* expressions may start with Plus ... Identifier *)
		LeftParenthesis LeftBracket LeftBrace Number Character String Nil Imag True False Self Result Identifier
		(* statementy may start with Self ... Begin *)
		If Case While Repeat For Loop With Exit Await Return Begin
		(* symbols, expressions and statements cannot start with *)
		Semicolon Transpose RightBrace RightBracket RightParenthesis 
		Questionmark ExclamationMark
		LessLess GreaterGreater 
		Upto Arrow Period Comma Colon Of Then Do To By Becomes Bar End Else Elsif Until Finally
		(* declaration elements *)
		Code Const Type Var Out Procedure Operator Import Definition Module Cell CellNet Extern
		(* composite type symbols *)
		Array Object Record Pointer Enum Port Address Size Alias
		(* assembler constants *)
		Ln PC PCOffset
		(* number types *)
		Shortint Integer Longint Hugeint Real Longreal
		Comment EndOfText
		~
	*)
	None*= 0; 
	(* RelationOps: Equal ... Is *)
	Equal*= 1; DotEqual*= 2; Unequal*= 3; DotUnequal*= 4; Less*= 5; DotLess*= 6; 
	LessEqual*= 7; DotLessEqual*= 8; Greater*= 9; DotGreater*= 10; GreaterEqual*= 11; DotGreaterEqual*= 12; 
	LessLessQ*= 13; GreaterGreaterQ*= 14; Questionmarks*= 15; ExclamationMarks*= 16; In*= 17; Is*= 18; 
	(* MulOps: Times ... And *)
	Times*= 19; TimesTimes*= 20; DotTimes*= 21; PlusTimes*= 22; Slash*= 23; Backslash*= 24; 
	DotSlash*= 25; Div*= 26; Mod*= 27; And*= 28; 
	(* AddOps: Or ... Minus *)
	Or*= 29; Plus*= 30; Minus*= 31; 
	(* Prefix Unary Operators Plus ... Not *)
	Not*= 32; 
	(* expressions may start with Plus ... Identifier *)
	LeftParenthesis*= 33; LeftBracket*= 34; LeftBrace*= 35; Number*= 36; Character*= 37; String*= 38; 
	Nil*= 39; Imag*= 40; True*= 41; False*= 42; Self*= 43; Result*= 44; 
	Identifier*= 45; 
	(* statementy may start with Self ... Begin *)
	If*= 46; Case*= 47; While*= 48; Repeat*= 49; For*= 50; Loop*= 51; 
	With*= 52; Exit*= 53; Await*= 54; Return*= 55; Begin*= 56; 
	(* symbols, expressions and statements cannot start with *)
	Semicolon*= 57; Transpose*= 58; RightBrace*= 59; RightBracket*= 60; RightParenthesis*= 61; Questionmark*= 62; 
	ExclamationMark*= 63; LessLess*= 64; GreaterGreater*= 65; Upto*= 66; Arrow*= 67; Period*= 68; 
	Comma*= 69; Colon*= 70; Of*= 71; Then*= 72; Do*= 73; To*= 74; 
	By*= 75; Becomes*= 76; Bar*= 77; End*= 78; Else*= 79; Elsif*= 80; 
	Until*= 81; Finally*= 82; 
	(* declaration elements *)
	Code*= 83; Const*= 84; Type*= 85; Var*= 86; Out*= 87; Procedure*= 88; 
	Operator*= 89; Import*= 90; Definition*= 91; Module*= 92; Cell*= 93; CellNet*= 94; 
	Extern*= 95; 
	(* composite type symbols *)
	Array*= 96; Object*= 97; Record*= 98; Pointer*= 99; Enum*= 100; Port*= 101; 
	Address*= 102; Size*= 103; Alias*= 104; 
	(* assembler constants *)
	Ln*= 105; PC*= 106; PCOffset*= 107; 
	(* number types *)
	Shortint*= 108; Integer*= 109; Longint*= 110; Hugeint*= 111; Real*= 112; Longreal*= 113; 
	Comment*= 114; EndOfText*= 115; 

	SingleQuote = 27X;  DoubleQuote* = 22X;
	Ellipsis = 7FX;   (* used in Scanner.GetNumber to return with ".." when reading an interval like 3..5 *)

	Uppercase*=0;
	Lowercase*=1;
	Unknown*=2;


TYPE
	(* keywords  book keeping *)
	Keyword* = ARRAY 32 OF CHAR;

	KeywordTable* = OBJECT(Basic.HashTableInt); (* string -> index *)
	VAR table: POINTER TO ARRAY OF LONGINT;

		PROCEDURE &InitTable*(size: LONGINT);
		VAR i: LONGINT;
		BEGIN
			Init(size); NEW(table,size); FOR i := 0 TO size-1 DO table[i] := -1; END;
		END InitTable;

		PROCEDURE IndexByIdentifier*(identifier: IdentifierType): LONGINT;
		VAR stringPoolIndex: LONGINT;
		BEGIN
			IF Has(identifier) THEN
				RETURN GetInt(identifier)
			ELSE (* do not modify index *)
				RETURN -1
			END;
		END IndexByIdentifier;

		PROCEDURE IndexByString*(CONST name: ARRAY OF CHAR): LONGINT;
		VAR stringPoolIndex: LONGINT;
		BEGIN
			StringPool.GetIndex(name,stringPoolIndex);
			IF Has(stringPoolIndex) THEN
				RETURN GetInt(stringPoolIndex)
			ELSE (* do not modify index *)
				RETURN -1
			END;
		END IndexByString;

		PROCEDURE IdentifierByIndex*(index: LONGINT; VAR identifier: IdentifierType);
		BEGIN
			identifier := table[index]
		END IdentifierByIndex;

		PROCEDURE StringByIndex*(index: LONGINT; VAR name: ARRAY OF CHAR);
		VAR stringPoolIndex: LONGINT;
		BEGIN
			stringPoolIndex := table[index];
			IF stringPoolIndex < 0 THEN
				name := ""
			ELSE
				StringPool.GetString(stringPoolIndex,name);
			END;
		END StringByIndex;

		PROCEDURE PutString*(CONST name: ARRAY OF CHAR; index: LONGINT);
		VAR stringPoolIndex: LONGINT;
		BEGIN
			StringPool.GetIndex(name,stringPoolIndex);
			table[index] := stringPoolIndex;
			PutInt(stringPoolIndex,index);
		END PutString;

	END KeywordTable;
TYPE

	Token*=LONGINT;

	(**
		symbol: data structure for the data transfer of the last read input from the scanner to the parser
	**)
	Symbol*= RECORD
		start*,end*,line-: LONGINT; (* start and end position of symbol *)
		token*: Token; (* token of symbol *)
		identifier*: IdentifierType; (* identifier *)
		identifierString*: IdentifierString; (* cache of identifier's string *)
		string*: StringType;  (* string or identifier *)
		stringLength*: LONGINT; (* length of string, if stringLength = 2 then this may be interpreted as character and integer = ORD(ch) *)
		numberType*: LONGINT;  (* Integer, HugeInteger, Real or Longreal *)
		integer*: LONGINT;
		hugeint*: HUGEINT;  (*! unify longint and hugeint *)
		character*: CHAR;
		real*: LONGREAL;
	END;

	StringMaker* = OBJECT (* taken from TF's scanner *)
	VAR length : LONGINT;
		data : StringType;

		PROCEDURE &Init*(initialSize : LONGINT);
		BEGIN
			IF initialSize < 256 THEN initialSize := 256 END;
			NEW(data, initialSize); length := 0;
		END Init;

		PROCEDURE Add*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR i : LONGINT; n: StringType;
		BEGIN
			IF length + len + 1 >= LEN(data) THEN
				NEW(n, LEN(data) + len + 1); FOR i := 0 TO length - 1 DO n[i] := data[i] END;
				data := n
			END;
			WHILE len > 0 DO
				data[length] := buf[ofs];
				INC(ofs); INC(length); DEC(len)
			END;
			data[length] := 0X;
		END Add;

		(* remove last n characters *)
		PROCEDURE Shorten*(n : LONGINT);
		BEGIN
			DEC(length, n);
			IF length < 0 THEN length := 0 END;
			IF length > 0 THEN data[length - 1] := 0X ELSE data[length] := 0X END
		END Shorten;

		PROCEDURE Clear*;
		BEGIN
			data[0] := 0X;
			length := 0
		END Clear;

		PROCEDURE GetWriter*() : Streams.Writer;
		VAR w : Streams.Writer;
		BEGIN
			NEW(w, SELF.Add, 256);
			RETURN w
		END GetWriter;

		PROCEDURE GetReader*(): Streams.Reader;
		VAR r: Streams.StringReader;
		BEGIN
			NEW(r, 256);
			r.Set(data^);
			RETURN r
		END GetReader;

		PROCEDURE GetString*(VAR len: LONGINT) : StringType;
		BEGIN
			len := length;
			RETURN data
		END GetString;

		PROCEDURE GetStringCopy*(VAR len: LONGINT): StringType;
		VAR new: StringType;
		BEGIN
			len := length;
			NEW(new,len+1);
			COPY(data^,new^);
			RETURN new
		END GetStringCopy;


	END StringMaker;

	(** scanner reflects the following EBNF
		Symbol 				= String | Token | Number | Keyword | Identifier.
		Token 				=  | '#' | '&' | '(' ['*' any '*' ')'] | ')' | '*'['*'] | '+'['*'] | ',' | '-' | '.' [ '.' | '*' | '/' | '=' | '#' | '>'['='] | '<' ['=']
											  | '/' | ':' ['='] | ';'  | '<' ['=' | '<' ['?'] ] | '=' | '>' [ '=' | '>' ['?']]  
											  | '[' | ']' | '^' | '{' | '|' | '}' | '~' | '\' |  '`' |  '?' ['?'] | '!' ['!']
		Identifier			= Letter {Letter | Digit | '_'}.
		Letter					= 'A' | 'B' | .. | 'Z' | 'a' | 'b' | .. | 'z'.
		Digit						= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' .
		String					= '"' {Character} '"' | "'" {Character} "'".
		Character			= Digit [HexDigit] 'X'.
		Number				= Integer | Real.
		Integer				= Digit {Digit} | Digit {HexDigit} 'H' | '0x' {HexDigit}.
		Real						= Digit {Digit} '.' {Digit} [ScaleFactor].
		ScaleFactor		= ('E' | 'D') ['+' | '-'] digit {digit}.
		HexDigit			= Digit | 'A' | 'B' | 'C' | 'D' | 'E' | 'F'.
	**)

	Scanner* = OBJECT
	VAR

		(* helper state information *)
		source-: StringType;
		reader-: Streams.Reader;   (* source *)
		diagnostics: Diagnostics.Diagnostics;   (* error logging *)

		ch-: CHAR;   (* look-ahead character *)
		position-: LONGINT;   (* current position *)
		line-: LONGINT;

		error-: BOOLEAN;   (* if error occured during scanning *)

		firstIdentifier: BOOLEAN;   (* support of lower vs. upper case keywords  *)
		case-: LONGINT;
		stringWriter: Streams.Writer;
		stringMaker: StringMaker;

		(*
			source: name of the source code for reference in error outputs
			reader: input stream
			position: reference position (offset) of the input stream , for error output
			diagnostics: error output object
		*)
		PROCEDURE & InitializeScanner*( CONST source: ARRAY OF CHAR; reader: Streams.Reader; position: LONGINT; diagnostics: Diagnostics.Diagnostics );
		BEGIN
			NEW(stringMaker,1024);
			stringWriter := stringMaker.GetWriter();
			error := FALSE;
			NEW(SELF.source, Strings.Length(source)+1);
			COPY (source, SELF.source^);
			SELF.reader := reader;
			SELF.diagnostics := diagnostics;
			ch := " ";
			case := Unknown;
			firstIdentifier := TRUE;
			IF reader = NIL THEN ch := EOT ELSE 	GetNextCharacter END;
			IF Trace THEN D.Str( "New scanner  " );   D.Ln;  END;
			SELF.position := position;
			line := 0;
		END InitializeScanner;

		PROCEDURE ResetCase*; (*! needs a better naming ! *)
		BEGIN
			firstIdentifier := TRUE; case := Unknown;
		END ResetCase;

		(** report an error occured during scanning **)
		PROCEDURE ErrorS(CONST msg: ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Error(source^, position, Diagnostics.Invalid, msg)
			END;
			error := TRUE;
		END ErrorS;

		(** report an error occured during scanning **)
		PROCEDURE Error( code: INTEGER );
		VAR errorMessage: ARRAY 256 OF CHAR;
		BEGIN
			IF diagnostics # NIL THEN
				Basic.GetErrorMessage(code,"",errorMessage);
				diagnostics.Error(source^, position, code, errorMessage)
			END;
			error := TRUE;
		END Error;

		(** get next character, end of text results in ch = EOT **)
		PROCEDURE GetNextCharacter*;
		BEGIN
			reader.Char(ch); INC(position);
			IF ch = LF THEN INC(line) END;
			(*
			(* not necessary, as Streams returns 0X if reading failed, but in case Streams.Reader.Char is modified ...  *)
			IF reader.res # Streams.Ok THEN ch := EOT END;
			*)
		END GetNextCharacter;

(*
	The following is an implementation of the KMP algorithm used in order to traverse strings until some pattern occurs.
	It is not necessary for our implementation of string escape sequences, because the first character of the pattern does not occur in the pattern elsewhere
	I found the code useful and keep it here for the time being....

	(* generate a table to be able to quickly search for string containing overlaps - KMP algorithm *)
	PROCEDURE MakeOverlapTable*(CONST pattern: ARRAY OF CHAR; VAR table: ARRAY OF LONGINT);
	VAR i, cnd: LONGINT;
	BEGIN
		ASSERT(pattern[0] # 0X);
		(* if first character did not match: reset search *)
		table[0] := -1;
		(* if second character did not match: compare to first *)
		IF pattern[1] # 0X THEN
			table[1] := 0;
		END;
		(* for all other characters: switch back to previous overlay in pattern *)
		i := 2; cnd := 0;
		WHILE(pattern[i] # 0X) DO
			(* do patterns [i-cnd, i-1] match with pattern[0.. cnd] ? *)
			IF pattern[i-1] = pattern[cnd] THEN
				INC(cnd); table[i] := cnd; INC(i);
			(* no, switch back to last overlap, if possible *)
			ELSIF cnd > 0 THEN cnd := table[cnd]
			(* not possible: restart at beginning *)
			ELSE table[i] := 0; INC(i)
			END;
		END;
	END MakeOverlapTable;

	(* using KMP substring search algorithm consume and reproduce all characters of a string until endString *)
	PROCEDURE GetString(CONST endString: ARRAY OF CHAR);
	VAR escapePos: LONGINT; ech: CHAR; i: LONGINT; table: ARRAY 16 OF LONGINT;
		next: LONGINT;

			PROCEDURE Append(ch :CHAR);
			BEGIN
				IF ch = 0X THEN
					ErrorS("Unexpected end of text in string"); error := TRUE
				ELSE
					stringWriter.Char(ch)
				END;
			END Append;

	BEGIN
		MakeOverlapTable(endString, table);

		(* traverse *)
		escapePos := 0; ech := endString[0];
		GetNextCharacter;
		REPEAT
			IF ch = ech THEN
				INC(escapePos); ech := endString[escapePos];
				GetNextCharacter;
			ELSIF escapePos = 0 THEN (* frequent case *)
				Append(ch); GetNextCharacter;
			ELSE
				(* overlaps ? *)
				next := table[escapePos];
				IF next < 0 THEN next := 0 END;

				(* account for "forgotten" characters *)
				FOR i := 0 TO escapePos-1-next DO
					Append(endString[i]);
				END;
				(* to next overlapping ? *)
				escapePos := table[escapePos];
				(* no overlapping *)
				IF escapePos < 0 THEN
					Append(ch);
					escapePos := 0;
					GetNextCharacter;
				END;
				ech := endString[escapePos];
			END;
		UNTIL (ch = EOT) OR (ech = 0X);

	END GetString;
*)

		(* simple case can be utilized when endString does not contain first character, which is the case for our string convention *)
		PROCEDURE ConsumeStringUntil(CONST endString: ARRAY OF CHAR; useControl: BOOLEAN);
		VAR escapePos: LONGINT; ech: CHAR; i: LONGINT; startPosition: LONGINT;
		CONST
			Control = '\';
			Delimiter = '"';

				PROCEDURE Append(ch :CHAR);
				BEGIN
					IF ch = 0X THEN
						ErrorS("Unexpected end of text in string"); error := TRUE;
					ELSE
						stringWriter.Char(ch)
					END;
				END Append;

		BEGIN
			(* traverse *)
			escapePos := 0; ech := endString[0]; startPosition := position;
			GetNextCharacter;
			REPEAT
				IF ch = ech THEN
					INC(escapePos); ech := endString[escapePos];
					GetNextCharacter;
				ELSIF useControl & (ch = Control) THEN
					GetNextCharacter;
					IF (ch = Control) OR (ch = Delimiter) THEN
						Append(ch)
					ELSIF ch = 'n' THEN
						Append(CR); Append(LF);
					ELSIF ch = 't' THEN
						Append(TAB)
					ELSE
						ErrorS("Unknown control sequence")
					END;
					GetNextCharacter
				ELSIF escapePos = 0 THEN (* frequent case *)
					Append(ch); GetNextCharacter;
				ELSE
					(* account for "forgotten" characters *)
					FOR i := 0 TO escapePos-1 DO
						Append(endString[i]);
					END;
					(* restart *)
					ech := endString[0]; escapePos := 0;
				END;
			UNTIL (ch = EOT) OR (ech = 0X) OR error;
			IF ch = EOT THEN position := startPosition; ErrorS("Unexpected end of text in string") END;
		END ConsumeStringUntil;

		PROCEDURE GetEscapedString(VAR symbol: Symbol);
		VAR endString: ARRAY 4 OF CHAR; escape: CHAR;
		BEGIN
			(* backslash already consumed *)
			stringMaker.Clear;
			IF ch = '"' THEN
				escape := 0X;
			ELSE
				escape := ch; GetNextCharacter;
			END;
			ASSERT((ch = '"') OR (ch = "'"));
			REPEAT
				IF escape # 0X THEN
					endString[0] := ch;
					endString[1] := escape;
					endString[2] := '\';
					endString[3] := 0X;
				ELSE
					endString[0] := ch;
					endString[1] := '\';
					endString[2] := 0X;
				END;
				ConsumeStringUntil(endString, escape = 0X);
			UNTIL TRUE;
			stringWriter.Char(0X);
			stringWriter.Update;
			symbol.string := stringMaker.GetStringCopy(symbol.stringLength);
		END GetEscapedString;


		(** get a string starting at current position
			string = {'"' {Character} '"'} | {"'" {Character} "'"}.
		**)
		(* multiline indicates that a string may occupy more than one lines, either concatenated or via multi-strings " "  " "
		*)
		PROCEDURE GetString(VAR symbol: Symbol; multiLine, multiString, useControl: BOOLEAN);
		VAR och: CHAR; error: BOOLEAN; done: BOOLEAN;
		CONST control = '\';

			PROCEDURE Append(ch :CHAR);
			BEGIN
				IF ch = 0X THEN
					ErrorS("Unexpected end of text in string"); error := TRUE
				ELSE
					stringWriter.Char(ch)
				END;
			END Append;

		BEGIN
			stringMaker.Clear;
			och := ch; error := FALSE;
			REPEAT
				LOOP
					IF error THEN EXIT END;
					GetNextCharacter;
					IF (ch = och) OR (ch = EOT) THEN EXIT END;
					IF useControl & (ch = control) THEN
						GetNextCharacter;
						IF (ch = control) OR (ch = och) THEN
							Append(ch)
						ELSIF ch = 'n' THEN
							Append(CR); Append(LF);
						ELSIF ch = 't' THEN
							Append(TAB)
						ELSE
							ErrorS("Unknown control sequence")
						END;
					ELSE
						IF ~multiLine & (ch < " ") THEN Error( Basic.StringIllegalCharacter ); EXIT END;
						Append(ch)
					END;
				END;
				IF ch = EOT THEN
					ErrorS("Unexpected end of text in string")
				ELSE
					GetNextCharacter;
					IF multiString THEN SkipBlanks END;
				END;
			UNTIL ~multiString OR (ch # och);
			stringWriter.Char(0X);
			stringWriter.Update;
			symbol.string := stringMaker.GetStringCopy(symbol.stringLength);
		END GetString;

		(**
			Identifier = Letter {Letter | Digit | '_'} .
			Letter = 'A' | 'B' | .. |  'Z' | 'a' | 'b' |  .. | 'z' .
			Digit = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'.

			'_' is the underscore character
		**)
		PROCEDURE GetIdentifier( VAR symbol: Symbol );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			REPEAT symbol.identifierString[i] := ch; INC( i );  GetNextCharacter UNTIL reservedCharacter[ORD( ch )] OR (i = MaxIdentifierLength);
			IF i = MaxIdentifierLength THEN Error( Basic.IdentifierTooLong );  DEC( i ) END;
			symbol.identifierString[i] := 0X;
			StringPool.GetIndex(symbol.identifierString, symbol.identifier);
		END GetIdentifier;

		(**
		Number       =  Integer | Real.
		Integer      =  Digit {Digit} | Digit {HexDigit} 'H' | '0x' {HexDigit}.
		Real         =  Digit {Digit} '.' {Digit} [ScaleFactor].
		ScaleFactor  =  ('E' | 'D') ['+' | '-'] digit {digit}.
		HexDigit     =  Digit | 'A' | 'B' | 'C' | 'D' | 'E' | 'F'.
		Digit = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' .
		**)
		PROCEDURE GetNumber(VAR symbol: Symbol): Token;
		VAR i, nextInt, m, n, d, e, si: LONGINT;
			dig: ARRAY 24 OF CHAR;
			f: LONGREAL;  expCh: CHAR;  neg, long: BOOLEAN;
			result: Token;
			hugeint, tenh, number: HUGEINT;
			digits: LONGINT;

			(** 10^e **)
			PROCEDURE Ten( e: LONGINT ): LONGREAL;
			VAR x, p: LONGREAL;
			BEGIN
				x := 1;  p := 10;
				WHILE e > 0 DO
					IF ODD( e ) THEN x := x * p END;
					e := e DIV 2;
					IF e > 0 THEN p := p * p END  (* prevent overflow *)
				END;
				RETURN x
			END Ten;

			(** return decimal number associated to character ch , error if none **)
			PROCEDURE Decimal( ch: CHAR ): LONGINT;
			BEGIN  (* ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") *)
				IF ch <= "9" THEN RETURN ORD( ch ) - ORD( "0" ) ELSE Error( Basic.NumberIllegalCharacter );  RETURN 0 END
			END Decimal;

			(** return hexadecimal number associated to character ch, error if none **)
			PROCEDURE Hexadecimal( ch: CHAR ): LONGINT;
			BEGIN
				IF ch <= "9" THEN RETURN ORD( ch ) - ORD( "0" )
				ELSIF ch <= "F" THEN RETURN ORD( ch ) - ORD( "A" ) + 10
				ELSIF ch <= "f" THEN RETURN ORD( ch ) - ORD( "a" ) + 10
				ELSE Error( Basic.NumberIllegalCharacter );  RETURN 0
				END
			END Hexadecimal;

		BEGIN  (* ("0" <= ch) & (ch <= "9") *)
			result := Number;
			i := 0;  m := 0;  n := 0;  d := 0;  si := 0;  long := FALSE;
			
			IF (ch = "0") & (reader.Peek() = "x") THEN (* hex number *)
				digits := 0;
				GetNextCharacter; GetNextCharacter;
				WHILE (ch >= "0") & (ch <= "9") OR (ch >= "a") & (ch <="f") OR (ch >= "A") & (ch <= "F") DO
					number := number * 10H + Hexadecimal(ch);
					INC(digits);
					GetNextCharacter;
				END;
				symbol.hugeint := number;
				symbol.integer := SHORT(number);
				IF digits > MaxHexDigits THEN
					symbol.numberType := Hugeint
				ELSE
					symbol.numberType := Integer
				END;
				RETURN result;
			END;
			
			LOOP  (* read mantissa *)
				IF ("0" <= ch) & (ch <= "9") OR (d = 0) & ("A" <= ch) & (ch <= "F") THEN
					IF (m > 0) OR (ch # "0") THEN  (* ignore leading zeros *)
						IF n < LEN( dig ) THEN dig[n] := ch;  INC( n ) END;
						INC( m )
					END;
					symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;  INC( i )
				ELSIF ch = "." THEN
					symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;
					IF ch = "." THEN ch := Ellipsis;  EXIT
					ELSIF d = 0 THEN  (* i > 0 *) d := i
					ELSE Error( Basic.NumberIllegalCharacter )
					END
				ELSE EXIT
				END
			END;   (* 0 <= n <= m <= i, 0 <= d <= i *)
			IF d = 0 THEN  (* integer *)
				IF n = m THEN
					symbol.integer := 0;  i := 0;  symbol.hugeint := 0;
					IF ch = "X" THEN  (* character *)
						symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;  result := Character;
						IF  (n <= 2) THEN
							WHILE i < n DO symbol.integer := symbol.integer * 10H + Hexadecimal( dig[i] );  INC( i ) END;
							symbol.character := CHR(symbol.integer);
						ELSE Error( Basic.NumberTooLarge )
						END
					ELSIF ch = "H" THEN  (* hexadecimal *)
						symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;
						IF (n < MaxHexDigits) OR (n=MaxHexDigits) & (dig[0] <= "7")  THEN (* otherwise the positive (!) number is not in the range of longints *)
							symbol.numberType := Integer;
							(* IF (n = MaxHexDigits) & (dig[0] > "7") THEN  (* prevent overflow *) symbol.integer := -1 END;  *)
							WHILE i < n DO symbol.integer := symbol.integer * 10H + Hexadecimal( dig[i] );  INC( i ) END;
							symbol.hugeint := symbol.integer;
						ELSIF n <= MaxHugeHexDigits THEN
							symbol.numberType := Hugeint;
							IF (n = MaxHugeHexDigits) & (dig[0] > "7") THEN  (* prevent overflow *) symbol.hugeint := -1 END;
							WHILE i < n DO symbol.hugeint := Hexadecimal( dig[i] ) + symbol.hugeint * 10H; INC( i ) END;
							symbol.integer :=SHORT(symbol.hugeint);
						ELSE
							symbol.numberType := Hugeint; (* to make parser able to go on *)
							Error( Basic.NumberTooLarge )
						END
					ELSE  (* decimal *)
						symbol.numberType := Integer;
						WHILE (i < n) & ~long  DO
							d := Decimal( dig[i] );  INC( i );
							IF symbol.integer >= MAX(LONGINT) DIV 10 THEN (* multiplication overflow *)long := TRUE END;
							nextInt := symbol.integer*10+d;
							IF nextInt >=0 THEN symbol.integer := nextInt ELSE (* overflow *) long := TRUE END;
						END;
						IF long THEN
							i := 0; (* restart computation , artificial limit because of compiler problems with hugeint *)
							hugeint := 0;
							tenh := 10; (* compiler does not like constants here ! *)
							symbol.numberType := Hugeint;
							WHILE i < n DO
								d := Decimal( dig[i] );  INC( i );
								IF hugeint >= MAX(HUGEINT) DIV 10 THEN Error( Basic.NumberTooLarge) END;
								hugeint := hugeint * tenh + d;
								IF hugeint < 0 THEN Error( Basic.NumberTooLarge ) END
							END;
							symbol.hugeint := hugeint;
							symbol.integer := SHORT(symbol.hugeint);
						ELSE
							symbol.hugeint := symbol.integer;
						END
					END
				ELSE
					symbol.numberType := Hugeint;
					Error( Basic.NumberTooLarge )
				END
			ELSE  (* fraction *)
				f := 0;  e := 0;  expCh := "E";
				WHILE n > 0 DO  (* 0 <= f < 1 *) DEC( n );  f := (Decimal( dig[n] ) + f) / 10 END;
				IF (ch = "E") OR (ch = "D") THEN
					expCh := ch;  symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;  neg := FALSE;
					IF ch = "-" THEN neg := TRUE;  symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter
					ELSIF ch = "+" THEN symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter
					END;
					IF ("0" <= ch) & (ch <= "9") THEN
						REPEAT
							n := Decimal( ch );  symbol.identifierString[si] := ch;  INC( si );  GetNextCharacter;
							IF e <= (MAX( INTEGER ) - n) DIV 10 THEN e := e * 10 + n ELSE Error( Basic.NumberTooLarge ) END
						UNTIL (ch < "0") OR ("9" < ch);
						IF neg THEN e := -e END
					ELSE Error( Basic.NumberIllegalCharacter )
					END
				END;
				DEC( e, i - d - m );   (* decimal point shift *)
				IF expCh = "E" THEN
					symbol.numberType := Real;
					IF (1 - MaxRealExponent < e) & (e <= MaxRealExponent) THEN
						IF e < 0 THEN symbol.real :=  f / Ten( -e ) ELSE symbol.real := f * Ten( e )  END
					ELSE Error( Basic.NumberTooLarge )
					END
				ELSE
					symbol.numberType := Longreal;
					IF (1 - MaxLongrealExponent < e) & (e <= MaxLongrealExponent) THEN
						IF e < 0 THEN symbol.real := f / Ten( -e ) ELSE symbol.real := f * Ten( e ) END
					ELSE Error( Basic.NumberTooLarge )
					END
				END
			END;
			symbol.identifierString[si] := 0X;
			RETURN result;
		END GetNumber;

		(** read / skip a comment **)
		PROCEDURE ReadComment(VAR symbol: Symbol);
		VAR level: LONGINT;
		BEGIN
			stringMaker.Clear;
			level := 1;
			WHILE (level > 0) & (ch # EOT) DO
				IF ch = "(" THEN
					stringWriter.Char(ch);
					GetNextCharacter;
					IF ch = "*" THEN INC(level); stringWriter.Char(ch); GetNextCharacter;  END;
				ELSIF ch = "*" THEN
					stringWriter.Char(ch);
					GetNextCharacter;
					IF ch =")" THEN DEC(level); stringWriter.Char(ch); GetNextCharacter;  END;
				ELSE
					stringWriter.Char(ch);
					GetNextCharacter;
				END;
			END;

			IF level > 0 THEN
				Error(Basic.CommentNotClosed)
			END;

			stringWriter.Char(0X);
			stringWriter.Update;
			stringMaker.Shorten(2); (* remove comment closing *)
			symbol.token := Comment;
			symbol.string := stringMaker.GetString(symbol.stringLength);
		END ReadComment;

		PROCEDURE SkipToEndOfCode*(VAR startPos,endPos: LONGINT; VAR symbol: Symbol): Token;
		VAR s: LONGINT;
		BEGIN
			ASSERT(case # Unknown);
			stringMaker.Clear;
			startPos := symbol.end;
			s := symbol.token;
			WHILE (s # EndOfText) & (s # End) & (s # With) DO
				symbol.start := position;
				endPos := position;
				CASE ch OF
				'A' .. 'Z','a'..'z': s := Identifier;
					GetIdentifier(symbol);
					IF (case=Uppercase) & (symbol.identifierString = "END") OR (case=Lowercase) & (symbol.identifierString = "end") THEN
						s := End
					ELSIF (case = Uppercase) & (symbol.identifierString = "WITH") OR (case = Lowercase) & (symbol.identifierString = "with") THEN
						s := With
					ELSE
						stringWriter.String(symbol.identifierString);
					END;
				ELSE
					stringWriter.Char(ch);
					GetNextCharacter;
				END;
				symbol.end := position;
			END;
			stringWriter.Update;
			symbol.string := stringMaker.GetStringCopy(symbol.stringLength);
			symbol.token := s;

			IF Trace THEN
				D.String("skip to end: "); D.Int(startPos,1); D.String(","); D.Int(endPos,1); D.Ln;
				OutSymbol(D.Log,symbol); D.Ln;
			END;
			RETURN s
		END SkipToEndOfCode;

		PROCEDURE SkipBlanks;
		BEGIN
			WHILE ch <= " " DO  (*ignore control characters*)
				IF ch = EOT THEN
					IF Trace THEN D.String("EOT"); D.Ln; END;
					RETURN
				ELSE GetNextCharacter
				END
			END;
		END SkipBlanks;

		(** get next symbol **)
		PROCEDURE GetNextSymbol*(VAR symbol: Symbol ): BOOLEAN;
		VAR s,token: LONGINT;
		BEGIN
			SkipBlanks;
			symbol.start := position; symbol.line := line;
			stringMaker.Clear;
			CASE ch OF  (* ch > " " *)
			EOT: s := EndOfText
			| DoubleQuote:
					s := String; GetString(symbol,TRUE, TRUE, FALSE);
			| SingleQuote:
					s := String; GetString(symbol,FALSE, FALSE,FALSE);
					(* to be replaced by:
					s := Character; GetString(symbol);
					IF symbol.stringLength #2 THEN  (* stringlength = 1 for empty string '' *)
						Error(Basic.IllegalCharacterValue)
					END;
					*)
			| '#':     s := Unequal;  GetNextCharacter
			| '&':     s := And;  GetNextCharacter
			| '(':     GetNextCharacter;
					IF ch = '*' THEN GetNextCharacter; ReadComment(symbol);  s := Comment; ELSE s := LeftParenthesis END
			| ')':     s := RightParenthesis;  GetNextCharacter
			| '*':    GetNextCharacter; IF ch = '*' THEN GetNextCharacter;  s := TimesTimes ELSE s := Times END
			| '+':    GetNextCharacter; IF ch = '*' THEN GetNextCharacter; s := PlusTimes ELSE s := Plus END
			| ',':     s := Comma;  GetNextCharacter
			| '-':    s := Minus;  GetNextCharacter
			| '.':     GetNextCharacter;
					IF ch = '.' THEN GetNextCharacter;  s := Upto;
					ELSIF ch = '*' THEN GetNextCharacter;  s := DotTimes;
					ELSIF ch = '/' THEN 	GetNextCharacter;  s := DotSlash;
					ELSIF ch='=' THEN GetNextCharacter; s := DotEqual;
					ELSIF ch='#' THEN GetNextCharacter; s := DotUnequal;
					ELSIF ch='>' THEN GetNextCharacter;
						IF ch='=' THEN s := DotGreaterEqual; GetNextCharacter
						ELSE s := DotGreater;
						END
					ELSIF ch='<' THEN GetNextCharacter;
						IF ch='=' THEN s := DotLessEqual; GetNextCharacter
						ELSE s := DotLess;
						END
					ELSE s := Period END
			| '/':     s := Slash;  GetNextCharacter
			| '0'..'9':   s := GetNumber(symbol);
			| ':':     GetNextCharacter;
					IF ch = '=' THEN GetNextCharacter;  s := Becomes  ELSE s := Colon END
			| ';':     s := Semicolon;  GetNextCharacter
			| '<':     GetNextCharacter;
					IF ch = '=' THEN GetNextCharacter;  s := LessEqual 
					ELSIF ch ='<' THEN GetNextCharacter; 
						IF ch ='?' THEN GetNextCharacter; s := LessLessQ
						ELSE s := LessLess
						END;
					ELSE s := Less;  
					END
			| '=':     s := Equal;  GetNextCharacter
			| '>':     GetNextCharacter;
					IF ch = '=' THEN GetNextCharacter;  s := GreaterEqual 
					ELSIF ch ='>' THEN GetNextCharacter; 
						IF ch ='?' THEN GetNextCharacter; s := GreaterGreaterQ
						ELSE s := GreaterGreater
						END;
					ELSE s := Greater;  END
			| '[':     s := LeftBracket;  GetNextCharacter
			| ']':     s := RightBracket;  GetNextCharacter
			| '^':     s := Arrow;  GetNextCharacter
			| '{':     s := LeftBrace;  GetNextCharacter
			| '|':     s := Bar;  GetNextCharacter
			| '}':     s := RightBrace;  GetNextCharacter
			| '~':     s := Not;  GetNextCharacter
			| '\':     s := Backslash;  GetNextCharacter;
					IF ch = DoubleQuote THEN
						s := String;
						GetEscapedString(symbol);
						(*
						GetString(symbol, TRUE, TRUE, TRUE)
						*)
					ELSIF (ch > " ") & (reader.Peek() = DoubleQuote) THEN
						s := String;
						GetEscapedString(symbol);
					END;
			| '`':	s := Transpose; GetNextCharacter
			| '?': 	s := Questionmark; GetNextCharacter; IF ch = '?' THEN s := Questionmarks; GetNextCharacter END;
			| '!':     s := ExclamationMark; GetNextCharacter; IF ch = '!' THEN s := ExclamationMarks; GetNextCharacter END;
			| Ellipsis:
					s := Upto;  GetNextCharacter
			| 'A'..'Z': s := Identifier; GetIdentifier( symbol );
					IF (case=Uppercase) OR (case=Unknown) THEN
						token := keywordsUpper.IndexByIdentifier(symbol.identifier);
						IF  (token >= 0) THEN s := token END;
						IF (s = Module) OR (s=CellNet) THEN case := Uppercase END;
					END;
			| 'a'..'z': s := Identifier; GetIdentifier( symbol);
					IF (case = Lowercase) OR (case=Unknown) THEN
						token := keywordsLower.IndexByIdentifier(symbol.identifier);
						IF  (token >= 0) THEN s := token END;
						IF (s = Module) OR (s=CellNet) THEN case := Lowercase END;
					END;
					IF firstIdentifier & (s # Module) & (s # CellNet) THEN case := Uppercase; s := Identifier END;
			ELSE s := Identifier;  GetIdentifier( symbol );
			END;
			firstIdentifier := FALSE;

			symbol.token := s;
			symbol.end := position;

			IF Trace THEN OutSymbol(D.Log,symbol); D.Ln; END;

			RETURN ~error
		END GetNextSymbol;

		PROCEDURE ResetError*();
		BEGIN error := FALSE
		END ResetError;

		(** set the diagnostics mode of the scanner (diagnostics = NIL ==> no report) and reset the error state
			intended for silent symbol peeeking after the end of a module *)
		PROCEDURE ResetErrorDiagnostics*(VAR diagnostics: Diagnostics.Diagnostics);
		VAR b: BOOLEAN; d: Diagnostics.Diagnostics;
		BEGIN
			error := FALSE;
			d := SELF.diagnostics; SELF.diagnostics := diagnostics; diagnostics := d;
		END ResetErrorDiagnostics;

	END Scanner;

	Context*=RECORD
		position, readerPosition : LONGINT;
		ch: CHAR;
	END;

	(** assembler scanner reflects the following EBNF
		Symbol 			= String | Token | Number | Identifier.
		Token 			= '\' | '#' | '(' ['*' any '*' ')'] | ')' | CR [LF] | LF | '*' | '+' | ',' | '-' | '~' | '.' | '/' | '%' | ':' | ';' | '=' | '[' | ']' | '{' | '}' | '!' | '^' | '$'['$'].
		String				= '"' {Character} '"' | "'" {Character} "'".
		Identifier		= '@' | Letter {'@' | '.' | Letter | Digit | '_'} .
		Letter 				= 'A' | 'B' | .. |  'Z' | 'a' | 'b' |  .. | 'z' .
		Digit 				= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'.
		Number			= Integer | Real.
		Character		= Digit [HexDigit] 'X'.
		Integer			=  Digit {Digit} | Digit {HexDigit} 'H' | '0x' {HexDigit}.
		Real					= Digit {Digit} '.' {Digit} [ScaleFactor].
		ScaleFactor	= ('E' | 'D') ['+' | '-'] digit {digit}.
		HexDigit		= Digit | 'A' | 'B' | 'C' | 'D' | 'E' | 'F'.
	**)

	AssemblerScanner* = OBJECT (Scanner) (*!  move to different module? unify with compiler scanner? *)
	VAR
		startContext-: Context;

		PROCEDURE &InitAssemblerScanner*( CONST source: ARRAY OF CHAR; reader: Streams.Reader; position: LONGINT; diagnostics: Diagnostics.Diagnostics );
		BEGIN
			InitializeScanner(source,reader,position,diagnostics);
			GetContext(startContext);
		END InitAssemblerScanner;

		PROCEDURE GetContext*(VAR context: Context);
		BEGIN
			context.ch := ch;
			context.position := position;
			context.readerPosition := reader.Pos();
		END GetContext;

		PROCEDURE SetContext*(CONST context: Context);
		BEGIN
			reader.SetPos(context.readerPosition);
			ch := context.ch;
			position := context.position;
		END SetContext;


		PROCEDURE SkipToEndOfLine*;
		BEGIN
			WHILE (ch # EOT) & (ch # CR) & (ch # LF) DO
				GetNextCharacter
			END;
		END SkipToEndOfLine;

		(**
			note: in contrast to a regular identifier, an assembler scanner identifier may also contain periods and the '@'-symbol

			Identifier = '@' | Letter {'@' | '.' | Letter | Digit | '_'} .
			Letter = 'A' | 'B' | .. |  'Z' | 'a' | 'b' |  .. | 'z' .
			Digit = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'.

			'_' is the underscore character
		**)
		PROCEDURE GetIdentifier( VAR symbol: Symbol );
		VAR
			i: LONGINT;

			PROCEDURE CharacterIsAllowed(character: CHAR): BOOLEAN;
			BEGIN
				CASE character OF
				| 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '@', '.', '_': RETURN TRUE
				ELSE RETURN FALSE
				END;
			END CharacterIsAllowed;
		BEGIN
			i := 0;
			REPEAT
				symbol.identifierString[i] := ch; INC( i );  GetNextCharacter
			UNTIL ~CharacterIsAllowed(ch) OR (i = MaxIdentifierLength);

			IF i = MaxIdentifierLength THEN Error( Basic.IdentifierTooLong );  DEC( i ) END;
			symbol.identifierString[i] := 0X;
		END GetIdentifier;

		PROCEDURE GetNumber(VAR symbol: Symbol): Token;
		VAR number: HUGEINT; result: Token; digits: LONGINT;

			(** return hexadecimal number associated to character ch, error if none **)
			PROCEDURE Hexadecimal( ch: CHAR ): LONGINT;
			BEGIN
				IF (ch >= "0") & (ch <= "9") THEN RETURN ORD( ch ) - ORD( "0" )
				ELSIF (ch >= "a") & (ch <= "f") THEN RETURN ORD( ch ) - ORD( "a" ) + 10
				ELSE Error( Basic.NumberIllegalCharacter );  RETURN 0
				END
			END Hexadecimal;

		BEGIN
			result := Number;
			IF (ch = "0") THEN
				IF reader.Peek() = "x" THEN (* hex number *)
					digits := 0;
					GetNextCharacter; GetNextCharacter;
					WHILE (ch >= "0") & (ch <= "9") OR (ch >= "a") & (ch <="f") DO
						number := number * 10H + Hexadecimal(ch);
						INC(digits);
						GetNextCharacter;
					END;
					symbol.hugeint := number;
					symbol.integer := SHORT(number);
					IF digits > MaxHexDigits THEN
						symbol.numberType := Hugeint
					ELSE
						symbol.numberType := Integer
					END;
				ELSIF reader.Peek() = "b" THEN (* binary number *)
					digits := 0;
					GetNextCharacter; GetNextCharacter;
					WHILE (ch >= "0") & (ch <= "1") DO
						number := number * 2;
						INC(digits);
						IF ch = "1" THEN INC(number) END;
						GetNextCharacter;
					END;
					symbol.hugeint := number;
					symbol.integer := SHORT(number);
					IF digits > 32 THEN
						symbol.numberType := Hugeint
					ELSE
						symbol.numberType := Integer
					END;
				ELSE RETURN GetNumber^(symbol)
				END;
			ELSE RETURN GetNumber^(symbol)
			END;
			RETURN result
		END GetNumber;

		(** get next symbol **)
		PROCEDURE GetNextSymbol*(VAR symbol: Symbol ): BOOLEAN;
		VAR s: LONGINT;

			PROCEDURE SkipBlanks;
			BEGIN
				WHILE (ch <= ' ') & (ch # CR) & (ch # LF) & (ch # EOT) DO  (* ignore control characters except line feeds *)
					GetNextCharacter
				END;
			END SkipBlanks;

		BEGIN
			REPEAT
				SkipBlanks;
				symbol.start := position; symbol.line := line;
				CASE ch OF  (* ch > ' ' *)
				| EOT: 	s := EndOfText;
				| DoubleQuote:
						s := String; GetString(symbol, TRUE, FALSE, TRUE);
				| SingleQuote:
						s := Character; GetString(symbol, FALSE, FALSE, FALSE); symbol.character := symbol.string[0];
						IF symbol.stringLength #2 THEN  (* stringlength = 1 for empty string '' *)
							Error(Basic.IllegalCharacterValue)
						END;
				| '\':     s := Backslash;  GetNextCharacter;
						IF ch = DoubleQuote THEN s := String; GetString(symbol, FALSE, FALSE, TRUE) END;
				| '#':     s := Unequal;  GetNextCharacter; (* for the ARM assembler *)
				| '(': GetNextCharacter;
						IF ch = '*' THEN GetNextCharacter; ReadComment(symbol);  s := Comment; ELSE s := LeftParenthesis END
				| ')':     s := RightParenthesis;  GetNextCharacter
				| CR: GetNextCharacter; s := Ln;IF ch = LF THEN GetNextCharacter END;
				| LF: GetNextCharacter; s := Ln;
				| '*':    s := Times; GetNextCharacter;
				| '+':    s := Plus ; GetNextCharacter;
				| ',':     s := Comma;  GetNextCharacter
				| '-':    s := Minus;  GetNextCharacter
				| '~':    s := Not;  GetNextCharacter
				| '.':     s:= Period; GetNextCharacter
				| '/':     s := Div;  GetNextCharacter
				| '%':	s := Mod; GetNextCharacter
				| '0'..'9':   s := GetNumber(symbol);
				| ':':     s := Colon; GetNextCharacter;
				| ';':    s := Comment; SkipToEndOfLine;
				| '=':     s := Equal;  GetNextCharacter
				| '[':     s := LeftBracket;  GetNextCharacter
				| ']':     s := RightBracket;  GetNextCharacter
				| '{':     s := LeftBrace;  GetNextCharacter
				| '}':     s := RightBrace;  GetNextCharacter
				| '!':     s := ExclamationMark; GetNextCharacter; 
				| '^':     s := Arrow; GetNextCharacter; 

				| 'A'..'Z': s := Identifier; GetIdentifier( symbol );
				| 'a'..'z': s := Identifier; GetIdentifier( symbol);
				| '@':     s := Identifier; GetIdentifier( symbol); (* the '@'-symbol initiates an assembly scanner identifier *)
				| '$': GetNextCharacter;
					IF ch = '$' THEN s := PCOffset; GetNextCharacter ELSE s := PC; END
				ELSE s := None; GetNextCharacter;
				END;
				symbol.end := position;
			UNTIL s # Comment;

			symbol.token := s;

			IF Trace THEN D.Ln;  D.Str( "Scan at " );  D.Int( symbol.start,1 );  D.Str( ": " );  OutSymbol(D.Log,symbol); D.Update;  END;
			RETURN ~error
		END GetNextSymbol;

	END AssemblerScanner;


	VAR
		reservedCharacter: ARRAY 256 OF BOOLEAN;
		tokens-: ARRAY EndOfText+1 OF Keyword;
		keywordsLower, keywordsUpper: KeywordTable;


	(** return a new scanner on a stream, error output via diagnostics  **)
	PROCEDURE NewScanner*( CONST source: ARRAY OF CHAR; reader: Streams.Reader; position: LONGINT; diagnostics: Diagnostics.Diagnostics ): Scanner;
	VAR s: Scanner;
	BEGIN
		NEW( s, source, reader, position, diagnostics );  RETURN s;
	END NewScanner;

	PROCEDURE NewAssemblerScanner*( CONST source: ARRAY OF CHAR; reader: Streams.Reader; position: LONGINT; diagnostics: Diagnostics.Diagnostics ): AssemblerScanner;
	VAR s: AssemblerScanner;
	BEGIN
		NEW( s, source, reader, position, diagnostics );  RETURN s;
	END NewAssemblerScanner;

	PROCEDURE SymbolToString*(CONST symbol: Symbol; case: LONGINT; VAR str: ARRAY OF CHAR);
	VAR id: StringPool.Index;
	BEGIN
		CASE symbol.token OF
		Identifier, Number: COPY(symbol.identifierString, str)
		| String, Comment: ASSERT(LEN(str) >= LEN(symbol.string^)); COPY(symbol.string^, str);
		ELSE
			GetKeyword(case, symbol.token, id);
			IF id < 0 THEN str := "" ELSE StringPool.GetString(id, str) END;
		END;
	END SymbolToString;

	(** debugging output **)
	PROCEDURE OutSymbol*(w: Streams.Writer; CONST symbol: Symbol);
	VAR str: ARRAY 256 OF CHAR;
	BEGIN
		w.Int(symbol.start,1); w.String("-");w.Int(symbol.end,1); w.String(":");
		w.String(tokens[symbol.token]);
		IF symbol.token= Number THEN
			CASE symbol.numberType OF
				Integer: w.String("(integer)")
				|Hugeint: w.String("(hugeint)")
				|Real: w.String("(real)")
				|Longreal: w.String("(longreal)")
			END;
		END;
		IF symbol.token = String THEN
			w.String(":"); w.Char('"'); w.String(symbol.string^); w.Char('"');
		ELSIF symbol.token = Comment THEN
			w.String("(*"); w.String(symbol.string^); w.String("*)");
		ELSE
			SymbolToString(symbol, Uppercase, str); w.String(": "); w.String(str);
		END
	END OutSymbol;

	(** reserved characters are the characters that may not occur within an identifier **)
	PROCEDURE InitReservedCharacters;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( reservedCharacter ) - 1 DO
			CASE CHR(i) OF
				| 'a' .. 'z', 'A' .. 'Z': reservedCharacter[i] := FALSE;
				| '0'..'9': reservedCharacter[i] := FALSE;
				| '_': reservedCharacter[i] := FALSE
			ELSE
				reservedCharacter[i] := TRUE
			END;
		END;
	END InitReservedCharacters;

	(* get keyword by token *)
	PROCEDURE GetKeyword*(case:LONGINT; token: LONGINT; VAR identifier: IdentifierType);
	BEGIN
		IF case = Uppercase THEN
			keywordsUpper.IdentifierByIndex(token,identifier);
		ELSE ASSERT(case=Lowercase);
			keywordsLower.IdentifierByIndex(token,identifier);
		END;
	END GetKeyword;

	PROCEDURE InitTokens;
	VAR i: LONGINT;
	BEGIN
		tokens[None] := "None";
		tokens[Equal] := "Equal";
		tokens[DotEqual] := "DotEqual";
		tokens[Unequal] := "Unequal";
		tokens[DotUnequal] := "DotUnequal";
		tokens[Less] := "Less";
		tokens[DotLess] := "DotLess";
		tokens[LessEqual] := "LessEqual";
		tokens[DotLessEqual] := "DotLessEqual";
		tokens[Greater] := "Greater";
		tokens[DotGreater] := "DotGreater";
		tokens[GreaterEqual] := "GreaterEqual";
		tokens[DotGreaterEqual] := "DotGreaterEqual";
		tokens[LessLessQ] := "LessLessQ";
		tokens[GreaterGreaterQ] := "GreaterGreaterQ";
		tokens[In] := "In";
		tokens[Is] := "Is";
		tokens[Times] := "Times";
		tokens[TimesTimes] := "TimesTimes";
		tokens[DotTimes] := "DotTimes";
		tokens[PlusTimes] := "PlusTimes";
		tokens[Slash] := "Slash";
		tokens[Backslash] := "Backslash";
		tokens[DotSlash] := "DotSlash";
		tokens[Div] := "Div";
		tokens[Mod] := "Mod";
		tokens[And] := "And";
		tokens[Or] := "Or";
		tokens[Plus] := "Plus";
		tokens[Minus] := "Minus";
		tokens[Not] := "Not";
		tokens[LeftParenthesis] := "LeftParenthesis";
		tokens[LeftBracket] := "LeftBracket";
		tokens[LeftBrace] := "LeftBrace";
		tokens[Number] := "Number";
		tokens[Character] := "Character";
		tokens[String] := "String";
		tokens[Nil] := "Nil";
		tokens[Imag] := "Imag";
		tokens[True] := "True";
		tokens[False] := "False";
		tokens[Self] := "Self";
		tokens[Result] := "Result";
		tokens[Identifier] := "Identifier";
		tokens[If] := "If";
		tokens[Case] := "Case";
		tokens[While] := "While";
		tokens[Repeat] := "Repeat";
		tokens[For] := "For";
		tokens[Loop] := "Loop";
		tokens[With] := "With";
		tokens[Exit] := "Exit";
		tokens[Await] := "Await";
		tokens[Return] := "Return";
		tokens[Begin] := "Begin";
		tokens[Semicolon] := "Semicolon";
		tokens[Transpose] := "Transpose";
		tokens[RightBrace] := "RightBrace";
		tokens[RightBracket] := "RightBracket";
		tokens[RightParenthesis] := "RightParenthesis";
		tokens[Questionmark] := "Questionmark";
		tokens[ExclamationMark] := "ExclamationMark";
		tokens[Questionmarks] := "Questionmarks";
		tokens[ExclamationMarks] := "ExclamationMarks";
		tokens[LessLess] := "LessLess";
		tokens[GreaterGreater] := "GreaterGreater";
		tokens[Upto] := "Upto";
		tokens[Arrow] := "Arrow";
		tokens[Period] := "Period";
		tokens[Comma] := "Comma";
		tokens[Colon] := "Colon";
		tokens[Of] := "Of";
		tokens[Then] := "Then";
		tokens[Do] := "Do";
		tokens[To] := "To";
		tokens[By] := "By";
		tokens[Becomes] := "Becomes";
		tokens[Bar] := "Bar";
		tokens[End] := "End";
		tokens[Else] := "Else";
		tokens[Elsif] := "Elsif";
		tokens[Extern] := "Extern";
		tokens[Until] := "Until";
		tokens[Finally] := "Finally";
		tokens[Code] := "Code";
		tokens[Const] := "Const";
		tokens[Type] := "Type";
		tokens[Var] := "Var";
		tokens[Out] := "Out";
		tokens[Procedure] := "Procedure";
		tokens[Operator] := "Operator";
		tokens[Import] := "Import";
		tokens[Definition] := "Definition";
		tokens[Module] := "Module";
		tokens[Cell] := "Cell";
		tokens[CellNet] := "CellNet";
		tokens[Array] := "Array";
		tokens[Object] := "Object";
		tokens[Record] := "Record";
		tokens[Pointer] := "Pointer";
		tokens[Enum] := "Enum";
		tokens[Port] := "Port";
		tokens[Address] := "Address";
		tokens[Alias] := "Alias";
		tokens[Size] := "Size";
		tokens[Ln] := "Ln";
		tokens[PC] := "PC";
		tokens[PCOffset] := "PCOffset";
		tokens[Shortint] := "Shortint";
		tokens[Integer] := "Integer";
		tokens[Longint] := "Longint";
		tokens[Hugeint] := "Hugeint";
		tokens[Real] := "Real";
		tokens[Longreal] := "Longreal";
		tokens[Comment] := "Comment";
		tokens[EndOfText] := "EndOfText";
		FOR i := 0 TO EndOfText DO ASSERT(tokens[i] # "") END;
	END InitTokens;

	(** enter keywords in the list of keywords (both upper- and lowercase)  **)
	PROCEDURE InitKeywords;

		PROCEDURE Upper(CONST source: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR);
		VAR c: CHAR; i: LONGINT;
		BEGIN
			i := 0;
			REPEAT
				c := source[i];
				IF (c >= 'a') & (c<= 'z') THEN c :=  CHR(ORD(c)-ORD('a')+ORD('A')) END;
				dest[i] := c; INC(i);
			UNTIL c = 0X;
		END Upper;

		PROCEDURE Enter1(CONST name: ARRAY OF CHAR; token: LONGINT; case: SET);
		BEGIN
			IF Lowercase IN case THEN keywordsLower.PutString(name,token) END;
			IF Uppercase IN case THEN keywordsUpper.PutString(name,token) END;
			Basic.SetErrorExpected(token,name);
		END Enter1;

		PROCEDURE Enter(CONST name: ARRAY OF CHAR; token: LONGINT);
		VAR upper: Keyword;
		BEGIN
			Enter1(name,token,{Lowercase});
			Upper(name,upper);
			Enter1(upper,token,{Uppercase});
		END Enter;

		PROCEDURE EnterSymbol(CONST name: ARRAY OF CHAR; token: LONGINT);
		BEGIN
			Enter1(name,token,{Lowercase,Uppercase});
		END EnterSymbol;

	BEGIN
		NEW(keywordsUpper,EndOfText+1);
		NEW(keywordsLower,EndOfText+1);

		(* constructs and statements *)
		Enter( "cell", Cell );
		Enter( "cellnet", CellNet);
		Enter( "await" , Await);
		Enter( "begin" , Begin);
		Enter( "by" , By);
		Enter( "const" , Const);
		Enter( "case" , Case);
		Enter( "code" , Code);
		Enter( "definition", Definition);
		Enter( "do" , Do);
		Enter( "div" , Div);
		Enter( "end" , End);
		Enter( "enum", Enum);
		Enter( "else" , Else);
		Enter( "elsif" , Elsif);
		Enter( "exit" , Exit);
		Enter( "extern" , Extern);
		Enter( "false" , False);
		Enter( "for" , For);
		Enter( "finally" , Finally);
		Enter( "if" , If);
		Enter( "imag" , Imag);
		Enter( "in" , In);
		Enter( "is" , Is);
		Enter( "import" , Import);
		Enter( "loop" , Loop);
		Enter( "module", Module);
		Enter( "mod" , Mod);
		Enter( "nil" , Nil );
		Enter( "of" , Of);
		Enter( "or" , Or);
		Enter( "out", Out);
		Enter( "operator" , Operator);
		Enter( "procedure" , Procedure);
		Enter( "port", Port);
		Enter( "repeat" , Repeat);
		Enter( "return" , Return);
		Enter( "self", Self);
		Enter( "result", Result);
		Enter( "then" , Then);
		Enter( "true" , True);
		Enter( "to" , To);
		Enter( "type" , Type);
		Enter( "until" , Until );
		Enter( "var" , Var );
		Enter( "while" , While);
		Enter( "with" , With);

		(* types *)
		Enter( "array" , Array );
		Enter( "object" , Object);
		Enter( "pointer" , Pointer);
		Enter( "record" , Record);
		Enter( "address" , Address);
		Enter( "size" , Size);
		Enter( "alias" , Alias);

		(* symbols *)
		EnterSymbol( "#", Unequal);
		EnterSymbol( "&", And);
		EnterSymbol( "(", LeftParenthesis);
		EnterSymbol( ")", RightParenthesis);
		EnterSymbol( "*", Times);
		EnterSymbol( "**",TimesTimes);
		EnterSymbol( "+", Plus);
		EnterSymbol( "+*", PlusTimes);
		EnterSymbol( ",", Comma);
		EnterSymbol( "-", Minus);
		EnterSymbol(".",Period );
		EnterSymbol("..",Upto );
		EnterSymbol(".*",DotTimes );
		EnterSymbol("./",DotSlash );
		EnterSymbol(".=",DotEqual );
		EnterSymbol(".#",DotUnequal );
		EnterSymbol(".>",DotGreater );
		EnterSymbol(".>=",DotGreaterEqual );
		EnterSymbol(".<", DotLess);
		EnterSymbol(".<=",DotLessEqual );
		EnterSymbol( "/", Slash);
		EnterSymbol( ":", Colon);
		EnterSymbol( ":=",Becomes);
		EnterSymbol( ";", Semicolon);
		EnterSymbol( "<", Less);
		EnterSymbol( "<=", LessEqual);
		EnterSymbol( "=", Equal);
		EnterSymbol( ">", Greater);
		EnterSymbol( ">=", GreaterEqual);
		EnterSymbol( "[", LeftBracket);
		EnterSymbol( "]", RightBracket);
		EnterSymbol( "^", Arrow);
		EnterSymbol( "{", LeftBrace);
		EnterSymbol( "|",Bar);
		EnterSymbol( "}", RightBrace);
		EnterSymbol( "~", Not);
		EnterSymbol( "\", Backslash);
		EnterSymbol( "`", Transpose);
		EnterSymbol( "?",Questionmark);
		EnterSymbol( "??",Questionmarks);
		EnterSymbol( "!",ExclamationMark);
		EnterSymbol( "!!",ExclamationMarks);
		EnterSymbol( "<<",LessLess);
		EnterSymbol( "<<?",LessLessQ);
		EnterSymbol( ">>",GreaterGreater);
		EnterSymbol( ">>?",GreaterGreaterQ);

		Basic.SetErrorMessage(Number,"missing number");
		Basic.SetErrorMessage(String,"missing string");
		Basic.SetErrorMessage(Character,"missing character");
		Basic.SetErrorMessage(Identifier,"missing identifier");
		Basic.SetErrorMessage(EndOfText,"unexpected symbol before end");
	  END InitKeywords;

	(** debugging / reporting **)
	PROCEDURE ReportKeywords*(context: Commands.Context);
	VAR i: LONGINT; name: Keyword;
	BEGIN
		FOR i := 0 TO EndOfText DO
			context.out.Int(i,1); context.out.String(": ");
			context.out.Char('"');
			keywordsLower.StringByIndex(i,name);
			context.out.String(name);
			context.out.Char('"');
			context.out.String(", ");
			context.out.Char('"');
			keywordsUpper.StringByIndex(i,name);
			context.out.String(name);
			context.out.Char('"');
			context.out.Ln;
		END;
	END ReportKeywords;


	(*
	PROCEDURE TestScanner*(context: Commands.Context);
	VAR filename: ARRAY 256 OF CHAR; reader: Streams.Reader; scanner: Scanner;sym: Symbol;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String(filename);
		reader := TextUtilities.GetTextReader(filename);
		scanner := NewScanner(filename,reader,0,NIL);
		REPEAT
			IF scanner.GetNextSymbol(sym) THEN
				OutSymbol(context.out,sym);context.out.Ln;
			END;
		UNTIL scanner.error OR (sym.token=EndOfText)
	END TestScanner;
	*)

BEGIN
	InitReservedCharacters;   InitTokens; InitKeywords
END FoxScanner.

FoxScanner.ReportKeywords
FoxScanner.TestScanner Test.Mod ~
