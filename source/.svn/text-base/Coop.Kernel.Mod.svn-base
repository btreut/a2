	
(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)
(* red marked parts are specific for WinAos, fof *)

MODULE Kernel;   (** AUTHOR "pjm, ejz, fof, ug"; PURPOSE "Implementation-independent kernel interface"; *)

IMPORT Environment, Heaps, Objects, Trace, Activities;

CONST

	TimerFree = 0;  TimerSleeping = 1;  TimerWoken = 2;  TimerExpired = 3;   (* Timer state *)

	Second* = 1000;

TYPE
	(** Finalizer for FinalizedCollection.Add. *)
	Finalizer* = Heaps.Finalizer;   (** PROCEDURE (obj: ANY) *)

	(** Enumerator for FinalizedCollection.Enumerate. *)
	Enumerator* = PROCEDURE {DELEGATE} ( obj: ANY;  VAR cont: BOOLEAN );

	FinalizerNode = POINTER TO RECORD (Objects.FinalizerNode)
		nextObj {UNTRACED} : FinalizerNode;   (* in Collection c *)
	END;

	(** Polling timer. *)
	MilliTimer* = RECORD
		start, target: LONGINT
	END;

TYPE
	(** Delay timer *)
	Timer* = OBJECT
	VAR
		timer: Objects.Timer;
		state-: SHORTINT;
		nofHandleTimeout-, nofHandleTimeout2- : LONGINT;
		nofSleeps-, nofSleepsLeft- : LONGINT;
		nofAwaits-, nofAwaitsLeft- : LONGINT;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			INC(nofHandleTimeout);
			IF state # TimerFree THEN INC(nofHandleTimeout2); state := TimerExpired END
		END HandleTimeout;

		(** Delay the calling process the specified number of milliseconds or until Wakeup is called. Only one process may sleep on a specific timer at a time. *)
		PROCEDURE Sleep*(ms: LONGINT);
		BEGIN {EXCLUSIVE}
			INC(nofSleeps);
			ASSERT(state = TimerFree);	(* only one process may sleep on a timer *)
			state := TimerSleeping;
			Objects.SetTimeout(timer, HandleTimeout, ms);
			INC(nofAwaits);
			AWAIT(state # TimerSleeping);
			INC(nofAwaitsLeft);
			IF state # TimerExpired THEN Objects.CancelTimeout(timer) END;
			state := TimerFree;
			INC(nofSleepsLeft);
		END Sleep;

		(** Wake up the process sleeping on the timer, if any. *)
		PROCEDURE Wakeup*;
		BEGIN {EXCLUSIVE}
			IF state = TimerSleeping THEN state := TimerWoken END
		END Wakeup;

		(** Initializer. *)
		PROCEDURE &Init*;
		BEGIN
			state := TimerFree; NEW(timer);
			nofHandleTimeout := 0; nofHandleTimeout2 := 0;
			nofSleeps := 0; nofSleepsLeft := 0;
			nofAwaits := 0; nofAwaitsLeft := 0;
		END Init;

	END Timer;

TYPE
	(** A collection of objects that are finalized automatically by the garbage collector. *)
	FinalizedCollection* = OBJECT (Objects.FinalizedCollection)
		VAR root: FinalizerNode;	(* weak list of contents linked by nextObj *)

		(** Add obj to collection. Parameter fin specifies finalizer, or NIL if not required. *)	(* may be called multiple times *)
		PROCEDURE Add*(obj: ANY; fin: Finalizer);
		VAR n: FinalizerNode;
		BEGIN
			NEW(n); n.c := SELF; n.finalizer := fin;
			Heaps.AddFinalizer(obj, n);
			BEGIN {EXCLUSIVE}
				n.nextObj := root.nextObj; root.nextObj := n	(* add to collection *)
			END
		END Add;

		(** Remove one occurrence of obj from collection. *)
		PROCEDURE Remove*(obj: ANY);
		VAR p, n: FinalizerNode;
		BEGIN {EXCLUSIVE}
			p := root; n := p.nextObj;
			WHILE (n # NIL) & (n.objWeak # obj) DO
				p := n; n := n.nextObj
			END;
			IF n # NIL THEN p.nextObj := n.nextObj END;
			(* leave in global finalizer list *)
		END Remove;

		(** Overriden method: Remove all occurrences of obj from collection. *)
		PROCEDURE RemoveAll*(obj: ANY);
		VAR p, n: FinalizerNode;
		BEGIN {EXCLUSIVE}
			p := root; n := p.nextObj;
			WHILE n # NIL DO
				IF n.objWeak = obj THEN
					p.nextObj := n.nextObj;
				ELSE
					p := n;
				END;
				n := n.nextObj
			END
		END RemoveAll;

		(** Enumerate all objects in the collection (Enumerator may not call Remove, Add, Enumerate or Clear). *)
		PROCEDURE Enumerate*(enum: Enumerator);
		VAR fn, next: FinalizerNode; cont: BOOLEAN;
		BEGIN {EXCLUSIVE}
			fn := root.nextObj; cont := TRUE;
			WHILE fn # NIL DO
				next := fn.nextObj;	(* current (or other) object may be removed by enum call *)
				enum(fn.objWeak, cont);
				IF cont THEN fn := next ELSE fn := NIL END
			END
		END Enumerate;

		(** Enumerate all objects in the collection not being finalized (Enumerator may not call Remove, Add, Enumerate or Clear). *)
		PROCEDURE EnumerateN*( enum: Enumerator );
		VAR fn, next: FinalizerNode; cont: BOOLEAN; obj: ANY;
		BEGIN {EXCLUSIVE}
			fn := root.nextObj; cont := TRUE;
			WHILE fn # NIL DO
				next := fn.nextObj;	(* current (or other) object may be removed by enum call *)
				obj := NIL;

				IF (fn.objWeak # NIL ) & (fn.objStrong = NIL ) THEN (* object is not yet on the finalizers list *)
					obj := fn.objWeak; (* now object is locally referenced, will therefore not be GCed *)
				END;

				IF obj # NIL THEN enum( obj, cont ); END;
				IF cont THEN fn := next ELSE fn := NIL END
			END
		END EnumerateN;

		(** Initialize new collection. May also be called to clear an existing collection. *)
		PROCEDURE &Clear*;
		BEGIN {EXCLUSIVE}
			NEW(root); root.nextObj := NIL	(* head *)
		END Clear;

	END FinalizedCollection;

VAR
	second- : LONGINT; (** number of ticks per second (Hz) *)

	(*
	PROCEDURE Watch;
	VAR free, total1, total2, largest, low, high: LONGINT;
	BEGIN
		IF TraceFin THEN
			Heaps.GetHeapInfo( total1, free, largest );  total1 := (total1 + 512) DIV 1024;  free := (free + 512) DIV 1024;
			largest := (largest + 512) DIV 1024;  Machine.GetFreeK( total2, low, high );  KernelLog.Enter;  KernelLog.String( "Heap: " );
			KernelLog.Int( total1, 1 );  KernelLog.String( " total, " );  KernelLog.Int( free, 1 );  KernelLog.String( " free, " );  KernelLog.Int( largest, 1 );
			KernelLog.String( " largest, Mem: " );  KernelLog.Int( total2, 1 );  KernelLog.String( " total, " );  KernelLog.Int( low, 1 );  KernelLog.String( " low, " );
			KernelLog.Int( high, 1 );  KernelLog.String( " high" );  KernelLog.Exit
		END
	END Watch;
	*)

	(** Return the number of ticks since system start. For timeouts, time measurements, etc, please use Kernel.MilliTimer instead.
		Ticks increment rate is stored in "second" variable in Hz. *)
	PROCEDURE GetTicks*() : LONGINT;
	BEGIN
		RETURN Environment.Clock()
	END GetTicks;

	(** -- Garbage collection -- *)

	(** Activate the garbage collector immediately. *)

	PROCEDURE GC*;
	BEGIN
		Heaps.LazySweepGC;
	END GC;

	(** -- Timers -- *)

(** Set timer to expire in approximately "ms" milliseconds. *)
	PROCEDURE SetTimer*( VAR t: MilliTimer;  ms: LONGINT );
	BEGIN
		IF ms < 5 THEN INC( ms ) END;   (* Nyquist adjustment *)
		t.start := Environment.Clock();  t.target := t.start + ms
	END SetTimer;

(** Test whether a timer has expired. *)
	PROCEDURE Expired*( VAR t: MilliTimer ): BOOLEAN;
	BEGIN
		RETURN Environment.Clock() - t.target >= 0
	END Expired;

(** Return elapsed time on a timer in milliseconds. *)
	PROCEDURE Elapsed*( VAR t: MilliTimer ): LONGINT;
	BEGIN
		RETURN Environment.Clock() - t.start
	END Elapsed;

(** Return time left on a timer in milliseconds. *)
	PROCEDURE Left*( VAR t: MilliTimer ): LONGINT;
	BEGIN
		RETURN t.target - Environment.Clock()
	END Left;

BEGIN
	second := Second;
	Heaps.GC := Heaps.InvokeGC; (* must be done after all processors have started *)
	Trace.String ("Kernel: "); Trace.Green; Trace.StringLn("Initialized and started."); Trace.Default;
END Kernel.

(**
Notes:
o The FinalizedCollection object implements collections of finalized objects.
o Objects added to a finalized collection (with Add) are removed automatically by the garbage collector when no references to them exist any more.  They can also be removed explicitly with Remove.
o All the objects currently in a collection can be enumerated by Enumerate, which takes an enumerator procedure as parameter.  The enumerator can also be a method in an object, which is useful when state information is required during the enumeration.  The enumerator may not call other methods of the same collection.
o An object in a finalized collection can have an finalizer procedure associated with it, which gets called by a separate process when there are no references left to the object any more.  A finalizer is usually used for some cleanup functions, e.g. releasing external resources. It is executed exactly once per object.  During the next garbage collector cycle the object is finally removed.
*)

(*
to do:
o cancel finalizer when removing object
o fix module free race: module containing finalizer is freed.  although the finalizer list is cleared, the FinalizerCaller has already taken a reference to a finalizer, but hasn't called it yet.
o consider: a module has a FinalizedCollection, without finalizers (NIL).  when the module is freed, the objects are still in the finalization list, and will get finalized in the next garbage collection.  The FinalizedCollection will survive the first collection, as the objects all have references to it through their c field.  After all objects have been finalized, the FinalizedCollection itself is collected.  No dangling pointers occur, except the untraced module field references from the type descriptors, which are only used for tracing purposes.
o check cyclic dependencies between finalized objects.
o GetTime(): LONGINT - return current time in ms
o Delay(td: LONGINT) - wait td ms
o AwaitTime(t: LONGINT) - wait at least until time t
o Wakeup(obj: ANY) - wake up object that is waiting
*)

