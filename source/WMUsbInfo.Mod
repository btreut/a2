MODULE WMUsbInfo; (** AUTHOR "staubesv"; PURPOSE "USB topology info (GUI)"; *)
(**
 * This Module doesn't add any functionality to the USB system software. Its purpose is to represent the current state of
 * the USB system software.
 *
 * Usage:
 *
 *	WMUsbInfo.Open ~ to start application
 *	SystemTools.Free WMUsbInfo ~ to unload it
 *
 * History:
 *
 *	20.11.2005	First release (staubesv)
 *	12.12.2005	Fixed HID class, subclass & protocol indication / BCD representation (staubesv)
 *	06.01.2006	Display VendorID, ProductID & Unknown descriptor type in Hexadecimal instead of decimal, add HID descriptor (staubesv)
 *	13.03.2006	Fixed Window.AddDeviceDescriptor so it also shows the maxPacketSize0 field (staubesv)
 *	21.03.2006	Made window restorable, don't keep reference to window when it's closed so the GC can collect it (staubesv)
 *	28.06.2006	Adapted to modified procedure Usb.GetRootHubs (staubesv)
 *	27.07.2006	Poll for events instead of being notified (staubesv)
 *)

IMPORT
	SYSTEM,
	KernelLog, Strings, Streams, Modules, Kernel, Plugins, Codecs, Machine,
	Usbdi, Usb, UsbHcdi,
	WMTabComponents, WMComponents, WMStandardComponents, WMWindowManager, WMTrees, WMGraphics, WMRestorable, WMMessages;

CONST
	(* Initial window size *)
	WindowWidth = 700;
	WindowHeight = 400;

	WriterSize = 1024; (* Default size of StringWriters *)

	Debug = TRUE;

	(* This file contains a list of assigned USB vendor IDs. Can be get from www.usb.org *)
	VendorIdFile = "WMUsbInfo.tar://usb.if";

	ShowIcons = TRUE;

	(* How often show the tool poll for changes? *)
	PollInterval = 200; (* ms *)

	(* Video Modes *)
	VmStandard = 0; (* Show devices connected to USB *)
	VmDetailed = 1; (* Show devices connected to USB and all their descriptors *)
	VmPortStatus = 2; (* Show the port status of all ports *)
	VmDrivers = 3; (* Show all registered USB device drivers and their instances *)

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	(* View mode data for Tab's *)
	Mode = POINTER TO RECORD;
		mode : LONGINT;
	END;

	Driver = POINTER TO RECORD;
		driver : Usbdi.Driver;
		interface : LONGINT;
		next : Driver;
	END;

	(* Graphical user interface *)
	Window = OBJECT (WMComponents.FormWindow)
	VAR
		(* Tree showing the USB topology *)
		usbTree : WMTrees.Tree;
		usbTreeView : WMTrees.TreeView;
		usbSelected : WMTrees.TreeNode;
		drivers : Driver; (* associated to usbSelected *)

		(* Tree showing the registered USB device drivers and their instances *)
		drvTree : WMTrees.Tree;
		drvTreeView : WMTrees.TreeView;

		mainpanel, buttonpanel, treepanel, driverpanel : WMStandardComponents.Panel;
		btnRefresh, btnProperties : WMStandardComponents.Button;

		tabs : WMTabComponents.Tabs;

		infoline : WMStandardComponents.Label;

		viewmode : LONGINT;

		string : ARRAY WriterSize OF CHAR;

		lastNbrOfDriverEvents, lastNbrOfTopologyEvents : LONGINT;

		(* Active object control *)
		dead, alive  : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE AddDeviceDescriptor(d : Usb.DeviceDescriptor; CONST nname: ARRAY OF CHAR; parent : WMTrees.TreeNode; isQualifier : BOOLEAN);
		VAR dn, tn : WMTrees.TreeNode; w : Streams.StringWriter; i : LONGINT; vendor, class, subclass, protocol : Strings.String;
		BEGIN
			NEW(dn); NEW(w, WriterSize);
			AddUsbNode(dn, parent, nname);

			GetDeviceDescription(d.bDeviceClass, d.bDeviceSubClass, d.bDeviceProtocol, class, subclass, protocol);
			vendor := GetVendorString(d.idVendor);

			i := 0;
			LOOP
				NEW(tn); w.Reset;
				CASE i OF
					0: w.String("USB Version: "); w.Hex(LSH(d.bcdUSB, -8) MOD 10H, -2); w.Char("."); w.Hex(d.bcdUSB MOD 10H, -2);
					|1: w.String("Class: "); w.Hex(d.bDeviceClass, -2); w.Char("H");
						IF class # NIL THEN w. String(" ("); w.String(class^); w.Char(")"); END;
					|2: w.String("SubClass: "); w.Hex(d.bDeviceSubClass, -2); w.Char("H");
						IF subclass # NIL THEN w. String(" ("); w.String(subclass^); w.Char(")"); END;
					|3: w.String("Protocoll: "); w.Hex(d.bDeviceProtocol, -2); w.Char("H");
						IF protocol # NIL THEN w. String(" ("); w.String(protocol^); w.Char(")"); END;
					|4: w.String("idVendor: "); w.Hex(LSH(d.idVendor, -8) MOD 100H, -2); w.Hex(d.idVendor MOD 100H, -2); w.Char("H");
						IF vendor # NIL THEN w.String(" ("); w.String(vendor^); w.Char(")"); END;
					|5: w.String("idProduct: "); w.Hex(LSH(d.idProduct, -8) MOD 100H, -2); w.Hex(d.idProduct MOD 100H, -2); w.Char("H");
					|6: w.String("Device Version: "); w.Hex(LSH(d.bcdDevice, -8) MOD 10H, -2); w.Char("."); w.Hex(d.bcdDevice MOD 10H, -2);
					|7: w.String("NumConfigurations: "); w.Int(d.bNumConfigurations, 0);
					|8: w.String("iManufacturer: "); w.Int(d.iManufacturer, 0); w.String(" (");
					      IF d.iManufacturer = 0 THEN w.String("No string descriptor)");
					      ELSIF d.sManufacturer # NIL THEN w.String(d.sManufacturer^); w.Char(")");
					      ELSE w.String("Not parsed)");
					      END;
					|9: w.String("iProduct: "); w.Int(d.iProduct, 0); w.String(" (");
					      IF d.iProduct = 0 THEN w.String("No string descriptor)");
					      ELSIF d.sProduct # NIL THEN w.String(d.sProduct^); w.Char(")");
					      ELSE w.String("Not parsed)");
					      END;
			      		|10: w.String("iSerial: "); w.Int(d.iSerialNumber, 0); w.String(" (");
					      IF d.iSerialNumber = 0 THEN w.String("No string descriptor)");
					      ELSIF d.sSerialNumber # NIL THEN w.String(d.sSerialNumber^); w.Char(")");
					      ELSE w.String("Not parsed)");
					      END;
					|11: w.String("MaxPacketSize0: "); w.Int(d.bMaxPacketSize0, 0); w.String(" Bytes");
				END;
				w.Get(string); AddUsbNode(tn, dn, string);
				INC(i); IF (i > 11) OR (isQualifier & (i > 7)) THEN EXIT; END;
			END;
		END AddDeviceDescriptor;

		PROCEDURE AddIad(iads : Usbdi.Iads; parent : WMTrees.TreeNode);
		VAR dn, tn, in : WMTrees.TreeNode; w : Streams.StringWriter; c, s, p : Strings.String; j, k : LONGINT; i : Usb.InterfaceAssociationDescriptor;
		BEGIN
			NEW(dn); NEW(w, WriterSize);
			AddUsbNode(dn, parent, "Interface Association Descriptors");

			FOR k := 0 TO LEN(iads)-1 DO

				NEW(in);
				w.Reset; w.String("Interface Associtation Descriptor "); w.Int(k, 0); w.Get(string);
				AddUsbNode(in, dn, string);

				i := iads[k] (Usb.InterfaceAssociationDescriptor) ;
				GetIadDescription(i.bFunctionClass, i.bFunctionSubClass, i.bFunctionProtocol, c, s, p);

				FOR j := 0 TO 5 DO
					NEW(tn); w.Reset;
					CASE j OF
						0: w.String("bFirstInterface: "); w.Int(i.bFirstInterface, 0);
						|1: w.String("bInterfaceCount: "); w.Int(i.bInterfaceCount, 0);
						|2: w.String("bFunctionClass: "); w.Int(i.bFunctionClass, 0);
							IF c # NIL THEN w.String(" ("); w.String(c^); w.String(")"); END;
						|3: w.String("bFunctionSubClass: "); w.Int(i.bFunctionSubClass, 0);
							IF s # NIL THEN w.String(" ("); w.String(s^); w.String(")"); END;
						|4: w.String("bFunctionProtocol: "); w.Int(i.bFunctionProtocol, 0);
							IF p # NIL THEN w.String(" ("); w.String(p^); w.String(")"); END;
						|5: w.String("iFunction: "); w.Int(i.iFunction, 0); w.String(" (");
						      IF i.iFunction = 0 THEN w.String("No string descriptor)");
						      ELSIF i.sFunction # NIL THEN w.String(i.sFunction^); w.Char(")");
						      ELSE w.String("Not parsed)");
						      END;
					END;
					w.Get(string); AddUsbNode(tn, in, string);
				END;
			END;
		END AddIad;

		PROCEDURE AddNonStandard(u : Usbdi.UnknownDescriptor ; intf : Usbdi.InterfaceDescriptor; parent : WMTrees.TreeNode);
		VAR dn, tn : WMTrees.TreeNode; w : Streams.StringWriter;
		BEGIN
			IF u = NIL THEN (* No non-standard descriptors *) RETURN; END;

			NEW(dn); NEW(w, WriterSize);
			AddUsbNode(dn, parent, "Non-Standard Descriptors");

			WHILE(u # NIL) DO
				IF intf.bInterfaceClass = 0EH THEN (* Video Device Class-Specific Descriptor *)
					AddVideoClass(u, intf, dn);
				ELSIF intf.bInterfaceClass = 03H THEN (* HID device class-specific descriptor *)
					AddHidClass(u, intf, dn);
				ELSE
					NEW(tn); w.Reset;
					 w.String("Non-Standard Descriptor (Type: "); w.Hex(u.bDescriptorType, -2); w.Char("H");
					 w.String(", Length: "); w.Int(u.bLength, 0); w.String(")");
					 w.Get(string); AddUsbNode(tn, dn, string);
					 AddDescriptorData(u.descriptor^, dn);
				END;
				u := u.next;
			END;
		END AddNonStandard;

		PROCEDURE AddDescriptorData(CONST data: ARRAY OF CHAR; parent : WMTrees.TreeNode);
		VAR n : WMTrees.TreeNode; i : LONGINT; w : Streams.StringWriter;
		BEGIN
			NEW(n); NEW(w, WriterSize);
			w.String("Data: ");
			FOR i := 0 TO LEN(data)-1 DO
				w.Hex(ORD(data[i]), -2); w.Char(" ");
			END;
			w.Get(string); AddUsbNode(n, parent, string);
		END AddDescriptorData;

		(* Add HID class-specific descriptor *)
		PROCEDURE AddHidClass(u : Usbdi.UnknownDescriptor; intf : Usbdi.InterfaceDescriptor; parent : WMTrees.TreeNode);
		VAR w : Streams.StringWriter;  cl, n, dn : WMTrees.TreeNode; i : LONGINT;

			PROCEDURE AddDescriptorType(type : LONGINT; w : Streams.StringWriter);
			BEGIN
				CASE type OF
					21H: 	w.String("(HID Descriptor)");
					|22H:	w.String("(Report Descriptor)");
					|23H: 	w.String("(Physical Descriptor)");
				ELSE
					w.String("(Unknown)");
				END;
			END AddDescriptorType;

			PROCEDURE AddClassDescriptor(offset : LONGINT);
			BEGIN
				NEW(n); w.Reset;
				w.String("bDescriptorType: "); w.Hex(ORD(u.descriptor[offset]), -2); w.String("H ");
				AddDescriptorType(ORD(u.descriptor[offset]), w);
				w.String(", bDescriptorLength: ");
				w.Int(ORD(u.descriptor[offset + 1]) + 10H*ORD(u.descriptor[offset + 2]), 0); w.String(" Bytes");
				w.Get(string); AddUsbNode(n, cl, string);
			END AddClassDescriptor;

		BEGIN
			NEW(dn); NEW(w, WriterSize);
			AddUsbNode(dn, parent, "HID class-specific descriptor");

			IF u.bLength >= 9 THEN
				i := 0;
				LOOP
					NEW(n); w.Reset;
					CASE i OF
						0: 	w.String("HID Class Specification Release: ");
							w.Hex(ORD(u.descriptor[3]), -2); w.Char("."); w.Hex(ORD(u.descriptor[2]), -2);
						|1:	w.String("Country Code: "); w.Int(ORD(u.descriptor[4]), 0);
							IF ORD(u.descriptor[4]) = 0 THEN w.String(" (Not Supported)"); END;
						|2:	w.String("bNumDescriptors: "); w.Int(ORD(u.descriptor[5]), 0);
					END;
					INC(i);
					w.Get(string); AddUsbNode(n, dn, string);
					IF i > 2 THEN EXIT; END;
				END;

				NEW(cl); AddUsbNode(cl, dn, "Class Descriptors");
				i := 6;
				LOOP
					AddClassDescriptor(i); INC(i, 3);
					IF i >= LEN(u.descriptor) - 3 THEN EXIT; END;
				END;
			ELSE
				NEW(n); w.Reset; w.String("Parse Error: Descriptor < 9 Bytes"); w.Get(string);
				AddUsbNode(n, dn, string);
			END;
		END AddHidClass;

		(* Show USB Video Device Class-Specific descriptors *)
		PROCEDURE AddVideoClass(u : Usbdi.UnknownDescriptor; intf : Usbdi.InterfaceDescriptor;  parent : WMTrees.TreeNode);
		VAR subtype : LONGINT; v, w : Streams.StringWriter; tn, n : WMTrees.TreeNode;

			PROCEDURE AddVCHeader(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; i : LONGINT; w : Streams.StringWriter;
			BEGIN
				ASSERT(LEN(u.descriptor) >= 12);
				NEW(w, WriterSize);
				FOR i := 1 TO 4 DO
					NEW(n); w.Reset;
					CASE i OF
						1: w.String("bcdVDC: "); w.Hex(ORD(u.descriptor[4]), -2); w.Char("."); w.Hex(ORD(u.descriptor[3]), -2);
						|2: w.String("wTotalLength: "); w.Int(ORD(u.descriptor[5]) + 100H*ORD(u.descriptor[6]), 0);
						|3: w.String("dwClockFrequency: ");
							w.Int(ORD(u.descriptor[7]) + 100H*ORD(u.descriptor[8]) + 10000H*ORD(u.descriptor[9])
							 +1000000H*ORD(u.descriptor[10]), 0); w.String(" Hz");
						|4: w.String("bInCollection: "); w.Int(ORD(u.descriptor[11]), 0);
					END;
					w.Get(string); AddUsbNode(n, parent, string);
				END;
				FOR i := 12 TO LEN(u.descriptor)-1 DO
					NEW(n); w.Reset;
					w.String("baInterfaceNr("); w.Int(i-11, 0); w.String("): ");
					w.Int(ORD(u.descriptor[i]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
				END;
			END AddVCHeader;

			PROCEDURE AddTerminal(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; i, subtype : LONGINT; w : Streams.StringWriter;
			BEGIN
				NEW(w, WriterSize);
				(* Common fields of all terminal descriptors *)
				FOR i := 1 TO 3 DO
					NEW(n); w.Reset;
					CASE i OF
						1: w.String("bTerminalID: "); w.Int(ORD(u.descriptor[3]), 0);
						|2: w.String("wTerminalType: "); subtype := ORD(u.descriptor[4]) + 100H*ORD(u.descriptor[5]);
							w.Int(subtype, 0); w.String(" (");
							IF subtype = 100H THEN w.String("Vendor-Specific Terminal)");
							ELSIF subtype = 101H THEN w.String("Streaming Terminal)");
							ELSIF subtype = 200H THEN w.String("Vendor-Specific Input Terminal)");
							ELSIF subtype = 201H THEN w.String("Camera Input Terminal)");
							ELSIF subtype = 202H THEN w.String("Media Transport Inpurt Terminal)");
							ELSIF subtype = 300H THEN w.String("Vendor-Specific Output Terminal)");
							ELSIF subtype = 301H THEN w.String("Display Output Terminal)");
							ELSIF subtype = 302H THEN w.String("Media Transport Output Terminal)");
							ELSIF subtype = 400H THEN w.String("Vendor-Specific External Terminal)");
							ELSIF subtype = 401H THEN w.String("Composite Connector)");
							ELSIF subtype = 402H THEN w.String("S-Video Connector)");
							ELSIF subtype = 403H THEN w.String("Component Connector)");
							ELSE
								w.String("Unknown Terminal Type)");
							END;
						|3: w.String("bAssocTerminal: "); w.Int(ORD(u.descriptor[6]), 0);
					END;
					w.Get(string); AddUsbNode(n, parent, string);
				END;
				NEW(n); w.Reset;
				subtype := ORD(u.descriptor[2]);
				IF subtype = 02H THEN (* Input Terminal *)
					w.String("iTerminal: "); w.Int(ORD(u.descriptor[7]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
				ELSIF subtype = 03H THEN (* Output Terminal *)
					w.String("bSourceID: "); w.Int(ORD(u.descriptor[8]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
					NEW(n); w.Reset;
					w.String("iTerminal: "); w.Int(ORD(u.descriptor[8]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
				END;
				AddDescriptorData(u.descriptor^, parent);
			END AddTerminal;

			(* Common fields of unit descriptors *)
			PROCEDURE AddUnit(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; i, j, subtype : LONGINT; w : Streams.StringWriter;
			BEGIN
				NEW(n); NEW(w, WriterSize);
				w.String("bUnitID: "); w.Int(ORD(u.descriptor[3]), 0);
				w.Get(string); AddUsbNode(n, parent, string);

				subtype := ORD(u.descriptor[2]);
				IF subtype = 4 THEN (* Selector Unit *)
					NEW(n); w.Reset;
					w.String("bNrInPins: "); w.Int(ORD(u.descriptor[4]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
					FOR i := 5 TO LEN(u.descriptor)-2 DO
						NEW(n); w.Reset;
						w.String("baSourceID("); w.Int(i-4, 0); w.String("): "); w.Int(ORD(u.descriptor[i]), 0);
						w.Get(string); AddUsbNode(n, parent, string);
					END;
					NEW(n); w.Reset;
					w.String("iSelector: "); w.Int(ORD(u.descriptor[LEN(u.descriptor)-1]), 0);
					w.Get(string); AddUsbNode(n, parent, string);
				ELSIF subtype = 6 THEN (* Extension Unit *)
					FOR i := 1 TO 7 DO
						NEW(n); w.Reset;
						CASE i OF
							1: w.String("guidExtensionCode: ");
							    FOR j := 0 TO 15 DO w.Hex(ORD(u.descriptor[4+j]), -2); w.Char(" "); END;
							|2: w.String("bNumControls: "); w.Int(ORD(u.descriptor[20]), 0);
							|3: w.String("bNrInPins: "); w.Int(ORD(u.descriptor[21]), 0);
							|4: FOR j := 0 TO ORD(u.descriptor[21])-1 DO
									w.String("baSourceID("); w.Int(j+1, 0); w.String("): "); w.Int(ORD(u.descriptor[22+j]), 0);
								END;
							|5: w.String("bControlSize: "); w.Int(ORD(u.descriptor[22 + ORD(u.descriptor[21])]), 0);
							|6: FOR j := 0 TO ORD(u.descriptor[22 + ORD(u.descriptor[21])])-1 DO
									w.String("bmControls("); w.Int(j+1, 0); w.String("): ");
									w.Int(ORD(u.descriptor[23 +  ORD(u.descriptor[21])]), 0);
								END;
							|7: w.String("iExtension: "); w.Int(ORD(u.descriptor[LEN(u.descriptor)-1]), 0);
						END;
						w.Get(string); AddUsbNode(n, parent, string);
					END;
				ELSE
					AddDescriptorData(u.descriptor^, parent);
				END;

			END AddUnit;

			PROCEDURE AddOutputHeader(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; i  : LONGINT; w : Streams.StringWriter;
			BEGIN
				NEW(w, WriterSize);
				FOR i := 1 TO 4 DO
					NEW(n); w.Reset;
					CASE i OF
						1: w.String("bNumFormats: "); w.Int(ORD(u.descriptor[3]), 0);
						|2: w.String("wTotalLength: "); w.Int(ORD(u.descriptor[4]) + 100H*ORD(u.descriptor[5]), 0);
						|3: w.String("bEndpointAddress: "); w.Int(ORD(u.descriptor[6]), 0);
						|4: w.String("bTerminalLink: "); w.Int(ORD(u.descriptor[7]), 0);
					END;
					w.Get(string); AddUsbNode(n, parent, string);
				END;
			END AddOutputHeader;

			PROCEDURE AddInputHeader(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; i, temp  : LONGINT; w : Streams.StringWriter;
			BEGIN
				NEW(w, WriterSize);
				FOR i := 1 TO 9 DO
					NEW(n); w.Reset;
					CASE i OF
						1: w.String("bNumFormats: "); w.Int(ORD(u.descriptor[3]), 0);
						|2: w.String("wTotalLength: "); w.Int(ORD(u.descriptor[4]) + 100H*ORD(u.descriptor[5]), 0);
						|3: w.String("bEndpointAddress: "); w.Int(ORD(u.descriptor[6]), 0);
						|4: w.String("bmInfo: "); w.Int(ORD(u.descriptor[7]), 0);
						|5: w.String("bTerminalLink: "); w.Int(ORD(u.descriptor[8]), 0);
						|6: w.String("bStillCaptureMethod: "); temp := ORD(u.descriptor[9]); w.Int(temp, 0);
							IF temp = 0 THEN w.String(" (None)");
							ELSIF temp = 1 THEN w.String(" (Method 1)");
							ELSIF temp = 2 THEN w.String(" (Method 2)");
							ELSIF temp = 3 THEN w.String(" (Method 3)");
							ELSE w.String(" (Unknown)");
							END;
						|7: w.String("bTriggerSupport: "); temp := ORD(u.descriptor[10]); w.Int(temp, 0);
							IF temp = 0 THEN w.String(" (Not supported)");
							ELSIF temp = 1 THEN w.String(" (Supported)");
							ELSE w.String(" (Unknown)");
							END;
						|8: w.String("bTriggerUsage: "); temp :=ORD(u.descriptor[11]);  w.Int(temp, 0);
							IF ORD(u.descriptor[10]) = 0 THEN w.String(" (No Trigger Support)");
							ELSIF temp = 0 THEN w.String(" (Initiate Still Image Captue)");
							ELSIF temp = 1 THEN w.String(" (General Purpose Button Event)");
							ELSE w.String(" (Unknown)");
							END;
						|9: w.String("bControlSize: "); w.Int(ORD(u.descriptor[12]), 0);
					END;
					w.Get(string); AddUsbNode(n, parent, string);
				END;
				FOR i := 13 TO LEN(u.descriptor)-1 DO
					NEW(n); w.Reset;
					w.String("bmaControls("); w.Int(i-12, 0); w.String("): "); w.Set(SYSTEM.VAL(SET, u.descriptor[i]));
					w.Get(string); AddUsbNode(n, parent, string);
				END;
			END AddInputHeader;

			PROCEDURE AddVcInterruptEp(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR wMaxTransferSize : LONGINT; n : WMTrees.TreeNode; w : Streams.StringWriter;
			BEGIN
				NEW(n); NEW(w, WriterSize);
				IF (LEN(u.descriptor) = 5) THEN
					wMaxTransferSize := ORD(u.descriptor[3]) + 100H*ORD(u.descriptor[4]);
					w.String("wMaxTransferSize: "); w.Int(wMaxTransferSize, 0);
				ELSE
					w.String("Parse Error (Length#5)");
				END;
				w.Get(string); AddUsbNode(n, parent, string);
			END AddVcInterruptEp;

			PROCEDURE AddLength(u : Usbdi.UnknownDescriptor; parent : WMTrees.TreeNode);
			VAR n : WMTrees.TreeNode; w : Streams.StringWriter;
			BEGIN
				NEW(n); NEW(w, WriterSize);
				w.String("bLength: "); w.Int(u.bLength, 0); w.String(" Bytes");
				w.Get(string); AddUsbNode(n, parent, string);
			END AddLength;

		BEGIN
			NEW(tn); NEW(w, WriterSize); NEW(v, WriterSize);
			w.String("Video Class-Specific ");

			IF u.bDescriptorType = 020H THEN
				w.String("Undefined Descriptor"); AddLength(u, tn); AddDescriptorData(u.descriptor^, tn);
			ELSIF u.bDescriptorType = 021H THEN
				w.String("Device Descriptor"); AddLength(u, tn); AddDescriptorData(u.descriptor^, tn);
			ELSIF u.bDescriptorType = 022H THEN
				w.String("Configuration Descriptor"); AddLength(u, tn); AddDescriptorData(u.descriptor^, tn);
			ELSIF u.bDescriptorType = 023H THEN
				w.String("String Descriptor"); AddLength(u, tn); AddDescriptorData(u.descriptor^, tn);
			ELSIF u.bDescriptorType = 024H THEN
				subtype := ORD(u.descriptor[2]);
				IF intf.bInterfaceSubClass = 01H THEN
					w.String("Video Control Interface Descriptor: "); AddLength(u, tn);
					CASE subtype OF
						0: w.String("Undefined Descriptor"); AddDescriptorData(u.descriptor^, tn);
						|1: w.String("VC Header"); AddVCHeader(u, tn);
						|2: w.String("VC Input Terminal"); AddTerminal(u, tn);
						|3: w.String( "VC Output Terminal"); AddTerminal(u, tn);
						|4: w.String( "VC Selector Unit"); AddUnit(u, tn);
						|5: w.String( "VC Processing Unit"); AddUnit(u, tn);
						|6: w.String("VC Extension Unit"); AddUnit(u, tn);
					ELSE
						w.String("Unknown");
						v.String("Unknown (Type: "); v.Int(u.bDescriptorType, 0); v.String(", Length: "); v.Int(u.bLength, 0); v.String(")");
						v.Get(string); AddUsbNode(n, tn, string);
						AddDescriptorData(u.descriptor^, tn);
					END;
				ELSIF intf.bInterfaceSubClass = 02H THEN
					w.String("Video Streaming Interface Descriptor: "); AddLength(u, tn);
					CASE subtype OF
						0: w.String("Undefined Descriptor");
						|1: w.String("VS Input Header"); AddInputHeader(u, tn);
						|2: w.String("VS Output Header"); AddOutputHeader(u, tn);
						|3: w.String("VS Still Image Frame"); AddDescriptorData(u.descriptor^, tn);
						|4: w.String("VS Format Uncompressed"); AddDescriptorData(u.descriptor^, tn);
						|5: w.String("VS Frame Uncompressed"); AddDescriptorData(u.descriptor^, tn);
						|6: w.String("VS Format MJPEG"); AddDescriptorData(u.descriptor^, tn);
						|7: w.String("VS Frame MJPEG"); AddDescriptorData(u.descriptor^, tn);
						|8: w.String("VS Format MPEG1"); AddDescriptorData(u.descriptor^, tn);
						|9: w.String("VS Format MPEG2 PS"); AddDescriptorData(u.descriptor^, tn);
						|10: w.String("VS Format MPEG2 TS"); AddDescriptorData(u.descriptor^, tn);
						|11: w.String("VS Format MPEG4 SL"); AddDescriptorData(u.descriptor^, tn);
						|12: w.String("VS Format DV"); AddDescriptorData(u.descriptor^, tn);
						|13: w.String("VS Color Format"); AddDescriptorData(u.descriptor^, tn);
						|14: w.String("VS Format Vendor"); AddDescriptorData(u.descriptor^, tn);
						|15: w.String("VS Frame Vendor"); AddDescriptorData(u.descriptor^, tn);
					ELSE
						w.String("Unknown");
						v.String("Unknown (Type: "); v.Int(u.bDescriptorType, 0); v.String(", Length: "); v.Int(u.bLength, 0); v.String(")");
						v.Get(string); AddUsbNode(n, tn, string);
						AddDescriptorData(u.descriptor^, tn);
					END;
				ELSE
					w.String("Undefined Interface Descriptor"); AddLength(u, tn); AddDescriptorData(u.descriptor^, tn);
				END;
			ELSIF u.bDescriptorType = 025H THEN
				subtype := ORD(u.descriptor[2]);
				w.String("Endpoint Descriptor");	AddLength(u, tn);
				NEW(n);
				CASE subtype OF
					0: AddUsbNode(n, tn, "Endpoint Undefined"); AddDescriptorData(u.descriptor^, tn);
					|1: AddUsbNode(n, tn, "Endpoint General"); AddDescriptorData(u.descriptor^, tn);
					|2: AddUsbNode(n, tn, "Endpoint"); AddDescriptorData(u.descriptor^, tn);
					|3: AddUsbNode(n, tn, "Endpoint Interrupt"); AddVcInterruptEp(u, tn);
				ELSE
					v.String("Unknown (Type: "); v.Int(u.bDescriptorType, 0); v.String(", Length: "); v.Int(u.bLength, 0); v.String(")");
					v.Get(string); AddUsbNode(n, tn, string);
					AddDescriptorData(u.descriptor^, tn);
				END;
			ELSE
			END;
			w.Get(string); AddUsbNode(tn, parent, string);
		END AddVideoClass;

		PROCEDURE AddConfiguration(c :  Usb.ConfigurationDescriptor; nbr: ADDRESS; parent : WMTrees.TreeNode);
		VAR dn, tn  : WMTrees.TreeNode; w : Streams.StringWriter; i : LONGINT;
		BEGIN
			NEW(dn); NEW(w, WriterSize);
			w.String("Configuration "); w.Address(nbr); w.Get(string);

			AddUsbNode(dn, parent, string);

			IF c.iads # NIL THEN (* Show Interface Associtation Descriptors *)
				AddIad(c.iads, dn);
			END;

	(*		IF c.unknown # NIL THEN (* Show Non-Standard Descriptors *)
				AddNonStandard(c.unknown, dn);
			END; *)

			IF c.interfaces # NIL THEN (* Show interfaces *)
				FOR i := 0 TO LEN(c.interfaces)-1 DO AddInterface(c.interfaces[i] (Usb.InterfaceDescriptor), i, dn); END;
			END;

			FOR i := 0 TO 6 DO
				NEW(tn); w.Reset;
				CASE i OF
					0: w.String("bNumInterfaces: "); w.Int(c.bNumInterfaces, 0);
					|1: w.String("bConfigurationValue: "); w.Int(c.bConfigurationValue, 0);
					|2: w.String("iConfiguration: "); w.Int(c.iConfiguration, 0); w.String(" (");
					      IF c.iConfiguration = 0 THEN w.String("No string descriptor)");
					      ELSIF c.sConfiguration # NIL THEN w.String(c.sConfiguration^); w.Char(")");
					      ELSE w.String("Not parsed)");
					      END;
					|3: w.String("Max Power: "); w.Int(c.bMaxPower, 0); w.String("mA");
					|4: w.String("Total Length: "); w.Int(c.wTotalLength, 0); w.String(" Bytes");
					|5: w.String("Can be Self-Powered: "); IF c.selfPowered THEN w.String("Yes"); ELSE w.String("No"); END;
					|6: w.String("Remote Wakeup support: "); IF c.remoteWakeup THEN w.String("Yes"); ELSE w.String("No"); END;
				END;
				w.Get(string); AddUsbNode(tn, dn, string);
			END;
		END AddConfiguration;

		PROCEDURE AddInterface(i : Usb.InterfaceDescriptor; nbr : LONGINT; parent : WMTrees.TreeNode);
		VAR dn, tn, en : WMTrees.TreeNode; w : Streams.StringWriter; j : LONGINT; class, subclass, protocol : Strings.String;
		BEGIN
			NEW(dn);
			NEW(w, WriterSize);
			IF i.bAlternateSetting # 0 THEN w.String("Alternate "); END;
			w.String("Interface "); w.Int(nbr, 0); w.Get(string);

			AddUsbNode(dn, parent, string);
			GetInterfaceDescription(i.bInterfaceClass, i.bInterfaceSubClass, i.bInterfaceProtocol, class, subclass, protocol);

			IF i.unknown # NIL THEN (* Show Non-Standard Interface Descriptors *)
				AddNonStandard(i.unknown, i, dn);
			END;

			IF i.endpoints # NIL THEN (* Show endpoint information *)
				NEW(en); AddUsbNode(en, dn, "Endpoints");
				FOR j := 0 TO LEN(i.endpoints)-1 DO AddEndpoint(i.endpoints[j] (Usb.EndpointDescriptor), i , j+1, en); END;
			END;

			FOR j := 0 TO 8 DO
				NEW(tn); w.Reset;
				CASE j OF
					0: w.String("Interface Number: "); w.Int(i.bInterfaceNumber, 0);
					|1: w.String("Alternate Setting: "); w.Int(i.bAlternateSetting, 0);
					|2: w.String("Class: "); w.Hex(i.bInterfaceClass, -2); w.Char("H");
						IF class # NIL THEN w.String(" ("); w.String(class^); w.Char(")"); END;
					|3: w.String("SubClass: "); w.Hex(i.bInterfaceSubClass, -2); w.Char("H");
						IF subclass # NIL THEN w.String(" ("); w.String(subclass^); w.Char(")"); END;
					|4: w.String("Protocol: "); w.Hex(i.bInterfaceProtocol, -2); w.Char("H");
						IF protocol # NIL THEN w.String(" ("); w.String(protocol^); w.Char(")"); END;
					|5: w.String("NumAlternateInterfaces: "); w.Int(i.numAlternateInterfaces , 0);
					|6: w.String("NumEndPoints: "); w.Int(i.bNumEndpoints , 0);
					|7: w.String("iInterface: "); w.Int(i.iInterface, 0); w.String(" (");
						IF i.iInterface = 0 THEN w.String("No string descriptor)");
						ELSIF i.sInterface # NIL THEN w.String(i.sInterface^); w.Char(")");
						ELSE w.String("Not parsed)");
						END;
					|8: w.String("Driver: ");
						IF i.driver = NIL THEN w.String("No driver installed");
						ELSE
							w.String(i.driver.name); w.String(" ("); w.String(i.driver.desc); w.Char(")");
						END;
				END;
				w.Get(string); AddUsbNode(tn, dn, string);
			END;

			IF i.alternateInterfaces # NIL THEN
				FOR j := 0 TO LEN(i.alternateInterfaces)-1 DO
					AddInterface(i.alternateInterfaces[j] (Usb.InterfaceDescriptor), j, dn);
				END;
			END;
		END AddInterface;

		PROCEDURE AddEndpoint(e : Usb.EndpointDescriptor;intf : Usbdi.InterfaceDescriptor;  nbr : LONGINT; parent : WMTrees.TreeNode);
		VAR dn  : WMTrees.TreeNode; w : Streams.StringWriter; i : LONGINT;
		BEGIN
			NEW(dn); NEW(w, WriterSize);
			FOR i := 0 TO 4 DO
				CASE i OF
					0: w.String("Endpoint Number: "); w.Int(e.bEndpointAddress, 0);
					    (* Direction bit is ignored for control endpoints *)
						IF SYSTEM.VAL(SET, e.bmAttributes) * {0,1} # {} THEN (* It's not a control endpoint *)
							IF SYSTEM.VAL(SET, e.bEndpointAddress) * {7} = {} THEN w.String(" (OUT)"); ELSE w.String(" (IN)"); END;
						END;
					|1: w.String(", Type: ");
						CASE SYSTEM.VAL(LONGINT, e.bmAttributes * {0..1}) OF
							0: w.String("Control");
							|1: w.String("Isochronous");
							|2: w.String("Bulk");
							|3: w.String("Interrupt");
						END;
					|2: w.String(", MaxPacketSize: "); w.Int(e.wMaxPacketSize, 0); w.String("Bytes");
					|3: w.String(" (Mult: "); w.Int(e.mult, 0); w.String(")");
					|4: w.String(", Interval: "); w.Int(e.bInterval, 0); w.String("ms");
				END;
			END;
			IF SYSTEM.VAL(LONGINT, e.bmAttributes * {0..1}) = 1 THEN (* Isochronous endpoint *)
				w.String(" (Synchronization: ");
				CASE SYSTEM.VAL(LONGINT, LSH(e.bmAttributes * {2..3}, -2)) OF
					0: w.String("None");
					|1: w.String("Asynchronous");
					|2: w.String("Adaptive");
					|3: w.String("Synchronous");
				END;
				w.String(", Usage: ");
				CASE SYSTEM.VAL(LONGINT, LSH(e.bmAttributes * {4..5}, -4)) OF
					0: w.String("Data");
					|1: w.String("Feedback");
					|2: w.String("Implicit Feedback Data");
					|3: w.String("Reserved");
				END;
				w.Char(")");
			END;
			w.Get(string); AddUsbNode(dn, parent, string);

			IF e.unknown # NIL THEN (* Show Non-Standard Endpoint Descriptors *)
				AddNonStandard(e.unknown, intf, parent);
			END;

		END AddEndpoint;

		PROCEDURE ViewModeDetailed(dev : Usb.UsbDevice; parent : WMTrees.TreeNode; w : Streams.StringWriter);
		VAR i : ADDRESS; cn : WMTrees.TreeNode;
		BEGIN
			ASSERT((dev # NIL) & (parent # NIL) & (w # NIL) );
			ASSERT(viewmode = VmDetailed);
			IF (dev.parent = dev) THEN (* It's a root hub *)
				i := Machine.PhysicalAdr(dev.controller.iobase, 4);
				IF (i = -1) & Debug THEN KernelLog.String("UsbInfo: Address mapping error."); KernelLog.Ln; END;
				w.String(" (I/O base address: "); w.Hex(i, -8); w.String("H, Interrupt Line: ");
				w.Int(dev.controller.irq, 0); w.Char(")");
			ELSE
				w.String(" (");
				IF dev.speed = UsbHcdi.LowSpeed THEN w.String("LowSpeed");
				ELSIF dev.speed = UsbHcdi.FullSpeed THEN w.String("FullSpeed");
				ELSIF dev.speed = UsbHcdi.HighSpeed THEN w.String("HighSpeed");
				ELSE w.String("Speed unknown!");
				END;
				w.String(", Address: "); w.Int(dev.address, 0); w.Char(")");

				AddDeviceDescriptor(dev.descriptor (Usb.DeviceDescriptor), "Device Descriptor", parent, FALSE);
				IF dev.qualifier # NIL THEN
					AddDeviceDescriptor(dev.qualifier (Usb.DeviceDescriptor), "Device Qualifier", parent, TRUE);
				END;

				NEW(cn);
				AddUsbNode(cn, parent, "Configurations");
				FOR i := 0 TO LEN(dev.configurations)-1 DO
					AddConfiguration(dev.configurations[i] (Usb.ConfigurationDescriptor), i, cn);
				END;

				IF dev.otherconfigurations # NIL THEN
					NEW(cn);
					AddUsbNode(cn, parent, "Other-speed Configurations");
					FOR i := 0 TO LEN(dev.configurations)-1 DO
						AddConfiguration(dev.otherconfigurations[i] (Usb.ConfigurationDescriptor), i, cn);
					END;
				END;
			END;
		END ViewModeDetailed;

		PROCEDURE Dev2Node(dev : Usb.UsbDevice; port : LONGINT; parent : WMTrees.TreeNode);
		VAR tn, pn : WMTrees.TreeNode; w : Streams.StringWriter; i : LONGINT; deviceAttached : BOOLEAN;
			image : WMGraphics.Image;
		BEGIN
			ASSERT(dev # NIL);
			NEW(tn); NEW(w, WriterSize);

			usbTree.Acquire;
			usbTree.SetNodeData(tn, dev);
			usbTree.Release;

			IF ShowIcons THEN
				image := GetImage(dev);
				IF image # NIL THEN usbTree.Acquire; usbTree.SetNodeImage(tn, image); usbTree.Release; END;
			END;

			IF dev.parent = dev THEN w.String("Root");
			ELSE w.String("Port "); w.Int(port, 0); w.String(": ");
			END;
			IF dev.hubFlag THEN w.String("Hub with "); w.Int(dev.nbrOfPorts, 0); w.String(" ports: "); END;

			IF ((dev.descriptor(Usb.DeviceDescriptor).sManufacturer # NIL) OR (dev.descriptor(Usb.DeviceDescriptor).sProduct # NIL)) THEN
				IF dev.descriptor(Usb.DeviceDescriptor).sManufacturer # NIL THEN w.String(dev.descriptor(Usb.DeviceDescriptor).sManufacturer^); w.Char(" "); END;
				IF dev.descriptor(Usb.DeviceDescriptor).sProduct # NIL THEN w.String(dev.descriptor(Usb.DeviceDescriptor).sProduct^); END;
			ELSE
				w.String("Unnamed device");
			END;

			IF viewmode = VmDetailed THEN ViewModeDetailed(dev, tn, w); END;

			w.Get(string);
			AddUsbNode(tn, parent, string);
			usbTree.Acquire; usbTree.ExpandToRoot(tn); usbTree.Release;

			IF dev.hubFlag THEN
				pn := tn;
				deviceAttached := FALSE;
				FOR i := 0 TO dev.nbrOfPorts-1 DO
					IF dev.deviceAtPort[i] # NIL THEN
						Dev2Node(dev.deviceAtPort[i], i+1,  pn);
						deviceAttached := TRUE;
					END;
				END;
				IF ~deviceAttached THEN
					NEW(tn);
					AddUsbNode(tn, pn, "No devices attached");
				END;
			END;
		END Dev2Node;

		PROCEDURE BuildTree;
		VAR i : LONGINT; tn, node : WMTrees.TreeNode; rootHubs : Usb.RootHubArray;
		BEGIN
			usbTreeView.visible.Set(FALSE);
			usbTree.Acquire;
			NEW(tn);
			usbTree.SetRoot(tn);
			usbTree.SetNodeCaption(tn, Strings.NewString("Universal Serial Bus(ses)"));
			usbTree.Release;

			Usb.GetRootHubs(rootHubs);
			IF rootHubs # NIL THEN
				FOR i := 0 TO LEN(rootHubs)-1 DO
					Dev2Node(rootHubs[i], i+1, tn);
					rootHubs[i] := NIL;
				END;
			ELSE
				NEW(node);
				AddUsbNode(node, tn, "No USB host controller drivers installed");
				usbTree.Acquire; usbTree.ExpandToRoot(node); usbTree.Release;
			END;
			usbTreeView.visible.Set(TRUE);
		END BuildTree;

		PROCEDURE BuildDrivers;
		VAR i, j : LONGINT; tn, node, n : WMTrees.TreeNode;
			drivers : POINTER TO ARRAY OF Usb.RegisteredDriver; driverFound : BOOLEAN;
			drv : Usb.RegisteredDriver; plugin : Plugins.Plugin;
			w : Streams.StringWriter; dev : Usb.UsbDevice;
		BEGIN
			drvTreeView.visible.Set(FALSE);
			drvTree.Acquire;
			NEW(tn);
			drvTree.SetRoot(tn);
			drvTree.SetNodeCaption(tn, Strings.NewString("Registered USB device drivers"));
			drvTree.Release;

			NEW(drivers, LEN(Usb.drivers.drivers)); (* NOT Threadsafe! *)
			FOR i := 0 TO LEN(Usb.drivers.drivers)-1 DO drivers[i] := Usb.drivers.drivers[i]; END;

			driverFound := FALSE; NEW(w, WriterSize);

			FOR i := 0 TO LEN(drivers)-1 DO (* i is driver priority *)
				IF drivers[i] # NIL THEN
					drv := drivers[i].next;
					WHILE drv # NIL DO(* NOT Threadsafe! *)
						driverFound := TRUE;
						NEW(node);
						w.Reset; w.String(drv.name); w.String(" ("); w.String(drv.desc); w.String(") ");
						w.String("Priority: "); w.Int(i, 0);
						w.Get(string);
						AddDrvNode(node, tn, string);
						drvTree.Acquire; drvTree.ExpandToRoot(node); drvTree.Release;
						(* Show instances of this driver *)
						FOR j := 0 TO 99 DO
							IF drv.usedSuffix[j]  THEN (* Driver instance found *)
								(* Get plugin name *)
								plugin := Usb.usbDrivers.Get(Usb.drivers.AddSuffix(drv.name, j));
								IF plugin # NIL THEN
									NEW(n);
									w.Reset; w.String("Instance: "); w.String(plugin.name);
									w.String(" assigned to ");
									dev := plugin(Usbdi.Driver).device (Usb.UsbDevice);
									IF dev # NIL THEN
										IF (dev.descriptor(Usb.DeviceDescriptor).sManufacturer # NIL) OR (dev.descriptor(Usb.DeviceDescriptor).sProduct # NIL) THEN
											IF dev.descriptor(Usb.DeviceDescriptor).sManufacturer # NIL THEN w.String(dev.descriptor(Usb.DeviceDescriptor).sManufacturer^); w.Char(" ");END;
											IF dev.descriptor(Usb.DeviceDescriptor).sProduct # NIL THEN w.String(dev.descriptor(Usb.DeviceDescriptor).sProduct^); END;
										ELSE
											w.String("Unnamed device");
										END;
									ELSE
										w.String("no device!?!");
									END;
									w.Get(string); AddDrvNode(n, node, string);
									drvTree.Acquire; drvTree.ExpandToRoot(n); drvTree.Release;
								END;
							END;
						END;
						drv := drv.next;
					END; (* end while *)
				END;
			END;

			IF ~driverFound THEN (* No USB device drivers registered *)
				NEW(node);
				AddDrvNode(node, tn, "No USB device drivers registered");
				drvTree.Acquire; drvTree.ExpandToRoot(node); drvTree.Release;
			END;

			drvTreeView.visible.Set(TRUE);
		END BuildDrivers;

		(* Search all interfaces of the USB device dev active configuration for installed
		device drivers. Returns NIL, if no drivers found. *)
		PROCEDURE GetDriversOf(dev : Usb.UsbDevice) : Driver;
		VAR drivers, d, temp : Driver; con : Usb.ConfigurationDescriptor; i : LONGINT;
		BEGIN
			IF dev # NIL THEN
				con := dev.actConfiguration (Usb.ConfigurationDescriptor);
				(* Search all interfaces of the active configuration for installed device drivers *)
				FOR i := 0 TO LEN(con.interfaces)-1 DO
					IF con.interfaces[i](Usb.InterfaceDescriptor).driver # NIL THEN
						IF drivers = NIL THEN (* New list *)
							NEW(drivers); drivers.interface := i;
							drivers.driver := con.interfaces[i](Usb.InterfaceDescriptor).driver;
						ELSE (* Append to list *)
							NEW(d); d.interface := i;
							d.driver := con.interfaces[i](Usb.InterfaceDescriptor).driver;
							temp := drivers; WHILE(temp.next # NIL) DO temp := temp.next; END;
							temp.next := d;
						END;
					END;
				END;
			END;
			RETURN drivers;
		END GetDriversOf;

		PROCEDURE GetUsbInfo(VAR nbrOfRootHubs,  nbrOfPorts, nbrOfDevices : LONGINT);
		VAR i : LONGINT; rootHubs : Usb.RootHubArray;

			PROCEDURE ProcessHub(hub : Usb.UsbDevice; VAR nbrOfPorts, nbrOfDevices : LONGINT);
			VAR i : LONGINT; dev : Usb.UsbDevice;
			BEGIN
				ASSERT((hub # NIL) & (hub.hubFlag = TRUE) & (hub.deviceAtPort # NIL));
				INC(nbrOfPorts, LEN(hub.deviceAtPort));
				FOR i := 0 TO LEN(hub.deviceAtPort)-1 DO
					dev := hub.deviceAtPort[i];
					IF (dev # NIL) THEN
						INC(nbrOfDevices);
						IF dev.hubFlag THEN ProcessHub(hub.deviceAtPort[i], nbrOfPorts, nbrOfDevices); END;
					END;
				END;
			END ProcessHub;

		BEGIN
			Usb.GetRootHubs(rootHubs);
			IF rootHubs # NIL THEN
				nbrOfRootHubs := LEN(rootHubs); nbrOfPorts := 0; nbrOfDevices := 0;
				FOR i := 0 TO LEN(rootHubs)-1 DO
					ProcessHub(rootHubs[i], nbrOfPorts, nbrOfDevices);
					rootHubs[i] := NIL;
				END;
			ELSE
				 nbrOfRootHubs := 0; nbrOfPorts := 0; nbrOfDevices := 0;
			END;
		END GetUsbInfo;

		PROCEDURE BuildInfoLine;
		VAR w : Streams.StringWriter; nbrOfRootHubs, nbrOfPorts, nbrOfDevices : LONGINT;
		BEGIN
			NEW(w, WriterSize);
			GetUsbInfo(nbrOfRootHubs, nbrOfPorts, nbrOfDevices);
			IF nbrOfRootHubs = 0 THEN
				w.String(" No USB host controllers found");
			ELSE
				w.String(" Root Hubs: "); w.Int(nbrOfRootHubs, 0);
				w.String("  Total port count: "); w.Int(nbrOfPorts, 0);
				w.String("  Devices connected: "); w.Int(nbrOfDevices, 0);
			END;
			w.Get(string);
			infoline.caption.Set(Strings.NewString(string));
		END BuildInfoLine;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR btn : WMStandardComponents.Button;
		BEGIN
			btn := sender (WMStandardComponents.Button);
			IF btn = btnRefresh THEN (* Force refresh *)
				lastNbrOfDriverEvents := -1; lastNbrOfTopologyEvents := -1;
				timer.Wakeup;
			END;
		END ButtonHandler;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR m : Mode; viewChanged : BOOLEAN;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				m := data(WMTabComponents.Tab).data (Mode);
				IF m.mode # viewmode THEN
					IF (viewmode = VmDrivers) & (m.mode # VmDrivers) THEN
						treepanel.visible.Set(TRUE); driverpanel.visible.Set(FALSE);
					END;
					viewmode := m.mode;
					IF  m.mode = VmStandard THEN viewChanged := TRUE;
					ELSIF m.mode = VmDetailed THEN viewChanged := TRUE;
					ELSIF m.mode = VmDrivers THEN
						treepanel.visible.Set(FALSE); driverpanel.visible.Set(TRUE);
					ELSIF m.mode = VmPortStatus THEN viewChanged := TRUE;
					END;
					IF viewChanged THEN (* Force refresh *) lastNbrOfTopologyEvents := -1; timer.Wakeup; END;
				END;
			END
		END TabSelected;

		PROCEDURE NodeSelected(sender, data : ANY);
		VAR dev : Usb.UsbDevice; ndata : ANY; d : Driver;
		BEGIN
			usbSelected := NIL; drivers := NIL;
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				usbTree.Acquire;
				usbSelected := data (WMTrees.TreeNode);
				ndata := usbTree.GetNodeData(usbSelected);
				usbTree.Release;
				IF ndata # NIL THEN
					dev := ndata (Usb.UsbDevice);
					d := GetDriversOf(dev);
					drivers := d;
				END;
			END;
		END NodeSelected;

		(* Add node <node> to the usbTree as child of node <parent> and name it <caption> *)
		PROCEDURE AddUsbNode(node, parent : WMTrees.TreeNode; CONST caption : ARRAY OF CHAR);
		BEGIN
			usbTree.Acquire;
			usbTree.AddChildNode(parent, node);
			usbTree.SetNodeCaption(node, Strings.NewString(caption));
			usbTree.Release;
		END AddUsbNode;

		(* Add node <node> to the drvTree as child of node <parent> and name it <caption> *)
		PROCEDURE AddDrvNode(node, parent : WMTrees.TreeNode; CONST caption : ARRAY OF CHAR);
		BEGIN
			drvTree.Acquire;
			drvTree.AddChildNode(parent, node);
			drvTree.SetNodeCaption(node, Strings.NewString(caption));
			drvTree.Release;
		END AddDrvNode;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR
			label : WMStandardComponents.Label;
			tab : WMTabComponents.Tab;
			mode : Mode;
			string : ARRAY 32 OF CHAR;
			i : LONGINT;
		BEGIN
			NEW(timer);
			dead := FALSE; alive := TRUE;

			NEW(mainpanel);
			mainpanel.bounds.SetExtents(WindowWidth, WindowHeight); mainpanel.fillColor.Set(LONGINT(0FFFFFFFFH));

			NEW(buttonpanel);
			buttonpanel.fillColor.Set(0F0F0F0FH);
			buttonpanel.bounds.SetHeight(20); buttonpanel.alignment.Set(WMComponents.AlignTop);
			mainpanel.AddContent(buttonpanel);

			NEW(label); label.caption.SetAOC("  View mode: ");
			label.bounds.SetWidth(100); label.alignment.Set(WMComponents.AlignLeft);
			buttonpanel.AddContent(label);

			NEW(tabs); tabs.bounds.SetWidth(250); tabs.alignment.Set(WMComponents.AlignLeft);
			tabs.onSelectTab.Add(TabSelected);
			buttonpanel.AddContent(tabs);

			FOR i := 0 TO 2 DO
				tab := tabs.NewTab();
				tabs.AddTab(tab);
				NEW(mode);
				CASE i OF
					0: string := "Standard"; mode.mode := VmStandard;
					|1 : string := "Detailed"; mode.mode := VmDetailed;
					|2 : string := "Drivers"; mode.mode := VmDrivers;
					|3 : string := "PortStatus"; mode.mode := VmPortStatus;
				END;
				tabs.SetTabCaption(tab, Strings.NewString(string));
				tabs.SetTabData(tab, mode);
			END;

			NEW(btnRefresh); btnRefresh.caption.SetAOC("Refresh"); btnRefresh.alignment.Set(WMComponents.AlignRight);
			btnRefresh.onClick.Add(ButtonHandler);
			buttonpanel.AddContent(btnRefresh);

			NEW(btnProperties); btnProperties.caption.SetAOC("Properties"); btnProperties.alignment.Set(WMComponents.AlignRight);
			btnProperties.onClick.Add(ButtonHandler); btnProperties.visible.Set(FALSE);
			buttonpanel.AddContent(btnProperties);

			NEW(infoline);
			infoline.bounds.SetHeight(20); infoline.alignment.Set(WMComponents.AlignBottom);
			infoline.fillColor.Set(0F0F0F0FH);
			mainpanel.AddContent(infoline);

			NEW(treepanel);
			treepanel.alignment.Set(WMComponents.AlignClient);
			mainpanel.AddContent(treepanel);

			NEW(usbTreeView);
			usbTreeView.alignment.Set(WMComponents.AlignClient);
			usbTreeView.onSelectNode.Add(NodeSelected);
			usbTree := usbTreeView.GetTree();
			treepanel.AddContent(usbTreeView);

			NEW(driverpanel);
			driverpanel.alignment.Set(WMComponents.AlignClient);
			driverpanel.visible.Set(FALSE);
			mainpanel.AddContent(driverpanel);

			NEW(drvTreeView);
			drvTreeView.alignment.Set(WMComponents.AlignClient);
			drvTree := drvTreeView.GetTree();
			driverpanel.AddContent(drvTreeView);

			viewmode := VmStandard;

			BuildTree;
			BuildDrivers;
			BuildInfoLine;

			Init(mainpanel.bounds.GetWidth(), mainpanel.bounds.GetHeight(), FALSE);
			SetContent(mainpanel);
			SetTitle(Strings.NewString("USB Viewer"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMUsbInfo.png", TRUE));

			WMWindowManager.DefaultAddWindow(SELF);
			IncCount;
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			alive := FALSE; timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			DecCount;
		END Close;

	BEGIN {ACTIVE}
		WHILE(alive) DO

			(* Have drivers been added or removed? *)
			IF Usb.drivers.nbrOfDriverEvents # lastNbrOfDriverEvents THEN
				lastNbrOfDriverEvents := Usb.drivers.nbrOfDriverEvents;
				BuildDrivers;
				BuildInfoLine;
			END;

			(* Has the bus topology changes? *)
			IF Usb.nbrOfTopologyEvents # lastNbrOfTopologyEvents THEN
				lastNbrOfTopologyEvents := Usb.nbrOfTopologyEvents;
				BuildTree;
				BuildInfoLine;
			END;

			timer.Sleep(PollInterval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Window;

VAR
	nofWindows : LONGINT;

(*
 * Return a string represenation of the idVendor field of the USB device descriptor. Returns "Unknown", if
 * no string available. A list of assigned vendor IDs can be found at www.usb.org.
 *)
PROCEDURE GetVendorString(vendorId : LONGINT) : Strings.String;
CONST Trace = FALSE;
VAR
	in : Streams.Reader;
	line, vendor : LONGINT; char : CHAR;
	vendorStr : ARRAY 128 OF CHAR;
BEGIN
	in := Codecs.OpenInputStream(VendorIdFile);
	IF in # NIL THEN
		(* File format: vendorid + "|" + vendor string + "EOL" *)
		LOOP
			INC(line);
			char := in.Peek();
			IF in.Available() = 0 THEN (* End of file *) EXIT; END;
			in.Int(vendor, FALSE); (* Get the Vendor ID *)
			in.Char(char);
			IF in.res # Streams.Ok THEN KernelLog.String("res: "); KernelLog.Int(in.res,0); KernelLog.Ln; END;
			IF char # "|" THEN
				IF Debug THEN
					KernelLog.String("UsbInfo: Parse error while parsing vendor id file at line ");
					KernelLog.Int(line, 0); KernelLog.Ln;
				END;
				EXIT;
			END;
			in.Ln(vendorStr);
			IF Trace THEN KernelLog.Int(vendor, 0); KernelLog.String(": "); KernelLog.String(vendorStr); KernelLog.Ln; END;
			IF vendorId = vendor THEN RETURN Strings.NewString(vendorStr); END;
			IF in.res # Streams.Ok THEN EXIT; END;
		END;
	ELSIF Debug THEN KernelLog.String("UsbInfo: Could not load file: "); KernelLog.String(VendorIdFile); KernelLog.Ln;
	END;
	RETURN Strings.NewString("Unknown");
END GetVendorString;

(* Return a image according to the device type *)
PROCEDURE GetImage(dev : Usb.UsbDevice) : WMGraphics.Image;
VAR if : Usb.InterfaceDescriptor; image : WMGraphics.Image;
BEGIN
	if := dev.actConfiguration.interfaces[0] (Usb.InterfaceDescriptor);
	IF dev.parent = dev THEN (* Root Hub *)
		IF dev.controller.isHighSpeed THEN
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbControllerHs.png", TRUE);
		ELSE
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbController.png", TRUE);
		END;
	ELSIF dev.hubFlag THEN  (* USB hub device *)
		IF dev.speed = UsbHcdi.HighSpeed THEN
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbHubHs.png", TRUE);
		ELSE
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbHub.png", TRUE);
		END;
	ELSIF (if.bInterfaceClass = 03H) & (if.bInterfaceSubClass = 01H) & (if.bInterfaceProtocol = 02H) THEN (* Mouse *)
		image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbMouse.png", TRUE);
	ELSIF (if.bInterfaceClass = 03H) & (if.bInterfaceSubClass = 01H) & (if.bInterfaceProtocol = 01H) THEN (* Keyboard *)
		image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbKeyboard.png", TRUE);
	ELSIF (if.bInterfaceClass = 08H) THEN (* Mass Storage Device *)
		IF dev.speed = UsbHcdi.HighSpeed THEN
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbMassStorageHs.png", TRUE);
		ELSE
			image := WMGraphics.LoadImage("WMUsbInfo.tar://UsbMassStorage.png", TRUE);
		END;
	END;
	RETURN image;
END GetImage;

(*
 * Return a string description of Device Class, Device Subclass and Interface Protocol according
 * to the Device Class Code Definition 1.0.
 *)
PROCEDURE GetDeviceDescription(class, subclass, protocol : LONGINT; VAR c, s, p : Strings.String);
BEGIN
	c := NIL; s := NIL; p := NIL;
	IF class = 0 THEN
		c := Strings.NewString("Class information at interface level");
	ELSIF class = 2 THEN
		c := Strings.NewString("Communication");
	ELSIF class = 9 THEN
		c := Strings.NewString("Hub");
		IF protocol = 0 THEN p := Strings.NewString("No TT");
		ELSIF protocol = 1 THEN p := Strings.NewString("Single TT");
		ELSIF protocol = 2 THEN p := Strings.NewString("Multi TT");
		END;
	ELSIF class = 220 THEN
		c := Strings.NewString("Diagnostic Device");
		IF (subclass = 1) THEN s := Strings.NewString("Reprogrammable Diagnostic Device"); END;
		IF (protocol = 1) THEN s := Strings.NewString("USB2 Compliance Device"); END;
	ELSIF class = 224 THEN
		c := Strings.NewString("Wireless Controller");
		IF (subclass = 1) THEN s := Strings.NewString("RF Controller"); END;
		IF (protocol = 1) THEN s := Strings.NewString("Bluetooth Programming Interface"); END;
	ELSIF class = 239 THEN
		c := Strings.NewString("Miscellaneous Device Class");
		IF (subclass = 2) THEN s := Strings.NewString("Common Class"); END;
		IF (protocol = 1) THEN s := Strings.NewString("Interface Association Descriptor"); END;
	END;
	IF class = 0FFH THEN c := Strings.NewString("Vendor-Specific"); END;
	IF subclass = 0FFH THEN s := Strings.NewString("Vendor-Specific"); END;
	IF protocol = 0FFH THEN p := Strings.NewString("Vendor-Specific"); END;
END GetDeviceDescription;

(*
 * Return a string description of Interface Class, Interface Subclass and Interface Protocol according
 * to the Device Class Code Definition 1.0 and
 * - USB Printer Device Class 1.0
 * - USB Mass-storage Device Class 1.0
 * - USB Audio Device Class 1.0
 * - USB Video Device Class 1.0
 * - USB HID Device Class 1.0
 *)
PROCEDURE GetInterfaceDescription(class, subclass, protocol : LONGINT; VAR c, s, p: Strings.String);
BEGIN
	c := NIL; s := NIL; p := NIL;
	IF class = 1 THEN
		c := Strings.NewString("Audio");
		IF subclass = 0 THEN s := Strings.NewString("Undefined");
		ELSIF subclass = 1 THEN s := Strings.NewString("Audio Control");
		ELSIF subclass = 2 THEN s := Strings.NewString("Audio Streaming");
		ELSIF subclass = 3 THEN s := Strings.NewString("MIDI Streaming");
		END;
		IF protocol = 0 THEN p := Strings.NewString("Undefined"); END;
	ELSIF class = 2 THEN
		c := Strings.NewString("CDC-Control");
	ELSIF class = 3 THEN
		c := Strings.NewString("HID");
		IF subclass = 0 THEN s := Strings.NewString("No Subclass");
		ELSIF subclass = 1 THEN s := Strings.NewString("Boot Interface Subclass");
			IF protocol = 0 THEN p := Strings.NewString("None");
			ELSIF protocol = 1 THEN p := Strings.NewString("Keyboard");
			ELSIF protocol = 2 THEN p := Strings.NewString("Mouse");
			ELSE p := Strings.NewString("Reserved");
			END;
		ELSE s := Strings.NewString("Reserved");
		END;
	ELSIF class = 5 THEN
		c := Strings.NewString("Physical");
	ELSIF class = 6 THEN
		IF (subclass = 1) & (protocol = 1) THEN c := Strings.NewString("Image"); END;
	ELSIF class = 7 THEN
		c := Strings.NewString("Printer");
		IF subclass = 1 THEN s := Strings.NewString("Printers"); END;
		IF protocol = 00H THEN p := Strings.NewString("Undefined");
		ELSIF protocol = 01H THEN p := Strings.NewString("Unidirectional Interface");
		ELSIF protocol = 02H THEN p := Strings.NewString("Bidirectional Interface");
		ELSIF protocol = 03H THEN p := Strings.NewString("1284.4 Compatible Bidirectional Interface");
		END;
	ELSIF class = 8 THEN
		c := Strings.NewString("Mass-Storage");
		IF subclass = 1 THEN s := Strings.NewString("Reduced Block Commands");
		ELSIF subclass = 2 THEN s := Strings.NewString("SFF-8020i, MMC-2 (ATAPI)");
		ELSIF subclass = 3 THEN s := Strings.NewString("QIC-157");
		ELSIF subclass = 4 THEN s := Strings.NewString("UFI");
		ELSIF subclass = 5 THEN s := Strings.NewString("SFF-8070i");
		ELSIF subclass = 6 THEN s := Strings.NewString("SCSI Transparent Command Set");
		ELSIF (subclass >= 7) & (subclass < 256) THEN
			s := Strings.NewString("Reserved");
		END;
		IF protocol = 00H THEN p := Strings.NewString("CBI Transport (with completion interrupt)");
		ELSIF protocol = 01H THEN p := Strings.NewString("CBI Transport (w/o completion interrupt)")
		ELSIF protocol = 50H THEN p := Strings.NewString("Bulk-Only Transport")
		END;
	ELSIF class = 9 THEN
		c := Strings.NewString("Hub");
	ELSIF class = 10 THEN
		c := Strings.NewString("CDC-Data");
	ELSIF class = 11 THEN
		c := Strings.NewString("Chip/Smartcard");
	ELSIF class = 13 THEN
		c := Strings.NewString("Content-Security");
	ELSIF class = 14 THEN
		c := Strings.NewString("Video");
		IF subclass = 0 THEN s := Strings.NewString("Undefined");
		ELSIF subclass = 1 THEN s := Strings.NewString("Video Control");
		ELSIF subclass = 2 THEN s := Strings.NewString("Video Streaming");
		ELSIF subclass = 3 THEN s := Strings.NewString("Video Interface Collection");
		END;
		IF protocol = 0 THEN p := Strings.NewString("Undefined"); END;
	ELSIF class = 220 THEN
		c := Strings.NewString("Diagnostic Device");
		IF (subclass = 1) THEN s := Strings.NewString("Reprogrammable Diagnostic Device"); END;
		IF (protocol = 1) THEN s := Strings.NewString("USB2 Compliance Device"); END;
	ELSIF class = 224 THEN
		c := Strings.NewString("Wireless Controller");
		IF (subclass = 1) THEN s := Strings.NewString("RF Controller"); END;
		IF (protocol = 1) THEN s := Strings.NewString("Bluetooth Programming Interface"); END;
	ELSIF class = 254 THEN
		c := Strings.NewString("Application-Specific");
		IF (subclass = 1) THEN s := Strings.NewString("Device Firmware Update");
		ELSIF (subclass = 2) THEN s := Strings.NewString("IrDA Bridge");
		ELSIF (subclass = 3) THEN s := Strings.NewString("Test & Measurement Class");
		END;
	END;
	IF class = 0FFH THEN c := Strings.NewString("Vendor-Specific"); END;
	IF subclass = 0FFH THEN s := Strings.NewString("Vendor-Specific"); END;
	IF protocol = 0FFH THEN p := Strings.NewString("Vendor-Specific"); END;
END GetInterfaceDescription;

(*
 * Return a string description of Device Class, Device Subclass and Interface Protocol according
 * to:
 *
 *)
PROCEDURE GetIadDescription(class, subclass, protocol : LONGINT; VAR c, s, p : Strings.String);
BEGIN
	c := NIL; s := NIL; p := NIL;
	IF class = 0EH THEN
		c := Strings.NewString("Video");
		IF subclass = 00H THEN s := Strings.NewString("Undefined");
		ELSIF subclass = 01H THEN s := Strings.NewString("Video Control");
		ELSIF subclass = 02H THEN s := Strings.NewString("Video Streaming");
		ELSIF subclass = 03H THEN s := Strings.NewString("Video Interface Collection");
		END;
		IF protocol = 00H THEN p := Strings.NewString("Undefined"); END;
	END;
END GetIadDescription;

(** Open Usb Viewer *)
PROCEDURE Open*;
VAR w : Window;
BEGIN
	NEW(w, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context)
END Restore;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg; msg : WMMessages.Message; m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMUsbInfo.

WMUsbInfo.Open ~  SystemTools.Free WMUsbInfo ~