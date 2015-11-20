MODULE Usb;  (** AUTHOR "staubesv"; PURPOSE "USB 2.0 Bus Driver"; *)
(**
 * Bluebottle USB 2.0 Bus Driver based on Usb.Mod from "cplattner".
 *
 * Note that the hub driver (UsbHubDriver.Mod) is closely coupled with the USB driver. The USB driver maintains bus topology using
 * UsbDevice object. Usb.rootHubArray is the root of the tiered-star topology. These are the root hubs of the USB host controllers, which
 * are represented as EmulatedHubDevice. All other USB devices are represented using UsbDevice objects. If the hubFlag of such an object
 * is set, it represents a USB hub. Then the hubPortDevices array is valid.
 *
 * References:
 *
 * 	Universal Serial Bus Specification, Revision 2.0
 * 	USB Interface Association Descriptor and Device Class Code and Use Model
 * 	USB Engineering Change Notice: Interface Association Descriptors (Applies to USB Specification 2.0)
 *
 *	All references can be found at http://www.usb.org
 *
 * History:
 *
 *	01.12.2005	First release (staubesv)
 *	07.12.2005	Support for automatic device driver loading using UsbDriverLoader (staubesv)
 *	12.12.2005 	Exception handling for Usbdi.Driver.Connect added (staubesv)
 *	13.12.2005 	Fixed UsbDevice.InternalParseConfiguration (always ask for 8 bytes, some devices didn't like less) (staubesv)
 *	03.12.2005	Fixed bug in DriverManager.Remove that prevented automatic USB pipe de-allocation when removing the device driver,
 *				added exception handling for Usbdi.Driver.Disconnect (staubesv)
 *	25.01.2006	Don't import UTF8String anymore, copied the procedure needed to this file to save space for the boot file (staubesv)
 *	10.02.2006	Moved TrimWS & Length into this module (staubesv)
 *	09.06.2006	DriverManager is notified when the driver lookup service is enabled (staubesv)
 *	28.06.2006	Removed some unnecessary exports, procedure GetRootHubs now copies rootHubs array, moved utility procedures
 *				to module UsbStrings.Mod (staubesv)
 *	26.07.2006	Replaced DriverManager.Notify mechanism by nbrOfDriverEvents variable, clients can poll this value to be
 *				informed about driver adds/removals (staubesv)
 *	02.08.2006	ParseEndpointDescriptor enhanced for EndpointDescriptor.type field, adapted to Usbdi changes (staubesv)
 *	05.01.2007	Check descriptor type in UsbDevice.GetDescriptor (staubesv)
 *	22.03.2007	Renamed UsbDevice fields hubPortDevices, hubPortPermanentlyDisabled & HubPortErrors to deviceAtPort,
 *				portPermanentlyDisabled & portErrors
 *
 * TODOs
 * 	- more general GetStringDescriptor
 *	- put driver manager in own module, driver manager should only return reference to appropriate driver, not call its connect/disconnect procedures
 *)

IMPORT SYSTEM, Modules, Machine, Plugins, KernelLog, UsbDriverLoader, Usbdi, UsbHcdi, Debug := UsbDebug, Lib := UsbUtilities;

CONST

	(** USB device states *)
	StateDisconnected* = -1;
	StateAttached* = 0;
	StatePowered* = 1;
	StateDefault* = 2;
	StateAddress* = 3;
	StateConfigured* = 4;
	StateSuspended* = 5;

	(* Descriptor types for GetDescriptor & SetDesciptor USB standard requests *)
	DescriptorDevice = 1;
	DescriptorConfiguration = 2;
	DescriptorString = 3;
	DescriptorInterface = 4;
	DescriptorEndpoint = 5;
	DescriptorDeviceQualifier = 6;
	DescriptorOtherSpeedConfig = 7;
	DescriptorInterfacePower = 8;
	DescriptorOtg = 9;
	DescriptorDebug = 10;
	DescriptorIad = 11; (* Interface Associtation Descriptor *)

	(* Standard Request Codes (USB2.0, p. 251) *)
	SrGetStatus = 0;
	SrClearFeature = 1;
	SrSetFeature = 3;
	SrSetAddress = 5;
	SrGetDescriptor = 6;
	SrSetDescriptor = 7;
	SrGetConfiguration = 8;
	SrSetConfiguration = 9;
	SrGetInterface = 10;
	SrSetInterface = 11;
	SrSynchFrame = 12;

	(** Standard feature selectors for GetFeature & SetFeature USB standard requests *)
	FsDeviceRemoteWakeup* = 1;
	FsEndpointHalt* = 0;
	FsTestMode* = 2;

	(** GetStatus bits (recipient = Device) *)
	SelfPowered* = {0}; 		(* Current power source *)
	RemoteWakeup* = {1}; 	(* Remote Wakeup enabled? *)
	(** GetStatus bits (recipient = Endpoint) *)
	Halted* = {0}; 			(* Endpoint halted? *)

	LowSpeed* = 0;
	FullSpeed* = 1;
	HighSpeed* = 2;

	(* LANGID codes used by string descriptors, see HID page on www.usb.org *)
	IdUserDefault = 0400H;
	IdSystemDefault = 0800H;
	IdEnglishUS = 0409H;
	IdEnglishUK = 0809H;

	(* Timeouts *)
	DefaultTimeout* = 5000;

	(* Driver manager constants *)
	DmMaxPriorities = 12;

TYPE

	Name* = Usbdi.Name;
	Description* = Usbdi.Description;

TYPE

	DeviceDescriptor* = POINTER TO RECORD (Usbdi.DeviceDescriptor)
		bMaxPacketSize0- : LONGINT;

		iManufacturer- : LONGINT;
		iProduct- : LONGINT;
		iSerialNumber- : LONGINT;

		sManufacturer- : Lib.AsciiString;
		sProduct- : Lib.AsciiString;
		sSerialNumber- : Lib.AsciiString;

		uManufacturer- : Lib.UnicodeString;
		uProduct- : Lib.UnicodeString;
		uSerialNumber- : Lib.UnicodeString;
	END;

	(** As specified in the Universal Serial Bus Specification 1.1/2.0 **)
	ConfigurationDescriptor* = POINTER TO RECORD (Usbdi.ConfigurationDescriptor)
		bLength- : LONGINT;
		wTotalLength- : LONGINT;
		iConfiguration- : LONGINT;
		bmAttributes- : SET;
		bMaxPower- : LONGINT;

		sConfiguration- : Lib.AsciiString;
		uConfiguration- : Lib.UnicodeString;

		(* Decoded bmAttributes *)
		selfPowered- : BOOLEAN;
		remoteWakeup- : BOOLEAN;
	END;

	(** UsbDeviceInterface: As specified in the Universal Serial Bus Specification 1.1/2.0
		Oberon Usb addition: "Driver" points to the device driver for this interface, NIL means no driver (yet) attached
		to this interface  **)
	InterfaceDescriptor* = POINTER TO RECORD (Usbdi.InterfaceDescriptor)
		bLength- : LONGINT;
		iInterface- : LONGINT;
		sInterface- : Lib.AsciiString;
		uInterface- : Lib.UnicodeString;
		driver- : Usbdi.Driver;
	END;

	(** EndpointDescriptor: As specified in the Universal Serial Bus Specification 1.1/2.0 **)
	EndpointDescriptor* = POINTER TO RECORD (Usbdi.EndpointDescriptor)
		bLength- : LONGINT;
		bInterval- : LONGINT; (* Raw value; interpretation dependend on transfer speed and transfer type *)
		mult- : LONGINT; (* Only for high-speed isochronous & interrupt transfers: How many transactions per microframe (1,2 or 3) *)
	END;

	InterfaceAssociationDescriptor* = POINTER TO RECORD (Usbdi.InterfaceAssociationDescriptor);
		bLength- : LONGINT;
		iFunction- : LONGINT;
		sFunction- : Lib.AsciiString;
		uFunction- : Lib.UnicodeString;
	END;

TYPE

	UsbDevice* = OBJECT(Usbdi.UsbDevice)
	VAR
		(* Default control pipe (endpoint zero) *)
		defaultpipe* : UsbHcdi.Pipe;

		(* Device Qualifier; NIL if not available *)
		qualifier- : DeviceDescriptor;

		(* Other speed configurations *)
		otherconfigurations- : Usbdi.Configurations;

		address* : LONGINT;
		speed* : LONGINT; (* Usb.LowSpeed, Usb.FullSpeed, Usb.HighSpeed *)

		(* This device is connected to the port <port> of the UsbDevice <parent> *)
		parent* : UsbDevice;
		port* : LONGINT;

		(* 	If this is a low- or fullspeed device that is connected to a high-speed bus, the device is connected to
			the high-speed hub with the device address <ttAddress> at port <ttPort> *)
		ttAddress*, ttPort* : LONGINT;

		hubFlag* : BOOLEAN;
		(* USB hub specific fields *)
		nbrOfPorts* : LONGINT;
		deviceAtPort* : POINTER TO ARRAY OF UsbDevice;
		portPermanentDisabled* : POINTER TO ARRAY OF BOOLEAN;
		portErrors* : POINTER TO ARRAY OF LONGINT;

		(* Private, exported readonly to grant access to bytesTransfered field of the controller *)
		controller* : UsbHcdi.Hcd;

		PROCEDURE SetState*(state : LONGINT);
		BEGIN {EXCLUSIVE}
			IF Debug.Trace & Debug.traceDeviceStates THEN ShowStateTransition(SELF, state); END;
			SELF.state := state;
		END SetState;

		(*
		 * Build a pipe object for the specified endpoint.
		 * @param interface: USB device interface to be searched
		 * @param endpointAddr: Address of endpoint to be searched
		 * @return: Pipe for specified endpoint; NIL if endpoint not found
		 *)
		PROCEDURE GetPipeByInterface(interface : InterfaceDescriptor; endpointAddr : LONGINT) : UsbHcdi.Pipe;
		VAR pipe : UsbHcdi.Pipe; endpoint : EndpointDescriptor; endp : LONGINT;
		BEGIN
			WHILE (endp < interface.bNumEndpoints) DO (* Search all endpoints of the interface *)
				IF interface.endpoints[endp].bEndpointAddress = endpointAddr THEN (* Found ! *)
					endpoint := interface.endpoints[endp](EndpointDescriptor);
					NEW(pipe, address, endpointAddr, controller);
					IF (SYSTEM.VAL(SET, endpointAddr) * {7}) = {7} THEN (* device-to-host *)
						pipe.direction := UsbHcdi.In;
					ELSE (* host-to-device *)
						pipe.direction := UsbHcdi.Out;
					END;
					pipe.status := Usbdi.InProgress;
					pipe.mult := endpoint.mult;
					pipe.device := SELF;
					pipe.ttPort := ttPort;
					pipe.ttAddress := ttAddress;
					pipe.type := SYSTEM.VAL(INTEGER,endpoint.bmAttributes *  {0,1});
					IF pipe.type = UsbHcdi.PipeControl THEN
						pipe.direction := UsbHcdi.In;
					ELSE
						pipe.mode := Usbdi.MinCpu;
						pipe.ioc := TRUE;
						controller.AddCompletionHandler(pipe);
					END;
					pipe.maxPacketSize := endpoint.wMaxPacketSize;
					pipe.maxRetries := 3;
					pipe.irqInterval := endpoint.bInterval;
					pipe.speed := speed;
					pipe.timeout := DefaultTimeout;
					pipe.completion.device := SELF;
					RETURN pipe;
				END;
				INC(endp);
			END;
			RETURN pipe;
		END GetPipeByInterface;

		(** Allocate a pipe for the specified endpoint *)
		PROCEDURE GetPipe*(endpoint : LONGINT) : Usbdi.Pipe;
		VAR pipe : UsbHcdi.Pipe; intfc, altIntfc : LONGINT; interface : InterfaceDescriptor;
		BEGIN
			IF SYSTEM.VAL(SET, endpoint) * {0..3} = {} THEN (* Special case: Default control pipe is always allocated *)
				ASSERT(defaultpipe#NIL);
				RETURN defaultpipe;
			ELSE
				LOOP (* Search all interfaces of the active configuration *)
					IF (pipe # NIL) OR (intfc >= actConfiguration.bNumInterfaces) THEN EXIT; END;
					interface := actConfiguration.interfaces[intfc] (InterfaceDescriptor);
					pipe := GetPipeByInterface(interface, endpoint);
					IF pipe # NIL THEN EXIT; END;
					LOOP (* Search all alternate interfaces *)
						IF altIntfc >= interface.numAlternateInterfaces THEN EXIT; END;
						pipe := GetPipeByInterface(interface.alternateInterfaces[altIntfc] (InterfaceDescriptor), endpoint);
						IF pipe # NIL THEN EXIT; END;
						INC(altIntfc);
					END; (* LOOP altIntfc *)
					INC(intfc);
				END; (* LOOP intfc *)
				controller.GetPipe(address, endpoint, pipe);
				RETURN pipe; (* can be NIL *)
			END;
			RETURN NIL;
		END GetPipe;

		(** De-allocate the specified pipe *)
		PROCEDURE FreePipe*(pipe : Usbdi.Pipe);
		BEGIN
			controller.FreePipe(pipe (UsbHcdi.Pipe));
		END FreePipe;

		(* Register this USB device at the USB hub <hub> *)
		PROCEDURE Register*(hub: UsbDevice; portNbr: LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(hub.hubFlag);
			parent := hub; port := portNbr;
			hub.deviceAtPort[portNbr] := SELF;
			Machine.AtomicInc(nbrOfTopologyEvents);
		END Register;

		(*  this device from the hub it is connected to and remove its driver if installed *)
		PROCEDURE Remove*;
		VAR n : LONGINT;device: UsbDevice;
		BEGIN {EXCLUSIVE}
			IF hubFlag THEN
				FOR n := 0 TO nbrOfPorts - 1 DO
					IF deviceAtPort[n] # NIL THEN
						device := deviceAtPort[n];
						deviceAtPort[n] := NIL; (* avoid recursion *)
						device.SetState(StateDisconnected);
						device.Remove;
						IF parent = SELF THEN (* Root hub: only disable ports on root hubs *) controller.DisablePort(n); END;
					END;
				END;
				IF actConfiguration.interfaces[0](InterfaceDescriptor).driver # NIL THEN
					drivers.RemoveInstance(actConfiguration.interfaces[0](InterfaceDescriptor).driver.name, SELF);
				END;
			ELSE
				FOR n := 0 TO actConfiguration.bNumInterfaces - 1 DO
					IF actConfiguration.interfaces[n](InterfaceDescriptor).driver # NIL THEN (* Remove device driver instance *)
						drivers.RemoveInstance(actConfiguration.interfaces[n](InterfaceDescriptor).driver.name, SELF);
						actConfiguration.interfaces[n](InterfaceDescriptor).driver := NIL;
					END;
				END;
			END;
			(* If it's not a root hub, then unregister all pipes of this device *)
			IF ~(hubFlag & (parent = SELF)) THEN
				controller.FreeAll(address);
				controller.FreeAddress(address);
			END;
			Machine.AtomicInc(nbrOfTopologyEvents);
		END Remove;

		(** Implementation of the USB standard device requests, see USB Specification Rev 1.1, p. 185 *)

		(** The ClearFeature standard request is used to clear or disable a specific feature. *)
		PROCEDURE ClearFeature*(recipient : SET;  feature, recipientNumber : LONGINT) : BOOLEAN;
		BEGIN
			ASSERT((recipient = Usbdi.Device) OR (recipient =Usbdi.Interface) OR (recipient = Usbdi.Endpoint));
			RETURN Request(recipient, SrClearFeature, feature, recipientNumber, 0, Usbdi.NoData) = Usbdi.Ok;
		END ClearFeature;

		(** This request is used to set or enable a specific feature *)
		PROCEDURE SetFeature*(recipient : SET; feature, recipientNumber : LONGINT) : BOOLEAN;
		BEGIN
			ASSERT((recipient = Usbdi.Device) OR (recipient = Usbdi.Interface) OR (recipient = Usbdi.Endpoint));
			RETURN Request(recipient, SrSetFeature, feature, recipientNumber, 0, Usbdi.NoData) = Usbdi.Ok;
		END SetFeature;

		(** Sets the address of the USB device dev to adr (should only be used by the USB driver) *)
		PROCEDURE SetAddress*(adr : LONGINT) : BOOLEAN;
		BEGIN
			IF Request(Usbdi.ToDevice, SrSetAddress, adr, 0, 0, Usbdi.NoData) = Usbdi.Ok THEN
				address := adr; RETURN TRUE;
			END;
			RETURN FALSE;
		END SetAddress;

		(** This requests returns the current device configuration value. If the returned value is zero, the device is not configured. *)
		PROCEDURE GetConfiguration*(VAR conf : LONGINT) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			NEW(buffer, 1);
			IF Request(Usbdi.ToHost, SrGetConfiguration, 0, 0, 1, buffer^) = Usbdi.Ok THEN
				conf := ORD(buffer[0]); RETURN TRUE;
			ELSE
				conf := -1; RETURN FALSE;
			END;
		END GetConfiguration;

		(** This requests sets the device configuration *)
		PROCEDURE SetConfiguration*(conf : LONGINT) : BOOLEAN;
		BEGIN
			ASSERT(configurations[conf].bConfigurationValue <= 255);
			IF Request(Usbdi.ToDevice + Usbdi.Standard, SrSetConfiguration, configurations[conf].bConfigurationValue, 0, 0, Usbdi.NoData) = Usbdi.Ok THEN
				actConfiguration := configurations[conf];
				RETURN TRUE;
				(* need to update info for pipes *)
			END;
			RETURN FALSE;
		END SetConfiguration;

		(** This request returns the specified descriptor if the descriptor exists *)
		PROCEDURE GetDescriptor*(descriptor, index, wIndex, len : LONGINT; VAR buffer : Usbdi.Buffer) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			ASSERT(len >= 2);
			status := Request(Usbdi.ToHost + Usbdi.Standard + Usbdi.Device, SrGetDescriptor, index + descriptor*100H, wIndex, len, buffer);
			RETURN (status = Usbdi.Ok) & (ORD(buffer[1]) = descriptor);
		END GetDescriptor;

		(** This request may be used to update existing descriptors or new descriptors may be added *)
		PROCEDURE SetDescriptor*(type : SET;  index, wIndex, len : LONGINT; VAR buffer : Usbdi.Buffer) : BOOLEAN;
		BEGIN
			RETURN Request(Usbdi.ToDevice, SrSetDescriptor, index + 100H*SYSTEM.VAL(LONGINT, type), wIndex, len, buffer) = Usbdi.Ok;
		END SetDescriptor;

		(** This request returns the selected alternate settings for the specified interface *)
		PROCEDURE GetInterface*(interfaceNumber : LONGINT; VAR setting : LONGINT): BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			NEW(buffer, 1);
			IF Request(Usbdi.ToHost + Usbdi.Interface, SrGetInterface, 0, interfaceNumber, 1, buffer^) = Usbdi.Ok THEN
				setting := ORD(buffer[0]);
				RETURN TRUE;
			END;
			RETURN FALSE;
		END GetInterface;

		(** This requests allows the host to select an alternate setting for the specified interface *)
		PROCEDURE SetInterface*(interfaceNumber, setting : LONGINT): BOOLEAN;
		BEGIN
			RETURN Request(Usbdi.ToDevice + Usbdi.Standard + Usbdi.Interface, SrSetInterface, setting, interfaceNumber, 0, Usbdi.NoData) = Usbdi.Ok;
		END SetInterface;

		(** This request returns status for the specified recipient *)
		PROCEDURE GetStatus*(recipient: SET;  recipientNumber: LONGINT; VAR status : SET): BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			ASSERT((recipient = Usbdi.Device) OR (recipient = Usbdi.Interface) OR (recipient = Usbdi.Endpoint));
			NEW(buffer, 2);
			IF Request(Usbdi.ToHost + Usbdi.Standard + recipient, SrGetStatus , 0, recipientNumber, 2, buffer^) = Usbdi.Ok THEN
				status := SYSTEM.VAL(SET, ORD(buffer[0]) + 100H*SYSTEM.VAL(LONGINT, ORD(buffer[1])));
				RETURN TRUE;
			END;
			RETURN FALSE;
		END GetStatus;

		(** This request is used to set and then report an endpoint's synchronization frame *)
		PROCEDURE SynchFrame*(endpoint: LONGINT; VAR frameNumber : LONGINT): BOOLEAN;  (* UNTESTED *)
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			NEW(buffer, 2);
			IF Request(Usbdi.ToDevice + Usbdi.Standard + Usbdi.Endpoint, SrSynchFrame, 0, endpoint, 2, buffer^) = Usbdi.Ok THEN
				frameNumber := ORD(buffer[0]) + 100H*SYSTEM.VAL(LONGINT, ORD(buffer[1]));
				RETURN TRUE;
			END;
			RETURN FALSE;
		END SynchFrame;

		(** USB device request *)
		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex, wLength : LONGINT; VAR buffer : Usbdi.Buffer) : Usbdi.Status;
		BEGIN
			RETURN defaultpipe.Request(bmRequestType, bRequest, wValue, wIndex, wLength, buffer);
		END Request;

		(*
		 * Get a device's configuration descriptor.
		 * @param nbr Configuration number
		 * @param type Configuration descriptor or Other-Speed configuration descriptor
		 * @return Buffer containing the configuration, NIL if operation fails
		 *)
		PROCEDURE InternalGetConfigurations(type : LONGINT; configurations : Usbdi.Configurations) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr; c, length : LONGINT;
		BEGIN
			ASSERT(((type = DescriptorConfiguration) & (descriptor # NIL)) OR ((type = DescriptorOtherSpeedConfig) & (qualifier # NIL)));
			FOR c := 0 TO LEN(configurations)-1 DO
				(* Get the total size of this configuration *)
				NEW(buffer, 8);
				IF GetDescriptor(type, c, 0, 8, buffer^) THEN
					length := ORD(buffer[2])+ 256*SYSTEM.VAL(LONGINT, ORD(buffer[3]));
					NEW(buffer, length);
					IF GetDescriptor(type, c, 0, length, buffer^) THEN (* Load and parse configuration *)
						configurations[c] := ParseConfigurationDescriptor(buffer^);
						IF configurations[c] = NIL THEN RETURN FALSE; END;
						IF (descriptor # NIL) &
						   (descriptor.bDeviceClass = 0EFH) & (descriptor.bDeviceSubClass = 02H) & (descriptor.bDeviceProtocol = 01H) THEN
						   (* Multi-interface function has Interface Association descriptors *)
						    configurations[c].iads := ParseInterfaceAssociation(buffer^);
						END;
						(* Parse non-standard descriptors *)
						configurations[c].unknown := ParseUnknownDescriptors(configurations[c], buffer^);
					ELSE
						IF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: Get configuration failed."); KernelLog.Ln; END;
						RETURN FALSE;
					END;
				ELSE
					IF Debug.Level >= Debug.Errors  THEN KernelLog.String("Usb: Read first 8 bytes of configuration failed"); KernelLog.Ln; END;
					RETURN FALSE;
				END;
			END;
			RETURN TRUE;
		END InternalGetConfigurations;

		PROCEDURE GetConfigurations*() : BOOLEAN;
		BEGIN
			ASSERT(descriptor # NIL);
			NEW(configurations, descriptor.bNumConfigurations);
			IF InternalGetConfigurations(DescriptorConfiguration, configurations) THEN
				RETURN TRUE;
			ELSE
				configurations := NIL;
				RETURN FALSE;
			END;
		END GetConfigurations;

		PROCEDURE GetOtherSpeedConfigurations*() : BOOLEAN;
		BEGIN
			ASSERT(qualifier # NIL);
			NEW(otherconfigurations, qualifier.bNumConfigurations);
			IF InternalGetConfigurations(DescriptorOtherSpeedConfig, otherconfigurations) THEN
				RETURN TRUE;
			ELSE
				otherconfigurations := NIL;
				RETURN FALSE;
			END;
		END GetOtherSpeedConfigurations;

		(**
		 * Loads and parses the USB device qualifier. This descriptor is only available on USB 2.0 devices
		 * which can operate as Low-/Fullspeed and Highspeed USB device.
		 * It essentially contains the same information as the device descriptor, but the values are for
		 * the case that the device would operate at its other operating speed.
		 * @return TRUE, if operation succeeded, FALSE otherwise
		 *)
		PROCEDURE GetDeviceQualifier*() : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			ASSERT(descriptor # NIL);
			NEW(buffer, 10);
			IF GetDescriptor(DescriptorDeviceQualifier, 0, 0, 10, buffer^) THEN
				qualifier := ParseDeviceQualifier(buffer^);
				(* Duplicate fields from device descriptor *)
				qualifier.idVendor := descriptor.idVendor;
				qualifier.idProduct := descriptor.idProduct;
				qualifier.bcdDevice := descriptor.bcdDevice;
				qualifier.iManufacturer := descriptor(DeviceDescriptor).iManufacturer;
				qualifier.iProduct := descriptor(DeviceDescriptor).iProduct;
				qualifier.iSerialNumber := descriptor(DeviceDescriptor).iSerialNumber;
				qualifier.sManufacturer := descriptor(DeviceDescriptor).sManufacturer;
				qualifier.sProduct := descriptor(DeviceDescriptor).sProduct;
				qualifier.sSerialNumber := descriptor(DeviceDescriptor).sSerialNumber;
				qualifier.uManufacturer := descriptor(DeviceDescriptor).uManufacturer;
				qualifier.uProduct := descriptor(DeviceDescriptor).uProduct;
				qualifier.uSerialNumber := descriptor(DeviceDescriptor).uSerialNumber;
				RETURN TRUE;
			ELSIF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't retrieve device qualifier."); KernelLog.Ln;
			END;
			RETURN FALSE;
		END GetDeviceQualifier;

		(**
		 * Loads and parses the USB device descriptor. If parsing succeeds, the SELF.descriptor record
		 * will be set, otherwise it's set to NIL.
		 * @return TRUE, if opertation succeeded, FALSE otherwise
		 *)
		PROCEDURE GetDeviceDescriptor*() : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr;
		BEGIN
			NEW(buffer, 18);
			IF GetDescriptor(DescriptorDevice, 0, 0, 18, buffer^) THEN
				descriptor := ParseDeviceDescriptor(buffer^);
				RETURN TRUE;
			ELSIF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: Couldn't get the device descriptor."); KernelLog.Ln;
			END;
			RETURN FALSE;
		END GetDeviceDescriptor;

		PROCEDURE ShowName*;
		BEGIN
			IF (descriptor # NIL) & (descriptor(DeviceDescriptor).sManufacturer # NIL) OR (descriptor(DeviceDescriptor).sProduct # NIL) THEN
				IF descriptor(DeviceDescriptor).sManufacturer # NIL THEN KernelLog.String(descriptor(DeviceDescriptor).sManufacturer^); KernelLog.Char(" "); END;
				IF descriptor(DeviceDescriptor).sProduct # NIL THEN KernelLog.String(descriptor(DeviceDescriptor).sProduct^); END;
			ELSE
				KernelLog.String("unknown device");
			END;
		END ShowName;

	END UsbDevice;

TYPE

	RootHubArray* = POINTER TO ARRAY OF UsbDevice;

TYPE

	(* Root hub emulation. Emulate USB standard device requests for root hubs. Since all standard requests implemented in the
	 * UsbDevice object use Request for the actual transfer, we simply overwrite it and emulated the results of the control transfers. *)
	EmulatedHubDevice* = OBJECT(UsbDevice);

		PROCEDURE GetPipe*(endpoint : LONGINT) : Usbdi.Pipe;
		BEGIN
			HALT(99); RETURN NIL; (* Root hubs don't provide pipes *)
		END GetPipe;

		PROCEDURE FreePipe*(pipe : Usbdi.Pipe);
		BEGIN
			HALT(99); (* Root hubs don't provide pipes *)
		END FreePipe;

		PROCEDURE Register*(hub: UsbDevice; portNbr: LONGINT);
		BEGIN
			HALT(99);
		END Register;

		(** Emulated USB device request *)
		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex, wLength : LONGINT; VAR buffer : Usbdi.Buffer) : Usbdi.Status;
		VAR res : Usbdi.Status;
		BEGIN
			res := Usbdi.Stalled;
			CASE bRequest OF
				SrGetStatus:
					BEGIN
						ASSERT(wLength = 2);
						IF (bmRequestType * Usbdi.ToHost # {}) & (bmRequestType - Usbdi.ToHost = {})  THEN
							(* Get Device status: Indicate Selfpowered, Remote Wakeup disabled *)
							buffer[0] := CHR(SYSTEM.VAL(LONGINT, {0})); buffer[1] := 0X; res := Usbdi.Ok;
						ELSIF (bmRequestType * Usbdi.ToHost # {}) & (bmRequestType - Usbdi.ToHost = Usbdi.Interface) THEN
							(* Get Interface status:  Reserved *)
							 buffer[0] := 0X; buffer[1] := 0X; res := Usbdi.Ok;
						ELSIF (bmRequestType * Usbdi.ToHost # {}) & (bmRequestType - Usbdi.ToHost = Usbdi.Endpoint) THEN
							(* Get endpoint status:  Indicate endpoint not halted. *)
							 buffer[0] := 0X; buffer[1] := 0X; res := Usbdi.Ok;
						END;
					END;
				(* All following requests will fail *)
				|SrClearFeature:
				|SrSetFeature:
				|SrGetDescriptor:
				|SrSetDescriptor:
				|SrGetConfiguration:
				|SrSetConfiguration:
				(* Requests unsupported by hubs / root hubs *)
				|SrGetInterface: HALT(99);
				|SrSetInterface: HALT(99);
				|SrSynchFrame: HALT(99);
				(* Requests unsupported by root hubs *)
				|SrSetAddress: HALT(99);
			ELSE
				HALT(99);
			END;
			RETURN res;
		END Request;

		(* Emulate device, configuration, interface and endpoint descriptors of root hub *)
		PROCEDURE EmulateDescriptors;
		VAR
			descriptor : DeviceDescriptor; configuration : ConfigurationDescriptor;
			interface : InterfaceDescriptor; endpoint : EndpointDescriptor;
			name : Lib.AsciiString;
			i, j : LONGINT;
		BEGIN
			(* Emulate device descriptor *)
			NEW(descriptor); SELF.descriptor := descriptor;
			descriptor.bNumConfigurations := 1;
			NEW(name, LEN(controller.name) + LEN(controller.desc) + 2);
		 	WHILE(i < LEN(controller.name)) & (controller.name[i] # 0X) DO name[i] := controller.name[i]; INC(i); END;
		 	name[i] := " "; name[i+1] := "(";
		 	WHILE(j < LEN(controller.desc)) & (controller.desc[j] # 0X) DO name[j + i + 2] := controller.desc[j]; INC(j); END;
		 	name[j + i + 2] := ")"; name[j + i + 3] := 0X;
			descriptor.sProduct := name;
			(* Emulate device configuration *)
			NEW(configurations, 1); NEW(configuration); configurations[0] := configuration;
			configuration.bNumInterfaces := 1;
			configuration.bmAttributes := {6,7}; (* Indicate self-powered device *)
			configuration.bMaxPower := 0; (* Root hub don't draw current from the BUS *)
			configuration.selfPowered := TRUE;
			configuration.remoteWakeup := FALSE;
			NEW(configurations[0].interfaces, 1); NEW(interface);
			configurations[0].interfaces[0] := interface;
			configurations[0].interfaces[0].bInterfaceClass := 9; (* Hub device class *)
			configurations[0].interfaces[0].bInterfaceSubClass := 0;
			configurations[0].interfaces[0].bNumEndpoints := 1;
			configurations[0].interfaces[0].bInterfaceProtocol := 0;
			NEW(configurations[0].interfaces[0].endpoints, 1);
			NEW(endpoint); endpoint.type := Usbdi.InterruptIn;
			configurations[0].interfaces[0].endpoints[0] := endpoint;
			actConfiguration := configuration;
		END EmulateDescriptors;

		PROCEDURE &New*(controller : UsbHcdi.Hcd);
		BEGIN
			ASSERT(controller # NIL);
			SELF.controller := controller;
			parent := SELF;
			hubFlag := TRUE;
			nbrOfPorts := controller.portCount;
			NEW(deviceAtPort, nbrOfPorts);
			NEW(portPermanentDisabled, nbrOfPorts);
			NEW(portErrors, nbrOfPorts);
			EmulateDescriptors;
		END New;

	END EmulatedHubDevice;

TYPE

	RegisteredDriver* = POINTER TO RECORD
		probe : Usbdi.ProbeProc;
		name- : Usbdi.Name;
		desc- : Usbdi.Description;
		usedSuffix- : ARRAY 100 OF BOOLEAN; (* Which numbers are used for the unique names of instances *)
		next- : RegisteredDriver;
	END;

TYPE
	(*
	 * This object manages USB device drivers. It will be notified by the USB hub driver when devices
	 * are attached/detached from the bus. If a device is attached, the driver manager calls the probe procedures
	 * of all USB device drivers which are registered at the driver manager. When a device is detached from the
	 * bus, the associated driver (if any) will be removed from the UsbDevice object.
	 *)
	DriverManager* = OBJECT(Usbdi.DriverManager)
	VAR
		(* Driver manager internal USB device driver registy (exported for WMUsbInfo only). *)
		drivers- : ARRAY DmMaxPriorities OF RegisteredDriver;

		(* Incremented each time a driver is added or removed *)
		nbrOfDriverEvents- : LONGINT;

		(* local copy of rootHubs, since it could be modified while operating on it *)
		rootHubs : RootHubArray;

		alive, dead, probeDrivers : BOOLEAN;

		(* For each interface of the USB device <dev> try to install a registered driver; called when a new USB device is found *)
		PROCEDURE ProbeDevice*(dev : UsbDevice);
		VAR n : LONGINT;
		BEGIN
			FOR n := 0 TO dev.actConfiguration.bNumInterfaces - 1 DO
				IF dev.actConfiguration.interfaces[n](InterfaceDescriptor).driver = NIL THEN
					(* probe all device drivers and install a driver instance if a driver for the device is registered *)
					Install(dev, n);
				END;
			END;
		END ProbeDevice;

		(* Load driver using driver database services *)
		PROCEDURE ConsultDriverDatabase(dev : UsbDevice) : BOOLEAN;
		VAR  loaded : BOOLEAN; d : DeviceDescriptor; i : InterfaceDescriptor; intf : LONGINT;
		BEGIN
			IF (dev # NIL) & (dev.descriptor # NIL) THEN
				d := dev.descriptor (DeviceDescriptor);
				(* First look for a device-specific driver *)
				loaded := UsbDriverLoader.LoadDeviceDriver(d.idVendor, d.idProduct, d.bcdDevice);
				(* Look for class-specific driver *)
				IF ~((d.bDeviceClass = 0EFH) & (d.bDeviceSubClass = 02H) & (d.bDeviceProtocol = 01H)) & (* IAD -> Search interfaces *)
					((d.bDeviceClass # 0) OR (d.bDeviceSubClass # 0) OR (d.bDeviceProtocol # 0)) THEN (* Class description at device level *)
					IF UsbDriverLoader.LoadClassDriver(d.bDeviceClass, d.bDeviceSubClass, d.bDeviceProtocol, d.bcdDevice) THEN
						loaded := TRUE;
					END;
				ELSE (* Class description at interface level *)
					IF (dev.actConfiguration # NIL) & (dev.actConfiguration.interfaces # NIL) THEN
						intf := 0;
						LOOP
							i := dev.actConfiguration.interfaces[intf] (InterfaceDescriptor);
							(* TODO: Actually, some classes specifiy class-specfic descriptors that may contain the class revision the device supports. Use this instead of bcdDevice *)
							IF (i # NIL) & UsbDriverLoader.LoadClassDriver(i.bInterfaceClass, i.bInterfaceSubClass, i.bInterfaceProtocol, d.bcdDevice) THEN
								loaded := TRUE;
							END;
							INC(intf);
							IF intf >= LEN(dev.actConfiguration.interfaces) THEN EXIT END;
						END;
					END;
				END;
			END;
			RETURN loaded;
		END ConsultDriverDatabase;

		PROCEDURE LookupDriver(dev : UsbDevice; interface : InterfaceDescriptor; VAR temp : RegisteredDriver) : Usbdi.Driver;
		VAR drv : Usbdi.Driver; i : LONGINT;
		BEGIN
			LOOP (* Search all priority lists *)
				temp := drivers[i].next;
				LOOP (* Search all drivers in priority list i *)
					IF temp = NIL THEN (* No more drivers available *) EXIT; END;
					drv := temp.probe(dev, interface);
					IF drv # NIL THEN (* Driver found *) EXIT; END;
					temp := temp.next;
				END;
				IF drv # NIL THEN (* Driver found *) EXIT; END;
				INC(i); IF (i >= DmMaxPriorities) THEN (* No driver available *) EXIT; END;
			END;
			RETURN drv;
		END LookupDriver;

		(* Returns FALSE if connect failed or trapped *)
		PROCEDURE SafelyConnect(drv : Usbdi.Driver) : BOOLEAN;
		VAR connected, trap : BOOLEAN;
		BEGIN
			connected := drv.Connect();
		FINALLY
			IF trap & (Debug.Level >= Debug.Warnings) THEN KernelLog.String("Usb: Catched TRAP when calling Driver.Connect."); KernelLog.Ln; END;
			RETURN (~trap & connected);
		END SafelyConnect;

		PROCEDURE SafelyDisconnect(drv : Usbdi.Driver);
		VAR trap : BOOLEAN;
		BEGIN
			drv.Disconnect;
		FINALLY
			IF trap & (Debug.Level >= Debug.Warnings) THEN KernelLog.String("Usb: Catched TRAP when calling Driver.Disconnect."); KernelLog.Ln; END;
		END SafelyDisconnect;

		(* Checks whether an appropriate driver for the USB device <dev> is registred in registredDrivers.
		 *  If yes, a unique Plugins.Name is generated and the driver is added to the usbDrivers registry *)
		PROCEDURE Install(dev : UsbDevice; interfaceIdx : LONGINT);
		VAR
			temp : RegisteredDriver;
			drv : Usbdi.Driver;
			interface : InterfaceDescriptor;
			i, res : LONGINT;
			name : Usbdi.Name;
			suffix : LONGINT; (* 0-99; suffix is used to generate unique names for AosPlugin.Name *)
		BEGIN
			interface := dev.actConfiguration.interfaces[interfaceIdx] (InterfaceDescriptor);
			(* Search an USB device driver for this device (See USB Common Class Specification, 3.10 Locating USB Drivers) *)
			(* we have to consult the database first always because of priorities. If a driver has already been loaded previously, this will return FALSE anyway *)
			IF ConsultDriverDatabase(dev) THEN
				RETURN;  (* Appropriate device driver has been loaded from driver database. Loading will force bus enumeration, so don't continue here. *)
			ELSE
				drv := LookupDriver(dev, interface, temp);
			END;

			BEGIN {EXCLUSIVE}
				(* Since it's possible that two threads (active body, hub driver via ProbeDevice) try to install a driver for the same device and interface,
				we need to check here *)
				IF (drv # NIL) & (interface.driver = NIL)  THEN

					(* Driver found;  generate a unique name for the instance of this driver to be created *)
					drv.device := dev; drv.interface := interface;

					(* Get first unused suffix *)
					i := 0; WHILE (temp.usedSuffix[i] = TRUE) & (i <= 99) DO INC(i); END;
					IF (i = 99) & (temp.usedSuffix[99] = TRUE) THEN
						KernelLog.String("Usb: No more than 99 instances of a driver supported"); KernelLog.Ln;
						RETURN;
					ELSE
						temp.usedSuffix[i] := TRUE; suffix := i;
					END;

					name := AddSuffix(temp.name, suffix);

					drv.SetName(name); drv.desc := temp.desc;

					(* Add this driver to the usbDrivers registry *)
					usbDrivers.Add(drv, res);
					IF res # Plugins.Ok THEN
						KernelLog.String("Usb: Couldn't register USB device driver (res: "); KernelLog.Int(res, 0); KernelLog.String(")"); KernelLog.Ln;
						temp.usedSuffix[suffix] := FALSE;
						RETURN;
					ELSE (* USB device driver successfully registered *)
						interface.driver := drv;
						IF ~SafelyConnect(drv) THEN
							KernelLog.String("Usb: Connect of driver "); KernelLog.String(drv.name); KernelLog.String("("); KernelLog.String(drv.desc); KernelLog.String(") failed."); KernelLog.Ln;
							ASSERT(drv.device(UsbDevice).parent.hubFlag);
							ASSERT(drv.device(UsbDevice).parent.portPermanentDisabled # NIL);
							(* Don't try to re-install a driver until ConnectStatusChange at this port *)
							drv.device(UsbDevice).parent.portPermanentDisabled[drv.device(UsbDevice).port] := TRUE;
							drv.device(UsbDevice).Remove;
							RETURN;
						END;
						IF Debug.Trace & Debug.traceDm THEN KernelLog.String("Usb: Registered USB device driver: "); KernelLog.String(name); KernelLog.Ln; END;
					END;
				END;
			END;
		END Install;

		(* For all USB devices which are attached to any USB root hub in the system the procedure ProbeDeviceChain() is called *)
		PROCEDURE ProbeDriversInternal;
		VAR i : LONGINT;
		BEGIN (* Works with local copy of rootHubs array *)
			GetRootHubs(rootHubs);
			IF rootHubs # NIL THEN
				FOR i := 0 TO LEN(rootHubs)-1 DO
					ProbeDeviceChain(rootHubs[i]);
					rootHubs[i] := NIL; (* we don't need the reference anymore *)
				END;
			END;
		END ProbeDriversInternal;

		(* Called by ProbeDrivers; calls Install() for all devices which don't already have a driver instance installed *)
		PROCEDURE ProbeDeviceChain(dev : UsbDevice);
		VAR n : LONGINT;
		BEGIN
			FOR n := 0 TO dev.actConfiguration.bNumInterfaces - 1 DO
				IF dev.actConfiguration.interfaces[n](InterfaceDescriptor).driver = NIL THEN
					(* Probe all device drivers and install a driver instance if a driver for the device is registered *)
					Install(dev, n);
				END;
			END;
			IF dev.hubFlag THEN
				FOR n := 0 TO dev.nbrOfPorts - 1 DO
					IF dev.deviceAtPort[n] # NIL THEN ProbeDeviceChain(dev.deviceAtPort[n]); END;
				END;
			END;
		END ProbeDeviceChain;

		(** Add a USB device driver to the internal registry. Driver names have to be unique and no longer than 30 characters (incl. Null-String) *)
		PROCEDURE Add*(probe : Usbdi.ProbeProc; CONST name: Usbdi.Name; CONST desc: Usbdi.Description; priority : LONGINT);
		VAR temp, new : RegisteredDriver; i : LONGINT;
		BEGIN
			(* The specified name mustn't be longer than 30 characters (including 0X) *)
			WHILE (name[i] # 0X) & (i < 32) DO INC(i); END;
			IF (i > 29) OR (name = "")  THEN
				KernelLog.String("Usb: Couldn't add driver (name NULL or longer than 30 characters or not NULL-terminated)"); KernelLog.Ln;
				RETURN;
			END;

			(* Specified priority must be in the interval [0,DmMaxPriorities-1] *)
			IF (priority > DmMaxPriorities-1) OR (priority < 0) THEN
				KernelLog.String("Usb: Couldn't add driver (Priority invalid)"); KernelLog.Ln;
				RETURN;
			END;

			BEGIN {EXCLUSIVE}
				(* Check whether there is no driver with the name <name> registered *)
				FOR i := 0 TO DmMaxPriorities-1 DO
					temp := drivers[i].next;
					WHILE temp # NIL DO
						IF temp.name = name THEN
							KernelLog.String("Usb: Couldn't add driver (driver name already registered)"); KernelLog.Ln;
							RETURN;
						END;
						temp := temp.next;
					END;
				END;

				(* Okay, arguments are valid, create RegisteredDriver object and add it to internal registry *)
				NEW(new);
				new.probe := probe;
				new.name := name;
				new.desc := desc;
				new.next := drivers[priority].next;

				FOR i := 0 TO 99 DO new.usedSuffix[i] := FALSE; END;
				drivers[priority].next := new;
			END;
			IF Debug.Verbose THEN
				KernelLog.String("Usb: Driver "); KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String(")");
				KernelLog.String(" has been added."); KernelLog.Ln;
			END;

			(* Maybe a USB device is already attached, just waiting for this driver: check! *)
			ProbeDrivers;

			BEGIN {EXCLUSIVE} INC(nbrOfDriverEvents); END;
		END Add;

		(* Removes a device driver instance from usbDriver registry; only used by the USB driver itself*)
		PROCEDURE RemoveInstance(CONST name : Usbdi.Name; dev : UsbDevice);
		VAR
			plugin : Plugins.Plugin;
			driver : Usbdi.Driver;
			regname : Plugins.Name;
			temp : RegisteredDriver;
			i, suffix : LONGINT;
		BEGIN
			plugin := usbDrivers.Get(name);
			IF plugin # NIL THEN (* Uninstall this instance *)

				driver := plugin (Usbdi.Driver);

				usbDrivers.Remove(plugin);

				SafelyDisconnect(driver);

				(* Remove allocated pipes *)
				driver.device(UsbDevice).controller.FreeAll(driver.device(UsbDevice).address);

				(* Get the name of the registered device driver which generates this instances *)
				WHILE name[i] # 0X DO regname[i] := name[i]; INC(i); END;
				regname[i-1] := 0X; regname[i-2] := 0X;

				suffix := GetSuffix(name);

				(* Need to update usedSuffix at the registered driver *)
				i := 0;
				LOOP
					temp := drivers[i].next;
					WHILE (temp # NIL) & (temp.name # regname) DO temp := temp.next; END;
					IF temp # NIL THEN (* Registered device driver found *)
						temp.usedSuffix[suffix] := FALSE;
						EXIT;
					END;
					INC(i); IF (i >= DmMaxPriorities) THEN (* No driver found *) EXIT; END;
				END;

				IF (i = DmMaxPriorities) & (temp = NIL) THEN (* Registered driver for this instance was not found *)
					 IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't find registered driver of the removed driver instance"); KernelLog.Ln; END;
				END;
			ELSE (* No such instance found *)
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Warning: Couldn't remove driver instance (no instance found)"); KernelLog.Ln; END;
			END;
		END RemoveInstance;

		(**
		 * Calls Disconnect of all instances of the driver. All instances are removed from the usbDrivers registry
		 * and the device driver is removed from the internal registry. *)
		PROCEDURE Remove*(CONST name : Plugins.Name);
		VAR
			prev, temp : RegisteredDriver;
			regname : Plugins.Name;
			plugin : Plugins.Plugin;
			dev : UsbDevice;
			i, j : LONGINT;
		BEGIN {EXCLUSIVE}
			IF Debug.Trace & Debug.traceDm THEN KernelLog.String("Usb: Removing driver: "); KernelLog.String(name); KernelLog.Ln; END;
			(* Remove device driver from internal registry *)
			LOOP
				prev := drivers[i];
				temp := drivers[i].next;
				WHILE (temp # NIL) & (temp.name # name) DO temp := temp.next; prev := prev.next; END;
				IF temp # NIL THEN (* Driver found *) EXIT; END;
				INC(i); IF (i >= DmMaxPriorities) THEN (* No driver available *) EXIT; END;
			END;
			(* Remove driver from internal registry and remove all its instances *)
			IF temp # NIL THEN
				(* Remove driver from internal registry *)
				prev.next := temp.next;
				(* Remove all instances of the driver *)
				FOR i := 0 TO 99 DO
					IF temp.usedSuffix[i] = TRUE THEN (* Driver instance found *)
						(* Get plugin name *)
						regname := AddSuffix(temp.name, i);
						plugin := usbDrivers.Get(regname);

						IF plugin = NIL THEN
							IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Error while trying to remove driver from usbDrivers registry"); KernelLog.Ln; END;
						ELSE
							SafelyDisconnect(plugin(Usbdi.Driver));
							dev := plugin(Usbdi.Driver).device (UsbDevice);
							IF dev # NIL THEN (* Remove link to driver instance from USB device *)
								IF ~(dev.hubFlag & (dev.parent = dev)) THEN
									dev.controller.FreeAll(dev.address);
								END;
								FOR j := 0 TO dev.actConfiguration.bNumInterfaces-1 DO
									IF dev.actConfiguration.interfaces[j](InterfaceDescriptor).driver = plugin(Usbdi.Driver) THEN
										dev.actConfiguration.interfaces[j](InterfaceDescriptor).driver := NIL;
									END;
								END;
							END;
							usbDrivers.Remove(plugin);
							temp.usedSuffix[i]:=FALSE;
						END;
					END;
				END;
				INC(nbrOfDriverEvents);
			ELSIF Debug.Level >= Debug.Warnings THEN
				KernelLog.String("Usb: Warning: Couldn't remove driver "); KernelLog.String(name); KernelLog.Ln;
			END;
		END Remove;

		(* Appends the suffix to name; the suffix is a number between 0-99 which is added as 2 ASCII characters (each 1 bytes)
		 * note: name mustn't be longer than 30 characters (incl. Null-Termination)  *)
		PROCEDURE AddSuffix*(CONST name: Plugins.Name; suffix : LONGINT) :  Plugins.Name;
		VAR i : LONGINT; newName : Plugins.Name;
		BEGIN
			WHILE name[i]#0X DO newName[i]:=name[i]; INC(i); END;
			(* Append suffix to name *)
			IF suffix < 10 THEN
				newName[i]:="0";
				newName[i+1]:=CHR(suffix+48);
				newName[i+2]:=0X;
			ELSE
				newName[i]:=CHR((suffix DIV 10)+48);
				newName[i+1]:=CHR((suffix MOD 10)+48);
				newName[i+2]:=0X;
			END;
			RETURN newName;
		END AddSuffix;

		(* Returns the suffix of the Plugins.Name name *)
		PROCEDURE GetSuffix(CONST name : Plugins.Name) : LONGINT;
		VAR i, suffix : LONGINT;
		BEGIN
			WHILE (name[i] # 0X) & (i < 32) DO INC(i); END;
			suffix:= (ORD(name[i-2]) - 48) * 10 + ORD(name[i-1])-48;
			ASSERT((suffix >= 0) & (suffix <= 99));
			RETURN suffix;
		END GetSuffix;

		(* Displays a list of registered drivers *)
		PROCEDURE Show*;
		VAR temp : RegisteredDriver; i : LONGINT;
		BEGIN
			KernelLog.Ln; KernelLog.String("Usb: Registered USB device drivers: "); KernelLog.Ln;
			FOR i := 0 TO DmMaxPriorities - 1 DO
				temp := drivers[i].next;
				WHILE temp # NIL DO
					KernelLog.String("   ");
					KernelLog.String(temp.name); KernelLog.String(" ("); KernelLog.String(temp.desc); KernelLog.String(")");
					KernelLog.String(" Priority: "); KernelLog.Int(i, 0); KernelLog.Ln;
					temp := temp.next;
				END;
			END;
		END Show;

		PROCEDURE ProbeDrivers;
		BEGIN {EXCLUSIVE}
			probeDrivers := TRUE;
		END ProbeDrivers;

		PROCEDURE Terminate;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			(* Release object lock to prevent deadlock *)
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Terminate;

		PROCEDURE &Init*;
		VAR  i : LONGINT; temp : RegisteredDriver;
		BEGIN
			alive := TRUE; dead := FALSE;
			FOR i := 0 TO 11 DO NEW(temp); drivers[i] := temp; END; (* Allocate list heads *)
		END Init;

	BEGIN {ACTIVE}
		(* This thread decouples the process of checking all connected USB devices for matching device drivers from the caller. 	*)
		(* It will be active in the following two situations:																	*)
		(*	- A device driver is successfully registered at the driver manager (Add procedure)									*)
		(*	- The driver lookup service has been enabled																		*)
		(* 																													*)
		(* Note: 																											*)
		(* When a device is connected to a bus, the thread of the corresponding hub driver will call ProbeDevice, so different	*)
		(* hubs/busses can install device drivers concurrently. To prevent two threads (this one and the hub driver's one) to con-*)
		(* currently install the same device driver to the same function, another check is made in proedure install.				*)
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT(probeDrivers OR ~alive);
				probeDrivers := FALSE;
			END;
			IF alive THEN (* Check availability of device drivers for all connected devices *)
				IF Debug.Trace & Debug.traceDm THEN
					KernelLog.Enter; KernelLog.String("Usb: Check connected devices for available device drivers"); KernelLog.Exit;
				END;
				ProbeDriversInternal;
			END;
		END;
		IF Debug.Trace & Debug.traceDm THEN KernelLog.Enter; KernelLog.String("Usb: Driver Manager object terminated."); KernelLog.Exit; END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END DriverManager;

TYPE
	Registry= OBJECT(Plugins.Registry) END Registry;

VAR
	usbDrivers- : (*Plugins.*)Registry;	(* Instanciated USB device drivers (linked to a attached USB device) 	*)
	drivers- : DriverManager;   			(* Usb internal registry for installable USB device drivers 			*)
	rootHubs : RootHubArray;
	nbrOfTopologyEvents- : LONGINT;	(* Incremented each time a device is connected/disconnected *)

PROCEDURE ParseDeviceDescriptor(buffer : Usbdi.Buffer) : DeviceDescriptor;
VAR descriptor : DeviceDescriptor;
BEGIN
	IF LEN(buffer) >= 18 THEN
		NEW(descriptor);
		descriptor.bcdUSB := ORD(buffer[2]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[3]));
		descriptor.bDeviceClass := ORD(buffer[4]);
		descriptor.bDeviceSubClass := ORD(buffer[5]);
		descriptor.bDeviceProtocol := ORD(buffer[6]);
		descriptor.bMaxPacketSize0 := ORD(buffer[7]);
		descriptor.idVendor := ORD(buffer[8]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[9]));
		descriptor.idProduct := ORD(buffer[10]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[11]));
		descriptor.bcdDevice := ORD(buffer[12]) +  256*SYSTEM.VAL(LONGINT, ORD(buffer[13]));
		descriptor.iManufacturer := ORD(buffer[14]);
		descriptor.iProduct := ORD(buffer[15]);
		descriptor.iSerialNumber := ORD(buffer[16]);
		descriptor.bNumConfigurations := ORD(buffer[17]);
	ELSIF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: Could not parse device descriptor."); KernelLog.Ln;
	END;
	RETURN descriptor;
END ParseDeviceDescriptor;

(**
 * Parses the USB device qualifier. This descriptor is only available on USB 2.0 devices which can operate as
 * Low-/Fullspeed and Highspeed USB device. It essentially contains the same information as the device descriptor,
 * but the values are for  the case that the device would operate at its other operating speed.
 *)
PROCEDURE ParseDeviceQualifier(buffer : Usbdi.Buffer) : DeviceDescriptor;
VAR qualifier : DeviceDescriptor;
BEGIN
	IF LEN(buffer) >= 10 THEN
		NEW(qualifier);
		qualifier.bcdUSB := ORD(buffer[2]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[3]));
		qualifier.bDeviceClass := ORD(buffer[4]);
		qualifier.bDeviceSubClass := ORD(buffer[5]);
		qualifier.bDeviceProtocol := ORD(buffer[6]);
		qualifier.bMaxPacketSize0 := ORD(buffer[7]);
		qualifier.bNumConfigurations := ORD(buffer[8]);
	ELSIF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: Could not parse device qualifier."); KernelLog.Ln;
	END;
	RETURN qualifier;
END ParseDeviceQualifier;

(** Parse all Interface Association Descriptors in the given configuration. All other descriptor types are skipped. *)
PROCEDURE ParseInterfaceAssociation(buffer : Usbdi.Buffer) : Usbdi.Iads;
VAR iads : Usbdi.Iads; iad : InterfaceAssociationDescriptor; idx, num, i : LONGINT;
BEGIN
	IF Debug.Trace & Debug.traceParsing THEN KernelLog.String("Usb: Parsing interface association descriptors:"); KernelLog.Ln; END;
	(* Determine number of available IADs *)
	WHILE(idx+1 < LEN(buffer)) DO
		IF (ORD(buffer[idx+1]) = DescriptorIad) THEN INC(num); END;
		idx := idx + ORD(buffer[idx+0]);
	END;

	idx := 0;
	IF num > 0 THEN (* Parse the IADs *)
		NEW(iads, num);
		LOOP
			IF idx+8 >= LEN(buffer) THEN EXIT; END;
			IF i >= LEN(iads) THEN EXIT; END;
			IF ORD(buffer[idx+1]) = DescriptorIad THEN
		 		IF Debug.Trace & Debug.traceParsing THEN ShowParse("interface association", idx, ORD(buffer[idx+1]), ORD(buffer[idx+0])); END;
		 		NEW(iad);
		 		iad.bFirstInterface := ORD(buffer[idx+2]);
				iad.bInterfaceCount := ORD(buffer[idx+3]);
				iad.bFunctionClass := ORD(buffer[idx+4]);
				iad.bFunctionSubClass := ORD(buffer[idx+5]);
				iad.bFunctionProtocol := ORD(buffer[idx+6]);
				iad.iFunction := ORD(buffer[idx+7]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[idx+8]));
				iads[i] := iad;
				INC(i);
			END;
			idx := idx + ORD(buffer[idx+0]);
		END;
	ELSIF Debug.Trace & Debug.traceParsing THEN KernelLog.String("No interface association descriptors found."); KernelLog.Ln;
	END;
	IF i # num THEN (* We didn't find all IADs... we can live without them, but warn the user *)
		IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Warning: Error when parsing IADs."); KernelLog.Ln; END;
		RETURN NIL;
	END;
	RETURN iads;
END ParseInterfaceAssociation;

(* Parse all non-standard descriptors found in the configuration *)
PROCEDURE ParseUnknownDescriptors(configuration : Usbdi.ConfigurationDescriptor; buffer : Usbdi.Buffer) : Usbdi.UnknownDescriptor;
VAR idx, i,  type,  curIntf, curAltIntf, curEp : LONGINT; list, unknown : Usbdi.UnknownDescriptor;

	PROCEDURE AppendToList(head, unknown : Usbdi.UnknownDescriptor);
	VAR u : Usbdi.UnknownDescriptor;
	BEGIN
		u := head; WHILE(u.next # NIL) DO u := u.next; END;
		u.next := unknown;
	END AppendToList;

	PROCEDURE AppendNonStandard(unknown : Usbdi.UnknownDescriptor) : BOOLEAN;
	VAR i : LONGINT; intf, altIntf : Usbdi.InterfaceDescriptor; endp : Usbdi.EndpointDescriptor;
	BEGIN
		IF (curIntf = -1) THEN (* Append to configuration *)
			IF configuration.unknown = NIL THEN configuration.unknown := unknown;
			ELSE
				AppendToList(configuration.unknown, unknown);
			END;
		ELSE (* Append to interface, alternate interface or endpoint *)
			(* Search Interface *)
			LOOP
				IF (configuration.interfaces=NIL) OR (i >= LEN(configuration.interfaces)) THEN EXIT; END;
				intf := configuration.interfaces[i];
				IF intf.bInterfaceNumber = curIntf THEN EXIT; END;
				INC(i);
			END;
			IF (intf = NIL) OR (intf.bInterfaceNumber # curIntf) THEN RETURN FALSE; END;

			IF curAltIntf # 0 THEN
				(* Search alternate interface *)
				i := 0;
				LOOP
					IF (intf.alternateInterfaces=NIL) OR (i >= LEN(intf.alternateInterfaces)) THEN EXIT; END;
					altIntf := intf.alternateInterfaces[i];
					IF altIntf.bAlternateSetting = curAltIntf THEN EXIT; END;
					INC(i);
				END;
				IF (altIntf = NIL) OR (altIntf.bAlternateSetting # curAltIntf) THEN RETURN FALSE; END;
				intf := altIntf;
			END;

			IF curEp = -1 THEN (* Append to interface *)
				IF intf.unknown = NIL THEN intf.unknown := unknown;
				ELSE
					AppendToList(intf.unknown, unknown);
				END;
			ELSE (* Append to endpoint *)
				(* Search endpoint descriptor *)
				i := 0;
				LOOP
					IF (intf.endpoints = NIL) OR (i >= LEN(intf.endpoints)) THEN EXIT; END;
					endp := intf.endpoints[i];
					IF endp.bEndpointAddress = curEp THEN EXIT; END;
					INC(i);
				END;
				IF (endp = NIL) OR (endp.bEndpointAddress # curEp) THEN RETURN FALSE; END;
				IF endp.unknown = NIL THEN endp.unknown := unknown;
				ELSE
					AppendToList(endp.unknown, unknown);
				END;
			END;
		END;
		RETURN TRUE;
	END AppendNonStandard;

BEGIN
	ASSERT(configuration # NIL);
	IF Debug.Trace & Debug.traceParsing THEN KernelLog.String("Usb: Parsing non-standard descriptors:"); KernelLog.Ln; END;
	curIntf := -1; curAltIntf := -1; curEp := -1;
	LOOP
		IF idx + 1 >= LEN(buffer) THEN EXIT; END;

	 	type := ORD(buffer[idx+1]);

	 	IF type = DescriptorConfiguration THEN
	 		(* skip *)
	 	ELSIF type = DescriptorIad THEN
	 		curIntf := -1; curAltIntf := -1;	curEp := -1;
	 	ELSIF type = DescriptorInterface THEN
	 		IF idx+3 >= LEN(buffer) THEN EXIT; END;
	 		curIntf := ORD(buffer[idx+2]);
			curAltIntf := ORD(buffer[idx+3]);
			curEp := -1;
	 	ELSIF type = DescriptorEndpoint THEN
	 		IF idx+2 >= LEN(buffer) THEN EXIT; END;
	 		curEp := ORD(buffer[idx+2]);
	 	ELSE (* Non-Standard descriptor *)
	 		NEW(unknown);
	 		unknown.bLength := ORD(buffer[idx+0]);
	 		unknown.bDescriptorType := ORD(buffer[idx+1]);
	 		IF Debug.Trace & Debug.traceParsing THEN ShowParse("unknown descriptor", idx, unknown.bDescriptorType, unknown.bLength); END;
	 		IF idx + unknown.bLength > LEN(buffer) THEN EXIT; END;
	 		NEW(unknown.descriptor, unknown.bLength);
	 		FOR i := 0 TO unknown.bLength-1 DO unknown.descriptor[i] := buffer[idx+i] END;
	 		IF ~AppendNonStandard(unknown) THEN
	 			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: ParseUnknownDescriptors: Warning: Could not assign non-standard descriptor."); KernelLog.Ln;	END;
	 			RETURN NIL;
	 		END;
	 	END;
	 	idx := idx + ORD(buffer[idx + 0]);
	END;

	IF idx # LEN(buffer) THEN
		IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: ParseUnknownDescriptors: Warning: Parse Error"); KernelLog.Ln; END;
		list := NIL;
	END;
	RETURN list;
END ParseUnknownDescriptors;

(* Parse the first endpoint descriptor found in the configuration beginning at index idx *)
PROCEDURE ParseEndpointDescriptor(buffer : Usbdi.Buffer; VAR idx : LONGINT) : EndpointDescriptor;
VAR endpoint : EndpointDescriptor; dword : SET;

	PROCEDURE GetEndpointType(address, attributes : SET) : LONGINT;
	VAR type : LONGINT;
	BEGIN
		IF attributes * {0..1} = {} THEN
			type := Usbdi.Control;
		ELSE
			IF address * {7} = {} THEN (* direction = OUT *)
				IF attributes * {0..1} = {0} THEN type := Usbdi.IsochronousOut;
				ELSIF attributes * {0..1} = {1} THEN type := Usbdi.BulkOut;
				ELSE type := Usbdi.InterruptOut;
				END;
			ELSE (* direction = IN *)
				IF attributes * {0..1} = {0} THEN type := Usbdi.IsochronousIn;
				ELSIF attributes * {0..1} = {1} THEN type := Usbdi.BulkIn;
				ELSE type := Usbdi.InterruptIn;
				END;
			END;
		END;
		RETURN type;
	END GetEndpointType;

BEGIN
	IF (Debug.Trace & Debug.traceParsing) & (idx+1 < LEN(buffer)) THEN ShowParse("endpoint",idx, ORD(buffer[idx+1]), ORD(buffer[idx+0])); END;
	(* Skip non-USB-standard descriptors (e.g. HID descriptors) *)
	SkipOthers(DescriptorEndpoint, buffer, idx);
	IF idx + 6 >= LEN(buffer) THEN
		IF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: ParseEndpoint: Buffer too short."); KernelLog.Ln; END;
		RETURN NIL;
	END;
	ASSERT(ORD(buffer[idx+1])=DescriptorEndpoint);
	NEW(endpoint);
	endpoint.bLength := ORD(buffer[idx + 0]);
	endpoint.bEndpointAddress := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(buffer[idx + 2])) * {0..3, 7});
	endpoint.bmAttributes := SYSTEM.VAL(SET, ORD(buffer[idx + 3]));
	endpoint.type := GetEndpointType(SYSTEM.VAL(SET, endpoint.bEndpointAddress), endpoint.bmAttributes);
	dword := SYSTEM.VAL(SET, ORD(buffer[idx + 4]) + 256*SYSTEM.VAL(LONGINT, ORD(buffer[idx + 5])));
	endpoint.wMaxPacketSize := SYSTEM.VAL(LONGINT, dword * {0..10});
	endpoint.mult := LSH(SYSTEM.VAL(LONGINT, dword * {11..12}), -11) + 1;
	endpoint.bInterval := ORD(buffer[idx + 6]);
	idx := idx + ORD(buffer[idx + 0]);
	RETURN endpoint;
END ParseEndpointDescriptor;

(* Parse the first interface descriptor beginning at index idx  including its endpoints *)
PROCEDURE ParseInterfaceDescriptor(buffer :Usbdi.Buffer; VAR idx : LONGINT) : InterfaceDescriptor;
VAR interface : InterfaceDescriptor; e : LONGINT;
BEGIN
	IF (Debug.Trace & Debug.traceParsing) & (idx+1 < LEN(buffer))  THEN ShowParse("interface",idx, ORD(buffer[idx+1]), ORD(buffer[idx+0])); END;
	(* Skip non-USB-standard descriptors (e.g. HID descriptors) *)
	SkipOthers(DescriptorInterface, buffer, idx);
	IF idx + 8 >= LEN(buffer) THEN
		IF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: ParseInterface: Buffer too short."); KernelLog.Ln; END;
		RETURN NIL;
	END;
	ASSERT(ORD(buffer[idx + 1])=DescriptorInterface);
	NEW(interface);
	interface.bLength := ORD(buffer[idx + 0]);
	interface.bInterfaceNumber := ORD(buffer[idx + 2]);
	interface.bAlternateSetting := ORD(buffer[idx + 3]);
	interface.bNumEndpoints := ORD(buffer[idx + 4]);
	interface.bInterfaceClass := ORD(buffer[idx + 5]);
	interface.bInterfaceSubClass := ORD(buffer[idx + 6]);
	interface.bInterfaceProtocol := ORD(buffer[idx + 7]);
	interface.iInterface := ORD(buffer[idx + 8]);

	idx := idx + ORD(buffer[idx + 0]);

	(* Interface can have zero endpoints (only containing endpoint 0) *)
	IF (interface.bNumEndpoints > 0)  THEN
		NEW(interface.endpoints, interface.bNumEndpoints);
		FOR e := 0 TO interface.bNumEndpoints-1 DO
			interface.endpoints[e] := ParseEndpointDescriptor(buffer, idx);
			IF interface.endpoints[e] = NIL THEN RETURN NIL; END;
		END;
	END;
	RETURN interface;
END ParseInterfaceDescriptor;

(* Parse the configuration descriptor including all standard interfaces, alternate interfaces and endpoints. *)
PROCEDURE ParseConfigurationDescriptor(buffer : Usbdi.Buffer) : ConfigurationDescriptor;
VAR configuration : ConfigurationDescriptor; i, j, idx, num, intfNbr : LONGINT;

	(* Return the number of alternate interfaces of interface <intf> starting at idx *)
	PROCEDURE NumAltInterfaces(intf, idx : LONGINT) : LONGINT;
	VAR res : LONGINT;
	BEGIN
		WHILE(idx + 3 < LEN(buffer)) DO
			IF (ORD(buffer[idx+1]) = DescriptorInterface) & (ORD(buffer[idx+2]) = intf) & (ORD(buffer[idx+3]) # 0) THEN
				INC(res);
			END;
			idx := idx + ORD(buffer[idx+0]);
		END;
		RETURN res;
	END NumAltInterfaces;

BEGIN
	IF Debug.Trace & Debug.traceParsing THEN
		ShowParse("configuration",idx, ORD(buffer[idx+1]), ORD(buffer[idx+0]));
		KernelLog.String("Usb: Total Length of configuration: "); KernelLog.Int(LEN(buffer), 0); KernelLog.Ln;
	END;
	NEW(configuration);
	configuration.bLength := ORD(buffer[0]);
	configuration.wTotalLength := ORD(buffer[2])+ 256*SYSTEM.VAL(LONGINT, ORD(buffer[3]));
	configuration.bNumInterfaces := ORD(buffer[4]);
	configuration.bConfigurationValue := ORD(buffer[5]);
	configuration.iConfiguration := ORD(buffer[6]);
	configuration.bmAttributes := SYSTEM.VAL(SET, ORD(buffer[7]));
	configuration.bMaxPower := 2*ORD(buffer[8]);

	IF SYSTEM.VAL(SET, ORD(buffer[7])) * {5} # {} THEN configuration.remoteWakeup := TRUE; END;
	IF SYSTEM.VAL(SET, ORD(buffer[7])) * {6} # {} THEN configuration.selfPowered := TRUE;  END;

	idx := configuration.bLength; (* idx points to first interface or IAD*)

	NEW(configuration.interfaces, configuration.bNumInterfaces); (* Always > 0 *)

	FOR i := 0 TO configuration.bNumInterfaces-1 DO

		IF idx + 1 >= LEN(buffer) THEN
			IF Debug.Level >= Debug.Errors THEN KernelLog.String("Usb: ParseConfiguration: Buffer too short."); KernelLog.Ln; END;
			RETURN NIL;
		END;
		SkipOthers(DescriptorInterface, buffer, idx);
		IF ORD(buffer[idx+1]) = DescriptorInterface THEN
			intfNbr := ORD(buffer[idx+2]);
			configuration.interfaces[i] := ParseInterfaceDescriptor(buffer, idx);
			IF configuration.interfaces[i] = NIL THEN RETURN NIL; END;
			num := NumAltInterfaces(intfNbr, idx);
			IF Debug.Trace & Debug.traceParsing THEN
				KernelLog.String("Usb: Parsing: "); KernelLog.Int(num, 0); KernelLog.String(" alternate interfaces found."); KernelLog.Ln;
			END;
			IF num # 0 THEN
				configuration.interfaces[i].numAlternateInterfaces := num;
				NEW(configuration.interfaces[i].alternateInterfaces, num);
				FOR j := 0 TO num-1 DO
					configuration.interfaces[i].alternateInterfaces[j] := ParseInterfaceDescriptor(buffer, idx);
					IF configuration.interfaces[i].alternateInterfaces[j] = NIL THEN RETURN NIL; END;
				END;
			END;
		END;
	END;
	RETURN configuration;
END ParseConfigurationDescriptor;

(* Skip all descriptors except those with the specified type *)
PROCEDURE SkipOthers(type : LONGINT; buffer : Usbdi.Buffer; VAR idx : LONGINT);
BEGIN
	(* Skip non-USB-standard descriptors (e.g. HID descriptors) *)
	WHILE(idx+1 < LEN(buffer)) & (ORD(buffer[idx+1]) # type) (* & (ORD(buffer[idx+1]) # DescriptorIad) *) DO
		IF Debug.Trace & Debug.traceParsing THEN ShowParse("Skip descriptor", idx, ORD(buffer[idx+1]), ORD(buffer[idx+0])); END;
		idx := idx + ORD(buffer[idx+0]);
	END;
END SkipOthers;

PROCEDURE ShowParse(CONST string : ARRAY OF CHAR; index, type, length : LONGINT);
BEGIN
	IF Debug.Trace THEN
	KernelLog.String("Usb: Parsing "); KernelLog.String(string); KernelLog.String(" at index "); KernelLog.Int(index, 0);
	KernelLog.String(" (Type: "); KernelLog.Int(type, 0); KernelLog.String(", Length: "); KernelLog.Int(length, 0); KernelLog.String(")"); KernelLog.Ln;
	END;
END ShowParse;

(* Reads StringDescriptors from USBdevice dev if any available *)
PROCEDURE GetStrings*(dev : UsbDevice);
VAR
	buffer : Usbdi.BufferPtr;
	langid : LONGINT;
	i, j, k, len : LONGINT;
	configuration : ConfigurationDescriptor;
	interface, altInterface : InterfaceDescriptor;

	PROCEDURE GetString(descriptorIndex, langID : LONGINT) :  Lib.UnicodeString;
	VAR unicode : Lib.UnicodeString; size, i, len : LONGINT; res : BOOLEAN;
	BEGIN
		(*First, get the length of the string descriptor to be loaded... *)
		NEW(buffer, 2);
		res := dev.GetDescriptor(DescriptorString,  descriptorIndex, langID, 2, buffer^);
		IF (res = TRUE) & (ORD(buffer[1]) = DescriptorString) & (ORD(buffer[0]) > 3) & (ORD(buffer[0]) MOD 2 = 0) THEN
			(* ... and then load the string descriptor *)
			len := ORD(buffer[0]); NEW(buffer, len);
			IF dev.GetDescriptor(DescriptorString, descriptorIndex, langID, len, buffer^) THEN
				(* ORD(buffer[0]) (length in bytes) - 2 (descriptortype and length field) DIV 2 : device delivers 16byte per character *)
				size :=  ((ORD(buffer[0])-2) DIV 2);
				NEW(unicode, size);
				(* Convert ARRAY OF CHAR to ARRAY OF LONGINT *)
				FOR i:=0 TO size-1 DO
					unicode[i] := ORD(buffer[(2*i)+2])+SYSTEM.VAL(LONGINT, ORD(buffer[(2*i)+3]))*100H;
				END;
			ELSIF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't load string descriptor"); KernelLog.Ln;
			END;
		ELSIF Debug.Level >= Debug.Warnings  THEN KernelLog.String("Usb: Couldn't get the first 2 bytes of the string descriptor"); KernelLog.Ln;
		END;
		RETURN unicode;
	END GetString;

BEGIN
	IF Debug.Trace & Debug.traceParsing THEN KernelLog.String("Usb: Read string descriptors... "); KernelLog.Ln; END;
	IF (dev.descriptor(DeviceDescriptor).iManufacturer=0) & (dev.descriptor(DeviceDescriptor).iProduct=0) & (dev.descriptor(DeviceDescriptor).iSerialNumber=0) THEN (* no string describtors supported *)
		IF Debug.Trace & Debug.traceParsing THEN KernelLog.String("Usb: No String Descriptors provided by this device."); KernelLog.Ln; END;
	ELSE
		(* first get the length of the LANGID code array *)
		NEW(buffer, 2);
		IF ~dev.GetDescriptor(DescriptorString, 0, 0, 2,  buffer^) OR (ORD(buffer[1]) # DescriptorString) THEN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't load the first 2 bytes of StringDescriptor"); KernelLog.Ln; END;
			RETURN;
		END;

		(* Get the LANDID code array *)
		len := ORD(buffer[0]); NEW(buffer, len);
		IF ~dev.GetDescriptor(DescriptorString, 0, 0, len, buffer^) OR (ORD(buffer[1]) # DescriptorString) THEN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't load String Descriptor"); KernelLog.Ln; END;
			RETURN;
		END;

		(* Get a preferred LANGID code *)
		IF LangIdSupported(buffer^, IdEnglishUS) THEN langid := IdEnglishUS;
		ELSIF LangIdSupported(buffer^, IdEnglishUK) THEN langid := IdEnglishUK;
		ELSIF LangIdSupported(buffer^, IdSystemDefault) THEN langid := IdSystemDefault;
		ELSIF LangIdSupported(buffer^, IdUserDefault) THEN langid := IdUserDefault;
		ELSIF ORD(buffer[0])-2 > 0 THEN (* at least one other language is supported... use it *)
			langid := ORD(buffer[3]) + 100H*SYSTEM.VAL(LONGINT, ORD(buffer[4]));
			IF Debug.Trace & Debug.traceParsing THEN KernelLog.String("Usb: Used LANGID code for GetString():"); KernelLog.Int(langid, 0); KernelLog.Ln; END;
		ELSE
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Usb: Couldn't load string descriptor (No supported language found)"); KernelLog.Ln; END;
			RETURN;
		END;

		(* Get manufacturer string *)
		IF dev.descriptor(DeviceDescriptor).iManufacturer # 0 THEN
			dev.descriptor(DeviceDescriptor).uManufacturer := GetString(dev.descriptor(DeviceDescriptor).iManufacturer, langid);
			dev.descriptor(DeviceDescriptor).sManufacturer := Lib.Unicode2Ascii(dev.descriptor(DeviceDescriptor).uManufacturer);
		END;

		(* Get product string *)
		IF dev.descriptor(DeviceDescriptor).iProduct # 0 THEN
			dev.descriptor(DeviceDescriptor).uProduct := GetString(dev.descriptor(DeviceDescriptor).iProduct, langid);
			dev.descriptor(DeviceDescriptor).sProduct := Lib.Unicode2Ascii(dev.descriptor(DeviceDescriptor).uProduct);
		END;

		(* Get serial number *)
		IF dev.descriptor(DeviceDescriptor).iSerialNumber # 0 THEN
			dev.descriptor(DeviceDescriptor).uSerialNumber := GetString(dev.descriptor(DeviceDescriptor).iSerialNumber, 0000H); (* 0000H: Language neutral *)
			dev.descriptor(DeviceDescriptor).sSerialNumber := Lib.Unicode2Ascii(dev.descriptor(DeviceDescriptor).uSerialNumber);
		END;

		(* Get string descriptors of the configurations and interfaces if available *)
		FOR i := 0 TO dev.descriptor.bNumConfigurations-1 DO
			configuration := dev.configurations[i] (ConfigurationDescriptor);

			IF configuration.iConfiguration#0 THEN (* device provide configuration description(s) *)
				dev.configurations[i](ConfigurationDescriptor).uConfiguration := GetString(configuration.iConfiguration, langid);
				dev.configurations[i](ConfigurationDescriptor).sConfiguration := Lib.Unicode2Ascii(dev.configurations[i](ConfigurationDescriptor).uConfiguration);
			END;

			FOR j := 0 TO configuration.bNumInterfaces -1 DO
				interface := configuration.interfaces[j] (InterfaceDescriptor);

				IF interface.iInterface#0 THEN (* Device provides interface descriptor(s) *)
					interface.uInterface := GetString(interface.iInterface, langid);
					interface.sInterface := Lib.Unicode2Ascii(interface.uInterface);
				END;

				FOR k := 0 TO interface.numAlternateInterfaces -1 DO
					altInterface := interface.alternateInterfaces[k] (InterfaceDescriptor);

					IF altInterface.iInterface#0 THEN (* Device provides interface descriptor(s) *)
						altInterface.uInterface := GetString(altInterface.iInterface, langid);
						altInterface.sInterface := Lib.Unicode2Ascii(altInterface.uInterface);
					END;
				END;
			END;
		END;
	END;
END GetStrings;

(** Returns TRUE if the <langid> is supported, FALSE otherwise *)
PROCEDURE LangIdSupported(buffer : Usbdi.Buffer; langid : LONGINT): BOOLEAN;
VAR supported : BOOLEAN; i : LONGINT;
BEGIN
	(* LANDID code array:  buf[0]=length of code array, buf[1]=DecriptorString, buf[2*i]+buf[2*i+1] : LangID codes *)
	IF (ORD(buffer[0]) MOD 2 # 0) OR (ORD(buffer[0]) < 4) THEN RETURN FALSE; END;
	(* Check whether langID is a element of the LANGID code array *)
	FOR i := 2 TO ORD(buffer[0])-2 BY 2 DO
		IF (ORD(buffer[i])+SYSTEM.VAL(LONGINT, ORD(buffer[i+1]))*100H) = langid THEN supported := TRUE; END;
	END;
	RETURN supported;
END LangIdSupported;

PROCEDURE ShowState(state : LONGINT);
BEGIN
	IF Debug.Trace THEN
	CASE state OF
	|StateDisconnected: KernelLog.String("Disconnected");
	|StateAttached: KernelLog.String("Attached");
	|StatePowered: KernelLog.String("Powered");
	|StateDefault: KernelLog.String("Default");
	|StateAddress: KernelLog.String("Address");
	|StateConfigured: KernelLog.String("Configured");
	|StateSuspended: KernelLog.String("Suspended");
	ELSE
		KernelLog.String("Unknown ("); KernelLog.Int(state, 0); KernelLog.String(")");
	END;
	END;
END ShowState;

PROCEDURE ShowStateTransition(dev : UsbDevice; newState : LONGINT);
BEGIN
	IF Debug.Trace THEN
	KernelLog.String("Usb: Device "); dev.ShowName; KernelLog.String(": State transition from ");
	ShowState(dev.state); KernelLog.String(" to "); ShowState(newState); KernelLog.Ln;
	END;
END ShowStateTransition;

PROCEDURE GetRootHubs*(VAR rootHubsCopy : RootHubArray);
VAR i : LONGINT;
BEGIN {EXCLUSIVE}
	IF rootHubs = NIL THEN rootHubsCopy := NIL; RETURN; END;
	IF (rootHubsCopy = NIL) OR (LEN(rootHubs) # LEN(rootHubsCopy)) THEN
		NEW(rootHubsCopy, LEN(rootHubs));
	END;
	FOR i := 0 TO LEN(rootHubs)-1 DO
		rootHubsCopy[i] := rootHubs[i];
	END;
END GetRootHubs;

PROCEDURE RootHubEvent(event : LONGINT; plugin : Plugins.Plugin);
VAR hcd : UsbHcdi.Hcd;
BEGIN
	hcd := plugin(UsbHcdi.Hcd);
	IF event = Plugins.EventAdd THEN
		AddRootHub(hcd);
	ELSIF event = Plugins.EventRemove THEN
		RemoveRootHub(hcd);
	ELSE
		HALT(90);
	END;
	Machine.AtomicInc(nbrOfTopologyEvents);
END RootHubEvent;

PROCEDURE AddRootHub(hcd : UsbHcdi.Hcd);
VAR roothub : EmulatedHubDevice; temp : RootHubArray; i : LONGINT;
BEGIN {EXCLUSIVE}
	NEW(roothub, hcd);
	IF rootHubs = NIL THEN
		NEW(rootHubs, 1);
		rootHubs[0] := roothub;
	ELSE
		NEW(temp, LEN(rootHubs)+1);
		FOR i := 0 TO LEN(rootHubs)-1 DO
			temp[i] := rootHubs[i];
		END;
		temp[LEN(rootHubs)] := roothub;
		rootHubs := temp;
	END;
	drivers.ProbeDevice(roothub);
END AddRootHub;

PROCEDURE RemoveRootHub(hcd : UsbHcdi.Hcd);
VAR i, j : LONGINT; temp : RootHubArray; roothub : EmulatedHubDevice;
BEGIN {EXCLUSIVE}
	IF rootHubs # NIL THEN
		IF LEN(rootHubs) > 1 THEN
			NEW(temp, LEN(rootHubs)-1);
			j := 0;
			FOR i := 0 TO LEN(rootHubs)-1 DO
				IF rootHubs[i].controller = hcd THEN
					roothub := rootHubs[i] (EmulatedHubDevice);
				ELSE
					IF j < LEN(temp) THEN temp[j] := rootHubs[i]; END; INC(j);
				END;
			END;
		ELSE
			IF rootHubs[0].controller = hcd THEN
				roothub := rootHubs[0] (EmulatedHubDevice);
			END;
		END;

		IF roothub # NIL THEN (* Found device to be removed *)
			rootHubs := temp;
			roothub.Remove;
		END;
	END;
END RemoveRootHub;

PROCEDURE InstallRootHubs;
VAR table : Plugins.Table; i : LONGINT;
BEGIN
	UsbHcdi.controllers.AddEventHandler(RootHubEvent, i); (* ignore res *)
	UsbHcdi.controllers.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO AddRootHub(table[i](UsbHcdi.Hcd)); END;
	END;
END InstallRootHubs;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	UsbDriverLoader.SetListener(NIL);
	drivers.Terminate;
	Plugins.main.Remove(usbDrivers);
	IF Debug.Verbose THEN KernelLog.Enter; KernelLog.String("Usb: USB driver unloaded."); KernelLog.Exit; END;
END Cleanup;

BEGIN
	(* System wide registry for USB device drivers *)
	NEW(usbDrivers, "Usb","USB Device Drivers");

	(* Create internal driver registry *)
	NEW(drivers); Usbdi.drivers := drivers;

	ASSERT(UsbHcdi.StateDisconnected = StateDisconnected);

	Modules.InstallTermHandler(Cleanup);
	InstallRootHubs;

	(* Install a notifier that will be called when the driver lookup service is enabled. *)
	UsbDriverLoader.SetListener(drivers.ProbeDrivers);

	IF Debug.Verbose THEN KernelLog.Enter; KernelLog.String("Usb: USB driver loaded."); KernelLog.Exit; END;
END Usb.


