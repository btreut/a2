MODULE ProcessInfo0; (** AUTHOR "staubesv"; PURPOSE "Platform-dependent process interface"; *)

IMPORT
	Objects;

TYPE

	ProcessArray* = ARRAY OF Objects.Process;

PROCEDURE GetProcesses*(VAR array : ProcessArray; VAR nofProcesses : LONGINT);
VAR thread : Objects.Process; length : LONGINT;
BEGIN
	nofProcesses := 0;
	length := LEN(array);
	thread := Objects.root;
	WHILE (thread # NIL) & (nofProcesses < length) DO
		IF (thread.mode # Objects.Terminated) THEN
			array[nofProcesses] := thread(Objects.Process);
			INC(nofProcesses);
		END;
		thread := thread.nextProcess;
	END;
END GetProcesses;

PROCEDURE GetProcess*(id : LONGINT) : Objects.Process;
VAR process, thread : Objects.Process; 
BEGIN
	process := NIL;
	thread := Objects.root;
	WHILE (thread # NIL) & (process = NIL) DO
		IF thread.id = id THEN process := thread; END;
		thread := thread.nextProcess;
	END;
	RETURN process;
END GetProcess;

END ProcessInfo0.
