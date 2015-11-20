MODULE WMKernelLog; (** AUTHOR "TF"; PURPOSE "Kernel log window"; *)

IMPORT
	Modules, KernelLogger, Strings, WMGraphics, WMComponents, DE := WMDocumentEditor,
	WMRestorable, WMMessages, WMWindowManager;

CONST
	WindowWidth = 640;
	WindowHeight = 420;

TYPE
	Window = OBJECT (WMComponents.FormWindow)
	VAR
		out : DE.Editor;

		PROCEDURE &New*(c : WMRestorable.Context);
		BEGIN
			NEW(out); out.alignment.Set(WMComponents.AlignClient);
			out.SetToolbar(DE.StoreButton + DE.ClearButton + DE.SearchButton + DE.WrapButton);
			out.editor.multiLine.Set(TRUE);

			IF (c # NIL) THEN
				Init(c.r - c.l, c.b - c.t, FALSE);
			ELSE
				Init(WindowWidth, WindowHeight, FALSE);
			END;

			SetContent(out);
			SetTitle(Strings.NewString("Kernel log"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMKernelLog.png", TRUE));

			out.SetText(KernelLogger.kernelLog);
			KernelLogger.kernelLog.AcquireRead;
			out.editor.tv.End(TRUE, FALSE); (*cursor.SetPosition(KernelLogger.kernelLog.GetLength());*)
			KernelLogger.kernelLog.ReleaseRead;

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
			ELSE
				WMWindowManager.DefaultAddWindow(SELF)
			END
		END New;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMKernelLog", "WMKernelLog.Restore", SELF, NIL)
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

VAR winstance : Window;

PROCEDURE Open*;
BEGIN
	IF winstance = NIL THEN
		NEW(winstance, NIL)
	ELSE
		WMWindowManager.DefaultBringToView(winstance, TRUE)
	END;
END Open;

PROCEDURE Restore* (context : WMRestorable.Context);
BEGIN
	NEW(winstance, context)
END Restore;

PROCEDURE Cleanup;
BEGIN
	IF winstance # NIL THEN winstance.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMKernelLog.

WMKernelLog.Open ~
SystemTools.Free WMKernelLog ~

KernelLogger.Mod
KernelLogger.Start ~
KernelLogger.Stop ~


