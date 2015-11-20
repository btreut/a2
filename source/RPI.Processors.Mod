(* Runtime support for Raspberry Pi *)
(* Copyright (C) Florian Negele *)

(** The Processors module represents all logical processors of the system. *)
MODULE Processors;

IMPORT SYSTEM, Counters, CPU;

(** Indicates the maximal number of logical processors that are supported by the system. *)
CONST Maximum* = 4 + CPU.Interrupts;

(** Holds the actual number of processors in the system. *)
VAR count-: SIZE;

VAR running: Counters.AlignedCounter; (* counts the number of application processors currently running *)

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentIndex- EXTERN "Activities.GetCurrentProcessorIndex" (): SIZE;

(** Suspends the execution of the current processor. *)
(** A suspended processor must be resumed by a call to the Processors.ResumeAnyProcessor procedure. *)
(** @topic Scheduling *)
PROCEDURE SuspendCurrentProcessor-;
CODE
	WFE
END SuspendCurrentProcessor;

(** Resumes the execution of a single suspended processor. *)
(** @topic Scheduling *)
PROCEDURE ResumeAllProcessors-;
CODE
	SEV
END ResumeAllProcessors;

(** Starts the execution of all available processors. *)
(** @topic Scheduling *)
PROCEDURE StartAll-;
CODE
	SEV
END StartAll;

PROCEDURE {NORETURN, NOPAF} Boot;
PROCEDURE Idle EXTERN "Activities.Idle";
PROCEDURE Execute EXTERN "Activities.Execute" (procedure: PROCEDURE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CODE
		MOV	SP, #0x8000
		MRC	P15, 0, R0, C0, C0, 5
		AND	R0, R0, #0x3
		SUB	SP, SP, R0, LSL #13
	END;
	CPU.EnableMemoryManagementUnit;
	Counters.Inc (running);
	SuspendCurrentProcessor;
	SuspendCurrentProcessor;
	Execute (Idle);
	Counters.Dec (running);
	CPU.Halt;
END Boot;

(** Initializes the module by enumerating all available processors. *)
(** @topic Runtime Call *)
PROCEDURE Initialize-;
CONST Core1Mailbox = 04000009CH; Core2Mailbox = 0400000ACH; Core3Mailbox = 0400000BCH;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPU.WriteWord (Core1Mailbox, ADDRESS OF Boot);
	CPU.WriteWord (Core2Mailbox, ADDRESS OF Boot);
	CPU.WriteWord (Core3Mailbox, ADDRESS OF Boot);
	REPEAT UNTIL Counters.Read (running) = 3;
	count := 4;
END Initialize;

(** Terminates the module and waits for all other processors to stop their execution. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT UNTIL Counters.Read (running) = 0;
END Terminate;

END Processors.
