MODULE UsbPrinter;  (** AUTHOR "staubesv"; PURPOSE "USB Printing Device Class Driver"; *)
(**
 * This is the Bluebottle implementation of the USB Printing Device Class driver. Note that this driver is mainly
 * for transport data between the host and a USB printer device. You will need approriate Page Description Language (PDL)
 * Printer Control Protocol (PCP) support to be able to actually print anything.
 *
 * Usage:
 *	UsbPrinter.Install ~ loads this driver
 *	SystemTools.Free UsbPrinter ~ unloads it
 *
 * References:
 *	Universal Serial Bus Device Class Definition for Printing Devices 1.0, www.usb.org
 *
 * History:
 *	01.12.2005 	First release (staubesv)
 *	09.01.2006	Adapted to Usb.Mod changes (staubesv)
 *	05.07.2006	Adapted to Usbdi (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Modules, Usbdi;

CONST

	Name = "UsbPrinter";
	Description = "USB Printing Device Class Driver";
	Priority = 10;

	Debug = TRUE;
	Trace = TRUE;

	StatusPaperEmpty = {5};
	StatusSelected = {4};
	StatusNoError = {3};

	(* Printing devices class specific request codes *)
	PrGetDeviceId = 0;
	PrGetPortStatus = 1;
	PrSoftReset = 2;

	(* Printer interface type *)
	PitUnidirectional = 01H;
	PitBidirectional = 02H;
	Pit1284 = 03H; (* IEEE 1284.4 compatible bi-directional interface *)
	PitVendorSpecific = 0FFH;

TYPE

	Printer= OBJECT (Usbdi.Driver)
	VAR
		defaultpipe, bulkInPipe, bulkOutPipe : Usbdi.Pipe;

		(* Printer info *)
		interfaceType : LONGINT;
		deviceId : ARRAY 256 OF CHAR;

		PROCEDURE Connect() : BOOLEAN;
		BEGIN
			defaultpipe := device.GetPipe(0);
			IF defaultpipe = NIL THEN
				IF Debug THEN KernelLog.String("UsbPrinter: Could not get default pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			bulkOutPipe := device.GetPipe(1);
			IF bulkOutPipe = NIL THEN
				IF Debug THEN KernelLog.String("UsbPrinter: Could not get bulk out pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			IF interfaceType # PitUnidirectional THEN
				bulkInPipe := device.GetPipe(82H);
				IF bulkInPipe = NIL THEN
					IF Debug THEN KernelLog.String("UsbPrinter: Could not get bulk in pipe."); KernelLog.Ln; END;
					RETURN FALSE;
				END;
			END;

			IF ~GetDeviceId(deviceId, 0,0,0) THEN
				IF Debug THEN KernelLog.String("UsbPrinter: Could not get device ID."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect;
		BEGIN
			KernelLog.String("UsbPrinter: "); KernelLog.String(name); KernelLog.String(" disconnected."); KernelLog.Ln;
		END Disconnect;

		(*
		 * This class-specific request returns the device ID strings that is compatible with IEEE1284 for
		 * the specified interface.
		 * @param config Zero-based USB device configuration index
		 * @param intf Zero-based USB device interface index
		 * @param alt Zero-based USB device alternate interface index
		 *)
		PROCEDURE GetDeviceId(VAR deviceId : ARRAY OF CHAR; config, intf, alt : LONGINT) : BOOLEAN;
		VAR
			buffer : Usbdi.BufferPtr;
			wValue, wIndex, len, i : LONGINT;
			string : POINTER TO ARRAY OF CHAR;
		BEGIN
			wValue := config;
			wIndex := LSH(intf, 8) + alt;
			NEW(buffer, 2);
			(* First we get the length of the device ID string (first 2 bytes) *)
			IF device.Request(Usbdi.ToHost + Usbdi.Class + Usbdi.Interface, PrGetDeviceId, wValue, wIndex, 2, buffer^) = Usbdi.Ok THEN
				(* Length is encoded in big endian *)
				len := SYSTEM.VAL(LONGINT, ORD(buffer[0]))*100H + SYSTEM.VAL(LONGINT, ORD(buffer[1]));
				NEW(buffer, len);
				IF device.Request(Usbdi.ToHost + Usbdi.Class + Usbdi.Interface, PrGetDeviceId, wValue, wIndex, len, buffer^) = Usbdi.Ok THEN
					NEW(string, len-2);
					FOR i := 0 TO len-3 DO string[i] := buffer[i+2]; END;
					COPY(string^, deviceId);
					IF Trace THEN KernelLog.String("UsbPrinter: DeviceID: "); KernelLog.String(deviceId); KernelLog.Ln; END;
					RETURN TRUE;
				ELSIF Debug THEN KernelLog.String("UsbPrinter: Could not read device ID."); KernelLog.Ln;
				END;
			ELSIF Debug THEN KernelLog.String("UsbPrinter: GetDeviceID's first two bytes  failed."); KernelLog.Ln;
			END;
			RETURN FALSE;
		END GetDeviceId;

		(*
		 * This class-specific request returns the printer's current status in a format which is compatible with the
		 * status register of a standard parallel port printer.
		 * @param portstatus Will be set to the retrieved status
		 * @return TRUE, if operation succeeded, FALSE otherwise
		 *)
		PROCEDURE GetPortStatus(VAR portstatus : SET) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			NEW(buffer, 1);
			IF device.Request(Usbdi.ToHost + Usbdi.Class + Usbdi.Interface, PrGetPortStatus, 0, interface.bInterfaceNumber, 1, buffer^) = Usbdi.Ok THEN
				portstatus := SYSTEM.VAL(SET, buffer[0]);
				IF Trace THEN ShowPrinterStatus(portstatus); END;
				RETURN TRUE;
			ELSE
				IF Debug THEN KernelLog.String("UsbPrinter: GetPortStatus failed."); KernelLog.Ln; END;
				RETURN FALSE;
			END;
		END GetPortStatus;

		(*
		 * This class-specific request flushes all buffers and resets the bulk out and bulk in pipes to their
		 * default states. This request will cleas all stall conditions.
		 * @return TRUE, if operation succeeded, FALSE otherwise
		 *)
		PROCEDURE SoftReset() : BOOLEAN;
		VAR dummy : Usbdi.BufferPtr;
		BEGIN
			NEW(dummy, 1);
			IF device.Request(Usbdi.ToDevice + Usbdi.Class + Usbdi.Interface, PrSoftReset, 0, interface.bInterfaceNumber, 0, dummy^) = Usbdi.Ok THEN
				IF Trace THEN KernelLog.String("UsbPrinter: Printer resetted."); KernelLog.Ln; END;
				RETURN TRUE;
			ELSE
				IF Debug THEN KernelLog.String("UsbPrinter: SoftReset failed."); KernelLog.Ln; END;
				RETURN FALSE;
			END;
		END SoftReset;

	END Printer;

(* Display textual representation of the printer status register *)
PROCEDURE ShowPrinterStatus(status : SET);
BEGIN
	KernelLog.String("UsbPrinter: Printer status: Paper: ");
	IF status * StatusPaperEmpty # {} THEN KernelLog.String("Empty"); ELSE KernelLog.String("Not Empty"); END;
	KernelLog.String(", Selected: ");
	IF status * StatusSelected # {} THEN KernelLog.String("Selected"); ELSE KernelLog.String("Not Selected"); END;
	KernelLog.String(", ");
	IF status * StatusNoError # {} THEN KernelLog.String("No Error"); ELSE KernelLog.String("Error"); END;
	KernelLog.Ln;
END ShowPrinterStatus;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : Printer;
BEGIN
	(* check whether the probed device is a supported USB mouse *)
	IF id.bInterfaceClass # 7 THEN RETURN NIL END; (* Base class for Printers *)
	IF id.bInterfaceSubClass # 1 THEN RETURN NIL END; (* Printer *)

	NEW(driver); driver.interfaceType := id.bInterfaceProtocol;
	IF Trace THEN KernelLog.String("USB Printer found."); KernelLog.Ln; END;
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
END UsbPrinter.
