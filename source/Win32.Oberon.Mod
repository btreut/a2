MODULE Oberon IN A2; (** AUTHOR "negelef"; PURPOSE "Oberon command interpreter interface for A2"; *)

IMPORT Modules, Commands, Strings ;

	PROCEDURE Call* (context: Commands.Context);
	VAR string, msg: ARRAY 64 OF CHAR; module, command: Modules.Name; res: LONGINT; procedure: PROCEDURE;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String (string);
		Commands.Split (string, module, command, res, msg);
		IF res # Commands.Ok THEN
			context.error.String (msg); context.error.Ln; RETURN;
		END;
		Strings.Concat ("Oberon.", module, module);
		GETPROCEDURE (module, command, procedure);
		IF procedure = NIL THEN
			context.error.String ("Oberon command '"); context.error.String (string);
			context.error.String ("' not found"); context.error.Ln; RETURN;
		END;
		procedure;
	END Call;


END Oberon.


SystemTools.Free Oberon ~

