MODULE UsbHidDriver;  (** AUTHOR "ottigerm"; PURPOSE "USB HID Parser"; *)
(**
 * Bluebottle USB HID Driver
 *
 * This driver currently supports:
 *
 *	Mouse:		2 axis, 1 mouse wheel, up to 32 buttons
 *	Keyboard	incl. consumer keys
 *	Joystick		x, y, z, rx, ry, rz and one slider axis, one coolie hat and arbitrary many buttons
 *  Touchscreen x,y
 *
 * Usage:
 *	UsbHidDriver.Install ~ load this driver
 *	SystemTools.Free UsbHidDriver ~ unload this driver
 *
 * Remarks:
 *
 * References:
 *	Device Class Definition for Human Interface Devices (HID), Version 1., 27.09.2006, www.usb.org
 *
 * History:
 *	21.04.2006	starting
 *	22.01.2007	Version 1.0
 *)

IMPORT
	SYSTEM, Machine, KernelLog, Modules, Inputs, Usbdi, UsbHid,
	HidParser := UsbHidParser, UsbHidReport, UsagePage := UsbHidUP, UsbKeyboard,
	Joystick := Joysticks, Kernel;

CONST

	Name = "UsbHid";
	Description = "USB HID driver";

	Debug 	= HidParser.Debug;
	Trace	= HidParser.Trace;

	(* use for logging the reports *)
	ShowNoReport 			= 0;	(* do not show any reports *)
	ShowVeryShortReport 	= 1; (* show short and non zero valued reports *)
	ShowShortReport 		= 2; (* show short reports; only the ids with their assigned value *)
	ShowFullReport 		= 3; (* show reports including description *)

	LoggingMode = ShowNoReport;

	MouseSpeed = 50;
	MouseWheelSpeed = 3;
	MouseAcceleration = 0;
	
	

TYPE

	MouseState = POINTER TO RECORD
		(* mouse msg can hold up to 32 buttons *)
		buttons:			ARRAY 32 OF UsbHidReport.UsageTuple;
		(* identifies the last available button *)
		buttonCount:	LONGINT;
		buttonReport:	UsbHidReport.HidReport;
		x:				UsbHidReport.UsageTuple;
		y:				UsbHidReport.UsageTuple;
		axisReport:		UsbHidReport.HidReport;
		wheel:			UsbHidReport.UsageTuple;
		wheelReport:	UsbHidReport.HidReport;
		lastDx, lastDy: 	LONGINT;
	END;

	TouchscreenState = POINTER TO RECORD
		x,y: UsbHidReport.UsageTuple;
		minX, maxX, minY, maxY: LONGINT;
		tipSwitch, inRange, confidence: UsbHidReport.UsageTuple;
		prev: BOOLEAN;
		prevx, prevy: LONGINT;
		prevkeys: SET;
		prevTip: BOOLEAN;
		tipTime: LONGINT; 
	END;

	(*Handling keyboard devices*)
	KeyboardState = OBJECT(UsbKeyboard.KeyboardBase);
	VAR
		modifierUsages: UsbHidReport.PtrToUsageTupleArr;     (*first ref on buffer*)
		keycodeUsages: UsbHidReport.PtrToUsageTupleArr;

		pressed* : POINTER TO ARRAY OF UsbKeyboard.Key;
		tempPressed : POINTER TO ARRAY OF UsbKeyboard.Key;

		ledStateChanged : BOOLEAN;

		(*init settings*)
		PROCEDURE Init;
		VAR i : ADDRESS; k : ARRAY 32 OF CHAR;
		BEGIN
			(* Get  *)
			Machine.GetConfig("Keyboard", k);
			i := -1;
			IF k # "" THEN i := TableFromFile(k); END;
			IF i = -1 THEN (* Fallback to default *) i := UsbKeyboard.TableUS(); END;
			SYSTEM.PUT(ADDRESSOF(keytable), i);

			(* Apply Numlock boot up state *)
			Machine.GetConfig("NumLock", k);
			IF k[0] = "1" THEN INCL(leds, UsbKeyboard.NumLock) END;

			keyDeadTime := UsbKeyboard.KeyDeadTime DIV 10;
			keyDeadTimeRepeat := UsbKeyboard.KeyDeadTimeRepeat DIV 10;

			NEW(ledBuffer, 1);
		END Init;

		(**
		 * Sets the maximum possible amount of keys, the device is sending at one time
		 * @param nofkeys: the number of keys maximumely sent by the device
		 *)
		PROCEDURE SetMaxKeycodes(nofKeys: LONGINT);
		BEGIN
			ASSERT(pressed=NIL);
			ASSERT(tempPressed=NIL);
			NEW(pressed,nofKeys);
			NEW(tempPressed, nofKeys);
		END SetMaxKeycodes;

		(**
		 * Handle Keyboard Report
		 *)
		PROCEDURE HandleKeyboardEvent;
		VAR
			i, j : LONGINT;
			c : CHAR;
			flags : SET;
			found, kill : BOOLEAN;
		BEGIN
			(*KernelLog.String('handle key'); KernelLog.Ln;*)
			(* evaluate modifier keys *)
			msg.flags := {};

			IF (modifierUsages[0].usageValue=1) THEN INCL(msg.flags, Inputs.LeftCtrl) END;
			IF (modifierUsages[1].usageValue=1) THEN INCL(msg.flags, Inputs.LeftShift) END;
			IF (modifierUsages[2].usageValue=1) THEN INCL(msg.flags, Inputs.LeftAlt) END;
			IF (modifierUsages[3].usageValue=1) THEN INCL(msg.flags, Inputs.LeftMeta) END;
			IF (modifierUsages[4].usageValue=1) THEN INCL(msg.flags, Inputs.RightCtrl) END;
			IF (modifierUsages[5].usageValue=1) THEN INCL(msg.flags, Inputs.RightShift) END;
			IF (modifierUsages[6].usageValue=1) THEN INCL(msg.flags, Inputs.RightAlt) END;
			IF (modifierUsages[7].usageValue=1) THEN INCL(msg.flags, Inputs.RightMeta) END;

			flags := msg.flags;

			(* evaluate the six keycodes *)
			FOR i := 2 TO 7 DO
				c := SYSTEM.VAL(CHAR, keycodeUsages[i-2].usageValue);
				IF c # CHR(0) THEN (* buffer[i] contains key code *)

					(* check whether the key is pressed for the first time, is still being pressed or has been released *)
					FOR j := 0 TO 5 DO

						IF pressed[j].ch = c THEN (* key is still pressed *)
							found := TRUE;
							pressed[j].updated := TRUE;

							tempPressed[i-2].counter := pressed[j].counter + 1;
							tempPressed[i-2].ch := pressed[j].ch;
							tempPressed[i-2].keysym := pressed[j].keysym;
							tempPressed[i-2].updated := FALSE;
							tempPressed[i-2].repeat := pressed[j].repeat;

							IF pressed[j].repeat THEN
								IF (keyDeadTimeRepeat # 0) & (tempPressed[i-2].counter MOD keyDeadTimeRepeat # 0) THEN (* don't send key event *) kill := TRUE; END;
							ELSE
								IF tempPressed[i-2].counter MOD keyDeadTime # 0 THEN (* don't send key event *)
									kill := TRUE;
								ELSE
									tempPressed[i-2].repeat := TRUE;
								END;
							END;
						END;
				    	END;
				 END;

				IF ~found THEN (* the key has not been pressed down before *)
					tempPressed[i-2].ch := c;
					tempPressed[i-2].repeat := FALSE;
					tempPressed[i-2].updated := FALSE;
					tempPressed[i-2].counter := 1;
				END;

			    (* kill : Key is pressed but do not generate key event this time -> repeat rate ... *)
			    IF (c # CHR(0)) & ~kill THEN
			    	HandleKey(c);
			    	tempPressed[i-2].keysym := msg.keysym; (* msg.keysym asigned by HandleKey() ... *)
			    END;
			END; (* FOR LOOP *)

			(* update pressed array. generate keyboard.msg's for released keys *)
			FOR i := 0 TO 5 DO
				IF (pressed[i].updated = FALSE) & (pressed[i].ch # CHR(0)) THEN (* this key has been released *)
					msg.flags := {};
					INCL(msg.flags, Inputs.Release);
					msg.ch := pressed[i].ch;
					msg.keysym := pressed[i].keysym;
					dkHack := deadKey;  (* value of deadKey should persist the key release event *)
					HandleKey(c);
					deadKey := dkHack;
				END;
				pressed[i].counter := tempPressed[i].counter;
				pressed[i].ch := tempPressed[i].ch;
				pressed[i].keysym := tempPressed[i].keysym;
				pressed[i].repeat := tempPressed[i].repeat;
				pressed[i].updated := FALSE;
			END;

			(* Generate events for modifiers *)
			HandleModifiers(flags);

			(* update status of the LEDs  of the keyboad if necessary *)
			IF lastLeds # leds THEN (* LED status has changed *)
				ledBuffer[0] := SYSTEM.VAL(CHAR, leds); lastLeds := leds;
				ledStateChanged := TRUE;
			END;
		END HandleKeyboardEvent;
	END KeyboardState;

	(* When user presses button, the system has to store the pressed keys in this linked list *)
	ConsumerKey = POINTER TO RECORD
		key: LONGINT;
		usagePage: LONGINT;
		alive: BOOLEAN;
		next: ConsumerKey;
	END;

	(*handling consumer devices*)
	ConsumerState= OBJECT
	VAR
		(*where the consumer report is stored*)
		consumerReport : UsbHidReport.HidReport;
		first: ConsumerKey;

		(**
		 * Checks, whether the usageID with the usagePage is still pressed by the user
		 * if found, also sets the alive flag to TRUE, such that the clean up method will not destroy it next time
		 * @param usageID: the usageID pressed
		 * @param usagePage: normally 0, for detected consumer devices; 9, if consumer send consumer keys as buttons
		 * @return TRUE, if found, FALSE otherwise
		 *)
		PROCEDURE IsSet(usageID, usagePage: LONGINT): BOOLEAN;
		VAR cursor:	ConsumerKey;
		BEGIN
			cursor := first;
			WHILE(cursor#NIL) DO
				IF ((cursor.key=usageID) & (cursor.usagePage=usagePage)) THEN
					cursor.alive := TRUE;
					RETURN TRUE;
				END;
				cursor := cursor.next;
			END;
			RETURN FALSE;
		END IsSet;

		(**
		 * Adds the tuple.usageID and tuple.usagePage to the linked list
		 * @param tuple: the tuple to add
		 *)
		PROCEDURE AddKey(tuple:UsbHidReport.UsageTuple);
		VAR cursor: ConsumerKey;
		BEGIN
			IF first=NIL THEN
				NEW(first);
			ELSE
				NEW(cursor);
				cursor.next := first;
				first := cursor;
			END;
			first.key := tuple.usageID;
			first.usagePage := tuple.usagePage;
			first.alive := TRUE;
		END AddKey;

		(**
		 * destroys all consumerKeys whose alive flag is not set
		 *)
		PROCEDURE CleanUp;
		VAR cursor, previous: ConsumerKey;
		BEGIN
			cursor := first;
			WHILE(cursor#NIL) DO
				IF cursor.alive = FALSE THEN
					SendKeySym(cursor.key,cursor.usagePage,FALSE);
					IF(cursor = first) THEN
						first := first.next;
					ELSE
						previous.next := cursor.next;
					END;
				ELSE
					cursor.alive := FALSE;
					previous := cursor;
				END;
				cursor := cursor.next;
			END;
		END CleanUp;

		(**
		 * Checks whether the keysym is valid, if yes, it generates a keymsg and sends the key to Inputs
		 * @param usage: the id of the keysym
		 * @param usagePage: 0: normally, 9: if key is sent as button
		 *)
		PROCEDURE SendKeySym(usage, usagePage:LONGINT; pressed:BOOLEAN);
		VAR keyMsg : Inputs.KeyboardMsg;
		BEGIN
			IF Debug THEN
				KernelLog.String("Handling key");
			END;
			IF (usagePage=0) THEN
				CASE usage OF
					0B5H: 	keyMsg.keysym := Inputs.KsScanNextTrack; 		(*KernelLog.String("KsScanNextTrack");*)
					|0B6H: 	keyMsg.keysym := Inputs.KsScanPreviousTrack; 	(*KernelLog.String("KsScanPreviousTrack");*)
					|0B7H: 	keyMsg.keysym := Inputs.KsStopOSC; 				(*KernelLog.String("KsStopOSC");*)
					|0CDH: 	keyMsg.keysym := Inputs.KsPlayPause; 			(*KernelLog.String("KsPlayPause");*)
					|0E2H: 	keyMsg.keysym := Inputs.KsMute; 					(*KernelLog.String("KsMute");*)
					|0E9H: 	keyMsg.keysym := Inputs.KsVolumeIncrement; 		(*KernelLog.String("KsVolumeIncrement");*)
					|0EAH: 	keyMsg.keysym := Inputs.KsVolumeDecrement; 	(*KernelLog.String("KsVolumeDecrement");*)
					|183H: 	keyMsg.keysym := Inputs.KsALConsumerControl; 	(*KernelLog.String("KsALConsumerControl");*)
					|18AH: 	keyMsg.keysym := Inputs.KsALEmailReader; 		(*KernelLog.String("KsALEmailReader");*)
					|221H: 	keyMsg.keysym := Inputs.KsACSearch; 				(*KernelLog.String("KsACSearch");*)
					|223H: 	keyMsg.keysym := Inputs.KsACHome; 				(*KernelLog.String("KsACHome");*)
					|224H: 	keyMsg.keysym := Inputs.KsACBack; 				(*KernelLog.String("KsACBack");*)
					|225H: 	keyMsg.keysym := Inputs.KsACForward; 			(*KernelLog.String("KsACForward");*)
					|22AH: 	keyMsg.keysym := Inputs.KsACBookmarks; 			(*KernelLog.String("KsACBookmarks");*)
				ELSE
					IF Trace THEN
						KernelLog.String("Key Sym "); KernelLog.Hex(usage,0 ); KernelLog.String("H not found"); KernelLog.Ln;
					END;
				END;
			ELSE
				(*special case: when usagePage Button is used*)
				IF (usagePage=9H) THEN
					keyMsg.keysym := Inputs.KsConsumerButtons+usage;
				END;
			END;
			IF (keyMsg.keysym#0) THEN
				IF ~pressed THEN
					keyMsg.flags:= {};
					keyMsg.keysym := Inputs.KsNil;
					INCL(keyMsg.flags, Inputs.Release);
				END;
				IF Debug THEN
					IF usagePage=0 THEN
						CASE usage OF
							0B5H: 	KernelLog.String("KsScanNextTrack");
							|0B6H: 	KernelLog.String("KsScanPreviousTrack");
							|0B7H: 	KernelLog.String("KsStopOSC");
							|0CDH:	KernelLog.String("KsPlayPause");
							|0E2H: 	KernelLog.String("KsMute");
							|0E9H: 	KernelLog.String("KsVolumeIncrement");
							|0EAH: 	KernelLog.String("KsVolumeDecrement");
							|183H: 	KernelLog.String("KsALConsumerControl");
							|18AH: 	KernelLog.String("KsALEmailReader");
							|192H: 	KernelLog.String("KsALCalculator");
							|221H: 	KernelLog.String("KsACSearch");
							|223H: 	KernelLog.String("KsACHome");
							|224H: 	KernelLog.String("KsACBack");
							|225H: 	KernelLog.String("KsACForward");
							|22AH: 	KernelLog.String("KsACBookmarks");
						ELSE
							KernelLog.String("Key Sym not found"); KernelLog.Ln;
						END;
					ELSE
						IF usagePage=9 THEN
							KernelLog.String("KsConsumerButtons(");KernelLog.Int(usage,0); KernelLog.String(")");
						END;
					END;
					IF pressed THEN
						KernelLog.String(" pressed");
					ELSE
						KernelLog.String(" released");
					END;
					KernelLog.Ln;
				END;
				Inputs.keyboard.Handle(keyMsg);
			END;
		END SendKeySym;

	END ConsumerState;

	(*handle joystick devices*)
	JoystickState = POINTER TO RECORD
		(*use the joystick as a mouse*)
		(*mouse msg can hold up to 32 buttons*)
		buttons:			ARRAY 32 OF UsbHidReport.UsageTuple;
		(*identifies the last available button*)
		buttonCount:	LONGINT;
		buttonReport:	UsbHidReport.HidReport;
		x:				UsbHidReport.UsageTuple;
		y:				UsbHidReport.UsageTuple;
		z:				UsbHidReport.UsageTuple;
		rx:				UsbHidReport.UsageTuple;
		ry:				UsbHidReport.UsageTuple;
		rz:				UsbHidReport.UsageTuple;
		slider:			UsbHidReport.UsageTuple;
		hatSwitch:		UsbHidReport.UsageTuple;

		xReport:			UsbHidReport.HidReport;
		yReport:			UsbHidReport.HidReport;
		zReport:			UsbHidReport.HidReport;
		rxReport:			UsbHidReport.HidReport;
		ryReport:			UsbHidReport.HidReport;
		rzReport:			UsbHidReport.HidReport;
		sliderReport:		UsbHidReport.HidReport;
		hatSwitchReport:	UsbHidReport.HidReport;

		joystick:			Joystick.Joystick;
	END;

	(*the hid driver*)
	HidDriver*= OBJECT (UsbHid.HidDriver);
	VAR
		(*itemParser is responsible for parsing the usb hid report descriptor*)
		itemParser 	: HidParser.ItemParser;
		endpoint	: LONGINT;
		pipe 		: Usbdi.Pipe;

		(*where the report interrupt in report is stored*)
		reportBuffer				: Usbdi.BufferPtr;
		reportManager			: UsbHidReport.HidReportManager;
		hidReportItemQueue	: UsbHidReport.ReportItemQueue;
		mouseState				: MouseState;
		touchscreenState : TouchscreenState;
		keyboardState			: KeyboardState;
		consumerState			: ConsumerState;
		joystickState			: JoystickState;
		useReportIDMechanism	: BOOLEAN;
		
		recentStatus: Usbdi.Status;

		(*
		 * This procedure is called by the USB system software after an instance of this object has been passed to it via the probe procedure.
		 * Typically, the code here sets up the communication pipe(s) use by the driver using device.GetPipe(endpointnumber).
		 *)
		PROCEDURE Connect() : BOOLEAN;
		VAR
			hidDescriptor 		: UsbHid.HidDescriptor;
			i					: LONGINT;
			reportDescBuffer 	: Usbdi.BufferPtr;
			status 				: Usbdi.Status;
			canManage			: BOOLEAN;
		BEGIN
			(*TestReader;*)
			(*parse the hid report descriptor*)
			NEW(itemParser);
			(*get interface descriptor*)

			hidDescriptor := GetHidDescriptor();
			IF (hidDescriptor = NIL) THEN
				RETURN FALSE;
			END;

			IF Debug THEN UsbHid.ShowHidDescriptor(hidDescriptor);	END;

			NEW(reportDescBuffer, hidDescriptor.wDescriptorLength);
			IF ~GetDescriptor(hidDescriptor.bClassDescriptorType,  0, interface.bInterfaceNumber , hidDescriptor.wDescriptorLength, reportDescBuffer^) THEN
				KernelLog.String("    Could not get reportDescriptor"); KernelLog.Ln;
				RETURN FALSE;
			ELSE
				IF Debug THEN
					(*print all all bytes of the reportDescBuffer*)
					LayoutBuffer(reportDescBuffer^, hidDescriptor.wDescriptorLength);
				END;
			END;
			IF(~itemParser.ParseReportDescriptor(hidDescriptor, reportDescBuffer)) THEN
				IF Debug THEN KernelLog.String("    Could not parse Report Descriptor correctly"); KernelLog.Ln; END;
			END;
			IF Trace THEN
				(*there are cases, where the report descriptor is not set correctly, but it can be used with this errors.*)
				itemParser.errorList.PrintAll;
			END;

			(*get reportManager and hidReportItemQueue*)
			reportManager := itemParser.GetReportManager();
			hidReportItemQueue := reportManager.GetReportItemQueue();

			LOOP
				IF i >= LEN(interface.endpoints) THEN EXIT; END;
				IF (interface.endpoints[i].type = Usbdi.InterruptIn)  THEN
					endpoint := SHORT(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, interface.endpoints[0].bEndpointAddress) * {0,1,2,3,7}));
					EXIT;
				END;
				INC(i);
			END;

			IF endpoint = 0 THEN
				IF Debug THEN KernelLog.String("UsbMouse: No interrupt IN endpoint found."); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			pipe := device.GetPipe(endpoint);
			IF pipe = NIL THEN RETURN FALSE END;

			IF InitializeTouchscreenDriver()=TRUE THEN
				canManage := TRUE;
			ELSIF InitializeMouseDriver() = TRUE THEN
				canManage := TRUE;
			END;

			IF InitializeKeyboardDriver()=TRUE THEN
				canManage := TRUE;
			END;

			IF InitializeConsumerDriver() = TRUE THEN
				canManage := TRUE;
			END;

			IF InitializeJoystickDriver()=TRUE THEN
				canManage := TRUE;
			END;


			IF (canManage) THEN

				useReportIDMechanism	:= reportManager.UsesReportIDMechanism();

				NEW(reportBuffer, pipe.maxPacketSize);

				pipe.SetTimeout(0);
				pipe.SetCompletionHandler(HandleHidEvent);

				status := pipe.Transfer(pipe.maxPacketSize, 0, reportBuffer^);
				recentStatus := status;
				IF Debug THEN
					KernelLog.String("UsbHidDriver.HidDriver.Connect: Connect successfully finished"); KernelLog.Ln;
				END;
		(*	ELSE  NOT SUPPORTED YET, because the whole driver is removed but not only the interface
				RETURN FALSE; *)
			END;

			RETURN TRUE;
		END Connect;

		

		(*called when detaching a usb hid device*)
		PROCEDURE Disconnect;
		BEGIN
			itemParser.Disconnect();
			itemParser:=NIL;
			(*joystick*)
			IF (joystickState#NIL) THEN
				IF joystickState.joystick#NIL THEN
					Joystick.registry.Remove(joystickState.joystick);
				END;
			END;
			IF Debug OR Trace THEN KernelLog.String("USB HID Device disconnected."); KernelLog.Ln; END;
		END Disconnect;

		(*is always called, when new report arrived*)
		PROCEDURE HandleHidEvent(status : Usbdi.Status; actLen : LONGINT);
		VAR
			ri			: UsbHidReport.ReportItem;
			i, bitIndex	: LONGINT;
			reportID	: LONGINT;
			res			: BOOLEAN;
			usageTuple	: UsbHidReport.UsageTuple;

			(*
			* update the reportManager with the newest values
			*)
			PROCEDURE HandleReportItem;
			BEGIN
				FOR i:=0 TO (ri.reportItemCount-1) DO
					IF(ri.values=NIL) THEN
						(*there are no values to read, because the reportItem describes a constant field*)
					ELSE
						IF Debug THEN
							KernelLog.String("HandleHidEvent: Reading..."); KernelLog.Ln;
						END;
						usageTuple := ri.values[i];
						usageTuple.usageValue := ReadBits(bitIndex,ri.reportItemSize);
						IF (LoggingMode=ShowShortReport) OR (LoggingMode=ShowVeryShortReport) THEN
							IF((LoggingMode=ShowShortReport)OR(ri.values[i].usageValue#0)) THEN
								KernelLog.String("usageValue for usageID ");
								KernelLog.Int(ri.values[i].usageID,0);
								KernelLog.String(" is: ");
								KernelLog.Int(ri.values[i].usageValue,0);
								KernelLog.Ln;
							END;
						END;
					END;

					bitIndex := bitIndex + ri.reportItemSize;
				END;
			END HandleReportItem;
		BEGIN
			(*start reportParsing*)

			IF Debug THEN
				IF((hidReportItemQueue=NIL) OR (reportManager=NIL)) THEN
					KernelLog.String("UsbHidDriver:HidDriver.HandleHidEvent: Internal Error,hidReportItemQueue or reportManager not found"); KernelLog.Ln;
				END;
				LayoutBuffer(reportBuffer^,actLen);
			END;

			(*fill up report buffer with new values*)
			ri := hidReportItemQueue.first;

			IF(ri=NIL) THEN
				KernelLog.String("ri=NIL"); KernelLog.Ln;
				RETURN;
			END;
			(*index in the reportBuffer*)
			bitIndex := 0;
			IF (useReportIDMechanism) THEN
				reportID := ReadBits(0, 8);
				bitIndex := bitIndex + 8;

				WHILE(ri#NIL) DO
					IF(ri.reportID=reportID) THEN
						HandleReportItem;
					END;
					ri := ri.next;
				END;
			ELSE
				WHILE(ri#NIL) DO
					HandleReportItem;
					ri := ri.next;
				END;
			END;

			IF LoggingMode=ShowFullReport THEN reportManager.PrintReportState END;

			IF (  (status = Usbdi.Ok) OR (status=Usbdi.ShortPacket)) THEN
				recentStatus := status;
				IF(mouseState#NIL) THEN
					IF Debug THEN KernelLog.String("handle mouse driver"); KernelLog.Ln; END;
					HandleMouseDriver;
				END;

				IF(keyboardState#NIL) THEN
					IF Debug  THEN  KernelLog.String("handle keyboard driver"); KernelLog.Ln; END;
					HandleKeyboardDriver;
					(* update status of the LEDs  of the keyboad if necessary *)
					IF keyboardState.lastLeds # keyboardState.leds THEN (* LED status has changed *)
						keyboardState.ledBuffer[0] := SYSTEM.VAL(CHAR, keyboardState.leds); keyboardState.lastLeds := keyboardState.leds;
						res := SetReport(UsbHid.ReportOutput, 0, keyboardState.ledBuffer^, 1); (* ignore res *)
					END;
				END;

				IF(consumerState#NIL) THEN
					IF Debug THEN KernelLog.String("handle consumer driver"); KernelLog.Ln; END;
					HandleConsumerDriver;
				END;

				IF(joystickState#NIL) THEN
					IF Debug THEN KernelLog.String("handle custom driver"); KernelLog.Ln; END;
					HandleJoystickDriver;
				END;

				IF touchscreenState #NIL THEN
					IF Debug  THEN  KernelLog.String("handle touchscreen driver"); KernelLog.Ln; END;
					HandleTouchscreenDriver
				END;

				(*get new message from hid device*)
				status := pipe.Transfer(pipe.maxPacketSize, 0, reportBuffer^);
			ELSE
				IF Debug THEN
					KernelLog.String("UsbHidDriver: "); KernelLog.String(name); KernelLog.String("("); KernelLog.String(desc); KernelLog.String(")");
					KernelLog.String(" has been disabled."); KernelLog.Ln;
				END;
				IF (status = Usbdi.Stalled) THEN
					IF pipe.ClearHalt() THEN
						IF Debug THEN KernelLog.String("UsbHidDriver: Stall on Interrupt Pipe cleared."); KernelLog.Ln; END;
						status := pipe.Transfer(pipe.maxPacketSize, 0, reportBuffer^); (* ignore status *)
					ELSE
						IF Debug THEN KernelLog.String("UsbHidDriver: Couldn't clear stall on interrupt pipe. Abort."); KernelLog.Ln; END;
						device.FreePipe(pipe);
					END;
				END;
				recentStatus := status;
			END;
		END HandleHidEvent;

		PROCEDURE IsTouchscreen*(): BOOLEAN;
		BEGIN
			RETURN touchscreenState # NIL
		END IsTouchscreen;
		
		PROCEDURE GetPipeStatus*(): Usbdi.Status;
		VAR len: LONGINT;
		BEGIN
			IF pipe # NIL THEN RETURN pipe.GetStatus(len) 
			ELSE RETURN Usbdi.Error
			END;
		END GetPipeStatus;
		
		
		PROCEDURE GetRecentStatus*(): Usbdi.Status;
		BEGIN
			RETURN recentStatus;
		END GetRecentStatus;
		
		
		(**
		 * Is called by handleHidEvent when mouse device is found
		 *)
		PROCEDURE HandleMouseDriver;
		VAR
			mm : 			Inputs.MouseMsg;
			dx, dy,i :		LONGINT;
			accelX, accelY : 	REAL;
		BEGIN
			dx := TwosComplement(mouseState.x.usageValue, mouseState.axisReport.reportSize);
			dy := TwosComplement(mouseState.y.usageValue, mouseState.axisReport.reportSize);
			IF Debug THEN KernelLog.String("x and y are: ");KernelLog.Int(dx,0); KernelLog.String(" and ");KernelLog.Int(dy,0); KernelLog.Ln; END;

			accelX := 1.0 + ABS(dx - mouseState.lastDx) / 128 * MouseAcceleration;
			accelY := 1.0 + ABS(dy - mouseState.lastDy) / 128 * MouseAcceleration;

			mouseState.lastDx := dx;
			mouseState.lastDy := dy;
			(*KernelLog.String("X: "); KernelLog.Int(dx,0); KernelLog.String("  Y:"); KernelLog.Int(dy,0); KernelLog.Ln;*)
			mm.dx := ENTIER(MouseSpeed / 50.0 *  dx * accelX);
			mm.dy := ENTIER(MouseSpeed / 50.0 * dy * accelY);

			IF (mouseState.wheel#NIL) THEN
				mm.dz := - TwosComplement(mouseState.wheel.usageValue, mouseState.wheelReport.reportSize);
				IF mm.dz < 0 THEN mm.dz := - MouseWheelSpeed;
				ELSIF mm.dz>0 THEN mm.dz := + MouseWheelSpeed;
				END;
			END;

			IF (mouseState.buttons[0].usageValue#0) THEN mm.keys := mm.keys + {0}; END;
			IF (mouseState.buttons[1].usageValue#0) THEN mm.keys := mm.keys + {2}; END;
			IF (mouseState.buttons[2].usageValue#0) THEN mm.keys := mm.keys + {1}; END;

			FOR i:=3 TO 31 DO
				IF (mouseState.buttons[i]#NIL) THEN
					IF (mouseState.buttons[i].usageValue#0) THEN mm.keys := mm.keys + {i}; END;
				END;
			END;
			Inputs.mouse.Handle(mm);
		END HandleMouseDriver;

		(**
		 * Is called by handleHidEvent when mouse device is found
		 *)
		PROCEDURE HandleTouchscreenDriver;
		VAR
			mm : 			Inputs.AbsMouseMsg;
			x,y: LONGINT; 
			displayWidth, displayHeight: LONGINT;
		BEGIN
			getDisplayDimensions(displayWidth, displayHeight); 
			x := (touchscreenState.x.usageValue-touchscreenState.minX) * displayWidth DIV (touchscreenState.maxX-touchscreenState.minX +1);
			y := (touchscreenState.y.usageValue-touchscreenState.minY) * displayHeight DIV  (touchscreenState.maxY -touchscreenState.minY + 1);
			
			(*
			TRACE(touchscreenState.inRange.usageValue);
			IF touchscreenState.confidence # NIL THEN 
				TRACE(touchscreenState.confidence.usageValue);
			END;
			*)
			
			IF (touchscreenState.tipSwitch.usageValue#0) THEN 
				IF (touchConfidenceDelay#0) & ~touchscreenState.prevTip THEN
					touchscreenState.tipTime := Kernel.GetTicks();
					touchscreenState.prevTip := TRUE
				ELSIF (touchConfidenceDelay =0) OR (Kernel.GetTicks()-touchscreenState.tipTime > touchConfidenceDelay) THEN
					mm.keys := mm.keys + {0}; 
				END
			ELSE
				touchscreenState.prevTip := FALSE;
			END;
			
			
			mm.x := x; mm.y := y;

			IF ~(0 IN mm.keys) THEN (* up event  *)
				touchscreenState.prev := FALSE;
				(* 
					There are touchscreen devices that report a (0,0) coordinate with up-events. 
					This does not work well together with an external mouse.
					We keep the coordinate for the time being -- with the side effect that there may be a pointer-over status after a touchscreen click
				*)
				IF 0 IN touchscreenState.prevkeys THEN
					mm.x := touchscreenState.prevx;
					mm.y := touchscreenState.prevy;
					touchscreenState.prevkeys := mm.keys;
					Inputs.mouse.Handle(mm);
				END;
			ELSIF (0 IN mm.keys) THEN (* down event or pointer move *)
				IF ~touchscreenState.prev THEN
					(* artificial initial up event in order to set mouse coordinates like with a "real" mouse before sending the down event *)
					touchscreenState.prev := TRUE;
					EXCL(mm.keys, 0);
					Inputs.mouse.Handle(mm);
				END;
				(* down event or pointer event *)
				touchscreenState.prevx := x;
				touchscreenState.prevy := y;
				touchscreenState.prevkeys := mm.keys;
				Inputs.mouse.Handle(mm);
			END;
		END HandleTouchscreenDriver;

		(**
		 * Is called by handleHidEvent when keyboard device is found
		 *)
		PROCEDURE HandleKeyboardDriver;
		VAR res : BOOLEAN;
		BEGIN
			keyboardState.HandleKeyboardEvent();
			IF keyboardState.ledStateChanged THEN
				res := SetReport(UsbHid.ReportOutput, 0, keyboardState.ledBuffer^, 1); (* ignore res *)
				keyboardState.ledStateChanged := FALSE;
			END;
		END HandleKeyboardDriver;

		(**
		 * Is called by handleHidEvent when consumer device is found
		 *)
		PROCEDURE HandleConsumerDriver;
		VAR
			temp: 		UsbHidReport.HidReport;
			usageTuple:	UsbHidReport.UsageTuple;
			i: 			LONGINT;
			dictUsage:	LONGINT;
		BEGIN
			temp := consumerState.consumerReport;
			WHILE(temp#NIL) DO
				IF temp.usages # NIL THEN
					FOR i:=0 TO temp.reportCount-1 DO
						IF(temp.usages[i].usageValue#0)THEN
							IF HidParser.IDMainIsVariable IN SYSTEM.VAL(SET,temp.mainState) THEN
								IF Debug THEN
									KernelLog.Int(temp.usages[i].usageID,0);
									KernelLog.String(" ("); UsagePage.PrintUsagePage(UsagePage.ConsumerPage, temp.usages[i].usageID);
								END;
								IF(consumerState.IsSet(temp.usages[i].usageID,temp.usages[i].usagePage)=FALSE) THEN
									consumerState.AddKey(temp.usages[i]);
									consumerState.SendKeySym(temp.usages[i].usageID, temp.usages[i].usagePage, TRUE);
								END;
							ELSE
								(*the data is sent in an array*)
								IF UsbHidReport.UseUsageDictionaryExt THEN
									IF Debug THEN
										KernelLog.String("-> usage dictionary  index: "); KernelLog.Int(temp.usages[i].usageValue,0); KernelLog.String(";     ");
									END;
									usageTuple := reportManager.GetDictKey(temp.usages[i].usageValue-temp.logicalMinimum, temp.supportedUsages);
									(*dictUsage := usageTuple.usageID;
									KernelLog.String("usageID is "); KernelLog.Int(usageTuple.usagePage,0); KernelLog.String("  "); KernelLog.Hex(dictUsage,0); KernelLog.Ln;*)
									IF (consumerState.IsSet(usageTuple.usageID,usageTuple.usagePage)=FALSE) THEN
										consumerState.AddKey(usageTuple);
										consumerState.SendKeySym(usageTuple.usageID, usageTuple.usagePage, TRUE);
									END;
									IF Debug THEN
										KernelLog.Int(dictUsage,0);
										KernelLog.String(" (");
										IF usageTuple.usagePage # 0 THEN
											UsagePage.PrintUsagePage(usageTuple.usagePage, dictUsage);
										ELSE
											UsagePage.PrintUsagePage(UsagePage.ConsumerPage, dictUsage);
										END;
									END;
								ELSE
									IF Debug THEN
										KernelLog.Int(temp.usages[i].usageValue,0);
										KernelLog.String(" ("); UsagePage.PrintUsagePage(UsagePage.ConsumerPage, temp.usages[i].usageValue);
									END;
									IF (consumerState.IsSet(temp.usages[i].usageValue,temp.usages[i].usagePage)=FALSE) THEN
										consumerState.AddKey(temp.usages[i]);
										consumerState.SendKeySym(temp.usages[i].usageValue,temp.usages[i].usagePage, TRUE);
									END;
								END;
							END;
							IF Debug THEN KernelLog.String(") pressed."); KernelLog.Ln; END;
						END;
					END;
				END;
				temp := temp.next;
			END;
			consumerState.CleanUp;
		END HandleConsumerDriver;

		(**
		 * Is called by handleHidEvent when joystick device is found
		 *)
		 PROCEDURE HandleJoystickDriver;
		VAR
			msg : 		Joystick.JoystickDataMessage;
			i:			LONGINT;
		BEGIN
			FOR i:=0 TO joystickState.buttonCount-1 DO
				IF (joystickState.buttons[i].usageValue#0) THEN
					msg.buttons := msg.buttons + {joystickState.buttons[i].usageID-1};
				END;
			END;

			IF joystickState.x # NIL THEN
				IF joystickState.xReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisX] := TwosComplement(joystickState.x.usageValue,joystickState.xReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisX] := joystickState.x.usageValue;
				END;
			END;

			IF joystickState.y # NIL THEN
				IF joystickState.yReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisY] := TwosComplement(joystickState.y.usageValue,joystickState.yReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisY] := joystickState.y.usageValue;
				END;
			END;

			IF joystickState.z # NIL THEN
				IF joystickState.zReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisZ] := TwosComplement(joystickState.z.usageValue,joystickState.zReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisZ] := joystickState.z.usageValue;
				END;
			END;

			IF joystickState.rx # NIL THEN
				IF joystickState.rxReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisRx] := TwosComplement(joystickState.rx.usageValue,joystickState.rxReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisRx] := joystickState.rx.usageValue;
				END;
			END;

			IF joystickState.ry # NIL THEN
				IF joystickState.ryReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisRy] := TwosComplement(joystickState.ry.usageValue,joystickState.ryReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisRy] := joystickState.ry.usageValue;
				END;
			END;

			IF joystickState.rz # NIL THEN
				IF joystickState.rzReport.logicalMinimum<0 THEN
					msg.axis[Joystick.AxisRz] := TwosComplement(joystickState.rz.usageValue,joystickState.rzReport.reportSize);
				ELSE
					msg.axis[Joystick.AxisRz] := joystickState.rz.usageValue;
				END;
			END;

			IF joystickState.slider # NIL THEN
				IF joystickState.sliderReport.logicalMinimum<0 THEN
					msg.axis[Joystick.Slider1] := TwosComplement(joystickState.slider.usageValue,joystickState.sliderReport.reportSize);
				ELSE
					msg.axis[Joystick.Slider1] := joystickState.slider.usageValue;
				END;
			END;

			IF joystickState.hatSwitch # NIL THEN
				CASE (joystickState.hatSwitch.usageValue-joystickState.hatSwitchReport.logicalMinimum+1) OF
					1:	msg.coolieHat[0]:= {Joystick.HatUp};
					|2: 	msg.coolieHat[0]:= {Joystick.HatUp}+{Joystick.HatLeft};
					|3:	msg.coolieHat[0]:= {Joystick.HatLeft};
					|4:	msg.coolieHat[0]:= {Joystick.HatLeft}+{Joystick.HatDown};
					|5:	msg.coolieHat[0]:= {Joystick.HatDown};
					|6:	msg.coolieHat[0]:= {Joystick.HatDown}+{Joystick.HatRight};
					|7:	msg.coolieHat[0]:= {Joystick.HatRight};
					|8:	msg.coolieHat[0]:= {Joystick.HatRight}+{Joystick.HatUp};
				ELSE

				END;
			END;

			joystickState.joystick.Handle(msg);
		END HandleJoystickDriver;

		(**
		 * checks, whether the device sends mouse informations or not
		 *)
		PROCEDURE InitializeMouseDriver():BOOLEAN;
		VAR
			mouseCollection	: UsbHidReport.HidCollection;
			temp			: UsbHidReport.HidReport;
			i				: LONGINT;
			isReportProtocol: BOOLEAN;
		BEGIN
			(*get mouse collection: mouse collection uses UsagePage(Generic Desktop Controlsl)->1 and Usage(Mouse)->2*)
			mouseCollection := reportManager.GetCollection(1,2);
			IF (mouseCollection#NIL) THEN
				NEW(mouseState);
				mouseState.buttonCount := 0;
				FOR i:=0 TO 31 DO
					IF( mouseState.buttonReport = NIL) THEN
						mouseState.buttons[i] := reportManager.GetUsage(UsagePage.ButtonPage, i+1, mouseCollection,mouseState.buttonReport);
					ELSE
						mouseState.buttons[i] := reportManager.GetUsage(UsagePage.ButtonPage, i+1, mouseCollection,temp);
					END;
					IF(mouseState.buttons[i]#NIL) THEN
						mouseState.buttonCount := i;
					END;
					(*KernelLog.String("mouseState.buttons ["); KernelLog.Int(i,0); KernelLog.String("] is ");
					KernelLog.Int(SYSTEM.VAL(LONGINT, mouseState.buttons[i]),0); KernelLog.Ln;*)
				END;
				mouseState.x := reportManager.GetUsage(UsagePage.GenericDesktopPage, 30H, mouseCollection,mouseState.axisReport);
				IF(mouseState.x=NIL) THEN
					KernelLog.String("Initialize mouse driver: error did not find x axis"); KernelLog.Ln;
				END;
				IF(mouseState.axisReport=NIL) THEN
					KernelLog.String("InitializeMouseDriver: Error: Did not find axis report"); KernelLog.Ln;
				END;
				mouseState.y 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 31H, mouseCollection,temp);
				IF(mouseState.y=NIL) THEN
					KernelLog.String("Initialize mouse driver: error did not find y axis"); KernelLog.Ln;
				END;
				mouseState.wheel	:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 38H, mouseCollection,mouseState.wheelReport);
				IF(mouseState.wheel=NIL) THEN
					KernelLog.String("Initialize mouse driver: warning did not find wheel"); KernelLog.Ln;
				END;
				IF Trace THEN
					KernelLog.String("Found Mouse Configuration"); KernelLog.Ln;
					KernelLog.String("Mouse Driver initialized");KernelLog.Ln;
				END;
				isReportProtocol := SetReportProtocol();
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END InitializeMouseDriver;

		(**
		 * checks, whether the device sends keyboard informations or not
		 *)
		PROCEDURE InitializeKeyboardDriver():BOOLEAN;
		VAR
			keyboardColl: UsbHidReport.HidCollection;
			aUsageTuple : UsbHidReport.UsageTuple;
			modifierReport: UsbHidReport.HidReport;
			keycodeReport: UsbHidReport.HidReport;
		BEGIN
			keyboardColl:= reportManager.GetCollection(UsagePage.GenericDesktopPage,UsagePage.KeyboardPage);
			IF(keyboardColl#NIL) THEN
				IF ~SetIdle(0,10) THEN
					IF Debug THEN KernelLog.String("UsbKeyboard: Error: Cannot set idle the keyboard."); KernelLog.Ln; END;
				END;
				NEW(keyboardState);
				keyboardState.Init;

				aUsageTuple:= reportManager.GetUsage(UsagePage.KeypadPage, 224,
						keyboardColl, modifierReport);
				IF (modifierReport=NIL) THEN
					IF Debug THEN KernelLog.String("Error did not find modifier"); KernelLog.Ln; END;
					keyboardState := NIL;
					RETURN FALSE;
				ELSE
					IF (modifierReport.usages=NIL) THEN
						IF Debug THEN KernelLog.String("Error did not find modifiers usages"); KernelLog.Ln; END;
						keyboardState := NIL;
						RETURN FALSE;
					ELSE
						IF (LEN(modifierReport.usages)<8) THEN
							keyboardState := NIL;
							RETURN FALSE;
						END;
					END;
					keyboardState.modifierUsages := modifierReport.usages;
				END;

				(*assume that the keycodes always begin at usage 0*)
				aUsageTuple:= reportManager.GetUsage(UsagePage.KeypadPage, 0,
						keyboardColl, keycodeReport);
				IF(keycodeReport=NIL) THEN
					IF Debug THEN KernelLog.String("Error did not find keycodeReport"); KernelLog.Ln; END;
					keyboardState := NIL;
					RETURN FALSE;
				ELSE
					IF(keycodeReport.usages=NIL) THEN
						keyboardState := NIL;
						IF Debug THEN KernelLog.String("Error did not find keycodeReports usages"); KernelLog.Ln; END;
						RETURN FALSE;
					(*ELSE
						IF (LEN(modifierReport.usages)<8) THEN
							keyboardState := NIL;
							RETURN FALSE;
						END;*)
					END;
				END;
				keyboardState.keycodeUsages := keycodeReport.usages;
				keyboardState.SetMaxKeycodes(LEN(keycodeReport.usages));
				RETURN SetReportProtocol();
			ELSE
				RETURN FALSE;
			END;
		END InitializeKeyboardDriver;

		(**
		 * checks, whether the device sends consumer informations or not
		 *)
		PROCEDURE InitializeConsumerDriver():BOOLEAN;
		VAR
			consumerColl	: UsbHidReport.HidCollection;
			temp			: UsbHidReport.HidReport;
			usageCounter	: LONGINT;
		BEGIN
			consumerColl := reportManager.GetCollection(UsagePage.ConsumerPage, 1H);
			IF consumerColl # NIL THEN
				NEW(consumerState);
				consumerState.consumerReport := consumerColl.firstReport;
				IF consumerState.consumerReport # NIL THEN
					temp := consumerState.consumerReport;
					WHILE (temp # NIL) DO
							usageCounter := usageCounter + temp.reportCount;
						temp := temp.next;
					END;
					temp := consumerState.consumerReport;
					RETURN TRUE;
				ELSE
					consumerState := NIL;
				END;
			END;
			RETURN FALSE;
		END InitializeConsumerDriver;

		(**
		 * checks, whether the device sends joystick informations or not
		 *)
		 PROCEDURE InitializeJoystickDriver():BOOLEAN;
		VAR
			joystickColl		: UsbHidReport.HidCollection;
			temp			: UsbHidReport.HidReport;
			res,i			: LONGINT;
		BEGIN
			(*get joystick collection: joystick collection uses UsagePage(Generic Desktop Controlsl)->1 and Usage(Joystick)->4*)
			joystickColl := reportManager.GetCollection(UsagePage.GenericDesktopPage,4);
			IF (joystickColl#NIL) THEN
				NEW(joystickState);
				joystickState.buttonCount := 0;
				FOR i:=0 TO 31 DO
					IF( joystickState.buttonReport = NIL) THEN
						joystickState.buttons[i] := reportManager.GetUsage(UsagePage.ButtonPage, i+1, joystickColl,joystickState.buttonReport);
						(*KernelLog.String("Found button report"); KernelLog.Ln;*)
					ELSE
						joystickState.buttons[i] := reportManager.GetUsage(UsagePage.ButtonPage, i+1, joystickColl,temp);
					END;
					IF(joystickState.buttons[i]#NIL) THEN
						joystickState.buttonCount := joystickState.buttonCount +1;
						(*KernelLog.String(" button ");
						KernelLog.Int(joystickState.buttonReport.usages[i].usageID,0);  KernelLog.Ln;*)
					END;
				END;

				IF Debug THEN
					KernelLog.String("Found Joystick Configuration"); KernelLog.Ln;
				END;

				NEW(joystickState.joystick,joystickState.buttonCount);
				joystickState.joystick.desc := "USBHIDJoystick";

				joystickState.x := reportManager.GetUsage(UsagePage.GenericDesktopPage, 30H, joystickColl,joystickState.xReport);
				IF(joystickState.x#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisX, joystickState.xReport.logicalMinimum, joystickState.xReport.logicalMaximum);
				END;

				joystickState.y 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 31H, joystickColl,joystickState.yReport);
				IF(joystickState.y#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisY, joystickState.yReport.logicalMinimum, joystickState.yReport.logicalMaximum);
				END;

				joystickState.z 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 32H, joystickColl,joystickState.zReport);
				IF(joystickState.z#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisZ, joystickState.zReport.logicalMinimum, joystickState.zReport.logicalMaximum);
				END;

				joystickState.rx 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 33H, joystickColl,joystickState.rxReport);
				IF(joystickState.rx#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisRx, joystickState.rxReport.logicalMinimum, joystickState.rxReport.logicalMaximum);
				END;

				joystickState.ry 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 34H, joystickColl,joystickState.ryReport);
				IF(joystickState.ry#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisRy, joystickState.ryReport.logicalMinimum, joystickState.ryReport.logicalMaximum);
				END;

				joystickState.rz 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 35H, joystickColl,joystickState.rzReport);
				IF(joystickState.rz#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.AxisRz, joystickState.rzReport.logicalMinimum, joystickState.rzReport.logicalMaximum);
				END;

				joystickState.slider	:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 36H, joystickColl,joystickState.sliderReport);
				IF(joystickState.slider#NIL) THEN
					joystickState.joystick.AddAxis(Joystick.Slider1, joystickState.sliderReport.logicalMinimum, joystickState.sliderReport.logicalMaximum);
				END;

				joystickState.hatSwitch:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 39H, joystickColl,joystickState.hatSwitchReport);
				IF(joystickState.hatSwitch#NIL) THEN
					IF (joystickState.hatSwitchReport.logicalMaximum-joystickState.hatSwitchReport.logicalMinimum=7) THEN
						joystickState.joystick.AddCoolieHat();
					ELSE
						KernelLog.String("HatSwitch found, but not compatible. HatSwitch events are not sent to Joysticks.."); KernelLog.Ln;
					END;
				END;

				Joystick.registry.Add(joystickState.joystick,res);
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END InitializeJoystickDriver;

		(**
		 * checks, whether the device sends mouse informations or not
		 *)
		PROCEDURE InitializeTouchscreenDriver():BOOLEAN;
		VAR
			mouseCollection	: UsbHidReport.HidCollection;
			temp			: UsbHidReport.HidReport;
			i				: LONGINT;
			isReportProtocol: BOOLEAN;
		BEGIN
			(*get mouse collection: mouse collection uses UsagePage(Generic Desktop Controlsl)->1 and Usage(Mouse)->2*)
			mouseCollection := reportManager.GetCollection(0DH, 04H);
			IF (mouseCollection#NIL) THEN
				NEW(touchscreenState);
				touchscreenState.prev := FALSE;
				touchscreenState.x 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 30H, mouseCollection,temp);
				touchscreenState.minX := temp.logicalMinimum;
				touchscreenState.maxX := temp.logicalMaximum;
				touchscreenState.y 		:= reportManager.GetUsage(UsagePage.GenericDesktopPage, 31H, mouseCollection,temp);
				touchscreenState.minY := temp.logicalMinimum;
				touchscreenState.maxY := temp.logicalMaximum;
				touchscreenState.tipSwitch := reportManager.GetUsage(0DH, 042H, mouseCollection,temp);
				touchscreenState.inRange := reportManager.GetUsage(0DH, 032H, mouseCollection,temp);
				touchscreenState.confidence := reportManager.GetUsage(0DH, 047H, mouseCollection, temp); 
				KernelLog.String("Touchscreen device registered with ");
				KernelLog.String("minX = "); KernelLog.Int(touchscreenState.minX,1); 
				KernelLog.String(", maxX = "); KernelLog.Int(touchscreenState.maxX,1); 
				KernelLog.String(", minY = "); KernelLog.Int(touchscreenState.minY,1); 
				KernelLog.String(", maxY = "); KernelLog.Int(touchscreenState.maxY,1); 
				IF touchscreenState.confidence # NIL THEN KernelLog.String(", confidence"); END; 
				KernelLog.Ln;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END InitializeTouchscreenDriver;


		(**
		 * Reads bitlen bits from a position index
		 * @param index[in bits]: where to start reading [1..32]
		 * @param bitLen: the amount of bits to read
		 * @return value
		 *)
		 PROCEDURE ReadBits(index, bitLen: LONGINT):LONGINT;
		VAR rv : LONGINT;
		BEGIN
			rv := ReadBitsBuffer(index,bitLen,reportBuffer);
			RETURN rv;
		END ReadBits;

		 (**
		 * Reads bitlen bits from a position index
		 * @param index[in bits]: where to start reading [1..32]
		 * @param bitLen: the amount of bits to read
		 * @param localBuf: the buffer to read from
		 * @return value
		 *)
		PROCEDURE ReadBitsBuffer(index, bitLen: LONGINT; localBuf: Usbdi.BufferPtr):LONGINT;
		VAR
			endIndex	: LONGINT;
			rv			: LONGINT;
			temp		: LONGINT;
			indexEightAligned : LONGINT;
			bitsToShift	: LONGINT;
			set			: SET;
		BEGIN
			endIndex := index + bitLen-1;

			IF bitLen<=0 THEN RETURN 0 END;

			IF Debug THEN KernelLog.String("read bits from "); KernelLog.Int(index,0); KernelLog.String(" to "); KernelLog.Int(endIndex,0); KernelLog.Ln; END;

			IF(endIndex>=(8*LEN(localBuf))) THEN
				IF Debug THEN KernelLog.String("ReadBits: Buffer overflow, endindex is out of localBuf"); KernelLog.Ln; END;
				RETURN 0;
			END;

			IF (bitLen=1) THEN
				(*simply get the bit*)
				set := SYSTEM.VAL(SET, localBuf[index DIV 8]);
				IF (index MOD 8) IN set THEN
					rv := 1;
				ELSE
					rv := 0;
				END;
				RETURN rv;
			END;

			IF ((index DIV 8) = (endIndex DIV 8)) THEN
				(*detect reading simple byte*)

				temp := SYSTEM.VAL(LONGINT, ORD(localBuf[index DIV 8]));

				IF (bitLen=8) THEN
					rv:= temp;
					IF Debug THEN
						KernelLog.String("the byte value is: "); KernelLog.Int(rv,0); KernelLog.Ln;
					END;
					RETURN rv;
				ELSE
					(*simply read in the byte index DIV 8*)
					IF Debug THEN
						KernelLog.Ln;
						KernelLog.String("       the value of the byte is: "); KernelLog.Int(temp,0); KernelLog.Ln;
						KernelLog.String(" (");KernelLog.Bits(SYSTEM.VAL(SET, temp),0,8); KernelLog.String(")"); KernelLog.Ln;
						KernelLog.String("       read in the byte from "); KernelLog.Int(index MOD 8,0); KernelLog.String(" to ");
						KernelLog.Int(endIndex MOD 8,0); KernelLog.String(")"); KernelLog.Ln;
					END;

					temp := SYSTEM.VAL(LONGINT,(SYSTEM.VAL(SET, temp) * {(index MOD 8)..(endIndex MOD 8)}));
					IF Debug THEN
						KernelLog.String("        the value of the byte after masking: "); KernelLog.Bits(SYSTEM.VAL(SET, temp),0,8); KernelLog.Ln;
					END;

					bitsToShift := index MOD 8;
					IF Debug THEN
						KernelLog.String("        bits to shift: "); KernelLog.Int(bitsToShift,0); KernelLog.Ln;
					END;

					rv := SYSTEM.VAL(LONGINT,LSH(SYSTEM.VAL(CHAR,temp),-bitsToShift));

					IF Debug THEN
						KernelLog.String("        the value of the byte after shifting: "); KernelLog.Bits(SYSTEM.VAL(SET, rv),0,8); KernelLog.Ln;
					END;

				END;
			ELSE
				(* the index and the endIndex are not in the same byte

					block position k of index is k="index DIV 8"
					so endBit in the same block is   eb=k * 8 + 7
					ex: given: index := 27;
					asked:	how many bits to shift the current rv to left

							k := 27 div 8
							k := 3;
							eb := 3 * 8 + 7= 31

				*)
				indexEightAligned := SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,index)+{0..2});

				IF Debug THEN
					KernelLog.String("index, indexEightAligned, endIndex");
					KernelLog.Int(index,6);KernelLog.Int(indexEightAligned,6);KernelLog.Int(endIndex,6); KernelLog.Ln;
				END;

				temp := ReadBitsBuffer(indexEightAligned+1,endIndex-indexEightAligned, localBuf);
				temp := LSH(temp,indexEightAligned-index+1);
				rv := temp + ReadBitsBuffer(index, indexEightAligned-index+1,localBuf);
			END;
			RETURN rv;
		END ReadBitsBuffer;

		(**
		 * for testing the readBits Procedure

		PROCEDURE TestReader;
		VAR
			myBuf:	Usbdi.BufferPtr;
			test:	LONGINT;
		BEGIN
			NEW(myBuf,8);

			myBuf[0] := CHR(5H);
			myBuf[1] := CHR(7H);
			myBuf[2] := CHR(55H);
			myBuf[3] := CHR(3H);
			myBuf[4] := CHR(5H);
			myBuf[5] := CHR(7H);
			myBuf[6] := CHR(0FFH);
			myBuf[7] := CHR(0FFH);


			KernelLog.Ln;
			KernelLog.String("Initialize TestReader"); KernelLog.Ln;

			KernelLog.String("myBuf[0]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[0])),0); KernelLog.Ln;
			KernelLog.String("myBuf[1]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[1])),0); KernelLog.Ln;
			KernelLog.String("myBuf[2]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[2])),0); KernelLog.Ln;
			KernelLog.String("myBuf[3]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[3])),0); KernelLog.Ln;
			KernelLog.String("myBuf[4]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[4])),0); KernelLog.Ln;
			KernelLog.String("myBuf[5]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[5])),0); KernelLog.Ln;
			KernelLog.String("myBuf[6]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[6])),0); KernelLog.Ln;
			KernelLog.String("myBuf[7]: "); KernelLog.Int(SYSTEM.VAL(LONGINT,ORD(myBuf[7])),0); KernelLog.Ln;

			IF FALSE THEN
			KernelLog.Ln;
			KernelLog.String("Starting Testcases"); KernelLog.Ln;
			KernelLog.String("Reading every bit from myBuf[0]: "); KernelLog.Bits(SYSTEM.VAL(SET,myBuf[0]),0,8); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 0:  "); KernelLog.Int(ReadBitsBuffer(0,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 1:  "); KernelLog.Int(ReadBitsBuffer(1,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 2:  "); KernelLog.Int(ReadBitsBuffer(2,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 3:  "); KernelLog.Int(ReadBitsBuffer(3,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 4:  "); KernelLog.Int(ReadBitsBuffer(4,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 5:  "); KernelLog.Int(ReadBitsBuffer(5,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 6:  "); KernelLog.Int(ReadBitsBuffer(6,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 1 bit from 7:  "); KernelLog.Int(ReadBitsBuffer(7,1,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;


			KernelLog.String("Reading 1-8 bits from myBuf[1]: "); KernelLog.Bits(SYSTEM.VAL(SET,myBuf[1]),0,8); KernelLog.Ln;
			KernelLog.String("    Read 1 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 2 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,2,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 3 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,3,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 4 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,4,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 5 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,5,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 6 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,6,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 7 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,6,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 8 bits from 8:  "); KernelLog.Int(ReadBitsBuffer(8,8,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;

			KernelLog.String("Reading 1-7 bits from myBuf[2]: "); KernelLog.Bits(SYSTEM.VAL(SET,myBuf[2]),0,8); KernelLog.Ln;
			KernelLog.String("    Read 1 bit   from 17:  "); KernelLog.Int(ReadBitsBuffer(17,1,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 2 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,2,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 3 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,3,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 4 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,4,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 5 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,5,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 6 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,6,myBuf),0); KernelLog.Ln;
			KernelLog.String("    Read 7 bits from 17:  "); KernelLog.Int(ReadBitsBuffer(17,6,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;


			KernelLog.String("Read 8 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,8,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 9 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,9,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 10 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,10,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 11 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,11,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 12 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,12,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 13 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,13,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 14 bits from 0:  "); KernelLog.Int(ReadBitsBuffer(0,14,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;

			KernelLog.String("Read 7 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,7,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 8 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,8,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 9 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,9,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 10 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,10,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 11 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,11,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 12 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,12,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 13 bits from 1:  "); KernelLog.Int(ReadBitsBuffer(1,13,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;

			KernelLog.String("Read 8 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,8,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 9 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,9,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 10 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,10,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 11 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,11,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 12 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,12,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 13 bits from 23:  "); KernelLog.Int(ReadBitsBuffer(32,13,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 14 bits from 32:  "); KernelLog.Int(ReadBitsBuffer(32,14,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;

			KernelLog.String("Read 7 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,7,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 8 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,8,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 9 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,9,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 10 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,10,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 11 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,11,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 12 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,12,myBuf),0); KernelLog.Ln;
			KernelLog.String("Read 13 bits from 33:  "); KernelLog.Int(ReadBitsBuffer(33,13,myBuf),0); KernelLog.Ln;
			KernelLog.Ln;
			END;
			KernelLog.String("TwosComplement of 6 in (4 Bits): "); KernelLog.Int(TwosComplement(6,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 7 in (4 Bits): "); KernelLog.Int(TwosComplement(7,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 8 in (4 Bits): "); KernelLog.Int(TwosComplement(8,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 13 in (4 Bits): "); KernelLog.Int(TwosComplement(13,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 14 in (4 Bits): "); KernelLog.Int(TwosComplement(14,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 15 in (4 Bits): "); KernelLog.Int(TwosComplement(15,4),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 15 in (5 Bits): "); KernelLog.Int(TwosComplement(15,5),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 16 in (5 Bits): "); KernelLog.Int(TwosComplement(16,5),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 28 in (5 Bits): "); KernelLog.Int(TwosComplement(28,5),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 29 in (5 Bits): "); KernelLog.Int(TwosComplement(29,5),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 30 in (5 Bits): "); KernelLog.Int(TwosComplement(30,5),0); KernelLog.Ln;
			KernelLog.String("TwosComplement of 31 in (5 Bits): "); KernelLog.Int(TwosComplement(31,5),0); KernelLog.Ln;
			KernelLog.Ln;

			test := ReadBitsBuffer(48,12, myBuf);
			KernelLog.String("Reading 12 Bits at block 6 (starting at 48, 12 bits: "); KernelLog.Int(test,0); KernelLog.Ln;
			KernelLog.String("      ?= 4095. Twos Complement should be -1: "); KernelLog.Int(TwosComplement(test,12),0); KernelLog.Ln;

			test := ReadBitsBuffer(49,12, myBuf);
			KernelLog.String("Reading 12 Bits at block 6 (starting at 49, 12 bits: "); KernelLog.Int(test,0); KernelLog.Ln;
			KernelLog.String("      ?= 4095. Twos Complement should be -1: "); KernelLog.Int(TwosComplement(test,12),0); KernelLog.Ln;


		END TestReader;
		*)

		(**
		 * returns the twos complement of a value by the predicted bitLen
		 * @param value: the value to convert
		 * @param bitLen: the bit length of the value it can have
		 * @return twos complement of value
		 *)
		PROCEDURE TwosComplement(value: LONGINT; bitLen: LONGINT) : LONGINT;
		VAR toMuch : LONGINT;
		BEGIN
			IF(bitLen<32) & (bitLen>0) THEN
				IF ((bitLen-1) IN SYSTEM.VAL(SET,value)) THEN
					toMuch:= SYSTEM.VAL(LONGINT,{bitLen});
					value := value - toMuch;
				END;
			END;
			RETURN value;
		END TwosComplement;

		(**
		 * Sets the device into normal mode (report protocol mode)
		 *)
		PROCEDURE SetReportProtocol():BOOLEAN;
		VAR
			(*0: if boot protocol, 1: if report protocol*)
			bootFlag:	LONGINT;
		BEGIN
			IF (GetProtocol(bootFlag)) THEN
				IF(bootFlag=0) THEN
					IF Debug THEN
						KernelLog.String("UsbHidDriver:HidDriver.Connect: GetProtocol returned boot protocol, set to report protocol"); KernelLog.Ln;
					END;
					IF(SetProtocol(1)=FALSE) THEN
						KernelLog.String("UsbHidDriver:HidDriver.Connect: SetProtocol to report failed"); KernelLog.Ln;
						RETURN FALSE;
					END;
				ELSE
					IF Debug THEN
						KernelLog.String("UsbHidDriver:HidDriver.Connect: GetProtocol returned report protocol"); KernelLog.Ln;
					END;
				END;
			END;
			RETURN TRUE;
		END SetReportProtocol;

	END HidDriver;

(*used for debug output. lists the report descriptor as described in Device Class Definition for Human Interface Devices,
	f.e. page 61 Appendix A, B.2 Protocol 2 (Mouse)*)
PROCEDURE LayoutBuffer*(CONST buf : Usbdi.Buffer;  len : LONGINT);
VAR temp : LONGINT;
BEGIN
	KernelLog.String("Buffer Outline:"); KernelLog.Ln;
	FOR temp := 0 TO len-1 DO
		IF (temp MOD 2 = 0) THEN
			KernelLog.Ln();
			KernelLog.Int(temp, 4);
			KernelLog.String("    ");
			KernelLog.Hex(ORD(buf[temp]), -2);
		ELSE
			KernelLog.String("    ");
			KernelLog.Hex(ORD(buf[temp]), -2);
		END;
	END;
	KernelLog.Ln(); KernelLog.Ln();
END LayoutBuffer;

(*check, whether the device is a hid device
 *	return 	HidDriver, if hid device found, NIL otherwise
 *)
PROCEDURE Probe(dev : Usbdi.UsbDevice; if : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR hidDriver : HidDriver;
BEGIN
	IF if.bInterfaceClass # 3 THEN RETURN NIL END;
	NEW(hidDriver);
	RETURN hidDriver;
END Probe;

(* Called, when detaching the UsbHidDriver *)
PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

PROCEDURE Install*;
END Install;

TYPE 
	DimensionGetter= PROCEDURE {DELEGATE} (VAR w,h: LONGINT);
VAR
	getDisplayDimensions: DimensionGetter;
	touchConfidenceDelay: LONGINT;

PROCEDURE DefaultDisplayDimensions(VAR w,h: LONGINT);
BEGIN
	w := 1024; h := 768;
END DefaultDisplayDimensions;

PROCEDURE InstallDisplayDimensions*(poller: DimensionGetter); (* for touchscreen coordinate transformation*)
BEGIN
	IF poller # NIL THEN
		getDisplayDimensions := poller;
	ELSE 
		getDisplayDimensions := DefaultDisplayDimensions;
	END;
END InstallDisplayDimensions;


PROCEDURE Setup;
VAR s: ARRAY 32 OF CHAR; p: LONGINT;
BEGIN
	getDisplayDimensions := DefaultDisplayDimensions;
	Machine.GetConfig("TouchDelay", s);
	IF s[0] # 0X THEN
		p := 0;  touchConfidenceDelay := Machine.StrToInt(p, s)
	ELSE
		touchConfidenceDelay := 0; 
	END;
	Usbdi.drivers.Add(Probe, Name, Description, 10);
END Setup;


BEGIN
	Modules.InstallTermHandler(Cleanup);
	Setup;
END UsbHidDriver.

UsbHidDriver.Install ~  SystemTools.Free UsbHidDriver UsbHidParser UsbHidErrors UsbHidParserExt UsbHidReport UsbHidUP~
