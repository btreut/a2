MODULE WinApplications;  (* ll, fof : call windows applications from within WinAos *)
							(*ll, add statements for waiting process terminate in procedure Callprocess, 23.11.2007*)
							(*ll, add return result of CallProcess Procedure. IF resturn result = 0 THEN execution success END, 28.11.2007*)

IMPORT Kernel32, KernelLog, Commands, Strings, SYSTEM, Options;

	PROCEDURE CallProcess( par: ARRAY OF CHAR; visible: BOOLEAN ): LONGINT;
	VAR bool: LONGINT;  start: Kernel32.StartupInfo;  pi: Kernel32.ProcessInformation;  result: LONGINT;
	BEGIN
		result := -1;
		start.cb := SIZEOF( Kernel32.StartupInfo );
		start.dwFlags := {Kernel32.StartFUseShowWindow};
		IF visible THEN start.wShowWindow := 1; ELSE start.wShowWindow := 0; END;

		KernelLog.String( "Calling Windows Application: " );  KernelLog.String( par );  KernelLog.Ln;

		bool := Kernel32.CreateProcess( NIL , par, NIL , NIL , Kernel32.False, 0, NIL , NIL , start, pi );
		result := Kernel32.WaitForSingleObject(pi.hProcess, Kernel32.Infinite);
		bool := Kernel32. GetExitCodeProcess(pi.hProcess, result);

		RETURN result
	END CallProcess;

	PROCEDURE Call*( CONST proc, par: ARRAY OF CHAR): LONGINT;
	VAR call: ARRAY 1024 OF CHAR;
	BEGIN
		call := '"'; Strings.Append (call, proc); Strings.Append (call, '" '); Strings.Append (call, par);
		RETURN CallProcess (call, TRUE);
	END Call;

	PROCEDURE Run*(context : Commands.Context);
	VAR options: Options.Options; visible: BOOLEAN; cmdpar: ARRAY 256 OF CHAR;  res: LONGINT;
	BEGIN
		NEW (options);
		options.Add("h", "hide", Options.Flag);
		IF options.Parse(context.arg,context.error) THEN
			visible := ~options.GetFlag ("h");
		ELSE
			visible := TRUE;
		END;
		context.arg.Ln (cmdpar);
		res := CallProcess (cmdpar, visible);
		IF res =  0 THEN KernelLog.String( "should have worked fine .... " );   KernelLog.Ln;
		ELSE KernelLog.String( "ERROR: " ); res:= Kernel32.GetLastError();  KernelLog.Int(res, 1 );  KernelLog.Ln;
		END;
		context.result := res;
	END Run;

END WinApplications.

SystemTools.Free WinApplications ~
System.Free WinApplications ~

~
WinApplications.Run avrdude -help ~

Aos.Call WinApplications.Run avrdude -p m128 -c avrisp -P com1 -e ~
Aos.Call WinApplications.Run Notepad Test.bat ~
Aos.Call WinApplications.Run Test.bat  ~
~

EditTools.OpenAscii Test.Bat ~


