MODULE BenchInterrupts; (** AUTHOR "staubesv"; PURPOSE "Interrupt latency benchmarks"; *)
(**

 	Non-comrehensive list of aspects to be considered:
 	-	The garbage collector prohibits interrupts while running. Depending on the current state of the heap, this can
 		introduce delays in the order of seconds
 	- 	There can be multipe handlers per interrupt vector
 	-	The Machine.SoftInt is a temporary interrupt vector that is potentially used by other applications
 	-	Result is dependent on other interrupts that have a higher priority and can interrupt our handler

*)

IMPORT
	SYSTEM,
	Machine, Heaps, Streams, Commands, MathL;

CONST
	(*	Interrupt vector number for 1st level interrupt handler benchmark
		This is a temporary interrupt vector number that is potentially used for different purposes *)
	InterruptVectorNumber = Machine.SoftInt;

	MinNofSamples = 1000;
	MaxNofSamples = 1000000;

VAR
	mhz : LONGINT;

	start, stop : HUGEINT;
	ngc : LONGINT;
	data : POINTER TO ARRAY OF LONGINT;

PROCEDURE InterruptHandler(VAR state: Machine.State);
BEGIN
	stop := Machine.GetTimer();
END InterruptHandler;

(* Software interrupt call *)
PROCEDURE -SoftwareInterrupt;
CODE {SYSTEM.AMD64}
	INT InterruptVectorNumber
END SoftwareInterrupt;

(** Start the 1st Level Interrupt Handler latency benchmark *)
PROCEDURE Bench*(context : Commands.Context); (** [nofSamples] ~ *)
VAR nofSamples, index, oldNgc, ignore : LONGINT;
BEGIN {EXCLUSIVE}
	context.arg.GetInteger(nofSamples, FALSE);
	IF (nofSamples < MinNofSamples) THEN nofSamples := MinNofSamples;
	ELSIF (nofSamples > MaxNofSamples) THEN nofSamples := MaxNofSamples;
	END;
	context.out.String("Starting 1st level interrupt handler latency benchmark (");
	context.out.Int(nofSamples, 0); context.out.String(" samples) ... ");
	context.out.Update;
	NEW(data, nofSamples);
	Machine.InstallHandler(InterruptHandler, InterruptVectorNumber);
	ignore := Machine.AcquirePreemption();
	oldNgc := Heaps.Ngc;
	FOR index := 0 TO LEN(data)-1 DO
		start := Machine.GetTimer();
		SoftwareInterrupt;
		data[index] := SHORT(stop - start);
	END;
	ngc := Heaps.Ngc - oldNgc;
	Machine.ReleasePreemption;
	Machine.RemoveHandler(InterruptHandler, InterruptVectorNumber);
	context.out.String("done."); context.out.Ln;
END Bench;

PROCEDURE CyclesToMs(cycles : HUGEINT; mhz : LONGINT) : LONGREAL;
BEGIN
	RETURN LONGREAL(cycles) / (1000*mhz);
END CyclesToMs;

PROCEDURE ShowMs(cycles : HUGEINT; out : Streams.Writer);
BEGIN
	IF (mhz # 0) THEN
		out.String(" ("); out.FloatFix(CyclesToMs(cycles, mhz), 0, 6, 0); out.String(" ms)");
	END;
END ShowMs;

(** Show the results of the last benchmark run *)
PROCEDURE Show*(context : Commands.Context); (** mhz ~ *)
VAR
	nofSamples, min, avg, max, i : LONGINT; sum : HUGEINT;
	diff, diffSum, standardDeviation : LONGREAL;
BEGIN {EXCLUSIVE}
	context.arg.GetInteger(mhz, FALSE);
	IF (data # NIL) THEN
		nofSamples := LEN(data);
		min := MAX(LONGINT); max := MIN(LONGINT); sum := 0;
		(* calculate min, max and sum *)
		FOR i := 0 TO LEN(data)-1 DO
			IF (data[i] < min) THEN min := data[i];
			ELSIF (data[i] > max) THEN max := data[i];
			END;
			sum := sum + data[i];
		END;
		avg := SHORT(sum DIV nofSamples);
		(* calculate standard deviation *)
		diffSum := 0;
		FOR i := 0 TO LEN(data)-1 DO
			diff := avg - data[i];
			diffSum := diffSum + (diff * diff);
		END;
		standardDeviation := MathL.sqrt(diffSum / nofSamples);
		context.out.String("NofSamples: "); context.out.Int(nofSamples, 0); context.out.Ln;
		context.out.String("Nof GC runs while benchmarking: "); context.out.Int(ngc, 0); context.out.Ln;
		context.out.String("CPU clock rate: ");
		IF (mhz # 0) THEN context.out.Int(mhz, 0); context.out.String(" MHz"); ELSE context.out.String("Unknown"); END;
		context.out.Ln;
		context.out.String("Interrupt Latency in CPU cycles: "); context.out.Ln;
		context.out.String("Min: "); context.out.Int(min, 0); ShowMs(min, context.out); context.out.Ln;
		context.out.String("Max: "); context.out.Int(max, 0); ShowMs(max, context.out); context.out.Ln;
		context.out.String("Avg: "); context.out.Int(avg, 0); ShowMs(avg, context.out); context.out.Ln;
		context.out.String("Standard Deviation: "); context.out.FloatFix(standardDeviation, 0, 0, 0); context.out.Ln;
	ELSE
		context.out.String("No data available."); context.out.Ln;
	END;
END Show;

END BenchInterrupts.

SystemTools.Free BenchInterrupts ~

BenchInterrupts.Bench 1000000 ~

BenchInterrupts.Show 2000 ~
