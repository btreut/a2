MODULE Objects;	(** AUTHOR "pjm"; PURPOSE "Active object runtime support"; *)

IMPORT SYSTEM, Trace, Machine, Heaps, Modules;

CONST
	(** Process flags *)
	Restart* = 0;			(* Restart/Destroy process on exception (hardcoded in compiler (OPC.CallRecBody / PCC.SysStart)) *)
	PleaseHalt* = 10;		(* Process requested to Halt itself soon *)
	Unbreakable*= 11;		(* FINALLY shall not catch HALT exception (PleaseHalt is also set) *)
	SelfTermination*=12;	(* Indicates the process has requested to terminate ifself (PleaseHalt is also set) *)
	Preempted* = 27;		(* Has been preempted. *)
	Resistant* = 28;		(* Can only be destroyed by itself *)

	(** Process modes *)
	Unknown* = 0; Ready* = 1; Running* = 2; AwaitingLock* = 3;
	AwaitingCond* = 4; AwaitingEvent* = 5; Suspended* = 6; (* Suspened for compatibility with WinAos, not used for native A2 *)
	Terminated* = 7;

	(** Process priorities *)
	MinPriority = 0;							(* only system idle processes run at this priority level *)
	Low* = 1; Normal* = 2; High* = 3;		(* "user" priorities *)
	GCPriority* = 4;							(* priority of garbage collector *)
	Realtime* = 5;							(* reserved for interrupt handling and realtime apps, these processes are not allowed to allocate memory *)
	NumPriorities = Heaps.NumPriorities; 	(* number of priority levels *)

	(* Process termination halt codes *)
	halt* = 2222;
	haltUnbreakable* = 2223;

	MinIRQ = Machine.IRQ0;
	NumIRQ = Machine.MaxIRQ-MinIRQ+1;

	Stats* = FALSE;	  (* maintain statistical counters *)
	TraceVerbose = FALSE;	(* write out verbose trace info *)
	StrongChecks = TRUE;	(* strong sanity checks *)
	VeryConservative = FALSE;	(* temp - be very conservative about stack-based pointers *)
	YieldTrick = FALSE;	(* avoid yield when no ready process available *)

	HandlePriorityInv = TRUE; (* enables or disables priority inversion handling. Handling of priority inversion leads to a simplified locking, see Lock, Unlock and Await *)

	(* constant used in GC Process.FindPointers *)
	InitDiff = MAX(LONGINT);

	AddressSize = SIZEOF(ADDRESS);

TYPE
	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	EventHandler* = PROCEDURE {DELEGATE};

	Timer* = POINTER TO RECORD
		next, prev : Timer;
		trigger: LONGINT;
		handler: EventHandler
	END;

	ProtectedObject = POINTER TO RECORD END; (* protected object *)

	ProcessQueue = Heaps.ProcessQueue;

	Body = PROCEDURE (self: ProtectedObject);
	Condition = PROCEDURE (slink: ADDRESS): BOOLEAN;

	InterruptList = POINTER TO RECORD
		next: InterruptList;
		handler: EventHandler
	END;

TYPE

	(** All exported fields and variables should be considered read-only. *)
	Process* = OBJECT (Heaps.ProcessLink)
	VAR
		rootedNext : Process;	(** for rootedProcesses *)
		obj-: ProtectedObject;	(** associated active object *)
		state-: Machine.State;	(** processor state of suspended process *)
		sse: Machine.SSEState;	(* fpu and sse state of preempted process (only valid if Preempted IN flag) *)
		sseAdr: ADDRESS;
		condition-: Condition;	(** awaited process' condition *)
		condFP-: ADDRESS;	(** awaited process' condition's context *)
		mode-: LONGINT;	(** process state *)	(* only changed inside Objects lock ??? *)
		procID-: LONGINT;	(** processor ID where running *)
		waitingOn-: ProtectedObject;	(** obj this process is waiting on (for lock or condition) *)
		id-: LONGINT;	(** unique process ID for tracing *)
		flags*: SET;	(** process flags *)
		priority-, staticPriority*: LONGINT;	(** process dynamic priority (can change during priority inversion handling) and static priority *)	(* exported for AosExceptions *)
		stack*: Machine.Stack;	(** user-level stack of process *)
		restartPC-: ADDRESS;	(** entry point of body, for SAFE exception recovery *)
		restartSP-: ADDRESS;	(** stack level at start of body, for SAFE exception recovery *)
		exp*: Machine.ExceptionState;
		oldReturnPC: ADDRESS;
		cpuCycles, lastCpuCycles : CpuCyclesArray;
		prioRequests : ARRAY NumPriorities OF LONGINT; (* priorities of processes that wait for resources locked by this process, only the highest priority per resource is stored *)

		(* set priority of process: Machine.Objects lock is taken *)
		PROCEDURE SetPriority(p : LONGINT);
		BEGIN
			DEC(prioRequests[staticPriority]);
			staticPriority := p;
			INC(prioRequests[staticPriority]);
			priority := MaxPrio(prioRequests)
		END SetPriority;

		PROCEDURE FindRoots; (* override *)
		VAR pc, bp, curbp, sp: ADDRESS; d0, d1: SIZE; first : BOOLEAN;
		BEGIN
			IF traceProcess # NIL THEN traceProcess(SELF) END;

					(* stack garbage collection *)
			IF (priority >= Low) & (priority <= High) & (mode >= Ready) & (mode # Terminated) THEN
			(* only processes with priority < GCPriority are preempted during GC,
			    only those are allowed to allocate memory and their stacks are inspected.
			    Furthermore, the process must be in a valid state, e.g. terminated processes have a disposed stack. *)

				IF Heaps.GCType = Heaps.HeuristicStackInspectionGC THEN

					IF VeryConservative THEN
						Heaps.RegisterCandidates(stack.adr, stack.high-stack.adr)
					ELSE
						sp := state.SP;	(* cf. Enter *)
						IF sp # 0 THEN
							IF Machine.ValidStack(stack, sp) THEN
								Heaps.RegisterCandidates(sp, stack.high - sp)
							END
						ELSE
							Trace.String("[Objects.FindRoots sp=0]")
						END
					END

				ELSIF Heaps.GCType = Heaps.MetaDataForStackGC THEN

					bp := state.BP; pc := state.PC; first := TRUE;
					IF pc # 0 THEN 	(* process is running already *)
						WHILE (bp # Heaps.NilVal) & (stack.adr <= bp) & (bp < stack.high) DO
							FindPointers(bp, pc, d0, d1);
 							IF first THEN
 								IF (d0 = 0) OR (d0 = 1) OR (d1 = 3) THEN
 									(* 	situation where pc and bp are not synchronized: *)
 									(* 	entry protocol of a procedure:
 										PUSH 	EBP			-- 1 byte instruction length, if pc points to this instruction at offset 0 from the codeoffset then bp still refers to caller frame -> critical
 										MOV	EBP, ESP	-- 2 bytes instruction length, do. for offset 1 from the codeoffset
 										(followed by initialization of local variables)
 										exit protocol of a procedure:
 										MOV	ESP, EBP	-- 2 bytes instruction length
 										POP	EBP			-- 1 byte instruction length
 										RET		n			-- 3 bytes instruction length, if pc points to this instruction at offset 3 from the last statement then bp already refers to caller's frame -> critical
 									*)
 									IF (d0 = 0) OR (d1 = 3) THEN
 										SYSTEM.GET(state.SP, pc);		(* matching pc is at position of stack pointer *)
 									ELSE
 										SYSTEM.GET(state.SP+AddressSize, pc);		(* matching pc is at 4 bytes after stack pointer, pushed base pointer is at stack pointer position *)
									END;
 								ELSE
 									(* regular case: bp and pc were synchronized *)
 									curbp := bp;
									SYSTEM.GET(curbp, bp);
									SYSTEM.GET(curbp+AddressSize, pc);
 								END;
 								first := FALSE;
 							ELSE
 								(* regular case: bp and pc were synchronized *)
 								curbp := bp;
								SYSTEM.GET(curbp, bp);
								SYSTEM.GET(curbp+AddressSize, pc);
							END
						END
					END

				ELSE
					HALT(900) (* wrong GCType constant *)
				END

			END

		END FindRoots;

		PROCEDURE FindPointers(bp, pc : ADDRESS; VAR diff0, diff1: SIZE);
		VAR data: Modules.ProcTableEntry; startIndex, i: LONGINT; ptr : ADDRESS; success: BOOLEAN;
		BEGIN
			diff0 := InitDiff; diff1 := InitDiff;
			Modules.FindProc(pc, data, startIndex, success);
			IF success THEN
				diff0 := pc - data.pcFrom;
				diff1 := pc - data.pcStatementEnd;
				IF (data.noPtr > 0) & (pc >= data.pcStatementBegin) & (pc <= data.pcStatementEnd) THEN
					FOR i := 0 TO data.noPtr - 1 DO
						SYSTEM.GET(bp + Modules.ptrOffsets[startIndex + i], ptr);
						IF ptr # Heaps.NilVal THEN
							Heaps.Mark(SYSTEM.VAL(ANY, ptr))
						END
					END
				END
			END
		END FindPointers;

	END Process;

	TraceProcess* = PROCEDURE (p: Process);

	ExceptionHandler* = PROCEDURE(p: Process; VAR int: Machine.State; VAR exc: Machine.ExceptionState; VAR return: BOOLEAN);

	Idle = OBJECT
	BEGIN {ACTIVE, SAFE, PRIORITY(-1)}	(* negative priority equivalent to MinPriority *)
		LOOP
			REPEAT
				IF ProcessorHLT # NIL THEN ProcessorHLT	(* UP *)
				ELSE Machine.SpinHint (* MP *)
				END
			UNTIL maxReady >= lowestAllowedPriority;
			Yield
		END
	END Idle;

	Clock = OBJECT
	VAR h: Timer;
	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		LOOP
			Machine.Acquire(Machine.Objects);
			LOOP
				h := event.next;
				IF (h = event) OR (h.trigger - Machine.ticks > 0) THEN EXIT END;
				event.next := h.next; event.next.prev := event; (* unlink *)
				h.next := NIL; h.prev := NIL;
				Machine.Release(Machine.Objects);
				h.handler;	(* assume handler will return promptly *)
				Machine.Acquire(Machine.Objects)
			END;
			ASSERT(timer = NIL); (* temp strong check *)
			timer := running[Machine.ID ()];
			timer.mode := AwaitingEvent;
			SwitchToNew
		END
	END Clock;

	ReadyProcesses = OBJECT(Heaps.RootObject)
		VAR q {UNTRACED}: ARRAY NumPriorities OF ProcessQueue;

		PROCEDURE &Init;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO NumPriorities - 1 DO
				q[i].head := NIL; q[i].tail := NIL
			END
		END Init;

		PROCEDURE FindRoots; (* override *)
		VAR i: LONGINT;
		BEGIN
			(* only mark queues of user processes since these will not change during GC *)
			FOR i := Low TO High DO
				Heaps.Mark(q[i].head);
				Heaps.Mark(q[i].tail)
			END
		END FindRoots;

	END ReadyProcesses;

	GCStatusExt = OBJECT(Heaps.GCStatus)
		VAR gcOngoing: BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			gcOngoing := FALSE;
		END Init;

		(* called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects lock here since writing
		    the set of variables here must not be interrupted, i.e. atomic writing of the set of variables is absolutely necessary.  They system may hang
		    if the lock is not taken. *)
		PROCEDURE SetgcOngoing(value: BOOLEAN);
		VAR p: Process;
		BEGIN
			IF value THEN
				Machine.Acquire(Machine.Objects);
				IF ~gcOngoing THEN
					gcOngoing := TRUE;
					lowestAllowedPriority := GCPriority;
					gcBarrier := Machine.allProcessors
				END;
				p := running[Machine.ID()];
				Enter(p);
				p.mode := Ready;
				SwitchToNew (* this method cannot schedule the running user process with priority Low, Normal or High since
				                            lowestAllowedPriority is set to GCPriority *)
			ELSE
				Machine.Acquire(Machine.Objects);
				gcOngoing := FALSE;
				lowestAllowedPriority := Low;
				Machine.Release(Machine.Objects)
			END;
		END SetgcOngoing;

		(* caller must hold Machine.Objects lock *)
		PROCEDURE GetgcOngoing(): BOOLEAN;
		BEGIN
			RETURN gcOngoing
		END GetgcOngoing;

	END GCStatusExt;

	GCActivity = OBJECT
	BEGIN {ACTIVE, SAFE, PRIORITY(GCPriority)}
		UpdateState;
		LOOP
			Machine.Acquire(Machine.Objects);

			ASSERT(gcProcess = NIL); (* temp strong check *)
			gcProcess := running[Machine.ID()];
			gcProcess.mode := AwaitingEvent;
			SwitchToNew; (* SwitchTo called by SwitchToNew will release the lock Machine.Objects *)

			(* process is scheduled -> gcProcess = NIL set by scheduler (Timeslice), perform garbage collection now *)
			Heaps.CollectGarbage(Modules.root);
			Machine.Acquire(Machine.Objects);
			IF finalizerProcess # NIL THEN
			(* it is safe to move finalizerProcess to the ready queue and set the variable to NIL
			    since the process has been marked by the GC already - marking is finished here *)
				Enter(finalizerProcess);
				finalizerProcess := NIL
			END;
			Machine.Release(Machine.Objects);
			Heaps.gcStatus.SetgcOngoing(FALSE)
		END
	END GCActivity;

	FinalizedCollection* = OBJECT (* base type for collection, extended in Kernel.Mod *)
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;

	FinalizerCaller = OBJECT	(* separate active object that calls finalizers *)
		VAR n: Heaps.FinalizerNode;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		LOOP
			Machine.Acquire(Machine.Objects);

			ASSERT(finalizerProcess = NIL); (* temp strong check *)
			finalizerProcess := running[Machine.ID()];
			finalizerProcess.mode := AwaitingEvent;
			SwitchToNew; (* SwitchTo called by SwitchToNew will release the lock Machine.Objects *)

			(* process is scheduled -> finalizerProcess = NIL set by GCActivity, perform finalization now *)
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n IS FinalizerNode THEN
					n(FinalizerNode).c.RemoveAll(n.objStrong)	(* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer(n.objStrong)	(* may acquire locks *)
				END
			END;
		END
	END FinalizerCaller;

	Interrupter = OBJECT (ProtectedObject)	(* to do: like Timer *)
	VAR interruptNumber: LONGINT;
	END Interrupter;

VAR
	ready: ReadyProcesses;	(* ready queue represented as an object that contains the queues *)
	maxReady: LONGINT;	(* for all i : MinPriority <= maxReady < i < NumPriorities : Empty(ready.q[i]) *)
	lowestAllowedPriority: LONGINT;  (* denotes the minimal user or realtime priority greater than the idle priority that can be
	                                                            scheduled depending on the GC status, minPriority = Low if GC is not running,
	                                                            minPrioriy = GCPriority otherwise *)
	running-{UNTRACED}: ARRAY Machine.MaxCPU OF Process;	(** processes currently running, exported for Traps, not traced by the GC since it may change during collection *)
	nextProcessID: LONGINT;

	gcBarrier: SET; 			(* barrier that must be passed by all processors before actual collection starts *)
	gcActivity: GCActivity;	(* active object for GC handling *)
	gcProcess: Process;		(* suspended GC process, is NIL when collection has started, not equal NIL when no garbage collection is in process, same behaviour as for timer *)
	finalizerProcess: Process;	(* finalizer process, regarded as part of GC *)
	interrupt: ARRAY NumIRQ OF RECORD
		root: InterruptList;
		process: Process
	END;

	processingIRQ: ARRAY NumIRQ OF BOOLEAN;

	rootedProcesses: ARRAY NumPriorities OF Process; (* list of potential processes that are not traced by GC when processing the ready queues, since GC only traces processes with
	                                                                                      priorities Low ... High in ready queues. The potentially not traced processes are rooted here and traced by the GC *)

	event: Timer;	(* list of events *)

	timer (*, realtimeTimer *): Process;	(* suspended timer processes *)
	terminate: PROCEDURE;
	trap, trapReturn: ARRAY 2 OF PROCEDURE;

	ProcessorHLT*: PROCEDURE;	 (** installable procedure to halt the current processor while idle *)
	traceProcess*: TraceProcess;	(** for debugging purposes (see Info.Active) *)

	entry: ADDRESS;
	init: Process;
	i: LONGINT;

	(* Performance monitoring *)
	idlecount*: ARRAY Machine.MaxCPU OF LONGINT; (** count of idle process timeslice interrupts *)
	idleCycles- : ARRAY Machine.MaxCPU OF HUGEINT; (** CPU cycles of idle threads *)
	perfTsc: ARRAY Machine.MaxCPU OF HUGEINT;

	(* Statistics *)
	Nlock-, Nunlock-, Nawait-, NawaitNoIF-, NawaitTrue-, Ncreate-, Nterminate-,
	Ncondition-, Ncondition1True-, Ncondition2-, Ncondition2True-,
	Ntimeslice-, NtimesliceTaken-, NtimesliceNothing-, NtimesliceIdle-,
	NtimesliceKernel-, NtimesliceV86-, NtimesliceCritical-,
	Npreempt-, NpreemptTaken-, NpreemptNothing-,
	NpreemptKernel-, NpreemptV86-, NpreemptCritical-,
	Nenter- : LONGINT;

PROCEDURE GetMaxPrio(VAR queue: ProcessQueue; VAR new: Process);
VAR
	t: Heaps.ProcessLink;
	maxPriority : LONGINT;
BEGIN
	ASSERT(new = NIL);
	t := queue.head;
	maxPriority := MIN(LONGINT);
	WHILE (t # NIL) DO
		IF (t(Process).priority > maxPriority) THEN
			new := t(Process); maxPriority := t(Process).priority;
		END;
		t := t.next;
	END;
	IF new = NIL THEN	(* zero elements in queue *)
		(* skip *)
	ELSE	(* more than one element in queue *)
		IF new.next # NIL THEN new.next.prev := new.prev END;
		IF new.prev # NIL THEN new.prev.next := new.next END;
		IF queue.head = new THEN
			queue.head := new.next
		END;
		IF queue.tail = new THEN
			queue.tail := new.prev
		END;
		new.next := NIL; new.prev := NIL
	END;
END GetMaxPrio;

(* Get a process from a queue (NIL if none). Caller must hold lock for specific queue. *)
PROCEDURE Get(VAR queue: ProcessQueue; VAR new: Process);
VAR t: Heaps.ProcessLink;
BEGIN
	t := queue.head;
	IF t = NIL THEN (* zero elements in queue *)
		(* skip *)
	ELSIF t = queue.tail THEN (* one element in queue *)
		queue.head := NIL; queue.tail := NIL (* {(t.next = NIL) & (t.prev = NIL)} *)
	ELSE	(* more than one element in queue *)
		queue.head := t.next; t.next := NIL; queue.head.prev := NIL
	END;
	ASSERT((t = NIL) OR (t.next = NIL) & (t.prev = NIL)); (* temp strong check *)
	IF t = NIL THEN
		new := NIL
	ELSE
		ASSERT(t IS Process);
		new := t(Process)
	END;
END Get;

(* Put a process in a queue. Caller must hold lock for specific queue. *)
(* If t was running, be careful to protect Put and the subsequent SwitchTo with the ready lock. *)
PROCEDURE Put(VAR queue: ProcessQueue; t: Process);
BEGIN (* {t # NIL & t.next = NIL} *)
	ASSERT((t.next = NIL) & (t.prev = NIL));
	IF queue.head = NIL THEN (* queue empty *)
		queue.head := t
	ELSE (* queue not empty *)
		queue.tail.next := t; t.prev := queue.tail
	END;
	queue.tail := t
END Put;

(* Select a process of at least the specified priority to run next on current processor (returns NIL if none). Caller must hold ready lock. *)
PROCEDURE Select(VAR new: Process; priority: LONGINT);
VAR thresholdPrio: LONGINT;
BEGIN
	IF Heaps.gcStatus.GetgcOngoing() THEN
		thresholdPrio := GCPriority
	ELSE
		thresholdPrio := priority
	END;
	LOOP
		IF maxReady < thresholdPrio THEN
			IF priority < thresholdPrio THEN Get(ready.q[MinPriority], new) ELSE new := NIL END;
			EXIT
		END;
		Get(ready.q[maxReady], new);
		IF (new # NIL) OR (maxReady = MinPriority) THEN EXIT END;
		DEC(maxReady)
	END
END Select;

(* Enter a process in the ready queue. Caller must hold ready lock. *)
(* If t was running, be careful to make Enter and the subsequent SwitchTo atomic, as the process could be grabbed by another process while it is still running. *)
PROCEDURE Enter(t: Process);
BEGIN
	IF Stats THEN Machine.AtomicInc(Nenter) END;
	t.mode := Ready;
	Put(ready.q[t.priority], t);
	IF t.priority > maxReady THEN
		maxReady := t.priority (* to do: re-establish global priority invariant *)
	END
END Enter;

(* Remove a process from a queue that contains it. Caller must hold lock for specific queue. *)
(* Not intended for frequent use. *)
PROCEDURE Remove(VAR queue: ProcessQueue; t: Process);
BEGIN
	IF t.prev # NIL THEN t.prev.next := t.next END;
	IF t.next # NIL THEN t.next.prev := t.prev END;
	IF t = queue.head THEN queue.head := t.next END;
	IF t = queue.tail THEN queue.tail := t.prev END;
	ASSERT((queue.head = NIL) OR (queue.head.prev = NIL) & (queue.tail.next = NIL));
	t.prev := NIL;
	t.next := NIL
END Remove;

(* Switch to the specified process. Caller must hold ready lock. Return may be on different processor! *)
PROCEDURE SwitchTo(VAR running: Process; new: Process);	(* parameters used in SwitchToState, TerminateThis, New *)
VAR id: LONGINT;
BEGIN
	ASSERT(Machine.CS () MOD 4 = Machine.UserLevel); (* registers hold user state *)
	id := Machine.ID ();
	INC (running.cpuCycles[id], Machine.GetTimer () - perfTsc[id]);
	IF running.priority = MinPriority THEN (* Special treatment for idle threads *)
		INC (idleCycles[id], Machine.GetTimer () - perfTsc[id]);
	END;
	(* save current state *)
	running.state.PC := Machine.CurrentPC ();	(* for GC *) (* ug *)
	running.state.SP := Machine.CurrentSP ();	(* for GC *)
	running.state.BP := Machine.CurrentBP ();	(* save state *)
	IF Machine.SSESupport THEN Machine.SSESaveMin(running.sseAdr)
	ELSE Machine.FPUSaveMin(running.sse)
	END;
	running := new; new.mode := Running;
	IF Preempted IN new.flags THEN
		ASSERT(new.state.CS MOD 4 = Machine.UserLevel); (* switching to user mode *)
		EXCL(new.flags, Preempted);
		perfTsc[id] := Machine.GetTimer ();
		Machine.SetSP (new.state.SP); (* for UpdateState - run on new stack (EBP on old) *)
		Machine.PushState(new.state);
		IF Machine.SSESupport THEN Machine.SSERestoreFull(new.sseAdr)
		ELSE Machine.FPURestoreFull(new.sse)
		END;
		Machine.Release(Machine.Objects);
		Machine.JumpState (* pops the state parameter from the stack and returns from interrupt *)
	ELSE
		IF Machine.SSESupport THEN Machine.SSERestoreMin(new.sseAdr)
		ELSE Machine.FPURestoreMin(new.sse)
		END;
		perfTsc[id] := Machine.GetTimer ();
		Machine.SetSP (new.state.SP); (* run on new stack *)
		Machine.SetBP (new.state.BP);
		Machine.Release(Machine.Objects);
	END;
(*
	MOV ESP, EBP	; exit code generated by compiler
	POP EBP
	RET 8
*)
END SwitchTo;

(* Select a new process to run and switch to it. Caller must hold ready lock. *)
PROCEDURE SwitchToNew;
VAR new: Process;
BEGIN
	Select(new, MinPriority); (* will return at least an Idle process *)
	new.procID := Machine.ID ();
	SwitchTo(running[new.procID], new)
END SwitchToNew;

(** Relinquish control. *)
PROCEDURE Yield*;
VAR r, new: Process;
BEGIN
	IF ~YieldTrick OR (maxReady >= lowestAllowedPriority) THEN
		r := SYSTEM.VAL (Process, Machine.GetProcessPtr ());
		Machine.Acquire(Machine.Objects);
		Select(new, r.priority);
		IF new # NIL THEN (* found another process *)
			Enter(r);
			new.procID := Machine.ID ();
			SwitchTo(running[new.procID], new)
		ELSE (* stay with same process *)
			Machine.Release(Machine.Objects)
		END
	END
END Yield;

PROCEDURE SwitchToState(new: Process; VAR state: Machine.State);
BEGIN
	(* simulate return from SwitchTo - MOV ESP, EBP; POP EBP; RET 8 *)
	state.SP := new.state.BP+AddressSize*2;	(* AddressSize*2 is effect of POP, RET *)
	SYSTEM.GET (new.state.BP, state.BP);	(* effect of POP *)
	SYSTEM.GET (new.state.BP + AddressSize, state.PC);	(* effect of RET *)
END SwitchToState;

(** Preempt the current process. *)
PROCEDURE Timeslice*(VAR state: Machine.State);
VAR id: LONGINT; new: Process;
BEGIN
	(* handle a timer tick *)
	Machine.Acquire(Machine.Objects);
	IF Stats THEN Machine.AtomicInc(Ntimeslice) END;
	id := Machine.ID ();
	IF id = 0 THEN (* process 0 checks event queues *)
		IF event.next.trigger - Machine.ticks <= 0 THEN (* next normal event due *)
			IF event.next # event THEN (* not dummy event *)
				IF timer # NIL THEN
					ASSERT(timer.mode = AwaitingEvent);
					Enter(timer); timer := NIL
				END
			ELSE (* reset dummy event *)
				event.trigger := Machine.ticks + MAX(LONGINT) DIV 2	(* ignore overflow *)
			END
		END
	END;
	IF Heaps.gcStatus.GetgcOngoing() & (id IN gcBarrier) THEN
		EXCL(gcBarrier, id);
		IF gcBarrier = {} THEN
			ASSERT(gcProcess.mode = AwaitingEvent);
			Enter(gcProcess); gcProcess := NIL
		END
	END;
	(* pre-empt the current process *)
	IF Machine.PreemptCount(id) = 1 THEN (* check against 1, because we are holding one lock *)
		IF ~(Machine.VMBit IN state.FLAGS) THEN (* not V86 mode *)
			IF state.CS MOD 4 = Machine.UserLevel THEN (* not kernel mode (used during initialization or interrupts) *)
				IF running[id].priority # MinPriority THEN	(* idle processes are not timesliced *)
					Select(new, running[id].priority);
					IF new # NIL THEN
						ASSERT(Machine.CS () MOD 4 = Machine.KernelLevel); (* otherwise we can not change state.SP *)
						INC (running[id].cpuCycles[id], Machine.GetTimer () - perfTsc[id]);
						IF Stats THEN Machine.AtomicInc(NtimesliceTaken) END;
						INCL(running[id].flags, Preempted);
						Machine.CopyState(state, running[id].state);
						IF Machine.SSESupport THEN Machine.SSESaveFull(running[id].sseAdr)
						ELSE Machine.FPUSaveFull(running[id].sse); (* to do: floating-point exception possible / Machine.SetupFPU *)
						END;
						Enter(running[id]);
						running[id] := new;
						new.mode := Running; new.procID := id;
						IF Preempted IN new.flags THEN
							EXCL(new.flags, Preempted);
							Machine.CopyState(new.state, state);
							IF Machine.SSESupport THEN Machine.SSERestoreFull(new.sseAdr)
							ELSE Machine.FPURestoreFull(new.sse)
							END
						ELSE
							SwitchToState(new, state);
							IF Machine.SSESupport THEN Machine.SSERestoreMin(new.sseAdr)
							ELSE Machine.FPURestoreMin(new.sse)
							END
						END;

						perfTsc[id] := Machine.GetTimer ()
					ELSE
						IF Stats THEN Machine.AtomicInc(NtimesliceNothing) END;
					END;

					(* Check if the process has the PleasHalt flag and handle it. *)
					IF PleaseHalt IN running[id].flags THEN
						(* Simulate procedure call: Increase stack & put return PC *)
						DEC(state.SP, AddressSize);
						SYSTEM.PUT (state.SP, state.PC); (* Here an stack overflow could happen! *)

						(* Set the right halt procedure *)
						IF (Unbreakable IN running[id].flags) THEN
							state.PC := SYSTEM.VAL (ADDRESS, trap[1]);
						ELSE
							state.PC := SYSTEM.VAL (ADDRESS, trap[0]);
						END;
					END;

				ELSE
					INC(idlecount[id]);
					IF Stats THEN Machine.AtomicInc(NtimesliceIdle) END;
				END
			ELSE
				(* can not interrupt kernel mode, because SwitchTo would not switch back to it *)
				IF Stats THEN Machine.AtomicInc(NtimesliceKernel) END	(* kernel mode, e.g. during page fault or FieldIRQ *)
			END
		ELSE
			IF Stats THEN Machine.AtomicInc(NtimesliceV86) END (* V86 mode *)
		END
	ELSE
		IF Stats THEN Machine.AtomicInc(NtimesliceCritical) END (* not preemptable *)
	END;
	Machine.Release(Machine.Objects)
END Timeslice;

(** Return current process. (DEPRECATED, use ActiveObject) *)
PROCEDURE CurrentProcess*( ): Process;
BEGIN
	RETURN SYSTEM.VAL(Process, Machine.GetProcessPtr());
END CurrentProcess;

(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
PROCEDURE GetStackBottom*(p: Process): ADDRESS;
BEGIN
	RETURN p.stack.high
END GetStackBottom;

(** Return the active object currently executing. *)
PROCEDURE ActiveObject* (): ANY;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL(Process, Machine.GetProcessPtr ());
	RETURN r.obj
END ActiveObject;

(** Return the ID of the active currently executing process. *)
PROCEDURE GetProcessID* (): LONGINT;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL (Process, Machine.GetProcessPtr ());
	RETURN r.id
END GetProcessID;

(** Set the current process' priority. *)
PROCEDURE SetPriority*(priority: LONGINT);
VAR id: LONGINT;
BEGIN
	ASSERT((priority >= Low) & (priority <= Realtime)); (* priority in bounds *)
	IF HandlePriorityInv THEN
		Machine.Acquire(Machine.Objects);
		id := Machine.ID();
		running[id].SetPriority(priority);
		Machine.Release(Machine.Objects)
	ELSE
		id := Machine.AcquirePreemption ();
		running[id].priority := priority;
		Machine.ReleasePreemption
		(* to do: re-establish global priority invariant *)
	END
END SetPriority;

(** Return TRUE iff the specified protected object is locked exclusive to the current process. *)
PROCEDURE LockedByCurrent*(obj: ANY): BOOLEAN;
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; id: LONGINT; res: BOOLEAN;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	ASSERT(hdr IS Heaps.ProtRecBlock);
	IF HandlePriorityInv THEN
		Machine.Acquire(Machine.Objects);
		id := Machine.ID();
		res := (hdr.lockedBy = running[id]);
		Machine.Release(Machine.Objects)
	ELSE
		id := Machine.AcquirePreemption ();
		Machine.AcquireObject(hdr.locked);
		res := (hdr.lockedBy = running[id]);
		Machine.ReleaseObject(hdr.locked);
		Machine.ReleasePreemption;
	END;
	RETURN res
END LockedByCurrent;

(** Return number of ready and running processes, excluding idle processes. *)
PROCEDURE NumReady* (): LONGINT;
VAR i, n: LONGINT; p: Heaps.ProcessLink;
BEGIN
	n := 0;
	Machine.Acquire(Machine.Objects);
	FOR i := MinPriority+1 TO NumPriorities-1 DO
		p := ready.q[i].head; WHILE p # NIL DO INC(n); p := p.next END
	END;
	FOR i := 0 TO Machine.MaxCPU-1 DO
		IF (running[i] # NIL) & (running[i].priority > MinPriority) THEN INC(n) END
	END;
	Machine.Release(Machine.Objects);
	RETURN n
END NumReady;

(** Return number of CPU cycles consumed by the specified process for each processor. If all is TRUE,
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
VAR result: HUGEINT; process: Process;
BEGIN
	process := CurrentProcess();
	FOR i := 0 TO Machine.MaxCPU-1 DO result := result + process.cpuCycles[i]; END;
	RETURN result;
END CurrentProcessTime;

PROCEDURE TimerFrequency*(): HUGEINT;
BEGIN
	RETURN 1000000000;
END TimerFrequency;

(* Handle hardware interrupt and route it to an interrupt handler process. *)
PROCEDURE FieldIRQ(VAR state: Machine.State);
VAR t: Process; id: LONGINT; new: Process; preempt: BOOLEAN;
BEGIN
	Machine.DisableIRQ(state.INT);	(* do this before acknowledging irq *)

	IF StrongChecks THEN
		IF processingIRQ[state.INT-MinIRQ] THEN
			Trace.String("IRQ recursion "); Trace.Int(state.INT,1); Trace.Ln;
			RETURN
		ELSE
			processingIRQ[state.INT-MinIRQ] := TRUE;
		END;
	END;
	
	(* if the reenabling of interrupts cannot be circumvented, then it is REQUIRED to acknowledge interrupts
		BEFORE reenabling. Otherwise spurious IRQs cannot be identified as such.
		Please note that this particular problem with spurious IRQs cannot observed on many machines but IF it is observed
		then the machine will behave unexpected. Very hard to debug and trace!

		Machine.Ack(state.INT); 
		Machine.Sti ();	(* avoid Processors.StopAll deadlock when waiting for locks below (remove this) *)
	*)
	
	Machine.Acquire(Machine.Objects);
	t := interrupt[state.INT-MinIRQ].process;
	IF StrongChecks THEN ASSERT(t.mode = AwaitingEvent) END;
	id := Machine.ID ();
	preempt := (t.priority > maxReady) & (maxReady # MinPriority) & (t.priority > running[id].priority);
	Enter(t);
	IF preempt THEN
		IF Stats THEN Machine.AtomicInc(Npreempt) END;
		(* pre-empt the current process *)
		IF Machine.PreemptCount(id) = 1 THEN (* check against 1, because we are holding one lock *)
			IF ~(Machine.VMBit IN state.FLAGS) THEN (* not V86 mode *)
				IF state.CS MOD 4 = Machine.UserLevel THEN (* not kernel mode (used during initialization or interrupts) *)
					Select(new, running[id].priority + 1);
					IF new # NIL THEN
						ASSERT(Machine.CS () MOD 4 = Machine.KernelLevel); (* otherwise we can not change state.SP *)
						INC (running[id].cpuCycles[id], Machine.GetTimer () - perfTsc[id]);
						IF running[id].priority = MinPriority THEN (* Special treatment for idle threads *)
							INC (idleCycles[id], Machine.GetTimer () - perfTsc[id]);
						END;
						IF Stats THEN Machine.AtomicInc(NpreemptTaken) END;
						INCL(running[id].flags, Preempted);
						Machine.CopyState(state, running[id].state);
						IF Machine.SSESupport THEN Machine.SSESaveFull(running[id].sseAdr)
						ELSE Machine.FPUSaveFull(running[id].sse); (* to do: floating-point exception possible / Machine.SetupFPU *)
						END;
						Enter(running[id]);
						running[id] := new;
						new.mode := Running; new.procID := id;
						IF Preempted IN new.flags THEN
							EXCL(new.flags, Preempted);
							Machine.CopyState(new.state, state);
							IF Machine.SSESupport THEN Machine.SSERestoreFull(new.sseAdr)
							ELSE Machine.FPURestoreFull(new.sse)
							END
						ELSE
							SwitchToState(new, state);
							IF Machine.SSESupport THEN Machine.SSERestoreMin(new.sseAdr)
							ELSE Machine.FPURestoreMin(new.sse)
							END
						END;
						perfTsc[id] := Machine.GetTimer ()
					ELSE
						IF Stats THEN Machine.AtomicInc(NpreemptNothing) END
					END
				ELSE
					(* can not interrupt kernel mode, because SwitchTo would not switch back to it *)
					IF Stats THEN Machine.AtomicInc(NpreemptKernel) END	(* kernel mode, e.g. during page fault or FieldIRQ *)
				END
			ELSE
				IF Stats THEN Machine.AtomicInc(NpreemptV86) END (* V86 mode *)
			END
		ELSE
			IF Stats THEN Machine.AtomicInc(NpreemptCritical) END (* not preemptable *)
		END
	END;
	Machine.Release(Machine.Objects)
END FieldIRQ;

(* Process scheduled to handle an interrupt. *)
PROCEDURE InterruptProcess(self: ProtectedObject);
VAR h: InterruptList; t: Process; int: LONGINT;
BEGIN
	int := self(Interrupter).interruptNumber;
	t := interrupt[int-MinIRQ].process;
	LOOP
		h := interrupt[int-MinIRQ].root;	(* concurrent updates allowed in InstallHandler and RemoveHandler *)
		WHILE h # NIL DO h.handler (); h := h.next END;
		Machine.Acquire(Machine.Objects);
		ASSERT(running[Machine.ID ()] = t); (* strong check *)
		t.mode := AwaitingEvent;
		processingIRQ[int-MinIRQ] := FALSE;
		Machine.EnableIRQ(int);
		SwitchToNew
	END
END InterruptProcess;

(** Install interrupt handler. *)
PROCEDURE InstallHandler*(h: EventHandler; int: LONGINT);
VAR t: Process; new: BOOLEAN; ih: Interrupter; n: InterruptList; i: LONGINT;
BEGIN
	ASSERT((int >= MinIRQ) & (int-MinIRQ < NumIRQ));	(* range check *)
	IF interrupt[int-MinIRQ].process = NIL THEN	(* first handler for this irq *)
		(* allocate process outside lock region, to avoid GC lock problems. *)
		(* hack: use type parameter to pass int index & set obj to h, for System.ShowProcesses *)
		NEW(ih); ih.interruptNumber := int;
		NewProcess(InterruptProcess, {Resistant}, ih, t);
		t.priority := High;  (* second-level interrupt handling processes have high priority, handlers may allocate memory, use exclusive locks and awaits *)
		t.staticPriority := t.priority;
		FOR i := 0 TO LEN(t.prioRequests) - 1 DO t.prioRequests[i] := 0 END;
		INC(t.prioRequests[t.priority])
	END;
	NEW(n); n.handler := h;
	Machine.Acquire(Machine.Objects);
	IF interrupt[int-MinIRQ].process = NIL THEN	(* still first handler for this irq *)
		t.id := nextProcessID; INC(nextProcessID);
		t.mode := AwaitingEvent;
		interrupt[int-MinIRQ].process := t;
		new := TRUE
	ELSE
		new := FALSE
	END;
	n.next := interrupt[int-MinIRQ].root; (* can be concurrent with loop in InterruptProcess *)
	interrupt[int-MinIRQ].root := n;
	Machine.Release(Machine.Objects);
	IF new THEN Machine.InstallHandler(FieldIRQ, int) END (* do outside lock region to avoid NEW/GC deadlock *)
END InstallHandler;

(** Remove interrupt handler. *)
PROCEDURE RemoveHandler*(h: EventHandler; int: LONGINT);
VAR p, c: InterruptList;
BEGIN
	ASSERT((int >= MinIRQ) & (int-MinIRQ < NumIRQ)); (* range check *)
	Machine.Acquire(Machine.Objects);
	p := NIL; c := interrupt[int-MinIRQ].root;
	WHILE (c.handler # h) & (c # NIL) DO p := c; c := c.next END;
	IF c.handler = h THEN (* handler found *)
		IF p = NIL THEN
			interrupt[int-MinIRQ].root := c.next;
	(*
			IF c.inext = NIL THEN (* this was the last handler *)
				Machine.RemoveHandler(FieldIRQ, int)
				(* to do: synchronize with FieldIRQ and InterruptProcess *)
			END
	*)
		ELSE
			p.next := c.next
		END
	ELSE
		HALT(99); (* handler not found *)
	END;
	(* can not clear c.next field, because InterruptProcess may be traversing it. *)
	Machine.Release(Machine.Objects)
END RemoveHandler;

(* local procedure *)
PROCEDURE SetTimeoutAbsOrRel(t: Timer; h: EventHandler; ms: LONGINT; isAbsolute: BOOLEAN);
VAR e: Timer; trigger: LONGINT;
BEGIN
	ASSERT(Machine.Second= 1000);	(* assume milliseconds for now *)
	ASSERT((t # NIL) & (h # NIL));
	IF ms < 1 THEN ms := 1 END;
	Machine.Acquire(Machine.Objects);
	IF isAbsolute THEN trigger := ms ELSE trigger := Machine.ticks + ms (* ignore overflow *) END;
	IF t.next # NIL THEN (* cancel previous timeout *)
		t.next.prev := t.prev; t.prev.next := t.next
	END;
	t.trigger := trigger; t.handler := h;
	e := event.next;	(* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev; e.prev := t; t.next := e; t.prev.next := t;
	Machine.Release(Machine.Objects)
END SetTimeoutAbsOrRel;

(** Set (or reset) an event handler object's timeout value. *)
PROCEDURE SetTimeout*(t: Timer; h: EventHandler; ms: LONGINT);
BEGIN
	SetTimeoutAbsOrRel(t, h, ms, FALSE)
END SetTimeout;

(** Set (or reset) an event handler object's timeout value. Here ms is absolute *)
PROCEDURE SetTimeoutAt*(t: Timer; h: EventHandler; ms: LONGINT);
BEGIN
	SetTimeoutAbsOrRel(t, h, ms, TRUE)
END SetTimeoutAt;

(** Cancel an event handler object's timeout, if any. It is possible that the timer has expired, but not yet been scheduled to run. *)
PROCEDURE CancelTimeout*(t: Timer);
BEGIN
	Machine.Acquire(Machine.Objects);
	ASSERT(t # event);
	IF t.next # NIL THEN
		t.next.prev := t.prev; t.prev.next := t.next;
		t.next := NIL; t.prev := NIL
	END;
	Machine.Release(Machine.Objects)
END CancelTimeout;

(** Terminate the current process and switch to next process. *)
PROCEDURE Terminate*; (* exported for Linker *)
VAR id: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Nterminate) END;
	Machine.Acquire(Machine.Objects);
	id := Machine.ID ();
	(*running[id].state.PC := CallerPC ();*) (* for tracing *)
	running[id].mode := Terminated;	(* a process can also be "terminated" if the queue containing it is garbage collected *)
	SwitchToNew;
	HALT(2201)	(* process resurrected *)
END Terminate;

PROCEDURE Halt;
BEGIN
	HALT(halt); (* process halted *)
END Halt;

PROCEDURE HaltUnbreakable;
BEGIN
	HALT(haltUnbreakable); (* process halted *)
END HaltUnbreakable;

(* Set the return PC which is saved in the process and set it to -1 *)
PROCEDURE HaltAltPC(haltCode: LONGINT);
VAR bp: ADDRESS; p: Process;
BEGIN
	p := running[Machine.ID ()];
	ASSERT(p.oldReturnPC # -1);
	bp := Machine.CurrentBP ();
	SYSTEM.PUT (bp + AddressSize, p.oldReturnPC);
	CASE haltCode OF
		|halt: HALT(halt);
		|haltUnbreakable: HALT(haltUnbreakable);
	END;
END HaltAltPC;

PROCEDURE HaltReturn;
VAR bp: ADDRESS;
BEGIN
	bp := Machine.CurrentBP ();
	SYSTEM.GET (bp, bp); (* Get the dynamic link *)
	Machine.SetBP (bp); (* Undo the actual paf *)
	HaltAltPC(halt);
END HaltReturn;

PROCEDURE HaltUnbreakableReturn;
VAR bp: ADDRESS;
BEGIN
	bp := Machine.CurrentBP ();
	SYSTEM.GET (bp, bp); (* Get the dynamic link *)
	Machine.SetBP (bp); (* Undo the actual paf *)
	HaltAltPC(haltUnbreakable);
END HaltUnbreakableReturn;

PROCEDURE TerminateThis*(t: Process; unbreakable: BOOLEAN);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; pc, fp : ADDRESS;

	(* terminates a process that is either in mode AwaitingLock or AwaitingCond *)
	PROCEDURE TerminateAwaiting(t: Process);
	VAR hdr {UNTRACED}: Heaps.ProtRecBlock;
	BEGIN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
		ASSERT(hdr IS Heaps.ProtRecBlock);
		IF t.mode = AwaitingLock THEN
			fp := t.state.BP; 		(* SwitchTo PAF *)
			SYSTEM.GET (fp, fp);		(* SwitchToNew PAF *)
			SYSTEM.GET (fp, fp);		(* Lock PAF*)
			SYSTEM.GET (fp + AddressSize, pc);	(* Get the return address*)
			IF ~Modules.IsExceptionHandled(pc, fp, FALSE) THEN
				Remove(hdr.awaitingLock, t);
				t.waitingOn := NIL; SYSTEM.GET (t.state.BP + AddressSize, t.oldReturnPC);
				IF unbreakable THEN
					SYSTEM.PUT (t.state.BP + AddressSize, SYSTEM.VAL (ADDRESS, trapReturn[1]))
				ELSE
					SYSTEM.PUT (t.state.BP + AddressSize, SYSTEM.VAL (ADDRESS, trapReturn[0]))
				END;
				Enter(t)
			ELSE
				Machine.Acquire (Machine.TraceOutput);
				Trace.String(" Not allowed to kill "); Trace.Int(t.id, 1); Trace.Char(" "); Trace.Int(t.mode, 1); Trace.Ln;
				Machine.Release (Machine.TraceOutput);
			END
		ELSIF t.mode = AwaitingCond THEN
			SYSTEM.GET (t.state.BP, fp);
			SYSTEM.GET (t.state.PC, pc);
			IF ~Modules.IsExceptionHandled(pc, fp, TRUE) THEN
				Remove(hdr.awaitingCond, t);
				t.waitingOn := NIL; SYSTEM.GET (t.state.BP + AddressSize, t.oldReturnPC);
				IF unbreakable THEN
					SYSTEM.PUT (t.state.BP + AddressSize, SYSTEM.VAL (ADDRESS, trapReturn[1]))
				ELSE
					SYSTEM.PUT (t.state.BP + AddressSize, SYSTEM.VAL (ADDRESS, trapReturn[0]))
				END;
				Enter(t)
			ELSE
				Machine.Acquire (Machine.TraceOutput);
				Trace.String(" Not allowed to kill "); Trace.Int(t.id, 1); Trace.Char(" "); Trace.Int(t.mode, 1); Trace.Ln;
				Machine.Release (Machine.TraceOutput);
			END
		END
	END TerminateAwaiting;

BEGIN
	IF PleaseHalt IN t.flags THEN
		IF TraceVerbose THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String("Process (ID="); Trace.Int(t.id, 0); Trace.StringLn (") is already halting!");
			Machine.Release (Machine.TraceOutput);
		END;
		RETURN
	ELSE
		Machine.Acquire(Machine.Objects);
		IF (t = running[Machine.ID ()]) THEN INCL(t.flags, SelfTermination); END;
		IF TraceVerbose THEN
			Machine.Acquire (Machine.TraceOutput);
			Trace.String(" Kill "); Trace.Int(t.id, 1); Trace.Char(" "); Trace.Int(t.mode, 1); Trace.Ln;
			Machine.Release (Machine.TraceOutput);
		END;
		CASE t.mode OF
			|Running:
				INCL(t.flags, PleaseHalt);
				IF unbreakable THEN INCL(t.flags, Unbreakable) END
			|Ready:
				DEC(t.state.SP, AddressSize);	SYSTEM.PUT (t.state.SP, t.state.PC);
				IF unbreakable THEN t.state.PC := SYSTEM.VAL (ADDRESS, trap[1])
				ELSE t.state.PC := SYSTEM.VAL (ADDRESS, trap[0]) END
			|AwaitingLock, AwaitingCond:
				IF HandlePriorityInv THEN
					TerminateAwaiting(t)
				ELSE
					SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
					ASSERT(hdr IS Heaps.ProtRecBlock);
					IF ~hdr.locked THEN
						Machine.AcquireObject(hdr.locked);
						TerminateAwaiting(t);
						Machine.ReleaseObject(hdr.locked)
					END
				END
			| AwaitingEvent, Unknown, Terminated:	(* skip *)
		END;
		Machine.Release(Machine.Objects)
	END
END TerminateThis;

(* Finalize a process. *)
PROCEDURE FinalizeProcess(t: ANY);
BEGIN
	Machine.DisposeStack(t(Process).stack)
END FinalizeProcess;

(* Allocate a new process associated with "obj". Must be outside lock region, because of potential GC. *)
PROCEDURE NewProcess(body: Body; flags: SET; obj: ProtectedObject; VAR new: Process);
VAR t: Process; sp: ADDRESS; id: LONGINT; fn: Heaps.FinalizerNode;
BEGIN
	NEW(t); NEW(fn); (* implicit call Heaps.NewRec *)
	t.next := NIL; t.prev := NIL; t.rootedNext := NIL;
	t.waitingOn := NIL; t.flags := flags;
	t.obj := obj; t.mode := Unknown;
	(* initialize the stack *)
	Machine.NewStack(t.stack, t, sp);
	IF VeryConservative THEN
		Machine.Fill32(t.stack.adr, sp-t.stack.adr, 0D0D0DEADH)
	END;
	SYSTEM.PUT (sp-1*AddressSize, obj); (* self parameter for body *)
	SYSTEM.PUT (sp-2*AddressSize, terminate); (* return address for body *)
	(* the following will be popped by SwitchTo exit code or Machine.JumpToUserLevel *)
	SYSTEM.PUT (sp-3*AddressSize, body); (* return address for SwitchTo (body entry point) *)
	SYSTEM.PUT (sp-4*AddressSize, NIL);	(* end of dynamic link list (FP value at entry to body) *)
	t.sseAdr := ADDRESSOF(t.sse) + ((-ADDRESSOF(t.sse)) MOD 16);
	IF Machine.SSESupport THEN Machine.SSESaveMin(t.sseAdr)
	ELSE Machine.FPUSaveMin(t.sse)	(* inherit FPU state of caller *)
	END;
	t.state.BP := sp-4*AddressSize;
	t.state.SP := t.state.BP;
	t.state.PC := 0; (* indicating that process is not running yet *)
	(* set up exception handling *)
	IF Restart IN flags THEN	(* restart object body *)
		t.restartPC := SYSTEM.VAL (ADDRESS, body);
		t.restartSP := sp-2*AddressSize	(* 1 parameter and return address of body *)
	ELSE (* terminate process *)
		t.restartPC := SYSTEM.VAL (ADDRESS, terminate);
		t.restartSP := sp
	END;
	fn.finalizer := FinalizeProcess;
	Heaps.AddFinalizer(t, fn);
	(* return *)
	FOR id := 0 TO Machine.MaxCPU-1 DO t.cpuCycles[id] := 0 END;
	new := t
END NewProcess;

(* Create the process associated with an active object (kernel call). *)
PROCEDURE CreateProcess*(body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject);
VAR t: Process; type: ADDRESS; heapBlock {UNTRACED}: Heaps.HeapBlock; i: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Ncreate) END;

	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, heapBlock);
	ASSERT(heapBlock IS Heaps.ProtRecBlock); (* protected object *)

	SYSTEM.GET (SYSTEM.VAL (ADDRESS, obj) + Heaps.TypeDescOffset, type); (* type tag *)
	IF Restart IN flags THEN INCL(flags, Resistant) END; (* SAFE => Restart & Resistant *)
	NewProcess(body, flags, obj, t);
	Machine.Acquire(Machine.Objects);
	t.id := nextProcessID; INC(nextProcessID);
	IF priority = 0 THEN	(* no priority specified *)
		t.priority := running[Machine.ID ()].priority (* inherit priority of creator *)
	ELSIF priority > 0 THEN (* positive priority specified *)
		t.priority := priority
	ELSE (* negative priority specified (only for Idle process) *)
		t.priority := MinPriority
	END;
	t.staticPriority := t.priority;
	FOR i := 0 TO LEN(t.prioRequests) - 1 DO t.prioRequests[i] := 0 END;
	INC(t.prioRequests[t.priority]);
	CASE t.priority OF
		MinPriority			: t.rootedNext := rootedProcesses[t.priority]; rootedProcesses[t.priority] := t
	|	Low, Normal, High	: (* do nothing, processes with this priority are traced by GC automatically *)
	|	GCPriority, Realtime	: t.rootedNext := rootedProcesses[t.priority]; rootedProcesses[t.priority] := t
	END;
	Enter(t);
	Machine.Release(Machine.Objects)
END CreateProcess;

(* Lock a protected object (kernel call) *)
(* There are two different procedures for locking a protected object in case of priority inversion handling enabled or disabled due to the different
    locking strategy. *)
PROCEDURE Lock*(obj: ProtectedObject; exclusive: BOOLEAN);
BEGIN
	IF HandlePriorityInv THEN
		LockPriorityInv(obj, exclusive)
	ELSE
		LockNoPriorityInv(obj, exclusive)
	END
END Lock;

(* Lock a protected object if priority inversion handling is disabled. Header locks, preemption and Machine.Objects locks are used. *)
PROCEDURE LockNoPriorityInv(obj: ProtectedObject; exclusive: BOOLEAN);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r: Process; id: LONGINT;
BEGIN (* {called from user level} *)
	IF Stats THEN Machine.AtomicInc(Nlock) END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock); (* protected object *)
		ASSERT(exclusive)	(* shared not implemented yet *)
	END;
	id := Machine.AcquirePreemption ();
	Machine.AcquireObject(hdr.locked);
	IF hdr.count = 0 THEN (* not locked *)
		hdr.count := -1; hdr.lockedBy := SYSTEM.VAL (Process, Machine.GetProcessPtr ()); (* set exclusive lock *)
		Machine.ReleaseObject(hdr.locked);
		Machine.ReleasePreemption;
	ELSE  (* locked *)
		r := SYSTEM.VAL (Process, Machine.GetProcessPtr ());
		IF hdr.lockedBy = r THEN
			Machine.ReleaseObject(hdr.locked);
			Machine.ReleasePreemption;
			ASSERT(hdr.lockedBy # r, 2203);	(* nested locks not allowed *)
		END;
		ASSERT(r.waitingOn = NIL);
		r.waitingOn := obj; r.mode := AwaitingLock;
		Machine.Acquire(Machine.Objects);
		Put(hdr.awaitingLock, r);
		Machine.ReleaseObject(hdr.locked);
		Machine.ReleasePreemption;
		SwitchToNew
	END
END LockNoPriorityInv;

(*
(* propagation of priorities - lock Machine.Objects is taken.
    This is a procedure that calls itself recursively if a higher priority is propagated along a chain of resources and processes where each resource
    is locked by a process that itself waits on a resource. The procedure can be rewritten into a non-recursive procedure if needed..
    Remark: parameters of type Heaps.HeapBlock or extensions of it are not passed as parameters for clarity and safety reasons .
    Instead, a ProtectedObject pointer is passed as the first parameter.   *)
PROCEDURE PropagatePrio(obj: ProtectedObject; prevMaxWaitingPrio, waitingPrio: LONGINT);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; p: Process;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF hdr.lockedBy # NIL THEN
		p := hdr.lockedBy(Process);
		DEC(p.prioRequests[prevMaxWaitingPrio]);
		INC(p.prioRequests[waitingPrio]);
		IF (p.waitingOn # NIL) & (waitingPrio > p.priority) THEN
			obj := p.waitingOn;
			SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
			prevMaxWaitingPrio := MaxPrio(hdr.waitingPriorities);
			DEC(hdr.waitingPriorities[p.priority]);
			INC(hdr.waitingPriorities[waitingPrio]);
			IF waitingPrio > prevMaxWaitingPrio THEN PropagatePrio(obj, prevMaxWaitingPrio, waitingPrio) END
		END;
		IF waitingPrio > p.priority THEN
			IF p.mode = Ready THEN Remove(ready.q[p.priority], p) END; (* remove p from the lower priority queue ... *)
			p.priority := waitingPrio;
			IF p.mode = Ready THEN Enter(p) END;  (* ... and add it to the higher priority queue *)
		END
	END;
END PropagatePrio;
*)

(* propagation of priorities - lock Machine.Objects is taken.
    This procedure is the iterative version of the above commented out recursive procedure.
    Remark: hdr is an actually UNTRACED parameter. The GC, however, can handle this, see procedure Heaps.Mark, there is a check whether the
    pointer to the header part is valid. In case of hdr, the pointer ot the header part is NIL. *)
PROCEDURE PropagatePrio(hdr: Heaps.ProtRecBlock; prevMaxWaitingPrio, waitingPrio: LONGINT);
VAR propagateFurther: BOOLEAN; p: Process; obj: ProtectedObject;
BEGIN
	propagateFurther := TRUE;
	WHILE propagateFurther & (waitingPrio > prevMaxWaitingPrio) DO
		IF hdr.lockedBy # NIL THEN
			p := hdr.lockedBy(Process);
			DEC(p.prioRequests[prevMaxWaitingPrio]);
			INC(p.prioRequests[waitingPrio]);
			IF (p.waitingOn # NIL) & (waitingPrio > p.priority) THEN
				obj := p.waitingOn;
				SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
				prevMaxWaitingPrio := MaxPrio(hdr.waitingPriorities);
				DEC(hdr.waitingPriorities[p.priority]);
				INC(hdr.waitingPriorities[waitingPrio]);
			ELSE (* p is not waiting for a resource or waitingPrio is less or equal to p's priority - priority propagation finishes *)
				propagateFurther := FALSE
			END;
			IF waitingPrio > p.priority THEN (* independently of whether p is waiting on a resource or not the priority of p is changed if it is lower than waitingPrio *)
				IF p.mode = Ready THEN Remove(ready.q[p.priority], p) END; (* remove p from the lower priority queue ... *)
				p.priority := waitingPrio;
				IF p.mode = Ready THEN Enter(p) END;  (* ... and add it to the higher priority queue *)
			END
		ELSE (* current resource is not locked - priority propagation finishes *)
			propagateFurther := FALSE
		END
	END
END PropagatePrio;

(* TO DO: adapt priority inversion algorithm such that priority of a process is not raised higher than High, it must not become Realtime, otherwise
    GC may be corrupted *)
(* Lock a protected object if priority inversion handling is enabled. Machine.Objects lock is used. *)
PROCEDURE LockPriorityInv(obj: ProtectedObject; exclusive: BOOLEAN);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r: Process;
	maxWaitingPrio, prevMaxWaitingPrio: LONGINT;
BEGIN (* {called from user level} *)
	IF Stats THEN Machine.AtomicInc(Nlock) END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock); (* protected object *)
		ASSERT(exclusive)	(* shared not implemented yet *)
	END;
	Machine.Acquire(Machine.Objects);
	r := SYSTEM.VAL(Process, Machine.GetProcessPtr());
	IF hdr.count = 0 THEN (* not locked *)
		hdr.count := -1; hdr.lockedBy := r; (* set exclusive lock *)
		maxWaitingPrio := MaxPrio(hdr.waitingPriorities);
		INC(r.prioRequests[maxWaitingPrio]);
		r.priority := MaxPrio(r.prioRequests);
		Machine.Release(Machine.Objects);
	ELSE	(* locked (to do: on multiprocessors, perhaps spin here for a while, if lockedBy.mode = running) *)
		IF hdr.lockedBy = r THEN
			Machine.Release(Machine.Objects);
			ASSERT(hdr.lockedBy # r, 2203);	(* nested locks not allowed *)
		END;
		IF r.waitingOn # NIL THEN
			Machine.Acquire(Machine.TraceOutput);
			Trace.String("Objects: LockPriorityInv - hdr.count # NIL, but r.waitingOn # NIL");
			Machine.Release(Machine.TraceOutput)
		END;
		ASSERT(r.waitingOn = NIL);
		r.waitingOn := obj; r.mode := AwaitingLock;
		prevMaxWaitingPrio := MaxPrio(hdr.waitingPriorities);
		INC(hdr.waitingPriorities[r.priority]);
		IF r.priority > prevMaxWaitingPrio THEN PropagatePrio(hdr, prevMaxWaitingPrio, r.priority) END;
		Put(hdr.awaitingLock, r);
		SwitchToNew
	END
END LockPriorityInv;

(* Find the first true condition from the queue and remove it. Assume the object is currently locked. *)
PROCEDURE FindCondition(VAR q: ProcessQueue): Process;
VAR first, cand: Process;
BEGIN
	IF Stats THEN Machine.AtomicInc(Ncondition) END;
	Get(q, first);
	IF first.condition(first.condFP) THEN
		IF Stats THEN Machine.AtomicInc(Ncondition1True) END;
		RETURN first
	END;
	Put(q, first);
	WHILE q.head # first DO
		IF Stats THEN Machine.AtomicInc(Ncondition2) END;
		Get(q, cand);
		IF cand.condition(cand.condFP) THEN
			IF Stats THEN Machine.AtomicInc(Ncondition2True) END;
			RETURN cand
		END;
		Put(q, cand)
	END;
	RETURN NIL
END FindCondition;

(* Find highest priority in array of priority counts *)
PROCEDURE MaxPrio(CONST priorityCounts: ARRAY OF LONGINT): LONGINT;
VAR i: LONGINT;
BEGIN
	i := LEN(priorityCounts) - 1;
	WHILE (i >= 0) & (priorityCounts[i] = 0) DO DEC(i) END;
	IF priorityCounts[i] = 0 THEN
		Machine.Acquire(Machine.TraceOutput);
		Trace.StringLn("Objects: MaxPrio - SEVERE ERROR: priorityCounts contains all zeros");
		Machine.Release(Machine.TraceOutput);
	END;
	RETURN i
END MaxPrio;

(* Unlock a protected object (kernel call). *)
(* There are two different procedures for locking a protected object in case of priority inverison handling enabled or disabled due to the different
    locking strategy. *)
PROCEDURE Unlock*(obj: ProtectedObject; dummy: BOOLEAN);
BEGIN
	IF HandlePriorityInv THEN
		UnlockPriorityInv(obj)
	ELSE
		UnlockNoPriorityInv(obj)
	END
END Unlock;

(* transfer the lock from a resource to another process.
    Remark: hdr is an actually UNTRACED parameter. The GC, however, can handle this, see procedure Heaps.Mark, there is a check whether the
    pointer to the header part is valid. In case of hdr, the pointer ot the header part is NIL. *)
PROCEDURE TransferLock(hdr: Heaps.ProtRecBlock; p: Process);
VAR maxWaitingPrio: LONGINT;
BEGIN
	p.waitingOn := NIL; hdr.lockedBy := p;
	IF HandlePriorityInv THEN
		DEC(hdr.waitingPriorities[p.priority]);
		maxWaitingPrio := MaxPrio(hdr.waitingPriorities);
		INC(p.prioRequests[maxWaitingPrio]);
		p.priority := MaxPrio(p.prioRequests)
	END
END TransferLock;

(* Unlock a protected object if priority inversion handling is disabled. Header locks, preemption and Machine.Objects locks are used. *)
PROCEDURE UnlockNoPriorityInv(obj: ProtectedObject);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; t, c, r: Process; id: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Nunlock) END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	ASSERT(hdr.count = -1);	(* exclusive locked *)
	IF hdr.awaitingCond.head # NIL THEN (* evaluate the waiting conditions *)
			(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
		c := FindCondition(hdr.awaitingCond) (* interrupts should be on during this call *)
	ELSE
		c := NIL
	END;
	id := Machine.AcquirePreemption ();
	Machine.AcquireObject(hdr.locked);
	r := running[Machine.ID ()];
	IF hdr.lockedBy # r THEN
		Machine.ReleaseObject(hdr.locked);
		Machine.ReleasePreemption;
		ASSERT(hdr.lockedBy = r)
	END;
	IF c = NIL THEN (* no true condition found, check the lock queue *)
		Get(hdr.awaitingLock, t);
		IF t # NIL THEN
			IF StrongChecks THEN
				ASSERT((t.mode = AwaitingLock) & (t.waitingOn = obj))
			END;
			TransferLock(hdr, t)
		ELSE
			hdr.lockedBy := NIL; hdr.count := 0
		END
	ELSE (* true condition found, transfer the lock *)
		TransferLock(hdr, c);
		t := NIL
	END;

	Machine.ReleaseObject(hdr.locked);
	IF (c # NIL) OR (t # NIL) THEN
		Machine.Acquire(Machine.Objects);
		IF c # NIL THEN Enter(c) END;
		IF t # NIL THEN Enter(t) END;
		Machine.Release(Machine.Objects);
	END;
	Machine.ReleasePreemption;
END UnlockNoPriorityInv;

(* Unlock a protected object in case priority inversion handling is enabled. Machine.Objects lock is used. *)
PROCEDURE UnlockPriorityInv(obj: ProtectedObject);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; t, c, r: Process; maxWaitingPrio: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Nunlock) END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	ASSERT(hdr.count = -1);	(* exclusive locked *)
	IF hdr.awaitingCond.head # NIL THEN (* evaluate the waiting conditions *)
			(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
		c := FindCondition(hdr.awaitingCond) (* interrupts should be on during this call *)
	ELSE
		c := NIL
	END;
	Machine.Acquire(Machine.Objects);
	r := running[Machine.ID ()];
	IF hdr.lockedBy # r THEN
		Machine.Release(Machine.Objects);
		ASSERT(hdr.lockedBy = r)
	END;
	maxWaitingPrio := MaxPrio(hdr.waitingPriorities);
	DEC(r.prioRequests[maxWaitingPrio]);
	r.priority := MaxPrio(r.prioRequests);
	IF c = NIL THEN (* no true condition found, check the lock queue *)
		GetMaxPrio(hdr.awaitingLock, t);
		IF t = NIL THEN
			hdr.lockedBy := NIL; hdr.count := 0
		ELSE
			IF StrongChecks THEN ASSERT((t.mode = AwaitingLock) & (t.waitingOn = obj)) END;
			TransferLock(hdr, t)
		END
	ELSE (* true condition found, transfer the lock *)
		TransferLock(hdr, c);
		t := NIL
	END;

	IF (c # NIL) OR (t # NIL) THEN
		IF c # NIL THEN Enter(c) END;
		IF t # NIL THEN Enter(t) END;
	END;
	Machine.Release(Machine.Objects);
END UnlockPriorityInv;

(* Await a condition (kernel call). *)
(* There are two different procedures for locking a protected object in case of priority inverison handling enabled or disabled due to the different
    locking strategies, i.e. there are no header locks in case of priority inversion handling. *)
PROCEDURE Await*(cond: Condition; slink: ADDRESS; obj: ProtectedObject; flags: SET);
BEGIN
	IF HandlePriorityInv THEN
		AwaitPriorityInv(cond, slink, obj, flags)
	ELSE
		AwaitNoPriorityInv(cond, slink, obj, flags)
	END
END Await;

(* Await a condition if priority inversion handling is disabled. Header locks, preemption and Machine.Objects locks are used. *)
PROCEDURE AwaitNoPriorityInv(cond: Condition; slink: ADDRESS; obj: ProtectedObject; flags: SET);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r, c, t: Process; id: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Nawait) END;
	IF 1 IN flags THEN (* compiler did not generate IF *)
		IF Stats THEN Machine.AtomicInc(NawaitNoIF) END;
		IF cond(slink) THEN
			IF Stats THEN Machine.AtomicInc(NawaitTrue) END;
			RETURN (* condition already true *)
		END
	END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	id := Machine.AcquirePreemption ();
	Machine.AcquireObject(hdr.locked);	(* must acquire object lock before other locks *)
	r := running[id];
	IF hdr.lockedBy = r THEN	(* current process holds exclusive lock *)
		IF StrongChecks THEN ASSERT(hdr.count = -1) END; (* exclusive locked *)
		IF hdr.awaitingCond.head # NIL THEN	(* evaluate the waiting conditions *)
			(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
			c := FindCondition(hdr.awaitingCond)	(* interrupts should be on during this call *)
		ELSE
			c := NIL
		END;

		IF c = NIL THEN
			Get(hdr.awaitingLock, t);
			IF t = NIL THEN	(* none waiting - remove lock *)
				hdr.count := 0; hdr.lockedBy := NIL;
			ELSE	(* transfer lock to first waiting process *)
				IF StrongChecks THEN ASSERT(t.mode = AwaitingLock) END;
				TransferLock(hdr, t)
			END;
		ELSE
			TransferLock(hdr, c);
			t := NIL
		END;
	ELSE (* no lock, or some other process may hold the lock, but that's the user's indaba (may be monotonic condition) *)
		Machine.ReleaseObject(hdr.locked);
		Machine.ReleasePreemption;
		HALT(2204)	(* await must be exclusive region *)
	END;
	Machine.Acquire(Machine.Objects); (* Put and SwitchTo must be protected *)
	IF c # NIL THEN Enter(c)  END;
	IF t # NIL THEN Enter(t) END;
	IF StrongChecks THEN ASSERT(r.waitingOn = NIL) END;
	r.condition := cond; r.condFP := slink;
	r.waitingOn := obj; r.mode := AwaitingCond;
	Put(hdr.awaitingCond, r);
	Machine.ReleaseObject(hdr.locked);
	Machine.ReleasePreemption;
	(* reschedule *)
	SwitchToNew;
	IF StrongChecks THEN
		ASSERT(cond(slink));
		ASSERT(hdr.lockedBy = r) (* lock held again *)
	END
END AwaitNoPriorityInv;

(* Await a condition in case priority inversion handling is enabled. Machine.Objects lock is used. *)
PROCEDURE AwaitPriorityInv(cond: Condition; slink: ADDRESS; obj: ProtectedObject; flags: SET);
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r, c, t: Process; id, maxWaitingPrio, prevMaxWaitingPrio: LONGINT;
BEGIN
	IF Stats THEN Machine.AtomicInc(Nawait) END;
	IF 1 IN flags THEN (* compiler did not generate IF *)
		IF Stats THEN Machine.AtomicInc(NawaitNoIF) END;
		IF cond(slink) THEN
			IF Stats THEN Machine.AtomicInc(NawaitTrue) END;
			RETURN (* condition already true *)
		END
	END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	Machine.Acquire(Machine.Objects);
	id := Machine.ID();
	r := running[id];
	IF hdr.lockedBy = r THEN	(* current process holds exclusive lock *)
		IF StrongChecks THEN ASSERT(hdr.count = -1) END; (* exclusive locked *)
		maxWaitingPrio := MaxPrio(hdr.waitingPriorities);
		DEC(r.prioRequests[maxWaitingPrio]);
		r.priority := MaxPrio(r.prioRequests);
		IF hdr.awaitingCond.head # NIL THEN	(* evaluate the waiting conditions *)
			(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
			c := FindCondition(hdr.awaitingCond)	(* interrupts should be on during this call *)
		ELSE
			c := NIL
		END;

		IF c = NIL THEN
			GetMaxPrio(hdr.awaitingLock, t);
			IF t = NIL THEN	(* none waiting - remove lock *)
				hdr.count := 0; hdr.lockedBy := NIL;
			ELSE	(* transfer lock to first waiting process *)
				IF StrongChecks THEN ASSERT(t.mode = AwaitingLock) END;
				TransferLock(hdr, t);
			END;
		ELSE  (* true condition found, transfer the lock *)
			TransferLock(hdr, c);
			t := NIL;
		END;
	ELSE (* no lock, or some other process may hold the lock, but that's the user's indaba (may be monotonic condition) *)
		Machine.Release(Machine.Objects);
		HALT(2204)	(* await must be exclusive region *)
	END;
	IF c # NIL THEN Enter(c) END;
	IF t # NIL THEN Enter(t) END;
	IF StrongChecks THEN ASSERT(r.waitingOn = NIL) END;
	r.condition := cond; r.condFP := slink;
	r.waitingOn := obj; r.mode := AwaitingCond;
	IF hdr.lockedBy # NIL THEN
		prevMaxWaitingPrio := MaxPrio(hdr.waitingPriorities);
		INC(hdr.waitingPriorities[r.priority]);
		IF r.priority > prevMaxWaitingPrio THEN PropagatePrio(hdr, prevMaxWaitingPrio, r.priority) END;
	ELSE (* it may happen that hdr is not locked - in that case no priority propagation takes place *)
		INC(hdr.waitingPriorities[r.priority])
	END;
	Put(hdr.awaitingCond, r);
	(* reschedule *)
	SwitchToNew;
	IF StrongChecks THEN
		ASSERT(cond(slink));
		ASSERT(hdr.lockedBy = r) (* lock held again *)
	END
END AwaitPriorityInv;

(** Update the state snapshot of the current process for GC. (for Processors) *)
PROCEDURE UpdateState;
VAR t: Process;
BEGIN (* interrupts off *)
	Machine.Acquire(Machine.Objects);
	t := running[Machine.ID ()];
	IF t # NIL THEN
 		t.state.PC := Machine.CurrentPC(); (* ug: required information for GC with meta data for stack inspection *)
 		t.state.SP := Machine.CurrentSP(); (* ug: not necessarily needed for GC *)
 		t.state.BP := Machine.CurrentBP(); (* ug: necessary information for GC with meta data for stack inspection *)
	END;
	Machine.Release(Machine.Objects)
END UpdateState;

(** Start executing user processes. Every processor calls this during initialization. *)
PROCEDURE Start*;
VAR id: LONGINT; idle: Idle; new: Process;
BEGIN (* running at kernel level (not preemptable) *)
	id := Machine.ID (); (* preemption not enabled yet, because we are running at kernel level *)
	NEW(idle); (* create process with MinPriority *)
	Machine.Acquire(Machine.Objects);
	Get(ready.q[MinPriority], new); (* can not use Select here, as it might return a preempted process *)
	ASSERT(~(Preempted IN new.flags)); (* will at least get the Idle process just created *)
	Machine.Release(Machine.Objects);
	running[id] := new; (* schedule new process *)
	new.mode := Running; new.procID := id;
	IF Machine.SSESupport THEN Machine.SSERestoreMin(new.sseAdr)
	ELSE Machine.FPURestoreMin(new.sse)
	END;
	Machine.JumpToUserLevel(new.state.BP)
END Start;

(* Initialize module. *)
PROCEDURE Init; (* can not use NEW *)
VAR
	lock: PROCEDURE (obj: ProtectedObject; exclusive: BOOLEAN);
	unlock: PROCEDURE (obj: ProtectedObject; dummy: BOOLEAN);
	await: PROCEDURE (cond: Condition; slink: ADDRESS; obj: ProtectedObject; flags: SET);
	create: PROCEDURE (body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject);
	i: LONGINT;
BEGIN
	ProcessorHLT := NIL;
	maxReady := High; (* scan all queues at start *)
	lowestAllowedPriority := Low; (* normal case, will be set to GCPriority if GC is running *)
	gcBarrier := {};
	FOR i := 0 TO Machine.MaxCPU - 1 DO running[i] := NIL END;
	FOR i := 0 TO NumPriorities - 1 DO rootedProcesses[i] := NIL END;
	FOR i := 0 TO NumIRQ-1 DO processingIRQ[i] := FALSE END;
	nextProcessID := 0; Machine.ticks := 0;
	traceProcess := NIL;
	lock := Lock; unlock := Unlock; await := Await; create := CreateProcess;
	Modules.kernelProc[3] := SYSTEM.VAL (ADDRESS, create);	(* 250 *)
	Modules.kernelProc[4] := SYSTEM.VAL (ADDRESS, await);	(* 249 *)
	Modules.kernelProc[6] := SYSTEM.VAL (ADDRESS, lock);	(* 247 *)
	Modules.kernelProc[7] := SYSTEM.VAL (ADDRESS, unlock);	(* 246 *)
	terminate := Terminate;
	trap[0] := Halt;
	trap[1] := HaltUnbreakable;
	trapReturn[0] := HaltReturn;
	trapReturn[1] := HaltUnbreakableReturn;
END Init;

PROCEDURE InitEventHandling;
VAR i: LONGINT; clock: Clock; (* realtimeClock: RealtimeClock; *)
BEGIN
	FOR i := 0 TO NumIRQ-1 DO
		interrupt[i].root := NIL; interrupt[i].process := NIL
	END;
	(* create normal event list *)
	NEW(event); event.next := event; event.prev := event;
	event.trigger := Machine.ticks + MAX(LONGINT) DIV 2;
	(* create normal timer processes *)
	timer := NIL; NEW(clock);
END InitEventHandling;

PROCEDURE InitGCHandling;
VAR finalizerCaller: FinalizerCaller;
BEGIN
	gcProcess := NIL; NEW(gcActivity);
	finalizerProcess := NIL; NEW(finalizerCaller);
END InitGCHandling;

PROCEDURE InitStats;
BEGIN
	Nlock := 0; Nunlock := 0; Nawait := 0; NawaitNoIF := 0; NawaitTrue := 0;
	Ncreate := 0; Nterminate := 0; Ncondition := 0; Ncondition1True := 0;
	Ncondition2 := 0; Ncondition2True := 0;
	Ntimeslice := 0; NtimesliceTaken := 0; NtimesliceNothing := 0;
	NtimesliceIdle := 0; NtimesliceKernel := 0; NtimesliceV86 := 0; NtimesliceCritical := 0;
	Npreempt := 0; NpreemptTaken := 0; NpreemptNothing := 0;
	NpreemptKernel := 0; NpreemptV86 := 0; NpreemptCritical := 0;
	Nenter := 0;
END InitStats;

PROCEDURE GCStatusFactory(): Heaps.GCStatus;
VAR gcStatusExt : GCStatusExt;
BEGIN
	ASSERT(Heaps.gcStatus = NIL);
	NEW(gcStatusExt);
	RETURN gcStatusExt
END GCStatusFactory;

BEGIN
	IF Stats THEN InitStats; END;
	Init;
	(* initialize memory management *)
	Machine.UpdateState; (* for gc *)
	Heaps.CollectGarbage(Modules.root); (* still in single-processor mode *)
	(* now NEW can be used *)
	NEW(ready); (* create the ready queues *)
	Machine.InitInterrupts;
	Machine.Start; (* initialize interrupts *)
	InitEventHandling;
	InitGCHandling;
	Heaps.gcStatus := GCStatusFactory();
	(* create a process for rest of init code, which runs at user level *)
	entry := Machine.CurrentBP ();
	SYSTEM.GET (entry+AddressSize, entry);	(* return address into linker-generated call table *)
	NewProcess(SYSTEM.VAL (Body, entry), {Resistant}, NIL, init); (* create init process *)
	init.priority := High;
	init.staticPriority := init.priority;
	(* initialize prioRequests for init process *)
	FOR i := 0 TO LEN(init.prioRequests) - 1 DO init.prioRequests[i] := 0 END;
	INC(init.prioRequests[init.priority]);
	Machine.Acquire(Machine.Objects);
	init.id := -1; Enter(init); init := NIL;
	Machine.Release(Machine.Objects);
	Start (* start it *)
	(* linker call table will end with a call to Terminate. So after executing all module bodies,
	the init process will terminate and other processes created during init will continue running. *)
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
19.06.2007	ug	Garbage Collector using meta data for stack inspection
*)

(*
Location	Stack
Lock	Current process
 SwitchTo.A	Current process
 SwitchTo.B
*)
