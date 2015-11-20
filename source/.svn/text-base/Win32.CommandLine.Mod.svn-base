MODULE CommandLine; (** AUTHOR "fof"; PURPOSE "A2 for Windows Command Line Interpreter"; *)

IMPORT
	Kernel32,SYSTEM,Streams,FileHandlers;

PROCEDURE Read(VAR commandLine: ARRAY OF CHAR);
VAR adr: ADDRESS; i: LONGINT; ch: CHAR;
BEGIN
	adr := Kernel32.GetCommandLine();
	SYSTEM.GET(adr,ch);
	i := 0;
	WHILE (i<LEN(commandLine)-1) & (ch # 0X) DO
		commandLine[i] := ch;
		INC(adr); INC(i);
		SYSTEM.GET(adr,ch);
	END;
END Read;

(* open documents specified in the command line *)
PROCEDURE Open*;
VAR commandLine,command,name: ARRAY 512 OF CHAR; reader: Streams.StringReader;
BEGIN
	Read(commandLine);
	NEW(reader,LEN(commandLine));
	reader.Set(commandLine);
	reader.String(command);
	WHILE reader.GetString(name) DO
		FileHandlers.OpenFile(name,NIL, NIL);
	END;
END Open;

END CommandLine.

SystemTools.Free CommandLine ~
CommandLine.Open
