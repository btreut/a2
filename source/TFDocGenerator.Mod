MODULE TFDocGenerator;

IMPORT
	TS := TFTypeSys, MultiLogger, Streams, Strings, Trace;

VAR w* : Streams.Writer;
	ml : MultiLogger.LogWindow;
	indent : LONGINT;

PROCEDURE Indent;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO indent - 1 DO w.Char(09X) END
END Indent;


PROCEDURE DumpConst(c : TS.Const);
BEGIN
	Indent; w.String(c.name^); w.Ln;
END DumpConst;

PROCEDURE DumpObject(o : TS.Class);
BEGIN
	Indent; w.String("OBJECT ");
	IF o.scope.super # NIL THEN
		w.Char("(");
	(*	DumpDesignator(o.super); *)
		w.Char(")");
	END;
	w.Ln;
	INC(indent); DumpDeclarations(o.scope); DEC(indent);

	Indent; w.String("END "); w.Ln
END DumpObject;

PROCEDURE DumpArray(a : TS.Array);
BEGIN
	Indent; w.String("ARRAY OF ");
	DumpType(a.base)
END DumpArray;

PROCEDURE DumpRecord(r : TS.Record);
BEGIN
	Indent; w.String("RECORD")
END DumpRecord;

PROCEDURE DumpProcedure(p : TS.ProcedureType);
BEGIN

	Indent; w.String("PROCEDURE");
END DumpProcedure;


PROCEDURE DumpDesignator*(d : TS.Designator);
VAR s : ARRAY 64 OF CHAR;
BEGIN
	IF d = NIL THEN w.String("NIL"); RETURN END;
	IF d IS TS.Ident THEN TS.s.GetString(d(TS.Ident).name, s); w.String(s)
	ELSIF d IS TS.Index THEN
		w.String("[");
		DumpExpressionList(d(TS.Index).expressionList);
		w.String("]");
	ELSIF d IS TS.ActualParameters THEN
		w.String("(");
		DumpExpressionList(d(TS.ActualParameters).expressionList);
		w.String(")");
	END;
	IF (d.next # NIL) THEN
		IF (d IS TS.Ident) THEN w.String(".") END;
		DumpDesignator(d.next)
	END
END DumpDesignator;

PROCEDURE DumpExpressionList(e : TS.ExpressionList);
BEGIN
	WHILE e # NIL DO
		DumpExpression(e.expression);
		IF e.next # NIL THEN w.String(", ") END;
		e := e.next
	END
END DumpExpressionList;


PROCEDURE DumpExpression(e : TS.Expression);
BEGIN
w.Update;
	IF e = NIL THEN w.String("NIL"); w.Update; RETURN END;

	IF e.kind = TS.ExpressionPrimitive THEN
		w.String("Primitive"); w.Int(e.basicType, 0); w.Int(SHORT(e.intValue), 0); w.Update
	ELSIF e.kind = TS.ExpressionUnary THEN
		CASE e.op OF
			|TS.OpNegate: w.String("-")
			|TS.OpInvert: w.String("~")
		ELSE
			Trace.String("Internal error :"); Trace.String("e.op= "); Trace.Int(e.op, 0); Trace.Ln;
		END;
		DumpExpression(e.a);
	ELSIF e.kind = TS.ExpressionBinary THEN
		w.String("(");
		DumpExpression(e.a);
		CASE e.op OF
			|TS.OpAdd: w.String("+")
			|TS.OpSub: w.String("-")
			|TS.OpOr: w.String("OR")
			|TS.OpMul: w.String("*")
			|TS.OpAnd: w.String("&")
			|TS.OpIntDiv: w.String("DIV")
			|TS.OpMod: w.String("MOD")
			|TS.OpDiv: w.String("/")

			|TS.OpEql: w.String("=")
			|TS.OpNeq: w.String("#")
			|TS.OpLss: w.String("<")
			|TS.OpLeq: w.String("<=")
			|TS.OpGtr: w.String(">")
			|TS.OpGeq: w.String(">=")
			|TS.OpIn: w.String("IN")
			|TS.OpIs: w.String("IS")
		END;
		DumpExpression(e.b);
		w.String(")");
	ELSIF e.kind = TS.ExpressionDesignator THEN
		DumpDesignator(e.designator)
	END;
END DumpExpression;


PROCEDURE DumpType*(t : TS.Type);
BEGIN
	CASE t.kind OF
		|TS.TAlias : DumpDesignator(t.qualident)
		|TS.TObject : DumpObject(t.object)
		|TS.TArray : DumpArray(t.array);
		|TS.TPointer : w.String("POINTER TO "); DumpType(t.pointer.type)
		|TS.TRecord : DumpRecord(t.record);
		|TS.TProcedure : DumpProcedure(t.procedure)
	ELSE
		w.String("XXXX"); Trace.String("Unknown Type"); Trace.String("t.kind= "); Trace.Int(t.kind, 0); Trace.Ln;
	END

END DumpType;

PROCEDURE DumpCases(case : TS.Case);
VAR cr : TS.CaseRange;
BEGIN
	Indent;
	WHILE case # NIL DO
		cr := case.caseRanges;
		WHILE cr # NIL DO
			DumpExpression(cr.a);
			IF cr.b # NIL THEN w.String(".."); DumpExpression(cr.b) END;
			IF cr.next # NIL THEN w.String(", ") END;
			cr := cr.next
		END;
		w.String(" :"); w.Ln;
		IF case.statements # NIL THEN DumpStatementSequence(case.statements) END;
		IF case.next # NIL THEN Indent; w.String("|") END;
		case := case.next
	END;
END DumpCases;

PROCEDURE DumpTypeDecl(t : TS.TypeDecl);
BEGIN
	Indent; w.String(t.name^); w.String(" = "); DumpType(t.type);
	w.Ln;
END DumpTypeDecl;

PROCEDURE DumpVar(v : TS.Var);
BEGIN
	Indent; w.String(v.name^); w.String(" : "); DumpType(v.type); w.Ln
END DumpVar;

PROCEDURE DumpComments(comments : TS.Comments);
VAR cur : TS.Comment;
BEGIN
	cur := comments.first;
	WHILE cur # NIL DO
		w.Update;
		ml.tw.SetFontStyle({0});
		w.String("(*");
		w.String(cur.str^);
		w.String("*)");
		w.Update;
		ml.tw.SetFontStyle({});
		cur := cur.next
	END
END DumpComments;


PROCEDURE DumpStatementSequence(s : TS.Statement);
VAR ts : TS.Statement;
BEGIN
	INC(indent);
	WHILE s # NIL DO
		IF s.preComment # NIL THEN Indent; DumpComments(s.preComment); w.Ln END;
		IF s IS TS.Assignment THEN
			Indent;
			DumpDesignator(s(TS.Assignment).designator);
			w.String(" := ");
			DumpExpression(s(TS.Assignment).expression);
		ELSIF s IS TS.ProcedureCall THEN
			Indent;
			DumpDesignator(s(TS.ProcedureCall).designator);
		ELSIF s IS TS.IFStatement THEN
			Indent;
			w.String("IF ");
			DumpExpression(s(TS.IFStatement).expression);
			w.String("THEN "); w.Ln;
			DumpStatementSequence(s(TS.IFStatement).then);
			ts := s(TS.IFStatement).else;
			IF ts # NIL THEN
				Indent; w.String("ELSE "); w.Ln;
				DumpStatementSequence(ts);
			END;
			Indent; w.String("END");
		ELSIF s IS TS.WHILEStatement THEN
			Indent; w.String("WHILE ");DumpExpression(s(TS.WHILEStatement).expression);
			w.String("DO"); w.Ln;
			DumpStatementSequence(s(TS.WHILEStatement).statements);
			Indent; w.String("END")
		ELSIF s IS TS.REPEATStatement THEN
			Indent; w.String("REPEAT "); w.Ln;
			DumpStatementSequence(s(TS.REPEATStatement).statements);
			Indent; w.String("UNTIL "); DumpExpression(s(TS.REPEATStatement).expression);
		ELSIF s IS TS.LOOPStatement THEN
			Indent; w.String("LOOP"); w.Ln;
			DumpStatementSequence(s(TS.LOOPStatement).statements);
			Indent; w.String("END")
		ELSIF s IS TS.FORStatement THEN
			Indent; w.String("FOR ");
			DumpDesignator(s(TS.FORStatement).variable);
			w.String(" := "); DumpExpression(s(TS.FORStatement).fromExpression);
			w.String(" TO "); DumpExpression(s(TS.FORStatement).toExpression);
			IF s(TS.FORStatement).byExpression # NIL THEN
				w.String(" BY "); DumpExpression(s(TS.FORStatement).byExpression);
			END;
			w.String(" DO"); w.Ln;
			DumpStatementSequence(s(TS.FORStatement).statements);
			Indent; w.String("END")
		ELSIF s IS TS.EXITStatement THEN
			Indent; w.String("EXIT");
		ELSIF s IS TS.RETURNStatement THEN
			Indent; w.String("RETURN ");
			IF s(TS.RETURNStatement).expression # NIL THEN DumpExpression(s(TS.RETURNStatement).expression) END;
		ELSIF s IS TS.AWAITStatement THEN
			Indent; w.String("AWAIT(");
			DumpExpression(s(TS.AWAITStatement).expression); w.String(")")
		ELSIF s IS TS.StatementBlock THEN
			Indent; w.String("BEGIN");
			DumpStatementSequence(s(TS.StatementBlock).statements);
			Indent; w.String("END")
		ELSIF s IS TS.WITHStatement THEN
			Indent; w.String("WITH ");
			DumpDesignator(s(TS.WITHStatement).variable);
			w.String(" : "); DumpDesignator(s(TS.WITHStatement).type);
			w.String(" DO"); w.Ln;
			DumpStatementSequence(s(TS.WITHStatement).statements);
			Indent; w.String("END")
		ELSIF s IS TS.CASEStatement THEN
			Indent; w.String("CASE "); DumpExpression(s(TS.CASEStatement).expression); w.String(" OF"); w.Ln;
			DumpCases(s(TS.CASEStatement).cases);
			IF s(TS.CASEStatement).else # NIL THEN
				Indent; w.String("ELSE"); w.Ln;
				DumpStatementSequence(s(TS.CASEStatement).else)
			END;
			Indent; w.String("END")
		END;
		IF (s.next # NIL) & ~(s.next IS TS.EmptyStatement) THEN w.String(";") END;
		IF s.postComment # NIL THEN DumpComments(s.postComment); END;
		IF ~(s IS TS.EmptyStatement) THEN w.Ln END;
		s := s.next
	END
	;DEC(indent)

END DumpStatementSequence;


PROCEDURE DumpProcDecl(p : TS.ProcDecl);
VAR s : TS.Statement;
	cur : TS.NamedObject; i : LONGINT;
BEGIN
	IF p.preComment # NIL THEN
		DumpComments(p.preComment);
	END;
	Indent; w.String("PROCEDURE "); w.String(p.name^);

	IF (p.signature # NIL) & (p.signature.params # NIL) THEN
		FOR i := 0 TO p.signature.params.nofObjs - 1 DO
			cur := p.signature.params.objs[i];
			w.String(cur.name^);
		END
	END;
	w.Ln;

	INC(indent); DumpDeclarations(p.scope); DEC(indent);

	IF p.scope.ownerBody # NIL THEN
		w.String("BEGIN"); w.Ln;
		s := p.scope.ownerBody;
		DumpStatementSequence(s)
	END;
	Indent; w.String("END "); w.String(p.name^); w.Ln; w.Ln;
END DumpProcDecl;

PROCEDURE DumpDeclarations(d : TS.Scope);
VAR i : LONGINT;
	last, cur : TS.NamedObject;
BEGIN
	IF d = NIL THEN RETURN END;
	FOR i := 0 TO d.elements.nofObjs - 1 DO
		cur := d.elements.objs[i];
		IF cur IS TS.Const THEN
			IF (last = NIL) OR ~(last IS TS.Const) THEN
				IF last # NIL THEN w.Ln END;
				Indent;	w.String("CONST"); w.Ln
			END;
			w.Char(09X); DumpConst(cur(TS.Const))
		ELSIF cur IS TS.TypeDecl THEN
			IF (last = NIL) OR ~(last IS TS.TypeDecl) THEN
				IF last # NIL THEN w.Ln END;
				Indent;	w.String("TYPE"); w.Ln
			END;
			w.Char(09X);DumpTypeDecl(cur(TS.TypeDecl));
		ELSIF cur IS TS.Var THEN
			IF (last = NIL) OR ~(last IS TS.Var) THEN
				IF last # NIL THEN w.Ln END;
				Indent;	w.String("VAR"); w.Ln
			END;
			w.Char(09X); DumpVar(cur(TS.Var))
		ELSIF cur IS TS.ProcDecl THEN
			IF last # NIL THEN w.Ln END;
			DumpProcDecl(cur(TS.ProcDecl))
		ELSIF cur IS TS.Import THEN
		END;
		last := cur;
	END
END DumpDeclarations;


PROCEDURE DumpConsts(d : TS.Scope);
VAR i : LONGINT;
	last, cur : TS.NamedObject;
BEGIN
	IF d = NIL THEN RETURN END;
	FOR i := 0 TO d.elements.nofObjs - 1 DO
		cur := d.elements.objs[i];
		IF cur IS TS.Const THEN
			IF (last = NIL) OR ~(last IS TS.Const) THEN
				IF last # NIL THEN w.Ln END;
				Indent;
			END;
			w.Char(09X); DumpConst(cur(TS.Const))
		END;
		last := cur;
	END
END DumpConsts;

PROCEDURE DocumentModule*(m : TS.Module);
VAR i : LONGINT;
	comment : TS.Comment;
BEGIN
	NEW(ml, m.name^, w);

	w.String("MODULE "); w.String(m.name^); w.Ln;
	w.Ln;
	
	IF m.preComment # NIL THEN
		comment := m.preComment.first;
		WHILE comment # NIL DO
			IF Strings.StartsWith2("(**", comment.str^) THEN
				w.String(comment.str^); w.Ln;
			END
		END
	END;
(*	IF m.imports.nofObjs > 0 THEN
		w.String("IMPORT ");
		FOR i := 0 TO m.imports.nofObjs - 1 DO
			w.String(m.imports.objs[i](TS.Import).import^);
			IF i < m.imports.nofObjs - 1 THEN w.String(", ") END
		END;
		w.String(";"); w.Ln;
	END; *)

	DumpConsts(m.scope);
	w.Update;
END DocumentModule;

END TFDocGenerator.
