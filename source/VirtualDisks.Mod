MODULE VirtualDisks; (** AUTHOR "staubesv"; PURPOSE "Virtual disk driver"; *)
(**
 * The virtual disk driver installs disk images as virtual disk drives.
 *
 * Usage:
 *
 *	VirtualDisks.Create [Options] filename nbrOfBlocks ~ creates a empty file for being use as file disk
 *
 *	VirtualDisks.Install [Options] diskname filename  ~ installs file <filename> as file disk
 *	VirtualDisks.InstallRamdisk [Options] diskname size ~ installs and creates a ram disk
 *	VirtualDisks.Uninstall diskname ~
 *
 *	SystemTools.Free VirtualDisks ~
 *
 *)

IMPORT
	SYSTEM,
	Commands, Options, Plugins, Modules, Streams, Disks, Files, Strings;

CONST
	BlockNumberInvalid* = 101;
	ShortTransfer* = 102;

	DefaultBlocksize = 512;

TYPE

	VirtualDisk = OBJECT(Disks.Device)
	VAR
		size : LONGINT;

		(* virtual disk geometry CHS *)
		cyls, hds, spt : LONGINT;

		PROCEDURE Transfer(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF (block < 0) OR (num < 1) OR (block + num > size) THEN res := BlockNumberInvalid; RETURN; END;
			ASSERT((ofs >= 0) & (ofs + num * blockSize <= LEN(data)));
			ASSERT( num * blockSize > 0);

			TransferOperation(op, block, num, data, ofs, res);

			IF Disks.Stats THEN
				IF op = Disks.Read THEN
					INC(NnofReads);
					IF (res = Disks.Ok) THEN INC(NbytesRead, num * blockSize);
					ELSE INC(NnofErrors);
					END;
				ELSIF op = Disks.Write THEN
					INC(NnofWrites);
					IF (res = Disks.Ok) THEN INC(NbytesWritten, num * blockSize);
					ELSE INC(NnofErrors);
					END;
				ELSE
					INC(NnofOthers);
				END;
			END;
		END Transfer;

		PROCEDURE TransferOperation(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN
			HALT(301); (* abstract *)
		END TransferOperation;

		PROCEDURE GetSize(VAR size, res: LONGINT);
		BEGIN
			size := SELF.size;	res := Disks.Ok;
		END GetSize;

		PROCEDURE Handle(VAR msg : Disks.Message; VAR res : LONGINT);
		BEGIN
			IF (msg IS Disks.GetGeometryMsg) & (cyls > 0) THEN
				WITH msg: Disks.GetGeometryMsg DO
					msg.cyls := SELF.cyls; msg.hds := SELF.hds; msg.spt := SELF.spt; res := Disks.Ok
				END
			ELSE
				res := Disks.Unsupported
			END
		END Handle;

		PROCEDURE &Init(CONST name : ARRAY OF CHAR; blockSize, cyls, hds, spt : LONGINT);
		BEGIN
			SELF.blockSize := blockSize;
			SELF.cyls := cyls; SELF.hds := hds; SELF.spt := spt;
			INCL(flags, Disks.Removable);
			SetName(name);
		END Init;

	END VirtualDisk;

TYPE

	FileDisk = OBJECT(VirtualDisk)
	VAR
		file : Files.File;
		rider : Files.Rider;

		PROCEDURE TransferOperation(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN
			file.Set(rider, SYSTEM.VAL (LONGINT, block * blockSize));
			IF rider.res # Files.Ok THEN res := BlockNumberInvalid; RETURN; END;

			IF op = Disks.Read THEN
				file.ReadBytes(rider, data, ofs, num * blockSize);
				IF rider.res # 0 THEN res := ShortTransfer; ELSE res := Disks.Ok; END;
			ELSIF op = Disks.Write THEN
				file.WriteBytes(rider, data, ofs, num * blockSize);
				file.Update;
				IF rider.res # 0 THEN res := ShortTransfer; ELSE res := Disks.Ok; END;
			ELSE
				res := Disks.Unsupported;
			END;
		END TransferOperation;

		PROCEDURE &New*(file : Files.File; CONST name, filename : ARRAY OF CHAR; blockSize, cyls, hds, spt : LONGINT);
		BEGIN
			ASSERT(file # NIL);
			ASSERT(file.Length() MOD blockSize = 0);
			Init(name, blockSize, cyls, hds, spt);
			SELF.file := file;
			SELF.size := file.Length() DIV blockSize;
			desc := "Virtual Disk for file "; Strings.Append(desc, filename);
		END New;

	END FileDisk;

TYPE

	MemoryBlock = POINTER TO ARRAY OF CHAR;

	RamDisk = OBJECT(VirtualDisk)
	VAR
		memory : MemoryBlock;

		PROCEDURE TransferOperation(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN
			IF op = Disks.Read THEN
				ASSERT((block  + num) * blockSize <= LEN(memory));
				SYSTEM.MOVE(ADDRESSOF(memory[0]) + block * blockSize, ADDRESSOF(data[ofs]), num * blockSize);
				res := Disks.Ok;
			ELSIF op = Disks.Write THEN
				ASSERT((block + num) * blockSize <=LEN(memory));
				SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(memory[0]) + block * blockSize, num * blockSize);
				res := Disks.Ok;
			ELSE
				res := Disks.Unsupported;
			END;
		END TransferOperation;

		PROCEDURE &New*(memory : MemoryBlock;  CONST name : ARRAY OF CHAR; blockSize, cyls, hds, spt : LONGINT);
		BEGIN
			ASSERT(memory # NIL);
			ASSERT(LEN(memory) MOD blockSize = 0);
			Init(name, blockSize, cyls, hds, spt);
			SELF.memory := memory;
			SELF.size := LEN(memory) DIV blockSize;
			desc := "Ramdisk";
		END New;

	END RamDisk;

(** Create an empty virtual disk *)
PROCEDURE Create*(context : Commands.Context); (** [Options] filename nbrOfBlocks ~ *)
VAR
	options : Options.Options;
	filename : ARRAY 256 OF CHAR; nbrOfBlocks, blocksize : LONGINT;
	file : Files.File; rider : Files.Rider;
	buffer : POINTER TO ARRAY OF CHAR;
	i : LONGINT;
BEGIN
	NEW(options);
	options.Add("b", "blocksize", Options.Integer);
	IF options.Parse(context.arg, context.out) THEN
		context.arg.SkipWhitespace; context.arg.String(filename);
		context.arg.SkipWhitespace; context.arg.Int(nbrOfBlocks, FALSE);
		IF ~options.GetInteger("blocksize", blocksize) THEN blocksize := DefaultBlocksize; END;
		IF (filename # "") THEN
			IF (nbrOfBlocks > 0) THEN
				file := Files.New(filename);
				IF file # NIL THEN
					context.out.String("Creating virtual disk '"); context.out.String(filename); context.out.String("' ... ");
					context.out.Update;
					NEW(buffer, blocksize);
					file.Set(rider, 0);
					FOR i := 0 TO nbrOfBlocks - 1 DO
						file.WriteBytes(rider, buffer^, 0, blocksize);
						IF rider.res # 0 THEN
							context.error.String("Error: Could not write bytes to file"); context.error.Ln;
							RETURN;
						END;
					END;
					Files.Register(file);
					context.out.String("done."); context.out.Ln;
				ELSE context.error.String("Could not create file '"); context.error.String(filename); context.error.String("'"); context.error.Ln;
				END;
			ELSE context.error.String("nbrOfBlocks parameter expected."); context.error.Ln;
			END;
		ELSE context.error.String("filename parameter expected."); context.error.Ln;
		END;
	END;
END Create;

PROCEDURE GetOptions(context : Commands.Context; VAR blocksize, cylinders, heads, sectors : LONGINT) : BOOLEAN;
VAR options : Options.Options;
BEGIN
	NEW(options);
	options.Add("b", "blocksize", Options.Integer);
	options.Add("c", "cylinders", Options.Integer);
	options.Add("h", "heads", Options.Integer);
	options.Add("s", "sectors", Options.Integer);
	IF options.Parse(context.arg, context.out) THEN
		(* disk geometry in CHS *)
		IF ~options.GetInteger("blocksize", blocksize) THEN blocksize := DefaultBlocksize; END;
		IF ~options.GetInteger("cylinders", cylinders) THEN cylinders := 0; END;
		IF ~options.GetInteger("heads", heads) THEN heads := 0; END;
		IF ~options.GetInteger("sectors", sectors) THEN sectors := 0; END;
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END GetOptions;

(** Add file as virtual disk *)
PROCEDURE Install*(context : Commands.Context); (** [Options] diskname filename ~ *)
VAR
	diskname, filename : ARRAY 256 OF CHAR;
	blocksize, c, h, s, res : LONGINT;
	file : Files.File;
	disk : FileDisk;

	PROCEDURE ShowUsage(out : Streams.Writer);
	BEGIN
		out.String("VirtualDisks.Install [Options] diskname filename ~"); out.Ln;
	END ShowUsage;

BEGIN
	IF GetOptions(context, blocksize, c, h, s) THEN
		diskname := "";
		context.arg.SkipWhitespace; context.arg.String(diskname);
		filename := "";
		context.arg.SkipWhitespace; context.arg.String(filename);
		IF (diskname = "") OR (filename = "") THEN ShowUsage(context.out); RETURN; END;

		file := Files.Old(filename);
		IF file # NIL THEN
			IF file.Length() MOD blocksize # 0 THEN
				context.error.String("File size must be multiple of blocksize"); context.error.Ln;
				RETURN;
			END;
			NEW(disk, file, diskname, filename, blocksize, c, h, s);
			Disks.registry.Add(disk, res);
			IF res = Plugins.Ok THEN
				context.out.String("Disk "); context.out.String(diskname); context.out.String(" registered");
				IF (s # 0) THEN
					context.out.String(" (CHS: ");
					context.out.Int(c, 0); context.out.Char("x"); context.out.Int(h, 0); context.out.Char("x");
					context.out.Int(s, 0); context.out.Char(")");
				END;
				context.out.Ln;
			ELSE
				context.error.String("Could not register disk, res: "); context.error.Int(res, 0); context.error.Ln;
			END;
		ELSE
			context.error.String(filename); context.error.String(" not found"); context.out.Ln;
		END;
	END;
END Install;

(** Add file as virtual disk *)
PROCEDURE InstallRamdisk*(context : Commands.Context); (** [Options] diskname size  ~ *)
VAR
	diskname  : ARRAY 256 OF CHAR;
	size, blocksize, c, h, s, res : LONGINT;
	memory : MemoryBlock;
	disk : RamDisk;

	PROCEDURE ShowUsage(out : Streams.Writer);
	BEGIN
		out.String("VirtualDisks.InstallRamdisk [Options] diskname size ~"); out.Ln;
	END ShowUsage;

BEGIN
	IF GetOptions(context, blocksize, c, h, s) THEN
		diskname := "";
		context.arg.SkipWhitespace; context.arg.String(diskname);
		context.arg.SkipWhitespace; context.arg.Int(size, FALSE);
		IF (diskname = "") OR (size < 10)  THEN ShowUsage(context.out); RETURN; END;

		NEW(memory, size * blocksize);
		NEW(disk, memory, diskname, blocksize, c, h, s);
		Disks.registry.Add(disk, res);
		IF res = Plugins.Ok THEN
			context.out.String("Disk "); context.out.String(diskname); context.out.String(" registered");
			IF (s # 0) THEN
				context.out.String(" (CHS: ");
				context.out.Int(c, 0); context.out.Char("x"); context.out.Int(h, 0); context.out.Char("x");
				context.out.Int(s, 0); context.out.Char(")");
			END;
			context.out.Ln;
		ELSE
			context.error.String("Could not register disk, res: "); context.error.Int(res, 0); context.error.Ln;
		END;
	END;
END InstallRamdisk;

(** Remove virtual disk *)
PROCEDURE Uninstall*(context : Commands.Context); (** diskname ~ *)
VAR diskname : Plugins.Name; plugin : Plugins.Plugin;

	PROCEDURE IsMounted(dev: Disks.Device): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		IF dev.table # NIL THEN
			FOR i := 0 TO LEN(dev.table)-1 DO
				IF Disks.Mounted IN dev.table[i].flags THEN RETURN TRUE END
			END
		END;
		RETURN FALSE
	END IsMounted;

BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(diskname); context.out.String(diskname);
	plugin := Disks.registry.Get(diskname);
	IF plugin # NIL THEN
		IF ~IsMounted(plugin(VirtualDisk)) THEN
			Disks.registry.Remove(plugin);
			context.out.String(" removed");
		ELSE
			context.out.String(" is mounted.");
		END;
	ELSE
		context.out.String(" not found");
	END;
	context.out.Ln;
END Uninstall;

PROCEDURE Cleanup;
VAR disks : Plugins.Table; i : LONGINT;
BEGIN
	Disks.registry.GetAll(disks);
	IF (disks # NIL) THEN
		FOR i := 0 TO LEN(disks)-1 DO
			IF (disks[i] IS VirtualDisk) THEN
				Disks.registry.Remove(disks[i]);
			END;
		END;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END VirtualDisks.

VirtualDisks.Create Test.Dsk 163840 ~
VirtualDisks.Install VDISK0 Test.Dsk 512 ~
VirtualDisks.Uninstall VDISK0 ~

VirtualDisks.InstallRamdisk RAMDISK 120000 ~
VirtualDisks.Uninstall RAMDISK ~

VirtualDisks.Install AosCD.iso 2048 ~

SystemTools.Free VirtualDisks ~
