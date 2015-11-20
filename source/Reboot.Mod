MODULE Reboot; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Kernel, Files, FileTrapWriter, Machine, Commands;

PROCEDURE Do*(context: Commands.Context);
VAR timer: Kernel.Timer; file: Files.File; filename, name: Files.FileName; time: LONGINT;
BEGIN
	IF ~context.arg.GetInteger(time, FALSE) THEN time := 0 END;
	IF context.arg.GetString(filename) THEN
		file := FileTrapWriter.GetNewFile(filename, name);
		Files.Register(file);
	END;

	IF time > 0 THEN
		NEW(timer); timer.Sleep(time)
	END;

	Machine.Shutdown(TRUE);
END Do;

END Reboot.

Reboot.Do 3000 rebooted ~
Reboot.Do 3000 ~
