(* Generic trap handling *)
(* Copyright (C) Florian Negele *)

MODULE Traps;

IMPORT Runtime, Activities, Machine, Streams, Reflection, TrapWriters;

CONST
	RecursiveLimit = 2;		(* normally 1 or 2 - how many recursive traps to display before stopping *)
	TestTrap = TRUE;

VAR
	trapState: ARRAY Machine.MaxCPU OF LONGINT;	(* indexed by Machine.ID() *)

PROCEDURE HandleTrap (number: SIZE);
VAR frame {UNTRACED}: POINTER {UNSAFE} TO RECORD descriptor, previous, caller, parameters: ADDRESS END; w: Streams.Writer; id: SIZE;
BEGIN
	w := TrapWriters.GetWriter();
	w.Update;	(* flush previous output stuck in global writer w *)
	w.Char(1X);	(* "start of trap" *)
	id := Machine.ID();
	INC(trapState[id]);
	IF trapState[id] > RecursiveLimit THEN
		w.String(" [Recursive TRAP]")
	ELSE
		(* output first line *)
		w.String("TRAP "); w.Int(number, 1);
		w.String(" ["); w.Int(trapState[id], 1); w.String("]");
		CASE number OF
			-14:	(* page fault *)
			|0: w.String(" division error")
			|1: w.String(" WITH guard failed")
			|2: w.String(" CASE invalid")
			|3: w.String(" RETURN missing")
			|4: w.String(" integer overflow")
			|5: w.String(" implicit type guard failed")
			|6: w.String(" type guard failed")
			|7: w.String(" index out of range")
			|8: w.String(" ASSERT failed")
			|9: w.String(" array dimension error")
			|14: w.String(" out of memory")
			|16: w.String(" procedure returned")
			|17: w.String(" nil pointer access")
			ELSE
				IF (number > MAX(INTEGER)+1) OR (number < MIN(INTEGER)) THEN
					w.String(" module freed?")
				END
		END;
		w.Ln; w.String("System: "); w.String(Machine.version); w.String(" Kernel_CRC=");(* w.Hex(SystemVersion.BootCRC,8);*)
		w.Ln;
		w.String( "StackTraceBack:" );  w.Ln;
		frame := ADDRESS OF frame + SIZE OF ADDRESS; frame := frame.previous;
		Reflection.StackTraceBack(w, frame.caller, frame.previous, ADDRESS OF frame + Activities.MaximumStackSize, TRUE, FALSE);
	END;
	w.String("---------------------------------"); w.Ln;
	w.Char(02X);	(* "end of trap" *)
	w.Update;
	TrapWriters.Trapped();
	trapState[id] := 0
END HandleTrap;

PROCEDURE Init;
VAR s: ARRAY 8 OF CHAR;
BEGIN
	IF TestTrap THEN
		Machine.GetConfig("TestTrap", s);
		IF s[0] = "1" THEN HALT(98) END
	END;
	Runtime.trapHandler := HandleTrap;
	IF TestTrap & (s[0] = "2") THEN HALT(99) END
END Init;

BEGIN
	Init
END Traps.
