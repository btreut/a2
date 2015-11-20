(* Runtime support for high precision timer *)
(* Copyright (C) Florian Negele *)

MODULE Timer;

IMPORT CPU;

TYPE Counter* = LONGINT;

PROCEDURE GetCounter- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN CPU.ReadWord (CPU.STCLO);
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN 1000000;
END GetFrequency;

END Timer.
