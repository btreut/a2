 (* Aos, Copyright 2001, Pieter Muller, ETH Zurich; this module ported for the windows version, fof. *)

MODULE Objects;   (** AUTHOR "pjm, ejz, fof"; PURPOSE "Active object runtime support"; *)

IMPORT SYSTEM, Trace, Kernel32, Machine, Modules, Heaps;

CONST
	HandleExcp = TRUE;   (* FALSE -> we asume that it is done correctly by Traps *)
	TraceVerbose = FALSE;
	StrongChecks = FALSE;  defaultStackSize = 0;
	TraceOpenClose = FALSE;

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
	MinPriority = 0;							(* only system idle processes run at this priority level *)
	Low* = 1; Normal* = 2; High* = 3;		(* "user" priorities *)
	GCPriority* = 4;							(* priority of garbage collector *)
	Realtime* = 5;							(* reserved for interrupt handling and realtime apps, these processes are not allowed to allocate memory *)

	(* Process termination halt codes *)
	halt* = 2222;
	haltUnbreakable* = 2223;

	(* constant used in GC Process.FindPointers *)
	InitDiff = MAX(LONGINT);

	AddressSize = SIZEOF (ADDRESS);

TYPE
	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	ProtectedObject = POINTER TO RECORD END;   (* protected object (10000) *)

	ProcessQueue = Heaps.ProcessQueue;

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
			ticks: LONGINT;
			hevent: Kernel32.HANDLE;
			res: Kernel32.BOOL;
			mode: LONGINT;
			process: Process;

		PROCEDURE Wakeup;
		VAR res: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			res := Kernel32.SetEvent(hevent)
		END Wakeup;

		PROCEDURE Finalize(ptr: ANY);
		VAR res: Kernel32.BOOL;
		BEGIN
			IF hevent # 0 THEN res := Kernel32.CloseHandle(hevent);  hevent := 0 END
		END Finalize;

		PROCEDURE &Init*;
		VAR fn: Heaps.FinalizerNode;
		BEGIN
			hevent := Kernel32.CreateEvent(NIL, 0, 0, NIL);
			ASSERT(hevent # 0);
			NEW(fn); fn.finalizer := SELF.Finalize; Heaps.AddFinalizer(SELF, fn)
		END Init;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		process := CurrentProcess();
		mode := process.mode;
		LOOP
			Machine.Acquire(Machine.Objects);
			process.mode := mode;
			LOOP
				h := event.next;  (* event: head of timer event queue *)
				ticks := Kernel32.GetTickCount();
				IF (h = event) OR (h.trigger - ticks > 0) THEN EXIT END;
				event.next := h.next;  event.next.prev := event;   (* unlink *)
				h.next := NIL;  h.prev := NIL;
				Machine.Release(Machine.Objects);
				h.handler();   (* assume handler will return promptly *)
				Machine.Acquire(Machine.Objects)
			END;
			mode := process.mode;
			process.mode := AwaitingEvent;
			Machine.Release(Machine.Objects);
			IF h = event THEN (* sentinel head of timer event queue: wait forever until a new event has been entered in queue *)
				res := Kernel32.WaitForSingleObject(hevent, MAX(LONGINT));
			ELSE
				res := Kernel32.WaitForSingleObject(hevent, h.trigger - ticks);
			END;
		END
	END Clock;

TYPE

	Win32Event = Kernel32.HANDLE;

	Process* = OBJECT(Heaps.ProcessLink)
	VAR
		rootedNext : Process; (*  to prevent process to be GCed in WinAos *)
		obj-: ProtectedObject;   (* associated active object *)
		state-: Kernel32.Context;
		(*
		sse: SSEState;	(* fpu and sse state of preempted process (only valid if Preempted IN flag) *)
		sseAdr: LONGINT;
		*)
		condition-: Condition;   (* awaited process' condition *)
		condFP-: LONGINT;   (* awaited process' condition's context *)
		mode-: LONGINT;   (* process state *)  (* only changed inside Objects lock ??? *)
		procID-: LONGINT;   (* processor ID where running,  exported for compatibilty , useless in WinAos *)
		waitingOn-: ProtectedObject;   (* obj this process is waiting on (for lock or condition) *)
		id-: LONGINT;   (* unique process ID for tracing *)
		flags*: SET;   (* process flags *)
		priority-: LONGINT;   (* process priority *)
		(*
		currPri: LONGINT;
		stack*: Machine.Stack; (** user-level stack of process *)
		*)
		stackBottom: LONGINT;
		handle-: Kernel32.HANDLE; (* handle to corresponding Windows thread *)
		body: Body;
		event: Win32Event;
		restartPC-: LONGINT;   (** entry point of body, for SAFE exception recovery *)
		restartSP-: LONGINT;   (** stack level at start of body, for SAFE exception recovery *)
		(*
		perfCyc*: ARRAY Machine.MaxCPU OF HUGEINT;
		priInvCnt: LONGINT; (* counts the nummber of object locks hold that increased currPri of the process *)
		exp*: Machine.ExceptionState;
		oldReturnPC: LONGINT;
		*)
		lastThreadTimes: HUGEINT;   (*ALEX 2005.12.12*)

		PROCEDURE FindRoots;   (* override, called while GC, replaces Threads.CheckStacks *)
		VAR sp: LONGINT; res: Kernel32.BOOL; pc, bp, curbp: ADDRESS;
			d0, d1: SIZE; first : BOOLEAN;
		BEGIN
		(*ALEX 2005.12.13 senseless ASSERT that blocks for AWAITING THREADS that were closed*)

			IF (handle = 0) OR (mode = Terminated) OR (mode < Ready) (* procedure Wrapper not yet started *)
			OR (priority > High) (* stack of GC and realtime processes not traced *) THEN
				RETURN
			END;
			(*
			ASSERT( SYSTEM.VAL( Process, Kernel32.TlsGetValue( tlsIndex ) ) # SELF); (* should not trace gc process *)
			*)

			state.ContextFlags := Kernel32.ContextControl + Kernel32.ContextInteger;
			res := Kernel32.GetThreadContext( handle, state );

			ASSERT ( res # 0, 1004 );
			sp := state.SP;  bp := state.BP; pc := state.PC;

			(* stack garbage collection *)

			IF Heaps.GCType= Heaps.HeuristicStackInspectionGC THEN
				Heaps.Candidate( state.EDI );  Heaps.Candidate( state.ESI );
				Heaps.Candidate( state.EBX ); Heaps.Candidate( state.EDX );
				Heaps.Candidate( state.ECX ); Heaps.Candidate( state.EAX );
				IF (stackBottom # 0) & (sp # 0) THEN
					Heaps.RegisterCandidates( sp, stackBottom - sp );
				END;
			ELSIF Heaps.GCType = Heaps.MetaDataForStackGC THEN
				first := TRUE; curbp := bp;
				WHILE (bp # Heaps.NilVal) & (sp <= bp) & (bp < stackBottom)  DO
					FindPointers(bp, pc, d0, d1);
 					IF first THEN
 						ASSERT(d0#2);
 						ASSERT(d1 # 1);
 						IF (d0 = 0) OR (d0 = 1) OR (d1 = 3)  THEN
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
 								SYSTEM.GET(state.SP + AddressSize, pc);		(* matching pc is at 4 bytes after stack pointer, pushed base pointer is at stack pointer position *)
							END;
 						ELSE
 							(* regular case: bp and pc were synchronized *)
 							curbp := bp;
							SYSTEM.GET(curbp + AddressSize, pc);
							SYSTEM.GET(curbp, bp);
 						END;
 						first := FALSE;
 					ELSE
	 					(* regular case: bp and pc were synchronized *)
 						curbp := bp;
						SYSTEM.GET(curbp, bp);
						SYSTEM.GET(curbp + AddressSize, pc);
					END
				END
			ELSE HALT(101);
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

	ExceptionHandler* = PROCEDURE(	VAR context: Kernel32.Context;
										VAR excpRec: Kernel32.ExceptionRecord;
										VAR handled: BOOLEAN);


	GCStatusExt = OBJECT(Heaps.GCStatus)
		VAR
			(*
			gcOngoing: BOOLEAN;
			event: Kernel32.HANDLE;
			caller: Process;

		PROCEDURE &Init;
		BEGIN
			gcOngoing := FALSE;
			event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto-reset *), Kernel32.False, NIL );   (* manual set event with initial state = reset *)
			ASSERT(event # 0);
		END Init;
			*)

		(*
		(* called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects lock here since writing
		    the set of variables here must not be interrupted, i.e. atomic writing of the set of variables is absolutely necessary.  They system may hang
		    if the lock is not taken. *)
		PROCEDURE SetgcOngoing(value: BOOLEAN);
		VAR p: Heaps.ProcessLink; cur, r: Process; res: Kernel32.BOOL; num: LONGINT;
		BEGIN (* serialize writers *)
			IF value THEN
				(* Low, Medium or High priority process calls this *)
				Machine.Acquire(Machine.Objects);
				Machine.Acquire(Machine.Heaps); (* to protect agains concurrent LazySweep *)
				r := CurrentProcess();
				caller := r;
				r.mode := AwaitingEvent;
				num := 0;
				IF ~gcOngoing THEN
					gcOngoing := TRUE;
					p := ready.head;
					WHILE p # NIL DO
						cur := p(Process);
						IF ((cur.mode = Ready) OR (cur.mode = Running)) & (cur.priority <= High) & (cur # r) THEN
							res := Kernel32.SuspendThread(cur.handle);
							cur.mode := Suspended
						ELSE INC(num);
						END;
						p := p.next
					END;
					(* start GC *)
					gcActivity.Activate;
				END;
				Machine.Release(Machine.Heaps);
				Machine.Release(Machine.Objects);
				(* no process is running except the caller process and the GC process, no race here *)
				res := Kernel32.WaitForSingleObject(event, Kernel32.Infinite); (* block execution *)
				ASSERT(res = Kernel32.WaitObject0)
			ELSE
				(* gcProcess calls this *)
				Machine.Acquire(Machine.Objects);
				gcOngoing := FALSE;
				p := ready.head;
				WHILE (p # NIL) DO
					cur := p(Process);
					(* only suspended and awaiting processes of ready queue are resumed *)
					IF cur.mode = Suspended THEN
						res := Kernel32.ResumeThread(cur.handle);
						cur.mode := Running
					END;
					p := p.next
				END;
				caller.mode := Running;
				Kernel32.SetEvent(event);
				r := CurrentProcess();
				ASSERT(r = gcActivity.process);
				r.mode := AwaitingEvent;
				Machine.Release(Machine.Objects);
			END;
		END SetgcOngoing;
		*)

	(* called from Heaps.InvokeGC, i.e. this is a hidden upcall. However, it is necessary to take the Machine.Objects lock here since writing
		    the set of variables here must not be interrupted, i.e. atomic writing of the set of variables is absolutely necessary.  They system may hang
		    if the lock is not taken. *)
		PROCEDURE SetgcOngoing(value: BOOLEAN);
		VAR p: Heaps.ProcessLink; cur, r: Process; res: Kernel32.BOOL; num: LONGINT; time: LONGINT;
		BEGIN (* serialize writers *)
			IF value THEN
				(* Low, Medium or High priority process calls this *)
				time := Kernel32.GetTickCount();
				Machine.Acquire(Machine.Objects);
				Machine.Acquire(Machine.Heaps); (* to protect agains concurrent LazySweep *)
				r := CurrentProcess();
				num := 0;
				p := ready.head;
				WHILE p # NIL DO
					cur := p(Process);
					IF ((cur.mode = Ready) OR (cur.mode = Running)) & (cur.priority <= High) & (cur # r) THEN
						res := Kernel32.SuspendThread(cur.handle);
						cur.mode := Suspended
					ELSE INC(num);
					END;
					p := p.next
				END;

				Heaps.CollectGarbage(Modules.root);
				p := ready.head;
				WHILE (p # NIL) DO
					cur := p(Process);
					(* only suspended and awaiting processes of ready queue are resumed *)
					IF cur.mode = Suspended THEN
						res := Kernel32.ResumeThread(cur.handle);
						cur.mode := Running
					END;
					p := p.next
				END;


				Machine.Release(Machine.Heaps);
				Machine.Release(Machine.Objects);
				time := Kernel32.GetTickCount()-time;
				IF Heaps.trace THEN Trace.String("GC Called -- duration "); Trace.Int(time,0); Trace.String(" ms."); Trace.Ln END;
				IF finalizerCaller # NIL THEN finalizerCaller.Activate() END;
			END;
		END SetgcOngoing;

	END GCStatusExt;

	GCActivity = OBJECT
	(*
	VAR
		res: Kernel32.BOOL;
		event: Kernel32.HANDLE;
		process: Process;

		PROCEDURE &Init;
		BEGIN
			ASSERT(gcActivity = NIL); (* should only exist once *)
			event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto-reset *), Kernel32.False, NIL );   (* manual set event with initial state = reset *)
		END Init;

		PROCEDURE Activate;
		BEGIN
			process.mode := Running;
			res := Kernel32.SetEvent(event);
		END Activate;

		PROCEDURE Wait;
		BEGIN
			process.mode := AwaitingEvent;
			res := Kernel32.WaitForSingleObject(event, Kernel32.Infinite); (* block execution *)
			ASSERT(res = Kernel32.WaitObject0);
		END Wait;

	BEGIN {ACTIVE, SAFE, PRIORITY(GCPriority)}
		Machine.Acquire(Machine.Objects);
		process := CurrentProcess();
		process.mode := AwaitingEvent;
		Machine.Release(Machine.Objects);
		LOOP
			Wait;
			(* process is scheduled -> perform garbage collection now *)
			Heaps.CollectGarbage(Modules.root);
			Heaps.gcStatus.SetgcOngoing(FALSE); (* resumes waiting processes and suspends itself *)
			IF finalizerCaller # NIL THEN finalizerCaller.Activate() END;
		END
	*)
	END GCActivity;

	FinalizedCollection* = OBJECT
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;

	FinalizerCaller = OBJECT  (* separate active object that calls finalizers *)
	VAR n: Heaps.FinalizerNode;
		event: Kernel32.HANDLE;
		process: Process;

		PROCEDURE &Init;
		BEGIN
			event := Kernel32.CreateEvent( NIL, Kernel32.False (* automatic *), Kernel32.False, NIL );
			ASSERT(event # 0);
		END Init;

		PROCEDURE Wait;
		VAR res: Kernel32.BOOL; mode: LONGINT;
		BEGIN
			mode := process.mode;
			process.mode := AwaitingEvent;
			res := Kernel32.WaitForSingleObject(event, Kernel32.Infinite);
			ASSERT(res = Kernel32.WaitObject0);
			process.mode := mode;
		END Wait;

		PROCEDURE Activate;
		VAR res: Kernel32.BOOL;
		BEGIN
			res := Kernel32.SetEvent(event);
		END Activate;

	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		process := CurrentProcess();
		LOOP
			Wait;
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n IS FinalizerNode THEN
					n( FinalizerNode ).c.RemoveAll( n.objStrong ) (* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer( n.objStrong ) (* may acquire locks *)
				END
			END
		END;
	END FinalizerCaller;

VAR
	awc-, awl-: LONGINT;
	oberonLoop*: ANY;   (* Oberon Loop Process temporary workaround for Threads.oberonLoop *)
	break: ARRAY 16 OF CHAR;
	terminateProc: PROCEDURE;
	ready: ProcessQueue;	(* contains running processes in this implementation *)

	numberOfProcessors: LONGINT; (* cached value of Machine.NumberOfProcessors() *)
	finalizerCaller: FinalizerCaller; (* active object for finalizer process, regarded as aprt of GC *)
	gcActivity: GCActivity;

	event: Timer; (* list of events *)
	clock: Clock;
	tlsIndex: LONGINT;
	nProcs: LONGINT;

	excplock: Kernel32.CriticalSection;  exceptionhandler: ExceptionHandler;

(* Set the current process' priority. *)
PROCEDURE SetPriority*( priority: LONGINT );
VAR r: Process; prio: LONGINT; res: Kernel32.BOOL;
BEGIN
	ASSERT((priority >= Low) & (priority <= Realtime));   (* priority in bounds *)
	r := CurrentProcess();  r.priority := priority;
	CASE priority OF
	MinPriority:
			prio := Kernel32.ThreadPriorityIdle
	| Low:
			prio := Kernel32.ThreadPriorityBelowNormal
	| High:
			prio := Kernel32.ThreadPriorityAboveNormal
	| GCPriority, Realtime:
			prio := Kernel32.ThreadPriorityTimeCritical
	ELSE  (* Normal *)
		prio := Kernel32.ThreadPriorityNormal
	END;
	res := Kernel32.SetThreadPriority( r.handle, prio );
	ASSERT(r.handle # 0);
	ASSERT(res # 0)
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
	Kernel32.Sleep(0)
END Yield;

(** Return current process. (DEPRECATED, use ActiveObject) *)
PROCEDURE CurrentProcess*( ): Process;
BEGIN
	RETURN SYSTEM.VAL(Process, Kernel32.TlsGetValue(tlsIndex));
END CurrentProcess;

(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
PROCEDURE GetStackBottom*(p: Process): ADDRESS;
BEGIN
	RETURN p.stackBottom
END GetStackBottom;

(** Return the active object currently executing. *)
PROCEDURE ActiveObject* (): ANY;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL(Process, Kernel32.TlsGetValue(tlsIndex));
	RETURN r.obj
END ActiveObject;

(** Return the ID of the active currently executing process. *)
PROCEDURE GetProcessID* (): LONGINT;
VAR r: Process;
BEGIN
	r := SYSTEM.VAL (Process, Kernel32.TlsGetValue( tlsIndex ));
	RETURN r.id
END GetProcessID;

(* Get a process from a queue (NIL if none). Caller must hold lock for specific queue. *)
PROCEDURE Get(VAR queue: ProcessQueue; VAR new: Process);
VAR t: Heaps.ProcessLink;
BEGIN
	t := queue.head;
	IF t = NIL THEN  (* zero elements in queue *)
		(* skip *)
	ELSIF t = queue.tail THEN  (* one element in queue *)
		queue.head := NIL; queue.tail := NIL  (* {(t.next = NIL) & (t.prev = NIL)} *)
	ELSE  (* more than one element in queue *)
		queue.head := t.next; t.next := NIL; queue.head.prev := NIL
	END;
	ASSERT((t = NIL) OR (t.next = NIL ) & (t.prev = NIL)); (* temp strong check *)
	IF t = NIL THEN
		new := NIL
	ELSE
		ASSERT(t IS Process);
		new := t(Process)
	END
END Get;

(* Put a process in a queue. Caller must hold lock for specific queue. *)
(* If t was running, be careful to protect Put and the subsequent SwitchTo with the ready lock. *)
PROCEDURE Put(VAR queue: ProcessQueue; t: Process);
BEGIN (* {t # NIL & t.next = NIL & t.prev = NIL} *)
	IF StrongChecks THEN
		ASSERT((t.next = NIL) & (t.prev = NIL))
	END;
	t.next := NIL; t.prev := NIL; (* ug *)
	IF queue.head = NIL THEN (* queue empty *)
		queue.head := t
	ELSE (* queue not empty *)
		queue.tail.next := t; t.prev := queue.tail
	END;
	queue.tail := t
END Put;

(* starting address of user stack for current thread, called stack top in TIB.H *)
PROCEDURE -StackBottom*( ): LONGINT;
CODE {SYSTEM.i386}
	DB	064H
	DB	08BH
	DB	005H
	DB	004H
	DB	000H
	DB	000H
	DB	000H
END StackBottom;

PROCEDURE {WINAPI} ExcpFrmHandler( VAR excpRec: Kernel32.ExceptionRecord; excpFrame: Kernel32.ExcpFrmPtr;
 										VAR context: Kernel32.Context;  dispatch: LONGINT ): LONGINT;
VAR m: Modules.Module;  eip, ebp, stack: LONGINT;  pc, handler, fp, sp: LONGINT;  handled: BOOLEAN;  t: Process;
BEGIN
	handled := FALSE;

	Kernel32.EnterCriticalSection( excplock );

	(*
	fof: commenting this resolved a problem with multiple traps that a are catched with FINALLY statements in Windows Vista
	in Windows XP not necessary if Kernel32.SetThreadContext is not used (better to return gracefully from this handler)
	SetCurrent(excpFrame);
	*)

	t := CurrentProcess();

	IF exceptionhandler = NIL THEN
		Trace.StringLn ( "Objects: No exception handler installed" );
		IF HandleExcp THEN

			Trace.String( "EXCEPTION " );  Trace.Hex( excpRec.ExceptionCode, 1 );
			Trace.String( " at " );  Trace.Hex( excpRec.ExceptionAddress, 1 );
			Trace.Ln();  Trace.String( "EAX " );  Trace.Hex( context.EAX, 1 );
			Trace.String( "  EBX " );  Trace.Hex( context.EBX, 1 );  Trace.Ln();
			Trace.String( "ECX " );  Trace.Hex( context.ECX, 1 );  Trace.String( "  EDX " );
			Trace.Hex( context.EDX, 1 );  Trace.Ln();  Trace.String( "EDI " );
			Trace.Hex( context.EDI, 1 );  Trace.String( "  ESI " );
			Trace.Hex( context.ESI, 1 );  Trace.Ln();  Trace.String( "EBP " );
			Trace.Hex( context.BP, 1 );  Trace.String( "  ESP " );
			Trace.Hex( context.SP, 1 );  Trace.Ln();  Trace.String( "EIP " );
			Trace.Hex( context.PC, 1 );  Trace.Ln();  Trace.Ln();
			eip := excpRec.ExceptionAddress;  ebp := context.BP;
			IF eip = 0 THEN SYSTEM.GET( context.SP, eip ) END;
			stack := StackBottom();
			LOOP
				Trace.String( "at ebp= " );  Trace.Hex( ebp, 1 );  Trace.String( "H : " );
				m := Modules.ThisModuleByAdr( eip );
				IF m # NIL THEN
					Trace.String( m.name );  Trace.String( " " );
					Trace.Hex( eip - SYSTEM.VAL( LONGINT, ADDRESSOF( m.code[0] ) ), 1 );
				ELSE Trace.String( "EIP " );  Trace.Hex( eip, 1 )
				END;
				Trace.Ln();
				IF (ebp # 0) & (ebp < stack) THEN  (* if ebp is 0 in first frame *)
					SYSTEM.GET( ebp + 4, eip );   (* return addr from stack *)
					SYSTEM.GET( ebp, ebp );   (* follow dynamic link *)
				ELSE EXIT
				END
			END;
			Trace.Ln();

			handled := FALSE;  fp := context.BP;  sp := context.SP;
			pc := context.PC;  handler := Modules.GetExceptionHandler( pc );
			IF handler # -1 THEN  (* Handler in the current PAF *)
				context.PC := handler;  handled := TRUE;
				(*SetTrapVariable(pc, fp);  SetLastExceptionState(exc)*)
			ELSE
				WHILE (fp # 0) & (handler = -1) DO
					SYSTEM.GET( fp + 4, pc );
					pc := pc - 1;   (*  CALL instruction, machine dependant!!! *)
					handler := Modules.GetExceptionHandler( pc );
					sp := fp;   (* Save the old framepointer into the stack pointer *)
					SYSTEM.GET( fp, fp ) (* Unwind PAF *)
				END;
				IF handler = -1 THEN handled := FALSE;
				ELSE
					context.PC := handler;  context.BP := fp;  context.SP := sp;
					(* SetTrapVariable(pc, fp); SetLastExceptionState(exc);*)
					handled := TRUE
				END
			END;
		ELSE Trace.StringLn ( "Warning: FINALLY statement cannot be treated !" );
		END
	ELSE exceptionhandler( context, excpRec, handled );
	END;
	IF ~handled THEN
		context.PC := t.restartPC;  context.SP := t.restartSP;
		context.BP := t.stackBottom;
	ELSIF TraceVerbose THEN Trace.StringLn ( "trying to jump to FINALLY pc..." );
	END;
	Kernel32.LeaveCriticalSection( excplock );

	IF TraceVerbose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String( "recover process; eip=" );  Trace.Int( context.PC, 10 );
		Trace.String( "; sp= " );  Trace.Int( context.SP, 10 );  Trace.String( "; ebp= " );
		Trace.Int( context.BP, 10 ); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;

	RETURN Kernel32.ExceptionContinueSearch; (* sets thread context and continues where specified in context *)
END ExcpFrmHandler;

(* get the currently installed execption frame *)
(*	PROCEDURE -GetCur 64H, 8BH, 0DH, 0, 0, 0, 0;   (* MOV ECX, FS:[0] *) *)
(* Better *)
PROCEDURE -GetCur;
CODE {SYSTEM.i386}
	DB	064H, 08BH, 00DH, 000H, 000H, 000H, 000H
END GetCur;

PROCEDURE GetCurrent( ): Kernel32.ExcpFrmPtr;
VAR cur: Kernel32.ExcpFrmPtr;
BEGIN
	GetCur;
	cur := SYSTEM.VAL(Kernel32.ExcpFrmPtr,Machine.GetECX());
	(* RETURN ECX *)
	RETURN cur
END GetCurrent;

(* install a new exception frame *)
(*	PROCEDURE -SetCur 64H, 0A3H, 0, 0, 0, 0;   (* MOV FS:[0], EAX *)*)
(* Better *)
PROCEDURE -SetCur;
CODE {SYSTEM.i386}
	DB	064H, 0A3H, 000H, 000H, 000H, 000H
END SetCur;

PROCEDURE SetCurrent( cur: Kernel32.ExcpFrmPtr );
BEGIN
	Machine.SetEAX(SYSTEM.VAL(LONGINT,cur));
	 (* EAX := cur *)
	SetCur
END SetCurrent;

PROCEDURE RemoveExcpFrm( VAR excpfrm: Kernel32.ExcpFrm );
VAR this: Kernel32.ExcpFrmPtr;
BEGIN
	this := GetCurrent();
	(* ASSERT ( this = ADDRESSOF( excpfrm ) );  *)
	IF this # ADDRESSOF( excpfrm ) THEN Trace.StringLn ( "RemoveExcpFrm: Problem with excpfrm pointer" );
	ELSE SetCurrent( excpfrm.link )
	END;
END RemoveExcpFrm;

PROCEDURE InstallExcpFrm( VAR excpfrm: Kernel32.ExcpFrm );
BEGIN
	excpfrm.link := GetCurrent();  excpfrm.handler := ExcpFrmHandler;
	SetCurrent( ADDRESSOF( excpfrm ) )
END InstallExcpFrm;

PROCEDURE InQueue( queue: ProcessQueue;  t: Process ): BOOLEAN;
VAR p: Heaps.ProcessLink;
BEGIN
	p := queue.head;
	WHILE (p # NIL ) & (p # t) DO p := p.next;  END;
	RETURN (p = t);
END InQueue;

(* Remove a process from a queue that contains it. Caller must hold lock for specific queue. *)
(* Not intended for frequent use. *)
(* does not check if queue contained t ! *)
PROCEDURE Remove( VAR queue: ProcessQueue;  t: Process );
BEGIN
	IF StrongChecks THEN
		ASSERT(InQueue(queue, t));
		ASSERT(t # NIL);
	END;
	IF t.prev # NIL THEN t.prev.next := t.next END;
	IF t.next # NIL THEN t.next.prev := t.prev END;
	IF t = queue.head THEN queue.head := t.next END;
	IF t = queue.tail THEN queue.tail := t.prev END;
	ASSERT((queue.head = NIL) OR (queue.head.prev = NIL) & (queue.tail.next = NIL));
	t.prev := NIL;  t.next := NIL
END Remove;

PROCEDURE WriteType(obj: ANY);
VAR type: LONGINT;
BEGIN
	IF obj = NIL THEN Trace.String(" > NIL");
	ELSE
		Trace.String(" > ");  SYSTEM.GET(SYSTEM.VAL(LONGINT, obj) + Heaps.TypeDescOffset, type);
		Heaps.WriteType(type);
	END;
END WriteType;

PROCEDURE terminate( t: Process );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; res: Kernel32.BOOL; shutdown: BOOLEAN;
BEGIN
	IF t = NIL THEN RETURN END;
	(* see Objects.TerminateThis *)
	Machine.Acquire( Machine.Objects );

	IF TraceVerbose OR TraceOpenClose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String( "Terminating process " );  Trace.Int( t.id, 1 );  WriteType( t.obj ); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;

	IF (t.mode = Ready) OR (t.mode = Running) THEN Remove( ready, t );
	ELSIF t.mode = AwaitingLock THEN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
		ASSERT(hdr IS Heaps.ProtRecBlock);
		Remove( hdr.awaitingLock, t );  Machine.Release( Machine.Objects );
		HALT( 97 )
	ELSIF t.mode = AwaitingCond THEN
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, t.waitingOn) + Heaps.HeapBlockOffset, hdr);
		ASSERT(hdr IS Heaps.ProtRecBlock);
		Remove( hdr.awaitingCond, t );  Machine.Release( Machine.Objects );
		HALT( 98 )
	ELSE Machine.Release( Machine.Objects );
		HALT( 99 )
	END;
	t.mode := Terminated;   (* a process can also be "terminated" if the queue containing it is garbage collected *)
	t.stackBottom := 0;  t.state.SP := 0;
	t.restartPC := 0;
	IF t.event # 0 THEN res := Kernel32.CloseHandle( t.event );  t.event := 0 END;
	DEC( nProcs );  shutdown := (nProcs = 0);

	Machine.Release( Machine.Objects );
	IF shutdown THEN
		Trace.StringLn ( " Objects: shutdown" ); Modules.Shutdown( -1 );
		Kernel32.ExitProcess( 0 )
	END
END terminate;

PROCEDURE {WINAPI} Wrapper( lpParameter: ANY ): LONGINT;
VAR t: Process;  obj: ProtectedObject; res: Kernel32.BOOL; bp,sp: LONGINT;
	excpfrm: Kernel32.ExcpFrm;
BEGIN
	(* it may happen that the garbage collector runs right here and ignores this procedure.
	    This is not a problem since lpParameter (being a reference to a process) is protected by the process lists *)

	Machine.Acquire(Machine.Objects);

	res := Kernel32.TlsSetValue(tlsIndex, SYSTEM.VAL(LONGINT, lpParameter));
	t := lpParameter(Process);  obj := t.obj;
	ASSERT(res # 0);
	InstallExcpFrm(excpfrm);
	SetPriority(t.priority);

	bp := Machine.CurrentBP();
	sp := Machine.CurrentSP();
	t.restartSP := sp;
	t.stackBottom := bp;
	IF t.restartPC = SYSTEM.VAL(ADDRESS, terminateProc) THEN DEC(t.restartSP, 4)
	ELSE DEC(t.restartSP, 8)
	END;
	IF TraceVerbose THEN
		Machine.Acquire(Machine.TraceOutput);
		Trace.String("New process; restartPC= "); Trace.Int(t.restartPC, 15);
		Trace.String("; restartSP= "); Trace.Int(t.restartSP, 15); Trace.String("; stackBottom= ");
		Trace.Int(t.stackBottom, 15); Trace.Ln;
		Machine.Release(Machine.TraceOutput);
	END;
	t.mode := Running;
	(* now gc is enabled for this process stack *)
	Machine.Release(Machine.Objects);
	(* loop all processes that the GC did not see during process suspending because they were in the very moment being generated (just before the locked section) *)

	(*! should not be necessary any more as GC runs immediately and without scheduling decisions
	WHILE (gcActivity # NIL) & (gcActivity.process # NIL) & (gcActivity.process.mode = Running) DO END;
	*)
	t.body(obj);
	terminate(t);
	RemoveExcpFrm(excpfrm);
	RETURN 0
END Wrapper;

PROCEDURE FinalizeProcess(t: ANY);
VAR p: Process;  res: Kernel32.BOOL;
BEGIN
	p := t(Process);

	IF TraceVerbose THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String("Finalizing Process"); Trace.Int(p.id, 1);
		WriteType(p.obj); Trace.Ln;
		Machine.Release (Machine.TraceOutput);
	END;
	IF p.mode # Terminated THEN
		IF p.mode = AwaitingLock THEN DEC(awl);
		ELSIF p.mode = AwaitingCond THEN DEC(awc);
		END;
		(* no reference to the object any more *)
		Trace.String ("Closing unreferenced process"); (*Trace.Int(p.mode,20); Trace.Int( p.id, 20 ); *) Trace.Ln; (* Trace.Ln *)
		(* this usually happens, when an objects process waits on its own objtec and no reference exists any more. Then the object is discarded and
		consequently the process is unreferenced (except in the object). This cannot happen when there are still other references on the object.
		example:
			TYPE
			Object= OBJECT VAR active: BOOLEAN; BEGIN{ACTIVE} active := FALSE; AWAIT(active) END Object;
			VAR o: Object;
			BEGIN NEW(o);
			END;
		 *)
	END;
	p.mode := Terminated; (* fof for GC problem *)

	IF p.handle # 0 THEN
		res := Kernel32.CloseHandle(p.handle); p.handle := 0
	END
END FinalizeProcess;

PROCEDURE TerminateProc;
BEGIN
	terminate(CurrentProcess());
	Kernel32.ExitThread(0);
	Kernel32.Sleep(999999);   (* wait until dependent threads terminated *)
END TerminateProc;

(* Allocate a new process associated with "obj". Must be outside lock region, because of potential GC. *)
PROCEDURE NewProcess(body: Body; priority: LONGINT;  flags: SET; obj: ProtectedObject; VAR new: Process);
VAR t,r: Process;  fn: Heaps.FinalizerNode;
BEGIN
	NEW(t);
	t.handle := 0;
	IF priority = 0 THEN  (* no priority specified *)
		r := CurrentProcess();
		t.priority := r.priority (* inherit priority of creator *)
	ELSIF priority > 0 THEN  (* positive priority specified *)
		t.priority := priority
	ELSE  (* negative priority specified (only for Idle process) *)
		t.priority := MinPriority
	END;

	NEW(fn);   (* implicit call Heaps.NewRec -> might invoke GC *)

	Machine.Acquire(Machine.Objects);
	t.next := NIL; t.prev := NIL; t.rootedNext := NIL;
	t.waitingOn := NIL; t.flags := flags; t.obj := obj; t.mode := Unknown;
	t.body := body; t.event := 0; fn.finalizer := FinalizeProcess;
	Heaps.AddFinalizer(t, fn);
	IF Restart IN flags THEN  (* restart object body *)
		t.restartPC := SYSTEM.VAL(ADDRESS, body);
	ELSE  (* terminate process *)
		t.restartPC := SYSTEM.VAL(ADDRESS, terminateProc);
	END;

	t.handle := Kernel32.CreateThread(0, defaultStackSize, Wrapper, t, {}, t.id);

	IF TraceVerbose OR TraceOpenClose THEN
		Machine.Acquire(Machine.TraceOutput);
		Trace.String("NewProcess: " ); Trace.Int(t.id, 1); WriteType(obj); Trace.Ln;
		Machine.Release(Machine.TraceOutput);
	END;

	ASSERT(t.handle # 0);
	new := t;
END NewProcess;

(* Create the process associated with an active object (kernel call). *)
PROCEDURE CreateProcess*(body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject);
VAR t : Process; heapBlock {UNTRACED}: Heaps.HeapBlock;
BEGIN
	ASSERT(priority >= 0, 1000); ASSERT(priority <=Realtime, 1001);
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, heapBlock);
	ASSERT(heapBlock IS Heaps.ProtRecBlock); (* protected object *)
	IF Restart IN flags THEN INCL(flags, Resistant) END;   (* SAFE => Restart & Resistant *)
	NewProcess(body, priority, flags, obj, t);  INC(nProcs);  (* acquires Machine.Objects lock *)
	t.mode := Ready; Put(ready, t);
	Machine.Release(Machine.Objects)
END CreateProcess;


(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Lock*(obj: ProtectedObject; exclusive: BOOLEAN );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r: Process; res: LONGINT;
BEGIN  (* {called from user level} *)
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock); (* protected object *)
		ASSERT(exclusive)	(* shared not implemented yet *)
	END;
	r := CurrentProcess();
	IF StrongChecks THEN
		ASSERT(hdr # NIL, 1001);
		ASSERT(r # NIL, 1002);
	END;
	Machine.Acquire(Machine.Objects);
	IF hdr.count = 0 THEN  (* not locked *)
		hdr.count := -1; hdr.lockedBy := r;
		Machine.Release(Machine.Objects)
	ELSE  (* already locked *)
		IF hdr.lockedBy = r THEN
			Machine.Release(Machine.Objects);
			HALT(2203) (* nested locks not allowed *)
		END;
		ASSERT(r.waitingOn = NIL); (* sanity check *)
		Remove(ready, r);
		IF r.event = 0 THEN
			r.event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto *), Kernel32.False, NIL );   (* auto reset event with initial state = reset *)
			ASSERT ( r.event # 0, 1239 );
		END;
		r.waitingOn := obj;  r.mode := AwaitingLock;
		Put(hdr.awaitingLock, r); INC(awl);
		Machine.Release(Machine.Objects);
		res := Kernel32.WaitForSingleObject(r.event, Kernel32.Infinite); (* block execution *)
		ASSERT(res = Kernel32.WaitObject0);
		IF StrongChecks THEN
			ASSERT(hdr.lockedBy = r); (* at this moment only this process can own the lock and only this process can release it*)
		END;
	END
END Lock;

(* Find the first true condition from the queue and remove it. Assume the object is currently locked. *)
PROCEDURE FindCondition( VAR q: ProcessQueue ): Process;
VAR first, cand: Process;
BEGIN
	Get( q, first );
	IF first.condition( first.condFP ) THEN RETURN first END;
	Put( q, first );
	WHILE q.head # first DO
		Get( q, cand );
		IF cand.condition( cand.condFP ) THEN RETURN cand END;
		Put( q, cand )
	END;
	RETURN NIL
END FindCondition;

(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Unlock*( obj: ProtectedObject;  dummy: BOOLEAN );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; t, c: Process; res: LONGINT;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	ASSERT(hdr.count = -1);	(* exclusive locked *)
	Machine.Acquire(Machine.Objects);

	IF hdr.awaitingCond.head # NIL THEN  (* evaluate the waiting conditions *)
		(* we are holding the lock, so the queue can not change (to do: except in TerminateThis) *)
		c := FindCondition(hdr.awaitingCond);   (* interrupts should be on during this call *)
	ELSE
		c := NIL
	END;
	IF c = NIL THEN  (* no true condition found, check the lock queue *)
		Get(hdr.awaitingLock, t);
		IF t # NIL THEN
			hdr.lockedBy := t;
			t.waitingOn := NIL;
		ELSE
			hdr.lockedBy := NIL; hdr.count := 0
		END
	ELSE  (* true condition found, transfer the lock *)
		c.waitingOn := NIL; hdr.lockedBy := c;
		t := NIL
	END;
	IF c # NIL THEN
		Put(ready, c); c.mode := Running; DEC(awc);
		res := Kernel32.SetEvent(c.event);
		ASSERT (res # 0, 1001);
	ELSIF t # NIL THEN
		Put(ready, t); t.mode := Running; DEC(awl);
		res := Kernel32.SetEvent(t.event);
		ASSERT (res # 0, 1002);
	END;
	Machine.Release( Machine.Objects )
END Unlock;

(* The procedure Lock, Unlock and Await do not use header locks since it turned out that the header locks sometimes were finalized
     too early. *)
PROCEDURE Await*( cond: Condition;  slink: LONGINT;  obj: ProtectedObject;  flags: SET );
VAR hdr {UNTRACED}: Heaps.ProtRecBlock; r, c, t: Process;  res: LONGINT;
BEGIN
	IF 1 IN flags THEN  (* compiler did not generate IF *)
		IF cond(slink) THEN
			RETURN  (* condition already true *)
		END
	END;
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, obj) + Heaps.HeapBlockOffset, hdr);
	IF StrongChecks THEN
		ASSERT(hdr IS Heaps.ProtRecBlock) (* protected object *)
	END;
	r := CurrentProcess();
	Machine.Acquire(Machine.Objects);
	IF hdr.lockedBy = r THEN  (* current process holds exclusive lock *)
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
				t.waitingOn := NIL;
				hdr.lockedBy := t;
			END;
		ELSE
			c.waitingOn := NIL; hdr.lockedBy := c;
			t := NIL;
		END;
	ELSE  (* no lock, or some other process may hold the lock, but that's the user's indaba (may be monotonic condition) *)
		Machine.Release(Machine.Objects);
		HALT( 2204 ) (* await must be exclusive region *)
	END;
	r.condition := cond; r.condFP := slink;
	r.waitingOn := obj; r.mode := AwaitingCond;
	Remove(ready, r);
	IF r.event = 0 THEN
		r.event := Kernel32.CreateEvent( NIL, Kernel32.False (* auto *), Kernel32.False, NIL );   (* auto-reset event with initial state = reset *)
		ASSERT ( r.event # 0, 1239 );
	END;
	IF c # NIL THEN
		DEC(awc); Put(ready, c); c.mode := Running;
		res := Kernel32.SetEvent(c.event); (* restart execution *)
		ASSERT(res # 0, 1002);
	END;
	IF t # NIL THEN
		DEC(awl); Put(ready, t);  t.mode := Running;
		res := Kernel32.SetEvent( t.event ); (* restart execution *)
		ASSERT(res # 0, 1003);
	END;
	Put(hdr.awaitingCond, r); INC(awc);
	Machine.Release(Machine.Objects);
	res := Kernel32.WaitForSingleObject(r.event, Kernel32.Infinite); (* block execution *)
	ASSERT(res = Kernel32.WaitObject0);
	IF StrongChecks THEN
		ASSERT(cond(slink));
		ASSERT(hdr.lockedBy = r) (* lock held again *)
	END
END Await;

	PROCEDURE Break*( t: Process );
	CONST MaxTry = 50;
	VAR mod: Modules.Module;  try: LONGINT;  retBOOL: Kernel32.BOOL;   (* Dan 09.11.05 *)

		PROCEDURE SafeForBreak( mod: Modules.Module ): BOOLEAN;
		BEGIN
			Trace.String( "Safe for break?: " );
			IF mod # NIL THEN
				Trace.StringLn ( mod.name );
				IF (mod.name = "Trace") OR (mod.name = "Machine") OR
					(mod.name = "Heaps") OR (mod.name = "Modules") OR
					(mod.name = "Objects") OR (mod.name = "Kernel") THEN
					Trace.StringLn ( " - no" );  RETURN FALSE
				ELSE Trace.StringLn ( " - yes" );  RETURN TRUE
				END
			ELSE Trace.StringLn ( "unknown module" );  RETURN FALSE
			END
		END SafeForBreak;

	BEGIN
		IF CurrentProcess() # t THEN
			Machine.Acquire( Machine.Objects );
			LOOP
				retBOOL := Kernel32.SuspendThread( t.handle );
				t.state.ContextFlags := Kernel32.ContextControl;
				retBOOL := Kernel32.GetThreadContext( t.handle, t.state );
				mod := Modules.ThisModuleByAdr( t.state.PC );  Trace.String( "Objects Break at adr: " );
				Trace.Int( t.state.PC, 5 );  Trace.Ln;
				IF mod # NIL THEN
					Trace.String( "In module: " );  Trace.StringLn ( mod.name );
				END;
				IF ~SafeForBreak( mod ) (* we do not break Kernel modules *) THEN
					retBOOL := Kernel32.ResumeThread( t.handle );  INC( try );
					IF try > MaxTry THEN
						Trace.StringLn ( "Threads.Break: failed " );
						Machine.Release( Machine.Objects );
						RETURN
					END
				ELSE EXIT
				END;
			END;
			(* push cont.Eip *) break[0] := 68X;
			SYSTEM.MOVE( ADDRESSOF( t.state.PC ), ADDRESSOF( break[1] ), 4 );
			(* push ebp *) break[5] := 055X;
			(* mov ebp, esp *) break[6] := 08BX;  break[7] := 0ECX;
			(* push 13 *) break[8] := 06AX;  break[9] := 0DX;
			(* int 3 *) break[10] := 0CCX;
			(* mov esp, ebp *) break[11] := 08BX;  break[12] := 0E5X;
			(* pop ebp *) break[13] := 05DX;
			(* ret *) break[14] := 0C3X;  t.state.PC := ADDRESSOF( break[0] );
			retBOOL := Kernel32.SetThreadContext( t.handle, t.state );
			retBOOL := Kernel32.ResumeThread( t.handle );   (*  INC( Kernel.GClevel ); *)

			Machine.Release( Machine.Objects );
		ELSE HALT( 99 )
		END;

	END Break;

(* Attempt to terminate a specific process (mostly ignoring its locks). DEPRECATED *)
PROCEDURE TerminateThis*( t: Process;  halt: BOOLEAN );
BEGIN
	terminate(t);
END TerminateThis;

PROCEDURE Terminate*;
BEGIN
	TerminateProc();
END Terminate;

PROCEDURE Init;   (* can not use NEW *)
VAR lock: PROCEDURE(obj: ProtectedObject; exclusive: BOOLEAN);
	unlock: PROCEDURE(obj: ProtectedObject; dummy: BOOLEAN);
	await: PROCEDURE(cond: Condition; slink: LONGINT; obj: ProtectedObject; flags: SET);
	create: PROCEDURE(body: Body; priority: LONGINT; flags: SET; obj: ProtectedObject);
VAR t: Process;  fn: Heaps.FinalizerNode;  proc: Kernel32.HANDLE;
	res: Kernel32.BOOL;
BEGIN
	Kernel32.InitializeCriticalSection(excplock);
	numberOfProcessors := Machine.NumberOfProcessors();
	lock := Lock; unlock := Unlock; await := Await; create := CreateProcess;

	Modules.kernelProc[3] := SYSTEM.VAL(LONGINT, create);   (* 250 *)
	Modules.kernelProc[4] := SYSTEM.VAL(LONGINT, await);   (* 249 *)
	Modules.kernelProc[6] := SYSTEM.VAL(LONGINT, lock);   (* 247 *)
	Modules.kernelProc[7] := SYSTEM.VAL(LONGINT, unlock);   (* 246 *)

	NEW(t);  NEW(fn);

	Machine.Acquire(Machine.Objects);
	nProcs := 1;
	t.next := NIL;  t.prev := NIL;
	t.waitingOn := NIL; t.flags := {}; t.obj := NIL;
	t.mode := Unknown; t.body := NIL;
	t.priority := Normal;
	fn.finalizer := FinalizeProcess;

	Heaps.AddFinalizer(t, fn);
	t.handle := Kernel32.GetCurrentThread();
	t.id := Kernel32.GetCurrentThreadId();
	proc := Kernel32.GetCurrentProcess();
	res := Kernel32.DuplicateHandle(proc, t.handle, proc, t.handle, {}, 0, {Kernel32.DuplicateSameAccess});
	ASSERT(res # 0);
	res := Kernel32.TlsSetValue(tlsIndex, SYSTEM.VAL(LONGINT, t));
	ASSERT(res # 0);
	t.stackBottom := StackBottom(); t.mode := Running;
	Put( ready, t );
	ASSERT(t.handle # 0);
	Machine.Release(Machine.Objects);
	InitEventHandling; (* implicit call of NewProcess! *)
	InitGCHandling; (* do. *)
	Heaps.gcStatus := GCStatusFactory()
END Init;

(** Set (or reset) an event handler object's timeout value. *)
PROCEDURE SetTimeout*(t: Timer; h: EventHandler;  ms: LONGINT );
VAR e: Timer;  trigger: LONGINT;
BEGIN
	ASSERT(Machine.Second= 1000); (* assume milliseconds for now *)
	ASSERT((t # NIL) & (h # NIL));
	ASSERT(ms >= 0);
	Machine.Acquire(Machine.Objects);
	trigger := Kernel32.GetTickCount() + ms;   (* ignore overflow *)
	IF t.next # NIL THEN  (* cancel previous timeout *)
		t.next.prev := t.prev;  t.prev.next := t.next
	END;
	t.trigger := trigger;  t.handler := h;
	e := event.next;   (* performance: linear search! *)
	WHILE (e # event) & (e.trigger - trigger <= 0) DO e := e.next END;
	t.prev := e.prev;  e.prev := t;  t.next := e;  t.prev.next := t;
	Machine.Release(Machine.Objects);
	clock.Wakeup()
END SetTimeout;

(** Set (or reset) an event handler object's timeout value. Here ms is absolute *)
PROCEDURE SetTimeoutAt*(t: Timer; h: EventHandler; ms: LONGINT);
VAR e: Timer; trigger: LONGINT;
BEGIN
	ASSERT(Machine.Second= 1000);	(* assume milliseconds for now *)
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
	clock.Wakeup()
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

PROCEDURE InitGCHandling;
BEGIN
	NEW(gcActivity);
	NEW(finalizerCaller);
END InitGCHandling;

PROCEDURE GCStatusFactory(): Heaps.GCStatus;
VAR gcStatusExt : GCStatusExt;
BEGIN
	ASSERT(Heaps.gcStatus = NIL);
	NEW(gcStatusExt);
	RETURN gcStatusExt
END GCStatusFactory;

PROCEDURE InstallExceptionHandler*( e: ExceptionHandler );
BEGIN
	exceptionhandler := e;
END InstallExceptionHandler;

PROCEDURE UpdateProcessState*( p: Process );
VAR res: Kernel32.BOOL;
BEGIN
	res := Kernel32.GetThreadContext( p.handle, p.state );
	ASSERT (p.handle # 0);
END UpdateProcessState;

(*ALEX 2005.12.12 added for WMPerfMon needs*)

PROCEDURE NumReady*( ): LONGINT;
VAR n: LONGINT; p: Heaps.ProcessLink;
BEGIN
	n := 0;
	Machine.Acquire( Machine.Objects );
	p := ready.head;
	WHILE p # NIL DO INC( n );  p := p.next END;
	Machine.Release( Machine.Objects );
	RETURN n
END NumReady;

(** Return number of CPU cycles consumed by the specified process. If all is TRUE,
	return the number of cycles since the process has been created. If FALSE, return the number of cycles
	consumed since the last time asked. *)
PROCEDURE GetCpuCycles*(process : Process; VAR cpuCycles : CpuCyclesArray; all : BOOLEAN);
VAR res : Kernel32.BOOL; temp : HUGEINT; i : LONGINT;
BEGIN
	ASSERT(process # NIL);
	IF (Kernel32.QueryThreadCycleTime # NIL) THEN
		res := Kernel32.QueryThreadCycleTime(process.handle, cpuCycles[0]);
	ELSE
		cpuCycles[0] := Machine.GetTimer(); res := Kernel32.True;
	END;

	IF ~all & (res = Kernel32.True) THEN
		temp := process.lastThreadTimes;
		process.lastThreadTimes := cpuCycles[0];
		cpuCycles[0] := cpuCycles[0] - temp;
	END;
END GetCpuCycles;

PROCEDURE CurrentProcessTime*(): HUGEINT;
VAR res: LONGINT; result: HUGEINT;
BEGIN
	res := Kernel32.QueryThreadCycleTime(CurrentProcess().handle, result);
	RETURN result;
END CurrentProcessTime;

PROCEDURE TimerFrequency*(): HUGEINT;
BEGIN
	RETURN 1000000000;
END TimerFrequency;

BEGIN
	exceptionhandler := NIL;
	terminateProc := TerminateProc;
	ready.head := NIL; ready.tail := NIL;
	tlsIndex := Kernel32.TlsAlloc();
	ASSERT ( tlsIndex # Kernel32.TLSOutOfIndexes );
	Kernel32.SendToDebugger("Modules.root", ADDRESSOF(Modules.root));
	Init
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

