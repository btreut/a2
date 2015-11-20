MODULE ProcessInfo; (** AUTHOR "staubesv"; PURPOSE "Information about processes"; *)

IMPORT
	SYSTEM, Streams, Reflection, Modules, Objects, ProcessInfo0;

CONST
	MaxNofProcesses* = 1000;

TYPE
	ProcessArray* = ProcessInfo0.ProcessArray;

	IsGreaterThanProc* = PROCEDURE {DELEGATE} (p1, p2 : Objects.Process) : BOOLEAN; (* { p1, p2 # NIL } *)

PROCEDURE Clear*(VAR array : ProcessArray);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(array)-1 DO array[i] := NIL; END;
END Clear;

PROCEDURE Copy*(CONST from : ProcessArray; VAR to : ProcessArray);
VAR length, fromLength, toLength, i : LONGINT;
BEGIN
	fromLength := LEN(from);
	toLength := LEN(to);
	IF (fromLength <= toLength) THEN length := fromLength; ELSE length := toLength; END;
	FOR i := 0 TO length - 1 DO
		to[i] := from[i];
	END;
	FOR i := length - 1 TO toLength - 1 DO
		to[i] := NIL;
	END;
END Copy;

PROCEDURE Sort*(VAR processes : ProcessArray; nofProcesses : LONGINT; isGreaterThan : IsGreaterThanProc);
VAR i, j : LONGINT; temp : Objects.Process;
BEGIN
	ASSERT(isGreaterThan # NIL);
	(* bubble sort, descending *)
	FOR i := 0 TO nofProcesses - 1 DO
		FOR j := 0 TO nofProcesses - 2 DO
			IF isGreaterThan(processes[j + 1], processes[j]) THEN
				temp := processes[j];
				processes[j] := processes[j + 1];
				processes[j + 1] := temp;
			END;
		END;
	END;
END Sort;

PROCEDURE Find*(CONST processes : ProcessArray; id : LONGINT) : Objects.Process;
VAR process : Objects.Process; i : LONGINT;
BEGIN
	i := 0;
	WHILE (i < LEN(processes)-1) & (processes[i] # NIL) & (processes[i].id # id) DO INC(i); END;
	IF (i < LEN(processes)) THEN
		process := processes[i];
	ELSE
		process := NIL;
	END;
	RETURN process;
END Find;

PROCEDURE SortByID*(p1, p2 : Objects.Process) : BOOLEAN;
BEGIN
	ASSERT((p1 # NIL) & (p2 # NIL));
	RETURN p1.id > p2.id;
END SortByID;

PROCEDURE SortByPriority*(p1, p2 : Objects.Process) : BOOLEAN;
BEGIN
	ASSERT((p1 # NIL) & (p2 # NIL));
	RETURN p1.priority > p2.priority;
END SortByPriority;

PROCEDURE SortByMode*(p1, p2 : Objects.Process) : BOOLEAN;
BEGIN
	ASSERT((p1 # NIL) & (p2 # NIL));
	RETURN p1.mode > p2.mode;
END SortByMode;

PROCEDURE GetProcesses*(VAR processes : ProcessArray; VAR nofProcesses : LONGINT);
BEGIN
	ProcessInfo0.GetProcesses(processes, nofProcesses);
END GetProcesses;

PROCEDURE GetProcess*(pid : LONGINT) : Objects.Process;
BEGIN
	RETURN ProcessInfo0.GetProcess(pid);
END GetProcess;

PROCEDURE WriteMode*(mode : LONGINT; out : Streams.Writer);
BEGIN
	CASE mode OF
		|Objects.Ready : out.String("rdy");
		|Objects.Running : out.String("run");
		|Objects.AwaitingLock : out.String("awl");
		|Objects.AwaitingCond : out.String("awc");
		|Objects.AwaitingEvent : out.String("awe");
		|Objects.Terminated : out.String("rip");
	ELSE
		out.String("???");
	END;
	out.Update;
END WriteMode;

PROCEDURE WriteActiveObject*(t : Objects.Process; out : Streams.Writer);
VAR adr : LONGINT;
BEGIN
	IF t.obj # NIL THEN
		SYSTEM.GET(SYSTEM.VAL(LONGINT, t.obj)-4, adr);
		Reflection.WriteType(out, adr);
	END;
END WriteActiveObject;

PROCEDURE WriteWaitingOn*(t : Objects.Process; out : Streams.Writer);
VAR adr : LONGINT; mod : Modules.Module;
BEGIN
	IF t.mode = Objects.AwaitingLock THEN
		adr := SYSTEM.VAL(LONGINT, t.waitingOn);
		IF adr # 0 THEN	(* can be 0 when snapshot is taken *)
			SYSTEM.GET(adr-4, adr); DEC(adr, adr MOD 8);
			IF adr = SYSTEM.TYPECODE(Modules.Module) THEN
				mod := SYSTEM.VAL(Modules.Module, adr);
				out.String(mod.name);
			ELSE
				Reflection.WriteType(out, adr);
			END;
		END
	ELSIF t.mode = Objects.AwaitingCond THEN
		Reflection.WriteProc(out, SYSTEM.VAL(LONGINT, t.condition));
	END;
	out.Update;
END WriteWaitingOn;

PROCEDURE WriteFlags*(flags : SET; out : Streams.Writer);
VAR comma : BOOLEAN;
BEGIN
	comma := FALSE;
	IF Objects.Restart IN flags THEN
		out.String("restart"); comma := TRUE;
	END;
	IF Objects.Resistant IN flags THEN
		IF comma THEN out.String(", "); END;
		out.String("resistant"); comma := TRUE;
	END;
	IF Objects.Preempted IN flags THEN
		IF comma THEN out.String(", "); END;
		out.String("preempted"); comma := TRUE;
	END;
	IF Objects.PleaseHalt IN flags THEN
		IF comma THEN out.String(", "); END;
		out.String("pleaseHalt"); comma := TRUE;
	END;
	IF Objects.Unbreakable IN flags THEN
		IF comma THEN out.String(", "); END;
		out.String("unbreakable"); comma := TRUE;
	END;
	IF Objects.SelfTermination IN flags THEN
		IF comma THEN out.String(", "); END;
		out.String("selftermination");
	END;
	out.Update;
END WriteFlags;

PROCEDURE ShowStack*(p : Objects.Process; out : Streams.Writer);
BEGIN
	ASSERT((p # NIL) & (out # NIL));
	out.String("Active Object: "); WriteActiveObject(p, out); out.Ln;
	out.String("Current Procedure: ");
	Reflection.WriteProc(out, p.state.PC); out.Ln;

	(* mode *)
	out.String("Mode: "); WriteMode(p.mode, out); out.Ln;
	out.String("Waiting On: "); WriteWaitingOn(p, out); out.Ln;

	(* Flags *)
	out.String("Flags: "); WriteFlags(p.flags, out); out.Ln;

	out.String("Stack Trace Back:"); out.Ln; out.Update;
	Reflection.StackTraceBack(out, p.state.PC, p.state.BP, Objects.GetStackBottom(p), TRUE, FALSE);
	out.Ln; out.Update;
END ShowStack;

PROCEDURE ShowProcess*(p : Objects.Process; out : Streams.Writer);
BEGIN
	ASSERT((p # NIL) & (out # NIL));
	IF (p.mode # Objects.Terminated) THEN
		out.Int(p.id, 5); out.String("   ");
		WriteMode(p.mode, out); out.String("   ");
		WriteActiveObject(p, out);
		out.Ln; out.Update;
	END;
END ShowProcess;

END ProcessInfo.

ProcessInfo.ShowProcesses ~

ProcessInfo.ShowStacks ~

SystemTools.Free ProcessInfo ProcessInfo0 ~
