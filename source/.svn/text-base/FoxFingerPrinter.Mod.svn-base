MODULE FoxFingerPrinter; (** AUTHOR "fof"; PURPOSE "FingerPrinting"; *)
(* literature for the fingerprinting: Dissertation Crelier *)

IMPORT SyntaxTree := FoxSyntaxTree, Basic := FoxBasic, SYSTEM, Global := FoxGlobal,Scanner := FoxScanner,
		D := Debugging, Streams;

(** FingerPrinting
	FP(TypeDeclaration)        = 0 <*> fpModeType -> Name -> Visibility <*> FP(Type).
	FP(ConstantDeclaration)    = 0 <*> fpModeConstant -> Name -> Visibility <*> FP(Type) -> Basic -> Value.
	FP(VariableDeclaration)    = 0 <*> fpModePar -> Name -> Visibility <*> FP(Type).
	FP(ProcedureDeclaration)   = 0 <*> fpModeInlineProcedure -> Name -> Visibility <*> FP(Type) -> Code.
	                            | 0 <*> fpModeExportedProcedure -> Name -> Visibility <*> FP(Type)
	Name(fp,name)              = fp <*> name[0] <*> ... <*> name[n].
	Visibility(fp,vis)         = fp <*> fpExtern | fp <*> fpExternR | fp <*> fpOther <*> vis.
	Value(fp)                  = fp <*> fpTrue | fp <*> fpFalse | fp <*> integer  | fp <*> intlow <*> inthigh | fp -> Name
	FP(Type)                   = FP(BasicType) | FP(RecordType) | FP(PointerType)

                           	 	| FP(ArrayType) | FP(MathArrayType) | FP(ProcedurType)

	FP(BasicType)              = fpTypeChar8 | fpTypeChar16 | fpTypeChar32
	                            | fpTypeShortint | fpTypeInteger | fpTypeLongint | fpTypeHugeint
	                            | fpTypeReal | fpTypeLongreal
	                            | fpTypeSet | fpTypePointer |fpTypeString
	                            | fpTypeByte | fpTypeAll | fpTypeSame | fpTypeRange | fpTypeBoolean.
	PublicFP(BasicType)        = FP(basicType).
	PrivateFP(BasicType)       = sizeof(basicType).

	FP(RecordType)             = fpTypeComposite <*> fptypeRecord
	                            [ -> Name(moduleName) -> Name(typeName)] [<*> FP(baseType)]
	PublicFP(RecordType)       = FP(recordType) [<*> PublicFP(baseType)] {<*> FP(method) <*> methodNumber }
	                            {<*> PublicFP(fieldType) <*> offset(field) <*> FP(field)} <*> flags.
	PrivateFP(RecordType)      = FP(recordType) [<*> PrivateFP(baseType)] {<*> FP(method) <*> methodNumber }
	                            {<*> PrivateFP(fieldType) <*> offset(field) <*> FP(field)}

	FP(Method)                 = 0 <*> fpModeMethod -> Name(methodName) -> Signature(method).

	FP(Field)                  = 0 <*> fpModeField -> Name(fieldName) -> Visibility [<*> fpUntraced] <*> FP(type).

	FP(PointerType)            = fpTypePointer <*> fpTypeBasic -> Name <*> FP(baseType).
	PublicFP(PointerType)      = 0.
	PrivateFP(PointerType)     = 0.

	FP(ArrayType)              = fpTypeComposite <*> (fpTypeOpenArray | fpTypeStaticArray)
	                            -> Name <*> FP(baseType) [<*> length].
	PublicFP(ArrayType)        = FP(arrayType).
	PrivateFP(ArrayType)       = FP(arrayType).

	FP(MathArrayType)          = fpTypeComposite <*> (fpTypeOpenArray | fpTypeStaticArray)
	                            -> Name <*> FP(baseType) [<*> length].
	PublicFP(MathArrayType)    = FP(arrayType).
	PrivateFP(MathArrayType)   = FP(arrayType).

	FP(ProcedureType)          = fpTypeProcedure <*> fpTypeBasic [<*> fpDelegate]-> Name.
	PublicFP(ProcedureType)    = FP(arrayType) -> Signature(procedureType)
	PrivateFP(ProcedureType)   = FP(arrayType)-> Signature(procedureType).

	Signature(f)               = f <*> FP(returnType)
	                            { <*> (fpModeVarParameter | fpModeConstParameter | fpModePar)
	                            <*> FP(parameterType) [-> Name(parameterName)]  }
**)


CONST
	(*FingerPrints/Obj Modes*)
	fpModeVar=1;
	fpModePar=1;
	fpModeVarPar=2;
	fpModeConstPar=fpModeVarPar; (*! for compatibility, must be changed *)
	fpModeConst=3;
	fpModeField=4;
	fpModeType=5;
	fpModeExportedProcedure=7;
	fpModeInlineProcedure=9;
	fpModeMethod=13;

	(*FingerPrints/Type Forms*)
	fpTypeByte = 1;
	fpTypeBoolean=2;
	fpTypeChar8=3;
	fpTypeShortint=4;
	fpTypeInteger=5;
	fpTypeLongint=6;
	fpTypeReal=7;
	fpTypeLongreal=8;
	fpTypeSet=9;
	fpTypeString=10;
	fpTypeNone = 12;
	fpTypePointer=13;
	fpTypeProcedure=14;
	fpTypeComposite=15;
	fpTypeHugeint=16;
	fpTypeChar16 = 17;
	fpTypeChar32 = 18;
	fpTypeAll = 19;
	fpTypeSame = 20;
	fpTypeRange = 21;
	fpTypeEnum = 22;
	fpTypePort = 23;
	fpTypeChannel = 23;
	fpTypeComplex = 24;
	fpTypeLongcomplex = 25;
	fpTypeModule=26;

	fpTypeBasic=1;
	fpTypeStaticArray=2;
	fpTypeDynamicArray=4;
	fpTypeOpenArray=5;
	fpTypeRecord=6;

	fpIntern=0;
	fpExtern=1;
	fpExternR=2;
	fpOther =3;

	fpFalse=0;
	fpTrue=1;

	fpHasBody = 1;
	fpProtected =4;
	fpActive = 5;

	fpDelegate = 5;
	fpSystemType = 6;

	fpUntraced = 4;

	Trace=FALSE;

TYPE
	FingerPrint = SyntaxTree.FingerPrint;

	FingerPrinter*= OBJECT (SyntaxTree.Visitor)
	VAR
		fp-: LONGINT; (* temporary fingerprint for values etc. *)
		fingerprint: FingerPrint;
		system-: Global.System;
		deep: BOOLEAN; (* public / private field of FP needed ? *)
		traceLevel: LONGINT;

		level: LONGINT;

		PROCEDURE & InitFingerPrinter*(system: Global.System);
		BEGIN fp:= 0; SELF.system := system; deep := FALSE; traceLevel := 0;
		END InitFingerPrinter;
		(** types *)

		(*
		FP(BasicType)        = | fpTypeByte | fpTypeAll | fpTypeSame | fpTypeRange | fpTypeBoolean.
                             | fpTypeSet | fpTypePointer
		PublicFP(BasicType)  = FP(basicType).
		PrivateFP(BasicType) = sizeof(basicType).
		*)
		PROCEDURE VisitBasicType(x: SyntaxTree.BasicType);
		BEGIN
		END VisitBasicType;

		PROCEDURE SetTypeFingerprint(x: SyntaxTree.Type; fp: LONGINT);
		VAR fingerprint: FingerPrint;
		BEGIN
			fingerprint := x.fingerprint;
			IF ~fingerprint.shallowAvailable THEN
				fingerprint.shallow := fp;
				fingerprint.public := fp;
				fingerprint.private := fp;
				fingerprint.shallowAvailable := TRUE;
				fingerprint.deepAvailable := TRUE; (* no distinction between deep and shallow fp necessary *)
				x.SetFingerPrint(fingerprint);
			END;
			SELF.fingerprint := fingerprint;
		END SetTypeFingerprint;

		PROCEDURE VisitRangeType(x: SyntaxTree.RangeType);
		VAR fingerprint: FingerPrint;
		BEGIN
			SetTypeFingerprint(x,fpTypeRange);
		END VisitRangeType;

		PROCEDURE VisitBooleanType(x: SyntaxTree.BooleanType);
		BEGIN
			SetTypeFingerprint(x,fpTypeBoolean);
		END VisitBooleanType;

		PROCEDURE VisitByteType(x: SyntaxTree.ByteType);
		BEGIN
			SetTypeFingerprint(x,fpTypeByte)
		END VisitByteType;

		PROCEDURE VisitSetType(x: SyntaxTree.SetType);
		BEGIN
			SetTypeFingerprint(x,fpTypeSet)
		END VisitSetType;

		PROCEDURE VisitNilType(x: SyntaxTree.NilType);
		BEGIN
			SetTypeFingerprint(x,fpTypePointer)
		END VisitNilType;

		PROCEDURE VisitAnyType(x: SyntaxTree.AnyType);
		BEGIN
			SetTypeFingerprint(x,fpTypePointer)
		END VisitAnyType;

		PROCEDURE VisitAddressType(x: SyntaxTree.AddressType);
		BEGIN
			SetTypeFingerprint(x,fpTypePointer)
		END VisitAddressType;

		PROCEDURE VisitSizeType(x: SyntaxTree.SizeType);
		BEGIN
			IF x.sizeInBits=8 THEN SetTypeFingerprint(x,fpTypeShortint)
			ELSIF x.sizeInBits = 16 THEN SetTypeFingerprint(x,fpTypeInteger)
			ELSIF x.sizeInBits = 32 THEN SetTypeFingerprint(x,fpTypeLongint)
			ELSIF x.sizeInBits = 64 THEN SetTypeFingerprint(x,fpTypeHugeint)
			ELSE HALT(100)
			END;
		END VisitSizeType;

		PROCEDURE VisitObjectType(x: SyntaxTree.ObjectType);
		BEGIN
			SetTypeFingerprint(x,fpTypePointer)
		END VisitObjectType;

		(*
		FP(BasicType)        = fpTypeChar8 | fpTypeChar16 | fpTypeChar32
		PublicFP(BasicType)  = FP(basicType).
		PrivateFP(BasicType) = sizeof(basicType).
		*)
		PROCEDURE VisitCharacterType(x: SyntaxTree.CharacterType);
		BEGIN
			IF x.sizeInBits = 8 THEN SetTypeFingerprint(x,fpTypeChar8)
			ELSIF x.sizeInBits = 16 THEN SetTypeFingerprint(x,fpTypeChar16)
			ELSIF x.sizeInBits =32 THEN SetTypeFingerprint(x,fpTypeChar32)
			ELSE HALT(100)
			END;
		END VisitCharacterType;

		(*
		FP(BasicType)        = fpTypeShortint | fpTypeInteger | fpTypeLongint | fpTypeLongint
		PublicFP(BasicType)  = FP(basicType).
		PrivateFP(BasicType) = sizeof(basicType).
		*)
		PROCEDURE VisitIntegerType(x: SyntaxTree.IntegerType);
		BEGIN
			IF x.sizeInBits=8 THEN SetTypeFingerprint(x,fpTypeShortint)
			ELSIF x.sizeInBits = 16 THEN SetTypeFingerprint(x,fpTypeInteger)
			ELSIF x.sizeInBits = 32 THEN SetTypeFingerprint(x,fpTypeLongint)
			ELSIF x.sizeInBits = 64 THEN SetTypeFingerprint(x,fpTypeHugeint)
			ELSE HALT(100)
			END;
		END VisitIntegerType;

		(*
		FP(BasicType)        = fpTypeReal | fpTypeLongreal
		PublicFP(BasicType)  = FP(basicType).
		PrivateFP(BasicType) = sizeof(basicType).
		*)
		PROCEDURE VisitFloatType(x: SyntaxTree.FloatType);
		BEGIN
			IF x.sizeInBits = 32 THEN SetTypeFingerprint(x,fpTypeReal)
			ELSIF x.sizeInBits = 64 THEN SetTypeFingerprint(x,fpTypeLongreal)
			ELSE HALT(100)
			END;
		END VisitFloatType;

		PROCEDURE VisitComplexType(x: SyntaxTree.ComplexType);
		BEGIN
			ASSERT(x.componentType # NIL);
			IF x.componentType.sizeInBits = 32 THEN SetTypeFingerprint(x,fpTypeComplex)
			ELSIF x.componentType.sizeInBits = 64 THEN SetTypeFingerprint(x,fpTypeLongcomplex)
			ELSE HALT(100)
			END
		END VisitComplexType;

		(*
		FP(BasicType)        = fpStringType
		PublicFP(BasicType)  = FP(basicType).
		PrivateFP(BasicType) = sizeof(basicType).
		*)
		PROCEDURE VisitStringType(x: SyntaxTree.StringType);
		BEGIN
			SetTypeFingerprint(x,fpTypeString);
		END VisitStringType;

		(**
			fp enumeration type
		**)
		PROCEDURE VisitEnumerationType(x: SyntaxTree.EnumerationType);
		VAR fingerprint: FingerPrint; enumerator: SyntaxTree.Constant; fp: LONGINT;
		BEGIN
			fingerprint := x.fingerprint;

			IF ~fingerprint.shallowAvailable THEN
				fp := fpTypeEnum;
				IF x.enumerationBase # NIL THEN
					FPType(fp,x.enumerationBase);
				END;
				enumerator := x.enumerationScope.firstConstant;
				WHILE enumerator # NIL DO
					IF enumerator.access * SyntaxTree.Public # {} THEN
						FPName(fp,enumerator.name);
					END;
					FPValue(fp,enumerator.value);
					enumerator := enumerator.nextConstant;
				END;
				fingerprint.shallow := fp;
				fingerprint.public := fingerprint.shallow;
				fingerprint.private := fingerprint.shallow;
				fingerprint.shallowAvailable := TRUE;
				fingerprint.deepAvailable := TRUE; (* no distinction between deep and shallow fp necessary *)
				x.SetFingerPrint(fingerprint);
			END;

			SELF.fingerprint := fingerprint

			(*! must be implemented
				IF x.enumerationBase # NIL THEN
					baseType := ResolveType(x.enumerationBase);
					resolved := baseType.resolved;
					enumerationBase := resolved(SyntaxTree.EnumerationType);
					baseScope := enumerationBase.enumerationScope;
					x.SetBaseValue(enumerationBase.baseValue + baseScope.numberEnumerators);
				END;
				CheckEnumerationScope(x.enumerationScope);
				x.SetState(SyntaxTree.Resolved);
			END;
			resolvedType := ResolvedType(x);
			*)
		END VisitEnumerationType;

		PROCEDURE VisitQualifiedType(x: SyntaxTree.QualifiedType);
		BEGIN
			x.resolved.Accept(SELF);
		END VisitQualifiedType;

		(*
		FP(ArrayType)              = fpTypeComposite <*> (fpTypeOpenArray | fpTypeStaticArray)
		                            -> Name <*> FP(baseType) [<*> length].
		PublicFP(ArrayType)        = FP(arrayType).
		PrivateFP(ArrayType)       = FP(arrayType).
		*)
		PROCEDURE VisitArrayType(x: SyntaxTree.ArrayType);
		VAR fingerprint: FingerPrint; deep: BOOLEAN; fp: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("ArrayType") END;
			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF ~fingerprint.shallowAvailable THEN
				fingerprint.shallowAvailable := TRUE; (* the fingerprinting may return to itself => avoid circles *)
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp,fpTypeComposite);
				IF x.form = SyntaxTree.Open THEN FPNumber(fp,fpTypeOpenArray)
				ELSIF x.form = SyntaxTree.Static THEN FPNumber(fp,fpTypeStaticArray)
				ELSIF x.form = SyntaxTree.SemiDynamic THEN FPNumber(fp, fpTypeDynamicArray);
				ELSE HALT(200)
				END;
				TypeName(fp,x);
				fingerprint.shallow := fp;
				x.SetFingerPrint(fingerprint);
				FPType(fp,x.arrayBase.resolved);

				IF x.form = SyntaxTree.Static THEN FPNumber(fp,x.staticLength) END;
				fingerprint.shallow := fp;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
			END;

			IF deep & ~fingerprint.deepAvailable THEN
				fingerprint.private := fingerprint.shallow;
				fingerprint.public := fingerprint.shallow;
				fingerprint.deepAvailable := TRUE; (* to avoid circles during base finger printing *)
				x.SetFingerPrint(fingerprint);
				x.arrayBase.Accept(SELF); (* make sure that base pointer is also deeply fped *)
			END;

			IF Trace THEN TraceExit("ArrayType",fingerprint) END;
			SELF.fingerprint := fingerprint;
		END VisitArrayType;

		(*

		FP(MathArrayType)          = fpTypeComposite <*> (fpTypeOpenArray | fpTypeStaticArray)
		                            -> Name <*> FP(baseType) [<*> length].
		PublicFP(MathArrayType)    = FP(arrayType).
		PrivateFP(MathArrayType)   = FP(arrayType).
		*)
		PROCEDURE VisitMathArrayType(x: SyntaxTree.MathArrayType);
		VAR fingerprint: FingerPrint; deep: BOOLEAN; fp: LONGINT;
		BEGIN
			fingerprint := x.fingerprint;
			deep := SELF.deep;
			IF Trace THEN TraceEnter("MathArrayType") END;


			IF ~fingerprint.shallowAvailable THEN
				fingerprint.shallowAvailable := TRUE; (* the fingerprinting may return to itself => avoid circles *)
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp,fpTypeComposite);
				IF x.form = SyntaxTree.Open THEN FPNumber(fp,fpTypeOpenArray)
				ELSIF x.form = SyntaxTree.Static THEN FPNumber(fp,fpTypeStaticArray)
				ELSIF x.form = SyntaxTree.Tensor THEN (* do nothing *)
				ELSE HALT(200)
				END;
				TypeName(fp,x);
				IF x.arrayBase # NIL THEN
					FPType(fp,x.arrayBase.resolved);
				END;
				IF x.form = SyntaxTree.Static THEN FPNumber(fp,x.staticLength) END;
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
			END;

			IF deep & ~fingerprint.deepAvailable THEN
				x.arrayBase.Accept(SELF);
				fingerprint.private := fingerprint.shallow;
				fingerprint.public := fingerprint.shallow;
				fingerprint.deepAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
			END;

			IF Trace THEN TraceExit("MathArrayType",fingerprint) END;

			SELF.fingerprint := fingerprint;
		END VisitMathArrayType;

		(*
			fp = fp [ -> Name(moduleName) -> Name(typeName) ]
		*)
		PROCEDURE TypeName(VAR fp: LONGINT; x:SyntaxTree.Type);
		VAR  typeDeclaration: SyntaxTree.TypeDeclaration;
		BEGIN
			IF (x.scope # NIL) THEN
				 (* only executed for imported types, reason:
				 	modification of a type name would result in modified fingerprint leading to modified fingerprints of using structures such as
				 	in the following example:
				 	TYPE A=ARRAY 32 OF CHAR;
				 	PROCEDURE P*(a:A);
				 	...
				 	END P;
				 	IF name of A was changed, P would get a new fingerprint.
				 	Better: fingerprint of P only depends in type of A but not on its declared name.
				 *)
				IF Trace THEN
					TraceIndent;
					D.Str("TypeName  ");
					D.Str0(x.scope.ownerModule.name);
				END;
				FPName(fp,x.scope.ownerModule.name);
				typeDeclaration := x.typeDeclaration;
				IF (typeDeclaration # NIL) & (typeDeclaration.declaredType.resolved # x) THEN
					(* in record type: pointer to type declaration of a pointer *)
					typeDeclaration := NIL
				END;
				IF (typeDeclaration # NIL) & (typeDeclaration.scope # NIL)THEN
					FPName(fp,typeDeclaration.name);
					IF Trace THEN
						D.Str(".");
						D.Str0(typeDeclaration.name);
					END;
				ELSIF (typeDeclaration # NIL) & (typeDeclaration.scope = NIL) THEN
					D.Str("typedeclaration without scope: "); D.Str0(x.typeDeclaration.name); D.Int(x.typeDeclaration.position,5); D.Ln;
					D.Update;
				ELSE
					FPNumber(fp,0);
				END;
				IF Trace THEN
					D.Str(", fp = "); D.Hex(fp,-8); D.Ln;
				END
			END
		END TypeName;

		(*
		FP(PointerType)            = fpTypePointer <*> fpTypeBasic -> Name <*> FP(baseType).
		PublicFP(PointerType)      = 0.
		PrivateFP(PointerType)     = 0.
		*)
		PROCEDURE VisitPointerType(x: SyntaxTree.PointerType);
		VAR fingerprint: FingerPrint; fp: LONGINT; deep: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("PointerType");  END;
			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF ~fingerprint.shallowAvailable THEN
				IF Trace THEN TraceIndent; D.Str("PointerType shallow");D.Ln;  END;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpTypePointer); FPNumber(fp, fpTypeBasic);
				TypeName(fp,x);
				FPType(fp,x.pointerBase);
				fingerprint.shallow := fp;
				fingerprint.private := fp;
				fingerprint.public := fp;
				fingerprint.shallowAvailable := TRUE;
				fingerprint.deepAvailable := TRUE;
				(*
				deep fingerprinting leads to cycles -> must be done on record type directly, if a deep FP is needed
				IF deep & ~fingerprint.deepAvailable THEN
					IF Trace THEN TraceIndent; D.Str("PointerType:deep");D.Ln;  END;
					x.pointerBase.Accept(SELF);
					fingerprint.deepAvailable := TRUE;
				END;
				*)
				SELF.deep := deep;
			END;
			IF Trace THEN TraceExit("PointerType",fingerprint) END;

			SELF.fingerprint := fingerprint;
		END VisitPointerType;

		(*
		FP(PortType)            = fpTypePort <*> fpTypeBasic -> Name <*> FP(baseType).
		PublicFP(PortType)      = 0.
		PrivateFP(PortType)     = 0.
		*)
		PROCEDURE VisitPortType(x: SyntaxTree.PortType);
		VAR fingerprint: FingerPrint; fp: LONGINT; deep: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("PortType");  END;
			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF ~fingerprint.shallowAvailable THEN
				IF Trace THEN TraceIndent; D.Str("PortType shallow");D.Ln;  END;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpTypePort); FPNumber(fp, fpTypeBasic);
				TypeName(fp,x);
				FPNumber(fp,x.sizeInBits);
				fingerprint.shallow := fp;
				fingerprint.private := fp;
				fingerprint.public := fp;
				fingerprint.shallowAvailable := TRUE;
				fingerprint.deepAvailable := TRUE;
				SELF.deep := deep;
			END;
			IF Trace THEN TraceExit("PortType",fingerprint) END;

			SELF.fingerprint := fingerprint;
		END VisitPortType;

		(*
		FP(Method)  = 0 <*> fpModeMethod -> Name(methodName) -> Signature(method).
		*)
		PROCEDURE FPrintMethod(VAR private,public: LONGINT; procedure,body: SyntaxTree.Procedure);
		VAR fingerprint: FingerPrint; fp: LONGINT; name: ARRAY 256 OF CHAR;
		BEGIN
			IF Trace THEN TraceEnter("Method");
				D.Address(SYSTEM.VAL(ADDRESS,procedure));
				procedure.GetName(name);
				TraceIndent; D.Str("name = "); D.Str(name); D.Ln;
			END;
			ASSERT(deep);
			fingerprint := procedure.fingerprint;
			IF ~fingerprint.shallowAvailable THEN
				fp := 0;
				FPNumber(fp,fpModeMethod);
				Global.GetSymbolName(procedure,name);
				FPString(fp,name);
				FPSignature(fp,procedure.type(SyntaxTree.ProcedureType),procedure IS SyntaxTree.Operator );
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				procedure.SetFingerPrint(fingerprint)
			ELSE
				fp := fingerprint.shallow;
			END;
			IF procedure.access * SyntaxTree.Public # {} THEN (* visible method or visible supermethod *)
				IF Trace THEN D.String("fp before method number"); D.Hex(fp,-8); D.Ln END;
				FPNumber(fp,procedure.methodNumber);
				IF Trace THEN D.String("fp after method number"); D.Hex(fp,-8); D.Ln END;
				IF procedure # body THEN
					FPNumber(private,fp); FPNumber(public,fp);
				END;
			END;
			IF Trace THEN
				TraceIndent; D.Str("Method, fp = "); D.Hex(private,-8); D.Str(" "); D.Hex(public,-8); D.Ln;
				TraceExit("Method",fingerprint)
			END;
		END FPrintMethod;

		PROCEDURE VisitCellType(x: SyntaxTree.CellType);
		VAR fingerprint: FingerPrint; fp:LONGINT; name: SyntaxTree.String;
		BEGIN
			fingerprint := x.fingerprint;
			deep := SELF.deep;
			IF ~fingerprint.shallowAvailable THEN
				fp := 0;
				TypeName(fp,x);
				fingerprint.shallow := fp;
				fingerprint.public := fp;
				fingerprint.private := fp;
				fingerprint.deepAvailable := TRUE;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
			END;
			SELF.fingerprint := fingerprint
		END VisitCellType;

		(*
		FP(RecordType)             = fpTypeComposite <*> fptypeRecord
		                            [ -> Name(moduleName) -> Name(typeName)] [<*> FP(baseType)]
		PublicFP(RecordType)       = FP(recordType) [<*> PublicFP(baseType)] {<*> FP(method) <*> methodNumber }
		                            {<*> PublicFP(fieldType) <*> offset(field) <*> FP(field)} <*> flags.
		PrivateFP(RecordType)      = FP(recordType) [<*> PrivateFP(baseType)] {<*> FP(method) <*> methodNumber }
		                            {<*> PrivateFP(fieldType) <*> offset(field) <*> FP(field)}
		*)
		PROCEDURE VisitRecordType(x: SyntaxTree.RecordType);
		VAR scope: SyntaxTree.RecordScope; fp: LONGINT; variable: SyntaxTree.Variable;
			fingerprint,variableFingerPrint,variableTypeFingerPrint,baseFingerPrint: FingerPrint;flags: SET;
			symbol: SyntaxTree.Symbol; procedure: SyntaxTree.Procedure;  baseType: SyntaxTree.Type;
			body: SyntaxTree.Body;
			deep: BOOLEAN;
		(* for dealing with cycles the private and public fingerprint are computed here
			while FP is computed completely during call of Type0 *)
		BEGIN
			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF Trace THEN TraceEnter("Record"); END;

			IF ~fingerprint.shallowAvailable THEN
				IF Trace THEN TraceIndent; D.Str("RecordType Enter Shallow "); D.Ln; END;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpTypeComposite); FPNumber(fp, fpTypeRecord);
				TypeName(fp,x);
				IF Trace THEN TraceIndent; D.Str("RecordType Name ");D.Hex(fp,-8);  D.Ln; END;

				IF (x.baseType # NIL) THEN
					baseType := x.GetBaseRecord();
					FPType(fp,baseType);
				END;
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
				IF Trace THEN TraceIndent; D.Str("RecordType Shallow Done "); TraceFP(fingerprint); D.Ln;  END;
			END;

			IF deep & ~fingerprint.deepAvailable THEN
				IF Trace THEN TraceIndent; D.Str("RecordType Enter Deep "); D.Ln; END;
				fingerprint.private := fingerprint.shallow;
				fingerprint.public := fingerprint.shallow;
				(*! finger printing for interfaces omitted *)
				IF Trace THEN TraceIndent; D.Str("RecordType before basetype"); TraceFP(fingerprint); D.Ln; END;

				(* now compute base record finger prints *)
				baseType := x.GetBaseRecord();
				IF  (baseType # NIL) THEN
					IF baseType IS SyntaxTree.PointerType THEN baseType := baseType(SyntaxTree.PointerType).pointerBase.resolved END;
					baseFingerPrint := TypeFP(baseType); (* deep finger print *)
					FPNumber(fingerprint.private,baseFingerPrint.private);
					FPNumber(fingerprint.public,baseFingerPrint.public);
				END;

				scope := x.recordScope;
				IF Trace THEN TraceIndent; D.Str("RecordType before methods"); TraceFP(fingerprint); D.Ln; END;

				(* methods, sorted *)
				symbol := scope.firstSymbol;
				WHILE symbol # NIL DO
					IF symbol IS SyntaxTree.Procedure THEN
						procedure := symbol(SyntaxTree.Procedure);
						FPrintMethod(fingerprint.private, fingerprint.public, procedure, scope.bodyProcedure);
						IF Trace THEN TraceIndent; D.Str("RecordType Method "); TraceFP(fingerprint); D.Ln; END;
					END;
					symbol := symbol.nextSymbol
				END;
				IF Trace THEN TraceIndent; D.Str("RecordType after methods"); TraceFP(fingerprint); D.Ln; END;

				variable := scope.firstVariable;
				WHILE variable # NIL DO
					variableFingerPrint := variable.fingerprint;
					IF variable.access * SyntaxTree.Public # {} THEN
						(* variable fp =  & fpModeField & Name & Visibility [& fpUntraced] & Type *)
						fp := 0;
						FPNumber(fp,fpModeField);
						FPName(fp,variable.name);

						FPVisibility(fp,variable.access);
						IF variable.untraced THEN FPNumber(fp,fpUntraced) END;
						variableTypeFingerPrint := TypeFP(variable.type); (* deep finger print *)
						FPNumber(fp,variableTypeFingerPrint.shallow);
						variableFingerPrint.shallow := fp;
						FPNumber(fingerprint.private,variableTypeFingerPrint.private);
						FPNumber(fingerprint.private,SHORT(variable.offsetInBits DIV 8));
						FPNumber(fingerprint.private,fp);
						FPNumber(fingerprint.public,variableTypeFingerPrint.public);
						FPNumber(fingerprint.public,SHORT(variable.offsetInBits DIV 8));
						FPNumber(fingerprint.public,fp);
						IF Trace THEN TraceIndent; D.Str("RecordType Field "); D.Str0(variable.name); D.Str(" "); TraceFP(fingerprint); D.Ln; END;
					ELSE
						fp := 0;
						IF variable.untraced THEN FPNumber(fp,fpUntraced) END;
						FPNumber(fingerprint.private,fp);
						IF Trace THEN TraceIndent; D.Str("RecordType InvisibleField "); TraceFP(fingerprint); D.Ln;  END;
					END;
					variable := variable.nextVariable;
				END;

				flags := {};
				IF x.recordScope.bodyProcedure # NIL THEN
					body := x.recordScope.bodyProcedure.procedureScope.body;
					INCL(flags,  fpHasBody);
					IF body # NIL THEN
						IF body.isActive THEN INCL(flags,fpActive) END;
						IF body.isExclusive THEN INCL(flags,fpProtected) END;
					END;
					IF Trace THEN TraceIndent; D.Str("RecordType Body "); TraceFP(fingerprint); D.Ln;  END;
				END;
				IF x.IsProtected() THEN INCL(flags,fpProtected) END;
				FPSet(fingerprint.public, flags);
				IF Trace THEN TraceIndent; D.Str("RecordType Exit Deep "); TraceFP(fingerprint); D.Ln;  END;

				(*
				ASSERT(fingerprint.private # 0,100);
				ASSERT(fingerprint.public # 0,101);
				*)
				fingerprint.deepAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
			END;

			SELF.fingerprint := fingerprint;

			IF Trace THEN TraceExit("Record",fingerprint); END;

		END VisitRecordType;

		(*
		FP(ProcedureType)          = fpTypeProcedure <*> fpTypeBasic [<*> fpDelegate]-> Name.
		PublicFP(ProcedureType)    = FP(arrayType) -> Signature(procedureType)
		PrivateFP(ProcedureType)   = FP(arrayType)-> Signature(procedureType).
		*)
		PROCEDURE VisitProcedureType(x: SyntaxTree.ProcedureType);
		VAR fingerprint: FingerPrint; deep: BOOLEAN; fp: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("ProcedureType") END;

			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF ~fingerprint.shallowAvailable THEN
				fingerprint.shallowAvailable := TRUE; (*! to avoid circles, this is not fully clean - for paco *)
				fp := 0;
				FPNumber(fp,fpTypeProcedure);
				FPNumber(fp,fpTypeBasic);
				IF x.isDelegate THEN FPNumber(fp,fpDelegate) END;
				x.SetFingerPrint(fingerprint);
				TypeName(fp,x);

				fingerprint.public := fp; fingerprint.private := fp;
				fingerprint.shallow := fp;
				FPSignature(fp,x,FALSE);
				fingerprint.public := fp; fingerprint.private := fp;
				fingerprint.shallow := fp;
				fingerprint.deepAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
			END;

			(*
			IF ~fingerprint.deepAvailable  THEN
				SELF.deep := FALSE;
				FPSignature(fp,x,FALSE);
				SELF.deep := deep;
				fingerprint.public := fp; fingerprint.private := fp;
				fingerprint.shallow := fp;
				fingerprint.deepAvailable := TRUE;
			END;
			*)

			IF Trace THEN TraceExit("ProcedureType",fingerprint) END;
			SELF.fingerprint := fingerprint;
		END VisitProcedureType;

		(** values - used in constant symbols - effects in fingerprint modification of (object) global variable fp *)

		(* fp = fp & (fpTrue | fpFalse) *)
		PROCEDURE VisitBooleanValue(x: SyntaxTree.BooleanValue);
		BEGIN IF x.value THEN FPNumber(SELF.fp,fpTrue) ELSE FPNumber(SELF.fp,fpFalse) END
		END VisitBooleanValue;

		(* fp = fp & (HugeInt | Number) *)
		PROCEDURE VisitIntegerValue(x: SyntaxTree.IntegerValue);
		BEGIN IF x.type.sizeInBits = 64 THEN FPHugeInt(SELF.fp,x.hvalue) ELSE FPNumber(SELF.fp,x.value) END;
		END VisitIntegerValue;

		(* fp = fp & (HugeInt | Number) *)
		PROCEDURE VisitEnumerationValue(x: SyntaxTree.EnumerationValue);
		BEGIN FPNumber(SELF.fp,x.value)
		END VisitEnumerationValue;

		(* fp = fp & ORD(char) *)
		PROCEDURE VisitCharacterValue(x: SyntaxTree.CharacterValue);
		BEGIN FPNumber(SELF.fp,ORD(x.value)) END VisitCharacterValue;

		(* fp = fp & Set *)
		PROCEDURE VisitSetValue(x: SyntaxTree.SetValue);
		BEGIN FPSet(SELF.fp,x.value) END VisitSetValue;

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		VAR element: SyntaxTree.Expression; i: LONGINT;
		BEGIN
			FOR i := 0 TO x.elements.Length()-1 DO
				element := x.elements.GetExpression(i);
				FPValue(fp, element);
			END;
		END VisitMathArrayExpression;

		(* fp = fp {& Value} *)
		PROCEDURE VisitMathArrayValue(x: SyntaxTree.MathArrayValue);
		BEGIN
			VisitMathArrayExpression(x.array); (* do not call FPValue here, recursion possible because x.array.resolved = x  *)
		END VisitMathArrayValue;

		(* fp = fp & (Real | LongReal) *)
		PROCEDURE VisitRealValue(x: SyntaxTree.RealValue);
		BEGIN
			IF x.type.sizeInBits=32 THEN FPReal(SELF.fp,SHORT(x.value))
			ELSE FPLongReal(SELF.fp,x.value)
			END;
		END VisitRealValue;

		(* fp = fp & String *)
		PROCEDURE VisitStringValue(x: SyntaxTree.StringValue);
		BEGIN FPString(SELF.fp,x.value^) END VisitStringValue;

		(* fp = fp & FP(x) *)
		PROCEDURE FPValue(VAR fp: LONGINT; x: SyntaxTree.Expression);
		BEGIN
			SELF.fp := fp;
			IF x.resolved # NIL THEN
				x.resolved.Accept(SELF);
			ELSE
				x.Accept(SELF)
			END;
			fp := SELF.fp
		END FPValue;

		PROCEDURE FPType(VAR fp: LONGINT; t: SyntaxTree.Type);
		BEGIN
			INC(level); ASSERT(level <= 100);
			IF t = NIL THEN FPNumber(fp,fpTypeNone);
			ELSE t.Accept(SELF); FPNumber(fp,SELF.fingerprint.shallow);
			END;
			DEC(level);
		END FPType;

		(* 	Signature(f)  = f <*> FP(returnType)
	                      { <*> (fpModeVarParameter | fpModeConstParameter | fpModePar)
	                      <*> FP(parameterType) [-> Name(parameterName)]  }
		 *)
		PROCEDURE FPSignature(VAR fp: LONGINT; t: SyntaxTree.ProcedureType; isOperator: BOOLEAN);
		VAR par,self: SyntaxTree.Parameter;

			(* fp = fp & (fpModeVarPar | fpModeConstPar | fpModePar) [ & Name ] *)
			PROCEDURE FPPar(VAR fp: LONGINT;  par: SyntaxTree.Parameter);
			VAR deep: BOOLEAN;
			BEGIN
				IF par.kind = SyntaxTree.VarParameter THEN  FPNumber(fp, fpModeVarPar)
				ELSIF par.kind = SyntaxTree.ConstParameter THEN
					IF (par.type.resolved IS SyntaxTree.ArrayType) OR (par.type.resolved IS SyntaxTree.RecordType) THEN (*! compatiblity with paco *)
						FPNumber(fp,fpModeVarPar)
					ELSE
						FPNumber(fp,fpModePar)
					END;
				ELSE  FPNumber(fp, fpModePar)  END;

				deep := SELF.deep;
				SELF.deep := FALSE;
				FPType(fp,par.type);
				SELF.deep := deep;

				IF isOperator & ~(par.type.resolved IS SyntaxTree.BasicType) & (par.type.resolved.typeDeclaration # NIL) THEN
					FPName(fp,par.type.resolved.typeDeclaration.name);
					(* D.Str("fp "); D.Str0(par.type.resolved.typeDeclaration.name.name); D.Ln;*)
				ELSIF isOperator & (par.type.resolved IS SyntaxTree.BasicType) THEN
					FPName(fp,par.type.resolved(SyntaxTree.BasicType).name);
					(* D.Str("fpb "); D.Str0(par.type.resolved(SyntaxTree.BasicType).name.name);*)
				END;
			END FPPar;

		BEGIN
			IF Trace THEN
				TraceIndent; D.Str("FPSignature enter "); D.Hex(fp,-8); D.Ln;
			END;
			FPType(fp,t.returnType);
			IF Trace THEN
				TraceIndent; D.Str("FPSignature after return type "); D.Hex(fp,-8); D.Ln;
			END;

			IF IsOberonProcedure(t) THEN
				self := t.firstParameter;
				WHILE (self # NIL) & (self.name#Global.SelfParameterName) DO
					self := self.nextParameter;
				END;
				IF self # NIL THEN FPPar(fp,self) END; (* self parameter *)

				(*
				IF t.selfParameter # NIL THEN FPPar(fp,t.selfParameter) END; (* self parameter *)
				self := NIL;
				*)

				IF Trace THEN
					TraceIndent; D.Str("FPSignature after self "); D.Hex(fp,-8); D.Ln;
				END;
				par := t.firstParameter;
				WHILE (par#self) DO (*! done as in PACO *)
					FPPar(fp, par);
					IF Trace THEN
						TraceIndent; D.Str("FPSignature par "); D.Hex(fp,-8); D.Ln;
					END;
					par:=par.nextParameter;
				END;
				IF Trace THEN
					TraceIndent; D.Str("FPSignature exit "); D.Hex(fp,-8); D.Ln;
				END;
			ELSE
				par := t.lastParameter;
				WHILE (par#NIL) DO (*! done as in PACO *)
					FPPar(fp, par);
					IF Trace THEN
						TraceIndent; D.Str("FPSignature par "); D.Hex(fp,-8); D.Ln;
					END;
					par:=par.prevParameter;
				END;
			END;
		END FPSignature;

		(** symbols *)

		(*
			FP(TypeDeclaration)        = 0 <*> fpModeType -> Name -> Visibility <*> FP(Type).
		*)
		PROCEDURE VisitTypeDeclaration(x: SyntaxTree.TypeDeclaration);
		VAR fp: LONGINT;
			fingerprint: FingerPrint; deep: BOOLEAN;
		BEGIN
			fingerprint := x.fingerprint;

			IF ~fingerprint.shallowAvailable THEN
				IF Trace THEN TraceEnter("TypeDeclaration") END;
				deep := SELF.deep;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpModeType);
				FPName(fp,x.name);
				IF Trace THEN TraceIndent; D.String("access="); D.Set(x.access); D.Ln;  END;
				FPVisibility(fp, x.access);

				x.declaredType.Accept(SELF);
				FPNumber(fp, SELF.fingerprint.shallow);
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
				IF Trace THEN TraceExit("TypeDeclaration",fingerprint) END;
			END;
			SELF.fingerprint := fingerprint
		END VisitTypeDeclaration;

		(*
			FP(ConstantDeclaration)    = 0 <*> fpModeConstant -> Name -> Visibility <*> FP(Type) -> Basic -> Value.
		*)
		PROCEDURE VisitConstant(x: SyntaxTree.Constant);
		VAR access: SET;
			fingerprint: FingerPrint;
			fp: LONGINT;
			deep: BOOLEAN;
		BEGIN
			fingerprint := x.fingerprint;

			IF ~fingerprint.shallowAvailable THEN
				deep := SELF.deep;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpModeConst);
				FPName(fp,x.name);
				(* for compatibility with old compiler: *)
				access := x.access; IF SyntaxTree.PublicRead IN access THEN INCL(access,SyntaxTree.PublicWrite) END;
				FPVisibility(fp, access);
				FPType(fp, x.type);
				FPNumber(fp, fpTypeBasic);
				FPValue(fp, x.value);
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
			END;
			SELF.fingerprint := fingerprint
		END VisitConstant;

		(*
			FP(VariableDeclaration)    = 0 <*> fpModePar -> Name -> Visibility <*> FP(Type).
		*)
		PROCEDURE VisitVariable(x: SyntaxTree.Variable);
		VAR fingerprint: FingerPrint; deep: BOOLEAN; name: SyntaxTree.IdentifierString;
		BEGIN
			fingerprint := x.fingerprint;

			IF ~fingerprint.shallowAvailable THEN
				deep := SELF.deep;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp,fpModeVar);
				Global.GetSymbolName(x,name);
				FPString(fp,name);
				FPVisibility(fp,x.access);
				x.type.Accept(SELF);
				FPNumber(fp,SELF.fingerprint.shallow);
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
			END;
			SELF.fingerprint := fingerprint
		END VisitVariable;
		
		PROCEDURE VisitProperty(x: SyntaxTree.Property);
		BEGIN
			VisitVariable(x);
		END VisitProperty;
		

		(*
			FP(ParameterDeclaration)    = 0 <*> fpModePar -> Name -> Visibility <*> FP(Type).
		*)
		PROCEDURE VisitParameter(x: SyntaxTree.Parameter);
		VAR fingerprint: FingerPrint; deep: BOOLEAN; name: SyntaxTree.IdentifierString;
		BEGIN
			fingerprint := x.fingerprint;

			IF ~fingerprint.shallowAvailable THEN
				deep := SELF.deep;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp,fpModePar);
				Global.GetSymbolName(x,name);
				FPString(fp,name);
				FPVisibility(fp,x.access);
				x.type.Accept(SELF);
				FPNumber(fp,SELF.fingerprint.shallow);
				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
			END;
			SELF.fingerprint := fingerprint
		END VisitParameter;

		(*
		FP(ProcedureDeclaration)   = 0 <*> fpModeInlineProcedure -> Name -> Visibility <*> FP(Type) -> Code.
		                            | 0 <*> fpModeExportedProcedure -> Name -> Visibility <*> FP(Type)
		*)
		PROCEDURE VisitProcedure(x: SyntaxTree.Procedure);
		VAR fp: LONGINT; access: SET; fingerprint: FingerPrint; deep: BOOLEAN; code: SyntaxTree.Code; i: LONGINT;
			size,value: LONGINT; name: ARRAY 256 OF CHAR;
		BEGIN
			IF x.scope IS SyntaxTree.RecordScope THEN (* method *)
				FPrintMethod(fp,fp,x,NIL);
				fingerprint := x.fingerprint;
			ELSE
				fingerprint := x.fingerprint;
				IF ~fingerprint.shallowAvailable THEN
					deep := SELF.deep;
					SELF.deep := FALSE;
					(* for compatibility with old compiler: *)
					access := x.access; IF SyntaxTree.PublicRead IN access THEN INCL(access,SyntaxTree.PublicWrite) END;
					fp := 0;
					IF x.isInline THEN
						FPNumber(fp, fpModeInlineProcedure);
						FPName(fp,x.name);
						FPVisibility(fp, access);
						FPSignature(fp,x.type(SyntaxTree.ProcedureType),x IS SyntaxTree.Operator);
						IF (x.procedureScope.body # NIL) & (x.procedureScope.body.code # NIL) THEN
							code := x.procedureScope.body.code;
							IF code.inlineCode = NIL THEN
								size := 0
							ELSE
								size := code.inlineCode.GetSize() DIV 8;
							END;
							FPNumber(fp,size);
							FOR i := 0 TO size-1 DO
								value := code.inlineCode.GetBits(i*8,8);
								FPNumber(fp,value);
							END;
						END;
					ELSE
						FPNumber(fp, fpModeExportedProcedure);
						Global.GetSymbolName(x,name);
						FPString(fp,name);
						FPVisibility(fp, access);
						FPSignature(fp,x.type(SyntaxTree.ProcedureType),x IS SyntaxTree.Operator);
					END;
					fingerprint.shallow := fp;
					fingerprint.shallowAvailable := TRUE;
					x.SetFingerPrint(fingerprint);
					SELF.deep := deep;
				END;
			END;
			SELF.fingerprint := fingerprint
		END VisitProcedure;

		(* cf. Procedure *)
		PROCEDURE VisitOperator(x: SyntaxTree.Operator);
		BEGIN
			VisitProcedure(x) (* same finger print as a procedure *)
		END VisitOperator;
		
		PROCEDURE VisitModule(x: SyntaxTree.Module);
		VAR fingerprint, symbolFingerPrint: FingerPrint; deep: BOOLEAN; fp: LONGINT; symbol: SyntaxTree.Symbol; scope: SyntaxTree.ModuleScope;
		BEGIN
			fingerprint := x.fingerprint;
			deep := SELF.deep;

			IF Trace THEN TraceEnter("Record"); END;

			IF ~fingerprint.shallowAvailable THEN
				IF Trace THEN TraceIndent; D.Str("Module Enter Shallow "); D.Ln; END;
				SELF.deep := FALSE;
				fp := 0;
				FPNumber(fp, fpTypeModule); 
				FPName(fp,x.name);

				IF Trace THEN TraceIndent; D.Str("Module Name ");D.Hex(fp,-8);  D.Ln; END;

				fingerprint.shallow := fp;
				fingerprint.shallowAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
				SELF.deep := deep;
				IF Trace THEN TraceIndent; D.Str("Module Shallow Done "); TraceFP(fingerprint); D.Ln;  END;
			END;

			IF deep & ~fingerprint.deepAvailable THEN
				IF Trace THEN TraceIndent; D.Str("Module Enter Deep "); D.Ln; END;
				fingerprint.private := fingerprint.shallow;
				fingerprint.public := fingerprint.shallow;
				
				scope := x.moduleScope;
				IF Trace THEN TraceIndent; D.Str("RecordType before methods"); TraceFP(fingerprint); D.Ln; END;

				symbol := scope.firstSymbol;
				WHILE symbol # NIL DO
					IF symbol.access * SyntaxTree.Public # {} THEN
						symbolFingerPrint := SymbolFP(symbol);
						FPNumber(fingerprint.private,symbolFingerPrint.shallow);
						FPNumber(fingerprint.public,symbolFingerPrint.shallow);
					END;
					symbol := symbol.nextSymbol;
				END;

				IF Trace THEN TraceIndent; D.Str("Module Exit Deep "); TraceFP(fingerprint); D.Ln;  END;

				(*
				ASSERT(fingerprint.private # 0,100);
				ASSERT(fingerprint.public # 0,101);
				*)
				fingerprint.deepAvailable := TRUE;
				x.SetFingerPrint(fingerprint);
			END;

			SELF.fingerprint := fingerprint;

			IF Trace THEN TraceExit("Record",fingerprint); END;

		END VisitModule;

		PROCEDURE VisitSymbol(x: SyntaxTree.Symbol);
		BEGIN
			fingerprint.shallow := 0;
			fingerprint.shallowAvailable := TRUE;
			x.SetFingerPrint(fingerprint);
		END VisitSymbol;

		PROCEDURE TraceIndent;
		VAR i: LONGINT;
		BEGIN
			FOR i := 1 TO traceLevel DO D.Str(" "); END;
		END TraceIndent;

		PROCEDURE TraceEnter(CONST name: ARRAY OF CHAR);
		BEGIN
			INC(traceLevel); TraceIndent;
			D.Str("Enter ");
			D.Str(name);
			D.Ln;
		END TraceEnter;

		PROCEDURE TraceExit(CONST name: ARRAY OF CHAR; fingerprint: FingerPrint);
		BEGIN
			TraceIndent; DEC(traceLevel);
			D.Str("Exit "); D.Str(name); D.Str(" "); TraceFP(fingerprint); D.Ln;
		END TraceExit;

		PROCEDURE TraceFP(fingerprint: FingerPrint);
		BEGIN
			D.Hex(fingerprint.shallow,-8); D.Str(" "); D.Hex(fingerprint.private,-8);
			D.Str(" "); D.Hex(fingerprint.public,-8);
		END TraceFP;


		(* returns the finger print (object) of a type *)
		PROCEDURE TypeFP*(this: SyntaxTree.Type): FingerPrint;
		VAR deep: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("TypeFP");  END;

			deep := SELF.deep;
			SELF.deep := TRUE;
			this.Accept(SELF);
			SELF.deep := deep;
			ASSERT(fingerprint.deepAvailable,101);
			ASSERT(fingerprint.shallow #0,102);

			IF Trace THEN TraceExit("TypeFP",fingerprint); D.Ln;
			D.Ln; END;

			RETURN fingerprint
		END TypeFP;

		(* returns the finger print (object) of a symbol *)
		PROCEDURE SymbolFP*(this: SyntaxTree.Symbol): FingerPrint;
		VAR deep: BOOLEAN;
		BEGIN
			deep := SELF.deep;
			SELF.deep := TRUE;
			IF Trace THEN TraceEnter("SymbolFP");
				TraceIndent;
				D.Str("name: ");
				D.Str0(this.name); D.Ln;
			END;
			this.Accept(SELF);
			SELF.deep := deep;
			IF Trace THEN TraceExit("SymbolFP",fingerprint); D.Ln; END;
			RETURN fingerprint
		END SymbolFP;

	END FingerPrinter;


	(** ---------- FingerPrinting primitives -------------- *)
	PROCEDURE IsOberonProcedure(type: SyntaxTree.ProcedureType): BOOLEAN;
	BEGIN
		RETURN type.callingConvention = SyntaxTree.OberonCallingConvention
	END IsOberonProcedure;

	(* fp = fp <*> val *)
	PROCEDURE FPNumber*(VAR fp: LONGINT; val: LONGINT);
	BEGIN
		fp:=SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ROT(fp, 7)) / SYSTEM.VAL(SET, val))
	END FPNumber;

	(* fp = fp <*> set *)
	PROCEDURE FPSet*(VAR fp: LONGINT; set: SET);
	BEGIN FPNumber(fp, SYSTEM.VAL(LONGINT, set))
	END FPSet;

	(* fp = fp <*> real *)
	PROCEDURE FPReal*(VAR fp: LONGINT; real: REAL);
	BEGIN FPNumber(fp, SYSTEM.VAL(LONGINT, real))
	END FPReal;

	(* fp = fp <*> low <*> high *)
	PROCEDURE FPLongReal*(VAR fp: LONGINT; lr: LONGREAL);
		VAR l, h: LONGINT;
	BEGIN
		SYSTEM.GET(ADDRESSOF(lr)+4, l); SYSTEM.GET(ADDRESSOF(lr), h);
		FPNumber(fp, l); FPNumber(fp, h);
	END FPLongReal;

	(* fp = fp <*> low <*> high *)
	PROCEDURE FPHugeInt*(VAR fp: LONGINT; huge: HUGEINT);
	VAR l, h: LONGINT;
	BEGIN
		SYSTEM.GET(ADDRESSOF(huge)+4, l); SYSTEM.GET(ADDRESSOF(huge), h);
		FPNumber(fp, l); FPNumber(fp, h);
	END FPHugeInt;

	(* fp = fp -> String *)
	PROCEDURE FPName*(VAR fp: LONGINT; x: SyntaxTree.Identifier);
	VAR name: Scanner.IdentifierString;
	BEGIN
		Basic.GetString(x,name);
		FPString(fp,name);
	END FPName;

	(* fp = fp {<*> str[i]} *)
	PROCEDURE FPString*(VAR fp: LONGINT; CONST str: ARRAY OF CHAR);
	VAR i: INTEGER; ch: CHAR;
	BEGIN i:=0; REPEAT ch:=str[i]; FPNumber(fp, ORD(ch)); INC(i) UNTIL ch=0X
	END FPString;

	(* fp = fp <*> (fpExtern | fpExternR | fpIntern | fpOther + vis) *)
	PROCEDURE FPVisibility*(VAR fp: LONGINT; vis: SET);
	BEGIN
		IF SyntaxTree.PublicWrite IN vis THEN  FPNumber(fp, fpExtern)
		ELSIF SyntaxTree.PublicRead IN vis THEN  FPNumber(fp, fpExternR)
		ELSIF SyntaxTree.Internal * vis #{} THEN  FPNumber(fp, fpIntern)
		ELSE
			FPNumber(fp, fpOther + SYSTEM.VAL(LONGINT, vis))
		END
	END FPVisibility;

	PROCEDURE DumpFingerPrint*(w: Streams.Writer; fp: FingerPrint);
	BEGIN
		w.String("fingerprint: ");
		w.String("shallow = "); w.Hex(fp.shallow,8);
		w.String(", private = "); w.Hex(fp.private,8);
		w.String(", public = "); w.Hex(fp.public,8);
		w.Ln;
	END DumpFingerPrint;


END FoxFingerPrinter.
