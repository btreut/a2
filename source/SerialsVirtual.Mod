MODULE SerialsVirtual; (** AUTHOR "staubesv"; PURPOSE "Virtual serial port driver"; *)
(**
 * This driver creates two virtual serial port instances that are linked using a virtual null-modem cable, i.e. the data sent to one
 * port is received by the other and vice versa.
 * Idea: One of the ports can be used by the application under development and the other is used to send data to this application, for example,
 * simulated output of a serial port device.
 *
 * Usage:
 *
 *	SerialsVirtual.Install ~ creates two virtual serial port instances that are cross-linked and registers them at Serials
 *
 *	SerialsVirtual.SendFile portNbr filename [Loop] ~ 	sends the content of the specified file to the specified virtual serial port.
 *														The data is then received by its companion port.
 *	SerialsVirtual.StopSendFile portNbr ~				stops sending a file for the specified port
 *
 *	SerialsVirtual.InstallSniffer ~ installs a virtal serial port that acts as proxy for the specified port
 *
 *	SystemTools.Free SerialsVirtual ~ Unregisters virtual serial ports at Serials
 *
 * History:
 *
 *	20.06.2006	Created (staubesv)
 *	26.06.2006	Speed emulation (staubesv)
 *	27.06.2006	Implemented PortSniffer (staubesv)
 *)

IMPORT
	KernelLog, Strings, Modules, Commands, Streams, Files, Kernel, Random,
	Serials;

CONST

	Verbose = TRUE;

	BufferSize = 1024;

	(* If TRUE, the SendChar procedure is artificially slowed down to the speed approx. bps *)
	EnableSendSpeedLimitation = TRUE;

	ModuleName = "SerialsVirtual";

TYPE

	SendProcedure = PROCEDURE {DELEGATE} (ch : CHAR; VAR res : LONGINT);

	(** Virtual serial port the can be linked to other virtual serial port *)
	VirtualPort = OBJECT (Serials.Port);
	VAR
		buffer : ARRAY BufferSize OF CHAR;
		head, tail : LONGINT;

		open : BOOLEAN;
		bps, data, parity, stop : LONGINT;
		mc : SET;

		sender : SendProcedure;

		(* Send speed emulation fields *)
		eachNCharacters, waitForMs : LONGINT;
		timer : Kernel.Timer;

		(** Virtual Port Interface *)

		PROCEDURE PutChar(ch : CHAR; VAR res : LONGINT);
		BEGIN {EXCLUSIVE}
			IF ~open THEN
				res := Serials.Closed;
			ELSE
				AWAIT(((tail + 1) MOD BufferSize # head) OR ~open); (* Wait until buffer is not full *)
				IF open THEN
					buffer[tail] := ch;
					tail := (tail + 1) MOD BufferSize;
					res := Serials.Ok;
				ELSE
					res := Serials.Closed;
				END;
			END;
		END PutChar;

		(** Serial Port Interface *)

		PROCEDURE Open (bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF open THEN
				IF Verbose THEN ShowModule; KernelLog.String(name); KernelLog.String(" already open"); KernelLog.Ln; END;
				res := Serials.PortInUse;
				RETURN
			END;
			SetPortState(bps, data, parity, stop, res);
			IF res = Serials.Ok THEN
				open := TRUE; head := 0; tail := 0;
				charactersSent := 0; charactersReceived := 0;
				IF Verbose THEN ShowModule; KernelLog.String(name); KernelLog.String(" opened"); KernelLog.Ln; END;
			END;
		END Open;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			open := FALSE;
			tail := -1;
			IF Verbose THEN ShowModule; KernelLog.String(name); KernelLog.String(" closed"); KernelLog.Ln; END;
		END Close;

		PROCEDURE SendChar (ch: CHAR; VAR res : LONGINT);
		VAR wait: BOOLEAN;
		BEGIN
			BEGIN{EXCLUSIVE}
				IF ~open THEN res := Serials.Closed; END;
			END;

			IF (errorRate > 0) & (random.Uniform() < errorRate) THEN RETURN; ch := CHR(ORD(ch) + random.Dice(20)) END;
			IF sender # NIL THEN
				BEGIN{EXCLUSIVE}
					INC(charactersSent);
					IF EnableSendSpeedLimitation & (waitForMs # 0) & (charactersSent MOD eachNCharacters = 0) THEN
						timer.Sleep(waitForMs)
					END;
				END;
				sender(ch, res);
			END;
		END SendChar;

		(** Wait for the next character is received in the input buffer. The buffer is fed by HandleInterrupt *)
		PROCEDURE ReceiveChar(VAR ch: CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN END;
			AWAIT((tail # head) OR ~open);
			IF ~open OR (tail = -1) THEN
				res := Serials.Closed;
			ELSE
				ch := buffer[head]; head := (head+1) MOD BufferSize;
				INC(charactersReceived);
				res := Serials.Ok;
			END
		END ReceiveChar;

		PROCEDURE Available(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN (tail - head) MOD BufferSize
		END Available;

		(* Set the port state: speed in bps, no. of data bits, parity, stop bit length. *)
		PROCEDURE SetPortState(bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN
			SELF.bps := bps; SELF.data := data; SELF.parity := parity; SELF.stop := stop;
			res := Serials.Ok;
			IF EnableSendSpeedLimitation THEN
				GetSlowdownValues(bps, eachNCharacters, waitForMs, res);
			END;
		END SetPortState;

		(** Get the port state: state (open, closed), speed in bps, no. of data bits, parity, stop bit length. *)
		PROCEDURE GetPortState(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		BEGIN {EXCLUSIVE}
			openstat := open;
			bps := SELF.bps; data := SELF.data; parity := SELF.parity; stop := SELF.stop;
		END GetPortState;

		(** Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC(s: SET);
		BEGIN {EXCLUSIVE}
			mc := mc - s;
		END ClearMC;

		(** Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC(s: SET);
		BEGIN {EXCLUSIVE}
			mc := mc + s;
		END SetMC;

		(** Return the state of the specified modem control lines.  s contains
			the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC(VAR s: SET);
		BEGIN {EXCLUSIVE}
			s := mc;
		END GetMC;

		PROCEDURE &Init*;
		BEGIN
			NEW(timer);
		END Init;

	END VirtualPort;

TYPE

	(* Note: If logging to the Kernel Log, be sure that associated real serial port is not the one which KernelLog uses *)
	PortSniffer = OBJECT(Serials.Port)
	VAR
		port : Serials.Port;
		in, out : Streams.Writer;

		PROCEDURE Open (bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			port.Open(bps, data, parity, stop, res);
			IF res = Serials.Ok THEN
				charactersSent := 0; charactersReceived := 0;
			END;
		END Open;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			port.Close;
		END Close;

		PROCEDURE SendChar (ch: CHAR; VAR res : LONGINT);
		BEGIN {EXCLUSIVE}
			port.SendChar(ch, res);
			IF res = Serials.Ok THEN
				IF out # NIL THEN
					out.Char(ch); out.Update;
				ELSE
					IF Verbose THEN KernelLog.Char(ch); END;
				END;
				INC(charactersSent);
			ELSE
				IF Verbose THEN
					ShowModule; KernelLog.String("Error while sending '"); KernelLog.Char(ch); KernelLog.String("': ");
					KernelLog.Int(res, 0); KernelLog.Ln;
				END;
			END;
		END SendChar;

		(** Wait for the next character is received in the input buffer. The buffer is fed by HandleInterrupt *)
		PROCEDURE ReceiveChar(VAR ch: CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			port.ReceiveChar(ch, res);
			IF res = Serials.Ok THEN
				IF in # NIL THEN
					in.Char(ch); in.Update;
				ELSE
					IF Verbose THEN KernelLog.Char(ch); END;
				END;
				INC(charactersReceived);
			ELSE
				IF Verbose THEN ShowModule; KernelLog.String("Error while receiving: "); KernelLog.Int(res, 0); KernelLog.Ln; END;
			END;
		END ReceiveChar;

		PROCEDURE Available(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN port.Available();
		END Available;

		(** Get the port state: state (open, closed), speed in bps, no. of data bits, parity, stop bit length. *)
		PROCEDURE GetPortState(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		BEGIN {EXCLUSIVE}
			port.GetPortState(openstat, bps, data, parity, stop);
		END GetPortState;

		(** Clear the specified modem control lines. s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC(s: SET);
		BEGIN {EXCLUSIVE}
			port.ClearMC(s);
		END ClearMC;

		(** Set the specified modem control lines. s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC(s: SET);
		BEGIN {EXCLUSIVE}
			port.SetMC(s);
		END SetMC;

		(** Return the state of the specified modem control lines. s contains the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC(VAR s: SET);
		BEGIN {EXCLUSIVE}
			port.GetMC(s);
		END GetMC;

		PROCEDURE &Init*(port : Serials.Port; in, out : Streams.Writer);
		BEGIN
			ASSERT(port # NIL);
			SELF.port := port; SELF.in := in; SELF.out := out;
		END Init;

	END PortSniffer;

VAR
	active : ARRAY Serials.MaxPorts+1 OF BOOLEAN;
	errorRate: LONGREAL;
	random: Random.Generator;

PROCEDURE ShowModule;
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": ");
END ShowModule;

PROCEDURE GetSlowdownValues(bps : LONGINT; VAR eachNCharacters, waitForMs, res : LONGINT);
BEGIN
	res := Serials.Ok;
	waitForMs := 1;
	IF bps = 0 THEN waitForMs := 0; (* Don't limit speed *)
	ELSIF bps = 300 THEN eachNCharacters := 1; waitForMs := 4;
	ELSIF bps = 600 THEN eachNCharacters := 1; waitForMs := 2;
	ELSIF bps = 1200 THEN eachNCharacters := 1;
	ELSIF bps = 2400 THEN eachNCharacters := 2;
	ELSIF bps = 4800 THEN eachNCharacters := 4;
	ELSIF bps = 9600 THEN eachNCharacters := 8;
	ELSIF bps = 19200 THEN eachNCharacters := 16;
	ELSIF bps = 38400 THEN eachNCharacters := 32;
	ELSIF bps = 115200 THEN eachNCharacters := 100;
	ELSIF bps = 230400 THEN eachNCharacters := 200;
	ELSIF bps = 460800 THEN eachNCharacters := 400;
	ELSIF bps = 921600 THEN eachNCharacters := 800;
	ELSE
		res := Serials.WrongBPS;
	END;
END GetSlowdownValues;

PROCEDURE IsValidPortNumber(portNbr : LONGINT) : BOOLEAN;
BEGIN
	RETURN (1 <= portNbr) & (portNbr <= Serials.MaxPorts);
END IsValidPortNumber;

PROCEDURE SendFileIntern(portNbr : LONGINT; CONST filename : ARRAY OF CHAR; loop : BOOLEAN; context : Commands.Context);
VAR
	port : Serials.Port;
	file : Files.File;
	len, res : LONGINT;
	in : Files.Reader; out : Streams.Writer;
	buffer : ARRAY BufferSize OF CHAR;
BEGIN
	BEGIN {EXCLUSIVE}
		IF active[portNbr] THEN
			context.out.String("Port is already used for data generation"); context.out.Ln;
			RETURN;
		ELSE
			active[portNbr] := TRUE;
		END;
	END;
	port := Serials.GetPort(portNbr);
	IF port # NIL THEN
		file := Files.Old(filename);
		IF file # NIL THEN
			port.Open(600, 8, 2, 2, res);
			IF res = Serials.Ok THEN
				context.out.String("Sending file "); context.out.String(filename); context.out.String(" to serial port "); context.out.Int(portNbr, 0);
				IF loop THEN context.out.String(" [LOOP MODE]"); END; context.out.String("... ");
				NEW(out, port.Send, BufferSize);
				Files.OpenReader(in, file, 0);
				REPEAT
					in.Bytes(buffer, 0, BufferSize, len); out.Bytes(buffer, 0, len); out.Update;
					IF loop & (in.res = Streams.EOF) THEN Files.OpenReader(in, file, 0); END;
				UNTIL (in.res # Streams.Ok) OR (out.res # Streams.Ok) OR (active[portNbr] = FALSE);
				context.out.String("done."); context.out.Ln;
			ELSE context.out.String("Could not open port "); context.out.Int(portNbr, 0); context.out.String(", res: "); context.out.Int(res, 0); context.out.Ln;
			END;
			port.Close;
		ELSE context.out.String("Could not open file "); context.out.String(filename); context.out.Ln;
		END;
	ELSE context.out.String("Could not get serial port "); context.out.Int(portNbr, 0); context.out.Ln;
	END;
	BEGIN {EXCLUSIVE}
		IF active[portNbr] THEN active[portNbr] := FALSE; END;
	END;
END SendFileIntern;

(** Send the content of the specified file to the specified serial port. If the Loop parameter is used, the file is sent
	in a endless loop. Sending can be stopped using the StopSendFile commands *)
PROCEDURE SendFile*(context : Commands.Context); (** portNbr filename [Loop] ~ *)
VAR portNbr : LONGINT; filename, parString : ARRAY Files.NameLength OF CHAR; loop : BOOLEAN;
BEGIN
	IF context.arg.GetInteger(portNbr, FALSE) & IsValidPortNumber(portNbr) THEN
		IF context.arg.GetString(filename) THEN
			IF context.arg.GetString(parString) & Strings.Match(parString, "Loop") THEN loop := TRUE; END;
			SendFileIntern(portNbr, filename, loop, context);
			context.out.String("Started generator on port "); context.out.Int(portNbr, 0);
			context.out.String(" (File: "); context.out.String(filename); context.out.String(")"); context.out.Ln;
		ELSE
			context.out.String("Expected portNbr filename parameters. Could not read filename."); context.out.Ln;
		END;
	ELSE
		context.out.String("Invalid port number"); context.out.Ln;
	END;
END SendFile;

(** Stop sending a file for the specified port *)
PROCEDURE StopSendFile*(context : Commands.Context); (** portNbr ~ *)
VAR portNbr : LONGINT;
BEGIN
	IF context.arg.GetInteger(portNbr, FALSE) & IsValidPortNumber(portNbr) THEN
		BEGIN {EXCLUSIVE}
			IF active[portNbr] THEN
				active[portNbr] := FALSE;
				context.out.String("Stopped generator on port "); context.out.Int(portNbr, 0); context.out.Ln;
			ELSE
				context.out.String("No generator running on port "); context.out.Int(portNbr, 0); context.out.Ln;
			END;
		END;
	ELSE
		context.out.String("Invalid port number"); context.out.Ln;
	END;
END StopSendFile;

(** Installs two virtual serial ports which are linked to each other. Data sent by one port is received by the other and vice versa *)
PROCEDURE Install*(context : Commands.Context); (** ~ *)
VAR port1, port2 : VirtualPort; description : ARRAY 128 OF CHAR;
BEGIN
	NEW(port1); NEW(port2);
	port1.sender := port2.PutChar;
	port2.sender := port1.PutChar;

	description := "Virtual Serial Port";
	Serials.RegisterPort(port1, description);

	Strings.Append(description, " (Linked to "); Strings.Append(description, port1.name); Strings.Append(description, ")");
	Serials.RegisterPort(port2, description);
END Install;

(** Install a virtual sniffer port as proxy for the specified serial port *)
PROCEDURE InstallSniffer*(context : Commands.Context); (** [portNbr] ~ *)
VAR
	portSniffer : PortSniffer; port : Serials.Port;
	portNbr : LONGINT;
	description : ARRAY 128 OF CHAR;
BEGIN
	IF context.arg.GetInteger(portNbr, FALSE) & IsValidPortNumber(portNbr) THEN
		port := Serials.GetPort(portNbr);
		IF port # NIL THEN
			NEW(portSniffer, port, NIL, NIL);
			description := "Virtual Serial Port (Sniffer linked to ";
			Strings.Append(description, port.name); Strings.Append(description, ")");
			Serials.RegisterPort(portSniffer, description);
			context.out.String("Registered serial port sniffer for port "); context.out.Int(portNbr, 0); context.out.Ln;
		ELSE
			context.out.String("Port "); context.out.Int(portNbr, 0); context.out.String(" not found."); context.out.Ln;
		END;
	ELSE
		context.out.String("Invalid port number"); context.out.Ln;
	END;
END InstallSniffer;

PROCEDURE Cleanup;
VAR portNbr : LONGINT;
BEGIN
	FOR portNbr := 1 TO Serials.MaxPorts DO
		active[portNbr] := FALSE;
	END;
END Cleanup;

PROCEDURE SetErrorRate*(context: Commands.Context);
VAR rate, divisor: LONGINT;
BEGIN
	IF context.arg.GetInteger(rate,FALSE) & context.arg.GetInteger(divisor,FALSE) THEN
		errorRate := rate  / divisor;
	END;;
END SetErrorRate;


BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(random); errorRate := 0;
END SerialsVirtual.

SerialsVirtual.SetErrorRate 0 1 ~
SerialsVirtual.SetErrorRate 1 100000 ~