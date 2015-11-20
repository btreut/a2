(* Runtime support for awaiting interrupts *)
(* Copyright (C) Florian Negele *)


(** The Interrupts module provides a hardware-independent synchronisation primitive for awaiting the occurrence of interrupts. *)
(** Activities waiting for an interrupt are suspended and resumed as soon as the interrupt occurred. *)
MODULE Interrupts;

IMPORT Activities, Counters, CPU, Queues;

(** Represents an interrupt. *)
TYPE Interrupt* = RECORD
	timestamp: SIZE;
	index: SIZE;
END;

VAR timestamps: ARRAY CPU.Interrupts OF SIZE;
VAR awaitingQueues: ARRAY CPU.Interrupts OF Queues.AlignedQueue;
VAR previousHandlers: ARRAY CPU.Interrupts OF CPU.InterruptHandler;
VAR processors: ARRAY CPU.Interrupts OF Activities.Activity;

(** Installs an interrupt to wait for. *)
(** The actual meaning of the specified interrupt number identifying the interrupt depends on the hardware. *)
PROCEDURE Install- (VAR interrupt: Interrupt; index: SIZE);
VAR processor: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (index < CPU.Interrupts);

	(* install the interrupt handler if necessary *)
	IF CAS (processors[index], NIL, NIL) = NIL THEN
		processor := Activities.CreateVirtualProcessor ();
		IF CAS (processors[index], NIL, processor) = NIL THEN
			previousHandlers[index] := CPU.InstallInterrupt (Handle, index);
		ELSE
			DISPOSE (processor);
		END;
	END;

	(* setup the interrupt *)
	interrupt.index := index;
	interrupt.timestamp := CAS (timestamps[index], 0, 0);
END Install;

(** Waits for the specified interrupt to occur. *)
(** This procedure returns as soon as the interrupt has to be handled, or if the wait was cancelled by a call to the Interrupts.Cancel procedure. *)
PROCEDURE Await- (VAR interrupt: Interrupt);
VAR nextActivity: Activities.Activity;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid argument *)
	ASSERT (interrupt.index < CPU.Interrupts);

	(* check whether an interrupt was missed *)
	IF CAS (timestamps[interrupt.index], 0, 0) = interrupt.timestamp THEN
		
		(* this is a workaround for a buggy USB driver that sends too many interrupts *)
		IF interrupt.index # CPU.IRQ0 (* timer interrupt *) THEN CPU.EnableIRQ(interrupt.index) END;

		(* inform the scheduler that there is at least one activity awaiting interrupts *)
		Counters.Inc (Activities.awaiting);

		(* wait for the actual interrupt *)
		WHILE CAS (timestamps[interrupt.index], 0, 0) = interrupt.timestamp DO
			REPEAT UNTIL Activities.Select (nextActivity, Activities.IdlePriority);
			Activities.SwitchTo (nextActivity, Enqueue, ADDRESS OF interrupt);
			Activities.FinalizeSwitch;
		END;

		(* inform the scheduler that there is one less activity awaiting interrupts *)
		Counters.Dec (Activities.awaiting);

		(* notify next waiting activity *)
		NotifyNext (ADDRESS OF awaitingQueues[interrupt.index]);
	END;

	(* update the local timestamp *)
	interrupt.timestamp := CAS (timestamps[interrupt.index], 0, 0);
END Await;

(* This procedure is a switch finalizer and is executed by a different activity. *)
PROCEDURE Enqueue (previous {UNTRACED}: Activities.Activity; interrupt {UNTRACED}: POINTER {UNSAFE} TO Interrupt);
VAR item: Queues.Item; index, timestamp: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	index := interrupt.index; timestamp := interrupt.timestamp;
	Queues.Enqueue (previous, awaitingQueues[index]);
	IF CAS (timestamps[index], 0, 0) = timestamp THEN RETURN END;
	WHILE Queues.Dequeue (item, awaitingQueues[index]) DO
		Activities.Resume (item(Activities.Activity));
	END;
END Enqueue;

(* Handler for a specific interrupt. *)
PROCEDURE Handle (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* forward the interrupt *)
	IF previousHandlers[index] # NIL THEN previousHandlers[index] (index) END;

	(* update the global timestamp *)
	INC (timestamps[index]);

	(* this is a workaround for a buggy USB driver that sends too many interrupts *)
	IF index # CPU.IRQ0 (* timer interrupt *) THEN CPU.DisableIRQ(index) END;

	(* this handler might have interrupted the execution of code in an uncooperative block *)
	(* executing the very same code more than once is semantically only valid when done by a different processor *)
	(* the same effect can be achieved if the current activity temporarily pretends to be executed by a different processor *)
	Activities.CallVirtual (NotifyNext, ADDRESS OF awaitingQueues[index], processors[index]);
END Handle;

(* Notifies the next activity in the awaiting queue of an interrupt. *)
PROCEDURE NotifyNext (awaitingQueue {UNTRACED}: POINTER {UNSAFE} TO Queues.Queue);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF Queues.Dequeue (item, awaitingQueue^) THEN
		Activities.Resume (item(Activities.Activity));
	END;
END NotifyNext

(** Resume all activities that are waiting for the specified interrupt. *)
PROCEDURE Cancel- (VAR interrupt: Interrupt);
VAR item: Queues.Item;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (interrupt.index < CPU.Interrupts);
	interrupt.timestamp := CAS (timestamps[interrupt.index], 0, 0) - 1;
	WHILE Queues.Dequeue (item, awaitingQueues[interrupt.index]) DO
		Activities.Resume (item(Activities.Activity));
	END;
END Cancel;

(** Terminates the module and disposes all resources associated with interrupts. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
VAR index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR index := 0 TO CPU.Interrupts - 1 DO
		CPU.DisableInterrupt (index);
		Queues.Dispose (awaitingQueues[index]);
		IF processors[index] # NIL THEN DISPOSE (processors[index]) END;
	END;
END Terminate;

END Interrupts.
