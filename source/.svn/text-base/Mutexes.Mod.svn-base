(* Runtime support for mutexes *)
(* Copyright (C) Florian Negele *)

(** The Mutexes module provides synchronization objects called mutexes. *)
MODULE Mutexes;

IMPORT Activities, Queues;

(** Represents a synchronization object which acquires mutually exclusive access to shared resources. *)
TYPE Mutex* = RECORD
	blockedQueue: Queues.Queue; (* maintains a queue of all activities that failed to acquire the mutex *)
	owner {UNTRACED} := NIL: Activities.Activity; (* stores the activity that has currently acquired the mutex, or NIL if it is not acquired *)
END;

(** Acquires mutual exclusive access to shared resources that are associated with a mutex. *)
(** If the mutex is currently acquired by some other activity, this procedure waits until it gets exclusive access to it. *)
(** A call to this procedure guarantees mutual exclusive access which has to be released by a subsequent call to the Mutexes.Release procedure. *)
PROCEDURE Acquire- (VAR mutex: Mutex);
VAR currentActivity {UNTRACED}, nextActivity: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := Activities.GetCurrentActivity ();

	(* repeated tries of atomicly changing the owner from NIL to the current activity guarantees mutual exclusion *)
	WHILE CAS (mutex.owner, NIL, currentActivity) # NIL DO

		(* suspend and enqueue the current activity on behalf of its successor *)
		IF Activities.Select (nextActivity, Activities.IdlePriority) THEN
			Activities.SwitchTo (nextActivity, Enqueue, ADDRESS OF mutex);
			Activities.FinalizeSwitch;
		END;
	END;
END Acquire;

(* This procedure is a switch finalizer and is executed by a different activity *)
PROCEDURE Enqueue (previous {UNTRACED}: Activities.Activity; mutex {UNTRACED}: POINTER {UNSAFE} TO Mutex);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* the mutex could have already been released at this point, *)
	(* and enqueuing the previous activity might cause it to remain suspended forever *)
	(* the only safe way of inspecting the owner of the mutex is after enqueueing, *)
	(* since the mutex can potentially be released at any time during that operation *)
	Queues.Enqueue (previous, mutex.blockedQueue);

	(* if the mutex was released before enqueueing, the owner of the mutex must have changed to NIL *)
	(* if the owner is still NIL at this point and the releasing activity did not resume any waiting activity, we do that on behalf of it now *)
	(* otherwise, there is either an activity that has acquired the mutex or there is a resumed activity that will try to aquire the mutex *)
	(* in all of these cases, it is guaranteed that there is a running activity that will eventually resume the previous one *)
	IF CAS (mutex.owner, NIL, NIL) = NIL THEN
		IF Queues.Dequeue (item, mutex.blockedQueue) THEN Activities.Resume (item(Activities.Activity)) END;
	END;
END Enqueue;

(** Releases the mutual exclusive access to shared resources that are associated with a mutex. *)
(** This procedure must be called once after each corresponding call to the Mutexes.Acquire procedure. *)
(** A mutex may not be released if it was not acquired by the same activity beforehand. *)
PROCEDURE Release- (VAR mutex: Mutex);
VAR currentActivity {UNTRACED}: Activities.Activity; item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := Activities.GetCurrentActivity ();

	(* reset the owner and check for consistency *)
	ASSERT (CAS (mutex.owner, currentActivity, NIL) = currentActivity);

	(* the mutex could have already been acquired again at this point, *)
	(* but resuming does not hurt since any resumed activity will wait again while acquiring *)
	IF Queues.Dequeue (item, mutex.blockedQueue) THEN Activities.Resume (item(Activities.Activity)) END;
END Release;

END Mutexes.
