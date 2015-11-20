 (* Aos, Copyright 2001, Pieter Muller, ETH Zurich; this module ported for the windows version, fof. *)

MODULE Objects;   (** AUTHOR "pjm, ejz, fof"; PURPOSE "Active object runtime support"; *)

IMPORT SYSTEM, Environment, Machine, Modules, Heaps, Activities, Interrupts, CPU, TimerModule := Timer;

CONST
	(* Process flags *)
	Restart* = 0;   (* Restart/Destroy process on exception *)
	PleaseHalt* = 10;   (* Process requested to Halt itself soon *)
	Unbreakable* = 11;
	SelfTermination* = 12;
	Preempted* = 27;   (* Has been preempted. *)
	Resistant* = 28;   (* Can only be destroyed by itself *)
	PleaseStop* = 31;   (* Process requested to Terminate or Halt itself soon *)

	InActive* = 26;   (* needed to prevent processes to call finalizers while in await or lock or unlock, see Kernel.GC *)

	(** Process modes *)
	Unknown* = 0; Ready* = 1; (* for compatibility with native A2 *)
	Running* = 2; AwaitingLock* = 3; AwaitingCond* = 4; AwaitingEvent* = 5; Suspended* = 6; Terminated* = 7;

	(** Process priorities *)
	Low* = Activities.DefaultPriority;								(* "user" priorities *)
	Normal* = Activities.DefaultPriority;	
	High* = Activities.HighPriority;
	Realtime* = Activities.RealtimePriority;						(* reserved for interrupt handling and realtime apps *)

	(* Process termination halt codes *)
	halt* = 2222;
	haltUnbreakable* = 2223;

TYPE
	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	ProtectedObject = POINTER TO RECORD END;   (* protected object (10000) *)

	Body = PROCEDURE (self: ProtectedObject);
	Condition = PROCEDURE (slink: ADDRESS): BOOLEAN;

	EventHandler* = PROCEDURE {DELEGATE};
	RealtimeEventHandler* = PROCEDURE {DELEGATE, REALTIME};

	Timer* = POINTER TO RECORD
		next, prev : Timer;
		trigger: LONGINT;
		handler: EventHandler
	END;

	RealtimeTimer* = POINTER TO RECORD
		next, prev: RealtimeTimer;
		trigger: LONGINT;
		handler: RealtimeEventHandler
	END;

	Clock = OBJECT
	VAR h: Timer;
	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		WHILE Environment.status = 0 DO
			Machine.Acquire(Machine.Objects);
			LOOP
				h := event.next;
				IF (h = event) OR (h.trigger - Environment.Clock () > 0) THEN EXIT END;
				event.next := h.next; event.next.prev := event; (* unlink *)
				h.next := NIL; h.prev := NIL;
				Machine.Release(Machine.Objects);
				h.handler;	(* assume handler will return promptly *)
				Machine.Acquire(Machine.Objects);
			END;
			Machine.Release(Machine.Objects);
			Environment.Sleep (1);
		END
	END Clock;

TYPE

	Process* = OBJECT(Heaps.ProcessLink)
	VAR
		obj-: ProtectedObject;   (* associated active object *)
		state-: RECORD PC-,BP-: ADDRESS END;
		condition-: Condition;   (* awaited process' condition *)
		condFP-: LONGINT;   (* awaited process' condition's context *)
		mode-: LONGINT;   (* process state *)  (* only changed inside Objects lock ??? *)
		procID-: LONGINT;   (* processor ID where running,  exported for compatibilty , useless in WinAos *)
		waitingOn-: ProtectedObject;   (* obj this process is waiting on (for lock or condition) *)
		id-: LONGINT;   (* unique process ID for tracing *)
		flags*: SET;   (* process flags *)
		priority-: LONGINT;   (* process priority *)
		stackBottom: LONGINT;
		restartPC-: LONGINT;   (** entry point of body, for SAFE exception recovery *)
		restartSP-: LONGINT;   (** stack level at start of body, for SAFE exception recovery *)
		cpuCycles, lastCpuCycles : CpuCyclesArray;

	END Process;

	FinalizedCollection* = OBJECT
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;
	
	InterruptList = POINTER TO RECORD
		next: InterruptList;
		handler: EventHandler
	END;

	Interrupter* = OBJECT

		VAR root: InterruptList;
		VAR cancelled: BOOLEAN;
		VAR interrupt: Interrupts.Interrupt;
		
		PROCEDURE &Init (irq: SIZE);
		BEGIN
			Interrupts.Install (interrupt, irq);
		END Init;

		PROCEDURE Add (handler: EventHandler);
		VAR item: InterruptList;
		BEGIN {EXCLUSIVE}
			NEW (item);
			item.next := root;
			item.handler := handler;
			root := item;
		END Add;
		
		PROCEDURE Remove (handler: EventHandler);
		VAR previous, current: InterruptList;
		BEGIN {EXCLUSIVE}
			previous := NIL; current := root;
			WHILE (current # NIL) & (current.handler # handler) DO
				previous := current; current := current.next;
			END;
			IF current # NIL THEN
				IF previous = NIL THEN
					root := current.next;
				ELSE
					previous.next := current.next;
				END;
			END;
		END Remove;
		
		PROCEDURE Count(): SIZE;
		VAR count := 0: SIZE; item: InterruptList;
		BEGIN {EXCLUSIVE}
			item := root;
			WHILE item # NIL DO INC (count); item := item.next END;
			RETURN count;
		END Count;
		
		PROCEDURE Cancel;
		BEGIN {EXCLUSIVE}
			IF ~cancelled THEN
				cancelled := TRUE;
				Interrupts.Cancel (interrupt);
				WAIT (SELF);
			END;
		END Cancel;

		PROCEDURE Handle;
		VAR item: InterruptList;
		BEGIN {EXCLUSIVE}
			item := root;
			WHILE item # NIL DO
				item.handler;
				item := item.next;
			END;
		END Handle;

	BEGIN {ACTIVE, PRIORITY(Realtime)}
		LOOP
			Interrupts.Await (interrupt);
			IF cancelled THEN EXIT END;
			Handle;
		END;
	END Interrupter;

VAR
	awc-, awl-: LONGINT;
	oberonLoop*: ANY;   (* Oberon Loop Process temporary workaround for Threads.oberonLoop *)

	event: Timer; (* list of events *)
	clock: Clock;
	interrupt: ARRAY CPU.Interrupts OF Interrupter;

(* Set the current process' priority. *)
PROCEDURE SetPriority*( priority: LONGINT );
BEGIN
END SetPriority;

(** Return TRUE iff the specified protected object is locked exclusive to the current process. *)
PROCEDURE LockedByCurrent*( obj: ANY ): BOOLEAN;
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; res: BOOLEAN;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	ASSERT(hdr IS Heaps.ProtRecBlock);
	Machine.Acquire(Machine.Objects);
	res := (hdr.lockedBy = ActiveObject());
	Machine.Release(Machine.Objects);
	RETURN res
END LockedByCurrent;

PROCEDURE Yield*;
BEGIN
	Activities.Switch;
END Yield;

(** Return current process. (DEPRECATED, use ActiveObject) *)
PROCEDURE CurrentProcess*( ): Process;
BEGIN
	HALT (1234);
	RETURN NIL;
END CurrentProcess;

(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
PROCEDURE GetStackBottom*(p: Process): ADDRESS;
BEGIN
	RETURN p.stackBottom
END GetStackBottom;

(** Return the active object currently executing. *)
PROCEDURE ActiveObject* (): ANY;
BEGIN
	RETURN Activities.GetCurrentActivity ().object;
END ActiveObject;

(** Return the ID of the active currently executing process. *)
PROCEDURE GetProcessID* (): LONGINT;
BEGIN
	RETURN SYSTEM.VAL (LONGINT, Activities.GetCurrentActivity ());
END GetProcessID;

(* Attempt to terminate a specific process (mostly ignoring its locks). DEPRECATED *)
PROCEDURE TerminateThis*( t: Process;  halt: BOOLEAN );
END TerminateThis;

PROCEDURE Terminate*;
BEGIN
	Activities.TerminateCurrentActivity;
END Terminate;

(** Set (or reset) an event handler object's timeout value. *)
PROCEDURE SetTimeout*(t: Timer; h: EventHandler;  ms: LONGINT );
VAR e: Timer; trigger: LONGINT;
BEGIN
	ASSERT((t # NIL) & (h # NIL));
	IF ms < 1 THEN ms := 1 END;
	Machine.Acquire(Machine.Objects);
	trigger := Environment.Clock () + ms;
	IF t.next # NIL THEN (* cancel previous timeout *)
		t.next.prev := t.prev; t.prev.next := t.next
	END;
	t.trigger := trigger; t.handler := h;
	e := event.next;	(* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev; e.prev := t; t.next := e; t.prev.next := t;
	Machine.Release(Machine.Objects)
END SetTimeout;

(** Set (or reset) an event handler object's timeout value. Here ms is absolute *)
PROCEDURE SetTimeoutAt*(t: Timer; h: EventHandler; ms: LONGINT);
VAR e: Timer; trigger: LONGINT;
BEGIN
	ASSERT((t # NIL) & (h # NIL));
	Machine.Acquire(Machine.Objects);
	trigger := ms; (* ignore overflow *)
	IF t.next # NIL THEN (* cancel previous timeout *)
		t.next.prev := t.prev; t.prev.next := t.next
	END;
	t.trigger := trigger; t.handler := h;
	e := event.next;	(* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev; e.prev := t; t.next := e; t.prev.next := t;
	Machine.Release(Machine.Objects);
END SetTimeoutAt;

(** Cancel an event handler object's timeout, if any. It is possible that the timer has expired, but not yet been scheduled to run. *)
PROCEDURE CancelTimeout*( t: Timer );
BEGIN
	Machine.Acquire(Machine.Objects);
	ASSERT (t # event );
	IF t.next # NIL THEN
		t.next.prev := t.prev;  t.prev.next := t.next;  t.next := NIL;
		t.prev := NIL
	END;
	Machine.Release(Machine.Objects);
END CancelTimeout;

PROCEDURE InitEventHandling;
BEGIN
	NEW(event); event.next := event; event.prev := event;  (* event: head of timer event queue, only a sentinel *)
	NEW(clock)
END InitEventHandling;

PROCEDURE NumReady*( ): LONGINT;
BEGIN
	RETURN 0
END NumReady;

(** Return number of CPU cycles consumed by the specified process. If all is TRUE,
	return the number of cycles since the process has been created. If FALSE, return the number of cycles
	consumed since the last time asked. *)
PROCEDURE GetCpuCycles*(process : Process; VAR cpuCycles : CpuCyclesArray; all : BOOLEAN);
VAR i : LONGINT;
BEGIN
	ASSERT(process # NIL);
	FOR i := 0 TO Machine.MaxCPU-1 DO cpuCycles[i] := process.cpuCycles[i]; END;
	IF ~all THEN
		FOR i := 0 TO Machine.MaxCPU-1 DO
			cpuCycles[i] := cpuCycles[i] - process.lastCpuCycles[i];
			process.lastCpuCycles[i] := process.cpuCycles[i]; (* actually could have changed meanwhile *)
		END;
	END;
END GetCpuCycles;

PROCEDURE CurrentProcessTime*(): HUGEINT;
BEGIN
	RETURN Activities.GetProcessTime();
END CurrentProcessTime;

PROCEDURE TimerFrequency*(): HUGEINT;
BEGIN
	RETURN TimerModule.GetFrequency();
END TimerFrequency;

(** Install interrupt handler. *)
PROCEDURE InstallHandler*(h: EventHandler; int: LONGINT);
VAR ih: Interrupter;
BEGIN {EXCLUSIVE}
	ASSERT((int >= 0) & (int < CPU.Interrupts));
	ih := interrupt[int];
	IF ih = NIL THEN
		NEW (ih, int);
		interrupt[int] := ih;
	END;
	ih.Add(h);
END InstallHandler;

(** Remove interrupt handler. *)
PROCEDURE RemoveHandler*(h: EventHandler; int: LONGINT);
VAR ih: Interrupter;
BEGIN {EXCLUSIVE}
	ASSERT((int >= 0) & (int < CPU.Interrupts));
	ih := interrupt[int];
	IF ih # NIL THEN
		ih.Remove(h);
		IF ih.Count () = 0 THEN
			ih.Cancel;
			interrupt[int] := NIL;
		END;
	END;
END RemoveHandler;

BEGIN
	InitEventHandling;
END Objects.

(*
24.03.1998	pjm	Started
06.05.1998	pjm	CreateProcess init process, page fault handler
06.08.1998	pjm	Moved exception interrupt handling here for current process
17.08.1998	pjm	FindRoots method
02.10.1998	pjm	Idle process
06.11.1998	pjm	snapshot
25.03.1999	pjm	Scope removed
28.05.1999	pjm	EventHandler object
01.06.1999	pjm	Fixed InterruptProcess lock error
16.06.1999	pjm	Flat IRQ priority model to avoid GC deadlock
23.06.1999	pjm	Flat IRQ priority experiment failed, rather do STI in FieldIRQ to avoid GC deadlock
29.06.1999	pjm	Timeout in EventHandler object
13.01.2000	pjm	Overed (Interrupt Objects, Event Handlers, Process ID, Process state, Process mode, Process stack, Await)
17.10.2000	pjm	Priorities
22.10.2003	mib	SSE2 extension
24.10.2003	phk	Priority inversion / cycle counters

Stack invariant for GC:
o if process is running, the processor registers contain its state
o if process is not running, at least state.ESP is valid, and between stack.adr and stack.high (for GC)

o when releasing the Ready lock, make sure the process state is up to date
*)

