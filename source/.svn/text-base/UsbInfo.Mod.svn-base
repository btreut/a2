MODULE UsbInfo; (** AUTHOR "staubesv"; PURPOSE "USB topology info" *)
(**
 * This Module doesn't add any functionality to the USB system software. Its purpose is to represent the current state of
 * the USB system software and to control trace options.
 *
 * Usage:
 *
 *	(* Information *)
 *	UsbInfo.Show ~ will display the current USB topology
 *	UsbInfo.Show details ~ will display the current USB topology with all available information (descriptors, configurations,...)
 *	UsbInfo.ShowDrivers ~ will display information about registered USB device drivers and their instances
 *	UsbInfo.ShowHc ~ will display all registered USB host controllers
 *	UsbInfo.ShowHc details ~ will display diagnostic information of all registered USB host controllers
 * 	UsbInfo.ShowHc schedule ~ will display the scheduling data structures of all host controllers
 *	UsbInfo.ShowHc pipes ~ will display all allocated pipes
 *	UsbInfo.ShowHc pipemore ~ will display all allocated pipes including their QH/TDs
 *	UsbInfo.ShowHc all ~ will display both the HC diagnostic information and its scheduling data structures
 *
 *	(* Trace options *)
 *	UsbInfo.TraceAll ~ enables all trace options
 *	UsbInfo.TraceNone ~ disables all trace options
 *	UsbInfo.TraceShow ~ show state of trace options
 *
 *	(* See UsbDebug.Mod for a description of the individual trace optinos *)
 *	UsbInfo.TraceOn Dm~ 			UsbInfo.TraceOff  Dm~
 *	UsbInfo.TraceOn Parsing~ 		UsbInfo.TraceOff  Parsing~
 *	UsbInfo.TraceOn DeviceStates~	UsbInfo.TraceOff  DeviceStates~
 *	UsbInfo.TraceOn Control~ 		UsbInfo.TraceOff  Control~
 *	UsbInfo.TraceOn ControlData~ 	UsbInfo.TraceOff  ControlData~
 *	UsbInfo.TraceOn Transfers~ 		UsbInfo.TraceOff  Transfers~
 *	UsbInfo.TraceOn Failed~ 			UsbInfo.TraceOff  Failed~
 *	UsbInfo.TraceOn ShortPackets ~	UsbInfo.TraceOff  ShortPackets ~
 *	UsbInfo.TraceOn Pipes~ 			UsbInfo.TraceOff  Pipes~
 *	UsbInfo.TraceOn Copying~ 		UsbInfo.TraceOff  Copying~
 *	UsbInfo.TraceOn Ioc~ 			UsbInfo.TraceOff  Ioc~
 *	UsbInfo.TraceOn Init~ 			UsbInfo.TraceOff  Init~
 *	UsbInfo.TraceOn Interrupts~ 		UsbInfo.TraceOff  Interrupts~
 *	UsbInfo.TraceOn Queuing~ 		UsbInfo.TraceOff  Queuing~
 *	UsbInfo.TraceOn HubRequests~ 	UsbInfo.TraceOff  HubRequests~
 *	UsbInfo.TraceOn Suspend~		UsbInfo.TraceOff  Suspend~
 *	UsbInfo.TraceOn Connects~		UsbInfo.TraceOff  Connects~
 *	UsbInfo.TraceOn Info~ 			UsbInfo.TraceOff  Info~
 *	UsbInfo.TraceOn Sensing~		UsbInfo.TraceOff  Sensing~
 *	UsbInfo.TraceOn ScRequests~ 	UsbInfo.TraceOff  ScRequests~
 *	UsbInfo.TraceOn ScTransfers~ 	UsbInfo.TraceOff  ScTransfers~
 *	UsbInfo.TraceOn CSWs~ 			UsbInfo.TraceOff  CSWs~
 *	UsbInfo.TraceOn CBWs~ 			UsbInfo.TraceOff  CBWs~
 *	UsbInfo.TraceOn ScInit~		 	UsbInfo.TraceOff  ScInit~
 *	UsbInfo.TraceOn Custom~		UsbInfo.TraceOff Custom~
 *
 *	UsbInfo.TraceOn Info Sensing ScRequests ScTransfers CSWs CBWs ScInit~ turns on all mass storage device related trace options
 *	UsbInfo.TraceOff Info Sensing ScRequests ScTransfers CSWs CBWs ScInit~ turns off ...
 *
 *	UsbInfo.TraceOn Dm Parsing DeviceStates Failed Pipes Init HubRequests Connects Info ~ is interesting when connecting devices
 *
 *	SystemTools.Free UsbInfo ~
 *
 * History:
 *
 *	17.11.2005	Created (staubesv)
 *	12.12.2005	Added schedule, pipes & all parameter to ShowHc (staubesv)
 *	01.02.2006	Adapted ShowHc to UsbHcdi changes (staubesv)
 *	06.02.2006	Added trace option control (staubesv)
 *	26.02.2006	Added Custom trace option (staubesv)
 *	28.06.2006	Adapted to modified Usb.GetRootHubs procedure (staubesv)
 *	04.07.2006	Added ShowHc pipemore (staubesv)
 *	05.01.2007	Added ShortPackets trace option, call ShowConfiguration in ShowDevice (staubesv)
 *)

IMPORT
	SYSTEM,
	Streams, Commands, Plugins, Strings,
	UsbHcdi, Usb, Usbdi, UsbDebug;

PROCEDURE ShowDeviceName(dev : Usb.UsbDevice; out : Streams.Writer);
VAR descriptor : Usb.DeviceDescriptor;
BEGIN
	descriptor := dev.descriptor (Usb.DeviceDescriptor);
	IF (descriptor # NIL) & (descriptor.sManufacturer # NIL) OR (descriptor.sProduct # NIL) THEN
		IF descriptor.sManufacturer # NIL THEN out.String(descriptor.sManufacturer^); out.Char(" "); END;
		IF descriptor.sProduct # NIL THEN out.String(descriptor.sProduct^); END;
	ELSE
		out.String("unknown device");
	END;
END ShowDeviceName;

(* Shows device descriptor / qualifier information and all configurations including its interfaces and endpoints. *)
PROCEDURE ShowDevice(dev : Usb.UsbDevice; indent : LONGINT; details : BOOLEAN; out : Streams.Writer);
VAR a, c, e, i : LONGINT;
BEGIN
	IF dev.hubFlag THEN
		IF dev.parent = dev THEN out.String("Root "); END;
		out.String("Hub with "); out.Int(dev.nbrOfPorts, 0); out.String(" ports: ");
	END;
	ShowDeviceName(dev, out);
	IF ~details OR (dev.hubFlag & (dev.parent = dev)) THEN RETURN END;
	out.String("(S/N: ");
	IF dev.descriptor(Usb.DeviceDescriptor).sSerialNumber # NIL THEN out.String(dev.descriptor(Usb.DeviceDescriptor).sSerialNumber^); out.String(")");
	ELSE out.String("Not available)");
	END;
	out.Ln;
	Indent(indent+4, out);
	out.String("Address: "); out.Int(dev.address, 0); out.String(" ");
	IF dev.speed = UsbHcdi.LowSpeed THEN out.String(" [LowSpeed]");
	ELSIF dev.speed = UsbHcdi.FullSpeed THEN out.String(" [FullSpeed]");
	ELSIF dev.speed = UsbHcdi.HighSpeed THEN out.String(" [HighSpeed]");
	ELSE out.String(" [UnknownSpeed!!!]");
	END;
	out.Ln;
	Indent(indent+4, out); out.String("Device descriptor information: ");
	out.Ln;
	ShowDescriptor(dev.descriptor (Usb.DeviceDescriptor), indent+8, out);
	(* List all configurations *)
	FOR c := 0 TO dev.descriptor.bNumConfigurations-1 DO
		Indent(indent+12, out);
		out.String("Configuration "); out.Int(c, 0); out.String(":");
		IF dev.configurations[c](Usb.ConfigurationDescriptor).sConfiguration # NIL THEN  out.String(dev.configurations[c](Usb.ConfigurationDescriptor).sConfiguration^); END;
		IF dev.actConfiguration = dev.configurations[c] THEN out.String(" [active]"); END; out.Ln;
		ShowConfiguration(dev.configurations[c](Usb.ConfigurationDescriptor), indent + 16, out);
		out.Ln;
		(* List all interfaces *)
		FOR i := 0 TO dev.configurations[c].bNumInterfaces - 1 DO
			Indent(indent+16, out);
			out.String("Interface "); out.Int(i, 0); out.String(": "); out.Ln;
			ShowInterface(dev.configurations[c].interfaces[i] (Usb.InterfaceDescriptor), indent+20, out); out.Ln;
			(* List all endpoints *)
			FOR e := 0 TO dev.configurations[c].interfaces[i].bNumEndpoints-1 DO
				ShowEndpoint(dev.configurations[c].interfaces[i].endpoints[e] (Usb.EndpointDescriptor), indent+24, out);
			END;
			(* List alternate interface if available *)
			Indent(indent+20, out);
			out.String("Alternate interface: ");
			IF dev.configurations[c].interfaces[i].numAlternateInterfaces = 0 THEN out.String("n/a");  out.Ln;
			ELSE
				FOR a := 0 TO dev.configurations[c].interfaces[i].numAlternateInterfaces-1 DO
					Indent(indent+20, out); out.String("Alternate Interface "); out.Int(a, 0); out.String(": ");
					ShowInterface(dev.configurations[c].interfaces[i].alternateInterfaces[a] (Usb.InterfaceDescriptor), indent+20, out); out.Ln;
					(* List all endpoints *)
					FOR e := 0 TO dev.configurations[c].interfaces[i].bNumEndpoints-1 DO
						ShowEndpoint(dev.configurations[c].interfaces[i].alternateInterfaces[a].endpoints[e] (Usb.EndpointDescriptor), indent+24, out);
					END;
				END;
				out.Ln;
			END;
		END;
	END;
	Indent(indent+4, out);
	out.String("Device qualifier information: ");
	IF dev.qualifier = NIL THEN out.String("n/a"); out.Ln;
	ELSE
		out.Ln;
		ShowDescriptor(dev.qualifier (Usb.DeviceDescriptor), indent + 8, out);
		FOR c := 0 TO dev.qualifier.bNumConfigurations-1 DO
			Indent(indent+12, out);
			out.String("Other-Speed Configuration "); out.Int(c, 0); out.String(":");
			IF dev.otherconfigurations[c](Usb.ConfigurationDescriptor).sConfiguration#NIL THEN  out.String(dev.configurations[c](Usb.ConfigurationDescriptor).sConfiguration^); END;
			(* List all interfaces *)
			FOR i := 0 TO dev.otherconfigurations[c].bNumInterfaces - 1 DO
				out.Ln; Indent(indent+16, out);
				out.String("Interface "); out.Int(i, 0); out.String(": "); out.Ln;
				ShowInterface(dev.otherconfigurations[c].interfaces[i] (Usb.InterfaceDescriptor), indent+20, out); out.Ln;
				(* List all endpoints *)
				FOR e := 0 TO dev.otherconfigurations[c].interfaces[i].bNumEndpoints-1 DO
					ShowEndpoint(dev.otherconfigurations[c].interfaces[i].endpoints[e] (Usb.EndpointDescriptor), indent+24, out);
				END;
				(* List alternate interface if available *)
				Indent(indent+16, out);
				out.String("Alternate interface: ");
				IF dev.otherconfigurations[c].interfaces[i].numAlternateInterfaces = 0 THEN out.String("n/a");  out.Ln;
				ELSE
					FOR a := 0 TO dev.otherconfigurations[c].interfaces[i].numAlternateInterfaces-1 DO
						out.String("Alternate Interface "); out.Int(a, 0); out.String(": "); out.Ln;
						ShowInterface(dev.otherconfigurations[c].interfaces[i].alternateInterfaces[a] (Usb.InterfaceDescriptor), indent+20, out); out.Ln;
						(* List all endpoints *)
						FOR e := 0 TO dev.otherconfigurations[c].interfaces[i].bNumEndpoints-1 DO
							ShowEndpoint(dev.otherconfigurations[c].interfaces[i].alternateInterfaces[a].endpoints[e] (Usb.EndpointDescriptor), indent+24, out);
						END;
					END;
				END;
			END;
		END;
	END;
END ShowDevice;

(* Display textual respresenation of device descriptor or device qualifier *)
PROCEDURE ShowDescriptor(d : Usb.DeviceDescriptor;  indent : LONGINT; out : Streams.Writer);
BEGIN
	Indent(indent, out);
	out.String("USB Version: "); PrintHex(LSH(d.bcdUSB, -8), out); out.Char("."); PrintHex(d.bcdUSB MOD 100H, out);
	out.String(", Device Class: "); PrintHex(d.bDeviceClass, out);
	out.String("H, Subclass: "); PrintHex(d.bDeviceSubClass, out);
	out.String("H, Protocol: "); PrintHex(d.bDeviceProtocol, out); out.String("H");
	out.Ln;
	Indent(indent, out);
	out.String("MaxPacketSize0: "); out.Int(d.bMaxPacketSize0, 0); out.String(" Bytes"); out.Ln;
	Indent(indent, out);
	out.String("idVendor: "); PrintHex(d.idVendor, out);
	out.String("H,  idProduct: "); PrintHex(d.idProduct, out);
	out.String("H,  Device Version: "); PrintHex(LSH(d.bcdDevice, -8), out); out.Char("."); PrintHex(d.bcdDevice MOD 100H, out);
	out.Ln;
END ShowDescriptor;

(* Display textual respresentation of a USB device configuration *)
PROCEDURE ShowConfiguration(c : Usb.ConfigurationDescriptor; indent : LONGINT; out : Streams.Writer);
BEGIN
	Indent(indent, out); out.String("ConfigurationValue: "); out.Int(c.bConfigurationValue, 0); out.Ln;
	Indent(indent, out); out.String ("MaxPower: "); out.Int(c.bMaxPower, 0); out.String(" mA  "); out.Ln;
	Indent(indent, out); out.String("Power support: ");
	IF c.bmAttributes * {6} # {} THEN out.String("Self-Powered"); ELSE out.String("Bus-Powered"); END;
	out.Ln;
	Indent(indent, out); out.String("Remote Wake-up support: ");
	IF c.bmAttributes * {5} # {} THEN out.String("Yes"); ELSE out.String("No"); END;
END ShowConfiguration;

(* Display textual representation of a USB device interface *)
PROCEDURE ShowInterface(i : Usb.InterfaceDescriptor; indent : LONGINT; out : Streams.Writer);
VAR drv : Usbdi.Driver;
BEGIN
	Indent(indent, out);
	IF i.sInterface # NIL THEN out.String(i.sInterface^); out.String(": "); END;
	out.String("[Class: "); PrintHex(i.bInterfaceClass, out);
	out.String("H Subclass: "); PrintHex(i.bInterfaceSubClass, out);
	out.String("H Protocol: "); PrintHex(i.bInterfaceProtocol, out);
	out.String("H #Endpoints: "); out.Int(i.bNumEndpoints, 0);
	out.String("]"); out.Ln;
	Indent(indent, out);
	drv := i.driver;
	out.String("Driver: ");
	IF drv # NIL THEN
		out.String("["); out.String(drv.name);
		out.String("("); out.String(drv.desc); out.String(")]");
	ELSE out.String("[No driver installed for this interface]");
	END;
END ShowInterface;

(* Display textual representation of a USB device endpoint *)
PROCEDURE ShowEndpoint(e : Usb.EndpointDescriptor; indent : LONGINT; out : Streams.Writer);
VAR attr : LONGINT;
BEGIN
	Indent(indent, out);
	out.String("Endpoint "); 	out.Int(e.bEndpointAddress MOD 16, 0);
	out.String(":"); out.String(" [Type: ");
	attr := SYSTEM.VAL(LONGINT, e.bmAttributes);
	CASE attr OF
		0 : out.String("Control");
		|1 : out.String("Isochronous");
		|2 : out.String("Bulk");
		|3 : out.String("Interrupt");
	ELSE
		out.String("unknown");
	END;
	IF (attr#0) & (attr<4) THEN
		out.String("(");
		IF (SYSTEM.VAL(SET, e.bEndpointAddress) * {7}) # {} THEN	 out.String("IN"); out.String(")");
		ELSE out.String("OUT)");
		END;
	END;
	IF attr = 1 THEN
		out.String(", Synchronization: ");
		CASE SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, attr) * {2..3}, -2)) OF
			0 : out.String("None");
			|1: out.String("Asynchronous");
			|2: out.String("Adaptive");
			|3: out.String("Synchronous");
		END;
		out.String(", Usage: ");
		CASE SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, attr) * {2..3}, -2)) OF
			0 : out.String("Data");
			|1: out.String("Feedback");
			|2: out.String("Implicit Feedback");
			|3: out.String("Reserved");
		END;
	END;
	out.String(" MaxPacketSize: "); out.Int(e.wMaxPacketSize, 0);
	out.String(" Bytes IRQinterval: "); out.Int(e.bInterval, 0); out.String(" ms]");
	out.Ln;
END ShowEndpoint;

(* Display textual representation of the specified device and its descendants *)
PROCEDURE ShowDeviceChain(dev : Usb.UsbDevice; indent : LONGINT; details : BOOLEAN; out : Streams.Writer);
VAR i, j : LONGINT;
BEGIN
	IF dev = NIL THEN out.String("No device attached");
	ELSIF dev.hubFlag THEN
		ShowDevice(dev, indent, details, out); out.Ln;
		FOR i := 0 TO dev.nbrOfPorts - 1 DO
			FOR j := 0 TO indent - 1 DO out.Char(" "); END;
			out.String("    Port "); out.Int(i+1, 0); out.String(": ");
			IF dev.deviceAtPort[i] = NIL THEN out.String("No device attached."); out.Ln;
			ELSIF dev.portPermanentDisabled[i] THEN out.String("Permanent disable (error)"); out.Ln;
			ELSE ShowDeviceChain(dev.deviceAtPort[i], indent+8, details, out);
			END;
		END;
	ELSE ShowDevice(dev, indent, details, out); out.Ln;
	END;
END ShowDeviceChain;

PROCEDURE DoShow*(out : Streams.Writer; details: BOOLEAN);
VAR
	i : LONGINT;
	rootHubs : Usb.RootHubArray;
BEGIN
	out.String("Usb: Topology and device information: "); out.Ln;
	Usb.GetRootHubs(rootHubs);
	BEGIN {EXCLUSIVE}
		IF rootHubs # NIL THEN
			FOR i := 0 TO LEN(rootHubs)-1 DO
				ShowDeviceChain(rootHubs[i], 0, details, out);
				rootHubs[i] := NIL;
			END;
		ELSE out.String("No USB host controllers found."); out.Ln;
		END;
	END;
END DoShow;


(** Prints information about current usb tree *)
PROCEDURE Show*(context : Commands.Context);
VAR
	details : BOOLEAN;
	pstr : ARRAY 10 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(pstr);
	details :=  Strings.Match("details", pstr);
	DoShow(context.out, details);
END Show;

(** Shows all registered drivers and their instances *)
PROCEDURE ShowDrivers*(context : Commands.Context);
VAR instances : Plugins.Table; i : LONGINT;
BEGIN
	Usb.drivers.Show;
	context.out.Ln; context.out.String("Usb: Instances of registered device drivers: "); context.out.Ln;
	Usb.usbDrivers.GetAll(instances);
	IF instances=NIL THEN
		context.out.String("no device drivers instances installed"); context.out.Ln;
	ELSE
		FOR i:=0 TO LEN(instances)-1 DO
			context.out.String("   ");
			context.out.String(instances[i].name); context.out.String(" (");
			context.out.String(instances[i].desc); context.out.String(")");
			context.out.Ln;
		END;
	END;
END ShowDrivers;

(** Shows all registered USB host controllers. *)
PROCEDURE ShowHc*(context : Commands.Context); (* ["details"|"schedule"|"all"] ~ *)
VAR
	table : Plugins.Table; hcd : UsbHcdi.Hcd;
	pstr : ARRAY 10 OF CHAR;
	i : LONGINT;

	PROCEDURE ShowPipes(hcd : UsbHcdi.Hcd; details : BOOLEAN);
	VAR i, j, k : LONGINT; pipe : UsbHcdi.Pipe;
	BEGIN
		FOR i := 0 TO 127 DO (* search all addresses ... *)
			FOR j := 0 TO 15 DO (* ... and all endpoints for presence of a pipe *)
				FOR k := 0 TO 1 DO
					pipe := hcd.pipes[i][k][j];
					IF pipe # NIL THEN
						context.out.String("ADR: "); context.out.Int(i, 0); context.out.String(": "); pipe.Show(details);
					END;
				END;
			END;
		END;
	END ShowPipes;

BEGIN
	context.arg.SkipWhitespace; context.arg.String(pstr);
	UsbHcdi.controllers.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			hcd := table[i] (UsbHcdi.Hcd);
			context.out.String("**** "); context.out.String(hcd.name); context.out.String(" ("); context.out.String(hcd.desc); context.out.String(")"); context.out.Ln;
			IF Strings.Match("schedule", pstr) THEN
				IF UsbDebug.Trace THEN hcd.ShowSchedule; ELSE context.out.String("UsbInfo: UsbDebug.Trace is FALSE. Cannot show schedule."); context.out.Ln; END;
			ELSIF Strings.Match("details", pstr) THEN
				IF UsbDebug.Trace THEN hcd.Diag; ELSE context.out.String("UsbInfo: UsbDebug.Trace is FALSE. Cannot show diagnostics."); context.out.Ln; END;
			ELSIF Strings.Match("pipes", pstr) THEN
				ShowPipes(hcd, FALSE);
			ELSIF Strings.Match("pipemore", pstr) THEN
				ShowPipes(hcd, TRUE);
			ELSIF Strings.Match("all", pstr) THEN
				IF UsbDebug.Trace THEN hcd.Diag; hcd.ShowSchedule;
				ELSE
					context.out.String("UsbInfo: UsbDebug.Trace is FALSE. Cannot show schedule/diagnostics."); context.out.Ln;
				END;
				ShowPipes(hcd, TRUE);
			END;
			context.out.Ln;
		END;
	ELSE
		context.out.String("UsbInfo: No USB host controllers found."); context.out.Ln;
	END;
END ShowHc;

(* Helper: Displays the number <was> in hex to the kernel log *)
PROCEDURE PrintHex(was: LONGINT; out : Streams.Writer);
VAR z,d,h,i:LONGINT;
BEGIN
	z := 0;
	d := 16*16*16*16*16*16*16; (* what a quick hack *)
	FOR i:=0 TO 7 DO
		h := (was DIV d) MOD 16;
		IF (z = 1) OR (h # 0) OR (i = 7) THEN
			z := 1;
			IF h < 10 THEN out.Int(h,0); ELSE out.Char(CHR(ORD("A")+h-10)); END;
		END;
		d:=d DIV 16;
	END;
END PrintHex;

(* Helper *)
PROCEDURE Indent(indent : LONGINT; out : Streams.Writer);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO indent-1 DO out.Char(" "); END;
END Indent;

(** Trace options interface *)

PROCEDURE TraceAll*(context : Commands.Context);
BEGIN
	IF UsbDebug.Trace THEN
		context.out.String("UsbInfo: All trace options enabled."); context.out.Ln;
		UsbDebug.traceDm := TRUE;
		UsbDebug.traceParsing := TRUE;
		UsbDebug.traceDeviceStates := TRUE;
		UsbDebug.traceControl := TRUE;
		UsbDebug.traceControlData := TRUE;
		UsbDebug.traceTransfers := TRUE;
		UsbDebug.traceFailed := TRUE;
		UsbDebug.traceShortPackets := TRUE;
		UsbDebug.tracePipes := TRUE;
		UsbDebug.traceCopying := TRUE;
		UsbDebug.traceIoc := TRUE;
		UsbDebug.traceInit := TRUE;
		UsbDebug.traceInterrupts := TRUE;
		UsbDebug.traceQueuing := TRUE;
		UsbDebug.traceHubRequests := TRUE;
		UsbDebug.traceSuspend := TRUE;
		UsbDebug.traceConnects := TRUE;
		UsbDebug.traceInfo := TRUE;
		UsbDebug.traceSensing := TRUE;
		UsbDebug.traceScRequests := TRUE;
		UsbDebug.traceScTransfers := TRUE;
		UsbDebug.traceCSWs := TRUE;
		UsbDebug.traceCBWs := TRUE;
		UsbDebug.traceScInit := TRUE;
		UsbDebug.traceCustom := TRUE;
	ELSE
		context.out.String("UsbInfo: UsbDebug.Trace is FALSE... cannot enable tracing."); context.out.Ln;
	END;
END TraceAll;

PROCEDURE TraceNone*(context : Commands.Context);
BEGIN
	UsbDebug.traceDm := FALSE;
	UsbDebug.traceParsing := FALSE;
	UsbDebug.traceDeviceStates := FALSE;
	UsbDebug.traceControl := FALSE;
	UsbDebug.traceControlData := FALSE;
	UsbDebug.traceTransfers := FALSE;
	UsbDebug.traceFailed := FALSE;
	UsbDebug.traceShortPackets := FALSE;
	UsbDebug.tracePipes := FALSE;
	UsbDebug.traceCopying := FALSE;
	UsbDebug.traceIoc := FALSE;
	UsbDebug.traceInit := FALSE;
	UsbDebug.traceInterrupts := FALSE;
	UsbDebug.traceQueuing := FALSE;
	UsbDebug.traceHubRequests := FALSE;
	UsbDebug.traceSuspend := FALSE;
	UsbDebug.traceConnects := FALSE;
	UsbDebug.traceInfo := FALSE;
	UsbDebug.traceSensing := FALSE;
	UsbDebug.traceScRequests := FALSE;
	UsbDebug.traceScTransfers := FALSE;
	UsbDebug.traceCSWs := FALSE;
	UsbDebug.traceCBWs := FALSE;
	UsbDebug.traceScInit := FALSE;
	UsbDebug.traceCustom := FALSE;
	context.out.String("UsbInfo: All trace options disabled."); context.out.Ln;
END TraceNone;

PROCEDURE TraceShow*(context : Commands.Context);

	PROCEDURE ShowOn(on : BOOLEAN);
	BEGIN
		IF on THEN context.out.String("On"); ELSE context.out.String("Off"); END;
	END ShowOn;

BEGIN
	context.out.String("UsbInfo: Trace options state: "); context.out.Ln;
	context.out.String("UsbDebug.Trace: "); ShowOn(UsbDebug.Trace); context.out.Ln;
	context.out.String("traceDm: "); ShowOn(UsbDebug.traceDm); context.out.Ln;
	context.out.String("traceParsing: "); ShowOn(UsbDebug.traceParsing); context.out.Ln;
	context.out.String("traceDeviceStates: "); ShowOn(UsbDebug.traceDeviceStates); context.out.Ln;
	context.out.String("traceControl: "); ShowOn(UsbDebug.traceControl); context.out.Ln;
	context.out.String("traceControlData: "); ShowOn(UsbDebug.traceControlData); context.out.Ln;
	context.out.String("traceTransfers: "); ShowOn(UsbDebug.traceTransfers); context.out.Ln;
	context.out.String("traceFailed: "); ShowOn(UsbDebug.traceFailed); context.out.Ln;
	context.out.String("traceShortPackets: "); ShowOn(UsbDebug.traceShortPackets); context.out.Ln;
	context.out.String("tracePipes: "); ShowOn(UsbDebug.tracePipes); context.out.Ln;
	context.out.String("traceCopying: "); ShowOn(UsbDebug.traceCopying); context.out.Ln;
	context.out.String("traceIoc: "); ShowOn(UsbDebug.traceIoc); context.out.Ln;
	context.out.String("traceInit: "); ShowOn(UsbDebug.traceInit); context.out.Ln;
	context.out.String("traceInterrupts: "); ShowOn(UsbDebug.traceInterrupts); context.out.Ln;
	context.out.String("traceQueuing: "); ShowOn(UsbDebug.traceQueuing); context.out.Ln;
	context.out.String("traceHubRequests: "); ShowOn(UsbDebug.traceHubRequests); context.out.Ln;
	context.out.String("traceSuspend: "); ShowOn(UsbDebug.traceSuspend); context.out.Ln;
	context.out.String("traceConnects: "); ShowOn(UsbDebug.traceConnects); context.out.Ln;
	context.out.String("traceInfo: "); ShowOn(UsbDebug.traceInfo); context.out.Ln;
	context.out.String("traceSensing: "); ShowOn(UsbDebug.traceSensing); context.out.Ln;
	context.out.String("traceScRequests: "); ShowOn(UsbDebug.traceScRequests); context.out.Ln;
	context.out.String("traceScTransfers: "); ShowOn(UsbDebug.traceScTransfers); context.out.Ln;
	context.out.String("traceCSWs: "); ShowOn(UsbDebug.traceCSWs); context.out.Ln;
	context.out.String("traceCBWs: "); ShowOn(UsbDebug.traceCBWs); context.out.Ln;
	context.out.String("traceScInit: "); ShowOn(UsbDebug.traceScInit); context.out.Ln;
	context.out.String("traceCustom: "); ShowOn(UsbDebug.traceCustom); context.out.Ln;
END TraceShow;

PROCEDURE TraceOn*(context : Commands.Context);
BEGIN
	IF UsbDebug.Trace THEN
		TraceOnOff(context, TRUE);
	ELSE
		context.out.String("UsbInfo: UsbDebug.Trace is FALSE... cannot use tracing."); context.out.Ln;
	END;
END TraceOn;

PROCEDURE TraceOff*(context : Commands.Context);
BEGIN
	TraceOnOff(context, FALSE);
END TraceOff;

PROCEDURE TraceOnOff(context : Commands.Context; on : BOOLEAN);
VAR pstr : ARRAY 32 OF CHAR; invalid : BOOLEAN;
BEGIN
	WHILE 	context.arg.GetString(pstr) DO
		 invalid := FALSE;
		IF Strings.Match("Dm", pstr) THEN UsbDebug.traceDm := on;
		ELSIF Strings.Match("Parsing", pstr) THEN UsbDebug.traceParsing := on;
		ELSIF Strings.Match("DeviceStates", pstr) THEN UsbDebug.traceDeviceStates := on;
		ELSIF Strings.Match("Control", pstr) THEN UsbDebug.traceControl := on;
		ELSIF Strings.Match("ControlData", pstr) THEN UsbDebug.traceControlData := on;
		ELSIF Strings.Match("Transfers", pstr) THEN UsbDebug.traceTransfers := on;
		ELSIF Strings.Match("Failed", pstr) THEN UsbDebug.traceFailed := on;
		ELSIF Strings.Match("ShortPackets", pstr) THEN UsbDebug.traceShortPackets := on;
		ELSIF Strings.Match("Pipes", pstr) THEN UsbDebug.tracePipes := on;
		ELSIF Strings.Match("Copying", pstr) THEN UsbDebug.traceCopying := on;
		ELSIF Strings.Match("Ioc", pstr) THEN UsbDebug.traceIoc := on;
		ELSIF Strings.Match("Init", pstr) THEN UsbDebug.traceInit := on;
		ELSIF Strings.Match("Interrupts", pstr) THEN UsbDebug.traceInterrupts := on;
		ELSIF Strings.Match("Queuing", pstr) THEN UsbDebug.traceQueuing := on;
		ELSIF Strings.Match("HubRequests", pstr) THEN UsbDebug.traceHubRequests := on;
		ELSIF Strings.Match("Suspend", pstr) THEN UsbDebug.traceSuspend := on;
		ELSIF Strings.Match("Connects", pstr) THEN UsbDebug.traceConnects := on;
		ELSIF Strings.Match("Info", pstr) THEN UsbDebug.traceInfo := on;
		ELSIF Strings.Match("Sensing", pstr) THEN UsbDebug.traceSensing := on;
		ELSIF Strings.Match("ScRequests", pstr) THEN UsbDebug.traceScRequests := on;
		ELSIF Strings.Match("ScTransfers", pstr) THEN UsbDebug.traceScTransfers := on;
		ELSIF Strings.Match("CSWs", pstr) THEN UsbDebug.traceCSWs := on;
		ELSIF Strings.Match("CBWs", pstr) THEN UsbDebug.traceCBWs := on;
		ELSIF Strings.Match("ScInit", pstr) THEN UsbDebug.traceScInit := on;
		ELSIF Strings.Match("Custom", pstr) THEN UsbDebug.traceCustom := on;
		ELSE
			context.error.String("Trace option '"); context.error.String(pstr); context.error.String("' not known."); context.error.Ln;
			invalid := TRUE;
		END;
		IF ~invalid THEN
			context.out.String("Trace option '"); context.out.String(pstr); context.out.String("' turned ");
			IF on THEN context.out.String("on."); ELSE context.out.String("off."); END;
		END;
		context.out.Ln;
	END;
END TraceOnOff;

END UsbInfo.

UsbInfo.Open ~
UsbInfo.Show ~
UsbInfo.Show details ~
UsbInfo.ShowDrivers ~
UsbInfo.ShowHc ~
UsbInfo.ShowHc details ~

SystemTools.Free UsbInfo ~