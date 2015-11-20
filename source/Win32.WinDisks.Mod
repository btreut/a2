MODULE WinDisks;   (**  AUTHOR "fof"; PURPOSE "module to access partitions under Windows";  **)

IMPORT Kernel32, SYSTEM, Strings, KernelLog, Streams, Commands, Disks, Plugins, Modules, WinFS;

VAR
	DeviceIoControl: PROCEDURE {WINAPI} ( hDevice: Kernel32.HANDLE;  dwIoControlCode: LONGINT;  VAR lpInBuffer: ARRAY OF SYSTEM.BYTE;  nInBufferSize: LONGINT;
																	    VAR lpOutBuffer: ARRAY OF SYSTEM.BYTE;  nOutBufferSize: LONGINT;  VAR lpBytesReturned: LONGINT;  lpOverlapped: ANY ): Kernel32.BOOL;

	SetFilePointer: PROCEDURE {WINAPI} ( hFile: Kernel32.HANDLE;  lDistanceToMove: LONGINT;  VAR lpDistanceToMoveHigh: LONGINT;  dwMoveMethod: LONGINT ): LONGINT;

CONST
	MaxExtents = 1;   (* do not handle more than one extents (yet?) *)
	BlockNumberInvalid* = 101;  Error* = 102;

TYPE
	DISK_GEOMETRY = RECORD
		Cylinders: HUGEINT;
		MediaType: LONGINT;
		TracksPerCylinder: LONGINT;
		SectorsPerTrack: LONGINT;
		BytesPerSector: LONGINT;
	END;

	DISK_EXTENT = RECORD   (* immer auf größten Member aligniert *)
		DiskNumber: LONGINT;
		padding: LONGINT;
		StartingOffset: HUGEINT;
		ExtentLength: HUGEINT;
	END;

	VOLUME_DISK_EXTENTS = RECORD    (* immer auf größten Member aligniert: hugeint *)
		NumberOfDiskExtents: LONGINT;   (* the msdn reports something different (LONGINT) but it works this way only *)
		padding: LONGINT;
		extents: ARRAY   MaxExtents OF DISK_EXTENT;   (* should be dynamic *)
	END;

CONST
	(* Media Types *)
	Unknown = 0;
	(* 1 - 10: Floppy *)
	RemovableMedia = 11;  FixedMedia = 12;
	(* 13-..: Floopy *)

	IOCTL_DISK_GET_DRIVE_GEOMETRY = 00070000H;  VOLUME_GET_VOLUME_DISK_EXTENTS = 00560000H;
	FSCTL_LOCK_VOLUME = 90018H; FSCTL_UNLOCK_VOLUME = 9001CH; FSCTL_DISMOUNT_VOLUME = 90020H;

TYPE

	VirtualDisk = OBJECT (Disks.Device)
	VAR handle: Kernel32.HANDLE;
		size: LONGINT;
		next: VirtualDisk;
		drive: LONGINT;

		PROCEDURE Finish( VAR res: LONGINT );
		BEGIN
			Kernel32.CloseHandle( handle );  KernelLog.String("Disk closed"); KernelLog.Ln;
		END Finish;

		PROCEDURE Transfer( op, block, num: LONGINT;  VAR data: ARRAY OF CHAR;  ofs: LONGINT;  VAR res: LONGINT );
		VAR bool, n,err: LONGINT;  pos: HUGEINT;  poslow, poshigh: LONGINT;  large: Kernel32.LargeInteger;
		BEGIN {EXCLUSIVE}
			IF (block < 0) OR (num < 1) OR (block + num > size) THEN res := BlockNumberInvalid;  RETURN;  END;

			pos := LONG( block ) * LONG( blockSize );

			poslow := SHORT( pos );  poshigh := SHORT( ASH( pos, -32 ) );

			large.LowPart := poslow;  large.HighPart := poshigh;

			IF ~LockVolume(handle) THEN END;
			
			bool := SetFilePointer( handle, poslow, poshigh, Kernel32.FileBegin );
			IF bool = -1 THEN res := BlockNumberInvalid;  HALT( 101 );  RETURN;  END;

			IF op = Disks.Read THEN
				bool := Kernel32.ReadFile( handle, data[ofs], num * blockSize, n, NIL );
				IF (bool > 0) & (num * blockSize = n) THEN
					res := Disks.Ok;
				ELSE
					res := Error;
				END;
			ELSIF op = Disks.Write THEN
				IF Disks.ReadOnly IN flags THEN
					KernelLog.String("Write attempt on read-only mounted drive "); KernelLog.String(name); KernelLog.Ln;
					res := Disks.Ok;   (* readonly *)
				ELSE
					bool := Kernel32.WriteFile(handle,data[ofs],num*blockSize,n,NIL);
					IF (bool # 0)  & (num * blockSize = n)  THEN
						res := Disks.Ok;
					ELSE
						res := Error;
						err := Kernel32.GetLastError();
						KernelLog.String("last error = "); KernelLog.Int(err,1); KernelLog.Ln;
					END;
				END;
			ELSE res := Disks.Unsupported;
			END;
			
			IF ~UnlockVolume(handle) THEN END;

			IF Disks.Stats THEN
				IF op = Disks.Read THEN
					INC (NnofReads);
					IF (res = Disks.Ok) THEN INC (NbytesRead, num * blockSize);
					ELSE INC (NnofErrors);
					END;
				ELSIF op = Disks.Write THEN
					INC (NnofWrites);
					IF (res = Disks.Ok) THEN INC (NbytesWritten, num * blockSize);
					ELSE INC (NnofErrors);
					END;
				ELSE
					INC (NnofOthers);
				END;
			END;
		END Transfer;

		PROCEDURE GetSize( VAR size, res: LONGINT );
		BEGIN
			size := SELF.size;  res := Disks.Ok;
		END GetSize;

		PROCEDURE Handle( VAR msg: Disks.Message;  VAR res: LONGINT );
		BEGIN
			res := Disks.Unsupported;
		END Handle;

		PROCEDURE & New*( handle: Kernel32.HANDLE;  CONST diskname: ARRAY OF CHAR; drive: LONGINT; flags: SET;  blockSize, blocks: LONGINT );
		BEGIN
			ASSERT( handle > 0 );  SELF.handle := handle;  SELF.blockSize := blockSize;  SELF.size := blocks;  SetName( diskname );  desc := "Windows Disk ";
			SELF.drive := drive;
			SELF.flags := flags;
		END New;

	END VirtualDisk;

VAR
	disks: VirtualDisk;   (* to enable cleanup when unloading module *)

	PROCEDURE AddDisk( vd: VirtualDisk );
	BEGIN {EXCLUSIVE}
		vd.next := disks;  disks := vd;
	END AddDisk;

	PROCEDURE RemoveDisk( vd: VirtualDisk );
	VAR d: VirtualDisk;
	BEGIN {EXCLUSIVE}
		IF disks = vd THEN disks := disks.next;
		ELSE
			d := disks;
			WHILE (d # NIL ) & (d.next # vd) DO d := d.next;  END;
			IF (d # NIL ) THEN d.next := d.next.next;  END;
		END;
	END RemoveDisk;

	PROCEDURE IsMounted( dev: Disks.Device ): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		IF dev.table # NIL THEN
			FOR i := 0 TO LEN( dev.table ) - 1 DO
				IF Disks.Mounted IN dev.table[i].flags THEN RETURN TRUE END
			END
		END;
		RETURN FALSE
	END IsMounted;

(** Remove virtual disk *)
	PROCEDURE Uninstall*(context : Commands.Context);   (** diskname ~ *)
	VAR diskname: Plugins.Name;  plugin: Plugins.Plugin;  drive: LONGINT; v: VirtualDisk;
	BEGIN
		context.arg.SkipWhitespace;
		context.arg.String(diskname);

		plugin := Disks.registry.Get( diskname );
		IF plugin = NIL THEN (* try to map disk name *)
			IF diskname[1] = ":" THEN
				drive := ORD(CAP(diskname[0]))-ORD("A");
				v := disks;
				WHILE(v#NIL) & (v.drive # drive) DO
					v := v.next;
				END;
				plugin := v;
			END;
		END;

		IF plugin # NIL THEN
			IF ~IsMounted( plugin( VirtualDisk ) ) THEN
				Disks.registry.Remove( plugin );  RemoveDisk( plugin( VirtualDisk ) );
				context.out.String( diskname );  context.out.String( " removed" );  context.out.Ln;
			ELSE
				context.error.String( diskname );  context.error.String( " is mounted." );  context.error.Ln;
			END;
		ELSE
			context.error.String( diskname );  context.error.String( " not found" );  context.error.Ln;
		END;
	END Uninstall;

	PROCEDURE Cleanup;
	VAR res: LONGINT;
	BEGIN {EXCLUSIVE}
		WHILE (disks # NIL ) DO disks.Finish( res );  Disks.registry.Remove( disks );  disks := disks.next;  END;
	END Cleanup;

	PROCEDURE ReportDiskGeometry( VAR pdg: DISK_GEOMETRY; out : Streams.Writer );
	VAR size: LONGREAL;
	BEGIN
		out.String( "Disk type: " );
		CASE pdg.MediaType OF
		| Unknown:
				out.String( "unknown" );
		| RemovableMedia:
				out.String( "removable media" );
		| FixedMedia:
				out.String( "fixed media" );
		ELSE out.String( "floppy" );
		END;
		out.Ln;  out.String( "Cylinders = " );  out.Int( SHORT( pdg.Cylinders ), 1 );  out.Ln;
		out.String( "TracksPerCylinder = " );  out.Int( pdg.TracksPerCylinder, 8 );  out.Ln;
		out.String( "SectorsPerTrack = " );  out.Int( pdg.SectorsPerTrack, 8 );  out.Ln;
		out.String( "BytesPerSector = " );  out.Int( pdg.BytesPerSector, 8 );  out.Ln;
		size := pdg.Cylinders;  size := size * pdg.TracksPerCylinder * pdg.SectorsPerTrack * pdg.BytesPerSector;
		out.String( "DiskSize = " );  OutSize( size, out );  out.Ln;
	END ReportDiskGeometry;

	PROCEDURE GetDiskGeometry( handle: Kernel32.HANDLE;  VAR pdg: DISK_GEOMETRY ): BOOLEAN;
	VAR done, returned: LONGINT;
	BEGIN
		done := DeviceIoControl( handle, IOCTL_DISK_GET_DRIVE_GEOMETRY, NIL , 0, pdg, SIZEOF( DISK_GEOMETRY ), returned, NIL );  RETURN done > 0;
	END GetDiskGeometry;
	
	(* lock, unlock and dismount only works on volumes specified as "X:". It does not work with PhysicalDrive.
	
	 *)
	PROCEDURE LockVolume(handle: Kernel32.HANDLE): BOOLEAN;
	VAR done,returned: LONGINT;
	BEGIN
		done := DeviceIoControl(handle, FSCTL_LOCK_VOLUME, NIL,0, NIL, 0, returned, NIL); 
		RETURN done > 0;
	END LockVolume;
	
	PROCEDURE UnlockVolume(handle: Kernel32.HANDLE): BOOLEAN;
	VAR done,returned: LONGINT;
	BEGIN
		done := DeviceIoControl(handle, FSCTL_UNLOCK_VOLUME, NIL,0, NIL, 0, returned, NIL); 
		RETURN done > 0;
	END UnlockVolume;
	
	PROCEDURE DismountVolume(handle: Kernel32.HANDLE): BOOLEAN;
	VAR done,returned: LONGINT;
	BEGIN
		done := DeviceIoControl(handle, FSCTL_DISMOUNT_VOLUME, NIL,0, NIL, 0, returned, NIL); 
		RETURN done > 0;
	END DismountVolume;
	

	PROCEDURE AppendInt( VAR name: ARRAY OF CHAR;  i: LONGINT );
	VAR str: ARRAY 8 OF CHAR;
	BEGIN
		Strings.IntToStr( i, str );  Strings.Append( name, str );
	END AppendInt;

	PROCEDURE OpenVolume( VAR handle: Kernel32.HANDLE;  flags: SET; CONST name: ARRAY OF CHAR; context : Commands.Context ): BOOLEAN;
	VAR devname: ARRAY 256 OF CHAR;  tflags: SET; errorcode : LONGINT;
	BEGIN
		Strings.Concat( "\\.\", name, devname );
		IF Disks.ReadOnly IN flags THEN tflags := {Kernel32.GenericRead} ELSE tflags := {(*2 (* Kernel32.GenericDelete *), *)Kernel32.GenericWrite,Kernel32.GenericRead} END;
		handle := Kernel32.CreateFile( devname, tflags, {Kernel32.FileShareRead, Kernel32.FileShareWrite}, NIL , Kernel32.OpenExisting, {}, Kernel32.NULL );
		IF (handle = Kernel32.InvalidHandleValue) THEN
			errorcode := Kernel32.GetLastError();
			context.error.String("Could not open '"); context.error.String(devname); context.error.String("' : ");
			CASE errorcode OF
				|Kernel32.ErrorFileNotFound:
					context.error.String('Drive or physical volume not found (Use a drive specification like "A:" or a phyiscal volume like PhysicalDrive0)');
				|Kernel32.ErrorAccessDenied:
					context.error.String("Access denied (Administrator privileges required)");
			ELSE
				context.error.String("Windows Error Code: "); context.error.Int(errorcode, 0);
			END;
			context.error.Ln;
		END;
		RETURN handle # Kernel32.InvalidHandleValue;
	END OpenVolume;

	PROCEDURE OutSize( f: LONGREAL; out : Streams.Writer );
	BEGIN
		IF f > 1.E9 THEN out.FloatFix( f / 1024 / 1024 / 1024, 4, 3, 0 );  out.String( " GiB" );
		ELSIF f > 1.E6 THEN out.FloatFix( f / 1024 / 1024, 4, 3, 0 );  out.String( " MiB" );
		ELSIF f > 1.E3 THEN out.FloatFix( f / 1024, 4, 3, 0 );  out.String( " KiB" );
		ELSE out.FloatFix( f, 4, 3, 0 );  out.String( " B" );
		END;
	END OutSize;

	PROCEDURE GetPhysicalDrive( VAR handle: Kernel32.HANDLE; flags: SET;  VAR name: ARRAY OF CHAR; context : Commands.Context );
	VAR done, returned: LONGINT;  extents: VOLUME_DISK_EXTENTS;  drive: LONGINT;  first, last: LONGREAL;  bps: LONGREAL;  pdg: DISK_GEOMETRY;   (* number of first and last block used *)
	BEGIN
		done := DeviceIoControl( handle, VOLUME_GET_VOLUME_DISK_EXTENTS, NIL , 0, extents, SIZEOF( VOLUME_DISK_EXTENTS ), returned, NIL );
		IF done > 0 THEN
			IF extents.NumberOfDiskExtents = 0 THEN
				context.error.String( "no disk extents used, probably the drive is physical already " );  context.error.Ln;
			ELSIF extents.NumberOfDiskExtents = 1 THEN
				drive := extents.extents[0].DiskNumber;
				IF GetDiskGeometry( handle, pdg ) THEN bps := pdg.BytesPerSector ELSE bps := 512 END;
				first := extents.extents[0].StartingOffset / bps;  last := extents.extents[0].ExtentLength / bps;  last := first + last;
				context.out.String( "Partition from Block " );  context.out.Int( ENTIER( first ), 1 );  context.out.String( " to " );  context.out.Int( ENTIER( last ), 1 );
				context.out.String( " in physical drive # " );  context.out.Int( drive, 1 );  OutSize( extents.extents[0].ExtentLength, context.out);  context.out.Ln;
				name := "PhysicalDrive";  AppendInt( name, drive );  context.out.String( "Mapping to drive : " );  context.out.String( name );  context.out.Ln;
				IF ~OpenVolume( handle, flags,name, context) THEN 
					context.error.String( "volume could not be opened. " ); context.error.Ln; 
				END;
			ELSE
				context.error.String( "cannot handle volumes with more than one extent (yet) " ); context.error.Ln;
			END;
		ELSE
			context.error.String( "GetPhysicalDrive: no success, probably the drive is already physical" ); context.error.Ln;
		END;
	END GetPhysicalDrive;

(** Add file as virtual disk *)
	PROCEDURE Install*(context : Commands.Context);   (** diskname filename [blocksize]  ~ *)
	VAR
		diskname, flagss: ARRAY 256 OF CHAR;  flags: SET;
		res: LONGINT; handle: Kernel32.HANDLE;  pdg: DISK_GEOMETRY;  size: LONGINT;  vd: VirtualDisk;  drive: LONGINT;
		i: LONGINT;
	BEGIN
		context.arg.SkipWhitespace;
		context.arg.String(diskname);
		context.arg.SkipWhitespace;
		flagss := ""; context.arg.String(flagss);

		flags := {Disks.ReadOnly};
		 i := 0;
		WHILE(flagss[i] # 0X) DO
			IF flagss[i] = "W" THEN
				EXCL(flags,Disks.ReadOnly);
			END;
			INC(i);
		END;

		IF diskname[1] = ":" THEN drive := ORD(CAP(diskname[0]))-ORD("A"); ELSE drive := -1 END;
		IF OpenVolume( handle, flags, diskname, context) THEN
			IF (diskname[1] = ":") & DismountVolume(handle) THEN
			END;
			GetPhysicalDrive( handle, flags,diskname, context );
			IF ~GetDiskGeometry( handle, pdg ) THEN
				Kernel32.CloseHandle( handle );
				context.error.String( "Could not determine disk geometry " );  context.error.Ln;
			ELSE
				ReportDiskGeometry( pdg, context.out);
				IF pdg.MediaType = RemovableMedia THEN INCL(flags,Disks.Removable) END;
				IF pdg.Cylinders > MAX( LONGINT ) THEN
					HALT( 100 )
				ELSE
					size := SHORT( pdg.Cylinders ) * pdg.TracksPerCylinder * pdg.SectorsPerTrack;
				END;

				NEW( vd, handle, diskname, drive, flags, pdg.BytesPerSector, size );  Disks.registry.Add( vd, res );
				IF res = Plugins.Ok THEN
					AddDisk( vd );
					context.out.String( diskname );  context.out.String( " registered." ); context.out.Ln;
				ELSE
					  Kernel32.CloseHandle( handle );
					context.out.String( "Could not register disk, res: " ); context.out.Int( res, 0 ); context.out.Ln;
				END;
			END;
		END;
	END Install;

	PROCEDURE Notification(type: LONGINT; drives: SET);
	VAR v: VirtualDisk; res: LONGINT;
	BEGIN
		IF type = WinFS.deviceArrival THEN
		ELSIF type = WinFS.deviceRemove THEN
			v := disks;
			WHILE(v # NIL) DO
				IF (v.drive >= 0) & (v.drive IN drives) THEN
					IF IsMounted (v) THEN
						KernelLog.String("Warning: Disk mounted but forcefully removed !"); KernelLog.Ln;
					END;
					Disks.registry.Remove( v ); v.Finish(res);  RemoveDisk( v );
					KernelLog.String( v.name );  KernelLog.String( " removed" );  KernelLog.Ln;
					v := disks;
				ELSE
					v := v.next;
				END;
			END;
		END;
	END Notification;

	PROCEDURE Init;
	VAR mod: Kernel32.HMODULE;
		str: ARRAY 64 OF CHAR;
	BEGIN
		str := "Kernel32.DLL";  mod := Kernel32.LoadLibrary( str );  str := "DeviceIoControl";  Kernel32.GetProcAddress( mod, str, SYSTEM.VAL( ADDRESS, DeviceIoControl ) );  str := "SetFilePointer";
		Kernel32.GetProcAddress( mod, str, SYSTEM.VAL( ADDRESS, SetFilePointer ) );
		IF DeviceIoControl = NIL THEN HALT( 100 ) END;
		IF SetFilePointer = NIL THEN HALT( 100 ) END;
		Modules.InstallTermHandler( Cleanup );
		WinFS.RegisterNotification(Notification);
	END Init;

BEGIN
	Init();
END WinDisks.


short description

WinDisks is a module to access volumes and partitions under WinAos.
One purpose is the access of file systems that are supported by Aos but not by Windows. The other is the partitioning of hard disks within WinAos.
It may thus also be used to install an entire native Aos system on a partition on the hard drive or USB memory stick etc.

To add a windows disk to the Aos system use the command

	WinDisks.Install DriveName ["RW"]

where
- DriveName can be one of "A:" to "Z:" or "PhysicalDriveX" where X has to be replaced by the physical drive number.
A drive name such as "C:" is matched to a PhysicalDriveX name, if appropriate.
It is better to use the "X:" format because the system can in general then perform an automatic unregistering if the device is becoming unavailable in Windows.
- If "PhysicalDriveX" is used to specify the drive, the logical volumes associated with it will not be dismounted, which can mean that write operations are unsuccesful 
- A volume is inserted read-only unless the optional parameter "RW" is provided.

To access the partitions of the drive you may use the Partition Tool.

To uninstall an installed volume in Aos, use the command

WinDisks.Uninstall DriveName .

~

Examples

WinDisks.Install "f:"
WinDisks.Install "c:"
WinDisks.Install "PhysicalDrive1" "RW"
WinDisks.Uninstall "C:" ~
WinDisks.Uninstall "PhysicalDrive0" ~
WinDisks.Uninstall "F:" ~
WinDisks.Install "f:" "RW" ~

SystemTools.Free WinDisks ~
