MODULE UsbKeyboard; (** AUTHOR "cplattner; staubesv"; PURPOSE "Bluebottle USB Keyboard Driver" *) (** non-portable **)
(**
 * Bluebottle USB Keyboard Driver (HID boot protocol)
 *
 * Usage:
 *
 *	UsbKeyboard.Install ~ loads this driver		SystemTools.Free UsbKeyboard ~ unloads it
 *
 *	UsbKeyboard.SetLayout dev file ~ sets the keyboard layout
 * 	UsbKeyboard.SetLayout UsbKeyboard00 KeyCH.Bin ~ sets the CH keyboard layout, for example
 *
 * References:
 *
 *	Device Class Definition for Human Interface Devices (HID), version 1.11
 *	HID Usage Tables, version 1.11
 *
 *	References are available at http://www.usb.org
 *
 * History:
 *
 *	30.09.2000 	cp first release
 *	18.10.2000 	cp fix size of interrupt endpoint and add warning message if keyboard fails
 *	27.02.2006	Correct handling for modifier keys (also generate event if only a modifier key is pressed) (staubesv)
 *	01.03.2006	Added SetLayout & KeyboardDriver.SetLayout (staubesv)
 *	22.01.2007	Splitted up Keyboard Driver for HID compatibility (ottigerm)
 *)

IMPORT SYSTEM, Machine, Files, Inputs, Commands, KernelLog, Streams, Plugins, Modules, Usb, Usbdi, UsbHid;

CONST

	Name = "UsbKeyboard";
	Description = "USB Keyboard Driver";
	Priority = 10;

	NumLock* = 0;
	CapsLock* = 1;
	ScrollLock* = 2;
	(* Compose & kana not yet implemented *)
	Compose = 3;
	Kana = 4;

	(* If you press a key and hold it down, the following will happen:					*)
	(* 1. A Inputs.KeyboardMsg is sent											*)
	(* 2. No further messages are sent until the period KeyDeadTime expires			*)
	(* 3. Further messages are sent with the interval KeyDeadTimeRepeat				*)
	(*																				*)
	(* A release event is sent when you release the key.								*)
	(* The values KeyDeadTime and KeyDeadTimeRepeat are set in milliseconds. 		*)
	(*																				*)
	KeyDeadTime* = 100;
	KeyDeadTimeRepeat* = 0;  (* 10 <= value < infinity  && value mod 10 = 0 *)

	TraceKeys* = FALSE; (* Displays scan code of pressed key on KernelLog if TRUE *)
	Debug* = TRUE;

TYPE

	Key* = RECORD
		ch* : CHAR;
		keysym* : LONGINT;
		counter* : LONGINT;
		repeat* : BOOLEAN;
		updated* : BOOLEAN;
	END;

TYPE

	KeyboardBase*=OBJECT
	VAR
		msg*, lastMsg : Inputs.KeyboardMsg;
		lastFlags : SET;

		numKeyVal : LONGINT;
		deadKey* : LONGINT;
		dkHack* : LONGINT;  (* deadKey value should persist Release events ... *)

		(* Status of NumLock,ScrollLock,CapsLock,Compose & Kana *)
		leds*, lastLeds* : SET;
		ledBuffer* : Usbdi.BufferPtr;

		keyboardFileTable : POINTER TO ARRAY OF CHAR;
		keytable* : ADDRESS; (* used as pointer to keyboardFileTable[0] *)

		keyDeadTime*, keyDeadTimeRepeat* : LONGINT;


		PROCEDURE HandleKey*(c : CHAR);
		VAR k : LONGINT;
		BEGIN
			(* map USB Usage ID to keysym: Only non-alphanumeric keys are mapped by Keysym()  *)
			msg.keysym := KeySym(c, leds);
			IF TraceKeys THEN KernelLog.String("USB Usage ID: "); KernelLog.Hex(ORD(c), -3); END;
			(* map USB Usage ID to Oberon key code *)
			SYSTEM.GET(UsbScanTab() + ORD(c), c);
			IF TraceKeys THEN KernelLog.String(" -> Oberon key code: "); KernelLog.Hex(ORD(c), -3) END;

			IF c = CHR(58) THEN  leds := leds / {CapsLock};
			ELSIF c = CHR(69) THEN leds := leds / {NumLock};
			ELSIF c = CHR(70) THEN leds := leds / {ScrollLock};
			ELSE
				k := Translate(msg.flags, leds, c, keytable, deadKey, numKeyVal);
				IF TraceKeys THEN KernelLog.String(" translated into: "); KernelLog.Char(CHR(k)); END;
				(* if c is an ASCII character, then map c to keysym *)
				IF (k  >= 1) & (k  <= 126) & (msg.keysym = Inputs.KsNil)  THEN msg.keysym := k; END;
				IF k >= 0 THEN msg.ch := CHR(k) ELSE msg.ch := 0X END;
				IF TraceKeys THEN
					KernelLog.String(" Aos Keysym: "); IF msg.keysym = Inputs.KsNil THEN KernelLog.String("No Key"); ELSE KernelLog.Hex(msg.keysym, 9); END;
					KernelLog.Ln; ShowFlags(msg.flags, leds); KernelLog.Ln;
				END;
				(* build up message for this event *)
				IF (msg.flags # lastMsg.flags) OR (msg.ch # 0X) OR (msg.keysym # Inputs.KsNil) THEN
					Inputs.keyboard.Handle(msg);
				END;
				lastMsg := msg;
			END;
		END HandleKey;

		PROCEDURE HandleModifiers*(flags : SET);
		VAR i : LONGINT;
		BEGIN
			IF flags # lastFlags THEN
				msg.flags := {}; msg.ch := 0X; msg.keysym := Inputs.KsNil;
				FOR i := 0 TO MAX(SET) DO
					IF (i IN flags) & ~(i IN lastFlags) THEN (* modifier key pressed for the first time *)
						msg.flags := {i}; msg.keysym := GetModifierKeysym(i);
						Inputs.keyboard.Handle(msg);
					ELSIF ~(i IN flags) & (i IN lastFlags) THEN (* modifier key released *)
						msg.flags := {Inputs.Release}; msg.keysym := GetModifierKeysym(i);
						Inputs.keyboard.Handle(msg);
					END;
				END;
			END;
			lastFlags := flags;
		END HandleModifiers;

		PROCEDURE TableFromFile*(CONST name: ARRAY OF CHAR): ADDRESS;
		VAR f: Files.File; r: Files.Rider; len: LONGINT;
		BEGIN
			KernelLog.String("UsbKeyboard: "); KernelLog.String(" Loading layout "); KernelLog.String(name); KernelLog.Ln;
			f := Files.Old(name);
			IF f # NIL THEN
				len := f.Length();
				IF len MOD 4 = 0 THEN
					NEW(keyboardFileTable, len+1);
					f.Set(r, 0); f.ReadBytes(r, keyboardFileTable^, 0, len);
					IF r.res = 0 THEN
						keyboardFileTable[len] := 0FFX;
						RETURN ADDRESSOF(keyboardFileTable[0])
					ELSIF Debug THEN KernelLog.String("UsbKeyboard: TableFromFile: Error: res="); KernelLog.Int(r.res, 1); KernelLog.Ln;
					END
				ELSIF Debug THEN KernelLog.String("UsbKeyboard: TableFromFile: Error: len="); KernelLog.Int(len, 1); KernelLog.Ln;
				END
			ELSIF Debug THEN KernelLog.String("UsbKeyboard: TableFromFile: Error: File not found."); KernelLog.Ln;
			END;
			RETURN -1;
		END TableFromFile;

		PROCEDURE SetLayout*(CONST name : ARRAY OF CHAR);
		VAR adr : ADDRESS;
		BEGIN
			IF name = "KeyUS.Bin" THEN adr := TableUS();
			ELSE adr := TableFromFile(name);
			END;
			IF adr = -1 THEN (* Leave the current setting *)
			ELSE SYSTEM.PUT(ADDRESSOF(keytable), adr);
			END;
		END SetLayout;

	END KeyboardBase;

	KeyboardDriver = OBJECT (UsbHid.HidDriver)
	VAR
		pipe : Usbdi.Pipe;

 		(* buffer[0] : modifier byte					*)
		(* buffer[1] : reserved						*)
		(* buffer[2]-buffer[7] : 6 one byte key codes  	*)
		buffer : Usbdi.BufferPtr;

		base : KeyboardBase;

		(*for keeping the pressed keys in mind*)
		pressed* : ARRAY 6 OF Key;

		PROCEDURE &Init*;
		BEGIN
			NEW(base);
		END Init;

		PROCEDURE EventHandler(status : Usbdi.Status; actLen : LONGINT);
		VAR
			i, j : LONGINT;
			c : CHAR;
			modifiers, flags : SET;
			res : BOOLEAN;
			tempPressed : ARRAY 6 OF Key;
			found, kill : BOOLEAN;
		BEGIN
			IF (status=Usbdi.Ok) OR ((status = Usbdi.ShortPacket) & (actLen >= 8)) THEN

				(* evaluate modifier keys *)
				base.msg.flags := {};
				modifiers := SYSTEM.VAL(SET, buffer[0]);
				IF modifiers * {0} # {} THEN INCL(base.msg.flags, Inputs.LeftCtrl) END;
				IF modifiers * {1} # {} THEN INCL(base.msg.flags, Inputs.LeftShift) END;
				IF modifiers * {2} # {} THEN INCL(base.msg.flags, Inputs.LeftAlt) END;
				IF modifiers * {3} # {} THEN INCL(base.msg.flags, Inputs.LeftMeta) END;
				IF modifiers * {4} # {} THEN INCL(base.msg.flags, Inputs.RightCtrl) END;
				IF modifiers * {5} # {} THEN INCL(base.msg.flags, Inputs.RightShift) END;
				IF modifiers * {6} # {} THEN INCL(base.msg.flags, Inputs.RightAlt) END;
				IF modifiers * {7} # {} THEN INCL(base.msg.flags, Inputs.RightMeta) END;
				flags := base.msg.flags;

				(* evaluate the six keycodes *)
				FOR i := 2 TO 7 DO
					c := buffer[i];
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
									IF (base.keyDeadTimeRepeat # 0) & (tempPressed[i-2].counter MOD base.keyDeadTimeRepeat # 0) THEN (* don't send key event *) kill := TRUE; END;
								ELSE
									IF tempPressed[i-2].counter MOD base.keyDeadTime # 0 THEN (* don't send key event *)
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
				    	base.HandleKey(c);
				    	tempPressed[i-2].keysym := base.msg.keysym; (* base.msg.keysym asigned by HandleKey() ... *)
				    END;
				END; (* FOR LOOP *)

				(* update pressed array. generate keyboard.base.msg's for released keys *)
				FOR i := 0 TO 5 DO
					IF (pressed[i].updated = FALSE) & (pressed[i].ch # CHR(0)) THEN (* this key has been released *)
						base.msg.flags := {};
						INCL(base.msg.flags, Inputs.Release);
						base.msg.ch := pressed[i].ch;
						base.msg.keysym := pressed[i].keysym;
						base.dkHack := base.deadKey;  (* value of deadKey should persist the key release event *)
						base.HandleKey(c);
						base.deadKey := base.dkHack;
					END;
					pressed[i].counter := tempPressed[i].counter;
					pressed[i].ch := tempPressed[i].ch;
					pressed[i].keysym := tempPressed[i].keysym;
					pressed[i].repeat := tempPressed[i].repeat;
					pressed[i].updated := FALSE;
				END;

				(* Generate events for modifiers *)
				base.HandleModifiers(flags);

				(* update status of the LEDs  of the keyboad if necessary *)
				IF base.lastLeds # base.leds THEN (* LED status has changed *)
					base.ledBuffer[0] := SYSTEM.VAL(CHAR, base.leds); base.lastLeds := base.leds;
					res := SetReport(UsbHid.ReportOutput, 0, base.ledBuffer^, 1); (* ignore res *)
				END;
				status := pipe.Transfer(pipe.maxPacketSize, 0, buffer^);
			ELSE
				IF Debug THEN KernelLog.String("UsbKeyboard: Error. Disabling keyboard "); KernelLog.String(name); KernelLog.Ln; END;
			END;
		END EventHandler;

		PROCEDURE Connect*(): BOOLEAN;
		VAR status : Usbdi.Status; endpoint: LONGINT; i: ADDRESS; k : ARRAY 32 OF CHAR;
		BEGIN
			IF ~SetProtocol(0) THEN
				IF Debug THEN KernelLog.String("UsbKeyboard: Error: Cannot set keyboard into boot protocol mode."); KernelLog.Ln; END;
				RETURN FALSE
			END;

			IF ~SetIdle(0,10) THEN
				IF Debug THEN KernelLog.String("UsbKeyboard: Error: Cannot set idle the keyboard."); KernelLog.Ln; END;
				RETURN FALSE
			END;

			endpoint := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, interface.endpoints[0].bEndpointAddress) * {0,1,2,3,7});

			pipe := device.GetPipe(endpoint);
			IF pipe = NIL THEN
				IF Debug THEN KernelLog.String("UsbKeyboard: Could not get pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* Get  *)
			Machine.GetConfig("Keyboard", k);
			i := -1;
			IF k # "" THEN i := base.TableFromFile(k); END;
			IF i = -1 THEN (* Fallback to default *) i := TableUS(); END;
			SYSTEM.PUT(ADDRESSOF(base.keytable), i);

			(* Apply Numlock boot up state *)
			Machine.GetConfig("NumLock", k);
			IF k[0] = "1" THEN INCL(base.leds, NumLock) END;

			base.keyDeadTime := KeyDeadTime DIV 10;
			base.keyDeadTimeRepeat := KeyDeadTimeRepeat DIV 10;

			NEW(base.ledBuffer, 1);

			NEW(buffer, pipe.maxPacketSize);
			pipe.SetTimeout(0);
			pipe.SetCompletionHandler(EventHandler);
			status := pipe.Transfer(pipe.maxPacketSize, 0, buffer^); (* ignore status *)

			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect*;
		BEGIN
			KernelLog.String("UsbKeyboard: USB Keyboard disconnected."); KernelLog.Ln;
		END Disconnect;

	END KeyboardDriver;

VAR

(* Translation table format:
 *
 *	table = { scancode unshifted-code shifted-code flags }  0FFX .
 *	scancode = <scancode byte from keyboard, bit 7 set for "grey" extended keys>
 *	unshifted-code = <CHAR produced by this scancode, without shift>
 *	shifted-code = <CHAR produced by this scancode, with shift>
 *	flags = <bit-mapped flag byte indicating special behaviour>
 *
 *	flag bit	function
 *		0	01	DeadKey: Set dead key flag according to translated key code (1-7)
 *		1	02	NumLock: if set, the state of NumLock will reverse the action of shift (for num keypad)
 *		2	04	CapsLock: if set, the state of CapsLock will reverse the action of shift (for alpha keys)
 *		3	08	LAlt:  \ the state of these two flags in the table and the current state of the two...
 *		4	10	RAlt: / ...Alt keys must match exactly, otherwise the search is continued.
 *		5	20	\
 *		6	40	 >  dead key number (0-7), must match current dead key flag
 *		7	80	/
 *
 *	The table is scanned sequentially (speed not critical).  Ctrl-Break, Ctrl-F10 and Ctrl-Alt-Del
 *	are always defined and are not in the table.   The control keys are also always defined.
 *)

(* TableUS - US keyboard translation table (dead keys: ^=1, '=2, `=3, ~=4, "=5) *)
PROCEDURE TableUS*(): ADDRESS;
CODE {SYSTEM.i386}
	CALL L1
L1:
	POP EAX
	ADD EAX,8
	POP EBP
	RET
		; alphabet
	DB 1EH, 'a', 'A', 4H,	30H, 'b', 'B', 4H,	2EH, 'c', 'C', 4H,	20H, 'd', 'D', 4H
	DB 12H, 'e', 'E', 4H,	21H, 'f', 'F', 4H,	22H, 'g', 'G', 4H,	23H, 'h', 'H', 4H
	DB 17H, 'i', 'I', 4H,	24H, 'j', 'J', 4H,	25H, 'k', 'K', 4H,	26H, 'l', 'L', 4H
	DB 32H, 'm', 'M', 4H,	31H, 'n', 'N', 4H,	18H, 'o', 'O', 4H,	19H, 'p', 'P', 4H
	DB 10H, 'q', 'Q', 4H,	13H, 'r', 'R', 4H,	1FH, 's', 'S', 4H,	14H, 't', 'T', 4H
	DB 16H, 'u', 'U', 4H,	2FH, 'v', 'V', 4H,	11H, 'w', 'W', 4H,	2DH, 'x', 'X', 4H
	DB 15H, 'y', 'Y', 4H,	2CH, 'z', 'Z', 4H
		; Oberon accents (LAlt & RAlt)
;	DB 1EH, 'ä', 'Ä', 0CH,	12H, 'ë', 0FFH, 0CH,	18H, 'ö', 'Ö', 0CH,	16H, 'ü', 'Ü', 0CH
;	DB 17H, 'ï', 0FFH, 0CH,	1FH, 'ß', 0FFH, 0CH,	2EH, 'ç', 0FFH, 0CH,	31H, 'ñ', 0FFH, 0CH
;	DB 1EH, 'ä', 'Ä', 14H,	12H, 'ë', 0FFH, 14H,	18H, 'ö', 'Ö', 14H,	16H, 'ü', 'Ü', 14H
;	DB 17H, 'ï', 0FFH, 14H,	1FH, 'ß', 0FFH, 14H,	2EH, 'ç', 0FFH, 14H,	31H, 'ñ', 0FFH, 14H
		; dead keys (LAlt & RAlt)
	DB 07H, 0FFH, 1H, 9H,	28H, 2H, 5H, 9H,	29H, 3H, 4H, 9H,
	DB 07H, 0FFH, 1H, 11H,	28H, 2H, 5H, 11H,	29H, 3H, 4H, 11H,
		; following keys
;	DB 1EH, 'â', 0FFH, 20H,	12H, 'ê', 0FFH, 20H,	17H, 'î', 0FFH, 20H,	18H, 'ô', 0FFH, 20H
;	DB 16H, 'û', 0FFH, 20H,	1EH, 'à', 0FFH, 60H,	12H, 'è', 0FFH, 60H,	17H, 'ì', 0FFH, 60H
;	DB 18H, 'ò', 0FFH, 60H,	16H, 'ù', 0FFH, 60H,	1EH, 'á', 0FFH, 40H,	12H, 'é', 0FFH, 40H
;	DB 1EH, 'ä', 'Ä', 0A4H,	12H, 'ë', 0FFH, 0A0H,	17H, 'ï', 0FFH, 0A0H,	18H, 'ö', 'Ö', 0A4H
;	DB 16H, 'ü', 'Ü', 0A4H,	31H, 'ñ', 0FFH, 80H
		; numbers at top
	DB 0BH, '0', ')', 0H,	02H, '1', '!', 0H,	03H, '2', '@', 0H,	04H, '3', '#', 0H
	DB 05H, '4', '$', 0H,	06H, '5', '%', 0H,	07H, '6', '^', 0H,	08H, '7', '&', 0H
	DB 09H, '8', '*', 0H,	0AH, '9', '(', 0H
		; symbol keys
	DB 28H, 27H, 22H, 0H,	33H, ',', '<', 0H,	0CH, '-', '_', 0H,	34H, '.', '>', 0H
	DB 35H, '/', '?', 0H,	27H, ';', ':', 0H,	0DH, '=', '+', 0H,	1AH, '[', '{', 0H
	DB 2BH, '\', '|', 0H,	1BH, ']', '}', 0H,	29H, '`', '~', 0H
		; control keys
	DB 0EH, 7FH, 7FH, 0H ; backspace
	DB 0FH, 09H, 09H, 0H ; tab
	DB 1CH, 0DH, 0DH, 0H ; enter
	DB 39H, 20H, 20H, 0H ; space
	DB 01H, 0FEH, 1BH, 0H ; esc
		; keypad
	DB 4FH, 0A9H, '1', 2H ; end/1
	DB 50H, 0C2H, '2', 2H ; down/2
	DB 51H, 0A3H, '3', 2H ; pgdn/3
	DB 4BH, 0C4H, '4', 2H ; left/4
	DB 4CH, 0FFH, '5', 2H ; center/5
	DB 4DH, 0C3H, '6', 2H ; right/6
	DB 47H, 0A8H, '7', 2H ; home/7
	DB 48H, 0C1H, '8', 2H ; up/8
	DB 49H, 0A2H, '9', 2H ; pgup/9
	DB 52H, 0A0H, '0', 2H ; insert/0
	DB 53H, 0A1H, 2EH, 2H ; del/.
		; gray keys
	DB 4AH, '-', '-', 0H ; gray -
	DB 4EH, '+', '+', 0H ; gray +
	DB 0B5H, '/', '/', 0H ; gray /
	DB 37H, '*', '*', 0H ; gray *
	DB 0D0H, 0C2H, 0C2H, 0H ; gray down
	DB 0CBH, 0C4H, 0C4H, 0H ; gray left
	DB 0CDH, 0C3H, 0C3H, 0H ; gray right
	DB 0C8H, 0C1H, 0C1H, 0H ; gray up
	DB 09CH, 0DH, 0DH, 0H ; gray enter
	DB 0D2H, 0A0H, 0A0H, 0H ; gray ins
	DB 0D3H, 0A1H, 0A1H, 0H ; gray del
	DB 0C9H, 0A2H, 0A2H, 0H ; gray pgup
	DB 0D1H, 0A3H, 0A3H, 0H ; gray pgdn
	DB 0C7H, 0A8H, 0A8H, 0H ; gray home
	DB 0CFH, 0A9H, 0A9H, 0H ; gray end
		; function keys
	DB 3BH, 0A4H, 0FFH, 0H ; F1
	DB 3CH, 0A5H, 0FFH, 0H ; F2
	DB 3DH, 1BH, 0FFH, 0H ; F3
	DB 3EH, 0A7H, 0FFH, 0H ; F4
	DB 3FH, 0F5H, 0FFH, 0H ; F5
	DB 40H, 0F6H, 0FFH, 0H ; F6
	DB 41H, 0F7H, 0FFH, 0H ; F7
	DB 42H, 0F8H, 0FFH, 0H ; F8
	DB 43H, 0F9H, 0FFH, 0H ; F9
	DB 44H, 0FAH, 0FFH, 0H ; F10
	DB 57H, 0FBH, 0FFH, 0H ; F11
	DB 58H, 0FCH, 0FFH, 0H ; F12
	DB 0FFH
END TableUS;

(* maps USB usage ID's to Oberon character code *)
PROCEDURE UsbScanTab*() : ADDRESS;
CODE {SYSTEM.i386}
	CALL L1
L1:
	POP EAX
	ADD EAX,8
	POP EBP
	RET
	; Keyboard table stolen from Linux Usb keyboard driver, and corrected for Oberon
	DB 000, 000, 000, 000, 030, 048, 046, 032, 018, 033, 034, 035, 023, 036, 037, 038
	DB 050, 049, 024, 025, 016, 019, 031, 020, 022, 047, 017, 045, 021 ,044, 002, 003
	DB 004, 005, 006, 007, 008, 009, 010, 011, 028, 001, 014, 015 ,057, 012, 013, 026
	DB 027, 043, 043, 039, 040, 041, 051, 052, 053, 058, 059, 060, 061, 062, 063, 064
	DB 065, 066, 067, 068, 087, 088, 099, 070, 119, 210, 199, 201, 211, 207, 209, 205
	DB 203, 208, 200, 069, 181, 055, 074, 078, 156, 079, 080, 081, 075, 076, 077, 071
	DB 072, 073, 082, 083, 086, 127, 116, 117, 085, 089, 090, 091, 092, 093, 094, 095
	DB 120, 121, 122, 123, 134, 138, 130, 132, 128, 129, 131, 137, 133, 135, 136, 113
	DB 115, 114, 000, 000, 000, 000, 000, 124, 000, 000, 000, 000, 000, 000, 000, 000
	DB 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000
	DB 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000
	DB 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000
	DB 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000
	DB 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000
	DB 029, 042, 056, 125, 097, 054, 100, 126, 164, 166, 165, 163, 161, 115, 114, 113
	DB 150, 158, 159, 128, 136, 177, 178, 176, 142, 152, 173, 140, 000, 000, 000, 000
END UsbScanTab;

(* Maps USB key code to X11 keysym (/usr/include/X11/keysymdef.h). *)
PROCEDURE KeySym*(VAR ch : CHAR; VAR leds : SET): LONGINT;
VAR res: LONGINT;
BEGIN
	CASE ch OF
		028X: res := Inputs.KsReturn (* Return *)
	    	|029X: res := Inputs.KsEscape (* Escape *)
	    	|02AX: res := Inputs.KsBackSpace (* Delete (Backspace) *)
	   	|02BX: res := Inputs.KsTab (* Tab *)
		|03AX: res := Inputs.KsF1 (* f1 *)
		|03BX: res := Inputs.KsF2 (* f2 *)
		|03CX: res := Inputs.KsF3 (* f3 *)
		|03DX: res := Inputs.KsF4 (* f4 *)
		|03EX: res := Inputs.KsF5 (* f5 *)
		|03FX: res := Inputs.KsF6 (* f6 *)
		|040X: res := Inputs.KsF7 (* f7 *)
		|041X: res := Inputs.KsF8 (* f8 *)
		|042X: res := Inputs.KsF9 (* f9 *)
		|043X: res := Inputs.KsF10 (* f10 *)
		|044X: res := Inputs.KsF11 (* f11 *)
		|045X: res := Inputs.KsF12 (* f12 *)
		|046X: res := Inputs.KsPrint (* Printscreen *)
		|047X: res := Inputs.KsScrollLock (* ScrollLock *)
		|048X: res := Inputs.KsPause (* Pause *)
		|049X: res := Inputs.KsInsert (* insert *)
		|04AX: res := Inputs.KsHome (* home *)
		|04BX: res := Inputs.KsPageUp (* pgup *)
		|04CX: res := Inputs.KsDelete (* delete *)
		|04DX: res := Inputs.KsEnd (* end *)
		|04EX: res := Inputs.KsPageDown (* pgdn *)
		|04FX: res := Inputs.KsRight (* right *)
		|050X: res := Inputs.KsLeft (* left *)
		|051X: res := Inputs.KsDown (* down *)
		|052X: res := Inputs.KsUp (* up *)
		|053X: res := Inputs.KsNumLock; (* Keypad NumLock *)
		|054X: res := Inputs.KsKPDivide (* Keypad / *)
		|055X: res := Inputs.KsKPMultiply (* Keypad * *)
		|056X: res := Inputs.KsKPSubtract (* Keypad - *)
		|057X: res := Inputs.KsKPAdd (* Keypad + *)
		|058X: res := Inputs.KsReturn (* Keypad Enter: Should be KsKPEnter *)
		|059X: IF ~(NumLock IN leds) THEN res := Inputs.KsEnd; ELSE res := Inputs.KsNil END;  (* Keypad 1 and End *)
		|05AX: IF ~(NumLock IN leds) THEN res := Inputs.KsDown; ELSE res := Inputs.KsNil END;  (* Keypad 2 and Down Arrow *)
		|05BX: IF ~(NumLock IN leds) THEN res := Inputs.KsPageDown; ELSE res := Inputs.KsNil END;  (* Keypad 3 and PageDown *)
		|05CX: IF ~(NumLock IN leds) THEN res := Inputs.KsLeft; ELSE res := Inputs.KsNil END;  (* Keypad 4 and Left Arrow *)
		|05DX: IF ~(NumLock IN leds) THEN ch := 0X; res := Inputs.KsNil; ELSE res := Inputs.KsNil END; (* don't report key event !! *)
		|05EX: IF ~(NumLock IN leds) THEN res := Inputs.KsRight; ELSE res := Inputs.KsNil END;  (* Keypad 6 and Right Arrow *)
		|05FX: IF ~(NumLock IN leds) THEN res := Inputs.KsHome; ELSE res := Inputs.KsNil END;  (* Keypad 7 and Home *)
		|060X: IF ~(NumLock IN leds) THEN res := Inputs.KsUp; ELSE res := Inputs.KsNil END;  (* Keypad 8 and Up Arrow *)
		|061X: IF ~(NumLock IN leds) THEN res := Inputs.KsPageUp; ELSE res := Inputs.KsNil END;  (* Keypad 9 and Page Up *)
		|062X: IF ~(NumLock IN leds) THEN res := Inputs.KsInsert; ELSE res := Inputs.KsNil END;  (* Keypad 0 and Insert *)
		|063X: IF ~(NumLock IN leds) THEN res := Inputs.KsDelete; ELSE res := Inputs.KsNil END;  (* Keypad . and Delete *)
		|067X:  IF ~(NumLock IN leds) THEN ch := 028X; res := Inputs.KsKPEnter; ELSE res := Inputs.KsNil END;  (* Keypad =; remap to KpEnter *)
		|0B0X: ch := 0X; res := Inputs.KsNil;  (* Keypad 00; don't map *)
		|0B1X: ch := 0X; res := Inputs.KsNil;  (* Keypad 000; don't map *)
		|09AX: res := Inputs.KsSysReq (* SysReq / Attention *)
		|0E0X: res := Inputs.KsControlL (* Left Control *)
		|0E1X: res := Inputs.KsShiftL (* Left Shift *)
		|0E2X: res := Inputs.KsAltL (* Left Alt *)
		|0E3X: res := Inputs.KsMetaL (* Left GUI *)
		|0E4X: res := Inputs.KsControlR (* Right Control *)
		|0E5X: res := Inputs.KsShiftR (* Right Shift *)
		|0E6X: res := Inputs.KsAltR (* Right Alt *)
		|0E7X: res := Inputs.KsMetaR (* Right GUI *)
		|076X: res := Inputs.KsMenu (* Windows Menu *)
		|0FFX: res := Inputs.KsBreak (* Break *)
	ELSE
		(* if res=Inputs.KsNil, the KeySym will be assigned later (see HandleKey) *)
		res := Inputs.KsNil (* no key *)
	END;
	RETURN res
END KeySym;

PROCEDURE GetModifierKeysym(modifier : LONGINT) : LONGINT;
VAR res : LONGINT;
BEGIN
	CASE modifier OF
		|Inputs.LeftCtrl: res := Inputs.KsControlL;
		|Inputs.LeftShift: res := Inputs.KsShiftL;
		|Inputs.LeftAlt: res := Inputs.KsAltL;
		|Inputs.LeftMeta: res := Inputs.KsMetaL;
		|Inputs.RightCtrl: res := Inputs.KsControlR;
		|Inputs.RightShift: res := Inputs.KsShiftR;
		|Inputs.RightAlt: res := Inputs.KsAltR;
		|Inputs.RightMeta: res := Inputs.KsMetaR;
	ELSE
		res := Inputs.KsNil;
	END;
	RETURN res;
END GetModifierKeysym;

(* Translate - Translate scan code "c" to key. *)
PROCEDURE Translate(flags, leds: SET;  c: CHAR; keyboardTable : ADDRESS; VAR keyboardDeadKey, keyboardKeyVal : LONGINT): LONGINT;
CONST
	(* The flags stored in the keytable are not the same as the ones defined in Inputs.
		The parameter flags and leds use the Inputs constants.
		The constants below are for the use of the flags stored in the keytable (variable s) *)
	OScrollLock = 0;
	ONumLock = 1;
	OCapsLock = 2;
	LAlt = 3;
	RAlt = 4;
	LCtrl = 5;
	RCtrl = 6;
	LShift = 7;
	RShift = 8;
	GreyEsc = 9;
	LMeta = 13;
	RMeta = 14;
	Alt = {LAlt, RAlt};
	Ctrl = {LCtrl, RCtrl};
	Shift = {LShift, RShift};
	DeadKey = 0;
VAR
	a: ADDRESS;
	s1: CHAR;
	s : SET;
	k: INTEGER;
	dkn: SHORTINT;
BEGIN
	IF (c = 46X) & (flags * Inputs.Ctrl # {}) THEN RETURN -2 END;  (* Ctrl-Break - break *)
	IF (c = 44X) & (flags * Inputs.Ctrl # {}) THEN RETURN 0FFH END;	(* Ctrl-F10 - exit *)
	IF (c = 53X) & (flags * Inputs.Ctrl # {}) & (flags * Inputs.Alt # {}) THEN RETURN 0FFH END; (* Ctrl-Alt-Del - exit *)

	a := keyboardTable;

	(* this loop linearly searches the keytable for an entry for the character c *)
	LOOP
		SYSTEM.GET(a, s1);

		IF s1 = 0FFX THEN (* end of table -> unmapped key *)

			(* reset key and dead key state *)
			k := -1;  keyboardDeadKey := 0;  EXIT;

		ELSIF s1 = c THEN (* found scan code in table *)

			k := 0;

			SYSTEM.GET(a+3, SYSTEM.VAL(CHAR, s)); (* flags from table *)
			dkn := SHORT(SHORT(SYSTEM.VAL(LONGINT, LSH(s * {5..7}, -5))));

			s := s * {DeadKey, ONumLock, OCapsLock, LAlt, RAlt, LCtrl, RCtrl};

			IF ((s * Alt = LSH(flags * Inputs.Alt,-2)) OR (ONumLock IN s) OR (s1>03BX))  & (dkn = keyboardDeadKey) THEN	(* Alt & dead keys match exactly *)

				(* check if shift pressed *)
				IF flags * Inputs.Shift # {} THEN INCL(s, LShift) END;

				(* handle CapsLock *)
				IF (OCapsLock IN s) & (CapsLock IN leds) THEN s := s / {LShift} END;

				(* handle NumLock *)
				IF ONumLock IN s THEN
					IF flags * Inputs.Alt # {} THEN INCL(s, LShift)
					ELSIF NumLock IN leds THEN s := s / {LShift}
					END
				END;

				(* get key code *)
				IF LShift IN s THEN SYSTEM.GET(a+2, SYSTEM.VAL(CHAR, k))	(* shifted value *)
				ELSE SYSTEM.GET(a+1, SYSTEM.VAL(CHAR, k))	(* unshifted value *)
				END;

				IF (DeadKey IN s) & (k <= 7) THEN (* dead key *)
					keyboardDeadKey := SHORT(k);  k := -1	(* set new dead key state *)
				ELSIF k = 0FFH THEN	(* unmapped key *)
					k := -1;  keyboardDeadKey := 0	(* reset dead key state *)
				ELSE	(* mapped key *)
					IF flags * Inputs.Ctrl # {} THEN
						IF ((k >= 64) & (k <= 95)) OR ((k >= 97) & (k <= 122)) THEN
							k := SHORT(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, k) * {0..4}))	(* control *)
						ELSIF k = 13 THEN	(* Ctrl-Enter *)
							k := 10
						END
					END;
					IF flags * Inputs.Alt # {} THEN	(* Alt-keypad *)
						IF (k >= ORD("0")) & (k <= ORD("9")) & (NumLock IN s) THEN	(* keypad num *)
							IF keyboardKeyVal = -1 THEN keyboardKeyVal := k-ORD("0")
							ELSE keyboardKeyVal := (10*keyboardKeyVal + (k-ORD("0"))) MOD 1000;
							END;
							k := -1
						END
					END;
					keyboardDeadKey := 0	(* reset dead key state *)
				END;
				EXIT
			END
		END;
		INC(a, 4)
	END; (* LOOP *)
	RETURN k
END Translate;

(* Displays textual representation of the set flags to KernelLog *)
PROCEDURE ShowFlags(flags, leds : SET);
BEGIN
	KernelLog.String("Flags: ");
	IF Inputs.LeftAlt IN flags THEN KernelLog.String("[Left Alt]"); END;
	IF Inputs.RightAlt IN flags THEN KernelLog.String("[Right Alt]"); END;
	IF Inputs.LeftCtrl IN flags THEN KernelLog.String("[Left Ctrl]"); END;
	IF Inputs.RightCtrl IN flags THEN KernelLog.String("[Rigth Ctrl]"); END;
	IF Inputs.LeftShift IN flags THEN KernelLog.String("[Left Shift]"); END;
	IF Inputs.RightShift IN flags THEN KernelLog.String("[Right Shift]"); END;
	IF Inputs.LeftMeta IN flags THEN KernelLog.String("[Left Meta]"); END;
	IF Inputs.RightMeta IN flags THEN KernelLog.String("[Rigth Meta]"); END;
	IF Inputs.Release IN flags THEN KernelLog.String("[Released]"); END;
	IF ScrollLock IN leds THEN KernelLog.String("[ScrollLock]"); END;
	IF NumLock IN leds THEN KernelLog.String("[NumLock]"); END;
	IF CapsLock IN leds THEN KernelLog.String("[CapsLock]"); END;
	IF Compose IN leds THEN KernelLog.String("[Compose]"); END;
	IF Kana IN leds THEN KernelLog.String("[Kana]"); END;
END ShowFlags;

PROCEDURE Probe(dev : Usbdi.UsbDevice; if : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : KeyboardDriver;
BEGIN
	IF if.bInterfaceClass # 3 THEN RETURN NIL END; (* HID class *)
	IF if.bInterfaceSubClass # 1 THEN RETURN NIL END; (* Boot protocol subclass *)
	IF if.bInterfaceProtocol # 1 THEN RETURN NIL END; (* Keyboard *)
	IF if.bNumEndpoints # 1 THEN RETURN NIL END;
	KernelLog.String("UsbKeyboard: USB Keyboard found."); KernelLog.Ln;
	NEW(driver);
	RETURN driver;
END Probe;

PROCEDURE SetLayout*(context : Commands.Context); (** dev file ~ *)
VAR
	string : ARRAY 64 OF CHAR;
	plugin : Plugins.Plugin; kd : KeyboardDriver;
BEGIN
	IF context.arg.GetString(string) THEN
		plugin := Usb.usbDrivers.Get(string);
		IF plugin # NIL THEN
			IF plugin IS KeyboardDriver THEN
				kd := plugin (KeyboardDriver);
			ELSE context.error.String("UsbKeyboard: Device "); context.error.String(string); context.error.String(" is not a keyboard."); context.error.Ln;
			END;
		ELSE context.error.String("UsbKeyboard: Device "); context.error.String(string); context.error.String(" not found."); context.error.Ln;
		END;
	ELSE context.error.String("UsbKeyboard: Expected <dev> parameter."); context.error.Ln;
	END;
	IF kd # NIL THEN
		IF context.arg.GetString(string) THEN
			kd.base.SetLayout(string);
			context.out.String("Layout set to "); context.out.String(string); context.out.Ln;
		END;
	END;
END SetLayout;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, Priority);
END UsbKeyboard.

UsbKeyboard.Install ~ SystemTools.Free UsbKeyboard ~

UsbKeyboard.SetLayout UsbKeyboard00 KeyBE.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyCA.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyCH.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyD.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyDV.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyFR.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyIT.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyN.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyPL.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeySF.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyTR.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyUK.Bin ~
UsbKeyboard.SetLayout UsbKeyboard00 KeyUS.Bin ~

WMKeyCode.Open ~	SystemTools.Free WMKeyCode ~
