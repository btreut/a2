MODULE FoxGlobal; (** AUTHOR "fof & fn"; PURPOSE "Oberon Compiler Globally Defined Symbols"; *)
(* (c) fof ETH Zürich, 2008 *)

IMPORT
	SyntaxTree := FoxSyntaxTree, Basic := FoxBasic, Scanner := FoxScanner, Strings, Dates, D:= Debugging;

CONST
	(* system flag names *)
	StringWinAPI* = "WINAPI";
	StringC* = "C";
	StringMovable*="MOVABLE";
	StringUntraced* = "UNTRACED";
	StringDelegate* = "DELEGATE";
	StringInterrupt*= "INTERRUPT";
	StringPcOffset* = "PCOFFSET";
	StringEntry* = "INITIAL";
	StringExit*= "FINAL";
	StringNoPAF*="NOPAF";
	StringFixed*="FIXED";
	StringAligned*="ALIGNED";
	StringAlignStack*="ALIGNSTACK";
	StringFinal*="FINAL";
	StringAbstract*="ABSTRACT";
	StringRegister*= "REGISTER";
	StringNoReturn*="NORETURN";
	StringUnsafe*="UNSAFE";
	StringPlain*="PLAIN";
	StringDisposable*="DISPOSABLE";
	StringUnchecked*="UNCHECKED";
	StringUncooperative*="UNCOOPERATIVE";

	(* block modifier flag names *)
	StringExclusive* = "EXCLUSIVE";
	StringActive* = "ACTIVE";
	StringPriority* = "PRIORITY";
	StringSafe* = "SAFE";
	StringRealtime* = "REALTIME";
	StringDynamic* = "DYNAMIC";
	
	StringInstructionWidth*="InstructionWidth";
	StringDataMemorySize*= "DataMemorySize";
	StringCodeMemorySize*= "CodeMemorySize";
	StringChannelWidth*= "ChannelWidth";
	StringChannelDepth*= "ChannelDepth";
	StringChannelModule*= "Channels";

	StringSystemModule* = "SYSTEM";
	StringsystemModule* = "system";
	
	StringBaseMem*= "BaseMem";
	StringBaseDiv*= "BaseDiv";

	StringVector*="Vector";
	StringFloatingPoint*="FloatingPoint";
	StringNoMul*="NoMul";
	StringNonBlockingIO*="HasNonBlockingIO";
	StringFrequencyDivider*="FrequencyDivider";
	StringEngine*="Engine";
	StringTRM*="TRM";
	StringTRMS*="TRMS";

	(* traps *)
	WithTrap* = 1;
	CaseTrap* = 2;
	ReturnTrap* = 3;
	TypeEqualTrap* = 5;
	TypeCheckTrap* = 6;
	IndexCheckTrap* = 7;
	AssertTrap* = 8;
	ArraySizeTrap* = 9;
	ArrayFormTrap*=10; (* fof: indicates that array cannot be (re-)allocated since shape, type or size does not match *)
	NoReturnTrap*=16;

	(** builtin procedures **)
	(* FoxProgTools.Enum -e -i
		(* global proper procedures *)
		Assert  Copy  Dec  Excl  Halt  Inc  Incl  New Dispose GetProcedure Connect Delegate
		Read Write Reshape Wait
		(* global functions *)
		Abs   Cap  Chr  Chr32 Entier  EntierH  Incr Len  Long  Max  Min Odd  Ord  Ord32 Short  Size
		Sum Dim Cas First Last Step Re Im Ash Lsh Rot
		(* system proper procedures *)
		systemGet  systemPut  systemMove  systemNew systemRef
		systemTypeCode systemHalt
		systemPut8 systemPut16 systemPut32 systemPut64 systemTrace
		systemSetStackPointer systemSetFramePointer systemSetActivity
		(* system functions *)
		systemAdr  systemSize systemBit  systemGet64  systemGet32  systemGet16  systemGet8
		systemVal systemMsk
		systemGetStackPointer systemGetFramePointer systemGetActivity

		(* for active cells *)
		Send Receive
		(* for backend specific extensions *)
		systemSpecial
		(* compatibility with Oberon07 -- other mappings: LSL -> LSH, FLOOR -> Entier, Pack und Unpk currently unsupported *)
		Asr Ror Flt

		Conversion
		DotTimesPlus AtMulDec AtMulInc DecMul IncMul
		endFox
		~
	*)

	(* global proper procedures *)
	Assert*= Scanner.EndOfText+1; Copy*= Assert+1; Dec*= Copy+1; Excl*= Dec+1; Halt*= Excl+1; Inc*= Halt+1; Incl*= Inc+1; New*= Incl+1; Dispose*= New+1; GetProcedure*= Dispose+1; Connect*= GetProcedure+1; Delegate*= Connect+1; Read*= Delegate+1; Write*= Read+1; Reshape*= Write+1; Wait*= Reshape+1; 
	(* global functions *)
	Abs*= Wait+1; Cap*= Abs+1; Chr*= Cap+1; Chr32*= Chr+1; Entier*= Chr32+1; EntierH*= Entier+1; Incr*= EntierH+1; Len*= Incr+1; Long*= Len+1; Max*= Long+1; Min*= Max+1; Odd*= Min+1; Ord*= Odd+1; Ord32*= Ord+1; Short*= Ord32+1; Size*= Short+1; Sum*= Size+1; Dim*= Sum+1; Cas*= Dim+1; First*= Cas+1; Last*= First+1; Step*= Last+1; Re*= Step+1; Im*= Re+1; Ash*= Im+1; Lsh*= Ash+1; Rot*= Lsh+1; 
	All* = Rot+1;
	(* system proper procedures *)
	systemGet*= All+1; systemPut*= systemGet+1; systemMove*= systemPut+1; systemNew*= systemMove+1; systemRef*= systemNew+1; systemTypeCode*= systemRef+1; systemHalt*= systemTypeCode+1; systemPut8*= systemHalt+1; systemPut16*= systemPut8+1; systemPut32*= systemPut16+1; systemPut64*= systemPut32+1; systemTrace*= systemPut64+1; systemSetStackPointer*= systemTrace+1; systemSetFramePointer*= systemSetStackPointer+1; systemSetActivity*= systemSetFramePointer+1; 
	(* system functions *)
	systemAdr*= systemSetActivity+1; systemSize*= systemAdr+1; systemBit*= systemSize+1; systemGet64*= systemBit+1; systemGet32*= systemGet64+1; systemGet16*= systemGet32+1; systemGet8*= systemGet16+1; systemVal*= systemGet8+1; systemMsk*= systemVal+1; systemGetStackPointer*= systemMsk+1; systemGetFramePointer*= systemGetStackPointer+1; systemGetActivity*= systemGetFramePointer+1; 
	(* for active cells *)
	Send*= systemGetActivity+1; Receive*= Send+1; 
	(* for backend specific extensions *)
	systemSpecial*= Receive+1; 
	(* compatibility with Oberon07 -- other mappings: LSL -> LSH, FLOOR -> Entier, Pack und Unpk currently unsupported *)
	Asr*= systemSpecial+1; Ror*= Asr+1; Flt*= Ror+1; Conversion*= Flt+1; DotTimesPlus*= Conversion+1; AtMulDec*= DotTimesPlus+1; AtMulInc*= AtMulDec+1; DecMul*= AtMulInc+1; IncMul*= DecMul+1; endFox*= IncMul+1; 

	VectorCapability* = 0;
	FloatingPointCapability*= 1;
	EngineCapability*= 2;
	TRMSCapability*= 3;
	NoMulCapability*=4;
	NonBlockingIOCapability*=5;
CONST    
    (* LYNX extensions *)

    (* different naming schema to satisfy FoxScanner when parsing imports *)
    LynxChar* = "@lynx_char";
    LynxSbyte* = "@lynx_sbyte";
    LynxShort* = "@lynx_short";
    LynxInt* = "@lynx_int";
    LynxLong* = "@lynx_long";
    LynxFloat* = "@lynx_float";
    LynxDouble* = "@lynx_double";
    LynxBool* = "@lynx_bool";
    LynxObject* = "@lynx_object";
    LynxString* = "@lynx_string";

    LynxNewobj* = "lynx@newobj";
    LynxNewarr* = "lynx@newarr";
    LynxAsop* = "lynx@asop";
    LynxUnop* = "lynx@unop";
    LynxBinop* = "lynx@binop";
    LynxSend* = "lynx@send";
    LynxReceive* = "lynx@receive";
    LynxRecvnb* = "lynx@recvnb";
    LynxConnect* = "lynx@connect";
    LynxDelegate* = "lynx@delegate";
    LynxNewsel* = "lynx@newsel";
    LynxAddsel* = "lynx@addsel";
    LynxSelect* = "lynx@select";
    LynxSelidx* = "lynx@selidx";

    LynxOpAdd* = 1;
    LynxOpSub* = 2;
    LynxOpMul* = 3;
    LynxOpDiv* = 4;
    LynxOpRem* = 5;
    LynxOpAnd* = 6;
    LynxOpOr* = 7;
    LynxOpXor* = 8;
    LynxOpShl* = 9;
    LynxOpShr* = 10;
    LynxOpNot* = 11;

    SymLynxNewobj* = endFox;
    SymLynxNewarr* = endFox + 1;
    SymLynxAsop* = endFox + 2;
    SymLynxUnop* = endFox + 3;
    SymLynxBinop* = endFox + 4;
    SymLynxRecvnb* = endFox + 5;

    SymLynxNewsel* = endFox + 6;
    SymLynxAddsel* = endFox + 7;
    SymLynxSelect* = endFox + 8;
    SymLynxSelidx* = endFox + 9;

    end = endFox + 10;

VAR
	(* names *)
	SelfParameterName-,ReturnParameterName-,SystemName-,systemName-,PointerReturnName-, ResultName-,
	A2Name-,OberonName-,ArrayBaseName-,RecordBodyName-,ModuleBodyName-,
	NameWinAPI-,NameC-,NameMovable-,NameUntraced-,NameDelegate-,NameInterrupt-, NamePcOffset-, NameNoPAF-,NameEntry-, NameExit-, NameFixed-,NameAligned-,NameStackAligned-,
	NameExclusive-,NameActive-,NamePriority-,NameSafe-,NameRealtime-, NameDynamic-, NameDataMemorySize-, NameCodeMemorySize-
	, NameChannelWidth-, NameChannelDepth-, NameChannelModule-, NameVector-, NameFloatingPoint-, NameNoMul-,NameNonBlockingIO-, NameTRM-, NameTRMS-, NameEngine-, NameFinal-, NameAbstract-,
	NameFrequencyDivider-, NameRegister-,NameNoReturn-,NamePlain-,NameUnsafe-,NameDisposable-,NameUnchecked-,NameUncooperative-: SyntaxTree.Identifier;

	identifiers: ARRAY 2 OF ARRAY end OF SyntaxTree.Identifier;

	(* some handy type variables for backend / checker implementers *)
	Boolean8-, Boolean32-: SyntaxTree.BooleanType;
	Integer8-, Integer16-, Integer32-, Integer64-: SyntaxTree.IntegerType;
	Unsigned8-, Unsigned16-, Unsigned32-, Unsigned64-: SyntaxTree.IntegerType;
	Character8-, Character16-, Character32-: SyntaxTree.CharacterType;
	Float32-, Float64-: SyntaxTree.FloatType;
	Complex64-, Complex128-: SyntaxTree.ComplexType;
	Byte8: SyntaxTree.ByteType;
	Byte32: SyntaxTree.ByteType;

TYPE
	Alignment* = RECORD
		min, max: LONGINT; (* alignments in bits *)
	END;

	PassInRegisterProc = PROCEDURE {DELEGATE} (type: SyntaxTree.Type): BOOLEAN;

	System*= OBJECT
	VAR
		(* system and global scopes and modules  (lowercase and uppercase each) *)
		systemScope-, globalScope-: ARRAY 2 OF SyntaxTree.ModuleScope;
		systemModule-,globalModule-: ARRAY 2 OF SyntaxTree.Module;
		activeCellsCapabilities-: SyntaxTree.Symbol; (* list of supported capabilities, filled by ActiveCells specification *)

		(* addressing granularity in code and data memory *)
		codeUnit-: LONGINT;
		dataUnit-: LONGINT;
		(* alignment (variables, record entries) *)
		(* alignment (parameters & stack frames) *)
		variableAlignment-, parameterAlignment-: Alignment;
		(* offset of first parameter *)
		offsetFirstParameter-: LONGINT;
		(* to determine if a builtin-procedure can be operator-overloaded *)
		operatorDefined-: ARRAY end OF BOOLEAN;

		(* type sizes defined by backend *)
		addressSize-: LONGINT;

		registerParameters-: LONGINT; (* how many parameters are passed via registers *)

		(* system type mapping, in a later version only the global (unisgned) types should be used
			the following two types are only there for compatibility with the system as is
			problematic are mainly the conversions between (signed) Oberon types and (unsigned) addressType.
			A good concept has to be derived.
		*)

		addressType-, sizeType-, shortintType-, integerType-, longintType-, hugeintType-, wordType-, longWordType-, characterType-, characterType8-, characterType16-, characterType32-, setType-, booleanType-, anyType-,byteType-,
		realType-, longrealType-, complexType-, longcomplexType-, objectType-, nilType-, rangeType-: SyntaxTree.Type;

		CanPassInRegister-: PassInRegisterProc;
		cellsAreObjects-: BOOLEAN;

		PROCEDURE &InitSystem*(codeUnit, dataUnit: LONGINT; addressSize, minVarAlign, maxVarAlign, minParAlign, maxParAlign, offsetFirstPar, registerParameters: LONGINT; cooperative: BOOLEAN);
		VAR i: LONGINT;
		BEGIN
			ASSERT(dataUnit > 0);
			ASSERT(minVarAlign > 0);
			ASSERT(maxVarAlign > 0);
			ASSERT(minParAlign > 0);
			ASSERT(maxParAlign > 0);
			SELF.dataUnit := dataUnit;
			SELF.codeUnit := codeUnit;
			SELF.addressSize := addressSize;
			SELF.variableAlignment.min := minVarAlign;
			SELF.variableAlignment.max := maxVarAlign;
			SELF.parameterAlignment.min := minParAlign;
			SELF.parameterAlignment.max := maxParAlign;
			SELF.offsetFirstParameter := offsetFirstPar;
			SELF.registerParameters := registerParameters;
			IF cooperative THEN INC(SELF.offsetFirstParameter,addressSize) END;
			activeCellsCapabilities := NIL;
			BuildScopes(SELF);
			FOR i := 0 TO LEN(operatorDefined)-1 DO
				operatorDefined[i] := FALSE;
			END;
			CanPassInRegister :=NIL;
			cellsAreObjects := FALSE;
		END InitSystem;

		PROCEDURE SetCellsAreObjects*(c: BOOLEAN);
		BEGIN
			cellsAreObjects := c;
		END SetCellsAreObjects;
		

		PROCEDURE SetRegisterPassCallback*(canPassInRegister: PassInRegisterProc);
		BEGIN
			CanPassInRegister := canPassInRegister;
		END SetRegisterPassCallback;


		PROCEDURE AddCapability*(name: SyntaxTree.Identifier);
		VAR symbol: SyntaxTree.Symbol;
		BEGIN
			symbol := SyntaxTree.NewSymbol(name);
			symbol.SetNext(activeCellsCapabilities);
			activeCellsCapabilities := symbol
		END AddCapability;

		PROCEDURE GenerateRecordOffsets*(x: SyntaxTree.RecordType): BOOLEAN; (* normally done in checker but the binary symbol file format makes this necessary *)
		VAR baseType: SyntaxTree.RecordType; offset,size: LONGINT; alignment, thisAlignment: LONGINT; variable: SyntaxTree.Variable;
		BEGIN
			baseType :=x.GetBaseRecord();
			IF (baseType  # NIL) & (baseType.sizeInBits < 0) THEN
				IF~ GenerateRecordOffsets(baseType) THEN RETURN FALSE END;
			END;
			IF baseType # NIL THEN
				offset := baseType.sizeInBits; 
				alignment := baseType.alignmentInBits;
			ELSE
				offset := 0; alignment := x.alignmentInBits;
				IF alignment <= 0 THEN alignment := dataUnit END;
			END;

			variable := x.recordScope.firstVariable;
			WHILE (variable # NIL) DO
				size := SizeOf(variable.type.resolved);
				IF size < 0 THEN RETURN FALSE END;

				IF variable.alignment > 0 THEN
					thisAlignment := variable.alignment*dataUnit;
				ELSE
					thisAlignment := AlignmentOf(SELF.variableAlignment, variable.type.resolved);
				END;
				Basic.Align(offset, thisAlignment);
				IF thisAlignment  > alignment THEN alignment := thisAlignment END;

				variable.SetOffset(offset);
				INC(offset,size);
				variable := variable.nextVariable;
			END;
			x.SetAlignmentInBits(alignment);
			Basic.Align(offset, alignment); (* strictly speaking not necessary, but with the old object file format otherwise problems with the GC show up *)
			x.SetSize(offset);
			RETURN TRUE
		END GenerateRecordOffsets;

		PROCEDURE GenerateCellOffsets(x: SyntaxTree.CellType): BOOLEAN;
		VAR baseType: SyntaxTree.RecordType; offset,size: LONGINT; alignment, thisAlignment: LONGINT; variable: SyntaxTree.Variable;
		BEGIN
			baseType :=x.GetBaseRecord();
			IF (baseType  # NIL) & (baseType.sizeInBits < 0) THEN
				IF~ GenerateRecordOffsets(baseType) THEN RETURN FALSE END;
			END;
			IF baseType # NIL THEN
				offset := baseType.sizeInBits; 
				alignment := baseType.alignmentInBits;
			ELSE
				offset := 0; alignment := x.alignmentInBits;
				IF alignment <= 0 THEN alignment := dataUnit END;
			END;

			variable := x.cellScope.firstVariable;
			WHILE (variable # NIL) DO
				size := SizeOf(variable.type.resolved);
				IF size < 0 THEN RETURN FALSE END;

				IF variable.alignment > 0 THEN
					thisAlignment := variable.alignment*dataUnit;
				ELSE
					thisAlignment := AlignmentOf(SELF.variableAlignment, variable.type.resolved);
				END;
				Basic.Align(offset, thisAlignment);
				IF thisAlignment  > alignment THEN alignment := thisAlignment END;

				variable.SetOffset(offset);
				INC(offset,size);
				variable := variable.nextVariable;
			END;
			x.SetAlignmentInBits(alignment);
			Basic.Align(offset, alignment); (* strictly speaking not necessary, but with the old object file format otherwise problems with the GC show up *)
			x.SetSize(offset);
			RETURN TRUE
			
		END GenerateCellOffsets;
		

		PROCEDURE GenerateVariableOffsets*(scope: SyntaxTree.Scope): BOOLEAN;
		VAR variable: SyntaxTree.Variable; offset,size: LONGINT; alignment: LONGINT; parameterOffset :LONGINT;
		BEGIN
			IF scope IS SyntaxTree.RecordScope THEN (* increasing indices *)
				RETURN GenerateRecordOffsets(scope(SyntaxTree.RecordScope).ownerRecord)
			ELSIF scope IS SyntaxTree.CellScope THEN
				RETURN GenerateCellOffsets(scope(SyntaxTree.CellScope).ownerCell);
			ELSE (* module scope or procedure scope: decreasing indices *)
				ASSERT((scope IS SyntaxTree.ModuleScope) OR (scope IS SyntaxTree.ProcedureScope) OR (scope IS SyntaxTree.CellScope)
				);
				offset := 0;
				IF scope IS SyntaxTree.ProcedureScope THEN
					parameterOffset := scope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).parameterOffset
				ELSE
					parameterOffset := 0
				END;

				variable := scope.firstVariable;
				WHILE (variable # NIL) DO
					IF variable.externalName = NIL THEN
						size := SizeOf(variable.type.resolved);
						IF size < 0 THEN RETURN FALSE END;
						DEC(offset,size);

						IF variable.alignment > 0 THEN
							Basic.Align(offset, -variable.alignment*dataUnit);
						ELSE
							alignment := AlignmentOf(SELF.variableAlignment,variable.type.resolved);
							Basic.Align(offset,-alignment);
						END;

						variable.SetOffset(offset);
					END;
					variable := variable.nextVariable;
				END;
			END;
			RETURN TRUE
		END GenerateVariableOffsets;

		PROCEDURE GenerateParameterOffsets*(procedure : SyntaxTree.Procedure; nestedProcedure: BOOLEAN): BOOLEAN;
		VAR offset,size: LONGINT;parameter: SyntaxTree.Parameter; procedureType: SyntaxTree.ProcedureType;
		BEGIN
			procedureType := procedure.type(SyntaxTree.ProcedureType);
			IF (procedure.isInline) THEN
				offset := 0
			ELSE
				offset := SELF.offsetFirstParameter;
			END;
			IF nestedProcedure THEN
				INC(offset,addressSize); (* parameter offset of static link *) (*! check alternative: add hidden parameter *)
			END;

			IF procedureType.callingConvention = SyntaxTree.OberonCallingConvention THEN
				parameter := procedureType.lastParameter;
				WHILE (parameter # NIL) DO
					Basic.Align(offset,addressSize);
					parameter.SetOffset(offset);
					size := SizeOfParameter(parameter);
					IF size < 0 THEN RETURN FALSE END;
					INC(offset,SizeOfParameter(parameter));
					parameter := parameter.prevParameter;
				END;
				parameter := procedureType.returnParameter;
				IF parameter # NIL THEN
					Basic.Align(offset,addressSize);
					parameter.SetOffset(offset);
					size := SizeOfParameter(parameter);
					IF size < 0 THEN RETURN FALSE END;
					INC(offset,SizeOfParameter(parameter));
				END;
			ELSE
				parameter := procedureType.firstParameter;
				WHILE (parameter # NIL) DO
					Basic.Align(offset,addressSize);
					parameter.SetOffset(offset);
					size := SizeOfParameter(parameter);
					IF size < 0 THEN RETURN FALSE END;
					INC(offset,size);
					parameter := parameter.nextParameter;
				END;
			END;
			IF (procedureType.isDelegate) THEN
				INC(offset,addressSize); (* parameter offset of delegate *)
			END;
			procedureType.SetParameterOffset(offset);
			RETURN TRUE
		END GenerateParameterOffsets;


		PROCEDURE SizeOf*(type: SyntaxTree.Type): LONGINT;
		VAR size: LONGINT; base: SyntaxTree.Type;
		BEGIN
			IF type = NIL THEN RETURN -1 END;
			type := type.resolved;
			IF type IS SyntaxTree.BasicType THEN
				size := type.sizeInBits
			ELSIF type IS SyntaxTree.PointerType THEN
				size := addressSize
			ELSIF type IS SyntaxTree.ProcedureType THEN
				IF type(SyntaxTree.ProcedureType).isDelegate THEN
					size := 2*addressSize
				ELSE
					size := addressSize
				END;
			ELSIF type IS SyntaxTree.RecordType THEN
				(* do not treat a record type like a pointer even if the Pointer field is set, this leads to problems in object files
					rather make sure that each reference type is a POINTER TO at least behind the secenes!
				*)
				IF ~(SyntaxTree.Resolved IN type.state) THEN
					size := -1
				ELSE
					size :=type.sizeInBits;
					IF size < 0 THEN
						IF GenerateRecordOffsets(type(SyntaxTree.RecordType)) THEN
							size :=type.sizeInBits;
						ELSE
							size := -1
						END;
					END;
				END;
			ELSIF type IS SyntaxTree.ArrayType THEN
				IF ~(SyntaxTree.Resolved IN type.state) THEN
					size := -1
				ELSIF type.sizeInBits >= 0 THEN
					size := type.sizeInBits
				ELSIF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
					size := AlignedSizeOf(type(SyntaxTree.ArrayType).arrayBase.resolved)*type(SyntaxTree.ArrayType).staticLength;
					type.SetSize(size);
				ELSE
					size := 0; base := type;
					WHILE(base IS SyntaxTree.ArrayType) DO
						base := base(SyntaxTree.ArrayType).arrayBase.resolved;
						INC(size); (* length field *)
					END;
					size := size*addressSize+addressSize;
					type.SetSize(size)
				END;
			ELSIF type IS SyntaxTree.MathArrayType THEN
				IF ~(SyntaxTree.Resolved IN type.state) THEN
					size := -1
				ELSIF type(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
					size := SizeOf(type(SyntaxTree.MathArrayType).arrayBase.resolved)*type(SyntaxTree.MathArrayType).staticLength
				ELSIF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					size := addressSize (* pointer to geometry descriptor *)
				ELSE
					size := 0;
					WHILE(type # NIL) & (type IS SyntaxTree.MathArrayType) DO
						type := type(SyntaxTree.MathArrayType).arrayBase;
						IF type # NIL THEN type := type.resolved END;
						INC(size);
					END;
					size := size*2*addressSize (* length and increments *) +5*addressSize (* data ptr, adr ptr, flags, dim and elementsize *);
				END;
			ELSIF type IS SyntaxTree.StringType THEN
				ASSERT(SyntaxTree.Resolved IN type.state);
				size := type(SyntaxTree.StringType).length * SizeOf(type(SyntaxTree.StringType).baseType);
			ELSIF type IS SyntaxTree.EnumerationType THEN
				size := addressSize
			ELSIF type = SyntaxTree.invalidType THEN size := 0
			ELSIF type IS SyntaxTree.QualifiedType THEN
				HALT(101); (* hint that unresolved type has been taken for type size computation *)
			ELSIF type IS SyntaxTree.PortType THEN
				size := addressSize
			ELSIF type IS SyntaxTree.CellType THEN
				size := addressSize;
			ELSIF type IS SyntaxTree.RangeType THEN
				size := 3 * SizeOf(longintType);
			ELSE
				HALT(100)
			END;
			RETURN size
		END SizeOf;

		PROCEDURE SizeOfParameter*(par: SyntaxTree.Parameter):LONGINT;
		BEGIN
			IF (par.type.resolved IS SyntaxTree.ArrayType) OR (par.type.resolved IS SyntaxTree.MathArrayType) THEN
				IF (par.type.resolved IS SyntaxTree.ArrayType) & (par.type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.Static) &
					(par.kind IN {SyntaxTree.ConstParameter,SyntaxTree.VarParameter})
					OR
					(par.type.resolved IS SyntaxTree.MathArrayType) & (par.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static) &
					(par.kind IN {SyntaxTree.ConstParameter,SyntaxTree.VarParameter})
					OR (par.type.resolved IS SyntaxTree.MathArrayType) & (par.kind = SyntaxTree.VarParameter)
				THEN
					RETURN addressSize
				ELSIF IsOberonProcedure(par.ownerType) THEN
					RETURN SizeOf(par.type);
				ELSE RETURN addressSize
				END
			ELSIF par.type.resolved IS SyntaxTree.RangeType THEN
				IF par.kind = SyntaxTree.VarParameter THEN
					RETURN addressSize
				ELSE
					RETURN SizeOf(rangeType) (* array range components are materialized on stack for both value and const parameters *)
				END
			ELSIF par.type.resolved IS SyntaxTree.RecordType THEN
				IF (par.kind IN {SyntaxTree.ConstParameter,SyntaxTree.VarParameter}) THEN
					IF IsOberonProcedure(par.ownerType) THEN
						RETURN 2*addressSize
					ELSE
						RETURN addressSize
					END
				ELSE
					RETURN SizeOf(par.type);
				END;
			ELSIF par.kind = SyntaxTree.VarParameter THEN
				RETURN addressSize
			ELSIF par.kind = SyntaxTree.ConstParameter THEN
				RETURN SizeOf(par.type)
			ELSE
				RETURN SizeOf(par.type);
			END;
		END SizeOfParameter;

		PROCEDURE AlignmentOf*(CONST alignment: Alignment;type: SyntaxTree.Type): LONGINT;
		VAR result: LONGINT;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				IF type.alignmentInBits <= 0 THEN
					IF GenerateRecordOffsets(type(SyntaxTree.RecordType)) THEN
						result := type.alignmentInBits
					END
				ELSE
					result := type.alignmentInBits
				END;
			ELSIF type IS SyntaxTree.ArrayType THEN
				IF type.alignmentInBits <= 0 THEN
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						result := AlignmentOf(alignment,type(SyntaxTree.ArrayType).arrayBase.resolved);
					ELSE
						result := alignment.max
					END;
					type.SetAlignmentInBits(result)
				ELSE
					result := type.alignmentInBits
				END;
			ELSIF type IS SyntaxTree.StringType THEN
				result := SizeOf(type(SyntaxTree.StringType).baseType);
			ELSE
				result := SizeOf(type);
				IF result > alignment.max THEN result := alignment.max END;
				IF result < alignment.min THEN result := alignment.min END;
			END;
			ASSERT(result # 0);
			RETURN result
		END AlignmentOf;

		PROCEDURE AlignedSizeOf*(type: SyntaxTree.Type): LONGINT;
		VAR size: LONGINT;
		BEGIN
			size := SizeOf(type);
			Basic.Align(size, AlignmentOf(variableAlignment, type));
			RETURN size
		END AlignedSizeOf;

(* LYNX+ *)
        PROCEDURE IsLynx*(): BOOLEAN;
        BEGIN
            RETURN TRUE;
        END IsLynx;
(* -LYNX *)

	END System;

	PROCEDURE BuildScopes(system: System);
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO end-1 DO
			system.operatorDefined[i] := FALSE
		END;
		system.globalScope[Scanner.Uppercase] := SyntaxTree.NewModuleScope();
		system.globalScope[Scanner.Lowercase] := SyntaxTree.NewModuleScope();
		system.globalModule[Scanner.Uppercase] := SyntaxTree.NewModule("",-1,SyntaxTree.NewIdentifier("@GLOBAL"),system.globalScope[Scanner.Uppercase],Scanner.Uppercase);
		system.globalModule[Scanner.Lowercase] := SyntaxTree.NewModule("",-1,SyntaxTree.NewIdentifier("@global"),system.globalScope[Scanner.Lowercase],Scanner.Lowercase);
		system.systemScope[Scanner.Uppercase] := SyntaxTree.NewModuleScope();
		system.systemScope[Scanner.Lowercase] := SyntaxTree.NewModuleScope();
		system.systemModule[Scanner.Uppercase] := SyntaxTree.NewModule("",-1,SystemName,system.systemScope[Scanner.Uppercase],Scanner.Uppercase);
		system.systemModule[Scanner.Lowercase] := SyntaxTree.NewModule("",-1,systemName,system.systemScope[Scanner.Lowercase],Scanner.Lowercase);
	END BuildScopes;

	PROCEDURE SetDefaultDeclarations*(system: System; minBits: LONGINT);
	VAR now: Dates.DateTime; date, time: ARRAY 20 OF CHAR;
	BEGIN
		(* types *)
		system.longintType := SyntaxTree.NewIntegerType(32, TRUE);
		system.hugeintType := SyntaxTree.NewIntegerType(64, TRUE);
		system.wordType := SyntaxTree.NewIntegerType(MIN(system.addressSize,32),TRUE);
		system.longWordType := SyntaxTree.NewIntegerType(system.addressSize,TRUE);
		system.realType := SyntaxTree.NewFloatType(32);
		system.longrealType := SyntaxTree.NewFloatType(64);
		(*
		system.longintType := Integer32;
		system.hugeintType := Integer64;
		system.realType := Float32;
		system.longrealType := Float64;
		*)

		IF minBits = 32 THEN
			system.shortintType := SyntaxTree.NewIntegerType(32, TRUE);
			system.integerType := SyntaxTree.NewIntegerType(32, TRUE);
			system.booleanType := SyntaxTree.NewBooleanType(32);
			system.byteType := SyntaxTree.NewByteType(32);
			system.characterType := SyntaxTree.NewCharacterType(32);
			system.characterType8 := SyntaxTree.NewCharacterType(32);
			system.characterType16 := SyntaxTree.NewCharacterType(32);
			system.characterType32 := SyntaxTree.NewCharacterType(32);
			(*
			system.shortintType := Integer32;
			system.integerType := Integer32;
			system.booleanType := Boolean32;
			system.byteType := Byte32;
			system.characterType := Character32;
			*)
		ELSE
			ASSERT(minBits = 8); (* nothing else is currently implemented *)
			system.shortintType := SyntaxTree.NewIntegerType(8, TRUE);
			system.integerType := SyntaxTree.NewIntegerType(16, TRUE);
			system.booleanType := SyntaxTree.NewBooleanType(8);
			system.byteType := SyntaxTree.NewByteType(8);
			system.characterType := SyntaxTree.NewCharacterType(8);;
			system.characterType8 := SyntaxTree.NewCharacterType(8);;
			system.characterType16 := SyntaxTree.NewCharacterType(16);;
			system.characterType32 := SyntaxTree.NewCharacterType(32);;
			(*
			system.shortintType := Integer8;
			system.integerType := Integer16;
			system.booleanType := Boolean8;
			system.byteType := Byte8;
			system.characterType := Character8;
			*)
		END;

		system.anyType := SyntaxTree.NewAnyType(system.addressSize);
		system.objectType := SyntaxTree.NewObjectType(system.addressSize);
		system.nilType := SyntaxTree.NewNilType(system.addressSize);
		system.addressType := SyntaxTree.NewAddressType(system.addressSize);
		system.sizeType := SyntaxTree.NewSizeType(system.addressSize);
		system.rangeType := SyntaxTree.NewRangeType(3 * system.SizeOf(system.longintType));

		system.complexType := Complex64;
		system.longcomplexType := Complex128;
		system.setType := SyntaxTree.NewSetType(system.addressSize);
		(* type declarations *)
		DeclareType(system.byteType,"BYTE",system.systemScope);
		DeclareType(system.addressType,"ADDRESS",system.globalScope);
		DeclareType(system.sizeType,"SIZE",system.globalScope);
		(*DeclareType(Same,"SAME",system.systemScope);*)

		(* system builtin procedures *)
		NewBuiltin(systemGet,"GET",system.systemScope,TRUE);
		NewBuiltin(systemPut,"PUT",system.systemScope,TRUE);
		NewBuiltin(systemPut64,"PUT64",system.systemScope,TRUE);
		NewBuiltin(systemPut32,"PUT32",system.systemScope,TRUE);
		NewBuiltin(systemPut16,"PUT16",system.systemScope,TRUE);
		NewBuiltin(systemPut8,"PUT8",system.systemScope,TRUE);
		NewBuiltin(systemGet64,"GET64",system.systemScope,TRUE);
		NewBuiltin(systemGet32,"GET32",system.systemScope,TRUE);
		NewBuiltin(systemGet16,"GET16",system.systemScope,TRUE);
		NewBuiltin(systemGet8,"GET8",system.systemScope,TRUE);
		NewBuiltin(systemVal,"VAL",system.systemScope,TRUE);
		NewBuiltin(systemMove,"MOVE",system.systemScope,TRUE);
		NewBuiltin(systemRef,"REF",system.systemScope,FALSE);
		NewBuiltin(systemNew,"NEW",system.systemScope,FALSE);
		NewBuiltin(systemTypeCode,"TYPECODE",system.systemScope,TRUE);
		NewBuiltin(systemHalt,"HALT",system.systemScope,TRUE);

		NewBuiltin(systemSize,"SIZE",system.systemScope,TRUE);
		NewBuiltin(systemAdr,"ADR",system.systemScope,TRUE);

		NewBuiltin(systemMsk,"MSK",system.systemScope,TRUE);
		NewBuiltin(systemBit,"BIT",system.systemScope,TRUE);

		now := Dates.Now ();
		Strings.FormatDateTime ("hh:nn:ss", now, time);
		Strings.FormatDateTime ("mmm dd yyyy", now, date);
		NewStringConstantCamelCase("Time", Strings.NewString (time), system.characterType, system.systemScope);
		NewStringConstantCamelCase("Date", Strings.NewString (date), system.characterType, system.systemScope);
		NewBuiltinCamelCase(systemGetStackPointer,"GetStackPointer",system.systemScope,TRUE);
		NewBuiltinCamelCase(systemSetStackPointer,"SetStackPointer",system.systemScope,TRUE);
		NewBuiltinCamelCase(systemGetFramePointer,"GetFramePointer",system.systemScope,TRUE);
		NewBuiltinCamelCase(systemSetFramePointer,"SetFramePointer",system.systemScope,TRUE);
		NewBuiltinCamelCase(systemGetActivity,"GetActivity",system.systemScope,TRUE);
		NewBuiltinCamelCase(systemSetActivity,"SetActivity",system.systemScope,TRUE);

		(* Set up system types *)
		DeclareType(system.characterType,"CHAR",system.globalScope);
		DeclareType(system.characterType8,"CHAR8",system.globalScope);
		DeclareType(system.characterType16,"CHAR16",system.globalScope);
		DeclareType(system.characterType32,"CHAR32",system.globalScope);
		DeclareType(system.rangeType,"RANGE",system.globalScope);
		DeclareType(system.shortintType,"SHORTINT",system.globalScope);
		DeclareType(system.integerType,"INTEGER",system.globalScope);
		DeclareType(system.longintType,"LONGINT",system.globalScope);
		DeclareType(system.hugeintType,"HUGEINT",system.globalScope);
		DeclareType(system.wordType,"WORD",system.globalScope);
		DeclareType(system.longWordType,"LONGWORD",system.globalScope);

		DeclareType(Integer8, "SIGNED8", system.globalScope);
		DeclareType(Integer16, "SIGNED16", system.globalScope);
		DeclareType(Integer32, "SIGNED32", system.globalScope);
		DeclareType(Integer64, "SIGNED64", system.globalScope);

		DeclareType(Unsigned8, "UNSIGNED8", system.globalScope);
		DeclareType(Unsigned16, "UNSIGNED16", system.globalScope);
		DeclareType(Unsigned32, "UNSIGNED32", system.globalScope);
		DeclareType(Unsigned64, "UNSIGNED64", system.globalScope);

		DeclareType(system.realType,"REAL",system.globalScope);
		DeclareType(system.longrealType,"LONGREAL",system.globalScope);
		DeclareType(system.complexType,"COMPLEX",system.globalScope);
		DeclareType(system.longcomplexType,"LONGCOMPLEX",system.globalScope);
		DeclareType(system.booleanType,"BOOLEAN",system.globalScope);
		DeclareType(system.setType,"SET",system.globalScope);
		DeclareType(system.anyType,"ANY",system.globalScope);
		DeclareType(system.objectType,"OBJECT",system.globalScope);

		(* global functions *)
		NewBuiltin(Abs,"ABS",system.globalScope,TRUE);
		NewBuiltin(Ash,"ASH",system.globalScope,TRUE);
		NewBuiltin(Asr,"ASR",system.globalScope,TRUE);
		NewBuiltin(Cap,"CAP",system.globalScope,TRUE);
		NewBuiltin(Chr,"CHR",system.globalScope,TRUE);
		NewBuiltin(Chr32,"CHR32",system.globalScope,TRUE);
		NewBuiltin(Entier,"ENTIER",system.globalScope,TRUE);
		NewBuiltin(Entier,"FLOOR",system.globalScope,TRUE);
		NewBuiltin(EntierH,"ENTIERH",system.globalScope,TRUE);
		NewBuiltin(Len,"LEN",system.globalScope,TRUE);
		NewBuiltin(Long,"LONG",system.globalScope,TRUE);
		NewBuiltin(Max,"MAX",system.globalScope,TRUE);
		NewBuiltin(Min,"MIN",system.globalScope,TRUE);
		NewBuiltin(Odd,"ODD",system.globalScope,TRUE);
		NewBuiltin(Ord,"ORD",system.globalScope,TRUE);
		NewBuiltin(Ord32,"ORD32",system.globalScope,TRUE);
		NewBuiltin(Lsh,"LSH",system.globalScope,TRUE);
		NewBuiltin(Lsh,"LSL",system.globalScope,TRUE);
		NewBuiltin(Rot,"ROT",system.globalScope,TRUE);
		NewBuiltin(Ror,"ROR",system.globalScope,TRUE);
		NewBuiltin(Incr,"INCR",system.globalScope,TRUE);

		NewBuiltin(Short,"SHORT",system.globalScope,TRUE);
		NewBuiltin(Sum,"SUM",system.globalScope,TRUE);
		NewBuiltin(Dim,"DIM",system.globalScope,TRUE);
		NewBuiltin(Cas,"CAS",system.globalScope,TRUE);

		NewBuiltin(First,"FIRST",system.globalScope,TRUE);
		NewBuiltin(Last,"LAST",system.globalScope,TRUE);
		NewBuiltin(Step,"STEP",system.globalScope,TRUE);

		NewBuiltin(Re,"RE",system.globalScope,TRUE);
		NewBuiltin(Im,"IM",system.globalScope,TRUE);

		NewBuiltin(systemAdr,"ADDRESSOF",system.globalScope,TRUE);
		NewBuiltin(systemSize,"SIZEOF",system.globalScope,TRUE);

		(* global proper procedures *)
		NewBuiltin(Assert,"ASSERT",system.globalScope,TRUE);
		NewBuiltin(Copy,"COPY",system.globalScope,TRUE);
		NewBuiltin(Dec,"DEC",system.globalScope,TRUE);
		NewBuiltin(Excl,"EXCL",system.globalScope,TRUE);
		NewBuiltin(Halt,"HALT",system.globalScope,TRUE);
		NewBuiltin(Inc,"INC",system.globalScope,TRUE);
		NewBuiltin(Incl,"INCL",system.globalScope,TRUE);
		NewBuiltin(New,"NEW",system.globalScope,FALSE);
		NewBuiltin(Dispose,"DISPOSE",system.globalScope, FALSE);
		NewBuiltin(GetProcedure,"GETPROCEDURE",system.globalScope,TRUE);
		NewBuiltin(systemTrace,"TRACE",system.globalScope,TRUE);
		NewBuiltin(Reshape,"RESHAPE",system.globalScope,TRUE);
		NewBuiltin(All,"ALL",system.globalScope,TRUE);
		NewBuiltin(Wait,"WAIT",system.globalScope,FALSE);
		NewBuiltin(Connect,"CONNECT",system.globalScope,FALSE);
		NewBuiltin(Receive,"RECEIVE",system.globalScope,FALSE);
		NewBuiltin(Send,"SEND",system.globalScope,FALSE);
		NewBuiltin(Delegate,"DELEGATE",system.globalScope,FALSE);


		(*!

       (* Following is LYNX version: *)

        IF minBits = 8 THEN
            system.characterType := Character16;
        END;


        (* LYNX builtin types *)
        DeclareLynxType(system.characterType, LynxChar, system.globalScope);
        DeclareLynxType(system.shortintType, LynxSbyte, system.globalScope);
        DeclareLynxType(system.integerType, LynxShort, system.globalScope);
        DeclareLynxType(system.longintType, LynxInt, system.globalScope);
        DeclareLynxType(system.hugeintType, LynxLong, system.globalScope);
        DeclareLynxType(system.realType, LynxFloat, system.globalScope);
        DeclareLynxType(system.longrealType, LynxDouble, system.globalScope);
        DeclareLynxType(system.booleanType, LynxBool, system.globalScope);
        (* TODO: object, string *)

        (* LYNX global functions *)
        NewBuiltin(SymLynxNewobj, LynxNewobj, system.globalScope, TRUE);
        NewBuiltin(SymLynxNewarr, LynxNewarr, system.globalScope, TRUE);
        NewBuiltin(SymLynxAsop, LynxAsop, system.globalScope, TRUE);
        NewBuiltin(SymLynxUnop, LynxUnop, system.globalScope, TRUE);
        NewBuiltin(SymLynxBinop, LynxBinop, system.globalScope, TRUE);
        NewBuiltin(SymLynxRecvnb, LynxRecvnb, system.globalScope, TRUE);

        (* 
            LynxCompiler will register builtins for send/receive/connect/delegate
            under "lynx@*" names but with their original Fox numeric identifiers,
            so that no modifications will be required in the semantic checker and
            intermediate backend.
        *)

        NewBuiltin(SymLynxNewsel, LynxNewsel, system.globalScope, TRUE);
        NewBuiltin(SymLynxAddsel, LynxAddsel, system.globalScope, TRUE);
        NewBuiltin(SymLynxSelect, LynxSelect, system.globalScope, TRUE);
        NewBuiltin(SymLynxSelidx, LynxSelidx, system.globalScope, TRUE);
	*)
	
	END SetDefaultDeclarations;

	PROCEDURE OperatorDefined*(system: System; op: LONGINT; defined: BOOLEAN);
	BEGIN
		system.operatorDefined[op] := defined;
	END OperatorDefined;

	PROCEDURE SetDefaultOperators*(system: System);
	VAR i: LONGINT;
	BEGIN
		FOR i := Scanner.Equal TO Scanner.Not DO
			OperatorDefined(system,i,TRUE);
		END;

		OperatorDefined(system, Conversion, TRUE);
		OperatorDefined(system, DotTimesPlus, TRUE);
		OperatorDefined(system, AtMulDec, TRUE);
		OperatorDefined(system, AtMulInc, TRUE);
		OperatorDefined(system, DecMul, TRUE);
		OperatorDefined(system, IncMul, TRUE);

		OperatorDefined(system,Scanner.Transpose,TRUE);
		OperatorDefined(system,Scanner.Becomes,TRUE);
		OperatorDefined(system,Dec,TRUE);
		OperatorDefined(system,Excl,TRUE);
		OperatorDefined(system,Inc,TRUE);
		OperatorDefined(system,Incl,TRUE);
		OperatorDefined(system,Abs,TRUE);
		OperatorDefined(system,Ash,TRUE);
		OperatorDefined(system,Cap,TRUE);
		OperatorDefined(system,Chr,TRUE);
		OperatorDefined(system,Entier,TRUE);
		OperatorDefined(system,EntierH,TRUE);
		OperatorDefined(system,Len,TRUE);
		OperatorDefined(system,Long,TRUE);
		OperatorDefined(system,Max,TRUE);
		OperatorDefined(system,Min,TRUE);
		OperatorDefined(system,Odd,TRUE);
		OperatorDefined(system,Short,TRUE);
		OperatorDefined(system,Sum,TRUE);
		OperatorDefined(system,Dim,TRUE);
		OperatorDefined(system,Scanner.Address, TRUE);
		OperatorDefined(system,Scanner.Size, TRUE);
		OperatorDefined(system,Scanner.Alias, TRUE);
		OperatorDefined(system,All,TRUE);
		
		OperatorDefined(system, Scanner.Questionmarks, TRUE);

		OperatorDefined(system, Scanner.GreaterGreater, TRUE);
		OperatorDefined(system, Scanner.LessLess, TRUE);

	END SetDefaultOperators;

	PROCEDURE DefaultSystem*(): System;
	VAR system: System;
	BEGIN
		NEW(system,8,8,32, 8,32,32,32,64,0,FALSE);
		SetDefaultDeclarations(system,8);
		SetDefaultOperators(system);
		RETURN system
	END DefaultSystem;

	PROCEDURE IsOberonProcedure*(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		RETURN (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.OberonCallingConvention)
	END IsOberonProcedure;

	PROCEDURE AlignedSizeOf*(system: System; CONST alignment: Alignment; type: SyntaxTree.Type):LONGINT;
	VAR value: LONGINT;
	BEGIN
		value := SHORT(system.SizeOf(type));
		INC(value, (-value) MOD system.AlignmentOf(alignment, type));
		RETURN value;
	END AlignedSizeOf;


	(* returns if a module is the system module *)
	PROCEDURE IsSystemModule*(module: SyntaxTree.Module): BOOLEAN;
	BEGIN RETURN (module.name=systemName) OR (module.name=SystemName)
	END IsSystemModule;

	(** Various factories *)
	PROCEDURE DeclareType0(type: SyntaxTree.Type; CONST name: ARRAY OF CHAR; in: SyntaxTree.Scope);
	VAR basic: SyntaxTree.TypeDeclaration; duplicate: BOOLEAN;
	BEGIN
		basic := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier(name));
		basic.SetDeclaredType(type);
		basic.SetState(SyntaxTree.Resolved);
		basic.SetAccess(SyntaxTree.ReadOnly);
		in.AddTypeDeclaration(basic);
		in.EnterSymbol(basic,duplicate);
		ASSERT(~duplicate);
	END DeclareType0;

	(** External interface backends can use to add their types etc. to the global scope *)
	PROCEDURE DeclareType*(type: SyntaxTree.Type; CONST name: ARRAY OF CHAR; CONST scope: ARRAY OF SyntaxTree.ModuleScope);
	VAR nameL,nameU: Scanner.IdentifierString;
	BEGIN
		Basic.Lowercase(name,nameL);
		Basic.Uppercase(name,nameU);
		DeclareType0(type,nameU,scope[Scanner.Uppercase]);
		DeclareType0(type,nameL,scope[Scanner.Lowercase]);
	END DeclareType;

    (* LYNX+ *)
    PROCEDURE DeclareLynxType*(
        type: SyntaxTree.Type; CONST name: ARRAY OF CHAR; CONST scope: ARRAY OF SyntaxTree.ModuleScope);
    BEGIN
        DeclareType0(type, name, scope[Scanner.Uppercase]);
        DeclareType0(type, name, scope[Scanner.Lowercase]);
    END DeclareLynxType;
    (* -LYNX *)

	PROCEDURE NewConstant0(CONST name: ARRAY OF CHAR; int: LONGINT; type: SyntaxTree.Type; in: SyntaxTree.Scope);
	VAR constant: SyntaxTree.Constant; value: SyntaxTree.IntegerValue;duplicate: BOOLEAN;
	BEGIN
		value := SyntaxTree.NewIntegerValue(-1,int);
		value.SetType(type);
		constant := SyntaxTree.NewConstant(-1,SyntaxTree.NewIdentifier(name));
		constant.SetValue(value);
		constant.SetType(value.type);
		constant.SetAccess(SyntaxTree.ReadOnly);
		constant.SetState(SyntaxTree.Resolved);
		in.AddConstant(constant);
		in.EnterSymbol(constant,duplicate);
		ASSERT(~duplicate);
	END NewConstant0;

	PROCEDURE NewConstant*(CONST name: ARRAY OF CHAR; int: LONGINT; type: SyntaxTree.Type; CONST scope: ARRAY OF SyntaxTree.ModuleScope);
	VAR nameL,nameU: Scanner.IdentifierString;
	BEGIN
		Basic.Lowercase(name,nameL);
		Basic.Uppercase(name,nameU);
		NewConstant0(nameU,int,type,scope[Scanner.Uppercase]);
		NewConstant0(nameL,int,type,scope[Scanner.Lowercase]);
	END NewConstant;

	PROCEDURE NewStringConstant0(CONST name: ARRAY OF CHAR; string: SyntaxTree.String; baseType: SyntaxTree.Type; in: SyntaxTree.Scope);
	VAR constant: SyntaxTree.Constant; value: SyntaxTree.StringValue;duplicate: BOOLEAN;
	BEGIN
		value := SyntaxTree.NewStringValue(-1,string);
		value.SetType(SyntaxTree.NewStringType(-1,baseType,value.length));
		constant := SyntaxTree.NewConstant(-1,SyntaxTree.NewIdentifier(name));
		constant.SetValue(value);
		constant.SetType(value.type);
		constant.SetAccess(SyntaxTree.ReadOnly);
		constant.SetState(SyntaxTree.Resolved);
		in.AddConstant(constant);
		in.EnterSymbol(constant,duplicate);
		ASSERT(~duplicate);
	END NewStringConstant0;

	PROCEDURE NewStringConstant*(CONST name: ARRAY OF CHAR; string: SyntaxTree.String; type: SyntaxTree.Type; CONST scope: ARRAY OF SyntaxTree.ModuleScope);
	VAR nameL,nameU: Scanner.IdentifierString;
	BEGIN
		Basic.Lowercase(name,nameL);
		Basic.Uppercase(name,nameU);
		NewStringConstant0(nameU,string,type,scope[Scanner.Uppercase]);
		NewStringConstant0(nameL,string,type,scope[Scanner.Lowercase]);
	END NewStringConstant;

	PROCEDURE NewStringConstantCamelCase*(CONST name: ARRAY OF CHAR; string: SyntaxTree.String; type: SyntaxTree.Type; CONST scope: ARRAY OF SyntaxTree.ModuleScope);
	BEGIN
		NewStringConstant0(name,string,type,scope[Scanner.Uppercase]);
		NewStringConstant0(name,string,type,scope[Scanner.Lowercase]);
	END NewStringConstantCamelCase;

	PROCEDURE NewBuiltin0( id: LONGINT; CONST name: ARRAY OF CHAR; in:  SyntaxTree.ModuleScope; realtime: BOOLEAN);
	VAR basic: SyntaxTree.Builtin; duplicate: BOOLEAN; type: SyntaxTree.ProcedureType;
	BEGIN
		basic := SyntaxTree.NewBuiltin(-1,SyntaxTree.NewIdentifier(name),id);
		basic.SetAccess(SyntaxTree.ReadOnly);
		type := SyntaxTree.NewProcedureType(-1,in);
		type.SetRealtime(realtime);
		type.SetReturnType(SyntaxTree.invalidType); (* make incompatible to any procedure *)
		basic.SetType(type);
		basic.SetState(SyntaxTree.Resolved);
		in.EnterSymbol(basic,duplicate);
		in.AddBuiltin(basic);
		ASSERT(~duplicate);
	END NewBuiltin0;

	PROCEDURE NewBuiltin*(id: LONGINT; CONST name: ARRAY OF CHAR; CONST scope: ARRAY OF SyntaxTree.ModuleScope; realtime: BOOLEAN);
	VAR nameL,nameU: Scanner.IdentifierString;
	BEGIN
		Basic.Lowercase(name,nameL);
		Basic.Uppercase(name,nameU);
		NewBuiltin0(id,nameU,scope[Scanner.Uppercase],realtime);
		NewBuiltin0(id,nameL,scope[Scanner.Lowercase],realtime);
	END NewBuiltin;

	PROCEDURE NewBuiltinCamelCase*(id: LONGINT; CONST name: ARRAY OF CHAR; CONST scope: ARRAY OF SyntaxTree.ModuleScope; realtime: BOOLEAN);
	BEGIN
		NewBuiltin0(id,name,scope[Scanner.Uppercase],realtime);
		NewBuiltin0(id,name,scope[Scanner.Lowercase],realtime);
	END NewBuiltinCamelCase;

	PROCEDURE NewCustomBuiltin0(CONST name: ARRAY OF CHAR; scope: SyntaxTree.ModuleScope; subType: SHORTINT; procedureType: SyntaxTree.ProcedureType);
	VAR
		isDuplicate: BOOLEAN;
		customBuiltin: SyntaxTree.CustomBuiltin;
	BEGIN
		customBuiltin := SyntaxTree.NewCustomBuiltin(-1, SyntaxTree.NewIdentifier(name), systemSpecial, subType);
		customBuiltin.SetAccess(SyntaxTree.ReadOnly); (* TODO: this might be changed *)
		procedureType.SetRealtime(TRUE);
		customBuiltin.SetType(procedureType); (* TODO: make incompatible to any procedure *)
		customBuiltin.SetState(SyntaxTree.Resolved);
		scope.EnterSymbol(customBuiltin, isDuplicate);
		scope.AddBuiltin(customBuiltin);
		ASSERT(~isDuplicate)
	END NewCustomBuiltin0;

	PROCEDURE NewCustomBuiltin*(CONST name: ARRAY OF CHAR; CONST scope: ARRAY OF SyntaxTree.ModuleScope; subType: SHORTINT; procedureType: SyntaxTree.ProcedureType);
	VAR
		nameL, nameU: Scanner.IdentifierString;
	BEGIN
		Basic.Lowercase(name, nameL);
		Basic.Uppercase(name, nameU);
		NewCustomBuiltin0(nameU, scope[Scanner.Uppercase], subType, procedureType);
		NewCustomBuiltin0(nameL, scope[Scanner.Lowercase], subType, procedureType)
	END NewCustomBuiltin;

	PROCEDURE ModuleFileName*(moduleName,context: SyntaxTree.Identifier; VAR fileName: ARRAY OF CHAR);
	VAR prefix,name: Scanner.IdentifierString;
	BEGIN
		Basic.GetString(moduleName,name);
		IF (context = SyntaxTree.invalidIdentifier) OR (context = A2Name) THEN
			COPY(name,fileName);
		ELSE
			ASSERT(context=OberonName);
			Basic.GetString(context,prefix);
			Basic.Concat(fileName,prefix,".",name);
		END;
	END ModuleFileName;

	PROCEDURE ContextFromName*(CONST fileName: ARRAY OF CHAR; VAR module,context: SyntaxTree.Identifier);
	VAR moduleName, contextName: Scanner.IdentifierString; i,j: LONGINT;
	BEGIN
		i := 0; j := 0;
		WHILE (fileName[i] # 0X) & (fileName[i] # ".") DO
			moduleName[i] := fileName[i];
			INC(i);
		END;
		moduleName[i] := 0X;
		IF fileName[i] # 0X THEN
			COPY(moduleName, contextName);
			INC(i);
			WHILE(fileName[i] # 0X) DO
				moduleName[j] := fileName[i];
				INC(i); INC(j);
			END;
			moduleName[j] := 0X;
		ELSE
			contextName := "A2";
		END;
		module := SyntaxTree.NewIdentifier(moduleName);
		context := SyntaxTree.NewIdentifier(contextName);
	END ContextFromName;

	PROCEDURE GetModuleName*(module: SyntaxTree.Module; VAR name: ARRAY OF CHAR);
	VAR n: SyntaxTree.IdentifierString;
	BEGIN
		name := "";
		IF module.context # SyntaxTree.invalidIdentifier THEN
			Basic.GetString(module.context,n);
			IF n# "A2" THEN Strings.Append(name,n);Strings.Append(name,".") END;
		END;
		module.GetName(n);
		Strings.Append(name,n);
	END GetModuleName;

	PROCEDURE GetModuleSegmentedName*(module: SyntaxTree.Module; VAR name: Basic.SegmentedName);
	BEGIN
		Basic.InitSegmentedName(name);
		IF (module.context # SyntaxTree.invalidIdentifier) & (module.context # A2Name) THEN
			name[0] := module.context;
			name[1] := module.name;
			name[2] := -1;
		ELSE
			name[0] :=module.name;
			name[1] := -1;
		END;
	END GetModuleSegmentedName;

	PROCEDURE FindSymbol*(CONST name: Basic.SegmentedName; scope: SyntaxTree.Scope): SyntaxTree.Symbol;
	VAR s: LONGINT;  symbol : SyntaxTree.Symbol;

		PROCEDURE GetSymbolScope;
		VAR type: SyntaxTree.Type;
		BEGIN
			IF symbol IS SyntaxTree.Module THEN
				scope := symbol(SyntaxTree.Module).moduleScope
			ELSIF symbol IS SyntaxTree.Import THEN
				scope := symbol(SyntaxTree.Import).module.moduleScope;
			ELSIF symbol IS SyntaxTree.Procedure THEN
				scope := symbol(SyntaxTree.Procedure).procedureScope
			ELSIF symbol IS SyntaxTree.TypeDeclaration THEN
				type := symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
				IF type IS SyntaxTree.RecordType THEN
					scope := type(SyntaxTree.RecordType).recordScope
				END;
			ELSE
				scope := NIL
			END
		END GetSymbolScope;

		PROCEDURE FindSymbol(name: SyntaxTree.Identifier): SyntaxTree.Symbol;
		VAR symbols: SyntaxTree.Symbol;
		BEGIN
			IF scope = scope.ownerModule.moduleScope THEN
				symbol := scope.ownerModule.moduleScope.ImportByModuleName(name, scope.ownerModule.context);
				IF symbol = NIL THEN
					symbol := scope.FindSymbol(name)
				END;
			ELSE
				symbol := scope.FindSymbol(name)
			END;
			RETURN symbol
		END FindSymbol;

	BEGIN
		s := 0;
		IF name[0] = scope.ownerModule.name THEN
			INC(s)
		END;
		scope := scope.ownerModule.moduleScope; (* expect fully qualified (segmented) name *)
		REPEAT
			IF scope = NIL THEN RETURN NIL END;
			symbol := FindSymbol(name[s]);
			IF symbol = NIL THEN RETURN NIL
			ELSE
				GetSymbolScope
			END;
			INC(s);
		UNTIL (s = LEN(name)) OR (name[s] < 0);
		RETURN symbol;
	END FindSymbol;


	PROCEDURE GetSymbolNameInScope*(symbol: SyntaxTree.Symbol; inScope: SyntaxTree.Scope; VAR name: ARRAY OF CHAR);
	VAR n: SyntaxTree.IdentifierString; td: SyntaxTree.TypeDeclaration;
		PROCEDURE Scope(scope: SyntaxTree.Scope);
		BEGIN
			IF scope = NIL THEN (* do nothing, locally declared temporary symbol *)
			ELSIF scope = inScope THEN (* do not traverse further *)
			ELSIF scope IS SyntaxTree.ModuleScope THEN

				GetModuleName(scope.ownerModule, name);
				Strings.Append(name,".");
			ELSIF scope IS SyntaxTree.RecordScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.RecordScope).ownerRecord.typeDeclaration;
				IF td = NIL THEN
					td := scope(SyntaxTree.RecordScope).ownerRecord.pointerType.typeDeclaration;
				END;
				td.GetName(n);
				Strings.Append(name,n); Strings.Append(name,".")
			ELSIF scope IS SyntaxTree.ProcedureScope THEN
				Scope(scope.outerScope);
				scope(SyntaxTree.ProcedureScope).ownerProcedure.GetName(n);
				Strings.Append(name,n); Strings.Append(name,".")
			ELSIF scope IS SyntaxTree.CellScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.CellScope).ownerCell.typeDeclaration;
				td.GetName(n);
				Strings.Append(name,n); Strings.Append(name,".")
			END;
		END Scope;

	BEGIN
		name := "";
		Scope(symbol.scope);
		symbol.GetName(n);
		IF symbol IS SyntaxTree.Operator THEN (*! append some more bits to make discrimintation possible *)
		END;
		Strings.Append(name,n);
	END GetSymbolNameInScope;

	PROCEDURE GetSymbolName*(symbol: SyntaxTree.Symbol; VAR name: ARRAY OF CHAR);
	BEGIN GetSymbolNameInScope(symbol,NIL,name)
	END GetSymbolName;

	PROCEDURE GetSymbolSegmentedNameInScope*(symbol: SyntaxTree.Symbol; inScope: SyntaxTree.Scope; VAR pooledName: Basic.SegmentedName);
	VAR n: SyntaxTree.String; td: SyntaxTree.TypeDeclaration; i: LONGINT;
		PROCEDURE Scope(scope: SyntaxTree.Scope);
		BEGIN
			IF scope = NIL THEN (* do nothing, locally declared temporary symbol *)
			ELSIF scope = inScope THEN (* do not traverse further *)
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				IF scope(SyntaxTree.ModuleScope).ownerModule.context # A2Name THEN
					Basic.SuffixSegmentedName(pooledName, scope(SyntaxTree.ModuleScope).ownerModule.context);
				END;
				Basic.SuffixSegmentedName(pooledName,scope.ownerModule.name);
			ELSIF scope IS SyntaxTree.RecordScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.RecordScope).ownerRecord.typeDeclaration;
				IF td = NIL THEN
					td := scope(SyntaxTree.RecordScope).ownerRecord.pointerType.typeDeclaration;
				END;
				Basic.SuffixSegmentedName(pooledName,td.name);
			ELSIF scope IS SyntaxTree.ProcedureScope THEN
				Scope(scope.outerScope);
				Basic.SuffixSegmentedName(pooledName,scope(SyntaxTree.ProcedureScope).ownerProcedure.name);
			ELSIF scope IS SyntaxTree.CellScope THEN
				Scope(scope.outerScope);
				td := scope(SyntaxTree.CellScope).ownerCell.typeDeclaration;
				Basic.SuffixSegmentedName(pooledName, td.name);
			END;
		END Scope;

	BEGIN
		FOR i := 0 TO LEN(pooledName)-1 DO pooledName[i] := -1 END;
		Scope(symbol.scope);
		Basic.SuffixSegmentedName(pooledName, symbol.name);
	END GetSymbolSegmentedNameInScope;


	PROCEDURE GetSymbolSegmentedName*(symbol: SyntaxTree.Symbol; VAR pooledName: Basic.SegmentedName);
	BEGIN
		GetSymbolSegmentedNameInScope(symbol,NIL,pooledName);
	END GetSymbolSegmentedName;


	PROCEDURE Level*(t: SyntaxTree.Type): LONGINT;
	VAR level: LONGINT;
	BEGIN
		IF t IS SyntaxTree.IntegerType THEN
			CASE t.sizeInBits OF
				8: level := 0;
				|16: level := 1;
				|32: level := 2;
				|64: level := 3;
			END;
		ELSIF t IS SyntaxTree.FloatType THEN
			CASE t.sizeInBits OF
				32: level := 4;
				|64: level := 5;
			END
		ELSE HALT(100)
		END;
		RETURN level
	END Level;

	PROCEDURE ConvertSigned*(this: HUGEINT; bits: LONGINT): HUGEINT;
	BEGIN
		bits := 64-bits;
		RETURN ASH (ASH (this, bits), -bits);
	END ConvertSigned;

	PROCEDURE ConvertUnsigned*(this: HUGEINT; bits: LONGINT): HUGEINT;
	BEGIN
		bits := 64-bits;
		RETURN LSH (LSH (this, bits), -bits);
	END ConvertUnsigned;

	PROCEDURE MaxInteger*(system: System; type: SyntaxTree.BasicType): HUGEINT;
	BEGIN
		RETURN ASH (HUGEINT(1), system.SizeOf (type) - 1) - 1;
	END MaxInteger;

	PROCEDURE MinInteger*(system: System; type: SyntaxTree.BasicType): HUGEINT;
	BEGIN
		RETURN -ASH (HUGEINT(1), system.SizeOf (type) - 1);
	END MinInteger;

	(*! make architecture  independent ! *)
	PROCEDURE MaxFloat*(system: System; type: SyntaxTree.FloatType): LONGREAL;
	BEGIN
		IF system.SizeOf(type) = 32 THEN RETURN MAX(REAL) ELSE RETURN MAX(LONGREAL) END;
	END MaxFloat;

	PROCEDURE MinFloat*(system: System; type: SyntaxTree.FloatType): LONGREAL;
	BEGIN
		IF system.SizeOf(type) = 32 THEN RETURN MIN(REAL) ELSE RETURN MIN(LONGREAL) END;
	END MinFloat;

	PROCEDURE IsUnsignedInteger*(this: HUGEINT; sizeInBits: LONGINT): BOOLEAN;
	VAR m: HUGEINT;
	BEGIN
		m := ASH(HUGEINT(1),sizeInBits);
		RETURN (this >= 0) & (this < m)
	END IsUnsignedInteger;

	PROCEDURE IsSignedInteger*(this: HUGEINT; sizeInBits: LONGINT): BOOLEAN;
	VAR m: HUGEINT;
	BEGIN
			m := ASH(HUGEINT(1),sizeInBits-1);
			RETURN (this < m) & (-this <= m)
	END IsSignedInteger;

	PROCEDURE GetSignedIntegerType*(system: System; this: HUGEINT): SyntaxTree.IntegerType;

		(* code snippets for unsigned
		ELSE
			m := Runtime.AslH(1,system.SizeOf(type));
			RETURN (this >= 0) & (this < m)
		END;

		PROCEDURE Bits(x: HUGEINT): BOOLEAN;
		BEGIN
			WHILE x > 0 DO INC(bits); x := x DIV 2 END;
		END Bits;

		IF a = MIN(HUGEINT) THEN (* -a does not work on lowest possible number, ~a+1 would overflow *)
			RETURN Integer[64]
		ELSIF a < 0 THEN
			RETURN Integer[Bits(-a-1)+1]
		ELSE
			RETURN Unisgned[Bits(a)]
		END;
		*)

	BEGIN
		IF IsSignedInteger(this,8) THEN RETURN Integer8
		ELSIF IsSignedInteger(this, 16) THEN RETURN Integer16
		ELSIF IsSignedInteger(this, 32) THEN RETURN Integer32
		ELSE RETURN Integer64
		END;
	END GetSignedIntegerType;
	
	PROCEDURE GetIntegerType*(system: System; this: HUGEINT): SyntaxTree.IntegerType;
	BEGIN
		IF IsSignedInteger(this,8) THEN RETURN Integer8
				(* system.SizeOf(...) = 8 : detect special backends with no sizes smaller than 32 *)
		ELSIF (system.SizeOf(Unsigned8) =  8) & IsUnsignedInteger(this,8) THEN RETURN Unsigned8
		ELSIF IsSignedInteger(this, 16) THEN RETURN Integer16
		ELSIF (system.SizeOf(Unsigned16) = 16) & IsUnsignedInteger(this,16) THEN RETURN Unsigned16
		ELSIF IsSignedInteger(this, 32) THEN RETURN Integer32
		ELSIF IsUnsignedInteger(this,32) THEN RETURN Unsigned32
		ELSE RETURN Integer64
		END;
	END GetIntegerType;
	
	PROCEDURE NewIntegerValue*(system: System; position: LONGINT; hugeint: HUGEINT): SyntaxTree.Value;
	VAR value: SyntaxTree.IntegerValue;
	BEGIN
		value := SyntaxTree.NewIntegerValue(position,hugeint);
		value.SetType(GetIntegerType(system,hugeint));
		RETURN value
	END NewIntegerValue;

	PROCEDURE NewBooleanValue*(system: System; position: LONGINT; b: BOOLEAN): SyntaxTree.Value;
	VAR value: SyntaxTree.BooleanValue;
	BEGIN
		value := SyntaxTree.NewBooleanValue(position,b);
		value.SetType(system.booleanType);
		RETURN value
	END NewBooleanValue;

	PROCEDURE NewSetValue*(system: System; position: LONGINT; s: SET): SyntaxTree.Value;
	VAR value: SyntaxTree.SetValue;
	BEGIN
		value := SyntaxTree.NewSetValue(position,s);
		value.SetType(system.setType);
		RETURN value
	END NewSetValue;

	PROCEDURE NewCharacterValue*(system: System; position: LONGINT; c: CHAR): SyntaxTree.Value;
	VAR value: SyntaxTree.CharacterValue;
	BEGIN
		value := SyntaxTree.NewCharacterValue(position,c);
		value.SetType(system.characterType);
		RETURN value
	END NewCharacterValue;

	PROCEDURE NewNilValue*(system: System; position: LONGINT): SyntaxTree.Value;
	VAR value: SyntaxTree.NilValue;
	BEGIN
		value := SyntaxTree.NewNilValue(position);
		value.SetType(system.anyType);
		RETURN value
	END NewNilValue;

	(* distance for assignment to <- from *)
	PROCEDURE BasicTypeDistance*(system: System; from, to: SyntaxTree.BasicType): LONGINT;
	VAR fromSize, toSize, distance: LONGINT;
	BEGIN
		fromSize := system.SizeOf(from); toSize := system.SizeOf(to);
		distance := -1;
		IF (from IS SyntaxTree.IntegerType) & (to IS SyntaxTree.IntegerType) & (toSize >= fromSize) THEN
			IF from(SyntaxTree.IntegerType).signed # to(SyntaxTree.IntegerType).signed THEN
				IF (toSize=fromSize) & to(SyntaxTree.IntegerType).signed THEN 
					distance := MIN(LONGINT) 
				ELSE
					INC(distance,2);
				END;
			END;
			WHILE toSize >= fromSize DO
				toSize := toSize DIV 2; INC(distance);
			END;
		ELSIF (from IS SyntaxTree.CharacterType) & (to IS SyntaxTree.CharacterType) & (toSize >= fromSize)  OR
			(from IS SyntaxTree.FloatType) & (to IS SyntaxTree.FloatType) & (toSize >= fromSize) 
		THEN
			WHILE toSize >= fromSize DO
				toSize := toSize DIV 2; INC(distance);
			END;
		ELSIF (from IS SyntaxTree.IntegerType) & (to IS SyntaxTree.FloatType) THEN
			IF toSize = 64 THEN distance := 1 ELSE distance := 0 END;
			toSize := 64;
			WHILE toSize >= fromSize DO
				toSize := toSize DIV 2; INC(distance);
			END;
		ELSIF (from IS SyntaxTree.RangeType) & (to IS SyntaxTree.RangeType) THEN
			distance := 0;
		ELSIF (from IS SyntaxTree.BooleanType) & (to IS SyntaxTree.BooleanType) THEN
			distance := 0;
		END;

		IF distance < 0 THEN distance := MAX(LONGINT) END;
		RETURN distance
	END BasicTypeDistance;

	PROCEDURE GetIdentifier*(symbol: LONGINT; case: LONGINT): SyntaxTree.Identifier;
	BEGIN
		IF (symbol >= 0) & (symbol < LEN(identifiers,1)) THEN
			RETURN identifiers[case,symbol]
		ELSE
			RETURN SyntaxTree.invalidIdentifier
		END;
	END GetIdentifier;

	PROCEDURE GetSymbol*(case: LONGINT; id: SyntaxTree.Identifier): LONGINT;
	VAR i: LONGINT;
	BEGIN
		(*! quick and dirty implementation, optimize ! *)
		FOR i := 0 TO LEN(identifiers,1)-1 DO
			IF id=identifiers[case,i] THEN RETURN i END;
		END;
		RETURN -1
	END GetSymbol;


	PROCEDURE InitIdentifiers;
	VAR i: LONGINT;

		PROCEDURE NewKeywordIdentifier(op: LONGINT);
		VAR id: Scanner.IdentifierType;
		BEGIN
			Scanner.GetKeyword(Scanner.Uppercase,op,id);
			identifiers[Scanner.Uppercase,op] := id;
			Scanner.GetKeyword(Scanner.Lowercase,op,id);
			identifiers[Scanner.Lowercase,op] := id;
		END NewKeywordIdentifier;

		PROCEDURE NewBuiltinIdentifier(op: LONGINT; CONST name: ARRAY OF CHAR);
		VAR nameL,nameU: Scanner.IdentifierString;
		BEGIN
			ASSERT(op < LEN(identifiers[0]));
			Basic.Lowercase(name,nameL);
			Basic.Uppercase(name,nameU);
			identifiers[Scanner.Lowercase,op] := SyntaxTree.NewIdentifier(nameL);
			identifiers[Scanner.Uppercase,op] := SyntaxTree.NewIdentifier(nameU);
		END NewBuiltinIdentifier;

	BEGIN
		FOR i := 0 TO LEN(identifiers,1)-1 DO
			identifiers[Scanner.Uppercase,i] := SyntaxTree.invalidIdentifier; identifiers[Scanner.Lowercase,i] := SyntaxTree.invalidIdentifier;
		END;
		FOR i := 0 TO Scanner.EndOfText-1 DO
			NewKeywordIdentifier(i);
		END;
		NewBuiltinIdentifier(Abs,"ABS");
		NewBuiltinIdentifier(Ash,"ASH");
		NewBuiltinIdentifier(Asr,"ASR");
		NewBuiltinIdentifier(Cap,"CAP");
		NewBuiltinIdentifier(Chr,"CHR");
		NewBuiltinIdentifier(Chr32,"CHR32");
		NewBuiltinIdentifier(Entier,"ENTIER");
		NewBuiltinIdentifier(EntierH,"ENTIERH");
		NewBuiltinIdentifier(Len,"LEN");
		NewBuiltinIdentifier(Long,"LONG");
		NewBuiltinIdentifier(Lsh,"LSH");
		NewBuiltinIdentifier(Max,"MAX");
		NewBuiltinIdentifier(Min,"MIN");
		NewBuiltinIdentifier(Odd,"ODD");
		NewBuiltinIdentifier(Ord,"ORD");
		NewBuiltinIdentifier(Ord32,"ORD32");
		NewBuiltinIdentifier(Ror,"ROR");
		NewBuiltinIdentifier(Rot,"ROT");
		NewBuiltinIdentifier(Short,"SHORT");
		NewBuiltinIdentifier(Sum,"SUM");
		NewBuiltinIdentifier(Dim,"DIM");
		NewBuiltinIdentifier(Cas,"CAS");
		NewBuiltinIdentifier(Dec,"DEC");
		NewBuiltinIdentifier(Excl,"EXCL");
		NewBuiltinIdentifier(Inc,"INC");
		NewBuiltinIdentifier(Incl,"INCL");
		NewBuiltinIdentifier(All,"ALL");


		(* TODO: check if ok. The operators defined in FoxArrayBase require the following identifiers *)
		(* TODO: ".*+" should preferably be added as a new token in the scanner *)
		identifiers[Scanner.Lowercase, Scanner.Becomes] := SyntaxTree.NewIdentifier(":=");
		identifiers[Scanner.Uppercase, Scanner.Becomes] := SyntaxTree.NewIdentifier(":=");
		identifiers[Scanner.Lowercase, Scanner.Transpose] := SyntaxTree.NewIdentifier("`");
		identifiers[Scanner.Uppercase, Scanner.Transpose] := SyntaxTree.NewIdentifier("`");
		identifiers[Scanner.Lowercase, DotTimesPlus] := SyntaxTree.NewIdentifier(".*+");
		identifiers[Scanner.Uppercase, DotTimesPlus] := SyntaxTree.NewIdentifier(".*+");
		identifiers[Scanner.Lowercase, AtMulDec] := SyntaxTree.NewIdentifier("@MulDec");
		identifiers[Scanner.Uppercase, AtMulDec] := SyntaxTree.NewIdentifier("@MulDec");
		identifiers[Scanner.Lowercase, AtMulInc] := SyntaxTree.NewIdentifier("@MulInc");
		identifiers[Scanner.Uppercase, AtMulInc] := SyntaxTree.NewIdentifier("@MulInc");
		identifiers[Scanner.Lowercase, DecMul] := SyntaxTree.NewIdentifier("DecMul");
		identifiers[Scanner.Uppercase, DecMul] := SyntaxTree.NewIdentifier("DecMul");
		identifiers[Scanner.Lowercase, IncMul] := SyntaxTree.NewIdentifier("IncMul");
		identifiers[Scanner.Uppercase, IncMul] := SyntaxTree.NewIdentifier("IncMul");

		identifiers[Scanner.Lowercase,Conversion] := SyntaxTree.NewIdentifier("@Convert");
		identifiers[Scanner.Uppercase,Conversion] := SyntaxTree.NewIdentifier("@Convert");

	END InitIdentifiers;

	(** initialize the global namespace *)
	PROCEDURE Init;
	BEGIN
		InitIdentifiers;
		(* names are not arbitrary, do not change unless you know what you do (compatibilty with paco!) *)
		SystemName := SyntaxTree.NewIdentifier("SYSTEM");
		systemName := SyntaxTree.NewIdentifier("system");
		SelfParameterName := SyntaxTree.NewIdentifier("@Self");
		ReturnParameterName := SyntaxTree.NewIdentifier("@ReturnParameter");
		PointerReturnName := SyntaxTree.NewIdentifier("@PtrReturnType");
		ResultName := SyntaxTree.NewIdentifier("RESULT");
		A2Name := SyntaxTree.NewIdentifier("A2");
		OberonName := SyntaxTree.NewIdentifier("Oberon");
		ArrayBaseName := SyntaxTree.NewIdentifier("FoxArrayBase");
		RecordBodyName := SyntaxTree.NewIdentifier("@Body");
		ModuleBodyName := SyntaxTree.NewIdentifier("@Body");

		NameWinAPI := SyntaxTree.NewIdentifier(StringWinAPI);
		NameC := SyntaxTree.NewIdentifier(StringC);
		NameMovable := SyntaxTree.NewIdentifier(StringMovable);
		NameUntraced := SyntaxTree.NewIdentifier(StringUntraced);
		NameDelegate := SyntaxTree.NewIdentifier(StringDelegate);
		NameInterrupt := SyntaxTree.NewIdentifier(StringInterrupt);
		NamePcOffset := SyntaxTree.NewIdentifier(StringPcOffset);
		NameNoPAF := SyntaxTree.NewIdentifier(StringNoPAF);
		NameEntry := SyntaxTree.NewIdentifier(StringEntry);
		NameExit := SyntaxTree.NewIdentifier(StringExit);
		NameFixed := SyntaxTree.NewIdentifier(StringFixed);
		NameAligned := SyntaxTree.NewIdentifier(StringAligned);
		NameStackAligned := SyntaxTree.NewIdentifier(StringAlignStack);
		NameExclusive := SyntaxTree.NewIdentifier(StringExclusive);
		NameActive := SyntaxTree.NewIdentifier(StringActive);
		NamePriority := SyntaxTree.NewIdentifier(StringPriority);
		NameSafe := SyntaxTree.NewIdentifier(StringSafe);
		NameRealtime := SyntaxTree.NewIdentifier(StringRealtime);
		NameDynamic := SyntaxTree.NewIdentifier(StringDynamic);
		NameDataMemorySize := SyntaxTree.NewIdentifier(StringDataMemorySize);
		NameCodeMemorySize := SyntaxTree.NewIdentifier(StringCodeMemorySize);
		NameChannelWidth := SyntaxTree.NewIdentifier(StringChannelWidth);
		NameChannelDepth := SyntaxTree.NewIdentifier(StringChannelDepth);
		NameChannelModule := SyntaxTree.NewIdentifier(StringChannelModule);
		NameVector := SyntaxTree.NewIdentifier(StringVector);
		NameFloatingPoint := SyntaxTree.NewIdentifier(StringFloatingPoint);
		NameNoMul:= SyntaxTree.NewIdentifier(StringNoMul);
		NameNonBlockingIO:=SyntaxTree.NewIdentifier(StringNonBlockingIO);
		NameTRM := SyntaxTree.NewIdentifier(StringTRM);
		NameTRMS := SyntaxTree.NewIdentifier(StringTRMS);
		NameEngine := SyntaxTree.NewIdentifier(StringEngine);
		NameFinal := SyntaxTree.NewIdentifier(StringFinal);
		NameAbstract := SyntaxTree.NewIdentifier(StringAbstract);
		NameFrequencyDivider := SyntaxTree.NewIdentifier(StringFrequencyDivider);
		NameRegister := SyntaxTree.NewIdentifier(StringRegister);
		NameNoReturn := SyntaxTree.NewIdentifier(StringNoReturn);
		NamePlain := SyntaxTree.NewIdentifier(StringPlain);
		NameUnsafe := SyntaxTree.NewIdentifier(StringUnsafe);
		NameDisposable := SyntaxTree.NewIdentifier(StringDisposable);
		NameUnchecked := SyntaxTree.NewIdentifier(StringUnchecked);
		NameUncooperative := SyntaxTree.NewIdentifier(StringUncooperative);

		(* types *)
		Boolean8 := SyntaxTree.NewBooleanType(8);
		Boolean32 := SyntaxTree.NewBooleanType(32);
		Integer8 := SyntaxTree.NewIntegerType(8, TRUE);
		Integer16 := SyntaxTree.NewIntegerType(16, TRUE);
		Integer32 := SyntaxTree.NewIntegerType(32, TRUE);
		Integer64 := SyntaxTree.NewIntegerType(64, TRUE);
		Unsigned8 := SyntaxTree.NewIntegerType(8, FALSE);
		Unsigned16 := SyntaxTree.NewIntegerType(16, FALSE);
		Unsigned32 := SyntaxTree.NewIntegerType(32, FALSE);
		Unsigned64 := SyntaxTree.NewIntegerType(64, FALSE);
		Float32 := SyntaxTree.NewFloatType(32);
		Float64 := SyntaxTree.NewFloatType(64);
		Complex64 := SyntaxTree.NewComplexType(Float32);
		Complex128 := SyntaxTree.NewComplexType(Float64);
		Byte8 := SyntaxTree.NewByteType(8);
		Byte32 := SyntaxTree.NewByteType(32);
		Character8 := SyntaxTree.NewCharacterType(8);
		Character16 := SyntaxTree.NewCharacterType(16);
		Character32 := SyntaxTree.NewCharacterType(32);
	END Init;

BEGIN
	Init;
END FoxGlobal.
