MODULE FoxSyntaxTree;   (**  AUTHOR "fof & fn"; PURPOSE "Oberon Compiler: Abstract Syntax Tree";  **)
(* (c) fof ETHZ 2009 *)

(**
	note on documentation:
	Most objects in this module are commented with an informal Oberon syntax example indicating which variables of the respective object stand for what symbol /expression etc.
	This syntax example should not be confused with a profound description of the syntax in an EBNF form, which can rather be found in the parser module.
	The informal Oberon syntax is marked with << ... >>
**)

IMPORT
	Basic := FoxBasic, Scanner := FoxScanner, BitSets, Commands, StringPool, Strings(* , D := Debugging (* only for debuggging / counting *) *) ;

CONST
	(** general flags: used in statements, procedure types and symbols
		general flags are unique and may overlap with access flags only
		flag numbers have no meaning and are not used for object files etc., i.e. flag renumbering is possible without effect
	*)
	(** calling conventions *)
	OberonCallingConvention* =0;
	CCallingConvention* =1;
	WinAPICallingConvention* =2;
	DarwinCCallingConvention* =3;
	InterruptCallingConvention* = 4;

	(** Access Flags *)
	InternalRead* = 0;			(** can read symbol in same module *)
	InternalWrite* = 1;		(** can write symbol in same module *)
	ProtectedRead* = 2;		(** can read symbol in type extentions *)
	ProtectedWrite* = 3;		(** can write symbol in type extentions *)
	PublicRead* = 4;			(** can read everywhere *)
	PublicWrite* = 5;			(** can write everywhere *)

	Hidden* = {};
	Internal* = {InternalRead, InternalWrite};
	Protected* = {ProtectedRead, ProtectedWrite} ;
	Public* = {PublicRead, PublicWrite} ;
	ReadOnly* = {InternalRead, ProtectedRead,PublicRead};

	(** parameter forms *)
	ValueParameter* = 0;  VarParameter* = 1;  ConstParameter* = 2;
	InPort*=3; 	OutPort*=4;

	(** array forms *)
	Static*=1; (* ARRAY x OF .. / ARRAY [x] OF ... *)
	Open*=2; (* ARRAY OF ... / ARRAY [*] OF ... *)
	Tensor*=3; (* ARRAY [?] OF ... *)
	SemiDynamic*=4;

	(** node states, important for checker to avoid cycles *)
	Undefined*={}; BeingResolved*=1; Resolved*=2; FingerPrinted*=3; Warned*=4; RecursionFlag=31;

	(* context in which a range expression is used *)
	ArrayIndex* = 0;
	SetElement* = 1;
	CaseGuard* = 2;

TYPE
	SourceCode*= Scanner.StringType;
	BinaryCode*= BitSets.BitSet;
	String*= Scanner.StringType;
	IdentifierString*= Scanner.IdentifierString;

	(** visitor pattern implementation *)
	(* to use this object in your implementation, copy and paste and replace "x: " by "x: SyntaxTree." *)
	Visitor* = OBJECT

		(** types *)
		PROCEDURE VisitType*(x: Type);
		BEGIN HALT(100) (* abstract *) END VisitType;

		PROCEDURE VisitBasicType*(x: BasicType);
		BEGIN HALT(100) (* abstract *) END VisitBasicType;

		PROCEDURE VisitByteType*(x: ByteType);
		BEGIN HALT(100) (* abstract *) END VisitByteType;

		PROCEDURE VisitAnyType*(x: AnyType);
		BEGIN HALT(100) (* abstract *) END VisitAnyType;

		PROCEDURE VisitObjectType*(x: ObjectType);
		BEGIN HALT(100) (* abstract *) END VisitObjectType;

		PROCEDURE VisitNilType*(x: NilType);
		BEGIN HALT(100) (* abstract *) END VisitNilType;

		PROCEDURE VisitAddressType*(x: AddressType);
		BEGIN HALT(100) (* abstract *) END VisitAddressType;

		PROCEDURE VisitSizeType*(x: SizeType);
		BEGIN HALT(100) (* abstract *) END VisitSizeType;

		PROCEDURE VisitBooleanType*(x: BooleanType);
		BEGIN HALT(100) (* abstract *) END VisitBooleanType;

		PROCEDURE VisitSetType*(x: SetType);
		BEGIN HALT(100) (* abstract *) END VisitSetType;

		PROCEDURE VisitCharacterType*(x: CharacterType);
		BEGIN HALT(100) END VisitCharacterType;

		PROCEDURE VisitIntegerType*(x: IntegerType);
		BEGIN HALT(100) END VisitIntegerType;

		PROCEDURE VisitFloatType*(x: FloatType);
		BEGIN HALT(100) END VisitFloatType;

		PROCEDURE VisitComplexType*(x: ComplexType);
		BEGIN HALT(100) END VisitComplexType;

		PROCEDURE VisitQualifiedType*(x: QualifiedType);
		BEGIN HALT(100) (* abstract *) END VisitQualifiedType;

		PROCEDURE VisitStringType*(x: StringType);
		BEGIN HALT(100) (* abstract *) END VisitStringType;

		PROCEDURE VisitEnumerationType*(x: EnumerationType);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationType;

		PROCEDURE VisitRangeType*(x: RangeType);
		BEGIN HALT(100) (* abstract *) END VisitRangeType;

		PROCEDURE VisitArrayType*(x: ArrayType);
		BEGIN HALT(100) (* abstract *) END VisitArrayType;

		PROCEDURE VisitMathArrayType*(x: MathArrayType);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayType;

		PROCEDURE VisitPointerType*(x: PointerType);
		BEGIN HALT(100) (* abstract *) END VisitPointerType;

		PROCEDURE VisitPortType*(x: PortType);
		BEGIN HALT(100) (* abstract *) END VisitPortType;

		PROCEDURE VisitRecordType*(x: RecordType);
		BEGIN HALT(100) (* abstract *) END VisitRecordType;

		PROCEDURE VisitCellType*(x: CellType);
		BEGIN HALT(100) (* abstract *) END VisitCellType;

		PROCEDURE VisitProcedureType*(x: ProcedureType);
		BEGIN HALT(100) (* abstract *) END VisitProcedureType;

		(** expressions *)
		PROCEDURE VisitExpression*(x: Expression);
		BEGIN HALT(100) (* abstract *) END VisitExpression;

		PROCEDURE VisitSet*(x: Set);
		BEGIN HALT(100) (* abstract *) END VisitSet;

		PROCEDURE VisitMathArrayExpression*(x: MathArrayExpression);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayExpression;

		PROCEDURE VisitUnaryExpression*(x: UnaryExpression);
		BEGIN HALT(100) (* abstract *) END VisitUnaryExpression;

		PROCEDURE VisitBinaryExpression*(x: BinaryExpression);
		BEGIN HALT(100) (* abstract *) END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression*(x: RangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: TensorRangeExpression);
		BEGIN HALT(100) (* abstract *) END VisitTensorRangeExpression;

		PROCEDURE VisitConversion*(x: Conversion);
		BEGIN HALT(100) (* abstract *) END VisitConversion;

		(** designators (expressions) *)
		PROCEDURE VisitDesignator*(x: Designator);
		BEGIN HALT(100) (* abstract *) END VisitDesignator;

		PROCEDURE VisitIdentifierDesignator*(x: IdentifierDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIdentifierDesignator;

		PROCEDURE VisitSelectorDesignator*(x: SelectorDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelectorDesignator;

		PROCEDURE VisitParameterDesignator*(x: ParameterDesignator);
		BEGIN HALT(100) (* abstract *) END VisitParameterDesignator;

		PROCEDURE VisitArrowDesignator*(x: ArrowDesignator);
		BEGIN HALT(100) (* abstract *) END VisitArrowDesignator;

		PROCEDURE VisitBracketDesignator*(x: BracketDesignator);
		BEGIN HALT(100) (* abstract *) END VisitBracketDesignator;

		PROCEDURE VisitSymbolDesignator*(x: SymbolDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSymbolDesignator;

		PROCEDURE VisitIndexDesignator*(x: IndexDesignator);
		BEGIN HALT(100) (* abstract *) END VisitIndexDesignator;

		PROCEDURE VisitProcedureCallDesignator*(x: ProcedureCallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitProcedureCallDesignator;

		PROCEDURE VisitStatementDesignator*(x: StatementDesignator);
		BEGIN HALT(100) (* abstract *) END VisitStatementDesignator;

		PROCEDURE VisitBuiltinCallDesignator*(x: BuiltinCallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitBuiltinCallDesignator;

		PROCEDURE VisitTypeGuardDesignator*(x: TypeGuardDesignator);
		BEGIN HALT(100) (* abstract *) END VisitTypeGuardDesignator;

		PROCEDURE VisitDereferenceDesignator*(x: DereferenceDesignator);
		BEGIN HALT(100) (* abstract *) END VisitDereferenceDesignator;

		PROCEDURE VisitSupercallDesignator*(x: SupercallDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator*(x: SelfDesignator);
		BEGIN HALT(100) (* abstract *) END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator*(x: ResultDesignator);
		BEGIN HALT(100) (* abstract *) END VisitResultDesignator;

		(** values *)
		PROCEDURE VisitValue*(x: Value);
		BEGIN HALT(100) (* abstract *) END VisitValue;

		PROCEDURE VisitBooleanValue*(x: BooleanValue);
		BEGIN HALT(100) (* abstract *) END VisitBooleanValue;

		PROCEDURE VisitIntegerValue*(x: IntegerValue);
		BEGIN HALT(100) (* abstract *) END VisitIntegerValue;

		PROCEDURE VisitCharacterValue*(x: CharacterValue);
		BEGIN HALT(100) (* abstract *) END VisitCharacterValue;

		PROCEDURE VisitSetValue*(x: SetValue);
		BEGIN HALT(100) (* abstract *) END VisitSetValue;

		PROCEDURE VisitMathArrayValue*(x: MathArrayValue);
		BEGIN HALT(100) (* abstract *) END VisitMathArrayValue;

		PROCEDURE VisitRealValue*(x: RealValue);
		BEGIN HALT(100) (* abstract *) END VisitRealValue;

		PROCEDURE VisitComplexValue*(x: ComplexValue);
		BEGIN HALT(100) (* abstract *) END VisitComplexValue;

		PROCEDURE VisitStringValue*(x: StringValue);
		BEGIN HALT(100) (* abstract *) END VisitStringValue;

		PROCEDURE VisitNilValue*(x: NilValue);
		BEGIN HALT(100) (* abstract *) END VisitNilValue;

		PROCEDURE VisitEnumerationValue*(x: EnumerationValue);
		BEGIN HALT(100) (* abstract *) END VisitEnumerationValue;

		(** symbols *)
		PROCEDURE VisitSymbol*(x: Symbol);
		BEGIN HALT(100) (* abstract *) END VisitSymbol;
		
		PROCEDURE VisitModule*(x: Module);
		BEGIN HALT(100) (* abstract *) END VisitModule;

		PROCEDURE VisitTypeDeclaration*(x: TypeDeclaration);
		BEGIN HALT(100) (* abstract *) END VisitTypeDeclaration;

		PROCEDURE VisitConstant*(x: Constant);
		BEGIN HALT(100) (* abstract *) END VisitConstant;

		PROCEDURE VisitVariable*(x: Variable);
		BEGIN HALT(100) (* abstract *) END VisitVariable;

		PROCEDURE VisitParameter*(x: Parameter);
		BEGIN HALT(100) (* abstract *) END VisitParameter;

		PROCEDURE VisitProperty*(x: Property);
		BEGIN HALT(100) (* abstract *) END VisitProperty;

		PROCEDURE VisitProcedure*(x: Procedure);
		BEGIN HALT(100) (* abstract *) END VisitProcedure;

		PROCEDURE VisitBuiltin*(x: Builtin);
		BEGIN HALT(100) (* abstract *) END VisitBuiltin;

		PROCEDURE VisitOperator*(x: Operator);
		BEGIN HALT(100) (* abstract *) END VisitOperator;

		PROCEDURE VisitImport*(x: Import);
		BEGIN HALT(100) (* abstract *) END VisitImport;

		(** statements *)
		PROCEDURE VisitStatement*(x: Statement);
		BEGIN HALT(100) (* abstract *) END VisitStatement;

		PROCEDURE VisitProcedureCallStatement*(x: ProcedureCallStatement);
		BEGIN HALT(100) (* abstract *) END VisitProcedureCallStatement;

		PROCEDURE VisitAssignment*(x: Assignment);
		BEGIN HALT(100) (* abstract *) END VisitAssignment;

		PROCEDURE VisitCommunicationStatement*(x: CommunicationStatement);
		BEGIN HALT(100) (* abstract *) END VisitCommunicationStatement;

		PROCEDURE VisitIfStatement*(x: IfStatement);
		BEGIN HALT(100) (* abstract *) END VisitIfStatement;

		PROCEDURE VisitWithStatement*(x: WithStatement);
		BEGIN HALT(100) (* abstract *) END VisitWithStatement;

		PROCEDURE VisitCaseStatement*(x: CaseStatement);
		BEGIN HALT(100) (* abstract *) END VisitCaseStatement;

		PROCEDURE VisitWhileStatement*(x: WhileStatement);
		BEGIN HALT(100) (* abstract *) END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement*(x: RepeatStatement);
		BEGIN HALT(100) (* abstract *) END VisitRepeatStatement;

		PROCEDURE VisitForStatement*(x: ForStatement);
		BEGIN HALT(100) (* abstract *) END VisitForStatement;

		PROCEDURE VisitLoopStatement*(x: LoopStatement);
		BEGIN HALT(100) (* abstract *) END VisitLoopStatement;

		PROCEDURE VisitExitableBlock*(x: ExitableBlock);
		BEGIN HALT(100) (* abstract *) END VisitExitableBlock;

		PROCEDURE VisitExitStatement*(x: ExitStatement);
		BEGIN HALT(100) (* abstract *) END VisitExitStatement;

		PROCEDURE VisitReturnStatement*(x: ReturnStatement);
		BEGIN HALT(100) (* abstract *) END VisitReturnStatement;

		PROCEDURE VisitAwaitStatement*(x: AwaitStatement);
		BEGIN HALT(100) (* abstract *) END VisitAwaitStatement;

		PROCEDURE VisitStatementBlock*(x: StatementBlock);
		BEGIN HALT(100) (* abstract *) END VisitStatementBlock;

		PROCEDURE VisitCode*(x: Code);
		BEGIN HALT(100) (* abstract *) END VisitCode;

	END Visitor;

	ArrayAccessOperators* = RECORD
		len*: Operator; (* length operator *)
		generalRead*, generalWrite*: Operator; (* operators on ARRAY [*] RANGE, for tensors *)
		read*, write*: POINTER TO ARRAY OF Operator; (* fixed-dim. operators *)
	END;

	FingerPrint*= RECORD
		shallow*,public*, private*: LONGINT;
		shallowAvailable*, deepAvailable*: BOOLEAN;
	END;

	(** identifiers in a program text **)
	Identifier* = Basic.String;

	(** qualified identifiers << Identifier.Identifier >> **)
	QualifiedIdentifier* = OBJECT
		VAR
			prefix-, suffix-: Identifier;   (* use string index instead ? *)
			position-: LONGINT;

		PROCEDURE & InitQualifiedIdentifier( position: LONGINT;  prefix, suffix: Identifier);
		BEGIN
			(* ASSERT(suffix # invalidIdentifier); can happen but should be catched by the parser with error report and not here with trap *)
			SELF.position := position;
			SELF.prefix := prefix; SELF.suffix := suffix;
		END InitQualifiedIdentifier;

		PROCEDURE GetName*(VAR name: Basic.SegmentedName);
		VAR s: ARRAY 64 OF CHAR;
		BEGIN
			Basic.InitSegmentedName(name);
			IF prefix # invalidIdentifier THEN Basic.SuffixSegmentedName(name, prefix) END;
			Basic.SuffixSegmentedName(name, suffix)
		END GetName;


	END QualifiedIdentifier;

	(**** types ****)
	(**
		Type
			BasicType
				ObjectType
				NilType
				AnyType
				ByteType
				AddressType
				SizeType
				BooleanType
				SetType
				CharacterType
				RangeType
				NumberType
					IntegerType
					FloatType
					ComplexType
			QualifiedType
			StringType
			EnumerationType
			ArrayType
			MathArrayType
			PointerType
			PortType
			RecordType
			CellType
			ProcedureType
	*)

	Type* = OBJECT
		VAR
			typeDeclaration-: TypeDeclaration; (* link to declaration (if any), needed for printing, debugging and symbol lookup *)
			scope-: Scope; (* scope where the type has been declared *)
			resolved-: Type; (* indirection to resolved type to preserve qualified types *)
			position-,endposition-: LONGINT;
			state-: SET;
			hasPointers-: BOOLEAN;

			fingerprint-: FingerPrint;

			isRealtime-: BOOLEAN;
			recursion: BOOLEAN;

			sizeInBits-: LONGINT; (* allocation size of this type in bits *)
			alignmentInBits-: LONGINT;

		PROCEDURE & InitType*( position: LONGINT);
		BEGIN
			SELF.position := position; state := Undefined;
			typeDeclaration := NIL;
			scope := NIL;
			resolved := SELF;
			sizeInBits := MIN(LONGINT);
			alignmentInBits := 0;
			isRealtime := FALSE;
			recursion := FALSE;
			hasPointers := FALSE;
			InitFingerPrint(fingerprint);
		END InitType;

		PROCEDURE SetSize*(sizeInBits: LONGINT);
		BEGIN SELF.sizeInBits := sizeInBits
		END SetSize;

		PROCEDURE SetAlignmentInBits*(alignmentInBits: LONGINT);
		BEGIN SELF.alignmentInBits := alignmentInBits
		END SetAlignmentInBits;

		PROCEDURE End*( position: LONGINT );
		BEGIN SELF.endposition := position;
		END End;

		PROCEDURE SetFingerPrint*(CONST fp: FingerPrint);
		BEGIN
			SELF.fingerprint := fp
		END SetFingerPrint;

		PROCEDURE SetState*(state: LONGINT);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE SetHasPointers*(has: BOOLEAN);
		BEGIN
			hasPointers := has
		END SetHasPointers;

		PROCEDURE RemoveState*(state: LONGINT);
		BEGIN EXCL(SELF.state,state)
		END RemoveState;

		PROCEDURE SetTypeDeclaration*(typeDeclaration: TypeDeclaration);
		BEGIN SELF.typeDeclaration := typeDeclaration
		END SetTypeDeclaration;

		PROCEDURE SetScope*(scope: Scope);
		BEGIN SELF.scope := scope
		END SetScope;

		PROCEDURE SetRealtime*(isRealtime: BOOLEAN);
		BEGIN SELF.isRealtime := isRealtime
		END SetRealtime;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END SameType;

		(** assignment compatibility of this := SELF *)
		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END CompatibleTo;

		(** Returns if the type is a pointer  *)
		PROCEDURE IsPointer*(): BOOLEAN;
		BEGIN RETURN FALSE
		END IsPointer;

		(** Returns if the type consists of more than one parts. Implies that an instance of this type cannot be (easily) represented in one register. *)
		PROCEDURE IsComposite*(): BOOLEAN;
		BEGIN RETURN FALSE
		END IsComposite;

		(** Returns if the type needs to be traced for garbage collection *)
		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN IsPointer ();
		END NeedsTrace;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitType(SELF)
		END Accept;
				
		PROCEDURE IsRecordType*(): BOOLEAN;
		BEGIN
			RETURN FALSE;
		END IsRecordType;

	END Type;

	(* basic types, defined in global name space *)
	BasicType*= OBJECT(Type)
	VAR name-: Identifier;

		PROCEDURE & InitBasicType(CONST id: ARRAY OF CHAR; sizeInBits: LONGINT);
		VAR str: IdentifierString;
		BEGIN
			COPY(id, str);Basic.AppendNumber(str,sizeInBits); name := NewIdentifier(str);
			InitType(-1);
			SetSize(sizeInBits);
			SELF.name := name
		END InitBasicType;

		PROCEDURE SetName*(CONST id: ARRAY OF CHAR);
		BEGIN
			name := NewIdentifier(id);
		END SetName;

		PROCEDURE SetTypeDeclaration*(typeDeclaration: TypeDeclaration);
		BEGIN HALT(100);
		END SetTypeDeclaration;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBasicType(SELF)
		END Accept;

	END BasicType;

	(** <<OBJECT>>
		object type (base type of all objects)
	**)
	ObjectType*=OBJECT(BasicType)

		PROCEDURE & InitObjectType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Object",sizeInBits);
			hasPointers := TRUE;
		END InitObjectType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS ObjectType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS AnyType) OR (to IS ObjectType))
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitObjectType(SELF)
		END Accept;

		PROCEDURE IsPointer(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

	END ObjectType;

	(** <<NIL>>
		nil type (type of NIL pointers), may be replaced by any type
	**)
	NilType*=OBJECT(BasicType)

		PROCEDURE & InitNilType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Nil",sizeInBits);
			SetRealtime(TRUE);
			hasPointers := TRUE;
		END InitNilType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS NilType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS NilType) OR (to IS ObjectType) OR (to IS AnyType) OR (to IS PointerType) OR (to IS ProcedureType) OR (to IS AddressType)
		END CompatibleTo;

		PROCEDURE IsPointer(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitNilType(SELF)
		END Accept;
	END NilType;

	(** <<SYSTEM.BYTE>>
		any pointer type (pointer to record and pointer to array)
	**)
	AnyType*=OBJECT(BasicType)

		PROCEDURE & InitAnyType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Any",sizeInBits);
			hasPointers := TRUE;
		END InitAnyType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS AnyType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS AnyType)
		END CompatibleTo;

		PROCEDURE IsPointer(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitAnyType(SELF)
		END Accept;
	END AnyType;

	(** <<SYSTEM.BYTE>>
		byte type
	**)
	ByteType*=OBJECT(BasicType)

		PROCEDURE & InitByteType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Byte",sizeInBits);
			SetRealtime(TRUE);
		END InitByteType;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitByteType(SELF)
		END Accept;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS ByteType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS ByteType)
		END CompatibleTo;

	END ByteType;

	(** <<ADDRESS>>
		address type
	**)
	AddressType*=OBJECT(BasicType)

		PROCEDURE & InitAddressType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Address",sizeInBits);
			SetRealtime(TRUE);
		END InitAddressType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS AddressType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS AddressType) OR (to IS SizeType) OR (to IS IntegerType) & (to.sizeInBits >= sizeInBits) OR (to IS PointerType) & to(PointerType).isUnsafe
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitAddressType(SELF)
		END Accept;
	END AddressType;

	(** <<SIZE>>
		size type (signed address type)
	**)
	SizeType*=OBJECT(BasicType)

		PROCEDURE & InitSizeType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Size",sizeInBits);
			SetRealtime(TRUE);
		END InitSizeType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN	RETURN (this IS SizeType) OR (this IS IntegerType) & (this(IntegerType).signed = TRUE) & (this.sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS SizeType) OR (to IS AddressType) OR (to IS IntegerType) & (to.sizeInBits >= sizeInBits)
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSizeType(SELF)
		END Accept;
	END SizeType;


	(** <<BOOLEAN>>
		boolean type
	**)
	BooleanType*=OBJECT(BasicType)

		PROCEDURE & InitBooleanType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Boolean",sizeInBits);
			SetRealtime(TRUE);
		END InitBooleanType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this IS BooleanType
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS BooleanType)
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBooleanType(SELF)
		END Accept;
	END BooleanType;


	(** <<SET>>
		set type
	**)
	SetType*=OBJECT(BasicType)

		PROCEDURE & InitSetType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Set",sizeInBits);
			SetRealtime(TRUE);
		END InitSetType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS SetType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS SetType)
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSetType(SELF)
		END Accept;

	END SetType;

	(** <<CHAR, CHAR8, CHAR16, CHAR32>>
		character types
	**)
	CharacterType*=OBJECT(BasicType)

		PROCEDURE & InitCharacterType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@Character", sizeInBits);
			SetRealtime(TRUE);
		END InitCharacterType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS CharacterType) & (this.sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS CharacterType) OR (to IS ByteType)) & (to.sizeInBits >= sizeInBits)
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCharacterType(SELF)
		END Accept;

	END CharacterType;

	(** type of ranges (case constants, set elements, array indices)
		represented by basic type <<RANGE>>
	**)
	RangeType* = OBJECT(BasicType)
		PROCEDURE & InitRangeType(sizeInBits: LONGINT);
		BEGIN
			InitBasicType("@RangeType",sizeInBits);
			SetRealtime(TRUE);
		END InitRangeType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS RangeType)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitRangeType(SELF)
		END Accept;
	END RangeType;

	(* number types: IntegerType or FloatType *)
	NumberType*=OBJECT(BasicType)

		PROCEDURE & InitNumberType( CONST name: ARRAY OF CHAR; sizeInBits: LONGINT);
		BEGIN
			InitBasicType(name, sizeInBits);
			SetRealtime(TRUE);
		END InitNumberType;

	END NumberType;

	(** <<SHORTINT, INTEGER, LONGINT, HUGEINT>>
		integer types
	**)
	IntegerType*= OBJECT (NumberType)
	VAR signed-: BOOLEAN;

		PROCEDURE & InitIntegerType(sizeInBits: LONGINT; signed: BOOLEAN);
		BEGIN
			IF signed THEN
				InitNumberType("@Integer",sizeInBits);
			ELSE
				InitNumberType("@Unsigned",sizeInBits);
			END;
			SELF.signed := signed;
		END InitIntegerType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS IntegerType) & (this.sizeInBits = sizeInBits) & (this(IntegerType).signed = signed)
			OR (this IS SizeType) & (this.sizeInBits=sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN ((to IS IntegerType) OR (to IS AddressType) OR (to IS SizeType) OR (to IS ByteType)) & (to.sizeInBits >= sizeInBits) OR (to IS FloatType)
				OR (to IS ComplexType) & CompatibleTo((to(ComplexType).componentType))
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitIntegerType(SELF)
		END Accept;

	END IntegerType;

	(** <<REAL,LONGREAL>>
		real types: REAL, LONGREAL
	**)
	FloatType*= OBJECT (NumberType)

		PROCEDURE & InitFloatType(sizeInBits: LONGINT);
		BEGIN
			InitNumberType("@Float",sizeInBits);
		END InitFloatType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS FloatType) & (this.sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN (to IS FloatType) & (to.sizeInBits >= sizeInBits)
					OR (to IS ComplexType) & CompatibleTo((to(ComplexType).componentType))
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitFloatType(SELF)
		END Accept;

	END FloatType;

	(** <<COMPLEX,LONGCOMPLEX>>
		complex types: COMPLEX, LONGCOMPLEX
	**)
	ComplexType*= OBJECT (NumberType)
		VAR componentType-: Type; (* REAL or LONGREAL*)

		PROCEDURE & InitComplexType(componentType: Type);
		BEGIN
			ASSERT(componentType # NIL);
			SELF.componentType := componentType;
			sizeInBits := 2 * componentType.sizeInBits;
			InitNumberType("@Complex",sizeInBits);
		END InitComplexType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (this IS ComplexType) & (componentType.SameType(this(ComplexType).componentType))
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS ComplexType) & (componentType.CompatibleTo(to(ComplexType).componentType))
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitComplexType(SELF)
		END Accept;

	END ComplexType;

	(** <<qualifiedIdentifier = resolved>>
		named reference to a type
	**)
	QualifiedType* = OBJECT (Type)
		VAR
			qualifiedIdentifier-: QualifiedIdentifier;

		PROCEDURE & InitQualifiedType( position: LONGINT; scope: Scope;  qualifiedIdentifier: QualifiedIdentifier);
		BEGIN
			ASSERT(qualifiedIdentifier # NIL);
			InitType( position);
			SELF.scope := scope;
			SELF.qualifiedIdentifier := qualifiedIdentifier;
			resolved := NIL;
		END InitQualifiedType;

		PROCEDURE SetResolved*(resolved: Type);
		BEGIN SELF.resolved := resolved; IF resolved # NIL THEN hasPointers := resolved.hasPointers END;
		END SetResolved;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF) OR (resolved # NIL) & (this.resolved # NIL) & resolved.SameType(this.resolved)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.CompatibleTo(to)
		END CompatibleTo;

		PROCEDURE IsPointer(): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.IsPointer()
		END IsPointer;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & resolved.IsComposite()
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitQualifiedType(SELF)
		END Accept;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN (resolved # NIL) & (resolved.NeedsTrace());
		END NeedsTrace;
		
		PROCEDURE IsRecordType(): BOOLEAN;
		BEGIN
			RETURN (resolved # NIL) & (resolved.IsRecordType());
		END IsRecordType;
		

	END QualifiedType;

	(** string literal type **)
	StringType*= OBJECT(Type)
	VAR
		length-: LONGINT;
		baseType-: Type;

		PROCEDURE & InitStringType(position: LONGINT; baseType: Type; length: LONGINT);
		BEGIN
			InitType(position);
			SetRealtime(TRUE);
			SELF.length := length;
			SELF.baseType := baseType;
		END InitStringType;

		PROCEDURE SetLength*(length: LONGINT);
		BEGIN SELF.length := length
		END SetLength;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS StringType) & (this(StringType).length = length)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			IF to IS ArrayType THEN
				WITH to: ArrayType DO
					RETURN to.arrayBase.SameType(baseType.resolved) & ((to.form = Open) OR (to.staticLength >= length))
				END;
			ELSIF to IS CharacterType THEN
				RETURN (length=2) & baseType.CompatibleTo(to)
			ELSE RETURN FALSE
			END;
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitStringType(SELF)
		END Accept;

	END StringType;

	(** enumeration type of the form <<enum (base) red,green,blue end>> **)
	EnumerationType*=OBJECT(Type)
	VAR
		enumerationScope-: EnumerationScope;
		enumerationBase-: Type;
		rangeLowest-,rangeHighest-: LONGINT;

		PROCEDURE &InitEnumerationType(position: LONGINT; scope: Scope; enumerationScope: EnumerationScope);
		BEGIN
			InitType(position);
			SetRealtime(TRUE);
			SELF.scope := scope;
			enumerationBase := NIL;
			rangeLowest := 0; rangeHighest := 0;
			SELF.enumerationScope := enumerationScope;
			enumerationScope.ownerEnumeration := SELF;
		END InitEnumerationType;

		PROCEDURE SetEnumerationBase*(base: Type);
		BEGIN enumerationBase := base
		END SetEnumerationBase;

		PROCEDURE SetRange*(lowest,highest: LONGINT);
		BEGIN rangeLowest := lowest; rangeHighest := highest;
		END SetRange;

		PROCEDURE Extends*(this: EnumerationType): BOOLEAN;
		BEGIN	RETURN (SELF = this) OR (enumerationBase # NIL) & (enumerationBase.resolved(EnumerationType).Extends(this));
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this = SELF
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN (to IS EnumerationType) & (to(EnumerationType).Extends(SELF))
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitEnumerationType(SELF)
		END Accept;

	END EnumerationType;

	(** <<ARRAY [length] OF baseType>> *)
	ArrayType* = OBJECT (Type)
		VAR
			arrayBase-: Type;
			length-: Expression;
			staticLength-: LONGINT;
			form-: LONGINT; (* redundant: (form = Open) = (staticLength = 0) else (form = Static) *)

		PROCEDURE & InitArrayType(position: LONGINT; scope: Scope;  form: LONGINT);
		BEGIN
			length := NIL; arrayBase := NIL; InitType(position); staticLength := 0; SELF.form := form; SELF.scope := scope;
		END InitArrayType;

		PROCEDURE SetArrayBase*( type: Type );
		BEGIN
			arrayBase := type; IF (arrayBase # NIL) & (arrayBase.hasPointers) THEN SetHasPointers(TRUE) END;
		END SetArrayBase;

		PROCEDURE SetForm*(f: LONGINT);
		BEGIN
			form := f;
		END SetForm;
		

		PROCEDURE SetLength*(length: Expression);
		BEGIN
			SELF.length := length;
			IF (length.resolved # NIL) & (length.resolved IS IntegerValue) THEN
				staticLength := length.resolved(IntegerValue).value
			END;
		END SetLength;

		PROCEDURE Child*(nr: LONGINT):Type;
		BEGIN
			IF nr = 0 THEN RETURN SELF;
			ELSIF nr = 1 THEN RETURN arrayBase.resolved;
			ELSE RETURN arrayBase.resolved(ArrayType).Child(nr-1);
			END;
		END Child;

		(* recursion safety for cases such as
			A= POINTER TO ARRAY OF B;
			B= POINTER TO ARRAY OF A;
		*)
		PROCEDURE SameType*(this: Type): BOOLEAN;
		VAR result : BOOLEAN;
		BEGIN
			result := FALSE;
			IF this = SELF THEN
				result := TRUE
			ELSIF recursion THEN
				result := TRUE;
			ELSIF this IS ArrayType THEN
				recursion := TRUE;
				WITH this: ArrayType DO
					result := (this.form = form) & (this.staticLength = staticLength) & arrayBase.SameType(this.arrayBase.resolved);
				END;
			END;
			recursion := FALSE;
			RETURN result
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN (form = Static) & SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN arrayBase.resolved.NeedsTrace ();
		END NeedsTrace;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitArrayType(SELF)
		END Accept;

	END ArrayType;

	(** <<ARRAY '[' length | '*' | '?' ']' OF baseType>> **)
	MathArrayType* = OBJECT (Type)
		VAR
			arrayBase-: Type;
			length-: Expression;
			staticLength-: LONGINT;
			staticIncrementInBits-: LONGINT;
			form-: LONGINT;

		PROCEDURE & InitMathArrayType(position: LONGINT;scope: Scope; form: LONGINT);
		BEGIN
			length := NIL; arrayBase := NIL; InitType(position); staticLength := 0; staticIncrementInBits := 0; SELF.form := form; SELF.scope := scope;
		END InitMathArrayType;

		PROCEDURE SetForm*(form: LONGINT);
		BEGIN
			SELF.form := form; IF form # Static THEN SetHasPointers(TRUE) END;
		END SetForm;

		PROCEDURE SetArrayBase*( type: Type );
		BEGIN
			arrayBase := type; IF (arrayBase # NIL) & (arrayBase.hasPointers) THEN SetHasPointers(TRUE) END;
		END SetArrayBase;

		PROCEDURE SetLength*(length: Expression);
		BEGIN
			SELF.length := length;
			IF (length # NIL) & (length.resolved # NIL) & (length.resolved IS IntegerValue) THEN
				staticLength := length.resolved(IntegerValue).value;

				(* optimization: unless the base type is a dynamic array, make this array static *)
				IF ~((arrayBase # NIL) & (arrayBase IS MathArrayType) & (arrayBase(MathArrayType).form # Static)) THEN
					form := Static;
				END

			ELSIF length = NIL THEN
				form := Open;
			END;
		END SetLength;

		PROCEDURE SetIncrement*(increment: LONGINT);
		BEGIN staticIncrementInBits := increment
		END SetIncrement;

		(* recursion safety for cases such as
			A= POINTER TO ARRAY OF B;
			B= POINTER TO ARRAY OF A;
		*)
		PROCEDURE SameType*(this: Type): BOOLEAN;
		VAR result: BOOLEAN;
		BEGIN
			result := FALSE;
			IF this = SELF THEN
				result := TRUE
			ELSIF recursion THEN
				result := TRUE;
			ELSIF this IS MathArrayType THEN
				recursion := TRUE;
				WITH this: MathArrayType DO
					result := (this.form = form) & (this.staticLength = staticLength) &
					((arrayBase = NIL) & (this.arrayBase = NIL) OR (arrayBase # NIL) & (this.arrayBase # NIL) &
					arrayBase.SameType(this.arrayBase.resolved));
				END;
			END;
			recursion := FALSE;
			RETURN result
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			HALT(200); (*! implement *)
			RETURN (form = Static) & SameType(to)
		END CompatibleTo;

		(** get the element  type of a math array, i.e. the first type in the math array chain that is not a math array **)
		PROCEDURE ElementType*(): Type;
		VAR
			type: Type;
		BEGIN
			type := SELF;
			WHILE type IS MathArrayType DO
				type := type(MathArrayType).arrayBase.resolved
			END;
			RETURN type
		END ElementType;

		(** get the number of dimensions of a math array; 0 in case of tensors **)
		PROCEDURE Dimensionality*(): LONGINT;
		VAR
			type: Type;
			dim: LONGINT;
		BEGIN
			IF form = Tensor THEN
				dim := 0
			ELSE
				type := SELF;
				dim := 0;
				WHILE type IS MathArrayType DO
					ASSERT(type(MathArrayType).form # Tensor);
					INC(dim);
					type := type(MathArrayType).arrayBase.resolved
				END
			END;
			RETURN dim
		END Dimensionality;

		(** if the math array is of the form ARRAY [*, *, ..., *], i.e. contains no static length and is not a tensor either **)
		PROCEDURE IsFullyDynamic*(): BOOLEAN;
		VAR
			type: Type;
			result: BOOLEAN;
		BEGIN
			IF form = Tensor THEN
				result := FALSE;
			ELSE
				result := TRUE;
				type := SELF;
				WHILE type IS MathArrayType DO
					IF type(MathArrayType).form # Open THEN result := FALSE END;
					type := type(MathArrayType).arrayBase.resolved
				END
			END;
			RETURN result
		END IsFullyDynamic;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitMathArrayType(SELF)
		END Accept;

	END MathArrayType;

	(** <<POINTER TO pointerBase>> **)
	PointerType* = OBJECT (Type)
		VAR
			modifiers-: Modifier; (* set by the parser *)
			pointerBase-: Type;
			isPlain-: BOOLEAN;
			isUnsafe-: BOOLEAN;
			isDisposable-: BOOLEAN;
			isHidden-: BOOLEAN;

		PROCEDURE & InitPointerType(position: LONGINT; scope: Scope);
		BEGIN
			modifiers := NIL;
			pointerBase := NIL;
			isPlain := FALSE;
			isUnsafe := FALSE;
			isDisposable := FALSE;
			InitType(position);
			SELF.scope := scope;
			hasPointers := TRUE;
			isHidden := FALSE;
		END InitPointerType;

		PROCEDURE SetHidden*(hidden: BOOLEAN);
		BEGIN
			isHidden := hidden;
		END SetHidden;	(** <<POINTER TO pointerBase>> **)

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE SetPointerBase*( type: Type );
		BEGIN
			pointerBase := type;
		END SetPointerBase;

		PROCEDURE SetPlain*(plain: BOOLEAN);
		BEGIN
			isPlain := plain;
		END SetPlain;

		PROCEDURE SetUnsafe*(unsafe: BOOLEAN);
		BEGIN
			isUnsafe := unsafe;
		END SetUnsafe;

		PROCEDURE SetDisposable*(disposable: BOOLEAN);
		BEGIN
			isDisposable := disposable;
		END SetDisposable;

		PROCEDURE Extends*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; extension, base: Type;
		BEGIN
			result := FALSE;
			IF ((this IS ObjectType) OR (this IS AnyType)) & (pointerBase.resolved IS RecordType) THEN result := TRUE
			ELSE
				extension := pointerBase.resolved;
				IF this IS PointerType THEN
					base := this(PointerType).pointerBase.resolved;
				ELSIF this IS RecordType THEN
					base := this
				ELSE base := NIL
				END;
				IF (extension IS RecordType) & (base # NIL) THEN
					result := extension(RecordType).Extends(base)
				END;
			END;
			RETURN result
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN	RETURN (SELF = this) OR (this IS PointerType) & (this(PointerType).pointerBase.SameType(pointerBase.resolved) & (this(PointerType).isUnsafe = isUnsafe))
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN SameType(to) OR ~(to IS RecordType) & SELF.Extends(to)
		END CompatibleTo;

		PROCEDURE IsPointer(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsPointer;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitPointerType(SELF)
		END Accept;

	END PointerType;

	(** << PORT (IN | OUT) [(size)] >>**)
	PortType* = OBJECT (Type)
		VAR
			direction-: LONGINT;
			sizeExpression-: Expression; (* generated by parser *)
			sizeInBits-: LONGINT; (* computed by checker *)

		PROCEDURE & InitPortType(position: LONGINT; direction: LONGINT; sizeExpression: Expression; scope: Scope);
		BEGIN
			InitType(position);
			SELF.sizeExpression := sizeExpression;
			SELF.direction := direction;
			SELF.scope := scope;
		END InitPortType;

		PROCEDURE SetSize*(size: LONGINT);
		BEGIN sizeInBits := size
		END SetSize;

		PROCEDURE SetSizeExpression*(sizeExpression: Expression);
		BEGIN SELF.sizeExpression := sizeExpression
		END SetSizeExpression;


		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this IS PortType) & (this(PortType).direction = direction) & (this(PortType).sizeInBits = sizeInBits)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitPortType(SELF)
		END Accept;

	END PortType;

	(** << recordType =
		[POINTER TO] RECORD (baseType) .. END |
		OBJECT (baseType) .. END
	>> **)
	RecordType* = OBJECT (Type)
		VAR
			recordScope-:RecordScope;
			baseType-: Type;
			pointerType-: PointerType; (* for support of A = POINTER TO RECORD ... END and B = POINTER TO RECORD (A) END; *)
			modifiers-: Modifier;
			isObject-,isProtected: BOOLEAN;

			(* a math array type describing an object's array structure; NIL if the type does not exhibit an array structure *)
			arrayStructure-: MathArrayType;
			(* list of all operators needed to access an array-structured object type *)
			arrayAccessOperators-: ArrayAccessOperators;

		PROCEDURE & InitRecordType( position: LONGINT; scope: Scope; recordScope: RecordScope);
		BEGIN
			InitType( position);
			SELF.scope := scope;
			baseType := NIL;
			pointerType := NIL;
			SELF.recordScope := recordScope;
			ASSERT(recordScope # NIL);
			ASSERT(recordScope.ownerRecord = NIL); (* cannot register twice ! *)
			recordScope.ownerRecord := SELF;
			isObject := FALSE; isProtected := FALSE;
			arrayStructure := NIL;
			modifiers := NIL;
		END InitRecordType;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;
		
		PROCEDURE SetBaseType*( type: Type );
		BEGIN
			baseType := type; IF (baseType # NIL) & (baseType.hasPointers) THEN hasPointers := TRUE END;
		END SetBaseType;

		PROCEDURE SetPointerType*(pointerType: PointerType);
		BEGIN SELF.pointerType := pointerType
		END SetPointerType;

		PROCEDURE IsObject*(isObject: BOOLEAN);
		BEGIN SELF.isObject := isObject
		END IsObject;

		PROCEDURE IsActive*(): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			IF (recordScope.bodyProcedure # NIL) & (recordScope.bodyProcedure.procedureScope.body # NIL) & (recordScope.bodyProcedure.procedureScope.body.isActive) THEN RETURN TRUE END;
			base := GetBaseRecord();
			IF base # NIL THEN RETURN base.IsActive() END;
			RETURN FALSE
		END IsActive;

		PROCEDURE IsProtected*(): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			IF isProtected THEN RETURN TRUE END;
			base := GetBaseRecord();
			IF base # NIL THEN RETURN base.IsProtected() END;
			RETURN FALSE
		END IsProtected;

		PROCEDURE SetProtected*(protected: BOOLEAN);
		BEGIN SELF.isProtected := protected
		END SetProtected;

		PROCEDURE Level*():LONGINT;
		VAR type: RecordType; res: LONGINT;
		BEGIN
			type := SELF;
			res := 0;
			WHILE (type # NIL) & (type.baseType # NIL) DO
				INC(res);
				type := type.GetBaseRecord();
			END;
			RETURN res;
		END Level;

		PROCEDURE GetBaseRecord*():RecordType;
		BEGIN
			IF baseType = NIL THEN RETURN NIL; END;
			IF baseType.resolved IS RecordType THEN
				RETURN baseType.resolved(RecordType);
			ELSIF baseType.resolved IS PointerType THEN
				IF baseType.resolved(PointerType).pointerBase.resolved # NIL THEN
					RETURN baseType.resolved(PointerType).pointerBase.resolved(RecordType);
				END;
			END;
			RETURN NIL;
		END GetBaseRecord;

		PROCEDURE Extends*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; extension: Type;
		BEGIN
			result := FALSE;
			IF this = SELF THEN result := TRUE
			ELSIF this IS RecordType THEN
				IF (baseType # NIL) THEN
					extension := baseType.resolved;
					IF extension IS PointerType THEN
						result := extension(PointerType).Extends(this)
					ELSIF extension IS RecordType THEN
						result := extension(RecordType).Extends(this)
					END;
				END;
			END;
			RETURN result
		END Extends;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN (this = SELF)
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN	RETURN Extends(to)
		END CompatibleTo;

		PROCEDURE SetArrayStructure*(arrayStructure: MathArrayType);
		BEGIN SELF.arrayStructure := arrayStructure
		END SetArrayStructure;

		PROCEDURE SetArrayAccessOperators*(arrayAccessOperators: ArrayAccessOperators);
		BEGIN SELF.arrayAccessOperators := arrayAccessOperators
		END SetArrayAccessOperators;

		PROCEDURE HasArrayStructure*(): BOOLEAN;
		BEGIN RETURN (arrayStructure # NIL)
		END HasArrayStructure
		;
		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN recordScope.NeedsTrace();
		END NeedsTrace;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitRecordType(SELF)
		END Accept;
		
		PROCEDURE IsRecordType(): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END IsRecordType;

	END RecordType;

	CellType*=OBJECT (Type)
	VAR
		firstParameter-,lastParameter-: Parameter; numberParameters-: LONGINT;  (* parameters *)
		firstProperty-, lastProperty-: Property; numberProperties: LONGINT; (* capabilities *)
		cellScope-: CellScope;
		isCellNet-: BOOLEAN;
		modifiers-: Modifier;
		baseType-: Type;

		PROCEDURE &InitCellType(position: LONGINT; scope: Scope;  cellScope: CellScope);
		BEGIN
			InitType(position);
			SELF.scope := scope;
			numberParameters := 0; firstParameter := NIL; lastParameter := NIL;
			numberProperties := 0; firstProperty := NIL; lastProperty := NIL;
			SELF.cellScope := cellScope;
			isCellNet := FALSE;
			baseType := NIL;
		END InitCellType;

		PROCEDURE SetBaseType*(base: Type);
		BEGIN
			baseType := base;
		END SetBaseType;
		
		PROCEDURE GetBaseRecord*():RecordType;
		BEGIN
			IF baseType = NIL THEN RETURN NIL; END;
			IF baseType.resolved IS RecordType THEN
				RETURN baseType.resolved(RecordType);
			ELSIF baseType.resolved IS PointerType THEN
				IF baseType.resolved(PointerType).pointerBase.resolved # NIL THEN
					RETURN baseType.resolved(PointerType).pointerBase.resolved(RecordType);
				END;
			END;
			RETURN NIL;
		END GetBaseRecord;

		PROCEDURE AddParameter*(p: Parameter);
		BEGIN
			ASSERT(p # NIL);
			IF lastParameter= NIL THEN firstParameter := p ELSE lastParameter.nextParameter := p; p.prevParameter := lastParameter; END;
			lastParameter := p;
			INC(numberParameters);
		END AddParameter;

		PROCEDURE AddProperty*(p: Property);
		BEGIN
			ASSERT(p # NIL);
			IF lastProperty= NIL THEN firstProperty := p ELSE lastProperty.nextProperty := p; p.prevProperty := lastProperty; END;
			lastProperty := p;
			INC(numberProperties);
		END AddProperty;
		
		PROCEDURE FindParameter*(identifier: Identifier): Parameter;
		VAR p: Parameter;
		BEGIN
			p := firstParameter;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextParameter END;
			RETURN p;
		END FindParameter;

		PROCEDURE FindProperty*(identifier: Identifier): Property;
		VAR p: Property;
		BEGIN
			p := firstProperty;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextProperty END;
			RETURN p;
		END FindProperty;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE IsCellNet*(t: BOOLEAN);
		BEGIN isCellNet := t
		END IsCellNet;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		BEGIN RETURN this = SELF
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN RETURN SameType(to)
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN TRUE
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCellType(SELF)
		END Accept;

	END CellType;


	(** <<procedureType = PROCEDURE [{DELEGATE}] (firstParameter .. lastParameter): returnType>>
		also used as type for procedures
	**)
	ProcedureType* = OBJECT (Type)
		VAR
			modifiers-: Modifier; (* set by the parser *)
			returnType-: Type;
			returnTypeModifiers-: Modifier;
			hasUntracedReturn-: BOOLEAN;
			firstParameter-,lastParameter-: Parameter; numberParameters-: LONGINT;  (* parameters *)
			returnParameter-: Parameter; (* not really necessary in syntax tree but very handy for backends *)

			isDelegate-,isInterrupt-,noPAF-,noReturn-: BOOLEAN;
			pcOffset-: LONGINT; (* PC offset: used for ARM interrupt procedures *)
			callingConvention-: LONGINT;
			stackAlignment-: LONGINT;
			parameterOffset-: LONGINT; (* stack parameter offset caused by parameters on stack *)

		PROCEDURE & InitProcedureType( position: LONGINT; scope: Scope);
		BEGIN
			InitType( position);
			SELF.scope := scope;
			modifiers := NIL;
			firstParameter := NIL; lastParameter := NIL; numberParameters := 0; returnParameter := NIL;
			returnType := NIL;
			stackAlignment := 1;
			isDelegate := FALSE; isInterrupt := FALSE; noPAF := FALSE;
			callingConvention := OberonCallingConvention;
			parameterOffset := 0;
			pcOffset := 0;
			hasUntracedReturn := FALSE;
			returnTypeModifiers := NIL;
		END InitProcedureType;

		PROCEDURE SetNoPAF*(noPAF: BOOLEAN);
		BEGIN SELF.noPAF := noPAF
		END SetNoPAF;

		PROCEDURE SetNoReturn*(noReturn: BOOLEAN);
		BEGIN SELF.noReturn := noReturn
		END SetNoReturn;

		PROCEDURE SetPcOffset*(pcOffset: LONGINT);
		BEGIN SELF.pcOffset := pcOffset
		END SetPcOffset;

		PROCEDURE SetInterrupt*(isInterrupt: BOOLEAN);
		BEGIN SELF.isInterrupt := isInterrupt
		END SetInterrupt;

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE SetReturnTypeModifiers*(flags: Modifier);
		BEGIN returnTypeModifiers := flags
		END SetReturnTypeModifiers;

		PROCEDURE SetDelegate*(delegate: BOOLEAN);
		BEGIN SELF.isDelegate := delegate; SELF.hasPointers := delegate;
		END SetDelegate;
		
		PROCEDURE SetUntracedReturn*(untraced: BOOLEAN);
		BEGIN
			hasUntracedReturn := untraced;
		END SetUntracedReturn;

		PROCEDURE SetStackAlignment*(alignment: LONGINT);
		BEGIN
			stackAlignment := alignment;
		END SetStackAlignment;

		PROCEDURE SetParameterOffset*(ofs: LONGINT);
		BEGIN parameterOffset := ofs
		END SetParameterOffset;

		PROCEDURE SetReturnParameter*(parameter: Parameter);
		BEGIN returnParameter := parameter
		END SetReturnParameter;

		PROCEDURE SetCallingConvention*(cc: LONGINT);
		BEGIN callingConvention := cc
		END SetCallingConvention;

		PROCEDURE AddParameter*(p: Parameter);
		BEGIN
			ASSERT(p # NIL);
			IF lastParameter= NIL THEN firstParameter := p ELSE lastParameter.nextParameter := p; p.prevParameter := lastParameter; END;
			lastParameter := p;
			INC(numberParameters);
			ASSERT(p.access # {}); (* no hidden parameters ! *)
		END AddParameter;

		PROCEDURE RevertParameters*;
		VAR this,next: Parameter; pnum: LONGINT;
		BEGIN
			pnum := numberParameters;
			IF lastParameter # NIL THEN
				this := lastParameter;
				lastParameter := NIL;
				firstParameter := NIL;
				numberParameters := 0;
				WHILE this # NIL DO
					next := this.prevParameter;
					this.prevParameter := NIL; this.nextParameter := NIL;
					AddParameter(this);
					this := next;
				END;
			END;
			ASSERT(pnum = numberParameters);
		END RevertParameters;

		PROCEDURE SetReturnType*( type: Type );
		BEGIN
			returnType := type;
		END SetReturnType;

		PROCEDURE SameType*(this: Type): BOOLEAN;
		VAR result: BOOLEAN; p1,p2: Parameter;
		BEGIN
			result := FALSE;
			IF recursion THEN
				result := TRUE
			ELSIF this = SELF THEN
				result := TRUE
			ELSIF this IS ProcedureType THEN
				recursion := TRUE;
				WITH this: ProcedureType DO
					result := (returnType = NIL) & (this.returnType = NIL) OR (returnType # NIL) & (this.returnType # NIL) & returnType.SameType(this.returnType.resolved);
					result := result & (callingConvention = this.callingConvention);
					result := result & (noReturn = this.noReturn);
					IF result THEN
						p1 := firstParameter; p2 := this.firstParameter;
						WHILE (p1 # NIL) & (p2 # NIL) & (p1.access # Hidden) & (p2.access # Hidden) & (p1.kind = p2.kind) & (p1.type.SameType(p2.type) OR (p2.type.resolved # NIL) & p1.type.SameType(p2.type.resolved) OR (p1.type.resolved IS AddressType) & (p2.type.resolved IS PointerType) & p2.type.resolved(PointerType).isUnsafe) DO
							p1 := p1.nextParameter; p2 := p2.nextParameter
						END;
						result := ((p1=NIL) OR (p1.access = Hidden)) & ((p2=NIL)  OR (p2.access= Hidden));
					END;
				END;
			END;
			recursion := FALSE;
			RETURN result
		END SameType;

		PROCEDURE CompatibleTo*(to: Type): BOOLEAN;
		BEGIN
			RETURN SameType(to) & (~isDelegate OR to(ProcedureType).isDelegate) & (~to.isRealtime OR isRealtime);
		END CompatibleTo;

		PROCEDURE IsComposite(): BOOLEAN;
		BEGIN RETURN isDelegate
		END IsComposite;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitProcedureType(SELF)
		END Accept;
		
		(** Returns if the type needs to be traced for garbage collection *)
		PROCEDURE NeedsTrace*(): BOOLEAN;
		BEGIN RETURN isDelegate;
		END NeedsTrace;

	END ProcedureType;

	(**** expressions ****)

	Expression* = OBJECT
		VAR
			type-: Type; (* the expression's type. Resolved by checker *)
			assignable-: BOOLEAN;  (* expression can be assigned to (or used as var-parameter): expression := ... *)
			position-,endposition-: LONGINT;
			state-: SET;
			resolved-: Value;
			isHidden-: BOOLEAN;


		PROCEDURE End*( position: LONGINT );
		BEGIN SELF.endposition := position;
		END End;

		PROCEDURE SetState*(state: LONGINT);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE &InitExpression(position: LONGINT);
		BEGIN	SELF.position := position; state := Undefined; type := NIL; assignable := FALSE; resolved := NIL; isHidden := FALSE;
		END InitExpression;

		PROCEDURE SetHidden*(hidden: BOOLEAN);
		BEGIN isHidden := hidden
		END SetHidden;
		

		PROCEDURE SetType*(type: Type);
		BEGIN
			SELF.type := type;
		END SetType;

		PROCEDURE SetResolved*(value: Value);
		BEGIN SELF.resolved := value
		END SetResolved;

		PROCEDURE SetAssignable*(assignable: BOOLEAN);
		BEGIN SELF.assignable := assignable
		END SetAssignable;

		PROCEDURE Clone(): Expression;
		VAR clone: Expression;
		BEGIN
			(* support cloning here for more robust error reporting -- should not happen normally *)
			NEW(clone, position); RETURN clone
		END Clone;


		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitExpression(SELF)
		END Accept;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN FALSE;
		END NeedsTrace;

	END Expression;

	(** <<expression, expression, ...>> **)
	ExpressionList* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList;
		BEGIN NEW( list,8 );
		END InitList;

		PROCEDURE Length*( ): LONGINT;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddExpression*( d: Expression );
		BEGIN list.Add(d)
		END AddExpression;

		PROCEDURE GetExpression*( index: LONGINT ): Expression;
		VAR p: ANY;
		BEGIN
			p := list.Get(index); RETURN p(Expression);
		END GetExpression;

		PROCEDURE SetExpression*(index: LONGINT; expression: Expression);
		BEGIN list.Set(index,expression)
		END SetExpression;

		PROCEDURE RemoveExpression*(i: LONGINT);
		BEGIN list.RemoveByIndex(i);
		END RemoveExpression;

		PROCEDURE Revert*;
		VAR i,j,last: LONGINT; ei,ej: ANY;
		BEGIN
			last := Length()-1;
			FOR i := 0 TO last DO
				j := last-i;
				ei := list.Get(i);
				ej := list.Get(j);
				list.Set(i,ej);
				list.Set(j,ei);
			END;
		END Revert;

		PROCEDURE Clone*(VAR list: ExpressionList);
		VAR i: LONGINT;
		BEGIN
			IF list = NIL THEN NEW(list) END;
			FOR i := 0 TO Length()-1 DO
				list.AddExpression(CloneExpression(GetExpression(i)));
			END;
		END Clone;

	END ExpressionList;

	(** << {elements} >>  **)
	Set* = OBJECT (Expression)
		VAR elements-: ExpressionList; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitSet( position: LONGINT );
		BEGIN
			InitExpression( position );
			elements := NewExpressionList();
		END InitSet;

		PROCEDURE Clone(): Expression;
		VAR copy: Set;
		BEGIN
			NEW(copy, position); elements.Clone(copy.elements); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSet(SELF)
		END Accept;

	END Set;

	(** << [elements] >>  **)
	MathArrayExpression* = OBJECT (Expression)
		VAR elements-: ExpressionList; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitMathArrayExpression( position: LONGINT );
		BEGIN
			InitExpression( position );
			elements := NewExpressionList();
		END InitMathArrayExpression;

		PROCEDURE Clone(): Expression;
		VAR copy: MathArrayExpression;
		BEGIN
			NEW(copy, position); elements.Clone(copy.elements); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitMathArrayExpression(SELF)
		END Accept;

	END MathArrayExpression;

	(** <<operator left>> **)
	UnaryExpression* = OBJECT (Expression)
		VAR
			left-: Expression;
			operator-: LONGINT;  (* one of Scanner.Minus ... Scanner.Not *)

		PROCEDURE & InitUnaryExpression( position: LONGINT;  operand: Expression;  operator: LONGINT );
		BEGIN
			InitExpression( position );  SELF.left := operand;  SELF.operator := operator;
		END InitUnaryExpression;

		PROCEDURE SetLeft*(left: Expression);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE Clone(): Expression;
		VAR copy: UnaryExpression;
		BEGIN
			NEW(copy, position, CloneExpression(left), operator); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitUnaryExpression(SELF)
		END Accept;

	END UnaryExpression;

	(** <<left operator right>> **)
	BinaryExpression* = OBJECT (Expression)
		VAR
			left-, right-: Expression;
			operator-: LONGINT;  (* one of Scanner.Equal ... Scanner.Minus *)

		PROCEDURE & InitBinaryExpression( position: LONGINT;  left, right: Expression;  operator: LONGINT );
		BEGIN
			InitExpression( position );  SELF.left := left;  SELF.right := right;  SELF.operator := operator;
		END InitBinaryExpression;

		PROCEDURE SetLeft*(left: Expression);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;

		PROCEDURE Clone(): Expression;
		VAR copy: BinaryExpression;
		BEGIN
			NEW(copy, position, CloneExpression(left), CloneExpression(right), operator); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBinaryExpression(SELF)
		END Accept;

	END BinaryExpression;

	(** expression that denotes a range
	    <<[first] '..' [last] ['by' step] | '*' >>
	**)
	RangeExpression* = OBJECT (Expression)
	VAR
		first-, last-, step-: Expression;
		missingFirst-, missingLast-, missingStep-: BOOLEAN; (* only for printout*)
		context-: SHORTINT; (* one of ArrayIndex, SetElement or CaseGuard *)

		PROCEDURE &InitRangeExpression(position: LONGINT; first, last, step: Expression);
		BEGIN
			context := ArrayIndex; (* by default, a range represents array indices *)
			InitExpression(position);
			missingFirst := (first = NIL);
			missingLast := (last = NIL);
			missingStep := (step = NIL);
			SELF.first := first;
			SELF.last := last;
			SELF.step := step;
		END InitRangeExpression;

		PROCEDURE SetFirst*(first: Expression);
		BEGIN
			SELF.first := first
		END SetFirst;

		PROCEDURE SetLast*(last: Expression);
		BEGIN SELF.last := last
		END SetLast;

		PROCEDURE SetStep*(step: Expression);
		BEGIN SELF.step := step
		END SetStep;

		PROCEDURE SetContext*(context: SHORTINT);
		BEGIN
			SELF.context := context
		END SetContext;

		PROCEDURE Clone(): Expression;
		VAR copy: RangeExpression;
		BEGIN
			NEW(copy, position, CloneExpression(first), CloneExpression(last), CloneExpression(step)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitRangeExpression(SELF)
		END Accept;

	END RangeExpression;

	(** << ? >> **)
	TensorRangeExpression*=OBJECT (Expression);

		PROCEDURE &InitTensorRangeExpression(position: LONGINT);
		BEGIN
			InitExpression(position);
		END InitTensorRangeExpression;

		PROCEDURE Clone(): Expression;
		VAR copy: TensorRangeExpression;
		BEGIN
			NEW(copy, position); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitTensorRangeExpression(SELF)
		END Accept;

	END TensorRangeExpression;

	(** convert expression from expression.type to Conversion.type **)
	Conversion* = OBJECT (Expression)
		VAR
			expression-: Expression;
			typeExpression-: Expression; (* for printout *)

		PROCEDURE & InitConversion( position: LONGINT;  expression: Expression; type: Type; typeExpression: Expression);
		BEGIN
			InitExpression( position );  SELF.expression := expression;  SELF.typeExpression := typeExpression; SELF.type := type;
		END InitConversion;

		PROCEDURE SetExpression*(expression: Expression);
		BEGIN SELF.expression := expression
		END SetExpression;

		PROCEDURE Clone(): Expression;
		VAR copy: Conversion;
		BEGIN
			NEW(copy, position, CloneExpression(expression), type, CloneExpression(typeExpression)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitConversion(SELF)
		END Accept;

	END Conversion;

	(**** designators ****)

	(** abstract **)
	Designator* = OBJECT(Expression)
		VAR
			left-: Expression; (* currently only designators are allowed but for later purposes ... (as for example (a+b).c) *)

			relatedRhs-: Expression; (* the RHS of an assignment if this designator is used on the LHS: *)

			(* used if this designator contains an index operator call, e.g. 'asot.^"[]"(indexList)': *)
			relatedAsot-: Expression; (* the ASOT on which the index operator is called *)
			relatedIndexList-: ExpressionList; (* the index list *)
			modifiers-: Modifier;

		PROCEDURE &InitDesignator*(position: LONGINT);
		BEGIN
			InitExpression(position);
			left := NIL;
			relatedRhs := NIL;
			relatedAsot := NIL;
			relatedIndexList := NIL;
			modifiers := NIL;
		END InitDesignator;

		PROCEDURE SetLeft*(expression: Expression);
		BEGIN left := expression
		END SetLeft;

		PROCEDURE SetRelatedRhs*(relatedRhs: Expression);
		BEGIN SELF.relatedRhs := relatedRhs
		END SetRelatedRhs;

		PROCEDURE SetRelatedAsot*(relatedAsot: Expression);
		BEGIN SELF.relatedAsot := relatedAsot
		END SetRelatedAsot;

		PROCEDURE SetRelatedIndexList*(relatedIndexList: ExpressionList);
		BEGIN SELF.relatedIndexList := relatedIndexList
		END SetRelatedIndexList;

		PROCEDURE SetModifiers*(flags: Modifier);
		BEGIN modifiers := flags
		END SetModifiers;

		PROCEDURE Clone(): Expression;
		VAR clone: Designator;
		BEGIN
			(* support cloning here for more robust error reporting -- should not happen normally *)
			NEW(clone, position); RETURN clone
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitDesignator(SELF)
		END Accept;

	END Designator;


	(*** first phase (parse time) designators ***)

	(** <<identifier>>
		may designate any symbol such as Variable, TypeDeclaration, Procedure
	**)
	IdentifierDesignator* = OBJECT(Designator)
		VAR identifier-: Identifier;

		PROCEDURE &InitIdentifierDesignator(position: LONGINT; id: Identifier);
		BEGIN InitDesignator(position); identifier := id
		END InitIdentifierDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: IdentifierDesignator;
		BEGIN
			NEW(copy, position, identifier); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitIdentifierDesignator(SELF)
		END Accept;

	END IdentifierDesignator;

	(** <<left.identifier>>
		may designate a record / module element (constant, type, variable, procedure)
	**)
	SelectorDesignator* = OBJECT (Designator)
		VAR identifier-: Identifier;

		PROCEDURE & InitSelector(position: LONGINT; left: Designator; identifier: Identifier);
		BEGIN   InitDesignator(position); SELF.left := left; SELF.identifier := identifier;
		END InitSelector;

		PROCEDURE Clone(): Expression;
		VAR copy: SelectorDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), identifier); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSelectorDesignator(SELF)
		END Accept;

	END SelectorDesignator;


	(** <<left(arg1, arg2, ...)>>
		may designate a function call or a type guard
	**)
	ParameterDesignator* = OBJECT(Designator)
		VAR
			parameters-: ExpressionList;

		PROCEDURE &InitParameterDesignator(position: LONGINT; left: Designator; parameters: ExpressionList);
		BEGIN InitDesignator(position); SELF.left := left; SELF.parameters := parameters
		END InitParameterDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: ParameterDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), CloneExpressionList(parameters)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitParameterDesignator(SELF)
		END Accept;

	END ParameterDesignator;


	(** <<left^>>
		may designate a pointer dereference or a method supercall
	**)
	ArrowDesignator* = OBJECT (Designator)

		PROCEDURE &InitArrowDesignator(position: LONGINT; left: Designator);
		BEGIN InitDesignator(position); SELF.left := left;
		END InitArrowDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: ArrowDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left(Designator))); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitArrowDesignator(SELF)
		END Accept;

	END ArrowDesignator;

	(** <<left[parameters]>>
		designates an index designator, before checker
	**)
	BracketDesignator* = OBJECT(Designator)
		VAR parameters-: ExpressionList;

		PROCEDURE &InitBracketDesignator(position: LONGINT; left: Designator; parameters: ExpressionList);
		BEGIN InitDesignator(position); SELF.left := left; SELF.parameters := parameters;
		END InitBracketDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: BracketDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), CloneExpressionList(parameters)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBracketDesignator(SELF)
		END Accept;


	END BracketDesignator;

	(*** second phase (after checker) designators ***)

	(** symbol designator emerged from IdentifierDesignator or from Selector **)
	SymbolDesignator* = OBJECT(Designator)
	VAR
		symbol-: Symbol;

		PROCEDURE &InitSymbolDesignator(position: LONGINT; left: Designator; symbol: Symbol);
		BEGIN
			InitDesignator(position);
			SELF.left := left;
			SELF.symbol := symbol;
		END InitSymbolDesignator;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN
			position := SELF.position; v.VisitSymbolDesignator(SELF);
		END Accept;

		PROCEDURE Clone(): Expression;
		VAR copy: SymbolDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), symbol); RETURN copy
		END Clone;

		PROCEDURE SetSymbol*(s: Symbol);
		BEGIN SELF.symbol := s;
		END SetSymbol;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN symbol.NeedsTrace() & ((left = NIL) OR (left.NeedsTrace()));
		END NeedsTrace;

	END SymbolDesignator;

	(** <<left[parameters]>>
		(ranged) indexer
	**)
	IndexDesignator* = OBJECT(Designator)
		VAR
			parameters-: ExpressionList;
			hasRange-: BOOLEAN;
			hasTensorRange-: BOOLEAN;

		PROCEDURE &InitIndexDesignator(position: LONGINT; left: Designator);
		BEGIN
			InitDesignator(position);
			SELF.left := left;
			parameters := NewExpressionList();
			hasRange := FALSE;
			hasTensorRange := FALSE;
		END InitIndexDesignator;

		PROCEDURE HasRange*;
		BEGIN hasRange := TRUE;
		END HasRange;

		PROCEDURE HasTensorRange*;
		BEGIN hasTensorRange := TRUE;
		END HasTensorRange;

		PROCEDURE Clone(): Expression;
		VAR copy: IndexDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left));
			parameters.Clone(copy.parameters);
			copy.hasRange := hasRange; copy.hasTensorRange := hasTensorRange ; RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitIndexDesignator(SELF)
		END Accept;
		
		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN type.NeedsTrace() & left.NeedsTrace(); (* for x[y]: if x is untraced, then also x[y] should be treated untraced *)
		END NeedsTrace;

	END IndexDesignator;

	StatementDesignator* = OBJECT (Designator)
	VAR
		statement-: Statement;
		result-: Expression;

		PROCEDURE & InitStatementDesignator(position: LONGINT; s: Statement);
		BEGIN
			InitDesignator(position); statement := s; result := NIL;
		END InitStatementDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: StatementDesignator;
		BEGIN
			NEW(copy, position, CloneStatement(statement)) ;
			copy.result := CloneExpression(result);
			RETURN copy
		END Clone;

		PROCEDURE SetResult*(r: Expression);
		BEGIN result := r
		END SetResult;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitStatementDesignator(SELF)
		END Accept;

	END StatementDesignator;

	(** <<left(parameters)>>
		procedure call
	**)
	ProcedureCallDesignator*= OBJECT (Designator)
		VAR parameters-: ExpressionList;

		PROCEDURE & InitProcedureCallDesignator(position: LONGINT; left: Designator;  parameters: ExpressionList);
		BEGIN
			InitDesignator(position); SELF.left := left; SELF.parameters := parameters;
		END InitProcedureCallDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: ProcedureCallDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), CloneExpressionList(parameters)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitProcedureCallDesignator(SELF)
		END Accept;

	END ProcedureCallDesignator;

	(** <<procedure(parameters)>>
		builtin procedure call **)
	BuiltinCallDesignator*= OBJECT (Designator) (*! should this be an extension of a procedure call designator ? *)
		VAR
			id-: LONGINT;
			parameters-: ExpressionList;
			builtin-: Builtin;

		PROCEDURE & InitBuiltinCallDesignator(position: LONGINT; id: LONGINT; left: Designator; parameters: ExpressionList);
		BEGIN
			InitDesignator(position); SELF.parameters := parameters; SELF.id := id; SELF.left := left;
		END InitBuiltinCallDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: BuiltinCallDesignator;
		BEGIN
			NEW(copy, position, id, CloneDesignator(left), CloneExpressionList(parameters)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBuiltinCallDesignator(SELF)
		END Accept;

	END BuiltinCallDesignator;

	(** <<left(type)>>
		resolved parameter designator, designates a type guard
	**)
	TypeGuardDesignator* = OBJECT(Designator)
	VAR
		typeExpression-: Expression; (* for printing only *)

		PROCEDURE &InitTypeGuardDesignator(position: LONGINT; left: Designator; type: Type);
		BEGIN InitDesignator(position); SELF.left := left; SELF.type := type; typeExpression := NIL;
		END InitTypeGuardDesignator;

		PROCEDURE SetTypeExpression*(typeExpression: Expression);
		BEGIN SELF.typeExpression := typeExpression
		END SetTypeExpression;

		PROCEDURE Clone(): Expression;
		VAR copy: TypeGuardDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left), type); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitTypeGuardDesignator(SELF)
		END Accept;
		
		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN left.NeedsTrace() & type.NeedsTrace(); (* for x(Y): if x is untraced, then x as Y should also be treated untraced  *)
		END NeedsTrace;

	END TypeGuardDesignator;

	(** <<left^>> resolved as dereference operation on pointer variable left **)
	DereferenceDesignator*= OBJECT (Designator)

		PROCEDURE &InitDereferenceDesignator(position: LONGINT; left: Designator);
		BEGIN InitDesignator(position); SELF.left := left;
		END InitDereferenceDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: DereferenceDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitDereferenceDesignator(SELF)
		END Accept;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN left.NeedsTrace() & type.NeedsTrace(); (* for x^: if x is an untraced pointer, the content of x^ is also treated untraced *)
		END NeedsTrace;

	END DereferenceDesignator;

	(** <<left^>> resolved as supercall operation on method left **)
	SupercallDesignator*= OBJECT (Designator)

		PROCEDURE &InitSupercallDesignator(position: LONGINT; left: Designator);
		BEGIN InitDesignator(position); SELF.left := left;
		END InitSupercallDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: SupercallDesignator;
		BEGIN
			NEW(copy, position, CloneDesignator(left)); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSupercallDesignator(SELF)
		END Accept;

	END SupercallDesignator;

	(**  <<SELF.x>> **)
	SelfDesignator*= OBJECT (Designator)

		PROCEDURE &InitSelfDesignator(position: LONGINT);
		BEGIN InitDesignator(position);
		END InitSelfDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: SelfDesignator;
		BEGIN
			NEW(copy, position); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSelfDesignator(SELF)
		END Accept;
		
		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN type.NeedsTrace();
		END NeedsTrace;


	END SelfDesignator;

	(** <<RESULT>> **)
		ResultDesignator*= OBJECT (Designator)

		PROCEDURE &InitResultDesignator(position: LONGINT);
		BEGIN InitDesignator(position);
		END InitResultDesignator;

		PROCEDURE Clone(): Expression;
		VAR copy: ResultDesignator;
		BEGIN
			NEW(copy, position); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitResultDesignator(SELF)
		END Accept;

	END ResultDesignator;

	(**** values ****)

	Value* = OBJECT (Expression)
	VAR fingerprint-: FingerPrint;

		PROCEDURE &InitValue(position: LONGINT);
		BEGIN SELF.position := position; resolved := SELF; InitFingerPrint(fingerprint);
		END InitValue;

		PROCEDURE SetFingerPrint*(CONST fp: FingerPrint);
		BEGIN
			SELF.fingerprint := fp
		END SetFingerPrint;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN HALT(100); (* abstract *) RETURN FALSE; END Equals;

	END Value;

	(** <<value = TRUE , FALSE>> **)
	BooleanValue* = OBJECT (Value)
		VAR
			value-: BOOLEAN;

		PROCEDURE & InitBooleanValue(position: LONGINT; value: BOOLEAN);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitBooleanValue;

		PROCEDURE SetValue*(value: BOOLEAN);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Clone(): Expression;
		VAR copy: BooleanValue;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBooleanValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS BooleanValue) & (v(BooleanValue).value = value); END Equals;

	END BooleanValue;

	(** <<value = 123456>> **)
	IntegerValue* = OBJECT (Value)
		VAR
			hvalue-: HUGEINT;
			value-: LONGINT;

		PROCEDURE & InitIntegerValue(position: LONGINT; hvalue: HUGEINT);
		BEGIN
			InitValue(position);  SELF.hvalue := hvalue; SELF.value := SHORT(hvalue);
		END InitIntegerValue;

		PROCEDURE SetValue*(hvalue: HUGEINT);
		BEGIN	SELF.hvalue := hvalue; SELF.value := SHORT(hvalue);
		END SetValue;

		PROCEDURE Clone(): Expression;
		VAR copy: IntegerValue;
		BEGIN
			NEW(copy, position, hvalue); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitIntegerValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS IntegerValue) & (v(IntegerValue).value = value); END Equals;

	END IntegerValue;

	(** <<value =  'c',  65X>> **)
	CharacterValue*= OBJECT(Value)
		VAR
			value-: CHAR; (* potential for extension to support CHAR16 and CHAR32 *)

		PROCEDURE & InitCharacterValue(position:LONGINT; value: CHAR);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitCharacterValue;

		PROCEDURE SetValue*(value: CHAR);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Clone(): Expression;
		VAR copy: CharacterValue;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCharacterValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS CharacterValue) & (v(CharacterValue).value = value); END Equals;

	END CharacterValue;

	SetValueType = SetValue;
	(** <<value =  {1,2,3..5}>> **)
	SetValue* = OBJECT (Value)
		VAR
			value-: SET;

		PROCEDURE & InitSetValue(position: LONGINT; value: SET);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitSetValue;

		PROCEDURE SetValue*(value: SET);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Clone(): Expression;
		VAR copy: SetValueType;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSetValue(SELF)
		END Accept;

	END SetValue;

		(** << [elements] >>  **)
	MathArrayValue* = OBJECT (Value)
		VAR array-: MathArrayExpression; (* an element of the form from .. to is represented as a RangeExpression *)

		PROCEDURE & InitMathArrayValue(position: LONGINT);
		BEGIN
			InitValue(position);
			array := NIL;
		END InitMathArrayValue;

		PROCEDURE SetArray*(array: MathArrayExpression);
		BEGIN SELF.array := array
		END SetArray;

		PROCEDURE Clone(): Expression;
		VAR copy: MathArrayValue;
		BEGIN
			NEW(copy, position);
			IF array # NIL THEN copy.array := array.Clone()(MathArrayExpression) END;
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitMathArrayValue(SELF)
		END Accept;

	END MathArrayValue;

	(** <<value = 1.2345E01>> **)
	RealValue* = OBJECT (Value)
		VAR
			value-: LONGREAL;
			subtype-: LONGINT; (* accuracy information: REAL vs. LONGREAL *)

		PROCEDURE & InitRealValue(position: LONGINT; value: LONGREAL);
		BEGIN
			InitValue(position);  SELF.value := value; SELF.subtype := 0;
		END InitRealValue;

		PROCEDURE SetValue*(value: LONGREAL);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE SetSubtype*(subtype: LONGINT);
		BEGIN SELF.subtype := subtype;
		END SetSubtype;

		PROCEDURE Clone(): Expression;
		VAR copy: RealValue;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitRealValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS RealValue) & (v(RealValue).value = value); END Equals;

	END RealValue;

	ComplexValue* = OBJECT (Value)
		VAR
			realValue-, imagValue-: LONGREAL;
			subtype-: LONGINT; (* accuracy information of components: REAL vs. LONGREAL *)

		PROCEDURE & InitComplexValue(position: LONGINT; realValue, imagValue: LONGREAL);
		BEGIN
			InitValue(position); SELF.realValue := realValue; SELF.imagValue := imagValue; SELF.subtype := 0;
		END InitComplexValue;

		PROCEDURE SetValue*(realValue, imagValue: LONGREAL);
		BEGIN	SELF.realValue := realValue; SELF.imagValue := imagValue;
		END SetValue;

		PROCEDURE UpdateSubtype*;
		BEGIN
			ASSERT((type # NIL) & (type.resolved # NIL) & (type.resolved IS ComplexType) & (type.resolved(ComplexType).componentType IS FloatType));
			CASE type.resolved(ComplexType).componentType(FloatType).sizeInBits OF
			| 32: subtype := Scanner.Real
			| 64: subtype := Scanner.Longreal
			END
		END UpdateSubtype;

		PROCEDURE SetSubtype*(subtype: LONGINT);
		BEGIN SELF.subtype := subtype;
		END SetSubtype;

		PROCEDURE Clone(): Expression;
		VAR copy: ComplexValue;
		BEGIN
			NEW(copy, position, realValue, imagValue); copy.subtype := subtype; RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitComplexValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS ComplexValue) & (v(ComplexValue).realValue = realValue) & (v(ComplexValue).imagValue = imagValue);
			(* TODO: append this?
			OR (v IS RealValue) & (v(RealValue).value = realValue) & (imagValue := 0)
			*)
		END Equals;
	END ComplexValue;

	(** <<value = "string">> **)
	StringValue* = OBJECT (Value)
		VAR
			value-: String;
			length-: LONGINT;

		PROCEDURE & InitStringValue(position: LONGINT; value: String);
		BEGIN
			InitValue(position);  SELF.value := value;
			length := 0;
			WHILE (length<LEN(value)) & (value[length] # 0X) DO
				INC(length);
			END;
			IF length < LEN(value) THEN INC(length) END
		END InitStringValue;

		PROCEDURE SetValue*(CONST value: String);
		BEGIN	SELF.value := value
		END SetValue;

		PROCEDURE Append*(CONST value: String);
		VAR new: String; len: LONGINT;
		BEGIN
			len := Strings.Length(SELF.value^) + Strings.Length(value^) + 1;
			IF LEN(SELF.value) < len THEN
				NEW(new, len);
				COPY(SELF.value^, new^);
				SELF.value := new
			END;
			Strings.Append(SELF.value^, value^);
			length := len
		END Append;

		PROCEDURE AppendChar*(CONST ch: CHAR);
		VAR v: String;
		BEGIN
			NEW(v,2); v[0] := ch;
			Append(v);
		END AppendChar;

		PROCEDURE Clone(): Expression;
		VAR copy: StringValue;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitStringValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS StringValue) & (v(StringValue).value = value); END Equals;

	END StringValue;

	(** <<value = NIL>> **)
	NilValue* = OBJECT (Value)

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitNilValue(SELF)
		END Accept;

		PROCEDURE Clone(): Expression;
		VAR copy: NilValue;
		BEGIN
			NEW(copy, position); RETURN copy
		END Clone;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS NilValue); END Equals;

	END NilValue;

	(** <<value = enum.x >> **)
	EnumerationValue* = OBJECT (Value)
	VAR
		value-: LONGINT;

		PROCEDURE & InitEnumerationValue(position: LONGINT; value: LONGINT);
		BEGIN
			InitValue(position);  SELF.value := value;
		END InitEnumerationValue;

		PROCEDURE SetValue*(value: LONGINT);
		BEGIN SELF.value := value
		END SetValue;

		PROCEDURE Clone(): Expression;
		VAR copy: EnumerationValue;
		BEGIN
			NEW(copy, position, value); RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitEnumerationValue(SELF)
		END Accept;

		PROCEDURE Equals*(v: Value):BOOLEAN;
		BEGIN RETURN (v IS EnumerationValue) & (v(EnumerationValue).value = value); END Equals;

	END EnumerationValue;

	(**** symbols ****)

	Symbol*= OBJECT
	VAR
		nextSymbol-: Symbol;

		name-: Identifier; (* constant / variable / parameter / type name / module name *)
		externalName-: Scanner.StringType;  (* variable / procedure *)
		access-: SET; (* access flags (exported, readonly etc.) *)
		type-: Type; (* type of constant / variable / parameter / procedure return type *)
		scope-:Scope; (* container of symbol *)
		offsetInBits-: LONGINT; (* offset in stack or heap, in bits *)
		used-, written-: BOOLEAN;
		fixed-: BOOLEAN;
		alignment-: LONGINT;

		position-: LONGINT; state-: SET;
		fingerprint-: FingerPrint;

		comment-: Comment;


		PROCEDURE & InitSymbol(position: LONGINT; name:Identifier);
		BEGIN
			SELF.position := position; state := Undefined;
			nextSymbol := NIL;
			SELF.name := name;
			externalName := NIL;
			scope:= NIL;
			type := NIL;
			access := Internal;
			state := Undefined;
			offsetInBits := MIN(LONGINT);
			alignment := 0; (* take default *)
			fixed := FALSE;
			used := FALSE; written := FALSE;
			InitFingerPrint(fingerprint);
			comment := NIL;
		END InitSymbol;

		PROCEDURE SetAlignment*(fix: BOOLEAN; align: LONGINT);
		BEGIN SELF.alignment := align; fixed := fix;
		END SetAlignment;

		PROCEDURE SetFingerPrint*(CONST fp: FingerPrint);
		BEGIN
			SELF.fingerprint := fp
		END SetFingerPrint;

		PROCEDURE SetState*(state: LONGINT);
		BEGIN	INCL(SELF.state,state);
		END SetState;

		PROCEDURE SetScope*(scope: Scope);
		BEGIN	SELF.scope := scope
		END SetScope;

		PROCEDURE SetType*(type: Type);
		BEGIN
			SELF.type := type;
		END SetType;

		PROCEDURE SetNext*(symbol: Symbol);
		BEGIN SELF.nextSymbol := symbol; END SetNext;

		PROCEDURE SetAccess*(access: SET);
		BEGIN
			(* consistency guarantee *)
			IF PublicWrite IN access THEN ASSERT(ProtectedWrite IN access)  END;
			IF ProtectedWrite IN access THEN ASSERT(InternalWrite IN access) END;
			IF PublicRead IN access THEN ASSERT(ProtectedRead IN access)  END;
			IF ProtectedRead IN access THEN ASSERT(InternalRead IN access)END;
			SELF.access := access;
		END SetAccess;

		PROCEDURE SetOffset*(ofs: LONGINT);
		BEGIN offsetInBits := ofs
		END SetOffset;

		PROCEDURE MarkUsed*;
		BEGIN used := TRUE
		END MarkUsed;

		PROCEDURE MarkWritten*;
		BEGIN written := TRUE
		END MarkWritten;

		PROCEDURE GetName*(VAR str: ARRAY OF CHAR);
		BEGIN Basic.GetString(name, str);
		END GetName;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitSymbol(SELF)
		END Accept;
		
		PROCEDURE SetExternalName*(name: Scanner.StringType);
		BEGIN externalName := name;
		END SetExternalName;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN FALSE;
		END NeedsTrace;

	END Symbol;

	(**
		<<TYPE name = declaredType>>
		TypeDeclaration symbol represents a type declaration of the form TYPE name  = declaredType.
		Note that the declared type is not stored in the symbol's type field but rather in the declaredType field.
		The type of a type declaration is set to "typeDeclarationType" in the semantic checker
	**)
	TypeDeclaration*= OBJECT(Symbol)
	VAR
		nextTypeDeclaration-: TypeDeclaration;
		declaredType-: Type;

		PROCEDURE &InitTypeDeclaration(position: LONGINT; name: Identifier);
		BEGIN
			InitSymbol(position,name);
			nextTypeDeclaration := NIL;
			declaredType := NIL;
			type := typeDeclarationType;
		END InitTypeDeclaration;

		PROCEDURE SetDeclaredType*(type: Type);
		BEGIN
			declaredType := type;
			IF ~(type IS BasicType) THEN
				type.typeDeclaration := SELF;
			END;
		END SetDeclaredType;

		PROCEDURE SetType*(type: Type);
		BEGIN
			ASSERT(type = typeDeclarationType);
		END SetType;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitTypeDeclaration(SELF)
		END Accept;

	END TypeDeclaration;


	(** <<CONST name = value >>
		Constant declaration symbol. Represents a constant being defined in the form CONST name  =  value
		The type of the constant is stored in the type field and is resolved by the semantic checker.
	**)
	Constant* = OBJECT (Symbol)
	VAR
		value-: Expression;
		nextConstant-: Constant;

		PROCEDURE & InitConstant( position: LONGINT;  name: Identifier );
		BEGIN
			InitSymbol(position,name);
			value := NIL;
			nextConstant := NIL;
		END InitConstant;

		PROCEDURE SetValue*( value: Expression );
		BEGIN
			SELF.value := value;
		END SetValue;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitConstant(SELF)
		END Accept;

	END Constant;

	(** <<VAR name: type >>
		Variable declaration symbol. Represents a variable defined in the form VAR name: Type.
		The type of the variable is stored in the symbol's type field and is resolved by the semantic checker.
	**)
	Variable* = OBJECT (Symbol)
	VAR
		nextVariable-: Variable;
		untraced-: BOOLEAN;
		useRegister-: BOOLEAN; registerNumber-: LONGINT;
		modifiers-: Modifier;
		initializer-: Expression;

		usedAsReference-: BOOLEAN;

		PROCEDURE & InitVariable*( position: LONGINT;  name: Identifier);
		BEGIN
			InitSymbol(position,name);
			nextVariable := NIL;
			modifiers := NIL;
			untraced := FALSE;
			modifiers := NIL;
			useRegister := FALSE;
			registerNumber := -1;
			usedAsReference := FALSE;
			initializer := NIL;
		END InitVariable;

		PROCEDURE UsedAsReference*;
		BEGIN
			usedAsReference := TRUE
		END UsedAsReference;


		PROCEDURE SetUntraced*(u: BOOLEAN);
		BEGIN untraced := u
		END SetUntraced;

		PROCEDURE SetUseRegister*(u: BOOLEAN);
		BEGIN
			useRegister := u
		END SetUseRegister;

		PROCEDURE SetRegisterNumber*(reg: LONGINT);
		BEGIN
			registerNumber := reg
		END SetRegisterNumber;


		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE SetInitializer*(initializer: Expression);
		BEGIN SELF.initializer := initializer;
		END SetInitializer;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitVariable(SELF)
		END Accept;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN ~untraced & (externalName = NIL) & type.NeedsTrace ();
		END NeedsTrace;

	END Variable;

	(** << [VAR | CONST] name: type >>
		Parameter declaration symbol. Represents a parameter in the form [VAR | CONST] name: Type.
		The parameter's type is stored in the symbol's type field and is resolved by the semantic checker.
	**)
	Parameter* = OBJECT (Symbol)
	VAR
		nextParameter-, prevParameter-: Parameter;
		modifiers-: Modifier;
		defaultValue-: Expression;

		kind-: LONGINT;   (* ValueParameter, ConstParameter, VarParameter *)
		ownerType-: Type;
		untraced-: BOOLEAN;
		movable-: BOOLEAN;

		PROCEDURE & InitParameter( position: LONGINT;  ownerType: Type ; name: Identifier; kind: LONGINT);
		BEGIN
			InitSymbol( position, name );
			SELF.kind := kind;
			IF kind = ConstParameter THEN access := access END;
			nextParameter := NIL;
			SELF.ownerType := ownerType;
			modifiers := NIL;
			untraced := FALSE;
			defaultValue := NIL;
			movable := FALSE;
		END InitParameter;

		PROCEDURE SetModifiers*(flag: Modifier);
		BEGIN SELF.modifiers := flag;
		END SetModifiers;

		PROCEDURE SetUntraced*(untraced: BOOLEAN);
		BEGIN SELF.untraced := untraced
		END SetUntraced;

		PROCEDURE SetMoveable*(movable: BOOLEAN);
		BEGIN SELF.movable := movable
		END SetMoveable;

		PROCEDURE SetDefaultValue*(e: Expression);
		BEGIN defaultValue := e
		END SetDefaultValue;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitParameter(SELF)
		END Accept;

		PROCEDURE SetKind*(kind: LONGINT);
		BEGIN SELF.kind := kind; END SetKind;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		BEGIN RETURN ~untraced  & type.NeedsTrace ();
		END NeedsTrace;

	END Parameter;
	
	Property* = OBJECT (Variable)
	VAR
		nextProperty-, prevProperty-: Property;
		value-: Expression;


		PROCEDURE & InitProperty(position: LONGINT;  name: Identifier);
		BEGIN
			InitSymbol( position, name );
		END InitProperty;

		PROCEDURE SetValue*(e: Expression);
		BEGIN value := e
		END SetValue;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitProperty(SELF)
		END Accept;

	END Property;


	(** Procedure declaration symbol. Represents a procedure being defined in the form PROCEDURE name(parameters): returnType;
		Note that the type of a procedure is a ProcedureType (and not the return type of the procedure).
		Parameters, local variables, constants and type declarations are stored in the procedureScope field.
	**)
	Procedure* = OBJECT (Symbol)
		VAR
			nextProcedure-: Procedure;
			procedureScope- : ProcedureScope;
			super-: Procedure;
			level-, methodNumber-: LONGINT;
			isBodyProcedure-, isConstructor-,isFinalizer-,isInline-,isOberonInline-, isEntry-, isExit-,isFinal-,isAbstract-,isOverwritten-: BOOLEAN;

		PROCEDURE & InitProcedure( position: LONGINT;  name: Identifier; scope: ProcedureScope);
		BEGIN
			InitSymbol(position,name);
			nextProcedure := NIL;
			procedureScope := scope;
			ASSERT(scope.ownerProcedure = NIL); (* cannot register twice ! *)
			scope.ownerProcedure := SELF;
			super := NIL;
			level := 0;
			methodNumber := -1;
			isBodyProcedure := FALSE;
			isConstructor := FALSE;
			isFinalizer := FALSE;
			isInline := FALSE;
			isOberonInline := FALSE;
			isEntry := FALSE;
			isExit := FALSE;
			isFinal := FALSE;
			isAbstract := FALSE;
			isOverwritten := FALSE;
		END InitProcedure;

		PROCEDURE SetSuper*(super: Procedure);
		BEGIN
			SELF.super := super
		END SetSuper;

		PROCEDURE SetBodyProcedure*(isBodyProcedure: BOOLEAN);
		BEGIN SELF.isBodyProcedure := isBodyProcedure;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(isConstructor: BOOLEAN);
		BEGIN SELF.isConstructor := isConstructor
		END SetConstructor;

		PROCEDURE SetFinalizer*(isFinalizer: BOOLEAN);
		BEGIN SELF.isFinalizer := isFinalizer
		END SetFinalizer;

		PROCEDURE SetInline*(isInline: BOOLEAN);
		BEGIN SELF.isInline := isInline
		END SetInline;

		PROCEDURE SetOberonInline*(isInline: BOOLEAN);
		BEGIN SELF.isOberonInline := isInline
		END SetOberonInline;

		PROCEDURE SetEntry*(entry: BOOLEAN);
		BEGIN SELF.isEntry := entry
		END SetEntry;

		PROCEDURE SetExit*(exit: BOOLEAN);
		BEGIN SELF.isExit := exit
		END SetExit;

		PROCEDURE SetFinal*(final: BOOLEAN);
		BEGIN SELF.isFinal := final
		END SetFinal;

		PROCEDURE SetOverwritten*(locallyOverwritten: BOOLEAN);
		BEGIN SELF.isOverwritten := locallyOverwritten
		END SetOverwritten;

		PROCEDURE SetAbstract*(abstract: BOOLEAN);
		BEGIN SELF.isAbstract := abstract
		END SetAbstract;

		PROCEDURE SetLevel*(level: LONGINT);
		BEGIN SELF.level := level
		END SetLevel;

		PROCEDURE SetMethodNumber*(methodNumber: LONGINT);
		BEGIN SELF.methodNumber := methodNumber
		END SetMethodNumber;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitProcedure(SELF)
		END Accept;

	END Procedure;


	(** Builtin symbol stands for a builtin procedure. Is resolved by the semantic checker. **)
	Builtin* = OBJECT (Symbol)
	VAR
		nextBuiltin-: Builtin;
		id-: LONGINT;

		PROCEDURE & InitBuiltin(position: LONGINT; name:Identifier; id: LONGINT);
		BEGIN
			InitSymbol(position,name); SELF.id := id;
		END InitBuiltin;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitBuiltin(SELF)
		END Accept;

	END Builtin;

	CustomBuiltin*=OBJECT (Builtin)
	VAR
		subType-: SHORTINT;

		PROCEDURE & InitCustomBuiltin(position: LONGINT; name: Identifier; id: LONGINT; subType: SHORTINT);
		BEGIN
			InitBuiltin(position,name,id);
			SELF.subType := subType;
		END InitCustomBuiltin;

		(* TODO: check if this is correct *)
		PROCEDURE CompatibleTo*(otherType: Type): BOOLEAN;
		BEGIN RETURN FALSE
		END CompatibleTo;

	END CustomBuiltin;

	Operator* = OBJECT (Procedure)
	VAR
		nextOperator-: Operator;
		isDynamic-: BOOLEAN; (* nopov *)

		PROCEDURE & InitOperator(position: LONGINT; name: Identifier; scope: ProcedureScope);
		BEGIN
			InitProcedure(position,name,scope);
			nextOperator := NIL;
			isDynamic := FALSE
		END InitOperator;

		(* nopov *)
		PROCEDURE SetDynamic*(isDynamic: BOOLEAN);
		BEGIN SELF.isDynamic := isDynamic
		END SetDynamic;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitOperator(SELF)
		END Accept;

	END Operator;

	Import* = OBJECT (Symbol)
		VAR
			nextImport-: Import;
			module-: Module;
			moduleName-: Identifier;
			context-: Identifier;
			direct-: BOOLEAN; (* direct import *)

		PROCEDURE & InitImport( position: LONGINT;  name, moduleName: Identifier; direct: BOOLEAN );
		BEGIN
			InitSymbol(position,name);
			SELF.direct := direct;
			module := NIL;
			context := invalidIdentifier;
			SELF.moduleName := moduleName;
			type := importType;
		END InitImport;

		PROCEDURE SetType*(type: Type);
		BEGIN
			ASSERT(type = importType);
		END SetType;

		PROCEDURE SetModule*(module: Module);
		BEGIN
			SELF.module := module;
		END SetModule;

		PROCEDURE SetDirect*(d: BOOLEAN);
		BEGIN
			direct := d
		END SetDirect;

		PROCEDURE SetModuleName*(moduleName: Identifier);
		BEGIN SELF.moduleName := moduleName
		END SetModuleName;

		PROCEDURE SetContext*(context: Identifier);
		BEGIN
			SELF.context := context
		END SetContext;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitImport(SELF)
		END Accept;

	END Import;

	StatementSequence* = OBJECT
		VAR
			list: Basic.List;

		PROCEDURE & InitList;
		BEGIN NEW( list,32 );
		END InitList;

		PROCEDURE Length*( ): LONGINT;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddStatement*( statement: Statement);
		BEGIN list.Add( statement );
		END AddStatement;

		PROCEDURE PrependStatement*( statement: Statement);
		BEGIN list.Prepend( statement );
		END PrependStatement;

		PROCEDURE HasStatement*( statement: Statement):BOOLEAN;
		BEGIN RETURN list.Contains(statement);
		END HasStatement;

		PROCEDURE GetStatement*( index: LONGINT ): Statement;
		VAR p: ANY;
		BEGIN p := list.Get( index );  RETURN p( Statement );
		END GetStatement;

		PROCEDURE SetStatement*(index: LONGINT; statement: Statement);
		BEGIN
			list.Set(index,statement);
		END SetStatement;

		PROCEDURE RemoveStatement*(statement: Statement);
		BEGIN
			list.Remove(statement);
		END RemoveStatement;

		PROCEDURE InsertBefore*(search, new: Statement);
		BEGIN
			list.Insert(list.IndexOf(search), new);
		END InsertBefore;

		PROCEDURE Clone(VAR copy: StatementSequence);
		VAR i: LONGINT;
		BEGIN
			IF copy = NIL THEN NEW(copy) END;
			FOR i := 0 TO Length()-1 DO
				copy.AddStatement(CloneStatement(GetStatement(i)))
			END;
		END Clone;

	END StatementSequence;

	(**** statements ****)

	Statement*= OBJECT
	VAR outer-: Statement;
		position-: LONGINT;
		isUnreachable-: BOOLEAN;

		comment-: Comment;

		PROCEDURE & InitStatement*(position: LONGINT; outer: Statement);
		BEGIN
			SELF.position := position;
			SELF.outer := outer;
			isUnreachable := FALSE;
			comment := NIL;
		END InitStatement;

		PROCEDURE SetOuter*(o: Statement);
		BEGIN outer := o
		END SetOuter;

		PROCEDURE SetUnreachable*(unreachable: BOOLEAN);
		BEGIN isUnreachable := unreachable
		END SetUnreachable;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitStatement(SELF)
		END Accept;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): Statement;
		BEGIN
			HALT(200) (* abstract *)
		END Clone;


	END Statement;

	(** << call(...) >> **)
	ProcedureCallStatement*= OBJECT(Statement)
		VAR call-: Designator;

		PROCEDURE & InitProcedureCallStatement(position: LONGINT; call: Designator; outer: Statement);
		BEGIN	InitStatement(position,outer); SELF.call := call;
		END InitProcedureCallStatement;

		PROCEDURE SetCall*(call: Designator);
		BEGIN	SELF.call := call;
		END SetCall;

		PROCEDURE Clone(): Statement;
		VAR copy: ProcedureCallStatement;
		BEGIN
			NEW(copy, position, CloneDesignator(call), outer);
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitProcedureCallStatement(SELF)
		END Accept;

	END ProcedureCallStatement;

	(** << left := right >> **)
	Assignment* = OBJECT (Statement)
	VAR left-: Designator; right-: Expression;

		PROCEDURE & InitAssignment*( position: LONGINT;  left: Designator;  right: Expression; outer: Statement );
		BEGIN
			InitStatement( position,outer );  SELF.left := left;  SELF.right := right;
		END InitAssignment;

		PROCEDURE SetLeft*(left: Designator);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;

		PROCEDURE Clone(): Statement;
		VAR copy: Assignment;
		BEGIN
			NEW(copy, position, CloneDesignator(left), CloneExpression(right), outer);
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitAssignment(SELF)
		END Accept;

	END Assignment;

	(** << left ('!' | '?' | '<<' | '>>') right >> **)
	CommunicationStatement* = OBJECT (Statement)
	VAR 
		left-: Designator; right-: Expression; op-: LONGINT;

		PROCEDURE & InitAssignment*( position: LONGINT; op: LONGINT; left: Designator;  right: Expression; outer: Statement );
		BEGIN
			InitStatement( position,outer );  SELF.op := op; SELF.left := left;  SELF.right := right;
		END InitAssignment;

		PROCEDURE SetLeft*(left: Designator);
		BEGIN SELF.left := left
		END SetLeft;

		PROCEDURE SetRight*(right: Expression);
		BEGIN SELF.right := right
		END SetRight;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCommunicationStatement(SELF)
		END Accept;

	END CommunicationStatement;


	(** << ... condition THEN statements ... >> **)
	IfPart*= OBJECT
	VAR
		condition-: Expression;
	 	statements-: StatementSequence;

	 	comment-: Comment;

	 	PROCEDURE & InitIfPart;
	 	BEGIN
	 		statements := NIL; condition := NIL; comment := NIL;
	 	END InitIfPart;

	 	PROCEDURE SetCondition*(condition: Expression);
	 	BEGIN SELF.condition := condition
	 	END SetCondition;

	 	PROCEDURE SetStatements*(statements: StatementSequence);
	 	BEGIN SELF.statements := statements
	 	END SetStatements;

	 	PROCEDURE SetComment*(comment: Comment);
	 	BEGIN SELF.comment := comment
	 	END SetComment;

	 	PROCEDURE Clone(): IfPart;
	 	VAR copy: IfPart;
	 	BEGIN
	 		NEW(copy); copy.condition := CloneExpression(condition);
	 		copy.statements := CloneStatementSequence(statements);
			RETURN copy
	 	END Clone;

	 END IfPart;

	(** << IF ifPart {ELSIF elsifParts} ELSE elseParts >> **)
	IfStatement* = OBJECT (Statement)
		VAR
			ifPart-: IfPart;
			elsifParts: Basic.List;
			elsePart-: StatementSequence;

		PROCEDURE & InitIfStatement( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement( position,outer ); ifPart := NewIfPart(); elsePart := NIL;  elsifParts := NIL;
		END InitIfStatement;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN
			SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE AddElsifPart*( elsifPart: IfPart );
		BEGIN
			IF elsifParts = NIL THEN NEW(elsifParts,4);  END;
			elsifParts.Add( elsifPart );
		END AddElsifPart;

		PROCEDURE GetElsifPart*( i: LONGINT ): IfPart;
		VAR a: ANY;
		BEGIN a := elsifParts.Get( i );  RETURN a( IfPart )
		END GetElsifPart;

		PROCEDURE ElsifParts*( ): LONGINT;
		BEGIN
			IF elsifParts = NIL THEN RETURN 0 ELSE RETURN elsifParts.Length();  END;
		END ElsifParts;

		PROCEDURE Clone(): Statement;
		VAR copy: IfStatement; i: LONGINT;
		BEGIN
			NEW(copy, position, outer);
			copy.ifPart := ifPart.Clone();
			FOR i := 0 TO ElsifParts()-1 DO
				copy.AddElsifPart(GetElsifPart(i).Clone());
			END;
			copy.SetElsePart(CloneStatementSequence(elsePart));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitIfStatement(SELF)
		END Accept;

	END IfStatement;

	WithPart*= OBJECT
	VAR
		variable-: Designator;
		type-: Type; (* initially is qualified type *)
		statements-: StatementSequence;

		comment-: Comment;

		PROCEDURE &InitWithPart();
		BEGIN
			type := NIL; variable := NIL; statements := NIL; comment := NIL;
		END InitWithPart;

		PROCEDURE SetVariable*( variable: Designator);
		BEGIN
			SELF.variable := variable
		END SetVariable;

		PROCEDURE SetType*( type: Type );
		BEGIN
			SELF.type := type
		END SetType;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): WithPart;
		VAR copy: WithPart;
		BEGIN
			NEW(copy);
			copy.SetVariable(CloneDesignator(variable));
			copy.SetType(type);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

	END WithPart;

	(** << WITH variable : type DO statements END >> **)
	WithStatement* = OBJECT (Statement)
		VAR
			withParts-: Basic.List;
			elsePart-: StatementSequence;

		PROCEDURE & InitWithStatement( position: LONGINT; outer: Statement );
		BEGIN
			InitStatement( position,outer );
			NEW(withParts,4); elsePart := NIL;
		END InitWithStatement;

		PROCEDURE AddWithPart*( withPart: WithPart );
		BEGIN withParts.Add( withPart );
		END AddWithPart;

		PROCEDURE GetWithPart*( i: LONGINT ): WithPart;
		VAR a: ANY;
		BEGIN a := withParts.Get( i );  RETURN a( WithPart )
		END GetWithPart;

		PROCEDURE WithParts*( ): LONGINT;
		BEGIN
			IF withParts = NIL THEN RETURN 0 ELSE RETURN withParts.Length();  END;
		END WithParts;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN
			SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE Clone(): Statement;
		VAR copy: WithStatement; i: LONGINT;
		BEGIN
			NEW(copy, position, outer);
			FOR i := 0 TO WithParts()-1 DO
				copy.AddWithPart(GetWithPart(i).Clone());
			END;
			copy.SetElsePart(CloneStatementSequence(elsePart));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitWithStatement(SELF)
		END Accept;

	END WithStatement;

	CaseConstant*= POINTER TO RECORD min*,max*: LONGINT; next*: CaseConstant END;

	(** << elements : statements >> **)
	CasePart* = OBJECT
		VAR
			elements-: ExpressionList; (* expression list inserted by the parser *)
			firstConstant-: CaseConstant; (* expression list resolved to int32s, inserted by checker *)
			statements-: StatementSequence;

			comment-: Comment;

		PROCEDURE & InitCasePart;
		BEGIN
			elements := NewExpressionList(); firstConstant := NIL;
		END InitCasePart;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE SetConstants*(firstConstant: CaseConstant);
		BEGIN SELF.firstConstant := firstConstant
		END SetConstants;

		PROCEDURE SetComment*(comment: Comment);
		BEGIN SELF.comment := comment
		END SetComment;

		PROCEDURE Clone(): CasePart;
		VAR copy: CasePart;
		BEGIN
			NEW(copy);
			copy.SetStatements(CloneStatementSequence(statements));
			copy.firstConstant := firstConstant;
			elements.Clone(copy.elements);
			RETURN copy
		END Clone;


	END CasePart;

	(** << CASE varaible OF caseParts ELSE elsePart >> **)
	CaseStatement* = OBJECT (Statement)
		VAR
			variable-: Expression;
			elsePart-: StatementSequence;
			caseParts-: Basic.List;
			min-,max-: LONGINT;

		PROCEDURE & InitCaseStatement( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement(position,outer );  variable := NIL;  elsePart := NIL;  caseParts := NIL;
			min := MAX(LONGINT); max := MIN(LONGINT);
		END InitCaseStatement;

		PROCEDURE SetVariable*( expression: Expression );
		BEGIN SELF.variable := expression;
		END SetVariable;

		PROCEDURE SetElsePart*( elsePart: StatementSequence );
		BEGIN SELF.elsePart := elsePart;
		END SetElsePart;

		PROCEDURE AddCasePart*( casePart: CasePart );
		BEGIN
			IF caseParts = NIL THEN NEW(caseParts,4);  END;
			caseParts.Add( casePart );
		END AddCasePart;

		PROCEDURE GetCasePart*( i: LONGINT ): CasePart;
		VAR a: ANY;
		BEGIN a := caseParts.Get( i );  RETURN a( CasePart )
		END GetCasePart;

		PROCEDURE CaseParts*( ): LONGINT;
		BEGIN
			IF caseParts = NIL THEN RETURN 0 ELSE RETURN caseParts.Length();  END;
		END CaseParts;

		PROCEDURE Clone(): Statement;
		VAR copy: CaseStatement; i: LONGINT;
		BEGIN
			NEW(copy, position, outer);
			copy.SetVariable(CloneExpression(variable));
			copy.SetElsePart(CloneStatementSequence(elsePart));
			FOR i := 0 TO CaseParts()-1 DO
				copy.AddCasePart(GetCasePart(i).Clone());
			END;
			copy.min := min; copy.max := max;
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCaseStatement(SELF)
		END Accept;

		PROCEDURE MaxConstant*(): LONGINT;
		VAR val,i: LONGINT; part: CasePart; const: CaseConstant;
		BEGIN
			val := -1;
			FOR i := 0 TO CaseParts() - 1 DO
				part := GetCasePart(i);
				const := part.firstConstant;
				WHILE(const # NIL) DO
					IF const.max > val THEN val := const.max; END;
					const := const.next;
				END;
			END;
			RETURN val;
		END MaxConstant;

		PROCEDURE SetMinMax*(min,max: LONGINT);
		BEGIN
			SELF.min := min; SELF.max := max;
		END SetMinMax;

	END CaseStatement;

	(** << WHILE condition DO statements END >> **)
	WhileStatement* = OBJECT (Statement)
		VAR
			condition-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitWhileStatement( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement( position,outer );  condition := NIL;  statements := NIL;
		END InitWhileStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN
			SELF.condition := condition
		END SetCondition;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: WhileStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitWhileStatement(SELF)
		END Accept;

	END WhileStatement;

	(** << REPEAT statements UNTIL condition >> **)
	RepeatStatement* = OBJECT (Statement)
		VAR
			condition-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitRepeatStatement( position: LONGINT; outer: Statement );
		BEGIN
			InitStatement( position,outer );  condition := NIL;  statements := NIL;
		END InitRepeatStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN
			SELF.condition := condition
		END SetCondition;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN
			SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: RepeatStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitRepeatStatement(SELF)
		END Accept;

	END RepeatStatement;

	(** << FOR variable := from TO to BY by DO statements END >> **)
	ForStatement* = OBJECT (Statement)
		VAR
			variable-: Designator;
			from-, to-, by-: Expression;
			statements-: StatementSequence;

		PROCEDURE & InitForStatement( position: LONGINT; outer: Statement );
		BEGIN
			InitStatement( position,outer );  variable := NIL;from := NIL;  to := NIL;  by := NIL; statements := NIL;
		END InitForStatement;

		PROCEDURE SetVariable*( variable: Designator);
		BEGIN
			SELF.variable := variable
		END SetVariable;

		PROCEDURE SetFrom*( from: Expression );
		BEGIN
			SELF.from := from
		END SetFrom;

		PROCEDURE SetTo*( to: Expression );
		BEGIN
			SELF.to := to
		END SetTo;

		PROCEDURE SetBy*( by: Expression );
		BEGIN SELF.by := by
		END SetBy;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: ForStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetVariable(CloneDesignator(variable));
			copy.SetFrom(CloneExpression(from));
			copy.SetTo(CloneExpression(to));
			copy.SetBy(CloneExpression(by));
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitForStatement(SELF)
		END Accept;

	END ForStatement;

	ExitableBlock*= OBJECT (Statement)
	VAR statements-: StatementSequence;

		PROCEDURE & InitExitableBlock( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement( position ,outer);  statements := NIL;
		END InitExitableBlock;

		PROCEDURE SetStatements*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatements;

		PROCEDURE Clone(): Statement;
		VAR copy: ExitableBlock;
		BEGIN
			NEW(copy, position, outer);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitExitableBlock(SELF)
		END Accept;

	END ExitableBlock;

	(** << LOOP statements END >> **)
	LoopStatement* = OBJECT (ExitableBlock)

		PROCEDURE Clone(): Statement;
		VAR copy: LoopStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetStatements(CloneStatementSequence(statements));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitLoopStatement(SELF)
		END Accept;

	END LoopStatement;

	(** << EXIT >> **)
	ExitStatement* = OBJECT (Statement)

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitExitStatement(SELF)
		END Accept;

		PROCEDURE Clone(): Statement;
		VAR copy: ExitStatement;
		BEGIN
			NEW(copy, position, outer);
			RETURN copy
		END Clone;

	END ExitStatement;

	(** << RETURN returnValue >> **)
	ReturnStatement* = OBJECT (Statement)
		VAR returnValue-: Expression; (* strictly speaking this is not a value but this term is in common use here *)

		PROCEDURE & InitReturnStatement( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement( position,outer );  returnValue := NIL
		END InitReturnStatement;

		PROCEDURE SetReturnValue*( returnValue: Expression );
		BEGIN SELF.returnValue := returnValue
		END SetReturnValue;

		PROCEDURE Clone(): Statement;
		VAR copy: ReturnStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetReturnValue(CloneExpression(returnValue));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitReturnStatement(SELF)
		END Accept;

	END ReturnStatement;

	(** << AWAIT condition >> **)
	AwaitStatement* = OBJECT (Statement)
		VAR condition-: Expression;

		PROCEDURE & InitAwaitStatement( position: LONGINT; outer: Statement );
		BEGIN
			InitStatement( position,outer );  condition := NIL
		END InitAwaitStatement;

		PROCEDURE SetCondition*( condition: Expression );
		BEGIN SELF.condition := condition
		END SetCondition;

		PROCEDURE Clone(): Statement;
		VAR copy: AwaitStatement;
		BEGIN
			NEW(copy, position, outer);
			copy.SetCondition(CloneExpression(condition));
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitAwaitStatement(SELF)
		END Accept;

	END AwaitStatement;

	(* << Identifier ( Expression) >> *)
	Modifier*= OBJECT
	VAR
		identifier-: Identifier; expression-: Expression;
		resolved-: BOOLEAN;
		nextModifier-: Modifier;
		position-: LONGINT;

		PROCEDURE & InitModifier(position: LONGINT; identifier: Identifier; expression: Expression);
		BEGIN
			SELF.position := position;
			SELF.identifier := identifier; SELF.expression := expression; nextModifier := NIL; resolved := FALSE;
		END InitModifier;

		PROCEDURE Resolved*;
		BEGIN resolved := TRUE
		END Resolved;

		PROCEDURE SetExpression*(e: Expression);
		BEGIN SELF.expression := e
		END SetExpression;

		PROCEDURE SetNext*(modifier: Modifier);
		BEGIN	nextModifier := modifier
		END SetNext;

	END Modifier;

	(** << BEGIN {Modifier, Modifier ... }  statements END >> **)
	StatementBlock* = OBJECT (Statement)
		VAR
			statements-: StatementSequence;
			blockModifiers-: Modifier;
			isExclusive-: BOOLEAN;
			isRealtime-: BOOLEAN;
			isUnchecked-: BOOLEAN;
			isUncooperative-: BOOLEAN;

		PROCEDURE & InitStatementBlock( position: LONGINT ; outer: Statement);
		BEGIN
			InitStatement( position ,outer);  statements := NIL;  blockModifiers := NIL;
			isExclusive := FALSE;
			isRealtime := FALSE;
			isUnchecked := FALSE;
			isUncooperative := FALSE;
		END InitStatementBlock;

		PROCEDURE SetRealtime*(b: BOOLEAN);
		BEGIN
			isRealtime := b
		END SetRealtime;

		PROCEDURE SetUnchecked*(unchecked: BOOLEAN);
		BEGIN
			isUnchecked := unchecked
		END SetUnchecked;

		PROCEDURE SetUncooperative*(uncooperative: BOOLEAN);
		BEGIN
			isUncooperative := uncooperative
		END SetUncooperative;

		PROCEDURE SetModifier*(modifier: Modifier);
		BEGIN
			blockModifiers := modifier;
		END SetModifier;

		PROCEDURE SetExclusive*(excl: BOOLEAN);
		BEGIN isExclusive := excl
		END SetExclusive;

		PROCEDURE SetStatementSequence*( statements: StatementSequence );
		BEGIN SELF.statements := statements;
		END SetStatementSequence;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitStatementBlock(SELF)
		END Accept;

	END StatementBlock;

	(** << CODE {flags} {character}  END >> **)
	Code*= OBJECT(Statement)
	VAR
		sourceCode-: SourceCode; sourceCodeLength-: LONGINT;
		inlineCode-: BinaryCode;
		inRules-, outRules-: StatementSequence;

		PROCEDURE & InitCode(position: LONGINT; outer: Statement);
		BEGIN
			InitStatement(position,outer);
			inlineCode := NIL;
			sourceCode := NIL; sourceCodeLength := 0;
			NEW(inRules); NEW(outRules);
		END InitCode;

		PROCEDURE SetSourceCode*(source: SourceCode; length: LONGINT);
		BEGIN sourceCode := source; sourceCodeLength := length;
			ASSERT(sourceCodeLength <= LEN(source));
		END SetSourceCode;

		PROCEDURE SetBinaryCode*(code: BinaryCode);
		BEGIN
			inlineCode := code;
		END SetBinaryCode;

		PROCEDURE Clone(): Statement;
		VAR copy: Code; s: Scanner.StringType;
		BEGIN
			NEW(copy, position, outer);
			NEW(s, sourceCodeLength);
			Strings.Copy(sourceCode^,0,sourceCodeLength,s^);
			copy.SetSourceCode(s, sourceCodeLength);
			copy.inRules := CloneStatementSequence(inRules);
			copy.outRules := CloneStatementSequence(outRules);
			RETURN copy
		END Clone;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitCode(SELF)
		END Accept;

	END Code;

	(** << BEGIN {flags} statements FINALLY statements END >> **)
	Body*= OBJECT(StatementBlock)
	VAR
		finally-: StatementSequence;
		priority-: Expression; (* set by checker *)
		inScope-: ProcedureScope;
		code-: Code;
		isActive-, isSafe-: BOOLEAN;

		PROCEDURE & InitBody(position: LONGINT; scope: ProcedureScope);
		BEGIN
			InitStatementBlock(position,NIL); finally := NIL; priority := NIL; inScope := scope; code := NIL;
			isActive := FALSE; isSafe := FALSE; isRealtime := FALSE;
		END InitBody;

		PROCEDURE SetActive*(active: BOOLEAN);
		BEGIN SELF.isActive := active
		END SetActive;

		PROCEDURE SetSafe*(safe: BOOLEAN);
		BEGIN SELF.isSafe := safe
		END SetSafe;

		PROCEDURE SetFinally*( finally: StatementSequence );
		BEGIN SELF.finally := finally
		END SetFinally;

		PROCEDURE SetPriority*(expression: Expression);
		BEGIN priority := expression
		END SetPriority;

		PROCEDURE SetCode*(code: Code);
		BEGIN SELF.code := code;
		END SetCode;

	END Body;

	(** (* comment *)  *)
	Comment*=OBJECT
	VAR position-: LONGINT;
		source-: String; (* currently: POINTER TO ARRAY OF CHAR *)
		scope-: Scope;
		item-: ANY; sameLine-: BOOLEAN;
		nextComment-: Comment;

		PROCEDURE & InitComment(pos: LONGINT; scope: Scope; CONST s: ARRAY OF CHAR; length: LONGINT);
		VAR i: LONGINT;
		BEGIN
			SELF.scope := scope;
			NEW(source,length);
			FOR i := 0 TO length-1 DO
				source[i] := s[i];
			END;
			SELF.position := pos;
			nextComment := NIL;
			item := NIL; sameLine := FALSE;
		END InitComment;

		PROCEDURE SetItem*(p: ANY; sameLine: BOOLEAN);
		BEGIN
			item := p; SELF.sameLine := sameLine
		END SetItem;

	END Comment;


	(**** building blocks ****)

	Scope*=OBJECT
		VAR
		firstSymbol-: Symbol; numberSymbols-: LONGINT; (* all symbols in scope (sorted) *)

		firstConstant-,lastConstant-: Constant;  numberConstants-: LONGINT; (* constants *)
		firstTypeDeclaration-,lastTypeDeclaration-: TypeDeclaration; numberTypeDeclarations-: LONGINT; (* type declarations *)
		firstVariable-,lastVariable-: Variable; numberVariables-: LONGINT;  (* variables *)
		firstProcedure-,lastProcedure-: Procedure; numberProcedures-: LONGINT;  (* procedures *)

		outerScope-: Scope; nextScope-: Scope;

		ownerModule-: Module;


		PROCEDURE & InitScope(outer: Scope);
		BEGIN
			firstSymbol := NIL; numberSymbols := 0;
			firstConstant := NIL; lastConstant := NIL; numberConstants := 0;
			firstTypeDeclaration := NIL; lastTypeDeclaration := NIL; numberTypeDeclarations := 0;
			firstVariable := NIL; lastVariable := NIL; numberVariables := 0;
			firstProcedure := NIL; lastProcedure := NIL; numberProcedures := 0;
			outerScope := outer;
			IF outer # NIL THEN
				ownerModule := outer.ownerModule
			ELSE
				ownerModule := NIL;
			END;
			nextScope := NIL;
		END InitScope;

		(** Enter a symbol in the scope, aplhabetically sorted, duplicate = TRUE if multiply identifier *)
		PROCEDURE EnterSymbol*(symbol: Symbol; VAR duplicate: BOOLEAN);
		VAR p,q: Symbol; name,nextname: Scanner.StringType;
		BEGIN
			ASSERT(symbol.nextSymbol = NIL,101); (* symbol may only be present in one scope at a time ! *)
			ASSERT(symbol.scope = NIL,102);
			ASSERT(symbol.name # invalidIdentifier,103);

			p := firstSymbol; q := NIL;
			WHILE (p # NIL) & (StringPool.CompareString(p.name,symbol.name)<0) DO q := p; p := p.nextSymbol END;
			IF (p#NIL) & (symbol.name = p.name) THEN
				duplicate := TRUE;
			ELSE
				duplicate := FALSE
			END;
			symbol.nextSymbol := p;
			IF q = NIL THEN firstSymbol := symbol ELSE q.nextSymbol := symbol END;
			symbol.SetScope(SELF);

			INC(numberSymbols);
		END EnterSymbol;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol;
		BEGIN
			IF identifier # invalidIdentifier THEN
				p := firstSymbol;
				WHILE(p#NIL) & ((p.name # identifier) OR (p IS Operator)) DO p := p.nextSymbol END;
			END;
			RETURN p;
		END FindSymbol;

		PROCEDURE AddConstant*(c: Constant);
		BEGIN
			ASSERT(c # NIL);
			IF lastConstant= NIL THEN firstConstant := c ELSE lastConstant.nextConstant := c END;
			lastConstant := c;
			INC(numberConstants);
		END AddConstant;

		PROCEDURE FindConstant*(identifier: Identifier): Constant;
		VAR p: Constant;
		BEGIN
			p := firstConstant;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextConstant END;
			RETURN p;
		END FindConstant;

		PROCEDURE AddTypeDeclaration*(t: TypeDeclaration);
		BEGIN
			ASSERT(t # NIL);
			IF lastTypeDeclaration= NIL THEN firstTypeDeclaration := t ELSE lastTypeDeclaration.nextTypeDeclaration := t END;
			INC(numberTypeDeclarations);
			lastTypeDeclaration := t;
		END AddTypeDeclaration;

		PROCEDURE FindTypeDeclaration*(identifier: Identifier): TypeDeclaration;
		VAR p: TypeDeclaration;
		BEGIN
			p := firstTypeDeclaration;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextTypeDeclaration END;
			RETURN p;
		END FindTypeDeclaration;

		PROCEDURE AddVariable*(v: Variable);
		BEGIN
			ASSERT(v # NIL);
			IF lastVariable= NIL THEN firstVariable := v ELSE lastVariable.nextVariable := v END;
			INC(numberVariables);
			lastVariable := v;
		END AddVariable;

		PROCEDURE PushVariable*(v: Variable);
		BEGIN
			ASSERT(v # NIL);
			IF lastVariable= NIL THEN lastVariable := v ELSE v.nextVariable := firstVariable END;
			INC(numberVariables);
			firstVariable := v;
		END PushVariable;

		PROCEDURE FindVariable*(identifier: Identifier): Variable;
		VAR p: Variable;
		BEGIN
			p := firstVariable;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextVariable END;
			RETURN p;
		END FindVariable;

		PROCEDURE AddProcedure*(p: Procedure);
		BEGIN
			ASSERT(p # NIL);
			IF lastProcedure= NIL THEN firstProcedure := p ELSE lastProcedure.nextProcedure := p END;
			INC(numberProcedures);
			lastProcedure := p;
		END AddProcedure;

		PROCEDURE FindProcedure*(identifier: Identifier): Procedure;
		VAR p: Procedure;
		BEGIN
			p := firstProcedure;
			WHILE (p#NIL) & ((p.name # identifier) OR (p IS Operator)) DO p := p.nextProcedure END;
			RETURN p;
		END FindProcedure;

		PROCEDURE FindMethod*(number: LONGINT): Procedure;
		VAR p: Procedure;
		BEGIN
			p := firstProcedure;
			WHILE (p# NIL) & (p.methodNumber # number) DO
				p := p.nextProcedure
			END;
			RETURN p;
		END FindMethod;


		PROCEDURE Level*(): LONGINT;
		VAR scope: Scope; level: LONGINT;
		BEGIN
			level := 0;
			scope := SELF;
			WHILE(scope.outerScope # NIL) DO
				scope := scope.outerScope;
				INC(level);
			END;
			RETURN level;
		END Level;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR variable: Variable;
		BEGIN
			variable := firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace () THEN RETURN TRUE END;
				variable := variable.nextVariable;
			END;
			RETURN FALSE;
		END NeedsTrace;

	END Scope;

	ProcedureScope*=OBJECT (Scope)
		VAR
		ownerProcedure-: Procedure;
		body-: Body;

		PROCEDURE & InitProcedureScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerProcedure := NIL;
			body := NIL;
		END InitProcedureScope;

		PROCEDURE SetBody*(body: Body);
		BEGIN
			SELF.body := body;
		END SetBody;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR parameter: Parameter;
		BEGIN
			parameter := ownerProcedure.type.resolved(ProcedureType).firstParameter;
			WHILE parameter # NIL DO
				IF parameter.NeedsTrace () THEN RETURN TRUE END;
				parameter := parameter.nextParameter;
			END;
			RETURN NeedsTrace^();
		END NeedsTrace;

	END ProcedureScope;


	EnumerationScope*= OBJECT(Scope)
	VAR
		ownerEnumeration-: EnumerationType;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: Type;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				base := ownerEnumeration.enumerationBase;
				IF (base # NIL) & (base.resolved IS EnumerationType) THEN
					p := base.resolved(EnumerationType).enumerationScope.FindSymbol(identifier)
				END;
			END;
			RETURN p;
		END FindSymbol;

		PROCEDURE &InitEnumerationScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerEnumeration := NIL; (* must be set by EnumerationType *)
		END InitEnumerationScope;

	END EnumerationScope;

	RecordScope*= OBJECT(Scope)
		VAR
			ownerRecord-: RecordType;
			bodyProcedure-: Procedure;
			constructor-: Procedure;
			finalizer-: Procedure;
			numberMethods-: LONGINT;
			firstParameter-,lastParameter-: Parameter; numberParameters-: LONGINT;  (* parameters for Active Cells programming*)
			firstOperator-, lastOperator-: Operator; numberOperators: LONGINT; (* defined operators *)

		PROCEDURE & InitRecordScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerRecord := NIL;
			numberMethods := 0;
			bodyProcedure := NIL;
			constructor := NIL;
			finalizer := NIL;
			firstOperator := NIL; lastOperator := NIL; numberOperators := 0;
		END InitRecordScope;

		PROCEDURE SetBodyProcedure*(body: Procedure);
		BEGIN SELF.bodyProcedure := body;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(body: Procedure);
		BEGIN SELF.constructor := body
		END SetConstructor;

		PROCEDURE SetFinalizer*(body: Procedure);
		BEGIN SELF.finalizer := body
		END SetFinalizer;

		PROCEDURE SetNumberMethods*(numberMethods: LONGINT);
		BEGIN SELF.numberMethods := numberMethods;
		END SetNumberMethods;

		PROCEDURE AddOperator*(p: Operator);
		BEGIN
			ASSERT(p # NIL);
			IF lastOperator= NIL THEN firstOperator := p ELSE lastOperator.nextOperator := p END;
			INC(numberOperators);
			lastOperator := p;
		END AddOperator;

		(** Find symbol by name *)
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: RecordType;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindSymbol(identifier)
				END;
			END;
			RETURN p;
		END FindSymbol;

		PROCEDURE FindConstant*(identifier: Identifier): Constant;
		VAR p: Constant; base: RecordType;
		BEGIN
			p := FindConstant^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindConstant(identifier)
				END;
			END;
			RETURN p;
		END FindConstant;

		PROCEDURE FindTypeDeclaration*(identifier: Identifier): TypeDeclaration;
		VAR p: TypeDeclaration; base: RecordType;
		BEGIN
			p := FindTypeDeclaration^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindTypeDeclaration(identifier)
				END;
			END;
			RETURN p;
		END FindTypeDeclaration;

		PROCEDURE FindVariable*(identifier: Identifier): Variable;
		VAR p: Variable; base: RecordType;
		BEGIN
			p := FindVariable^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindVariable(identifier)
				END;
			END;
			RETURN p;
		END FindVariable;

		PROCEDURE FindProcedure*(identifier: Identifier): Procedure;
		VAR p: Procedure; base: RecordType;
		BEGIN
			p := FindProcedure^(identifier);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindProcedure(identifier)
				END;
			END;
			RETURN p;
		END FindProcedure;

		PROCEDURE FindMethod*(number: LONGINT): Procedure;
		VAR p: Procedure; base: RecordType;
		BEGIN
			p := FindMethod^(number);
			IF p = NIL THEN
				base := ownerRecord.GetBaseRecord();
				IF (base # NIL) THEN
					p := base.recordScope.FindMethod(number)
				END;
			END;
			RETURN p;
		END FindMethod;

		PROCEDURE NeedsTrace* (): BOOLEAN;
		VAR base: RecordType;
		BEGIN
			base := ownerRecord.GetBaseRecord();
			IF (base # NIL) & (base.NeedsTrace ()) THEN RETURN TRUE END;
			RETURN NeedsTrace^();
		END NeedsTrace;

	END RecordScope;

	CellScope*=OBJECT (Scope)
		VAR
		ownerCell-: CellType;
		bodyProcedure-: Procedure;
		constructor-: Procedure;

		PROCEDURE & InitCellScope(outer: Scope);
		BEGIN
			InitScope(outer);
			ownerCell := NIL;
			bodyProcedure := NIL;
			constructor := NIL;
		END InitCellScope;

		PROCEDURE SetOwnerCell*(owner: CellType);
		BEGIN
			ownerCell := owner
		END SetOwnerCell;

		PROCEDURE SetBodyProcedure*(bodyProcedure: Procedure);
		BEGIN
			SELF.bodyProcedure := bodyProcedure;
		END SetBodyProcedure;

		PROCEDURE SetConstructor*(p: Procedure);
		BEGIN constructor := p
		END SetConstructor;
		
		PROCEDURE FindSymbol*(identifier: Identifier): Symbol;
		VAR p: Symbol; base: RecordType;
		BEGIN
			p := FindSymbol^(identifier);
			IF p = NIL THEN
				IF ownerCell.isCellNet THEN
					RETURN ownerCell.FindProperty(identifier);
				END;
			END;
			RETURN p;
		END FindSymbol;

	END CellScope;


	(**
		<<
		IMPORT firstImport .. lastImport;
		...
		firstOperator ... lastOperator
		....
		>>
	**)

	ModuleScope*= OBJECT(Scope)
		VAR
		firstImport-,lastImport-: Import; numberImports: LONGINT; (* imported modules *)
		firstOperator-,lastOperator-: Operator; numberOperators: LONGINT; (* defined operators *)
		firstBuiltin-,lastBuiltin-: Builtin; numberBuiltins: LONGINT; (* defined builtins, only for global and system module *)

		firstComment-,lastComment-: Comment; numberComments-: LONGINT; (* comments *)
		bodyProcedure-: Procedure;

		PROCEDURE & InitModuleScope;
		BEGIN
			InitScope(NIL);
			firstComment := NIL; lastComment := NIL; numberComments := 0;
			firstImport:= NIL; lastImport := NIL; numberImports := 0;
			firstOperator := NIL; lastOperator := NIL; numberOperators := 0;
		END InitModuleScope;

		PROCEDURE SetBodyProcedure*(body: Procedure);
		BEGIN SELF.bodyProcedure := body;
		END SetBodyProcedure;

		PROCEDURE SetGlobalScope*(outer: Scope);
		BEGIN
			SELF.outerScope := outer;
		END SetGlobalScope;

		PROCEDURE AddBuiltin*(p: Builtin);
		BEGIN
			ASSERT(p # NIL);
			IF lastBuiltin= NIL THEN firstBuiltin := p ELSE lastBuiltin.nextBuiltin := p END;
			INC(numberBuiltins);
			lastBuiltin := p;
		END AddBuiltin;

		PROCEDURE AddOperator*(p: Operator);
		BEGIN
			ASSERT(p # NIL);
			IF lastOperator= NIL THEN firstOperator := p ELSE lastOperator.nextOperator := p END;
			INC(numberOperators);
			lastOperator := p;
		END AddOperator;

		PROCEDURE FindOperator*(identifier: Identifier): Operator;
		VAR p: Operator;
		BEGIN
			p := firstOperator;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextOperator END;
			RETURN p;
		END FindOperator;

		PROCEDURE AddImport*(i: Import);
		BEGIN
			ASSERT(i # NIL);
			ASSERT(i.nextImport = NIL);
			IF lastImport= NIL THEN firstImport:= i ELSE lastImport.nextImport := i END;
			lastImport := i;
			INC(numberImports);
		END AddImport;

		PROCEDURE FindImport*(identifier: Identifier): Import;
		VAR p: Import;
		BEGIN
			p := firstImport;
			WHILE(p#NIL) & (p.name # identifier) DO p := p.nextImport END; (* finds imports and re-imports! *)
			RETURN p;
		END FindImport;

		PROCEDURE GetImport*( index: LONGINT ): Import;
		VAR import: Import;
		BEGIN
			import := firstImport;
			WHILE(import # NIL) & (index > 0) DO
				import := import.nextImport;
				DEC(index);
			END;
			RETURN import;
		END GetImport;

		PROCEDURE AddComment*(comment: Comment);
		BEGIN
			ASSERT(comment # NIL);
			IF lastComment= NIL THEN firstComment := comment ELSE lastComment.nextComment := comment END;
			INC(numberComments);
			lastComment := comment;
		END AddComment;

		PROCEDURE ImportByModuleName*(moduleName,context: Identifier): Import;
		VAR p: Import;
		BEGIN
			p := firstImport;
			WHILE(p#NIL) & ~((moduleName = p.moduleName) & (context = p.context)) DO p := p.nextImport END;
			RETURN p;
		END ImportByModuleName;

		PROCEDURE RemoveImporters*(moduleName,context: Identifier);
		VAR this: Import;

			PROCEDURE Check(p: Import): BOOLEAN;
			VAR result: BOOLEAN;
			BEGIN
				IF (moduleName = p.moduleName) & (context = p.context) THEN
					result := TRUE
				ELSE
					result := p.module.moduleScope.ImportByModuleName(moduleName,context) # NIL;
				END;
				RETURN result
			END Check;

		BEGIN
			WHILE(firstImport # NIL) & Check(firstImport) DO
				firstImport := firstImport.nextImport;
				DEC(numberImports);
			END;
			IF firstImport = NIL THEN lastImport := NIL
			ELSE
				this :=firstImport;
				WHILE(this.nextImport # NIL) DO
					IF Check(this.nextImport) THEN
						this.nextImport := this.nextImport.nextImport;
						DEC(numberImports);
					ELSE
						this := this.nextImport
					END;
				END;
				lastImport := this;
			END;
		END RemoveImporters;


	END ModuleScope;


	(* << MODULE name ['in' context] moduleScope name '.' >>  *)
	Module* = OBJECT (Symbol)
		VAR
			sourceName-: Basic.FileName;
			moduleScope-: ModuleScope;
			context-:Identifier; (* modules context *)
			case-: LONGINT; (* module notation in lower or upper case, important for printout and operators *)
			isCellNet-: BOOLEAN;
			firstScope-,lastScope-: Scope; numberScopes-: LONGINT; (* list of all scopes for checker / backend traversal etc. *)
			closingComment-: Comment;
			modifiers-: Modifier;

		PROCEDURE & InitModule( CONST sourceName: ARRAY OF CHAR; position: LONGINT; name: Identifier; scope: ModuleScope; case: LONGINT);
		BEGIN
			InitSymbol(position,name);
			COPY (sourceName, SELF.sourceName);
			moduleScope := scope;
			ASSERT(scope.ownerModule = NIL); (* cannot register twice ! *)
			scope.ownerModule := SELF;
			context := invalidIdentifier;
			SELF.case := case;
			firstScope := NIL; lastScope := NIL; numberScopes := 0;
			SetType(moduleType);
			closingComment := NIL;
			isCellNet := FALSE;
			modifiers := NIL;
		END InitModule;

		PROCEDURE SetCase*(case: LONGINT);
		BEGIN
			SELF.case := case
		END SetCase;


		PROCEDURE SetCellNet*(isCellNet: BOOLEAN);
		BEGIN SELF.isCellNet := isCellNet
		END SetCellNet;

		PROCEDURE SetContext*(context: Identifier);
		BEGIN	SELF.context := context;
		END SetContext;

		PROCEDURE SetName*(name: Identifier);
		BEGIN SELF.name := name
		END SetName;

		PROCEDURE SetClosingComment*(comment: Comment);
		BEGIN SELF.closingComment := comment
		END SetClosingComment;

		PROCEDURE SetModifiers*(modifiers: Modifier);
		BEGIN SELF.modifiers := modifiers
		END SetModifiers;


		PROCEDURE AddScope*(c: Scope);
		BEGIN
			IF lastScope= NIL THEN firstScope := c ELSE lastScope.nextScope := c END;
			lastScope := c;
			INC(numberScopes);
		END AddScope;

		PROCEDURE Accept*(v: Visitor);
		VAR position: LONGINT;
		BEGIN position := SELF.position; v.VisitModule(SELF)
		END Accept;

	END Module;

	(** <<expression, expression, ...>> **)
	SymbolList* = OBJECT
		VAR list: Basic.List;

		PROCEDURE & InitList*;
		BEGIN NEW( list,8 );
		END InitList;

		PROCEDURE Length*( ): LONGINT;
		BEGIN RETURN list.Length();
		END Length;

		PROCEDURE AddSymbol*( d: Symbol );
		BEGIN list.Add(d)
		END AddSymbol;

		PROCEDURE GetSymbol*( index: LONGINT ): Symbol;
		VAR p: ANY;
		BEGIN
			p := list.Get(index); RETURN p(Symbol);
		END GetSymbol;

		PROCEDURE SetSymbol*(index: LONGINT; expression: Symbol);
		BEGIN list.Set(index,expression)
		END SetSymbol;

		PROCEDURE RemoveSymbol*(i: LONGINT);
		BEGIN list.RemoveByIndex(i);
		END RemoveSymbol;

		(*
		PROCEDURE Clone*(VAR list: SymbolList);
		VAR i: LONGINT;
		BEGIN
			IF list = NIL THEN NEW(list) END;
			FOR i := 0 TO Length()-1 DO
				list.AddSymbol(CloneSymbol(GetSymbol(i)));
			END;
		END Clone;
		*)

	END SymbolList;

VAR
	(* invalid items used, for example, by parser and checker *)
	invalidIdentifier-: Identifier;
	invalidQualifiedIdentifier-: QualifiedIdentifier;
	invalidType-: Type;
	invalidExpression-: Expression; (* mapped to invalidDesignator for better error handling in checker *)
	invalidDesignator-: Designator;
	invalidValue-: Value;
	invalidSymbol-: Symbol;

	anonymousIdentifier-: Identifier;
	importType-: Type;
	typeDeclarationType-: Type;
	moduleType-: Type;

	indexListSeparator-: Expression;

	PROCEDURE InitFingerPrint*(VAR fingerprint: FingerPrint);
	BEGIN
		fingerprint.shallowAvailable := FALSE;
		fingerprint.deepAvailable := FALSE;
		fingerprint.shallow := 0;
		fingerprint.private := 0;
		fingerprint.public := 0;
	END InitFingerPrint;

	PROCEDURE NewModule*( CONST sourceName: ARRAY OF CHAR; position: LONGINT;  name: Identifier;scope: ModuleScope; case: LONGINT ): Module;
	VAR module: Module;
	BEGIN
		NEW( module, sourceName, position, name, scope, case);  RETURN module;
	END NewModule;

	PROCEDURE NewComment*(position: LONGINT; scope: Scope; CONST source: ARRAY OF CHAR; length: LONGINT): Comment;
	VAR comment: Comment;
	BEGIN
		NEW(comment,position,scope,source,length); RETURN comment;
	END NewComment;

	PROCEDURE NewImport*( position: LONGINT;  alias, name: Identifier; direct: BOOLEAN): Import;
	VAR import: Import;
	BEGIN
		NEW( import, position, alias, name, direct );  RETURN import
	END NewImport;

	PROCEDURE NewConstant*( position: LONGINT;  name: Identifier ): Constant;
	VAR constant: Constant;
	BEGIN
		NEW( constant, position, name );  RETURN constant
	END NewConstant;

	PROCEDURE NewProcedure*( position: LONGINT;  name: Identifier; scope: ProcedureScope ): Procedure;
	VAR procedure: Procedure;
	BEGIN
		NEW( procedure, position, name, scope);  RETURN procedure
	END NewProcedure;

	PROCEDURE NewBuiltin*(position: LONGINT; name: Identifier; id: LONGINT): Builtin;
	VAR builtin: Builtin;
	BEGIN
		NEW(builtin,position,name,id); RETURN builtin
	END NewBuiltin;

	PROCEDURE NewCustomBuiltin*(position: LONGINT; name: Identifier; id: LONGINT; subType: SHORTINT): CustomBuiltin;
	VAR builtin:CustomBuiltin;
	BEGIN
		NEW(builtin,position,name,id,subType); RETURN builtin
	END NewCustomBuiltin;

	PROCEDURE NewOperator*( position: LONGINT;  name: Identifier; scope: ProcedureScope): Operator;
	VAR operator: Operator;
	BEGIN
		NEW( operator, position, name, scope);  RETURN operator
	END NewOperator;

	PROCEDURE NewType*(): Type;  (* for error handling: invalid Type, is realtime type *)
	VAR type: Type;
	BEGIN
		NEW( type, -1);
		type.SetRealtime(TRUE);
		RETURN type
	END NewType;

	PROCEDURE NewByteType*(sizeInBits: LONGINT): ByteType;
	VAR basicType: ByteType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewByteType;

	PROCEDURE NewAnyType*(sizeInBits: LONGINT): AnyType;
	VAR basicType: AnyType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewAnyType;

	PROCEDURE NewObjectType*(sizeInBits: LONGINT): ObjectType;
	VAR basicType: ObjectType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewObjectType;

	PROCEDURE NewNilType*(sizeInBits: LONGINT): NilType;
	VAR basicType: NilType;
	BEGIN
		NEW(basicType,  sizeInBits); RETURN basicType;
	END NewNilType;

	PROCEDURE NewAddressType*(sizeInBits: LONGINT): AddressType;
	VAR basicType: AddressType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewAddressType;

	PROCEDURE NewSizeType*(sizeInBits: LONGINT): SizeType;
	VAR basicType: SizeType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewSizeType;

	PROCEDURE NewBooleanType*(sizeInBits: LONGINT): BooleanType;
	VAR basicType: BooleanType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewBooleanType;

	PROCEDURE NewSetType*(sizeInBits: LONGINT): SetType;
	VAR basicType: SetType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewSetType;

	PROCEDURE NewCharacterType*(sizeInBits: LONGINT): CharacterType;
	VAR basicType: CharacterType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewCharacterType;

	PROCEDURE NewRangeType*(sizeInBits: LONGINT): RangeType;
	VAR basicType: RangeType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewRangeType;

	PROCEDURE NewComplexType*(base: Type): ComplexType;
	VAR basicType: ComplexType;
	BEGIN
		NEW(basicType, base); RETURN basicType;
	END NewComplexType;

	PROCEDURE NewIntegerType*(size: LONGINT; signed: BOOLEAN): IntegerType;
	VAR basicType: IntegerType;
	BEGIN
		NEW(basicType, size, signed); RETURN basicType;
	END NewIntegerType;

	PROCEDURE NewFloatType*(sizeInBits: LONGINT): FloatType;
	VAR basicType: FloatType;
	BEGIN
		NEW(basicType, sizeInBits); RETURN basicType;
	END NewFloatType;

	PROCEDURE NewTypeDeclaration*(position: LONGINT; name: Identifier): TypeDeclaration;
	VAR typeDeclaration: TypeDeclaration;
	BEGIN
		ASSERT(name # invalidIdentifier);
		NEW(typeDeclaration,position,name); RETURN typeDeclaration
	END NewTypeDeclaration;

	PROCEDURE NewStringType*( position: LONGINT; baseType: Type; length: LONGINT): StringType;
	VAR stringType: StringType;
	BEGIN
		NEW( stringType, position, baseType, length);  RETURN stringType;
	END NewStringType;

	PROCEDURE NewEnumerationType*( position: LONGINT; scope: Scope; enumerationScope: EnumerationScope): EnumerationType;
	VAR enumerationType: EnumerationType;
	BEGIN
		NEW( enumerationType, position, scope, enumerationScope);  RETURN enumerationType;
	END NewEnumerationType;

	PROCEDURE NewArrayType*( position: LONGINT; scope: Scope; form: LONGINT): ArrayType;
	VAR arrayType: ArrayType;
	BEGIN
		NEW( arrayType, position,scope, form);  RETURN arrayType;
	END NewArrayType;

	PROCEDURE NewMathArrayType*( position: LONGINT; scope: Scope; form: LONGINT): MathArrayType;
	VAR mathArrayType: MathArrayType;
	BEGIN
		NEW( mathArrayType,  position,scope,form);  RETURN mathArrayType;
	END NewMathArrayType;

	PROCEDURE NewPointerType*( position: LONGINT; scope: Scope): PointerType;
	VAR pointerType: PointerType;
	BEGIN
		NEW( pointerType, position,scope);  RETURN pointerType;
	END NewPointerType;

	PROCEDURE NewPortType*( position: LONGINT; direction: LONGINT; sizeExpression: Expression; scope: Scope): PortType;
	VAR portType: PortType;
	BEGIN
		NEW( portType, position, direction, sizeExpression, scope);  RETURN portType;
	END NewPortType;

	PROCEDURE NewRecordType*( position: LONGINT; scope: Scope; recordScope: RecordScope): RecordType;
	VAR recordType: RecordType;
	BEGIN
		NEW( recordType, position, scope, recordScope);  RETURN recordType
	END NewRecordType;

	PROCEDURE NewCellType*(position: LONGINT; scope:Scope; cellScope: CellScope): CellType;
	VAR actorType: CellType;
	BEGIN
		NEW(actorType, position, scope, cellScope); RETURN actorType;
	END NewCellType;

	PROCEDURE NewProcedureType*( position: LONGINT; scope: Scope): ProcedureType;
	VAR procedureType: ProcedureType;
	BEGIN
		NEW( procedureType, position,scope);  RETURN procedureType;
	END NewProcedureType;

	PROCEDURE NewQualifiedType*( position: LONGINT;   scope: Scope; qualifiedIdentifier: QualifiedIdentifier): QualifiedType;
	VAR qualifiedType: QualifiedType;
	BEGIN
		NEW( qualifiedType, position,scope,qualifiedIdentifier );  RETURN qualifiedType
	END NewQualifiedType;

	PROCEDURE NewSymbol*(name: Identifier): Symbol; (* for error handling: invalid Symbol *)
	VAR symbol: Symbol;
	BEGIN
		NEW(symbol,-1,name); RETURN symbol
	END NewSymbol;

	PROCEDURE NewVariable*( position: LONGINT;  name: Identifier): Variable;
	VAR variable: Variable;
	BEGIN
		NEW( variable, position, name );  RETURN variable
	END NewVariable;

	PROCEDURE NewQualifiedIdentifier*( position: LONGINT;  prefix, suffix: Identifier ): QualifiedIdentifier;
	VAR qualifiedIdentifier: QualifiedIdentifier;
	BEGIN
		NEW( qualifiedIdentifier, position, prefix, suffix );  RETURN qualifiedIdentifier
	END NewQualifiedIdentifier;

	PROCEDURE NewIdentifier*(CONST name: ARRAY OF CHAR): Identifier;
	BEGIN
		RETURN Basic.MakeString(name);
	END NewIdentifier;

	PROCEDURE NewParameter*( position: LONGINT; ownerType:Type ;  name: Identifier; passAs: LONGINT): Parameter;
	VAR parameter: Parameter;
	BEGIN
		NEW( parameter, position, ownerType, name, passAs);  RETURN parameter;
	END NewParameter;

	PROCEDURE NewProperty*( position: LONGINT; name: Identifier): Property;
	VAR property: Property;
	BEGIN
		NEW( property, position, name);  RETURN property;
	END NewProperty;


	PROCEDURE NewExpressionList*(): ExpressionList;
	VAR expressionList: ExpressionList;
	BEGIN
		NEW(expressionList);  RETURN expressionList
	END NewExpressionList;

	PROCEDURE CloneExpressionList*(l: ExpressionList): ExpressionList;
	VAR copy: ExpressionList;
	BEGIN
		IF l = NIL THEN RETURN NIL ELSE l.Clone(copy); RETURN copy END;
	END CloneExpressionList;

	PROCEDURE NewDesignator*(): Designator; (* for error handling: invalid Designator *)
	VAR designator: Designator;
	BEGIN
		NEW(designator,-1); RETURN designator;
	END NewDesignator;

	PROCEDURE NewIdentifierDesignator*( position: LONGINT; identifier: Identifier): IdentifierDesignator;
	VAR identifierDesignator: IdentifierDesignator;
	BEGIN
		NEW( identifierDesignator, position, identifier );  RETURN identifierDesignator
	END NewIdentifierDesignator;

	PROCEDURE NewSelectorDesignator*( position: LONGINT;  left: Designator; name: Identifier ): SelectorDesignator;
	VAR selectorDesignator: SelectorDesignator;
	BEGIN
		NEW( selectorDesignator, position, left, name );  RETURN selectorDesignator
	END NewSelectorDesignator;

	PROCEDURE NewParameterDesignator*( position: LONGINT; left: Designator; expressionList: ExpressionList ): ParameterDesignator;
	VAR parameterDesignator: ParameterDesignator;
	BEGIN
		NEW( parameterDesignator,position, left, expressionList );  RETURN parameterDesignator
	END NewParameterDesignator;

	PROCEDURE NewArrowDesignator*( position: LONGINT; left: Designator ): ArrowDesignator;
	VAR dereferenceDesignator: ArrowDesignator;
	BEGIN
		NEW( dereferenceDesignator, position, left );  RETURN dereferenceDesignator;
	END NewArrowDesignator;

	PROCEDURE NewBracketDesignator*( position: LONGINT; left: Designator; expressionList: ExpressionList ): BracketDesignator;
	VAR bracketDesignator: BracketDesignator;
	BEGIN
		NEW( bracketDesignator, position, left, expressionList );  RETURN bracketDesignator
	END NewBracketDesignator;

	PROCEDURE NewSymbolDesignator*( position: LONGINT; left: Designator; symbol: Symbol ): SymbolDesignator;
	VAR symbolDesignator: SymbolDesignator;
	BEGIN
		NEW( symbolDesignator, position, left, symbol); RETURN symbolDesignator
	END NewSymbolDesignator;

	PROCEDURE NewIndexDesignator*( position: LONGINT; left: Designator): IndexDesignator;
	VAR indexDesignator: IndexDesignator;
	BEGIN
		NEW( indexDesignator, position, left);  RETURN indexDesignator
	END NewIndexDesignator;

	PROCEDURE NewProcedureCallDesignator*(position: LONGINT; left: Designator; parameters: ExpressionList): ProcedureCallDesignator;
	VAR procedureCallDesignator: ProcedureCallDesignator;
	BEGIN
		NEW(procedureCallDesignator, position, left, parameters); RETURN procedureCallDesignator
	END NewProcedureCallDesignator;

	PROCEDURE NewBuiltinCallDesignator*(position: LONGINT; id: LONGINT; left: Designator; parameters: ExpressionList): BuiltinCallDesignator;
	VAR builtinCallDesignator: BuiltinCallDesignator;
	BEGIN
		NEW(builtinCallDesignator, position, id, left,parameters); RETURN builtinCallDesignator
	END NewBuiltinCallDesignator;

	PROCEDURE NewTypeGuardDesignator*(position: LONGINT; left: Designator; type: Type): TypeGuardDesignator;
	VAR guardDesignator: TypeGuardDesignator;
	BEGIN
		NEW(guardDesignator,position,left,type); RETURN guardDesignator;
	END NewTypeGuardDesignator;

	PROCEDURE NewDereferenceDesignator*( position: LONGINT; left: Designator): DereferenceDesignator;
	VAR dereferenceDesignator: DereferenceDesignator;
	BEGIN
		NEW( dereferenceDesignator, position, left);  RETURN dereferenceDesignator
	END NewDereferenceDesignator;

	PROCEDURE NewSupercallDesignator*( position: LONGINT; left: Designator): SupercallDesignator;
	VAR supercallDesignator: SupercallDesignator;
	BEGIN
		NEW( supercallDesignator, position, left);  RETURN supercallDesignator
	END NewSupercallDesignator;

	PROCEDURE NewSelfDesignator*( position: LONGINT): SelfDesignator;
	VAR selfDesignator: SelfDesignator;
	BEGIN
		NEW( selfDesignator, position);  RETURN selfDesignator
	END NewSelfDesignator;

	PROCEDURE NewResultDesignator*( position: LONGINT): ResultDesignator;
	VAR resultDesignator: ResultDesignator;
	BEGIN
		NEW( resultDesignator, position);  RETURN resultDesignator
	END NewResultDesignator;

	PROCEDURE NewExpression*(): Expression; (* for error handling: invalid Expression *)
	VAR expression: Expression;
	BEGIN
		NEW(expression,-1); RETURN expression;
	END NewExpression;

	PROCEDURE CloneExpression*(e: Expression): Expression;
	VAR copy: Expression;
	BEGIN
		IF e = NIL THEN
			RETURN NIL
		ELSE
			copy := e.Clone();
			copy.type := e.type;
			copy.assignable := e.assignable;
			copy.position := e.position;
			copy.state := e.state;
			IF e.resolved = e THEN copy.resolved := copy(Value);
			ELSIF e.resolved # NIL THEN copy.resolved := CloneExpression(e.resolved)(Value);
			END;
			RETURN copy
		END;
	END CloneExpression;

	PROCEDURE CloneDesignator*(e: Expression): Designator;
	BEGIN
		IF e = NIL THEN RETURN NIL ELSE RETURN CloneExpression(e)(Designator) END;
	END CloneDesignator;

	PROCEDURE NewElement*( position: LONGINT;  from,to: Expression ): Expression;
	BEGIN
			IF from = to THEN RETURN from
			ELSE RETURN NewRangeExpression(position,from,to,NIL)
			END;
	END NewElement;

	PROCEDURE NewSet*( position: LONGINT ): Set;
	VAR set: Set;
	BEGIN NEW( set, position );  RETURN set
	END NewSet;

	PROCEDURE NewMathArrayExpression*( position: LONGINT ): MathArrayExpression;
	VAR mathArrayExpression: MathArrayExpression;
	BEGIN NEW( mathArrayExpression, position );  RETURN mathArrayExpression
	END NewMathArrayExpression;

	PROCEDURE NewBinaryExpression*( position: LONGINT;  left, right: Expression;  operator: LONGINT ): BinaryExpression;
	VAR binaryExpression: BinaryExpression;
	BEGIN
		NEW( binaryExpression, position, left, right, operator );  RETURN binaryExpression;
	END NewBinaryExpression;

	PROCEDURE NewRangeExpression*(position: LONGINT; first, last, step: Expression): RangeExpression;
	VAR rangeExpression: RangeExpression;
	BEGIN
		NEW(rangeExpression, position, first, last, step); RETURN rangeExpression
	END NewRangeExpression;

	PROCEDURE NewTensorRangeExpression*(position: LONGINT): TensorRangeExpression;
	VAR tensorRangeExpression: TensorRangeExpression;
	BEGIN
		NEW(tensorRangeExpression,position); RETURN tensorRangeExpression
	END NewTensorRangeExpression;

	PROCEDURE NewUnaryExpression*( position: LONGINT;  operand: Expression;  operator: LONGINT ): UnaryExpression;
	VAR unaryExpression: UnaryExpression;
	BEGIN
		NEW( unaryExpression, position, operand, operator );  RETURN unaryExpression;
	END NewUnaryExpression;

	PROCEDURE NewConversion*( position: LONGINT;  expression: Expression; type: Type; typeExpression: Expression): Conversion;
	VAR conversion: Conversion;
	BEGIN
		ASSERT(type # NIL);
		NEW( conversion, position, expression,type, typeExpression );  RETURN conversion;
	END NewConversion;

	PROCEDURE NewValue*(): Value;(* for error handling: invalid Value *)
	VAR value: Value;
	BEGIN
		NEW(value,-1); RETURN value;
	END NewValue;

	PROCEDURE NewIntegerValue*( position: LONGINT;  value: HUGEINT): IntegerValue;
	VAR integerValue: IntegerValue;
	BEGIN
		NEW( integerValue, position, value);  RETURN integerValue;
	END NewIntegerValue;

	PROCEDURE NewCharacterValue*( position: LONGINT;  value: CHAR): CharacterValue;
	VAR characterValue: CharacterValue;
	BEGIN
		NEW( characterValue, position, value);  RETURN characterValue;
	END NewCharacterValue;

	PROCEDURE NewSetValue*(position: LONGINT; value: SET): SetValue;
	VAR setValue: SetValue;
	BEGIN
		NEW(setValue, position, value); RETURN setValue
	END NewSetValue;

	PROCEDURE NewMathArrayValue*( position: LONGINT ): MathArrayValue;
	VAR mathArrayValue: MathArrayValue;
	BEGIN NEW( mathArrayValue, position );  RETURN mathArrayValue
	END NewMathArrayValue;

	PROCEDURE NewRealValue*( position: LONGINT;  value: LONGREAL): RealValue;
	VAR realValue: RealValue;
	BEGIN
		NEW( realValue, position, value);  RETURN realValue
	END NewRealValue;

	PROCEDURE NewComplexValue*( position: LONGINT;  realValue, imagValue: LONGREAL): ComplexValue;
	VAR complexValue: ComplexValue;
	BEGIN
		NEW( complexValue, position, realValue, imagValue);  RETURN complexValue
	END NewComplexValue;

	PROCEDURE NewStringValue*( position: LONGINT;  value: String): StringValue;
	VAR stringValue: StringValue;
	BEGIN
		NEW( stringValue, position, value );  RETURN stringValue
	END NewStringValue;

	PROCEDURE NewBooleanValue*( position: LONGINT;  value: BOOLEAN): BooleanValue;
	VAR booleanValue: BooleanValue;
	BEGIN
		NEW( booleanValue, position, value );  RETURN booleanValue;
	END NewBooleanValue;

	PROCEDURE NewNilValue*( position: LONGINT ): NilValue;
	VAR nilValue: NilValue;
	BEGIN
		NEW( nilValue, position );  RETURN nilValue
	END NewNilValue;

	PROCEDURE NewEnumerationValue*( position: LONGINT; value: LONGINT ): EnumerationValue;
	VAR enumeratorValue: EnumerationValue;
	BEGIN
		NEW( enumeratorValue, position, value );  RETURN enumeratorValue
	END NewEnumerationValue;

	PROCEDURE NewStatement*(outer: Statement): Statement; (* for error handling: invalid Statement *)
	VAR statement: Statement;
	BEGIN NEW(statement,-1,outer); RETURN statement;
	END NewStatement;

	PROCEDURE CloneStatement*(statement: Statement): Statement;
	BEGIN IF statement = NIL THEN RETURN NIL ELSE RETURN statement.Clone() END
	END CloneStatement;

	PROCEDURE NewStatementSequence*(): StatementSequence;
	VAR statementSequence: StatementSequence;
	BEGIN
		NEW( statementSequence);  RETURN statementSequence
	END NewStatementSequence;

	PROCEDURE CloneStatementSequence*(statementSequence: StatementSequence): StatementSequence;
	VAR copy: StatementSequence;
	BEGIN IF statementSequence = NIL THEN RETURN NIL ELSE statementSequence.Clone(copy); RETURN copy END
	END CloneStatementSequence;

	PROCEDURE NewModifier*(position: LONGINT; identifier: Identifier; expression: Expression): Modifier;
	VAR blockModifier: Modifier;
	BEGIN
		NEW(blockModifier,position,identifier,expression); RETURN blockModifier
	END NewModifier;

	PROCEDURE NewStatementBlock*( position: LONGINT ; outer: Statement): StatementBlock;
	VAR statementBlock: StatementBlock;
	BEGIN
		NEW( statementBlock, position, outer );  RETURN statementBlock
	END NewStatementBlock;

	PROCEDURE NewStatementDesignator*(position: LONGINT; s: Statement): StatementDesignator;
	VAR statementDesignator: StatementDesignator;
	BEGIN
		NEW( statementDesignator, position, s); RETURN statementDesignator
	END NewStatementDesignator;


	PROCEDURE NewBody*( position: LONGINT ; scope: ProcedureScope): Body;
	VAR body: Body;
	BEGIN
		NEW( body, position,scope );  RETURN body
	END NewBody;

	PROCEDURE NewIfPart*(): IfPart;
	VAR ifPart: IfPart;
	BEGIN
		NEW( ifPart);  RETURN ifPart
	END NewIfPart;

	PROCEDURE NewIfStatement*( position: LONGINT ; outer: Statement): IfStatement;
	VAR ifStatement: IfStatement;
	BEGIN
		NEW( ifStatement, position,outer );  RETURN ifStatement
	END NewIfStatement;

	PROCEDURE NewAssignment*( position: LONGINT;  left: Designator; right: Expression; outer: Statement): Assignment;
	VAR assignment: Assignment;
	BEGIN
		NEW( assignment, position, left, right,outer );  RETURN assignment
	END NewAssignment;

	PROCEDURE NewCommunicationStatement*( position: LONGINT;  op: LONGINT; left: Designator; right: Expression; outer: Statement): CommunicationStatement;
	VAR communication: CommunicationStatement;
	BEGIN
		NEW( communication, position, op, left, right,outer );  RETURN communication
	END NewCommunicationStatement;

	PROCEDURE NewProcedureCallStatement*(position: LONGINT; call: Designator; outer: Statement): ProcedureCallStatement;
	VAR caller: ProcedureCallStatement;
	BEGIN
		NEW(caller,position,call,outer); RETURN caller
	END NewProcedureCallStatement;

	PROCEDURE NewCaseStatement*( position: LONGINT ; outer: Statement): CaseStatement;
	VAR caseStatement: CaseStatement;
	BEGIN
		NEW( caseStatement, position,outer );  RETURN caseStatement
	END NewCaseStatement;

	PROCEDURE NewCasePart*(): CasePart;
	VAR casePart: CasePart;
	BEGIN
		NEW( casePart);  RETURN casePart
	END NewCasePart;

	PROCEDURE NewWithPart*(): WithPart;
	VAR withPart: WithPart;
	BEGIN
		NEW( withPart);  RETURN withPart
	END NewWithPart;

	PROCEDURE NewWithStatement*( position: LONGINT; outer: Statement): WithStatement;
	VAR withStatement: WithStatement;
	BEGIN
		NEW( withStatement, position, outer );  RETURN withStatement
	END NewWithStatement;

	PROCEDURE NewWhileStatement*( position: LONGINT ; outer: Statement): WhileStatement;
	VAR whileStatement: WhileStatement;
	BEGIN
		NEW( whileStatement, position,outer );  RETURN whileStatement
	END NewWhileStatement;

	PROCEDURE NewRepeatStatement*( position: LONGINT ; outer: Statement): RepeatStatement;
	VAR repeatStatement: RepeatStatement;
	BEGIN
		NEW( repeatStatement, position ,outer);  RETURN repeatStatement
	END NewRepeatStatement;

	PROCEDURE NewForStatement*( position: LONGINT; outer: Statement ): ForStatement;
	VAR forStatement: ForStatement;
	BEGIN
		NEW( forStatement, position,outer );  RETURN forStatement
	END NewForStatement;

	PROCEDURE NewLoopStatement*( position: LONGINT ; outer: Statement): LoopStatement;
	VAR loopStatement: LoopStatement;
	BEGIN
		NEW( loopStatement, position ,outer);  RETURN loopStatement
	END NewLoopStatement;

	PROCEDURE NewExitableBlock*( position: LONGINT ; outer: Statement): ExitableBlock;
	VAR loopStatement: ExitableBlock;
	BEGIN
		NEW( loopStatement, position ,outer);  RETURN loopStatement
	END NewExitableBlock;

	PROCEDURE NewExitStatement*( position: LONGINT ; outer: Statement): ExitStatement;
	VAR exitStatement: ExitStatement;
	BEGIN
		NEW( exitStatement, position, outer);  RETURN exitStatement
	END NewExitStatement;

	PROCEDURE NewReturnStatement*( position: LONGINT; outer: Statement ): ReturnStatement;
	VAR returnStatement: ReturnStatement;
	BEGIN
		NEW( returnStatement, position,outer );  RETURN returnStatement
	END NewReturnStatement;

	PROCEDURE NewAwaitStatement*( position: LONGINT; outer: Statement ): AwaitStatement;
	VAR awaitStatement: AwaitStatement;
	BEGIN
		NEW( awaitStatement, position, outer );  RETURN awaitStatement
	END NewAwaitStatement;

	PROCEDURE NewCode*(position: LONGINT; outer: Statement): Code;
	VAR code: Code;
	BEGIN
		NEW(code,position,outer); RETURN code
	END NewCode;

	PROCEDURE NewProcedureScope*(outer: Scope): ProcedureScope;
	VAR scope: ProcedureScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewProcedureScope;

	PROCEDURE NewModuleScope*(): ModuleScope;
	VAR scope: ModuleScope;
	BEGIN	NEW(scope); RETURN scope
	END NewModuleScope;

	PROCEDURE NewRecordScope*(outer: Scope): RecordScope;
	VAR scope: RecordScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewRecordScope;

	PROCEDURE NewCellScope*(outer: Scope): CellScope;
	VAR scope: CellScope;
	BEGIN	NEW(scope,outer); RETURN scope
	END NewCellScope;

	PROCEDURE NewEnumerationScope*(outer: Scope): EnumerationScope;
	VAR scope: EnumerationScope;
	BEGIN NEW(scope,outer); RETURN scope
	END NewEnumerationScope;

	PROCEDURE Init;
	BEGIN;
		invalidIdentifier := Basic.invalidString;
		invalidQualifiedIdentifier := NewQualifiedIdentifier(-1,invalidIdentifier,Basic.emptyString);
		invalidType := NewType();
		invalidDesignator := NewDesignator();
		invalidDesignator.SetType(invalidType);
		invalidExpression := invalidDesignator;
		invalidValue := NewValue();
		invalidSymbol := NewSymbol(NewIdentifier(""));
		invalidSymbol.SetType(invalidType);

		importType := NewType();
		importType.SetState(Resolved);
		typeDeclarationType := NewType();
		typeDeclarationType.SetState(Resolved);
		moduleType := NewType();
		moduleType.SetState(Resolved);
		anonymousIdentifier := NewIdentifier("");

		indexListSeparator := NewDesignator();
		indexListSeparator.SetType(invalidType);

	END Init;


BEGIN
	Init;
END FoxSyntaxTree.

