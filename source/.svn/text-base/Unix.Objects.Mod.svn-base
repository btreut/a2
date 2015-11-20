(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Objects;   (** AUTHOR "pjm, G.F."; PURPOSE "Active object runtime support"; *)


IMPORT S := SYSTEM, Trace, Glue, Unix, Machine, Heaps, Modules;

CONST

	(*! Process flags, meaningless in Unix ports !!! *)
	PleaseHalt* = 10;		(* Process requested to Halt itself soon *)
	Unbreakable*= 11;		(* FINALLY shall not catch HALT exception (PleaseHalt is also set) *)
	SelfTermination*=12;	(* Indicates the process has requested to terminate ifself (PleaseHalt is also set) *)
	Preempted* = 27;		(* Has been preempted. *)
	Resistant* = 28;		(* Can only be destroyed by itself *)


	MinPriority*	= Unix.ThreadLow;
	Low*			= Unix.ThreadLow + 1;
	Normal*		= Unix.ThreadNormal;
	High*			= Unix.ThreadHigh - 2;
	GCPriority*	= Unix.ThreadHigh - 1;
	Realtime*	= Unix.ThreadHigh;

	(* Process flag defined by compiler in OPC.CallRecBody *)
	Restart* = 0;	(* Restart/Destroy process on exception *)

	(* Process modes (in UnixAos Running means Running or Ready!) *)
	Unknown* = 0;  Ready* = 1;  Running* = 2;  AwaitingLock* = 3;
	AwaitingCond* = 4;  AwaitingEvent* = 5;  Terminated* = 6;

	Second* = 1000;	(* frequency of ticks increments in Hz *)

	DefaultStacksize = 128*1024;
	
	AddrSize = SIZEOF( ADDRESS )


VAR
	(* timer *)
	timerActivity		: TimerActivity;
	timers				: Timer;  
	timerListMutex	: Unix.Mutex_t;
	
	(* processes *)
	mainProcess	: Process;	(* runs the GC *)
	root-	: Process;	(*!  Anchor of all instantiated threads in system *)
	stacksize: LONGINT;		(* stack size of active objects, adjustable via boot parameter *)
	
	processList		: Unix.Mutex_t;
	createProcess	: Unix.Mutex_t;
	startProcess	: Unix.Mutex_t;
	childrunning		: Unix.Condition_t;
		
	newProcess: Process;
	nextPID: LONGINT;
	
	(* garbage colletion *)
	gcFinished: Unix.Condition_t; igc: Unix.Mutex_t;
	collect: BOOLEAN;
	finalizerCaller	: FinalizerCaller;
	finCaller			: Process;
	
	
	(* the dummy parameters assure proper stack alignment when compiled with 
		option "\A" or "--darwinHost" *)
	mtxInit: 		PROCEDURE {REALTIME, C}  ( dummy: LONGINT ): Unix.Mutex_t;
	mtxDestroy: 	PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );
	mtxLock: 		PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );
	mtxUnlock:	PROCEDURE {REALTIME, C}  ( mtx: Unix.Mutex_t );

	conInit: 		PROCEDURE {REALTIME, C}  ( dummy: LONGINT ): Unix.Condition_t;
	conDestroy:	PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t );
	conWait: 		PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t;  mtx: Unix.Mutex_t );
	conSignal: 	PROCEDURE {REALTIME, C}  ( cond: Unix.Condition_t );
	
	thrStart: 			PROCEDURE {REALTIME, C} ( p: PROCEDURE;  stackLen: LONGINT ): Unix.Thread_t;
	thrThis: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT ): Unix.Thread_t;
	thrSleep: 			PROCEDURE {REALTIME, C} ( ms: LONGINT );
	thrYield: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT );
	thrExit: 			PROCEDURE {REALTIME, C} ( dummy: LONGINT );
	thrSuspend: 		PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	thrResume: 		PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	thrSetPriority: 	PROCEDURE {REALTIME, C} ( t: Unix.Thread_t;  prio: LONGINT );
	thrGetPriority: 	PROCEDURE {REALTIME, C} ( t: Unix.Thread_t ): LONGINT;
	thrKill: 			PROCEDURE {REALTIME, C} ( t: Unix.Thread_t );
	
	

TYPE

	CpuCyclesArray* = ARRAY Machine.MaxCPU OF HUGEINT;

	ProtectedObject = POINTER TO RECORD END;

	ObjectHeader = Heaps.ProtRecBlock;

	ProcessQueue = Heaps.ProcessQueue;

	EventHandler* = PROCEDURE  {DELEGATE};



	Timer* =  OBJECT
	VAR
		next: Timer;
		trigger: LONGINT;
		handler: EventHandler
	END Timer;
			
	TimerActivity = OBJECT		
	VAR 
		t, r: Timer;  h: EventHandler;  restart: BOOLEAN;
		
		PROCEDURE UpdateTicks;
		BEGIN {EXCLUSIVE}
			Machine.UpdateTicks
		END UpdateTicks;
		
		PROCEDURE Restart;
		BEGIN {EXCLUSIVE}
			restart := TRUE
		END Restart;
		
	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		restart := FALSE;
		LOOP
			t := timers;
			IF t # NIL THEN				
				h := NIL;  r := NIL;
				BEGIN {EXCLUSIVE}
					AWAIT( (Machine.ticks >= t.trigger) OR restart );  restart := FALSE;
					IF Machine.ticks >= t.trigger THEN
						h := t.handler;  r := t
					END
				END;
				IF r # NIL THEN  Remove( r )  END;
				IF h # NIL THEN  (* not canceled *) h  END
			ELSE				
				BEGIN{EXCLUSIVE}
					AWAIT( restart );  restart := FALSE;
				END
			END
		END
	END TimerActivity;



	FinalizedCollection* = OBJECT (* base type for collection, extended in Kernel.Mod *)
		PROCEDURE RemoveAll*(obj: ANY); (** abstract *)
		BEGIN HALT(301) END RemoveAll;
	END FinalizedCollection;

	FinalizerNode* = POINTER TO RECORD (Heaps.FinalizerNode)
		c*: FinalizedCollection (* base type for collection containing object *)
	END;

		
	FinalizerCaller = OBJECT	(* separate active object that calls finalizers *)
	VAR 
		n: Heaps.FinalizerNode;  start: BOOLEAN;
	
		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			start := TRUE
		END Start;
		
	BEGIN {ACTIVE, SAFE, PRIORITY(High)}
		finCaller := CurrentProcess( );  start := FALSE;
		LOOP 
			BEGIN {EXCLUSIVE} AWAIT( start ) END;
			start := FALSE;
			LOOP
				n := Heaps.GetFinalizer();
				IF n = NIL THEN EXIT END;
				IF n IS FinalizerNode THEN
					n(FinalizerNode).c.RemoveAll(n.objStrong)	(* remove it if it is not removed yet *)
				END;
				IF n.finalizer # NIL THEN
					n.finalizer(n.objStrong)	(* may acquire locks *)
				END;
			END;
			Machine.Release( Machine.GC )
		END
	END FinalizerCaller;
	


	Body = PROCEDURE ( self: ProtectedObject );
	Condition = PROCEDURE ( slink: ADDRESS ): BOOLEAN;
	
	Process* = OBJECT (Heaps.RootObject)
	VAR
		threadId			: Unix.Thread_t;
		nextProcess-	: Process;	(* next in list of all processes *)
		stackBottom	-	: ADDRESS;
		SP-				: ADDRESS;	(* SP value at last NEW *)
		id-				: LONGINT;
		body			: Body;
		mode-		: LONGINT;
		flags-			: SET;
		priority-		: LONGINT;	(* only effective if Aos is running SUID root *)
		succ			: Process;   		  	(* in ProcessQueue *)
		obj-			: ProtectedObject;	(* associated active object *)
		condition-	: Condition;   			(* awaited process' condition *)
		condFP-		: ADDRESS;			(* awaited process' condition's context *)
		continue		: Unix.Condition_t;	(* gets signaled when condition yields true *)
		waitingOn-	: ProtectedObject;
		procID-		: LONGINT;				(* processor ID where running, not used in UnixAos *)
		state-			: Machine.State;		(*! not used in UnixAos! *)
		state0	: ARRAY 2048 OF CHAR;		(* thread state at body start, used for restart after trap *)
					
				
		PROCEDURE FindRoots*;
		VAR sp, ptr: ADDRESS;
		BEGIN
			IF mode # Terminated THEN
				sp := SP;
				WHILE sp < stackBottom DO  
					S.GET( sp, ptr );  
					IF (ptr # 0) & (ptr MOD 8 = 0) THEN  Heaps.AddCandidate( ptr )  END;  
					INC( sp, AddrSize )  
				END;
			END;
			Heaps.Mark( nextProcess ) 
		END FindRoots;
				
		PROCEDURE Cancel;
		VAR pt, t: Process;  kt: Unix.Thread_t;
		BEGIN
			IF SELF = CurrentProcess() THEN  Exit
			ELSE
				Machine.Acquire( Machine.X11 );  (* let the thread to be killed first finish its last I/O, if any *)
				mtxLock( processList );
					pt := NIL; t := root;  kt := 0;
					WHILE (t # NIL ) & (t # SELF) DO  pt := t;  t := t.nextProcess  END;
					IF t = SELF THEN
						kt := threadId;
						IF pt = NIL THEN  root := t.nextProcess  ELSE  pt.nextProcess := t.nextProcess  END;
					END;
				mtxUnlock( processList );
				IF kt # 0 THEN  thrKill( kt )  END;
				Machine.Release( Machine.X11 );
			END
		END Cancel;

		PROCEDURE GetPriority( ): LONGINT;
		BEGIN
			RETURN thrGetPriority( threadId ) 
		END GetPriority;

		PROCEDURE SetPriority( prio: LONGINT );
		VAR pr: LONGINT;
		BEGIN
			pr := max( Machine.prioLow, min( prio, Machine.prioHigh ) );
			thrSetPriority( threadId, pr );	(* works only if SUID root *)
			priority := GetPriority( )	
		END SetPriority;
				
				
		PROCEDURE & Initialize( obj: ProtectedObject;  bodyProc: Body;  prio: LONGINT; fl: SET; stacksize: LONGINT);
		VAR  thr: Unix.Thread_t;
		BEGIN
			SELF.obj := obj;  condition := NIL;  continue := conInit(0);
			flags := fl;
			priority := prio;
			nextProcess := NIL;
			IF root # NIL THEN
				newProcess := SELF;
				ASSERT( bodyProc # NIL );
				body := bodyProc;  
				mtxLock( startProcess );
					thr := thrStart( BodyStarter, stacksize );
					conWait( childrunning, startProcess );
				mtxUnlock( startProcess );
				RegisterFinalizer( SELF, FinalizeProcess );
			ELSE 
				(* first process *)
				stackBottom := Glue.stackBottom;  
				SP := Machine.CurrentSP( );
				threadId := thrThis(0);
				id := 0;  nextPID := 1;
				root := SELF;
				mainProcess := SELF;
				mode := Running;
			END;
		END Initialize;
				
	END Process;


	
	PROCEDURE BodyStarter;
	VAR p{UNTRACED}: Process;  res: LONGINT; prevBP: ADDRESS;
	BEGIN
		mtxLock( startProcess );
			p := newProcess;  newProcess := NIL;
			p.threadId := thrThis(0);  
			p.id := nextPID;  INC( nextPID );
			p.SP := Machine.CurrentSP(  );  
			p.stackBottom := Machine.CurrentBP( );
			S.GET( p.stackBottom, prevBP );
			S.PUT( prevBP, S.VAL( ADDRESS, 0 ) );	(* for terminating Reflection.StackTraceBack *)
			mtxLock( processList );
				p.nextProcess := root;  root := p;
			mtxUnlock( processList );
			conSignal( childrunning );
		mtxUnlock( startProcess );

		p.SetPriority( p.priority );
		IF Restart IN p.flags THEN
			res := Unix.sigsetjmp( ADDRESSOF( p.state0[0] ), 1 );
		END;
		p.mode := Running;
		p.body( p.obj );
		p.mode := Terminated;
		Exit
	END BodyStarter;




	(*---------------------   create,  lock,  await,  unlock   -------------------------*)
	
	PROCEDURE InitProtHeader( hdr: ObjectHeader );
	BEGIN
		hdr.mtx := mtxInit( 0 );  hdr.enter := conInit( 0 );  hdr.lockedBy := NIL;  
	END InitProtHeader;
	
	
	PROCEDURE CreateProcess*( body: Body;  priority: LONGINT;  flags: SET;  obj: ProtectedObject );
	VAR p: Process;  hdr: ObjectHeader;
	BEGIN
		mtxLock( createProcess );
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  InitProtHeader( hdr );
		IF priority = 0 THEN  priority := Normal  END;
		NEW( p, obj, body, priority, flags, stacksize ) ;	(* execute BodyStarter as new (posix or solaris) thread *)
		mtxUnlock( createProcess );
		RegisterFinalizer( obj, FinalizeActiveObj )
	END CreateProcess;

	PROCEDURE Lock*( obj: ProtectedObject;  exclusive: BOOLEAN );
	VAR hdr: ObjectHeader;  p: Process; 
	BEGIN
		ASSERT( exclusive );   (* shared not implemented yet *)
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		p := CurrentProcess();
		p.mode := AwaitingLock;
		IF hdr.mtx = 0 THEN  InitProtHeader( hdr )  END;
		mtxLock( hdr.mtx );
		WHILE hdr.lockedBy # NIL DO
			(* wait until threads with complied AWAIT conditions have left the monitor *)
			conWait( hdr.enter, hdr.mtx );
		END;
		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Lock;

	PROCEDURE Await*( cond: Condition;  slink: ADDRESS;  obj: ProtectedObject;  flags: SET );
	VAR hdr: ObjectHeader;  p, c: Process;
	BEGIN
		IF 1 IN flags THEN  (* compiler did not generate IF *)
			IF cond( slink ) THEN  (* condition already true *)  RETURN  END
		END;
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;
		
		p := CurrentProcess();  p.succ := NIL;  p.condition := cond;  p.condFP := slink;   
		p.waitingOn := obj;  p.mode := AwaitingCond;
		
		Put( hdr.awaitingCond, p );
		
		hdr.lockedBy := c;
		IF c # NIL THEN  conSignal( c.continue )  ELSE  conSignal( hdr.enter )  END;
		conWait( p.continue, hdr.mtx );   
		
		p.mode := Running;  hdr.lockedBy := p;  p.waitingOn := NIL
	END Await;

	PROCEDURE Unlock*( obj: ProtectedObject;  dummy: BOOLEAN );
	VAR hdr: ObjectHeader;  c: Process;
	BEGIN
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );  c := NIL;
		IF hdr.awaitingCond.head # NIL THEN  c := FindCondition( hdr.awaitingCond )  END;
		
		hdr.lockedBy := c;
		IF c # NIL THEN  conSignal( c.continue )  ELSE  conSignal( hdr.enter )  END;
		mtxUnlock( hdr.mtx );
	END Unlock;
	
	
	
	PROCEDURE FindCondition( VAR q: ProcessQueue ): Process;
	VAR first, cand: Process;
	BEGIN
		Get( q, first );
		IF first.condition( first.condFP ) THEN  RETURN first  ELSE  Put( q, first )  END;
		WHILE q.head # first DO
			Get( q, cand );
			IF cand.condition( cand.condFP ) THEN  RETURN cand  ELSE  Put( q, cand )  END;
		END;
		RETURN NIL
	END FindCondition;

	PROCEDURE Get( VAR queue: ProcessQueue;  VAR new: Process );
	VAR t: Process;
	BEGIN
		t := queue.head(Process);
		IF t # NIL THEN
			IF t = queue.tail THEN  queue.head := NIL;  queue.tail := NIL
			ELSE  queue.head := t.succ;  t.succ := NIL
			END
		END;
		new := t
	END Get;

	PROCEDURE Put( VAR queue: ProcessQueue;  t: Process );
	BEGIN
		IF queue.head = NIL THEN  queue.head := t  ELSE  queue.tail(Process).succ := t  END;
		queue.tail := t
	END Put;
	
	
	
	(*-------------------------------------------------------------------------*)
	
	PROCEDURE Terminate*;
	BEGIN
		Exit
	END Terminate;

	PROCEDURE TerminateThis*( p: Process; unbreakable: BOOLEAN );
	BEGIN
		p.mode := Terminated;
		p.Cancel
	END TerminateThis;
	
	PROCEDURE SetPriority*( pri: LONGINT );		(* Set the current process' priority. *)
	VAR me: Process;
	BEGIN
		me := CurrentProcess();
		me.SetPriority( pri )
	END SetPriority;

	PROCEDURE Sleep*( ms: LONGINT );
	BEGIN
		thrSleep( ms )
	END Sleep;

	PROCEDURE Yield*;	(* Relinquish control. *)
	BEGIN
		thrYield(0);
	END Yield;
	
	(* Return current process. (DEPRECATED, use ActiveObject) *)
	PROCEDURE CurrentProcess*( ): Process;	
	VAR me: Unix.Thread_t;  p: Process;
	BEGIN
		me := thrThis(0);
		mtxLock( processList );
		p := root;
		WHILE (p # NIL) & (p.threadId # me) DO  p := p.nextProcess  END;
		mtxUnlock( processList );
		RETURN p
	END CurrentProcess;

	
	(* Return the active object currently executing. *)
	PROCEDURE ActiveObject*( ): ANY;		
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		RETURN p.obj 
	END ActiveObject;
	
	
	(* Return stack bottom of process. For compatibility WinAos/UnixAos/NativeAos  *)
	PROCEDURE GetStackBottom*(p: Process): ADDRESS;
	BEGIN
		RETURN p.stackBottom
	END GetStackBottom;


	PROCEDURE GetProcessID*( ): LONGINT;
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		RETURN p.id;
	END GetProcessID;

	
	PROCEDURE GetCpuCycles*( process : Process; VAR cpuCycles: CpuCyclesArray; all: BOOLEAN );
	VAR i: LONGINT;
	BEGIN
		ASSERT( process # NIL );
		FOR i := 0 TO Machine.MaxCPU-1 DO  cpuCycles[i] := 0  END;
	END GetCpuCycles;
	
	
	
	(*-----------------------------------------------------------------------*)
	
	
	PROCEDURE min( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a <= b THEN  RETURN a  ELSE  RETURN b  END
	END min;

	PROCEDURE max( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a >= b THEN  RETURN a  ELSE  RETURN b  END
	END max;
	
	
	PROCEDURE RegisterFinalizer( obj: ANY;  fin: Heaps.Finalizer );
	VAR n: Heaps.FinalizerNode;
	BEGIN
		NEW( n ); n.finalizer := fin;  Heaps.AddFinalizer( obj, n );
	END RegisterFinalizer;


	PROCEDURE FinalizeActiveObj( obj: ANY );
	VAR p: Process;
	BEGIN
		mtxLock( processList );
			p := root;
			WHILE (p # NIL) & (p.obj # obj) DO p := p.nextProcess  END;
		mtxUnlock( processList );
		IF (p # NIL) & (p.obj = obj) THEN
			p.mode := Terminated;
			conDestroy( p.continue );  p.continue := 0;
			FinalizeProtObject( obj );
			p.Cancel
		END;
	END FinalizeActiveObj;

	PROCEDURE FinalizeProtObject( obj: ANY );
	VAR hdr: ObjectHeader;
	BEGIN
		S.GET( S.VAL( ADDRESS, obj ) + Heaps.HeapBlockOffset, hdr );
		IF hdr.mtx # 0 THEN
			mtxDestroy( hdr.mtx );  hdr.mtx := 0
		END
	END FinalizeProtObject;


	PROCEDURE FinalizeProcess( obj: ANY );
	VAR p: Process;
	BEGIN
		p := obj(Process);
		IF p.continue # 0 THEN
			conDestroy( p.continue );  p.continue := 0
		END
	END FinalizeProcess;
	
	(* Terminate calling thread. *)
	PROCEDURE Exit;
	VAR prev, p, me: Process;
	BEGIN
		me := CurrentProcess();
		me.mode := Terminated;
		mtxLock( processList );
			prev := NIL;  p := root;
			WHILE (p # NIL ) & (p # me) DO  prev := p;  p := p.nextProcess  END;
			IF p = me THEN
				IF prev = NIL THEN  root := p.nextProcess  ELSE  prev.nextProcess := p.nextProcess  END;
			END;
		mtxUnlock( processList );
		thrExit(0)
	END Exit;

	PROCEDURE ExitTrap*;
	VAR p: Process;
	BEGIN
		p := CurrentProcess();
		(* restart the object body if it was given the SAFE flag *)
		IF Restart IN p.flags THEN
			Unix.siglongjmp( ADDRESSOF( p.state0[0] ), 1 )
		END;
		Exit
	END ExitTrap;




	(*---------------------------- Timer --------------------------------*)


	PROCEDURE Remove( t: Timer );  (* remove timer from list of active timers *)
	VAR p, x: Timer;
	BEGIN
		mtxLock( timerListMutex ); 
		t.trigger := 0;  t.handler := NIL;
		IF timers # NIL THEN
			IF t = timers THEN  
				timers := t.next
			ELSE
				p := timers;  x := p.next;
				WHILE (x # NIL) & (x # t)  DO  p := x;  x := p.next  END;
				IF x = t THEN  p.next := t.next  END
			END;
			t.next := NIL
		END;
		mtxUnlock( timerListMutex )
	END Remove;
	
	PROCEDURE Insert( t: Timer );
	VAR  p, x: Timer;
	BEGIN
		mtxLock( timerListMutex ); 
		p := NIL;  x := timers;
		WHILE (x # NIL) & (x.trigger < t.trigger)  DO  p := x;  x := p.next  END;
		t.next := x;
		IF p = NIL THEN  timers := t  ELSE   p.next := t  END;
		mtxUnlock( timerListMutex )
	END Insert;

	PROCEDURE SetTimeout*( t: Timer;  h: EventHandler;  ms: LONGINT );
	BEGIN
		ASSERT( ( t # NIL) & ( h # NIL) );
		Remove( t );  
		IF ms < 1 THEN ms := 1 END;
		t.trigger := Machine.ticks + ms;  t.handler := h;
		Insert( t );
		timerActivity.Restart
	END SetTimeout;

	PROCEDURE SetTimeoutAt*( t: Timer;  h: EventHandler;  ms: LONGINT );
	BEGIN
		ASSERT( (t # NIL) & (h # NIL) );
		Remove( t );
		t.trigger := ms;  t.handler := h;
		Insert( t );
		timerActivity.Restart
	END SetTimeoutAt;

	PROCEDURE CancelTimeout*( t: Timer );
	BEGIN
		Remove( t )
	END CancelTimeout;



	(*--------------------  Garbage Collection  ------------------------------------*)
	
	PROCEDURE SuspendActivities;
	VAR t: Process;  
	BEGIN
		t := root;
		WHILE t # NIL DO
			IF (t # mainProcess) & (t # finCaller) THEN  thrSuspend( t.threadId )  END;
			t := t.nextProcess
		END;
	END SuspendActivities;

	PROCEDURE ResumeActivities;
	VAR t: Process;  
	BEGIN
		t := root;
		WHILE t # NIL DO
			IF (t # mainProcess) & (t # finCaller) THEN  thrResume( t.threadId )  END;
			t := t.nextProcess
		END;
	END ResumeActivities;
	

	PROCEDURE SaveSP;   (* save current SP for usage by the GC *)
	VAR me: Unix.Thread_t;  t: Process;
	BEGIN
		me := thrThis(0);  t := root;
		WHILE (t # NIL ) & (t.threadId # me) DO  t := t.nextProcess  END;
		IF t # NIL THEN  t.SP := Machine.CurrentSP( )  END
	END SaveSP;
		
	
	PROCEDURE InvokeGC;
	BEGIN
		Machine.Acquire( Machine.GC ); (* gets released by FinalizerCaller *)
		collect := TRUE;
		conWait( gcFinished, igc );
	END InvokeGC;
	
	(*!	GCLoop gets called as last procedure in BootConsole (main thread). 
		The stack of the main thread is not limited by the  boot parameter 'StackSize' !!
	*)
	PROCEDURE GCLoop*;	(* Timer and GC activity *)
	BEGIN
		LOOP
			IF collect THEN  
				collect := FALSE;
				Machine.Acquire( Machine.Heaps );
				SuspendActivities;
				Heaps.CollectGarbage( Modules.root );
				Machine.Release( Machine.Heaps );
				ResumeActivities;
				finalizerCaller.Start;
				conSignal( gcFinished );
			ELSE
				thrSleep( 10 ); 
			END;
			timerActivity.UpdateTicks
		END
	END GCLoop;	
	
	
	
	PROCEDURE CurrentProcessTime*(): HUGEINT;
	BEGIN
		RETURN  Machine.GetTimer()
	END CurrentProcessTime;
	
	PROCEDURE TimerFrequency*(): HUGEINT;
	BEGIN
		RETURN Machine.mhz * 1000000
	END TimerFrequency;

	
	(*----------------------------- initialization ----------------------------------*)
	
	PROCEDURE StartTimerActivity;
	BEGIN
		timerListMutex := mtxInit(0);  timers := NIL;  
		NEW( timerActivity );
	END StartTimerActivity;


	PROCEDURE GetStacksize;
	VAR str: ARRAY  32 OF  CHAR;  i: LONGINT;
	BEGIN
		Machine.GetConfig( "StackSize", str );
		IF str = "" THEN  stacksize := DefaultStacksize
		ELSE
			i := 0;  stacksize := Machine.StrToInt( i, str );
			stacksize := stacksize * 1024;
		END;
		IF Glue.debug # {} THEN
			Trace.String( "Stacksize of active objects = " );
			Trace.Int( stacksize DIV 1024, 0 );  Trace.StringLn( "K"  )
		END;
	END GetStacksize;

	
	PROCEDURE Convert;
	VAR p: Process;
	BEGIN
		(* make current thread the first active object  *)
		NEW( p, NIL, NIL, 0, {}, 0 );
	END Convert;

	PROCEDURE Init;
	BEGIN
		Modules.kernelProc[0] := ADDRESSOF( Heaps.NewRec );
		Modules.kernelProc[1] := ADDRESSOF( Heaps.NewSys );
		Modules.kernelProc[2] := ADDRESSOF( Heaps.NewArr );
		Modules.kernelProc[3] := ADDRESSOF( CreateProcess );	(* 250 *)
		Modules.kernelProc[4] := ADDRESSOF( Await);				(* 249 *)
		Modules.kernelProc[6] := ADDRESSOF( Lock);				(* 247 *)
		Modules.kernelProc[7] := ADDRESSOF( Unlock);			(* 246 *)
		Modules.kernelProc[10] := ADDRESSOF( Modules.GetProcedure );
		
		Unix.Dlsym( 0, "mtxInit",		ADDRESSOF( mtxInit ) );
		Unix.Dlsym( 0, "mtxDestroy",	ADDRESSOF( mtxDestroy ) );
		Unix.Dlsym( 0, "mtxLock",		ADDRESSOF( mtxLock ) );
		Unix.Dlsym( 0, "mtxUnlock",	ADDRESSOF( mtxUnlock ) );
		Unix.Dlsym( 0, "conInit",		ADDRESSOF( conInit ) );
		Unix.Dlsym( 0, "conDestroy",	ADDRESSOF( conDestroy ) );
		Unix.Dlsym( 0, "conWait",		ADDRESSOF( conWait ) );
		Unix.Dlsym( 0, "conSignal",	ADDRESSOF( conSignal ) );
		
		Unix.Dlsym( 0, "thrStart",	ADDRESSOF( thrStart ) );
		Unix.Dlsym( 0, "thrThis",		ADDRESSOF( thrThis ) );
		Unix.Dlsym( 0, "thrSleep",	ADDRESSOF( thrSleep ) );
		Unix.Dlsym( 0, "thrYield",	ADDRESSOF( thrYield ) );
		Unix.Dlsym( 0, "thrExit",		ADDRESSOF( thrExit ) );
		Unix.Dlsym( 0, "thrSuspend",			ADDRESSOF( thrSuspend ) );
		Unix.Dlsym( 0, "thrResume",			ADDRESSOF( thrResume ) );
		Unix.Dlsym( 0, "thrGetPriority",	ADDRESSOF( thrGetPriority ) );
		Unix.Dlsym( 0, "thrSetPriority",	ADDRESSOF( thrSetPriority ) );
		Unix.Dlsym( 0, "thrKill",				ADDRESSOF( thrKill ) );
		
		createProcess := mtxInit( 0 );  processList := mtxInit( 0 );
		startProcess := mtxInit(0);  childrunning := conInit(0); 
				
		collect := FALSE;
		igc := mtxInit( 0 );  gcFinished := conInit( 0 ); 
							
		GetStacksize;  
		
		Convert;
		StartTimerActivity;
		
		NEW( finalizerCaller );
		
		Heaps.saveSP := SaveSP;
		Heaps.GC := InvokeGC;
		Heaps.InvokeGC := InvokeGC;
	END Init;

BEGIN
	Init;
END Objects.

