MODULE UsbTouchscreen;  (** AUTHOR "felixf"; PURPOSE "USB Touchscreen drivers"; *)
(* 2014.04.02 felixf: USB touchscreen moved back as generic feature to HIDDrivers *)

IMPORT
	UsbHidDriver, Displays, Plugins, Objects, Modules;

VAR display: Displays.Display;

PROCEDURE GetDisplayDimensions (VAR w,h: LONGINT);
VAR o: Plugins.Plugin;
BEGIN
	IF display = NIL THEN
		o := Displays.registry.Get("");
		IF o # NIL THEN display := o(Displays.Display) END;
	END;
	IF display # NIL THEN
		w := display.width; h := display.height
	ELSE
		w := 1024; h := 768
	END;
END GetDisplayDimensions;
						
PROCEDURE Cleanup;
BEGIN
	UsbHidDriver.InstallDisplayDimensions(NIL);
END Cleanup;

PROCEDURE Install*;
BEGIN
	UsbHidDriver.InstallDisplayDimensions(GetDisplayDimensions);
END Install;


BEGIN
	display := NIL; 
	Modules.InstallTermHandler(Cleanup);
	Install;
END UsbTouchscreen.

SystemTools.Free UsbTouchscreen ~