MODULE FoxIntermediateBackend; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, SemanticChecker := FoxSemanticChecker, Backend := FoxBackend, Global := FoxGlobal,
	Scanner := FoxScanner, IntermediateCode := FoxIntermediateCode, Sections := FoxSections, BinaryCode := FoxBinaryCode,  Printout := FoxPrintout,
	SYSTEM, Diagnostics, Strings, Options, Streams, Compiler, Formats := FoxFormats, SymbolFileFormat := FoxTextualSymbolFile, D := Debugging,
	FingerPrinter := FoxFingerPrinter, StringPool;

CONST
		(* operand modes *)
		ModeUndefined = 0;
		ModeReference = 1;
		ModeValue = 2;

		(* heap data offsets *)
		ArrayDimTable = 3;	(* dimension table in dyn arrays *)

		(* math array offsets *)
		MathPtrOffset=0;
		MathAdrOffset=1;
		MathFlagsOffset=2;
		MathDimOffset=3;
		MathElementSizeOffset=4;
		MathLenOffset=5;
		MathIncrOffset=6;

		SysDataArrayOffset* = 0; (* array offset in system bl	ock, for 32 byte alignment *)
		ArrDataArrayOffset*= 16*8; (* 16 bytes array offset in array block, to be compatible with the GC scheme of POINTER TO ARRAY OF ... *)

		TensorFlag* = 0;   (* flag indicating a tensor array *)
		RangeFlag* = 1;   (* flag indicating a range, e.g. an array derived from A[..,..] *)
		StackFlag* = 2;   (* flag indicates temporary result *)
		StaticFlag* = 1;   (* flag indicating a static array, may not be reallocated *)

		(** compiler generated traps *)
		WithTrap* = 1; (* generated when a WITH statement fails *)
		CaseTrap* = 2; (* generated when a case statement without else block fails *)
		ReturnTrap* = 3;
		TypeEqualTrap* = 5;
		TypeCheckTrap* = 6;
		IndexCheckTrap* = 7; (* generated when index is out of bounds or range is invalid *)
		AssertTrap* = 8; (* generated when an assert fails *)
		ArraySizeTrap* = 9;
		ArrayFormTrap*=10; (* indicates that array cannot be (re-)allocated since shape, type or size does not match *)
		SetElementTrap*=11; (* indicates that a set element is out of MIN(SET)...MAX(SET) *)
		NegativeDivisorTrap*=12;
		NoReturnTrap*=16; (* indicates that a procedure marked no return did return *)
		NilPointerTrap*=17; (* indicates that a nil pointer was being dereferenced *)

		Trace = FALSE;
		TraceRegisterUsageCount=TRUE;

		ArrayAlignment = 8*8;			(* first array element of ArrayBlock and first data element of SystemBlock must be aligned to 0 MOD ArrayAlignment *)

		(** system call numbers  *)
		NumberSystemCalls* = 12;
		SysNewRec* = 0;  SysNewArr* = 1;  SysNewSys* = 2;  SysCaseTable* = 3;  SysProcAddr* = 4;
		SysLock* = 5;  SysUnlock* = 6;  SysStart* = 7;  SysAwait* = 8; SysInterfaceLookup* = 9;
		SysRegisterInterface* = 10; SysGetProcedure* = 11;

		DefaultRuntimeModuleName ="Runtime";
		DefaultTraceModuleName ="KernelLog";
		ChannelModuleName = "Channels";

		suppressModuleRegistration=FALSE;

		NonPointer = -1; (* special pointer values *)
		NoType = 0; (* special type info values *)
		LhsIsPointer = 0; (* for the operator kind *)
		RhsIsPointer = 1;

		(* priority values, lower means higher priority *)
		EntryPriority=-4;
		FirstPriority=-3;
		InitPriority=-2;
		ExitPriority=-1;

		StrictChecks = FALSE;
		
		BasePointerTypeSize = 5;
		BaseArrayTypeSize = BasePointerTypeSize + 3;
			LengthOffset = BasePointerTypeSize + 0;
			DataOffset = BasePointerTypeSize + 1;
			DescriptorOffset = BasePointerTypeSize + 2;
		BaseRecordTypeSize = BasePointerTypeSize + 2;
			ActionOffset = BasePointerTypeSize + 0;
			MonitorOffset = BasePointerTypeSize + 1;
		BaseObjectTypeSize = BaseRecordTypeSize;
			ActionTypeSize = 3;
			MonitorTypeSize = 7;
			ProcessorOffset = BaseObjectTypeSize + 1;
			StackLimitOffset* = BaseObjectTypeSize + 3;
			QuantumOffset = BaseObjectTypeSize + 4;
			
			
			
		(* flags for optimizations with small matricies and vectors (Alexey Morozov) *)
		SmallMatrixFlag = 3; (* flag for identification of a small matrix *)
		SmallVectorFlag = 3; (* flag for identification of a small vector *)
		Size2Flag = 4; (* size = 2 *)
		Size3Flag = 5; (* size = 3 *)
		Size4Flag = 6; (* size = 4 *)
		Size5Flag = 7; (* size = 5 *)
		Size6Flag = 8; (* size = 6 *)
		Size7Flag = 9; (* size = 7 *)
		Size8Flag = 10; (* size = 8 *)
		
		ReflectionSupport = TRUE;
		
TYPE
	SupportedInstructionProcedure* = PROCEDURE {DELEGATE} (CONST instr: IntermediateCode.Instruction; VAR moduleName,procedureName: ARRAY OF CHAR): BOOLEAN;
	SupportedImmediateProcedure* = PROCEDURE {DELEGATE} (CONST op: IntermediateCode.Operand): BOOLEAN;

	Operand = RECORD
		mode: SHORTINT;
		op: IntermediateCode.Operand;
		tag: IntermediateCode.Operand;
		extra: IntermediateCode.Operand; (* stores the step size of an array range *)
		dimOffset: LONGINT;
	END;

	Fixup= POINTER TO RECORD
		pc: LONGINT;
		nextFixup: Fixup;
	END;

	WriteBackCall = POINTER TO RECORD
		call: SyntaxTree.ProcedureCallDesignator;
		next: WriteBackCall;
	END;

	Label= OBJECT
	VAR
		fixups: Fixup;
		section: IntermediateCode.Section;
		pc: LONGINT;

		PROCEDURE &InitLabel(section: IntermediateCode.Section);
		BEGIN
			SELF.section := section; pc := -1;
		END InitLabel;

		PROCEDURE Resolve(pc: LONGINT);
		VAR at: LONGINT;
		BEGIN
			SELF.pc := pc;
			WHILE(fixups # NIL) DO
				at := fixups.pc;
				section.PatchAddress(at,pc);
				fixups := fixups.nextFixup;
			END;
		END Resolve;

		PROCEDURE AddFixup(at: LONGINT);
		VAR fixup: Fixup;
		BEGIN
			ASSERT(pc=-1);
			NEW(fixup); fixup.pc := at; fixup.nextFixup := fixups; fixups := fixup;
		END AddFixup;

	END Label;


	ConditionalBranch = PROCEDURE {DELEGATE}(label: Label; op1,op2: IntermediateCode.Operand);

	DeclarationVisitor =OBJECT(SyntaxTree.Visitor)
	VAR
		backend: IntermediateBackend;
		implementationVisitor: ImplementationVisitor;
		meta: MetaDataGenerator;
		system: Global.System;
		currentScope: SyntaxTree.Scope;
		module: Sections.Module;
		moduleSelf: SyntaxTree.Variable;
		dump: BOOLEAN;
		forceModuleBody: BOOLEAN;
		addressType: IntermediateCode.Type;

		PROCEDURE & Init(system: Global.System; implementationVisitor: ImplementationVisitor; backend: IntermediateBackend; forceModuleBody, dump: BOOLEAN);
		BEGIN
			currentScope := NIL; module := NIL; moduleSelf := NIL;
			SELF.system := system; SELF.implementationVisitor := implementationVisitor;
			SELF.dump := dump;
			SELF.backend := backend;
			SELF.forceModuleBody := forceModuleBody;
			addressType := IntermediateCode.GetType(system,system.addressType)
		END Init;

		PROCEDURE Error(position: LONGINT; CONST s: ARRAY OF CHAR);
		BEGIN
			backend.Error(module.module.sourceName, position, Diagnostics.Invalid, s);
		END Error;

		PROCEDURE Type(x: SyntaxTree.Type);
		BEGIN
			x.Accept(SELF);
		END Type;

		(** types **)

		PROCEDURE VisitBasicType(x: SyntaxTree.BasicType);
		BEGIN (* no code emission *) END VisitBasicType;

		PROCEDURE VisitCharacterType(x: SyntaxTree.CharacterType);
		BEGIN (* no code emission *)  END VisitCharacterType;

		PROCEDURE VisitIntegerType(x: SyntaxTree.IntegerType);
		BEGIN (* no code emission *)  END VisitIntegerType;

		PROCEDURE VisitFloatType(x: SyntaxTree.FloatType);
		BEGIN (* no code emission *)  END VisitFloatType;

		PROCEDURE VisitComplexType(x: SyntaxTree.ComplexType);
		BEGIN (* no code emission *)  END VisitComplexType;

		PROCEDURE VisitQualifiedType(x: SyntaxTree.QualifiedType);
		VAR type: SyntaxTree.Type;
		BEGIN (* no further traversal to x.resolved necessary since type descriptor and code will be inserted at "original" position ? *)
			type := x.resolved;
			IF (type.typeDeclaration # NIL) & (type.typeDeclaration.scope.ownerModule # module.module) THEN
				meta.CheckTypeDeclaration(type);
			END;
		END VisitQualifiedType;

		PROCEDURE VisitStringType(x: SyntaxTree.StringType);
		BEGIN (* no code emission *)   END VisitStringType;

		PROCEDURE VisitArrayRangeType(x: SyntaxTree.RangeType);
		BEGIN (* no code emission *)
		END VisitArrayRangeType;

		PROCEDURE VisitArrayType(x: SyntaxTree.ArrayType);
		BEGIN (* no code emission *)   END VisitArrayType;

		PROCEDURE VisitMathArrayType(x: SyntaxTree.MathArrayType);
		BEGIN
			meta.CheckTypeDeclaration(x);
		END VisitMathArrayType;

		PROCEDURE VisitPointerType(x: SyntaxTree.PointerType);
		BEGIN
			meta.CheckTypeDeclaration(x);
			(* base type must not be visited => will be done via record type declaration, otherwise is done twice ! *)
		END VisitPointerType;

		PROCEDURE VisitRecordType(x: SyntaxTree.RecordType);
		VAR name: ARRAY 256 OF CHAR; td: SyntaxTree.TypeDeclaration;
		BEGIN (* no code emission *)
			meta.CheckTypeDeclaration(x);
			IF (x.recordScope.ownerModule = module.module) & (x.isObject) THEN
				IF x.pointerType.typeDeclaration # NIL THEN
					td := x.pointerType.typeDeclaration
				ELSE
					td := x.typeDeclaration
				END;
				Global.GetSymbolName(td,name);

				(* code section for object *)
			END;
			Scope(x.recordScope);
		END VisitRecordType;

		PROCEDURE HasFlag(modifiers: SyntaxTree.Modifier; CONST name: ARRAY OF CHAR): BOOLEAN;
		VAR this: SyntaxTree.Modifier; id: SyntaxTree.Identifier;
		BEGIN
			this := modifiers; id := SyntaxTree.NewIdentifier(name);
			WHILE (this # NIL) & (this.identifier# id) DO
				this := this.nextModifier;
			END;
			RETURN this # NIL
		END HasFlag;

		PROCEDURE VisitCellType(x: SyntaxTree.CellType);
		VAR port,adr: LONGINT; symbol: IntermediateCode.Section; op: IntermediateCode.Operand; capabilities: SET;

			(*
			PROCEDURE CreatePorts(type: SyntaxTree.Type; len: LONGINT);
			VAR i,len2: LONGINT; baseType: SyntaxTree.Type;
			BEGIN
				FOR i := 0 TO len-1 DO
					IF SemanticChecker.IsStaticArray(type, baseType, len2) THEN
						CreatePorts(baseType, len*len2);
					ELSIF IsSemiDynamicArray(type) THEN
						port := MIN(LONGINT); (* unknown port address from here on *)
					ELSE
						IntermediateCode.InitImmediate(op,addressType,adr);
						symbol.Emit(Data(-1,op));
						INC(port);
					END;
				END;
			END CreatePorts;
			*)

		BEGIN
			IF backend.cellsAreObjects THEN meta.CheckTypeDeclaration(x) END;
			(*
			IF (x.cellScope.ownerModule = module.module)  THEN
				td := x.typeDeclaration;
				Global.GetSymbolSegmentedName(td,name);
				(* code section for object *)
			END;
			*)
			(* unnecessary to generate space for ports: already represented as hidden variables *)
			(*
			port := 0;
			parameter := x.firstParameter;
			WHILE parameter # NIL DO
				type := parameter.type.resolved;
				Global.GetSymbolSegmentedName(parameter,name);
				symbol := implementationVisitor.NewSection(module.allSections, Sections.ConstSection,name,parameter,dump);
				IF port >= 0 THEN
					(*! could be used for optimization: query value here ???
					parameter.SetResolved(SyntaxTree.NewIntegerValue(-1, port));
					*)
				END;
				CreatePorts(type, 1); 
				IF backend.cellsAreObjects THEN
					IF IsStaticArray(parameter.type.resolved) THEN
						Error(parameter.position, "static arrays of ports are currently not implemented, please use a property (array property of port)");
					END;
				END;
				parameter := parameter.nextParameter;
			END;
			*)
			capabilities := {};
			IF HasFlag(x.modifiers, Global.StringFloatingPoint) THEN INCL(capabilities, Global.FloatingPointCapability) END;
			IF HasFlag(x.modifiers, Global.StringVector) THEN INCL(capabilities, Global.VectorCapability) END;
			backend.SetCapabilities(capabilities);
			Scope(x.cellScope);
		END VisitCellType;

		PROCEDURE VisitProcedureType(x: SyntaxTree.ProcedureType);
		BEGIN (* no code emission *)   END VisitProcedureType;

		PROCEDURE VisitEnumerationType(x: SyntaxTree.EnumerationType);
		BEGIN (* no code emission, exported enumeration type values should be included in symbol file *)
		END VisitEnumerationType;

		(* symbols *)

		PROCEDURE VisitProcedure(x: SyntaxTree.Procedure);
		BEGIN
			Procedure(x);
		END VisitProcedure;

		PROCEDURE VisitOperator(x: SyntaxTree.Operator);
		BEGIN
			Procedure(x);
		END VisitOperator;

		PROCEDURE VisitVariable(x: SyntaxTree.Variable);
		VAR name: Basic.SegmentedName; irv: IntermediateCode.Section; align, i, dim: LONGINT;
			size, addressSize: LONGINT; lastUpdated: LONGINT; imm: IntermediateCode.Operand;

			PROCEDURE SingleInitialize(CONST op: IntermediateCode.Operand; offset: LONGINT);
			BEGIN
					size := offset - lastUpdated;
					IF size > 0 THEN
						irv.Emit(Reserve(x.position,size));
					END;
					irv.Emit(Data(x.position, op));
					lastUpdated := offset + ToMemoryUnits(system, op.type.sizeInBits);
			END SingleInitialize;
			

			PROCEDURE Initialize(type: SyntaxTree.Type; initializer: SyntaxTree.Expression; offset: LONGINT);
			VAR op: Operand; baseType: SyntaxTree.Type; variable: SyntaxTree.Variable;
			BEGIN
				IF type = NIL THEN RETURN ELSE type := type.resolved END;
				WITH type: SyntaxTree.RecordType DO
					baseType := type.baseType;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
						IF baseType IS SyntaxTree.PointerType THEN 
							baseType := baseType(SyntaxTree.PointerType).pointerBase 
						END;
						Initialize(baseType,NIL, offset);
					END;
					variable := type.recordScope.firstVariable;
					WHILE variable # NIL DO
						Initialize(variable.type, variable.initializer, offset+ToMemoryUnits(system,variable.offsetInBits));
						variable := variable.nextVariable
					END;
				| type: SyntaxTree.ArrayType DO
						IF type.form = SyntaxTree.Static THEN
							baseType := type.arrayBase;
							size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
							FOR i := 0 TO type.staticLength-1 DO
								Initialize(baseType,NIL,offset+i*size);
							END;
						END;
				| type: SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Open THEN
							dim := DynamicDim(type);
							baseType := SemanticChecker.ArrayBase(type,dim);
							imm := IntermediateCode.Immediate(addressType,dim);
							SingleInitialize(imm, offset + ToMemoryUnits(system, addressType.sizeInBits)* MathDimOffset);
							IF baseType = NIL THEN size := 0 ELSE size := system.AlignedSizeOf(baseType) END;
							imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,size));
							SingleInitialize(imm, offset + ToMemoryUnits(system, addressType.sizeInBits)* MathElementSizeOffset);
							(* flags remain empty (=0) for open array *)
						ELSIF type.form = SyntaxTree.Static THEN
							baseType := type.arrayBase;
							size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
							ASSERT(type.staticLength < 1024*1024*1024);
							FOR i := 0 TO type.staticLength-1 DO
								Initialize(baseType,NIL,offset+i*size);
							END;
						END;
				ELSE 
					IF initializer # NIL THEN
						implementationVisitor.Evaluate(initializer, op);
						SingleInitialize(op.op, offset);
					END;
				END;
			END Initialize;
			
		
		BEGIN
			IF x.externalName # NIL THEN RETURN END;
			IF (currentScope IS SyntaxTree.ModuleScope) OR (currentScope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
				(* code section for variable *)
				Global.GetSymbolSegmentedName(x,name);
				irv := implementationVisitor.NewSection(module.allSections, Sections.VarSection, name,x,dump);
				irv.SetExported(IsExported(x));
				irv.SetOffset(ToMemoryUnits(system,x.offsetInBits));
				IF (currentScope IS SyntaxTree.CellScope) & IsSemiDynamicArray(x.type) THEN
					irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
					irv := implementationVisitor.NewSection(module.allSections, Sections.VarSection, name,NIL,dump);
					FOR i := 0 TO DynamicDim(x.type)-1 DO
						irv.Emit(Reserve(x.position, ToMemoryUnits(system, system.addressSize)));
					END;
				ELSE
					lastUpdated:= 0;
					Initialize(x.type, x.initializer, 0);
					size := ToMemoryUnits(system,system.SizeOf(x.type)) - lastUpdated;	
					IF size > 0 THEN
						irv.Emit(Reserve(x.position,size));
					END;
					IF ~x.fixed THEN
						align := CommonAlignment(x.alignment, ToMemoryUnits(system, system.AlignmentOf(system.variableAlignment, x.type)));
					ELSE
						align := x.alignment;
					END;
					irv.SetPositionOrAlignment(x.fixed, align);
					meta.CheckTypeDeclaration(x.type);
				END;
			ELSIF currentScope IS SyntaxTree.RecordScope THEN
			ELSIF currentScope IS SyntaxTree.ProcedureScope THEN
			END;
			(* do not call Type(x.type) here as this must already performed in the type declaration section ! *)
		END VisitVariable;

		PROCEDURE VisitParameter(x: SyntaxTree.Parameter);
		VAR name: Basic.SegmentedName; irv, irl: IntermediateCode.Section; op: Operand; dim: LONGINT;
		BEGIN
			HALT(100);
			(*
			ASSERT(currentScope.outerScope IS SyntaxTree.CellScope);
			(* code section for variable *)
			Global.GetSymbolSegmentedName(x,name);
			irv := implementationVisitor.NewSection(module.allSections, Sections.VarSection, name,x,dump);
			irv.SetPositionOrAlignment(x.fixed, x.alignment);
			(*
			irv.SetOffset(ToMemoryUnits(system,x.offsetInBits));
			*)
			IF IsSemiDynamicArray(x.type) & ~backend.cellsAreObjects THEN
				HALT(100);
				irv.Emit(Reserve(x.position, system.addressSize));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
				irl := implementationVisitor.NewSection(module.allSections, Sections.VarSection, name,x,dump);
				irl.Emit(Reserve(x.position, DynamicDim(x.type) * system.addressSize));
			ELSIF x.defaultValue = NIL THEN
				irv.Emit(Reserve(x.position,ToMemoryUnits(system,system.SizeOf(x.type))))
			ELSE
				implementationVisitor.inData := TRUE;
				implementationVisitor.Evaluate(x.defaultValue, op);
				irv.Emit(Data(x.position,op.op));
				implementationVisitor.inData := FALSE;
			END;
			meta.CheckTypeDeclaration(x.type);
			*)
		END VisitParameter;


		PROCEDURE VisitTypeDeclaration(x: SyntaxTree.TypeDeclaration);
		BEGIN
			Type(x.declaredType); (* => code in objects *)
			IF ~(x.declaredType IS SyntaxTree.QualifiedType) & (x.declaredType.resolved IS SyntaxTree.PointerType) THEN
				Type(x.declaredType.resolved(SyntaxTree.PointerType).pointerBase);
			END;
		END VisitTypeDeclaration;

		PROCEDURE VisitConstant(x: SyntaxTree.Constant);
		BEGIN
			IF (SyntaxTree.Public * x.access # {}) THEN
				implementationVisitor.VisitConstant(x);
			END;
		END VisitConstant;


		PROCEDURE Scope(x: SyntaxTree.Scope);
		VAR procedure: SyntaxTree.Procedure;
			constant: SyntaxTree.Constant;
			variable: SyntaxTree.Variable;
			prevScope: SyntaxTree.Scope;  typeDeclaration: SyntaxTree.TypeDeclaration;
		BEGIN
			prevScope := currentScope;
			currentScope := x;
			(* constants treated in implementation visitor  *)

			typeDeclaration := x.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				VisitTypeDeclaration(typeDeclaration);
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;

			variable := x.firstVariable;
			WHILE variable # NIL DO
				VisitVariable(variable);
				variable := variable.nextVariable;
			END;

			procedure := x.firstProcedure;
			WHILE procedure # NIL DO
				VisitProcedure(procedure);
				procedure := procedure.nextProcedure;
			END;

			constant := x.firstConstant;
			WHILE constant # NIL DO
				VisitConstant(constant);
				constant := constant.nextConstant;
			END;
			currentScope := prevScope;
		END Scope;

		PROCEDURE Parameters(first: SyntaxTree.Parameter);
		VAR parameter: SyntaxTree.Parameter;
		BEGIN
			parameter := first;
			WHILE parameter # NIL DO
				VisitParameter(parameter);
				parameter := parameter.nextParameter;
			END;
		END Parameters;


		PROCEDURE Procedure(x: SyntaxTree.Procedure);
		VAR scope: SyntaxTree.ProcedureScope;
			prevScope: SyntaxTree.Scope;
			inline, finalizer: BOOLEAN;
			procedureType: SyntaxTree.ProcedureType;
			pc: LONGINT;
			stackSize: LONGINT;
			name,baseObject: Basic.SegmentedName; ir: IntermediateCode.Section;
			null,size,src,dest,fp,res: IntermediateCode.Operand;
			cc: LONGINT;
			cellType: SyntaxTree.CellType;
			registerNumber: LONGINT;
			registerClass: IntermediateCode.RegisterClass;
			type: IntermediateCode.Type;
			formalParameter: SyntaxTree.Parameter;
			recordType: SyntaxTree.RecordType;
			isModuleBody: BOOLEAN;

			PROCEDURE Signature;
			VAR parameter: SyntaxTree.Parameter; procedureType: SyntaxTree.ProcedureType; returnType : SyntaxTree.Type;
			BEGIN
				procedureType := x.type(SyntaxTree.ProcedureType);
				returnType := procedureType.returnType;
				IF returnType # NIL THEN
					meta.CheckTypeDeclaration(returnType)
				END;
				parameter := procedureType.firstParameter;
				WHILE parameter # NIL DO
					meta.CheckTypeDeclaration(parameter.type); (* we have to re-export a type, i.e. it has to be present in the list of symbols *)
					parameter := parameter.nextParameter;
				END;
			END Signature;

			PROCEDURE CheckIntegerValue(x: SyntaxTree.Expression; VAR value: LONGINT): BOOLEAN;
			VAR result: BOOLEAN;
			BEGIN
				result := FALSE;
				IF x = SyntaxTree.invalidExpression THEN
				ELSIF (x.resolved # NIL) & (x.resolved IS SyntaxTree.IntegerValue) THEN
					result := TRUE;
					value := x.resolved(SyntaxTree.IntegerValue).value;
				ELSE
					Error(x.position,"expression is not an integer constant");
				END;
				RETURN result;
			END CheckIntegerValue;

			PROCEDURE HasValue(modifiers: SyntaxTree.Modifier; CONST name: ARRAY OF CHAR; VAR value: LONGINT): BOOLEAN;
			VAR this: SyntaxTree.Modifier; id: SyntaxTree.Identifier;
			BEGIN
				this := modifiers; id := SyntaxTree.NewIdentifier(name);
				WHILE (this # NIL) & (this.identifier # id) DO
					this := this.nextModifier;
				END;
				IF this # NIL THEN
					IF this.expression = NIL THEN
						Error(this.position,"expected expression value");
					ELSIF CheckIntegerValue(this.expression,value) THEN
					END;
					RETURN TRUE
				ELSE RETURN FALSE
				END;
			END HasValue;
		
			CONST DefaultDataMemorySize=512;

		BEGIN
			IF x.externalName # NIL THEN RETURN END;

			(*
			IF Trace & (dump # NIL) THEN dump.String("DeclarationVisitor:Procedure"); dump.Ln END;
			*)
			(* code section for this procedure *)
			scope := x.procedureScope;
			prevScope := currentScope;
			currentScope := scope;
			procedureType := x.type(SyntaxTree.ProcedureType);
			isModuleBody := x = module.module.moduleScope.bodyProcedure;
			implementationVisitor.temporaries.Init;
			implementationVisitor.usedRegisters := NIL;
			implementationVisitor.registerUsageCount.Init;

			implementationVisitor.GetCodeSectionNameForSymbol(x, name);
			IF (scope.body # NIL) & (x.isInline)  THEN
				inline := TRUE;
				ir := implementationVisitor.NewSection(module.allSections, Sections.InlineCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (x.scope # NIL) & (x.scope IS SyntaxTree.CellScope) & (x.scope(SyntaxTree.CellScope).ownerCell.isCellNet)
				OR (x.scope # NIL) & (x.scope IS SyntaxTree.ModuleScope) & (x.scope(SyntaxTree.ModuleScope).ownerModule.isCellNet) THEN
				IF backend.cellsAreObjects THEN
					ir := implementationVisitor.NewSection(module.allSections, Sections.CodeSection, name, x, dump);
					ir.SetExported(IsExported(x));
				ELSE
					RETURN; (* cellnet cannot be compiled for final static hardware *)
				END;
			ELSIF x = module.module.moduleScope.bodyProcedure THEN
				inline := FALSE;
				AddBodyCallStub(x);
				ir := implementationVisitor.NewSection(module.allSections, Sections.BodyCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & (x = scope.outerScope(SyntaxTree.CellScope).bodyProcedure) THEN
				inline := FALSE;
				cellType := scope.outerScope(SyntaxTree.CellScope).ownerCell;
				IF ~HasValue(cellType.modifiers,Global.StringDataMemorySize,stackSize) THEN stackSize := DefaultDataMemorySize END;
				AddBodyCallStub(x);
				AddStackAllocation(x,stackSize);
				ir := implementationVisitor.NewSection(module.allSections,Sections.BodyCodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & (x.isConstructor) THEN
				inline := FALSE;
				Parameters(procedureType.firstParameter);
				ir := implementationVisitor.NewSection(module.allSections, Sections.CodeSection, name,x,dump);
				ir.SetExported(IsExported(x));
			ELSE
				inline := FALSE;
				IF x.isEntry OR x.isExit THEN
					ir := implementationVisitor.NewSection(module.allSections, Sections.InitCodeSection, name,x,dump);
					ir.SetExported(TRUE);
					IF x.isEntry THEN ir.SetPriority(EntryPriority) ELSE ir.SetPriority(ExitPriority) END;
				ELSE
					ir := implementationVisitor.NewSection(module.allSections, Sections.CodeSection, name,x,dump);
					ir.SetExported(IsExported(x) OR SemanticChecker.InMethodTable(x));
				END;
			END;

			cc := procedureType.callingConvention;

			IF scope.body # NIL THEN
				IF implementationVisitor.emitLabels THEN ir.Emit(LabelInstruction(scope.body.position)) END;
				registerNumber := 0;
				IF ~inline THEN
					IF scope.lastVariable = NIL THEN
						stackSize := 0
					ELSE
						stackSize := scope.lastVariable.offsetInBits;
						IF stackSize <0 THEN stackSize := -stackSize END;
						Basic.Align(stackSize,system.AlignmentOf(system.parameterAlignment,system.byteType));  (* round up to parameter alignment *)
					END;
					(*
					ir.Emit(Nop(position)); (* placeholder for stack frame check *)
					ir.Emit(Nop(position)); (* placeholder for stack frame check (2) *)
					*)
					IF ~procedureType.noPAF THEN (* no procedure activation frame ! *)
						implementationVisitor.EmitEnter(ir,x.position,x,cc,ToMemoryUnits(system,stackSize),registerNumber);
					END;
					pc := ir.pc-1;
					(*
					ir.Emit(Nop(position)); (* placeholder for fill *)
					*)

					IF procedureType.callingConvention # SyntaxTree.OberonCallingConvention THEN
						formalParameter := procedureType.lastParameter;
						WHILE (formalParameter # NIL) & (registerNumber < system.registerParameters) DO
							IF ~PassInRegister(formalParameter) THEN
								Error(formalParameter.position,"Calling convention error: cannot be passed as register");
							ELSE
								IntermediateCode.InitRegisterClass(registerClass, IntermediateCode.Parameter, SHORT(registerNumber));
								type := GetType(system, formalParameter.type);
								src := IntermediateCode.Register(type, registerClass, implementationVisitor.AcquireRegister(type, registerClass));
								IntermediateCode.InitMemory(dest,GetType(system,formalParameter.type),implementationVisitor.fp,ToMemoryUnits(system,formalParameter.offsetInBits));
								ir.Emit(Mov(-1,dest, src));
								implementationVisitor.ReleaseIntermediateOperand(src);
								INC(registerNumber);
								formalParameter := formalParameter.prevParameter;
							END;
						END;
					END;
					ir.EnterValidPAF;
				END;

				implementationVisitor.tagsAvailable := procedureType.callingConvention = SyntaxTree.OberonCallingConvention;

				implementationVisitor.Body(scope.body,currentScope,ir,isModuleBody);

				IF ~inline & ~(procedureType.noPAF) & ~x.isEntry & ~x.isExit THEN
					IF scope.lastVariable # NIL THEN
						stackSize := scope.lastVariable.offsetInBits;
						IF stackSize <0 THEN stackSize := -stackSize END;
						Basic.Align(stackSize,system.AlignmentOf(system.parameterAlignment,system.byteType));  (* round up to parameter alignment *)
					END;
				END;

				IF ~inline  & ~(procedureType.noPAF) & ~x.isEntry & ~x.isExit THEN
					IF ToMemoryUnits(system,stackSize) > 4*1024-256 THEN (* stack frame potentially larger than page size *) (*! get page size from backend *)
						(*! unnecessary with new implementation of ENTER -- should potentially be called by backend
						IF implementationVisitor.GetRuntimeProcedure(implementationVisitor.runtimeModuleName,"EnsureAllocatedStack",procedure,TRUE) THEN
							size := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,stackSize+256));
							ir.EmitAt(pc,Push(size));
							implementationVisitor.StaticCallOperand(result,procedure);
							ir.EmitAt(pc+1,Call(result.op,ProcedureParametersSize(system,procedure)));
						END;
						*)
					END;


					ir.EmitAt(pc(*+2*),implementationVisitor.Enter(x.position,cc,ToMemoryUnits(system,stackSize))); (*!!*)

					IF stackSize > 0 THEN
						IF (stackSize MOD system.addressSize = 0) THEN
							null := IntermediateCode.Immediate(addressType,0);
							fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
							IntermediateCode.AddOffset(fp,ToMemoryUnits(system,-system.addressSize));
							size := IntermediateCode.Immediate(addressType,stackSize DIV system.addressSize);
						ELSE
							null := IntermediateCode.Immediate(int8,0);
							fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
							IntermediateCode.AddOffset(fp,ToMemoryUnits(system,-null.type.sizeInBits));
							size := IntermediateCode.Immediate(addressType,stackSize DIV null.type.sizeInBits);
						END;
						(*! should potentially be called by backend -- enter might initialize
						ir.EmitAt(pc+3,Fill(fp,null,size,TRUE));
						*)
					END;

					ir.ExitValidPAF;


					IF (procedureType.returnType = NIL) OR (scope.body.code # NIL)  THEN
						finalizer := FALSE;
						IF backend.cooperative & x.isFinalizer THEN
							recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
							Basic.ToSegmentedName("BaseTypes.Object", baseObject);
							GetRecordTypeName(recordType,name);
							finalizer := (name # baseObject) & (recordType.baseType = NIL);
						END;
						implementationVisitor.SetLabel(implementationVisitor.exitLabel);
						IF backend.cooperative THEN
							IF HasPointers (scope) THEN  implementationVisitor.ResetVariables(scope); END;
							IF implementationVisitor.profile  & ~isModuleBody THEN 
								implementationVisitor.ProfilerEnterExit(implementationVisitor.numberProcedures-1, FALSE) 
							END;
						END;
						implementationVisitor.EmitLeave(ir, x.position,cc);
						IF finalizer THEN
							IF backend.hasLinkRegister THEN
								ir.Emit(Pop(-1, implementationVisitor.lr));
							END;	
							Basic.ToSegmentedName("BaseTypes.Object.Finalize", name);
							IntermediateCode.InitAddress(dest, addressType, name , 0, 0);
							ir.Emit(Br(x.position,dest));
						ELSE
							ir.Emit(Exit(x.position,procedureType.pcOffset,cc));
						END;
					ELSE
						IF ~scope.body.isUnchecked & ~backend.noRuntimeChecks THEN
							implementationVisitor.EmitTrap(x.position,ReturnTrap);
						END;
						implementationVisitor.SetLabel(implementationVisitor.exitLabel);
						IF backend.cooperative THEN
							IF HasPointers (scope) THEN 
								IF ~ReturnedAsParameter(procedureType.returnType) THEN
									res := implementationVisitor.NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
									ir.Emit(Result(x.position, res));
									ir.Emit(Push(x.position, res)); 
									implementationVisitor.ResetVariables(scope); 
									IF implementationVisitor.profile  & ~isModuleBody THEN implementationVisitor.ProfilerEnterExit(implementationVisitor.numberProcedures-1, FALSE) END;
									ir.Emit(Pop(x.position, res));
									ir.Emit(Return(x.position, res));
								ELSE
									implementationVisitor.ResetVariables(scope); 
									IF implementationVisitor.profile & ~isModuleBody THEN implementationVisitor.ProfilerEnterExit(implementationVisitor.numberProcedures-1, FALSE) END;
								END;
							ELSIF  implementationVisitor.profile & ~isModuleBody THEN
								IF ~ReturnedAsParameter(procedureType.returnType) THEN
									res := implementationVisitor.NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
									ir.Emit(Result(x.position, res));
									ir.Emit(Push(x.position, res)); 
									implementationVisitor.ProfilerEnterExit(implementationVisitor.numberProcedures-1, FALSE);
									ir.Emit(Pop(x.position, res));
									ir.Emit(Return(x.position, res));
								ELSE
									implementationVisitor.ProfilerEnterExit(implementationVisitor.numberProcedures-1, FALSE);
								END;
							END;
							
							implementationVisitor.EmitLeave(ir,x.position,cc);
							ir.Emit(Exit(x.position,procedureType.pcOffset,cc));
						ELSE
							ir.Emit(Nop(x.position));
							IF scope.body.isUnchecked OR backend.noRuntimeChecks THEN (* return from procedure in any case *)
								implementationVisitor.EmitLeave(ir,x.position,cc);
								ir.Emit(Exit(x.position,procedureType.pcOffset,cc));
							END;
						END;
					END
				END;
			ELSE (* force body for procedures *)
				implementationVisitor.EmitEnter(ir, x.position,x,cc,0,0);
				ir.EnterValidPAF;
				implementationVisitor.Body(scope.body,currentScope,ir,x = module.module.moduleScope.bodyProcedure);
				IF implementationVisitor.usedRegisters # NIL THEN D.TraceBack END;
				ir.ExitValidPAF;
				implementationVisitor.EmitLeave(ir,x.position,cc);
				ir.Emit(Exit(x.position,procedureType.pcOffset,cc));
			END;
			Scope(scope);
			Signature;
			IF (x IS SyntaxTree.Operator) & x(SyntaxTree.Operator).isDynamic THEN implementationVisitor.RegisterDynamicOperator(x(SyntaxTree.Operator)) END;

			currentScope := prevScope;
		END Procedure;



		PROCEDURE AddBodyCallStub(bodyProcedure: SyntaxTree.Procedure); (* code that is only necessary for static linkers *)
		VAR procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope; name: Basic.SegmentedName;
			ir: IntermediateCode.Section; op: IntermediateCode.Operand;
		BEGIN
			ASSERT (bodyProcedure # NIL);
			procedureScope := SyntaxTree.NewProcedureScope(bodyProcedure.scope);
			procedure := SyntaxTree.NewProcedure(-1,SyntaxTree.NewIdentifier("@BodyStub"), procedureScope);
			procedure.SetScope(bodyProcedure.scope);
			procedure.SetType(SyntaxTree.NewProcedureType(-1,bodyProcedure.scope));
			procedure.SetAccess(SyntaxTree.Hidden);
			Global.GetSymbolSegmentedName (procedure,name);
			ir := implementationVisitor.NewSection(module.allSections, Sections.InitCodeSection, name,procedure,dump);
			ir.SetExported(TRUE);
			ir.SetPriority(InitPriority);
			Global.GetSymbolSegmentedName (bodyProcedure,name);
			IF (backend.newObjectFile OR backend.cooperative) & ~meta.simple THEN
				implementationVisitor.currentScope := module.module.moduleScope;
				implementationVisitor.section := ir;
				implementationVisitor.PushSelfPointer();
				implementationVisitor.CallThis(bodyProcedure.position,"Modules","Register",1);
			ELSIF backend.preregisterStatic THEN
				implementationVisitor.currentScope := module.module.moduleScope;
				implementationVisitor.section := ir;
				implementationVisitor.PushSelfPointer();
				implementationVisitor.CallThis(bodyProcedure.position,"Modules","Preregister",1);
			ELSE
				IntermediateCode.InitAddress(op, addressType, name, implementationVisitor.GetFingerprint(bodyProcedure), 0);
				ir.Emit(Call(bodyProcedure.position,op, 0));
			END;
		END AddBodyCallStub;

		PROCEDURE AddStackAllocation(symbol: SyntaxTree.Symbol; initStack: LONGINT); (* code that is only necessary for static linkers *)
		VAR name: Basic.SegmentedName;
			ir: IntermediateCode.Section; op: IntermediateCode.Operand;
		BEGIN
			Global.GetSymbolSegmentedName (symbol,name);
			Basic.RemoveSuffix(name);
			Basic.SuffixSegmentedName(name, Basic.MakeString("@StackAllocation"));
			ir := implementationVisitor.NewSection(module.allSections,Sections.InitCodeSection,name,NIL,dump);
			ir.SetExported(TRUE);
			ir.SetPriority(FirstPriority);
			IntermediateCode.InitImmediate(op,addressType,initStack);
			ir.Emit(Mov(-1,implementationVisitor.sp,op));
		END AddStackAllocation;



		(** entry function to visit a complete module *)
		PROCEDURE Module(x: SyntaxTree.Module; module: Sections.Module);
		VAR
			ir: IntermediateCode.Section; op: IntermediateCode.Operand; name: Basic.SegmentedName; idstr: SyntaxTree.IdentifierString;
			hasDynamicOperatorDeclarations: BOOLEAN;
			operator: SyntaxTree.Operator;
			import: SyntaxTree.Import;

			PROCEDURE TypeNeedsInitialization(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				type := type.resolved;
				IF type IS SyntaxTree.RecordType THEN
					IF ScopeNeedsInitialization(type(SyntaxTree.RecordType).recordScope) THEN RETURN TRUE END;
				ELSIF (type IS SyntaxTree.ArrayType) THEN
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						IF TypeNeedsInitialization(type(SyntaxTree.ArrayType).arrayBase) THEN RETURN TRUE END;
					END;
				ELSIF type IS SyntaxTree.MathArrayType THEN
					WITH type: SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Open THEN
							RETURN TRUE
						ELSIF type.form = SyntaxTree.Static THEN
							IF TypeNeedsInitialization(type.arrayBase) THEN RETURN TRUE END;
						END;
					END;
				END;
				RETURN FALSE
			END TypeNeedsInitialization;

			PROCEDURE ScopeNeedsInitialization(scope: SyntaxTree.Scope): BOOLEAN;
			VAR variable: SyntaxTree.Variable;
			BEGIN
				variable := scope.firstVariable;
				WHILE variable # NIL DO
					IF TypeNeedsInitialization(variable.type) THEN RETURN TRUE END;
					IF variable.initializer # NIL THEN RETURN TRUE END;
					variable := variable.nextVariable;
				END;
				RETURN FALSE
			END ScopeNeedsInitialization;


		BEGIN
			ASSERT(x # NIL); ASSERT(module # NIL);
			SELF.module := module;

			(* add import names to the generated Sections.Module *)
			import := x.moduleScope.firstImport;
			WHILE import # NIL DO
				import.module.GetName(idstr);
				module.imports.AddName(idstr);
				import := import.nextImport
			END;

			IF ~implementationVisitor.newObjectFile & ~meta.simple THEN
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@moduleSelf"));
				moduleSelf := SyntaxTree.NewVariable(0,SyntaxTree.NewIdentifier("@moduleSelf"));
				moduleSelf.SetType(system.anyType);
				moduleSelf.SetScope(x.moduleScope);
				moduleSelf.SetUntraced(TRUE);
				ir := implementationVisitor.NewSection(module.allSections, Sections.ConstSection, name,moduleSelf,dump);  ir.SetOffset(0);
				ir.SetExported(TRUE);
				IntermediateCode.InitImmediate(op,addressType,0);
				ir.Emit(Data(-1,op));
			END;

			implementationVisitor.module := module;
			implementationVisitor.moduleScope := x.moduleScope;
			implementationVisitor.moduleSelf := moduleSelf;
			implementationVisitor.canBeLoaded := TRUE;
			meta.SetModule(module);

			IF (forceModuleBody OR implementationVisitor.newObjectFile  & ~meta.simple  OR ScopeNeedsInitialization(x.moduleScope)) THEN
				EnsureBodyProcedure(x.moduleScope); (* currently needed in Oberon, remove ? *)
			END;

			IF backend.profile THEN
				EnsureBodyProcedure(x.moduleScope);
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@ModuleId"));
				implementationVisitor.profileId := implementationVisitor.NewSection(module.allSections, Sections.VarSection, name,NIL,dump);
				implementationVisitor.profileId.Emit(Reserve(-1,ToMemoryUnits(system,system.SizeOf(system.longintType))));
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@InitProfiler"));
				implementationVisitor.profileInit := implementationVisitor.NewSection(module.allSections, Sections.CodeSection, name,NIL,dump);
				implementationVisitor.EmitEnter(implementationVisitor.profileInit,-1,NIL,0,0,0);

				Global.GetModuleName(module.module,idstr);
				implementationVisitor.ProfilerAddModule(idstr);
				implementationVisitor.numberProcedures := 0;
			END;
			implementationVisitor.profile := backend.profile;

			(* check if there is at least one dynamic operator locally defined *)
			hasDynamicOperatorDeclarations := FALSE;
			operator := x.moduleScope.firstOperator;
			WHILE operator # NIL DO
				IF operator.isDynamic THEN hasDynamicOperatorDeclarations := TRUE END;
				operator := operator.nextOperator
			END;

			(* add operator initialization code section *)
			IF hasDynamicOperatorDeclarations THEN
				EnsureBodyProcedure(x.moduleScope);
				Global.GetModuleSegmentedName(module.module,name); Basic.SuffixSegmentedName(name, Basic.MakeString("@OperatorInitialization"));
				implementationVisitor.operatorInitializationCodeSection := implementationVisitor.NewSection(module.allSections, Sections.CodeSection,name, NIL, dump);
				implementationVisitor.EmitEnter(implementationVisitor.operatorInitializationCodeSection,-1,NIL,0,0,0);
			END;

			Scope(x.moduleScope);

			IF hasDynamicOperatorDeclarations THEN
				implementationVisitor.EmitLeave(implementationVisitor.operatorInitializationCodeSection,-1,0);
				implementationVisitor.operatorInitializationCodeSection.Emit(Exit(-1,0,0));
			END;

			IF backend.profile THEN
				implementationVisitor.ProfilerPatchInit;
			END;

		END Module;

	END DeclarationVisitor;

	UsedArray*=POINTER TO ARRAY OF RECORD count: LONGINT; map: LONGINT; type: IntermediateCode.Type; class: IntermediateCode.RegisterClass END;

	RegisterUsageCount*=OBJECT
	VAR used: UsedArray; count: LONGINT;

		PROCEDURE &Init;
		VAR i: LONGINT;
		BEGIN
			count := 0;
			IF used = NIL THEN NEW(used,64); END;
			FOR i := 0 TO LEN(used)-1 DO used[i].count := 0; used[i].map := i END;
		END Init;

		PROCEDURE Grow;
		VAR new: UsedArray; size,i: LONGINT;
		BEGIN
			size := LEN(used)*2;
			NEW(new,size);
			FOR i := 0 TO LEN(used)-1 DO
				new[i].count := used[i].count;
				new[i].type := used[i].type;
				new[i].map := used[i].map
			END;
			FOR i := LEN(used) TO LEN(new)-1 DO new[i].count := 0 END;
			used := new
		END Grow;

		PROCEDURE Next(type: IntermediateCode.Type; class: IntermediateCode.RegisterClass): LONGINT;
		BEGIN
			INC(count);
			IF count = LEN(used) THEN Grow END;
			used[count].type := type;
			used[count].class := class;
			used[count].map := count;
			RETURN count;
		END Next;

		PROCEDURE IncUse(register: LONGINT);
		BEGIN
			INC(used[register].count);
			(*
			IF (register = 1) & (count > 30)  THEN
				D.TraceBack;
			END;
			*)
		END IncUse;

		PROCEDURE DecUse(register: LONGINT);
		BEGIN
			DEC(used[register].count);
		END DecUse;

		PROCEDURE Map(register: LONGINT): LONGINT;
		VAR map : LONGINT;
		BEGIN
			IF register > 0 THEN
				map := used[register].map;
				WHILE register # map DO register := map; map := used[register].map END;
			END;
			RETURN register
		END Map;

		PROCEDURE Use(register: LONGINT): LONGINT;
		BEGIN
			IF register< LEN(used) THEN
				RETURN used[register].count
			ELSE
				RETURN 0
			END
		END Use;

	END RegisterUsageCount;

	RegisterEntry = POINTER TO RECORD
		prev,next: RegisterEntry;
		register: LONGINT;
		registerClass: IntermediateCode.RegisterClass;
		type: IntermediateCode.Type;
	END;

	VariableUse= ARRAY 32 OF SET; (* upper bound of 1024 temporary variables in a procedure .. should be enough for all times *)

	Variables = OBJECT (Basic.List)
	VAR
		inUse: VariableUse;
		registerIndex: LONGINT;

		PROCEDURE & Init;
		VAR i: LONGINT;
		BEGIN
			InitList(16);
			FOR i := 0 TO LEN(inUse)-1 DO inUse[i] := {} END;
			registerIndex := 1024;
		END Init;

		PROCEDURE GetUsage(VAR use: VariableUse);
		BEGIN
			use := inUse;
		END GetUsage;

		PROCEDURE SetUsage(CONST use: VariableUse);
		BEGIN
			inUse := use;
		END SetUsage;

		PROCEDURE GetVariable(i: LONGINT): SyntaxTree.Variable;
		VAR any: ANY;
		BEGIN
			any := Get(i);;
			IF any = NIL THEN RETURN NIL ELSE RETURN any(SyntaxTree.Variable) END;
		END GetVariable;

		PROCEDURE Occupy(pos: LONGINT);
		BEGIN
			INCL(inUse[pos DIV 32], pos MOD 32);
		END Occupy;

		PROCEDURE AddVariable(v: SyntaxTree.Variable);
		BEGIN
			Occupy(Length());
			Add(v);
		END AddVariable;

		PROCEDURE GetFreeVariable(type: SyntaxTree.Type; VAR pos: LONGINT): SyntaxTree.Variable;
		VAR var : SyntaxTree.Variable;
		BEGIN
			FOR pos := 0 TO Length()-1 DO
				IF ~((pos MOD 32) IN inUse[pos DIV 32]) THEN
					var := GetVariable(pos);
					IF type.SameType(var.type) THEN
						Occupy(pos); RETURN var
					END;
				END;
			END;
			pos := Length();
			RETURN NIL
		END GetFreeVariable;

	END Variables;

	SymbolMap = POINTER TO RECORD this: SyntaxTree.Symbol; to, tag: SyntaxTree.Expression; next: SymbolMap; END;

	SymbolMapper = OBJECT
	VAR
		first: SymbolMap;

		PROCEDURE & Init;
		BEGIN
			first := NIL;
		END Init;

		PROCEDURE Add(this: SyntaxTree.Symbol; to, tag: SyntaxTree.Expression);
		VAR new: SymbolMap;
		BEGIN
			NEW(new); new.this := this; new.to := to; new.tag := tag;
			new.next := first;	first := new;
		END Add;

		PROCEDURE Get(this: SyntaxTree.Symbol): SymbolMap;
		VAR s: SymbolMap;
		BEGIN
			s := first;
			WHILE (s # NIL) & (s.this # this) DO
				s := s.next
			END;
			RETURN s
		END Get;

	END SymbolMapper;


	ImplementationVisitor =OBJECT(SyntaxTree.Visitor)
	VAR
		system: Global.System;
		section: IntermediateCode.Section;
		module: Sections.Module;
		moduleScope : SyntaxTree.ModuleScope; (* shortcut for module.module.moduleScope *)
		awaitProcCounter, labelId, constId, caseId: LONGINT;

		hiddenPointerType: SyntaxTree.RecordType; (* used as hidden pointer, for example for ARRAY OF ANY *)
		delegatePointerType: SyntaxTree.RecordType; (* used for delegates, for example in ARRAY OF PROCEDURE{DELEGATE} *)

		checker: SemanticChecker.Checker;
		backend: IntermediateBackend;
		meta: MetaDataGenerator;
		position: LONGINT;
		moduleSelf: SyntaxTree.Variable;
		(* variables for hand over of variables /  temporary state *)
		currentScope: SyntaxTree.Scope;
		constantDeclaration : SyntaxTree.Symbol;
		result: Operand; (* result of the most recent expression / statement *)
		destination: IntermediateCode.Operand;

		arrayDestinationTag: IntermediateCode.Operand;
		arrayDestinationDimension:LONGINT;

		currentLoop: Label; (* variable to hand over loop exit jump list *)
		conditional: BOOLEAN;
		trueLabel, falseLabel, exitLabel: Label;
		locked: BOOLEAN;
		(*
		usedRegisters: Registers;
		*)
		registerUsageCount: RegisterUsageCount;
		usedRegisters: RegisterEntry;
		
		

		(* useful operands and types *)
		nil,fp,sp,ap,lr,true,false: IntermediateCode.Operand;
		bool,addressType,setType, sizeType, byteType: IntermediateCode.Type;

		commentPrintout: Printout.Printer;
		dump: Streams.Writer;
		tagsAvailable : BOOLEAN;
		supportedInstruction: SupportedInstructionProcedure;
		supportedImmediate: SupportedImmediateProcedure;
		inData: BOOLEAN;  (* to prevent indirect reference to data within data sections, cf. VisitIntegerValue *)
		emitLabels: BOOLEAN;
		runtimeModuleName : SyntaxTree.IdentifierString;
		newObjectFile: BOOLEAN;
		indexCounter: LONGINT;

		profile: BOOLEAN;
		profileId, profileInit: IntermediateCode.Section;
		profileInitPatchPosition: LONGINT;
		numberProcedures: LONGINT;
		procedureResultDesignator : SyntaxTree.Designator;
		operatorInitializationCodeSection: IntermediateCode.Section;
		fingerPrinter: FingerPrinter.FingerPrinter;

		temporaries: Variables;
		canBeLoaded : BOOLEAN;

		currentIsInline: BOOLEAN;
		currentMapper: SymbolMapper;
		currentInlineExit: Label;

		moduleBodySection: IntermediateCode.Section;
		NeedDescriptor : BOOLEAN;

		cooperativeSwitches: BOOLEAN;
		lastSwitchPC: LONGINT;

		isUnchecked: BOOLEAN;
	
		
		PROCEDURE & Init(system: Global.System; checker: SemanticChecker.Checker; supportedInstructionProcedure: SupportedInstructionProcedure; supportedImmediateProcedure: SupportedImmediateProcedure; emitLabels: BOOLEAN; CONST runtime: SyntaxTree.IdentifierString; backend: IntermediateBackend;
			newObjectFile: BOOLEAN);
		BEGIN
			SELF.system := system;
			SELF.runtimeModuleName := runtime;

			currentScope := NIL;
			hiddenPointerType := NIL;
			delegatePointerType := NIL;

			awaitProcCounter := 0;
			labelId := 0; constId := 0; labelId := 0;
			SELF.checker := checker;
			SELF.backend := backend;
			position := Diagnostics.Invalid;
			conditional := FALSE;
			locked := FALSE;
			InitOperand(result,ModeUndefined);
			addressType := IntermediateCode.GetType(system,system.addressType);
			setType := IntermediateCode.GetType(system,system.setType);
			sizeType := IntermediateCode.GetType(system, system.sizeType);
			byteType := IntermediateCode.GetType(system, system.byteType);
			
			fp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.FP);
			sp := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.SP);
			ap := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.AP);
			lr := IntermediateCode.Register(addressType,IntermediateCode.GeneralPurposeRegister,IntermediateCode.LR);
			nil := IntermediateCode.Immediate(addressType,0);

			IntermediateCode.InitOperand(destination);
			tagsAvailable := TRUE;
			supportedInstruction := supportedInstructionProcedure;
			supportedImmediate := supportedImmediateProcedure;
			inData := FALSE;

			SELF.emitLabels := emitLabels;
			IntermediateCode.InitOperand(arrayDestinationTag);

			bool := IntermediateCode.GetType(system,system.booleanType);
			IntermediateCode.InitImmediate(false,bool,0);
			IntermediateCode.InitImmediate(true,bool,1);

			SELF.newObjectFile := newObjectFile;
			indexCounter := 0;
			NEW(registerUsageCount);
			usedRegisters := NIL;
			procedureResultDesignator := NIL;
			NEW(fingerPrinter, system);
			NEW(temporaries);
			currentIsInline := FALSE;
			NeedDescriptor := FALSE;
			isUnchecked := backend.noRuntimeChecks;
		END Init;
		
		TYPE Context = RECORD 
			section: IntermediateCode.Section;
			registerUsageCount: RegisterUsageCount;
			usedRegisters: RegisterEntry;
			END;
		
		PROCEDURE SwitchContext(new: IntermediateCode.Section): Context;
		VAR context: Context;
		BEGIN
			context.section := section;
			context.registerUsageCount := registerUsageCount;
			context.usedRegisters := usedRegisters;
			section := new;
			NEW(registerUsageCount);
			usedRegisters := NIL; 
			RETURN context;
		END SwitchContext;

		PROCEDURE ReturnToContext(context: Context);
		BEGIN
			section := context.section;
			registerUsageCount := context.registerUsageCount;
			usedRegisters := context.usedRegisters;
		END ReturnToContext;

		PROCEDURE NewSection(list: Sections.SectionList; type: SHORTINT; CONST name: Basic.SegmentedName; syntaxTreeSymbol: SyntaxTree.Symbol; dump: BOOLEAN): IntermediateCode.Section;
		VAR fp: SyntaxTree.FingerPrint; section: IntermediateCode.Section;
		BEGIN
			IF (syntaxTreeSymbol # NIL) & ~((syntaxTreeSymbol IS SyntaxTree.Procedure) & (syntaxTreeSymbol(SyntaxTree.Procedure).isInline)) THEN
				fp := fingerPrinter.SymbolFP(syntaxTreeSymbol)
			END;
			section := IntermediateCode.NewSection(list, type, name, syntaxTreeSymbol, dump);
			section.SetExported(IsExported(syntaxTreeSymbol));
			RETURN section
		END NewSection;

		PROCEDURE AcquireRegister(CONST type: IntermediateCode.Type; class: IntermediateCode.RegisterClass): LONGINT;
		VAR new: LONGINT;
		BEGIN
			new :=  registerUsageCount.Next(type,class);
			UseRegister(new);
			RETURN new
		END AcquireRegister;

		(** get the name for the code section that represens a certain symbol
		(essentially the same as Global.GetSymbolName, apart from operators) **)
		PROCEDURE GetCodeSectionNameForSymbol(symbol: SyntaxTree.Symbol; VAR name: Basic.SegmentedName);
		VAR
			operatorFingerPrint: SyntaxTree.FingerPrint;
			operatorFingerPrintString,string: ARRAY 32 OF CHAR;
		BEGIN
			Global.GetSymbolSegmentedName(symbol, name);
			(* if the symbol is an operator, then append the fingerprint to the name *)
			IF symbol IS SyntaxTree.Operator THEN
				operatorFingerPrint := fingerPrinter.SymbolFP(symbol);
				string := "[";
				Strings.IntToHexStr(operatorFingerPrint.shallow, 8, operatorFingerPrintString);
				Strings.Append(string, operatorFingerPrintString);
				Strings.Append(string, "]");
				Basic.AppendToSegmentedName(name,string);
			END
		END GetCodeSectionNameForSymbol;

		PROCEDURE TraceEnter(CONST s: ARRAY OF CHAR);
		BEGIN
			IF dump # NIL THEN
				dump.String("enter "); dump.String(s); dump.Ln;
			END;
		END TraceEnter;

		PROCEDURE TraceExit(CONST s: ARRAY OF CHAR);
		BEGIN
			IF dump # NIL THEN
				dump.String("exit "); dump.String(s); dump.Ln;
			END;
		END TraceExit;


		PROCEDURE Emit(instruction: IntermediateCode.Instruction);
		VAR moduleName, procedureName: SyntaxTree.IdentifierString;

			PROCEDURE CheckRegister(VAR op: IntermediateCode.Operand);
			VAR i: LONGINT;
			BEGIN
				IF op.register >0 THEN IntermediateCode.SetRegister(op,registerUsageCount.Map(op.register)) END;
				IF op.rule # NIL THEN
					FOR i := 0 TO LEN(op.rule)-1 DO
						CheckRegister(op.rule[i])
					END;
				END;

			END CheckRegister;

		BEGIN
			CheckRegister(instruction.op1);
			CheckRegister(instruction.op2);
			CheckRegister(instruction.op3);

			IF supportedInstruction(instruction,moduleName,procedureName) THEN section.Emit(instruction)
			ELSE section.Emit(instruction);
				EnsureSymbol(moduleName,procedureName); (* remainder for binary object file *)
			END;
		END Emit;
		
		PROCEDURE EmitTrap (position, trapNo: LONGINT);
		BEGIN
			IF backend.cooperative THEN
				Emit(Push(position,IntermediateCode.Immediate(sizeType,trapNo)));
				CallThis(position,DefaultRuntimeModuleName,"Trap",1); 
			ELSE
				Emit(Trap(position,trapNo));
			END;
		END EmitTrap;

		PROCEDURE EmitEnter (section: IntermediateCode.Section; position: LONGINT; procedure: SyntaxTree.Procedure; callconv: LONGINT; varSize: LONGINT; numRegs: LONGINT);
		VAR name: Basic.SegmentedName;
		VAR op1, op2, reg: IntermediateCode.Operand;
		VAR call, nocall: Label;
		VAR parametersSize: LONGINT;
		VAR prevSection: IntermediateCode.Section;
		VAR prevDump: Streams.Writer;
		VAR body: SyntaxTree.Body;
		BEGIN
			ASSERT((procedure = NIL) OR ~procedure.type(SyntaxTree.ProcedureType).noPAF);
			prevSection := SELF.section;
			SELF.section := section;
			prevDump := dump;
			dump := section.comments;
			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;
			Emit(Push(-1,fp));
			
			IF backend.cooperative & (callconv = SyntaxTree.OberonCallingConvention) THEN
				IF (procedure # NIL) & (HasPointers (procedure.procedureScope) OR HasVariableParameters (procedure.procedureScope) OR IsNested (procedure)) THEN
					GetCodeSectionNameForSymbol(procedure, name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Descriptor"));
				ELSE
					Basic.ToSegmentedName ("BaseTypes.StackFrame",name);
				END;
				IntermediateCode.InitAddress(op1, addressType, name , 0, 0);
				Emit(Push(-1,op1));
				Emit(Mov(-1,fp, sp));
				body := procedure.procedureScope.body;
				IF (body # NIL) & (body.code = NIL) & ~procedure.procedureScope.body.isUnchecked THEN
					NEW(call, section);
					NEW(nocall, section);
					reg := NewRegisterOperand(addressType);
					IntermediateCode.InitImmediate(op1,addressType, varSize);
					Emit(Sub(-1,reg, sp, op1));
					BrltL(call, sp, reg);
					IntermediateCode.InitMemory(op2, addressType,ap,ToMemoryUnits(system,system.addressSize*10));
					BrgeL(nocall, sp, op2);
					call.Resolve(section.pc);
					parametersSize := ProcedureParametersSize(backend.system,procedure);
					IntermediateCode.InitImmediate(op2,addressType, parametersSize);
					Emit(Push(-1, op2));
					Emit(Push(-1, reg));
					ReleaseIntermediateOperand(reg);
					CallThis(position, "Activities","ExpandStack",2);
					Emit(Result(-1, sp));
					nocall.Resolve(section.pc);
				END;
			ELSE
				Emit(Mov(-1, fp, sp));
			END;
			Emit(Enter(-1, callconv, varSize));
			SELF.section := prevSection;
			dump := prevDump;
		END EmitEnter;
		
		PROCEDURE Enter(position: LONGINT; callconv: LONGINT; varSize: LONGINT): IntermediateCode.Instruction;
		VAR op1,op2: IntermediateCode.Operand;
		VAR instruction: IntermediateCode.Instruction;
		BEGIN
			IntermediateCode.InitNumber(op1,callconv);
			IntermediateCode.InitNumber(op2,varSize);
			IntermediateCode.InitInstruction(instruction, position, IntermediateCode.enter,op1,op2,emptyOperand);
			RETURN instruction
		END Enter;

		PROCEDURE Leave(position: LONGINT; callconv: LONGINT): IntermediateCode.Instruction;
		VAR op1: IntermediateCode.Operand;
		VAR instruction: IntermediateCode.Instruction;
		BEGIN
			IntermediateCode.InitNumber(op1,callconv);
			IntermediateCode.InitInstruction(instruction, position, IntermediateCode.leave,op1,emptyOperand,emptyOperand);
			RETURN instruction
		END Leave;
		
		PROCEDURE EmitLeave(section: IntermediateCode.Section; position: LONGINT; callconv: LONGINT);
		VAR prevSection: IntermediateCode.Section;
		VAR op2: IntermediateCode.Operand;
		BEGIN
			prevSection := SELF.section;
			SELF.section := section;
			Emit(Leave(position, callconv)); 
			IF backend.cooperative THEN
				IntermediateCode.InitImmediate(op2,addressType, ToMemoryUnits(system, system.addressSize));
				Emit(Add(position, sp, fp, op2));
			ELSE
				Emit(Mov(position, sp, fp));
			END;
			Emit(Pop(position, fp));
			SELF.section := prevSection;
		END EmitLeave;

		PROCEDURE Symbol(x: SyntaxTree.Symbol; VAR op: Operand);
		VAR m: SymbolMap; 
		BEGIN
			position := x.position;
			IF currentIsInline THEN
				m  := currentMapper.Get(x);
				IF m # NIL THEN
					(*
					Printout.Info("mapping from", x);
					Printout.Info("mapping to ", m.to);
					*)
					m.to.Accept(SELF);
					op := result;
					IF m.tag # NIL THEN
						ReleaseIntermediateOperand(result.tag);
						m.tag.Accept(SELF);
						op.tag := result.op;
						ReleaseIntermediateOperand(result.tag);
					END;
					RETURN
				END;
			END;
			x.Accept(SELF);
			op := result;
		END Symbol;

		PROCEDURE Expression(x: SyntaxTree.Expression);
		BEGIN
			position := x.position;
			constantDeclaration := NIL;
			IF (x IS SyntaxTree.SymbolDesignator) & (x(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Constant) THEN
				constantDeclaration := x(SyntaxTree.SymbolDesignator).symbol;
			END;
			IF x.resolved # NIL THEN
				x.resolved.Accept(SELF)
			ELSE
				x.Accept(SELF)
			END;
			(* check this, was commented out in ActiveCells3 *)
			IF (x IS SyntaxTree.Designator) & (x(SyntaxTree.Designator).modifiers # NIL) & ~backend.cellsAreObjects THEN
				Error(x.position, "unsupported modifier");
			END;
		END Expression;

		(*
		PROCEDURE ResetUsedTemporaries(previous: VariableUse);
		VAR current: VariableUse; set: SET; i,j: LONGINT; variable: SyntaxTree.Variable; op: Operand; tmp: IntermediateCode.Operand;
		BEGIN
			temporaries.GetUsage(current);
			FOR i := 0 TO LEN(current)-1 DO
				set := current[i] - previous[i];
				IF set # {} THEN
					FOR j := 0 TO MAX(SET)-1 DO
						IF j IN set THEN
							variable := temporaries.GetVariable(i*MAX(SET)+j);
							IF (variable.type.resolved IS SyntaxTree.MathArrayType) & (variable.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) THEN
								Symbol(variable, op);
								MakeMemory(tmp,op.op,addressType,0);
								ReleaseOperand(op);
								Emit(Mov(position,tmp, nil ) );
								ReleaseIntermediateOperand(tmp);
							END;
						END;
					END;
				END;
			END;

		END ResetUsedTemporaries;
		*)

		PROCEDURE Statement(x: SyntaxTree.Statement);
		VAR use: VariableUse;
		BEGIN
			temporaries.GetUsage(use);
			position := x.position;
			IF emitLabels THEN Emit(LabelInstruction(x.position)) END;
			IF commentPrintout # NIL THEN
				commentPrintout.Statement(x);
				dump.Ln;
				(*dump.Update;*)
			END;
			x.Accept(SELF);
			(*
			CheckRegistersFree();
			*)
			(*ResetUsedTemporaries(use);*)
			temporaries.SetUsage(use);
		END Statement;

		(* dereference op. If op is already a memory operand then use auxiliary register to dereference
			result will be registered as a new use of operand, op is not released (op must be released by caller)
		*)
		PROCEDURE MakeMemory(VAR res: IntermediateCode.Operand; op: IntermediateCode.Operand; type: IntermediateCode.Type; offset: LONGINT);
		BEGIN

			IF op.mode = IntermediateCode.ModeMemory THEN
				ReuseCopy(res,op);
			ELSE
				res := op;
				UseIntermediateOperand(res);
			END;
			IntermediateCode.AddOffset(res,offset);

			IntermediateCode.MakeMemory(res,type);
		END MakeMemory;

		PROCEDURE ToMemory(VAR res: IntermediateCode.Operand; type: IntermediateCode.Type; offset: LONGINT);
		VAR mem: IntermediateCode.Operand;
		BEGIN
			MakeMemory(mem,res,type,offset);
			ReleaseIntermediateOperand(res);
			res := mem;
		END ToMemory;

		PROCEDURE LoadValue(VAR operand: Operand; type: SyntaxTree.Type);
		VAR mem: IntermediateCode.Operand;
			firstOp, lastOp, stepOp: IntermediateCode.Operand;
			componentType: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			IF operand.mode = ModeReference THEN
				IF type IS SyntaxTree.RangeType THEN
					MakeMemory(firstOp, operand.op, IntermediateCode.GetType(system, system.longintType), 0);
					MakeMemory(lastOp, operand.op, IntermediateCode.GetType(system, system.longintType), ToMemoryUnits(system, system.SizeOf(system.longintType)));
					MakeMemory(stepOp, operand.op, IntermediateCode.GetType(system, system.longintType), 2 * ToMemoryUnits(system, system.SizeOf(system.longintType)));
					ReleaseOperand(operand);
					operand.op := firstOp;
					operand.tag := lastOp;
					operand.extra := stepOp;
				ELSIF type IS SyntaxTree.ComplexType THEN
					componentType := type(SyntaxTree.ComplexType).componentType;
					ASSERT((componentType.SameType(system.realType)) OR (componentType.SameType(system.longrealType)));
					MakeMemory(firstOp, operand.op, IntermediateCode.GetType(system, componentType), 0);
					MakeMemory(lastOp, operand.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
					ReleaseOperand(operand);
					operand.op := firstOp;
					operand.tag := lastOp
				ELSE
					MakeMemory(mem,operand.op,IntermediateCode.GetType(system,type),0);
					ReleaseIntermediateOperand(operand.op);
					operand.op := mem;
				END;
				operand.mode := ModeValue;
			END;
			ASSERT(operand.mode = ModeValue);
		END LoadValue;

		PROCEDURE Evaluate(x: SyntaxTree.Expression; VAR op: Operand);
		VAR prevConditional: BOOLEAN;
		BEGIN
			prevConditional := conditional;
			conditional := FALSE;
			InitOperand(result, ModeUndefined);
			Expression(x);
			op := result;
			LoadValue(op,x.type.resolved);
			conditional := prevConditional;
		END Evaluate;

		PROCEDURE Designate(x: SyntaxTree.Expression; VAR op: Operand);
		VAR prevConditional: BOOLEAN;
		BEGIN
			prevConditional := conditional;
			conditional := FALSE;
			InitOperand(result,ModeUndefined);
			Expression(x);
			op := result;
		(*
			ASSERT((op.mode = ModeReference) OR (x.type.resolved IS SyntaxTree.NilType)); (* special case: winapi NIL parameter on references *)
		*)
			conditional := prevConditional;
		END Designate;

		PROCEDURE Condition(x: SyntaxTree.Expression; trueL,falseL: Label);
		VAR prevTrue, prevFalse: Label; prevConditional: BOOLEAN;
		BEGIN
			ASSERT(trueL # NIL); ASSERT(falseL # NIL);
			prevTrue := trueLabel; prevFalse := falseLabel; prevConditional := conditional;
			conditional := TRUE;
			trueLabel := trueL; falseLabel := falseL;
			Expression(x);
			trueL := trueLabel; falseL := falseLabel;
			trueLabel := prevTrue;falseLabel := prevFalse;conditional := prevConditional;
		END Condition;

		PROCEDURE NewRegisterOperand(type: IntermediateCode.Type): IntermediateCode.Operand;
		VAR op: IntermediateCode.Operand; reg: LONGINT;
		BEGIN
			reg := AcquireRegister(type,IntermediateCode.GeneralPurposeRegister);
			IntermediateCode.InitRegister(op, type, IntermediateCode.GeneralPurposeRegister,reg);
			RETURN op
		END NewRegisterOperand;

		PROCEDURE UnuseRegister(register: LONGINT);
		BEGIN
			IF (register > 0) THEN
				register := registerUsageCount.Map(register);
				registerUsageCount.DecUse(register);
				IF TraceRegisterUsageCount & (dump# NIL) THEN
					dump.String("unuse register "); dump.Int(register,1); dump.String(": ");dump.Int(registerUsageCount.Use(register),1); dump.Ln; dump.Update;
				END;
				IF registerUsageCount.Use(register)=0 THEN
					IF ~RemoveRegisterEntry(usedRegisters,register) THEN
						Warning(position, "register cannot be removed");
					END;
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("remove register from usedRegisters"); dump.Ln; dump.Update;
					END;
				ELSIF registerUsageCount.Use(register)<0 THEN
					Warning(position, "register removed too often");
					IF dump # NIL THEN
						dump.String("register removed too often"); dump.Ln; dump.Update;
					END;
					D.TraceBack;
				END;
			END;
		END UnuseRegister;

		PROCEDURE UseRegister(register: LONGINT);
		BEGIN
			IF (register > 0) THEN
				register := registerUsageCount.Map(register);

				registerUsageCount.IncUse(register);
				IF TraceRegisterUsageCount & (dump# NIL) THEN
					dump.String("use register "); dump.Int(register,1); dump.String(": ");dump.Int(registerUsageCount.Use(register),1); dump.Ln; dump.Update;
				END;
				IF registerUsageCount.Use(register)=1 THEN
					AddRegisterEntry(usedRegisters,register, registerUsageCount.used[register].class, registerUsageCount.used[register].type);
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("add register to usedRegisters"); dump.Ln; dump.Update;
					END;
				END;
			END;
		END UseRegister;

		PROCEDURE ReleaseIntermediateOperand(CONST op: IntermediateCode.Operand);
		BEGIN
			UnuseRegister(op.register)
		END ReleaseIntermediateOperand;

		PROCEDURE UseIntermediateOperand(CONST op: IntermediateCode.Operand);
		BEGIN
			UseRegister(op.register)
		END UseIntermediateOperand;

		PROCEDURE ReleaseOperand(CONST op: Operand);
		BEGIN
			UnuseRegister(op.op.register);
			UnuseRegister(op.tag.register);
			UnuseRegister(op.extra.register);
		END ReleaseOperand;

		(* save registers marked in array "markedRegisters" to the stack
			remove entries from array "markedRegisters" and save to array "saved" (=> recursion possible)
		*)
		PROCEDURE SaveRegisters();
		VAR op: IntermediateCode.Operand; entry: RegisterEntry; type: IntermediateCode.Type;
		BEGIN
			entry := usedRegisters;
			WHILE entry # NIL DO
				type := registerUsageCount.used[entry.register].type;
				IntermediateCode.InitRegister(op,entry.type,entry.registerClass, entry.register);
				Emit(Push(position,op));
				entry := entry.next;
			END;
		END SaveRegisters;

		PROCEDURE ReleaseUsedRegisters(VAR saved: RegisterEntry);
		BEGIN
			saved := usedRegisters;
			usedRegisters := NIL;
		END ReleaseUsedRegisters;

		(** remove parameter registers from used queue *)
		PROCEDURE ReleaseParameterRegisters;
		VAR entry,prev,next: RegisterEntry;
		BEGIN
			entry := usedRegisters; prev := NIL; usedRegisters := NIL;
			WHILE entry # NIL DO
				next := entry.next;
				IF entry.registerClass.class = IntermediateCode.Parameter THEN
					registerUsageCount.DecUse(entry.register);
					ASSERT(registerUsageCount.Use(entry.register)=0);
					IF TraceRegisterUsageCount & (dump# NIL) THEN
						dump.String("unuse register "); dump.Int(entry.register,1); dump.Ln; dump.Update;
					END;
				ELSIF prev = NIL THEN
					usedRegisters := entry; entry.prev := NIL; entry.next := NIL; prev := entry;
				ELSE
					prev.next := entry; entry.prev := prev; entry.next := NIL; prev:= entry;
				END;
				entry := next;
			END;
		END ReleaseParameterRegisters;

		(* restore registers from array saved and re-enter into array markedRegisters (recursion possible) *)
		PROCEDURE RestoreRegisters(CONST saved: RegisterEntry);
		VAR op: IntermediateCode.Operand; entry,prev: RegisterEntry; type: IntermediateCode.Type; class: IntermediateCode.RegisterClass;
		BEGIN
			entry := saved;
			WHILE (entry # NIL) DO prev := entry; entry := entry.next END;
			entry := prev;
			WHILE entry # NIL DO
				prev := entry.prev;
				type := entry.type;
				class := entry.registerClass;
				IntermediateCode.InitRegister(op,type,class,entry.register);
				(*
				new := registerUsageCount.Next(type,class);
				registerUsageCount.Remap(entry.register,new);
				IF TraceRegisterUsageCount & (dump# NIL) THEN
					dump.String("remap register "); dump.Int(entry.register,1);
					dump.String("to "); dump.Int(new,1);
					dump.String("with count "); dump.Int(registerUsageCount.Use(new),1); dump.Ln; dump.Update;
				END;
				entry.register := new;
				*)
				
				Emit(Pop(position,op));
				AddRegisterEntry(usedRegisters,entry.register,entry.registerClass, entry.type);
				entry := prev;
			END;
			(*
			usedRegisters := saved;
			*)
		END RestoreRegisters;

		PROCEDURE CheckRegistersFree;
		VAR r: RegisterEntry; warning: ARRAY 128 OF CHAR; i: LONGINT;
		BEGIN
			IF usedRegisters # NIL THEN
				r := usedRegisters;
				WHILE r # NIL DO
					warning := "register ";
					Strings.AppendInt(warning, r.register);
					Strings.Append(warning, " not released.");
					Warning(position,warning);
					r := r .next;
				END;
			END;
			FOR i := 0 TO registerUsageCount.count-1 DO
				IF registerUsageCount.used[i].count < 0 THEN
					warning := "register ";
					Strings.AppendInt(warning, i);
					Strings.Append(warning, " unused too often.");
					Warning(position,warning);
				ELSIF registerUsageCount.used[i].count > 0 THEN (* should always coincide with cases above *)
					warning := "register ";
					Strings.AppendInt(warning, i);
					Strings.Append(warning, " not unused often enough.");
					Warning(position,warning);
				END;
			END;
		END CheckRegistersFree;


		(* Reuse2: reuse src1 or src2 for ongoing computation if src1 or src2, respectively, is a register.
			Otherwise allocate a new register.
			Does NOT necessarily keep the content of src1 or src2 in result! *)
		PROCEDURE Reuse2(VAR result: IntermediateCode.Operand; src1,src2: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF ReusableRegister(src2) THEN IntermediateCode.InitRegister(result,src2.type,src2.registerClass, src2.register);
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass,AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse2;

		(* Reuse2a: reuse src1 or src2 for ongoing computation if src1 or src2, respectively, is a register.
			Otherwise check if an alternative destination is available. If so, then take the alternative (which is not necessarily a register).
			If not then allocate a new register.
			Does NOT necessarily keep the content of src1 or src2 in result!
		*)
		PROCEDURE Reuse2a(VAR result: IntermediateCode.Operand; src1,src2: IntermediateCode.Operand; VAR alternative: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF ReusableRegister(src2) THEN IntermediateCode.InitRegister(result,src2.type,src2.registerClass, src2.register);
				UseIntermediateOperand(result);
			ELSIF alternative.mode # IntermediateCode.Undefined THEN
				result := alternative; alternative := emptyOperand;
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse2a;

		(* like reuse2 but only one source *)
		PROCEDURE Reuse1(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse1;

		(* like reuse2a but only one source *)
		PROCEDURE Reuse1a(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand; VAR alternative: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				UseIntermediateOperand(result);
			ELSIF alternative.mode # IntermediateCode.Undefined THEN result := alternative; alternative := emptyOperand;
				UseIntermediateOperand(result);
			ELSE IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
			END;
		END Reuse1a;

		(* like reuse1 but guarantees that content of src1 is in result *)
		PROCEDURE ReuseCopy(VAR result: IntermediateCode.Operand; src1: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src1) THEN
				IntermediateCode.InitRegister(result,src1.type,src1.registerClass, src1.register);
				ASSERT((src1.mode = IntermediateCode.ModeRegister) & (src1.offset = 0));
				UseIntermediateOperand(result);
			ELSE
				IntermediateCode.InitRegister(result,src1.type,src1.registerClass, AcquireRegister(src1.type, src1.registerClass));
				Emit(Mov(position,result,src1));
			END
		END ReuseCopy;

		PROCEDURE TransferToRegister(VAR result: IntermediateCode.Operand; src: IntermediateCode.Operand);
		BEGIN
			IF ReusableRegister(src) THEN
				IntermediateCode.InitRegister(result,src.type,src.registerClass, src.register);
			ELSE
				IntermediateCode.InitRegister(result,src.type,src.registerClass, AcquireRegister(src.type, src.registerClass));
				Emit(Mov(position,result,src));
				ReleaseIntermediateOperand(src);
			END
		END TransferToRegister;


		(** labels and branches **)
		PROCEDURE NewLabel(): Label;
		VAR label: Label;
		BEGIN
			NEW(label,section); RETURN label;
		END NewLabel;

		PROCEDURE SetLabel(label: Label);
		BEGIN label.Resolve(section.pc);
		END SetLabel;

		PROCEDURE LabelOperand(label: Label): IntermediateCode.Operand;
		BEGIN
			ASSERT(label # NIL);
			IF label.pc < 0 THEN (* label not yet set *)
				label.AddFixup(section.pc);
			END;
			RETURN IntermediateCode.Address(addressType,label.section.name,GetFingerprint(label.section.symbol), label.pc);
		END LabelOperand;

		PROCEDURE BrL(label: Label);
		BEGIN
			Emit(Br(position,LabelOperand(label)));
		END BrL;

		PROCEDURE BrgeL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brge(position,LabelOperand(label),left,right));
		END BrgeL;

		PROCEDURE BrltL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brlt(position,LabelOperand(label),left,right));
		END BrltL;

		PROCEDURE BreqL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Breq(position,LabelOperand(label),left,right));
		END BreqL;

		PROCEDURE BrneL(label: Label; left,right: IntermediateCode.Operand);
		BEGIN
			Emit(Brne(position,LabelOperand(label),left,right));
		END BrneL;

		PROCEDURE Convert(VAR operand: IntermediateCode.Operand; type: IntermediateCode.Type);
		VAR new: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("Convert") END;
			IF IntermediateCode.TypeEquals(type,operand.type) THEN (* nothing to be done *)
			ELSIF (operand.mode = IntermediateCode.ModeRegister) THEN
				IF (type.sizeInBits = operand.type.sizeInBits) & (type.form IN IntermediateCode.Integer) & (operand.type.form IN IntermediateCode.Integer)
					& (operand.offset = 0)
				THEN
					IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,operand.register);
					Emit(Conv(position,new,operand));
				ELSE
					IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(type,IntermediateCode.GeneralPurposeRegister));
					Emit(Conv(position,new,operand));
					ReleaseIntermediateOperand(operand);
				END;
				operand := new;
			ELSIF (operand.mode = IntermediateCode.ModeImmediate) & (operand.symbol.name = "") & (operand.type.sizeInBits <= type.sizeInBits) & (operand.type.form IN IntermediateCode.Integer) & (type.form IN IntermediateCode.Integer) THEN
				IntermediateCode.InitImmediate(operand,type,operand.intValue);
			ELSE
				IntermediateCode.InitRegister(new,type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(type,IntermediateCode.GeneralPurposeRegister));
				Emit(Conv(position,new,operand));
				ReleaseIntermediateOperand(operand);
				operand := new;
			END;
			IF Trace THEN TraceExit("Convert") END;
		END Convert;

		PROCEDURE TrapC(br: ConditionalBranch; left,right:IntermediateCode.Operand; trapNo: LONGINT);
		VAR exit: Label;
		BEGIN
			Assert((left.mode # IntermediateCode.ModeImmediate) OR (right.mode # IntermediateCode.ModeImmediate),"trap emission with two immediates");
			exit := NewLabel();
			br(exit,left,right);
			EmitTrap(position,trapNo);
			SetLabel(exit);
		END TrapC;

		(** expressions *)

		(** emit necessary runtime check for set elements **)
		PROCEDURE CheckSetElement(o: IntermediateCode.Operand);
		VAR max: IntermediateCode.Operand;
		BEGIN
			IF isUnchecked THEN RETURN END;
			IF o.mode # IntermediateCode.ModeImmediate THEN (* otherwise it's the job of the checker *)
				IntermediateCode.InitImmediate(max, setType, setType.sizeInBits (* number of bits in set *) -1);
				TrapC(BrgeL, max, o, SetElementTrap);
			END;
		END CheckSetElement;

		(** the set that a range represents **)
		PROCEDURE SetFromRange(x: SyntaxTree.RangeExpression): IntermediateCode.Operand;
		VAR
			operand: Operand;
			resultingSet, temp, size, allBits, noBits, one: IntermediateCode.Operand;
		BEGIN
			ASSERT((x.first # NIL) & (x.last # NIL)); (* ensured by the checker *)

			allBits := IntermediateCode.Immediate(setType, -1);  (* bit mask 111...11111 *)
			noBits := IntermediateCode.Immediate(setType, 0);  (* bit mask 0...0 *)
			one := IntermediateCode.Immediate(setType, 1);

			Evaluate(x, operand);

			Convert(operand.op, setType);
			Convert(operand.tag, setType);

			CheckSetElement(operand.op);
			CheckSetElement(operand.tag);

			(* create mask for lower bound
				i.e. shift 11111111 to the left by the value of the lower bound
			*)
			Reuse1(temp, operand.op);
			Emit(Shl(position,temp, allBits, operand.op));
			ReleaseIntermediateOperand(operand.op);
			operand.op := temp;

			(* create mask for upper bound
				i.e. shift 11111111 to the right by the difference between the
				upper bound and the maximum number of set elements
			*)
			IF (operand.tag.mode = IntermediateCode.ModeImmediate) & (operand.tag.symbol.name = "") THEN
				IntermediateCode.InitImmediate(operand.tag, operand.tag.type, operand.op.type.sizeInBits - 1- operand.tag.intValue);
				Reuse1(temp, operand.tag);
			ELSE
				Reuse1(temp, operand.tag);
				IntermediateCode.InitImmediate(size, operand.tag.type, operand.op.type.sizeInBits - 1);
				Emit(Sub(position,temp, size, operand.tag));
			END;
			Emit(Shr(position,temp, allBits, operand.tag));
			ReleaseIntermediateOperand(operand.tag);
			operand.tag := temp;

			Reuse2(resultingSet, operand.op, operand.tag);

			(* intersect the two masks *)
			Emit(And(position,resultingSet, operand.op, operand.tag));

			ReleaseOperand(operand);

			RETURN resultingSet
		END SetFromRange;

		PROCEDURE VisitSet(x: SyntaxTree.Set);
		VAR
			res, operand: Operand;
			temp, one, noBits, dest: IntermediateCode.Operand;
			expression: SyntaxTree.Expression;
			i: LONGINT;

		BEGIN
			IF Trace THEN TraceEnter("VisitSet") END;

			dest := destination;
			destination := emptyOperand;

			noBits := IntermediateCode.Immediate(setType, 0);
			one := IntermediateCode.Immediate(setType, 1);

			(* start off with the empty set *)
			InitOperand(res, ModeValue);
			IntermediateCode.InitRegister(res.op, setType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(setType, IntermediateCode.GeneralPurposeRegister));
			Emit(Mov(position,res.op, noBits));

			FOR i := 0 TO x.elements.Length() - 1 DO
				expression := x.elements.GetExpression(i);

				IF expression IS SyntaxTree.RangeExpression THEN
					(* range of set elements *)
					temp := SetFromRange(expression(SyntaxTree.RangeExpression));
					ASSERT(IntermediateCode.TypeEquals(setType, temp.type));
					Emit(Or(position,res.op, res.op, temp)); (* unify subset with current set *)
					ReleaseIntermediateOperand(temp)
				ELSE
					(* singelton element *)
					Evaluate(expression, operand);
					Convert(operand.op, setType);
					CheckSetElement(operand.op);

					(* create subset containing single element *)
					Reuse1(temp, operand.op);
					Emit(Shl(position,temp, one, operand.op));
					ReleaseOperand(operand);

					Emit(Or(position,res.op, res.op, temp)); (* unify subset with current set *)
					ReleaseIntermediateOperand(temp);
				END
			END;

			result := res;
			destination := dest;

			IF Trace THEN TraceExit("VisitSet") END;
		END VisitSet;

		PROCEDURE VisitMathArrayExpression(x: SyntaxTree.MathArrayExpression);
		VAR variable: SyntaxTree.Variable; index: SyntaxTree.IndexDesignator; dim: LONGINT;
			designator: SyntaxTree.Designator; i: LONGINT; element: SyntaxTree.IntegerValue;

			PROCEDURE RecursiveAssignment(x: SyntaxTree.MathArrayExpression; dim: LONGINT);
			VAR numberElements,i: LONGINT; expression: SyntaxTree.Expression;
				element: SyntaxTree.IntegerValue;
			BEGIN
				numberElements := x.elements.Length();
				expression := index.parameters.GetExpression(dim);
				element := expression(SyntaxTree.IntegerValue);
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					element.SetValue(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursiveAssignment(expression(SyntaxTree.MathArrayExpression),dim+1);
					ELSE
						Assign(index,expression);
					END;
				END;
			END RecursiveAssignment;

		BEGIN
			variable := GetTemporaryVariable(x.type, FALSE);
			designator := SyntaxTree.NewSymbolDesignator(-1,NIL,variable);
			designator.SetType(variable.type);
			dim := SemanticChecker.Dimension(x.type,{SyntaxTree.Static});
			index := SyntaxTree.NewIndexDesignator(x.position,designator);
			FOR i := 0 TO dim-1 DO
				element := SyntaxTree.NewIntegerValue(x.position,0);
				element.SetType(system.longintType);
				index.parameters.AddExpression(element);
			END;
			index.SetType(SemanticChecker.ArrayBase(x.type,dim));
			RecursiveAssignment(x,0);
			Expression(designator);
		END VisitMathArrayExpression;


		PROCEDURE VisitUnaryExpression(x: SyntaxTree.UnaryExpression);
		VAR type,t0: SyntaxTree.Type; operand: Operand; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitUnaryExpression") END;
			dest := destination; destination := emptyOperand;
			IF x.operator = Scanner.Not THEN
				IF conditional THEN
					Condition(x.left,falseLabel,trueLabel)
				ELSE
					Evaluate(x.left,operand);
					InitOperand(result,ModeValue);
					Reuse1a(result.op,operand.op,dest);
					Emit(Xor(position,result.op,operand.op,true));
					ReleaseOperand(operand);
				END;
			ELSIF x.operator = Scanner.Minus THEN
				Evaluate(x.left,operand);
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				type := x.left.type.resolved;
				IF type IS SyntaxTree.SetType THEN
					Emit(Not(position,result.op,operand.op));
				ELSIF (type IS SyntaxTree.ComplexType) THEN
					Reuse1(result.tag,operand.tag);
					Emit(Neg(position,result.op,operand.op)); (* real part *)
					Emit(Neg(position,result.tag,operand.tag)) (* imaginary part *)
				ELSIF (type IS SyntaxTree.NumberType) OR (type IS SyntaxTree.SizeType) OR (type IS SyntaxTree.AddressType) THEN
					Emit(Neg(position,result.op,operand.op));
				ELSE HALT(200)
				END;
				ReleaseOperand(operand);
			ELSIF x.operator = Scanner.Address THEN
				Designate(x.left,operand);
				operand.mode := ModeValue;
				t0 := x.left.type.resolved;
				IF (t0 IS SyntaxTree.MathArrayType) & (t0(SyntaxTree.MathArrayType).form = SyntaxTree.Open) THEN
					ReleaseIntermediateOperand(operand.op);
					operand.op := operand.tag;
					IntermediateCode.InitOperand(operand.tag);
				END;
				Convert(operand.op,IntermediateCode.GetType(system,x.type));
				result := operand;
			ELSE HALT(100)
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitUnaryExpression") END;
		END VisitUnaryExpression;

		(* test if e is of type type, side effect: result of evaluation of e stays in the operand *)
		PROCEDURE TypeTest(tag: IntermediateCode.Operand; type: SyntaxTree.Type; trueL,falseL: Label);
		VAR left,right: IntermediateCode.Operand; level,offset: LONGINT; repeatL: Label; originalType: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			originalType := type;
			IF type IS SyntaxTree.PointerType THEN
				type := type(SyntaxTree.PointerType).pointerBase.resolved;
			END;
			IF type IS SyntaxTree.ObjectType THEN
				BrL(trueL);
			ELSE

				ASSERT(type IS SyntaxTree.RecordType);

				(*
				IntermediateCode.MakeMemory(tag,addressType); (*! already done during generation *)
				*)
				ReuseCopy(left,tag);
				right := TypeDescriptorAdr(type);
				IF ~newObjectFile THEN
					IntermediateCode.MakeMemory(right,addressType);
				END;
				
				IF backend.cooperative THEN
		 			repeatL := NewLabel();
		 			IF (originalType IS SyntaxTree.PointerType) & ~type(SyntaxTree.RecordType).isObject THEN
						Emit(Mov(position,left,IntermediateCode.Memory(addressType,left,ToMemoryUnits(system,addressType.sizeInBits))));
					END;
		 			SetLabel(repeatL);
					BreqL(trueL,left,right);
					Emit(Mov(position,left,IntermediateCode.Memory(addressType,left,0)));
					BrneL(repeatL,left,nil);
				ELSIF meta.simple THEN
					level := type(SyntaxTree.RecordType).Level();
					(* get type desc tag of level relative to base tag *)
					offset := (meta.BaseTypesTableOffset + level) * addressType.sizeInBits;
					IntermediateCode.AddOffset(left,ToMemoryUnits(system,offset));
					IntermediateCode.MakeMemory(left,addressType);
					BreqL(trueL,left,right);
				ELSE
					level := type(SyntaxTree.RecordType).Level();
					(* get type desc tag of level relative to base tag *)
					offset := (meta.BaseTypesTableOffset - level) * addressType.sizeInBits;
					IntermediateCode.AddOffset(left,ToMemoryUnits(system,offset));
					IntermediateCode.MakeMemory(left,addressType);
					BreqL(trueL,left,right);
				END;
				ReleaseIntermediateOperand(left); ReleaseIntermediateOperand(right);
				BrL(falseL);
			END;
		END TypeTest;

		PROCEDURE Error(position: LONGINT; CONST s: ARRAY OF CHAR);
		BEGIN
			backend.Error(module.module.sourceName,position,Diagnostics.Invalid,s);
			IF dump # NIL THEN
				dump.String(s); dump.Ln;
			END;
		END Error;

		PROCEDURE Warning(position: LONGINT; CONST s: ARRAY OF CHAR);
		BEGIN
			backend.diagnostics.Warning(module.module.sourceName,position,Diagnostics.Invalid,s);
			IF dump # NIL THEN
				dump.String(s); dump.Ln; dump.Update;
			END;
		END Warning;

		PROCEDURE CreateTraceModuleMethod(mod: SyntaxTree.Module);
		VAR name: Basic.SectionName; pooledName: Basic.SegmentedName; previousSection: IntermediateCode.Section;
		VAR variable: SyntaxTree.Variable; register,op: IntermediateCode.Operand; 
			operand:Operand; 
		BEGIN
			previousSection := section;
			Global.GetModuleName(mod,name);
			Strings.Append(name,".@Trace");
			Basic.ToSegmentedName(name, pooledName);
			section := IntermediateCode.NewSection(module.allSections, Sections.CodeSection, pooledName,NIL,TRUE);
			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;

			variable := mod.moduleScope.firstVariable;
			WHILE variable # NIL DO
				IF ~variable.untraced & variable.type.resolved.hasPointers THEN
					Symbol(variable, operand);
					register := operand.op;
					CallTraceMethod(register, variable.type);
					ReleaseIntermediateOperand(register);
				END;
				variable := variable.nextVariable;
			END;

			IF backend.hasLinkRegister THEN
				Emit(Pop(-1, lr));
			END;
			Basic.ToSegmentedName ("Modules.Module.@Trace",pooledName);
			IntermediateCode.InitAddress(op, addressType, pooledName , 0, 0);
			Emit(Br(position,op));
			INC(statCoopTraceModule, section.pc);
			section := previousSection;
			IF dump # NIL THEN dump := section.comments END;

		END CreateTraceModuleMethod;

		PROCEDURE CallAssignPointer(CONST dst (* address *) , src (* value *): IntermediateCode.Operand);
		BEGIN
			Emit (Push(position, dst));
			Emit (Push(position, src));
			CallThis(position,"GarbageCollector","Assign", 2);
		END CallAssignPointer;

		PROCEDURE CallAssignMethod(CONST dst (* address *) , src (* address *) : IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR name: Basic.SegmentedName; size: LONGINT; base: SyntaxTree.Type; op: IntermediateCode.Operand;
		BEGIN
			IF SemanticChecker.IsPointerType (type) THEN
				CallAssignPointer(dst, IntermediateCode.Memory (addressType,src,0));
			ELSIF type.IsRecordType() THEN
				Emit (Push(position,dst));
				Emit (Push(position,src));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, 2*system.addressSize)));
			ELSIF IsStaticArray(type) THEN
				size := StaticArrayNumElements(type);
				base := StaticArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));					
					Emit (Push(position, dst));
					Emit (Push(position, src));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position,op,ToMemoryUnits(system, 3*system.addressSize)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, dst));
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, src));
					CallThis(position,"GarbageCollector","AssignDelegateArray", 4);
				ELSE 
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, dst));
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, src));
					CallThis(position,"GarbageCollector","AssignPointerArray", 4);
					ASSERT(StaticArrayBaseType(type).IsPointer());
				END;
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				ASSERT(type.resolved(SyntaxTree.ProcedureType).isDelegate);
				Emit (Push(position, dst));
				Emit (Push(position, src));
				CallThis(position,"GarbageCollector","AssignDelegate", 2);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallAssignMethod;
		
		PROCEDURE CreateAssignProcedure (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName; 
		VAR variable: SyntaxTree.Variable; src, dst, op, ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType; 
			parameter1, parameter2, parameter0: IntermediateCode.Operand; label: Label; 
			context: Context;
		BEGIN
			parameter0 (* len *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,3*addressType.sizeInBits));
			parameter1 (* dest *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter2 (* src *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));
			
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
			context := SwitchContext(IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE));

			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;

			
			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN

					dst := NewRegisterOperand (addressType);
					src := NewRegisterOperand (addressType);
					Emit (Mov(position, dst, parameter1));
					Emit (Mov(position, src, parameter2));

					IntermediateCode.AddOffset(dst,ToMemoryUnits(system,variable.offsetInBits));
					IntermediateCode.AddOffset(src,ToMemoryUnits(system,variable.offsetInBits));
					CallAssignMethod(dst, src, variable.type);
					ReleaseIntermediateOperand(src);
					ReleaseIntermediateOperand(dst);
				END;
				variable := variable.nextVariable;
			END;
			
			recordBase := recordType.GetBaseRecord();
			IF (recordBase # NIL) & recordBase.NeedsTrace() THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(-1, lr));
				END;				
				GetRecordTypeName (recordBase,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSE
				Emit(Exit(position,0,0));
			END;
			
			IF ~recordType.isObject THEN
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				section := IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE);
				NEW(registerUsageCount);
				usedRegisters := NIL;

				dst := NewRegisterOperand (addressType);
				src := NewRegisterOperand (addressType);
				ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
				Emit(Mov(position, dst, parameter1));
				Emit(Mov(position, src, parameter2));
				label := NewLabel(); 
				SetLabel(label);
				Emit(Push(position, dst));
				Emit(Push(position, src)); 
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position, op, 0));
				Emit(Pop(position, src));
				Emit(Pop(position, dst));
				Emit(Add(position, dst, dst, ofs));
				Emit(Add(position, src, src, ofs));
				Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
				BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
				Emit(Exit(position,0,0));
			END;
			INC(statCoopAssignProcedure, section.pc);
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateAssignProcedure;
		
		PROCEDURE CallTraceMethod(CONST register: IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR name: Basic.SegmentedName; op: IntermediateCode.Operand; size: LONGINT; base: SyntaxTree.Type; skip: Label;
		BEGIN
			IF IsUnsafePointer (type) THEN
				skip := NewLabel();
				IntermediateCode.InitRegister(op, addressType, IntermediateCode.GeneralPurposeRegister, register.register);
				Emit (Mov (position, op, IntermediateCode.Memory (addressType,register,0)));
				BreqL (skip, op, nil);
				CallTraceMethod (op,type.resolved(SyntaxTree.PointerType).pointerBase);
				SetLabel (skip);
			ELSIF SemanticChecker.IsPointerType (type) THEN
				Emit (Push(position, IntermediateCode.Memory (addressType,register,0)));
				CallThis(position,"GarbageCollector","Mark", 1);
			ELSIF type.IsRecordType() THEN
				Emit (Push(position,register));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
			ELSIF IsStaticArray(type) THEN
				size := StaticArrayNumElements(type);
				base := StaticArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType), name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position, op, ToMemoryUnits(system, system.addressSize*2)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					CallThis(position,"GarbageCollector","MarkDelegateArray", 2);
				ELSE 
					Emit (Push(position, IntermediateCode.Immediate (sizeType,size)));
					Emit (Push(position, register));
					CallThis(position,"GarbageCollector","MarkPointerArray", 2);
					ASSERT(base.IsPointer());
				END;
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				Emit (Push(position, IntermediateCode.Memory (addressType,register,ToMemoryUnits(system,addressType.sizeInBits))));
				CallThis(position,"GarbageCollector","Mark", 1);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallTraceMethod;
		
		PROCEDURE CreateTraceMethod (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName; previousSection: IntermediateCode.Section;
		VAR variable: SyntaxTree.Variable; register,op,ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType; 
			parameter0, parameter1: IntermediateCode.Operand; label: Label; context: Context;
		BEGIN
			previousSection := section;
			parameter0 (* size *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter1 (* address *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
			context := SwitchContext(IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE));
			IF dump # NIL THEN dump := section.comments END;

			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;

			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN
					register := NewRegisterOperand (addressType);
					Emit (Mov(position,register,parameter1));
					IntermediateCode.AddOffset(register,ToMemoryUnits(system,variable.offsetInBits));
					IF recordType.isObject & ((recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain) THEN
						IntermediateCode.AddOffset(register,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
					CallTraceMethod(register, variable.type);
					ReleaseIntermediateOperand(register);
				END;
				variable := variable.nextVariable;
			END;
			
			recordBase := recordType.GetBaseRecord();
			WHILE (recordBase # NIL) & ~recordBase.hasPointers DO
				recordBase := recordBase.GetBaseRecord();
			END;			
			IF recordBase # NIL THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(-1, lr));
				END;	
				GetRecordTypeName (recordBase,name);
				IF HasExplicitTraceMethod (recordBase) THEN
					Basic.SuffixSegmentedName (name, Basic.MakeString ("Trace"));
				ELSE
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				END;
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSIF (recordType.pointerType # NIL) & recordType.pointerType.isPlain THEN
				Emit(Exit(position,0,0));
			ELSE
				IF backend.hasLinkRegister THEN
					Emit(Pop(-1, lr));
				END;
				IF recordType.isObject THEN
					Basic.ToSegmentedName ("BaseTypes.Object",name);
				ELSE								
					Basic.ToSegmentedName ("BaseTypes.Record",name);
				END;
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			END;

			IF ~recordType.isObject THEN
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				section := IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE);
				NEW(registerUsageCount);
				usedRegisters := NIL;
				IF dump # NIL THEN dump := section.comments END;
				
				register := NewRegisterOperand (addressType);
				Emit (Mov(position,register,IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,addressType.sizeInBits))));
				IF (recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain THEN
					IntermediateCode.AddOffset(register,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;

				Emit (Push(position,register));
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
				ReleaseIntermediateOperand(register);
				Emit(Exit(position,0,0));
				
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				section := IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE);
				NEW(registerUsageCount);
				usedRegisters := NIL;

				register := NewRegisterOperand (addressType);
				ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
				Emit(Mov(position, register, parameter1));
				label := NewLabel(); 
				SetLabel(label);
				Emit(Push(position, register)); 
				GetRecordTypeName (recordType,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position, op, 0));
				Emit(Pop(position, register));
				Emit(Add(position, register, register, ofs));
				Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
				BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
				Emit(Exit(position,0,0));
			END;
			INC(statCoopTraceMethod, section.pc);

			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateTraceMethod;

		PROCEDURE CreateResetProcedure (recordType: SyntaxTree.RecordType);
		VAR name: Basic.SegmentedName; 
		VAR variable: SyntaxTree.Variable; dst, op, ofs: IntermediateCode.Operand; recordBase: SyntaxTree.RecordType; 
			parameter1, parameter0: IntermediateCode.Operand; label: Label; 
			context: Context;
		BEGIN
			IF recordType.isObject THEN RETURN END;
			parameter0 (* len *) := IntermediateCode.Memory(sizeType,sp,ToMemoryUnits(system,2*addressType.sizeInBits));
			parameter1 (* dest *) := IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,1*addressType.sizeInBits));
			
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			context := SwitchContext(IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE));

			IF dump # NIL THEN dump := section.comments END;

			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;

			variable := recordType.recordScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN
					dst := NewRegisterOperand (addressType);
					Emit (Mov(position, dst, parameter1));
					IntermediateCode.AddOffset(dst,ToMemoryUnits(system,variable.offsetInBits));
					IF recordType.isObject & ((recordType.pointerType = NIL) OR ~recordType.pointerType.isPlain) THEN
						IntermediateCode.AddOffset(dst,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
					CallResetProcedure(dst, nil, variable.type);
					ReleaseIntermediateOperand(dst);
				END;
				variable := variable.nextVariable;
			END;
			
			recordBase := recordType.GetBaseRecord();
			IF (recordBase # NIL) & recordBase.NeedsTrace() THEN
				IF backend.hasLinkRegister THEN
					Emit(Pop(-1, lr));
				END;
				GetRecordTypeName (recordBase,name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Br(position,op));
			ELSE
				Emit(Exit(position,0,0));
			END;
			
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			section := IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE);
			NEW(registerUsageCount);
			usedRegisters := NIL;

			dst := NewRegisterOperand (addressType);
			ofs := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(recordType)));
			Emit(Mov(position, dst, parameter1));
			label := NewLabel(); 
			SetLabel(label);
			Emit(Push(position, dst));
			GetRecordTypeName (recordType,name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Call(position, op, 0));
			Emit(Pop(position, dst));
			Emit(Add(position, dst, dst, ofs));
			Emit(Sub(position, parameter0, parameter0, IntermediateCode.Immediate(sizeType, 1)));
			BrneL(label, parameter0, IntermediateCode.Immediate(sizeType, 0));
			Emit(Exit(position,0,0));
			INC(statCoopResetProcedure, section.pc);

			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateResetProcedure;
		
		PROCEDURE CreateResetMethod (scope: SyntaxTree.ProcedureScope);
		VAR name: Basic.SegmentedName; context: Context;
		BEGIN
			GetCodeSectionNameForSymbol(scope.ownerProcedure, name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			context := SwitchContext(IntermediateCode.NewSection(module.allSections, Sections.CodeSection, name,NIL,TRUE));
			IF dump # NIL THEN dump := section.comments END;
			IF backend.hasLinkRegister THEN
				Emit(Push(-1, lr));
			END;
			Emit(Push(position,fp));
			Emit(Mov(position,fp, IntermediateCode.Memory(addressType,sp,ToMemoryUnits(system,addressType.sizeInBits * 2))));
			ResetVariables(scope);
			Emit(Pop(position,fp));
			Emit(Exit(position,0,0));
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateResetMethod;

		PROCEDURE CallResetProcedure(dest, tag: IntermediateCode.Operand; type: SyntaxTree.Type);
		VAR base: SyntaxTree.Type; op, size: IntermediateCode.Operand; name: Basic.SegmentedName;
		BEGIN
			IF SemanticChecker.IsPointerType (type) THEN
				Emit (Push(position, dest));
				CallThis(position,"GarbageCollector","Reset", 1);
			ELSIF type.IsRecordType() THEN
				Emit (Push(position, dest));
				GetRecordTypeName (type.resolved(SyntaxTree.RecordType),name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
				IntermediateCode.InitAddress(op, addressType, name , 0, 0);
				Emit(Call(position,op, ToMemoryUnits(system, system.addressSize)));
			ELSIF type.resolved IS SyntaxTree.ArrayType THEN
				size := GetArrayLength(type, tag);
				base := ArrayBaseType(type);
				IF base.IsRecordType() THEN
					Emit (Push(position, size));					
					Emit (Push(position, dest));
					GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
					Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
					IntermediateCode.InitAddress(op, addressType, name , 0, 0);
					Emit(Call(position,op,ToMemoryUnits(system, 2*system.addressSize)));
				ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
					Emit (Push(position, size));
					Emit (Push(position, dest));
					CallThis(position,"GarbageCollector","ResetDelegateArray", 2);
				ELSE 
					Emit (Push(position, size));
					Emit (Push(position, dest));
					CallThis(position,"GarbageCollector","ResetArray", 2);
					ASSERT(ArrayBaseType(type).IsPointer());
				END;
				ReleaseIntermediateOperand(size);
			ELSIF type.resolved IS SyntaxTree.ProcedureType THEN
				ASSERT(type.resolved(SyntaxTree.ProcedureType).isDelegate);
				Emit (Push(position, dest));
				CallThis(position,"GarbageCollector","ResetDelegate", 1);
			ELSE HALT(100); (* missing ? *)
			END;
		END CallResetProcedure;
		

		PROCEDURE ResetVariables (scope: SyntaxTree.ProcedureScope);
		VAR variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter; previousScope: SyntaxTree.Scope;   pc: LONGINT;

			PROCEDURE Reset (symbol: SyntaxTree.Symbol);
			VAR operand: Operand;
			BEGIN
				Symbol (symbol, operand);
				CallResetProcedure(operand.op, operand.tag, symbol.type.resolved);
				ReleaseOperand(operand);
			END Reset;

		BEGIN
			previousScope := currentScope;
			currentScope := scope;
			pc := section.pc;
			variable := scope.firstVariable;
			WHILE variable # NIL DO
				IF variable.NeedsTrace() THEN
					Reset (variable);
				END;
				variable := variable.nextVariable;
			END;
			parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
			WHILE parameter # NIL DO
				IF parameter.NeedsTrace() & ~IsVariableParameter(parameter) THEN
					Reset (parameter);
				END;
				parameter := parameter.nextParameter;
			END;
				INC(statCoopResetVariables, section.pc - pc); 
				currentScope := previousScope;
		END ResetVariables;
		
		PROCEDURE CreateProcedureDescriptor (procedure: SyntaxTree.Procedure);
		VAR previousSection: IntermediateCode.Section; name: Basic.SegmentedName;
		VAR op: IntermediateCode.Operand; context: Context;
		BEGIN
			previousSection := section;
			GetCodeSectionNameForSymbol(procedure, name);
			Basic.SuffixSegmentedName (name, Basic.MakeString ("@Descriptor"));
			context := SwitchContext(IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,NIL,TRUE));
			IF dump # NIL THEN dump := section.comments END;
			Basic.ToSegmentedName ("BaseTypes.StackFrame",name);

			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Data(position,op));
			Emit(Data(position,nil));

			IF HasPointers (procedure.procedureScope) THEN
				GetCodeSectionNameForSymbol(procedure, name);
				Basic.SuffixSegmentedName (name, Basic.MakeString ("@Reset"));
			ELSE
				Basic.ToSegmentedName ("BaseTypes.StackFrame.Reset",name);
			END;
			IntermediateCode.InitAddress(op, addressType, name , 0, 0);
			Emit(Data(position,op));
			ReturnToContext(context);
			IF dump # NIL THEN dump := section.comments END;
		END CreateProcedureDescriptor;

		PROCEDURE AddImport(CONST moduleName: ARRAY OF CHAR; VAR module: SyntaxTree.Module; force: BOOLEAN): BOOLEAN;
		VAR import: SyntaxTree.Import;
			s: Basic.MessageString;
			selfName: SyntaxTree.IdentifierString;
		BEGIN
			moduleScope.ownerModule.GetName(selfName);
			IF (moduleName = selfName) & (moduleScope.ownerModule.context = Global.A2Name) THEN
				module := moduleScope.ownerModule
			ELSE
				import := moduleScope.ImportByModuleName(SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier("A2"));



				IF import = NIL THEN
					import := SyntaxTree.NewImport(-1,SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier(moduleName),FALSE);

					import.SetContext(SyntaxTree.NewIdentifier("A2"));
					IF ~checker.AddImport(moduleScope.ownerModule,import) THEN
						s := "Module ";
						Strings.Append(s,moduleName);
						Strings.Append(s," cannot be imported.");
						IF force THEN
							Error(position,s);
						ELSIF canBeLoaded THEN
							Strings.Append(s, "=> no dynamic linking.");
							Warning(position, s);
							canBeLoaded := FALSE;
						END;
						RETURN FALSE
					ELSE
						SELF.module.imports.AddName(moduleName)
					END;
				ELSIF import.module = NIL THEN (* already tried *)
					RETURN FALSE
				END;
				module := import.module;
			END;
			RETURN TRUE
		END AddImport;

		(* needed for old binary object file format*)
		PROCEDURE EnsureSymbol(CONST moduleName,procedureName: SyntaxTree.IdentifierString);
		VAR r: Operand; procedure: SyntaxTree.Procedure; module: SyntaxTree.Module; s: ARRAY 128 OF CHAR; fp: LONGINT;
		BEGIN
			IF AddImport(moduleName,module,TRUE) THEN
				procedure := module.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Instruction not supported on target, emulation procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					StaticCallOperand(r,procedure);
					ReleaseOperand(r);
					fp := GetFingerprint(procedure);
				END;
			END;
		END EnsureSymbol;

		PROCEDURE ConditionToValue(x: SyntaxTree.Expression);
		VAR exit: Label; trueL,falseL: Label;
		BEGIN
			trueL := NewLabel();
			falseL := NewLabel();
			exit := NewLabel();
			Condition(x,trueL,falseL);
			InitOperand(result,ModeValue);
			SetLabel(trueL);
			IntermediateCode.InitRegister(result.op,IntermediateCode.GetType(system,x.type),IntermediateCode.GeneralPurposeRegister,AcquireRegister(IntermediateCode.GetType(system,x.type),IntermediateCode.GeneralPurposeRegister));
			Emit(Mov(position,result.op,true));
			BrL(exit);
			SetLabel(falseL);
			Emit(MovReplace(position,result.op,false));
			SetLabel(exit);
		END ConditionToValue;

		PROCEDURE ValueToCondition(VAR op: Operand);
		BEGIN
			LoadValue(op,system.booleanType);
			BrneL(trueLabel,op.op, false);
			ReleaseOperand(op);
			BrL(falseLabel);
		END ValueToCondition;

		PROCEDURE GetDynamicSize(type: SyntaxTree.Type; tag: IntermediateCode.Operand):IntermediateCode.Operand;
		VAR size: LONGINT;
			PROCEDURE GetArraySize(type: SyntaxTree.ArrayType; offset: LONGINT):IntermediateCode.Operand;
			VAR baseType: SyntaxTree.Type; size: LONGINT; sizeOperand,len,res: IntermediateCode.Operand;
			BEGIN
				ASSERT(type.form = SyntaxTree.Open);
				baseType := type.arrayBase.resolved;
				IF IsOpenArray(baseType) THEN
					sizeOperand := GetArraySize(baseType(SyntaxTree.ArrayType),offset+system.addressSize);
				ELSE
					size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
					sizeOperand :=  IntermediateCode.Immediate(addressType,size);
				END;
				len := tag;
				IntermediateCode.AddOffset(len,ToMemoryUnits(system,offset));
				IntermediateCode.MakeMemory(len,addressType);
				UseIntermediateOperand(len);
				Reuse2(res,sizeOperand,len);
				Emit(Mul(position,res,sizeOperand,len));
				ReleaseIntermediateOperand(sizeOperand); ReleaseIntermediateOperand(len);
				RETURN res
			END GetArraySize;

		BEGIN
			type := type.resolved;
			IF IsOpenArray(type)  THEN
				IF tag.mode = IntermediateCode.ModeImmediate THEN (* special rule for winapi/c  arrays *)
					RETURN tag
				ELSE
					RETURN  GetArraySize(type.resolved(SyntaxTree.ArrayType),0)
				END;
			ELSE
				size := ToMemoryUnits(system,system.SizeOf(type));
				RETURN IntermediateCode.Immediate(addressType,size)
			END;
		END GetDynamicSize;
		
		PROCEDURE GetArrayLength(type: SyntaxTree.Type; tag: IntermediateCode.Operand):IntermediateCode.Operand;

			PROCEDURE GetLength(type: SyntaxTree.ArrayType; offset: LONGINT):IntermediateCode.Operand;
			VAR baseType: SyntaxTree.Type; sizeOperand,len,res: IntermediateCode.Operand;
			BEGIN
				ASSERT(type.form = SyntaxTree.Open);
				baseType := type.arrayBase.resolved;
				IF IsOpenArray(baseType) THEN
					sizeOperand := GetLength(baseType(SyntaxTree.ArrayType),offset+system.addressSize);
				ELSE
					sizeOperand :=  IntermediateCode.Immediate(addressType,StaticArrayNumElements(baseType));
				END;
				len := tag;
				IntermediateCode.AddOffset(len,ToMemoryUnits(system,offset));
				IntermediateCode.MakeMemory(len,addressType);
				UseIntermediateOperand(len);
				Reuse2(res,sizeOperand,len);
				Emit(Mul(position,res,sizeOperand,len));
				ReleaseIntermediateOperand(sizeOperand); ReleaseIntermediateOperand(len);
				RETURN res
			END GetLength;

		BEGIN
			type := type.resolved;
			IF IsOpenArray(type)  THEN
				ASSERT(tag.mode # IntermediateCode.ModeImmediate);
				RETURN  GetLength(type.resolved(SyntaxTree.ArrayType),0)
			ELSE
				RETURN IntermediateCode.Immediate(addressType,1)
			END;
		END GetArrayLength;
		
		PROCEDURE GetSizeFromTag(tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR result: IntermediateCode.Operand;
		BEGIN
			IF backend.cooperative THEN
				MakeMemory(result, tag, addressType, ToMemoryUnits(system,system.addressSize));
			ELSE
				MakeMemory(result, tag, addressType, 0);
			END;
			RETURN result
		END GetSizeFromTag;
		
		PROCEDURE GetArrayOfBytesSize(e: SyntaxTree.Expression; tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR parameter: SyntaxTree.Parameter;
		BEGIN
			IF (e IS SyntaxTree.SymbolDesignator) & (e(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				parameter := e(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter);
				IF (parameter.kind IN {SyntaxTree.VarParameter,SyntaxTree.ConstParameter}) & (parameter.type.resolved IS SyntaxTree.RecordType) THEN RETURN GetSizeFromTag(tag) END;
			ELSIF e IS SyntaxTree.DereferenceDesignator THEN
				IF (e.type.resolved IS SyntaxTree.RecordType) THEN RETURN GetSizeFromTag(tag) END;
			END;
			RETURN GetDynamicSize(e.type, tag);
		END GetArrayOfBytesSize;
		

		(*
		to find imported symbol. not needed ?
		PROCEDURE SymbolByName(CONST moduleName, symbolName: ARRAY OF CHAR): SyntaxTree.Symbol;
		VAR importedModule: SyntaxTree.Module; symbol: SyntaxTree.Symbol;
		BEGIN
			IF AddImport(moduleName,importedModule,FALSE) THEN
				symbol := importedModule.moduleScope.FindSymbol(SyntaxTree.NewIdentifier(symbolName));
				RETURN symbol
			ELSE
				RETURN NIL
			END
		END SymbolByName;
		*)

		PROCEDURE GetRuntimeProcedure(CONST moduleName, procedureName: ARRAY OF CHAR; VAR procedure: SyntaxTree.Procedure; force: BOOLEAN): BOOLEAN;
		VAR runtimeModule: SyntaxTree.Module; s: Basic.MessageString;
		BEGIN
			IF AddImport(moduleName,runtimeModule,force) THEN
				procedure := runtimeModule.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
					RETURN FALSE
				ELSE
					RETURN TRUE
				END;
			ELSE RETURN FALSE
			END;
		END GetRuntimeProcedure;

		PROCEDURE GetTypeDescriptor(CONST moduleName, typeName: ARRAY OF CHAR; VAR name: Basic.SegmentedName): SyntaxTree.Symbol;
		VAR importedModule: SyntaxTree.Module; source: IntermediateCode.Section; symbol: SyntaxTree.Symbol;
			s: Basic.MessageString;
		BEGIN
			Basic.InitSegmentedName(name);
			name[0] := Basic.MakeString(moduleName);
			name[1] := Basic.MakeString(typeName);
			name[2] := -1;

			IF AddImport(moduleName,importedModule, FALSE) THEN
				symbol := importedModule.moduleScope.FindTypeDeclaration(SyntaxTree.NewIdentifier(typeName));
				IF symbol = NIL THEN
					s := "type  ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,typeName);
					Strings.Append(s," not present");
					Error(position,s);
				END;
			ELSE symbol := NIL;
			END;
			IF importedModule = moduleScope.ownerModule THEN
				source := NewSection(module.allSections, Sections.ConstSection, name, symbol, commentPrintout # NIL);
			ELSE
				source := NewSection(module.importedSections, Sections.ConstSection, name, symbol, commentPrintout # NIL);
			END;
			RETURN symbol
		END GetTypeDescriptor;


		(* Call a runtime procedure.  If numberParameters >= 0 then the procedure may be called without module import. Otherwise the signature has to be inferred from the import. *)
		PROCEDURE CallThisChecked(position: LONGINT; CONST moduleName, procedureName: ARRAY OF CHAR; numberParameters: LONGINT; checkNumParameters: BOOLEAN);
		VAR procedure: SyntaxTree.Procedure; result: Operand; reg: IntermediateCode.Operand; source: IntermediateCode.Section;
			pooledName: Basic.SegmentedName; size: LONGINT;
		BEGIN
			IF GetRuntimeProcedure(moduleName,procedureName,procedure,numberParameters < 0) THEN (* ready for dynamic linking *)
				StaticCallOperand(result,procedure);
				IF numberParameters < 0 THEN
					size := ProcedureParametersSize(system,procedure);
				ELSE
					size := ToMemoryUnits(system,numberParameters * system.addressSize);
					IF checkNumParameters & (size # ProcedureParametersSize(system,procedure)) THEN
						Error(position,"runtime call parameter count mismatch");
					END;
				END;
				Emit(Call(position, result.op, size));
				ReleaseOperand(result);
			ELSE (* only static linking possible *)
				ASSERT(numberParameters >= 0);
				Basic.InitSegmentedName(pooledName);
				pooledName[0] := Basic.MakeString(moduleName);
				pooledName[1] := Basic.MakeString(procedureName);
				pooledName[2] := -1;
				source := NewSection(module.importedSections, Sections.CodeSection, pooledName, NIL,commentPrintout # NIL);
				IntermediateCode.InitAddress(reg, addressType, pooledName , 0, 0);
				Emit(Call(position,reg, ToMemoryUnits(system,numberParameters * system.addressSize)));
			END;
		END CallThisChecked;

		(* Call a runtime procedure.  If numberParameters >= 0 then the procedure may be called without module import. Otherwise the signature has to be inferred from the import. *)
		PROCEDURE CallThis(position: LONGINT; CONST moduleName, procedureName: ARRAY OF CHAR; numberParameters: LONGINT);
		BEGIN
			CallThisChecked(position, moduleName, procedureName, numberParameters,TRUE); 
		END CallThis;

		PROCEDURE CompareString(br: ConditionalBranch; leftExpression,rightExpression: SyntaxTree.Expression);
		VAR
			left,right: Operand;
			leftSize, rightSize: IntermediateCode.Operand;
			saved: RegisterEntry;
			reg: IntermediateCode.Operand;
			procedureName: SyntaxTree.IdentifierString;
		BEGIN
			procedureName := "CompareString";

			SaveRegisters();ReleaseUsedRegisters(saved);
			Designate(leftExpression,left);
			leftSize := GetDynamicSize(leftExpression.type,left.tag);
			Emit(Push(position,leftSize));
			ReleaseIntermediateOperand(leftSize);
			Emit(Push(position,left.op));
			ReleaseOperand(left);

			Designate(rightExpression,right);
			rightSize := GetDynamicSize(rightExpression.type,right.tag);
			Emit(Push(position,rightSize));
			ReleaseIntermediateOperand(rightSize);
			Emit(Push(position,right.op));
			ReleaseOperand(right);

			IF backend.cooperative THEN
				CallThis(position,DefaultRuntimeModuleName,procedureName, 4);
			ELSE
				CallThis(position,runtimeModuleName,procedureName, 4);
			END;
			IntermediateCode.InitRegister(reg,int8,IntermediateCode.GeneralPurposeRegister,AcquireRegister(int8,IntermediateCode.GeneralPurposeRegister));
			Emit(Result(position,reg));
			(*
			AcquireThisRegister(int8,IntermediateCode.Result);
			*)
			RestoreRegisters(saved); (* must be done before use of result, might be jumped over otherwise *)
			(*
			IntermediateCode.InitRegister(reg,int8,IntermediateCode.Result);
			*)
			br(trueLabel,reg,IntermediateCode.Immediate(int8,0));
			ReleaseIntermediateOperand(reg);
			BrL(falseLabel);
		END CompareString;

		PROCEDURE CopyString(leftExpression,rightExpression: SyntaxTree.Expression);
		VAR
			left,right: Operand;
			leftSize, rightSize: IntermediateCode.Operand;
			saved: RegisterEntry;
			procedureName: SyntaxTree.IdentifierString;
		BEGIN
			procedureName := "CopyString";

			SaveRegisters();ReleaseUsedRegisters(saved);
			Designate(leftExpression,left);
			leftSize := GetDynamicSize(leftExpression.type,left.tag);
			Emit(Push(position,leftSize));
			ReleaseIntermediateOperand(leftSize);
			Emit(Push(position,left.op));
			ReleaseOperand(left);

			Designate(rightExpression,right);
			rightSize := GetDynamicSize(rightExpression.type,right.tag);
			Emit(Push(position,rightSize));
			ReleaseIntermediateOperand(rightSize);
			Emit(Push(position,right.op));
			ReleaseOperand(right);

			IF backend.cooperative THEN
				CallThis(position,DefaultRuntimeModuleName,procedureName, 4);
			ELSE
				CallThis(position,runtimeModuleName,procedureName,4);
			END;
			RestoreRegisters(saved);
		END CopyString;

		PROCEDURE VisitBinaryExpression(x: SyntaxTree.BinaryExpression);
		VAR left,right: Operand; temp: Operand;  zero, one, tempReg, tempReg2: IntermediateCode.Operand;
			leftType,rightType: SyntaxTree.Type;
			leftExpression,rightExpression : SyntaxTree.Expression;
			componentType: IntermediateCode.Type;
			value: HUGEINT; exp: LONGINT;next,exit: Label; recordType: SyntaxTree.RecordType; dest: IntermediateCode.Operand;
			size: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("VisitBinaryExpression") END;
			dest := destination; destination := emptyOperand;
			leftType := x.left.type.resolved;
			rightType := x.right.type.resolved;
			(* for "OR" and "&" the left and right expressions may not be emitted first <= shortcut evaluation *)
			CASE x.operator OF
			Scanner.Or:
				(* shortcut evaluation of left OR right *)
				IF ~conditional THEN ConditionToValue(x);
				ELSE
					next := NewLabel();
					Condition(x.left,trueLabel,next);
					SetLabel(next);
					Condition(x.right,trueLabel,falseLabel);
				END;
			|Scanner.And:
				(* shortcut evaluation of left & right *)
				IF ~conditional THEN ConditionToValue(x);
				ELSE
					next := NewLabel();
					Condition(x.left,next,falseLabel);
					SetLabel(next);
					Condition(x.right,trueLabel,falseLabel);
				END;
			|Scanner.Is:
				IF ~conditional THEN ConditionToValue(x);
				ELSE
					(* get type desc tag *)
					IF IsPointerToRecord(leftType,recordType) THEN
						Evaluate(x.left,left);
						Dereference(left,recordType,IsUnsafePointer(leftType))
					ELSE
						Designate(x.left,left);
					END;
					TypeTest(left.tag,x.right(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType.resolved,trueLabel,falseLabel);
					ReleaseOperand(left);
				END;
			|Scanner.Plus:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Or(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest); (* TODO: review this *)
					Reuse2(result.tag,left.tag,right.tag);
					Emit(Add(position,result.op,left.op,right.op));
					Emit(Add(position,result.tag,left.tag,right.tag))
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Add(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Minus:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse1(result.op,right.op);
					Emit(Not(position,result.op,right.op));
					ReleaseOperand(right);
					Emit(And(position,result.op,result.op,left.op));
					ReleaseOperand(left);
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest); (* TODO: review this *)
					Reuse2(result.tag,left.tag,right.tag);
					Emit(Sub(position,result.op,left.op,right.op));
					Emit(Sub(position,result.tag,left.tag,right.tag));
					ReleaseOperand(left); ReleaseOperand(right)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Sub(position,result.op,left.op,right.op));
					ReleaseOperand(left); ReleaseOperand(right);
				END;
			|Scanner.Times:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(And(position,result.op,left.op,right.op));
				ELSIF (x.type.resolved IS SyntaxTree.IntegerType) & IsIntegerConstant(x.right,value) & PowerOf2(value,exp) THEN
					InitOperand(result,ModeValue);
					Reuse1a(result.op,left.op,dest);
					IntermediateCode.InitImmediate(right.op,IntermediateCode.GetType(system, system.longintType),exp);
					Emit(Shl(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result, ModeValue);
					componentType := left.op.type;
					(* TODO: review this *)
					(*
					result.op = left.op * right.op - left.tag * right.tag
					result.tag = left.tag * right.op + left.op * right.tag
					*)
					result.op := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,result.op, left.op, right.op));
					tempReg := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg, left.tag, right.tag));
					Emit(Sub(position,result.op, result.op, tempReg));

					Reuse2(result.tag, left.tag, right.op);
					Emit(Mul(position,result.tag, left.tag, right.op));
					Emit(Mul(position,tempReg, left.op, right.tag));
					Emit(Add(position,result.tag, result.tag, tempReg));

					ReleaseIntermediateOperand(tempReg)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Mul(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Div:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF ((x.type.resolved IS SyntaxTree.IntegerType) OR (x.type.resolved IS SyntaxTree.AddressType)) & IsIntegerConstant(x.right,value) & PowerOf2(value,exp) THEN
					InitOperand(result,ModeValue);
					Reuse1a(result.op,left.op,dest);
					IntermediateCode.InitImmediate(right.op,IntermediateCode.GetType(system, system.longintType),exp);
					Emit(Shr(position,result.op,left.op,right.op));
				ELSE
					IF (x.type.resolved IS SyntaxTree.IntegerType) & (x.right.resolved = NIL) THEN (* divisor negative check *)
						IntermediateCode.InitImmediate(zero,IntermediateCode.GetType(system,rightType),0);
						IF ~isUnchecked THEN
							exit := NewLabel();
							BrltL(exit,zero,right.op);
							EmitTrap(position,NegativeDivisorTrap);
							SetLabel(exit);
						END;
					END;
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Div(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Mod:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF ((x.type.resolved IS SyntaxTree.IntegerType) OR (x.type.resolved IS SyntaxTree.AddressType)) & IsIntegerConstant(x.right,value) & PowerOf2(value,exp) THEN
					IntermediateCode.InitImmediate(right.op,IntermediateCode.GetType(system,x.type),value-1);
					InitOperand(result,ModeValue);
					Reuse1a(result.op,left.op,dest);
					Emit(And(position,result.op,left.op,right.op));
				ELSE
					IF (x.type.resolved IS SyntaxTree.IntegerType) & (x.right.resolved = NIL) THEN (* divisor negative check *)
						IntermediateCode.InitImmediate(zero,IntermediateCode.GetType(system,rightType),0);
						IF ~isUnchecked THEN
							exit := NewLabel();
							BrltL(exit,zero,right.op);
							EmitTrap(position,NegativeDivisorTrap);
							SetLabel(exit);
						END;
					END;
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Mod(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Slash:
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				IF leftType IS SyntaxTree.SetType THEN
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Xor(position,result.op,left.op,right.op));
				ELSIF leftType IS SyntaxTree.ComplexType THEN
					InitOperand(result,ModeValue);
					componentType := left.op.type;
					(* review this *)
					(*
					divisor = right.op * right.op + right.tag * right.tag
					result.op = (left.op * right.op + left.tag * right.tag) / divisor
					result.tag = (left.tag * right.op - left.op * right.tag) / divisor
					*)
					tempReg := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					tempReg2 := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister,AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg, right.op, right.op));
					Emit(Mul(position,tempReg2, right.tag, right.tag));
					Emit(Add(position,tempReg, tempReg, tempReg2));

					result.op := tempReg2;
					Emit(Mul(position,result.op, left.op, right.op));
					tempReg2 := IntermediateCode.Register(componentType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(componentType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mul(position,tempReg2, left.tag, right.tag));
					Emit(Add(position,result.op, result.op, tempReg2));
					Emit(Div(position,result.op, result.op, tempReg));

					Reuse2(result.tag, left.tag, right.op);
					Emit(Mul(position,result.tag, left.tag, right.op));
					Emit(Mul(position,tempReg2, left.op, right.tag));
					Emit(Sub(position,result.tag, result.tag, tempReg2));
					Emit(Div(position,result.tag, result.tag, tempReg));

					ReleaseIntermediateOperand(tempReg);
					ReleaseIntermediateOperand(tempReg2)
				ELSE
					InitOperand(result,ModeValue);
					Reuse2a(result.op,left.op,right.op,dest);
					Emit(Div(position,result.op,left.op,right.op));
				END;
				ReleaseOperand(left); ReleaseOperand(right);
			|Scanner.Equal:
				IF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BreqL,x.left,x.right);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					IF leftType IS SyntaxTree.RangeType THEN
						ASSERT(rightType IS SyntaxTree.RangeType);
						BrneL(falseLabel, left.op, right.op); (* first *)
						BrneL(falseLabel, left.tag, right.tag); (* last *)
						BrneL(falseLabel, left.extra, right.extra); (* step *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel)
					ELSIF IsDelegate(leftType) THEN (* delegate comparison *)
						BrneL(falseLabel, left.op, right.op); (* first *)
						BrneL(falseLabel, left.tag, right.tag); (* last *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel)
					ELSIF leftType IS SyntaxTree.ComplexType THEN
						(* TODO: review this *)
						BrneL(falseLabel, left.op, right.op); (* real part *)
						BrneL(falseLabel, left.tag, right.tag); (* imaginary part *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel)
					ELSE
						BrneL(falseLabel,left.op,right.op); (* inverse evaluation to optimize jumps for true case *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel);
					END;
				END;
			|Scanner.LessEqual:
				IF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BrgeL,x.right,x.left);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					IF leftType IS SyntaxTree.SetType THEN (* left subsetequal right: left \cap right = left  *)
						Reuse1(temp.op,right.op);
						Emit(And(position,temp.op,left.op,right.op));
						ReleaseOperand(right);
						BreqL(trueLabel,temp.op,left.op);
						BrL(falseLabel);
						ReleaseOperand(temp);ReleaseOperand(left);
					ELSE
						BrltL(falseLabel,right.op,left.op); (* inverse evaluation to optimize jumps for true case *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel);
					END;
				END;
			|Scanner.Less:
				IF leftType IS SyntaxTree.SetType THEN (* left < right <=> left <= right & left # right *)
					leftExpression := SyntaxTree.NewBinaryExpression(-1,x.left,x.right,Scanner.LessEqual);
					leftExpression.SetType(system.booleanType);
					rightExpression := SyntaxTree.NewBinaryExpression(-1,x.left,x.right,Scanner.Unequal);
					rightExpression.SetType(system.booleanType);
					leftExpression := SyntaxTree.NewBinaryExpression(-1,leftExpression,rightExpression,Scanner.And);
					leftExpression.SetType(system.booleanType);
					Expression(leftExpression);
				ELSIF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BrltL,x.left,x.right);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					BrgeL(falseLabel,left.op,right.op); (* inverse evaluation to optimize jumps for true case *)
					ReleaseOperand(left); ReleaseOperand(right);
					BrL(trueLabel);
				END;
			|Scanner.Greater:
				IF leftType IS SyntaxTree.SetType THEN (* left > right <=> left >= right & left # right  *)
					leftExpression := SyntaxTree.NewBinaryExpression(-1,x.left,x.right,Scanner.GreaterEqual);
					leftExpression.SetType(system.booleanType);
					rightExpression := SyntaxTree.NewBinaryExpression(-1,x.left,x.right,Scanner.Unequal);
					rightExpression.SetType(system.booleanType);
					leftExpression := SyntaxTree.NewBinaryExpression(-1,leftExpression,rightExpression,Scanner.And);
					leftExpression.SetType(system.booleanType);
					Expression(leftExpression);
				ELSIF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BrltL,x.right,x.left);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					BrgeL(falseLabel, right.op,left.op); (* inverse evaluation to optimize jumps for true case *)
					ReleaseOperand(left); ReleaseOperand(right);
					BrL(trueLabel);
				END;
			|Scanner.GreaterEqual:
				IF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BrgeL,x.left,x.right);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					IF leftType IS SyntaxTree.SetType THEN (* left supsetequal right: left \cap right = right *)
						Reuse1(temp.op,left.op);
						Emit(And(position,temp.op,left.op,right.op));
						ReleaseOperand(left);
						BreqL(trueLabel, temp.op,right.op);
						ReleaseOperand(temp); ReleaseOperand(right);
						BrL(falseLabel);
					ELSE
						BrltL(falseLabel, left.op,right.op); (* inverse evaluation to optimize jumps for true case *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel);
					END;
				END;
			|Scanner.Unequal:
				IF ~conditional THEN ConditionToValue(x);
				ELSIF (leftType IS SyntaxTree.ArrayType) OR (leftType IS SyntaxTree.StringType) THEN (* string comparison *)
					CompareString(BrneL,x.left,x.right);
				ELSE
					Evaluate(x.left,left);
					Evaluate(x.right,right);
					IF leftType IS SyntaxTree.RangeType THEN
						ASSERT(rightType IS SyntaxTree.RangeType);
						BrneL(trueLabel, left.op, right.op); (* first *)
						BrneL(trueLabel, left.tag, right.tag); (* last *)
						BrneL(trueLabel, left.extra, right.extra); (* step *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(falseLabel)
					ELSIF IsDelegate(leftType) THEN (* delegate comparison *)
						BrneL(trueLabel, left.op, right.op); (* first *)
						BrneL(trueLabel, left.tag, right.tag); (* last *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(falseLabel)
					ELSIF leftType IS SyntaxTree.ComplexType THEN
						(* TODO: review this *)
						BrneL(trueLabel, left.op, right.op); (* real part *)
						BrneL(trueLabel, left.tag, right.tag); (* imaginary part *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(falseLabel)
					ELSE
						BreqL(falseLabel,left.op,right.op); (* inverse evaluation to optimize jumps for true case *)
						ReleaseOperand(left); ReleaseOperand(right);
						BrL(trueLabel);
					END;
				END;
			|Scanner.In:
				ASSERT(rightType.resolved IS SyntaxTree.SetType);
				Evaluate(x.left,left);
				Evaluate(x.right,right);
				Convert(left.op,setType);
				ReuseCopy(temp.op,right.op);
				Emit(Shr(position,temp.op,temp.op,left.op));
				ReleaseOperand(right); ReleaseOperand(left);
				IntermediateCode.InitImmediate(one,setType,1);
				Emit(And(position,temp.op,temp.op,one));
				IF conditional THEN
					IntermediateCode.InitImmediate(zero,setType,0);
					BrneL(trueLabel,temp.op,zero);
					ReleaseOperand(temp);
					BrL(falseLabel);
				ELSE
					Convert(temp.op,bool);
					result.mode := ModeValue;
					result.op := temp.op;
					result.tag := nil; (* may be left over from calls to evaluate *)
				END;
			ELSE
				IF (x.operator = Scanner.Questionmarks) OR (x.operator = Scanner.LessLessQ) & (x.right.type.resolved IS SyntaxTree.PortType) THEN
					IF x.operator = Scanner.Questionmarks THEN
						leftExpression := x.left;
						rightExpression := x.right;
					ELSE
						leftExpression := x.right;
						rightExpression := x.left;
					END;
					
					Evaluate(leftExpression, left);
					Emit(Push(position,left.op));
					ReleaseOperand(left);
					Designate(rightExpression, right);
					size := ToMemoryUnits(system,system.SizeOf(x.right.type));
					IF ~backend.cellsAreObjects THEN
						IF size # 1 THEN Error(x.right.position,"receive not implemented for complex data types") END;
					END;
					Emit(Push(position,right.op));
					ReleaseOperand(right);
					IF backend.cellsAreObjects THEN
						CallThis(position,"ActiveCellsRuntime","ReceiveNonBlocking",2);
					ELSE
						CallThis(position,ChannelModuleName,"ReceiveNonBlocking",2);
					END;
					InitOperand(result, ModeValue);
					result.op := NewRegisterOperand(bool);
					Emit(Result(position,result.op));
					IF conditional THEN
						IntermediateCode.InitImmediate(zero,setType,0);
						BrneL(trueLabel,result.op,zero);
						ReleaseOperand(result);
						BrL(falseLabel);
					END;
				ELSIF (x.operator = Scanner.ExclamationMarks) OR (x.operator = Scanner.LessLessQ) & (x.left.type.resolved IS SyntaxTree.PortType) THEN
					leftExpression := x.left;
					rightExpression := x.right;

					Evaluate(leftExpression, left);
					Emit(Push(position,left.op));
					ReleaseOperand(left);
					Evaluate(rightExpression, right);
					size := ToMemoryUnits(system,system.SizeOf(x.right.type));
					IF ~backend.cellsAreObjects THEN
						IF size # 1 THEN Error(x.right.position,"send not implemented for complex data types") END;
					END;
					Emit(Push(position,right.op));
					ReleaseOperand(right);
					IF backend.cellsAreObjects THEN
						CallThis(position,"ActiveCellsRuntime","SendNonBlocking",2);
					ELSE
						CallThis(position,ChannelModuleName,"SendNonBlocking",2);
					END;
					InitOperand(result, ModeValue);
					result.op := NewRegisterOperand(bool);
					Emit(Result(position,result.op));
					IF conditional THEN
						IntermediateCode.InitImmediate(zero,setType,0);
						BrneL(trueLabel,result.op,zero);
						ReleaseOperand(result);
						BrL(falseLabel);
					END;
				ELSE
					HALT(100);
				END;
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitBinaryExpression") END;
		END VisitBinaryExpression;

		PROCEDURE VisitRangeExpression(x: SyntaxTree.RangeExpression);
		VAR localResult, operand: Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitRangeExpression") END;

			InitOperand(localResult, ModeValue);

			ASSERT(x.first # NIL);
			Evaluate(x.first, operand);
			localResult.op := operand.op;
			ReleaseOperand(operand);
			UseIntermediateOperand(localResult.op);

			ASSERT(x.last # NIL);
			Evaluate(x.last, operand);
			localResult.tag := operand.op;
			ReleaseOperand(operand);
			UseIntermediateOperand(localResult.tag);

			IF x.step # NIL THEN
				Evaluate(x.step, operand);
				localResult.extra := operand.op;
				ReleaseOperand(operand);
				UseIntermediateOperand(localResult.extra);
			END;

			result := localResult;

			IF Trace THEN TraceExit("VisitRangeExpression") END
		END VisitRangeExpression;

		PROCEDURE VisitTensorRangeExpression*(x: SyntaxTree.TensorRangeExpression);
		BEGIN
			HALT(100); (* should never be evaluated *)
		END VisitTensorRangeExpression;

		PROCEDURE VisitConversion(x: SyntaxTree.Conversion);
		VAR old: Operand; dest: IntermediateCode.Operand; componentType: SyntaxTree.Type;
		BEGIN
			IF Trace THEN TraceEnter("VisitConversion") END;

			ASSERT(~(x.expression.type.resolved IS SyntaxTree.RangeType));

			dest := destination; destination := emptyOperand;
			Evaluate(x.expression,old);
			InitOperand(result,ModeValue);

			result.op := old.op;
			ASSERT(result.op.mode # 0);
			IF x.type.resolved IS SyntaxTree.ComplexType THEN
				(* convert TO a complex number *)
				componentType := x.type.resolved(SyntaxTree.ComplexType).componentType;
				Convert(result.op,IntermediateCode.GetType(system, componentType));
				ASSERT(result.op.mode # 0);
				IF x.expression.type.resolved IS SyntaxTree.ComplexType THEN
					(* convert FROM a complex number TO a complex number*)
					result.tag := old.tag;
					ASSERT(result.tag.mode # 0);
					Convert(result.tag,IntermediateCode.GetType(system, componentType));
					ASSERT(result.tag.mode # 0)
				ELSE
					ASSERT(componentType IS SyntaxTree.FloatType); (* this excludes complex types based on integer types *)
					result.tag := IntermediateCode.FloatImmediate(IntermediateCode.GetType(system, componentType), 0); (* the imaginary part is set to 0 *)
				END
			ELSE
				Convert(result.op,IntermediateCode.GetType(system,x.type));
				ASSERT(result.op.mode # 0);

				result.tag := old.tag; (*! probably never used *)
			END;

			destination := dest;
			IF Trace THEN TraceExit("VisitConversion") END;
		END VisitConversion;

		PROCEDURE VisitTypeDeclaration(x: SyntaxTree.TypeDeclaration);
		BEGIN
			IF Trace THEN TraceEnter("VisitTypeDeclaration") END;
			ASSERT((x.declaredType.resolved IS SyntaxTree.EnumerationType) OR (x.declaredType.resolved IS SyntaxTree.RecordType)
			OR (x.declaredType.resolved IS SyntaxTree.PointerType) & (x.declaredType.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType));
			IF Trace THEN TraceExit("VisitTypeDeclaration") END;
		END VisitTypeDeclaration;

		(** designators (expressions) *)

		PROCEDURE VisitSymbolDesignator(x: SyntaxTree.SymbolDesignator);
		VAR ownerType, designatorType: SyntaxTree.RecordType;
		BEGIN
			IF Trace THEN TraceEnter("VisitSymbolDesignator") END;
			IF x.left # NIL THEN Expression(x.left) END;
			Symbol(x.symbol,result);
			IF backend.cooperative & (x.symbol IS SyntaxTree.Variable) & (x.symbol.scope IS SyntaxTree.RecordScope) THEN
				ASSERT ((x.left # NIL) & (x.left.type.resolved IS SyntaxTree.RecordType));
				ownerType := x.symbol.scope(SyntaxTree.RecordScope).ownerRecord;
				designatorType := x.left.type.resolved(SyntaxTree.RecordType);
				IF ~ownerType.isObject & designatorType.isObject & ~designatorType.pointerType.isPlain THEN
					IntermediateCode.AddOffset(result.op,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;
			END;
			IF Trace THEN TraceExit("VisitSymbolDesignator") END;
		END VisitSymbolDesignator;

		PROCEDURE BoundCheck(index,length: IntermediateCode.Operand);
		BEGIN
			IF isUnchecked THEN RETURN END;
			IF tagsAvailable THEN
				TrapC(BrltL,index,length,IndexCheckTrap);
			END;
		END BoundCheck;

		PROCEDURE DimensionCheck(base,dim: IntermediateCode.Operand; op: ConditionalBranch );
		VAR d: IntermediateCode.Operand;
		BEGIN
			IF isUnchecked THEN RETURN END;
			MakeMemory(d,base,dim.type,ToMemoryUnits(system,MathDimOffset * addressType.sizeInBits));
			TrapC(op,dim,d,ArraySizeTrap);
			ReleaseIntermediateOperand(d);
		END DimensionCheck;

		PROCEDURE MathIndexDesignator(x: SyntaxTree.IndexDesignator);
		VAR
			index, range, array, sourceLength, sourceIncrement, localResult: Operand;
			firstIndex, lastIndex, stepSize, summand, targetLength, targetIncrement, tmp, srcDim, destDim: IntermediateCode.Operand;
			expression: SyntaxTree.Expression;
			resultingType, leftType, baseType: SyntaxTree.Type;
			skipLabel1: Label;
			i, indexListSize, indexDim, rangeCount, indexCount, tensorRangeCount, srcDimOffset, destDimOffset, targetArrayDimensionality: LONGINT;
			staticSourceLength, staticSourceIncrement, staticIndex, staticFirstIndex, staticLastIndex, staticStepSize, staticTargetLength: LONGINT;
			variableOp: Operand;
			variable: SyntaxTree.Variable;

			PROCEDURE CountIndices(parameters: SyntaxTree.ExpressionList; VAR indexCount: LONGINT; VAR rangeCount: LONGINT; VAR tensorRangeCount: LONGINT);
			VAR expression: SyntaxTree.Expression;
			BEGIN
				(* count the number of indices, ranges and tensorRanges in the index list *)
				indexCount := 0; rangeCount := 0; tensorRangeCount := 0;
				FOR i := 0 TO parameters.Length() - 1 DO
					expression := parameters.GetExpression(i);
					IF expression IS SyntaxTree.TensorRangeExpression THEN INC(tensorRangeCount)
					ELSIF (expression.type # NIL) & (expression.type.resolved IS SyntaxTree.RangeType) THEN INC(indexCount)
					ELSE INC(indexCount)
					END
				END;
			END CountIndices;


		BEGIN
			ASSERT(tagsAvailable);

			resultingType := x.type.resolved; (* resulting type *)
			leftType := x.left.type.resolved; (* type of array to be indexed over *)

			InitOperand(localResult, ModeReference);

			IF (resultingType IS SyntaxTree.MathArrayType)  & ( (resultingType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) OR NeedDescriptor) THEN
				targetArrayDimensionality := resultingType(SyntaxTree.MathArrayType).Dimensionality();

				IF arrayDestinationTag.mode # IntermediateCode.Undefined THEN
					(* a globally defined array destination tag is available -> use and invalidate it*)
					localResult.tag := arrayDestinationTag;
					IntermediateCode.InitOperand(arrayDestinationTag)
				ELSE
					(* otherwise, create a temporary variable and use it to store the array destination tag *)
					variable := GetTemporaryVariable(GetMathArrayDescriptorType(targetArrayDimensionality), FALSE);
					Symbol(variable, variableOp);
					ReuseCopy(localResult.tag, variableOp.op);
					ReleaseOperand(variableOp);
				END
			END;

			indexListSize := x.parameters.Length();

			CountIndices(x.parameters, indexCount, rangeCount, tensorRangeCount);
			ASSERT(tensorRangeCount <= 1);

			(* designate the array to be indexed over, perform tensor range check if known *)
			Designate(x.left, array);

			IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
				Dereference(array, leftType,FALSE);
				IF tensorRangeCount=0 THEN
					DimensionCheck(array.tag, IntermediateCode.Immediate(int32, rangeCount+indexCount), BreqL)
				END
			END;

			(* determine source and destination dimension offsets; this depends on if the list starts with a '?' *)
			IF x.parameters.GetExpression(0) IS SyntaxTree.TensorRangeExpression THEN
				srcDimOffset := -indexListSize;
				destDimOffset := -rangeCount
			ELSE
				srcDimOffset := 0;
				destDimOffset := 0
			END;

			indexDim := 0;

			(* use address of source array as basis *)
			(*
			ReuseCopy(localResult.op, array.op);
			*)
			localResult.op := array.op;
			UseIntermediateOperand(localResult.op);

			(* go through the index list *)
			FOR i := 0 TO indexListSize - 1 DO
				expression := x.parameters.GetExpression(i);

				IF expression IS SyntaxTree.TensorRangeExpression THEN
					(* nothing to do *)
				ELSE
					(* determine which dimension of source array is currently looked at *)
					IF srcDimOffset < 0 THEN (* tensor expression or the form a[?,i,j] *)
						(* get the memory operand pointing to array descriptor dimension *)
						GetMathArrayField(tmp, array.tag, MathDimOffset);
						(* make a reusable register from it *)
						ReuseCopy(srcDim, tmp);
						ReleaseIntermediateOperand(tmp);
						AddInt(srcDim, srcDim, IntermediateCode.Immediate(addressType, i + srcDimOffset));
					ELSE
						srcDim := IntermediateCode.Immediate(int32, i)
					END;

					(* get length and increment of source array for current dimension *)
					GetMathArrayLength(leftType(SyntaxTree.MathArrayType), array, srcDim, FALSE, sourceLength);
					Convert(sourceLength.op, sizeType);
					GetMathArrayIncrement(leftType(SyntaxTree.MathArrayType), array, srcDim, FALSE, sourceIncrement);
					Convert(sourceIncrement.op, sizeType);
					(* release the dim operand, if dynamic. No register reuse to decrease register pressure *)
					ReleaseIntermediateOperand(srcDim);

					IF SemanticChecker.IsIntegerType(expression.type.resolved) THEN
						(* SINGLE INDEX *)
						Evaluate(expression, index);
						ReleaseIntermediateOperand(index.tag);
						index.tag := emptyOperand;
						Convert(index.op, sizeType);

						(* lower bound check *)
						IF IsIntegerImmediate(index.op, staticIndex) THEN
							ASSERT(staticIndex >= 0) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, index.op, IntermediateCode.Immediate(sizeType, 0), IndexCheckTrap)
						END;

						(* upper bound check *)
						IF IsIntegerImmediate(index.op, staticIndex) & IsIntegerImmediate(sourceLength.op, staticSourceLength) THEN
							ASSERT(staticIndex < staticSourceLength) (* ensured by checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrltL, index.op, sourceLength.op, IndexCheckTrap)
						END;

						ReleaseOperand(sourceLength);
						Convert(index.op, addressType);
						summand := index.op;

					ELSIF expression.type.resolved IS SyntaxTree.RangeType THEN
						(* RANGE OF INDICES *)
						Evaluate(expression, range);
						firstIndex := range.op; UseIntermediateOperand(firstIndex);
						lastIndex := range.tag; UseIntermediateOperand(lastIndex);
						stepSize := range.extra; UseIntermediateOperand(stepSize);
						ReleaseOperand(range);

						Convert(firstIndex, sizeType);
						Convert(lastIndex, sizeType);
						Convert(stepSize, sizeType);

						(* for dynamic upper bounds: add a runtime check, which repaces the upper bound with the largest valid index
						if it is 'MAX(LONGINT)' *)
						IF ~IsIntegerImmediate(lastIndex, staticLastIndex) THEN
							TransferToRegister(lastIndex, lastIndex);
							skipLabel1 := NewLabel();
							BrneL(skipLabel1, lastIndex, IntermediateCode.Immediate(sizeType, MAX(LONGINT)));
							Emit(MovReplace(position,lastIndex, sourceLength.op)); (* make sure that no new register is allocated *)
							Emit(Sub(position,lastIndex, lastIndex, IntermediateCode.Immediate(sizeType, 1)));
							SetLabel(skipLabel1)
						END;

						(* check if step size is valid *)
						IF IsIntegerImmediate(stepSize, staticStepSize) THEN
							ASSERT(staticStepSize >= 1) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, stepSize, IntermediateCode.Immediate(sizeType, 1), IndexCheckTrap)
						END;

						(* check lower bound check *)
						IF IsIntegerImmediate(firstIndex, staticFirstIndex) THEN
							ASSERT(staticFirstIndex >= 0) (* ensured by the checker *)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrgeL, firstIndex, IntermediateCode.Immediate(sizeType, 0), IndexCheckTrap)
						END;

						(* check upper bound check *)
						IF IsIntegerImmediate(lastIndex, staticLastIndex) & (staticLastIndex = MAX(LONGINT)) THEN
							(* statically open range: nothing to do *)
						ELSIF IsIntegerImmediate(lastIndex, staticLastIndex) & IsIntegerImmediate(sourceLength.op, staticSourceLength) THEN
							ASSERT(staticLastIndex < staticSourceLength)
						ELSIF isUnchecked THEN (* do nothing *)
						ELSE
							TrapC(BrltL, lastIndex, sourceLength.op, IndexCheckTrap)
						END;

						(* determine length of target array for current dimension *)
						(* 1. incorporate last index: *)
						IF IsIntegerImmediate(lastIndex, staticLastIndex) THEN
							(* last index is static *)
							IF IsIntegerImmediate(lastIndex, staticLastIndex) & (staticLastIndex = MAX(LONGINT)) THEN
								targetLength := sourceLength.op
							ELSE
								targetLength := IntermediateCode.Immediate(sizeType, staticLastIndex + 1)
							END;
							UseIntermediateOperand(targetLength);
						ELSE
							(* targetLength := lastIndex + 1
							Reuse1(targetLength, lastIndex);
							*)
							AddInt(targetLength, lastIndex, IntermediateCode.Immediate(sizeType, 1));
						END;
						ReleaseOperand(sourceLength);
						ReleaseIntermediateOperand(lastIndex);
						(* 2. incorporate first index: *)
						IF IsIntegerImmediate(firstIndex, staticFirstIndex) & IsIntegerImmediate(targetLength, staticTargetLength) THEN
							(* first index and current target length are static *)
							targetLength := IntermediateCode.Immediate(sizeType, staticTargetLength - staticFirstIndex)
						ELSIF IsIntegerImmediate(firstIndex, staticFirstIndex) & (staticFirstIndex = 0) THEN
							(* first index = 0: nothing to do *)
						ELSE
							(* targetLength := targetLength - firstIndex *)
							TransferToRegister(targetLength, targetLength);
							Emit(Sub(position,targetLength, targetLength, firstIndex))
						END;

						(* clip negative lengths to 0 *)
						IF IsIntegerImmediate(targetLength, staticTargetLength) THEN
							IF staticTargetLength < 0 THEN
								targetLength := IntermediateCode.Immediate(sizeType, 0)
							END
						ELSE
							skipLabel1 := NewLabel();
							TransferToRegister(targetLength, targetLength);
							BrgeL(skipLabel1, targetLength, IntermediateCode.Immediate(sizeType, 0));
							Emit(Mov(position,targetLength, IntermediateCode.Immediate(sizeType, 0)));
							SetLabel(skipLabel1)
						END;

						(* 3. incorporate index step size: *)
						IF IsIntegerImmediate(stepSize, staticStepSize) & IsIntegerImmediate(targetLength, staticTargetLength) THEN
							(*step size and current target length are static *)
							staticTargetLength := (staticTargetLength-1) DIV staticStepSize + 1;
							targetLength := IntermediateCode.Immediate(sizeType, staticTargetLength)
						ELSIF IsIntegerImmediate(stepSize, staticStepSize) & (staticStepSize = 1) THEN
							(* step size = 1: nothing to do *)
						ELSE
							(* emit code for this:
								targetLength := (targetLength-1) DIV stepSize +1;
							*)
							AddInt(targetLength, targetLength, IntermediateCode.Immediate(sizeType, -1));
							DivInt(targetLength, targetLength, stepSize);
							AddInt(targetLength, targetLength, IntermediateCode.Immediate(sizeType, 1));

						END;

						(* determine increment of target array for current dimension *)
						IF IsIntegerImmediate(sourceIncrement.op, staticSourceIncrement) & IsIntegerImmediate(stepSize, staticStepSize) THEN
							targetIncrement := IntermediateCode.Immediate(sizeType, staticSourceIncrement * staticStepSize);
						ELSIF IsIntegerImmediate(stepSize, staticStepSize) & (staticStepSize = 1) THEN
							(* step size = 1 *)
							targetIncrement := sourceIncrement.op;
							UseIntermediateOperand(targetIncrement)
						ELSE
							(* targetIncrement := sourceIncrement * stepSize *)
							Reuse1(targetIncrement, stepSize);
							ASSERT((sourceIncrement.op.mode # IntermediateCode.ModeImmediate) OR (stepSize.mode # IntermediateCode.ModeImmediate));
							MulInt(targetIncrement, sourceIncrement.op, stepSize);
						END;
						ReleaseIntermediateOperand(stepSize);

						(* write length and increment of target array to descriptor *)
						IF destDimOffset < 0 THEN
							(* determine which dimension of target array is currently looked at *)
							GetMathArrayField(tmp, array.tag, MathDimOffset);
							TransferToRegister(destDim, tmp);
							AddInt(destDim, destDim, IntermediateCode.Immediate(sizeType, indexDim + destDimOffset));

							PutMathArrayLenOrIncr(localResult.tag, targetLength, destDim, FALSE);
							PutMathArrayLenOrIncr(localResult.tag, targetIncrement, destDim, TRUE);

							ReleaseIntermediateOperand(destDim)
						ELSE
							PutMathArrayLength(localResult.tag, targetLength, indexDim);
							PutMathArrayIncrement(localResult.tag , targetIncrement, indexDim)
						END;
						ReleaseIntermediateOperand(targetLength); targetLength := nil;
						ReleaseIntermediateOperand(targetIncrement); targetIncrement := nil;

						INC(indexDim);

						Convert(firstIndex, addressType);
						TransferToRegister(summand, firstIndex);
					ELSE HALT(100);
					END;

					(*
					ASSERT((summand.mode # IntermediateCode.ModeImmediate) OR (sourceIncrement.op.mode # IntermediateCode.ModeImmediate));
					*)
					Convert(sourceIncrement.op, addressType);
					Convert(summand, addressType);
					MulInt(summand, summand, sourceIncrement.op);
					ReleaseIntermediateOperand(sourceIncrement.op);
					AddInt(localResult.op, localResult.op, summand);
					ReleaseIntermediateOperand(summand);
				END
			END;

			result := localResult;

			IF (resultingType IS SyntaxTree.RecordType) & (resultingType(SyntaxTree.RecordType).pointerType = NIL) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(resultingType);
				IF ~newObjectFile THEN
					IntermediateCode.MakeMemory(result.tag,addressType);
				END;

			ELSIF IsDelegate(resultingType) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
				UseIntermediateOperand(result.tag);

			ELSIF (resultingType IS SyntaxTree.ArrayType) & (resultingType(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitImmediate(result.tag,addressType,resultingType(SyntaxTree.ArrayType).staticLength);

			ELSIF (resultingType IS SyntaxTree.ArrayType) THEN
				result.tag := array.tag; UseIntermediateOperand(result.tag); result.dimOffset := array.dimOffset+indexListSize-1;

			ELSIF (resultingType IS SyntaxTree.MathArrayType) & ( (resultingType(SyntaxTree.MathArrayType).form # SyntaxTree.Static) OR NeedDescriptor) THEN
				(* finalize target array descriptor *)
				ASSERT(result.tag.mode # IntermediateCode.Undefined); (* tag has been already set in the beginning *)

				(* write lengths and increments of target array for remaining dimensions *)
				i := indexListSize;
				WHILE indexDim < targetArrayDimensionality DO
					GetMathArrayLengthAt(leftType(SyntaxTree.MathArrayType),array,i,FALSE, sourceLength);
					PutMathArrayLength(result.tag, sourceLength.op,indexDim);
					ReleaseOperand(sourceLength);
					GetMathArrayIncrementAt(leftType(SyntaxTree.MathArrayType),array,i,FALSE,sourceIncrement);
					PutMathArrayIncrement(result.tag, sourceIncrement.op,indexDim);
					ReleaseOperand(sourceIncrement);
					INC(i); INC(indexDim);
				END;

				IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
					tmp := nil;
				ELSE
					GetMathArrayField(tmp,array.tag,MathPtrOffset);
				END;
				PutMathArrayField(result.tag, tmp, MathPtrOffset);
				ReleaseIntermediateOperand(tmp);
				IF leftType(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
					baseType := SemanticChecker.ArrayBase(resultingType, indexDim);
					tmp := IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
				ELSE
					GetMathArrayField(tmp,array.tag, MathElementSizeOffset);
				END;
				PutMathArrayField(result.tag, tmp, MathElementSizeOffset);
				ReleaseIntermediateOperand(tmp);

				PutMathArrayField(result.tag, result.op, MathAdrOffset);

				(* write dimensionality *)
				IF targetArrayDimensionality # 0 THEN
					PutMathArrayField(result.tag, IntermediateCode.Immediate(addressType, targetArrayDimensionality),MathDimOffset);
				END;

				PutMathArrayField(result.tag, IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{RangeFlag})),MathFlagsOffset);

			END;

			ReleaseOperand(array);

			IF conditional & (resultingType.resolved IS SyntaxTree.BooleanType) THEN
				ValueToCondition(result); (*! wrong as the result of an index designator is always an address *)
			END;

		END MathIndexDesignator;

		(* TENTATIVE *)
		PROCEDURE DumpOperand(operand: Operand);
		BEGIN
			D.Log.String("    op = ");
			IntermediateCode.DumpOperand(D.Log, operand.op );
			D.Log.Ln;
			D.Log.String("    tag = ");
			IntermediateCode.DumpOperand(D.Log, operand.tag );
			D.Log.Ln;
			D.Log.String("    extra = ");
			IntermediateCode.DumpOperand(D.Log, operand.extra );
			D.Log.Ln;
			D.Log.Update
		END DumpOperand;

		(* get the length of an array , trying to make use of static information *)
		PROCEDURE ArrayLength(type: SyntaxTree.Type; dim: LONGINT; tag: IntermediateCode.Operand): IntermediateCode.Operand;
		VAR res: IntermediateCode.Operand; size: LONGINT;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.ArrayType THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form = SyntaxTree.Static THEN
						RETURN IntermediateCode.Immediate(addressType,type.staticLength);
					(*ELSIF (type.form = SyntaxTree.SemiDynamic) & backend.cellsAreObjects THEN
						Evaluate(type.length, op);
						ReleaseIntermediateOperand(op.tag);
						RETURN op.op;*)
					ELSE
						res := tag;
						IntermediateCode.AddOffset(res,ToMemoryUnits(system,addressType.sizeInBits*(DynamicDim(type)-1)));
						IntermediateCode.MakeMemory(res,addressType);
						UseIntermediateOperand(res);
						RETURN res
					END
				END;
			ELSE
				size := ToMemoryUnits(system,system.AlignedSizeOf(type));
				RETURN IntermediateCode.Immediate(addressType,size);
			END;
		END ArrayLength;

		PROCEDURE AddInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue+y.intValue);
			ELSIF IsAddress(x) & IsImmediate(y) THEN
				IntermediateCode.InitAddress(res,x.type,x.symbol.name, x.symbol.fingerprint, x.symbolOffset);
				IntermediateCode.AddOffset(res, LONGINT(y.intValue)+x.offset);
			ELSIF IsAddress(y) & IsImmediate(x) THEN
				IntermediateCode.InitAddress(res,y.type,y.symbol.name, y.symbol.fingerprint, y.symbolOffset);
				IntermediateCode.AddOffset(res, LONGINT(x.intValue)+y.offset);
			ELSIF IsRegister(x) & IsImmediate(y) THEN
				IntermediateCode.InitRegister(res, x.type, x.registerClass, x.register);
				IntermediateCode.AddOffset(res, x.offset + LONGINT(y.intValue));
				UseIntermediateOperand(res);
			ELSIF IsRegister(y) & IsImmediate(x) THEN
				IntermediateCode.InitRegister(res, y.type, y.registerClass, y.register);
				IntermediateCode.AddOffset(res, y.offset + LONGINT(x.intValue));
				UseIntermediateOperand(res);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE
					UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 0) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=0) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Add(position,res, x, y));
				END;
			END;
		END AddInt;

		PROCEDURE MulInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue*y.intValue);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 1) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=1) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Mul(position,res, x, y));
				END;
			END;
		END MulInt;

		PROCEDURE DivInt(VAR res: IntermediateCode.Operand; x,y: IntermediateCode.Operand);
		BEGIN
			ReleaseIntermediateOperand(res);
			IF IsImmediate(x) & IsImmediate(y) THEN
				IntermediateCode.InitImmediate(res,x.type,x.intValue DIV y.intValue);
			ELSE
				IF ~ReusableRegister(res) THEN
					IntermediateCode.InitRegister(res,x.type,IntermediateCode.GeneralPurposeRegister,AcquireRegister(x.type,IntermediateCode.GeneralPurposeRegister));
				ELSE UseIntermediateOperand(res);
				END;
				IF IsImmediate(x) & (x.intValue = 1) THEN
					Emit(Mov(position,res,y))
				ELSIF IsImmediate(y) & (y.intValue=1) THEN
					Emit(Mov(position,res,x))
				ELSE
					Emit(Div(position,res, x, y));
				END;
			END;
		END DivInt;

		PROCEDURE IndexDesignator(x: SyntaxTree.IndexDesignator);
		VAR length,res: IntermediateCode.Operand; type: SyntaxTree.Type; maxDim: LONGINT; array:Operand;
			index: Operand; e: SyntaxTree.Expression;i: LONGINT; size: LONGINT; atype: SyntaxTree.ArrayType;
		BEGIN
			type := x.left.type.resolved;
			IF type IS SyntaxTree.StringType THEN
				atype := SyntaxTree.NewArrayType(-1, NIL, SyntaxTree.Static);
				atype.SetArrayBase(type(SyntaxTree.StringType).baseType);
				atype.SetLength(Global.NewIntegerValue(system,-1, type(SyntaxTree.StringType).length));
				type := atype;
				x.left.SetType(type);
			END;

			IntermediateCode.InitImmediate(res,addressType,0);
			maxDim := x.parameters.Length()-1;
			FOR i := 0 TO maxDim DO
				e := x.parameters.GetExpression(i);
				Evaluate(e,index);
				Convert(index.op,addressType);

				AddInt(res, res, index.op);

				IF i = 0 THEN
					(*
					ReuseCopy(res, index.op);
					*)
					Designate(x.left,array);
					type := x.left.type.resolved;
					IF (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic) & backend.cellsAreObjects THEN
						Dereference(array, type, FALSE);
					END;
				(*
				ELSE AddInt(res, res, index.op);
				*)
				END;

				IF (array.tag.mode # IntermediateCode.Undefined ) THEN
					length := ArrayLength(type(SyntaxTree.ArrayType),array.dimOffset+i,array.tag);
					IF ((length.mode # IntermediateCode.ModeImmediate) OR (index.op.mode # IntermediateCode.ModeImmediate)) & tagsAvailable THEN
						BoundCheck(index.op, length);
					END;
					ReleaseIntermediateOperand(length);
				END;
				ReleaseOperand(index);
				type := type(SyntaxTree.ArrayType).arrayBase.resolved;
				
				length := ArrayLength(type,array.dimOffset+i-1,array.tag);
				IF (length.mode # IntermediateCode.ModeImmediate) OR (length.intValue # 1) THEN
					MulInt(res,res,length);
				END;
				ReleaseIntermediateOperand(length);
			END;
			IF (type IS SyntaxTree.ArrayType) THEN
				IF (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) THEN
					size := StaticSize(system, type);
					IF size # 1 THEN
						length := IntermediateCode.Immediate(addressType,size);
						MulInt(res,res,length);
					END;
				ELSE
					size := StaticSize(system, type(SyntaxTree.ArrayType).arrayBase);
					IF size # 1 THEN
						length := IntermediateCode.Immediate(addressType,size);
						MulInt(res,res,length);
					END;
				END;
			END;
			AddInt(res,res,array.op);
			InitOperand(result,ModeReference);
			result.op := res;

			IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType = NIL) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(type);
				IF ~newObjectFile THEN
					IntermediateCode.MakeMemory(result.tag,addressType);
				END
			ELSIF IsDelegate(type) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
				UseIntermediateOperand(result.tag);
			ELSIF (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static) THEN
				ReleaseIntermediateOperand(result.tag);
				IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
			ELSIF (type IS SyntaxTree.ArrayType)  THEN
				result.tag := array.tag; UseIntermediateOperand(result.tag); result.dimOffset := array.dimOffset+maxDim;
			END;
			ReleaseOperand(array);

			IF (conditional)  & (type.resolved IS SyntaxTree.BooleanType)  THEN
				ValueToCondition(result); (*! wrong as the result of an index designator is always an address *)
			END;
		END IndexDesignator;

		PROCEDURE VisitIndexDesignator(x: SyntaxTree.IndexDesignator);
		VAR type: SyntaxTree.Type; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitIndexDesignator") END;
			dest := destination; destination := emptyOperand;
			type := x.left.type.resolved;
			IF type IS SyntaxTree.MathArrayType THEN
				MathIndexDesignator(x);
			ELSE ASSERT((type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.StringType));
				IndexDesignator(x);
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitIndexDesignator") END;
		END VisitIndexDesignator;

		PROCEDURE PrepareTensorDescriptor(expression: SyntaxTree.IndexDesignator): SyntaxTree.Variable;
		VAR variable: SyntaxTree.Variable; srcOperand,destOperand,procOp: Operand;
			moduleName, procedureName: SyntaxTree.IdentifierString; arrayBase: SyntaxTree.Module; saved: RegisterEntry; s: Basic.MessageString;
			procedure: SyntaxTree.Procedure;
			parameters: SyntaxTree.ExpressionList; e: SyntaxTree.Expression;
			prefixIndices, prefixRanges, suffixIndices, suffixRanges,i : LONGINT; tensorFound: BOOLEAN;
		BEGIN
			variable := GetTemporaryVariable(expression.left.type, FALSE);
			parameters := expression.parameters;

			moduleName := "FoxArrayBase";
			procedureName := "CopyDescriptor";
			IF AddImport(moduleName,arrayBase,TRUE) THEN
				SaveRegisters();ReleaseUsedRegisters(saved);
				procedure := arrayBase.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					(* push address of temporary variable *)
					Symbol(variable,destOperand);
					Emit(Push(position,destOperand.op));
					ReleaseOperand(destOperand);
					(* push src *)
					Evaluate(expression.left,srcOperand);
					(*
					Dereference(srcOperand,expression.type.resolved);
					Emit(Push(position,srcOperand.tag));
					*)
					Emit(Push(position,srcOperand.op));
					ReleaseOperand(srcOperand);

					tensorFound := FALSE;
					FOR i := 0 TO parameters.Length()-1 DO
						e := parameters.GetExpression(i);
						IF e IS SyntaxTree.TensorRangeExpression THEN
							tensorFound := TRUE;
						ELSIF e IS SyntaxTree.RangeExpression THEN
							IF tensorFound THEN INC(suffixRanges) ELSE INC(prefixRanges) END;
						ELSE
							IF tensorFound THEN INC(suffixIndices) ELSE INC(prefixIndices) END;
						END;
					END;

					Emit(Push(position,IntermediateCode.Immediate(int32,prefixIndices)));
					Emit(Push(position,IntermediateCode.Immediate(int32,prefixRanges)));
					Emit(Push(position,IntermediateCode.Immediate(int32,suffixIndices)));
					Emit(Push(position,IntermediateCode.Immediate(int32,suffixRanges)));

					StaticCallOperand(procOp,procedure);
					Emit(Call(position,procOp.op,ProcedureParametersSize(system,procedure)));
					ReleaseOperand(procOp);
				END;
				RestoreRegisters(saved);
			END;
			RETURN variable

		END PrepareTensorDescriptor;

		PROCEDURE PushParameter(expression: SyntaxTree.Expression; parameter: SyntaxTree.Parameter; callingConvention: LONGINT; needsParameterBackup: BOOLEAN; VAR parameterBackup: IntermediateCode.Operand; numberRegister: LONGINT);
		VAR
			type, descriptorType, baseType: SyntaxTree.Type;
			operand, tmpOperand, variableOp, variable2Op: Operand;
			baseReg, tmp, dimOp, null, dst: IntermediateCode.Operand;
			variable, variable2: SyntaxTree.Variable;
			dim, i, size: LONGINT;

			(* TODO: needed? *)
			oldArrayDestinationTag: IntermediateCode.Operand;
			oldArrayDestinationDimension: LONGINT;
			position: LONGINT;
			saved: RegisterEntry;
			
			arrayFlags: SET;
			m, n: LONGINT;

			PROCEDURE Pass(op: IntermediateCode.Operand);
			VAR registerClass: IntermediateCode.RegisterClass; parameterRegister: IntermediateCode.Operand;
			BEGIN
				IF numberRegister >= 0 THEN
					IntermediateCode.InitRegisterClass(registerClass, IntermediateCode.Parameter, SHORT(numberRegister));
					IntermediateCode.InitRegister(parameterRegister, op.type, registerClass, AcquireRegister(op.type, registerClass));
					Emit(Mov(position,parameterRegister, op));
				ELSE
					Emit(Push(position,op))
				END
			END Pass;


			PROCEDURE PushArrayLens(formalType,actualType: SyntaxTree.Type; dim: LONGINT);
			VAR tmp: IntermediateCode.Operand; actualArrayBase: SyntaxTree.Type;
			BEGIN
				formalType := formalType.resolved; actualType := actualType.resolved;
				IF IsOpenArray(formalType)THEN
					IF actualType IS SyntaxTree.StringType THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.StringType).length)));
						RETURN;
					ELSIF (actualType IS SyntaxTree.MathArrayType) & (actualType(SyntaxTree.MathArrayType).form = SyntaxTree.Static) THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.MathArrayType).staticLength)));
						actualArrayBase := actualType(SyntaxTree.MathArrayType).arrayBase.resolved;
					ELSIF actualType(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						Pass((IntermediateCode.Immediate(addressType,actualType(SyntaxTree.ArrayType).staticLength)));
						actualArrayBase := actualType(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSE
						tmp := baseReg;
						IntermediateCode.AddOffset(tmp,ToMemoryUnits(system,dim*system.addressSize));
						IntermediateCode.MakeMemory(tmp,addressType);
						Pass((tmp));
						actualArrayBase := actualType(SyntaxTree.ArrayType).arrayBase.resolved;
					END;
					PushArrayLens(formalType(SyntaxTree.ArrayType).arrayBase.resolved, actualArrayBase,dim-1);
				END;
			END PushArrayLens;
			
			PROCEDURE SetSmallArraySizeFlag(VAR flags: SET; size: LONGINT);
			BEGIN
				CASE size OF
					|2: INCL(flags,Size2Flag);
					|3: INCL(flags,Size3Flag);
					|4: INCL(flags,Size4Flag);
					|5: INCL(flags,Size5Flag);
					|6: INCL(flags,Size6Flag);
					|7: INCL(flags,Size7Flag);
					|8: INCL(flags,Size8Flag);
				END;
			END SetSmallArraySizeFlag;

		BEGIN
			IF Trace THEN TraceEnter("PushParameter") END;
			position := expression.position;
			IF expression.resolved # NIL THEN expression := expression.resolved END;
			type := expression.type.resolved;

			ASSERT( ((type IS SyntaxTree.MathArrayType) = (parameter.type.resolved IS SyntaxTree.MathArrayType))
						OR  (type IS SyntaxTree.MathArrayType) & (parameter.type.resolved IS SyntaxTree.ArrayType)
							& (type(SyntaxTree.MathArrayType).form = SyntaxTree.Static)
							& (parameter.type.resolved(SyntaxTree.ArrayType).form = SyntaxTree.Open)
				);

			(* TODO: needed? *)
			oldArrayDestinationTag := arrayDestinationTag;
			oldArrayDestinationDimension := arrayDestinationDimension;

			IF IsArrayOfSystemByte(parameter.type) THEN
				Designate(expression,operand);
				tmp := GetArrayOfBytesSize(expression,operand.tag);
				ReleaseIntermediateOperand(operand.tag);
				operand.tag := tmp;
				IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
					Pass((operand.tag));
				END;
				Pass((operand.op));
			ELSIF IsOpenArray(parameter.type) THEN
				Designate(expression,operand);
				baseReg := operand.tag;
				IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
					PushArrayLens(parameter.type,type,operand.dimOffset+DynamicDim(parameter.type)-1);
				END;
				Pass((operand.op)); (* address of the array *)
			ELSIF parameter.type.resolved IS SyntaxTree.MathArrayType THEN
			(* case 1 *)
				IF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) &
				(parameter.kind IN {SyntaxTree.ValueParameter, SyntaxTree.ConstParameter}) THEN
					size := MathLenOffset + 2*SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					size := ToMemoryUnits(system,size*addressType.sizeInBits);
					Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
					dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					arrayDestinationTag := sp;

					(* case 1b *)
					IF expression IS SyntaxTree.IndexDesignator THEN
					(*
						dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
						descriptorType := GetMathArrayDescriptorType(dim);
						variable := GetTemporaryVariable(descriptorType,expression.position);
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						*)
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
						arrayDestinationDimension := dim;
						Designate(expression,operand);
					(* case 1a *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
					Designate(expression,operand);
						Emit(Copy(position,arrayDestinationTag,operand.tag,IntermediateCode.Immediate(addressType,size)));
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						type := expression.type.resolved;
						WHILE (i<dim) DO (* remaining static dimensions *)
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							INC(i);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);
					(* case 1d *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						DimensionCheck(operand.tag, IntermediateCode.Immediate(int32,dim),BreqL);
						Emit(Copy(position,sp(*arrayDestinationTag*),operand.tag,IntermediateCode.Immediate(addressType,size)));
						PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);
					(* case 1f *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						
						(*******
							identify the cases of small vector and matrices, used for optimizations in FoxArrayBase module (Alexey Morozov)
						*)
						arrayFlags := {StaticFlag};
						IF dim = 1 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) THEN INCL(arrayFlags,SmallVectorFlag); SetSmallArraySizeFlag(arrayFlags,m); END;
						ELSIF dim = 2 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,1,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							n := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) & (n >= 2) & (n <= 8) THEN
								INCL(arrayFlags,SmallMatrixFlag); 
								IF m = n THEN SetSmallArraySizeFlag(arrayFlags,m); END;
							END;
						END;
						(*******)
						
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,arrayFlags)),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) & (parameter.kind = SyntaxTree.VarParameter) THEN
					dim := SemanticChecker.Dimension(parameter.type.resolved,{SyntaxTree.Open});
					(* case 2b *)
					IF expression IS SyntaxTree.IndexDesignator THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						variable := GetTemporaryVariable(descriptorType, FALSE);
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := dim;
						NeedDescriptor := TRUE;
						Designate(expression,operand);
						Pass((operand.tag));
						NeedDescriptor := FALSE;
					(* case 2a *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							Pass((operand.tag));
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							variable := GetTemporaryVariable(descriptorType, FALSE);
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag, IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
							Pass((arrayDestinationTag));
						END;
					(* case 2d *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						DimensionCheck(operand.tag, IntermediateCode.Immediate(int32,dim),BreqL);
						Pass((operand.tag));
					(* case 2f *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						variable := GetTemporaryVariable(descriptorType, FALSE);
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						
						(*
							identify the cases of small vector and matrices, used for optimizations in FoxArrayBase module (Alexey Morozov)
						*)
						arrayFlags := {StaticFlag};
						IF dim = 1 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) THEN INCL(arrayFlags,SmallVectorFlag); SetSmallArraySizeFlag(arrayFlags,m); END;
						ELSIF dim = 2 THEN
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,0,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							m := LONGINT(tmpOperand.op.intValue);
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,1,FALSE,tmpOperand);
							ReleaseOperand(tmpOperand);
							ASSERT(tmpOperand.op.mode = IntermediateCode.ModeImmediate);
							n := LONGINT(tmpOperand.op.intValue);
							IF (m >= 2) & (m <= 8) & (n >= 2) & (n <= 8) THEN
								INCL(arrayFlags,SmallMatrixFlag); 
								IF m = n THEN SetSmallArraySizeFlag(arrayFlags,m); END;
							END;
						END;
						(*******)
						
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,arrayFlags)),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						Pass((arrayDestinationTag));
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (parameter.kind IN {SyntaxTree.ConstParameter,SyntaxTree.ValueParameter}) THEN
					dim := SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static});
					(* case 3b *)
					IF (expression IS SyntaxTree.IndexDesignator) & (type.resolved(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN (* indexer of form a[e,....,?] *)
							variable := PrepareTensorDescriptor(expression(SyntaxTree.IndexDesignator));
							Symbol(variable,variableOp);
							LoadValue(variableOp,system.addressType);
						ELSE
							descriptorType := GetMathArrayDescriptorType(dim);
							variable := GetTemporaryVariable(descriptorType, FALSE);
							Symbol(variable,variableOp);
						END;
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := 0;
						Designate(expression,operand);
						Pass((operand.tag));
					(* case 3a *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							Pass((operand.tag));
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							variable := GetTemporaryVariable(descriptorType, FALSE);
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset); (* static flag ? *)
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
							Pass((arrayDestinationTag));
						END;
					(* case 3d *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						Dereference(operand,type.resolved,FALSE);
						(*
						DimensionCheck(operand.tag, IntermediateCode.Immediate(int32,dim),BreqL);
						*)
						Pass((operand.tag));
					(* case 3f *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						variable := GetTemporaryVariable(descriptorType, FALSE);
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						IF operand.op.type.length >1 THEN (* vector register *)
							variable2 := GetTemporaryVariable(type, FALSE);
							Symbol(variable2, variable2Op);
							MakeMemory(tmp,variable2Op.op,operand.op.type,0);
							Emit(Mov(position,tmp, operand.op));
							ReleaseOperand(operand);
							Symbol(variable2, operand);
						END;

						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						Pass((arrayDestinationTag));
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor) & (parameter.kind = SyntaxTree.VarParameter) THEN
					dim := SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static});
					(* case 4b *)
					IF (expression IS SyntaxTree.IndexDesignator) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN (* indexer of form a[e,....,?] *)
							variable := PrepareTensorDescriptor(expression(SyntaxTree.IndexDesignator));
							Symbol(variable,variableOp);
							LoadValue(variableOp,system.addressType);
						ELSE
							descriptorType := GetMathArrayDescriptorType(dim);
							variable := GetTemporaryVariable(descriptorType, FALSE);
							Symbol(variable,variableOp);
						END;
						arrayDestinationTag := variableOp.op;
						ReuseCopy(arrayDestinationTag,arrayDestinationTag);
						arrayDestinationDimension := 0;
						Designate(expression,operand);
						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
							Symbol(variable,variableOp);
						ELSE
							variable := GetTemporaryVariable(parameter.type.resolved, FALSE);
							Symbol(variable,variableOp);
							MakeMemory(tmp,variableOp.op,addressType,0);
							Emit(Mov(position,tmp,operand.tag));
							ReleaseIntermediateOperand(tmp);
						END;
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					(* case 4a *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open THEN
						i := 0;
						WHILE (i< dim) & (type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Open) DO
							type := type.resolved(SyntaxTree.MathArrayType).arrayBase;
							INC(i);
						END;
						IF i = dim THEN
							Designate(expression,operand);
							arrayDestinationTag := operand.tag;
						ELSE (* open-static *)
							type := expression.type.resolved;
							descriptorType := GetMathArrayDescriptorType(dim);
							variable := GetTemporaryVariable(descriptorType, FALSE);
							Symbol(variable,variableOp);
							arrayDestinationTag := variableOp.op;
							Designate(expression,operand);
							FOR i := 0 TO dim-1 DO
								GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
								GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
								PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
								ReleaseOperand(tmpOperand);
							END;
							dimOp := IntermediateCode.Immediate(addressType,dim);
							PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
							PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
							PutMathArrayField(arrayDestinationTag,nil,MathFlagsOffset);
							baseType := SemanticChecker.ArrayBase(type,dim);
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
							PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						END;
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE);
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,addressType,0);
						Emit(Mov(position,tmp,arrayDestinationTag));
						ReleaseIntermediateOperand(tmp);
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					(* case 4d *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Designate(expression,operand);
						(*
						Dereference(operand,type.resolved,FALSE);
						*)
						(*
						DimensionCheck(operand.tag, IntermediateCode.Immediate(int32,dim),BreqL);
						*)
						Pass((operand.op));
					(* case 4f *)
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						descriptorType := GetMathArrayDescriptorType(dim);
						variable := GetTemporaryVariable(descriptorType, FALSE);
						Symbol(variable,variableOp);
						arrayDestinationTag := variableOp.op;
						Designate(expression,operand);
						FOR i := 0 TO dim-1 DO
							GetMathArrayLengthAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayLength(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
							GetMathArrayIncrementAt(type.resolved(SyntaxTree.MathArrayType),operand,i,FALSE,tmpOperand);
							PutMathArrayIncrement(arrayDestinationTag,tmpOperand.op,i);
							ReleaseOperand(tmpOperand);
						END;
						dimOp := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayField(arrayDestinationTag,dimOp,MathDimOffset);
						PutMathArrayField(arrayDestinationTag,operand.op,MathAdrOffset);
						PutMathArrayField(arrayDestinationTag,nil,MathPtrOffset);
						PutMathArrayField(arrayDestinationTag,IntermediateCode.Immediate(addressType,SYSTEM.VAL(LONGINT,{StaticFlag})),MathFlagsOffset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.AlignedSizeOf(baseType)));
						PutMathArrayField(arrayDestinationTag,tmp,MathElementSizeOffset);
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE);
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,addressType,0);
						Emit(Mov(position,tmp,arrayDestinationTag));
						ReleaseIntermediateOperand(tmp);
						Pass((variableOp.op));
						ReleaseOperand(variableOp);
					ELSE HALT(100);
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (parameter.kind = SyntaxTree.ValueParameter) THEN
					ASSERT(type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static);
					Designate(expression,operand);
					IF operand.op.type.length > 1 THEN
						Emit(Push(position, operand.op));
						ReleaseOperand(operand);
					ELSE
						size := system.SizeOf(type);
						Basic.Align(size,system.AlignmentOf(system.parameterAlignment,type));
						size := ToMemoryUnits(system,size);
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size)));
						arrayDestinationTag := sp;
						Emit(Copy(position,arrayDestinationTag,operand.op,IntermediateCode.Immediate(addressType,size)));
					END;
				ELSIF (parameter.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static) & (parameter.kind IN {SyntaxTree.VarParameter,SyntaxTree.ConstParameter}) THEN
					Designate(expression,operand);
					IF operand.op.type.length > 1 THEN (* need temporary to pass register *)
						variable := GetTemporaryVariable(parameter.type.resolved, FALSE);
						Symbol(variable,variableOp);
						MakeMemory(tmp,variableOp.op,operand.op.type,0);
						Emit(Mov(position,tmp,operand.op));
						Emit(Push(position,variableOp.op));
					ELSIF type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Static THEN
						Pass((operand.op));
					ELSE Error(position,"Forbidden non-static actual type. Conversion involved?");
					END;
				ELSE HALT(200)
				END;
			ELSIF parameter.type.resolved IS SyntaxTree.RangeType THEN
				IF parameter.kind = SyntaxTree.VarParameter THEN
					ASSERT(~(expression IS SyntaxTree.RangeExpression));
					Designate(expression, operand);
					Pass((operand.op));
				ELSE
					ASSERT((parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter));
					Evaluate(expression, operand);
					Pass((operand.extra)); (* step *)
					Pass((operand.tag)); (* last *)
					Pass((operand.op)) (* first *)
				END
			ELSIF parameter.type.resolved IS SyntaxTree.ComplexType THEN
				IF parameter.kind = SyntaxTree.VarParameter THEN
					Designate(expression, operand);
					Pass((operand.op));
				ELSE
					ASSERT((parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter));
					Evaluate(expression, operand);
					Pass((operand.tag)); (* real part *)
					Pass((operand.op)) (* imaginary part *)
				END
			ELSE
				IF (parameter.kind = SyntaxTree.ValueParameter) OR (parameter.kind = SyntaxTree.ConstParameter) & ~(parameter.type.resolved IS SyntaxTree.RecordType) & ~(parameter.type.resolved IS SyntaxTree.ArrayType) THEN
					IF (type IS SyntaxTree.RecordType) OR IsStaticArray(parameter.type) THEN
						Designate(expression,operand);
						size := ToMemoryUnits(system,system.SizeOf(parameter.type));
						(* stack allocation *)
						Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,size + (-size) MOD (system.addressSize DIV system.dataUnit))));
						(*! parameter alignment to be discussed ... *)

						IF type IS SyntaxTree.StringType THEN (* source potentially shorter than destination *)
							size := type(SyntaxTree.StringType).length;
						END;
						IF backend.cooperative & parameter.NeedsTrace() THEN
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							IntermediateCode.InitImmediate(null, byteType, 0);
							Emit(Fill(position, dst, IntermediateCode.Immediate(addressType,size), null));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							(* register dst has been freed before SaveRegisters already *)
							CallAssignMethod(dst, operand.op, parameter.type);
							RestoreRegisters(saved);
						END;
						Emit(Copy(position,sp,operand.op,IntermediateCode.Immediate(addressType,size)));
					ELSIF IsOpenArray(parameter.type) THEN
						Designate(expression,operand);
						baseReg := operand.tag;
						IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
							PushArrayLens(parameter.type,type,operand.dimOffset+DynamicDim(parameter.type)-1);
						END;
						Pass((operand.op)); (* address of the array *)
					ELSIF IsDelegate(parameter.type) THEN
						Evaluate(expression,operand);
						IF backend.cooperative & parameter.NeedsTrace() THEN
							Emit(Push(position, nil));
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							Emit(Push(position, dst));
							(* register dst has been freed before SaveRegisters already *)
							Emit(Push(position, operand.tag));
							CallThis(position,"GarbageCollector","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Pass((operand.tag));
						END;
						Pass((operand.op));
					ELSE
						Evaluate(expression,operand);
						IF backend.cooperative & parameter.NeedsTrace() & (operand.op.mode # IntermediateCode.ModeImmediate) THEN
							Emit(Push(position, nil));
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position,dst, sp));
							ReleaseIntermediateOperand(dst);
							SaveRegisters();ReleaseUsedRegisters(saved);
							Emit(Push(position, dst));
							(* register dst has been freed before SaveRegisters already *)
							Emit(Push(position, operand.op));
							CallThis(position,"GarbageCollector","Assign",2);
							RestoreRegisters(saved);
						ELSE
							Pass((operand.op));
						END;
					END;
				ELSIF expression IS SyntaxTree.NilValue THEN (* for special WinAPI rule *)
					Evaluate(expression,operand);
					Pass((operand.op));
				ELSE (* var parameter *)
					Designate(expression,operand);
					IF (type IS SyntaxTree.RecordType) & (parameter.kind IN {SyntaxTree.ConstParameter, SyntaxTree.VarParameter}) THEN
						IF callingConvention = SyntaxTree.OberonCallingConvention  THEN
							Pass((operand.tag));
						END;	
					END;
					Pass((operand.op));
				END;
			END;

			(* TODO: needed? *)
			arrayDestinationTag := oldArrayDestinationTag;
			arrayDestinationDimension := oldArrayDestinationDimension;

			IF needsParameterBackup THEN
				(* IF dump # NIL THEN dump.String("backup parameter"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ReuseCopy(parameterBackup, operand.op)
			END;

			ReleaseOperand(operand);
			IF Trace THEN TraceExit("PushParameter") END;
		END PushParameter;

		PROCEDURE VisitStatementDesignator(x: SyntaxTree.StatementDesignator);
		VAR prevConditional: BOOLEAN;
		BEGIN
			prevConditional := conditional;
			conditional := FALSE;

			IF (x.result # NIL) & ( x.result IS SyntaxTree.SymbolDesignator) & (x.result(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) & (x.result(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).useRegister) THEN
				Expression(x.result); (* use register *)
			END;

			Statement(x.statement);
			conditional := prevConditional;
			IF x.result # NIL THEN Expression(x.result) END;

			IF (x.result # NIL) & (x.result IS SyntaxTree.SymbolDesignator) & (x.result(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) & (x.result(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).useRegister) THEN
				ReleaseIntermediateOperand(result.op);
			END;


		END VisitStatementDesignator;

		PROCEDURE InlineProcedureCall(x: SyntaxTree.ProcedureCallDesignator): BOOLEAN;
		VAR
			procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
			wasInline: BOOLEAN;
			actualParameters: SyntaxTree.ExpressionList;
			formalParameter: SyntaxTree.Parameter;
			actualParameter: SyntaxTree.Expression;
			i: LONGINT;
			localVariable: SyntaxTree.Variable;
			variableDesignator, returnDesignator: SyntaxTree.Expression;
			src, dest: Operand;
			prevInlineExit : Label;
			prevMapper: SymbolMapper;
			tooComplex: BOOLEAN;

			PROCEDURE SimpleExpression(e: SyntaxTree.Expression): BOOLEAN;
			BEGIN
				IF e = NIL THEN RETURN TRUE
				ELSIF (e IS SyntaxTree.SymbolDesignator) THEN RETURN SimpleExpression(e(SyntaxTree.SymbolDesignator).left)
				ELSIF (e IS SyntaxTree.Value) THEN RETURN TRUE
				ELSIF (e IS SyntaxTree.SelfDesignator) THEN RETURN TRUE
				ELSIF (e IS SyntaxTree.ResultDesignator) THEN RETURN TRUE
				ELSIF (e IS SyntaxTree.DereferenceDesignator) THEN RETURN SimpleExpression(e(SyntaxTree.DereferenceDesignator).left)
				ELSE RETURN FALSE
				END;
			END SimpleExpression;

			PROCEDURE FitsInRegister(type: SyntaxTree.Type): BOOLEAN;
			BEGIN
				RETURN checker.CanPassInRegister(type)
			END FitsInRegister;

			PROCEDURE GetTemp(type: SyntaxTree.Type; tryRegister: BOOLEAN): SyntaxTree.Expression;
			VAR
				variable: SyntaxTree.Variable;
				variableDesignator: SyntaxTree.Designator;
			BEGIN
				variable :=  GetTemporaryVariable(type, tryRegister & FitsInRegister(type));
				variableDesignator := SyntaxTree.NewSymbolDesignator(SemanticChecker.InvalidPosition, NIL, variable);
				variableDesignator.SetType(type);
				RETURN variableDesignator
			END GetTemp;



		BEGIN
			wasInline := currentIsInline;
			prevInlineExit := currentInlineExit;
			prevMapper := currentMapper;
			currentInlineExit := NewLabel();
			tooComplex := FALSE;
			NEW(currentMapper);
			currentIsInline := TRUE;
			procedure := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
			procedureType := procedure.type(SyntaxTree.ProcedureType);

			formalParameter := procedureType.firstParameter;
			actualParameters := x.parameters;

			i := 0;
			WHILE (i < actualParameters.Length()) & ~tooComplex DO
				actualParameter := actualParameters.GetExpression(i);
				IF actualParameter.resolved # NIL THEN
					actualParameter := actualParameter.resolved
				END;

				(*
					if expression is simple and can be passed immediately
					or if type fits in register then we can proceed
					otherwise we escape to ordinary procedure call.
				*)

				(* cases where the expression can be mapped identically *)
				IF SimpleExpression(actualParameter) & (formalParameter.kind IN {SyntaxTree.ConstParameter, SyntaxTree.VarParameter})  THEN
					currentMapper.Add(formalParameter, actualParameter, NIL);
				ELSIF FitsInRegister(actualParameter.type) & (formalParameter.kind IN {SyntaxTree.ConstParameter, SyntaxTree.ValueParameter}) THEN
					variableDesignator := GetTemp(formalParameter.type, TRUE);
					(*
					Assign(variableDesignator, actualParameter);
					*)

					Evaluate(actualParameter, src);
					Designate(variableDesignator, dest);
					Emit(Mov(x.position, dest.op, src.op));
					ReleaseOperand(dest);
					ReleaseOperand(src);

					currentMapper.Add(formalParameter, variableDesignator, NIL);
				ELSE tooComplex := TRUE
				END;

				(*
				ELSIF (formalParameter.kind = SyntaxTree.ConstParameter) & IsSimple(actualParameter) THEN
					currentMapper.Add(formalParameter, actualParameter, NIL);
				ELSIF (formalParameter.kind = SyntaxTree.VarParameter) OR formalParameter.type.IsComposite() & (formalParameter.kind = SyntaxTree.ConstParameter) THEN
					variableDesignator := GetTemp(system.addressType, FALSE);
					Designate(actualParameter, src);
					Designate(variableDesignator, dest);
					IntermediateCode.MakeMemory(dest.op,addressType);
					Emit(Mov(x.position, dest.op, src.op));
					ReleaseOperand(dest);
					IF src.tag.mode # IntermediateCode.Undefined THEN
						tagDesignator := GetTemp(system.addressType, FALSE);
						Designate(tagDesignator, dest);
						IntermediateCode.MakeMemory(dest.op,addressType);
						Emit(Mov(x.position, dest.op, src.op));
					END;

					ReleaseOperand(dest); ReleaseOperand(src);
					currentMapper.Add(formalParameter, variableDesignator, tagDesignator);
				END;
				*)
				formalParameter := formalParameter.nextParameter;
				INC(i);
			END;


			IF ~tooComplex & (procedureType.returnType # NIL) THEN
				returnDesignator := GetTemp(procedureType.returnType, TRUE);
				currentMapper.Add(NIL, returnDesignator, NIL);
			END;

			localVariable := procedure.procedureScope.firstVariable;
			WHILE ~tooComplex & (localVariable # NIL) DO
				variableDesignator := GetTemp(localVariable.type, FALSE);
				currentMapper.Add(localVariable, variableDesignator, NIL);
				localVariable := localVariable.nextVariable;
			END;

			IF ~tooComplex THEN
				VisitStatementBlock(procedure.procedureScope.body);

				SetLabel(currentInlineExit);

				IF procedureType.returnType # NIL THEN
					Designate(returnDesignator, result);
					IF conditional THEN
						ASSERT (procedureType.returnType.resolved IS SyntaxTree.BooleanType);
						ValueToCondition(result)
					END;
				END;
			END;

			currentMapper := prevMapper;
			currentInlineExit := prevInlineExit;
			currentIsInline := wasInline;
			RETURN ~tooComplex
		END InlineProcedureCall;

		PROCEDURE VisitProcedureCallDesignator(x: SyntaxTree.ProcedureCallDesignator);
		VAR
			parameters: SyntaxTree.ExpressionList;
			d, resultDesignator, actualParameter: SyntaxTree.Expression;
			designator: SyntaxTree.Designator;
			procedureType: SyntaxTree.ProcedureType;
			formalParameter: SyntaxTree.Parameter;
			operand, returnValue: Operand;
			reg, size, mask, dest: IntermediateCode.Operand;
			saved: RegisterEntry;
			symbol: SyntaxTree.Symbol;
			variable: SyntaxTree.Variable;
			i,  parametersSize, returnTypeSize : LONGINT;
			structuredReturnType: BOOLEAN;
			firstWriteBackCall, currentWriteBackCall: WriteBackCall;
			tempVariableDesignator: SyntaxTree.Designator;
			gap, alignment: LONGINT; (*fld*)

			(* TODO: remove unnecessary backup variables *)
			oldResult: Operand;
			oldCurrentScope: SyntaxTree.Scope;
			oldArrayDestinationTag: IntermediateCode.Operand;
			oldArrayDestinationDimension: LONGINT;
			oldConstantDeclaration: SyntaxTree.Symbol;
			oldDestination: IntermediateCode.Operand;
			oldCurrentLoop: Label;
			oldConditional: BOOLEAN;
			oldTrueLabel, oldFalseLabel: Label;
			oldLocked: BOOLEAN;
			usedRegisters,oldUsedRegisters: RegisterEntry;

			return: IntermediateCode.Operand;

			parameterBackups: ARRAY 2 OF IntermediateCode.Operand;
			arg: IntermediateCode.Operand;
			dummy: IntermediateCode.Operand;
			recordType: SyntaxTree.RecordType;
			operatorSelectionProcedureOperand: Operand;
			operatorSelectionProcedure: SyntaxTree.Procedure;
			fingerPrint: SyntaxTree.FingerPrint;
			isCallOfDynamicOperator, hasDynamicOperands: BOOLEAN;
			identifierNumber: LONGINT;

			passByRegister: BOOLEAN; registerNumber,stackSize: LONGINT;
			procedure: SyntaxTree.Procedure;

			PROCEDURE BackupGlobalState;
			BEGIN
				oldResult := result;
				oldCurrentScope := currentScope;
				oldArrayDestinationTag := arrayDestinationTag;
				oldArrayDestinationDimension := arrayDestinationDimension;
				oldConstantDeclaration := constantDeclaration;
				oldDestination := destination;
				oldCurrentLoop := currentLoop;
				oldConditional := conditional;
				oldTrueLabel := trueLabel;
				oldFalseLabel := falseLabel;
				oldLocked := locked;
				oldUsedRegisters := usedRegisters
			END BackupGlobalState;

			PROCEDURE RestoreGlobalState;
			BEGIN
				result := oldResult;
				currentScope := oldCurrentScope;
				arrayDestinationTag := oldArrayDestinationTag;
				arrayDestinationDimension := oldArrayDestinationDimension;
				constantDeclaration := oldConstantDeclaration;
				destination := oldDestination;
				currentLoop := oldCurrentLoop;
				conditional := oldConditional;
				trueLabel := oldTrueLabel;
				falseLabel := oldFalseLabel;
				locked := oldLocked;
				usedRegisters := oldUsedRegisters
			END RestoreGlobalState;
			
			(** do preparations before parameter push for array-structured object types (ASOTs):
				if ASOT is passed as VAR parameter:
				- allocate temporary variable of math array type
				- copy contents of ASOT to be passed to temporary variable
				- use temporary variable as the actual parameter instead
				- create and store a write-back call in a list (an index operator call that writes the contents of the temp. variable back into the ASOT)
			**)
			PROCEDURE PrepareParameter(VAR actualParameter: SyntaxTree.Expression; formalParameter: SyntaxTree.Parameter);
			VAR
				expression: SyntaxTree.Expression;
			BEGIN
				IF actualParameter IS SyntaxTree.Designator THEN
					designator := actualParameter(SyntaxTree.Designator);
					IF (formalParameter.kind = SyntaxTree.VarParameter) & (designator.relatedAsot # NIL) & (actualParameter.type.resolved IS SyntaxTree.MathArrayType) THEN
						(* actual parameter is an index read operator call on ASOT and formal parameter is of VAR kind *)
						(* IF dump # NIL THEN dump.String("!!! BEGIN ASOT VAR parameter preparation"); dump.Ln; dump.Update END; *) (* TENTATIVE*)
						ASSERT(checker # NIL);
						checker.SetCurrentScope(currentScope);

						(* allocate temporary variable *)
						ASSERT(actualParameter.type # NIL);
						ASSERT(actualParameter.type.resolved IS SyntaxTree.MathArrayType);
						variable := GetTemporaryVariable(actualParameter.type.resolved, FALSE);
						tempVariableDesignator := SyntaxTree.NewSymbolDesignator(SemanticChecker.InvalidPosition, NIL, variable);
						tempVariableDesignator.SetType(actualParameter.type.resolved);
						ASSERT(tempVariableDesignator IS SyntaxTree.SymbolDesignator);
						ASSERT(tempVariableDesignator.type # NIL);
						ASSERT(tempVariableDesignator.type.resolved IS SyntaxTree.MathArrayType);

						(* copy math array stored in actual parameter to temporary variable *)
						BackupGlobalState;
						AssignMathArray(tempVariableDesignator, actualParameter);
						RestoreGlobalState;

						(* use temporary variable as actual parameter instead of the original one *)
						actualParameter := tempVariableDesignator;

						(* create write-back call and store it in linked list *)
						(* create new list entry *)
						IF firstWriteBackCall = NIL THEN
							NEW(firstWriteBackCall);
							currentWriteBackCall := firstWriteBackCall
						ELSE
							ASSERT(currentWriteBackCall # NIL);
							NEW(currentWriteBackCall.next);
							currentWriteBackCall := currentWriteBackCall.next
						END;
 						expression := checker.NewIndexOperatorCall(SemanticChecker.InvalidPosition, designator.relatedAsot, designator.relatedIndexList, tempVariableDesignator);
						ASSERT(expression.type = NIL);
						currentWriteBackCall.call := expression(SyntaxTree.ProcedureCallDesignator);
					ELSIF (formalParameter.kind = SyntaxTree.VarParameter) & (designator.relatedAsot # NIL)  THEN
						(* prepare writeback for any other "normal" indexer *)
						variable := GetTemporaryVariable(actualParameter.type.resolved, FALSE);
						tempVariableDesignator := SyntaxTree.NewSymbolDesignator(SemanticChecker.InvalidPosition, NIL, variable);
						tempVariableDesignator.SetType(actualParameter.type.resolved);
						Assign(tempVariableDesignator, actualParameter);
						actualParameter := tempVariableDesignator;
						IF firstWriteBackCall = NIL THEN
							NEW(firstWriteBackCall);
							currentWriteBackCall := firstWriteBackCall
						ELSE
							ASSERT(currentWriteBackCall # NIL);
							NEW(currentWriteBackCall.next);
							currentWriteBackCall := currentWriteBackCall.next
						END;
 						expression := checker.NewObjectOperatorCall(SemanticChecker.InvalidPosition, designator.relatedAsot, designator.relatedIndexList, tempVariableDesignator);
						currentWriteBackCall.call := expression(SyntaxTree.ProcedureCallDesignator);
					END
				END
			END PrepareParameter;

		BEGIN
			IF Trace THEN TraceEnter("VisitProcedureCallDesignator") END;

			IF (x.left IS SyntaxTree.SymbolDesignator) & (x.left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Procedure) THEN
				procedure := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
				IF procedure.isOberonInline & (procedure.scope.ownerModule = module.module) THEN
					IF  InlineProcedureCall(x) THEN
						RETURN
					ELSE
						Warning(x.position, "Inline call with complex parameters not yet implemented. Emitting ordinary procedure call.")
					END
				END;
			END;


			resultDesignator := procedureResultDesignator; procedureResultDesignator := NIL;
			procedureType := x.left.type.resolved(SyntaxTree.ProcedureType);


			dest := destination; destination := emptyOperand;
			SaveRegisters();ReleaseUsedRegisters(saved);

			parameters := x.parameters;

			IF (x.left IS SyntaxTree.SymbolDesignator) & (x.left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Operator) THEN
				(* an operator is called *)
				(* IF dump # NIL THEN dump.String("*** begin of operator call ***"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ASSERT(procedureType.callingConvention = SyntaxTree.OberonCallingConvention);

				(* check if a dynamic operator call should be performed *)
				isCallOfDynamicOperator := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Operator).isDynamic
			ELSE
				isCallOfDynamicOperator := FALSE
			END;

			IF backend.cooperative & (procedureType.callingConvention = SyntaxTree.WinAPICallingConvention) THEN
				Emit(Push(position, ap));
			END;

			alignment := procedureType.stackAlignment;
			IF alignment > 1 THEN
				IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,reg, sp));
				gap := ParametersSize(system, procedureType, FALSE) + ToMemoryUnits(system,system.offsetFirstParameter) + ToMemoryUnits(system,system.addressSize);

				Emit(Sub(position,sp, sp, IntermediateCode.Immediate(addressType,gap)));
				IntermediateCode.InitImmediate(mask,addressType,-alignment);
				Emit(And(position,sp, sp, mask));
				Emit(Add(position, sp, sp, IntermediateCode.Immediate(addressType, gap)));
			 	Emit(Push(position,reg));
				(*
				IntermediateCode.InitMemory(mem, addressType, sp, 0);
				Emit(Mov(position,mem,reg));
				*)
				ReleaseIntermediateOperand(reg);
			END;

			IF procedureType.callingConvention = SyntaxTree.DarwinCCallingConvention THEN	(*fld*)
				IntermediateCode.InitImmediate(mask,addressType,-16);
				Emit(And(position,sp, sp, mask));
				gap := (-ParametersSize( system, procedureType, FALSE )) MOD 16;
				IF gap # 0 THEN
					IntermediateCode.InitImmediate(size,addressType,gap);
					Emit(Sub(position,sp,sp,size))
				END;
			END;

			IF x.left IS SyntaxTree.SupercallDesignator THEN
				symbol := x.left(SyntaxTree.SupercallDesignator).left(SyntaxTree.SymbolDesignator).symbol;
			ELSIF x.left IS SyntaxTree.IndexDesignator THEN
				symbol := x.left(SyntaxTree.IndexDesignator).left(SyntaxTree.SymbolDesignator).symbol;
			ELSE
				symbol := x.left(SyntaxTree.SymbolDesignator).symbol;
			END;

			IF isCallOfDynamicOperator & hasDynamicOperands THEN
				IF dump # NIL THEN dump.String("++++++++++ dynamic operator call ++++++++++"); dump.Ln; dump.Update END; (* TENTATIVE *)
				(* push ID *)
				(* IF dump # NIL THEN dump.String("push ID"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				ASSERT(x.left IS SyntaxTree.SymbolDesignator);
				identifierNumber := Global.GetSymbol(module.module.case, x.left(SyntaxTree.SymbolDesignator).symbol.name);
				Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), identifierNumber)));

				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO parameters.Length() - 1 DO
					IF formalParameter.access # SyntaxTree.Hidden THEN
						ASSERT(i < 2);
						IF IsStrictlyPointerToRecord(formalParameter.type) THEN
							(* push pointer *)
							(* IF dump # NIL THEN dump.String("push pointer"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							IF formalParameter.kind = SyntaxTree.VarParameter THEN
								(* add dereference *)
								(* IF dump # NIL THEN dump.String("dereference pointer"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
								ReleaseIntermediateOperand(parameterBackups[i]);
								MakeMemory(parameterBackups[i], parameterBackups[i], addressType, 0)
							END;
							Emit(Push(position,parameterBackups[i]));
							ReleaseIntermediateOperand(parameterBackups[i]);

							(* push typetag *)
							(* IF dump # NIL THEN dump.String("push typetag"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							recordType := formalParameter.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
							arg := TypeDescriptorAdr(recordType);
							IF ~newObjectFile THEN IntermediateCode.MakeMemory(arg, addressType) END;
							Emit(Push(position,arg));
						ELSE
							(* push 'NonPointer' *)
							(* IF dump # NIL THEN dump.String("push 'NonPointer'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NonPointer)));

							(* push fingerprint *)
							(* IF dump # NIL THEN dump.String("push fingerprint"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
							fingerPrint := fingerPrinter.TypeFP(formalParameter.type.resolved);
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), fingerPrint.shallow))) (* TODO: push the type's fingerprint *)
						END
					END;
					formalParameter := formalParameter.nextParameter
				END;

				(* for unary operators: complete the information for the second parameter *)
				IF procedureType.numberParameters < 2 THEN
					(* push 'NonPointer' *)
					(* IF dump # NIL THEN dump.String("push 'NonPointer'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NonPointer)));

					(* push 'NoType' *)
					(* IF dump # NIL THEN dump.String("push 'NoType'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NoType)));
				END;

				(* call operator selection procedure *)
				IF GetRuntimeProcedure("FoxOperatorRuntime", "SelectOperator", operatorSelectionProcedure, TRUE) THEN
					StaticCallOperand(operatorSelectionProcedureOperand, operatorSelectionProcedure);
					Emit(Call(position,operatorSelectionProcedureOperand.op, ProcedureParametersSize(system, operatorSelectionProcedure)));
					ReleaseOperand(operatorSelectionProcedureOperand);

					(* use the address that the operator selection procedure returned as the target address of the call *)
					InitOperand(operand, ModeValue);
					operand.op := IntermediateCode.Register(addressType, IntermediateCode.GeneralPurposeRegister, AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Result(position,operand.op))
				END
			ELSE
				Evaluate(x.left, operand)
			END;

			IF symbol IS SyntaxTree.Procedure THEN
				IF x.left IS SyntaxTree.SupercallDesignator THEN
					Emit(Push(position,operand.tag));
				ELSIF (procedureType.isDelegate) THEN
					Emit(Push(position,operand.tag));
				END;
			ELSIF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
				IF (procedureType.isDelegate) THEN (* push self pointer only if procedure is a method *)
					Emit(Push(position,operand.tag));
				END;
			ELSE HALT(200);
			END;
			
			ReleaseIntermediateOperand(operand.tag);
			operand.tag := emptyOperand;

			(* determine if a structured return type is needed *)
			structuredReturnType := StructuredReturnType(procedureType);

			IF structuredReturnType THEN
				IF resultDesignator  # NIL THEN
					d := resultDesignator;
				ELSE
					variable := GetTemporaryVariable(procedureType.returnType, FALSE);
					variable.SetUntraced(procedureType.hasUntracedReturn);
					d := SyntaxTree.NewSymbolDesignator(-1,NIL,variable);
					d.SetType(variable.type);
				END;
				IF (procedureType.returnType.resolved IS SyntaxTree.RecordType) THEN
					Designate(d,returnValue);
					returnTypeSize := system.SizeOf(procedureType.returnType.resolved);
					size := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,returnTypeSize));
			 		Emit(Push(position,size));
			 		Emit(Push(position,returnValue.op));
			 		ReleaseOperand(returnValue);
				ELSE
					PushParameter(d,procedureType.returnParameter,procedureType.callingConvention, FALSE, dummy,-1)
		 		END;
		 	END;

			firstWriteBackCall := NIL; (* reset write-back call list *)

			IF procedureType.callingConvention # SyntaxTree.OberonCallingConvention THEN
				passByRegister := system.registerParameters > 0;
				registerNumber := 0;
				formalParameter := procedureType.lastParameter;
				FOR i := parameters.Length() - 1 TO 0 BY -1 DO
					actualParameter := parameters.GetExpression(i);
					PrepareParameter(actualParameter, formalParameter);
					IF passByRegister & (i < system.registerParameters) THEN
						IF ~PassInRegister(formalParameter) THEN
							Error(actualParameter.position,"cannot be passed by register")
						ELSE
							PushParameter(actualParameter, formalParameter, procedureType.callingConvention, FALSE, dummy,i);
						END;
						INC(registerNumber);
					ELSE
						PushParameter(actualParameter, formalParameter, procedureType.callingConvention, FALSE, dummy,-1);
					END;
					formalParameter := formalParameter.prevParameter;
				END;
				IF passByRegister & (registerNumber > 0) THEN
					stackSize := ToMemoryUnits(system,system.registerParameters*addressType.sizeInBits);
					Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,stackSize)));
				END;
			ELSE
				hasDynamicOperands := FALSE;
				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO parameters.Length() - 1 DO
					actualParameter := parameters.GetExpression(i);

					IF formalParameter # NIL THEN (* TENTATIVE *)
						PrepareParameter(actualParameter, formalParameter);

						IF isCallOfDynamicOperator  & IsStrictlyPointerToRecord(formalParameter.type) & (formalParameter.access # SyntaxTree.Hidden) THEN (* TODO: remove hidden parameters *)
							ASSERT(i < 2);
							hasDynamicOperands := TRUE;
							PushParameter(actualParameter, formalParameter, procedureType.callingConvention, TRUE, parameterBackups[i],-1)
						ELSE
							IF passByRegister & (registerNumber > 0) THEN
								stackSize := ToMemoryUnits(system,registerNumber*addressType.sizeInBits);
								Emit(Sub(position,sp,sp,IntermediateCode.Immediate(addressType,stackSize)));
							END;
							passByRegister := FALSE;
							PushParameter(actualParameter, formalParameter, procedureType.callingConvention, FALSE, dummy,-1);
						END;
						formalParameter := formalParameter.nextParameter;
					END;
				END;
			END;

			IF symbol IS SyntaxTree.Procedure THEN
				IF IsNested(symbol(SyntaxTree.Procedure)) THEN
					GetBaseRegister(reg,currentScope,symbol.scope); (* static link, may be fp or [fp+8] (if nested proc calls itself) *)
					Emit(Push(position,reg));
					ReleaseIntermediateOperand(reg);
				END;
				parametersSize := ProcedureParametersSize(system,symbol(SyntaxTree.Procedure));
			ELSIF (symbol IS SyntaxTree.Variable) OR (symbol IS SyntaxTree.Parameter) THEN
				parametersSize := ParametersSize(system,procedureType,FALSE);
			END;
						
			ReleaseParameterRegisters();
			IF (procedureType.callingConvention = SyntaxTree.WinAPICallingConvention) OR (procedureType.callingConvention = SyntaxTree.CCallingConvention) THEN
				Emit(Call(position,operand.op,0));
			ELSE
				Emit(Call(position,operand.op,parametersSize));
			END;
			ReleaseOperand(operand);

			IF procedureType.noReturn THEN
				EmitTrap(position,NoReturnTrap);
			END;

			IF (procedureType.returnType # NIL) & ~structuredReturnType THEN
				return := NewRegisterOperand(IntermediateCode.GetType(system,procedureType.returnType));
				Emit(Result(position,return));
			END;

			IF procedureType.callingConvention = SyntaxTree.CCallingConvention THEN
				IF passByRegister & (registerNumber > 0) & (registerNumber < system.registerParameters) THEN (* allocated space for all registers *)
					parametersSize := ToMemoryUnits(system,system.registerParameters*addressType.sizeInBits);
				END;
				size := IntermediateCode.Immediate(addressType,parametersSize);
				Emit(Add(position,sp,sp,size));
			END;

			IF (resultDesignator = NIL) & (procedureType.returnType # NIL) THEN

				IF structuredReturnType THEN
					(* stack pointer rewinding done by callee
					size := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.SizeOfParameter(procedureType.returnParameter)));
					Emit(Add(position,sp,sp,size));
					*)
					RestoreRegisters(saved);
					InitOperand(result,ModeReference);
					Symbol(variable,result);
				ELSE
					RestoreRegisters(saved);
					InitOperand(result,ModeValue);
					result.op := return;
				END;
			END;

			IF alignment > 1 THEN
				Emit(Pop(position,sp));
			END;

			IF backend.cooperative & (procedureType.callingConvention = SyntaxTree.WinAPICallingConvention) THEN
				Emit(Pop(position, ap));
			END;

			IF conditional & (procedureType.returnType # NIL) & (procedureType.returnType.resolved IS SyntaxTree.BooleanType) THEN
				ValueToCondition(result);
			END;
			destination := dest;

			(* perform all write-back calls in the list *)
			BackupGlobalState;
			currentWriteBackCall := firstWriteBackCall;
			WHILE currentWriteBackCall # NIL DO
				VisitProcedureCallDesignator(currentWriteBackCall.call);
				currentWriteBackCall := currentWriteBackCall.next
			END;
			RestoreGlobalState;
			(* TENATIVE *)
			(*
			IF isOperatorCall THEN
				IF dump # NIL THEN dump.String("*** end of operator call ***"); dump.Ln; dump.Update END
			END;
			*)

			IF Trace THEN TraceExit("VisitProcedureCallDesignator") END;
		END VisitProcedureCallDesignator;

		PROCEDURE TypeDescriptorAdr(t: SyntaxTree.Type): IntermediateCode.Operand;
		VAR res: IntermediateCode.Operand; offset: LONGINT; name: Basic.SegmentedName;

			td: SyntaxTree.Symbol;

			PROCEDURE GetHiddenPointerType(): SyntaxTree.Type;
			VAR scope: SyntaxTree.RecordScope; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration;
			BEGIN
				IF (hiddenPointerType = NIL) OR (hiddenPointerType.typeDeclaration.scope.ownerModule # module.module) THEN
					scope := SyntaxTree.NewRecordScope(module.module.moduleScope);
					variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier("@Any"));
					variable.SetType(system.anyType);
					scope.AddVariable(variable);
					hiddenPointerType := SyntaxTree.NewRecordType(-1,NIL,scope);
					typeDeclaration := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier("@HdPtrDesc"));
					typeDeclaration.SetDeclaredType(hiddenPointerType);
					typeDeclaration.SetScope(module.module.moduleScope);
					hiddenPointerType.SetTypeDeclaration(typeDeclaration);
					hiddenPointerType.SetState(SyntaxTree.Resolved);
				END;
				RETURN hiddenPointerType;
			END GetHiddenPointerType;

			PROCEDURE GetDelegateType(): SyntaxTree.Type;
			VAR scope: SyntaxTree.RecordScope; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration;
			BEGIN
				IF (delegatePointerType = NIL) OR (delegatePointerType.typeDeclaration.scope.ownerModule # module.module) THEN
					scope := SyntaxTree.NewRecordScope(module.module.moduleScope);
					variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier("@Procedure"));
					variable.SetType(SyntaxTree.NewProcedureType(-1,NIL));
					scope.AddVariable(variable);
					variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier("@Any"));
					variable.SetType(system.anyType);
					scope.AddVariable(variable);
					delegatePointerType := SyntaxTree.NewRecordType(-1,NIL,scope);
					typeDeclaration := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier("@Delegate"));
					typeDeclaration.SetDeclaredType(delegatePointerType);
					typeDeclaration.SetScope(module.module.moduleScope);
					delegatePointerType.SetTypeDeclaration(typeDeclaration);
					delegatePointerType.SetState(SyntaxTree.Resolved);
				END;
				RETURN delegatePointerType
			END GetDelegateType;


			PROCEDURE GetBackendType(x: SyntaxTree.Type; VAR offset: LONGINT; VAR name: Basic.SegmentedName): SyntaxTree.Symbol;
			(* create anonymous type declaration for types that need a type descriptor but have been declared anonymously
				such as in VAR a: RECORD ... END;
				reason: type desciptors in Sections are then accessible via a type declaration symbol and for types
				and variables, constants and procedures the same mechanism can be used for fixups etc.
			*)
			VAR  source: Sections.Section;null: HUGEINT; td: SyntaxTree.TypeDeclaration;
				op: IntermediateCode.Operand; baseRecord: SyntaxTree.RecordType;
			BEGIN (* no code emission *)
				source := NIL;
				x := x.resolved;
				IF (x IS SyntaxTree.AnyType) OR (x IS SyntaxTree.PointerType) THEN
					x := GetHiddenPointerType();
				ELSIF IsDelegate(x) THEN
					x := GetDelegateType();
				ELSIF (x IS SyntaxTree.RecordType) OR (x IS SyntaxTree.CellType) THEN
				ELSE HALT(200);
				END;

				td := x.typeDeclaration;
				IF td = NIL THEN
					ASSERT(x(SyntaxTree.RecordType).pointerType # NIL);
					td := x(SyntaxTree.RecordType).pointerType.resolved.typeDeclaration;
					ASSERT(td # NIL);
				END;

				IF newObjectFile THEN
					GetCodeSectionNameForSymbol(td,name);
					IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
						meta.CheckTypeDeclaration(x);
						source := NewSection(module.allSections, Sections.ConstSection, name,td,commentPrintout # NIL);
					ELSE
						source := NewSection(module.importedSections, Sections.ConstSection,name,td,commentPrintout # NIL);
					END;
					IF backend.cooperative OR meta.simple THEN
						offset := 0;
					ELSE
						IF x IS SyntaxTree.CellType THEN
							baseRecord := x(SyntaxTree.CellType).GetBaseRecord();
							IF baseRecord = NIL THEN 
								offset := ToMemoryUnits(system, meta.GetTypeRecordBaseOffset(0));
							ELSE 
								offset := ToMemoryUnits(system, meta.GetTypeRecordBaseOffset(baseRecord.recordScope.numberMethods)*system.addressSize);
							END;
						ELSE
							offset := ToMemoryUnits(system,meta.GetTypeRecordBaseOffset(x(SyntaxTree.RecordType).recordScope.numberMethods)*system.addressSize);
						END;
					END;
				ELSE
					offset := 0;
					source := module.allSections.FindBySymbol(td); (*TODO*)
					IF source = NIL THEN
						null := 0;
						GetCodeSectionNameForSymbol(td,name);
						source := NewSection(module.allSections, Sections.ConstSection, name,td,commentPrintout # NIL);
						IntermediateCode.InitImmediate(op,addressType,0);
						source(IntermediateCode.Section).Emit(Data(position,op));
						source.SetReferenced(FALSE)
					ELSE
						name := source.name;
					END;
				END;
				RETURN td
			END GetBackendType;

		BEGIN
			(*td := t.typeDeclaration;*)
			td := GetBackendType(t,offset,name); (*! do not dereference a pointer here as the type descriptor for the pointer might be asked for *)
			(*
			IF t IS SyntaxTree.PointerType THEN
				source := GetBackendType(t(SyntaxTree.PointerType).pointerBase.resolved);
			ELSE
				source := GetBackendType(t);
			END;
			*)
			IF newObjectFile THEN
				IntermediateCode.InitAddress(res, addressType, name, GetFingerprint(td), 0 (*
				1+t(SyntaxTree.RecordType).recordScope.numberMethods+16+1 *));
				IntermediateCode.SetOffset(res,offset);
			ELSE
				IntermediateCode.InitAddress(res, addressType, name, GetFingerprint(td), 0);
			END;
			(*
			IntermediateCode.MakeMemory(res,IntermediateCode.UnsignedInteger,addressType.sizeInBits);
			make memory should be used when tag is used, not earlier
			*)


			RETURN res
		END TypeDescriptorAdr;

		(*
		PROCEDURE MakeTypeTag(VAR operand: Operand);
		VAR result: IntermediateCode.Operand;
		BEGIN
			IF operand.tag.mode = IntermediateCode.Undefined THEN
				operand.tag := TypeDescriptorAdr(operand.type);
				IntermediateCode.MakeMemory(operand.tag,addressType);
				UseIntermediateOperand(operand.tag);
			END;
		END MakeTypeTag;
		*)

		PROCEDURE ProfilerInit;
		VAR reg: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitAddress(reg, addressType, profileInit.name , GetFingerprint(profileInit.symbol), 0);
			Emit(Call(position,reg,0));
		END ProfilerInit;

		PROCEDURE ProfilerEnterExit(procedureNumber: LONGINT; enter: BOOLEAN);
		VAR reg: IntermediateCode.Operand; result: Operand; procedure: SyntaxTree.Procedure;
		BEGIN
			IF enter & GetRuntimeProcedure("FoxProfiler","EnterProcedure",procedure,TRUE)
			OR ~enter & GetRuntimeProcedure("FoxProfiler","ExitProcedure",procedure,TRUE)
			THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				IntermediateCode.MakeMemory(reg, IntermediateCode.GetType(system,system.longintType));
				Emit(Push(position,reg));
				IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), procedureNumber);
				Emit(Push(position,reg));
				StaticCallOperand(result,procedure);
				Emit(Call(position,result.op,ProcedureParametersSize(system,procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerEnterExit;

		PROCEDURE ProfilerAddProcedure(procedureNumber: LONGINT; CONST name: ARRAY OF CHAR);
		VAR string: SyntaxTree.String; reg: IntermediateCode.Operand; result: Operand; procedure: SyntaxTree.Procedure; sv: SyntaxTree.StringValue;type: SyntaxTree.Type;
		BEGIN
			IF GetRuntimeProcedure("FoxProfiler","AddProcedure",procedure,TRUE) THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				IntermediateCode.MakeMemory(reg, IntermediateCode.GetType(system,system.longintType));
				profileInit.Emit(Push(position,reg));
				IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), procedureNumber);
				profileInit.Emit(Push(position,reg));
				NEW(string, LEN(name)); COPY(name, string^);
				sv := SyntaxTree.NewStringValue(-1,string);
				type := SyntaxTree.NewStringType(-1,system.characterType,Strings.Length(name));
				sv.SetType(type);
				Designate(sv,result);
				profileInit.Emit(Push(position,result.tag));
				profileInit.Emit(Push(position,result.op));
				StaticCallOperand(result,procedure);
				profileInit.Emit(Call(position,result.op,ProcedureParametersSize(system,procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerAddProcedure;

		PROCEDURE ProfilerAddModule(CONST name: ARRAY OF CHAR);
		VAR string: SyntaxTree.String; sv: SyntaxTree.StringValue; type: SyntaxTree.Type; result: Operand;  reg: IntermediateCode.Operand; procedure: SyntaxTree.Procedure;
		BEGIN
			IF GetRuntimeProcedure("FoxProfiler","AddModule",procedure,TRUE) THEN
				IntermediateCode.InitAddress(reg, addressType, profileId.name , GetFingerprint(profileId.symbol), 0);
				profileInit.Emit(Push(position,reg));
				profileInitPatchPosition := profileInit.pc;
				profileInit.Emit(Nop(position)); (* placeholder, will be patched by number of procedures *)
				NEW(string, LEN(name)); COPY(name, string^);
				sv := SyntaxTree.NewStringValue(-1,string);
				type := SyntaxTree.NewStringType(-1,system.characterType,Strings.Length(name));
				sv.SetType(type);
				Designate(sv,result);
				profileInit.Emit(Push(position,result.tag));
				profileInit.Emit(Push(position,result.op));
				StaticCallOperand(result,procedure);
				profileInit.Emit(Call(position,result.op,ProcedureParametersSize(system,procedure)));
				ReleaseOperand(result);
			END;
		END ProfilerAddModule;

		PROCEDURE ProfilerPatchInit;
		VAR reg: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(reg, IntermediateCode.GetType(system,system.longintType), numberProcedures);
			profileInit.EmitAt(profileInitPatchPosition,Push(position,reg));
			EmitLeave(profileInit,position,0);
			profileInit.Emit(Exit(position,0,0));
		END ProfilerPatchInit;

		(** if operator can be overloaded dynamically, emit code that registers it in the runtime **)
		PROCEDURE RegisterDynamicOperator(operator: SyntaxTree.Operator);
		VAR
			id: LONGINT;
			leftType, rightType: SyntaxTree.Type;
			procedureType: SyntaxTree.ProcedureType;
			runtimeProcedure: SyntaxTree.Procedure;
			runtimeProcedureOperand, operatorOperand: Operand;
			kind: SET;

			PROCEDURE PushTypeInfo(type: SyntaxTree.Type);
			VAR
				arg: IntermediateCode.Operand;
				recordType: SyntaxTree.RecordType;
				fingerPrint: SyntaxTree.FingerPrint;
			BEGIN
				IF type = NIL THEN
					(* no type: push 'NoType' *)
					(* IF dump # NIL THEN dump.String("push 'NoType'"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					arg := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), NoType)
				ELSIF IsStrictlyPointerToRecord(type) THEN
					(* pointer to record type: push typetag *)
					(* IF dump # NIL THEN dump.String("push typetag"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					recordType := type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
					arg := TypeDescriptorAdr(recordType);
					IF ~newObjectFile THEN IntermediateCode.MakeMemory(arg, addressType) END;
				ELSE
					(* non-pointer to record type: push fingerprint *)
					(* IF dump # NIL THEN dump.String("push fingerprint"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					fingerPrint := fingerPrinter.TypeFP(type.resolved);
					arg := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), fingerPrint.shallow)
				END;
				operatorInitializationCodeSection.Emit(Push(position,arg))
			END PushTypeInfo;
		BEGIN
			ASSERT(operatorInitializationCodeSection # NIL);

			ASSERT(operator.type IS SyntaxTree.ProcedureType);
			procedureType := operator.type(SyntaxTree.ProcedureType);

			(* determine types *)
			leftType := procedureType.firstParameter.type;
			IF procedureType.numberParameters = 2 THEN
				ASSERT(procedureType.firstParameter.nextParameter # NIL);
				rightType := procedureType.firstParameter.nextParameter.type;
			ELSE
				rightType := NIL
			END;


			(* determine operator kind *)
			IF IsStrictlyPointerToRecord(leftType) THEN
				kind := {LhsIsPointer}
			ELSE
				kind := {}
			END;
			IF IsStrictlyPointerToRecord(rightType) THEN
				kind := kind + {RhsIsPointer}
			END;

			IF kind # {} THEN (* TODO: to be removed later on *)
				(* at least one of the types is a pointer to record *)

				(* emit a code that registers this specific operator in the runtime *)
				dump := operatorInitializationCodeSection.comments;

				(* IF dump # NIL THEN dump.String("*** begin of operator registration ***"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
				IF GetRuntimeProcedure("FoxOperatorRuntime", "RegisterOperator", runtimeProcedure, TRUE) THEN
					(* push ID *)
					(* IF dump # NIL THEN dump.String("push ID"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					id := Global.GetSymbol(module.module.case, operator.name);
					operatorInitializationCodeSection.Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType), id)));

					(* push kind *)
					(* IF dump # NIL THEN dump.String("push kind"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					operatorInitializationCodeSection.Emit(Push(position,IntermediateCode.Immediate(setType, SYSTEM.VAL(LONGINT, kind))));

					(* push type infos *)
					PushTypeInfo(leftType);
					PushTypeInfo(rightType);

					(* push operator address *)
					(* IF dump # NIL THEN dump.String("push operator address"); dump.Ln; dump.Update END; *) (* TENTATIVE *)
					StaticCallOperand(operatorOperand, operator);
					operatorInitializationCodeSection.Emit(Push(position,operatorOperand.op));
					ReleaseOperand(operatorOperand);

					StaticCallOperand(runtimeProcedureOperand, runtimeProcedure);
					operatorInitializationCodeSection.Emit(Call(position,runtimeProcedureOperand.op, ProcedureParametersSize(system, runtimeProcedure)));
					ReleaseOperand(runtimeProcedureOperand)
				END
				(* IF dump # NIL THEN dump.String("*** end of operator registration ***"); dump.Ln; dump.Update END *) (* TENTATIVE *)
			END
		END RegisterDynamicOperator;

		PROCEDURE SystemTrace(x: SyntaxTree.ExpressionList; pos: LONGINT);
		VAR
			traceModule: SyntaxTree.Module;
			procedure: SyntaxTree.Procedure;
			procedureVariable: SyntaxTree.Variable;
			s,msg: Basic.MessageString;
			res: Operand;
			i: LONGINT;
			sv: SyntaxTree.StringValue;
			type: SyntaxTree.Type;
			recordType: SyntaxTree.RecordType;
			printout: Printout.Printer;
			stringWriter: Streams.StringWriter;
			expression: SyntaxTree.Expression;

			PROCEDURE GetProcedure(CONST procedureName: ARRAY OF CHAR): BOOLEAN;
			BEGIN
				procedure := traceModule.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					procedureVariable := traceModule.moduleScope.FindVariable(SyntaxTree.NewIdentifier(procedureName));
				END;
				IF (procedure = NIL) & (procedureVariable = NIL) THEN
					s := "procedure ";
					Strings.Append(s,backend.traceModuleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
					RETURN FALSE
				ELSE
					RETURN TRUE
				END;
			END GetProcedure;

			PROCEDURE CallProcedure;
			VAR size: LONGINT;
			BEGIN
				IF procedure # NIL THEN
					StaticCallOperand(result,procedure);
					size := ProcedureParametersSize(system,procedure);
				ELSE
					Symbol(procedureVariable, result);
					LoadValue(result, procedureVariable.type.resolved);
					size := ParametersSize(system, procedureVariable.type.resolved(SyntaxTree.ProcedureType), FALSE);
				END;
				Emit(Call(position,result.op,size));
			END CallProcedure;

			PROCEDURE String(CONST s: ARRAY OF CHAR);
			VAR res: Operand; string: SyntaxTree.String;
			BEGIN
				IF GetProcedure("String") THEN
					NEW(string, LEN(s)); COPY(s, string^);
					sv := SyntaxTree.NewStringValue(-1,string);
					type := SyntaxTree.NewStringType(-1,system.characterType,Strings.Length(s));
					sv.SetType(type);
					Designate(sv,res);
					Emit(Push(position,res.tag));
					Emit(Push(position,res.op));
					ReleaseOperand(res);
					CallProcedure;
				END;
			END String;

			PROCEDURE Integer(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("Int") THEN
					Emit(Push(position,op));
					Emit(Push(position,IntermediateCode.Immediate(int32,1)));
					CallProcedure;
				END;
			END Integer;

			PROCEDURE Float(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("HIntHex") THEN
					Emit(Push(position,op));
					Emit(Push(position,IntermediateCode.Immediate(int32,16)));
					CallProcedure;
				END;
			END Float;

			PROCEDURE Set(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("Set") THEN
					Emit(Push(position,op));
					(*
					Emit(Push(position,IntermediateCode.Immediate(int32,0))); (* ofs *)
					Emit(Push(position,IntermediateCode.Immediate(int32,32))); (* n *)
					*)
					CallProcedure;
				END;
			END Set;

			PROCEDURE Boolean(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("Boolean") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
			END Boolean;

			PROCEDURE Char(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("Char") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
			END Char;

			PROCEDURE Address(op: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("Address") THEN
					Emit(Push(position,op));
					CallProcedure;
				END;
			END Address;

			PROCEDURE StringOperand(op,tag: IntermediateCode.Operand);
			BEGIN
				IF GetProcedure("String") THEN
					Emit(Push(position,tag));
					Emit(Push(position,op));
					CallProcedure;
				END;
			END StringOperand;


			PROCEDURE Ln;
			BEGIN
				IF GetProcedure("Ln") THEN
					CallProcedure;
				END;
			END Ln;


		BEGIN
			IF backend.traceModuleName = "" THEN RETURN END;
			IF AddImport(backend.traceModuleName,traceModule,TRUE) THEN
				IF GetProcedure("Enter") THEN
					CallProcedure
				END;
				NEW(stringWriter,LEN(s));
				FOR i := 0 TO x.Length()-1 DO
					msg := "";
					expression := x.GetExpression(i);
					IF currentScope IS SyntaxTree.ProcedureScope THEN
						Global.GetSymbolName(currentScope(SyntaxTree.ProcedureScope).ownerProcedure, s)
					ELSE
					Global.GetModuleName(module.module, s);
					END;
					IF i = 0 THEN
						stringWriter.String(s); stringWriter.String("@"); stringWriter.Int(pos,1);
						stringWriter.String(":");
					END;

					printout := Printout.NewPrinter(stringWriter,Printout.SourceCode,FALSE);
					IF ~(expression IS SyntaxTree.StringValue) THEN
						printout.Expression(expression);
						stringWriter.Get(s);
						Strings.Append(msg,s);
						Strings.Append(msg,"= ");
					ELSE stringWriter.Get(s); (* remove from string writer *)
						Strings.Append(msg, s);
					END;
					String(msg);
					IF SemanticChecker.IsStringType(expression.type) THEN
						Designate(expression,res);
						StringOperand(res.op,res.tag);
					ELSE
						Evaluate(expression,res);
						IF expression.type.resolved IS SyntaxTree.IntegerType THEN
							IF res.op.type.sizeInBits < IntermediateCode.Bits64 THEN
								Convert(res.op,int64);
							END;
							Integer(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.BooleanType THEN
							Boolean(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.SetType THEN
							Set(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.FloatType THEN
							IF res.op.type.sizeInBits = IntermediateCode.Bits32 THEN
								Convert(res.op,float64);
							END;
							Float(res.op);
						ELSIF (expression.type.resolved IS SyntaxTree.CharacterType) & (expression.type.resolved.sizeInBits = 8) THEN
							Char(res.op);
						ELSIF expression.type.resolved IS SyntaxTree.AddressType THEN
							Address(res.op);String("H");
						ELSIF expression.type.resolved IS SyntaxTree.SizeType THEN
							Address(res.op);String("H");
						ELSIF (expression.type.resolved IS SyntaxTree.PointerType) OR IsPointerToRecord(expression.type,recordType) THEN
							Address(res.op);String("H");
						ELSIF (expression.type.resolved IS SyntaxTree.ProcedureType) THEN
							Address(res.op);String("H");
						ELSIF expression.type.resolved IS SyntaxTree.NilType THEN
							String("NIL");
						ELSE HALT(200);
						END;
					END;
					ReleaseOperand(res);
					String("; ");
				END;
				IF GetProcedure("Exit") THEN
					CallProcedure
				ELSE
					Ln;
				END;
			END;
		END SystemTrace;


		PROCEDURE InitFields(type: SyntaxTree.Type; CONST adr: IntermediateCode.Operand; offset: LONGINT);
		VAR baseType: SyntaxTree.Type; imm,mem: IntermediateCode.Operand; dim,size: LONGINT;
			variable: SyntaxTree.Variable; i: LONGINT; initializerOp: Operand;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				WITH type: SyntaxTree.RecordType DO
					baseType := type.baseType;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
						IF baseType IS SyntaxTree.PointerType THEN baseType := baseType(SyntaxTree.PointerType).pointerBase END;
						InitFields(baseType,adr,offset);
					END;
					variable := type.recordScope.firstVariable;
					WHILE variable # NIL DO
						IF variable.initializer # NIL THEN
							Evaluate(variable.initializer,initializerOp);
							MakeMemory(mem,adr,IntermediateCode.GetType(system,variable.type),offset+ ToMemoryUnits(system,variable.offsetInBits));
							Emit(Mov(position,mem,initializerOp.op));
							ReleaseOperand(initializerOp);
							ReleaseIntermediateOperand(mem);
						END;					
						InitFields(variable.type, adr, offset+ ToMemoryUnits(system,variable.offsetInBits));
						variable := variable.nextVariable
					END;
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form = SyntaxTree.Static THEN
						baseType := type.arrayBase;
						size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
						FOR i := 0 TO type.staticLength-1 DO
							InitFields(baseType,adr,offset+i*size);
						END;
					END;
				END;
			ELSIF type IS SyntaxTree.MathArrayType THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Open THEN
						dim := DynamicDim(type);
						imm := IntermediateCode.Immediate(addressType,dim);
						PutMathArrayFieldOffset(adr,imm,MathDimOffset,offset);
						baseType := SemanticChecker.ArrayBase(type,dim);
						IF baseType = NIL THEN size := 0 ELSE size := system.AlignedSizeOf(baseType) END;
						imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,size));
						PutMathArrayFieldOffset(adr,imm,MathElementSizeOffset,offset);
						ReleaseIntermediateOperand(imm);
						(* flags remain empty (=0) for open array *)
					ELSIF type.form = SyntaxTree.Static THEN
						baseType := type.arrayBase;
						size := ToMemoryUnits(system,system.AlignedSizeOf(baseType));
						ASSERT(type.staticLength < 1024*1024*1024);
						FOR i := 0 TO type.staticLength-1 DO
							InitFields(baseType,adr,offset+i*size);
						END;
					END;
				END;
			END;
		END InitFields;

		PROCEDURE InitVariable(VAR variable: SyntaxTree.Variable);
		VAR type: SyntaxTree.Type; operand: Operand; tmp: IntermediateCode.Operand; reference: SyntaxTree.Expression;
		BEGIN
			type := variable.type.resolved;
			IF (type IS SyntaxTree.MathArrayType) THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Open THEN
						Symbol(variable,operand);
						InitFields(type, operand.tag,0);
					ELSIF type.form = SyntaxTree.Tensor THEN
						Symbol(variable, operand);
						MakeMemory(tmp,operand.op,addressType,0);
						ReleaseOperand(operand);
						Emit(Mov(position,tmp, nil ) );
						ReleaseIntermediateOperand(tmp);
					END;
				END;
			ELSE
				Symbol(variable,operand);
				IF variable.initializer # NIL THEN
					reference := SyntaxTree.NewSymbolDesignator(variable.initializer.position,NIL,variable);
					reference.SetType(variable.type.resolved);
					reference.SetAssignable(TRUE);
					Assign(reference,variable.initializer);
				END;
				InitFields(type, operand.op,0);
				ReleaseOperand(operand);
			END;
		END InitVariable;

		PROCEDURE MathArrayDim(type: SyntaxTree.MathArrayType; CONST base: IntermediateCode.Operand; VAR result: Operand);
		VAR end: Label;
		BEGIN
			IF type.form = SyntaxTree.Tensor THEN
				InitOperand(result,ModeValue);
				ReuseCopy(result.op,base);
				end := NewLabel();
				BreqL(end,result.op,IntermediateCode.Immediate(addressType,0));
				Emit(MovReplace(position,result.op,IntermediateCode.Memory(addressType,result.op,ToMemoryUnits(system,MathDimOffset*addressType.sizeInBits))));
				SetLabel(end);
				Convert(result.op,int32);
			ELSE
				InitOperand(result,ModeValue);
				IntermediateCode.InitImmediate(result.op, int32, SemanticChecker.Dimension(type,{SyntaxTree.Open, SyntaxTree.Static}));
			END
		END MathArrayDim;

		PROCEDURE PutMathArrayField(base,value: IntermediateCode.Operand; fieldOffset: LONGINT);
		VAR mem: IntermediateCode.Operand; offset: LONGINT;
		BEGIN
			offset := ToMemoryUnits(system,fieldOffset*addressType.sizeInBits);
			MakeMemory(mem,base,addressType,offset);
			Emit(Mov(position,mem,value));
			ReleaseIntermediateOperand(mem);
		END PutMathArrayField;

		PROCEDURE PutMathArrayFieldOffset(base,value: IntermediateCode.Operand; fieldOffset, offset: LONGINT);
		VAR mem: IntermediateCode.Operand;
		BEGIN
			offset := offset + ToMemoryUnits(system,fieldOffset*addressType.sizeInBits);
			MakeMemory(mem,base,addressType,offset);
			Emit(Mov(position,mem,value));
			ReleaseIntermediateOperand(mem);
		END PutMathArrayFieldOffset;

		PROCEDURE GetMathArrayField(VAR value: IntermediateCode.Operand; base: IntermediateCode.Operand; offset: LONGINT);
		BEGIN
			offset := ToMemoryUnits(system,offset*addressType.sizeInBits);
			MakeMemory(value,base,addressType,offset);
		END GetMathArrayField;

		PROCEDURE PutMathArrayLenOrIncr(CONST base,value,dim: IntermediateCode.Operand; incr: BOOLEAN);
		VAR offset: LONGINT; reg,mem: IntermediateCode.Operand;
		BEGIN
			IF incr THEN
				offset := ToMemoryUnits(system,MathIncrOffset*addressType.sizeInBits);
			ELSE
				offset := ToMemoryUnits(system,MathLenOffset*addressType.sizeInBits);
			END;
			IF dim.mode=IntermediateCode.ModeImmediate THEN
				PutMathArrayField(base,value,offset + ToMemoryUnits(system,SHORT(dim.intValue) * 2 * addressType.sizeInBits));
			ELSE
				IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,reg,dim));
				Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,2*addressType.sizeInBits))));
				Emit(Add(position,reg,reg,base));
				MakeMemory(mem, reg, addressType, offset);
				ReleaseIntermediateOperand(reg);
				Emit(Mov(position,mem,value));
				ReleaseIntermediateOperand(mem);
			END;
		END PutMathArrayLenOrIncr;

		PROCEDURE PutMathArrayLength(base,value: IntermediateCode.Operand; dim: LONGINT);
		BEGIN
			PutMathArrayField(base,value,MathLenOffset + dim * 2);
		END PutMathArrayLength;

		PROCEDURE PutMathArrayIncrement(base,value: IntermediateCode.Operand; dim: LONGINT);
		BEGIN
			PutMathArrayField(base,value,MathIncrOffset + dim * 2);
		END PutMathArrayIncrement;

		PROCEDURE GetMathArrayIncrement(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; check: BOOLEAN; VAR result: Operand);
		BEGIN
			MathArrayLenOrIncr(type,operand,dim,TRUE,check,result);
		END GetMathArrayIncrement;

		PROCEDURE GetMathArrayLength(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; check: BOOLEAN; VAR result: Operand);
		BEGIN
			MathArrayLenOrIncr(type,operand,dim,FALSE,check,result);
		END GetMathArrayLength;

		PROCEDURE GetMathArrayLengthAt(type: SyntaxTree.MathArrayType; CONST operand: Operand; dim: LONGINT; check: BOOLEAN; VAR result: Operand);
		VAR dimOp: IntermediateCode.Operand;
		BEGIN
			dimOp := IntermediateCode.Immediate(int32, dim);
			GetMathArrayLength(type, operand, dimOp, check, result);
		END GetMathArrayLengthAt;

		PROCEDURE GetMathArrayIncrementAt(type: SyntaxTree.MathArrayType; CONST operand: Operand; dim: LONGINT; check: BOOLEAN; VAR result: Operand);
		VAR dimOp: IntermediateCode.Operand;
		BEGIN
			dimOp := IntermediateCode.Immediate(int32, dim);
			GetMathArrayIncrement(type, operand, dimOp, check, result);
		END GetMathArrayIncrementAt;

		PROCEDURE MathArrayLenOrIncr(type: SyntaxTree.MathArrayType; CONST operand: Operand; VAR dim: IntermediateCode.Operand; increment: BOOLEAN; check: BOOLEAN; VAR result: Operand );
		VAR val: LONGINT; res,res2: IntermediateCode.Operand; end,next: Label; t: SyntaxTree.Type; imm: IntermediateCode.Operand; hasDynamicPart: BOOLEAN;
			offset: LONGINT;
		BEGIN
			IF increment THEN
				offset := MathIncrOffset;
			ELSE
				offset := MathLenOffset;
			END;
			INC(offset,operand.dimOffset*2);
			IF check & (type.form = SyntaxTree.Tensor) & ~isUnchecked THEN
				TrapC(BrneL,operand.tag,IntermediateCode.Immediate(addressType,0),IndexCheckTrap);
			END;
			(* static dimension *)
			IF  dim.mode = IntermediateCode.ModeImmediate THEN
				IF check & (type.form = SyntaxTree.Tensor) THEN
					DimensionCheck(operand.tag,dim,BrltL);
				END;
				val := SHORT(dim.intValue);
				IF type.form # SyntaxTree.Tensor THEN
					t := SemanticChecker.ArrayBase(type,val);
					type := t.resolved(SyntaxTree.MathArrayType);
					IF type.form = SyntaxTree.Static THEN
						IF increment THEN
							res := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,type.staticIncrementInBits));
						ELSE
							res := IntermediateCode.Immediate(addressType,type.staticLength);
						END;
						InitOperand(result,ModeValue);
						result.op := res;
						RETURN;
					END;
				END;
				offset := ToMemoryUnits(system, (val*2+offset)*addressType.sizeInBits);
				MakeMemory(res,operand.tag,addressType,offset);
				(*
				res := IntermediateCode.Memory(addressType,operand.tag,offset);
				*)
				InitOperand(result,ModeValue);
				result.op := res;
			ELSE
				Convert(dim,addressType);
				IF check THEN
					IF type.form = SyntaxTree.Tensor THEN
						DimensionCheck(operand.tag,dim,BrltL);
					ELSIF isUnchecked THEN (* do nothing *)
					ELSE
						TrapC(BrltL,dim,IntermediateCode.Immediate(addressType,SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static})), IndexCheckTrap);
					END;
				END;
				end := NewLabel(); next := NIL;

				IntermediateCode.InitRegister(res,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,res,dim));
				Convert(res,int32);

				t := type; val := operand.dimOffset; hasDynamicPart := FALSE;
				WHILE t IS SyntaxTree.MathArrayType DO
					type := t(SyntaxTree.MathArrayType);
					IF type.form = SyntaxTree.Static THEN
						imm := IntermediateCode.Immediate(int32,val);
						next := NewLabel();
						BrneL(next,imm,res);
						IF increment THEN
							imm := IntermediateCode.Immediate(int32,ToMemoryUnits(system,type.staticIncrementInBits));
						ELSE
							imm := IntermediateCode.Immediate(int32,type.staticLength);
						END;
						Emit(MovReplace(position,res,imm));
						BrL(end);
					ELSE hasDynamicPart := TRUE;
					END;
					t := type.arrayBase.resolved;
					val := val + 1;
					IF next # NIL THEN SetLabel(next) END;
				END;
				IF hasDynamicPart THEN
					IntermediateCode.InitRegister(res2,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position,res2,dim));
					Emit(Mul(position,res2,res2,IntermediateCode.Immediate(addressType,2*ToMemoryUnits(system,addressType.sizeInBits))));
					imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,offset*addressType.sizeInBits));
					Emit(Add(position,res2,res2,imm));
					Emit(Add(position,res2,res2,operand.tag));
					IntermediateCode.MakeMemory(res2,int32);
					Emit(MovReplace(position,res,res2));
					ReleaseIntermediateOperand(res2);
				END;
				SetLabel(end);
				Convert(res,int32);
				InitOperand(result,ModeValue);
				result.op := res;
			END;
		END MathArrayLenOrIncr;



		PROCEDURE ArrayLen(type: SyntaxTree.ArrayType; VAR operand: Operand; VAR dim: IntermediateCode.Operand; VAR result: Operand );
		VAR val: LONGINT; res,res2: IntermediateCode.Operand; end,next: Label; t: SyntaxTree.Type; imm: IntermediateCode.Operand; hasDynamicPart: BOOLEAN;
			offset: LONGINT;
		BEGIN
			offset := operand.dimOffset+DynamicDim(type)-1;
			IF  dim.mode = IntermediateCode.ModeImmediate THEN
				ASSERT(type.form IN {SyntaxTree.Open, SyntaxTree.SemiDynamic});
				val := SHORT(dim.intValue);
				t := SemanticChecker.ArrayBase(type,val);
				type := t.resolved(SyntaxTree.ArrayType);
				IF type.form = SyntaxTree.Static THEN
					res := IntermediateCode.Immediate(addressType,type.staticLength);
				ELSE
					offset := ToMemoryUnits(system, (offset-val)*addressType.sizeInBits);
					res := IntermediateCode.Memory(addressType,operand.tag,offset);
				END;
				UseIntermediateOperand(res);
				InitOperand(result,ModeValue);
				result.op := res;
			ELSE
				Convert(dim,addressType);
				IF ~isUnchecked THEN
					TrapC(BrltL,dim,IntermediateCode.Immediate(addressType,SemanticChecker.Dimension(type,{SyntaxTree.Open,SyntaxTree.Static})), IndexCheckTrap);
				END;

				end := NewLabel(); next := NIL;

				(* ReuseCopy(dim,res); *)
				IntermediateCode.InitRegister(res,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType, IntermediateCode.GeneralPurposeRegister));
				Emit(Mov(position,res,dim));
				Convert(res,int32);

				Convert(res,int32);
				t := type; val := operand.dimOffset; hasDynamicPart := FALSE;
				WHILE t IS SyntaxTree.ArrayType DO
					type := t(SyntaxTree.ArrayType);
					IF type.form = SyntaxTree.Static THEN
						imm := IntermediateCode.Immediate(int32,val);
						next := NewLabel();
						BrneL(next,imm,res);
						imm := IntermediateCode.Immediate(int32,type.staticLength);
						Emit(MovReplace(position,res,imm));
						BrL(end);
					ELSE hasDynamicPart := TRUE;
					END;
					t := type.arrayBase.resolved;
					val := val + 1;
					IF next # NIL THEN SetLabel(next) END;
				END;
				IF hasDynamicPart THEN
					ReuseCopy(res2,dim); (* dim is now in register res2 *)
					Convert(res2,addressType);
					Emit(Mul(position,res2,res2,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,addressType.sizeInBits))));
					imm := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,offset*addressType.sizeInBits));
					Emit(Sub(position,res2,imm,res2));
					Emit(Add(position,res2,res2,operand.tag));
					IntermediateCode.MakeMemory(res2,int32);
					Emit(MovReplace(position,res,res2));
					ReleaseIntermediateOperand(res2);
				END;
				SetLabel(end);
				Convert(res,int32);
				InitOperand(result,ModeValue);
				result.op := res;
			END;
		END ArrayLen;

		(**
			create a temporary variable in current scope
		**)
		PROCEDURE GetTemporaryVariable(type: SyntaxTree.Type; register: BOOLEAN): SyntaxTree.Variable;
		VAR name: SyntaxTree.Identifier; string: SyntaxTree.IdentifierString ; variable: SyntaxTree.Variable;
		scope: SyntaxTree.Scope; duplicate: BOOLEAN; offset, index: LONGINT;
		BEGIN
			IF ~register THEN
				variable := temporaries.GetFreeVariable(type, index);
			ELSE
				index := temporaries.registerIndex; INC(temporaries.registerIndex);
			END;
			scope := currentScope;

			IF variable = NIL THEN
				COPY("@hiddenIRVar",string);
				Basic.AppendNumber(string,index);
				name := SyntaxTree.NewIdentifier(string);

				variable := SyntaxTree.NewVariable(Diagnostics.Invalid,name);
				variable.SetType(type);
				variable.SetAccess(SyntaxTree.Hidden);
				IF ~register THEN
					temporaries.AddVariable(variable);

					IF scope.lastVariable # NIL THEN
						offset := scope.lastVariable.offsetInBits;
					ELSE
						offset := 0;
					END;
					DEC(offset,system.SizeOf(variable.type));
					Basic.Align(offset,-system.AlignmentOf(system.variableAlignment,variable.type));
					variable(SyntaxTree.Variable).SetOffset(offset);

					scope.AddVariable(variable(SyntaxTree.Variable));
					scope.EnterSymbol(variable, duplicate);
					ASSERT(~duplicate);
					InitVariable(variable(SyntaxTree.Variable));
				ELSE
					variable.SetUseRegister(TRUE);
					variable(SyntaxTree.Variable).SetOffset(0);
				END;
			ELSE
				InitVariable(variable(SyntaxTree.Variable));
				(*
				ASSERT(variable.type.resolved = type.resolved)
				*)
			END;
			RETURN variable(SyntaxTree.Variable)
		END GetTemporaryVariable;

		PROCEDURE GetMathArrayDescriptorType(dimensions: LONGINT): SyntaxTree.Type;
		VAR name: ARRAY 32 OF CHAR; symbol: SyntaxTree.Symbol; typeDeclaration: SyntaxTree.TypeDeclaration;
			recordType: SyntaxTree.RecordType; type: SyntaxTree.Type;
			recordScope: SyntaxTree.RecordScope; parentScope: SyntaxTree.Scope; identifier: SyntaxTree.Identifier;
			i: LONGINT; duplicate: BOOLEAN;

			PROCEDURE AddVariable(CONST name: ARRAY OF CHAR; type: SyntaxTree.Type);
			VAR variable: SyntaxTree.Variable;
			BEGIN
				variable := SyntaxTree.NewVariable(-1,SyntaxTree.NewIdentifier(name));
				variable.SetType(type);
				recordScope.AddVariable(variable);
			END AddVariable;


		BEGIN
			name := "@ArrayDescriptor";
			Basic.AppendNumber(name,dimensions);
			identifier := SyntaxTree.NewIdentifier(name);
			parentScope := module.module.moduleScope;
			symbol := parentScope.FindSymbol(identifier);
			IF symbol # NIL THEN
				typeDeclaration := symbol(SyntaxTree.TypeDeclaration);
				type := typeDeclaration.declaredType;
			ELSE
				typeDeclaration := SyntaxTree.NewTypeDeclaration(-1,SyntaxTree.NewIdentifier(name));
				typeDeclaration.SetAccess(SyntaxTree.Hidden);
				recordScope := SyntaxTree.NewRecordScope(parentScope);
				recordType := SyntaxTree.NewRecordType( -1, parentScope, recordScope);
				recordType.SetTypeDeclaration(typeDeclaration);
				recordType.SetState(SyntaxTree.Resolved);
				typeDeclaration.SetDeclaredType(recordType);
				AddVariable("@ptr",system.anyType);
				AddVariable("@adr",system.addressType);
				AddVariable("@flags",system.addressType);
				AddVariable("@dim",system.addressType);
				AddVariable("@elementSize",system.addressType);
				FOR i := 0 TO dimensions-1  DO
					name := "@len";
					Basic.AppendNumber(name,i);
					AddVariable(name,system.addressType);
					name := "@incr";
					Basic.AppendNumber(name,i);
					AddVariable(name,system.addressType);
				END;
				parentScope.AddTypeDeclaration(typeDeclaration);
				parentScope.EnterSymbol(typeDeclaration,duplicate);
				ASSERT(~duplicate);
				type := recordType;
			END;
			RETURN type
		END GetMathArrayDescriptorType;

		PROCEDURE NewMathArrayDescriptor(op: Operand; dimensions: LONGINT);
		VAR reg: IntermediateCode.Operand; type: SyntaxTree.Type;
		BEGIN
			type := GetMathArrayDescriptorType(dimensions);
			Emit(Push(position,op.op));
			(* push type descriptor *)
			reg := TypeDescriptorAdr(type);
			IF ~newObjectFile THEN
				IntermediateCode.MakeMemory(reg,addressType);
			END;
			Emit(Push(position,reg));
			ReleaseIntermediateOperand(reg);
			(* push realtime flag: false by default *)
			Emit(Push(position,false));
			CallThis(position,"Heaps","NewRec",3);
		END NewMathArrayDescriptor;

		PROCEDURE PushConstString(CONST s: ARRAY OF CHAR);
		VAR res: Operand; string: SyntaxTree.String; sv: SyntaxTree.StringValue; type: SyntaxTree.Type;
		BEGIN
			NEW(string, LEN(s)); COPY(s, string^);
			sv := SyntaxTree.NewStringValue(-1,string);
			type := SyntaxTree.NewStringType(-1,system.characterType,Strings.Length(s));
			sv.SetType(type);
			Designate(sv,res);
			Emit(Push(position,res.tag));
			Emit(Push(position,res.op));
			ReleaseOperand(res);
		END PushConstString;

		PROCEDURE PushConstBoolean(b: BOOLEAN);
		BEGIN
			IF b THEN
				Emit(Push(-1, true));
			ELSE
				Emit(Push(-1, false));
			END;
		END PushConstBoolean;

		PROCEDURE PushConstSet(v: SET);
		VAR value: SyntaxTree.Value; op: Operand;
		BEGIN
			value := SyntaxTree.NewSetValue(-1, v);
			value.SetType(system.setType);
			Evaluate(value, op);
			Emit(Push(-1, op.op));
			ReleaseOperand(op);
		END PushConstSet;

		PROCEDURE PushConstInteger(v: LONGINT);
		VAR value: SyntaxTree.Value; op: Operand;
		BEGIN
			value := SyntaxTree.NewIntegerValue(-1, v);
			value.SetType(system.longintType);
			Evaluate(value, op);
			Emit(Push(-1, op.op));
			ReleaseOperand(op);
		END PushConstInteger;

		
		PROCEDURE OpenInitializer(symbol: SyntaxTree.Symbol; scope: SyntaxTree.Scope): IntermediateCode.Section;
		VAR name: Basic.SegmentedName; procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope;
		 section: IntermediateCode.Section;
		BEGIN
			procedureScope := SyntaxTree.NewProcedureScope(scope);
			Global.GetSymbolSegmentedName(symbol, name);
			Basic.SuffixSegmentedName(name, Basic.MakeString("@Initializer"));
			procedure := SyntaxTree.NewProcedure(-1, SyntaxTree.NewIdentifier(""), procedureScope);
			procedure.SetScope(moduleScope);
			procedure.SetType(SyntaxTree.NewProcedureType(-1,scope));
			procedure.type(SyntaxTree.ProcedureType).SetDelegate(TRUE);
			procedure.SetAccess(SyntaxTree.Hidden);
			currentScope := procedureScope;
			section := NewSection(module.allSections, Sections.CodeSection, name, NIL,commentPrintout # NIL);
			EmitEnter(section, -1,NIL,0,0,0);
			RETURN section;
		END OpenInitializer;
		
		PROCEDURE CloseInitializer(prev: IntermediateCode.Section);
		BEGIN
			EmitLeave(section, 0, 0 );
			Emit(Exit(-1,ToMemoryUnits(system,addressType.sizeInBits),0));
			section := prev;
		END CloseInitializer;
		

		PROCEDURE AddPorts(cell: SyntaxTree.Symbol; x: SyntaxTree.CellType);
		VAR name: SyntaxTree.IdentifierString; 
			variable: SyntaxTree.Variable;
			type: SyntaxTree.Type;

			PROCEDURE Field(symbol: SyntaxTree.Symbol; VAR op: Operand);
			BEGIN
				InitOperand(op,ModeReference);
				op.op := fp;
				IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,2*addressType.sizeInBits));
				Dereference(op, x, FALSE);
				result := op;
				Symbol(symbol, op);
			END Field;
			
			PROCEDURE Direction(direction: LONGINT): SET;
			BEGIN
				IF direction = SyntaxTree.OutPort THEN RETURN {0}
				ELSIF direction = SyntaxTree.InPort THEN RETURN {1}
				ELSE HALT(100);
				END;
			END Direction;

			PROCEDURE AddPortProperty(port: SyntaxTree.Variable; modifier: SyntaxTree.Modifier; value: SyntaxTree.Expression);
			VAR name: ARRAY 256 OF CHAR; op: Operand; 
			BEGIN
					Field(port, op);
					ToMemory(op.op,addressType,0);
					Emit(Push(-1, op.op));
					ReleaseOperand(op);			
						
					Basic.GetString(modifier.identifier, name);
					PushConstString(name);

					IF SemanticChecker.IsStringType(modifier.expression.type) THEN 
						ASSERT(SemanticChecker.IsStringType(value.type));
						Designate(value, op);
						Emit(Push(modifier.position, op.tag));
						Emit(Push(modifier.position, op.op));
						ReleaseOperand(op);
						CallThis(position,"ActiveCellsRuntime","AddPortStringProperty",5);
					ELSIF (modifier.expression.type.resolved IS SyntaxTree.IntegerType) THEN
						ASSERT(value.type.resolved IS SyntaxTree.IntegerType);
						Evaluate(value, op); 
						Emit(Push(modifier.position, op.op));
						ReleaseOperand(op);
						CallThis(position,"ActiveCellsRuntime","AddPortIntegerProperty",4);
					ELSE
						CallThis(position,"ActiveCellsRuntime","AddPortFlagProperty",3);
					END;
			END AddPortProperty;
			
			PROCEDURE AddPortProperties(variable: SyntaxTree.Variable);
			VAR modifier: SyntaxTree.Modifier;
			BEGIN
				modifier := variable.modifiers;
				WHILE modifier # NIL DO
					AddPortProperty(variable,modifier, modifier.expression);
					modifier := modifier.nextModifier;
				END;
			END AddPortProperties;
			

			
			PROCEDURE Variable(name: ARRAY OF CHAR; variable: SyntaxTree.Variable);
			VAR op : Operand; portType: SyntaxTree.PortType; baseType: SyntaxTree.Type; 
				size, reg: IntermediateCode.Operand; dim, len: LONGINT;
				
				PROCEDURE PushLens(type: SyntaxTree.Type);
				BEGIN
					IF IsSemiDynamicArray(type) THEN
						PushLens(type(SyntaxTree.ArrayType).arrayBase.resolved);
						Evaluate(type(SyntaxTree.ArrayType).length, op);
						Emit(Push(-1, op.op));
						ReleaseOperand(op);
						INC(dim);
					ELSIF IsStaticArray(type) THEN
						len := len * type(SyntaxTree.ArrayType).staticLength;
						PushLens(type(SyntaxTree.ArrayType).arrayBase.resolved);
						INC(dim);
					ELSE
						baseType := type;
					END;
				END PushLens;
				
			BEGIN
				(* cell *)
					IF variable.type IS SyntaxTree.ArrayType THEN
						type := variable.type;
						dim := 0; 
						len := 1;
						PushLens(type);
						portType := baseType.resolved(SyntaxTree.PortType);
					ELSE
						portType := variable.type(SyntaxTree.PortType);
					END;
					
					PushSelfPointer();
				(* port / array of ports *)
					IF IsStaticArray(type) THEN
						PushConstInteger(len);
					END;
					Field(variable, op);
					(*left := SyntaxTree.NewSymbolDesignator(-1,left,cell); left.SetType(system.anyType);
					left := SyntaxTree.NewDereferenceDesignator(-1, left); left.SetType(x);
					d := SyntaxTree.NewSymbolDesignator(-1, left, variable); d.SetType(variable.type);
					Designate(d, op);*)
					Emit(Push(-1, op.op));
					ReleaseOperand(op);
				(* name *)
					PushConstString(name);
				(* inout *)
					PushConstSet(Direction(portType.direction));
				(* width *)
					PushConstInteger(portType.sizeInBits);
				
				IF variable.type IS SyntaxTree.PortType THEN
					CallThis(variable.position,"ActiveCellsRuntime","AddPort",6);
					AddPortProperties(variable);
				ELSIF IsStaticArray(type)THEN
					CallThis(variable.position,"ActiveCellsRuntime","AddStaticPortArray",7);
				ELSIF IsSemiDynamicArray(type) THEN
					IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					size :=  IntermediateCode.Immediate(addressType, ToMemoryUnits(system,6*addressType.sizeInBits));
					Emit(Add(position,reg, sp, size));
					(* dim *)
					PushConstInteger(dim);
					(* len array *)
					Emit(Push(position, reg));
					ReleaseIntermediateOperand(reg);
					CallThis(position,"ActiveCellsRuntime","AddPortArray",8);
					size :=  IntermediateCode.Immediate(addressType, ToMemoryUnits(system,dim*addressType.sizeInBits));
					Emit(Add(position, sp,sp, size));
				ELSE
					HALT(100);
				END;
			END Variable;
			


		BEGIN
		
			IF backend.cellsAreObjects THEN
				variable := x.cellScope.firstVariable;
				WHILE (variable # NIL) DO
					type := variable.type.resolved;
					WHILE (type IS SyntaxTree.ArrayType) DO
						type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					END;
					IF (type IS SyntaxTree.PortType) THEN (* port found *)
						Global.GetSymbolNameInScope(variable,x.cellScope,name);
						Variable(name,variable);
					END;
					variable := variable.nextVariable;
				END;
			ELSE HALT(200) 
			END;
		
			(*prevActiveCellsScope := currentActiveCellsScope;*)
			(*
			x.typeDeclaration.GetName(componentName);
			instanceType := currentActiveCellsScope.NewType(componentName); (*backend.cification.NewType(componentName);*)
			IF HasValue(x.modifiers,Global.StringDataMemorySize,dataMemorySize) THEN
				instanceType.SetDataMemorySize(dataMemorySize);
			END;
			IF HasValue(x.modifiers,Global.StringCodeMemorySize,codeMemorySize) THEN
				instanceType.SetInstructionMemorySize(codeMemorySize)
			END;
			IF HasFlag(x.modifiers, Global.StringVector) THEN
				instanceType.AddCapability(ActiveCells.VectorCapability)
			END;
			IF HasFlag(x.modifiers, Global.StringTRMS) THEN
				instanceType.AddCapability(ActiveCells.TRMSCapability)
			END;
			IF HasFlag(x.modifiers, Global.StringFloatingPoint) THEN
				instanceType.AddCapability(ActiveCells.FloatingPointCapability)
			END;
			AddDevices(instanceType, x);
			*)
			(*
			IF x.isCellNet THEN
				IF HasValue(x.modifiers,Global.StringFrequencyDivider,value) THEN backend.activeCellsSpecification.SetFrequencyDivider(value) END;
			END;
			*)

			(*currentActiveCellsScope := instanceType;*)
			(*
			parameter := x.firstParameter;
			portIndex := 0;
			WHILE parameter # NIL DO
				parameter.GetName(parameterName);
				parameterType := parameter.type.resolved;
				Parameter(parameterName, parameterType);
				(*
				IF SemanticChecker.IsStaticArray(parameterType,parameterType,len) THEN
					ParameterArray(parameterType);
					direction := Direction(parameterType(SyntaxTree.PortType).direction);
					FOR i := 0 TO len-1 DO
						COPY(parameterName,name);
						AppendIndex(name,i);
						port := instanceType.NewPort(name,direction,backend.activeCellsSpecification.GetPortAddress(portIndex));
						port.SetWidth(parameterType(SyntaxTree.PortType).sizeInBits);
						INC(portIndex);
					END;
				ELSE
					direction := Direction(parameterType(SyntaxTree.PortType).direction);
					port := instanceType.NewPort(parameterName,direction,backend.activeCellsSpecification.GetPortAddress(portIndex));
					port.SetWidth(parameterType(SyntaxTree.PortType).sizeInBits);
					INC(portIndex);
				END;
				*)
				parameter := parameter.nextParameter;
			END;
			*)
			(*
			Scope(x.cellScope);
			currentActiveCellsScope := prevActiveCellsScope;
			AddModules(instanceType,x.cellScope);
			*)
		END AddPorts;
		
	
		
		PROCEDURE AddProperty(cellType: SyntaxTree.CellType; cell: SyntaxTree.Symbol; property: SyntaxTree.Property; value: SyntaxTree.Expression);
		VAR name: ARRAY 256 OF CHAR; op: Operand;  left, d: SyntaxTree.Designator;
		BEGIN
				
				Symbol(cell,op);
				ToMemory(op.op,addressType,0);
				Emit(Push(position,op.op));
				ReleaseOperand(op);

				Global.GetSymbolNameInScope(property, cellType.cellScope , name);
				PushConstString(name);
				
				IF SemanticChecker.IsStringType(property.type) OR (property.type.resolved IS SyntaxTree.IntegerType) THEN 
					left := SyntaxTree.NewSymbolDesignator(-1,left,cell); left.SetType(system.anyType);
					left := SyntaxTree.NewDereferenceDesignator(-1, left); left.SetType(cellType);
					d := SyntaxTree.NewSymbolDesignator(-1, left, property); d.SetType(property.type);
					Designate(d, op);
					IF SemanticChecker.IsStringType(property.type) THEN 
						Emit(Push(-1, op.tag))
					END;
					Emit(Push(-1, op.op));
					ReleaseOperand(op);
				END;
				
				IF SemanticChecker.IsStringType(property.type) THEN 
					ASSERT(SemanticChecker.IsStringType(value.type));
					Designate(value, op);
					Emit(Push(property.position, op.tag));
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddStringProperty",7);
				ELSIF (property.type.resolved IS SyntaxTree.IntegerType) THEN
					ASSERT(value.type.resolved IS SyntaxTree.IntegerType);
					Evaluate(value, op); 
					Emit(Push(property.position, op.op));
					ReleaseOperand(op);
					CallThis(position,"ActiveCellsRuntime","AddIntegerProperty",5);
				ELSE
					CallThis(position,"ActiveCellsRuntime","AddFlagProperty",3);
				END;
		END AddProperty;
		
		PROCEDURE AddModifiers(cellType: SyntaxTree.CellType; cell: SyntaxTree.Symbol; modifier: SyntaxTree.Modifier);
		VAR symbol: SyntaxTree.Symbol; 
		BEGIN
			WHILE modifier # NIL DO
				symbol := cellType.cellScope.FindSymbol(modifier.identifier);
				IF (symbol # NIL) & (symbol IS SyntaxTree.Property) THEN
					AddProperty(cellType, cell, symbol(SyntaxTree.Property), modifier.expression);
				ELSE
					(*! move this check to checker *)
					Error(modifier.position, "undefined property");
				END;
				modifier := modifier.nextModifier;
			END;
		END AddModifiers;
		
		PROCEDURE AppendModifier(VAR to: SyntaxTree.Modifier; this: SyntaxTree.Modifier);
		VAR last: SyntaxTree.Modifier;
		BEGIN
			IF to = NIL THEN 
				to := SyntaxTree.NewModifier(this.position, this.identifier, this.expression);
			ELSE
				last := to;
				WHILE (last.nextModifier # NIL) & (this.identifier # last.identifier) DO
					last := last.nextModifier;
				END;
				IF last.identifier # this.identifier THEN
					ASSERT(last.nextModifier = NIL);
					last.SetNext(SyntaxTree.NewModifier(this.position, this.identifier, this.expression));
				END;
			END;
		END AppendModifier;

		PROCEDURE AppendModifiers(VAR to: SyntaxTree.Modifier; this: SyntaxTree.Modifier);
		BEGIN
			WHILE this # NIL DO
				AppendModifier(to, this);
				this := this.nextModifier;
			END;
		END AppendModifiers;
		
		PROCEDURE PushPort(p: SyntaxTree.Expression);
		VAR op: Operand;
		BEGIN
			Evaluate(p, op);
			Emit(Push(p.position, op.op));
			ReleaseOperand(op);
			(*
			WHILE (p # NIL) & ~(p.type.resolved IS SyntaxTree.CellType) DO
				p := p(SyntaxTree.Designator).left;
			END;
			IF p # NIL THEN
				Evaluate(p, op);
				Emit(Push(p.position, op.op));
				ReleaseOperand(op);
			ELSE
				Emit(Push(-1, nil));
			END;
			*)
		END PushPort;


		PROCEDURE VisitBuiltinCallDesignator(x: SyntaxTree.BuiltinCallDesignator);
		VAR
			p0,p1,p2,parameter: SyntaxTree.Expression; len,val: LONGINT; l,r: Operand; res,adr,reg: IntermediateCode.Operand; type, componentType: SyntaxTree.Type;
			constructor: SyntaxTree.Procedure; s0,s1,s2: Operand; hint: HUGEINT;
			i: LONGINT; formalParameter: SyntaxTree.Parameter;
			tmp:IntermediateCode.Operand;
			size: LONGINT; dim,openDim: LONGINT; pointer: IntermediateCode.Operand; t,t0,t1,t2: SyntaxTree.Type; trueL,falseL,ignore: Label;
			exit,else,end: Label; procedureType: SyntaxTree.ProcedureType;
			name: Basic.SegmentedName; symbol: Sections.Section; operand: Operand;
			dest: IntermediateCode.Operand;
			staticLength: LONGINT; itype: IntermediateCode.Type;
			convert,isTensor: BOOLEAN;
			recordType: SyntaxTree.RecordType;
			baseType: SyntaxTree.Type;
			flags: SET;
			left: SyntaxTree.Expression;
			call: SyntaxTree.Designator;
			procedure: SyntaxTree.Procedure;
			temporaryVariable: SyntaxTree.Variable;
			dummy: IntermediateCode.Operand;
			customBuiltin: SyntaxTree.CustomBuiltin;
			isVarPar: ARRAY 3 OF BOOLEAN;
			callsection: Sections.Section;
			segmentedName: Basic.SegmentedName;
			needsTrace: BOOLEAN;
			n: ARRAY 256 OF CHAR;
			modifier: SyntaxTree.Modifier;
			previous, init: IntermediateCode.Section;
			prevScope: SyntaxTree.Scope;

			PROCEDURE CallBodies(self: IntermediateCode.Operand; type: SyntaxTree.Type);
			VAR recordScope: SyntaxTree.RecordScope; procedure: SyntaxTree.Procedure; body: SyntaxTree.Body; flags: LONGINT;
				priority: IntermediateCode.Operand;
				op,callop: Operand;
			BEGIN
				IF type = NIL THEN RETURN END;
				type := type.resolved;
				IF type IS SyntaxTree.PointerType THEN
					type := type(SyntaxTree.PointerType).pointerBase.resolved
				END;
				IF type IS SyntaxTree.MathArrayType THEN RETURN END;
				CallBodies(self,type(SyntaxTree.RecordType).baseType);
				recordScope := type(SyntaxTree.RecordType).recordScope;
				IF recordScope.bodyProcedure # NIL THEN
					procedure := recordScope.bodyProcedure;
					body := procedure.procedureScope.body;
					Emit(Push(position,self));
					IF body.isActive THEN
						StaticCallOperand(callop,procedure);
						Emit(Push(position,callop.op));
						IF body.priority # NIL THEN Evaluate(body.priority,op); priority := op.op;
							Convert(priority,sizeType);
						ELSE priority := IntermediateCode.Immediate(sizeType,0)
						END;
						Emit(Push(position,priority));
						ReleaseIntermediateOperand(priority);
						IF backend.cooperative THEN
							Emit(Push(position,self));
							CallThis(position,"Activities","Create",3)
						ELSE
							flags := 0;
							IF body.isSafe THEN
								flags := 1;
							END;
							Emit(Push(position,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.setType),flags)));
							Emit(Push(position,self));
							CallThis(position,"Objects","CreateProcess",4)
						END;
					ELSE
						Emit(Push(position,self));
						StaticCallOperand(callop,procedure);
						Emit(Call(position,callop.op,ProcedureParametersSize(system,procedure)));
					END;
					Emit(Pop(position,self));
				END;
			END CallBodies;

			PROCEDURE PushString(op: Operand; actualType: SyntaxTree.Type);
			BEGIN
				actualType := actualType.resolved;
				IF actualType IS SyntaxTree.StringType THEN
					Emit(Push(position,IntermediateCode.Immediate(addressType,actualType(SyntaxTree.StringType).length)));
				ELSIF actualType(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
					Emit(Push(position,IntermediateCode.Immediate(addressType,actualType(SyntaxTree.ArrayType).staticLength)));
				ELSE
					tmp := op.tag;
					IntermediateCode.MakeMemory(tmp,addressType);
					Emit(Push(position,tmp));
				END;
				Emit(Push(position,op.op))
			END PushString;

			PROCEDURE PushTD(type: SyntaxTree.Type);
			VAR op: IntermediateCode.Operand;
			BEGIN
				IF type = NIL THEN Emit(Push(position,IntermediateCode.Immediate(addressType,0)))
				ELSIF type.resolved IS SyntaxTree.AnyType THEN Emit(Push(position,IntermediateCode.Immediate(addressType,1)))
				ELSE
					IF type.resolved IS SyntaxTree.PointerType THEN
						type := type.resolved(SyntaxTree.PointerType).pointerBase;
					END;
					op := TypeDescriptorAdr(type.resolved);
					IF ~newObjectFile THEN
						IntermediateCode.MakeMemory(op,addressType);
					END;
					Emit(Push(position,op));
				END
			END PushTD;


		BEGIN
			IF Trace THEN TraceEnter("VisitBuiltinCallDesignator") END;

			dest := destination; destination := emptyOperand;
			p0 := NIL; p1 := NIL; p2 := NIL; len := x.parameters.Length();
			IF len > 0 THEN p0 := x.parameters.GetExpression(0); t0 := p0.type.resolved END;
			IF len > 1 THEN p1 := x.parameters.GetExpression(1); t1 := p1.type.resolved END;
			IF len > 2 THEN p2 := x.parameters.GetExpression(2); t2 := p2.type.resolved END;

			CASE x.id OF

			(* ---- COPY ----- *)
			|Global.Copy:
				CopyString(p1,p0); (* roles exchanged: COPY ( src => dest ) *)
			(* ---- EXCL, INCL----- *)
			|Global.Excl,Global.Incl:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Convert(s1.op,setType);
				IF (s1.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
					TrapC(BrltL,s1.op,IntermediateCode.Immediate(setType,setType.sizeInBits),IndexCheckTrap);
				END;
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Reuse1(tmp,s1.op);
				ReleaseOperand(s1);
				Emit(Shl(position,tmp,IntermediateCode.Immediate(setType,1),s1.op));
				IF x.id = Global.Excl THEN
					Emit(Not(position,tmp,tmp));
					Emit(And(position,res,res,tmp));
				ELSE
					Emit(Or(position,res,res,tmp));
				END;
				ReleaseIntermediateOperand(tmp);
				Designate(p0,s0);
				ToMemory(s0.op,setType,0);
				Emit(Mov(position,s0.op,res));
				ReleaseOperand(s0); ReleaseIntermediateOperand(res);
			(* ---- DISPOSE ----- *)
			|Global.Dispose:
				Designate(p0,s0);
				Emit(Push(position,s0.op));
				ReleaseOperand(s0);
				CallThis(position,DefaultRuntimeModuleName,"Dispose", 1);
			(* ---- GETPROCEDURE ----- *)
			|Global.GetProcedure:
				Designate(p0,s0);
				PushString(s0,p0.type);
				Designate(p1,s1);
				PushString(s1,p1.type);
				procedureType := p2.type.resolved(SyntaxTree.ProcedureType);
				IF (procedureType.firstParameter = NIL) OR (procedureType.firstParameter.access = SyntaxTree.Hidden) THEN PushTD(NIL)
				ELSE PushTD(procedureType.firstParameter.type)
				END;
				PushTD(procedureType.returnType);

				Designate(p2,s2);
				Emit(Push(position,s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				CallThis(position,"Modules","GetProcedure", 7);
			(* ---- ASH, LSH, ROT ----- *)
			|Global.Ash, Global.Asr, Global.Lsh, Global.Rot, Global.Ror:
				Evaluate(p0,s0);
				IF (x.id = Global.Lsh) OR (x.id = Global.Rot) OR (x.id = Global.Ror)THEN
					(* make unsigned arguments in order to produced a logical shift *)
					IF s0.op.type.form = IntermediateCode.SignedInteger THEN
						convert:= TRUE;
						itype := s0.op.type;
						IntermediateCode.InitType(itype,IntermediateCode.UnsignedInteger,s0.op.type.sizeInBits);
						Convert(s0.op,itype);
					ELSE
						convert := FALSE;
					END;
				END;
				Evaluate(p1,s1);
				IF IsIntegerConstant(p1,hint) THEN
					ReuseCopy(reg,s0.op);
					IF hint  > 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,hint);
						IF x.id = Global.Ash THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,s0.op,s1.op))
						END;
					ELSIF hint < 0 THEN
						IntermediateCode.InitImmediate(s1.op,s1.op.type,-hint);
						IF x.id = Global.Ash THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,s0.op,s1.op));
						ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,s0.op,s1.op))
						ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,s0.op,s1.op))
						END;
					END;
					ReleaseOperand(s0); ReleaseOperand(s1);
				ELSE
					exit := NewLabel();
					end := NewLabel();
					ReuseCopy(reg,s0.op);
					BrgeL(exit,s1.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p1.type),0));
					Reuse1(tmp,s1.op);
					Emit(Neg(position,tmp,s1.op));
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shr(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shl(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					BrL(end);
					SetLabel(exit);
					ReuseCopy(tmp,s1.op);
					Convert(tmp,s1.op.type);
					IF x.id = Global.Ash THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Lsh THEN Emit(Shl(position,reg,reg,tmp))
					ELSIF x.id = Global.Rot THEN Emit(Rol(position,reg,reg,tmp))
					ELSIF x.id = Global.Ror THEN Emit(Ror(position,reg,reg,tmp))
					ELSIF x.id = Global.Asr THEN Emit(Shr(position,reg,reg,tmp))
					END;
					ReleaseIntermediateOperand(tmp);
					SetLabel(end);
					ReleaseOperand(s0); ReleaseOperand(s1);
				END;
				InitOperand(result,ModeValue);
				IF convert THEN
					itype := reg.type;
					IntermediateCode.InitType(itype,IntermediateCode.SignedInteger,reg.type.sizeInBits);
					Convert(reg,itype);
				END;
				result.op := reg;
			(* ---- CAP ----- *)
			|Global.Cap:
				Evaluate(p0,result);
				ReuseCopy(reg,result.op);
				ReleaseIntermediateOperand(result.op);
				ignore := NewLabel();
				BrltL(ignore, reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("a")));
				BrltL(ignore,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),ORD("z")),reg);
				Emit(And(position,reg,reg,IntermediateCode.Immediate(IntermediateCode.GetType(system,system.characterType),5FH)));
				SetLabel(ignore);
				result.op := reg;
			(* ---- CHR ----- *)
			|Global.Chr, Global.Chr32:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			|Global.Entier, Global.EntierH:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- MIN and MAX ----- *)
			|Global.Max,Global.Min:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Reuse2(res,s0.op,s1.op);
				else := NewLabel();
				IF x.id = Global.Max THEN BrltL(else,s0.op,s1.op);
				ELSE BrltL(else,s1.op,s0.op) END;
				Emit(Mov(position,res,s0.op));
				ReleaseOperand(s0);
				end := NewLabel();
				BrL(end);
				SetLabel(else);
				Emit(MovReplace(position,res,s1.op));
				SetLabel(end);
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- ODD ----- *)
			|Global.Odd:
				IF ~conditional THEN
					ConditionToValue(x)
				ELSE
					Evaluate(p0,result);
					res := IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1);
					Reuse1(res,result.op);
					Emit(And(position,res,result.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
					ReleaseIntermediateOperand(result.op);
					result.op := res;
					BreqL(trueLabel,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1),result.op);
					ReleaseOperand(result);
					BrL(falseLabel);
				END;
			(* ---- ORD ----- *)
			|Global.Ord, Global.Ord32:
				Evaluate(p0,result);
				Convert(result.op,IntermediateCode.GetType(system,x.type));
			(* ---- SHORT, LONG ----- *)
			|Global.Short, Global.Long:
				Evaluate(p0,result);
				IF x.type IS SyntaxTree.ComplexType THEN
					componentType := x.type(SyntaxTree.ComplexType).componentType;
					Convert(result.op, IntermediateCode.GetType(system, componentType));
					Convert(result.tag, IntermediateCode.GetType(system, componentType));
				ELSE
					Convert(result.op,IntermediateCode.GetType(system,x.type));
				END
			(* ---- HALT, SYSTEM.HALT----- *)
			|Global.Halt, Global.systemHalt:
				val := p0.resolved(SyntaxTree.IntegerValue).value;
				EmitTrap (position, val);
			(* ---- ASSERT ----- *)
			|Global.Assert:
				IF ~backend.noAsserts & (p0.resolved = NIL) THEN
					trueL := NewLabel();
					falseL := NewLabel();
					Condition(p0,trueL,falseL);

					IF p1 = NIL THEN val := AssertTrap
					ELSE val := p1.resolved(SyntaxTree.IntegerValue).value;
					END;

					SetLabel(falseL);
					EmitTrap(position,val);
					SetLabel(trueL);
				END;

				(*
				Emit(TrapC(result.op,val);
				*)
			(* ---- INC, DEC----- *)
			|Global.Inc,Global.Dec:
				Expression(p0); adr := result.op;
				LoadValue(result,p0.type); l := result;
				IF p1 = NIL THEN r.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1);
				ELSE Expression(p1); LoadValue(result,p1.type); r := result;
				END;
				IF x.id = Global.Inc THEN
					Emit(Add(position,l.op,l.op,r.op));
				ELSE
					Emit(Sub(position,l.op,l.op,r.op));
				END;
				ReleaseOperand(l); ReleaseOperand(r);
			(* ---- LEN ----- *)
			|Global.Len: (* dynamic length, static length done by checker  *)
				Designate(p0,operand);
				IF p1 = NIL THEN
					InitOperand(l,ModeValue);
					l.op := IntermediateCode.Immediate(int32,0);
				ELSE
					Evaluate(p1,l);
				END;
				IF p0.type.resolved IS SyntaxTree.ArrayType THEN
					IF (p0.type.resolved(SyntaxTree.ArrayType).form= SyntaxTree.SemiDynamic) THEN
						Dereference(operand, p0.type.resolved, FALSE);
					END;
					ArrayLen(p0.type.resolved(SyntaxTree.ArrayType),operand,l.op, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSIF p0.type.resolved IS SyntaxTree.MathArrayType THEN
					ASSERT(p1 # NIL);
					IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
						Dereference(operand,p0.type.resolved,FALSE);
					END;
					GetMathArrayLength(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op, TRUE, result);
					ReleaseOperand(operand); ReleaseOperand(l);
				ELSE HALT(100);
				END;
				Convert(result.op,IntermediateCode.GetType(system, x.type));

			(* ---- FIRST ---- *)
			|Global.First:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).first, result)
				ELSE
					Designate(p0, result)
				END

			(* ---- LAST ---- *)
			|Global.Last:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).last, result)
				ELSE
					Designate(p0, result);
					(* make sure result.op is a register *)
					tmp := result.op;
					ReuseCopy(result.op, result.op);
					ReleaseIntermediateOperand(tmp);
					(* add offset to result.op *)
					IntermediateCode.AddOffset(result.op, ToMemoryUnits(system, system.SizeOf(system.longintType)))
				END

			(* ---- STEP ---- *)
			|Global.Step:
				IF p0 IS SyntaxTree.RangeExpression THEN (* optimization, could also work with designate *)
					Evaluate(p0(SyntaxTree.RangeExpression).step, result)
				ELSE
					Designate(p0, result);

					(* make sure result.op is a register *)
					tmp := result.op;
					ReuseCopy(result.op, result.op);
					ReleaseIntermediateOperand(tmp);

					(* add offset to result.op *)
					IntermediateCode.AddOffset(result.op, 2 * ToMemoryUnits(system, system.SizeOf(system.longintType)))
				END

			(* ---- RE ---- *)
			|Global.Re:
				IF p0.type.resolved IS SyntaxTree.ComplexType THEN
					Designate(p0, result)
				ELSE
					Evaluate(p0, result)
				END

			(* ---- IM ---- *)
			|Global.Im:
				ASSERT(p0.type.resolved IS SyntaxTree.ComplexType);
				componentType := p0.type.resolved(SyntaxTree.ComplexType).componentType;

				Designate(p0, result);

				(* make sure result.op is a register *)
				tmp := result.op;
				ReuseCopy(result.op, result.op);
				ReleaseIntermediateOperand(tmp);
				(* add offset to result.op *)
				IntermediateCode.AddOffset(result.op, ToMemoryUnits(system, system.SizeOf(componentType)));

			(* ---- ABS ----- *)
			|Global.Abs:
				Evaluate(p0,operand);
				type := p0.type.resolved;
				InitOperand(result,ModeValue);
				Reuse1a(result.op,operand.op,dest);
				Emit(Abs(position,result.op,operand.op));
				ReleaseOperand(operand);
			(* ---- WAIT ----- *)
			|Global.Wait:
				Evaluate(p0,operand);
				Emit(Push(position,operand.op));
				ReleaseOperand(operand);
				CallThis(position,"Activities","Wait", 1);
			(* ---- NEW ----- *)
			|Global.New:
				(*! the following code is only correct for "standard" Oberon calling convention *)
				type := p0.type.resolved;
				IF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType)
				THEN
					recordType := type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType);
					IF backend.cooperative THEN
						size := ToMemoryUnits(system,system.SizeOf(recordType));
						IF ~type(SyntaxTree.PointerType).isPlain THEN
							IF recordType.isObject THEN
								INC (size, BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
								IF recordType.IsActive() THEN
									INC (size, ActionTypeSize * ToMemoryUnits(system,addressType.sizeInBits))
								END;
								IF recordType.IsProtected() THEN
									INC (size, MonitorTypeSize * ToMemoryUnits(system,addressType.sizeInBits))
								END;
							ELSE
								INC (size, BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
							END;
						END;
						Emit(Push(position,IntermediateCode.Immediate(sizeType,size)));
						CallThis(position,"Runtime","New", 1);
						pointer := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
						Emit(Result(position, pointer));
						exit := NewLabel();
						BreqL(exit,pointer,nil);
						IF ~type(SyntaxTree.PointerType).isPlain THEN
							GetRecordTypeName (recordType,name);
							IF ~recordType.isObject THEN
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
							END;
							IntermediateCode.InitAddress(adr, addressType, name , 0, 0);
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,0),adr));
							IF recordType.isObject THEN
								IF recordType.IsProtected() THEN
									DEC (size, MonitorTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
									Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,MonitorOffset * ToMemoryUnits(system,addressType.sizeInBits)), IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,size)));
								END;
								IF recordType.IsActive() THEN
									DEC (size, ActionTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
									Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ActionOffset * ToMemoryUnits(system,addressType.sizeInBits)), IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,size)));
								END;
							END;
						END;
						
						(* initialize fields *)
						IF type(SyntaxTree.PointerType).isPlain THEN
							size := 0;
						ELSIF recordType.isObject THEN
							size := BaseObjectTypeSize;
						ELSE
							size := BaseRecordTypeSize;
						END;
						InitFields(recordType, pointer,size*ToMemoryUnits(system,addressType.sizeInBits));

						(* call initializer *)
						constructor := GetConstructor(recordType);
						IF constructor # NIL THEN
							(*! should be unified with ProcedureCallDesignator *)
							Emit(Push(position,pointer));
							ReleaseIntermediateOperand(pointer);
							formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
							FOR i := 1 TO x.parameters.Length()-1 DO
								PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
								formalParameter := formalParameter.nextParameter;
							END;

							(* static call of the constructor *)
							GetCodeSectionNameForSymbol(constructor,name);
							ASSERT(~constructor.isInline);
							IF constructor.scope.ownerModule # module.module THEN
								symbol := NewSection(module.importedSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
							ELSE
								symbol := NewSection(module.allSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
							END;
							Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcedureParametersSize(system,constructor) - ToMemoryUnits(system,addressType.sizeInBits)));
							IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Pop(position,pointer));
						END;

						(* call bodies *)
						CallBodies(pointer,p0.type);
						
						
						SetLabel(exit);
						needsTrace := p0.NeedsTrace();
						IF needsTrace THEN ModifyAssignments(true) END;
						IF ~type(SyntaxTree.PointerType).isDisposable THEN
							Emit(Push(position, pointer));
							CallThisChecked(position,"GarbageCollector","Watch",0,FALSE);
							Emit(Pop(position, pointer));
						END;
						Designate(p0,l);
						IF needsTrace THEN
							CallAssignPointer(l.op, pointer);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseIntermediateOperand(pointer);
						ReleaseOperand(l);
						IF needsTrace THEN ModifyAssignments(false) END;
					ELSE
						temporaryVariable := GetTemporaryVariable(type, FALSE);
						IF temporaryVariable # NIL THEN
							Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
						ELSE
							Designate(p0,l);
						END;
						(* l.op contains address of pointer to record *)
						Emit(Push(position,l.op)); (* address for use after syscall *)
						Emit(Push(position,l.op));
						ReleaseOperand(l);

						(* push type descriptor *)
						reg := TypeDescriptorAdr(recordType);
						IF ~newObjectFile THEN
							IntermediateCode.MakeMemory(reg,addressType);
						END;
						Emit(Push(position,reg));
						ReleaseIntermediateOperand(reg);

						(* push realtime flag *)
						IF (p0.type.resolved.isRealtime) THEN Emit(Push(position,true));
						ELSE Emit(Push(position,false));
						END;

						CallThis(position,"Heaps","NewRec", 3);
						(* check allocation success, if not successful then do not call initializers and bodies *)
						IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						Emit(Pop(position,pointer));
						MakeMemory(reg,pointer,addressType,0);
						ReleaseIntermediateOperand(pointer);
						pointer := reg;
						exit := NewLabel();
						BreqL(exit,pointer,nil);
						Emit(Push(position,pointer));

						(* initialize fields *)
						InitFields(recordType, pointer,0);

						(* call initializer *)
						constructor := GetConstructor(recordType);
						IF constructor # NIL THEN
							(*! should be unified with ProcedureCallDesignator *)
							Emit(Push(position,pointer));
							ReleaseIntermediateOperand(pointer);
							formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
							FOR i := 1 TO x.parameters.Length()-1 DO
								PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
								formalParameter := formalParameter.nextParameter;
							END;
							(* static call of the constructor *)
							GetCodeSectionNameForSymbol(constructor,name);
							ASSERT(~constructor.isInline);
							IF constructor.scope.ownerModule # module.module THEN
								symbol := NewSection(module.importedSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
							ELSE
								symbol := NewSection(module.allSections, Sections.CodeSection, name,constructor,commentPrintout # NIL);
							END;
							Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcedureParametersSize(system,constructor)));
						ELSE
							ReleaseIntermediateOperand(pointer);
						END;

						IntermediateCode.InitRegister(pointer,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						Emit(Pop(position,pointer));

						IF temporaryVariable # NIL THEN
							Designate(p0,l);
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
							ReleaseOperand(l);
							result.tag := emptyOperand;
						END;

						(* call bodies *)
						CallBodies(pointer,p0.type);
						ReleaseIntermediateOperand(pointer);

						IF temporaryVariable # NIL THEN
							end := NewLabel();
							BrL(end);
							SetLabel(exit);
							Designate(p0,l);
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,nil)); (* write NIL to adr *)
							ReleaseOperand(l);
							SetLabel(end);
						ELSE
							SetLabel(exit);
						END;
					END;
				ELSIF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType)  THEN
					type := type(SyntaxTree.PointerType).pointerBase.resolved;

					dim := 0;

					IF p1 # NIL THEN
						FOR i := 1 TO x.parameters.Length()-1 DO
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
							parameter := x.parameters.GetExpression(i);
							Evaluate(parameter,r);
							IF (r.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
								IntermediateCode.InitImmediate(tmp,IntermediateCode.GetType(system,parameter.type),0);
								TrapC(BrgeL,r.op,tmp,ArraySizeTrap);
							END;
							Emit(Push(position,r.op));
							IF i=1 THEN
								ReuseCopy(reg,r.op);
							ELSE
								Emit(Mul(position,reg,reg,r.op)); (*! optimize the multiplication of immediate operands *)
							END;
							ReleaseOperand(r);
							INC(dim);
						END;
						Convert(reg,addressType);
					ELSE
						IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						Emit(Mov(position,reg,IntermediateCode.Immediate(addressType,1)));
					END;

					openDim := dim;
					ASSERT(~(type IS SyntaxTree.ArrayType) OR (type(SyntaxTree.ArrayType).form = SyntaxTree.Static));
					
					IF backend.cooperative THEN

						size := ToMemoryUnits(system,system.SizeOf(type));
						WHILE type IS SyntaxTree.ArrayType DO
							type := type(SyntaxTree.ArrayType).arrayBase.resolved;
						END;
						size := size DIV ToMemoryUnits(system,system.SizeOf(type));
						IF (size # 1) THEN
							Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,size))); (*! optimize the multiplication of immediate operands *)
						END;
						Emit(Push(position,reg));
						size := ToMemoryUnits(system,system.SizeOf(type));
						IF (size # 1) THEN
							Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,size))); (*! optimize the multiplication of immediate operands *)
						END;
						Emit(Add(position,reg,reg,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,(BaseArrayTypeSize + openDim)* system.addressSize))));
						Emit(Push(position,reg));
						ReleaseIntermediateOperand(reg);
						CallThis(position,"Runtime","New", 1);

						pointer := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
						Emit(Result(position, pointer));
						exit := NewLabel();
						else := NewLabel();
						BreqL(else,pointer,nil);
						
						IF ~type.hasPointers THEN 
							Basic.ToSegmentedName ("BaseTypes.Array",name);
						ELSIF type IS SyntaxTree.RecordType THEN
							Basic.ToSegmentedName ("BaseTypes.RecordArray",name);
						ELSIF type IS SyntaxTree.ProcedureType THEN
							Basic.ToSegmentedName ("BaseTypes.DelegateArray",name);
						ELSE
							Basic.ToSegmentedName ("BaseTypes.PointerArray",name);
						END;
						Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,0),IntermediateCode.Address(addressType,name,0,0)));

						Emit(Pop(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,LengthOffset * system.addressSize))));
						Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DataOffset * system.addressSize)),IntermediateCode.RegisterOffset(addressType,IntermediateCode.GeneralPurposeRegister,pointer.register,ToMemoryUnits(system,(BaseArrayTypeSize + openDim)* system.addressSize))));
						IF type IS SyntaxTree.RecordType THEN
							GetRecordTypeName(type(SyntaxTree.RecordType),name);
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DescriptorOffset * system.addressSize)),IntermediateCode.Address(addressType,name,0,0)));
						ELSE
							Emit(Mov(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,DescriptorOffset * system.addressSize)),nil));
						END;
						
						i := openDim;
						WHILE i > 0 DO
							DEC (i);
							Emit(Pop(position,IntermediateCode.Memory(addressType,pointer,ToMemoryUnits(system,(BaseArrayTypeSize + i)* system.addressSize))));
						END;

						needsTrace := p0.NeedsTrace();
						IF needsTrace THEN ModifyAssignments(true) END;
						IF ~p0.type.resolved(SyntaxTree.PointerType).isDisposable THEN
							Emit(Push(position, pointer));
							CallThisChecked(position,"GarbageCollector","Watch",0,FALSE);
							Emit(Pop(position, pointer));
						END;
						Designate(p0,l);
						IF needsTrace THEN
							CallAssignPointer(l.op, pointer);
							ModifyAssignments(false);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseIntermediateOperand(pointer);
						ReleaseOperand(l);
						BrL(exit);

						SetLabel(else);
						Emit(Add(position,sp,sp,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,(openDim+1)*system.addressSize))));
						Designate(p0,l);
						IF needsTrace THEN
							CallResetProcedure(l.op,l.tag,p0.type.resolved);
						ELSE
							ToMemory(l.op,addressType,0);
							Emit(Mov(position,l.op,pointer));
						END;
						ReleaseOperand(l);
						SetLabel(exit);

					ELSE

						(*! the following code is only correct for "standard" Oberon calling convention *)
						IF SemanticChecker.ContainsPointer(type) THEN
							IF type IS SyntaxTree.ArrayType THEN
								staticLength := 1;
								WHILE (type IS SyntaxTree.ArrayType) DO (* static array *)
									staticLength := staticLength * type(SyntaxTree.ArrayType).staticLength;
									type := type(SyntaxTree.ArrayType).arrayBase.resolved;
								END;
								tmp := IntermediateCode.Immediate(reg.type,staticLength);
								Emit(Mul(position,reg,reg,tmp));
							END;
							Designate(p0,l);
							IF openDim > 0 THEN
								Emit(Push(position,l.op)); (* address for use after syscall *)
							END;
							Emit(Push(position,l.op)); (* address *)
							ReleaseOperand(l);

							tmp := TypeDescriptorAdr(type);
							IF ~newObjectFile THEN
								IntermediateCode.MakeMemory(tmp,addressType);
							END;
							Emit(Push(position,tmp)); (* type descriptor *)
							ReleaseIntermediateOperand(tmp);

							Emit(Push(position,reg)); (* number Elements *)
							ReleaseIntermediateOperand(reg);
							tmp := IntermediateCode.Immediate(addressType,dim);
							Emit(Push(position,tmp)); (* dimensions *)
							(* push realtime flag *)
							IF (p0.type.resolved.isRealtime) THEN Emit(Push(position,true));
							ELSE Emit(Push(position,false));
							END;
							CallThis(position,"Heaps","NewArr",5)
						ELSE
							size := ToMemoryUnits(system,system.SizeOf(type));
							IF (size # 1) THEN
								Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,size))); (*! optimize the multiplication of immediate operands *)
							END;
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,ArrayDimTable * system.addressSize+ system.addressSize+  system.addressSize * 2 * (openDim DIV 2)));
							(* DIV 2 term for some strange alignment, don't understand it at the moment - copied from PCC *)
							Emit(Add(position,reg,reg,tmp));
							Designate(p0,l);
							IF openDim >0 THEN
								Emit(Push(position,l.op)); (* address for use after syscall *)
							END;
							Emit(Push(position,l.op)); (* address for syscall *)
							ReleaseOperand(l); (* pointer address *)

							Emit(Push(position,reg)); (* size *)
							ReleaseIntermediateOperand(reg);
							(* push realtime flag *)
							IF (p0.type.resolved.isRealtime) THEN Emit(Push(position,true));
							ELSE Emit(Push(position,false));
							END;
							CallThis(position,"Heaps","NewSys", 3)
						END;

						IF openDim > 0 THEN
							IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Pop(position,adr));
							ToMemory(adr,addressType,0);
							ReuseCopy(tmp,adr);
							ReleaseIntermediateOperand(adr);
							adr := tmp;

							else := NewLabel();
							BreqL(else,adr,IntermediateCode.Immediate(addressType,0));

							i := openDim-1;
							IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							WHILE (i >= 0) DO
								Emit(Pop(position,reg));
								IntermediateCode.InitMemory(res,addressType,adr,ToMemoryUnits(system,ArrayDimTable* system.addressSize + system.addressSize*((openDim-1)-i)));
								Emit(Mov(position,res,reg));
								DEC(i);
							END;
							ReleaseIntermediateOperand(adr);
							ReleaseIntermediateOperand(reg);

							exit := NewLabel();
							BrL(exit);
							SetLabel(else);
							(* else part: array could not be allocated *)
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,openDim*system.addressSize));
							Emit(Add(position,sp,sp,tmp));
							SetLabel(exit);
						END;
					END;
				ELSIF (type IS SyntaxTree.MathArrayType) THEN
					IF t1 IS SyntaxTree.MathArrayType THEN (* NEW(a, array) *)
						IF GetRuntimeProcedure("FoxArrayBase","AllocateTensorX",procedure,TRUE) THEN
							left := SyntaxTree.NewSymbolDesignator(Diagnostics.Invalid,NIL,procedure);
							procedureType := procedure.type(SyntaxTree.ProcedureType);
							left.SetType(procedure.type);
							formalParameter := procedureType.firstParameter;
							(* push array to allocate *)
							PushParameter(p0, formalParameter, procedureType.callingConvention, FALSE, dummy,-1);
							formalParameter :=formalParameter.nextParameter;
							(* push length array *)
							PushParameter(p1, formalParameter, procedureType.callingConvention, FALSE, dummy,-1);
							(* push size *)
							type := t0;
							WHILE (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
								type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
							END;
							tmp := IntermediateCode.Immediate(IntermediateCode.GetType(system, system.longintType),ToMemoryUnits(system,system.SizeOf(type))); (* alignment *)
							Emit(Push(position,tmp));
							(* *)
							IF SemanticChecker.ContainsPointer(type) THEN
								tmp := TypeDescriptorAdr(type);
								IF ~newObjectFile THEN
									IntermediateCode.MakeMemory(tmp,addressType);
								END;
							ELSE
								tmp := IntermediateCode.Immediate(addressType, 0);
							END;
							Emit(Push(position,tmp)); (* type descriptor *)

							StaticCallOperand(result,procedure);
							Emit(Call(position,result.op,ProcedureParametersSize(system,procedure)));
							ReleaseOperand(result);
						END;
						(*
						designator := SyntaxTree.NewIdentifierDesignator(InvalidPosition, Global.ArrayBaseName);
						designator := SyntaxTree.NewSelectorDesignator(InvalidPosition, designator, SyntaxTree.NewIdentifier(InvalidPosition, "AllocateTensorX"));
						result := ResolveExpression(SyntaxTree.NewParameterDesignator(InvalidPosition, designator, actualParameters));
						*)
					ELSE

						dim := 0;

						IF type(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
							(* generate geometry descriptor *)
							Designate(p0,l);
							NewMathArrayDescriptor(l, x.parameters.Length()-1);
							ReleaseOperand(l);
							isTensor := TRUE;
						ELSE
							isTensor := FALSE;
						END;

						FOR i := 1 TO x.parameters.Length()-1 DO
							IF ~isTensor THEN
								type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
							END;
							parameter := x.parameters.GetExpression(i);
							Evaluate(parameter,r);
							IF (r.op.mode # IntermediateCode.ModeImmediate) & ~isUnchecked THEN
								IntermediateCode.InitImmediate(tmp,IntermediateCode.GetType(system,parameter.type),0);
								TrapC(BrgeL,r.op,tmp,ArraySizeTrap);
							END;
							Emit(Push(position,r.op));
							IF i=1 THEN
								ReuseCopy(reg,r.op);
							ELSE
								Emit(Mul(position,reg,reg,r.op)); (*! optimize the multiplication of immediate operands *)
							END;
							ReleaseOperand(r);
							INC(dim);
						END;
						Convert(reg,addressType);

						openDim := dim;
						ASSERT(~(type IS SyntaxTree.MathArrayType) OR (type(SyntaxTree.MathArrayType).form IN {SyntaxTree.Static,SyntaxTree.Tensor}));

						(*! the following code is only correct for "standard" Oberon calling convention *)
						IF SemanticChecker.ContainsPointer(SemanticChecker.ArrayBase(type,MAX(LONGINT))) THEN
							t := type;
							IF ~isTensor & (t IS SyntaxTree.MathArrayType) THEN
								staticLength := 1;
								WHILE (t IS SyntaxTree.MathArrayType) DO (* static array *)
									staticLength := staticLength * t(SyntaxTree.MathArrayType).staticLength;
									t := t(SyntaxTree.MathArrayType).arrayBase.resolved;
								END;
								tmp := IntermediateCode.Immediate(reg.type,staticLength);
								Emit(Mul(position,reg,reg,tmp));
							END;
							Designate(p0,l);
							IF isTensor THEN
								Dereference(l,type,FALSE);
								t := SemanticChecker.ArrayBase(type,MAX(LONGINT));
							END;
							Emit(Push(position,l.tag)); (* address for use after syscall *)
							Emit(Push(position,l.tag)); (* address *)
							ReleaseOperand(l);

							tmp := TypeDescriptorAdr(t);
							IF ~newObjectFile THEN
								IntermediateCode.MakeMemory(tmp,addressType);
							END;
							Emit(Push(position,tmp)); (* type descriptor *)
							ReleaseIntermediateOperand(tmp);

							Emit(Push(position,reg)); (* number Elements *)
							ReleaseIntermediateOperand(reg);
							tmp := IntermediateCode.Immediate(addressType,0);
							Emit(Push(position,tmp)); (* dimensions = 0, we control dimensions in the geometry descriptor *)
							(* push realtime flag: false by default *)
							Emit(Push(position,false));
							CallThis(position,"Heaps","NewArr",5);
							IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Pop(position,adr));
							GetMathArrayField(tmp,adr,MathPtrOffset);
							IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,ArrDataArrayOffset))));
							PutMathArrayField(adr,reg,MathAdrOffset);
							ReleaseIntermediateOperand(tmp);
							ReleaseIntermediateOperand(reg);
						ELSE
							IF isTensor THEN
								size := ToMemoryUnits(system,system.AlignedSizeOf(SemanticChecker.ArrayBase(type,MAX(LONGINT))));
							ELSE
								size := ToMemoryUnits(system,system.AlignedSizeOf(SemanticChecker.ArrayBase(type,openDim)));
							END;
							IF (size # 1) THEN
								Emit(Mul(position,reg,reg,IntermediateCode.Immediate(addressType,size))); (*! optimize the multiplication of immediate operands *)
							END;
							tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,SysDataArrayOffset));
							Emit(Add(position,reg,reg,tmp));

							Designate(p0,l);
							IF isTensor THEN
								Dereference(l,type,FALSE);
							END;
							Emit(Push(position,l.tag)); (* address for use after syscall *)
							Emit(Push(position,l.tag)); (* address for syscall *)
							ReleaseOperand(l); (* pointer address *)

							Emit(Push(position,reg)); (* size *)
							ReleaseIntermediateOperand(reg);
							(* push realtime flag: false by default *)
							Emit(Push(position,false));
							CallThis(position,"Heaps","NewSys",3);
							IntermediateCode.InitRegister(adr,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Pop(position,adr));
							GetMathArrayField(tmp,adr,MathPtrOffset);
							IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
							Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,SysDataArrayOffset))));
							PutMathArrayField(adr,reg,MathAdrOffset);
							ReleaseIntermediateOperand(tmp);
							ReleaseIntermediateOperand(reg);
						END;


						flags := {};
						IntermediateCode.InitImmediate(tmp,addressType,SYSTEM.VAL(LONGINT,flags));
						PutMathArrayField(adr,tmp,MathFlagsOffset);
						IntermediateCode.InitImmediate(tmp,addressType,openDim);
						PutMathArrayField(adr,tmp,MathDimOffset);

						else := NewLabel();
						BreqL(else,IntermediateCode.Memory(addressType,adr,0),IntermediateCode.Immediate(addressType,0));

						i := openDim-1;
						IntermediateCode.InitRegister(reg,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
						IF isTensor THEN
							IntermediateCode.InitImmediate(tmp,addressType,ToMemoryUnits(system,system.AlignedSizeOf(SemanticChecker.ArrayBase(type,MAX(LONGINT)))));
						ELSE
							IntermediateCode.InitImmediate(tmp,addressType,ToMemoryUnits(system,system.AlignedSizeOf(SemanticChecker.ArrayBase(type,openDim))));
						END;
						PutMathArrayField(adr,tmp,MathElementSizeOffset);
						WHILE (i >= 0) DO
							Emit(Pop(position,reg));
							PutMathArrayLength(adr,reg,i);
							PutMathArrayIncrement(adr,tmp,i);
							IF i > 0 THEN
								IF i=openDim-1 THEN
									ReuseCopy(tmp,tmp);
								END;
								Emit(Mul(position,tmp,tmp,reg));
							END;
							DEC(i);
						END;
						ReleaseIntermediateOperand(adr);
						ReleaseIntermediateOperand(reg);
						ReleaseIntermediateOperand(tmp);

						exit := NewLabel();
						BrL(exit);
						SetLabel(else);
						(* else part: array could not be allocated *)
						tmp := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,openDim*system.addressSize));
						Emit(Add(position,sp,sp,tmp));

						SetLabel(exit);
					END;
				ELSIF (type IS SyntaxTree.PointerType) & (type(SyntaxTree.PointerType).pointerBase.resolved  IS SyntaxTree.CellType) 
				THEN
					IF ~backend.cellsAreObjects THEN RETURN END;
					IF InCellScope(currentScope) THEN
						PushSelfPointer()
					ELSE
						Emit(Push(position, nil));
					END;
					(* push temp address *)
					baseType := type(SyntaxTree.PointerType).pointerBase.resolved; 
					temporaryVariable := GetTemporaryVariable(type, FALSE);
					Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
					(* l.op contains address of pointer to record *)
					Emit(Push(position,l.op)); (* address for use after syscall *)
					ReleaseOperand(l);
					
					(* push type descriptor *)
					reg := TypeDescriptorAdr(baseType);
					IF ~newObjectFile THEN
						IntermediateCode.MakeMemory(reg,addressType);
					END;
					Emit(Push(position,reg));
					ReleaseIntermediateOperand(reg);

					(* push name *)
					(*Global.GetSymbolName(p0, n);*)

					IF currentScope IS SyntaxTree.ProcedureScope THEN
						Global.GetSymbolName(currentScope(SyntaxTree.ProcedureScope).ownerProcedure, n)
					ELSE
						Global.GetModuleName(module.module, n);
					END;
					Strings.Append(n,"@"); Strings.AppendInt(n, p0.position);
					(*type.typeDeclaration.GetName(n);*)
					PushConstString(n);
					
					(* push cellnet boolean *)
					PushConstBoolean(baseType(SyntaxTree.CellType).isCellNet);
					(* push engine boolean *)
					PushConstBoolean(baseType(SyntaxTree.CellType).FindProperty(Global.NameEngine) # NIL);
					(* allocate *)
					CallThis(position,"ActiveCellsRuntime","Allocate",7);
					
					
					(* add capabilities *)
					modifier := p0(SyntaxTree.Designator).modifiers;
					
					IF (p0 IS SyntaxTree.SymbolDesignator) & (p0(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Variable) THEN
						(*modifier := p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).modifiers;*)
						AppendModifiers(modifier, p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Variable).modifiers );
						(* AddModifiers(baseType(SyntaxTree.CellType), temporaryVariable, modifier);*)
					END;
					AppendModifiers(modifier, baseType(SyntaxTree.CellType).modifiers);
					(*
					modifier := baseType(SyntaxTree.CellType).modifiers;
					AddProperties(baseType(SyntaxTree.CellType), temporaryVariable, baseType(SyntaxTree.CellType).firstProperty);

					modifier := p0(SyntaxTree.Designator).modifiers;
					*)
					AddModifiers(baseType(SyntaxTree.CellType), temporaryVariable, modifier);

					
					Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
					(* l.op contains address of pointer to record *)
					ToMemory(l.op,addressType,0);
					(* l.op contains value  of pointer to record *)
					Emit(Push(position,l.op)); (* address for use after syscall *)
					ReleaseOperand(l);
					CallThis(position,"ActiveCellsRuntime","FinishedProperties",1);
					
					prevScope := currentScope;
					init := OpenInitializer(temporaryVariable, baseType(SyntaxTree.CellType).cellScope);
					previous := section;
					section := init;
					
					(* add ports *)
					AddPorts(temporaryVariable, baseType(SyntaxTree.CellType));
					
					CloseInitializer(previous);
					currentScope := prevScope; 
					
					Symbol(temporaryVariable,l);
					ToMemory(l.op,addressType,0);
					Emit(Push(position,l.op));
					Emit(Call(position,IntermediateCode.Address(addressType, init.name, 0, 0), ToMemoryUnits(system, addressType.sizeInBits)));

					(*
					constructor := type(SyntaxTree.CellType).cellScope.constructor;
					IF constructor # NIL THEN
						parameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
						FOR i := 1 TO x.parameters.Length()-1 DO
							p := x.parameters.GetExpression(i);
							Global.GetSymbolName(parameter,name);
							Evaluate(p, value);
							ASSERT(value.type # NIL);
							IF value.type.resolved IS SyntaxTree.IntegerType THEN
								par := instance.AddParameter(name);
								par.SetInteger(value.integer);
							ELSIF value.type.resolved IS SyntaxTree.BooleanType THEN
								par := instance.AddParameter(name);
								par.SetBoolean(value.boolean);
							ELSE Error(x.position,NotYetImplemented)
							END;
							parameter := parameter.nextParameter
						END;
					END;
					*)
					(* call initializer *)
					constructor := baseType(SyntaxTree.CellType).cellScope.constructor (*GetConstructor(p0.type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType))*);
					IF constructor # NIL THEN
						(*! should be unified with ProcedureCallDesignator *)
						IF backend.cellsAreObjects THEN
							Symbol(temporaryVariable,l);
							ToMemory(l.op,addressType,0);
							Emit(Push(position,l.op));
							ReleaseOperand(l);
						END;
						formalParameter := constructor.type(SyntaxTree.ProcedureType).firstParameter;
						FOR i := 1 TO x.parameters.Length()-1 DO
							PushParameter(x.parameters.GetExpression(i), formalParameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
							formalParameter := formalParameter.nextParameter;
						END;
						(* static call of the constructor *)
						Global.GetSymbolSegmentedName(constructor,name);
						ASSERT(~constructor.isInline);
						IF constructor.scope.ownerModule # module.module THEN
							symbol := NewSection(module.importedSections, Sections.CodeSection, name, constructor, commentPrintout # NIL);
						ELSE
							symbol := NewSection(module.allSections, Sections.CodeSection, name, constructor, commentPrintout # NIL);
						END;
						Emit(Call(position,IntermediateCode.Address(addressType, symbol.name, GetFingerprint(constructor), 0),ProcedureParametersSize(system,constructor)));
					(*ELSE
						ReleaseIntermediateOperand(pointer);*)
					END;
					
					Symbol(temporaryVariable,l); (*Designate(temporaryVariable,l)*)
					ToMemory(l.op, addressType, 0);
					Designate(p0,s0);
					ToMemory(s0.op,addressType,0);
					Emit(Mov(position,s0.op,l.op));
					ReleaseOperand(l);
					ReleaseOperand(s0);
					result.tag := emptyOperand;					

					(* start *)
					IF baseType(SyntaxTree.CellType).cellScope.bodyProcedure # NIL THEN
						(* push cell *)
						Symbol(temporaryVariable, l);
						ToMemory(l.op,addressType,0);
						Emit(Push(-1,l.op));
						(* push delegate *)
						Emit(Push(-1,l.op));
						ReleaseOperand(l);
						StaticCallOperand(s1,baseType(SyntaxTree.CellType).cellScope.bodyProcedure);
						Emit(Push(position, s1.op));
						ReleaseOperand(s1);
						
						CallThis(position,"ActiveCellsRuntime","Start",3);
					END;

					(*IF temporaryVariable # NIL THEN
						end := NewLabel();
						BrL(end);
						SetLabel(exit);
						Designate(p0,l);
						ToMemory(l.op,addressType,0);
						Emit(Mov(position,l.op,nil)); (* write NIL to adr *)
						ReleaseOperand(l);
						SetLabel(end);
					ELSE
						SetLabel(exit);
					END;
					*)
					(*Error(p0.position,"cannot be allocated in runtime yet");*)
				ELSE (* no pointer to record, no pointer to array *)
					IF ~backend.cellsAreObjects & (type IS SyntaxTree.CellType) THEN
						(* ignore new statement *)
						Warning(p0.position, "cannot run on final hardware");
					ELSE
						HALT(200);
					END;
				END;

			(* ---- ADDRESSOF----- *)
			|Global.systemAdr:
				Designate(p0,s0);
				s0.mode := ModeValue;
				IF (t0 IS SyntaxTree.MathArrayType) & (t0(SyntaxTree.MathArrayType).form = SyntaxTree.Open) THEN
					ReleaseIntermediateOperand(s0.op);
					s0.op := s0.tag;
					IntermediateCode.InitOperand(s0.tag);
				END;
				Convert(s0.op,IntermediateCode.GetType(system,x.type));
				result := s0;
			(* ---- BIT ----- *)
			|Global.systemBit:
				Evaluate(p0,s0);
				ToMemory(s0.op,addressType,0);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Evaluate(p1,s1);
				Emit(Ror(position,res,res,s1.op));
				ReleaseOperand(s1);
				Emit(And(position,res,res,IntermediateCode.Immediate(IntermediateCode.GetType(system,p0.type),1)));
				Convert(res,IntermediateCode.GetType(system,system.booleanType));
				IF ~conditional THEN
					InitOperand(result,ModeValue); result.op := res;
				ELSE
					BreqL(trueLabel,IntermediateCode.Immediate(res.type,1),res);
					BrL(falseLabel);
					ReleaseIntermediateOperand(res);
				END;
			(* --- MSK ----*)
			|Global.systemMsk:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				ReuseCopy(res,s0.op);
				ReleaseOperand(s0);
				Emit(And(position,res,res,s1.op));
				ReleaseOperand(s1);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GET8|16|32|64 ----- *)
			|Global.systemGet8, Global.systemGet16, Global.systemGet32, Global.systemGet64:
				Evaluate(p0,s0);
				MakeMemory(res,s0.op,IntermediateCode.GetType(system,x.type),0);
				ReleaseOperand(s0);
				InitOperand(result,ModeValue);
				result.op := res;
			(* ---- SYSTEM.GetStackPointer ----- *)
			|Global.systemGetStackPointer:
				InitOperand(result,ModeValue);
				result.op := sp;
			(* ---- SYSTEM.GetFramePointer ----- *)
			|Global.systemGetFramePointer:
				InitOperand(result,ModeValue);
				result.op := fp;
			(* ---- SYSTEM.GetActivity ----- *)
			|Global.systemGetActivity:
				ASSERT(backend.cooperative);
				InitOperand(result,ModeValue);
				result.op := ap;
			(* ---- SYSTEM.SetStackPointer ----- *)
			|Global.systemSetStackPointer:
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,sp,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.SetFramePointer ----- *)
			|Global.systemSetFramePointer:
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,fp,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.Activity ----- *)
			|Global.systemSetActivity:
				ASSERT(backend.cooperative);
				Evaluate(p0,s0); (*  *)
				Emit(Mov(position,ap,s0.op));
				ReleaseOperand(s0);
			(* ---- SYSTEM.VAL ----- *)
			|Global.systemVal:
				Expression(p1);
				s1 := result;
				type :=p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
				IF s1.mode = ModeReference THEN
					(* nothing to  be done if not record type, just take over new type *)
					IF (type IS SyntaxTree.RecordType) THEN
						ReleaseIntermediateOperand(s1.tag);
						s1.tag := TypeDescriptorAdr(type);
						IF ~newObjectFile THEN
							IntermediateCode.MakeMemory(s1.tag,addressType);
						END;
						UseIntermediateOperand(s1.tag);
					END;
					result := s1;
				ELSE (* copy over result to different type, may not use convert *)
					itype := IntermediateCode.GetType(system,type);
					IF itype.sizeInBits = s1.op.type.sizeInBits THEN
						IntermediateCode.InitRegister(s0.op,itype,IntermediateCode.GeneralPurposeRegister,AcquireRegister(itype,IntermediateCode.GeneralPurposeRegister));
						Emit(Mov(position,s0.op,s1.op));
						ReleaseOperand(s1);
						InitOperand(result,ModeValue);
						result.op := s0.op;
					ELSE (* different size, must convert *)
						(*! this is not very clean, should we forbid conversions between operands with different sizes or should we implement a cutting move ??? *)
						Convert(s1.op, IntermediateCode.GetType(system,type));
						result := s1;
					END;
				END;
			(* ---- SYSTEM.GET ----- *)
			|Global.systemGet:
				Evaluate(p0,s0); (* adr *)
				Designate(p1,s1); (* variable *)
				ToMemory(s0.op,IntermediateCode.GetType(system,p1.type),0);
				ToMemory(s1.op,IntermediateCode.GetType(system,p1.type),0);
				Emit(Mov(position,s1.op,s0.op));
				ReleaseOperand(s1);
				ReleaseOperand(s0);
			(* ---- SYSTEM.PUT 8|16|32|64 ----- *)
			|Global.systemPut, Global.systemPut64, Global.systemPut32, Global.systemPut16, Global.systemPut8:
				Evaluate(p0,s0); (*  *)
				Evaluate(p1,s1); (* variable *)
				IF p1.type.resolved IS SyntaxTree.ComplexType THEN
					componentType := p1.type.resolved(SyntaxTree.ComplexType).componentType;

					(* real part *)
					MakeMemory(res, s0.op, IntermediateCode.GetType(system, componentType), 0);
					Emit(Mov(position,res, s1.op));
					ReleaseIntermediateOperand(res);

					(* imaginary part *)
					MakeMemory(res, s0.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
					Emit(Mov(position,res, s1.tag));
					ReleaseIntermediateOperand(res);

					ReleaseOperand(s1);
					ReleaseOperand(s0);
				ELSE
					MakeMemory(res,s0.op,IntermediateCode.GetType(system,p1.type),0);
					ReleaseOperand(s0);
					Emit(Mov(position,res,s1.op));
					ReleaseIntermediateOperand(res);
					ReleaseOperand(s1);
				END;
			(* ---- SYSTEM.MOVE ----- *)
			|Global.systemMove:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				Evaluate(p2,s2);
				Emit(Copy(position,s1.op,s0.op,s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
			(* ---- SYSTEM.NEW ----- *)
			|Global.systemNew:
				Designate(p0,s0);
				Emit(Push(position,s0.op));
				ReleaseOperand(s0);
				Evaluate(p1,s1);
				Emit(Push(position,s1.op));
				ReleaseOperand(s1);
				(* push realtime flag: false by default *)
				Emit(Push(position,false));
				CallThis(position,"Heaps","NewSys",3);
			(* ---- SYSTEM.CALL ----- *)
			|Global.systemRef:
				Basic.ToSegmentedName(p0(SyntaxTree.StringValue).value^, segmentedName);
				callsection := NewSection(module.allSections,  Sections.CodeSection, segmentedName, NIL,commentPrintout # NIL);
				s0.mode := ModeValue;
				IntermediateCode.InitAddress(s0.op, addressType, callsection.name, 0, 0);
				result := s0
			(* ---- INCR ----- *)
			|Global.Incr:
				Designate(p0,operand);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(operand,p0.type.resolved,FALSE);
				END;
				ASSERT(p1 # NIL);
				Evaluate(p1,l);
				GetMathArrayIncrement(p0.type.resolved(SyntaxTree.MathArrayType),operand, l.op,TRUE, result);

				ReleaseOperand(operand); ReleaseOperand(l);
				Convert(result.op,IntermediateCode.GetType(system, x.type));
			(* ---- SUM ----- *)
			|Global.Sum: HALT(200);
			(* ---- ALL ----- *)
			|Global.All: HALT(200);
			(* ---- CAS ----- *)
			|Global.Cas:
				needsTrace := p0.NeedsTrace();
				IF needsTrace THEN ModifyAssignments(true) END;
				Designate(p0,s0);
				Evaluate(p1,s1);
				Evaluate(p2,s2);
				IF needsTrace THEN 
					Emit(Push(position, s0.op));
					Emit(Push(position, s1.op));
					Emit(Push(position, s2.op));
					CallThis(position,"GarbageCollector","CompareAndSwap",3);
				ELSE
					Emit(Cas(position,s0.op,s1.op,s2.op));
				END;
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF needsTrace THEN ModifyAssignments(false) END;
				res := NewRegisterOperand(IntermediateCode.GetType(system, p0.type));
				Emit(Result(position, res)); result.op := res; result.mode := ModeValue;
				IF conditional THEN
					BreqL(trueLabel,IntermediateCode.Immediate(res.type,1),res);
					BrL(falseLabel);
					ReleaseIntermediateOperand(res);
				END;
			(* ---- DIM ----- *)
			|Global.Dim:
				ASSERT(~SemanticChecker.IsArrayStructuredObjectType(p0.type));
				Designate(p0,s0);
				IF p0.type.resolved(SyntaxTree.MathArrayType).form = SyntaxTree.Tensor THEN
					Dereference(s0,p0.type.resolved,FALSE);
				END;
				MathArrayDim(p0.type.resolved(SyntaxTree.MathArrayType),s0.tag,result);
				ReleaseOperand(s0);
			(* ---- RESHAPE ----- *)
			|Global.Reshape:
				IF GetRuntimeProcedure("FoxArrayBase","Reshape",procedure,TRUE) THEN
					left := SyntaxTree.NewSymbolDesignator(Diagnostics.Invalid,NIL,procedure);
					left.SetType(procedure.type);
					call := SyntaxTree.NewProcedureCallDesignator(position,left(SyntaxTree.Designator),x.parameters);
					VisitProcedureCallDesignator(call(SyntaxTree.ProcedureCallDesignator));
				END;
			(* ---- SYSTEM.TYPECODE ----- *)
			|Global.systemTypeCode:
				type := p0(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
				IF type.resolved IS SyntaxTree.PointerType THEN
					type := type.resolved(SyntaxTree.PointerType).pointerBase;
				END;
				result.op := TypeDescriptorAdr(type);
				IF ~newObjectFile THEN
					ToMemory(result.op,IntermediateCode.GetType(system,x.type),0);
				ELSE Convert(result.op, IntermediateCode.GetType(system,x.type));
				END;
				result.mode := ModeValue;
			(* ---- SYSTEM.TRACE ----- *)
			|Global.systemTrace:
				SystemTrace(x.parameters, x.position);
			(* ----- CONNECT ------*)
			|Global.Connect:
				IF backend.cellsAreObjects THEN
					PushPort(p0);
					PushPort(p1);
					IF p2 # NIL THEN
						Evaluate(p2, s2);
						Emit(Push(p2.position, s2.op));
						ReleaseOperand(s2);
					ELSE
						Emit(Push(-1, IntermediateCode.Immediate(int32, -1)));
					END;
					CallThis(position,"ActiveCellsRuntime","Connect",3);
				ELSE
					Warning(x.position, "cannot run on final hardware");
				END;
			(* ----- DELEGATE ------*)
			|Global.Delegate:
				IF backend.cellsAreObjects THEN
					PushPort(p0);
					PushPort(p1);
					CallThis(position,"ActiveCellsRuntime","Delegate",2);
				ELSE
					Warning(x.position, "cannot run on final hardware");
				END;

			(* ----- SEND ------*)
			|Global.Send:
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s0.op));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size # 1 THEN Error(p1.position,"send not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Send",2);
				ELSE
					CallThis(position,ChannelModuleName,"Send",2);
				END;
			(* ----- RECEIVE ------*)
			|Global.Receive:
				Evaluate(p0,s0);
				Emit(Push(position,s0.op));
				Designate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s1.op));
				IF p2 # NIL THEN
					Designate(p2,s2);
					Emit(Push(position,s2.op));
				END;


				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size # 1 THEN Error(p1.position,"receive not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				ReleaseOperand(s2);
				IF backend.cellsAreObjects THEN
					IF p2 = NIL THEN
						CallThis(position,"ActiveCellsRuntime","Receive",2)
					ELSE
						CallThis(position,"ActiveCellsRuntime","ReceiveNonBlockingVar",3)
					END;
				ELSE
					IF p2 = NIL THEN
						CallThis(position,ChannelModuleName,"Receive",2)
					ELSE
						CallThis(position,ChannelModuleName,"ReceiveNonBlockingVar",3)
					END;
				END;

			| Global.systemSpecial:
				customBuiltin := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.CustomBuiltin);
				ASSERT(customBuiltin.type IS SyntaxTree.ProcedureType);
				procedureType := customBuiltin.type(SyntaxTree.ProcedureType);

				(* determine if parameters are of the VAR kind *)
				ASSERT(x.parameters.Length() <= 3);
				formalParameter := procedureType.firstParameter;
				FOR i := 0 TO x.parameters.Length() - 1 DO
					isVarPar[i] := formalParameter.kind = SyntaxTree.VarParameter;
					formalParameter := formalParameter.nextParameter
				END;

				IF p0 # NIL THEN IF isVarPar[0] THEN Designate(p0, s0) ELSE Evaluate(p0,s0) END ELSE InitOperand(s0, ModeValue) END;
				IF p1 # NIL THEN IF isVarPar[1] THEN Designate(p1, s1) ELSE Evaluate(p1,s1) END ELSE InitOperand(s1, ModeValue) END;
				IF p2 # NIL THEN IF isVarPar[2] THEN Designate(p2, s2) ELSE Evaluate(p2,s2) END ELSE InitOperand(s2, ModeValue) END;
				Emit(SpecialInstruction(x.position, customBuiltin.subType,s0.op, s1.op, s2.op));
				ReleaseOperand(s0); ReleaseOperand(s1); ReleaseOperand(s2);
				IF procedureType.returnType # NIL THEN
					res := NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
					Emit(Result(position, res));
					(*InitOperand(result,ModeValue);
					result.op := res;
					*)

					IF ~conditional THEN
						InitOperand(result,ModeValue); result.op := res;
					ELSE
						BreqL(trueLabel,IntermediateCode.Immediate(res.type,1),res);
						BrL(falseLabel);
						ReleaseIntermediateOperand(res);
					END;

				END

			ELSE (* function not yet implemented *)
				Error(position,"not yet implemented");
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitBuiltinCallDesignator") END;
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitTypeGuardDesignator(x: SyntaxTree.TypeGuardDesignator);
		VAR trueL,falseL: Label; recordType: SyntaxTree.RecordType; dest,tag,ptr: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitTypeGuardDesignator") END;
			dest := destination; destination := emptyOperand;

			Expression(x.left);
			IF x.left.type.resolved = x.type.resolved THEN (* always true: do nothing *)
			ELSIF isUnchecked THEN (* no check *)
			ELSE
				trueL := NewLabel();
				falseL := NewLabel();
				IF IsPointerToRecord(x.left.type,recordType) THEN
					IntermediateCode.InitRegister(tag,addressType,IntermediateCode.GeneralPurposeRegister,AcquireRegister(addressType,IntermediateCode.GeneralPurposeRegister));
					Emit(Mov(position,tag, result.op));
					IF result.mode # ModeValue THEN
						ptr := tag;
						IntermediateCode.MakeMemory(ptr,addressType);
						Emit(Mov(position,tag, ptr));
					END;
					IF ~backend.cooperative THEN
						IntermediateCode.AddOffset(tag,ToMemoryUnits(system,-addressType.sizeInBits));
					END;
					IntermediateCode.MakeMemory(tag,addressType);
				ELSE
					tag := result.tag;
				END;
				TypeTest(tag,x.type,trueL,falseL);
				ReleaseIntermediateOperand(tag);
				SetLabel(falseL);
				EmitTrap(position,TypeCheckTrap);
				SetLabel(trueL);
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitTypeGuardDesignator") END;
		END VisitTypeGuardDesignator;

		PROCEDURE Dereference(VAR operand: Operand; type: SyntaxTree.Type; isUnsafe: BOOLEAN);
		VAR dereferenced: IntermediateCode.Operand; arrayDataOffset: LONGINT;
		
			PROCEDURE NilCheck(CONST op: IntermediateCode.Operand);
			VAR label: Label; pc: LONGINT;
			BEGIN
				IF backend.cooperative & ~isUnchecked THEN
					pc := section.pc;
					label := NewLabel();
					BrneL(label, operand.op, nil);
					EmitTrap(position, NilPointerTrap);
					SetLabel(label);
					INC(statCoopNilCheck, section.pc - pc);
				END;
			END NilCheck;
			
		BEGIN
			LoadValue(operand,system.addressType); (* in case operand is not a value yet *)
			ReuseCopy(dereferenced,operand.op);
			ReleaseOperand(operand);
			operand.mode := ModeReference;
			operand.op := dereferenced;
			operand.tag := dereferenced;
			UseIntermediateOperand(operand.tag);
			IF (type=NIL) OR (type IS SyntaxTree.RecordType)OR (type IS SyntaxTree.CellType) THEN
				IF isUnsafe & ((type = NIL) OR ~type(SyntaxTree.RecordType).isObject) THEN
					ReleaseIntermediateOperand(operand.tag);
					operand.tag := TypeDescriptorAdr(type);
					IF ~newObjectFile THEN
						IntermediateCode.MakeMemory(operand.tag,addressType);
					END;
				ELSE
					IF ~backend.cooperative THEN
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,-addressType.sizeInBits));
					END;
					IntermediateCode.MakeMemory(operand.tag,addressType);
				END;
				NilCheck(operand.op);
			ELSIF type IS SyntaxTree.ArrayType THEN
				IF isUnsafe THEN
					NilCheck(operand.op);
					ReleaseIntermediateOperand(operand.tag);
					IF type(SyntaxTree.ArrayType).form = SyntaxTree.Static THEN
						IntermediateCode.InitImmediate(operand.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
					ELSE
						operand.tag := emptyOperand;
					END;
				ELSE
					NilCheck(operand.op);
					IF backend.cooperative THEN
						arrayDataOffset := (BaseArrayTypeSize + DynamicDim(type)) * addressType.sizeInBits;
						IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,arrayDataOffset));
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,BaseArrayTypeSize*system.addressSize));
					ELSE
						arrayDataOffset := DynamicDim(type) * addressType.sizeInBits + 3 * addressType.sizeInBits;
						INC(arrayDataOffset, (-arrayDataOffset) MOD ArrayAlignment);  (* round up to multiple of ArrayAlignment to ensure that first array element is aligned at 0 MOD ArrayAlignment *)
						IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,arrayDataOffset));
						IntermediateCode.AddOffset(operand.tag,ToMemoryUnits(system,ArrayDimTable*system.addressSize))
					END;
				END;
			ELSIF type IS SyntaxTree.MathArrayType THEN
				IntermediateCode.AddOffset(operand.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
				IntermediateCode.MakeMemory(operand.op,addressType);
			ELSE HALT(100);
			END;
		END Dereference;

		PROCEDURE VisitDereferenceDesignator(x: SyntaxTree.DereferenceDesignator);
		VAR  type: SyntaxTree.Type; d: Operand; dest: IntermediateCode.Operand;prevIsUnchecked: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("VisitDereferenceDesignator") END;
			dest := destination; destination := emptyOperand;
			Evaluate(x.left,d);
			type := x.type.resolved;
			prevIsUnchecked := isUnchecked;
			IF (x.left # NIL) & (x.left IS SyntaxTree.SelfDesignator) THEN 
				isUnchecked := TRUE; (* avoid NIL-pointer-check for SELF pointer *)
			END;
			Dereference(d,type,IsUnsafePointer(x.left.type));
			isUnchecked := prevIsUnchecked;
			result := d;
			IF backend.cooperative & (x.left.type.resolved IS SyntaxTree.PointerType) & ~x.left.type.resolved(SyntaxTree.PointerType).isPlain & ~x.left.type.resolved(SyntaxTree.PointerType).isUnsafe THEN
				IF (type IS SyntaxTree.RecordType) & ~type(SyntaxTree.RecordType).isObject THEN
					IntermediateCode.AddOffset(result.op,BaseRecordTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
				END;
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitDereferenceDesignator") END;
		END VisitDereferenceDesignator;

		PROCEDURE VisitSupercallDesignator(x: SyntaxTree.SupercallDesignator);
		VAR procedure: SyntaxTree.Procedure; tag: IntermediateCode.Operand; dest: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitSupercallDesignator") END;
			dest := destination; destination := emptyOperand;
			Designate(x.left(SyntaxTree.SymbolDesignator).left,result);
			tag := result.op;
			(*ReleaseIntermediateOperand(result.tag); not necessary -- done in StaticCallOperand *)
			procedure := x.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
			StaticCallOperand(result,procedure.super);

			ReleaseIntermediateOperand(result.tag);
			UseIntermediateOperand(tag); (* necessary ? *)

			result.tag := tag;
			destination := dest;
			IF Trace THEN TraceExit("VisitSupercallDesignator") END;
		END VisitSupercallDesignator;

		PROCEDURE VisitSelfDesignator(x: SyntaxTree.SelfDesignator);
		VAR basereg: IntermediateCode.Operand; scope: SyntaxTree.Scope; dest: IntermediateCode.Operand;
			moduleSection: IntermediateCode.Section; moduleOffset, parametersSize: LONGINT;
			name: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("VisitSelfDesignator") END;
			dest := destination; destination := emptyOperand;
			scope := currentScope;
			WHILE (scope.outerScope # NIL) & (scope.outerScope IS SyntaxTree.ProcedureScope) DO
				scope := scope.outerScope;
			END;
			IF scope.outerScope IS SyntaxTree.ModuleScope THEN
				IF newObjectFile THEN
					moduleSection := meta.ModuleSection();
					IF backend.cooperative THEN
						moduleOffset := 0;
					ELSE
						moduleOffset := moduleSection.pc;
					END;
					result.mode := ModeValue;
					result.op := IntermediateCode.Address(addressType, moduleSection.name, GetFingerprint(moduleSection.symbol), moduleOffset);
				ELSE
					Symbol(moduleSelf,result);
					IntermediateCode.MakeMemory(result.op,addressType);
				END
			ELSIF (scope.outerScope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
				result.mode := ModeValue;
				Global.GetSymbolSegmentedName(scope.outerScope(SyntaxTree.CellScope).ownerCell.typeDeclaration, name);
				result.op := IntermediateCode.Address(addressType, name, 0, moduleOffset);
			ELSE
				GetBaseRegister(basereg,currentScope,scope);
				InitOperand(result,ModeReference);
				result.op := basereg;
				parametersSize := ProcedureParametersSize(system,scope(SyntaxTree.ProcedureScope).ownerProcedure);
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,addressType.sizeInBits)+parametersSize);
				IF backend.cooperative THEN
					IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,addressType.sizeInBits));
				END;
				(* tag must be loaded when dereferencing SELF pointer *)
			END;
			destination := dest;
			IF Trace THEN TraceExit("VisitSelfDesignator") END;
		END VisitSelfDesignator;

		PROCEDURE VisitResultDesignator(x: SyntaxTree.ResultDesignator);
		VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; parameter: SyntaxTree.Parameter;
		BEGIN
			IF Trace THEN TraceEnter("VisitResultDesignator") END;
			procedure := currentScope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);
			parameter := procedureType.returnParameter;
			VisitParameter(parameter);
			IF Trace THEN TraceExit("VisitResultDesignator") END;
		END VisitResultDesignator;

		(** values *)
		PROCEDURE VisitBooleanValue(x: SyntaxTree.BooleanValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitBooleanValue") END;
			IF conditional THEN
				IF x.value THEN BrL(trueLabel)
				ELSE BrL(falseLabel)
				END;
			ELSE
				InitOperand(result,ModeValue);
				IF x.value THEN result.op := true ELSE result.op := false END;
			END;
		END VisitBooleanValue;

		PROCEDURE GetDataSection*(): IntermediateCode.Section;
		VAR name: Basic.SegmentedName; section: IntermediateCode.Section;
		BEGIN
			Global.GetModuleSegmentedName(module.module, name);
			Basic.SuffixSegmentedName(name,Basic.MakeString("@Immediates"));
			section := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,NIL,TRUE);
			RETURN section
		END GetDataSection;

		PROCEDURE GetImmediateMem(VAR vop: IntermediateCode.Operand);
		VAR data: IntermediateCode.Section;pc: LONGINT; type: IntermediateCode.Type;
		BEGIN
			type := vop.type;
			data := GetDataSection();
			pc := EnterImmediate(data,vop);
			IntermediateCode.InitAddress(vop, addressType, data.name, 0, pc);
			IntermediateCode.MakeMemory(vop, type);
		END GetImmediateMem;

		PROCEDURE VisitIntegerValue(x: SyntaxTree.IntegerValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitIntegerValue") END;
			InitOperand(result,ModeValue);
			IntermediateCode.InitImmediate(result.op,IntermediateCode.GetType(system,x.type),x.hvalue);
			IF ~supportedImmediate(result.op)  &~inData THEN
				GetImmediateMem(result.op)
			END;
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue(x: SyntaxTree.CharacterValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitCharacterValue") END;
			InitOperand(result,ModeValue);
			IntermediateCode.InitImmediate(result.op,IntermediateCode.GetType(system,x.type),ORD(x.value));
		END VisitCharacterValue;

		PROCEDURE VisitSetValue(x: SyntaxTree.SetValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitSetValue") END;
			InitOperand(result,ModeValue);
			IntermediateCode.InitImmediate(result.op,IntermediateCode.GetType(system,x.type),SYSTEM.VAL(LONGINT,x.value));
		END VisitSetValue;

		PROCEDURE VisitMathArrayValue(x: SyntaxTree.MathArrayValue);
		VAR  irv: IntermediateCode.Section; name:Basic.SegmentedName;

			PROCEDURE RecursiveData(x: SyntaxTree.MathArrayExpression);
			VAR numberElements,i: LONGINT; expression: SyntaxTree.Expression; op: Operand;
			BEGIN
				numberElements := x.elements.Length();
				FOR i := 0 TO numberElements-1 DO
					expression := x.elements.GetExpression(i);
					IF expression IS SyntaxTree.MathArrayExpression THEN
						RecursiveData(expression(SyntaxTree.MathArrayExpression));
					ELSE
						inData := TRUE;
						Evaluate(expression,op);
						irv.Emit(Data(position,op.op));
						inData := FALSE;
						ReleaseOperand(op);
					END;
				END;
			END RecursiveData;

		BEGIN
			IF Trace THEN TraceEnter("VisitMathArrayValue") END;
			IF ~TryConstantDeclaration() THEN
				IF constantDeclaration = NIL THEN constantDeclaration:=BuildConstant(module.module,x,constId) END;
				GetCodeSectionNameForSymbol(constantDeclaration,name);
				IF ~newObjectFile OR (constantDeclaration.scope = NIL) OR (constantDeclaration.scope.ownerModule = module.module) THEN
					irv := NewSection(module.allSections,Sections.ConstSection,name,constantDeclaration,commentPrintout # NIL);
				ELSE
					irv := NewSection(module.importedSections, Sections.ConstSection, name,constantDeclaration,commentPrintout # NIL);
				END;
				RecursiveData(x.array);
				InitOperand(result,ModeReference);
				IntermediateCode.InitAddress(result.op, addressType, irv.name, GetFingerprint(irv.symbol), 0);
			END
		END VisitMathArrayValue;

		PROCEDURE TryConstantDeclaration(): BOOLEAN;
		VAR constant: Sections.Section;
		BEGIN
			IF constantDeclaration = NIL THEN
				RETURN FALSE
			ELSE
				(* Is a constant in this module: did we generate it already? *)
				constant := module.allSections.FindBySymbol(constantDeclaration); (*TODO*)
				IF constant # NIL THEN
					InitOperand(result,ModeReference);
					IntermediateCode.InitAddress(result.op,addressType,constant.name,GetFingerprint(constant.symbol), 0);
					RETURN TRUE;
				END;
			END;
			RETURN FALSE
		END TryConstantDeclaration;

		PROCEDURE VisitConstant(x: SyntaxTree.Constant);
		BEGIN
			constantDeclaration := x;
			x.value.resolved.Accept(SELF);
		END VisitConstant;

		PROCEDURE VisitRealValue(x: SyntaxTree.RealValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitRealValue") END;
			InitOperand(result,ModeValue);
			IntermediateCode.InitFloatImmediate(result.op,IntermediateCode.GetType(system,x.type),x.value);
		END VisitRealValue;

		PROCEDURE VisitComplexValue(x: SyntaxTree.ComplexValue);
		VAR
			componentType: SyntaxTree.Type;
		BEGIN
			IF Trace THEN TraceEnter("VisitComplexValue") END;
			ASSERT(x.type IS SyntaxTree.ComplexType);
			componentType := x.type(SyntaxTree.ComplexType).componentType;
			InitOperand(result,ModeValue);
			IntermediateCode.InitFloatImmediate(result.op,IntermediateCode.GetType(system,componentType),x.realValue); (* real part *)
			IntermediateCode.InitFloatImmediate(result.tag,IntermediateCode.GetType(system,componentType),x.imagValue); (* imaginary part *)
		END VisitComplexValue;

		PROCEDURE VisitStringValue(x: SyntaxTree.StringValue);
		VAR  i: LONGINT; name: Basic.SegmentedName;
			irv: IntermediateCode.Section; op: IntermediateCode.Operand;
		BEGIN
			IF Trace THEN TraceEnter("VisitStringValue") END;
			IF ~TryConstantDeclaration() THEN
				IF constantDeclaration = NIL THEN constantDeclaration:=BuildConstant(module.module,x,constId) END;
				GetCodeSectionNameForSymbol(constantDeclaration,name);
				IF ~newObjectFile OR (constantDeclaration.scope = NIL) OR (constantDeclaration.scope.ownerModule = module.module) THEN
					irv := NewSection(module.allSections, Sections.ConstSection, name,constantDeclaration,commentPrintout # NIL);
				ELSE
					irv := NewSection(module.importedSections, Sections.ConstSection, name,constantDeclaration,commentPrintout # NIL);
				END;
				FOR i := 0 TO x.length-1 DO
					IntermediateCode.InitImmediate(op,IntermediateCode.GetType(system,system.characterType),ORD(x.value[i]));
					irv.Emit(Data(position,op));
				END;
				InitOperand(result,ModeReference);
				IntermediateCode.InitAddress(result.op, addressType, irv.name, GetFingerprint(irv.symbol), 0);
				result.tag := IntermediateCode.Immediate(addressType,x.length);
			END
		END VisitStringValue;

		PROCEDURE VisitNilValue(x: SyntaxTree.NilValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitNilValue") END;
			InitOperand(result,ModeValue);
			result.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),0);
			result.tag := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),0);
		END VisitNilValue;

		PROCEDURE VisitEnumerationValue(x: SyntaxTree.EnumerationValue);
		BEGIN
			IF Trace THEN TraceEnter("VisitEnumerationValue") END;
			InitOperand(result,ModeValue);
			result.op := IntermediateCode.Immediate(IntermediateCode.GetType(system,x.type),x.value);
		END VisitEnumerationValue;

		(** symbols *)

		PROCEDURE VisitImport(x: SyntaxTree.Import);
		BEGIN (* nothing to be done, might however be called via some designator module.procedure *)
		END VisitImport;

		PROCEDURE GetBaseRegister(VAR result: IntermediateCode.Operand; scope,baseScope: SyntaxTree.Scope);
		VAR left,right: IntermediateCode.Operand;level: LONGINT;
		BEGIN
			IF scope # baseScope THEN
				(* left := [fp+8] *)
				IntermediateCode.InitMemory(right,addressType,fp,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				ReuseCopy(left,right);
				ReleaseIntermediateOperand(right);
				scope := scope.outerScope; DEC(level);
				(* { left := [left+8] } *)
				IntermediateCode.InitMemory(right,addressType,left,ToMemoryUnits(system,2*addressType.sizeInBits));
				IF backend.cooperative THEN IntermediateCode.AddOffset (right, ToMemoryUnits(system,addressType.sizeInBits)) END;
				WHILE (scope # baseScope) & (scope IS SyntaxTree.ProcedureScope) DO
					Emit(Mov(position,left,right));
					scope := scope.outerScope; DEC(level);
				END;
				ASSERT((scope = baseScope) OR (baseScope = NIL));
				result := left;
			ELSE
				result := fp;
			END;
		END GetBaseRegister;

		PROCEDURE VisitVariable(x: SyntaxTree.Variable);
		VAR symbol: Sections.Section;  type: SyntaxTree.Type; recordType: SyntaxTree.RecordType; name: Basic.SegmentedName; temp: IntermediateCode.Operand; reg: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("VisitVariable");  END;
			type := x.type.resolved;
			IF (x.useRegister) THEN
				InitOperand(result, ModeValue);
				IF x.registerNumber < 0 THEN
					x.SetRegisterNumber(AcquireRegister(IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister));
					reg := x.registerNumber;
				ELSE
					reg := registerUsageCount.Map(x.registerNumber);
					UseRegister(reg);
				END;
				IntermediateCode.InitRegister(result.op,IntermediateCode.GetType(system, type),IntermediateCode.GeneralPurposeRegister,reg);
			ELSIF x.externalName # NIL THEN
				InitOperand(result,ModeReference);
				Basic.ToSegmentedName(x.externalName^, name);
				IntermediateCode.InitAddress(result.op, addressType, name, 0, 0);
			ELSIF (x.scope IS SyntaxTree.ProcedureScope) THEN (* local variable (potentially via nested procedure) *)
				InitOperand(result,ModeReference);
				GetBaseRegister(result.op,currentScope,x.scope);
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
			ELSIF (x.scope = moduleScope) OR (x.scope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN (* global variable *)
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.allSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0);
			ELSIF x.scope IS SyntaxTree.ModuleScope THEN (* global variable in imported module *)
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.importedSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0)
			ELSE (* field, left designator must have been emitted *)
				ASSERT(result.mode = ModeReference);
				IF result.op.mode = IntermediateCode.ModeMemory THEN
					ReuseCopy(temp,result.op);
					ReleaseIntermediateOperand(result.op);
					result.op := temp;
				END;
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));

				IF backend.cooperative & (x.scope IS SyntaxTree.RecordScope) THEN
					recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
					IF recordType.isObject & ~recordType.pointerType.isPlain THEN
						IntermediateCode.AddOffset(result.op,BaseObjectTypeSize * ToMemoryUnits(system,addressType.sizeInBits));
					END;
				END;
			END;

			IF conditional & (x.type.resolved IS SyntaxTree.BooleanType) THEN
				ValueToCondition(result);
			ELSIF type IS SyntaxTree.ProcedureType THEN
				ReleaseIntermediateOperand(result.tag);
				IF type(SyntaxTree.ProcedureType).isDelegate THEN
					IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
					UseIntermediateOperand(result.tag);
				ELSE
					result.tag := nil; (* nil *)
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				IF type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic THEN
					IF (x.scope IS SyntaxTree.ModuleScope) OR (x.scope IS SyntaxTree.CellScope) & ~backend.cellsAreObjects THEN
						ReleaseIntermediateOperand(result.tag);
						Global.GetSymbolSegmentedName(x,name);
						Basic.SuffixSegmentedName (name, Basic.MakeString ("@len"));
						symbol := NewSection(module.allSections, Sections.VarSection, name,NIL ,commentPrintout # NIL);
						IntermediateCode.InitAddress(result.tag, addressType, symbol.name,0 , 0);
					ELSE
					END;
				ELSE
					ReleaseIntermediateOperand(result.tag);
					IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				IF type(SyntaxTree.MathArrayType).form IN {SyntaxTree.Open} THEN
					ReleaseIntermediateOperand(result.tag);
					result.tag := result.op;
					UseIntermediateOperand(result.tag);
					IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
					IntermediateCode.MakeMemory(result.op,addressType);
				END;
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType = NIL) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(type);
				IF ~newObjectFile THEN
					IntermediateCode.MakeMemory(result.tag,addressType);
				END;
				UseIntermediateOperand(result.tag);
			(* tag for pointer type computed not here but during dereferencing *)
			END;
			IF Trace THEN TraceExit("VisitVariable") END;
		END VisitVariable;

		PROCEDURE VisitProperty(property: SyntaxTree.Property);
		BEGIN 
			VisitVariable(property);
		END VisitProperty;

		PROCEDURE VisitParameter(x: SyntaxTree.Parameter);
		VAR type: SyntaxTree.Type; basereg, mem: IntermediateCode.Operand; parameter: SyntaxTree.Parameter;adr: LONGINT; symbol: Sections.Section;
			name: Basic.SegmentedName; parameterType, ptype: SyntaxTree.Type; len,inc: LONGINT;
		BEGIN
			type := x.type.resolved;
			IF Trace THEN TraceEnter("VisitParameter") END;

			IF x.ownerType IS SyntaxTree.CellType THEN
				ptype := x.type.resolved;
				IF ptype IS SyntaxTree.ArrayType THEN ptype := ptype(SyntaxTree.ArrayType).arrayBase.resolved END;
				IF ~(ptype IS SyntaxTree.PortType) THEN
					InitOperand(result,ModeReference);
					GetCodeSectionNameForSymbol(x,name);
					symbol := NewSection(module.allSections, Sections.ConstSection, name,x,commentPrintout # NIL);
					IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol),0);
					RETURN
				ELSE
					InitOperand(result, ModeValue);
					parameter := x.ownerType(SyntaxTree.CellType).firstParameter;
					adr := 0;
					WHILE parameter # x DO
						parameterType := parameter.type;
						inc := 1;
						WHILE SemanticChecker.IsStaticArray(parameterType, parameterType, len) DO inc := inc * len END;
						INC(adr, inc);
						parameter := parameter.nextParameter
					END;
					IntermediateCode.InitImmediate(result.op,addressType,adr);
					RETURN
				END;
			ELSIF ~backend.cellsAreObjects & (currentScope IS SyntaxTree.ProcedureScope) & (currentScope(SyntaxTree.ProcedureScope).ownerProcedure.isConstructor) & (currentScope.outerScope IS SyntaxTree.CellScope) THEN
				InitOperand(result,ModeReference);
				GetCodeSectionNameForSymbol(x,name);
				symbol := NewSection(module.allSections, Sections.VarSection, name,x,commentPrintout # NIL);
				IntermediateCode.InitAddress(result.op, addressType, symbol.name, GetFingerprint(symbol.symbol), 0);
				RETURN
			ELSE
				GetBaseRegister(basereg,currentScope,x.scope);
				InitOperand(result,ModeReference);
				result.op := basereg;
			END;

			IF IsOpenArray(type) THEN
				result.tag := basereg;
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);
				IF Global.IsOberonProcedure(x.ownerType) THEN
					IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,x.offsetInBits+addressType.sizeInBits));
					UseIntermediateOperand(result.tag);
				ELSE
					IntermediateCode.InitImmediate(result.tag,addressType,MAX(LONGINT)); (* non-Oberon procedure => unbounded array length *)
				END;
			ELSIF IsStaticArray(type) & (x.kind = SyntaxTree.ValueParameter) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
			ELSIF IsStaticArray(type) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);
				IntermediateCode.InitImmediate(result.tag,addressType,type(SyntaxTree.ArrayType).staticLength);
			ELSIF type IS SyntaxTree.MathArrayType THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				WITH type: SyntaxTree.MathArrayType DO
					IF (x.kind = SyntaxTree.ValueParameter) OR (x.kind = SyntaxTree.ConstParameter) THEN
						IF type.form = SyntaxTree.Tensor THEN
						ELSIF type.form = SyntaxTree.Open THEN
							result.tag := result.op;
							IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
							IntermediateCode.MakeMemory(result.op,addressType);
							UseIntermediateOperand(result.tag);
						ELSIF type.form = SyntaxTree.Static THEN
							IF x.kind = SyntaxTree.ConstParameter THEN
								IntermediateCode.MakeMemory(result.op,addressType);
							END;
						ELSE HALT(100)
						END;
					ELSIF x.kind = SyntaxTree.VarParameter THEN
						IF type.form = SyntaxTree.Tensor THEN
							ToMemory(result.op,addressType,0);
						ELSIF type.form = SyntaxTree.Open THEN
							MakeMemory(mem, result.op,  addressType, 0); (* offset already added above *)
							ReuseCopy(result.tag, mem);
							ReleaseIntermediateOperand(mem);
							ReleaseIntermediateOperand(result.op);
							MakeMemory(result.op, result.tag, addressType, ToMemoryUnits(system,MathAdrOffset*addressType.sizeInBits));
						ELSIF type.form = SyntaxTree.Static THEN
							IntermediateCode.MakeMemory(result.op,addressType);
						ELSE HALT(100)
						END;
					ELSE HALT(100)
					END;
				END;
			ELSIF (x.kind = SyntaxTree.VarParameter) OR (x.kind = SyntaxTree.ConstParameter) & (type IS SyntaxTree.RecordType) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
				IntermediateCode.MakeMemory(result.op,addressType);

			ELSIF (x.kind = SyntaxTree.ValueParameter) OR (x.kind = SyntaxTree.ConstParameter) THEN
				IntermediateCode.AddOffset(result.op,ToMemoryUnits(system,x.offsetInBits));
			END;

			IF conditional & (x.type.resolved IS SyntaxTree.BooleanType) THEN
				ValueToCondition(result);
			ELSIF type IS SyntaxTree.ProcedureType THEN
				ReleaseIntermediateOperand(result.tag);
				IF type(SyntaxTree.ProcedureType).isDelegate THEN
					IF x.kind = SyntaxTree.VarParameter THEN
						ReuseCopy(result.tag,result.op);
						IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,system.addressSize));
						IntermediateCode.MakeMemory(result.tag,addressType);
					ELSE
						IntermediateCode.InitMemory(result.tag,addressType,result.op,ToMemoryUnits(system,system.addressSize));
						UseIntermediateOperand(result.tag);
					END;
				ELSE
					result.tag := nil;
				END;
			(* tag for pointer type computed not here but during dereferencing *)
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType= NIL) & (x.kind IN {SyntaxTree.VarParameter, SyntaxTree.ConstParameter}) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := basereg;
				IntermediateCode.AddOffset(result.tag,ToMemoryUnits(system,x.offsetInBits+system.addressSize));
				IntermediateCode.MakeMemory(result.tag,addressType);
				UseIntermediateOperand(result.tag);
			ELSIF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType= NIL) & (x.kind = SyntaxTree.ValueParameter) THEN
				ReleaseIntermediateOperand(result.tag);
				result.tag := TypeDescriptorAdr(type);
				IF ~newObjectFile THEN
					IntermediateCode.MakeMemory(result.tag,addressType);
				END;
				UseIntermediateOperand(result.tag);
			END;
			IF Trace THEN TraceExit("VisitParameter") END;
		END VisitParameter;

		PROCEDURE DynamicCallOperand(VAR operand: Operand; x: SyntaxTree.Procedure);
		VAR tag,reg,tmp: IntermediateCode.Operand; offset: LONGINT; recordType: SyntaxTree.RecordType; name, stackFrame: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("DynamicCallOperand") END;
			(* left.p: left already emitted *)
			tag := result.op; (* value of pointer to left *)
			(* get type desc *)
			tmp := result.tag;
			IntermediateCode.MakeMemory(tmp,addressType);
			(* get method adr *)
			Reuse1(reg,tmp);
			ReleaseIntermediateOperand(tmp);
			
			IF backend.cooperative THEN
				recordType := x.scope(SyntaxTree.RecordScope).ownerRecord;
				WHILE recordType.baseType # NIL DO
					recordType := recordType.GetBaseRecord ();
				END;
				GetRecordTypeName (recordType,name);
				Basic.ToSegmentedName ("BaseTypes.StackFrame",stackFrame);
				IF (name = stackFrame) OR HasExplicitTraceMethod (recordType) THEN
					offset := 0;
				ELSE
					offset := 2;
				END;
				Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.addressSize  *(meta.MethodTableOffset + x.methodNumber + offset)))));
			ELSE
				Emit(Add(position,reg,tmp,IntermediateCode.Immediate(addressType, ToMemoryUnits(system,system.addressSize  *(meta.MethodTableOffset - x.methodNumber)))));
			END;
			
			InitOperand(operand,ModeReference);
			(* then operand.op contains the method adr and operand.tag contains the potential self pointer value *)
			operand.op := reg;
			operand.tag := tag;
			IF Trace THEN TraceExit("DynamicCallOperand") END;
		END DynamicCallOperand;

		PROCEDURE StaticCallOperand(VAR operand: Operand; x: SyntaxTree.Procedure);
		VAR source: IntermediateCode.Section; tag,reg: IntermediateCode.Operand; name:Basic.SegmentedName; sectionType: SHORTINT;
			binary: BinaryCode.Section; bits: SyntaxTree.BinaryCode;
		BEGIN
			IF Trace THEN TraceEnter("StaticCallOperand") END;
			IF x.type(SyntaxTree.ProcedureType).isDelegate THEN
				tag := operand.op;
				ReleaseIntermediateOperand(operand.tag);
			ELSE tag := nil
			END;
			IF x.isInline  THEN
				sectionType := Sections.InlineCodeSection;
			ELSE
				sectionType := Sections.CodeSection;
			END;
			IF x.externalName # NIL THEN
				Basic.ToSegmentedName(x.externalName^, name);
				IntermediateCode.InitAddress(reg, addressType, name, 0, 0);
			ELSE
				GetCodeSectionNameForSymbol(x, name);
				IF (x.scope.ownerModule = module.module) THEN
					source := NewSection(module.allSections, sectionType, name,x,commentPrintout # NIL);
				ELSIF (sectionType = Sections.InlineCodeSection) & (x.procedureScope.body.code.sourceCode # NIL) THEN
					source := NewSection(module.allSections, sectionType, name,x,commentPrintout # NIL);
					IF source.pc = 0 THEN (* no code yet *)
						source.Emit(Asm(position,x.procedureScope.body.code.sourceCode,NIL,NIL));
					END;
				ELSIF (sectionType = Sections.InlineCodeSection) & (x.procedureScope.body.code.inlineCode # NIL) THEN
					bits := x.procedureScope.body.code.inlineCode;
					source := NewSection(module.allSections, sectionType, name, x, commentPrintout # NIL);
					binary := BinaryCode.NewBinarySection(source.type, source.priority, system.codeUnit, name, FALSE, FALSE);
					binary.CopyBits(bits, 0, bits.GetSize());
					source.SetResolved(binary);
				ELSE
					source := NewSection(module.importedSections, sectionType, name,x,commentPrintout # NIL);
				END;
				IntermediateCode.InitAddress(reg, addressType, source.name , GetFingerprint(source.symbol), 0);
			END;
			InitOperand(operand,ModeValue);
			operand.op := reg;
			operand.tag := tag;
			IF Trace THEN TraceExit("StaticCallOperand") END;
		END StaticCallOperand;

		PROCEDURE VisitProcedure(x: SyntaxTree.Procedure);
		(* handle expressions of the form designator.procedure or procedure *)
		BEGIN
			IF Trace THEN TraceEnter("VisitProcedure") END;
			IF  (x.type(SyntaxTree.ProcedureType).isDelegate) & ~SemanticChecker.IsStaticProcedure(x) THEN
				DynamicCallOperand(result,x);
			ELSIF x.isInline THEN
				StaticCallOperand(result,x);
			ELSE
				StaticCallOperand(result,x);
			END;
			IF Trace THEN TraceExit("VisitProcedure") END;
		END VisitProcedure;

		PROCEDURE VisitOperator(x: SyntaxTree.Operator);
		BEGIN
			VisitProcedure(x);
		END VisitOperator;

		(** statements *)

		PROCEDURE VisitProcedureCallStatement(x: SyntaxTree.ProcedureCallStatement);
		BEGIN
			IF Trace THEN TraceEnter("VisitProcedureCallStatement") END;
			Expression(x.call);
			IF (x.call.type # NIL) THEN (* WINAPI call: procedure returning unused value *)
				ReleaseOperand(result)
			END;
			IF Trace THEN TraceExit("VisitProcedureCallStatement") END;
		END VisitProcedureCallStatement;

		PROCEDURE AssignMathArray(left,right: SyntaxTree.Expression);
		VAR leftType, rightType: SyntaxTree.MathArrayType;
			leftBase, rightBase: SyntaxTree.Type;
			procedureName,s: SyntaxTree.IdentifierString;
			arrayBase: SyntaxTree.Module; saved: RegisterEntry;  procedure: SyntaxTree.Procedure; parameter: SyntaxTree.Parameter;
			size: LONGINT; rightKind: LONGINT;
			dummy: IntermediateCode.Operand;

		CONST moduleName = "FoxArrayBase";

			PROCEDURE OpenArray(from: SyntaxTree.MathArrayType): SyntaxTree.MathArrayType;
			VAR result: SyntaxTree.MathArrayType; base: SyntaxTree.Type;
			BEGIN
				base := from(SyntaxTree.MathArrayType).arrayBase.resolved;
				IF base IS SyntaxTree.MathArrayType THEN
					base := OpenArray(base(SyntaxTree.MathArrayType));
				END;
				result := SyntaxTree.NewMathArrayType(left.position,currentScope,SyntaxTree.Open);
				result.SetArrayBase(base);
				RETURN result
			END OpenArray;

		BEGIN
			IF AddImport(moduleName,arrayBase,TRUE) THEN
				SaveRegisters();ReleaseUsedRegisters(saved);
				leftType := left.type.resolved(SyntaxTree.MathArrayType);
				rightType := right.type.resolved(SyntaxTree.MathArrayType);
				leftBase := SemanticChecker.ArrayBase(leftType,MAX(LONGINT));
				rightBase := SemanticChecker.ArrayBase(rightType,MAX(LONGINT));
				ASSERT(leftBase.resolved.SameType(rightBase.resolved));

				IF leftType.form = SyntaxTree.Tensor THEN
					procedureName := "CopyTensor"; rightKind := SyntaxTree.ValueParameter;
				ELSIF leftType.form = SyntaxTree.Open THEN
					procedureName := "CopyArray"; rightKind := SyntaxTree.VarParameter;
				ELSIF leftType.form = SyntaxTree.Static THEN
					procedureName := "CopyArray";rightKind := SyntaxTree.VarParameter;
					leftType := OpenArray(leftType); (* necessary since copy procedure presumes an open array *)
				END;

				procedure := arrayBase.moduleScope.FindProcedure(SyntaxTree.NewIdentifier(procedureName));
				IF procedure = NIL THEN
					s := "Instruction not supported on target, emulation procedure ";
					Strings.Append(s,moduleName);
					Strings.Append(s,".");
					Strings.Append(s,procedureName);
					Strings.Append(s," not present");
					Error(position,s);
				ELSE
					parameter := SyntaxTree.NewParameter(left.position,procedure.type(SyntaxTree.ProcedureType),SyntaxTree.NewIdentifier("temp"), SyntaxTree.VarParameter);
					parameter.SetType(leftType);
					parameter.SetAccess(SyntaxTree.Internal);
					PushParameter(left,parameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
					parameter.SetKind(rightKind);
					PushParameter(right,parameter,SyntaxTree.OberonCallingConvention, FALSE, dummy,-1);
					size := ToMemoryUnits(system,system.SizeOf(rightBase));
					Emit(Push(position,IntermediateCode.Immediate(int32,size)));
					StaticCallOperand(result,procedure);
					Emit(Call(position,result.op,ProcedureParametersSize(system,procedure)));
					ReleaseOperand(result);
				END;
				RestoreRegisters(saved);
			END;
		END AssignMathArray;
		
		VAR modifyAssignmentCounter := 0: LONGINT; 
		
		PROCEDURE ModifyAssignments(CONST value: IntermediateCode.Operand);
		VAR processor,mem,dst: IntermediateCode.Operand;
		BEGIN
			IF value.intValue = true.intValue THEN
				INC(modifyAssignmentCounter);
				IF (modifyAssignmentCounter > 1) THEN RETURN END;
				modifyAssignmentsPC := section.pc;

			ELSE
				DEC(modifyAssignmentCounter);
				IF (modifyAssignmentCounter > 0) THEN RETURN END;
				INC(statCoopModifyAssignments , section.pc - modifyAssignmentsPC);
			END;
			IntermediateCode.InitMemory (processor,  IntermediateCode.SignedIntegerType(addressType.sizeInBits), ap, ToMemoryUnits(system, ProcessorOffset * addressType.sizeInBits));
			dst := NewRegisterOperand (addressType);
			Emit(Mov(position,dst, processor));
			IntermediateCode.InitMemory(mem,bool, dst, 0);
			Emit(Mov(position,mem, value));
			ReleaseIntermediateOperand(dst);
		END ModifyAssignments;

		PROCEDURE CopySize(left: SyntaxTree.Expression): IntermediateCode.Operand;
		VAR type: SyntaxTree.Type; procedureType: SyntaxTree.ProcedureType; parameter: SyntaxTree.Parameter;
		BEGIN
			type := left.type.resolved;
			IF (type IS SyntaxTree.RecordType) & (left IS SyntaxTree.SymbolDesignator) & (left(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
				parameter := left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Parameter);
				procedureType := parameter.ownerType.resolved(SyntaxTree.ProcedureType);
				IF procedureType.returnParameter = parameter THEN
					RETURN IntermediateCode.Memory(addressType, fp, ToMemoryUnits(system, parameter.offsetInBits + system.addressSize));
				END;
			END;
			RETURN IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.SizeOf(type)));
		END CopySize;

		PROCEDURE Assign(left,right: SyntaxTree.Expression);
		VAR
			leftO, rightO: Operand;
			mem, sizeOp: IntermediateCode.Operand;
			leftType, rightType, componentType: SyntaxTree.Type;
			size: LONGINT;
			parameters: SyntaxTree.ExpressionList;
			procedure: SyntaxTree.Procedure;
			call: SyntaxTree.ProcedureCallDesignator;
			designator: SyntaxTree.Designator;

			PROCEDURE CanPassAsResultParameter(right: SyntaxTree.Expression): BOOLEAN;
			VAR procedureType: SyntaxTree.ProcedureType;
			BEGIN
				IF ReturnedAsParameter(right.type)  THEN
					IF right IS SyntaxTree.ProcedureCallDesignator THEN
						procedureType := right(SyntaxTree.ProcedureCallDesignator).left.type.resolved(SyntaxTree.ProcedureType);
						RETURN procedureType.callingConvention = SyntaxTree.OberonCallingConvention
					ELSIF right IS SyntaxTree.BuiltinCallDesignator THEN
						WITH right: SyntaxTree.BuiltinCallDesignator DO
							IF right.id = Global.Reshape THEN RETURN TRUE
							END;
						END;
					END;
				END;
				RETURN FALSE
			END CanPassAsResultParameter;

		BEGIN
			ASSERT(left.type # NIL); ASSERT(right.type # NIL);
			leftType := left.type.resolved; rightType:= right.type.resolved;

			IF backend.cooperative & left.NeedsTrace() THEN
				ModifyAssignments(true);
				IF  (leftType IS SyntaxTree.RecordType) OR IsStaticArray(leftType) THEN
					Designate(right, rightO);
					Designate(left, leftO); 
					ASSERT(leftO.mode = ModeReference);
					TransferToRegister(leftO.op, leftO.op);
					TransferToRegister(rightO.op, rightO.op); 
					Emit(Push(position, leftO.op));
					Emit(Push(position, rightO.op));
					CallAssignMethod(leftO.op, rightO.op, left.type);
					Emit(Pop(position, rightO.op));
					Emit(Pop(position, leftO.op));
					sizeOp := CopySize(left);
					Emit(Copy(position,leftO.op,rightO.op,sizeOp));
					ReleaseOperand(leftO); 
					ReleaseOperand(rightO);
				ELSE
					Evaluate(right,rightO);
					Designate(left,leftO);
					ASSERT(leftO.mode = ModeReference);
					IF (leftType IS SyntaxTree.ProcedureType) THEN
						(* copy procedure address first *)
						MakeMemory(mem,leftO.op,addressType,0);
						Emit(Mov(position,mem,rightO.op));
						ReleaseIntermediateOperand(mem);
						(* copy pointer address *)
						IntermediateCode.MakeAddress(leftO.tag, addressType);
						CallAssignPointer(leftO.tag, rightO.tag);
					ELSE
						ASSERT(system.SizeOf(left.type) = system.addressSize);
						CallAssignPointer(leftO.op, rightO.op);
					END;
					ReleaseOperand(leftO); 
					ReleaseOperand(rightO);
				END;
				ModifyAssignments(false);
				RETURN;
			END;

			IF CanPassAsResultParameter(right) THEN
				procedureResultDesignator := left(SyntaxTree.Designator);
				Expression(right);
				procedureResultDesignator := NIL;
			ELSIF (right IS SyntaxTree.UnaryExpression) & (right(SyntaxTree.UnaryExpression).operator = Scanner.Alias) THEN
				(* left <-- ALIAS OF right: zerocopy *)
				IF GetRuntimeProcedure("FoxArrayBase","ZeroCopy",procedure,TRUE) THEN
					designator := SyntaxTree.NewSymbolDesignator(Diagnostics.Invalid, NIL, procedure);
					designator.SetType(procedure.type);
					parameters := SyntaxTree.NewExpressionList();  parameters.AddExpression(right(SyntaxTree.UnaryExpression).left); parameters.AddExpression(left);
					call := SyntaxTree.NewProcedureCallDesignator(position,designator(SyntaxTree.Designator),parameters);
					VisitProcedureCallDesignator(call(SyntaxTree.ProcedureCallDesignator));
				END;
			ELSIF leftType IS SyntaxTree.RangeType THEN
				(* LHS is of array range type *)
				ASSERT(rightType IS SyntaxTree.RangeType); (* ensured by the checker *)
				Evaluate(right, rightO);
				Designate(left, leftO);(* The order is crucial. Do not reorder emission of left and right *)

				(* first *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.longintType), 0);
				Emit(Mov(position,mem, rightO.op));
				ReleaseIntermediateOperand(mem);

				(* last *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.longintType), ToMemoryUnits(system, system.SizeOf(system.longintType)));
				Emit(Mov(position,mem, rightO.tag));
				ReleaseIntermediateOperand(mem);

				(* step *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, system.longintType), 2 * ToMemoryUnits(system, system.SizeOf(system.longintType)));
				Emit(Mov(position,mem, rightO.extra));
				ReleaseIntermediateOperand(mem);

				ReleaseOperand(rightO);
				ReleaseOperand(leftO)
			ELSIF leftType IS SyntaxTree.ComplexType THEN
				ASSERT(leftType.SameType(rightType)); (* ensured by the checker *)

				Evaluate(right, rightO);
				Designate(left, leftO); (* The order is crucial. Do not reorder emission of left and right *)

				componentType := leftType(SyntaxTree.ComplexType).componentType;

				(* real part *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, componentType), 0);
				Emit(Mov(position,mem, rightO.op));
				ReleaseIntermediateOperand(mem);

				(* imaginary part *)
				MakeMemory(mem, leftO.op, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
				Emit(Mov(position,mem, rightO.tag));
				ReleaseIntermediateOperand(mem);

				ReleaseOperand(rightO);
				ReleaseOperand(leftO)
			ELSIF (leftType IS SyntaxTree.BasicType) OR (leftType IS SyntaxTree.PointerType) OR (leftType IS SyntaxTree.EnumerationType)
				OR (leftType IS SyntaxTree.PortType) THEN
				(* rightO := leftO;*)
				Evaluate(right,rightO);
				(* DO NOT REORDER EMISSION OF LEFT AND RIGHT OPERAND *)
				Designate(left,leftO);
				IF leftO.mode = ModeReference THEN
					MakeMemory(mem,leftO.op,IntermediateCode.GetType(system,left.type),0);
					destination := mem;
				ELSE
					destination := leftO.op;
				END;
				ReleaseOperand(leftO);
				IF destination.mode # IntermediateCode.Undefined THEN
					Emit(Mov(position,destination,rightO.op));
				END;
				ReleaseOperand(rightO);
				ReleaseIntermediateOperand(mem);
				IntermediateCode.InitOperand(destination);
			ELSIF (leftType IS SyntaxTree.ProcedureType) THEN
				Evaluate(right,rightO);
				Designate(left,leftO);
				MakeMemory(mem,leftO.op,addressType,0);
				Emit(Mov(position,mem,rightO.op));
				ReleaseIntermediateOperand(mem);
				IF leftType(SyntaxTree.ProcedureType).isDelegate THEN
					(* delegate *)
					(*
					MakeMemory(leftO.tag,leftO.tag,addressType); no! is already memory
					*)
					Emit(Mov(position,leftO.tag,rightO.tag));
				END;
				ReleaseOperand(leftO);
				ReleaseOperand(rightO);
			ELSIF (leftType IS SyntaxTree.RecordType) THEN
				Designate(right,rightO);
				Designate(left,leftO);
				sizeOp := CopySize(left);
				Emit(Copy(position,leftO.op,rightO.op,sizeOp));
				ReleaseOperand(leftO); ReleaseOperand(rightO);
			ELSIF (leftType IS SyntaxTree.ArrayType) THEN
				IF (rightType IS SyntaxTree.StringType) THEN
					CopyString(left,right);
				ELSIF ((rightType IS SyntaxTree.ArrayType) & (rightType(SyntaxTree.ArrayType).staticLength # 0) OR (rightType IS SyntaxTree.MathArrayType) & (rightType(SyntaxTree.MathArrayType).staticLength # 0)) & (leftType(SyntaxTree.ArrayType).staticLength # 0) THEN
					Designate(right,rightO);
					Designate(left,leftO);
					size := ToMemoryUnits(system,system.SizeOf(rightType));
					Emit(Copy(position,leftO.op, rightO.op, IntermediateCode.Immediate(addressType,size)));
					ReleaseOperand(leftO); ReleaseOperand(rightO);
				ELSE
					HALT(201)
				END;
			ELSIF (leftType IS SyntaxTree.MathArrayType) THEN
				AssignMathArray(left,right);
			ELSE
				HALT(200);
			END;
		END Assign;

		PROCEDURE VisitAssignment(x: SyntaxTree.Assignment);
		BEGIN
			IF Trace THEN TraceEnter("VisitAssignment") END;
			Assign(x.left,x.right);
			IF Trace THEN TraceExit("VisitAssignment") END;
		END VisitAssignment;
		
		PROCEDURE EmitCooperativeSwitch;
		VAR quantum, offset, zero: IntermediateCode.Operand; skip: Label; pc: LONGINT;
		BEGIN
			ASSERT (cooperativeSwitches);
			pc := section.pc; 
			IF lastSwitchPC = section.pc THEN RETURN END;
			IntermediateCode.InitMemory (quantum,  IntermediateCode.SignedIntegerType(addressType.sizeInBits), ap, ToMemoryUnits(system, QuantumOffset * addressType.sizeInBits));
			IntermediateCode.InitImmediate(offset, quantum.type, section.pc - lastSwitchPC); IntermediateCode.InitImmediate(zero, quantum.type, 0); 
			Emit(Sub(position,quantum,quantum, offset)); skip := NewLabel(); BrgeL(skip, quantum, zero);
			lastSwitchPC := section.pc; CallThis(position,"Activities","Switch",0); SetLabel(skip);
			INC(statCoopSwitch, section.pc - pc);
		END EmitCooperativeSwitch;

		PROCEDURE VisitCommunicationStatement(communication: SyntaxTree.CommunicationStatement);
		VAR p0,p1,tmp: SyntaxTree.Expression; s0,s1: Operand; size: LONGINT;
		BEGIN
			p0 := communication.left; p1 := communication.right;
			IF (communication.op = Scanner.ExclamationMark) OR (communication.op = Scanner.LessLess) & (communication.left.type.resolved IS SyntaxTree.PortType) THEN
				Evaluate(p0,s0);
				Evaluate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s0.op));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size > ToMemoryUnits(system, system.addressSize) THEN Error(p1.position,"send not implemented for complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Send",2);
				ELSE
					CallThis(position,ChannelModuleName,"Send",2);
				END;
			(* ----- RECEIVE ------*)
			ELSE
				IF (communication.op = Scanner.LessLess) & (communication.right.type.resolved IS SyntaxTree.PortType) THEN
					tmp := p0; p0 := p1; p1 := tmp;
				END;
				Evaluate(p0,s0);
				Emit(Push(position,s0.op));
				Designate(p1,s1);
				size := ToMemoryUnits(system,system.SizeOf(p1.type));
				Emit(Push(position,s1.op));
				(*
				Emit(Push(position,IntermediateCode.Immediate(addressType,size)));
				*)
				IF ~backend.cellsAreObjects THEN
					IF size > ToMemoryUnits(system, system.addressSize) THEN Error(p1.position,"receive not implemented for  complex data types") END;
				END;
				ReleaseOperand(s0);
				ReleaseOperand(s1);
				IF backend.cellsAreObjects THEN
					CallThis(position,"ActiveCellsRuntime","Receive",2);
				ELSE
					CallThis(position,ChannelModuleName,"Receive",2)
				END;
			END;
		END VisitCommunicationStatement;


		PROCEDURE VisitIfStatement(x: SyntaxTree.IfStatement);
		VAR end: Label; i,elsifs: LONGINT; elsif: SyntaxTree.IfPart; escape: BOOLEAN;

			PROCEDURE IfPart(if: SyntaxTree.IfPart);
			VAR true, false: Label; condition, value: BOOLEAN;
			BEGIN
				condition := ~SemanticChecker.IsBooleanValue(if.condition, value);
				IF condition THEN
					true := NewLabel();
					false := NewLabel();
					Condition(if.condition,true,false);
					SetLabel(true);
					StatementSequence(if.statements);
					BrL(end);
					SetLabel(false);
				ELSE
					IF value THEN (* always true *)
						escape := TRUE;
						StatementSequence(if.statements);
						(* no branch necessary -- rest skipped *)
					END;
				END;
			END IfPart;

		BEGIN
			IF Trace THEN TraceEnter("VisitIfStatement") END;
			end := NewLabel();
			elsifs := x.ElsifParts();
			IfPart(x.ifPart);
			FOR i := 0 TO elsifs-1 DO
				IF ~escape THEN
					elsif := x.GetElsifPart(i);
					IfPart(elsif);
				END;
			END;
			IF (x.elsePart # NIL) & ~escape THEN
				StatementSequence(x.elsePart);
			END;
			SetLabel(end);
			IF Trace THEN TraceExit("VisitIfStatement") END;
		END VisitIfStatement;

		PROCEDURE WithPart(x: SyntaxTree.WithPart; VAR falseL, endL: Label);
		VAR trueL: Label; res: Operand; recordType: SyntaxTree.RecordType;
		BEGIN
			(*IF x.variable.type.resolved = x.type.resolved THEN
				(* always true, do nothing *)
			ELSE*)
			Designate(x.variable,res);
			IF IsPointerToRecord(x.variable.type,recordType) THEN
				Dereference(res,recordType,IsUnsafePointer(x.variable.type))
			END;
			trueL := NewLabel();
			TypeTest(res.tag,x.type,trueL,falseL);
			ReleaseOperand(res);
			SetLabel(trueL);
			StatementSequence(x.statements);
			BrL(endL);
		END WithPart;

		PROCEDURE VisitWithStatement(x: SyntaxTree.WithStatement);
		VAR endL,falseL: Label;i: LONGINT;
		BEGIN
			IF Trace THEN TraceEnter("VisitWithStatement") END;

			endL := NewLabel();
			FOR i := 0 TO x.WithParts()-1 DO
				falseL := NewLabel();
				WithPart(x.GetWithPart(i),falseL,endL);
				SetLabel(falseL);
			END;
			IF x.elsePart = NIL THEN
				IF ~isUnchecked THEN
					EmitTrap(position,WithTrap);
				END;
			ELSE
				StatementSequence(x.elsePart)
			END;
			SetLabel(endL);
			IF Trace THEN TraceExit("VisitWithStatement") END;
		END VisitWithStatement;

		PROCEDURE VisitCaseStatement(x: SyntaxTree.CaseStatement);
		VAR var: Operand; jmp,res,op,tmp: IntermediateCode.Operand; j,i,size: LONGINT; part: SyntaxTree.CasePart; constant: SyntaxTree.CaseConstant;
			out,else: Label; label: Label;
			fixups: POINTER TO ARRAY OF Label; section: IntermediateCode.Section; name: Basic.SegmentedName; string: ARRAY 32 OF CHAR;
			symbol: SyntaxTree.Symbol;
		BEGIN
			(*! split case statement into if-elsif statements for large case label lists *)
			IF Trace THEN TraceEnter("VisitCaseStatement") END;
			size := x.max-x.min+1;
			IF (size<0) OR (size > 1024*1024) THEN Error(x.position,"implementation restriction: case table size too large"); RETURN
			END;
			Evaluate(x.variable,var);
			ReuseCopy(tmp,var.op);
			ReleaseIntermediateOperand(var.op);
			var.op := tmp;
			Emit(Sub(position,var.op,var.op,IntermediateCode.Immediate(IntermediateCode.GetType(system,x.variable.type),x.min)));
			Convert(var.op,addressType);
			size := x.max-x.min+1;
			else := NewLabel();
			BrgeL(else,var.op,IntermediateCode.Immediate(addressType,size));
			(*
			UniqueId(name,module.module,"case",caseId);
			*)
			string := "@case"; Basic.AppendNumber(string, caseId); INC(caseId);
			Global.GetModuleSegmentedName(module.module, name);
			Basic.SuffixSegmentedName(name,Basic.MakeString(string));
			symbol := SyntaxTree.NewSymbol(name[1]);
			symbol.SetScope(moduleScope);
			NEW(fixups,size); FOR i := 0 TO size-1 DO fixups[i] := NIL END;
			section := NewSection(module.allSections, Sections.ConstSection,name,SyntaxTree.NewSymbol(name[1]),commentPrintout # NIL);
			section.isCaseTable := TRUE;
			IntermediateCode.InitAddress(jmp, addressType, section.name, GetFingerprint(section.symbol), 0);
			ReuseCopy(res,var.op);
			ReleaseOperand(var);
			Emit(Mul(position,res,res,IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.addressSize))));
			Emit(Add(position,res,res,jmp));
			IntermediateCode.MakeMemory(res,addressType);
			Emit(Br(position,res));
			ReleaseIntermediateOperand(res);
			out := NewLabel();
			FOR i := 0 TO x.caseParts.Length()-1 DO (* case parts *)
				part := x.GetCasePart(i);
				constant := part.firstConstant;
				label := NewLabel();
				SetLabel(label);
				WHILE(constant # NIL) DO (* case labels for this case part *)
					FOR j := constant.min TO constant.max DO
						fixups[j-x.min] := label;
					END;
					constant := constant.next;
				END;
				StatementSequence(part.statements);
				BrL(out);
			END;
			SetLabel(else);
			FOR i := 0 TO size-1 DO
				IF fixups[i] = NIL THEN
					fixups[i] := else;
				END;
			END;
			IF x.elsePart # NIL THEN
				StatementSequence(x.elsePart);
			ELSIF ~isUnchecked THEN
				EmitTrap(position,CaseTrap);
			END;
			SetLabel(out);
			FOR i := 0 TO size-1 DO
				IntermediateCode.InitAddress(op, addressType, fixups[i].section.name, GetFingerprint(fixups[i].section.symbol), fixups[i].pc);
				section.Emit(Data(position,op));
			END;
			IF Trace THEN TraceExit("VisitCaseStatement") END;
		END VisitCaseStatement;


		PROCEDURE VisitWhileStatement(x: SyntaxTree.WhileStatement);
		VAR start: Label; true,false: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitWhileStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			start := NewLabel();
			true := NewLabel();
			false := NewLabel();
			SetLabel(start);
			Condition(x.condition,true,false);
			SetLabel(true);
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			BrL(start);
			SetLabel(false);
			IF Trace THEN TraceExit("VisitWhileStatement") END;
		END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement(x: SyntaxTree.RepeatStatement);
		VAR false,true: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitRepeatStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			true := NewLabel();
			false := NewLabel();
			SetLabel(false);
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			Condition(x.condition,true,false);
			SetLabel(true);
			IF Trace THEN TraceExit("VisitRepeatStatement") END;
		END VisitRepeatStatement;

		PROCEDURE VisitForStatement(x: SyntaxTree.ForStatement);
		VAR
			binary: SyntaxTree.BinaryExpression; start,true,false : Label; cmp: LONGINT; by: HUGEINT;
			temporaryVariable: SyntaxTree.Variable;
			temporaryVariableDesignator : SyntaxTree.Designator;
		BEGIN
			IF Trace THEN TraceEnter("VisitForStatement") END;
			true := NewLabel();
			false := NewLabel();
			start := NewLabel();

			Assign(x.variable,x.from);
			temporaryVariable := GetTemporaryVariable(x.variable.type, FALSE);
			temporaryVariableDesignator := SyntaxTree.NewSymbolDesignator(SemanticChecker.InvalidPosition, NIL, temporaryVariable);
			temporaryVariableDesignator.SetType(x.variable.type.resolved);


			Assign(temporaryVariableDesignator,x.to);
			IF x.by = NIL THEN by := 1 ELSE by := x.by.resolved(SyntaxTree.IntegerValue).hvalue END;
			IF by > 0 THEN
				cmp := Scanner.LessEqual
			ELSE
				cmp := Scanner.GreaterEqual
			END;
			binary := SyntaxTree.NewBinaryExpression(0,x.variable,temporaryVariableDesignator,cmp);
			binary.SetType(system.booleanType);

			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			SetLabel(start);


			Condition(binary,true,false);
			SetLabel(true);
			StatementSequence(x.statements);

			binary := SyntaxTree.NewBinaryExpression(0,x.variable,x.by,Scanner.Plus);
			binary.SetType(x.variable.type);
			Assign(x.variable,binary);

			IF cooperativeSwitches THEN EmitCooperativeSwitch END;

			BrL(start);
			SetLabel(false);

			IF Trace THEN TraceExit("VisitForStatement") END;
		END VisitForStatement;

		PROCEDURE VisitExitableBlock(x: SyntaxTree.ExitableBlock);
		VAR prevLoop: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitExitableBlock") END;
			prevLoop := currentLoop;
			currentLoop := NewLabel();
			StatementSequence(x.statements);
			SetLabel(currentLoop);
			currentLoop := prevLoop;
			IF Trace THEN TraceExit("VisitExitableBlock") END;
		END VisitExitableBlock;

		PROCEDURE VisitLoopStatement(x: SyntaxTree.LoopStatement);
		VAR prevLoop,start: Label;
		BEGIN
			IF Trace THEN TraceEnter("VisitLoopStatement") END;
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			start := NewLabel();
			prevLoop := currentLoop;
			SetLabel(start);
			currentLoop := NewLabel();
			StatementSequence(x.statements);
			IF cooperativeSwitches THEN EmitCooperativeSwitch END;
			BrL(start);
			SetLabel(currentLoop);
			currentLoop := prevLoop;
			IF Trace THEN TraceExit("VisitLoopStatement") END;
		END VisitLoopStatement;

		PROCEDURE VisitExitStatement(x: SyntaxTree.ExitStatement);
		VAR outer: SyntaxTree.Statement;
		BEGIN
			IF Trace THEN TraceEnter("VisitExitStatement") END;
			IF locked  THEN (* r if we jump out of an exclusive block *)
				outer := x.outer;
				WHILE ~(outer IS SyntaxTree.ExitableBlock) & ~((outer IS SyntaxTree.StatementBlock) & outer(SyntaxTree.StatementBlock).isExclusive) DO
					outer := outer.outer;
				END;
				IF ~(outer IS SyntaxTree.ExitableBlock) THEN
					Lock(FALSE);
				END;
			END;
			BrL(currentLoop);
			IF Trace THEN TraceExit("VisitExitStatement") END;
		END VisitExitStatement;

		PROCEDURE VisitReturnStatement(x: SyntaxTree.ReturnStatement);
		VAR
			expression, parameterDesignator: SyntaxTree.Expression;
			type, componentType: SyntaxTree.Type;
			res, right: Operand;
			left, mem, reg: IntermediateCode.Operand;
			parameter: SyntaxTree.Parameter;
			procedure: SyntaxTree.Procedure;
			procedureType: SyntaxTree.ProcedureType;
			returnTypeOffset: LONGINT;
			delegate: BOOLEAN;
			map: SymbolMap;
		BEGIN
			IF Trace THEN TraceEnter("VisitReturnStatement") END;
			expression := x.returnValue;
			procedure := currentScope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);

			IF currentIsInline THEN
				IF expression # NIL THEN
					map := currentMapper.Get(NIL);
					IF map # NIL THEN
						Assign(map.to, expression);
					END;
				END;
				BrL(currentInlineExit);
				RETURN;
			END;

			IF expression # NIL THEN
				type := expression.type.resolved;
				IF (expression IS SyntaxTree.ResultDesignator) THEN
					IF locked THEN Lock(FALSE) END;
					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
					(* "RETURN RESULT" -> no assignment, it is assumed that result has been written to return parameter via structured return type *)
				ELSIF (type IS SyntaxTree.BasicType) & ~(type IS SyntaxTree.RangeType) & ~(type IS SyntaxTree.ComplexType) & ~type.IsPointer() OR (procedureType.callingConvention # SyntaxTree.OberonCallingConvention) THEN
					(* return without structured return parameter *)
					Evaluate(expression,res);
					delegate := (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate);
					IF locked OR profile THEN
						Emit(Push(position,res.op));
						IF delegate THEN HALT(200) END;
						ReleaseOperand(res);
						IF locked THEN Lock(FALSE) END;
						IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
						reg := NewRegisterOperand(res.op.type);
						Emit(Pop(position,reg));
						Emit(Return(position,reg));
						ReleaseIntermediateOperand(reg);
					ELSE
						Emit(Return(position,res.op));
						ReleaseOperand(res);
					END;
				ELSIF (type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR type.IsPointer()
				THEN
					(* return using structured return parameter *)
					ASSERT((type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static)
						OR SemanticChecker.IsPointerType(type));
					(* parameter := currentScope(SyntaxTree.ProcedureScope).FindParameter(Global.ReturnParameterName); *)
					parameter :=procedureType.returnParameter;
					ASSERT(parameter # NIL);
					returnTypeOffset := parameter.offsetInBits;
					(*
					IF parameter# NIL THEN
						returnTypeOffset := parameter.offsetInBits + system.SizeOfParameter(parameter);
						INC(returnTypeOffset,(-returnTypeOffset) MOD system.AlignmentOf(system.parameterAlignment,parameter.type));
					ELSE
						returnTypeOffset := system.offsetFirstParameter
					END;
					*)
					left := IntermediateCode.Memory(addressType,fp,ToMemoryUnits(system,returnTypeOffset));

					IF type IS SyntaxTree.RangeType THEN
						(* array range type *)
						Evaluate(expression, right);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.longintType), 0);
						Emit(Mov(position,mem, right.op)); (* first *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.longintType), ToMemoryUnits(system, system.SizeOf(system.longintType)));
						Emit(Mov(position,mem, right.tag)); (* last *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, system.longintType), 2 * ToMemoryUnits(system, system.SizeOf(system.longintType)));
						Emit(Mov(position,mem, right.extra)); (* step *)
						ReleaseIntermediateOperand(mem);

						ReleaseOperand(right);
					ELSIF type IS SyntaxTree.ComplexType THEN
						Evaluate(expression, right);
						componentType := type(SyntaxTree.ComplexType).componentType;

						MakeMemory(mem, left, IntermediateCode.GetType(system, componentType), 0);
						Emit(Mov(position,mem, right.op)); (* real part *)
						ReleaseIntermediateOperand(mem);

						MakeMemory(mem, left, IntermediateCode.GetType(system, componentType), ToMemoryUnits(system, system.SizeOf(componentType)));
						Emit(Mov(position,mem, right.tag)); (* imaginary part *)
						ReleaseIntermediateOperand(mem);

						ReleaseOperand(right);
					ELSE (* covers cases: pointer / record / array *)
						parameter := procedureType.returnParameter;
						checker.SetCurrentScope(currentScope);
						ASSERT(parameter # NIL); 
						parameterDesignator := checker.NewSymbolDesignator(expression.position,NIL,parameter);
						Assign(parameterDesignator,expression);
					END;
					ReleaseIntermediateOperand(left);
					IF locked THEN Lock(FALSE) END;
					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
				ELSIF (type IS SyntaxTree.MathArrayType) OR (type IS SyntaxTree.ProcedureType) THEN
					parameter := procedureType.returnParameter;
					checker.SetCurrentScope(currentScope);

					IF parameter = NIL THEN
						Error(procedure.position, "structured return of parameter of procedure not found");
					ELSE
						parameterDesignator := checker.NewSymbolDesignator(expression.position,NIL,parameter);
						Assign(parameterDesignator,expression);
					END;
					IF locked THEN Lock(FALSE) END;
					IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
				ELSE
					HALT(200);
				END;
			ELSE
				IF locked THEN Lock(FALSE) END;
				IF ~backend.cooperative & profile THEN ProfilerEnterExit(numberProcedures,FALSE) END;
			END;

			IF backend.cooperative THEN
				BrL(exitLabel);
			ELSE
				EmitLeave(section, position,procedure.type(SyntaxTree.ProcedureType).callingConvention);
				Emit(Exit(position,procedure.type(SyntaxTree.ProcedureType).pcOffset,procedure.type(SyntaxTree.ProcedureType).callingConvention));
			END;
			IF Trace THEN TraceExit("VisitReturnStatement") END;
		END VisitReturnStatement;

		PROCEDURE MakeAwaitProcedure(x: SyntaxTree.AwaitStatement): SyntaxTree.Procedure;
		VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; procedureScope: SyntaxTree.ProcedureScope;
			identifier: SyntaxTree.Identifier; body: SyntaxTree.Body; returnStatement : SyntaxTree.ReturnStatement;
			statements: SyntaxTree.StatementSequence;
			name, suffix: SyntaxTree.IdentifierString;
		BEGIN
			Strings.IntToStr(awaitProcCounter,suffix);
			Strings.Concat("@AwaitProcedure",suffix,name);
			identifier := SyntaxTree.NewIdentifier(name);
			INC(awaitProcCounter);
			ASSERT(currentScope IS SyntaxTree.ProcedureScope);
			procedureScope := SyntaxTree.NewProcedureScope(currentScope);
			ASSERT(procedureScope.outerScope IS SyntaxTree.ProcedureScope);
			procedure := SyntaxTree.NewProcedure(x.position,identifier,procedureScope);
			procedure.SetAccess(SyntaxTree.Hidden);
			procedure.SetScope(currentScope);
			procedureType := SyntaxTree.NewProcedureType(x.position,currentScope);
			procedureType.SetReturnType(system.booleanType);
			procedure.SetType(procedureType);
			body := SyntaxTree.NewBody(x.position,procedureScope);
			procedureScope.SetBody(body);
			returnStatement := SyntaxTree.NewReturnStatement(x.position,body);
			returnStatement.SetReturnValue(x.condition);
			statements := SyntaxTree.NewStatementSequence();
			statements.AddStatement(returnStatement);
			body.SetStatementSequence(statements);
			currentScope.AddProcedure(procedure);
			RETURN procedure
		END MakeAwaitProcedure;

		PROCEDURE VisitAwaitStatement(x: SyntaxTree.AwaitStatement);
		VAR proc: SyntaxTree.Procedure; res: IntermediateCode.Operand; symbol: Sections.Section;
			call: IntermediateCode.Operand; label, start, true, false: Label; name: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("VisitAwaitStatement") END;
			IF profile THEN ProfilerEnterExit(numberProcedures, FALSE) END;
			
			IF backend.cooperative THEN
				start := NewLabel();
				true := NewLabel();
				false := NewLabel();
				SetLabel(start);
				Condition(x.condition,true,false);
				SetLabel(false);
				PushSelfPointer();
				CallThis(position,"ExclusiveBlocks","Await",1);
				BrL(start);
				SetLabel(true);
				PushSelfPointer();
				CallThis(position,"ExclusiveBlocks","FinalizeAwait",1);
			ELSE
				proc := MakeAwaitProcedure(x);
				Emit(Push(position,fp));
				GetCodeSectionNameForSymbol(proc,name);
				symbol := NewSection(module.allSections, Sections.CodeSection, name,proc,commentPrintout # NIL);
				IntermediateCode.InitAddress(call,addressType,name, GetFingerprint(proc), 0);
				res := NewRegisterOperand(IntermediateCode.GetType(system,system.booleanType));
				Emit(Call(position,call,ProcedureParametersSize(system,proc)));
				Emit(Result(position,res));
				(*
				AcquireThisRegister(IntermediateCode.GetType(system,system.booleanType),IntermediateCode.Result);
				IntermediateCode.InitRegister(res,IntermediateCode.GetType(system,system.booleanType),IntermediateCode.Result);
				*)
				InitOperand(result,ModeValue);
				result.op := res;
				label := NewLabel();
				BreqL(label, result.op, SELF.true);
				ReleaseOperand(result);
				symbol := NewSection(module.allSections, Sections.CodeSection, name,proc,commentPrintout # NIL);
				IntermediateCode.InitAddress(res, addressType, name,GetFingerprint(proc), 0);
				Emit(Push(position,res));
				Emit(Push(position,fp));
				PushSelfPointer();
				Emit(Push(position,nil));
				CallThis(position,"Objects","Await",4);
				SetLabel(label);
			END;

			IF profile THEN ProfilerEnterExit(numberProcedures, TRUE) END;

			IF Trace THEN TraceExit("VisitAwaitStatement") END;
		END VisitAwaitStatement;

		PROCEDURE StatementSequence(x: SyntaxTree.StatementSequence);
		VAR statement: SyntaxTree.Statement;  i: LONGINT; (* pos: LONGINT; *)
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				statement := x.GetStatement( i );
				Statement(statement);
				IF cooperativeSwitches & (section.pc - lastSwitchPC > 1000) THEN EmitCooperativeSwitch END;
			END;
		END StatementSequence;

		PROCEDURE PushSelfPointer;
		VAR scope: SyntaxTree.Scope;  op: Operand; moduleSection: IntermediateCode.Section; moduleOffset, parametersSize: LONGINT;
		BEGIN
			scope := currentScope;
			WHILE(scope.outerScope IS SyntaxTree.ProcedureScope) DO
				scope := scope.outerScope;
			END;
			IF scope.outerScope IS SyntaxTree.ModuleScope THEN
				IF ~newObjectFile THEN
					Symbol(moduleSelf,op);
					IntermediateCode.MakeMemory(op.op,addressType);
				ELSE
					moduleSection := meta.ModuleSection();
					IF backend.cooperative THEN
						moduleOffset := 0;
					ELSE
						moduleOffset := moduleSection.pc;
					END;
					op.op := IntermediateCode.Address(addressType, moduleSection.name, GetFingerprint(moduleSection.symbol), moduleOffset);
				END;
			ELSE
				GetBaseRegister(op.op,currentScope,scope);
				parametersSize := ProcedureParametersSize(system,scope(SyntaxTree.ProcedureScope).ownerProcedure);
				IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,addressType.sizeInBits)+parametersSize);
				IF backend.cooperative THEN
					IntermediateCode.AddOffset(op.op,ToMemoryUnits(system,addressType.sizeInBits));
				END;
				IntermediateCode.MakeMemory(op.op,addressType);
			END;
			Emit(Push(position,op.op));
			ReleaseOperand(op);
		END PushSelfPointer;

		PROCEDURE Lock(lock: BOOLEAN);
		BEGIN
			IF Trace THEN TraceEnter("Lock") END;
			IF profile THEN ProfilerEnterExit(numberProcedures, FALSE) END;
			CheckRegistersFree(); (* no register may be in use as operands should not be preserved over the lock / unlock boundary *)
			ASSERT(modifyAssignmentCounter = 0);
			IF dump # NIL THEN
				IF lock THEN dump.String("lock") ELSE dump.String("unlock") END;
				dump.Ln;dump.Update;
			END;
			PushSelfPointer;
			IF backend.cooperative THEN
				Emit(Push(position,IntermediateCode.Immediate(sizeType, 1)));
				IF lock THEN CallThis(position,"ExclusiveBlocks","Enter",2)
				ELSE CallThis(position,"ExclusiveBlocks","Exit",2);
				END;
			ELSE
				Emit(Push(position,true));
				IF lock THEN CallThis(position,"Objects","Lock",2)
				ELSE CallThis(position,"Objects","Unlock",2);
				END;
			END;
			IF profile THEN ProfilerEnterExit(numberProcedures, TRUE) END;
			IF Trace THEN TraceExit("Lock") END;
		END Lock;

		PROCEDURE VisitStatementBlock(x: SyntaxTree.StatementBlock);
		VAR previouslyUnchecked, previouslyCooperativeSwitches: BOOLEAN;
		BEGIN
			IF Trace THEN TraceEnter("VisitStatementBlock") END;
			IF emitLabels THEN Emit(LabelInstruction(x.position)) END;

			previouslyUnchecked := isUnchecked;
			isUnchecked := isUnchecked OR x.isUnchecked;
			previouslyCooperativeSwitches := cooperativeSwitches;
			cooperativeSwitches := cooperativeSwitches & ~x.isUncooperative;

			IF x.isExclusive THEN Lock(TRUE); ASSERT(~locked);  locked := TRUE; END;
			IF x.statements # NIL THEN
				StatementSequence(x.statements);
			END;
			IF x.isExclusive THEN Lock(FALSE); ASSERT(locked); locked := FALSE; END;
			isUnchecked := previouslyUnchecked;
			cooperativeSwitches := previouslyCooperativeSwitches;

			IF Trace THEN TraceExit("VisitStatementBlock") END;
		END VisitStatementBlock;

		PROCEDURE VisitCode(x: SyntaxTree.Code);
		VAR (*  inline: Sections.CellNet; symbol: SyntaxTree.Symbol; *)
			in, out: IntermediateCode.Rules; statement: SyntaxTree.Statement; i: LONGINT; operand,par: Operand; str: POINTER TO ARRAY OF CHAR;
				result, mem: IntermediateCode.Operand; scope: SyntaxTree.Scope; procedureType: SyntaxTree.ProcedureType; return: IntermediateCode.Operand;
				procedure: SyntaxTree.Procedure;
				map: SymbolMap;
		BEGIN
			scope := currentScope;
			WHILE ~(scope IS SyntaxTree.ProcedureScope) DO scope := scope.outerScope END;
			procedure :=  scope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);
			return := emptyOperand;

			IF Trace THEN TraceEnter("VisitCode") END;
			IF (x.inRules # NIL) & (x.inRules.Length()>0) THEN
				NEW(in, x.inRules.Length());
				FOR i := 0 TO LEN(in)-1 DO
					statement := x.inRules.GetStatement(i);
					WITH statement: SyntaxTree.Assignment DO
						Evaluate(statement.right, operand);
						result := operand.op;
						NEW(str, 64);
						Basic.GetString(statement.left(SyntaxTree.IdentifierDesignator).identifier, str^);
						in[i] := result; IntermediateCode.SetString(in[i], str);
						ReleaseIntermediateOperand(operand.tag);
					END;
				END;
			ELSE in := NIL
			END;
			IF (x.outRules # NIL) & (x.outRules.Length()>0) THEN
				NEW(out, x.outRules.Length());
				FOR i := 0 TO LEN(out)-1 DO
					statement := x.outRules.GetStatement(i);
					IF statement IS SyntaxTree.StatementBlock THEN statement := statement(SyntaxTree.StatementBlock).statements.GetStatement(0) END;
					WITH statement: SyntaxTree.Assignment DO
						Evaluate(statement.left, operand); (*?? or designate *)
						result := operand.op;
						NEW(str, 64);
						Basic.GetString(statement.right(SyntaxTree.IdentifierDesignator).identifier, str^);
						out[i] := result; IntermediateCode.SetString(out[i], str);
						ReleaseIntermediateOperand(operand.tag);
					|statement: SyntaxTree.ReturnStatement DO
						NEW(str, 64);
						Basic.GetString(statement.returnValue(SyntaxTree.IdentifierDesignator).identifier, str^);
						IF currentIsInline THEN
							map := currentMapper.Get(NIL);
							Evaluate(map.to, operand);
							out[i] := operand.op;
						ELSE
							out[i] :=NewRegisterOperand(IntermediateCode.GetType(system, procedureType.returnType));
						END;
						IntermediateCode.SetString(out[i], str);
						ReleaseIntermediateOperand(operand.tag);
						return := out[i];
					ELSE
					END;
				END;
			ELSE out := NIL
			END;
			Emit(Asm(x.position,x.sourceCode, in, out));
			IF in # NIL THEN
				FOR i := 0 TO LEN(in)-1 DO
					ReleaseIntermediateOperand(in[i]);
				END;
			END;
			IF out # NIL THEN
				FOR i := 0 TO LEN(out)-1 DO
					WITH statement: SyntaxTree.Assignment DO
						ReleaseIntermediateOperand(out[i]);
					ELSE
						IF currentIsInline THEN
							ReleaseIntermediateOperand(out[i]);
						END;
					END;
					statement := x.outRules.GetStatement(i);
				END;
			END;
			IF return.mode # IntermediateCode.Undefined THEN

				IF currentIsInline THEN
				ELSIF ReturnedAsParameter(procedureType.returnType) THEN
					Symbol(procedureType.returnParameter, par);
					MakeMemory(mem, par.op, return.type, 0);
					ReleaseOperand(par);
					Emit(Mov(position, mem, return));
					ReleaseIntermediateOperand(mem);
				ELSE
					Emit(Return(position,return));
				END;
				IF currentIsInline THEN RETURN END;

				EmitLeave(section, position,procedureType(SyntaxTree.ProcedureType).callingConvention);
				Emit(Exit(position,procedureType(SyntaxTree.ProcedureType).pcOffset,procedureType(SyntaxTree.ProcedureType).callingConvention));
				ReleaseIntermediateOperand(return);
			END;

			IF Trace THEN TraceExit("VisitCode") END;
		END VisitCode;

		PROCEDURE ParameterCopies(x: SyntaxTree.ProcedureType);
		VAR parameter: SyntaxTree.Parameter; type, base: SyntaxTree.Type; 
			op: Operand; temp,size,par,dst, length,null: IntermediateCode.Operand;
			const, call: IntermediateCode.Operand;
			parameterDesignator: SyntaxTree.Expression;
			saved: RegisterEntry;
			name: Basic.SegmentedName;
		BEGIN
			IF Trace THEN TraceEnter("ParameterCopies") END;
			parameter := x.firstParameter;
			WHILE parameter # NIL DO
				IF parameter.kind = SyntaxTree.ValueParameter THEN
					type := parameter.type.resolved;
					IF IsOpenArray(type) THEN
						VisitParameter(parameter);
						op := result;
						IF backend.cooperative & parameter.NeedsTrace() THEN
							length := GetArrayLength(type, op.tag);
							size := NewRegisterOperand(addressType);
							base := ArrayBaseType(type);
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,system.SizeOf(base)));							
							Emit(Mul(position, size, length, const)); 
							
							dst := NewRegisterOperand (addressType);
							Emit(Mov(position, dst, size));
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,-system.addressSize)); (* alignment *)
							Emit(Sub(position,dst,sp,dst));
							Emit(And(position,dst,dst,const));
							Emit(Mov(position,sp,dst));
							par := fp;
							IntermediateCode.AddOffset(par,ToMemoryUnits(system,parameter.offsetInBits));
							IntermediateCode.InitImmediate(null, byteType, 0);
							Emit(Fill(position, dst, size, null));
							ReleaseIntermediateOperand(dst);
							ReleaseIntermediateOperand(length);
							SaveRegisters();ReleaseUsedRegisters(saved);
							(* register dst has been freed before SaveRegisters already *)
							base := ArrayBaseType(type);
							(* assign method of open array *)
							IF base.IsRecordType() THEN
								Emit (Push(position, length));					
								Emit (Push(position, dst));
								Emit (Push(position, op.op));
								GetRecordTypeName (base.resolved(SyntaxTree.RecordType),name);
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Array"));
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Assign"));
								IntermediateCode.InitAddress(call, addressType, name , 0, 0);
								Emit(Call(position,call,ToMemoryUnits(system, 3*system.addressSize)));
							ELSIF base.resolved IS SyntaxTree.ProcedureType THEN (* array of delegates *)
								Emit (Push(position,length));
								Emit (Push(position, dst));
								Emit (Push(position, length));
								Emit (Push(position, op.op));
								CallThis(position,"GarbageCollector","AssignDelegateArray", 4);
							ELSE 
								Emit (Push(position, length));
								Emit (Push(position, dst));
								Emit (Push(position, length));
								Emit (Push(position, op.op));
								CallThis(position,"GarbageCollector","AssignPointerArray", 4);
								ASSERT(ArrayBaseType(type).IsPointer());
							END;
							RestoreRegisters(saved);
						ELSE
							temp := GetDynamicSize(type,op.tag);
							ReuseCopy(size,temp);
							ReleaseIntermediateOperand(temp);
							const := IntermediateCode.Immediate(addressType,ToMemoryUnits(system,-system.addressSize)); (* alignment *)
							Emit(Sub(position,size,sp,size));
							Emit(And(position,size,size,const));
							Emit(Mov(position,sp,size));
							par := fp;
							IntermediateCode.AddOffset(par,ToMemoryUnits(system,parameter.offsetInBits));
							ReleaseIntermediateOperand(size);
							size := GetDynamicSize(type,op.tag);
						END;
												
						Emit(Copy(position,sp,op.op,size));
						ReleaseIntermediateOperand(size);
						ReleaseOperand(op);
						IntermediateCode.MakeMemory(par,addressType);
						Emit(Mov(position,par,sp));
					ELSIF (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) THEN
						checker.SetCurrentScope(currentScope);
						parameterDesignator := checker.NewSymbolDesignator(position,NIL,parameter);
						Assign(parameterDesignator,parameterDesignator);
					END;
				END;
				parameter := parameter.nextParameter;
			END;
			IF Trace THEN TraceExit("ParameterCopies") END;
		END ParameterCopies;

		PROCEDURE InitVariables(scope: SyntaxTree.Scope);
		VAR x: SyntaxTree.Variable;
		BEGIN
			x := scope.firstVariable;
			WHILE x # NIL DO
				InitVariable(x);
				x := x.nextVariable;
			END;
		END InitVariables;

		PROCEDURE GetFingerprint(symbol: SyntaxTree.Symbol): LONGINT;
		BEGIN
			IF (symbol # NIL) THEN
				RETURN fingerPrinter.SymbolFP(symbol).shallow
			ELSE
				RETURN 0
			END;
		END GetFingerprint;


		PROCEDURE Body(x: SyntaxTree.Body; scope: SyntaxTree.Scope; ir: IntermediateCode.Section; moduleBody: BOOLEAN);
		VAR prevScope: SyntaxTree.Scope; procedureType: SyntaxTree.ProcedureType; procedure: SyntaxTree.Procedure;
			cellScope: SyntaxTree.CellScope; op: Operand; string: SyntaxTree.IdentifierString;
			saved: RegisterEntry;
		BEGIN
			IF Trace THEN TraceEnter("Body") END;
			ReleaseUsedRegisters(saved); (* just in case ... *)
			section := ir;
			exitLabel := NewLabel ();
			IF moduleBody THEN moduleBodySection := section END;
			IF ir.comments # NIL THEN
				commentPrintout := Printout.NewPrinter(ir.comments,Printout.SourceCode,FALSE);
				commentPrintout.SingleStatement(TRUE);
				dump := ir.comments;
			ELSE
				commentPrintout := NIL;
				dump := NIL;
			END;


			prevScope := currentScope;
			currentScope := scope;
			
			lastSwitchPC := 0;
			cooperativeSwitches := backend.cooperative;

			procedure := scope(SyntaxTree.ProcedureScope).ownerProcedure;
			procedureType := procedure.type(SyntaxTree.ProcedureType);
			IF x # NIL THEN
				IF emitLabels THEN Emit(LabelInstruction(x.position)) END;
				IF profile & (x.code = NIL) THEN (* do not profile assembler code sections *)
					IF moduleBody THEN
						ProfilerInit();
					ELSE
						Basic.SegmentedNameToString(ir.name, string);
						ProfilerAddProcedure(numberProcedures,string);
						ProfilerEnterExit(numberProcedures,TRUE);
					END;
				END;

				IF moduleBody & (operatorInitializationCodeSection # NIL) THEN
					Emit(Call(position,IntermediateCode.Address(addressType, operatorInitializationCodeSection.name, GetFingerprint(operatorInitializationCodeSection.symbol),  0), 0))
				END;

				section.SetPositionOrAlignment(procedure.fixed, procedure.alignment);
				IF moduleBody THEN
					(* InitVariables(moduleScope) *)
				END;
				IF (scope.outerScope # NIL) & (scope.outerScope IS SyntaxTree.CellScope) THEN
					cellScope := scope.outerScope(SyntaxTree.CellScope);
					IF procedure = cellScope.bodyProcedure THEN
						IF (cellScope.constructor # NIL) & ~backend.cellsAreObjects THEN
							StaticCallOperand(op, cellScope.constructor);
							Emit(Call(position,op.op,0));
						END;
					END;
				END;

				ParameterCopies(procedureType);
				InitVariables(scope);
				IF x.code = NIL THEN
					VisitStatementBlock(x);
				ELSE
					VisitCode(x.code)
				END;
				IF x.finally # NIL THEN (*! mark finally block for object file *)
					ir.SetFinally(ir.pc);
					StatementSequence(x.finally)
				END;
				IF profile & (x.code = NIL) & ~moduleBody THEN (* do not profile assembler code sections *)
					IF ~backend.cooperative THEN 
						ProfilerEnterExit(numberProcedures,FALSE);
					END;
					INC(numberProcedures);
				END;
			END;
			IF backend.cooperative THEN
				IF HasPointers (procedure.procedureScope) THEN CreateResetMethod (procedure.procedureScope) END;
				IF HasPointers (procedure.procedureScope) OR HasVariableParameters (procedure.procedureScope) OR IsNested (procedure) THEN CreateProcedureDescriptor (procedure) END;
			ELSIF newObjectFile & moduleBody  & ~suppressModuleRegistration & ~meta.simple THEN
				(*! not required any more? check and delete!
				PushSelfPointer();
				CallThis(position,"Modules","SetInitialized",1);
				*)
				(*
				SetLabel(end);
				*)
			END;
			IF x # NIL THEN
				SELF.position := x.position;
			END;
			CheckRegistersFree();
			ASSERT(modifyAssignmentCounter = 0);
			currentScope := prevScope;
			IF Trace THEN TraceExit("Body") END;
		END Body;

	END ImplementationVisitor;

	MetaDataGenerator=OBJECT
	VAR
		implementationVisitor: ImplementationVisitor;
		declarationVisitor: DeclarationVisitor;
		module: Sections.Module;
		moduleName: ARRAY 128 OF CHAR;
 		moduleNamePool: Basic.HashTableInt;
 		moduleNamePoolSection: IntermediateCode.Section;
 		
		simple: BOOLEAN; (* simple = no methods, no module loading, no reflection *)

		MethodTableOffset: LONGINT; (* method table offset from zero *)
		BaseTypesTableOffset: LONGINT;	(* table with all record extensions offset *)
		TypeTags: LONGINT; (* type extension level support *)
		TypeRecordBaseOffset: LONGINT; (* offset of type zero offset (without method entries) *)
		

		PROCEDURE &InitMetaDataGenerator(implementationVisitor: ImplementationVisitor; declarationVisitor: DeclarationVisitor; simple: BOOLEAN);
		BEGIN
			IF implementationVisitor.backend.cooperative THEN
				TypeTags := MAX(LONGINT); 
				BaseTypesTableOffset := 0;
				MethodTableOffset := 2;
				TypeRecordBaseOffset := 0;			
			ELSIF simple THEN
				TypeTags := 3; (* only 3 extensions allowed *)
				BaseTypesTableOffset := 1;
				MethodTableOffset := BaseTypesTableOffset+TypeTags;
				TypeRecordBaseOffset := 0;
			ELSE
				TypeTags := 16;
				BaseTypesTableOffset := -2; (* typeInfo and size field *)
				MethodTableOffset := -TypeTags+BaseTypesTableOffset;
				TypeRecordBaseOffset := TypeTags + 2; (* MPO, typeInfo *)
			END;
			SELF.simple := simple;
			SELF.implementationVisitor := implementationVisitor;
			SELF.declarationVisitor := declarationVisitor;
			implementationVisitor.meta := SELF;
			declarationVisitor.meta := SELF;
		END InitMetaDataGenerator;

		PROCEDURE SetModule(module: Sections.Module);
		VAR namePoolOffset: LONGINT;
		BEGIN
			SELF.module := module;
			Global.GetModuleName(module.module,moduleName);
			IF ReflectionSupport &  implementationVisitor.newObjectFile & ~simple THEN 
				NEW(moduleNamePool, 32);
				moduleNamePoolSection := Block("Heaps","SystemBlockDesc",".@ModuleNamePool", namePoolOffset);
			END;
		END SetModule;

		PROCEDURE GetTypeRecordBaseOffset(numberMethods: LONGINT): LONGINT;
		BEGIN
			IF implementationVisitor.backend.cooperative OR simple THEN RETURN 0 ELSE RETURN TypeRecordBaseOffset + numberMethods END;
		END GetTypeRecordBaseOffset;

		PROCEDURE HeapBlock(CONST moduleName, typeName: ARRAY OF CHAR; section: IntermediateCode.Section; dataAdrOffset: LONGINT);
		VAR offset: LONGINT; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol;
		BEGIN
			INC(dataAdrOffset,6);
			Info(section,"headerAdr");
			Address(section,0);
			Info(section,"typeDesc");

			symbol := implementationVisitor.GetTypeDescriptor(moduleName,typeName, name);
			offset := ToMemoryUnits(module.system,TypeRecordBaseOffset*module.system.addressSize);
			NamedSymbol(section, name, symbol, 0, offset);

			Info(section,"mark: LONGINT;");
			Longint(section,-1);
			Info(section,"dataAdr-: ADDRESS");
			Symbol(section,section, dataAdrOffset,0);
			Info(section,"size-: SIZE");
			Address(section,0);
			Info(section,"nextRealtime: HeapBlock;");
			Address(section,0);
		END HeapBlock;

		PROCEDURE ProtectedHeapBlock(CONST moduleName, typeName: ARRAY OF CHAR; section: IntermediateCode.Section; dataAdrOffset: LONGINT);
		VAR i: LONGINT;
		BEGIN
			INC(dataAdrOffset,14);
			HeapBlock(moduleName,typeName,section,dataAdrOffset);
			Info(section,"count*: LONGINT");
			Longint(section,0);
			Info(section,"locked*: BOOLEAN");
			Longint(section,0);
			Info(section,"awaitingLock*: ProcessQueue");
			Address(section,0);
			Address(section,0);
			Info(section,"awaitingCond*: ProcessQueue");
			Address(section,0);
			Address(section,0);
			Info(section,"lockedBy*: ANY");
			Address(section,0);
			Info(section,"lock*: ANY");
			Address(section,0);
			Info(section,"waitingPriorities*: ARRAY NumPriorities OF LONGINT");
			Longint(section,1);
			FOR i := 2 TO 6 DO
			Longint(section,0);
			END;
		END ProtectedHeapBlock;

		PROCEDURE Info(section: IntermediateCode.Section; CONST s: ARRAY OF CHAR);
		BEGIN
			IF section.comments # NIL THEN section.comments.String(s); section.comments.Ln; section.comments.Update END;
		END Info;

		PROCEDURE Address(section: IntermediateCode.Section; value: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.addressType),value);
			section.Emit(Data(-11,op));
		END Address;

		PROCEDURE Size(section: IntermediateCode.Section; value: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.sizeType),value);
			section.Emit(Data(-12,op));
		END Size;


		PROCEDURE Set(section: IntermediateCode.Section; value: SET);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.longintType),SYSTEM.VAL(LONGINT,value));
			section.Emit(Data(-1,op));
		END Set;

		PROCEDURE Longint(section: IntermediateCode.Section; value: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.longintType),value);
			section.Emit(Data(-1,op));
		END Longint;

		PROCEDURE PatchLongint(section: IntermediateCode.Section; pc: LONGINT; value: LONGINT);
		VAR op,noOperand: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitOperand(noOperand);
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.longintType),value);
			section.PatchOperands(pc,op,noOperand,noOperand);
		END PatchLongint;
		
		PROCEDURE PatchSymbol(section: IntermediateCode.Section; pc: LONGINT; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol; virtualOffset, realOffset: LONGINT);
		VAR op, noOperand: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitOperand(noOperand);
			IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system, module.system.addressType), name,implementationVisitor.GetFingerprint(symbol), virtualOffset);
			section.PatchOperands(pc,op,noOperand,noOperand);
		END PatchSymbol;

		PROCEDURE Boolean(section: IntermediateCode.Section; value: BOOLEAN);
		VAR op: IntermediateCode.Operand; intValue: LONGINT;
		BEGIN
			IF value = FALSE THEN intValue := 0 ELSE intValue :=1 END;
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.booleanType),intValue);
			section.Emit(Data(-1,op));
		END Boolean;

		PROCEDURE Char(section: IntermediateCode.Section; char: CHAR);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.characterType),ORD(char));
			section.Emit(Data(-1,op));
		END Char;

		PROCEDURE String(section: IntermediateCode.Section; CONST str: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			Info(section,str);
			i := 0;
			WHILE(str[i] # 0X) DO
				Char(section,str[i]);
				INC(i);
			END;
			Char(section,0X);
		END String;


		PROCEDURE NamedSymbol(section: IntermediateCode.Section; name: Basic.SegmentedName; symbol: SyntaxTree.Symbol; virtualOffset, realOffset: LONGINT);
		VAR op: IntermediateCode.Operand;
		BEGIN
			IntermediateCode.InitAddress(op, IntermediateCode.GetType(module.system, module.system.addressType), name,implementationVisitor.GetFingerprint(symbol), virtualOffset);
			IntermediateCode.SetOffset(op,realOffset);
			section.Emit(Data(-1,op));
		END NamedSymbol;


		PROCEDURE Symbol(section: IntermediateCode.Section; symbol: Sections.Section; virtualOffset, realOffset: LONGINT);
		BEGIN
			IF symbol= NIL THEN
				Address( section, realOffset);
				ASSERT(virtualOffset = 0);
			ELSE
				NamedSymbol(section, symbol.name, symbol.symbol, virtualOffset, realOffset)
			END;
		END Symbol;

		(* OutPointers delivers
			{pointerOffset}
		*)
		PROCEDURE Pointers(offset: LONGINT; symbol: Sections.Section; section: IntermediateCode.Section; type: SyntaxTree.Type; VAR numberPointers: LONGINT);
		VAR variable: SyntaxTree.Variable; i,n,size: LONGINT; base: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.AnyType THEN
				Symbol(section, symbol, 0, (offset ));
				INC(numberPointers);

				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
			ELSIF (type IS SyntaxTree.PortType) & implementationVisitor.backend.cellsAreObjects THEN
				Symbol(section, symbol, 0, offset); INC(numberPointers);
			ELSIF type IS SyntaxTree.PointerType THEN
				Symbol(section, symbol, 0, (offset )); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1);D.Ln;  END;
			ELSIF (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate) THEN
				Symbol(section, symbol, 0, (offset )+ToMemoryUnits(module.system,module.system.addressSize)); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset+ToMemoryUnits(module.system,module.system.addressSize),1); END;
			ELSIF (type IS SyntaxTree.RecordType) THEN
				(* never treat a record like a pointer, even if the pointer field is set! *)
				WITH type: SyntaxTree.RecordType DO
					base := type.GetBaseRecord();
					IF base  # NIL THEN
						Pointers(offset,symbol,section, base,numberPointers);
					END;
					variable := type.recordScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,variable.offsetInBits), symbol,  section, variable.type,numberPointers);
						END;
						variable := variable.nextVariable;
					END;
				END;
			ELSIF (type IS SyntaxTree.CellType) THEN
				WITH type: SyntaxTree.CellType DO
					base := type.GetBaseRecord();
					IF base  # NIL THEN
						Pointers(offset,symbol,section, base,numberPointers);
					END;
					variable := type.cellScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							Pointers(offset+ToMemoryUnits(module.system,variable.offsetInBits), symbol,  section, variable.type,numberPointers);
						END;
						variable := variable.nextVariable;
					END;
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form= SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.ArrayType) DO
							type := base(SyntaxTree.ArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := ToMemoryUnits(module.system,module.system.AlignedSizeOf(base));
						IF SemanticChecker.ContainsPointer(base) THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								Pointers(offset+i*size, symbol, section, base,numberPointers);
							END;
						END;
					ELSE
						Symbol( section, symbol, 0, (offset )); INC(numberPointers);
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END;
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.MathArrayType) DO
							type := base(SyntaxTree.MathArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := ToMemoryUnits(module.system,module.system.AlignedSizeOf(base));
						IF SemanticChecker.ContainsPointer(base) THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								Pointers(offset+i*size, symbol,   section, base,numberPointers);
							END;
						END;
					ELSE
						Symbol(section, symbol, 0, (offset )); INC(numberPointers); (* GC relevant pointer is at offset 0 *)
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END
				END;
			(* ELSE no pointers in type *)
			END;
		END Pointers;

		PROCEDURE EnterDynamicName(source: IntermediateCode.Section; CONST name: ARRAY OF CHAR; index: LONGINT; pool: Basic.HashTableInt): LONGINT;
		VAR position,i: LONGINT; ch: CHAR; 
		BEGIN
			IF pool.Has(index) THEN
				RETURN pool.GetInt(index)
			ELSE
				position := source.pc;
				pool.PutInt(index, position);
				Info(source, name);
				i := 0;
				REPEAT
					ch := name[i]; INC(i);
					Char( source, ch);
				UNTIL ch = 0X;
			END;
			RETURN position;
		END EnterDynamicName;

		PROCEDURE DynamicName(source: IntermediateCode.Section; index: StringPool.Index; pool: Basic.HashTableInt): LONGINT;
		VAR name: Basic.SectionName; position: LONGINT;
		BEGIN
			IF pool.Has(index) THEN
				RETURN pool.GetInt(index)
			ELSE
				StringPool.GetString(index, name);
				position := EnterDynamicName(source,name,index, pool); 
			END;
			RETURN position;
		END DynamicName;
				
		PROCEDURE Block(CONST mName, typeName, suffix: ARRAY OF CHAR; VAR offset: LONGINT): IntermediateCode.Section;
		VAR name: ARRAY 128 OF CHAR; section: IntermediateCode.Section; pooledName: Basic.SegmentedName;
		BEGIN
			COPY(moduleName,name);
			Strings.Append(name,suffix);
			Basic.ToSegmentedName(name, pooledName);
			section := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, pooledName, NIL,TRUE);
			
			IF implementationVisitor.backend.cooperative THEN
				Info(section, "TypeDescriptor");
				Basic.ToSegmentedName("BaseTypes.Array", pooledName);
				NamedSymbol(section, pooledName,NIL, 0, 0);
				BasePointer(section);
				offset := 0;
			ELSE
				HeapBlock(mName,typeName,section,2);
				Info(section, "HeapBlock");
				(*
				Symbol(section,section,2,0);
				*)
				Address(section,0); (* empty such that GC does not go on traversing *)
				Info(section, "TypeDescriptor");
				Address(section,0);
				offset := section.pc;
			END;
			RETURN section
		END Block;		

		PROCEDURE Array(source: IntermediateCode.Section; VAR sizePC: LONGINT; CONST baseType: ARRAY OF  CHAR);
		VAR name: Basic.SegmentedName;
		BEGIN
			Info(source,"ArrayHeader");
			IF implementationVisitor.backend.cooperative THEN
				sizePC := source.pc;
				Address(source,0);
				NamedSymbol(source,source.name,NIL,0,ToMemoryUnits(implementationVisitor.system,(BaseArrayTypeSize + 1)*implementationVisitor.addressType.sizeInBits));
				IF baseType # "" THEN
					Basic.ToSegmentedName(baseType, name);
					NamedSymbol(source, name,NIL, 0, 0);
				ELSE
					Address(source,0);
				END;
				Address(source,0);
			ELSE
				Address(source,0);
				Address(source,0);
				Address(source,0);
				sizePC := source.pc;
				Address(source,0);
				Info(source,"array data");
			END;
		END Array;

		PROCEDURE PatchArray(section: IntermediateCode.Section; pc: LONGINT; size: LONGINT);
		BEGIN
			IF implementationVisitor.backend.cooperative THEN
				PatchLongint(section, pc, size);
				PatchLongint(section, pc + 3, size);
			ELSE
				PatchLongint(section, pc, size);
			END;
		END PatchArray;

		PROCEDURE ExportDesc(source: IntermediateCode.Section);
		VAR
			i: LONGINT; section: Sections.Section; fingerPrinter : FingerPrinter.FingerPrinter;
			sectionArray: POINTER TO ARRAY OF Sections.Section;
			poolMap: Basic.HashTableInt;
			namePool: IntermediateCode.Section;
			namePoolOffset: LONGINT;
			
			PROCEDURE Compare(VAR s1, s2: Sections.Section): BOOLEAN;
			VAR n1, n2: Basic.SectionName; index: LONGINT; ch1, ch2: CHAR;
			BEGIN
				Basic.SegmentedNameToString(s1.name,n1);
				Basic.SegmentedNameToString(s2.name,n2);
				index := 0; 
				ch1 := n1[index];
				ch2 := n2[index];
				WHILE (ch1 # 0X) & (ch1 = ch2)  DO
					INC(index);
					ch1 := n1[index];
					ch2 := n2[index];
				END;
				RETURN ch1 < ch2;
			END Compare;
			
			PROCEDURE QuickSort(VAR list: ARRAY OF Sections.Section;  lo, hi: LONGINT);
			VAR
				i, j: LONGINT;
				x, t: Sections.Section;
			BEGIN
				IF lo < hi THEN
					i := lo; j := hi; x:= list[(lo+hi) DIV 2];

					WHILE i <= j DO
						WHILE Compare(list[i], x) DO INC(i) END;
						WHILE Compare(x, list[j]) DO DEC(j) END;

						IF i <= j THEN
							t := list[i]; list[i] := list[j]; list[j] := t; (* swap i and j *)
							INC(i); DEC(j)
						END
					END;

					IF lo < j THEN QuickSort(list, lo, j) END;
					IF i < hi THEN QuickSort(list, i, hi) END
				END;
			END QuickSort;
		
	(*
	ExportDesc* = RECORD
		fp*: ADDRESS;
		name* {UNTRACED}: DynamicName;
		adr*: ADDRESS;
		exports*: LONGINT;
		dsc* {UNTRACED}: ExportArray
	END;
	ExportArray* = POINTER {UNSAFE} TO ARRAY OF ExportDesc;
	*)
	
		PROCEDURE ExportDesc2(
			source: IntermediateCode.Section; 
			namePool: IntermediateCode.Section;
			fingerPrinter: FingerPrinter.FingerPrinter;
			symbol: Sections.Section;
			name: StringPool.Index;
			VAR patchAdr: LONGINT
			): BOOLEAN;
		VAR fingerPrint: SyntaxTree.FingerPrint; 
		BEGIN
			(*IF  (implementationVisitor.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection)
				& (symbol.type # Sections.InlineCodeSection)
			THEN
			*)
			IF (symbol = NIL) OR ( (implementationVisitor.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection)
				& (symbol.type # Sections.InlineCodeSection))
			THEN

				IF (symbol = NIL) OR (symbol # NIL) & (symbol.type # Sections.InlineCodeSection) THEN
					IF (symbol # NIL) & (symbol.symbol # NIL) THEN 
						fingerPrint := fingerPrinter.SymbolFP(symbol.symbol);
						Longint(source,fingerPrint.shallow);
					ELSE
						Longint(source, 0);
					END;
					
					Symbol(source, namePool, DynamicName(namePool, name, poolMap), 0); (* reference to dynamic name *)
					Symbol(source, symbol,0,0);
					patchAdr := source.pc;
					Address(source,0);
					Address(source,0);
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END ExportDesc2;
		
		
			
			PROCEDURE Export(CONST sections: ARRAY OF Sections.Section);
			VAR level, olevel, s: LONGINT; prev, this: Basic.SegmentedName; name: ARRAY 256 OF CHAR;
				scopes: ARRAY LEN(prev)+1 OF Scope; arrayName: ARRAY 32 OF CHAR;
				sym: Sections.Section; ignore: LONGINT; symbol: Sections.Section;
			TYPE
				Scope = RECORD
					elements: LONGINT;
					gelements: LONGINT;
					section: IntermediateCode.Section;
					patchAdr: LONGINT;
					arraySizePC: LONGINT;
					beginPC: LONGINT; (* current scope start pc *)
				END;
			BEGIN
				Basic.InitSegmentedName(prev);
				olevel := -1;
				scopes[0].section := source;

				FOR s := 0 TO LEN(sections)-1 DO
					symbol := sections[s];
					IF (symbol # NIL) & (implementationVisitor.backend.cooperative) & (symbol.symbol = NIL) OR (symbol.symbol # NIL) & (symbol.type # Sections.InitCodeSection) & (symbol.type # Sections.InlineCodeSection) THEN
						this := sections[s].name;
						level := 0;
						WHILE  (this[level] > 0) DO
							WHILE  (this[level] > 0) & (prev[level] = this[level]) DO
								INC(level);
							END;
							WHILE level < olevel DO 
								(*TRACE("closing",olevel,scopes[olevel].elements); *)
								IF olevel > 0 THEN
									PatchLongint(scopes[olevel-1].section,scopes[olevel-1].patchAdr, scopes[olevel].elements);
									PatchSymbol(scopes[olevel-1].section,scopes[olevel-1].patchAdr+1, scopes[olevel].section.name,  scopes[olevel].section.symbol, scopes[olevel].beginPC, 0);
								END;
								scopes[olevel].gelements := scopes[olevel].gelements + scopes[olevel].elements;
								DEC(olevel); 
							END;
							IF (this[level] > 0) THEN
								IF level > olevel THEN 
									(*TRACE("opening",level); *)
									IF scopes[level].section = NIL THEN
										arrayName := ".@ExportArray";
										Strings.AppendInt(arrayName, level);
										scopes[level].section := Block("Heaps","SystemBlockDesc",arrayName,ignore);
										Array(scopes[level].section,scopes[level].arraySizePC,"Modules.ExportDesc");
									END;
									scopes[level].beginPC := scopes[level].section.pc;
									
									olevel := level;
									scopes[olevel].elements := 0;
								END;
								IF (level = LEN(this)-1) OR (this[level+1] <= 0) THEN
									sym := sections[s];
								ELSE
									sym := NIL;
								END;
								IF ExportDesc2(scopes[level].section, namePool, fingerPrinter, sym, this[level], scopes[level].patchAdr)
								THEN
									INC(scopes[olevel].elements);
								END;
								(*StringPool.GetString(this[level], name);*)
								(*TRACE(level, name);*)
								(* enter string in scope *)
								INC(level);
							END;
						END;
						Basic.SegmentedNameToString(this, name);
						(*TRACE(level, "enter", name);*)
						prev := this;
					END;
				END;
				WHILE 0 <= olevel DO 
					(*TRACE("closing",olevel,scopes[olevel].elements); *)
					IF olevel > 0 THEN
						PatchLongint(scopes[olevel-1].section,scopes[olevel-1].patchAdr, scopes[olevel].elements);
						PatchSymbol(scopes[olevel-1].section,scopes[olevel-1].patchAdr+1, scopes[olevel].section.name,  scopes[olevel].section.symbol, scopes[olevel].beginPC, 0);
					END;
					scopes[olevel].gelements := scopes[olevel].gelements + scopes[olevel].elements;
					DEC(olevel); 
				END;
				
				level := 0;
				WHILE (level < LEN(scopes)) DO
					IF scopes[level].section # NIL THEN
						PatchArray(scopes[level].section, scopes[level].arraySizePC, scopes[level].gelements);
					END;
					INC(level);
				END;
				
			END Export;
			
		BEGIN
			NEW(fingerPrinter, module.system);
			NEW(poolMap, 64);
			(* this is the name pool private to the export table -- it is sorted and should not be mixed / used for other names in a module *)
			namePool := Block("Heaps","SystemBlockDesc",".@NamePool",namePoolOffset); 
			
			NEW(sectionArray, module.allSections.Length());
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				sectionArray[i] := section;
			END;
			QuickSort(sectionArray^,0,module.allSections.Length()-1);
			
			Export(sectionArray^);
		END ExportDesc;


		PROCEDURE ExceptionArray(source: IntermediateCode.Section);
		VAR
			p: Sections.Section; finallyPC, sizePC, size, i: LONGINT;
		BEGIN
			Info(source, "exception table offsets array descriptor");
			size := 0;
			Array(source,sizePC,"Modules.ExceptionTableEntry");
			Info(source, "exception table content");
			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				IF p.type = Sections.CodeSection THEN
					finallyPC := p(IntermediateCode.Section).finally;
					IF finallyPC>=0 THEN
						Symbol( source, p, 0,0);
						Symbol( source, p,  finallyPC, 0);
						Symbol( source, p, finallyPC,0);
						INC(size);
					END;
				END
			END;
			PatchArray(source,sizePC,size);
			END ExceptionArray;

			PROCEDURE Name(section: IntermediateCode.Section; CONST name: ARRAY OF CHAR);
			VAR i: LONGINT; ch: CHAR;
			BEGIN
				i := 0;
				REPEAT
					ch := name[i]; INC(i);
					Char( section, ch);
				UNTIL ch = 0X;
				WHILE i < 32 DO
					Char( section, 0X); INC(i);
				END;
			END Name;



			PROCEDURE References(section: IntermediateCode.Section);
			CONST
				rfDirect = 1X; rfIndirect = 3X;
				rfStaticArray= 12X; rfDynamicArray=14X; rfOpenArray=15X;
				rfByte = 1X; rfBoolean = 2X; rfChar8=3X; rfShortint=04X; rfInteger = 05X; rfLongint = 06X;
				rfReal = 07X; rfLongreal = 08X; rfSet = 09X; rfDelegate = 0EX;  rfString = 0FH; rfPointer = 0DX; rfHugeint = 10X;
				rfChar16=11X; rfChar32=12X; rfAll=13X; rfSame=14X; rfRange=15X; rfRecord=16X; rfComplex = 17X; rfLongcomplex = 18X; 
				rfRecordPointer=1DX;
				rfArrayFlag = 80X;

			VAR
				s: Sections.Section; sizePC, i, startPC, endPC: LONGINT;

				PROCEDURE BaseType(type: SyntaxTree.Type): CHAR;
				VAR char: CHAR;
				BEGIN
					IF type = NIL THEN char := rfLongint
					ELSIF type  IS SyntaxTree.ByteType THEN char := rfByte
					ELSIF type IS SyntaxTree.BooleanType THEN char := rfBoolean
					ELSIF type IS SyntaxTree.CharacterType THEN
						IF type.sizeInBits = 8 THEN char := rfChar8
						ELSIF type.sizeInBits = 16 THEN char := rfChar16
						ELSIF type.sizeInBits = 32 THEN char := rfChar32
						END;
					ELSIF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType) THEN
						IF type.sizeInBits = 8 THEN char := rfShortint
						ELSIF type.sizeInBits = 16 THEN char := rfInteger
						ELSIF type.sizeInBits = 32 THEN char := rfLongint
						ELSIF type.sizeInBits = 64 THEN char := rfHugeint
						END;
					ELSIF type IS SyntaxTree.SizeType THEN char := rfLongint
					ELSIF type IS SyntaxTree.FloatType THEN
						IF type.sizeInBits = 32 THEN char := rfReal
						ELSIF type.sizeInBits = 64 THEN  char := rfLongreal
						END;
					ELSIF type IS SyntaxTree.ComplexType THEN
						IF type.sizeInBits = 64 THEN char := rfComplex
						ELSIF type.sizeInBits = 128 THEN char := rfLongcomplex
						END;
					ELSIF type IS SyntaxTree.SetType THEN char := rfSet
					ELSIF type IS SyntaxTree.AnyType THEN char := rfPointer
					ELSIF type IS SyntaxTree.ObjectType THEN char := rfPointer
					ELSIF type IS SyntaxTree.PointerType THEN char := rfPointer
					ELSIF type IS SyntaxTree.ProcedureType THEN char := rfDelegate
					ELSIF type IS SyntaxTree.RangeType THEN char := rfRange
					ELSE (*ASSERT(arrayOf);*) char := rfPointer; (*RETURN (* ARRAY OF unknown (record): do not write anything *)*)
					END;
					RETURN char
				END BaseType;

				PROCEDURE RecordType(type: SyntaxTree.RecordType);
				VAR destination: Sections.Section; 
				BEGIN
					destination := module.allSections.FindBySymbol(type.typeDeclaration); (*TODO*)
					IF type.pointerType # NIL THEN
						Char(section,rfRecordPointer)
					ELSE
						Char(section,rfRecord);
					END;
					IF destination = NIL THEN
						Longint(section,0);
					ELSE
						Longint(section,destination.offset); (* used for ? *)
					END;
				END RecordType;
				
				PROCEDURE StaticArrayLength(type: SyntaxTree.ArrayType; VAR baseType: SyntaxTree.Type): LONGINT;
				BEGIN
					baseType := type.arrayBase.resolved;
					IF type.form = SyntaxTree.Static THEN
						IF baseType IS SyntaxTree.ArrayType THEN
							RETURN type.staticLength * StaticArrayLength(baseType(SyntaxTree.ArrayType),baseType)
						ELSE
							RETURN type.staticLength
						END
					ELSE
						RETURN 0
					END;
				END StaticArrayLength;
				
				PROCEDURE ArrayType(type: SyntaxTree.ArrayType);
				VAR length: LONGINT; baseType: SyntaxTree.Type; char: CHAR;
				BEGIN
					length := StaticArrayLength(type, baseType);
					char := BaseType(baseType);
					IF type.form # SyntaxTree.Open THEN
						Char(section,CHR(ORD(char)+ORD(rfArrayFlag)));
						Longint(section, length)
					ELSE
						length :=0;
						(*length := 1+SemanticChecker.Dimension(type,{SyntaxTree.Open});*)
						Char(section, CHR(ORD(char)+ORD(rfArrayFlag)));
						Longint(section, length)
					END;
				END ArrayType;
				
				PROCEDURE StaticMathArrayLength(type: SyntaxTree.MathArrayType; VAR baseType: SyntaxTree.Type): LONGINT;
				BEGIN
					baseType := type.arrayBase;
					IF baseType # NIL THEN
						baseType := baseType.resolved;
					END;
					IF type.form = SyntaxTree.Static THEN
						IF (baseType # NIL) & (baseType IS SyntaxTree.MathArrayType) THEN
							RETURN type.staticLength * StaticMathArrayLength(baseType(SyntaxTree.MathArrayType),baseType)
						ELSE
							RETURN type.staticLength
						END
					ELSE
						RETURN 0
					END;
				END StaticMathArrayLength;

				PROCEDURE MathArrayType(type: SyntaxTree.MathArrayType);
				VAR length: LONGINT; baseType: SyntaxTree.Type; char: CHAR;
				BEGIN
					length := StaticMathArrayLength(type, baseType);
					char :=  BaseType(baseType);
					IF type.form = SyntaxTree.Open THEN
						char := BaseType(module.system.addressType);
						length := 5+2*SemanticChecker.Dimension(type,{SyntaxTree.Open});
						Char(section, CHR(ORD(char)+ORD(rfArrayFlag)));
						Longint(section, length)
					ELSIF type.form=SyntaxTree.Tensor THEN
						char := BaseType(module.system.addressType);
						Char(section, CHR(ORD(char)));
					ELSE
						Char(section, CHR(ORD(char)+ORD(rfArrayFlag)));
						Longint(section, length)
					END;
				END MathArrayType;

				PROCEDURE Type(type: SyntaxTree.Type);
				BEGIN
					IF type = NIL THEN Char(section,0X); RETURN ELSE type := type.resolved END;

					IF type IS SyntaxTree.BasicType THEN
						Char(section, BaseType(type));
					ELSIF type IS SyntaxTree.RecordType THEN
						RecordType(type(SyntaxTree.RecordType));
					ELSIF type IS SyntaxTree.ArrayType THEN
						ArrayType(type(SyntaxTree.ArrayType))
					ELSIF type IS SyntaxTree.EnumerationType THEN
						Char(section, BaseType(module.system.longintType))
					ELSIF type IS SyntaxTree.PointerType THEN
						IF type(SyntaxTree.PointerType).pointerBase IS SyntaxTree.RecordType THEN
							RecordType(type(SyntaxTree.PointerType).pointerBase(SyntaxTree.RecordType));
						ELSE
							Char(section, BaseType(type))
						END;
					ELSIF type IS SyntaxTree.ProcedureType THEN
						Char(section, BaseType(type));
					ELSIF type IS SyntaxTree.MathArrayType THEN
						MathArrayType(type(SyntaxTree.MathArrayType));
					ELSIF type IS SyntaxTree.CellType THEN
						Char(section, BaseType(module.system.anyType));
					ELSE HALT(200)
					END;
				END Type;

				PROCEDURE WriteVariable(variable: SyntaxTree.Variable; indirect: BOOLEAN);
					VAR name: ARRAY 256 OF CHAR;
				BEGIN
					IF variable.externalName # NIL THEN RETURN END;
					IF indirect THEN Char(section,rfIndirect) ELSE Char(section,rfDirect) END;
					variable.GetName(name);
					Type(variable.type);
					Longint(section,ToMemoryUnits(module.system,variable.offsetInBits));
					String(section,name);
				END WriteVariable;

				PROCEDURE WriteParameter(variable: SyntaxTree.Parameter; indirect: BOOLEAN);
				VAR name: ARRAY 256 OF CHAR;
				BEGIN
					IF indirect THEN Char(section,rfIndirect) ELSE Char(section,rfDirect) END;
					variable.GetName(name);
					Type(variable.type);
					Longint(section,ToMemoryUnits(module.system,variable.offsetInBits));
					variable.GetName(name);
					String(section,name);
				END WriteParameter;

				PROCEDURE ReturnType(type: SyntaxTree.Type);
				BEGIN
					IF type = NIL THEN Char(section,0X); RETURN ELSE type := type.resolved END;

					IF type IS SyntaxTree.ArrayType THEN
						WITH type: SyntaxTree.ArrayType DO
							IF type.form = SyntaxTree.Static THEN Char(section,rfStaticArray)
							ELSE Char(section,rfOpenArray)
							END;
						END
					ELSIF type IS SyntaxTree.MathArrayType THEN
						WITH type: SyntaxTree.MathArrayType DO
							IF type.form = SyntaxTree.Static THEN Char(section,rfStaticArray)
							ELSE Char(section,rfOpenArray)
							END;
						END
					ELSIF type IS SyntaxTree.RecordType THEN
						Char(section,rfRecord);
					ELSE
						Char(section, BaseType(type));
					END;
				END ReturnType;

				PROCEDURE Procedure(s: Sections.Section);
				VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
					 parameter: SyntaxTree.Parameter; variable: SyntaxTree.Variable;
					 name: ARRAY 256 OF CHAR;
				BEGIN
					procedure := s.symbol(SyntaxTree.Procedure); (*! check for variable or type symbol for object body *)
				(*procedure.name,name);*)
				Global.GetSymbolNameInScope(procedure,module.module.moduleScope,name);

					procedureType := procedure.type(SyntaxTree.ProcedureType);

					Char(section,0F9X);
					Symbol(section,s,0,0);
					Symbol(section,s,s(IntermediateCode.Section).pc,0);
					Longint(section,procedureType.numberParameters);
					ReturnType(procedureType.returnType);
					Longint(section,0); (*! level *)
					Longint(section,0);
					(*
					IF procedure.scope IS SyntaxTree.RecordScope THEN (* add object name *)
						record := procedure.scope(SyntaxTree.RecordScope).ownerRecord;
						recordName := "";
						IF record.pointerType # NIL THEN
							DeclarationName(record.pointerType.typeDeclaration,recordName);
						ELSE
							DeclarationName(record.typeDeclaration,recordName);
						END;
						i := 0;
						Info(section,recordName);
						WHILE recordName[i] # 0X DO
							Char(section,recordName[i]); INC(i);
							INC(size);
						END;
						Char(section,".");
						INC(size);
					END;
					*)
					String(section,name);
					parameter := procedureType.firstParameter;
					WHILE(parameter # NIL) DO
						WriteParameter(parameter,parameter.kind # SyntaxTree.ValueParameter); (*!treat  exceptions !*)
						parameter := parameter.nextParameter;
					END;
					variable := procedure.procedureScope.firstVariable;
					WHILE(variable # NIL) DO
						WriteVariable(variable,FALSE);
						variable := variable.nextVariable;
					END;
				END Procedure;

				PROCEDURE Scope(s: Sections.Section);
				BEGIN
					Char(section,0F8X);
					Symbol(section,s,0,0); (* start *)
					Symbol(section,s,s(IntermediateCode.Section).pc,0); (* end *)
					String(section,"$$");
					(* removed variables -- wrongly interpreted by Reflection
					variable := module.module.moduleScope.firstVariable;
					WHILE(variable # NIL) DO
						WriteVariable(variable,FALSE);
						variable := variable.nextVariable;
					END;
					*)
				END Scope;

				PROCEDURE ComputeSize(startPC, endPC: LONGINT): SIZE;
				VAR result, i: LONGINT;
				BEGIN
					FOR i := startPC TO endPC -1 DO
						ASSERT (section.instructions[i].opcode = IntermediateCode.data);
						INC(result, ToMemoryUnits(module.system, section.instructions[i].op1.type.sizeInBits));
					END;
					RETURN result;
				END ComputeSize;
				

			BEGIN
				Array(section,sizePC,"");
				
				startPC := section.pc;
				Char(section,0FFX); (* sign for trap writer *)

				FOR i := 0 TO module.allSections.Length() - 1 DO
					s := module.allSections.GetSection(i);
					IF (s.type # Sections.InitCodeSection) & (s.symbol = module.module.moduleScope.bodyProcedure) THEN
						Scope(s) (*! must be first procedure in ref section *)
					END
				END;

				FOR i := 0 TO module.allSections.Length() - 1 DO
					s := module.allSections.GetSection(i);
					IF (s.symbol = module.module.moduleScope.bodyProcedure) THEN (* already done, see above *)
					ELSIF (s.type # Sections.InitCodeSection) & (s.symbol # NIL) & (s.symbol IS SyntaxTree.Procedure) & ~s.symbol(SyntaxTree.Procedure).isInline THEN
						Procedure(s)
					END
				END;
				
				endPC := section.pc;
				PatchArray(section,sizePC,ComputeSize(startPC, endPC));

			END References;
			
		(*
		Command* = RECORD
			(* Fields exported for initialization by loader/linker only! Consider read-only! *)
			name*: Name; (* name of the procedure *)
			argTdAdr*, retTdAdr* : ADDRESS; (* address of type descriptors of argument and return type, 0 if no type *)
			entryAdr* : ADDRESS; (* entry address of procedure *)
		END;
		*)
		PROCEDURE CommandArray(source: IntermediateCode.Section);
		VAR
			p: Sections.Section;  sizePC, numberCommands: LONGINT;
			procedure : SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
			name: SyntaxTree.IdentifierString; numberParameters, i: LONGINT;

				(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
				PROCEDURE GetProcedureAllowed() : BOOLEAN;

					PROCEDURE TypeAllowed(type : SyntaxTree.Type) : BOOLEAN;
					BEGIN
						RETURN
							(type = NIL) OR
							(type.resolved IS SyntaxTree.RecordType) OR
							(type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) OR
							(type.resolved IS SyntaxTree.AnyType);
				END TypeAllowed;

				BEGIN
					numberParameters := procedureType.numberParameters;
					RETURN
						(numberParameters = 0) & TypeAllowed(procedureType.returnType) OR
						(numberParameters = 1) & TypeAllowed(procedureType.firstParameter.type) & TypeAllowed(procedureType.returnType) OR
						(numberParameters = 1) & (procedureType.firstParameter.type.resolved IS SyntaxTree.AnyType) & (procedureType.returnType # NIL) & (procedureType.returnType.resolved IS SyntaxTree.AnyType);
				END GetProcedureAllowed;

				PROCEDURE WriteType(type : SyntaxTree.Type);
				VAR typeDeclaration: SyntaxTree.TypeDeclaration; section: Sections.Section;
					name: Basic.SegmentedName; offset: LONGINT;
				BEGIN
					IF type = NIL THEN
						Address(source,0);
					ELSIF (type.resolved IS SyntaxTree.AnyType) OR (type.resolved IS SyntaxTree.ObjectType) THEN
						Address(source,1);
					ELSE
						type := type.resolved;
						IF type IS SyntaxTree.PointerType THEN
							type := type(SyntaxTree.PointerType).pointerBase.resolved;
						END;
						typeDeclaration := type.typeDeclaration; (* must be non-nil *)
						IF (typeDeclaration.scope = NIL) OR (typeDeclaration.scope.ownerModule = module.module) THEN
							name[0] := typeDeclaration.name; name[1] := -1;
							section := module.allSections.FindBySymbol(type.typeDeclaration); (*TODO*)
							ASSERT(section # NIL);
						ELSE
							Global.GetSymbolSegmentedName(typeDeclaration,name);
							(* TODO *)
							section := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,typeDeclaration, source.comments # NIL);
						END;
						IF implementationVisitor.backend.cooperative THEN
							offset := 0;
						ELSE
							offset := 1 + type(SyntaxTree.RecordType).recordScope.numberMethods+16+1;
						END;
						Symbol(source,section, 0, ToMemoryUnits(module.system,offset*module.system.addressSize));
					END;
				END WriteType;

		BEGIN
			Info(source, "command array descriptor");
			Array(source,sizePC,"Modules.Command");
			numberCommands := 0;
			Info(source, "command array content");

			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				IF (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure)  THEN
					procedure := p.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					IF (SyntaxTree.PublicWrite IN procedure.access) & ~(procedure.isInline) & ~(procedureType.isDelegate) & GetProcedureAllowed() THEN
						procedure.GetName(name);
						Name(source,name);
						numberParameters := procedureType.numberParameters;
						(* offset of type of first parameter *)
						IF (numberParameters = 0 ) THEN WriteType(NIL)
						ELSE WriteType(procedureType.firstParameter.type)
						END;
						(* offset of type of return parameter *)
						WriteType(procedureType.returnType);
						(* command name *)
						(* command code offset *)
						Symbol(source,p,0,0);
						INC(numberCommands);
						IF Trace THEN
							D.Ln;
						END;
					END;
				END
			END;
			PatchArray(source,sizePC,numberCommands);
		END CommandArray;

		(* to prevent from double import of different module aliases *)
		PROCEDURE IsFirstDirectOccurence(import: SyntaxTree.Import): BOOLEAN; (*! inefficient *)
		VAR i: SyntaxTree.Import;
		BEGIN
			i := module.module.moduleScope.firstImport;
			WHILE (i # NIL) & ((i.module # import.module) OR ~i.direct) DO
				i := i.nextImport;
			END;
			RETURN i = import
		END IsFirstDirectOccurence;

		PROCEDURE ImportsArray(source: IntermediateCode.Section);
		VAR import: SyntaxTree.Import ; pc: LONGINT;name: Basic.SegmentedName; numberImports: LONGINT; offset: LONGINT;
		BEGIN
			Array(source,pc,"");
			Info(source, "import module array data");
			IF implementationVisitor.backend.cooperative THEN
				offset := 0;
			ELSE
				offset := ToMemoryUnits(module.system, 22* module.system.addressSize) (* Module pointer offset -- cf. ModuleSection(), how to encode generically correct? *);
			END;
			import :=  module.module.moduleScope.firstImport;
			numberImports := 0;
			WHILE import # NIL DO
				IF import.direct & ~Global.IsSystemModule(import.module) & IsFirstDirectOccurence(import) THEN
					Global.GetModuleSegmentedName(import.module,name);
					Basic.SuffixSegmentedName(name, StringPool.GetIndex1("@Module"));
					NamedSymbol(source, name, NIL, 0, offset);
					INC(numberImports);
				END;
				import := import.nextImport
			END;
			PatchArray(source,pc,numberImports);
		END ImportsArray;

		PROCEDURE TypeInfoSection(source: IntermediateCode.Section);
		VAR
			p: Sections.Section; sizePC, size, i: LONGINT;
		BEGIN
			Info(source, "Type info section");
			size := 0;
			Array(source,sizePC,"Modules.TypeDesc");
			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				WITH p: IntermediateCode.Section DO
					IF Basic.SegmentedNameEndsWith(p.name,"@Info") THEN
						Symbol(source,p,0,0);
						INC(size);
					END;
				END
			END;
			PatchArray(source,sizePC,size);
		END TypeInfoSection;

		(*
			ProcTableEntry* = RECORD
				pcFrom*, pcLimit*, pcStatementBegin*, pcStatementEnd*: ADDRESS;
				noPtr*: LONGINT;
			END;

			ProcTable* = POINTER TO ARRAY OF ProcTableEntry;

			PtrTable* = POINTER TO ARRAY OF ADDRESS;
		*)

		PROCEDURE PointersInProcTables(procArray, pointerArray: IntermediateCode.Section; VAR procArraySize, maxPointers: LONGINT);
		VAR
			destination: Sections.Section;
			pointerArraySizePC, procArraySizePC, pointerArraySize, i: LONGINT;

			PROCEDURE PointerOffsets(destination : IntermediateCode.Section);
			VAR numberPointers: LONGINT; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
				variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter; string: Basic.SectionName;
			BEGIN
				Info(procArray,"pcFrom");
				Symbol(procArray,destination,0,0);
				Info(procArray,"pcTo");
				Symbol(procArray,destination,destination.pc,0);
				Info(procArray,"pcStatementBegin");
				Symbol(procArray,destination,destination.validPAFEnter,0);
				Info(procArray,"pcStatementEnd");
				Symbol(procArray,destination,destination.validPAFExit,0);
				IF ~implementationVisitor.backend.cooperative THEN 
					Basic.SegmentedNameToString(destination.name, string);
					Info(pointerArray,string);
					procedure := destination.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					variable := procedure.procedureScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							Pointers(ToMemoryUnits(module.system,variable.offsetInBits), NIL,  pointerArray, variable.type, numberPointers);
						END;
						variable := variable.nextVariable
					END;
					parameter := procedureType.firstParameter;
					WHILE(parameter # NIL) DO
						IF ~(parameter.untraced) THEN
							Pointers(ToMemoryUnits(module.system,parameter.offsetInBits), NIL,  pointerArray, parameter.type, numberPointers);
						END;
						parameter := parameter.nextParameter;
					END;
				END;
				Info(procArray,"numberPointers");
				Longint(procArray,numberPointers);
				IF numberPointers > maxPointers THEN maxPointers := numberPointers END;
				INC(pointerArraySize, numberPointers);
			END PointerOffsets;

		BEGIN
			maxPointers := 0;
			Info(procArray, "proc array descriptor");
			Address(procArray,0);
			Address(procArray,0);
			Address(procArray,0);
			procArraySizePC := procArray.pc;
			Address(procArray,0);
			procArraySize := 0;
			IF ~implementationVisitor.backend.cooperative THEN
				Info(pointerArray, "pointer array descriptor");
				Address(pointerArray,0);
				Address(pointerArray,0);
				Address(pointerArray,0);
				pointerArraySizePC := pointerArray.pc;
				Address(pointerArray,0);
				pointerArraySize := 0;
			END;
			procArraySize := 0;
			FOR i := 0 TO module.allSections.Length() - 1 DO
				destination := module.allSections.GetSection(i);
				IF (destination.type IN {Sections.CodeSection, Sections.BodyCodeSection}) & (destination.symbol # NIL) & (destination.symbol IS SyntaxTree.Procedure) & ~destination.symbol(SyntaxTree.Procedure).isInline THEN
					PointerOffsets(destination(IntermediateCode.Section));
					INC(procArraySize);
				END
			END;

			PatchLongint(procArray,procArraySizePC,procArraySize);
			IF ~implementationVisitor.backend.cooperative THEN
				PatchLongint(pointerArray,pointerArraySizePC,pointerArraySize);
			END;
		END PointersInProcTables;

		(*
			Module* = OBJECT (Heaps.RootObject)	(* cf. Linker0 & Heaps.WriteType *)
			VAR
				next*: Module;	(** once a module is published, all fields are read-only *)
				name*: Name;
				init, published: BOOLEAN;
				refcnt*: LONGINT; (* counts loaded modules that import this module *)
				sb*: ADDRESS; <- set to beginning of data section by loader
				entry*: POINTER TO ARRAY OF ADDRESS; <- not needed in new loader
				command*: POINTER TO ARRAY OF Command;
				ptrAdr*: POINTER TO ARRAY OF ADDRESS;
				typeInfo*: POINTER TO ARRAY OF TypeDesc;
				module*: POINTER TO ARRAY OF Module; <---- currently done by loader
				procTable*: ProcTable; (* information inserted by loader, removed after use in Publish *)
				ptrTable*: PtrTable;  (* information inserted by loader, removed after use in Publish *)
				data*, code*: Bytes;
				staticTypeDescs* (* ug *), refs*: Bytes; <- staticTypeDescs in data section, refs currently unsupported
				export*: ExportDesc;
				term*: TerminationHandler;
				exTable*: ExceptionTable;
				noProcs*: LONGINT;
				firstProc*: ADDRESS; <-   done by loader
				maxPtrs*: LONGINT;
				crc*: LONGINT;
		*)

		PROCEDURE BasePointer (section: IntermediateCode.Section);
		BEGIN
			Info(section, "cycle");
			Size(section,0);
			Info(section, "references");
			Size(section,0);
			Info(section, "nextMarked");
			Address(section,0);
			Info(section, "nextWatched");
			Address(section,0);
		END BasePointer;

		PROCEDURE BaseObject (section: IntermediateCode.Section);
		BEGIN
			BasePointer(section);
			Info(section, "action");
			Address(section,0);
			Info(section, "monitor");
			Address(section,0);
		END BaseObject;
		
		PROCEDURE ModuleDescriptor(section: IntermediateCode.Section);
		VAR descriptorSection: IntermediateCode.Section; name: ARRAY 128 OF CHAR;
			pooledName: Basic.SegmentedName;
			symbol: SyntaxTree.Symbol;
		BEGIN
			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Module.@Descriptor");
			Basic.ToSegmentedName(name, pooledName);
			descriptorSection := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, pooledName,NIL,TRUE);
			Symbol(section,descriptorSection,0,0);
			
			Info(descriptorSection, "descriptor");
			symbol := implementationVisitor.GetTypeDescriptor("Modules","Module", pooledName);
			NamedSymbol(descriptorSection, pooledName,symbol, 0, 0);
			Address(descriptorSection,0);

			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Trace");
			Basic.ToSegmentedName(name, pooledName);
			NamedSymbol(descriptorSection, pooledName,NIL, 0, 0);
			
			Basic.ToSegmentedName ("BaseTypes.Object.Finalize",pooledName);
			NamedSymbol(descriptorSection, pooledName,NIL, 0, 0);
		END ModuleDescriptor;

		PROCEDURE ModuleSection(): IntermediateCode.Section;
		VAR name: ARRAY 128 OF CHAR;
			moduleSection: IntermediateCode.Section; offset: LONGINT; pooledName: Basic.SegmentedName;
			symbol: SyntaxTree.Symbol;
		BEGIN
			Global.GetModuleName(module.module,name);
			Strings.Append(name,".@Module");
			Basic.ToSegmentedName(name, pooledName);
			moduleSection := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, pooledName,NIL,TRUE);
			moduleSection.SetExported(TRUE);
			IF moduleSection.pc = 0 THEN
				IF implementationVisitor.backend.cooperative THEN
					Info(moduleSection, "descriptor");
					ModuleDescriptor(moduleSection);
					BaseObject(moduleSection);
					implementationVisitor.CreateTraceModuleMethod(module.module);
				ELSE
					ProtectedHeapBlock("Heaps","ProtRecBlockDesc",moduleSection,2);
					Info(moduleSection, "HeapBlock");
					Symbol(moduleSection,moduleSection,2,0);
					Info(moduleSection, "TypeDescriptor");
					symbol := implementationVisitor.GetTypeDescriptor("Modules","Module", pooledName);
					offset := ToMemoryUnits(module.system,(TypeRecordBaseOffset + 1 (*= numberMethods*))*module.system.addressSize);
					NamedSymbol(moduleSection, pooledName,symbol, 0, offset);
				END;
			END;
			RETURN moduleSection;
		END ModuleSection;
		

			
		PROCEDURE Module(bodyProc: IntermediateCode.Section);
		VAR
		moduleSection, pointerSection, importSection, emptyArraySection, exceptionSection, commandsSection,
			typeInfoSection, procTableSection, ptrTableSection, referenceSection : IntermediateCode.Section;
			emptyArraySectionOffset, pointerSectionOffset, importSectionOffset, numberPointers,
			exceptionSectionOffset, commandsSectionOffset, typeInfoSectionOffset, procTableSectionOffset, ptrTableSectionOffset, maxPointers, numberProcs,temp,
			referenceSectionOffset	: LONGINT;
		BEGIN
			
			pointerSection := Block("Heaps","SystemBlockDesc",".@PointerArray",pointerSectionOffset);
			PointerArray(pointerSection,module.module.moduleScope, numberPointers);
			importSection := Block("Heaps","SystemBlockDesc",".@ImportsArray",importSectionOffset);
			ImportsArray(importSection);
			commandsSection := Block("Heaps","SystemBlockDesc",".@CommandArray",commandsSectionOffset);
			CommandArray(commandsSection);
			exceptionSection := Block("Heaps","SystemBlockDesc",".@ExceptionArray",exceptionSectionOffset);
			ExceptionArray(exceptionSection);
			typeInfoSection := Block("Heaps","SystemBlockDesc",".@TypeInfoArray",typeInfoSectionOffset);
			TypeInfoSection(typeInfoSection);
			referenceSection := Block("Heaps","SystemBlockDesc",".@References",referenceSectionOffset);
			References(referenceSection);
			procTableSection := Block("Heaps","SystemBlockDesc",".@ProcTable",procTableSectionOffset);
			IF ~implementationVisitor.backend.cooperative THEN
				ptrTableSection := Block("Heaps","SystemBlockDesc",".@PtrTable",ptrTableSectionOffset);
			ELSE
				ptrTableSection := NIL;
			END;
			PointersInProcTables(procTableSection,ptrTableSection,numberProcs,maxPointers);
			emptyArraySection := Block("Heaps","SystemBlockDesc",".@EmptyArray",emptyArraySectionOffset);
			Array(emptyArraySection,temp,"");
			moduleSection := ModuleSection();
			Info(moduleSection, "nextRoot*: RootObject");
			Address(moduleSection,0);
			Info(moduleSection, "next*: Module");
			Address(moduleSection,0);
			Info(moduleSection, "name*: Name");
			Name(moduleSection,moduleName);
			Info(moduleSection, "init, published: BOOLEAN");
			Boolean(moduleSection,FALSE);
			Boolean(moduleSection,FALSE);
			Info(moduleSection,"filler"); (*! introduce alignment! *)
			Boolean(moduleSection,FALSE);
			Boolean(moduleSection,FALSE);
			Info(moduleSection, "refcnt*: LONGINT");
			Longint(moduleSection,0);
			Info(moduleSection, "sb*: ADDRESS");
			Address(moduleSection,0);
			Info(moduleSection, "entry*: POINTER TO ARRAY OF ADDRESS");
			Symbol(moduleSection,emptyArraySection,emptyArraySectionOffset,0);
			Info(moduleSection, "command*: POINTER TO ARRAY OF Command");
			Symbol(moduleSection,commandsSection,commandsSectionOffset,0);
			Info(moduleSection, "ptrAdr*: POINTER TO ARRAY OF ADDRESS");
			Symbol(moduleSection,pointerSection,pointerSectionOffset,0);
			Info(moduleSection, "typeInfo*: POINTER TO ARRAY OF TypeDesc");
			Symbol(moduleSection,typeInfoSection,typeInfoSectionOffset,0);
			Info(moduleSection, "module*: POINTER TO ARRAY OF Module");
			Symbol(moduleSection,importSection,emptyArraySectionOffset,0);
			Info(moduleSection, "procTable*: ProcTable");
			Symbol(moduleSection,procTableSection,procTableSectionOffset,0);
			Info(moduleSection, "ptrTable*: PtrTable");
			IF ~implementationVisitor.backend.cooperative THEN
				Symbol(moduleSection,ptrTableSection,ptrTableSectionOffset,0);
			ELSE
				Symbol(moduleSection,emptyArraySection,emptyArraySectionOffset,0);
			END;
			Info(moduleSection, "data*, code*, staticTypeDescs*, refs*: Bytes");
			Symbol(moduleSection,emptyArraySection,emptyArraySectionOffset,0);
			Symbol(moduleSection,emptyArraySection,emptyArraySectionOffset,0);
			Symbol(moduleSection,emptyArraySection,emptyArraySectionOffset,0);
			Symbol(moduleSection,referenceSection,referenceSectionOffset,0);
			Info(moduleSection, "export*: ExportDesc");
			ExportDesc(moduleSection);
			Info(moduleSection, "term*: TerminationHandler");
			Address(moduleSection,0);
			Info(moduleSection, "exTable*: ExceptionTable");
			Symbol(moduleSection,exceptionSection,exceptionSectionOffset,0);
			Info(moduleSection, "noProcs*: LONGINT");
			Longint(moduleSection,numberProcs);
			Info(moduleSection, "firstProc*: ADDRESS");
			Address(moduleSection,0);
			Info(moduleSection, "maxPtrs*: LONGINT");
			Longint(moduleSection,maxPointers);
			Info(moduleSection, "crc*: LONGINT");
			Longint(moduleSection, 0); (*!  must be implemented *)


			Info(moduleSection, "body*: ADDRESS");
			Symbol(moduleSection, bodyProc, 0,0);

			IF implementationVisitor.backend.cooperative THEN
				PatchSymbol(moduleSection,MonitorOffset,moduleSection.name,NIL,moduleSection.pc,0);
				Info(moduleSection, "monitor.owner");
				Address(moduleSection,0);
				Info(moduleSection, "monitor.nestingLevel");
				Address(moduleSection,0);
				Info(moduleSection, "monitor.blockedQueue");
				Address(moduleSection,0); Address(moduleSection,0);
				Info(moduleSection, "monitor.waitingQueue");
				Address(moduleSection,0); Address(moduleSection,0);
				Info(moduleSection, "monitor.waitingSentinel");
				Address(moduleSection,0);
			END;
		END Module;

		PROCEDURE PointerArray(source: IntermediateCode.Section; scope: SyntaxTree.Scope; VAR numberPointers: LONGINT);
		VAR variable: SyntaxTree.Variable; pc: LONGINT; symbol: Sections.Section;
		BEGIN
			Array(source,pc,"");
			Info(source, "pointer offsets array data");
			IF scope IS SyntaxTree.RecordScope THEN
				Pointers(0,symbol, source,scope(SyntaxTree.RecordScope).ownerRecord,numberPointers);
			ELSIF scope IS SyntaxTree.CellScope THEN
				Pointers(0, symbol, source, scope(SyntaxTree.CellScope).ownerCell, numberPointers);
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				variable := scope(SyntaxTree.ModuleScope).firstVariable;
				WHILE variable # NIL DO
					IF ~(variable.untraced) & (variable.externalName = NIL) THEN
						symbol := module.allSections.FindBySymbol(variable);
						ASSERT(symbol # NIL);
						Pointers(0,symbol, source,variable.type,numberPointers);
					END;
					variable := variable.nextVariable;
				END;
			END;
			PatchArray(source,pc,numberPointers);
		END PointerArray;

			PROCEDURE SymbolSection(symbol: SyntaxTree.Symbol; CONST suffix: ARRAY OF CHAR; VAR pc: LONGINT): IntermediateCode.Section;
			VAR
				name: Basic.SegmentedName;
				section: IntermediateCode.Section;
			BEGIN
					ASSERT(implementationVisitor.newObjectFile);
					Global.GetSymbolSegmentedName(symbol,name);
					Basic.AppendToSegmentedName(name,suffix);

					section := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name, NIL,TRUE);
					HeapBlock("Heaps","SystemBlockDesc", section, 2);
					Info(section, "HeapBlock");
					Address(section,0); (* empty such that GC does not go on traversing *)
					Info(section, suffix);
					Address(section,0);
					pc := section.pc;
					RETURN section;
			END SymbolSection;
			
			PROCEDURE ReflectVariables(in: IntermediateCode.Section; symbol: SyntaxTree.Symbol);
			VAR type: SyntaxTree.Type; variable: SyntaxTree.Variable; pc: LONGINT; section: IntermediateCode.Section;
			BEGIN
				ASSERT(implementationVisitor.newObjectFile);
				IF ~ReflectionSupport OR simple THEN variable := NIL
				ELSIF symbol IS SyntaxTree.TypeDeclaration THEN
					type := symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
					IF type IS SyntaxTree.PointerType THEN
						type := type(SyntaxTree.PointerType).pointerBase.resolved;
					END;
					IF type IS SyntaxTree.RecordType THEN
						variable := type(SyntaxTree.RecordType).recordScope.firstVariable
					ELSIF type IS SyntaxTree.CellType THEN
						variable := type(SyntaxTree.CellType).cellScope.firstVariable;
					END;
				ELSIF symbol IS SyntaxTree.Procedure THEN
					variable := symbol(SyntaxTree.Procedure).procedureScope.firstVariable;
				END;
				Info(in, "variables");
				IF variable # NIL THEN
					section := SymbolSection(symbol, "@Variables",pc);
					VariableArray(section, variable);
					Symbol(in, section, pc, 0);
				ELSE
					Address(in, 0);
				END;
			END ReflectVariables;

			PROCEDURE ReflectProcedures(in: IntermediateCode.Section; symbol: SyntaxTree.Symbol);
			VAR type: SyntaxTree.Type; procedure: SyntaxTree.Procedure; pc: LONGINT; section: IntermediateCode.Section;
			BEGIN
				ASSERT(implementationVisitor.newObjectFile);
				IF ~ReflectionSupport OR simple THEN procedure := NIL
				ELSIF symbol IS SyntaxTree.TypeDeclaration THEN
					type := symbol(SyntaxTree.TypeDeclaration).declaredType.resolved;
					IF type IS SyntaxTree.PointerType THEN
						type := type(SyntaxTree.PointerType).pointerBase.resolved;
					END;
					IF type IS SyntaxTree.RecordType THEN
						procedure := type(SyntaxTree.RecordType).recordScope.firstProcedure
					ELSIF type IS SyntaxTree.CellType THEN
						procedure := type(SyntaxTree.CellType).cellScope.firstProcedure;
					END;
				ELSIF symbol IS SyntaxTree.Procedure THEN
					procedure := symbol(SyntaxTree.Procedure).procedureScope.firstProcedure;
				END;
				
				Info(in, "procedures");
				IF procedure # NIL THEN
					section := SymbolSection(symbol, "@Procedures",pc);
					ProcedureArray(section, procedure);
					Symbol(in, section, pc, 0);
				ELSE
					Address(in, 0);
				END;
			END ReflectProcedures;
			
			PROCEDURE VariableArray(source: IntermediateCode.Section; variable: SyntaxTree.Variable);
			VAR pc, offset: LONGINT; tir: Sections.Section; size: LONGINT;
				segmentedName: Basic.SegmentedName;
				td: SyntaxTree.TypeDeclaration;
				type: SyntaxTree.Type;
			BEGIN
				Array(source,pc,"Modules.FieldEntry");
				Info(source, "FieldArray");
				size :=0;
				WHILE variable # NIL DO
					Info(source,"name");
					Symbol(source, moduleNamePoolSection, DynamicName(moduleNamePoolSection, variable.name, moduleNamePool), 0); (* reference to dynamic name *)
					type := variable.type.resolved;
					Info(source,"offset");
					Size(source, ToMemoryUnits(module.system,variable.offsetInBits));
					Info(source,"type class");
					IF type IS SyntaxTree.PointerType THEN
						Size(source, 1);
					ELSIF type IS SyntaxTree.RecordType THEN
						Size(source, 2);
					ELSIF type IS SyntaxTree.NumberType THEN
						Size(source, 3);
					ELSE
						Size(source, 0);
					END;
					Info(source, "type desc");
					IF type IS SyntaxTree.RecordType THEN
						td := type(SyntaxTree.RecordType).typeDeclaration;
						Global.GetSymbolSegmentedName(td,segmentedName);
						IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
							tir := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, segmentedName,td,declarationVisitor.dump);
						ELSE
							tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, segmentedName,td,declarationVisitor.dump);
						END;
						offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(type(SyntaxTree.RecordType).recordScope.numberMethods)*module.system.addressSize);
						Symbol(source, tir,  0, offset);
					ELSE
						Address(source, 0);
					END;
					Info(source,"flags");
					Set(source, {});
					variable := variable.nextVariable;
					INC(size);
				END;
				PatchArray(source,pc,size);
			END VariableArray;
			
			PROCEDURE ProcedureArray(source: IntermediateCode.Section; procedure: SyntaxTree.Procedure);
			VAR pc: LONGINT; size: LONGINT; 
				segmentedName: Basic.SegmentedName;
			BEGIN
				Array(source,pc,"Modules.ProcedureEntry");

				Info(source, "ProcedureArray");
				size :=0;
				WHILE procedure # NIL DO
				
					Info(source,"name");
					Symbol(source, moduleNamePoolSection, DynamicName(moduleNamePoolSection, procedure.name, moduleNamePool), 0); (* reference to dynamic name *)

					Global.GetSymbolSegmentedName(procedure, segmentedName);
					NamedSymbol(source, segmentedName, procedure, 0 , 0); 

					(* size *)
					Size(source, 0);
					(* parameters *)
					Address(source, 0);
					(* variables *)
					ReflectVariables(source, procedure);
					ReflectProcedures(source, procedure);

					(* return type entry *)
					Address(source, 0);
					Address(source, 0);
					procedure := procedure.nextProcedure;
					INC(size);
				END;
				PatchArray(source,pc,size);
			END ProcedureArray;


		PROCEDURE CheckTypeDeclaration(x: SyntaxTree.Type);
		VAR recordType: SyntaxTree.RecordType;
			tir: IntermediateCode.Section; op: IntermediateCode.Operand; name: Basic.SegmentedName; td: SyntaxTree.TypeDeclaration;
			section: Sections.Section; cellType: SyntaxTree.CellType;


			PROCEDURE NewTypeDescriptorInfo(tag: Sections.Section; offset: LONGINT; isProtected: BOOLEAN): Sections.Section;
			VAR name: Basic.SegmentedName;source: IntermediateCode.Section;
				moduleSection: IntermediateCode.Section; i: LONGINT; flags: SET;
				sectionName: Basic.SectionName;
			CONST MPO=-40000000H;
			BEGIN
					(*
						TypeDesc* = POINTER TO RECORD
							descSize: LONGINT;
							sentinel: LONGINT;	(* = MPO-4 *)
							tag*: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
							flags*: SET;
							mod*: Module;	(* hint only, because module may have been freed (at Heaps.ModOfs) *)
							name*: Name;
						END;
					*)
					(* source := module.sections.FindByName(...) *)
					Global.GetSymbolSegmentedName(td,name);
					Basic.AppendToSegmentedName(name,"@Info");
					source := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,NIL,declarationVisitor.dump);
					Info(source, "type info size");	Address(source, 3*ToMemoryUnits(module.system,module.system.addressSize)+32);
					Address(source,MPO-4);
					Info(source, "type tag pointer");
					Symbol( source, tag, offset, 0);
					Info(source, "type flags");
					flags := {};
					IF isProtected THEN INCL(flags,31) END;
					Set( source, flags);
					Info(source, "pointer to module");
					moduleSection := ModuleSection();
					Symbol( source, moduleSection, moduleSection.pc,0);
					Info(source, "type name");
					i := 0;
					Global.GetSymbolNameInScope(td, module.module.moduleScope, sectionName);
					(*
					Global.GetSymbolSegmentedName(td,name);
					Basic.SegmentedNameToString(name, sectionName);
					*)
					Name(source,sectionName);
					source.SetReferenced(FALSE);

					Global.GetSymbolSegmentedName(td,name);
					Basic.AppendToSegmentedName(name,"@Fields");
					
					ReflectVariables(source, td);
					ReflectProcedures(source, td);
					(*
					fieldSection := VariableArray(

					fieldSection := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name, NIL,TRUE);
					HeapBlock("Heaps","SystemBlockDesc", fieldSection, 2);
					Info(fieldSection, "HeapBlock");
					Address(fieldSection,0); (* empty such that GC does not go on traversing *)
					Info(fieldSection, "TypeDescriptor");
					Address(fieldSection,0);

					Info(source, "FieldArray ref");
					Symbol(source, fieldSection, fieldSection.pc, 0);

					FieldArray(fieldSection);

					Global.GetSymbolSegmentedName(td,name);
					Basic.AppendToSegmentedName(name,"@Procedures");

					fieldSection := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name, NIL,TRUE);
					HeapBlock("Heaps","SystemBlockDesc", fieldSection, 2);
					Info(fieldSection, "HeapBlock");
					Address(fieldSection,0); (* empty such that GC does not go on traversing *)
					Info(fieldSection, "TypeDescriptor");
					Address(fieldSection,0);

					Info(source, "Procedure Array ref");
					Symbol(source, fieldSection, fieldSection.pc, 0);

					ProcedureArray(fieldSection);
					*)
					RETURN source;
			END NewTypeDescriptorInfo;


			PROCEDURE NewTypeDescriptor;
			VAR name: Basic.SegmentedName; op: IntermediateCode.Operand; source, base: IntermediateCode.Section;
				procedure: SyntaxTree.Procedure; baseRecord: SyntaxTree.RecordType;
				baseTD: SyntaxTree.TypeDeclaration; sym: SyntaxTree.Symbol;
				numberPointers: LONGINT;  padding, i: LONGINT;
			CONST MPO=-40000000H;

				PROCEDURE TdTable(size: LONGINT; reverse: BOOLEAN);
				VAR i: LONGINT;
				
					PROCEDURE Td(record: SyntaxTree.RecordType);
					VAR baseTD: SyntaxTree.TypeDeclaration; name: Basic.SegmentedName; offset: LONGINT; 
					BEGIN
						IF record # NIL THEN
							IF ~reverse THEN Td(record.GetBaseRecord()) END;
							baseTD := record.typeDeclaration;
							Global.GetSymbolSegmentedName(baseTD,name);
							IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
								tir := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,baseTD,declarationVisitor.dump);
							ELSE
								tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,baseTD,declarationVisitor.dump);
							END;
							offset := ToMemoryUnits(module.system,GetTypeRecordBaseOffset(record.recordScope.numberMethods)*module.system.addressSize);
							Symbol(source, tir,  0, offset);
							IF reverse THEN Td(record.GetBaseRecord()) END;
						END;
					END Td;
					
				BEGIN
					Info(source, "tag table");
					baseRecord := recordType;
					i := 0;
					WHILE baseRecord # NIL DO
						INC(i);
						baseRecord := baseRecord.GetBaseRecord();
					END;
					IF i > size THEN implementationVisitor.Error(x.position,"maximal extension level exceeded") END;
					IF ~reverse THEN Td(recordType) END;
					WHILE i < size DO
						Address(source,0);
						INC(i);
					END;
					IF reverse THEN Td(recordType) END;
				END TdTable;

				PROCEDURE MethodTable(reverse: BOOLEAN);
				VAR i,methods: LONGINT;
				BEGIN
					Info(source, "method table");
					IF recordType # NIL THEN
						methods := recordType.recordScope.numberMethods;
						IF reverse THEN
							FOR i := methods-1 TO 0 BY -1 DO
								procedure := recordType.recordScope.FindMethod(i);
								Global.GetSymbolSegmentedName(procedure, name);
								NamedSymbol(source, name,procedure, 0,0);
							END;
						ELSE
							FOR i := 0 TO methods-1 DO
								procedure := recordType.recordScope.FindMethod(i);
								Global.GetSymbolSegmentedName(procedure, name);
								NamedSymbol(source, name,procedure, 0,0);
							END;
						END;
					END;
				END MethodTable;

				PROCEDURE CooperativeMethodTable(pointer: BOOLEAN);
				VAR baseRecord: SyntaxTree.RecordType; name, stackFrame: Basic.SegmentedName; i,start,methods: LONGINT;
				BEGIN
					Info(source, "method table");
					baseRecord := recordType;
					WHILE baseRecord.baseType # NIL DO
						baseRecord := baseRecord.GetBaseRecord ();
					END;
					GetRecordTypeName (baseRecord, name);
					Basic.ToSegmentedName ("BaseTypes.StackFrame", stackFrame);
					IF name = stackFrame THEN
						start := 0;
					ELSIF ~HasExplicitTraceMethod(recordType) THEN
						baseRecord := recordType;
						WHILE (baseRecord # NIL) & ~baseRecord.hasPointers DO
							baseRecord := baseRecord.GetBaseRecord ();
						END;
						IF baseRecord # NIL THEN
							GetRecordTypeName (baseRecord, name);
							IF pointer & ~baseRecord.isObject THEN
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
							END;
							Basic.SuffixSegmentedName (name, Basic.MakeString ("@Trace"));
						ELSIF recordType.isObject THEN
							Basic.ToSegmentedName ("BaseTypes.Object.@Trace",name);
						ELSIF pointer THEN
							Basic.ToSegmentedName ("BaseTypes.Pointer.Trace",name);
						ELSE
							Basic.ToSegmentedName ("BaseTypes.Record.@Trace",name);
						END;
						tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationVisitor.dump);
						Symbol(source, tir,  0, 0);
						start := 0;
						
						baseRecord := recordType;
						WHILE (baseRecord # NIL) DO
							IF HasExplicitTraceMethod(baseRecord) THEN start := 1 END;
							baseRecord := baseRecord.GetBaseRecord ();
						END;
					ELSE
						(* explicit trace method: *)

						procedure := recordType.recordScope.FindMethod(0);
						IF ~procedure.isFinalizer THEN
							Global.GetSymbolSegmentedName(procedure, name);
							NamedSymbol(source, name,procedure, 0,0);
						END;

						start := 1;
					END;
					IF (name # stackFrame) & recordType.isObject THEN
						baseRecord := recordType;
						WHILE (baseRecord # NIL) & (baseRecord.recordScope.finalizer = NIL) DO
							baseRecord := baseRecord.GetBaseRecord ();
						END;
						IF (baseRecord = NIL) OR (baseRecord.recordScope.finalizer = NIL) THEN
							Basic.ToSegmentedName ("BaseTypes.Object.Finalize",name);
						ELSE
							Global.GetSymbolSegmentedName(baseRecord.recordScope.finalizer, name);
						END;
						tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationVisitor.dump);
						Symbol(source, tir,  0, 0);
					END;
					methods := recordType.recordScope.numberMethods;
					FOR i := start TO methods-1 DO
						procedure := recordType.recordScope.FindMethod(i);
						IF ~procedure.isFinalizer THEN
							Global.GetSymbolSegmentedName(procedure, name);
							NamedSymbol(source, name,procedure, 0,0);
						END;
					END;
				END CooperativeMethodTable;

			BEGIN
					Global.GetSymbolSegmentedName(td,name);
					source := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,td,declarationVisitor.dump);
					source.SetExported(IsExported(td));
					
					IF (cellType # NIL) THEN recordType := cellType.GetBaseRecord() END;
					
					IF implementationVisitor.backend.cooperative THEN

						base := NIL;
						baseRecord := recordType.GetBaseRecord();
						IF baseRecord # NIL THEN
							baseTD := baseRecord.typeDeclaration;
						END;

						IF ~recordType.isObject THEN
							Info(source, "parent");
							IF baseRecord # NIL THEN
								Global.GetSymbolSegmentedName(baseTD,name);
								IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
									tir := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,baseTD,declarationVisitor.dump);
								ELSE
									tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,baseTD,declarationVisitor.dump);
								END;
								Symbol(source, tir,  0, 0);
							ELSE
								Address(source,0);
							END;

							Info(source, "record size");
							Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
							source.SetReferenced(FALSE);
							CooperativeMethodTable(FALSE);
	
							base := source;
							Global.GetSymbolSegmentedName(td,name);
							Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
							source := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,NIL,declarationVisitor.dump);
							source.SetExported(IsExported(td));
							source.SetReferenced(FALSE);
						END;

	
						Info(source, "parent");
						IF baseRecord # NIL THEN
							Global.GetSymbolSegmentedName(baseTD,name);
							sym := baseTD;
							IF ~recordType.isObject THEN
								Basic.SuffixSegmentedName (name, Basic.MakeString ("@Pointer"));
								sym := NIL;
							END;
							IF (baseTD.scope = NIL) OR (baseTD.scope.ownerModule = module.module) THEN
								tir := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,sym,declarationVisitor.dump);
							ELSE
								tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,sym,declarationVisitor.dump);
							END;
							Symbol(source, tir,  0, 0);
						ELSIF (recordType.pointerType # NIL) & recordType.pointerType.isPlain THEN
							Address(source,0);
						ELSE
							IF recordType.isObject THEN
								Basic.ToSegmentedName ("BaseTypes.Object",name);
							ELSE
								Basic.ToSegmentedName ("BaseTypes.Record",name);
							END;
							tir := IntermediateCode.NewSection(module.importedSections, Sections.ConstSection, name,NIL,declarationVisitor.dump);
							Symbol(source, tir,  0, 0);
						END;

						Info(source, "base record descriptor");
						Symbol(source, base, 0, 0);
						CooperativeMethodTable(TRUE);
						source.SetReferenced(FALSE);
						
						IF recordType.hasPointers THEN
							IF ~HasExplicitTraceMethod (recordType) THEN
								implementationVisitor.CreateTraceMethod(recordType);
							END;
							implementationVisitor.CreateResetProcedure(recordType);
							implementationVisitor.CreateAssignProcedure(recordType);
						END;
					ELSIF ~simple THEN
						(*

										MethodEnd = MPO
										---
										methods (# methods)
										---
										tags (16)
										---
										TypeDesc = TypeInfoAdr
										---
						td adr ---> 	rec size
										----
										pointer offsets
										----
										(padding)
										-----
										empty [2 addresses aligned]
										empty
										empty
										numPtrs
										---
										pointer offsets
										---
						*)

						Info(source, "MethodEnd = MPO");
						IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.addressType),MPO);
						source(IntermediateCode.Section).Emit(Data(-1,op));

						MethodTable(TRUE);
						TdTable(TypeTags, TRUE);
						Info(source, "type descriptor info pointer");
						Symbol(source, NewTypeDescriptorInfo(source,source.pc+1,recordType.IsProtected()),0,0);
						IF (cellType # NIL) THEN
							IF cellType.sizeInBits < 0 THEN
								ASSERT(module.system.GenerateVariableOffsets(cellType.cellScope));
							END;
							Info(source, "cell size");
							Address(source, ToMemoryUnits(module.system,cellType.sizeInBits));						
						ELSE
							Info(source, "record size");
							Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
						END;
						Info(source, "pointer offsets pointer");
						padding := 1- source.pc MOD 2;
						Symbol(source, source, source.pc+1+padding,0);
						IF padding >0 THEN
							Info(source, "padding");
							FOR i := 1 TO padding DO Address(source,0) END;
						END;
						IF cellType # NIL THEN
							PointerArray(source, cellType.cellScope, numberPointers);
						ELSE
							PointerArray(source, recordType.recordScope, numberPointers);
						END;
					ELSE
						(*
							simple:
							td adr --> size
											tag(1)
											tag(2)
											tag(3)
							methods -> 
						*)
						Info(source, "record size");
						Address(source, ToMemoryUnits(module.system,module.system.SizeOf(recordType)));
						TdTable(TypeTags, FALSE);
						MethodTable(FALSE);
						source.SetReferenced(FALSE);
					END;
			END NewTypeDescriptor;

		BEGIN
			x := x.resolved;
			IF (x IS SyntaxTree.PointerType) THEN
				x := x(SyntaxTree.PointerType).pointerBase.resolved;
			END;

			IF (x IS SyntaxTree.RecordType) THEN (* enter: insert only if not already inserted *)
				recordType := x(SyntaxTree.RecordType);
				td := x.typeDeclaration;
				IF td = NIL THEN td := recordType.pointerType.resolved.typeDeclaration END; (* for compatibility with paco *)
				ASSERT(td # NIL);

				section := module.allSections.FindBySymbol(td); (* TODO *)
				IF (section = NIL) OR (section(IntermediateCode.Section).pc = 0) THEN
					IF implementationVisitor.newObjectFile THEN
						IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
							NewTypeDescriptor
						END;
					ELSE
						(* data section in intermediate code *)
						Global.GetSymbolSegmentedName(td,name);
						tir := IntermediateCode.NewSection(module.allSections, Sections.ConstSection, name,td,implementationVisitor.dump # NIL);
						IntermediateCode.InitImmediate(op,IntermediateCode.GetType(module.system, module.system.addressType),0);
						tir.Emit(Data(-1,op));
					END;
				END;
			ELSIF (x IS SyntaxTree.CellType) & implementationVisitor.backend.cellsAreObjects THEN
				cellType := x(SyntaxTree.CellType);
				td := x.typeDeclaration;
				section := module.allSections.FindBySymbol(td); (* TODO *)
				IF (section = NIL) OR (section(IntermediateCode.Section).pc = 0) THEN
					IF implementationVisitor.newObjectFile THEN
						IF (td.scope = NIL) OR (td.scope.ownerModule = module.module) THEN
							NewTypeDescriptor
						END;
					END;
				END;
			END
		END CheckTypeDeclaration

	END MetaDataGenerator;


	IntermediateBackend*= OBJECT (IntermediateCode.IntermediateBackend)
	VAR
		trace-: BOOLEAN;
		traceString-: SyntaxTree.IdentifierString;
		traceModuleName-: SyntaxTree.IdentifierString;
		newObjectFile-: BOOLEAN;
		profile-: BOOLEAN;
		noRuntimeChecks: BOOLEAN;
		simpleMetaData-: BOOLEAN;
		noAsserts: BOOLEAN;
		optimize-: BOOLEAN;
		cooperative-: BOOLEAN;
		preregisterStatic-: BOOLEAN;
		dump-: Basic.Writer;
		cellsAreObjects: BOOLEAN;

		PROCEDURE &InitIntermediateBackend*;
		BEGIN
			simpleMetaData := FALSE;
			newObjectFile := FALSE;
			InitBackend;
			SetRuntimeModuleName(DefaultRuntimeModuleName);
			SetTraceModuleName(DefaultTraceModuleName);
		END InitIntermediateBackend;

		PROCEDURE GenerateIntermediate*(x: SyntaxTree.Module; supportedInstruction: SupportedInstructionProcedure; supportedImmediate: SupportedImmediateProcedure): Sections.Module;
		VAR
			declarationVisitor: DeclarationVisitor;
			implementationVisitor: ImplementationVisitor;
			module: Sections.Module;
			name, platformName: SyntaxTree.IdentifierString;
			meta: MetaDataGenerator; 
		BEGIN
			ResetError;
			Global.GetSymbolName(x,name);

			NEW(module,x,system); (* backend structures *)

			Global.GetModuleName(x, name);
			module.SetModuleName(name);

			NEW(implementationVisitor,system,checker,supportedInstruction, supportedImmediate, Compiler.FindPC IN flags, runtimeModuleName, SELF, newObjectFile);
			NEW(declarationVisitor,system,implementationVisitor,SELF,Compiler.ForceModuleBodies IN flags,trace & (Compiler.Info IN flags));

			NEW(meta, implementationVisitor, declarationVisitor,simpleMetaData);
			declarationVisitor.Module(x,module);

			IF newObjectFile & ~meta.simple THEN
				meta.Module(implementationVisitor.moduleBodySection);
			END;

			GetDescription(platformName);
			module.SetPlatformName(platformName);

			RETURN module
		END GenerateIntermediate;

		PROCEDURE SupportedImmediate*(CONST op: IntermediateCode.Operand): BOOLEAN;
		BEGIN RETURN TRUE
		END SupportedImmediate;

		PROCEDURE ProcessSyntaxTreeModule(syntaxTreeModule: SyntaxTree.Module): Formats.GeneratedModule;
		BEGIN RETURN ProcessIntermediateCodeModule(GenerateIntermediate(syntaxTreeModule, SupportedInstruction, SupportedImmediate))
		END ProcessSyntaxTreeModule;

		PROCEDURE ProcessIntermediateCodeModule(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		VAR
			result: Sections.Module;
			traceName: Basic.MessageString;
		BEGIN
			ASSERT(intermediateCodeModule IS Sections.Module);
			result := intermediateCodeModule(Sections.Module);

			IF trace THEN
				traceName := "intermediate code trace: ";
				Strings.Append(traceName,traceString);
				dump := Basic.GetWriter(Basic.GetDebugWriter(traceName));
				IF (traceString="") OR (traceString="*") THEN
					result.Dump(dump);
					dump.Update
				ELSE
					Sections.DumpFiltered(dump, result, traceString);
				END
			END;
			RETURN result
		END ProcessIntermediateCodeModule;

		PROCEDURE GetDescription*(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "Intermediate";
		END GetDescription;

		PROCEDURE SetNewObjectFile*(newObjectFile: BOOLEAN; simpleMetaData: BOOLEAN);
		BEGIN
			SELF.newObjectFile := newObjectFile;
			SELF.simpleMetaData := simpleMetaData;
		END SetNewObjectFile;

		PROCEDURE SetTraceModuleName(CONST name: ARRAY OF CHAR);
		BEGIN COPY(name, traceModuleName)
		END SetTraceModuleName;

		PROCEDURE DefineOptions(options: Options.Options);
		BEGIN
			DefineOptions^(options);
			options.Add(0X,"trace",Options.String);
			options.Add(0X,"runtime",Options.String);
			options.Add(0X,"newObjectFile",Options.Flag);
			options.Add(0X,"traceModule",Options.String);
			options.Add(0X,"profile",Options.Flag);
			options.Add(0X,"noRuntimeChecks",Options.Flag);
			options.Add(0X,"noAsserts",Options.Flag);
			options.Add(0X,"metaData",Options.String);
			options.Add('o',"optimize", Options.Flag);
			options.Add(0X,"preregisterStatic", Options.Flag);
			options.Add(0X,"cellsAreObjects", Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions(options: Options.Options);
		VAR name,string: SyntaxTree.IdentifierString;
		BEGIN
			GetOptions^(options);
			trace := options.GetString("trace",traceString);
			profile := options.GetFlag("profile");
			noRuntimeChecks := options.GetFlag("noRuntimeChecks");
			noAsserts := options.GetFlag("noAsserts");
			cooperative := options.GetFlag("cooperative");
			IF options.GetFlag("newObjectFile") THEN newObjectFile := TRUE; 
				IF cooperative THEN 
					SetRuntimeModuleName("CPU") END
				END;
			IF options.GetString("objectFile",string) & (string = "Minos") THEN 
				simpleMetaData := TRUE
			END;
			IF options.GetString("metaData",string) THEN
				IF string = "simple" THEN simpleMetaData := TRUE
				ELSIF string ="full" THEN simpleMetaData := FALSE
				END;
			END;
			IF options.GetString("runtime",name) THEN SetRuntimeModuleName(name) END;
			IF options.GetString("traceModule",name) THEN SetTraceModuleName(name) END;
			optimize := options.GetFlag("optimize");
			preregisterStatic := options.GetFlag("preregisterStatic");
			cellsAreObjects := options.GetFlag("cellsAreObjects");
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get()
		END DefaultSymbolFileFormat;

	END IntermediateBackend;


	(* ----------------------------------- register allocation ------------------------------------- *)


		(* register mapping scheme
			virtual register number	--> register mapping   = 		part(0)		-->	ticket	<-->	physical register
																											spill offset

																	part(n)		-->	ticket	<-->	physical register
																											spill offset
		*)




	VAR int8-, int16-, int32-, int64-, uint8-, uint16-, uint32-, uint64-, float32-, float64-: IntermediateCode.Type;
		emptyOperand: IntermediateCode.Operand;
		systemCalls: ARRAY NumberSystemCalls OF SyntaxTree.Symbol;
		statCoopResetVariables: LONGINT;
		statCoopModifyAssignments: LONGINT;
		modifyAssignmentsPC : LONGINT;
		statCoopNilCheck: LONGINT;
		statCoopSwitch: LONGINT;
		statCoopAssignProcedure: LONGINT;
		statCoopTraceMethod: LONGINT;
		statCoopResetProcedure: LONGINT;
		statCoopTraceModule: LONGINT;
		
	PROCEDURE ResetStatistics*;
	BEGIN
		statCoopResetVariables := 0;
		statCoopModifyAssignments := 0; 
		statCoopNilCheck:= 0;
		statCoopSwitch:= 0;
		statCoopAssignProcedure:= 0;
		statCoopTraceMethod:= 0;
		statCoopResetProcedure:= 0;
		statCoopTraceModule:= 0;
	END ResetStatistics;

	PROCEDURE Statistics*;
	BEGIN
		TRACE(statCoopResetVariables, statCoopModifyAssignments);
		TRACE(statCoopNilCheck, statCoopSwitch);
		TRACE(statCoopAssignProcedure,
		statCoopTraceMethod,
		statCoopResetProcedure,
		statCoopTraceModule)
	END Statistics;


	PROCEDURE GCD(a,b: LONGINT): LONGINT;
	VAR h: LONGINT;
	BEGIN
		WHILE b # 0 DO
			h := a MOD b;
			a := b;
			b := h;
		END;
		RETURN a
	END GCD;

	PROCEDURE SCM(a,b: LONGINT): LONGINT;
	BEGIN
		RETURN a*b DIV GCD(a,b)
	END SCM;

	PROCEDURE CommonAlignment(a,b: LONGINT): LONGINT;
	BEGIN
		(*TRACE(a,b);*)
		IF a = 0 THEN RETURN b
		ELSIF b = 0 THEN RETURN a
		ELSE RETURN SCM(a,b)
		END;
	END CommonAlignment;
	
	PROCEDURE PassBySingleReference(parameter: SyntaxTree.Parameter): BOOLEAN;
	BEGIN
		IF parameter.kind = SyntaxTree.ValueParameter THEN RETURN FALSE
		ELSIF parameter.kind = SyntaxTree.ConstParameter THEN
			RETURN (parameter.type.resolved IS SyntaxTree.RecordType) OR (parameter.type.resolved IS SyntaxTree.ArrayType) & (parameter.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.CCallingConvention)
		ELSIF parameter.kind = SyntaxTree.VarParameter THEN
			RETURN ~(parameter.type.resolved IS SyntaxTree.ArrayType) & ~(parameter.type.resolved IS SyntaxTree.MathArrayType) OR (parameter.type.resolved IS SyntaxTree.ArrayType) & (parameter.ownerType(SyntaxTree.ProcedureType).callingConvention = SyntaxTree.CCallingConvention)
		END
	END PassBySingleReference;

	PROCEDURE PassInRegister(parameter: SyntaxTree.Parameter): BOOLEAN;
	BEGIN
		RETURN  ~parameter.type.IsComposite() OR PassBySingleReference(parameter)
	END PassInRegister;

	PROCEDURE AddRegisterEntry(VAR queue: RegisterEntry; register: LONGINT; class: IntermediateCode.RegisterClass; type: IntermediateCode.Type);
	VAR new: RegisterEntry;
	BEGIN
		NEW(new); new.register := register; new.registerClass := class; new.type := type; new.next := NIL; new.prev := NIL;
		IF queue = NIL THEN
			queue := new
		ELSE
			new.next := queue;
			IF queue#NIL THEN queue.prev := new END;
			queue := new
		END;
	END AddRegisterEntry;

	PROCEDURE RemoveRegisterEntry(VAR queue: RegisterEntry; register: LONGINT): BOOLEAN;
	VAR this: RegisterEntry;
	BEGIN
		this := queue;
		WHILE (this # NIL) & (this.register # register) DO
			this := this.next;
		END;
		IF this = NIL THEN
			RETURN FALSE
		END;
		ASSERT(this # NIL);
		IF this = queue THEN queue := queue.next END;
		IF this.prev # NIL THEN this.prev.next := this.next END;
		IF this.next # NIL THEN this.next.prev := this.prev END;
		RETURN TRUE
	END RemoveRegisterEntry;

	PROCEDURE Assert(cond: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN ASSERT(cond);
	END Assert;

	PROCEDURE ReusableRegister(op: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (op.mode = IntermediateCode.ModeRegister) & (op.register > 0) & (op.offset = 0);
	END ReusableRegister;

	PROCEDURE EnsureBodyProcedure(moduleScope: SyntaxTree.ModuleScope);
	VAR procedure: SyntaxTree.Procedure; procedureScope: SyntaxTree.ProcedureScope;
	BEGIN
		procedure := moduleScope.bodyProcedure;
		IF procedure = NIL THEN (* artificially add body procedure if not existing. Really needed? *)
			procedureScope := SyntaxTree.NewProcedureScope(moduleScope);
			procedure := SyntaxTree.NewProcedure(-1,Global.ModuleBodyName, procedureScope);
			procedure.SetScope(moduleScope);
			procedure.SetType(SyntaxTree.NewProcedureType(-1,moduleScope));
			procedure.SetAccess(SyntaxTree.Hidden);
			moduleScope.SetBodyProcedure(procedure);
			moduleScope.AddProcedure(procedure);
			procedureScope.SetBody(SyntaxTree.NewBody(-1,procedureScope)); (* empty body *)
		END;
	END EnsureBodyProcedure;

	PROCEDURE GetSymbol*(scope: SyntaxTree.ModuleScope; CONST moduleName, symbolName: ARRAY OF CHAR): SyntaxTree.Symbol;
	VAR import: SyntaxTree.Import;
		selfName: SyntaxTree.IdentifierString;
		module: SyntaxTree.Module;
	BEGIN
		scope.ownerModule.GetName(selfName);
		IF (moduleName = selfName) & (scope.ownerModule.context = Global.A2Name) THEN
			module := scope.ownerModule
		ELSE
			import := scope.ImportByModuleName(SyntaxTree.NewIdentifier(moduleName),SyntaxTree.NewIdentifier("A2"));
			IF import = NIL THEN
				RETURN NIL
			ELSIF import.module = NIL THEN
				RETURN NIL
			ELSE module := import.module
			END;
		END;
		RETURN module.moduleScope.FindSymbol(SyntaxTree.NewIdentifier(symbolName));
	END GetSymbol;

	PROCEDURE InitOperand(VAR op: Operand; mode: SHORTINT);
	BEGIN
		op.mode := mode;
		IntermediateCode.InitOperand(op.op);
		IntermediateCode.InitOperand(op.tag);
		IntermediateCode.InitOperand(op.extra);
		op.dimOffset := 0;
	END InitOperand;

	(* TODO: remove this, and redirect calls to 'IntermediateCode.GetType' directly *)
	PROCEDURE GetType*(system: Global.System; type: SyntaxTree.Type): IntermediateCode.Type;
	BEGIN RETURN IntermediateCode.GetType(system, type)
	END GetType;

	PROCEDURE BuildConstant(module: SyntaxTree.Module; value: SyntaxTree.Value; VAR adr: LONGINT): SyntaxTree.Constant;
	VAR name: SyntaxTree.IdentifierString; constant: SyntaxTree.Constant;
	BEGIN
		name := "@const"; Basic.AppendNumber(name, adr); INC(adr);
		(*
		UniqueId(name,module,name,adr);
		*)
		constant := SyntaxTree.NewConstant(-1,SyntaxTree.NewIdentifier(name));
		constant.SetValue(value);
		module.moduleScope.AddConstant(constant);
		constant.SetScope(module.moduleScope);
		RETURN constant
	END BuildConstant;
	
	PROCEDURE HasPointers (scope: SyntaxTree.ProcedureScope): BOOLEAN;
	VAR variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter;
	BEGIN
		variable := scope.firstVariable;
		WHILE variable # NIL DO
			IF variable.NeedsTrace() THEN
				RETURN TRUE;
			END;
			variable := variable.nextVariable;
		END;
		parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
		WHILE parameter # NIL DO
			IF parameter.NeedsTrace() & ~IsVariableParameter(parameter) THEN
				RETURN TRUE;
			END;
			parameter := parameter.nextParameter;
		END;
		RETURN FALSE;
	END HasPointers;
	
	PROCEDURE IsVariableParameter (parameter: SyntaxTree.Parameter): BOOLEAN;
	BEGIN RETURN (parameter.kind = SyntaxTree.VarParameter) OR (parameter.kind = SyntaxTree.ConstParameter) & ((parameter.type.resolved IS SyntaxTree.RecordType) OR (parameter.type.resolved IS SyntaxTree.ArrayType));
	END IsVariableParameter;
	
	PROCEDURE HasVariableParameters(scope: SyntaxTree.ProcedureScope): BOOLEAN;
	VAR parameter: SyntaxTree.Parameter;
	BEGIN
		parameter := scope.ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
		WHILE parameter # NIL DO
			IF IsVariableParameter (parameter) THEN RETURN TRUE END;
			IF parameter.movable THEN RETURN TRUE END;
			parameter := parameter.nextParameter;
		END;
		RETURN scope.ownerProcedure.type(SyntaxTree.ProcedureType).returnParameter # NIL;
	END HasVariableParameters;

	PROCEDURE HasExplicitTraceMethod(recordType: SyntaxTree.RecordType): BOOLEAN;
	BEGIN
		IF (recordType.pointerType # NIL) & ~recordType.pointerType.isPlain THEN RETURN FALSE END;
		RETURN (recordType.recordScope.firstProcedure # NIL) & Basic.StringEqual (Basic.MakeString ("Trace"), recordType.recordScope.firstProcedure.name);
	END HasExplicitTraceMethod;

	PROCEDURE IsIntegerConstant(expression: SyntaxTree.Expression; VAR val: HUGEINT): BOOLEAN;
	BEGIN
		IF expression.resolved # NIL THEN expression := expression.resolved END;

		IF  (expression IS SyntaxTree.IntegerValue)  THEN
			val := expression(SyntaxTree.IntegerValue).value;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END IsIntegerConstant;

	PROCEDURE PowerOf2(val: HUGEINT;  VAR exp: LONGINT): BOOLEAN;
	BEGIN
		IF val <= 0 THEN RETURN FALSE END;
		exp := 0;
		WHILE ~ODD(val) DO
			val := val DIV 2;
			INC(exp)
		END;
		RETURN val = 1
	END PowerOf2;

	PROCEDURE GetConstructor(record: SyntaxTree.RecordType): SyntaxTree.Procedure;
	VAR procedure: SyntaxTree.Procedure;
	BEGIN
		procedure := record.recordScope.constructor;
		IF procedure = NIL THEN
			record := record.GetBaseRecord();
			IF record # NIL THEN
				procedure := GetConstructor(record)
			END;
		END;
		RETURN procedure;
	END GetConstructor;

	PROCEDURE IsIntegerImmediate(CONST op: IntermediateCode.Operand; VAR value: LONGINT): BOOLEAN;
	BEGIN
		value := SHORT(op.intValue);
		RETURN op.mode = IntermediateCode.ModeImmediate;
	END IsIntegerImmediate;

	(** whether a type strictily is a pointer to record or object type
	(however, the basic type <<OBJECT>> is explicitly excluded) **)
	PROCEDURE IsStrictlyPointerToRecord(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN
			RETURN FALSE
		ELSIF type.resolved IS SyntaxTree.PointerType THEN
			RETURN type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType
		ELSE
			RETURN FALSE
		END
	END IsStrictlyPointerToRecord;

	PROCEDURE IsUnsafePointer(type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type # NIL) & (type.resolved IS SyntaxTree.PointerType) & type.resolved(SyntaxTree.PointerType).isUnsafe
	END IsUnsafePointer;

	PROCEDURE IsPointerToRecord(type: SyntaxTree.Type; VAR recordType: SyntaxTree.RecordType): BOOLEAN;
	BEGIN type := type.resolved;
		IF type IS SyntaxTree.PointerType THEN
			type := type(SyntaxTree.PointerType).pointerBase;
			type := type.resolved;
			IF type IS SyntaxTree.RecordType THEN
				recordType := type(SyntaxTree.RecordType);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		ELSIF type IS SyntaxTree.RecordType THEN
			recordType := type(SyntaxTree.RecordType);
			RETURN type(SyntaxTree.RecordType).pointerType # NIL
		ELSIF type IS SyntaxTree.ObjectType THEN
			RETURN TRUE
		ELSIF type IS SyntaxTree.AnyType THEN
			RETURN TRUE (*! potentially is a pointer to record, treat it this way?? *)
		ELSE
			RETURN FALSE
		END;
	END IsPointerToRecord;

	PROCEDURE IsArrayOfSystemByte(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open)
		& (type(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType);
	END IsArrayOfSystemByte;

	PROCEDURE IsOpenArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Open);
	END IsOpenArray;
	
	PROCEDURE IsSemiDynamicArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.SemiDynamic);
	END IsSemiDynamicArray;
	

	PROCEDURE IsStaticArray(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form = SyntaxTree.Static);
	END IsStaticArray;

	PROCEDURE StaticArrayNumElements(type: SyntaxTree.Type): LONGINT;
	VAR size: LONGINT;
	BEGIN
		size := 1;
		WHILE (IsStaticArray(type)) DO
			size := size * type.resolved(SyntaxTree.ArrayType).staticLength;
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN size;
	END StaticArrayNumElements;
	
	PROCEDURE StaticArrayBaseType(type: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		WHILE (IsStaticArray(type)) DO
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN type;
	END StaticArrayBaseType;

	PROCEDURE ArrayBaseType(type: SyntaxTree.Type): SyntaxTree.Type;
	BEGIN
		WHILE (type.resolved IS SyntaxTree.ArrayType) DO
			type := type.resolved(SyntaxTree.ArrayType).arrayBase;
		END;
		RETURN type;
	END ArrayBaseType;
	
	PROCEDURE IsDelegate(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE END;
		type := type.resolved;
		RETURN (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate)
	END IsDelegate;

	PROCEDURE DynamicDim(type:SyntaxTree.Type): LONGINT;
	VAR i: LONGINT;
	BEGIN
		i := 0; type := type.resolved;
		WHILE(type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) DO
			INC(i);
			type := type(SyntaxTree.ArrayType).arrayBase.resolved;
		END;
		WHILE(type # NIL) & (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
			INC(i);
			type := type(SyntaxTree.MathArrayType).arrayBase;
			IF type # NIL THEN type := type.resolved END;
		END;
		RETURN i
	END DynamicDim;

	PROCEDURE StaticSize(system: Global.System; type: SyntaxTree.Type): LONGINT;
	BEGIN
		WHILE (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).form # SyntaxTree.Static) DO
			type := type(SyntaxTree.ArrayType).arrayBase;
		END;
		WHILE (type IS SyntaxTree.MathArrayType) & (type(SyntaxTree.MathArrayType).form # SyntaxTree.Static) DO
			type := type(SyntaxTree.MathArrayType).arrayBase;
		END;
		RETURN ToMemoryUnits(system,system.AlignedSizeOf(type));
	END StaticSize;

	PROCEDURE IsImmediate(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeImmediate)  & (x.symbol.name = "");
	END IsImmediate;

	PROCEDURE IsAddress(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeImmediate) & (x.symbol.name # "")
	END IsAddress;

	PROCEDURE IsRegister(x: IntermediateCode.Operand): BOOLEAN;
	BEGIN
		RETURN (x.mode = IntermediateCode.ModeRegister);
	END IsRegister;

	PROCEDURE GetRecordTypeName(recordType: SyntaxTree.RecordType; VAR name: Basic.SegmentedName);
	VAR typeDeclaration: SyntaxTree.TypeDeclaration;
	BEGIN
		typeDeclaration := recordType.typeDeclaration;
		IF typeDeclaration = NIL THEN typeDeclaration := recordType.pointerType.resolved.typeDeclaration END; (* for compatibility with paco *)
		Global.GetSymbolSegmentedName(typeDeclaration,name);
	END GetRecordTypeName;

	PROCEDURE ParametersSize(system: Global.System; procedureType: SyntaxTree.ProcedureType; isNested: BOOLEAN): LONGINT;
	VAR parSize: LONGINT; parameter: SyntaxTree.Parameter;
	BEGIN
		parSize := 0;

		IF StructuredReturnType(procedureType) THEN
			parameter := procedureType.returnParameter;
			INC(parSize,system.SizeOfParameter(parameter));
			parSize := parSize + (-parSize) MOD system.addressSize;
		END;

		parameter :=procedureType.lastParameter;
		WHILE (parameter # NIL) DO
			INC(parSize,system.SizeOfParameter(parameter));
			parSize := parSize + (-parSize) MOD system.addressSize;
			parameter := parameter.prevParameter;
		END;

		IF procedureType.isDelegate THEN INC(parSize,system.addressSize) END; (* method => self pointer *)
		IF isNested THEN INC(parSize,system.addressSize) END; (* nested procedure => static base *)

		RETURN ToMemoryUnits(system,parSize)
	END ParametersSize;

	PROCEDURE ReturnedAsParameter(type: SyntaxTree.Type): BOOLEAN;
	BEGIN
		IF type = NIL THEN RETURN FALSE
		ELSE
			type := type.resolved;
			RETURN (type IS SyntaxTree.RecordType) OR (type IS SyntaxTree.RangeType) OR (type IS SyntaxTree.ComplexType) OR (type IS SyntaxTree.ProcedureType) OR SemanticChecker.IsPointerType(type)
				OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType);
		END
	END ReturnedAsParameter;

	PROCEDURE StructuredReturnType(procedureType: SyntaxTree.ProcedureType): BOOLEAN;
	BEGIN
		RETURN (procedureType # NIL) & (procedureType.callingConvention=SyntaxTree.OberonCallingConvention) & ReturnedAsParameter(procedureType.returnType);
	END StructuredReturnType;

	PROCEDURE IsNested(procedure: SyntaxTree.Procedure): BOOLEAN;
	BEGIN
		RETURN (procedure.scope IS SyntaxTree.ProcedureScope) & (procedure.externalName = NIL);
	END IsNested;

	PROCEDURE InCellScope(scope: SyntaxTree.Scope): BOOLEAN;
	BEGIN
		WHILE (scope # NIL) & ~(scope IS SyntaxTree.CellScope) DO
			scope := scope.outerScope;
		END;
		RETURN scope # NIL;
	END InCellScope;
	

	PROCEDURE ProcedureParametersSize*(system: Global.System; procedure: SyntaxTree.Procedure): LONGINT;
	BEGIN
		(*IF (procedure.scope IS SyntaxTree.CellScope) & (procedure = procedure.scope(SyntaxTree.CellScope).constructor) & ~backend.cellsAreObjects THEN
			RETURN 0
		ELSE
		*)
			RETURN ParametersSize(system,procedure.type(SyntaxTree.ProcedureType),IsNested(procedure));
		(*END;*)
	END ProcedureParametersSize;

	PROCEDURE ToMemoryUnits*(system: Global.System; size: LONGINT): LONGINT;
	VAR dataUnit: LONGINT;
	BEGIN dataUnit := system.dataUnit;

		ASSERT(size MOD system.dataUnit = 0);
		RETURN size DIV system.dataUnit
	END ToMemoryUnits;

	PROCEDURE Get*(): Backend.Backend;
	VAR backend: IntermediateBackend;
	BEGIN NEW(backend); RETURN backend
	END Get;

	PROCEDURE Nop(position: LONGINT):IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.nop,emptyOperand,emptyOperand,emptyOperand);
		RETURN instruction
	END Nop;

	PROCEDURE Mov(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.mov,dest,src,emptyOperand);
		RETURN instruction
	END Mov;

	(* like Mov but ensures that no new register will be allocated for dest *)
	PROCEDURE MovReplace(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.mov,dest,src,dest);
		RETURN instruction
	END MovReplace;

	PROCEDURE Conv(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.conv,dest,src,emptyOperand);
		RETURN instruction
	END Conv;

	PROCEDURE Call*(position: LONGINT;op: IntermediateCode.Operand; parSize: LONGINT): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.call,op,IntermediateCode.Number(parSize),emptyOperand);
		RETURN instruction
	END Call;

	PROCEDURE Exit(position: LONGINT;pcOffset: LONGINT; callingConvention: LONGINT): IntermediateCode.Instruction;
	VAR op1, op2: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,pcOffset);
		IntermediateCode.InitNumber(op2,callingConvention);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.exit,op1,op2,emptyOperand);
		RETURN instruction
	END Exit;

	PROCEDURE Return(position: LONGINT;res: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.return,res,emptyOperand,emptyOperand);
		RETURN instruction
	END Return;

	PROCEDURE Result*(position: LONGINT;res: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.result,res,emptyOperand,emptyOperand);
		RETURN instruction
	END Result;

	PROCEDURE Trap(position: LONGINT;nr: LONGINT): IntermediateCode.Instruction;
 	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,nr);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.trap,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END Trap;

	PROCEDURE Br(position: LONGINT;dest: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.br,dest,emptyOperand,emptyOperand);
		RETURN instruction
	END Br;

	PROCEDURE Breq(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.breq,dest,left,right);
		RETURN instruction
	END Breq;

	PROCEDURE Brne(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brne,dest,left,right);
		RETURN instruction
	END Brne;

	PROCEDURE Brge(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brge,dest,left,right);
		RETURN instruction
	END Brge;

	PROCEDURE Brlt(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.brlt,dest,left,right);
		RETURN instruction
	END Brlt;

	PROCEDURE Pop*(position: LONGINT;op:IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.pop,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Pop;

	PROCEDURE Push*(position: LONGINT;op: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		ASSERT(op.mode # IntermediateCode.Undefined);
		IntermediateCode.InitInstruction(instruction, position, IntermediateCode.push,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Push;

	PROCEDURE Neg(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position, IntermediateCode.neg,dest,src,emptyOperand);
		RETURN instruction
	END Neg;

	PROCEDURE Not(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.not,dest,src,emptyOperand);
		RETURN instruction
	END Not;

	PROCEDURE Abs(position: LONGINT;dest,src: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.abs,dest,src,emptyOperand);
		RETURN instruction
	END Abs;

	PROCEDURE Mul(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.mul,dest,left,right);
		RETURN instruction
	END Mul;

	PROCEDURE Div(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.div,dest,left,right);
		RETURN instruction
	END Div;

	PROCEDURE Mod(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.mod,dest,left,right);
		RETURN instruction
	END Mod;

	PROCEDURE Sub(position: LONGINT;dest: IntermediateCode.Operand; left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.sub,dest,left,right);
		RETURN instruction
	END Sub;

	PROCEDURE Add(position: LONGINT;dest: IntermediateCode.Operand; left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.add,dest,left,right);
		RETURN instruction
	END Add;

	PROCEDURE And(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.and,dest,left,right);
		RETURN instruction
	END And;

	PROCEDURE Or(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.or,dest,left,right);
		RETURN instruction
	END Or;

	PROCEDURE Xor(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.xor,dest,left,right);
		RETURN instruction
	END Xor;

	PROCEDURE Shl(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.shl,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Shl;

	PROCEDURE Shr(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.shr,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Shr;

	PROCEDURE Rol(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.rol,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Rol;

	PROCEDURE Ror(position: LONGINT;dest,left,right: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.ror,dest,left, IntermediateCode.ToUnsigned(right));
		RETURN instruction
	END Ror;

	PROCEDURE Cas(position: LONGINT;dest,src,size: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.cas,dest,src,size);
		RETURN instruction
	END Cas;

	PROCEDURE Copy(position: LONGINT;dest,src,size: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.copy,dest,src,size);
		RETURN instruction
	END Copy;

	PROCEDURE Fill(position: LONGINT;dest,size, value: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.fill,dest,size,value);
		RETURN instruction
	END Fill;

	PROCEDURE Asm(position: LONGINT;s: SyntaxTree.SourceCode; inRules, outRules: IntermediateCode.Rules): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction; string, o1, o2: IntermediateCode.Operand;
	BEGIN
		string := IntermediateCode.String(s);
		IntermediateCode.SetIntValue(string,position); (* for error reporting *)
		IF inRules # NIL THEN IntermediateCode.InitRule(o1, inRules) ELSE o1 := emptyOperand END;
		IF outRules # NIL THEN IntermediateCode.InitRule(o2, outRules) ELSE o2 := emptyOperand END;
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.asm,string,o1,o2);
		RETURN instruction
	END Asm;

	PROCEDURE Data*(position: LONGINT;op: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.data,op,emptyOperand,emptyOperand);
		RETURN instruction
	END Data;

	PROCEDURE SpecialInstruction(position: LONGINT;subtype: SHORTINT; op1,op2,op3: IntermediateCode.Operand): IntermediateCode.Instruction;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.special,op1,op2,op3);
		IntermediateCode.SetSubType(instruction, subtype);
		RETURN instruction
	END SpecialInstruction;


	PROCEDURE Reserve(position: LONGINT;units: LONGINT): IntermediateCode.Instruction;
	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		(*! generate a warning if size exceeds a certain limit *)
		(*
		ASSERT(bytes < 1000000); (* sanity check *)
		*)
		ASSERT(0 <= units); (* sanity check *)
		IntermediateCode.InitNumber(op1,units);
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.reserve,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END Reserve;

	PROCEDURE LabelInstruction(position: LONGINT): IntermediateCode.Instruction;
	VAR op1: IntermediateCode.Operand;
	VAR instruction: IntermediateCode.Instruction;
	BEGIN
		IntermediateCode.InitNumber(op1,position);
		IntermediateCode.InitInstruction(instruction,position,IntermediateCode.label,op1,emptyOperand,emptyOperand);
		RETURN instruction
	END LabelInstruction;

	PROCEDURE EnterImmediate*(data: IntermediateCode.Section; CONST vop: IntermediateCode.Operand): LONGINT;
	VAR pc: LONGINT;

		PROCEDURE ProvidesValue(CONST instr: IntermediateCode.Instruction; op: IntermediateCode.Operand): BOOLEAN;
		BEGIN
			IF instr.opcode # IntermediateCode.data THEN RETURN FALSE END;
			ASSERT(instr.op1.mode = IntermediateCode.ModeImmediate);
			IF instr.op1.type.sizeInBits # op.type.sizeInBits THEN RETURN FALSE END;
			IF instr.op1.type.form # op.type.form THEN RETURN FALSE END;
			IF instr.op1.type.form = IntermediateCode.Float THEN
				RETURN instr.op1.floatValue = op.floatValue
			ELSE
				RETURN instr.op1.intValue = op.intValue
			END;
		END ProvidesValue;

	BEGIN
		ASSERT(vop.mode = IntermediateCode.ModeImmediate);
		pc := 0;
		WHILE (pc<data.pc) & ~ProvidesValue(data.instructions[pc],vop) DO
			INC(pc);
		END;

		IF pc = data.pc THEN
			data.Emit(Data(-1,vop));
		END;
		RETURN pc
	END EnterImmediate;


	PROCEDURE Init;
	VAR i: LONGINT; name: SyntaxTree.IdentifierString;
	BEGIN
		int8 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits8);
		int16 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits16);
		int32 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits32);
		int64 := IntermediateCode.NewType(IntermediateCode.SignedInteger,IntermediateCode.Bits64);
		uint8 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits8);
		uint16 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits16);
		uint32 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits32);
		uint64 := IntermediateCode.NewType(IntermediateCode.UnsignedInteger,IntermediateCode.Bits64);
		float32 := IntermediateCode.NewType(IntermediateCode.Float,IntermediateCode.Bits32);
		float64 := IntermediateCode.NewType(IntermediateCode.Float,IntermediateCode.Bits64);
		IntermediateCode.InitOperand(emptyOperand);

		FOR i := 0 TO NumberSystemCalls-1 DO
			name := "@SystemCall";
			Basic.AppendNumber(name,i);
			systemCalls[i] := SyntaxTree.NewSymbol(SyntaxTree.NewIdentifier(name));
		END;


	END Init;

	PROCEDURE IsExported(symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN
		RETURN (symbol # NIL) & (symbol.access * SyntaxTree.Public # {})
	END IsExported;



BEGIN
	Init;

END FoxIntermediateBackend.


Compiler.Compile FoxIntermediateBackend.Mod ~
