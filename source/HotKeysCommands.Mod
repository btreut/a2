MODULE HotKeysCommands; (** AUTHOR "staubesv"; PURPOSE "Useful hot key commands"; *)
(**
 * This modules contains some commands considered being useful for execution via hot keys.
 *
 * Overview/Usage:
 *
 *	HotKeysCommands.SimulateMouse MouseX|MouseY|MouseButtons|MouseWheel value ~ generates mouse messages
 *
 *	HotKeysCommands.EnterCommand ~ opens a window that queries a command string that is executed on enter
 *	HotKeysCommands.ClearLog ~ clears the kernel log
 *
 *)

IMPORT
	SYSTEM,
	KernelLog, Modules, Commands, Streams, Strings,
	Inputs, KernelLogger,
	WMWindowManager, WMComponents, WMEditors, WMGraphics;

CONST
	(* Command window constants *)
	DefaultWidth = 400; DefaultHeight = 40;
	DefaultTextColor =  WMGraphics.White;
	DefaultTextBgColor =  00008080H;

	(* Mouse simulator constants *)
	MouseX = "MouseX";
	MouseY = "MouseY";
	MouseButtons = "MouseButtons";
	MouseWheel = "MouseWheel";

TYPE

	(* Window that queries a command string and executes it when pressing enter. Pressing the escape key closes the window. The
	 * window is also closed when it looses the focus *)
	Window = OBJECT (WMComponents.FormWindow)
	VAR
		editor : WMEditors.Editor;

		PROCEDURE HandleEnter(sender, data : ANY);
		VAR commandString : ARRAY 4096 OF CHAR; msg : ARRAY 128 OF CHAR; res : LONGINT;
		BEGIN
			editor.GetAsString(commandString);
			IF commandString # "" THEN
				Commands.Call(commandString, {}, res, msg);
				IF res # Commands.Ok THEN
					KernelLog.String("HotKeysCommands: Failed to execute '"); KernelLog.String(commandString);
					KernelLog.String("', res: "); KernelLog.Int(res, 0);
					KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")");
					KernelLog.Ln;
				END;
			END;
			Close;
		END HandleEnter;

		PROCEDURE HandleEscape(sender, data : ANY);
		BEGIN
			Close;
		END HandleEscape;

		PROCEDURE FocusLost;
		BEGIN
			Close;
		END FocusLost;

		PROCEDURE Close;
		BEGIN
			Close^; window := NIL;
		END Close;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		BEGIN
			NEW(editor);
			editor.alignment.Set(WMComponents.AlignClient);
			editor.onEnter.Add(HandleEnter);
			editor.onEscape.Add(HandleEscape);
			editor.allowScrollbars.Set(FALSE);
			editor.multiLine.Set(FALSE);
			editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editor.tv.defaultTextColor.Set(DefaultTextColor);
			editor.tv.defaultTextBgColor.Set(0);
			editor.fillColor.Set(DefaultTextBgColor);
			RETURN editor;
		END CreateForm;

		PROCEDURE &New*;
		VAR manager : WMWindowManager.WindowManager;
		BEGIN
			Init(DefaultWidth, DefaultHeight, TRUE);
			SetContent(CreateForm());
			SetTitle(Strings.NewString("Enter command: "));
			WMWindowManager.ExtAddWindow(SELF, 200, 100, {});
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			editor.SetFocus;
		END New;

	END Window;

VAR
	window : Window;

(** Generate mouse message *)
PROCEDURE SimulateMouse*(context : Commands.Context); (** MouseX|MouseY|MouseButtons|MouseWheel value ~ *)
VAR
	string : ARRAY 32 OF CHAR; value : LONGINT;
	msg : Inputs.MouseMsg;
	doHandle : BOOLEAN;
BEGIN
	IF context.arg.GetString(string) THEN
		IF context.arg.GetInteger(value, FALSE) THEN
			doHandle := TRUE;
			IF Strings.Match(string, MouseX) THEN msg.dx := value;
			ELSIF Strings.Match(string, MouseY) THEN msg.dy := value;
			ELSIF Strings.Match(string, MouseWheel) THEN msg.dz := value;
			ELSIF Strings.Match(string, MouseButtons) THEN msg.keys := SYSTEM.VAL(SET, value);
			ELSE
				doHandle := FALSE;
			END;
			IF doHandle THEN Inputs.mouse.Handle(msg); END;
		END;
	END;
END SimulateMouse;

(** Opens a window that queries a command string and executes it on enter *)
PROCEDURE EnterCommand*; (** ~ *)
BEGIN {EXCLUSIVE}
	IF window = NIL THEN NEW(window); END;
END EnterCommand;

(** Clear kernel log *)
PROCEDURE ClearLog*; (** ~ *)
BEGIN
	KernelLogger.kernelLog.AcquireWrite;
	KernelLogger.kernelLog.Delete(0, KernelLogger.kernelLog.GetLength());
	KernelLogger.kernelLog.ReleaseWrite;
END ClearLog;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF window # NIL THEN window.Close; window := NIL; END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END HotKeysCommands.

HotKeysCommands.ClearLog ~
HotKeysCommands.EnterCommand ~
HotKeysCommands.SimulateMouse MouseWheel -3 ~

SystemTools.Free HotKeysCommands ~
