(* Runtime environment for BIOS *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT SYSTEM, CPU, ACPI, Activities, HeapManager, Interrupts, Processors, Timer, Trace;

CONST IsNative* = TRUE;

CONST Running* = 0; ShuttingDown* = 1; Rebooting* = 2;

CONST HeapAdr = 100000H;
CONST MaxMemTop = 80000000H;

CONST TraceV24 = 2; TraceScreen = 0;
CONST TraceWidth = 80; TraceHeight = 25;
CONST TraceLen = TraceWidth * SIZEOF (INTEGER);
CONST TraceSize = TraceLen * TraceHeight;

VAR memory: SIZE;
VAR traceMode: SET;
VAR bootFlag: ADDRESS;
VAR clock: LONGINT;
VAR status-: WORD;
VAR memTop: ADDRESS;
VAR traceBase: ADDRESS;
VAR heap: HeapManager.Heap;
VAR config: ARRAY 2048 OF CHAR;
VAR initRegs: ARRAY 2OF ADDRESS;
VAR tracePort, tracePos, traceColor: SIZE;
VAR previousTimerHandler: CPU.InterruptHandler;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF SYSTEM.GetActivity () # NIL THEN Activities.TerminateCurrentActivity END;
	Exit (ShuttingDown);
END Abort;

PROCEDURE Shutdown*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF CAS (status, Running, ShuttingDown) # Running THEN RETURN END;
	Trace.StringLn ("system: shutting down...");
END Shutdown;

PROCEDURE Reboot*;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Shutdown;
	ASSERT (CAS (status, ShuttingDown, Rebooting) = ShuttingDown);
END Reboot;

PROCEDURE {NORETURN} Exit- (status: WORD);
VAR index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Trace.String ("system: ");
	IF status = Rebooting THEN Trace.StringLn ("rebooting..."); CPU.Reset END;
	Trace.StringLn ("ready for power off or restart"); CPU.Halt;
END Exit;

PROCEDURE Clock- (): LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN clock;
END Clock;

PROCEDURE Sleep- (milliseconds: LONGINT);
VAR interrupt: Interrupts.Interrupt;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Interrupts.Install (interrupt, CPU.IRQ0); INC (milliseconds, clock);
	WHILE (status = Running) & (clock - milliseconds < 0) DO Interrupts.Await (interrupt) END;
END Sleep;

PROCEDURE HandleTimerInterrupt (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	INC (clock);
END HandleTimerInterrupt;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
VAR result, address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := HeapManager.Allocate (size, heap);
	IF result = NIL THEN RETURN NIL END;
	FOR address := result TO result + size - 1 DO SYSTEM.PUT8 (address, 0) END;
	RETURN result;
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	HeapManager.Deallocate (address, heap);
END Deallocate;

PROCEDURE StrToInt (VAR i: LONGINT; CONST s: ARRAY OF CHAR): LONGINT;
VAR vd, vh, sgn, d: LONGINT; hex: BOOLEAN;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	vd := 0; vh := 0; hex := FALSE;
	IF s[i] = "-" THEN sgn := -1; INC (i) ELSE sgn := 1 END;
	LOOP
		IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD (s[i])-ORD ("0")
		ELSIF (CAP (s[i]) >= "A") & (CAP (s[i]) <= "F") THEN d := ORD (CAP (s[i]))-ORD ("A") + 10; hex := TRUE
		ELSE EXIT
		END;
		vd := 10*vd + d; vh := 16*vh + d;
		INC (i)
	END;
	IF CAP (s[i]) = "H" THEN hex := TRUE; INC (i) END;	(* optional H *)
	IF hex THEN vd := vh END;
	RETURN sgn * vd
END StrToInt;

PROCEDURE GetString- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
VAR i, src: LONGINT; ch: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (name[0] # "=");	(* no longer supported, use GetInit instead *)
	src := 0;
	LOOP
		ch := config[src];
		IF ch = 0X THEN EXIT END;
		i := 0;
		LOOP
			ch := config[src];
			IF (ch # name[i]) OR (name[i] = 0X) THEN EXIT END;
			INC (i); INC (src)
		END;
		IF (ch = 0X) & (name[i] = 0X) THEN	(* found: (src^ = 0X) & (name[i] = 0X) *)
			i := 0;
			REPEAT
				INC (src); ch := config[src]; result[i] := ch; INC (i);
				IF i = LEN(result) THEN result[i - 1] := 0X; RETURN END	(* val too short *)
			UNTIL ch = 0X;
			result[i] := 0X; RETURN
		ELSE
			WHILE ch # 0X DO	(* skip to end of name *)
				INC (src); ch := config[src]
			END;
			INC (src);
			REPEAT	(* skip to end of value *)
				ch := config[src]; INC (src)
			UNTIL ch = 0X
		END
	END;
	result[0] := 0X
END GetString;

PROCEDURE ReadBootTable (bt: ADDRESS);
VAR i, p: ADDRESS; j, d, type, addr, size, heapSize: LONGINT; ch: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	heapSize := 0;
	p := bt; d := 0;
	LOOP
		SYSTEM.GET (p, type);
		IF type = -1 THEN
			EXIT	(* end *)
		ELSIF type = 3 THEN	(* boot memory/top of low memory *)
			SYSTEM.GET (p + 8, addr); SYSTEM.GET (p + 12, size);
		ELSIF type = 4 THEN	(* free memory/extended memory size *)
			SYSTEM.GET (p + 8, addr); SYSTEM.GET (p + 12, size);
			IF addr = HeapAdr THEN heapSize := size END
		ELSIF type = 5 THEN	(* HD config *)
		ELSIF type = 8 THEN	(* config strings *)
			i := p + 8; j := 0;	(* copy the config strings over *)
			LOOP
				SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j);
				IF ch = 0X THEN EXIT END;
				REPEAT SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j) UNTIL ch = 0X;	(* end of name *)
				REPEAT SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j) UNTIL ch = 0X	(* end of value *)
			END
		END;
		SYSTEM.GET (p + 4, size); INC (p, size)
	END;
	memTop := HeapAdr + heapSize
END ReadBootTable;

PROCEDURE TraceChar (c: CHAR);
VAR status: SIZE;

	(* Scroll the screen by one line. *)
	PROCEDURE Scroll;
	VAR adr: ADDRESS; off: SIZE;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		adr := traceBase + TraceLen;
		SYSTEM.MOVE (adr, adr - TraceLen, TraceSize - TraceLen);
		adr := traceBase + TraceSize - TraceLen;
		FOR off := 0 TO TraceLen - SIZEOF(INTEGER) BY SIZEOF(INTEGER) DO SYSTEM.PUT16 (adr + off, 100H * 7H + 32) END
	END Scroll;

BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF TraceV24 IN traceMode THEN
		REPEAT	(* wait until port is ready to accept a character *)
			status := CPU.InByte (tracePort + 5)
		UNTIL ODD (status DIV 20H);	(* THR empty *)
		CPU.OutChar (tracePort, c);
	END;
	IF TraceScreen IN traceMode THEN
		IF c = 9X THEN c := 20X END;
		IF c = 0DX THEN	(* CR *)
			DEC (tracePos, tracePos MOD TraceLen)
		ELSIF c = 0AX THEN	(* LF *)
			IF tracePos < TraceSize THEN
				INC (tracePos, TraceLen)	(* down to next line *)
			ELSE
				Scroll
			END
		ELSE
			IF tracePos >= TraceSize THEN
				Scroll;
				DEC (tracePos, TraceLen)
			END;
			SYSTEM.PUT16 (traceBase + tracePos, 100H * traceColor + ORD (c));
			INC (tracePos, SIZEOF(INTEGER))
		END
	END
END TraceChar;

PROCEDURE TraceColor (c: SHORTINT);
BEGIN {UNCOOPERATIVE, UNCHECKED} traceColor := c;
END TraceColor;

PROCEDURE InitTrace;
CONST MaxPorts = 8;
VAR i, p, bps: LONGINT; off: SIZE; s, name: ARRAY 32 OF CHAR;
	baselist: ARRAY MaxPorts OF LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	GetString ("TraceMode", s);
	p := 0; traceMode := SYSTEM.VAL (SET, StrToInt (p, s));
	IF TraceScreen IN traceMode THEN
		GetString ("TraceMem", s);
		p := 0; traceBase := SYSTEM.VAL (ADDRESS, StrToInt (p, s));
		IF traceBase = 0 THEN traceBase := 0B8000H END;	(* default screen buffer *)
		FOR off := 0 TO TraceSize - SIZEOF(INTEGER) BY SIZEOF(INTEGER) DO SYSTEM.PUT16 (traceBase + off, 100H * 7H + 32) END;
		tracePos := 0;
		CPU.OutByte(3D4H, 0EH);
		CPU.OutByte(3D5H, (TraceWidth*TraceHeight) DIV 100H);
		CPU.OutByte(3D4H, 0FH);
		CPU.OutByte(3D5H, (TraceWidth*TraceHeight) MOD 100H)
	END;
	IF TraceV24 IN traceMode THEN
		FOR i := 0 TO MaxPorts - 1 DO
			COPY ("COMx", name); name[3] := CHR (ORD ("1") + i);
			GetString (name, s); p := 0; baselist[i] := StrToInt (p, s);
		END;
		IF baselist[0] = 0 THEN baselist[0] := 3F8H END;	(* COM1 port default values *)
		IF baselist[1] = 0 THEN baselist[1] := 2F8H END;	(* COM2 port default values *)
		GetString("TracePort", s); p := 0; p := StrToInt(p, s); DEC(p);
		IF (p >= 0) & (p < MaxPorts) THEN tracePort := baselist[p] ELSE tracePort := baselist[0] END;
		ASSERT(tracePort > 0);
		GetString("TraceBPS", s); p := 0; bps := StrToInt(p, s);
		IF bps <= 0 THEN bps := 38400 END;
		CPU.OutByte (tracePort + 3, 80H);	(* Set the Divisor Latch Bit - DLAB = 1 *)
		bps := 115200 DIV bps;	(* compiler DIV/PORTOUT bug workaround *)
		CPU.OutByte (tracePort + 1, bps DIV 100H);	(* Set the Divisor Latch MSB *)
		CPU.OutByte (tracePort, bps MOD 100H);	(* Set the Divisor Latch LSB *)
		CPU.OutByte (tracePort + 3, 3H);	(* 8N1 *)
		CPU.OutByte (tracePort + 4, 3H);	(* Set DTR, RTS on in the MCR *)
		CPU.OutByte (tracePort + 1, 0H);	(* Disable receive interrupts *)
	END;
	Trace.Init;
	traceColor := 7; Trace.Char := TraceChar; Trace.Color := TraceColor;
END InitTrace;

(* Check if the specified address is RAM. *)
PROCEDURE IsRAM(adr: ADDRESS): BOOLEAN;
CONST Pattern1 = 0BEEFC0DEH; Pattern2 = 0AA55FF00H;
VAR save, x: ADDRESS; ok: BOOLEAN;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ok := FALSE;
	SYSTEM.GET (adr, save);
	SYSTEM.PUT (adr, Pattern1);	(* attempt 1st write *)
	x := Pattern2;				(* write something else *)
	SYSTEM.GET (adr, x);		(* attempt 1st read *)
	IF x = Pattern1 THEN		(* first test passed *)
		SYSTEM.PUT (adr, Pattern2);	(* attempt 2nd write *)
		x := Pattern1;			(* write something else *)
		SYSTEM.GET (adr, x);	(* attempt 2nd read *)
		ok := (x = Pattern2)
	END;
	SYSTEM.PUT (adr, save);
	RETURN ok
END IsRAM;

(* Check amount of memory available and update memTop. *)
PROCEDURE CheckMemory;
CONST M = 100000H; ExtMemAdr = M; Step = M;
VAR s: ARRAY 16 OF CHAR; adr: ADDRESS; i: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	GetString("ExtMemSize", s);	(* in MB *)
	IF s[0] # 0X THEN	(* override detection *)
		i := 0; memTop := ExtMemAdr + StrToInt(i, s) * M;
	ELSE
		IF memTop >= 15*M THEN	(* search for more memory (ignore aliasing) *)
			adr := memTop-4;
			WHILE (LSH(memTop, -12) < LSH(MaxMemTop, -12)) & IsRAM(adr) DO
				memTop := adr + 4;
				INC (adr, Step)
			END;
			IF (memTop <= 0) THEN memTop := 2047 * M ; END;
		END
	END;
END CheckMemory;

PROCEDURE SetupTimer (channel, mode: SHORTINT; frequency: LONGINT);
CONST CommandPort = 043H; AccessLoHiByte = 030H; Binary = 000H; Channel0Port = 040H;
CONST OscillatorFrequency = 1193180;
VAR divisor: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (frequency > 1);
	ASSERT (frequency < OscillatorFrequency);
	divisor := OscillatorFrequency DIV frequency;
	CPU.OutByte (CommandPort, AccessLoHiByte + Binary + mode + channel * 64);
	CPU.OutChar (Channel0Port + channel, CHR (divisor MOD 100H));
	CPU.OutChar (Channel0Port + channel, CHR (divisor DIV 100H));
END SetupTimer;

PROCEDURE GetInit- (n: SIZE; VAR val: LONGINT);
BEGIN val := initRegs[n]
END GetInit;

PROCEDURE Initialize-;
CONST Channel0 = 0; RateGenerator = 4;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	CPU.Initialize;
	ACPI.Initialize;
	Timer.Initialize;
	ReadBootTable (bootFlag);
	InitTrace;
	CheckMemory;
	memory := memTop - ADDRESS OF KernelEnd;
	HeapManager.Initialize (heap, ADDRESS OF KernelEnd, memTop);
	previousTimerHandler := CPU.InstallInterrupt (HandleTimerInterrupt, CPU.IRQ0);
	SetupTimer (Channel0, RateGenerator, 1000);
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

PROCEDURE {NOPAF, INITIAL, FIXED(100000H)} KernelBegin;
CODE
	MOV bootFlag, EAX
	LEA EAX, initRegs
	MOV [EAX + 0], ESI
	MOV [EAX + 4], EDI
END KernelBegin;

PROCEDURE {NOPAF, FINAL, ALIGNED(32)} KernelEnd;
CODE {SYSTEM.i386}
END KernelEnd;

BEGIN
	Trace.String ("Build "); Trace.String (SYSTEM.Date); Trace.String (" (");
	Trace.Int (memory DIV (1024 * 1024), 0); Trace.String (" MB RAM, ");
	Trace.String ("GC, ");
	Trace.Int (Processors.count, 0); Trace.String (" CPU");
	IF Processors.count > 1 THEN Trace.Char ('s') END; Trace.String (", ");
	Trace.Int (SIZE OF ADDRESS * 8, 0); Trace.String ("-bit)"); Trace.Ln;
END Environment.

