(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Threads;   (** non-portable / source: Win32.Threads.Mod *)  (* ejz, *)

IMPORT SYSTEM, Kernel32, AosKernel := Kernel, Kernel := Heaps;
CONST
		Infinite* = Kernel32.Infinite;   (** see Wait *)
(*
CONST
	(** Priority levels used by GetPriority & SetPriority *)
	Low* = Kernel32.ThreadPriorityBelowNormal;  Normal* = Kernel32.ThreadPriorityNormal;
	High* = Kernel32.ThreadPriorityAboveNormal;
	Infinite* = Kernel32.Infinite;   (** see Wait *)
	unknown* = 0;  ready* = 1;  running* = 2;  suspended* = 3;  killed* = 4;  ended* = 5;

TYPE
	(** Thread descriptor, used to store thread information. *)
	BodyProc* = Modules.CommandProc;   (** Thread body procedure. *)
	Thread* = POINTER TO RECORD (Kernel32.Object)
		id, prio, GCCount: LONGINT;
		stackBottom*: ADDRESS;
		name*: ARRAY 64 OF CHAR;   (** Name of thread. *)
		proc: BodyProc;
		next: Thread;
		cont: Kernel32.Context;
		atomic, first: BOOLEAN;
		atomiccnt: LONGINT;
		safe*: BOOLEAN (** Restart the thread after a trap. *) ;
		aux*: ANY;   (* auxiliary variable, may be used by ActiveObjects , needed ? *)
		state-: LONGINT;   (* unknown*=0; ready*=1; running*=2;suspended*=3;ended*=4;  *)
	END;

	RegThread = POINTER TO RECORD (Thread)
		refCount: LONGINT
	END;

	(** Threads enumerator *)
	EnumProc* = PROCEDURE ( t: Thread );
*)
TYPE

	(** Base type for critical section objects. *)
	Mutex* = POINTER TO RECORD
		cs: Kernel32.CriticalSection;
		next{UNTRACED} : Mutex;
		id, count-: LONGINT
	END;

	(** Base type for events *)
	Event* = POINTER TO RECORD (Kernel32.Object) END;
	Finalizer* = Kernel.Finalizer;

VAR
	(* threads, aliens, startup: Thread;  *) mtxs: Mutex;
	(*
	oberonLoop*: Thread;   (** thread executing Oberon.Loop *)

	threaded: BOOLEAN;

	*)
	finalizers: AosKernel.FinalizedCollection;

	moduleCS: Kernel32.CriticalSection;  retBOOL: Kernel32.BOOL;

	(** Wait for ownership of the mutex. *)
	PROCEDURE Lock*( mtx: Mutex );
	BEGIN
		IF mtx = NIL THEN HALT( 10025 ) END;
		Kernel32.EnterCriticalSection( mtx.cs );
		IF mtx.count <= 0 THEN mtx.id := Kernel32.GetCurrentThreadId() END;
		INC( mtx.count )
	END Lock;

(** Release ownership of the mutex. *)
	PROCEDURE Unlock*( mtx: Mutex );
	BEGIN
		(* ASSERT ( threaded );  *)
		DEC( mtx.count );
		IF mtx.count <= 0 THEN mtx.id := 0 END;
		Kernel32.LeaveCriticalSection( mtx.cs )
	END Unlock;

(** Try to take ownership of the mutex without blocking. *)
	PROCEDURE TryLock*( mtx: Mutex ): BOOLEAN;
	VAR id: LONGINT;  ret: Kernel32.BOOL;
	BEGIN
		IF Kernel32.TryEnterCriticalSection # NIL THEN
			ret := Kernel32.TryEnterCriticalSection( mtx.cs );
			IF ret = Kernel32.False THEN RETURN FALSE END
		ELSE
			id := Kernel32.GetCurrentThreadId();
			IF (mtx.count > 0) & (mtx.id # id) THEN RETURN FALSE ELSE Kernel32.EnterCriticalSection( mtx.cs ) END
		END;
		IF mtx.count <= 0 THEN mtx.id := Kernel32.GetCurrentThreadId() END;
		INC( mtx.count );  RETURN TRUE
	END TryLock;


	PROCEDURE FinalizeMutex( mtx: ANY );
	VAR mx: Mutex;
	BEGIN
		WITH mtx: Mutex DO
			mx := mtxs;
			WHILE (mx # NIL ) & (mx.next # mtx) DO mx := mx.next END;
			IF mx # NIL THEN mx.next := mtx.next
			ELSIF mtx = mtxs THEN mtxs := mtx.next
			ELSE HALT( 99 )
			END;
			Kernel32.DeleteCriticalSection( mtx.cs )
		END
	END FinalizeMutex;

(** Initialize a new mutex. *)
	PROCEDURE Init*( mtx: Mutex );
	VAR mx: Mutex;
	BEGIN
		mx := mtxs;
		WHILE (mx # NIL ) & (mx # mtx) DO mx := mx.next END;
		IF mx = NIL THEN
			Kernel32.EnterCriticalSection( moduleCS );  mtx.next := mtxs;  mtxs := mtx;
			Kernel32.LeaveCriticalSection( moduleCS );  mtx.id := 0;  mtx.count := 0;
			Kernel32.InitializeCriticalSection( mtx.cs );   finalizers.Add(mtx,FinalizeMutex);  (* Kernel.RegisterObject( mtx, FinalizeMutex, TRUE ) *)
		ELSE HALT( 99 )
		END
	END Init;

(** Set an event *)
	PROCEDURE Set*( event: Event );
	BEGIN
		retBOOL :=Kernel32.SetEvent( event.handle )
	END Set;

(** Reset an event *)
	PROCEDURE Reset*( event: Event );
	BEGIN
		retBOOL :=Kernel32.ResetEvent( event.handle )
	END Reset;

	PROCEDURE FinalizeEvent( event: ANY );
	BEGIN
		WITH event: Event DO
			IF event.handle # Kernel32.InvalidHandleValue THEN
				retBOOL :=Kernel32.CloseHandle( event.handle );  event.handle := Kernel32.InvalidHandleValue
			END
		END
	END FinalizeEvent;



(** Initialize a new event *)
	PROCEDURE Create*( event: Event );
	BEGIN
		event.handle := Kernel32.CreateEvent( NIL , Kernel32.False, Kernel32.False, NIL );  finalizers.Add(event,FinalizeEvent);
		(* Kernel.RegisterObject( event, FinalizeEvent, TRUE )*)
	END Create;

	PROCEDURE CreateManualReset*( event: Event );
	BEGIN
		event.handle := Kernel32.CreateEvent( NIL , Kernel32.True, Kernel32.False, NIL );
		(* Kernel.RegisterObject( event, FinalizeEvent, TRUE )*)
	END CreateManualReset;


(** Wait for an event or kernel object to be signaled for at most timeOut milliseconds. *)
	PROCEDURE Wait*( event: Kernel32.Object;  timeOut: LONGINT ): BOOLEAN;
	BEGIN
		RETURN Kernel32.WaitForSingleObject( event.handle, timeOut ) # Kernel32.WaitTimeout
	END Wait;

	(*

	PROCEDURE this( ): Thread;
	VAR id: LONGINT;  t: Thread;
	BEGIN
		id := Kernel32.GetCurrentThreadId();
		(* KernelLog.String("Current thread reports id: "); KernelLog.Int(id,1); KernelLog.Ln; *)
		t := threads;
		WHILE (t # NIL ) & (t.id # id) DO t := t.next END;
		RETURN t
	END this;

(** Get the current thread beeing processed. *)
	PROCEDURE This*( ): Thread;
	VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  t := this();
		IF Machine.debug THEN
			(*
	IF t = NIL THEN KernelLog.String("Threads: reports = NIL");  KernelLog.Ln ELSE KernelLog.String("Threads: reports # NIL");  KernelLog.Ln END;
	*)
		END;
		Kernel32.LeaveCriticalSection( moduleCS );  RETURN t
	END This;

	PROCEDURE FinalizeThread*( t: ANY );
	BEGIN
		WITH t: Thread DO
			IF t.handle # Kernel32.InvalidHandleValue THEN
				Kernel32.CloseHandle( t.handle );  t.handle := Kernel32.InvalidHandleValue
			END
		END
	END FinalizeThread;

	PROCEDURE -stackBottom
	(* starting address of user stack for current thread, called stack top in TIB.H *)
	064H, 08BH, 005H, 004H, 000H, 000H, 000H;   (* MOV EAX, FS:[4] *)

	PROCEDURE StackBottom( ): ADDRESS;
	VAR x: ADDRESS;
	BEGIN
		stackBottom();  SYSTEM.GETREG( SYSTEM.EAX, x );  RETURN x
	END StackBottom;

(** Register the calling thread as non-Oberon thread. *)
	PROCEDURE Register*( name: ARRAY OF CHAR ): Thread;
	VAR proc: Kernel32.HANDLE;  t: Thread;  r: RegThread;  ret: Kernel32.BOOL;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  t := this();
		IF t = NIL THEN
			NEW( r );  t := r;  r.refCount := 1;  t.id := Kernel32.GetCurrentThreadId();  t.handle := Kernel32.GetCurrentThread();
			t.prio := Kernel32.GetThreadPriority( t.handle );  t.proc := NIL;   (* unknown *)
			t.atomic := FALSE;  t.first := FALSE;  t.GCCount := 0;  t.safe := FALSE;  COPY( name, t.name );
			proc := Kernel32.GetCurrentProcess();
			ret :=
				Kernel32.DuplicateHandle( proc, t.handle, proc, t.handle, {}, Kernel32.False, {Kernel32.DuplicateSameAccess} );
			ASSERT ( ret # Kernel32.False );
			t.cont.ContextFlags := Kernel32.ContextFull;  ret := Kernel32.GetThreadContext( t.handle, t.cont );
			ASSERT ( ret # Kernel32.False );
			t.stackBottom := StackBottom();  t.next := threads;  threads := t;  (* Kernel.RegisterObject( t, FinalizeThread, TRUE )*)
		ELSIF t IS RegThread THEN r := t( RegThread );  INC( r.refCount )
		END;
		Kernel32.LeaveCriticalSection( moduleCS );  RETURN t
	END Register;

(** Unregister a thread previously registered with Register. *)
	PROCEDURE Unregister*( t: Thread );
	VAR pt: Thread;
	BEGIN
		IF (t = NIL ) OR ~(t IS RegThread) THEN RETURN END;
		WITH t: RegThread DO
			Kernel32.EnterCriticalSection( moduleCS );  DEC( t.refCount );
			IF t.refCount <= 0 THEN
				pt := threads;
				WHILE (pt # NIL ) & (pt.next # t) DO pt := pt.next END;
				IF pt # NIL THEN pt.next := t.next
				ELSIF t = threads THEN threads := t.next
				ELSE HALT( 99 )
				END;
				FinalizeThread( t )
			END;
			Kernel32.LeaveCriticalSection( moduleCS )
		END
	END Unregister;

	PROCEDURE Cleanup( t: Thread );
	VAR mx: Mutex;
	BEGIN
		ASSERT ( t.id = Kernel32.GetCurrentThreadId() );
		(*		IF t.atomic THEN Kernel.EndAtomic() END;  *)
		mx := mtxs;
		WHILE mx # NIL DO
			IF mx.id = t.id THEN
				WHILE mx.count > 0 DO Unlock( mx ) END
			END;
			mx := mx.next
		END;
		WHILE t.GCCount > 0 DO DEC( t.GCCount );   (* INC( Kernel.GClevel ) *) END
	END Cleanup;

	PROCEDURE ^Start*( t: Thread;  p: BodyProc;  stackLen: LONGINT );

	PROCEDURE kill( t: Thread;  safe: BOOLEAN );
	VAR pt: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  pt := threads;
		WHILE (pt # NIL ) & (pt.next # t) DO pt := pt.next END;
		IF pt # NIL THEN pt.next := t.next
		ELSIF t = threads THEN threads := t.next
		ELSE HALT( 99 )
		END;
		IF t.id # Kernel32.GetCurrentThreadId() THEN
			t.state := suspended;  Kernel32.SuspendThread( t.handle );  t.next := aliens;  aliens := t;
			Kernel32.LeaveCriticalSection( moduleCS );  Kernel32.SetThreadContext( t.handle, t.cont );  t.state := running;
			Kernel32.ResumeThread( t.handle )
		ELSE  (* Stop(self) *)
			IF t.state # ended THEN t.state := killed;  END;
			Cleanup( t );  FinalizeThread( t );  Kernel32.LeaveCriticalSection( moduleCS );
			IF t.safe & safe THEN Start( t, t.proc, 0 ) END;
			Kernel32.ExitThread( 0 )
		END
	END kill;

(** Stop execution of thread t. *)
	PROCEDURE Kill*( t: Thread );
	BEGIN
		kill( t, FALSE )
	END Kill;

(** Stop execution of thread t after a trap. *)
	PROCEDURE Abort*( t: Thread );
	BEGIN
		kill( t, TRUE )
	END Abort;

	PROCEDURE [WINAPI] *ExcpFrmHandler( VAR excpRec: Kernel32.ExceptionRecord;  excpFrame: Kernel32.ExcpFrmPtr;
																	VAR context: Kernel32.Context;  dispatch: LONGINT ): LONGINT;
	VAR t: Thread;  ret: LONGINT;
	BEGIN
		(* 	DEC( Kernel.GClevel );  *) t := this();  ret := Kernel32.excpFrmHandler( excpRec, excpFrame, context, dispatch );
		IF ret = Kernel32.ExceptionExecuteHandler THEN
			IF t # NIL THEN  (* INC( Kernel.GClevel ); *) Abort( t );  RETURN ret ELSE KernelLog.String( "Threads.ExcpFrmHandler: failing thread not found!!!" );  KernelLog.Ln() END
		END;
		(*	INC( Kernel.GClevel );  *) RETURN ret
	END ExcpFrmHandler;

	PROCEDURE SafeForBreak( mod: Modules.Module ): BOOLEAN;
	BEGIN
		KernelLog.String( "Threads.SafeForBreak: " );
		IF mod # NIL THEN
			KernelLog.String( mod.name );  KernelLog.Ln();
			IF (mod.name = "Kernel") OR (mod.name = "FileDir") OR (mod.name = "Files") OR (mod.name = "Modules") OR (mod.name = "Threads") THEN RETURN FALSE
			ELSE RETURN TRUE
			END
		ELSE KernelLog.String( "module not found" );  KernelLog.Ln();  RETURN FALSE
		END
	END SafeForBreak;

(** *)
	PROCEDURE Break*( t: Thread );   (* not reentrant / global break code *)
	CONST MaxTry = 50;
	VAR cont: Kernel32.Context;  mod: Modules.Module;  try: LONGINT;
	BEGIN
		IF This() # t THEN
			Kernel32.EnterCriticalSection( moduleCS );  try := 0;
			LOOP
			(* DEC( Kernel.GClevel );  *)
				t.state := suspended;  Kernel32.SuspendThread( t.handle );  cont.ContextFlags := Kernel32.ContextControl;
				Kernel32.GetThreadContext( t.handle, cont );  mod := Modules.ThisModuleByAdr( cont.EIP );  KernelLog.String( "Threads.Break at adr:" );
				KernelLog.Int( cont.EIP, 5 );  KernelLog.Ln;
				IF mod # NIL THEN KernelLog.String( "Threads.Break in" );  KernelLog.String( mod.name );  KernelLog.Ln;  END;

				IF ~SafeForBreak( mod ) THEN
					t.state := running;  Kernel32.ResumeThread( t.handle );   (* INC( Kernel.GClevel ); *) INC( try );
					IF try > MaxTry THEN KernelLog.String( "Threads.Break: failed " );  KernelLog.Ln();  Kernel32.LeaveCriticalSection( moduleCS );  RETURN END
				ELSE EXIT
				END
			END;
			(* push cont.Eip *) break[0] := 68X;  SYSTEM.MOVE( ADDRESSOF( cont.EIP ), ADDRESSOF( break[1] ), 4 );
			(* push ebp *) break[5] := 055X;
			(* mov ebp, esp *) break[6] := 08BX;  break[7] := 0ECX;
			(* push 13 *) break[8] := 06AX;  break[9] := 0DX;
			(* int 3 *) break[10] := 0CCX;
			(* mov esp, ebp *) break[11] := 08BX;  break[12] := 0E5X;
			(* pop ebp *) break[13] := 05DX;
			(* ret *) break[14] := 0C3X;  cont.EIP := ADDRESSOF( break[0] );  Kernel32.SetThreadContext( t.handle, cont );
			t.state := running;  Kernel32.ResumeThread( t.handle );   (*  INC( Kernel.GClevel ); *)
			Kernel32.LeaveCriticalSection( moduleCS )
		ELSE HALT( 99 )
		END
	END Break;

	PROCEDURE [WINAPI] *Wrapper( par: ANY ): LONGINT;
	VAR excp: Kernel32.ExcpFrm;  pt, t: Thread;  id: LONGINT;  wrapper: Kernel32.ThreadProc;
	BEGIN
		IF (par # NIL ) THEN Kernel32.SetEvent( SYSTEM.VAL( LONGINT, par ) ) END;
		Kernel32.EnterCriticalSection( moduleCS );  id := Kernel32.GetCurrentThreadId();  t := threads;
		WHILE (t # NIL ) & (t.id # id) DO t := t.next END;
		Kernel32.LeaveCriticalSection( moduleCS );
		IF (t # NIL ) & t.first THEN
			t.first := FALSE;  wrapper := Wrapper;  SYSTEM.GETREG( SYSTEM.ESP, t.stackBottom );
			t.cont.ContextFlags := Kernel32.ContextFull;  Kernel32.GetThreadContext( t.handle, t.cont );
			t.cont.EIP := SYSTEM.VAL( LONGINT, wrapper );
			Kernel32.SetThreadPriority( t.handle, t.prio );   (* t.prio := Normal; *)
			excp.handler := ExcpFrmHandler;  excp.link := Kernel32.NULL;  Kernel32.InstallExcpFrm( excp );
			Reals.SetFCR( Reals.DefaultFCR );  t.state := running;  t.proc();  t.state := ended;  Kill( t )
		ELSE
			ASSERT ( t = NIL );
			Kernel32.EnterCriticalSection( moduleCS );  pt := NIL;  t := aliens;
			WHILE (t # NIL ) & (t.id # id) DO pt := t;  t := t.next END;
			ASSERT ( t # NIL );
			Cleanup( t );
			IF pt # NIL THEN pt.next := t.next
			ELSIF aliens = t THEN aliens := t.next
			END;
			Kernel32.LeaveCriticalSection( moduleCS );  Kernel32.ExitThread( 0 )
		END
	END Wrapper;

(** Start a new thread executing p. *)
	PROCEDURE Start*( t: Thread;  p: BodyProc;  stackLen: LONGINT );
	VAR pt, tt: Thread;  eventhandle: LONGINT;
	BEGIN
		IF Machine.debug THEN KernelLog.String( "Threads starting thread: " );  KernelLog.String( t.name );  KernelLog.Ln;  END;
		ASSERT ( threaded & (p # NIL ) & (t # NIL ), 32 );
		Kernel32.EnterCriticalSection( moduleCS );  pt := NIL;  tt := threads;
		WHILE (tt # NIL ) & (tt # t) DO pt := tt;  tt := tt.next END;
		IF tt = t THEN Kernel32.LeaveCriticalSection( moduleCS );  HALT( 99 )
		ELSIF pt # NIL THEN pt.next := t
		ELSE threads := t
		END;
		t.state := ready;  (* Kernel.RegisterObject( t, FinalizeThread, TRUE ); *)  t.next := NIL;  t.proc := p;
		t.handle := Kernel32.InvalidHandleValue;  t.id := 0;  t.stackBottom := Kernel32.NULL;  t.atomic := FALSE;  t.first := TRUE;
		t.GCCount := 0;  t.prio := Normal;

		eventhandle := Kernel32.CreateEvent( NIL , Kernel32.False, Kernel32.False, NIL );
		t.handle := Kernel32.CreateThread( 0, stackLen, Wrapper, SYSTEM.VAL( ANY, eventhandle ), {}, t.id );
		Kernel32.WaitForSingleObject( eventhandle, Kernel32.Infinite );  Kernel32.CloseHandle( eventhandle );
		Kernel32.LeaveCriticalSection( moduleCS );

	END Start;

(** Start a new thread executing p. *)
	PROCEDURE StartWFinalizer*( t: Thread;  p: BodyProc;  stackLen: LONGINT;  finalizer: Finalizer;  priority: LONGINT );
	VAR pt, tt: Thread;  eventhandle: LONGINT;
	BEGIN
		IF Machine.debug THEN KernelLog.String( "Threads starting thread wf: " );  KernelLog.String( t.name );  KernelLog.Ln;  END;
		ASSERT ( threaded & (p # NIL ) & (t # NIL ), 32 );
		Kernel32.EnterCriticalSection( moduleCS );  pt := NIL;  tt := threads;
		WHILE (tt # NIL ) & (tt # t) DO pt := tt;  tt := tt.next END;
		IF tt = t THEN Kernel32.LeaveCriticalSection( moduleCS );  HALT( 99 )
		ELSIF pt # NIL THEN pt.next := t
		ELSE threads := t
		END;
		t.state := ready;  (* Kernel.RegisterObject( t, finalizer, TRUE );  t.next := NIL;  t.proc := p;  *)
		t.handle := Kernel32.InvalidHandleValue;  t.id := 0;  t.stackBottom := Kernel32.NULL;  t.atomic := FALSE;  t.first := TRUE;
		t.GCCount := 0;  t.prio := priority;

		eventhandle := Kernel32.CreateEvent( NIL , Kernel32.False, Kernel32.False, NIL );
		t.handle := Kernel32.CreateThread( 0, stackLen, Wrapper, SYSTEM.VAL( ANY, eventhandle ), {}, t.id );
		Kernel32.WaitForSingleObject( eventhandle, Kernel32.Infinite );  Kernel32.CloseHandle( eventhandle );
		Kernel32.LeaveCriticalSection( moduleCS );
	END StartWFinalizer;


(** Enumerate all threads. *)
	PROCEDURE Enumerate*( p: EnumProc );
	VAR t: Thread;
	BEGIN
		ASSERT ( p # NIL );
		Kernel32.EnterCriticalSection( moduleCS );  t := threads;
		WHILE t # NIL DO p( t );  t := t.next END;
		Kernel32.LeaveCriticalSection( moduleCS )
	END Enumerate;

(** Suspend execution of thread t. *)
	PROCEDURE Suspend*( t: Thread );
	BEGIN
		IF Machine.debug THEN KernelLog.String( "Threads suspend thread: " );  KernelLog.String( t.name );  KernelLog.Ln;  END;
		t.state := suspended;  Kernel32.SuspendThread( t.handle )
	END Suspend;

(** Resume execution of thread t. *)
	PROCEDURE Resume*( t: Thread );
	BEGIN
		IF Machine.debug THEN

			KernelLog.String( "Threads resume thread: " );  KernelLog.String( t.name );  KernelLog.Ln;
		END;
		t.state := running;  Kernel32.ResumeThread( t.handle )
	END Resume;

(** Change the priority of thread t to prio. *)
	PROCEDURE SetPriority*( t: Thread;  prio: LONGINT );
	BEGIN
		Kernel32.SetThreadPriority( t.handle, prio );  t.prio := prio
	END SetPriority;

(** Get the priority for thread t. *)
	PROCEDURE GetPriority*( t: Thread;  VAR prio: LONGINT );
	BEGIN
		t.prio := Kernel32.GetThreadPriority( t.handle );  prio := t.prio
	END GetPriority;

*)

(** Set the calling thread to sleep for the specified amount of milliseconds. *)
	PROCEDURE Sleep*( ms: LONGINT );
	BEGIN
		Kernel32.Sleep( ms )
	END Sleep;

(** Pass control to the next ready thread. *)
	PROCEDURE Pass*;
	BEGIN
		Kernel32.Sleep( 0 )
	END Pass;

(*
	PROCEDURE EnableGC*( );
	VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  t := this();
		IF t # NIL THEN DEC( t.GCCount ) END;
		(* INC( Kernel.GClevel ); *) Kernel32.LeaveCriticalSection( moduleCS )
	END EnableGC;

	PROCEDURE DisableGC*( );
	VAR t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  t := this();
		IF t # NIL THEN INC( t.GCCount ) END;
		(* DEC( Kernel.GClevel ); *) Kernel32.LeaveCriticalSection( moduleCS )
	END DisableGC;

(** Start non-interruptable section *)
	PROCEDURE BeginAtomic*( ): BOOLEAN;
	VAR t, tt: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  tt := this();
		IF tt # NIL THEN
			IF ~tt.atomic THEN tt.atomiccnt := 0 ELSE INC( tt.atomiccnt );  RETURN TRUE;  END;   (* to identify - if already in atomic section - when to come back*)
			ASSERT ( threaded & ~tt.atomic, 34 );
			t := threads;
			WHILE t # NIL DO
				IF t # tt THEN
					ASSERT ( ~t.atomic, 35 );
					Kernel32.SuspendThread( t.handle )
				END;
				t := t.next
			END;
			tt.atomic := TRUE;  RETURN TRUE
		ELSE Kernel32.LeaveCriticalSection( moduleCS );  RETURN FALSE
		END
	END BeginAtomic;

(** End non-interruptable section *)
	PROCEDURE EndAtomic*( );
	VAR t, tt: Thread;
	BEGIN
		tt := this();
		ASSERT ( threaded & tt.atomic, 36 );
		IF tt.atomiccnt > 0 THEN DEC( tt.atomiccnt );  RETURN END;
		t := threads;
		tt.atomic := FALSE;   (* fof 030304: resumed threads might want to be atomic -> unlock BEFORE resuming them *)
		WHILE t # NIL DO
			IF t # tt THEN
				ASSERT ( ~t.atomic, 37 );
				Kernel32.ResumeThread( t.handle )
			END;
			t := t.next
		END;
		(* tt.atomic := FALSE; *)
		Kernel32.LeaveCriticalSection( moduleCS )
	END EndAtomic;

	PROCEDURE CheckStacks( );
	VAR t: Thread;  cont: Kernel32.Context;  sp, p, bottom: ADDRESS;
	BEGIN
		t := threads;   (*! remove if removing check stacks *)
		WHILE (t # NIL ) DO
			IF (t # startup) THEN
				cont.ContextFlags := Kernel32.ContextControl + Kernel32.ContextInteger;
				Kernel32.GetThreadContext( t.handle, cont );  Kernel.Candidate( cont.EDI );  Kernel.Candidate( cont.ESI );
				Kernel.Candidate( cont.EBX );  Kernel.Candidate( cont.EDX );  Kernel.Candidate( cont.ECX );
				Kernel.Candidate( cont.EAX );  sp := cont.ESP;
				(*
			ASSERT(cont.Ebp <= t.stackBottom);
			bottom := t.stackBottom;
			*)
				(*
				IF cont.EBP > t.stackBottom THEN  (*! fof  030614, commented out the previous and reactivated this, might be wrong *)
					t.stackBottom := cont.EBP
				END;
				bottom := t.stackBottom;
				WHILE sp < bottom DO SYSTEM.GET( sp, p );  Kernel.Candidate( p );  INC( sp, 4 ) END;
				*)
			END;
			t := t.next
		END
	END CheckStacks;


	PROCEDURE Shutdown( );
	VAR tt, t: Thread;
	BEGIN
		Kernel32.EnterCriticalSection( moduleCS );  threaded := FALSE;   (* oberonLoop := NIL;  *) tt := this();  t := threads;
		WHILE t # NIL DO
			IF (t # tt) & ((t IS RegThread) OR (Kernel32.TerminateThread( t.handle, 0 ) # Kernel32.False)) THEN FinalizeThread( t ) END;
			t := t.next
		END;
		Kernel32.LeaveCriticalSection( moduleCS );  Kernel32.DeleteCriticalSection( moduleCS )
	END Shutdown;


	PROCEDURE GC;
	BEGIN
		Kernel.CollectGarbage( Modules.root );
	END GC;
*)

	PROCEDURE init;
	BEGIN
		Kernel32.InitializeCriticalSection( moduleCS );  Kernel32.EnterCriticalSection( moduleCS );  NEW(finalizers);
		(*
		threads := NIL;
		aliens := NIL;   (*  oberonLoop := NIL; *) threaded := FALSE;  *)
		mtxs :=
		NIL;   (* Kernel.CheckStacks := CheckStacks;  Kernel.BeginAtomic := BeginAtomic;  Kernel.EndAtomic := EndAtomic;  *)
		(* 	threaded := TRUE;  *)
		(* INC( Kernel.GClevel ); *)  (* enable GC *)
		(* Kernel.GC := GC; *)  (* Modules.InstallTermHandler( Shutdown );  *)
		(* threads := Register( "StartupThread" );   *)  (* need a registered startup thread for Objects etc., startup thread gets killed when Configuration is ready *)
		(*
		startup := NIL;   (* not needed, remove. *)
		*)
		Kernel32.LeaveCriticalSection( moduleCS );

	END init;

BEGIN
	init();
END Threads.
