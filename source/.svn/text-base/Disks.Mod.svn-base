(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Disks; (** AUTHOR "pjm"; PURPOSE "Abstract disk driver"; *)

IMPORT SYSTEM, KernelLog, Modules, Plugins;

CONST
	Read* = 0; Write* = 1;	(** Device.Transfer.op *)

		(** res parameter *)
	Ok* = 0;	(** no error *)

		(** common errors - a device may also return its own error codes > 0 *)
	MediaChanged* = 2501;	(** media in removable device was changed unexpectedly *)
	WriteProtected* = 2502;	(** write failed because media is write-protected *)
	Unsupported* = 2503;	(** operation is currently not supported on this device *)
	DeviceInUse* = 2504;	(** the device is open (UpdatePartitionTable) *)
	MediaMissing* = 2505;	(** the device media is not present *)

		(** Device.flags *)
	ReadOnly* = 0;	(** the current media can not be written to (flags only valid after Open) *)
	Removable* = 1;	(** the device has removable media *)

		(** Partition.flags *)
	Mounted* = 0;	(** a file system is currently mounted on the partition (set by file system implementations) *)
	Primary* = 1;	(** a primary partition *)
	Boot* = 2;	(** a bootable partition *)
	Valid* = 3;	(** media contains a valid partition table. *)

	BS = 512;	(* default block size *)

	Trace = FALSE;
	TraceBoot = FALSE;

	Stats* = TRUE;

TYPE
	Message* = RECORD END;

	Partition* = RECORD
		type*: LONGINT;	(** partition type *)
		start*, size*: LONGINT;	(** start block and size of partition in blocks *)
		flags*: SET;	(** Mounted, Primary, Boot, Valid *)
		ptblock*: LONGINT;	(** block containing partition table entry *)
		ptoffset*: LONGINT;	(** offset in partition table of entry, 0 if unknown *)
	END;
	PartitionTable* = POINTER TO ARRAY OF Partition;

(** The base for block devices. It provides operations on an abstract array of disk blocks of blockSize bytes, numbered from 0 to size-1. If applicable, a PC-format partition table starts at block 0, and can be read into the table field with Open or UpdatePartitionTable. *)

	Device* = OBJECT (Plugins.Plugin)	(** fields read-only, initialized by extender *)
		VAR
			blockSize*: LONGINT;	(** in bytes - unit of block, num & size parameters *)
			flags*: SET;	(** ReadOnly, Removable *)
			table*: PartitionTable;	(** cache for partition table *)
			openCount*: LONGINT;	(** number of times device has been opened *)

			(** statistics *)
			NbytesRead*, NbytesWritten*, (** successfully tranfered bytes *)
			NnofReads*, NnofWrites*, NnofOthers*, (** operation count *)
			NnofErrors* : HUGEINT; (** read/write errors *)

		PROCEDURE Transfer*(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN
			res := Unsupported
		END Transfer;

		PROCEDURE GetSize*(VAR size, res: LONGINT);
		BEGIN
			res := Unsupported
		END GetSize;

		PROCEDURE Handle*(VAR msg: Message;  VAR res: LONGINT);
		BEGIN
			res := Unsupported
		END Handle;

		(** Open the device and increment its open count if successful. If the device is opened for the first time, lock it and update its partition table. *)

		PROCEDURE Open*(VAR res: LONGINT);
		VAR lockMsg: LockMsg; unlockMsg: UnlockMsg; ignore: LONGINT;
		BEGIN
			res := Ok;
			IF openCount = 0 THEN
				Handle(lockMsg, res);
				IF TraceBoot THEN
					KernelLog.Enter; KernelLog.String("LockMsg = "); KernelLog.Int(res, 1); KernelLog.Exit
				END;
				IF (res = Ok) OR (res = Unsupported) THEN
					UpdatePartitionTable(SELF, res);
					IF res # Ok THEN Handle(unlockMsg, ignore) END
				END
			END;
			IF res = Ok THEN INC(openCount) END
		END Open;

		(** Close the device and decrement its open count. Unlock it if the open count has reached 0. *)

		PROCEDURE Close*(VAR res: LONGINT);
		VAR unlockMsg: UnlockMsg;
		BEGIN
			res := Ok; ASSERT(openCount > 0);
			DEC(openCount);
			IF openCount = 0 THEN
				Handle(unlockMsg, res);
				IF TraceBoot THEN
					KernelLog.Enter; KernelLog.String("UnlockMsg = "); KernelLog.Int(res, 1); KernelLog.Exit
				END;
				IF res = Unsupported THEN res := Ok END;
				table := NIL
			END
		END Close;

	END Device;

	EjectMsg* = RECORD (Message) END;	(** eject the media *)
	LockMsg* = RECORD (Message) END;	(** disallow manual ejection *)
	UnlockMsg* = RECORD (Message) END;	(** allow manual ejection *)
	SavePowerMsg* = RECORD (Message) END;	(** spin down the device *)
	GetGeometryMsg* = RECORD (Message)	(** return physical geometry *)
		cyls*, hds*, spt*: LONGINT
	END;
	ShutdownMsg* = RECORD (Message) END;	(** shut down the device (driver) *)

	DiskBlock = ARRAY BS OF CHAR;

VAR
	registry*: Plugins.Registry;

(** Initialize a device. Defaults: blockSize = 512, flags = {}, all methods return res = Unsupported. *)

PROCEDURE InitDevice*(d: Device);
BEGIN
	d.desc := "";
	d.blockSize := BS; d.flags := {}; d.table := NIL; d.openCount := 0
END InitDevice;

(*
Partition table starts at 01BEH in partition table sector and consists of 4 records of the type:

	00    bootind: Types.Byte;
	01    head: Types.Byte;
	02    sectorcyl: Types.Byte;
	03    cyl: Types.Byte;
	04    type: Types.Byte;
	05    head2: Types.Byte;
	06    sector2cyl: Types.Byte;
	07    cyl2: Types.Byte;
	08    start: Types.DWord;
	12    num: Types.DWord

References:
	MSKB Q69912 MS-DOS Partitioning Summary
	MSKB Q51978 Order in Which MS-DOS and Windows 95 Assigns Drive Letters
	MSKB Q151414 Windows 95 Partition Types Not Recognized by Windows NT
	MSKB Q93373 Default Drive Letters and Partitions in Windows NT
*)

PROCEDURE Resize(VAR p: PartitionTable;  n: LONGINT);
VAR old: PartitionTable;  i, len: LONGINT;
BEGIN
	len := LEN(p);  WHILE len < n DO len := 2*len END;
	old := p;  NEW(p, len);
	FOR i := 0 TO LEN(old)-1 DO p[i] := old[i] END
END Resize;

PROCEDURE Get4(VAR b: ARRAY OF CHAR;  i: LONGINT): LONGINT;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8) + ASH(ORD(b[i+2]), 16) + ASH(ORD(b[i+3]), 24)
END Get4;

PROCEDURE Extended(type: LONGINT): BOOLEAN;
BEGIN
	RETURN (type = 5) OR (type = 15)
END Extended;

PROCEDURE ValidFlag(f: CHAR): BOOLEAN;
BEGIN
	RETURN (f = 0X) OR (f = 80X) OR (f = 81X)
END ValidFlag;

(* Read primary partition table entries into p *)

PROCEDURE ReadPrimary(VAR b: DiskBlock; dev: Device;  VAR p: PartitionTable;  VAR n, res: LONGINT; VAR valid: BOOLEAN);
VAR e, size, i: LONGINT;
BEGIN
	n := 0;
	dev.Transfer(Read, 0, 1, b, 0, res);
	IF (res = Ok) & (b[510] = 055X) & (b[511] = 0AAX) THEN	(* signature ok *)
		valid := ValidFlag(b[01BEH]) & ValidFlag(b[01BEH+16]) & ValidFlag(b[01BEH+32]) & ValidFlag(b[01BEH+48]);
		IF valid THEN
			FOR i := 0 TO 3 DO
				e := 01BEH + 16*i;  size := Get4(b, e+12);
				IF (b[e+4] # 0X) & (size # 0) THEN	(* non-empty partition *)
					Resize(p, n+1);  p[n].type := ORD(b[e+4]);
					p[n].start := Get4(b, e+8);  p[n].size := size; p[n].flags := {Valid, Primary};
					IF b[e] # 0X THEN INCL(p[n].flags, Boot) END;
					p[n].ptblock := 0; p[n].ptoffset := e;
					INC(n)
				END
			END
		END
	ELSE
		IF Trace THEN
			KernelLog.String("Disks: ReadPrimary = "); KernelLog.Int(res, 1);
			KernelLog.String(" on "); KernelLog.String(dev.name); KernelLog.Ln;
			IF res = 0 THEN KernelLog.Memory(ADDRESSOF(b[0]), BS) END
		END
	END
END ReadPrimary;

(* Read "logical drive" partitions into p *)

PROCEDURE ReadLogical(VAR b: DiskBlock; dev: Device;  first: LONGINT;  VAR p: PartitionTable;  VAR n, res: LONGINT);
VAR e, sec, size, i: LONGINT; found: BOOLEAN;
BEGIN
	sec := first;
	REPEAT
		found := FALSE;
		dev.Transfer(Read, sec, 1, b, 0, res);
		IF (res = Ok) & (b[510] = 055X) & (b[511] = 0AAX) THEN
			FOR i := 0 TO 3 DO	(* look for partition entry (max one expected) *)
				e := 01BEH + 16*i;  size := Get4(b, e+12);
				IF (b[e+4] # 0X) & ~Extended(ORD(b[e+4])) & (size # 0) THEN
					Resize(p, n+1);  p[n].type := ORD(b[e+4]);
					p[n].start := sec + Get4(b, e+8);  p[n].size := size; p[n].flags := {Valid};
					IF b[e] # 0X THEN INCL(p[n].flags, Boot) END;
					p[n].ptblock := sec; p[n].ptoffset := e;
					INC(n)
				END
			END;
			i := 0;
			WHILE (i # 4) & ~found DO	(* look for nested extended entry (max one expected) *)
				e := 01BEH + 16*i;  size := Get4(b, e+12);
				IF Extended(ORD(b[e+4])) & (size # 0) THEN	(* found *)
					sec := first + Get4(b, e+8);
					i := 4;  found := TRUE
				ELSE
					INC(i)
				END
			END
		ELSE
			IF Trace THEN
				KernelLog.String("Disks: ReadLogical = ");  KernelLog.Int(res, 1);
				KernelLog.String(" on ");  KernelLog.String(dev.name);
				KernelLog.String(" sector ");  KernelLog.Int(sec, 1);  KernelLog.Ln
			END
		END
	UNTIL ~found
END ReadLogical;

(** Read a PC-format partition table starting at block 0 and initialize dev.table. dev.table[0] is a virtual
partition spanning the entire device, with type = 256. If the device has been opened before, do nothing and
return DeviceInUse, otherwise return Ok. On any other error dev.table is set NIL. *)

PROCEDURE UpdatePartitionTable*(dev: Device; VAR res: LONGINT);
VAR p, t: PartitionTable; i, pn, tn, size: LONGINT; buf: DiskBlock; valid: BOOLEAN;
BEGIN
	IF dev.openCount = 0 THEN
		tn := 0; res := Ok;
		dev.table := NIL;
		dev.GetSize(size, res);
		IF (res = Ok) & (size = 0) THEN res := MediaMissing END;	(* workaround for broken drivers *)
		IF (res = Ok) & (dev.blockSize = BS) THEN
			NEW(p, 4); NEW(t, 8);
			ReadPrimary(buf, dev, p, pn, res, valid);
			i := 0;
			WHILE valid & (i # pn) & (res = Ok) DO
				Resize(t, tn+1);  t[tn] := p[i];  INC(tn);
				IF Extended(p[i].type) THEN
					ReadLogical(buf, dev, p[i].start, t, tn, res)
				END;
				INC(i)
			END
		END;
		IF res = Ok THEN
			NEW(dev.table, tn+1);
			dev.table[0].type := 256;
			IF valid THEN dev.table[0].flags := {Valid} ELSE dev.table[0].flags := {} END;
			dev.table[0].start := 0; dev.table[0].size := size;
			FOR i := 1 TO tn DO dev.table[i] := t[i-1] END
		END
	ELSE
		res := DeviceInUse	(* could not update partition table *)
	END;
	IF TraceBoot THEN
		KernelLog.Enter; KernelLog.String("UpdatePartitionTable = "); KernelLog.Int(res, 1); KernelLog.Exit
	END
END UpdatePartitionTable;

(* Clean up the installed devices. *)
PROCEDURE Cleanup;
VAR dev: Plugins.Table; i, res: LONGINT; msg: ShutdownMsg;
BEGIN
	registry.GetAll(dev);
	IF dev # NIL THEN
		FOR i := 0 TO LEN(dev^)-1 DO
			dev[i](Device).Handle(msg, res)	(* ignore res *)
		END
	END
END Cleanup;

BEGIN
	NEW(registry, "Disks", "Disk drivers");
	Modules.InstallTermHandler(Cleanup)
END Disks.

(*
29.10.1999	pjm	Started
19.01.1999	pjm	32-bit block numbers again
22.01.1999	pjm	Hash call error in Acquire fixed
16.02.1999	pjm	LRU design error fixed
04.05.1999	pjm	Ported over new things from Native version, added partitioning
20.10.2000	pjm	Added Cleanup and Valid from Native
26.03.2007	staubesv Added Device.NnofReads, Device.NnofWrites, Device.NnofOthers and Device.NnofErrors

Block size 512 and LONGINT block number limit us to 1TB = 1024GB.
*)
