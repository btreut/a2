(* Runtime support for exclusive blocks *)
(* Copyright (C) Florian Negele *)

(** The ExclusiveBlocks module implements object monitors and provides runtime support for block statements marked as exclusive. *)
MODULE ExclusiveBlocks;

IMPORT SYSTEM, Activities, BaseTypes, Queues;

(** Enters an exclusive region by acquiring the monitor of the corresponding object. *)
(** If the monitor is currently acquired by another activity, this procedure waits until it gets exclusive access to it. *)
(** The compiler calls this procedure at the beginning of each block statement marked as exclusive. *)
(** The specified nesting level keeps track of how many times the same activity has acquired the monitor. *)
PROCEDURE Enter- (object {UNTRACED}: BaseTypes.Object; nestingLevel: SIZE);
VAR monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor; currentActivity {UNTRACED}, nextActivity: Activities.Activity; previousOwner {UNTRACED}: OBJECT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (object # NIL);
	monitor := object.monitor;
	ASSERT (monitor # NIL);

	(* repeated tries of atomically changing the owner from NIL to the current activity guarantees mutual exclusion *)
	currentActivity := Activities.GetCurrentActivity ();
	LOOP
		previousOwner := CAS (monitor.owner, NIL, currentActivity);
		IF (previousOwner = NIL) OR (previousOwner = currentActivity) THEN EXIT END;

		(* suspend and enqueue the current activity on behalf of its successor *)
		IF Activities.Select (nextActivity, Activities.IdlePriority) THEN
			Activities.SwitchTo (nextActivity, Enqueue, monitor);
			Activities.FinalizeSwitch;
		END;
	END;

	(* keep track of nested acquisitions *)
	INC (monitor.nestingLevel, nestingLevel);
END Enter;

(* This procedure is a switch finalizer and is executed by a different activity *)
PROCEDURE Enqueue (previousActivity {UNTRACED}: Activities.Activity; monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* the monitor could have already been released at this point, *)
	(* and enqueueing the previous activity might cause it to remain suspended forever *)
	(* the only safe way of inspecting the owner of the monitor is after enqueueing, *)
	(* since the monitor can potentially be released at any time during that operation *)
	Queues.Enqueue (previousActivity, monitor.blockedQueue);

	(* if the monitor was released before enqueueing, the owner of the monitor must have changed to NIL *)
	(* if the owner is still NIL at this point and the releasing activity did not resume any waiting activity, we do that on behalf of it now *)
	(* otherwise, there is either an activity that has acquired the monitor or there is a resumed activity that will try to acquire the monitor *)
	(* in all of these cases, it is guaranteed that there is a running activity that will eventually resume the previous one *)
	IF CAS (monitor.owner, NIL, NIL) = NIL THEN
		IF Queues.Dequeue (item, monitor.blockedQueue) THEN Activities.Resume (item(Activities.Activity)) END;
	END;
END Enqueue;

(** Exits an exclusive region by releasing the monitor of the corresponding object if its nesting level reaches zero. *)
(** The compiler calls this procedure at the end of each block statement marked as exclusive or during the execution of a RETURN statement inside such blocks. *)
(** A monitor may not be released if it was not acquired by the same activity beforehand. *)
PROCEDURE Exit- (object {UNTRACED}: BaseTypes.Object; nestingLevel: SIZE);
VAR monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor; currentActivity {UNTRACED}: Activities.Activity; item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (object # NIL);
	monitor := object.monitor;
	ASSERT (monitor # NIL);
	currentActivity := Activities.GetCurrentActivity ();
	ASSERT (monitor.owner = currentActivity);

	(* update nesting level for exiting without releasing *)
	DEC (monitor.nestingLevel, nestingLevel);
	IF monitor.nestingLevel # 0 THEN RETURN END;

	(* release the monitor *)
	IF Queues.Dequeue (item, monitor.waitingQueue) OR Queues.Dequeue (item, monitor.blockedQueue) THEN
		(* transfer the ownership to any activity waiting inside an await statement *)
		ASSERT (CAS (monitor.owner, currentActivity, item(Activities.Activity)) = currentActivity);
		Activities.Resume (item(Activities.Activity));
	ELSE
		(* reset the owner and check for consistency *)
		ASSERT (CAS (monitor.owner, currentActivity, NIL) = currentActivity);

		(* the monitor could have already been acquired again at this point, *)
		(* but resuming does not hurt since any resumed activity will wait again while acquiring *)
		IF Queues.Dequeue (item, monitor.blockedQueue) THEN Activities.Resume (item(Activities.Activity)) END;
	END;
END Exit;

(** Temporarily releases an acquired monitor and waits for other activities to modify the object by entering and exiting an exclusive region. *)
(** The compiler calls this procedure whenever the repeated evaluation of an AWAIT statement yields an unsatisfied condition. *)
PROCEDURE Await- (object {UNTRACED}: BaseTypes.Object);
VAR monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor; currentActivity {UNTRACED}, nextActivity: Activities.Activity; nestingLevel: SIZE; item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (object # NIL);
	monitor := object.monitor;
	ASSERT (monitor # NIL);
	currentActivity := Activities.GetCurrentActivity ();
	ASSERT (monitor.owner = currentActivity);

	(* reset the nesting level *)
	nestingLevel := monitor.nestingLevel; monitor.nestingLevel := 0;

	(* check for activities waiting in an await statement that need to be resumed *)
	IF Queues.Dequeue (item, monitor.waitingQueue) & (item # monitor.waitingSentinel) THEN
		(* keep track of the first activity waiting in an await statement *)
		IF monitor.waitingSentinel = NIL THEN monitor.waitingSentinel := currentActivity END;

		(* transfer the ownership to another activity waiting inside an await statement *)
		Activities.SwitchTo (item(Activities.Activity), Transfer, monitor);
		Activities.FinalizeSwitch;
	ELSE
		(* enqueue the first waiting activity again in order to prevent loops *)
		monitor.waitingSentinel := NIL;
		IF item # NIL THEN Queues.Enqueue (item, monitor.waitingQueue) END;

		IF Queues.Dequeue (item, monitor.blockedQueue) THEN
			(* transfer the ownership to any activity waiting for exclusive access *)
			Activities.SwitchTo (item(Activities.Activity), Transfer, monitor);
			Activities.FinalizeSwitch;
		ELSIF Activities.Select (nextActivity, Activities.IdlePriority) THEN
			(* release the owner and suspend the activity on behalf of its successor *)
			Activities.SwitchTo (nextActivity, Release, monitor);
			Activities.FinalizeSwitch;
		ELSE
			(* just release the owner if there is temporarily no other activity ready to be run *)
			ASSERT (CAS (monitor.owner, currentActivity, NIL) = currentActivity);
			Activities.Switch;
		END;
	END;

	(* acquire the monitor again using the previous nesting level *)
	Enter (object, nestingLevel);
END Await;

(* Enqueues the previous activity in the waiting queue of a monitor and transfers its ownership to the currently executing activity. *)
PROCEDURE Transfer (previousActivity {UNTRACED}: Activities.Activity; monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor);
VAR currentActivity {UNTRACED}: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	currentActivity := Activities.GetCurrentActivity ();
	Queues.Enqueue (previousActivity, monitor.waitingQueue);
	ASSERT (CAS (monitor.owner, previousActivity, currentActivity) = previousActivity);
END Transfer;

(* Enqueues the previous activity in the waiting queue of a monitor and releases its owner. *)
PROCEDURE Release (previousActivity {UNTRACED}: Activities.Activity; monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue (previousActivity, monitor.waitingQueue);
	ASSERT (CAS (monitor.owner, previousActivity, NIL) = previousActivity);

	(* the monitor could have already been acquired again at this point, *)
	(* but resuming does not hurt since any resumed activity will wait again while acquiring *)
	IF Queues.Dequeue (item, monitor.blockedQueue) THEN Activities.Resume (item(Activities.Activity)) END;
END Release;

(** Guarantees that all other activities awaiting a condition will evaluate it again when the current activity leaves the exclusive region. *)
(** The compiler calls this procedure after the evaluation of an AWAIT statement has yielded a satisfied condition. *)
PROCEDURE FinalizeAwait- (object {UNTRACED}: BaseTypes.Object);
VAR monitor {UNTRACED}: POINTER {UNSAFE} TO BaseTypes.Monitor; currentActivity {UNTRACED}: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (object # NIL);
	monitor := object.monitor;
	ASSERT (monitor # NIL);
	currentActivity := Activities.GetCurrentActivity ();
	ASSERT (monitor.owner = currentActivity);

	(* reset the first activity waiting in an await statement *)
	monitor.waitingSentinel := NIL;
END FinalizeAwait;

END ExclusiveBlocks.
