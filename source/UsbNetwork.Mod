MODULE UsbNetwork; (** AUTHOR "staubesv"; PURPOSE "USB network device driver framework"; *)
(**
 * History:
 *
 *	03.11.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Usbdi, Commands, Network, Plugins;

CONST

	Ok* = 0;
	Error* = 1;
	Unsupported* = 2;

	MinEthernetFrameSize* = 60;
	MaxEthernetFrameSize* = 1514;
	EthernetHeaderSize* = 14;

	Name = "UsbNet#";
	Description = "USB Link Device";

	ModuleName = "UsbNetwork";

	AddressSize = 6;

	RegisterAtNetwork = TRUE;

TYPE

	UsbLinkDevice = OBJECT (Network.LinkDevice)
	VAR
		controller : UsbNetworkController;

		PROCEDURE Linked(): LONGINT;
		BEGIN
			RETURN controller.linkStatus;
		END Linked;

		PROCEDURE DoSend(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR;  h3len, h4len, dofs, dlen: LONGINT);
		BEGIN
			controller.SendFrame(dst, type, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
		END DoSend;

		PROCEDURE Finalize(connected: BOOLEAN);
		BEGIN
			controller.Finalize;
			Finalize^(connected);
		END Finalize;

		PROCEDURE Diag;
		BEGIN
			Show(" Diagnostics:"); KernelLog.Ln;
			IF controller # NIL THEN controller.Diag;
			ELSE KernelLog.String("No controller available."); KernelLog.Ln;
			END;
		END Diag;

		PROCEDURE Show*(CONST string : ARRAY OF CHAR);
		BEGIN
			KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("): "); KernelLog.String(string);
		END Show;

	END UsbLinkDevice;

TYPE

	UsbNetworkController* = OBJECT (Usbdi.Driver)
	VAR
		bulkInPipe-, bulkOutPipe-, interruptInPipe- : Usbdi.Pipe;

		rxBuffer-, interruptInBuffer- : Usbdi.BufferPtr;

		linkDevice- : UsbLinkDevice;
		linkStatus* : LONGINT;

		(** Interface to be implemented by actual network controller driver *)

		PROCEDURE SendFrame*(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR;  h3len, h4len, dofs, dlen: LONGINT); (* abstract *)
		BEGIN {EXCLUSIVE} HALT(301); END SendFrame;

		PROCEDURE GetLinkAddress*(VAR linkAddress : Network.LinkAdr; VAR res : LONGINT); (* abstract *)
		BEGIN HALT(301); END GetLinkAddress;

		PROCEDURE SetLinkAddress*(linkAddress : Network.LinkAdr; VAR res : LONGINT); (* abstract *)
		BEGIN HALT(301); END SetLinkAddress;

		PROCEDURE HandleInterrupt*(status : Usbdi.Status; actLen : LONGINT); (* abstract *)
		BEGIN HALT(301); END HandleInterrupt;

		PROCEDURE HandleBulkIn*(status : Usbdi.Status; actLen : LONGINT); (* abstract *)
		BEGIN HALT(301); END HandleBulkIn;

		PROCEDURE InitController*(VAR rxBuffer : Usbdi.BufferPtr) : BOOLEAN; (* abstract *)
		BEGIN HALT(301); END InitController;

		PROCEDURE Finalize*; (* abstract *)
		BEGIN HALT(301); END Finalize;

		PROCEDURE Diag*;
		BEGIN
			KernelLog.String("Diagnostics of "); KernelLog.String(name);
			KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String(")"); KernelLog.Ln;
		END Diag;

		PROCEDURE InitLinkDevice() : BOOLEAN;
		VAR name : Plugins.Name; nofDevices, i, res : LONGINT;
		BEGIN
			NEW(linkDevice, Network.TypeEthernet, 1000, AddressSize);

			linkDevice.controller := SELF;

			nofDevices := GetNofDevices();
			name := Name;
			i := 0; WHILE name[i] # 0X DO INC(i) END;
			IF nofDevices > 9 THEN
				name[i] := CHR(ORD("A") + nofDevices - 10);
			ELSE
				name[i] := CHR(ORD("0") + nofDevices);
			END;
			name[i+1] := 0X;
			linkDevice.SetName(name);
			linkDevice.desc := Description;

			(* Set ethernet broadcast address: FF-FF-FF-FF-FF-FF *)
			FOR i := 0 TO 5 DO linkDevice.broadcast[i] := 0FFX; END;

			GetLinkAddress(linkDevice.local, res);
			IF res # Ok THEN
				Show("Could not get link address, res: "); KernelLog.Int(res, 0); KernelLog.Ln;
				RETURN FALSE;
			END;

			IF ~RegisterAtNetwork THEN RETURN TRUE; END;

			Network.registry.Add(linkDevice, res);
			ASSERT(res = Plugins.Ok);
			IncNofDevices;

			RETURN TRUE;
		END InitLinkDevice;

		PROCEDURE GetPipes(VAR bulkInPipe, bulkOutPipe, interruptInPipe : Usbdi.Pipe);
		VAR i : LONGINT; bulkInEndpoint, bulkOutEndpoint, interruptInEndpoint : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(interface.endpoints)-1 DO
				IF interface.endpoints[i].type = Usbdi.BulkIn THEN
					bulkInEndpoint := interface.endpoints[i].bEndpointAddress;
				ELSIF interface.endpoints[i].type = Usbdi.BulkOut THEN
					bulkOutEndpoint := interface.endpoints[i].bEndpointAddress;
				ELSIF interface.endpoints[i].type = Usbdi.InterruptIn THEN
					interruptInEndpoint := interface.endpoints[i].bEndpointAddress;
				END;
			END;
			IF bulkInEndpoint # 0 THEN bulkInPipe := device.GetPipe(bulkInEndpoint); END;
			IF bulkOutEndpoint # 0 THEN bulkOutPipe := device.GetPipe(bulkOutEndpoint); END;
			IF interruptInEndpoint # 0 THEN interruptInPipe := device.GetPipe(interruptInEndpoint); END;
		END GetPipes;

		PROCEDURE Connect*() : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			linkStatus := Network.LinkUnknown;

			GetPipes(bulkInPipe, bulkOutPipe, interruptInPipe);

			IF (bulkInPipe = NIL) OR (bulkOutPipe = NIL) OR (interruptInPipe = NIL) THEN
				Show("Device endpoints not found."); KernelLog.Ln;
				RETURN FALSE;
			END;

			IF ~InitController(rxBuffer) THEN
				Show("Controller initialization failed."); KernelLog.Ln;
				RETURN FALSE;
			END;

			bulkInPipe.SetTimeout(0);
			bulkInPipe.SetCompletionHandler(HandleBulkIn);

			status := bulkInPipe.Transfer(bulkInPipe.maxPacketSize, 0, rxBuffer^); (* ignore status *)

			(* setup status pipe *)
			NEW(interruptInBuffer, interruptInPipe.maxPacketSize);

			interruptInPipe.SetTimeout(0);
			interruptInPipe.SetCompletionHandler(HandleInterrupt);

			status := interruptInPipe.Transfer(interruptInPipe.maxPacketSize, 0, interruptInBuffer^); (* ignore status *)

			IF ~InitLinkDevice() THEN
				Show("Link device initialization failed."); KernelLog.Ln;
				RETURN FALSE;
			END;

			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect*;
		BEGIN
			IF ~RegisterAtNetwork THEN RETURN; END;
			Network.registry.Remove(linkDevice);
		END Disconnect;

	END UsbNetworkController;

VAR
	nofDevices : LONGINT;

(** Show diagnostics of the specified link device *)
PROCEDURE Diag*(context : Commands.Context); (** linkdevice ~ *)
VAR plugin : Plugins.Plugin; name : ARRAY 128 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(name);
	plugin := Network.registry.Get(name);
	IF plugin # NIL THEN
		IF plugin IS UsbLinkDevice THEN
			plugin(UsbLinkDevice).Diag;
		ELSE
			context.out.String("Link device "); context.out.String(name); context.out.String(" is not a USB link device."); context.out.Ln;
		END;
	ELSE
		context.out.String("Link device "); context.out.String(name); context.out.String(" not found."); context.out.Ln;
	END;
END Diag;

PROCEDURE IncNofDevices;
BEGIN {EXCLUSIVE}
	INC(nofDevices);
END IncNofDevices;

PROCEDURE GetNofDevices() : LONGINT;
BEGIN {EXCLUSIVE}
	RETURN nofDevices;
END GetNofDevices;

PROCEDURE Show(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END Show;

END UsbNetwork.

UsbNetwork.Diag UsbNet#0 ~
UsbNetwork.Diag UsbNet#1 ~
UsbNetwork.Diag UsbNet#2 ~

SystemTools.Free UsbNetwork ~
