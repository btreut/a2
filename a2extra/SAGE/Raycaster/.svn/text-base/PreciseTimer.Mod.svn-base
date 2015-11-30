MODULE PreciseTimer; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Precise timer"; *)

IMPORT
	Kernel, Machine, Heaps;
	
VAR
	nFrequency : HUGEINT;
	Ready : BOOLEAN;
	
PROCEDURE EstimateCpuClockrate(VAR clockrate : HUGEINT) : BOOLEAN;
VAR
	timer : Kernel.Timer; milliTimer : Kernel.MilliTimer;
	startTime, endTime : HUGEINT;
	nbrOfGcRuns : LONGINT;
BEGIN
	NEW(timer); nbrOfGcRuns := Heaps.Ngc;
	Kernel.SetTimer(milliTimer, 1000);
	startTime := Machine.GetTimer();
	WHILE ~Kernel.Expired(milliTimer) DO
		timer.Sleep(1);
		IF nbrOfGcRuns # Heaps.Ngc THEN RETURN FALSE; END;
	END;
	endTime := Machine.GetTimer();
	IF nbrOfGcRuns # Heaps.Ngc THEN RETURN FALSE; END;
	clockrate := endTime - startTime;
	RETURN TRUE;
END EstimateCpuClockrate;

PROCEDURE EsimateFrequency;
CONST
	tries = 10;
VAR
	clockrate : HUGEINT;
	try : LONGINT;
BEGIN
	try := 1; Ready := FALSE; nFrequency := -1;
	WHILE ~Ready & (try <= tries) DO
		Ready := EstimateCpuClockrate(clockrate);
		INC(try)
	END;
	nFrequency := clockrate
END EsimateFrequency;

PROCEDURE GetTicks*(): HUGEINT;
BEGIN
	IF Ready THEN
		RETURN Machine.GetTimer()
	ELSE
		RETURN Kernel.GetTicks()
	END
END GetTicks;

PROCEDURE GetTime*(nTicks: HUGEINT): REAL;
BEGIN
	IF Ready THEN
		RETURN nTicks / nFrequency
	ELSE
		RETURN nTicks / Kernel.Second
	END
END GetTime;

BEGIN
	EsimateFrequency
END PreciseTimer.

SystemTools.Free PreciseTimer ~
PreciseTimer.Test ~