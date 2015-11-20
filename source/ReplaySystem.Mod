MODULE ReplaySystem; (** AUTHOR "PH"; PURPOSE "automatic replay of a traced A2 system session from the trace log"; *)

IMPORT Files, Streams, Commands, SearchTools;

PROCEDURE replay(r: Streams.Reader);
VAR cmdline: Streams.StringReader; w: Streams.StringWriter; context:Commands.Context;
	cmd, args: ARRAY 1024 OF CHAR;
	len: LONGINT;
	flags : SET; res : LONGINT; msg : ARRAY 128 OF CHAR;
	ok:BOOLEAN;
BEGIN
	NEW(cmdline, 1024);
	NEW(w, 1024);
	WHILE r.res#Streams.EOF DO
		len:=1024;
		SearchTools.SearchPatternRaw(r, NIL, "Commands.Activate");
		SearchTools.SearchPatternRaw(r, w, "~"); 
		w.GetRaw(args, len); 
		cmdline.SetRaw(args, 0, len);
		ok:=cmdline.GetString(cmd);
		(*KernelLog.String(cmd); KernelLog.Char("|"); KernelLog.String(args); KernelLog.Ln;*)
		NEW(context, NIL, cmdline, NIL,NIL,NIL);
		Commands.Activate(cmd, context, flags, res, msg);
	END;
END replay;

PROCEDURE Replay*(context:Commands.Context);
VAR f:Files.File;  fr: Files.Reader; res:BOOLEAN; log: ARRAY 1024 OF CHAR;
BEGIN
	res:=context.arg.GetString(log);
	IF res THEN
		f:=Files.Old(log);
		IF f#NIL THEN
			Files.OpenReader(fr,f,0);
			replay(fr);
		END;
	END;
END Replay;

END ReplaySystem.

how to use: 

ReplaySystem.Replay SystemTrace20120309_114313_07.txt~

SystemTools.Free DownTo ReplaySystem~

