MODULE FoxCSharpParser;
(* module originating from Alexey Gokhberg's ActiveCells# Parser *)

IMPORT Strings, StringPool, Diagnostics, D := Debugging, Basic := FoxBasic, FoxScanner,
    Scanner := FoxCSharpScanner, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal,
    KernelLog (* DEBUG *);

CONST
    Trace = FALSE;

    (* modifiers *)
    Public = 0;
    Internal = 1;

    LynxCase = FoxScanner.Lowercase;

    invalidPosition = -1;

TYPE
    LocalIdentEntry = OBJECT
    VAR
        next: LocalIdentEntry;
        level: LONGINT;
        name: SyntaxTree.Identifier;
        local: SyntaxTree.Identifier;
    END LocalIdentEntry;

    LocalIdentTable = OBJECT
    VAR
        head: LocalIdentEntry;
        level: LONGINT;
        suffix: LONGINT;

        PROCEDURE & Init;
        BEGIN
            Reset;
        END Init;

        PROCEDURE Reset;
        BEGIN
            head := NIL;
            level := 0;
            suffix := 0;
        END Reset;

        PROCEDURE OpenScope;
        BEGIN
            INC(level);
        END OpenScope;
        
        PROCEDURE CloseScope;
            VAR p: LocalIdentEntry;
        BEGIN
            p := head;
            WHILE (p # NIL) & (p.level = level) DO
                p := p.next;
            END;
            head := p;
            DEC(level);
        END CloseScope;

        PROCEDURE Enter(name: SyntaxTree.Identifier): SyntaxTree.Identifier;
            VAR p, q: LocalIdentEntry;
                local: SyntaxTree.Identifier;
                str: Scanner.IdentifierString;
        BEGIN
            IF level = 0 THEN
                RETURN name;
            END;
            p := head;
            q := NIL;
            WHILE (q = NIL) & (p # NIL) & (p.level = level) DO
                IF p.name = name THEN
                    q := p;
                END;
                p := p.next;
            END;
            IF q # NIL THEN
                RETURN q.local;
            END;
            Basic.GetString(name, str);
            Strings.AppendChar(str, "@");
            INC(suffix);
            Basic.AppendNumber(str, suffix);
            local := Basic.MakeString(str);
            NEW(q);
            q.level := level;
            q.name := name;
            q.local := local;
            q.next := head;
            head := q;
            RETURN local; 
        END Enter;

        PROCEDURE Find(name: SyntaxTree.Identifier): SyntaxTree.Identifier;
            VAR p: LocalIdentEntry;
        BEGIN
            p := head;
            WHILE (p # NIL) & (p.name # name) DO
                p := p.next;
            END;
            IF p # NIL THEN
                RETURN p.local;
            END;
            RETURN name;
        END Find;
    END LocalIdentTable;

    Parser* = OBJECT
    VAR
        scanner: Scanner.Scanner;
        symbol-: Scanner.Symbol;
        diagnostics: Diagnostics.Diagnostics;
        currentScope: SyntaxTree.Scope;
        recentCommentItem: ANY; 
        recentLine: LONGINT;
        recentComment: SyntaxTree.Comment;
        moduleScope: SyntaxTree.ModuleScope;
        error-: BOOLEAN;
        activeCellsSupport: BOOLEAN;

        initStatements: SyntaxTree.StatementSequence;
        initOuter: SyntaxTree.Statement;

        delegateModifiers: SyntaxTree.Modifier;

        lynxChar: SyntaxTree.Identifier;
        lynxSbyte: SyntaxTree.Identifier;
        lynxShort: SyntaxTree.Identifier;
        lynxInt: SyntaxTree.Identifier;
        lynxLong: SyntaxTree.Identifier;
        lynxFloat: SyntaxTree.Identifier;
        lynxDouble: SyntaxTree.Identifier;
        lynxBool: SyntaxTree.Identifier;
        lynxObject: SyntaxTree.Identifier;
        lynxString: SyntaxTree.Identifier;
        lynxNewobj: SyntaxTree.Identifier;
        lynxNewarr: SyntaxTree.Identifier;
        lynxAsop: SyntaxTree.Identifier;
        lynxUnop: SyntaxTree.Identifier;
        lynxBinop: SyntaxTree.Identifier;

        lynxSend: SyntaxTree.Identifier;
        lynxReceive: SyntaxTree.Identifier;
        lynxRecvnb: SyntaxTree.Identifier;
        lynxConnect: SyntaxTree.Identifier;
        lynxDelegate: SyntaxTree.Identifier;

        lynxNewsel: SyntaxTree.Identifier;
        lynxAddsel: SyntaxTree.Identifier;
        lynxSelect: SyntaxTree.Identifier;
        lynxSelidx: SyntaxTree.Identifier;

        lynxType: SyntaxTree.Identifier;

        identMain: SyntaxTree.Identifier;
        localIdentTable: LocalIdentTable;

        indent: LONGINT;    (* for debugging purposes only *)

        (** constructor, init parser with scanner providing input and with diagnostics for error output *)
        PROCEDURE & Init*(scanner: Scanner.Scanner; diagnostics: Diagnostics.Diagnostics);
        BEGIN
            SELF.scanner := scanner;
            SELF.diagnostics := diagnostics;
            error := ~scanner.GetNextSymbol(symbol);
            recentCommentItem := NIL; 
            recentComment := NIL;
            initStatements := NIL;
            initOuter := NIL;
            InitDelegateModifiers;
            InitSystemNames;
            StringPool.GetIndex("lynx@type", lynxType);
            StringPool.GetIndex("main", identMain);
            NEW(localIdentTable);
            (* debugging *)
            indent := 0;
            activeCellsSupport := FALSE;

        END Init;

        PROCEDURE InitDelegateModifiers;
            VAR name: SyntaxTree.Identifier;
        BEGIN
            StringPool.GetIndex("DELEGATE", name);
            delegateModifiers := SyntaxTree.NewModifier(invalidPosition, name, NIL);
        END InitDelegateModifiers;

        (*
            NOTE: Fox semantical analysis has been extended in order to recognize
                and properly support the following names of system procedures.
                Lynx version of FoxGlobal provides the respective bindings.
        *)
        PROCEDURE InitSystemNames;
        BEGIN
            StringPool.GetIndex(Global.LynxChar, lynxChar);
            StringPool.GetIndex(Global.LynxSbyte, lynxSbyte);
            StringPool.GetIndex(Global.LynxShort, lynxShort);
            StringPool.GetIndex(Global.LynxInt, lynxInt);
            StringPool.GetIndex(Global.LynxLong, lynxLong);
            StringPool.GetIndex(Global.LynxFloat, lynxFloat);
            StringPool.GetIndex(Global.LynxDouble, lynxDouble);
            StringPool.GetIndex(Global.LynxBool, lynxBool);
            StringPool.GetIndex(Global.LynxObject, lynxObject);
            StringPool.GetIndex(Global.LynxString, lynxString);
            StringPool.GetIndex(Global.LynxNewobj, lynxNewobj);
            StringPool.GetIndex(Global.LynxNewarr, lynxNewarr);
            StringPool.GetIndex(Global.LynxAsop, lynxAsop);
            StringPool.GetIndex(Global.LynxUnop, lynxUnop);
            StringPool.GetIndex(Global.LynxBinop, lynxBinop);
            StringPool.GetIndex(Global.LynxSend, lynxSend);
            StringPool.GetIndex(Global.LynxReceive, lynxReceive);
            StringPool.GetIndex(Global.LynxRecvnb, lynxRecvnb);
            StringPool.GetIndex(Global.LynxConnect, lynxConnect);
            StringPool.GetIndex(Global.LynxDelegate, lynxDelegate);
            StringPool.GetIndex(Global.LynxNewsel, lynxNewsel);
            StringPool.GetIndex(Global.LynxAddsel, lynxAddsel);
            StringPool.GetIndex(Global.LynxSelect, lynxSelect);
            StringPool.GetIndex(Global.LynxSelidx, lynxSelidx);
        END InitSystemNames;

        PROCEDURE ActiveCellsSupport*;
        BEGIN 
            activeCellsSupport := TRUE
        END ActiveCellsSupport;

        PROCEDURE S(CONST s: ARRAY OF CHAR);    (* for debugging purposes only *)
            VAR i: LONGINT;
        BEGIN
            D.Ln;
            INC(indent);
            D.Int(indent, 1);
            FOR i := 1 TO indent DO 
                D.Str("  ");
            END;
            D.Str("start: ");
            D.Str(s);
            D.Str(" at pos ");
            D.Int(symbol.start, 1);
        END S;

        PROCEDURE E(CONST s: ARRAY OF CHAR);    (* for debugging purposes only *)
            VAR i: LONGINT;
        BEGIN
            D.Ln;
            D.Int(indent, 1);
            FOR i := 1 TO indent DO 
                D.Str("  ");
            END;
            D.Str("end : ");
            D.Str(s);
            D.Str(" at pos ");
            D.Int(symbol.start, 1);
        END E;

        PROCEDURE EE(CONST s, t: ARRAY OF CHAR);    (* for debugging purposes only *)
            VAR i: LONGINT;
        BEGIN
            D.Ln;
            D.Int(indent, 1);
            FOR i := 1 TO indent DO 
                D.Str("  ");
            END;
            D.Str("end : ");
            D.Str(s);
            D.Str(" (");
            D.Str(t);
            D.Str(") at pos ");
        END EE;

        (** output error message and / or given code *)
        PROCEDURE Error(position: LONGINT; code: LONGINT; CONST message: ARRAY OF CHAR);
            VAR errorMessage: ARRAY 256 OF CHAR;
        BEGIN
            IF diagnostics # NIL THEN
                Basic.GetErrorMessage(code,message,errorMessage);
                diagnostics.Error(scanner.source^, position, code, errorMessage);
            END;
            error := TRUE;
(* @@@ *)
HALT(100);
        END Error;

        (** helper procedures interfacing to the scanner **)

        (** Get next symbol from scanner and store it in object-local variable 'symbol' *)
        PROCEDURE NextSymbol;
            VAR comment: SyntaxTree.Comment;
        BEGIN
            error := ~scanner.GetNextSymbol(symbol) OR error;
            WHILE ~error & (symbol.token = Scanner.Comment) DO
                comment := SyntaxTree.NewComment(symbol.start, currentScope, symbol.string^, symbol.stringLength);
                moduleScope.AddComment(comment);
                IF recentComment = NIL THEN
                    recentComment := comment;
                    IF symbol.line = recentLine THEN
                        IF recentCommentItem # NIL THEN
                            IF (recentCommentItem IS SyntaxTree.Symbol) THEN
                                IF recentCommentItem(SyntaxTree.Symbol).comment = NIL THEN
                                    recentCommentItem(SyntaxTree.Symbol).SetComment(comment)
                                END;
                            ELSIF (recentCommentItem IS SyntaxTree.Statement) THEN
                                IF recentCommentItem(SyntaxTree.Statement).comment = NIL THEN
                                    recentCommentItem(SyntaxTree.Statement).SetComment(comment)
                                END;
                            ELSIF (recentCommentItem IS SyntaxTree.IfPart) THEN
                                IF recentCommentItem(SyntaxTree.IfPart).comment = NIL THEN
                                    recentCommentItem(SyntaxTree.IfPart).SetComment(comment)
                                END;
                            ELSIF (recentCommentItem IS SyntaxTree.CasePart) THEN
                                IF recentCommentItem(SyntaxTree.CasePart).comment = NIL THEN
                                    recentCommentItem(SyntaxTree.CasePart).SetComment(comment)
                                END;
(* LYNX+
                            ELSIF (recentCommentItem IS SyntaxTree.WithPart) THEN
                                IF recentCommentItem(SyntaxTree.WithPart).comment = NIL THEN
                                    recentCommentItem(SyntaxTree.WithPart).SetComment(comment)
                                END;
-LYNX *)
                            END;
                            comment.SetItem(recentCommentItem, TRUE);
                            recentComment := NIL;
                            recentCommentItem := NIL
                        END;
                    END;
                END;
                error := ~scanner.GetNextSymbol(symbol);
            END;
        END NextSymbol;

        (** Check if current symbol equals sym. If yes then return true, return false otherwise *)
        PROCEDURE Peek(token: Scanner.Token): BOOLEAN;
            VAR comment: SyntaxTree.Comment;
        BEGIN
            WHILE ~error & (symbol.token = Scanner.Comment) DO
                comment := SyntaxTree.NewComment(symbol.start, currentScope, symbol.string^, symbol.stringLength);
                moduleScope.AddComment(comment);
                IF recentComment = NIL THEN
                    recentComment := comment;
                END;
                error := ~scanner.GetNextSymbol(symbol);
            END;
            RETURN symbol.token = token
        END Peek;

        (** Check if the current symbol equals sym. If yes then read next symbol, report error otherwise. Returns success value *)
        PROCEDURE Mandatory(token: Scanner.Token): BOOLEAN;
        BEGIN
(* @@@ *)
(*
KernelLog.String("Mandatory: want ");
KernelLog.Int(token, 1);
KernelLog.String(" have ");
KernelLog.Int(symbol.token, 1);
KernelLog.Ln();
*)
            (* because of NextSymbol! *)
            ASSERT(token # Scanner.Identifier);
            ASSERT(token # Scanner.IntegerLiteral);
            ASSERT(token # Scanner.RealLiteral);
            ASSERT(token # Scanner.CharacterLiteral);
            ASSERT(token # Scanner.StringLiteral);
            IF ~Peek(token) THEN
                Error(symbol.start, token, "");
                RETURN FALSE
            ELSE
                NextSymbol;
                RETURN TRUE
            END
        END Mandatory;

        (** Check if the current symbol equals sym. If yes then read next symbol, report error otherwise *)
        PROCEDURE Check(token: Scanner.Token);
            VAR b: BOOLEAN;
        BEGIN
            b := Mandatory(token);
        END Check;

        (** Check if current symbol is an identifier. If yes then copy identifier to name and get next symbol,
            report error otherwise and set name to empty name. Returns success value *)
        PROCEDURE MandatoryIdentifier(VAR name: SyntaxTree.Identifier): BOOLEAN;
        BEGIN
            IF Peek(Scanner.Identifier) THEN
                name := symbol.identifier;
                NextSymbol;
                RETURN TRUE
            ELSE
                Error(symbol.start, Scanner.Identifier, "");
                name := SyntaxTree.invalidIdentifier;
                RETURN FALSE
            END
        END MandatoryIdentifier;

        (** Expect an identifier (using MandatoryIdentifier) and return identifier object **)
        PROCEDURE Identifier(VAR position: LONGINT): SyntaxTree.Identifier;
            VAR name: SyntaxTree.Identifier; 
                identifier: SyntaxTree.Identifier;
        BEGIN
            position := symbol.start;
            IF MandatoryIdentifier(name) THEN
                identifier := name;
            ELSE
                identifier := SyntaxTree.invalidIdentifier;
            END;
            RETURN identifier
        END Identifier;

        (** Check if current symbol equals sym. If yes then get next symbol, return false otherwise *)
        PROCEDURE Optional(token: Scanner.Token): BOOLEAN;
        BEGIN
            (* do not use for Identifier or literal if the result is needed ! *)
            IF Peek(token) THEN
                NextSymbol;
                RETURN TRUE
            ELSE
                RETURN FALSE
            END
        END Optional;

        (* ignore one ore more symbols of type token *)
        PROCEDURE Ignore(token: Scanner.Token);
        BEGIN 
            WHILE Optional(token) DO 
                (* void *)
            END;
        END Ignore;

        (** Handling comments **)

        PROCEDURE SetNextInComment(c: SyntaxTree.Comment; this: ANY);
        BEGIN
            WHILE c # NIL DO
                c.SetItem(this, FALSE);
                c := c.nextComment
            END;
        END SetNextInComment;

        PROCEDURE CommentSymbol(symbol: SyntaxTree.Symbol);
        BEGIN
            IF (recentComment # NIL) (* & (recentComment.nextSymbol = NIL) *) THEN
                symbol.SetComment(recentComment);
                SetNextInComment(recentComment, symbol);
                recentComment := NIL
            END;
            recentLine := scanner.line;
            recentCommentItem := symbol;
        END CommentSymbol;

        (** Mapping tokens to AST operators **)

(*
    Mapping table for all punctuation tokens

    Lynx                                     Fox
    ------------------------------------------------------------

    Exclamation* = 1;         (* ! *)        Not
    ExclamationEqual* = 2;    (* != *)       Unequal
    Percent* = 3;             (* % *)        lynx@binop    (rem)
    PercentEqual* = 4;        (* %= *)       lynx@asop     (rem)
    And* = 5;                 (* & *)        lynx@binop    (and)
    AndEqual* = 6;            (* &= *)       lynx@asop     (and)
    AndAnd* = 7;              (* && *)       And
    LeftParenthesis* = 8;     (* ( *)        N/A
    RightParenthesis* = 9;    (* ) *)        N/A
    Times* = 10;              (* * *)        Times  
    TimesEqual* = 11;         (* *= *)       lynx@asop     (mul)
    Plus* = 12;               (* + *)        Plus
    PlusEqual* = 13;          (* += *)       lynx@asop     (add)
    PlusPlus* = 14;           (* ++ *)       lynx@asop     (add)
    Comma* = 15;              (* , *)        N/A
    Minus* = 16;              (* - *)        Minus  
    MinusEqual* = 17;         (* -= *)       lynx@asop     (sub)
    MinusMinus* = 18;         (* -- *)       lynx@asop     (sub)
    Period* = 19;             (* . *)        N/A
    Slash* = 20;              (* / *)        lynx@binop    (div)
    SlashEqual* = 21;         (* /= *)       lynx@asop     (div)
    Colon* = 22;              (* : *)        N/A
    Semicolon* = 23;          (* ; *)        N/A
    Less* = 24;               (* < *)        Less
    LessEqual* = 25;          (* <= *)       LessEqual
    LeftShift* = 26;          (* << *)       lynx@binop    (shl)
    LeftShiftEqual* = 27;     (* <<= *)      lynx@asop     (shl)
    Equal* = 28;              (* = *)        N/A
    EqualEqual* = 29;         (* == *)       Equal
    Greater* = 30;            (* > *)        Greater
    GreaterEqual* = 31;       (* >= *)       GreaterEqual
    RightShift* = 32;         (* >> *)       lynx@binop    (shr)
    RightShiftEqual* = 33;    (* >>= *)      lynx@asop     (shr)
    LeftBracket* = 34;        (* [ *)        N/A
    RightBracket* = 35;       (* ] *)        N/A
    Arrow* = 36;              (* ^ *)        lynx@binop    (xor)
    ArrowEqual* = 37;         (* ^= *)       lynx@asop     (xor)
    LeftBrace* = 38;          (* { *)        N/A
    Bar* = 39;                (* | *)        lynx@binop    (or)
    BarEqual* = 40;           (* |= *)       lynx@asop     (or)
    BarBar* = 41;             (* || *)       Or
    RightBrace* = 42;         (* } *)        N/A
    Tilde* = 43;              (* ~ *)        lynx@unop     (not)
*)

        PROCEDURE MapOperator(token: Scanner.Token): LONGINT;
            VAR operator: LONGINT;
        BEGIN
            CASE token OF
              Scanner.Exclamation:    
                operator := FoxScanner.Not;
            | Scanner.ExclamationEqual:
                operator := FoxScanner.Unequal;
            | Scanner.Percent, Scanner.PercentEqual:
                operator := 256 + Global.LynxOpRem;
            | Scanner.And, Scanner.AndEqual:
                operator := 256 + Global.LynxOpAnd;
            | Scanner.AndAnd:
                operator := FoxScanner.And;
            | Scanner.Times:
                operator := FoxScanner.Times;
            | Scanner.TimesEqual:
                operator := 256 + Global.LynxOpMul;
            | Scanner.Plus:
                operator := FoxScanner.Plus;
            | Scanner.PlusEqual, Scanner.PlusPlus:
                operator := 256 + Global.LynxOpAdd;
            | Scanner.Minus:   
                operator := FoxScanner.Minus;
            | Scanner.MinusEqual, Scanner.MinusMinus:
                operator := 256 + Global.LynxOpSub;
            | Scanner.Slash, Scanner.SlashEqual:
                operator := 256 + Global.LynxOpDiv;
            | Scanner.Less:
                operator := FoxScanner.Less;
            | Scanner.LessEqual:
                operator := FoxScanner.LessEqual;
            | Scanner.LeftShift, Scanner.LeftShiftEqual:
                operator := 256 + Global.LynxOpShl;
            | Scanner.EqualEqual:
                operator := FoxScanner.Equal;
            | Scanner.Greater:
                operator := FoxScanner.Greater;
            | Scanner.GreaterEqual:
                operator := FoxScanner.GreaterEqual;
            | Scanner.RightShift, Scanner.RightShiftEqual:
                operator := 256 + Global.LynxOpShr;
            | Scanner.Arrow, Scanner.ArrowEqual:
                operator := 256 + Global.LynxOpXor;
            | Scanner.Bar, Scanner.BarEqual:
                operator := 256 + Global.LynxOpOr;
            | Scanner.BarBar:
                operator := FoxScanner.Or;
            | Scanner.Tilde:
                operator := 256 + Global.LynxOpNot;
            END;
            RETURN operator;
        END MapOperator;

        PROCEDURE NewUnaryExpression(
                position: LONGINT; 
                operand: SyntaxTree.Expression; 
                operator: LONGINT): SyntaxTree.Expression;
            VAR expressionList: SyntaxTree.ExpressionList;
                expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
        BEGIN
            operator := MapOperator(operator);
            IF operator < 256 THEN
                expression := SyntaxTree.NewUnaryExpression(position, operand, operator);
            ELSE
                expressionList := SyntaxTree.NewExpressionList();
                expression := SyntaxTree.NewIntegerValue(position, operator-256);
                expressionList.AddExpression(expression);
                expressionList.AddExpression(operand);
                designator := SyntaxTree.NewIdentifierDesignator(position, lynxUnop);
                expression := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
            END;
            RETURN expression;
        END NewUnaryExpression;

        PROCEDURE NewBinaryExpression(
                position: LONGINT; 
                left, right: SyntaxTree.Expression; 
                operator: LONGINT): SyntaxTree.Expression;
            VAR expressionList: SyntaxTree.ExpressionList;
                expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
        BEGIN
            operator := MapOperator(operator);
            IF operator < 256 THEN
                expression := SyntaxTree.NewBinaryExpression(position, left, right, operator);
            ELSE
                expressionList := SyntaxTree.NewExpressionList();
                expression := SyntaxTree.NewIntegerValue(position, operator-256);
                expressionList.AddExpression(expression);
                expressionList.AddExpression(left);
                expressionList.AddExpression(right);
                designator := SyntaxTree.NewIdentifierDesignator(position, lynxBinop);
                expression := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
            END;
            RETURN expression;
        END NewBinaryExpression;

        PROCEDURE NewTypeExpression(position: LONGINT): SyntaxTree.Expression;
        BEGIN
            RETURN SyntaxTree.NewIdentifierDesignator(position, lynxType);
        END NewTypeExpression;

        PROCEDURE NewReceiveExpression(
                position: LONGINT; left, right: SyntaxTree.Expression): SyntaxTree.Expression;
            VAR expressionList: SyntaxTree.ExpressionList;
                expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
        BEGIN
            expressionList := SyntaxTree.NewExpressionList();
            expressionList.AddExpression(left);
            expressionList.AddExpression(right);
            designator := SyntaxTree.NewIdentifierDesignator(position, lynxRecvnb);
            expression := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
            RETURN expression;
        END NewReceiveExpression;

        PROCEDURE MapNumberType(numberType: LONGINT): LONGINT;
        BEGIN
            CASE numberType OF
              Scanner.IntNumber:
                numberType := FoxScanner.Longint;
            | Scanner.LongNumber:
                numberType := FoxScanner.Hugeint;
            | Scanner.FloatNumber:
                numberType := FoxScanner.Real;
            | Scanner.DoubleNumber:
                numberType := FoxScanner.Longreal;
            END;
            RETURN numberType;
        END MapNumberType;

        (*
            ACHTUNG: Initializers of members of modules, classes, structs,
                cells, and cellnets are collected in a special statement
                block. This block is inserted as the first statement in
                the corresponding constructors.

            TODO: This feature is not yet implemented. Initializers are 
                collected but not inserted in constructors. Implement what is missing.
        *)

        (* create a statement block to collect initializers *)
        PROCEDURE EnterInit;
            VAR block: SyntaxTree.StatementBlock;
        BEGIN
            block := SyntaxTree.NewStatementBlock(invalidPosition, NIL);
            initOuter := block;
            initStatements := SyntaxTree.NewStatementSequence();
            block.SetStatementSequence(initStatements);
        END EnterInit;

        (** Parsing according to the EBNF **)

        (**
            type-name:
                identifier
                module-name '.' identifier
        **)
        PROCEDURE QualifiedIdentifier(): SyntaxTree.QualifiedIdentifier;
            VAR prefix, suffix: SyntaxTree.Identifier; 
                qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
                position0, position1: LONGINT;
        BEGIN
            IF Trace THEN 
                S("QualifiedIdentifier") 
            END;
            prefix := Identifier(position0);
            IF prefix # SyntaxTree.invalidIdentifier THEN
                IF ~Optional(Scanner.Period) THEN
                    suffix := prefix;
                    prefix := SyntaxTree.invalidIdentifier;    (* empty *)
                ELSE
                    suffix := Identifier(position1);
                END;
                qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(position0, prefix, suffix);
            ELSE
                qualifiedIdentifier := SyntaxTree.invalidQualifiedIdentifier;
            END;
            IF Trace THEN 
                E("QualifiedIdentifier") 
            END;
            RETURN qualifiedIdentifier
        END QualifiedIdentifier;

        (**
            expression-list:
                expression
                expression-list ',' expression
        **)
        PROCEDURE ExpressionList(expressionList: SyntaxTree.ExpressionList);
            VAR expression: SyntaxTree.Expression;
        BEGIN
            IF Trace THEN 
                S("ExpressionList")
            END;
            REPEAT
                expression := Expression();
                expressionList.AddExpression(expression);
            UNTIL ~Optional(Scanner.Comma);
            IF Trace THEN 
                E("ExpressionList")
            END;
        END ExpressionList;

        (**
            argument-list:
                argument
                argument-list ',' argument

            argument:
                expression
               'ref' variable-reference

            variable-reference:
                expression
        **)
        PROCEDURE ArgumentList(expressionList: SyntaxTree.ExpressionList);
            VAR expression: SyntaxTree.Expression;
                modifier: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ArgumentList")
            END;
            REPEAT
                IF Optional(Scanner.Ref) THEN
                    modifier := Scanner.Ref;
                ELSE
                    modifier := -1;
                END;
                (* 
                    ACHTUNG: Modifiers cannot be validated without AST modifications,
                        therefore 'modifier' value is not used in this release.
                *)
                expression := Expression();
                expressionList.AddExpression(expression);
            UNTIL ~Optional(Scanner.Comma);
            IF Trace THEN 
                E("ArgumentList")
            END;
        END ArgumentList;

        (**
            primary-expression:
                array-creation-expression
                primary-no-array-creation-expression

            primary-no-array-creation-expression:
                literal
                simple-name
                parenthesized-expression
                member-access
                invocation-expression
                element-access
                this-access
                base-access
                object-creation-expression
                delegate-creation-expression
                receive-expression

            literal:
                boolean-literal
                integer-literal
                real-literal
                character-literal
                string-literal
                null-literal

            boolean-literal:
                'true'
                'false'

            null-literal:
                'null'

            simple-name:
                identifier

            parenthesized-expression:
                '(' expression ')'

            member-access:
                primary-expression '.' identifier

            invocation-expression:
                primary-expression '(' [argument-list] ')'

            element-access:
                primary-no-array-creation-expression '[' expression-list ']'

            this-access:
                'this'

            base-access:
                'base' '.' identifier

            object-creation-expression:
                'new' non-array-type '(' [argument-list] ')'

            array-creation-expression:
                'new' non-array-type '[' expression-list ']' [rank-specifiers]

            delegate-creation-expression:
                'new' delegate-type '(' expression ')'

            receive-expression:
                primary-expression '??' primary-expression
        **)
        PROCEDURE Accessors(expression: SyntaxTree.Expression; arrayCreation: BOOLEAN): SyntaxTree.Expression;
            VAR identifier: SyntaxTree.Identifier;
                expressionList: SyntaxTree.ExpressionList;
                position: LONGINT;
        BEGIN
            LOOP
                position := symbol.start;
                IF Optional(Scanner.Period) THEN
                    identifier := Identifier(position);
                    expression := SyntaxTree.NewSelectorDesignator(position, expression(SyntaxTree.Designator), identifier);
                ELSIF Optional(Scanner.LeftParenthesis) THEN
                    expressionList := SyntaxTree.NewExpressionList();
                    IF ~Optional(Scanner.RightParenthesis) THEN
                        ArgumentList(expressionList);
                        Check(Scanner.RightParenthesis);
                    END;
                    expression := SyntaxTree.NewParameterDesignator(position, expression(SyntaxTree.Designator), expressionList);
                ELSIF (~arrayCreation) & Optional(Scanner.LeftBracket) THEN
                    expressionList := SyntaxTree.NewExpressionList();
                    ExpressionList(expressionList);
                    Check(Scanner.RightBracket);
(* ACHTUNG: 27-09-2012
                    expression := SyntaxTree.NewArrowDesignator(position, expression);
*)
                    expression := SyntaxTree.NewBracketDesignator(position, expression(SyntaxTree.Designator), expressionList);
                ELSE
                    EXIT;
                END;
            END;
            RETURN expression;
        END Accessors;

        PROCEDURE PrimaryExpression(): SyntaxTree.Expression;
            VAR expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
                realValue: SyntaxTree.RealValue;
                identifier: SyntaxTree.Identifier;
                type: SyntaxTree.Type;
                typeExpression: SyntaxTree.Expression;
                expressionList: SyntaxTree.ExpressionList;
                position: LONGINT;
                arrayCreation: BOOLEAN;
                arrayType: SyntaxTree.ArrayType;
                pointerType: SyntaxTree.PointerType;
                rightExpression: SyntaxTree.Expression;
                i, n: LONGINT;
        BEGIN
            IF Trace THEN 
                S("PrimaryExpression")
            END;

            position := symbol.start;
            arrayCreation := FALSE;

            IF Peek(Scanner.True) THEN
                expression := SyntaxTree.NewBooleanValue(position, TRUE);
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Peek(Scanner.False) THEN
                expression := SyntaxTree.NewBooleanValue(position, FALSE);
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Peek(Scanner.IntegerLiteral) THEN
                IF symbol.numberType = Scanner.IntNumber THEN
                    expression := SyntaxTree.NewIntegerValue(position, symbol.integer);
                    expression.End(symbol.end);
                ELSIF symbol.numberType = Scanner.LongNumber THEN
                    expression := SyntaxTree.NewIntegerValue(position, symbol.hugeint);
                    expression.End(symbol.end);
                ELSE
                    HALT(100);
                END;
                NextSymbol;
            ELSIF Peek(Scanner.RealLiteral) THEN
                realValue := SyntaxTree.NewRealValue(position, symbol.real);
                realValue.SetSubtype(MapNumberType(symbol.numberType));
                expression := realValue;
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Peek(Scanner.CharacterLiteral) THEN
                expression := SyntaxTree.NewCharacterValue(position, symbol.character);
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Peek(Scanner.StringLiteral) THEN
                (* 
                    TODO: Revise this: may need a string constructor wrapper ...
                          ... and symbol.stringLength may be important too 
                *)
                expression := SyntaxTree.NewStringValue(position, symbol.string);
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Peek(Scanner.Identifier) THEN
                identifier := Identifier(position);
                identifier := localIdentTable.Find(identifier);
                expression := SyntaxTree.NewIdentifierDesignator(position, identifier);
            ELSIF Peek(Scanner.Null) THEN
                expression := SyntaxTree.NewNilValue(position);
                expression.End(symbol.end);
                NextSymbol;
            ELSIF Optional(Scanner.LeftParenthesis) THEN
                expression := Expression();
                Check(Scanner.RightParenthesis);
            ELSIF Optional(Scanner.This) THEN
                expression := SyntaxTree.NewSelfDesignator(position);
            ELSIF Optional(Scanner.Base) THEN
                Check(Scanner.Period);
                position := symbol.start;
                identifier := Identifier(position);
                expression := SyntaxTree.NewIdentifierDesignator(position, identifier);
                expression := SyntaxTree.NewArrowDesignator(position, expression(SyntaxTree.Designator));
            ELSIF Optional(Scanner.New) THEN
                type := NonArrayType();
                expressionList := SyntaxTree.NewExpressionList();
                typeExpression := NewTypeExpression(position);
                expressionList.AddExpression(typeExpression);
                IF Optional(Scanner.LeftBracket) THEN
                    arrayCreation := TRUE;
                    ExpressionList(expressionList);
                    Check(Scanner.RightBracket);
                    WHILE Optional(Scanner.LeftBracket) DO
                        type := RankSpecifier(type);
                        Check(Scanner.RightBracket);
                    END;
                    n := expressionList.Length() - 1;
                    FOR i := 1 TO n DO
                        arrayType := SyntaxTree.NewArrayType(position, currentScope, SyntaxTree.Open);
                        arrayType.SetArrayBase(type);
                        type := arrayType;
                    END;
                    pointerType := SyntaxTree.NewPointerType(position, currentScope);
                    pointerType.SetPointerBase(type);
                    type := pointerType;
                END;
                typeExpression.SetType(type);
                IF ~arrayCreation THEN
                    Check(Scanner.LeftParenthesis);
                    IF ~Optional(Scanner.RightParenthesis) THEN
                        ArgumentList(expressionList);
                        Check(Scanner.RightParenthesis);
                    END;
                    designator := SyntaxTree.NewIdentifierDesignator(position, lynxNewobj);
                    expression := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
                ELSE
                    designator := SyntaxTree.NewIdentifierDesignator(position, lynxNewarr);
                    expression := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
                END;
             ELSE
                Error(symbol.start, Diagnostics.Invalid, "Invalid primary expression");
                NextSymbol;
                expression := SyntaxTree.invalidExpression;
            END;

            expression := Accessors(expression, arrayCreation);

            position := symbol.start;
            IF Optional(Scanner.QuestionQuestion) THEN
                rightExpression := PrimaryExpression();
                expression := NewReceiveExpression(position, expression, rightExpression);
            END;

            IF Trace THEN 
                E("PrimaryExpression")
            END;
            RETURN expression;
        END PrimaryExpression;

        (**
            unary-expression:
                primary-expression
                '+' unary-expression
                '-' unary-expression
                '!' unary-expression
                '~' unary-expression
                cast-expression
        **)
        PROCEDURE UnaryExpression(): SyntaxTree.Expression;
            VAR expression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("UnaryExpression")
            END;
            position := symbol.start;
            IF Peek(Scanner.Plus) OR Peek(Scanner.Minus) OR 
                    Peek(Scanner.Exclamation) OR Peek(Scanner.Tilde) THEN
                operator := symbol.token;
                NextSymbol;
                expression := UnaryExpression();
                expression := NewUnaryExpression(position, expression, operator);
            ELSE
                (* TODO: Implement cast-expression *)
                expression := PrimaryExpression();
            END;
            IF Trace THEN 
                E("UnaryExpression")
            END;
            RETURN expression;
        END UnaryExpression;

        (**
            multiplicative-expression:
                unary-expression
                multiplicative-expression '*' unary-expression
                multiplicative-expression '/' unary-expression
                multiplicative-expression '%' unary-expression
        **)
        PROCEDURE MultiplicativeExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("MultiplicativeExpression")
            END;
            position := symbol.start;
            expression := UnaryExpression();
            WHILE Peek(Scanner.Times) OR Peek(Scanner.Slash) OR Peek(Scanner.Percent) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := UnaryExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("MultiplicativeExpression")
            END;
            RETURN expression;
        END MultiplicativeExpression;

        (**
            additive-expression:
                multiplicative-expression
                additive-expression '+' multiplicative-expression
                additive-expression '' multiplicative-expression
        **)
        PROCEDURE AdditiveExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("AdditiveExpression")
            END;
            position := symbol.start;
            expression := MultiplicativeExpression();
            WHILE Peek(Scanner.Plus) OR Peek(Scanner.Minus) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := MultiplicativeExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("AdditiveExpression")
            END;
            RETURN expression;
        END AdditiveExpression;

        (**
            shift-expression:
                additive-expression
                shift-expression '<<' additive-expression
                shift-expression '>>' additive-expression
        **)
        PROCEDURE ShiftExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ShiftExpression")
            END;
            position := symbol.start;
            expression := AdditiveExpression();
            WHILE Peek(Scanner.LeftShift) OR Peek(Scanner.RightShift) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := AdditiveExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("ShiftExpression")
            END;
            RETURN expression;
        END ShiftExpression;

        (**
            relational-expression:
                shift-expression
                relational-expression '<' shift-expression
                relational-expression '>' shift-expression
                relational-expression '<=' shift-expression
                relational-expression '>=' shift-expression
                relational-expression 'is' type-name
                relational-expression 'as' type-name
        **)
        PROCEDURE RelationalExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("RelationalExpression")
            END;
            position := symbol.start;
            expression := ShiftExpression();
            WHILE Peek(Scanner.Less) OR Peek(Scanner.Greater) OR
                    Peek(Scanner.LessEqual) OR Peek(Scanner.GreaterEqual) OR
                    Peek(Scanner.Is) OR Peek(Scanner.As) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := ShiftExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("RelationalExpression")
            END;
            RETURN expression;
        END RelationalExpression;

        (**
            equality-expression:
                relational-expression
                equality-expression '==' relational-expression
                equality-expression '!=' relational-expression
        **)
        PROCEDURE EqualityExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("EqualityExpression")
            END;
            position := symbol.start;
            expression := RelationalExpression();
            WHILE Peek(Scanner.EqualEqual) OR Peek(Scanner.ExclamationEqual) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := RelationalExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("EqualityExpression")
            END;
            RETURN expression;
        END EqualityExpression;

        (**
            and-expression:
                equality-expression
                and-expression '&' equality-expression
        **)
        PROCEDURE AndExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("AndExpression")
            END;
            position := symbol.start;
            expression := EqualityExpression();
            WHILE Peek(Scanner.And) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := EqualityExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("AndExpression")
            END;
            RETURN expression;
        END AndExpression;

        (**
            exclusive-or-expression:
                and-expression
                exclusive-or-expression '^' and-expression
        **)
        PROCEDURE ExclusiveOrExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ExclusiveOrExpression")
            END;
            position := symbol.start;
            expression := AndExpression();
            WHILE Peek(Scanner.Arrow) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := AndExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("ExclusiveOrExpression")
            END;
            RETURN expression;
        END ExclusiveOrExpression;

        (**
            inclusive-or-expression:
                exclusive-or-expression
                inclusive-or-expression '|' exclusive-or-expression
        **)
        PROCEDURE InclusiveOrExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("InclusiveOrExpression")
            END;
            position := symbol.start;
            expression := ExclusiveOrExpression();
            WHILE Peek(Scanner.Bar) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := ExclusiveOrExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("InclusiveOrExpression")
            END;
            RETURN expression;
        END InclusiveOrExpression;

        (**
            conditional-and-expression:
                inclusive-or-expression
                conditional-and-expression '&&' inclusive-or-expression
        **)
        PROCEDURE ConditionalAndExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ConditionalAndExpression")
            END;
            position := symbol.start;
            expression := InclusiveOrExpression();
            WHILE Peek(Scanner.AndAnd) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := InclusiveOrExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("ConditionalAndExpression")
            END;
            RETURN expression;
        END ConditionalAndExpression;

        (**
            conditional-or-expression:
                conditional-and-expression
                conditional-or-expression '||' conditional-and-expression
        **)
        PROCEDURE ConditionalOrExpression(): SyntaxTree.Expression;
            VAR expression, rightExpression: SyntaxTree.Expression;
                operator: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ConditionalOrExpression")
            END;
            position := symbol.start;
            expression := ConditionalAndExpression();
            WHILE Peek(Scanner.BarBar) DO
                operator := symbol.token;
                NextSymbol;
                rightExpression := ConditionalAndExpression();
                expression := NewBinaryExpression(position, expression, rightExpression, operator);
            END;
            IF Trace THEN 
                E("ConditionalOrExpression")
            END;
            RETURN expression;
        END ConditionalOrExpression;

        (**
            expression:
                conditional-expression

            conditional-expression:
                conditional-or-expression
        **)
        PROCEDURE Expression(): SyntaxTree.Expression;
            VAR expression: SyntaxTree.Expression;
        BEGIN
            IF Trace THEN 
                S("Expression")
            END;
            expression := ConditionalOrExpression();
            IF Trace THEN 
                E("Expression")
            END;
            RETURN expression;
        END Expression;

        (**
            local-variable-declaration:
                type local-variable-declarators
        **)
        PROCEDURE LocalVariableDeclaration(
                statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement; type: SyntaxTree.Type);
            VAR previousStatements: SyntaxTree.StatementSequence;
                previousOuter: SyntaxTree.Statement;
        BEGIN
            IF Trace THEN 
                S("LocalVariableDeclaration")
            END;
            previousStatements := initStatements;
            previousOuter := initOuter;
            initStatements := statements;
            initOuter := outer;
            IF type = NIL THEN
                type := Type();
            END;
            REPEAT
                VariableDeclarator(currentScope, {}, type, SyntaxTree.invalidIdentifier, invalidPosition);
            UNTIL ~Optional(Scanner.Comma);
            initStatements := previousStatements;
            initOuter := previousOuter;
            IF Trace THEN 
                E("LocalVariableDeclaration")
            END;
        END LocalVariableDeclaration;

        (**
            local-constant-declaration:
                'const' type constant-declarators
        **)
        PROCEDURE LocalConstantDeclaration(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR type: SyntaxTree.Type;
        BEGIN
            (* ACHTUNG: Parameters 'statements' and 'outer' are not used *)
            IF Trace THEN 
                S("LocalConstantDeclaration")
            END;
            type := Type();
            REPEAT
                ConstantDeclarator(currentScope, {}, type);
            UNTIL ~Optional(Scanner.Comma);
            IF Trace THEN 
                E("LocalConstantDeclaration")
            END;
        END LocalConstantDeclaration;

        (**
            block:
                '{' [statement-list] '}'

        **)
        PROCEDURE Block(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR block: SyntaxTree.StatementBlock;
        BEGIN
            IF Trace THEN 
                S("Block")
            END;
            Check(Scanner.LeftBrace);
            block := SyntaxTree.NewStatementBlock(symbol.end, outer);
            (* CommentStatement(block); *)
            IF ~Optional(Scanner.RightBrace) THEN
                localIdentTable.OpenScope;
                block.SetStatementSequence(StatementList(block));
                localIdentTable.CloseScope;
                Check(Scanner.RightBrace);
            END;
            statements.AddStatement(block);
            IF Trace THEN 
                E("Block")
            END;
        END Block;

        (**
            expression-statement:
                statement-expression ';'

            statement-expression:
                invocation-expression
                assignment
                post-increment-expression
                post-decrement-expression
                send-expression
                receive-expression
                connect-expression
                delegate-expression

            assignment:
                primary-expression assignment-operator expression

            assignment-operator: one of
                '=' '+=' '-=' '*=' '/=' '%=' '&=' '|=' '^=' '<<=' '>>='

            post-increment-expression:
                primary-expression '++'

            post-decrement-expression:
                primary-expression '--'

            send-expression:
                primary-expression '!' expression-list

            receive-expression:
                primary-expression '?' expression-list

            connect-expression:
                primary-expression '>>' primary-expression

            delegate-expression:
                primary-expression '<=' primary-expression
        **)
        PROCEDURE NewAsopStatement(
                position: LONGINT;
                operator: LONGINT;
                left: SyntaxTree.Designator;
                right: SyntaxTree.Expression;
                outer: SyntaxTree.Statement): SyntaxTree.Statement;
            VAR expressionList: SyntaxTree.ExpressionList;
                expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
        BEGIN
            operator := MapOperator(operator);
            ASSERT(operator >= 256);
            expressionList := SyntaxTree.NewExpressionList();
            expression := SyntaxTree.NewIntegerValue(position, operator-256);
            expressionList.AddExpression(expression);
            expressionList.AddExpression(left);
            expressionList.AddExpression(right);
            designator := SyntaxTree.NewIdentifierDesignator(position, lynxAsop);
            designator := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
            RETURN SyntaxTree.NewProcedureCallStatement(designator.position, designator, outer);
        END NewAsopStatement;

(* ACHTUNG: LYNX 15-MAY-2013 *)
        PROCEDURE PatchPortReference(expression: SyntaxTree.Expression): SyntaxTree.Expression;
            VAR result: SyntaxTree.Expression;
                parameterDesignator: SyntaxTree.ParameterDesignator;
                parameters: SyntaxTree.ExpressionList;
                p0: SyntaxTree.Expression;
                identifierDesignator: SyntaxTree.IdentifierDesignator;
                bracketDesignator: SyntaxTree.BracketDesignator;
                left, left2: SyntaxTree.Expression;
        BEGIN
            IF ~(expression IS SyntaxTree.ParameterDesignator) THEN
                result := expression;
            ELSE
                parameterDesignator := expression(SyntaxTree.ParameterDesignator);
                parameters := parameterDesignator.parameters;
                IF parameters.Length() # 1 THEN
                    result := expression;
                ELSE
                    p0 := parameters.GetExpression(0);
                    IF p0 IS SyntaxTree.IdentifierDesignator THEN
                        (* C(P) -> C.P *)
                        left := parameterDesignator.left;
                        identifierDesignator := p0(SyntaxTree.IdentifierDesignator);
                        result := 
                            SyntaxTree.NewSelectorDesignator(
                                expression.position, left(SyntaxTree.Designator), identifierDesignator.identifier);
                    ELSIF p0 IS SyntaxTree.BracketDesignator THEN
                        bracketDesignator := p0(SyntaxTree.BracketDesignator);
                        left2 := bracketDesignator.left; 
                        IF left2 IS SyntaxTree.IdentifierDesignator THEN
                            (* C(P[I]) -> C.P[I] *)
                            left := parameterDesignator.left;
                            identifierDesignator := left2(SyntaxTree.IdentifierDesignator);
                            result :=
                                SyntaxTree.NewBracketDesignator(
                                    expression.position,
                                    SyntaxTree.NewSelectorDesignator(
                                        expression.position, 
                                        left(SyntaxTree.Designator), 
                                        identifierDesignator.identifier),
                                    bracketDesignator.parameters);
                        ELSE                    
                            result := expression;
                        END;
                    ELSE
                        result := expression;
                    END;
                END;
            END;
            RETURN result;
        END PatchPortReference;

        PROCEDURE NewPortStatement(
                position: LONGINT;
                name: SyntaxTree.Identifier;
                left: SyntaxTree.Designator;
                right: SyntaxTree.Expression;
                outer: SyntaxTree.Statement): SyntaxTree.Statement;
            VAR expressionList: SyntaxTree.ExpressionList;
                designator: SyntaxTree.Designator;
        BEGIN
            expressionList := SyntaxTree.NewExpressionList();
            expressionList.AddExpression(left);
            expressionList.AddExpression(right);
            designator := SyntaxTree.NewIdentifierDesignator(position, name);
            designator := SyntaxTree.NewParameterDesignator(position, designator, expressionList);
            RETURN SyntaxTree.NewProcedureCallStatement(designator.position, designator, outer);
        END NewPortStatement; 

        PROCEDURE StatementExpression(
                statements: SyntaxTree.StatementSequence; 
                outer: SyntaxTree.Statement;
                expression: SyntaxTree.Expression): BOOLEAN;
            VAR designator: SyntaxTree.Designator;
                expressionList: SyntaxTree.ExpressionList;
                statement: SyntaxTree.Statement;
                operator: LONGINT;
                position: LONGINT;
                length, i: LONGINT;
                temp: SyntaxTree.Expression;
        BEGIN
            IF Trace THEN 
                S("StatementExpression")
            END;
            (* ACHTUNG: Only expressions of type SyntaxTree.Designator are supported
                   in place of primary-expression in the above productions. This is
                   required for compatibility with Fox back-end *)
            statement := NIL;
            position := symbol.start;
            IF expression = NIL THEN
                expression := PrimaryExpression();
            END;
            IF ~(expression IS SyntaxTree.Designator) THEN
                Error(position, Diagnostics.Invalid, "Invalid expression statement");
            ELSE
                designator := expression(SyntaxTree.Designator);
                position := symbol.start;
                IF Optional(Scanner.Equal) THEN
                    expression := Expression();
                    statement := SyntaxTree.NewAssignment(position, designator, expression, outer);
                ELSIF Peek(Scanner.PlusEqual) OR Peek(Scanner.MinusEqual) OR
                        Peek(Scanner.TimesEqual) OR Peek(Scanner.SlashEqual) OR
                        Peek(Scanner.PercentEqual) OR Peek(Scanner.AndEqual) OR
                        Peek(Scanner.BarEqual) OR Peek(Scanner.ArrowEqual) OR
                        Peek(Scanner.LeftShiftEqual) OR Peek(Scanner.RightShiftEqual) THEN
                    operator := symbol.token;
                    NextSymbol;
                    (* lynx@asop(operator, designator, expression) *)
                    expression := Expression();
                    statement := NewAsopStatement(position, operator, designator, expression, outer);
                ELSIF Optional(Scanner.PlusPlus) THEN
                    (* lynx@asop(PlusEqual, designator, 1) *)
                    operator := Scanner.PlusPlus;
                    expression := SyntaxTree.NewIntegerValue(position, 1);
                    statement := NewAsopStatement(position, operator, designator, expression, outer);
                ELSIF Optional(Scanner.MinusMinus) THEN
                    (* lynx@asop(MinusEqual, designator, 1) *)
                    operator := Scanner.MinusMinus;
                    expression := SyntaxTree.NewIntegerValue(position, 1);
                    statement := NewAsopStatement(position, operator, designator, expression, outer);
(* ACHTUNG: LYNX 15-MAY-2013
               ELSIF Optional(Scanner.Exclamation) THEN
                    (* lynx@send(designator, expression) *)
                    expression := Expression();
                    statement := NewPortStatement(position, lynxSend, designator, expression, outer);
                ELSIF Optional(Scanner.Question) THEN
                    (* lynx@receive(designator, expression) *)
                    expression := Expression();
                    statement := NewPortStatement(position, lynxReceive, designator, expression, outer);
*)
               ELSIF Optional(Scanner.Exclamation) THEN
                    (* lynx@send(designator, expression) *)
                    expressionList := SyntaxTree.NewExpressionList();
                    ExpressionList(expressionList);
                    length := expressionList.Length();
                    FOR i := 0 TO length - 1 DO
                        expression := expressionList.GetExpression(i);
                        statement := NewPortStatement(position, lynxSend, designator, expression, outer);
                        IF i < length - 1 THEN
                            statements.AddStatement(statement);
                        END;
                    END;
                ELSIF Optional(Scanner.Question) THEN
                    (* lynx@receive(designator, expression) *)
                    expressionList := SyntaxTree.NewExpressionList();
                    ExpressionList(expressionList);
                    length := expressionList.Length();
                    FOR i := 0 TO length - 1 DO
                        expression := expressionList.GetExpression(i);
                        statement := NewPortStatement(position, lynxReceive, designator, expression, outer);
                        IF i < length - 1 THEN
                            statements.AddStatement(statement);
                        END;
                    END;
(* ACHTUNG: LYNX 15-MAY-2013
                ELSIF Optional(Scanner.RightShift) THEN
                    (* lynx@connect(designator, expression) *)
                    expression := PrimaryExpression();
                    statement := NewPortStatement(position, lynxConnect, designator, expression, outer);
                ELSIF Optional(Scanner.LessEqual) THEN
                    (* lynx@delegate(designator, expression) *)
                    expression := PrimaryExpression();
                    statement := NewPortStatement(position, lynxDelegate, designator, expression, outer);
*)
                ELSIF Optional(Scanner.RightShift) THEN
                    (* lynx@connect(designator, expression) *)
                    expression := PrimaryExpression();
                    temp := PatchPortReference(designator);
                    designator := temp(SyntaxTree.Designator);
                    expression := PatchPortReference(expression);
                    statement := NewPortStatement(position, lynxConnect, designator, expression, outer);
                ELSIF Optional(Scanner.LessEqual) THEN
                    (* lynx@delegate(designator, expression) *)
                    expression := PrimaryExpression();
                    temp := PatchPortReference(designator);
                    designator := temp(SyntaxTree.Designator);
                    expression := PatchPortReference(expression);
                    statement := NewPortStatement(position, lynxDelegate, designator, expression, outer);
                ELSIF designator IS SyntaxTree.ParameterDesignator THEN
                    statement := SyntaxTree.NewProcedureCallStatement(designator.position, designator, outer);
                ELSE
                    Error(position, Diagnostics.Invalid, "Invalid expression statement");
                END;
            END;
            IF statement # NIL THEN
                (* CommentStatement(statement); *)
                statements.AddStatement(statement);
            END;
            IF Trace THEN 
                E("StatementExpression")
            END;
            RETURN statement # NIL;
        END StatementExpression;

        PROCEDURE ExpressionStatement(
                statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
            VAR b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("ExpressionStatement")
            END;
            b := StatementExpression(statements, outer, NIL);
            Check(Scanner.Semicolon);
            IF Trace THEN 
                E("ExpressionStatement")
            END;
            RETURN b;
        END ExpressionStatement;

        (**
            if-statement:
                'if' '(' boolean-expression ')' embedded-statement
                'if' '(' boolean-expression ')' embedded-statement 'else' embedded-statement
        **)
        PROCEDURE IfStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR expression: SyntaxTree.Expression;
                ifStatement: SyntaxTree.IfStatement;
                elsePart: SyntaxTree.IfPart;
                statementSequence: SyntaxTree.StatementSequence;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("IfStatement")
            END;
            Check(Scanner.If);
            ifStatement := SyntaxTree.NewIfStatement(symbol.start, outer);
            (* CommentStatement(ifStatement); *)
            Check(Scanner.LeftParenthesis);
            expression := Expression();
            Check(Scanner.RightParenthesis);
            ifStatement.ifPart.SetCondition(expression);
            statementSequence := SyntaxTree.NewStatementSequence();
            b := EmbeddedStatement(statementSequence, ifStatement);
            ifStatement.ifPart.SetStatements(statementSequence);
            IF Optional(Scanner.Else) THEN
                statementSequence := SyntaxTree.NewStatementSequence();
                b := EmbeddedStatement(statementSequence, ifStatement);
                ifStatement.SetElsePart(statementSequence);
            END;
            statements.AddStatement(ifStatement);
            IF Trace THEN 
                E("IfStatement")
            END;
        END IfStatement;

        (**
            switch-statement:
                'switch' '(' expression ')' switch-block

            switch-block:
                '{' [switch-sections] '}'


            switch-sections:
                switch-section
                switch-sections switch-section

            switch-section:
                switch-labels statement-list

            switch-labels:
                switch-label
                switch-labels switch-label

            switch-label:
                'case' constant-expression ':'
                'default' ':'
        **)
        PROCEDURE SwitchSection(caseStatement: SyntaxTree.CaseStatement; VAR haveDefault: BOOLEAN);
            VAR casePart: SyntaxTree.CasePart;
                statements: SyntaxTree.StatementSequence;
                last: SyntaxTree.Statement;
                element: SyntaxTree.Expression;
                defaultSection: BOOLEAN;
                length, position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("SwitchSection")
            END;
            casePart := SyntaxTree.NewCasePart();
            defaultSection := FALSE;
            WHILE Peek(Scanner.Case) OR Peek(Scanner.Default) DO
                (* CommentCasePart(casePart); *)
                IF Optional(Scanner.Case) THEN
                    element := Expression();
                    Check(Scanner.Colon);
                    casePart.elements.AddExpression(element);
                ELSE
                    position := symbol.start;
                    Check(Scanner.Default);
                    Check(Scanner.Colon);
                    IF haveDefault THEN
                        Error(position, Diagnostics.Invalid, "Duplicate default label");
                    ELSE
                        defaultSection := TRUE;
                        haveDefault := TRUE;
                    END;
                END;
            END;
            statements := StatementList(caseStatement);
            length := statements.Length();
            IF length = 0 THEN
                Error(symbol.start, Diagnostics.Invalid, "Fall through in switch section");
            ELSE
                last := statements.GetStatement(length-1);
                IF last IS SyntaxTree.ExitStatement THEN
                    statements.RemoveStatement(last);
                ELSIF ~(last IS SyntaxTree.ReturnStatement) THEN
                    Error(symbol.start, Diagnostics.Invalid, "Fall through in switch section");
                END;
            END;
            IF ~defaultSection THEN
                casePart.SetStatements(statements);
                caseStatement.AddCasePart(casePart);
            ELSE
                (* ignore case labels, if any *)
                (* ACHTUNG: these labels will not be checked for duplicates *)
                caseStatement.SetElsePart(statements);
            END;
            IF Trace THEN 
                E("SwitchSection")
            END;
        END SwitchSection;

        PROCEDURE SwitchStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR expression: SyntaxTree.Expression;
                caseStatement: SyntaxTree.CaseStatement;
                haveDefault: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("SwitchStatement")
            END;
            Check(Scanner.Switch);
            caseStatement := SyntaxTree.NewCaseStatement(symbol.start, outer);
            (* CommentStatement(caseStatement); *)
            Check(Scanner.LeftParenthesis);
            expression := Expression();
            Check(Scanner.RightParenthesis);
            caseStatement.SetVariable(expression);
            Check(Scanner.LeftBrace);
            haveDefault := FALSE;
            WHILE Peek(Scanner.Case) OR Peek(Scanner.Default) DO
                SwitchSection(caseStatement, haveDefault);
            END;
            Check(Scanner.RightBrace);
            statements.AddStatement(caseStatement);
            IF Trace THEN 
                E("SwitchStatement")
            END;
        END SwitchStatement;

        (**
            select-statement:
                'select' select-block

            select-block:
                '{' select-sections '}'

            select-sections:
                select-section
                select-sections select-section

            select-section:
                select-label statement-list

            select-label:
                'case' [select-replicator] primary-expression '?' primary-expression ':'

            select-replicator:
                '(' integral-type simple-name 'in' expression ':' expression ')'
        **)

        (**
            Fox mapping schema:

            // LYNX

            select {
            case c ? x:
                S1;
            case (int i in m : n) d[i] ? y:
                S2;
            }

            // Fox

            lynx@newsel;
            lynx@addsel(0, 0, c);
            FOR i := m TO n DO
                lynx@addsel(1, i, d[i])
            END;
            CASE lynx@select() OF
              0:
                c ? x;
                S1;
            | 1:
                i := lynx@selidx();
                d[i] ? y;
                S2;
            END;
        **)

        PROCEDURE NewLynxNewsel(
                position: LONGINT; outer: SyntaxTree.Statement): SyntaxTree.Statement;
            VAR parameters: SyntaxTree.ExpressionList;
                designator: SyntaxTree.Designator;
        BEGIN
            parameters := SyntaxTree.NewExpressionList();
            designator := SyntaxTree.NewIdentifierDesignator(position, lynxNewsel);
            designator := SyntaxTree.NewParameterDesignator(position, designator, parameters);
            RETURN SyntaxTree.NewProcedureCallStatement(position, designator, outer);
        END NewLynxNewsel;

        PROCEDURE NewLynxAddsel(
                position: LONGINT;
                index: LONGINT;
                variable: SyntaxTree.Identifier;
                channel: SyntaxTree.Expression;
                outer: SyntaxTree.Statement): SyntaxTree.Statement;
            VAR parameters: SyntaxTree.ExpressionList;
                designator: SyntaxTree.Designator;
        BEGIN
            parameters := SyntaxTree.NewExpressionList();
            parameters.AddExpression(SyntaxTree.NewIntegerValue(position, index));
            IF variable # SyntaxTree.invalidIdentifier THEN
                parameters.AddExpression(
                    SyntaxTree.NewIdentifierDesignator(position, variable));
            ELSE
                parameters.AddExpression(SyntaxTree.NewIntegerValue(position, 0));
            END;
            parameters.AddExpression(channel);
            designator := SyntaxTree.NewIdentifierDesignator(position, lynxAddsel);
            designator := SyntaxTree.NewParameterDesignator(position, designator, parameters);
            RETURN SyntaxTree.NewProcedureCallStatement(position, designator, outer);
        END NewLynxAddsel;

        PROCEDURE NewLynxSelect(position: LONGINT): SyntaxTree.Expression;
            VAR left: SyntaxTree.Designator;
                parameters: SyntaxTree.ExpressionList;
        BEGIN
            left := SyntaxTree.NewIdentifierDesignator(position, lynxSelect);
            parameters := SyntaxTree.NewExpressionList();
            RETURN SyntaxTree.NewParameterDesignator(position, left, parameters);
        END NewLynxSelect;

        PROCEDURE NewLynxSelidx(
                position: LONGINT; 
                variable: SyntaxTree.Identifier;
                outer: SyntaxTree.Statement): SyntaxTree.Statement;
            VAR left: SyntaxTree.Designator;
                parameters: SyntaxTree.ExpressionList;
                right: SyntaxTree.Expression;
        BEGIN
            left := SyntaxTree.NewIdentifierDesignator(position, lynxSelidx);
            parameters := SyntaxTree.NewExpressionList();
            right := SyntaxTree.NewParameterDesignator(position, left, parameters);
            left := SyntaxTree.NewIdentifierDesignator(position, variable);
            RETURN SyntaxTree.NewAssignment(position, left, right, outer);
        END NewLynxSelidx;

        PROCEDURE SelectSection(
                statements: SyntaxTree.StatementSequence; 
                caseStatement: SyntaxTree.CaseStatement;
                index: LONGINT;
                outer: SyntaxTree.Statement);
            VAR typename, varname: SyntaxTree.Identifier;
                type: SyntaxTree.Type;
                variable: SyntaxTree.Variable;
                position: LONGINT;
                from, to: SyntaxTree.Expression;
                channel, target: SyntaxTree.Expression;
                statement: SyntaxTree.Statement;
                forStatement: SyntaxTree.ForStatement;
                forBody: SyntaxTree.StatementSequence;
                designator: SyntaxTree.Designator;
                casePart: SyntaxTree.CasePart;
                caseBody: SyntaxTree.StatementSequence;
                length: LONGINT;
                last: SyntaxTree.Statement;
        BEGIN
            IF Trace THEN 
                S("SelectSection")
            END;
            position := symbol.start;
            Check(Scanner.Case);
            localIdentTable.OpenScope;
            IF Optional(Scanner.LeftParenthesis) THEN
                IF Optional(Scanner.Sbyte) THEN
                    typename := lynxSbyte;
                ELSIF Optional(Scanner.Short) THEN
                    typename := lynxShort;
                ELSIF Optional(Scanner.Int) THEN
                    typename := lynxInt;
                ELSIF Optional(Scanner.Long) THEN
                    typename := lynxLong;
                ELSE
                    Error(position, Diagnostics.Invalid, "Missing integral type specifier");
                    typename := lynxInt;
                END;
                type := 
                    SyntaxTree.NewQualifiedType(
                        position, 
                        currentScope,
                        SyntaxTree.NewQualifiedIdentifier(
                            position, SyntaxTree.invalidIdentifier, typename));
                varname := Identifier(position);
                varname := localIdentTable.Enter(varname);
                variable := SyntaxTree.NewVariable(position, varname);
                CommentSymbol(variable);
                variable.SetType(type);
                currentScope.AddVariable(variable);
                Check(Scanner.In);
                from := Expression();
                Check(Scanner.Colon);
                to := Expression();
                Check(Scanner.RightParenthesis);
            ELSE
                varname := SyntaxTree.invalidIdentifier;
            END;
            channel := PrimaryExpression();
            Check(Scanner.Question);
            target := PrimaryExpression();
            Check(Scanner.Colon);

            (* prolog *)
            IF varname = SyntaxTree.invalidIdentifier THEN
                statement := NewLynxAddsel(position, index, varname, channel, outer);
                statements.AddStatement(statement);
            ELSE
                forStatement := SyntaxTree.NewForStatement(symbol.start, outer);
                designator := SyntaxTree.NewIdentifierDesignator(position, varname);
                forStatement.SetVariable(designator);
                forStatement.SetFrom(from);
                forStatement.SetTo(to);
                forBody := SyntaxTree.NewStatementSequence();
                statement := 
                    NewLynxAddsel(position, index, varname, channel, forStatement);
                forBody.AddStatement(statement);
                forStatement.SetStatements(forBody);
                statements.AddStatement(forStatement);
            END;

            (* case part *)
            casePart := SyntaxTree.NewCasePart();
            casePart.elements.AddExpression(SyntaxTree.NewIntegerValue(position, index));

            (* same logic as for switch: *)
            caseBody := StatementList(caseStatement);
            length := caseBody.Length();
            IF length = 0 THEN
                Error(symbol.start, Diagnostics.Invalid, "Fall through in switch section");
            ELSE
                last := caseBody.GetStatement(length-1);
                IF last IS SyntaxTree.ExitStatement THEN
                    caseBody.RemoveStatement(last);
                ELSIF ~(last IS SyntaxTree.ReturnStatement) THEN
                    Error(symbol.start, Diagnostics.Invalid, "Fall through in switch section");
                END;
            END;

            statement := NewPortStatement(position, lynxReceive, channel(SyntaxTree.Designator), target, caseStatement);
            caseBody.PrependStatement(statement);
            IF varname # SyntaxTree.invalidIdentifier THEN
                statement := NewLynxSelidx(position, varname, caseStatement);
                caseBody.PrependStatement(statement);
            END;

            casePart.SetStatements(caseBody);
            caseStatement.AddCasePart(casePart);

            localIdentTable.CloseScope;

            IF Trace THEN 
                E("SelectSection")
            END;
        END SelectSection;

        PROCEDURE SelectStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR statement: SyntaxTree.Statement;
                caseStatement: SyntaxTree.CaseStatement;
                expression: SyntaxTree.Expression;
                index: LONGINT;
                position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("SelectStatement")
            END;
            position := symbol.start;
            Check(Scanner.Select);
            statement := NewLynxNewsel(position, outer);
            statements.AddStatement(statement);
            caseStatement := SyntaxTree.NewCaseStatement(position, outer);
            expression := NewLynxSelect(position);
            caseStatement.SetVariable(expression);
            Check(Scanner.LeftBrace);
            index := 0;
            WHILE Peek(Scanner.Case) DO
                SelectSection(statements, caseStatement, index, outer);
                INC(index);
            END;
            position := symbol.start;
            Check(Scanner.RightBrace);
            IF index = 0 THEN
                Error(position, Diagnostics.Invalid, "Empty select statement");
            END;
            statements.AddStatement(caseStatement);
            IF Trace THEN 
                E("SelectStatement")
            END;
        END SelectStatement;

        (**
            while-statement:
                'while' '(' boolean-expression ')' embedded-statement
        **)
        PROCEDURE WhileStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR expression: SyntaxTree.Expression;
                whileStatement: SyntaxTree.WhileStatement;
                statementSequence: SyntaxTree.StatementSequence;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("WhileStatement")
            END;
            Check(Scanner.While);
            whileStatement := SyntaxTree.NewWhileStatement(symbol.start, outer);
            (* CommentStatement(whileStatement); *)
            Check(Scanner.LeftParenthesis);
            expression := Expression();
            Check(Scanner.RightParenthesis);
            whileStatement.SetCondition(expression);
            statementSequence := SyntaxTree.NewStatementSequence();
            b := EmbeddedStatement(statementSequence, whileStatement);
            whileStatement.SetStatements(statementSequence);
            statements.AddStatement(whileStatement);
            IF Trace THEN 
                E("WhileStatement")
            END;
        END WhileStatement;

        (**
            do-statement:
                'do' embedded-statement 'while' '(' boolean-expression ')' ';'
        **)
        PROCEDURE DoStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR expression: SyntaxTree.Expression;
                repeatStatement: SyntaxTree.RepeatStatement;
                statementSequence: SyntaxTree.StatementSequence;
                position: LONGINT;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("DoStatement")
            END;
            Check(Scanner.Do);
            repeatStatement := SyntaxTree.NewRepeatStatement(symbol.start, outer);
            (* CommentStatement(repeatStatement); *)
            statementSequence := SyntaxTree.NewStatementSequence();
            b := EmbeddedStatement(statementSequence, repeatStatement);
            repeatStatement.SetStatements(statementSequence);
            Check(Scanner.While);
            Check(Scanner.LeftParenthesis);
            position := symbol.start;
            expression := Expression();
            Check(Scanner.RightParenthesis);
            expression := NewUnaryExpression(position, expression, Scanner.Exclamation); 
            repeatStatement.SetCondition(expression);
            statements.AddStatement(repeatStatement);
            IF Trace THEN 
                E("DoStatement")
            END;
        END DoStatement;

        (**
            statement-expression-list:
                statement-expression
                statement-expression-list ',' statement-expression
        **)
        PROCEDURE StatementExpressionList(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("StatementExpressionList")
            END;
            REPEAT
                b := StatementExpression(statements, outer, NIL);
            UNTIL ~Optional(Scanner.Comma);
            IF Trace THEN 
                E("StatementExpressionList")
            END;
        END StatementExpressionList;

        (**
            for-initializer:
                local-variable-declaration
                statement-expression-list
        **)
        PROCEDURE ForInitializer(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR isDeclaration: BOOLEAN;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("ForInitializer")
            END;

            IF Peek(Scanner.Bool) OR Peek(Scanner.Sbyte) OR
                    Peek(Scanner.Short) OR Peek(Scanner.Int) OR
                    Peek(Scanner.Long) OR Peek(Scanner.Char) OR
                    Peek(Scanner.Float) OR Peek(Scanner.Double) OR
                    Peek(Scanner.Object) OR Peek(Scanner.String) THEN
                LocalVariableDeclaration(statements, outer, NIL);
            ELSIF Peek(Scanner.Identifier) THEN
                (* either local-variable-declaration or statement expression *)
                b := ExpressionOrDeclaration(statements, outer, isDeclaration);
                IF ~isDeclaration & Optional(Scanner.Comma) THEN
                    StatementExpressionList(statements, outer);
                END;
            ELSE
                StatementExpressionList(statements, outer);
            END;

            IF Trace THEN 
                E("ForInitializer")
            END;
        END ForInitializer;

        (**
            for-iterator:
                statement-expression-list
        **)
        PROCEDURE ForIterator(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
        BEGIN
            IF Trace THEN 
                S("ForIterator")
            END;
            StatementExpressionList(statements, outer);
            IF Trace THEN 
                E("ForIterator")
            END;
        END ForIterator;

        (**
            for-statement:
                'for' '(' [for-initializer] ';' [for-condition] ';' [for-iterator] ')' embedded-statement

            for-condition:
                boolean-expression
        **)
        PROCEDURE ForStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR expression: SyntaxTree.Expression;
                whileStatement: SyntaxTree.WhileStatement;
                statementSequence: SyntaxTree.StatementSequence;
                iterator: SyntaxTree.StatementSequence;
                position0, position1: LONGINT;
                i: LONGINT;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("ForStatement")
            END;
            Check(Scanner.For);
            localIdentTable.OpenScope;
            whileStatement := SyntaxTree.NewWhileStatement(symbol.start, outer);
            (* CommentStatement(whileStatement); *)
            Check(Scanner.LeftParenthesis);
            IF ~Optional(Scanner.Semicolon) THEN
                ForInitializer(statements, outer);
                Check(Scanner.Semicolon);
            END;
            position0 := symbol.start;
            position1 := symbol.end;
            IF ~Optional(Scanner.Semicolon) THEN
                expression := Expression();
                Check(Scanner.Semicolon);
            ELSE
                expression := SyntaxTree.NewBooleanValue(position0, TRUE);
                expression.End(position1);
            END;
            IF ~Optional(Scanner.RightParenthesis) THEN
                iterator := SyntaxTree.NewStatementSequence();
                ForIterator(iterator, whileStatement);
                Check(Scanner.RightParenthesis);
            ELSE
                iterator := NIL;
            END;
            whileStatement.SetCondition(expression);
            statementSequence := SyntaxTree.NewStatementSequence();
            b := EmbeddedStatement(statementSequence, whileStatement);
            IF iterator # NIL THEN
                FOR i := 0 TO iterator.Length() - 1 DO
                    statementSequence.AddStatement(iterator.GetStatement(i));
                END;
            END;
            whileStatement.SetStatements(statementSequence);
            statements.AddStatement(whileStatement);
            localIdentTable.CloseScope;
            IF Trace THEN 
                E("ForStatement")
            END;
        END ForStatement;

        (**
            return-statement:
                'return' [expression] ';'
        **)
        PROCEDURE ReturnStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR returnStatement: SyntaxTree.ReturnStatement;
                expression: SyntaxTree.Expression;
        BEGIN
            IF Trace THEN 
                S("ReturnStatement")
            END;
            Check(Scanner.Return);
            returnStatement := SyntaxTree.NewReturnStatement(symbol.start, outer);
            (* CommentStatement(returnStatement); *)
            IF ~Optional(Scanner.Semicolon) THEN
                expression := Expression();
                returnStatement.SetReturnValue(expression);
                Check(Scanner.Semicolon);
            END;
            statements.AddStatement(returnStatement);
            IF Trace THEN 
                E("ReturnStatement")
            END;
        END ReturnStatement;

        (**
            break-statement:
                'break' ';'
        **)
        PROCEDURE BreakStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement);
            VAR statement: SyntaxTree.Statement;
        BEGIN
            IF Trace THEN 
                S("BreakStatement")
            END;
            Check(Scanner.Break);
            statement := SyntaxTree.NewExitStatement(symbol.start, outer);
            (* CommentStatement(statement); *)
            statements.AddStatement(statement);
            Check(Scanner.Semicolon);
            IF Trace THEN 
                E("BreakStatement")
            END;
        END BreakStatement;

        (**
            embedded-statement:
                block
                empty-statement
                expression-statement
                selection-statement
                iteration-statement
                jump-statement

            empty-statement:
                ';'

            selection-statement:
                if-statement
                switch-statement
                select-statement

            iteration-statement:
                while-statement
                do-statement
                for-statement

            jump-statement:
                break-statement
                return-statement
        **)
        PROCEDURE EmbeddedStatement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
            VAR result: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("EmbeddedStatement")
            END;
            IF Optional(Scanner.Semicolon) THEN
                result := FALSE;
            ELSIF Peek(Scanner.LeftBrace) THEN
                Block(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.If) THEN
                IfStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.Switch) THEN
                SwitchStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.Select) THEN
                SelectStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.While) THEN
                WhileStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.Do) THEN
                DoStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.For) THEN
                ForStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.Break) THEN
                BreakStatement(statements, outer);
                result := TRUE;
            ELSIF Peek(Scanner.Return) THEN
                ReturnStatement(statements, outer);
                result := TRUE;
            ELSE
                result := ExpressionStatement(statements, outer);
            END;
            IF Trace THEN 
                E("EmbeddedStatement")
            END;
            RETURN result;
        END EmbeddedStatement;

        (**
            statement:
                declaration-statement
                embedded-statement

            declaration-statement:
                local-variable-declaration ';'
                local-constant-declaration ';'
        **)
        PROCEDURE ExpressionOrDeclaration(
                statements: SyntaxTree.StatementSequence; 
                outer: SyntaxTree.Statement;
                VAR isDeclaration: BOOLEAN): BOOLEAN;
            VAR result: BOOLEAN;
                name0, name1: SyntaxTree.Identifier;
                position0, position1, position2: LONGINT;
                leftBracket: BOOLEAN;
                qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
                type: SyntaxTree.Type;
                expression: SyntaxTree.Expression;
                expressionList: SyntaxTree.ExpressionList;
        BEGIN
            name0 := Identifier(position0);
            IF Optional(Scanner.Period) THEN
                name1 := Identifier(position1);
            ELSE
                name1 := SyntaxTree.invalidIdentifier;
            END;
            isDeclaration := FALSE;
            leftBracket := FALSE;
            position2 := symbol.start;
            IF Peek(Scanner.Identifier) THEN
                isDeclaration := TRUE;
            ELSIF Optional(Scanner.LeftBracket) THEN
                leftBracket := TRUE;
                IF Peek(Scanner.RightBracket) OR Peek(Scanner.Comma) THEN
                    isDeclaration := TRUE;
                END;
            END;
            IF isDeclaration THEN
                (* local-variable-declaration *)
                IF name1 = SyntaxTree.invalidIdentifier THEN
                    name1 := name0;
                    name0 := SyntaxTree.invalidIdentifier;
                END;
                qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(position0, name0, name1);                       
                type := SyntaxTree.NewQualifiedType(
                    qualifiedIdentifier.position, currentScope, qualifiedIdentifier);
                IF leftBracket THEN
                    type := RankSpecifier(type);
                    Check(Scanner.RightBracket);
                END;
                WHILE Optional(Scanner.LeftBracket) DO
                    type := RankSpecifier(type);
                    Check(Scanner.RightBracket);
                END;
                LocalVariableDeclaration(statements, outer, type);
            ELSE
                (* expression-statement *)
                name0 := localIdentTable.Find(name0);
                expression := SyntaxTree.NewIdentifierDesignator(position0, name0);
                IF name1 # SyntaxTree.invalidIdentifier THEN
                    expression := SyntaxTree.NewSelectorDesignator(position1, expression(SyntaxTree.Designator), name1);
                END;
                IF leftBracket THEN
                    expressionList := SyntaxTree.NewExpressionList();
                    ExpressionList(expressionList);
                    Check(Scanner.RightBracket);
                    expression := SyntaxTree.NewBracketDesignator(position2, expression(SyntaxTree.Designator), expressionList);
                END;
                expression := Accessors(expression, FALSE);
                result := StatementExpression(statements, outer, expression);
            END;
            RETURN result;
        END ExpressionOrDeclaration;

        PROCEDURE Statement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
            VAR result: BOOLEAN;
                isDeclaration: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("Statement")
            END;
            IF Peek(Scanner.Const) THEN
                LocalConstantDeclaration(statements, outer);
                Check(Scanner.Semicolon);
                result := TRUE;
            ELSIF Peek(Scanner.Bool) OR Peek(Scanner.Sbyte) OR
                    Peek(Scanner.Short) OR Peek(Scanner.Int) OR
                    Peek(Scanner.Long) OR Peek(Scanner.Char) OR
                    Peek(Scanner.Float) OR Peek(Scanner.Double) OR
                    Peek(Scanner.Object) OR Peek(Scanner.String) THEN
                LocalVariableDeclaration(statements, outer, NIL);
                Check(Scanner.Semicolon);
                result := TRUE;
            ELSIF Peek(Scanner.Identifier) THEN
                (* either local-variable-declaration or statement expression *)
                result := ExpressionOrDeclaration(statements, outer, isDeclaration);
                Check(Scanner.Semicolon);
            ELSE
                result := EmbeddedStatement(statements, outer);
            END;
            IF Trace THEN 
                E("Statement")
            END;
            RETURN result;
        END Statement;

        (**
            statement-list:
                statement
                statement-list statement
        **)
        PROCEDURE StatementList(outer: SyntaxTree.Statement): SyntaxTree.StatementSequence;
            VAR statements: SyntaxTree.StatementSequence; 
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("StatementList")
            END;
            statements := SyntaxTree.NewStatementSequence();
            REPEAT
                b := Statement(statements, outer);
            UNTIL Peek(Scanner.RightBrace) OR Peek(Scanner.Case) OR Peek(Scanner.Default) ;
            IF Trace THEN 
                E("StatementList")
            END;
            RETURN statements;
        END StatementList;

        (**
            block:
                '{' [statement-list] '}'
        **)
        PROCEDURE Body(scope: SyntaxTree.ProcedureScope): SyntaxTree.Body;
            VAR body: SyntaxTree.Body;
                previousScope: SyntaxTree.Scope;
        BEGIN
            IF Trace THEN 
                S("Body")
            END;
            previousScope := currentScope;
            currentScope := scope;
            Check(Scanner.LeftBrace);
            body := SyntaxTree.NewBody(symbol.start, scope);
            IF ~Optional(Scanner.RightBrace) THEN
                body.SetStatementSequence(StatementList(body));
                Check(Scanner.RightBrace);
            END;
            currentScope := previousScope;
            IF Trace THEN 
                E("Body")
            END;
            RETURN body;
        END Body;

        (**
            type:
                value-type
                reference-type
                port-type

            value-type:
                struct-type

            struct-type:
                type-name
                simple-type

            simple-type:
                numeric-type
               'bool'

            numeric-type:
                integral-type
                floating-point-type

            integral-type:
                'sbyte'
                'short'
                'int'
                'long'
                'char'

            floating-point-type:
                'float'
                'double'

            reference-type:
                class-type
                array-type
                delegate-type

            class-type:
                type-name
                'object'
                'string'

            array-type:
                non-array-type rank-specifiers

            non-array-type:
                value-type
                class-type
                delegate-type

            rank-specifiers:
                rank-specifier
                rank-specifiers rank-specifier

            rank-specifier:
                '[' [dim-separators] ']'

            dim-separators:
                ','
                dim-separators ','

            delegate-type:
                type-name
        **)
        PROCEDURE RankSpecifier(type: SyntaxTree.Type): SyntaxTree.Type;
            VAR position: LONGINT;
                arrayType: SyntaxTree.ArrayType;
                pointerType: SyntaxTree.PointerType;
        BEGIN
            IF Trace THEN 
                S("RankSpecifier")
            END;
            position := symbol.start;
            REPEAT
                arrayType := SyntaxTree.NewArrayType(position, currentScope, SyntaxTree.Open);
                arrayType.SetArrayBase(type);
                type := arrayType;
            UNTIL ~Optional(Scanner.Comma);
            pointerType := SyntaxTree.NewPointerType(position, currentScope);
            pointerType.SetPointerBase(type);
            type := pointerType;
            IF Trace THEN 
                E("RankSpecifier")
            END;
            RETURN type;
        END RankSpecifier; 

        PROCEDURE NonArrayType(): SyntaxTree.Type;
            VAR type: SyntaxTree.Type;
                position: LONGINT;
                name: SyntaxTree.Identifier;
                direction: LONGINT;
                qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
        BEGIN
            IF Trace THEN 
                S("NonArrayType")
            END;
            position := symbol.start;
            name := SyntaxTree.invalidIdentifier;
            direction := -1;
            IF Optional(Scanner.Bool) THEN
                name := lynxBool;
            ELSIF Optional(Scanner.Sbyte) THEN
                name := lynxSbyte;
            ELSIF Optional(Scanner.Short) THEN
                name := lynxShort;
            ELSIF Optional(Scanner.Int) THEN
                name := lynxInt;
            ELSIF Optional(Scanner.Long) THEN
                name := lynxLong;
            ELSIF Optional(Scanner.Char) THEN
                name := lynxChar;
            ELSIF Optional(Scanner.Float) THEN
                name := lynxFloat;
            ELSIF Optional(Scanner.Double) THEN
                name := lynxDouble;
            ELSIF Optional(Scanner.Object) THEN
                name := lynxObject;
            ELSIF Optional(Scanner.String) THEN
                name := lynxString;
            ELSIF Optional(Scanner.In) THEN
                direction := SyntaxTree.InPort;
            ELSIF Optional(Scanner.Out) THEN
                direction := SyntaxTree.OutPort;
            END;
            IF direction >= 0 THEN
                type := SyntaxTree.NewPortType(position, direction, NIL, currentScope);
            ELSE
                IF name # SyntaxTree.invalidIdentifier THEN
                    qualifiedIdentifier := 
                        SyntaxTree.NewQualifiedIdentifier(
                            position, SyntaxTree.invalidIdentifier, name);
                ELSE
                    qualifiedIdentifier := QualifiedIdentifier();
                END;
                type := SyntaxTree.NewQualifiedType(
                    qualifiedIdentifier.position, currentScope, qualifiedIdentifier);
            END;
            IF Trace THEN 
                E("NonArrayType")
            END;
            RETURN type;
        END NonArrayType;

        PROCEDURE Type(): SyntaxTree.Type;
            VAR type: SyntaxTree.Type;
        BEGIN
            IF Trace THEN 
                S("Type")
            END;
            type := NonArrayType();
            WHILE Optional(Scanner.LeftBracket) DO
                type := RankSpecifier(type);
                Check(Scanner.RightBracket);
            END;
            IF Trace THEN 
                E("Type")
            END;
            RETURN type;
        END Type;

        (**
            attributes:
                '[' attribute-list ']'

            attribute-list:
                attribute
                attribute-list ',' attribute

            attribute:
                attribute-name [attribute-argument]

            attribute-name:
                identifier

            attribute-argument:
                '(' attribute-argument-expression ')'

            attribute-argument-expression:
                expression
        **)
        PROCEDURE AppendModifier(VAR list: SyntaxTree.Modifier; modifier: SyntaxTree.Modifier);
        VAR this, next: SyntaxTree.Modifier;
        BEGIN
            IF list = NIL THEN 
                list := modifier
            ELSE
                this := list;
                next := list.nextModifier;
                WHILE next # NIL DO
                    this := next;
                    next := this.nextModifier;
                END;
                this.SetNext(modifier);
            END;
        END AppendModifier;

        PROCEDURE Attributes(): SyntaxTree.Modifier;
            VAR identifier: SyntaxTree.Identifier;
                modifier, list: SyntaxTree.Modifier;
                position: LONGINT;
                expression: SyntaxTree.Expression;
        BEGIN
            IF Trace THEN
                S("Attributes")
            END;
            (* left bracket already consumed *)
            list := NIL;
            REPEAT            
                position := symbol.start;
                identifier := Identifier(position);
                IF Optional(Scanner.LeftParenthesis) THEN
                    expression := Expression();
                    Check(Scanner.RightParenthesis);
                ELSE
                    expression := NIL;
                END;
                modifier := SyntaxTree.NewModifier(position, identifier, expression);
                AppendModifier(list, modifier);
            UNTIL ~Optional(Scanner.Comma);
            Check(Scanner.RightBracket);
            IF Trace THEN
                E("Attributes")
            END;
            RETURN list;
        END Attributes;

        (**
            constant-modifiers:
                constant-modifier
                constant-modifiers constant-modifier

            constant-modifier:
                'public'

            field-modifiers:
                field-modifier
                field-modifiers field-modifier

            field-modifier:
                'public'
                'internal'

            method-modifiers:
                method-modifier
                method-modifiers method-modifier

            method-modifier:
                'public'

            constructor-modifiers:
                constructor-modifier
                constructor-modifiers constructor-modifier

            constructor-modifier:
                public

            class-modifiers:
                class-modifier
                class-modifiers class-modifier

            class-modifier:
                'public'

            struct-modifiers:
                struct-modifier
                struct-modifiers struct-modifier

            struct-modifier:
                'public'

            delegate-modifiers:
                delegate-modifier
                delegate-modifiers delegate-modifier

            delegate-modifier:
               'public'
        **)
        PROCEDURE Modifiers(VAR modifiers: SET);
        BEGIN
            modifiers := {};
            LOOP
                IF Optional(Scanner.Public) THEN
                    INCL(modifiers, Public);
                ELSIF Optional(Scanner.Internal) THEN
                    INCL(modifiers, Internal);
                ELSE
                    EXIT;
                END;
            END;
        END Modifiers;

        PROCEDURE IdentifierAccess(modifiers: SET; allowedReadOnly: BOOLEAN): SET;
            VAR access: SET;
        BEGIN
            IF modifiers * {Public, Internal} = {Public, Internal} THEN
                Error(symbol.start, Diagnostics.Invalid, "conflicting modifiers");
            END;
            IF Public IN modifiers THEN
                access := SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal;
            ELSIF Internal IN modifiers THEN
                IF ~allowedReadOnly THEN
                    Error(symbol.start, Diagnostics.Invalid, "may not be defined internal")
                ELSE
                    access :=  SyntaxTree.ReadOnly + {SyntaxTree.InternalWrite};
                END;
            ELSE
                access := SyntaxTree.Internal;
            END;
            RETURN access;
        END IdentifierAccess;

        (**
            constant-declaration:
                [constant-modifiers] 'const' type constant-declarators ';'

            constant-declarators:
                constant-declarator
                constant-declarators ',' constant-declarator

            constant-declarator:
                identifier '=' constant-expression
        **)
        PROCEDURE ConstantDeclarator(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET; 
                type: SyntaxTree.Type);
            VAR name: SyntaxTree.Identifier;
                position: LONGINT;
                constant: SyntaxTree.Constant;
                expression: SyntaxTree.Expression;
                access: SET;
        BEGIN
            IF Trace THEN 
                S("ConstantDeclarator") 
            END;
            name := Identifier(position);
            name := localIdentTable.Enter(name);
            access := IdentifierAccess(modifiers, FALSE);
            constant := SyntaxTree.NewConstant(position, name);
            CommentSymbol(constant);
            constant.SetAccess(access);
            (* ACHTUNG: Make sure that Fox semantic checker will respect a type set at this stage: *)
            constant.SetType(type);
            Check(Scanner.Equal);
            expression := Expression();
            constant.SetValue(expression);
            parentScope.AddConstant(constant);
            IF Trace THEN 
                E("ConstantDeclarator") 
            END;
        END ConstantDeclarator;

        PROCEDURE ConstantDeclaration(parentScope: SyntaxTree.Scope; modifiers: SET);
            VAR type: SyntaxTree.Type;
        BEGIN
            IF Trace THEN 
                S("ConstantDeclaration") 
            END;
            type := Type();
            REPEAT
                ConstantDeclarator(parentScope, modifiers, type);
            UNTIL ~Optional(Scanner.Comma);
            Check(Scanner.Semicolon);
            IF Trace THEN 
                E("ConstantDeclaration") 
            END;
        END ConstantDeclaration;

        (**
            field-declaration:
                [field-modifiers] type variable-declarators ';'

            field-modifiers:
                field-modifier
                field-modifiers field-modifier

            variable-declarators:
                variable-declarator
                variable-declarators ',' variable-declarator

            variable-declarator:
                identifier
                identifier '=' variable-initializer

            variable-initializer:
                expression
//                array-initializer
        **)
        PROCEDURE VariableDeclarator(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET; 
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT);
            VAR variable: SyntaxTree.Variable;
                expression: SyntaxTree.Expression;
                designator: SyntaxTree.Designator;
                statement: SyntaxTree.Statement;
                start: LONGINT;
                access: SET;
        BEGIN
            IF Trace THEN 
                S("VariableDeclarator") 
            END;
            IF name = SyntaxTree.invalidIdentifier THEN
                name := Identifier(position);
            END;
            name := localIdentTable.Enter(name);
            access := IdentifierAccess(modifiers, TRUE);
            variable := SyntaxTree.NewVariable(position, name);
            CommentSymbol(variable);
            variable.SetAccess(access);
            variable.SetType(type);
            parentScope.AddVariable(variable);
            start := symbol.start;
            (* 'initOuter' is set to NIL in contexts where initialization is not yet implemented *)
            IF (initOuter # NIL) & Optional(Scanner.Equal) THEN
                (* ACHTUNG: array-initializer form is not supported *)
                designator := SyntaxTree.NewIdentifierDesignator(position, name);
                expression := Expression();
                statement := SyntaxTree.NewAssignment(start, designator, expression, initOuter);
                initStatements.AddStatement(statement);
            END;
            IF Trace THEN 
                E("VariableDeclarator") 
            END;
        END VariableDeclarator;

        PROCEDURE FieldDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET;
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT);
        BEGIN
            IF Trace THEN 
                S("FieldDeclaration") 
            END;
            REPEAT
                VariableDeclarator(parentScope, modifiers, type, name, position);
                name := SyntaxTree.invalidIdentifier;
                position := invalidPosition;
            UNTIL ~Optional(Scanner.Comma);
            Check(Scanner.Semicolon);
            IF Trace THEN 
                E("FieldDeclaration") 
            END;
        END FieldDeclaration;

        (**
            formal-parameter-list:
                fixed-parameters

            fixed-parameters:
                fixed-parameter
                fixed-parameters ',' fixed-parameter

            fixed-parameter:
                [parameter-modifier] type identifier

            parameter-modifier:
               'ref'
        **)
        PROCEDURE FixedParameter(procedureType: SyntaxTree.ProcedureType; parentScope: SyntaxTree.Scope);
            VAR type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                parameter: SyntaxTree.Parameter;
                kind, position: LONGINT;
        BEGIN
            IF Trace THEN 
                S("FixedParameter")
            END;
            IF Optional(Scanner.Ref) THEN
                kind := SyntaxTree.VarParameter;
            ELSE
                kind := SyntaxTree.ValueParameter;
            END;
            type := Type();
            name := Identifier(position);
            parameter := SyntaxTree.NewParameter(position, procedureType, name, kind);
            procedureType.AddParameter(parameter);
            parameter.SetType(type);
            IF Trace THEN 
                E("FixedParameter")
            END;
        END FixedParameter;

        PROCEDURE FormalParameterList(
                procedureType: SyntaxTree.ProcedureType; 
                parentScope: SyntaxTree.Scope;
                returnType: SyntaxTree.Type);
        BEGIN
            IF Trace THEN 
                S("FormalParameterList")
            END;
            Check(Scanner.LeftParenthesis);
            IF ~Optional(Scanner.RightParenthesis) THEN
                REPEAT
                    FixedParameter(procedureType, parentScope);
                UNTIL ~Optional(Scanner.Comma);
                Check(Scanner.RightParenthesis);
            END;
            IF returnType # NIL THEN
                procedureType.SetReturnType(returnType);
            END;
            IF Trace THEN 
                E("FormalParameterList")
            END;
        END FormalParameterList;

        (**
            constructor-initializer:
                ':' 'base' '(' [argument-list] ')'
        **)
        PROCEDURE ConstructorInitializer(scope: SyntaxTree.ProcedureScope);
        BEGIN
            IF Trace THEN 
                S("ConstructorInitializer")
            END;
            (* TODO *)
            IF Trace THEN 
                E("ConstructorInitializer")
            END;
        END ConstructorInitializer;

        (**
            method-declaration:
                method-header method-body

            method-header:
                [method-modifiers] return-type member-name '(' [formal-parameter-list] ')'

            return-type:
                type
               'void'

            member-name:
                identifier

            method-body:
                block

            constructor-declaration:
                [constructor-modifiers] constructor-declarator constructor-body

            constructor-declarator:
                identifier ( [formal-parameter-list] ) [constructor-initializer]

            constructor-body:
                block
        **)
        PROCEDURE ProcedureDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET;
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT;
                isConstructor: BOOLEAN);
            VAR procedure: SyntaxTree.Procedure;
                procedureType: SyntaxTree.ProcedureType;
                procedureScope: SyntaxTree.ProcedureScope;
                previousScope: SyntaxTree.Scope;
                access: SET;
                body: SyntaxTree.Body;
        BEGIN
            procedureType := SyntaxTree.NewProcedureType(position, parentScope);
            access := IdentifierAccess(modifiers, FALSE);
            procedureScope := SyntaxTree.NewProcedureScope(parentScope);
            procedure := SyntaxTree.NewProcedure(position, name, procedureScope);
            procedure.SetConstructor(isConstructor);
            CommentSymbol(procedure);
            procedure.SetAccess(access);
            procedure.SetType(procedureType);
            FormalParameterList(procedureType, procedureScope, type);
            IF isConstructor & Optional(Scanner.Colon) THEN
                (* TODO: Connect initializer to the body *)
                ConstructorInitializer(procedureScope);
            END;
            previousScope := currentScope;
            currentScope := procedureScope;
            body := Body(procedureScope);
            currentScope := previousScope;
            procedureScope.SetBody(body);
            parentScope.AddProcedure(procedure);
        END ProcedureDeclaration;

        PROCEDURE MethodDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET;
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT);
        BEGIN
            IF Trace THEN 
                S("MethodDeclaration") 
            END;
            localIdentTable.Reset;
            IF (name = identMain) &
                    (parentScope IS SyntaxTree.CellScope) &
                    ~parentScope(SyntaxTree.CellScope).ownerCell.isCellNet THEN
                (* bodies of cells are represented as main() functions *)
                BodyDeclaration(parentScope, modifiers, type, name, position);
            ELSE
                ProcedureDeclaration(parentScope, modifiers, type, name, position, FALSE);
            END;
            IF Trace THEN 
                E("MethodDeclaration") 
            END;
        END MethodDeclaration;

        PROCEDURE ConstructorDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET;
                name: SyntaxTree.Identifier;
                position: LONGINT);
        BEGIN
            IF Trace THEN 
                S("ConstructorDeclaration") 
            END;
            localIdentTable.Reset;
            IF (parentScope IS SyntaxTree.ModuleScope) OR
                    ((parentScope IS SyntaxTree.CellScope) &
                        parentScope(SyntaxTree.CellScope).ownerCell.isCellNet) THEN
                (* bodies of modules and cellnets are represented as constructors *)
                BodyDeclaration(parentScope, modifiers, NIL, name, position);
            ELSE
                ProcedureDeclaration(parentScope, modifiers, NIL, name, position, TRUE);
            END;
            IF Trace THEN 
                E("ConstructorDeclaration") 
            END;
        END ConstructorDeclaration;

        PROCEDURE BodyDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET;
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT);
            VAR procedureScope: SyntaxTree.ProcedureScope;
                procedureType: SyntaxTree.ProcedureType;
                procedure: SyntaxTree.Procedure;
        BEGIN
            procedureScope := SyntaxTree.NewProcedureScope(parentScope);
            IF parentScope IS SyntaxTree.ModuleScope THEN
                procedure := SyntaxTree.NewProcedure(position, Global.ModuleBodyName, procedureScope);
                procedure.SetAccess(SyntaxTree.Hidden);
            ELSE
                procedure := SyntaxTree.NewProcedure(position, Global.RecordBodyName, procedureScope);
                procedure.SetAccess(SyntaxTree.Public+SyntaxTree.Protected+SyntaxTree.Internal);
            END;
            parentScope.AddProcedure(procedure);
            procedureType := SyntaxTree.NewProcedureType(position, parentScope);
            FormalParameterList(procedureType, procedureScope, type);
            IF procedureType.numberParameters # 0 THEN
                Error(position, Diagnostics.Invalid, "constructor/main has parameters");
            ELSIF procedureType.returnType # NIL THEN
                Error(position, Diagnostics.Invalid, "constructor/main returns value");
            END;
            procedure.SetType(procedureType);
            procedure.SetBodyProcedure(TRUE);
            procedureScope.SetBody(Body(procedureScope));
            IF parentScope IS SyntaxTree.ModuleScope THEN
                parentScope(SyntaxTree.ModuleScope).SetBodyProcedure(procedure);
            ELSE
                parentScope(SyntaxTree.CellScope).SetBodyProcedure(procedure);
            END;
        END BodyDeclaration;

        (**
            class-declaration:
                [class-modifiers] 'class' identifier [class-base] class-body [';']

            class-base:
                ':' class-type

            class-body:
                '{' [class-member-declarations] '}'

            class-member-declarations:
                class-member-declaration
                class-member-declarations class-member-declaration

            class-member-declaration:
                constant-declaration
                field-declaration
                method-declaration
                constructor-declaration
                type-declaration

            type-declaration:
                class-declaration
                struct-declaration
                delegate-declaration
                cell-declaration
                cellnet-declaration
        **)
        PROCEDURE MemberDeclaration(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
            VAR attributes: SyntaxTree.Modifier;
                modifiers: SET;
                type: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT;
        BEGIN
            IF Optional(Scanner.LeftBracket) THEN
                attributes := Attributes();
            ELSE
                attributes := NIL;
            END;
            Modifiers(modifiers);
            IF Optional(Scanner.Const) THEN
                ConstantDeclaration(parentScope, modifiers);
            ELSIF Optional(Scanner.Class) THEN
                ClassDeclaration(parentScope, modifiers);
            ELSIF Optional(Scanner.Struct) THEN
                StructDeclaration(parentScope, modifiers);
            ELSIF Optional(Scanner.Delegate) THEN
                DelegateDeclaration(parentScope, modifiers);
            ELSIF Optional(Scanner.Cell) THEN
                CellDeclaration(parentScope, modifiers, attributes, FALSE);
            ELSIF Optional(Scanner.Cellnet) THEN
                CellDeclaration(parentScope, modifiers, attributes, TRUE);
            ELSIF Peek(Scanner.Identifier) & (symbol.identifier = parentName) THEN
                name := Identifier(position);
                ConstructorDeclaration(parentScope, modifiers, name, position);
            ELSIF Optional(Scanner.Void) THEN
                name := Identifier(position);
                MethodDeclaration(parentScope, modifiers, NIL, name, position);
            ELSE
                type := Type();
                name := Identifier(position);
                IF Peek(Scanner.LeftParenthesis) THEN
                    MethodDeclaration(parentScope, modifiers, type, name, position);
                ELSE
                    FieldDeclaration(parentScope, modifiers, type, name, position);
                END;
            END;
        END MemberDeclaration;

        PROCEDURE ClassMemberDeclaration(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
        BEGIN
            IF Trace THEN 
                S("ClassMemberDeclaration") 
            END;
            MemberDeclaration(parentScope, parentName);
            IF Trace THEN 
                E("ClassMemberDeclaration") 
            END;
        END ClassMemberDeclaration;

        PROCEDURE ClassMemberDeclarations(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
            VAR previousScope: SyntaxTree.Scope;
        BEGIN
            IF Trace THEN 
                S("ClassMemberDeclarations") 
            END;
            previousScope := currentScope;
            currentScope := parentScope;
            WHILE ~Peek(Scanner.RightBrace) DO
                ClassMemberDeclaration(parentScope, parentName);
            END;
            currentScope := previousScope;
            IF Trace THEN 
                E("ClassMemberDeclarations") 
            END;
        END ClassMemberDeclarations;

        PROCEDURE ClassDeclaration(parentScope: SyntaxTree.Scope; modifiers: SET);
            VAR name: SyntaxTree.Identifier;
                position: LONGINT;
                typeDeclaration: SyntaxTree.TypeDeclaration;
                access: SET;
                objectType: SyntaxTree.RecordType;
                pointerType: SyntaxTree.PointerType;
                recordScope: SyntaxTree.RecordScope;
                qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
                baseType: SyntaxTree.Type;
                previousStatements: SyntaxTree.StatementSequence;
                previousOuter: SyntaxTree.Statement;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("ClassDeclaration") 
            END;

            previousStatements := initStatements;
            previousOuter := initOuter;
            (* TODO: Implement initialization of fields *)
            initStatements := NIL;
            initOuter := NIL;

            EnterInit;

            (* symbol 'class' already consumed *)
            name := Identifier(position);
            access := IdentifierAccess(modifiers, FALSE);
            typeDeclaration := SyntaxTree.NewTypeDeclaration(position, name);
            CommentSymbol(typeDeclaration);

            recordScope := SyntaxTree.NewRecordScope(parentScope);
            pointerType := SyntaxTree.NewPointerType(position, parentScope);
            objectType := SyntaxTree.NewRecordType(position, parentScope, recordScope);
            objectType.IsObject(TRUE);
            objectType.SetPointerType(pointerType);
            pointerType.SetPointerBase(objectType);
            IF Optional(Scanner.Colon) THEN
                qualifiedIdentifier := QualifiedIdentifier();
                baseType := SyntaxTree.NewQualifiedType(
                    qualifiedIdentifier.position, parentScope, qualifiedIdentifier);
                objectType.SetBaseType(baseType);
            END;
            Check(Scanner.LeftBrace);
            ClassMemberDeclarations(recordScope, name);
            Check(Scanner.RightBrace);
            b := Optional(Scanner.Semicolon);

            pointerType.SetTypeDeclaration(typeDeclaration);
            typeDeclaration.SetDeclaredType(pointerType);
            typeDeclaration.SetAccess(access);
            parentScope.AddTypeDeclaration(typeDeclaration);

            initStatements := previousStatements;
            initOuter := previousOuter;

            IF Trace THEN 
                E("ClassDeclaration") 
            END;
        END ClassDeclaration;

        (**
            struct-declaration:
                [struct-modifiers] 'struct' identifier struct-body [';']

            struct-body:
                '{' [struct-member-declarations] '}'

            struct-member-declarations:
                struct-member-declaration
                struct-member-declarations struct-member-declaration

            struct-member-declaration:
                constant-declaration
                field-declaration
                method-declaration
                constructor-declaration
                type-declaration
        **)
        PROCEDURE StructMemberDeclaration(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
        BEGIN
            IF Trace THEN 
                S("StructMemberDeclaration") 
            END;
            MemberDeclaration(parentScope, parentName);
            IF Trace THEN 
                E("StructMemberDeclaration") 
            END;
        END StructMemberDeclaration;

        PROCEDURE StructMemberDeclarations(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
            VAR previousScope: SyntaxTree.Scope;
        BEGIN
            IF Trace THEN 
                S("StructMemberDeclarations") 
            END;
            previousScope := currentScope;
            currentScope := parentScope;
            WHILE ~Peek(Scanner.RightBrace) DO
                StructMemberDeclaration(parentScope, parentName);
            END;
            currentScope := previousScope;
            IF Trace THEN 
                E("StructMemberDeclarations") 
            END;
        END StructMemberDeclarations;

        PROCEDURE StructDeclaration(parentScope: SyntaxTree.Scope; modifiers: SET);
            VAR name: SyntaxTree.Identifier;
                position: LONGINT;
                typeDeclaration: SyntaxTree.TypeDeclaration;
                access: SET;
                recordType: SyntaxTree.RecordType;
                recordScope: SyntaxTree.RecordScope;
                previousStatements: SyntaxTree.StatementSequence;
                previousOuter: SyntaxTree.Statement;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("StructDeclaration") 
            END;

            previousStatements := initStatements;
            previousOuter := initOuter;
            (* TODO: Implement initialization of fields *)
            initStatements := NIL;
            initOuter := NIL;

            (* symbol 'struct' already consumed *)
            name := Identifier(position);
            access := IdentifierAccess(modifiers, FALSE);
            typeDeclaration := SyntaxTree.NewTypeDeclaration(position, name);
            CommentSymbol(typeDeclaration);

            recordScope := SyntaxTree.NewRecordScope(parentScope);
            recordType := SyntaxTree.NewRecordType(position, parentScope, recordScope);
            Check(Scanner.LeftBrace);
            StructMemberDeclarations(recordScope, name);
            Check(Scanner.RightBrace);
            b := Optional(Scanner.Semicolon);

            recordType.SetTypeDeclaration(typeDeclaration);
            typeDeclaration.SetDeclaredType(recordType);
            typeDeclaration.SetAccess(access);
            parentScope.AddTypeDeclaration(typeDeclaration);

            initStatements := previousStatements;
            initOuter := previousOuter;

            IF Trace THEN 
                E("StructDeclaration") 
            END;
        END StructDeclaration;

        (**
            delegate-declaration:
                [delegate-modifiers] 'delegate' return-type identifier '(' [formal-parameter-list] ')' ';'

        **)
        PROCEDURE DelegateDeclaration(parentScope: SyntaxTree.Scope; modifiers: SET);
            VAR returnType: SyntaxTree.Type;
                name: SyntaxTree.Identifier;
                position: LONGINT;
                typeDeclaration: SyntaxTree.TypeDeclaration;
                access: SET;
                procedureType: SyntaxTree.ProcedureType;
        BEGIN
            IF Trace THEN 
                S("DelegateDeclaration") 
            END;

            (* symbol 'delegate' already consumed *)
            IF Optional(Scanner.Void) THEN
                returnType := NIL;
            ELSE
                returnType := Type();
            END;
            name := Identifier(position);
            access := IdentifierAccess(modifiers, FALSE);
            typeDeclaration := SyntaxTree.NewTypeDeclaration(position, name);
            CommentSymbol(typeDeclaration);

            procedureType := SyntaxTree.NewProcedureType(position, parentScope);
            procedureType.SetModifiers(delegateModifiers);
            (* ACHTUNG: Should we create a fictionary parentScope for parameters? *)
            FormalParameterList(procedureType, parentScope, returnType);

            procedureType.SetTypeDeclaration(typeDeclaration);
            typeDeclaration.SetDeclaredType(procedureType);
            typeDeclaration.SetAccess(access);
            parentScope.AddTypeDeclaration(typeDeclaration);

            IF Trace THEN 
                E("DelegateDeclaration") 
            END;
        END DelegateDeclaration;

        (**
            port-list:
                port-declaration
                port-list ',' port-declaration

            port-declaration:
                port-type  ['[' constant-expression ']'] identifier

            port-type:
                'in'
                'out'
        **)
        PROCEDURE PortDeclaration(cell: SyntaxTree.CellType; parentScope: SyntaxTree.Scope);
            VAR position: LONGINT;
                direction: LONGINT;
                type: SyntaxTree.Type;
                arrayType: SyntaxTree.ArrayType;
                expression: SyntaxTree.Expression;
                name: SyntaxTree.Identifier;
                parameter: SyntaxTree.Parameter;
        BEGIN
            IF Trace THEN
                S("PortDeclaration")
            END;
            position := symbol.start;
            IF Optional(Scanner.In) THEN
                direction := SyntaxTree.InPort;
            ELSIF Optional(Scanner.Out) THEN
                direction := SyntaxTree.OutPort;
            ELSE
                Error(position, Diagnostics.Invalid, "invalid direction, expected in or out");
            END;
            type := SyntaxTree.NewPortType(position, direction, NIL, parentScope);
            IF Optional(Scanner.LeftBracket) THEN
                expression := Expression();
                arrayType := SyntaxTree.NewArrayType(position, parentScope, SyntaxTree.Static);
                arrayType.SetArrayBase(type);
                arrayType.SetLength(expression);
                type := arrayType;
                Check(Scanner.RightBracket);
            END;
            name := Identifier(position);
            parameter := SyntaxTree.NewParameter(position, cell, name, SyntaxTree.ValueParameter);
            cell.AddParameter(parameter);
            parameter.SetType(type);
            IF Trace THEN
                E("PortDeclaration")
            END;
        END PortDeclaration;

        PROCEDURE PortList(cell: SyntaxTree.CellType; parentScope: SyntaxTree.Scope);
        BEGIN
            IF Trace THEN
                S("PortList")
            END;
            Check(Scanner.LeftParenthesis);
            IF ~Optional(Scanner.RightParenthesis) THEN
                REPEAT
                    PortDeclaration(cell, parentScope);
                UNTIL ~Optional(Scanner.Comma);
                Check(Scanner.RightParenthesis);
            END;
            IF Trace THEN
                E("PortList")
            END;
        END PortList;

        (**
            cell-declaration:
               [cell-modifiers] 'cell' identifier ['(' [cell-parameter-list] ')'] cell-body [';']

            cell-body:
                '{' [cell-member-declarations] '}'

            cell-member-declarations:
                cell-member-declaration
                cell-member-declarations cell-member-declaration

            cell-member-declaration:
                constant-declaration
                field-declaration
                method-declaration
                constructor-declaration
                type-declaration

            cellnet-declaration:
               [cell-modifiers] 'cellnet' identifier ['(' [cell-parameter-list] ')'] cell-body [';']
        **)
        PROCEDURE CellMemberDeclaration(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
        BEGIN
            IF Trace THEN 
                S("CellMemberDeclaration") 
            END;
            MemberDeclaration(parentScope, parentName);
            IF Trace THEN 
                E("CellMemberDeclaration") 
            END;
        END CellMemberDeclaration;

        PROCEDURE CellMemberDeclarations(parentScope: SyntaxTree.Scope; parentName: SyntaxTree.Identifier);
            VAR previousScope: SyntaxTree.Scope;
        BEGIN
            IF Trace THEN 
                S("CellMemberDeclarations") 
            END;
            previousScope := currentScope;
            currentScope := parentScope;
            WHILE ~Peek(Scanner.RightBrace) DO
                CellMemberDeclaration(parentScope, parentName);
            END;
            currentScope := previousScope;
            IF Trace THEN 
                E("CellMemberDeclarations") 
            END;
        END CellMemberDeclarations;

        PROCEDURE CellDeclaration(
                parentScope: SyntaxTree.Scope; 
                modifiers: SET; 
                attributes: SyntaxTree.Modifier; 
                isCellNet: BOOLEAN);
            VAR name: SyntaxTree.Identifier;
                position: LONGINT;
                access: SET;
                typeDeclaration: SyntaxTree.TypeDeclaration;
                cellScope: SyntaxTree.CellScope;
                cellType: SyntaxTree.CellType;
                previousStatements: SyntaxTree.StatementSequence;
                previousOuter: SyntaxTree.Statement;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("CellDeclaration") 
            END;

            previousStatements := initStatements;
            previousOuter := initOuter;
            (* TODO: Implement initialization of fields *)
            initStatements := NIL;
            initOuter := NIL;

            (* symbol 'cell' already consumed *)
            name := Identifier(position);
            access := IdentifierAccess(modifiers, FALSE);
            typeDeclaration := SyntaxTree.NewTypeDeclaration(position, name);
            CommentSymbol(typeDeclaration);

            cellScope := SyntaxTree.NewCellScope(parentScope);
            cellType := SyntaxTree.NewCellType(position, parentScope, cellScope);
            cellType.IsCellNet(isCellNet);
            cellScope.SetOwnerCell(cellType);

            IF attributes # NIL THEN
                cellType.SetModifiers(attributes);
            END;

            IF Peek(Scanner.LeftParenthesis) THEN
                PortList(cellType, cellScope);
            END;

            EnterInit;

            Check(Scanner.LeftBrace);
            CellMemberDeclarations(cellScope, name);
            Check(Scanner.RightBrace);
            b := Optional(Scanner.Semicolon);

            cellType.SetTypeDeclaration(typeDeclaration);
            typeDeclaration.SetDeclaredType(cellType);
            typeDeclaration.SetAccess(access);
            parentScope.AddTypeDeclaration(typeDeclaration);

            initStatements := previousStatements;
            initOuter := previousOuter;

            IF Trace THEN 
                E("CellDeclaration") 
            END;
        END CellDeclaration;

        (**
            import-directives:
                import-directive
                import-directives import-directive

            import-directive:
                import-alias-directive
                import-module-directive

            import-alias-directive:
                'import' identifier '=' module-name ';'

            import-module-directive:
                'import' module-name ';'

            module-name:
                identifier
        **)
        PROCEDURE ImportDirective(moduleScope: SyntaxTree.ModuleScope);
            VAR alias, name, context: SyntaxTree.Identifier;
                import: SyntaxTree.Import; 
                position, idPosition: LONGINT;
        BEGIN
            IF Trace THEN 
                S("ImportDirective") 
            END;
            (* import symbol already consumed *)
            position := symbol.start;
            alias := Identifier(idPosition);
            IF alias # SyntaxTree.invalidIdentifier THEN
                IF Optional(Scanner.Equal) THEN
                    name := Identifier(idPosition);
                ELSE 
                    name := alias;  
                END;
                import := SyntaxTree.NewImport(position, alias, name, TRUE);
                CommentSymbol(import);
                moduleScope.AddImport(import);
            END;
            Check(Scanner.Semicolon);
            IF Trace THEN 
                E("ImportDirective");
            END;
        END ImportDirective;

        PROCEDURE ImportDirectives(moduleScope: SyntaxTree.ModuleScope);
        BEGIN
            IF Trace THEN 
                S("ImportDirectives") 
            END;
            WHILE Optional(Scanner.Import) DO
                ImportDirective(moduleScope);
            END;
            IF Trace THEN 
                E("ImportDirectives");
            END;
        END ImportDirectives;

        (**
            compilation-unit:
                'module' identifier '{' [import-directives] [class-member-declarations] '}' [';']
                'cellnet' identifier '{' [import-directives] [class-member-declarations] '}' [';']
        **)
        PROCEDURE Module*(): SyntaxTree.Module;
            VAR moduleName, context: SyntaxTree.Identifier;
                module: SyntaxTree.Module;
                position: LONGINT;
                isCellNet: BOOLEAN;
                scannerDiagnostics: Diagnostics.Diagnostics;
                b: BOOLEAN;
        BEGIN
            IF Trace THEN 
                S("Module") 
            END;
            position := symbol.start;
            (* needed to feed in comment already before module starts: *)
            moduleScope := SyntaxTree.NewModuleScope(); 
            currentScope := moduleScope;
            isCellNet := Optional(Scanner.Cellnet);
            IF isCellNet OR Mandatory(Scanner.Module) THEN
                moduleName := Identifier(position);
                module := SyntaxTree.NewModule(scanner.source^, position, moduleName, moduleScope, LynxCase);
                IF isCellNet THEN
                    module.SetCellNet(TRUE);
                END;
                module.SetType(SyntaxTree.moduleType);
                CommentSymbol(module);
                Check(Scanner.LeftBrace);
                IF Peek(Scanner.Import) THEN
                    ImportDirectives(moduleScope) 
                END;
                EnterInit;
                ClassMemberDeclarations(moduleScope, moduleName);
                Check(Scanner.RightBrace);
                b := Optional(Scanner.Semicolon);
                IF ~error & ~scanner.error THEN 
                    (* read ahead to read comments *)
                    scannerDiagnostics := NIL;
                    scanner.ResetErrorDiagnostics(scannerDiagnostics);
                    NextSymbol;
                    scanner.ResetErrorDiagnostics(scannerDiagnostics);
                    (* do not use Check for not reading after end of module *)
                    SetNextInComment(recentComment, module);
                    module.SetClosingComment(recentComment);
                    recentComment := NIL;
                END;
            END;
            IF Trace THEN 
                E("Module") 
            END;
            RETURN module
        END Module;

    END Parser;    (* Parser *)

    (** parser retrieval **)
    PROCEDURE NewParser*(scanner: Scanner.Scanner; diagnostics: Diagnostics.Diagnostics): Parser;
        VAR parser: Parser;
    BEGIN
        NEW(parser, scanner, diagnostics);
        RETURN parser;
    END NewParser;

END FoxCSharpParser.
