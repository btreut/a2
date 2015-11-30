MODULE PreciseTimer; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Precise timer"; *)

IMPORT
	SYSTEM, Kernel32, Kernel;

VAR
	nFrequency : HUGEINT;
	Ready : BOOLEAN;
	
PROCEDURE EsimateFrequency;
VAR
	res : Kernel32.BOOL;
BEGIN
	res := Kernel32.QueryPerformanceFrequency(SYSTEM.VAL(Kernel32.LargeInteger, nFrequency));
	Ready := res > 0
END EsimateFrequency;

PROCEDURE GetTicks*(): HUGEINT;
VAR
	nTicks : HUGEINT;
	res : Kernel32.BOOL;
BEGIN
	IF Ready THEN
		res := Kernel32.QueryPerformanceCounter(SYSTEM.VAL(Kernel32.LargeInteger, nTicks));
		RETURN nTicks
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