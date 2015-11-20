MODULE TFXRef; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Generate a cross reference of Modules"; *)

IMPORT
	TS := TFTypeSys, TFAOParser, MultiLogger, Streams, Trace, Commands, KernelLog, Kernel,
	TextUtilities, Texts, ST := TFScopeTools, S := BimboScanner, Strings, Files, UTF8Strings, TFClasses, Dates,
	TFDocGenerator;

CONST
	KindNoStart = 0;
	KindComment = 1;
	KindDeclaration = 2;
	KindUse = 3;
TYPE
	Range = RECORD
		a, b : LONGINT;
		kind : LONGINT;
		no : TS.NamedObject;
	END;

	NamedObjectArray = POINTER TO ARRAY OF TS.NamedObject;
	LocalExternalUsesSet = OBJECT
	VAR nof : LONGINT;
		items : NamedObjectArray;
		PROCEDURE &Init;
		BEGIN
			nof := 0;
			NEW(items, 1024);
		END Init;

		PROCEDURE Add(x : TS.NamedObject);
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nof) & (items[i] # x) DO INC(i) END;
			IF i < nof THEN RETURN END;
			IF nof = LEN(items) THEN Grow END;
			items[nof] := x;
			INC(nof);
		END Add;

		PROCEDURE Grow;
		VAR temp : NamedObjectArray;
			i : LONGINT;
		BEGIN
			NEW(temp, LEN(items) * 2);
			FOR i := 0 TO LEN(items) - 1 DO
				temp[i] := items[i]
			END;
			items := temp
		END Grow;

	END LocalExternalUsesSet;
	
	StringList = POINTER TO ARRAY OF Strings.String;
	GlobalUse = OBJECT
	VAR
		items : StringList;
		nofItems : LONGINT;
		
		PROCEDURE &Init;
		BEGIN
			NEW(items, 16);
			nofItems := 0;
		END Init;
		
		PROCEDURE AddFile(CONST filename : ARRAY OF CHAR);
		BEGIN
			IF nofItems = LEN(items) THEN Grow END;
			items[nofItems] := Strings.NewString(filename);
			INC(nofItems)
		END AddFile;

		PROCEDURE Grow;
		VAR temp : StringList;
			i : LONGINT;
		BEGIN
			NEW(temp, LEN(items) * 2);
			FOR i := 0 TO LEN(items) - 1 DO
				temp[i] := items[i]
			END;
			items := temp
		END Grow;
		
	END GlobalUse;

VAR
	ml : MultiLogger.LogWindow;
	globalUses : TFClasses.StringHashMap;

	(* could be a hash, sorted list, priority queue *)
	ranges : POINTER TO ARRAY OF Range;
	localUses : LocalExternalUsesSet;
	currentAuthor : ARRAY 128 OF CHAR;
	currentPurpose : ARRAY 4096 OF CHAR;

PROCEDURE MakeRange(from, to, kind : LONGINT; no : TS.NamedObject);
BEGIN
	ranges[from].kind := kind;
	ranges[from].a := from;
	ranges[from].b := to;
	ranges[from].no := no;
END MakeRange;

PROCEDURE DumpConst(scope : TS.Scope; c : TS.Const);
BEGIN
	CheckExpression(c.expression, scope)
END DumpConst;

PROCEDURE DumpObject(o : TS.Class);
BEGIN
	IF o.scope.superQualident # NIL THEN
		CheckDesignator(o.scope.superQualident, o.container);
	END;
	DumpDeclarations(o.scope);
END DumpObject;

PROCEDURE DumpArray(a : TS.Array; scope : TS.Scope);
BEGIN
	IF a.expression # NIL THEN CheckExpression(a.expression, scope) END;
	DumpType(a.base, scope)
END DumpArray;

PROCEDURE DumpRecord(r : TS.Record);
BEGIN
	DumpDeclarations(r.scope);
END DumpRecord;

PROCEDURE DumpProcedure(p : TS.ProcedureType);
BEGIN
END DumpProcedure;

PROCEDURE CheckExpressionList(e : TS.ExpressionList; sig : TS.ProcedureSignature; scope : TS.Scope);
(*VAR i, a, b : LONGINT;(* nr, f : Reference;*)*)
BEGIN
(*	i := 0;
	f := NIL;*)
	WHILE e # NIL DO
		CheckExpression(e.expression, scope);
(*		IF (sig # NIL) & (sig.params # NIL)  THEN
			IF i < sig.params.nofObjs THEN
				a := -1; b := -1; GetExpressionRange(e.expression, a, b);
				IF (a >= 0) & (b > a) THEN
					NEW(nr); nr.next := actualParameter; actualParameter := nr; nr.np := -1;
					nr.no := sig.params.objs[i];
					nr.fp := posKeeper.AddPos(a);
					nr.tp := posKeeper.AddPos(b);
					IF f # NIL THEN f.np := nr.fp END; f := nr;
				END
			ELSE
				GetExpressionRange(e.expression, a, b);
				KernelLog.String("pos = "); KernelLog.Int(a, 0); KernelLog.String(" more parameter than expected ")
			END
		END;
		INC(i);*)
		e := e.next
	END
END CheckExpressionList;

PROCEDURE CheckExpression(e : TS.Expression; scope : TS.Scope);
VAR t : TS.Type;
	sr : TS.SetRange;
BEGIN
	IF e = NIL THEN KernelLog.String("Expression is NIL"); RETURN END;
	IF e.kind = TS.ExpressionPrimitive THEN
		IF e.basicType = TS.BasicSet THEN
			sr := e.setValue.setRanges;
			WHILE sr # NIL DO
				IF sr.a # NIL THEN CheckExpression(sr.a, scope) END;
				IF sr.b # NIL THEN CheckExpression(sr.b, scope) END;
				sr := sr.next
			END;
		END;
	ELSIF e.kind = TS.ExpressionUnary THEN
		CheckExpression(e.a, scope);
	ELSIF e.kind = TS.ExpressionBinary THEN
		CheckExpression(e.a, scope);
		IF e.op # TS.OpIs THEN CheckExpression(e.b, scope)
		ELSE
			t := ST.FindType(e.b.designator, scope);
			CheckDesignator(e.b.designator, scope);
			IF t = NIL THEN KernelLog.String("pos = "); KernelLog.Int(e.b.designator(TS.Ident).pos.a, 0); KernelLog.String(" Type not found ") END;
		END
	ELSIF e.kind = TS.ExpressionDesignator THEN
		CheckDesignator(e.designator, scope)
	END;
END CheckExpression;

PROCEDURE CheckDesignator(d : TS.Designator; scope : TS.Scope);
VAR no: TS.NamedObject;
	curScope : TS.Scope;
	type, temptype : TS.Type;

	first : BOOLEAN;
	s : ARRAY 64 OF CHAR;
	m : TS.Module;
	te : TS.ExpressionList;
	lastpos : LONGINT;

	PROCEDURE Check(id : TS.Ident; no : TS.NamedObject);
	BEGIN
		IF no = NIL THEN RETURN END;
		localUses.Add(no);
		MakeRange(id.pos.a, id.pos.b, KindUse, no);
	END Check;

BEGIN
	first := TRUE;
	curScope := scope;
	WHILE d # NIL DO
		IF d IS TS.Ident THEN
			lastpos := d(TS.Ident).pos.a;
			TS.s.GetString(d(TS.Ident).name, s);
			IF first & (s = "SELF") THEN
				curScope := scope.parent;
				(* look for object or module represented by SELF*)
				WHILE (curScope.parent # NIL) & (curScope.owner # NIL) &
					~((curScope.owner IS TS.Class) OR (curScope.owner IS TS.Module)) DO
					curScope := curScope.parent
				END;
				IF curScope = NIL THEN
					KernelLog.String("SELF could not be resolved"); KernelLog.Ln;
				END;
			ELSIF first & (s = "SYSTEM") THEN
				d := d.next;
				IF d # NIL THEN
					IF d IS TS.Ident THEN
						TS.s.GetString(d(TS.Ident).name, s);
						IF s = "VAL" THEN
							d := d.next;
							IF d # NIL THEN
								IF d IS TS.ActualParameters THEN
									te := d(TS.ActualParameters).expressionList;
									IF te # NIL THEN
										IF te.expression.kind = TS.ExpressionDesignator THEN
											temptype := ST.FindType(te.expression.designator, scope);
											IF temptype = NIL THEN KernelLog.String("pos = "); KernelLog.Int(te.expression.designator(TS.Ident).pos.a, 0); KernelLog.String(" Type not found ") END;
										END;
										te := te.next;
										CheckExpression(te.expression, scope);
									ELSE
										KernelLog.String("type arameter expeced"); KernelLog.Ln;
									END
								ELSE
									KernelLog.String("parameters expeced"); KernelLog.Ln;
								END
							ELSE
								KernelLog.String("Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(s); KernelLog.String("Ident expeced"); KernelLog.Ln;

							END
						END
					ELSE
						KernelLog.String(s); KernelLog.String("Ident expeced"); KernelLog.Ln;
					END
				ELSE
					KernelLog.String("Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(s); KernelLog.String("incomplete SYSTEM call"); KernelLog.Ln;
				END
			ELSE
				IF curScope # NIL THEN
					no := curScope.Find(s, first);

					IF (no # NIL) & (d.next # NIL) & (d.next IS TS.Dereference) & (no IS TS.ProcDecl) THEN
						no.scope.parent.FixSuperScope;
						IF no.scope.parent.super # NIL THEN
							no := no.scope.parent.super.Find(s, FALSE)
						ELSE KernelLog.String("   super is NIL"); KernelLog.String(s); KernelLog.Ln;
						END
					END;
	 				Check(d(TS.Ident), no);
					IF no # NIL THEN
						IF no IS TS.Var THEN
							type := ST.DealiaseType(no(TS.Var).type);
							IF type # NIL THEN
								IF type.kind = TS.TRecord THEN curScope := type.record.scope
								ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
							END
						ELSIF no IS TS.ProcDecl THEN
							IF no(TS.ProcDecl).signature # NIL THEN
								type := ST.DealiaseType(no(TS.ProcDecl).signature.return);
								IF type # NIL THEN
									IF type.kind = TS.TRecord THEN curScope := type.record.scope
									ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
								END
							END;
						ELSIF no IS TS.Import THEN
							m := TS.GetModule(no(TS.Import));
							IF m # NIL THEN
								curScope := m.scope;
(*										ELSE
								KernelLog.String("No symbol information for : "); KernelLog.String(no(TS.Import).import^); KernelLog.Ln *)
							END
						ELSIF no IS TS.Const THEN
							IF d.next # NIL THEN
							END
(*									ELSE
							KernelLog.String(" Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(" : ");
							KernelLog.String("variable, const or procedure expected but "); ST.ID(no); KernelLog.Ln; *)
						END
					ELSE
					(*	KernelLog.String("named object nil"); KernelLog.String(s); KernelLog.Ln; *)
					END
				ELSE
					KernelLog.String("no scope"); KernelLog.Ln;
				END
			END
		ELSIF d IS TS.Dereference THEN IF d.next # NIL THEN d := d.next END;
		ELSIF d IS TS.Index THEN
			(* automatic dealiasing if index access *)
			IF (type # NIL) & (type.kind = TS.TPointer) THEN
				type := ST.DealiaseType(type.pointer.type) END;
			IF (type = NIL) OR ( type.kind # TS.TArray) THEN
				IF type # NIL THEN ST.ShowType(type) END;
				KernelLog.String("Type is not an array pos= "); KernelLog.Int(lastpos, 0);  KernelLog.Ln
			ELSE
				type := ST.DealiaseType(type.array.base);
				IF type # NIL THEN
					IF type.kind = TS.TRecord THEN curScope := type.record.scope
					ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
				END
			END;
			CheckExpressionList(d(TS.Index).expressionList, NIL,  scope);
		ELSIF d IS TS.ActualParameters THEN
			(* no is the item before "(" *)
			IF no # NIL THEN
				IF no IS TS.ProcDecl THEN
					CheckExpressionList(d(TS.ActualParameters).expressionList, no(TS.ProcDecl).signature, scope)
				ELSIF (no IS TS.Var) THEN
					type := ST.DealiaseType(no(TS.Var).type);
					IF  (type # NIL) & (type.kind = TS.TProcedure) THEN
						(* delegate *)
						IF type.procedure = NIL THEN
							KernelLog.String("no(TS.Var).type.procedure"); KernelLog.Ln;
						ELSIF type.procedure.signature = NIL THEN
							KernelLog.String("no(TS.Var).type.procedure.signature"); KernelLog.Ln;
						ELSE
							CheckExpressionList(d(TS.ActualParameters).expressionList, type.procedure.signature, scope)
						END;
					ELSE (* type guard *)
						IF d(TS.ActualParameters).expressionList # NIL THEN
							IF d(TS.ActualParameters).expressionList.next # NIL THEN
								KernelLog.String("lastpos= "); KernelLog.Int(lastpos, 0);
								KernelLog.String(" Can only guard for one type at once."); KernelLog.Ln
							ELSE
								IF d(TS.ActualParameters).expressionList.expression.kind = TS.ExpressionDesignator THEN
									type := ST.DealiaseType(ST.FindType(d(TS.ActualParameters).expressionList.expression.designator, scope));
									IF type # NIL THEN
										IF type.kind = TS.TRecord THEN curScope := type.record.scope
										ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
									END;
									CheckDesignator(d(TS.ActualParameters).expressionList.expression.designator, scope);
								ELSE
									KernelLog.String("Type expected"); KernelLog.Ln
								END
							END
						ELSE
							KernelLog.String("Expressionlist ist NIL"); KernelLog.Ln
						END						
					END
				ELSE 
				END
			ELSE
				(* not found... fallback *)
				CheckExpressionList(d(TS.ActualParameters).expressionList, NIL, scope)
				(* probably because of a not found
				KernelLog.String("lastpos= "); KernelLog.Int(lastpos, 0);
				KernelLog.String(" No proc"); KernelLog.Ln *)
			END
		END;
		first := FALSE;

		(* Auto dereferencing *)
		IF type # NIL THEN
			IF type.kind = TS.TPointer THEN type := ST.DealiaseType(type.pointer.type) END;
			IF type # NIL THEN
				IF type.kind = TS.TRecord THEN curScope := type.record.scope
				ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
			END
		END;
		d := d.next
	END
END CheckDesignator;

PROCEDURE DumpType*(t : TS.Type; scope : TS.Scope);
BEGIN
	CASE t.kind OF
		|TS.TAlias : CheckDesignator(t.qualident, scope)
		|TS.TObject : DumpObject(t.object)
		|TS.TArray : DumpArray(t.array, scope);
		|TS.TPointer : DumpType(t.pointer.type, scope)
		|TS.TRecord : DumpRecord(t.record);
		|TS.TProcedure : DumpProcedure(t.procedure)
	ELSE
		Trace.String("Unknown Type"); Trace.String("t.kind= "); Trace.Int(t.kind, 0); Trace.Ln;
	END

END DumpType;

PROCEDURE DumpCases(case : TS.Case; scope : TS.Scope);
VAR cr : TS.CaseRange;
BEGIN
	WHILE case # NIL DO
		cr := case.caseRanges;
		WHILE cr # NIL DO
			CheckExpression(cr.a, scope);
			IF cr.b # NIL THEN CheckExpression(cr.b, scope) END;
			cr := cr.next
		END;
		IF case.statements # NIL THEN DumpStatementSequence(case.statements, scope) END;
		case := case.next
	END;
END DumpCases;

PROCEDURE DumpTypeDecl(t : TS.TypeDecl; scope : TS.Scope);
BEGIN
	DumpType(t.type, scope);
END DumpTypeDecl;

PROCEDURE DumpVar(v : TS.Var; scope : TS.Scope);
BEGIN
	DumpType(v.type, scope);
END DumpVar;

PROCEDURE DumpStatementSequence(s : TS.Statement; scope : TS.Scope);
VAR ts : TS.Statement;
BEGIN
	WHILE s # NIL DO
		IF s IS TS.Assignment THEN
			CheckDesignator(s(TS.Assignment).designator, scope);
			CheckExpression(s(TS.Assignment).expression, scope);
		ELSIF s IS TS.ProcedureCall THEN
			CheckDesignator(s(TS.ProcedureCall).designator, scope);
		ELSIF s IS TS.IFStatement THEN
			CheckExpression(s(TS.IFStatement).expression, scope);
			DumpStatementSequence(s(TS.IFStatement).then, scope);
			ts := s(TS.IFStatement).else;
			IF ts # NIL THEN
				DumpStatementSequence(ts, scope);
			END;
		ELSIF s IS TS.WHILEStatement THEN
			CheckExpression(s(TS.WHILEStatement).expression, scope);
			DumpStatementSequence(s(TS.WHILEStatement).statements, scope);
		ELSIF s IS TS.REPEATStatement THEN
			DumpStatementSequence(s(TS.REPEATStatement).statements, scope);
			CheckExpression(s(TS.REPEATStatement).expression, scope);
		ELSIF s IS TS.LOOPStatement THEN
			DumpStatementSequence(s(TS.LOOPStatement).statements, scope);
		ELSIF s IS TS.FORStatement THEN
			CheckDesignator(s(TS.FORStatement).variable, scope);
			CheckExpression(s(TS.FORStatement).fromExpression, scope);
			CheckExpression(s(TS.FORStatement).toExpression, scope);
			IF s(TS.FORStatement).byExpression # NIL THEN
				CheckExpression(s(TS.FORStatement).byExpression, scope);
			END;
			DumpStatementSequence(s(TS.FORStatement).statements, scope);
		ELSIF s IS TS.EXITStatement THEN
		ELSIF s IS TS.RETURNStatement THEN
			IF s(TS.RETURNStatement).expression # NIL THEN CheckExpression(s(TS.RETURNStatement).expression, scope) END;
		ELSIF s IS TS.AWAITStatement THEN
			CheckExpression(s(TS.AWAITStatement).expression, scope);
		ELSIF s IS TS.StatementBlock THEN
			DumpStatementSequence(s(TS.StatementBlock).statements, scope);
		ELSIF s IS TS.WITHStatement THEN
			CheckDesignator(s(TS.WITHStatement).variable, scope);
			CheckDesignator(s(TS.WITHStatement).type, scope);
			DumpStatementSequence(s(TS.WITHStatement).statements, scope);
		ELSIF s IS TS.CASEStatement THEN
			CheckExpression(s(TS.CASEStatement).expression, scope);
			DumpCases(s(TS.CASEStatement).cases, scope);
			IF s(TS.CASEStatement).else # NIL THEN
				DumpStatementSequence(s(TS.CASEStatement).else, scope)
			END;
		END;
		NoteCommentRanges(s.preComment);
		NoteCommentRanges(s.postComment);
		s := s.next
	END
END DumpStatementSequence;

PROCEDURE CheckSignature(sig : TS.ProcedureSignature; scope : TS.Scope);
VAR i : LONGINT; cur : TS.NamedObject; t : TS.Type;
BEGIN
	IF sig = NIL THEN RETURN END;
	IF sig.return # NIL THEN DumpType(sig.return, scope) END;
	IF sig.params # NIL THEN
		t := NIL;
		FOR i := 0 TO sig.params.nofObjs - 1 DO
			cur := sig.params.objs[i];
			NoteDeclaration(cur);
			IF cur IS TS.Var THEN IF t # cur(TS.Var).type THEN DumpType(cur(TS.Var).type, scope) END; t := cur(TS.Var).type
			ELSE KernelLog.String("non- variable as a parameter"); KernelLog.Ln
			END
		END
	END
END CheckSignature;

PROCEDURE DumpProcDecl(p : TS.ProcDecl);
VAR s : TS.Statement;
	cur : TS.NamedObject; i : LONGINT;
BEGIN
	CheckSignature(p.signature, p.scope.parent);
	(*IF (p.signature # NIL) & (p.signature.params # NIL) THEN
		FOR i := 0 TO p.signature.params.nofObjs - 1 DO
			cur := p.signature.params.objs[i];
			NoteDeclaration(cur);
		END
	END;*)

	DumpDeclarations(p.scope);

	IF p.scope.ownerBody # NIL THEN
		s := p.scope.ownerBody;
		DumpStatementSequence(s, p.scope)
	END;
END DumpProcDecl;

PROCEDURE DumpDeclarations(d : TS.Scope);
VAR i : LONGINT;
	last, cur : TS.NamedObject;
BEGIN
	IF d = NIL THEN RETURN END;
	FOR i := 0 TO d.elements.nofObjs - 1 DO
		cur := d.elements.objs[i];
		CommentsFromNamedObject(cur);
		NoteDeclaration(cur);
		IF cur IS TS.Const THEN
			DumpConst(d, cur(TS.Const))
		ELSIF cur IS TS.TypeDecl THEN
			DumpTypeDecl(cur(TS.TypeDecl), d);
		ELSIF cur IS TS.Var THEN
			DumpVar(cur(TS.Var), d)
		ELSIF cur IS TS.ProcDecl THEN
			DumpProcDecl(cur(TS.ProcDecl))
		ELSIF cur IS TS.Import THEN
		END;
		last := cur;
	END
END DumpDeclarations;

PROCEDURE NoteCommentRanges(comments : TS.Comments);
VAR cur : TS.Comment;
	r : Streams.StringReader;
	token : ARRAY 32 OF CHAR;
BEGIN
	IF comments = NIL THEN RETURN END;
	cur := comments.first;
	WHILE cur # NIL DO
		IF (currentAuthor = "") & (Strings.Pos("AUTHOR", cur.str^) >= 0) THEN
			IF Strings.Pos("PURPOSE", cur.str^) >= 0 THEN
				NEW(r, LEN(cur.str^));
				r.Set(cur.str^);
				
				WHILE r.res # Streams.EOF DO
					r.SkipWhitespace;
					r.Token(token);
					r.SkipWhitespace;
					IF token = "AUTHOR" THEN
						r.String(currentAuthor);
						KernelLog.String("currentAuthor= "); KernelLog.String(currentAuthor); KernelLog.Ln; 
					ELSIF token = "PURPOSE" THEN
						r.String(currentPurpose);
						KernelLog.String("currentPurpose= "); KernelLog.String(currentPurpose); KernelLog.Ln;
					END
				END
			END
		END;
		MakeRange(cur.pos.a, cur.pos.b, KindComment, NIL);
		cur := cur.next
	END
END NoteCommentRanges;

PROCEDURE CommentsFromNamedObject(no : TS.NamedObject);
BEGIN
	NoteCommentRanges(no.preComment);
	NoteCommentRanges(no.postComment);
END CommentsFromNamedObject;

PROCEDURE NoteDeclaration(no : TS.NamedObject);
BEGIN
	MakeRange(no.pos.a, no.pos.b, KindDeclaration, no);
END NoteDeclaration;

PROCEDURE DumpM*(m : TS.Module);
BEGIN
	CommentsFromNamedObject(m);
	NoteDeclaration(m);
	DumpDeclarations(m.scope);
	IF m.scope.ownerBody # NIL THEN
		DumpStatementSequence(m.scope.ownerBody, m.scope)
	END
END DumpM;

PROCEDURE DumpLocalUses;
VAR i : LONGINT;
	filename, scopePath, name, path : ARRAY 1024 OF CHAR;
	a : ANY;
	u : GlobalUse;
BEGIN
	FOR i := 0 TO localUses.nof - 1 DO
		ST.GetSourceReference(localUses.items[i], filename, scopePath);
		a := globalUses.Find(scopePath);
		IF a = NIL THEN
			NEW(u);
			globalUses.Add(scopePath, u);
		ELSE
			u := a(GlobalUse);
		END;
		u.AddFile(filename);
	END;
END DumpLocalUses;


PROCEDURE GenerateModule(module : TS.Module; r : Streams.Reader; out : Streams.Writer);
VAR ch : CHAR;
	w : Streams.Writer;
	currentRange, pos, nextEnd : LONGINT;
	inRange, inComment, lastInRange : BOOLEAN;
	token : ARRAY 1024 OF CHAR;
	filename, scopePath, name, path : ARRAY 1024 OF CHAR;
	i : LONGINT;
	referencedModule : TS.Module;
CONST DoXml = TRUE;
BEGIN
	(* Source files > 1MB are not supported *)
	NEW(localUses);
	IF ranges = NIL THEN NEW(ranges, 1000000)
	ELSE
		FOR i := 0 TO LEN(ranges) - 1 DO
			ranges[i].kind := KindNoStart;
			ranges[i].no := NIL
		END
	END;
	DumpM(module);
	IF out = NIL THEN
		NEW(ml, module.name^, w);
	ELSE
		w := out;
	END;
	pos := 0;
	inRange := FALSE; lastInRange := FALSE; inComment := FALSE;
	IF DoXml THEN
		w.String('<!DOCTYPE html>'); w.Ln;
		w.String('<html>'); w.Ln();
		w.String('  <head>'); w.Ln();
		w.String('    <title>'); w.String(module.name^); w.String('</title>'); w.Ln();
		w.String('    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>'); w.Ln();
		w.String('    <link rel="stylesheet" href="code.css" type="text/css" media="screen"/>'); w.Ln();
		w.String('    <script src="highlight.js"> </script>'); w.Ln();
		w.String('  </head>'); w.Ln();
		w.String('<body onLoad="setup();">'); w.Ln();
		w.String('<nav>'); w.Ln();
		w.String('  <div class="menu">'); w.Ln();
		w.String('    <ul>'); w.Ln();
		w.String('      <li><a href="index.html">Index</a></li>'); w.Ln();
		w.String('    </ul>'); w.Ln();
		w.String('  </div>'); w.Ln();
		w.String('</nav>'); w.Ln();
		w.String('<div class="scroll"><code><pre>'); w.Ln();
	END;
	ch := r.Get();
	REPEAT
		IF ~inRange THEN
			IF (ranges[pos].kind # KindNoStart) & (ranges[pos].b > pos) THEN
				inRange := TRUE;
				currentRange := pos;
				nextEnd := ranges[pos].b;
				CASE ranges[pos].kind OF
					| KindComment :
						w.String('<span class="comment">');
						inComment := TRUE;
					| KindDeclaration:
						ST.GetSourceReference(ranges[pos].no, filename, scopePath);
						Files.SplitPath(filename, path, name);
						w.String('<a name="'); w.String(scopePath);w.String('">');
					| KindUse :
						scopePath := ""; filename := "";
						IF ranges[pos].no.container # TFAOParser.Universe THEN
							IF ranges[pos].no IS TS.Import THEN
								referencedModule := TS.GetModule(ranges[pos].no(TS.Import));
								IF referencedModule # NIL THEN
									COPY(referencedModule.name^, scopePath);
									IF referencedModule.filename # NIL THEN
										COPY(referencedModule.filename^, filename)
									END
								END
							ELSE
								ST.GetSourceReference(ranges[pos].no, filename, scopePath);
							END;
							Files.SplitPath(filename, path, name);
							w.String('<a href="'); w.String(name); w.String('.html#'); w.String(scopePath); w.String('">');
						END
				END
			END
		ELSE
			IF pos = nextEnd THEN
				IF token # "" THEN
					w.String(token);
					token := "";
				END;
				CASE ranges[currentRange].kind OF
					| KindComment :
						w.String('</span>');
					| KindDeclaration:
						w.String('</a>');
					| KindUse:
						IF ranges[currentRange].no.container # TFAOParser.Universe THEN
							w.String('</a>');
						END
				END;
				inRange := FALSE;
				inComment := FALSE;
			END
		END;

		IF ~inComment THEN
			IF ~S.reservedChar[ORD(ch)] THEN
				Strings.AppendChar(token, ch);
				WHILE ~S.newChar[ORD(ch)] DO
					ch := r.Get();
					Strings.AppendChar(token, ch);
				END
			ELSE
				IF IsKeyWord(token) THEN
					w.String('<span class="keyword">');
					w.String(token);
					w.String('</span>');
				ELSE
					w.String(token);
				END;
				token := "";
				IF ch = "<" THEN w.String("&lt;")
				ELSE	w.Char(ch)
				END;
				WHILE ~S.newChar[ORD(ch)] DO
					ch := r.Get();
					w.Char(ch);
				END
			END
		ELSE
			IF ch = "<" THEN w.String("&lt;")
			ELSE	w.Char(ch)
			END;
			WHILE ~S.newChar[ORD(ch)] DO
				ch := r.Get();
				w.Char(ch);
			END
		END;
		INC(pos);
		ch := r.Get();
	UNTIL r.res # 0;
	IF DoXml THEN
		w.String('</pre></code>'); w.Ln();
		w.String('<div class="footer">'); PageTime(w); w.String('</div>');
		w.String("</div></body></html>"); w.Ln();
	END;
	w.Update;

	DumpLocalUses;
END GenerateModule;

PROCEDURE InitWithText(t: Texts.Text; pos: LONGINT): Strings.String;
	VAR buffer: Strings.String; len, i, j, ch: LONGINT; r: Texts.TextReader;
	bytesPerChar: LONGINT;

	PROCEDURE ExpandBuf(VAR oldBuf: Strings.String; newSize: LONGINT);
	VAR newBuf: Strings.String; i: LONGINT;
	BEGIN
		IF LEN(oldBuf^) >= newSize THEN RETURN END;
		NEW(newBuf, newSize);
		FOR i := 0 TO LEN(oldBuf^)-1 DO
			newBuf[i] := oldBuf[i];
		END;
		oldBuf := newBuf;
	END ExpandBuf;
BEGIN
	t.AcquireRead;
	len := t.GetLength();
	bytesPerChar := 2;
	NEW(buffer, len * bytesPerChar);	(* UTF8 encoded characters use up to 5 bytes *)
	NEW(r, t);
	r.SetPosition(pos);
	j := 0;
	FOR i := 0 TO len-1 DO
		r.ReadCh(ch);
		WHILE ~UTF8Strings.EncodeChar(ch, buffer^, j) DO
				(* buffer too small *)
			INC(bytesPerChar);
			ExpandBuf(buffer, bytesPerChar * len);
		END;
	END;
	t.ReleaseRead;
	RETURN buffer;
END InitWithText;

PROCEDURE ProcessFile(CONST filename, targetPath : ARRAY OF CHAR; indexFile : Streams.Writer);
VAR
	module : TS.Module;
	t : Texts.Text; res : LONGINT;
	r : Streams.StringReader;
	str : Strings.String;
	name, path, targetFile : ARRAY 1024 OF CHAR;
	f : Files.File;
	fw : Files.Writer;
	trap : BOOLEAN;
BEGIN
	KernelLog.String("filename= "); KernelLog.String(filename); KernelLog.Ln;
	NEW(t);
	Files.SplitPath(filename, path, name);
	Files.JoinPath(targetPath, name, targetFile);
	Strings.Append(targetFile, ".html");
	TFAOParser.ScanModule(filename, FALSE, module);
	IF module # NIL THEN
		module.filename := Strings.NewString(filename);
		TextUtilities.LoadAuto(t, filename, res, res);
		str := InitWithText(t, 0);
		NEW(r, Strings.Length(str^));
		r.Set(str^);
		f := Files.New(targetFile);
		Files.OpenWriter(fw, f, 0);
		currentAuthor := "";
		currentPurpose := "";
		GenerateModule(module, r, fw);
		IF (indexFile # NIL) THEN 
			indexFile.String('<tr><td><a href="'); indexFile.String(name); indexFile.String('.html">');
			indexFile.String(module.name^); indexFile.String('</a></td><td>');
			indexFile.String(currentPurpose); indexFile.String('</td><td>');
			indexFile.String(currentAuthor); indexFile.String('</td></tr>');
			indexFile.Ln
		END;
		fw.Update();
		Files.Register(f)
	END;
FINALLY
	IF trap THEN (* trap will be set in case a trap occurs in the block above *)
		KernelLog.String("Parse error for "); KernelLog.String(filename);  KernelLog.Ln;
	END
END ProcessFile;


PROCEDURE Generate*(par : Commands.Context) ;
VAR
	filename :ARRAY 256 OF CHAR;
	sr : Streams.Reader;
	t0, t1 : LONGINT;
	module : TS.Module;
	t : Texts.Text; res : LONGINT;
	textReader : TextUtilities.TextReader;
BEGIN
	NEW(globalUses);
	sr := par.arg;
	sr.String(filename);
	KernelLog.String("Parsing "); KernelLog.String(filename);
	t0 := Kernel.GetTicks();

	NEW(t);
	TFAOParser.ScanModule(filename, FALSE, module);
	IF module # NIL THEN
		module.filename := Strings.NewString(filename);
		TextUtilities.LoadAuto(t, filename, res, res);
		NEW(textReader, t);
		GenerateModule(module, textReader, NIL);
		TFDocGenerator.DocumentModule(module);
	END;
	t1 := Kernel.GetTicks();
	KernelLog.String("t1-t0= "); KernelLog.Int(t1-t0, 0); KernelLog.Ln;
	KernelLog.String(" done.");
END Generate;

(** Make sure to have built all the TFPET Symbol files first *)
PROCEDURE MakeXRef*(par : Commands.Context) ;
VAR e : Files.Enumerator;
	path, name, exclude : ARRAY 256 OF CHAR; flags : SET; time, date, size : LONGINT;
	sr : Streams.Reader;
	indexFileWriter : Files.Writer;
	f : Files.File;
BEGIN
	NEW(globalUses);
	sr := par.arg;
	sr.String(path); sr.SkipWhitespace();
	sr.String(exclude);
	IF (path # "") & ~Strings.EndsWith("/", path) THEN Strings.Append(path, "/") END;
	Strings.Append(path, "*.Mod");
	KernelLog.String(path); KernelLog.Ln;
	IF exclude # "" THEN
		KernelLog.String("Excluding "); KernelLog.String(exclude); KernelLog.Ln;
	END;
	NEW(e);
	e.Open(path, {});
	KernelLog.String("Processing ... "); KernelLog.Ln;
	f := Files.New("xref/index.html");
	Files.OpenWriter(indexFileWriter, f, 0);
	
	indexFileWriter.String("<html><table>"); indexFileWriter.Ln;
	WHILE e.HasMoreEntries() DO
		IF e.GetEntry(name, flags, time, date, size) THEN
			IF (exclude = "") OR ~Strings.Match(exclude, name) THEN
				(*AddTask(name);*)

				ProcessFile(name, "xref", indexFileWriter);

			ELSE
				KernelLog.String("Excluding "); KernelLog.String(name); KernelLog.Ln;
			END
		END
	END;
	indexFileWriter.String("</table></html>"); indexFileWriter.Ln;
	indexFileWriter.Update;
	Files.Register(f)
END MakeXRef;

PROCEDURE PageTime(out : Streams.Writer);
VAR dateTimeStr : ARRAY 32 OF CHAR;
BEGIN
	Strings.FormatDateTime("yyyy.mm.dd hh:nn:ss", Dates.Now(), dateTimeStr);
	out.String(dateTimeStr)
END PageTime;

PROCEDURE IsKeyWord(CONST str : ARRAY OF CHAR) : BOOLEAN;
VAR s : LONGINT;
BEGIN
	s := 0;
	IF str = "ARRAY" THEN s := S.array
	ELSIF str = "AWAIT" THEN s := S.passivate
	ELSIF str = "BEGIN" THEN s := S.begin
	ELSIF str = "BY" THEN s := S.by
	ELSIF str = "CONST" THEN s := S.const
	ELSIF str = "CASE" THEN s := S.case
	ELSIF str = "CODE" THEN s := S.code
	ELSIF str = "DO" THEN s := S.do
	ELSIF str = "DIV" THEN s := S.div
	ELSIF str = "DEFINITION" THEN s := S.definition
	ELSIF str = "END" THEN s := S.end
	ELSIF str = "ELSE" THEN s := S.else
	ELSIF str = "ELSIF" THEN s := S.elsif
	ELSIF str = "EXIT" THEN s := S.exit
	ELSIF str = "FALSE" THEN s := S.false
	ELSIF str = "FOR" THEN s := S.for
	ELSIF str = "IF" THEN s := S.if
	ELSIF str = "IN" THEN s := S.in
	ELSIF str = "IS" THEN s := S.is
	ELSIF str = "IMPORT" THEN s := S.import
	ELSIF str = "IMPLEMENTS" THEN s := S.implements
	ELSIF str = "LOOP" THEN s := S.loop
	ELSIF str = "MOD" THEN s := S.mod
	ELSIF str = "MODULE" THEN s := S.module
	ELSIF str = "NIL" THEN s := S.nil
	ELSIF str = "OR" THEN s := S.or
	ELSIF str = "OF" THEN s := S.of
	ELSIF str = "OBJECT" THEN s := S.object
	ELSIF str = "PROCEDURE" THEN s := S.procedure
	ELSIF str = "POINTER" THEN s := S.pointer
	ELSIF str = "RECORD" THEN s := S.record
	ELSIF str = "REPEAT" THEN s := S.repeat
	ELSIF str = "RETURN" THEN s := S.return
	ELSIF str = "REFINES" THEN s := S.refines
	ELSIF str = "THEN" THEN s := S.then
	ELSIF str = "TRUE" THEN s := S.true
	ELSIF str = "TO" THEN s := S.to
	ELSIF str = "TYPE" THEN s := S.type
	ELSIF str = "UNTIL" THEN s := S.until
	ELSIF str = "VAR" THEN s := S.var
	ELSIF str = "WHILE" THEN s := S.while
	ELSIF str = "WITH" THEN s := S.with
	END;
	RETURN s # 0
END IsKeyWord;

END TFXRef.

(* Make sure the TFPET symbol files are available (takes a few minutes) *)
TFAOParser.MakeSymbolFiles "D:\Aos\trunk\source\" "*Oberon*"~ (* d:/release/*.Mod *)

SystemTools.Free TFXRef TFDocGenerator~
TFXRef.MakeXRef "D:\Aos\trunk\source\" "*Oberon*"~
TFXRef.Generate HelloWorld.Mod ~
TFXRef.Generate I386.VMWareTools.Mod ~
 TFXRef.Generate TFModuleTrees.Mod ~
  TFXRef.Generate String.Mod ~