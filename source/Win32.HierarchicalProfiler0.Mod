MODULE HierarchicalProfiler0; (** AUTHOR "staubesv"; PURPOSE "WinAos platform-specific part of the hierarchical profiler"; *)

IMPORT
	SYSTEM, Kernel32, Objects, Modules, ProcessInfo;

CONST
	Initialized = 0;
	Running = 1;
	Terminating = 2;
	Terminated = 3;

	Intervall = 1; (* milliseconds *)

TYPE

	ProcessTimeArray = POINTER TO ARRAY ProcessInfo.MaxNofProcesses OF HUGEINT;

	Callback = PROCEDURE (id : LONGINT; process : Objects.Process; pc, bp, lowAdr, highAdr : ADDRESS);

	Poller = OBJECT
	VAR
		processes, oldProcesses : ARRAY ProcessInfo.MaxNofProcesses OF Objects.Process;
		nofProcesses, oldNofProcesses : LONGINT;
		times, oldTimes : ProcessTimeArray;
		me : Objects.Process;
		state : LONGINT;

		PROCEDURE &Init;
		BEGIN
			state := Running;
			ProcessInfo.Clear(processes); nofProcesses := 0;
			ProcessInfo.Clear(oldProcesses); oldNofProcesses := 0;
			NEW(times); Clear(times);
			NEW(oldTimes); Clear(oldTimes);
		END Init;

		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			IF (state # Terminated) THEN state := Terminating; END;
			AWAIT(state = Terminated);
		END Terminate;

		PROCEDURE Clear(array : ProcessTimeArray);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(array)-1 DO array[i] := 0; END;
		END Clear;

		PROCEDURE RanMeanwhile(process : Objects.Process; currentCycles : HUGEINT) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN

			IF ~(process.mode IN {Objects.Running,Objects.Ready}) THEN RETURN FALSE END;

			i := 0; WHILE (i < oldNofProcesses) &	(oldProcesses[i] # process) DO INC(i); END;
			RETURN (i >= oldNofProcesses) OR (oldTimes[i] < currentCycles);
		END RanMeanwhile;

		PROCEDURE Process;
		VAR process : Objects.Process; cycles : Objects.CpuCyclesArray; temp : ProcessTimeArray; i : LONGINT;
			t0,t1,t2,t3: Kernel32.FileTime;
		BEGIN
			ProcessInfo.GetProcesses(processes, nofProcesses);
			FOR i := 0 TO nofProcesses - 1 DO
				process := processes[i];

				Objects.GetCpuCycles(process, cycles, FALSE); (* higher granularity counter, but does not detect suspending of thread *)
				times[i] := cycles[0];
				(*
				Kernel32.GetThreadTimes(process.handle, t0,t1,t2,t3);
				times[i] := HUGEINT(t2.dwLowDateTime+t3.dwLowDateTime) + 10000000H * HUGEINT(t2.dwHighDateTime+t3.dwHighDateTime) ;
				*)
				IF (process # me) & (cycles[0] # 0)  & (process.mode = Objects.Running) (* (process.mode # Objects.AwaitingEvent) & (process.mode # Objects.AwaitingCond)  & (process.mode < Objects.Suspended) & (process.mode >= Objects.Ready)  (*RanMeanwhile(process, times[i]) *) *) THEN
					HandleProcess(process);
				END;
			END;
			temp := oldTimes;
			oldTimes := times;
			times := temp;
			ProcessInfo.Copy(processes, oldProcesses); oldNofProcesses := nofProcesses;
			ProcessInfo.Clear(processes);
		END Process;

	BEGIN {ACTIVE, PRIORITY(Objects.Realtime)}
		me := Objects.CurrentProcess();
		LOOP
			WHILE (state = Running) DO
				Process;
				(*Kernel32.Sleep(Intervall);*)
			END;
			IF (state = Terminating) THEN EXIT; END;
		END;
		ProcessInfo.Clear(processes);
		ProcessInfo.Clear(oldProcesses);
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END Poller;

VAR
	poller : Poller;
	callback : Callback;
	state : LONGINT;

PROCEDURE HandleProcess(process : Objects.Process);
VAR context : Kernel32.Context; handle : Kernel32.HANDLE; res : Kernel32.BOOL; stackBottom, sp, bp: ADDRESS;
BEGIN
	ASSERT(process # NIL);
	handle := process.handle;
	IF (handle # Kernel32.NULL) & (handle # Kernel32.InvalidHandleValue) THEN
		res := Kernel32.SuspendThread(handle);
		IF (res >= 0) THEN
			context.ContextFlags := Kernel32.ContextControl+Kernel32.ContextInteger;
			res := Kernel32.GetThreadContext(handle, context);
			IF (res = Kernel32.True) THEN
				IF (context.PC # 0) THEN
					stackBottom := Objects.GetStackBottom(process);
					bp := context.BP;
					sp := context.SP;
					ASSERT(context.BP <= stackBottom);
					callback(1, process, context.PC, context.BP, context.SP,  stackBottom(*  LONGINT(0FFFFFFFFH)*)  );
				END;
			END;
			res := Kernel32.ResumeThread(handle);
		END;
	END;
END HandleProcess;

PROCEDURE Enable*(proc : Callback);
BEGIN {EXCLUSIVE}
	ASSERT(proc # NIL);
	ASSERT((state = Initialized) & (poller = NIL));
	callback := proc;
	NEW(poller);
	state := Running;
END Enable;

PROCEDURE Disable*;
BEGIN {EXCLUSIVE}
	ASSERT((state = Running) & (poller # NIL));
	poller.Terminate;
	poller := NIL;
	state := Initialized;
END Disable;

PROCEDURE Cleanup;
BEGIN
	IF (poller # NIL) THEN poller.Terminate; poller := NIL; END;
END Cleanup;

BEGIN
	state := Initialized;
	Modules.InstallTermHandler(Cleanup);
END HierarchicalProfiler0.

WMProfiler.Open

SystemTools.Free WMProfiler HierarchicalProfiler HierarchicalProfiler0 ~
