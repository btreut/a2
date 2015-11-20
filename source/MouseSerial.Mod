(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE MouseSerial; (** AUTHOR "pjm"; PURPOSE "Serial mouse driver"; *)
(**
 * Aos serial mouse driver (quick and dirty port from Native Input.Mod and ConfigInput.Mod).
 * Mouse protocol information from XFree in X11R6 distribution (Thomas Roell & David Dawes)
 *
 * Usage:
 *
 *	Load mouse driver: MouseSerial.Install ~
 *
 *	To unload the driver, use SystemTools.Free MouseSerial ~
 *
 * Note:
 *
 * Be sure that the serial port driver is loaded before this module. Use V24.Install to load the serial port driver.
 *
 * History:
 *
 *	12.03.2003	procedure Configure modified to support 8 serial ports i.o. 4 (AFI)
 *	03.07.2007	Quick and dirty port to Shell (staubesv)
 *)

IMPORT SYSTEM, Machine, KernelLog, Modules, Kernel, Commands, Inputs, Serials;

CONST
	Trace = TRUE;
	Debug = FALSE;

	(* If TRUE, call the V24.Install command when loading this module *)
	LoadV24 = TRUE;

	(* mouse types *)
	MinType = 0;  MaxType = 9;
	MS = 0;  MSC1 = 1;  MM = 2;  Logi = 3;  MSC2 = 4;  LogiMan = 5;  PS2 = 6;  MSI = 7;  MSC3 = 8;  MSC4 = 9;
(*
	0  Microsoft serial (2-button)
	1  Mouse Systems Corp serial type a (dtr on, rts on)
	2  Logitech serial Type a (old models)
	3  Logitech serial Type b (old models)
	4  Mouse Systems Corp serial type b (dtr off, rts off)
	5  Logitech serial Type c (new models)
	6  PS/2 mouse (default)
	7  Microsoft serial IntelliMouse
	8  Mouse Systems Corp serial type c (dtr off, rts on)
	9  Mouse Systems Corp serial type d (dtr on, rts off)

	MT=PS2  PS/2 or built-in
	MT=LM1  Logitech 1
	MT=LM2  Logitech 2
	MT=LM3  Logitech 3
	MT=MS1  Mouse Systems 1
	MT=MS2  Mouse Systems 2
	MT=MS3  Mouse Systems 3
	MT=MS4  Mouse Systems 4
	MT=MSM  Microsoft (2-button)
	MT=MSI  Microsoft IntelliMouse
	MP=1
	MP=2
*)

	Rate = 100;	(* Sampling rate *)
	BPS = 1200;	(* Speed *)

	DetectOffTime = 250;	(* ms *)
	DetectOnTime = 250;	(* ms *)
	DetectMaxIdent = 256;

TYPE

	Mouse = OBJECT
	VAR
		type: LONGINT; (* mouse type *)
		mbufp, numb: SHORTINT; (* buffer pointer & protocol bytes *)
		mbuf: ARRAY 5 OF SET; (* protocol buffer *)
		mask0, val0, mask1, val1, lastkeys: SET; (* protocol parameters *)

		errors : LONGINT;
		res : LONGINT;

		port : Serials.Port;
		m : Inputs.MouseMsg; keys: SET;

		dead : BOOLEAN;

		(* Read a mouse event *)
		PROCEDURE GetMouseEvent(VAR keys: SET;  VAR dx, dy: LONGINT): LONGINT;
		VAR ch : CHAR; b : SET; res : LONGINT;
		BEGIN
			b := {};

			port.ReceiveChar(ch, res);
			IF res # Serials.Ok THEN RETURN res; END;
			b := SYSTEM.VAL(SET, ch);

			(* check for resync *)
			IF (mbufp # 0) & ((b * mask1 # val1) OR (b = {7})) THEN mbufp := 0 END;
			IF (mbufp = 0) & (b * mask0 # val0) THEN
				(* skip package, unless it is a LogiMan middle button... *)
				IF ((type = MS) OR (type = LogiMan)) & (b * {2..4,6,7} = {}) THEN
					keys := lastkeys * {0,2};
					IF 5 IN b THEN INCL(keys, 1) END;
					dx := 0;  dy := 0;
					RETURN Serials.Ok;
				ELSE
					INC(errors);
				END
			ELSE
				mbuf[mbufp] := b;  INC(mbufp);
				IF mbufp = numb THEN
					CASE type OF
						|MS, LogiMan:
							keys := lastkeys * {1};
							IF 5 IN mbuf[0] THEN INCL(keys, 2) END;
							IF 4 IN mbuf[0] THEN INCL(keys, 0) END;
							dx := LONG(SYSTEM.VAL(SHORTINT, LSH(mbuf[0] * {0,1}, 6) + mbuf[1] * {0..5}));
							dy := LONG(SYSTEM.VAL(SHORTINT, LSH(mbuf[0] * {2,3}, 4) + mbuf[2] * {0..5}));
						|MSC1, MSC2, MSC3, MSC4:
							keys := {0..2} - (mbuf[0] * {0..2});
							dx := LONG(SYSTEM.VAL(SHORTINT, mbuf[1])) + LONG(SYSTEM.VAL(SHORTINT, mbuf[3]));
							dy := -(LONG(SYSTEM.VAL(SHORTINT, mbuf[2])) + LONG(SYSTEM.VAL(SHORTINT, mbuf[4])));
						|MM, Logi:
							keys := mbuf[0] * {0..2};
							dx := SYSTEM.VAL(INTEGER, mbuf[1]);
							IF ~(4 IN mbuf[0]) THEN dx := -dx END;
							dy := SYSTEM.VAL(INTEGER, mbuf[2]);
							IF 3 IN mbuf[0] THEN dy := -dy END;
						|MSI:
							keys := {};
							IF 4 IN mbuf[0] THEN INCL(keys, 0) END;
							IF 5 IN mbuf[0] THEN INCL(keys, 2) END;
							IF 3 IN mbuf[3] THEN INCL(keys, 3) END;
							IF 4 IN mbuf[3] THEN INCL(keys, 1) END;
							IF ~(3 IN mbuf[3]) & (mbuf[3] * {0..2} # {}) THEN INCL(keys, 4) END;
							dx := LONG(SYSTEM.VAL(SHORTINT, LSH(mbuf[0] * {0,1}, 6) + mbuf[1] * {0..7}));
							dy := LONG(SYSTEM.VAL(SHORTINT, LSH(mbuf[0] * {2,3}, 4) + mbuf[2] * {0..7}));
					ELSE
						(* ignore *)
					END;
					mbufp := 0;
					RETURN Serials.Ok;
				END;
			END;
			keys := lastkeys;  dx := 0;  dy := 0;
			RETURN 99; (* don't sent mouse message *)
		END GetMouseEvent;

		PROCEDURE Close;
		BEGIN
			port.Close();
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Close;

		(* Initialise mouse.
			"type" - mouse type from list
			"port" - V24.COM[12]
			"bps" - V24.BPS*
			"rate" - sample rate (not all mice support this) *)
		PROCEDURE &Init*(port : Serials.Port; type : LONGINT);
		VAR c: CHAR; res, n: LONGINT;
		BEGIN
			(* ASSERT: Port is already open *)
			ASSERT(port # NIL);
			ASSERT((MinType <= type) & (type  <= MaxType));
			dead := FALSE;
			SELF.port := port;
			SELF.type := type;
			IF type # PS2 THEN
				errors := 0;
				IF type = LogiMan THEN
					SetSpeed(port, type, 1200, 1200);
					port.SendChar("*", res);
					port.SendChar("X", res);
					SetSpeed(port, type, 1200, BPS)
				ELSE
					SetSpeed(port, type, 9600, BPS);
					SetSpeed(port, type, 4800, BPS);
					SetSpeed(port, type, 2400, BPS);
					SetSpeed(port, type, 1200, BPS);
					IF type = Logi THEN
						port.SendChar("S", res);
						SetSpeed(port, MM, BPS, BPS);
					END;
					(* set sample rate *)
					IF Rate <= 0 THEN c := "O";	(* continuous - don't use *)
					ELSIF Rate <= 15 THEN c := "J";	(* 10 Hz *)
					ELSIF Rate <= 27 THEN c := "K";	(* 20 *)
					ELSIF Rate <= 42 THEN c := "L";	(* 35 *)
					ELSIF Rate <= 60 THEN c := "R";	(* 50 *)
					ELSIF Rate <= 85 THEN c := "M";	(* 70 *)
					ELSIF Rate <= 125 THEN c := "Q"; (* 100 *)
					ELSE c := "N"; (* 150 *)
					END;
					port.SendChar(c, res);
					IF type = MSC2 THEN port.ClearMC({Serials.DTR, Serials.RTS});
					ELSIF type = MSC3 THEN port.ClearMC( {Serials.DTR});
					ELSIF type = MSC4 THEN port.ClearMC( {Serials.RTS});
					END;
				END;
				mbufp := 0;  lastkeys := {};
				(* protocol parameters *)
				CASE type OF
					|MS:  numb := 3;  mask0 := {6};  val0 := {6};  mask1 := {6};  val1 := {};
					|MSC1, MSC2, MSC3, MSC4:  numb := 5;  mask0 := {3..7};  val0 := {7};  mask1 := {};  val1 := {};
					|MM:  numb := 3;  mask0 := {5..7};  val0 := {7};  mask1 := {7};  val1 := {};
					|Logi:  numb := 3;  mask0 := {5..7};  val0 := {7};  mask1 := {7};  val1 := {};
					|LogiMan:  numb := 3;  mask0 := {6};  val0 := {6};  mask1 := {6};  val1 := {};
					|MSI: numb := 4;  mask0 := {6};  val0 := {6};  mask1 := {6};  val1 := {};
				ELSE
					(* ignore *)
				END;

				(* ignore the first few bytes from the mouse (e.g. Logitech MouseMan Sensa) *)
				n := 4;
				REPEAT
					WHILE port.Available() # 0 DO port.ReceiveChar(c, res) END;
					Wait(1000 DIV n); (* wait 1/4s, 1/3s, 1/2s, 1s *)
					DEC(n);
				UNTIL (port.Available() = 0) OR (n = 0)
			END;

			(* Lower/Raise DTR/RTS for autodetection, and to start an Intellimouse *)
			port.ClearMC({Serials.DTR, Serials.RTS});
			Wait(DetectOffTime);
			port.SetMC({Serials.DTR, Serials.RTS});
			Wait(DetectOnTime);
		END Init;

	BEGIN {ACTIVE}
		LOOP
			res := GetMouseEvent(keys, m.dx, m.dy);
			IF res = Serials.Ok THEN
				m.dz := 0; m.keys := {};
				IF 0 IN keys THEN INCL(m.keys, 2); END;
				IF 1 IN keys THEN INCL(m.keys, 1); END;
				IF 2 IN keys THEN INCL(m.keys, 0); END;
				Inputs.mouse.Handle(m);
			ELSIF res = Serials.Closed THEN
				EXIT;
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Mouse;

VAR
	mouse : ARRAY Serials.MaxPorts + 1 OF Mouse; (* index 0 not used *)
	timer : Kernel.Timer;

(* Set mouse speed *)
PROCEDURE SetSpeed(port : Serials.Port; mouseType, oldBPS, newBPS: LONGINT);
VAR word, stop, par : INTEGER; c : CHAR;  res : LONGINT;
BEGIN
	ASSERT(port # NIL);
	port.Close();
	CASE mouseType OF
		MS:  word := 7;  stop := Serials.Stop1;  par := Serials.ParNo |
		MSC1, MSC2, MSC3, MSC4:  word := 8;  stop := Serials.Stop2;  par := Serials.ParNo |
		MM:  word := 8;  stop := Serials.Stop1;  par := Serials.ParOdd |
		Logi:  word := 8;  stop := Serials.Stop2;  par := Serials.ParNo |
		LogiMan:  word := 7;  stop := Serials.Stop1;  par := Serials.ParNo |
		MSI:  word := 7;  stop := Serials.Stop1;  par := Serials.ParNo
	ELSE
		(* ignore *)
	END;
	IF (mouseType = Logi) OR (mouseType = LogiMan) THEN
		port.Open(oldBPS, word, par, stop, res);
		IF res = Serials.Ok THEN
			IF newBPS = 9600 THEN c := "q"
			ELSIF newBPS = 4800 THEN c := "p"
			ELSIF newBPS = 2400 THEN c := "o"
			ELSE c := "n"
			END;
			port.SendChar("*", res);
			port.SendChar(c, res);
			Wait(100);
			port.Close();
		END
	END;
	port.Open(newBPS, word, par, stop, res);
	IF res = Serials.Ok THEN
		port.SetMC({Serials.DTR, Serials.RTS})
	END;
END SetSpeed;

PROCEDURE GetMouseType(CONST s : ARRAY OF CHAR) : LONGINT;
VAR type : LONGINT;
BEGIN
	type := MinType-1;
	IF (s[0] >= "0") & (s[0] <= "9") THEN (* old style config *)
		type := SHORT(ORD(s[0])-ORD("0"))
	ELSE (* new style config *)
		IF s = "" THEN
		(* default if none specified *)
		ELSIF (CAP(s[0]) = "L") & (CAP(s[1]) = "M") THEN (* Logitech *)
			CASE s[2] OF
				|"1": type := LogiMan;
				|"2": type := MM;
				|"3": type := Logi;
			ELSE
				type := MinType-1; (* Unknown *)
			END;
		ELSIF (CAP(s[0]) = "M") & (CAP(s[1]) = "S") THEN (* Mouse Systems or Microsoft *)
			IF CAP(s[2]) = "M" THEN
				type := MS;
			ELSIF CAP(s[2]) = "I" THEN
				type := MSI;
			ELSE
				CASE s[2] OF
					|"1": type := MSC1;
					|"2": type := MSC2;
					|"3": type := MSC3|"4": type := MSC4;
				ELSE
					type := MinType-1;
				END;
			END;
		ELSIF CAP(s[0]) = "P" THEN (* PS/2 *)
			type := PS2
		END
	END;
	IF (type < MinType) OR (type > MaxType) THEN type := PS2 END; (* unknown mouse type *)
	RETURN type;
END GetMouseType;

PROCEDURE Detect(port : Serials.Port; VAR mouseType : LONGINT): BOOLEAN;
VAR ch: CHAR; i, res : LONGINT; mouseIdent : ARRAY DetectMaxIdent OF CHAR;
BEGIN
	ASSERT(port # NIL);
	port.Open(BPS, 7,  Serials.ParNo, Serials.Stop1, res);
	IF res # Serials.Ok THEN RETURN FALSE; END;

	(* Lower/Raise DTR/RTS for autodetection, and to start an Intellimouse *)
	port.ClearMC({Serials.DTR, Serials.RTS});
	Wait(DetectOffTime);
	port.SetMC({Serials.DTR, Serials.RTS});
	Wait(DetectOnTime);

	REPEAT
		IF port.Available() = 0 THEN RETURN FALSE END;
		port.ReceiveChar(ch, res);
		IF ch >= 80X THEN ch := CHR(ORD(ch)-80H) END
	UNTIL ch = "M";

	mouseIdent[0] := ch; i := 1;
	WHILE (port.Available() # 0) & (i < DetectMaxIdent-1) DO
		port.ReceiveChar(ch, res);
		IF ch >= 80X THEN ch := CHR(ORD(ch)-80H) END;
		IF (ch < " ") OR (ch >= 7FX) THEN ch := "." END;
		mouseIdent[i] := ch; INC(i)
	END;
	mouseIdent[i] := 0X;
	IF Debug THEN
		KernelLog.Enter; KernelLog.String("Mouse ident:"); KernelLog.Ln; KernelLog.Buffer(mouseIdent, 0, i); KernelLog.Exit
	END;
	IF mouseIdent[1] = "3" THEN mouseType := LogiMan;
	ELSIF mouseIdent[1] = "Z" THEN mouseType := MSI;
	ELSE mouseType := MS;
	END;
	RETURN TRUE
END Detect;

PROCEDURE Init;
VAR
	value: ARRAY DetectMaxIdent OF CHAR;
	port : Serials.Port;
	mouseType, portNbr : LONGINT;
BEGIN
	Machine.GetConfig("MT", value);
	IF value[0] # 0X THEN (* manual config *)
		mouseType := GetMouseType(value);

		(* Get port number *)
		Machine.GetConfig("MP", value);
		IF (value[0] >= "1") & (value[0] <= "8") THEN
			portNbr := ORD(value[0]) - ORD("0");
		ELSE
			portNbr := 1;
		END;
		IF Trace THEN
			KernelLog.String("MouseSerial: Manual configuration (Port: "); KernelLog.Int(portNbr, 0);
			KernelLog.String(", type: "); KernelLog.Int(mouseType, 0); KernelLog.String(")"); KernelLog.Ln;
		END;
		port := Serials.GetPort(portNbr);
		IF port # NIL THEN
			IF mouse[portNbr] # NIL THEN mouse[portNbr].Close; END;
			NEW(mouse[portNbr], port, mouseType);
			IF Trace THEN KernelLog.String("MouseSerial: Mouse at COM port "); KernelLog.Int(portNbr, 0); KernelLog.String(" started."); KernelLog.Ln; END;
		ELSE
			IF Trace THEN KernelLog.String("MouseSerial: COM port "); KernelLog.Int(portNbr, 0); KernelLog.String(" not avaiable."); KernelLog.Ln; END;
		END;
	ELSE
		IF Trace THEN KernelLog.String("MouseSerial: Auto-detect serial mice..."); KernelLog.Ln; END;
		FOR portNbr := 1 TO Serials.MaxPorts DO
			port := Serials.GetPort(portNbr);
			IF port # NIL THEN
				IF Detect(port, mouseType) THEN
					IF Trace THEN
						KernelLog.String("MouseSerial: Detected mouse at port "); KernelLog.Int(portNbr, 0);
						KernelLog.String(" (type: "); KernelLog.Int(mouseType, 0); KernelLog.String(")"); KernelLog.Ln;
					END;
					IF mouse[portNbr] # NIL THEN mouse[portNbr].Close; END;
					NEW(mouse[portNbr], port, mouseType);
				END;
			END;
		END;
		IF Trace THEN KernelLog.String("MouseSerial: Auto-detection finished."); KernelLog.Ln; END;
	END;
END Init;

PROCEDURE Wait(milliseconds : LONGINT);
BEGIN {EXCLUSIVE}
	ASSERT(milliseconds > 0);
	timer.Sleep(milliseconds);
END Wait;

PROCEDURE LoadSerialPortDriver;
VAR msg : ARRAY 64 OF CHAR; res : LONGINT;
BEGIN
	KernelLog.String("MouseSerial: Loading serial port driver..."); KernelLog.Ln;
	Commands.Call("V24.Install", {Commands.Wait}, res, msg);
	IF res = Commands.Ok THEN
		KernelLog.String("MouseSerial: Serial port driver loaded.");
	ELSE
		KernelLog.String("MouseSerial: Loading serial port driver failed, res: "); KernelLog.Int(res, 0); KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")");
	END;
	KernelLog.Ln;
END LoadSerialPortDriver;

PROCEDURE Install*; (** ~ *)
END Install;

(** Manually set the mouse type *)
PROCEDURE ToggleMouseType*(context : Commands.Context); (** PortNumber  ~ *)
VAR portNbr, type : LONGINT; m : Mouse;
BEGIN
	IF context.arg.GetInteger(portNbr, FALSE) & (1 <= portNbr) & (portNbr <= Serials.MaxPorts) THEN
		m := mouse[portNbr];
		IF m # NIL THEN
			type := (m.type + 1) MOD (MaxType + 1);
			m.Close;
			NEW(mouse[portNbr], m.port, type);
			context.out.String("MouseSerial: Set type of mouse at port "); context.out.Int(portNbr, 0);
			context.out.String(" to "); context.out.Int(m.type, 0); context.out.Ln;
		ELSE
			context.out.String("MouseSerial: No mouse at port "); context.out.Int(portNbr, 0); context.out.Ln;
		END;
	ELSE context.error.String("MouseSerial: Invalid port number"); context.error.Ln;
	END;
END ToggleMouseType;

PROCEDURE Cleanup;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(mouse)-1 DO
		IF mouse[i] # NIL THEN
			mouse[i].Close; mouse[i] := NIL;
		END;
	END;
END Cleanup;

BEGIN
	NEW(timer);
	Modules.InstallTermHandler(Cleanup);
	IF LoadV24 THEN LoadSerialPortDriver; END;
	Init;
END MouseSerial.

MouseSerial.Install ~	MouseSerial.ToggleMouseType 1 ~

SystemTools.Free MouseSerial ~

