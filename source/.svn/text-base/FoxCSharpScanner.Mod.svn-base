MODULE FoxCSharpScanner;

IMPORT Streams, Strings, Diagnostics, Commands, StringPool, 
    D := Debugging, Basic := FoxBasic, FoxScanner,
    KernelLog (* DEBUG *);

CONST
    Trace = FALSE;

    (* overal scanner limitation *)
    MaxIdentifierLength* = FoxScanner.MaxIdentifierLength;

    (* parametrization of numeric scanner: *)
    MaxHexDigits* = FoxScanner.MaxHexDigits;
    MaxHugeHexDigits* = FoxScanner.MaxHugeHexDigits;
    MaxRealExponent* = FoxScanner.MaxRealExponent;
    MaxLongrealExponent* = FoxScanner.MaxLongrealExponent;

    (* scanner constants *)
    EOT* = 0X; 
    LF* = 0AX; 
    CR* = 0DX; 
    TAB* = 09X;

TYPE
    StringType* = FoxScanner.StringType;
    IdentifierType* = FoxScanner.IdentifierType;
    IdentifierString* = FoxScanner.IdentifierString; 

CONST
    (* tokens *)

    None*= 0;

    (* operators and punctuators *)    
    Exclamation* = 1;         (* ! *)    
    ExclamationEqual* = 2;    (* != *)
    Percent* = 3;             (* % *)   
    PercentEqual* = 4;        (* %= *)
    And* = 5;                 (* & *)   
    AndEqual* = 6;            (* &= *)   
    AndAnd* = 7;              (* && *)
    LeftParenthesis* = 8;     (* ( *)
    RightParenthesis* = 9;    (* ) *)
    Times* = 10;              (* * *)    
    TimesEqual* = 11;         (* *= *)
    Plus* = 12;               (* + *)    
    PlusEqual* = 13;          (* += *)    
    PlusPlus* = 14;           (* ++ *)
    Comma* = 15;              (* , *)
    Minus* = 16;              (* - *)   
    MinusEqual* = 17;         (* -= *)   
    MinusMinus* = 18;         (* -- *)
    Period* = 19;             (* . *)
    Slash* = 20;              (* / *)
    SlashEqual* = 21;         (* /= *)
    Colon* = 22;              (* : *)
    Semicolon* = 23;          (* ; *)
    Less* = 24;               (* < *)
    LessEqual* = 25;          (* <= *)
    LeftShift* = 26;          (* << *)
    LeftShiftEqual* = 27;     (* <<= *)
    Equal* = 28;              (* = *)
    EqualEqual* = 29;         (* == *)
    Greater* = 30;            (* > *)
    GreaterEqual* = 31;       (* >= *)
    RightShift* = 32;         (* >> *)
    RightShiftEqual* = 33;    (* >>= *)
    LeftBracket* = 34;        (* [ *)
    RightBracket* = 35;       (* ] *)
    Arrow* = 36;              (* ^ *)
    ArrowEqual* = 37;         (* ^= *)
    LeftBrace* = 38;          (* { *)
    Bar* = 39;                (* | *)
    BarEqual* = 40;           (* |= *)
    BarBar* = 41;             (* || *)
    RightBrace* = 42;         (* } *)
    Tilde* = 43;              (* ~ *)

    (* keywords *)
    As* = 44;
    Base* = 45;
    Bool* = 46;
    Break* = 47;
    Case* = 48;
    Char* = 49;
    Class* = 50;
    Const* = 51;
    Default* = 52;
    Delegate* = 53;
    Do* = 54;
    Double* = 55;
    Else* = 56;
    False* = 57;
    Float* = 58;
    For* = 59;
    If* = 60;
    Import* = 61;
    Int* = 62;
    Internal* = 63;
    Is* = 64;
    Long* = 65;
    Module* = 66;
    New* = 67;
    Null* = 68;
    Object* = 69;
    Public* = 70;
    Readonly* = 71;
    Ref* = 72;
    Return* = 73;
    Sbyte* = 74;
    Short* = 75;
    String* = 76;
    Struct* = 77;
    Switch* = 78;
    This* = 79;
    True* = 80;
    Void* = 81;
    While* = 82;

    Identifier* = 83;
    IntegerLiteral* = 84;
    RealLiteral* = 85;
    CharacterLiteral* = 86;
    StringLiteral* = 87;

    Comment*= 88; 

    (* Active Cells *)
    Cell* = 89;
    Cellnet* = 90;
    In* = 91;
    Out* = 92;
    Select* = 93;

    Question* = 94;           (* ? *)
    QuestionQuestion* = 95;   (* ?? *)

    EndOfText*= 96;

    (* number types *)
    IntNumber*= 1; 
    LongNumber*= 2; 
    FloatNumber*= 3; 
    DoubleNumber*= 4; 

    SingleQuote = 27X;  
    DoubleQuote* = 22X;
    Backslash = 5CX;

TYPE
    (* keywords book keeping *)
    Keyword* = FoxScanner.Keyword;
    KeywordTable* = FoxScanner.KeywordTable;

TYPE
    Token* = LONGINT;

    (**
        symbol: data structure for the data transfer of 
        the last read input from the scanner to the parser
    **)
    Symbol* = RECORD
        start*, end*, line-: LONGINT;
        token*: Token;
        identifier*: IdentifierType;
        identifierString*: IdentifierString;
        string*: StringType;
        stringLength*: LONGINT;
        numberType*: LONGINT;
        integer*: LONGINT;
        hugeint*: HUGEINT;
        character*: CHAR;
        real*: LONGREAL;
    END;

    StringMaker* = FoxScanner.StringMaker;

    Scanner* = OBJECT
    VAR
        source-: StringType;
        reader: Streams.Reader;
        diagnostics: Diagnostics.Diagnostics;
        ch: CHAR;
        position: LONGINT;
        line-: LONGINT;
        error-: BOOLEAN;
        stringWriter: Streams.Writer;
        stringMaker: StringMaker;

        (*
            source: name of the source code for reference in error outputs
            reader: input stream
            position: reference position (offset) of the input stream, for error output
            diagnostics: error output object
        *)
        PROCEDURE & InitializeScanner*(
                CONST source: ARRAY OF CHAR; 
                reader: Streams.Reader; 
                position: LONGINT; 
                diagnostics: Diagnostics.Diagnostics);
        BEGIN
            NEW(stringMaker,1024);
            stringWriter := stringMaker.GetWriter();
            error := FALSE;
            NEW(SELF.source, Strings.Length(source)+1);
            COPY(source, SELF.source^);
            SELF.reader := reader;
            SELF.diagnostics := diagnostics;
            ch := " ";
            IF reader = NIL THEN 
                ch := EOT
            ELSE
                GetNextCharacter 
            END;
            IF Trace THEN 
                D.Str("New scanner  ");
                D.Ln;  
            END;
            SELF.position := position;
            line := 0;
        END InitializeScanner;

        (** report an error occured during scanning **)
        PROCEDURE ErrorS(CONST msg: ARRAY OF CHAR);
        BEGIN
            IF diagnostics # NIL THEN
                diagnostics.Error(source^, position, Diagnostics.Invalid, msg)
            END;
            error := TRUE;
        END ErrorS;

        (** report an error occured during scanning **)
        PROCEDURE Error(code: INTEGER);
            VAR errorMessage: ARRAY 256 OF CHAR;
        BEGIN
            IF diagnostics # NIL THEN
                Basic.GetErrorMessage(code, "", errorMessage);
                diagnostics.Error(source^, position, code, errorMessage)
            END;
            error := TRUE;
        END Error;

        (** get next character, end of text results in ch = EOT **)
        PROCEDURE GetNextCharacter;
        BEGIN
            reader.Char(ch); 
            INC(position);
            IF ch = LF THEN 
                INC(line) 
            END;
        END GetNextCharacter;

        PROCEDURE IsNewlineCharacter(ch: CHAR): BOOLEAN;
        BEGIN
            RETURN (ch = 0AX) OR (ch = 0DX);
        END IsNewlineCharacter;

        (**
            CharacterLiteral =
                "'" Character "'".
            Character =
                SingleCharacter |
                SimpleEscapeSequence |
                HexadecimalEscapeSequence.
            SingleCharacter =
                any character except ' (27X), \ (5CX), and NewLineCharacter.
            SimpleEscapeSequence =
                "\'" | '\"' | '\\' | '\0' | 
                '\a' | '\b' | '\f' | '\n' | '\r' | '\t' | '\v'.
            HexadecimalEscapeSequence =
                '\x' HexDigit {HexDigit}.
        **)
        PROCEDURE GetEscapeSequence(VAR esc: CHAR);
            VAR i, k, n: LONGINT;

            PROCEDURE HexDigit(ch: CHAR; VAR dig: LONGINT): BOOLEAN;
            BEGIN
                IF (ch >= '0') & (ch <= '9') THEN
                    dig := ORD(ch) - ORD('0');
                    RETURN TRUE;
                END;
                IF (ch >= 'A') & (ch <= 'F') THEN
                    dig := ORD(ch) - ORD('A') + 10;
                    RETURN TRUE;
                END;
                IF (ch >= 'a') & (ch <= 'f') THEN
                    dig := ORD(ch) - ORD('a') + 10;
                    RETURN TRUE;
                END;
                RETURN FALSE;
            END HexDigit;

        BEGIN
            CASE ch OF
              SingleQuote, DoubleQuote, Backslash:
                esc := ch;
                GetNextCharacter
            | '0':
                esc := 0X;
                GetNextCharacter
            | 'a':
                esc := 07X;
                GetNextCharacter
            | 'b':
                esc := 08X;
                GetNextCharacter
            | 'f':
                esc := 0CX;
                GetNextCharacter
            | 'n':
                esc := 0AX;
                GetNextCharacter
            | 'r':
                esc := 0DX;
                GetNextCharacter
            | 't':
                esc := 09X;
                GetNextCharacter
            | 'v':
                esc := 0BX;
                GetNextCharacter
            | 'x':
                GetNextCharacter;
                n := 0;
                i := 0;
                WHILE (i < 2) & HexDigit(ch, k) DO
                    n := n * 16 + k;
                    GetNextCharacter;
                    INC(i);
                END;
                IF i = 0 THEN
                    ErrorS("Illegal hexadecimal escape sequence");
                END;
                esc := CHR(n);
            ELSE
                ErrorS("Illegal escape sequence");
                esc := 0X;    (* arbitrary *)
            END;
        END GetEscapeSequence;

        PROCEDURE GetCharacter(VAR symbol: Symbol);
            VAR vch: CHAR;
        BEGIN
            GetNextCharacter;
            IF ch = EOT THEN
                ErrorS("Unexpected end of character literal");
                symbol.character := 0X;
                RETURN;
            END;
            IF ch = Backslash THEN
                GetNextCharacter;
                GetEscapeSequence(vch);
            ELSIF (ch = SingleQuote) OR IsNewlineCharacter(ch) THEN
                ErrorS("Illegal character literal");
                vch := 0X;
            ELSE
                vch := ch;
                GetNextCharacter;
            END;
            IF ch = SingleQuote THEN
                GetNextCharacter
            ELSE
                ErrorS("Illegal character literal")
            END;
            symbol.character := vch;
            symbol.integer := ORD(vch);
        END GetCharacter;

        (**
            StringLiteral =
                '"' {StringCharacter} '"'.
            StringCharacter =
                SingleStringCharacter |
                SimpleEscapeSequence |
                HexadecimalEscapeSequence.
            SingleStringCharacter =
                any character except " (22X), \ (5CX), and NewLineCharacter.

        **)
        PROCEDURE GetString(VAR symbol: Symbol);
            VAR vch: CHAR;
        BEGIN
            stringMaker.Clear;
            GetNextCharacter;
            LOOP
                IF (ch = EOT) THEN
                    ErrorS("Unexpected end of string literal");
                    EXIT;
                END;
                IF IsNewlineCharacter(ch) THEN
                    ErrorS("Illegal string literal");
                    EXIT;
                END;
                IF ch = DoubleQuote THEN
                    GetNextCharacter;
                    EXIT;
                END;
                IF ch = Backslash THEN
                    GetNextCharacter;
                    GetEscapeSequence(vch);
                ELSE
                    vch := ch;
                    GetNextCharacter;
                END;
                stringWriter.Char(vch);
            END;
            stringWriter.Char(0X);
            stringWriter.Update;
            (*
                ACHTUNG: Due to the implementation of GetStringCopy
                    the length of the copied string may be inconsistent
                    with its contents if the string contains 0X.
                    This must be fixed in the future.
            *)
            symbol.string := stringMaker.GetStringCopy(symbol.stringLength);
        END GetString;

        (**
            Identifier = 
                (Letter | '_') {Letter | Digit | '_'}.
            Letter = 
                'A' | 'B' | .. |  'Z' | 'a' | 'b' |  .. | 'z' .
        **)
        PROCEDURE GetIdentifier(VAR symbol: Symbol);
            VAR i: LONGINT;
        BEGIN
            i := 0;
            REPEAT 
                symbol.identifierString[i] := ch; 
                INC(i);  
                GetNextCharacter 
            UNTIL reservedCharacter[ORD(ch)] OR (i = MaxIdentifierLength);
            IF i = MaxIdentifierLength THEN 
                Error(Basic.IdentifierTooLong);
                DEC(i)
            END;
            symbol.identifierString[i] := 0X;
            StringPool.GetIndex(symbol.identifierString, symbol.identifier);
        END GetIdentifier;

        (**
            Number =
                IntegerLiteral | 
                RealLiteral.
            IntegerLiteral =
                DecimalIntegerLiteral |
                HexadecimalIntegerLiteral.
            DecimalIntegerLiteral =
                Digit {Digit} [IntegerTypeSuffix].
            HexadecimalIntegerLiteral =
                ('0X' | '0x') HexDigit {HexDigit} [IntegerTypeSuffix].
            IntegerTypeSuffix =
                'L' | 'l'.
            RealLiteral =
                Digit {Digit} '.' Digit {Digit} [ExponentPart] [RealTypeSuffix] |
                '.' Digit {Digit} [ExponentPart] [RealTypeSuffix] |
                Digit {Digit} [ExponentPart] [RealTypeSuffix] |
                Digit {Digit} [RealTypeSuffix].
            ExponentPart =
                ('E' | 'e') ['+' | '-'] Digit {Digit}.
            RealTypeSuffix =
                'F' | 'f' | 'D' | 'd'.
            Digit = 
                '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'.
            HexDigit = 
                '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' |
                'A' | 'B' | 'C' | 'D' | 'E' | 'F' |
                'a' | 'b' | 'c' | 'd' | 'e' | 'f'.
        **)
        PROCEDURE GetNumber(VAR symbol: Symbol; frac: BOOLEAN): Token;
            VAR i, nextInt, m, n, d, e, si: LONGINT;
                dig: ARRAY 24 OF CHAR;
                f: LONGREAL;
                hex, neg, long: BOOLEAN;
                hugeint, tenh: HUGEINT;
                result: LONGINT;

            PROCEDURE Append(ch: CHAR);
            BEGIN
                symbol.identifierString[si] := ch;
                INC(si);
            END Append;

            PROCEDURE Digit(ch: CHAR): LONGINT;
            BEGIN
                RETURN ORD(ch) - ORD('0')
            END Digit;

            PROCEDURE HexDigit(ch: CHAR): LONGINT;
            BEGIN
                IF (ch >= '0') & (ch <= '9') THEN
                    RETURN ORD(ch) - ORD('0')
                END;
                IF (ch >= 'A') & (ch <= 'F') THEN
                    RETURN ORD(ch) - ORD('A') + 10
                END;
                IF (ch >= 'a') & (ch <= 'f') THEN
                    RETURN ORD(ch) - ORD('a') + 10
                END;
                (* cannot happen *)
                Error(Basic.NumberIllegalCharacter);
                RETURN 0
            END HexDigit;

            PROCEDURE Ten(e: LONGINT): LONGREAL;
                VAR x, p: LONGREAL;
            BEGIN
                x := 1;
                p := 10;
                WHILE e > 0 DO
                    IF ODD(e) THEN
                        x := x * p
                    END;
                    e := e DIV 2;
                    IF e > 0 THEN
                        p := p * p
                    END
                END;
                RETURN x
            END Ten;

        BEGIN
            (* ch is '.' or Digit *)
            si := 0;
            hex := FALSE;
            IF ~frac & (ch = '0') THEN
                Append(ch);
                GetNextCharacter;
                IF (ch = 'X') OR (ch = 'x') THEN
                    Append(ch);
                    GetNextCharacter;
                    hex := TRUE
                END;
            END;
            i := 0;
            m := 0;
            n := 0;
            d := 0;
            long := FALSE;
            IF frac THEN
                Append('.');
                (* fictionary zero mantissa: *)
                i := 1;
                d := 1;
            END;
            LOOP    (* read mantissa *)
                IF ((ch >= '0') & (ch <= '9')) OR
                        (hex & 
                            (((ch >= 'A') & (ch <= 'F')) OR
                                ((ch >= 'a') & (ch <= 'f')))) THEN
                    IF (m > 0) OR (ch # '0') THEN    (* ignore leading zeros *)
                        IF n < LEN(dig) THEN
                            dig[n] := ch;
                            INC(n);
                        END;
                        INC(m);
                    END;
                    Append(ch);
                    GetNextCharacter;
                    INC(i)
                ELSIF ~hex & (ch = '.') THEN
                    IF d # 0 THEN
                        EXIT
                    END;
                    Append(ch);
                    GetNextCharacter;
                    d := i
                ELSE
                    EXIT
                END
            END;
            IF d = 0 THEN
                IF ((ch = 'F') OR (ch = 'f') OR 
                        (ch = 'D') OR (ch = 'd') OR 
                        (ch = 'E') OR (ch = 'e')) THEN
                    d := i
                END;
            ELSIF d = i THEN
                (* '.' must be followed by a digit *)
                Error(Basic.NumberIllegalCharacter)
            END;
            (* 0 <= n <= m <= i, 0 <= d <= i *)
            IF d = 0 THEN    (* integer *)
                IF (ch = 'L') OR (ch = 'l') THEN
                    Append(ch);
                    GetNextCharacter;
                    long := TRUE
                END;
                IF n = m THEN
                    symbol.integer := 0;
                    symbol.hugeint := 0;
                    i := 0;
                    IF hex THEN
                        IF ~long & 
                                ((n < MaxHexDigits) OR 
                                    ((n = MaxHexDigits) & (dig[0] <= '7'))) THEN
                            WHILE i < n DO
                                symbol.integer := symbol.integer * 10H + HexDigit(dig[i]);
                                INC(i)
                            END;
                            symbol.numberType := IntNumber;
                            symbol.hugeint := symbol.integer;
                        ELSIF n <= MaxHugeHexDigits THEN
                            hugeint := 0;
                            IF (n = MaxHugeHexDigits) & (dig[0] > '7') THEN
                                (* prevent overflow *)
                                hugeint := -1
                            END;
                            WHILE i < n DO
                                hugeint := hugeint * 10H + HexDigit(dig[i]);
                                INC(i)
                            END;
                            symbol.numberType := LongNumber;
                            symbol.hugeint := hugeint;
                            symbol.integer := SHORT(symbol.hugeint);

                        ELSE
                            symbol.numberType := LongNumber;
                            Error(Basic.NumberTooLarge)
                        END
                    ELSE    (* decimal *)
                        WHILE (i < n) & ~long DO
                            d := Digit(dig[i]);
                            INC(i);
                            nextInt := symbol.integer * 10 + d;
                            IF nextInt >= 0 THEN
                                symbol.integer := nextInt
                            ELSE    (* overflow *)
                                long := TRUE
                            END;
                        END;
                        IF long THEN
                            (* restart computation *)
                            (*
                                ACHTUNG: Reportedly, Fox has or had certain limitations
                                    working with HUGEINT that affected the original code. 
                                    Furthermore, at present Ronin supports HUGEINT as
                                    a mere alias to LONGINT, therefore the following code
                                    is just reserved for the future and long integer
                                    constants are not yet supported.
                            *)
                            i := 0;
                            hugeint := 0;
                            tenh := 10;
                            WHILE i < n DO
                                d := Digit(dig[i]);
                                INC(i);
                                hugeint := hugeint * tenh + d;
                                IF hugeint < 0 THEN
                                    Error(Basic.NumberTooLarge)
                                END
                            END;
                            symbol.numberType := LongNumber;
                            symbol.hugeint := hugeint;
                            symbol.integer := SHORT(symbol.hugeint);
                        ELSE
                            symbol.numberType := IntNumber;
                            symbol.hugeint := symbol.integer;
                        END
                    END
                ELSE
                    symbol.numberType := LongNumber;
                    Error(Basic.NumberTooLarge)
                END;
                result := IntegerLiteral;
            ELSE    (* fraction *)
                IF (ch = 'F') OR (ch = 'f') THEN
                    Append(ch);
                    GetNextCharacter;
                    long := FALSE
                ELSIF (ch = 'D') OR (ch = 'd') THEN
                    Append(ch);
                    GetNextCharacter;
                    long := TRUE
                ELSE
                    long := TRUE
                END;
                f := 0;
                e := 0;
                WHILE n > 0 DO
                    (* 0 <= f < 1 *)
                    DEC(n);
                    f := (Digit(dig[n]) + f) / 10
                END;
                IF (ch = 'E') OR (ch = 'e') THEN
                    Append(ch);
                    GetNextCharacter;
                    neg := FALSE;
                    IF ch = '-' THEN
                        neg := TRUE;
                        Append(ch);
                        GetNextCharacter
                    ELSIF ch = '+' THEN
                        Append(ch);
                        GetNextCharacter
                    END;
                    IF (ch >= '0') & (ch <= '9') THEN
                        REPEAT
                            n := Digit(ch);
                            Append(ch);
                            GetNextCharacter;
                            IF e <= (MAX(INTEGER) - n) DIV 10 THEN
                                e := e * 10 + n
                            ELSE
                                Error(Basic.NumberTooLarge)
                            END
                        UNTIL (ch < '0') OR (ch > '9');
                        IF neg THEN
                            e := -e
                        END
                    ELSE
                        Error(Basic.NumberIllegalCharacter)
                    END
                END;
                (* decimal point shift *)
                DEC(e, i-d-m);
                IF long THEN
                    symbol.numberType := DoubleNumber;
                    IF (1 - MaxLongrealExponent < e) & (e <= MaxLongrealExponent) THEN
                        IF e < 0 THEN
                            symbol.real := f / Ten(-e)
                        ELSE
                            symbol.real := f * Ten(e)
                        END
                    ELSE
                        Error(Basic.NumberTooLarge)
                    END
                ELSE
                    symbol.numberType := FloatNumber;
                    IF (1- MaxRealExponent < e) & (e <= MaxRealExponent) THEN
                        IF e < 0 THEN
                            symbol.real := f / Ten(-e)
                        ELSE
                            symbol.real := f * Ten(e)
                        END
                    ELSE
                        Error(Basic.NumberTooLarge)
                    END
                END;
                result := RealLiteral;
            END;
            symbol.identifierString[si] := 0X;
            RETURN result;
        END GetNumber;

        (** read / skip a comment **)
        (**
            Comment =
                SingleLineComment |
                DelimitedComment.
            SingleLineComment =
                '//' {InputCharacter}.
            InputCharacter =
                any character except a NewLineCharacter.
            NewlineCharacter =
                Carriage return character (0DX) |
                Line feed character (0AX) |
				EOT (0X).
            DelimitedComment =
                '/*' [DelimitedCommentText] Asterisks '/'.
            DelimitedCommentText =
                DelimitedCommentSection {DelimitedCommentSection}.
            DelimitedCommentSection =
                NotAsterisk |
                Asterisks NotSlash.
            Asterisks =
                '*' {'*'}.
            NotAsterisk =
                any character except *.
            NotSlash =
                any character except /.            
        **)
        PROCEDURE ReadSingleLineComment(VAR symbol: Symbol);
        BEGIN
            stringMaker.Clear;
            WHILE (ch # 0DX) & (ch # 0AX) & (ch # EOT) DO
                stringWriter.Char(ch);
                GetNextCharacter;
            END;
            stringWriter.Char(0X);
            stringWriter.Update;
            symbol.token := Comment;
            symbol.string := stringMaker.GetString(symbol.stringLength);
        END ReadSingleLineComment;

        PROCEDURE ReadDelimitedComment(VAR symbol: Symbol);
            VAR done: BOOLEAN;
        BEGIN
            stringMaker.Clear;
            done := FALSE;
            WHILE ~done & (ch # EOT) DO
                IF ch = '*' THEN
                    GetNextCharacter;
                    IF ch = '/' THEN
                        GetNextCharacter;
                        done := TRUE;
                    ELSE
                        stringWriter.Char('*');
                    END;
                ELSE
                    stringWriter.Char(ch);
                    GetNextCharacter;
                END;
            END;
            IF ~done THEN
                Error(Basic.CommentNotClosed);
            END;
            stringWriter.Char(0X);
            stringWriter.Update;
            symbol.token := Comment;
            symbol.string := stringMaker.GetString(symbol.stringLength);
        END ReadDelimitedComment;

        PROCEDURE SkipBlanks;
        BEGIN
            WHILE (ch = 20X) OR (ch = 09X) OR (ch = 0BX) OR (ch = 0CX) OR
                    (ch = 0DX) OR (ch = 0AX) DO
                (* ignore  C# whitespace characters '\t' (09X), '\v' (0BX), '\f' (0CX) 
                       and newlines '\r' (0DX), '\n' (0AX) *)
                IF ch = EOT THEN
                    IF Trace THEN 
                        D.String("EOT"); 
                        D.Ln; 
                    END;
                    RETURN
                ELSE 
                    GetNextCharacter
                END
            END;
        END SkipBlanks;

        (** get next symbol **)
        PROCEDURE GetNextSymbol*(VAR symbol: Symbol): BOOLEAN;
            VAR s, token: LONGINT;
        BEGIN
            SkipBlanks;
            symbol.start := position;
            symbol.line := line;
            stringMaker.Clear;
(* @@@ *)
(*
KernelLog.String("GetNextSymbol ");
KernelLog.Char(ch);
KernelLog.Ln();
*)
            CASE ch OF
              EOT:
                s := EndOfText
            | DoubleQuote:
                s := StringLiteral;
                GetString(symbol)
            | SingleQuote:
                s := CharacterLiteral;
                GetCharacter(symbol)
            | '!':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := ExclamationEqual
                ELSE
                    s := Exclamation
                END
            | '%':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := PercentEqual
                ELSE
                    s := Percent
                END
            | '&':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := AndEqual
                ELSIF ch = '&' THEN
                    GetNextCharacter;
                    s := AndAnd
                ELSE
                    s := And
                END
            | '(':
                s := LeftParenthesis;
                GetNextCharacter
            | ')':
                s := RightParenthesis;
                GetNextCharacter
            | '*':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := TimesEqual
                ELSE
                    s := Times
                END
            | '+':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := PlusEqual
                ELSIF ch = '+' THEN
                    GetNextCharacter;
                    s := PlusPlus
                ELSE
                    s := Plus
                END
            | ',':
                s := Comma;
                GetNextCharacter
            | '-':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := MinusEqual
                ELSIF ch = '-' THEN
                    GetNextCharacter;
                    s := MinusMinus
                ELSE
                    s := Minus
                END
            | '.':
                GetNextCharacter;
                IF (ch >= '0') & (ch <= '9') THEN
                    s := GetNumber(symbol, TRUE)
                ELSE
                    s := Period
                END
            | '/':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := SlashEqual
                ELSIF ch = '/' THEN
                    GetNextCharacter;
                    ReadSingleLineComment(symbol);
                    s := Comment
                ELSIF ch = '*' THEN
                    GetNextCharacter;
                    ReadDelimitedComment(symbol);
                    s := Comment
                ELSE
                    s := Slash
                END
            | '0' .. '9':
                s := GetNumber(symbol, FALSE)
            | ':':
                s := Colon;
                GetNextCharacter
            | ';':
                s := Semicolon;
                GetNextCharacter
            | '<':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := LessEqual
                ELSIF ch = '<' THEN
                    GetNextCharacter;
                    IF ch = '=' THEN
                        GetNextCharacter;
                        s := LeftShiftEqual
                    ELSE
                        s := LeftShift
                    END
                ELSE
                    s := Less
                END
            | '=':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := EqualEqual
                ELSE
                    s := Equal
                END
            | '>':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := GreaterEqual
                ELSIF ch = '>' THEN
                    GetNextCharacter;
                    IF ch = '=' THEN
                        GetNextCharacter;
                        s := RightShiftEqual
                    ELSE
                        s := RightShift
                    END
                ELSE
                    s := Greater
                END
            | '?':
                GetNextCharacter;
                IF ch = '?' THEN
                    GetNextCharacter;
                    s := QuestionQuestion
                ELSE
                    s := Question;
                END
            | '[':
                s := LeftBracket;
                GetNextCharacter
            | ']':
                s := RightBracket;
                GetNextCharacter
            | '^':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := ArrowEqual
                ELSE
                    s := Arrow
                END
            | '{':
                s := LeftBrace;
                GetNextCharacter
            | '|':
                GetNextCharacter;
                IF ch = '=' THEN
                    GetNextCharacter;
                    s := BarEqual
                ELSIF ch = '|' THEN
                    GetNextCharacter;
                    s := BarBar
                ELSE
                    s := Bar
                END
            | '}':
                s := RightBrace;
                GetNextCharacter
            | '~':
                s := Tilde;
                GetNextCharacter
            | 'A' .. 'Z':
                s := Identifier;
                GetIdentifier(symbol)
            | 'a' .. 'z':
                s := Identifier;
                GetIdentifier(symbol);
                token := keywords.IndexByIdentifier(symbol.identifier);
                IF  (token >= 0) THEN 
                    s := token 
                END;
            ELSE
                s := Identifier;
                GetIdentifier(symbol)
            END;

            symbol.token := s;
            symbol.end := position;

            IF Trace THEN 
                OutSymbol(D.Log, symbol); 
                D.Ln; 
            END;

            RETURN ~error
        END GetNextSymbol;

        PROCEDURE ResetError*();
        BEGIN 
            error := FALSE
        END ResetError;

        (** set the diagnostics mode of the scanner 
            (diagnostics = NIL ==> no report) and reset the error state
            intended for silent symbol peeeking after the end of a module *)
        PROCEDURE ResetErrorDiagnostics*(VAR diagnostics: Diagnostics.Diagnostics);
            VAR b: BOOLEAN; 
                d: Diagnostics.Diagnostics;
        BEGIN
            error := FALSE;
            d := SELF.diagnostics; 
            SELF.diagnostics := diagnostics; 
            diagnostics := d;
        END ResetErrorDiagnostics;

    END Scanner;

    (** return a new scanner on a stream, error output via diagnostics  **)
    PROCEDURE NewScanner*(
            CONST source: ARRAY OF CHAR; 
            reader: Streams.Reader; 
            position: LONGINT; 
            diagnostics: Diagnostics.Diagnostics): Scanner;
        VAR s: Scanner;
    BEGIN
        NEW( s, source, reader, position, diagnostics );  
        RETURN s;
    END NewScanner;

    VAR
        reservedCharacter: ARRAY 256 OF BOOLEAN;
        tokens-: ARRAY EndOfText+1 OF Keyword;
        keywords: KeywordTable;

    PROCEDURE SymbolToString*(CONST symbol: Symbol; VAR str: ARRAY OF CHAR);
        VAR id: StringPool.Index;
    BEGIN
        CASE symbol.token OF
          Identifier, IntegerLiteral, RealLiteral: 
            COPY(symbol.identifierString, str)
        | StringLiteral, Comment: 
            ASSERT(LEN(str) >= LEN(symbol.string^)); 
            COPY(symbol.string^, str);
        ELSE
            GetKeyword(symbol.token, id);
            IF id < 0 THEN 
                str[0] := 0X 
            ELSE 
                StringPool.GetString(id, str) END;
        END;
    END SymbolToString;

    (** debugging output **)
    PROCEDURE OutSymbol*(w: Streams.Writer; CONST symbol: Symbol);
        VAR str: ARRAY 256 OF CHAR;
            i: LONGINT;

        PROCEDURE OutChar(ch: CHAR);
        BEGIN
            IF ((ch >= 20X) & (ch < 7FX)) OR ((ch > 0A0X) & (ch # 0ADX)) THEN
                w.Char(ch);
            ELSE
                w.Char(Backslash);
                w.Char('x');
                w.Hex(ORD(ch), 1);
            END;
        END OutChar;

    BEGIN
        w.Int(symbol.start, 1); 
        w.String("-");
        w.Int(symbol.end, 1); 
        w.String(":");
        w.String(tokens[symbol.token]);
        IF (symbol.token = IntegerLiteral) OR (symbol.token = RealLiteral) THEN
            CASE symbol.numberType OF
              IntNumber: 
                w.String("(int)")
            | LongNumber: 
                w.String("(long)")
            | FloatNumber: 
                w.String("(float)")
            | DoubleNumber: 
                w.String("(double)")
            END;
        ELSIF symbol.token = CharacterLiteral THEN
            w.String(":"); 
            w.Char("'"); 
            OutChar(symbol.character);
            w.Char("'");
        ELSIF symbol.token = StringLiteral THEN
            w.String(":"); 
            w.Char('"'); 
            i := 0;
            WHILE symbol.string^[i] # 0X DO
                OutChar(symbol.string^[i]);
                INC(i);
            END;
            w.Char('"');
        ELSIF symbol.token = Comment THEN
            w.String("/*"); 
            w.String(symbol.string^); 
            w.String("*/");
        ELSE
            SymbolToString(symbol, str); 
            w.String(": "); 
            w.String(str);
        END
    END OutSymbol;

    (** reserved characters are the characters that may not occur within an identifier **)
    PROCEDURE InitReservedCharacters;
        VAR i: LONGINT;
    BEGIN
        FOR i := 0 TO LEN(reservedCharacter) - 1 DO
            CASE CHR(i) OF
            | 'a' .. 'z', 'A' .. 'Z': 
                reservedCharacter[i] := FALSE;
            | '0'..'9': 
                reservedCharacter[i] := FALSE;
            | '_': 
                reservedCharacter[i] := FALSE
            ELSE
                reservedCharacter[i] := TRUE
            END;
        END;
    END InitReservedCharacters;

    (* get keyword by token *)
    PROCEDURE GetKeyword*(token: LONGINT; VAR identifier: IdentifierType);
    BEGIN
        keywords.IdentifierByIndex(token, identifier);
    END GetKeyword;

    PROCEDURE InitTokens;
    VAR i: LONGINT;
    BEGIN
        tokens[None] := "None";

        (* operators and punctuators *)    
        tokens[Exclamation] := "Exclamation";
        tokens[ExclamationEqual] := "ExclamationEqual";
        tokens[Percent] := "Percent";   
        tokens[PercentEqual] := "PercentEqual";
        tokens[And] := "And";
        tokens[AndEqual] := "AndEqual";
        tokens[AndAnd] := "AndAnd";
        tokens[LeftParenthesis] := "LeftParenthesis";
        tokens[RightParenthesis] := "RightParenthesis";
        tokens[Times] := "Times";
        tokens[TimesEqual] := "TimesEqual";
        tokens[Plus] := "Plus";
        tokens[PlusEqual] := "PlusEqual";
        tokens[PlusPlus] := "PlusPlus";
        tokens[Comma] := "Comma";
        tokens[Minus] := "Minus";
        tokens[MinusEqual] := "MinusEqual";
        tokens[MinusMinus] := "MinusMinus";
        tokens[Period] := "Period";
        tokens[Slash] := "Slash";
        tokens[SlashEqual] := "SlashEqual";
        tokens[Colon] := "Colon";
        tokens[Semicolon] := "Semicolon";
        tokens[Less] := "Less";
        tokens[LessEqual] := "LessEqual";
        tokens[LeftShift] := "LeftShift";
        tokens[LeftShiftEqual] := "LeftShiftEqual";
        tokens[Equal] := "Equal";
        tokens[EqualEqual] := "EqualEqual";
        tokens[Greater] := "Greater";
        tokens[GreaterEqual] := "GreaterEqual";
        tokens[RightShift] := "RightShift";
        tokens[RightShiftEqual] := "RightShiftEqual";
        tokens[LeftBracket] := "LeftBracket";
        tokens[RightBracket] := "RightBracket";
        tokens[Arrow] := "Arrow";
        tokens[ArrowEqual] := "ArrowEqual";
        tokens[LeftBrace] := "LeftBrace";
        tokens[Bar] := "Bar";
        tokens[BarEqual] := "BarEqual";
        tokens[BarBar] := "BarBar";
        tokens[RightBrace] := "RightBrace";
        tokens[Tilde] := "Tilde";

        (* keywords *)
        tokens[As] := "As";
        tokens[Base] := "Base";
        tokens[Bool] := "Bool";
        tokens[Break] := "Break";
        tokens[Case] := "Case";
        tokens[Char] := "Char";
        tokens[Class] := "Class";
        tokens[Const] := "Const";
        tokens[Default] := "Default";
        tokens[Delegate] := "Delegate";
        tokens[Do] := "Do";
        tokens[Double] := "Double";
        tokens[Else] := "Else";
        tokens[False] := "False";
        tokens[Float] := "Float";
        tokens[For] := "For";
        tokens[If] := "If";
        tokens[Import] := "Import";
        tokens[Int] := "Int";
        tokens[Internal] := "Internal";
        tokens[Is] := "Is";
        tokens[Long] := "Long";
        tokens[Module] := "Module";
        tokens[New] := "New";
        tokens[Null] := "Null";
        tokens[Object] := "Object";
        tokens[Public] := "Public";
        tokens[Readonly] := "Readonly";
        tokens[Ref] := "Ref";
        tokens[Return] := "Return";
        tokens[Sbyte] := "Sbyte";
        tokens[Short] := "Short";
        tokens[String] := "String";
        tokens[Struct] := "Struct";
        tokens[Switch] := "Switch";
        tokens[This] := "This";
        tokens[True] := "True";
        tokens[Void] := "Void";
        tokens[While] := "While";

        tokens[Identifier] := "Identifier";
        tokens[IntegerLiteral] := "IntegerLiteral";
        tokens[RealLiteral] := "RealLiteral";
        tokens[CharacterLiteral] := "CharacterLiteral";
        tokens[StringLiteral] := "StringLiteral";

        tokens[Comment] := "Comment";
        tokens[EndOfText] := "EndOfText";

        (* Active Cells *)
        tokens[Cell] := "Cell";
        tokens[Cellnet] := "Cellnet";
        tokens[In] := "In";
        tokens[Out] := "Out";
        tokens[Select] := "Select";

        tokens[Question] := "Question";
        tokens[QuestionQuestion] := "QuestionQuestion";

        FOR i := 0 TO EndOfText DO 
            ASSERT(tokens[i] # "") 
        END;
    END InitTokens;

    (** enter keywords in the list of keywords **)
    PROCEDURE InitKeywords;

        PROCEDURE Enter(CONST name: ARRAY OF CHAR; token: LONGINT);
        BEGIN
            keywords.PutString(name, token);
            Basic.SetErrorExpected(token, name);
        END Enter;

    BEGIN
        NEW(keywords,EndOfText+1);

        (* keywords *)
        Enter("as", As);
        Enter("base", Base);
        Enter("bool", Bool);
        Enter("break", Break);
        Enter("case", Case);
        Enter("char", Char);
        Enter("class", Class);
        Enter("const", Const);
        Enter("default", Default);
        Enter("delegate", Delegate);
        Enter("do", Do);
        Enter("double", Double);
        Enter("else", Else);
        Enter("false", False);
        Enter("float", Float);
        Enter("for", For);
        Enter("if", If);
        Enter("import", Import);
        Enter("int", Int);
        Enter("internal", Internal);
        Enter("is", Is);
        Enter("long", Long);
        Enter("module", Module);
        Enter("new", New);
        Enter("null", Null);
        Enter("object", Object);
        Enter("public", Public);
        Enter("readonly", Readonly);
        Enter("ref", Ref);
        Enter("return", Return);
        Enter("sbyte", Sbyte);
        Enter("short", Short);
        Enter("string", String);
        Enter("struct", Struct);
        Enter("switch", Switch);
        Enter("this", This);
        Enter("true", True);
        Enter("void", Void);
        Enter("while", While);

        (* operators and punctuators *)
        Enter("!", Exclamation);   
        Enter("!=", ExclamationEqual);
        Enter("%", Percent);
        Enter("%=", PercentEqual);
        Enter("&", And);
        Enter("&=", AndEqual);
        Enter("&&", AndAnd);
        Enter("(", LeftParenthesis);
        Enter(")", RightParenthesis);
        Enter("*", Times);
        Enter("*=", TimesEqual);
        Enter("+", Plus);
        Enter("+=", PlusEqual);
        Enter("++", PlusPlus);
        Enter(",", Comma);
        Enter("-", Minus);
        Enter("-=", MinusEqual);
        Enter("--", MinusMinus);
        Enter(".", Period);
        Enter("/", Slash);
        Enter("/=", SlashEqual);
        Enter(":", Colon);
        Enter(";", Semicolon);
        Enter("<", Less);
        Enter("<=", LessEqual);
        Enter("<<", LeftShift);
        Enter("<<=", LeftShiftEqual);
        Enter("=", Equal);
        Enter("==", EqualEqual);
        Enter(">", Greater);
        Enter(">=", GreaterEqual);
        Enter(">>", RightShift);
        Enter(">>=", RightShiftEqual);
        Enter("[", LeftBracket);
        Enter("]", RightBracket);
        Enter("^", Arrow);
        Enter("^=", ArrowEqual);
        Enter("{", LeftBrace);
        Enter("|", Bar);
        Enter("}", BarEqual);
        Enter("||", BarBar);
        Enter("}", RightBrace);
        Enter("~", Tilde);

        (* Active Cells *)
        Enter("cell", Cell);
        Enter("cellnet", Cellnet);
        Enter("in", In);
        Enter("out", Out);
        Enter("select", Select);

        Enter("?", Question);
        Enter("??", QuestionQuestion);

        Basic.SetErrorMessage(Identifier, "missing identifier");
        Basic.SetErrorMessage(IntegerLiteral, "missing integer literal");
        Basic.SetErrorMessage(RealLiteral, "missing real literal");
        Basic.SetErrorMessage(CharacterLiteral, "missing character literal");
        Basic.SetErrorMessage(StringLiteral, "missing string literal");
      END InitKeywords;

    (** debugging / reporting **)
    PROCEDURE ReportKeywords*(context: Commands.Context);
        VAR i: LONGINT; 
            name: Keyword;
    BEGIN
        FOR i := 0 TO EndOfText DO
            context.out.Int(i, 1); 
            context.out.String(": ");
            context.out.Char('"');
            keywords.StringByIndex(i, name);
            context.out.String(name);
            context.out.Char('"');
            context.out.Ln;
        END;
    END ReportKeywords;

(*
    PROCEDURE TestScanner*(context: Commands.Context);
        VAR filename: ARRAY 256 OF CHAR; 
            reader: Streams.Reader; 
            scanner: Scanner;
            sym: Symbol;
    BEGIN
        context.arg.SkipWhitespace; 
        context.arg.String(filename);
        reader := TextUtilities.GetTextReader(filename);
        scanner := NewScanner(filename, reader, 0, NIL);
        REPEAT
            IF scanner.GetNextSymbol(sym) THEN
                OutSymbol(context.out, sym);
                context.out.Ln;
            END;
        UNTIL scanner.error OR (sym.token = EndOfText)
    END TestScanner;
*)

BEGIN
    InitReservedCharacters;
    InitTokens;
    InitKeywords
END FoxCSharpScanner.
