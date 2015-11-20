MODULE HotKeys; (** AUTHOR "staubesv"; PURPOSE "Hotkey support"; *)
(**
 * This tool registers a message preview handler at the window manager. If the previewed message is a keyboard message,
 * the tool checks whether a command or key remapping has been defined for that key.
 * In case of a defined command, the command is executed and the keyboard message is discarded. In case of a key remapping, the
 * keyboard message is modified and then forwarded.
 *
 * Usage:
 *
 *	HotKeys.Open ~ enables the hot keys defined in the DefaultHotKeyFile
 *	HotKeys.Open <filename> ~ enables the hot keys defined in the specified file
 *
 *	HotKeys.Show ~ displays a list of bound hot keys
 *
 *	SystemTools.Free HotKeys ~ disables all hot keys and unloads the module
 *
 * History:
 *
 *	22.08.2006	First release (staubesv)
 *)

IMPORT
	KernelLog, Strings, Inputs, Modules,
	Commands, Files, Streams, WMWindowManager, WMMessages,
	XML, XMLScanner, XMLParser, XMLObjects;

CONST
	(* Load this file if no file specified *)
	DefaultHotKeyFile = "HotKeys.XML";

	(* Keywords used in XML file *)
	XMLKeysString = "keys";
	XMLCommandString = "command";
	KeySeparatorCharacter = "+";

	NoKeysym = -1;

	Trace = FALSE;

TYPE

	Remapping = POINTER TO RECORD
		ch : CHAR;
		flags : SET;
		keysym : LONGINT;
	END;

	HotKey = POINTER TO RECORD
		ch : CHAR;
		flags : SET;
		keyString : XML.String;
		keysym : LONGINT;
		command : XML.String;
		remapping : Remapping; (* Remap key if not NIL *)
		next : HotKey;
	END;

VAR
	hotkeys : HotKey; (* List head of linked list of hot keys *)
	hasErrors : BOOLEAN;

	manager : WMWindowManager.WindowManager;

PROCEDURE ParseKeyString(keyString : XML.String; VAR ch : CHAR; VAR flags : SET; VAR keysym : LONGINT) : BOOLEAN;
VAR keys : Strings.StringArray; i : LONGINT;
BEGIN
	ASSERT(keyString # NIL);
	ch := 0X; flags := {}; keysym := NoKeysym;
	keys :=	Strings.Split(keyString^, KeySeparatorCharacter);
	FOR i := 0 TO LEN(keys)-1 DO
		Strings.TrimWS(keys[i]^);
		Strings.UpperCase(keys[i]^);
		IF Strings.Match("ALT", keys[i]^) THEN flags := flags + Inputs.Alt;
		ELSIF Strings.Match("LALT", keys[i]^) THEN flags := flags + {Inputs.LeftAlt};
		ELSIF Strings.Match("RALT", keys[i]^) THEN flags := flags + {Inputs.RightAlt};
		ELSIF Strings.Match("SHIFT", keys[i]^) THEN flags := flags + Inputs.Shift;
		ELSIF Strings.Match("LSHIFT", keys[i]^) THEN flags := flags + {Inputs.LeftShift};
		ELSIF Strings.Match("RSHIFT", keys[i]^) THEN flags := flags + {Inputs.RightShift};
		ELSIF Strings.Match("CTRL", keys[i]^) THEN flags := flags + Inputs.Ctrl;
		ELSIF Strings.Match("LCTRL", keys[i]^) THEN flags := flags + {Inputs.LeftCtrl};
		ELSIF Strings.Match("RCTRL", keys[i]^) THEN flags := flags + {Inputs.RightCtrl};
		ELSIF Strings.Match("META", keys[i]^) THEN flags := flags + Inputs.Meta;
		ELSIF Strings.Match("LMETA", keys[i]^) THEN flags := flags + {Inputs.LeftMeta};
		ELSIF Strings.Match("RMETA", keys[i]^) THEN flags := flags + {Inputs.RightMeta};
		ELSIF Strings.Match("RELEASE", keys[i]^) THEN flags := flags + {Inputs.Release};
		ELSIF Strings.Length(keys[i]^) = 1 THEN
			ch := keys[i][0];
			keysym := ORD(ch);
		ELSE
			IF (keysym # NoKeysym) OR (ch # 0X) THEN
				KernelLog.String("HotKeys: Could not parse hotkey: "); KernelLog.String(keyString^);
				KernelLog.String(": Only one non-modifier key per hotkey allowed!"); KernelLog.Ln;
				RETURN FALSE;
			END;
			keysym := StringToKeysym(keys[i]^);
			IF keysym = NoKeysym THEN
				KernelLog.String("HotKeys: Could not parse hotkey: "); KernelLog.String(keyString^);
				KernelLog.String(": Parse error at string: "); KernelLog.String(keys[i]^); KernelLog.Ln;
				RETURN FALSE;
			END;
		END;
	END;
	RETURN TRUE;
END ParseKeyString;

PROCEDURE ParseRemapping(hk : HotKey) : BOOLEAN;
BEGIN
	ASSERT(hk # NIL);
	IF Strings.Match("REMAP*", hk.command^) THEN
		Strings.Delete(hk.command^, 0, 5); (* remove REMAP *)
		NEW(hk.remapping);
		IF ~ParseKeyString(hk.command, hk.remapping.ch, hk.remapping.flags, hk.remapping.keysym) THEN
			RETURN FALSE;
		END;
	END;
	RETURN TRUE;
END ParseRemapping;

PROCEDURE StringToKeysym(CONST string : ARRAY OF CHAR) : LONGINT;
VAR keysym : LONGINT;
BEGIN
	keysym := NoKeysym;
	IF Strings.Match("BACKSPACE", string) THEN keysym := Inputs.KsBackSpace;
	ELSIF Strings.Match("TAB", string) THEN keysym := Inputs.KsTab;
	ELSIF Strings.Match("RETURN", string) THEN keysym := Inputs.KsReturn;
	ELSIF Strings.Match("PAUSE", string) THEN keysym := Inputs.KsPause;
	ELSIF Strings.Match("SCROLLLOCK", string) THEN keysym := Inputs.KsScrollLock;
	ELSIF Strings.Match("SYS", string) OR Strings.Match("SYSREQ", string) THEN keysym := Inputs.KsSysReq;
	ELSIF Strings.Match("ESC", string) OR Strings.Match("ESCAPE", string) THEN keysym := Inputs.KsEscape;
	ELSIF Strings.Match("DEL", string) OR Strings.Match("DELETE", string) THEN keysym := Inputs.KsDelete;
	ELSIF Strings.Match("HOME", string) THEN keysym := Inputs.KsHome;
	ELSIF Strings.Match("LEFT", string) THEN keysym := Inputs.KsLeft;
	ELSIF Strings.Match("UP", string) THEN keysym := Inputs.KsUp;
	ELSIF Strings.Match("RIGHT", string) THEN keysym := Inputs.KsRight;
	ELSIF Strings.Match("DOWN", string) THEN keysym := Inputs.KsDown;
	ELSIF Strings.Match("PAGEUP", string) THEN keysym := Inputs.KsPageUp;
	ELSIF Strings.Match("PAGEDOWN", string) THEN keysym := Inputs.KsPageDown;
	ELSIF Strings.Match("END", string) THEN keysym := Inputs.KsEnd;
	ELSIF Strings.Match("PRINT", string) THEN keysym := Inputs.KsPrint;
	ELSIF Strings.Match("INS", string) OR Strings.Match("INSERT", string) THEN keysym := Inputs.KsInsert;
	ELSIF Strings.Match("MENU", string) THEN keysym := Inputs.KsMenu;
	ELSIF Strings.Match("BREAK", string) THEN keysym := Inputs.KsBreak;
	ELSIF Strings.Match("NUMLOCK", string) THEN keysym := Inputs.KsNumLock;
	ELSIF Strings.Match("KPENTER", string) THEN keysym := Inputs.KsKPEnter;
	ELSIF Strings.Match("KPMULTIPLY", string) THEN keysym := Inputs.KsKPMultiply;
	ELSIF Strings.Match("KPADD", string) THEN keysym := Inputs.KsKPAdd;
	ELSIF Strings.Match("KPSUB", string) OR Strings.Match("KPSUBTRACT", string) THEN keysym := Inputs.KsKPSubtract;
	ELSIF Strings.Match("KPDECIMAL", string) THEN keysym := Inputs.KsKPDecimal;
	ELSIF Strings.Match("KPDIV", string) OR Strings.Match("KPDIVIDE", string) THEN keysym := Inputs.KsKPDivide;
	ELSIF Strings.Match("F1", string) THEN keysym := Inputs.KsF1;
	ELSIF Strings.Match("F2", string) THEN keysym := Inputs.KsF2;
	ELSIF Strings.Match("F3", string) THEN keysym := Inputs.KsF3;
	ELSIF Strings.Match("F4", string) THEN keysym := Inputs.KsF4;
	ELSIF Strings.Match("F5", string) THEN keysym := Inputs.KsF5;
	ELSIF Strings.Match("F6", string) THEN keysym := Inputs.KsF6;
	ELSIF Strings.Match("F7", string) THEN keysym := Inputs.KsF7;
	ELSIF Strings.Match("F8", string) THEN keysym := Inputs.KsF8;
	ELSIF Strings.Match("F9", string) THEN keysym := Inputs.KsF9;
	ELSIF Strings.Match("F10", string) THEN keysym := Inputs.KsF10;
	ELSIF Strings.Match("F11", string) THEN keysym := Inputs.KsF11;
	ELSIF Strings.Match("F12", string) THEN keysym := Inputs.KsF12;
	END;
	RETURN keysym;
END StringToKeysym;

PROCEDURE IsDuplicate(hotkey : HotKey) : BOOLEAN;
VAR hk : HotKey;
BEGIN
	hk := hotkeys.next;
	WHILE (hk # NIL) DO
		IF (hotkey.ch = hk.ch) & (hotkey.flags = hk.flags) & (hotkey.keysym = hk.keysym) THEN
			KernelLog.String("HotKeys: Warning: Duplicate hot key found: ");
			IF hotkey.keyString # NIL THEN KernelLog.String(hotkey.keyString^);
			ELSE KernelLog.String("NIL");
			END;
			KernelLog.String("... ignore!"); KernelLog.Ln;
			RETURN TRUE;
		END;
		hk := hk.next;
	END;
	RETURN FALSE;
END IsDuplicate;

(* Create HotKey object and insert it into the hotkeys list (sorted) *)
PROCEDURE AddHotKey(keys, command : XML.String);
VAR hk : HotKey;
BEGIN
	ASSERT((keys # NIL) & (command # NIL));
	NEW(hk); hk.command := command;	hk.keyString := keys;
	IF ParseKeyString(keys, hk.ch, hk.flags, hk.keysym) & ~IsDuplicate(hk) & ParseRemapping(hk) THEN
		hk.next := hotkeys.next;
		hotkeys.next := hk;
	END;
END AddHotKey;

PROCEDURE CreateHotKeyList(doc : XML.Document);
VAR
	enum: XMLObjects.Enumerator; p: ANY; e: XML.Element;
	s, keys, command  : XML.String;
BEGIN
	IF doc = NIL THEN RETURN END;
	(* First we just count the number of hot keys defined *)
	e := doc.GetRoot(); enum := e.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF (s # NIL) & (s^ = "HotKey") THEN
				keys := e.GetAttributeValue(XMLKeysString);
				IF keys # NIL THEN
					command := e.GetAttributeValue(XMLCommandString);
					IF command # NIL THEN
						AddHotKey(keys, command);
					END;
				END;
			END;
		END;
	END;
END CreateHotKeyList;

PROCEDURE FlagsAreEqual(f1, f2 : SET) : BOOLEAN;
VAR match : BOOLEAN;
BEGIN
	match := TRUE;
	IF f1 # f2 THEN
		IF f2 - f1 # {} THEN (* user pressed more modifier keys than hotkey defines *)
			match := FALSE;
		ELSE (* maybe the hotkey defines ALT and the user presses LALT *)
			IF (f1 * Inputs.Alt = Inputs.Alt) & (f2 * Inputs.Alt = {}) THEN match := FALSE; END;
			IF (f1 * Inputs.Alt # Inputs.Alt) & (f1 * Inputs.Alt # f2 * Inputs.Alt) THEN match := FALSE; END;

			IF (f1 * Inputs.Ctrl = Inputs.Ctrl) & (f2 * Inputs.Ctrl = {}) THEN match := FALSE; END;
			IF (f1 * Inputs.Ctrl # Inputs.Ctrl) & (f1 * Inputs.Ctrl # f2 * Inputs.Ctrl) THEN match := FALSE; END;

			IF (f1 * Inputs.Shift = Inputs.Shift) & (f2 * Inputs.Shift = {}) THEN match := FALSE; END;
			IF (f1 * Inputs.Shift # Inputs.Shift) & (f1 * Inputs.Shift # f2 * Inputs.Shift) THEN match := FALSE; END;

			IF (f1 * Inputs.Meta = Inputs.Meta) & (f2 * Inputs.Meta = {}) THEN match := FALSE; END;
			IF (f1 * Inputs.Meta # Inputs.Meta) & (f1 * Inputs.Meta # f2 * Inputs.Meta) THEN match := FALSE; END;

			IF (f1 * {Inputs.Release}) # (f2 * {Inputs.Release}) THEN match := FALSE; END;
		END;
	END;
	RETURN match;
END FlagsAreEqual;

PROCEDURE GetHotKey(ch : CHAR; flags : SET; keysym : LONGINT) : HotKey;
VAR hk : HotKey;

	PROCEDURE FixMessage(VAR ch : CHAR; VAR keysym : LONGINT;  flags : SET);
	BEGIN
		IF (0 < keysym) & (keysym < 32) & (flags * Inputs.Ctrl # {}) THEN (* Reverse keyboard driver ctrl key mapping *)
			IF (0 < ORD(ch)) & (ORD(ch) < 32) THEN
				ch := CHR(ORD(ch) + 60H);
				keysym := ORD(ch);
			END;
		END;
		IF (ch >= "a") & (ch <= "z") THEN
			ch := CAP(ch);
			keysym := ORD(ch);
		END;
	END FixMessage;

BEGIN
	FixMessage(ch, keysym, flags);
	hk := hotkeys.next;
	LOOP
		IF (hk = NIL) THEN EXIT; END;
		IF (hk.keysym # NoKeysym) THEN
			IF (hk.keysym = keysym) & FlagsAreEqual(hk.flags, flags) THEN RETURN hk; END;
		ELSE
			IF (hk.ch = ch) & FlagsAreEqual(hk.flags, flags) THEN RETURN hk; END;
		END;
		hk := hk.next;
	END;
	RETURN NIL;
END GetHotKey;

PROCEDURE ExecuteCommandFor(command : XML.String);
VAR
	caller: OBJECT
	VAR
		command: XML.String;
		msg : ARRAY 256 OF CHAR; res : LONGINT;

		PROCEDURE & Init(c: XML.String);
		BEGIN
			command := c
		END Init;

	BEGIN{ACTIVE}
		ASSERT(command # NIL);
		IF Trace THEN KernelLog.String("HotKeys: Executing "); KernelLog.String(command^); KernelLog.Ln; END;
		Commands.Call(command^, {}, res, msg);
		IF res # 0 THEN
			KernelLog.String("HotKeys: Error when executing command "); KernelLog.String(command^); KernelLog.String(", res: ");
			KernelLog.Int(res, 0); KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")"); KernelLog.Ln;
		END;
	END;
BEGIN
	NEW(caller, command);
END ExecuteCommandFor;

(* Report errors while parsing *)
PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("HotKeys: Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
	KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
	hasErrors := TRUE
END Error;

PROCEDURE Read(CONST name : ARRAY OF CHAR; context : Commands.Context);
VAR f : Files.File; scanner : XMLScanner.Scanner; parser : XMLParser.Parser; reader : Files.Reader; doc : XML.Document;
BEGIN
	hasErrors := FALSE;
	f := Files.Old(name);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader); scanner.reportError := Error;
		NEW(parser, scanner); parser.reportError := Error;
		doc := parser.Parse();
		IF hasErrors THEN
			context.error.String("HotKeys: File "); context.error.String(name); context.error.String(" has errors."); context.error.Ln;
		ELSE
			CreateHotKeyList(doc);
			context.out.String("HotKeys: File "); context.out.String(name); context.out.String(" loaded."); context.out.Ln;
		END;
	ELSE
		context.error.String("HotKeys: File "); context.error.String(name); context.error.String(" not found"); context.error.Ln;
	END;
END Read;

(* Message preview handler for window manager. MUST NOT TRAP!!! *)
PROCEDURE Handle(VAR msg : WMMessages.Message; VAR discard : BOOLEAN);
VAR hotkey : HotKey;
BEGIN
	IF msg.msgType # WMMessages.MsgKey THEN RETURN; END;
	IF (msg.x >= 0) & (msg.x < 256) THEN
		hotkey := GetHotKey(CHR(msg.x), msg.flags, msg.y);
	END;
	IF hotkey # NIL THEN
		IF hotkey.remapping = NIL THEN
			ExecuteCommandFor(hotkey.command);
			discard := TRUE;
		ELSE
			msg.x := ORD(hotkey.remapping.ch);
			msg.flags := hotkey.remapping.flags;
			msg.y := hotkey.remapping.keysym;
		END;
	END;
END Handle;

PROCEDURE InstallHandler;
BEGIN
	ASSERT(manager = NIL);
	manager := WMWindowManager.GetDefaultManager();
	IF manager # NIL THEN
		manager.InstallMessagePreview(Handle);
	ELSE
		KernelLog.String("HotKeys: Window Manager not found."); KernelLog.Ln;
	END;
END InstallHandler;

(** Show all currently loaded hot keys *)
PROCEDURE Show*(context : Commands.Context); (** ~ *)
VAR nbrOfHotKeys : LONGINT; hk : HotKey;
BEGIN
	nbrOfHotKeys := 0;
	hk := hotkeys.next;
	WHILE hk # NIL DO
		INC(nbrOfHotKeys);
		context.out.String("Hotkey "); context.out.Int(nbrOfHotKeys, 2); context.out.String(": ");
		context.out.String(hk.keyString^);
		IF hk.keysym # NoKeysym THEN
			context.out.String(" Keysym: "); context.out.Hex(hk.keysym, 0);
		END;
		context.out.String(" Command: ");
		context.out.String(hk.command^); context.out.Ln;
		hk := hk.next;
	END;
	context.out.Int(nbrOfHotKeys, 0); context.out.String(" hot keys in total."); context.out.Ln;
END Show;

(** (Re)Load hotkeys of the specified file. If no filename is specified, the default filename is used *)
PROCEDURE Open*(context : Commands.Context); (** [filename] ~ *)
VAR filename : ARRAY 256 OF CHAR;
BEGIN
	hotkeys.next := NIL;
	IF context.arg.GetString(filename) THEN
		Read(filename, context);
	ELSE
		Read(DefaultHotKeyFile, context);
	END;
END Open;

PROCEDURE Cleanup;
BEGIN
	IF manager # NIL THEN manager.RemoveMessagePreview(Handle); END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(hotkeys); (* head of list *)
	InstallHandler;
END HotKeys.