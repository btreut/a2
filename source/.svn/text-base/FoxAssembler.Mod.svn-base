MODULE FoxAssembler;   (**  AUTHOR "fof"; PURPOSE "Oberon Assembler: Generic Part";  **)
(* (c) fof ETH Zürich, 2009 *)

IMPORT Streams, Strings, Diagnostics,D := Debugging, Commands, BinaryCode := FoxBinaryCode, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal,
	IntermediateCode := FoxIntermediateCode, Sections := FoxSections, Scanner := FoxScanner, Basic := FoxBasic, SYSTEM, ObjectFile;

CONST
	Trace* = FALSE;   (* debugging output *)

	MaxOperands* = 3;

	(*
		currently there is conceptual support for one-pass assembly with a fixup mechanism for section-local references
		disadvantages of one-pass assembly:
			- expressions with labels would not work
			- fixup mechanism complicated and not generic


	*)
	MaxPasses* = 2;

	ConstantInteger* = 0;
	ConstantFloat* = 1;
	Fixup* = 2;
	Offset* = 3;
	ConstantIntegerOrOffset* = {ConstantInteger, Offset};

TYPE
	OperandString=ARRAY 256 OF CHAR;

	FixupElement=POINTER TO RECORD
		fixup: BinaryCode.Fixup; next: FixupElement;
	END;

	NamedLabel*= OBJECT
	VAR
		section: IntermediateCode.Section;
		offset, displacement: LONGINT; (* in contrast to offset, displacement will be reset each round of assembling. This is to make sure that GetFixup generates the right displacement in the fixup *)
		name-: Scanner.IdentifierString;
		nextNamedLabel-: NamedLabel;
		fixupList: FixupElement;

		PROCEDURE &InitNamedLabel(section: IntermediateCode.Section; CONST name: ARRAY OF CHAR);
		BEGIN
			fixupList := NIL;
			SELF.offset := 0; (* must be zero to be able to track local displacement *)
			SELF.section := section;
			COPY(name,SELF.name);
			nextNamedLabel := NIL;
		END InitNamedLabel;

		PROCEDURE GetFixup(): BinaryCode.Fixup;
		VAR fixup: BinaryCode.Fixup; element: FixupElement; identifier: ObjectFile.Identifier;
		BEGIN
			identifier.name := section.name;
			fixup := BinaryCode.NewFixup(BinaryCode.Absolute,0,identifier,0,displacement,0,NIL);
			NEW(element); element.fixup := fixup; element.next := fixupList; fixupList := element;
			RETURN fixup;
		END GetFixup;

		PROCEDURE ResetDisplacements;
		VAR element: FixupElement;
		BEGIN
			displacement := 0;
			element := fixupList;
			WHILE element # NIL DO
				element.fixup.SetSymbol(section.name,0,0,0);
				element := element.next;
			END;
		END ResetDisplacements;

		PROCEDURE SetOffset*(ofs: LONGINT);
		VAR element: FixupElement;
		BEGIN
			SELF.offset := ofs;
			displacement := ofs;
			element := fixupList;
			WHILE element # NIL DO
				element.fixup.SetSymbol(section.name,0,0,element.fixup.displacement (* must be here to take into account modifications of code emission *) +displacement);
				element := element.next;
			END;
		END SetOffset;

	END NamedLabel;

	NamedLabelList*=OBJECT
	VAR first-,last-: NamedLabel;

		PROCEDURE & InitNamedLabelList;
		BEGIN first := NIL; last := NIL
		END InitNamedLabelList;

		PROCEDURE Add*(n: NamedLabel);
		BEGIN
			IF first = NIL THEN first := n ELSE last.nextNamedLabel := n; last.nextNamedLabel := n;  END; last := n;
		END Add;

		PROCEDURE ResetDisplacements;
		VAR label: NamedLabel;
		BEGIN
			label := first;
			WHILE label # NIL DO label.ResetDisplacements; label := label.nextNamedLabel END;
		END ResetDisplacements;

		PROCEDURE Find*(CONST name: ARRAY OF CHAR): NamedLabel;
		VAR label: NamedLabel;
		BEGIN
			label := first;
			WHILE (label # NIL) & (label.name # name)  DO
				label := label.nextNamedLabel;
			END;
			RETURN label
		END Find;

	END NamedLabelList;

	Result*= RECORD
		type*: INTEGER; (* ConstantInteger, ConstantFloat, Fixup, Offset *)
		sizeInBits*: INTEGER;
		value*: LONGINT; (*! implementation restriction: operations between hugeints do not yet work *)
		valueR*: LONGREAL;
		fixup*: BinaryCode.Fixup;
	END;

	NamedResult*=POINTER TO RECORD (Result)
		name: Scanner.IdentifierString;
		nextResult: NamedResult;
	END;

	NamedResultList*=OBJECT
	VAR first, last: NamedResult; number: LONGINT;

		PROCEDURE & InitNamedResultList;
		BEGIN first := NIL; last := NIL; number := 0;
		END InitNamedResultList;

		PROCEDURE Add*(n: NamedResult);
		BEGIN
			IF first = NIL THEN first := n ELSE last.nextResult := n END; last := n; INC(number);
		END Add;

		PROCEDURE Find*(CONST name: ARRAY OF CHAR): NamedResult;
		VAR result: NamedResult;
		BEGIN
			result := first;
			WHILE (result # NIL) & (result.name # name)  DO
				result := result.nextResult;
			END;
			RETURN result
		END Find;

	END NamedResultList;

	Assembler*= OBJECT
	VAR
		diagnostics: Diagnostics.Diagnostics;
		error-: BOOLEAN;
		errorPosition-: LONGINT;
		symbol-: Scanner.Symbol;
		scanner: Scanner.AssemblerScanner;
		orgOffset: LONGINT;
		section-: IntermediateCode.Section;
		code: BinaryCode.Section;
		labels: NamedLabelList;
		results: NamedResultList;
		scope: SyntaxTree.Scope;
		module: Sections.Module;
		pass-: LONGINT;

		PROCEDURE &Init*(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics; errorPosition := Diagnostics.Invalid; orgOffset := 0;
		END Init;

		PROCEDURE SetContext(CONST context: Scanner.Context);
		BEGIN
			scanner.SetContext(context); NextSymbol;
		END SetContext;

		PROCEDURE Error*(pos: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			error := TRUE;
			IF diagnostics # NIL THEN
				diagnostics.Error(scanner.source^,pos,Diagnostics.Invalid,msg);
			END;
		END Error;

		PROCEDURE ErrorSS*(pos: LONGINT; CONST s1,s2: ARRAY OF CHAR);
		VAR msg: Basic.MessageString;
		BEGIN COPY(s1,msg); Strings.Append(msg,s2); Error(pos, msg);
		END ErrorSS;

		PROCEDURE NextSymbol*;
		BEGIN error := error OR ~scanner.GetNextSymbol(symbol); errorPosition := symbol.start;
		END NextSymbol;

		PROCEDURE ThisToken*(x: LONGINT): BOOLEAN;
		BEGIN
			IF ~error & (symbol.token = x) THEN NextSymbol; RETURN TRUE ELSE RETURN FALSE END;
		END ThisToken;

		PROCEDURE GetIdentifier*(VAR pos: LONGINT; VAR identifier: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			pos := symbol.start;
			IF symbol.token # Scanner.Identifier THEN RETURN FALSE
			ELSE COPY(symbol.identifierString,identifier); NextSymbol; RETURN TRUE
			END;
		END GetIdentifier;

		PROCEDURE ThisIdentifier*(CONST this: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF ~error & (symbol.token = Scanner.Identifier) & (this = symbol.identifierString) THEN NextSymbol; RETURN TRUE ELSE RETURN FALSE END;
		END ThisIdentifier;

		PROCEDURE ExpectIdentifier*(VAR pos: LONGINT; VAR identifier: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF ~GetIdentifier(pos,identifier)THEN Error(errorPosition,"identifier expected"); RETURN FALSE
			ELSE RETURN TRUE
			END;
		END ExpectIdentifier;

		PROCEDURE ExpectToken*(x: LONGINT): BOOLEAN;
		VAR s: Basic.MessageString;
		BEGIN
			IF ThisToken(x) THEN RETURN TRUE
			ELSE
				s := "expected token "; Strings.Append(s,Scanner.tokens[x]); Strings.Append(s," but got "); Strings.Append(s,Scanner.tokens[symbol.token]);
				Error(errorPosition,s);RETURN FALSE
			END;
		END ExpectToken;

		PROCEDURE ExpectConstantInteger*(VAR x: Result; critical: BOOLEAN): BOOLEAN;
		VAR result: Result;
		BEGIN
			IF ~Expression(result,critical) OR (result.type # ConstantInteger) THEN
				result.value := 0;
				IF critical THEN Error(errorPosition,"constant integer expected") END;
				RETURN ~critical
			ELSE RETURN TRUE
			END
		END ExpectConstantInteger;

		PROCEDURE Section;
		VAR sectionType: Scanner.IdentifierString; pos: LONGINT;
		BEGIN
			IF ExpectToken(Scanner.Period) THEN
				IF ExpectIdentifier(pos,sectionType) THEN
					IF sectionType = "data" THEN
						IF Trace THEN D.String("data section"); D.Ln END;
						(*! generate section here, if allowed *)
					ELSIF sectionType = "code" THEN
						IF Trace THEN D.String("code section"); D.Ln END;
						(*! generate section here, if allowed *)
					ELSE Error(pos,"expected data or code");
					END;
				END;
			END;
		END Section;

		PROCEDURE DefineLabel(pos: LONGINT; CONST name: ARRAY OF CHAR);
		VAR label: NamedLabel;
		BEGIN
			IF Trace THEN D.String("define label: "); D.String(name); D.Ln END;
			IF labels.Find(name) # NIL THEN
				Error(pos,"multiply declared identifier")
			ELSE
				NEW(label,section,name);
				labels.Add(label);
				ASSERT(labels.Find(name) =label);
			END;
		END DefineLabel;

		PROCEDURE SetLabel(pos: LONGINT; CONST name: ARRAY OF CHAR);
		VAR label: NamedLabel;
		BEGIN
			IF Trace THEN D.String("set label: "); D.String(name); D.String(" "); D.Int(code.pc,1); D.Ln END;
			label := labels.Find(name);
			label.SetOffset(code.pc);
		END SetLabel;

		PROCEDURE CopyResult(CONST from: Result; VAR to: Result);
		BEGIN
			to.type := from.type;
			to.sizeInBits := from.sizeInBits;
			to.value := from.value;
			to.valueR := from.valueR;
			to.fixup := from.fixup;
		END CopyResult;

		PROCEDURE DefineResult(pos: LONGINT; CONST name: ARRAY OF CHAR; CONST r: Result);
		VAR result: NamedResult;
		BEGIN
			IF Trace THEN D.String("define result: "); D.String(name); D.Ln END;
			IF results.Find(name) # NIL THEN
				Error(pos,"multiply declared identifier")
			ELSE
				NEW(result); COPY(name,result.name);
				CopyResult(r,result^);
				results.Add(result);
				ASSERT(results.Find(name) =result);
			END;
		END DefineResult;

		PROCEDURE SetResult(CONST name: ARRAY OF CHAR; CONST r: Result);
		VAR result: NamedResult;
		BEGIN
			IF Trace THEN D.String("define result: "); D.String(name); D.Ln END;
			result := results.Find(name);
			CopyResult(r,result^);
		END SetResult;

		PROCEDURE SymbolInScope(CONST ident: ARRAY OF CHAR): SyntaxTree.Symbol;
		VAR sym: SyntaxTree.Symbol; localScope: SyntaxTree.Scope;  identifier: SyntaxTree.Identifier;
		CONST Trace=FALSE;
		BEGIN
			IF scope = NIL THEN RETURN NIL END;
			localScope := scope;
			identifier := SyntaxTree.NewIdentifier(ident);
			IF Trace THEN D.String("GetScopeSymbol:"); D.String(ident); D.Ln; END;
			WHILE (sym = NIL) & (localScope # NIL) DO
				sym := localScope.FindSymbol(identifier);
				localScope := localScope.outerScope
			END;

			IF (sym # NIL) & (sym IS SyntaxTree.Import)  THEN
				NextSymbol;
				IF ExpectToken(Scanner.Period) & (symbol.token = Scanner.Identifier) THEN
					identifier := SyntaxTree.NewIdentifier(symbol.identifierString);
					IF Trace THEN D.String("GetScopeSymbol  :"); D.String(symbol.identifierString); D.Ln; END;
					localScope := sym(SyntaxTree.Import).module.moduleScope;
					sym := NIL;
					WHILE (sym = NIL) & (localScope # NIL) DO
						sym := localScope.FindSymbol(identifier);
						IF (sym # NIL) & (sym.access * SyntaxTree.Public = {}) THEN sym := NIL END;
						localScope := localScope.outerScope
					END;
				ELSE RETURN NIL
				END;
			END;
			IF Trace THEN IF sym = NIL THEN D.String("not found") ELSE D.String("found"); END; D.Ln; END;
			RETURN sym
		END SymbolInScope;

		PROCEDURE ConstantSymbol(pos: LONGINT; constant: SyntaxTree.Constant; VAR result: Result): BOOLEAN;
		BEGIN
			IF constant.type.resolved IS SyntaxTree.CharacterType THEN
				result.value := ORD(constant.value.resolved(SyntaxTree.CharacterValue).value);
				result.valueR := result.value;
				result.type := ConstantInteger;
			ELSIF constant.type.resolved IS SyntaxTree.IntegerType THEN
				result.value := constant.value.resolved(SyntaxTree.IntegerValue).value;
				result.valueR := result.value;
				result.type := ConstantInteger;
			ELSIF constant.type.resolved IS SyntaxTree.FloatType THEN
				result.valueR := constant.value.resolved(SyntaxTree.RealValue).value;
				result.type := ConstantFloat;
			ELSE
				Error(pos,"incompatible constant");
				RETURN FALSE;
			END;
			result.sizeInBits := SHORT(module.system.SizeOf(constant.type));
			RETURN TRUE
		END ConstantSymbol;

		PROCEDURE GetFingerprint(symbol: SyntaxTree.Symbol): LONGINT;
		BEGIN
			IF (symbol # NIL) THEN RETURN symbol.fingerprint.shallow END;
		END GetFingerprint;


		PROCEDURE NonConstantSymbol(pos: LONGINT; symbol: SyntaxTree.Symbol; VAR result: Result): BOOLEAN;
		VAR
			name: Basic.SegmentedName; moduleScope: SyntaxTree.Scope; fixupSection: IntermediateCode.Section;
			fixupPatternList: ObjectFile.FixupPatterns; identifier: ObjectFile.Identifier;
		BEGIN
			IF scope = NIL THEN RETURN FALSE END;
			moduleScope := scope.ownerModule.moduleScope;
			Global.GetSymbolSegmentedName(symbol,name);
			identifier.name := name;
			identifier.fingerprint := GetFingerprint(symbol);

			IF symbol.scope IS SyntaxTree.ModuleScope THEN (* symbol in module scope *)
				IF symbol IS SyntaxTree.Variable THEN (* global variable *)
					result.type := Fixup;
					result.sizeInBits := SHORT(module.system.SizeOf(symbol.type));

					(* generic fixup pattern list for generic implementation of data instruction etc. -- otherwise replaced during encoding *)
					NEW(fixupPatternList, 1);
					fixupPatternList[0].bits := result.sizeInBits;
					fixupPatternList[0].offset := 0;
					result.fixup := BinaryCode.NewFixup(BinaryCode.Absolute, 0, identifier, 0, 0, 0, fixupPatternList);

				ELSIF symbol IS SyntaxTree.Procedure THEN (* procedure *)
					IF symbol(SyntaxTree.Procedure).isInline THEN
						Error(pos,"forbidden reference to inline procedure"); RETURN FALSE
					ELSE
						result.type := Fixup;
						result.sizeInBits := SHORT(module.system.SizeOf(symbol.type));
						(* generic fixup pattern list for generic implementation of data instruction etc. -- otherwise replaced during encoding *)
						NEW(fixupPatternList, 1);
						fixupPatternList[0].bits := result.sizeInBits;
						fixupPatternList[0].offset := 0;
						result.fixup := BinaryCode.NewFixup(BinaryCode.Absolute, 0, identifier, 0, 0, 0, fixupPatternList);
					END;
				ELSE HALT(100);
				END;
			ELSIF symbol.scope IS SyntaxTree.ProcedureScope THEN (* symbol in procedure (local) scope *)
				IF symbol.scope # scope THEN
					Error(pos,"local symbol not in current scope");
				ELSE
					RETURN FALSE;
					IF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
						result.type := Offset;
						result.value := symbol.offsetInBits DIV module.system.dataUnit;
						ASSERT(symbol.offsetInBits MOD module.system.dataUnit = 0);
						result.sizeInBits := SHORT(module.system.SizeOf(symbol.type));
					ELSE Error(pos,"forbidden symbol in local scope");
					END;
				END
			ELSIF symbol.scope IS SyntaxTree.RecordScope THEN (* symbol in record scope *)
			ELSE Error(pos,"symbol in forbidden scope"); RETURN FALSE
			END;
			RETURN TRUE
		END NonConstantSymbol;

		PROCEDURE GetNonConstant*(pos: LONGINT; CONST ident: ARRAY OF CHAR; VAR result: Result): BOOLEAN;
		VAR symbol: SyntaxTree.Symbol; namedLabel: NamedLabel;
			name: Basic.SegmentedName;fixupPatternList: ObjectFile.FixupPatterns;
			string: ARRAY 256 OF CHAR;
			identifier: ObjectFile.Identifier;
		BEGIN
			namedLabel := labels.Find(ident);
			IF (namedLabel # NIL) THEN
				result.type := Fixup;
				result.fixup := namedLabel.GetFixup();
				RETURN TRUE
			END;
			IF ident[0] = "@" THEN
				result.type := Fixup;
				COPY(ident, string);
				Strings.Delete(string,0,1);
				Basic.ToSegmentedName(string, name);
				result.sizeInBits := 32;
				NEW(fixupPatternList, 1);
				fixupPatternList[0].bits := result.sizeInBits;
				fixupPatternList[0].offset := 0;
				identifier.name := name;
				identifier.fingerprint := 0;
				result.fixup := BinaryCode.NewFixup(BinaryCode.Absolute, 0, identifier, 0, 0, 0, fixupPatternList);
				RETURN TRUE
			END;
			symbol := SymbolInScope(ident);
			IF symbol = NIL THEN RETURN FALSE
			ELSIF symbol IS SyntaxTree.Constant THEN RETURN FALSE
			ELSE RETURN NonConstantSymbol(pos,symbol,result)
			END;
		END GetNonConstant;

		PROCEDURE LocalOffset(pos: LONGINT; symbol: SyntaxTree.Symbol; VAR result: Result): BOOLEAN;
		BEGIN
			IF symbol.scope IS SyntaxTree.ProcedureScope THEN (* symbol in procedure (local) scope *)
				IF symbol.scope = scope THEN
					IF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
						result.type := ConstantInteger;
						result.value := symbol.offsetInBits DIV module.system.dataUnit;
						ASSERT(symbol.offsetInBits MOD module.system.dataUnit = 0);
						result.sizeInBits := SHORT(module.system.SizeOf(symbol.type));
						RETURN TRUE
					END;
				END;
			END;
			RETURN FALSE
		END LocalOffset;

		PROCEDURE GetConstant*(pos: LONGINT; CONST ident: ARRAY OF CHAR; VAR result: Result): BOOLEAN;
		VAR symbol: SyntaxTree.Symbol; namedResult: NamedResult;
		BEGIN
			namedResult := results.Find(ident);
			IF namedResult # NIL THEN CopyResult(namedResult^,result); RETURN TRUE END;
			symbol := SymbolInScope(ident);
			IF symbol = NIL THEN RETURN FALSE
			ELSIF symbol IS SyntaxTree.Constant THEN RETURN ConstantSymbol(pos,symbol(SyntaxTree.Constant),result)
			ELSIF LocalOffset(pos,symbol,result) THEN RETURN TRUE
			ELSE RETURN FALSE
			END;
		END GetConstant;

		PROCEDURE Factor (VAR x: Result; critical: BOOLEAN): BOOLEAN;
		VAR label: NamedLabel; identifier: Scanner.IdentifierString; pos: LONGINT;
		BEGIN
			IF ThisToken(Scanner.Number) THEN
				(* ASSERT(symbol.numberType = Scanner.Integer); *)
				IF symbol.numberType = Scanner.Integer THEN
					x.value := symbol.integer
				ELSIF symbol.numberType = Scanner.Hugeint THEN
					(* note that 64 bit integer constants are not (yet) supported in expressions by the assembler.
					however, the scanner interprets large 32 bit integers as hugeints (because integers are always assumed to be signed). *)
					x.value := SYSTEM.VAL(LONGINT, symbol.hugeint); (* TODO: how to do that? *)
					ASSERT(x.value < 0); (* the resulting 32 bit integer must be negative when interpreted as a signed value *)
				END;
				x.type := ConstantInteger;
				RETURN TRUE;
			ELSIF ThisToken(Scanner.PC) THEN (* pc IN units ! *)
				x.value := code.pc;
				x.type := ConstantInteger; (* TODO: should it be 'x.type := Offset'? *)
				RETURN TRUE;
			ELSIF ThisToken(Scanner.PCOffset) THEN
				x.value := code.pc-orgOffset;
				x.type := ConstantInteger; (* TODO: should it be 'x.type := Offset'? *)
				RETURN TRUE;
			ELSIF GetIdentifier(pos,identifier) THEN
				label := labels.Find (identifier);
				IF label # NIL THEN
					x.value := label.offset;
					x.type := Offset;
					(*! deal with fixups ? / enter fixup ? *)
					RETURN TRUE;
				ELSIF GetConstant(errorPosition, identifier,x) THEN RETURN TRUE
				ELSIF ~critical & (pass # MaxPasses) THEN
					x.value := 0; x.type := ConstantInteger; RETURN TRUE
				ELSE Error(pos,"undefined symbol"); RETURN FALSE
				END;
			ELSIF ThisToken(Scanner.LeftParenthesis)  THEN
				RETURN Expression (x, critical) & ExpectToken(Scanner.RightParenthesis);
			END;
			RETURN FALSE
		END Factor;

		(* term = Factor { ( "*" | "/" | "%" ) Factor } *)
		PROCEDURE Term (VAR x: Result; critical: BOOLEAN): BOOLEAN;
		VAR y: Result; op : LONGINT;
		BEGIN
			IF Factor (x, critical) THEN
				WHILE (symbol.token = Scanner.Times) OR (symbol.token = Scanner.Div) OR (symbol.token = Scanner.Mod) DO
					op := symbol.token; NextSymbol;
					IF Factor (y, critical) THEN
						IF (x.type IN ConstantIntegerOrOffset) & (y.type IN ConstantIntegerOrOffset) THEN
							IF op = Scanner.Times THEN x.value := x.value * y.value
							ELSIF op = Scanner.Div THEN x.value := x.value DIV y.value
							ELSE x.value := x.value MOD y.value
							END;
						ELSIF (x.type = ConstantFloat) OR (y.type = ConstantFloat) THEN
							IF op = Scanner.Times THEN x.valueR := x.valueR * y.valueR
							ELSIF op = Scanner.Div THEN x.valueR := x.valueR / y.valueR
							ELSE RETURN FALSE
							END;
						ELSE RETURN FALSE
						END;
					ELSE
						RETURN FALSE;
					END;
				END;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Term;

		(* Expression = [ "-" | "+" | "~" ] Term { ( "+" | "-" ) Term } *)
		PROCEDURE Expression*(VAR x: Result; critical: BOOLEAN): BOOLEAN;
		VAR y: Result; op : LONGINT;
		BEGIN
			op := symbol.token;
			IF ThisToken(Scanner.Minus) THEN
				IF Term (x, critical) THEN
					IF x.type IN ConstantIntegerOrOffset THEN
						x.value := -x.value; x.valueR := x.value
					ELSIF x.type = ConstantFloat THEN
						x.valueR := -x.valueR
					ELSE
						RETURN FALSE
					END;
				ELSE
					RETURN FALSE;
				END;
			ELSIF ThisToken(Scanner.Plus) THEN
				IF ~Term (x, critical) THEN RETURN FALSE
				ELSE
					RETURN (x.type IN ConstantIntegerOrOffset) OR (x.type = ConstantFloat)
				END;
			ELSIF ThisToken(Scanner.Not) THEN
				IF Term (x, critical) THEN
					IF x.type IN ConstantIntegerOrOffset THEN
						x.value := -x.value-1; x.valueR := x.value
					ELSE
						RETURN FALSE
					END
				END;
			ELSIF ~Term (x, critical) THEN RETURN FALSE
			END;
			WHILE (symbol.token = Scanner.Plus) OR (symbol.token = Scanner.Minus) DO
				op := symbol.token; NextSymbol;
				IF Term (y, critical) THEN
					IF op = Scanner.Plus THEN
						IF (x.type IN ConstantIntegerOrOffset) & (y.type IN ConstantIntegerOrOffset) THEN
							x.value := x.value+y.value; x.valueR := x.value;
						ELSIF (x.type = ConstantFloat) & (y.type = ConstantFloat) THEN
							x.valueR := x.valueR + y.valueR;
						ELSE RETURN FALSE
						END;
					ELSE
						IF (x.type IN ConstantIntegerOrOffset) & (y.type IN ConstantIntegerOrOffset) THEN
							x.value := x.value-y.value; x.valueR := x.value;
						ELSIF (x.type = ConstantFloat) & (y.type = ConstantFloat) THEN
							x.valueR := x.valueR - y.valueR;
						ELSE RETURN FALSE
						END;
					END;
				ELSE
					RETURN FALSE;
				END;
			END;
			RETURN TRUE;
		END Expression;

		PROCEDURE Data(CONST ident: ARRAY OF CHAR): BOOLEAN;
		VAR size,i,nr: LONGINT; x: Result; pos: LONGINT; result: Result; patterns: ObjectFile.FixupPatterns;
			PROCEDURE Number(ch: CHAR; VAR nr: LONGINT): BOOLEAN;
			BEGIN
				IF (ch >= "0") & (ch <="9") THEN
					nr := ORD(ch)-ORD("0");
					RETURN TRUE
				ELSE
					RETURN FALSE
				END;
			END Number;

		BEGIN
			size := -1;
			IF (ident = "DB") OR (ident = "db") THEN size := 8
			ELSIF (ident="DW") OR (ident = "dw") THEN size := 16
			ELSIF (ident="DD") OR (ident = "dd") THEN size := 32
			ELSIF (ident="DQ") OR (ident = "dq") THEN size := 64
			ELSIF (CAP(ident[0]) ="D") THEN
				size := 0;i := 1;
				WHILE Number(ident[i],nr) DO
					size := size*10+nr; INC(i);
				END;
				IF ident[i] # 0X THEN size := -1 END;
			END;
			IF size = -1 THEN RETURN FALSE
			ELSE
				IF Trace THEN D.String("Data"); D.Ln; END;
				REPEAT
					pos := errorPosition;
					IF symbol.token = Scanner.String THEN
						IF (pass = MaxPasses) & (code.comments # NIL) THEN
							code.comments.String(ident); section.comments.String(' "');
							code.comments.String(symbol.string^);
							code.comments.String('"');
							code.comments.Ln;
							code.comments.Update
						END;
						i := 0;
						WHILE symbol.string[i] # 0X DO
							PutBitsIfLastPass(ORD(symbol.string[i]),size);
							INC(i);
						END;
						NextSymbol;

					ELSIF (symbol.token = Scanner.Identifier) & GetNonConstant(errorPosition,symbol.identifierString,result) THEN
						IF (pass = MaxPasses) & (code.comments # NIL) THEN
							code.comments.String(ident);
							code.comments.String(" ");
							code.comments.String(symbol.identifierString);
							code.comments.Ln;
							code.comments.Update
						END;

						(* if this is the last pass then enter the fixup to the generated code section *)
						IF pass = MaxPasses THEN
							result.fixup.SetFixupOffset(code.pc);
							code.fixupList.AddFixup(result.fixup);
							(* set fixup width *)
							NEW(patterns, 1);
							patterns[0].offset := 0; patterns[0].bits := size;
							result.fixup.InitFixup(result.fixup.mode, result.fixup.offset, result.fixup.symbol, result.fixup.symbolOffset, result.fixup.displacement, 0, patterns);
						END;

						PutBitsIfLastPass(0,size);
						NextSymbol;

					ELSIF Expression(x,FALSE) THEN
						IF x.type # ConstantInteger THEN Error(pos,"forbidden non-constant value") END;
						IF (pass = MaxPasses) & (code.comments # NIL) THEN
							code.comments.String(ident);
							code.comments.String(" ");
							(* code.comments.Int(x.value,1); *)

							(* print number in hexadecimal form *)
							code.comments.String("0");
							code.comments.Hex(x.value, -size DIV 4);
							code.comments.String("H");

							code.comments.Ln;
							code.comments.Update
						END;

						PutBitsIfLastPass(x.value,size);

					ELSE Error(pos,"expected string or expression");
					END;
				UNTIL error OR ~ThisToken(Scanner.Comma);
			END;
			RETURN TRUE
		END Data;

		PROCEDURE Reserve(CONST ident: ARRAY OF CHAR): BOOLEAN;
		BEGIN RETURN FALSE
		END Reserve;

		(** if the assembler is at the last pass: put bits into the binary code section, otherwise only increment the PC **)
		PROCEDURE PutBitsIfLastPass(data: LONGINT; size: BinaryCode.Bits);
		VAR
			oldPC: LONGINT;
		BEGIN
			IF pass = MaxPasses THEN
				code.PutBits(data, size)
			ELSE
				oldPC := code.pc;
				ASSERT(size MOD code.os.unit = 0);
				code.SetPC(oldPC + size DIV code.os.unit)
			END
		END PutBitsIfLastPass;

		PROCEDURE Instruction*(CONST mnemonic: ARRAY OF CHAR);
		VAR numberOperands: LONGINT;

			PROCEDURE ParseOperand(pos: LONGINT; numberOperand: LONGINT);
			(* stub, must be overwritten by implementation *)
			VAR operand: OperandString;
				result: Result; first: BOOLEAN; str: ARRAY 256 OF CHAR;
			BEGIN
				first := TRUE;
				WHILE ~error & (symbol.token # Scanner.Ln) & (symbol.token # Scanner.Comma) DO
					IF (symbol.token = Scanner.Identifier) & GetNonConstant(errorPosition,symbol.identifierString,result) THEN
							D.String("(* non constant ");
							D.String(symbol.identifierString); D.String("="); DumpResult(D.Log,result);
							D.String("*)");
					ELSIF (symbol.token = Scanner.Identifier) & GetConstant(errorPosition,symbol.identifierString,result) THEN
							D.String("(* constant ");
							DumpResult(D.Log,result);
							D.String("*)");
					END;
					IF first THEN first := FALSE ELSE Strings.Append(operand," ") END;
					Scanner.SymbolToString(symbol, scanner.case, str);
					Strings.Append(operand, str);
					NextSymbol;
				END;
				IF Trace THEN
					D.String("operand= ");
					D.String(operand); IF symbol.token = Scanner.Comma THEN D.String(" , ") END;
				END;
			END ParseOperand;
		BEGIN
			IF Trace THEN
				D.String("Instruction= "); D.String(mnemonic);  D.String(" ");
			END;
			numberOperands := 0;
			IF ~ThisToken(Scanner.Ln) THEN
				REPEAT
					ParseOperand(errorPosition,numberOperands);
					INC(numberOperands);
				UNTIL error OR ~ThisToken(Scanner.Comma);
				IF ~error & ExpectToken(Scanner.Ln) THEN END;
			END;
			IF Trace THEN D.Ln END
		END Instruction;

		PROCEDURE IgnoreNewLines;
		BEGIN
			WHILE ThisToken(Scanner.Ln) DO END;
		END IgnoreNewLines;

		PROCEDURE DoAssemble();
		VAR result: Result; line,pos, orgCodePos: LONGINT; identifier: Scanner.IdentifierString; context: Scanner.Context;
		BEGIN
			IF Trace THEN
				D.Str("DoAssemble: ");
				IF section # NIL THEN Basic.WriteSegmentedName(D.Log,section.name); D.Ln END;
			END;

			NEW(labels);
			NEW(results);

			scanner.GetContext(context);
			NextSymbol;
			IgnoreNewLines;
			WHILE ~error & (symbol.token # Scanner.Period) & (symbol.token # Scanner.EndOfText) DO
				IF ThisToken(Scanner.Number) THEN
					line := symbol.integer;
					IF ThisToken(Scanner.Colon) THEN (* line number *)
					ELSE Error(symbol.start,"Identifier expected");
					END;
				END;
				IF ExpectIdentifier(pos,identifier) THEN
					IF ThisToken(Scanner.Colon) THEN (* label *)
						DefineLabel(pos,identifier)
					ELSIF ThisIdentifier("equ") OR ThisToken(Scanner.Equal) THEN
						IF Expression(result,FALSE) THEN DefineResult(pos,identifier,result) END;
					ELSE scanner.SkipToEndOfLine; NextSymbol;
					END;
				END;
				IgnoreNewLines;
			END;

			orgCodePos := code.pc;
			FOR pass := 1 TO MaxPasses DO
				labels.ResetDisplacements; (* this is important as the displacement is corrected by code emission in a cummulative way *)
				code.SetPC(orgCodePos);
				SetContext(context);
				IgnoreNewLines;
				WHILE ~error & (symbol.token # Scanner.EndOfText) & (symbol.token # Scanner.Period) DO
					IF ThisToken(Scanner.Number) THEN
						line := symbol.integer;
						IF ThisToken(Scanner.Colon) THEN (* line number *)
						ELSE Error(symbol.start,"Identifier expected");
						END;
					END;
					IF ExpectIdentifier(pos,identifier) THEN
						IF ThisToken(Scanner.Colon) THEN (* label *)
							SetLabel(pos,identifier);
						ELSIF ThisIdentifier("equ") OR ThisToken(Scanner.Equal) THEN (* constant definition *)
							IF Expression(result,FALSE) THEN SetResult(identifier,result) END;
						ELSE
							IF identifier = "section" THEN
								Section()
							ELSIF Data(identifier) THEN
							ELSIF Reserve(identifier) THEN
							ELSIF identifier = "fixed" THEN
								IF ExpectConstantInteger(result,TRUE) THEN
									code.SetAlignment(TRUE,result.value)
								END;
							ELSIF ~error THEN
								errorPosition := pos;
								Instruction(identifier);
								(*
								IF ~error & ExpectToken(Scanner.Ln) THEN END;
								*)
							END;
						END;
					END;
					IgnoreNewLines;
				END;
			END;
			IF Trace THEN
				D.Str("END Assemble"); D.Ln;
			END
		END DoAssemble;

		PROCEDURE InlineAssemble*(scanner: Scanner.AssemblerScanner; section: IntermediateCode.Section; scope: SyntaxTree.Scope; module: Sections.Module);
		BEGIN
			ASSERT(module # NIL); ASSERT(scanner # NIL); ASSERT(section # NIL);
			ASSERT(section.resolved # NIL);
			SELF.scope := scope;
			SELF.module := module;
			SELF.scanner := scanner;
			SELF.section := section;
			SELF.code := section.resolved;
			DoAssemble;
		END InlineAssemble;

		PROCEDURE Assemble*(scanner: Scanner.AssemblerScanner);
		BEGIN
			ASSERT(scanner # NIL);
			SELF.scanner := scanner;
			module := NIL; section := NIL; scope := NIL;
			scanner.SetContext(scanner.startContext);
			DoAssemble;
		END Assemble;

		PROCEDURE AllSections*;
		VAR pos: LONGINT; sectionType, sectionName: Scanner.IdentifierString;
		BEGIN
			IF Trace THEN D.String("AllSections"); D.Ln END;
			SetContext(scanner.startContext);
			IgnoreNewLines;
			WHILE ThisToken(Scanner.Period) & ExpectIdentifier(pos,sectionType) & ExpectIdentifier(pos,sectionName) DO
				D.String("section "); D.String(sectionType); D.String(" "); D.String(sectionName); D.Ln;
				DoAssemble;
			END;
		END AllSections;

		PROCEDURE Text*(scanner: Scanner.AssemblerScanner);
		BEGIN
			ASSERT(scanner # NIL);
			SELF.scanner := scanner;
			module := NIL; section := NIL; scope := NIL;
			AllSections;
		END Text;


	END Assembler;

	PROCEDURE DumpResult*(w: Streams.Writer; result: Result);
	BEGIN
		CASE result.type OF
			ConstantInteger: w.String("i"); w.Int(result.sizeInBits,1);w.String(" ");w.Int(result.value,1);
			|ConstantFloat: w.String("f");w.Int(result.sizeInBits,1);w.String(" ");w.Float(result.value,20);
			|Offset: w.String("ofs "); w.Int(result.value,1);
			|Fixup: w.String("i"); w.Int(result.sizeInBits,1);w.String(" "); w.String("fixup ");
				result.fixup.Dump(w);
		END;
	END DumpResult;

	PROCEDURE Test*(context: Commands.Context);
	VAR scanner: Scanner.AssemblerScanner;  diagnostics: Diagnostics.StreamDiagnostics; assembler: Assembler;
	BEGIN
		NEW(diagnostics,context.out);
		NEW(scanner,"command",context.arg,0,diagnostics);
		NEW(assembler,diagnostics);
		assembler.Text(scanner);
		(*
		assembler.Assemble(scanner);
		*)
	END Test;

	PROCEDURE TestScanner*(context: Commands.Context);
	VAR scanner: Scanner.AssemblerScanner;  diagnostics: Diagnostics.StreamDiagnostics; symbol: Scanner.Symbol;
	BEGIN
		NEW(diagnostics,context.out);
		NEW(scanner,"command",context.arg,0,diagnostics);
		WHILE scanner.GetNextSymbol(symbol) & (symbol.token # Scanner.EndOfText)  DO
			Scanner.OutSymbol(context.out, symbol); context.out.Ln;
		END;
	END TestScanner;

END FoxAssembler.

SystemTools.Free FoxAssembler ~


FoxAssembler.Test
;---------------- intermediate code -----------------
.module BitSets

.imports SYSTEM

.const BitSets.@moduleSelf offset=0
	 0: data u32 0

.const BitSets.BitSet offset=0
	 0: data u32 0

.code BitSets.BitSet.InitBitSet offset=0
	 0: enter  0,  0
	 1: mov u32 r1, u32 [fp+8]
	 2: mov s32 [r1], s32 [fp+12]
	 3: push s32 [fp+12]
	 4: mov u32 r2, u32 [fp+8]
	 5: add u32 r3, u32 [r2-4], u32 -88
	 6: push u32 r2
	 7: call u32 [r3],  8
	 8: leave  0
	 9: exit  8

.code BitSets.BitSet.Zero offset=0
	 0: enter  0,  8
	 1: mov s32 [fp-4], s32 0
	 2: mov u32 r1, u32 [fp+8]
	 3: mov u32 r2, u32 [r1+4]
	 4: conv s32 r3, u32 [r2+12]
	 5: sub s32 r3, s32 r3, s32 1
	 6: mov s32 [fp-8], s32 r3
	 7: brlt u32 BitSets.BitSet.Zero:21, s32 [fp-8], s32 [fp-4]
	 8: br u32 BitSets.BitSet.Zero:9
	 9: conv u32 r4, s32 [fp-4]
	10: mov u32 r5, u32 r4
	11: mov u32 r6, u32 [fp+8]
	12: mov u32 r7, u32 [r6+4]
	13: brlt u32 BitSets.BitSet.Zero:15, u32 r4, u32 [r7+12]
	14: trap  7
	15: mul u32 r5, u32 r5, u32 4
	16: add u32 r5, u32 r5, u32 r7+16
	17: mov u32 [r5], u32 0
	18: add s32 r8, s32 [fp-4], s32 1
	19: mov s32 [fp-4], s32 r8
	20: br u32 BitSets.BitSet.Zero:7
	21: leave  0
	22: exit  4

.code BitSets.BitSet.Resize offset=0
	 0: enter  0,  12
	 1: brlt u32 BitSets.BitSet.Resize:3, s32 [fp+12], s32 0
	 2: br u32 BitSets.BitSet.Resize:4
	 3: trap  8
	 4: mov u32 r1, u32 [fp+8]
	 5: mov s32 [r1], s32 [fp+12]
	 6: sub s32 r2, s32 [fp+12], s32 1
	 7: brlt u32 BitSets.BitSet.Resize:10, s32 r2, s32 0
	 8: mov s32 r2, s32 r2
	 9: br u32 BitSets.BitSet.Resize:11
	10: mov s32 r2, s32 0, s32 r2
	11: shr s32 r2, s32 r2, s32 5
	12: add s32 r2, s32 r2, s32 1
	13: mov s32 [fp+12], s32 r2
	14: mov u32 r3, u32 [fp+8]
	15: breq u32 BitSets.BitSet.Resize:35, u32 [r3+4], u32 0
	16: br u32 BitSets.BitSet.Resize:17
	17: mov u32 r4, u32 [fp+8]
	18: mov u32 r5, u32 [r4+4]
	19: conv s32 r6, u32 [r5+12]
	20: brlt u32 BitSets.BitSet.Resize:25, s32 r6, s32 [fp+12]
	21: br u32 BitSets.BitSet.Resize:22
	22: leave  0
	23: exit  8
	24: br u32 BitSets.BitSet.Resize:25
	25: mov u32 r7, u32 [fp+8]
	26: mov u32 r8, u32 [r7+4]
	27: conv s32 r9, u32 [r8+12]
	28: shl s32 r9, s32 r9, s32 1
	29: brlt u32 BitSets.BitSet.Resize:32, s32 [fp+12], s32 r9
	30: mov s32 r9, s32 [fp+12]
	31: br u32 BitSets.BitSet.Resize:33
	32: mov s32 r9, s32 r9, s32 r9
	33: mov s32 [fp+12], s32 r9
	34: br u32 BitSets.BitSet.Resize:35
	35: brge u32 BitSets.BitSet.Resize:37, s32 [fp+12], s32 0
	36: trap  9
	37: push s32 [fp+12]
	38: mov s32 r10, s32 [fp+12]
	39: conv u32 r10, s32 r10
	40: mul u32 r10, u32 r10, u32 4
	41: add u32 r10, u32 r10, u32 16
	42: push u32 fp-4
	43: push u32 fp-4
	44: push u32 r10
	45: push u8 0
	46: call u32 $SystemCall2:0,  0
	47: pop u32 r11
	48: mov u32 r12, u32 [r11]
	49: breq u32 BitSets.BitSet.Resize:53, u32 r12, u32 0
	50: pop u32 r13
	51: mov u32 [r12+12], u32 r13
	52: br u32 BitSets.BitSet.Resize:54
	53: add u32 sp, u32 sp, u32 4
	54: mov u32 r14, u32 [fp+8]
	55: breq u32 BitSets.BitSet.Resize:85, u32 [r14+4], u32 0
	56: br u32 BitSets.BitSet.Resize:57
	57: mov s32 [fp-8], s32 0
	58: mov u32 r15, u32 [fp+8]
	59: mov u32 r16, u32 [r15+4]
	60: conv s32 r17, u32 [r16+12]
	61: sub s32 r17, s32 r17, s32 1
	62: mov s32 [fp-12], s32 r17
	63: brlt u32 BitSets.BitSet.Resize:84, s32 [fp-12], s32 [fp-8]
	64: br u32 BitSets.BitSet.Resize:65
	65: conv u32 r18, s32 [fp-8]
	66: mov u32 r19, u32 r18
	67: mov u32 r20, u32 [fp+8]
	68: mov u32 r21, u32 [r20+4]
	69: brlt u32 BitSets.BitSet.Resize:71, u32 r18, u32 [r21+12]
	70: trap  7
	71: mul u32 r19, u32 r19, u32 4
	72: add u32 r19, u32 r19, u32 r21+16
	73: conv u32 r22, s32 [fp-8]
	74: mov u32 r23, u32 r22
	75: mov u32 r24, u32 [fp-4]
	76: brlt u32 BitSets.BitSet.Resize:78, u32 r22, u32 [r24+12]
	77: trap  7
	78: mul u32 r23, u32 r23, u32 4
	79: add u32 r23, u32 r23, u32 r24+16
	80: mov u32 [r23], u32 [r19]
	81: add s32 r25, s32 [fp-8], s32 1
	82: mov s32 [fp-8], s32 r25
	83: br u32 BitSets.BitSet.Resize:63
	84: br u32 BitSets.BitSet.Resize:85
	85: mov u32 r26, u32 [fp+8]
	86: mov u32 [r26+4], u32 [fp-4]
	87: leave  0
	88: exit  8

.code BitSets.BitSet.GetSize offset=0
	 0: enter  0,  0
	 1: mov u32 r1, u32 [fp+8]
	 2: return s32 [r1]
	 3: leave  0
	 4: exit  4
	 5: trap  3
