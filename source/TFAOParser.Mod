MODULE TFAOParser; (** AUTHOR "tf"; PURPOSE "Parser for AO --> CI"; *)

IMPORT
	S := BimboScanner, TS := TFTypeSys, Texts, TextUtilities, Files, Strings, KernelLog, Streams, TFDumpTS, Commands, Kernel, TFCheck;

TYPE
	Parser*= OBJECT
	VAR s : S.Scanner;

		m* : TS.Module;
		pos  : LONGINT;
		comments : TS.Comments;
		lastStatement : TS.Statement;

		(* add the comment to the currents tructure *)
		PROCEDURE CommentToStructure;
		VAR str : Strings.String;
			comment : TS.Comment;
		BEGIN
			ASSERT(s.commentStr # NIL);
			str := s.commentStr.GetString();
			IF str # NIL THEN
				comment := TS.AddComment(comments, str^);
				StorePos(comment.pos)
			END
		END CommentToStructure;

		PROCEDURE Next;
		VAR lpos : LONGINT;
		BEGIN
			s.Next;
			lpos := s.pos;
			WHILE (s.sym = S.comment) OR (s.sym = S.newLine) DO
				IF (s.sym = S.comment) THEN CommentToStructure
				ELSIF s.sym = S.newLine THEN
					IF (comments # NIL) & (lastStatement # NIL) THEN lastStatement.postComment := comments; comments := NIL END;
					lastStatement := NIL;
				END;
				s.Next
			END;
			lpos := s.pos;
			ASSERT((s.sym = S.eof) OR (s.pos > pos)); (* Assert progress *)
			pos := s.pos;
		END Next;

		PROCEDURE StorePos(VAR pos : TS.Position);
		BEGIN
			pos.valid := TRUE;
			pos.a := s.lastpos; pos.b := s.curpos - 1
		END StorePos;

		PROCEDURE Error(CONST str : ARRAY OF CHAR);
		BEGIN
			KernelLog.Ln;
			KernelLog.String("pos= "); KernelLog.Int(s.pos, 0); KernelLog.String(" ");  KernelLog.String(str);
			KernelLog.Ln;
(*			HALT(123456); *)
		END Error;

		PROCEDURE Warn(CONST str : ARRAY OF CHAR);
		BEGIN
			KernelLog.Ln;
			KernelLog.String("pos= "); KernelLog.Int(s.pos, 0); KernelLog.String(" ");  KernelLog.String(str);
			KernelLog.Ln;
		END Warn;

		PROCEDURE Eat(sym : LONGINT);
		VAR t, str : ARRAY 32 OF CHAR;
		BEGIN
			IF s.sym = sym THEN Next;
			ELSE
				str := "sym = "; Strings.IntToStr(sym, t); Strings.Append(str, t); Strings.Append(str, " expected");
				Error(str)
			END
		END Eat;

		PROCEDURE ImportList;
		VAR
			imp : TS.Import;
		BEGIN
			Next;
			WHILE s.sym = S.ident DO
				NEW(imp);
				imp.name := Strings.NewString(s.str);
				StorePos(imp.pos);
				Next;
				IF s.sym = S.in THEN (* ignore package *)
					Next;
					imp.package := Strings.NewString(s.str);
					Eat(S.ident);

					imp.import := imp.name
				ELSIF s.sym = S.becomes THEN
					Next;
					IF s.sym = S.ident THEN
						imp.import := Strings.NewString(s.str);
						Next;
						IF s.sym = S.in THEN (* ignore package *)
							Next;
							imp.package := Strings.NewString(s.str);
							Eat(S.ident)
						END
					ELSE
						Error("Name of imported module expected")
					END;
				ELSE
					imp.import := imp.name
				END;
				m.scope.elements.Add(imp);
				IF s.sym = S.comma THEN Next END;
			END;
			Eat(S.semicolon);
		END ImportList;

		PROCEDURE ProcedureType(scope : TS.Scope) : TS.ProcedureType;
		VAR proc : TS.ProcedureType;
		BEGIN
			NEW(proc);
			SysFlag;
			IF s.sym = S.lbrace THEN
				Next;
				IF s.sym # S.ident THEN
					(* Error *)
				ELSIF s.str = "DELEGATE" THEN
					proc.delegate := TRUE;
				END;
				Next;
				Eat(S.rbrace);
			END;
			IF s.sym = S.lparen THEN
				proc.signature := ProcSignature(scope);
			END;
			RETURN proc
		END ProcedureType;

(* *)

		PROCEDURE Type(scope : TS.Scope; CONST name : ARRAY OF CHAR) :  TS.Type;
		VAR type : TS.Type; ident : TS.Ident; str : ARRAY 8 OF CHAR;
		BEGIN
			NEW(type);
			type.container := scope;
			CASE s.sym OF
			| S.array: Next; type.kind := TS.TArray; NEW(type.array); Array(type.array, scope);
			| S.record: Next; type.kind := TS.TRecord; NEW(type.record); Record(type.record, scope);
			| S.pointer: Next; type.kind := TS.TPointer; NEW(type.pointer); type.pointer := Pointer(scope);
			| S.object: Next; type.kind := TS.TObject; type.object := Object(name);
				(* Handle the ANY case *)
				IF type.object = NIL THEN
					type.kind := TS.TAlias;
					NEW(ident); str := "OBJECT"; ident.name := TS.s.AddString(str); type.qualident := ident
				END;
			| S.procedure: Next; type.kind := TS.TProcedure; type.procedure := ProcedureType(scope);
			| S.ident: type.kind := TS.TAlias; type.qualident := Designator();
			ELSE
				(* Error *)
				Error("Illegal Type");
				Next	(* ??? *)
			END;
			RETURN type
		END Type;

		PROCEDURE Pointer(scope : TS.Scope) : TS.Pointer;
		VAR p : TS.Pointer;
		BEGIN
			SysFlag;
			Eat(S.to);
			NEW(p);
			p.type := Type(scope, "");
			RETURN p
		END Pointer;

		PROCEDURE DeclSeq(declarations: TS.Scope);
		VAR
			ol : TS.ObjectList;
			i, j : LONGINT;

			PROCEDURE CheckEndOrSemicolon;
			BEGIN
				IF s.sym # S.end THEN
					REPEAT Eat(S.semicolon) UNTIL s.sym # S.semicolon
				END
			END CheckEndOrSemicolon;

		BEGIN
			LOOP
				CASE s.sym OF
				| S.const:
					Next;
					WHILE s.sym = S.ident DO
						declarations.Add(ConstDecl());
						CheckEndOrSemicolon()
					END;
				| S.type:
					Next;
					WHILE s.sym = S.ident DO
						declarations.Add(TypeDecl(declarations));
						CheckEndOrSemicolon();
					END;
				| S.var:
					Next;
					WHILE s.sym = S.ident DO
						ol := VarDecl(declarations);
						FOR i := 0 TO ol.nofObjs - 1 DO
							ol.objs[i](TS.Var).varNr := i;
							declarations.Add(ol.objs[i](TS.Var))
						END;
						CheckEndOrSemicolon();
					END;
				| S.procedure:
					WHILE s.sym = S.procedure DO
						Next;
						declarations.Add(ProcDecl(declarations));
						CheckEndOrSemicolon();
					END;
				ELSE
					EXIT;
				END;
			END;
			j := 0;
			FOR i := 0 TO declarations.elements.nofObjs - 1 DO
				IF declarations.elements.objs[i] IS TS.Var THEN
					declarations.elements.objs[i](TS.Var).varNr := j;
					INC(j)
				END
			END
		END DeclSeq;

		PROCEDURE ConstDecl() : TS.Const;
		VAR c : TS.Const;
		BEGIN
			IF s.sym # S.ident THEN Error("Ident expect") END;
			NEW(c); c.name := Strings.NewString(s.str);
			StorePos(c.pos);
			Next;
			c.exportState := VisibilityModifier();
			Eat(S.eql);
			c.expression := Expression();
			RETURN c
		END ConstDecl;

		PROCEDURE TypeDecl(scope : TS.Scope) : TS.TypeDecl;
		VAR t : TS.TypeDecl;
		BEGIN
			IF s.sym # S.ident THEN Error("Ident expect") END;
			NEW(t); StorePos(t.pos); t.name := Strings.NewString(s.str);
			Next;
			t.exportState := VisibilityModifier();
			Eat(S.eql);
			t.type := Type(scope, t.name^);
			RETURN t
		END TypeDecl;

		PROCEDURE VarDecl(scope : TS.Scope) : TS.ObjectList;
		VAR
			ol : TS.ObjectList;
			v : TS.Var;
			t : TS.Type;
			i : LONGINT;
		BEGIN
			NEW(ol);
			IF s.sym # S.ident THEN Error("Ident expect") END;
			NEW(v); StorePos(v.pos); v.name := Strings.NewString(s.str); ol.Add(v);
			Next;
			v.exportState := VisibilityModifier();
			IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
			SysFlag;
			WHILE s.sym = S.comma DO
				Next;
				IF s.sym # S.ident THEN Error("Ident expect") END;
				NEW(v); StorePos(v.pos); v.name := Strings.NewString(s.str); ol.Add(v);
				Next;
				v.exportState := VisibilityModifier();
				IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
				SysFlag;
			END;
			Eat(S.colon);
			t := Type(scope, v.name^);
			FOR i := 0 TO ol.nofObjs - 1 DO ol.objs[i](TS.Var).type := t END;
			RETURN ol
		END VarDecl;

		PROCEDURE Object(CONST name : ARRAY OF CHAR) :  TS.Class;
		VAR
			pos: LONGINT;
			qualident: TS.Designator;
			class : TS.Class;
			body : TS.Statement;
		BEGIN
			NEW(class);
			NEW(class.scope);
			class.name := Strings.NewString(name);
			class.container := m.scope;
			class.scope.parent := m.scope;
			class.scope.owner := class;
			IF (s.sym = S.semicolon) OR (s.sym = S.rparen) THEN RETURN NIL END;
			SysFlag;
			IF s.sym = S.lparen THEN
				Next;
				class.scope.superQualident := Designator();
				Eat(S.rparen);
			END;
			IF (s.sym = S.semicolon) THEN Eat(S.semicolon); Warn("Superfluous Semicolon") END;
			IF s.sym = S.implements THEN
				Next;

				qualident := Designator();
				WHILE s.sym = S.comma DO
					Next;
					qualident := Designator();
				END;
			END;
			IF (s.sym # S.begin) & (s.sym # S.end) & (s.sym # S.eof) THEN
(*				(* avoid endless-loop *)
				IF pos = s.errpos THEN Next END; *)
				pos := s.errpos;

				DeclSeq(class.scope)
			END;
			IF s.sym = S.begin THEN
				Next;
				IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
				body := StatementSequence();
				class.scope.ownerBody := body
			END;
			Eat(S.end);
			StorePos(class.altPos);
			IF s.sym = S.ident THEN
				IF s.str # name THEN Error("object name does not match") END;
				Next
			END;
			RETURN class
		END Object;

		PROCEDURE BlockAttributes;
		VAR q : TS.Designator;
		BEGIN
			Next;
			IF s.sym # S.rbrace THEN
				q := Designator();
				WHILE s.sym = S.comma DO
					Next;
					q := Designator()
				END
			END;
		END BlockAttributes;

		PROCEDURE Set(): TS.Set;
		VAR set : TS.Set;
			cr, f: TS.SetRange;
		BEGIN
			NEW(set);
			IF s.sym # S.rbrace THEN
				REPEAT
					IF s.sym= S.comma THEN Next END;
					IF f = NIL THEN NEW(f); cr := f ELSE NEW(cr.next); cr := cr.next END;
					cr.a := Expression();
					IF s.sym = S.upto THEN
						Next; cr.b := Expression();
					END;
				UNTIL s.sym # S.comma;
				set.setRanges := f
			ELSE
				(* empty set *)
			END;

			RETURN set
		END Set;

		PROCEDURE Factor():TS.Expression;
		VAR sym, pos : LONGINT;
			ex : TS.Expression;
		BEGIN
			sym := s.sym; pos := s.pos;
			CASE s.sym OF
				|S.number : ex := TS.PrimitiveExpressionInt(s.intval); Next;
				|S.string: ex := TS.PrimitiveExpressionString(s.str); Next;
				|S.nil : ex := TS.PrimitiveExpressionNIL(); Next
				|S.true: ex := TS.PrimitiveExpressionBool(TRUE); Next
				|S.false: ex := TS.PrimitiveExpressionBool(FALSE); Next
				|S.lbrace: Next; ex := TS.PrimitiveExpressionSet(Set()); Eat(S.rbrace);
				|S.lparen: Next; ex := Expression(); Eat(S.rparen)
				|S.not: Next; ex := TS.UnaryExpression(TS.OpInvert,  Factor());
				|S.ident: ex := TS.CreateDesignatorExpression(Designator());
			ELSE
				Error("Unexpected Symbol");
			END;
		(*	ASSERT(ex # NIL); *)
			RETURN ex
		END Factor;

		PROCEDURE Term() : TS.Expression;
		VAR exa, exb : TS.Expression;
			op : LONGINT;
			pos : LONGINT;
		BEGIN
			pos := s.pos;
			exa := Factor();
			WHILE (s.sym >= S.times) & (s.sym <= S.and) DO
				CASE s.sym OF
					|S.times : op := TS.OpMul;
					|S.slash : op := TS.OpDiv;
					|S.div : op := TS.OpIntDiv;
					|S.mod : op := TS.OpMod;
					|S.and : op := TS.OpAnd;
				END;
				Next;
				exb := Factor();
				exa := TS.BinaryExpression(op, exa, exb);
			END;
		(*	ASSERT(exa # NIL);			*)
			RETURN exa;
		END Term;

		PROCEDURE SimpleExpression() : TS.Expression;
		VAR exa, exb : TS.Expression;
			op : LONGINT;
			neg : BOOLEAN;
		BEGIN
			neg := (s.sym = S.minus);
			IF (s.sym = S.plus) OR (s.sym = S.minus) THEN Next END;
			exa := Term();
			IF neg THEN exa := TS.UnaryExpression(TS.OpNegate, exa) END;
			WHILE (s.sym >= S.plus) & (s.sym <= S.or) DO
				CASE s.sym OF
					|S.plus : op := TS.OpAdd;
					|S.minus : op := TS.OpSub;
					|S.or : op := TS.OpOr;
				END;
				Next;
				exb := Term();
				exa := TS.BinaryExpression(op, exa, exb)
			END;
			(*ASSERT(exa # NIL);			 *)
			RETURN exa
		END SimpleExpression;

		PROCEDURE Expression () : TS.Expression;
		VAR exa, exb : TS.Expression;
			op : LONGINT;
		BEGIN
			exa := SimpleExpression();
			IF (s.sym >= S.eql) & (s.sym <= S.is) THEN
				CASE s.sym OF
					|S.eql : op := TS.OpEql;
					|S.neq : op := TS.OpNeq;
					|S.lss : op := TS.OpLss;
					|S.leq : op := TS.OpLeq;
					|S.gtr : op := TS.OpGtr;
					|S.geq : op := TS.OpGeq;
					|S.in : op := TS.OpIn;
					|S.is : op := TS.OpIs;
				END;
				Next;
				exb := SimpleExpression();
				exa := TS.BinaryExpression(op, exa, exb)
			END;
		(*	ASSERT(exa # NIL);			*)
			RETURN exa
		END Expression;

		PROCEDURE ExpressionList():TS.ExpressionList;
		VAR f, c : TS.ExpressionList;
		BEGIN
			NEW(f);
			f.expression := Expression();
			c := f;
			WHILE (s.sym = S.comma) DO
				Next;
				NEW(c.next);
				c := c.next;
				c.expression := Expression()
			END;
			RETURN f
		END ExpressionList;

		PROCEDURE Designator () : TS.Designator;
		VAR f, c : TS.Designator;

			parameters : TS.ActualParameters;
			index : TS.Index;
			newIdent : TS.Ident;
			deref : TS.Dereference;
		BEGIN
			NEW(newIdent); StorePos(newIdent.pos);
			newIdent.name := TS.s.AddString(s.str); (* Strings.NewString(s.str); *)
			f := newIdent; c := f;
			Next;
			WHILE (s.sym = S.lbrak) OR (s.sym = S.period) OR (s.sym = S.lparen) OR (s.sym = S.lparen) OR (s.sym = S.arrow) DO
				CASE s.sym OF
					| S.lbrak : Next; NEW(index); index.expressionList := ExpressionList(); c.next := index; c := c.next; Eat(S.rbrak);
					| S.period : Next; NEW(newIdent); StorePos(newIdent.pos);
						newIdent.name := TS.s.AddString(s.str); (*Strings.NewString(s.str);*) c.next := newIdent; c := c.next; Next;
					| S.arrow: NEW(deref); c.next := deref; c := c.next; Next;
					| S.lparen : Next; NEW(parameters);
						IF s.sym # S.rparen THEN parameters.expressionList := ExpressionList() ELSE parameters.expressionList := NIL END;
						c.next := parameters; c := c.next;
						Eat(S.rparen);
				END
			END;
			RETURN f
		END Designator;

		PROCEDURE IFStatement() : TS.IFStatement;
		VAR f, c, if : TS.IFStatement;
		BEGIN
			f := NIL;
			REPEAT
				Next;
				NEW(if);
				IF f = NIL THEN f := if; c := f ELSE c.else := if; c := if END;
				if.expression := Expression();
				Eat(S.then);
				if.then := StatementSequence()
			UNTIL s.sym # S.elsif;
			IF s.sym = S.else THEN
				Next;
				c.else := StatementSequence()
			END;
			Eat(S.end);
			IF s.sym = S.semicolon THEN Next END;
			RETURN f
		END IFStatement;

		PROCEDURE Case() : TS.Case;
		VAR
			case : TS.Case;
			f, cr : TS.CaseRange;
		BEGIN
			NEW(case);
			REPEAT
				IF s.sym= S.comma THEN Next END;
				IF f = NIL THEN NEW(f); cr := f ELSE NEW(cr.next); cr := cr.next END;
				cr.a := Expression();
				IF s.sym = S.upto THEN
					Next; cr.b := Expression();
				END;
			UNTIL s.sym # S.comma;
			Eat(S.colon);
			case.caseRanges := f;
			case.statements := StatementSequence();

			RETURN case
		END Case;


		PROCEDURE StatementSequence() : TS.Statement;
		VAR ex, fromEx, toEx, byEx : TS.Expression;
			f, n, sequence : TS.Statement;
			designator, designator2 : TS.Designator;
			fcase, ccase : TS.Case;

			PROCEDURE Add(new : TS.Statement);
			BEGIN
				IF comments # NIL THEN new.preComment := comments; comments := NIL END;
				lastStatement := new;
				IF f = NIL THEN f := new; n := new;
				ELSE n.next := new; n := new
				END
			END Add;

		BEGIN
			WHILE (s.sym # S.end) & (s.sym # S.else) & (s.sym # S.elsif) & (s.sym # S.until) & (s.sym # S.bar) & (s.sym # S.eof) DO
				CASE s.sym OF
					|S.ident :
						designator := Designator();
						IF s.sym = S.becomes THEN Next; ex := Expression();
							Add(TS.CreateAssignment(designator, ex))
						ELSE
							Add( TS.CreateProcedureCall(designator))
						END
					|S.if :
						Add(IFStatement())
					|S.while :
						Next;
						ex := Expression();
						Eat(S.do);
						Add(TS.CreateWhile(ex, StatementSequence()));
						Eat(S.end);
					|S.repeat :
						Next;
						sequence := StatementSequence();
						Eat(S.until);
						Add(TS.CreateRepeat(Expression(), sequence))
					|S.for :
						Next;
						designator := Designator();
						Eat(S.becomes);
						fromEx := Expression(); Eat(S.to); toEx := Expression();
						IF s.sym = S.by THEN
							Next;
							byEx := Expression()
						ELSE byEx := NIL;
						END;
						Eat(S.do);
						sequence := StatementSequence();
						Add(TS.CreateFor(designator, fromEx, toEx, byEx, sequence));
						Eat(S.end)
					|S.loop :
						Next;
						Add(TS.CreateLoop(StatementSequence()));
						Eat(S.end);
					|S.exit :
						Next;
						Add(TS.CreateExit())
					|S.return :
						Next;
						IF s.sym < S.semicolon THEN ex := Expression() ELSE ex := NIL END;
						Add(TS.CreateReturn(ex))
					|S.case :
						Next;
						fcase := NIL; ccase := NIL;
						ex := Expression();
						Eat(S.of);
						WHILE s.sym <= S.bar DO
							IF s.sym = S.bar THEN Next END;
							IF s.sym # S.else THEN
								IF fcase = NIL THEN fcase := Case(); ccase := fcase
								ELSE ccase.next := Case(); ccase := ccase.next
								END
							ELSE
								Warn("Illegal '|' before 'ELSE'")
							END
						END;
						sequence := NIL;
						IF s.sym = S.else THEN
							Next;
							sequence := StatementSequence();
						END;
						Add(TS.CreateCase(ex, fcase, sequence));
						Eat(S.end)
					|S.finally : Next;
					|S.begin : Add(StatementBlock()); Eat(S.end);
					|S.with : Next; designator := Designator(); Eat(S.colon); designator2 := Designator(); Eat(S.do);
						sequence := StatementSequence(); Eat(S.end);
						Add(TS.CreateWith(designator, designator2, sequence))
					|S.passivate : Next; Eat(S.lparen); ex := Expression(); Eat(S.rparen); Add(TS.CreateAwait(ex))
					|S.semicolon : Next; Warn("Superfluous Semicolon")
				ELSE
				 (* not yet handled *)
				 	KernelLog.String("s.pos= "); KernelLog.Int(s.pos, 0); KernelLog.Ln;
				 	KernelLog.String("s.sym= "); KernelLog.Int(s.sym, 0); KernelLog.Ln;
				 	(* synchronize to end of current statement sequence *)
				 	WHILE (s.sym # S.eof) & (s.sym # S.end) & (s.sym # S.else) & (s.sym # S.elsif) & (s.sym # S.until) & (s.sym # S.bar) DO Next END;
				END;
				IF s.sym = S.semicolon THEN Next END;
			END;
			Add(TS.NewEmptyStatement());
			ASSERT(f # NIL);
			RETURN f
		END StatementSequence;

		PROCEDURE StatementBlock() : TS.StatementBlock;
		VAR block : TS.StatementBlock;
		BEGIN
			Eat(S.begin);
			IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
			NEW(block);
			block.statements := StatementSequence();
			RETURN block
		END StatementBlock;

		PROCEDURE Body() : TS.StatementBlock;
		VAR b : TS.StatementBlock;
		BEGIN
			IF s.sym = S.begin THEN
				b := StatementBlock();
			ELSIF s.sym = S.code THEN
				(* skip assembler *)
				WHILE (s.sym # S.eof)  & (s.sym # S.end) DO Next END;
			END;
			RETURN b
		END Body;

		PROCEDURE SysFlag;
		BEGIN
			(* System flag *)
			IF s.sym = S.lbrak THEN
				Next;
				Eat(S.ident);
				Eat(S.rbrak);
			END;
		END SysFlag;

		PROCEDURE VisibilityModifier() : SET;
		VAR state : SET;
		BEGIN
			state := {};
			IF (s.sym = S.times) OR (s.sym = S.minus) THEN
				IF (s.sym = S.times) THEN INCL(state, TS.ExportReadWrite) END;
				IF (s.sym = S.minus) THEN INCL(state, TS.ExportReadOnly) END;
				Next
			END;
			RETURN state
		END VisibilityModifier;


		PROCEDURE Array(array: TS.Array; scope : TS.Scope);
		BEGIN
			 (* SysFlag; *)
			IF s.sym = S.lbrak THEN (* skip over open array *)
				REPEAT
					Next;
					IF s.sym = S.times THEN Eat(S.times)
					ELSIF s.sym = S.question THEN Eat(S.question)
					ELSE Error("* or ? expected")
					END;
				UNTIL s.sym # S.comma;
				Eat(S.rbrak);
				IF s.sym = S.of THEN
					Next;
					array.base := Type(scope, "");
				END
			ELSE
				IF s.sym = S.of THEN
					array.open := TRUE;
					Next;
					array.base := Type(scope, "")
				ELSE
					array.expression := Expression();

					IF s.sym = S.of THEN
						Next;
						array.base := Type(scope, "");
					ELSIF s.sym = S.comma THEN
						NEW(array.base);
						array.base.kind := TS.TArray;
						NEW(array.base.array);
						Next;
						Array(array.base.array, scope)
					ELSE
						Error("Illegal Array Definition")
					END
				END
			END
		END Array;

		PROCEDURE Record(record: TS.Record; scope : TS.Scope);
		VAR i : LONGINT;
			debug : TS.NamedObject;
		BEGIN
			SysFlag;
			NEW(record.scope);
			record.scope.parent := scope;
			NEW(debug); debug.name := Strings.NewString("RECORD");
			record.scope.owner := debug;

			IF s.sym = S.lparen THEN
				Next;
				record.scope.superQualident := Designator();
				Eat(S.rparen);
			END;
			WHILE s.sym = S.semicolon DO Next END;
			IF s.sym = S.ident THEN
				record.scope.elements := FieldList(record.scope);
				FOR i := 0 TO record.scope.elements.nofObjs - 1 DO
					record.scope.elements.objs[i].container := record.scope
				END;
			END;
			Eat(S.end);
		END Record;

		PROCEDURE FieldList(scope : TS.Scope) : TS.ObjectList;
		VAR fieldList, t : TS.ObjectList; i : LONGINT;
		BEGIN
			NEW(fieldList);
			t := FieldDecl(scope);
			FOR i := 0 TO t.nofObjs - 1 DO fieldList.Add(t.objs[i]) END;
			WHILE s.sym = S.semicolon DO
				Next;
				t := FieldDecl(scope);
				FOR i := 0 TO t.nofObjs - 1 DO fieldList.Add(t.objs[i]) END;
			END;
			RETURN fieldList
		END FieldList;

		PROCEDURE FieldDecl(scope : TS.Scope) :  TS.ObjectList;
		VAR
			var : TS.Var;
			t : TS.Type;
			i : LONGINT;
			ol : TS.ObjectList;
		BEGIN
			NEW(ol);
			IF s.sym = S.ident THEN
				NEW(var);
				var.name := Strings.NewString(s.str);
				StorePos(var.pos); ol.Add(var);
				Next;
				var.exportState := VisibilityModifier();
				IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
				SysFlag;
				WHILE s.sym = S.comma DO
					Next;
					NEW(var);
					var.name := Strings.NewString(s.str);
					StorePos(var.pos); ol.Add(var);
					Next;
					var.exportState := VisibilityModifier();
					IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
					SysFlag
				END;
				Eat(S.colon);
				t :=	Type(scope, var.name^);
				(* only now the type is known *)
				FOR i := 0 TO ol.nofObjs - 1 DO
					ol.objs[i](TS.Var).type := t
				END
			END;
			RETURN ol
		END FieldDecl;

(* *)

		PROCEDURE FPSection(scope : TS.Scope) : TS.ObjectList;
		VAR
			var : TS.Var;
			t : TS.Type;
			i : LONGINT;
			ol : TS.ObjectList;
			isConst : BOOLEAN;
			isVar : BOOLEAN;
		BEGIN
			NEW(ol);
			isConst := FALSE; isVar := FALSE;
			IF s.sym = S.var THEN
				(* VAR parameter section *)
				isVar := TRUE;
				Next
			ELSIF s.sym = S.const THEN
				(* CONST parameter section *)
				isConst := TRUE;
				Next
			END;
			IF s.sym = S.ident THEN
				NEW(var);
				StorePos(var.pos);
				var.name := Strings.NewString(s.str);
				IF isConst THEN INCL(var.parameterType, TS.IsConstParam)
				ELSIF isVar THEN INCL(var.parameterType, TS.IsVarParam)
				END;
				ol.Add(var);
				Next;

				WHILE s.sym = S.comma DO
					Next;

					NEW(var);
					StorePos(var.pos);
					var.name := Strings.NewString(s.str);
					ol.Add(var);
					Next
				END;
				Eat(S.colon);
				t :=	Type(scope, "");
				(* only now the type is known *)
				FOR i := 0 TO ol.nofObjs - 1 DO
					ol.objs[i](TS.Var).type := t
				END
			END;
			RETURN ol
		END FPSection;

		PROCEDURE ProcSignature(scope : TS.Scope) : TS.ProcedureSignature;
		VAR ps : TS.ProcedureSignature;
			ol : TS.ObjectList;
			i : LONGINT;
		BEGIN
			NEW(ps);
			Next;
			IF (s.sym = S.var) OR (s.sym = S.const) OR (s.sym = S.ident) THEN
				ps.params := FPSection(scope);
				WHILE s.sym = S.semicolon DO
					Next;	(* avoids endless loop *)
					ol := FPSection(scope);
					FOR i := 0 TO ol.nofObjs - 1 DO ps.params.Add(ol.objs[i]) END;
				END;
				FOR i := 0 TO ps.params.nofObjs - 1 DO
					ps.params.objs[i](TS.Var).varNr := i;
					INCL(ps.params.objs[i](TS.Var).parameterType, TS.IsParam)
				END
			END;
			Eat(S.rparen);
			IF s.sym = S.colon THEN
				Next;
				ps.return := Type(scope, "")
			END;
			RETURN ps
		END ProcSignature;

		PROCEDURE ProcDecl(currentScope : TS.Scope) : TS.ProcDecl;
		VAR pd : TS.ProcDecl; forward : BOOLEAN;
			name : ARRAY 64 OF CHAR;
			 i : LONGINT;
		BEGIN
			NEW(pd);
			IF comments # NIL THEN pd.preComment := comments; comments := NIL END;

			forward := FALSE;
			SysFlag;
			CASE s.sym OF
			| S.minus: (*inline := TRUE;*) Next
			| S.and: (* constructor := TRUE;*) Next
			| S.times: (* ignore *) Next
			| S.arrow: forward := TRUE; Next
			| S.string: (*operator := TRUE;*)
			| S.number: (*IF s.numtyp = S.char THEN (* operator := TRUE  *)END;*)
			ELSE
			END;
			IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;
			(* procedure name *)
			pd.name := Strings.NewString(s.str);
			StorePos(pd.pos);
			COPY(pd.name^, name);
			IF pd.name^="" THEN HALT(9999) END;
			Next;

			(* visibility modifier *)
			pd.exportState := VisibilityModifier();

			NEW(pd.scope) ;
			pd.scope.parent := currentScope;
			pd.scope.owner := pd;

			IF s.sym = S.lparen THEN
				pd.signature := ProcSignature(currentScope);
				(* update container *)
				IF pd.signature.params # NIL THEN
					FOR i := 0 TO pd.signature.params.nofObjs - 1 DO pd.signature.params.objs[i].container := pd.scope END;
				END;
				pd.scope.params := pd.signature.params
			END;

			IF ~forward THEN
				Eat(S.semicolon);
				IF (s.sym = S.const) OR (s.sym = S.var) OR (s.sym = S.type) OR (s.sym = S.procedure) THEN
					DeclSeq(pd.scope)
				END;
				
				pd.scope.ownerBody := Body();
				Eat(S.end);
				StorePos(pd.altPos);
				IF s.str # pd.name^ THEN
					Error("Procedure-name does not match")
				END;
				Next;
			END;
	(*		KernelLog.String("P:");  KernelLog.String(s.str); KernelLog.Ln;  *)
			RETURN pd
		END ProcDecl;

		PROCEDURE Definition;
		VAR ps : TS.ProcedureSignature; q : TS.Designator;
		BEGIN
			IF s.sym = S.definition THEN
				Next;
				IF s.sym = S.ident THEN
					Next
				ELSE Error("Definition name expected")
				END;
				WHILE s.sym = S.semicolon DO Next END;
				IF s.sym = S.refines THEN Next;
					q := Designator()
				END;
				WHILE s.sym = S.procedure DO
					Next;
					ps := ProcSignature(m.scope);
					Eat(S.semicolon);
				END;
				Eat(S.end);
				Eat(S.ident);
				WHILE s.sym = S.semicolon DO Next END;
			END;
		END Definition;

		PROCEDURE Module;
		VAR body : TS.Statement;
		BEGIN
			IF s.sym = S.module THEN
				Next;
				(* read module name *)
				IF s.sym = S.ident THEN
					NEW(m);
					(* attach pre-comments *)
					IF comments # NIL THEN
						m.preComment := comments; comments := NIL 
					END;
					
					NEW(m.scope);
					m.scope.parent := Universe;
					m.scope.owner := m;

					StorePos(m.pos);
					m.name := Strings.NewString(s.str);

					(* skip module options *)
					Next;
					IF s.sym = S.lbrace THEN
						WHILE (s.sym # S.semicolon) & (s.sym # S.eof) DO Next END;
					END;

					(* read (and ignore) package *)
					IF s.sym = S.in THEN
						Next;
						m.package := Strings.NewString(s.str);
						Eat(S.ident)
					END;
					Eat(S.semicolon);

					IF s.sym = S.import THEN 
						(* attach pre-comments *)
						IF comments # NIL THEN 
							m.postComment := comments; comments := NIL 
						END;

						ImportList 
					END;

					WHILE s.sym = S.definition DO Definition END;

					IF (s.sym = S.const) OR (s.sym = S.type) OR (s.sym = S.var) OR (s.sym = S.procedure) THEN
						DeclSeq(m.scope)
					END;
					IF s.sym = S.begin THEN
						Next;
						IF s.sym = S.lbrace THEN BlockAttributes; Eat(S.rbrace) END;

						body := StatementSequence();
						m.scope.ownerBody := body;
					END;
					Eat(S.end);
					StorePos(m.altPos);
					IF (s.sym = S.ident) & (s.str = m.name^) THEN
						(* correct *)
						Next;
					ELSE
						(* maybe missing END or wrong module name *)
						Error("END missing or wrong module name")
					END;
					Eat(S.period);
				ELSE
					Error("name expected");
				END;
			END;
		END Module;

		PROCEDURE Parse*(s : S.Scanner);
		BEGIN
			SELF.s := s;
			Next; (* establish one look ahead *)
			Module;
		END Parse;

	END Parser;

	FileListEntry = POINTER TO RECORD
		filename : ARRAY 128 OF CHAR;
		next : FileListEntry;
	END;

	SymbolCreator = OBJECT
	VAR filename : ARRAY 128 OF CHAR;
	BEGIN {ACTIVE}
		IncWorker;
		WHILE GetTask(filename) DO
			MakeSymbolFile(filename);
		END;
		DecWorker
	END SymbolCreator;


VAR Universe* : TS.Scope;
	System : TS.Module;
	release : TS.ObjectList;
	fileList : FileListEntry;
	nofWorkers : LONGINT;

PROCEDURE GetTask(VAR filename : ARRAY OF CHAR) : BOOLEAN;
BEGIN {EXCLUSIVE}
	IF fileList # NIL THEN
		COPY(fileList.filename, filename); fileList := fileList.next;
		RETURN TRUE
	ELSE RETURN FALSE
	END
END GetTask;

PROCEDURE AddTask(CONST filename : ARRAY OF CHAR);
VAR fl : FileListEntry;
BEGIN {EXCLUSIVE}
	NEW(fl);
	COPY(filename, fl.filename);
	fl.next := fileList; fileList := fl;
END AddTask;

PROCEDURE IncWorker;
BEGIN {EXCLUSIVE}
	INC(nofWorkers);
END IncWorker;

PROCEDURE DecWorker;
BEGIN {EXCLUSIVE}
	DEC(nofWorkers);
END DecWorker;

PROCEDURE ScanModule*(CONST filename : ARRAY OF CHAR; dump : BOOLEAN; VAR m : TS.Module);
VAR t : Texts.Text; res : LONGINT;
	s : S.Scanner;
	p : Parser;
BEGIN
	NEW(t);
	TextUtilities.LoadAuto(t, filename, res, res);
	IF res # 0 THEN
		KernelLog.String(filename);  KernelLog.String(" not found"); KernelLog.Ln;
		RETURN
	END;
	s := S.InitWithText(t, 0);

	NEW(p); p.Parse(s);
	m := p.m;
	IF dump THEN
		IF p.m # NIL THEN
			TFDumpTS.Open(p.m.name^);
			TFDumpTS.DumpM(p.m)
		END
	END
END ScanModule;

PROCEDURE ScanForModules;
VAR
	e : Files.Enumerator;
	name : ARRAY 256 OF CHAR; flags : SET; time, date, size : LONGINT;
	module : TS.Module;
	i : LONGINT;
	t0, t1 : LONGINT;
BEGIN
	NEW(release);
	NEW(e);
	e.Open("d:/release/*.Mod", {});
	i := 0;
	t0 := Kernel.GetTicks();
	WHILE e.HasMoreEntries() DO
		IF e.GetEntry(name, flags, time, date, size) THEN
			KernelLog.String(name); KernelLog.Ln;
			ScanModule(name, FALSE, module);
			TS.WriteSymbolFile(module);
(*			IF module # NIL THEN
				TFCheck.CheckDeclarations(module.scope);
			END; *)
		(*	IF module # NIL THEN release.Add(module); INC(i) END;  *)
		END
	END;
	t1 := Kernel.GetTicks();
	KernelLog.String("Finished "); KernelLog.Int(i, 0); KernelLog.String(" modules loaded");  KernelLog.Ln;
	KernelLog.String("t1-t0= "); KernelLog.Int(t1-t0, 0); KernelLog.Ln;
	KernelLog.Int((t1-t0) DIV 60000, 0); KernelLog.String("m"); KernelLog.Int(((t1-t0) DIV 1000) MOD 60, 0); KernelLog.String("s"); KernelLog.Ln;
END ScanForModules;

PROCEDURE Test*(par : Commands.Context) ;
VAR
	name :ARRAY 256 OF CHAR;
	sr : Streams.Reader;
	t0, t1 : LONGINT;
	module : TS.Module;
BEGIN
	sr := par.arg;
	sr.String(name);
	KernelLog.String("Parsing "); KernelLog.String(name);
	t0 := Kernel.GetTicks();
	ScanModule(name, TRUE, module);
	IF module # NIL THEN
		TFCheck.CheckDeclarations(module.scope);
	END;
	t1 := Kernel.GetTicks();
	KernelLog.String("t1-t0= "); KernelLog.Int(t1-t0, 0); KernelLog.Ln;
	KernelLog.String(" done.");
END Test;

PROCEDURE MakeSymbolFile(CONST filename : ARRAY OF CHAR);
VAR module : TS.Module;
BEGIN
	KernelLog.String(filename); KernelLog.Ln;
	ScanModule(filename, FALSE, module);
	IF module # NIL THEN
		module.filename := Strings.NewString(filename);
		TS.WriteSymbolFile(module)
	END
END MakeSymbolFile;


PROCEDURE MakeSymbolFiles*(par : Commands.Context) ;
CONST NofSymbolCreators = 4;
VAR e : Files.Enumerator;
	path, name, exclude : ARRAY 256 OF CHAR; flags : SET; time, date, size : LONGINT;
	sr : Streams.Reader;
	i : LONGINT;
	t0, t1 : LONGINT;
	symbolCreators : ARRAY NofSymbolCreators OF SymbolCreator;
BEGIN
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
	i := 0;
	t0 := Kernel.GetTicks();
	KernelLog.String("Processing ... "); KernelLog.Ln;
	WHILE e.HasMoreEntries() DO
		IF e.GetEntry(name, flags, time, date, size) THEN
			IF (exclude = "") OR ~Strings.Match(exclude, name) THEN
				AddTask(name);
				INC(i)
			ELSE
				KernelLog.String("Excluding "); KernelLog.String(name); KernelLog.Ln;
			END
		END
	END;
	KernelLog.Int(i, 0); KernelLog.String(" modules queued for processing");  KernelLog.Ln;
	FOR i := 0 TO NofSymbolCreators - 1 DO NEW(symbolCreators[i]) END;
	BEGIN {EXCLUSIVE}
		AWAIT((fileList = NIL) & (nofWorkers = 0));
	END;
	t1 := Kernel.GetTicks();
	KernelLog.Int((t1-t0) DIV 60000, 0); KernelLog.String("m"); KernelLog.Int(((t1-t0) DIV 1000) MOD 60, 0); KernelLog.String("s"); KernelLog.Ln;
END MakeSymbolFiles;

PROCEDURE MakeSym*(par : Commands.Context) ;
VAR
	name :ARRAY 256 OF CHAR;
	sr : Streams.Reader;
	t0, t1 : LONGINT;
	module : TS.Module;
BEGIN
	sr := par.arg;
	sr.String(name);
	KernelLog.String("Parsing "); KernelLog.String(name);
	t0 := Kernel.GetTicks();
	ScanModule(name, TRUE, module);
	IF module # NIL THEN
		(* TFCheck.CheckDeclarations(module.scope); *)
		TS.WriteSymbolFile(module);
	END;
	t1 := Kernel.GetTicks();
	KernelLog.String("t1-t0= "); KernelLog.Int(t1-t0, 0); KernelLog.Ln;
	KernelLog.String(" done.");
END MakeSym;

PROCEDURE AddStandardProc(scope : TS.Scope; CONST name : ARRAY OF CHAR);
VAR p : TS.ProcDecl;
BEGIN
	NEW(p); p.name := Strings.NewString(name);
	scope.Add(p)
END AddStandardProc;

PROCEDURE AddBasicType(scope : TS.Scope; CONST name : ARRAY OF CHAR; type : LONGINT);
VAR t : TS.TypeDecl;
BEGIN
	NEW(t); t.name := Strings.NewString(name);
	NEW(t.type); t.type.kind := TS.TBasic; t.type.basicType := type;
	scope.Add(t)
END AddBasicType;

BEGIN
	NEW(Universe);
	Universe.parent := NIL;
	NEW(System); System.name := Strings.NewString("SYSTEM");
	NEW(System.scope);
	AddBasicType(System.scope, "ADDRESS", TS.BasicInt32);
	AddBasicType(System.scope, "SIZE", TS.BasicInt32);

	TS.ns.AddModule(System);
	AddStandardProc(Universe, "NEW");
	AddStandardProc(Universe, "LEN");
	AddStandardProc(Universe, "COPY");
	AddStandardProc(Universe, "ASSERT");
	AddStandardProc(Universe, "HALT");
	AddStandardProc(Universe, "INC");
	AddStandardProc(Universe, "DEC");
	AddStandardProc(Universe, "INCL");
	AddStandardProc(Universe, "EXCL");
	AddStandardProc(Universe, "CHR");
	AddStandardProc(Universe, "ORD");
	AddStandardProc(Universe, "LONG");
	AddStandardProc(Universe, "SHORT");
	AddStandardProc(Universe, "ENTIER");
	AddStandardProc(Universe, "ASH");
	AddBasicType(Universe, "BOOLEAN", TS.BasicBoolean);
	AddBasicType(Universe, "ANY", TS.BasicInt32);
	AddBasicType(Universe, "PTR", TS.BasicInt32);
	AddBasicType(Universe, "SHORTINT", TS.BasicInt8);
	AddBasicType(Universe, "INTEGER", TS.BasicInt16);
	AddBasicType(Universe, "LONGINT", TS.BasicInt32);
	AddBasicType(Universe, "SET", TS.BasicInt32);
	AddBasicType(Universe, "HUGEINT", TS.BasicInt64);
	AddBasicType(Universe, "CHAR", TS.BasicChar8);
	AddBasicType(Universe, "REAL", TS.BasicReal32);
	AddBasicType(Universe, "LONGREAL", TS.BasicReal64);
	AddBasicType(Universe, "STRING", TS.BasicString);
END TFAOParser.

