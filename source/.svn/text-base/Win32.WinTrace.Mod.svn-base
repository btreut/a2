MODULE WinTrace;

IMPORT Kernel32, Modules,Trace,Commands;

CONST
	none = 0; console = 1; file = 2;
VAR
	hin-, hout-: Kernel32.HANDLE;
	mode: LONGINT; (* none, console or file *)

(* Sender to be used with Stream.Writer *)
PROCEDURE Send* (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN
	IF mode # none THEN
		Kernel32.WriteFile (hout, buf[ofs], len, len, NIL);
		Kernel32.FlushFileBuffers(hout);
	END;
END Send;

(* Receiver to be used with Stream.Reader *)
PROCEDURE Receive* (VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
BEGIN
	Kernel32.ReadFile (hin, buf[ofs], min, len, NIL);
END Receive;

PROCEDURE Init;
BEGIN
	mode := none;
END Init;

PROCEDURE Close*;
VAR res: LONGINT;
BEGIN
	IF mode = console THEN
		Kernel32.CloseHandle(hout);
		res := Kernel32.FreeConsole ();
	ELSIF mode = file THEN
		Kernel32.CloseHandle(hout);
	END;
	hout := Kernel32.InvalidHandleValue;
	mode := none;
END Close;

PROCEDURE OpenConsole*;
VAR res: LONGINT;
BEGIN
	IF mode = console THEN RETURN 
	ELSIF mode = file THEN Close
	END;
	IF Kernel32.AttachConsole(-1) = Kernel32.False THEN
		res := Kernel32.AllocConsole ();
	END;

	hin := Kernel32.GetStdHandle (Kernel32.STDInput);
	ASSERT ((hin) # (Kernel32.InvalidHandleValue));

	hout := Kernel32.GetStdHandle (Kernel32.STDOutput);
	ASSERT ((hout) # (Kernel32.InvalidHandleValue));

	Trace.Char := Char;
	mode := console;
END OpenConsole;

PROCEDURE OpenFile*(context: Commands.Context);
VAR filename: ARRAY 256 OF CHAR;
BEGIN
	Close;
	IF ~context.arg.GetString(filename) THEN filename := "WinTrace.Text" END;
	hout := Kernel32.CreateFile(filename, {Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, Kernel32.NULL);
	ASSERT ((hout) # (Kernel32.InvalidHandleValue));
	Trace.Char := Char;
	mode := file;
END OpenFile;

PROCEDURE Terminate;
BEGIN
	Close;
END Terminate;

PROCEDURE Char(c: CHAR);
VAR len: LONGINT;
BEGIN
	len := 1;
	Kernel32.WriteFile(hout,c,len,len,NIL);
END Char;

BEGIN
	Init;
	Modules.InstallTermHandler (Terminate);
END WinTrace.

WinTrace.OpenFile ~
WinTrace.OpenFile myTrace.Text ~
WinTrace.OpenConsole
WinTrace.Close 