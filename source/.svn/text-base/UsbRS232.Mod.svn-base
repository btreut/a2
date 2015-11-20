MODULE UsbRS232;  (** AUTHOR "staubesv"; PURPOSE "MCT USB-RS232 Converter Driver"; *)
(**
 *	This module implements a Serials.Port object. It is a Linux port of mct-u232.c, mct-u232.h.
 *
 * Usage:
 *
 *	UsbRS232.Install ~ loads this driver
 *	SystemTools.Free UsbRS232 ~
 *
 * Status: BETA
 *
 * Licence: GPL
 *
 * References:

 *	mct_u232.c Linux USB device driver
 *	mct-u232.h contains some documentation
 *
 * History:
 *
 *	20.01.2006	First Release (staubesv)
 *	14.06.2006	Adapted to changes in Serials.Mod (staubesv)
 *	05.07.2006	Adapted to Usbdi (staubesv)
 *	05.01.2007	Introduced Port.Send procedure for better performance (staubesv)
 *
 * Todo:
 *	- Cleanup mess with constants
 *	- testing
 *)

IMPORT SYSTEM, Kernel, KernelLog, Modules, Serials, Usbdi;

CONST

	Name = "UsbRs232";
	Description = "USB-RS232 Interface Converter Driver";
	Priority = 0;

	BufSize = 1024;

	TraceSend = {0};				(* Display sent characters *)
	TraceReceive = {1};			(* Display received characters *)
	TraceCommands = {2};
	TraceReceiveData = {3};
	TraceReceiveStatus = {4};
	TraceAll = {0..31};
	TraceNone = {};

	Trace = TraceNone;

	Debug = TRUE;
	Verbose = TRUE;

	ModuleName = "UsbRS232";

	(* Expected endpoints *)
	EpBulkOut = 02H; 			(* Used to send data *)
	EpInterruptInData = 082H; 	(* Used to receive data *)
	EpInterruptInStatus = 081H; 	(* Signals exception conditions *)

	IdVendorMct = 0711H; 		(* Magic Control Technology *)
	IdProductU232P9 = 230H; 	(* MCT U232-P9 *)
	IdProductU232P25 = 210H; 	(* MCT U232-P25 *)
	IdProductDUH3SP = 200H;	(* D-Link DU-H3SP USB Bay *)

	IdVendorBelkin = 50DH; 		(* Belkin *)
	IdProductF5U109 = 109H; 	(* Belkin F5U109 *)

	(* Vendor specific requests *)
	MctGetModemStatus = 2; 	(* Get modem status register (MSR) *)
	MctSetBaudrate = 5; 		(* Set baudrate divisor *)
	MctGetLineCtrl = 6; 			(* Get line control register (LCR) *)
	MctSetLineCtrl = 7; 			(* Set line control register (LCR) *)
	MctSetModemCtrl = 10; 		(* Set modem control register (MCR)*)
	MctSetUnknown1 = 11; 		(* Both requests are sent after SetBaudrate requests by windows driver *)
	MctSetUnknown2 = 12;

	(* line control register (LCR) *)
	MctLcrSetBreak = 6;
	MctData5 = {};
	MctData6 = {0};
	MctData7 = {1};
	MctData8 = {0,1};
	MctParityNone = {};
	MctParityEven = {3, 4};
	MctParityOdd = {3};
	MctParityMark = {3, 5};
	MctParitySpace = {3,4,5};
	MctStop1= {};
	MctStop2 = {2}; (* 1.5 stop bits for 5 data bits, 2 stop bits for 6, 7 & 8 data bits *)

	(* Modem control register (MCR) *)
	MctMcrRts = 1; 		(* Activate RTS *)
	MctMcrDtr = 0; 		(* Activate DTR *)
	MctMcrOut2 = 3; 	(* Activate Out2 *)

	(* Modem status register (MSR) *)
	MctMsrCd = 7; 		(* current CD *)
	MctMsrRi = 6; 		(* current RI *)
	MctMsrDsr = 5;		(* current DSR *)
	MctMsrCts = 4; 		(* current CTS *)
	MctMsrDcd = 3; 		(* delta CD, unused *)
	MctMsrDri = 2; 		(* delta RI, unused *)
	MctMsrDdsr = 1; 	(* delta DSR, unused *)
	MctMsrDcts = 0; 	(* delta CTS, unused *)

	(* Line status register (LSR) *)
	MctLsrErr = 7; 		(*  PE / FE / BI, unused *)
	MctLsrTemt = 6; 		(* transmit register empty *)
	MctLsrThre = 5; 		(* transmit holding register empty *)
	MctLsrBi = 4; 		(* break indicator *)
	MctLsrFe = 3; 		(* framing error *)
	MctLsrPe = 2; 		(* parity error *)
	MctLsrOe = 1; 		(* overrun error *)
	MctLsrDr = 0; 		(* receive data ready *)

TYPE

	UsbRs232Driver = OBJECT (Usbdi.Driver)
	VAR
		port : Port;
		controlPipe : Usbdi.Pipe;
		interruptInData, interruptInStatus : Usbdi.Pipe;
		bulkOut : Usbdi.Pipe;
		data1, data4, data64 : Usbdi.BufferPtr; (* datax -> ARRAY x OF CHAR *)
		status2 : Usbdi.BufferPtr;
		diagnostics : SET;
		msr : SET; (* Modem Status Register: Updated by UpdateStatus() & GetMSR *)
		lsr : SET;   (* Line Status Register: Updated by UpdateStatus() *)
		mcr : SET; (* Modem Control Register *)
		lcr : SET;   (* Line Control Register *)
		mc : SET; (*  Serials.DTR, Serials.RTS, Serials.DSR, Serials.CTS, Serials.RI, Serials.DCD & Serials.BI (Break Interrupt) *)

		PROCEDURE Connect() : BOOLEAN;
		VAR ignore : Usbdi.Status;
		BEGIN
			(* Get default control pipe *)
			controlPipe := device.GetPipe(0);
			IF controlPipe = NIL THEN
				IF Debug THEN ShowModule("Couldn't get default control pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Get both interrupt pipes *)
			interruptInData := device.GetPipe(EpInterruptInData);
			interruptInStatus := device.GetPipe(EpInterruptInStatus);
			IF (interruptInData = NIL) OR (interruptInStatus = NIL) THEN
				IF Debug THEN ShowModule("Couldn't get interrupt in pipes."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Get bulk out pipe *)
			bulkOut := device.GetPipe(EpBulkOut);
			IF bulkOut = NIL THEN
				IF Debug THEN ShowModule("Couldn't get bulk out pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* the interrupt pipe for endpoint EpInterruptStatus is used to asynchronously receive status information... set up the USB transfers. *)
			interruptInStatus.SetTimeout(0);
			interruptInStatus.SetCompletionHandler(UpdateStatus);
			ignore := interruptInStatus.Transfer(2, 0, status2^);

			interruptInData.SetTimeout(0);
			interruptInData.SetCompletionHandler(UpdateData);
			ignore := interruptInData.Transfer(64, 0, data64^);

			(* Get Modem Status Register (MSR) *)
			IF ~GetMSR(msr) THEN
				IF Debug THEN ShowModule("GetMSR failed during connect."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Register port at Serials *)
			NEW(port); NEW(port.data1, 1); port.driver := SELF;
			Serials.RegisterPort(port, Description);
			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect;
		BEGIN
			Serials.UnRegisterPort(SELF.port);
		END Disconnect;

		(* Interrupt on Completion - Handler for EpInterruptInData; data contained in variable data64 *)
		PROCEDURE UpdateData(status : Usbdi.Status; actLen : LONGINT);
		VAR ignore : Usbdi.Status; i : LONGINT;
		BEGIN
			IF Trace * TraceReceiveData # {} THEN
				ShowModule("UpdateData: Received "); KernelLog.Int(actLen, 0); KernelLog.String(" Bytes:");
				FOR i := 0 TO actLen - 1 DO KernelLog.Char(" "); KernelLog.Int(ORD(data64[i]), 0); END;
				KernelLog.Ln;
			END;
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN
				port.HandleData(data64^, actLen);
				ignore := interruptInData.Transfer(64, 0, data64^);
			ELSE
				IF Debug THEN ShowModule("UpdateData failed."); KernelLog.Ln; END;
			END;
		END UpdateData;

		(* Interrupt on Completion - Handler for EpInterruptInStatus; data contained in variable status2 *)
		PROCEDURE UpdateStatus(status : Usbdi.Status; actLen : LONGINT);
		VAR ignore : Usbdi.Status;
		BEGIN
			IF Trace * TraceReceiveStatus # {} THEN ShowModule("UpdateStatus: Received "); KernelLog.Int(actLen, 0); KernelLog.String(" Bytes: ");  END;
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN
				IF actLen>=1 THEN
					msr := SYSTEM.VAL(SET, status2[0]); (* status2[0] is the MSR *)
					IF MctMsrRi IN msr THEN INCL(mc, Serials.RI); ELSE EXCL(mc, Serials.RI); END;
					IF MctMsrDsr IN msr THEN INCL(mc, Serials.DSR); ELSE EXCL(mc, Serials.DSR); END;
					IF MctMsrCts IN msr THEN INCL(mc, Serials.CTS); ELSE EXCL(mc, Serials.CTS); END;
					IF MctMsrCd IN msr THEN INCL(mc,  Serials.DCD); ELSE EXCL(mc, Serials.DCD); END;
					IF Trace * TraceReceiveStatus # {} THEN
						IF Serials.RI IN mc THEN KernelLog.String("[RI]"); END;
						IF Serials.DSR IN mc THEN KernelLog.String("[DSR]"); END;
						IF Serials.CTS IN mc THEN KernelLog.String("[CTS]"); END;
						IF Serials.DCD IN mc THEN KernelLog.String("[DCD]"); END;
					END;
				END;
				IF actLen>=2 THEN (* okay... I was expecting 2 bytes of data *)
					lsr := SYSTEM.VAL(SET, status2[1]); (* status2[1] is the LSR *)
					diagnostics := {};
					IF MctLsrOe IN lsr THEN INCL(diagnostics, Serials.OverrunError); END;
					IF MctLsrPe IN lsr THEN INCL(diagnostics, Serials.ParityError); END;
					IF MctLsrFe IN lsr THEN INCL(diagnostics, Serials.FramingError); END;
					IF MctLsrBi IN lsr THEN
						INCL(mc, Serials.BreakInterrupt); INCL(diagnostics, Serials.BreakInterrupt);
					ELSE
						EXCL(mc, Serials.BreakInterrupt);
					END;
					IF Trace * TraceReceiveStatus # {} THEN
						IF Serials.BreakInterrupt IN mc THEN KernelLog.String("[BI]"); END;
						KernelLog.String(" Errors: ");
						IF diagnostics = {} THEN KernelLog.String("none");
						ELSE
							IF Serials.OverrunError IN diagnostics THEN KernelLog.String("[Overrun]"); END;
							IF Serials.ParityError IN diagnostics THEN KernelLog.String("[Parity]"); END;
							IF Serials.FramingError IN diagnostics THEN KernelLog.String("[Framing]"); END;
							IF Serials.BreakInterrupt IN diagnostics THEN KernelLog.String("BreakInterrupt]"); END;
						END;
					END;
				END;
				ignore := interruptInStatus.Transfer(2, 0, status2^);
			ELSE
				IF Debug THEN ShowModule("UpdateStatus failed."); KernelLog.Ln; END;
			END;
			IF Trace * TraceReceiveStatus # {} THEN KernelLog.Ln; END;
		END UpdateStatus;

		(* Set baudrate divisor; returns TRUE if operation succeeded, FALSE otherwise *)
		PROCEDURE SetBaudrate(baudrate : LONGINT) : BOOLEAN;
		VAR divisor : LONGINT; status : Usbdi.Status;
		BEGIN
			IF Trace * TraceCommands # {} THEN ShowModule("SetBaudrate to "); KernelLog.Int(baudrate, 0); KernelLog.String(" bps."); KernelLog.Ln; END;
			port.portbps := 0; (* indicates invalid value *)

			IF ((device.descriptor.idVendor = IdVendorMct) & (device.descriptor.idProduct = IdProductU232P25)) OR
			   ((device.descriptor.idVendor = IdVendorMct) & (device.descriptor.idProduct = IdProductU232P9)) THEN (* use one-byte coded value ... *)
				IF baudrate = 300 THEN divisor := 01H
				ELSIF baudrate = 600 THEN divisor := 02H;
				ELSIF baudrate = 1200 THEN divisor := 03H;
				ELSIF baudrate = 2400 THEN divisor := 04H;
				ELSIF baudrate = 4800 THEN divisor := 06H;
				ELSIF baudrate = 9600 THEN divisor := 08H;
				ELSIF baudrate = 19200 THEN divisor := 09H;
				ELSIF baudrate = 38400 THEN divisor := 0AH;
				ELSIF baudrate = 57600 THEN divisor := 0BH;
				ELSIF baudrate = 115200 THEN divisor := 0CH;
				ELSE
					IF Debug THEN ShowModule("SetBaudrate: Wrong baud rate selected."); KernelLog.Ln; END;
					RETURN FALSE;
				END;

				data1[0] := CHR(divisor);
				status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetBaudrate, 0, 0, 1, data1^);

			ELSE (* standart UART way ... *)
				IF (115200 MOD baudrate) # 0 THEN
					IF Debug THEN ShowModule("SetBaudrate: Wrong baud rate selected."); KernelLog.Ln; END;
					RETURN FALSE;
				ELSE
					divisor := 115200 DIV baudrate;
				END;

				data4[0] := CHR(divisor);
				data4[1] := CHR(LSH(divisor, -8));
				data4[2] := CHR(LSH(divisor, -16));
				data4[3] := CHR(LSH(divisor, -24));
				status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetBaudrate, 0, 0, 4, data4^);
			END;

			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetBaudrate failed (MctSetBaudrate)"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* don't known what the following two vendor-specific requests are good for ... just imitating the windows driver *)
			data1[0] := CHR(0);

			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetUnknown1, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetBaudrate failed (MctSetUnknown1). "); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetUnknown2, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetBaudrate failed (MctSetUnknown1). "); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			port.portbps := baudrate;
			RETURN TRUE;
		END SetBaudrate;

		(* Vendor-specific request: Used to set the Line Control Register (LCR) *)
		PROCEDURE SetLCR(set : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			data1[0] := SYSTEM.VAL(CHAR, set);
			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetLineCtrl, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetLCR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				lcr := set;
				RETURN TRUE;
			END;
		END SetLCR;

		(* vendor-specific request: Used to get the Line Control Register (LCR) *)
		PROCEDURE GetLCR(VAR lcr : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(Usbdi.ToHost + Usbdi.Vendor + Usbdi.Device, MctGetLineCtrl, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("GetLCR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				lcr := SYSTEM.VAL(SET, data1[0]);
				RETURN TRUE;
			END;
		END GetLCR;

		(* Vendor-specific request: used to set RTS & DTR Bits of the Modem Control Register (MCR) *)
		(* Updates DTR&RTS in mc *)
		PROCEDURE SetMCR(set : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			IF Serials.DTR IN set THEN INCL(mcr, MctMcrDtr); ELSE EXCL(mcr, MctMcrDtr); END;
			IF Serials.RTS IN set THEN INCL(mcr, MctMcrRts); ELSE EXCL(mcr, MctMcrRts); END;
			INCL(mcr, MctMcrOut2); (* Always enable Out2 *)

			data1[0] := CHR(SYSTEM.VAL(LONGINT, mcr));

			status := device.Request(Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device, MctSetModemCtrl, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("SetMCR failed: "); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				IF Serials.DTR IN set THEN INCL(mc, Serials.DTR) ELSE EXCL(mc, Serials.DTR) END;
				IF Serials.RTS IN set THEN INCL(mc, Serials.RTS) ELSE EXCL (mc, Serials.RTS) END;
				RETURN TRUE;
			END;
		END SetMCR;

		(* Updates the msr & mc variable *)
		PROCEDURE GetMSR(VAR value : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(Usbdi.ToHost + Usbdi.Vendor + Usbdi.Device, MctGetModemStatus, 0, 0, 1, data1^);
			IF status # Usbdi.Ok THEN
				IF Debug THEN ShowModule("GetMSR failed."); KernelLog.Ln; END;
				RETURN FALSE;
			ELSE
				IF Trace * TraceCommands # {} THEN ShowModule("GetMSR succeeded (value: "); KernelLog.Bits(SYSTEM.VAL(SET, data1[0]), 0, 8); KernelLog.String(")");  KernelLog.Ln; END;
				msr := SYSTEM.VAL(SET, data1[0]);
				IF MctMsrRi IN msr THEN INCL(mc, Serials.RI); ELSE EXCL(mc, Serials.RI); END;
				IF MctMsrDsr IN msr THEN INCL(mc, Serials.DSR); ELSE EXCL(mc, Serials.DSR); END;
				IF MctMsrCts IN msr THEN INCL(mc, Serials.CTS); ELSE EXCL(mc, Serials.CTS);  END;
				IF MctMsrCd IN msr THEN INCL(mc, Serials.DCD); ELSE EXCL(mc, Serials.DCD); END;
				value := msr;
				RETURN TRUE;
			END;
		END GetMSR;

		PROCEDURE &Init*;
		BEGIN
			NEW(data1, 1); NEW(data4, 4); NEW(data64, 64); NEW(status2, 2);
			msr := {}; lsr := {}; mcr := {}; lcr := {};
		END Init;

	END UsbRs232Driver;

TYPE

	Port = OBJECT(Serials.Port)
	VAR
		driver : UsbRs232Driver;
		portbps : LONGINT;
		data1 : Usbdi.BufferPtr; (* datax -> ARRAY x OF CHAR *)
		buf: ARRAY BufSize OF CHAR;
		head, tail: LONGINT;
		open: BOOLEAN;
		diagnostic: LONGINT;

		PROCEDURE Open*(bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF open THEN
				IF Verbose THEN ShowModule(name); KernelLog.String(" already open"); KernelLog.Ln; END;
				res := Serials.PortInUse;
				RETURN;
			END;
			SetPortState(bps, data, parity, stop, res);
			IF res = Serials.Ok THEN
				open := TRUE;
				head := 0; tail:= 0;
				IF Verbose THEN ShowModule(name); KernelLog.String("opened"); KernelLog.Ln; END;
			END
		END Open;

		(** Send len characters from buf to output, starting at ofs. res is non-zero on error. *)
		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR status : Usbdi.Status; buffer: POINTER TO ARRAY OF CHAR;
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			IF Trace * TraceSend # {} THEN ShowModule("Sending "); KernelLog.Int(len, 0); KernelLog.String(" bytes"); KernelLog.Ln; END;
			NEW (buffer, len); COPY (buf, buffer^);
			status := driver.bulkOut.Transfer(len, ofs, buffer^);
			IF status = Usbdi.Ok THEN
				res := Serials.Ok;
				charactersSent := charactersSent + len;
			ELSE
				res := Serials.TransportError;
				IF Debug THEN ShowModule("Transmission failed, res: "); KernelLog.Int(status, 0); KernelLog.Ln; END;
			END;
		END Send;

		(** Send a single character to the UART. *)
		PROCEDURE SendChar*(ch: CHAR; VAR res : LONGINT);
		VAR status : Usbdi.Status;
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			data1[0] := ch;
			IF Trace * TraceSend # {} THEN ShowModule("Sending character ORD: "); KernelLog.Int(ORD(data1[0]), 0); KernelLog.Ln; END;
			status := driver.bulkOut.Transfer(1, 0, data1^);
			IF status # Usbdi.Ok THEN
				res := Serials.Ok;
				INC(charactersSent);
			ELSE
				res := Serials.TransportError;
				IF Debug THEN ShowModule("Transmission of character failed."); KernelLog.Ln; END;
			END;
		END SendChar;

		(** Wait for the next character is received in the input buffer. The buffer is fed by HandleData *)
		PROCEDURE ReceiveChar*(VAR ch: CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Serials.Closed; RETURN; END;
			AWAIT(tail # head);
			IF tail = -1 THEN
				res := Serials.Closed;
			ELSE
				ch := buf[head]; head := (head+1) MOD BufSize;
				res := diagnostic
			END
		END ReceiveChar;

		(** On detecting an interupt request, transfer the characters from the UART buffer to the input buffer *)
		PROCEDURE HandleData(data :  Usbdi.Buffer; actLen : LONGINT);
		VAR n, i : LONGINT; 	ch : CHAR;
		BEGIN {EXCLUSIVE}
			charactersReceived := charactersReceived + actLen;
			i := 0;
			LOOP
				IF i >= actLen THEN EXIT; END;
				ch := data[i];
				n := (tail + 1) MOD BufSize;
				IF n # head THEN
					buf[tail] := ch; tail := n
				ELSE
					IF Debug THEN KernelLog.String("Port: HandleData: Buffer overflow detected."); KernelLog.Ln; END;
				END;
				INC(i);
				diagnostic := SYSTEM.VAL(LONGINT, driver.diagnostics); (* includes Serials.OE, Serials.PE, Serials.FE & Serials.BI *)
			END;
		END HandleData;

		PROCEDURE Available*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN (tail - head) MOD BufSize
		END Available;

		PROCEDURE SetPortState(bps, data, parity, stop : LONGINT; VAR res: LONGINT);
		VAR s : SET;
		BEGIN
			IF (bps > 0) & (115200 MOD bps = 0) THEN

				IF (data >= 5) & (data <= 8) & (parity >= Serials.ParNo) & (parity <= Serials.ParSpace) & (stop >= Serials.Stop1) & (stop <= Serials.Stop1dot5) THEN

					IF ~driver.SetBaudrate(bps) THEN
						res := Serials.WrongBPS; RETURN;
					END;

					(* Prepare parameters destined to LCR data, stop, parity *)
					CASE data OF	(* word length *)
						   5: s := MctData5;
						| 6: s := MctData6;
						| 7: s := MctData7;
						| 8: s := MctData8;
					END;

					CASE parity OF
						   Serials.ParNo: 		s := s + MctParityNone;
						| Serials.ParOdd: 	s := s + MctParityOdd;
						| Serials.ParEven: 	s := s + MctParityEven;
						| Serials.ParMark: 	s := s + MctParityMark;
						| Serials.ParSpace: 	s := s + MctParitySpace;
					END;

					IF (stop = Serials.Stop1dot5) & (data # 5) THEN res := Serials.WrongStop; RETURN; END;
					IF stop # Serials.Stop1 THEN s := s + MctStop2;  END;

					(* Finalize the LCR *)
					IF ~driver.SetLCR(s) THEN
						res := Serials.WrongData;RETURN;
					END;

					(* Set DTR, RTS in the MCR *)
					s := {}; INCL(s, Serials.DTR); INCL(s, Serials.RTS);
					IF ~driver.SetMCR(s) THEN
						res := Serials.WrongData; RETURN;
					END;
					res := Serials.Ok
				ELSE
					res := Serials.WrongData (* bad data/parity/stop *)
				END
			ELSE
				res := Serials.WrongBPS (* bad BPS *)
			END;
		END SetPortState;

		(** Get the port state: speed, no. of data bits, parity, no. of stop bits *)
		PROCEDURE GetPortState*(VAR openstat : BOOLEAN; VAR bps, data, parity, stop : LONGINT);
		VAR set : SET; res : BOOLEAN;
		BEGIN
			(* get parameters *)
			openstat := open;
			bps := portbps;

			res := driver.GetLCR(set);
			IF set * {0, 1} = MctData8 THEN data := 8;
			ELSIF set * {0, 1} = MctData7 THEN data := 7;
			ELSIF set * {0, 1} = MctData6 THEN data := 6;
			ELSE data := 5;
			END;

			IF set * MctStop2 # {} THEN
				IF set * {0, 1} = MctData5 THEN stop := Serials.Stop1dot5; 	ELSE stop := Serials.Stop2; END;
			ELSE
				stop := Serials.Stop1;
			END;

			IF set * {3..5} = MctParitySpace THEN parity := Serials.ParSpace;
			ELSIF set * {3..5} = MctParityMark THEN parity := Serials.ParMark;
			ELSIF set * {3..5} = MctParityEven THEN parity := Serials.ParEven;
			ELSIF set * {3..5} = MctParityOdd THEN parity := Serials.ParOdd;
			ELSE parity := Serials.ParNo;
			END;
			IF Trace * TraceCommands # {} THEN
				ShowModule("GetPortState of port "); KernelLog.String(name); KernelLog.String(":");
				IF res THEN
					KernelLog.String(" State: "); IF open THEN KernelLog.String("Open"); ELSE KernelLog.String("Closed"); END;
					KernelLog.String(" DataBits: "); KernelLog.Int(data, 0);
					KernelLog.String(" StopBits: "); IF stop=3 THEN KernelLog.String("1.5"); ELSE KernelLog.Int(stop, 0); END;
					KernelLog.String(" Parity: ");
					CASE parity OF
						0 : KernelLog.String("None");
						|1 : KernelLog.String("Odd");
						|2 : KernelLog.String("Even");
						|3 : KernelLog.String("Mark");
						|4 : KernelLog.String("Space");
					ELSE
						KernelLog.String("Unknown");
					END;
					KernelLog.String(" Bps: "); KernelLog.Int(bps, 0); KernelLog.Ln;
				ELSE
					KernelLog.String("Status request failed."); KernelLog.Ln;
				END;
			END;
		END GetPortState;

		(** ClearMC - Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC*(s: SET);
		VAR  temp : SET; ignore : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF s * {Serials.DTR, Serials.RTS} # {} THEN
				temp := driver.mcr;
				IF s * {Serials.DTR} # {} THEN EXCL(temp, Serials.DTR); END;
				IF s * {Serials.RTS} # {} THEN EXCL(temp, Serials.RTS); END;
				ignore := driver.SetMCR(temp);
			END;
			IF Serials.Break IN s THEN
				ignore := driver.GetLCR(temp);
				EXCL(temp, Serials.Break);
				ignore := driver.SetLCR(temp);
			END;
		END ClearMC;

		(** SetMC - Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC*(s: SET);
		VAR ignore : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF s * {Serials.DTR, Serials.RTS} # {} THEN ignore := driver.SetMCR(s * {Serials.DTR, Serials.RTS}); END;
			IF Serials.Break IN s THEN
				ignore := driver.SetLCR({Serials.Break});
			END;
		END SetMC;

		(** GetMC - Return the state of the specified modem control lines. s contains the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC*(VAR s: SET);
		BEGIN {EXCLUSIVE}
			s := driver.msr; (* Inlcudes CTS, DSR, RI, CD *)
			IF MctLsrBi IN driver.lsr THEN INCL(s, Serials.Break); END;
		END GetMC;

		PROCEDURE Close*;
		VAR timer : Kernel.Timer; counter : LONGINT;
		BEGIN {EXCLUSIVE}
			IF ~open THEN
				IF Verbose THEN ShowModule(name); KernelLog.String(" not open"); KernelLog.Ln; END;
				RETURN;
			ELSE
				IF ~(MctLsrTemt IN driver.lsr) THEN (* wait for last byte to leave *)
					NEW(timer); counter := 0;
					REPEAT
						timer.Sleep(1);
						INC(counter);
					UNTIL (MctLsrTemt IN driver.lsr) OR (counter>100); (* No remaining word in the FIFO or transmit shift register *)
				END;
				tail := -1; (* Force a pending Receive to terminate in error. *)
				open := FALSE;
				IF Verbose THEN ShowModule(name); KernelLog.String(" closed"); KernelLog.Ln END;
			END;
		END Close;

	END Port;

PROCEDURE ShowModule(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END ShowModule;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : UsbRs232Driver;
BEGIN
	IF ((dev.descriptor.idVendor = IdVendorMct) & (dev.descriptor.idProduct = IdProductU232P9)) THEN (* MCT U232-P9 *)
	ELSIF ((dev.descriptor.idVendor = IdVendorMct) & (dev.descriptor.idProduct = IdProductU232P25)) THEN (* MCT U232-P25 *)
	ELSIF ((dev.descriptor.idVendor = IdVendorMct) & (dev.descriptor.idProduct = IdProductDUH3SP)) THEN (* D-Link USB Bay *)
	ELSIF ((dev.descriptor.idVendor = IdVendorBelkin) & (dev.descriptor.idProduct = IdProductF5U109)) THEN (* Belkin F5U109 *)
	ELSE (* device not supported *)
		RETURN NIL;
	END;
	NEW(driver);
	RETURN driver;
END Probe;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

PROCEDURE Install*;
END Install;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, Priority)
END UsbRS232.

UsbRS232.Install ~   SystemTools.Free UsbRS232 ~