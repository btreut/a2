(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Keyboard; (** AUTHOR "pjm"; PURPOSE "PC keyboard driver"; *)

(* temporary Native-based version *)

IMPORT SYSTEM, Machine, KernelLog, Modules, Kernel, Objects, Inputs, Commands, Files;

CONST
		(* do not change these values, as they are used in the keyboard tables from Native *)
	ScrollLock = 0; NumLock = 1; CapsLock = 2; LAlt = 3; RAlt = 4;
	LCtrl = 5; RCtrl = 6; LShift = 7; RShift = 8; GreyEsc = 9;
	Resetting = 10; SetTypematic = 11; SendingLEDs = 12;
	LMeta = 13; RMeta = 14;

	DeadKey = 0;

	TraceKeys = FALSE;

TYPE
	Keyboard = OBJECT
		VAR last: Inputs.KeyboardMsg;

		PROCEDURE HandleInterrupt;
		VAR m: SET; i: LONGINT; msg: Inputs.KeyboardMsg; k: INTEGER; c: CHAR;
		BEGIN {EXCLUSIVE}
			SYSTEM.PORTIN(060H, c);	(* get scan code *)
			SYSTEM.PORTIN(061H, SYSTEM.VAL(CHAR, m));
			INCL(m, 7); SYSTEM.PORTOUT(061H, SYSTEM.VAL(CHAR, m));
			EXCL(m, 7); SYSTEM.PORTOUT(061H, SYSTEM.VAL(CHAR, m));	(* ack *)
			IF TraceKeys THEN KernelLog.Hex(ORD(c), -3) END;
			k := MapScanCode(c, msg.keysym);
			IF k >= 0 THEN msg.ch := CHR(k) ELSE msg.ch := 0X END;
			IF TraceKeys & (msg.keysym # Inputs.KsNil) THEN
				KernelLog.Hex(msg.keysym, 9); KernelLog.Ln
			END;
			(*msg.key := CHR(ORD(c) MOD 80H);*)
			msg.flags := {};
			FOR i := LAlt TO RShift DO
				IF i IN flags THEN INCL(msg.flags, mapflag[i]) END
			END;
			FOR i := LMeta TO RMeta DO
				IF i IN flags THEN INCL(msg.flags, i-LMeta+Inputs.LeftMeta) END
			END;
			IF c >= 80X THEN INCL(msg.flags, Inputs.Release) END;
			IF (msg.flags # last.flags) OR (msg.ch # 0X) OR (msg.keysym # Inputs.KsNil) THEN
				last := msg; Inputs.keyboard.Handle(msg)
			END
		END HandleInterrupt;

		PROCEDURE &Init*;
		BEGIN
			last.ch := 0X; (*last.key := 0X;*) last.flags := {0..31};
			Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+1)
		END Init;

		PROCEDURE Finalize;
		BEGIN
			Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0+1)
		END Finalize;

	END Keyboard;

VAR
	dkey: SHORTINT;
	lastport: LONGINT;
	lastvalue: SYSTEM.BYTE;
	keyval: INTEGER;
	table: ADDRESS;
	flags: SET;
	keytable: POINTER TO ARRAY OF CHAR;
	keyboard: Keyboard;
	mapflag: ARRAY RShift+1 OF SHORTINT;

(* ---- Keyboard Driver ---- *)

(* Translation table format:

	table = { scancode unshifted-code shifted-code flags }  0FFX .
	scancode = <scancode byte from keyboard, bit 7 set for "grey" extended keys>
	unshifted-code = <CHAR produced by this scancode, without shift>
	shifted-code = <CHAR produced by this scancode, with shift>
	flags = <bit-mapped flag byte indicating special behaviour>

	flag bit	function
		0	01	DeadKey: Set dead key flag according to translated key code (1-7)
		1	02	NumLock: if set, the state of NumLock will reverse the action of shift (for num keypad) *** no longer ***
		2	04	CapsLock: if set, the state of CapsLock will reverse the action of shift (for alpha keys)
		3	08	LAlt:  \ the state of these two flags in the table and the current state of the two...
		4	10	RAlt: / ...Alt keys must match exactly, otherwise the search is continued.
		5	20	\
		6	40	 >  dead key number (0-7), must match current dead key flag
		7	80	/

	The table is scanned sequentially (speed not critical).  Ctrl-Break, Ctrl-F10 and Ctrl-Alt-Del
	are always defined and are not in the table.   The control keys are also always defined. *)

(* TableUS - US keyboard translation table (dead keys: ^=1, '=2, `=3, ~=4, "=5) *)

PROCEDURE TableUS(): ADDRESS;
CODE {SYSTEM.AMD64}
	LEA RAX, [RIP + L2 - L1];
L1:
	LEAVE
	RET
L2:
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
;		; dead keys (LAlt & RAlt)
;	DB 07H, 0FFH, 1H, 9H,	28H, 2H, 5H, 9H,	29H, 3H, 4H, 9H,
;	DB 07H, 0FFH, 1H, 11H,	28H, 2H, 5H, 11H,	29H, 3H, 4H, 11H,
;		; following keys
;	DB 1EH, 'â', 0FFH, 20H,	12H, 'ê', 0FFH, 20H,	17H, 'î', 0FFH, 20H,	18H, 'ô', 0FFH, 20H
;	DB 16H, 'û', 0FFH, 20H,	1EH, 'à', 0FFH, 60H,	12H, 'è', 0FFH, 60H,	17H, 'ì', 0FFH, 60H
;	DB 18H, 'ò', 0FFH, 60H,	16H, 'ù', 0FFH, 60H,	1EH, 'á', 0FFH, 40H,	12H, 'é', 0FFH, 40H
;	DB 1EH, 'ä', 'Ä', 0A4H,	12H, 'ë', 0FFH, 0A0H,	17H, 'ï', 0FFH, 0A0H,	18H, 'ö', 'Ö', 0A4H
;	DB 16H, 'ü', 'Ü', 0A4H,	31H, 'ñ', 0FFH, 80H

	DB 1EH, 83H, 80H, 0CH,	12H, 91H, 0FFH, 0CH,	18H, 84H, 81H, 0CH,	16H, 85H, 82H, 0CH
	DB 17H, 92H, 0FFH, 0CH,	1FH, 96H, 0FFH, 0CH,	2EH, 93H, 0FFH, 0CH,	31H, 95H, 0FFH, 0CH
	DB 1EH, 83H, 80H, 14H,	12H, 91H, 0FFH, 14H,	18H, 84H, 81H, 14H,	16H, 85H, 82H, 14H
	DB 17H, 92H, 0FFH, 14H,	1FH, 96H, 0FFH, 14H,	2EH, 93H, 0FFH, 14H,	31H, 95H, 0FFH, 14H
		; dead keys (LAlt & RAlt)
	DB 07H, 0FFH, 1H, 9H,	28H, 2H, 5H, 9H,	29H, 3H, 4H, 9H,
	DB 07H, 0FFH, 1H, 11H,	28H, 2H, 5H, 11H,	29H, 3H, 4H, 11H,
		; following keys
	DB 1EH, 86H, 0FFH, 20H,	12H, 87H, 0FFH, 20H,	17H, 88H, 0FFH, 20H,	18H, 89H, 0FFH, 20H
	DB 16H, 8AH, 0FFH, 20H,	1EH, 8BH, 0FFH, 60H,	12H, 8CH, 0FFH, 60H,	17H, 8DH, 0FFH, 60H
	DB 18H, 8EH, 0FFH, 60H,	16H, 8FH, 0FFH, 60H,	1EH, 94H, 0FFH, 40H,	12H, 90H, 0FFH, 40H
	DB 1EH, 83H, 80H, 0A4H,	12H, 91H, 0FFH, 0A0H,	17H, 92H, 0FFH, 0A0H,	18H, 84H, 81H, 0A4H
	DB 16H, 85H, 82H, 0A4H,	31H, 95H, 0FFH, 80H

	DB 1EH, 'a', 'A', 0CH,	12H, 'e', 0FFH, 0CH,	18H, 'o', 'O', 0CH,	16H, 'u', 'U', 0CH
	DB 17H, 'i', 0FFH, 0CH,	1FH, 's', 0FFH, 0CH,	2EH, 'c', 0FFH, 0CH,	31H, 'n', 0FFH, 0CH
	DB 1EH, 'a', 'A', 14H,	12H, 'e', 0FFH, 14H,	18H, 'o', 'O', 14H,	16H, 'u', 'U', 14H
	DB 17H, 'i', 0FFH, 14H,	1FH, 's', 0FFH, 14H,	2EH, 'c', 0FFH, 14H,	31H, 'n', 0FFH, 14H
		; dead keys (LAlt & RAlt)
	DB 07H, 0FFH, 1H, 9H,	28H, 2H, 5H, 9H,	29H, 3H, 4H, 9H,
	DB 07H, 0FFH, 1H, 11H,	28H, 2H, 5H, 11H,	29H, 3H, 4H, 11H,
		; following keys
	DB 1EH, 'a', 0FFH, 20H,	12H, 'e', 0FFH, 20H,	17H, 'i', 0FFH, 20H,	18H, 'o', 0FFH, 20H
	DB 16H, 'u', 0FFH, 20H,	1EH, 'a', 0FFH, 60H,	12H, 'e', 0FFH, 60H,	17H, 'i', 0FFH, 60H
	DB 18H, 'o', 0FFH, 60H,	16H, 'u', 0FFH, 60H,	1EH, 'a', 0FFH, 40H,	12H, 'e', 0FFH, 40H
	DB 1EH, 'a', 'A', 0A4H,	12H, 'e', 0FFH, 0A0H,	17H, 'i', 0FFH, 0A0H,	18H, 'o', 'O', 0A4H
	DB 16H, 'u', 'U', 0A4H,	31H, 'n', 0FFH, 80H
		; numbers at top
	DB 0BH, '0', ')', 0H,	02H, '1', '!', 0H,	03H, '2', '@', 0H,	04H, '3', '#', 0H
	DB 05H, '4', '$', 0H,	06H, '5', '%', 0H,	07H, '6', '^', 0H,	08H, '7', '&', 0H
	DB 09H, '8', '*', 0H,	0AH, '9', '(', 0H
		; symbol keys
	DB 28H, 27H, 22H, 0H,	33H, ',', '<', 0H,	0CH, '-', '_', 0H,	34H, '.', '>', 0H
	DB 35H, '/', '?', 0H,	27H, ';', ':', 0H,	0DH, '=', '+', 0H,	1AH, '[', '{', 0H
	DB 2BH, '\', '|', 0H,	1BH, ']', '}', 0H,	29H, '`', '~', 0H
		; control keys
	DB 0EH, 7FH, 7FH, 0H	; backspace
	DB 0FH, 09H, 09H, 0H	; tab
	DB 1CH, 0DH, 0DH, 0H	; enter
	DB 39H, 20H, 20H, 0H	; space
	DB 01H, 1BH, 1BH, 0H	; esc
	 	; keypad
	DB 4FH, 0A9H, '1', 2H	; end/1
	DB 50H, 0C2H, '2', 2H	; down/2
	DB 51H, 0A3H, '3', 2H	; pgdn/3
	DB 4BH, 0C4H, '4', 2H	; left/4
	DB 4CH, 0FFH, '5', 2H	; center/5
	DB 4DH, 0C3H, '6', 2H	; right/6
	DB 47H, 0A8H, '7', 2H	; home/7
	DB 48H, 0C1H, '8', 2H	; up/8
	DB 49H, 0A2H, '9', 2H	; pgup/9
	DB 52H, 0A0H, '0', 2H	; insert/0
	DB 53H, 0A1H, 2EH, 2H	; del/.
		; grey keys
	DB 4AH, '-', '-', 0H	; grey -
	DB 4EH, '+', '+', 0H	; grey +
	DB 0B5H, '/', '/', 0H	; grey /
	DB 37H, '*', '*', 0H	; grey *
	DB 0D0H, 0C2H, 0C2H, 0H	; grey down
	DB 0CBH, 0C4H, 0C4H, 0H	; grey left
	DB 0CDH, 0C3H, 0C3H, 0H	; grey right
	DB 0C8H, 0C1H, 0C1H, 0H	; grey up
	DB 09CH, 0DH, 0DH, 0H	; grey enter
	DB 0D2H, 0A0H, 0A0H, 0H	; grey ins
	DB 0D3H, 0A1H, 0A1H, 0H	; grey del
	DB 0C9H, 0A2H, 0A2H, 0H	; grey pgup
	DB 0D1H, 0A3H, 0A3H, 0H	; grey pgdn
	DB 0C7H, 0A8H, 0A8H, 0H	; grey home
	DB 0CFH, 0A9H, 0A9H, 0H	; grey end
		; function keys
	DB 3BH, 0A4H, 0FFH, 0H	; F1
	DB 3CH, 0A5H, 0FFH, 0H	; F2
	DB 3DH, 0A6H, 0FFH, 0H	; F3
	DB 3EH, 0A7H, 0FFH, 0H	; F4
	DB 3FH, 0F5H, 0FFH, 0H	; F5
	DB 40H, 0F6H, 0FFH, 0H	; F6
	DB 41H, 0F7H, 0FFH, 0H	; F7
	DB 42H, 0F8H, 0FFH, 0H	; F8
	DB 43H, 0F9H, 0FFH, 0H	; F9
	DB 44H, 0FAH, 0FFH, 0H	; F10
	DB 57H, 0FBH, 0FFH, 0H	; F11
	DB 58H, 0FCH, 0FFH, 0H	; F12
	DB 0FFH
END TableUS;

PROCEDURE TableFromFile(name: ARRAY OF CHAR): ADDRESS;
VAR f: Files.File; r: Files.Rider; len: LONGINT;
BEGIN
	KernelLog.String("Keyboard: "); KernelLog.String(name);
	f := Files.Old(name);
	IF f # NIL THEN
		len := f.Length();
		IF len MOD 4 = 0 THEN
			NEW(keytable, len+1);
			f.Set(r, 0); f.ReadBytes(r, keytable^, 0, len);
			IF r.res = 0 THEN
				KernelLog.String(" loaded."); KernelLog.Ln;
				keytable[len] := 0FFX;
				RETURN ADDRESSOF(keytable[0])
			ELSE
				KernelLog.String(" res="); KernelLog.Int(r.res, 1)
			END
		ELSE
			KernelLog.String(" len="); KernelLog.Int(len, 1)
		END
	ELSE
		KernelLog.String(" not found.")
	END;
	KernelLog.Ln;
	RETURN TableUS()
END TableFromFile;

(* Translate - Translate scan code "c" to key. *)

PROCEDURE Translate(flags: SET; c: CHAR): INTEGER;
CONST
	Alt = {LAlt, RAlt}; Ctrl = {LCtrl, RCtrl}; Shift = {LShift, RShift};
VAR a: ADDRESS; s1: CHAR; s: SET; k: INTEGER; dkn: SHORTINT;
BEGIN {EXCLUSIVE}
	IF (c = 46X) & (flags * Ctrl # {}) THEN RETURN -2 END;	(* Ctrl-Break - break *)
	IF (c = 44X) & (flags * Ctrl # {}) THEN RETURN 0FFH END;	(* Ctrl-F10 - exit *)
	IF (c = 53X) & (flags * Ctrl # {}) & (flags * Alt # {}) THEN RETURN 0A1H END;	(* Ctrl-Alt-Del - Del *)
	IF GreyEsc IN flags THEN c := CHR(ORD(c)+80H) END;
	a := table;
	LOOP
		SYSTEM.GET(a, s1);
		IF s1 = 0FFX THEN	(* end of table, unmapped key *)
			k := -1; dkey := 0; EXIT
		ELSIF s1 = c THEN	(* found scan code in table *)
			SYSTEM.GET(a+3, SYSTEM.VAL(CHAR, s));	(* flags from table *)
			dkn := SHORT(SHORT(SYSTEM.VAL(LONGINT, LSH(s * {5..7}, -5))));
			s := s * {DeadKey, NumLock, CapsLock, LAlt, RAlt, LCtrl, RCtrl}; k := 0;
			IF ((s * Alt = flags * Alt) OR (NumLock IN s) OR (s1 > 03BX)) & (dkn = dkey) THEN	(* Alt & dead keys match exactly *)
				IF flags * Shift # {} THEN INCL(s, LShift) END;	(* check if shift pressed *)
					(* handle CapsLock *)
				IF (CapsLock IN s) & (CapsLock IN flags) THEN s := s / {LShift} END;
					(* handle NumLock *)
				IF NumLock IN s THEN
					IF NumLock IN flags THEN s := s + {LShift} ELSE s := s - {LShift} END
				END;
					(* get key code *)
				IF LShift IN s THEN SYSTEM.GET(a+2, SYSTEM.VAL(CHAR, k))	(* shifted value *)
				ELSE SYSTEM.GET(a+1, SYSTEM.VAL(CHAR, k))	(* unshifted value *)
				END;
				IF (DeadKey IN s) & (k <= 7) THEN	(* dead key *)
					dkey := SHORT(k); k := -1	(* set new dead key state *)
				ELSIF k = 0FFH THEN	(* unmapped key *)
					k := -1; dkey := 0	(* reset dead key state *)
				ELSE	(* mapped key *)
					IF flags * Ctrl # {} THEN
						IF ((k >= 64) & (k <= 95)) OR ((k >= 97) & (k <= 122)) THEN
							k := SHORT(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, k) * {0..4}))	(* control *)
						ELSIF k = 13 THEN	(* Ctrl-Enter *)
							k := 10
						END
					END;
					IF flags * Alt # {} THEN	(* Alt-keypad *)
						IF (k >= ORD('0')) & (k <= ORD('9')) & (NumLock IN s) THEN	(* keypad num *)
							IF keyval = -1 THEN keyval := k-ORD('0')
							ELSE keyval := (10*keyval + (k-ORD('0'))) MOD 1000
							END;
							k := -1
						END
					END;
					dkey := 0	(* reset dead key state *)
				END;
				EXIT
			END
		END;
		INC(a, 4)
	END; (* LOOP *)
	RETURN k
END Translate;

(* Wait - Wait for keyboard serial port to acknowledge byte. *)

PROCEDURE Wait;
VAR t: Kernel.MilliTimer; s: SET;
BEGIN
	Kernel.SetTimer(t, 20);	(* wait up to 17 ms *)
	REPEAT
		SYSTEM.PORTIN(64H, SYSTEM.VAL(CHAR, s))
	UNTIL ~(1 IN s) OR Kernel.Expired(t)
END Wait;

(* SendByte - Send a byte to the keyboard. *)

PROCEDURE SendByte(port: LONGINT; value: SYSTEM.BYTE);
BEGIN
	Wait; SYSTEM.PORTOUT(port, SYSTEM.VAL(CHAR, value));
	lastport := port; lastvalue := value
END SendByte;

(* ShiftKey - Handle shift keys. *)

PROCEDURE ShiftKey(left, right: SHORTINT; in: BOOLEAN);
BEGIN
	IF in THEN
		IF GreyEsc IN flags THEN INCL(flags, right)
		ELSE INCL(flags, left)
		END
	ELSE
		IF GreyEsc IN flags THEN EXCL(flags, right)
		ELSE EXCL(flags, left)
		END
	END
END ShiftKey;

(* LedKey - Handle "lock" keys. *)

PROCEDURE LedKey(VAR flags: SET; lock: SHORTINT; c: CHAR;
		VAR k: INTEGER);
BEGIN
	IF flags * {LAlt, RAlt, LCtrl, RCtrl, LShift, RShift} = {} THEN
		flags := flags / {lock}
	ELSE
		k := Translate(flags, c)
	END
END LedKey;

(* MapScanCode - Map a scan code "c" to a key code. *)

PROCEDURE MapScanCode(c: CHAR; VAR keysym: LONGINT): INTEGER;
VAR k: INTEGER; oldleds: SET;
BEGIN
	SendByte(64H, 0ADX); Wait;	(* disable keyboard *)
	k := -1; oldleds := flags * {ScrollLock, NumLock, CapsLock};
	keysym := Inputs.KsNil;	(* no key *)
	IF c = 0X THEN	(* overrun, ignore *)
	ELSIF c = 0FAX THEN	(* keyboard ack *)
		IF Resetting IN flags THEN
			EXCL(flags, Resetting); INCL(flags, SendingLEDs);
			SendByte(60H, 0EDX)	(* set keyboard LEDs *)
		ELSIF SendingLEDs IN flags THEN
			SendByte(60H, SYSTEM.VAL(CHAR, oldleds));
			EXCL(flags, SendingLEDs)
		ELSIF SetTypematic IN flags THEN
			EXCL(flags, SetTypematic); INCL(flags, Resetting);
			SendByte(60H, 020X)	(* 30Hz, 500 ms *)
		ELSE (* assume ack was for something else *)
		END
	ELSIF c = 0FEX THEN	(* keyboard resend *)
		SendByte(lastport, lastvalue)
	ELSIF c = 038X THEN	(* Alt make *)
		ShiftKey(LAlt, RAlt, TRUE); keysym := Inputs.KsAltL
	ELSIF c = 01DX THEN	(* Ctrl make *)
		ShiftKey(LCtrl, RCtrl, TRUE); keysym := Inputs.KsControlL
	ELSIF c = 02AX THEN	(* LShift make *)
		IF ~(GreyEsc IN flags) THEN
			INCL(flags, LShift); keysym := Inputs.KsShiftL
		END
	ELSIF c = 036X THEN	(* RShift make *)
		IF ~(GreyEsc IN flags) THEN
			INCL(flags, RShift); keysym := Inputs.KsShiftR
		END
	ELSIF c = 05BX THEN	(* LMeta make *)
		INCL(flags, LMeta); keysym := Inputs.KsMetaL
	ELSIF c = 05CX THEN	(* RMeta make *)
		INCL(flags, RMeta); keysym := Inputs.KsMetaR
	ELSIF c = 03AX THEN	(* Caps make *)
		LedKey(flags, CapsLock, c, k)
	ELSIF c = 046X THEN	(* Scroll make *)
		LedKey(flags, ScrollLock, c, k);
		IF k = -2 THEN keysym := Inputs.KsBreak END	(* Break *)
	ELSIF c = 045X THEN	(* Num make *)
		LedKey(flags, NumLock, c, k)
	ELSIF c = 0B8X THEN	(* Alt break *)
		ShiftKey(LAlt, RAlt, FALSE); keysym := Inputs.KsAltL;
		IF (keyval >= 0) & (keyval < 255) THEN k := keyval END;	(* exclude 255 - reboot *)
		keyval := -1
	ELSIF c = 09DX THEN	(* Ctrl break *)
		ShiftKey(LCtrl, RCtrl, FALSE); keysym := Inputs.KsControlL
	ELSIF c = 0AAX THEN	(* LShift break *)
		IF ~(GreyEsc IN flags) THEN
			EXCL(flags, LShift); keysym := Inputs.KsShiftL
		END
	ELSIF c = 0B6X THEN	(* RShift break *)
		IF ~(GreyEsc IN flags) THEN
			EXCL(flags, RShift); keysym := Inputs.KsShiftR
		END
	ELSIF c = 0DBX THEN	(* LMeta break *)
		EXCL(flags, LMeta); keysym := Inputs.KsMetaL
	ELSIF c = 0DCX THEN	(* RMeta break *)
		EXCL(flags, RMeta); keysym := Inputs.KsMetaR
	ELSIF c = 05DX THEN	(* Menu make *)
		keysym := Inputs.KsMenu	(* Windows menu *)
	ELSIF c < 080X THEN	(* Other make *)
		k := Translate(flags, c);
		IF c = 0EX THEN keysym := Inputs.KsBackSpace	(* backspace *)
		ELSIF c = 0FX THEN keysym := Inputs.KsTab	(* tab *)
		ELSIF c = 1CX THEN keysym := Inputs.KsReturn	(* enter *)
		ELSIF c = 01X THEN keysym := Inputs.KsEscape	(* esc *)
		ELSIF c = 3DX THEN keysym := Inputs.KsF3	(* f3 *)
		ELSIF c = 4AX THEN keysym := Inputs.KsKPSubtract	(* kp - *)
		ELSIF c = 4EX THEN keysym := Inputs.KsKPAdd	(* kp + *)
		ELSIF c = 0B5X THEN keysym := Inputs.KsKPDivide	(* kp / *)
		ELSIF c = 37X THEN keysym := Inputs.KsKPMultiply	(* kp * *)
		ELSIF k >= 0 THEN keysym := KeySym(CHR(k))
		ELSE (* skip *)
		END
	ELSE	(* ignore *)
	END;
	IF c = 0E0X THEN INCL(flags, GreyEsc) ELSE EXCL(flags, GreyEsc) END;
	IF flags * {ScrollLock, NumLock, CapsLock} # oldleds THEN
		INCL(flags, SendingLEDs);
		SendByte(60H, 0EDX)	(* set keyboard LEDs *)
	END;
	SendByte(64H, 0AEX);	(* enable keyboard *)
		(* now do additional mappings *)
	RETURN k
END MapScanCode;

(* Map Oberon character code to X11 keysym (/usr/include/X11/keysymdef.h). *)

PROCEDURE KeySym(ch: CHAR): LONGINT;
VAR x: LONGINT;
BEGIN
	IF (ch >= 1X) & (ch <= 7EX) THEN x := ORD(ch)	(* ascii *)
	ELSIF ch = 0A0X THEN x := Inputs.KsInsert	(* insert *)
	ELSIF ch = 0A1X THEN x := Inputs.KsDelete	(* delete *)
	ELSIF ch = 0A8X THEN x := Inputs.KsHome	(* home *)
	ELSIF ch = 0A9X THEN x := Inputs.KsEnd	(* end *)
	ELSIF ch = 0A2X THEN x := Inputs.KsPageUp	(* pgup *)
	ELSIF ch = 0A3X THEN x := Inputs.KsPageDown	(* pgdn *)
	ELSIF ch = 0C4X THEN x := Inputs.KsLeft	(* left *)
	ELSIF ch = 0C1X THEN x := Inputs.KsUp	(* up *)
	ELSIF ch = 0C3X THEN x := Inputs.KsRight	(* right *)
	ELSIF ch = 0C2X THEN x := Inputs.KsDown	(* down *)
	ELSIF ch = 0A4X THEN x := Inputs.KsF1	(* f1 *)
	ELSIF ch = 0A5X THEN x := Inputs.KsF2	(* f2 *)
	(*ELSIF ch = 0xxX THEN x := Inputs.KsF3*)	(* f3 *)
	ELSIF ch = 0A7X THEN x := Inputs.KsF4	(* f4 *)
	ELSIF ch = 0F5X THEN x := Inputs.KsF5	(* f5 *)
	ELSIF ch = 0F6X THEN x := Inputs.KsF6	(* f6 *)
	ELSIF ch = 0F7X THEN x := Inputs.KsF7	(* f7 *)
	ELSIF ch = 0F8X THEN x := Inputs.KsF8	(* f8 *)
	ELSIF ch = 0F9X THEN x := Inputs.KsF9	(* f9 *)
	ELSIF ch = 0FAX THEN x := Inputs.KsF10	(* f10 *)
	ELSIF ch = 0FBX THEN x := Inputs.KsF11	(* f11 *)
	ELSIF ch = 0FCX THEN x := Inputs.KsF12	(* f12 *)
	ELSE x := 0
	END;
	RETURN x
END KeySym;

(* InitKeyboard - Initialise the keyboard. *)

PROCEDURE InitKeyboard;
VAR s: SET; c: CHAR; i: SHORTINT; k: ARRAY 32 OF CHAR;
BEGIN
	keyval := -1; dkey := 0;
	mapflag[LAlt] := Inputs.LeftAlt; mapflag[RAlt] := Inputs.RightAlt;
	mapflag[LCtrl] := Inputs.LeftCtrl; mapflag[RCtrl] := Inputs.RightCtrl;
	mapflag[LShift] := Inputs.LeftShift; mapflag[RShift] := Inputs.RightShift;
		(* Get table *)
	Machine.GetConfig("Keyboard", k);
	i := 0; WHILE (k[i] # 0X) & (k[i] # '.') DO INC(i) END;
	IF k[i] = '.' THEN table := TableFromFile(k)
	ELSE table := TableUS()
	END;
		(* Get compatibility option *)
	flags := {};
	NEW(keyboard);
		(* clear the keyboard's internal buffer *)
	i := 8;
	LOOP
		SYSTEM.PORTIN(64H, SYSTEM.VAL(CHAR, s));
		IF ~(0 IN s) OR (i = 0) THEN EXIT END;
		SYSTEM.PORTIN(60H, c);	(* read byte *)
		SYSTEM.PORTIN(61H, SYSTEM.VAL(CHAR, s));
		INCL(s, 7); SYSTEM.PORTOUT(61H, SYSTEM.VAL(CHAR, s));
		EXCL(s, 7); SYSTEM.PORTOUT(61H, SYSTEM.VAL(CHAR, s));	(* ack *)
		DEC(i)
	END;
	flags := {SetTypematic};
	Machine.GetConfig("NumLock", k);
	IF k[0] = '1' THEN INCL(flags, NumLock) END;
	SendByte(60H, 0F3X)	(* settypedel, will cause Ack from keyboard *)
END InitKeyboard;

PROCEDURE SetLayout*(context : Commands.Context); (** KeyboardLayoutFile ~ *)
VAR layoutFilename : ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	IF (keyboard # NIL) THEN
		context.arg.GetString(layoutFilename);
		table := TableFromFile(layoutFilename);
	ELSE
		context.error.String("Keyboard: No keyboard found."); context.error.Ln;
	END;
END SetLayout;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	IF (keyboard # NIL) & (Modules.shutdown = Modules.None) THEN
		keyboard.Finalize; keyboard := NIL
	END
END Cleanup;

BEGIN
	InitKeyboard;
	Modules.InstallTermHandler(Cleanup)
END Keyboard.

(*
19.08.1999	pjm	Split from Aos.Input
20.09.2006	Added SetLayout (staubesv)
*)

Keyboard.Install ~

Keyboard.SetLayout KeyCH.Bin ~
Keyboard.SetLayout KeyUS.Bin ~

SystemTools.Free Keyboard ~