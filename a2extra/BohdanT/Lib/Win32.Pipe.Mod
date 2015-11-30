MODULE Pipe; (** AUTHOR "BohdanT"; PURPOSE "Work with windows Pipes"; *)
IMPORT SYSTEM, Kernel32, KernelLog, Commands, Strings;
CONST
	SWHide* = 0; SWShowNnormal* = 1;  SWShowMinimized* = 2;  SWShowMaximazed* = 3;  SWShowNoActivate* = 4;  SWShow* = 5;
	SWMinimize* = 6;  SWShowMinNoActive* = 7;  SWShowNA* = 8;  SWRestore* = 9;  SWShowDefault* = 10;

	(** StartupInfo flags *)
	StartFUseShowWindow* = 0;  StartFUseSize* = 1;  StartFUsePosition* = 2;StartFUseStdHandles = 8;

	(** BOOL values *)
	False* = 0;  True* = 1;

	Trace = TRUE;
TYPE

SecurityAttributes* = RECORD
    nLength*: LONGINT;
    lpSecurityDescriptor*: ANY;
    bInheritHandle*: LONGINT;
END;
StartupInfo = Kernel32.StartupInfo;
ProcessInformation = Kernel32.ProcessInformation;
HANDLE* = Kernel32.HANDLE;

VAR

	CreatePipe-:PROCEDURE{WINAPI}(VAR hReadPipe, hWritePipe: HANDLE; CONST lpPipeAttributes: SecurityAttributes; nSize: LONGINT): LONGINT;
	TerminateProcess-:PROCEDURE{WINAPI}(hProcess: HANDLE; exitcode: LONGINT): LONGINT;
TYPE
	ChildProcess* = OBJECT
	VAR
		FChildStdoutRd, FChildStdoutWr,
		FChildStdinRd, FChildStdinWr:HANDLE;
		SA: SecurityAttributes; SI: StartupInfo; PI: ProcessInformation;
		wdir,cmdLine, Line: ARRAY 256 OF CHAR;
		WasOK: LONGINT;
		internalEnabled,alive:BOOLEAN;
		Buffer,buf:ARRAY 1024 OF CHAR;
		bytesRead,head:LONGINT;
		tail:LONGINT;
		PROCEDURE &Init*(name,workdir:ARRAY OF CHAR);
		VAR
			Buffer: ARRAY 1024 OF CHAR;
			BytesRead: LONGINT;
			tmp1,tmp2:HANDLE;
		BEGIN
			alive := TRUE;
			COPY(name,cmdLine);
			COPY(workdir,wdir);
		    SA.nLength := SIZEOF(SecurityAttributes);
		    SA.bInheritHandle := True;
		    SA.lpSecurityDescriptor := NIL;

			CreatePipe(FChildStdoutRd, FChildStdoutWr, SA, 0);
			CreatePipe(FChildStdinRd, FChildStdinWr, SA, 0);

			SI.cb := SIZEOF(StartupInfo);
			SI.dwFlags := {StartFUseShowWindow} + {StartFUseStdHandles};
			SI.wShowWindow :=SWHide;(*SWShowNnormal*);
			SI.hStdInput :=  FChildStdinRd; (*GetStdHandle(STD_INPUT_HANDLE);*)
			SI.hStdOutput :=FChildStdoutWr;
			IF Trace THEN
				KernelLog.String("cmdLine= "); KernelLog.String(cmdLine); KernelLog.Ln; 
				KernelLog.String("wdir= "); KernelLog.String(wdir); KernelLog.Ln; 
			END;
			IF Kernel32.CreateProcess(NIL, cmdLine, NIL, NIL, True, 0, NIL, wdir, SI, PI)=0 THEN
				KernelLog.String("'Could not execute command line!"); KernelLog.Ln;
			ELSE
				BEGIN {EXCLUSIVE} internalEnabled := TRUE; END;
			END;
		END Init;
		PROCEDURE String*(x:ARRAY OF CHAR); 
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE x[i] # 0X DO Char( x[i] );  INC( i ) END
		END String;

		
		PROCEDURE Char*( x: CHAR );
		BEGIN
			IF (tail = LEN( buf )) THEN
				Update;
			END;
			 buf[tail] := x;  INC( tail ); 
		END Char;

		PROCEDURE Ln*();
		BEGIN
			Char(0DX); Char(0AX);
		END Ln;
		
		PROCEDURE Update*;
		VAR
			 len:LONGINT;
		BEGIN
			len := Kernel32.WriteFile(FChildStdinWr,buf,tail,len,NIL);
			tail:=0;
		END Update;
		
		PROCEDURE Available*( ): LONGINT;
		BEGIN
			RETURN bytesRead-head;
		END Available;
		
		PROCEDURE Read*(n:LONGINT;VAR x:ARRAY OF CHAR);
		VAR
		 i:LONGINT;
		BEGIN
			FOR i:=0 TO n-1 DO x[i]:=Buffer[head+i]; END;
			BEGIN {EXCLUSIVE} INC(head,n);END;
		END Read;
		
		PROCEDURE ReadCh*(VAR x:CHAR);
		BEGIN
			BEGIN {EXCLUSIVE} AWAIT(Available()>0);END;
			x:=Buffer[head];
			BEGIN {EXCLUSIVE} INC(head);END;
		END ReadCh;

		PROCEDURE Peek*():CHAR;
		BEGIN
			BEGIN {EXCLUSIVE} AWAIT(Available()>0);END;
			RETURN Buffer[head];
		END Peek;
		
		PROCEDURE Close*;
		BEGIN{EXCLUSIVE}
			alive:=FALSE;
			TerminateProcess(PI.hProcess,0);
		END Close;
		
	BEGIN{ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(internalEnabled); END;
		REPEAT
			BEGIN {EXCLUSIVE} AWAIT(bytesRead=head); END;
			head:=0;
			bytesRead:=0;
			IF Trace THEN
(*				KernelLog.String("=Read= "); KernelLog.Ln; *)
			END;
			WasOK := Kernel32.ReadFile(FChildStdoutRd, Buffer, 256, bytesRead, NIL);
			IF Trace THEN
	(*			KernelLog.String("=bytesRead= "); KernelLog.Int(bytesRead,0); KernelLog.Ln; 
				KernelLog.String("=WasOK= "); KernelLog.Int(WasOK,0); KernelLog.Ln; *)
			END;
			IF bytesRead > 0 THEN
				Buffer[bytesRead] := 0X;
				IF Trace THEN 
					KernelLog.Enter;
					KernelLog.String(Buffer); 
					KernelLog.Exit;
				END;
			END;
		UNTIL (~alive);
		Kernel32.WaitForSingleObject(PI.hProcess, Kernel32.Infinite);
		Kernel32.CloseHandle(PI.hThread);
		Kernel32.CloseHandle(PI.hProcess);
		Kernel32.CloseHandle(FChildStdoutRd);
	END ChildProcess;

VAR
	test:ChildProcess;
	PROCEDURE TestInit*;
	BEGIN
		NEW(test, 'chkdsk.exe /?', 'C:\');
	END TestInit;
	PROCEDURE TestRead*;
	VAR
	 n:LONGINT;
	 b:ARRAY 1024 OF CHAR;
	BEGIN
		n:=test.Available();
(*		KernelLog.String("n= "); KernelLog.Int(n, 0); KernelLog.Ln;*)
		IF n#0 THEN
			test.Read(n,b);
			b[n]:=0X;
		END;
	END TestRead;
	
	PROCEDURE SendCommand*(context : Commands.Context); (** {modulename} ~ *)
	VAR name : ARRAY 64 OF CHAR; 
		 res:BOOLEAN;
		 len:LONGINT;
	BEGIN
		name := "";
		res:=context.arg.GetString(name);
		IF res&(test#NIL) THEN
			test.String(name);
			test.Ln;
			test.Update;
		END;
	END SendCommand;

	PROCEDURE Init;
	VAR mod: HANDLE;
		str: ARRAY 64 OF CHAR;
	BEGIN
		str := "Kernel32.DLL";
		mod := Kernel32.LoadLibrary(str);
		Kernel32.GetProcAddress(mod, "CreatePipe",SYSTEM.VAL(ADDRESS,CreatePipe));
		Kernel32.GetProcAddress(mod, "TerminateProcess",SYSTEM.VAL(ADDRESS,TerminateProcess));
	END Init;


BEGIN
	Init();
END Pipe.Test

Pipe.TestInit~
Pipe.TestRead~

SystemTools.Free Pipe~

Pipe.SendCommand help~
Pipe.SendCommand exit~

SystemTools.Free Pipe~

