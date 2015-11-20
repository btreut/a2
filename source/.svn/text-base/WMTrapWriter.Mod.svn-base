MODULE WMTrapWriter; (** AUTHOR "fof"; PURPOSE "trap window writer"; *)

IMPORT
	Modules, Streams, TrapWriters, WMGraphics, WMUtilities;

VAR w: WMUtilities.WindowWriter;

PROCEDURE TrapWriterFactory*(): Streams.Writer;
BEGIN
	IF (w = NIL) OR (~w.IsVisible()) THEN
		NEW(w, "TRAPS", 860, 480, FALSE);
		w.SetWindowBgColor(WMGraphics.Red);
		w.SetWindowIcon(WMGraphics.LoadImage("WMIcons.tar://WMTrapWriter.png", TRUE));
		w.SetFontName("Courier");
		w.SetFontSize(12);
		w.SetFontColor(WMGraphics.Yellow);
		w.window.editor.SetWordWrap(TRUE);
	END;
	RETURN w;
END TrapWriterFactory;

PROCEDURE Install*;
BEGIN
	TrapWriters.InstallTrapWriterFactory (TrapWriterFactory)
END Install;

PROCEDURE Uninstall*;
BEGIN
	TrapWriters.UninstallTrapWriterFactory (TrapWriterFactory)
END Uninstall;

PROCEDURE HaltTest*;
BEGIN
	HALT(100);
END HaltTest;

PROCEDURE Cleanup;
BEGIN
	Uninstall;
	IF (w # NIL) THEN w.Close; END;
END Cleanup;

BEGIN
	w := NIL;
	Modules.InstallTermHandler(Cleanup);
END WMTrapWriter.

SystemTools.Free WMTrapWriter WMUtilities ~

WMTrapWriter.Install
WMTrapWriter.Uninstall
WMTrapWriter.HaltTest
