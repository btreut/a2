MODULE TFCheck;

IMPORT
	TS := TFTypeSys, ST := TFScopeTools, Trace;

(*PROCEDURE GetScope(type : TS.Type; scope : TS.Scope) : TS.Scope;
BEGIN
	IF type # NIL THEN
		IF type.kind = TS.TRecord THEN
			RETURN type.record.scope
		ELSIF type.kind = TS.TObject THEN
			IF type.object = NIL THEN
				Trace.String("Object field of an object type is NIL. Who did this???"); Trace.Ln;
				RETURN NIL
			END;
			RETURN type.object.scope
		ELSIF type.kind = TS.TAlias THEN
			RETURN GetScope(FindType(type.qualident, scope), scope);
		ELSIF type.kind = TS.TArray THEN
			RETURN GetScope(type.array.base, scope)
		ELSIF type.kind = TS.TPointer THEN
			RETURN GetScope(type.pointer.type, scope)
		ELSE
			(* Trace.String("unexpected type = "); ShowType(type); Trace.Ln; *)
			RETURN NIL
		END
	ELSE RETURN NIL
	END
END GetScope;
*)

PROCEDURE CheckExpressionList(e : TS.ExpressionList; scope : TS.Scope);
BEGIN
	WHILE e # NIL DO
		CheckExpression(e.expression, scope);
		e := e.next
	END
END CheckExpressionList;

PROCEDURE CheckExpression(e : TS.Expression; scope : TS.Scope);
BEGIN
	IF e = NIL THEN Trace.String("Expression is NIL"); RETURN END;
	IF e.kind = TS.ExpressionPrimitive THEN
	ELSIF e.kind = TS.ExpressionUnary THEN
		CheckExpression(e.a, scope);
	ELSIF e.kind = TS.ExpressionBinary THEN
		CheckExpression(e.a, scope);
		CheckExpression(e.b, scope);
	ELSIF e.kind = TS.ExpressionDesignator THEN
		CheckDesignator(e.designator, scope)
	END;
END CheckExpression;

PROCEDURE CheckSuperClass(o : TS.Class; scope : TS.Scope);
VAR st : TS.Type;
BEGIN
	IF (o.scope.super = NIL) THEN
	(*	Trace.String("Searching for super type :");  ST.ShowDesignator(o.super); Trace.Ln;
		st := DealiaseType(FindType(o.super, scope)); *)
		IF st # NIL THEN
			IF st.kind = TS.TObject THEN
				o.scope.super := st.object.scope;
			ELSE Trace.String("super type is not an class"); Trace.Ln;
			END
		ELSE Trace.String("No information about super type "); Trace.Ln;
		END
	END
END CheckSuperClass;


			PROCEDURE GetModule(imp : TS.Import) : TS.Module;
			VAR m : TS.Module;
			BEGIN
				m := TS.ns.GetModule(imp.import^);
				IF m = NIL THEN
					m := TS.ReadSymbolFile(imp.import^);
					IF m # NIL THEN
(*						m.scope.parent := TFAOParser.Universe; *)
						TS.ns.AddModule(m)
					END;
				END;
				RETURN m
			END GetModule;

			PROCEDURE FindType(d : TS.Designator; scope : TS.Scope) : TS.Type;
			VAR first : BOOLEAN;
				no : TS.NamedObject;
				currentScope : TS.Scope;
				s : ARRAY 64 OF CHAR;
				m : TS.Module;
			BEGIN
				TS.s.GetString(d(TS.Ident).name,s);
				no := scope.Find(s, TRUE);
				IF no = NIL THEN RETURN NIL END;
				(* follow import *)
				IF no IS TS.Import THEN m := GetModule(no(TS.Import));
					IF m = NIL THEN RETURN NIL END;
					scope := m.scope;
					IF scope # NIL THEN
						d := d.next;
						TS.s.GetString(d(TS.Ident).name,s);
						no := scope.Find(s, FALSE);
					END
				END;
				IF no = NIL THEN RETURN NIL END;
				IF no IS TS.TypeDecl THEN
					IF no(TS.TypeDecl).type.kind = TS.TObject THEN CheckSuperClass(no(TS.TypeDecl).type.object, no.container) END;
					RETURN no(TS.TypeDecl).type
				END;
				RETURN NIL
			END FindType;

			PROCEDURE DealiaseType(t : TS.Type) : TS.Type;
			BEGIN
				IF t = NIL THEN RETURN NIL END;
				IF t.kind = TS.TAlias THEN
					RETURN DealiaseType(FindType(t.qualident, t.container))
				ELSE RETURN t
				END
			END DealiaseType;


PROCEDURE CheckDesignator(d : TS.Designator; scope : TS.Scope);
VAR no, co : TS.NamedObject;
	curScope : TS.Scope;
	type, temptype : TS.Type;

	td : TS.TypeDecl;
	first : BOOLEAN;
	trace : BOOLEAN;
	s : ARRAY 64 OF CHAR;
	m : TS.Module;
	te : TS.ExpressionList;
	lastpos : LONGINT;
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
					Trace.String("SELF could not be resolved"); Trace.Ln;
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
											temptype := FindType(te.expression.designator, scope);
											IF temptype = NIL THEN Trace.String("pos = "); Trace.Int(te.expression.designator(TS.Ident).pos.a, 0); Trace.String(" Type not found ") END;
										END;
										te := te.next;
										CheckExpression(te.expression, scope);
									ELSE
										Trace.String("type arameter expeced"); Trace.Ln;
									END
								ELSE
									Trace.String("parameters expeced"); Trace.Ln;
								END
							ELSE
								Trace.String("Pos= "); Trace.Int(d(TS.Ident).pos.a, 0);  Trace.String(s); Trace.String("Ident expeced"); Trace.Ln;

							END
						END
					ELSE
						Trace.String(s); Trace.String("Ident expeced"); Trace.Ln;
					END
				ELSE
					Trace.String("Pos= "); Trace.Int(d(TS.Ident).pos.a, 0);  Trace.String(s); Trace.String("incomplete SYSTEM call"); Trace.Ln;
				END
			ELSE
				IF curScope # NIL THEN
					no := curScope.Find(s, first);
					IF no # NIL THEN  (*Trace.String("found");*) ELSE
						Trace.String(" Pos= "); Trace.Int(d(TS.Ident).pos.a, 0);  Trace.String(s); Trace.String("not found"); Trace.Ln;
					END;
					IF no # NIL THEN
						IF no IS TS.Var THEN
							type := DealiaseType(no(TS.Var).type);
							IF type # NIL THEN
								IF type.kind = TS.TRecord THEN curScope := type.record.scope
								ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
							END
						ELSIF no IS TS.ProcDecl THEN
							IF no(TS.ProcDecl).signature # NIL THEN
								type := DealiaseType(no(TS.ProcDecl).signature.return);
								IF type # NIL THEN
									IF type.kind = TS.TRecord THEN curScope := type.record.scope
									ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
								END
							END;
						ELSIF no IS TS.Import THEN
							m := GetModule(no(TS.Import));
							IF m # NIL THEN
								curScope := m.scope;
							ELSE
								Trace.String("No symbol information for : "); Trace.String(no(TS.Import).import^); Trace.Ln
							END
						ELSIF no IS TS.Const THEN
							IF d.next # NIL THEN
								Trace.String(" Pos= "); Trace.Int(d(TS.Ident).pos.a, 0);  Trace.String(" is not an array or record"); Trace.Ln;
							END
						ELSE
							Trace.String(" Pos= "); Trace.Int(d(TS.Ident).pos.a, 0);  Trace.String(" : ");
							Trace.String("variable, const or procedure expected but "); ST.ID(no); Trace.Ln;
						END
					END
				ELSE
					Trace.String("no scope"); Trace.Ln;
				END
			END
		ELSIF d IS TS.Dereference THEN
			IF d.next # NIL THEN d := d.next END;
			IF type # NIL THEN
				IF type.kind = TS.TPointer THEN type := DealiaseType(type.pointer.type) END;
				IF type # NIL THEN
					IF type.kind = TS.TRecord THEN curScope := type.record.scope
					ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
				END

			END
		ELSIF d IS TS.Index THEN
			(* automatic dealiasing if index access *)
			IF (type # NIL) & (type.kind = TS.TPointer) THEN type := DealiaseType(type.pointer.type) END;
			IF (type = NIL) OR ( type.kind # TS.TArray) THEN
				IF type # NIL THEN ST.ShowType(type) END;
				Trace.String("Type is not an array"); Trace.Ln
			ELSE
				type := DealiaseType(type.array.base);
				IF type # NIL THEN
					IF type.kind = TS.TRecord THEN curScope := type.record.scope
					ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
				END
			END;
			CheckExpressionList(d(TS.Index).expressionList, scope);
		ELSIF d IS TS.ActualParameters THEN
			IF no # NIL THEN
				IF no IS TS.ProcDecl THEN
					CheckExpressionList(d(TS.ActualParameters).expressionList, scope)
				ELSE (* type guard *)
					IF d(TS.ActualParameters).expressionList # NIL THEN
						IF d(TS.ActualParameters).expressionList.next # NIL THEN
							Trace.String("Can only guard for one type at once."); Trace.Ln
						ELSE
							IF d(TS.ActualParameters).expressionList.expression.kind = TS.ExpressionDesignator THEN
								type := DealiaseType(FindType(d(TS.ActualParameters).expressionList.expression.designator, scope));
								IF type # NIL THEN
									IF type.kind = TS.TRecord THEN curScope := type.record.scope
									ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
								END
							ELSE
								Trace.String("Type expected"); Trace.Ln
							END
						END
					ELSE
						Trace.String("Expressionlist ist NIL"); Trace.Ln
					END
				END
			ELSE (* probably because of a not found
				Trace.String("lastpos= "); Trace.Int(lastpos, 0);
				Trace.String(" No proc"); Trace.Ln *)
			END
		END;
		first := FALSE;

		d := d.next;
	END
END CheckDesignator;


PROCEDURE Generate(s : TS.Statement; scope : TS.Scope);
VAR ts : TS.Statement; t, origType : TS.Type;
BEGIN
	WHILE s # NIL DO
		IF s IS TS.Assignment THEN
			CheckDesignator(s(TS.Assignment).designator, scope);
			CheckExpression(s(TS.Assignment).expression, scope);
		ELSIF s IS TS.ProcedureCall THEN
			CheckDesignator(s(TS.ProcedureCall).designator, scope)
		ELSIF s IS TS.StatementBlock THEN
			Generate(s(TS.StatementBlock).statements, scope);
		ELSIF s IS TS.IFStatement THEN
			CheckExpression(s(TS.IFStatement).expression, scope);
			Generate(s(TS.IFStatement).then, scope);
			ts := s(TS.IFStatement).else;
			IF ts # NIL THEN
				Generate(ts, scope);
			END;
		ELSIF s IS TS.WHILEStatement THEN
			CheckExpression(s(TS.WHILEStatement).expression, scope);
			Generate(s(TS.WHILEStatement).statements, scope);
		ELSIF s IS TS.REPEATStatement THEN
			Generate(s(TS.REPEATStatement).statements, scope);
			CheckExpression(s(TS.REPEATStatement).expression, scope);
		ELSIF s IS TS.LOOPStatement THEN
			Generate(s(TS.LOOPStatement).statements, scope);
		ELSIF s IS TS.FORStatement THEN
			CheckDesignator(s(TS.FORStatement).variable, scope);
			CheckExpression(s(TS.FORStatement).fromExpression, scope);
			CheckExpression(s(TS.FORStatement).toExpression, scope);
			IF s(TS.FORStatement).byExpression # NIL THEN
				CheckExpression(s(TS.FORStatement).byExpression, scope);
			END;
			Generate(s(TS.FORStatement).statements, scope);
		ELSIF s IS TS.RETURNStatement THEN
			IF s(TS.RETURNStatement).expression # NIL THEN CheckExpression(s(TS.RETURNStatement).expression, scope) END;
		ELSIF s IS TS.AWAITStatement THEN
			CheckExpression(s(TS.AWAITStatement).expression, scope);
		ELSIF s IS TS.WITHStatement THEN
			CheckDesignator(s(TS.WITHStatement).variable, scope);

			t := FindType(s(TS.WITHStatement).type, scope);

			IF t = NIL THEN Trace.String("pos = "); Trace.Int(s(TS.WITHStatement).type(TS.Ident).pos.a, 0); Trace.String(" Type not found ") END;
			Generate(s(TS.WITHStatement).statements, scope);
		ELSIF s IS TS.CASEStatement THEN
			CheckExpression(s(TS.CASEStatement).expression, scope);
		(*	CheckCases(s(TS.CASEStatement).cases, scope); *)
			IF s(TS.CASEStatement).else # NIL THEN
				Generate(s(TS.CASEStatement).else, scope)
			END;
		END;
		s := s.next
	END
END Generate;


PROCEDURE CheckProcedure(p : TS.ProcDecl);
VAR s : TS.Statement;
BEGIN

END CheckProcedure;

PROCEDURE CheckType*(t : TS.Type);
BEGIN
	CASE t.kind OF
		|TS.TAlias :
		|TS.TObject : CheckSuperClass(t.object, t.container); CheckDeclarations(t.object.scope)
		|TS.TArray :
		|TS.TPointer : (*DumpType(t.pointer.type) *)
		|TS.TRecord : (*CheckDeclarations(t.record.fields) *)
		|TS.TProcedure : (* CheckDeclarations(t.procedure.scope)*)
	ELSE
		Trace.String("t.kind= "); Trace.Int(t.kind, 0); Trace.Ln;
	END
END CheckType;


PROCEDURE CheckDeclarations*(d : TS.Scope);
VAR i : LONGINT;
	last, cur : TS.NamedObject;
BEGIN
	IF d = NIL THEN RETURN END;
	IF d.ownerBody # NIL THEN Generate( d.ownerBody, d) END;
	FOR i := 0 TO d.elements.nofObjs - 1 DO
		cur := d.elements.objs[i];
		IF cur IS TS.Const THEN
		ELSIF cur IS TS.TypeDecl THEN CheckType(cur(TS.TypeDecl).type)


		ELSIF cur IS TS.Var THEN
		ELSIF cur IS TS.ProcDecl THEN CheckDeclarations(cur(TS.ProcDecl).scope);
		END;
		last := cur;
	END
END CheckDeclarations;


END TFCheck.
