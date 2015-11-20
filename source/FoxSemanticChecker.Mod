
MODULE FoxSemanticChecker; (* AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Semantic Checker"; *)
(* (c) fof ETHZ 2009 *)

IMPORT D := Debugging, Basic := FoxBasic, Scanner := FoxScanner, SyntaxTree := FoxSyntaxTree, Parser := FoxParser,
Diagnostics, Global := FoxGlobal, Printout:= FoxPrintout, Formats := FoxFormats, SYSTEM, Streams, Strings;

CONST
	Trace = FALSE;

	Infinity = MAX(LONGINT); (* for type distance *)
	InvalidPosition* = Diagnostics.Invalid;
	MaxTensorIndexOperatorSize = 4;
	UndefinedPhase = 0; DeclarationPhase=1; InlinePhase=2; ImplementationPhase=3;

TYPE
	FileName=ARRAY 256 OF CHAR;

	LateFix= POINTER TO RECORD (* contains a late fix to be resolved in a later step: type fixes and implementations *)
		p: ANY; scope: SyntaxTree.Scope;
		next: LateFix;
	END;

	LateFixList = OBJECT (* fifo queue for items to be resolved later on - deferred fixes *)
	VAR first,last: LateFix;

		PROCEDURE & Init;
		BEGIN first := NIL; last := NIL;
		END Init;

		(* get and remove element from list *)
		PROCEDURE Get(VAR scope: SyntaxTree.Scope): ANY;
		VAR p: ANY;
		BEGIN
			IF first # NIL THEN p := first.p; scope := first.scope; first := first.next ELSE p := NIL; END;
			IF first = NIL THEN last := NIL END;
			RETURN p;
		END Get;

		(* add unresolved type to list *)
		PROCEDURE Add(p: ANY; scope: SyntaxTree.Scope);
		VAR next: LateFix;
		BEGIN
			ASSERT(scope # NIL);
			NEW(next); next.p := p; next.scope := scope;
			next.next := NIL;
			IF first = NIL THEN first := next; last := next;
			ELSE last.next := next; last := next
			END;
		END Add;

	END LateFixList;

	WithEntry = POINTER TO RECORD
		previous: WithEntry;
		symbol: SyntaxTree.Symbol;
		type: SyntaxTree.Type;
	END;

	Replacement*= POINTER TO RECORD
		name*: Basic.SegmentedName;
		expression*: SyntaxTree.Expression;
		used*: BOOLEAN;
		next*: Replacement;
	END;

	(** checker object: used to check and resolve a module
		- resolves types
		- resolves expressions
		- resolves designators
		- resolves declarations
		- resolves statements
		- resolves implementations (bodies)
	**)
	Checker*= OBJECT (SyntaxTree.Visitor)
	VAR
		module: SyntaxTree.Module;
		diagnostics: Diagnostics.Diagnostics;
		useDarwinCCalls: BOOLEAN;
		cooperative: BOOLEAN;
		error-: BOOLEAN;
		VerboseErrorMessage: BOOLEAN;
		typeFixes, pointerFixes: LateFixList;
		importCache-: SyntaxTree.ModuleScope; (* contains global imports, did not take ImportList as it was much slower, for whatever reasons *)
		arrayBaseImported: BOOLEAN;
		phase: LONGINT;
		system-: Global.System;
		symbolFileFormat-: Formats.SymbolFileFormat;

		(* temporary variables for the visitors
		    they replace variables on a stack during use of the visitor pattern and may only be
			- set in AcceptXXX procedures
			- set and read in ResolveXXX procedures
		*)
		resolvedType: SyntaxTree.Type; (** temporary used for type resolution **)
		resolvedExpression: SyntaxTree.Expression; (** temporary variable used for expression resolution **)
		resolvedStatement: SyntaxTree.Statement; (** used for statement resolution **)
		currentScope-: SyntaxTree.Scope;
		currentIsRealtime: BOOLEAN;
		currentIsUnreachable: BOOLEAN;
		currentIsCellNet: BOOLEAN;
		currentIsBodyProcedure: BOOLEAN;
		currentIsExclusive: BOOLEAN;
		global: SyntaxTree.ModuleScope;
		withEntries: WithEntry;
		activeCellsStatement: BOOLEAN;
		replacements*: Replacement;
		cellsAreObjects: BOOLEAN;
		variableAccessed: BOOLEAN;

		PROCEDURE &InitChecker*(diagnostics: Diagnostics.Diagnostics; verboseErrorMessage,useDarwinCCalls,cooperative: BOOLEAN; system: Global.System; symbolFileFormat: Formats.SymbolFileFormat; VAR importCache: SyntaxTree.ModuleScope);
		BEGIN
			SELF.diagnostics := diagnostics;
			SELF.useDarwinCCalls := useDarwinCCalls;
			SELF.cooperative := cooperative;
			SELF.system := system;
			SELF.symbolFileFormat := symbolFileFormat;
			error := FALSE;
			NEW(typeFixes);
			NEW(pointerFixes);
			resolvedType := NIL;
			resolvedExpression := NIL;
			resolvedStatement := NIL;
			currentScope := NIL;
			IF importCache = NIL THEN importCache := SyntaxTree.NewModuleScope() END;
			SELF.importCache := importCache;
			arrayBaseImported := FALSE;
			SELF.VerboseErrorMessage := verboseErrorMessage;
			global := NIL;
			phase := UndefinedPhase;
			currentIsRealtime := FALSE;
			currentIsUnreachable := FALSE;
			currentIsCellNet := FALSE;
			currentIsBodyProcedure := FALSE;
			currentIsExclusive := FALSE;
			withEntries := NIL;
			SELF.cellsAreObjects := system.cellsAreObjects;
		END InitChecker;

		(** report error **)
		PROCEDURE Error(position: LONGINT; code: LONGINT; CONST message: ARRAY OF CHAR);
		VAR errorMessage: ARRAY 256 OF CHAR; errModule: SyntaxTree.Module;
		BEGIN
			IF diagnostics # NIL THEN
				Basic.GetErrorMessage(code,message,errorMessage);
				ASSERT(currentScope # NIL);
				IF module # NIL THEN errModule := module ELSE errModule := currentScope.ownerModule END;
				diagnostics.Error(errModule.sourceName, position, code, errorMessage);
			END;
			error := TRUE;
		END Error;

		PROCEDURE Warning(position: LONGINT; CONST message: ARRAY OF CHAR);
		VAR errModule: SyntaxTree.Module;
		BEGIN
			IF diagnostics # NIL THEN
				IF module # NIL THEN errModule := module ELSE errModule := currentScope.ownerModule END;
				diagnostics.Warning(errModule.sourceName, position, Diagnostics.Invalid, message);
			END;
		END Warning;


		PROCEDURE ErrorSS(position: LONGINT; CONST msg,msg2: ARRAY OF CHAR);
		VAR errorMessage: ARRAY 256 OF CHAR;
		BEGIN
			IF diagnostics # NIL THEN
				Basic.Concat(errorMessage,msg," ", msg2);
				diagnostics.Error(currentScope.ownerModule.sourceName, position, Diagnostics.Invalid, errorMessage);
			END;
			error := TRUE;
		END ErrorSS;

		PROCEDURE InfoSS(position: LONGINT; CONST msg1: ARRAY OF CHAR; CONST s: Basic.String);
		VAR msg, msg2: ARRAY 256 OF CHAR;
		BEGIN
			IF diagnostics # NIL THEN
				COPY(msg1, msg);
				Strings.Append(msg, " = ");
				Basic.GetString(s, msg2);
				Strings.Append(msg, msg2);
				diagnostics.Information(currentScope.ownerModule.sourceName, position, Diagnostics.Invalid, msg);
			END;
		END InfoSS;


		(*** symbol lookup ***)

		(** find a symbol in the current scope, traverse to outer scope if traverse=true and no symbol found yet
		**)
		PROCEDURE Find(inScope: SyntaxTree.Scope; name: SyntaxTree.Identifier; traverse: BOOLEAN): SyntaxTree.Symbol;
		VAR
			scope,baseScope: SyntaxTree.Scope;
			symbol, s: SyntaxTree.Symbol;
			ownerRecord,base: SyntaxTree.RecordType;
		BEGIN
			scope := inScope;
			symbol := NIL;

			WHILE (scope # NIL) & (symbol = NIL) DO
				symbol := scope.FindSymbol(name);
				s := NIL;
				IF (symbol # NIL) & (symbol.access * SyntaxTree.Public = {}) & (symbol.scope IS SyntaxTree.CellScope) (* hidden copies of parameters *) THEN
					s := symbol.scope(SyntaxTree.CellScope).ownerCell.FindParameter(name);
				END;

				IF (symbol # NIL) & (symbol IS SyntaxTree.Parameter) & (symbol.scope IS SyntaxTree.CellScope) THEN (* ok, symbol auto-export in scope *)
				ELSIF s # NIL THEN (* hidden variable shadows port parameter *)
				ELSE
					WHILE (symbol # NIL) & (symbol.scope.ownerModule # currentScope.ownerModule) & (symbol.access * SyntaxTree.Public = {}) DO
						(* found symbol in different module, but is it not exported, can we go on searching in record base scopes ? *)
						symbol.MarkUsed;
						IF (symbol.scope IS SyntaxTree.RecordScope) THEN
							ownerRecord := symbol.scope(SyntaxTree.RecordScope).ownerRecord;
							base := RecordBase(ownerRecord);
							IF (base # NIL) THEN
								baseScope := base.recordScope;
								symbol := Find(baseScope,name,FALSE);
							ELSE
								symbol := NIL;
							END;
						ELSE
							symbol := NIL;
						END;
					END;
				END;
				IF traverse THEN scope := scope.outerScope ELSE scope := NIL END;
			END;
			IF (symbol # NIL) THEN
				IF ~(SyntaxTree.Resolved IN symbol.state) THEN
					ASSERT(phase = DeclarationPhase);
					ResolveSymbol(symbol)
				END;
				symbol.MarkUsed;
			END;
			RETURN symbol
		END Find;

		(*** types ***)

		(** find type declaration with name qualifiedIdentifier and return resolved type
			- check qualified identifier prefix, set scope to module scope if appropriate
			- check suffix in scope
		**)
		PROCEDURE ResolveNamedType(qualifiedIdentifier: SyntaxTree.QualifiedIdentifier; VAR typeDeclaration: SyntaxTree.TypeDeclaration): SyntaxTree.Type;
		VAR prevScope: SyntaxTree.Scope; symbol: SyntaxTree.Symbol; result:SyntaxTree.Type;
		BEGIN
			result := NIL;
			prevScope := currentScope;
			IF (qualifiedIdentifier.prefix # SyntaxTree.invalidIdentifier) THEN
				symbol := Find(currentScope,qualifiedIdentifier.prefix,TRUE);
				IF (symbol # NIL) & (symbol IS SyntaxTree.Import) THEN
					IF symbol(SyntaxTree.Import).module = NIL THEN
						Error(qualifiedIdentifier.position,Diagnostics.Invalid,"module not loaded");
						result := SyntaxTree.invalidType;
						symbol := NIL;
					ELSE
						currentScope := symbol(SyntaxTree.Import).module.moduleScope;
						symbol := Find(currentScope,qualifiedIdentifier.suffix,FALSE);
						
						IF (symbol = NIL) OR (symbol.access * SyntaxTree.Public = {}) THEN 
							IF VerboseErrorMessage THEN
								Printout.Info("scope", currentScope);
								Printout.Info("symbol", symbol);
							END;
							Error(qualifiedIdentifier.position,Diagnostics.Invalid,"undeclared identifier (prefix-suffix)") 
						END;
					END;
				ELSE
					D.Str0(qualifiedIdentifier.prefix);D.Ln;
					Error(qualifiedIdentifier.position,Diagnostics.Invalid,"prefix does not denote a module name");
					symbol := NIL;
				END;
			ELSE
				symbol := Find(currentScope,qualifiedIdentifier.suffix,TRUE);
				IF symbol = NIL THEN
					Error(qualifiedIdentifier.position,Diagnostics.Invalid,"undeclared identifier (qualident suffix)");
					IF VerboseErrorMessage THEN
						Printout.Info("Qualident",qualifiedIdentifier);
						Printout.Info("in scope",currentScope) ;
					END;
				END;
			END;

			IF symbol = NIL THEN (* error already handled *)
				typeDeclaration := NIL;
				result := SyntaxTree.invalidType;
			ELSIF ~(symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(qualifiedIdentifier.position,Diagnostics.Invalid,"symbol does not denote a type");
				typeDeclaration := NIL;
				result := SyntaxTree.invalidType;
			ELSE
				currentScope := symbol.scope;
				typeDeclaration := symbol(SyntaxTree.TypeDeclaration);
				result := ResolveType(typeDeclaration.declaredType);
				symbol.MarkUsed;
				ASSERT(result # NIL);
			END;
			currentScope := prevScope;


			RETURN result
		END ResolveNamedType;

		(** Check if a node has already been resolved. If not then mark as currently being resolved.
			If node is currently being resolved then emit a cyclic definition error.
			Return TRUE only if node is fully resolved.
		**)
		PROCEDURE TypeNeedsResolution(x: SyntaxTree.Type): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			IF SyntaxTree.Resolved IN x.state THEN
				result := FALSE
			ELSIF SyntaxTree.BeingResolved IN x.state THEN
				Error(x.position,Diagnostics.Invalid,"cyclic definition");
				result := FALSE;
			ELSE
				result := TRUE;
				x.SetState(SyntaxTree.BeingResolved)
			END;
			RETURN result
		END TypeNeedsResolution;

		(** Return invalid type if x is currently being resolved, return x otherwise**)
		PROCEDURE ResolvedType(x: SyntaxTree.Type): SyntaxTree.Type;
		BEGIN
			IF SyntaxTree.Resolved IN x.state THEN
				RETURN x
			ELSE
				RETURN SyntaxTree.invalidType
			END;
		END ResolvedType;

		PROCEDURE VisitType(x: SyntaxTree.Type);
		BEGIN
			ASSERT(x = SyntaxTree.invalidType);
		END VisitType;

		(** resolve basic type **)
		PROCEDURE VisitBasicType(x: SyntaxTree.BasicType);
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x)
		END VisitBasicType;

		PROCEDURE VisitByteType(x: SyntaxTree.ByteType);
		BEGIN
			VisitBasicType(x);
		END VisitByteType;

		(** resolve character type **)
		PROCEDURE VisitCharacterType(x: SyntaxTree.CharacterType);
		BEGIN
			VisitBasicType(x);
		END VisitCharacterType;

		PROCEDURE VisitBooleanType(x: SyntaxTree.BooleanType);
		BEGIN
			VisitBasicType(x);
		END VisitBooleanType;

		PROCEDURE VisitSetType(x: SyntaxTree.SetType);
		BEGIN
			VisitBasicType(x);
		END VisitSetType;

		PROCEDURE VisitAddressType(x: SyntaxTree.AddressType);
		BEGIN
			VisitBasicType(x);
		END VisitAddressType;

		PROCEDURE VisitSizeType(x: SyntaxTree.SizeType);
		BEGIN
			VisitBasicType(x);
		END VisitSizeType;

		PROCEDURE VisitAnyType(x: SyntaxTree.AnyType);
		BEGIN
			VisitBasicType(x);
		END VisitAnyType;

		PROCEDURE VisitObjectType(x: SyntaxTree.ObjectType);
		BEGIN
			VisitBasicType(x);
		END VisitObjectType;

		PROCEDURE VisitNilType(x: SyntaxTree.NilType);
		BEGIN
			VisitBasicType(x);
		END VisitNilType;

		(** resolve integer type **)
		PROCEDURE VisitIntegerType(x: SyntaxTree.IntegerType);
		BEGIN
			VisitBasicType(x);
		END VisitIntegerType;

		(** resolve real type **)
		PROCEDURE VisitFloatType(x: SyntaxTree.FloatType);
		BEGIN
			VisitBasicType(x);
		END VisitFloatType;

		(** resolve complex type **)
		PROCEDURE VisitComplexType(x: SyntaxTree.ComplexType);
		BEGIN
			VisitBasicType(x);
		END VisitComplexType;

		(**
			resolve string type: nothing to be done
		**)
		PROCEDURE VisitStringType(x: SyntaxTree.StringType);
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x)
		END VisitStringType;

		(**
			check enumeration scope: enter symbols and check for duplicate names
		**)
		PROCEDURE CheckEnumerationScope(x: SyntaxTree.EnumerationScope; VAR highest: LONGINT);
		VAR e: SyntaxTree.Constant; value: SyntaxTree.Expression; nextHighest: LONGINT; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			e := x.firstConstant;
			WHILE (e # NIL) DO
				Register(e,x,FALSE);
				IF SymbolNeedsResolution(e) THEN
					IF e.value # NIL THEN
						value := ConstantExpression(e.value);
						value := NewConversion(e.position,value,x.ownerEnumeration,NIL);
					ELSE
						value := SyntaxTree.NewEnumerationValue(e.position,highest+1);
						value.SetType(x.ownerEnumeration);
					END;
					IF (value.resolved # NIL) & (value.resolved IS SyntaxTree.EnumerationValue) THEN
						nextHighest := value.resolved(SyntaxTree.EnumerationValue).value;
						IF nextHighest > highest THEN highest := nextHighest END;
					END;
					e.SetValue(value);
					CheckSymbolVisibility(e);
					e.SetType(x.ownerEnumeration);
					e.SetState(SyntaxTree.Resolved);
				END;
				e := e.nextConstant;
			END;
			currentScope := prevScope;
		END CheckEnumerationScope;

		(**
			resolve enumeration type: check enumeration scope
		**)
		PROCEDURE VisitEnumerationType(x: SyntaxTree.EnumerationType);
		VAR position: LONGINT; baseScope: SyntaxTree.EnumerationScope; baseType,resolved: SyntaxTree.Type; enumerationBase: SyntaxTree.EnumerationType;
			lowest, highest: LONGINT;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				IF x.enumerationBase # NIL THEN
					position := x.enumerationBase.position;
					baseType := ResolveType(x.enumerationBase);
					resolved := baseType.resolved;
					baseScope := NIL;
					IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
					ELSIF ~(resolved IS SyntaxTree.EnumerationType) THEN
						Error(position,Diagnostics.Invalid,"base type is no enumeration type");
					ELSE
						enumerationBase := resolved(SyntaxTree.EnumerationType);
						lowest := enumerationBase.rangeHighest+1;
					END;
					x.SetEnumerationBase(baseType);
				ELSE lowest := 0;
				END;
				highest := lowest-1;
				CheckEnumerationScope(x.enumerationScope, highest);
				x.SetRange(lowest, highest);
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x);
		END VisitEnumerationType;

		(**
			resolve range type: nothing to be done
		**)
		PROCEDURE VisitRangeType(x: SyntaxTree.RangeType);
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x)
		END VisitRangeType;

		(**
			resolve qualified type
			- find and resolve named type and set resolved type
		**)
		PROCEDURE VisitQualifiedType(x: SyntaxTree.QualifiedType);
		VAR type: SyntaxTree.Type; typeDeclaration: SyntaxTree.TypeDeclaration;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				type := ResolveNamedType(x.qualifiedIdentifier, typeDeclaration);
				x.SetResolved(type.resolved);
				x.SetState(SyntaxTree.Resolved);
				x.SetTypeDeclaration (typeDeclaration);
			ELSIF ~(SyntaxTree.Resolved IN x.state) THEN
				x.SetResolved(SyntaxTree.invalidType);
			END;
			resolvedType := x;
		END VisitQualifiedType;

		(**
			resolve array type
			- check base type
				- array of math array  forbidden
				- static array of open array forbidden
		**)
		PROCEDURE VisitArrayType(x: SyntaxTree.ArrayType);
		VAR arrayBase: SyntaxTree.Type; e: SyntaxTree.Expression; pointerType: SyntaxTree.PointerType;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetArrayBase(ResolveType(x.arrayBase));
				IF x.arrayBase.resolved.isRealtime THEN x.SetRealtime(TRUE) END;
				arrayBase := x.arrayBase.resolved;
				IF (arrayBase IS SyntaxTree.CellType) (*& (cellsAreObjects)*) THEN
					pointerType := SyntaxTree.NewPointerType(x.position, x.scope);
					pointerType.SetPointerBase(arrayBase);
					pointerType.SetHidden(TRUE);
					x.SetArrayBase(pointerType);
				END;
				IF x.length # NIL THEN
				
					variableAccessed := FALSE;
					e := ResolveExpression(x.length);
			
					IF (e.resolved = NIL) THEN
						IF variableAccessed THEN
							Error(e.position, Diagnostics.Invalid, "forbidden variable access");
						END;
						x.SetLength(e); x.SetForm(SyntaxTree.SemiDynamic);
					ELSE
						x.SetLength(ConstantIntegerGeq0(e (*x.length*)));
					END;
				END;

				IF arrayBase IS SyntaxTree.ArrayType THEN
					IF (x.form = SyntaxTree.Static) & (arrayBase(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
						Error(x.position,Diagnostics.Invalid,"forbidden static array of dynamic array");
					END;
				ELSIF arrayBase IS SyntaxTree.MathArrayType THEN
					Error(x.position,Diagnostics.Invalid,"forbidden array mixed form");
				END;
				x.SetHasPointers(arrayBase.hasPointers);
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x);
		END VisitArrayType;

		PROCEDURE ImportModule(name: SyntaxTree.Identifier; position: LONGINT);
		VAR module: SyntaxTree.Module; import, duplicate: SyntaxTree.Import; moduleScope: SyntaxTree.ModuleScope;
		BEGIN
			module := currentScope.ownerModule;
			IF module.name=name THEN
				(* do nothing *)
			ELSE
				moduleScope := module.moduleScope;
				import := moduleScope.FindImport(name);
				IF import = NIL THEN
					import := SyntaxTree.NewImport(position,name,name,TRUE);
					moduleScope.AddImport(import);
					Register(import,moduleScope,FALSE);
					IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(SELF.module.context) END;
					VisitImport(import);
				ELSIF import.direct=FALSE THEN
					import.SetScope(module.moduleScope);
					import.SetDirect(TRUE);
					IF moduleScope.FindSymbol(import.name) = NIL THEN
						duplicate := SyntaxTree.NewImport(InvalidPosition,import.name, import.name,FALSE);
						duplicate.SetContext(import.context);
						duplicate.SetModule(import.module);
						Register(duplicate,moduleScope,TRUE);
						VisitImport(duplicate);
					END;
				END;
				import.MarkUsed
			END;
		END ImportModule;

		(**
			resolve math array type
			- check base type
				- open math array of array  forbidden
				- math array of tensor forbidden
				- static array of open array forbidden
		**)
		PROCEDURE VisitMathArrayType(x: SyntaxTree.MathArrayType);
		VAR arrayBase: SyntaxTree.Type;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetArrayBase(ResolveType(x.arrayBase));
				IF x.length # NIL THEN
					x.SetLength(ConstantIntegerGeq0(x.length));
				END;
				arrayBase := x.arrayBase;
				IF arrayBase # NIL THEN
					arrayBase := arrayBase.resolved;
					IF arrayBase = SyntaxTree.invalidType THEN
						(* error already handled *)
					ELSIF arrayBase IS SyntaxTree.ArrayType THEN
						Error(x.position,Diagnostics.Invalid,"forbidden array mixed form");
					ELSIF arrayBase IS SyntaxTree.MathArrayType THEN
						IF (x.form = SyntaxTree.Tensor) OR (arrayBase(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) THEN
							Error(x.position,Diagnostics.Invalid,"forbidden Tensor Array mix")
						ELSIF (x.form=SyntaxTree.Static) & (arrayBase(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
							Error(x.position,Diagnostics.Invalid,"forbidden static array of dynamic array")
						END;
					END;
					IF x.form = SyntaxTree.Static THEN
						x.SetIncrement(system.SizeOf(arrayBase));
					END;
					x.SetHasPointers((x.form # SyntaxTree.Static) OR arrayBase.hasPointers);
				END;
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x);
		END VisitMathArrayType;

		(* anonymous type declarations are used for variables that use an anonymous type. They are not used for records that are
			pointed to by a pointer to record. The following diagram shows the possible cases for records and pointer to records.

			(1) Rec = RECORD ... END;					Ptr		<--->		Rec
				Ptr = POINTER TO Rec;						^				 |
																|				 |
															TypeDesc			TypeDesc


			(2)	Obj = POINTER TO RECORD .. END;		Obj		<--->		Record
																^				/
																|			   /
															TypeDesc	<-- /
		*)

		PROCEDURE AnonymousTypeDeclaration(x: SyntaxTree.Type; CONST prefix: ARRAY OF CHAR);
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; name,number: Scanner.IdentifierString;
		BEGIN
			Strings.IntToStr(x.position,number);
			COPY(prefix,name);
			Strings.Append(name,"@");
			Strings.Append(name,number);
			typeDeclaration := SyntaxTree.NewTypeDeclaration(x.position,SyntaxTree.NewIdentifier(name));
			typeDeclaration.SetDeclaredType(x);
			typeDeclaration.SetAccess(SyntaxTree.Hidden);
			x.SetTypeDeclaration(typeDeclaration);
			currentScope.AddTypeDeclaration(typeDeclaration);
			typeDeclaration.SetScope(currentScope);
		END AnonymousTypeDeclaration;


		(**
			deferred pointer type resolving
			- resolve base type
			- check that base type is a record or array type
			- if error then set base type to invalid type
		**)
		PROCEDURE FixPointerType(type: SyntaxTree.PointerType);
		VAR resolved, base: SyntaxTree.Type; position: LONGINT; recordType: SyntaxTree.RecordType;
		BEGIN
			ASSERT(type.pointerBase # NIL);
			position := type.pointerBase.position;
			IF (type.pointerBase IS SyntaxTree.RecordType) THEN (* direct POINTER TO RECORD *)
				type.pointerBase(SyntaxTree.RecordType).SetPointerType(type);
				(* not for pointers, a type is needed for the records only
				IF type.typeDeclaration = NIL THEN
					AnonymousTypeDeclaration(type);
				END;
				*)
			END;
			resolved := ResolveType(type.pointerBase);
			IF (resolved.resolved IS SyntaxTree.RecordType) OR (resolved.resolved IS SyntaxTree.ArrayType) OR (resolved.resolved IS SyntaxTree.CellType) THEN
				type.SetPointerBase(resolved);
				IF (resolved.resolved IS SyntaxTree.RecordType) THEN
					recordType := resolved.resolved(SyntaxTree.RecordType);
					IF recordType.isObject & (recordType.baseType # NIL) THEN
						IF type.isRealtime & ~recordType.baseType.resolved.isRealtime THEN
							Error(position,Diagnostics.Invalid,"base type of object must be a realtime object");
						ELSIF ~type.isRealtime & recordType.baseType.resolved.isRealtime THEN
							Error(position,Diagnostics.Invalid,"extensions of realtime objects must be explicitly declared as realtime objects");
						END;
					END;
				END;
				IF type.isRealtime & ~resolved.resolved.isRealtime THEN
					Error(position,Diagnostics.Invalid,"realtime object contains references to non-realtime objects");
				END;
				IF type.isUnsafe & (resolved.resolved IS SyntaxTree.ArrayType) THEN
					(*IF ~IsOpenArray(resolved.resolved, base) THEN 
						Error(position,Diagnostics.Invalid,"forbidden unsafe at static array");
					ELS
					*)
					IF IsOpenArray(resolved.resolved(SyntaxTree.ArrayType).arrayBase, base) THEN
						Error(position,Diagnostics.Invalid,"forbidden unsafe at multidimensional array");
					END;
				END;
			ELSE
				Error(position,Diagnostics.Invalid,"forbidden pointer base type");
				type.SetPointerBase(SyntaxTree.invalidType)
			END
		END FixPointerType;

		(**
			resolve pointer type
			- enter pointer type to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE VisitPointerType(x: SyntaxTree.PointerType);
		VAR recordType: SyntaxTree.RecordType; recordBaseType: SyntaxTree.Type;
		modifiers: SyntaxTree.Modifier; position: LONGINT;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				modifiers := x.modifiers;
				x.SetRealtime(HasFlag(modifiers,Global.NameRealtime, position));
				x.SetPlain(HasFlag(modifiers,Global.NamePlain,position));
				x.SetDisposable(HasFlag(modifiers,Global.NameDisposable, position));
				x.SetUnsafe(HasFlag(modifiers,Global.NameUnsafe,position));
				(* inheritance cycle check
					example:
					A=POINTER TO RECORD(B) END;
					B=POINTER TO RECORD(A) END;
				*)
				IF x.pointerBase IS SyntaxTree.RecordType THEN
					recordType := x.pointerBase(SyntaxTree.RecordType);
					recordBaseType := ResolveType(recordType.baseType);
					recordType.SetBaseType(recordBaseType);
					recordType.SetProtected(HasFlag(modifiers, Global.NameExclusive, position));
				END;
				CheckModifiers(modifiers, TRUE);
				typeFixes.Add(x,currentScope);
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x)
		END VisitPointerType;

		(**
			resolve port type
			- enter port type to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE VisitPortType(x: SyntaxTree.PortType);
		VAR value: LONGINT;
		BEGIN
			IF TypeNeedsResolution(x) THEN
				x.SetSizeExpression(ResolveExpression(x.sizeExpression));
				IF (x.sizeExpression # NIL) & CheckPositiveIntegerValue(x.sizeExpression,value,FALSE) THEN
					x.SetSize(value)
				ELSE
					x.SetSize(system.SizeOf(system.longintType));
				END;
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x)
		END VisitPortType;

		(**
			deferred procedure type resolving
			- resolve return type
			- traverse and resolve parameters
		**)
		PROCEDURE FixProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR resolved: SyntaxTree.Type; parameter: SyntaxTree.Parameter;
		BEGIN
				resolved := ResolveType(procedureType.returnType);
				IF (resolved # NIL) & (resolved.resolved IS SyntaxTree.ArrayType) & (resolved.resolved(SyntaxTree.ArrayType).length = NIL) THEN
					Error(procedureType.position,Diagnostics.Invalid,"forbidden open array return type");
				ELSIF (resolved # NIL) & (procedureType.noReturn) THEN
					Error(procedureType.position,Diagnostics.Invalid,"procedure with return type does not return");
				END;

				procedureType.SetReturnType(resolved);
				IF (resolved # NIL) THEN
					parameter := SyntaxTree.NewParameter(procedureType.position,procedureType,Global.ResultName, SyntaxTree.VarParameter);
					parameter.SetType(procedureType.returnType);
					parameter.SetAccess(SyntaxTree.Hidden);
					parameter.SetUntraced(procedureType.hasUntracedReturn);
					VisitParameter(parameter);
					procedureType.SetReturnParameter(parameter); (* return parameter serves as a cache only *)
				END;

				(* process parameters *)
				parameter :=procedureType.firstParameter;
				WHILE (parameter # NIL) DO
					VisitParameter(parameter);
					parameter := parameter.nextParameter;
				END;
		END FixProcedureType;

		PROCEDURE HasFlag(VAR modifiers: SyntaxTree.Modifier; name: SyntaxTree.Identifier; VAR position: LONGINT): BOOLEAN;
		VAR prev,this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;prev := NIL;
			WHILE (this # NIL) & (this.identifier # name) DO
			prev := this; this := this.nextModifier;
			END;
			IF this # NIL THEN
				IF this.expression # NIL THEN
					Error(this.position,Diagnostics.Invalid,"unexpected expression");
				END;
				this.Resolved;
				position := this.position;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END HasFlag;

		PROCEDURE HasValue(modifiers: SyntaxTree.Modifier; name: SyntaxTree.Identifier; VAR position: LONGINT; VAR value: LONGINT): BOOLEAN;
		VAR prev,this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;prev := NIL;
			WHILE (this # NIL) & (this.identifier # name) DO
				prev := this; this := this.nextModifier;
			END;
			IF this # NIL THEN
				IF this.expression = NIL THEN
					Error(this.position,Diagnostics.Invalid,"expected expression value");
				ELSE
					this.SetExpression(ConstantExpression(this.expression));
					IF CheckIntegerValue(this.expression,value) THEN END;
				END;
				this.Resolved;
				position := this.position;
				RETURN TRUE
			ELSE RETURN FALSE
			END;
		END HasValue;

		PROCEDURE CheckModifiers(modifiers: SyntaxTree.Modifier; checkUse: BOOLEAN);
		VAR this: SyntaxTree.Modifier;
		BEGIN
			this := modifiers;
			WHILE this # NIL DO
				IF ~this.resolved THEN
					IF checkUse OR (this.expression = NIL) THEN
						Error(this.position,Diagnostics.Invalid,"unexpected modifier");
					ELSE
						this.SetExpression(ResolveExpression(this.expression));
						this.Resolved;
					(*! sanity check for "unqualified" modifiers, as for example used in ActiveCells Engine parameterization *)
					END;
				END;
				this := this.nextModifier
			END;
		END CheckModifiers;


		(**
			resolve procedure type
			- enter procedure to list of deferred fixes (to avoid infinite loops in the declaration phase)
		**)
		PROCEDURE VisitProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR modifiers: SyntaxTree.Modifier; value,position: LONGINT;
		BEGIN
			IF TypeNeedsResolution(procedureType) THEN
				modifiers := procedureType.modifiers;
				IF HasFlag(modifiers, Global.NameWinAPI,position) THEN procedureType.SetCallingConvention(SyntaxTree.WinAPICallingConvention)
				ELSIF HasFlag(modifiers, Global.NameInterrupt,position) THEN
					procedureType.SetInterrupt(TRUE);
					procedureType.SetCallingConvention(SyntaxTree.InterruptCallingConvention)
				ELSIF HasFlag(modifiers,Global.NameC,position) THEN
					IF useDarwinCCalls THEN	(*fld*)
						procedureType.SetCallingConvention(SyntaxTree.DarwinCCallingConvention)
					ELSE
						procedureType.SetCallingConvention(SyntaxTree.CCallingConvention)
					END
				ELSIF HasFlag(modifiers, Global.NameNoReturn,position) THEN
					procedureType.SetNoReturn(TRUE);
				END;
				IF HasValue(modifiers,Global.NameStackAligned,position,value) THEN procedureType.SetStackAlignment(value) END;
				IF HasFlag(modifiers, Global.NameDelegate,position) THEN procedureType.SetDelegate(TRUE) END;
				IF HasFlag(modifiers, Global.NameRealtime,position) THEN procedureType.SetRealtime(TRUE) END;
				CheckModifiers(modifiers, TRUE);
				
				modifiers := procedureType.returnTypeModifiers;
				procedureType.SetUntracedReturn(HasFlag(modifiers, Global.NameUntraced, position));
				CheckModifiers(modifiers, TRUE);
				
				typeFixes.Add(procedureType,currentScope);
				procedureType.SetHasPointers(procedureType.isDelegate);
				procedureType.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(procedureType)
		END VisitProcedureType;

		(** check and resolve record type
			- check base type: must be record, math array or array-structured object type
			- check declarations
			- every record type is guaranteed to have a type declaration in the module scope (anonymous or not)
		**)
		PROCEDURE VisitRecordType(x: SyntaxTree.RecordType);
		VAR resolved, baseType: SyntaxTree.Type; position: LONGINT;
			numberMethods: LONGINT; recordBase, recordType: SyntaxTree.RecordType; procedure: SyntaxTree.Procedure;
			symbol: SyntaxTree.Symbol; isRealtime: BOOLEAN;
			hasPointers: BOOLEAN;
			modifiers: SyntaxTree.Modifier;
			value: LONGINT;

			PROCEDURE IsPointerToRecord(type: SyntaxTree.Type; VAR recordType: SyntaxTree.RecordType): BOOLEAN;
			BEGIN
				type := type.resolved;
				IF	(type IS SyntaxTree.PointerType) &
					(type(SyntaxTree.PointerType).pointerBase.resolved # NIL) &
					(type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) THEN
					recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
					RETURN TRUE
				ELSE
					RETURN FALSE
				END;
			END IsPointerToRecord;


		BEGIN
			IF TypeNeedsResolution(x) THEN
				hasPointers := FALSE;
				
				modifiers := x.modifiers;
				IF HasValue(modifiers,Global.NameAligned,position,value) THEN x.SetAlignmentInBits(value*system.dataUnit) END;
				CheckModifiers(modifiers, TRUE);
				
				IF x.baseType # NIL THEN

					position := x.baseType.position;
					baseType := ResolveType(x.baseType);
					resolved := baseType.resolved;
					hasPointers := hasPointers OR resolved.hasPointers;

					IF x.isObject THEN (* object *)
						ASSERT(x.pointerType # NIL);
						IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
						ELSIF resolved IS SyntaxTree.ObjectType THEN (* the type denoted by the <<OBJECT>> alone *)
							baseType := NIL
						ELSIF IsPointerToRecord(resolved,recordType) THEN
							IF ~recordType.isObject THEN Warning(position, "deprecated extension of record to object"); END; 
						ELSIF resolved IS SyntaxTree.MathArrayType THEN
						ELSE
							Error(position, Diagnostics.Invalid,"object does not extend pointer to record, object or math array ")
						END;
					ELSIF x.pointerType # NIL THEN (* record with type declaration POINTER TO RECORD *)
						IF resolved = SyntaxTree.invalidType THEN (* error already handled *)
						ELSIF IsPointerToRecord(resolved,recordType) THEN
							IF recordType.isObject THEN Error(position, Diagnostics.Invalid,"pointer to record extends object") END;
						ELSIF resolved IS SyntaxTree.RecordType THEN
						ELSE
							Error(position, Diagnostics.Invalid,"pointer to record does not extend pointer to record or record")
						END;

					ELSE
						IF resolved IS SyntaxTree.RecordType THEN
						ELSE
							Error(position, Diagnostics.Invalid,"record does not extend record")
						END;
					END;

					x.SetBaseType(baseType);
					IF x.Level() > 15 THEN
						Error(position,Diagnostics.Invalid,"record/object inheritance level too high");
						(* note:
							the restriction to inheritance with a maximum level of 15 is caused by the implementation of the
							runtime structures: type tests are very efficient and rely on the fact that each type descriptor contains the whole
							inheritance history of a type.
							Example: let inhertitance oe given by B(A), C(B), D(C) etc.
							Then the type descriptor of G contains: A|B|C|D|E|F|G|0|0|0...
							while the type decriptor of D contains: A|B|C|D|0|0|0|0|0|0...
						*)
					END;
					IF (x.pointerType # NIL) & (resolved IS SyntaxTree.PointerType) & (x.pointerType.isDisposable # resolved(SyntaxTree.PointerType).isDisposable) THEN
						Error(position,Diagnostics.Invalid,"invalid inheritance of disposable types");
					END;
				END;
				Declarations(x.recordScope);

				ResolveArrayStructure(x);

				(* computation of sizes and offsets skipped -> done in backend / system *)

				recordBase := x.GetBaseRecord();

				IF recordBase = NIL THEN numberMethods := 0
				ELSE numberMethods := recordBase.recordScope.numberMethods
				END;

				isRealtime := TRUE;
				symbol := x.recordScope.firstSymbol; (* sorted symbols, important to go through procedures in a sorted way here !*)
				WHILE symbol # NIL DO
					IF symbol IS SyntaxTree.Variable THEN
						isRealtime := isRealtime & symbol.type.resolved.isRealtime;
						hasPointers := hasPointers OR symbol.type.resolved.hasPointers & ~symbol(SyntaxTree.Variable).untraced;
					END;
					IF symbol IS SyntaxTree.Procedure THEN
						procedure := symbol(SyntaxTree.Procedure);
						IF procedure.super # NIL THEN
							procedure.SetMethodNumber(procedure.super.methodNumber)
						ELSIF InMethodTable(procedure) THEN (* not a static method *)
							procedure.SetMethodNumber(numberMethods);
							INC(numberMethods);
						END;
					END;
					symbol := symbol.nextSymbol;
				END;
				IF isRealtime THEN x.SetRealtime(TRUE) END;

				x.recordScope.SetNumberMethods(numberMethods);

				(* TODO: is this needed anymore? *)
				IF (x.isObject) & (x.baseType # NIL) & (x.baseType.resolved IS SyntaxTree.RecordType) THEN
					Error(x.position,Diagnostics.Invalid,"object extends a record")
				END;

				IF (x.typeDeclaration = NIL) THEN
					IF (x.pointerType # NIL) & (x.pointerType.resolved.typeDeclaration # NIL) THEN
						x.SetTypeDeclaration(x.pointerType.resolved.typeDeclaration);
						(*
						x.pointerType.resolved.typeDeclaration.name.GetString(name);
						AnonymousTypeDeclaration(x,name);
						*)
					ELSE
						AnonymousTypeDeclaration(x,"Anonymous");
					END;
				END;
				x.SetHasPointers(hasPointers);
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x);
		END VisitRecordType;

			(** check and resolve cell type
			- check base type: must be cell
			- check declarations
			- every cell type is guaranteed to have a type declaration in the module scope (anonymous or not)
		**)
		PROCEDURE VisitCellType(x: SyntaxTree.CellType);
		VAR
			symbol: SyntaxTree.Symbol; isRealtime: BOOLEAN; parameter: SyntaxTree.Parameter; type: SyntaxTree.Type; len: LONGINT;
			modifier: SyntaxTree.Modifier; position,value: LONGINT; isEngine: BOOLEAN; property: SyntaxTree.Property;
			qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
			recordBase: SyntaxTree.RecordType;
			numberMethods, int: LONGINT;
			variable: SyntaxTree.Variable;
			v: SyntaxTree.Expression;
			str: Scanner.StringType;
			atype: SyntaxTree.ArrayType;
			prev: SyntaxTree.Scope;
		BEGIN
		
			IF TypeNeedsResolution(x) THEN
				recordBase := NIL;
				IF cellsAreObjects THEN
					qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(x.position, SyntaxTree.NewIdentifier("ActiveCellsRuntime"), SyntaxTree.NewIdentifier("Cell"));
					ImportModule(qualifiedIdentifier.prefix, x.position);
					x.SetBaseType(SyntaxTree.NewQualifiedType(x.position, currentScope, qualifiedIdentifier));
					x.SetBaseType(ResolveType(x.baseType));
					recordBase := x.GetBaseRecord();
					IF recordBase = NIL THEN
						Error(x.position,Diagnostics.Invalid,"ActiveCellsRuntime.Cell not present");
					END;
				END;
				
				IF recordBase = NIL THEN numberMethods := 0
				ELSE numberMethods := recordBase.recordScope.numberMethods
				END;


				modifier := x.modifiers;
				(*IF ~x.isCellNet THEN*)
					IF HasValue(modifier,Global.NameDataMemorySize,position,value) THEN END;
					IF HasValue(modifier,Global.NameCodeMemorySize,position,value) THEN END;
					IF HasFlag(modifier, Global.NameEngine, position) THEN isEngine := TRUE ELSE isEngine := FALSE END;
					IF HasFlag(modifier, Global.NameVector,position) THEN END;
					IF HasFlag(modifier, Global.NameFloatingPoint, position) THEN END;
					IF HasFlag(modifier, Global.NameNoMul,position) THEN END;
					IF HasFlag(modifier, Global.NameNonBlockingIO,position) THEN END;
					IF HasFlag(modifier, Global.NameTRM, position) THEN END;
					IF HasFlag(modifier, Global.NameTRMS, position) THEN END;
					symbol := system.activeCellsCapabilities;
					WHILE symbol # NIL DO
						IF HasFlag(modifier, symbol.name, position) THEN END;
						symbol := symbol.nextSymbol;
					END;
					
					modifier := x.modifiers;
					WHILE (modifier # NIL) DO
					
						property := SyntaxTree.NewProperty(modifier.position, modifier.identifier);
							
						IF modifier.expression # NIL THEN
							v := ConstantExpression(modifier.expression);
							property.SetValue(v);
							IF IsIntegerValue(modifier.expression, int) THEN
								(*property.SetValue(modifier.expression);*)
								property.SetType(system.longintType);
							ELSIF IsStringValue(modifier.expression, str) THEN
								(*property.SetValue(modifier.expression);*)
								atype := SyntaxTree.NewArrayType(-1, NIL, SyntaxTree.Static);
								atype.SetArrayBase(modifier.expression.type(SyntaxTree.StringType).baseType);
								atype.SetLength(Global.NewIntegerValue(system,-1, (* type(SyntaxTree.StringType).length *) 256 (*! check if this is a good idea *) ));
								property.SetType(atype);
				ELSE
								Error(modifier.position, Diagnostics.Invalid, "unsupported property type");
							END;
						ELSE (* flag property *)
							ASSERT(modifier.resolved);
							property.SetValue(SyntaxTree.NewBooleanValue(position,TRUE));
							property.SetType(system.booleanType);
						END;
						(* property.SetScope(x.cellScope); *) (* not required, will be done during entry *)
						(* property.SetState(SyntaxTree.Resolved); *) (* not required, will be done during entry *)
						
						x.AddProperty(property);
						
						modifier := modifier.nextModifier;
					END;
					
				(*ELSE
					
					(* no: this should not be allowed on cell net types or check against global scope ...
					IF HasValue(modifier, Global.NameFrequencyDivider, position,value) THEN
						IF parameter # NIL THEN Error(position, Diagnostics.Invalid,"forbiddern frequency divider in non-terminal cellnet")
						END;
					END
					*)
				
				END;*)
				CheckModifiers(modifier, FALSE);


				Declarations(x.cellScope);

				(* process parameters *)
				prev := currentScope;
				currentScope := x.cellScope;
				parameter :=x.firstParameter;
				WHILE (parameter # NIL) DO
					VisitParameter(parameter);
					type := parameter.type.resolved;
					IF ~(type IS SyntaxTree.PortType) THEN
						WHILE IsStaticArray(type, type, len) DO
							IF IsDynamicArray(type, type) THEN Error(parameter.position, Diagnostics.Invalid, "invalid mixture of dynamic and static array of ports") END;
						END;
						WHILE IsDynamicArray(type, type) DO 
							IF IsStaticArray(type, type, len) THEN Error(parameter.position, Diagnostics.Invalid, "invalid mixture of dynamic and static array of ports") END;
						END;
						IF (* ~IsStaticArray(type,type,len) OR*)  ~(type IS SyntaxTree.PortType) THEN
							Error(parameter.position, Diagnostics.Invalid, "invalid type, must be port or static array of port ");
						END;
					END;
					parameter := parameter.nextParameter;
				END;
				
				currentScope := prev;



				symbol := x.cellScope.firstSymbol; (* sorted symbols, important to go through procedures in a sorted way here !*)
				WHILE symbol # NIL DO
					IF symbol IS SyntaxTree.Variable THEN
						isRealtime := isRealtime & symbol.type.resolved.isRealtime;
					END;
					symbol := symbol.nextSymbol;
				END;
				IF isRealtime THEN x.SetRealtime(TRUE) END;

				IF (x.typeDeclaration = NIL) THEN
					AnonymousTypeDeclaration(x,"Anonymous");
				END;
				x.SetState(SyntaxTree.Resolved);

				IF (x.cellScope.bodyProcedure = NIL) & (~isEngine)THEN
					Error(x.position, Diagnostics.Invalid, "Forbidden empty Body.");
				ELSIF (x.cellScope.bodyProcedure # NIL) & (isEngine)THEN
					Warning(x.position, "Non-empty body for an engine?");
				END;
			END;
			resolvedType := ResolvedType(x);
		END VisitCellType;

		(* check if an object is an array-structured object type
			- determine the array structure
			- collect operators from top to bottom in the inheritance hierarchy
			- check if LEN operator is declared
			- determine number of possible index operators
			- for non-tensors, check if index operators on ranges (RANGE, RANGE, ... RANGE) are present
			- for tensors, check if general index operators (ARRAY [*] OF RANGE) are present
		*)
		PROCEDURE ResolveArrayStructure*(recordType: SyntaxTree.RecordType);
		VAR
			indexOperatorCount, i: LONGINT;
			arrayAccessOperators: SyntaxTree.ArrayAccessOperators;
			isTensor: BOOLEAN;

		BEGIN
			IF recordType.isObject & (recordType.baseType # NIL) THEN
				(* determine array structure *)
				recordType.SetArrayStructure(MathArrayStructureOfType(recordType.baseType.resolved))
			END;

			IF recordType.HasArrayStructure() THEN
				(* the object is an ASOT *)

				isTensor := recordType.arrayStructure.form = SyntaxTree.Tensor;

				(* reset array access operators *)
				arrayAccessOperators.len := NIL;
				arrayAccessOperators.generalRead := NIL;
				arrayAccessOperators.generalWrite := NIL;
				IF isTensor THEN
					(* all operators of dimensionalities 1 to max *)
					indexOperatorCount := TwoToThePowerOf(MaxTensorIndexOperatorSize + 1) - 2
				ELSE
					(* all operators of certain dimensionality *)
					indexOperatorCount := TwoToThePowerOf(recordType.arrayStructure.Dimensionality())
				END;
				NEW(arrayAccessOperators.read, indexOperatorCount);
				NEW(arrayAccessOperators.write, indexOperatorCount);
				FOR i := 0 TO indexOperatorCount - 1 DO
					arrayAccessOperators.read[i] := NIL;
					arrayAccessOperators.write[i] := NIL
				END;

				(* collect access operators in the record scope *)
				CollectArrayAccessOperators(recordType.recordScope, recordType.arrayStructure, arrayAccessOperators);

				IF arrayAccessOperators.len = NIL THEN
					(* TODO: think about making this operator optional for static array structures *)
					Error(recordType.position, Diagnostics.Invalid, "LEN operator missing")
				END;

				(* show error messages *)
				IF isTensor THEN
					(* require ARRAY [*] OF RANGE *)
					IF arrayAccessOperators.generalRead = NIL THEN Error(recordType.position, Diagnostics.Invalid, "general read operator missing") END;
					IF arrayAccessOperators.generalWrite = NIL THEN Error(recordType.position, Diagnostics.Invalid, "general write operator missing") END;
				ELSE
					(* forbid ARRAY [*] OF RANGE *)
					IF arrayAccessOperators.generalRead # NIL THEN Error(recordType.position, Diagnostics.Invalid, "general read operator not applicable") END;
					IF arrayAccessOperators.generalWrite # NIL THEN Error(recordType.position, Diagnostics.Invalid, "general write operator not applicable") END;
					(* require RANGE, RANGE, ... RANGE *)
					IF arrayAccessOperators.read[indexOperatorCount - 1] = NIL THEN Error(recordType.position, Diagnostics.Invalid, "read operator on ranges missing") END;
					IF arrayAccessOperators.write[indexOperatorCount - 1] = NIL THEN Error(recordType.position, Diagnostics.Invalid, "write operator on ranges missing") END;
				END;

				recordType.SetArrayAccessOperators(arrayAccessOperators)
			ELSE
				(* make sure record scopes of non-ASOT object types do not contain operator declarations *)
				IF recordType.recordScope.firstOperator # NIL THEN
					RETURN;
					Error(recordType.recordScope.firstOperator.position, Diagnostics.Invalid, "operator declared for record type without array structure")
				END
			END
		END ResolveArrayStructure;

		(** collect array access operators in a record scope **)
		PROCEDURE CollectArrayAccessOperators(recordScope: SyntaxTree.RecordScope; arrayStructure: SyntaxTree.MathArrayType; VAR arrayAccessOperators: SyntaxTree.ArrayAccessOperators);
		VAR
			baseType: SyntaxTree.Type;
			operator: SyntaxTree.Operator;
			isReadOperator, isGeneralOperator: BOOLEAN;
			indexListSize, indexListKind, hashValue: LONGINT;

		BEGIN
			(* if a parent record scope exists, collect the operators there first *)
			baseType := recordScope.ownerRecord.baseType;
			IF (baseType # NIL) & (baseType.resolved IS SyntaxTree.PointerType) THEN
				baseType := baseType.resolved(SyntaxTree.PointerType).pointerBase.resolved
			END;
			IF (baseType # NIL) & (baseType.resolved IS SyntaxTree.RecordType) THEN
				CollectArrayAccessOperators(baseType(SyntaxTree.RecordType).recordScope, arrayStructure, arrayAccessOperators);
			END;

			(* go through all operators in the current record scope *)
			operator := recordScope.firstOperator;
			WHILE operator # NIL DO
				IF operator.name=SyntaxTree.NewIdentifier("LEN") THEN
					IF CheckLenOperator(operator, arrayStructure) THEN arrayAccessOperators.len := operator END

				ELSIF operator.name = SyntaxTree.NewIdentifier("[]") THEN
					IF CheckIndexOperator(operator, arrayStructure, isReadOperator, isGeneralOperator, indexListSize, indexListKind) THEN
						IF isGeneralOperator THEN
							IF isReadOperator THEN
								arrayAccessOperators.generalRead := operator
							ELSE
								arrayAccessOperators.generalWrite := operator
							END
						ELSE
							hashValue := IndexOperatorHash(indexListSize, indexListKind, arrayStructure.form = SyntaxTree.Tensor);
							IF isReadOperator THEN
								arrayAccessOperators.read[hashValue] := operator
							ELSE
								arrayAccessOperators.write[hashValue] := operator
							END
						END
					END
				ELSE
					Error(operator.position, Diagnostics.Invalid, 'invalid operator')

				END;
				operator := operator.nextOperator
			END
		END CollectArrayAccessOperators;

		(** the hash value of an index operator **)
		PROCEDURE IndexOperatorHash(indexListSize, indexListKind: LONGINT; isTensor: BOOLEAN): LONGINT;
		VAR result: LONGINT;
		BEGIN
			IF isTensor THEN
				IF indexListSize > MaxTensorIndexOperatorSize THEN
					result := -1 (* no fixed-dim. index operator may exist for this scenario: thus, no hash value *)
				ELSE
					result := TwoToThePowerOf(indexListSize) - 2 + indexListKind
				END
			ELSE
				result := indexListKind
			END;
			RETURN result
		END IndexOperatorHash;

		(** 2 to the power of exponent **)
		PROCEDURE TwoToThePowerOf(exponent: LONGINT): LONGINT;
		VAR result, i: LONGINT;
		BEGIN
			result := 1;
			FOR i := 1 TO exponent DO
				result := result * 2;
			END;
			RETURN result
		END TwoToThePowerOf;

		(** check if a LEN operator has a correct signature. i.e.
		for non-tensors: 'OPERATOR "LEN"(): ARRAY [<Dimensionality>] OF LONGINT;'
		for tensors (or non-tensors): 'OPERATOR "LEN"(): ARRAY [*] OF LONGINT;'
		**)
		PROCEDURE CheckLenOperator(operator: SyntaxTree.Operator; arrayStructure: SyntaxTree.MathArrayType): BOOLEAN;
		VAR
			procedureType: SyntaxTree.ProcedureType;
			returnedArrayType: SyntaxTree.MathArrayType;
			result: BOOLEAN;
		BEGIN
			result := FALSE;
			procedureType := operator.type.resolved(SyntaxTree.ProcedureType);
			IF (procedureType.numberParameters = 0) THEN
				IF (procedureType.returnType # NIL) & (procedureType.returnType.resolved IS SyntaxTree.MathArrayType) THEN
					returnedArrayType := procedureType.returnType.resolved(SyntaxTree.MathArrayType);
					IF system.longintType.SameType(returnedArrayType.arrayBase.resolved) THEN
						IF returnedArrayType.form = SyntaxTree.Open THEN
							(* ARRAY [*] OF LONGINT: acceptable for both tensors and non-tensors *)
							result := TRUE
						ELSIF arrayStructure.form # SyntaxTree.Tensor THEN
							(* ARRAY [<Dimensionality>] OF LONGINT: only acceptable for non-tensors *)
							IF (returnedArrayType.form = SyntaxTree.Static) & (returnedArrayType.staticLength = arrayStructure.Dimensionality()) THEN
								result := TRUE
							END
						END
					END
				END
			END;
			IF result THEN
				(* export symbol automatically *)
				operator.SetAccess(SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal)
			ELSE
				Error(operator.position, Diagnostics.Invalid, "LEN operator with invalid signature");
			END;
			RETURN result
		END CheckLenOperator;

		(** check if an index operator has a correct signature. i.e.
			- for read operators: 'OPERATOR "[]"(<IndexParameters>): <DataType>;'
			- for write operators: 'OPERATOR "[]"(<IndexParameters>; rhs: <DataType>);'

			- for general operators: <IndexParameters> = ARRAY [*] OF RANGE
			- for fixed-dim. operators: <IndexParameters> = i0: <LONGINT/RANGE>; i1: <LONGINT/RANGE>; ...; in: <LONGINT/RANGE>

			- determine if it is a read or write operator (existance of return type)
			- check index parameters
			- for fixed-dim. operators, determine the size of the index lists, the operator handles
			- for fixed-dim. operators, determine the kind of the index list this operator handles. index lists kinds are calculated as follows:
				[LONGINT] -> binary 0 -> 0
				[RANGE] -> binary 1 -> 1

				[LONGINT, LONGINT] -> binary 00 -> 0
				[LONGINT, RANGE] -> binary 01 -> 1
				[RANGE, LONGINT] -> binary 10 -> 2
				[RANGE, RANGE] -> binary 11 -> 3

				etc.
			- for fixed-dim. operators and non-tensors, check if number of index parameters equals the ASOT's dimensionality
			- for read operators, check if return type matches the type of data that is read
			- for write operators, check if last parameter type matches the type of data that is written
		**)
		PROCEDURE CheckIndexOperator(operator: SyntaxTree.Operator; arrayStructure: SyntaxTree.MathArrayType; VAR isReadOperator, isGeneralOperator: BOOLEAN; VAR indexListSize, indexListKind: LONGINT): BOOLEAN;
		VAR
			elementType, otherElementType, dataType: SyntaxTree.Type;
			procedureType: SyntaxTree.ProcedureType;
			mathArrayType: SyntaxTree.MathArrayType;
			parameter: SyntaxTree.Parameter;
			parameterCount, rangeCount, i: LONGINT;
			hasTypeError: BOOLEAN;

		BEGIN
			procedureType := operator.type.resolved(SyntaxTree.ProcedureType);
			parameterCount := procedureType.numberParameters; (* true parameter count *)

			(* determine if it is a read or write operator *)
			isReadOperator := (procedureType.returnType # NIL);

			IF isReadOperator THEN
				indexListSize := parameterCount;
			ELSE
				indexListSize := parameterCount - 1;
			END;

			IF indexListSize < 1 THEN
				Error(operator.position, Diagnostics.Invalid, "index operator with too few parameters");
				RETURN FALSE
			END;

			IF procedureType.firstParameter.type.resolved IS SyntaxTree.MathArrayType THEN
				(* general operator *)

				isGeneralOperator := TRUE;

				IF indexListSize > 1 THEN
					Error(operator.position, Diagnostics.Invalid, "index operator with too many parameters");
					RETURN FALSE
				END;

				(* ARRAY [*] OF RANGE*)
				mathArrayType := procedureType.firstParameter.type.resolved(SyntaxTree.MathArrayType);
				IF ~((mathArrayType.arrayBase.resolved IS SyntaxTree.RangeType) & (mathArrayType.form = SyntaxTree.Open)) THEN
					Error(operator.position, Diagnostics.Invalid, "index parameter not dynamic math array of range");
					RETURN FALSE
				END;

				parameter := procedureType.firstParameter.nextParameter
			ELSE
				(* fixed-dim. operator *)

				isGeneralOperator := FALSE;

				(* check number of index parameters *)
				IF arrayStructure.form = SyntaxTree.Tensor THEN
					(* for tensors, limited to a certain size *)
					IF indexListSize > MaxTensorIndexOperatorSize THEN
						Error(operator.position, Diagnostics.Invalid, "too many index parameters for tensor");
						RETURN FALSE
					END
				ELSE
					(* for non-tensors, depends on dimensionality *)
					IF indexListSize # arrayStructure.Dimensionality() THEN
						Error(operator.position, Diagnostics.Invalid, "index parameter count does not match dimensionality");
						RETURN FALSE
					END
				END;

				(* go through all index parameters
				- count the number of ranges
				- determine the index list kind number
				*)
				indexListKind := 0;
				rangeCount := 0;
				parameter := procedureType.firstParameter;
				FOR i := 1 TO indexListSize DO
					indexListKind := indexListKind * 2;
					IF parameter.type.resolved IS SyntaxTree.IntegerType THEN
					ELSIF parameter.type.resolved IS SyntaxTree.RangeType THEN
						INC(indexListKind);
						INC(rangeCount)
					ELSE
						Error(parameter.position, Diagnostics.Invalid, "integer or range expected");
						RETURN FALSE
					END;
					parameter := parameter.nextParameter
				END;
			END;

			(*
			- for read operators: check type of last parameter
			- for write operators: check return type
			*)

			IF isReadOperator THEN
				dataType := procedureType.returnType (* the return type *)
			ELSE
				dataType := parameter.type (* the type of the last non-hidden parameter *)
			END;

			elementType := arrayStructure.ElementType();
			hasTypeError := FALSE;
			IF isGeneralOperator THEN
				(* ARRAY [?] OF <Element> *)
				IF dataType.resolved IS SyntaxTree.MathArrayType THEN
					mathArrayType := dataType.resolved(SyntaxTree.MathArrayType);
					IF ~((mathArrayType.arrayBase.resolved = elementType.resolved) & (mathArrayType.form = SyntaxTree.Tensor)) THEN
						hasTypeError := TRUE
					END
				ELSE
					hasTypeError := TRUE
				END
			ELSE
				IF rangeCount = 0 THEN
					(* <Element> *)
					IF dataType.resolved # elementType.resolved THEN hasTypeError := TRUE END
				ELSE
					(* ARRAY [*, *, ..., *] OF <Element> *)
					IF dataType.resolved IS SyntaxTree.MathArrayType THEN
						mathArrayType := dataType.resolved(SyntaxTree.MathArrayType);
						IF mathArrayType.IsFullyDynamic() THEN
							IF mathArrayType.Dimensionality() = rangeCount THEN
								otherElementType := mathArrayType.ElementType();
								IF otherElementType.resolved # elementType.resolved THEN hasTypeError := TRUE END
							ELSE
								hasTypeError := TRUE
							END
						ELSE
							hasTypeError := TRUE
						END
					ELSE
						hasTypeError := TRUE
					END
				END
			END;

			IF hasTypeError THEN
				IF isReadOperator THEN
					Error(operator.position, Diagnostics.Invalid, "return type does not match")
				ELSE
					Error(parameter.position, Diagnostics.Invalid, "type of last parameter does not match")
				END;
				RETURN FALSE
			END;

			(* export symbol automatically *)
			operator.SetAccess(SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal);

			RETURN TRUE
		END CheckIndexOperator;

		(** resolve all pending types (late resolving).
			- type fixes are resolved at the end of the declaration phase
			- type fixes may imply new type fixes that are also entered at the end of the list
		**)
		PROCEDURE FixTypes;
		VAR p: ANY; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			p := typeFixes.Get(currentScope);
			WHILE p # NIL DO
				ASSERT(currentScope # NIL);
				ASSERT(p IS SyntaxTree.Type);

				IF p IS SyntaxTree.PointerType THEN
					FixPointerType(p(SyntaxTree.PointerType))
				ELSIF p IS SyntaxTree.ProcedureType THEN
					FixProcedureType(p(SyntaxTree.ProcedureType))
				ELSE
					HALT(100);
				END;
				p := typeFixes.Get(currentScope);
			END;
			currentScope :=prevScope;
		END FixTypes;

		(**
			resolve type x
			- if x is nil then return nil
			- if x cannot be resolved then the result is invalidType else the result is x
			- the resolved type is entered into x.resolved
		**)
		PROCEDURE ResolveType(x: SyntaxTree.Type): SyntaxTree.Type;
		VAR prev,resolved: SyntaxTree.Type;
		BEGIN
			prev := resolvedType;
			resolvedType := SyntaxTree.invalidType;
			IF x = NIL THEN resolvedType := NIL
			ELSE x.Accept(SELF); ASSERT(resolvedType # NIL); (* in error cases it must be invalidType *)
			END;
			resolved := resolvedType;
			resolvedType := prev;

			ASSERT((resolved = NIL) OR (resolved.resolved # NIL));

			RETURN resolved
		END ResolveType;

		(*** compatibility rules ***)

		(**
			return a regular type: if type is invalid, NIL, importType or typeDeclarationType then return invalidType else return type
		**)
		PROCEDURE RegularType(position: LONGINT; type: SyntaxTree.Type): SyntaxTree.Type;
		VAR result: SyntaxTree.Type;
		BEGIN
			result := SyntaxTree.invalidType;
			IF type = NIL THEN Error(position,Diagnostics.Invalid,"expression of type NIL");
			ELSIF type = SyntaxTree.invalidType THEN (* error already handled *)
			ELSIF type.resolved = SyntaxTree.importType THEN Error(position,Diagnostics.Invalid,"expression is an import");
			ELSIF type.resolved = SyntaxTree.typeDeclarationType THEN Error(position,Diagnostics.Invalid,"expression is a type");
			ELSE result := type.resolved
			END;
			RETURN result
		END RegularType;


		(** returns signature compatibility of procedure types this and to
			- if not compatible then error is reported
			- compatibility means type equality
		**)
		PROCEDURE SignatureCompatible(position: LONGINT; this, to: SyntaxTree.ProcedureType): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := SameType(to,this);
			IF ~result THEN
				Error(position,Diagnostics.Invalid,"signature incompatible");
				IF VerboseErrorMessage THEN
					Printout.Info("this",this);
					Printout.Info("to",to);
				END;
			ELSIF (to(SyntaxTree.ProcedureType).isRealtime) & ~(this(SyntaxTree.ProcedureType).isRealtime) THEN
				Error(position,Diagnostics.Invalid,"signature incompatible: realtime flag must be inherited");
			END;
			RETURN result
		END SignatureCompatible;

		(** check parameter compatibility for expressions of the form P(actual) where P = PROCEDURE([VAR|CONST] formal)
			- for var parameters compatibility means same type except for
				- formal is of open array of system byte
				- formal is of record type
				- formal is of open array type
				- formal is of open math array type
			- for value parameters compatibllity means assignment compatibility except for
				- formal is of open array type
			if compatible the return true else report error and return false
		**)

		PROCEDURE ParameterCompatible(formal: SyntaxTree.Parameter; actual: SyntaxTree.Expression): BOOLEAN;
		VAR formalType, actualType: SyntaxTree.Type; result,error: BOOLEAN;
		BEGIN
			formalType := RegularType(formal.position,formal.type);
			actualType := RegularType(actual.position,actual.type);
			error := FALSE;

			IF actualType = SyntaxTree.invalidType THEN (* error already handled *)
			ELSIF (formal.kind = SyntaxTree.VarParameter) THEN
				IF (actual IS SyntaxTree.SymbolDesignator) & (actual(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) THEN
					actual(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).UsedAsReference;
				END;
				IF (formal.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.WinAPICallingConvention) & (actualType IS SyntaxTree.NilType) THEN
					result := TRUE; (* special rule for WINAPI parameters, needed to be able to pass NIL address to var parameters *)
				ELSIF ~IsVariable(actual) THEN
					result := FALSE; error := TRUE;
					IF actual IS SyntaxTree.ProcedureCallDesignator THEN
						Error(actual.position,Diagnostics.Invalid,"not a variable: no operator for writing");
					ELSE
						Error(actual.position,Diagnostics.Invalid,"is not a variable");
					END;
					IF VerboseErrorMessage THEN
						Printout.Info("actual",actual);
						Printout.Info("formal",formal);
					END;
				ELSIF (formalType IS SyntaxTree.ByteType) OR (formalType IS SyntaxTree.RecordType) & (~formalType(SyntaxTree.RecordType).isObject) THEN
					result := CompatibleTo(system,actualType,formalType);
				ELSIF (formalType IS SyntaxTree.ArrayType) & (formalType(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
					result := OpenArrayCompatible(formalType(SyntaxTree.ArrayType),actualType);
				ELSIF (formalType IS SyntaxTree.MathArrayType) THEN
					IF IsArrayStructuredObjectType(actualType) THEN
						actualType := MathArrayStructureOfType(actualType)
					END;
					result := MathArrayCompatible(formalType(SyntaxTree.MathArrayType),actualType);
					IF result & (formalType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (actualType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						Error(actual.position,Diagnostics.Invalid,"incompatible non-static actual type");
					END;
					IF result & (actualType(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (formalType(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) THEN
						Error(actual.position,Diagnostics.Invalid,"incompatible tensor (use a range expression)");
					END;
				ELSE
					result := SameType(actualType,formalType)
				END
			ELSE
				IF (formalType IS SyntaxTree.CharacterType) & (actualType IS SyntaxTree.StringType) & (actualType(SyntaxTree.StringType).length = 2) THEN
					actualType := system.characterType;
				END;
				IF (formal.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.WinAPICallingConvention) &  ((actualType IS SyntaxTree.NilType) OR (actualType IS SyntaxTree.AnyType)) THEN
					result := TRUE; (* special rule for WINAPI parameters *)
				ELSIF (formalType IS SyntaxTree.ArrayType) & (formalType(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
					result := OpenArrayCompatible(formalType(SyntaxTree.ArrayType),actualType);
				ELSE
					result := CompatibleTo(system,actualType,formalType);
					IF result & (formalType IS SyntaxTree.MathArrayType) & (formalType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (actualType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						Error(actual.position,Diagnostics.Invalid,"incompatible non-static actual type");
					END;
				END;
			END;
			IF ~result & ~error THEN
				Error(actual.position,Diagnostics.Invalid,"incompatible parameter");
				IF VerboseErrorMessage THEN
					Printout.Info("actual",actual);
					Printout.Info("formal",formal);
				END;
			END;
			RETURN result
		END ParameterCompatible;

		(** check compatibility for expressions of the form left := right
			- if compatible then return true else error report and return false
			- check if left is variable
			- check compatiblity
		**)
		PROCEDURE AssignmentCompatible(left: SyntaxTree.Designator; right: SyntaxTree.Expression): BOOLEAN;
		VAR leftType,rightType: SyntaxTree.Type; VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			leftType := RegularType(left.position,left.type);
			rightType := RegularType(right.position,right.type);

			IF (leftType IS SyntaxTree.CharacterType) & (rightType IS SyntaxTree.StringType) & (rightType(SyntaxTree.StringType).length = 2) THEN
				rightType := system.characterType; (* conversion character "x" -> string "x" *)
			END;

			(* special rule: a type is assignment compatible to an ASOT if it is assignment compatible to its structure *)
			IF IsArrayStructuredObjectType(leftType) THEN leftType := MathArrayStructureOfType(leftType) END;

			IF (leftType = SyntaxTree.invalidType) OR (rightType = SyntaxTree.invalidType) THEN
				(* error already handled *)
				result := TRUE;

			ELSIF ~IsVariable(left) THEN
				Error(left.position,Diagnostics.Invalid,"is not a variable");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("right",right);
				END;
			ELSIF (leftType IS SyntaxTree.AddressType) & IsAddressValue(right) THEN
				result := TRUE;
			ELSIF IsUnsignedIntegerType(leftType) & IsUnsignedValue(right, leftType.sizeInBits) THEN
				result := TRUE
			ELSIF ~CompatibleTo(system,rightType,leftType) THEN
				Error(left.position,Diagnostics.Invalid,"incompatible assignment");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("right",right);
				END;
			ELSIF (right IS SyntaxTree.SymbolDesignator) & (right(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Procedure) &
				(right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure).scope IS SyntaxTree.ProcedureScope) THEN
				Error(right.position,Diagnostics.Invalid,"forbidden assignment of a nested procedure");
			ELSE
				result := TRUE
			END;
			RETURN result
		END AssignmentCompatible;

		(*** values  ***)

		(** check and resolve integer value **)
		PROCEDURE VisitIntegerValue(value: SyntaxTree.IntegerValue);
		VAR hugeint: HUGEINT;
		BEGIN
			hugeint := value(SyntaxTree.IntegerValue).hvalue;
			value.SetType(Global.GetIntegerType(system,hugeint));
			resolvedExpression := value
		END VisitIntegerValue;

		(** check and resolve real value **)
		PROCEDURE VisitRealValue(value: SyntaxTree.RealValue);
		VAR subtype: LONGINT; type: SyntaxTree.Type;
		BEGIN
			subtype := value(SyntaxTree.RealValue).subtype;
			IF subtype = Scanner.Real THEN
				type := system.realType
			ELSIF subtype = Scanner.Longreal THEN
				type := system.longrealType
			ELSE
				HALT(100)
			END;
			value.SetType(type);
			resolvedExpression := value
		END VisitRealValue;

		(** check and resolve complex value **)
		PROCEDURE VisitComplexValue(value: SyntaxTree.ComplexValue);
		VAR subtype: LONGINT; type: SyntaxTree.Type;
		BEGIN
			subtype := value(SyntaxTree.ComplexValue).subtype;
			IF subtype = Scanner.Real THEN
				type := system.complexType
			ELSIF subtype = Scanner.Longreal THEN
				type := system.longcomplexType
			ELSE
				HALT(100)
			END;
			value.SetType(type);
			resolvedExpression := value
		END VisitComplexValue;

		(** check and resolve set value **)
		PROCEDURE VisitSetValue(value: SyntaxTree.SetValue);
		BEGIN
			value.SetType(system.setType);
			resolvedExpression := value
		END VisitSetValue;

		(** check and resolve set value **)
		PROCEDURE VisitMathArrayValue(value: SyntaxTree.MathArrayValue);
		BEGIN
			value.SetType(SyntaxTree.invalidType);
			resolvedExpression := value
		END VisitMathArrayValue;

		(** check and resolve boolean value **)
		PROCEDURE VisitBooleanValue(value: SyntaxTree.BooleanValue);
		BEGIN
			value.SetType(system.booleanType);
			resolvedExpression := value
		END VisitBooleanValue;

		(** check and resolve string value **)
		PROCEDURE VisitStringValue(value: SyntaxTree.StringValue);
		BEGIN
			value.SetType(ResolveType(SyntaxTree.NewStringType(value.position,system.characterType,value.length)));
			resolvedExpression := value
		END VisitStringValue;

		(** check and resolve character value **)
		PROCEDURE VisitCharacterValue(value: SyntaxTree.CharacterValue);
		BEGIN
			value.SetType(system.characterType);
			resolvedExpression := value
		END VisitCharacterValue;

		(** check and resolve nil value **)
		PROCEDURE VisitNilValue(value: SyntaxTree.NilValue);
		BEGIN
			value.SetType(system.nilType);
			resolvedExpression := value
		END VisitNilValue;

		(** check and resolve enumerator value **)
		PROCEDURE VisitEnumerationValue(value: SyntaxTree.EnumerationValue);
		BEGIN
			value.SetType(currentScope(SyntaxTree.EnumerationScope).ownerEnumeration);
			ASSERT(value.type # NIL);
			resolvedExpression := value
		END VisitEnumerationValue;

		(*** expressions ***)

		(** check and resolve a Set expression of the form {Expression, Expression, ...}
			- check all elements on integer type
			- if element range is constant, then check lower and upper bound
			- if all elements constant then return constant set value else return set expression (via global variable resolvedExpression)
			if an error occurs then report error and return invalidExpression
		**)
		PROCEDURE VisitSet(set: SyntaxTree.Set);
		VAR
			i: LONGINT;
			element: SyntaxTree.Expression;
			constant: BOOLEAN;
			elements: SyntaxTree.ExpressionList;
			s: SET;
			result: SyntaxTree.Expression;
			value: SyntaxTree.Value;

			PROCEDURE CheckElement(element: SyntaxTree.Expression): SyntaxTree.Expression;
			VAR
				left, right: SyntaxTree.Expression;
				elementResult: SyntaxTree.Expression;
				leftInteger, rightInteger: LONGINT;
			BEGIN
				(* set context of range *)
				IF element IS SyntaxTree.RangeExpression THEN
					element(SyntaxTree.RangeExpression).SetContext(SyntaxTree.SetElement)
				END;

				elementResult := ResolveExpression(element); (* implies checking of subexpressions in binary expressions *)

				IF elementResult = SyntaxTree.invalidExpression THEN
					(* error already reported *)
					constant := FALSE

				ELSIF elementResult IS SyntaxTree.RangeExpression THEN
					(* the element is a range expression *)

					(* extract left and right hand side of range *)
					left := elementResult(SyntaxTree.RangeExpression).first;
					right := elementResult(SyntaxTree.RangeExpression).last;

					(* guaranteed by VisitRangeExpression: *)
					ASSERT((left # NIL) & (right # NIL));
					ASSERT(system.longintType.SameType(left.type.resolved) & system.longintType.SameType(right.type.resolved));

				ELSE
					(* the element is not a range expression *)

					(* check type and add conversion if needed *)
					IF IsSizeType(elementResult.type.resolved, system.addressSize) THEN
						elementResult := NewConversion(elementResult.position, elementResult, system.sizeType, NIL)
					ELSE
						Error(elementResult.position, Diagnostics.Invalid, "non integer element in set");
						elementResult := SyntaxTree.invalidExpression;
						constant := FALSE
					END;

					left := elementResult;
					right := elementResult
				END;

				IF elementResult # SyntaxTree.invalidExpression THEN
					IF IsIntegerValue(left,leftInteger) & IsIntegerValue(right,rightInteger) THEN
						IF (leftInteger<0) OR (leftInteger >= system.setType.sizeInBits) THEN
							Error(left.position,Diagnostics.Invalid,"not allowed set integer value");
							IF (rightInteger<0) OR (rightInteger  >= system.setType.sizeInBits) THEN
								Error(right.position,Diagnostics.Invalid,"not allowed set integer value");
							END
						ELSIF (rightInteger<0) OR (rightInteger >= system.setType.sizeInBits) THEN
							Error(right.position,Diagnostics.Invalid,"not allowed set integer value");
						ELSE
							IF rightInteger > MAX(SET) THEN rightInteger := MAX(SET) END; (*!!!!!!!!! this is a hack !!!!!!! *)
							s := s + {leftInteger..rightInteger};
							(* same but more explicit:
							WHILE (leftInteger <= rightInteger) DO
								INCL(s,leftInteger);
								INC(leftInteger);
							END;
							*)
						END;
					ELSE
						constant := FALSE;
					END
				END;

				RETURN elementResult
			END CheckElement;

		BEGIN
			result := set; constant := TRUE; s := {}; elements := set.elements;
			IF elements # NIL THEN
				FOR i := 0 TO elements.Length()-1 DO
					element := elements.GetExpression(i);
					element := CheckElement(element);
					IF element = SyntaxTree.invalidExpression THEN
						result := SyntaxTree.invalidExpression
					END;
					elements.SetExpression(i,element);
				END;
			END;
			IF constant THEN
				value := SyntaxTree.NewSetValue(set.position,s);
				value.SetType(system.setType);
				result.SetResolved(value);
			END;
			(* optimization possible
				convert {a,b,1,2,3,4,c,d} into {a,b,c,d} + {1,2,3,4}
				left this to the programmer...
			*)
			result.SetType(system.setType);
			resolvedExpression := result;
		END VisitSet;

		(*
		old variant: quite generic but needs better conversion handling, do this?

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		VAR type: SyntaxTree.Type; position,numberElements,i: LONGINT; expression: SyntaxTree.Expression; isValue: BOOLEAN;
			value: SyntaxTree.MathArrayValue; arrayType: SyntaxTree.MathArrayType;
		BEGIN
			type := NIL;
			numberElements := x.elements.Length();
			FOR i := 0 TO numberElements-1 DO
				expression := x.elements.GetExpression(i);
				position := expression.position;
				expression := ResolveExpression(x.elements.GetExpression(i));
				x.elements.SetExpression(i,de);
				IF type = NIL THEN
					type := expression.type;
				ELSIF CompatibleTo(system,expression.type,type) THEN
					(* ok *)
				ELSIF CompatibleTo(system,type,expression.type) THEN
					type := expression.type
				ELSE
					Error(expression.position,Diagnostics.Invalid, "incompatible element types");
					type := SyntaxTree.invalidType;
				END;
			END;
			isValue := TRUE;
			FOR i := 0 TO numberElements-1 DO
				expression := NewConversion(position,x.elements.GetExpression(i),type);
				x.elements.SetExpression(i,expression);
				isValue := isValue & (expression.resolved # NIL);
			END;
			arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
			arrayType.SetArrayBase(type);
			arrayType.SetLength(Global.NewIntegerValue(system,NewIntegerValue(system,rElements));
			IF isValue THEN
				value := SyntaxTree.NewMathArrayValue(position);
				value.SetElements(x.elements);
				x.SetResolved(value);
			END;
			x.SetType(arrayType);
			resolvedExpression := x;
		END VisitMathArrayExpression;
		*)

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		VAR type: SyntaxTree.Type; isValue: BOOLEAN;
			value: SyntaxTree.MathArrayValue; arrayType: SyntaxTree.Type;

			PROCEDURE RecursivelyFindType(x: SyntaxTree.MathArrayExpression);
			VAR position,numberElements,i: LONGINT; expression: SyntaxTree.Expression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursivelyFindType(expression(SyntaxTree.MathArrayExpression))
					ELSE
						position := expression.position;
						expression := ResolveExpression(x.elements.GetExpression(i));
						x.elements.SetExpression(i,expression);
						IF type = NIL THEN
							type := expression.type;
						ELSIF CompatibleTo(system,expression.type,type) THEN
							(* ok *)
						ELSIF CompatibleTo(system,type,expression.type) THEN
							type := expression.type
						ELSE
							Error(expression.position,Diagnostics.Invalid, "incompatible element types");
							type := SyntaxTree.invalidType;
						END;
					END;
				END;
			END RecursivelyFindType;

			PROCEDURE RecursivelySetExpression(x: SyntaxTree.MathArrayExpression);
			VAR position,numberElements,i: LONGINT; expression: SyntaxTree.Expression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursivelySetExpression(expression(SyntaxTree.MathArrayExpression));
					ELSE
						position := expression.position;
						expression := NewConversion(position,x.elements.GetExpression(i),type,NIL);
						x.elements.SetExpression(i,expression);
						isValue := isValue & (expression.resolved # NIL);
					END;
				END;
			END RecursivelySetExpression;

			PROCEDURE RecursivelySetType(x: SyntaxTree.MathArrayExpression): SyntaxTree.Type;
			VAR numberElements,i,size,gsize: LONGINT; baseType: SyntaxTree.Type;expression: SyntaxTree.Expression;
				arrayType: SyntaxTree.MathArrayType;
			BEGIN
				numberElements := x.elements.Length();
				baseType := NIL;
				gsize := 0;
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						size := expression(SyntaxTree.MathArrayExpression).elements.Length();
						IF i=0 THEN
							gsize := size;
							baseType := RecursivelySetType(expression(SyntaxTree.MathArrayExpression));
						ELSIF (baseType = type) OR (gsize # size) THEN  Error(expression.position,Diagnostics.Invalid, "invalid array dimensions");
						ELSE expression.SetType(baseType)
						END;
					ELSIF baseType = NIL THEN baseType := type;
					ELSIF baseType # type THEN Error(expression.position,Diagnostics.Invalid, "invalid array dimensions");
					END;
				END;
				arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
				arrayType.SetArrayBase(baseType);
				arrayType.SetLength(Global.NewIntegerValue(system,x.position,numberElements));
				RETURN ResolveType(arrayType);
			END RecursivelySetType;


		BEGIN
			type := NIL;
			RecursivelyFindType(x);
			isValue := TRUE;
			RecursivelySetExpression(x);
			arrayType := RecursivelySetType(x);
			x.SetType(arrayType);
			IF isValue THEN
				value := SyntaxTree.NewMathArrayValue(x.position);
				value.SetArray(x);
				x.SetResolved(value);
				value.SetType(arrayType);
			END;
			x.SetType(arrayType);
			resolvedExpression := x;
		END VisitMathArrayExpression;

		(** check and resolve unary expression **)
		PROCEDURE VisitUnaryExpression(unaryExpression: SyntaxTree.UnaryExpression);
		VAR
			left: SyntaxTree.Expression;
			int: HUGEINT; real, imaginary: LONGREAL; set: SET; operator: LONGINT;
			bool: BOOLEAN;
			result: SyntaxTree.Expression; type: SyntaxTree.Type; operatorCall: SyntaxTree.Expression;
			value: SyntaxTree.Value;
		BEGIN
			type := SyntaxTree.invalidType;
			left := ResolveExpression(unaryExpression.left);
			unaryExpression.SetLeft(left);
			operator := unaryExpression.operator;
			result := unaryExpression;
			IF ~system.operatorDefined[operator] THEN
				Error(left.position,Diagnostics.Invalid,"Operator Not Defined");
				RETURN
			ELSIF left.type = NIL THEN
				Error(left.position,Diagnostics.Invalid,"Invalid Nil Argument in Unary Expression");
				resolvedExpression := SyntaxTree.invalidExpression;
				RETURN
			ELSIF left = SyntaxTree.invalidExpression THEN (* error already handled *)
				RETURN
			END;
			IF  ~(left.type.resolved IS SyntaxTree.BasicType) OR (left.type.resolved IS SyntaxTree.ComplexType) THEN
				operatorCall := NewOperatorCall(unaryExpression.position, operator,left,NIL,NIL);
			END;
			IF operatorCall # NIL THEN
				result := operatorCall;
				type := operatorCall.type;
				(* admissible operators
					Minus			number, set
					Not			boolean
				*)
			ELSE
				CASE unaryExpression.operator OF
				|Scanner.Minus:
					IF IsIntegerType(left.type.resolved) THEN
						IF left.resolved # NIL THEN
							int := -left.resolved(SyntaxTree.IntegerValue).hvalue;
							value := SyntaxTree.NewIntegerValue(unaryExpression.position,int);
							result.SetResolved(value);
							type := Global.GetIntegerType(system,int);
							value.SetType(type);
						ELSE
							type := left.type
						END
					ELSIF left.type.resolved IS SyntaxTree.FloatType THEN
						IF IsRealValue(left,real) THEN
							value := SyntaxTree.NewRealValue(unaryExpression.position,-real);
							result.SetResolved(value);
							type := left.type;
							value.SetType(type);
						ELSE
							type := left.type;
						END;
					ELSIF left.type.resolved IS SyntaxTree.SetType THEN
						IF IsSetValue(left,set) THEN
							value := SyntaxTree.NewSetValue(unaryExpression.position,-set);
							result.SetResolved(value);
							type := left.type;
							value.SetType(type);
						ELSE
							type := left.type;
						END;
					ELSIF left.type.resolved IS SyntaxTree.ComplexType THEN
						IF IsComplexValue(left, real, imaginary) THEN
							value := SyntaxTree.NewComplexValue(unaryExpression.position,-real, -imaginary);
							result.SetResolved(value);
							type := left.type;
							value.SetType(type);
							value(SyntaxTree.ComplexValue).SetSubtype(left.resolved(SyntaxTree.ComplexValue).subtype) (* reuse subtype *)
						ELSE
							type := left.type;
						END
					ELSE
						Error(left.position,Diagnostics.Invalid,"unary operator not applicable");
					END;
				|Scanner.Not:
					IF left.type.resolved IS SyntaxTree.BooleanType THEN
						IF IsBooleanValue(left,bool)  THEN
							value := SyntaxTree.NewBooleanValue(unaryExpression.position,~bool);
							result.SetResolved(value);
							type := system.booleanType;
							value.SetType(type);
						ELSE
							type := system.booleanType;
						END;
					ELSE
						Error(left.position,Diagnostics.Invalid,"unary operator not applicable");
					END;
				|Scanner.Plus:
					IF (left.type.resolved IS SyntaxTree.NumberType) THEN
						result := left; type := left.type;
					ELSE
						Error(left.position,Diagnostics.Invalid,"unary operator not applicable");
					END;
				(* ADDRESS OF *)
				|Scanner.Address:
					IF HasAddress(left) THEN
						type := system.addressType;
					ELSE
						type := SyntaxTree.invalidType;
						Error(left.position,Diagnostics.Invalid,"has no address");
						Printout.Info("par", left);
					END;
				(* SIZE OF *)
				|Scanner.Size:
					IF (left.type = SyntaxTree.typeDeclarationType) THEN
						type := left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						int := system.SizeOf(type.resolved) DIV 8 (* in bytes *);
						value := SyntaxTree.NewIntegerValue(left.position, int);
						result.SetResolved(value);
						type := Global.GetIntegerType(system,int);
						value.SetType(type)
						(* was Int16  in paco but should be systemSize (conflict with current release) *)
					ELSE
						(* for variables, system sizeof could represent the physically occupied size
							determined via the type descriptor, implement that ? *)
						Error(left.position,Diagnostics.Invalid,"is not a type symbol");
					END
				 (* ALIAS OF *)
				|Scanner.Alias:
					type := left.type.resolved;
					IF ~(type IS SyntaxTree.MathArrayType) THEN
						type := SyntaxTree.invalidType;
						Error(left.position, Diagnostics.Invalid,"alias on non math array type");
					END;
				ELSE
					Error(left.position,Diagnostics.Invalid,"unary operator not defined");
				END;
			END;
			result.SetType(type);
			resolvedExpression := result
		END VisitUnaryExpression;

		PROCEDURE MathArrayConversion(position: LONGINT; expression: SyntaxTree.Expression; type: SyntaxTree.Type): SyntaxTree.Expression;
		VAR
			result: SyntaxTree.Expression;
			array: SyntaxTree.MathArrayExpression;
			value: SyntaxTree.MathArrayValue;
			isValue: BOOLEAN;

			PROCEDURE BaseType(type: SyntaxTree.Type): SyntaxTree.Type;
			BEGIN
				type := type.resolved;
				WHILE (type # NIL) & (type IS SyntaxTree.MathArrayType) DO
					type := Resolved(type(SyntaxTree.MathArrayType).arrayBase);
				END;
				WHILE (type # NIL) & (type IS SyntaxTree.ArrayType) DO
					type := Resolved(type(SyntaxTree.ArrayType).arrayBase);
				END;
				RETURN type
			END BaseType;

			PROCEDURE RecursivelyConvert(x, to: SyntaxTree.MathArrayExpression);
			VAR position,numberElements,i: LONGINT; expression: SyntaxTree.Expression; array: SyntaxTree.MathArrayExpression;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						array := SyntaxTree.NewMathArrayExpression(position);
						RecursivelyConvert(expression(SyntaxTree.MathArrayExpression), array);
						expression := array;
					ELSE
						position := expression.position;
						expression := NewConversion(position,x.elements.GetExpression(i),type,NIL);
						isValue := isValue & (expression.resolved # NIL);
					END;
					to.elements.AddExpression(expression);
				END;
			END RecursivelyConvert;


			PROCEDURE RecursivelySetType(x: SyntaxTree.MathArrayExpression): SyntaxTree.Type;
			VAR numberElements,i,size,gsize: LONGINT; baseType: SyntaxTree.Type;expression: SyntaxTree.Expression;
				arrayType: SyntaxTree.MathArrayType;
			BEGIN
				numberElements := x.elements.Length();
				baseType := NIL;
				gsize := 0;
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						size := expression(SyntaxTree.MathArrayExpression).elements.Length();
						IF i=0 THEN
							gsize := size;
							baseType := RecursivelySetType(expression(SyntaxTree.MathArrayExpression));
						ELSIF (baseType = type) OR (gsize # size) THEN  Error(expression.position,Diagnostics.Invalid, "invalid array dimensions");
						ELSE expression.SetType(baseType)
						END;
					ELSIF baseType = NIL THEN baseType := type;
					ELSIF baseType # type THEN Error(expression.position,Diagnostics.Invalid, "invalid array dimensions");
					END;
				END;
				arrayType := SyntaxTree.NewMathArrayType(x.position,NIL, SyntaxTree.Static);
				arrayType.SetArrayBase(baseType);
				arrayType.SetLength(Global.NewIntegerValue(system,x.position,numberElements));
				RETURN ResolveType(arrayType);
			END RecursivelySetType;

		BEGIN
			result := SyntaxTree.invalidExpression;
			IF (BaseType(type)=NIL) OR (BaseType(expression.type.resolved).SameType(BaseType(type)))  THEN
				result := expression (* do not convert *)
			ELSIF (expression.resolved # NIL) & (BaseType(type) IS SyntaxTree.BasicType) THEN (* compliance has already been checked *)
				isValue := TRUE;
				type :=  BaseType(type);
				array := SyntaxTree.NewMathArrayExpression(expression.position);
				RecursivelyConvert(expression(SyntaxTree.MathArrayValue).array(SyntaxTree.MathArrayExpression), array);
				value := SyntaxTree.NewMathArrayValue(array.position);
				value.SetArray(array);
				value.SetType(RecursivelySetType(array));
				result := value;
				IF ~isValue THEN Error(position, Diagnostics.Invalid, "incompatible array conversion") END;
			ELSE (* should the search for operators be restricted to the ArrayBase module here ? *)
				result := NewOperatorCall(position,Global.Conversion,expression,NIL,type);
				IF result = NIL THEN
					result := SyntaxTree.invalidExpression;
					Error(position,Diagnostics.Invalid,"incompatible conversion");
					IF VerboseErrorMessage THEN
						Printout.Info("expression",expression);
						Printout.Info("type",type);
					END;
				END;
			END;
			RETURN result
		END MathArrayConversion;

		PROCEDURE ConvertValue(position: LONGINT; expression: SyntaxTree.Value; type: SyntaxTree.Type): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; int: HUGEINT; real, imaginary: LONGREAL; set: SET; char: CHAR; string: Scanner.StringType;
		BEGIN
			result := expression; type := type.resolved;
			IF (expression IS SyntaxTree.IntegerValue)  THEN
				int := expression(SyntaxTree.IntegerValue).hvalue;
				IF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.SizeType) THEN
					int := Global.ConvertSigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.AddressType) OR IsUnsafePointer(type) THEN
					int := Global.ConvertUnsigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.FloatType) THEN
					result := SyntaxTree.NewRealValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, int, 0);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.SetType) THEN
					result := SyntaxTree.NewSetValue(expression.position,SYSTEM.VAL(SET,int));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,SYSTEM.VAL(CHAR,int));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.EnumerationType) THEN
					IF (int > MAX(LONGINT)) OR (int < MIN(LONGINT)) THEN
						Error(position,Diagnostics.Invalid,"huge integer value incompatible to enumeration");
					END;
					result := SyntaxTree.NewEnumerationValue(expression.position,SHORT(int));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position,Diagnostics.Invalid,"integer value cannot be converted");
					result := SyntaxTree.invalidExpression;
					IF VerboseErrorMessage THEN
						Printout.Info("expression",expression);
						Printout.Info("type",type);
					END;
				END;
			ELSIF IsRealValue(expression,real) THEN
				IF (type IS SyntaxTree.IntegerType) & (type.sizeInBits < 64) THEN
					int := Global.ConvertSigned(ENTIER(real),system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.IntegerType) THEN
					int := ENTIERH(real);
					result := SyntaxTree.NewIntegerValue(expression.position,int);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.FloatType) THEN
					result := SyntaxTree.NewRealValue(position,real);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, real, 0);
					result.SetType(type);
					result(SyntaxTree.ComplexValue).UpdateSubtype;
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position,Diagnostics.Invalid,"real value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END
			ELSIF IsComplexValue(expression, real, imaginary) THEN
				IF (type IS SyntaxTree.ComplexType) THEN
					result := SyntaxTree.NewComplexValue(expression.position, real, imaginary);
					result.SetType(type);
					result(SyntaxTree.ComplexValue).SetSubtype(expression.resolved(SyntaxTree.ComplexValue).subtype) (* reuse subtype *)
				ELSE
					Error(position,Diagnostics.Invalid,"complex value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END
			ELSIF IsSetValue(expression,set) THEN
				IF (type IS SyntaxTree.IntegerType) THEN
					result := SyntaxTree.NewIntegerValue(expression.position,SYSTEM.VAL(LONGINT,set));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) THEN (* for example: possible via ch = CHR(SYSTEM.VAL(LONGINT,set)) *)
					result := SyntaxTree.NewCharacterValue(expression.position,SYSTEM.VAL(CHAR,set));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position,Diagnostics.Invalid,"set value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF IsStringValue(expression,string) THEN
				IF ((type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType)) & (string[1]=0X) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,string[0]);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN (* nothing to be done *)
				ELSE
					Error(position,Diagnostics.Invalid,"string value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF IsCharacterValue(expression,char) THEN
				IF (type IS SyntaxTree.StringType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN
					string[0] := char; string[1] := 0X;
					type := SyntaxTree.NewStringType(InvalidPosition,system.characterType,2);
					result := SyntaxTree.NewStringValue(expression.position,string);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.ByteType) THEN
					(* do not simply set the new type as this could invalidate types of constants *)
					result := SyntaxTree.NewCharacterValue(expression.position,char);
					result.SetType(type)
				ELSIF (type IS SyntaxTree.IntegerType) THEN
					result := SyntaxTree.NewIntegerValue(expression.position,SYSTEM.VAL(LONGINT,char));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.SetType) THEN
					result := SyntaxTree.NewSetValue(expression.position,SYSTEM.VAL(SET,char));
					result.SetType(type);
				ELSIF (type IS SyntaxTree.CharacterType) THEN
					result := SyntaxTree.NewCharacterValue(expression.position,char);
					result.SetType(type);
				ELSIF (type IS SyntaxTree.PortType) THEN
					result := ConvertValue(position, expression, system.integerType);
				ELSE
					Error(position,Diagnostics.Invalid,"character value cannot be converted");
					result := SyntaxTree.invalidExpression;
				END;
			ELSIF expression IS SyntaxTree.NilValue THEN
				IF type IS SyntaxTree.AddressType THEN
					result := SyntaxTree.NewIntegerValue(position,0);
					result.SetType(type);
				ELSE
					result := expression;
				END;
				(* nothing to be done *)
			ELSIF expression IS SyntaxTree.MathArrayValue THEN
				result := MathArrayConversion(position, expression,type);
			ELSIF expression IS SyntaxTree.EnumerationValue THEN
				int := expression(SyntaxTree.EnumerationValue).value;
				IF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.SizeType) THEN
					int := Global.ConvertSigned(int,system.SizeOf(type));
					result := SyntaxTree.NewIntegerValue(position,int);
					result.SetType(type);
				ELSE
					result := expression;
				END;
				(* nothing to be done *)
			ELSE
				Error(position,Diagnostics.Invalid,"expression cannot be converted");
				IF VerboseErrorMessage THEN
					Printout.Info("expression",expression);
					Printout.Info("type",type);
				END;
				result := SyntaxTree.invalidExpression;
			END;
			RETURN result
		END ConvertValue;

		(**
			return a conversion of an expression to a given type
				- if expression is already of same type then return expression
				- if incompatible conversion then report error and return invalidExpression
		**)
		PROCEDURE NewConversion*(position: LONGINT; expression: SyntaxTree.Expression; type: SyntaxTree.Type; reference: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; value: SyntaxTree.Expression; expressionList: SyntaxTree.ExpressionList; typeDeclaration: SyntaxTree.TypeDeclaration; typeSymbol: SyntaxTree.Designator;
		BEGIN
			type := type.resolved;

			ASSERT(type # NIL); ASSERT(~(type IS SyntaxTree.QualifiedType));
			result := expression;

			IF expression = SyntaxTree.invalidExpression THEN (* error already handled *)
			ELSIF expression = NIL THEN (* NIL expression *)
			ELSIF expression.type = NIL THEN
				Error(position,Diagnostics.Invalid,"expression of type NIL cannot be converted");
			ELSIF expression.type.SameType(type) THEN (* nothing to be done ! *)
			ELSIF IsPointerType(expression.type) & IsPointerType(type) THEN (* nothing to be done *)
			ELSIF (expression.type.resolved IS SyntaxTree.AnyType) THEN (*! binary symbol file problem: ANY and OBJECT cannot be distinguished  *)
			ELSIF (expression.type.resolved IS SyntaxTree.ObjectType) & (type IS SyntaxTree.AnyType) THEN (*! binary symbol file problem *)
			ELSIF expression.resolved # NIL THEN (* value *)
				value := ConvertValue(position,expression.resolved(SyntaxTree.Value),type);
				IF value IS SyntaxTree.Value THEN
					result := SyntaxTree.NewConversion(expression.position,expression,type,reference);
					result.SetResolved(value(SyntaxTree.Value));
					result.SetType(value.type);
				ELSE
					result := value
				END;
			ELSIF (type IS SyntaxTree.ByteType) THEN (* do not convert *)
				expressionList := SyntaxTree.NewExpressionList();
				typeDeclaration := SyntaxTree.NewTypeDeclaration(expression.position,SyntaxTree.NewIdentifier("@byte"));
				typeDeclaration.SetDeclaredType(type);
				typeSymbol := SyntaxTree.NewSymbolDesignator(InvalidPosition,NIL,typeDeclaration);
				typeSymbol.SetType(typeDeclaration.type);
				expressionList.AddExpression(typeSymbol); (* type declaration symbol skipped *)
				expressionList.AddExpression(expression);
				result := SyntaxTree.NewBuiltinCallDesignator(expression.position,Global.systemVal,NIL,expressionList);
				result.SetType(type);
			ELSIF IsArrayStructuredObjectType(type) THEN
				(* no type can be converted to an array-structured object type *)
				HALT(100)
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				IF expression.type.resolved IS SyntaxTree.MathArrayType THEN
					result := MathArrayConversion(position, expression,type);
				ELSIF IsArrayStructuredObjectType(expression.type) THEN
					expression := ConvertToMathArray(expression);
					type := MathArrayStructureOfType(type);
					result := MathArrayConversion(position, expression, type)
				ELSE
					Error(expression.position,Diagnostics.Invalid,"cannot convert non array type to array type")
				END;
			ELSIF (expression.type.resolved IS SyntaxTree.MathArrayType) THEN
					IF (expression.type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static)
						OR ~(type IS SyntaxTree.ArrayType) THEN
						Error(expression.position,Diagnostics.Invalid,"cannot convert array type to non-array type")
					END;
			ELSIF ~(type IS SyntaxTree.BasicType) & ~(expression.type.resolved IS SyntaxTree.CharacterType) THEN
				(*skip, no conversion*)
			ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
				(* skip, no conversion *)
			ELSE
				ASSERT(~(type IS SyntaxTree.RangeType));
				result := SyntaxTree.NewConversion(expression.position,expression,type,reference);
				ASSERT(type # NIL);
			END;
			RETURN result
		END NewConversion;

		PROCEDURE CompatibleConversion(position: LONGINT; expression: SyntaxTree.Expression; type: SyntaxTree.Type): SyntaxTree.Expression;
		BEGIN
			IF CompatibleTo(system,expression.type, type) THEN
				RETURN NewConversion(position, expression, type, NIL);
			ELSE
				Error(expression.position, Diagnostics.Invalid, "incompatible expression");
				RETURN SyntaxTree.invalidExpression
			END;
		END CompatibleConversion;

		(**
			convert operands left and right to a type that both operands are compatible with, if no such type exists then report error
		**)
		PROCEDURE ConvertOperands(VAR left,right: SyntaxTree.Expression);
		VAR leftType,rightType: SyntaxTree.Type;
		BEGIN
			IF left.type = NIL THEN Error(left.position,Diagnostics.Invalid,"no type")
			ELSIF right.type= NIL THEN Error(right.position,Diagnostics.Invalid,"no type")
			ELSIF (left = SyntaxTree.invalidExpression) OR (right = SyntaxTree.invalidExpression) THEN
				(* error already handled *)
			ELSE
				leftType := left.type.resolved; rightType := right.type.resolved;
				IF (leftType IS SyntaxTree.AddressType) & IsAddressExpression(right) THEN
					right := NewConversion(right.position, right, leftType, NIL);
				ELSIF (rightType IS SyntaxTree.AddressType) & IsAddressExpression(left) THEN
					left := NewConversion(left.position,left,rightType,NIL);
				ELSIF (leftType IS SyntaxTree.SizeType) & IsSizeExpression(right) THEN
					right := NewConversion(right.position, right, leftType, NIL);
				ELSIF (rightType IS SyntaxTree.SizeType) & IsSizeExpression(left) THEN
					left := NewConversion(left.position,left,rightType,NIL);
				ELSIF CompatibleTo(system,leftType,rightType) THEN
					left := NewConversion(left.position,left,right.type.resolved,NIL);
				ELSIF CompatibleTo(system,rightType,leftType) THEN
					right := NewConversion(right.position,right,left.type.resolved,NIL);
				ELSIF
					(leftType IS SyntaxTree.ComplexType) & (rightType IS SyntaxTree.FloatType) OR
					(leftType IS SyntaxTree.FloatType) & (rightType IS SyntaxTree.ComplexType) THEN
					(* must be the case LONGREAL / COMPLEX ) *)
					left := NewConversion(left.position, left, Global.Complex128, NIL);
					right := NewConversion(right.position, right, Global.Complex128, NIL);
				ELSE
					Error(left.position,Diagnostics.Invalid,"incompatible operands");
				END;
			END;
		END ConvertOperands;

		(** find and return best operator matching to parameter list (nil, if none)
			- search current module scope and all (directly or indirectly) imported modules for matching operator
			- take operator with smalles distance, where signature distance is computed in procedure Distance
		**)
		PROCEDURE FindOperator*(system: Global.System; operator: LONGINT; actualParameters: SyntaxTree.ExpressionList; returnType: SyntaxTree.Type): SyntaxTree.Operator;
		VAR bestOperator: SyntaxTree.Operator; bestDistance: LONGINT; import: SyntaxTree.Import; numberParameters: LONGINT; procedureType: SyntaxTree.ProcedureType;
			identifier: SyntaxTree.Identifier;

			PROCEDURE FindInScope(scope: SyntaxTree.ModuleScope; access: SET);
			VAR operator: SyntaxTree.Operator; distance,i: LONGINT;
			BEGIN
				operator := scope.firstOperator;
				WHILE(operator # NIL) DO
					IF (operator.name=identifier) & (operator.access * access # {}) THEN
						procedureType := operator.type(SyntaxTree.ProcedureType);
						distance := Distance(system, procedureType,actualParameters);
						IF (distance < Infinity) THEN
							IF returnType # NIL THEN
								IF procedureType.returnType = NIL THEN
									distance := Infinity
								ELSE
									i := TypeDistance(system,returnType,procedureType.returnType,TRUE);
									IF i = Infinity THEN distance := Infinity ELSE INC(distance,i) END;
								END;
							END;
						END;

						(*
						IF distance < Infinity THEN
							TRACE(distance, operator);
							Printout.Info("potential operator",operator);
						ELSE
							Printout.Info("operator not possible",operator);
						END;
						*)

						IF distance < bestDistance THEN
							bestDistance := distance;
							bestOperator := operator;
						END;
					END;
					operator := operator.nextOperator;
				END;
				(*
				Printout.Info("taken operator",bestOperator);
				*)
			END FindInScope;

		BEGIN
			bestDistance := Infinity; bestOperator := NIL; numberParameters := actualParameters.Length();
			identifier := Global.GetIdentifier(operator,currentScope.ownerModule.case);
			FindInScope(currentScope.ownerModule.moduleScope,SyntaxTree.ReadOnly);
			import := currentScope.ownerModule.moduleScope.firstImport;
			WHILE (bestDistance > 0) & (import # NIL) DO
				IF import.module # NIL THEN
					identifier := Global.GetIdentifier(operator,import.module.case);
					FindInScope(import.module.moduleScope,SyntaxTree.Public);
				END;
				import := import.nextImport;
			END;
			RETURN bestOperator
		END FindOperator;

		PROCEDURE SetCurrentScope*(scope: SyntaxTree.Scope);
		BEGIN
			currentScope := scope;
		END SetCurrentScope;

		(**
			return a procedure call designator for the best matching operator procedure of the form "op"(leftExpression,rightExpression) (if any)
			- handle LEN and DIM operator for array-structured object types
			- find operator, if found then
				- if in other module then add import designator
				- create symbol designator for operator
			- if error then return invalidExpression, if no operator then return NIL
		**)
		PROCEDURE NewOperatorCall*(position: LONGINT; op: LONGINT; leftExpression, rightExpression: SyntaxTree.Expression; resultType: SyntaxTree.Type): SyntaxTree.Expression;
		VAR
			operator: SyntaxTree.Operator;
			import: SyntaxTree.Import;
			expression, result: SyntaxTree.Expression;
			designator: SyntaxTree.Designator;
			actualParameters, tempList: SyntaxTree.ExpressionList;
			recordType: SyntaxTree.RecordType;
			castReturnType : SyntaxTree.MathArrayType;
		BEGIN
			IF (leftExpression = SyntaxTree.invalidExpression) OR (rightExpression = SyntaxTree.invalidExpression)  THEN
				result := SyntaxTree.invalidExpression

			ELSIF leftExpression = NIL THEN
				result := NIL

			ELSIF IsArrayStructuredObjectType(leftExpression.type) & ((op = Global.Len) OR (op = Global.Dim)) THEN
				(* LEN or DIM operator on array-structured object type *)
				ASSERT(leftExpression.type.resolved IS SyntaxTree.PointerType);
				recordType := leftExpression.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
				IF recordType.arrayAccessOperators.len = NIL THEN
					Error(position, Diagnostics.Invalid, "call of undeclared LEN operator");
					result := SyntaxTree.invalidExpression
				ELSE
					ASSERT(leftExpression IS SyntaxTree.Designator);
					designator := leftExpression(SyntaxTree.Designator);
					expression := NewSymbolDesignator(InvalidPosition, NewDereferenceDesignator(position, designator), recordType.arrayAccessOperators.len);
					ASSERT(expression IS SyntaxTree.Designator);
					designator := NewProcedureCallDesignator(InvalidPosition, expression(SyntaxTree.Designator), SyntaxTree.NewExpressionList());

					IF (op = Global.Len) & (rightExpression = NIL) THEN
						(* LEN(OBJECT) -> OBJECT^."LEN"() *)
						result := designator

					ELSIF (op = Global.Len) & (rightExpression # NIL) & (rightExpression.type.resolved IS SyntaxTree.IntegerType) THEN
						(* LEN(OBJECT, LONGINT) -> OBJECT^."LEN"()[LONGINT] *)
						tempList := SyntaxTree.NewExpressionList();
						tempList.AddExpression(rightExpression);
						result := ResolveDesignator(SyntaxTree.NewBracketDesignator(InvalidPosition, designator, tempList))

					ELSIF (op = Global.Dim) & (rightExpression = NIL) THEN
						(* DIM(OBJECT) -> LEN(OBJECT^."LEN"(), 0) *)
						tempList := SyntaxTree.NewExpressionList();
						tempList.AddExpression(designator);
						tempList.AddExpression(SyntaxTree.NewIntegerValue(InvalidPosition, 0));
						designator := SyntaxTree.NewIdentifierDesignator(InvalidPosition, Global.GetIdentifier(Global.Len, module.case));
						result := ResolveExpression(SyntaxTree.NewParameterDesignator(InvalidPosition, designator, tempList))
					END
				END;
			ELSE
				(* import OCArrayBase if needed *)
				IF ~arrayBaseImported THEN
					IF (leftExpression # NIL) & IsComplexType(leftExpression.type) THEN
						(* operators on complex numbers *)
						ImportModule(Global.ArrayBaseName,position);
						arrayBaseImported := TRUE;
					ELSIF (leftExpression # NIL) & IsMathArrayType(leftExpression.type) OR (rightExpression # NIL) & IsMathArrayType(rightExpression.type) THEN
						IF op = Global.Dim THEN
							(* not existing in OCArrayBase *)
						ELSIF (op = Global.Len) & (rightExpression # NIL) THEN
							(* not existing in OCArrayBase *)
						ELSE
							ImportModule(Global.ArrayBaseName,position);
							arrayBaseImported := TRUE;
						END
					ELSIF (leftExpression # NIL) & IsArrayStructuredObjectType(leftExpression.type) OR (rightExpression # NIL) & IsArrayStructuredObjectType(rightExpression.type) THEN
						ImportModule(Global.ArrayBaseName,position);
						arrayBaseImported := TRUE
					END;
					IF (op = Global.Len) & (leftExpression # NIL) & IsRangeType(leftExpression.type) & (rightExpression = NIL) THEN
						(* LEN(RANGE) *)
						ImportModule(Global.ArrayBaseName,position);
						arrayBaseImported := TRUE;
					END;
				END;

				actualParameters := SyntaxTree.NewExpressionList();
				actualParameters.AddExpression(leftExpression);
				IF rightExpression # NIL THEN
					actualParameters.AddExpression(rightExpression)
				END;
				operator := FindOperator(system,op,actualParameters,resultType);
				IF operator # NIL THEN
					designator := NIL;
					IF operator.scope.ownerModule # currentScope.ownerModule THEN
						import := currentScope.ownerModule.moduleScope.firstImport;
						WHILE(import # NIL) & (import.module # operator.scope.ownerModule) DO
							import := import.nextImport;
						END;
						expression := NewSymbolDesignator(position,NIL,import);
						designator := expression(SyntaxTree.Designator);
					END;
					expression := NewSymbolDesignator(position,designator,operator);
					designator := expression(SyntaxTree.Designator);
					result := NewProcedureCallDesignator(position,designator,actualParameters);
					IF op = Scanner.Alias THEN (* hard type cast to same type *)
						castReturnType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid, expression.type.scope,SyntaxTree.Tensor);
						castReturnType.SetArrayBase(ArrayBase(leftExpression.type.resolved,MAX(LONGINT)));
						result.SetType(castReturnType);
					END;
				ELSE
					result := NIL;
				END;
			END;
			RETURN result
		END NewOperatorCall;

		(** check and resolve binary expression **)
		(*! clean up *)
		PROCEDURE VisitBinaryExpression(binaryExpression: SyntaxTree.BinaryExpression);
		VAR left,right,result: SyntaxTree.Expression;
			leftType, rightType: SyntaxTree.Type;
			il,ir: LONGINT; rl,rr,a,b,c,d,divisor: LONGREAL; hl,hr: HUGEINT;bl,br: BOOLEAN; sl,sr: SET;  strl,strr: Scanner.StringType;
			cl,cr: CHAR;
			operator: LONGINT; operatorCall: SyntaxTree.Expression;
			type: SyntaxTree.Type;
			value: SyntaxTree.Value;
			leftFirst, leftLast, leftStep, rightFirst, rightLast, rightStep: LONGINT;
			integerConstantFolding: BOOLEAN;

			PROCEDURE NewBool(v: BOOLEAN);
			BEGIN
				value := SyntaxTree.NewBooleanValue(binaryExpression.position,v);
				value.SetType(system.booleanType);
				result.SetResolved(value);
				type := system.booleanType
			END NewBool;

			PROCEDURE NewSet(v: SET);
			BEGIN
				value := SyntaxTree.NewSetValue(binaryExpression.position,v);
				value.SetType(system.setType);
				result.SetResolved(value);
				type := system.setType;
			END NewSet;

			PROCEDURE NewInteger(v: HUGEINT; t: SyntaxTree.Type);
			BEGIN
				value := Global.NewIntegerValue(system,binaryExpression.position,v);

				(* type cast to "larger" type only if the value is still in the range *)
				IF (t IS SyntaxTree.AddressType) & IsAddressValue(value) THEN
					value.SetType(t);
				END;

				result.SetResolved(value);
				type := value.type;
			END NewInteger;

			PROCEDURE NewReal(v: LONGREAL; t: SyntaxTree.Type);
			BEGIN
				value := SyntaxTree.NewRealValue(binaryExpression.position,v);
				value.SetType(t);
				result.SetResolved(value);
				type := t;
			END NewReal;

			PROCEDURE NewComplex(realValue, imagValue: LONGREAL; t: SyntaxTree.Type);
			BEGIN
				value := SyntaxTree.NewComplexValue(binaryExpression.position, realValue, imagValue);
				value.SetType(t);
				value(SyntaxTree.ComplexValue).UpdateSubtype;
				result.SetResolved(value);
				type := t;
			END NewComplex;

		BEGIN
			type := SyntaxTree.invalidType;
			left := ResolveExpression(binaryExpression.left);
			right := ResolveExpression(binaryExpression.right);
			binaryExpression.SetLeft(left);
			binaryExpression.SetRight(right);

			result := binaryExpression;
			operator := binaryExpression.operator;
			IF ~system.operatorDefined[operator] THEN
				Error(left.position,Diagnostics.Invalid,"Operator Not Defined");
				result := SyntaxTree.invalidExpression;
				RETURN
			END;
			IF left.type = NIL THEN
				Error(left.position,Diagnostics.Invalid,"Expression has no result type");
				result := SyntaxTree.invalidExpression;
				RETURN;
			END;
			IF right.type = NIL THEN
				Error(right.position,Diagnostics.Invalid,"Expression has no result type");
				result := SyntaxTree.invalidExpression;
				RETURN;
			END;
			leftType := left.type.resolved; rightType := right.type.resolved;
			IF ~(leftType IS SyntaxTree.BasicType) OR ~(rightType IS SyntaxTree.BasicType) OR (leftType IS SyntaxTree.ComplexType) OR (rightType IS SyntaxTree.ComplexType) THEN
				operatorCall := NewOperatorCall(binaryExpression.position,operator,left,right,NIL);
			END;

			IF operatorCall # NIL THEN
				result := operatorCall;
				type := operatorCall.type;

			(* admissible operators:

				Times, Plus, Minus		numeric		numeric		numeric
											set				set				set
				Slash 						numeric		numeric		real	/complex
											set				set				set
				Div , Mod					integer			integer			integer
				And, Or					bool			bool			bool
				Equal, Unequal 			basic			basic			bool
											pointer 		pointer 		bool
											object			object			bool
											record			record			bool
											string			string			bool
											enumerator	enumerator	bool

				Less, LessEqual,
				Greater, GreaterEqual		integer/real	integer/real	bool
											enumerator	enumerator	bool

				In							integer			set				bool
				Is							pointer			type			bool
				 							object			type			bool
				 							record			type			bool

				 Upto: special abbreviation for a..b
			*)

			ELSIF (left.type = NIL) THEN
				Error(left.position,Diagnostics.Invalid,"type (left operand) = NIL in binary expression");
				D.Str("nil type in "); D.Type(left); D.Ln;
				result := SyntaxTree.invalidExpression;
			ELSIF (right.type = NIL) THEN
				Error(right.position,Diagnostics.Invalid,"type (right operand) = NIL in binary expression");
				result := SyntaxTree.invalidExpression;
			ELSIF (leftType = SyntaxTree.invalidType) OR (rightType = SyntaxTree.invalidType) THEN (* error already handled *)
				result := SyntaxTree.invalidExpression;
			ELSIF operator = Scanner.Upto THEN (* left .. right: now solved as RangeExpression*)
				HALT(100);
			ELSIF operator = Scanner.Is THEN (* left IS right: now solved as IsExpression *)
				type := system.booleanType;
				IF  ~(rightType = SyntaxTree.typeDeclarationType) THEN
					Error(right.position,Diagnostics.Invalid,"is not a type ");
				ELSIF ~IsTypeExtension(leftType, right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved) THEN
					Error(binaryExpression.position,Diagnostics.Invalid,"is not a  type extension of ");
					IF VerboseErrorMessage THEN
						Printout.Info("left",left);
						Printout.Info("right",right);
					END;
				ELSIF (leftType.SameType(right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved)) & ~(leftType IS SyntaxTree.PointerType) THEN
					NewBool(TRUE)
				ELSIF right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved IS SyntaxTree.AnyType THEN
					NewBool(TRUE);
				ELSIF IsUnextensibleRecord(left) THEN
					NewBool(FALSE)
				END
			ELSIF (right IS SyntaxTree.SymbolDesignator) & (right(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(right.position,Diagnostics.Invalid,"must not be a type");
			ELSIF (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.TypeDeclaration) THEN
				Error(left.position,Diagnostics.Invalid,"must not be a type");
			ELSIF operator = Scanner.In THEN (* left IN right *)
				IF IsIntegerType(leftType) & (rightType IS SyntaxTree.SetType) THEN
					IF IsIntegerValue(left,il) & IsSetValue(right,sr) THEN
						NewBool(il IN sr);
					ELSE
						IF leftType.sizeInBits # system.longintType.sizeInBits THEN
							left := NewConversion(left.position, left, system.longintType,NIL);
							binaryExpression.SetLeft(left)
						END;
						type := system.booleanType;
					END
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid, "incompatible operands");
				END
			ELSIF (leftType IS SyntaxTree.ProcedureType) OR (rightType IS SyntaxTree.ProcedureType) THEN
				IF ~CompatibleTo(system,leftType,rightType) & ~CompatibleTo(system,rightType,leftType) THEN
					Error(binaryExpression.position,Diagnostics.Invalid,"incompatible operands");
				END;

				IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN type := system.booleanType
				ELSE  Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 1")
				END
			ELSIF IsPointerType(leftType) OR IsPointerType(rightType) THEN
				IF ~CompatibleTo(system,leftType,rightType) & ~CompatibleTo(system,rightType,leftType) THEN
				(* IsPointerType(leftType) OR ~IsPointerType(rightType) THEN *)
					Error(binaryExpression.position,Diagnostics.Invalid,"incompatible operands");
					IF VerboseErrorMessage THEN Printout.Info("leftType",leftType); Printout.Info("right",rightType) END
				ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN
					IF (left IS SyntaxTree.NilValue) & (right IS SyntaxTree.NilValue) THEN
						IF operator = Scanner.Equal THEN NewBool(TRUE) ELSE NewBool(FALSE) END;
					END;
					type := system.booleanType;
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 3");
				END
			ELSIF (left.resolved# NIL) & (left.resolved IS SyntaxTree.NilValue) THEN Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined");
			ELSIF (right.resolved # NIL) & (right.resolved IS SyntaxTree.NilValue) THEN Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined");
			ELSIF IsStringType(leftType) & IsStringType(rightType) THEN		(* string ops*)
				IF IsStringType(leftType) & IsStringType(rightType) THEN	(*ok*)
					IF IsStringValue(left,strl) & IsStringValue(right,strr) THEN
						CASE operator OF
						|Scanner.Equal: NewBool(strl^=strr^);
						|Scanner.Unequal:NewBool(strl^#strr^);
						|Scanner.Less: NewBool(strl^<strr^);
						|Scanner.LessEqual: NewBool(strl^<=strr^);
						|Scanner.Greater:  NewBool(strl^>strr^);
						|Scanner.GreaterEqual: NewBool(strl^>=strr^);
						ELSE
							Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 4");
						END;
					END;
				ELSIF (operator = Scanner.Equal) OR (operator=Scanner.Unequal) OR (operator = Scanner.Less)
						OR (operator = Scanner.LessEqual) OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 5");
				END;
				IF (operator = Scanner.Equal) OR (operator=Scanner.Unequal)
					OR 	(operator = Scanner.Less) OR (operator = Scanner.LessEqual)
					OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
					type := system.booleanType;
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 6");
				END
			ELSIF (leftType IS SyntaxTree.EnumerationType) OR (rightType IS SyntaxTree.EnumerationType) THEN
				IF IsEnumerationExtension(left.type,right.type) OR IsEnumerationExtension(right.type,left.type) THEN
					IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined for enumerators");
					END;
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid,"operator not applicable between different enumerators");
				END;
			ELSIF (leftType IS SyntaxTree.PortType) & ((operator = Scanner.Questionmarks) OR (operator = Scanner.ExclamationMarks) OR (operator = Scanner.LessLessQ)) THEN
				type := system.booleanType;
			ELSIF (rightType IS SyntaxTree.PortType) & (operator = Scanner.LessLessQ) THEN
				type := system.booleanType;
			ELSIF (leftType IS SyntaxTree.BasicType) & (rightType IS SyntaxTree.BasicType)
				OR IsCharacterType(leftType) & IsCharacterType(rightType)
			THEN
				integerConstantFolding := IsIntegerValue(left,il) & IsIntegerValue(right,ir);
				IF (leftType # rightType)   THEN
					IF ~integerConstantFolding THEN (* no conversions for constant folding on integer values  *)
						ConvertOperands(left,right); (* operands must be of the same type here *)
					END;
					binaryExpression.SetLeft(left);
					binaryExpression.SetRight(right);
					leftType := left.type.resolved;
					rightType := right.type.resolved;
				END;
				type := leftType;
				IF ~integerConstantFolding & ~leftType.SameType(rightType) THEN
					Error(binaryExpression.position,Diagnostics.Invalid,"conversion failed ?");
					IF VerboseErrorMessage THEN
						Printout.Info("left",left);
						Printout.Info("right",right);
					END;
				ELSIF IsIntegerType(leftType) THEN
					IF IsIntegerValue(right,ir) (* & (right.type.sizeInBits < 64) *) THEN
						hr := right.resolved(SyntaxTree.IntegerValue).hvalue;
						IF (hr=0) & ((operator = Scanner.Mod) OR (operator = Scanner.Div) OR (operator = Scanner.Slash)) THEN
							Error(binaryExpression.position,Diagnostics.Invalid,"division by zero");
						ELSIF (hr<0) & ((operator = Scanner.Mod) OR (operator = Scanner.Div))THEN
							Error(binaryExpression.position,Diagnostics.Invalid,"integer division by negative number");
						END;
					END;
					(* constant folding *)
					(* bootstrap64
					IF IsIntegerValue(left,il) & IsIntegerValue(right,ir)  & (type.sizeInBits < 64) THEN
						CASE operator OF
						|Scanner.Plus: NewInteger(il+ir,left.type);
						|Scanner.Minus: NewInteger(il-ir,left.type);
						|Scanner.Times: NewInteger(il*ir,left.type);
						|Scanner.Slash:
							IF ir # 0 THEN
								NewReal(il/ir, system.realType);
							END;
						|Scanner.Mod:
							IF ir > 0 THEN
								NewInteger(il MOD ir,left.type);
							END;
						|Scanner.Div:
							IF ir > 0 THEN
								NewInteger(il DIV ir,left.type);
							END;
						|Scanner.Equal: NewBool(il=ir);
						|Scanner.Unequal:NewBool(il#ir);
						|Scanner.Less: NewBool(il<ir);
						|Scanner.LessEqual: NewBool(il<=ir);
						|Scanner.Greater:  NewBool(il>ir);
						|Scanner.GreaterEqual: NewBool(il>=ir);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 7");
						END;
					ELS*)
					IF IsIntegerValue(left,il) & IsIntegerValue(right,ir) (* bootstrap64 & (type.sizeInBits = 64)*) THEN
						hl := left.resolved(SyntaxTree.IntegerValue).hvalue;
						hr := right.resolved(SyntaxTree.IntegerValue).hvalue;
						CASE operator OF
						|Scanner.Plus: NewInteger(hl+hr,left.type);
						|Scanner.Minus: NewInteger(hl-hr,left.type);
						|Scanner.Times: NewInteger(hl*hr,left.type);
						|Scanner.Slash:
							IF hr = 0 THEN
								Error(binaryExpression.position,Diagnostics.Invalid,"division by zero");
							ELSE
								IF type.sizeInBits = 64 THEN
									NewReal(hl/hr,system.longrealType);
								ELSE
									NewReal(hl/hr,system.realType)
								END
							END;
						(* do the bootstrapping for this kind of expression on hugeint values , then enable: *)
						|Scanner.Mod:
							IF hr = 0 THEN
								Error(binaryExpression.position,Diagnostics.Invalid,"division by zero");
							ELSE
								NewInteger(hl MOD hr, left.type);
								(* bootstrap64
								NewInteger(hl - Machine.DivH(hl,hr)*hr,left.type);
								*)
							END;
						|Scanner.Div:
							IF hr = 0 THEN
								Error(binaryExpression.position,Diagnostics.Invalid,"division by zero");
							ELSE
								NewInteger(hl DIV hr, left.type);
								(* bootstrap64
								NewInteger(Machine.DivH(hl,hr),left.type);
								*)
							END;
						(* *)
						|Scanner.Equal: NewBool(hl=hr);
						|Scanner.Unequal: NewBool(hl#hr);
						|Scanner.Less: NewBool(hl<hr);
						|Scanner.LessEqual: NewBool(hl<=hr);
						|Scanner.Greater: NewBool(hl>hr);
						|Scanner.GreaterEqual:NewBool(hl>=hr);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 8");
						END;
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR
					(operator = Scanner.Mod) OR (operator = Scanner.Div) THEN
						type := left.type
					ELSIF (operator = Scanner.Slash) THEN
						left := NewConversion(left.position,left,system.realType,NIL);
						right := NewConversion(right.position,right,system.realType,NIL);
						binaryExpression.SetLeft(left);
						binaryExpression.SetRight(right);
						type := system.realType
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 9");
					END;
				ELSIF (leftType IS SyntaxTree.FloatType) THEN
					IF IsRealValue(left,rl) & IsRealValue(right,rr) THEN
						CASE operator OF
						|Scanner.Plus: NewReal(rl+rr,leftType);
						|Scanner.Minus: NewReal(rl-rr,leftType);
						|Scanner.Times:NewReal(rl*rr,leftType);
						|Scanner.Slash:
							IF rr = 0 THEN
								Error(binaryExpression.position,Diagnostics.Invalid,"division by zero");
							ELSE
								NewReal(rl/rr,leftType);
							END
						|Scanner.Equal: NewBool(rl=rr);
						|Scanner.Unequal: NewBool(rl#rr);
						|Scanner.Less: NewBool(rl<rr);
						|Scanner.LessEqual:  NewBool(rl<=rr);
						|Scanner.Greater:  NewBool(rl>rr);
						|Scanner.GreaterEqual: NewBool(rl>=rr);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 10");
						END;
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR (operator = Scanner.Slash) THEN
						type := left.type
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 11");
						IF VerboseErrorMessage THEN
							Printout.Info("left",left);
							Printout.Info("right",right);
						END;
					END;
				ELSIF (leftType IS SyntaxTree.ComplexType) THEN
					CASE operator OF
					|Scanner.Plus, Scanner.Minus, Scanner.Times, Scanner.Slash: type := left.type
					|Scanner.Equal, Scanner.Unequal: type := system.booleanType
					ELSE
						Error(binaryExpression.position, Diagnostics.Invalid,"operator not defined");
						IF VerboseErrorMessage THEN
							Printout.Info("left", left);
							Printout.Info("right", right)
						END;
					END;

					IF ~error THEN
						IF (operator = Scanner.Slash) & IsComplexValue(right, c, d) & (c = 0) & (d = 0) THEN
							Error(binaryExpression.position, Diagnostics.Invalid,"division by zero")
						ELSIF IsComplexValue(left, a, b) & IsComplexValue(right, c, d) THEN
							(* do constant folding *)
							CASE operator OF
							|Scanner.Plus: NewComplex(a + b, c + d, leftType)
							|Scanner.Minus: NewComplex(a - b, c - d, leftType)
							|Scanner.Times: NewComplex(a * c - b * d, b * c + a * d, leftType)
							|Scanner.Slash:
								divisor := c * c + d * d;
								ASSERT(divisor # 0);
								NewComplex((a * c + b * d) / divisor, (b * c - a * d) / divisor, leftType)
							|Scanner.Equal: NewBool((a = c) & (b = d))
							|Scanner.Unequal: NewBool((a # c) OR (b # d))
							END
						END
					END

				ELSIF (leftType IS SyntaxTree.BooleanType) THEN
					IF IsBooleanValue(left,bl) & IsBooleanValue(right,br) THEN
						CASE operator OF
						|Scanner.And: NewBool(bl & br);
						|Scanner.Or: NewBool(bl OR br);
						|Scanner.Equal: NewBool(bl = br);
						|Scanner.Unequal: NewBool(bl # br);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 12");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.And) OR (operator = Scanner.Or)  THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 13");
					END;
				ELSIF left.type.resolved IS SyntaxTree.RangeType THEN
					(* constant folding *)
					IF IsStaticRange(left, leftFirst, leftLast, leftStep) & IsStaticRange(right, rightFirst, rightLast, rightStep) THEN
						IF operator = Scanner.Equal THEN
							NewBool((leftFirst = rightFirst) & (leftLast = rightLast) & (leftStep = rightStep))
						ELSIF operator = Scanner.Unequal THEN
							NewBool((leftFirst # rightFirst) OR (leftLast # rightLast) OR (leftStep # rightStep))
						END;
					END;

					IF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) THEN
						type := system.booleanType;
					ELSE
						Error(binaryExpression.position, Diagnostics.Invalid, "operator not defined");
					END;
				ELSIF (leftType IS SyntaxTree.SetType) THEN
					IF IsSetValue(left,sl) & IsSetValue(right,sr) THEN
						CASE operator OF
						|Scanner.Plus: NewSet(sl + sr);
						|Scanner.Minus:  NewSet(sl - sr);
						|Scanner.Times:  NewSet(sl * sr);
						|Scanner.Slash:  NewSet(sl / sr);
						|Scanner.Equal:  NewBool(sl=sr);
						|Scanner.Unequal: NewBool(sl#sr);
						|Scanner.Less: NewBool( (sl * sr = sl) & (sl#sr));
						|Scanner.LessEqual: NewBool(sl*sr = sl);
						|Scanner.Greater: NewBool( (sl * sr = sr) & (sl # sr));
						|Scanner.GreaterEqual: NewBool(sl*sr = sr);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 14");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal)
						OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual)  (* implement inclusion *)
						THEN
						type := system.booleanType
					ELSIF (operator = Scanner.Plus) OR (operator = Scanner.Minus) OR (operator = Scanner.Times) OR (operator = Scanner.Slash) THEN
						type := left.type
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 15");
					END;
				ELSIF IsCharacterType(left.type) THEN
					IF IsCharacterValue(left,cl) & IsCharacterValue(right,cr) THEN
						CASE operator OF
						|Scanner.Equal:  NewBool(cl=cr);
						|Scanner.Unequal: NewBool(cl#cr);
						|Scanner.Less: NewBool(cl<cr);
						|Scanner.LessEqual:  NewBool(cl<=cr);
						|Scanner.Greater:  NewBool(cl>cr);
						|Scanner.GreaterEqual: NewBool(cl>=cr);
						ELSE Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 16");
						END;
					ELSIF (operator = Scanner.Equal) OR (operator = Scanner.Unequal) OR (operator = Scanner.Less) OR (operator = Scanner.LessEqual)
						OR (operator = Scanner.Greater) OR (operator = Scanner.GreaterEqual) THEN
						type := system.booleanType
					ELSE
						Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 17");
					END;
				ELSE
					Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 18");
				END;
			ELSE
				Error(binaryExpression.position,Diagnostics.Invalid,"operator not defined 19");
			END;
			IF type = SyntaxTree.invalidType THEN
				result := SyntaxTree.invalidExpression
			ELSE
				result.SetType(type)
			END;
			resolvedExpression := result
		END VisitBinaryExpression;

		(** resolve a range expression of the from <<first .. last BY step>>
		    - depending on the context different things are checked:
				ArrayIndex:
					- components must be integers
					- replace missing lower bound with 0
					- replace missing upper bound with MAX(LONGINT)
					- replace missing step size with 1
				SetElement:
					- components must be integers
					- replace missing lower bound with 0
					- replace missing upper bound with MAX(SET)
					- must not have step size
				CaseGuard:
					- components must be constant
					- components must be integers or characters
					- must have lower and upper bound present
					- components are made compatible
					- must not have step size
		    - if error: return invalidExpression
		**)
		PROCEDURE VisitRangeExpression(x: SyntaxTree.RangeExpression);
		VAR
			hasError: BOOLEAN;
			first, last, step: SyntaxTree.Expression;

		BEGIN
			hasError := FALSE;
			first := x.first;
			last := x.last;
			step := x.step;

			(* check lower bound *)
			IF x.context = SyntaxTree.CaseGuard THEN
				IF first = NIL THEN
					Error(x.position, Diagnostics.Invalid, "missing lower bound");
					hasError := TRUE
				ELSE
					first := ResolveExpression(first);
					IF ~(first.type.resolved IS SyntaxTree.IntegerType) & ~IsCharacterType(first.type.resolved) THEN
						Error(first.position, Diagnostics.Invalid, "lower bound not integer or character");
						hasError := TRUE
					ELSE
						IF first IS SyntaxTree.StringValue THEN
							(* add conversion from string to character *)
							first := ConvertValue(first.position, first(SyntaxTree.Value), system.characterType)
						END
					END;

					(* check if expression is constant *)
					IF ConstantExpression(first) = SyntaxTree.invalidExpression THEN
						(* error already reported *)
						hasError := TRUE
					END
				END

			ELSE (* ArrayIndex, SetElement *)
				IF first = NIL THEN
					first := SyntaxTree.NewIntegerValue(x.position, 0);
				END;
				first := ResolveExpression(first);
				IF first.type.resolved IS SyntaxTree.IntegerType THEN
					first := NewConversion(first.position, first, system.longintType, NIL)
				ELSE
					Error(first.position, Diagnostics.Invalid, "lower bound not integer");
					hasError := TRUE
				END
			END;

			(* check upper bound *)
			IF x.context = SyntaxTree.CaseGuard THEN
				IF last = NIL THEN
					Error(x.position, Diagnostics.Invalid, "missing upper bound");
					hasError := TRUE
				ELSE
					last := ResolveExpression(last);
					IF ~(last.type.resolved IS SyntaxTree.IntegerType) & ~IsCharacterType(last.type.resolved) THEN
						Error(last.position, Diagnostics.Invalid, "lower bound not integer or character");
						hasError := TRUE
					ELSE
						IF last IS SyntaxTree.StringValue THEN
							(* add conversion from string to character *)
							last := ConvertValue(last.position, last(SyntaxTree.Value), system.characterType)
						END
					END;

					(* check if expression is constant *)
					IF ConstantExpression(last) = SyntaxTree.invalidExpression THEN
						(* error already reported *)
						hasError := TRUE
					ELSE
						(* try to make lower and upper bound compatible *)
						ConvertOperands(first, last);
						IF first.type.resolved # last.type.resolved THEN
							Error(x.position, Diagnostics.Invalid, "lower and upper bounds incompatible");
							hasError := TRUE
						END
					END
				END

			ELSE (* ArrayIndex, SetElement *)
				IF last = NIL THEN
					IF x.context = SyntaxTree.ArrayIndex THEN
						last := SyntaxTree.NewIntegerValue(x.position, MAX(LONGINT))
					ELSE
						last := SyntaxTree.NewIntegerValue(x.position, MAX(SET))
					END
				END;
				last := ResolveExpression(last);
				IF last.type.resolved IS SyntaxTree.IntegerType THEN
					last := NewConversion(last.position, last, system.longintType, NIL)
				ELSE
					Error(last.position, Diagnostics.Invalid, "upper bound not integer");
					hasError := TRUE
				END
			END;

			(* check step size *)
			IF x.context = SyntaxTree.ArrayIndex THEN
				IF step = NIL THEN
					step := SyntaxTree.NewIntegerValue(x.position, 1)
				END;
				step := ResolveExpression(step);
				IF step.type.resolved IS SyntaxTree.IntegerType THEN
					step := NewConversion(step.position, step, system.longintType, NIL)
				ELSE
					Error(step.position, Diagnostics.Invalid, "step size not integer");
					hasError := TRUE
				END
			ELSE (* SetElement, CaseGuard *)
				IF step # NIL THEN
					Error(last.position, Diagnostics.Invalid, "step size not allowed in this context");
					hasError := TRUE
				END
			END;

			IF hasError THEN
				resolvedExpression := SyntaxTree.invalidExpression
			ELSE
				x.SetFirst(first);
				x.SetLast(last);
				x.SetStep(step);
				x.SetType(system.rangeType);
				resolvedExpression := x;
				resolvedExpression.SetAssignable(FALSE) (* range expressions may never be assigned to *)
			END
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression(x: SyntaxTree.TensorRangeExpression);
		BEGIN
			x.SetType(NIL);
			resolvedExpression := x;
		END VisitTensorRangeExpression;

		(** resolve the expression d and return result as designator
			- resolve expression
			- if expression is a designator then return designator else error message and return invalidDesignator
		**)
		PROCEDURE ResolveDesignator*(d: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator; resolved: SyntaxTree.Expression;
		BEGIN
			IF Trace THEN D.Str("ResolveDesignator"); D.Ln; END;
			resolved := ResolveExpression(d);
			IF resolved = SyntaxTree.invalidExpression THEN
				(* error should already have been reported *)
				result := SyntaxTree.invalidDesignator;
			ELSIF resolved IS SyntaxTree.Designator THEN
				result := resolved(SyntaxTree.Designator);
			ELSE
				 Error(d.position,Diagnostics.Invalid,"is no designator ! ");
				 result := SyntaxTree.invalidDesignator;
			END;


			(* result.type might be nil.  *)
			RETURN result
		END ResolveDesignator;

		(**
			symbol designator generated in this module
			nothing to be resolved
		**)
		PROCEDURE VisitSymbolDesignator(x: SyntaxTree.SymbolDesignator);
		BEGIN
			resolvedExpression := x;
		END VisitSymbolDesignator;

		(**
			self designator generated in this module
			nothing to be resolved
		**)
		PROCEDURE VisitSelfDesignator(x: SyntaxTree.SelfDesignator);
		VAR scope: SyntaxTree.Scope; record: SyntaxTree.RecordType; type: SyntaxTree.Type; cell: SyntaxTree.CellType;
		BEGIN
			(* check if in record scope *)
			scope := currentScope;
			WHILE (scope # NIL) & ~(scope IS SyntaxTree.RecordScope) &~(scope IS SyntaxTree.CellScope) DO
				scope := scope.outerScope;
			END;
			IF scope = NIL THEN (* in module scope *)
				x.SetType(system.anyType);
			ELSIF scope IS SyntaxTree.CellScope THEN
				cell := scope(SyntaxTree.CellScope).ownerCell;
				x.SetType(cell);
			ELSE (* in record scope *)
				record := scope(SyntaxTree.RecordScope).ownerRecord;
				IF (record # NIL) & (record.pointerType # NIL) THEN
					type := ResolveType(record.pointerType);
					x.SetType(type);
				ELSE
					x.SetType(record);
				END;
			END;
			resolvedExpression := x;
		END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator(x: SyntaxTree.ResultDesignator);
		VAR scope: SyntaxTree.Scope; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; returnType: SyntaxTree.Type;
		BEGIN
			scope := currentScope;
			IF (scope # NIL) & (scope IS SyntaxTree.ProcedureScope) THEN
				procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				returnType := procedureType.returnType;
				IF IsPointerType(returnType) OR IsArrayType(returnType) OR IsMathArrayType(returnType)
				THEN
					x.SetType(returnType);
				ELSE
					Error(x.position,Diagnostics.Invalid,"forbidden access to result designator (only pointer, array and math array)");
					x.SetType(SyntaxTree.invalidType);
				END;
			ELSE
				Error(x.position,Diagnostics.Invalid,"forbidden access to result designator");
				x.SetType(SyntaxTree.invalidType);
			END;
			x.SetAssignable(TRUE);
			resolvedExpression := x;
		END VisitResultDesignator;


		(**
			return symbol designator as an expression
			- if symbol is a constant then return the constant value expression
			- else
				- if no left designator present then do auto-self if in record scope identifier-> SELF.identiifer
				- if symbol is a guarded variable then return a TypeGuardDesignator
				- else return a symbol designator
		**)
		PROCEDURE NewSymbolDesignator*(position: LONGINT; left: SyntaxTree.Designator; symbol: SyntaxTree.Symbol): SyntaxTree.Expression;
		VAR result: SyntaxTree.Expression; assignable: BOOLEAN; scope: SyntaxTree.Scope;
		guardType: SyntaxTree.Type;
		BEGIN
			IF Trace THEN D.Str("NewSymbolDesignator "); D.Ln; END;
			result := SyntaxTree.invalidExpression;
			ASSERT(symbol # NIL);
			(*
			not necessary any more since a type declaration is of type SyntaxTree.typeDeclarationType now
			IF symbol IS SyntaxTree.TypeDeclaration THEN
				Error(position,Diagnostics.Invalid,"type not allowed here");
			ELS *)

			(* not needed any more as values are stored in the expression
			IF symbol IS SyntaxTree.Constant THEN
				result := symbol(SyntaxTree.Constant).value
				IF symbol(SyntaxTree.Constant).value # NIL THEN
				IF symbol(SyntaxTree.Constant).value IS SyntaxTree.Value THEN
					result := symbol(SyntaxTree.Constant).value(SyntaxTree.Value).Copy(position);
				ELSE
					result := symbol(SyntaxTree.Constant).value
				END;
			ELSE
			*)
			IF (left = NIL) & (symbol.scope IS SyntaxTree.RecordScope) 
				OR (left = NIL) & (symbol.scope IS SyntaxTree.CellScope) & cellsAreObjects
			THEN
				left := ResolveDesignator(SyntaxTree.NewSelfDesignator(position)); (* auto self *)
				IF IsPointerType(left.type) OR (left.type.resolved IS SyntaxTree.CellType) & cellsAreObjects THEN
					left := NewDereferenceDesignator(position,left);
					left.SetHidden(TRUE);
				END;
			ELSIF (symbol.scope IS SyntaxTree.ProcedureScope) THEN
				scope := currentScope;
				WHILE (scope # NIL) & (scope # symbol.scope) & ~(scope IS SyntaxTree.RecordScope) DO
					scope := scope.outerScope;
				END;
				IF (scope # NIL) & (scope # symbol.scope) & ~(symbol IS SyntaxTree.Constant) THEN
					Error(position,Diagnostics.Invalid,"forbidden access to symbol in parent procedure scope");
				END;
			END;

			assignable := (left = NIL) OR left.assignable OR (left IS SyntaxTree.DereferenceDesignator) OR (left IS SyntaxTree.SelfDesignator) OR (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Import);

			IF (currentScope # NIL) & (symbol.scope.ownerModule # currentScope.ownerModule) THEN
				assignable := assignable & (SyntaxTree.PublicWrite IN symbol.access);
			ELSE
				assignable := assignable & (SyntaxTree.InternalWrite IN symbol.access);
			END;

				
			assignable := assignable & ((symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter)
				& (symbol(SyntaxTree.Parameter).kind # SyntaxTree.ConstParameter) & ~(symbol(SyntaxTree.Parameter).ownerType IS SyntaxTree.CellType));

			result := SyntaxTree.NewSymbolDesignator(position,left,symbol);
			result.SetType(symbol.type);
			result.SetAssignable(assignable);
			symbol.MarkUsed;
			IF symbol IS SyntaxTree.Constant THEN
				result.SetResolved(symbol(SyntaxTree.Constant).value.resolved);
			END;
			
			IF (symbol IS SyntaxTree.Variable) & ~(symbol IS SyntaxTree.Property) THEN
				variableAccessed := TRUE
			END;

			IF (left = NIL) OR (left IS SyntaxTree.SelfDesignator) OR (left IS SyntaxTree.DereferenceDesignator) & (left(SyntaxTree.DereferenceDesignator).left IS SyntaxTree.SelfDesignator) THEN
				IF GetGuard(symbol,guardType) THEN
					result := NewTypeGuardDesignator(position,result(SyntaxTree.SymbolDesignator),guardType);
				END;
			END;

			ASSERT(result.type # NIL);
			RETURN result
		END NewSymbolDesignator;

		(** check and resolve an identifier designator "identifier"
			- if identifier = self then return SelfDesignator
			- else find symbol in current scope
				- if symbol found then return SymbolDesignator, else error message and return invalidDesignator
		**)
		PROCEDURE VisitIdentifierDesignator(identifierDesignator: SyntaxTree.IdentifierDesignator);
		VAR symbol: SyntaxTree.Symbol;
		BEGIN
			IF Trace THEN D.Str("VisitIdentifierDesignator "); D.Ln; END;
			symbol := Find(currentScope,identifierDesignator.identifier,TRUE);
			IF symbol # NIL THEN
				ResolveSymbol(symbol);
				ASSERT(symbol.type # NIL);
				resolvedExpression := NewSymbolDesignator(identifierDesignator.position,NIL,symbol);
			ELSE
				Error(identifierDesignator.position,Basic.UndeclaredIdentifier,"");
				IF VerboseErrorMessage THEN
					Printout.Info("undeclared identifier designator",identifierDesignator);
				END;
				resolvedExpression := SyntaxTree.invalidDesignator;
			END;
		END VisitIdentifierDesignator;


		(** check and resolve a selector designator of the form left.designator
			- if left is a pointer type then do auto dereferenciation
			- left denotes a search scope:
				- if left type is import type then set search scope to respective module
				- if left type is enumeration type then set search scope to respective enumeration scope
				- elsif left type is record type then set search scope to record scope
			- search symbol in computed scope
			returns selector designator (via global variable resolvedExpression) if symbol found, else error message is given and invalidDesignator is returned
		**)
		PROCEDURE VisitSelectorDesignator(selectorDesignator: SyntaxTree.SelectorDesignator);
		VAR
			symbol: SyntaxTree.Symbol; left: SyntaxTree.Designator; scope: SyntaxTree.Scope;
			module: SyntaxTree.Module; result: SyntaxTree.Expression; type: SyntaxTree.Type;
		BEGIN
			IF Trace THEN D.Str("VisitSelectorDesignator"); D.Ln; END;
			left := ResolveDesignator(selectorDesignator.left);

			result := SyntaxTree.invalidDesignator;
			IF left # NIL THEN
				IF (left.type # NIL) & IsPointerType(left.type.resolved) THEN
					left := NewDereferenceDesignator(selectorDesignator.position,left);
				END;
				scope := NIL;
				IF left.type = NIL THEN
					Error(selectorDesignator.position,Diagnostics.Invalid,"field on nil typed designator");
					IF VerboseErrorMessage THEN Printout.Info("nil typed designator",left) END;
				ELSIF left.type.resolved = SyntaxTree.invalidType THEN (* error already handled *)
				ELSIF left.type.resolved = SyntaxTree.importType THEN
					symbol := left(SyntaxTree.SymbolDesignator).symbol;
					module := symbol(SyntaxTree.Import).module;
					IF module # NIL THEN
						scope := module.moduleScope
					ELSE
						Error(left.position,Diagnostics.Invalid,"module not loaded");
						IF VerboseErrorMessage THEN Printout.Info("unloaded module",symbol) END;
					END;
				ELSIF left.type.resolved IS SyntaxTree.RecordType THEN
					scope := left.type.resolved(SyntaxTree.RecordType).recordScope;
					ASSERT(scope # NIL)
				ELSIF left.type.resolved = SyntaxTree.typeDeclarationType THEN
					symbol := left(SyntaxTree.SymbolDesignator).symbol;
					type := symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
					IF type IS SyntaxTree.EnumerationType THEN
						scope := type(SyntaxTree.EnumerationType).enumerationScope;
					ELSE
						Error(selectorDesignator.position,Diagnostics.Invalid,"field on non-enumeration type declaration");
						IF VerboseErrorMessage THEN Printout.Info("non-record type designator",left) END;
					END;
				ELSIF left.type.resolved IS SyntaxTree.CellType THEN
					scope := left.type.resolved(SyntaxTree.CellType).cellScope;
				ELSE
					Error(selectorDesignator.position,Diagnostics.Invalid,"field on non-record type designator");
					IF VerboseErrorMessage THEN Printout.Info("non-record type designator",left) END;
				END;

				symbol := NIL;
				IF scope # NIL THEN
					symbol := Find(scope,selectorDesignator.identifier,FALSE (* do not visit nested scopes *));
					IF symbol # NIL THEN
						ResolveSymbol(symbol);
						result := NewSymbolDesignator(selectorDesignator.position,left,symbol);
						symbol.MarkUsed
					ELSE
						Error(selectorDesignator.position,Diagnostics.Invalid,"undeclared identifier (selector)");
						IF VerboseErrorMessage THEN
							D.Str("IDENT = "); D.Str0(selectorDesignator.identifier); D.Ln; 
							Printout.Info("scope", scope);
							Printout.Info("left", left);
							Printout.Info("undeclared identifier",selectorDesignator);
							Printout.Info("left resolved designator",left);
						END
					END;
				END;

			END;
			resolvedExpression := result;
		END VisitSelectorDesignator;

		PROCEDURE IndexCheck(index,length: SyntaxTree.Expression);
		VAR len,idx: LONGINT;
		BEGIN
			IF (index # NIL) & IsIntegerValue(index,idx) THEN
				IF idx < 0 THEN
					Error(index.position,Diagnostics.Invalid,"index out of bounds (too small)")
				ELSE
					IF (length # NIL) & IsIntegerValue(length,len) & (idx >= len)  THEN
						Error(index.position,Diagnostics.Invalid,"index out of bounds (too large)");
					END;
				END;
			END;
		END IndexCheck;

		(*
			- if index designator has not type, use newBaseType as its type
			- otherwise, replace the element type (last base type of math array chain) with newBaseType
			- special rule: if static array of dynamic array occurs, make it all dynamic

			index designator type:	new base type:		new index designator type:
			NIL						z					z
			ARRAY [x, y]			z					ARRAY [x, y] OF z
			ARRAY [x, y]			ARRAY [z]			ARRAY [x, y, z]
			ARRAY [x, y]	 		ARRAY [*]			ARRAY [*, *, *]
		*)
		PROCEDURE SetIndexBaseType(indexDesignator: SyntaxTree.IndexDesignator; newBaseType: SyntaxTree.Type);
		VAR
			mathArrayType: SyntaxTree.MathArrayType;
			makeDynamic: BOOLEAN;
		BEGIN
			IF indexDesignator.type = NIL THEN
				indexDesignator.SetType(newBaseType)
			ELSE
				(* index designator must be a of math array type *)
				ASSERT(indexDesignator.type.resolved IS SyntaxTree.MathArrayType);
				mathArrayType := indexDesignator.type.resolved(SyntaxTree.MathArrayType);

				(* determine if all arrays have to be made dynamic *)
				makeDynamic :=
						(newBaseType.resolved IS SyntaxTree.MathArrayType) &
						(newBaseType.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static);

				WHILE (mathArrayType.arrayBase # NIL) & (mathArrayType.arrayBase IS SyntaxTree.MathArrayType) DO
					IF makeDynamic THEN mathArrayType.SetForm(SyntaxTree.Open) END;
					mathArrayType := mathArrayType.arrayBase(SyntaxTree.MathArrayType)
				END;
				IF makeDynamic THEN mathArrayType.SetForm(SyntaxTree.Open) END;
				mathArrayType.SetArrayBase(newBaseType)
			END
		END SetIndexBaseType;

		(** check and append index list element to index designator of math array
			- check validity of single index or array range
			- compute new type
				- if range then create new array type (calculate length of resulting array)
				- otherwise take sourceArray.arrayBase as new type
				- type is not only replaced but might have to be inserted when resolving expressions of the form A[*,i,j,*]
		**)
		PROCEDURE AppendMathIndex(position: LONGINT; indexDesignator: SyntaxTree.IndexDesignator; indexListItem: SyntaxTree.Expression; sourceArray: SyntaxTree.MathArrayType);
		VAR
			targetArray: SyntaxTree.MathArrayType;
			first, last, step: SyntaxTree.Expression;
			firstValue, lastValue, stepValue, length: LONGINT;
			rangeExpression: SyntaxTree.RangeExpression;
		BEGIN
			IF indexListItem.type = SyntaxTree.invalidType THEN
				(* error already handled *)
				indexDesignator.parameters.AddExpression(indexListItem)

			ELSIF indexListItem IS SyntaxTree.TensorRangeExpression THEN
				indexDesignator.HasRange;
				indexDesignator.HasTensorRange;
				indexDesignator.parameters.AddExpression(indexListItem);
				indexDesignator.SetType(SyntaxTree.NewMathArrayType(position, NIL, SyntaxTree.Tensor))

			ELSIF indexListItem.type.resolved IS SyntaxTree.IntegerType THEN
				IndexCheck(indexListItem, sourceArray.length);
				indexListItem := NewConversion(InvalidPosition, indexListItem, system.sizeType, NIL);
				indexDesignator.parameters.AddExpression(indexListItem)

			ELSIF indexListItem.type.resolved IS SyntaxTree.RangeType THEN
				indexDesignator.HasRange;

				(* if the range is given as an array range expression, check the validity of its components *)
				IF indexListItem IS SyntaxTree.RangeExpression THEN
					rangeExpression := indexListItem(SyntaxTree.RangeExpression);
					first := rangeExpression.first;
					last := rangeExpression.last;
					step := rangeExpression.step;

					(* perform static checks on range components *)

					IF IsIntegerValue(first, firstValue) & (firstValue < 0) THEN
						Error(indexListItem.position, Diagnostics.Invalid,"lower bound of array range too small")
					END;
					IF IsIntegerValue(last, lastValue) & (lastValue # MAX(LONGINT)) THEN
						IF (sourceArray.length # NIL) & IsIntegerValue(sourceArray.length, length) & (lastValue > (length - 1)) THEN
							Error(indexListItem.position, Diagnostics.Invalid,"upper bound of array range too large")
						END
					END;
					IF IsIntegerValue(step, stepValue) & (stepValue < 1) THEN
						Error(indexListItem.position, Diagnostics.Invalid,"invalid step size")
					END;

					(* add conversions to size type *)
					(* TODO: needed? *)
					rangeExpression.SetFirst(NewConversion(InvalidPosition, first, system.sizeType, NIL));
					rangeExpression.SetLast(NewConversion(InvalidPosition, last, system.sizeType, NIL));
					rangeExpression.SetStep(NewConversion(InvalidPosition, step, system.sizeType, NIL));
				END;

				IF indexDesignator.hasTensorRange THEN
					(* the index designator's base type is a tensor: leave it as is *)
				ELSE
					(* append a new math array to the index designator's base type *)
					targetArray := SyntaxTree.NewMathArrayType(position, NIL, SyntaxTree.Open);

					IF ~error THEN
						(*
						(* optimization: calculate length of target array for static ranges *)
						IF indexListItem IS SyntaxTree.RangeExpression THEN
							IF IsStaticallyOpenRange(rangeExpression) THEN
								(* range is open ('*'): reuse source array length as target array length *)
								targetArray.SetLength(sourceArray.length); (* the length may or may not be static *)
								targetArray.SetIncrement(sourceArray.staticIncrementInBits)

							ELSIF IsStaticRange(rangeExpression, firstValue, lastValue, stepValue) THEN
								IF lastValue = MAX(LONGINT) THEN
									IF IsIntegerValue(sourceArray.length, length) THEN
										lastValue := length - 1;
										isStaticTargetArrayLength := TRUE
									ELSE
										isStaticTargetArrayLength := FALSE
									END
								ELSE
									isStaticTargetArrayLength := TRUE
								END;
								IF isStaticTargetArrayLength THEN
									(* calculate static target array length *)
									IF firstValue > lastValue THEN
										length := 0
									ELSE
										length := 1 + lastValue - firstValue;
										IF length MOD stepValue = 0 THEN
											length := length DIV stepValue
										ELSE
											length := length DIV stepValue + 1
										END
									END;
									targetArray.SetLength(Global.NewIntegerValue(system, position, length));
									targetArray.SetIncrement(sourceArray.staticIncrementInBits * stepValue);
									ASSERT(targetArray.form = SyntaxTree.Static)
								END
							END
						END
						*)
					END;

					SetIndexBaseType(indexDesignator, targetArray)
				END;

				indexDesignator.parameters.AddExpression(indexListItem)

			ELSE
				Error(position, Diagnostics.Invalid,"invalid index list item");
			END;
		END AppendMathIndex;

		PROCEDURE AppendIndex(position: LONGINT; index: SyntaxTree.IndexDesignator; expression: SyntaxTree.Expression; over: SyntaxTree.Type);
		VAR  parameters: SyntaxTree.ExpressionList;
		BEGIN
			parameters := index.parameters;
			IF (expression.type = NIL) THEN
				Error(position,Diagnostics.Invalid,"invalid index");
			ELSIF IsIntegerType(expression.type.resolved) THEN
				IF over IS SyntaxTree.ArrayType THEN
					IndexCheck(expression,over(SyntaxTree.ArrayType).length);
				ELSIF over IS SyntaxTree.StringType THEN
					IndexCheck(expression,Global.NewIntegerValue(system, position, over(SyntaxTree.StringType).length));
				END;
				expression := NewConversion(InvalidPosition,expression,system.sizeType,NIL);
				parameters.AddExpression(expression);
			ELSE
				Error(position,Diagnostics.Invalid,"invalid index");
			END;
		END AppendIndex;

		(** convert an expression to math array type
			if expression is of math array type: return expression itself
			if expression is of array-structured object type: return an index operator call on it
				e.g. if expression is 3-dim. ASOT: expression -> expression^."[]"( * , * , * )
			otherwise: return invalid expression
		**)
		PROCEDURE ConvertToMathArray(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR
			result: SyntaxTree.Expression;
			mathArrayType: SyntaxTree.MathArrayType;
		BEGIN
			IF expression.type = NIL THEN
				result := SyntaxTree.invalidExpression
			ELSIF expression.type.resolved IS SyntaxTree.MathArrayType THEN
				(* expression of math array type *)
				result := expression
			ELSIF IsArrayStructuredObjectType(expression.type) THEN
				(* expression of array-structured object type *)
				mathArrayType := MathArrayStructureOfType(expression.type);
				result := NewIndexOperatorCall(InvalidPosition, expression, ListOfOpenRanges(mathArrayType.Dimensionality()), NIL)
			ELSE
				result := SyntaxTree.invalidExpression
			END;
			RETURN result
		END ConvertToMathArray;

		(** get an expression list containing a certain amount of open ranges, e.g. [*, *, *, *] **)
		PROCEDURE ListOfOpenRanges(itemCount: LONGINT): SyntaxTree.ExpressionList;
		VAR
			result: SyntaxTree.ExpressionList;
			i: LONGINT;
		BEGIN
			result := SyntaxTree.NewExpressionList();
			FOR i := 1 TO itemCount DO
				result.AddExpression(ResolveExpression(SyntaxTree.NewRangeExpression(InvalidPosition, NIL, NIL, NIL)))
			END;
			RETURN result
		END ListOfOpenRanges;

		(** create a procedure call designator for an index operator call on an array-structured object type
			- use given index list as actual parameters
			- if rhs parameter is not NIL: call write operator, otherwise read operator
		**)
		PROCEDURE NewIndexOperatorCall*(position: LONGINT; left: SyntaxTree.Expression; indexList: SyntaxTree.ExpressionList; rhs: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR
			operator: SyntaxTree.Operator;
			expression: SyntaxTree.Expression;
			actualParameters, tempList: SyntaxTree.ExpressionList;
			tempMathArrayExpression: SyntaxTree.MathArrayExpression;
			result, tempDesignator: SyntaxTree.Designator;
			recordType: SyntaxTree.RecordType;
			containsNonRange, usesPureRangeOperator, usesGeneralOperator, needsReshaping: BOOLEAN;
			i, hashValue, indexListSize, indexListKind: LONGINT;
			castReturnType: SyntaxTree.MathArrayType;
		BEGIN
			ASSERT(IsArrayStructuredObjectType(left.type));
			ASSERT(left.type.resolved IS SyntaxTree.PointerType);
			recordType := left.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);

			(* determine hash value of optimal index operator and if index list contains non-range item *)
			indexListSize := indexList.Length();
			indexListKind := 0;
			containsNonRange := FALSE;
			FOR i := 0 TO indexList.Length() - 1 DO
				indexListKind := indexListKind * 2;
				expression := indexList.GetExpression(i);
				IF expression.type.resolved IS SyntaxTree.RangeType THEN
					INC(indexListKind)
				ELSE
					containsNonRange := TRUE
				END
			END;
			hashValue := IndexOperatorHash(indexListSize, indexListKind, recordType.arrayStructure.form = SyntaxTree.Tensor);

			(* select applicable index operator
				- try to look up optimal index operator
				- if not present, use operator on ranges
					- for non-tensors, use fixed-dim. operator: (RANGE, RANGE, ... RANGE)
					- for tensors, use general operator: (ARRAY [*] OF RANGE)
			 *)
			usesGeneralOperator := FALSE;
			IF rhs # NIL THEN
				(* write operator *)
				IF hashValue = -1 THEN
					operator := NIL
				ELSE
					operator := recordType.arrayAccessOperators.write[hashValue];
				END;
				IF operator = NIL THEN
					usesPureRangeOperator := TRUE;
					IF recordType.arrayStructure.form = SyntaxTree.Tensor THEN
						operator := recordType.arrayAccessOperators.generalWrite;
						usesGeneralOperator := TRUE
					ELSE
						hashValue := TwoToThePowerOf(indexListSize) - 1;
						operator := recordType.arrayAccessOperators.write[hashValue];
					END
				END
			ELSE
				(* read operator *)
				IF hashValue = -1 THEN
					operator := NIL
				ELSE
					operator := recordType.arrayAccessOperators.read[hashValue];
				END;
				IF operator = NIL THEN
					usesPureRangeOperator := TRUE;
					IF recordType.arrayStructure.form = SyntaxTree.Tensor THEN
						operator := recordType.arrayAccessOperators.generalRead;
						usesGeneralOperator := TRUE
					ELSE
						hashValue := TwoToThePowerOf(indexListSize) - 1;
						operator := recordType.arrayAccessOperators.read[hashValue];
					END
				END
			END;

			IF operator = NIL THEN
				Error(position, Diagnostics.Invalid, "call of undeclared [] operator");
				result := SyntaxTree.invalidDesignator;
			ELSE
				(* determine if reshaping is needed *)
				needsReshaping := containsNonRange & usesPureRangeOperator;

				(* import OCArrayBase if reshaping is needed *)
				IF needsReshaping & ~arrayBaseImported THEN
					ImportModule(Global.ArrayBaseName, InvalidPosition);
					arrayBaseImported := TRUE
				END;

				(* add the index list item to the list of actual parameters
					- for general operators: add a single inline array containing the index list items as parameter
					- otherwise: add all index list items as individual parameters
				 *)
				actualParameters := SyntaxTree.NewExpressionList();
				IF usesGeneralOperator THEN
					tempMathArrayExpression := SyntaxTree.NewMathArrayExpression(InvalidPosition);
				END;
				FOR i := 0 TO indexListSize - 1 DO
					expression := indexList.GetExpression(i);
					IF (expression.type.resolved IS SyntaxTree.IntegerType) & needsReshaping THEN
						(* convert integer to range using OCArrayBase.RangeFromInteger *)
						tempList := SyntaxTree.NewExpressionList();
						tempList.AddExpression(expression);
						tempDesignator := SyntaxTree.NewIdentifierDesignator(InvalidPosition, Global.ArrayBaseName);
						tempDesignator := SyntaxTree.NewSelectorDesignator(InvalidPosition, tempDesignator, SyntaxTree.NewIdentifier("RangeFromInteger"));
						expression := ResolveExpression(SyntaxTree.NewParameterDesignator(InvalidPosition, tempDesignator, tempList));
					END;
					IF usesGeneralOperator THEN
						tempMathArrayExpression.elements.AddExpression(expression);
					ELSE
						actualParameters.AddExpression(expression)
					END
				END;
				IF usesGeneralOperator THEN
					actualParameters.AddExpression(tempMathArrayExpression)
				END;

				IF rhs # NIL THEN
					(* add actual parameter for RHS *)

					IF needsReshaping THEN
						(* reshape using OCArrayBase.ExpandDimensions *)
						tempList := SyntaxTree.NewExpressionList();

						(* source array *)
						IF rhs.type.resolved IS SyntaxTree.MathArrayType THEN
							tempList.AddExpression(rhs);
						ELSE
							(* convert scalar to one-dimensional array *)
							tempMathArrayExpression := SyntaxTree.NewMathArrayExpression(InvalidPosition);
							tempMathArrayExpression.elements.AddExpression(rhs);
							tempList.AddExpression(tempMathArrayExpression)
						END;

						(* list of kept dimensions *)
						tempMathArrayExpression := SyntaxTree.NewMathArrayExpression(InvalidPosition);
						FOR i := 0 TO indexListSize - 1 DO
							expression := indexList.GetExpression(i);
							IF expression.type.resolved IS SyntaxTree.IntegerType THEN
								tempMathArrayExpression.elements.AddExpression(SyntaxTree.NewBooleanValue(InvalidPosition, FALSE)) (* insert dimension *)
							ELSE
								tempMathArrayExpression.elements.AddExpression(SyntaxTree.NewBooleanValue(InvalidPosition, TRUE)) (* keep dimension *)
							END
						END;
						tempList.AddExpression(tempMathArrayExpression);
						tempDesignator := SyntaxTree.NewIdentifierDesignator(InvalidPosition, Global.ArrayBaseName);
						tempDesignator := SyntaxTree.NewSelectorDesignator(InvalidPosition, tempDesignator, SyntaxTree.NewIdentifier("ExpandDimensions"));
						expression := ResolveExpression(SyntaxTree.NewParameterDesignator(InvalidPosition, tempDesignator, tempList));

						IF expression.type.resolved IS SyntaxTree.MathArrayType THEN
							(* change the base type of the returned tensor from SYSTEM.ALL to the array structure's element type *)
							castReturnType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid, expression.type.scope,SyntaxTree.Tensor);
							castReturnType.SetArrayBase(ArrayBase(rhs.type.resolved,MAX(LONGINT)));
							expression.SetType(castReturnType);
						ELSE
							Error(expression.position, Diagnostics.Invalid, "problem with resolving ArrayBase.ExpandDimensions");
						END;

						actualParameters.AddExpression(expression)
					ELSE
						actualParameters.AddExpression(rhs)
					END
				END;

				(* add dereference operator and create procedure call designator *)
				ASSERT(left IS SyntaxTree.Designator);
				expression := NewSymbolDesignator(InvalidPosition, NewDereferenceDesignator(InvalidPosition, left(SyntaxTree.Designator)), operator);

				ASSERT(expression IS SyntaxTree.Designator);
				result := NewProcedureCallDesignator(InvalidPosition, expression(SyntaxTree.Designator), actualParameters);

				IF (rhs = NIL) & needsReshaping THEN
					(* reshape using an additional bracket designator with zeros and open ranges at the end; e.g. designator[0, *, *, 0] *)
					tempList := SyntaxTree.NewExpressionList();
					FOR i := 0 TO indexList.Length() - 1 DO
						expression := indexList.GetExpression(i);
						IF expression.type.resolved IS SyntaxTree.IntegerType THEN
							tempList.AddExpression(SyntaxTree.NewIntegerValue(InvalidPosition, 0))
						ELSE
							tempList.AddExpression(SyntaxTree.NewRangeExpression(InvalidPosition, NIL, NIL, NIL))
						END
					END;
					result := ResolveDesignator(SyntaxTree.NewBracketDesignator(InvalidPosition, result, tempList))
				END;

				IF rhs = NIL THEN
					(* special rule: index read operator calls are considered to be assignable *)
					result.SetAssignable(TRUE)
				END;

				(* put information about this index operator call into the resulting designator *)
				result.SetRelatedAsot(left);
				result.SetRelatedIndexList(indexList)
			END;

			RETURN result
		END NewIndexOperatorCall;

		PROCEDURE NewObjectOperatorCall*(position: LONGINT; left: SyntaxTree.Expression; parameters: SyntaxTree.ExpressionList; rhs: SyntaxTree.Expression): SyntaxTree.Designator;
		VAR type: SyntaxTree.Type; expression: SyntaxTree.Expression; op: SyntaxTree.Operator; recordType: SyntaxTree.RecordType;
			actualParameters: SyntaxTree.ExpressionList; i: LONGINT; result: SyntaxTree.Designator;

			PROCEDURE FindOperator(recordType: SyntaxTree.RecordType; identifier: SyntaxTree.Identifier; actualParameters: SyntaxTree.ExpressionList): SyntaxTree.Operator;
			VAR bestOperator: SyntaxTree.Operator; bestDistance: LONGINT; numberParameters: LONGINT; procedureType: SyntaxTree.ProcedureType;
				PROCEDURE FindInScope(scope: SyntaxTree.RecordScope; access: SET);
				VAR operator: SyntaxTree.Operator; distance,i: LONGINT;
				CONST trace = FALSE;
				BEGIN
					IF trace THEN

						FOR i := 0 TO actualParameters.Length()-1 DO
							Printout.Info("par", actualParameters.GetExpression(i));
						END;
					END;
					operator := scope.firstOperator;
					WHILE(operator # NIL) DO
						IF (operator.name=identifier) & (operator.access * access # {}) THEN
							procedureType := operator.type(SyntaxTree.ProcedureType);
							distance := Distance(system, procedureType,actualParameters);
							IF trace THEN Printout.Info("check op ",operator) END;
							IF distance < bestDistance THEN
								IF trace THEN Printout.Info("taken op",operator) END;
								bestDistance := distance;
								bestOperator := operator;
							END;
						END;
						operator := operator.nextOperator;
					END;
				END FindInScope;

			BEGIN
				bestDistance := Infinity; bestOperator := NIL; numberParameters := actualParameters.Length();
				identifier := SyntaxTree.NewIdentifier("[]");
				WHILE (recordType # NIL) DO
					FindInScope(recordType.recordScope,SyntaxTree.ReadOnly);
					recordType := recordType.GetBaseRecord();
				END;
				RETURN bestOperator
			END FindOperator;
		BEGIN
			type := left.type.resolved;

			recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);

			actualParameters := SyntaxTree.NewExpressionList();
			FOR i := 0 TO parameters.Length()-1 DO
				expression := ResolveExpression(parameters.GetExpression(i));
				actualParameters.AddExpression(expression);
			END;
			IF rhs # NIL THEN actualParameters.AddExpression(rhs) END;

			op := FindOperator(recordType, SyntaxTree.NewIdentifier("[]"), actualParameters);
			IF op # NIL THEN
				expression := NewSymbolDesignator(position, NewDereferenceDesignator(InvalidPosition, left(SyntaxTree.Designator)) , op);
				ASSERT(expression IS SyntaxTree.Designator);
				result := NewProcedureCallDesignator(position, expression(SyntaxTree.Designator), actualParameters);
				result.SetRelatedAsot(left);
				result.SetRelatedIndexList(parameters);

				(* check if write operator exists, for var parameters *)
				IF (rhs = NIL) & (op.type(SyntaxTree.ProcedureType).returnType # NIL) THEN
					actualParameters := SyntaxTree.NewExpressionList();
					FOR i := 0 TO parameters.Length()-1 DO
						expression := ResolveExpression(parameters.GetExpression(i));
						actualParameters.AddExpression(expression);
					END;
					rhs := SyntaxTree.NewDesignator(); rhs.SetType(op.type(SyntaxTree.ProcedureType).returnType); (* only a stub to test for existence of operator *)
					actualParameters.AddExpression(rhs);
					op := FindOperator(recordType, SyntaxTree.NewIdentifier("[]"), actualParameters);
					IF op = NIL THEN rhs := NIL END;
				END;

				IF rhs # NIL THEN result.SetAssignable(TRUE) END;
			ELSE
				Error(position,Diagnostics.Invalid,"undefined operator");
				result := SyntaxTree.invalidDesignator
			END;
			RETURN result;
		END NewObjectOperatorCall;

		(** check and semantically resolve a bracket designator of the form 'left[expression, ..., expression]'
			1. convert bracket designator chains into a single one that contains separators
				e.g.: left[a, b, c][d, e][f] -> left[a, b, c, |, d, e, |, f]

			2. convert single bracket designator into a chain of index- , dereference- and procedure call designators
				e.g.: left[a, b, c, |, d, e, |, f] -> left^[a]^."[]"(b, c, d)[e, f]

				- if an array or math array is indexed over, create index designator
					a[x, |, y] -> a[x][y] (split at separator if 'x' contains range or 'a' is tensor math array)
					a[x, |, y] -> a[x, y] (otherwise, combine into single one)

				- if a pointer is indexed over, splitting and auto-dereferencing takes place:
					a[x, y] -> a[x]^[y] (a: ARRAY OF POINTER TO ARRAY OF INTEGER)

				- if an array-structured object type is indexed over, create procedure call designator
					e.g.: a[x, y] -> a^."[]"(x, y)

			Note 1: for math arrays, there can be a difference between a[x, y] and [y, x]:
				- a[i, *] = a[i][*]
				- a[*, i] # a[*][i]

				Because:
				- 'i-th row' = a[*][i] = a[*][i, *] = a[i, *] = a[i] = a[i][*] = a[i][*][*] = a[i][*][*][*]
				- 'i-th column' = a[*, i]

			Note 2: math arrays of arrays (and vice versa) are forbidden by the type system.
			However, pointers are permitted: e.g. ARRAY [10] OF POINTER TO ARRAY is a valid type.

			Note 3: while this compiler tries to combine multiple bracket designators into a single index designator,
			older Oberon compilers did this the other way around: a[x, y, z] -> A[x][y][z].
		**)
		PROCEDURE VisitBracketDesignator(bracketDesignator: SyntaxTree.BracketDesignator);
		VAR
			leftBracketDesignator: SyntaxTree.BracketDesignator;
			indexDesignator: SyntaxTree.IndexDesignator;
			designator: SyntaxTree.Designator;
			type: SyntaxTree.Type;
			recordType: SyntaxTree.RecordType;
			expression, rhs: SyntaxTree.Expression;
			indexList: SyntaxTree.ExpressionList;
			i: LONGINT;
			hasError, done: BOOLEAN;


			PROCEDURE FinalizeIndexDesignator;
			BEGIN
				IF indexDesignator # NIL THEN
					(* the end of a tensor has been reached: *)
					IF IsTensor(type) THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved END;
					SetIndexBaseType(indexDesignator, type);
					indexDesignator.SetType(ResolveType(indexDesignator.type));
					designator := indexDesignator;
					type := designator.type.resolved;
					indexDesignator := NIL;
					ASSERT(SyntaxTree.Resolved IN type.state)
				END
			END FinalizeIndexDesignator;




		BEGIN
			IF Trace THEN D.Str("VisitBracketDesignator"); D.Ln; END;

			IF bracketDesignator.left IS SyntaxTree.BracketDesignator THEN
				leftBracketDesignator := bracketDesignator.left(SyntaxTree.BracketDesignator);
				(* copy all index list entries including a separator to the left bracket designator *)
				leftBracketDesignator.parameters.AddExpression(SyntaxTree.indexListSeparator);
				FOR i := 0 TO bracketDesignator.parameters.Length() - 1 DO
					leftBracketDesignator.parameters.AddExpression(bracketDesignator.parameters.GetExpression(i))
				END;
				(* propagate the related RHS *)
				leftBracketDesignator.SetRelatedRhs(bracketDesignator.relatedRhs); (* for 'left[a][b] := rhs;' *)
				(* only resolve left bracket designator and use as final result *)
				resolvedExpression := ResolveExpression(leftBracketDesignator)

			ELSE
				ASSERT(~(bracketDesignator.left IS SyntaxTree.BracketDesignator));

				designator := ResolveDesignator(bracketDesignator.left);
				type := designator.type.resolved;
				indexDesignator := NIL;

				(*!!! clean up *)
				IF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) & ~IsArrayStructuredObjectType(type) THEN
					resolvedExpression := NewObjectOperatorCall(bracketDesignator.position, designator, bracketDesignator.parameters,bracketDesignator.relatedRhs);
					RETURN
				END;

				i := 0;
				WHILE i <= bracketDesignator.parameters.Length() - 1 DO
					expression := bracketDesignator.parameters.GetExpression(i);
					expression := ResolveExpression(expression);
					bracketDesignator.parameters.SetExpression(i, expression);

					IF expression = SyntaxTree.indexListSeparator THEN
						(* finalize an existing index designator if needed *)
						IF IsTensor(type) OR (indexDesignator # NIL) & (indexDesignator.hasRange) THEN FinalizeIndexDesignator END;
						INC(i)

					ELSE
						(* do auto-dereferencing if needed *)
						IF (type IS SyntaxTree.PointerType) & ~IsArrayStructuredObjectType(type) 
							(*OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) & cellsAreObjects
							& (i=0)*)
						THEN
							(* expression of the form A[x,...] over ARRAY [...] OF POINTER TO ARRAY OF ... *)
							IF (indexDesignator # NIL) & indexDesignator.hasRange THEN
								Error(expression.position, Diagnostics.Invalid, "forbidden range valued indexer over pointer to array");
								designator := SyntaxTree.invalidDesignator;
								type := SyntaxTree.invalidType
							ELSE
								FinalizeIndexDesignator;
								designator := NewDereferenceDesignator(bracketDesignator.position, designator);
								type := designator.type.resolved
							END
						END;

						(* create a new index designator, if needed *)
						IF (indexDesignator = NIL) & ((type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType) OR (type IS SyntaxTree.StringType)) THEN
							indexDesignator := SyntaxTree.NewIndexDesignator(bracketDesignator.position, designator);
							indexDesignator.SetAssignable(designator.assignable);
							indexDesignator.SetType(NIL); (* type will be re-set when index designator is finalized *)
							(* designator := indexDesignator *)
						END;

						IF type = SyntaxTree.invalidType THEN
							(* error already handled *)
							INC(i)

						ELSIF type IS SyntaxTree.ArrayType THEN
							(* indexing over an array *)
							ASSERT(indexDesignator # NIL);
							AppendIndex(expression.position, indexDesignator, expression, type(SyntaxTree.ArrayType));
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
							INC(i)
						ELSIF type IS SyntaxTree.StringType THEN
							(* indexing over an array *)
							ASSERT(indexDesignator # NIL);
							AppendIndex(expression.position, indexDesignator, expression, type);
							type := type(SyntaxTree.StringType).baseType.resolved;
							INC(i)

						ELSIF type IS SyntaxTree.MathArrayType THEN
							(* indexing over a math array *)

							ASSERT(indexDesignator # NIL);
							AppendMathIndex(expression.position, indexDesignator, expression, type(SyntaxTree.MathArrayType));
							IF type(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved END;
							INC(i)

						ELSIF IsArrayStructuredObjectType(type) THEN
							(* indexing over ASOTs *)
							FinalizeIndexDesignator;

							ASSERT(type IS SyntaxTree.PointerType);
							recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);

							(*
							- collect index list items from bracket designator that belong to ASOT
							- check for errors
							*)
							indexList := SyntaxTree.NewExpressionList();
							hasError := FALSE;
							IF recordType.arrayStructure.form = SyntaxTree.Tensor THEN
								(* indexing over tensor ASOT:
									- stop at index list end or separator
									- dimensionality is given by number of index list items
								*)
								done := FALSE;
								WHILE ~done DO
									IF i > bracketDesignator.parameters.Length() - 1 THEN
										done := TRUE;
									ELSE
										expression := bracketDesignator.parameters.GetExpression(i);
										IF expression = SyntaxTree.indexListSeparator THEN
											done := TRUE;
										ELSE
											expression := ResolveExpression(expression);
											IF expression IS SyntaxTree.TensorRangeExpression THEN
												Error(expression.position, Diagnostics.Invalid, "tensor range expression not supported for tensor ASOTs");
												hasError := TRUE
											ELSIF ~(expression.type.resolved IS SyntaxTree.IntegerType) & ~(expression.type.resolved IS SyntaxTree.RangeType) THEN
												Error(expression.position, Diagnostics.Invalid, "integer or range expected");
												expression := SyntaxTree.invalidExpression;
												hasError := TRUE
											END;
											indexList.AddExpression(expression)
										END;
										INC(i)
									END
								END
							ELSE
								(* indexing over non-tensor ASOT:
									- ignore separators
									- make sure that the number of index items matches the ASOT's dimensionality by appending open ranges ('*')
								*)
								WHILE indexList.Length() < recordType.arrayStructure.Dimensionality() DO
									IF i <= bracketDesignator.parameters.Length() - 1 THEN
										expression := bracketDesignator.parameters.GetExpression(i);
									ELSE
										expression := SyntaxTree.NewRangeExpression(InvalidPosition, NIL, NIL, NIL)
									END;
									IF expression # SyntaxTree.indexListSeparator THEN
										expression := ResolveExpression(expression);
										IF ~(expression.type.resolved IS SyntaxTree.IntegerType) & ~(expression.type.resolved IS SyntaxTree.RangeType) THEN
											Error(expression.position, Diagnostics.Invalid, "integer or range expected");
											expression := SyntaxTree.invalidExpression;
											hasError := TRUE
										END;
										indexList.AddExpression(expression)
									END;
									INC(i)
								END;
							END;

							IF hasError THEN
								designator := SyntaxTree.invalidDesignator;
								type := SyntaxTree.invalidType;
							ELSE
								(* determine if read or write mode applies: write mode applies if there is a related RHS
								and the last entry in the index list belongs to the array-structured object type in question.
								E.g.: for a 2-dimensional array-structured object type:
									- 'lhs := asot[1, 2]' -> read mode
									- 'asot[1, 2] := rhs' -> write mode
									- 'asot[1, 2, 3] := rhs' -> read mode
								*)
								IF (bracketDesignator.relatedRhs # NIL) & (i > bracketDesignator.parameters.Length() - 1) THEN
									rhs := bracketDesignator.relatedRhs
								ELSE
									rhs := NIL
								END;
								designator := NewIndexOperatorCall(bracketDesignator.position, designator, indexList, rhs);
								type := designator.type
							END

						ELSE
							Error(expression.position, Diagnostics.Invalid,"indexing over non-array type");
							designator := SyntaxTree.invalidDesignator;
							type := SyntaxTree.invalidType;
							INC(i)

						END
					END
				END;

				IF type # SyntaxTree.invalidType THEN FinalizeIndexDesignator END;
				resolvedExpression := designator
			END
		END VisitBracketDesignator;


		(** check and resolve expression list
			- resolve each expression in an expression list
			- returns true if and only if all statements could have successfully been resolved
		**)
		PROCEDURE ExpressionList(expressionList: SyntaxTree.ExpressionList): BOOLEAN;
		VAR i: LONGINT; expression: SyntaxTree.Expression; result: BOOLEAN;
		BEGIN
			result := TRUE;
			FOR i := 0 TO expressionList.Length()-1 DO
				expression := ResolveExpression(expressionList.GetExpression(i));
				IF expression = SyntaxTree.invalidExpression THEN result := FALSE END;
				expressionList.SetExpression(i,expression);
			END;
			RETURN result
		END ExpressionList;

		PROCEDURE CanPassInRegister*(type: SyntaxTree.Type): BOOLEAN;
		BEGIN
			type := type.resolved;
			IF (type IS SyntaxTree.BasicType) & ~type.IsPointer() & ~type.IsComposite() THEN
				RETURN TRUE
			ELSIF system.CanPassInRegister # NIL THEN
				RETURN system.CanPassInRegister(type);
			ELSE
				RETURN FALSE
			END;
		END CanPassInRegister;


		(** return procedure call designator left(actualParameters)
			- check realtime procedure call in realtime procedure
			- check number of parameters
			- check parameter compatibility
			return invalidDesignator if error
		**)
		PROCEDURE NewProcedureCallDesignator(position: LONGINT; left: SyntaxTree.Designator; actualParameters:SyntaxTree.ExpressionList): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator;
			numberFormalParameters, numberActualParameters: LONGINT;
			formalType: SyntaxTree.ProcedureType;
			formalParameter: SyntaxTree.Parameter;
			actualParameter: SyntaxTree.Expression;
			i: LONGINT;
		BEGIN
			IF Trace THEN D.Str("ProcedureCallDesignator"); D.Ln; END;
			result := SyntaxTree.invalidDesignator;
			formalType := left.type.resolved(SyntaxTree.ProcedureType); (* type checked in VisitParameterDesignator *)
			numberFormalParameters := formalType.numberParameters;
			numberActualParameters := actualParameters.Length();

			IF (currentIsRealtime) & ~(formalType.isRealtime) THEN
				Error(position,Diagnostics.Invalid,"forbidden call of non-realtime procedure in realtime block");
			END;

			IF ~ExpressionList(actualParameters) THEN
				result := SyntaxTree.invalidDesignator
			ELSE
				IF numberActualParameters <= numberFormalParameters THEN
					formalParameter := formalType.firstParameter;
					FOR i := 0 TO numberActualParameters-1 DO
						actualParameter := actualParameters.GetExpression(i);
						IF (actualParameter = SyntaxTree.invalidExpression) THEN
						ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
						ELSIF (currentIsRealtime) & ~actualParameter.type.resolved.isRealtime THEN
							Error(position,Diagnostics.Invalid,"non-realtime actual parameter in context of realtime procedure");
						ELSE
							IF ~formalParameter.type.SameType(actualParameter.type.resolved) THEN
								actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
							END;
							actualParameters.SetExpression(i,actualParameter);
						END;
						formalParameter := formalParameter.nextParameter;
					END;
					WHILE (formalParameter # NIL) DO
						IF formalParameter.defaultValue # NIL THEN
							actualParameters.AddExpression(formalParameter.defaultValue);
							formalParameter := formalParameter.nextParameter
						ELSE
							Error(position,Diagnostics.Invalid,"less actual than formal parameters");
							formalParameter := NIL;
						END;
					END;
				ELSE
					Error(position,Diagnostics.Invalid,"more actual than formal parameters")
				END;

				result := SyntaxTree.NewProcedureCallDesignator(position,left,actualParameters);
				result.SetAssignable(FALSE);
				result.SetType(left.type.resolved(SyntaxTree.ProcedureType).returnType);

			END;

			RETURN result
		END NewProcedureCallDesignator;

		(**
			builtin call designator generated in VisitParameterDesignator
			-> nothing to be resolved
		**)
		PROCEDURE VisitTypeGuardDesignator(x: SyntaxTree.TypeGuardDesignator);
		BEGIN
			resolvedExpression := x;
		END VisitTypeGuardDesignator;

		(**
			builtin call designator generated in VisitParameterDesignator
			-> nothing to be resolved
		**)
		PROCEDURE VisitBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator);
		BEGIN
			IF ExpressionList(x.parameters) THEN
				resolvedExpression := x;
			END;
		END VisitBuiltinCallDesignator;

		(**
			procedure call designator generated in VisitParameterDesignator
			-> nothing to be resolved
		**)
		PROCEDURE VisitProcedureCallDesignator(x: SyntaxTree.ProcedureCallDesignator);
		BEGIN
			x.SetType(x.left.type.resolved(SyntaxTree.ProcedureType).returnType);
			resolvedExpression := x;
		END VisitProcedureCallDesignator;

		(** return true if x is a variable else return false and report error **)
		PROCEDURE CheckVariable(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := TRUE;
			IF x = SyntaxTree.invalidExpression THEN
				result := FALSE;
			ELSIF ~IsVariable(x) THEN
				Error(x.position,Diagnostics.Invalid,"non variable expression");
				IF VerboseErrorMessage THEN Printout.Info("non variable",x) END;
				result := FALSE;
			END;
			RETURN result
		END CheckVariable;

		(**
			if expression x is of basic type then return true else report error and return false
		**)
		PROCEDURE CheckBasicType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~IsBasicType(x.type) THEN
				Error(x.position,Diagnostics.Invalid,"is no basic type");
				result := FALSE
			ELSE result := TRUE
			END;
			RETURN result
		END CheckBasicType;


		(**
			if expression x is of number type then return true else report error and return false
		**)
		PROCEDURE CheckNumberType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.NumberType) THEN
				Error(x.position,Diagnostics.Invalid,"is non number type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckNumberType;

		(**
			if expression x is of number or size type but not complex then return true else report error and return false
		**)
		PROCEDURE CheckNonComplexNumberSizeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF x.type.resolved IS SyntaxTree.ComplexType THEN
				Error(x.position,Diagnostics.Invalid,"is complex type");
			ELSIF ~(x.type.resolved IS SyntaxTree.NumberType) & ~(x.type.resolved IS SyntaxTree.SizeType) THEN
				Error(x.position,Diagnostics.Invalid,"is non number type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckNonComplexNumberSizeType;

		PROCEDURE CheckAddressType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF  ~(type IS SyntaxTree.AddressType) & ~(type IS SyntaxTree.NilType) & ~(type IS SyntaxTree.SizeType) & ~( (type IS SyntaxTree.IntegerType) & (type.sizeInBits <= system.addressType.sizeInBits)) & ~IsAddressValue(x) & ~IsUnsafePointer(type) THEN
				TRACE(type.sizeInBits);
				TRACE(system.addressType.sizeInBits);
				Error(x.position,Diagnostics.Invalid,"is no address type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckAddressType;

		PROCEDURE CheckSizeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF   ~(type IS SyntaxTree.SizeType) & ~( (type IS SyntaxTree.IntegerType) & (type.sizeInBits <= system.sizeType.sizeInBits)) THEN
				Error(x.position,Diagnostics.Invalid,"is no size type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckSizeType;

		PROCEDURE CheckObjectType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(type IS SyntaxTree.NilType) & ~(type IS SyntaxTree.ObjectType) & (~(type IS SyntaxTree.PointerType) OR ~(type(SyntaxTree.PointerType).pointerBase IS SyntaxTree.RecordType) OR ~type(SyntaxTree.PointerType).pointerBase(SyntaxTree.RecordType).isObject) THEN
				Error(x.position,Diagnostics.Invalid,"is no object type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckObjectType;

		(**
			if expression x is of integer type then return true else report error and return false
		**)
		PROCEDURE CheckIntegerType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN; type: SyntaxTree.Type;
		BEGIN
			result := FALSE; type := x.type.resolved;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(type IS SyntaxTree.IntegerType) & ~(type IS SyntaxTree.ByteType) & ~(type IS SyntaxTree.AddressType) & ~(type IS SyntaxTree.SizeType) THEN
				Error(x.position,Diagnostics.Invalid,"is no integer type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckIntegerType;

		(**
			if expression x is of character type then return true else report error and return false
		**)
		PROCEDURE CheckCharacterType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.CharacterType) & ~(x.type.resolved IS SyntaxTree.ByteType) & ~IsCharacterType(x.type.resolved) THEN
				Error(x.position,Diagnostics.Invalid,"is no character type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckCharacterType;

		(**
			if expression x is of real type then return true else report error and return false
		**)
		PROCEDURE CheckRealType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.FloatType) THEN
				Error(x.position,Diagnostics.Invalid,"is no float type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckRealType;


		(**
			if expression x is of range type then return true else report error and return false
		**)
		PROCEDURE CheckRangeType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.RangeType) THEN
				Error(x.position,Diagnostics.Invalid,"is no range type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckRangeType;

		(**
			if expression x is of boolean type then return true else report error and return false
		**)
		PROCEDURE CheckBooleanType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.BooleanType) THEN
				Error(x.position,Diagnostics.Invalid,"is no boolean type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckBooleanType;

		(**
			if expression x is of set type then return true else report error and return false
		**)
		PROCEDURE CheckSetType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~(x.type.resolved IS SyntaxTree.SetType) THEN
				Error(x.position,Diagnostics.Invalid,"is no set type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckSetType;

		(**
			if expression x is of string or array of character type then return true else report error and return false
		**)
		PROCEDURE CheckStringType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF ~IsStringType(x.type.resolved) THEN
				Error(x.position,Diagnostics.Invalid,"is no string type");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckStringType;

		(**
			if expression x is a type declaration type return true else report error and return false
		**)
		PROCEDURE CheckTypeDeclarationType(x: SyntaxTree.Expression): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.type.resolved # SyntaxTree.typeDeclarationType) THEN
				Error(x.position,Diagnostics.Invalid,"is not a type declaration");
			ELSE result := TRUE
			END;
			RETURN result
		END CheckTypeDeclarationType;

		PROCEDURE CheckIntegerValue(x: SyntaxTree.Expression; VAR value: LONGINT): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.IntegerValue).value;
			ELSE
				Error(x.position,Diagnostics.Invalid,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckIntegerValue;

		PROCEDURE IsUnsignedValue(x: SyntaxTree.Expression; maxSizeInBits: LONGINT): BOOLEAN;
		BEGIN
			IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				RETURN Global.IsUnsignedInteger(x.resolved(SyntaxTree.IntegerValue).hvalue, maxSizeInBits)
			ELSE
				RETURN FALSE
			END;
		END IsUnsignedValue;

		PROCEDURE IsAddressValue(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				RETURN Global.IsUnsignedInteger(x.resolved(SyntaxTree.IntegerValue).hvalue, system.addressType.sizeInBits)
			ELSE
				RETURN FALSE
			END
		END IsAddressValue;

		PROCEDURE IsAddressExpression(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			RETURN IsAddressType(x.type.resolved, system.addressSize) OR  IsAddressValue(x)
		END IsAddressExpression;

		PROCEDURE IsSizeExpression(x: SyntaxTree.Expression): BOOLEAN;
		BEGIN
			RETURN IsSizeType(x.type.resolved, system.addressSize) OR IsAddressValue(x)
		END IsSizeExpression;

		PROCEDURE CheckEnumerationValue(x: SyntaxTree.Expression; VAR value: LONGINT): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.EnumerationValue) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.EnumerationValue).value;
			ELSE
				Error(x.position,Diagnostics.Invalid,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckEnumerationValue;


		PROCEDURE CheckCharacterValue(x: SyntaxTree.Expression; VAR value: CHAR): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.CharacterValue) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.CharacterValue).value;
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.StringValue) & (x.resolved(SyntaxTree.StringValue).length =2) THEN
				result := TRUE;
				value := x.resolved(SyntaxTree.StringValue).value[0];
			ELSE
				Error(x.position,Diagnostics.Invalid,"expression is not a character constant");
			END;
			RETURN result;
		END CheckCharacterValue;

		PROCEDURE CheckPositiveIntegerValue(x: SyntaxTree.Expression; VAR value: LONGINT; includeZero: BOOLEAN): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
				value := x.resolved(SyntaxTree.IntegerValue).value;
				IF (value > 0) OR includeZero & (value = 0)  THEN
					result := TRUE;
				ELSE
					Error(x.position,Diagnostics.Invalid,"integer is not positive");
				END
			ELSE
				Error(x.position,Diagnostics.Invalid,"expression is not an integer constant");
			END;
			RETURN result;
		END CheckPositiveIntegerValue;


		PROCEDURE CheckPortType(x: SyntaxTree.Expression; VAR portType: SyntaxTree.PortType): BOOLEAN;
		VAR type: SyntaxTree.Type; result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF x = SyntaxTree.invalidExpression THEN
			ELSE
				type := x.type.resolved;
				IF (type # NIL) & (type IS SyntaxTree.PortType) THEN
					portType := type(SyntaxTree.PortType);
					result := TRUE
				ELSE
					Error(x.position,Diagnostics.Invalid,"no port type");
				END;
			END;
			RETURN result
		END CheckPortType;

		(* move to builtin procedure call statement ?
			remove builtin procedure call designator ?
		*)
		PROCEDURE NewBuiltinCallDesignator(position: LONGINT; builtin: SyntaxTree.Builtin; actualParameters:SyntaxTree.ExpressionList; left: SyntaxTree.Designator): SyntaxTree.Expression;
		VAR
			numberActualParameters,numberFormalParameters: LONGINT;
			formalParameter: SyntaxTree.Parameter;
			actualParameter: SyntaxTree.Expression;
			procedureType: SyntaxTree.ProcedureType;
			parameter0, parameter1, parameter2, result: SyntaxTree.Expression;
			inPort, outPort: SyntaxTree.PortType;
			constructor: SyntaxTree.Procedure;
			type0,type1,type2: SyntaxTree.Type;
			type,base,parameterType: SyntaxTree.Type;
			arrayType: SyntaxTree.ArrayType;
			i,i0,i1: LONGINT;
			r,r0,r1,im: LONGREAL;
			c: CHAR;
			id: LONGINT;
			b: BOOLEAN;

			mathArrayType: SyntaxTree.MathArrayType;
			customBuiltin: SyntaxTree.CustomBuiltin;

			PROCEDURE CheckArity(from,to: LONGINT): BOOLEAN;
			VAR resultB: BOOLEAN;
			BEGIN
				IF numberActualParameters < from THEN
					Error(position,Diagnostics.Invalid,"less actual than formal parameters");
					result := SyntaxTree.invalidExpression;
					resultB := FALSE;
				ELSIF numberActualParameters > to THEN
					Error(position,Diagnostics.Invalid,"more actual than formal parameters");
					result := SyntaxTree.invalidExpression;
					resultB := FALSE;
				ELSE
					resultB := TRUE;
				END;
				RETURN resultB
			END CheckArity;

		BEGIN
			type := NIL; result := NIL;
			type0 := NIL; type1 := NIL; type2 := NIL;
			numberActualParameters := actualParameters.Length();
			IF numberActualParameters>0 THEN
				parameter0 := actualParameters.GetExpression(0);
				IF parameter0.type # NIL THEN type0 := parameter0.type.resolved ELSE
					Error(parameter0.position,Diagnostics.Invalid,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;
			IF numberActualParameters >1 THEN
				parameter1 := actualParameters.GetExpression(1);
				IF parameter1.type # NIL THEN type1 := parameter1.type.resolved
				ELSE
					Error(parameter1.position,Diagnostics.Invalid,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;
			IF numberActualParameters >2 THEN
				parameter2 := actualParameters.GetExpression(2);
				IF parameter2.type # NIL THEN type2 := parameter2.type.resolved
				ELSE
					Error(parameter2.position,Diagnostics.Invalid,"forbidden type-less argument");
					result := SyntaxTree.invalidExpression
				END
			END;

			id := builtin.id;
			IF system.operatorDefined[id] THEN (* try to find overloaded operator *)
				result := NewOperatorCall(position,builtin.id,parameter0,parameter1,NIL);
			END;

			IF result = SyntaxTree.invalidExpression THEN (* error already handled *)
			ELSIF result # NIL THEN type := result.type (* operator *)
			ELSE
				result := SyntaxTree.NewBuiltinCallDesignator(position,id,left,actualParameters);
				result(SyntaxTree.Designator).SetLeft(left);
				(* ---- ASSERT ----- *)
				IF (id = Global.Assert) & CheckArity(1,2)  THEN
					IF CheckBooleanType(parameter0) THEN
	(*					mk: Commented this out because Oberon 07 uses Assert(FALSE, trap) instead of HALT
						fof: commented in again as ASSERT is crucial for compilation tests, Oberon07 obviously needs a HALT statement
							misusing ASSERT does not make the language clearer nor odes it make the compiler simpler!
	*)
						IF IsBooleanValue(parameter0,b) & ~b & ~(currentIsUnreachable)  THEN
							Error(position,Diagnostics.Invalid,"assert failed");
						END;
						IF (numberActualParameters > 1) & CheckIntegerValue(parameter1,i1) THEN
							(* modified: any integer parameter value is allowed, it is in the responsibility of the programmer to adhere to
								rules imposed by the architecture / current runtime
							 *)
						END;
					END;
				(* ---- COPY ----- *)
				ELSIF (id = Global.Copy) & CheckArity(2,2) THEN
					IF~IsStringType(type0) THEN
						Error(parameter0.position,Diagnostics.Invalid,"no string type");
					END;
					IF ~IsStringType(type1) THEN
						Error(parameter1.position,Diagnostics.Invalid,"no string type");
					ELSIF CheckVariable(parameter1) THEN
						IF (type0 IS SyntaxTree.StringType) THEN
							arrayType := type1(SyntaxTree.ArrayType);
							IF arrayType.form = SyntaxTree.Static THEN
								IF arrayType.staticLength < type0(SyntaxTree.StringType).length THEN
									Error(position,Diagnostics.Invalid,"destination length smaller than source length")
								END;
							END;
						END;
					END;
				(* ---- INC, DEC----- *)
				ELSIF ((id = Global.Dec) OR (id = Global.Inc)) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						parameter1 :=Global.NewIntegerValue(system,position,1);
						actualParameters.AddExpression(parameter1);
					END;
					IF CheckVariable(parameter0) & CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						IF ~CompatibleTo(system,parameter1.type,parameter0.type) THEN
							Error(position,Diagnostics.Invalid,"incompatible increment");
						ELSE
							parameter1 := NewConversion(0,parameter1,parameter0.type,NIL);
							actualParameters.SetExpression(1,parameter1);
						END;
					END;
				(* ---- EXCL, INCL----- *)
				ELSIF ((id = Global.Excl) OR (id = Global.Incl)) & CheckArity(2,2) THEN
					IF CheckVariable(parameter0) & CheckSetType(parameter0) & CheckSizeType(parameter1) THEN
						IF IsIntegerValue(parameter1,i0) THEN
							IF (i0 < 0) OR (i0>= system.setType.sizeInBits) THEN
								Error(position,Diagnostics.Invalid,"parameter out of SET range")
							END;
						END;
						parameter1 := NewConversion(0,parameter1,system.longintType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- HALT, SYSTEM.HALT ----- *)
				ELSIF ((id = Global.Halt) OR (id = Global.systemHalt)) & CheckArity(1,1) THEN
					IF CheckPositiveIntegerValue(parameter0,i0,FALSE) THEN
						(* modified: any integer parameter value is allowed, it is in the responsibility of the programmer to adhere to
							rules imposed by the architecture / current runtime
						 *)
					END;
				(* ---- WAIT ----- *)
				ELSIF cooperative & (id = Global.Wait) & CheckArity(1,1) THEN
					IF CheckObjectType(parameter0) THEN
					END;
				(* ---- NEW ----- *)
				ELSIF (id = Global.New) & CheckArity(1,Infinity) THEN
					IF currentIsRealtime THEN
						Error(position,Diagnostics.Invalid,"forbidden new in realtime block");
					END;
					(* check constructor *)
					IF CheckVariable(parameter0) THEN
						IF type0 IS SyntaxTree.PointerType THEN
							type0 := type0(SyntaxTree.PointerType).pointerBase.resolved;
						END;
						IF type0 IS SyntaxTree.ArrayType THEN
							arrayType := type0(SyntaxTree.ArrayType);
							IF arrayType.form = SyntaxTree.Static THEN
								i := 1
							ELSIF arrayType.form = SyntaxTree.Open THEN
								i := Dimension(arrayType,{SyntaxTree.Open})+1;
							ELSE HALT(100)
							END;
							IF CheckArity(i,i) & (numberActualParameters>1) THEN
								i := 1;
								REPEAT
									actualParameter := actualParameters.GetExpression(i);
									IF CheckSizeType(actualParameter) THEN
										actualParameter := NewConversion(0,actualParameter,system.longintType,NIL);
										actualParameters.SetExpression(i,actualParameter);
									END;
									INC(i);
								UNTIL ~CheckSizeType(actualParameter) OR (actualParameter.resolved # NIL) & ~CheckPositiveIntegerValue(actualParameter,i0,TRUE) OR (i=numberActualParameters);
							END;
						ELSIF (type0 IS SyntaxTree.RecordType) THEN
							constructor := GetConstructor(type0(SyntaxTree.RecordType));
							IF constructor = NIL THEN
								IF CheckArity(1,1) THEN END;
							ELSIF (constructor.scope.ownerModule # currentScope.ownerModule) & ~(SyntaxTree.PublicRead IN constructor.access) THEN
								Error(position,Diagnostics.Invalid,"new on object with hidden constructor");
							ELSE
								procedureType := constructor.type(SyntaxTree.ProcedureType);
								numberFormalParameters := procedureType.numberParameters;
								DEC(numberActualParameters);
								IF numberActualParameters <= numberFormalParameters THEN
									formalParameter := procedureType.firstParameter;
									FOR i := 1 TO numberActualParameters DO
										actualParameter := actualParameters.GetExpression(i);
										IF (actualParameter = SyntaxTree.invalidExpression) THEN
										ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
										ELSE
											IF formalParameter.type.resolved # actualParameter.type.resolved THEN
												actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
											END;
											actualParameters.SetExpression(i,actualParameter);
										END;
										formalParameter := formalParameter.nextParameter;
									END;
									WHILE (formalParameter # NIL) DO
										IF formalParameter.defaultValue # NIL THEN
											actualParameters.AddExpression(formalParameter.defaultValue);
											formalParameter := formalParameter.nextParameter
										ELSE
											Error(position,Diagnostics.Invalid,"less actual than formal parameters");
											formalParameter := NIL;
										END;
									END;
								ELSE
									Error(position,Diagnostics.Invalid,"more actual than formal parameters")
								END;
							END;
						ELSIF type0 IS SyntaxTree.MathArrayType THEN
							mathArrayType := type0(SyntaxTree.MathArrayType);
							IF mathArrayType.form = SyntaxTree.Static THEN
								Error(position,Diagnostics.Invalid,"new on static array");
							ELSE
								IF mathArrayType.form = SyntaxTree.Tensor THEN
									i0 := 2; i1 := Infinity;
								ELSIF mathArrayType.form = SyntaxTree.Open THEN
									i0 := Dimension(mathArrayType,{SyntaxTree.Open})+1;
									i1 := i0;
								ELSE HALT(100);
								END;
								IF type1 IS SyntaxTree.MathArrayType THEN (* NEW(a, array) *)

									(* use type checking facilities of procedure calls: artificially build parameters here and call checker *)
									base := ArrayBase(type0,MAX(LONGINT));

									parameterType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid,currentScope,SyntaxTree.Tensor);
									parameterType(SyntaxTree.MathArrayType).SetArrayBase(base);
									IF ~CompatibleTo(system,type0,parameterType) THEN
										Error(parameter0.position,Diagnostics.Invalid,"incompatible parameter in new");
										result := SyntaxTree.invalidExpression;
									ELSE
										parameter0 := NewConversion(Diagnostics.Invalid,parameter0,parameterType,NIL); actualParameters.SetExpression(0,parameter0);
									END;

									parameterType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid,currentScope,SyntaxTree.Open);
									parameterType(SyntaxTree.MathArrayType).SetArrayBase(system.longintType);
									IF ~CompatibleTo(system,type1,parameterType) THEN
										Error(parameter1.position,Diagnostics.Invalid,"parameter incompatible to math array of longint");
										result := SyntaxTree.invalidExpression;
									ELSE
										parameter1 := NewConversion(Diagnostics.Invalid,parameter1,parameterType,NIL); actualParameters.SetExpression(1,parameter1);
									END;
								ELSE
									IF CheckArity(i0,i1) & (numberActualParameters >1) THEN
										i := 1;
										REPEAT
											actualParameter := actualParameters.GetExpression(i);
											IF CheckSizeType(actualParameter) THEN
												actualParameter := NewConversion(0,actualParameter,system.sizeType,NIL);
												actualParameters.SetExpression(i,actualParameter);
											END;
											INC(i);
										UNTIL ~CheckSizeType(actualParameter) OR (actualParameter.resolved # NIL) & ~CheckPositiveIntegerValue(actualParameter,i0,TRUE) OR (i=numberActualParameters);
									END;
								END;
							END;
						ELSIF type0 IS SyntaxTree.CellType THEN
							IF ~(currentIsCellNet) THEN
								Error(position,Diagnostics.Invalid,"cell allocation outside activeCells ");
							ELSE
								constructor := type0(SyntaxTree.CellType).cellScope.constructor;
								IF (constructor = NIL) & CheckArity(1,1) THEN
									(* ok *)
								ELSE
									procedureType := constructor.type(SyntaxTree.ProcedureType);
									numberFormalParameters := procedureType.numberParameters;
									DEC(numberActualParameters);
									IF numberActualParameters <= numberFormalParameters THEN
										formalParameter := procedureType.firstParameter;
										FOR i := 1 TO numberActualParameters DO
											actualParameter := actualParameters.GetExpression(i);
											IF (actualParameter = SyntaxTree.invalidExpression) THEN
											ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
											ELSE
												IF formalParameter.type.resolved # actualParameter.type.resolved THEN
													actualParameter := NewConversion(actualParameter.position,actualParameter,formalParameter.type,NIL);
												END;
												actualParameters.SetExpression(i,actualParameter);
											END;
											formalParameter := formalParameter.nextParameter;
										END;
										WHILE (formalParameter # NIL) DO
											IF formalParameter.defaultValue # NIL THEN
												actualParameters.AddExpression(formalParameter.defaultValue);
												formalParameter := formalParameter.nextParameter
											ELSE
												Error(position,Diagnostics.Invalid,"less actual than formal parameters");
												formalParameter := NIL;
											END;
										END;
									ELSE
										Error(position,Diagnostics.Invalid,"more actual than formal parameters")
									END;

								END;
							END;
							activeCellsStatement := TRUE;
						ELSE
							Error(position,Diagnostics.Invalid,"cannot be allocated");
						END;
					END;
				(* ---- DISPOSE ----- *)
				ELSIF (id = Global.Dispose) & CheckArity(1,1) THEN
					IF ~IsPointerType(parameter0.type) THEN
						Error(parameter0.position,Diagnostics.Invalid,"is not a pointer")
					ELSIF ~IsDisposable(parameter0.type) THEN
						Error(parameter0.position,Diagnostics.Invalid,"is not disposable")
					ELSIF CheckVariable(parameter0) THEN (* ok *)
					END
				(* ---- GETPROCEDURE ----- *)
				ELSIF (id = Global.GetProcedure) & CheckArity(3,3) THEN
					IF CheckStringType(parameter0) & CheckStringType(parameter1) THEN
						IF CheckVariable(parameter2) THEN
							IF ~GetProcedureAllowed(parameter2.type) THEN
								Error(parameter2.position,Diagnostics.Invalid,"GETPROCEDURE not allowed on this type");
							END;
						END;
					END;
				(* ---- ABS ----- *)
				ELSIF (id = Global.Abs) & CheckArity(1,1) THEN
					(* note: ABS on complex numbers is done using overloading *)
					IF CheckNonComplexNumberSizeType(parameter0) THEN
						type := type0;
						IF IsIntegerValue(parameter0,i0) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ABS(i0)));
							type := Global.GetIntegerType(system,ABS(i0));
						ELSIF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewRealValue(position,ABS(r)));
						END;
					ELSE
						type := SyntaxTree.invalidType;
					END;
				(* ---- ASH, ASR ----- *)
				ELSIF ((id = Global.Ash) OR (id= Global.Asr)) & CheckArity(2,2) THEN
					type := type0;
					IF CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						(*
						ConvertOperands(parameter0,parameter1); (* same type *)
						*)

						type := parameter0.type;
						IF IsIntegerValue(parameter0,i0) THEN
							IF IsIntegerValue(parameter1,i1) THEN
								IF id = Global.Ash THEN i0 := ASH(i0,i1) ELSE i0 := ASR(i0,i1) END;
								result.SetResolved(SyntaxTree.NewIntegerValue(position,i0));
								result := ResolveExpression(result);
								type := Global.GetIntegerType(system,i0);
							END;
						END;

						IF type.resolved.sizeInBits < 32 THEN
							type := system.longintType;
						END;

						(*!compatibility with release, remove when resolved
						    critical in release : SHORT(ASH(..))), ASH(ORD(..))
						*)
						parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
						parameter0 := NewConversion(parameter0.position,parameter0,type,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- CAP ----- *)
				ELSIF (id = Global.Cap) & CheckArity(1,1) THEN
					type := system.characterType;
						IF CheckCharacterType (parameter0) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,type,NIL);
						actualParameters.SetExpression(0,parameter0);
						IF IsCharacterValue(parameter0,c) THEN
							IF (c <= "z") & (c >= "a") THEN
								result.SetResolved(SyntaxTree.NewCharacterValue(position,CAP(c)))
							ELSE
								result.SetResolved(SyntaxTree.NewCharacterValue(position,c))
							END;
						END;
					END;
				(* ---- CHR ----- *)
				ELSIF ((id = Global.Chr) OR (id = Global.Chr32)) & CheckArity(1,1) THEN
					IF id = Global.Chr THEN
						type := system.characterType
					ELSE
						type := system.characterType32
					END;
					IF CheckIntegerType(parameter0) THEN
						IF IsIntegerValue(parameter0,i0)  THEN
							result.SetResolved(SyntaxTree.NewCharacterValue(position,CHR(i0)));
							result := ResolveExpression(result);
						ELSE
							(*
							result := NewConversion(parameter0.position,parameter0,type);
							*)
						END;
					END
				(* ---- ENTIER ----- *)
				ELSIF (id = Global.Entier) & CheckArity(1,1) THEN
					type := system.longintType;
					IF CheckRealType(parameter0) THEN
						IF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ENTIER(r)));
							type := Global.GetIntegerType(system,ENTIER(r));
						END
					END;
				(* ---- ENTIERH ----- *)
				ELSIF (id = Global.EntierH) & CheckArity(1,1) THEN
					type := system.hugeintType;
					IF CheckRealType(parameter0) THEN
						IF IsRealValue(parameter0,r) THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ENTIERH(r)));
						END
					END;
				(* ---- LEN ----- *)
				ELSIF (id = Global.Len) & CheckArity(1,2) THEN
					type := system.longintType;
					base := type0;

					IF (base IS SyntaxTree.PointerType) & (parameter0 IS SyntaxTree.Designator) THEN
						parameter0 := NewDereferenceDesignator(position,parameter0(SyntaxTree.Designator));
						actualParameters.SetExpression(0,parameter0);
						type0 := parameter0.type.resolved;
						base := type0;
					END;

					IF (numberActualParameters=1) OR (numberActualParameters =2) & CheckIntegerType(parameter1) THEN
						IF ~(numberActualParameters=2) OR ~IsIntegerValue(parameter1,i1) THEN i1 := 0 END;
						IF i1 < 0 THEN
							Error(position,Diagnostics.Invalid,"invalid dimension");
							base := SyntaxTree.invalidType;
						ELSE
							base := ArrayBase(base,i1);
							IF (base # NIL) & Indexable(base) THEN
							ELSE
								Error(position,Diagnostics.Invalid,"len on no array");
								IF VerboseErrorMessage THEN
									Printout.Info("base",base);
								END;
								base := SyntaxTree.invalidType;
							END;
						END;
						IF numberActualParameters=2 THEN
							parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
							actualParameters.SetExpression(1,parameter1);
						ELSIF base IS SyntaxTree.MathArrayType THEN
							Error(position,Diagnostics.Invalid,"missing dimension specification");
						END;
						IF (numberActualParameters=1) OR (numberActualParameters =2) & IsIntegerValue(parameter1,i1) THEN
							IF base IS SyntaxTree.ArrayType THEN
								arrayType := base(SyntaxTree.ArrayType);
								IF (arrayType.length # NIL) & (arrayType.length.resolved # NIL) & IsIntegerValue(arrayType.length,i) THEN
									(* do not use length directly such as in result := length as this mide have side-effects when result types get converted *)
									result := Global.NewIntegerValue(system,position,i);
									type := result.type;(* arrayType.length.type;*)
									ASSERT(type # NIL);
								END;
							ELSIF base IS SyntaxTree.MathArrayType THEN
								mathArrayType := base(SyntaxTree.MathArrayType);
								IF (mathArrayType.length # NIL) & (mathArrayType.length.resolved # NIL) & IsIntegerValue(mathArrayType.length,i) THEN
									result := Global.NewIntegerValue(system,position,i);
									type := result.type;
									(*
									type := mathArrayType.length.type;
									*)
									ASSERT(type # NIL);
								END;
							END;
						END;
					ELSE
						type := system.longintType;
					END;
				(* ---- FIRST ---- *)
				ELSIF (id = Global.First) & CheckArity(1,1) THEN
					type := system.longintType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- LAST ---- *)
				ELSIF (id = Global.Last) & CheckArity(1,1) THEN
					type := system.longintType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- STEP ---- *)
				ELSIF (id = Global.Step) & CheckArity(1,1) THEN
					type := system.longintType;
					IF CheckRangeType(parameter0) THEN END;
					result.SetAssignable(parameter0.assignable)

				(* ---- RE ---- *)
				ELSIF (id = Global.Re) & CheckArity(1,1) THEN
					IF CheckNumberType(parameter0) THEN
						IF parameter0.type.resolved IS SyntaxTree.ComplexType THEN
							type := parameter0.type.resolved(SyntaxTree.ComplexType).componentType;
							IF IsComplexValue(parameter0, r, im) THEN result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, r)) END
						ELSIF parameter0.type.resolved IS SyntaxTree.FloatType THEN
							type := parameter0.type
						ELSE
							type := system.realType
						END
					END;
					result.SetAssignable(parameter0.assignable)

				(* ---- IM ---- *)
				ELSIF (id = Global.Im) & CheckArity(1,1) THEN
					IF CheckNumberType(parameter0) THEN
						IF parameter0.type.resolved IS SyntaxTree.ComplexType THEN
							type := parameter0.type.resolved(SyntaxTree.ComplexType).componentType;
							IF IsComplexValue(parameter0, r, im) THEN result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, im)) END
						ELSE
							type := system.realType;
							result.SetResolved(SyntaxTree.NewRealValue(parameter0.position, 0))
						END
					END;
					result.SetAssignable(parameter0.assignable)

				(* ---- MAX ----- *)
				ELSIF (id = Global.Max) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						IF parameter0.type = SyntaxTree.typeDeclarationType THEN
							type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
							IF type IS SyntaxTree.CharacterType THEN result.SetResolved(SyntaxTree.NewCharacterValue(position,MAX(CHAR)));
							(*!! ELSIF type = Global.Char16 THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0FFFFH));
							ELSIF type = Global.Char32 THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0FFFFFFFFH));
							*)
							ELSIF type IS SyntaxTree.IntegerType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MaxInteger(system,type(SyntaxTree.IntegerType))));
							ELSIF type IS SyntaxTree.FloatType THEN result.SetResolved(SyntaxTree.NewRealValue(position,Global.MaxFloat(system,type(SyntaxTree.FloatType))));
							ELSIF type IS SyntaxTree.SetType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,system.SizeOf(type)-1)); type := system.shortintType;
							ELSIF type IS SyntaxTree.SizeType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MaxInteger(system,type(SyntaxTree.BasicType))));
							ELSE Error(Diagnostics.Invalid,parameter0.position,"builtin function not applicable to this type");
							END;
						ELSE
							Error(parameter0.position,Diagnostics.Invalid,"is not a type symbol");
						END
					ELSIF CheckNonComplexNumberSizeType(parameter0) & CheckNonComplexNumberSizeType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						IF IsRealValue(parameter0,r0) & IsRealValue(parameter1,r1) THEN
							IF r0 > r1 THEN result.SetResolved(parameter0(SyntaxTree.Value))
							ELSE result.SetResolved(parameter0(SyntaxTree.Value))
							END;
						ELSIF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
							IF i0 > i1 THEN result.SetResolved(parameter0(SyntaxTree.Value))
							ELSE result.SetResolved(parameter1(SyntaxTree.Value))
							END;
						END;
						type := parameter0.type;
					ELSE type := SyntaxTree.invalidType;
					END;
				(* ---- MIN ----- *)
				ELSIF (id = Global.Min) & CheckArity(1,2) THEN
					IF numberActualParameters = 1 THEN
						IF parameter0.type = SyntaxTree.typeDeclarationType THEN
							type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
							IF type IS SyntaxTree.CharacterType THEN result.SetResolved(SyntaxTree.NewCharacterValue(position,MIN(CHAR)));
							ELSIF type IS SyntaxTree.IntegerType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,Global.MinInteger(system,type(SyntaxTree.IntegerType))));
							ELSIF type IS SyntaxTree.FloatType THEN result.SetResolved(SyntaxTree.NewRealValue(position,Global.MinFloat(system,type(SyntaxTree.FloatType))));
							ELSIF type IS SyntaxTree.SetType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position,0)); type := system.shortintType;
							ELSIF type IS SyntaxTree.SizeType THEN result.SetResolved(SyntaxTree.NewIntegerValue(position, Global.MinInteger(system,type(SyntaxTree.BasicType))));
							ELSE Error(parameter0.position,Diagnostics.Invalid,"builtin function not applicable to this type");
							END;
						ELSE
							Error(parameter0.position,Diagnostics.Invalid,"is not a type symbol");
						END
					ELSIF CheckNonComplexNumberSizeType(parameter0) & CheckNonComplexNumberSizeType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						IF IsRealValue(parameter0,r0) & IsRealValue(parameter1,r1) THEN
							IF r0 < r1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter1.resolved)
							END;
						ELSIF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
							IF i0 < i1 THEN result.SetResolved(parameter0.resolved)
							ELSE result.SetResolved(parameter1.resolved)
							END;
						END;
						type := parameter0.type;
					ELSE type := SyntaxTree.invalidType;
					END;
				(* ---- ODD ----- *)
				ELSIF (id = Global.Odd) & CheckArity(1,1) THEN
					type := system.booleanType;
					IF CheckIntegerType(parameter0) THEN
						IF IsIntegerValue(parameter0,i0)  THEN
							result.SetResolved(SyntaxTree.NewBooleanValue(position,ODD(i0)));
							type := system.booleanType;
						END;
					END;
				(* ---- ORD ----- *)
				ELSIF ((id = Global.Ord) OR (id = Global.Ord32)) & CheckArity(1,1) THEN
					IF id = Global.Ord THEN
						type := system.integerType;
					ELSE
						type := system.longintType;
					END;
					IF CompatibleTo(system, parameter0.type, system.characterType) THEN
						parameter0 := NewConversion(parameter0.position, parameter0, system.characterType,NIL);
						actualParameters.SetExpression(0,parameter0);
						(* IF CheckCharacterType(parameter0) THEN*)
						 IF IsCharacterValue(parameter0,c)THEN
							result.SetResolved(Global.NewIntegerValue(system,position,ORD(c)));
							type := Global.GetSignedIntegerType(system,ORD(c));
						END;
					ELSE Error(parameter0.position, Diagnostics.Invalid, "incompatible parameter");
					END;
				(* ---- SHORT ----- *)
				ELSIF (id = Global.Short) & CheckArity(1,1) THEN
					type := type0;
					IF IsSignedIntegerType(type) THEN
						IF (type.sizeInBits = 8) OR (type = system.shortintType) THEN Error(parameter0.position,Diagnostics.Invalid,"short not applicable")
						ELSIF type = system.integerType THEN type := system.shortintType
						ELSIF type = system.longintType THEN type := system.integerType
						ELSIF type = system.hugeintType THEN type:= system.longintType
						ELSE
							CASE type.sizeInBits OF
								16: type := Global.Integer8
								|32: type := Global.Integer16
								|64: type := Global.Integer32
							END;
						END;
					ELSIF type IS SyntaxTree.FloatType THEN
						IF (type.sizeInBits = 32) OR (type = system.realType) THEN Error(parameter0.position,Diagnostics.Invalid,"short not applicable")
						ELSIF type = system.longrealType THEN type := system.realType
						ELSIF type.sizeInBits = 64 THEN type := Global.Float32
						END;
					ELSIF type IS SyntaxTree.ComplexType THEN
						IF (type.sizeInBits = 64) OR (type = system.complexType) THEN Error(parameter0.position,Diagnostics.Invalid,"short not applicable")
						ELSIF (type = system.longcomplexType) THEN type := system.complexType
						ELSIF type.sizeInBits = 128 THEN type := Global.Complex64
						END;
					ELSE
						 Error(parameter0.position,Diagnostics.Invalid,"short not applicable")
					END;
					IF (parameter0.resolved # NIL) THEN
						parameter0 := ConvertValue(parameter0.position,parameter0.resolved,type);
						IF parameter0 IS SyntaxTree.Value THEN
							result.SetResolved(parameter0(SyntaxTree.Value));
						END;
					END;
				(* ---- LONG ----- *)
				ELSIF (id = Global.Long) & CheckArity(1,1) THEN
					type := type0;
					IF IsSignedIntegerType(type) THEN
						IF (type.sizeInBits = 64) OR (type = system.hugeintType) THEN Error(parameter0.position,Diagnostics.Invalid,"long not applicable")
						ELSIF type = system.longintType THEN type := system.hugeintType
						ELSIF type = system.integerType THEN type := system.longintType
						ELSIF type = system.shortintType THEN type := system.integerType
						ELSE
							CASE type.sizeInBits OF
							8: type := Global.Integer16
							|16: type := Global.Integer32
							|32: type := Global.Integer64
							END;
						END;
					ELSIF type IS SyntaxTree.FloatType THEN
						IF (type.sizeInBits = 64) OR (type = system.longrealType) THEN Error(parameter0.position,Diagnostics.Invalid,"long not applicable")
						ELSIF type= system.realType THEN  type := system.longrealType
						ELSIF type.sizeInBits = 32 THEN type := Global.Float64
						END;
					ELSIF type IS SyntaxTree.ComplexType THEN
						IF (type.sizeInBits = 128) OR (type = system.longcomplexType) THEN Error(parameter0.position,Diagnostics.Invalid,"long not applicable")
						ELSIF type = system.complexType THEN type := system.longcomplexType
						ELSIF type.sizeInBits = 64 THEN type := Global.Complex128
						END;
					ELSE
						 Error(parameter0.position,Diagnostics.Invalid,"long not applicable")
					END;
					IF (parameter0.resolved # NIL) THEN
						parameter0 := ConvertValue(parameter0.position,parameter0.resolved,type);
						IF parameter0 IS SyntaxTree.Value THEN
							result.SetResolved(parameter0(SyntaxTree.Value));
						END;
					END;
				(* ---- SIZE OF ----- *)
				ELSIF (id = Global.systemSize) & CheckArity(1,1) THEN
					IF (parameter0.type = SyntaxTree.typeDeclarationType) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						result.SetResolved(SyntaxTree.NewIntegerValue(position,system.SizeOf(type.resolved) DIV 8 (* in bytes *) ));
						type := system.integerType;
						(* was Int16  in paco but should be systemSize (conflict with current release) *)
					ELSE
						(* for variables, system sizeof could represent the physically occupied size
							determined via the type descriptor, implement that ? *)
						Error(parameter0.position,Diagnostics.Invalid,"is not a type symbol");
					END
				(* ---- SYSTEM.TRACE -----*)
				ELSIF (id = Global.systemTrace) & CheckArity(1,MAX(LONGINT)) THEN
					FOR i := 0 TO numberActualParameters-1 DO
						parameter0 := actualParameters.GetExpression(i);
						IF ~IsBasicType(parameter0.type) & ~IsStringType(parameter0.type) THEN
							Error(parameter0.position,Diagnostics.Invalid,"incompatible parameter");
						END;
					END;
					(* remaining issues can only be tested in backend *)
				(* ---- ADDRESSOF----- *)
				ELSIF (id = Global.systemAdr) & CheckArity(1,1) THEN
					IF HasAddress(parameter0) THEN
						type := system.addressType;
					ELSE
						type := SyntaxTree.invalidType;
						Error(parameter0.position,Diagnostics.Invalid,"has no address");

					END;
				(* ---- BIT ----- *)
				ELSIF (id = Global.systemBit) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckSizeType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
						parameter1 := NewConversion(parameter1.position,parameter1,system.addressType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
					type := system.booleanType;
				(* ----- MSK ---- *)
				ELSIF (id = Global.systemMsk) & CheckArity(2,2) THEN
					IF CheckIntegerType(parameter0) & CheckIntegerType(parameter1) THEN
						ConvertOperands(parameter0,parameter1);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
					type := parameter0.type;
				(* ---- SYSTEM.GET64 ----- *)
				ELSIF (id = Global.systemGet64) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.hugeintType;
				(* ---- SYSTEM.GET32 ----- *)
				ELSIF (id = Global.systemGet32) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.longintType;
				(* ---- SYSTEM.GET16 ----- *)
				ELSIF (id = Global.systemGet16) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.integerType;
				(* ---- SYSTEM.GET8 ----- *)
				ELSIF (id = Global.systemGet8) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
					type := system.shortintType;
				(* ---- SYSTEM.GetStackPointer ----- *)
				ELSIF (id = Global.systemGetStackPointer) & CheckArity(0,0) THEN
					type := system.addressType;
				(* ---- SYSTEM.GetFramePointer ----- *)
				ELSIF (id = Global.systemGetFramePointer) & CheckArity(0,0) THEN
					type := system.addressType;
				(* ---- SYSTEM.GetActivity ----- *)
				ELSIF cooperative & (id = Global.systemGetActivity) & CheckArity(0,0) THEN
					type := system.objectType;
				(* ---- SYSTEM.SetStackPointer ----- *)
				ELSIF (id = Global.systemSetStackPointer) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.SetFramePointer ----- *)
				ELSIF (id = Global.systemSetFramePointer) & CheckArity(1,1) THEN
					IF CheckAddressType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.SetActivity ----- *)
				ELSIF cooperative & (id = Global.systemSetActivity) & CheckArity(1,1) THEN
					IF CheckObjectType(parameter0) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- LSH, LSL, ROT, ROR ----- *)
				ELSIF ((id = Global.Lsh) OR (id = Global.Rot) OR (id= Global.Ror)) & CheckArity(2,2) THEN
				 	type := type0;

				 	parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
				 	actualParameters.SetExpression(1, parameter1);

					IF IsIntegerValue(parameter0,i0) & IsIntegerValue(parameter1,i1) THEN
						IF id = Global.Lsh THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,LSH(i0,i1)));
						ELSIF id = Global.Rot THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ROT(i0,i1)));
						ELSIF id = Global.Ror THEN
							result.SetResolved(SyntaxTree.NewIntegerValue(position,ROR(i0,i1)));
						END;
					END;
				(* ---- SYSTEM.VAL ----- *)
				ELSIF (id = Global.systemVal) & CheckArity(2,2) THEN
					IF CheckTypeDeclarationType(parameter0) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						IF (type.resolved IS SyntaxTree.ArrayType) & (type.resolved(SyntaxTree.ArrayType).form # SyntaxTree.Static) THEN
							result := SyntaxTree.invalidExpression;
							Error(parameter0.position,Diagnostics.Invalid,"is no basic type");
						ELSE
							 IF (parameter1.resolved # NIL) THEN
								parameter0 := ConvertValue(parameter1.position,parameter1.resolved,type);
								IF parameter0 IS SyntaxTree.Value THEN
									result.SetResolved(parameter0(SyntaxTree.Value));
								END;
							END;
							result.SetAssignable(parameter1.assignable);
						END;
					END;
				(* ---- SYSTEM.GET ----- *)
				ELSIF (id = Global.systemGet) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) & CheckVariable(parameter1) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.PUT ----- *)
				ELSIF (id = Global.systemPut) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
					END;
				(* ---- SYSTEM.PUT64 ----- *)
				ELSIF (id = Global.systemPut64) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.hugeintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT32 ----- *)
				ELSIF (id = Global.systemPut32) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT16 ----- *)
				ELSIF (id = Global.systemPut16) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.integerType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.PUT8 ----- *)
				ELSIF (id = Global.systemPut8) & CheckArity(2,2) THEN
					IF CheckAddressType(parameter0) & CheckBasicType(parameter1) THEN
						parameter0 := NewConversion(parameter0.position,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(parameter1.position,parameter1,system.shortintType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ---- SYSTEM.MOVE ----- *)
				ELSIF (id = Global.systemMove) & CheckArity(3,3) THEN
					IF CheckAddressType(parameter0) & CheckAddressType(parameter1) & CheckAddressType(parameter2) THEN
						parameter0 := NewConversion(0,parameter0,system.addressType,NIL);
						parameter1 := NewConversion(0,parameter1,system.addressType,NIL);
						parameter2 := NewConversion(0,parameter2,system.addressType,NIL);
						actualParameters.SetExpression(0,parameter0);
						actualParameters.SetExpression(1,parameter1);
						actualParameters.SetExpression(2,parameter2);
					END;
				(* ---- SYSTEM.NEW ----- *)
				ELSIF (id = Global.systemNew) & CheckArity(2,2) THEN
					IF ~IsPointerType(parameter0.type) THEN
						Error(parameter0.position,Diagnostics.Invalid,"is not a pointer")
					ELSIF CheckSizeType(parameter1) THEN
						parameter1 := NewConversion(Diagnostics.Invalid, parameter1, system.sizeType,NIL);
						actualParameters.SetExpression(1,parameter1);
					END;
				(* ----SYSTEM.REF ---- *)
				ELSIF (id = Global.systemRef) & CheckArity(1,1) & CheckStringType(parameter0) THEN
					type := system.addressType
				(* ---- INCR ----- *)
				ELSIF (id = Global.Incr) & CheckArity(1,2) THEN
					type := system.sizeType;
					base := type0;
					IF (numberActualParameters =2) & CheckSizeType(parameter1) THEN
						IF ~IsIntegerValue(parameter1,i1) THEN i1 := 0 END;
						IF i1 < 0 THEN
							Error(position,Diagnostics.Invalid,"invalid dimension");
							base := SyntaxTree.invalidType;
						ELSE
							base := ArrayBase(base,i1);
							IF (base # NIL) & Indexable(base) THEN
							ELSE
								Error(position,Diagnostics.Invalid,"len on no array");
								IF VerboseErrorMessage THEN
									Printout.Info("base",base);
								END;
								base := SyntaxTree.invalidType;
							END;
						END;
						parameter1 := NewConversion(parameter1.position,parameter1,system.longintType,NIL);
						actualParameters.SetExpression(1,parameter1);
						IF (numberActualParameters =2) & (parameter1 IS SyntaxTree.IntegerValue) THEN
							mathArrayType := base(SyntaxTree.MathArrayType);
							IF (mathArrayType.form = SyntaxTree.Static) THEN
								result := SyntaxTree.NewIntegerValue(position,ToMemoryUnits(system,mathArrayType.staticIncrementInBits));
								type := system.longintType;
							END;
						END;
					ELSE
						type := system.longintType;
					END;


				(* ---- SUM ----- *)
				ELSIF (id = Global.Sum) & CheckArity(1,2) THEN (* can only be found by overloading *)
					Error(position, Diagnostics.Invalid, "sum operator not applicable");
				(* ---- ALL ----- *)
				ELSIF (id = Global.All) & CheckArity(2,3) THEN (* can only be found by overloading *)
					Error(position, Diagnostics.Invalid, "all operator not applicable");
				(* ---- DIM ----- *)
				ELSIF (id = Global.Dim) & CheckArity(1,1) THEN
					type := system.sizeType;
					IF type0 IS SyntaxTree.MathArrayType THEN
						IF type0(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor THEN
							i := Dimension(type0,{SyntaxTree.Open,SyntaxTree.Static});
							result.SetResolved(SyntaxTree.NewIntegerValue(position,i));
						END;
					ELSE
						Error(position,Diagnostics.Invalid,"dimension on non math array type");
					END;
				(* ---- CAS ----- *)
				ELSIF (id = Global.Cas) & CheckArity(3,3) THEN
					IF type0.IsComposite () THEN
						Error(position,Diagnostics.Invalid,"first parameter of composite type");
						result := SyntaxTree.invalidExpression;
					ELSIF ~IsVariable (parameter0) THEN
						Error(position,Diagnostics.Invalid,"first parameter not assignable");
						result := SyntaxTree.invalidExpression;
					ELSIF ~CompatibleTo(system,type1,type0) THEN
						Error(position,Diagnostics.Invalid,"second parameter incompatible");
						result := SyntaxTree.invalidExpression;
					ELSIF ~CompatibleTo(system,type2,type0) THEN
						Error(position,Diagnostics.Invalid,"third parameter incompatible");
						result := SyntaxTree.invalidExpression;
					ELSE
						parameter1 := NewConversion(Diagnostics.Invalid,parameter1,type0,NIL); actualParameters.SetExpression(1,parameter1);
						parameter2 := NewConversion(Diagnostics.Invalid,parameter2,type0,NIL); actualParameters.SetExpression(2,parameter2);
						type := type0;
					END;
				(* ---- RESHAPE ----- *)
				ELSIF (id = Global.Reshape) & CheckArity(2,2) THEN
					IF type0 IS SyntaxTree.MathArrayType THEN
						(* use type checking facilities of procedure calls: artificially build parameters here and call checker *)
						base := ArrayBase(type0,MAX(LONGINT));
						type := SyntaxTree.NewMathArrayType(Diagnostics.Invalid,currentScope,SyntaxTree.Tensor);
						type(SyntaxTree.MathArrayType).SetArrayBase(base);

						parameterType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid,currentScope,SyntaxTree.Tensor);
						parameterType(SyntaxTree.MathArrayType).SetArrayBase(base);
						IF ~CompatibleTo(system,type0,parameterType) THEN
							Error(parameter0.position,Diagnostics.Invalid,"incompatible parameter in reshape");
							result := SyntaxTree.invalidExpression;
						ELSE
							parameter0 := NewConversion(Diagnostics.Invalid,parameter0,parameterType,NIL); actualParameters.SetExpression(0,parameter0);
						END;

						parameterType := SyntaxTree.NewMathArrayType(Diagnostics.Invalid,currentScope,SyntaxTree.Open);
						parameterType(SyntaxTree.MathArrayType).SetArrayBase(system.longintType);
						IF ~CompatibleTo(system,type1,parameterType) THEN
							Error(parameter1.position,Diagnostics.Invalid,"parameter incompatible to math array of longint");
							result := SyntaxTree.invalidExpression;
						ELSE
							parameter1 := NewConversion(Diagnostics.Invalid,parameter1,parameterType,NIL); actualParameters.SetExpression(1,parameter1);
						END;
					ELSE
						Error(position, Diagnostics.Invalid,"reshape on non math array type");
						result := SyntaxTree.invalidExpression;
					END;
				(* ---- SYSTEM.TYPECODE ----- *)
				ELSIF (id = Global.systemTypeCode) & CheckArity(1,1) THEN
					IF (parameter0.type = SyntaxTree.typeDeclarationType) THEN
						type := parameter0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
						type := type.resolved;
						IF type IS SyntaxTree.PointerType THEN
							type := type(SyntaxTree.PointerType).pointerBase.resolved;
						END;
						IF ~(type IS SyntaxTree.RecordType) THEN
							Error(parameter0.position,Diagnostics.Invalid,"must be type with type descriptor");
						END;
					ELSE
						Error(parameter0.position,Diagnostics.Invalid,"is not a type symbol");
					END;
					type := system.addressType;
				(* -------- FLT --------- *)
				ELSIF (id = Global.Flt) & CheckArity(1,1) THEN
					type := system.realType;
					IF IsRealValue(parameter0, r) THEN
						result.SetResolved(SyntaxTree.NewRealValue(position, r));
					ELSIF CheckIntegerType(parameter0) & IsIntegerValue(parameter0, i) THEN
						i0 := i; i := ABS(i);
						IF i # 0 THEN
							i1 := 23;
							IF i >= 2*800000H THEN
								REPEAT i := i DIV 2; INC(i1) UNTIL i < 2*800000H;
							ELSIF i < 800000H THEN
								REPEAT i := 2 * i; DEC(i1) UNTIL i >= 800000H;
							END;
							i := (i1 + 127)*800000H - 800000H + i;
							IF i0 < 0 THEN i := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, i) + {31}); END;
						END;
						result.SetResolved(SyntaxTree.NewRealValue(position, SYSTEM.VAL(REAL, i)));
					END;
				(* ------- CONNECT -------*)
				ELSIF (id = Global.Connect) & (CheckArity(2,3)) THEN
					IF 	~(currentIsCellNet) THEN
						Error(position,Diagnostics.Invalid,"connection outside activeCells body block");
					END;

					IF CheckPortType(parameter0, outPort) & CheckPortType(parameter1, inPort) THEN
						IF (outPort.direction # SyntaxTree.OutPort) THEN Error(parameter0.position,Diagnostics.Invalid,"not an out-port") END;
						IF (inPort.direction # SyntaxTree.InPort) THEN Error(parameter1.position,Diagnostics.Invalid,"not an in-port") END;
					END;

					IF numberActualParameters = 3 THEN
						IF ~cellsAreObjects & ~IsIntegerValue(parameter2,i0) & (i0>=0) THEN
							Error(position,Diagnostics.Invalid,"incompatible channel size parameter");
						END;
						parameter2 := NewConversion(Diagnostics.Invalid,parameter2,system.longintType,NIL);
						actualParameters.SetExpression(2,parameter2);
					END;

					activeCellsStatement := TRUE;
				(* ---------- DELEGATE --------*)
				ELSIF (id = Global.Delegate) & (CheckArity(2,2)) THEN
					IF 	~(currentIsCellNet) THEN
						Error(position,Diagnostics.Invalid,"connection delegation outside activeCells body block");
					END;
					IF ~CheckPortType(parameter1, inPort) THEN
						Error(parameter0.position,Diagnostics.Invalid,"not a port")
					ELSIF ~CheckPortType(parameter0, outPort) THEN
						Error(parameter1.position,Diagnostics.Invalid,"not a port")
					ELSIF (outPort.direction # inPort.direction) THEN
						Error(parameter0.position,Diagnostics.Invalid,"invalid port direction");
					ELSIF outPort.sizeInBits # inPort.sizeInBits THEN
						Error(position,Diagnostics.Invalid,"incompatible port sizes");
					END;
					activeCellsStatement := TRUE;
				(* --------- RECEIVE ---------*)
				ELSIF (id = Global.Receive) & CheckArity(2,3) THEN
					IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,position) END;
					IF CheckPortType(parameter0,inPort) & CheckVariable(parameter1) THEN
						IF inPort.direction # SyntaxTree.InPort THEN
							Error(parameter0.position,Diagnostics.Invalid,"not an in-port")
						ELSIF inPort.sizeInBits # system.SizeOf(parameter1.type) THEN
							Error(parameter1.position,Diagnostics.Invalid,"incompatible to port type");
						END;
						IF (numberActualParameters=3) & CheckVariable(parameter2) THEN
							IF ~SameType(parameter2.type, system.integerType) THEN
								Error(parameter2.position,Diagnostics.Invalid,"incompatible to integer type");
							END;
						END;
					END;
				(* --------- SEND ---------*)
				ELSIF (id = Global.Send) & CheckArity(2,2) THEN
					IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,position) END;
					IF CheckPortType(parameter0,outPort)  THEN
						IF outPort.direction # SyntaxTree.OutPort THEN
							Error(parameter1.position,Diagnostics.Invalid,"not an out-port")
						ELSIF outPort.sizeInBits # system.SizeOf(parameter1.type) THEN
							Error(parameter1.position,Diagnostics.Invalid,"incompatible to port type");
						ELSE
							parameter1 := NewConversion(position,parameter1,parameter0.type.resolved,NIL);
							actualParameters.SetExpression(1,parameter1);
						END;
					END;
				(* ------- custom builtins ----- *)
				ELSIF id = Global.systemSpecial THEN
					customBuiltin := builtin(SyntaxTree.CustomBuiltin);
					ASSERT(customBuiltin.type IS SyntaxTree.ProcedureType);
					procedureType := customBuiltin.type(SyntaxTree.ProcedureType);
					type := procedureType.returnType;
					IF CheckArity(procedureType.numberParameters, procedureType.numberParameters) THEN (* check parameter count *)
						(* go through all formal parameters *)
						formalParameter := procedureType.firstParameter;
						FOR i := 0 TO actualParameters.Length() - 1 DO
							actualParameter := actualParameters.GetExpression(i);
							IF actualParameter = SyntaxTree.invalidExpression THEN
							ELSIF ~ParameterCompatible(formalParameter,actualParameter) THEN
								Error(position,Diagnostics.Invalid, "incompatible parameter")
							ELSE
								actualParameter := NewConversion(actualParameter.position, actualParameter, formalParameter.type, NIL)
							END;
							actualParameters.SetExpression(i, actualParameter);
							formalParameter := formalParameter.nextParameter
						END
					END

				ELSE
					Error(position,Diagnostics.Invalid,"builtin not implemented");
					result := SyntaxTree.invalidExpression;
				END;
			END;

			IF result # SyntaxTree.invalidExpression THEN
				type := ResolveType(type);
				IF result.resolved # NIL THEN result.resolved.SetType(type) END;
				result.SetType(type);
			END;

			RETURN result
		END NewBuiltinCallDesignator;

		(** return type guard designator left(type)
			- check if type can be extended (i.e. is no static record)
			- check if type is a type extension of left.type
			- returns new type guard designator
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE NewTypeGuardDesignator(position: LONGINT; left: SyntaxTree.Designator; type: SyntaxTree.Type): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator;
		BEGIN
			result := SyntaxTree.invalidDesignator;

			IF ~IsTypeExtension(left.type.resolved,type.resolved) THEN
				Error(position,Diagnostics.Invalid,"no type extension of type");
				IF VerboseErrorMessage THEN
					Printout.Info("left",left);
					Printout.Info("type",type);
				END;
			ELSIF ~(left.type.resolved = type.resolved) & ~IsExtensibleDesignator(left) THEN (* left is not extensible *)
				Error(position,Diagnostics.Invalid,"variable cannot be extended");
			ELSE
				result := SyntaxTree.NewTypeGuardDesignator(position,left,type);
				result.SetType(type);
				result.SetAssignable(left.assignable);
			END;
			RETURN result
		END NewTypeGuardDesignator;

		(** check and resolve parameter designator left(expression list)
			- check expression list
			- if one parameter and left is extensible type and parameter contains type declaration then return TypeGuardDesignator
			- elsif left is a procedure type then
				- if left is a built-in procedure then return NewBuiltinCallDesignator
				- else return is a procedure call then return ProcedureCallDesignator
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE VisitParameterDesignator(designator: SyntaxTree.ParameterDesignator);
		VAR
			parameters: SyntaxTree.ExpressionList;
			left: SyntaxTree.Designator;
			result,expression: SyntaxTree.Expression;
			typeDeclaration: SyntaxTree.TypeDeclaration;
			type, expressionType: SyntaxTree.Type;

			PROCEDURE BaseType(type: SyntaxTree.Type): SyntaxTree.Type;
			BEGIN
				type := type.resolved;
				WHILE (type # NIL) & (type IS SyntaxTree.MathArrayType) DO
					type := Resolved(type(SyntaxTree.MathArrayType).arrayBase);
				END;
				RETURN type
			END BaseType;

		BEGIN
			IF Trace THEN D.Str("VisitParameterDesignator"); D.Ln; END;
			result := SyntaxTree.invalidDesignator;
			left := ResolveDesignator(designator.left);
			IF left # SyntaxTree.invalidDesignator THEN
				parameters := designator.parameters;
				IF ExpressionList(parameters) THEN
					IF (left.type = NIL) THEN
						Error(left.position,Diagnostics.Invalid,"object is not a procedure or cannot be extended");
					ELSIF IsExtensibleDesignator(left) & (parameters.Length()=1) & IsTypeDesignator(parameters.GetExpression(0),typeDeclaration) THEN
						result := NewTypeGuardDesignator(designator.position,left,typeDeclaration.declaredType)
					ELSIF IsUnextensibleRecord(left) & (parameters.Length()=1) & IsTypeDesignator(parameters.GetExpression(0),typeDeclaration) & (typeDeclaration.declaredType.resolved = left.type.resolved) THEN
						result := NewTypeGuardDesignator(designator.position,left,typeDeclaration.declaredType)
					ELSIF (left.type.resolved IS SyntaxTree.ProcedureType) THEN
						IF (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Builtin) THEN
							result := NewBuiltinCallDesignator(designator.position,left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Builtin),parameters,left);
						ELSE
							result := NewProcedureCallDesignator(designator.position,left,parameters)
						END
					ELSIF IsTypeDesignator(left,typeDeclaration)  & (parameters.Length()=1) THEN
						expression := parameters.GetExpression(0);
						type := typeDeclaration.declaredType.resolved;
						expressionType := BaseType(expression.type); (* type or base type of math array, if applicable *)
						IF ((type IS SyntaxTree.NumberType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType)) &
							((expressionType IS SyntaxTree.NumberType) OR (expressionType IS SyntaxTree.AddressType) OR (expressionType IS SyntaxTree.SizeType)
							OR (expressionType IS SyntaxTree.EnumerationType)
							) THEN
							result := NewConversion(designator.position,expression,typeDeclaration.declaredType,left)
						ELSE
							Error(left.position,Diagnostics.Invalid,"invalid type in explicit conversion");
						END;
					ELSE
						Error(left.position,Diagnostics.Invalid,"called object is not a procedure or cannot be extended");
						IF VerboseErrorMessage THEN Printout.Info("designator",designator); Printout.Info("left",left) END;
						result := SyntaxTree.invalidDesignator;
					END;
				ELSE
					result := SyntaxTree.invalidDesignator
				END;
			END;
			resolvedExpression := result;
		END VisitParameterDesignator;

		(** check dereference designator left^
			 - check if left is pointer type or left is object type
			 - return new dereference designator with type = left.baseType.type (if appropriate)
			with error handling
			returns invalidDesignator = invalidExpression if error
		**)
		PROCEDURE NewDereferenceDesignator(position: LONGINT; left: SyntaxTree.Designator): SyntaxTree.Designator;
		VAR type: SyntaxTree.Type; result: SyntaxTree.Designator;
		BEGIN
			result := SyntaxTree.invalidDesignator;
			type := left.type;
			IF (type # NIL) & ((type.resolved IS SyntaxTree.PointerType)) THEN
				type := type.resolved(SyntaxTree.PointerType).pointerBase;
				result := SyntaxTree.NewDereferenceDesignator(position,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSIF (type # NIL) & (type.resolved IS SyntaxTree.ArrayType) & (type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) THEN
				type := type.resolved;
				result := SyntaxTree.NewDereferenceDesignator(position,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSIF (type # NIL) & (type.resolved IS SyntaxTree.CellType) THEN
				result := SyntaxTree.NewDereferenceDesignator(position,left);
				result.SetAssignable(TRUE);
				result.SetType(type);
				result.SetHidden(left.isHidden);
			ELSE
				Error(position,Diagnostics.Invalid,"dereference on no pointer");
				IF VerboseErrorMessage THEN
					Printout.Info("pointer", type);
					Printout.Info("scope", currentScope);
				END;
			END;
			RETURN result
		END NewDereferenceDesignator;

		(** check supercall designator left^
			- if left is symbol designator with procedure symbol containing non-nil supermethod then
				- return new supercall designator with type = left.type
			with error handling
		**)
		PROCEDURE NewSupercallDesignator(position: LONGINT; left: SyntaxTree.Designator): SyntaxTree.Designator;
		VAR result: SyntaxTree.Designator; symbol: SyntaxTree.Symbol; procedure: SyntaxTree.Procedure;
			objectScope: SyntaxTree.Scope;
		BEGIN
			result := SyntaxTree.invalidDesignator;
			IF left = SyntaxTree.invalidDesignator THEN
				(* error already handled *)
			ELSIF left IS SyntaxTree.SymbolDesignator THEN
				symbol := left(SyntaxTree.SymbolDesignator).symbol;
				ASSERT(symbol # SyntaxTree.invalidSymbol);
				IF symbol IS SyntaxTree.Procedure THEN
					procedure := symbol(SyntaxTree.Procedure);
					objectScope := currentScope;
					WHILE (objectScope # NIL) & ~(objectScope IS SyntaxTree.RecordScope) DO
						objectScope := objectScope.outerScope;
					END;
					IF (left.left = NIL) OR ~
						(
						(left.left IS SyntaxTree.SelfDesignator) OR
						(left.left IS SyntaxTree.DereferenceDesignator)
						& (left.left(SyntaxTree.Designator).left # NIL)
						& (left.left(SyntaxTree.Designator).left IS SyntaxTree.SelfDesignator)) OR (procedure.scope # objectScope)  THEN
						Error(position,Diagnostics.Invalid,"procedure not in immediate object scope");
						IF VerboseErrorMessage THEN
							Printout.Info("left.left",left.left);
						END;
					ELSIF procedure.super # NIL THEN
						result := SyntaxTree.NewSupercallDesignator(position,left);
						result.SetType(left.type.resolved)
					ELSE
						Error(position,Diagnostics.Invalid,"no supermethod for this procedure");
					END;
				ELSE
					Error(position,Diagnostics.Invalid,"symbol is not a procedure");
				END;
			ELSE
				Error(position,Diagnostics.Invalid,"is no symbol designator");
			END;

			RETURN result
		END NewSupercallDesignator;

		(** check and semantically resolve arrow designator left^
			- if left is procedure type -> result := SupercallDesignator
			- else result :=  DereferenceDesignator
			returns result via global variable resolvedExpression
			error handling deferred to procedures SupercallDesignator and DereferenceDesignator
		**)
		PROCEDURE VisitArrowDesignator(arrowDesignator: SyntaxTree.ArrowDesignator);
		VAR left: SyntaxTree.Designator;
		BEGIN
			IF Trace THEN D.Str("VisitArrowDesignator"); D.Ln; END;
			left := ResolveDesignator(arrowDesignator.left);
			IF left # NIL THEN
				IF (left.type = NIL) THEN
					Error(arrowDesignator.position,Diagnostics.Invalid,"Invalid arrow designator");
				ELSIF (left.type.resolved # NIL) & (left.type.resolved IS SyntaxTree.ProcedureType) THEN
					resolvedExpression := NewSupercallDesignator(arrowDesignator.position,left);
				ELSE
					IF IsPointerToObject(left.type) THEN
						Warning(arrowDesignator.position,  "forbidden dereference on object"); 
					END;
					resolvedExpression := NewDereferenceDesignator(arrowDesignator.position,left)
				END
			END
		END VisitArrowDesignator;

		(** check and return expression
			- if expression has no type then resolve expression
			- resulting expression is exchanged via global variable "resolvedExpression" which makes this mechanism thread-unsafe
			- return result
		**)
		PROCEDURE ResolveExpression(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR result,prev: SyntaxTree.Expression;
		BEGIN
			IF expression = NIL THEN result := NIL
			ELSIF (expression.type = NIL) THEN
				prev := resolvedExpression;
				resolvedExpression := SyntaxTree.invalidExpression;
				IF ~(expression IS SyntaxTree.BuiltinCallDesignator) THEN
					expression.SetType(SyntaxTree.invalidType);
				END;
				expression.Accept(SELF);
				result := resolvedExpression;
				IF currentIsRealtime THEN
					IF (result.type # NIL) & ~result.type.resolved.isRealtime THEN
						Error(expression.position,Diagnostics.Invalid,"forbidden non-realtime expression in realtime procedure");
					END;
				END;
				(* designator modifiers for backends if they support it ...*)
				IF (expression IS SyntaxTree.Designator) & (expression(SyntaxTree.Designator).modifiers # NIL) & (result IS SyntaxTree.Designator) THEN
					result(SyntaxTree.Designator).SetModifiers(expression(SyntaxTree.Designator).modifiers);
					CheckModifiers(result(SyntaxTree.Designator).modifiers, FALSE);
				END;
				resolvedExpression := prev
			ELSE
				result := expression
			END;
			RETURN result
		END ResolveExpression;

		(**
			check expression to be constant expression
			- resolve expression
			- if valid then check that of value type
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantExpression(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: LONGINT;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.resolved = NIL) THEN
				Error(position,Diagnostics.Invalid,"expression is not constant");
				IF VerboseErrorMessage THEN Printout.Info("expression",expression); END;
				expression := SyntaxTree.invalidExpression;
			END;
			RETURN expression
		END ConstantExpression;

		(** check expression to be constant integer
			- resolve expresssion
			- if valid then check that of integer value type
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantInteger(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: LONGINT;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.resolved = NIL) OR ~(expression.resolved IS SyntaxTree.IntegerValue) THEN
				expression := SyntaxTree.invalidExpression;
				Error(position,Diagnostics.Invalid,"expression is not a constant integer");
			END;
			RETURN expression
		END ConstantInteger;

		(** check expression as positive (>=0) constant integer
			- resolve expression
			- if valid then check that integer value
			- if integer value then check that value >= 0
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ConstantIntegerGeq0(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: LONGINT;
		BEGIN
			position := expression.position;
			expression := ConstantExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN
				(* error already reported *)
			ELSIF  (expression.resolved = NIL) OR ~(expression.resolved IS SyntaxTree.IntegerValue) THEN
				Error(position,Diagnostics.Invalid,"expression is not integer valued");
				expression := SyntaxTree.invalidExpression
			ELSIF (expression.resolved(SyntaxTree.IntegerValue).hvalue <0) THEN
				Error(position,Diagnostics.Invalid,"integer is not greater or equal zero");
			END;
			RETURN expression
		END ConstantIntegerGeq0;

		(** check expression as condition
			- resolve expression
			- if valid expression then check that result type is boolean
			report error and return invalidExpression if anything fails
		**)
		PROCEDURE ResolveCondition(expression: SyntaxTree.Expression): SyntaxTree.Expression;
		VAR position: LONGINT;
		BEGIN
			position := expression.position;
			expression := ResolveExpression(expression);
			IF expression = SyntaxTree.invalidExpression THEN (* error already reported *)
			ELSIF (expression.type = NIL) OR ~(expression.type.resolved IS SyntaxTree.BooleanType) THEN
				expression := SyntaxTree.invalidExpression;
				Error(position,Diagnostics.Invalid,"expression is not boolean");
			END;
			RETURN expression
		END ResolveCondition;

		(*** symbols ***)

		PROCEDURE ResolveSymbol(x: SyntaxTree.Symbol);
		BEGIN
			x.Accept(SELF);
		END ResolveSymbol;

		(** check a symbol
			- check visibility flags (symbols within procedure scope (direct or indirect) cannot be exported)
		**)
		PROCEDURE CheckSymbolVisibility(symbol: SyntaxTree.Symbol);
		VAR scope: SyntaxTree.Scope;
		BEGIN
			(* visibility *)
			scope := symbol.scope;
			WHILE (scope # NIL) & ~(scope IS SyntaxTree.ProcedureScope) DO
				scope := scope.outerScope;
			END;
			IF (scope # NIL) THEN (* symbol (directly or indirectly) in procedure scope *)
				IF (symbol.access * SyntaxTree.Public # {}) & (~(symbol IS SyntaxTree.Procedure) OR  ~symbol(SyntaxTree.Procedure).isBodyProcedure & ~symbol(SyntaxTree.Procedure).isConstructor & ~symbol(SyntaxTree.Procedure).isFinalizer)  THEN
					Error(symbol.position,Diagnostics.Invalid,"cannot be exported");
					IF VerboseErrorMessage THEN
						Printout.Info("symbol",symbol);
					END;
				END;
			END;
		END CheckSymbolVisibility;

				(** Check if a node has already been resolved. If not then mark as currently being resolved.
			If node is currently being resolved then emit a cyclic definition error.
			Return TRUE only if node is fully resolved.
		**)
		PROCEDURE SymbolNeedsResolution(x: SyntaxTree.Symbol): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			IF SyntaxTree.Resolved IN x.state THEN
				result := FALSE
			ELSIF SyntaxTree.BeingResolved IN x.state THEN
				Error(x.position,Diagnostics.Invalid,"cyclic definition");
				result := FALSE;
			ELSE
				result := TRUE;
				x.SetState(SyntaxTree.BeingResolved)
			END;
			RETURN result
		END SymbolNeedsResolution;


		(** check and resolve a type declaration symbol = Type
			- set type to declaration type
				-> the type of a type declaration is NOT the declared type but the "declaration" type.
				     This is so because the type declaration itself does not have a type but it only stands for a type.
				     In the implementation of the compiler this made a lot much easier.
			- resolve and set declared type
			- check symbol
		**)
		PROCEDURE VisitTypeDeclaration(typeDeclaration: SyntaxTree.TypeDeclaration);
		VAR prevScope: SyntaxTree.Scope;
		BEGIN
			IF Trace THEN D.Str("VisitTypeDeclaration "); D.Str0(typeDeclaration.name);  D.Ln;  END;
			IF SymbolNeedsResolution(typeDeclaration) THEN
				prevScope := currentScope;
				currentScope := typeDeclaration.scope;
				typeDeclaration.SetType(SyntaxTree.typeDeclarationType);
				typeDeclaration.SetDeclaredType(ResolveType(typeDeclaration.declaredType));
				CheckSymbolVisibility(typeDeclaration);
				typeDeclaration.SetState(SyntaxTree.Resolved);
				currentScope := prevScope;
			END;
		END VisitTypeDeclaration;

		(** check and resolve a constant declaration symbol = (constant) expression
			- check expression
			- set type and value
			- check symbol
		**)
		PROCEDURE VisitConstant(constant: SyntaxTree.Constant);
		VAR
			expression: SyntaxTree.Expression;
			type: SyntaxTree.Type;
			name: Basic.SegmentedName;
			replacement: Replacement;
			stringReader: Streams.StringReader;
			scanner: Scanner.Scanner; parser: Parser.Parser;
		BEGIN
			IF Trace THEN D.Str("VisitConstant "); D.Str0(constant.name);  D.Ln;  END;
			IF SymbolNeedsResolution(constant) THEN
				expression := constant.value;
				IF replacements # NIL THEN
					Global.GetSymbolSegmentedName(constant, name);
					replacement := replacements;
					WHILE (replacement # NIL) & (replacement.name # name) DO
						replacement := replacement.next;
					END;
					IF replacement # NIL THEN
						InfoSS(constant.position, "replacing constant", constant.name);
						(*
						NEW(stringReader, Strings.Length(replacement.string^));
						stringReader.Set(replacement.string^);
						NEW(scanner, replacement.string^, stringReader,0, diagnostics);
						NEW(parser, scanner, diagnostics);
						expression := parser.Expression();
						*)
						expression := replacement.expression;
						replacement.used := TRUE;
					END;
				END;

				constant.SetType(SyntaxTree.invalidType);
				expression := ConstantExpression(expression);
				ASSERT(expression.type # NIL);
				type := expression.type.resolved;
				constant.SetType(type);
				constant.SetValue(expression);
				CheckSymbolVisibility(constant);
				constant.SetState(SyntaxTree.Resolved);
			END;
		END VisitConstant;

		PROCEDURE AdaptStackAlignment(procedure: SyntaxTree.Procedure; alignment: LONGINT);
		VAR procedureAlignment: LONGINT;

			PROCEDURE LCM(a0,b0: LONGINT): LONGINT;
			(* least common multiple *)
			VAR a,b: LONGINT;
			BEGIN
				a := a0; b := b0;
				WHILE (a # b) DO
					IF a < b THEN a := a+a0
					ELSE b := b + b0
					END;
				END;
				RETURN a
			END LCM;

		BEGIN
			IF alignment > 1 THEN
				procedureAlignment := procedure.type(SyntaxTree.ProcedureType).stackAlignment;
				IF (procedureAlignment > 1) THEN
					alignment := LCM(alignment, procedureAlignment);
				END;
				procedure.type(SyntaxTree.ProcedureType).SetStackAlignment(alignment);
			END;
		END AdaptStackAlignment;


		(** check and resolve a variable / field
			- check and set type
			- negative check on open array type
			- check symbol
		**)
		PROCEDURE VisitVariable(variable: SyntaxTree.Variable);
		VAR modifiers: SyntaxTree.Modifier; value,position: LONGINT; pointerType: SyntaxTree.PointerType;
		BEGIN
			IF Trace THEN D.Str("VisitVariable "); D.Str0(variable.name);  D.Ln;  END;
			IF SymbolNeedsResolution(variable) THEN

				modifiers := variable.modifiers;
				(*
				flags := Flags(variable.modifiers,{SyntaxTree.UntracedFlag, SyntaxTree.AlignedFlag, SyntaxTree.FixedFlag});
				variable.AddFlags(flags);
				*)
				variable.SetType(ResolveType(variable.type));
				IF variable.type.resolved IS SyntaxTree.ArrayType THEN
					IF variable.type.resolved(SyntaxTree.ArrayType).length = NIL THEN
						Error(variable.position,Diagnostics.Invalid,"forbidden open array variable");
					END;
				END;
				CheckSymbolVisibility(variable);
				IF HasFlag(modifiers, Global.NameUntraced,position) THEN
					variable.SetUntraced(TRUE);
					IF ~ContainsPointer(variable.type) THEN
						IF VerboseErrorMessage THEN Printout.Info("variable",variable); Printout.Info("variable.type",variable.type.resolved); END;
						Error(position,Diagnostics.Invalid,"untraced flag on non-pointer variable");
					END;
				END;
				IF HasValue(modifiers, Global.NameAligned,position, value) THEN
					IF (variable.scope IS SyntaxTree.ProcedureScope) THEN
						IF ~PowerOf2(value) THEN
							Error(position,Diagnostics.Invalid,"forbidden alignment - must be power of two");
						ELSE
							AdaptStackAlignment(variable.scope(SyntaxTree.ProcedureScope).ownerProcedure, value);
						END;
					END;
					variable.SetAlignment(FALSE,value);
				ELSIF HasValue(modifiers, Global.NameFixed,position, value) THEN
					IF (variable.scope IS SyntaxTree.ProcedureScope) THEN
						Error(position,Diagnostics.Invalid,"fixed position not possible in procedure");
					END;
					variable.SetAlignment(TRUE, value);
				END;
				IF HasFlag(modifiers, Global.NameRegister, position) THEN variable.SetUseRegister(TRUE) END;
				IF variable.type.resolved IS SyntaxTree.CellType THEN
					IF HasValue(modifiers, Global.NameCodeMemorySize, position, value) THEN END;
					IF HasValue(modifiers, Global.NameDataMemorySize, position, value) THEN END;
				END;
				CheckModifiers(modifiers, ~InCellNetScope(variable.scope) & ~(variable.type.resolved IS SyntaxTree.CellType) & ~(variable.type.resolved IS SyntaxTree.PortType));
				IF variable.initializer # NIL THEN
					variable.SetInitializer (CompatibleConversion (variable.initializer.position, ConstantExpression(variable.initializer), variable.type));
				END;
				
				IF (variable.type.resolved IS SyntaxTree.CellType) (*& (cellsAreObjects)*) THEN
					pointerType := SyntaxTree.NewPointerType(variable.position, variable.scope);
					pointerType.SetPointerBase(variable.type);
					pointerType.SetHidden(TRUE);
					variable.SetType(ResolveType(pointerType));
				END;
				
				variable.SetState(SyntaxTree.Resolved);
			END;
		END VisitVariable;

		PROCEDURE VisitProperty(property: SyntaxTree.Property);
		BEGIN
			VisitVariable(property);
		END VisitProperty;
		

		(** check and resolve a (procedure) parameter
			- check and set type
			- check symbol
			- check parameter kind and set read-only flags if appropriate
		**)
		PROCEDURE VisitParameter(parameter: SyntaxTree.Parameter);
		VAR modifiers: SyntaxTree.Modifier; expression: SyntaxTree.Expression; position: LONGINT;
		BEGIN
			IF Trace THEN D.Str("VisitParameter "); D.Str0(parameter.name);  D.Ln;  END;
			IF SymbolNeedsResolution(parameter) THEN
				modifiers := parameter.modifiers;
				parameter.SetType(ResolveType(parameter.type));
				ASSERT(parameter.type.resolved # NIL);
				CheckSymbolVisibility(parameter);
				IF parameter.defaultValue # NIL THEN
					IF parameter.kind # SyntaxTree.ValueParameter THEN
						Error(parameter.position,Diagnostics.Invalid,"forbidden default value on non-value parameter");
					ELSE
						expression := ConstantExpression(parameter.defaultValue);
						IF CompatibleTo(system,expression.type, parameter.type) THEN
							expression := NewConversion(expression.position, expression, parameter.type, NIL);
							parameter.SetDefaultValue(expression);
						END;
					END;
				END;
				IF HasFlag(modifiers, Global.NameUntraced,position) THEN
					parameter.SetUntraced(TRUE);
					IF ~ContainsPointer(parameter.type) THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position,Diagnostics.Invalid,"untraced flag on non-pointer variable");
					END;
				END;
				IF HasFlag(modifiers, Global.NameMovable,position) THEN
					parameter.SetMoveable(TRUE);
					IF ~(parameter.type.resolved IS SyntaxTree.AddressType) THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position,Diagnostics.Invalid,"illegal movable flag on non-address variable");
					ELSIF parameter.kind = SyntaxTree.VarParameter THEN
						IF VerboseErrorMessage THEN Printout.Info("parameter",parameter); Printout.Info("parameter.type",parameter.type.resolved); END;
						Error(position,Diagnostics.Invalid,"unnecessary movable flag on variable variable");
					END;
				END;
				CheckModifiers(modifiers, ~InCellNetScope(parameter.scope) & ~(parameter.type.resolved IS SyntaxTree.CellType) & ~(parameter.type.resolved IS SyntaxTree.PortType));
				parameter.SetState(SyntaxTree.Resolved);
			END;
		END VisitParameter;

		(** check and resolve a procedure (with declaration and implementation scope)
			- check the procedure type
			- check if method (i.e. in record scope), if so then
				- check if (unique) constructor
				- check if (unique) finalizer
				- check if super method available, if so then check signature
			- of not in record scope then negative check on constructor flag
			- of not in record scope then negative check on finalizer flag
			- check declarations (including a delayed implementation check, cf procedure Declarations)
			- check procedure symbol
		**)
		PROCEDURE VisitProcedure(procedure: SyntaxTree.Procedure);
		VAR super,proc: SyntaxTree.Procedure; record: SyntaxTree.RecordType;
			procedureType: SyntaxTree.ProcedureType;
			selfParameter: SyntaxTree.Parameter; qualifiedIdentifier: SyntaxTree.QualifiedIdentifier;
			qualifiedType: SyntaxTree.QualifiedType;
			value: LONGINT;
			modifiers: SyntaxTree.Modifier; recentIsRealtime, recentIsBodyProcedure: BOOLEAN;
			position: LONGINT;
		BEGIN
			IF Trace THEN D.Str("VisitProcedure "); D.Str0(procedure.name);  D.Ln;  END;
			IF IsOberonInline(procedure) THEN
				IF SyntaxTree.Public * procedure.access # {} THEN
					Error(procedure.position, Diagnostics.Invalid, "Export of Oberon Inline Not Yet Implemented")
				END;
				procedure.SetInline(FALSE);
				procedure.SetOberonInline(TRUE);
			END;

			IF SymbolNeedsResolution(procedure) THEN
				recentIsRealtime := currentIsRealtime;
				recentIsBodyProcedure := currentIsBodyProcedure;

				IF Trace THEN D.Str("undefined"); D.Ln; END;
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				modifiers := procedureType.modifiers;
				IF HasFlag(modifiers, Global.NameWinAPI,position) THEN procedureType.SetCallingConvention(SyntaxTree.WinAPICallingConvention)
				ELSIF HasFlag(modifiers, Global.NameC,position) THEN
					IF useDarwinCCalls THEN	(*fld*)
						procedureType.SetCallingConvention(SyntaxTree.DarwinCCallingConvention)
					ELSE
						procedureType.SetCallingConvention(SyntaxTree.CCallingConvention)
					END
				END;
				IF HasFlag(modifiers, Global.NameInterrupt, position) THEN
					procedureType.SetInterrupt(TRUE);
					procedureType.SetCallingConvention(SyntaxTree.InterruptCallingConvention)
				END;
				IF HasFlag(modifiers, Global.NameNoReturn, position) THEN
					procedureType.SetNoReturn(TRUE);
				END;
				IF HasValue(modifiers, Global.NamePcOffset, position, value) THEN procedureType.SetPcOffset(value) END;

				IF HasFlag(modifiers,Global.NameNoPAF,position) THEN procedureType.SetNoPAF(TRUE) END;
				IF HasFlag(modifiers, Global.NameEntry,position) THEN procedure.SetEntry(TRUE)
				ELSIF (procedure.scope IS SyntaxTree.ModuleScope) & HasFlag(modifiers, Global.NameExit, position) THEN procedure.SetExit(TRUE)
				END;
				IF HasValue(modifiers,Global.NameAligned,position,value) THEN procedure.SetAlignment(FALSE,value)
				ELSIF HasValue(modifiers,Global.NameFixed,position,value) THEN procedure.SetAlignment(TRUE,value)
				END;
				IF HasValue(modifiers,Global.NameStackAligned, position, value) THEN
					IF ~PowerOf2(value) THEN
						Error(position,Diagnostics.Invalid,"forbidden stack alignment - must be power of two");
					ELSE
						procedureType.SetStackAlignment(value)
					END;
				END;
				IF HasFlag(modifiers,Global.NameRealtime,position) THEN procedureType.SetRealtime(TRUE) END;
				IF HasFlag(modifiers,Global.NameFinal,position) THEN procedure.SetFinal(TRUE)
				ELSIF HasFlag(modifiers,Global.NameAbstract,position) THEN procedure.SetAbstract(TRUE)
				END;

				CheckModifiers(modifiers, TRUE);
				
				modifiers := procedureType.returnTypeModifiers;
				procedureType.SetUntracedReturn(HasFlag(modifiers, Global.NameUntraced, position));
				CheckModifiers(modifiers, TRUE);
				

				
				FixProcedureType(procedureType);
				currentIsRealtime := procedureType.isRealtime;
				currentIsBodyProcedure := procedure.isBodyProcedure;
				IF  ~system.GenerateParameterOffsets(procedure,FALSE) (* assume that this is no nested procedure, is fixed later otherwise *)
				THEN
					Error(procedure.position,Diagnostics.Invalid,"problems during parameter offset computation");
				END;

				CheckSymbolVisibility(procedure);

				IF procedure.scope IS SyntaxTree.ProcedureScope THEN
					procedure.SetLevel(procedure.scope(SyntaxTree.ProcedureScope).ownerProcedure.level+1);
					IF ~system.GenerateParameterOffsets(procedure,TRUE) THEN
						Error(procedure.position,Diagnostics.Invalid,"problem during parameter offset generation");
					END;
				END;
				IF procedure.scope IS SyntaxTree.RecordScope THEN
					record := procedure.scope(SyntaxTree.RecordScope).ownerRecord;
					procedureType.SetDelegate(TRUE);

					selfParameter := SyntaxTree.NewParameter(procedure.position,procedureType,Global.SelfParameterName,SyntaxTree.ValueParameter);
					IF record.pointerType.typeDeclaration = NIL THEN
						selfParameter.SetType(record.pointerType);
					ELSE
						qualifiedIdentifier := SyntaxTree.NewQualifiedIdentifier(procedure.position,SyntaxTree.invalidIdentifier,record.pointerType.typeDeclaration.name);
						qualifiedType := SyntaxTree.NewQualifiedType(procedure.position,procedure.scope,qualifiedIdentifier);
						qualifiedType.SetResolved(record.pointerType);
						selfParameter.SetType(qualifiedType);
					END;
					selfParameter.SetAccess(SyntaxTree.Hidden);

					(*! constructor information is redundant, we can remove "isConstructor" and repplace by constructor procedure reference *)
					IF procedure.isConstructor THEN
						(*! constructor is always visible, compatibility to paco
						procedure.SetAccess(SyntaxTree.Public+SyntaxTree.Protected+SyntaxTree.Internal);
						*)
						procedure.MarkUsed;
						IF procedureType.returnType # NIL THEN
							Error(procedure.position,Diagnostics.Invalid,"constructor with forbidden return type");
						END;
						proc := procedure.scope.firstProcedure;
						WHILE (proc # NIL) & ((proc = procedure) OR ~(proc.isConstructor)) DO
							proc := proc.nextProcedure;
						END;
						IF proc # NIL THEN
							Error(procedure.position,Diagnostics.Invalid,"duplicate constructor")
						ELSE
							procedure.scope(SyntaxTree.RecordScope).SetConstructor(procedure);
						END;
					END;
					IF procedure.isFinalizer THEN
						procedure.MarkUsed;
						IF procedureType.returnType # NIL THEN
							Error(procedure.position,Diagnostics.Invalid,"finalizer with forbidden return type");
						END;
						IF procedureType.numberParameters # 0 THEN
							Error(procedure.position,Diagnostics.Invalid,"finalizer with formal parameters");
						END;
						proc := procedure.scope.firstProcedure;
						WHILE (proc # NIL) & ((proc = procedure) OR ~(proc.isFinalizer)) DO
							proc := proc.nextProcedure;
						END;
						IF proc # NIL THEN
							Error(procedure.position,Diagnostics.Invalid,"duplicate finalizer")
						ELSE
							procedure.scope(SyntaxTree.RecordScope).SetFinalizer(procedure);
						END;
					END;
					super := FindSuperProcedure(record.recordScope, procedure);
					IF (super # NIL) & SignatureCompatible(procedure.position,procedureType,super.type.resolved(SyntaxTree.ProcedureType)) THEN
						IF (super.isConstructor) & ~(procedure.isConstructor) THEN
							Error(procedure.position,Diagnostics.Invalid,"incompatible signature: non-constructor extends constructor");
						END;
						IF (super.isFinalizer) & ~(procedure.isFinalizer) THEN
							Error(procedure.position,Diagnostics.Invalid,"incompatible signature: non-finalizer extends finalizer");
						END;
						IF super.isFinal THEN
							Error(procedure.position,Diagnostics.Invalid,"forbidden method extending final method");
						END;
						procedure.SetSuper(super);
						super.SetOverwritten(TRUE);
						procedure.SetAccess(procedure.access+super.access);
						procedure.MarkUsed;
					END;
					IF  ~system.GenerateParameterOffsets(procedure,FALSE) (* assume that this is no nested procedure, is fixed later otherwise *)
					THEN
						Error(procedure.position,Diagnostics.Invalid,"problems during parameter offset computation");
					END;
				ELSIF procedure.scope IS SyntaxTree.CellScope THEN (* allowed to be constructor *)
					IF cellsAreObjects THEN 
						procedureType.SetDelegate(TRUE);
					END;
					IF procedure.isConstructor THEN
						procedure.scope(SyntaxTree.CellScope).SetConstructor(procedure);
					END;
				ELSIF procedure.isConstructor THEN
					Error(procedure.position,Diagnostics.Invalid,"procedure illegaly marked as initializer - not in object scope");
				END;
				Declarations(procedure.procedureScope);
				(* body resolution part done as late fix of the procedure type *)
				procedure.SetState(SyntaxTree.Resolved);
				currentIsRealtime := recentIsRealtime;
				currentIsBodyProcedure := recentIsBodyProcedure;
			END;
		END VisitProcedure;

		(**
			a builtin procedure is a global item that may not be modified locally
			instead the resolving of builtin procedure calls are done in the NewBuiltinCallDesignator
		**)
		PROCEDURE VisitBuiltin(builtinProcedure: SyntaxTree.Builtin);
		VAR type: SyntaxTree.Type;
		BEGIN
			type := ResolveType(builtinProcedure.type);
		END VisitBuiltin;

		(* nopov *)
		(** check and resolve operator
			- operators are first checked as procedures
			- then additional operator-specific checks are done
			- note that only module-scope operators are checked here
				(operators in a record scope are only allowed in the context of
				array-structured object types and checked in 'ResolveArrayStructure')
			- also note that inter-operator conformity is not checked here
		**)
		PROCEDURE VisitOperator(operator: SyntaxTree.Operator);
		VAR
			procedureType: SyntaxTree.ProcedureType;
			leftType, rightType: SyntaxTree.Type;
			identifierNumber, position: LONGINT;
			hasReturnType, mustBeUnary, mustBeBinary, mustReturnBoolean, mustReturnInteger, mustHaveEquitypedOperands: BOOLEAN;
			modifiers: SyntaxTree.Modifier;

			(** whether a type is locally defined in the current module scope
			for arrays, the base type must be locally defined **)
			PROCEDURE IsLocallyDefined(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				IF type = NIL THEN
					RETURN FALSE
				ELSIF (type.typeDeclaration # NIL) & (type.typeDeclaration.scope.ownerModule = currentScope.ownerModule) THEN
					RETURN TRUE
				ELSIF (type.resolved IS SyntaxTree.ArrayType) THEN
					RETURN IsLocallyDefined(type.resolved(SyntaxTree.ArrayType).arrayBase)
				ELSIF (type.resolved IS SyntaxTree.MathArrayType) THEN
					RETURN IsLocallyDefined(type.resolved(SyntaxTree.MathArrayType).arrayBase)
				ELSE
					RETURN FALSE
				END
			END IsLocallyDefined;
		BEGIN
			ASSERT(operator.type IS SyntaxTree.ProcedureType);
			procedureType := operator.type(SyntaxTree.ProcedureType);

			modifiers := procedureType.modifiers;
			IF HasFlag(modifiers, Global.NameDynamic, position) THEN operator.SetDynamic(TRUE) END;
			CheckModifiers(modifiers, TRUE);

			VisitProcedure(operator);

			IF operator.scope IS SyntaxTree.RecordScope THEN
			ELSIF operator.scope IS SyntaxTree.ModuleScope THEN
				identifierNumber := Global.GetSymbol(operator.scope.ownerModule.case, operator.name);

				IF identifierNumber = -1 THEN
					Error(operator.position, Diagnostics.Invalid, "operator with unknown identifier")
				ELSIF ~system.operatorDefined[identifierNumber] THEN
					Error(operator.position, Diagnostics.Invalid, "identifier may not be used for operator")
				ELSE
					IF procedureType.numberParameters < 1 THEN
						Error(operator.position, Diagnostics.Invalid, "operator without operand");
					ELSIF procedureType.numberParameters > 2 THEN
						Error(operator.position, Diagnostics.Invalid, "operator with more than two operands");
					ELSE
						(* determine operand types *)
						leftType := procedureType.firstParameter.type;
						IF procedureType.numberParameters > 1 THEN
							rightType := procedureType.firstParameter.nextParameter.type
						ELSE
							rightType := NIL
						END;

						(* check whether at least one of the operand types is declared in the current module (this check is skipped for the module FoxArrayBase) *)
						IF currentScope.ownerModule.name # Global.ArrayBaseName THEN
							IF ~(IsLocallyDefined(leftType) OR IsLocallyDefined(rightType)) THEN
								Error(operator.position, Diagnostics.Invalid, "none of the operands is declared in the same module")
							END
						END;

						(* TODO: refine the checks, think about how restrictive the checks should be
						requiring operators such as "&", "OR", "~" to return Booleans, makes overloading for them almost pointless.
						They might be used for intersection, union, complement of custom object types *)

						(* defaults *)
						hasReturnType := TRUE;
						mustBeUnary := FALSE;
						mustBeBinary := FALSE;
						mustReturnBoolean := FALSE;
						mustReturnInteger := FALSE;
						mustHaveEquitypedOperands := FALSE;

						(* operator-specific exceptions *)
						CASE identifierNumber OF
						| Scanner.Equal, Scanner.Unequal, Scanner.Less, Scanner.LessEqual, Scanner.Greater, Scanner.GreaterEqual:
							mustBeBinary := TRUE; mustReturnBoolean := TRUE;
						| Scanner.DotEqual, Scanner.DotUnequal, Scanner.DotLess, Scanner.DotLessEqual, Scanner.DotGreater, Scanner.DotGreaterEqual:
							mustBeBinary := TRUE
						| Scanner.In: mustBeBinary := TRUE; mustReturnBoolean := TRUE
						| Scanner.Is: mustBeBinary := TRUE; mustReturnBoolean := TRUE
						| Scanner.Times: mustBeBinary := TRUE
						| Scanner.TimesTimes: mustBeBinary := TRUE
						| Scanner.DotTimes: mustBeBinary := TRUE
						| Scanner.PlusTimes: mustBeBinary := TRUE
						| Scanner.Slash: mustBeBinary := TRUE
						| Scanner.Backslash: mustBeBinary := TRUE
						| Scanner.DotSlash: mustBeBinary := TRUE
						| Scanner.Div, Scanner.Mod: mustBeBinary := TRUE;
						| Scanner.And, Scanner.Or: mustBeBinary := TRUE;
						| Scanner.Not: mustBeUnary := TRUE
						| Scanner.Plus, Scanner.Minus: (* unary and binary *)
						| Scanner.Becomes: mustBeBinary := TRUE; hasReturnType := FALSE;
						| Scanner.Transpose: mustBeUnary := TRUE;
						| Global.Conversion: mustBeUnary := TRUE; (* TODO: get rid of return type? *)
						| Global.DotTimesPlus: mustBeBinary := TRUE;
						| Global.AtMulDec, Global.AtMulInc: mustBeBinary := TRUE;
						| Global.DecMul, Global.IncMul: mustBeBinary := TRUE;
						| Global.Dec, Global.Inc: hasReturnType := FALSE; (* unary and binary *)
						| Global.Excl, Global.Incl:hasReturnType := FALSE; 
						| Global.Abs: mustBeUnary := TRUE;
						| Global.Ash: (* TODO: arity? *)
						| Global.Cap: (* TODO: arity? *)
						| Global.Chr: mustBeUnary := TRUE;
						| Global.Entier: (* TODO: arity? *)
						| Global.EntierH: (* TODO: arity? *)
						| Global.Len: (* unary and binary *)
						| Global.Short, Global.Long: mustBeUnary := TRUE;
						| Global.Max, Global.Min: (* unary and binary *)
						| Global.Odd: (* TODO: arity? *)
						| Global.Sum: (* TODO: arity? *)
						| Global.All: (* TODO: arity? *)
						| Global.Dim: mustBeUnary := TRUE; mustReturnInteger := TRUE;
						| Scanner.Alias:
						| Scanner.GreaterGreater, Scanner.LessLess:
							mustBeBinary := TRUE;
						| Scanner.GreaterGreaterQ, Scanner.LessLessQ:
							mustBeBinary := TRUE; mustReturnBoolean := TRUE;
						END;

						(* check parameter count *)
						IF mustBeUnary & (procedureType.numberParameters # 1) THEN
							Error(operator.position, Diagnostics.Invalid,"operator is not unary")
						ELSIF mustBeBinary & (procedureType.numberParameters # 2) THEN
							Error(operator.position, Diagnostics.Invalid,"operator is not binary")
						END;

						(* check parameter types *)
						(* TODO: is this used at all? *)
						IF mustHaveEquitypedOperands & (procedureType.numberParameters = 2) THEN
							leftType := procedureType.firstParameter.type;
							rightType := procedureType.firstParameter.nextParameter.type;
							IF ~leftType.resolved.SameType(rightType.resolved) THEN
								Error(operator.position,Diagnostics.Invalid, "the two operands are not of the same type")
							END
						END;

						(* check return type *)
						IF hasReturnType THEN
							IF procedureType.returnType = NIL THEN
								Error(operator.position, Diagnostics.Invalid, "return type required")
							ELSIF mustReturnBoolean THEN
								IF ~(procedureType.returnType.resolved IS SyntaxTree.BooleanType) THEN
									Error(operator.position, Diagnostics.Invalid,"return type is not Boolean")
								END
							ELSIF mustReturnInteger THEN
								IF ~(procedureType.returnType.resolved IS SyntaxTree.IntegerType) THEN
									Error(operator.position, Diagnostics.Invalid,"return type is not integer")
								END
							END
						ELSIF procedureType.returnType # NIL THEN
							Error(operator.position, Diagnostics.Invalid, "return type not allowed")
						END
					END
				END
			END
		END VisitOperator;



		PROCEDURE AddImport*(module: SyntaxTree.Module; x: SyntaxTree.Import): BOOLEAN;
		VAR prevScope: SyntaxTree.Scope; prevDiagnostics: Diagnostics.Diagnostics;
		BEGIN
			IF error THEN RETURN FALSE END;
			prevScope := currentScope;
			prevDiagnostics := diagnostics;
			diagnostics := NIL; (* suppress error output *)
			currentScope := module.moduleScope;
			VisitImport(x);
			IF ~error THEN
				module.moduleScope.AddImport(x);
				x.SetScope(module.moduleScope);
			END;
			currentScope := prevScope;
			diagnostics := prevDiagnostics;
			IF error THEN error := FALSE; RETURN FALSE ELSE RETURN TRUE END;
		END AddImport;


		(** check and resolve import
			- check for name = SYSTEM
			- check for forbidden self import
			- search through global import cache: already imported?
			- check if already imported indirectly
			- import if necessary -> set module and enter into import cache
			- enter re-imports into list of imported modules as non-direct import (if not in direct import list)
			- after this import this direct import and all indirect imports are stored in the current module's import list
		**)
		PROCEDURE VisitImport(x: SyntaxTree.Import);
		VAR
			module: SyntaxTree.Module;
			moduleScope: SyntaxTree.ModuleScope;
			import,reimport: SyntaxTree.Import;
			filename: FileName;
			prevScope: SyntaxTree.Scope;
		BEGIN
			IF SymbolNeedsResolution(x) THEN
				prevScope := currentScope;
				x.SetType(SyntaxTree.importType);
				moduleScope := currentScope.ownerModule.moduleScope;

				IF (x.moduleName=Global.SystemName) THEN x.SetModule(system.systemModule[Scanner.Uppercase])
				ELSIF (x.moduleName=Global.systemName) THEN x.SetModule(system.systemModule[Scanner.Lowercase])
				ELSIF (x.moduleName=currentScope.ownerModule.name) & (x.context=currentScope.ownerModule.context) THEN
					Error(x.position,Diagnostics.Invalid,"forbidden self import");
				ELSE

					(* search through global import list: already imported ? *)
					IF (x.module = NIL) & (importCache # NIL)  THEN
						import := importCache.ImportByModuleName(x.moduleName,x.context);
					ELSE import := NIL
					END;

					IF x.module # NIL THEN (* already imported indirectly *)
						module := x.module;
					ELSIF import # NIL THEN (* already in module list *)
						module := import.module;
						ASSERT(module # NIL);
						x.SetModule(module);
					ELSE (* must be imported *)
						Global.ModuleFileName(x.moduleName,x.context,filename);
						IF symbolFileFormat # NIL THEN
							module := symbolFileFormat.Import(filename,importCache); (* includes module parsing *)
							IF module = NIL THEN
								ErrorSS(x.position,"could not import",filename);
								IF VerboseErrorMessage THEN
									Printout.Info("import",x)
								END
							ELSE
								(*
								IF ~(SyntaxTree.Resolved IN module.state) THEN
									(*! should rather be done by importer *)
									checker := NewChecker(diagnostics,VerboseErrorMessage,system,symbolFileFormat,importCache);
									checker.importCache := importCache;
									checker.arrayBaseImported := arrayBaseImported;
									checker.global := global;
									checker.Module(module); (* semantic check *)
									error := error OR checker.error;
								END;
								*)
								(*
								ASSERT(SyntaxTree.Resolved IN module.state);
								*)
								x.SetModule(module);
								IF importCache # NIL THEN
									import := SyntaxTree.NewImport(InvalidPosition,x.moduleName,x.moduleName,FALSE);
									import.SetContext(x.context);
									import.SetModule(module);
									importCache.AddImport(import);
								END;
							END;
						ELSE
							ErrorSS(x.position,"no symbol file specified: cannot import",filename);
						END;
					END;
					IF module # NIL THEN (* enter reimports into list of imported modules *)
						IF SELF.module = NIL THEN (* happens in recursive imports *)
						END;
						import := module.moduleScope.firstImport;
						WHILE(import # NIL) DO
							ASSERT(import.moduleName # SyntaxTree.invalidIdentifier);
							ASSERT(currentScope # NIL);
							ASSERT(currentScope.ownerModule # NIL);
							ASSERT(import.context # SyntaxTree.invalidIdentifier);

							IF (import.moduleName=currentScope.ownerModule.name) & (import.context=currentScope.ownerModule.context) THEN
								Error(x.position,Diagnostics.Invalid,"recursive import");
							ELSE
								IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(x.context) END;
								reimport := moduleScope.ImportByModuleName(import.moduleName,import.context);
								IF reimport = NIL THEN  (* indirect import *)
									reimport := SyntaxTree.NewImport(InvalidPosition,import.moduleName,import.moduleName,FALSE);
									reimport.SetContext(import.context);
									reimport.SetModule(import.module);
									moduleScope.AddImport(reimport);
									reimport.SetScope(moduleScope);
								ELSE
									ASSERT(import.module # NIL);
									reimport.SetModule(import.module); (* direct or indirect import *)
								END;
							END;
							import := import.nextImport;
						END;
					END;
				END;
				currentScope := prevScope;
				(* ELSE nothing to be done *)
				x.SetState(SyntaxTree.Resolved);
			END;
		END VisitImport;

		(*** statements ***)

		PROCEDURE ResolveStatement(x: SyntaxTree.Statement): SyntaxTree.Statement;
		VAR prev,resolved: SyntaxTree.Statement;
		BEGIN
			prev := resolvedStatement;
			resolvedStatement := x;
			IF currentIsUnreachable THEN x.SetUnreachable(TRUE) END;
			activeCellsStatement := FALSE;
			x.Accept(SELF);
			(* removed this, implementation restriction should be resolved by backend
			IF (inCellNetBody) & (activeCellsStatement = FALSE) THEN
				Error(x.position, Diagnostics.Invalid, "non-activeCells statement in activeCells block - not yet implemented");
			END;
			*)
			resolved := resolvedStatement;
			resolvedStatement := prev;
			RETURN resolved
		END ResolveStatement;

		(** check and resolve statement sequence
			- check all statements, replace if necessary
		**)
		PROCEDURE StatementSequence(statementSequence: SyntaxTree.StatementSequence);
		VAR i: LONGINT; statement,resolved: SyntaxTree.Statement;
		BEGIN
			IF statementSequence # NIL THEN (* else empty *)
				FOR i := 0 TO statementSequence.Length()-1 DO
					statement := statementSequence.GetStatement(i);
					resolved := ResolveStatement(statement);
					IF (resolved # statement) THEN
						statementSequence.SetStatement(i,resolved);
					END;
				END;
			END;
		END StatementSequence;



		(** check and resolve procedure call statement procedureCall() or procedureCall;
			- check if call is a procedure call designator, if not (procedure type symbol) try to make one out of it
			- check if procedure is callable
			- check return type = NIL (otherwise must be assignment statement)
		**)
		PROCEDURE VisitProcedureCallStatement(procedureCall: SyntaxTree.ProcedureCallStatement);
		VAR call: SyntaxTree.Designator;
		BEGIN
			IF Trace THEN D.Str("VisitProcedureCallStatement"); D.Ln; END;
			call := procedureCall.call;
			IF (call # NIL) &  ~(call IS SyntaxTree.ParameterDesignator) & ~(call IS SyntaxTree.ProcedureCallDesignator) & ~(call IS SyntaxTree.BuiltinCallDesignator)  THEN
				call := SyntaxTree.NewParameterDesignator(call.position,call,SyntaxTree.NewExpressionList());
			END;

			call := ResolveDesignator(call);


			IF call = SyntaxTree.invalidDesignator THEN
				(* error already handled *)
			ELSIF call IS SyntaxTree.StatementDesignator THEN
				(* inline call in a statement *)
			ELSIF ~IsCallable(call) THEN
				Error(procedureCall.position,Diagnostics.Invalid,"called object is not a procedure");
			ELSIF (call.type # NIL) &  (call.left # NIL) &  (call.left.type.resolved(SyntaxTree.ProcedureType).callingConvention # SyntaxTree.WinAPICallingConvention) THEN
				Error(procedureCall.position,Diagnostics.Invalid,"calling procedure with non-void return type");
				IF VerboseErrorMessage THEN Printout.Info("call ",call) END;
			END;
			procedureCall.SetCall(call);

			(*
			IF call = SyntaxTree.invalidDesignator THEN
			ELSIF (call.left IS SyntaxTree.SymbolDesignator) & (call.left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Procedure) THEN
				procedure := call.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
				IF IsOberonInline(procedure) THEN
					Warning(procedure.position,"call to inline proc");
					block := SyntaxTree.NewStatementBlock(call.position, NIL (*! todo *));
					block.SetStatementSequence(SyntaxTree.CloneStatementSequence(procedure.procedureScope.body.statements));
					ReplaceParameters(block, procedure.type(SyntaxTree.ProcedureType).firstParameter, call(SyntaxTree.ProcedureCallDesignator).parameters);
					resolvedStatement := block;
					RETURN;
				END;
			END;
			*)
		END VisitProcedureCallStatement;

		(** check and resolve assignment LHS := RHS
			- resolve LHS and RHS
			- check if assignment operator is found. if yes, return operator call instead of assignment instruction
			- check if assignment is compatible
			- check if LHS is variable (i.e. assignable)
			- convert RHS if necessary
			- for the following two cases, return index write operator call on ASOT instead of assignment instruction:
				- assignment between different ASOTs
					asot := asot2; -> asot^."[]"( *, *, ..., *, asot2);
				- assignment to ASOT elements:
					asot[indexList] := rhs; -> asot^."[]"(indexList, rhs);
		**)
		PROCEDURE VisitAssignment(assignment: SyntaxTree.Assignment);
		VAR
			left: SyntaxTree.Designator;
			right, expression: SyntaxTree.Expression;
			designator: SyntaxTree.Designator;
			procedureCallDesignator: SyntaxTree.ProcedureCallDesignator;
			mathArrayType: SyntaxTree.MathArrayType;

		BEGIN
			right := ResolveExpression(assignment.right);
			assignment.left.SetRelatedRhs(right); (* store a reference to the RHS in the assignement's LHS*)
			left := ResolveDesignator(assignment.left);

			IF (left = SyntaxTree.invalidDesignator) OR (right = SyntaxTree.invalidExpression) THEN
				(* error already handled *)
			ELSIF (left IS SyntaxTree.ProcedureCallDesignator) & (left.type = NIL) & (left.relatedAsot # NIL) THEN
				(* LHS is index write operator call on ASOT *)
				procedureCallDesignator :=  left(SyntaxTree.ProcedureCallDesignator);
				(* necessary ?
				procedureType := procedureCallDesignator.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure).type(SyntaxTree.ProcedureType);
				type := procedureType.firstParameter.type;
				expression := procedureCallDesignator.parameters.GetExpression(0);
				procedureCallDesignator.parameters.SetExpression(0,NewConversion(0,expression,type,NIL));
				*)
				resolvedStatement := SyntaxTree.NewProcedureCallStatement(assignment.position, procedureCallDesignator, assignment.outer);
			ELSIF CheckVariable(left) THEN
				expression := NewOperatorCall(assignment.position, Scanner.Becomes, left, right, NIL);
				IF (expression # NIL) & (expression IS SyntaxTree.ProcedureCallDesignator) THEN
					procedureCallDesignator := expression(SyntaxTree.ProcedureCallDesignator);
					(* conversion done by procedure call
					(* try to convert to left argument *)
					IF (left.type.resolved IS SyntaxTree.MathArrayType) & (right.type.resolved IS SyntaxTree.MathArrayType) & AssignmentCompatible(left, right) THEN
						right := NewConversion(right.position, right, left.type.resolved, NIL);
						procedureCallDesignator.parameters.SetExpression(1, right);
					END;
					*)
					resolvedStatement := SyntaxTree.NewProcedureCallStatement(assignment.position, procedureCallDesignator, assignment.outer);
				ELSIF (expression # NIL) & (expression IS SyntaxTree.StatementDesignator) THEN
					resolvedStatement := expression(SyntaxTree.StatementDesignator).statement;
				ELSIF AssignmentCompatible(left, right) THEN
					IF IsArrayStructuredObjectType(left.type) & (left.type.resolved # right.type.resolved) THEN
						mathArrayType := MathArrayStructureOfType(left.type);
						right := NewConversion(right.position, right, mathArrayType, NIL);
						designator := NewIndexOperatorCall(InvalidPosition, left, ListOfOpenRanges(mathArrayType.Dimensionality()), right);
						resolvedStatement := SyntaxTree.NewProcedureCallStatement(assignment.position, designator, assignment.outer)
					ELSE
						right := NewConversion(right.position, right, left.type.resolved, NIL);
						assignment.SetLeft(left);
						assignment.SetRight(right);
						resolvedStatement := assignment
					END
				END
			END
		END VisitAssignment;


		(** check and resolve assignment LHS := RHS
			- resolve LHS and RHS
			- check if assignment operator is found. if yes, return operator call instead of assignment instruction
			- check if assignment is compatible
			- check if LHS is variable (i.e. assignable)
			- convert RHS if necessary
			- for the following two cases, return index write operator call on ASOT instead of assignment instruction:
				- assignment between different ASOTs
					asot := asot2; -> asot^."[]"( *, *, ..., *, asot2);
				- assignment to ASOT elements:
					asot[indexList] := rhs; -> asot^."[]"(indexList, rhs);
		**)
		PROCEDURE VisitCommunicationStatement(communication: SyntaxTree.CommunicationStatement);
		VAR
			left: SyntaxTree.Designator;
			right: SyntaxTree.Expression;
			inPort, outPort: SyntaxTree.PortType;
		BEGIN
			right := ResolveExpression(communication.right);
			left := ResolveDesignator(communication.left);
			communication.SetLeft(left);
			communication.SetRight(right);
			IF ~cellsAreObjects THEN ImportModule(Global.NameChannelModule,communication.position) END;

			IF (left = SyntaxTree.invalidDesignator) OR (right = SyntaxTree.invalidExpression) THEN
				(* error already handled *)
			ELSIF communication.op = Scanner.LessLess THEN (* left is dest *)
				IF (left.type.resolved IS SyntaxTree.PortType) & CheckPortType(left, outPort) THEN (* send *)
					IF outPort.direction # SyntaxTree.OutPort THEN
						Error(left.position,Diagnostics.Invalid,"not an out-port")
					ELSIF outPort.sizeInBits # system.SizeOf(right.type) THEN
						Error(left.position,Diagnostics.Invalid,"incompatible to port type");
					ELSE
						right := NewConversion(communication.position,right,left.type.resolved,NIL);
						communication.SetRight(right)
					END;
				ELSIF (right.type.resolved IS SyntaxTree.PortType) & CheckPortType(right, inPort) THEN (* receive *)
					IF CheckVariable(left) THEN
						IF inPort.direction # SyntaxTree.InPort THEN
							Error(left.position,Diagnostics.Invalid,"not an in-port")
						ELSIF inPort.sizeInBits # system.SizeOf(right.type) THEN
							Error(right.position,Diagnostics.Invalid,"incompatible to port type");
						END;
					END;
				ELSE
					Error(communication.position, -1, "unsupported stream operation");
				END;
			ELSIF (communication.op = Scanner.Questionmark)  & CheckPortType(left,outPort)  THEN
				IF outPort.direction # SyntaxTree.OutPort THEN
					Error(left.position,Diagnostics.Invalid,"not an out-port")
				ELSIF outPort.sizeInBits # system.SizeOf(right.type) THEN
					Error(left.position,Diagnostics.Invalid,"incompatible to port type");
				ELSE
					right := NewConversion(communication.position,right,left.type.resolved,NIL);
					communication.SetRight(right)
				END;
			ELSIF (communication.op = Scanner.ExclamationMark) & CheckPortType(left,inPort) THEN
				IF CheckVariable(right) THEN
					IF inPort.direction # SyntaxTree.InPort THEN
						Error(left.position,Diagnostics.Invalid,"not an in-port")
					ELSIF inPort.sizeInBits # system.SizeOf(right.type) THEN
						Error(right.position,Diagnostics.Invalid,"incompatible to port type");
					END;
				END;
			ELSE
				Error(communication.position, -1, "unsupported operation");
			END
		END VisitCommunicationStatement;

		(** check and resolve if/eslif part
			- check condition
			- check statement sequence
		**)
		PROCEDURE IfPart(ifPart: SyntaxTree.IfPart; VAR true: BOOLEAN);
		VAR prevUnreachable, b: BOOLEAN;
		BEGIN
			prevUnreachable := currentIsUnreachable;
			ifPart.SetCondition(ResolveCondition(ifPart.condition));
			IF IsBooleanValue(ifPart.condition,b) THEN
				IF b=FALSE THEN
					currentIsUnreachable := TRUE
				ELSIF b=TRUE THEN
					true := TRUE
				END;
			END;
			StatementSequence(ifPart.statements);
			currentIsUnreachable := prevUnreachable;
		END IfPart;

		(** check and resolve if statement
			- check if parts and else part statement sequence
		**)
		PROCEDURE VisitIfStatement(ifStatement: SyntaxTree.IfStatement);
		VAR elsif: SyntaxTree.IfPart; i: LONGINT; ifPartTrue, prevUnreachable: BOOLEAN;
		BEGIN
			prevUnreachable := currentIsUnreachable;
			ifPartTrue := FALSE;
			IfPart(ifStatement.ifPart,ifPartTrue);
			FOR i := 0 TO ifStatement.ElsifParts()-1 DO
				elsif := ifStatement.GetElsifPart(i);
				IfPart(elsif,ifPartTrue);
			END;
			IF ifStatement.elsePart # NIL THEN
				IF ifPartTrue THEN
					currentIsUnreachable := TRUE
				END;
				StatementSequence(ifStatement.elsePart)
			END;
			currentIsUnreachable := prevUnreachable;
		END VisitIfStatement;

		PROCEDURE WithPart(withPart: SyntaxTree.WithPart; VAR symbol: SyntaxTree.Symbol);
		VAR variable: SyntaxTree.Designator;
			type,variableType: SyntaxTree.Type;
			withEntry: WithEntry;
		BEGIN
			variable := ResolveDesignator(withPart.variable);
			variableType := variable.type.resolved;
			withPart.SetVariable(variable);
			type := ResolveType(withPart.type);
			withPart.SetType(type);

			WHILE variable IS SyntaxTree.TypeGuardDesignator DO
				variable := variable(SyntaxTree.TypeGuardDesignator).left(SyntaxTree.Designator);
			END;

			IF (type.resolved = SyntaxTree.invalidType) OR (variableType = SyntaxTree.invalidType) THEN (* error already reported *)
			ELSIF ~(type.resolved = variableType) & ~IsExtensibleDesignator(variable) THEN
				Error(variable.position,Diagnostics.Invalid,"is not extensible designator");
			ELSIF ~(variable IS SyntaxTree.SymbolDesignator) (* OR (variable(SyntaxTree.SymbolDesignator).left # NIL) needed ?? *)  THEN
				Error(variable.position,Diagnostics.Invalid,"is no local variable ");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable)
				END;
			ELSIF ~IsTypeExtension(variableType, type.resolved) THEN
				Error(variable.position,Diagnostics.Invalid,"withguarded symbol is no type extension of ");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable);
					Printout.Info("type",type);
				END;
			ELSIF ~(variable(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable)
					& ~(variable(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				Error(variable.position,Diagnostics.Invalid,"withguarded symbol is no variable ");
				IF VerboseErrorMessage THEN
					Printout.Info("variable",variable);
					Printout.Info("type",type);
				END;
			ELSIF (symbol # NIL) & (symbol # variable(SyntaxTree.SymbolDesignator).symbol) THEN
				Error(variable.position,Diagnostics.Invalid,"invalid change of withguarded symbol");
			ELSE
				symbol := variable(SyntaxTree.SymbolDesignator).symbol;
				NEW(withEntry);
				withEntry.previous := withEntries;
				withEntry.symbol := variable(SyntaxTree.SymbolDesignator).symbol;
				withEntry.type := type;
				withEntries := withEntry;
				StatementSequence(withPart.statements);
				withEntries := withEntries.previous;
			END;

		END WithPart;


		(** check and resolve with statement WITH variable: type DO ... END;
			- check type and variable
			- check that variable type is type extension of type
			- check that variable is a variable
			- enter new with scope and enter guardedVariable with same name and reference to variable
			- create if statement:
				WITH variable: type DO ... END; 	--> IF ~(variable IS type) THEN HALT(withTrap) ELSE ... END;
		**)
		PROCEDURE VisitWithStatement(withStatement: SyntaxTree.WithStatement);
		VAR i: LONGINT; prevScope: SyntaxTree.Scope; symbol: SyntaxTree.Symbol;
		BEGIN
			prevScope := currentScope; symbol := NIL;
			FOR i := 0 TO withStatement.WithParts()-1 DO
				WithPart(withStatement.GetWithPart(i),symbol);
			END;
			IF withStatement.elsePart # NIL THEN
				StatementSequence(withStatement.elsePart)
			END;
			currentScope := prevScope;
		END VisitWithStatement;

		(** check and resolve case part <<a, b, c..d: StatementSequence>>
			- check expression to be constant or case range expression <<first .. last>> with constants 'first' and 'last' and compatible to type
			- check 'first' < 'last' and no overlaps between different case labels
			- check statement sequence
		**)
		PROCEDURE CasePart(casePart: SyntaxTree.CasePart; type: SyntaxTree.Type; VAR allcases: SyntaxTree.CaseConstant; VAR min,max: LONGINT);
		VAR
			i: LONGINT;
			position: LONGINT;
			expression, left, right: SyntaxTree.Expression;
			expressionType: SyntaxTree.Type;
			l, r: LONGINT;
			cl, cr: CHAR;
			thiscases: SyntaxTree.CaseConstant;
		BEGIN
			thiscases := NIL;
			FOR i := 0 TO casePart.elements.Length() - 1 DO
				expression := casePart.elements.GetExpression(i);
				position := expression.position;

				(* set context of range *)
				IF expression IS SyntaxTree.RangeExpression THEN
					expression(SyntaxTree.RangeExpression).SetContext(SyntaxTree.CaseGuard)
				END;

				expression := ResolveExpression(expression);

				IF expression = SyntaxTree.invalidExpression THEN
					(* error already reported *)
					expressionType := SyntaxTree.invalidType;

				ELSIF (expression IS SyntaxTree.RangeExpression) THEN
					(* read out 'first' and 'last' *)
					left := expression(SyntaxTree.RangeExpression).first;
					right := expression(SyntaxTree.RangeExpression).last;
					(* guaranteed by VisitRangeExpression: *)
					ASSERT((left # NIL) & (right # NIL));
					ASSERT(left.type.resolved = right.type.resolved);
					left := CompatibleConversion(left.position, left, type);
					right := CompatibleConversion(right.position, right, type);
					expression(SyntaxTree.RangeExpression).SetFirst(left);
					expression(SyntaxTree.RangeExpression).SetLast(right);
					expressionType := RegularType(position,left.type);
				ELSE
					expression := ConstantExpression(expression);
					expression := CompatibleConversion(expression.position, expression, type);
					(*
					IF IsStringType(expression.type) (*& IsCharacterValue(expression,cl) *) THEN
						left := Global.NewCharacterValue(system,expression.position,cl);
						expression := casePart.elements.GetExpression(i);
						expression.SetResolved(left(SyntaxTree.CharacterValue));
						expression := left
					END;
					*)
					casePart.elements.SetExpression(i,expression);
					left := expression; right := expression;
					expressionType := RegularType(position,expression.type)
				END;

				IF (expressionType = SyntaxTree.invalidType) THEN
				ELSIF ~CompatibleTo(system,expressionType,type) THEN
					Error(position,Diagnostics.Invalid,"inadmissible case label");
					expression := SyntaxTree.invalidExpression;
				ELSE
					l := 0; r := 0;
					IF IsIntegerValue(left,l) & CheckIntegerValue(right,r) THEN
					ELSIF IsCharacterValue(left,cl) & CheckCharacterValue(right,cr) THEN
						l := ORD(cl); r := ORD(cr);
					ELSIF IsEnumerationValue(left,l) & CheckEnumerationValue(right,r) THEN
					ELSE
						expression := SyntaxTree.invalidExpression
					END;

					IF expression # SyntaxTree.invalidExpression THEN
						IF l>r THEN
							Error(position,Diagnostics.Invalid,"empty case label")
						ELSIF ~EnterCase(thiscases,l,r) OR ~EnterCase(allcases,l,r) THEN
							Error(position,Diagnostics.Invalid,"duplicate case label");
						ELSE
							IF l < min THEN min := l END;
							IF r > max THEN max := r END;
						END;
					END;
				END;
				casePart.elements.SetExpression(i,expression);
			END;
			(*! Coalesce(caseConstants); sort and find succeeeding numbers !!! *)
			casePart.SetConstants(thiscases);
			StatementSequence(casePart.statements);
		END CasePart;


		(** check and resolve case statement CASE variable OF ... END;
			- check variable
			- check case parts
		**)
		PROCEDURE VisitCaseStatement(caseStatement: SyntaxTree.CaseStatement);
		VAR expression: SyntaxTree.Expression; i: LONGINT; type: SyntaxTree.Type; caseList: SyntaxTree.CaseConstant;
			ch: CHAR; l: LONGINT; min,max: LONGINT; msg: ARRAY 64 OF CHAR;
		BEGIN
			expression := ResolveExpression(caseStatement.variable);
			type := RegularType(expression.position,expression.type);
			IF type = SyntaxTree.invalidType THEN
				expression := SyntaxTree.invalidExpression;
			ELSIF IsIntegerType(type) THEN
			ELSIF IsStringType(expression.type) (* & IsCharacterValue(expression,ch) *) THEN
				expression := NewConversion(expression.position, expression, system.characterType,NIL);
				(*
				expression := Global.NewCharacterValue(system,expression.position,ch);
				*)
				type := expression.type;
			ELSIF IsCharacterType(type) THEN
			ELSIF IsEnumerationType(type) THEN
			ELSE
				Error(caseStatement.variable.position,Diagnostics.Invalid,"variable must be integer or character type");
				expression := SyntaxTree.invalidExpression;
			END;
			caseStatement.SetVariable(expression);
			caseList := NIL;
			min := MAX(LONGINT); max := MIN(LONGINT);
			FOR i := 0 TO caseStatement.CaseParts()-1 DO
				CasePart(caseStatement.GetCasePart(i),type,caseList,min,max);
			END;
			IF (max - min > 1024) & (100* caseStatement.CaseParts() DIV (max-min) < 10) (* less than ten percent used in a huge case table *) THEN
				msg := "huge sparse case table ";
				Strings.AppendInt(msg, max-min);
				Strings.Append(msg,"/");
				Strings.AppendInt(msg, caseStatement.CaseParts());
				Warning(caseStatement.position,msg);
			END;

			caseStatement.SetMinMax(min,max);
			StatementSequence(caseStatement.elsePart);
			IF expression.resolved # NIL THEN
				IF IsCharacterValue(expression,ch) THEN
					l := ORD(ch)
				ELSIF IsIntegerValue(expression,l) THEN
				END;
				IF EnterCase(caseList,l,l) & (caseStatement.elsePart = NIL) THEN Error(caseStatement.position,Diagnostics.Invalid,"no matching case label") END;
			END;

		END VisitCaseStatement;

		(** check and resolve while statement
			- check condition
			- check statement sequence
		**)
		PROCEDURE VisitWhileStatement(whileStatement: SyntaxTree.WhileStatement);
		VAR prevIsUnreachable,b: BOOLEAN;
		BEGIN
			prevIsUnreachable := currentIsUnreachable;
			whileStatement.SetCondition(ResolveCondition(whileStatement.condition));
			IF IsBooleanValue(whileStatement.condition,b) THEN
				IF b=FALSE THEN
					currentIsUnreachable := TRUE
				END;
			END;
			StatementSequence(whileStatement.statements);
			currentIsUnreachable := prevIsUnreachable
		END VisitWhileStatement;

		(** check and resolve repeat statement
			- check condition
			- check statement sequence
		**)
		PROCEDURE VisitRepeatStatement(repeatStatement: SyntaxTree.RepeatStatement);
		BEGIN
			repeatStatement.SetCondition(ResolveCondition(repeatStatement.condition));
			StatementSequence(repeatStatement.statements);
		 END VisitRepeatStatement;


		PROCEDURE GetGuard(symbol: SyntaxTree.Symbol; VAR type: SyntaxTree.Type): BOOLEAN;
		VAR withEntry: WithEntry;
		BEGIN
			withEntry := withEntries;
			WHILE (withEntry # NIL) & (withEntry.symbol # symbol) DO
				withEntry := withEntry.previous
			END;
			IF withEntry = NIL THEN RETURN FALSE
			ELSE
				type := withEntry.type;
				RETURN TRUE
			END;
		END GetGuard;

		(** check and resolve for statement FOR variable := from TO to BY by DO StatementSequence END;
			- check that variable is an integer variable
			- check that from is integer typed with compatible type
			- check that to has compatible type
			- check that by is constant integer with compatible type
		**)
		PROCEDURE VisitForStatement(forStatement: SyntaxTree.ForStatement);
		VAR expression: SyntaxTree.Expression; designator: SyntaxTree.Designator; type: SyntaxTree.Type;
		BEGIN
			designator := ResolveDesignator(forStatement.variable);
			type := SyntaxTree.invalidType;
			IF designator.type = SyntaxTree.invalidType THEN (* error already handled *)
				designator := SyntaxTree.invalidDesignator;
			ELSIF ~IsIntegerType(designator.type.resolved) THEN
				Error(designator.position,Diagnostics.Invalid,"control variable of non-integer type");
				designator := SyntaxTree.invalidDesignator;
			ELSIF CheckVariable(designator) THEN
				type := designator.type;
			END;
			forStatement.SetVariable(designator);

			expression := ResolveExpression(forStatement.from);
			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,Diagnostics.Invalid,"start value of incompatible type");
				expression := SyntaxTree.invalidExpression;
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetFrom(expression);

			expression := ResolveExpression(forStatement.to);
			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,Diagnostics.Invalid,"end value of incompatible type");
				expression := SyntaxTree.invalidExpression;
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetTo(expression);

			IF forStatement.by # NIL THEN
				expression := ConstantInteger(forStatement.by);
			ELSE
				expression := Global.NewIntegerValue(system,InvalidPosition,1);
			END;


			IF expression = SyntaxTree.invalidExpression THEN
			ELSIF  ~CompatibleTo(system,expression.type.resolved,designator.type.resolved) THEN
				Error(expression.position,Diagnostics.Invalid,"step value of incompatible type");
			ELSIF (expression.resolved(SyntaxTree.IntegerValue).hvalue = 0) THEN
				Error(expression.position,Diagnostics.Invalid,"invalid step value");
			ELSIF type # SyntaxTree.invalidType THEN
				expression := NewConversion(expression.position,expression,type,NIL)
			END;
			forStatement.SetBy(expression);

			StatementSequence(forStatement.statements);
		END VisitForStatement;

		(** check and resolve loop statement LOOP StatementSequence END
			- check statement sequence
		**)
		PROCEDURE VisitLoopStatement(loopStatement: SyntaxTree.LoopStatement);
		BEGIN
			StatementSequence(loopStatement.statements)
		END VisitLoopStatement;

		PROCEDURE VisitExitableBlock(exitableBlock: SyntaxTree.ExitableBlock);
		BEGIN
			StatementSequence(exitableBlock.statements);
		END VisitExitableBlock;


		(** check and resolve exit statement EXIT
			- check that exit is within LOOP statement block
		**)
		PROCEDURE VisitExitStatement(exitStatement: SyntaxTree.ExitStatement);
		VAR outer: SyntaxTree.Statement;
		BEGIN
			outer := exitStatement.outer;
			WHILE(outer # NIL) & ~(outer IS SyntaxTree.ExitableBlock) DO
				outer := outer.outer;
			END;
			IF outer = NIL THEN
				Error(exitStatement.position,Diagnostics.Invalid,"exit statement not within loop statement");
			END;
		 END VisitExitStatement;

		(** check and resolve return statement RETURN [expression]
			- check expression (if any)
			- check if in procedure scope
				- if in procedure scope then check expression compatibility
				- if not in procecdure scope then check on return without expression
		**)
		PROCEDURE VisitReturnStatement(returnStatement: SyntaxTree.ReturnStatement);
		VAR expression: SyntaxTree.Expression; position: LONGINT; procedure: SyntaxTree.Procedure;
			returnType: SyntaxTree.Type; outer: SyntaxTree.Statement; scope: SyntaxTree.Scope;
		BEGIN
			position := returnStatement.position;
			expression := returnStatement.returnValue;
			IF expression # NIL THEN
				expression := ResolveExpression(expression);
				returnStatement.SetReturnValue(expression);
			END;
			outer := returnStatement.outer;
			WHILE(outer # NIL) & ~(outer IS SyntaxTree.Body) DO
				outer := outer.outer
			END;
			IF (outer # NIL) THEN
				scope := outer(SyntaxTree.Body).inScope;
				IF ~(scope IS SyntaxTree.ProcedureScope) THEN
					IF (expression # NIL) THEN
						Error(position,Diagnostics.Invalid,"return statement with parameter not in procedure scope");
					END;
				ELSE
					procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
					IF procedure.type(SyntaxTree.ProcedureType).noReturn THEN
						Error(position,Diagnostics.Invalid,"return statement in procedure that does not return");
					END;
					returnType := procedure.type(SyntaxTree.ProcedureType).returnType;
					IF returnType # NIL THEN
						returnType := returnType.resolved;
						IF expression = NIL THEN
							Error(position,Diagnostics.Invalid,"empty return type in procedure providing a return type")
						ELSIF expression.type = NIL THEN
							Error(position, Diagnostics.Invalid,"returned type incompatible: expression has no type");
						ELSIF ~CompatibleTo(system,expression.type.resolved,returnType) THEN
							Error(position,Diagnostics.Invalid,"return type not compatible");
							IF VerboseErrorMessage THEN
								Printout.Info("returnType",returnType);
								Printout.Info("expression",expression);
							END;
						ELSE
							expression := NewConversion(expression.position,expression,returnType,NIL);
							returnStatement.SetReturnValue(expression);
						END;
					ELSIF expression # NIL THEN
						Error(position,Diagnostics.Invalid,"non-empty return type in procedure providing no return type");
					END;
				END;
			END;
		 END VisitReturnStatement;

		(** check and resolve await statement AWAIT(condition: Expression)
			- check await condition
		**)
		PROCEDURE VisitAwaitStatement(awaitStatement: SyntaxTree.AwaitStatement);
		VAR condition: SyntaxTree.Expression;
		BEGIN
			condition := ResolveCondition(awaitStatement.condition);
			IF currentIsRealtime THEN
				Error(awaitStatement.position,Diagnostics.Invalid,"forbidden await statement in realtime block");
			END;
			IF (condition.resolved # NIL) & (condition.resolved IS SyntaxTree.BooleanValue) THEN
				Error(awaitStatement.position,Diagnostics.Invalid,"senseless await statement with constant condition");
			END;
			awaitStatement.SetCondition(condition);
		END VisitAwaitStatement;

		PROCEDURE CheckSystemImport(position: LONGINT);
		VAR import: SyntaxTree.Import;
		BEGIN
			import := currentScope.ownerModule.moduleScope.firstImport;
			WHILE(import # NIL) DO
				IF (import.module.name = Global.SystemName) OR (import.module.name = Global.systemName)  THEN
					RETURN;
				END;
				import := import.nextImport;
			END;
			Error(position, Diagnostics.Invalid, "forbidden code without system import");
		END CheckSystemImport;

		(** check and resolve code statement: do nothing, must be done by assembler
		**)
		PROCEDURE VisitCode(code: SyntaxTree.Code);
		VAR i: LONGINT; statement: SyntaxTree.Statement;
		BEGIN
			CheckSystemImport(code.position);
			FOR i := 0 TO code.inRules.Length()-1 DO
				statement := code.inRules.GetStatement(i);
				IF statement IS SyntaxTree.Assignment THEN
					WITH statement: SyntaxTree.Assignment DO
						statement.SetRight(ResolveExpression(statement.right));
					END;
				ELSE
					Error(statement.position, Diagnostics.Invalid, "can only be assignment")
				END;
			END;
			FOR i := 0 TO code.outRules.Length()-1 DO
				statement := code.outRules.GetStatement(i);
				IF statement IS SyntaxTree.Assignment THEN
					WITH statement: SyntaxTree.Assignment DO
						statement.SetLeft(ResolveDesignator(statement.left));
					END;
				ELSIF statement IS SyntaxTree.ReturnStatement THEN
				ELSIF statement IS SyntaxTree.StatementBlock THEN
				ELSE
					Printout.Info("out statement ", statement);
					Error(statement.position, Diagnostics.Invalid, "(out) can only be assignment")
				END;
			END;
		END VisitCode;


		(** check and set flags of a statement block
			- check for multiply occurence of a flag
			- check and set priority only in bodies
			- check for valid names
		**)
		PROCEDURE BlockFlags(block: SyntaxTree.StatementBlock);
		VAR blockModifier: SyntaxTree.Modifier; expression: SyntaxTree.Expression; name: SyntaxTree.Identifier; flags: SET; position: LONGINT;
			flag: LONGINT; recordBody: SyntaxTree.Body;

			PROCEDURE SetProtectedRecord;
			VAR scope: SyntaxTree.Scope;
			BEGIN
				scope := currentScope;
				WHILE (scope # NIL) & ~(scope IS SyntaxTree.RecordScope) DO
					scope := scope.outerScope
				END;
				IF scope # NIL THEN
					scope(SyntaxTree.RecordScope).ownerRecord.SetProtected(TRUE);
				END;
			END SetProtectedRecord;


		BEGIN
			flags := {};
			IF (block IS SyntaxTree.Body) & (currentIsBodyProcedure) & ((currentScope.outerScope = NIL) OR ~(currentScope.outerScope IS SyntaxTree.ModuleScope)) THEN
				recordBody := block(SyntaxTree.Body)
			ELSE
				recordBody := NIL
			END;

			blockModifier := block.blockModifiers;
			WHILE(blockModifier # NIL) DO
				name := blockModifier.identifier;
				expression := blockModifier.expression;
				position := blockModifier.position;
				flag := -1;
				IF name=Global.NamePriority THEN
					IF expression = NIL THEN
						Error(position,Diagnostics.Invalid,"missing priority expression");
					ELSIF recordBody = NIL THEN
						Error(position,Diagnostics.Invalid,"priority not on record body");
					ELSIF recordBody.priority # NIL THEN
						Error(position,Diagnostics.Invalid,"duplicate priority expression");
					ELSE
						recordBody.SetPriority(expression);
					END;
				ELSIF expression # NIL THEN
					Error(expression.position,Diagnostics.Invalid,"expression not in connection with priority")
				ELSIF name=Global.NameExclusive THEN
					IF block.isExclusive THEN
						Error(position,Diagnostics.Invalid,"duplicate exclusive flag")
					END;
					block.SetExclusive(TRUE); SetProtectedRecord;
				ELSIF name=Global.NameActive THEN
					IF recordBody = NIL THEN
						Error(position,Diagnostics.Invalid,"active not in record body");
					ELSIF recordBody.isActive THEN
						Error(position,Diagnostics.Invalid,"duplicate active flag")
					ELSE
						recordBody.SetActive(TRUE); SetProtectedRecord;
					END;
				ELSIF name=Global.NameSafe THEN
					IF recordBody = NIL THEN
						Error(position,Diagnostics.Invalid,"safe not in record body");
					ELSIF recordBody.isSafe THEN
						Error(position,Diagnostics.Invalid,"duplicate safe flag")
					ELSE
						recordBody.SetSafe(TRUE);
						SetProtectedRecord;
					END;
				ELSIF name=Global.NameRealtime THEN
					IF recordBody = NIL THEN
						Error(position,Diagnostics.Invalid,"realtime not in record body");
					ELSIF recordBody.isRealtime THEN
						Error(position,Diagnostics.Invalid,"duplicate realtime flag")
					ELSE
						recordBody.SetRealtime(TRUE);
						block.SetRealtime(TRUE);
					END;
				ELSIF name=Global.NameUnchecked THEN
					IF block.isUnchecked THEN
						Error(position,Diagnostics.Invalid,"duplicate unchecked flag")
					ELSE
						block.SetUnchecked(TRUE);
					END;
				ELSIF (name=Global.NameUncooperative) THEN
					IF block.isUncooperative THEN
						Error(position,Diagnostics.Invalid,"duplicate uncooperative flag")
					ELSE
						block.SetUncooperative(TRUE);
					END;
				ELSE
					Error(position,Diagnostics.Invalid,"unknown block modifier");
				END;
				blockModifier := blockModifier.nextModifier;
			END;
		END BlockFlags;

		(** check and resolve statement block
			- check flags (exclusive)
			- check statement sequence
		**)
		PROCEDURE VisitStatementBlock(statementBlock: SyntaxTree.StatementBlock);
		VAR recentExclusive, recentUnreachable, recentRealtime: BOOLEAN;
		BEGIN
			BlockFlags(statementBlock);
			IF statementBlock.isExclusive THEN
				(* check that not in exclusive block *)
				IF currentIsExclusive THEN
					Error (statementBlock.position,Diagnostics.Invalid,"forbidden recursive exclusive")
				ELSIF currentIsRealtime THEN
					Error( statementBlock.position,Diagnostics.Invalid,"forbidden exculsive in realtime block");
				END;
			END;
			recentExclusive := currentIsExclusive;
			recentUnreachable := currentIsUnreachable;
			recentRealtime := currentIsRealtime;
			IF statementBlock.isExclusive THEN currentIsExclusive := TRUE END;
			IF statementBlock.isUnreachable THEN currentIsUnreachable := TRUE END;
			IF statementBlock.isRealtime THEN currentIsRealtime := TRUE END;
			StatementSequence(statementBlock.statements);
			currentIsRealtime := recentRealtime;
			currentIsExclusive := recentExclusive;
			currentIsUnreachable := recentUnreachable;
		END VisitStatementBlock;

		(** check and resolve body
			- check flags (active, priority, safe)
			- check body and finally part
		 **)
		PROCEDURE Body(body: SyntaxTree.Body);
		BEGIN
			VisitStatementBlock(body);
			IF body.isActive THEN
				IF  ~currentIsBodyProcedure THEN
					Error(body.position,Diagnostics.Invalid,"active flag not in object body");
				ELSIF body.priority # NIL THEN
					body.SetPriority(ConstantInteger(body.priority));
				END;
			ELSIF body.isSafe THEN
				Error(body.position,Diagnostics.Invalid,"safe flag not in active body");
			ELSIF body.priority # NIL THEN
				Error(body.position,Diagnostics.Invalid,"priority flag not in active body");
			END;
			IF body.code # NIL THEN
				CheckSystemImport(body.position);
			END;
			StatementSequence(body.finally)
		END Body;

		(*** scopes ***)

		(** Register a symbol in a scope. Check for duplicate symbols and collision with globally defined symbols. **)
		PROCEDURE Register(symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope; allowDuplicate: BOOLEAN);
		VAR duplicateSymbol: BOOLEAN;
		BEGIN
			ASSERT(symbol.name # SyntaxTree.invalidIdentifier);
			IF ~allowDuplicate & (global.FindSymbol(symbol.name)#NIL) THEN
				Error(symbol.position,Diagnostics.Invalid,"globally defined keyword")
			END;

			scope.EnterSymbol(symbol,duplicateSymbol);
			IF ~allowDuplicate & duplicateSymbol THEN
				Error(symbol.position,Basic.MultiplyDefinedIdentifier,"");
				IF VerboseErrorMessage THEN
					Printout.Info("multiply defined identifier",symbol);
					Printout.Info("in scope",scope);
				END;
			END;
		END Register;



		(**
			implementation: check and resolve an implementation part
		**)
		(*!	can in principle be done in parallel on different checkers: implementations do only depend on declarations)
		 move implementation checker to a separate object ? *)
		PROCEDURE Implementation(scope: SyntaxTree.Scope);
		VAR prevScope: SyntaxTree.Scope; procedure: SyntaxTree.Procedure; prevIsRealtime, prevIsBodyProcedure, prevIsCellNet: BOOLEAN;
		BEGIN
			prevIsRealtime := currentIsRealtime;
			prevIsBodyProcedure := currentIsBodyProcedure;
			prevIsCellNet := currentIsCellNet;
			prevScope := currentScope;
			currentScope := scope;
			IF (scope IS SyntaxTree.ProcedureScope) THEN
				procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
				currentIsBodyProcedure := currentIsBodyProcedure OR procedure.isBodyProcedure;
				currentIsRealtime := currentIsRealtime OR procedure.type.isRealtime;
				currentIsCellNet := InCellNetScope(procedure.scope) OR cellsAreObjects;
				(*
				IF procedure.isInline & ((scope(SyntaxTree.ProcedureScope).body = NIL) OR (scope(SyntaxTree.ProcedureScope).body # NIL) & (scope(SyntaxTree.ProcedureScope).body.code = NIL)) THEN
					Warning(procedure.position,"unsupported inline procedure - must be assembler code")
				END;
				*)
			END;
			IF (scope IS SyntaxTree.ProcedureScope) & (scope(SyntaxTree.ProcedureScope).body # NIL) (* & ~(scope IS SyntaxTree.RecordScope) *) THEN
				(* module body, record bodies are wrapped into an artifical procedure *)
				IF (phase = InlinePhase) & (IsOberonInline(procedure)) THEN
					Body(scope(SyntaxTree.ProcedureScope).body)
				ELSIF (phase = ImplementationPhase) & ~IsOberonInline(procedure) THEN
					Body(scope(SyntaxTree.ProcedureScope).body)
				END;
			END;
			currentScope := prevScope;
			currentIsRealtime := prevIsRealtime;
			currentIsBodyProcedure := prevIsBodyProcedure;
			currentIsCellNet := prevIsCellNet;
		END Implementation;

		(** implementation phase:
			check and resolve all scopes (implementation phase) that have been entered into a list during the declaration phase
		**)
		PROCEDURE Implementations(x: SyntaxTree.Module);
		VAR  scope: SyntaxTree.Scope; prevPhase: LONGINT;
		BEGIN
			prevPhase := phase;
			phase := InlinePhase;
			scope := x.firstScope;
			WHILE(scope # NIL) DO
				Implementation(scope);
				scope := scope.nextScope;
			END;
			phase := ImplementationPhase;
			scope := x.firstScope;
			WHILE(scope # NIL) DO
				Implementation(scope);
				scope := scope.nextScope;
			END;
			phase := prevPhase;
		END Implementations;

		(** declaration phase:
			check and resolve all declarations of a scope (module scope, procedure scope, record scope):
			- import lists (for module scopes)
			- parameter list (for procedure scopes)
			- constant declarations
			- type declarations
			- variable declarations
			- procedure declarations
			preformed in two stages:
				- first all symbols are entered into the symbol table (with uniqueness check),
				- then all symbols are resolved
			after declaration check, bodies are entered into the global list of implementations that remain to be resolved after all declarations.

			Declarations depend on other declarations, this procedure is neither thread safe not would it be wise to try concurrency here
		**)
		PROCEDURE Declarations(scope: SyntaxTree.Scope);
		VAR
			constant: SyntaxTree.Constant;
			typeDeclaration: SyntaxTree.TypeDeclaration;
			variable: SyntaxTree.Variable;
			procedure: SyntaxTree.Procedure;
			prevScope: SyntaxTree.Scope;
			parameter: SyntaxTree.Parameter;
			import: SyntaxTree.Import;
			symbol: SyntaxTree.Symbol;
			prevPhase: LONGINT;
			prevError : BOOLEAN;
			property: SyntaxTree.Property;
			type: SyntaxTree.Type;
			atype : SyntaxTree.ArrayType;
		BEGIN
			prevError := error;
			prevPhase := phase;
			phase := DeclarationPhase;
			prevScope := currentScope;
			currentScope := scope;
			error := FALSE;

			(* first enter all symbols in scope *)
			IF scope IS SyntaxTree.ModuleScope THEN
				(* treat imports first for a module scope, , set default context if necessary *)
				import := scope(SyntaxTree.ModuleScope).firstImport;
				WHILE(import # NIL) DO
					IF import.context = SyntaxTree.invalidIdentifier THEN import.SetContext(scope.ownerModule.context) END;
					Register(import, currentScope, FALSE);
					import := import.nextImport;
				END;
				import := scope(SyntaxTree.ModuleScope).firstImport;
				WHILE(import # NIL) DO (* 2nd stage to avoid duplicate symbol *)
					ResolveSymbol(import);
					import := import.nextImport;
				END;
			ELSIF scope IS SyntaxTree.ProcedureScope THEN
				(* enter parameters for a procedure scope *)
				parameter := scope(SyntaxTree.ProcedureScope).ownerProcedure.type.resolved(SyntaxTree.ProcedureType).firstParameter;
				WHILE(parameter # NIL) DO
					Register(parameter,currentScope, FALSE); parameter := parameter.nextParameter;
				END;
				parameter := scope(SyntaxTree.ProcedureScope).ownerProcedure.type.resolved(SyntaxTree.ProcedureType).returnParameter;
				IF parameter # NIL THEN Register(parameter, currentScope, FALSE); END;
			ELSIF scope IS SyntaxTree.CellScope THEN
				parameter := scope(SyntaxTree.CellScope).ownerCell.firstParameter;
				WHILE(parameter # NIL) DO
					variable := SyntaxTree.NewVariable(parameter.position, parameter.name);
					variable.SetType(parameter.type);
					variable.SetAccess(SyntaxTree.Hidden);
					variable.SetModifiers(parameter.modifiers);
					currentScope.PushVariable(variable);
					(*
					Register(parameter,scope, FALSE); 
					*)
					parameter := parameter.nextParameter;
				END;
				
				property := scope(SyntaxTree.CellScope).ownerCell.firstProperty;
				WHILE (property # NIL) DO
					property.SetAccess(SyntaxTree.Hidden);
					currentScope.PushVariable(property);
					property := property.nextProperty;
				END;
			END;
			IF error THEN RETURN END;

			(* constants *)
			constant := scope.firstConstant;
			WHILE (constant # NIL) DO
				Register(constant, currentScope, FALSE); constant := constant.nextConstant;
			END;
			(* type declarations *)
			typeDeclaration := scope.firstTypeDeclaration;
			WHILE (typeDeclaration # NIL) DO
				Register(typeDeclaration, currentScope, FALSE); typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
			(* variables *)
			variable := scope.firstVariable;
			WHILE (variable # NIL) DO
				Register(variable, currentScope, FALSE); variable := variable.nextVariable;
			END;
			(* procedures *)
			procedure := scope.firstProcedure;
			WHILE (procedure # NIL) DO
				Register(procedure, currentScope, procedure IS SyntaxTree.Operator); procedure := procedure.nextProcedure;
			END;


			(* now process all symbols without any presumption on the order *)
			symbol := scope.firstSymbol;
			WHILE(symbol # NIL) DO
				IF ~(symbol IS SyntaxTree.Parameter) OR (symbol(SyntaxTree.Parameter).ownerType IS SyntaxTree.CellType) THEN
					ResolveSymbol(symbol);
				END;
				symbol := symbol.nextSymbol;
			END;

			IF (scope IS SyntaxTree.ProcedureScope) & scope(SyntaxTree.ProcedureScope).ownerProcedure.type.isRealtime THEN
				symbol := scope.firstSymbol;
				WHILE symbol # NIL DO
					IF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
						IF (symbol.type IS SyntaxTree.PointerType) OR (symbol.type IS SyntaxTree.QualifiedType) THEN
							pointerFixes.Add(symbol, currentScope);
						END;
						IF ~symbol.type.resolved.isRealtime THEN
							Error(symbol.position,Diagnostics.Invalid,"symbol has no realtime type");
						END;
					END;
					symbol := symbol.nextSymbol
				END;
			END;

			IF ~error & ~system.GenerateVariableOffsets(scope) THEN
				Error(Diagnostics.Invalid,Diagnostics.Invalid,"problems during offset computation in module");
			END;

			IF scope.ownerModule # NIL THEN
				(* add scope to global list of all scopes, very handy for code generation and for checking implementations *)
				scope.ownerModule.AddScope(scope);
			END;

			phase := prevPhase;
			currentScope := prevScope;
			error := error OR prevError;
		END Declarations;

		(* nopov *)
		(** check if all operators from one module are compatible to the ones in the other module
		- check if there are not multiple operators with the same signature
			(apart from the conversion operator "@Convert": it is the only operator that may be defined multiple times with the same signature)
		- check for all operators whose signatures are compatible, whether the return types are compatible
		note that:
			- the return type is not considered to be part of the signature
			- two signatures are considered compatible, if all of the operands are compatible
		**)
		PROCEDURE CheckInterOperatorConformity(thisModuleScope, thatModuleScope: SyntaxTree.ModuleScope);
		VAR
			thisOperator, thatOperator: SyntaxTree.Operator;
			thisProcedureType, thatProcedureType: SyntaxTree.ProcedureType;
			thisParameter, thatParameter: SyntaxTree.Parameter;
			operandsAreEqual, operandsAreCompatible, hasError: BOOLEAN;
			i: LONGINT;
		BEGIN
			currentScope := thisModuleScope;
			hasError := FALSE;

			(* go through all operators in the other module *)
			thatOperator := thatModuleScope.firstOperator;
			WHILE (thatOperator # NIL) & ~hasError DO
				IF (thisModuleScope = thatModuleScope) OR (SyntaxTree.PublicRead IN thatOperator.access) THEN
					(* the other operator is accessible *)
					IF thatOperator.name # Global.GetIdentifier(Global.Conversion, thatModuleScope.ownerModule.case) THEN
						(* the other operator is not the conversion operator *)

						(* go through all operators in this module *)
						thisOperator := thisModuleScope.firstOperator;
						WHILE (thisOperator # NIL) & ~hasError DO
							IF thisOperator # thatOperator THEN
								(* the operators are not the same *)
								IF thisOperator.name = thatOperator.name THEN
									(* the operators share the same identifier *)

									ASSERT(thisOperator.type IS SyntaxTree.ProcedureType);
									ASSERT(thatOperator.type IS SyntaxTree.ProcedureType);
									thisProcedureType := thisOperator.type(SyntaxTree.ProcedureType);
									thatProcedureType := thatOperator.type(SyntaxTree.ProcedureType);
									IF thisProcedureType.numberParameters = thatProcedureType.numberParameters THEN
										(* both operators have the same paramter count *)
										thisParameter := thisProcedureType.firstParameter;
										thatParameter := thatProcedureType.firstParameter;
										operandsAreEqual := TRUE;
										operandsAreCompatible := TRUE;
										(* go through all parameters *)
										FOR i := 1 TO thisProcedureType.numberParameters DO
											ASSERT(thatParameter # NIL);
											IF ~SameType(thisParameter.type, thatParameter.type) THEN
												operandsAreEqual := FALSE;
												IF ~CompatibleTo(system, thisParameter.type, thatParameter.type) THEN
													operandsAreCompatible := FALSE
												END
											END;
											thisParameter := thisParameter.nextParameter;
											thatParameter := thatParameter.nextParameter
										END;
										IF operandsAreEqual THEN
											Error(thisOperator.position, Diagnostics.Invalid, "operator has the same identifier and operand types as other one");
											hasError := TRUE
										ELSIF operandsAreCompatible THEN
											IF ~CompatibleTo(system, thisProcedureType.returnType, thatProcedureType.returnType) THEN
												Error(thisOperator.position, Diagnostics.Invalid, "operator's return type is not compatible to the one of a more generic operator");
												hasError := TRUE
											ELSIF ~thisOperator.isDynamic & thatOperator.isDynamic THEN
												Error(thisOperator.position, Diagnostics.Invalid, "operator must be dynamic because it is signature-compatible to a dynamic one");
												hasError := TRUE
											END
										END
									END
								END
							END;
							thisOperator := thisOperator.nextOperator
						END
					END
			 	END;
			 	thatOperator := thatOperator.nextOperator
			 END
		END CheckInterOperatorConformity;

		(** check module:
			- check module declaration
			- add context, if necessary
			- remove module from import cache, if necessary
			- check declarations
			- resolve all type fixes
			- check implementation (bodies)
		**)
		PROCEDURE Module*(x: SyntaxTree.Module);
		VAR (* nopov *)
			import: SyntaxTree.Import; modifier: SyntaxTree.Modifier; value,position: LONGINT; prevIsCellNet: BOOLEAN; prevScope: SyntaxTree.Scope;
		BEGIN
			prevScope := currentScope;
			prevIsCellNet := currentIsCellNet;
			module := x;
			ASSERT(x # NIL);
			global := system.globalScope[x.case];
			x.moduleScope.SetGlobalScope(global);
			currentScope := global;
			IF (x.name = Global.SystemName) OR (x.name = Global.systemName) THEN Error(x.position,Diagnostics.Invalid,"name reserved") END;
			IF x.context = SyntaxTree.invalidIdentifier THEN x.SetContext(Global.A2Name) END;
			RemoveModuleFromCache(importCache,x);
			Declarations(x.moduleScope);
			FixTypes();

			IF module.isCellNet THEN
				currentIsCellNet := TRUE;
				modifier := x.modifiers;
				IF HasValue(modifier,Global.NameFrequencyDivider,position,value) THEN END;
				CheckModifiers(modifier, FALSE);
			END;

			(* nopov *)
			IF ~error THEN
				(* check if operators conform to each other within this module *)
				CheckInterOperatorConformity(x.moduleScope, x.moduleScope);

				(* go through all imports *)
				import := x.moduleScope.firstImport;
				WHILE import # NIL DO
					IF (import.module # NIL) & ~Global.IsSystemModule(import.module) THEN (* ignore SYSTEM-module *)
						(* check if all operators in this module conform to the ones of the imported module *)
						CheckInterOperatorConformity(x.moduleScope, import.module.moduleScope)
					END;
					import := import.nextImport
				END;
			END;

			Implementations(x);
			module := NIL;
			currentIsCellNet := prevIsCellNet;
			currentScope := prevScope;
		END Module;


	END Checker;

	Warnings*=OBJECT (SyntaxTree.Visitor)
	VAR diagnostics: Diagnostics.Diagnostics; module: SyntaxTree.Module;

		PROCEDURE &InitWarnings*(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics
		END InitWarnings;

		(** types *)
		PROCEDURE Type(x: SyntaxTree.Type);
		BEGIN x.Accept(SELF)
		END Type;

		PROCEDURE VisitType*(x: SyntaxTree.Type);
		BEGIN  END VisitType;

		PROCEDURE VisitBasicType*(x: SyntaxTree.BasicType);
		BEGIN  END VisitBasicType;

		PROCEDURE VisitCharacterType*(x: SyntaxTree.CharacterType);
		BEGIN END VisitCharacterType;

		PROCEDURE VisitIntegerType*(x: SyntaxTree.IntegerType);
		BEGIN END VisitIntegerType;

		PROCEDURE VisitFloatType*(x: SyntaxTree.FloatType);
		BEGIN END VisitFloatType;

		PROCEDURE VisitQualifiedType*(x: SyntaxTree.QualifiedType);
		BEGIN END VisitQualifiedType;

		PROCEDURE VisitStringType*(x: SyntaxTree.StringType);
		BEGIN END VisitStringType;

		PROCEDURE VisitEnumerationType*(x: SyntaxTree.EnumerationType);
		BEGIN END VisitEnumerationType;

		PROCEDURE VisitRangeType*(x: SyntaxTree.RangeType);
		BEGIN  END VisitRangeType;

		PROCEDURE VisitArrayType*(x: SyntaxTree.ArrayType);
		BEGIN
			IF ~(SyntaxTree.Warned IN x.state) THEN
				x.SetState(SyntaxTree.Warned);
				Type(x.arrayBase);
			END;
		END VisitArrayType;

		PROCEDURE VisitMathArrayType*(x: SyntaxTree.MathArrayType);
		BEGIN
			IF ~(SyntaxTree.Warned IN x.state) THEN
				x.SetState(SyntaxTree.Warned);
				Type(x.arrayBase);
			END;
		END VisitMathArrayType;

		PROCEDURE VisitPointerType*(x: SyntaxTree.PointerType);
		BEGIN
			IF ~(SyntaxTree.Warned IN x.state) THEN
				x.SetState(SyntaxTree.Warned);
				Type(x.pointerBase);
			END;
		END VisitPointerType;

		PROCEDURE VisitRecordType*(x: SyntaxTree.RecordType);
		BEGIN Scope(x.recordScope) END VisitRecordType;

		PROCEDURE VisitCellType*(x: SyntaxTree.CellType);
		BEGIN  Scope(x.cellScope) END VisitCellType;

		PROCEDURE VisitProcedureType*(x: SyntaxTree.ProcedureType);
		BEGIN  END VisitProcedureType;

		PROCEDURE Warning(x: SyntaxTree.Symbol; CONST text: ARRAY OF CHAR);
		VAR msg: ARRAY 256 OF CHAR;
		BEGIN
			Global.GetSymbolName(x,msg);
			Strings.Append(msg," ");
			Strings.Append(msg,text);
			diagnostics.Warning(module.sourceName,x.position,Diagnostics.Invalid,msg);
		END Warning;

		(** symbols *)
		PROCEDURE Symbol(x: SyntaxTree.Symbol);
		BEGIN
			IF ~x.used & (x.access * SyntaxTree.Public = {}) & (x.access # SyntaxTree.Hidden) THEN
				IF ~(x IS SyntaxTree.Parameter) THEN
					Warning(x,"never used");
				END;
			END;
			x.Accept(SELF);
		END Symbol;

		PROCEDURE VisitSymbol*(x: SyntaxTree.Symbol);
		BEGIN END VisitSymbol;

		PROCEDURE VisitTypeDeclaration*(x: SyntaxTree.TypeDeclaration);
		BEGIN Type(x.declaredType) END VisitTypeDeclaration;

		PROCEDURE VisitConstant*(x: SyntaxTree.Constant);
		BEGIN  END VisitConstant;

		PROCEDURE VisitVariable*(x: SyntaxTree.Variable);
		BEGIN  END VisitVariable;

		PROCEDURE VisitProperty*(x: SyntaxTree.Property);
		BEGIN  END VisitProperty;

		PROCEDURE VisitParameter*(x: SyntaxTree.Parameter);
		BEGIN	END VisitParameter;

		PROCEDURE VisitProcedure*(x: SyntaxTree.Procedure);
		BEGIN Scope(x.procedureScope) END VisitProcedure;

		PROCEDURE VisitOperator*(x: SyntaxTree.Operator);
		BEGIN END VisitOperator;

		PROCEDURE VisitImport*(x: SyntaxTree.Import);
		BEGIN END VisitImport;

		PROCEDURE Scope(scope: SyntaxTree.Scope);
		VAR
			symbol: SyntaxTree.Symbol;
		BEGIN
			symbol := scope.firstSymbol;
			WHILE(symbol # NIL) DO
				Symbol(symbol);
				symbol := symbol.nextSymbol;
			END;
		END Scope;

		PROCEDURE Module*(x: SyntaxTree.Module);
		BEGIN
			SELF.module := x;
			Scope(x.moduleScope);
		END Module;

	END Warnings;

	PROCEDURE IsOberonInline(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		RETURN procedure.isInline & ((procedure.procedureScope.body = NIL) OR (procedure.procedureScope.body # NIL) & (procedure.procedureScope.body.code = NIL))
	END IsOberonInline;


	PROCEDURE Resolved(x: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		IF x = NIL THEN RETURN NIL ELSE RETURN x.resolved END;
	END Resolved;

	PROCEDURE PowerOf2(x: LONGINT): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		i := 1;
		WHILE i < x DO
			i := i *2
		END;
		RETURN i=x
	END PowerOf2;

	PROCEDURE IsCellNetScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		RETURN
			(scope # NIL) &
			(scope IS SyntaxTree.ModuleScope)
			& (scope(SyntaxTree.ModuleScope).ownerModule.isCellNet)
			OR
			 (scope # NIL) & (scope IS SyntaxTree.CellScope)
			 & (scope(SyntaxTree.CellScope).ownerCell.isCellNet)
	END IsCellNetScope;

	PROCEDURE IsCellScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		RETURN (scope # NIL) & (scope IS SyntaxTree.CellScope) & ~(scope(SyntaxTree.CellScope).ownerCell.isCellNet)
	END IsCellScope;


	PROCEDURE InCellNetScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		WHILE (scope # NIL) & ~IsCellScope(scope) & ~IsCellNetScope(scope) DO scope := scope.outerScope END;
		RETURN (scope # NIL) & IsCellNetScope(scope)
	END InCellNetScope;


	PROCEDURE ToMemoryUnits(system: Global.System; size: LONGINT): LONGINT;
	BEGIN
		ASSERT(size MOD system.dataUnit = 0);
		RETURN size DIV system.dataUnit
	END ToMemoryUnits;

	(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
	PROCEDURE GetProcedureAllowed*(type: SyntaxTree.Type) : BOOLEAN;
	VAR procedureType: SyntaxTree.ProcedureType; numberParameters: LONGINT;

		PROCEDURE TypeAllowed(t : SyntaxTree.Type) : BOOLEAN;
		BEGIN
			IF t = NIL THEN
				RETURN TRUE
			ELSE
				t := t.resolved;
				RETURN (t IS SyntaxTree.RecordType) OR IsPointerToRecord(t) OR (t IS SyntaxTree.AnyType);
			END;
		END TypeAllowed;

	BEGIN
		type := type.resolved;
		IF ~(type IS SyntaxTree.ProcedureType) THEN
			RETURN FALSE
		ELSE
			procedureType := type(SyntaxTree.ProcedureType);
			numberParameters := procedureType.numberParameters;
			RETURN
				(numberParameters = 0) & TypeAllowed(procedureType.returnType) OR
				(numberParameters = 1) & TypeAllowed(procedureType.firstParameter.type) & TypeAllowed(procedureType.returnType) OR
				(numberParameters = 1) & (procedureType.firstParameter.ownerType.resolved IS SyntaxTree.AnyType) & (procedureType.returnType.resolved IS SyntaxTree.AnyType)
		END;
	END GetProcedureAllowed;

	(** check import cache: if module x is in current import cache then remove x and all modules importing x from the cache **)
	PROCEDURE RemoveModuleFromCache*(importCache: SyntaxTree.ModuleScope; x: SyntaxTree.Module);
	VAR import: SyntaxTree.Import;
	BEGIN
		import := importCache.ImportByModuleName(x.name,x.context);
		IF import # NIL THEN
			importCache.RemoveImporters(x.name,x.context);
		END;
	END RemoveModuleFromCache;

	PROCEDURE CompatibleTo(system: Global.System; this,to: SyntaxTree.Type): BOOLEAN;
	(* to <- this assignment compatibility *)
	VAR result: BOOLEAN;
	BEGIN
		IF this= NIL THEN result := (to=NIL)
		ELSIF to=NIL THEN result := FALSE
		ELSE
			(*! will be replaced by this:
			ELSE result := this.CompatibleTo(to.resolved);
			*)
			this := this.resolved; to := to.resolved;
			IF to=SyntaxTree.invalidType THEN result := FALSE
			ELSIF to=SyntaxTree.typeDeclarationType THEN result := FALSE;
			ELSIF to = this THEN
				result := ~(to IS SyntaxTree.ArrayType) OR (to(SyntaxTree.ArrayType).form # SyntaxTree.Open);

			ELSIF to IS SyntaxTree.BasicType THEN
				IF (to IS SyntaxTree.NumberType) & (this IS SyntaxTree.NumberType) THEN
					IF (to IS SyntaxTree.ComplexType) OR (this IS SyntaxTree.ComplexType) THEN
						result := this.CompatibleTo(to.resolved)
					ELSE
						result := Global.BasicTypeDistance(system,this(SyntaxTree.BasicType),to(SyntaxTree.BasicType)) < Infinity;
					END
				ELSIF (to IS SyntaxTree.SetType) & (this IS SyntaxTree.SetType) THEN
					result := to.sizeInBits = this.sizeInBits;
				ELSIF (to IS SyntaxTree.IntegerType) & (this IS SyntaxTree.AddressType) THEN
					result := to.sizeInBits >= this.sizeInBits; (* weak compatibility: (unsigned) address may be assigned to signed integer of same (or greater) size *)
				ELSIF (to IS SyntaxTree.IntegerType) & (this IS SyntaxTree.SizeType) THEN
					result := to.sizeInBits >= this.sizeInBits; (* compatibility: (signed) size may be assigned to signed integer of greater or equal size *)
				ELSIF (to IS SyntaxTree.FloatType) & (this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.SizeType) THEN
					result := TRUE;
				ELSIF to IS SyntaxTree.AnyType THEN
					result :=  (this IS SyntaxTree.RecordType) & this(SyntaxTree.RecordType).isObject OR (this IS SyntaxTree.PointerType) OR (this IS SyntaxTree.ProcedureType) OR (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.AnyType) OR (this IS SyntaxTree.ObjectType);
				ELSIF to IS SyntaxTree.ObjectType THEN
					result := IsPointerToRecord(this) OR (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.ObjectType) OR (this IS SyntaxTree.AnyType) (*! remove when symbol file can distinguish OBJECT from ANY *) ;
				ELSIF to IS SyntaxTree.ByteType THEN
					result := (this IS SyntaxTree.IntegerType) & (to.sizeInBits = 8) OR IsCharacterType(this)
				ELSIF to IS SyntaxTree.CharacterType THEN
					result := IsCharacterType(this)
				ELSIF (to IS SyntaxTree.SizeType) & ((this IS SyntaxTree.SizeType) OR (this IS SyntaxTree.IntegerType) OR (this IS SyntaxTree.AddressType)) THEN
					result := to.sizeInBits >= this.sizeInBits (*! weak compatibility: signed size type may be assigned with unsigned address type of same size *)
				ELSIF (to IS SyntaxTree.AddressType) & ((this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.IntegerType) OR (this IS SyntaxTree.SizeType) OR IsPointerType(this)) THEN
					result := to.sizeInBits >= this.sizeInBits; (*! weak compatibility: addresses may be assigned with signed integer *)
				ELSIF (to IS SyntaxTree.RangeType) & (this IS SyntaxTree.RangeType) THEN
					result := TRUE;
				ELSIF (to IS SyntaxTree.BooleanType) & (this IS SyntaxTree.BooleanType) THEN
					result := TRUE;
				ELSE
					result := FALSE
				END;

			ELSIF to IS SyntaxTree.PointerType THEN
				result := (this IS SyntaxTree.NilType) OR ((this IS SyntaxTree.AddressType) OR (this IS SyntaxTree.IntegerType)) & to(SyntaxTree.PointerType).isUnsafe OR
						IsPointerType(this) & (IsTypeExtension(to,this) OR ((to(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType) & SameType(to,this)))
				     & (~to.isRealtime OR this.isRealtime);
			ELSIF to IS SyntaxTree.ProcedureType THEN
				result := (this IS SyntaxTree.NilType) OR (this IS SyntaxTree.ProcedureType) & SameType(to(SyntaxTree.ProcedureType),this(SyntaxTree.ProcedureType))
					& (~(this(SyntaxTree.ProcedureType).isDelegate) OR (to(SyntaxTree.ProcedureType).isDelegate))
					& (~to.isRealtime OR this.isRealtime)
					& ((this(SyntaxTree.ProcedureType).stackAlignment <=1) OR (this(SyntaxTree.ProcedureType).stackAlignment <= to(SyntaxTree.ProcedureType).stackAlignment));
			ELSIF (to IS SyntaxTree.RecordType) & to(SyntaxTree.RecordType).isObject THEN
				result := (this IS SyntaxTree.NilType) OR IsTypeExtension(to,this);
			ELSIF to IS SyntaxTree.RecordType THEN
				result :=  (this IS SyntaxTree.RecordType) & IsTypeExtension(to,this);
			ELSIF to IS SyntaxTree.ArrayType THEN
				IF IsStringType(to) & (this IS SyntaxTree.StringType) THEN
					result := (to(SyntaxTree.ArrayType).form = SyntaxTree.Open) OR (to(SyntaxTree.ArrayType).staticLength >= this(SyntaxTree.StringType).length)
				ELSIF StaticArrayCompatible(to, this) THEN
					result := TRUE
				ELSE
					result := (to(SyntaxTree.ArrayType).staticLength # 0) & SameType(to,this)
				END;
			ELSIF to IS SyntaxTree.MathArrayType THEN
				IF this IS SyntaxTree.MathArrayType THEN
					IF to(SyntaxTree.MathArrayType).arrayBase= NIL THEN
						IF to(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
							result := TRUE;
						ELSIF this(SyntaxTree.MathArrayType).arrayBase = NIL THEN
							result := TRUE;
						ELSE
							result := ~(this(SyntaxTree.MathArrayType).arrayBase.resolved IS SyntaxTree.MathArrayType);
						END;
						(* special case: ARRAY [...] OF SYSTEM.ALL *)
					ELSIF (to(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) OR (this(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) THEN
						(* ARRAY [?] OF <- ARRAY [x,...,x] OF *)
						result := CompatibleTo(system,ArrayBase(this,Infinity),ArrayBase(to,Infinity));
					ELSIF (to(SyntaxTree.MathArrayType).form = SyntaxTree.Open) OR (this(SyntaxTree.MathArrayType).form = SyntaxTree.Open)
						OR (to(SyntaxTree.MathArrayType).staticLength = this(SyntaxTree.MathArrayType).staticLength) THEN
						(* ARRAY [x] OF <- ARRAY [x] OF  *)
						result := CompatibleTo(system,this(SyntaxTree.MathArrayType).arrayBase,to(SyntaxTree.MathArrayType).arrayBase);
					ELSE
						result := FALSE
					END;

				(* an array-structured object type is compatible to the type of its array structure *)
				ELSIF IsArrayStructuredObjectType(this) THEN
					result := CompatibleTo(system, to, MathArrayStructureOfType(this))

				ELSE
					result := FALSE;
				END;
			ELSIF to IS SyntaxTree.StringType THEN
				result := FALSE;
			ELSIF to IS SyntaxTree.EnumerationType THEN
				result := IsEnumerationExtension(this,to);
			ELSIF to IS SyntaxTree.PortType THEN
				result := SameType(to, this)
			ELSE
				Printout.Info("CompatibleTo",to);
				HALT(100); (* implement missing type check *)
			END;
		END;
		RETURN result
	END CompatibleTo;

	PROCEDURE StaticArrayCompatible(formal: SyntaxTree.Type; actual: SyntaxTree.Type): BOOLEAN;
	VAR actualBase, formalBase: SyntaxTree.Type;
	BEGIN
		IF SameType(formal,actual) THEN
			RETURN TRUE
		ELSIF (formal IS SyntaxTree.MathArrayType) & (actual IS SyntaxTree.ArrayType) THEN
			actualBase := actual(SyntaxTree.ArrayType).arrayBase.resolved;
			formalBase := formal(SyntaxTree.MathArrayType).arrayBase.resolved;
			RETURN
				(formal(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.ArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.ArrayType).staticLength = formal(SyntaxTree.MathArrayType).staticLength)
				& StaticArrayCompatible(formalBase,actualBase)
		ELSIF (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.MathArrayType) THEN
			actualBase := actual(SyntaxTree.MathArrayType).arrayBase.resolved;
			formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
			RETURN
				(formal(SyntaxTree.ArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
				& (actual(SyntaxTree.MathArrayType).staticLength = formal(SyntaxTree.ArrayType).staticLength)
				& StaticArrayCompatible(formalBase,actualBase)
		ELSE RETURN FALSE
		END;
	END StaticArrayCompatible;


	PROCEDURE OpenArrayCompatible(formalType: SyntaxTree.ArrayType; actualType: SyntaxTree.Type): BOOLEAN;
	VAR arrayBase: SyntaxTree.Type; result: BOOLEAN;

		PROCEDURE TC(formal,actual: SyntaxTree.Type): BOOLEAN;
		VAR actualBase,formalBase: SyntaxTree.Type; result: BOOLEAN;
		BEGIN
			result := SameType(formal,actual);
			IF ~result & (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.ArrayType) THEN
				actualBase := actual(SyntaxTree.ArrayType).arrayBase.resolved;
				formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
				result := (formal(SyntaxTree.ArrayType).form = SyntaxTree.Open) & TC(formalBase,actualBase)
			ELSIF ~result & (formal IS SyntaxTree.ArrayType) & (actual IS SyntaxTree.MathArrayType) THEN
				actualBase := actual(SyntaxTree.MathArrayType).arrayBase.resolved;
				formalBase := formal(SyntaxTree.ArrayType).arrayBase.resolved;
				result := (formal(SyntaxTree.ArrayType).form = SyntaxTree.Open) & (actual(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
					& TC(formalBase, actualBase);
			END;
			RETURN result
		END TC;

	BEGIN
		IF formalType.form # SyntaxTree.Open THEN result := FALSE
		ELSE
			arrayBase := formalType.arrayBase.resolved;
			IF (actualType IS SyntaxTree.StringType) THEN
				result := arrayBase IS SyntaxTree.CharacterType
			ELSIF actualType IS SyntaxTree.ArrayType THEN
				result := (arrayBase IS SyntaxTree.ByteType) OR TC(formalType,actualType)
			ELSIF actualType IS SyntaxTree.MathArrayType THEN
				result := TC(formalType, actualType);
			ELSE
				result := (arrayBase IS SyntaxTree.ByteType)
			END;
		END;
		RETURN result
	END OpenArrayCompatible;

	PROCEDURE MathArrayCompatible(formalType: SyntaxTree.MathArrayType; actualType: SyntaxTree.Type): BOOLEAN;
	(* special compatibility rule for parameters of the form VAR A: ARRAY [x] OF , VAR A: ARRAY [*] OF and VAR A: ARRAY [?] OF  *)
	VAR formalBase,actualBase: SyntaxTree.Type; result: BOOLEAN; actualArray: SyntaxTree.MathArrayType;
	BEGIN
		IF actualType IS SyntaxTree.MathArrayType THEN
			actualArray := actualType(SyntaxTree.MathArrayType);
			IF (formalType.form = SyntaxTree.Tensor) OR (actualArray.form = SyntaxTree.Tensor) THEN
				(*
					ARRAY [?] OF  -> ARRAY [?|*|k] OF
					ARRAY [?|*|k] OF -> ARRAY [?] OF
				*)
				actualBase := ArrayBase(actualType,Infinity);
				formalBase := ArrayBase(formalType,Infinity);
				result := (formalBase = NIL) OR SameType(formalBase,actualBase);
			ELSE
				(*
					ARRAY [*|k] OF -> ARRAY [*|n] OF
				*)
				formalBase := Resolved(formalType.arrayBase);
				actualBase := Resolved(actualArray.arrayBase);
				IF (formalType.form = SyntaxTree.Static) & (actualArray.form = SyntaxTree.Static) THEN
					(*
						ARRAY [k] -> ARRAY [n]
					*)
					result := (formalType.staticLength = actualArray.staticLength)
				ELSE
					result := TRUE
				END;
				IF ~result THEN
				ELSIF formalBase = NIL THEN result := (actualBase = NIL) OR ~(actualBase IS SyntaxTree.MathArrayType);
				ELSIF actualBase = NIL THEN result := FALSE
				ELSIF formalBase IS SyntaxTree.MathArrayType THEN
					result := MathArrayCompatible(formalBase(SyntaxTree.MathArrayType),actualBase)
				ELSE
					result := SameType(formalBase,actualBase)
				END;
			END;
		ELSE
			result := FALSE
		END;
		RETURN result
	END MathArrayCompatible;



	(**
		Math Array Type distance for assignments / parameter passings of the form
		from -> to
		variants:
		ARRAY [num] | ARRAY [*] | ARRAY [?] -> ARRAY [num] | ARRAY[*] | ARRAY [?]

		allowed:
			static -> static (& size match)
			static -> open
			static -> tensor
			open -> open
			open -> tensor
			open -> static
			tensor -> tensor
			tensor -> open
			tensor -> static
	**)
	(*! think about the metric here: is form matching more important than element type matching? *)
	PROCEDURE MathArrayTypeDistance(system: Global.System; from,to: SyntaxTree.MathArrayType; varpar:BOOLEAN): LONGINT;
	VAR i: LONGINT; fromBase, toBase: SyntaxTree.Type;
	BEGIN
		fromBase := Resolved(from.arrayBase);
		toBase := Resolved(to.arrayBase);
		i := Infinity;
		IF from = to THEN
			i := 0;
		ELSIF (from.form = to.form) THEN
			(* static -> static, open -> open, tensor -> tensor *)
			IF (from.form # SyntaxTree.Static) OR (from.staticLength = to.staticLength) THEN
				IF fromBase = toBase THEN i := 0
				ELSIF toBase = NIL THEN i := 1
				ELSIF (fromBase IS SyntaxTree.MathArrayType) & (toBase IS SyntaxTree.MathArrayType) THEN
					i := MathArrayTypeDistance(system,fromBase(SyntaxTree.MathArrayType),toBase(SyntaxTree.MathArrayType),varpar);
				ELSE
					i := TypeDistance(system,fromBase, toBase, varpar);
				END;
			END;
		ELSIF (to.form = SyntaxTree.Static) THEN
			(* forbidden *)
		ELSIF (from.form = SyntaxTree.Tensor) OR (to.form = SyntaxTree.Tensor) THEN
			(* static -> tensor, open -> tensor, tensor -> open *)
			IF toBase=fromBase THEN i := 0;
			ELSIF toBase = NIL THEN i := 1;
			ELSIF (toBase IS SyntaxTree.MathArrayType) THEN
				toBase := ArrayBase(toBase,Infinity);
				IF (fromBase=toBase) THEN i := 0
				ELSIF (toBase = NIL) THEN i:= 1
				ELSIF (fromBase = NIL) THEN i := Infinity;
				ELSE i := TypeDistance(system,fromBase,toBase,varpar);
				END;
			ELSIF (fromBase IS SyntaxTree.MathArrayType) THEN
				fromBase := ArrayBase(fromBase,Infinity);
				IF (fromBase=toBase) THEN i := 0
				ELSIF (toBase = NIL) THEN i := 1
				ELSIF (fromBase = NIL) THEN i := Infinity;
				ELSE i := TypeDistance(system,fromBase,toBase,varpar);
				END;
			ELSE i := TypeDistance(system, fromBase, toBase, varpar);
			END;
			IF i # Infinity THEN INC(i,2) END;
		ELSIF (from.form = SyntaxTree.Static) THEN
			(* static -> open *)
			IF toBase=fromBase THEN i := 0
			ELSIF toBase = NIL THEN i := 1
			ELSIF fromBase = NIL THEN i := Infinity
			ELSIF (toBase IS SyntaxTree.MathArrayType) & (fromBase IS SyntaxTree.MathArrayType) THEN
				i := MathArrayTypeDistance(system,fromBase(SyntaxTree.MathArrayType),toBase(SyntaxTree.MathArrayType),varpar);
			ELSE i := TypeDistance(system,fromBase, toBase, varpar);
			END;
			IF i # Infinity THEN INC(i,1) END;
		ELSE HALT(100); (* unknown case *)
		END;
		RETURN i;
	END MathArrayTypeDistance;

	(** compute and return the distance of two array types
	- return the distance of the base types
	**)
	PROCEDURE ArrayTypeDistance(system: Global.System; from, to: SyntaxTree.ArrayType): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := Infinity;
		IF from = to THEN
			i := 0
		ELSE
			i := TypeDistance(system,from.arrayBase.resolved, to.arrayBase.resolved,FALSE);
		(*
		ELSIF (from.mode = static) & (to.mode IN {open}) THEN
			i := TypeDistance(from.base, to.base);
			IF i >= 0 THEN INC(i) END
		ELSIF (from.mode = open) & (to.mode = open) THEN
			i := TypeDistance(from.base, to.base);
		*)
		END;
		RETURN i
	END ArrayTypeDistance;

	(** compute the signature distance of a procedure and an actual parameter list
		- if any of the parameters are not compatible, the result is infinite
		- add up and return the distance over all parameters
	**)
	PROCEDURE Distance(system: Global.System; procedureType: SyntaxTree.ProcedureType; actualParameters: SyntaxTree.ExpressionList): LONGINT;
	VAR result: LONGINT; formalParameter: SyntaxTree.Parameter; actualParameter: SyntaxTree.Expression;
	distance: LONGINT; baseFormal,baseActual: SyntaxTree.Type; i: LONGINT;
	BEGIN
		IF actualParameters.Length() # (procedureType.numberParameters) THEN
			result := Infinity
		ELSE
			formalParameter := procedureType.firstParameter;
			i := 0;
			result := 0;
			(*! taken from paco, seems to not be 100% correct, check (in particular array part -> length of arrays??) *)
			WHILE (formalParameter # NIL) & (result # Infinity) DO
				actualParameter := actualParameters.GetExpression(i);
				ASSERT(formalParameter.type # NIL);
				IF (actualParameter.type = NIL) THEN distance := Infinity
				ELSE
					distance := TypeDistance(system,actualParameter.type.resolved,formalParameter.type.resolved,formalParameter.kind = SyntaxTree.VarParameter);
				END;
				IF distance = Infinity THEN
					result := Infinity;
				ELSE
					IF (formalParameter.kind = SyntaxTree.VarParameter) & (distance # 0) THEN
						IF (formalParameter.type.resolved IS SyntaxTree.MathArrayType) & (actualParameter.type.resolved IS SyntaxTree.MathArrayType) THEN
							(* already handled varpar *)
							(*
							baseActual := actualParameter.type.resolved(SyntaxTree.MathArrayType).arrayBase.resolved;
							baseFormal := formalParameter.type.resolved(SyntaxTree.MathArrayType).arrayBase.resolved;
							WHILE(baseActual IS SyntaxTree.MathArrayType) & (baseFormal IS SyntaxTree.MathArrayType) DO
								baseActual := baseActual(SyntaxTree.MathArrayType).arrayBase.resolved;
								baseFormal := baseFormal(SyntaxTree.MathArrayType).arrayBase.resolved;
							END;
							IF TypeDistance(system,baseActual,baseFormal,FALSE) # 0 THEN
								result := Infinity
							END;
							*)
						ELSIF (formalParameter.type.resolved IS SyntaxTree.ArrayType) & (actualParameter.type.resolved IS SyntaxTree.ArrayType) THEN
							baseActual := actualParameter.type.resolved(SyntaxTree.ArrayType).arrayBase.resolved;
							baseFormal := formalParameter.type.resolved(SyntaxTree.ArrayType).arrayBase.resolved;
							WHILE(baseActual IS SyntaxTree.ArrayType) & (baseFormal IS SyntaxTree.ArrayType) DO
								baseActual := baseActual(SyntaxTree.ArrayType).arrayBase.resolved;
								baseFormal := baseFormal(SyntaxTree.ArrayType).arrayBase.resolved;
							END;
							IF TypeDistance(system,baseActual,baseFormal,FALSE) # 0 THEN
								result := Infinity
							END;
						ELSE
							result := Infinity
						END;
					ELSE
						INC(result,distance);
					END;
				END;
				formalParameter := formalParameter.nextParameter; INC(i);
			END;
		END;
		ASSERT(result >= 0);
		RETURN result
	END Distance;
	
	PROCEDURE ProcedureTypeDistance(system: Global.System; procedureType: SyntaxTree.ProcedureType; right: SyntaxTree.ProcedureType): LONGINT;
	VAR result: LONGINT; formalParameter, rightParameter: SyntaxTree.Parameter; distance: LONGINT; i: LONGINT;
	BEGIN
		IF right.numberParameters # (procedureType.numberParameters) THEN
			result := Infinity
		ELSE
			formalParameter := procedureType.firstParameter;
			rightParameter := right.firstParameter;
			i := 0;
			result := 0;
			(*! taken from paco, seems to not be 100% correct, check (in particular array part -> length of arrays??) *)
			WHILE (formalParameter # NIL) & (result # Infinity) DO
				distance := TypeDistance(system,rightParameter.type.resolved,formalParameter.type.resolved,formalParameter.kind = SyntaxTree.VarParameter);
				IF distance = Infinity THEN
					result := Infinity;
				ELSE
					INC(result,distance);
				END;
				formalParameter := formalParameter.nextParameter;
				rightParameter := rightParameter.nextParameter;
			END;
		END;
		ASSERT(result >= 0);
		RETURN result
	END ProcedureTypeDistance;

	(** compute and return the distance between two types, used for computation of signature distance
		from -> to
	**)
	PROCEDURE TypeDistance(system: Global.System; from, to: SyntaxTree.Type; varpar: BOOLEAN): LONGINT;
	VAR i: LONGINT; ptr: SyntaxTree.PointerType;
	BEGIN
		IF IsArrayStructuredObjectType(from) & (to IS SyntaxTree.MathArrayType) THEN
			RETURN TypeDistance(system, MathArrayStructureOfType(from), to, varpar) + 0; (* TODO: find better value?*)
		END;

		i := Infinity;

		IF from = to THEN
			i := 0
		ELSIF (to = NIL) OR (from=NIL) THEN HALT(100); (* was: SYSTEM.ALL type, removed *)
		ELSIF (from IS SyntaxTree.NilType) OR (to IS SyntaxTree.NilType) THEN
			i := Infinity;
		ELSIF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
			i := 1
		ELSIF (from IS SyntaxTree.StringType) THEN
			IF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved  IS SyntaxTree.CharacterType) THEN  i := 1  END
		ELSIF (from IS SyntaxTree.CharacterType) THEN
			IF (to IS SyntaxTree.CharacterType) & (to.sizeInBits = from.sizeInBits) THEN i := 0
			ELSIF (to IS SyntaxTree.ArrayType) & (to(SyntaxTree.ArrayType).length = NIL) & (to(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType) THEN  i := 1
			ELSIF to IS SyntaxTree.ByteType THEN i := 1 END
		ELSIF (from IS SyntaxTree.IntegerType) & (to IS SyntaxTree.ByteType) & (to.sizeInBits = from.sizeInBits) THEN
			i := 1
		ELSIF (from IS SyntaxTree.NilType) THEN
			IF (to IS SyntaxTree.AnyType) OR (to IS SyntaxTree.ObjectType) OR (to IS SyntaxTree.PointerType) OR (to IS SyntaxTree.ProcedureType) THEN i := 1 END
		(*
		ELSIF (from = NoType) THEN
			IF (to IS Delegate) THEN i := 1 END	(*special case: procedure -> proctype, not resolved yet*)
		*)
		ELSIF (from IS SyntaxTree.BasicType) THEN
			IF to IS SyntaxTree.BasicType THEN  i := Global.BasicTypeDistance(system,from(SyntaxTree.BasicType), to(SyntaxTree.BasicType)) END;
			IF varpar & (i # 0) THEN i := Infinity END;
		ELSIF (from IS SyntaxTree.ArrayType) THEN
			IF to IS SyntaxTree.ArrayType THEN i := ArrayTypeDistance(system,from(SyntaxTree.ArrayType), to(SyntaxTree.ArrayType)) END
		ELSIF (from IS SyntaxTree.RecordType) THEN
			IF to IS SyntaxTree.RecordType THEN i := RecordTypeDistance(from(SyntaxTree.RecordType), to (SyntaxTree.RecordType)) END
		ELSIF (from IS SyntaxTree.MathArrayType) THEN
			IF to IS SyntaxTree.MathArrayType THEN
				(*
				IF varpar & (from(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (to(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) THEN
					i := Infinity;
				ELSE
				*)
					i := MathArrayTypeDistance(system,from(SyntaxTree.MathArrayType), to(SyntaxTree.MathArrayType),varpar)
				(*
				END;
				*)
			END
		ELSIF (from IS SyntaxTree.PointerType) THEN
			ptr := from(SyntaxTree.PointerType);
			IF (to IS SyntaxTree.AnyType) THEN i := 1
			ELSIF to IS SyntaxTree.PointerType THEN i := PointerTypeDistance(ptr, to(SyntaxTree.PointerType))
			(* ELSE i := TypeDistance(ptr.base, to); *)
			END
		ELSIF (from IS SyntaxTree.ProcedureType) THEN
			IF (to IS SyntaxTree.ProcedureType) THEN
				i := ProcedureTypeDistance(system, from(SyntaxTree.ProcedureType), to(SyntaxTree.ProcedureType));
			END;
		(*no procedure test, procedure must be the same*)
		END;
		RETURN i
	END TypeDistance;

	PROCEDURE IsIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & ((type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType))
	END IsIntegerType;

	PROCEDURE IsAddressType*(type: SyntaxTree.Type; addressWidth: LONGINT): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & ((type IS SyntaxTree.IntegerType) & (type(SyntaxTree.IntegerType).sizeInBits <= addressWidth) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType))
	END IsAddressType;

	PROCEDURE IsSizeType(type: SyntaxTree.Type; addressWidth: LONGINT): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & ((type IS SyntaxTree.IntegerType) & (type(SyntaxTree.IntegerType).sizeInBits <= addressWidth) OR (type IS SyntaxTree.SizeType))
	END IsSizeType;


	PROCEDURE IsSignedIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type IS SyntaxTree.IntegerType) & type(SyntaxTree.IntegerType).signed
	END IsSignedIntegerType;

	PROCEDURE IsUnsignedIntegerType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type IS SyntaxTree.IntegerType) & ~type(SyntaxTree.IntegerType).signed
	END IsUnsignedIntegerType;

	PROCEDURE IsIntegerValue(x: SyntaxTree.Expression; VAR value: LONGINT): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
			value :=  x.resolved(SyntaxTree.IntegerValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsIntegerValue;

	PROCEDURE IsEnumerationValue(x: SyntaxTree.Expression; VAR value: LONGINT): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF (x.resolved # NIL) & (x.resolved IS SyntaxTree.EnumerationValue) THEN
			value :=  x.resolved(SyntaxTree.EnumerationValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsEnumerationValue;


	PROCEDURE IsRealValue(x: SyntaxTree.Expression; VAR value: LONGREAL): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.RealValue) THEN
			value :=  x.resolved(SyntaxTree.RealValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsRealValue;

	PROCEDURE IsComplexValue(x: SyntaxTree.Expression; VAR realValue, imagValue: LONGREAL): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.ComplexValue) THEN
			realValue :=  x.resolved(SyntaxTree.ComplexValue).realValue;
			imagValue :=  x.resolved(SyntaxTree.ComplexValue).imagValue;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsComplexValue;

	PROCEDURE IsCharacterValue(x: SyntaxTree.Expression; VAR value: CHAR): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.CharacterValue) THEN
			value :=  x.resolved(SyntaxTree.CharacterValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsCharacterValue;

	PROCEDURE IsBooleanValue*(x: SyntaxTree.Expression; VAR value: BOOLEAN): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.BooleanValue) THEN
			value :=  x.resolved(SyntaxTree.BooleanValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsBooleanValue;

	PROCEDURE IsSetValue(x: SyntaxTree.Expression; VAR value: SET): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.SetValue) THEN
			value :=  x.resolved(SyntaxTree.SetValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsSetValue;

	PROCEDURE IsStringValue(x: SyntaxTree.Expression; VAR value: Scanner.StringType): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF  (x.resolved # NIL) & (x.resolved IS SyntaxTree.StringValue) THEN
			value :=  x.resolved(SyntaxTree.StringValue).value;
			result := TRUE
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsStringValue;

	PROCEDURE Indexable(x: SyntaxTree.Type): BOOLEAN;
	BEGIN
		x := x.resolved;
		RETURN (x IS SyntaxTree.ArrayType) OR (x IS SyntaxTree.MathArrayType);
	END Indexable;

	PROCEDURE SameType(t1,t2: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN t1.SameType(t2.resolved);
	END SameType;

	PROCEDURE ArrayBase*(t: SyntaxTree.Type; max: LONGINT): SyntaxTree.Type;
	BEGIN
		IF t IS SyntaxTree.MathArrayType THEN
			WHILE (t # NIL) & (t IS SyntaxTree.MathArrayType) & ((t(SyntaxTree.MathArrayType).form # SyntaxTree.Tensor) OR (max = Infinity)) & (max > 0) DO
				t := Resolved(t(SyntaxTree.MathArrayType).arrayBase);
				IF (t # NIL) & (t IS SyntaxTree.PointerType) & (t(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.MathArrayType) THEN t := t(SyntaxTree.PointerType).pointerBase.resolved END;
				DEC(max);
			END;
		ELSIF t IS SyntaxTree.ArrayType THEN
			WHILE (t IS SyntaxTree.ArrayType) & (max > 0) DO
				t := t(SyntaxTree.ArrayType).arrayBase.resolved; DEC(max);
				IF (t IS SyntaxTree.PointerType) & (t(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType) THEN t := t(SyntaxTree.PointerType).pointerBase.resolved END;
			END;
		END;
		RETURN t;
	END ArrayBase;

	PROCEDURE IsOpenArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			RETURN TRUE;
		END;
		RETURN FALSE;
	END IsOpenArray;
	

	PROCEDURE IsStaticArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type; VAR dim :LONGINT): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			dim := type(SyntaxTree.ArrayType).staticLength;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsStaticArray;

	PROCEDURE IsDynamicArray*(type: SyntaxTree.Type; VAR base: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) THEN
			base := type(SyntaxTree.ArrayType).arrayBase;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsDynamicArray;

	PROCEDURE Dimension*(t: SyntaxTree.Type; form: SET): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		t := t.resolved;
		IF t IS SyntaxTree.MathArrayType THEN
			WHILE (t # NIL) & (t IS SyntaxTree.MathArrayType) & (t(SyntaxTree.MathArrayType).form IN form)  DO
				t := Resolved(t(SyntaxTree.MathArrayType).arrayBase); INC(i);
			END;
		ELSIF t IS SyntaxTree.ArrayType THEN
			WHILE(t IS SyntaxTree.ArrayType) & (t(SyntaxTree.ArrayType).form IN form) DO
				t := t(SyntaxTree.ArrayType).arrayBase.resolved; INC(i);
			END;
		END;
		RETURN i
	END Dimension;

	PROCEDURE IsVariable(expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		RETURN expression.assignable;
	END IsVariable;

	PROCEDURE IsVariableParameter (symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN 
		IF (symbol IS SyntaxTree.Parameter) THEN
			WITH symbol: SyntaxTree.Parameter DO
				RETURN (symbol.kind = SyntaxTree.VarParameter) OR (symbol.kind = SyntaxTree.ConstParameter) & ((symbol.type.resolved IS SyntaxTree.RecordType) OR (symbol.type.resolved IS SyntaxTree.ArrayType));
			END;
		ELSE
			RETURN FALSE
		END;
	END IsVariableParameter;

	PROCEDURE IsPointerType*(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
		type := type.resolved;
		result :=  (type IS SyntaxTree.AnyType) OR (type IS SyntaxTree.PointerType) OR (type IS SyntaxTree.NilType)  OR (type  IS SyntaxTree.ObjectType)
		END;
		RETURN result
	END IsPointerType;

	PROCEDURE IsUnsafePointer*(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
		type := type.resolved;
		result :=  (type IS SyntaxTree.PointerType) & type(SyntaxTree.PointerType).isUnsafe;
		END;
		RETURN result
	END IsUnsafePointer;
	

	PROCEDURE IsDisposable*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type # NIL) & (type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).isDisposable)
	END IsDisposable;

	PROCEDURE IsPointerToRecord(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
			type := type.resolved;
			result := (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType);
			result := result OR	(type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL);
			result := result OR (type IS SyntaxTree.ObjectType);
		END;
		RETURN result
	END IsPointerToRecord;

	PROCEDURE IsPointerToObject(type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		IF type = NIL THEN result := FALSE
		ELSE
			type := type.resolved;
			result := (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType)
				&  (type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType).isObject)
				;
			result := result OR	(type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL);
			result := result OR (type IS SyntaxTree.ObjectType);
		END;
		RETURN result
	END IsPointerToObject;

	PROCEDURE ContainsPointer*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type # NIL THEN
			RETURN type.resolved.hasPointers
		ELSE
			RETURN FALSE
		END;
	END ContainsPointer;

	PROCEDURE IsStringType*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.StringType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType);
	END IsStringType;

	PROCEDURE IsCharacterType*(type: SyntaxTree.Type):BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.CharacterType) OR (type IS SyntaxTree.ByteType) OR (type IS SyntaxTree.StringType) & (type(SyntaxTree.StringType).length = 2)
	END IsCharacterType;

	PROCEDURE IsEnumerationType*(type: SyntaxTree.Type):BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.EnumerationType)
	END IsEnumerationType;


	(** cf. section "Type extension (base type)" in the language report **)
	PROCEDURE IsTypeExtension(base,extension: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		ASSERT(base # NIL); ASSERT(extension # NIL);
		base := base.resolved; extension := extension.resolved;

		IF ( (base IS SyntaxTree.ObjectType) OR  (base IS SyntaxTree.AnyType)) & IsPointerToRecord(extension) THEN
			result := TRUE;
		ELSE
			IF (base IS SyntaxTree.PointerType) & (extension IS SyntaxTree.PointerType) THEN
				base := base(SyntaxTree.PointerType).pointerBase.resolved;
				extension := extension(SyntaxTree.PointerType).pointerBase.resolved;
			END;

			WHILE (extension # NIL) & (extension # base) DO
				IF extension IS SyntaxTree.RecordType THEN
					extension := extension(SyntaxTree.RecordType).baseType;
					IF (extension # NIL) THEN extension := extension.resolved END;
					IF (extension # NIL) & (extension IS SyntaxTree.PointerType) THEN
						extension := extension(SyntaxTree.PointerType).pointerBase.resolved;
					END;
				ELSE extension := NIL;
				END;
			END;
			result :=  (extension = base) & (extension IS SyntaxTree.RecordType);
		END;
		RETURN result
	END IsTypeExtension;

	(** check if base is the base enumeration type of extension **)
	PROCEDURE IsEnumerationExtension(base,extension: SyntaxTree.Type): BOOLEAN;
	BEGIN
		base := base.resolved; extension := extension.resolved;

		WHILE (extension # NIL) & (extension # base) DO
			IF extension IS SyntaxTree.EnumerationType THEN
				extension := extension(SyntaxTree.EnumerationType).enumerationBase;
				IF extension # NIL THEN extension := extension.resolved END;
			ELSE
				extension := NIL
			END;
		END;
		RETURN (extension = base) & (base IS SyntaxTree.EnumerationType);
	END IsEnumerationExtension;

	PROCEDURE IsCallable(expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF expression IS SyntaxTree.ProcedureCallDesignator THEN
			RETURN TRUE
		ELSIF expression IS SyntaxTree.BuiltinCallDesignator THEN
			RETURN TRUE
		ELSIF (expression.type # NIL) & (expression.type.resolved IS SyntaxTree.ProcedureType) THEN
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END IsCallable;


	(** compute and return the distance of two record types
		returns the number of extension levels of from to to, returns infinite if to is not an extension of from
	**)
	PROCEDURE RecordTypeDistance(from, to: SyntaxTree.RecordType): LONGINT;
	VAR i: LONGINT; baseType: SyntaxTree.Type;
	BEGIN
		i := 0;
		WHILE (from # NIL) & (from # to) DO
			baseType :=  from.baseType;
			IF (baseType # NIL) THEN
				baseType := baseType.resolved;
				IF baseType IS SyntaxTree.PointerType THEN
					baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved;
				END;
				IF baseType IS SyntaxTree.RecordType THEN
					from := baseType(SyntaxTree.RecordType);
				ELSE
					from := NIL;
				END;
			ELSE
				from := NIL
			END;
			INC(i)
		END;
		IF from = NIL THEN  i := Infinity  END;
		RETURN i
	END RecordTypeDistance;

	(** compute and return the distance of two pointer types **)
	PROCEDURE PointerTypeDistance(from, to: SyntaxTree.PointerType): LONGINT;
	BEGIN
		IF ~((to.pointerBase.resolved IS SyntaxTree.RecordType) & (from.pointerBase.resolved IS SyntaxTree.RecordType)) THEN
			RETURN Infinity;
		ELSE
			RETURN RecordTypeDistance(from.pointerBase.resolved(SyntaxTree.RecordType), to.pointerBase.resolved(SyntaxTree.RecordType));
		END;
	END PointerTypeDistance;

	(** check if expression contains a symbol designator pointing to a type declaration.
		- if so then enter type declaration into typeDeclaration and return true else return false
	**)
	PROCEDURE IsTypeDesignator(expression: SyntaxTree.Expression; VAR typeDeclaration: SyntaxTree.TypeDeclaration): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		result := FALSE;
		IF (expression # NIL) & (expression.type.resolved = SyntaxTree.typeDeclarationType) THEN
			result := TRUE;
			typeDeclaration := expression(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration)
		END;
		RETURN result
	END IsTypeDesignator;

	(** returns true if type is an extensible type (pointer to record, record, object or any), returns false otherwise **)
	PROCEDURE IsExtensibleType( type: SyntaxTree.Type): BOOLEAN;
	VAR result: BOOLEAN;
	BEGIN
		type := type.resolved;
		IF type IS SyntaxTree.PointerType THEN
			result := IsExtensibleType(type(SyntaxTree.PointerType).pointerBase.resolved);
		ELSIF (type IS SyntaxTree.AnyType) OR (type IS SyntaxTree.ObjectType)  THEN
			result := TRUE
		ELSE
			result := type IS SyntaxTree.RecordType
		END;
		RETURN result
	END IsExtensibleType;

	PROCEDURE IsUnextensibleRecord(d: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		RETURN (d.type.resolved IS SyntaxTree.RecordType) &
			(d IS SyntaxTree.SymbolDesignator) &
			( (d(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable)
			OR
			(d(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) & (d(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter).kind = SyntaxTree.ValueParameter));

	END IsUnextensibleRecord;

	PROCEDURE IsExtensibleDesignator(d: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		IF IsUnextensibleRecord(d) THEN
			RETURN FALSE
		ELSE RETURN IsExtensibleType(d.type.resolved)
		END;
	END IsExtensibleDesignator;

	PROCEDURE IsBasicType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		IF (type IS SyntaxTree.PointerType) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL) (* object *) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.ProcedureType) THEN
			RETURN TRUE
		ELSIF (type IS SyntaxTree.BasicType) THEN
			RETURN TRUE
		END;
		RETURN FALSE
	END IsBasicType;

	PROCEDURE RecordBase*(record: SyntaxTree.RecordType): SyntaxTree.RecordType;
	VAR baseType: SyntaxTree.Type; recordType: SyntaxTree.RecordType;
	BEGIN
		baseType := record.baseType;
		IF (baseType # NIL) THEN
			baseType := baseType.resolved;
			IF  (baseType IS SyntaxTree.PointerType) THEN
				baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved;
			END;
		END;
		IF (baseType # NIL) & (baseType IS SyntaxTree.RecordType) THEN
			recordType := baseType(SyntaxTree.RecordType);
		ELSE
			recordType := NIL;
		END;
		RETURN recordType
	END RecordBase;

	PROCEDURE FindSuperProcedure*(scope: SyntaxTree.RecordScope; procedure: SyntaxTree.Procedure): SyntaxTree.Procedure;
	VAR super: SyntaxTree.Procedure; operator: SyntaxTree.Operator; procedureType: SyntaxTree.Type; baseRecord: SyntaxTree.RecordType;
	BEGIN
		baseRecord := RecordBase(scope.ownerRecord);
		IF baseRecord = NIL THEN RETURN NIL END;
		scope := baseRecord.recordScope;
		procedureType := procedure.type.resolved;

		IF procedure IS SyntaxTree.Operator THEN
			operator := scope.firstOperator;
			WHILE (operator # NIL) & ((operator.name # procedure.name) OR ~SameType(procedureType, operator.type)) DO
				(*
				Printout.Info("not same ",procedureType);
				Printout.Info("with ",operator.type);
				*)
				operator := operator.nextOperator;
			END;
			super := operator;
		ELSE
			super := scope.firstProcedure;
			WHILE (super # NIL) & (super.name # procedure.name) DO
				super := super.nextProcedure;
			END;
		END;
		IF (super # NIL) & ((super.scope.ownerModule = procedure.scope.ownerModule) OR (SyntaxTree.Public * super.access # {})) THEN
			RETURN super
		ELSIF (super # NIL) & (FindSuperProcedure(scope,procedure)#NIL) THEN (* check if there is an exported supermethod, in which case return (non-exported) supermethod *)
			RETURN super
		ELSE
			RETURN FindSuperProcedure(scope,procedure);
		END;
	END FindSuperProcedure;

	PROCEDURE GetConstructor(record: SyntaxTree.RecordType): SyntaxTree.Procedure;
	VAR procedure: SyntaxTree.Procedure;
	BEGIN
		procedure := record.recordScope.constructor;
		IF procedure = NIL THEN
			record := RecordBase(record);
			IF record # NIL THEN
				procedure := GetConstructor(record)
			END;
		END;
		RETURN procedure;
	END GetConstructor;

	(* enter a case into a list of cases in a sorted way and check for collision *)
	PROCEDURE EnterCase(VAR root: SyntaxTree.CaseConstant; min,max: LONGINT): BOOLEAN;
	VAR prev,this,new: SyntaxTree.CaseConstant;
	BEGIN
		this := root;
		prev := NIL;
		WHILE (this # NIL) & (min > this.max) DO  prev := this; this := this.next  END;
		IF (this # NIL) & (max >= this.min) THEN	(* collision since min <=  this.max and max >= this.min *)
			RETURN FALSE
		ELSE
			IF (this # NIL) & (this.min = max+1) THEN
				this.min := min
			ELSIF (prev # NIL) & (min+1 = prev.max) THEN
				prev.max := min
			ELSE
				NEW(new);  new.min := min; new.max := max;
				new.next := this;
				IF prev = NIL THEN
					root := new;
				ELSE
					prev.next := new
				END
			END;
			RETURN TRUE
		END;
	END EnterCase;

	(** generate and return a new checker object, errors are entered into diagnostics **)
	PROCEDURE NewChecker*(diagnostics: Diagnostics.Diagnostics; verboseErrorMessage,useDarwinCCalls,cooperative: BOOLEAN; system: Global.System; symbolFileFormat: Formats.SymbolFileFormat; VAR importCache: SyntaxTree.ModuleScope): Checker;
	VAR checker: Checker;
	BEGIN
		NEW(checker, diagnostics,verboseErrorMessage,useDarwinCCalls,cooperative,system,symbolFileFormat,importCache);
		RETURN checker
	END NewChecker;

	PROCEDURE NewWarnings*(diagnostics: Diagnostics.Diagnostics): Warnings;
	VAR warnings: Warnings;
	BEGIN
		NEW(warnings, diagnostics); RETURN warnings;
	END NewWarnings;

	PROCEDURE IsRangeType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.RangeType);
	END IsRangeType;

	PROCEDURE IsMathArrayType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.MathArrayType);
	END IsMathArrayType;

	PROCEDURE IsArrayType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.ArrayType);
	END IsArrayType;

	PROCEDURE IsComplexType(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.ComplexType);
	END IsComplexType;

	(** if a type is an array-structured object type *)
	PROCEDURE IsArrayStructuredObjectType*(type: SyntaxTree.Type): BOOLEAN;
	VAR recordType: SyntaxTree.RecordType;
	BEGIN
		IF type = NIL THEN
			RETURN FALSE
		ELSE
			type := type.resolved;
			IF type IS SyntaxTree.PointerType THEN
				type := type(SyntaxTree.PointerType).pointerBase.resolved;
				IF type IS SyntaxTree.RecordType THEN
					recordType := type(SyntaxTree.RecordType);
					RETURN recordType.isObject & recordType.HasArrayStructure()
				ELSE
					RETURN FALSE
				END
			ELSE
				RETURN FALSE
			END
		END
	END IsArrayStructuredObjectType;

	(** the math array structure of a type
		- for math arrays: the array itself
		- for pointers: the math array structure of the pointer base
		- for array-structured object types: the underlying structure
		- for non-math arrays and all other types: NIL
	**)
	PROCEDURE MathArrayStructureOfType(type: SyntaxTree.Type): SyntaxTree.MathArrayType;
	VAR
		result: SyntaxTree.MathArrayType;
	BEGIN
		IF type = NIL THEN
			result := NIL
		ELSE
			type := type.resolved;
			IF type IS SyntaxTree.PointerType THEN
				type := type(SyntaxTree.PointerType).pointerBase.resolved;
			END;
			IF type IS SyntaxTree.MathArrayType THEN
				result := type(SyntaxTree.MathArrayType)
			ELSIF type IS SyntaxTree.RecordType THEN
				result := type(SyntaxTree.RecordType).arrayStructure
			ELSE
				result := NIL
			END
		END;
		RETURN result
	END MathArrayStructureOfType;

	PROCEDURE IsStaticRange(x: SyntaxTree.Expression; VAR firstValue, lastValue, stepValue: LONGINT): BOOLEAN;
	VAR
		result: BOOLEAN;
		rangeExpression: SyntaxTree.RangeExpression;
	BEGIN
		IF x IS SyntaxTree.RangeExpression THEN
			rangeExpression := x(SyntaxTree.RangeExpression);
			result := TRUE;
			IF ~IsIntegerValue(rangeExpression.first, firstValue) THEN result := FALSE END;
			IF ~IsIntegerValue(rangeExpression.last, lastValue) THEN result := FALSE END;
			IF ~IsIntegerValue(rangeExpression.step, stepValue) THEN result := FALSE END
		ELSE
			result := FALSE
		END;
		RETURN result
	END IsStaticRange;

	(** whether a type is a math array of tensor form **)
	PROCEDURE IsTensor(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type.resolved IS SyntaxTree.MathArrayType) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor)
	END IsTensor;


	PROCEDURE IsStaticMathArray*(type: SyntaxTree.Type; VAR length: LONGINT; VAR baseType: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static) THEN
			length := type(SyntaxTree.MathArrayType).staticLength;
			baseType := type(SyntaxTree.MathArrayType).arrayBase.resolved;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsStaticMathArray;


	PROCEDURE SymbolHasAddress(symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN
		RETURN (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) OR (symbol IS SyntaxTree.Procedure)
	END SymbolHasAddress;


	PROCEDURE HasAddress(expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN
		RETURN (expression # NIL) & (expression IS SyntaxTree.SymbolDesignator) & SymbolHasAddress(expression(SyntaxTree.SymbolDesignator).symbol) OR (expression IS SyntaxTree.ResultDesignator)
			OR (expression IS SyntaxTree.IndexDesignator) OR (expression IS SyntaxTree.DereferenceDesignator)
			OR (expression IS SyntaxTree.TypeGuardDesignator) OR (expression IS SyntaxTree.StringValue)
			OR (expression IS SyntaxTree.StatementDesignator) & HasAddress(expression(SyntaxTree.StatementDesignator).result);
	END HasAddress;
	
	PROCEDURE IsLocalVariable*(e: SyntaxTree.Expression): BOOLEAN;
	VAR d: SyntaxTree.Designator; symbol: SyntaxTree.Symbol;
	BEGIN
		IF (e IS SyntaxTree.Designator) THEN
			d := e(SyntaxTree.Designator);
			WHILE (d # NIL) & ~(d IS SyntaxTree.SymbolDesignator) DO
				IF d IS SyntaxTree.DereferenceDesignator THEN (* on heap *) RETURN FALSE END;
				e := d.left;
				IF (e # NIL) & (e IS SyntaxTree.Designator) THEN d := e(SyntaxTree.Designator) ELSE d := NIL END;
			END;
			IF d # NIL THEN
				symbol := d(SyntaxTree.SymbolDesignator).symbol;
				RETURN (symbol.scope IS SyntaxTree.ProcedureScope) & (symbol.externalName = NIL);
			END;
		END;
		RETURN FALSE;
	END IsLocalVariable;

	PROCEDURE IsStaticProcedure*(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		IF procedure.scope IS SyntaxTree.RecordScope THEN
			RETURN (procedure.super = NIL) & ((procedure.isFinal) OR (procedure.access * SyntaxTree.Public = {}) & ~procedure.isOverwritten)
		ELSE
			RETURN TRUE
		END;
	END IsStaticProcedure;

	PROCEDURE InMethodTable*(procedure: SyntaxTree.Procedure): BOOLEAN;
	CONST OptimizeMethodTable = FALSE;
	BEGIN
		RETURN ~OptimizeMethodTable OR IsStaticProcedure(procedure)
	END InMethodTable;

END FoxSemanticChecker.
