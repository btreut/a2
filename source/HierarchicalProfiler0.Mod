MODULE HierarchicalProfiler0; (** AUTHOR "staubesv"; PURPOSE "Platform-specific part of the hierarchical profiler"; *)

IMPORT
	SYSTEM, Machine, Objects, Modules, Kernel;

CONST
	HandlerNotInstalled = 0;
	HandlerInstalled = 1;

	(* 	Time to wait when unloading the module before it is actually unloaded. This avoids that a pending interrupt
		calls 'HandleTimer' when the module is already unloaded. *)
	WaitTime = 100;	(* ms *)

TYPE
	Callback = PROCEDURE (id : LONGINT; process : Objects.Process; pc, bp, lowAdr, highAdr : ADDRESS);

VAR
	callback : Callback;
	state : LONGINT;

(* First level interrupt handler. Called 1000 times per second by each processor *)
PROCEDURE HandleTimer(id: LONGINT; CONST state: Machine.State);
VAR process : Objects.Process;
BEGIN
	process := Objects.running[id];
	callback(id, process, state.PC, state.BP, state.SP, LONGINT(0FFFFFFFFH));
END HandleTimer;

(** Start profiling. If the profiler is already running, it is stopped and the sample data is discarded before re-starting it *)
PROCEDURE Enable*(proc : Callback);
BEGIN {EXCLUSIVE}
	ASSERT(proc # NIL);
	ASSERT(state = HandlerNotInstalled);
	Machine.InstallEventHandler(HandleTimer);
	state := HandlerInstalled;
END Enable;

(** Stop profiling. The profile data is not discarded. It can be retrieved using the procedure 'GetProfile' *)
PROCEDURE Disable*;
VAR timer : Kernel.Timer;
BEGIN {EXCLUSIVE}
	ASSERT(state = HandlerInstalled);
	Machine.InstallEventHandler(NIL);
	NEW(timer); timer.Sleep(WaitTime);
END Disable;

PROCEDURE Cleanup;
BEGIN
	Machine.InstallEventHandler(NIL);
END Cleanup;

BEGIN
	callback := NIL;
	state := HandlerNotInstalled;
	Modules.InstallTermHandler(Cleanup);
END HierarchicalProfiler0.
