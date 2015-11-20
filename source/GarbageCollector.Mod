(* Automatic memory management *)
(* Copyright (C) Florian Negele *)

(** The GarbageCollector module provides an automatic memory management for pointers allocated using the NEW statement. *)
(** It implements a concurrent and interruptible mark and sweep garbage collection. *)
MODULE GarbageCollector;

IMPORT Activities, BaseTypes, Counters, CPU;

VAR tracings: Counters.AlignedCounter;
VAR currentCycle, oldestCycle: LONGWORD;
VAR firstMarked {UNTRACED}, firstWatched {UNTRACED}: BaseTypes.Pointer;
VAR markedSentinel {UNTRACED}, watchedSentinel {UNTRACED}: BaseTypes.Pointer;

TYPE Delegate = RECORD proc: PROCEDURE; pointer: BaseTypes.Pointer END;

(** Registers the specified pointer for automatic memory management. *)
(** This procedure is called by the compiler when a pointer or object type is allocated using the NEW statement. *)
PROCEDURE Watch- (pointer {UNTRACED}: BaseTypes.Pointer);
VAR value {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (pointer # NIL);
	ASSERT (pointer.nextWatched = NIL);

	(* initialize garbage collection cycle *)
	pointer.cycle := CAS (oldestCycle, 0, 0);

	(* append pointer to linked list of watched pointers *)
	LOOP
		value := CAS (firstWatched, NIL, NIL);
		pointer.nextWatched := value;
		IF CAS (firstWatched, value, pointer) = value THEN EXIT END;
		CPU.Backoff;
	END;
END Watch;

(** Performs the assignment of a pointer variable. *)
(** This procedure is called by the compiler when assigning variables of pointer type. *)
PROCEDURE Assign- (VAR pointer {UNTRACED}: BaseTypes.Pointer; value {UNTRACED}: BaseTypes.Pointer);
VAR previousValue {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	previousValue := pointer; pointer := value; IF value # NIL THEN Mark (value) END;
	IF Activities.IsLocalVariable (ADDRESS OF pointer) THEN
		IF value # NIL THEN Counters.Inc (value.references) END;
		IF previousValue # NIL THEN Counters.Dec (previousValue.references) END;
	END;
END Assign;

(** Performs the assignment of a procedure delegate. *)
(** This procedure is called by the compiler when assigning variables of procedure delegate type. *)
PROCEDURE AssignDelegate-(target {UNTRACED}, source {UNTRACED}:  POINTER {UNSAFE} TO Delegate);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Assign(target.pointer, source.pointer);
	target.proc := source.proc;
END AssignDelegate;

(** Performs the assignment of an array containing pointers. *)
(** This procedure is called by the compiler when assigning arrays of pointer type. *)
PROCEDURE AssignPointerArray- (VAR target {UNTRACED}: ARRAY OF BaseTypes.Pointer; CONST source {UNTRACED}: ARRAY OF BaseTypes.Pointer);
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (LEN (target) = LEN (source));
	FOR i := 0 TO LEN (target) - 1 DO
		Assign (target[i], source[i]);
	END;
END AssignPointerArray;

(** Performs the assignment of an array containing delegates. *)
(** This procedure is called by the compiler when assigning arrays of procedure delegate type. *)
PROCEDURE AssignDelegateArray-(VAR target {UNTRACED}: ARRAY OF Delegate; CONST source {UNTRACED}: ARRAY OF Delegate);
VAR i: SIZE;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO LEN(target) DO
		AssignDelegate(ADDRESS OF target[i], ADDRESS OF source[i]);
	END;
END AssignDelegateArray;

(** Executes an atomic compare-and-swap operation on a pointer variable. *)
(** This procedure is called by the compiler when executing CAS expressions. *)
PROCEDURE CompareAndSwap- (VAR pointer {UNTRACED}: BaseTypes.Pointer; previousValue {UNTRACED}, value {UNTRACED}: BaseTypes.Pointer): ADDRESS;
VAR result {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := CAS (pointer, previousValue, value); IF value # NIL THEN Mark (value) END;
	IF (result = previousValue) & Activities.IsLocalVariable (ADDRESS OF pointer) THEN
		IF value # NIL THEN Counters.Inc (value.references) END;
		IF previousValue # NIL THEN Counters.Dec (value.references) END;
	END;
	RETURN result;
END CompareAndSwap;

(** Resets a pointer variable. *)
(** This procedure is called by the compiler when assigning NIL to variables of pointer type. *)
PROCEDURE Reset- (VAR pointer {UNTRACED}: BaseTypes.Pointer);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF pointer = NIL THEN RETURN END;
	IF Activities.IsLocalVariable (ADDRESS OF pointer) THEN Counters.Dec (pointer.references) END;
	pointer := NIL;
END Reset;

(** Resets an array of pointers. *)
(** This procedure is called by the compiler for resetting all elements of array variables containing pointers. *)
PROCEDURE ResetArray- (VAR pointers {UNTRACED}: ARRAY OF BaseTypes.Pointer);
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO LEN (pointers) - 1 DO
		Reset (pointers[i]);
	END;
END ResetArray;

(** Reset a delegate. *)
(** This procedure is called by the compiler when resetting variables of procedure delegate type. *)
PROCEDURE ResetDelegate-(target {UNTRACED}:  POINTER {UNSAFE} TO Delegate);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Reset(target.pointer);
END ResetDelegate;

(** Resets an array of delegates. *)
(** This procedure is called by the compiler for resetting all elements of array variables containing procedure delegates. *)
PROCEDURE ResetDelegateArray-(VAR delegates {UNTRACED}: ARRAY OF Delegate);
VAR i: SIZE;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO LEN(delegates) DO
		Reset (delegates[i].pointer);
	END;
END ResetDelegateArray;

(* Increments a garbage collection cycle and returns its previous value. *)
(* Collection cycles should be able to overflow and are therefore represented using a signed type. *)
PROCEDURE Increment (VAR cycle: LONGWORD): LONGWORD;
VAR value: LONGWORD;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (cycle, 0, 0);
		IF CAS (cycle, value, value + 1) = value THEN EXIT END;
		CPU.Backoff;
	END;
	RETURN value;
END Increment;

(** Performs a complete garbage collection cycle by marking the object graph and disposing all unreachable objects. *)
(** Garbage can be collected concurrently if necessary. *)
PROCEDURE Collect*;
VAR root EXTERN "Modules.root": BaseTypes.Pointer;
VAR cycle: LONGWORD; first {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCHECKED}
	(* ensure list of marked pointers is empty *)
	TraceMarkedPointers;

	(* get unique garbage collection cycle *)
	cycle := Increment (currentCycle);

	(* help older collection cycles to mark all remaining pointers *)
	WHILE CAS (oldestCycle, 0, 0) # cycle DO TraceMarkedPointers END;

	(* acquire ownership of watched pointers *)
	first := AcquireList (firstWatched, watchedSentinel);

	(* mark global referenced pointers *)
	Mark (root); TraceMarkedPointers;

	(* mark pointers changed by assignments *)
	WHILE Activities.AssignmentsInProgress () DO TraceMarkedPointers END;

	(* mark local referenced pointers *)
	MarkReferenced (first); TraceMarkedPointers;

	(* mark all remaining pointers *)
	WHILE Counters.Read (tracings) # 0 DO TraceMarkedPointers END; TraceMarkedPointers;
	ASSERT (CAS (oldestCycle, cycle, cycle + 1) = cycle);

	(* collect garbage *)
	Sweep (first, cycle);
END Collect;

(** Marks the specified pointer as reachable. *)
(** This procedure is called by the compiler while tracing outgoing pointers of marked objects. *)
PROCEDURE Mark- (pointer {UNTRACED}: BaseTypes.Pointer);
VAR cycle, current: LONGWORD; first {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* ignore nil pointers *)
	IF pointer = NIL THEN RETURN END;

	(* check whether the pointer has to be marked *)
	LOOP
		cycle := CAS (pointer.cycle, 0, 0);
		(* ignore already marked pointers *)
		current := CAS (currentCycle, 0, 0);
		IF cycle - current >= 0 THEN RETURN END;

		(* try to mark pointer *)
		IF CAS (pointer.cycle, cycle, current) = cycle THEN EXIT END;
		CPU.Backoff;
	END;

	(* append pointer to linked list of marked pointers *)
	LOOP
		first := CAS (firstMarked, NIL, NIL);
		IF CAS (pointer.nextMarked, NIL, first) # NIL THEN RETURN END;
		IF CAS (firstMarked, first, pointer) = first THEN EXIT END;
		ASSERT (CAS (pointer.nextMarked, first, NIL) = first);
		CPU.Backoff;
	END;
END Mark;

(** Marks an array of pointers. *)
(** This procedure is called by the compiler while tracing arrays of pointer type. *)
PROCEDURE MarkPointerArray- (CONST pointers {UNTRACED} : ARRAY OF BaseTypes.Pointer);
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO LEN (pointers) - 1 DO
		Mark (pointers[i]);
	END;
END MarkPointerArray;

(** Marks an array of records. *)
(** This procedure is called by the compiler while tracing arrays of record type. *)
PROCEDURE MarkRecordArray- (address: ADDRESS; length: SIZE; descriptor {UNTRACED}: BaseTypes.Descriptor);
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO length - 1 DO
		descriptor.trace (address);
		INC (address, descriptor.size);
	END;
END MarkRecordArray;

PROCEDURE MarkDelegateArray-(CONST delegates {UNTRACED}: ARRAY OF Delegate);
VAR i: SIZE;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO LEN(delegates) DO
		Mark (delegates[i].pointer);
	END;
END MarkDelegateArray;

(* Acquires ownership of the specified linked list by exchanging its first item with its sentinel. *)
PROCEDURE AcquireList (VAR first {UNTRACED}: BaseTypes.Pointer; sentinel {UNTRACED}: BaseTypes.Pointer): {UNTRACED} BaseTypes.Pointer;
VAR value {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (first, NIL, NIL);
		IF value = sentinel THEN EXIT END;
		IF CAS (first, value, sentinel) = value THEN EXIT END;
		CPU.Backoff;
	END;
	RETURN value;
END AcquireList;

(* Traverses the linked list of marked pointers and traces outgoing pointers. *)
PROCEDURE TraceMarkedPointers;
VAR current {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCHECKED}
	(* notify older collections cycles that the list is traversed *)
	IF CAS (firstMarked, NIL, NIL) = markedSentinel THEN RETURN END;

	Counters.Inc (tracings);

	LOOP
		(* acquire ownership of marked pointers *)
		current := AcquireList (firstMarked, markedSentinel);
		IF current = markedSentinel THEN EXIT END;

		(* traverse linked list and trace pointers *)
		REPEAT
			current.Trace;
			current := CAS (current.nextMarked, current.nextMarked, NIL);
		UNTIL current = markedSentinel;
	END;

	(* allow older cycles to continue *)
	Counters.Dec (tracings);
END TraceMarkedPointers;

(* Traverses a list of watched pointers and marks local references. *)
PROCEDURE MarkReferenced (VAR first {UNTRACED}: BaseTypes.Pointer);
VAR current {UNTRACED}, previous {UNTRACED}, next {UNTRACED}, front {UNTRACED}, back {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCHECKED}
	(* traverse linked list and remove unreferenced items  *)
	current := first; previous := NIL; front := NIL; back := NIL;
	WHILE current # watchedSentinel DO
		next := current.nextWatched;
		IF Counters.Read (current.references) # 0 THEN
			IF previous # NIL THEN previous.nextWatched := next ELSE first := next END;
			IF front # NIL THEN current.nextWatched := front ELSE back := current END;
			front := current; Mark (current);
		ELSE
			previous := current;
		END;
		current := next;
	END;

	(* reinsert referenced items *)
	InsertWatched (front, back);
END MarkReferenced;

(* Insert specified items to linked list of watched pointers. *)
PROCEDURE InsertWatched (first {UNTRACED}, last {UNTRACED}: BaseTypes.Pointer);
VAR value {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF last = NIL THEN RETURN END;
	LOOP
		value := CAS (firstWatched, NIL, NIL);
		last.nextWatched := value;
		IF CAS (firstWatched, value, first) = value THEN EXIT END;
		CPU.Backoff;
	END;
END InsertWatched;

(** Disposes all unmarked pointers up to the specified garbage collection cycle. *)
PROCEDURE Sweep (first {UNTRACED}: BaseTypes.Pointer; cycle: LONGWORD);
VAR current {UNTRACED}, previous {UNTRACED}, next {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCHECKED}
	(* traverse linked list and remove unmarked items *)
	current := first; previous := NIL;
	WHILE current # watchedSentinel DO
		next := current.nextWatched;
		ASSERT (next # NIL);
		IF current.cycle - cycle <= 0 THEN
			IF previous # NIL THEN previous.nextWatched := next ELSE first := next END;
			DISPOSE (current);
		ELSE
			previous := current;
		END;
		current := next;
	END;

	(* reinsert marked items *)
	InsertWatched (first, previous);
END Sweep;

(** Initializes the module and its resources. *)
PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	NEW (markedSentinel); markedSentinel.nextWatched := markedSentinel; firstMarked := markedSentinel;
	NEW (watchedSentinel); watchedSentinel.nextWatched := watchedSentinel; firstWatched := watchedSentinel;
END Initialize;

(** Terminates the module and disposes its resources and all remaining pointers that have been registered using the GarbageCollector.Watch procedure. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
VAR current {UNTRACED}, next {UNTRACED}: BaseTypes.Pointer;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE firstWatched # watchedSentinel DO
		current := firstWatched;
		firstWatched := watchedSentinel;
		REPEAT
			next := current.nextWatched;
			ASSERT (next # NIL);
			DISPOSE (current);
			current := next;
		UNTIL current = watchedSentinel;
	END;
	DISPOSE (markedSentinel);
	DISPOSE (watchedSentinel);
END Terminate;

END GarbageCollector.
