MODULE FoxTranspilerBackend;	(** AUTHOR "negelef"; PURPOSE "Oberon to C transpiler"; *)

IMPORT Basic := FoxBasic, Global := FoxGlobal, Backend := FoxBackend, SyntaxTree := FoxSyntaxTree, Scanner := FoxScanner,
	Formats := FoxFormats, Files, Streams, Strings, Options, SymbolFileFormat := FoxTextualSymbolFile, Printout := FoxPrintout;

CONST

	Space = ' ';
	Tab = 9X;
	Comma = ',';
	Semicolon = ';';
	LeftBrace = '{';
	RightBrace = '}';

	StructTag = "_tag";
	BaseTag = "_base";
	TypeTag = "_type";
	LenTag = "_len";
	PointerTag = "_pointer";
	DelegateTag = "_delegate";
	BaseObjectName = "BaseObject";
	TypeDescriptorTag = "_descriptor";

	DefaultStyle = 0;
	StailaStyle = 1;

TYPE
	TYPE Style = INTEGER;
	TYPE Indent = INTEGER;
	Identifier = ARRAY Scanner.MaxIdentifierLength OF CHAR;

	TYPE Transpiler* = OBJECT (SyntaxTree.Visitor)
	VAR
		indent: Indent;
		writer: Streams.Writer;
		backend: TranspilerBackend;
		currentProcedureScope: SyntaxTree.ProcedureScope;
		initializeLocalData: BOOLEAN;

		PROCEDURE &InitTranspiler (writer: Streams.Writer; backend: TranspilerBackend; initLocalData: BOOLEAN);
		BEGIN indent := 0; SELF.writer := writer; SELF.backend := backend; currentProcedureScope := NIL; initializeLocalData:= initLocalData;
		END InitTranspiler;

		PROCEDURE DeclareModule (module: SyntaxTree.Module);
		BEGIN
			DeclareImports (module.moduleScope);
			DefineConstants (module.moduleScope);
			DefineTypes (module.moduleScope);
			DeclareVariables (module.moduleScope);
			DeclareProcedures (module.moduleScope);
			DeclareObjects (module.moduleScope);
		END DeclareModule;

		PROCEDURE DeclareImports (scope: SyntaxTree.ModuleScope);
		VAR filename: Files.FileName; import: SyntaxTree.Import;
		BEGIN
			writer.Ln; PrintInclude ("oberon.h");
			import := scope.firstImport;
			WHILE import # NIL DO
				IF ~Global.IsSystemModule (import.module) & import.direct THEN
					GetHeaderName (import.module, filename, backend.style);
					PrintInclude (filename);
				END;
				import := import.nextImport;
			END;
		END DeclareImports;

		PROCEDURE DeclareVariables (scope: SyntaxTree.Scope);
		VAR variable: SyntaxTree.Variable; name: Identifier;
		BEGIN
			variable := scope.firstVariable;
			IF scope IS SyntaxTree.ModuleScope THEN
				GetScopeName (scope, name, backend.style); writer.Ln;
				PrintIndent; writer.String ("extern "); writer.String (BaseObjectName);
				writer.Char (Space); writer.String (name); writer.String (StructTag); writer.Char (Semicolon); writer.Ln;
			ELSIF variable # NIL THEN writer.Ln END;
			WHILE variable # NIL DO
				GetSymbolName (variable, name, backend.style);
				PrintComments (variable.comment, variable);
				PrintIndent; writer.String ("extern ");
				PrintVariable (FALSE, name, variable.type); writer.Char (Semicolon);
				writer.Ln;
				IF IsDelegate (variable.type.resolved) THEN
					PrintIndent; writer.String ("extern "); writer.String (BaseObjectName); writer.Char ('*');
					writer.Char (' '); writer.String (name); writer.String (DelegateTag); writer.Char (Semicolon); writer.Ln;
				END;
				variable := variable.nextVariable;
			END;
		END DeclareVariables;

		PROCEDURE DeclareProcedures (scope: SyntaxTree.Scope);
		VAR procedure: SyntaxTree.Procedure; name: Identifier;
		BEGIN
			procedure := scope.firstProcedure;
			IF procedure # NIL THEN writer.Ln; END;
			WHILE procedure # NIL DO
				IF IsInlineAssemblyCode (procedure) THEN
					GetSymbolName (procedure, name, backend.style); writer.Ln; writer.String ("#define "); writer.String (name);
					writer.String ("() "); PrintCode (procedure.procedureScope.body.code); writer.Ln;
				ELSE
					PrintIndent; PrintProcedure (procedure); writer.Char (Semicolon); writer.Ln;
				END;
				procedure := procedure.nextProcedure;
			END;
		END DeclareProcedures;

		PROCEDURE DeclareObjects (scope: SyntaxTree.Scope);
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; record: SyntaxTree.RecordType;
		BEGIN
			typeDeclaration := scope.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				record := GetRecord (typeDeclaration.declaredType);
				IF record # NIL THEN DeclareProcedures (record.recordScope); DeclareDescriptor (record) END;
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
		END DeclareObjects;

		PROCEDURE DeclareDescriptor (record: SyntaxTree.RecordType);
		VAR name: Identifier; method: LONGINT; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
		BEGIN
			GetSymbolName (record.typeDeclaration, name, backend.style);
			writer.Ln; writer.String ("typedef struct "); writer.String (name); writer.String (TypeTag); writer.String (StructTag);
			writer.Char (Space); writer.String (name); writer.String (TypeTag); writer.Char (Semicolon); writer.Ln;
			writer.Ln; writer.String ("extern "); writer.String (name); writer.String (TypeTag); INC (indent);
			writer.Char (Space); writer.String (name); writer.String (TypeDescriptorTag); writer.Char (Semicolon); writer.Ln;
			writer.Ln; writer.String ("struct "); writer.String (name); writer.String (TypeTag); writer.String (StructTag); writer.Char (Space); writer.Char ('{'); writer.Ln;
			PrintIndent; writer.String ("void* "); writer.String (BaseTag); writer.Char (Semicolon); writer.Ln;
			FOR method := 0 TO record.recordScope.numberMethods - 1 DO
				procedure := GetRecordMethod (record, method);
				procedure.GetName(name); FixIdentifier (name, backend.style);
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				PrintIndent; PrintType (TRUE, procedureType.returnType, name);
				PrintParameters (procedureType, procedure.scope);
				writer.Char (Semicolon); writer.Ln;
			END;
			DEC (indent); writer.Char ('}'); writer.Char (Semicolon); writer.Ln;
		END DeclareDescriptor;

		PROCEDURE DefineModule (module: SyntaxTree.Module);
		BEGIN
			DefineImports (module.moduleScope);
			DefineVariables (module.moduleScope);
			DefineProcedures (module.moduleScope);
			DefineObjects (module.moduleScope);
		END DefineModule;

		PROCEDURE DefineMain (module: SyntaxTree.Module);
		VAR name: Identifier;
		BEGIN
			writer.Ln; PrintIndent; writer.String ("int main ()"); writer.Ln; BeginBlock;
			IF module.moduleScope.bodyProcedure # NIL THEN
				GetSymbolName (module.moduleScope.bodyProcedure, name, backend.style);
				PrintIndent; writer.String (name); writer.String (" ();"); writer.Ln;
			END;
			EndBlock;
		END DefineMain;

		PROCEDURE DefineImports (scope: SyntaxTree.ModuleScope);
		VAR filename: Files.FileName; import: SyntaxTree.Import;
		BEGIN
			writer.Ln; PrintInclude ("oberon.h");
			GetHeaderName (scope.ownerModule, filename, backend.style); PrintInclude (filename);
			import := scope.firstImport;
			WHILE import # NIL DO
				PrintComments (import.comment, import);
				import := import.nextImport;
			END;
		END DefineImports;

		PROCEDURE DefineConstants (scope: SyntaxTree.Scope);
		VAR constant: SyntaxTree.Constant; name: Identifier;
		BEGIN
			constant := scope.firstConstant;
			IF constant # NIL THEN writer.Ln; END;
			WHILE constant # NIL DO
				GetSymbolName (constant, name, backend.style);
				PrintComments (constant.comment, constant);
				writer.String ("#define "); writer.String (name);
				writer.Char (Space); PrintExpression (constant.value);
				writer.Ln;
				constant := constant.nextConstant;
			END;
		END DefineConstants;

		PROCEDURE DefineTypes (scope: SyntaxTree.Scope);
		TYPE Types = POINTER TO ARRAY OF SyntaxTree.Type;
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; types: Types; count: LONGINT;

			PROCEDURE DeclareType (type: SyntaxTree.Type);
			VAR name: Identifier;
			BEGIN
				IF type IS SyntaxTree.RecordType THEN
					GetSymbolName (type.typeDeclaration, name, backend.style);
					writer.String ("typedef struct "); writer.String (name); writer.String (StructTag);
					writer.Char (Space); writer.String (name); writer.Char (Semicolon); writer.Ln;
				ELSIF (type IS SyntaxTree.PointerType) THEN
					writer.String ("typedef struct ");
					IF type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType THEN
						GetSymbolName (type(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType).typeDeclaration, name, backend.style);
						writer.String (name);
					ELSE
						writer.String ("Array");
					END;
					writer.String (PointerTag); GetSymbolName (type.typeDeclaration, name, backend.style);
					writer.Char (Space); writer.Char ('*'); writer.String (name); writer.Char (Semicolon); writer.Ln;
				END;
			END DeclareType;

			PROCEDURE DefineType (type: SyntaxTree.Type; reference: BOOLEAN);
			VAR i: LONGINT; variable: SyntaxTree.Variable; new: Types; name: Identifier;
			BEGIN
				IF (type IS SyntaxTree.PointerType) & ~reference THEN RETURN END;
				FOR i := 0 TO count - 1 DO IF types[i] = type THEN RETURN END END;
				IF LEN (types) = count THEN NEW (new, count * 2); FOR i := 0 TO count - 1 DO new[i] := types[i] END; types := new; END;
				types[count] := type; INC (count);
				IF type.typeDeclaration # NIL THEN GetSymbolName (type.typeDeclaration, name, backend.style) END;
				IF type IS SyntaxTree.ArrayType THEN
					DefineType (type(SyntaxTree.ArrayType).arrayBase.resolved, FALSE);
				ELSIF type IS SyntaxTree.PointerType THEN
					DefineType (type(SyntaxTree.PointerType).pointerBase.resolved, TRUE);
				ELSIF type IS SyntaxTree.RecordType THEN
					IF type(SyntaxTree.RecordType).baseType # NIL THEN DefineType (type(SyntaxTree.RecordType).GetBaseRecord (), FALSE) END;
					DefineTypes (type(SyntaxTree.RecordType).recordScope);
					variable := type(SyntaxTree.RecordType).recordScope.firstVariable;
					WHILE variable # NIL DO
						DefineType (variable.type.resolved, FALSE);
						variable := variable.nextVariable;
					END;
				END;
				IF (type.typeDeclaration = NIL) OR (type.typeDeclaration.scope # scope) THEN RETURN END;
				IF type IS SyntaxTree.RecordType THEN
					writer.Ln; writer.String ("struct "); writer.String (name); writer.String (StructTag);
					writer.Char (Space); writer.Char (LeftBrace); writer.Ln; INC (indent); PrintIndent;
					IF type(SyntaxTree.RecordType).baseType # NIL THEN
						IF type(SyntaxTree.RecordType).isObject OR ~IsEmptyRecord (type(SyntaxTree.RecordType).GetBaseRecord ()) THEN
							writer.String ("struct "); PrintType (FALSE, type(SyntaxTree.RecordType).GetBaseRecord (), ""); writer.String (StructTag);
							writer.Char (Space); writer.String (BaseTag); writer.Char (Semicolon); writer.Ln;
						END;
					ELSIF type(SyntaxTree.RecordType).isObject THEN
						writer.String (BaseObjectName); writer.Char (Space); writer.String (BaseTag); writer.Char (Semicolon); writer.Ln;
					ELSIF type(SyntaxTree.RecordType).recordScope.numberVariables = 0 THEN
						writer.String ("char dummy;"); writer.Ln;
					END;
					DefineVariables (type(SyntaxTree.RecordType).recordScope);
					DEC (indent); writer.Char (RightBrace); writer.Char (Semicolon); writer.Ln;
					writer.Ln; writer.String ("struct "); writer.String (name); writer.String (PointerTag);
					writer.Char (Space); writer.Char (LeftBrace); writer.Ln; INC (indent);
					PrintIndent; writer.String ("void* "); writer.String (TypeDescriptorTag); writer.Char (Semicolon); writer.Ln;
					PrintIndent; writer.String ("struct "); PrintType (FALSE, type(SyntaxTree.RecordType), ""); writer.String (StructTag); writer.Char (Space); writer.String ("record"); writer.Char (Semicolon); writer.Ln;
					DEC (indent); writer.Char (RightBrace); writer.Char (Semicolon); writer.Ln;
				ELSIF type IS SyntaxTree.EnumerationType THEN
					writer.String ("typedef int "); PrintType (FALSE, type, ""); writer.Char (Semicolon); writer.Ln;
				ELSIF ~(type IS SyntaxTree.PointerType) OR IsStaticArray (type(SyntaxTree.PointerType).pointerBase.resolved) THEN
					writer.String ("typedef "); PrintType (FALSE, type, name); writer.Char (Semicolon); writer.Ln;
				END;
			END DefineType;

		BEGIN
			typeDeclaration := scope.firstTypeDeclaration;
			IF typeDeclaration # NIL THEN writer.Ln END;
			WHILE typeDeclaration # NIL DO
				DeclareType (typeDeclaration.declaredType);
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
			NEW (types, 100); count := 0;
			typeDeclaration := scope.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				DefineType (typeDeclaration.declaredType, TRUE);
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
		END DefineTypes;

		PROCEDURE DefineVariables (scope: SyntaxTree.Scope);
		VAR variable: SyntaxTree.Variable; name: Identifier;
		BEGIN
			variable := scope.firstVariable;
			IF scope IS SyntaxTree.ModuleScope THEN
				GetScopeName (scope, name, backend.style); writer.Ln; PrintIndent; writer.String (BaseObjectName);
				writer.Char (Space); writer.String (name); writer.String (StructTag); writer.Char (Semicolon); writer.Ln;
			ELSIF variable # NIL THEN writer.Ln END;
			WHILE variable # NIL DO
				GetSymbolName (variable, name, backend.style); PrintIndent;
				PrintVariable (FALSE, name, variable.type); writer.Char (Semicolon); writer.Ln;
				IF IsDelegate (variable.type.resolved) THEN
					PrintIndent; writer.String (BaseObjectName); writer.Char ('*'); writer.Char (' ');
					writer.String (name); writer.String (DelegateTag); writer.Char (Semicolon); writer.Ln;
				END;
				variable := variable.nextVariable;
			END;
		END DefineVariables;

		PROCEDURE DefineProcedures (scope: SyntaxTree.Scope);
		VAR procedure: SyntaxTree.Procedure;
		BEGIN
			procedure := scope.firstProcedure;
			WHILE procedure # NIL DO
				IF ~IsInlineAssemblyCode (procedure) THEN
					DefineConstants (procedure.procedureScope);
					DefineTypes (procedure.procedureScope);
					DeclareProcedures (procedure.procedureScope);
					writer.Ln; PrintComments (procedure.comment, procedure);
					PrintProcedure (procedure); writer.Ln;
					PrintBody (procedure, procedure.procedureScope.body, procedure.procedureScope.firstVariable);
					DefineProcedures (procedure.procedureScope);
				END;
				procedure := procedure.nextProcedure;
			END;
		END DefineProcedures;

		PROCEDURE DefineObjects (scope: SyntaxTree.Scope);
		VAR typeDeclaration: SyntaxTree.TypeDeclaration; record: SyntaxTree.RecordType;
		BEGIN
			typeDeclaration := scope.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				record := GetRecord (typeDeclaration.declaredType);
				IF record # NIL THEN DefineDescriptor (record); DefineProcedures (record.recordScope) END;
				typeDeclaration := typeDeclaration.nextTypeDeclaration;
			END;
		END DefineObjects;

		PROCEDURE DefineDescriptor (record: SyntaxTree.RecordType);
		VAR name: Identifier; method: LONGINT; procedure: SyntaxTree.Procedure;
		BEGIN
			GetSymbolName (record.typeDeclaration, name, backend.style);
			writer.Ln; writer.String (name); writer.String (TypeTag); writer.Char (Space); writer.String (name);
			writer.String (TypeDescriptorTag); INC (indent); writer.String (" = {"); writer.Ln; PrintIndent;
			IF record.baseType # NIL THEN writer.Char ('&'); PrintType (FALSE, record.baseType, ""); writer.String (TypeDescriptorTag);
			ELSIF record.isObject THEN writer.Char ('&'); writer.String (BaseObjectName); writer.String (TypeDescriptorTag);
			ELSE writer.Char ('0'); END; writer.Char (Comma); writer.Ln;
			FOR method := 0 TO record.recordScope.numberMethods - 1 DO
				procedure := GetRecordMethod (record, method);
				GetSymbolName (procedure, name, backend.style); PrintIndent; writer.String (name); writer.Char (Comma); writer.Ln;
			END;
			DEC (indent); writer.Char ('}'); writer.Char (Semicolon); writer.Ln;
		END DefineDescriptor;

		PROCEDURE BeginBlock;
		BEGIN PrintIndent; writer.Char (LeftBrace); writer.Ln; INC (indent);
		END BeginBlock;

		PROCEDURE EndBlock;
		BEGIN DEC (indent); PrintIndent; writer.Char (RightBrace); writer.Ln;
		END EndBlock;

		PROCEDURE AccessBase (record, base: SyntaxTree.RecordType);
		BEGIN
			WHILE (record # base) & (record # NIL) DO
				IF (record.baseType # NIL) OR record.isObject THEN
					writer.Char ('.'); writer.String (BaseTag);
				END;
				record := record.GetBaseRecord ();
			END;
		END AccessBase;

		PROCEDURE BeginRuntimeCall (CONST module, procedure: ARRAY OF CHAR);
		VAR identifier: Identifier;
		BEGIN
			COPY (module, identifier); FixIdentifier (identifier, backend.style); writer.String (identifier); writer.Char ('_');
			COPY (procedure, identifier); FixIdentifier (identifier, backend.style); writer.String (identifier);
			writer.Char (' '); writer.Char ('(');
		END BeginRuntimeCall;

		PROCEDURE EndRuntimeCall;
		BEGIN
			writer.Char (')'); writer.Char (';');
		END EndRuntimeCall;

		PROCEDURE Trace (expression: SyntaxTree.Expression);
		VAR name: Identifier; printer: Printout.Printer; pos: LONGINT;
		BEGIN
			BeginRuntimeCall (backend.traceModule, "String"); writer.Char ('"'); pos := writer.Pos ();
			currentProcedureScope.ownerModule.GetName (name); writer.String (name); writer.Char ('@');
			writer.Int (expression.position, 0); writer.Char (':'); writer.Char (' ');
			printer := Printout.NewPrinter (writer, Printout.SourceCode, FALSE);
			printer.Expression (expression); writer.Char (' '); writer.Char ('=');
			writer.Char (' '); writer.Char ('"'); writer.Char (','); writer.Char (' ');
			writer.Int (writer.Pos () - pos - 3, 0); EndRuntimeCall;

			IF (expression.type.resolved IS SyntaxTree.IntegerType) OR (expression.type.resolved IS SyntaxTree.SizeType) THEN
				BeginRuntimeCall (backend.traceModule, "Int");
				PrintExpression (expression); writer.String (", 0"); EndRuntimeCall;
			ELSIF expression.type.resolved IS SyntaxTree.BooleanType THEN
				BeginRuntimeCall (backend.traceModule, "Boolean");
				PrintExpression (expression); EndRuntimeCall;
			ELSIF expression.type.resolved IS SyntaxTree.SetType THEN
				BeginRuntimeCall (backend.traceModule, "Bits");
				PrintExpression (expression); writer.String (", 0, ");
				writer.Int (expression.type.resolved.sizeInBits, 0); EndRuntimeCall;
			ELSIF expression.type.resolved IS SyntaxTree.CharacterType THEN
				BeginRuntimeCall (backend.traceModule, "Char");
				PrintExpression (expression); EndRuntimeCall;
			ELSIF (expression.type.resolved IS SyntaxTree.AddressType) OR (expression.type.resolved IS SyntaxTree.PointerType) THEN
				BeginRuntimeCall (backend.traceModule, "Address");
				PrintExpression (expression); EndRuntimeCall;
			ELSE
				HALT (200);
			END;

			BeginRuntimeCall (backend.traceModule, "Ln"); EndRuntimeCall;
		END Trace;

		PROCEDURE Convert (expression: SyntaxTree.Expression; type: SyntaxTree.Type);
		BEGIN
				IF (expression.type.resolved # type.resolved) & (type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType) & (expression.type.resolved IS SyntaxTree.PointerType) THEN
					writer.Char ('('); PrintType (FALSE, expression.type.resolved, ""); writer.Char (')'); writer.Char (Space);
				END;
				PrintExpression (expression);
		END Convert;

		PROCEDURE LockScope (scope: SyntaxTree.Scope);
		VAR name: Identifier;
		BEGIN
			PrintIndent; writer.String ("LockObject (&");
			IF scope IS SyntaxTree.RecordScope THEN
				PrintSelf; writer.String ("->record");
				AccessBase (scope(SyntaxTree.RecordScope).ownerRecord, NIL);
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				GetScopeName (scope, name, backend.style);
				writer.String (name); writer.String (StructTag);
			END;
			writer.Char (')'); writer.Char (Semicolon); writer.Ln;
		END LockScope;

		PROCEDURE UnlockScope (scope: SyntaxTree.Scope);
		VAR name: Identifier;
		BEGIN
			IF scope IS SyntaxTree.RecordScope THEN
				PrintIndent; writer.String ("UnlockObject (&"); PrintSelf; writer.String ("->record");
				AccessBase (scope(SyntaxTree.RecordScope).ownerRecord, NIL);
				writer.Char (')'); writer.Char (Semicolon); writer.Ln;
			ELSIF scope IS SyntaxTree.ModuleScope THEN
				GetScopeName (scope, name, backend.style); PrintIndent; writer.String ("UnlockObject (&"); writer.String (name); writer.String (StructTag); writer.Char (')'); writer.Char (Semicolon); writer.Ln;
			END;
		END UnlockScope;

		PROCEDURE CompareTypeDescriptor (expression: SyntaxTree.Expression; type: SyntaxTree.Type);
		VAR name: Identifier;
		BEGIN
			writer.String ("IsBase (");
			IF expression.type.resolved IS SyntaxTree.PointerType THEN
				PrintExpression (expression); writer.String ("->"); writer.String (TypeDescriptorTag);
				IF ~type.resolved(SyntaxTree.PointerType).pointerBase.resolved(SyntaxTree.RecordType).isObject THEN
					type := type.resolved(SyntaxTree.PointerType).pointerBase.resolved;
				END;
			ELSIF (expression.type.resolved IS SyntaxTree.AnyType) THEN
				writer.String ("(*(void**) "); PrintExpression (expression); writer.Char (')');
			ELSIF expression.type.resolved IS SyntaxTree.RecordType THEN
				IF (expression IS SyntaxTree.SymbolDesignator) & (expression(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
					GetSymbolName (expression(SyntaxTree.SymbolDesignator).symbol, name, backend.style); writer.String (name);
				ELSE
					PrintType (FALSE, expression.type, "");
				END;
				writer.String (TypeDescriptorTag);
			ELSIF expression.type.resolved IS SyntaxTree.ObjectType THEN
				PrintExpression (expression); writer.String ("->"); writer.String (TypeDescriptorTag);
			END;
			writer.String (", &"); GetSymbolName (type.resolved.typeDeclaration, name, backend.style);
			writer.String (name); writer.String (TypeDescriptorTag); writer.String (')');
		END CompareTypeDescriptor;

		PROCEDURE PrintIndent;
		VAR indent: Indent;
		BEGIN indent := SELF.indent; WHILE indent > 0 DO writer.Char (Tab); DEC (indent); END;
		END PrintIndent;

		PROCEDURE PrintInclude (CONST filename: ARRAY OF CHAR);
		BEGIN writer.String ('#include "'); writer.String (filename); writer.String ('"'); writer.Ln;
		END PrintInclude;

		PROCEDURE PrintComment (CONST comment: ARRAY OF CHAR);
		VAR i, len: LONGINT; ch: CHAR; pragma: BOOLEAN;
		BEGIN
			IF Strings.StartsWith2("#pragma", comment) THEN
				pragma := TRUE
			ELSE pragma := FALSE
			END;

			PrintIndent;
			IF ~pragma THEN writer.String("/*") END;
 			i := 0; len := LEN (comment);
			LOOP
				ch := comment[i]; INC (i);
				IF (i = len) OR (ch = 0X) THEN EXIT END;
				IF ch = 0AX THEN writer.Ln; PrintIndent;
				ELSIF ch # 0DX THEN writer.Char(ch) END;
			END;
			IF ~pragma THEN writer.String("*/") END;
			writer.Ln;
		END PrintComment;

		PROCEDURE PrintComments (comment: SyntaxTree.Comment; item: OBJECT);
		BEGIN
			WHILE (comment # NIL) & (comment.item = item) DO
				PrintComment (comment.source^);
				comment := comment.nextComment;
			END;
		END PrintComments;

		PROCEDURE PrintProcedure (procedure: SyntaxTree.Procedure);
		VAR name: Identifier; procedureType: SyntaxTree.ProcedureType;
		BEGIN
			GetSymbolName (procedure, name, backend.style); procedureType := procedure.type(SyntaxTree.ProcedureType);
			PrintType (FALSE, procedureType.returnType, name);
			PrintParameters (procedureType, procedure.scope);
			ASSERT ((procedureType.returnType = NIL) OR (~IsDelegate (procedureType.returnType.resolved)));
		END PrintProcedure;

		PROCEDURE PrintParameter (symbol: SyntaxTree.Symbol; nested: BOOLEAN);
		VAR name: Identifier; type: SyntaxTree.Type; index: LONGINT;
		BEGIN
			GetSymbolName (symbol, name, backend.style); type := symbol.type;
			PrintVariable (IsVarParameter (symbol) & ~IsOpenArray (type) OR nested, name, type);
			IF type.resolved IS SyntaxTree.RecordType THEN
				writer.String (", void* "); writer.String (name); writer.String (TypeDescriptorTag);
			END;
			index := 0;
			WHILE IsOpenArray (type) DO
				writer.String (", int "); writer.String (name); writer.String (LenTag);
				writer.Int (index, 0); type := type(SyntaxTree.ArrayType).arrayBase; INC (index);
			END;
			IF IsDelegate (type.resolved) THEN
				writer.Char (Comma); writer.Char (Space); writer.String (BaseObjectName); writer.Char ('*');
				writer.Char (' '); writer.String (name); writer.String (DelegateTag);
			END;
		END PrintParameter;

		PROCEDURE PrintParameters (procedureType: SyntaxTree.ProcedureType; scope: SyntaxTree.Scope);
		VAR first: BOOLEAN; name: Identifier; outerScope: SyntaxTree.Scope;
		VAR parameter: SyntaxTree.Parameter; variable: SyntaxTree.Variable;
		BEGIN
			writer.Char (Space); writer.Char ('('); first := TRUE;
			parameter := procedureType.firstParameter;
			WHILE parameter # NIL DO
				IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
				PrintParameter (parameter, FALSE);
				parameter := parameter.nextParameter;
			END;
			outerScope := scope;
			WHILE (outerScope # NIL) & (outerScope IS SyntaxTree.ProcedureScope) DO
				parameter := outerScope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
				WHILE parameter # NIL DO
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					PrintParameter (parameter, TRUE);
					parameter := parameter.nextParameter;
				END;
				variable := outerScope.firstVariable;
				WHILE variable # NIL DO
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					PrintParameter (variable, TRUE);
					variable := variable.nextVariable;
				END;
				outerScope := outerScope.outerScope;
			END;
			IF IsDelegate (procedureType.resolved) & (scope = NIL) THEN
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					writer.String (BaseObjectName); writer.Char ('*'); writer.Char (' ');
					writer.String (name); writer.String (DelegateTag);
			END;
			WHILE scope # NIL DO
				IF scope IS SyntaxTree.RecordScope THEN
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					PrintType (FALSE, scope(SyntaxTree.RecordScope).ownerRecord, ""); writer.Char (Space); PrintSelf; scope := NIL;
				ELSE
					scope := scope.outerScope;
				END;
			END;
			writer.Char (')');
		END PrintParameters;

		PROCEDURE PrintArgument (argument: SyntaxTree.Expression; parameter: SyntaxTree.Symbol; nested: BOOLEAN);
		VAR argumentType, parameterType: SyntaxTree.Type; index: LONGINT; name: Identifier; isEmptyRecord: BOOLEAN;
		BEGIN
			parameterType := parameter.type; index := 0;
			IF argument = NIL THEN argumentType := parameterType.resolved ELSE argumentType := argument.type.resolved END;
			isEmptyRecord := (parameterType.resolved IS SyntaxTree.RecordType) & IsEmptyRecord (parameterType.resolved(SyntaxTree.RecordType));
			IF IsVarParameter (parameter) & ~IsOpenArray(parameterType) & ~(argumentType.resolved IS SyntaxTree.StringType) OR nested THEN
				IF isEmptyRecord THEN writer.Char ('0'); ELSE writer.Char ('&');
				END;
			ELSIF IsOpenArray (parameterType) & (parameterType(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType) THEN
				writer.String ("*("); PrintType (TRUE, argumentType, ""); writer.String (") &");
			END;
			IF ~isEmptyRecord THEN
				IF argument = NIL THEN GetSymbolName (parameter, name, backend.style); writer.String (name) ELSE PrintExpression (argument) END;
			END;
			IF parameterType.resolved IS SyntaxTree.RecordType THEN
				IF ~isEmptyRecord THEN
					AccessBase (argumentType(SyntaxTree.RecordType), parameterType.resolved(SyntaxTree.RecordType));
				END;
				writer.Char (Comma); writer.Char (Space);
				IF (argument # NIL) & (argument IS SyntaxTree.SymbolDesignator) & (argument(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
					GetSymbolName (argument(SyntaxTree.SymbolDesignator).symbol, name, backend.style);
					writer.String(name); writer.String (TypeDescriptorTag);
				ELSE
					writer.Char ('&'); PrintType (FALSE, argumentType, ""); writer.String (TypeDescriptorTag);
				END;
			END;
			WHILE IsOpenArray (parameterType) DO
				writer.Char (Comma); writer.Char (Space);
				IF argument = NIL THEN
					GetSymbolName (parameter, name, backend.style); writer.String (name);
					writer.String (LenTag); writer.Int (index, 0);
				ELSIF argumentType IS SyntaxTree.StringType THEN
					writer.Int (argumentType(SyntaxTree.StringType).length, 0);
				ELSIF parameterType(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.ByteType THEN
					writer.String ("sizeof ("); PrintType (FALSE, argumentType, ""); writer.Char (')');
				ELSIF ~IsOpenArray (argumentType) THEN
					writer.Int (argumentType(SyntaxTree.ArrayType).staticLength, 0);
					ASSERT (argumentType IS SyntaxTree.ArrayType);
					ASSERT (argumentType(SyntaxTree.ArrayType).arrayBase # NIL);
					argumentType := argumentType(SyntaxTree.ArrayType).arrayBase.resolved;
				ELSIF (argument IS SyntaxTree.SymbolDesignator) & (argument(SyntaxTree.SymbolDesignator).symbol IS SyntaxTree.Parameter) THEN
					PrintExpression (argument); writer.String (LenTag); writer.Int (index, 0);
				ELSIF argument IS SyntaxTree.DereferenceDesignator THEN
					PrintExpression (argument(SyntaxTree.DereferenceDesignator).left);
					writer.String ("->length["); writer.Int (index, 0); writer.Char (']');
				END;
				parameterType := parameterType(SyntaxTree.ArrayType).arrayBase; INC (index);
			END;
			IF IsDelegate (parameterType.resolved) THEN
				writer.Char (Comma); writer.Char (Space); PrintDelegate (argument);
			END;
		END PrintArgument;

		PROCEDURE PrintArguments (arguments: SyntaxTree.ExpressionList; index, count: LONGINT; parameter: SyntaxTree.Parameter; outerScope: SyntaxTree.Scope): BOOLEAN;
		VAR first: BOOLEAN; variable: SyntaxTree.Variable;
		BEGIN
			first := TRUE;
			WHILE count # 0 DO
				IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
				PrintArgument (arguments.GetExpression (index), parameter, FALSE);
				INC (index); DEC (count); parameter := parameter.nextParameter;
 			END;
			WHILE (outerScope # NIL) & (outerScope IS SyntaxTree.ProcedureScope) DO
 				parameter := outerScope(SyntaxTree.ProcedureScope).ownerProcedure.type(SyntaxTree.ProcedureType).firstParameter;
 				WHILE parameter # NIL DO
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					PrintArgument (NIL, parameter, outerScope = currentProcedureScope);
					parameter := parameter.nextParameter;
				END;
  				variable := outerScope.firstVariable;
 				WHILE variable # NIL DO
					IF first THEN first := FALSE ELSE writer.Char (Comma); writer.Char (Space); END;
					PrintArgument (NIL, variable, outerScope = currentProcedureScope);
					variable := variable.nextVariable;
				END;
 				outerScope := outerScope.outerScope;
			END;
			RETURN first;
		END PrintArguments;

		PROCEDURE PrintSelf;
		VAR self: Identifier;
		BEGIN
			IF backend.style = StailaStyle THEN writer.String ("_this");
			ELSE Basic.GetString(Global.SelfParameterName,self); FixIdentifier (self, backend.style); writer.String (self); END;
		END PrintSelf;

		PROCEDURE PrintDelegate (expression: SyntaxTree.Expression);
		VAR designator: SyntaxTree.SymbolDesignator;
		BEGIN
			IF IsDelegate (expression.type.resolved) & (expression IS SyntaxTree.SymbolDesignator) THEN
				designator := expression(SyntaxTree.SymbolDesignator);
				IF (designator.left # NIL) & (designator.symbol IS SyntaxTree.Procedure) THEN
					PrintExpression (designator.left(SyntaxTree.DereferenceDesignator).left);
				ELSE
					PrintExpression (designator); writer.String (DelegateTag);
				END;
			ELSE
				writer.Char ('0');
			END;
		END PrintDelegate;

		PROCEDURE PrintBody (procedure: SyntaxTree.Procedure; body: SyntaxTree.Body; variable: SyntaxTree.Variable);
		VAR name: Identifier;
		BEGIN
			BeginBlock;
			WHILE variable # NIL DO
				GetSymbolName (variable, name, backend.style);
				PrintIndent; PrintVariable (FALSE, name, variable.type);
				IF initializeLocalData THEN
					IF variable.type.resolved IS SyntaxTree.ArrayType THEN
						writer.String (" = {0}");
					ELSIF variable.type.resolved IS SyntaxTree.RecordType THEN
						IF ~IsEmptyRecord (variable.type.resolved(SyntaxTree.RecordType)) THEN writer.String (" = {0}") END;
					ELSE
						writer.String (" = 0");
					END;
				END;
				writer.Char (Semicolon); writer.Ln;
				IF IsDelegate (variable.type.resolved) THEN
					PrintIndent; writer.String (BaseObjectName); writer.Char ('*'); writer.Char (' ');
					writer.String (name); writer.String (DelegateTag);
					IF initializeLocalData THEN writer.String (" = 0") END;
					writer.Char (Semicolon); writer.Ln;
				END;
				variable := variable.nextVariable;
			END;
			IF body # NIL THEN
				IF body.code # NIL THEN
					PrintCode (body.code);
				ELSE
					currentProcedureScope := body.inScope;
					IF procedure = procedure.procedureScope.ownerModule.moduleScope.bodyProcedure THEN
						GetScopeName (procedure.procedureScope.ownerModule.moduleScope, name, backend.style); PrintIndent; writer.String ("InitObject (&");
						writer.String (name); writer.String (StructTag); writer.Char (')'); writer.Char (Semicolon); writer.Ln;
					END;
					PrintStatement (body);
					IF body.isActive THEN
						PrintIndent; writer.String ("Objects_Terminate ();"); writer.Ln;
					END;
				END;
			END;
			EndBlock;
		END PrintBody;

		PROCEDURE PrintType (pointer: BOOLEAN; type: SyntaxTree.Type; CONST name: ARRAY OF CHAR);

			PROCEDURE Prefix (type: SyntaxTree.Type);
			VAR temp: Identifier;
			BEGIN
				IF type = NIL THEN writer.String ("void");
				ELSIF type IS SyntaxTree.ArrayType THEN Prefix (type(SyntaxTree.ArrayType).arrayBase);
				ELSIF type IS SyntaxTree.PointerType THEN
					writer.String ("struct ");
					IF type(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.ArrayType THEN
						writer.String ("Array");
					ELSE
						GetSymbolName (type(SyntaxTree.PointerType).pointerBase.resolved.typeDeclaration, temp, backend.style);
						writer.String (temp);
					END;
					writer.String (PointerTag); writer.String (" (*");
				ELSIF type IS SyntaxTree.ProcedureType THEN Prefix (type(SyntaxTree.ProcedureType).returnType);
				ELSIF type.resolved.typeDeclaration # NIL THEN GetSymbolName (type.resolved.typeDeclaration, temp, backend.style); writer.String (temp);
				ELSIF type.resolved IS SyntaxTree.ObjectType THEN writer.String ("ObjectType");
				ELSE PrintBasicType (type.resolved(SyntaxTree.BasicType)); END;
				IF name # "" THEN writer.Char (Space) END;
			END Prefix;

			PROCEDURE Infix (type: SyntaxTree.Type);
			BEGIN
				IF type = NIL THEN IF pointer THEN writer.Char ('('); writer.Char ('*'); writer.String (name); writer.Char (')') ELSE writer.String (name) END
				ELSIF type IS SyntaxTree.ArrayType THEN Infix (type(SyntaxTree.ArrayType).arrayBase);
				ELSIF type IS SyntaxTree.PointerType THEN Infix (type(SyntaxTree.PointerType).pointerBase);
				ELSIF type IS SyntaxTree.ProcedureType THEN writer.Char ('('); writer.Char ('*'); IF pointer THEN writer.Char ('*') END; writer.String (name);
				ELSE IF pointer THEN writer.Char ('('); writer.Char ('*'); writer.String (name); writer.Char (')') ELSE writer.String (name) END
				END;
			END Infix;

			PROCEDURE Postfix (type: SyntaxTree.Type);
			BEGIN
				IF type = NIL THEN
				ELSIF type IS SyntaxTree.ArrayType THEN
					ASSERT (~IsDelegate (type(SyntaxTree.ArrayType).arrayBase.resolved));
					writer.Char ('['); IF type(SyntaxTree.ArrayType).staticLength # 0 THEN writer.Int (type(SyntaxTree.ArrayType).staticLength, 0); END; writer.Char (']');
					Postfix (type(SyntaxTree.ArrayType).arrayBase);
				ELSIF type IS SyntaxTree.PointerType THEN writer.Char (')');
				ELSIF type IS SyntaxTree.ProcedureType THEN writer.Char (')'); PrintParameters (type(SyntaxTree.ProcedureType), NIL);
				END;
			END Postfix;

		BEGIN
			Prefix (type); Infix (type); Postfix (type);
		END PrintType;

		PROCEDURE PrintBasicType (type: SyntaxTree.BasicType);
		VAR i: LONGINT;
		BEGIN
			IF type IS SyntaxTree.AddressType THEN
				writer.String ("size_t");
			ELSIF type IS SyntaxTree.SizeType THEN
				writer.String ("size_t");
			ELSIF type IS SyntaxTree.ByteType THEN
				IF type.sizeInBits = 8 THEN
					IF backend.style = StailaStyle THEN writer.String ("int8_t") ELSE writer.String ("Byte") END;
				ELSE
					HALT (1234);
				END;
			ELSIF type IS SyntaxTree.CharacterType THEN
				IF type.sizeInBits = 8 THEN
					IF backend.style = StailaStyle THEN writer.String ("char") ELSE writer.String ("Char") END;
				ELSE
					HALT (1234);
				END;
			ELSIF type IS SyntaxTree.BooleanType THEN
					IF backend.style = StailaStyle THEN writer.String ("bool") ELSE writer.String ("Boolean") END;
			ELSIF type IS SyntaxTree.IntegerType THEN
				IF type.sizeInBits = 8 THEN
					IF backend.style = StailaStyle THEN writer.String ("int8_t") ELSE writer.String ("ShortInt") END;
				ELSIF type.sizeInBits = 16 THEN
					IF backend.style = StailaStyle THEN writer.String ("int16_t") ELSE writer.String ("Integer") END;
				ELSIF type.sizeInBits = 32 THEN
					IF backend.style = StailaStyle THEN writer.String ("int32_t") ELSE writer.String ("LongInt") END;
				ELSIF type.sizeInBits = 64 THEN
					IF backend.style = StailaStyle THEN writer.String ("int64_t") ELSE writer.String ("HugeInt") END;
				ELSE
					HALT (1234);
				END;
			ELSIF type IS SyntaxTree.FloatType THEN
				IF type.sizeInBits = 32 THEN
					IF backend.style = StailaStyle THEN writer.String ("float") ELSE writer.String ("Real") END;
				ELSIF type.sizeInBits = 64 THEN
					IF backend.style = StailaStyle THEN writer.String ("double") ELSE writer.String ("LongReal") END;
				ELSE
					HALT (1234);
				END;
			ELSIF type IS SyntaxTree.SetType THEN
				IF type.sizeInBits = backend.addressSize THEN
					IF backend.style = StailaStyle THEN writer.String ("size_t") ELSE writer.String ("Set") END;
				ELSE
					HALT (1234);
				END;
			ELSIF type IS SyntaxTree.NilType THEN
				writer.String ("void*");
			ELSIF type IS SyntaxTree.AnyType THEN
				writer.String ("void*");
			ELSE
				HALT (1234);
			END;
		END PrintBasicType;

		PROCEDURE PrintVariable (variable: BOOLEAN; CONST name: ARRAY OF CHAR; type: SyntaxTree.Type);
		BEGIN PrintType (variable, type, name);
		END PrintVariable;

		PROCEDURE PrintCharacter (value: CHAR);
		BEGIN
			writer.Char ("'");
			IF value = "'" THEN
				writer.String ("\'");
			ELSIF (ORD (value) >= 32) & (ORD (value) < 127) THEN
				writer.Char (value);
			ELSE
				writer.String ("\x"); writer.Hex (ORD (value), 0);
			END;
			writer.Char ("'");
		END PrintCharacter;

		PROCEDURE PrintNew (arguments: SyntaxTree.ExpressionList);
		VAR designator: SyntaxTree.Expression; type: SyntaxTree.Type; name: Identifier;
		VAR procedure: SyntaxTree.Procedure; recordType: SyntaxTree.RecordType; first: BOOLEAN;
		BEGIN
			designator := arguments.GetExpression (0);
			type := designator.type.resolved(SyntaxTree.PointerType).pointerBase.resolved;
			IF (type IS SyntaxTree.ArrayType) & (arguments.Length () > 1) THEN
				ASSERT (arguments.Length () = 2);
				ASSERT (type(SyntaxTree.ArrayType).staticLength = 0);
				PrintExpression (designator); writer.String (" = ("); PrintType (FALSE, designator.type, "");
				writer.String (") calloc (1, "); PrintExpression (arguments.GetExpression (1)); writer.String (" * sizeof (");
				PrintType (FALSE, type(SyntaxTree.ArrayType).arrayBase, ""); writer.String (") + sizeof (struct Array_pointer))");
				writer.Char (Semicolon); writer.Ln; PrintIndent; PrintExpression (designator);
				writer.String ("->length[0] = "); PrintExpression (arguments.GetExpression (1)); writer.Char (Semicolon);
			ELSE
				PrintExpression (designator); writer.String (" = ("); PrintType (FALSE, designator.type, "");
				writer.String (") calloc (1, sizeof (struct "); PrintType (FALSE, type, ""); writer.String (PointerTag); writer.String ("))");
			END;
			IF type IS SyntaxTree.RecordType THEN
				recordType := type(SyntaxTree.RecordType);
				GetSymbolName (recordType.typeDeclaration, name, backend.style);
				writer.Char (Semicolon); writer.Ln; PrintIndent; PrintExpression (designator); writer.String ("->"); writer.String (TypeDescriptorTag); writer.String (" = &"); writer.String (name); writer.String (TypeDescriptorTag);
				IF recordType.isObject THEN
					writer.Char (Semicolon); writer.Ln; PrintIndent; writer.String ("InitObject (&"); PrintExpression (designator);
					writer.String ("->record"); AccessBase (recordType, NIL); writer.Char (')');
				END;
				procedure := GetConstructor (recordType);
				IF procedure # NIL THEN
					GetSymbolName (procedure, name, backend.style);
					writer.Char (Semicolon); writer.Ln; PrintIndent; writer.String (name); writer.String (" (");
					first := PrintArguments (arguments, 1, arguments.Length () - 1, procedure.type(SyntaxTree.ProcedureType).firstParameter, procedure.scope.outerScope);
					IF first THEN first := FALSE ELSE writer.String (", ") END; PrintExpression (designator); writer.Char (')');
				END;
				REPEAT
					procedure := recordType.recordScope.bodyProcedure;
					IF procedure # NIL THEN
						GetSymbolName (procedure, name, backend.style); writer.Char (Semicolon); writer.Ln; PrintIndent;
						IF procedure.procedureScope.body.isActive THEN
							writer.String ("Activate ((ObjectType) "); PrintExpression (designator);
							writer.String (", "); IF procedure.procedureScope.body.priority # NIL THEN PrintExpression (procedure.procedureScope.body.priority) ELSE writer.Char ('2') END;
							writer.String (", (void (*) (ObjectType)) "); writer.String (name); writer.Char (')');
						ELSE
							writer.String (name); writer.String (" ("); PrintExpression (designator); writer.Char (')');
						END;
					END;
					recordType := recordType.GetBaseRecord ();
				UNTIL recordType = NIL;
			END;
		END PrintNew;

		PROCEDURE PrintStatements (statements: SyntaxTree.StatementSequence);
		VAR i: LONGINT;
		BEGIN
			ASSERT (statements # NIL);
			FOR i := 0 TO statements.Length () - 1 DO PrintStatement (statements.GetStatement (i)); END;
		END PrintStatements;

		PROCEDURE PrintCode (code: SyntaxTree.Code);
		VAR text: Scanner.StringType; i: LONGINT;
		BEGIN
			PrintIndent; writer.String ("__asm ("); writer.Char ('"');
			text := code.sourceCode; i := 0;
			WHILE (text[i] # 0X) & (text[i] # 0AX) DO INC (i); END;
			IF text[i] # 0X THEN INC (i); END;
			WHILE text[i] # 0X DO
				IF text[i] = 0AX THEN
					writer.Char ('\'); writer.Char ('n'); writer.Char ('"'); writer.Char (Space);
					writer.Char ('\'); writer.Ln; INC (indent); PrintIndent; DEC (indent); writer.Char ('"');
				ELSE writer.Char (text[i]); END;
				INC (i);
			END;
			writer.Char ('"'); writer.Char (')'); writer.Char (Semicolon); writer.Ln;
		END PrintCode;

		PROCEDURE PrintIfPart (ifPart: SyntaxTree.IfPart);
		BEGIN
			ASSERT (ifPart # NIL);
			PrintComments (ifPart.comment, ifPart);
			writer.String ("if ("); PrintExpression (ifPart.condition); writer.Char (')'); writer.Ln;
			BeginBlock; PrintStatements (ifPart.statements); EndBlock;
		END PrintIfPart;

		PROCEDURE PrintStatement (statement: SyntaxTree.Statement);
		BEGIN
			ASSERT (statement # NIL);
			PrintComments (statement.comment, statement);
			statement.Accept (SELF);
		END PrintStatement;

		PROCEDURE PrintExpression (expression: SyntaxTree.Expression);
		BEGIN ASSERT (expression # NIL); expression.Accept (SELF);
		END PrintExpression;

		PROCEDURE PrintNegatedExpression (expression: SyntaxTree.Expression);
		BEGIN
			IF (expression IS SyntaxTree.UnaryExpression) & (expression(SyntaxTree.UnaryExpression).operator = Scanner.Not) THEN
				PrintExpression (expression(SyntaxTree.UnaryExpression).left);
			ELSE
				writer.Char ('!'); writer.Char ('('); PrintExpression (expression); writer.Char (')');
			END;
		END PrintNegatedExpression;

		PROCEDURE VisitAssignment* (statement: SyntaxTree.Assignment);
		BEGIN
			PrintIndent;
			IF IsEmptyString (statement.right.type) THEN
				PrintExpression (statement.left); writer.String ("[0] = 0");
			ELSIF IsStructuredType (statement.left.type) THEN
				ASSERT (~IsOpenArray (statement.left.type.resolved));
				writer.String ("memcpy (");
				IF ~(statement.left.type.resolved IS SyntaxTree.ArrayType) THEN writer.Char ('&'); END;
				PrintExpression (statement.left); writer.String (", ");
				IF ~(statement.right.type.resolved IS SyntaxTree.StringType) & ~(statement.right.type.resolved IS SyntaxTree.ArrayType) THEN writer.Char ('&'); END;
				PrintExpression (statement.right); writer.String (", sizeof ("); PrintType (FALSE, statement.left.type, ""); writer.String ("))");
			ELSE
				PrintExpression (statement.left); writer.Char (Space); writer.Char ('='); writer.Char (Space); Convert (statement.right, statement.left.type);
			END;
			writer.Char (Semicolon); writer.Ln;
			IF IsDelegate (statement.left.type.resolved) THEN
				PrintIndent; PrintExpression (statement.left); writer.String (DelegateTag);
				writer.String (" = "); PrintDelegate (statement.right); writer.Char (Semicolon); writer.Ln;
			END;
		END VisitAssignment;

		PROCEDURE VisitIfStatement* (statement: SyntaxTree.IfStatement);
		VAR i: LONGINT;
		BEGIN
			PrintIndent; PrintIfPart (statement.ifPart);
			FOR i := 0 TO statement.ElsifParts () - 1 DO
				PrintIndent; writer.String ("else "); PrintIfPart (statement.GetElsifPart (i));
			END;
			IF statement.elsePart # NIL THEN
				PrintIndent; writer.String ("else"); writer.Ln;
				BeginBlock; PrintStatements (statement.elsePart); EndBlock;
			END;
		END VisitIfStatement;

		PROCEDURE VisitWithStatement* (statement: SyntaxTree.WithStatement);
		VAR withPart: SyntaxTree.WithPart; i: LONGINT;
		BEGIN
			FOR i := 0 TO statement.WithParts () - 1 DO
				withPart := statement.GetWithPart (i); PrintIndent;
				IF i > 0 THEN writer.String ("else ") END;
				writer.String ("if ("); CompareTypeDescriptor (withPart.variable, withPart.type); writer.String (")"); writer.Ln;
				BeginBlock; PrintStatements (withPart.statements); EndBlock;
			END;
			PrintIndent;
			IF statement.elsePart = NIL THEN
				writer.String ("else ASSERT (false);"); writer.Ln;
			ELSE
				writer.String ("else"); writer.Ln;
				BeginBlock; PrintStatements (statement.elsePart); EndBlock;
			END;
		END VisitWithStatement;

		PROCEDURE VisitWhileStatement* (statement: SyntaxTree.WhileStatement);
		BEGIN
			PrintIndent; writer.String ("while ("); PrintExpression (statement.condition); writer.Char (')'); writer.Ln;
			BeginBlock; PrintStatements (statement.statements); EndBlock;
		END VisitWhileStatement;

		PROCEDURE VisitRepeatStatement* (statement: SyntaxTree.RepeatStatement);
		BEGIN
			PrintIndent; writer.String ("do"); writer.Ln;
			BeginBlock; PrintStatements (statement.statements); EndBlock;
			PrintIndent; writer.String ("while ("); PrintNegatedExpression (statement.condition); writer.String (");"); writer.Ln;
		END VisitRepeatStatement;

		PROCEDURE VisitLoopStatement* (statement: SyntaxTree.LoopStatement);
		BEGIN
			PrintIndent; writer.String ("for (;;)"); writer.Ln;
			BeginBlock; PrintStatements (statement.statements); EndBlock;
		END VisitLoopStatement;

		PROCEDURE VisitExitStatement* (statement: SyntaxTree.ExitStatement);
		BEGIN PrintIndent; writer.String ("break;"); writer.Ln;
		END VisitExitStatement;

		PROCEDURE VisitReturnStatement* (statement: SyntaxTree.ReturnStatement);
		CONST ResultVariable = "_result";
		VAR scope: SyntaxTree.ProcedureScope; locked: BOOLEAN;
		BEGIN
			scope := GetStatementProcedure (statement);
			locked := IsInExclusiveBlock (statement);
			IF statement.returnValue # NIL THEN
				IF locked THEN
					BeginBlock; PrintIndent; PrintVariable (FALSE, ResultVariable, statement.returnValue.type.resolved); writer.Char (Semicolon); writer.Ln;
					PrintIndent; writer.String (ResultVariable); writer.String (" = "); PrintExpression (statement.returnValue);
					writer.Char (Semicolon); writer.Ln; UnlockScope (scope.outerScope);
					PrintIndent; writer.String ("return "); writer.String (ResultVariable); writer.Char (Semicolon); writer.Ln; EndBlock;
				ELSE
					PrintIndent; writer.String ("return "); PrintExpression (statement.returnValue); writer.Char (Semicolon); writer.Ln;
				END
			ELSE
				IF locked THEN UnlockScope (scope.outerScope); END;
				PrintIndent; writer.String ("return"); writer.Char (Semicolon); writer.Ln;
			END;
		END VisitReturnStatement;

		PROCEDURE VisitStatementBlock* (statement: SyntaxTree.StatementBlock);
		VAR procedureScope: SyntaxTree.ProcedureScope;
		BEGIN
			procedureScope := GetStatementProcedure (statement);
			IF statement.outer # NIL THEN BeginBlock END;
			IF statement.isExclusive THEN LockScope (procedureScope.outerScope) END;
			PrintStatements (statement.statements);
			IF statement.isExclusive THEN UnlockScope (procedureScope.outerScope) END;
			IF statement.outer # NIL THEN EndBlock END;
		END VisitStatementBlock;

		PROCEDURE VisitAwaitStatement* (statement: SyntaxTree.AwaitStatement);
		VAR procedureScope: SyntaxTree.ProcedureScope; name: Identifier;
		BEGIN
			procedureScope := GetStatementProcedure (statement);
			PrintIndent; writer.String ("while ("); PrintNegatedExpression (statement.condition);
			writer.String (") "); writer.String ("AwaitCondition (&");
			IF procedureScope.outerScope IS SyntaxTree.RecordScope THEN
				PrintSelf; writer.String ("->record");
				AccessBase (procedureScope.outerScope(SyntaxTree.RecordScope).ownerRecord, NIL);
			ELSIF procedureScope.outerScope IS SyntaxTree.ModuleScope THEN
				GetScopeName (procedureScope.outerScope, name, backend.style);
				writer.String (name); writer.String (StructTag);
			END;
			writer.Char (')'); writer.Char (Semicolon); writer.Ln;
		END VisitAwaitStatement;

		PROCEDURE VisitCaseStatement* (statement: SyntaxTree.CaseStatement);
		VAR i, value: LONGINT; casePart: SyntaxTree.CasePart; caseConstant: SyntaxTree.CaseConstant;
		BEGIN
			PrintIndent; writer.String ("switch ("); PrintExpression (statement.variable); writer.Char (')'); writer.Ln;
			BeginBlock;
			FOR i := 0 TO statement.CaseParts () - 1 DO
				casePart := statement.GetCasePart (i);
				PrintComments (casePart.comment, casePart);
				caseConstant := casePart.firstConstant;
				WHILE caseConstant # NIL DO
					FOR value := caseConstant.min TO caseConstant.max DO
						IF (caseConstant = casePart.firstConstant) & (value = caseConstant.min) THEN DEC (indent); PrintIndent; INC (indent); ELSE writer.Char (Space); END;
						writer.String ("case "); writer.Int (value, 0); writer.Char (':');
					END;
					caseConstant := caseConstant.next;
				END;
				writer.Ln; PrintStatements (casePart.statements);
				PrintIndent; writer.String ("break;"); writer.Ln;
			END;
			DEC (indent); PrintIndent; INC (indent); writer.String ("default:"); writer.Ln;
			IF statement.elsePart = NIL THEN
				PrintIndent; writer.String ("ASSERT (false);"); writer.Ln;
			ELSE
				PrintStatements (statement.elsePart);
				PrintIndent; writer.String ("break;"); writer.Ln;
			END;
			EndBlock;
		END VisitCaseStatement;

		PROCEDURE VisitForStatement* (statement: SyntaxTree.ForStatement);
		BEGIN
			PrintIndent; writer.String ("for (");
			PrintExpression (statement.variable); writer.String (" = "); PrintExpression (statement.from); writer.String ("; "); PrintExpression (statement.variable);
			IF (statement.by # NIL) & (statement.by.resolved(SyntaxTree.IntegerValue).value < 0) THEN writer.String (" >= "); ELSE writer.String (" <= "); END;
			PrintExpression (statement.to); writer.String ("; "); PrintExpression (statement.variable); writer.String (" += ");
			IF statement.by = NIL THEN writer.Char ('1'); ELSE PrintExpression (statement.by); END;
			writer.Char (')'); writer.Ln; BeginBlock; PrintStatements (statement.statements); EndBlock;
		END VisitForStatement;

		PROCEDURE VisitProcedureCallStatement* (statement: SyntaxTree.ProcedureCallStatement);
		BEGIN PrintIndent; PrintExpression (statement.call); writer.Char (Semicolon); writer.Ln;
		END VisitProcedureCallStatement;

		PROCEDURE VisitSymbolDesignator* (expression: SyntaxTree.SymbolDesignator);
		VAR name: Identifier; recordType: SyntaxTree.RecordType;
		BEGIN
			recordType := NIL;
			IF (expression.left # NIL) & (expression.left.type.resolved # SyntaxTree.importType) THEN
				IF expression.left.type.resolved IS SyntaxTree.RecordType THEN
					recordType := expression.left.type.resolved(SyntaxTree.RecordType);
					IF expression.symbol IS SyntaxTree.Procedure THEN
						writer.String ("(("); GetSymbolName (recordType.typeDeclaration, name, backend.style); writer.String (name);  writer.String (TypeTag); writer.String ("*) ");
						PrintExpression (expression.left(SyntaxTree.DereferenceDesignator).left); writer.String ("->"); writer.String (TypeDescriptorTag); writer.String (")->");
						expression.symbol.GetName(name); FixIdentifier (name, backend.style); writer.String (name); RETURN;
					ELSE
						PrintExpression (expression.left);
						AccessBase (recordType, expression.symbol.scope(SyntaxTree.RecordScope).ownerRecord);
					END;
				ELSE
					PrintExpression (expression.left);
				END;
				writer.Char ('.');
			END;

			GetSymbolName (expression.symbol, name, backend.style);

			IF IsVarParameter (expression.symbol) & ~IsOpenArray (expression.type) OR
				((expression.symbol IS SyntaxTree.Parameter) OR (expression.symbol IS SyntaxTree.Variable)) &
				(expression.symbol.scope IS SyntaxTree.ProcedureScope) & (expression.symbol.scope # currentProcedureScope) THEN
				writer.Char ('('); writer.Char ('*'); writer.String (name); writer.Char (')');
			ELSE
				writer.String (name);
			END;
		END VisitSymbolDesignator;

		PROCEDURE VisitBuiltinCallDesignator* (expression: SyntaxTree.BuiltinCallDesignator);
		VAR argument: ARRAY 3 OF SyntaxTree.Expression; i: LONGINT; name: Identifier;
			position: LONGINT; typeDeclaration: SyntaxTree.TypeDeclaration;
		BEGIN
			FOR i := 0 TO LEN (argument) - 1 DO
				IF i < expression.parameters.Length () THEN argument[i] := expression.parameters.GetExpression (i); ELSE argument[i] := NIL; END;
			END;
			position := expression.position;
			CASE expression.id OF
			| Global.Incl: PrintExpression (argument[0]); writer.String (" |= 1 << ("); PrintExpression (argument[1]); writer.Char (')');
			| Global.Excl: PrintExpression (argument[0]); writer.String (" &= ~(1 << ("); PrintExpression (argument[1]); writer.Char (')'); writer.Char (')');
			| Global.Inc: PrintExpression (argument[0]); writer.String (" += "); PrintExpression (argument[1]);
			| Global.Dec: PrintExpression (argument[0]); writer.String (" -= "); PrintExpression (argument[1]);
			| Global.Assert: IF argument[0].resolved = NIL THEN writer.String ("ASSERT ("); PrintExpression (argument[0]); writer.Char (')') END;
			| Global.Halt, Global.systemHalt: writer.String ("ASSERT (false)");
			| Global.Ord: PrintExpression (argument[0]);
			| Global.Chr: PrintExpression (argument[0]);
			| Global.Short, Global.Long: writer.Char ('('); PrintType (FALSE, expression.type, ""); writer.Char (')'); writer.Char (Space); PrintExpression (argument[0]);
			| Global.Entier, Global.EntierH: writer.String ("floor ("); PrintExpression (argument[0]); writer.Char (')');
			| Global.Cap: writer.String ("Capitalize ("); PrintExpression (argument[0]); writer.Char (')');
			| Global.Odd: writer.Char ('('); PrintExpression (argument[0]); writer.String (" & 1)");
			| Global.Ash: writer.Char ('('); PrintExpression (argument[0]); IF IsNegative (argument[1]) THEN writer.String (" >> - ") ELSE writer.String (" << ") END; PrintExpression (argument[1]); writer.Char (')');
			| Global.Abs: IF (expression.type.resolved IS SyntaxTree.FloatType) THEN writer.Char ('f') END;
				writer.String ("abs ("); PrintExpression (argument[0]); writer.Char (')');
			| Global.Min, Global.Max: PrintExpression (expression.resolved);
			| Global.New: PrintNew (expression.parameters);
			| Global.Dispose: writer.String ("Dispose (&"); PrintExpression (argument[0]); writer.Char (')');
			| Global.Len:
				IF argument[0] IS SyntaxTree.DereferenceDesignator THEN PrintExpression (argument[0](SyntaxTree.DereferenceDesignator).left); writer.String ("->length[0]");
				ELSE PrintExpression (argument[0]); writer.String (LenTag); writer.Char ('0') END;
			| Global.Copy: writer.String ("strcpy ("); PrintExpression (argument[1]); writer.String (", "); PrintExpression (argument[0]); writer.Char (')');
			| Global.systemAdr: writer.String ("(("); PrintType (FALSE, backend.system.addressType, ""); writer.String (") &"); PrintExpression (argument[0]); writer.Char (')');
			| Global.systemGet: PrintExpression (argument[1]); writer.String (" = *(("); PrintType (TRUE, argument[1].type, ""); writer.String (") "); PrintExpression (argument[0]); writer.Char (')');
			| Global.systemGet8, Global.systemGet16, Global.systemGet32, Global.systemGet64:
				writer.String ("*(("); PrintType (TRUE, expression.type, ""); writer.String (") "); PrintExpression (argument[0]); writer.Char (')');
			| Global.systemPut, Global.systemPut8, Global.systemPut16, Global.systemPut32, Global.systemPut64:
				writer.String ("*(("); PrintType (TRUE, argument[1].type, ""); writer.String (") "); PrintExpression (argument[0]); writer.String (") = "); PrintExpression (argument[1]);
			| Global.systemMove: writer.String ("memcpy ("); PrintExpression (argument[1]); writer.String (", "); PrintExpression (argument[0]); writer.String (", "); PrintExpression (argument[2]); writer.Char (')');
			| Global.systemVal:
				IF (argument[1] IS SyntaxTree.SymbolDesignator) & (argument[1].resolved = NIL) THEN
					writer.String ("*(("); PrintType (TRUE, GetDeclaredType (argument[0]), ""); writer.String (") &"); PrintExpression (argument[1]); writer.Char (')');
				ELSE
					writer.String ("("); PrintType (FALSE, GetDeclaredType (argument[0]), ""); writer.String (") "); PrintExpression (argument[1]);
				END;
			| Global.Lsh: writer.Char ('('); PrintExpression (argument[0]); IF IsNegative (argument[1]) THEN writer.String (" >> - ") ELSE writer.String (" << ") END; PrintExpression (argument[1]); writer.Char (')');
			| Global.Rot: writer.String ("(("); PrintExpression (argument[0]); writer.String (" << "); PrintExpression (argument[1]); writer.String (") | (");
				PrintExpression (argument[0]); writer.String (" >> (sizeof ("); PrintType (FALSE, expression.type, ""); writer.String (") * 8 - "); PrintExpression (argument[1]); writer.String (")))");
			| Global.systemSize: writer.String ("sizeof ("); PrintType (FALSE, GetDeclaredType (argument[0]), ""); writer.Char (')');
			| Global.systemTypeCode: typeDeclaration := argument[0](SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration);
				IF typeDeclaration.declaredType.resolved IS SyntaxTree.PointerType THEN
					typeDeclaration := typeDeclaration.declaredType.resolved(SyntaxTree.PointerType).pointerBase.resolved.typeDeclaration;
				END;
				GetSymbolName (typeDeclaration, name, backend.style); writer.Char ('&'); writer.String (name); writer.String (TypeDescriptorTag);
			| Global.GetProcedure: PrintExpression (argument[2]); writer.String (" = 0");
			|Global.systemTrace: FOR i := 0 TO expression.parameters.Length () - 1 DO Trace (expression.parameters.GetExpression (i)) END;
			END;
		END VisitBuiltinCallDesignator;

		PROCEDURE VisitProcedureCallDesignator* (expression: SyntaxTree.ProcedureCallDesignator);
		VAR procedureType: SyntaxTree.ProcedureType; first: BOOLEAN;
		VAR symbolDesignator: SyntaxTree.SymbolDesignator; scope: SyntaxTree.Scope;
		BEGIN
			IF expression.left IS SyntaxTree.SymbolDesignator THEN
				symbolDesignator := expression.left(SyntaxTree.SymbolDesignator);
				IF symbolDesignator.symbol IS SyntaxTree.Procedure THEN
					scope := symbolDesignator.symbol.scope;
				END;
			ELSE
				symbolDesignator := NIL; scope := NIL;
			END;
			procedureType := expression.left.type.resolved(SyntaxTree.ProcedureType);
			PrintExpression (expression.left); writer.Char (Space); writer.Char ('(');
			first := PrintArguments (expression.parameters, 0, expression.parameters.Length (), procedureType.firstParameter, scope);
			IF (symbolDesignator # NIL) & IsMethod (symbolDesignator) THEN
				IF first THEN first := FALSE ELSE writer.String (", ") END;
				IF symbolDesignator.left # NIL THEN
					PrintExpression (symbolDesignator.left(SyntaxTree.DereferenceDesignator).left);
				ELSE
					PrintSelf;
				END;
			ELSIF expression.left IS SyntaxTree.SupercallDesignator THEN
				IF expression.parameters.Length () > 0 THEN writer.String (", ") END; PrintSelf;
			ELSIF IsDelegate (procedureType) THEN
				IF expression.parameters.Length () > 0 THEN writer.String (", ") END;
				PrintExpression (expression.left); writer.String (DelegateTag);
			END;
			writer.Char (')');
		END VisitProcedureCallDesignator;

		PROCEDURE VisitBooleanValue* (expression: SyntaxTree.BooleanValue);
		BEGIN IF expression.value THEN writer.Char ('1'); ELSE writer.Char ('0'); END;
		END VisitBooleanValue;

		PROCEDURE VisitIntegerValue* (expression: SyntaxTree.IntegerValue);
		BEGIN IF expression.value = expression.hvalue THEN writer.Int (expression.value, 0); ELSE writer.String ("0x"); writer.Hex (expression.hvalue, 0); END;
		END VisitIntegerValue;

		PROCEDURE VisitCharacterValue* (expression: SyntaxTree.CharacterValue);
		BEGIN PrintCharacter (expression.value);
		END VisitCharacterValue;

		PROCEDURE VisitSetValue* (expression: SyntaxTree.SetValue);
		VAR i: INTEGER; mask, value: HUGEINT;
		BEGIN
			mask := 1; value := 0;
			FOR i := MIN (SET) TO MAX (SET) DO IF i IN expression.value THEN INC (value, mask); END; INC (mask, mask); END;
			writer.String ("0x"); writer.Hex (value, 0);
		END VisitSetValue;

		PROCEDURE VisitRealValue* (expression: SyntaxTree.RealValue);
		BEGIN writer.FloatFix (expression.value, 0, 5, 0);
		END VisitRealValue;

		PROCEDURE VisitStringValue* (expression: SyntaxTree.StringValue);
		VAR char: CHAR; i: LONGINT;
		BEGIN
			writer.Char ('"'); i := 0;
			LOOP
				char := expression.value[i];
				IF char = 0X THEN EXIT END;
				IF char = '"' THEN writer.Char ('\') END;
				writer.Char (char); INC (i);
			END;
			writer.Char ('"');
		END VisitStringValue;

		PROCEDURE VisitNilValue* (expression: SyntaxTree.NilValue);
		BEGIN writer.Char ('0');
		END VisitNilValue;

		PROCEDURE VisitEnumerationValue* (expression: SyntaxTree.EnumerationValue);
		BEGIN writer.Int (expression.value, 0);
		END VisitEnumerationValue;

		PROCEDURE VisitUnaryExpression* (expression: SyntaxTree.UnaryExpression);
		BEGIN
			CASE expression.operator OF
			| Scanner.Plus:
			| Scanner.Minus: IF expression.type.resolved IS SyntaxTree.SetType THEN writer.Char ('~') ELSE writer.Char ('-') END;
			| Scanner.Not: writer.Char ('!');
			END;
			 PrintExpression (expression.left);
		END VisitUnaryExpression;

		PROCEDURE VisitTypeGuardDesignator* (expression: SyntaxTree.TypeGuardDesignator);
		VAR isRecord: BOOLEAN;
		BEGIN
			isRecord := expression.type.resolved IS SyntaxTree.RecordType;
			IF isRecord THEN writer.String ("(*") END;
			writer.String ("(ASSERT ("); CompareTypeDescriptor (expression.left, expression.type); writer.String ("), (");
			PrintType (isRecord, expression.type, ""); writer.String (") ");
			IF isRecord THEN writer.Char ('&') END;
			PrintExpression (expression.left); writer.Char (')');
			IF isRecord THEN writer.Char (')') END;
		END VisitTypeGuardDesignator;

		PROCEDURE VisitSupercallDesignator(expression: SyntaxTree.SupercallDesignator);
		VAR name: Identifier; procedure: SyntaxTree.Procedure;
		BEGIN
			procedure := expression.left(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.Procedure);
			GetSymbolName (procedure.super, name, backend.style); writer.String (name);
		END VisitSupercallDesignator;

		PROCEDURE VisitBinaryExpression* (expression: SyntaxTree.BinaryExpression);
		BEGIN
			IF expression.operator = Scanner.In THEN
				writer.String ("(("); PrintExpression (expression.right); writer.String (" >> ");
				PrintExpression (expression.left); writer.String (") & 1)"); RETURN;
			ELSIF expression.operator = Scanner.Is THEN
				CompareTypeDescriptor (expression.left, GetDeclaredType (expression.right));
				RETURN;
			END;
			writer.Char ('(');
			IF IsString (expression.left.type) THEN
				writer.String ("strcmp ("); PrintExpression (expression.left); writer.Char (Comma); writer.Char (Space); PrintExpression (expression.right); writer.Char (')');
			ELSE
				PrintExpression (expression.left);
			END;
			writer.Char (Space);
			CASE expression.operator OF
			| Scanner.Equal: writer.String ("==");
			| Scanner.Unequal: writer.String ("!=");
			| Scanner.Less: writer.String ("<");
			| Scanner.LessEqual: writer.String ("<=");
			| Scanner.Greater: writer.String (">");
			| Scanner.GreaterEqual: writer.String (">=");
			| Scanner.And: writer.String ("&&");
			| Scanner.Or: writer.String ("||");
			| Scanner.Plus: IF expression.type.resolved IS SyntaxTree.SetType THEN writer.Char ('|') ELSE writer.Char ('+') END;
			| Scanner.Minus: IF expression.type.resolved IS SyntaxTree.SetType THEN writer.Char ('&'); writer.Char ('~') ELSE writer.Char ('-') END;
			| Scanner.Times: IF expression.type.resolved IS SyntaxTree.SetType THEN writer.Char ('&') ELSE writer.Char ('*') END;
			| Scanner.Slash, Scanner.Div:  IF expression.type.resolved IS SyntaxTree.SetType THEN writer.Char ('^') ELSE writer.Char ('/') END;
			| Scanner.Mod: writer.Char ('%');
			END;
			writer.Char (Space);
			IF IsString (expression.left.type) THEN writer.Char ('0'); ELSE PrintExpression (expression.right); END; writer.Char (')');
		END VisitBinaryExpression;

		PROCEDURE VisitSelfDesignator* (expression: SyntaxTree.SelfDesignator);
		BEGIN PrintSelf;
		END VisitSelfDesignator;

		PROCEDURE VisitIndexDesignator* (expression: SyntaxTree.IndexDesignator);
		VAR i: LONGINT;
		BEGIN
			PrintExpression (expression.left);
			FOR i := 0 TO expression.parameters.Length () - 1 DO
				writer.Char ('[');
				PrintExpression (expression.parameters.GetExpression (i));
				writer.Char (']');
			END;
		END VisitIndexDesignator;

		PROCEDURE VisitConversion* (expression: SyntaxTree.Conversion);
		VAR e: SyntaxTree.Expression;
		BEGIN
			IF (expression.type IS SyntaxTree.CharacterType) & (expression.expression.type IS SyntaxTree.StringType) THEN
				PrintCharacter (expression.expression.resolved(SyntaxTree.StringValue).value[0]);
			ELSE
				PrintExpression (expression.expression);
			END;
		END VisitConversion;

		PROCEDURE VisitDereferenceDesignator* (expression: SyntaxTree.DereferenceDesignator);
		BEGIN
			IF expression.type IS SyntaxTree.ArrayType THEN
				writer.String ("(*("); PrintType (TRUE, expression.type, ""); writer.String (") &");
				PrintExpression (expression.left); writer.String ("->array)");
			ELSE
				PrintExpression (expression.left); writer.String ("->record");
			END;
		END VisitDereferenceDesignator;

		PROCEDURE VisitSet* (expression: SyntaxTree.Set);
		VAR i: LONGINT; element: SyntaxTree.Expression;
		BEGIN
			IF expression.elements.Length () = 0 THEN
				writer.Char ('0');
			ELSE
				writer.Char ('(');
				FOR i := 0 TO expression.elements.Length () - 1 DO
					IF i # 0 THEN writer.String (" | "); END;
					element := expression.elements.GetExpression (i);
					IF element IS SyntaxTree.RangeExpression THEN
						writer.String ("(("); PrintType (FALSE, backend.system.setType, ""); writer.String (") - 1 << "); PrintExpression (element(SyntaxTree.RangeExpression).first);
						writer.String (" & ~(("); PrintType (FALSE, backend.system.setType, ""); writer.String (") - 2 << "); PrintExpression (element(SyntaxTree.RangeExpression).last); writer.String ("))");
					ELSE
						writer.String ("1 << "); PrintExpression (element);
					END;
				END;
				writer.Char (')');
			END;
		END VisitSet;

	END Transpiler;

	TYPE TranspilerBackend*= OBJECT (Backend.Backend)
	VAR
		defineMain, declarations, initLocalData: BOOLEAN;
		addressSize: LONGINT; style: Style;
		traceModule: Identifier;

		PROCEDURE &InitTranspilerBackend;
		BEGIN InitBackend;
		END InitTranspilerBackend;

		PROCEDURE ProcessSyntaxTreeModule* (module: SyntaxTree.Module): Formats.GeneratedModule;
		VAR filename, pathname, fullname: Files.FileName; file: Files.File; writer: Files.Writer; transpiler: Transpiler;
		BEGIN
			Files.SplitPath (module.sourceName, pathname, filename); GetHeaderName (module, filename, style);
			IF pathname = "" THEN fullname := filename ELSE Files.JoinPath (pathname, filename, fullname) END;
			file := Files.New (fullname); Files.OpenWriter (writer, file, 0);
			Replace (filename, '.', '_'); Strings.UpperCase (filename); Strings.Append (filename, "_INCLUDED");
			writer.String ("#ifndef "); writer.String (filename); writer.Ln; writer.String ("#define "); writer.String (filename); writer.Ln; writer.Ln;
			writer.String ("/* C header file generated from '"); writer.String (module.sourceName); writer.String ("' */"); writer.Ln;
			NEW (transpiler, writer, SELF, initLocalData); transpiler.DeclareModule (module);
			writer.Ln; writer.String ("#endif /* "); writer.String (filename); writer.String (" */"); writer.Ln; writer.Update; Files.Register (file);
			IF declarations THEN RETURN NIL END; GetSourceName (module, filename, style);
			IF pathname = "" THEN fullname := filename ELSE Files.JoinPath (pathname, filename, fullname) END;
			file := Files.New (fullname); Files.OpenWriter (writer, file, 0);
			writer.String ("/* C source file generated from '"); writer.String (module.sourceName); writer.String ("' */"); writer.Ln;
			NEW (transpiler, writer, SELF, initLocalData); transpiler.DefineModule (module);
			IF defineMain THEN transpiler.DefineMain (module); END; writer.Update; Files.Register (file);
			RETURN NIL;
		END ProcessSyntaxTreeModule;

		PROCEDURE DefineOptions* (options: Options.Options);
		BEGIN DefineOptions^(options);
			options.Add(0X,"defineMain", Options.Flag);
			options.Add(0X,"declarations", Options.Flag);
			options.Add(0X,"addressSize", Options.Integer);
			options.Add(0X,"style", Options.String);
			options.Add(0X,"traceModule", Options.String);
			options.Add(0X,"noLocalInit", Options.Flag);
		END DefineOptions;

		PROCEDURE GetOptions* (options: Options.Options);
		VAR styleName: ARRAY 32 OF CHAR;
		BEGIN GetOptions^(options);
			defineMain := options.GetFlag ("defineMain");
			declarations := options.GetFlag ("declarations");
			IF ~options.GetInteger ("addressSize", addressSize) THEN addressSize := 32 END;
			IF ~options.GetString ("style", styleName) OR (styleName # "staila") THEN style := DefaultStyle ELSE style := StailaStyle END;
			IF ~options.GetString ("traceModule", traceModule) THEN traceModule := "KernelLog" END;
			initLocalData := ~options.GetFlag("noLocalInit");
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat* (): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get ();
		END DefaultSymbolFileFormat;

		PROCEDURE GetSystem*(): Global.System;
		VAR system: Global.System;
		BEGIN
			NEW(system, 8, 8, addressSize, 8, 32, 32, 32, 64,0, FALSE);
			Global.SetDefaultDeclarations(system,8);
			Global.SetDefaultOperators(system);
			RETURN system;
		END GetSystem;

	END TranspilerBackend;

	PROCEDURE AppendName (identifier: SyntaxTree.Identifier; VAR name: ARRAY OF CHAR; style: Style);
	VAR temp: Identifier;
	BEGIN Strings.Append (name, "_"); Basic.GetString(identifier,temp); Strings.Append (name, temp);
	END AppendName;

	PROCEDURE IsEmptyRecord (record: SyntaxTree.RecordType): BOOLEAN;
	BEGIN
		IF record.isObject OR (record.baseType # NIL) & ~IsEmptyRecord (record.GetBaseRecord ()) THEN RETURN FALSE END;
		RETURN record.recordScope.firstVariable = NIL;
	END IsEmptyRecord;

	PROCEDURE GetSymbolName (symbol: SyntaxTree.Symbol; VAR name: ARRAY OF CHAR; style: Style);
	BEGIN
		IF symbol IS SyntaxTree.Module THEN
			IF (symbol(SyntaxTree.Module).context # SyntaxTree.invalidIdentifier) & (symbol(SyntaxTree.Module).context # Global.A2Name) THEN
				Basic.GetString(symbol(SyntaxTree.Module).context,name); Strings.Append (name, "_"); AppendName (symbol.name, name, style);
			ELSE
				symbol.GetName(name);
			END;
		ELSIF symbol IS SyntaxTree.Parameter THEN
			symbol.GetName(name);
		ELSIF (symbol IS SyntaxTree.Variable) & ~(symbol.scope IS SyntaxTree.ModuleScope) THEN
			symbol.GetName(name);
		ELSE
			GetScopeName (symbol.scope, name, style); AppendName (symbol.name, name, style);
		END;
		FixIdentifier (name, style);
	END GetSymbolName;

	PROCEDURE GetScopeName (scope: SyntaxTree.Scope; VAR name: ARRAY OF CHAR; style: Style);
	BEGIN
		IF scope IS SyntaxTree.ProcedureScope THEN
			GetScopeName (scope.outerScope, name, style); AppendName (scope(SyntaxTree.ProcedureScope).ownerProcedure.name, name, style);
		ELSIF scope IS SyntaxTree.RecordScope THEN
			GetSymbolName (scope(SyntaxTree.RecordScope).ownerRecord.typeDeclaration, name, style);
		ELSIF scope IS SyntaxTree.ModuleScope THEN
			GetSymbolName (scope(SyntaxTree.ModuleScope).ownerModule, name, style);
		END;
	END GetScopeName;

	PROCEDURE GetSourceName (module: SyntaxTree.Module; VAR filename: Files.FileName; style: Style);
	BEGIN GetSymbolName (module, filename, style); Strings.Append (filename, ".c");
	END GetSourceName;

	PROCEDURE GetHeaderName (module: SyntaxTree.Module; VAR filename: Files.FileName; style: Style);
	BEGIN GetSymbolName (module, filename, style); Strings.Append (filename, ".h");
	END GetHeaderName;

	PROCEDURE GetConstructor (recordType: SyntaxTree.RecordType): SyntaxTree.Procedure;
	VAR constructor: SyntaxTree.Procedure; base: SyntaxTree.Type;
	BEGIN
		LOOP
			constructor := recordType.recordScope.constructor;
			IF constructor # NIL THEN RETURN constructor END;
			base := recordType.baseType;
			IF base = NIL THEN RETURN NIL END;
			IF base.resolved IS SyntaxTree.PointerType THEN
				base := base.resolved(SyntaxTree.PointerType).pointerBase;
			END;
			IF ~(base.resolved IS SyntaxTree.RecordType) THEN RETURN NIL END;
			recordType := base.resolved(SyntaxTree.RecordType);
		END;
	END GetConstructor;

	PROCEDURE GetStatementProcedure (statement: SyntaxTree.Statement): SyntaxTree.ProcedureScope;
	BEGIN WHILE statement.outer # NIL DO statement := statement.outer END; RETURN statement(SyntaxTree.Body).inScope;
	END GetStatementProcedure;

	PROCEDURE GetDeclaredType (expression: SyntaxTree.Expression): SyntaxTree.Type;
	BEGIN RETURN expression(SyntaxTree.SymbolDesignator).symbol(SyntaxTree.TypeDeclaration).declaredType;
	END GetDeclaredType;

	PROCEDURE IsMethod (expression: SyntaxTree.SymbolDesignator): BOOLEAN;
	VAR scope: SyntaxTree.Scope;
	BEGIN
		IF ~(expression.symbol IS SyntaxTree.Procedure) THEN RETURN FALSE END;
		scope := expression.symbol.scope;
		WHILE scope IS SyntaxTree.ProcedureScope DO scope := scope.outerScope END;
		RETURN scope IS SyntaxTree.RecordScope;
	END IsMethod;

	PROCEDURE IsVarParameter (symbol: SyntaxTree.Symbol): BOOLEAN;
	BEGIN RETURN (symbol IS SyntaxTree.Parameter) & ((symbol(SyntaxTree.Parameter).kind = SyntaxTree.VarParameter) OR (symbol(SyntaxTree.Parameter).kind = SyntaxTree.ConstParameter) & ~(symbol.type.resolved IS SyntaxTree.BasicType));
	END IsVarParameter;

	PROCEDURE IsInExclusiveBlock (statement: SyntaxTree.Statement): BOOLEAN;
	BEGIN
		WHILE statement # NIL DO
			IF (statement IS SyntaxTree.StatementBlock) & statement(SyntaxTree.StatementBlock).isExclusive THEN RETURN TRUE END;
			statement := statement.outer;
		END;
		RETURN FALSE;
	END IsInExclusiveBlock;

	PROCEDURE IsOpenArray (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).staticLength = 0);
	END IsOpenArray;

	PROCEDURE IsStaticArray (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type IS SyntaxTree.ArrayType) & (type(SyntaxTree.ArrayType).staticLength # 0);
	END IsStaticArray;

	PROCEDURE IsDelegate (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type IS SyntaxTree.ProcedureType) & type(SyntaxTree.ProcedureType).isDelegate;
	END IsDelegate;

	PROCEDURE IsStructuredType (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type.resolved IS SyntaxTree.ArrayType) OR (type.resolved IS SyntaxTree.RecordType);
	END IsStructuredType;

	PROCEDURE IsString (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type.resolved IS SyntaxTree.StringType) OR (type.resolved IS SyntaxTree.ArrayType) & (type.resolved(SyntaxTree.ArrayType).arrayBase.resolved IS SyntaxTree.CharacterType);
	END IsString;

	PROCEDURE IsEmptyString (type: SyntaxTree.Type): BOOLEAN;
	BEGIN RETURN (type.resolved IS SyntaxTree.StringType) & (type.resolved(SyntaxTree.StringType).length = 1);
	END IsEmptyString;

	PROCEDURE IsNegative (expression: SyntaxTree.Expression): BOOLEAN;
	BEGIN RETURN (expression.resolved # NIL) & (expression.resolved IS SyntaxTree.IntegerValue) & (expression.resolved(SyntaxTree.IntegerValue).value < 0);
	END IsNegative;

	PROCEDURE IsInlineAssemblyCode (procedure: SyntaxTree.Procedure): BOOLEAN;
	VAR type: SyntaxTree.ProcedureType; body: SyntaxTree.Body;
	BEGIN
		type := procedure.type(SyntaxTree.ProcedureType); body := procedure.procedureScope.body;
		RETURN (procedure.isInline) & (type.firstParameter = NIL) & (type.returnType = NIL) & (body # NIL) & (body.code # NIL);
	END IsInlineAssemblyCode;

	PROCEDURE GetRecordMethod (record: SyntaxTree.RecordType; method: LONGINT): SyntaxTree.Procedure;
	VAR base: SyntaxTree.RecordType; scope: SyntaxTree.RecordScope; procedure: SyntaxTree.Procedure;
	BEGIN
		scope := record.recordScope;
		LOOP
			procedure := scope.firstProcedure;
			WHILE (procedure # NIL) & (procedure.methodNumber #method) DO procedure := procedure.nextProcedure END;
			IF procedure # NIL THEN RETURN procedure END;
			base := scope.ownerRecord.GetBaseRecord ();
			scope := base.recordScope;
		END;
	END GetRecordMethod;

	PROCEDURE GetRecord (type: SyntaxTree.Type): SyntaxTree.RecordType;
	BEGIN
		IF type IS SyntaxTree.RecordType THEN RETURN type(SyntaxTree.RecordType)
		ELSIF type IS SyntaxTree.PointerType THEN
			type := type(SyntaxTree.PointerType).pointerBase.resolved;
			IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).pointerType # NIL) THEN RETURN type(SyntaxTree.RecordType) END;
		END;
		RETURN NIL;
	END GetRecord;

	PROCEDURE Replace (VAR string: ARRAY OF CHAR; replace, by: CHAR);
	VAR i: LONGINT; char: CHAR;
	BEGIN
		i := 0; char := string[0];
		WHILE char # 0X DO IF char = replace THEN string[i] := by; END; INC (i); char := string[i]; END;
	END Replace;

	PROCEDURE FixStailaIdentifier (VAR identifier: ARRAY OF CHAR);
	VAR i: LONGINT; previousLower: BOOLEAN;
	BEGIN
		i := 0; previousLower := FALSE;
		WHILE identifier[i] # 0X DO
			IF (ORD (identifier[i]) >= ORD ('A')) & (ORD (identifier[i]) <= ORD ('Z')) THEN
				IF previousLower THEN Strings.Insert ("_", identifier, i); INC (i) END;
				identifier[i] := Strings.LOW (identifier[i]); previousLower := FALSE;
			ELSE
				previousLower := (ORD (identifier[i]) >= ORD ('a')) & (ORD (identifier[i]) <= ORD ('z'));
			END;
			INC (i);
		END;
	END FixStailaIdentifier;

	PROCEDURE FixIdentifier (VAR identifier: ARRAY OF CHAR; style: Style);
	CONST Tag = '_';
	BEGIN
		Replace (identifier, '$', Tag); Replace (identifier, '@', Tag);
		(* IF style = StailaStyle THEN FixStailaIdentifier (identifier) END; *)
		IF (identifier = "int") OR (identifier = "return") OR (identifier = "enum") OR
			(identifier = "char") OR (identifier = "register") OR (identifier = "continue") THEN
				Strings.Append (identifier, Tag);
		END;
	END FixIdentifier;

	PROCEDURE Get* (): Backend.Backend;
	VAR backend: TranspilerBackend;
	BEGIN NEW(backend); RETURN backend;
	END Get;

END FoxTranspilerBackend.

SystemTools.Free FoxTranspilerBackend ~
Compiler.Compile -b=Transpiler Test.Mod ~
TextCompiler.CompileSelection -b=Transpiler  ~
TextCompiler.CompileSelection -b=Transpiler --defineMain  ~

	MODULE Test;
	VAR a: INTEGER;
	END Test.

FoxTest.Compile --options="-PC -G=Transpiler" --command="WinApplications.Run --hide cl /c Test.c" Oberon.Temp.Test Oberon.Temp.TranspilerTestDiff ~
FoxTest.Compile --options="--defineMain -PC -G=Transpiler" --command="WinApplications.Run --hide cl Test.c;WinApplications.Run --hide Test.exe" Oberon.Temp.Test Oberon.Temp.TranspilerTestDiff ~


