MODULE FoxBinarySymbolFile; (** AUTHOR "fof"; PURPOSE "Symbol File - Binary Format"; *)

IMPORT
	 Basic := FoxBasic, Scanner := FoxScanner,  SyntaxTree := FoxSyntaxTree, Global := FoxGlobal,
	 Files,Streams, Kernel, SYSTEM, D := Debugging,  Diagnostics, Options, Formats := FoxFormats, InterfaceComparison := FoxInterfaceComparison
	 ,Commands, Printout := FoxPrintout, SemanticChecker := FoxSemanticChecker,
	 Machine
	 ;

(** Symbol File Format

	SymbolFile    = codeOptions:RawSet
	                Imports
	                [sfSysFlag sysFlags:RawNum]
	                [sfConst {Symbol Value}]
	                [sfVar {Symbol}]
	                [sfXProcedure {Symbol ParameterList}]
	                [sfOperator {Symbol ParameterList [sfInline Inline]}]
	                [sfCProcedure {Symbol ParameterList Inline}]
	                [sfAlias {Type name:RawString}]
	                [sfType {Type}]
	                sfEnd.

	Imports       = {moduleName:RawString} 0X

	Symbol        = [sfObjFlag flag:RawNum] [sfReadOnly]
	                Type name:RawString

	Value         = [ RawNum | RawHInt | RawReal | RawLReal | RawString ]

	Type          = TypeReference
	                | BasicType
	                | ImportedType
	                | UserType.

	TypeReference = number<0:RawNum

	BasicType     = sfTypeBoolean |  .. |  sfLastType.

	ImportedType  = ModuleNumber (structName:RawString | 0X typeIndex:RawNum)

	ModuleNumber  = sfMod1 | .. | sfModOther-1 | sfModOther moduleNumber:RawNum

	UserType      = [sfInvisible] [sfSysFlag sysFlag:RawNum] UserType2

	UserType2     =  sfTypeOpenArray baseType:Type name:RawString
	                 | sfTypeStaticArray  baseType:Type name:RawString length:RawNum
	                 | sfTypePointer baseType:Type name:RawString
	                 | sfTypeRecord baseType:Type name:RawString Record
	                 | sfTypeProcedure baseType:Type name:RawString flags:RawNum
	                   ParameterList

	Record        =  mode:RawNum priority:Char {variable:Symbol}
	                 [sfTProcedure {Symbol [name:RawString] ParameterList [sfInline Inline]} ]
	                 sfEnd.

	ParameterList = {
	                [sfObjflag ( sfCParam | sfDarwinCParam | sfWinAPIParam )]
	                [sfVar] [sfReadOnly] Type name:RawString
	                } sfEnd.

	Inline        = {len:Char {c:Char}} 0X.

*)


CONST
		TraceImport=0;
		TraceExport=1;
		Trace = {} ;

		(* FoxProgTools.Enum --start=1 sfTypeBoolean sfTypeChar8 sfTypeChar16 sfTypeChar32
		sfTypeShortint sfTypeInteger sfTypeLongint sfTypeHugeint sfTypeReal sfTypeLongreal sfTypeSet
		sfTypeString sfTypeNoType sfTypeNilType sfTypeByte sfTypeSptr sfMod1 ~

		FoxProgTools.Enum --start=2DH --hex sfModOther  sfTypeOpenArray sfTypeStaticArray sfTypePointer sfTypeRecord sfTypeProcedure
		sfSysFlag sfInvisible sfReadOnly sfObjFlag sfConst sfVar sfLProcedure sfXProcedure sfOperator sfTProcedure sfCProcedure sfAlias sfType sfEnd ~
		*)

		sfTypeBoolean= 1;
		sfTypeChar8= 2;
		sfTypeChar16= 3;
		sfTypeChar32= 4;
		sfTypeShortint= 5;
		sfTypeInteger= 6;
		sfTypeLongint= 7;
		sfTypeHugeint =   8;
		sfTypeReal =   9;
		sfTypeLongreal =  10;
		sfTypeSet =  11;
		sfTypeString =  12;
		sfTypeNoType =  13;
		sfTypeNilType =  14;
		sfTypeByte =  15;
		sfTypeAny =  16;
		sfTypeObject = 17;
		sfTypeAddress= 18;
		sfTypeSize = 19;
		sfTypeUnsigned8=20;
		sfTypeUnsigned16=21;
		sfTypeUnsigned32=22;
		sfTypeUnsigned64=23;

		sfLastType = 23;
		sfMod1 =  sfLastType+1;

		sfModOther=2DH;
		sfTypeOpenArray=2EH;
		(*
		sfTypeDynamicArray=2FH;
		*)
		sfTypeStaticArray=30H;
		sfTypePointer=31H;
		sfTypeRecord=32H;
		sfTypeProcedure=33H;
		sfSysFlag=34H;
		sfInvisible=35H;
		sfReadOnly=36H;
		sfObjFlag = 37H; (* fof: very (!) bad idea to have same number for two type flags *)
		sfConst=37H;
		sfVar=38H;
		sfTypeEnumeration=39H;
		(*
		sfLProcedure=39H;
		*)
		sfXProcedure=3AH;
		sfOperator=3BH;
		sfTProcedure=3CH;
		sfCProcedure = sfTProcedure;
		sfAlias=3DH;
		sfType=3EH;
		sfEnd= 3FH;
		sfTypeOpenMathArray = 40H;
		sfTypeTensor=42H;
		sfTypeStaticMathArray = 43H;
		sfTypeAll = 44H;
		sfTypeRange = 45H;
		sfTypeComplex = 46H;
		sfTypeLongcomplex = 47H;


		(* workaround: handle inlined operators *)
		sfInline = 0ABH;

		sfProtected = 0;
		sfActive=1;
		sfSafe=2;
		sfClass=16;
		sfDelegate = 5;
		sfUntraced = 4;
		sfWinAPIParam = 13; (* ejz *)
		sfCParam= 14; (* fof for linux *)
		sfDarwinCParam= 15; (* fld for darwin *)
		sfRealtime= 21;
		sfDynamic = 22;
		sfUnsafe= 23;
		sfDisposable= 24;

		Undef=MIN(LONGINT);

CONST
		FileTag = 0BBX;				(* same constants are defined in Linker and AosLoader *)
		NoZeroCompress = 0ADX;		(* do. *)
		FileVersion* = 0B1X;			(* do. *)
		FileVersionOC*=0B2X;
		FileVersionCurrent*=0B4X;
TYPE
	(* TypeReference provides a link between a type and a number for the purpose of late fixes while importing.
		When a type number is encountered while importing, a type reference will be used as a placeholder for the final type.
		After the import process has collected all types, the references are replaced by the referenced types (cf. Resolver Object) *)
	TypeReference = OBJECT (SyntaxTree.Type)
		VAR nr: LONGINT;

		PROCEDURE & InitTypeReference(nr: LONGINT);
		BEGIN
			InitType(-1); SELF.nr := nr;
		END InitTypeReference;

	END TypeReference;

	(* IndexToType provides a link between numbers and a type. Lists like this are typically filled while importing and provide the base
		for the type resolving, cf. Resolver below
	 *)
	IndexToType= OBJECT(Basic.List)

		PROCEDURE PutType(nr: LONGINT; type: SyntaxTree.Type);
		BEGIN GrowAndSet(nr,type);
		END PutType;

		PROCEDURE GetType(nr: LONGINT): SyntaxTree.Type;
		VAR node: ANY;
		BEGIN node := Get(nr); IF node = NIL THEN RETURN NIL ELSE RETURN node(SyntaxTree.Type) END;
		END GetType;

	END IndexToType;


	LateFix= POINTER TO RECORD (* contains a late fix to be resolved in a later step: type fixes and implementations *)
		p: ANY; (*scope: SyntaxTree.Scope;*)
		next: LateFix;
	END;

	LateFixList = OBJECT (* fifo queue for items to be resolved later on - deferred fixes *)
	VAR first,last: LateFix;

		PROCEDURE & Init;
		BEGIN first := NIL; last := NIL;
		END Init;

		(* get and remove element from list *)
		PROCEDURE Get((*VAR scope: SyntaxTree.Scope*)): ANY;
		VAR p: ANY;
		BEGIN
			IF first # NIL THEN p := first.p; (*scope := first.scope;*) first := first.next ELSE p := NIL; END;
			IF first = NIL THEN last := NIL END;
			RETURN p;
		END Get;

		(* add unresolved type to list *)
		PROCEDURE Add(p: ANY (*; scope: SyntaxTree.Scope*));
		VAR next: LateFix;
		BEGIN
			(*ASSERT(scope # NIL);*)
			NEW(next); next.p := p; (* next.scope := scope;*)
			next.next := NIL;
			IF first = NIL THEN first := next; last := next;
			ELSE last.next := next; last := next
			END;
		END Add;

	END LateFixList;


	(*
		The resolver object is used to replace type references in a SyntaxTree.Module tree with the respective types from a given type list.
		To do so, the resolver traverses the module tree partially with direct procedural recursion and partially using the visitor pattern.
	*)
	Resolver=OBJECT (SyntaxTree.Visitor)
	VAR typeList: IndexToType; system: Global.System; typeFixes: LateFixList;

		checker: SemanticChecker.Checker;

		PROCEDURE & Init(system: Global.System; symbolFile: BinarySymbolFile; importCache: SyntaxTree.ModuleScope);
		VAR streamDiagnostics: Diagnostics.StreamDiagnostics;
		BEGIN
			typeList := NIL; SELF.system := system; NEW(typeFixes);
			NEW(streamDiagnostics, D.Log);
			checker := SemanticChecker.NewChecker(streamDiagnostics,FALSE,FALSE,TRUE,system,symbolFile,importCache);
		END Init;

		(* types that do not refer to other types *)

		PROCEDURE VisitType(x: SyntaxTree.Type);
		BEGIN END VisitType;

		PROCEDURE VisitBasicType(x: SyntaxTree.BasicType);
		BEGIN END VisitBasicType;

		PROCEDURE VisitByteType(x: SyntaxTree.ByteType);
		BEGIN END VisitByteType;

		PROCEDURE VisitBooleanType(x: SyntaxTree.BooleanType);
		BEGIN END VisitBooleanType;

		PROCEDURE VisitSetType(x: SyntaxTree.SetType);
		BEGIN END VisitSetType;

		PROCEDURE VisitAddressType(x: SyntaxTree.AddressType);
		BEGIN END VisitAddressType;

		PROCEDURE VisitSizeType(x: SyntaxTree.SizeType);
		BEGIN END VisitSizeType;

		PROCEDURE VisitAnyType(x: SyntaxTree.AnyType);
		BEGIN END VisitAnyType;

		PROCEDURE VisitObjectType(x: SyntaxTree.ObjectType);
		BEGIN END VisitObjectType;

		PROCEDURE VisitNilType(x: SyntaxTree.NilType);
		BEGIN END VisitNilType;

		PROCEDURE VisitCharacterType(x: SyntaxTree.CharacterType);
		BEGIN END VisitCharacterType;

		PROCEDURE VisitIntegerType(x: SyntaxTree.IntegerType);
		BEGIN END VisitIntegerType;

		PROCEDURE VisitFloatType(x: SyntaxTree.FloatType);
		BEGIN END VisitFloatType;

		PROCEDURE VisitComplexType(x: SyntaxTree.ComplexType);
		BEGIN END VisitComplexType;

		PROCEDURE VisitQualifiedType(x: SyntaxTree.QualifiedType);
		BEGIN
			x.SetResolved(ResolveType(x.resolved))
		END VisitQualifiedType;

		PROCEDURE VisitStringType(x: SyntaxTree.StringType);
		BEGIN END VisitStringType;

		PROCEDURE VisitRangeType(x: SyntaxTree.RangeType);
		BEGIN END VisitRangeType;

		(* types containing links to other types *)

		(**
			check enumeration scope: enter symbols and check for duplicate names
		**)
		PROCEDURE CheckEnumerationScope(x: SyntaxTree.EnumerationScope);
		VAR e: SyntaxTree.Constant; lowest, highest,value: LONGINT;
		BEGIN
			lowest := 0; highest := 0;
			e := x.firstConstant;
			WHILE (e # NIL) DO
				e.SetType(x.ownerEnumeration);
				e.SetState(SyntaxTree.Resolved);
				value := e.value(SyntaxTree.EnumerationValue).value;
				IF value < lowest THEN lowest := value END;
				IF value > highest THEN highest := value END;
				e := e.nextConstant;
			END;
			x.ownerEnumeration.SetRange(lowest,highest);
		END CheckEnumerationScope;

		(**
			resolve enumeration type: check enumeration scope
		**)
		PROCEDURE VisitEnumerationType(x: SyntaxTree.EnumerationType);
		VAR baseScope: SyntaxTree.EnumerationScope; resolved: SyntaxTree.Type; enumerationBase: SyntaxTree.EnumerationType;
		BEGIN
			x.SetEnumerationBase(ResolveType(x.enumerationBase));
			IF x.enumerationBase # NIL THEN
				resolved := x.enumerationBase.resolved;
				enumerationBase := resolved(SyntaxTree.EnumerationType);
				baseScope := enumerationBase.enumerationScope;
			END;
			CheckEnumerationScope(x.enumerationScope);
			x.SetState(SyntaxTree.Resolved);
		END VisitEnumerationType;

		PROCEDURE VisitArrayType(arrayType: SyntaxTree.ArrayType);
		BEGIN
			ASSERT(arrayType.arrayBase # NIL);
			arrayType.SetArrayBase(ResolveType(arrayType.arrayBase));
			arrayType.SetHasPointers(arrayType.arrayBase.resolved.hasPointers);
			arrayType.SetState(SyntaxTree.Resolved);
		END VisitArrayType;

		PROCEDURE VisitMathArrayType(arrayType: SyntaxTree.MathArrayType);
		BEGIN
			arrayType.SetArrayBase(ResolveType(arrayType.arrayBase));
			IF arrayType.form = SyntaxTree.Static THEN
				arrayType.SetIncrement(system.SizeOf(arrayType.arrayBase));
				arrayType.SetHasPointers(arrayType.arrayBase.resolved.hasPointers);
			ELSE
				arrayType.SetHasPointers(TRUE)
			END;
			arrayType.SetState(SyntaxTree.Resolved);
		END VisitMathArrayType;

		PROCEDURE VisitPointerType(pointerType: SyntaxTree.PointerType);
		VAR recordType: SyntaxTree.RecordType;
		BEGIN
			IF ~(SyntaxTree.Resolved IN pointerType.state) THEN
				typeFixes.Add(pointerType);
				pointerType.SetState(SyntaxTree.Resolved);
			END;
			(*
			pointerType.SetPointerBase(ResolveType(pointerType.pointerBase));

			IF pointerType.pointerBase.resolved IS SyntaxTree.RecordType THEN
				recordType := pointerType.pointerBase.resolved(SyntaxTree.RecordType);
				IF (recordType.typeDeclaration = NIL) THEN
					recordType.SetPointerType(pointerType);
					recordType.SetTypeDeclaration(pointerType.typeDeclaration)
				END;
			END;

			pointerType.SetState(SyntaxTree.Resolved);
			*)
		END VisitPointerType;

		PROCEDURE FixPointerType(pointerType: SyntaxTree.PointerType);
		VAR recordType: SyntaxTree.RecordType;
		BEGIN
			pointerType.SetPointerBase(ResolveType(pointerType.pointerBase));

			IF pointerType.pointerBase.resolved IS SyntaxTree.RecordType THEN
				recordType := pointerType.pointerBase.resolved(SyntaxTree.RecordType);
				IF (recordType.typeDeclaration = NIL) THEN
					recordType.SetPointerType(pointerType);
					recordType.SetTypeDeclaration(pointerType.typeDeclaration)
				END;
			END;

		END FixPointerType;



		PROCEDURE VisitRecordType(recordType: SyntaxTree.RecordType);
		VAR recordBase: SyntaxTree.RecordType; numberMethods: LONGINT; procedure,super,testsuper: SyntaxTree.Procedure; recordScope: SyntaxTree.RecordScope;
			pointerType: SyntaxTree.Type; typeDeclaration: SyntaxTree.TypeDeclaration; symbol: SyntaxTree.Symbol; size: HUGEINT; hasPointer: BOOLEAN;
			var: SyntaxTree.Variable;
		BEGIN
			recordType.SetBaseType(ResolveType(recordType.baseType));

			recordScope := recordType.recordScope;
			recordBase := recordType.GetBaseRecord();
			hasPointer := FALSE;
			IF recordBase = NIL THEN numberMethods := 0;
			ELSE
				recordBase.Accept(SELF); numberMethods := recordBase.recordScope.numberMethods;
			END;
			symbol := recordScope.firstSymbol; (* must use the sorted list here, important! *)
			WHILE symbol # NIL DO
				IF (symbol IS SyntaxTree.Procedure) THEN
					procedure := symbol(SyntaxTree.Procedure);
					IF procedure IS SyntaxTree.Operator THEN FixProcedureType(procedure.type(SyntaxTree.ProcedureType)) END;
					super := SemanticChecker.FindSuperProcedure(recordScope, procedure);
					procedure.SetSuper(super);
					IF super # NIL THEN
						procedure.SetAccess(procedure.access+super.access);
					END;

					IF procedure.super # NIL THEN
						procedure.SetMethodNumber(procedure.super.methodNumber)
					ELSE
						procedure.SetMethodNumber(numberMethods);
						INC(numberMethods);
					END;
				END;
				symbol := symbol.nextSymbol;
			END;

			recordScope.SetNumberMethods(numberMethods);

			IF (recordScope.firstProcedure # NIL) OR (recordBase # NIL) & (recordBase.isObject) THEN
				recordType.IsObject(TRUE)
			END;

			IF (recordBase # NIL) &  recordBase.hasPointers THEN hasPointer := TRUE END;

			Scope(recordType.recordScope);
			var := recordType.recordScope.firstVariable;
			WHILE var # NIL DO
				hasPointer := hasPointer OR var.type.resolved.hasPointers & ~var.untraced;
				var := var.nextVariable;
			END;
			recordType.SetHasPointers(hasPointer);

			checker.SetCurrentScope(recordType.recordScope);
			checker.ResolveArrayStructure(recordType);

			recordType.SetState(SyntaxTree.Resolved);
			size := system.SizeOf(recordType); (* generate field offsets *)

			IF (recordType.typeDeclaration = NIL) & (recordType.pointerType # NIL) THEN
				pointerType := recordType.pointerType.resolved;
				typeDeclaration := pointerType.typeDeclaration;
				recordType.SetTypeDeclaration(typeDeclaration);
			END;
		END VisitRecordType;


		PROCEDURE VisitProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR parameter: SyntaxTree.Parameter;
		BEGIN
			IF ~(SyntaxTree.Resolved IN procedureType.state) THEN
				typeFixes.Add(procedureType);
				IF procedureType.isDelegate THEN
					procedureType.SetHasPointers(TRUE);
				END;
				procedureType.SetState(SyntaxTree.Resolved);
			END;
		END VisitProcedureType;


		PROCEDURE FixProcedureType(procedureType: SyntaxTree.ProcedureType);
		VAR parameter: SyntaxTree.Parameter; returnType: SyntaxTree.Type;
		BEGIN
			(* parameter list *)
			parameter := procedureType.firstParameter;
			WHILE(parameter # NIL) DO
				parameter.SetType(ResolveType(parameter.type));
				parameter := parameter.nextParameter;
			END;
			(* return type *)
			returnType := ResolveType(procedureType.returnType);
			procedureType.SetReturnType(ResolveType(returnType));
			IF returnType# NIL THEN
				parameter := SyntaxTree.NewParameter(-1,procedureType,Global.ReturnParameterName,SyntaxTree.VarParameter);
				parameter.SetType(returnType);
				parameter.SetState(SyntaxTree.Resolved);
				procedureType.SetReturnParameter(parameter);
			END;
		END FixProcedureType;

		(* a type reference is resolved by replacing it with the respective element of the type list, all other types remain *)
		PROCEDURE ResolveType(type: SyntaxTree.Type): SyntaxTree.Type;
		BEGIN
			IF type = NIL THEN RETURN NIL
			ELSIF (type IS TypeReference) THEN
				type :=  typeList.GetType(type(TypeReference).nr);
			END;
			IF ~(SyntaxTree.Resolved IN type.state)  THEN
				type.Accept(SELF);
				type.SetState(SyntaxTree.Resolved);
			END;
			RETURN type;
		END ResolveType;

		(** resolve all pending types (late resolving).
			- type fixes are resolved at the end of the declaration phase
			- type fixes may imply new type fixes that are also entered at the end of the list
		**)
		PROCEDURE FixTypes;
		VAR p: ANY; prevScope: SyntaxTree.Scope;
		BEGIN
			(*prevScope := currentScope;*)
			p := typeFixes.Get((*currentScope*));
			WHILE p # NIL DO
				ASSERT(p IS SyntaxTree.Type);

				IF p IS SyntaxTree.PointerType THEN
					FixPointerType(p(SyntaxTree.PointerType))
				ELSIF p IS SyntaxTree.ProcedureType THEN
					FixProcedureType(p(SyntaxTree.ProcedureType))
				ELSE
					HALT(100);
				END;
				p := typeFixes.Get((*currentScope*));
			END;
			(*currentScope :=prevScope;*)
		END FixTypes;

		(* scope traversal *)
		PROCEDURE Scope(scope: SyntaxTree.Scope);
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; variable: SyntaxTree.Variable; procedure: SyntaxTree.Procedure;
		BEGIN
			(* type declarations *)
			typeDeclaration := scope.firstTypeDeclaration;
			WHILE(typeDeclaration # NIL) DO
				typeDeclaration.SetDeclaredType(ResolveType(typeDeclaration.declaredType));
				IF ~(typeDeclaration.declaredType IS SyntaxTree.BasicType) THEN
					typeDeclaration.declaredType.SetTypeDeclaration(typeDeclaration);
				END;
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
			(* variables *)
			variable := scope.firstVariable;
			WHILE(variable # NIL) DO
				variable.SetType(ResolveType(variable.type));
				ASSERT (~(variable.type IS TypeReference));
				ASSERT(~(variable.type.resolved IS TypeReference));
				variable := variable.nextVariable;
			END;
			(* procedures *)
			procedure := scope.firstProcedure;
			WHILE(procedure # NIL) DO
				Scope(procedure.procedureScope);
				procedure.SetType(ResolveType(procedure.type));
				procedure := procedure.nextProcedure;
			END;
		END Scope;

		(* replace all TypeReferences in module by referenced types in typeList *)
		PROCEDURE Resolve(module: SyntaxTree.Module; typeList: IndexToType);
		BEGIN
			SELF.typeList := typeList;
			Scope(module.moduleScope);
			FixTypes;
			module.SetState(SyntaxTree.Resolved);
		END Resolve;

	END Resolver;

	(*
		An Index is the data structure containing a number to be mapped to types via the object TypeToIndex below.
		Used for type enumeration when exporting.
	*)
	Index =POINTER TO RECORD tag: LONGINT END;

	(*
		The TypeToIndex object provides the link between a type and a module and type number. It is the inverse of the IndexToType and is used
		for exporting. It is implemented using a hash table mapping a SyntaxTree.Type to a Index object.
	*)
	TypeToIndex= OBJECT (Basic.HashTable)

		PROCEDURE GetIndex(type: SyntaxTree.Type): LONGINT;
		VAR t:ANY;
		BEGIN
			t := Get(type);
			IF t # NIL THEN RETURN t(Index).tag ELSE RETURN Undef END;
		END GetIndex;

		PROCEDURE PutIndex(type:SyntaxTree.Type; nr: LONGINT);
		VAR t: Index;
		BEGIN
			ASSERT(nr # Undef);
			NEW(t); t.tag := nr; Put(type,t);
		END PutIndex;

	END TypeToIndex;

	Attribute = OBJECT
	VAR
		numberTypes: LONGINT;
		indexToType: IndexToType;
		typeToIndex: TypeToIndex;

		PROCEDURE &Init;
		BEGIN numberTypes := 0; NEW(indexToType,16); NEW(typeToIndex,100);
		END Init;
	END Attribute;

	IndexToAttribute= OBJECT(Basic.List)

		PROCEDURE PutAttribute(nr: LONGINT; attribute: Attribute);
		BEGIN GrowAndSet(nr,attribute);
		END PutAttribute;

		PROCEDURE GetAttribute(nr: LONGINT): Attribute;
		VAR node: ANY; attribute: Attribute;
		BEGIN
			IF Length() <= nr THEN node := NIL ELSE node := Get(nr) END;
			IF node # NIL THEN attribute := node(Attribute)
			ELSE NEW(attribute); PutAttribute(nr,attribute);
			END;
			RETURN attribute
		END GetAttribute;

	END IndexToAttribute;

	BinarySymbolFile*=OBJECT (Formats.SymbolFileFormat)
	VAR file-: Files.File; extension-: Basic.FileName;
			noRedefinition, noModification, noInterfaceCheck: BOOLEAN;
			version: CHAR;

		(** Import - Symbol Table Loader Plugin *)
		PROCEDURE Import(CONST moduleName: ARRAY OF CHAR; importCache: SyntaxTree.ModuleScope): SyntaxTree.Module;
		VAR
			module: SyntaxTree.Module;
			moduleIdentifier,contextIdentifier: SyntaxTree.Identifier;
			moduleScope: SyntaxTree.ModuleScope;

			fileName: Files.FileName;
			R: Streams.Reader;
			tag, i: LONGINT;

			visibility: SET;

			type: SyntaxTree.Type;
			variable: SyntaxTree.Variable;
			constant: SyntaxTree.Constant;
			procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
			procedureScope: SyntaxTree.ProcedureScope;
			typeDeclaration: SyntaxTree.TypeDeclaration;

			resolver: Resolver;

			allTypes: IndexToType; numberReimports, numberTypes : LONGINT;

			name: SyntaxTree.IdentifierString;

			value: SyntaxTree.Value;

			stamp: LONGINT;
			b: BOOLEAN;

			indexToAttribute: IndexToAttribute;
			predefType: ARRAY sfLastType+1 OF SyntaxTree.Type;

			PROCEDURE NewTypeReference(nr: LONGINT): SyntaxTree.Type;
			VAR typeReference: TypeReference;
			BEGIN
				NEW(typeReference,nr); RETURN typeReference;
			END NewTypeReference;


			(* Imports = {moduleName:RawString} 0X *)
			PROCEDURE Imports;
			VAR moduleName: SyntaxTree.IdentifierString; import: SyntaxTree.Import; importedModule: SyntaxTree.Module; moduleIdentifier,moduleContext: SyntaxTree.Identifier; b: BOOLEAN;
			BEGIN
				R.RawString(moduleName);
				WHILE	moduleName # ""	DO
					ASSERT(moduleName # "SYSTEM");
					IF TraceImport IN Trace THEN D.Str("import module: "); D.Str(moduleName); D.Ln; END;

					(* as the context is not encoded in the symbol file, we have to deduce it from the filename, this is ugly but necessary
						to keep consistency with old compiler
					*)

					Global.ContextFromName(moduleName,moduleIdentifier,moduleContext);

					import := importCache.ImportByModuleName(moduleIdentifier,moduleContext);

					IF import # NIL THEN
						IF import.module = NIL THEN (* has not yet been imported by parent module *)
							(* adjust import symbol in parent *)
							importedModule := Import(moduleName,importCache);
							import.SetModule(importedModule);
						ELSE
							(* take module from parent *)
							importedModule := import.module;
						END
					ELSE
						importedModule := Import(moduleName,importCache);
						IF importedModule # NIL THEN
							import := SyntaxTree.NewImport(-1,importedModule.name,importedModule.name,FALSE);
							import.SetContext(importedModule.context);
							import.SetModule(importedModule);
							import.SetState(SyntaxTree.Resolved);
							importCache.AddImport(import);
						END;
					END;

					(* create new import symbol for this module scope *)
					IF importedModule # NIL THEN
						import := SyntaxTree.NewImport(-1,moduleIdentifier,moduleIdentifier,TRUE);
						import.SetModule(importedModule);
						import.SetContext(moduleContext);
						import.SetState(SyntaxTree.Resolved);
						module.moduleScope.AddImport(import);
						module.moduleScope.EnterSymbol(import,b);
					END;
					R.RawString(moduleName);
				END
			END Imports;

			(* Value = [ RawNum | RawHInt | RawReal | RawLReal | RawString ] *)
			PROCEDURE Value(type: SyntaxTree.Type): SyntaxTree.Value;
			VAR i: LONGINT; huge: HUGEINT;  r: REAL;  lr: LONGREAL; string: SyntaxTree.String; length: LONGINT; set: SET;
				value: SyntaxTree.Value; size: LONGINT;
			BEGIN
				size := type.sizeInBits;
				IF type IS SyntaxTree.BooleanType THEN R.RawNum(i);
					IF TraceImport IN Trace THEN D.Str("InConst / Bool / "); D.Int(i,1); D.Ln;  END;
					IF	i = 0	THEN	value := Global.NewBooleanValue(system,-1,FALSE)	 ELSE value := Global.NewBooleanValue(system,-1,TRUE)	END
				ELSIF (type IS SyntaxTree.CharacterType) THEN
					IF  (size=8) OR (size=16) OR (size=32) THEN
						R.RawNum(i);
						IF TraceImport IN Trace THEN D.Str("InConst / Char / "); D.Int(i,1); D.Ln;  END;
						value := SyntaxTree.NewCharacterValue(-1,CHR(i));
					END;
				ELSIF type IS SyntaxTree.IntegerType THEN
					IF (size = 32) & ~type(SyntaxTree.IntegerType).signed THEN
						R.RawHInt(huge);
						IF TraceImport IN Trace THEN  D.Str("InConst / Unsigned32 / "); D.Ln END;
						value := SyntaxTree.NewIntegerValue (-1,huge);
					ELSIF size <=32 THEN
						R.RawNum(i);
						IF TraceImport IN Trace THEN  D.Str("InConst / Int"); D.Int(size,1); D.String(" "); D.Int(i,1); D.Ln END;
						value := SyntaxTree.NewIntegerValue(-1,i);
					ELSIF size=64 THEN
						R.RawHInt(huge);
						IF TraceImport IN Trace THEN  D.Str("InConst / HInt / "); D.Ln END;
						value := SyntaxTree.NewIntegerValue (-1,huge);
					END;
				ELSIF type IS SyntaxTree.SetType THEN R.RawNum(SYSTEM.VAL(LONGINT, set));
					IF TraceImport IN Trace THEN  D.Str("InConst / Set / "); D.Hex(SYSTEM.VAL(LONGINT, set),1); D.Ln END;
					value := SyntaxTree.NewSetValue(-1,set);
				ELSIF type IS SyntaxTree.FloatType THEN
					IF size = 32 THEN
						R.RawReal(r);
						IF TraceImport IN Trace THEN  D.Str("InConst / Real / "); D.Ln END;
						value := SyntaxTree.NewRealValue(-1,r);
					ELSIF size = 64 THEN
						R.RawLReal(lr);
						IF TraceImport IN Trace THEN  D.Str("InConst / LongReal / "); D.Ln END;
						value := SyntaxTree.NewRealValue(-1,lr);
					END;
				ELSIF type IS SyntaxTree.StringType THEN
					IF version <= FileVersionOC THEN NEW(string, 256)
					ELSE R.RawLInt(length); NEW(string, length)
					END;
					R.RawString(string^);
					IF TraceImport IN Trace THEN  D.Str("InConst / String / "); D.Str(string^); D.Ln END;
					value := SyntaxTree.NewStringValue(-1,string);
					type(SyntaxTree.StringType).SetLength(value(SyntaxTree.StringValue).length);
					type.SetState(SyntaxTree.Resolved);
				ELSIF type IS SyntaxTree.EnumerationType THEN R.RawNum(i);
					IF TraceImport IN Trace THEN  D.Str("InConst / LInt / "); D.Int(i,1); D.Ln END;
					value := SyntaxTree.NewEnumerationValue(-1,i);
				ELSIF type IS SyntaxTree.NilType THEN
					IF TraceImport IN Trace THEN  D.Str("InConst / Nil"); D.Ln END;
					value := SyntaxTree.NewNilValue(-1);
				END;
				value.SetType(type);
				value.SetState(SyntaxTree.Resolved);
				RETURN value
			END Value;

			(* EnumerationList = {name:RawString} sfEnd *)
			PROCEDURE EnumerationList(enumerationScope: SyntaxTree.EnumerationScope);
			VAR enumerator: SyntaxTree.Constant; visibility,flags: SET; b: BOOLEAN;
				type: SyntaxTree.Type; name: SyntaxTree.IdentifierString; identifier: SyntaxTree.Identifier;
			BEGIN
				R.RawString(name);
				WHILE name # "" DO
					identifier := SyntaxTree.NewIdentifier(name);
					enumerator := SyntaxTree.NewConstant(-1,identifier);
					enumerationScope.AddConstant(enumerator);
					enumerationScope.EnterSymbol(enumerator,b);
					IF name # "@" THEN enumerationScope.lastConstant.SetAccess(SyntaxTree.Public+SyntaxTree.Internal+SyntaxTree.Protected)
					ELSE enumerationScope.lastConstant.SetAccess(SyntaxTree.Internal)
					END;
					value := Value(enumerationScope.ownerEnumeration);
					enumerator.SetValue(value);
					enumerator.SetType(enumerationScope.ownerEnumeration);
					R.RawString(name);
				END;



			END EnumerationList;


			(* ParameterList = { [sfObjflag ( sfCParam | sfDarwinCParam | sfWinAPIParam )] [sfVar] [sfReadOnly] Type name:RawString } sfEnd *)
			PROCEDURE ParameterList(VAR callingConvention: LONGINT; parentScope: SyntaxTree.Scope; procedureType: SyntaxTree.ProcedureType);
			VAR name: SyntaxTree.IdentifierString; type: SyntaxTree.Type; f: LONGINT;
				kind: LONGINT;
				parameter: SyntaxTree.Parameter;
			BEGIN
				IF TraceImport IN Trace THEN
					D.Str("ParameterList "); D.Ln
				END;
				callingConvention := SyntaxTree.OberonCallingConvention;

				R.RawNum(tag);
				WHILE  tag#sfEnd  DO
					IF tag = sfObjFlag THEN (*! the calling convention should not be expressed via the parameters (compatiblity with old compiler) *)
						R.RawNum(f);
						IF f = sfCParam THEN (* fof for Linux *)
							callingConvention := SyntaxTree.CCallingConvention
						ELSIF f = sfDarwinCParam THEN (* fld for darwin *)
							callingConvention := SyntaxTree.DarwinCCallingConvention
						ELSIF f=sfWinAPIParam THEN
							callingConvention := SyntaxTree.WinAPICallingConvention
						ELSE HALT(100)
						END;
						R.RawNum(tag);
					END;
					IF  tag=sfVar  THEN
						R.RawNum(tag);
						kind := SyntaxTree.VarParameter;
					ELSE
						kind := SyntaxTree.ValueParameter;
					END;
					IF tag = sfReadOnly THEN  (* var const *)
						R.RawNum(tag);
						kind := SyntaxTree.ConstParameter;
					END;

					type := Type();

					R.RawString(name);

					parameter := SyntaxTree.NewParameter(-1,procedureType,SyntaxTree.NewIdentifier(name),kind);
					parameter.SetType(type);
					parameter.SetState(SyntaxTree.Resolved);
					(*! remove this after a rebuild of the release - for compatibility only *)
					IF (parameter.name=Global.SelfParameterName)
						OR (parameter.name=Global.ReturnParameterName)
						OR (parameter.name=Global.PointerReturnName)
						OR (parameter.name=Global.ResultName) THEN (* ignore *)
					ELSE
					procedureType.AddParameter(parameter);
					END;

					R.RawNum(tag)
				END;

				IF callingConvention # SyntaxTree.OberonCallingConvention THEN
					procedureType.RevertParameters;
				END;
			END ParameterList;

			(* returns the index of module importedModule in the list of module module *)
			PROCEDURE ModuleByIndex(module: SyntaxTree.Module; index: LONGINT): SyntaxTree.Module;
			VAR import: SyntaxTree.Import;
			BEGIN import := module.moduleScope.firstImport;
				WHILE (import # NIL) & (index > 0) DO
					IF (* (import.direct) & *)  ~Global.IsSystemModule(import.module) THEN DEC(index) END;
					import := import.nextImport;
				END;
				ASSERT(import # NIL);
				(* ASSERT(import.direct); *)
				RETURN import.module;
			END ModuleByIndex;

			(*
				Record =
					mode:RawNum priority:Char {variable:Symbol}
					[sfTProcedure {Symbol [name:RawString] ParameterList [sfInline Inline]} ]
					sfEnd
			*)
			PROCEDURE Record(recordType: SyntaxTree.RecordType; baseType: SyntaxTree.Type);
			VAR
				mode: SET;
				priority: LONGINT;
				visibility: SET;

				active, safe, isOperator, isDynamic: BOOLEAN;
				untraced, realtime, constructor: BOOLEAN;

				variable: SyntaxTree.Variable;
				procedure: SyntaxTree.Procedure;
				operator: SyntaxTree.Operator;
				procedureType: SyntaxTree.ProcedureType;
				recordScope: SyntaxTree.RecordScope;
				recordBody: SyntaxTree.Body;
				name: SyntaxTree.IdentifierString;

				ch: CHAR;
				callingConvention: LONGINT;

			BEGIN
				recordScope := recordType.recordScope;

				R.RawNum(SYSTEM.VAL(LONGINT, mode));
				IF sfActive IN mode THEN active := TRUE ELSE active := FALSE END;
				IF sfProtected IN mode THEN recordType.SetProtected(TRUE) END;
				IF sfSafe IN mode THEN safe := TRUE ELSE safe := FALSE END;

				R.Char(ch);
				priority := ORD(ch); (* body priority, if active object *)
				IF TraceImport IN Trace THEN
					D.Str("Rec / Mode / "); D.Hex(SYSTEM.VAL(LONGINT, mode),1); D.Ln;
					D.Str("Rec / Prio / "); D.Int(priority,1); D.Ln
				END;

				R.RawNum(tag);
				WHILE  (tag < sfTProcedure) OR (tag > sfEnd) DO	(*read fields*)
					isOperator := FALSE;
					Symbol(recordScope,type,name,visibility,untraced, realtime, constructor, isOperator, isDynamic);
					ASSERT(type # NIL);
					IF  name = "" THEN visibility := SyntaxTree.Internal END;
					variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier(name));
					variable.SetType(type);
					variable.SetUntraced(untraced);
					variable.SetAccess(visibility);
					variable.SetState(SyntaxTree.Resolved);
					recordScope.AddVariable(variable);
					recordScope.EnterSymbol(variable,b);
					R.RawNum(tag);
				END;

				IF tag=sfTProcedure THEN
					R.RawNum(tag);
					WHILE  tag#sfEnd  DO
						isOperator := FALSE;
						Symbol(recordScope,type,name, visibility,untraced, realtime, constructor, isOperator, isDynamic);
						IF  name = "" THEN  R.RawString(name)  END;

						procedureScope := SyntaxTree.NewProcedureScope(recordScope);
						IF isOperator THEN
							operator := SyntaxTree.NewOperator(-1,SyntaxTree.NewIdentifier(name),procedureScope);
							procedure := operator
						ELSE
							procedure := SyntaxTree.NewProcedure(-1,SyntaxTree.NewIdentifier(name),procedureScope);
						END;
						procedureType := SyntaxTree.NewProcedureType(-1,recordScope);
						procedureType.SetReturnType(type);
						procedureType.SetRealtime(realtime);
						procedure.SetConstructor(constructor);
						procedureType.SetDelegate(TRUE);
						procedure.SetType(procedureType);
						procedure.SetAccess(visibility);
						procedure.SetState(SyntaxTree.Resolved);
						IF constructor THEN
							recordScope.SetConstructor(procedure); (*! redundant *)
						END;

						ParameterList(callingConvention,procedureScope,procedureType);

						recordScope.AddProcedure(procedure);
						IF isOperator THEN
							recordScope.AddOperator(operator);
						END;
						recordScope.EnterSymbol(procedure,b);

						(* This identifies a inlined Indexer *)
						R.RawNum(tag);
						IF tag = sfInline THEN
							Inline(procedureScope);
							(*
							INCL(flag, SyntaxTree.Inline);
							INCL(flag, SyntaxTree.Indexer);
							INCL(flag, SyntaxTree.Operator);
							mscope.code := Inline();
							*)
							R.RawNum(tag)
						END;
						IF (procedure.name=Global.RecordBodyName) THEN
							recordScope.SetBodyProcedure(procedure);
							recordBody := SyntaxTree.NewBody(-1,procedureScope);
							recordBody.SetSafe(safe);
							recordBody.SetActive(active);
							procedureScope.SetBody(recordBody);
						END;
					END

				ELSE ASSERT(tag = sfEnd);
				END;

				(*
				ASSERT((bodyFlags = {}) OR (recordScope.bodyProcedure # NIL));
				*)

				recordType.SetBaseType(baseType);

			END Record;

			(*
				Type =
					TypeReference
					|BasicType
					|ImportedType
					|UserType.

				TypeReference = number:RawNum(<0)
				BasicType = sfTypeBoolean |  .. |  sfLastType.
				ImportedType = ModuleNumber (structName:RawString | 0X typeIndex:RawNum)
				ModuleNumber = sfMod1 | .. | sfModOther-1 | sfModOther moduleNumber:RawNum

				UserType = [sfInvisible] [sfSysFlag sysFlag:RawNum] UserType2
				UserType2=
					sfTypeOpenArray baseType:Type name:RawString flags:RawNum
					|sfTypeStaticArray baseType:Type name:RawString flags:RawNum length:RawNum
					|sfOpenMathArray baseType:Type name:RawString
					|sfStaticMathArray baseType:Type name:RawString length:RawNum
					|sfTypeTensor baseType:Type name:RawString
					|sfTypePointer baseType:Type name:RawString flags:RawNum
					|sfTypeRecord baseType:Type name:RawString flags:RawNum Record
					|sfTypeProcedure baseType:Type name:RawString flags:RawNum ParameterList
					|sfTypeEnumeration enumerationBase:Type name:RawString
			*)
			PROCEDURE Type(): SyntaxTree.Type;
				VAR
					typtag,len: LONGINT;

				name: SyntaxTree.IdentifierString;

				type, baseType: SyntaxTree.Type;
				typeDeclaration: SyntaxTree.TypeDeclaration;
				arrayType: SyntaxTree.ArrayType;
				mathArrayType: SyntaxTree.MathArrayType;
				pointerType: SyntaxTree.PointerType;
				procedureType: SyntaxTree.ProcedureType;
				recordType: SyntaxTree.RecordType;
				recordScope: SyntaxTree.RecordScope;
				qualifiedType: SyntaxTree.QualifiedType;
				enumerationScope: SyntaxTree.EnumerationScope;
				enumerationType: SyntaxTree.EnumerationType;
				(*import: SyntaxTree.Import;*)
				importedModule: SyntaxTree.Module;
				identifier: SyntaxTree.Identifier;
				thisIndex : LONGINT;
				typeAdr: LONGINT;
				size: SyntaxTree.Value;

				visibility: SET;

				typeName: SyntaxTree.IdentifierString;

				sysflag: LONGINT; flags: SET;

				attribute: Attribute;
				callingConvention: LONGINT;

			BEGIN
				visibility := SyntaxTree.Public + SyntaxTree.Protected + SyntaxTree.Internal; flags := {};

				IF tag <= 0 THEN (* TypeReference = number:RawNum(<0) *)
					type := NewTypeReference(-tag);
					IF TraceImport IN Trace THEN
						D.Str("Type / OldStr "); D.Int(-tag,1); D.Ln
					END
				ELSIF tag = sfTypeString THEN
					type := SyntaxTree.NewStringType(-1,system.characterType,0);
					IF TraceImport IN Trace THEN
						D.Str("Type / String "); D.Int(tag,1); D.Ln
					END
				ELSIF tag <= sfLastType THEN  (* BasicType = sfTypeBoolean |  .. |  sfLastType. *)
					type := predefType[tag];
					ASSERT((tag = sfTypeNoType) OR (type # NIL));
					IF TraceImport IN Trace THEN
						D.Str("Type / Basic "); D.Int(tag,1); D.Ln
					END
				ELSIF tag = sfTypeRange THEN
					type := system.rangeType;
				ELSIF tag = sfTypeComplex THEN
					type := system.complexType;
				ELSIF tag = sfTypeLongcomplex THEN
					type := system.longcomplexType;
				ELSIF tag <= sfModOther THEN
					(* ImportedType = ModuleNumber (structName:RawString | 0X typeIndex:RawNum) *)
					(* ModuleNumber = sfMod1 | .. | sfModOther-1 | sfModOther moduleNumber:RawNum *)


					IF tag = sfModOther THEN
						R.RawNum(tag);
						ASSERT(tag >= 0);
					ELSE
						tag := tag-sfMod1
					END;	(*tag = [0 .. +oo[ *)

					importedModule := ModuleByIndex(module,tag);
					ASSERT(importedModule # NIL);

					R.RawString(typeName);

					type := NIL;

					attribute := indexToAttribute.GetAttribute(tag);

					IF typeName # "" THEN (* first import of struct *)
						identifier := SyntaxTree.NewIdentifier(typeName);
						typeDeclaration := importedModule.moduleScope.FindTypeDeclaration(identifier); (* find type in module *)
						IF (typeDeclaration # NIL) THEN
							qualifiedType := SyntaxTree.NewQualifiedType(-1,moduleScope,SyntaxTree.NewQualifiedIdentifier(-1,importedModule.name,identifier));
							qualifiedType.SetResolved(typeDeclaration.declaredType);
							qualifiedType.SetTypeDeclaration(typeDeclaration);
							type := qualifiedType;
						END;
						(* add reimport *)
						attribute.indexToType.PutType(attribute.numberTypes,type);
						INC(attribute.numberTypes);
						IF TraceImport IN Trace THEN
							D.Str("Type / Reimport "); D.Str(typeName); D.Str(" in "); D.Str0(importedModule.name); D.Str(":"); D.Int(tag,1-sfMod1);  D.Ln;
						END;
					ELSE
						R.RawNum(typeAdr);
						type := attribute.indexToType.GetType(typeAdr);
						IF TraceImport IN Trace THEN
							D.Str("Type / Reimport "); D.Int(typeAdr,1); D.Str(" in "); D.Str0(importedModule.name); D.Str(":"); D.Int(tag,1-sfMod1);  D.Ln;
						END;
					END;
				ELSE (* UserType = [sfInvisible] [sfSysFlag flag] UserType2 *)
					IF TraceImport IN Trace THEN
						D.Str("Type / User "); D.Str(name); D.Ln
					END;
					thisIndex := numberTypes; INC(numberTypes);

					IF tag = sfInvisible THEN visibility := SyntaxTree.Internal;  R.RawNum(tag)  END;
					IF tag = sfSysFlag THEN R.RawNum(sysflag); R.RawNum(tag)  END;


					(* UserType2 *)
					typtag := tag;
					R.RawNum(tag);

					baseType := Type();
					R.RawString(name);

					CASE typtag OF
					| sfTypeOpenArray:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / OpenArr "); D.Str(name); D.Ln
							END;
							ASSERT(baseType # NIL);
							arrayType := SyntaxTree.NewArrayType(-1,moduleScope,SyntaxTree.Open);
							arrayType.SetArrayBase(baseType);
							type := arrayType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
					| sfTypeStaticArray:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Array ");
								D.Int(len,1); D.Str(name); D.Ln
							END;
							ASSERT(baseType # NIL);
							arrayType :=SyntaxTree.NewArrayType(-1,moduleScope,SyntaxTree.Static);
							arrayType.SetArrayBase(baseType);
							type := arrayType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
							R.RawNum(len);
							size := SyntaxTree.NewIntegerValue(-1,len);
							size.SetType(system.longintType);
							arrayType.SetLength(size);
					| sfTypeOpenMathArray:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / MathArray (open) "); D.Str(name); D.Ln
							END;
							ASSERT(baseType # NIL);
							mathArrayType := SyntaxTree.NewMathArrayType(-1,moduleScope,SyntaxTree.Open);
							mathArrayType.SetArrayBase(baseType);
							type := mathArrayType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
					| sfTypeTensor:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Tensor "); D.Str(name); D.Ln
							END;
							mathArrayType := SyntaxTree.NewMathArrayType(-1,moduleScope,SyntaxTree.Tensor);
							mathArrayType.SetArrayBase(baseType);
							type := mathArrayType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
					| sfTypeStaticMathArray:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / MathArray (Static) ");
								D.Int(len,1); D.Str(name); D.Ln
							END;
							ASSERT(baseType # NIL);
							mathArrayType :=SyntaxTree.NewMathArrayType(-1,moduleScope,SyntaxTree.Static);
							mathArrayType.SetArrayBase(baseType);
							type := mathArrayType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
							R.RawNum(len);
							size := SyntaxTree.NewIntegerValue(-1,len);
							size.SetType(system.longintType);
							mathArrayType.SetLength(size);
					| sfTypePointer:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Pointer "); D.Str(name); D.Ln
							END;
							pointerType := SyntaxTree.NewPointerType(-1,moduleScope);
							type := pointerType;
							pointerType.SetPointerBase(baseType);
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							WITH type: SyntaxTree.PointerType DO
								IF sfUnsafe IN flags THEN type.SetUnsafe(TRUE) END;
								IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
								IF sfDisposable IN flags THEN type.SetDisposable(TRUE) END;
							END;
					| sfTypeRecord:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Record "); D.Str(name); D.Ln
							END;
							recordScope := SyntaxTree.NewRecordScope(moduleScope);
							recordType := SyntaxTree.NewRecordType(-1,moduleScope,recordScope);
							type := recordType;
							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfRealtime IN flags THEN type.SetRealtime(TRUE) END;
							Record(recordType,baseType);
					| sfTypeProcedure:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Proc "); D.Str(name); D.Ln
							END;
							procedureScope := SyntaxTree.NewProcedureScope(NIL);
							procedureType := SyntaxTree.NewProcedureType(-1,moduleScope);
							procedureType.SetReturnType(baseType);
							type := procedureType;

							IF sysflag = sfDelegate THEN procedureType.SetDelegate(TRUE)  END;

							R.RawNum(SYSTEM.VAL(LONGINT,flags));
							IF sfWinAPIParam IN flags THEN procedureType.SetCallingConvention(SyntaxTree.WinAPICallingConvention)
							ELSIF sfCParam IN flags THEN procedureType.SetCallingConvention(SyntaxTree.CCallingConvention)
							ELSIF sfDarwinCParam IN flags THEN procedureType.SetCallingConvention(SyntaxTree.DarwinCCallingConvention)
							END;
							IF sfRealtime IN flags THEN procedureType.SetRealtime(TRUE) END;

							ParameterList(callingConvention,procedureScope,procedureType);
					| sfTypeEnumeration:
							IF TraceImport IN Trace THEN
								D.Str("Type / User / Enumerator "); D.Str(name); D.Ln
							END;
							enumerationScope := SyntaxTree.NewEnumerationScope(moduleScope);
							enumerationType := SyntaxTree.NewEnumerationType(-1,moduleScope,enumerationScope);
							type := enumerationType;
							enumerationType.SetEnumerationBase(baseType);
							EnumerationList(enumerationScope);
					END;

					IF name # "" THEN
						typeDeclaration := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier(name));
						typeDeclaration.SetDeclaredType(type);
						type.SetTypeDeclaration(typeDeclaration);
						typeDeclaration.SetAccess(visibility);
						typeDeclaration.SetState(SyntaxTree.Resolved);
						qualifiedType := SyntaxTree.NewQualifiedType(-1,moduleScope, SyntaxTree.NewQualifiedIdentifier(-1,SyntaxTree.invalidIdentifier,typeDeclaration.name));
						qualifiedType.SetResolved(type);
						type := qualifiedType;
						type.SetTypeDeclaration(typeDeclaration);

						module.moduleScope.AddTypeDeclaration(typeDeclaration);  (* do not replace module.moduleScope by parentScope ! *)
						module.moduleScope.EnterSymbol(typeDeclaration,b);
					END;

					allTypes.PutType(thisIndex,type);

					IF TraceImport IN Trace THEN
						D.Str("resolver.AddType "); D.Str(name); D.Str(" "); D.Int(thisIndex,1); D.Str("");
						D.Ln
					END;

				END;
				RETURN type;
			END Type;

			(*
				Inline = {len:Char {c:Char}} 0X
			*)
			PROCEDURE Inline(scope: SyntaxTree.ProcedureScope);
			VAR ch: CHAR;  pos, len: LONGINT; array: SyntaxTree.BinaryCode; newcode: SyntaxTree.Code;
				body: SyntaxTree.Body;

			PROCEDURE Append(ch: CHAR);
			BEGIN
				array.Resize(pos+8);
				array.SetBits(pos,8,ORD(ch));
				INC(pos,8);
			END Append;

			BEGIN
				NEW(array,128*8);
				R.Char(ch);pos := 0;
				REPEAT
					len := ORD(ch);
					WHILE len > 0 DO  R.Char(ch); Append(ch);  DEC(len)  END;
					R.Char(ch);
				UNTIL ch = 0X;
				body := SyntaxTree.NewBody(-1,scope);
				newcode := SyntaxTree.NewCode(-1,body);
				body.SetCode(newcode);
				scope.SetBody(body);
				newcode.SetBinaryCode(array);
			END Inline;

			(* Symbol = [sfObjFlag flag:RawNum] [sfReadOnly] Type name:RawString *)
			PROCEDURE Symbol(parentScope: SyntaxTree.Scope; VAR type: SyntaxTree.Type; VAR name: SyntaxTree.IdentifierString;  VAR visibility: SET; VAR untraced, realtime, constructor, operator, isDynamic: BOOLEAN);
			VAR  f,i: LONGINT;
			BEGIN
				IF TraceImport IN Trace THEN
					D.Str("Symbol: --> "); D.Ln
				END;
				untraced := FALSE; realtime := FALSE; constructor := FALSE; isDynamic := FALSE;
				visibility:=SyntaxTree.Public+SyntaxTree.Protected+SyntaxTree.Internal;
				WHILE tag=sfObjFlag DO
					R.RawNum(f);
					IF f = sfUntraced THEN untraced := TRUE
					ELSIF f = sfRealtime THEN realtime := TRUE
					ELSIF f = sfOperator THEN operator := TRUE;
					ELSIF f = sfDynamic THEN isDynamic := TRUE;
					ELSE D.Str("Object: unknown objflag"); D.Ln
					END;
					R.RawNum(tag);
				END;
				IF tag=sfReadOnly THEN  visibility := visibility * SyntaxTree.ReadOnly; R.RawNum(tag) END;
				type := Type();
				R.RawString(name);
				IF ~operator & (name[0] = "&") THEN
					constructor := TRUE;
					i := 0; REPEAT  name[i] := name[i+1]; INC(i)  UNTIL name[i] = 0X;
				END;
				IF name = "" THEN
					visibility := visibility * SyntaxTree.Internal;
				END;
				IF TraceImport IN Trace THEN
					D.Str("<-- "); D.Str(name); D.Ln
				END;

			END Symbol;

			(*
				SymbolFile =
				coeOptions:RawSet
				Imports
				[sfSysFlag sysFlags:Number]
				[sfConst {Symbol Value}]
				[sfVar {Symbol}]
				[sfXProcedure {Symbol ParameterList}]
				[sfOperator {Symbol ParameterList [sfInline Inline]}]
				[sfCProcedure {Symbol ParameterList Inline}]
				[sfAlias {Type name:RawString}]
				[sfType {Type}]
				sfEnd
			*)

			PROCEDURE Module;
			VAR flags: SET; untraced, realtime, constructor,operator, isDynamic: BOOLEAN; callingConvention: LONGINT;
			BEGIN
				R.RawSet(flags);

				Imports;

				R.RawNum(tag);
				flags := {};
				IF tag = sfSysFlag THEN
					R.RawNum(SYSTEM.VAL(LONGINT, flags));
					R.RawNum(tag);
				END;

				IF TraceImport IN Trace THEN  D.Str("importing constants"); D.Ln; END;
				IF tag=sfConst	THEN R.RawNum(tag);
					WHILE	(tag < sfVar) OR (tag > sfEnd) DO
						operator := FALSE;
						Symbol(moduleScope,type,name, visibility,untraced,realtime,constructor,operator, isDynamic);
						ASSERT(type # NIL);
						value := Value(type);
						constant := SyntaxTree.NewConstant(-1,SyntaxTree.NewIdentifier(name));
						constant.SetValue(value);
						constant.SetType(value.type);
						constant.SetAccess(visibility);
						constant.SetState(SyntaxTree.Resolved);
						moduleScope.AddConstant(constant);
						moduleScope.EnterSymbol(constant,b);
						R.RawNum(tag)
					END
				END;

				IF TraceImport IN Trace THEN  D.Str("importing variables"); D.Ln; END;
				IF	tag=sfVar	THEN	R.RawNum(tag);
					WHILE	(tag < sfXProcedure) OR (tag > sfEnd)	DO
						operator := FALSE;
						Symbol(moduleScope,type,name, visibility,untraced,realtime,constructor,operator, isDynamic);
						ASSERT(type # NIL);
						variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier(name));
						variable.SetType(type);
						variable.SetAccess(visibility);
						variable.SetState(SyntaxTree.Resolved);
						moduleScope.AddVariable(variable);
						moduleScope.EnterSymbol(variable,b);
						R.RawNum(tag)
					END
				END;

				IF TraceImport IN Trace THEN  D.Str("importing procedures"); D.Ln; END;
				IF	tag=sfXProcedure	THEN	R.RawNum(tag);
					WHILE	(tag < sfOperator) OR (tag > sfEnd)	DO
						operator := FALSE;
						Symbol(moduleScope,type,name, visibility,untraced,realtime,constructor,operator, isDynamic);
						ASSERT(~(constructor));
						procedureScope := SyntaxTree.NewProcedureScope(moduleScope);
						procedureType := SyntaxTree.NewProcedureType(-1,moduleScope);
						procedureType.SetReturnType(type);
						procedure := SyntaxTree.NewProcedure(-1,SyntaxTree.NewIdentifier(name),procedureScope);
						procedure.SetType(procedureType);
						procedure.SetAccess(visibility);
						ParameterList(callingConvention,procedureScope,procedureType);
						procedureType.SetRealtime(realtime);
						procedure.SetState(SyntaxTree.Resolved);
						procedure.SetConstructor(constructor);
						moduleScope.AddProcedure(procedure);
						moduleScope.EnterSymbol(procedure,b);
						R.RawNum(tag)
					END
				END;

				IF TraceImport IN Trace THEN  D.Str("importing operators"); D.Ln; END;
				IF	tag=sfOperator	THEN	R.RawNum(tag);
					WHILE	(tag < sfCProcedure) OR (tag > sfEnd)	DO
						operator := TRUE;
						Symbol(moduleScope,type,name, visibility,untraced,realtime,constructor,operator, isDynamic);
						ASSERT(~(constructor));
						procedureScope := SyntaxTree.NewProcedureScope(moduleScope);
						procedureType := SyntaxTree.NewProcedureType(-1,moduleScope);
						procedureType.SetReturnType(type);
						procedureType.SetRealtime(realtime);
						procedure := SyntaxTree.NewOperator(-1,SyntaxTree.NewIdentifier(name),procedureScope);
						procedure.SetType(procedureType);
						procedure.SetAccess(visibility);
						procedure(SyntaxTree.Operator).SetDynamic(isDynamic);
						ParameterList(callingConvention,procedureScope,procedureType);
						procedureType.SetCallingConvention(callingConvention);
						procedure.SetState(SyntaxTree.Resolved);
						module.moduleScope.AddProcedure(procedure);
						module.moduleScope.AddOperator(procedure(SyntaxTree.Operator));
						module.moduleScope.EnterSymbol(procedure,b);
						R.RawNum(tag);
						IF tag = sfInline THEN
							Inline(procedureScope);
							procedure.SetInline(TRUE);
							R.RawNum(tag);
						END;
					END
				END;
				IF TraceImport IN Trace THEN  D.Str("importing inline procedures"); D.Ln; END;
				IF  tag = sfCProcedure  THEN	R.RawNum(tag);
					WHILE	(tag < sfAlias) OR (tag > sfEnd)	DO
						operator := FALSE;
						Symbol(moduleScope,type,name, visibility,untraced, realtime, constructor,operator, isDynamic);
						ASSERT(~(constructor));
						procedureScope := SyntaxTree.NewProcedureScope(moduleScope);
						procedureType := SyntaxTree.NewProcedureType(-1,moduleScope);
						procedure := SyntaxTree.NewProcedure(-1,SyntaxTree.NewIdentifier(name),procedureScope);
						procedureType.SetReturnType(type);
						procedure.SetInline(TRUE);
						procedure.SetType(procedureType);
						procedure.SetAccess(visibility);
						ParameterList(callingConvention,procedureScope,procedureType);
						procedure.SetState(SyntaxTree.Resolved);
						module.moduleScope.AddProcedure(procedure);
						module.moduleScope.EnterSymbol(procedure,b);
						Inline(procedureScope);
						R.RawNum(tag);
					END
				END;
				IF TraceImport IN Trace THEN  D.Str("importing type declaration aliases"); D.Ln; END;
				IF	tag=sfAlias	THEN	R.RawNum(tag);
					WHILE	(tag < sfType) OR (tag > sfEnd)	DO
						type := Type();
						R.RawString(name);
						IF TraceImport IN Trace  THEN  D.Str("alias:"); D.Str(name); D.Ln  END;
						typeDeclaration := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier(name));
						typeDeclaration.SetDeclaredType(type);
						visibility := SyntaxTree.Public+SyntaxTree.Protected+SyntaxTree.Internal;
						typeDeclaration.SetAccess(visibility);
						typeDeclaration.SetState(SyntaxTree.Resolved);
						IF ~(type IS SyntaxTree.BasicType) THEN
							type.SetTypeDeclaration(typeDeclaration);
						END;
						module.moduleScope.AddTypeDeclaration(typeDeclaration);
						module.moduleScope.EnterSymbol(typeDeclaration,b);
						R.RawNum(tag)
					END
				END;
				IF TraceImport IN Trace THEN  D.Str("importing type declaration"); D.Ln; END;
				IF	tag=sfType	THEN
					R.RawNum(tag);
					WHILE	tag # sfEnd	DO
						type := Type();
						R.RawNum(tag)
					END
				END;
			END Module;

		PROCEDURE InitBasic(type: SyntaxTree.Type; tag: LONGINT);
		BEGIN
			predefType[tag] := type;
		END InitBasic;

		PROCEDURE Init;
		BEGIN
			(*Built-In types*)
			InitBasic(system.booleanType,sfTypeBoolean);
			InitBasic(system.characterType,sfTypeChar8);
			InitBasic(Global.Character16,sfTypeChar16);
			InitBasic(Global.Character32,sfTypeChar32);
			InitBasic(system.shortintType, sfTypeShortint);
			InitBasic(system.integerType, sfTypeInteger);
			InitBasic(system.longintType, sfTypeLongint);
			InitBasic(system.hugeintType, sfTypeHugeint);
			InitBasic(Global.Unsigned8, sfTypeUnsigned8);
			InitBasic(Global.Unsigned16, sfTypeUnsigned16);
			InitBasic(Global.Unsigned32, sfTypeUnsigned32);
			InitBasic(Global.Unsigned64, sfTypeUnsigned64);
			InitBasic(Global.Float32, sfTypeReal);
			InitBasic(Global.Float64, sfTypeLongreal);
			InitBasic(system.setType, sfTypeSet);
			InitBasic(system.anyType, sfTypeAny);
			InitBasic(system.objectType, sfTypeObject);
			InitBasic(system.nilType, sfTypeNilType);
			InitBasic(NIL, sfTypeNoType);
			InitBasic(system.byteType, sfTypeByte);
			InitBasic(system.sizeType, sfTypeSize);
			InitBasic(system.addressType, sfTypeAddress);
		END Init;

		BEGIN
			Init;
			i := 0; numberTypes := 0; numberReimports := 0;
			COPY(moduleName,fileName);
			NEW(allTypes,32); NEW(indexToAttribute,32);
			ASSERT(fileName # "SYSTEM");

			IF ~OpenSymFile(fileName, path, extension, R, version) THEN (*! reintroduce flexible extension *)
				RETURN NIL
			END;

			IF TraceImport IN Trace THEN
				D.Str("BINARY SYMBOL FILE IMPORT "); D.Str(moduleName); D.Ln;
			END;

			(* as the context is not encoded in the symbol file, we have to deduce it from the filename, this is ugly but necessary
				to keep consistency with old compiler
			*)
			Global.ContextFromName(moduleName,moduleIdentifier,contextIdentifier);

			moduleScope := SyntaxTree.NewModuleScope();
			module:= SyntaxTree.NewModule(fileName,-1,moduleIdentifier,moduleScope,Scanner.Uppercase);
			module.SetContext(contextIdentifier);
			IF importCache = NIL THEN importCache := SyntaxTree.NewModuleScope(); END;

			Module;

			stamp := Kernel.GetTicks();
			NEW(resolver,system,SELF,importCache);
			resolver.Resolve(module,allTypes);
			module.SetState(SyntaxTree.Resolved);

			IF TraceImport IN Trace THEN
					D.Str("BINARY SYMBOL FILE IMPORT DONE "); D.Str(moduleName); D.Ln;
			END;
			(* if import error then module := NIL *)
			RETURN module
		END Import;

		PROCEDURE Export(module: SyntaxTree.Module; importCache: SyntaxTree.ModuleScope): BOOLEAN;
		VAR w: Files.Writer; lookup: TypeToIndex; indexToAttribute: IndexToAttribute; numberType: LONGINT; flags: SET;


			(* Imports = {moduleName:RawString} 0X *)
			PROCEDURE Imports(import: SyntaxTree.Import);
			VAR name: SyntaxTree.IdentifierString;
			BEGIN
				WHILE import # NIL DO
					IF  ~Global.IsSystemModule(import.module) THEN
						Global.ModuleFileName(import.module.name,import.module.context,name);
						(*! maybe the context and module name should be stored as different names ? *)
						IF TraceExport IN Trace THEN
							D.Str("import: "); D.Str(name); D.Ln;
						END;
						w.RawString(name);
					END;
					import := import.nextImport;
				END;
				w.RawNum(0); (* end of imports *)
			END Imports;

			(* Value = [RawNum | RawHInt | RawReal | RawLReal | RawString] *)
			PROCEDURE Value(v: SyntaxTree.Value);
			VAR type: SyntaxTree.Type;
			BEGIN
				type := v.type.resolved;
				IF type IS SyntaxTree.BooleanType THEN w.RawNum(SYSTEM.VAL(SHORTINT,v(SyntaxTree.BooleanValue).value))
				ELSIF type IS SyntaxTree.CharacterType THEN w.RawNum(ORD(v(SyntaxTree.CharacterValue).value));
				(*
				ELSIF type = Global.Char16 THEN  w.RawNum(ORD(v(SyntaxTree.CharacterValue).value));
				ELSIF type = Global.Char32 THEN w.RawNum(ORD(v(SyntaxTree.CharacterValue).value));
				*)
				ELSIF (type IS SyntaxTree.IntegerType) & (type.sizeInBits = 64) THEN w.RawHInt(v(SyntaxTree.IntegerValue).hvalue);
				ELSIF (type IS SyntaxTree.IntegerType) & (type.sizeInBits = 32) & ~type(SyntaxTree.IntegerType).signed  THEN w.RawHInt(v(SyntaxTree.IntegerValue).hvalue);
				ELSIF (type IS SyntaxTree.IntegerType) & (type.sizeInBits <= 32)  THEN w.RawNum(v(SyntaxTree.IntegerValue).value);
				ELSIF type IS SyntaxTree.SetType THEN   w.RawNum(SYSTEM.VAL(LONGINT,v(SyntaxTree.SetValue).value));
				ELSIF type IS SyntaxTree.FloatType THEN
					IF type.sizeInBits = 32 THEN w.RawReal(SHORT(v(SyntaxTree.RealValue).value));
					ELSE w.RawLReal(v(SyntaxTree.RealValue).value);
					END;
				ELSIF type IS SyntaxTree.StringType THEN  w.RawLInt(v(SyntaxTree.StringValue).length); w.RawString(v(SyntaxTree.StringValue).value^);
				ELSIF type IS SyntaxTree.NilType THEN
				ELSIF type IS SyntaxTree.ByteType THEN HALT(100)
				ELSIF type IS SyntaxTree.EnumerationType THEN w.RawNum(v(SyntaxTree.EnumerationValue).value);
				ELSE HALT(200);
				END;
			END Value;

			(*
				Record =
					mode:RawNum priority:Char {variable:Symbol}
					[sfTProcedure {Symbol [name:RawString] ParameterList [sfInline Inline]} ]
					sfEnd
			*)
			PROCEDURE Record(record: SyntaxTree.RecordType);
			VAR scope: SyntaxTree.RecordScope; variable: SyntaxTree.Variable; procedure: SyntaxTree.Procedure; name: SyntaxTree.IdentifierString; flags,mode: SET;
				procedureType: SyntaxTree.ProcedureType; body: SyntaxTree.Body; first: BOOLEAN;
			BEGIN
				scope := record.recordScope;
				IF record.recordScope.bodyProcedure # NIL THEN
					body := record.recordScope.bodyProcedure.procedureScope.body;
					IF body.isActive THEN INCL(mode,sfActive) END;
					IF body.isSafe THEN INCL(mode,sfSafe) END;
				END;
				IF record.IsProtected() THEN INCL(mode,sfProtected) END;
				IF record.pointerType # NIL THEN INCL(mode,sfClass) END;
				w.RawNum(SYSTEM.VAL(LONGINT,mode));

				w.Char(0X); (*! record priority *)
				variable := scope.firstVariable;
				WHILE variable # NIL DO
					ASSERT(variable.type # NIL);
					Symbol(variable.type,variable.name,variable.access,variable.untraced,FALSE, FALSE, FALSE, FALSE);
					variable := variable.nextVariable;
				END;

				procedure := scope.firstProcedure;
				IF procedure # NIL THEN
					w.RawNum(sfTProcedure);
					WHILE procedure # NIL DO
						procedureType := procedure.type(SyntaxTree.ProcedureType);
						IF (procedure.access * SyntaxTree.Internal = procedure.access) THEN  (* not exported method *)
							Symbol(procedureType.returnType,procedure.name,procedure.access,FALSE, procedureType.isRealtime,procedure.isConstructor,procedure IS SyntaxTree.Operator, FALSE);
							procedure.GetName(name);
							w.RawString(name);
						ELSE (* exported method *)
							Symbol(procedureType.returnType,procedure.name,SyntaxTree.Public (*! for compatiblity should be procedure.access *),
							FALSE, procedureType.isRealtime,procedure.isConstructor, procedure IS SyntaxTree.Operator, FALSE
							);
						END;
						ParameterList(procedure.type(SyntaxTree.ProcedureType));
						(*! inline *)
						procedure := procedure.nextProcedure;
					END;
				END;
				w.RawNum(sfEnd);
			END Record;

			(* returns the index of module importedModule in the list of module module *)
			PROCEDURE ModuleIndex(module: SyntaxTree.Module; importedModule: SyntaxTree.Module): LONGINT;
			VAR import: SyntaxTree.Import; index: LONGINT;
			BEGIN import := module.moduleScope.firstImport;
				index := 0;
				WHILE (import # NIL) & (import.module # importedModule) DO
					IF (* (import.direct) & *)  ~Global.IsSystemModule(import.module) THEN INC(index) END;
					import := import.nextImport;
				END;
				ASSERT(import # NIL);
				RETURN index;
			END ModuleIndex;

			(*
				Type =
					TypeReference
					|BasicType
					|ImportedType
					|UserType.

				TypeReference = number:RawNum(<0)
				BasicType = sfTypeBoolean |  .. |  sfLastType.
				ImportedType = ModuleNumber (structName:RawString | 0X typeIndex:RawNum)
				ModuleNumber = sfMod1 | .. | sfModOther-1 | sfModOther moduleNumber:RawNum

				UserType = [sfInvisible] [sfSysFlag sysFlag:RawNum] UserType2
				UserType2=
					sfTypeOpenArray baseType:Type name:RawString flags:RawNum
					|sfTypeStaticArray baseType:Type name:RawString flags:RawNum length:RawNum
					|sfOpenMathArray baseType:Type name:RawString
					|sfStaticMathArray baseType:Type name:RawString length:RawNum
					|sfTypeTensor baseType:Type name:RawString
					|sfTypePointer baseType:Type name:RawString flags:RawNum
					|sfTypeRecord baseType:Type name:RawString flags:RawNum Record
					|sfTypeProcedure baseType:Type name:RawString flags:RawNum ParameterList
					|sfTypeEnumeration enumerationBase:Type name:RawString
			*)
			PROCEDURE Type(type: SyntaxTree.Type);
			VAR typeIndex,moduleIndex: LONGINT; name:SyntaxTree.IdentifierString; importedModule: SyntaxTree.Module; attribute: Attribute;
				baseType: SyntaxTree.Type; typeDeclaration : SyntaxTree.TypeDeclaration; flags: SET; size: LONGINT;
			BEGIN
				IF type = NIL THEN
					IF TraceExport IN Trace THEN
						D.Str("Type / Basic / NIL "); D.Ln
					END;
					w.RawNum(sfTypeNoType); RETURN
				END;

				type := type.resolved;
				typeDeclaration := type.typeDeclaration;
				IF (typeDeclaration # NIL) & (typeDeclaration.declaredType.resolved # type) THEN  typeDeclaration := NIL END;
				size := type.sizeInBits;
				IF type IS SyntaxTree.BasicType THEN (* BasicType  *)
					IF type IS SyntaxTree.BooleanType THEN w.RawNum(sfTypeBoolean);
					IF TraceExport IN Trace THEN
						D.Str("Type / Basic / Boolean "); D.Ln
					END;
					ELSIF type IS SyntaxTree.CharacterType THEN
						IF size = 8 THEN
							w.RawNum(sfTypeChar8);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Char8"); D.Ln
							END;
						ELSIF size = 16 THEN
							w.RawNum(sfTypeChar16);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Char16"); D.Ln
							END;
						ELSIF size = 32 THEN
							w.RawNum(sfTypeChar32);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Char32"); D.Ln
							END;
						END
					ELSIF type IS SyntaxTree.IntegerType THEN
						IF type(SyntaxTree.IntegerType).signed THEN
							IF size = 8 THEN
								w.RawNum(sfTypeShortint);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Shortint"); D.Ln
								END;
							ELSIF size = 16 THEN
								w.RawNum(sfTypeInteger);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Integer"); D.Ln
								END;
							ELSIF size = 32 THEN
								w.RawNum(sfTypeLongint);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Longint"); D.Ln
								END;
							ELSIF size = 64 THEN w.RawNum(sfTypeHugeint);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Hugeint"); D.Ln
								END;
							END;
						ELSE
							IF size = 8 THEN
								w.RawNum(sfTypeUnsigned8);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Unsigned8"); D.Ln
								END;
							ELSIF size = 16 THEN
								w.RawNum(sfTypeUnsigned16);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Unsigned16"); D.Ln
								END;
							ELSIF size = 32 THEN
								w.RawNum(sfTypeUnsigned32);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Unsigned32"); D.Ln
								END;
							ELSIF size = 64 THEN w.RawNum(sfTypeUnsigned64);
								IF TraceExport IN Trace THEN
									D.Str("Type / Basic / Unsigned64"); D.Ln
								END;
							END;
						END;
					ELSIF type IS SyntaxTree.FloatType THEN
						IF size = 32 THEN
							w.RawNum(sfTypeReal);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Real"); D.Ln
							END;
						ELSIF size = 64 THEN
							w.RawNum(sfTypeLongreal);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Longreal"); D.Ln
							END;
						END;

					ELSIF type IS SyntaxTree.ComplexType THEN
						IF size = 64 THEN
							w.RawNum(sfTypeComplex);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Complex"); D.Ln
							END;
						ELSIF size = 128 THEN
							w.RawNum(sfTypeLongcomplex);
							IF TraceExport IN Trace THEN
								D.Str("Type / Basic / Longcomplex"); D.Ln
							END;
						END;

					ELSIF type IS SyntaxTree.SetType THEN
						w.RawNum(sfTypeSet);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / Set"); D.Ln
						END;
					ELSIF type IS SyntaxTree.NilType THEN w.RawNum(sfTypeNilType);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / NilType"); D.Ln
						END;
					ELSIF type IS SyntaxTree.AnyType THEN w.RawNum(sfTypeAny);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / Any"); D.Ln
						END;
					ELSIF type IS SyntaxTree.ObjectType THEN
						w.RawNum(sfTypeObject);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / Object"); D.Ln
						END;
					ELSIF type IS SyntaxTree.ByteType THEN
						w.RawNum(sfTypeByte);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / Byte"); D.Ln
						END;
					ELSIF type IS SyntaxTree.RangeType THEN w.RawNum(sfTypeRange);
						IF TraceExport IN Trace THEN
							D.Str("Type / Basic / Range"); D.Ln
						END;

					ELSIF type IS SyntaxTree.AddressType THEN w.RawNum(sfTypeAddress) (*! compatibility with PACO *)
					ELSIF type IS SyntaxTree.SizeType THEN w.RawNum(sfTypeSize)
					ELSE HALT(100)
					END;
				ELSIF type IS SyntaxTree.StringType THEN (* special case BasicType : StringType *)
					IF TraceExport IN Trace THEN
						D.Str("Type / String "); D.Ln
					END;
					w.RawNum(sfTypeString); (*! string length should be written here also *)
				ELSIF (typeDeclaration # NIL) & (typeDeclaration.scope # NIL) & (typeDeclaration.scope.ownerModule # module) THEN (* ImportedType *)
					(* imported, reexport:
						ImportedType = ModuleNumber (structName:RawString | 0X typeIndex:RawNum)
						ModuleNumber = sfMod1 | .. | sfModOther-1 | sfModOther moduleNumber:RawNum
					*)
					typeDeclaration.GetName(name);

					importedModule := typeDeclaration.scope.ownerModule;
					moduleIndex := ModuleIndex(module,importedModule);
					ASSERT(moduleIndex >= 0);

					IF moduleIndex >= sfModOther - sfMod1 THEN w.RawNum(sfModOther); w.RawNum(moduleIndex)
					ELSE w.RawNum(sfMod1 + moduleIndex)
					END;
					attribute := indexToAttribute.GetAttribute(moduleIndex);
					typeIndex := attribute.typeToIndex.GetIndex(type);

					IF TraceExport IN Trace THEN
						D.Str("Type / Reexport "); D.Str(name); D.Str(":"); D.Int(typeIndex,1); D.String(" in "); D.Str0(importedModule.name); D.String(":"); D.Int(moduleIndex,1);D.Ln
					END;
					IF typeIndex = Undef THEN (* not yet written import: structName:RawString *)
						type.typeDeclaration.GetName(name);
						w.RawString(name);
						attribute.typeToIndex.PutIndex(type,attribute.numberTypes); INC(attribute.numberTypes);
					ELSE (* previously written import: 0X typeIndex:RawNum *)
						w.Char(0X); w.RawNum(typeIndex);
					END;
				ELSE
					IF TraceExport IN Trace THEN
						D.Str("Type / User "); D.Ln
					END;
					typeIndex := lookup.GetIndex(type);

					IF typeIndex # Undef THEN (* already written: TypeReference = number:RawNum (<0)*)
						IF TraceExport IN Trace THEN
							D.Str("Type / User / AlreadyWritten "); D.Ln
						END;
						w.RawNum(-typeIndex)
					ELSE (* UserType *)
						IF TraceExport IN Trace THEN D.Str("Type / UserType "); D.Ln END;
						lookup.PutIndex(type,numberType); INC(numberType);

						name:="";
						IF  typeDeclaration#NIL THEN typeDeclaration.GetName(name);
							IF typeDeclaration.access* SyntaxTree.Public={} THEN
								w.RawNum(sfInvisible);
							END;
						END;

						flags := {};
						IF  type IS SyntaxTree.RecordType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / RecordType "); D.Str(name); D.Ln END;
							WITH type: SyntaxTree.RecordType DO
								w.RawNum(sfTypeRecord);
								baseType := type.baseType;
								Type(baseType);
								w.RawString(name);
								IF type.isRealtime THEN INCL(flags,sfRealtime) END;
								w.RawNum(SYSTEM.VAL(LONGINT,flags));
								Record(type)
							END
						ELSIF type IS SyntaxTree.PointerType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / PointerType "); D.Str(name); D.Ln END;
							w.RawNum(sfTypePointer);
							Type(type(SyntaxTree.PointerType).pointerBase);
							w.RawString(name);
							WITH type: SyntaxTree.PointerType DO
								IF type.isUnsafe THEN INCL(flags,sfUnsafe) END;
								IF type.isRealtime THEN INCL(flags,sfRealtime) END;
								IF type.isDisposable THEN INCL(flags,sfDisposable) END;
							END;
							w.RawNum(SYSTEM.VAL(LONGINT,flags));
						ELSIF type IS SyntaxTree.ArrayType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / ArrayType "); D.Str(name); D.Ln END;
							WITH type: SyntaxTree.ArrayType DO
								IF type.form = SyntaxTree.Open THEN
									w.RawNum(sfTypeOpenArray)
								ELSIF type.form = SyntaxTree.Static THEN
									w.RawNum(sfTypeStaticArray)
								ELSE HALT(100)
								END;
								Type(type.arrayBase);
								w.RawString(name);
								IF type.isRealtime THEN INCL(flags,sfRealtime) END;
								w.RawNum(SYSTEM.VAL(LONGINT,flags));
								IF type.form = SyntaxTree.Static THEN
									w.RawNum(type.staticLength);
								END;
							END;
						ELSIF type IS SyntaxTree.MathArrayType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / MathArrayType "); D.Str(name); D.Ln END;
							WITH type: SyntaxTree.MathArrayType DO
								IF type.form = SyntaxTree.Open THEN
									w.RawNum(sfTypeOpenMathArray)
								ELSIF type.form = SyntaxTree.Static THEN
									w.RawNum(sfTypeStaticMathArray)
								ELSIF type.form = SyntaxTree.Tensor THEN
									w.RawNum(sfTypeTensor)
								ELSE HALT(100)
								END;
								Type(type.arrayBase);
								w.RawString(name);
								IF type.isRealtime THEN INCL(flags,sfRealtime) END;
								w.RawNum(SYSTEM.VAL(LONGINT,flags));
								IF type.form = SyntaxTree.Static THEN
									w.RawNum(type.staticLength);
								END;
							END;
						ELSIF type IS SyntaxTree.ProcedureType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / ProcedureType"); D.Str(name); D.Ln END;
							WITH type: SyntaxTree.ProcedureType DO
								IF type.isDelegate THEN
									w.RawNum(sfSysFlag); w.RawNum(sfDelegate);
								END;
								w.RawNum(sfTypeProcedure);
								Type(type.returnType);
								w.RawString(name);

								IF type.callingConvention =  SyntaxTree.WinAPICallingConvention THEN
									INCL(flags,sfWinAPIParam);
								ELSIF  type.callingConvention =  SyntaxTree.CCallingConvention  THEN
									INCL(flags,sfCParam);
								ELSIF  type.callingConvention =  SyntaxTree.DarwinCCallingConvention  THEN
									INCL(flags,sfDarwinCParam);
								END;
								IF type.isRealtime THEN
									INCL(flags,sfRealtime)
								END;
								w.RawNum(SYSTEM.VAL(LONGINT,flags));

								ParameterList(type);
							END;
						ELSIF type IS SyntaxTree.EnumerationType THEN
							IF TraceExport IN Trace THEN D.Str("Type / UserType / EnumerationType"); D.Str(name); D.Ln END;
							WITH type: SyntaxTree.EnumerationType DO
								w.RawNum(sfTypeEnumeration);
								Type(type.enumerationBase);
								w.RawString(name);
								EnumerationList(type.enumerationScope);
							END;
						ELSE HALT(200)
						END;
					END;
				END;
			END Type;

			(*
			EnumerationList = {name:RawString} 0X;
			*)
			PROCEDURE EnumerationList(enumerationScope: SyntaxTree.EnumerationScope);
			VAR name: SyntaxTree.IdentifierString; enumerator: SyntaxTree.Constant;
			BEGIN
				enumerator := enumerationScope.firstConstant;
				WHILE enumerator # NIL DO
					enumerator.GetName(name);
					IF enumerator.access * SyntaxTree.Public = {} THEN
						w.RawString("@");
					ELSE
						w.RawString(name);
					END;
					Value(enumerator.value.resolved);
					enumerator := enumerator.nextConstant;
				END;
				w.RawString("");
			END EnumerationList;

			(* ParameterList =
				{ [sfObjFlag sfWinAPIParam | sfObjFlag sfCParam | sfObjFlag sfDarwinCParam] [sfVar] [sfReadOnly] Type name:RawString } sfEnd
			*)
			PROCEDURE ParameterList(procedureType: SyntaxTree.ProcedureType);
			VAR flags: SET; name: SyntaxTree.IdentifierString;
				PROCEDURE Parameters(parameter: SyntaxTree.Parameter; reverse: BOOLEAN);
				VAR procedureType: SyntaxTree.ProcedureType;
				BEGIN
					WHILE parameter # NIL DO
						(*! the calling convention should not be expressed via the parameters (compatiblity with old compiler) *)
						procedureType := parameter.ownerType(SyntaxTree.ProcedureType);
						IF  procedureType.callingConvention = SyntaxTree.WinAPICallingConvention THEN
							w.RawNum(sfObjFlag); w.RawNum(sfWinAPIParam);
						ELSIF procedureType.callingConvention = SyntaxTree.CCallingConvention THEN
							w.RawNum(sfObjFlag); w.RawNum(sfCParam);
						ELSIF procedureType.callingConvention = SyntaxTree.DarwinCCallingConvention THEN
							w.RawNum(sfObjFlag); w.RawNum(sfDarwinCParam);
						END;

						IF parameter.kind = SyntaxTree.VarParameter THEN
							w.RawNum(sfVar)
						ELSIF parameter.kind = SyntaxTree.ConstParameter THEN
							IF (parameter.type.resolved IS SyntaxTree.ArrayType) OR (parameter.type.resolved IS SyntaxTree.RecordType) THEN
								w.RawNum(sfVar);
							END; (* cf. FingerPrint.FPSignature *)
							w.RawNum(sfReadOnly);
						END;
						Type(parameter.type);
						parameter.GetName(name);
						w.RawString(name);
						IF reverse THEN
							parameter := parameter.prevParameter
						ELSE
							parameter := parameter.nextParameter
						END;
					END;
				END Parameters;

			BEGIN
				IF procedureType.callingConvention # SyntaxTree.OberonCallingConvention  THEN
					(*! if a procedure has a return type, then it has a return parameter (new)
					ASSERT(procedureType.returnParameter = NIL);
					*)
					Parameters(procedureType.lastParameter,TRUE);
				ELSE
					Parameters(procedureType.firstParameter,FALSE);
				END;
				w.RawNum(sfEnd);
			END ParameterList;

			PROCEDURE Inline(procedureScope: SyntaxTree.ProcedureScope);
			VAR len,count,pos: LONGINT; code: SyntaxTree.Code; ch: CHAR;
			BEGIN
				code := procedureScope.body.code;
				IF code.inlineCode # NIL THEN
					len := code.inlineCode.GetSize() DIV 8;
				ELSE
					len := 0
				END;
				count := 0; pos := 0;

				IF len = 0 THEN
					w.Char(0X);
				ELSE
					WHILE pos < len DO
						IF count = 0 THEN
							count := 255;
							IF len < 255 THEN count := len END;
							w.Char(CHR(count))
						END;
						ch := CHR(code.inlineCode.GetBits(pos*8,8));
						w.Char(ch);
						INC(pos); DEC(count)
					END;
				END;
				w.Char(0X);
			END Inline;

			(* Symbol =
				[sfObjFlag flag:RawNum] [sfReadOnly] Type Name
			*)
			PROCEDURE Symbol(type: SyntaxTree.Type; name: SyntaxTree.Identifier; visibility: SET;untraced, realtime, constructor, operator, isDynamic: BOOLEAN);
			VAR string,string2: SyntaxTree.IdentifierString;
			BEGIN
				IF TraceExport IN Trace THEN
					Basic.GetString(name,string);
					D.Str("Symbol "); D.Str(string); D.Ln;
				END;
				IF untraced THEN w.RawNum(sfObjFlag); w.RawNum(sfUntraced)
				ELSIF realtime  THEN w.RawNum(sfObjFlag); w.RawNum(sfRealtime)
				END;
				IF operator THEN w.RawNum(sfObjFlag); w.RawNum(sfOperator) END;
				IF isDynamic THEN w.RawNum(sfObjFlag); w.RawNum(sfDynamic) END;
				IF (SyntaxTree.PublicRead IN visibility) & ~(SyntaxTree.PublicWrite IN visibility) THEN
					w.RawNum(sfReadOnly);
				END;
				Type(type);
				IF visibility * SyntaxTree.Internal = visibility THEN
					string2 := "";
					IF constructor THEN string2 := "&" END;
				ELSE Basic.GetString(name,string);
					IF constructor THEN
						Basic.Concat(string2,"&",string,"");
					ELSE
						string2 := string
					END;
				END;
				w.RawString(string2);
			END Symbol;

			(*
				SymbolFile =
				flags:RawSet
				Imports
				[sfSysFlag flags:Number]
				[sfConst {Symbol Value}]
				[sfVar {Symbol}]
				[sfXProcedure {Symbol ParameterList}]
				[sfOperator {Symbol ParameterList [sfInline Inline]}]
				[sfCProcedure {Symbol ParameterList Inline}]
				[sfAlias {declaredType:Type Name}]
				[sfType {declaredType:Type}]
				sfEnd
			*)
			PROCEDURE Module(module: SyntaxTree.Module);
			VAR constant: SyntaxTree.Constant; name: SyntaxTree.IdentifierString; first: BOOLEAN;
				variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration; procedure: SyntaxTree.Procedure;
				procedureType: SyntaxTree.ProcedureType;
			BEGIN
				IF TraceExport IN Trace THEN
					module.GetName(name);
					D.Str("BINARY SYMBOL FILE EXPORT "); D.Str(name); D.Ln;
				END;

				w.RawSet({}); (* compilation flags *)

				(* overloading flags omitted *)

				(* import section: write names of imported modules *)
				Imports(module.moduleScope.firstImport);

				(* constants *)
				IF TraceExport IN Trace THEN
					D.Str("exporting constants "); D.Ln;
				END;
				first :=TRUE;
				constant := module.moduleScope.firstConstant;
				WHILE constant # NIL DO
					IF constant.access * SyntaxTree.Public # {} THEN
						IF first THEN w.RawNum(sfConst); first := FALSE END;
						Symbol(constant.type,constant.name,SyntaxTree.Public (*! for compatiblity should be constant.access *) ,FALSE,FALSE,FALSE,FALSE, FALSE);
						constant.GetName(name);
						Value(constant.value.resolved(SyntaxTree.Value))
					END;
					constant := constant.nextConstant;
				END;

				(* variables *)
				IF TraceExport IN Trace THEN
					D.Str("exporting variables "); D.Ln;
				END;
				first := TRUE;
				variable := module.moduleScope.firstVariable;
				WHILE variable # NIL DO
					IF variable.access * SyntaxTree.Public # {} THEN
						IF first THEN w.RawNum(sfVar); first := FALSE END;
						Symbol(variable.type,variable.name,variable.access,variable.untraced, FALSE, FALSE, FALSE, FALSE);
					END;
					variable := variable.nextVariable;
				END;

				(* procedures: normal *)
				IF TraceExport IN Trace THEN
					D.Str("exporting procedures "); D.Ln;
				END;
				first := TRUE;
				procedure := module.moduleScope.firstProcedure;
				WHILE procedure # NIL DO
					IF (procedure.access * SyntaxTree.Public # {}) & ~(procedure IS SyntaxTree.Operator)  THEN
						procedureType := procedure.type(SyntaxTree.ProcedureType);
						IF ~procedure.isInline  THEN
							IF first THEN w.RawNum(sfXProcedure); first := FALSE END;
							Symbol(procedureType.returnType,procedure.name,SyntaxTree.Public (*! for compatiblity should be procedure.access *),
							FALSE, procedureType.isRealtime, procedure.isConstructor, FALSE, FALSE);
							ParameterList(procedureType);
						END;
					END;
					procedure := procedure.nextProcedure;
				END;

				(* procedures: operators *)
				IF TraceExport IN Trace THEN
					D.Str("exporting operators"); D.Ln;
				END;
				first := TRUE;
				procedure := module.moduleScope.firstProcedure;
				WHILE procedure # NIL DO
					IF (procedure.access * SyntaxTree.Public # {}) & (procedure IS SyntaxTree.Operator)  THEN
						procedureType := procedure.type(SyntaxTree.ProcedureType);
						IF first THEN w.RawNum(sfOperator); first := FALSE END;
						Symbol(procedureType.returnType,procedure.name,SyntaxTree.Public (*! for compatiblity should be procedure.access *),
						FALSE, procedure.isInline, procedure.isConstructor, FALSE, procedure(SyntaxTree.Operator).isDynamic);
						ParameterList(procedureType);
						IF procedure.isInline THEN
							w.RawNum(sfInline); Inline(procedure.procedureScope);
						END;
					END;
					procedure := procedure.nextProcedure;
				END;

				(* procedures: inline *)
				IF TraceExport IN Trace THEN
					D.Str("exporting inline procedures"); D.Ln;
				END;
				first := TRUE;
				procedure := module.moduleScope.firstProcedure;
				WHILE procedure # NIL DO
					IF (procedure.access * SyntaxTree.Public # {}) & ~(procedure IS SyntaxTree.Operator)  THEN
						procedureType := procedure.type(SyntaxTree.ProcedureType);
						IF procedure.isInline THEN
							IF first THEN w.RawNum(sfCProcedure); first := FALSE END;
							Symbol(procedureType.returnType,procedure.name,SyntaxTree.Public (*! for compatiblity should be procedure.access *),
							FALSE, procedure.isInline, procedure.isConstructor, FALSE, FALSE);
							ParameterList(procedureType);
							Inline(procedure.procedureScope);
						END;
					END;
					procedure := procedure.nextProcedure;
				END;

				(* type declarations: aliases *)
				IF TraceExport IN Trace THEN
					D.Str("exporting type declarations aliases"); D.Ln;
				END;
				first := TRUE;
				typeDeclaration := module.moduleScope.firstTypeDeclaration;
				WHILE typeDeclaration # NIL DO
					IF typeDeclaration.access * SyntaxTree.Public # {} THEN
						IF typeDeclaration.declaredType IS SyntaxTree.QualifiedType THEN
							IF first THEN w.RawNum(sfAlias); first := FALSE END;
							Type(typeDeclaration.declaredType);
							typeDeclaration.GetName(name);
							w.RawString(name);
						END;
					END;
					typeDeclaration := typeDeclaration.nextTypeDeclaration;
				END;

				(* type declarations: declarations *)
				IF TraceExport IN Trace THEN
					D.Str("exporting type declarations"); D.Ln;
				END;
				first := TRUE;
				typeDeclaration := module.moduleScope.firstTypeDeclaration;
				WHILE typeDeclaration # NIL DO
					IF typeDeclaration.access * SyntaxTree.Public # {} THEN
						IF ~(typeDeclaration.declaredType IS SyntaxTree.QualifiedType) THEN
							IF first THEN w.RawNum(sfType); first := FALSE END;
							Type(typeDeclaration.declaredType);
						END;
					END;
					typeDeclaration := typeDeclaration.nextTypeDeclaration;
				END;

				IF TraceExport IN Trace THEN
					module.GetName(name);
					D.Str("BINARY SYMBOL FILE EXPORT DONE "); D.Str(name); D.Ln;
				END;

				w.RawNum(sfEnd);
			END Module;

		BEGIN
			file := Files.New("");

			IF ~noInterfaceCheck THEN
				InterfaceComparison.CompareThis(module,SELF,diagnostics,importCache,flags);

				IF noRedefinition OR noModification THEN
					IF (InterfaceComparison.Redefined IN flags) THEN
						diagnostics.Error(module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," no redefinition of symbol file allowed");
						RETURN FALSE;
					END;
				END;
				IF noModification THEN
					IF (InterfaceComparison.Extended IN flags) THEN
						diagnostics.Error(module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," no extension of symbol file allowed");
						RETURN FALSE;
					END;
				END;
			END;

			NEW(w,file,0);
			NEW(lookup,100); NEW(indexToAttribute,16);
			numberType := 0;
			Module(module);
			w.Update();
			Files.Register(file);
			RETURN TRUE
		END Export;


		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
			options.Add(0X,"symbolFileExtension",Options.String);
			options.Add(0X,"noRedefinition",Options.Flag);
			options.Add(0X,"noModification",Options.Flag);
			options.Add(0X,"noInterfaceCheck",Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		BEGIN
			IF ~options.GetString("symbolFileExtension",extension) THEN
				extension := Machine.DefaultObjectFileExtension
			END;
			noRedefinition := options.GetFlag("noRedefinition");
			noModification := options.GetFlag("noModification");
			noInterfaceCheck := options.GetFlag("noInterfaceCheck");
		END GetOptions;

	END BinarySymbolFile;

	VAR


	(* move to basic *)
	PROCEDURE MakeFileName(VAR file: ARRAY OF CHAR; CONST name, prefix, suffix: ARRAY OF CHAR);
	VAR i, j: LONGINT;
	BEGIN
		i := 0; WHILE prefix[i] # 0X DO  file[i] := prefix[i];  INC(i)  END;
		j := 0; WHILE name[j] # 0X DO  file[i+j] := name[j];  INC(j)  END;
		INC(i, j);
		j := 0; WHILE suffix[j] # 0X DO file[i+j] := suffix[j]; INC(j)  END;
		file[i+j] := 0X;
	END MakeFileName;

	(** OpenSymFile - Open a symfile for reading *)

	PROCEDURE OpenSymFile(CONST name,prefix,suffix: ARRAY OF CHAR;  VAR r: Streams.Reader; VAR version: CHAR): BOOLEAN;
		VAR res: BOOLEAN;  file: Files.FileName;  f: Files.File; R: Files.Reader; dummy: LONGINT; ch: CHAR;
	BEGIN
		res := FALSE;
		MakeFileName(file, name, prefix, suffix);
		f := Files.Old(file);
		IF f # NIL THEN
			NEW(R,f,0);
			r := R;
			r.Char(ch);
			IF ch = FileTag THEN
				r.Char(version);
				ASSERT(version = NoZeroCompress); r.Char(version);
				IF version = FileVersion THEN
					r.RawNum(dummy);	(*skip symfile size*)
				ELSIF (version >= FileVersionOC) & (version <= FileVersionCurrent) THEN
					r.RawLInt(dummy); (* new in OC: symbol file size uncompressed *)
				ELSE
					HALT(100)
				END;
				res := TRUE
			END
		END;
		RETURN res
	END OpenSymFile;



PROCEDURE Get*(): Formats.SymbolFileFormat;
VAR symbolFileFormat: BinarySymbolFile;
BEGIN
	NEW(symbolFileFormat); symbolFileFormat.file := Files.New("");  RETURN symbolFileFormat
END Get;


PROCEDURE Test*(context: Commands.Context);
VAR moduleName: SyntaxTree.IdentifierString; module: SyntaxTree.Module;
		log2: Basic.Writer; time: LONGINT;
		p: Printout.Printer;
		symbolFileFormat: BinarySymbolFile;
		options: Options.Options;
		extension: Basic.FileName;
BEGIN
	NEW(options);
		NEW(symbolFileFormat);
		symbolFileFormat.DefineOptions(options);
	IF options.Parse(context.arg,context.error) THEN
		symbolFileFormat.GetOptions(options);
		context.arg.SkipWhitespace; context.arg.String(moduleName);
		time := Kernel.GetTicks();
		symbolFileFormat.Initialize(NIL,Global.DefaultSystem(),"");
		module := symbolFileFormat.Import(moduleName,NIL);
		time := Kernel.GetTicks()-time;
		D.Str("importer elapsed ms: "); D.Int(time,10); D.Ln;
		D.Update;

		log2 := Basic.GetWriter(Basic.GetDebugWriter("SymbolFile"));
		p := Printout.NewPrinter(log2,Printout.SymbolFile,FALSE);
		log2.String("Interface of "); log2.String(moduleName); log2.Ln;
		log2.Ln;

		p.Module(module);
		log2.Ln;
		log2.Ln;
		log2.String(" -------------------------------------------------------------- "); log2.Ln;
		log2.Ln;
		log2.Ln;

		p := Printout.NewPrinter(log2,Printout.All,TRUE);
		p.Module(module);
		log2.Update;
	END;
END Test;


END FoxBinarySymbolFile.


SystemTools.Free FoxBinarySymbolFile ~
FoxBinarySymbolFile.Test  Visualizer   ~

Compiler.Compile -PCtp Visualizer.Sym ~

FoxBinarySymbolFile.Test  Oberon.Oberon   ~
FoxBinarySymbolFile.Test   --symbolFileExtension=".Obw" Dump    ~



