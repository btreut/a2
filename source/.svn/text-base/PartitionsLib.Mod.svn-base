MODULE PartitionsLib; (** AUTHOR "staubesv"; PURPOSE "Partitioning and formatting tool for N2KFS and AosFS. "; *)
(**
 * Overview:
 *
 * 	Operation:				Base object  for generic disk operation
 *	OperationManager		Manages operation objects
 *	DiskModel:				Internal represenation of currenly present devices (and their partition layout). Provides locking mechanism for
 *							disk operations.
 *
 * Note: Most of the actual disk operation implementation has been taken from Partitions.Mod from "pjm".
 *
 * History:
 *
 *	05.08.2005	Cleanup (staubesv)
 *	25.11.2005	Integrated windows 2000 workaround from Partitions.Mod, fixed CheckDisk operation reporting negative speeds,
 *				Operation uses Text instead of StringWriter (staubesv)
 *	07.12.2005	Fixed InitOBL (did not use disk geometry correctly -> OBL failed when booting), fixed progress report of FileToPartition (staubesv)
 *	09.12.2005	Fixed Operation.SetStart deadlock (staubesv)
 *	12.12.2005	Operation object uses exception handling to release ressources -> more stable, adapted operations (staubesv)
 *	12.12.2005	Implemented Reader/Writer locks (staubesv)
 *	15.12.2005	DiskModel.Update now also calls DiskModel.OnChanged (staubesv)
 *	16.12.2005	Operation.state.min/cur/max type change to HUGEINT to prevent overflows (staubesv)
 *	19.12.2005	Fixed DeletePartition/CreatePartition (staubesv)
 *	06.01.2006	Fixed nn fsRes handling (staubesv)
 *	17.01.2006	Made output more appropriate for Partitions front-end, fixed Configuration.ParseConfig (staubesv)
 *	24.02.2006	PartitionToFile & FileToPartition not dependent on device blocksize anymore (staubesv)
 *	09.03.2006	Improved DiskModel.GetFS and renamed it to DiskModel.AssignFileSystems (staubesv)
 *	18.03.2006	Small changes/cleanup in ShowBlocks, added Operation.SetParent, added InstallBootManager (staubesv)
 *	12.08.2006	GetDriveNum: treat partitioned devices as non-removable
 *	02.08.2007	DiskModel.GetDisk: Fixed NIL trap if no disks are available (staubesv)
 *)

(*
 *	OBL variables (in boot block)
 *
 *	ofs	size	description
 *	00	03	?,?,?
 *	03	06	"OBERON"
 *	09	01	?
 *	0A	01	flag (if 0, start config string editor, otherwise, bits 0-4 tested with shift bits from BIOS)
 *	0B	02	?
 *	0D	01	?
 *	0E	02	reserved blocks
 *	10	01	config table size in blocks
 *	11	02	?
 *	13	02	total blocks (or 0)
 *	15	01	?
 *	16	02	?
 *	18	02	blocks per track
 *	1A	02	heads
 *	1C	04	boot block number
 *	20	04	total blocks (if 13 is 0)
 *	24	01	drive number (0, 1 for floppy, 80H, 81H, ... for hard disk)
 *
 *	AosFS Table Format (in boot block)
 *
 *	New (post 14.03.00)
 *	1F0H	4	fileSystemOfs (in 512-byte blocks, relative to this block)
 *	1F4H	4	fileSystemSize (in sectors, aka volume blocks)
 *	1F8H	4	id = 21534F41H ("AOS!")
 *	1FCH	1	version = 1X
 *	1FDH	1	sectorSizeLog2 = 12 (4096)
 *	1FEH	1	bootID0 = 055X
 *	1FFH	1	bootID1 = 0AAX
 *
 *	Old (pre 14.03.00)
 *	1E0H	4	fileSystemOfs (in blocks, relative to this block)
 *	1E4H	4	fileSystemSize (in sectors)
 *	1E8H	16	volumeName (0X-terminated)
 *	1F8H	4	id = 5245424FH ("OBER")
 *	1FCH	1	version = 1X
 *	1FDH	1	sectorSizeLog2 = 12 (4096)
 *	1FEH	1	bootID0 = 055X
 *	1FFH	1	bootID1 = 0AAX
 *
 *	Partition layout (N2KFS and AosFS overlayed)
 *
 *	block	description
 *	 0..3	OBL.Bin (4 blocks)
 *		<-- BootLoaderSize
 *	4..7	Config table (size from 10H)
 *		<-- start of BootFile
 *		<-- reserved blocks pointer (from 0EH)
 *	x..	N2KFS
 *		<-- fileSystemOfs pointer (from 1F0H)
 *	y..	AosFS
 *)

IMPORT KernelLog,  Kernel, Modules, Commands, AosDisks := Disks, Files, Dates, Strings, Plugins, Streams, Objects,
	WMGraphics, WMEvents, DiskVolumes, OldDiskVolumes, FATVolumes, ISO9660Volumes, Texts, TextUtilities;

CONST
	(* Result codes *)
	Ok* = 0;

	(* Operation status *)
	StatusRunning* = {1};
	StatusAborted* = {2};
	StatusWaiting* = {3};
	StatusFinished* = {5};
	StatusError* = {4};

	(* Disk model lock types. More restrictive lock types must have lower numbers! *)
	WriterLock* = 0; (* default *)
	ReaderLock* = 1;

	(* DetectFS return codes *)
	UnknownFS* = 0;
	NativeFS* = 1;
	OldAosFS32* = 2;
	AosFS32* = 3;
	FatFS* = 4;
	AosFS128* = 5;

	Trace = {};

	TraceGeometry = {1};
	TraceGetFS = {2};
	TraceLocks = {3};

	Debug = TRUE;

	ShowReserved = FALSE;	(* Show reserved space in partitions *)

	DateTimeFormat = "yyyy.mm.dd hh:nn:ss";

	(* Default name  for  boot file *)
	BootFileName = "IDE.Bin";
	MaxBootLoaderSize=10; (* blocks *)

	BS* = 512;
	MinPartSize = 64; (* absolute minimum number of sectors in Oberon partition *)

	N2KSS = 2048;
	N2KBPS = N2KSS DIV BS;
	N2KDirMark = LONGINT(9B1EA38DH);

	AosSSLog2 = 12;
	AosSS = ASH(1, AosSSLog2); (* Sector Size *)
	AosBPS = AosSS DIV BS;
	AosSF = 29;
	AosSTS = 128;
	AosXS = AosSS DIV 4;
	AosHS = 568;
	AosDirMark = LONGINT(9B1EA38DH);

	AosType = 76;
	NativeType1 = 79;
	NativeType2 = 80;

	FSID = 21534F41H;
	FSID0 = 5245424FH;
	FSIDOBL = 44494449H;
	FSVer = 2;
	FSRes = 640*1024 DIV BS; (* default blocks reserved for boot file *)

	MaxConfig* = 2000; (* less than tsize*BS *)
	MaxConfigString* = 4096;

	WholeDisk = 256;
	FreeSpace = -1;
	ReservedSpace = -2;

	NoSpaceAvailable = 9001;
	CoreMismatch = 9002; 		(* core file on disk does not match *)
	CoreChecksumError = 9003; 	(* core file checksum mismatch *)

	DisketteLimit = 2880; (* if device has <= this many sectors, assume it is a diskette without partition table *)

	(* Offsets of slot in partition table of MBR/EPBR *)
	Slot1 = 1BEH;
	Slot2 = 1CEH;
	Slot3 = 1DEH;
	Slot4 = 1EEH;

	MaxStringLength = 1024;

TYPE

	Block* =  ARRAY BS OF CHAR;

TYPE

	Disk* = RECORD
		device* : AosDisks.Device;
		table* : AosDisks.PartitionTable; (* extended copy of device.table *)
		size*, res*: LONGINT; (* device.GetSize(size, res); Size is valid only when res = AosDisks.Ok *)
		geo* : AosDisks.GetGeometryMsg; (* device.Handle(geo, res); geo is valid only when res = AosDisks.Ok *)
		gres* : LONGINT;
		fs* : POINTER TO ARRAY OF Files.FileSystem;
		isDiskette* : BOOLEAN; (* is this a floppy drive diskette? *)
	END;

	Disks* = POINTER TO ARRAY OF Disk;

	Selection* = RECORD
		disk* : Disk;
		partition* : LONGINT;
	END;

TYPE

	RegionLock = POINTER TO RECORD
		device : AosDisks.Device;
		partition : AosDisks.Partition; 	(* we consider only partition.start & partition.size *)
		type : LONGINT; 				(* lock type: WriterLock | ReaderLock *)
		nbrOfReaders : LONGINT; 		(* ReaderLock only: How many readers hold the lock? *)
		next : RegionLock;
	END;

TYPE

	DisksModel* = OBJECT
	VAR
		lockedBy : ANY;
		lockLevel : LONGINT;
		onChanged* : WMEvents.EventSource; (** does not hold the lock, if called *)
		devTable : Plugins.Table;

		disks- : Disks;
		usedDisks : RegionLock; (* note: synchronization with disks not needed *)

		(* IF check = TRUE, only partitions with the AosDisks.Valid flags set are returned *)
		PROCEDURE GetDisk*(CONST devpart : ARRAY OF CHAR; VAR selection : Selection; check : BOOLEAN) : BOOLEAN;
		VAR devname, partStr : ARRAY 32 OF CHAR; i, j : LONGINT;
		BEGIN
			IF disks # NIL THEN
				i := 0;
				LOOP (* get device name *)
					devname[i] := devpart[i]; (* at least one character before "#" *)
					INC(i); IF (i >= LEN(devpart)) OR (i >= LEN(devname)) OR (devpart[i]="#") THEN EXIT END;
				END;
				IF (i < LEN(devpart)) & (devpart[i]="#") THEN
					devname[i] := 0X; INC(i);
					j := 0;
					LOOP (* get partition number *)
						partStr[j] := devpart[i];
						INC(i); INC(j); IF (i >= LEN(devpart)) OR (j >= LEN(partStr)) OR (devpart[i]=0X) THEN EXIT END;
					END;
					IF (i < LEN(devpart)) THEN
						Strings.StrToInt(partStr, selection.partition);
						Acquire; (* lock disks[] *)
						i := 0;
						LOOP (* get disk record *)
							IF (disks[i].device # NIL) & Strings.Match(devname, disks[i].device.name) THEN EXIT END;
							INC(i); IF i >= LEN(disks) THEN EXIT END;
						END;
						Release;
						IF (i < LEN(disks)) THEN (* disk record found *)
							IF (disks[i].device # NIL) & (disks[i].table # NIL) & (disks[i].device.table # NIL) & (selection.partition >= 0) THEN
								IF (check & ((disks[i].device.table # NIL) & (selection.partition < LEN(disks[i].device.table)))) OR (~check & (selection.partition < LEN(disks[i].table))) THEN
									selection.disk := disks[i];
									RETURN TRUE;
								END;
							END;
						ELSIF Debug THEN KernelLog.String("PartitionsLib.diskModel.GetDisk: "); KernelLog.String(devpart); KernelLog.String(" not found"); KernelLog.Ln;
						END;
					ELSIF Debug THEN  KernelLog.String("PartitionsLib.diskModel.GetDisk: "); KernelLog.String(devpart); KernelLog.String(" : ParseError"); KernelLog.Ln;
					END;
				ELSIF Debug THEN  KernelLog.String("PartitionsLib.diskModel.GetDisk: "); KernelLog.String(devpart); KernelLog.String(" : ParseError"); KernelLog.Ln;
				END;
			ELSIF Debug THEN KernelLog.String("PartitionsLib.diskModel.GetDisk: No disks available"); KernelLog.Ln;
			END;
			RETURN FALSE;
		END GetDisk;

		(* Lock a partition. Returns TRUE if locked succeded, FALSE otherwise *)
		PROCEDURE AcquirePartition*(disk : Disk; partition : LONGINT; locktype : LONGINT) : BOOLEAN;
		VAR table : AosDisks.PartitionTable; lock, temp : RegionLock; getReaderLock : BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(disk.device # NIL);
			(* check whether region is already locked *)
			NEW(table, 2);
			table[0] := disk.table[partition];
			temp := usedDisks; getReaderLock := FALSE;
			LOOP
				IF temp.next = NIL THEN EXIT END; (* region is not locked *)
				IF temp.next.device = disk.device THEN (* there are some operations locking region on the device *)
					table[1] := temp.next.partition;
					IF PartitionsOverlap(table, 0, 1) THEN
						IF (locktype = WriterLock) OR (temp.next.type = WriterLock) THEN
							getReaderLock := FALSE;
							EXIT (* region is locked ! *)
						ELSE
							getReaderLock := TRUE;
						END;
					END;
				END;
				temp := temp.next;
			END;
			IF temp.next = NIL THEN
				IF getReaderLock THEN (* we can acquire a reader lock only *)
					temp := usedDisks;
					WHILE temp.next # NIL DO
						IF (temp.next.device = disk.device) & PartitionsOverlap(table, 0, 1) THEN INC(temp.next.nbrOfReaders); END;
						temp := temp.next;
					END;
				ELSE (* the region has not yet been locked... lock it *)
					NEW(lock); lock.device := disk.device; lock.partition := disk.table[partition]; lock.type := locktype;
					IF locktype = ReaderLock THEN lock.nbrOfReaders := 1; END;
					temp.next := lock;
				END;
				IF Trace * TraceLocks # {} THEN KernelLog.String("LOCK GRANTED: "); ShowLocks; END;
				RETURN TRUE;
			END;
			IF Trace * TraceLocks # {} THEN KernelLog.String("LOCK DENIED: "); ShowLocks; END;
			RETURN FALSE;
		END AcquirePartition;

		(* Release a partition. *)
		PROCEDURE ReleasePartition*(disk : Disk; partition : LONGINT);
		VAR temp : RegionLock;
		BEGIN {EXCLUSIVE}
			ASSERT(disk.device # NIL);
			temp := usedDisks;
			WHILE (temp.next # NIL) DO
				IF (temp.next.device = disk.device) & (temp.next.partition.start = disk.table[partition].start) &
					(temp.next.partition.size = disk.table[partition].size) THEN (* lock found *)
					IF temp.next.type = WriterLock THEN
						temp.next := temp.next.next;
						IF Trace * TraceLocks # {} THEN KernelLog.String("WRITER LOCK REMOVED: "); ShowLocks; END;
						RETURN;
					ELSE
						DEC(temp.next.nbrOfReaders);
						IF temp.next.nbrOfReaders <= 0 THEN (* release region *)
							temp.next := temp.next.next;
						ELSE
							temp := temp.next;
						END;
					END;
				ELSE
					temp := temp.next;
				END;
			END;
			IF Trace * TraceLocks # {} THEN KernelLog.String("AFTER RELEASING A LOCK: "); ShowLocks; END;
		END ReleasePartition;

		(* Show all locks currently held *)
		PROCEDURE ShowLocks;
		VAR temp : RegionLock;
		BEGIN
			IF Trace * TraceLocks # {} THEN
				KernelLog.String("PartitionsLib.DiskModel locks: "); KernelLog.Ln;
				temp := usedDisks;
				IF temp = NIL THEN
					KernelLog.String("no locks granted");
				ELSE
					WHILE temp.next # NIL DO
						KernelLog.String("Device: "); KernelLog.String(temp.next.device.name);
						KernelLog.String(", LBA start: "); KernelLog.Int(temp.next.partition.start, 0);
						KernelLog.String(", LBA end: "); KernelLog.Int(temp.next.partition.start + temp.next.partition.size - 1, 0);
						KernelLog.String(", Lock Type: ");
						IF temp.next.type = WriterLock THEN
							KernelLog.String("WriterLock");
						ELSE
							KernelLog.String("ReaderLock ["); KernelLog.Int(temp.next.nbrOfReaders, 0); KernelLog.String(" readers]");
						END;
						temp := temp.next;
					END;
				END;
				KernelLog.Ln;
			END;
		END ShowLocks;

		PROCEDURE &Init*;
		VAR ignore : LONGINT;
		BEGIN
			NEW(usedDisks);
			AosDisks.registry.GetAll(devTable);
			NEW(onChanged, SELF,Strings.NewString("DiskModelChanged"), NIL, NIL);
			lockLevel := 0;
			UpdateAllDisks;
			AosDisks.registry.AddEventHandler(DiskEventHandler, ignore);
		END Init;

		(** Update partition tables & file systems of all disk devices *)
		PROCEDURE Update*;
		BEGIN
			UpdateAllDisks;
			onChanged.Call(NIL);
		END Update;

		PROCEDURE UpdateAllDisks;
		VAR
			dev : AosDisks.Device;
			doClose : BOOLEAN;
			errorWriter : Streams.StringWriter;
			errorString : ARRAY 1024 OF CHAR;
			i, j, res : LONGINT;
		BEGIN (* caller must hold lock *)
			Acquire;
			IF devTable # NIL THEN
				NEW(disks, LEN(devTable));
				FOR i := 0 TO LEN(devTable)-1 DO

					dev := devTable[i] (AosDisks.Device);
					disks[i].device := dev;
					(* Hack to support diskette drives *)
					IF Strings.Match("Diskette0*", dev.name) THEN
						disks[i].isDiskette := TRUE;
						doClose := FALSE;
						IF (dev.openCount < 1) THEN
							dev.Open(disks[i].res); (* ignore res *)
							doClose := TRUE;
						END;
					END;

					dev.GetSize(disks[i].size, disks[i].res);
					IF disks[i].res = AosDisks.MediaChanged THEN dev.GetSize(disks[i].size, disks[i].res) END; (* we didn't use Open, so retry *)
					IF disks[i].res # AosDisks.MediaMissing THEN
						AosDisks.UpdatePartitionTable(dev, res);
						IF ((res = AosDisks.Ok) OR (res = AosDisks.DeviceInUse)) & (dev.table # NIL) THEN
							NEW(disks[i].fs, LEN(dev.table));
							(* copy partition table - the copy will be extended by FindFreeSpace *)
							NEW(disks[i].table, LEN(disks[i].device.table));
							FOR j := 0 TO LEN(disks[i].device.table)-1 DO disks[i].table[j] := disks[i].device.table[j]; END;

							GetGeometry(disks[i], disks[i].geo, disks[i].gres);  (* calls dev.Handle(geo, res) *)
							IF ((res = AosDisks.DeviceInUse) OR (res = AosDisks.Ok)) & (dev.blockSize = BS) & (disks[i].geo.cyls * disks[i].geo.hds * disks[i].geo.spt > DisketteLimit) THEN
								NEW(errorWriter, LEN(errorString));
								(* possibly re-allocate table *)
								IF ~FindFreeSpace(errorWriter, dev, disks[i].table, disks[i].geo.spt, disks[i].geo.hds) THEN
									errorWriter.Get(errorString);
									KernelLog.String("PartitionsLib: "); KernelLog.String(errorString); KernelLog.Ln;
								END;
							END;
						END;
						AssignFileSystems(i);
					END;
					IF disks[i].isDiskette & doClose & (dev.openCount > 0) THEN dev.Close(res); (* ignore res *) END;
				END;
			ELSE
				disks := NIL;
			END;
			Release;
		END UpdateAllDisks;

		PROCEDURE UpdateDisk*(disk : Disk);
		VAR i : LONGINT;
		BEGIN
			IF disks # NIL THEN
				Acquire;
				WHILE (i < LEN(disks)) & (disks[i].device # disk.device) DO INC(i); END;
				IF (i < LEN(disks)) THEN (* disk found *)
					UpdateDiskInternal(i);
				ELSE
					IF Debug THEN KernelLog.String("PartitionsLib.diskModel.UpdateDisk: disk not found"); KernelLog.Ln; END;
				END;
				Release;
				onChanged.Call(NIL);
			ELSE
				IF Debug THEN KernelLog.String("PartitionsLib.diskModel.UpdateDisk: disk not found (2)"); KernelLog.Ln; END;
			END;
		END UpdateDisk;

		PROCEDURE UpdateDiskInternal(i : LONGINT);
		VAR dev : AosDisks.Device; errorWriter : Streams.StringWriter; errorString : ARRAY 1024 OF CHAR; doClose : BOOLEAN; j, res : LONGINT;
		BEGIN
			dev := disks[i].device;
			IF dev # NIL THEN
				(* Hack to support diskettes *)
				IF Strings.Match("Diskette0*", dev.name) THEN
					disks[i].isDiskette := TRUE; doClose := FALSE;
					IF dev.openCount < 1 THEN
						dev.Open(res); (* ignore res *)
						doClose := TRUE;
					END;
				END;

				dev.GetSize(disks[i].size, disks[i].res);
				IF disks[i].res = AosDisks.MediaChanged THEN dev.GetSize(disks[i].size, disks[i].res) END; (* we didn't use Open, so retry *)

				IF disks[i].res # AosDisks.MediaMissing THEN
					AosDisks.UpdatePartitionTable(dev, res);
					IF ((res = AosDisks.Ok) OR (res = AosDisks.DeviceInUse)) & (dev.table # NIL) THEN

						NEW(disks[i].fs, LEN(dev.table));
						(* copy partition table - the copy will be extended by FindFreeSpace *)
						NEW(disks[i].table, LEN(disks[i].device.table));
						FOR j := 0 TO LEN(disks[i].device.table)-1 DO disks[i].table[j] := disks[i].device.table[j];	END;

						GetGeometry(disks[i], disks[i].geo, disks[i].gres);  (* calls dev.Handle(geo, res) *)
						IF ((res = AosDisks.Ok) OR (res = AosDisks.DeviceInUse)) & (dev.blockSize = BS) & (disks[i].geo.cyls * disks[i].geo.hds * disks[i].geo.spt > DisketteLimit) THEN
							(* possibly re-allocate table *)
							NEW(errorWriter, LEN(errorString));
							IF ~FindFreeSpace(errorWriter, dev, disks[i].table, disks[i].geo.spt, disks[i].geo.hds) THEN
								errorWriter.Get(errorString);
								KernelLog.String("PartitionsLib: "); KernelLog.String(errorString); KernelLog.Ln;
							END;
						END;
					END;
				END;
				AssignFileSystems(i);
				IF disks[i].isDiskette & doClose & (dev.openCount > 0) THEN dev.Close(res); (* ignore res *) END;
			END;
		END UpdateDiskInternal;

		(** acquire a read/write lock on the object *)
		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			IF lockedBy = me THEN
				ASSERT(lockLevel # -1);	(* overflow *)
				INC(lockLevel);
			ELSE
				AWAIT(lockedBy = NIL);
				lockedBy := me; lockLevel := 1
			END
		END Acquire;

		(** release the read/write lock on the object *)
		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			DEC(lockLevel);
			IF lockLevel = 0 THEN lockedBy := NIL; END
		END Release;

		PROCEDURE DiskEventHandler(event : LONGINT; plugin : Plugins.Plugin);
		VAR tempTable : Plugins.Table; dev : AosDisks.Device; i, j : LONGINT;
		BEGIN
			ASSERT(plugin#NIL);
			dev := plugin (AosDisks.Device);
			Acquire;
			IF event = Plugins.EventAdd THEN
				IF devTable # NIL THEN
					NEW(tempTable, LEN(devTable)+1);
					FOR i := 0 TO LEN(devTable)-1 DO tempTable[i] := devTable[i]; END;
					tempTable[LEN(devTable)] := dev;
					devTable := tempTable;
				ELSE
					NEW(devTable, 1); devTable[0] := dev;
				END;
			ELSIF event = Plugins.EventRemove THEN
				IF (devTable#NIL) & (LEN(devTable)>1) THEN
					NEW(tempTable, LEN(devTable)-1);
					i := 0; j := 0;
					LOOP
						IF devTable[i]#dev THEN
							tempTable[j] := devTable[i];
							INC(j);
						END;
						INC(i);
						IF i >= LEN(devTable) THEN EXIT; END;
					END;
					devTable := tempTable;
				ELSE
					devTable := NIL;
				END;
			ELSE
				IF Debug THEN KernelLog.String("PartitionsLib.diskModel.DiskEventHandler: Wrong event"); KernelLog.Ln; END;
			END;
			UpdateAllDisks;
			Release;
			onChanged.Call(NIL);
		END DiskEventHandler;

		(* Get geometry from partition table, if possible. *)
		PROCEDURE GetTableGeometry(dev: AosDisks.Device; VAR hds, spt: LONGINT): BOOLEAN;
		VAR buf: ARRAY BS OF CHAR; res, p, hd, sec, i: LONGINT; ok: BOOLEAN;
		BEGIN
			ok := FALSE;
			IF dev.blockSize # BS THEN RETURN FALSE; END;
			dev.Transfer(AosDisks.Read, 0, 1, buf, 0, res);
			IF (res = AosDisks.Ok) & (buf[510] = 055X) & (buf[511] = 0AAX) & (buf[Slot1+4] = 055X) THEN (* EZDrive *)
				dev.Transfer(AosDisks.Read, 1, 1, buf, 0, res)	(* read sector 1 *)
			END;
			IF (res = AosDisks.Ok) & (buf[510] = 055X) & (buf[511] = 0AAX) THEN (* valid partition table *)
				hds := -1;
				FOR i := 0 TO 3 DO (* find end head and sector for each valid primary partition *)
					p := Slot1 + 16*i;
					IF buf[p+4] # 0X THEN (* partition i in use *)
						hd := ORD(buf[p+5]); (* end head *)
						sec := ORD(buf[p+6]) MOD 64; (* end sector *)
						IF hds = -1 THEN
							hds := hd+1; spt := sec; ok := TRUE (* first partition found *)
						ELSIF (hds = hd+1) & (spt = sec) THEN
							(* skip *)
						ELSE
							ok := FALSE	(* inconsistent table *)
						END
					END
				END
			END;
			IF (hds<=0) OR (spt <= 0) OR ~ok THEN hds := 0; spt := 0; ok := FALSE; END;
			RETURN ok
		END GetTableGeometry;

		(* Get drive geometry and adjust it. *)
		PROCEDURE GetGeometry(disk: Disk; VAR geo: AosDisks.GetGeometryMsg; VAR res: LONGINT);
		VAR dev : AosDisks.Device; thds, tspt, dsize: LONGINT; org: AosDisks.GetGeometryMsg;
		BEGIN
			dev := disk.device;
			dev.Handle(geo, res);
			IF res # AosDisks.Ok THEN
				IF Trace * TraceGeometry # {} THEN KernelLog.String("Partitions: GetGeometry result "); KernelLog.Int(res, 1); KernelLog.Ln END;
				IF dev.blockSize = BS THEN (* try getSize instead *)
					dev.GetSize(dsize, res);
					IF res = AosDisks.Ok THEN
						geo.cyls := 1; geo.hds := 1; geo.spt := dsize; (* fake it *)
					END
				END
			END;
			IF (res = AosDisks.Ok) & (dev.blockSize = BS) THEN (* adjust geometry *)
				org := geo; dsize := geo.cyls*geo.hds*geo.spt;
				IF GetTableGeometry(dev, thds, tspt) THEN (* adjust geometry to partition table *)
					geo.cyls := dsize DIV (thds*tspt);
					geo.hds := thds; geo.spt := tspt
				ELSIF (geo.cyls > 1024) OR (geo.hds > 255) OR (geo.spt > 63) THEN
					(* modify the parameters to be inside BIOS limits (for boot loader) *)
					(* BIOS limits: 1024 cylinders (0-1023), 255 heads (0-254), 63 sectors (1-63) (max size 8032M) *)
					geo.hds := 1; geo.spt := 63;
					REPEAT	(* try 2, 4, 8, 16, 32, 64, 128 and 255 heads *)
						geo.hds := geo.hds*2;
						geo.cyls := dsize DIV (geo.hds*geo.spt)
					UNTIL (geo.cyls <= 1023) OR (geo.hds = 256);
					IF geo.hds = 256 THEN geo.hds := 255; geo.cyls := dsize DIV (geo.hds*geo.spt) END
				ELSE
					(* skip - ok *)
				END;
				IF Trace * TraceGeometry # {} THEN
					IF (org.cyls # geo.cyls) OR (org.hds # geo.hds) OR (org.spt # geo.spt) THEN
						KernelLog.String("Partitions: "); KernelLog.String(dev.name); KernelLog.Char(" ");
						KernelLog.Int(org.cyls, 1); KernelLog.Char("*"); KernelLog.Int(org.hds, 1); KernelLog.Char("*"); KernelLog.Int(org.spt, 1); KernelLog.Char("=");
						KernelLog.Int(dsize, 1); KernelLog.String(" -> "); KernelLog.Int(geo.cyls, 1); KernelLog.Char("*"); KernelLog.Int(geo.hds, 1); KernelLog.Char("*");
						KernelLog.Int(geo.spt, 1); KernelLog.Char("="); KernelLog.Int(geo.cyls*geo.hds*geo.spt, 1); KernelLog.Ln;
					END
				END
			END
		END GetGeometry;

		(* Add a free partition entry at the end (to keep partition numbers the same) *)
		PROCEDURE NewFree(type: LONGINT; VAR table: AosDisks.PartitionTable; start, size, ptblock: LONGINT; flags: SET);
		VAR j: LONGINT; p: AosDisks.Partition; new: AosDisks.PartitionTable;
		BEGIN
			p.type := type; p.start := start; p.size := size; p.flags := flags;
			p.ptblock := ptblock; p.ptoffset := 0; (* find free ptoffset later *)
			NEW(new, LEN(table)+1); j := 0;
			WHILE j # LEN(table) DO new[j] := table[j]; INC(j) END;
			new[j] := p; table := new
		END NewFree;

		PROCEDURE FindFreePrimary(VAR table: AosDisks.PartitionTable; spt, hds: LONGINT);
		VAR i, g, t, max, start, end, prevstart, nextstart: LONGINT;
		BEGIN
			start := spt; g := hds * spt; (* skip first track *)
			max := table[0].size - g;	(* reserve one cylinder at end of disk *)
			FOR i := 1 TO LEN(table)-1 DO (* find overlapping partition, if any *)
				IF (AosDisks.Primary IN table[i].flags) & (table[i].start <= start) & (start < table[i].start+table[i].size) THEN
					start := table[i].start	(* start search at this partition instead *)
				END
			END;
			LOOP
				prevstart := start; end := MAX(LONGINT);
				FOR i := 1 TO LEN(table)-1 DO (* find first partition start after or on start *)
					IF (AosDisks.Primary IN table[i].flags) & (table[i].start >= start) & (table[i].start < end) THEN
						end := table[i].start (* free space ends at this start position *)
					END
				END;
				IF end > max THEN end := max END;	(* clip to end of disk *)
					(* {start..end-1 is free} *)
				IF start # spt THEN INC(start, (-start) MOD g) END; (* start on cylinder boundary (except first) *)
				DEC(end, end MOD g); (* end on cylinder boundary *)
					(* {start..end-1 is free and aligned} *)
				IF end-start > 0 THEN NewFree(FreeSpace, table, start, end-start, 0, {AosDisks.Primary}) END;
				nextstart := MAX(LONGINT);
				FOR i := 1 TO LEN(table)-1 DO (* find first partition end after prevstart *)
					IF AosDisks.Primary IN table[i].flags THEN
						t := table[i].start+table[i].size-1;
						IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
					END
				END;
				IF nextstart = MAX(LONGINT) THEN
					EXIT (* no more partitions end after prevstart *)
				ELSE
					start := nextstart+1
				END
			END
		END FindFreePrimary;

		PROCEDURE FindFreeExtended(VAR table: AosDisks.PartitionTable; spt, hds: LONGINT);
		VAR i, g, t, max, start, end, prevstart, nextstart: LONGINT;
		BEGIN
			t := -1; i := 1;
			WHILE i < LEN(table) DO
				IF IsExtendedPartition(table[i].type) THEN
					ASSERT(t = -1); t := i (* at most one extended partition allowed *)
				END;
				INC(i)
			END;
			IF t # -1 THEN
				start := table[t].start; g := hds * spt; max := start + table[t].size;
				LOOP
					prevstart := start; end := MAX(LONGINT);
					FOR i := 1 TO LEN(table)-1 DO (* find first partition start after or on start *)
						IF ~(AosDisks.Primary IN table[i].flags) & (table[i].start >= start) & (table[i].start < end) THEN
							end := table[i].start
						END
					END;
					IF end > max THEN end := max END;
						(* {start..end-1 is free} *)
					IF start MOD g # spt THEN
						INC(start, (-start) MOD g + spt)	(* start on cylinder boundary, second head *)
					END;
					DEC(end, end MOD g); (* end on cylinder boundary *)
						(* {start..end-1 is free and aligned} *)
					IF end-start > 0 THEN NewFree(FreeSpace, table, start, end-start, start-spt, {}) END;
					nextstart := MAX(LONGINT);
					FOR i := 1 TO LEN(table)-1 DO (* find first partition end after prevstart *)
						IF ~(AosDisks.Primary IN table[i].flags) THEN
							t := table[i].start+table[i].size-1;
							IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
						END
					END;
					IF nextstart = MAX(LONGINT) THEN
						EXIT (* no more partitions end after prevstart *)
					ELSE
						start := nextstart+1
					END
				END
			END
		END FindFreeExtended;

		PROCEDURE FindReserved(VAR table: AosDisks.PartitionTable);
		VAR i, t, max, start, end, prevstart, nextstart: LONGINT;
		BEGIN
			 IF ShowReserved THEN
				start := 0; max := table[0].size;
				LOOP
					prevstart := start; end := MAX(LONGINT);
					FOR i := 1 TO LEN(table)-1 DO (* find first partition start after or on start *)
						IF (table[i].start >= start) & (table[i].start < end) THEN
							end := table[i].start	(* free space ends at this start position *)
						END
					END;
					IF end > max THEN end := max END;	(* clip to end of disk *)
						(* {start..end-1 is free} *)
					IF end-start > 0 THEN NewFree(ReservedSpace, table, start, end-start, 0, {AosDisks.Primary}) END;
					nextstart := MAX(LONGINT);
					FOR i := 1 TO LEN(table)-1 DO (* find first partition end after prevstart *)
						t := table[i].start+table[i].size-1;
						IF (t > prevstart) & (t < nextstart) THEN nextstart := t END
					END;
					IF nextstart = MAX(LONGINT) THEN
						EXIT (* no more partitions end after prevstart *)
					ELSE
						start := nextstart+1
					END
				END
			END
		END FindReserved;

		PROCEDURE CheckTable(w : Streams.Writer; dev: AosDisks.Device; table: AosDisks.PartitionTable): BOOLEAN;
		VAR i, j, ext: LONGINT;
		BEGIN
			ASSERT(w # NIL);
			ext := -1;
			(* check all partitions for size, and presence of at most one extended partition *)
			FOR i := 0 TO LEN(table)-1 DO
				IF (table[i].start < 0) OR (table[i].size < 0) OR (table[i].start+table[i].size < 0) THEN
					w.String("Warning: "); WritePart(w, dev, i);
					w.String("too large"); w.Ln;
					RETURN FALSE
				END;
				IF IsExtendedPartition(table[i].type) THEN
					IF ext # -1 THEN
						w.String("Error: "); WritePart(w, dev, ext);
						w.String("and "); WritePart(w, dev, i);
						w.String("are both extended"); w.Ln;
						RETURN FALSE
					END;
					ext := i
				END
			END;
			(* check all primary partitions and logical drives for overlap *)
			FOR i := 1 TO LEN(table)-1 DO
				IF AosDisks.Primary IN table[i].flags THEN (* primary partition *)
					FOR j := 1 TO LEN(table)-1 DO
						IF (i # j) & (AosDisks.Primary IN table[j].flags) & PartitionsOverlap(table, i, j) THEN
							w.String("Error: "); WritePart(w, dev, i);
							w.String("and "); WritePart(w, dev, j);
							w.String("overlap"); w.Ln;
							RETURN FALSE (* primary partitions can not overlap *)
						END
					END
				ELSE (* logical drive in extended partition *)
					FOR j := 1 TO LEN(table)-1 DO
						IF (i # j) & (j # ext) & PartitionsOverlap(table, i, j) THEN
							w.String("Error: "); WritePart(w, dev, i);
							w.String("and "); WritePart(w, dev, j);
							w.String("overlap"); w.Ln;
							RETURN FALSE	(* logical drives can not overlap any other partition, except the extended partition *)
						END
					END
				END
			END;
			RETURN TRUE
		END CheckTable;

		(* Find free space on the disk and insert placeholder partitions (table is reallocated). *)
		PROCEDURE FindFreeSpace(w : Streams.Writer; dev: AosDisks.Device; VAR table: AosDisks.PartitionTable; spt, hds: LONGINT) : BOOLEAN;
		BEGIN
			ASSERT(w # NIL);
			ASSERT((hds > 0) & (spt > 0) & (table[0].start = 0));
			IF CheckTable(w, dev, table) THEN
				FindFreePrimary(table, spt, hds);
				FindFreeExtended(table, spt, hds);
				IF ShowReserved THEN FindReserved(table) END;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END
		END FindFreeSpace;

		(* For each partition of the specified disk, try to find the associated file system (if any) *)
		PROCEDURE AssignFileSystems(disk : LONGINT);
		VAR
			fs : Files.FileSystem;
			ft : Files.FileSystemTable;
			vol : DiskVolumes.Volume;
			volOld : OldDiskVolumes.Volume;
			volFAT : FATVolumes.Volume;
			volISO : ISO9660Volumes.Volume;
			dev : AosDisks.Device;
			found : BOOLEAN;
			partition , fsStart, i : LONGINT;
		BEGIN
			ASSERT(disk < LEN(disks));
			Files.GetList(ft);
			FOR i := 0 TO LEN(ft)-1 DO
				fs := ft[i];
				IF fs.vol # NIL THEN
					dev := NIL;
					IF fs.vol IS DiskVolumes.Volume THEN
						vol := fs.vol (DiskVolumes.Volume); dev := vol.dev; fsStart := vol.startfs;
					ELSIF fs.vol IS OldDiskVolumes.Volume THEN
						volOld := fs.vol (OldDiskVolumes.Volume); dev := volOld.dev; fsStart := volOld.startfs;
					ELSIF fs.vol IS FATVolumes.Volume THEN
						volFAT := fs.vol (FATVolumes.Volume); dev := volFAT.dev; fsStart := volFAT.start;
					ELSIF fs.vol IS ISO9660Volumes.Volume THEN
					      volISO := fs.vol (ISO9660Volumes.Volume); dev := volISO.dev;
					END;
					IF (dev # NIL) & (dev = disks[disk].device) & (disks[disk].device.table # NIL) THEN
						IF Trace * TraceGetFS # {} THEN KernelLog.String("Looking for FS of device: "); KernelLog.String(dev.name); KernelLog.Ln; END;

						IF IsPartitioned(disks[disk].device) THEN

							found := FALSE; partition := 1; (* Partition 0 is WHOLE DISK - ignore for partitioned devices *)
							LOOP
								IF found OR (partition > LEN(disks[disk].device.table) - 1) THEN EXIT END;

								IF ~IsExtendedPartition(disks[disk].device.table[partition].type) THEN (* don't consider extended partitions *)
									IF (disks[disk].device.table[partition].start <= fsStart) &
										(fsStart < disks[disk].device.table[partition].start + disks[disk].device.table[partition].size) THEN
										found := TRUE;
										disks[disk].fs[partition] := fs;
										IF Trace * TraceGetFS # {} THEN
											KernelLog.String(fs.prefix); KernelLog.String(" on "); KernelLog.String(disks[disk].device.name);
											KernelLog.String("#"); KernelLog.Int(partition, 0);
										END;
									END;
								END;
								INC(partition);
							END;

						ELSE (* Device is not partitioned *)
							disks[disk].fs[0] := fs;
						END;

					END;
				END;
			END; (* END FOR *)
		END AssignFileSystems;

		(* Returns TRUE iff partition i contains sector x. *)
		PROCEDURE Contains(table: AosDisks.PartitionTable; i, x: LONGINT): BOOLEAN;
		BEGIN
			RETURN (table[i].start <= x) & (x < table[i].start + table[i].size)
		END Contains;

		(* Returns TRUE iff partition i and j overlap *)
		PROCEDURE PartitionsOverlap(table: AosDisks.PartitionTable; i, j: LONGINT): BOOLEAN;
		BEGIN
			RETURN Contains(table, i, table[j].start) OR Contains(table, i, table[j].start+table[j].size-1)
				OR Contains(table, j, table[i].start) OR Contains(table, j, table[i].start+table[i].size-1)
		END PartitionsOverlap;

		PROCEDURE Finalize;
		VAR ignore : LONGINT;
		BEGIN
			AosDisks.registry.RemoveEventHandler(DiskEventHandler, ignore);
		END Finalize;

	END DisksModel;

TYPE

	String* = ARRAY 256 OF CHAR;

	OperationState* = RECORD
		(** status information *)
		status- : SET;
		statusString- : String;

		(** error information *)
		errorCount- : LONGINT;

		(** progress *)
		progressValid- : BOOLEAN; (* IF progressValid= TRUE the variables min, cur & max contain meaningful values *)
		min-, cur-, max- : HUGEINT;
	END;

TYPE

	(*
	 *	How this works:
	 *
	 *	1. Initialize new object instance
	 *	2. Pass parameters (child object will have parameters as fields)
	 *	3. IF parameters are valid, set alive := TRUE, else, set alive := FALSE
	 *	4. Add object to PartitionsLib.registry via Add
 	 *	5. Call SetStart
	 *	6. As long status * StatusRunning # {} the object is active
	 * 	7. Terminate object via Abort & AwaitDead
	 *)
	Operation* = OBJECT
	VAR
		(* Note: The actual implementation may read the state without lock it. All other cases: only access via Set/Get procedures!  *)
		state- : OperationState;

		resultText, infoText, errorsText : Texts.Text;
		result-, info-, errors : TextUtilities.TextWriter;	(* info, result: write access while operation is running is allowed *)

		(* IF TRUE, the WMPartitions.selection field is invalidated (set to none)
		    Set this flag if the operation changed the length of the partition table; *)
		invalidateSelection* : BOOLEAN;

		(* set at object instantiation *)
		name*, desc* : String;
		uid- : LONGINT;
		disk- : Disk; partition- : LONGINT;
		diskpartString- : String; (* dev#part; Set at &Init *)
		starttime-, endtime- : Dates.DateTime; (* endtime only valid if state.status * StatusFinished # {} *)

		(* internal variables *)
		alive*, dead, start : BOOLEAN; (* synchronization *)
		diskmodel : DisksModel; (* needed for locking *)
		next : Operation;

		trapped : BOOLEAN;
		parent : Operation; (* See procedure SetParent *)

		locktype* : LONGINT; (* WriterLock or ReaderLock *)
		locked : BOOLEAN;

		out- : Streams.Writer;

		temp: Strings.String;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		VAR temp : ARRAY 10 OF CHAR;
		BEGIN
			ASSERT((disk.device # NIL) & (disk.table#NIL) & (partition >= 0) & (partition <LEN(disk.table)));
			SELF.disk := disk; SELF.partition := partition;
			SELF.out := out;
			ASSERT((diskModel#NIL) & (operations#NIL));
			locktype := WriterLock; diskmodel := diskModel;
			state.errorCount := 0;
			alive := TRUE; dead := FALSE; start := FALSE; invalidateSelection := FALSE;
			diskpartString := "";
			Strings.Append(diskpartString, disk.device.name); Strings.Append(diskpartString, "#");
			Strings.IntToStr(partition, temp); Strings.Append(diskpartString, temp);
			starttime := Dates.Now();
			NEW(resultText); NEW(result, resultText);
			NEW(infoText); NEW(info, infoText);
			NEW(errorsText); NEW(errors, errorsText);
			SetStatus(StatusWaiting, "Waiting", 0, 0, 0, FALSE);
		END Init;

		(** synchronized access to the object's state *)

		PROCEDURE GetState*() : OperationState;
		BEGIN {EXCLUSIVE}
			RETURN state;
		END GetState;

		PROCEDURE SetStatus*(status : SET; CONST statusString : String; min, cur, max : HUGEINT; valid : BOOLEAN);
		BEGIN {EXCLUSIVE}
			state.status := status; state.statusString := statusString;
			state.min := min; state.cur := cur; state.max := max; state.progressValid := valid;
		END SetStatus;

		PROCEDURE SetCurrentProgress*(cur :HUGEINT);
		BEGIN {EXCLUSIVE}
			state.cur := cur;
		END SetCurrentProgress;

		PROCEDURE ReportError*(CONST error : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			state.status := state.status + StatusError;
			INC(state.errorCount);
			errors.String("Error "); errors.Int(state.errorCount, 3); errors.String(" : "); errors.String(error); errors.Ln;
		END ReportError;

		PROCEDURE GetResult*() : Strings.String;
		VAR string : Strings.String; length : LONGINT;
		BEGIN
			string := Strings.NewString(""); result.Update;
			resultText.AcquireRead;
			length := resultText.GetLength() + 1;
			IF (state.status * StatusFinished # {}) & (length > 0) THEN
				NEW(string, length);
				TextUtilities.TextToStr(resultText, string^);
			END;
			resultText.ReleaseRead;
			RETURN string;
		END GetResult;

		PROCEDURE GetInfo*() : Strings.String;
		VAR string : Strings.String;
		BEGIN
			string := Strings.NewString(""); info.Update;
			infoText.AcquireRead;
			IF (state.status * StatusFinished # {}) & (infoText.GetLength() > 0) THEN
				NEW(string, infoText.GetLength() + 1);
				TextUtilities.TextToStr(infoText, string^);
			END;
			infoText.ReleaseRead;
			RETURN string;
		END GetInfo;

		PROCEDURE GetErrors*() : Strings.String;
		VAR string : Strings.String;
		BEGIN
			string := Strings.NewString(""); errors.Update;
			errorsText.AcquireRead;
			IF errorsText.GetLength() > 0 THEN
				NEW(string, errorsText.GetLength() + 1);
				TextUtilities.TextToStr(errorsText, string^);
			END;
			errorsText.ReleaseRead;
			RETURN string;
		END GetErrors;

		(* Does the actual disk operation. Should RETURN asap when alive is set to FALSE *)
		(* The needed parameters will be fields of the operation that inhertis from this  object *)
		PROCEDURE DoOperation*;
		BEGIN
			HALT(301); (* abstract *)
		END DoOperation;

		(* Returns TRUE if the parameters are valid *)
		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			HALT(301); RETURN FALSE; (* abstract *)
		END ValidParameters;

		(* the following procedures are FINAL *)

		(* The object shall abort its current operation and call SetDead when it's finished *)
		PROCEDURE Abort*;
		BEGIN {EXCLUSIVE}
			state.status := state.status + StatusAborted;
			state.statusString := "Aborted";
			result.String("Operation aborted");
			alive := FALSE; start := TRUE;
		END Abort;

		PROCEDURE Aborted*() : BOOLEAN;
		VAR o : Operation;
		BEGIN
			o := SELF;
			WHILE (o.alive) & (o.parent # NIL) DO
				o := o.parent;
			END;
			RETURN ~o.alive;
		END Aborted;

		PROCEDURE SetBlockingStart*;
		BEGIN
			BEGIN {EXCLUSIVE} start := TRUE; END;
			(* Release lock to trigger AWAIT(start) *)
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END SetBlockingStart;

		(** 																											*)
		(* To support the containment relation for operation, a parent operation can declare other operations			*)
		(* as its child operations. The parent must be set before the child operation is started and must have a lock type	*)
		(* at least as restrictive as the child has. The child operations then do not try to acquire a partition lock.			*)
		PROCEDURE SetParent*(operation : Operation);
		VAR newName : String;
		BEGIN
			parent := operation;
			COPY(parent.name, newName);
			Strings.Append(newName, ".");
			Strings.Append(newName, name);
			name := newName;
			ASSERT(parent.locktype <= locktype);
		END SetParent;

		PROCEDURE Indent;
		VAR operation : Operation;
		BEGIN
			ASSERT(out # NIL);
			operation := parent;
			WHILE (operation # NIL) DO
				out.Char(9X);
				operation := operation.parent;
			END;
		END Indent;

		(* synchronization procedures *)
		PROCEDURE SetDead; BEGIN {EXCLUSIVE} dead := TRUE; END SetDead;
		PROCEDURE AwaitDead*; BEGIN {EXCLUSIVE} AWAIT(dead); END AwaitDead;
		PROCEDURE SetStart*; BEGIN {EXCLUSIVE} start := TRUE; END SetStart;
		PROCEDURE AwaitStart; BEGIN {EXCLUSIVE} AWAIT(start); END AwaitStart;

		PROCEDURE GetReport*(details : BOOLEAN) : Texts.Text;
		VAR
			text : Texts.Text; w : TextUtilities.TextWriter;
			temp : ARRAY 64 OF CHAR;
		BEGIN {EXCLUSIVE}
			NEW(text); NEW(w, text);
			w.SetFontStyle({WMGraphics.FontBold}); w.String("Operation: "); w.SetFontStyle({});
			w.String("UID "); w.Int(uid, 0); w.String(": ");  w.String(name); w.Ln;
			IF ~details THEN
				w.String(" on "); w.String(diskpartString); w.String(", Status: ");
				IF state.status * StatusFinished = {} THEN
					 w.String(state.statusString);
					IF state.progressValid THEN
						w.String(" (Progress: "); w.Int(ENTIER(100.0 * state.cur / state.max), 1); w.String("%"); w.String(")");
					ELSE
						w.String(" (Running)");
					END;
				ELSE
					w.Update; result.Update;
					resultText.AcquireRead; text.AcquireWrite;
					text.CopyFromText(resultText, 0, resultText.GetLength(), text.GetLength());
					text.ReleaseWrite; resultText.ReleaseRead;
				END;
				IF state.errorCount > 0 THEN w.String(", errors: "); w.Int(state.errorCount, 0); END;
				w.Ln; w.Update;
			ELSE
				w.SetFontStyle({WMGraphics.FontBold}); w.String("Description: "); w.SetFontStyle({}); w.String(desc); w.Ln;
				(* Target information *)
				w.SetFontStyle({WMGraphics.FontBold}); w.String("Target: "); w.SetFontStyle({});
				IF disk.device # NIL THEN
					w.String(diskpartString); w.String(" ("); w.String(disk.device.desc); w.String(")");
				ELSE
					w.String("Unknown");
				END;
				w.Ln;
				(* Time information *)
				w.SetFontStyle({WMGraphics.FontBold}); w.String("Started: "); w.SetFontStyle({});
				Strings.FormatDateTime(DateTimeFormat, starttime, temp); w.String(temp);
				IF state.status * StatusFinished # {} THEN
					w.SetFontStyle({WMGraphics.FontBold}); w.String("    Ended: ");  w.SetFontStyle({});
					Strings.FormatDateTime(DateTimeFormat, endtime, temp); w.String(temp);
				END;
				w.Ln;
				(* Status information *)
				w.SetFontStyle({WMGraphics.FontBold}); w.String("Status: "); w.SetFontStyle({});
				IF state.status * StatusFinished # {} THEN
					w.Update; result.Update;
					resultText.AcquireRead;
					text.AcquireWrite;
					text.CopyFromText(resultText, 0, resultText.GetLength(), text.GetLength());
					text.ReleaseWrite;
					resultText.ReleaseRead;
					w.Ln;
				ELSE
					w.String(state.statusString);
					IF (state.status * StatusFinished = {}) & state.progressValid THEN
						w.String(" (Progress: "); w.Int(ENTIER(100.0 * state.cur / state.max), 1); w.String("%"); w.String(")");
					END;
				END;
				w.Ln;
				(* Append error text *)
				errors.Update;
				w.SetFontStyle({WMGraphics.FontBold}); w.String("Errors: "); w.SetFontStyle({});
				IF state.errorCount > 0 THEN
					w.Int(state.errorCount, 0); w.Ln; w.Update;
					errorsText.AcquireRead; text.AcquireWrite;
					text.CopyFromText(errorsText, 0, errorsText.GetLength(), text.GetLength());
					text.ReleaseWrite; errorsText.ReleaseRead;
				ELSE
					w.String("none"); w.Update;
				END;
				w.Ln; w.Ln;
				(* Append information text *)
				info.Update;
				infoText.AcquireRead;
				IF infoText.GetLength() > 0 THEN
					w.SetFontStyle({WMGraphics.FontBold}); w.String("Information:"); w.SetFontStyle({}); w.Ln; w.Update;
					text.AcquireWrite;
					text.CopyFromText(infoText, 0, infoText.GetLength(), text.GetLength());
					text.ReleaseWrite;
				END;
				infoText.ReleaseRead;
			END;
			RETURN text;
		END GetReport;

		PROCEDURE Show*(out : Streams.Writer; details : BOOLEAN);
		VAR text : Texts.Text; string : Strings.String;
		BEGIN
			text := GetReport(details);
			text.AcquireRead;
			NEW(string, text.GetLength() + 1);
			TextUtilities.TextToStr(text, string^);
			text.ReleaseRead;
			out.String("Partitions: "); out.String(string^);
		END Show;

		(* Returns TRUE if operation trapped *)
		PROCEDURE SafelyDoOperation() : BOOLEAN;
		VAR trap, opened : BOOLEAN; res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			trap := FALSE; opened := FALSE;
			IF (disk.device # NIL) THEN
				disk.device.Open(res);
				IF res = AosDisks.Ok THEN
					opened := TRUE;
					DoOperation;
				ELSE
					GetErrorMsg("Could not open device: ", res, temp); ReportError(temp);
				END;
			ELSE
				ReportError("Could not open device: No device exists");
			END;
		FINALLY
			IF opened & (disk.device # NIL) THEN
				disk.device.Close(res);
				IF res # AosDisks.Ok THEN
					GetErrorMsg("Could not close device: ", res, temp); ReportError(temp);
				END;
			END;
			RETURN trap;
		END SafelyDoOperation;

	BEGIN {ACTIVE}
		locked := FALSE;
		AwaitStart;
		SetStatus(StatusRunning, "Running", 0, 0, 0, FALSE);
		IF (out # NIL) THEN Indent; out.String(desc); out.String(" "); out.String(diskpartString); out.String(" ... "); out.Update; END;
		IF alive THEN
			operations.Add(SELF);
			IF ValidParameters() THEN
				IF (parent # NIL) & (parent.locktype <= locktype) THEN
					trapped := SafelyDoOperation();
				ELSIF (parent = NIL) & (diskmodel.AcquirePartition(disk, partition, locktype)) THEN
					locked := TRUE;
					trapped := SafelyDoOperation();
				ELSE
					ReportError("Partition is locked"); result.String("Partition is locked");
					IF (out # NIL) THEN out.String("partition is locked."); out.Ln; out.Update; END;
				END;
				IF locked THEN diskmodel.ReleasePartition(disk, partition); END;
				IF (locktype = WriterLock) THEN
					diskModel.UpdateDisk(disk);
				END;
			ELSE
				result.String("Wrong Parameters");
				IF (out # NIL) THEN
					out.String("invalid parameters."); out.Ln;
					temp := GetErrors (); Indent; out.String(temp^); out.Ln; out.Update;
				END;
			END;
		ELSE
			(* operation has been aborted before it started *)
		END;

		endtime := Dates.Now();

		IF trapped THEN
			ReportError("Operation trapped");
			SetStatus(state.status, "TRAPPED", state.min, state.cur, state.max, state.progressValid);
			IF (out # NIL) THEN out.String("trapped."); out.Ln; out.Update; END;
		ELSIF state.status * StatusAborted = {} THEN
			SetStatus(state.status + StatusFinished, "Finished", state.min, state.cur, state.max, state.progressValid);
			IF (out # NIL) THEN
				IF (state.errorCount = 0) THEN
					info.Update;
					infoText.AcquireRead;
					IF (infoText.GetLength() > 0) THEN
						temp := GetInfo (); out.Ln; Indent; out.String("   "); out.String(temp^); Indent;
					END;
					infoText.ReleaseRead;
					out.String("done.");
				ELSE
					temp := GetErrors(); out.Ln; Indent; out.String(temp^);
				END;
				out.Ln; out.Update;
			END;
		ELSE
			SetStatus(state.status, "Aborted", state.min, state.cur, state.max, state.progressValid);
			IF (out # NIL) THEN out.String("aborted."); out.Ln; out.Update; END;
		END;
		infobus.ReportCompletion(SELF);
		SetDead;
	END Operation;

TYPE

	AllOperations* = POINTER TO ARRAY OF Operation;

TYPE

	OperationManager* = OBJECT
	VAR
		onChanged- : WMEvents.EventSource; (* notify when operations added/removed *)
		operations : Operation;
		uid : LONGINT;

		(** Add the specified operation *)
		PROCEDURE Add(operation : Operation);
		BEGIN {EXCLUSIVE}
			ASSERT(operation # NIL);
			operation.uid := GetUid();
			IF operations = NIL THEN
				operations := operation;
			ELSE
				operation.next := operations;
				operations := operation;
			END;
			onChanged.Call(NIL);
		END Add;

		(** Remove the specified operation. Returns FALSE if operation not found *)
		PROCEDURE Remove*(operation : Operation) : BOOLEAN;
		VAR temp : Operation; found : BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(operation#NIL);
			found := FALSE;
			IF operations = operation THEN
				found := TRUE;
				IF operation.state.status * StatusFinished = {} THEN (* operation is still running *)
					Terminate(operation);
				END;
				operations := operations.next;
			ELSE
				temp := operations;
				IF temp#NIL THEN
					WHILE (temp.next # operation) & (temp.next # NIL) DO temp := temp.next; END;
					IF temp.next = operation THEN (* found *)
						found := TRUE;
						IF operation.state.status * StatusFinished = {} THEN (* operation is still running *)
							Terminate(operation);
						END;
						temp.next := temp.next.next;
					END;
				END;
			END;
			IF found THEN onChanged.Call(GetAllInternal()); END;
			RETURN found;
		END Remove;

		(** Get a operation object by its UID. Returns NIL if not found *)
		PROCEDURE GetByUid*(uid : LONGINT) : Operation;
		VAR temp : Operation;
		BEGIN {EXCLUSIVE}
			temp := operations;
			WHILE (temp # NIL) & (temp.uid # uid) DO temp := temp.next; END;
			RETURN temp;
		END GetByUid;

		PROCEDURE GetAll*() : AllOperations;
		BEGIN {EXCLUSIVE}
			RETURN GetAllInternal();
		END GetAll;

		PROCEDURE GetAllInternal*() : AllOperations;
		VAR  temp : Operation; result : AllOperations; i, num : LONGINT;
		BEGIN (* caller holds lock on operation manager *)
			temp := operations;
			IF temp # NIL THEN
				num := 0;
				WHILE (temp#NIL) DO temp := temp.next; INC(num); END;
				NEW(result, num);
				temp := operations; i := 0;
				WHILE (temp#NIL) DO result[i] := temp; temp := temp.next; INC(i); END;
			END;
			RETURN result;
		END GetAllInternal;

		(** Remove the specified operation. Returns FALSE if the operation has not been found *)
		PROCEDURE RemoveByUid*(uid : LONGINT) : BOOLEAN;
		VAR temp : Operation; found : BOOLEAN;
		BEGIN {EXCLUSIVE}
			temp := operations; found := FALSE;
			IF temp # NIL THEN
				IF temp.uid = uid THEN
					found := TRUE;
					IF temp.state.status * StatusFinished = {} THEN (* operation is still running *)
						Terminate(temp);
					END;
					operations := operations.next;
				ELSE
					WHILE (temp.next # NIL) & (temp.next.uid # uid) DO temp := temp.next; END;
					IF temp.next # NIL THEN
						found := TRUE;
						IF temp.next.state.status * StatusFinished = {} THEN (* operation is still running *)
							Terminate(temp.next);
						END;
						temp.next := temp.next.next;
					END;
				END;
			END;
			IF found THEN onChanged.Call(GetAllInternal()); END;
			RETURN found;
		END RemoveByUid;

		(** Remove all (finished) operations. Returns the number of removed operations *)
		PROCEDURE RemoveAll*(finishedOnly : BOOLEAN) : LONGINT;
		VAR temp : Operation; counter : LONGINT;
		BEGIN {EXCLUSIVE}
			temp := operations; counter := 0;
			IF finishedOnly THEN
				IF temp # NIL THEN
					WHILE (temp # NIL) & (temp.next # NIL) DO
						IF temp.next.state.status * StatusFinished # {} THEN
							temp.next := temp.next.next;
							INC(counter);
						ELSE
							temp := temp.next;
						END;
					END;
					(* now look at the head of the list *)
					IF operations.state.status * StatusFinished # {} THEN
						operations := operations.next;
						INC(counter);
					END;
				END;
			ELSE
				WHILE (temp # NIL) DO (* terminate operations which are still in progress *)
					IF temp.state.status * StatusFinished = {} THEN
						Terminate(temp);
					END;
					INC(counter);
					temp := temp.next;
				END;
				operations := NIL;
			END;
			IF counter > 0 THEN onChanged.Call(GetAllInternal()); END;
			RETURN counter;
		END RemoveAll;

		PROCEDURE Terminate(operation : Operation);
		BEGIN (* caller must hold lock on operation manager*)
			ASSERT(operation # NIL);
			KernelLog.String("Terminating plugin "); KernelLog.String(operation.desc); KernelLog.String(" on ");
			KernelLog.String(operation.name); KernelLog.String("...");
			operation.Abort;
			operation.AwaitDead;
			KernelLog.String("done."); KernelLog.Ln;
		END Terminate;

		PROCEDURE Show*(out : Streams.Writer; details : BOOLEAN);
		VAR operation : Operation;
		BEGIN {EXCLUSIVE}
			ASSERT(out # NIL);
			out.String("Partitions: Currently pending disk operations: "); out.Ln;
			IF operations = NIL THEN
				out.String("None"); out.Ln;
			ELSE
				operation:= operations;
				WHILE (operation # NIL) DO
					operation.Show(out, details);
					operation := operation.next;
				END;
			END;
		END Show;

		PROCEDURE GetUid() : LONGINT;
		BEGIN (* caller must hold lock on operation manager *)
			INC(uid); ASSERT(uid >= 0); (* LONGINT overflow *)
			RETURN uid;
		END GetUid;

		PROCEDURE Finalize;
		VAR ignore : LONGINT;
		BEGIN
			ignore := RemoveAll(FALSE);
		END Finalize;

		PROCEDURE &Init*;
		BEGIN
			uid := -1;
			NEW(onChanged, SELF,Strings.NewString("OperationsChanged"), NIL, NIL);
		END Init;

	END OperationManager;

TYPE

	ListenerProcedure = PROCEDURE {DELEGATE} (operation : Operation; CONST message : ARRAY OF CHAR);

	Listener = POINTER TO RECORD
		proc : ListenerProcedure;
		next : Listener;
	END;

	CompletionNotification* = OBJECT
	VAR
		listeners : Listener;

		PROCEDURE &Init;
		BEGIN
			listeners := NIL;
		END Init;

		PROCEDURE AddListener*(proc : ListenerProcedure);
		VAR l : Listener;
		BEGIN {EXCLUSIVE}
			ASSERT(proc # NIL);
			NEW(l); l.proc := proc;
			l.next := listeners;
			listeners := l;
		END AddListener;

		PROCEDURE RemoveListener*(proc : ListenerProcedure);
		VAR temp : Listener;
		BEGIN {EXCLUSIVE}
			ASSERT((listeners # NIL) & (proc # NIL));
			IF (listeners.proc = proc) THEN
				listeners := listeners.next;
			ELSE
				temp := listeners;
				WHILE (temp.next # NIL) & (temp.next.proc # proc) DO temp := temp.next; END;
				ASSERT(temp # NIL);
				temp.next := temp.next.next;
			END;
		END RemoveListener;

		PROCEDURE NotifyListeners(operation : Operation; CONST message : ARRAY OF CHAR);
		VAR l : Listener;
		BEGIN {EXCLUSIVE}
			ASSERT(operation # NIL);
			l := listeners;
			WHILE (l # NIL) DO
				l.proc(operation, message);
				l := l.next;
			END;
		END NotifyListeners;

		PROCEDURE ReportCompletion*(operation : Operation);
		VAR string : Strings.String; message : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(operation # NIL);
			string := operation.GetResult();
			IF (string # NIL) THEN
				COPY(string^, message);
			ELSE
				message := "";
			END;
			NotifyListeners(operation, message);
		END ReportCompletion;

	END CompletionNotification;

CONST
	BlocksPerTransfer = 128;

TYPE

	(* Base class of PartitionToFile & FileToPartition operations *)
	Image* = OBJECT(Operation);
	VAR
		block, numblocks, blocksize : LONGINT;
		filename : Files.FileName;
		buffer : POINTER TO ARRAY OF CHAR;

		(* Parameters: dev#part name [block numblocks] *)
		PROCEDURE SetParameters*(CONST name : ARRAY OF CHAR; block, numblocks: LONGINT);
		BEGIN
			filename := ""; Strings.Append(filename, name); SELF.block := block; SELF.numblocks := numblocks;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			IF (block = -1) & (numblocks = -1) THEN (* optional parameters block & numblocks not set; whole partition *)
				block := 0;
				disk.device.GetSize(numblocks, res);
				IF res # AosDisks.Ok THEN
					GetErrorMsg("GetSize failed: ", res, temp); ReportError(temp); RETURN FALSE;
				END;
			END;
			IF block < 0 THEN ReportError("<Block> parameter must be >= 0"); RETURN FALSE; END;
			IF numblocks < 1 THEN ReportError("<Numblocks> parameter must be > 0"); RETURN FALSE; END;
			blocksize := disk.device.blockSize;
			IF blocksize > 0 THEN
				info.String("Blocksize: "); info.Int(blocksize, 0); info.String(" Bytes"); info.Ln;
			ELSE
				ReportError("Could not get blocksize of device"); RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

	END Image;

TYPE

	PartitionToFile* = OBJECT(Image);

		PROCEDURE DoOperation*;
		VAR f : Files.File; w: Files.Writer; error : String; pos, i, num, res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			f := Files.New(filename);
			IF f # NIL THEN
				IF block + numblocks > disk.table[partition].size THEN
					numblocks := disk.table[partition].size - block;
					info.String("Warning: Partition too small. Using lower numblocks: "); info.Int(numblocks, 0); info.Ln;
				END;
				SetStatus(state.status, "Copying...", 0, 0, numblocks, TRUE);
				NEW(w, f, 0); NEW(buffer, BlocksPerTransfer * blocksize);
				pos := disk.table[partition].start + block;
				num := BlocksPerTransfer; i := 0;
				LOOP
					IF num >= numblocks - i THEN num := numblocks - i END;
					IF (num = 0) OR ~alive THEN EXIT END;
					disk.device.Transfer(AosDisks.Read, pos, num, buffer^, 0, res);
					IF res # AosDisks.Ok THEN
						GetTransferError(disk.device, AosDisks.Read, pos, res, temp); ReportError(temp); EXIT;
					END;
				  	w.Bytes(buffer^, 0, num*blocksize); ASSERT(w.res = 0); w.Update;
					INC(pos, num); INC(i, num);
					SetCurrentProgress(state.cur + num);
				END;
				IF alive THEN
					Files.Register(f);
					result.Int(i, 0); result.String(" blocks written to "); result.String(filename);
				END;
			ELSE
				error := "Could not create file: "; Strings.Append(error, filename); ReportError(error);
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "PartitionToFile"; desc := "Write a partition to a file"; locktype := ReaderLock;
		END Init;

	END PartitionToFile;

TYPE

	FileToPartition* = OBJECT(Image);

		PROCEDURE DoOperation*; (** dev#part filename [block numblocks] ~ *)
		VAR f: Files.File; r: Files.Reader; error : String; len, res, pos, num, i : LONGINT;
		BEGIN
			f := Files.Old(filename);
			IF f # NIL THEN
				num := (f.Length() + blocksize - 1) DIV blocksize;
				IF numblocks > num THEN
					numblocks := num;
					info.String("Warning: Specified number of blocks is bigger than image file size. Set numblocks to "); info.Int(numblocks, 0); info.Ln;
				 END;
				IF block + numblocks > disk.table[partition].size THEN
					numblocks := disk.table[partition].size - block;
					info.String("Warning: Partition too small. Writing only "); info.Int(numblocks, 0); info.String(" to partition"); info.Ln;
				END;
				SetStatus(state.status, "Copying", 0, 0, numblocks, TRUE);
				NEW(r, f, 0); NEW(buffer, BlocksPerTransfer * blocksize);
				pos := disk.table[partition].start + block;
				i := 0; num := BlocksPerTransfer;
				LOOP
					IF num >= numblocks - i THEN num := numblocks - i; END;
					IF (num = 0) OR ~alive THEN EXIT; END;
					r.Bytes(buffer^, 0, num*blocksize, len);
					WHILE len MOD blocksize # 0 DO buffer^[len] := 0X; INC(len) END;
					ASSERT((disk.table[partition].start <= pos) & (pos + num <= disk.table[partition].start + disk.table[partition].size ));
					disk.device.Transfer(AosDisks.Write, pos, num, buffer^, 0, res);
					IF res # AosDisks.Ok THEN
						GetTransferError(disk.device, AosDisks.Write, pos, res, error); ReportError(error); EXIT
					END;
					INC(pos, num); INC(i, num);
					SetCurrentProgress(state.cur + num);
				END;
				IF alive THEN result.Int(numblocks, 0); result.String(" blocks written to "); result.String(diskpartString); END;
			ELSE
				error := ""; Strings.Append(error, filename); Strings.Append(error, " not found"); ReportError(error);
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "FileToPartition"; desc := "Write file to partition"; locktype := WriterLock;
		END Init;

	END FileToPartition;

TYPE

	Mount* = OBJECT(Operation)
	VAR
		prefix : Files.Prefix;
		alias : ARRAY 64 OF CHAR;
		volumePars, fsPars : ARRAY 64 OF CHAR;

		PROCEDURE SetParameters*(CONST prefix, alias, volumePars, fsPars : ARRAY OF CHAR);
		BEGIN
			COPY(prefix, SELF.prefix);
			COPY(alias, SELF.alias);
			COPY(volumePars, SELF.volumePars);
			COPY(fsPars, SELF.fsPars);
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF (prefix = "") THEN ReportError("No prefix specified"); RETURN FALSE;
			ELSIF (alias = "") THEN ReportError("No alias specified"); RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE DoOperation*; (** prefix alias [volpar] ["|" fspar] ~ *)
		VAR
			errorString, par : ARRAY 512 OF CHAR;
			context : Commands.Context;
			arg : Streams.StringReader; errors : Streams.StringWriter;
			msg: ARRAY 64 OF CHAR;
			res : LONGINT;
		BEGIN
			par := "";
			Strings.Append(par, prefix); Strings.Append(par, " ");
			Strings.Append(par, alias); Strings.Append(par, " ");
			Strings.Append(par, diskpartString); Strings.Append(par, " ");
			Strings.Append(par, volumePars); Strings.Append(par, " ");
			Strings.Append(par, fsPars);

			errorString := "";
			NEW(errors, 512);

			NEW(arg, 512); arg.SetRaw(par, 0, 512);
			NEW(context, NIL, arg, NIL, errors, SELF);

			Commands.Activate("FSTools.Mount", context, {Commands.Wait}, res, msg);

			errors.Get(errorString);
			IF (errorString # "") THEN
				ReportError(errorString);
			ELSE
				result.String(prefix); result.String(" mounted");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "Mount"; desc := "Mount partition"; locktype := WriterLock;
		END Init;

	END Mount;

TYPE

	CheckPartition* = OBJECT(Operation);
	VAR
		timer : Kernel.MilliTimer;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			RETURN TRUE; (* operation has no parameters *)
		END ValidParameters;

		(* parameters : dev#part *)
		PROCEDURE DoOperation*;
		CONST Size = 16*512; Max = 50;
		VAR
			maxblocks : LONGINT;
			buf : ARRAY Size OF CHAR;
			start, size : LONGINT;
			seed, res, len, i, ticks: LONGINT;
			temp: ARRAY 256 OF CHAR;
		BEGIN
			start := disk.table[partition].start; size := disk.table[partition].size;
			SetStatus(state.status, "Random check", 0, 0, Max+size, TRUE);

			maxblocks := Size DIV disk.device.blockSize; ASSERT(maxblocks > 0);
			seed := 8872365; res := AosDisks.Ok;
			LOOP
				i := Random(seed, size);
				disk.device.Transfer(AosDisks.Read, start + i, 1, buf, 0, res);
				IF res # AosDisks.Ok THEN GetTransferError(disk.device, AosDisks.Read, start + i, res, temp); ReportError (temp) END;
				SetCurrentProgress(state.cur + 1);
				IF (state.cur >= Max) OR (res # AosDisks.Ok) OR ~alive THEN EXIT END;
			END;

			IF alive & (res = AosDisks.Ok) THEN
				SetStatus(state.status, "Seq Read check", state.min, state.cur, state.max, TRUE);
				Kernel.SetTimer(timer, MAX(LONGINT)); (* performance monitoring *)
				i := 0;
				LOOP
					len := maxblocks;
					IF len > size-i THEN len := size-i END;
					disk.device.Transfer(AosDisks.Read, start + i, len, buf, 0, res);
					IF res # AosDisks.Ok THEN GetTransferError(disk.device, AosDisks.Read, start + i, res, temp); ReportError(temp); END;
					SetCurrentProgress(state.cur+len);
					INC(i, len);
					IF (i >= size) OR (res # AosDisks.Ok) OR ~alive THEN EXIT END;
				END;
			END;

			IF res = AosDisks.Ok THEN
				ticks := Kernel.Elapsed(timer);
				IF (ticks # 0) & (i # 0) THEN
					WriteK(info, i DIV 2); info.String(" KB read in "); info.Int(ticks DIV 1000, 1); info.String("s (");
					info.Int(((i DIV 2) DIV ticks) * 1000, 1); info.String(" KB/s)");
				END;
				result.String("Partition "); result.String(diskpartString); result.String(" has no errors");
			ELSE
				result.String("Encountered "); result.Int(state.errorCount, 1); result.String("errors");
			END;
		END DoOperation;

		(* Pseudo-random number. *)
		PROCEDURE Random (VAR seed: LONGINT; N :LONGINT): LONGINT;
		BEGIN
			(* this is not a good one, but ok for this purpose *)
			seed := (seed + 773) * 13 MOD 9999991;
			RETURN seed MOD N
		END Random;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "CheckPartition"; desc := "Sequentially read all blocks on partition"; locktype := ReaderLock;
		END Init;

	END CheckPartition;

TYPE

	(* Format a partition with an N2KFS or AosFS. *)
	FormatPartition* = OBJECT(Operation);
	VAR
		(* parameters: *)
		fsRes : LONGINT;
		fsName, bootName : ARRAY 256 OF CHAR;
		flag : LONGINT;

		dev : AosDisks.Device; (* set to disk.device in &Init *)

		(* fsname :  ["AosFS" | "NatFS" | "NatFS2"]  *)
		(* bootname : Name of the bootloader;  if bootname="" -> Use Bootname constant *)
		(* fsRes : file system reserved space; fsRes = -1 -> Bootfile size;  fsRes = -2 -> Use FSRes constant *)
		(* fl : flag *)
		PROCEDURE SetParameters*(CONST fsname, bootname : ARRAY OF CHAR;  fsRes : LONGINT; fl : LONGINT );
		BEGIN
			fsName := ""; Strings.Append(fsName, fsname); SELF.fsRes := fsRes;
			IF fl = 0 THEN flag := 1FH; (* default *) ELSE flag := fl; END;
			COPY(bootname, bootName);
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF disk.device.blockSize # BS THEN ReportError("Blocksize not supported"); RETURN FALSE; END;

			IF (partition # 0) & ~(AosDisks.Valid IN disk.table[partition].flags) THEN ReportError("Partition not valid"); RETURN FALSE; END;
			IF ~(((partition = 0) & (LEN(disk.table) = 1)) OR IsNativeType(disk.table[partition].type)) THEN
				ReportError("Cannot format selected partition"); RETURN FALSE;
			END;
			IF AosDisks.Mounted IN disk.table[partition].flags THEN ReportError("Cannot format mounted partition"); RETURN FALSE; END;
			IF fsRes < -2 THEN ReportError("Wrong fsRes value"); RETURN FALSE; END;
			IF (fsName # "NatFS") & (fsName # "NatFS2") & (fsName # "AosFS") THEN
				ReportError("Specified file system unknown (use AosFS, NatFS or NatFS2)"); RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

		(** dev#part [ "AosFS" | "NatFS" | "NatFS2" [ FSRes [ BootFile [ Flag ] ] ] ] ~ *)
		PROCEDURE DoOperation*;
		VAR
			f : Files.File;
			error : String;
			fs, type, size, res : LONGINT;
		BEGIN
			IF (fsName = "NatFS") OR (fsName = "NatFS1") THEN type := NativeType1
			ELSIF fsName = "NatFS2" THEN type := NativeType2
			ELSE type := AosType
			END;
			safe := FALSE;
			fs := DetectFS(disk.device, partition);
			IF ~safe OR (fs = UnknownFS) THEN
				disk.device.GetSize(size, res);
				IF res = AosDisks.Ok THEN
					f := Files.Old(bootName);
					IF (f # NIL) OR (fsRes # -1) THEN
						IF fsRes = -1 THEN fsRes := (f.Length()+BS-1) DIV BS;
						ELSIF fsRes = -2 THEN fsRes := FSRes;
						ELSE fsRes := fsRes * 1024 DIV BS;
						END;
						info.String("Reserving "); WriteK(info, fsRes*BS DIV 1024); info.String(" for boot file"); info.Ln;
						CASE type OF
							AosType: InitAosFS(fsRes, flag, res)
							|NativeType1, NativeType2: InitNativeFS(fsRes, flag, res)
						END;
						IF res = AosDisks.Ok THEN
							IF f # NIL THEN
								InitBootFile(disk.device, partition, f, res);
								IF res = AosDisks.Ok THEN
									info.String("Bootfile "); info.String(bootName); info.String(" written to disk"); info.Ln;
									result.String(diskpartString); result.String(" has been successfully formatted.");
								ELSE
									GetErrorMsg("InitBootfile",res, error); ReportError(error);
									result.String(diskpartString); result.String(" has been formatted but boot initialization failed");
								END
							ELSE
								IF bootName # "" THEN
									error := "Bootfile "; Strings.Append(error, bootName); Strings.Append(error, " missing - partition not bootable");
									ReportError(error);
								END;
								result.String(diskpartString); result.String(" has been formatted but bootfile not found");
							END
						ELSE (* skip - error message already written *)
						END
					ELSE error := ""; Strings.Append(error, name); Strings.Append(error, "missing"); ReportError(error);
					END
				ELSE ReportError("Disk has errors");
				END
			ELSE ReportError("To reformat this partition, execute Partitions.Unsafe and try again");
			END;
		END DoOperation;

		(* Initialize the Aos file system in a partition. See AosFiles.Volume.Init *)
		PROCEDURE InitAosFS(fsres, flag: LONGINT; VAR res: LONGINT);
		VAR fssize, i, j, ofs, size, x, fsofs: LONGINT; b: ARRAY BS OF CHAR; temp: ARRAY 256 OF CHAR;
		BEGIN
			ofs := dev.table[partition].start; size := dev.table[partition].size;
			ASSERT(dev.blockSize = BS);
			fsofs := fsres + BootLoaderSize + 4;
			ASSERT((fsofs >= BootLoaderSize+4) & (fsofs <= size));
			fssize := (size-fsofs) DIV AosBPS;
			ASSERT(fssize > MinPartSize);
			InitOBL(flag, res);
			IF res = AosDisks.Ok THEN
				dev.Transfer(AosDisks.Read, ofs, 1, b, 0, res);
				IF res = AosDisks.Ok THEN (* init AosFS table *)
					ASSERT((b[1FEH] = 55X) & (b[1FFH] = 0AAX));
					Put4(b, 1F0H, fsofs); Put4(b, 1F4H, fssize); Put4(b, 1F8H, FSID);
					b[1FCH] := CHR(FSVer); b[1FDH] := CHR(AosSSLog2);
					dev.Transfer(AosDisks.Write, ofs, 1, b, 0, res);
					IF res = AosDisks.Ok THEN
						i := 0;
						WHILE (i # AosBPS) & (res = AosDisks.Ok) DO
							FOR j := 0 TO BS-1 DO b[j] := 0X END;
							IF i = 0 THEN
								b[0] := CHR(AosDirMark MOD 100H);
								b[1] := CHR(AosDirMark DIV 100H MOD 100H);
								b[2] := CHR(AosDirMark DIV 10000H MOD 100H);
								b[3] := CHR(AosDirMark DIV 1000000H MOD 100H)
							END;
							x := ofs + fsofs + i; dev.Transfer(AosDisks.Write, x, 1, b, 0, res);
							IF res # AosDisks.Ok THEN GetTransferError(dev, AosDisks.Write, x, res, temp); ReportError(temp) END;
							INC(i)
						END;
						IF res = AosDisks.Ok THEN (* invalidate map *)
							FOR j := 0 TO BS-1 DO b[j] := 0X END;
							x := ofs + fsofs + (fssize-1)*AosBPS; dev.Transfer(AosDisks.Write, x, 1, b, 0, res);
							IF res # AosDisks.Ok THEN GetTransferError(dev, AosDisks.Write, x, res, temp); ReportError(temp); END
						END
					ELSE GetTransferError(dev, AosDisks.Write, ofs, res, temp); ReportError(temp);
					END
				ELSE GetTransferError(dev, AosDisks.Read, ofs, res, temp); ReportError(temp);
				END
			ELSE GetErrorMsg("InitOBL failed: ", res, temp); ReportError(temp);
			END;
		END InitAosFS;

		(* Initialize the Native file system in a partition. *)
		PROCEDURE InitNativeFS(fsres, flag: LONGINT; VAR res: LONGINT);
		VAR ofs, size, fssize, fsofs, startfs, i: LONGINT; b: ARRAY N2KSS*2 OF CHAR; temp: ARRAY 256 OF CHAR;
		BEGIN
			ofs := dev.table[partition].start; size := dev.table[partition].size;
			ASSERT(dev.blockSize = BS);
			fsofs := fsres + BootLoaderSize+4;
			ASSERT((fsofs >= BootLoaderSize+4) & (fsofs <= size));
			fssize := (size-fsofs) DIV N2KBPS;
			ASSERT(fssize > MinPartSize);
			InitOBL(flag, res);
			IF res # AosDisks.Ok THEN
				GetErrorMsg("InitLoader: ", res, temp); ReportError(temp);
			ELSE
				dev.Transfer(AosDisks.Read, dev.table[partition].start, 1, b, 0, res);
				IF res # AosDisks.Ok THEN
					GetTransferError(dev, AosDisks.Read, dev.table[partition].start, res, temp); ReportError(temp);
				ELSE
					ASSERT((b[1FEH] = 55X) & (b[1FFH] = 0AAX));
					Put2(b, 0EH, fsofs);	(* reserved *)
					dev.Transfer(AosDisks.Write, dev.table[partition].start, 1, b, 0, res);	(* update reserved *)
					IF res # AosDisks.Ok THEN
						GetTransferError(dev, AosDisks.Read, dev.table[partition].start, res, temp); ReportError(temp);
					ELSE
						FOR i := 0 TO N2KSS*2-1 DO b[i] := 0X END;
						Put4(b, 0, N2KDirMark);
						startfs := dev.table[partition].start + fsofs;
						dev.Transfer(AosDisks.Write, startfs, N2KBPS*2, b, 0, res);
						IF res = AosDisks.Ok THEN
							Put4(b, 0, 0); (* invalidate map mark *)
							dev.Transfer(AosDisks.Write, startfs + (fssize-1)*N2KBPS, N2KBPS, b, 0, res);
							IF res # AosDisks.Ok THEN GetTransferError(dev, AosDisks.Write, startfs + (fssize-1)*N2KBPS, res, temp); ReportError(temp); END;
						ELSE
							GetTransferError(dev, AosDisks.Write, startfs, res, temp); ReportError(temp);
						END
					END
				END
			END;
		END InitNativeFS;

		(* Write the OBL boot loader and an empty config table to disk. *)
		PROCEDURE InitOBL(flag: LONGINT; VAR res: LONGINT);
		VAR
			buf: ARRAY 10*BS OF CHAR; i, tsize, rsize, lsize, len : LONGINT;
			f: Files.File; r: Files.Reader;
		BEGIN
			ASSERT(dev.blockSize = BS);
			IF disk.gres = AosDisks.Ok THEN
				f := Files.Old(BootLoaderName);  NEW(r, f, 0);
				ASSERT((f # NIL) & (f.Length() <= BootLoaderSize*BS));	(* assume boot file is present and small enough *)
				len := f.Length();
				r.Bytes(buf, 0, BootLoaderSize*BS, len);
				ASSERT(r.res = 0);
				ASSERT(Get4(buf, 1F8H) = FSIDOBL); (* new OBL.Bin *)
				(* get parameters from boot loader *)
				rsize := Get2(buf, 0EH); tsize := ORD(buf[10H]);
				ASSERT((rsize-tsize)*BS = f.Length()); (* check boot loader size *)
				lsize := f.Length() DIV BS;
				ASSERT(lsize = BootLoaderSize);
				(* set parameters in boot loader *)
				IF (disk.size > DisketteLimit) THEN (* Windows 2000 workaround *)
					Put2(buf, 0BH, 0);	(* bytes per sector *)
					buf[0DH] := 0X;		(* sectors per cluster *)
					Put2(buf, 11H, 0);	(* root directory size *)
					buf[15H] := 0X;		(* media type *)
					Put2(buf, 16H, 0)	(* sectors per FAT *)
				END;
				IF dev.table[partition].size < 10000H THEN
					Put2(buf, 13H, dev.table[partition].size)
				ELSE
					Put2(buf, 13H, 0)
				END;
				Put4(buf, 20H, dev.table[partition].size);
				Put2(buf, 18H, disk.geo.spt);
				Put2(buf, 1AH, disk.geo.hds);
				Put4(buf, 1CH, dev.table[partition].start); (* boot sector *)
				buf[24H] := GetDriveNum(dev); (* drive *)
				buf[0AH] := CHR(flag);	(* flag *)
				(* now write the boot loader to disk *)
				dev.Transfer(AosDisks.Write, dev.table[partition].start, lsize, buf, 0, res);
				IF res = AosDisks.Ok THEN (* write an empty table *)
					info.String("Boot loader "); info.String(BootLoaderName); info.String(" written"); info.Ln;
					FOR i := 0 TO BS-1 DO buf[i] := 0FFX END;
					i := 0;
					WHILE (i < tsize) & (res = AosDisks.Ok) DO
						dev.Transfer(AosDisks.Write, dev.table[partition].start + lsize + i, 1, buf, 0, res);
						INC(i)
					END
				END
			END
		END InitOBL;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "Format"; desc := "Format partition"; dev := disk.device; locktype := WriterLock;
		END Init;

	END FormatPartition;

TYPE

	ShowBlockCallback* = PROCEDURE {DELEGATE} (text : Texts.Text);

TYPE

	ShowBlocks* = OBJECT(Operation);
	VAR
		(* parameters : dev#part block [numblocks] *)
		block, numblocks : LONGINT;
		callback : ShowBlockCallback;

		(* Parameters: dev#part block [numblocks] *)
		PROCEDURE SetParameters*(block, numblocks: LONGINT);
		BEGIN
			SELF.block := block; SELF.numblocks := numblocks;
		END SetParameters;

		PROCEDURE SetCallback*(callback : ShowBlockCallback);
		BEGIN
			SELF.callback := callback;
		END SetCallback;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF block < 0 THEN
				ReportError("Wrong parameter: block must be >= 0"); RETURN FALSE;
			END;
			IF numblocks < 0 THEN
				ReportError("Wrong parameter: numblocks must be >= 1"); RETURN FALSE;
			END;
			IF (block + numblocks -1 > disk.table[partition].start + disk.table[partition].size) THEN
				ReportError("Block not contained in this partition"); RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE DoOperation*; (** dev#part block [numblocks] ~ *)
		VAR
			text : Texts.Text; tw : TextUtilities.TextWriter;
			pos, num, res : LONGINT;
			buf: POINTER TO ARRAY OF CHAR;
			temp: ARRAY 256 OF CHAR;
		BEGIN
			pos := disk.table[partition].start + block; num := numblocks;
			NEW(text); NEW(tw, text); tw.SetFontName("Courier");
			NEW(buf, disk.device.blockSize);
			LOOP
				IF num <= 0 THEN EXIT END;
				ASSERT((disk.table[partition].start <= pos) & (pos <= disk.table[partition].start + disk.table[partition].size - 1));
				disk.device.Transfer(AosDisks.Read, pos, 1, buf^, 0, res);
				IF res # AosDisks.Ok THEN GetTransferError(disk.device,AosDisks.Read, pos, res, temp); ReportError(temp); EXIT END;
				tw.SetFontStyle({WMGraphics.FontBold});
				tw.String(diskpartString); tw.Char(" "); tw.Int(pos, 1); tw.Ln;
				tw.SetFontStyle({});
				WriteHexDump(tw, buf^, 0, disk.device.blockSize, 0);
				INC(pos); DEC(num);
				IF ~alive THEN tw.String(" interrupted."); tw.Ln; EXIT; END;
			END;
			tw.Update;
			IF callback#NIL THEN callback(text); END;
			IF alive THEN result.String("succeeded"); END;
		END DoOperation;

		PROCEDURE WriteHexDump(w: Streams.Writer; CONST buf: ARRAY OF CHAR; ofs, size, base: LONGINT);
		VAR i: LONGINT; ch: CHAR;
		BEGIN
			WHILE ofs < size DO
				w.Hex(base + ofs, -8); w.String(": ");
				FOR i := 0 TO 15 DO
					IF ofs+i < size THEN w.Hex(ORD(buf[ofs+i]), -2); w.Char(" ");
					ELSE w.String("  ")
					END;
				END;
				w.Char(" ");
				FOR i := 0 TO 15 DO
					IF ofs+i < size THEN
						ch := buf[ofs+i];
						IF (ch < " ") OR (ch > 7EX) THEN ch := "." END
					ELSE
						ch := " "
					END;
					w.Char(ch);
				END;
				w.Ln;
				INC(ofs, 16)
			END
		END WriteHexDump;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "ShowBlocks"; desc := "Show block(s) of partition"; locktype := ReaderLock;
		END Init;

	END ShowBlocks;

TYPE

	(** Update the boot loader OBL in an existing AosFS partition, replacing it by the new BBL handling the Init string differently.
	The BBL must imperatively have the same size, 4 blocks, as the OBL. The same BBL is applicable to all AosFS partitions. *)
	UpdateBootLoader* = OBJECT(Operation);
	VAR
		(* parameters *)
		bootloader : ARRAY 32 OF CHAR;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF disk.device.blockSize = BS THEN
				IF IsNativeType(disk.table[partition].type) OR (disk.isDiskette) THEN
					valid := TRUE;
				ELSE ReportError("Partition must have Native/Aos type");
				END;
			ELSE ReportError("Blocksize not supported");
			END;
			RETURN valid;
		END ValidParameters;

		(** dev#part BootLoader ~ *)
		PROCEDURE SetParameters*(CONST bootloader : ARRAY OF CHAR);
		BEGIN
			SELF.bootloader := ""; Strings.Append(SELF.bootloader, bootloader);
		END SetParameters;

		PROCEDURE DoOperation*;
		VAR  res, fs : LONGINT; string: ARRAY 256 OF CHAR; f : Files.File;
		BEGIN
			fs := DetectFS(disk.device, partition);
			IF (fs = AosFS32) OR (fs = AosFS128) THEN
				f := Files.Old(bootloader);
				IF f # NIL THEN
					UpdateOBL(f, res);
					IF res = AosDisks.Ok THEN
						info.String(bootloader); info.String(" written to disk"); info.Ln;
						result.String(diskpartString); result.String(" updated successful");
					ELSE
						GetErrorMsg("UpdateOBL failed: ", res, string); ReportError(string);
					END
				ELSE
					string := "Bootloader file"; Strings.Append(string, bootloader); Strings.Append(string, " not found");
					ReportError(string);
				END
			ELSE
				string := ""; Strings.Append(string, diskpartString); Strings.Append(string, " is not AosFS-formatted");
				ReportError(string);
			END;
		END DoOperation;

		(* Overwrite the existing boot loader with the new one, leaving critical data untouched. *)
		PROCEDURE UpdateOBL(f: Files.File; VAR res: LONGINT);
		CONST MaxSize = MaxBootLoaderSize*BS;
		VAR
			b, bnew: ARRAY MaxSize OF CHAR; i, tsize, rsize, lsize, len: LONGINT;
			r: Files.Reader;
		BEGIN
			ASSERT(disk.device.blockSize = BS);
			IF res = AosDisks.Ok THEN
				NEW(r, f, 0);
				ASSERT((f # NIL) & (f.Length() <= BootLoaderSize*BS)); (* assume boot file is present and small enough *)
				r.Bytes(bnew, 0, f.Length(), len);
				ASSERT(r.res = 0);
				lsize := f.Length() DIV BS;
				disk.device.Transfer(AosDisks.Read, disk.device.table[partition].start, lsize, b, 0, res);
				ASSERT(Get4(b, 1F8H) = FSID); (* OBL.Bin signature 'AOS!' *)
				(* get parameters from boot loader *)
				rsize := Get2(b, 0EH); tsize := ORD(b[10H]);
				ASSERT((rsize-tsize)*BS = f.Length()); (* check boot loader size *)
				lsize := f.Length() DIV BS;
				ASSERT(lsize = BootLoaderSize);
				(* set parameters in boot loader *)
				FOR i := 0H TO 2H DO b[i] := bnew[i] END;
				(* Leave the data from 3H to 24H untouched: info on the partition position and size
					i.e. the BPB or BIOS Parameter Block - see comments "OBL variables" *)
				FOR i := 25H TO 1EFH DO b[i] := bnew[i] END;
				(* Leave the data from 1F0H to 1FFH untouched: info on the file sytem
					see comments "AosFS Table Format" *)
				FOR i := 200H TO BootLoaderSize*BS-1 DO b[i] := bnew[i] END;
				(* now write the boot loader back to disk *)
				disk.device.Transfer(AosDisks.Write, disk.device.table[partition].start, lsize, b, 0, res);
				(* The configuration table is left as is. It is up to the user to specify
				a new Init string (3 hexadecimal characters) suitable for the graphic card. *)
			END
		END UpdateOBL;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "UpdateLoader"; desc := "Update Boot Loader on partition"; locktype := WriterLock;
		END Init;

	END UpdateBootLoader;

TYPE

	UpdateBootFile* = OBJECT(Operation);
	VAR
		(* parameters *)
		bootfilename : ARRAY 128 OF CHAR;

		PROCEDURE SetParameters*(CONST bootfilename : ARRAY OF CHAR);
		BEGIN
			SELF.bootfilename := ""; Strings.Append(SELF.bootfilename, bootfilename);
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF disk.device.blockSize = BS THEN
				IF IsNativeType(disk.table[partition].type) OR (disk.isDiskette)THEN
					valid := TRUE;
				ELSE ReportError("Partition must have type Native/Aos");
				END;
			ELSE ReportError("Blocksize not supported");
			END;
			RETURN valid;
		END ValidParameters;

		(* Update the boot file in an existing Oberon partition. *)
		PROCEDURE DoOperation*; (** dev#part [ BootFile ] ~ *)
		VAR  f : Files.File; res, fs : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			fs := DetectFS(disk.device, partition);
			IF (fs # UnknownFS) THEN
				IF bootfilename = "" THEN bootfilename := BootFileName; END;
				f := Files.Old(bootfilename);
				IF f # NIL THEN
					InitBootFile(disk.device, partition, f, res);
					IF res = AosDisks.Ok THEN
						result.String("Bootfile "); result.String(bootfilename); result.String(" written to "); result.String(diskpartString); result.Ln;
					ELSE
						GetErrorMsg("InitBootFile failed", res, temp); ReportError(temp);
					END;
				ELSE Strings.Append(bootfilename, " not found"); ReportError(bootfilename);
				END;
			ELSE ReportError("Partition is not Oberon-formatted");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "UpdateBootFile"; desc := "Updates boot file on partition "; locktype := WriterLock;
		END Init;

	END UpdateBootFile;

TYPE

	WriteMBR* = OBJECT(Operation);
	VAR
		(* parameters *)
		filename : ARRAY 128 OF CHAR; (* file containing MBR code *)
		preserveTable : BOOLEAN; (* if TRUE, the partition table is not altered *)
		preserveSignature : BOOLEAN; (* if TRUE, the disk signature used by Windows Vista (Offset 1B8H-1BBH) is not altered *)

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF disk.device.blockSize = BS THEN
				IF partition = 0 THEN
					valid := TRUE;
				ELSE ReportError("Only partition 0 is valid");
				END;
			ELSE ReportError("Blocksize not supported");
			END;
			RETURN valid;
		END ValidParameters;

		(** dev#0 name ~ *)
		PROCEDURE SetParameters*(CONST filename : ARRAY OF CHAR; preserveTable, preserveSignature : BOOLEAN);
		BEGIN
			SELF.filename := ""; Strings.Append(SELF.filename, filename);
			SELF.preserveTable := preserveTable;
			SELF.preserveSignature := preserveSignature;
		END SetParameters;

		PROCEDURE DoOperation*;
		VAR
			f: Files.File; r: Files.Reader; buf1, buf2: ARRAY BS OF CHAR;
			string : ARRAY 256 OF CHAR;
			res, len, i: LONGINT;
		BEGIN
			f := Files.Old(filename);
			IF f # NIL THEN
				NEW(r, f, 0);
				r.Bytes(buf1, 0, BS, len);
				IF (r.res = 0) & (buf1[01FEH] = 055X) & (buf1[01FFH] = 0AAX)  & (f.Length() = BS) THEN
					IF preserveTable OR preserveSignature THEN
						disk.device.Transfer(AosDisks.Read, 0, 1, buf2, 0, res);
						IF (res = AosDisks.Ok) THEN
							IF preserveTable THEN (* copy partition table *)
								FOR i := Slot1 TO 01FDH DO buf1[i] := buf2[i] END;
							END;
							IF preserveSignature THEN (* copy Windows Vista disk signature *)
								FOR i := 01B8H TO 01BBH DO buf1[i] := buf2[i]; END;
							END;
						ELSE
							GetErrorMsg("Could not load MBR", res, string); ReportError(string);
							RETURN;
						END
					END;
					IF  ~preserveTable THEN (* empty partition table *)
						FOR i := Slot1 TO 01FDH DO buf1[i] := 0X END;
					END;
					disk.device.Transfer(AosDisks.Write, 0, 1, buf1, 0, res);
					IF res = AosDisks.Ok THEN
						result.String(filename); result.String(" written to MBR");
					ELSE
						GetErrorMsg("Could not write MBR", res, string); ReportError(string);
						result.String("Operation failed");
					END;
				ELSE
					Strings.Append(string, filename); Strings.Append(string, " does not contain MBR");
					ReportError(string);
				END
			ELSE
				string := ""; Strings.Append(string, filename); Strings.Append(string, " not found");
				ReportError(string);
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "WriteMBR"; desc := "Write MBR to disk"; locktype := WriterLock;
		END Init;

	END WriteMBR;

TYPE

	GetConfig* = OBJECT(Operation);
	VAR
		table : ConfigString;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF disk.device.blockSize # BS THEN ReportError("Unsupported blocksize"); RETURN FALSE; END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE GetTable*() : ConfigString;
		BEGIN
			IF (state.status * StatusFinished # {}) & (state.status * StatusError = {}) THEN RETURN table END;
			RETURN NIL;
		END GetTable;

		PROCEDURE DoOperation*;
		VAR config : Configuration; fs, res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			fs := DetectFS(disk.device, partition);
			IF (fs = AosFS32) OR (fs = AosFS128) THEN
				NEW(config);
				config.GetTable(disk.device, partition, res);
				IF res = AosDisks.Ok THEN
					table := config.table;
					result.String("Config loaded from "); result.String(diskpartString);
				ELSE GetErrorMsg("GetTable failed: ", res, temp); ReportError(temp);
				END;
			ELSE ReportError("Volume is not AosFS");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "GetConfig"; desc := "Read config string to partition"; locktype := ReaderLock;
		END Init;

	END GetConfig;

TYPE

	SetConfig* = OBJECT(Operation);
	VAR
		(* parameters *)
		configString : Strings.String;
		pos : LONGINT;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF disk.device.blockSize = BS THEN
				RETURN TRUE;
			ELSE ReportError("Blocksize not supported");
			END;
			RETURN FALSE;
		END ValidParameters;

		(** dev#part configString ~ *)
		(** config string format: {key = "value"} *)
		PROCEDURE SetParameters*(configString : Strings.String; pos : LONGINT);
		BEGIN
			SELF.configString := configString; SELF.pos := pos;
		END SetParameters;

		PROCEDURE DoOperation*;
		VAR config : Configuration; fs, i , res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			fs := DetectFS(disk.device, partition);
			IF (fs = AosFS32) OR (fs = AosFS128) THEN
				NEW(config);
				config.GetTable(disk.device, partition, res);
				IF res = AosDisks.Ok THEN
					LOOP
						i := config.FindEntry(0, 8);
						IF i < 0 THEN EXIT END;
						config.DeleteEntry(i)
					END;
					IF config.ParseConfig(configString^, pos) THEN
						config.PutTable(disk.device, partition, res);
						IF res = AosDisks.Ok THEN
							result.String("Config written to "); result.String(diskpartString);
						ELSE GetErrorMsg("PutTable failed", res, temp); ReportError(temp);
						END
					ELSE ReportError("syntax error");
					END;
				ELSE GetErrorMsg("GetTable failed: ", res, temp); ReportError(temp);
				END;
			ELSE ReportError("Volume is not AosFS");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "SetConfig"; desc := "Write config string to partition"; locktype := WriterLock;
		END Init;

	END SetConfig;

TYPE

	ConfigEntry* = RECORD
		key*, value* : Strings.String;
	END;

	Table* = POINTER TO ARRAY OF ConfigEntry;

	ConfigTable* = OBJECT
	VAR
		entries : Table;
		hex : ARRAY 32 OF CHAR;

		PROCEDURE GetEntries*() : Table;
		VAR table : Table; i : LONGINT;
		BEGIN {EXCLUSIVE}
			table := NIL;
			IF (entries # NIL) THEN
				NEW(table, LEN(entries));
				FOR i := 0 TO LEN(entries)-1 DO
					table[i] := entries[i];
				END;
			END;
			RETURN table;
		END GetEntries;

		PROCEDURE GetNofEntries*() : LONGINT;
		VAR len : LONGINT;
		BEGIN {EXCLUSIVE}
			IF (entries = NIL) THEN len := 0; ELSE len := LEN(entries); END;
			RETURN len;
		END GetNofEntries;

		PROCEDURE GetAsString*() : Strings.String;
		BEGIN {EXCLUSIVE}
			RETURN GetAsStringInternal();
		END GetAsString;

		(**	Replace all occurence of entries with key 'key'. If no entry is found, add it *)
		PROCEDURE SetValueOf*(key, value : Strings.String);
		VAR entry : ConfigEntry; found : BOOLEAN; i : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT((key # NIL) & (value # NIL));
			entry.key := key; entry.value := value;
			IF (entries = NIL) THEN
				NEW(entries, 1);
				entries[i] := entry;
			ELSE
				found := FALSE;
				FOR i := 0 TO LEN(entries)-1 DO
					IF (entries[i].key^ = key^) THEN
						entries[i] := entry;
						found := TRUE;
					END;
				END;
				IF ~found THEN
					AddEntryInternal(0, entry);
				END;
			END;
		END SetValueOf;

		PROCEDURE GetAsStringInternal() : Strings.String;
		VAR string : ARRAY MaxConfigString OF CHAR; w : Streams.StringWriter; i : LONGINT;
		BEGIN
			NEW(w, MaxConfigString);
			FOR i := 0 TO LEN(entries)-1 DO
				w.String(entries[i].key^); w.String(" = "); w.Char(22X); w.String(entries[i].value^); w.Char(22X); w.Ln;
				IF w.res # Streams.Ok THEN
					RETURN NIL;
				END;
			END;
			w.Char("~"); w.Get(string);
			RETURN Strings.NewString(string);
		END GetAsStringInternal;

		PROCEDURE LoadFromStream*(r : Streams.Reader; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(r # NIL);
			entries := NIL; res := Ok; msg := "";
			IF ~ParseStream(r) THEN
				entries := NIL;
				res := 99; COPY("Configuration string parsing failed", msg);
			END;
		END LoadFromStream;

		(** Load configuration data from file *)
		PROCEDURE LoadFromFile*(CONST filename : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
		VAR file : Files.File; r: Files.Reader;
		BEGIN {EXCLUSIVE}
			res := Ok; entries := NIL;
			file := Files.Old(filename);
			IF (file # NIL) THEN
				NEW(r, file, 0);
				IF ParseStream(r) THEN
					res := Ok; msg := "";
				ELSE
					entries := NIL;
					msg := "Parsing configuration file "; Strings.Append(msg, filename); Strings.Append(msg, " failed");
					res := 99;
				END;
			ELSE
				msg := "Configuration file "; Strings.Append(msg, filename); Strings.Append(msg, " not found");
				res := 99;
			END;
		END LoadFromFile;

		(** Store configuration data to file *)
		PROCEDURE StoreToFile*(CONST filename : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
		VAR f : Files.File; w : Files.Writer; string : Strings.String;
		BEGIN {EXCLUSIVE}
			res := Ok;
			IF (entries # NIL) THEN
				string := GetAsStringInternal();
				ASSERT(string # NIL);
				f := Files.New(filename);
				IF (f # NIL) THEN
					Files.OpenWriter(w, f, 0); w.String(string^); w.Update;
					IF w.res = Streams.Ok THEN
						Files.Register(f); f.Update;
						msg := ""; res := Ok;
					ELSE msg := "Error when writing to file "; Strings.Append(msg, filename); res := 99;
					END;
				ELSE msg := "Could not create file "; Strings.Append(msg, filename); res := 99;
				END;
			ELSE msg := "No configuration data available to store"; res := 99;
			END;
		END StoreToFile;

		(* builds up configTable from config.table*)
		PROCEDURE ParseRawTable*(config : Configuration);
		VAR
			entry : ConfigEntry;
			key, value : ARRAY MaxStringLength OF CHAR;
			ch : CHAR;
			i, j, pos : LONGINT;
		BEGIN {EXCLUSIVE}
			entries := NIL;
			IF config.table # NIL THEN
				i := config.FindEntry(0, 8);
				IF i >= 0 THEN
					pos := 0;
					INC(i, 8);
					WHILE config.table[i] # 0X DO
						key := ""; j := 0;
						REPEAT (* get key *)
							key[j] := config.table[i]; INC(i); INC(j);
						UNTIL config.table[i] = 0X;
						key[j] := 0X;
						entry.key := Strings.NewString(key);

						value := ""; j := 0;
						LOOP (* get value *)
							INC(i); ch := config.table[i];
							IF ch = 0X THEN EXIT END;
							IF (ch >= " ") & (ch < 7FX) THEN
								value[j] := config.table[i];
							ELSE
								value[j] := "%"; INC(j);
								value[j] :=  hex[ORD(ch) DIV 10H]; INC(j);
								value[j] :=  hex[ORD(ch) MOD 10H];
							END;
							INC(j);
						END;
						value[j] := 0X;
						entry.value := Strings.NewString(value);
						AddEntryInternal(pos, entry); (* append entry *)
						INC(i); INC(pos);
					END
				END;
			END;
		END ParseRawTable;

		PROCEDURE ParseStream(r : Streams.Reader) : BOOLEAN;
		VAR
			temp : ARRAY 1024 OF CHAR; ch : CHAR;
			entry : ConfigEntry;
			error : BOOLEAN;
			i : LONGINT;
		BEGIN
			ASSERT(r # NIL);
			entries := NIL;
			error := FALSE; i := 0;
			LOOP
				r.SkipWhitespace;
				ch := r.Peek();
				IF ch = "~" THEN (* end of configuration string *)
				 	EXIT;
				END;
				(* read key *)
				r.String(temp);
				IF r.res = Streams.Ok THEN
					Strings.Trim(temp, " ");
					entry.key := Strings.NewString(temp);
				ELSE error := TRUE; EXIT;
				END;
				r.SkipWhitespace;
				r.Char(ch);
				IF (r.res # Streams.Ok) OR (ch # "=") THEN error := TRUE; EXIT; END;
				r.SkipWhitespace;
				(* read value *)
				r.String(temp);
				IF r.res = Streams.Ok THEN
					Strings.Trim(temp, " ");
					entry.value := Strings.NewString(temp);
				ELSE error := TRUE; EXIT;
				END;
				r.SkipSpaces;
				IF ~r.EOLN() THEN error := TRUE; EXIT; END;
				AddEntryInternal(i, entry); INC(i);
			END;
			IF error THEN entries := NIL; END;
			RETURN ~error;
		END ParseStream;

		PROCEDURE ChangeEntry*(pos : LONGINT; key, value : Strings.String);
		BEGIN {EXCLUSIVE}
			IF (pos >= 0) & (pos < LEN(entries)) THEN
				entries[pos].key := key;
				entries[pos].value := value;
			END;
		END ChangeEntry;

		PROCEDURE AddEntry*(pos : LONGINT; entry : ConfigEntry);
		BEGIN {EXCLUSIVE}
			AddEntryInternal(pos, entry);
		END AddEntry;

		PROCEDURE AddEntryInternal(pos : LONGINT; entry : ConfigEntry);
		VAR newTable : Table; i, j : LONGINT;
		BEGIN
			ASSERT(pos >=0);
			IF entries = NIL THEN
				NEW(entries, 1); entries[0] := entry;
			ELSE
				 ASSERT(pos < LEN(entries)+1);
				NEW(newTable, LEN(entries)+1);
				i := 0; j := 0;
				LOOP
					IF i = pos THEN
						newTable[i] := entry;
					ELSE
						newTable[i] := entries[j];
						INC(j);
					END;
					INC(i); IF i >= LEN(newTable) THEN EXIT END;
				END;
				entries := newTable;
			END;
		END AddEntryInternal;

		PROCEDURE RemoveEntry*(entry : LONGINT);
		BEGIN {EXCLUSIVE}
			RemoveEntryInternal(entry);
		END RemoveEntry;

		PROCEDURE RemoveEntryInternal(entry : LONGINT);
		VAR newTable : Table; i, j : LONGINT;
		BEGIN
			IF (entries # NIL) THEN
				IF LEN(entries) = 1 THEN
					entries := NIL;
				ELSE
					NEW(newTable, LEN(entries) -1);
					j := 0;
					FOR i := 0 TO LEN(entries) - 1 DO
						IF  i # entry THEN
							newTable[j] := entries[i]; INC(j);
						END;
					END;
					entries := newTable;
				END;
			END;
		END RemoveEntryInternal;

		PROCEDURE SwapEntries*(i, j : LONGINT);
		VAR temp : ConfigEntry;
		BEGIN {EXCLUSIVE}
			IF (i >= 0) & (i < LEN(entries)) & (j >= 0) & (j < LEN(entries)) THEN
				temp := entries[i];
				entries[i] := entries[j];
				entries[j] := temp;
			END;
		END SwapEntries;

		PROCEDURE Clone*() : ConfigTable;
		VAR configTable : ConfigTable;
		BEGIN
			NEW(configTable);
			configTable.entries := GetEntries();
			RETURN configTable;
		END Clone;


	END ConfigTable;

TYPE


	ConfigString* = POINTER TO ARRAY OF CHAR;

	Configuration*  = OBJECT
	VAR
		table* : ConfigString; (* in raw format *)
		hex : ARRAY 32 OF CHAR;

		(* Read the config table from the specified partition. *)
		PROCEDURE GetTable*(dev: AosDisks.Device; part: LONGINT; VAR res: LONGINT);
		VAR tsize, reserved, fsOfs: LONGINT;
		BEGIN {EXCLUSIVE}
			table := NIL; GetVars(dev, part, tsize, reserved, fsOfs, res);
			BootLoaderSize := reserved-tsize;
			(*TRACE(BootLoaderSize);*)
			IF res = AosDisks.Ok THEN
				NEW(table, tsize*BS);
				dev.Transfer(AosDisks.Read, dev.table[part].start + BootLoaderSize, tsize, table^, 0, res)
			END
		END GetTable;

		(* Overwrite the config table on the specified partition. *)
		PROCEDURE PutTable*(dev: AosDisks.Device; part: LONGINT; VAR res: LONGINT);
		VAR tsize, reserved, fsOfs: LONGINT;
		BEGIN {EXCLUSIVE}
			GetVars(dev, part, tsize, reserved, fsOfs, res);
			BootLoaderSize := reserved-tsize;
			(*TRACE(BootLoaderSize);*)
			IF res = AosDisks.Ok THEN
				ASSERT(tsize*BS = LEN(table^)); (* same size *)
				dev.Transfer(AosDisks.Write, dev.table[part].start + BootLoaderSize, tsize, table^, 0, res)
			END
		END PutTable;

		(* Parse the configuration strings on the command line and add them to the config table. *)
		PROCEDURE ParseConfig*(CONST table : ARRAY OF CHAR; pos : LONGINT): BOOLEAN;
		CONST CR = 0DX; LF = 0AX;
		VAR  config: ARRAY MaxConfig OF CHAR; result : BOOLEAN; i, j: LONGINT;
		BEGIN
			ASSERT((pos >= 0) & (pos < LEN(table)));
			i := 0; j := pos;
			LOOP
				(* skip whitespace and comment lines *)
				REPEAT
					WHILE (j < LEN(table)) & (table[j] <= " ") DO INC(j); END;
					IF (j < LEN(table)) & (table[j] = "#") THEN (* comment; skip line *)
						WHILE (j < LEN(table)) & (table[j] # CR) & (table[j] # LF) DO INC(j); END;
					END;
					IF j >= LEN(table) THEN result := FALSE; EXIT END;
				UNTIL (table[j] # CR) & (table[j] # LF);

				IF table[j] = "~" THEN (* end of config table *)
					config[i] := 0X; INC(i);
					UnQuote(config, i);
					AddEntry(8, i, config);
					result := TRUE;
					EXIT
				END;

				(* read key *)
				REPEAT
					config[i] := table[j];
					INC(i); INC(j);
				UNTIL (j >= LEN(table)) OR (table[j] <= " ") OR (table[j] = "=") OR (table[j] = 22X);

				(* skip whitespace *)
				WHILE (j < LEN(table)) & (table[j] > 0X) & (table[j] <= " ") DO INC(j); END;

				(* exspected character: "=" *)
				IF (j >= LEN(table)) OR (table[j] # "=") THEN result := FALSE; EXIT END;
				config[i] := 0X; INC(i); INC(j);

				(* skip whitespace *)
				WHILE (j < LEN(table)) & (table[j] > 0X) & (table[j] <= " ") DO INC(j); END;

				(* expecting opening quote *)
				IF (j >= LEN(table)) OR (table[j] # 22X) THEN result := FALSE; EXIT END;

				(* read value *)
				INC(j); WHILE (j < LEN(table)) & (table[j] # 22X) & (table[j] >= " ") DO config[i] := table[j]; INC(i); INC(j); END;

				(* exspecting closing quote *)
				IF (j >= LEN(table)) OR (table[j] # 22X) THEN result := FALSE; EXIT END;

				config[i] := 0X; INC(i); INC(j);
			END;
			RETURN result;
		END ParseConfig;

		(* Parse the table and return it as string *)
		PROCEDURE GetTableAsString*() :  Streams.StringWriter;
		CONST MaxSize = 2048;
		VAR w : Streams.StringWriter; i: LONGINT; ch: CHAR;
		BEGIN
			NEW(w, MaxSize);
			IF table # NIL THEN
				i := FindEntry(0, 8);
				IF i >= 0 THEN
					INC(i, 8);
					WHILE table[i] # 0X DO
						w.String("  ");
						REPEAT w.Char(table[i]); INC(i) UNTIL table[i] = 0X;
						w.Char("="); w.Char(22X);
						LOOP
							INC(i); ch := table[i];
							IF ch = 0X THEN EXIT END;
							IF ch = ";" THEN ch := ","; END; (* ";" is used to separate Commands *)
							IF (ch >= " ") & (ch < 7FX) THEN
								w.Char(ch);
							ELSE
								w.Char("%"); w.Char( hex[ORD(ch) DIV 10H]); w.Char(hex[ORD(ch) MOD 10H]);
							END
						END;
						w.Char(22X); w.Ln;
						INC(i)
					END
				END;
				w.Char("~")
			ELSE w.String("GetTable: No configuration is loaded");
			END;
			w.Ln;
			RETURN w;
		END GetTableAsString;

		(* Find the next occurance of the specified entry type in the config table. *)
		PROCEDURE FindEntry*(i, type: LONGINT): LONGINT;
		VAR t: LONGINT;
		BEGIN (* caller must hold lock on object *)
			ASSERT(table#NIL);
			LOOP
				t := Get4(table^, i);
				IF t = type THEN RETURN i
				ELSIF t = -1 THEN RETURN -1
				ELSE INC(i, Get4(table^, i+4));
				END;
				IF i >= LEN(table) THEN RETURN -1 END;
			END;
		END FindEntry;

		(* Add an entry to the end of the table. *)
		PROCEDURE AddEntry*(type, dsize: LONGINT; CONST data: ARRAY OF CHAR);
		VAR i, j, size: LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(dsize >= 0);
			i := FindEntry(0, -1); (* find end of table *)
			size := (dsize+3) DIV 4 * 4 + 8;
			Put4(table^, i, type); Put4(table^, i+4, size);
			j := 0; WHILE j # dsize DO table[i+8+j] := data[j]; INC(j) END;
			WHILE j MOD 4 # 0 DO table[i+8+j] := 0X; INC(j) END;
			Put4(table^, i+size, -1)
		END AddEntry;

		(* Delete the specified entry. *)
		PROCEDURE DeleteEntry*(i: LONGINT);
		VAR j, s: LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(Get4(table^, i) # -1); (* can not delete end marker *)
			s := Get4(table^, i+4);
			FOR j := i TO LEN(table^)-s-1 DO table[j] := table[j+s] END
		END DeleteEntry;

		PROCEDURE UnQuote(VAR config: ARRAY OF CHAR; VAR len: LONGINT);
		VAR i, j: LONGINT;
		BEGIN
			i := 0;
			WHILE i < len DO
				IF (config[i] = "%") & IsHex(config[i+1]) & IsHex(config[i+2]) THEN
					config[i] := CHR(HexVal(config[i+1])*10H + HexVal(config[i+2]));
					ASSERT(config[i] # 0X);
					FOR j := i+1 TO len-1 DO config[j] := config[j+2] END;
					DEC(len, 2)
				ELSE
					INC(i)
				END
			END
		END UnQuote;

		PROCEDURE HexVal(ch: CHAR): LONGINT;
		BEGIN
			CASE ch OF
				"0".."9": RETURN ORD(ch)-ORD("0")
				|"A".."F": RETURN ORD(ch)-ORD("A")+10
				|"a".."f": RETURN ORD(ch)-ORD("a")+10
			END
		END HexVal;

		PROCEDURE IsHex(ch: CHAR): BOOLEAN;
		BEGIN
			RETURN (ch >= "0") & (ch <= "9") OR (CAP(ch) >= "A") & (CAP(ch) <= "F")
		END IsHex;

		PROCEDURE &Init*;
		BEGIN
			hex := "0123456789ABCDEF";
		END Init;

	END Configuration;

TYPE

	(* Change the type of dev#part from oldtype to newtype *)
	ChangePartType* = OBJECT(Operation)
	VAR
		(* parameters *)
		oldtype, newtype : LONGINT;

		(* dev#name oldtype newtime *)
		PROCEDURE SetParameters*(oldtype, newtype : LONGINT);
		BEGIN
			SELF.oldtype := oldtype; SELF.newtype := newtype;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF disk.table[partition].type # oldtype THEN
				ReportError("Selected Partition has not type oldtype");
			ELSIF disk.table[partition].flags * {AosDisks.Valid} = {} THEN
				ReportError("Partition must be valid");
			ELSIF (newtype <= 0) OR (newtype > 255) THEN
				ReportError("The new type must be in [1,255]");
			ELSE (* parameters valid *)
				valid := TRUE;
			END;
			RETURN valid;
		END ValidParameters;

		(* Change type of partition from oldtype to newtype *)
		PROCEDURE DoOperation*;
		VAR
			b: ARRAY BS OF CHAR; e: LONGINT; res : LONGINT; temp: ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(disk.table[partition].type = oldtype);
			ASSERT(disk.device.blockSize = BS);
			SetStatus(state.status, "Changing type", 0, 0, 0, FALSE);
			disk.device.Transfer(AosDisks.Read, disk.table[partition].ptblock, 1, b, 0, res);
			IF res = AosDisks.Ok THEN
				e := disk.table[partition].ptoffset;
				ASSERT((e >= Slot1) & (e <= Slot4));	(* too strict, but good for now *)
				ASSERT((ORD(b[e+4]) = oldtype) & (b[510] = 055X) & (b[511] = 0AAX));
				ASSERT((newtype > 0) & (newtype < 256));
				b[e+4] := CHR(newtype);
				disk.device.Transfer(AosDisks.Write, disk.table[partition].ptblock, 1, b, 0, res);
				IF res = AosDisks.Ok THEN
					disk.table[partition].type := newtype;
					result.String("Changed type of "); result.String(diskpartString); result.String(" from ");
					result.Int(oldtype, 0); result.String(" to "); result.Int(newtype, 0);
				ELSE GetTransferError(disk.device, AosDisks.Read, disk.table[partition].ptblock, res, temp); ReportError(temp);
				END
			ELSE GetTransferError(disk.device, AosDisks.Read, disk.table[partition].ptblock, res, temp); ReportError(temp);
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "ChangeType"; desc := "Change type of partition"; locktype := WriterLock;
		END Init;

	END ChangePartType;

TYPE

	(** Create a partition of the specified size and type. *)
	CreatePartition* = OBJECT(Operation);
	VAR
		(* parameters *)
		size, type : LONGINT;
		override : BOOLEAN;

		(** dev#part sizeMB ~ *)
		PROCEDURE SetParameters*(size, type : LONGINT; override : BOOLEAN);
		BEGIN
			SELF.size := size; SELF.type := type; SELF.override := override;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR temp: ARRAY 256 OF CHAR;
		BEGIN
			IF disk.device.blockSize # BS THEN ReportError("Blocksize # 512B not supported"); RETURN FALSE; END;
			IF disk.gres # AosDisks.Ok THEN GetErrorMsg("Geometry error", disk.gres, temp); ReportError(temp); RETURN FALSE; END;
			IF disk.geo.cyls * disk.geo.hds * disk.geo.spt < DisketteLimit THEN ReportError("Geormetry error"); RETURN FALSE; END;
			IF (partition >= LEN(disk.table)) OR (disk.table[partition].type # FreeSpace) THEN
				ReportError("Specified partition not free"); RETURN FALSE;
			END;
			IF AosDisks.Valid IN disk.table[partition].flags THEN ReportError("Selected partition is primary partition"); RETURN FALSE; END;
			IF size < 0 THEN ReportError("Size parameter invalid"); RETURN FALSE; END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE DoOperation*;
		VAR done : BOOLEAN;
		BEGIN
			IF (disk.device.openCount = 1) OR override THEN (* only "mounted" once, so ok to change names *)
				IF (AosDisks.Primary IN disk.table[partition].flags) THEN
					done := CreatePrimary(size*1024*(1024 DIV BS), type);
				ELSE
					done := CreateLogical(size*1024*(1024 DIV BS), type);
				END;
				IF done THEN result.String("Partition created"); END;
			ELSE ReportError("Device has already been mounted");
			END;
		END DoOperation;

		PROCEDURE CreatePrimary(size, type: LONGINT) : BOOLEAN;
		VAR
			mbr, epbr : Block;
			i, e, res : LONGINT;
			temp: ARRAY 256 OF CHAR;
		BEGIN
			ASSERT((disk.device.blockSize = BS) & (disk.table[partition].type = FreeSpace));
			ASSERT(disk.table[partition].ptblock = 0); (* primary partition entry is in MBR *)
			IF IsExtendedPartition(type) THEN (* at most one extended partition per disk is allowed *)
				FOR i := 0 TO LEN(disk.device.table)-1 DO
					IF (AosDisks.Valid IN disk.device.table[i].flags) & IsExtendedPartition(disk.device.table[i].type) THEN
						ReportError("Create failed: There is already an extended partition on device");
						RETURN FALSE;
					END;
				END;
			END;
			disk.device.Transfer(AosDisks.Read, 0, 1, mbr, 0, res);
			IF res = AosDisks.Ok THEN
				IF IsMBR(mbr) THEN
					(* find first free slot *)
					e := -1;
					FOR i := 0 TO 3 DO
						IF (e = -1) & (Get4(mbr, Slot1 + 16*i + 12) = 0) THEN (* size is 0 (empty slot) *)
							e := Slot1 + 16*i
						END
					END;
					IF e # -1 THEN (* found free slot *)
						IF ~FillinSlot(disk, partition, mbr, e, type, disk.table[partition].start, size) THEN
							ReportError("Could not create partition: Partition too small");
							RETURN FALSE
						END;
						(* write the MBR *)
						disk.device.Transfer(AosDisks.Write, 0, 1, mbr, 0, res);
						IF res = AosDisks.Ok THEN
							IF IsExtendedPartition(type) THEN (* write emtpy EPBR *)
								FOR i := 0 TO BS-1 DO epbr[i] := 0X; END;
								epbr[510] := 055X; epbr[511] := 0AAX; (* EPBR signature *)
								disk.device.Transfer(AosDisks.Write, disk.table[partition].start, 1, epbr, 0 , res);
								IF res # AosDisks.Ok THEN
									GetErrorMsg("Critical: Failed to write EPBR", res, temp); ReportError(temp);
									RETURN FALSE;
								END;
							END;
							RETURN TRUE;
						ELSE GetErrorMsg("Critical: Failed to write MBR", res, temp); ReportError(temp);
						END;
					ELSE ReportError("Can't create partition: No free slots");
					END
				ELSE ReportError("Can't create partition: MBR signature wrong");
				END;
			ELSE GetErrorMsg("Can't create partition: Couldn't load MBR", res, temp); ReportError(temp);
			END;
			RETURN FALSE;
		END CreatePrimary;

		PROCEDURE CreateLogical(size, type: LONGINT) : BOOLEAN;
		CONST
			TypeExt = 5;
		VAR
			epbr, new : Block;
			slot1, slot2 : ARRAY 16 OF CHAR;
			extStart, extPart, lastLogical, i, res : LONGINT;
		BEGIN
			ASSERT((disk.device.blockSize = BS) & (disk.table[partition].type = FreeSpace));
			IF IsExtendedPartition(type) THEN
				ReportError("Can't create extended partition in extended partition");
				RETURN FALSE;
			END;
			(* we need the start sector of the extended partition that will contain the logical drive *)
			extStart := 0;
			FOR i := 0 TO LEN(disk.device.table)-1 DO
				IF IsExtendedPartition(disk.device.table[i].type) THEN
					IF extStart = 0 THEN
						extStart := disk.device.table[i].start; extPart := i;
					ELSE
						ReportError("Fatal: More than one extended partition on disk");
						RETURN FALSE;
					END;
				END;
			END;
			IF extStart = 0 THEN
				ReportError("No extended partition found");
				RETURN FALSE;
			END;

			IF ~GetEPBR(epbr, extStart) THEN RETURN FALSE END;

			FOR i := 0 TO 15 DO slot1[i] := epbr[Slot1 + i]; slot2[i] := epbr[Slot2 + i]; END;
			IF SlotEmpty(slot1) THEN (* no logical drives present *)
				ASSERT(SlotEmpty(slot2));
				IF ~FillinSlot(disk, partition, epbr, Slot1, type, 63, size) THEN
					ReportError("Create failed: Partition too small");
					RETURN FALSE;
				END;
				disk.device.Transfer(AosDisks.Write, extStart, 1, epbr, 0, res);
				IF res # AosDisks.Ok THEN
					ReportError("Could not write EPBR to logical drive partition");
					RETURN FALSE;
				END;
			ELSE
				i := extPart + 1; (* first logical drive *)
				WHILE (i < LEN(disk.table)) & (AosDisks.Valid IN disk.table[i].flags) & ~(AosDisks.Primary IN disk.table[i].flags) DO INC(i); END;
				(* last logical drive at disk.table[i-1] *)
				lastLogical := i-1;
				IF ~GetEPBR(epbr, disk.table[lastLogical].ptblock) THEN RETURN FALSE END;

				FOR i := 0 TO 15 DO slot2[i] := epbr[Slot2 + i]; END;
				IF ~SlotEmpty(slot2) THEN
					ReportError("Could not create logical drive (slot not empty)");
					RETURN FALSE;
				END;

				(* write new EPBR of partition to be created *)
				FOR i := 0 TO BS-1 DO new[i] := 0X; END;
				new[510] := 055X; new[511] := 0AAX; (* EPBR signature *)
				IF ~FillinSlot(disk, partition, new, Slot1, type, 63, size) THEN
					ReportError("Partition to small ");
					RETURN FALSE;
				END;
				ASSERT(disk.table[partition].ptblock # 0); (* protects MBR *)
				disk.device.Transfer(AosDisks.Write, disk.table[partition].ptblock, 1, new, 0, res);
				IF res # AosDisks.Ok THEN
					ReportError("Could not write EPBR to logical drive partition");
					RETURN FALSE;
				END;

				IF ~FillinSlot(disk, partition, epbr, Slot2, TypeExt, disk.table[partition].ptblock, size) THEN
					ReportError("Partition too small");
					RETURN FALSE
				END;
				Put4(epbr, Slot2+8, disk.table[partition].ptblock - extStart); (* sector number is relative to position of EPBR of extended partition *)

				disk.device.Transfer(AosDisks.Write, disk.table[lastLogical].ptblock, 1, epbr, 0, res);
				IF res # AosDisks.Ok THEN
					ReportError("Could not write EPBR to logical drive partition");
					RETURN FALSE;
				END;
			END;
			RETURN TRUE;
		END CreateLogical;

		PROCEDURE GetEPBR(VAR epbr : Block; ptblock : LONGINT) : BOOLEAN;
		VAR res : LONGINT; result : BOOLEAN; temp: ARRAY 256 OF CHAR;
		BEGIN
			result := FALSE;
			disk.device.Transfer(AosDisks.Read, ptblock, 1, epbr, 0, res);
			IF res = AosDisks.Ok THEN
				IF IsEPBR(epbr) THEN
					result := TRUE;
				ELSE ReportError("Delete failed: EPBR signature wrong(1)");
				END;
			ELSE GetErrorMsg("Delete failed: Could not load EPBR", res, temp); ReportError(temp);
			END;
			RETURN result;
		END GetEPBR;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "Create"; desc := "Create partition"; locktype := WriterLock;
		END Init;

	END CreatePartition;

TYPE

	(** Delete the specified partition. *)
	DeletePartition* = OBJECT(Operation);
	VAR
		(* parameter: type of partition to delete *)
		type : LONGINT;

		PROCEDURE SetParameters*(type : LONGINT);
		BEGIN
			SELF.type := type;
		END SetParameters;

		(* dev#part type *)
		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF (type > 0) OR (type < 256) THEN
				IF disk.device.blockSize = BS THEN
					IF (disk.table # NIL) & (LEN(disk.table) > 1) & (partition < LEN(disk.table)) THEN
						IF disk.table[partition].type = type THEN
							IF (AosDisks.Valid IN disk.table[partition].flags) & (disk.table[partition].type # FreeSpace) THEN
								valid := TRUE;
							ELSE ReportError("Partition not valid");
							END;
						ELSE ReportError("Oldtype parameter does not match");
						END;
					ELSE ReportError("Device is not partitioned");
					END;
				ELSE ReportError("Blocksize not supported");
				END;
			ELSE ReportError("New type must be in [1, 255]");
			END;
			RETURN valid;
		END ValidParameters;

		PROCEDURE DoOperation*;
		VAR  done : BOOLEAN;
		BEGIN
			ASSERT((type > 0) & (type < 256));
			IF disk.device.openCount = 1 THEN (* only "mounted" once, so ok to change names *)
	 			IF (AosDisks.Primary IN disk.table[partition].flags) THEN
	 				done := DeletePrimary(type);
		 		ELSE (* logical drive *)
					done := DeleteLogical(type);
				END;
				IF done THEN result.String(diskpartString); result.String(" deleted");
				ELSE ReportError("Delete Failed");
				END;
			ELSE ReportError(" contains mounted partitions");
			END;
		END DoOperation;

		PROCEDURE DeletePrimary(type: LONGINT) : BOOLEAN;
		VAR
			mbr, epbr: Block;
			e, i, res: LONGINT;
			result : BOOLEAN;
			temp: ARRAY 256 OF CHAR;
		BEGIN
			result := FALSE;
			ASSERT((disk.table[partition].type = type) & (disk.device.blockSize = BS) & (disk.table[partition].ptblock = 0)); (* primary partition entry is in MBR *)
			disk.device.Transfer(AosDisks.Read, 0, 1, mbr, 0, res);
			IF res = AosDisks.Ok THEN
				IF IsMBR(mbr) THEN
					e := disk.device.table[partition].ptoffset;
					ASSERT(ORD(mbr[e+4]) = type);  ASSERT((e >= Slot1) & (e <= Slot4));	(* entry is in partition table *)
					FOR i := 0 TO 15 DO mbr[e+i] := 0X END;
					disk.device.Transfer(AosDisks.Write, 0, 1, mbr, 0, res);
					IF res # AosDisks.Ok THEN
						GetErrorMsg("Critical: Could not store MBR, res: ", res, temp); ReportError(temp);
					ELSE
						result := TRUE;
						IF IsExtendedPartition(type) THEN
							(* delete EPBR on extended partition *)
							IF GetEPBR(epbr, disk.table[partition].start) THEN
								FOR i := 0 TO BS-1 DO epbr[i] := 0X; END;
								ASSERT(disk.table[partition].start#0);
								disk.device.Transfer(AosDisks.Write, disk.table[partition].start, 1, epbr, 0, res);
								IF res # AosDisks.Ok THEN
									ReportError("Could not delete EPBR signature of extended partition");
									result := FALSE;
								END;
							ELSE
								ReportError("Could not delete EPBR signature of extended partition (EPBR not found)");
								result := FALSE;
							END;
						END;
					END;
				ELSE ReportError("Delete failed: MBR signature wrong");
				END;
			ELSE  GetErrorMsg("Delete failed: Could not load MBR, res: ", res, temp); ReportError(temp);
			END;
			RETURN result;
		END DeletePrimary;

		PROCEDURE DeleteLogical(type: LONGINT) : BOOLEAN;
		VAR
			epbr, temp : Block;
			nextLogical, i, res, start : LONGINT;
			slot2 : ARRAY 16 OF CHAR;
			extStart : LONGINT; (* adr of EPBR of extended partition *)
			writebackAdr : LONGINT;
		BEGIN
			ASSERT((disk.table[partition].type = type) & (disk.device.blockSize = BS) & (disk.table[partition].ptblock #  0)); (* logical partition entry not in MBR *)
			(* Extended partitions work the following way:
			- There's at most one extended partition entry in the MBR
			- The first sector of an extended partition contains the Extended Partition Boot Record (EPBR)
			- The structure of the EPBR is similar to the MBR's structure, but...
				- only partition table & signature (no executable code)
				- slots 2&3 are always zero
				- the first slot describes a logical drive
				- the second slot points to the next EBPR (~ next logical drive)
				- the address of the next EPBR is : ExtPartition.start + <second slot number of sectors between MBR & first sector field>
				-> linked list
			*)
			(* get start block of extended partition *)
			extStart := 0;
			FOR i := 0 TO LEN(disk.device.table)-1 DO
				IF IsExtendedPartition(disk.device.table[i].type) THEN
					IF extStart = 0 THEN
						extStart := disk.device.table[i].start;
					ELSE
						ReportError("Fatal: More than one extended partition on disk");
						RETURN FALSE;
					END;
				END;
			END;
			IF extStart = 0 THEN
				ReportError("No extended partition found");
				RETURN FALSE;
			END;

			(* get the "pointer" to the next EPBR; we take the whole slot 2*)
			IF ~GetEPBR(epbr, disk.table[partition].ptblock) THEN RETURN FALSE END;
			FOR i := 0 TO 15 DO slot2[i] := epbr[Slot2 + i]; END;

			(* now get the epbr which contains the "pointer" to the partition we want to delete *)
			IF disk.table[partition].ptblock = extStart THEN (* entry is in EPBR of extended partition *)

				writebackAdr := extStart;
				IF ~GetEPBR(epbr, extStart) THEN RETURN FALSE END; (* EPBR of extended partition *)

				IF SlotEmpty(slot2) THEN (* only one logical drive; just delete slot 1 ;-) *)
					FOR i := 0 TO 15 DO epbr[Slot1 + i] := 0X END;
				ELSE (* need to replace slot1&2 *)
					(* first we get slot1 & 2 of the next logical drive *)
					nextLogical := extStart + Get4(slot2, 8);
					IF ~GetEPBR(temp, nextLogical) THEN RETURN FALSE END;
					start := Get4(temp, Slot1 + 8) + Get4(slot2, 8);
					Put4(temp, Slot1 + 8, start);
					FOR i := 0 TO 15 DO
						epbr[Slot1 + i] := temp[Slot1 + i];
						epbr[Slot2 + i] := temp[Slot2 +i];
					END;
				END;
			ELSE
				(* we need the logical drive whos EBPR "points to" the logical drive we want to delete...*)
				IF (partition-1 > 0) & ~(AosDisks.Primary IN disk.table[partition-1].flags) THEN
					writebackAdr := disk.table[partition-1].ptblock;
					IF ~ GetEPBR(epbr, disk.table[partition-1].ptblock) THEN RETURN FALSE END;
					FOR i := 0 TO 15 DO epbr[Slot2+i] := slot2[i];	END;
				ELSE
					ReportError("Can't find EPBR of previous logical drive");
					RETURN FALSE;
				END;
			END;
			(* write back EPBR of extended partition *)
			ASSERT(writebackAdr#0);
			disk.device.Transfer(AosDisks.Write, writebackAdr, 1, epbr, 0, res);
			IF res # AosDisks.Ok THEN
				GetErrorMsg("Critical: Could not store EPBR of extended partition", res, temp); ReportError(temp);
				RETURN FALSE;
			END;
			RETURN TRUE;
		END DeleteLogical;

		PROCEDURE GetEPBR(VAR epbr : Block; ptblock : LONGINT) : BOOLEAN;
		VAR res : LONGINT; result : BOOLEAN; temp: ARRAY 256 OF CHAR;
		BEGIN
			result := FALSE;
			disk.device.Transfer(AosDisks.Read, ptblock, 1, epbr, 0, res);
			IF res = AosDisks.Ok THEN
				IF IsEPBR(epbr) THEN
					result := TRUE;
				ELSE ReportError("Delete failed: EPBR signature wrong(1)");
				END;
			ELSE GetErrorMsg("Delete failed: Could not load EPBR", res, temp); ReportError(temp);
			END;
			RETURN result;
		END GetEPBR;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "Delete"; desc := "Delete partition"; locktype := WriterLock;
		END Init;

	END DeletePartition;

TYPE

	(** Set or clear the active bit of the specified partition. *)
	SetFlags* = OBJECT(Operation);
	VAR
		(* Parameters *)
		on : BOOLEAN;

		PROCEDURE SetParameters*(on : BOOLEAN);
		BEGIN
			SELF.on := on;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		VAR valid : BOOLEAN;
		BEGIN
			valid := FALSE;
			IF disk.device.blockSize = BS THEN
				IF ~disk.isDiskette THEN
					valid := TRUE;
				ELSE ReportError("Operation not supported for floppy disk drives");
				END;
			ELSE ReportError("Blocksize not supported");
			END;
			RETURN valid;
		END ValidParameters;

		(* Set active bit of dev#part to <on> *)
		PROCEDURE DoOperation*;
		VAR
			res, e: LONGINT; b: ARRAY BS OF CHAR; mod: BOOLEAN;
			string : ARRAY 256 OF CHAR;
		BEGIN
			disk.device.Transfer(AosDisks.Read, disk.device.table[partition].ptblock, 1, b, 0, res);
			IF res = AosDisks.Ok THEN
				ASSERT((b[510] = 055X) & (b[511] = 0AAX));
				e := disk.device.table[partition].ptoffset;
				IF (e >= Slot1) & (e <= Slot4) THEN
					mod := FALSE;
					IF on & (b[e] = 0X) THEN b[e] := 80X; mod := TRUE
					ELSIF ~on & ((b[e] >= 80X) & (b[e] <= 81X)) THEN b[e] := 0X; mod := TRUE
					END;
					IF mod THEN
						disk.device.Transfer(AosDisks.Write, disk.device.table[partition].ptblock, 1, b, 0, res);
						IF res = AosDisks.Ok THEN
							IF on THEN
								INCL(disk.device.table[partition].flags, AosDisks.Boot);
								INCL(disk.table[partition].flags, AosDisks.Boot);
								result.String(diskpartString); result.String(" activated");
							ELSE
								EXCL(disk.device.table[partition].flags, AosDisks.Boot);
								EXCL(disk.table[partition].flags, AosDisks.Boot);
								result.String(diskpartString); result.String(" deactivated");
							END
						ELSE GetTransferError(disk.device, AosDisks.Write, disk.device.table[partition].ptblock, res, string); ReportError(string);
						END
					ELSE
						string := ""; Strings.Append(string, diskpartString);
						IF on THEN Strings.Append(string, " already active"); ELSE Strings.Append(string, " already inactive"); END;
						ReportError(string);
					END
				ELSE ReportError("not a valid partition");
				END
			ELSE GetTransferError(disk.device, AosDisks.Write, disk.device.table[partition].ptblock, res, string); ReportError(string);
			END;
		END DoOperation;

		PROCEDURE &Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "(In)Activate"; desc := "Set/clear active bit of partition"; locktype := WriterLock;
		END Init;

	END SetFlags;

TYPE

	(**																								*)
	(* Install the Bluebottle boot manager on the specified partition 									*)
	(* Example of a compound operation.															*)
	InstallBootManager* = OBJECT(Operation)
	VAR
		mbrFilename, restFilename : ARRAY 1024 OF CHAR; (* boot manager *)

		PROCEDURE SetParameters*(CONST mbrFilename, restFilename : ARRAY OF CHAR);
		BEGIN
			SELF.mbrFilename := ""; Strings.Append(SELF.mbrFilename, mbrFilename);
			SELF.restFilename := ""; Strings.Append(SELF.restFilename, restFilename);
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF disk.device.blockSize # BS THEN
				ReportError("InstallBootManager only works with 512B block size"); RETURN FALSE;
			END;
			IF partition # 0 THEN
				ReportError("The only valid selection is partition 0"); RETURN FALSE;
			END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE DoOperation*;
		VAR
			writeMBR : WriteMBR; fileToPartition : FileToPartition;
			nofSectors : LONGINT;
			string : ARRAY 1024 OF CHAR;
			f : Files.File;
		BEGIN
			(* Before we write data to the MBR, first check whether the rest of the boot manager is present *)
			f := Files.Old(restFilename);
			IF f = NIL THEN
				string := "File "; Strings.Append(string, restFilename); Strings.Append(string, " not found.");
				ReportError(string);
				RETURN;
			END;

			IF (f.Length() MOD BS # 0) THEN
				ReportError("Boot manager file size must be multiple of 512B");
				RETURN;
			END;

			nofSectors := f.Length() DIV BS;
			IF (nofSectors > 20) THEN
				ReportError("Boot manager file is too large. Wrong file?");
				RETURN;
			END;

			(* Do the actual operation *)
			NEW(writeMBR, disk, partition, out);
			writeMBR.SetParent(SELF);
			writeMBR.SetParameters(mbrFilename, TRUE, TRUE);
			writeMBR.SetBlockingStart;

			IF writeMBR.state.errorCount = 0 THEN
				NEW(fileToPartition, disk, partition, out);
				fileToPartition.SetParent(SELF);
				fileToPartition.SetParameters(restFilename, 1, nofSectors);
				fileToPartition.SetBlockingStart;
				IF fileToPartition.state.errorCount = 0 THEN
					result.String("Boot manager has been written to "); result.String(diskpartString);
				ELSE
					ReportError("FileToPartition operation failed.");
				END;
			ELSE
				ReportError("WriteMBR operation failed.");
			END;

		END DoOperation;

		PROCEDURE & Init*(disk : Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "InstallBootManager"; desc := "Install Boot Manager on partition"; locktype := WriterLock;
		END Init;

	END InstallBootManager;

VAR
	safe*: BOOLEAN;
	diskModel- : DisksModel;
	operations- : OperationManager;
	infobus- : CompletionNotification;
	BootLoaderName: ARRAY 64 OF CHAR;
	BootLoaderSize: LONGINT;

PROCEDURE WritePart*(w: Streams.Writer; dev: AosDisks.Device; part: LONGINT);
BEGIN
	ASSERT((dev#NIL) & (w # NIL) & (part >= 0) & (part <= 99));
	w.String(dev.name); w.String("#"); w.Int(part,1); w.String(" ");
END WritePart;

(* Check if an Oberon file system is present on a partition. Returns 0 if no Oberon file system found,
 1 for a Native file system, 2 for an old Aos file system and 3 for a new Aos file system, 4 for unknown but
 valid boot signature  *)
PROCEDURE DetectFS*(dev: AosDisks.Device; part: LONGINT): LONGINT;
VAR b: ARRAY BS OF CHAR; res, fs: LONGINT; doClose : BOOLEAN;
BEGIN
	IF dev.blockSize # BS THEN RETURN 0; END;
	(* special handling for diskettes *)
	IF Strings.Match("Diskette*", dev.name) & (dev.openCount < 1) THEN
		doClose := TRUE;
		dev.Open(res);
		IF res # AosDisks.Ok THEN RETURN 0 END;
	END;
	IF (dev.table = NIL) OR (part >= LEN(dev.table)) THEN RETURN 0 END;
	fs := UnknownFS;
	dev.Transfer(AosDisks.Read, dev.table[part].start, 1, b, 0, res);
	IF res = AosDisks.Ok THEN
		IF (b[1FEH] = 055X) & (b[1FFH] = 0AAX) THEN
			b[0] := "x"; b[1] := "x"; b[2] := "x"; b[9] := 0X;
			IF Get4(b, 1F8H) = FSID THEN
				IF (b[1FCH] = CHR(1)) THEN
					fs := AosFS32;
				ELSIF (b[1FCH] = CHR(2)) THEN
					fs := AosFS128;
				ELSE
					fs := UnknownFS;
				END;
			ELSIF Get4(b, 1F8H) = FSID0 THEN fs := OldAosFS32;
			ELSIF b = "xxxOBERON" THEN fs := NativeFS;
			ELSE fs := FatFS;
			END
		ELSE (* skip *)
		END
	END;
	IF doClose & (dev.openCount > 0) THEN (* it's a diskette *)
		dev.Close(res); (* ignore res *)
	END;
	RETURN fs
END DetectFS;

(** Performs a read on the specified device to see whether a medium is present *)
PROCEDURE DisketteInserted*(dev : AosDisks.Device) : BOOLEAN;
VAR res : LONGINT; b : ARRAY BS OF CHAR;
BEGIN
	IF (dev = NIL) OR (dev.blockSize # BS) THEN RETURN FALSE END;
	dev.Transfer(AosDisks.Read, 0, 1, b, 0, res);
	RETURN res = AosDisks.Ok;
END DisketteInserted;

(* Read OBL variables from the specified partition. *)
PROCEDURE GetVars(dev: AosDisks.Device; part: LONGINT; VAR tsize, reserved, fsOfs, res: LONGINT);
VAR b: ARRAY BS OF CHAR;
BEGIN
	ASSERT(dev.blockSize = BS);
	dev.Transfer(AosDisks.Read, dev.table[part].start, 1, b, 0, res);
	IF res = AosDisks.Ok THEN
		b[0] := "x"; b[1] := "x"; b[2] := "x"; b[9] := 0X;
		ASSERT(b = "xxxOBERON");	(* OBL present *)
		tsize := ORD(b[10H]); ASSERT(tsize > 0);
		reserved := Get2(b, 0EH); ASSERT(reserved >= BootLoaderSize + tsize);
		IF Get4(b, 1F8H) = FSID THEN fsOfs := Get4(b, 1F0H) ELSE fsOfs := reserved END
	END
END GetVars;

(* Write the specified file to the device, starting at block pos. *)
PROCEDURE WriteFile(f: Files.File; dev: AosDisks.Device; pos: LONGINT; VAR sum, res: LONGINT);
CONST Size = 32;
VAR buf: ARRAY Size*BS OF CHAR; r: Files.Rider; n, num: LONGINT;
BEGIN
	ASSERT(dev.blockSize = BS);
	f.Set(r, 0); num := (f.Length()+BS-1) DIV BS; sum := 0;
	LOOP
		IF num <= 0 THEN EXIT END;
		f.ReadBytes(r, buf, 0, Size*BS);
		n := Size*BS - r.res;
		WHILE n MOD BS # 0 DO buf[n] := 0X; INC(n) END;
		ASSERT((n > 0) & (n <= num*BS));
		dev.Transfer(AosDisks.Write, pos, n DIV BS, buf, 0, res);
		IF res # AosDisks.Ok THEN EXIT END;
		DEC(num, n DIV BS); INC(pos, n DIV BS);
		REPEAT DEC(n); sum := (sum + ORD(buf[n])) MOD 100H UNTIL n = 0
	END;
	sum := (-sum) MOD 100H
END WriteFile;

PROCEDURE CheckFile(f: Files.File; dev: AosDisks.Device; pos: LONGINT; sum: LONGINT; VAR res: LONGINT);
CONST Size = 32;
VAR buf1, buf2: ARRAY Size*BS OF CHAR; r: Files.Rider; n, num, i: LONGINT;
BEGIN
	ASSERT(dev.blockSize = BS);
	f.Set(r, 0); num := (f.Length()+BS-1) DIV BS;
	LOOP
		IF num <= 0 THEN EXIT END;
		f.ReadBytes(r, buf1, 0, Size*BS);
		n := Size*BS - r.res;
		WHILE n MOD BS # 0 DO buf1[n] := 0X; INC(n) END;
		ASSERT((n > 0) & (n <= num*BS));
		dev.Transfer(AosDisks.Read, pos, n DIV BS, buf2, 0, res);
		IF res # AosDisks.Ok THEN EXIT END;
		i := 0;
		WHILE i # n DO
			IF buf1[i] # buf2[i] THEN res := CoreMismatch; EXIT END;
			INC(i)
		END;
		DEC(num, n DIV BS); INC(pos, n DIV BS);
		REPEAT DEC(n); sum := (sum + ORD(buf2[n])) MOD 100H UNTIL n = 0
	END;
	IF (res = AosDisks.Ok) & (sum # 0) THEN res := CoreChecksumError END;
END CheckFile;

(* Write a boot file on the specified partition. *)
PROCEDURE InitBootFile(dev: AosDisks.Device; part: LONGINT; f: Files.File; VAR res: LONGINT);
CONST Frag = 7; LoadAdr = 1000H; StartAdr = 1000H; Frags = 1;
VAR config: Configuration; i, tsize, reserved, fsOfs, sum, start: LONGINT; data: ARRAY 12+8*Frags OF CHAR;
BEGIN
	NEW(config);
	config.GetTable(dev, part, res);
	IF res = AosDisks.Ok THEN
		LOOP
			i := config.FindEntry(0, Frag);
			IF i < 0 THEN EXIT END;
			config.DeleteEntry(i)
		END;
		GetVars(dev, part, tsize, reserved, fsOfs, res);
		IF res = AosDisks.Ok THEN
			start := BootLoaderSize+tsize;
			IF (fsOfs-start)*BS >= f.Length() THEN
				WriteFile(f, dev, dev.table[part].start + start, sum, res);
				IF res = AosDisks.Ok THEN CheckFile(f, dev, dev.table[part].start + start, sum, res) END;
				IF res = AosDisks.Ok THEN
					Put4(data, 0, LoadAdr); Put4(data, 4, Frags + ASH(sum, 16));
					Put4(data, 8, StartAdr); Put4(data, 12, 0); (* pos relative to start *)
					Put4(data, 16, (f.Length()+BS-1) DIV BS);
					config.AddEntry(Frag, LEN(data), data);
					config.PutTable(dev, part, res)
				END
			ELSE
				res := NoSpaceAvailable	(* not enough space available for boot file *)
			END
		END
	END
END InitBootFile;

PROCEDURE Eject*(dev : AosDisks.Device; VAR result: ARRAY OF CHAR);
VAR msg: AosDisks.EjectMsg; res : LONGINT; temp: ARRAY 256 OF CHAR;
BEGIN
	ASSERT(dev#NIL);
	COPY (dev.name, result);
	dev.Handle(msg, res);
	IF res = AosDisks.Ok THEN
		Strings.Append(result, " ejected");
	ELSE
		GetErrorMsg(" ejection failed: ", res, temp); Strings.Append(result, temp);
	END;
END Eject;

PROCEDURE ShowAosFSLimits*;
CONST Unit = 1024*1024*1024;
VAR string : ARRAY 32 OF CHAR;
BEGIN
	KernelLog.String("* Aos file system limits with "); KernelLog.Int(AosSS, 0); KernelLog.String(" byte sectors:"); KernelLog.Ln;
	Strings.FloatToStr( 1.0D0*MAX(LONGINT)/Unit, 1, 2, 0, string);
	KernelLog.String(" "); KernelLog.String(string); KernelLog.String(" Gb positioning limit in file because of 31 bit Set & Pos parameters"); KernelLog.Ln;
	Strings.FloatToStr(((1.0D0*AosXS*AosXS+AosSTS)*AosSS-AosHS)/Unit, 1, 2, 0, string);
	KernelLog.String(" "); KernelLog.String(string); KernelLog.String(" Gb file size limit because of triple index structure"); KernelLog.Ln;
	Strings.FloatToStr(1.0D0*MAX(LONGINT)/AosSF*AosSS/Unit, 1, 2, 0, string);
	KernelLog.String(" "); KernelLog.String(string); KernelLog.String(" Gb volume size limit because of sector factor"); KernelLog.Ln;
	Strings.FloatToStr((1.0D0*MAX(LONGINT)+1)*AosSS/Unit, 1, 2, 0, string);
	KernelLog.String(" "); KernelLog.String(string); KernelLog.String(" Gb file size limit because of 31 bit apos field"); KernelLog.Ln;
END ShowAosFSLimits;

(* Helper procedures *)

PROCEDURE IsMBR(CONST mbr : Block) : BOOLEAN;
BEGIN
	RETURN ((mbr[510] = 55X) & (mbr[511] = 0AAX));
END IsMBR;

PROCEDURE IsEPBR(CONST epbr : Block) : BOOLEAN;
VAR i : LONGINT; result : BOOLEAN;
BEGIN
	result := ((epbr[510] = 055X) & (epbr[511] = 0AAX)); (* EPBR signature *)
	FOR i := 1DEH TO 1DEH+31 DO (* last two slots should be zero *)
		IF epbr[i]#0X THEN result := FALSE; END;
	END;
	RETURN result;
END IsEPBR;

PROCEDURE SlotEmpty(CONST slot : ARRAY OF CHAR) : BOOLEAN;
VAR result : BOOLEAN; i : LONGINT;
BEGIN
	result := TRUE;
	IF LEN(slot)#16 THEN RETURN FALSE END;
	FOR i := 0 TO 15 DO
		IF slot[i]#0X THEN result := FALSE END;
	END;
	RETURN result;
END SlotEmpty;

PROCEDURE FillinSlot(disk : Disk; partition : LONGINT; VAR bootrecord : Block; slot, type, start, size : LONGINT) : BOOLEAN;
VAR spt, hds, end, t : LONGINT;
BEGIN
	ASSERT((slot = Slot1) OR (slot = Slot2) OR (slot = Slot3) OR (slot = Slot4)); ASSERT(disk.gres=AosDisks.Ok);
	spt := disk.geo.spt; hds := disk.geo.hds;
	INC(size, (-(start+size)) MOD (hds*spt)); (* round end up to cylinder boundary *)
	IF size > disk.table[partition].size THEN size := disk.table[partition].size END; (* clip size down to max *)
	IF size >= MinPartSize THEN (* create the entry *)
		end := start + size - 1;
		bootrecord[slot] := 0X; (* not bootable *)
		bootrecord[slot+1] := CHR((start DIV spt) MOD hds);
		t := start DIV (spt*hds);
		IF t > 1023 THEN t := 1023 END;
		bootrecord[slot+2] := CHR(ASH(ASH(t, -8), 6) + (start MOD spt) + 1);
		bootrecord[slot+3] := CHR(t MOD 256);
		bootrecord[slot+4] := CHR(type);
		bootrecord[slot+5] := CHR((end DIV spt) MOD hds);
		t := end DIV (spt*hds);
		IF t > 1023 THEN t := 1023 END;
		bootrecord[slot+6] := CHR(ASH(ASH(t, -8), 6) + (end MOD spt) + 1);
		bootrecord[slot+7] := CHR(t MOD 256);
		Put4(bootrecord, slot+8, start);
		Put4(bootrecord, slot+12, size);
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END FillinSlot;

(* Returns TRUE if partition type is extended partition type *)
PROCEDURE IsExtendedPartition(type: LONGINT): BOOLEAN;
BEGIN
	RETURN (type = 5) OR (type = 15);
END IsExtendedPartition;

PROCEDURE IsNativeType*(type: LONGINT) : BOOLEAN;
BEGIN
	RETURN (type = NativeType1) OR (type = NativeType2) OR (type = AosType)
END IsNativeType;

PROCEDURE IsFatType*(type : LONGINT) : BOOLEAN;
BEGIN
	RETURN (type = 4) OR (type = 6) OR (type = 0EH) OR (type = 1) OR (type = 0BH) OR (type = 0CH);
END IsFatType;

PROCEDURE IsPartitioned(dev : AosDisks.Device) : BOOLEAN;
BEGIN
	RETURN (dev # NIL) & (dev.table # NIL) & (dev.table[0].flags * {AosDisks.Valid} # {});
END IsPartitioned;

(* Decide heuristically which BIOS drive number to use when booting from the specified device. *)
PROCEDURE GetDriveNum*(dev: AosDisks.Device): CHAR;
VAR d: CHAR;
BEGIN
	(* for removable media, assume the BIOS drive number is 0H, otherwise 80H. *)
	(* The caller has opened the device, so IsPartitioned can access the partition table. *)
	IF ~IsPartitioned(dev) & (AosDisks.Removable IN dev.flags) THEN d := 0X ELSE d := 80X END;
	RETURN d
END GetDriveNum;

PROCEDURE Put2*(VAR b: ARRAY OF CHAR; i, val: LONGINT);
BEGIN
	ASSERT((val >= 0) & (val < 10000H));
	b[i] := CHR(val MOD 100H);
	b[i+1] := CHR(ASH(val, -8) MOD 100H);
END Put2;

PROCEDURE Put4*(VAR b: ARRAY OF CHAR; i, val: LONGINT);
BEGIN
	b[i] := CHR(val MOD 100H);
	b[i+1] := CHR(ASH(val, -8) MOD 100H);
	b[i+2] := CHR(ASH(val, -16) MOD 100H);
	b[i+3] := CHR(ASH(val, -24) MOD 100H);
END Put4;

PROCEDURE Get2*(CONST b: ARRAY OF CHAR; i: LONGINT): LONGINT;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8);
END Get2;

PROCEDURE Get4*(CONST b: ARRAY OF CHAR; i: LONGINT): LONGINT;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8) + ASH(ORD(b[i+2]), 16) + ASH(ORD(b[i+3]), 24);
END Get4;

(* Write partition type *)
PROCEDURE WriteType*(type: LONGINT; VAR s : ARRAY OF CHAR; VAR color : LONGINT);
CONST
	ColorFAT12 = WMGraphics.Red;
	ColorFAT16 = WMGraphics.Red;
	ColorFAT32 = WMGraphics.Red;
	ColorOberon = WMGraphics.Blue;
	ColorDefault = WMGraphics.Black;
	ColorExtended = WMGraphics.White;
BEGIN
	(* list from Linux fdisk, Microsoft Partitioning Summary (Q69912), Hal Landis' list & Jacques Eloff, http://home.global.co.za/~eloffjl/parcodes.html *)
	color := ColorDefault;
	CASE type OF
		|001H: s := "DOS FAT12"; color := ColorFAT12;
		|002H: s := "Xenix root"
		|003H: s := "Xenix usr"
		|004H: s := "DOS FAT16 < 32M"; color := ColorFAT16;
		|005H: s := "Extended"; color := ColorExtended;
		|006H: s := "DOS FAT16 >= 32M"; color := ColorFAT16;
		|007H: s := "NTFS, HPFS, QNX, Adv. Unix"
		|008H: s := "AIX boot, SplitDrive, QNX qny"
		|009H: s := "AIX data, Coherent swap, QNX qnz"
		|00AH: s := "OS/2 BM, Coherent swap"
		|00BH: s := "Win 95/98, FAT32"; color := ColorFAT32;
		|00CH: s := "Win 95/98, FAT32 LBA"; color := ColorFAT32;

		|00EH: s := "DOS FAT16 LBA"; color := ColorFAT16;
		|00FH: s := "Extended LBA"; color := ColorExtended;
		|010H: s := "Opus"
		|011H: s := "OS/2 BM: Hidden FAT12"
		|012H: s := "Xenix, SCO, Compaq diag."
		|013H: s := "Xenix, SCO"
		|014H: s := "OS/2 BM: Hidden FAT16 < 32M"

		|016H: s := "OS/2 BM: Hidden FAT16 >= 32M"
		|017H: s := "OS/2 BM: Hidden IFS"
		|018H: s := "AST Windows"
		|019H: s := "Interactive Unix, SCO"

		|024H: s := "NEC DOS"
		|028H..029H: s := "THEOS"

		|038H..039H: s := "THEOS"

		|03CH: s := "PQMagic recovery"

		|040H: s := "Venix 80286"
		|041H: s := "Linux/Minix, DR-DOS"
		|042H: s := "SFS, Linux swap, DR-DOS"
		|043H: s := "Linux fs, DR-DOS"

		|04CH: s := "Native Oberon, Aos"; color := ColorOberon;
		|04DH: s := "Switcherland or QNX Posix"
		|04EH: s := "Active or QNX Posix"
		|04FH: s := "Native Oberon or QNX Posix"
		|050H: s := "Native Oberon alt. or Lynx RTOS, DM"
		|051H: s := "Novell Netware, Ontrack Ext, DM6 Aux 1"
		|052H: s := "Microport SysV/AT, CP/M"
		|053H: s := "DM6 Aux 3"
		|054H: s := "NTFS, DM6"
		|055H: s := "EZ-Drive, DM"
		|056H: s := "Golden Bow, DM"

		|05CH: s := "Priam EDisk, DM"
		|05DH..05EH: s := "QNX"

		|061H: s := "SpeedStor"
		|062H: s := "Pick"
		|063H: s := "GNU HURD, Mach, Sys V/386, ISC UNIX"
		|064H: s := "Novell Netware 286"
		|065H: s := "Novell Netware 386"
		|066H..69H: s := "Novell Netware"
		|070H: s := "Disk Secure Multi-Boot"

		|072H: s := "Pick"
		|073H: s := "Unix, SCO"
		|074H: s := "Novell Netware"
		|075H: s := "PC/IX"

		|077H..079H: s := "QNX 4.x"
		|080H: s := "Minix <= 1.4a"
		|081H: s := "Minix > 1.4b, old Linux, Mitax DM"
		|082H: s := "Linux swap"
		|083H: s := "Linux fs"
		|084H: s := "OS/2 Hidden C: drive"
		|085H: s := "Linux ext"
		|086H..087H: s := "NTFS volume"

		|093H..094H: s := "Amoeba"

		|0A0H: s := "IBM Thinkpad hibernation"

		|0A5H: s := "BSD i386"

		|0A7H: s := "NeXTSTEP 486"

		|0B5H: s := "FreeBSD"

		|0B7H: s := "BSDI fs"
		|0B8H: s := "BSDI swap"

		|0C0H: s := "CTOS"
		|0C1H: s := "DRDOS/sec FAT12"

		|0C4H: s := "DRDOS/sec FAT16 < 32M"
		|0C6H: s := "DRDOS/sec FAT16 >= 32M"
		|0C7H: s := "Syrinx"

		|0CBH: s := "CP/M, DR"

		|0CDH: s := "CTOS, Mem"

		|0D0H: s := "CTOS"

		|0DBH: s := "CP/M, Concurrent CP/M, DOS, CTOS"

		|0DDH: s := "CTOS, Mem"

		|0DFH: s := "Datafusion"

		|0E1H: s := "DOS access, SpeedStor FAT12 ext"
		|0E2H: s := "Gneiss"
		|0E3H: s := "DOS R/O, SpeedStor, Oberon old"
		|0E4H: s := "SpeedStor FAT16 ext"

		|0F1H: s := "SpeedStor"
		|0F2H: s := "DOS 3.3 secondary"

		|0F4H: s := "SpeedStor large"

		|0FEH: s := "SpeedStor > 1024 cyl, LANstep"
		|0FFH: s := "Xenix BBT"
		|WholeDisk: s := "Whole disk"; color := WMGraphics.RGBAToColor(200,200,200,255);
		|-1: s := "Unallocated"; color := WMGraphics.RGBAToColor(200,200,200,255);
		|-2: s := "Reserved"	(* boot records, alignment, test track *)
		ELSE s := "Unknown"
	END;
END WriteType;

PROCEDURE GetErrorMsg*(CONST msg: ARRAY OF CHAR; res: LONGINT; VAR string: ARRAY OF CHAR);
VAR temp : ARRAY 32 OF CHAR;
BEGIN
	IF res = AosDisks.MediaChanged THEN string := " (res: media changed)";
	ELSIF res = AosDisks.WriteProtected THEN string := " (res: write-protected)";
	ELSIF res = AosDisks.Unsupported THEN string := " (res: unsupported)";
	ELSIF res = AosDisks.DeviceInUse THEN string := " (res: device in use)";
	ELSIF res = AosDisks.MediaMissing THEN string := " (res: no media)";
	ELSIF res = NoSpaceAvailable THEN string := " (res: no space for bootfile)";
	ELSE
		string := " (error:  ";Strings.IntToStr(res, temp); Strings.Append(string, temp); Strings.Append(string, ")");
	END;
END GetErrorMsg;

PROCEDURE GetTransferError*(dev: AosDisks.Device; op, start, res: LONGINT; VAR result: ARRAY OF CHAR);
VAR w : Streams.StringWriter;
BEGIN
	NEW(w, 1024);
	ASSERT((dev # NIL) & (w # NIL));
	CASE op OF
		AosDisks.Read: w.String("Read")
		|AosDisks.Write: w.String("Write")
	ELSE
		w.String("I/O")
	END;
	w.String(" on "); w.String(dev.name); w.String(" : "); w.Int(start, 1); w.String(" failed, ");
	GetErrorMsg("", res, result); w.String (result);
	w.Get(result);
END GetTransferError;

PROCEDURE WriteK*(w: Streams.Writer; k: LONGINT);
VAR suffix: CHAR;
BEGIN
	IF k < 10*1024 THEN suffix := "K"
	ELSIF k < 10*1024*1024 THEN suffix := "M"; k := k DIV 1024
	ELSE suffix := "G"; k := k DIV (1024*1024)
	END;
	w.Int(k, 0); w.Char(suffix); w.Char("B");
END WriteK;

PROCEDURE SetBootLoaderFile*(context: Commands.Context);
VAR file: Files.File;fileName: Files.FileName;
BEGIN
	IF context.arg.GetString(fileName) THEN
		file := Files.Old(fileName);
		IF file # NIL THEN
			BootLoaderSize := (file.Length()-1) DIV BS + 1;
			COPY(fileName, BootLoaderName);
			context.out.String("PartitionsLib.BootLoaderName = "); context.out.String(BootLoaderName); context.out.Ln;
			context.out.String("PartitionsLib.BootLoaderSize ="); context.out.Int(BootLoaderSize,1);context.out.Ln;
		ELSE
			context.error.String("File not present:"); context.error.String(fileName); context.error.Ln;
		END;
	ELSE
		context.error.String("No file name specified.");  context.error.Ln;
	END;
END SetBootLoaderFile;


PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	operations.Finalize; operations := NIL;
	diskModel.Finalize; diskModel := NIL;
END Cleanup;

BEGIN
	safe := TRUE;
	NEW(diskModel); NEW(operations); NEW(infobus);
	Modules.InstallTermHandler(Cleanup);
	BootLoaderSize := 4;
	BootLoaderName := "OBL.Bin";
END PartitionsLib.

SystemTools.Free PartitionsLib ~