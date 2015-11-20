(* Runtime support for high precision timer
Copyright (C) Florian Negele
*)


MODULE Timer;

IMPORT Kernel32;

TYPE Counter* = LONGINT;

PROCEDURE GetCounter- (): Counter;
VAR counter: Kernel32.LargeInteger;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.QueryPerformanceCounter (counter) # 0);
	RETURN counter.LowPart;
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
VAR frequency: Kernel32.LargeInteger;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF Kernel32.QueryPerformanceFrequency (frequency) = 0 THEN RETURN 0 END;
	RETURN frequency.LowPart;
END GetFrequency;

END Timer.
