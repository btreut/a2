MODULE EFITest; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Test"; *)

IMPORT EFI, EFISimpleFS, EFIFileProtocol, EFILib, Trace, SYSTEM;

PROCEDURE TestFS;
VAR
	size : EFI.Int;
	buffer : ARRAY 1000 OF EFI.Handle;
	status : EFI.Status;
	prot : EFI.Protocol;
	fs : EFISimpleFS.Protocol;
	root : EFIFileProtocol.Protocol;
	file : EFIFileProtocol.Protocol;
	filename : ARRAY 32 OF EFI.Char16;
	buf : POINTER TO ARRAY 30 OF CHAR;
BEGIN
	EFILib.StringToLongString("\test.txt",filename);
	(*status := EFI.table.ConOut.OutputString(EFI.table.ConOut, filename);*)
	size := LEN(buffer)*4;
	status := EFI.table.BS.LocateHandle(EFI.ByProtocol, EFISimpleFS.GUID , 0, size, buffer);
	IF (status # EFI.Success) THEN
		Trace.String("Status: "); Trace.Int(status, 0); Trace.Ln;
		Trace.String("Error code: "); Trace.Int(status - EFI.Error,0); Trace.Ln;
	END;
	Trace.String("Buffer size: "); Trace.Int(size,0); Trace.Ln;
	IF ((status = EFI.Success) & (size > 0)) THEN
		status := EFI.table.BS.HandleProtocol(buffer[0], EFISimpleFS.GUID, prot);
		Trace.Int(status, 0); Trace.Ln;
		fs := SYSTEM.VAL(EFISimpleFS.Protocol,prot);
		Trace.Address(SYSTEM.VAL(ADDRESS, prot)); Trace.Ln;

		IF (fs # NIL) THEN
			status := fs.OpenVolume(fs, root);
			Trace.Int(status,0); Trace.Ln;
			IF status = EFI.Success THEN
				Trace.String("Trying to open the file ");
				status := EFI.table.ConOut.OutputString(EFI.table.ConOut, filename);
				Trace.Ln;
				status := root.Open(root, file, filename, EFIFileProtocol.ModeRead+EFIFileProtocol.ModeWrite, 0);
				IF status = EFI.Success THEN
					NEW(buf);
					size := 20;
					status := file.Read(file, size, ADDRESSOF(buf[0]));
					Trace.String(buf^);
					buf^ := "pipapo";
					size := LEN(buf);
					status := file.SetPosition(file, -1); (* EOF *)
					status := file.Write(file, size,buf);
					status := file.Close(file);
					Trace.Int(status,0);
				END;
			END;
		END;
	END;
END TestFS;

BEGIN
	Trace.Blue;
	Trace.String ("Hello ");
	Trace.Red;
	Trace.String ("World!");
	Trace.Ln;
	TestFS;
END EFITest.

Compiler.Compile  --objectFile=Generic --symbolFile=Textual --extensions
	Runtime.Mod Trace.Mod EFI.Mod EFITrace.Mod EFIFileProtocol.Mod EFISimpleFS.Mod EFILib.Mod EFITest.Mod ~
StaticLinker.Link --fileName=test.efi --fileFormat=EFI32 --displacement=401000H
	Runtime Trace EFI EFITrace EFISimpleFS EFIFileProtocol EFILib EFITest ~