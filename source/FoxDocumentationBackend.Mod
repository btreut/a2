(**
	The special backend in the Fox compiler suite serves as a documentation generator to produce documents from Oberon source files.
	#author# Felix Friedrich
	#purpose# Documentation Generator
*)

MODULE FoxDocumentationBackend;

(**
@concept
= Documentation Backend

The [[FoxDocumentationBackend|documentation backend]] is mainly a tool to merge different informations, namely:
	# The information from the symbol and module scope structure
	# The information provided by documenting comments

Documentation comments that immediately precede a symbol or that are directly in the same line as a symbol are associated with this symbol.
Therefore the documentation contained within the respective comment is on the same level as the description of the symbol itself and will be
displayed together with the information about the symbol.

The following describes how a documentation is generated from a module:
	* Association to symbols and preprocessing
		## A comment that follows a symbol X and stands in the same line as X is associated with this symbol X.
		## Comments that follow the MODULE (or CELLNET) specification are treated separately to describe the module.
		## Any other comment that stand in front of some symbol Y is associated with this symbol Y.
		## Consecutive comments are always merged as character arrays mefore being parsed by the comment parser.
	* Module documentation
		## Each comment (or sequence of consecutive comments) is parsed by the comment parser into a separate document
		## During processing of a module, each symbol is described in a separate symbol section. The module itself is described in the module summary section.
		## Each comment document is merged with the respective symbol section in the overal module document.
	* Module documentation merging
		## When more than one modules are processed into one documentation file, the module documentats are merged into one global document.
		## The header of the document contains a linked list of all involved modules.

== Formatting elements
=== Paragraphs and line breaks
	Text is written in paragraphs. Paragraphs are separated by a blank line. Lines that are not separated by a blank line are considered as contiguous text (such as in LaTex)
	Explicit line breaks can be inserted using two backslashes:

	{{{ This is a line \\ that is broken }}}

	This is a line \\ that is broken
=== Text Styles
	Text can  be written boldface, underlined or  in italics. Left and right delimiters of such emphasized text may not be separated from the text by a whitespace.

	|=Name |= Code Example |= Translation |
	| Boldface | {{{ *example text*}}} | *Boldface Text* |
	| Underline | {{{ _example text_}}} | _Underline Text_ |
	| Italics | {{{ /example text/ }}} | /Italics Text/ |

=== bullets and lists
	Bulleted or numbered lists start with an asterisk or number sign, respectively. Description start with a text that is embraced by number signs.

{{{	* bullet 1
	** sub bullet1
	** sub bullet2
* bullet 2

# number 1
	## sub number 1
	## sub number 2
# number 2

#description label# description text
#description label2# description text2 }}}

	Result
		* bullet 1
			** sub bullet1
			** sub bullet2
		* bullet 2

		# number 1
			## sub number 1
			## sub number 2
		# number 2

		#description label# description text
		#description label2# description text2

=== Labels and links
	A label in the text is denoted as follows

	{{{ <<labelName>> }}} <<labelName>>

	A link in the text is denoted as

	{{{ [[labelName]] }}}

	or, if an alternative text should be displayed, it can be written as

	{{{ [[labelName|alternative text] }}}

=== Document Structure
	Documents consist of sections. A section is started with a sequence of {{{@}}} letter as the first characters on a separate line. Examples:

	{{{ @ title of a section of level 1 }}}

	{{{ @@ title of a section of level 2 }}}

	If the first text element of the title is a label, then this lable is attributed to the section.

	{{{ @ <<label>> title }}}

	This can be written shorter: If there is no whitespace between the leading section letter and a string, the string is also counted as the label of the section:

	{{{ @label title }}}

	For structuring a section, headings are provided. A heading is started with an equal sign as the first character in a separate line. Examples

{{{	= title of a paragraph of level 1
	== title of a paragraph of level 2
	=label title
	= <<label>> title }}}

=== Tables

	Tables can be written by writing cells in a separate paragraph. A cell is either a header cell or a data cell. Header cells start with a vertical bar and an equal sign
	while data cells are embraced by vertical lines only:

	{{{
	|= header 1 |= header 2 |= header 3
	| data 1 | data 2 | data 3
	| data 4 | data 5 | data 6 }}}

	Result:

	|= header 1 |= header 2 |= header 3
	| data 1 | data 2 | data 3
	| data 4 | data 5 | data 6 }}}

**)



IMPORT Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Scanner := FoxScanner, Backend := FoxBackend, Formats := FoxFormats,
		Options, Streams, Runtime, Strings, SymbolFileFormat := FoxBinarySymbolFile, Diagnostics,
		DocumentationTree := FoxDocumentationTree, DocumentationPrinter := FoxDocumentationPrinter, DocumentationHtml := FoxDocumentationHtml, DocumentationParser := FoxDocumentationParser, DocumentationScanner := FoxDocumentationScanner,
		D := Debugging, Files;

CONST
	Section=0;
	Item=1;
	Enum=2;
	MaxLevels=3;

	VisibleConstant*=3; (** visible constant comment **)

	(** second visible constant *)
	SecondVisibleConstant*=4;
	Third*=4;

	DefaultTemplateFile="oc/DocuTemplate.txt";
	
	KeywordElementType = ElementType.Bold;
	QualifiedIdentifierElementType = ElementType.Bold;

TYPE

	ElementType=DocumentationTree.ElementType;
	ParagraphType=DocumentationTree.ParagraphType;

	State= RECORD
		document: DocumentationTree.Document;
		section: DocumentationTree.Section;
		paragraphs: DocumentationTree.Paragraphs;
		paragraph: DocumentationTree.Paragraph;
		text: DocumentationTree.Text;
		scope: SyntaxTree.Scope;
	END;

	(** Printer object to write the documentation to a stream. Implemented as visitor on the Syntax Tree.*)
	Generator*= OBJECT (SyntaxTree.Visitor)
	VAR
		w,ws: Streams.StringWriter;
		case: LONGINT;
		diagnostics: Diagnostics.Diagnostics;

		(* transient state variables *)
		level: ARRAY MaxLevels OF LONGINT;

		current: State;
		document: DocumentationTree.Document;
		parameterDocument: DocumentationTree.Document;
		short: BOOLEAN;
		backend: DocumentationBackend;

		PROCEDURE &Init*(diagnostics: Diagnostics.Diagnostics);
		VAR i: LONGINT;
		BEGIN
			NEW(w,1024); NEW(ws, 64); case := Scanner.Uppercase;
			FOR i := 0 TO MaxLevels-1 DO level[i] := 0 END;
			SELF.diagnostics := diagnostics;
			current.document := NIL; current.section := NIL; current.paragraphs := NIL; current.text := NIL;
			document := NIL;
		END Init;

		(* helper procedures *)

		PROCEDURE Keyword(CONST a: ARRAY OF CHAR);
		VAR
			str: ARRAY 64 OF CHAR;
		BEGIN
			IF case= Scanner.Lowercase THEN Small(a,str) ELSE COPY(a,str) END;
			w.String(str);
			ToText(w,current.text,KeywordElementType);
		END Keyword;

		PROCEDURE Identifier*(x: SyntaxTree.Identifier);
		VAR str: Scanner.IdentifierString;
		BEGIN
			Basic.GetString(x,str); w.String(str);ToText(w,current.text,ElementType.Default)
		END Identifier;

		(** Procedure used to traverse qualified identifiers **)
		PROCEDURE QualifiedIdentifier*(x: SyntaxTree.QualifiedIdentifier);
		VAR str: Scanner.IdentifierString;
		BEGIN
			IF x.prefix # SyntaxTree.invalidIdentifier THEN Basic.GetString(x.prefix,str); w.String(str); w.String("."); END;
			Basic.GetString(x.suffix,str); w.String(str); ToText(w,current.text,QualifiedIdentifierElementType);
		END QualifiedIdentifier;

		(* types *)

		PROCEDURE Type*(x: SyntaxTree.Type);
		BEGIN
			IF x # NIL THEN x.Accept(SELF) END;
		END Type;

		PROCEDURE VisitType(x: SyntaxTree.Type);
		BEGIN
		END VisitType;

		PROCEDURE VisitBasicType(x: SyntaxTree.BasicType);
		BEGIN
			IF x.typeDeclaration # NIL THEN
				Identifier(x.typeDeclaration.name)
			ELSE
				Identifier(x.name)
			END
		END VisitBasicType;

		PROCEDURE VisitBooleanType(x: SyntaxTree.BooleanType);
		BEGIN VisitBasicType(x)
		END VisitBooleanType;

		PROCEDURE VisitSetType(x: SyntaxTree.SetType);
		BEGIN VisitBasicType(x)
		END VisitSetType;

		PROCEDURE VisitSizeType(x: SyntaxTree.SizeType);
		BEGIN VisitBasicType(x)
		END VisitSizeType;

		PROCEDURE VisitCharacterType(x: SyntaxTree.CharacterType);
		BEGIN VisitBasicType(x)
		END VisitCharacterType;

		PROCEDURE VisitIntegerType(x: SyntaxTree.IntegerType);
		BEGIN VisitBasicType(x)
		END VisitIntegerType;

		PROCEDURE VisitFloatType(x: SyntaxTree.FloatType);
		BEGIN VisitBasicType(x)
		END VisitFloatType;

		PROCEDURE VisitComplexType(x: SyntaxTree.ComplexType);
		BEGIN VisitBasicType(x)
		END VisitComplexType;

		PROCEDURE VisitByteType(x: SyntaxTree.ByteType);
		BEGIN VisitBasicType(x)
		END VisitByteType;

		PROCEDURE VisitQualifiedType(x: SyntaxTree.QualifiedType);
		BEGIN
			IF x.qualifiedIdentifier # NIL THEN
				QualifiedIdentifier(x.qualifiedIdentifier)
			END;
		END VisitQualifiedType;

		PROCEDURE VisitStringType(x: SyntaxTree.StringType);
		BEGIN
		END VisitStringType;

		PROCEDURE VisitEnumerationType(x: SyntaxTree.EnumerationType);
		VAR e: SyntaxTree.Constant; first: BOOLEAN;
		BEGIN
			Keyword("ENUMERATION"); Whitespace;

			IF x.enumerationBase # NIL THEN
				String("(");
				Type(x.enumerationBase);
				String(")");
			END;
			IF ~short THEN
				e := x.enumerationScope.firstConstant; first := TRUE;
				WHILE (e # NIL) DO
					IF ~first THEN String(","); Whitespace; ELSE first := FALSE END;
					VisitConstant(e);
					e := e.nextConstant;
				END;
			END;
		END VisitEnumerationType;

		PROCEDURE VisitRangeType(x: SyntaxTree.RangeType);
		BEGIN VisitBasicType(x);
		END VisitRangeType;

		PROCEDURE VisitArrayType(x: SyntaxTree.ArrayType);
		BEGIN
			Keyword("ARRAY"); Whitespace;
			IF x.length # NIL THEN Expression(x.length);ToText(w,current.text,ElementType.Default);Whitespace; END;
			Keyword("OF");Whitespace;
			Type(x.arrayBase);
		END VisitArrayType;

		PROCEDURE VisitNilType(x: SyntaxTree.NilType);
		BEGIN
			String("NILTYPE");
		END VisitNilType;

		PROCEDURE VisitAddressType(x: SyntaxTree.AddressType);
		BEGIN
			String("ADDRESSTYPE");
		END VisitAddressType;

		PROCEDURE VisitObjectType(x: SyntaxTree.ObjectType);
		BEGIN
			VisitBasicType(x);
		END VisitObjectType;

		PROCEDURE VisitAnyType(x: SyntaxTree.AnyType);
		BEGIN
			VisitBasicType(x);
		END VisitAnyType;

		PROCEDURE VisitMathArrayType(x: SyntaxTree.MathArrayType);
		BEGIN
			Keyword("ARRAY" );Whitespace;
			IF x.form = SyntaxTree.Tensor THEN String("[?]");
			ELSE
				String("[");
				IF x.length = NIL THEN
					String("*")
				ELSE
					Expression(x.length);
				END;
				WHILE(x.arrayBase # NIL) & (x.arrayBase IS SyntaxTree.MathArrayType) DO
					x := x.arrayBase(SyntaxTree.MathArrayType);
					String(",");
					IF x.length = NIL THEN
						String("*")
					ELSE
						Expression(x.length);
					END;
				END;
				String("]");Whitespace;
			END;
			IF x.arrayBase # NIL THEN
				Keyword("OF" );Whitespace;
				Type(x.arrayBase);
			END;
		END VisitMathArrayType;

		PROCEDURE VisitPointerType(x: SyntaxTree.PointerType);
		VAR pointerBase: SyntaxTree.Type;
		BEGIN
			IF x.pointerBase # NIL THEN
				pointerBase := x.pointerBase;
				IF (pointerBase IS SyntaxTree.RecordType) & (pointerBase(SyntaxTree.RecordType).isObject) THEN
					VisitRecordType(pointerBase(SyntaxTree.RecordType))
				ELSE
					Keyword("POINTER"); Whitespace; Keyword("TO" ); Whitespace;  Type(x.pointerBase)
				END;
			END;
		END VisitPointerType;

		PROCEDURE VisitPortType(x: SyntaxTree.PortType);
		BEGIN
			Keyword("PORT");Whitespace;
			IF x.direction = SyntaxTree.OutPort THEN
				Keyword("OUT")
			ELSE
				ASSERT(x.direction = SyntaxTree.InPort);
				Keyword("IN");
			END;
			Whitespace;
			IF x.sizeExpression # NIL THEN
				String("("); Expression(x.sizeExpression); String(")");
			END;
		END VisitPortType;

		PROCEDURE VisitCellType(x: SyntaxTree.CellType);
		BEGIN
			Keyword("CELL");Whitespace;
			Modifiers(x.modifiers);
			IF x.firstParameter # NIL THEN ParameterList(x.firstParameter) END;
			IF ~short THEN
				Summary(current.paragraphs, x.cellScope);
				Scope(x.cellScope);
			END;
		END VisitCellType;

		PROCEDURE VisitRecordType(x: SyntaxTree.RecordType);
		VAR prevScope: SyntaxTree.Scope; first: BOOLEAN; variable: SyntaxTree.Variable;
		BEGIN
			IF x.isObject THEN
				Keyword("OBJECT");Whitespace;
				IF x.pointerType # NIL THEN  END;
				IF (x.baseType # NIL)  THEN
					String( "(" );
					IF (x.baseType IS SyntaxTree.RecordType) & (x.baseType(SyntaxTree.RecordType).pointerType # NIL) THEN
						Type(x.baseType(SyntaxTree.RecordType).pointerType)
					ELSE
						Type(x.baseType);
					END;
					String( ")" );
				END;
				IF ~short THEN
					Summary(current.paragraphs, x.recordScope);
					Scope(x.recordScope);
				END;
			ELSE
				Keyword("RECORD");Whitespace;
				IF (x.baseType # NIL) THEN
					String( "(" );
					IF (x.baseType IS SyntaxTree.RecordType) & (x.baseType(SyntaxTree.RecordType).pointerType # NIL) THEN
						Type(x.baseType(SyntaxTree.RecordType).pointerType)
					ELSE
						Type(x.baseType);
					END;
					String( ")" );
				END;
				IF ~short THEN
					Summary(current.paragraphs, x.recordScope);
					Scope(x.recordScope);
				END;
			END;
		END VisitRecordType;

		PROCEDURE VisitProcedureType(x: SyntaxTree.ProcedureType);
		VAR first: BOOLEAN;
		BEGIN
			Keyword("PROCEDURE" );
			first := TRUE;
			IF x.isDelegate THEN Flag(Global.NameDelegate,first) END;
			IF x.isInterrupt THEN Flag(Global.NameInterrupt,first) END;
			IF x.noPAF THEN Flag(Global.NameNoPAF,first) END;
			IF x.callingConvention = SyntaxTree.WinAPICallingConvention THEN
				Flag(Global.NameWinAPI,first)
			ELSIF x.callingConvention = SyntaxTree.CCallingConvention THEN
				Flag(Global.NameC,first)
			END;
			IF x.stackAlignment > 1 THEN Value(Global.NameStackAligned,x.stackAlignment,first) END;
			IF ~first THEN String("}") END;
			Whitespace;
			IF (x.firstParameter # NIL) OR (x.returnType # NIL) THEN
				ParameterList(x.firstParameter)
			END;
			IF x.returnType # NIL THEN String( ":" );  Whitespace; Type(x.returnType) END;
		END VisitProcedureType;

		(* expressions *)

		PROCEDURE ExpressionList(x: SyntaxTree.ExpressionList);
		VAR i: LONGINT;  expression: SyntaxTree.Expression;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				expression := x.GetExpression( i );  Expression(expression);
				IF i < x.Length() - 1 THEN String( "," );  END;
			END;
		END ExpressionList;

		PROCEDURE Expression*(x: SyntaxTree.Expression);
		BEGIN
			IF x # NIL THEN
				x.Accept(SELF);
			END;
			w.Update;
		END Expression;

		PROCEDURE VisitExpression(x: SyntaxTree.Expression);
		BEGIN
		END VisitExpression;

		PROCEDURE VisitSet(x: SyntaxTree.Set);
		BEGIN
			String( "{" );  ExpressionList(x.elements); String( "}" );
		END VisitSet;

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		BEGIN
			String( "[" );  ExpressionList(x.elements); String( "]" );
		END VisitMathArrayExpression;

		PROCEDURE VisitUnaryExpression(x: SyntaxTree.UnaryExpression);
		VAR identifier: SyntaxTree.Identifier;
		BEGIN
			IF x.operator = Scanner.Transpose THEN
				identifier := Global.GetIdentifier(x.operator,case);
				Expression(x.left);
				Identifier(identifier);
			ELSE
				identifier := Global.GetIdentifier(x.operator,case);
				Identifier(identifier);
				Expression(x.left);
			END;
		END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression(x: SyntaxTree.BinaryExpression);
		VAR identifier: SyntaxTree.Identifier;
		BEGIN
			String( "(" );
			Expression(x.left);
			identifier := Global.GetIdentifier(x.operator,case);
			Identifier(identifier);
			Expression(x.right);
			String(")");
		END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression(x: SyntaxTree.RangeExpression);
		BEGIN
			IF x.missingFirst & x.missingLast & x.missingStep THEN
				String("*")
			ELSE
				IF ~x.missingFirst THEN Expression(x.first) END;
				String("..");
				IF ~x.missingLast THEN Expression(x.last) END;
				IF ~x.missingStep THEN
					Keyword("BY");
					Expression(x.step)
				END
			END;
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression(x: SyntaxTree.TensorRangeExpression);
		BEGIN String("?");
		END VisitTensorRangeExpression;

		PROCEDURE VisitConversion(x: SyntaxTree.Conversion);
		BEGIN
			IF x.typeExpression # NIL THEN Expression(x.typeExpression); String("(");
			END;
			Expression(x.expression);
			IF x.typeExpression # NIL THEN String(")") END;
		END VisitConversion;

		PROCEDURE VisitSymbolDesignator(x: SyntaxTree.SymbolDesignator);
		BEGIN
			IF x.left # NIL THEN
			Expression(x.left); String(".");
			END;
			IF x.symbol IS SyntaxTree.Operator THEN
				String('"'); Identifier(x.symbol.name); String('"');
			ELSE
				Identifier(x.symbol.name)
			END;
		END VisitSymbolDesignator;

		PROCEDURE VisitBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator);
		BEGIN
			IF x.left # NIL THEN
				Expression(x.left);
			ELSE
				String("BUILTIN(");
				w.Int(x.id,1);
				String(")");
			END;
			String("("); ExpressionList(x.parameters); String(")");
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitValue(x: SyntaxTree.Value);
		BEGIN
		END VisitValue;

		PROCEDURE VisitBooleanValue(x: SyntaxTree.BooleanValue);
		BEGIN
			IF Scanner.Uppercase = case THEN
				IF x.value THEN String("TRUE" ) ELSE String( "FALSE" ) END
			ELSE
				IF x.value THEN String("true" ) ELSE String( "false" ) END
			END
		END VisitBooleanValue;

		PROCEDURE VisitIntegerValue(x: SyntaxTree.IntegerValue);

			PROCEDURE InBounds(val: HUGEINT; bits: LONGINT): BOOLEAN;
			VAR m: HUGEINT;
			BEGIN
				m := Runtime.AslH(1,bits-1);
				RETURN (val < m) & (-val <= m)
			END InBounds;
		BEGIN
			(*! use subtype for representation form ?  *)
			IF x.hvalue = MIN(HUGEINT) THEN
				(* special case: display 8000000000000000H without leading minus sign
					to avoid double minus sign for unary expression -8000000000000000H
				*)
				w.Char("0"); w.Hex(x.hvalue,-16); w.Char("H");
			ELSIF InBounds(x.hvalue,32) THEN
				Int(SHORT(x.hvalue));
			ELSE
				Hex(w,x.hvalue); w.Char("H");
			END;
			ToText(w,current.text,ElementType.Default);
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue(x: SyntaxTree.CharacterValue);
		BEGIN
			Hex(w, ORD(x.value));  w.String( "X" );
			ToText(w,current.text,ElementType.Default);
		END VisitCharacterValue;

		PROCEDURE VisitSetValue(x: SyntaxTree.SetValue);
		VAR i: LONGINT;
		BEGIN
			w.String("{");
			i := 0;
			WHILE (i<MAX(SET)) & ~(i IN x.value)  DO
				INC(i);
			END;
			IF i<MAX(SET) THEN
				w.Int(i,1);
				INC(i);
				WHILE i < MAX(SET) DO
					IF i IN x.value THEN w.String(","); w.Int(i,1); END;
					INC(i)
				END
			END;
			w.String("}");
			ToText(w,current.text,ElementType.Default);
		END VisitSetValue;

		PROCEDURE VisitMathArrayValue(x: SyntaxTree.MathArrayValue);
		BEGIN
			VisitMathArrayExpression(x.array);
		END VisitMathArrayValue;

		PROCEDURE FormatedFloat(value: LONGREAL; subtype: LONGINT);
		VAR string: ARRAY 128 OF CHAR; i: LONGINT;
		BEGIN
			IF subtype = Scanner.Real THEN
				ws.SetPos(0); ws.Float(value,11(*mantissa X.XXXXXXX *)+5(*exponent E+XXX *)); ws.Get(string);
				i := 0;
				WHILE(i<LEN(string)) & (string[i] # 0X) DO
					IF string[i] = "D" THEN string[i] := "E" END;
					INC(i);
				END;
				String(string);
			ELSIF subtype = Scanner.Longreal THEN
				ws.SetPos(0); ws.Float(value,20(*mantissa X.X..(16)..X *)+5(*exponent E+XXX *) ); ws.Get(string);
				i := 0;
				WHILE(i<LEN(string)) & (string[i] # 0X) DO
					IF string[i] = "E" THEN string[i] := "D" END;
					INC(i);
				END;
				String(string);
			ELSE
				w.Float(value,64);
				ToText(w,current.text,ElementType.Default);
			END;
		END FormatedFloat;

		PROCEDURE VisitRealValue(x: SyntaxTree.RealValue);
		BEGIN FormatedFloat(x.value, x.subtype)
		END VisitRealValue;

		PROCEDURE VisitComplexValue(x: SyntaxTree.ComplexValue);
		BEGIN
			IF (x.realValue = 0) & (x.imagValue = 1) THEN
				String("IMAG")
			ELSE
				String("(");
				FormatedFloat(x.realValue, x.subtype)	;
				IF x.imagValue > 0 THEN String("+") END;
				FormatedFloat(x.imagValue, x.subtype);
				String("*IMAG)")
			END
		END VisitComplexValue;

		PROCEDURE VisitStringValue(x: SyntaxTree.StringValue);
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < LEN( x.value )) & (x.value[i] # 0X) & (x.value[i] # '"') DO INC( i );  END;
			ASSERT(i # LEN(x.value));
			IF  (x.value[i] = 0X) THEN (* no double quotes contained in the string *)
				w.String( '"' );  w.String( x.value^ );  w.String( '"' );
			ELSE  (* double quotes found in string *)
				w.String( "'" );  w.String( x.value^ );  w.String( "'" );
			END;
			ToText(w,current.text,ElementType.Default);
		END VisitStringValue;

		PROCEDURE VisitNilValue(x: SyntaxTree.NilValue);
		BEGIN String( "NIL" );
		END VisitNilValue;

		PROCEDURE VisitEnumerationValue(x: SyntaxTree.EnumerationValue);
		BEGIN w.Int(x.value,1); ToText(w,current.text,ElementType.Default);
		END VisitEnumerationValue;

		(**** symbols ****)

		PROCEDURE VisitParameter(x: SyntaxTree.Parameter);
		END VisitParameter;

		PROCEDURE PrintSymbol(x: SyntaxTree.Symbol);
		VAR first: BOOLEAN; w: Streams.StringWriter; name: Scanner.IdentifierString;
		BEGIN
			NEW(w,256);

			Basic.GetString(x.name,name);
			IF x IS SyntaxTree.Operator THEN
				w.String('"'); w.String(name); w.String('"')
			ELSE
				w.String(name)
			END;
			IF SyntaxTree.PublicWrite IN x.access THEN w.String( "*" )
			ELSIF SyntaxTree.PublicRead IN x.access THEN
				IF x IS SyntaxTree.Variable THEN
					w.String( "-" )
				ELSIF ~(x IS SyntaxTree.Parameter) THEN
					w.String("*")
				END
			END;
			ToText(w, current.text,ElementType.Default);
		END PrintSymbol;

		PROCEDURE ParameterList*(x: SyntaxTree.Parameter);
		VAR next: SyntaxTree.Parameter; first: BOOLEAN;
		BEGIN
			first := TRUE;
			String( "(" );
			WHILE(x # NIL) DO
				next := x.nextParameter;
				IF (x.access # SyntaxTree.Hidden) THEN
					IF ~first THEN String(";"); Whitespace END;
					first := FALSE;
					IF x.kind = SyntaxTree.VarParameter THEN Keyword("VAR" );Whitespace;
					ELSIF x.kind = SyntaxTree.ConstParameter THEN Keyword("CONST" );Whitespace;
					END;
					PrintSymbol(x);
					IF x.defaultValue # NIL THEN
						String("="); Whitespace; Expression(x.defaultValue);
					END;

					WHILE (next # NIL) & (next.type = x.type) & (next.kind = x.kind) & ((next.access # SyntaxTree.Hidden) ) DO
						String(",");Whitespace;
						PrintSymbol(next);
						IF next.defaultValue # NIL THEN
							String("="); Whitespace; Expression(next.defaultValue);
						END;
						next := next.nextParameter;
					END;
					IF x.access # SyntaxTree.Hidden THEN
						String(":");Whitespace;
						Type(x.type);
					ELSE
						String(":");Whitespace;
						Type(x.type);
					END;
				END;
				x := next;
			END;
			String( ")" );
		END ParameterList;

		PROCEDURE Visible(symbol: SyntaxTree.Symbol): BOOLEAN;
		BEGIN
			RETURN (symbol # NIL) & ( (SyntaxTree.Public * symbol.access # {}) OR backend.internals)
		END Visible;

		PROCEDURE Symbol*(x: SyntaxTree.Symbol);
		BEGIN
			IF Visible(x) THEN x.Accept(SELF) END
		END Symbol;

		PROCEDURE NeedsSection(x: SyntaxTree.Symbol): BOOLEAN;
		VAR declaredType: SyntaxTree.Type;tmp: SyntaxTree.Comment;
		BEGIN
			IF x.comment # NIL THEN
				tmp := x.comment;
				WHILE (tmp # NIL) & (tmp.item = x) DO
					IF tmp.source[0] = "*" THEN RETURN TRUE END;
					tmp := tmp.nextComment
				END;
			END;
			IF x IS SyntaxTree.TypeDeclaration THEN
				declaredType := x(SyntaxTree.TypeDeclaration).declaredType.resolved;
				IF declaredType IS SyntaxTree.PointerType THEN declaredType := declaredType(SyntaxTree.PointerType).pointerBase.resolved END;
				RETURN (declaredType IS SyntaxTree.RecordType) OR (declaredType IS SyntaxTree.EnumerationType)
			END;
			RETURN FALSE
		END NeedsSection;


		PROCEDURE ExtractParameters(x: SyntaxTree.ProcedureType; doc: DocumentationTree.Document; VAR parameters: DocumentationTree.Document);
		VAR par: SyntaxTree.Parameter; paragraph,heading: DocumentationTree.Paragraph; i: LONGINT; element: DocumentationTree.TextElement;
			string: DocumentationTree.String; id: SyntaxTree.Identifier; done: BOOLEAN;
		BEGIN
			i := 0;
			WHILE i < doc.description.Length() DO
				paragraph := doc.description.GetParagraph(i);
				done := FALSE;
				IF (paragraph.type = ParagraphType.Description) & (paragraph.description.Length() = 1) THEN
					element := paragraph.description.GetElement(0);
					string := element.string;
					id := SyntaxTree.NewIdentifier(string^);
					par := x.firstParameter;
					WHILE (par # NIL) & ~done DO
						IF par.name = id THEN
							done := TRUE;
							doc.description.RemoveByIndex(i);
							IF parameters = NIL THEN
								NEW(parameters);
							END;
							parameters.description.Add(paragraph);
						END;
						par := par.nextParameter;
					END;

					IF ~done & ((string^="RESULT") OR (string^="result")) THEN
						doc.description.RemoveByIndex(i);
						IF parameters = NIL THEN
							NEW(parameters);
						END;
						parameters.description.Add(paragraph);
						done := TRUE;
					END;

				END;
				IF ~done THEN INC(i) END;
			END;
		END ExtractParameters;


		PROCEDURE WriteSymbolSection(x: SyntaxTree.Symbol);
		VAR section: DocumentationTree.Section; paragraph: DocumentationTree.Paragraph; commentDoc: DocumentationTree.Document;
			parameters: DocumentationTree.Document;
		BEGIN
			IF Visible(x) & NeedsSection(x) THEN
				section := BeginSymbolSection("",x);

				parameterDocument := NIL;


				IF x.comment # NIL THEN
					commentDoc := DocumentationTree.NewDocument();
					ParseComments(commentDoc,x.comment, NIL,x);
					PatchLinks(commentDoc, x.scope);
					KeepSections(commentDoc);
					IF (x IS SyntaxTree.Procedure) THEN
						ExtractParameters(x.type(SyntaxTree.ProcedureType), commentDoc, parameters);
					END;
					MergeDocument(current.document, section.contents, commentDoc);
				END;

				paragraph := section.contents.AppendNew(ParagraphType.Heading);
				paragraph.SetLevel(2);
				paragraph.text.WriteString("Syntax");

				paragraph := section.contents.AppendNew(ParagraphType.Code);
				current.text := paragraph.text;
				Symbol(x);

				IF parameters # NIL THEN
					paragraph := section.contents.AppendNew(ParagraphType.Heading);
					paragraph.SetLevel(2);
					paragraph.text.WriteString("Parameters");
					MergeDocument(current.document, section.contents, parameters);
				END;

				EndSection(section);
			END;
		END WriteSymbolSection;

		PROCEDURE BeginSymbolSection(CONST title: ARRAY OF CHAR; x: SyntaxTree.Symbol):DocumentationTree.Section;
		VAR section: DocumentationTree.Section; name: Basic.SectionName; paragraph:DocumentationTree.Paragraph;
		BEGIN
			section := BeginSection(current.document);
			current.section := section;
			current.paragraphs := section.contents;
			WriteSymbolLabel(section.title, x);
			(*
			Global.GetSymbolNameInScope(x,(* current.scope*) NIL ,name);
			*)
			WriteReferenceInScope(section.title, x, NIL);
			(*
			section.title.WriteString(name); (* WriteString(section.title,title);*)
			*)
			(*
			section := current.section;
			current.paragraphs := section.contents;
			paragraph := section.contents.AppendNew(ParagraphType.Line);
			paragraph := section.contents.AppendNew(ParagraphType.Heading);
			paragraph.SetLevel(1);
			WriteSymbolLabel(paragraph.text, x);
			Global.GetSymbolNameInScope(x,(* current.scope*) NIL ,name);
			WriteString(paragraph.text, name); (* WriteString(section.title,title);*)
			*)
			RETURN section;
		END BeginSymbolSection;

		PROCEDURE VisitSymbol(x: SyntaxTree.Symbol);
		BEGIN
		END VisitSymbol;

		PROCEDURE VisitTypeDeclaration(x: SyntaxTree.TypeDeclaration);
		VAR section: DocumentationTree.Section; paragraph: DocumentationTree.Paragraph;commentDoc: DocumentationTree.Document;
		BEGIN
			IF ~short THEN
				Keyword("TYPE"); Whitespace;
				PrintSymbol(x);
			ELSE
				WriteSymbolReference(current.text, x, current.scope);
			END;
			Whitespace;
			String("="); Type(x.declaredType);
		END VisitTypeDeclaration;

		PROCEDURE VisitConstant(x: SyntaxTree.Constant);
		VAR section: DocumentationTree.Section;paragraph: DocumentationTree.Paragraph; commentDoc: DocumentationTree.Document;
		BEGIN
			IF ~short THEN
				Keyword("CONST"); Whitespace; PrintSymbol(x)
			ELSE
				WriteSymbolReference(current.text, x, current.scope);
			END;
			IF x.value # NIL THEN
				String( "=" );  Whitespace; Expression(x.value);
			END;
		END VisitConstant;

		PROCEDURE VisitVariable(x: SyntaxTree.Variable);
		VAR section: DocumentationTree.Section; paragraph: DocumentationTree.Paragraph;commentDoc: DocumentationTree.Document;
		BEGIN
			IF ~short THEN
				Keyword("VAR"); Whitespace; PrintSymbol(x)
			ELSE
				WriteSymbolReference(current.text, x, current.scope);
			END;
			String( ":" );Whitespace;
			Type(x.type);
		END VisitVariable;

		PROCEDURE Flag(identifier: SyntaxTree.Identifier; VAR first: BOOLEAN);
		VAR name: SyntaxTree.IdentifierString;
		BEGIN
			IF first THEN String("{") ELSE String(",") END;
			first := FALSE;
			Basic.GetString(identifier,name);
			String(name);
		END Flag;

		PROCEDURE FlagEnd(first: BOOLEAN);
		BEGIN
			IF ~first THEN String("}") END;
		END FlagEnd;

		PROCEDURE Int(value: LONGINT);
		VAR s: DocumentationTree.String; textElement: DocumentationTree.TextElement;
		BEGIN
			NEW(s,32); Strings.IntToStr(value,s^);
			textElement := current.text.AppendNew(ElementType.Default);
			textElement.SetString(s);
		END Int;

		PROCEDURE Value(identifier: SyntaxTree.Identifier; value: LONGINT; VAR first: BOOLEAN);
		BEGIN
			Flag(identifier,first);
			w.String("("); w.Int(value,1); w.String(")");ToText(w,current.text,ElementType.Default);
		END Value;

		(** process procedure including comments describing the procedure *)
		PROCEDURE VisitProcedure(x: SyntaxTree.Procedure);
		VAR section: DocumentationTree.Section; paragraph: DocumentationTree.Paragraph; name: Basic.SectionName; first: BOOLEAN; type: SyntaxTree.ProcedureType;
		doc: DocumentationTree.Document; par: SyntaxTree.Parameter;
		BEGIN
			IF ~short  THEN
				IF x IS SyntaxTree.Operator THEN
					Keyword("OPERATOR")
				ELSE
					Keyword("PROCEDURE")
				END;
			END;

			IF x.isInline THEN String("-") END;
			IF x.isConstructor THEN String("&") END;
			Whitespace;

			type := x.type(SyntaxTree.ProcedureType);
			first := TRUE;
			IF type.stackAlignment > 1 THEN Value(Global.NameStackAligned,type.stackAlignment,first) END;
			IF (type.isRealtime) THEN Flag(Global.NameRealtime,first) END;
			IF (x.fixed) THEN Value(Global.NameFixed, x.alignment,first)
			ELSIF (x.alignment >1) THEN Value(Global.NameAligned, x.alignment, first)
			END;
			FlagEnd(first);

			IF ~short THEN
				PrintSymbol(x)
			ELSE
				WriteSymbolReference(current.text, x, current.scope);
			END;

			IF (type.firstParameter # NIL)  OR (type.returnType # NIL ) THEN  (* print parentheses only if not parameterless procedure *)
				Whitespace;
				ParameterList(type.firstParameter);
			END;
			IF type.returnType # NIL THEN
				String( ":" );
				Whitespace;
				Type(type.returnType);
			END;
		END VisitProcedure;

		PROCEDURE String(CONST name: ARRAY OF CHAR);
		BEGIN current.text.WriteString(name);
		END String;

		PROCEDURE Whitespace;
		BEGIN
			current.text.WriteWhitespace
		END Whitespace;


		PROCEDURE VisitOperator(x: SyntaxTree.Operator);
		BEGIN VisitProcedure(x);
		END VisitOperator;

		PROCEDURE VisitImport(x: SyntaxTree.Import);
		VAR context: SyntaxTree.Identifier; name: Basic.SectionName; 
		BEGIN
			x.GetName(name);
			current.text.WriteLabel(name);
			IF x.moduleName # x.name THEN PrintSymbol(x); String( " := " );  END;
			IF (x.scope = NIL) OR (x.scope.ownerModule = NIL) THEN context := SyntaxTree.invalidIdentifier ELSE context := x.scope.ownerModule.context END;
			WriteReferenceInScope(current.text, x.module, NIL);
			IF (x.context # SyntaxTree.invalidIdentifier) & (x.context#context) THEN
				String(" IN ");
				Identifier(x.context)
			END;
		END VisitImport;

		PROCEDURE VisitBuiltin(x: SyntaxTree.Builtin);
		BEGIN
		END VisitBuiltin;

		(*** scopes ****)

		PROCEDURE Scope*(x: SyntaxTree.Scope);
		VAR
			constant: SyntaxTree.Constant;
			type: SyntaxTree.TypeDeclaration;
			variable : SyntaxTree.Variable;
			procedure: SyntaxTree.Procedure;
			prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := current.scope;
			current.scope := x;

			constant := x.firstConstant;
			WHILE constant # NIL DO WriteSymbolSection(constant); constant := constant.nextConstant; END;

			type := x.firstTypeDeclaration;
			WHILE type # NIL DO WriteSymbolSection(type); type := type.nextTypeDeclaration END;

			variable := x.firstVariable;
			WHILE variable # NIL DO WriteSymbolSection(variable); variable := variable.nextVariable END;

			procedure := x.firstProcedure;
			WHILE procedure # NIL DO WriteSymbolSection(procedure); procedure := procedure.nextProcedure END;

			current.scope := prevScope;
		END Scope;
		PROCEDURE SymbolRow(CONST head: ARRAY OF CHAR; symbol: SyntaxTree.Symbol; VAR first: BOOLEAN);
		VAR row, cell: DocumentationTree.TextElement; x: SyntaxTree.Constant;
		BEGIN
			IF Visible(symbol) THEN
				row := current.text.AppendNew(ElementType.Row);
				IF first THEN
					first := FALSE;
					cell := row.text.AppendNew(ElementType.HeaderCell);
					cell.text.WriteString(head);
				ELSE
					cell := row.text.AppendNew(ElementType.DataCell);
				END;
				cell := row.text.AppendNew(ElementType.DataCell);
				current.text := cell.text;
				Symbol(symbol);
			END;
		END SymbolRow;

		PROCEDURE Summary(paragraphs: DocumentationTree.Paragraphs; x: SyntaxTree.Scope);
		VAR
			import: SyntaxTree.Import;
			constant: SyntaxTree.Constant;
			type: SyntaxTree.TypeDeclaration;
			variable : SyntaxTree.Variable;
			procedure: SyntaxTree.Procedure;
			first: BOOLEAN;
			prevScope: SyntaxTree.Scope;

			paragraph: DocumentationTree.Paragraph;


		BEGIN
			prevScope := current.scope;
			current.scope := x;

			paragraph := paragraphs.AppendNew(ParagraphType.Heading);	paragraph.SetLevel(2); paragraph.text.WriteString("Summary");

			paragraph := paragraphs.AppendNew(ParagraphType.Table);
			current.text := paragraph.text;


			short := TRUE;

			IF x IS SyntaxTree.ModuleScope THEN
				import := x(SyntaxTree.ModuleScope).firstImport; first := TRUE;
				WHILE import # NIL DO SymbolRow("imports",import,first); import := import.nextImport; END;
			END;

			constant := x.firstConstant; first := TRUE;
			WHILE constant # NIL DO SymbolRow("constants",constant,first); constant := constant.nextConstant; END;

			type := x.firstTypeDeclaration; first := TRUE;
			WHILE type # NIL DO SymbolRow("type declarations", type,first); type := type.nextTypeDeclaration END;

			variable := x.firstVariable; first := TRUE;
			WHILE variable # NIL DO SymbolRow("variables", variable,first); variable := variable.nextVariable END;

			procedure := x.firstProcedure; first := TRUE;
			WHILE procedure # NIL DO SymbolRow("procedures", procedure,first); procedure := procedure.nextProcedure END;

			current.scope := prevScope;
			short := FALSE;

			(*
			paragraph := paragraphs.AppendNew(ParagraphType.TextBlock);
			paragraph.text.WriteLink("ModuleList","List of modules");
			*)
		END Summary;

		PROCEDURE WriteTextElement(textElement: DocumentationTree.TextElement);
		VAR paragraph: DocumentationTree.Paragraph; element: DocumentationTree.TextElement;
		BEGIN
			ASSERT(current.text # NIL);
			CASE textElement.type OF
			ElementType.Italic, ElementType.Bold, ElementType.Underline, ElementType.Code: current.text.Add(textElement);
				current.text := textElement.text;
			| ElementType.HeaderCell, ElementType.DataCell, ElementType.Row:
				ASSERT(current.paragraphs # NIL);
				ASSERT(current.paragraphs.Length() # 0);
				paragraph := current.paragraphs.Last();
				current.text := paragraph.text;
				IF textElement.type # ElementType.Row THEN
					ASSERT(current.text.Length() # 0);
					element := current.text.Last();
					current.text := element.text
				END;
				current.text.Add(textElement);
				current.text := textElement.text;
			ELSE
				current.text.Add(textElement)
			END;
		END WriteTextElement;

		PROCEDURE BeginSection(document: DocumentationTree.Document): DocumentationTree.Section;
		VAR section: DocumentationTree.Section;
		BEGIN
			INC(level[Section]);
			section := document.sections.AppendNew(level[Section]);
			RETURN section;
		END BeginSection;

		PROCEDURE PrefixSection(document: DocumentationTree.Document): DocumentationTree.Section;
		VAR section: DocumentationTree.Section;
		BEGIN
			INC(level[Section]);
			NEW(section, level[Section]);
			document.sections.Insert(0, section);
			RETURN section;
		END PrefixSection;

		PROCEDURE EndSection(section: DocumentationTree.Section);
		BEGIN
			DEC(level[Section]);
		END EndSection;

		PROCEDURE PatchLinkE(element: DocumentationTree.TextElement);
		VAR label: Strings.String; symbol: SyntaxTree.Symbol;name: Basic.SectionName; identifier: SyntaxTree.Identifier;
		BEGIN
			IF (element.type = ElementType.Link) & (element.string # NIL) THEN
				identifier := SyntaxTree.NewIdentifier(element.string^);
				symbol := current.scope.FindSymbol(identifier);
				IF (symbol # NIL) & ~(symbol IS SyntaxTree.Import) THEN
					IF element.text.Length()= 0 THEN element.text.WriteString(element.string^) END;
					Global.GetSymbolNameInScope(symbol, NIL, name);
					element.SetString(Strings.NewString(name));
				END;
			END;
			element.text.ForAllElementsDo(PatchLinkE)
		END PatchLinkE;

		PROCEDURE PatchLinksP(par: DocumentationTree.Paragraph);
		BEGIN
			par.text.ForAllElementsDo(PatchLinkE)
		END PatchLinksP;

		PROCEDURE PatchLinksS(sec: DocumentationTree.Section);
		VAR i: LONGINT;
		BEGIN
			sec.title.ForAllElementsDo(PatchLinkE);
			sec.contents.ForAllParagraphsDo(PatchLinksP)
		END PatchLinksS;

		PROCEDURE PatchLinks(doc: DocumentationTree.Document; scope: SyntaxTree.Scope);
		VAR i: LONGINT; prev: SyntaxTree.Scope;
		BEGIN
			prev := current.scope;
			current.scope := scope;
			doc.sections.ForAllSectionsDo(PatchLinksS);
			doc.description.ForAllParagraphsDo(PatchLinksP);
			current.scope := prev
		END PatchLinks;
		
		PROCEDURE Modifiers(x: SyntaxTree.Modifier);
		VAR name: Scanner.IdentifierString; first: BOOLEAN;
		BEGIN
			first := TRUE;
			WHILE x # NIL DO
				IF first THEN String("{"); first := FALSE ELSE String(", ") END;
				Basic.GetString(x.identifier,name);
				String(name);
				IF x.expression # NIL THEN
					String("(");
					Expression(x.expression);
					String(")");
				END;
				x := x.nextModifier;
			END;
			IF ~first THEN String("} ") END;
		END Modifiers;

		PROCEDURE Module*(x: SyntaxTree.Module; backend: DocumentationBackend): DocumentationTree.Document;
		VAR
			name: SyntaxTree.IdentifierString; section, cs: DocumentationTree.Section; commentDoc: DocumentationTree.Document;
			doc: DocumentationTree.Document; par: DocumentationTree.Paragraph; text: DocumentationTree.Text;
		BEGIN
			SELF.backend := backend;
			ASSERT(x # NIL);
			doc := DocumentationTree.NewDocument();
			level[Section] := 0;

			Global.GetModuleName(x,name);

			section := BeginSection(doc);
			section.WriteLabel("ModuleList");
			par := section.contents.AppendNew(ParagraphType.TextBlock);
			par.text.WriteString("Module");
			par.text.WriteWhitespace;
			par.text.WriteLink(name, name);

			EndSection(section);

			section := BeginSection(doc);
			section.title.WriteLabel(name);
			section.title.WriteWeakLink("ModuleList","Module"); (* if there is a module list, then e refer to it here *)
			section.title.WriteWhitespace;
			section.title.WriteString(name);

			IF x.comment # NIL THEN
				commentDoc := DocumentationTree.NewDocument();
				ParseComments(commentDoc,x.comment, x.closingComment,x);
				PatchLinks(commentDoc, x.moduleScope);
				MergeDocument(doc, section.contents, commentDoc);
			END;

			Summary(section.contents, x.moduleScope);

			EndSection(section);

			IF x.closingComment # NIL THEN
				cs := BeginSection(doc);
				commentDoc := DocumentationTree.NewDocument();
				ParseComments(commentDoc,x.closingComment, NIL,x);
				PatchLinks(commentDoc, x.moduleScope);
				MergeDocument(doc, cs.contents, commentDoc);
				EndSection(cs);
			END;

			current.document := doc;

			INC(level[Section]);

			Scope(x.moduleScope);

			DEC(level[Section]);

			current.scope := x.moduleScope;

			MergeDocument(doc, doc.description, document);
			document := doc;
			RETURN document
		END Module;

	END Generator;

	Checker= OBJECT
	VAR
		labels: DocumentationTree.Text;
		links: DocumentationTree.Text;
		currentScope: SyntaxTree.Scope;

		PROCEDURE CheckElement(element: DocumentationTree.TextElement);
		VAR label: Strings.String; symbol: SyntaxTree.Symbol;name: Basic.SectionName; identifier: SyntaxTree.Identifier;
		BEGIN
			IF (element.type = ElementType.Link) & (element.string # NIL) THEN
				identifier := SyntaxTree.NewIdentifier(element.string^);
				symbol := currentScope.FindSymbol(identifier);
				IF symbol # NIL THEN
					Global.GetSymbolNameInScope(symbol, NIL, name);
					element.SetString(Strings.NewString(name));
				END;
			ELSIF (element.type = ElementType.WeakLink) THEN
				IF labels.FindByString(element.string^) = NIL THEN
					element.SetType(ElementType.Default)
				ELSE
					element.SetType(ElementType.Link)
				END;
			END;
		END CheckElement;

		PROCEDURE CollectElement(element: DocumentationTree.TextElement);
		BEGIN
			IF (element.type = ElementType.WeakLink) THEN
				links.AddElement(element);
			ELSIF (element.type = ElementType.Label) THEN
				labels.Add(element)
			END;
			element.text.ForAllElementsDo(CollectElement);
		END CollectElement;

		PROCEDURE CollectParagraph(par: DocumentationTree.Paragraph);
		BEGIN
			IF par.label # NIL THEN
				labels.WriteLabel(par.label^)
			END;
			par.text.ForAllElementsDo(CollectElement);
			par.description.ForAllElementsDo(CollectElement);
		END CollectParagraph;

		PROCEDURE CollectSection(sec: DocumentationTree.Section);
		BEGIN
			IF sec.label # NIL THEN
				labels.WriteLabel(sec.label^)
			END;
			sec.title.ForAllElementsDo(CollectElement);
			sec.contents.ForAllParagraphsDo(CollectParagraph);
		END CollectSection;

		PROCEDURE Document(doc: DocumentationTree.Document; scope: SyntaxTree.Scope);
		BEGIN
			currentScope := scope;
			NEW(links, 4); NEW(labels, 4);
			doc.description.ForAllParagraphsDo(CollectParagraph);
			doc.sections.ForAllSectionsDo(CollectSection);
			links.ForAllElementsDo(CheckElement)
		END Document;

	END Checker;

	DocumentationBackend= OBJECT (Backend.Backend)
	VAR
		trace: BOOLEAN;
		fileName : Files.FileName;
		generator: Generator;
		templateFile: Files.FileName;
		internals: BOOLEAN;

		PROCEDURE &InitIntermediateBackend*;
		BEGIN
			InitBackend; generator := NIL;
		END InitIntermediateBackend;

		PROCEDURE ParseFile(fileName: ARRAY OF CHAR): DocumentationTree.Document;
		VAR reader: Files.Reader; parser: DocumentationParser.Parser; scanner: DocumentationScanner.Scanner;
			printer: DocumentationPrinter.Printer; document: DocumentationTree.Document;
			file: Files.File;
		BEGIN
			file := Files.Old(fileName);
			IF file = NIL THEN RETURN NIL END;
			NEW(reader, file, 0);
			NEW(scanner, reader,0,NIL);
			NEW(parser, scanner);
			document := DocumentationTree.NewDocument();
			parser.ParseDocument(document);
			
			RETURN document
		END ParseFile;

		PROCEDURE ProcessSyntaxTreeModule(syntaxTreeModule: SyntaxTree.Module): Formats.GeneratedModule;
		VAR dump: Streams.Writer;  printer: DocumentationPrinter.Printer; document, template: DocumentationTree.Document;
			htmlPrinter: DocumentationHtml.Printer; file: Files.File; writer: Files.Writer;

			name, extension: Files.FileName; checker: Checker;
		BEGIN
			Files.SplitExtension(fileName, name, extension);

			IF (name = "*") OR (generator = NIL) THEN
				NEW(generator,diagnostics);
				generator.case := syntaxTreeModule.case;
			END;
			document := generator.Module(syntaxTreeModule,SELF);
			IF templateFile # "" THEN
				template := ParseFile(templateFile);
				IF template # NIL THEN
					MergeDocument(template, NIL, document);
					document := template;
				ELSIF diagnostics # NIL THEN
					diagnostics.Error("",Diagnostics.Invalid, Diagnostics.Invalid,"could not  open / parse documentation template");
				END;
			END;

			NEW(checker);
			checker.Document(document, NIL);

			IF trace THEN
				Global.GetModuleName(syntaxTreeModule, name);
				Strings.Append(name,".docu");
				dump := Basic.GetDebugWriter(name);
				NEW(printer, dump);
				printer.Document(document);
				NEW(htmlPrinter, dump);
				htmlPrinter.Document(document);
				dump.Update;
			END;
			IF name = "*" THEN
				Global.GetModuleName(syntaxTreeModule, name);
			END;
			Files.JoinExtension(name, extension, name);
			file := Files.New(name);
			IF file # NIL THEN
				NEW(writer, file,0);
				IF extension = "html" THEN
					NEW(htmlPrinter, writer);
					htmlPrinter.Document(document);
				ELSE
					NEW(printer, writer);
					printer.Document(document);
				END;
				writer.Update;
				Files.Register(file);
			END;
			RETURN NIL
		END ProcessSyntaxTreeModule;

		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN
			DefineOptions^(options);
			options.Add(0X,"dtrace",Options.Flag);
			options.Add(0X,"docuTemplate", Options.String);
			options.Add(0X,"internals",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		BEGIN
			GetOptions^(options);
			trace := options.GetFlag("dtrace");
			IF ~options.GetString("d", fileName) THEN fileName := "" END;
			IF ~options.GetString("docuTemplate", templateFile) THEN COPY(DefaultTemplateFile, templateFile) END;
			internals := options.GetFlag("internals");
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get()
		END DefaultSymbolFileFormat;

		PROCEDURE DefaultObjectFileFormat(): Formats.ObjectFileFormat;
		BEGIN RETURN NIL
		END DefaultObjectFileFormat;

	END DocumentationBackend;

	(* helper procedures *)

	PROCEDURE Small(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR ch: CHAR; i: LONGINT;
	BEGIN
		i := 0;
		REPEAT
			ch := name[i];
			IF (ch >= 'A') & (ch <= 'Z') THEN
				ch := CHR(ORD(ch)-ORD('A')+ORD('a'));
			END;
			result[i] := ch; INC(i);
		UNTIL ch = 0X;
	END Small;

	PROCEDURE Hex(w: Streams.Writer; x: HUGEINT);
	VAR i: LONGINT; a: ARRAY 20 OF CHAR; y: HUGEINT;
	BEGIN
		i := 0;
		REPEAT
			y := x MOD 10H;
			IF y < 10 THEN a[i] := CHR(y+ORD('0'))
			ELSE a[i] := CHR(y-10+ORD('A'))
			END;
			x := x DIV 10H;
			INC(i);
		UNTIL (x=0) OR (i=16);
		IF y >=10 THEN w.Char("0") END;
		REPEAT DEC( i ); w.Char( a[i] ) UNTIL i = 0
	END Hex;

	PROCEDURE ToText(w: Streams.StringWriter; text: DocumentationTree.Text; elementType: ElementType);
	VAR textElement: DocumentationTree.TextElement; s: DocumentationTree.String;
	BEGIN
		NEW(s,w.Pos()+1);
		w.Get(s^);
		textElement := text.AppendNew(elementType);
		textElement.SetString(s);
		w.SetPos(0); (* reset writer *)
	END ToText;

	PROCEDURE WriteSymbolLabel(text: DocumentationTree.Text; symbol: SyntaxTree.Symbol);
	VAR label: Basic.SectionName;
	BEGIN
		Global.GetSymbolNameInScope(symbol,NIL,label);
		text.WriteLabel(label);
	END WriteSymbolLabel;



	PROCEDURE WriteReferenceInScope*(text: DocumentationTree.Text; symbol: SyntaxTree.Symbol; inScope: SyntaxTree.Scope);
	VAR n: SyntaxTree.IdentifierString; td: SyntaxTree.TypeDeclaration; name: Basic.SectionName; write: BOOLEAN;
		PROCEDURE Scope(scope: SyntaxTree.Scope);
		BEGIN

			IF scope = NIL THEN (* do nothing, locally declared temporary symbol *)
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				Scope(NIL);
				Global.GetModuleName(scope.ownerModule, name);
				IF write THEN text.WriteWeakLink(name, name); text.WriteString(".") END;
				Strings.Append(name,".");
			ELSIF scope IS SyntaxTree.RecordScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.RecordScope).ownerRecord.typeDeclaration;
				IF td = NIL THEN
					td := scope(SyntaxTree.RecordScope).ownerRecord.pointerType.typeDeclaration;
				END;
				td.GetName(n);
				Strings.Append(name,n);
				IF write THEN text.WriteWeakLink(name, n); text.WriteString(".") END;
				Strings.Append(name,".")
			ELSIF scope IS SyntaxTree.ProcedureScope THEN
				Scope(scope.outerScope);
				scope(SyntaxTree.ProcedureScope).ownerProcedure.GetName(n);
				Strings.Append(name,n);
				IF write THEN text.WriteWeakLink(name, n); text.WriteString(".") END;
				Strings.Append(name,".")
			ELSIF scope IS SyntaxTree.CellScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.CellScope).ownerCell.typeDeclaration;
				td.GetName(n);
				Strings.Append(name,n);
				IF write THEN text.WriteWeakLink(name, n); text.WriteString(".") END;
				Strings.Append(name,".")
			ELSE Scope(scope.outerScope)
			END;
			IF (scope = inScope) THEN write := TRUE END;
		END Scope;

	BEGIN
		write := FALSE;
		name := "";
		Scope(symbol.scope);
		symbol.GetName(n);
		IF symbol IS SyntaxTree.Operator THEN (*! append some more bits to make discrimintation possible *)
		END;
		Strings.Append(name,n);
		text.WriteWeakLink(name, n);
	END WriteReferenceInScope;

	PROCEDURE WriteSymbolReference(text: DocumentationTree.Text; symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope);
	VAR name, label: Basic.SectionName; textElement: DocumentationTree.TextElement;
	BEGIN
		WriteReferenceInScope(text,symbol,scope);
		(*
		Global.GetSymbolNameInScope(symbol,scope,name);
		Global.GetSymbolNameInScope(symbol,NIL,label);
		IF symbol.comment # NIL THEN
			text.WriteLink(label, name);
		ELSE
			text.WriteString(name)
		END;
		*)
	END WriteSymbolReference;

	(*
	PROCEDURE ConvertSpecialSections(document: DocumentationTree.Document);
	VAR description: DocumentationTree.Paragraphs; i: LONGINT; section: DocumentationTree.Section; par : DocumentationTree.Paragraph;
	BEGIN
		description := document.description;
		FOR i := document.sections.Length()-1 TO 0 BY -1 DO
		 section := document.sections.GetSection(i);
			IF (section.label # NIL) THEN
				IF section.label^= "author" THEN
					par := description.AppendNew(ParagraphType.Heading);
					par.SetLevel(4);
					par.text.WriteString("Author");
					par.text.WriteText(section.title);
					document.sections.RemoveByIndex(i);
				END;
			END;
		END;
	END ConvertSpecialSections;
	*)

	PROCEDURE ParseComments(document : DocumentationTree.Document; c,sentinel: SyntaxTree.Comment; x: ANY);
	VAR string: DocumentationTree.String; stringReader: Streams.StringReader; parser: DocumentationParser.Parser; scanner: DocumentationScanner.Scanner;
		printer: DocumentationPrinter.Printer;
	BEGIN
		IF c # NIL THEN
			string := MergeComments(c,sentinel,x);
			NEW(stringReader, LEN(string));
			stringReader.Set(string^);
			NEW(scanner, stringReader,0,NIL);
			NEW(parser, scanner);
			parser.ParseDocument(document);
			(*ConvertSpecialSections(document);*)
		END;
	END ParseComments;

	(* sentinel used for stopping merging at closing comment of a module if the opening comment comes directly before it.*)
	PROCEDURE MergeComments(c,sentinel: SyntaxTree.Comment; x: ANY): DocumentationTree.String;
	VAR i,len: LONGINT; tmp: SyntaxTree.Comment; string: DocumentationTree.String;
	BEGIN
		len := 0; tmp := c;
		WHILE (tmp # sentinel) & (tmp.item = x) DO
			IF tmp.source[0] = "*" THEN
				i := 1;
				WHILE (i<LEN(tmp.source^)) & (tmp.source[i] # 0X) DO
					INC(i); INC(len);
				END;
			END;
			INC(len,2);
			tmp := tmp.nextComment;
		END;
		NEW(string, len+1);
		len := 0; tmp := c;
		WHILE (tmp # sentinel) & (tmp.item = x) DO
			IF tmp.source[0] = "*" THEN
				i := 1;
				WHILE (i<LEN(tmp.source^)) & (tmp.source[i] # 0X) DO
					string[len] := tmp.source[i];
					INC(i); INC(len);
				END;
				IF (len > 0) & (string[len-1] = "*") THEN DEC(len) END; (* remove last "*" from comment *)
			END;
			string[len] := Scanner.CR;
			INC(len);
			string[len] := Scanner.CR;
			INC(len);
			tmp := tmp.nextComment;
		END;
		string[len] := 0X;
		RETURN string
	END MergeComments;

	PROCEDURE KeepSections(in: DocumentationTree.Document);
	VAR i , j: LONGINT; insert, check: DocumentationTree.Section; done: BOOLEAN; paragraph: DocumentationTree.Paragraph; section: DocumentationTree.Section;
	BEGIN
			FOR i := 0 TO in.sections.Length()-1 DO
				section := in.sections.GetSection(i);
				IF section.title.Length() # 0 THEN
					paragraph := in.description.AppendNew(ParagraphType.Heading);
					paragraph.SetLevel(section.level);
					paragraph.text.WriteText(section.title);
					MergeParagraphs(in.description, section.contents);
				END;
			END;
	END KeepSections;

	PROCEDURE MergeDocument(in: DocumentationTree.Document; descriptionSection: DocumentationTree.Paragraphs; this: DocumentationTree.Document);
	VAR i , j: LONGINT; insert, check: DocumentationTree.Section; done: BOOLEAN; paragraph: DocumentationTree.Paragraph; section: DocumentationTree.Section;
	BEGIN
		ASSERT(in # NIL);
		IF descriptionSection = NIL THEN descriptionSection := in.description END;
		IF this # NIL THEN
			FOR i := 0 TO this.description.Length()-1 DO
				descriptionSection.Add(this.description.GetParagraph(i));
			END;
			MergeSections(in.sections, this.sections);

			(*
			FOR i := 0 TO this.sections.Length()-1 DO
				section := this.sections.GetSection(i);
				paragraph := this.description.AppendNew(ParagraphType.Heading);
				paragraph.SetLevel(2);
				paragraph.text.WriteText(section.title);
				MergeParagraphs(this.description, section.contents);
			END;
			*)
		END
	END MergeDocument;

	PROCEDURE MergeParagraphs(in, this: DocumentationTree.Paragraphs);
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO this.Length()-1 DO
			in.AddParagraph(this.GetParagraph(i));
		END;
	END MergeParagraphs;

	PROCEDURE MergeSections(in, this: DocumentationTree.Sections);
	VAR j,i,k,l: LONGINT;  insert, check: DocumentationTree.Section; done: BOOLEAN; par, paragraph,checkPar: DocumentationTree.Paragraph; section: DocumentationTree.Section;
	BEGIN
			i := 0;
			WHILE i < this.Length() DO
				insert := this.GetSection(i);

				done := FALSE;
				IF insert.label # NIL THEN
					j := 0;
					WHILE (j < in.Length()) (*& ~done*) DO
						check := in.GetSection(j);
						IF (check.label # NIL) & (check.label^ = insert.label^) THEN
							(* first merge all paragraphs *)
							MergeParagraphs(check.contents, insert.contents);
							done := TRUE;
						ELSE
							k := 0;
							WHILE k < check.contents.Length() DO
								checkPar := check.contents.GetParagraph(k);
								IF (checkPar.type = ParagraphType.Heading) & (checkPar.label # NIL) & (checkPar.label^ = insert.label^) THEN
									done := TRUE;
									REPEAT
										INC(k);
										IF k < check.contents.Length() THEN
											par := check.contents.GetParagraph(k);
										END;
									UNTIL (k = check.contents.Length()) OR (par.type = ParagraphType.Heading) & (par.level >= checkPar.level);
									FOR l := 0 TO insert.contents.Length()-1 DO
										paragraph := insert.contents.GetParagraph(l);
										check.contents.Insert(k,paragraph);
										INC(k);
									END;
								END;
								INC(k);
							END;
						END;
						INC(j);
					END;
				END;
				IF ~done THEN
					in.Add(this.GetSection(i));
				END;
				INC(i);
			END;
	END MergeSections;

	PROCEDURE MergeSectionDocument(section: DocumentationTree.Section; document: DocumentationTree.Document);
	VAR paragraphs: DocumentationTree.Paragraphs; i,j: LONGINT; paragraph: DocumentationTree.Paragraph; first: BOOLEAN; firstSection: DocumentationTree.Section;
	BEGIN
		NEW(paragraphs, document.description.Length() + section.contents.Length());
		FOR i := 0 TO document.description.Length()-1 DO
			paragraphs.Add(document.description.GetParagraph(i));
		END;
		FOR i := 0 TO section.contents.Length()-1 DO
			paragraphs.Add(section.contents.GetParagraph(i));
		END;
		section.SetContents(paragraphs);

		FOR i := 0 TO document.sections.Length()-1 DO
			section := document.sections.GetSection(i);
			IF (section.label # NIL)  THEN
				first := TRUE;
				FOR j := 0 TO i-1 DO
					firstSection := document.sections.GetSection(j);
					IF (firstSection.label # NIL) & (firstSection.label^ = section.label^) THEN
						first := FALSE;
					END;
				END;

				IF first THEN
					paragraph := paragraphs.AppendNew(ParagraphType.Heading);
					paragraph.SetLevel(2);
					paragraph.text.WriteString(section.label^);
					paragraph.text.WriteText(section.title);
				END;
				MergeParagraphs(paragraphs, section.contents);
			END;
		END;

	END MergeSectionDocument;


	PROCEDURE Get*(): Backend.Backend;
	VAR documentationBackend: DocumentationBackend;
	BEGIN
		NEW(documentationBackend); RETURN documentationBackend;
	END Get;



END FoxDocumentationBackend.

~~

(**
= Documentation Backend Description.

This closing comment can be used to describe a whole application.
It may contain sections like this:

@ Section1
	* bullet1
		** bullet2
		*boldface* (and in same line)
		*erroneous boldface
	# bullet3
		## bullet4
		## bullet5
	# bullet 6
@ Section2

The following is a bulleted list

	\* Bullet1
	\* Bullet2


	This is  a normal text with *

There may be references like this: [[Get|FoxDocumentationBackend.Get]]


*)

SystemTools.Free FoxDocumentationHtml FoxDocumentationBackend FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationTree FoxDocumentationScanner ~
Compiler.Compile -d=*.html -i  oc/FoxDocumentationBackend.Mod ~
