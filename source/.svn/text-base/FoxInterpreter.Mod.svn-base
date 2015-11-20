MODULE FoxInterpreter; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Scanner := FoxScanner, FoxParser, SyntaxTree := FoxSyntaxTree, Printout := FoxPrintout, Commands, Diagnostics, StringPool, InterpreterSymbols := FoxInterpreterSymbols, D:= Debugging,
	Strings, Streams, Modules, PersistentObjects, Basic := FoxBasic;
	
CONST
	EnableTrace = FALSE;

TYPE

	Value*=InterpreterSymbols.Item;
	Integer*=InterpreterSymbols.IntegerValue;
	Real*=InterpreterSymbols.RealValue;
	String*=InterpreterSymbols.StringValue;
	Boolean*=InterpreterSymbols.BooleanValue;
	Set*=InterpreterSymbols.SetValue;
	Range*=InterpreterSymbols.RangeValue;
	Char*=InterpreterSymbols.CharValue;
	Scope*=InterpreterSymbols.Scope;
	Container*= InterpreterSymbols.Container;
	Address*=InterpreterSymbols.Address;

	CommandStatement = OBJECT (SyntaxTree.Statement)
	VAR command: Strings.String;

		PROCEDURE & InitCommandStatement(s: Strings.String);
		BEGIN
			command := s
		END InitCommandStatement;

	END CommandStatement;

	Parser*= OBJECT(FoxParser.Parser)

		PROCEDURE Statement(statements: SyntaxTree.StatementSequence; outer: SyntaxTree.Statement): BOOLEAN;
		VAR statement: SyntaxTree.Statement;
		BEGIN
			IF (symbol.token = Scanner.Identifier) & (symbol.identifier = StringPool.GetIndex1("CMD")) THEN
				statement := Cmd();
				statements.AddStatement(statement);
				RETURN TRUE
			(*
			ELSIF (symbol.token = Scanner.Identifier) & (symbol.identifier = StringPool.GetIndex1("CMDS")) THEN
				REPEAT
					statement := Cmd();
					statements.AddStatement(statement);
				UNTIL (symbol.token = Scanner.Identifier) & (symbol.identifier = StringPool.GetIndex1("ENDCMDS"))
			*)
			ELSE
				RETURN Statement^(statements, outer);
			END;
		END Statement;

		PROCEDURE Cmd(): SyntaxTree.Statement;
		VAR cmd: CommandStatement; string: Strings.String;
		BEGIN
			NextSymbol;
			IF MandatoryString(string) THEN
			NEW(cmd, string);
			(* TRACE(string^) *)
			END;
			RETURN cmd;
		END Cmd;


	END Parser;

	Interpreter* = OBJECT (SyntaxTree.Visitor)
	VAR
		value: BOOLEAN;
		address-: Address;
		module-: Modules.Module;

		scope-: Scope;
		exit: BOOLEAN;
		error-: BOOLEAN;
		diagnostics: Diagnostics.Diagnostics;
		context-: Commands.Context;

		PROCEDURE & Init*(scope: Scope; diagnostics: Diagnostics.Diagnostics; context: Commands.Context);
		BEGIN
			IF scope = NIL THEN scope := global END;
			SELF.scope := scope;
			error := FALSE;
			SELF.diagnostics := diagnostics;
			SELF.context := context
		END Init;

		PROCEDURE SetScope*(s: Scope);
		BEGIN
			scope := s
		END SetScope;

		PROCEDURE Reset*;
		BEGIN
			error := FALSE;
		END Reset;


		PROCEDURE Error(CONST msg: ARRAY OF CHAR);
		BEGIN
			IF error THEN RETURN END;
			(*! use diagnostics *)
			error := TRUE;
			IF diagnostics # NIL THEN
				diagnostics.Error("",Diagnostics.Invalid, Diagnostics.Invalid, msg);
			END;
		END Error;

		PROCEDURE ErrorSS(CONST msg: ARRAY OF CHAR; id: StringPool.Index);
		VAR name: ARRAY 128 OF CHAR; message: ARRAY 256 OF CHAR;
		BEGIN
			IF error THEN RETURN END;
			(*! use diagnostics *)
			error := TRUE;
			COPY(msg, message);
			IF id # 0 THEN Strings.Append(message," "); StringPool.GetString(id, name); Strings.Append(message, name); END;
			IF diagnostics # NIL THEN
				diagnostics.Error("",Diagnostics.Invalid, Diagnostics.Invalid, message);
			END;
		END ErrorSS;

		(** syntax tree types omitted -- unused *)

		(** expressions *)

		PROCEDURE VisitSet*(x: SyntaxTree.Set);
		VAR s: SET; i: LONGINT; value: Value;
		BEGIN
			FOR i := 0 TO x.elements.Length()-1 DO
				IF GetValue(x.elements.GetExpression(i), value) THEN
					IF value IS Integer THEN INCL(s, value(Integer).value)
					ELSIF value IS Range THEN s := s + {FIRST(value(Range).value)..LAST(value(Range).value)}
					ELSE Error("wrong value type")
					END;
				END;
			END;
			NewSet(s)
		END VisitSet;

		PROCEDURE VisitMathArrayExpression*(x: SyntaxTree.MathArrayExpression);
		VAR numberElements, i: LONGINT; a: InterpreterSymbols.MathArrayValue;
		BEGIN
			numberElements := x.elements.Length();
			NEW(a, numberElements);
			FOR i := 0 TO numberElements-1 DO
				Expression(x.elements.GetExpression(i));
				a.SetValue(i,address.object(InterpreterSymbols.Value));
			END;
			address.object := a; value := TRUE;
		END VisitMathArrayExpression;

		PROCEDURE NewInt(i: LONGINT);
		VAR v: Integer;
		BEGIN
			NEW(v, i); address.object := v; value := TRUE
		END NewInt;

		PROCEDURE NewReal(i: LONGREAL);
		VAR v: Real;
		BEGIN
			NEW(v, i); address.object := v; value := TRUE
		END NewReal;

		PROCEDURE NewBool(b: BOOLEAN);
		VAR v: Boolean;
		BEGIN
			NEW(v, b); address.object := v; value := TRUE;
		END NewBool;

		PROCEDURE NewSet(s: SET);
		VAR v: Set;
		BEGIN
			NEW(v, s); address.object := v; value := TRUE;
		END NewSet;

		PROCEDURE NewString(CONST s: ARRAY OF CHAR);
		VAR v: String;
		BEGIN
			NEW(v, s); address.object := v; value := TRUE;
		END NewString;

		PROCEDURE NewRange(r: RANGE);
		VAR v: Range;
		BEGIN
			NEW(v, r ); address.object := v; value := TRUE;
		END NewRange;

		PROCEDURE NewChar(c: CHAR);
		VAR v: Char;
		BEGIN
			NEW(v, c); address.object := v; value := TRUE;
		END NewChar;

		PROCEDURE VisitUnaryExpression*(x: SyntaxTree.UnaryExpression);
		VAR value: Value; i: LONGINT; r: LONGREAL; b: BOOLEAN; operator: LONGINT;
		BEGIN
			operator := x.operator;
			IF ~GetValue(x, value) THEN RETURN END;
			IF value IS Integer THEN
				i := value(Integer).value;
				CASE operator OF
				Scanner.Minus: NewInt(-i)
				|Scanner.Plus: NewInt(i)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Real THEN
				r := value(Real).value;
				CASE operator OF
				Scanner.Minus: NewReal(-r)
				|Scanner.Plus: NewReal(r)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Boolean THEN
				b := value(Boolean).value;
				CASE operator OF
				Scanner.Not: NewBool(~b)
				ELSE Error("unary operator not supported")
				END;
			ELSIF value IS Set THEN
				CASE operator OF
				Scanner.Minus: NewSet(-value(Set).value)
				ELSE Error("unary operator not supported")
				END;
			ELSE
				Error("unary operation not supported");
			END;
		END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression*(x: SyntaxTree.BinaryExpression);
		VAR left, right: Value; operator: LONGINT; li, ri: LONGINT; lr, rr: LONGREAL; lb, rb:  BOOLEAN; sl, sr: SET;
		BEGIN
			operator := x.operator;
			IF ~GetValue(x.left, left) OR ~GetValue(x.right, right) THEN RETURN END;

			IF (left IS Integer) & (right IS Integer) THEN
				li := left(Integer).value; ri := right(Integer).value;
				CASE operator OF
				|Scanner.Plus: NewInt(li+ri)
				|Scanner.Minus: NewInt(li-ri);
				|Scanner.Times: NewInt(li * ri);
				|Scanner.Div: NewInt(li DIV ri);
				|Scanner.Mod: NewInt(li MOD ri);
				|Scanner.Equal: NewBool(li = ri);
				|Scanner.Unequal: NewBool(li # ri)
				|Scanner.Less: NewBool(li < ri)
				|Scanner.LessEqual: NewBool(li <= ri)
				|Scanner.Greater: NewBool(li > ri)
				|Scanner.GreaterEqual: NewBool(li >= ri)
				|Scanner.Slash: NewReal(li/ri)
				ELSE Error("binary operator not supported")
				END;
			ELSIF ((left IS Integer) OR (left IS Real)) & ((right IS Integer) OR (right IS Real)) THEN
				IF left IS Integer THEN lr := left(Integer).value
				ELSE lr := left(Real).value
				END;
				IF right IS Integer THEN rr := right(Integer).value;
				ELSE rr := right(Real).value
				END;
				CASE operator OF
				|Scanner.Plus: NewReal(lr+rr)
				|Scanner.Minus: NewReal(lr-rr);
				|Scanner.Times: NewReal(lr * rr);
				|Scanner.Slash: NewReal(lr / rr);
				|Scanner.Equal: NewBool(lr = rr);
				|Scanner.Unequal: NewBool(lr # rr)
				|Scanner.Less: NewBool(lr < rr)
				|Scanner.LessEqual: NewBool(lr <= rr)
				|Scanner.Greater: NewBool(lr > rr)
				|Scanner.GreaterEqual: NewBool(lr >= rr)
				ELSE Error("binary operator not supported")
				END;
			ELSIF (left IS Boolean) & (right IS Boolean) THEN
				lb := left(Boolean).value; rb := right(Boolean).value;
				CASE operator OF
				|Scanner.Or: NewBool(lb OR rb);
				|Scanner.And: NewBool(lb & rb);
				|Scanner.Equal: NewBool(lb = rb)
				|Scanner.Unequal: NewBool(lb # rb)
				ELSE Error("operator not supported")
				END;
			ELSIF (left IS String) & (right IS String) THEN
				CASE operator OF
				|Scanner.Equal: NewBool(left(String).value^ = right(String).value^);
				|Scanner.Unequal: NewBool(left(String).value^ = right(String).value^);
				|Scanner.Less: NewBool(left(String).value^ < right(String).value^);
				|Scanner.LessEqual: NewBool(left(String).value^ <= right(String).value^);
				|Scanner.Greater: NewBool(left(String).value^ > right(String).value^);
				|Scanner.GreaterEqual: NewBool(left(String).value^ >= right(String).value^);
				ELSE Error("binary operator not supported")
				END
			ELSIF (left IS Set) & (right IS Set) THEN
				sl := left(Set).value; sr := right(Set).value;
				CASE operator OF
				|Scanner.Plus: NewSet(sl+sr)
				|Scanner.Minus: NewSet(sl-sr);
				|Scanner.Times: NewSet(sl * sr);
				|Scanner.Slash: NewSet(sl / sr);
				|Scanner.Equal: NewBool(sl = sr);
				|Scanner.Unequal: NewBool(sl # sr)
				|Scanner.Less: NewBool(sl < sr)
				|Scanner.LessEqual: NewBool(sl <= sr)
				|Scanner.Greater: NewBool(sl > sr)
				|Scanner.GreaterEqual: NewBool(sl >= sr)
				ELSE Error("binary operator not supported")
				END;
			ELSIF (left IS Integer) & (right IS Set) THEN
				CASE operator OF
				Scanner.In: NewBool(left(Integer).value IN right(Set).value)
				ELSE Error("binary operator not supported")
				END;
			ELSE
				Error("binary operation not supported");
				Printout.Info("binary operation", x);
			END;
		END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression*(x: SyntaxTree.RangeExpression);
		VAR first,last,step: LONGINT; value: Integer;
		BEGIN
			IF ~ExpectInteger(x.first, value) THEN RETURN END;
			first := value.value;
			IF ~ExpectInteger(x.last, value) THEN RETURN END;
			last := value.value;
			IF (x.step # NIL) & ExpectInteger(x.step, value) THEN
				step := value.value;
			ELSE
				step := 1
			END;
			NewRange(first ..last BY step);
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: SyntaxTree.TensorRangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitTensorRangeExpression;

		PROCEDURE VisitConversion*(x: SyntaxTree.Conversion);
		BEGIN HALT(100) (* abstract *) END VisitConversion;

		(** designators (expressions) *)
		PROCEDURE VisitDesignator*(x: SyntaxTree.Designator);
		BEGIN HALT(100) (* abstract *) END VisitDesignator;

		(*
		PROCEDURE FindInScope(scope: Scope; symbol: StringPool.Index): Value;
		VAR item: Value;
		BEGIN
			REPEAT
				item := scope.Find1(symbol);

				IF (item = NIL) THEN
					scope := scope.outer
				ELSE
					scope := NIL
				END;
			UNTIL (scope = NIL);
			RETURN item
		END FindInScope;
		*)

		PROCEDURE VisitIdentifierDesignator*(x: SyntaxTree.IdentifierDesignator);
		VAR moduleName: Modules.Name; msg: ARRAY 128 OF CHAR; res: LONGINT;
		BEGIN
			ASSERT(x.left = NIL);
			address.name := x.identifier;
			(*
			address.object := FindInScope(address.scope, address.name);
			*)
			address.object := scope.FindObject1(address.name, -1, address.in);
			IF address.object = NIL THEN
				StringPool.GetString(address.name, moduleName);
				module := Modules.ThisModule(moduleName, res, msg)
			ELSE
				module := NIL
			END;
		END VisitIdentifierDesignator;

		PROCEDURE VisitSelectorDesignator*(x: SyntaxTree.SelectorDesignator);
		VAR traverse: BOOLEAN; name: ARRAY 128 OF CHAR;
		BEGIN
			Expression(x.left); traverse := FALSE;
			IF error THEN RETURN END;
			address.name := x.identifier;
			IF (address.object # NIL) THEN
				address.in := address.object;
				address.object := InterpreterSymbols.FindInObject1(address.object, x.identifier,-1);
			ELSIF module # NIL THEN
				StringPool.GetString(address.name, name);
			ELSE
				ErrorSS("invalid selector",address.name);
				address.in := NIL;
			END;
		END VisitSelectorDesignator;

		PROCEDURE VisitParameterDesignator*(x: SyntaxTree.ParameterDesignator);
		VAR e: SyntaxTree.Expression;
		BEGIN HALT(100);
			e := x.left;
			(*IF e IS IdentifierDesignator THEN
			END;
			*)
		END VisitParameterDesignator;

		PROCEDURE VisitArrowDesignator*(x: SyntaxTree.ArrowDesignator);
		BEGIN HALT(100) (* abstract *) END VisitArrowDesignator;

		PROCEDURE VisitBracketDesignator*(x: SyntaxTree.BracketDesignator);
		VAR array: InterpreterSymbols.MathArrayValue; i: LONGINT; element: InterpreterSymbols.Value; index: Integer; obj: PersistentObjects.Object;
			leftValue, rightValue: Value; filter: InterpreterSymbols.ObjectFilter; expression: SyntaxTree.Expression;
			attribute, value: ARRAY 128 OF CHAR;
		BEGIN
			Expression(x.left);
			IF (address.object # NIL) & (address.object IS InterpreterSymbols.MathArrayValue) THEN
				element := address.object(InterpreterSymbols.MathArrayValue);
				FOR i := 0 TO x.parameters.Length()-1 DO
					array := element(InterpreterSymbols.MathArrayValue);
					IF GetInteger(x.parameters.GetExpression(i), index) THEN
						element := array.GetValue(index.value);
					END;
				END;
				address.object := element;
			ELSIF (address.object # NIL) THEN
				NEW(filter); obj := address.object;
				FOR i := 0 TO x.parameters.Length()-1 DO
					expression := x.parameters.GetExpression(i);
					IF (expression IS SyntaxTree.BinaryExpression) & (expression(SyntaxTree.BinaryExpression).operator = Scanner.Equal) THEN
						IF (expression(SyntaxTree.BinaryExpression).left IS SyntaxTree.IdentifierDesignator) &
						GetValue(expression(SyntaxTree.BinaryExpression).right, rightValue) THEN
							StringPool.GetString(
							expression(SyntaxTree.BinaryExpression).left(SyntaxTree.IdentifierDesignator).identifier, attribute);
							rightValue(InterpreterSymbols.Value).GetString(value);
							obj := filter.Filter(obj, attribute, value)
						ELSE HALT(200)
						END;
					ELSE
						IF GetValue(expression, leftValue) THEN
							IF leftValue IS String THEN
								leftValue(InterpreterSymbols.Value).GetString(value);
								obj := filter.Filter(obj, "name", value);
							ELSIF leftValue IS Integer THEN
								IF obj IS PersistentObjects.ObjectList THEN
									address.object := obj(PersistentObjects.ObjectList).GetElement(leftValue(Integer).value)
								ELSIF obj IS InterpreterSymbols.Container THEN
									address.object := obj(InterpreterSymbols.Container).GetItem(leftValue(Integer).value)
								ELSE Error("cannot be indexed")
								END;
							END;
						END;
					END;
				END;
				IF obj(InterpreterSymbols.Container).symbols.Length() > 0 THEN
					address.object := obj(InterpreterSymbols.Container).GetItem(0);
				ELSE
					Error("no such symbol")
				END;
			END;
		END VisitBracketDesignator;

		PROCEDURE VisitSymbolDesignator*(x: SyntaxTree.SymbolDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSymbolDesignator;

		PROCEDURE VisitIndexDesignator*(x: SyntaxTree.IndexDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIndexDesignator;

		PROCEDURE VisitProcedureCallDesignator*(x: SyntaxTree.ProcedureCallDesignator);
		BEGIN HALT(100)
		END VisitProcedureCallDesignator;

		PROCEDURE VisitBuiltinCallDesignator*(x: SyntaxTree.BuiltinCallDesignator);
		BEGIN HALT(100)
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitTypeGuardDesignator*(x: SyntaxTree.TypeGuardDesignator);
		BEGIN HALT(100) (* abstract *) END VisitTypeGuardDesignator;

		PROCEDURE VisitDereferenceDesignator*(x: SyntaxTree.DereferenceDesignator);
		BEGIN HALT(100) (* abstract *) END VisitDereferenceDesignator;

		PROCEDURE VisitSupercallDesignator*(x: SyntaxTree.SupercallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator*(x: SyntaxTree.SelfDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator*(x: SyntaxTree.ResultDesignator);
		BEGIN HALT(100) (* abstract *) END VisitResultDesignator;

		(** values *)
		PROCEDURE VisitValue*(x: SyntaxTree.Value);
		BEGIN HALT(100) (* abstract *) END VisitValue;

		PROCEDURE VisitBooleanValue*(x: SyntaxTree.BooleanValue);
		BEGIN
			NewBool(x.value)
		END VisitBooleanValue;

		PROCEDURE VisitIntegerValue*(x: SyntaxTree.IntegerValue);
		BEGIN
			NewInt(x.value)
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue*(x: SyntaxTree.CharacterValue);
		BEGIN
			NewChar(x.value);
		END VisitCharacterValue;

		PROCEDURE VisitSetValue*(x: SyntaxTree.SetValue);
		BEGIN
			NewSet(x.value)
		END VisitSetValue;

		PROCEDURE VisitMathArrayValue*(x: SyntaxTree.MathArrayValue);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayValue;

		PROCEDURE VisitRealValue*(x: SyntaxTree.RealValue);
		BEGIN
			NewReal(x.value)
		END VisitRealValue;

		PROCEDURE VisitComplexValue*(x: SyntaxTree.ComplexValue);
		BEGIN HALT(100) (* abstract *) END VisitComplexValue;

		PROCEDURE VisitStringValue*(x: SyntaxTree.StringValue);
		BEGIN
			NewString(x.value^);
		END VisitStringValue;

		PROCEDURE VisitNilValue*(x: SyntaxTree.NilValue);
		BEGIN HALT(100) (* abstract *) END VisitNilValue;

		PROCEDURE VisitEnumerationValue*(x: SyntaxTree.EnumerationValue);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationValue;

		(** symbols *)
		PROCEDURE VisitSymbol*(x: SyntaxTree.Symbol);
		BEGIN HALT(100) (* abstract *) END VisitSymbol;

		PROCEDURE VisitTypeDeclaration*(x: SyntaxTree.TypeDeclaration);
		BEGIN HALT(100) (* abstract *) END VisitTypeDeclaration;

		PROCEDURE VisitConstant*(x: SyntaxTree.Constant);
		BEGIN HALT(100) (* abstract *) END VisitConstant;

		PROCEDURE VisitVariable*(x: SyntaxTree.Variable);
		BEGIN HALT(100) (* abstract *) END VisitVariable;

		PROCEDURE VisitParameter*(x: SyntaxTree.Parameter);
		BEGIN HALT(100) (* abstract *) END VisitParameter;

		PROCEDURE VisitProcedure*(x: SyntaxTree.Procedure);
		BEGIN HALT(100) (* abstract *) END VisitProcedure;

		PROCEDURE VisitBuiltin*(x: SyntaxTree.Builtin);
		BEGIN HALT(100) (* abstract *) END VisitBuiltin;

		PROCEDURE VisitOperator*(x: SyntaxTree.Operator);
		BEGIN HALT(100) (* abstract *) END VisitOperator;

		PROCEDURE VisitImport*(x: SyntaxTree.Import);
		BEGIN HALT(100) (* abstract *) END VisitImport;

		(* copy src to value string replacing substrings that are embraced between refSymbols by expression value *)
		PROCEDURE TranslateString*(cmd: CHAR; CONST str: ARRAY OF CHAR; VAR dest: Strings.String): BOOLEAN;
		CONST
			LeftDelimiter = '{'; RightDelimiter = '}';
		VAR
			position : LONGINT; ch: CHAR;
			destination, expMaker: Scanner.StringMaker; destinationWriter, expressionWriter: Streams.Writer; scanner: Scanner.Scanner; parser: Parser;
			expression: SyntaxTree.Expression; value: Value; len: LONGINT;
			comment: LONGINT;

			PROCEDURE Next(VAR ch: CHAR);
			BEGIN
				IF position = LEN(str) THEN ch := 0X ELSE ch := str[position]; INC(position) END;
			END Next;

			PROCEDURE EvaluateExpression();
			VAR str: Strings.String; reader: Streams.Reader; done: BOOLEAN;
			BEGIN
				reader := expMaker.GetReader();
				NEW(scanner, "", reader, 0, NIL);
				NEW(parser, scanner, NIL);
				REPEAT
					error := FALSE;
					expression := parser.Expression();
					done := GetValue(expression, value);
				UNTIL done OR ~parser.Optional(Scanner.Colon);

				IF done THEN value(InterpreterSymbols.Value).WriteValue(destinationWriter);
				ELSE
					destinationWriter.String("#COULD NOT INTERPRETE#");
					error := TRUE;
				END;
			END EvaluateExpression;

		BEGIN
			error := FALSE;
			position := 0;
			Next(ch);
			NEW(destination,256); destinationWriter := destination.GetWriter();
			NEW(expMaker, 256); expressionWriter := expMaker.GetWriter();
			comment := 0;

			WHILE (ch # 0X) DO
				(* copy string literally *)
				IF (comment = 0) & (ch = cmd) THEN
					Next(ch);
					IF ch = LeftDelimiter THEN
						Next(ch);
						REPEAT
							WHILE (ch # 0X) & (ch # RightDelimiter) DO expressionWriter.Char(ch); Next(ch) END;
							IF ch = RightDelimiter THEN
								Next(ch); IF (ch # cmd) THEN expressionWriter.Char(RightDelimiter) END;
							END;
						UNTIL (ch=0X) OR (ch = cmd);
						IF ch # 0X THEN Next(ch) END;
						expressionWriter.Update;
						EvaluateExpression();
						expMaker.Clear;
					ELSE
						destinationWriter.Char(cmd);
					END;
				(* remove comments *)
				ELSIF ch = "(" THEN
					Next(ch);
					IF ch = "*" THEN 
						INC(comment); Next(ch);
					ELSIF comment = 0 THEN 
						destinationWriter.Char("(");
					END;
				ELSIF ch="*" THEN
					Next(ch);
					IF ch = ")" THEN 
						DEC(comment); 
						IF comment < 0 THEN comment := 0 END; Next(ch);
					ELSIF comment = 0 THEN 
						destinationWriter.Char("*")
					END;
				ELSE
					IF comment = 0 THEN destinationWriter.Char(ch) END;
					Next(ch);
				END;
			END;
			destinationWriter.Update;
			dest := destination.GetString(len);
			RETURN ~error
		END TranslateString;
		
		PROCEDURE VisitCommandStatement(x: CommandStatement);
		VAR t: Strings.String; res: LONGINT; msg: ARRAY 128 OF CHAR; i: LONGINT; array: Strings.StringArray; pos: LONGINT;
			command: ARRAY 256 OF CHAR; context: Commands.Context;

			PROCEDURE CreateContext(paramString : Strings.String; pos: LONGINT) : Commands.Context;
			VAR c : Commands.Context; arg : Streams.StringReader; dummy : ARRAY 1 OF CHAR; len: LONGINT;
			BEGIN
				IF (paramString = NIL) THEN
					NEW(arg, 1); dummy := ""; arg.SetRaw(dummy, 0, 1);
				ELSE
					len := Strings.Length(paramString^)+1 (*+1 to include 0X *);
					NEW(arg, len-pos); arg.SetRaw(paramString^, pos, len-pos);
				END;
				NEW(c, context.in, arg, context.out, context.error, context.caller);
				RETURN c;
			END CreateContext;

			PROCEDURE IsDelimiter(ch : CHAR) : BOOLEAN;
			CONST 	CR = 0DX;  LF = 0AX;  TAB = 9X;
			BEGIN
				RETURN (ch = " ") OR (ch = CR) OR (ch = LF) OR (ch = TAB) OR (ch = ";") OR (ch = 0X);
			END IsDelimiter;

		BEGIN
			IF SELF.context = NIL THEN
				context := Commands.GetContext();
			ELSE
				context := SELF.context
			END;
			IF TranslateString("?", x.command^, t) THEN END;
			array := Strings.Split(t^, "~");
			FOR i := 0 TO LEN(array)-1 DO
				Strings.TrimWS(array[i]^);
				IF (array[i]^ # "") THEN
						(* extract command *)
						pos := 0;
						WHILE ~IsDelimiter(array[i][pos])  DO command[pos] := array[i][pos]; INC(pos); END;
						command[pos] := 0X;
						IF pos # 0 THEN
							context := CreateContext(array[i], pos);
							Commands.Activate(command, context, {Commands.Wait, Commands.InheritContext}, res, msg);
							IF res # 0 THEN
								context.out.String("Interpreter: "); context.error.String(command); context.error.String(" failed"); context.error.Ln
							END;
						END;
				END;

			END;
			IF res # 0 THEN Error(msg) END;
		END VisitCommandStatement;

		(** statements *)
		PROCEDURE VisitStatement*(x: SyntaxTree.Statement);
		BEGIN
			IF x IS CommandStatement THEN
				VisitCommandStatement(x(CommandStatement));
			ELSE HALT(100)
			END;
		END VisitStatement;

		PROCEDURE VisitProcedureCallStatement*(x: SyntaxTree.ProcedureCallStatement);
		BEGIN x.call.Accept(SELF) END VisitProcedureCallStatement;

		PROCEDURE LoadValue;
		BEGIN
			IF address.object = NIL THEN
				ErrorSS("could not load value", address.name);
			END;
		END LoadValue;

		PROCEDURE GetValue*(x: SyntaxTree.Expression; VAR w: Value): BOOLEAN;
		BEGIN
			IF error THEN RETURN FALSE END;
			Expression(x);
			LoadValue();
			w := address.object;
			RETURN ~error
		END GetValue;

		PROCEDURE GetInteger(x: SyntaxTree.Expression; VAR i: Integer): BOOLEAN;
		VAR v: Value;
		BEGIN
			IF GetValue(x, v) & (v IS Integer) THEN i := v(Integer); RETURN TRUE ELSE RETURN FALSE END;
		END GetInteger;

		PROCEDURE ExpectInteger(x: SyntaxTree.Expression; VAR i: Integer): BOOLEAN;
		BEGIN IF ~GetInteger(x, i) THEN Error("invalid value - must be integer"); RETURN FALSE ELSE RETURN TRUE END;
		END ExpectInteger;

		PROCEDURE GetBoolean(x: SyntaxTree.Expression; VAR i: Boolean): BOOLEAN;
		VAR v: Value;
		BEGIN
			IF GetValue(x, v) & (v IS Boolean) THEN i := v(Boolean); RETURN TRUE ELSE RETURN FALSE END;
		END GetBoolean;

		PROCEDURE ExpectBoolean(x: SyntaxTree.Expression; VAR b: Boolean): BOOLEAN;
		BEGIN IF ~GetBoolean(x, b) THEN Error("invalid value - must be boolean"); RETURN FALSE ELSE RETURN TRUE END;
		END ExpectBoolean;

		PROCEDURE PutValue(x: SyntaxTree.Designator; v: Value);
		BEGIN
			x.Accept(SELF);
			IF (address.in # NIL) & (address.name # 0) & (address.in IS InterpreterSymbols.Container) THEN
				address.in(InterpreterSymbols.Container).Enter1(v, address.name);
			END;
		END PutValue;

		PROCEDURE VisitAssignment*(x: SyntaxTree.Assignment);
		VAR value: Value;
		BEGIN
			IF GetValue(x.right, value) THEN
				PutValue(x.left, value);
			END;
		END VisitAssignment;

		PROCEDURE IfPart(ifPart: SyntaxTree.IfPart): BOOLEAN;
		VAR value: Boolean;
		BEGIN
			IF ExpectBoolean(ifPart.condition,value) THEN
				IF value(Boolean).value THEN
					StatementSequence(ifPart.statements);
					RETURN TRUE
				END;
			END;
			RETURN FALSE
		END IfPart;

		PROCEDURE VisitIfStatement*(x: SyntaxTree.IfStatement);
		VAR i: LONGINT; elsif: SyntaxTree.IfPart;
		BEGIN
			IF IfPart(x.ifPart) THEN RETURN END;
			FOR i := 0 TO x.ElsifParts()-1 DO
				elsif := x.GetElsifPart(i);
				IF IfPart(elsif) THEN RETURN END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart)
			END;
		END VisitIfStatement;

		PROCEDURE VisitWithStatement*(x: SyntaxTree.WithStatement);
		BEGIN HALT(100) (* abstract *) END VisitWithStatement;

		PROCEDURE CasePart(x: SyntaxTree.CasePart; b: SyntaxTree.BinaryExpression): BOOLEAN;
		VAR i: LONGINT; value: Value;
		BEGIN
			FOR i := 0 TO x.elements.Length()-1 DO
				b.SetRight(x.elements.GetExpression(i));
				IF GetValue(b, value) & (value IS Boolean) THEN
					IF value(Boolean).value THEN StatementSequence(x.statements); RETURN TRUE END;
				ELSE Error("invalid non-boolean value")
				END
			END;
			RETURN FALSE
		END CasePart;

		PROCEDURE VisitCaseStatement*(x: SyntaxTree.CaseStatement);
		VAR binary: SyntaxTree.BinaryExpression; i: LONGINT;
		BEGIN
			binary := SyntaxTree.NewBinaryExpression(0, x.variable, x.variable, Scanner.Equal);
			FOR i := 0 TO x.CaseParts()-1 DO
				IF CasePart(x.GetCasePart(i), binary) THEN RETURN END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart)
			END;
		END VisitCaseStatement;

		PROCEDURE VisitWhileStatement*(x: SyntaxTree.WhileStatement);
		VAR value: Boolean;
		BEGIN
			WHILE ExpectBoolean(x.condition, value) & value.value DO
				StatementSequence(x.statements);
			END;
		END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement*(x: SyntaxTree.RepeatStatement);
		VAR value: Boolean;
		BEGIN
			REPEAT
				StatementSequence(x.statements);
			UNTIL ~ExpectBoolean(x.condition, value) OR value.value
		END VisitRepeatStatement;

		PROCEDURE VisitForStatement*(x: SyntaxTree.ForStatement);
		VAR fromV, toV, byV: Integer; from, to, by,i: LONGINT; int: Integer;
		BEGIN
			IF ExpectInteger(x.from, fromV) & ExpectInteger(x.to, toV) THEN
				from := fromV.value;
				to := toV.value;
				Expression(x.variable);
				NEW(int, from);
				PutValue(x.variable, int);
				i := from;
				WHILE i <= to DO
					int.value := i;
					StatementSequence(x.statements);
					INC(i);
				END;
			END;
		END VisitForStatement;

		PROCEDURE VisitLoopStatement*(x: SyntaxTree.LoopStatement);
		VAR prevExit: BOOLEAN;
		BEGIN
			prevExit := exit;
			exit := FALSE;
			LOOP
				StatementSequence(x.statements);
				IF exit THEN EXIT END;
			END;
			exit := prevExit
		END VisitLoopStatement;

		PROCEDURE VisitExitStatement*(x: SyntaxTree.ExitStatement);
		BEGIN
			exit := TRUE
		END VisitExitStatement;

		PROCEDURE VisitReturnStatement*(x: SyntaxTree.ReturnStatement);
		BEGIN HALT(100) (* abstract *) END VisitReturnStatement;

		PROCEDURE VisitAwaitStatement*(x: SyntaxTree.AwaitStatement);
		BEGIN HALT(100) (* abstract *) END VisitAwaitStatement;

		PROCEDURE VisitStatementBlock*(x: SyntaxTree.StatementBlock);
		BEGIN
			StatementSequence(x.statements)
		END VisitStatementBlock;

		PROCEDURE VisitCode*(x: SyntaxTree.Code);
		BEGIN HALT(100) (* abstract *) END VisitCode;

		PROCEDURE Expression(x: SyntaxTree.Expression);
		BEGIN
			value := FALSE;
			x.Accept(SELF);
		END Expression;

		PROCEDURE Statement(x: SyntaxTree.Statement);
		BEGIN
			address.object := NIL;
			x.Accept(SELF);
		END Statement;

		PROCEDURE StatementSequence*(x: SyntaxTree.StatementSequence);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length()-1 DO
				Statement(x.GetStatement(i));
			END;
		END StatementSequence;

	END Interpreter;

	Resolver*= OBJECT
	VAR
		interpreter: Interpreter;
		content: PersistentObjects.Content;
		resolved: Basic.HashTable;
		current: Scope;
		changed: BOOLEAN;

		PROCEDURE & InitResolver*;
		BEGIN
			NEW(content); NEW(resolved,64); NEW(interpreter, NIL, NIL, NIL);
		END InitResolver;

		PROCEDURE Traverse(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR index: LONGINT; success: BOOLEAN;
		BEGIN
			IF array THEN index := 0 ELSE index := -1 END;
			REPEAT
				success := FALSE;
				content.success := FALSE;
				current.object.Get(name, index, content);
				IF content.success & (content.class = PersistentObjects.Class.Object) THEN
					success := content.object # NIL;
					IF content.object # NIL THEN
						DoResolve(current.Enter(content.object)); (* content object can be overwritten as sideeffect! *)
					END;
				END;
				INC(index);
			UNTIL ~array OR ~success
		END Traverse;

		PROCEDURE DoResolve*(scope: Scope);
		VAR translation: PersistentObjects.Interpretation; prev: Scope; str: Strings.String;
		BEGIN
			IF (scope.object # NIL) & ~resolved.Has(scope.object) THEN
				prev := current;
				current := scope;
				resolved.Put(scope.object, SELF);
				interpreter.Init(scope, NIL, NIL);

				translation := scope.object.firstTranslation;
				WHILE translation # NIL DO
					IF EnableTrace THEN D.String("resolve "); D.String(translation.name^); D.String(":"); D.String(translation.str^); END;
					IF interpreter.TranslateString("?", translation.str^,  str) THEN
						IF EnableTrace THEN D.String(":"); D.Str(str^); END;
						scope.object.Get(translation.name^, -1, content);
						IF ~content.Equals(str^) THEN
							changed := TRUE;
							content.SetAsString(str^);
						END;
						scope.object.Set(translation.name^, -1, content);
					ELSE
						IF EnableTrace THEN D.String(":could not resolve"); END;
					END;
					IF EnableTrace THEN D.Ln; END;
					translation := translation.next
				END;

				scope.object.Enumerate(Traverse);

				current := prev;
			END;
		END DoResolve;

		PROCEDURE Resolve*(scope: InterpreterSymbols.Scope);
		BEGIN
			REPEAT
				changed := FALSE;
				resolved.Clear();
				DoResolve(scope);
			UNTIL ~changed;
		END Resolve;

	END Resolver;

VAR global-: Scope;

PROCEDURE Statements*(context: Commands.Context);
VAR scanner: Scanner.Scanner; parser: Parser; diagnostics: Diagnostics.StreamDiagnostics;
	seq: SyntaxTree.StatementSequence; interpreter: Interpreter;
BEGIN
	NEW(diagnostics, context.error);
	scanner := Scanner.NewScanner("",context.arg,0,diagnostics);
	NEW(parser, scanner, diagnostics);
	seq := parser.StatementSequence(NIL);
	NEW(interpreter, global, diagnostics,context); interpreter.StatementSequence(seq);
END Statements;

PROCEDURE Expression*(context: Commands.Context);
VAR scanner: Scanner.Scanner; parser: Parser; diagnostics: Diagnostics.StreamDiagnostics;
	interpreter: Interpreter; value: Value; expression: SyntaxTree.Expression;
BEGIN
	NEW(diagnostics, context.error);
	scanner := Scanner.NewScanner("",context.arg,0,diagnostics);
	NEW(parser, scanner, diagnostics);
	expression := parser.Expression();
	NEW(interpreter, global, diagnostics,NIL);
	IF interpreter.GetValue(expression, value) THEN
		value(InterpreterSymbols.Value).WriteValue(context.out); context.out.Ln
	ELSE
		context.error.String("could not evaluate expression"); context.error.Ln
	END;
END Expression;

PROCEDURE TranslateString*(context: Commands.Context);
VAR dest: Strings.String; testString: ARRAY 256 OF CHAR; interpreter: Interpreter; streamDiagnostics: Diagnostics.StreamDiagnostics;
BEGIN
	NEW(streamDiagnostics, context.error);
	NEW(interpreter, global, streamDiagnostics,NIL);
	WHILE context.arg.GetString(testString) DO
		IF interpreter.TranslateString("?", testString, dest) THEN
			context.out.String("RESULT: ");
			context.out.String(dest^);
			context.out.Ln;
		ELSE
			context.error.String("could not translate: ");
			context.error.String(dest^);
			context.error.Ln;
		END;
	END;
END TranslateString;

PROCEDURE InitGlobalScope;
VAR container: Container;
BEGIN
	NEW(container);
	NEW(global, NIL, container);
END InitGlobalScope;

BEGIN
	InitGlobalScope;
END FoxInterpreter.

SystemTools.Free FoxInterpreter FoxInterpreterSymbols ~

FoxInterpreter.Statements
	FOR i := 1 TO 100 DO
		CASE i MOD 10 OF
		1: suffix := "st"
		|2: suffix := "nd"
		|3: suffix := "rd"
		ELSE suffix := "th"
		END;
		IF i MOD 9 = 0 THEN
			CMD SystemTools.Show This is the ?{i}?{suffix} run. ;
			CMD SystemTools.Ln;
		END;
	END;
~
FoxInterpreter.Expression
	i MOD 10  ~



FoxInterpreter.Statements
	s := {0..10, 15};
	a := 10;
	b := 10..20;
	c := {a,b};
	x := 10;
	y := 20;
	z := x;
	z := x + y;
	b := x = y;
	nb := x # y;
	FOR i := 0 TO 3 DO
		a := i;
		IF i<2 THEN
			a := 200+i;
		END;
		CASE i OF
		0: a := 2000;
		|2: HALT(100)
		END;
	END;
	~
	TRACE(x);

	FOR i := 0 TO 100 DO
		x[i] := i
	END;
	~

FoxInterpreter.TranslateString
	"This is a string ?{15+2*20*a:32}? oha."
	"The rest of this string will be evaluated ?{3+5 = 20}?"
	"?{ 100*15"
	"a set in a evaluated expression ?{{1,2,4}}?"
	~

FoxInterpreter.Statements
	a := [[1,2,3],[4,5,6],[7,8,9]];
	FOR i := 0 TO 2 DO
	FOR j := 0 TO 2 DO
		CMD \+"SystemTools.Show ?{a[i,j]}? ;"+\
	END;
		CMD \+"SystemTools.Ln;"+\
	END;
	CMD \+"SystemTools.Show ?{a}? "+\
	~

SystemTools.FreeDownTo FoxInterpreter FoxInterpreterSymbols ~

FoxInterpreter.Statements
	version := 02000302H;
	a := [
	(* development , version base, TL300, CN, SingleSensor, Version *)
	[FALSE, "TLxDev", FALSE, FALSE, FALSE, version],
	[FALSE, "TL400", FALSE, FALSE, FALSE, version],
	[FALSE, "TL300", TRUE, FALSE, TRUE, version],
	[FALSE, "TL300CN", TRUE, TRUE, FALSE, version],
	[FALSE, "TL300USsu", TRUE, FALSE, TRUE, version],
	[FALSE, "TL300USrt", TRUE, FALSE, FALSE, version]
	];
	FOR i := 0 TO 5 DO
		major := a[i,5] DIV 1000000H MOD 100H;
		minor := a[i,5] DIV 10000H MOD 100H;
		release := a[i,5] DIV 100H MOD 100H;
		internal := a[i,5] MOD 100H;
		CMD \+"
		SystemTools.Show Building ?{a[i,1]}? Version ?{major}?.?{minor}?.?{release}?.?{internal}? ~
		SystemTools.Ln ~
		FSTools.CreateFile -c -r TLHostConst.Mod
			MODULE TLHostConst;
			(**
				purpose: GUI Configuration Controller. Sets basics for differentiation of different product lines.
				author: Felix Friedrich
			*)

			CONST
				Development*=?{a[i,0]}?;
				VersionBase*="?{a[i,1]}? ";
				TL300*=?{a[i,2]}?;
				CN*=?{a[i,3]}?;
				SingleSensor*=?{a[i,4]}?;
				Version* = ?{a[i,5]}?;
			END TLHostConst.
		~
		Compiler.Compile  --objectFile=Generic Runtime.Mod Trace.Mod  A2/Win32.MiniKernel.Mod A2/Win32.WatchdogServer.Mod ~

		StaticLinker.Link
			--fileFormat=PE32
			--fileName=A2Watchdog.exe
			--extension=Gof
			--displacement=401000H

			Runtime Trace MiniKernel WatchdogServer ~

		SystemTools.Show Create ramdisk and format with FAT file system... ~ SystemTools.Ln ~
		VirtualDisks.InstallRamdisk RAMDISK 240000 ~
		Partitions.WriteMBR RAMDISK#0 OBEMBR.Bin ~
		Partitions.Create RAMDISK#1 12 1000 ~
		Partitions.Format RAMDISK#1 FatFS  ~
		FSTools.Mount WINAOS FatFS RAMDISK#1 ~

		SystemTools.Ln ~ SystemTools.Show Create WinAOS directory structure... ~
		FSTools.CreateDirectory WINAOS:/TL ~
		FSTools.CreateDirectory WINAOS:/TL/obj ~
		FSTools.CreateDirectory WINAOS:/TL/source ~
		FSTools.CreateDirectory WINAOS:/TL/data ~
		FSTools.CreateDirectory WINAOS:/TL/skins ~
		FSTools.CreateDirectory WINAOS:/TL/fonts ~
		FSTools.CreateDirectory WINAOS:/TL/work ~
		SystemTools.Show Done. ~ SystemTools.Ln ~

		SystemTools.Ln ~ SystemTools.Show Create build directory and build WinAos... ~ SystemTools.Ln ~
		Release.Build
			-f=TL/TLHost.Tool --path="WINAOS:/TL/obj/" --build --zip WinAosMini ~

		SystemTools.Ln ~ SystemTools.Show Extracting data ... ~ SystemTools.Ln ~
		ZipTool.ExtractAll --prefix=WINAOS:/TL/data/ --sourcePath=WINAOS:/TL/obj/ --overwrite -d --silent
			Kernel.zip System.zip Drivers.zip
			ApplicationsMini.zip Compiler.zip GuiApplicationsMini.zip TL.zip
		~

		SystemTools.Ln ~ SystemTools.Show Removing object files from data folder... ~ SystemTools.Ln ~
		FSTools.DeleteFiles --silent WINAOS:/TL/data/*.Obw ~

		SystemTools.Ln ~ SystemTools.Show Extracting  fonts ... ~ SystemTools.Ln ~
		ZipTool.ExtractAll --prefix=WINAOS:/TL/fonts/ --sourcePath=WINAOS:/TL/obj/ --overwrite -d --silent
			ScreenFonts.zip TrueTypeFonts.zip
		~

		SystemTools.Ln ~ SystemTools.Show Delete ZIP archives from obj folder... ~ SystemTools.Ln ~
		FSTools.DeleteFiles --silent WINAOS:/TL/obj/*.zip ~

		SystemTools.Ln ~ SystemTools.Show Copy skins ... ~ SystemTools.Ln ~
		FSTools.CopyFiles  -o ../../source/*.skin => WINAOS:/TL/skins/*.skin ~


		SystemTools.Ln ~ SystemTools.Show Delete some large files that are not stricly required... ~ SystemTools.Ln ~
		FSTools.DeleteFiles
			WINAOS:/TL/data/UnicodeData.txt
			WINAOS:/TL/data/Setup.Text
			WINAOS:/TL/data/BootManager.Text
		~

		SystemTools.Ln ~ SystemTools.Show Delete some files from data folder... ~ SystemTools.Ln ~
		FSTools.DeleteFiles WINAOS:/TL/data/*.Bin ~
		FSTools.DeleteFiles
			WINAOS:/TL/data/TestContext.xml
			WINAOS:/TL/data/Release.Auto.dsk
			WINAOS:/TL/data/AosDefault.Pal
			WINAOS:/TL/data/OBL.Text
			WINAOS:/TL/data/License.Text
			WINAOS:/TL/data/bluebottle.xsl
			WINAOS:/TL/data/WMPerfMonAlerts.XML
			WINAOS:/TL/data/config.txt
			WINAOS:/TL/data/WMPerfMon.Text
			WINAOS:/TL/obj/CompileCommand.Tool
		~
		FSTools.CopyFiles WINAOS:/TL/data/ZeroSkin.zip => WINAOS:/TL/skins/ZeroSkin.zip ~
		FSTools.CopyFiles A2Watchdog.exe => WINAOS:/TL/A2Watchdog.exe ~
		FSTools.DeleteFiles WINAOS:/TL/data/ZeroSkin.zip ~


		SystemTools.Show Linking aos.exe ... ~ SystemTools.Ln ~
		PELinker.Link --path=WINAOS:/TL/obj/ --destination=WINAOS:/TL/tl.exe Win32.Aos.Link ~

		FSTools.CreateFile -c -r WINAOS:/TL/aos.ini
			[Configuration]
			Paths.Search = work;obj;source;data;skins;fonts;c:/windows/fonts/
			Paths.Work = work
			Oberon = OberonExternal.Text
			Boot  = Traps.Install
			Boot1 = FileTrapWriter.Install
			Boot2  = Display.Install --fullscreen --bits16 --noMouseCursor
			Boot3 = WindowManager.Install --noMouseCursor --bgColor=0F2EFFH
			Boot4 = Clipboard.Install
			Boot6 = HotKeys.Open
			Boot7 = TLC.EnableTrace
			Boot8 = TLC.SetClientTraceLog tltrace
			Boot9 = TLHost.Boot
			Trace = File
		~

		FSTools.CreateFile -c -r WINAOS:/TL/TL.bat
			A2Watchdog tl.exe
		~

		FSTools.DeleteFiles TL.zip ~
		SystemTools.Ln ~ SystemTools.Show Creating archive TL.zip... ~
		FSTools.Enumerate -s WINAOS:/TL/*.*
			ZipTool.Add --silent -r   TL.zip <#filename#>
		~
		FSTools.CloseFiles TL.zip ~
		SystemTools.Show Done ~ SystemTools.Ln ~

		FSTools.Unmount WINAOS ~
		VirtualDisks.Uninstall RAMDISK ~
		FSTools.CopyFiles -o TL.zip => ?{a[i,1]}?_?{major}?_?{minor}?_?{release}?_?{internal}?.zip ~
		"+\;
	END;
	~



