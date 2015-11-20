MODULE FoxFrontend; (**  AUTHOR "fof"; PURPOSE "Oberon Compiler: Common frontend module";  **)

IMPORT
	Streams, Diagnostics,  SyntaxTree := FoxSyntaxTree, Strings;

TYPE

	Frontend* = OBJECT
	VAR		
		PROCEDURE & InitFrontEnd*;
		BEGIN
			Initialize(NIL, NIL, "", 0, FALSE);
		END InitFrontEnd;
		
		(* initialize frontend for usage *)
		PROCEDURE Initialize*(diagnostics: Diagnostics.Diagnostics; reader: Streams.Reader;CONST fileName: ARRAY OF CHAR; pos: LONGINT; activeCellsSupport: BOOLEAN);
		BEGIN
		END Initialize;

		PROCEDURE Parse*(): SyntaxTree.Module;
		BEGIN RETURN NIL
		END Parse;
		
		PROCEDURE Done*(): BOOLEAN;
		BEGIN RETURN TRUE;
		END Done;
		
		PROCEDURE Error*(): BOOLEAN;
		BEGIN RETURN TRUE;
		END Error;
		
	END Frontend;

	PROCEDURE GetDummy*():Frontend;
	VAR frontend: Frontend;
	BEGIN
		NEW(frontend);
		RETURN frontend;
	END GetDummy;

	PROCEDURE GetFrontendByName*(CONST name: ARRAY OF CHAR): Frontend;
	VAR
		procname: ARRAY 256 OF CHAR;
		factory: PROCEDURE (): Frontend;
		frontend: Frontend;
	BEGIN
		frontend := NIL;
		IF Strings.Length(name) > 0 THEN
			GETPROCEDURE(name,"Get", factory); (* try long name for example -G=OCERAFrontend *)

			IF factory = NIL THEN (* try short name for example -G=ERA*)
				procname := "Fox";
				Strings.Append(procname, name);
				Strings.Append(procname, "Frontend");
				GETPROCEDURE(procname,"Get", factory);
			END;

			IF factory # NIL THEN
				frontend := factory();
				Assert(frontend # NIL,"frontend factory returned NIL frontend");
			END;
		END;
		RETURN frontend
	END GetFrontendByName;

	PROCEDURE Assert(b: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN
		ASSERT(b);
	END Assert;

END FoxFrontend.