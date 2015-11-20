MODULE TFTypeSys; (** AUTHOR "tf"; PURPOSE "semantic representation"; *)
(* idea : contain complete program in an intermediate structure that fits for AO/C#/Java/Delphi.
	Inclusion of comments and line breaks allows pretty printing and source to source conversion *)

IMPORT
	Strings, Trace, TFStringPool, Files, Streams, Tar, KernelLog;

CONST
	TarBasedDB = FALSE;
	SymVersion = 6;

	TNone* = -1;
	TBasic* = 0;
	TAlias* = 1;
	TObject* = 2;
	TArray* = 3;
	TRecord* = 4;
	TPointer* = 5;
	TProcedure* = 6;

	BasicBoolean* = 0;
	BasicInt8* = 1;
	BasicInt16* = 2;
	BasicInt32* = 3;
	BasicInt64* = 4;
	BasicCard8* = 5;
	BasicCard16* = 6;
	BasicCard32* = 7;
	BasicCard64* = 8;
	BasicChar8* = 9;
	BasicChar16* = 10;
	BasicChar32* = 11;
	BasicReal32* = 12;
	BasicReal64* = 13;
	BasicNIL* = 14;
	BasicString* = 15;
	BasicSet* = 16;

	ExpressionIllegal* = -1;
	ExpressionPrimitive* = 0;
	ExpressionUnary* = 1;
	ExpressionBinary* = 2;
	ExpressionProcedure* = 3;
	ExpressionDesignator* = 4;

	IsParam* = 0;
	IsVarParam* = 1;
	IsConstParam* = 2;

	OpNegate* = 1;
	OpInvert* = 2;

	OpAdd* = 3;
	OpSub* = 4;
	OpOr* =5;

	OpMul* = 6;
	OpAnd* = 7;
	OpIntDiv* = 8;
	OpMod* = 9;
	OpDiv* = 10;

	OpEql* = 11;
	OpNeq* = 12;
	OpLss* = 13;
	OpLeq* = 14;
	OpGtr* = 15;
	OpGeq* = 16;
	OpIn* = 17;
	OpIs* = 18;

	StatementAssign* = 1;

	ExportReadWrite* = 0;
	ExportReadOnly* = 1;

TYPE
	String = Strings.String;

	Position* = RECORD
		valid* : BOOLEAN;
		a*, b* : LONGINT;
	END;

	Comment* = POINTER TO RECORD
		next* : Comment;
		pos* : Position;
		str* : String;
	END;

	Comments* = POINTER TO RECORD
		first*, last* : Comment;
	END;

	Expression* = POINTER TO RECORD
		kind*, op*, basicType* : LONGINT;
		intValue* : HUGEINT;
		strValue* : Strings.String;
		setValue* : Set;
		a*, b* : Expression;
		designator* : Designator; (* either a variable, field, array index, or procedure call *)
		eol* : BOOLEAN; (* end of line for code transformation only *)
		isConstant* : BOOLEAN;
		boolValue* : BOOLEAN;
	END;

	ExpressionList* = POINTER TO RECORD
		next* : ExpressionList;
		expression* : Expression;
	END;

	Designator* = POINTER TO RECORD
		next* : Designator;
	END;

	Set* = POINTER TO RECORD
		setRanges* : SetRange;
	END;

	SetRange* = POINTER TO RECORD
		next* : SetRange;
		a*, b* : Expression;
	END;

	Ident* = POINTER TO RECORD (Designator)
		name* : LONGINT;
		type* : Type;
		pos* : Position;
	END;

	Index* = POINTER TO RECORD(Designator)
		expressionList* : ExpressionList;
	END;

	Dereference* = POINTER TO RECORD(Designator)
	END;

	ActualParameters* = POINTER TO RECORD(Designator)
		expressionList* : ExpressionList;
	END;

	Statement* = POINTER TO RECORD
		next* : Statement;
		preComment*, postComment* : Comments;
	END;

	(*used to keep empty CASE ELSE alive because it is altering the meaning. Side-effect is to hang comments to empty statement sequences *)
	EmptyStatement* = POINTER TO RECORD(Statement)
	END;

	Assignment* = POINTER TO RECORD(Statement)
		designator* : Designator;
		expression* : Expression;
	END;

	ProcedureCall* = POINTER TO RECORD(Statement)
		designator* : Designator;
	END;

	IFStatement* = POINTER TO RECORD(Statement)
		expression* : Expression;
		then*, else* : Statement;
	END;

	WHILEStatement* = POINTER TO RECORD(Statement)
		expression* : Expression;
		statements* : Statement;
	END;

	FORStatement* = POINTER TO RECORD(Statement)
		variable* : Designator;
		fromExpression*, toExpression*, byExpression* : Expression;
		statements* : Statement;
	END;

	WITHStatement* = POINTER TO RECORD(Statement)
		variable*, type* : Designator;
		statements* : Statement;
	END;

	REPEATStatement* = POINTER TO RECORD(Statement)
		expression* : Expression;
		statements* : Statement;
	END;

	LOOPStatement* = POINTER TO RECORD(Statement)
		statements* : Statement;
	END;

	RETURNStatement* = POINTER TO RECORD(Statement)
	expression* : Expression;
	END;

	AWAITStatement* = POINTER TO RECORD(Statement)
	expression* : Expression;
	END;

	EXITStatement* = POINTER TO RECORD(Statement)
	END;

	CASEStatement* = POINTER TO RECORD(Statement)
		expression* : Expression;
		cases* : Case;
		else* : Statement;
	END;

	Case* = POINTER TO RECORD
		next* : Case;
		caseRanges* : CaseRange;
		statements* : Statement;
	END;

	CaseRange* = POINTER TO RECORD
		next* : CaseRange;
		a*, b* : Expression;
	END;

	StatementBlock* = POINTER TO RECORD(Statement)
		statements* : Statement;
	END;

	Array* = POINTER TO RECORD
		container* : Scope; (* containing scope *)
		open*: BOOLEAN;
		len*: LONGINT;
		expression* : Expression;
		base*: Type;
	END;

	Pointer* =POINTER TO RECORD
		type*: Type;
	END;

	ProcedureSignature* = POINTER TO RECORD
		params*: ObjectList;
		return* : Type;
	END;

	ProcedureType* = POINTER TO RECORD
		delegate*: BOOLEAN;
		signature* : ProcedureSignature;
	END;

	Type* = POINTER TO RECORD
		container* : Scope; (* containing scope *)
		kind*, basicType* : LONGINT;
		qualident*: Designator;
		type* : TypeDecl;
		array*: Array;
		record*: Record;
		pointer*: Pointer;
		object*: Class;
		procedure*: ProcedureType;
	END;

	NamedObject* = POINTER TO RECORD
		container*, scope* : Scope;
		name* : String;
		exportState* : SET;
		preComment*, postComment* : Comments;
		pos*, altPos* : Position;
	END;

	TypeDecl* = POINTER TO RECORD(NamedObject)
		type* : Type;
	END;

	Const* =POINTER TO RECORD(NamedObject)
		expression* : Expression;
	END;

	Import* = POINTER TO RECORD(NamedObject)
		import* : String;
		package* : String;
	END;

	Var* = POINTER TO RECORD(NamedObject)
		type* : Type;
		varNr* : LONGINT;
		parameterType* : SET;
	END;

	NamedObjectArray = POINTER TO ARRAY OF NamedObject;

	ObjectList*= OBJECT
	VAR objs- : NamedObjectArray;
		nofObjs- : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			NEW(objs, 16); nofObjs := 0
		END Init;

		PROCEDURE Add*(m : NamedObject);
		VAR n : NamedObjectArray; i : LONGINT;
		BEGIN
			ASSERT(m.name # NIL);
			IF nofObjs >= LEN(objs) - 1 THEN
				NEW(n, LEN(objs) * 2);
				FOR i := 0 TO nofObjs - 1 DO n[i] := objs[i] END;
				objs := n
			END;
			objs[nofObjs] := m;
			INC(nofObjs)
		END Add;

		PROCEDURE AddReplace*(m : NamedObject);
		VAR i : LONGINT;
		BEGIN
			ASSERT(m.name # NIL);
			i := 0; WHILE (i < nofObjs) & (objs[i].name^ # m.name^) DO INC(i) END;
			IF i < nofObjs THEN objs[i] := m
			ELSE Add(m)
			END
		END AddReplace;

		PROCEDURE Get*(CONST name : ARRAY OF CHAR) : NamedObject;
		VAR i : LONGINT;
		BEGIN
			i := 0; WHILE (i < nofObjs) & (objs[i].name^ # name) DO INC(i) END;
			IF i < nofObjs THEN RETURN objs[i]
			ELSE RETURN NIL
			END
		END Get;

		PROCEDURE GetWithPrefix*(CONST prefix : ARRAY OF CHAR; candidates : ObjectList; onlyPublic : BOOLEAN);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofObjs) DO
				IF Strings.StartsWith2(prefix, objs[i].name^) THEN
					IF (objs[i].exportState # {}) OR (~onlyPublic) THEN
						candidates.Add(objs[i])
					END
				END;
				INC(i)
			END
		END GetWithPrefix;

	END ObjectList;

	Scope* = OBJECT
	VAR elements*, params* : ObjectList; (* params is only for procedures *)
		parent*, super* : Scope; (* super is only for classes *)
		superQualident* : Designator;
		ownerBody* : Statement;
		owner* : NamedObject;

		PROCEDURE &Init*;
		BEGIN
			NEW(elements);
		END Init;

		PROCEDURE Add*(no : NamedObject);
		BEGIN
			no.container := SELF;
			elements.Add(no)
		END Add;

		PROCEDURE FixSuperScope*;
		VAR type : Type;
		BEGIN
			IF (super = NIL) & (superQualident # NIL) THEN
				type := FindType(superQualident, parent);

				IF type # NIL THEN
					IF type.kind = TObject THEN
						super := type.object.scope;
					ELSIF type.kind = TRecord THEN
						KernelLog.String("fixing record super"); KernelLog.Ln;
						super := type.record.scope
					ELSIF type.kind = TPointer THEN
						IF type.pointer.type.kind = TRecord THEN
							super := type.pointer.type.record.scope
						END
					ELSE KernelLog.String(" xxxpointer to record" ); KernelLog.Ln;
					END;
				END
			END;
		END FixSuperScope;

		(* TODO: Add parameter to only search visible items *)
		PROCEDURE Find*(VAR name : ARRAY OF CHAR; searchUpscopes : BOOLEAN) : NamedObject;
		VAR no : NamedObject;
		BEGIN
			no := elements.Get(name);
			IF (no = NIL) & (params # NIL) THEN no := params.Get(name) END;
			IF (no = NIL) & (super = NIL) & (superQualident # NIL) THEN
				FixSuperScope
			END;

			IF (no = NIL) & (super # NIL) THEN
				no := super.Find(name, FALSE)
			END;

			IF (no = NIL) & searchUpscopes & (parent # NIL) THEN no := parent.Find(name, TRUE) END;
			RETURN no
		END Find;

		(* TODO: add parameter to check for visibility *)
		PROCEDURE FindCandidates*(VAR prefix : ARRAY OF CHAR; searchUpscopes, onlyPublic : BOOLEAN;
			candidates : ObjectList);
		BEGIN
			elements.GetWithPrefix(prefix, candidates, FALSE);
			IF (params # NIL) THEN params.GetWithPrefix(prefix, candidates, onlyPublic) END;
			IF (super = NIL) & (superQualident # NIL) THEN
				FixSuperScope()
			END;

			IF super # NIL THEN
				super.FindCandidates(prefix, FALSE, onlyPublic, candidates)
			END;

			IF searchUpscopes & (parent # NIL) THEN
				parent.FindCandidates(prefix, TRUE, FALSE, candidates)
			END
		END FindCandidates;

	END Scope;

	Record* = POINTER TO RECORD
		scope*: Scope;
	END;

	ProcDecl* = POINTER TO RECORD(NamedObject)
		signature* : ProcedureSignature;
	END;

	(* use private sub classes and private classes in modules to allow separate collection ? *)
	Class* = POINTER TO RECORD(NamedObject)
		implements* : ObjectList;
	END;

	Module* = POINTER TO RECORD(NamedObject)
		package* : Strings.String;
		filename* : Strings.String;
		isSymbolic* : BOOLEAN;
	END;

	NameSpace* = OBJECT
	VAR modules : ObjectList;

		PROCEDURE &Init*;
		BEGIN NEW(modules)
		END Init;

		PROCEDURE AddModule*(m : Module);
		BEGIN
			modules.AddReplace(m)
		END AddModule;

		PROCEDURE GetModule*(CONST name : ARRAY OF CHAR) : Module;
		VAR r : NamedObject;
		BEGIN
			r := modules.Get(name);
			IF r # NIL THEN RETURN r(Module)
			ELSE RETURN NIL
			END
		END GetModule;

	END NameSpace;

	FailList = POINTER TO RECORD next : FailList; name : Strings.String END;

VAR s* : TFStringPool.StringPool;
	ns* : NameSpace;
	db : Tar.Archive;
	failList : FailList;

PROCEDURE GetModule*(imp : Import) : Module;
VAR m : Module;
	fl : FailList;
BEGIN
	ASSERT(imp.import # NIL);
	m := ns.GetModule(imp.import^);
	IF m = NIL THEN
		fl := failList; WHILE fl # NIL DO IF fl.name^ = imp.import^ THEN RETURN NIL END; fl := fl.next END;
		m := ReadSymbolFile(imp.import^);
		IF m # NIL THEN
			m.scope.parent := NIL;
			ns.AddModule(m)
		ELSE
			KernelLog.String("FAIL imp.name^= "); KernelLog.String(imp.name^);
			KernelLog.String(imp.import^); KernelLog.Ln;

			NEW(fl); fl.name := Strings.NewString(imp.import^);
			fl.next := failList; failList := fl
		END
	END;
	RETURN m
END GetModule;

PROCEDURE FindType*(d : Designator; scope : Scope) : Type;
VAR
	no : NamedObject;
	str : ARRAY 64 OF CHAR;
	m : Module;
BEGIN
	IF scope = NIL THEN RETURN NIL END;
	s.GetString(d(Ident).name,str);
	no := scope.Find(str, TRUE);
	IF no = NIL THEN RETURN NIL END;
	(* follow import *)
	IF no IS Import THEN m := GetModule(no(Import));
		IF m = NIL THEN RETURN NIL END;
		scope := m.scope;
		IF scope # NIL THEN
			d := d.next;

			s.GetString(d(Ident).name,str);
			no := scope.Find(str, TRUE);
		END
	END;
	IF no = NIL THEN RETURN NIL END;
	RETURN no(TypeDecl).type
END FindType;

PROCEDURE PrimitiveExpressionInt*(value : HUGEINT) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionPrimitive;
	IF (value >= -128) & (value <= 127) THEN expression.basicType:= BasicInt8
	ELSIF (value >= MIN(INTEGER)) & (value <= MAX(INTEGER)) THEN expression.basicType := BasicInt16
	ELSIF (value >= MIN(LONGINT)) & (value <= MAX(LONGINT)) THEN expression.basicType := BasicInt32
	ELSE expression.basicType := BasicInt64
	END;
	expression.intValue := value;
	expression.isConstant := TRUE;
	RETURN expression
END PrimitiveExpressionInt;

PROCEDURE PrimitiveExpressionString*(CONST str : ARRAY OF CHAR) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionPrimitive;
	expression.basicType := BasicString;
	expression.strValue := Strings.NewString(str);
	expression.isConstant := TRUE;
	RETURN expression
END PrimitiveExpressionString;

PROCEDURE PrimitiveExpressionBool*(value : BOOLEAN) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionPrimitive;
	expression.basicType:= BasicBoolean;
	expression.boolValue := value;
	expression.isConstant := TRUE;
	RETURN expression
END PrimitiveExpressionBool;

PROCEDURE PrimitiveExpressionSet*(value : Set) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionPrimitive;
	expression.basicType:= BasicSet;
	expression.setValue := value;
	expression.isConstant := TRUE;
	RETURN expression
END PrimitiveExpressionSet;

PROCEDURE PrimitiveExpressionNIL*() : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionPrimitive;
	expression.basicType:= BasicNIL;
	expression.isConstant := TRUE;
	RETURN expression
END PrimitiveExpressionNIL;

PROCEDURE IllegalExpression*() : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionIllegal;
	expression.basicType:= BasicNIL;
	expression.isConstant := TRUE;
	RETURN expression
END IllegalExpression;

PROCEDURE UnaryExpression*(op : INTEGER; exp : Expression) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionUnary;
	expression.a := exp;
	expression.op := op;
	expression.isConstant := exp.isConstant;
	RETURN expression
END UnaryExpression;

PROCEDURE BinaryExpression*(op : LONGINT; expa, expb : Expression) : Expression;
VAR expression : Expression;
BEGIN
	IF expa = NIL THEN expa := IllegalExpression() END;
	IF expb = NIL THEN expb := IllegalExpression() END;
	NEW(expression);
	expression.kind := ExpressionBinary;
	expression.a := expa;
	expression.b := expb;
	expression.op := op;
	expression.isConstant := expa.isConstant & expb.isConstant;
	RETURN expression
END BinaryExpression;

PROCEDURE CreateDesignatorExpression*(designator : Designator) : Expression;
VAR expression : Expression;
BEGIN
	NEW(expression);
	expression.kind := ExpressionDesignator;
	expression.designator := designator;
	RETURN expression
END CreateDesignatorExpression;

PROCEDURE CreateAssignment*(designator : Designator; expression : Expression) : Statement;
VAR as : Assignment;
BEGIN
	NEW(as);
	as.designator := designator; as.expression := expression;
	RETURN as
END CreateAssignment;

PROCEDURE CreateProcedureCall*(designator : Designator) : Statement;
VAR pc : ProcedureCall ;
BEGIN
	NEW(pc);
	pc.designator := designator;
	RETURN pc
END CreateProcedureCall;

PROCEDURE CreateWhile*(expression : Expression; statements : Statement) : Statement;
VAR w : WHILEStatement;
BEGIN
	NEW(w);
	w.expression := expression;
	w.statements := statements;
	RETURN w
END CreateWhile;

PROCEDURE CreateRepeat*(expression : Expression; statements : Statement) : Statement;
VAR r : REPEATStatement;
BEGIN
	NEW(r);
	r.expression := expression;
	r.statements := statements;
	RETURN r
END CreateRepeat;

PROCEDURE CreateLoop*(statements : Statement) : Statement;
VAR l : LOOPStatement;
BEGIN
	NEW(l);
	l.statements := statements;
	RETURN l
END CreateLoop;

PROCEDURE CreateFor*(variable : Designator; from, to, by : Expression; statements : Statement) : Statement;
VAR f : FORStatement;
BEGIN
	NEW(f);
	f.variable := variable;
	f.fromExpression := from;
	f.toExpression := to;
	f.byExpression := by;
	f.statements := statements;

	RETURN f
END CreateFor;

PROCEDURE CreateWith*(variable, type : Designator; statements : Statement) : Statement;
VAR w : WITHStatement;
BEGIN
	NEW(w);
	w.variable := variable;
	w.type := type;
	w.statements := statements;
	RETURN w
END CreateWith;

PROCEDURE CreateCase*(expression : Expression; cases : Case; statements : Statement) : Statement;
VAR c : CASEStatement;
BEGIN
	NEW(c);
	c.expression := expression;
	c.cases := cases;
	c.else := statements;
	RETURN c
END CreateCase;


PROCEDURE CreateExit*(): Statement;
VAR e : EXITStatement;
BEGIN
	NEW(e);
	RETURN e
END CreateExit;

PROCEDURE CreateReturn*(ex : Expression): Statement;
VAR r : RETURNStatement;
BEGIN
	NEW(r); r.expression := ex;
	RETURN r
END CreateReturn;

PROCEDURE CreateAwait*(ex : Expression): Statement;
VAR a :AWAITStatement;
BEGIN
	NEW(a); a.expression := ex;
	RETURN a
END CreateAwait;

PROCEDURE AddComment*(VAR comments : Comments; CONST str : ARRAY OF CHAR) : Comment;
BEGIN
	IF comments = NIL THEN NEW(comments) END;
	IF comments.first = NIL THEN NEW(comments.first); comments.last := comments.first
	ELSE NEW(comments.last.next); comments.last := comments.last.next END;
	comments.last.str := Strings.NewString(str);
	RETURN comments.last
END AddComment;

PROCEDURE NewEmptyStatement*(): Statement;
VAR e : EmptyStatement;
BEGIN
	NEW(e);
	RETURN e
END NewEmptyStatement;

(* EXPORT/IMPORT symbols to symbol DB *)

(* a qualident that can only comprise ident{.ident} *)
PROCEDURE ExportQualident(w : Streams.Writer; ident : Designator; scope : Scope);
VAR i : LONGINT; q : Designator; str : ARRAY 128 OF CHAR; no : NamedObject;
BEGIN
	i := 0; q := ident; WHILE q # NIL DO ASSERT(q IS Ident); q := q.next; INC(i) END;
	w.Net32(i);
	q := ident;
	IF q # NIL THEN
		(* check if it is an alias import *)
		s.GetString(q(Ident).name, str); no := scope.Find(str, TRUE);
		IF (no # NIL) & (no IS Import) THEN
			w.RawString(no(Import).import^); q := q.next
		END;

		WHILE q # NIL DO
			s.GetString(q(Ident).name, str); w.RawString(str);  q := q.next
		END
	END
END ExportQualident;

PROCEDURE ExportSignature(w : Streams.Writer; signature : ProcedureSignature; scope : Scope);
VAR i : LONGINT;
	no : NamedObject;
BEGIN
	IF signature = NIL THEN ExportType(w, NIL, 0, scope)
	ELSE ExportType(w, signature.return, 0, scope)
	END;
	IF (signature = NIL) OR (signature.params = NIL) THEN
		w.Net32(0);
		RETURN
	END;
	w.Net32(signature.params.nofObjs);

	FOR i := 0 TO signature.params.nofObjs - 1 DO
		no := signature.params.objs[i];
		IF no IS Var THEN
			w.RawString(no.name^);
			ExportType(w, no(Var).type, 0, scope)
		END
	END;
END ExportSignature;

PROCEDURE ExportType(w : Streams.Writer; t : Type; level : LONGINT; scope : Scope);
BEGIN
	IF t = NIL THEN w.Net32(TNone); RETURN END;
	w.Net32(t.kind);
	CASE t.kind OF
		|TAlias : ExportQualident(w, t.qualident, scope)
		|TObject : ExportScope(w, t.object.scope, level + 1)
		|TArray : ExportType(w, t.array.base, level + 1, scope);
		|TPointer : ExportType(w, t.pointer.type, level + 1, scope);
		|TRecord : ExportScope(w, t.record.scope, level + 1)
		|TProcedure : ExportSignature(w, t.procedure.signature, scope)
	ELSE
	END
END ExportType;

PROCEDURE ExportScope(w : Streams.Writer; scope : Scope; level : LONGINT);
VAR no : NamedObject;
	nofTypes, nofProcs, nofImports, nofConst, nofVar, i, t : LONGINT;
BEGIN
	(* Count element types in scope *)
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS Import THEN INC(nofImports)
		ELSIF no IS ProcDecl THEN INC(nofProcs)
		ELSIF no IS TypeDecl THEN INC(nofTypes)
		ELSIF no IS Const THEN INC(nofConst)
		ELSIF no IS Var THEN INC(nofVar)
		ELSE Trace.String("Was denn noch ?")
		END
	END;

	ExportQualident(w, scope.superQualident, scope);

	(* imports *)
	w.Net32(nofImports); t := 0;
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS Import THEN w.RawString(no(Import).import^); INC(t) END
	END;
	ASSERT(t = nofImports);

	(* variables *)
	w.Net32(nofVar); t := 0;
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS Var THEN
			w.RawString(no.name^); INC(t);
			w.RawSet(no.exportState);
			ExportType(w, no(Var).type, level, scope)
		END
	END;
	ASSERT(t = nofVar);

	(* types *)
	w.Net32(nofTypes); t := 0;
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS TypeDecl THEN
			w.RawString(no.name^); INC(t);
			w.RawSet(no.exportState);
			ExportType(w, no(TypeDecl).type, level, scope)
		END
	END;
	ASSERT(t = nofTypes);

	(* Const *)
	w.Net32(nofConst); t := 0;
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS Const THEN
			w.RawString(no.name^); INC(t);
			w.RawSet(no.exportState)
		END
	END;
	ASSERT(t = nofConst);

	(* Procedures *)
	w.Net32(nofProcs); t := 0;
	FOR i := 0 TO scope.elements.nofObjs - 1 DO
		no := scope.elements.objs[i];
		IF no IS ProcDecl THEN
			w.RawString(no.name^); INC(t);
			w.RawSet(no.exportState);
			ExportSignature(w, no(ProcDecl).signature, scope)
		END
	END;
	ASSERT(t = nofProcs)
END ExportScope;

PROCEDURE WriteSymbolFile*(m : Module);
VAR
	sender : Streams.Sender;
	w : Streams.Writer;

	f : Files.File;
	fw : Files.Writer;
	fn : ARRAY 128 OF CHAR;
BEGIN
	IF TarBasedDB THEN
		db.Acquire;
	(*	receiver := db.OpenReceiver(m.name^);
		IF receiver # NIL THEN
			db.RemoveEntry(m.name^);
		END; *)
		sender := db.OpenSender(m.name^);
		db.Release;
		Streams.OpenWriter(w, sender)
	ELSE
		COPY(m.name^, fn); Strings.Append(fn, ".xym");
		f := Files.New(fn);
		Files.OpenWriter(fw, f, 0);
		w := fw
	END;
	w.Net32(SymVersion);
	w.RawString(m.name^);
	IF m.filename = NIL THEN w.RawString("") ELSE w.RawString(m.filename^) END;
	ExportScope(w, m.scope, 0);
	w.Update;

	IF ~TarBasedDB THEN
		Files.Register(f)
	END;
END WriteSymbolFile;

(* a qualident that can only comprise ident{.ident} *)
PROCEDURE ImportQualident(r : Streams.Reader) : Designator;
VAR nof, i : LONGINT; f, n : Designator; ident : Ident; str : ARRAY 128 OF CHAR;
BEGIN
	nof := r.Net32(); f := NIL;
	FOR i := 0 TO nof - 1 DO
		NEW(ident); IF f = NIL THEN f := ident; n := f ELSE n.next := ident END;
		r.RawString(str);
		ident.name := s.AddString(str);
	END;
	RETURN f
END ImportQualident;

PROCEDURE ImportSignature(r : Streams.Reader; scope : Scope; owner : NamedObject) : ProcedureSignature;
VAR i : LONGINT;
	signature : ProcedureSignature;
	n : LONGINT;
	var : Var;
	str : ARRAY 128 OF CHAR;
BEGIN
	NEW(signature);
	signature.return := ImportType(r, scope, owner);
	n := r.Net32();

	NEW(signature.params);
	FOR i := 0 TO n - 1 DO
		NEW(var);
		r.RawString(str); var.name := Strings.NewString(str);
		var.type := ImportType(r, scope, owner);
		signature.params.Add(var)
	END;
	RETURN signature
END ImportSignature;

PROCEDURE ImportType(r : Streams.Reader; scope : Scope; owner : NamedObject) : Type;
VAR t : Type;
BEGIN
	NEW(t);
	t.container := scope;
	t.kind := r.Net32();
	IF t.kind = TNone THEN RETURN NIL END;
	CASE t.kind OF
		|TAlias : t.qualident := ImportQualident(r)
		|TObject : NEW(t.object); t.object.scope := ImportScope(r, scope, owner)
		|TArray : NEW(t.array); t.array.base := ImportType(r, scope, owner);
		|TPointer : NEW(t.pointer); t.pointer.type := ImportType(r, scope, owner);
		|TRecord : NEW(t.record); t.record.scope := ImportScope(r, scope, owner)
		|TProcedure : NEW(t.procedure); t.procedure.signature := ImportSignature(r, scope, owner);
	ELSE
	END;
	RETURN t
END ImportType;

PROCEDURE ImportScope(r : Streams.Reader; scope : Scope; owner : NamedObject) : Scope;
VAR i, nofImports, nofVar, nofTypes, nofConst, nofProcs : LONGINT;
	imp : Import; typeDecl : TypeDecl; var : Var; const : Const; procDecl : ProcDecl;
	str : ARRAY 128 OF CHAR;
	s : Scope;
BEGIN
	NEW(s); s.parent := scope; s.owner := owner;
	 s.superQualident := ImportQualident(r);
	(* imports *)
	nofImports := r.Net32();
	FOR i := 0 TO nofImports - 1 DO
		NEW(imp);
		r.RawString(str); imp.name := Strings.NewString(str); imp.import := imp.name;
		s.Add(imp)
	END;

	(* variables *)
	nofVar := r.Net32();
	FOR i := 0 TO nofVar - 1 DO
		NEW(var);
		r.RawString(str); var.name := Strings.NewString(str);
		r.RawSet(var.exportState);
		var.type := ImportType(r, s, owner);
		s.Add(var)
	END;

	(* types *)
	nofTypes := r.Net32();
	FOR i := 0 TO nofTypes - 1 DO
		NEW(typeDecl);
		r.RawString(str); typeDecl.name := Strings.NewString(str);
		r.RawSet(typeDecl.exportState);
		typeDecl.type := ImportType(r, s, typeDecl);
		s.Add(typeDecl)
	END;

	(* Const *)
	nofConst := r.Net32();
	FOR i := 0 TO nofConst - 1 DO
		NEW(const);
		r.RawString(str); const.name := Strings.NewString(str);
		r.RawSet(const.exportState);
		s.Add(const)
	END;

	(* Procedures *)
	nofProcs := r.Net32();
	FOR i := 0 TO nofProcs - 1 DO
		NEW(procDecl);
		r.RawString(str); procDecl.name := Strings.NewString(str);
		r.RawSet(procDecl.exportState);
		procDecl.signature := ImportSignature(r, s, owner);
		s.Add(procDecl)
	END;
	RETURN s
END ImportScope;

PROCEDURE ReadSymbolFile*(CONST modname : ARRAY OF CHAR) : Module;
VAR r : Streams.Reader;
	receiver : Streams.Receiver;
	fn, name, ofn : ARRAY 128 OF CHAR;
	m : Module; version : LONGINT;
 	f : Files.File;
	fr : Files.Reader;
BEGIN
	IF TarBasedDB THEN
		db.Acquire;
		receiver := db.OpenReceiver(modname);
		db.Release;
		IF receiver # NIL THEN
			Streams.OpenReader(r, receiver);
		ELSE RETURN NIL
		END
	ELSE
		COPY(modname, fn); Strings.Append(fn, ".xym");
		f := Files.Old(fn);
		IF f # NIL THEN
			Files.OpenReader(fr, f, 0);
			r := fr;
		ELSE RETURN NIL
		END;
	END;
	version := r.Net32();
	IF version # SymVersion THEN Trace.String("Wrong symbol file"); Trace.String(modname); Trace.Ln; RETURN NIL END;
	r.RawString(name);
	r.RawString(ofn);
	NEW(m); m.name := Strings.NewString(name);
	m.filename := Strings.NewString(ofn);
	m.scope := ImportScope(r, NIL, m);
	RETURN m
END ReadSymbolFile;

PROCEDURE OpenDB;
VAR f : Files.File;
BEGIN
	IF TarBasedDB THEN
		f := Files.Old("TFPETSymbols.db");
		IF f = NIL THEN f := Files.New("TFPETSymbols.db") END;
		NEW(db, f);
	END
END OpenDB;

BEGIN
	OpenDB;
	NEW(s); NEW(ns)
END TFTypeSys.
