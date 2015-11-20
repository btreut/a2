(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE BenchObjCount;	(* pjm *)

(* Test how many active objects can be created. *)

IMPORT SYSTEM, KernelLog, Machine, Kernel;

TYPE
	Tester = OBJECT
		VAR next: Tester; stop: BOOLEAN;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			stop := TRUE
		END Stop;

		PROCEDURE &Init*;
		BEGIN
			stop := FALSE
		END Init;

	BEGIN {ACTIVE, EXCLUSIVE}
		AWAIT(stop)
	END Tester;

PROCEDURE Report(CONST msg: ARRAY OF CHAR; n, time: LONGINT);
BEGIN
	KernelLog.Enter;
	KernelLog.Int(n, 1); KernelLog.String(" threads "); KernelLog.String(msg); KernelLog.String(", ");
	KernelLog.Int(time, 1); KernelLog.String("ms");
	IF n # 0 THEN
		KernelLog.String(", "); KernelLog.Int(ENTIER(time/n*1000), 1); KernelLog.String("us/thread")
	END;
	KernelLog.Exit
END Report;

PROCEDURE Max*;
VAR n, time: LONGINT; total, low, high: SIZE; root, t: Tester;
BEGIN
	n := Kernel.GetTicks();
	REPEAT time := Kernel.GetTicks() UNTIL time # n;

	n := 0; root := NIL;
	LOOP
		Machine.GetFreeK(total, low, high);
		IF low+high < 1024 THEN EXIT END;
		NEW(t); t.next := root; root := t;
		INC(n)
	END;
	time := ENTIER((Kernel.GetTicks() - time)/Kernel.second*1000);
	Report("created", n, time);

	time := Kernel.GetTicks();
	WHILE root # NIL DO root.Stop; t := root; root := root.next; t.next := NIL END;
	time := ENTIER((Kernel.GetTicks() - time)/Kernel.second*1000);
	Report("stopped", n, time);

	time := Kernel.GetTicks();
	Kernel.GC;
	time := ENTIER((Kernel.GetTicks() - time)/Kernel.second*1000);
	Report("collected", n, time);	(* not accurate, because interrupts currently disabled during GC *)

	time := Kernel.GetTicks();
	(*Heaps.CallFinalizers;*)	(* safe, if we are in an Oberon command *)
	time := ENTIER((Kernel.GetTicks() - time)/Kernel.second*1000);
	Report("finalized", n, time)
END Max;

END BenchObjCount.

System.Free BenchObjCount ~

System.State Machine ~

System.OpenKernelLog

Configuration.DoCommands
BenchObjCount.Max
System.Time start
System.Collect
System.Time lap
System.Watch
~