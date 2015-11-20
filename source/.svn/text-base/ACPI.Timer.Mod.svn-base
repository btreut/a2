(* Runtime support for high precision timer *)
(* Copyright (C) Florian Negele *)

MODULE Timer;

IMPORT ACPI;

TYPE Counter* = LONGINT;

VAR frequency: Counter;
VAR counter {UNTRACED}: POINTER {UNSAFE} TO RECORD value: HUGEINT END;

PROCEDURE GetCounter- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} ASSERT (counter # NIL); RETURN SHORT (counter.value);
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN frequency;
END GetFrequency;

PROCEDURE Initialize-;
CONST OverallEnable = 0;
VAR hpet {UNTRACED}: POINTER {UNSAFE} TO ACPI.HPET; address: ADDRESS;
VAR period {UNTRACED}: POINTER {UNSAFE} TO RECORD value: LONGINT END; configuration {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SET END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ACPI.Initialize;
	IF ACPI.rdsp = NIL THEN RETURN END;
	hpet := ACPI.GetTable (ACPI.HPETSignature);
	IF hpet = NIL THEN RETURN END;
	address := ACPI.Convert (hpet.baseAddress.addressLow);
	period := address + SIZE OF CHAR * 004H;
	counter := address + SIZE OF CHAR * 0F0H;
	configuration := address + SIZE OF CHAR * 010H;
	frequency := SHORT (1000000000000000 DIV period.value);
	INCL (configuration.value, OverallEnable);
END Initialize;

END Timer.
