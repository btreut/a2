(* Windows runtime support for processors *)
(* Copyright (C) Florian Negele *)

MODULE Processors;

IMPORT Kernel32;

(** Indicates the maximal number of logical processors that are supported by the system. *)
CONST Maximum* = MAX (SET) - MIN (SET) + 1;

(** Holds the actual number of processors in the system. *)
VAR count-: SIZE;

VAR affinityMask: SET;
VAR event: Kernel32.HANDLE;
VAR thread: ARRAY Maximum OF Kernel32.HANDLE;

(** Returns the unique index of the processor executing this procedure call. *)
PROCEDURE GetCurrentIndex- EXTERN "Activities.GetCurrentProcessorIndex" (): SIZE;

(** Suspends the execution of the current processor. *)
(** A suspended processor must be resumed by a call to the ResumeAnyProcessor procedure. *)
PROCEDURE SuspendCurrentProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.WaitForSingleObject (event, Kernel32.Infinite) # Kernel32.WaitFailed);
END SuspendCurrentProcessor;

(** Resumes the execution of all suspended processors. *)
PROCEDURE ResumeAllProcessors-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.SetEvent (event) # 0);
	ASSERT (Kernel32.ResetEvent (event) # 0);
END ResumeAllProcessors;

(** Starts the execution of all available processors. *)
PROCEDURE StartAll-;
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO Maximum - 1 DO
		IF thread[i] # NIL THEN
			ASSERT (Kernel32.ResumeThread (thread[i]) # -1);
		END;
	END;
END StartAll;

(* Start routine for each Windows thread. *)
PROCEDURE {WINAPI} Start (lpParameter {UNTRACED}: ANY): LONGINT;
PROCEDURE Execute EXTERN "Activities.Execute" (procedure: PROCEDURE);
PROCEDURE Idle EXTERN "Activities.Idle";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Kernel32.InstallExceptionHandler;
	Execute (Idle);
	Kernel32.ExitThread(0);
END Start;

(** Initializes the module by enumerating all available processors. *)
(** The number of concurrent threads corresponds to the number of slots in the affinity mask of the current process. *)
PROCEDURE Initialize-;
VAR systemAffinityMask: SET; i: SIZE; handle: Kernel32.HANDLE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	event := Kernel32.CreateEvent (NIL, Kernel32.True, Kernel32.False, NIL);
	ASSERT (event # Kernel32.InvalidHandleValue);

	ASSERT (Kernel32.GetProcessAffinityMask (Kernel32.GetCurrentProcess (), ADDRESS OF affinityMask, ADDRESS OF systemAffinityMask) # 0);

	count := 0;
	FOR i := 0 TO Maximum - 1 DO
		IF i IN affinityMask THEN
			INC (count);

			IF count = 1 THEN
				handle := Kernel32.GetCurrentThread ();
				thread[i] := NIL;
			ELSE
				handle := Kernel32.CreateThread (NIL, 0, Start, NIL, {Kernel32.CreateSuspended}, NIL);
				ASSERT (handle # Kernel32.InvalidHandleValue);
				thread[i] := handle;
			END;

			ASSERT (Kernel32.SetThreadAffinityMask (handle, {i}) # {});
		ELSE
			thread[i] := NIL;
		END;
	END;
END Initialize;

(** Terminates the module and waits for all other processors to stop their execution. *)
PROCEDURE Terminate-;
VAR i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO Maximum - 1 DO
		IF thread[i] # NIL THEN
			ASSERT (Kernel32.WaitForSingleObject (thread[i], Kernel32.Infinite) # Kernel32.WaitFailed);
			ASSERT (Kernel32.CloseHandle (thread[i]) # 0);
		END;
	END;
	ASSERT (Kernel32.CloseHandle (event) # 0);
END Terminate;

END Processors.
