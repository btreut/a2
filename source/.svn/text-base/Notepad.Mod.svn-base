MODULE Notepad; (** AUTHOR "TF"; PURPOSE "Simple Text Editor"; *)

IMPORT
	Modules, Commands, Options, Files, Strings, WMRestorable, XML,
	WMGraphics, WMComponents, WMMessages, WMWindowManager, WMDocumentEditor;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		editor- : WMDocumentEditor.Editor;

		PROCEDURE &New*(c : WMRestorable.Context);
		BEGIN
			IncCount;
			Init(850, 700, FALSE);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.fillColor.Set(WMGraphics.White);
			editor.SetToolbar({0..31});
			editor.SetWordWrap(TRUE);
			SetContent(editor);
			SetTitle(Strings.NewString("Notepad"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://Notepad.png", TRUE));

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					editor.FromXml(c.appData(XML.Element));
					Resized(GetWidth(), GetHeight())
				END
			ELSE WMWindowManager.DefaultAddWindow(SELF)
			END;
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR data : XML.Element;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data); data.SetName("NotepadData");
					editor.ToXml(data);
					x.ext(WMRestorable.Storage).Add("Notepad", "Notepad.Restore", SELF, data);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

(** Open document *)
PROCEDURE Open*(context : Commands.Context); (** [Options] [filename] ~ *)
VAR options : Options.Options; window : Window; filename : Files.FileName; format : ARRAY 32 OF CHAR;
BEGIN
	NEW(options);
	options.Add("f", "format", Options.String);
	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("format", format) THEN format := "AUTO"; END;
		NEW(window, NIL);
		IF context.arg.GetString(filename) THEN
			window.editor.Load(filename, format);
		END;
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR winstance : Window;
BEGIN
	NEW(winstance, context)
END Restore;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END Notepad.

SystemTools.Free Notepad~

Notepad.Open ~