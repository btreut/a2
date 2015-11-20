(* APIC runtime support for processors *)
(* Copyright (C) Florian Negele *)

(** The Processors module represents all logical processors of the system. *)
MODULE Processors;

IMPORT APIC, Counters, CPU;

(** Indicates the maximal number of logical processors that are supported by the system. *)
CONST Maximum* = APIC.Processors + 4;

CONST InitMessage = APIC.INIT + APIC.Assert + APIC.AllExcludingSelf;
CONST StartupMessage = APIC.STARTUP + APIC.Assert + APIC.AllExcludingSelf;
CONST NonmaskableMessage = APIC.NMI + APIC.Assert + APIC.AllExcludingSelf;

(** Holds the actual number of processors in the system. *)
VAR count-: SIZE;

VAR running: Counters.AlignedCounter; (* counts the number of application processors currently running *)

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentIndex- EXTERN "Activities.GetCurrentProcessorIndex" (): SIZE;

(** Suspends the execution of the current processor. *)
(** A suspended processor must be resumed by a call to the Processors.ResumeAnyProcessor procedure. *)
(** @topic Scheduling *)
PROCEDURE SuspendCurrentProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	APIC.AwaitInterrupt;
END SuspendCurrentProcessor;

(** Resumes the execution of a single suspended processor. *)
(** @topic Scheduling *)
PROCEDURE ResumeAllProcessors-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	APIC.SendInterrupt (NonmaskableMessage, {});
END ResumeAllProcessors;

(** Starts the execution of all available processors. *)
(** @topic Scheduling *)
PROCEDURE StartAll-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	APIC.SendInterrupt (NonmaskableMessage, {});
END StartAll;

PROCEDURE {NORETURN} Start;
PROCEDURE InitProcessor EXTERN "Machine.InitApplicationProcessor";
PROCEDURE Execute EXTERN "Activities.Execute" (procedure: PROCEDURE);
PROCEDURE Idle EXTERN "Activities.Idle";
VAR value: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (count, 0, 0);
		IF value = APIC.Processors THEN CPU.Halt END;
		IF CAS (count, value, value + 1) = value THEN EXIT END;
		CPU.Backoff;
	END;
	InitProcessor;
	Counters.Inc (running);
	APIC.AwaitInterrupt; Execute (Idle);
	Counters.Dec (running);
	CPU.Halt;
END Start;

PROCEDURE AwaitStartups;
VAR current := 0, previous := 0, counter := 0: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT
		current := Counters.Read (running); INC (counter);
		IF current # previous THEN previous := current; counter := 0 END;
	UNTIL counter = 100000;
END AwaitStartups;

(** Initializes the module by enumerating all available processors. *)
(** @topic Runtime Call *)
PROCEDURE Initialize-;
PROCEDURE InitProcessor EXTERN "Machine.InitBootProcessor";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	InitProcessor;
	count := 1;
	APIC.Initialize;
	APIC.CopyBootCode (Start);
	APIC.SendInterrupt (InitMessage, {});
	APIC.SendInterrupt (StartupMessage, {});
	AwaitStartups;
END Initialize;

(** Terminates the module and waits for all other processors to stop their execution. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	REPEAT UNTIL Counters.Read (running) = 0;
END Terminate;

END Processors.
