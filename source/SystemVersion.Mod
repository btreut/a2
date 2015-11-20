MODULE SystemVersion; (** AUTHOR "Patrick Hunziker"; PURPOSE "unequivocally identify system by combined CRC of Kernel"; *)
(* load this module early in the boot sequence, but after the statically linked modules. Currently, it is called early through Traps.Mod  *)

IMPORT
	Modules, CRC, KernelLog;

	VAR	BootCRC-: LONGINT;
	
	(* combined CRC of those Kernel Modules that loaded at this point in time.	 *)
	PROCEDURE GetKernelCRC*():LONGINT;
	VAR m:Modules.Module; crc: CRC.CRC32;
	BEGIN
		NEW(crc);
		m:=Modules.ModuleByName("Kernel32"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Trace"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Machine"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Heaps"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Modules"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Objects"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Kernel"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("KernelLog"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Streams"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Commands"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Files"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("WinFS"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("Loader"); IF m#NIL THEN crc.Add(m.crc) END;
		m:=Modules.ModuleByName("BootConsole"); IF m#NIL THEN crc.Add(m.crc) END;
		RETURN crc.Get()
	END GetKernelCRC;
	
	
	PROCEDURE GetKernelDate(CONST name: ARRAY OF CHAR; VAR d,t: LONGINT): BOOLEAN;
	BEGIN
		(*! TBD*)
		d:=0; t:=0; RETURN FALSE;
	END GetKernelDate;
	
	PROCEDURE Test*;
	BEGIN
		KernelLog.String("Kernel CRC at boot time: "); KernelLog.Hex(BootCRC,8); KernelLog.Ln;
		KernelLog.String("Kernel CRC now: "); KernelLog.Hex(GetKernelCRC(),8); KernelLog.Ln;
	END Test;
	

BEGIN
	BootCRC:=GetKernelCRC();
END SystemVersion.

SystemVersion.Test
SystemTools.FreeDownTo SystemVersion ~

