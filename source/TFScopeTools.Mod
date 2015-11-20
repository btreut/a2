MODULE TFScopeTools;

IMPORT
	KernelLog, TS := TFTypeSys, Strings;
	

PROCEDURE FindType*(d : TS.Designator; scope : TS.Scope) : TS.Type;
VAR
	no : TS.NamedObject;
	s : ARRAY 64 OF CHAR;
	m : TS.Module;
BEGIN
	IF (scope = NIL) OR  (d = NIL) THEN RETURN NIL END;
	TS.s.GetString(d(TS.Ident).name,s);

	no := scope.Find(s, TRUE);

	IF no = NIL THEN RETURN NIL END;
	(* follow import *)
	IF no IS TS.Import THEN m := TS.GetModule(no(TS.Import));

		IF m = NIL THEN RETURN NIL END;
		scope := m.scope;
		IF scope # NIL THEN
			d := d.next;
			WHILE (d # NIL) & (scope # NIL) DO
				TS.s.GetString(d(TS.Ident).name,s);
				no := scope.Find(s, FALSE);
				IF no # NIL THEN
					scope := no.scope;
				ELSE scope := NIL
				END
			END
		END
	END;
	IF no = NIL THEN RETURN NIL END;
	IF no IS TS.TypeDecl THEN
		RETURN no(TS.TypeDecl).type
	END;
	RETURN NIL
END FindType;

PROCEDURE DealiaseType*(t : TS.Type) : TS.Type;
VAR pos : LONGINT;
BEGIN
	pos := -1;
	IF t = NIL THEN RETURN NIL END;
	IF t.container = NIL THEN RETURN NIL END;
	IF (t.container # NIL)  & (t.container.owner # NIL) THEN
		pos := t.container.owner.pos.a
	END;

	IF t.kind = TS.TAlias THEN
		RETURN DealiaseType(FindType(t.qualident, t.container))
	ELSE RETURN t
	END
END DealiaseType;

PROCEDURE ShowDesignator*(d : TS.Designator);
VAR s : ARRAY 64 OF CHAR;
BEGIN
	IF d IS TS.Ident THEN TS.s.GetString(d(TS.Ident).name, s); KernelLog.String(s)
	ELSIF d IS TS.Index THEN
		KernelLog.String("[");
		KernelLog.String("]");
	ELSIF d IS TS.ActualParameters THEN
		KernelLog.String("(");
		KernelLog.String(")");
	END;
	IF (d.next # NIL) THEN
		IF (d IS TS.Ident) THEN KernelLog.String(".") END;
		ShowDesignator(d.next)
	END
END ShowDesignator;

PROCEDURE ShowType*(t : TS.Type);
BEGIN
	KernelLog.String("{");
	CASE t.kind OF
		|TS.TBasic : KernelLog.String("Basic type "); KernelLog.Int(t.basicType, 0);
		|TS.TAlias : KernelLog.String("Alias to "); ShowDesignator(t.qualident)
		|TS.TObject : KernelLog.String("OBJECT");
		|TS.TArray : KernelLog.String("[]");
		|TS.TPointer : KernelLog.String("POINTER TO ");
		|TS.TRecord :  KernelLog.String("RECORD");
		|TS.TProcedure : KernelLog.String("PROCEDURE");
	ELSE KernelLog.String("UNKNOWN");
	END;
	KernelLog.String("}");
END ShowType;

PROCEDURE GetSourceReference*(no : TS.NamedObject; VAR filename, scopePath : ARRAY OF CHAR );
VAR s : TS.Scope;
	stack : ARRAY 32 OF TS.NamedObject;
	tos : LONGINT;
BEGIN
	scopePath := "";
	filename := "";
	IF no = NIL THEN RETURN END;
	tos := 0;
	stack[tos] := no; INC(tos);
	s := no.container;
	WHILE s # NIL DO
		IF s.owner # NIL THEN
			stack[tos] := s.owner; INC(tos);
		END;
		s := s.parent
	END;
	IF (stack[tos - 1] # NIL) & (stack[tos - 1] IS TS.Module) THEN
		IF stack[tos - 1](TS.Module).filename # NIL THEN
			COPY(stack[tos - 1](TS.Module).filename^, filename)
		END
	END;

	REPEAT
		DEC(tos);
		Strings.Append(scopePath, stack[tos].name^);
		IF tos # 0 THEN Strings.Append(scopePath, ".") END
	UNTIL tos = 0
END GetSourceReference;

PROCEDURE ID*(no : TS.NamedObject );
VAR filename : ARRAY 256 OF CHAR;
	scopePath : ARRAY 256 OF CHAR;
BEGIN
	GetSourceReference(no, filename, scopePath);
	IF filename # "" THEN
		KernelLog.String(filename); KernelLog.Ln;
	END;
	KernelLog.String(scopePath); KernelLog.Ln
END ID;

PROCEDURE IDScope*(s : TS.Scope);
BEGIN
	WHILE s # NIL DO
		IF s.owner # NIL THEN
			IF s.owner.name = NIL THEN
				KernelLog.String("{NIL}")
			ELSE
				 KernelLog.String(s.owner.name^); KernelLog.String("/");
			END
		END; s := s.parent
	END;
END IDScope;

PROCEDURE QualidentToString*(scope : TS.Scope; q : TS.Designator) : Strings.String;
VAR str : ARRAY 128 OF CHAR; no : TS.NamedObject;
	qStr : ARRAY 1024 OF CHAR;
BEGIN
	qStr := "";
	IF q # NIL THEN
		(* check if it is an alias import *)
		TS.s.GetString(q(TS.Ident).name, str); no := scope.Find(str, TRUE);
		IF (no # NIL) & (no IS TS.Import) THEN
			Strings.Append(qStr, no(TS.Import).import^); Strings.Append(qStr, "."); q := q.next
		END;

		WHILE q # NIL DO
			TS.s.GetString(q(TS.Ident).name, str); Strings.Append(qStr, str);
			IF q.next # NIL THEN Strings.Append(qStr, ".") END;
			q := q.next
		END
	END;
	RETURN Strings.NewString(qStr)
END  QualidentToString;

END TFScopeTools.
