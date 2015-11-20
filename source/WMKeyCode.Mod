MODULE WMKeyCode;	(** AUTHOR "TF"; PURPOSE "Display key code of a pressed key"; *)

IMPORT
	Commands, WMRestorable, WMMessages, WMGraphics, Inputs, KernelLog,
	Modules, WMRectangles, Strings,
	WM := WMWindowManager;

TYPE
	Window = OBJECT(WM.BufferWindow)

		PROCEDURE &New*(c : WMRestorable.Context);
		BEGIN
			Init(300, 32, FALSE);
			canvas.Fill(WMRectangles.MakeRect(0,0, img.width, img.height), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			SetTitle(Strings.NewString("Key Code Display"));
			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c)
			ELSE
				WM.DefaultAddWindow(SELF)
			END;
		END New;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT);
		VAR t : ARRAY 128 OF CHAR;
			font : WMGraphics.Font;
			x, y : LONGINT;

			PROCEDURE WriteString(CONST s : ARRAY OF CHAR);
			VAR dx, dy : LONGINT;
			BEGIN
				font.GetStringSize(s, dx, dy);
				canvas.DrawString(x, y, s); INC(x, dx)
			END WriteString;

		BEGIN
			font := canvas.GetFont();
			x := 3; y := 14;
			canvas.Fill(WMRectangles.MakeRect(0,0, img.width, img.height), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			IF keysym # 0 THEN
				WriteString("Key: ");
				GetFlagsString(flags, t); WriteString(t);
				WriteString(" '"); t[0] := CHR(ucs); t[1] := 0X; WriteString(t); WriteString("' (");
				Strings.IntToHexStr(ucs, 0, t); WriteString(t); WriteString(")");

				x := 3; y := 14 + 14;
				WriteString("Keysym: ");
				Strings.IntToHexStr(keysym, 0, t);
				WriteString(t);
				WriteString(" ("); GetKeysymString(keysym, t); WriteString(t); WriteString(")");
			END;
			Invalidate(WMRectangles.MakeRect(0,0, img.width, img.height))
		END KeyEvent;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMKeyCode", "WMKeyCode.Restore", SELF, NIL)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		BEGIN
			Close^;
			winstance := NIL
		END Close;

	END Window;

VAR
	winstance : Window;
	manager : WM.WindowManager;

PROCEDURE GetKeysymString(keysym : LONGINT; VAR string: ARRAY OF CHAR);
BEGIN
	IF keysym = Inputs.KsBackSpace THEN string := "BackSpace";
	ELSIF keysym = Inputs.KsTab THEN string := "Tab";
	ELSIF keysym = Inputs.KsReturn  THEN string := "Return";
	ELSIF keysym = Inputs.KsPause THEN string := "Pause";
	ELSIF keysym = Inputs.KsScrollLock THEN string := "ScrollLock";
	ELSIF keysym = Inputs.KsSysReq THEN string := "SysReq";
	ELSIF keysym = Inputs.KsEscape THEN string := "Escape";
	ELSIF keysym = Inputs.KsDelete THEN string := "Delete";
	ELSIF keysym = Inputs.KsHome THEN string := "Home";
	ELSIF keysym = Inputs.KsLeft THEN string := "Left";
	ELSIF keysym = Inputs.KsUp THEN string := "Up";
	ELSIF keysym = Inputs.KsRight THEN string := "Right";
	ELSIF keysym = Inputs.KsDown THEN string := "Down";
	ELSIF keysym = Inputs.KsPageUp THEN string := "PageUp";
	ELSIF keysym = Inputs.KsPageDown THEN string := "PageDown";
	ELSIF keysym = Inputs.KsEnd THEN string := "End";
	ELSIF keysym = Inputs.KsPrint THEN string := "Print";
	ELSIF keysym = Inputs.KsInsert THEN string := "Insert";
	ELSIF keysym = Inputs.KsMenu THEN string := "Menu";
	ELSIF keysym = Inputs.KsBreak THEN string := "Break";
	ELSIF keysym = Inputs.KsNumLock THEN string := "NumLock";
	ELSIF keysym = Inputs.KsKPEnter THEN string := "KPEnter";
	ELSIF keysym = Inputs.KsKPMultiply THEN string := "KPMultiply";
	ELSIF keysym = Inputs.KsKPAdd THEN string := "KPAdd";
	ELSIF keysym = Inputs.KsKPSubtract THEN string := "KPSubtract";
	ELSIF keysym = Inputs.KsKPDecimal THEN string := "KPDecimal";
	ELSIF keysym = Inputs.KsKPDivide THEN string := "KPDivide";
	ELSIF keysym = Inputs.KsF1 THEN string := "F1";
	ELSIF keysym = Inputs.KsF2 THEN string := "F2";
	ELSIF keysym = Inputs.KsF3 THEN string := "F3";
	ELSIF keysym = Inputs.KsF4 THEN string := "F4";
	ELSIF keysym = Inputs.KsF5 THEN string := "F5";
	ELSIF keysym = Inputs.KsF6 THEN string := "F6";
	ELSIF keysym = Inputs.KsF7 THEN string := "F7";
	ELSIF keysym = Inputs.KsF8 THEN string := "F8";
	ELSIF keysym = Inputs.KsF9 THEN string := "F9";
	ELSIF keysym = Inputs.KsF10 THEN string := "F10";
	ELSIF keysym = Inputs.KsF11 THEN string := "F11";
	ELSIF keysym = Inputs.KsF12 THEN string := "F12";
	ELSIF keysym = Inputs.KsShiftL THEN string := "ShiftL";
	ELSIF keysym = Inputs.KsShiftR THEN string := "ShiftR";
	ELSIF keysym = Inputs.KsControlL THEN string := "ControlL";
	ELSIF keysym = Inputs.KsControlR THEN string := "ControlR";
	ELSIF keysym = Inputs.KsCapsLock THEN string := "CapsLock";
	ELSIF keysym = Inputs.KsMetaL THEN string := "MetaL";
	ELSIF keysym = Inputs.KsMetaR THEN string := "MetaR";
	ELSIF keysym = Inputs.KsAltL THEN string := "AltL";
	ELSIF keysym = Inputs.KsAltR THEN string := "AltR";
	ELSIF keysym = Inputs.KsNil THEN string := "No Key";
	ELSE
		string := "No Keysym";
	END;
END GetKeysymString;

PROCEDURE GetFlagsString(flags : SET; VAR string: ARRAY OF CHAR);
BEGIN
	string := "";
	IF Inputs.LeftCtrl IN flags THEN Strings.Append(string, "[LCTRL]"); END;
	IF Inputs.RightCtrl IN flags THEN Strings.Append(string, "[RCTRL]"); END;
	IF Inputs.LeftShift IN flags THEN Strings.Append(string, "[LSHIFT]"); END;
	IF Inputs.RightShift IN flags THEN Strings.Append(string, "[RSHIFT]"); END;
	IF Inputs.LeftAlt IN flags THEN Strings.Append(string, "[LALT]"); END;
	IF Inputs.RightAlt IN flags THEN Strings.Append(string, "[RALT]"); END;
	IF Inputs.LeftMeta IN flags THEN Strings.Append(string, "[LMETA]"); END;
	IF Inputs.RightMeta IN flags THEN Strings.Append(string, "[RMETA]"); END;
	IF Inputs.Release IN flags THEN Strings.Append(string, "[RELEASE]"); END;
END GetFlagsString;

(* Message preview handler for window manager. MUST NOT TRAP!!! *)
PROCEDURE Handle(VAR msg : WMMessages.Message; VAR discard : BOOLEAN);
VAR str: ARRAY 128 OF CHAR;
BEGIN
	discard := FALSE;
	IF msg.msgType = WMMessages.MsgKey THEN
		KernelLog.String("Key: UCS="); KernelLog.Hex(msg.x, 8);
		KernelLog.String(", KeySym="); KernelLog.Hex(msg.y, 8);
		KernelLog.String(" ("); GetKeysymString(msg.y, str); KernelLog.String(str); KernelLog.String(")");
		KernelLog.String(", Key: '");
		IF (31 < msg.x) & (msg.x < 128) THEN KernelLog.Char(CHR(msg.x)); END;
		KernelLog.String("', Flags="); GetFlagsString(msg.flags, str); KernelLog.String(str);
		KernelLog.Ln;
	END;
END Handle;

(** Start logging key messages to kernel log *)
PROCEDURE StartLog*(context : Commands.Context); (** ~ *)
BEGIN {EXCLUSIVE}
	IF manager = NIL THEN
		manager := WM.GetDefaultManager();
		IF manager # NIL THEN
			context.out.String("WMKeyCode: Log started."); context.out.Ln;
			manager.InstallMessagePreview(Handle);
		ELSE
			context.out.String("WMKeyCode: Could not retrieve default window manager."); context.out.Ln;
		END;
	ELSE
		context.out.String("WMKeyCode: Log is already started."); context.out.Ln;
	END;
END StartLog;

(** Stop logging key messages to kernel log *)
PROCEDURE StopLog*(context : Commands.Context);
BEGIN {EXCLUSIVE}
	IF manager # NIL THEN
		manager.RemoveMessagePreview(Handle);
		manager := NIL;
		context.out.String("WMKeyCode: Log stoppped."); context.out.Ln;
	ELSE
		context.out.String("WMKeyCode: Log is not running."); context.out.Ln;
	END;
END StopLog;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF winstance= NIL THEN NEW(winstance, NIL) END;
END Open;

PROCEDURE Restore* (context : WMRestorable.Context);
BEGIN {EXCLUSIVE}
	IF (winstance = NIL) THEN
		NEW (winstance, context)
	END;
END Restore;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF winstance # NIL THEN winstance.Close END;
	IF manager # NIL THEN manager.RemoveMessagePreview(Handle); END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMKeyCode.

WMKeyCode.Open ~

WMKeyCode.StartLog ~
WMKeyCode.StopLog ~

SystemTools.Free WMKeyCode ~