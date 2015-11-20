MODULE WMUtilities;  (** AUTHOR "fof"; PURPOSE "Utilities for easy opening of windows, Streams.Writers etc. "; *)

IMPORT
	Modules, Commands, Options, Strings, TextUtilities,
	WMWindowManager, WMMessages, WMGraphics, WMComponents, WMDocumentEditor, Kernel;

CONST
	Buttons = WMDocumentEditor.StoreButton + WMDocumentEditor.FormatButton + WMDocumentEditor.SearchButton
		+ WMDocumentEditor.WrapButton + WMDocumentEditor.ClearButton;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		editor-: WMDocumentEditor.Editor;
		visible: BOOLEAN;

		PROCEDURE &New*(CONST title : ARRAY OF CHAR; width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			Init(width, height, alpha);
			IncCount;
			visible := TRUE;

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.fillColor.Set(WMGraphics.White);
			editor.SetToolbar(Buttons);

			SetContent(editor);
			SetTitle(Strings.NewString(title));

			WMWindowManager.DefaultAddWindow(SELF);
		END New;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		BEGIN
			visible := FALSE;
			Close^;
			DecCount;
		END Close;

	END Window;

TYPE

	WindowWriter*= OBJECT (TextUtilities.TextWriter)
	VAR
		window-: Window;

		PROCEDURE IsVisible*() : BOOLEAN;
		BEGIN
			RETURN window.visible;
		END IsVisible;

		PROCEDURE SetWindowBgColor*(color : LONGINT);
		BEGIN
			window.editor.fillColor.Set(color);
			window.editor.editor.fillColor.Set(color);
		END SetWindowBgColor;

		PROCEDURE SetWindowIcon*(image : WMGraphics.Image);
		BEGIN
			window.SetIcon(image);
		END SetWindowIcon;

		PROCEDURE Close*;
		BEGIN
			IF window.visible THEN window.Close; END;
		END Close;

		PROCEDURE &New*(CONST title : ARRAY OF CHAR; width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			NEW(window, title, width, height, alpha);

			Init(window.editor.editor.text);
		END New;

	END WindowWriter;

VAR
	nofWindows : LONGINT; timeout: BOOLEAN;

(** Call the specified command and redirect its output streams to a WindowWriter *)
PROCEDURE Call*(context : Commands.Context); (** command ~ *)
VAR
	writer: WindowWriter;
	command, msg : ARRAY 128 OF CHAR;
	flags : SET;
	options : Options.Options;
	newContext : Commands.Context;
	res : LONGINT;
	fontName: ARRAY 128 OF CHAR;
BEGIN
	NEW(options);
	options.Add("b", "blocking", Options.Flag);
	options.Add("f","font",Options.String);
	IF options.Parse(context.arg, context.out) THEN
		context.arg.SkipWhitespace; context.arg.String(command);
		NEW(writer, command, 700, 480, FALSE);
		IF options.GetString("font",fontName) THEN writer.SetFontName(fontName) END;
		NEW(newContext, context.in, context.arg, writer, writer, context.caller);
		IF options.GetFlag("blocking") THEN flags := {Commands.Wait}; ELSE flags := {}; END;
		Commands.Activate(command, newContext, flags, res, msg);
		IF (res # Commands.Ok) THEN
			writer.String("ERROR: "); writer.String(msg); writer.Update;
		END;
	END;
END Call;

PROCEDURE TestWindow*;
VAR window : Window;
BEGIN
	NEW(window, "Test Window", 700, 480, FALSE);
END TestWindow;

PROCEDURE TestWindowWriter*;
VAR w : WindowWriter;
BEGIN
	NEW(w, "Test Window Writer", 700, 480, FALSE);
	w.String("This is a test"); w.Ln; w.Update;
END TestWindowWriter;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Timeout;
BEGIN{EXCLUSIVE}
	timeout := TRUE
END Timeout;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
	 timer: OBJECT VAR timer: Kernel.Timer; BEGIN{ACTIVE} NEW(timer); timer.Sleep(100); Timeout END;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	WHILE nofWindows >0 DO
		m.Broadcast(msg);
		timeout := FALSE; NEW(timer);
		AWAIT (nofWindows = 0) OR timeout;
	END;
END Cleanup;
BEGIN
	Modules.InstallTermHandler (Cleanup);
END WMUtilities.

SystemTools.Free WMUtilities ~
SystemTools.FreeDownTo WMUtilities ~

WMUtilities.Call SystemTools.List plugins ~

WMUtilities.TestWindow ~
WMUtilities.TestWindowWriter ~
 