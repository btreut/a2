(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE OldDiskVolumes; (** AUTHOR "pjm"; PURPOSE "Generic disk-based volume"; *)

(* Files.Volume implementation based on Disks. *)

IMPORT SYSTEM, Machine, Plugins, Disks, Caches, Files;

CONST
	BS = 512;	(* supported device block size *)
	CDBS = 2048;	(* cd device block size *)

	SystemReserved = 32;	(* Blocks reserved for system on Boot volumes *)

	CacheSS = 4096;
	CacheHash1 = 97;
	CacheHash2 = 997;
	CacheHash3 = 3331;
	CacheHash4 = 9973;
	CacheMin = CacheHash1;

	Header = "AosDiskVolumes: ";

VAR
	cache: Caches.Cache;	(* shared cache for all volumes *)
	cacheSize, cacheHash: LONGINT;
	writeback: BOOLEAN;
	cdid: ARRAY 32 OF CHAR;

TYPE
	Volume* = OBJECT (Files.Volume)
		VAR
			dev-: Disks.Device;
			cache: Caches.Cache;	(* cache associated with volume, if any *)
			blocks: LONGINT;	(* device blocks per volume block *)
			startfs-: LONGINT;	(* device block offset of file system start *)

		(** Get block from adr [1..size] of volume vol *)
		PROCEDURE GetBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		VAR res, block: LONGINT; buf: Caches.Buffer; valid: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (adr < 1) OR (adr > size) THEN SYSTEM.HALT(15) END;
			ASSERT(startfs > 0);	(* startfs initialized *)
			ASSERT(LEN(blk) >= blockSize);	(* index check *)
			block := startfs + (adr-1) * blocks;
			IF cache # NIL THEN
				ASSERT(cache.blockSize >= blockSize);
				cache.Acquire(dev, block, buf, valid);
				IF ~valid THEN dev.Transfer(Disks.Read, block, blocks, buf.data^, 0, res)
				ELSE res := Disks.Ok
				END;
				SYSTEM.MOVE(ADDRESSOF(buf.data[0]), ADDRESSOF(blk[0]), blockSize);
				cache.Release(buf, FALSE, FALSE)
			ELSE
				dev.Transfer(Disks.Read, block, blocks, blk, 0, res)
			END;
			IF res # Disks.Ok THEN SYSTEM.HALT(17) END
		END GetBlock;

		(** Put block to adr [1..size] of volume vol *)
		PROCEDURE PutBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		VAR res, block: LONGINT; buf: Caches.Buffer; valid: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (adr < 1) OR (adr > size) THEN SYSTEM.HALT(15) END;
			ASSERT(startfs > 0);	(* startfs initialized *)
			ASSERT(LEN(blk) >= blockSize);	(* index check *)
			block := startfs + (adr-1) * blocks;
			IF cache # NIL THEN
				ASSERT(cache.blockSize >= blockSize);
				cache.Acquire(dev, block, buf, valid);
				ASSERT(LEN(buf.data) >= blockSize);	(* index check *)
				SYSTEM.MOVE(ADDRESSOF(blk[0]), ADDRESSOF(buf.data[0]), blockSize);
				IF writeback THEN
					cache.Release(buf, TRUE, FALSE)
				ELSE
					dev.Transfer(Disks.Write, block, blocks, buf.data^, 0, res);
					cache.Release(buf, TRUE, TRUE)
				END
			ELSE
				dev.Transfer(Disks.Write, block, blocks, blk, 0, res)
			END;
			IF res # Disks.Ok THEN SYSTEM.HALT(17) END
		END PutBlock;

		(** Finalize a volume and close its device. *)
		PROCEDURE Finalize*;
		VAR res, i, j: LONGINT; ptable: Disks.PartitionTable;
		BEGIN {EXCLUSIVE}
			IF cache # NIL THEN cache.Synchronize; cache := NIL END;
			i := 0; j := -1; ptable := dev.table;	(* todo: fix race! *)
			WHILE i # LEN(ptable) DO
				IF (startfs > ptable[i].start) & (startfs < ptable[i].start + ptable[i].size) THEN
					j := i
				END;
				INC(i)
			END;
			IF j # -1 THEN
				ASSERT(Disks.Mounted IN ptable[j].flags);
				EXCL(ptable[j].flags, Disks.Mounted)
			END;
			dev.Close(res);	(* ignore res *)
			dev := NIL;
			Finalize^	(* see note in AosFS *)
		END Finalize;

	END Volume;

PROCEDURE Get4(VAR b: ARRAY OF CHAR; i: LONGINT): LONGINT;
BEGIN
	RETURN ORD(b[i]) + ASH(ORD(b[i+1]), 8) + ASH(ORD(b[i+2]), 16) + ASH(ORD(b[i+3]), 24)
END Get4;

(* Get the file system parameters by reading the boot block. The pstart and psize parameters are the partition start and size in device blocks (size 512 or 2048).  The startfs parameter returns the offset of the file system from the start of the disk in device blocks.  The size parameter returns the size of the file system in volume blocks.  The vbs parameter returns the volume block size of the file system (4096 for AosFS, 2048 for NatFS). *)
PROCEDURE GetOberonFS(dev: Disks.Device; pstart, psize: LONGINT; VAR startfs, size, vbs, res: LONGINT);
CONST FSID = 21534F41H; FSVer = 1; AosSS = 4096; NSS = 2048;
VAR i, x, bc, fsofs: LONGINT; b: ARRAY CDBS OF CHAR;
BEGIN
	startfs := 0; size := 0; vbs := 0; fsofs := 0;	(* fsofs is the file system offset from the partition start in 512-byte blocks *)
	IF (dev.blockSize = BS) & (psize > 0) THEN	(* "normal" device with 512-byte blocks *)
		dev.Transfer(Disks.Read, pstart, 1, b, 0, res)	(* read boot block of partition/disk *)
	ELSIF (dev.blockSize = CDBS) & (psize > 17) THEN
		(* typically pstart = 0 *)
		dev.Transfer(Disks.Read, pstart + 17, 1, b, 0, res);	(* read El Torito boot record *)
		IF res = Disks.Ok THEN
			bc := Get4(b, 47H);	(* boot catalog location *)
			i := 0; WHILE (i < 20H) & (b[i] = cdid[i]) DO INC(i) END;
			IF (i = 20H) & (bc > 0) & (bc < psize) THEN
				dev.Transfer(Disks.Read, pstart + bc, 1, b, 0, res);	(* read boot catalog *)
				IF (b[0] = 1X) & (b[1EH] = 55X) & (b[1FH] = 0AAX) THEN	(* validation entry ok (skip checksum) *)
					x := Get4(b, 20H+8);	(* start of virtual disk *)
					IF (x > 0) & (x < psize) THEN
						dev.Transfer(Disks.Read, pstart + x, 1, b, 0, res);	(* read boot block of virtual disk *)
						fsofs := x * (CDBS DIV BS)	(* convert to 512-byte block address *)
					ELSE
						res := 3	(* not bootable CD *)
					END
				ELSE
					res := 3	(* not bootable CD *)
				END
			ELSE
				res := 3	(* not bootable CD *)
			END
		END
	ELSE
		res := 2	(* unsupported device block size *)
	END;
	IF res = Disks.Ok THEN	(* check boot sector *)
		b[0] := "x"; b[1] := "x"; b[2] := "x"; b[9] := 0X;
		IF (b[510] = 55X) & (b[511] = 0AAX) THEN	(* boot sector id found *)
			ASSERT(fsofs >= 0);
			IF (Get4(b, 1F8H) = FSID) & (b[1FCH] = CHR(FSVer)) & (ASH(1, ORD(b[1FDH])) = AosSS) THEN	(* Aos boot block id found *)
				vbs := AosSS;
				x := fsofs + Get4(b, 1F0H);	(* get offset in 512-byte blocks *)
				ASSERT(x >= 0);
				size := Get4(b, 1F4H);	(* size in volume blocks *)
				ASSERT(size >= 0);
				ASSERT(AosSS MOD dev.blockSize = 0);
				ASSERT(x + size * (AosSS DIV BS) <= psize * (dev.blockSize DIV BS));	(* range check *)
				ASSERT(x MOD (dev.blockSize DIV BS) = 0);	(* correctly aligned *)
				startfs := pstart + x DIV (dev.blockSize DIV BS)	(* offset from start of device in device blocks *)
			ELSIF b = "xxxOBERON" THEN	(* Oberon boot block id found *)
				vbs := NSS;	(* NatFS *)
				x := ORD(b[0EH]) + 256*LONG(ORD(b[0FH]));	(* reserved 512-byte blocks *)
				size := ORD(b[13H]) + 256*LONG(ORD(b[14H]));	(* small size in 512-byte blocks *)
				IF size = 0 THEN size := Get4(b, 20H) END;	(* large size in 512-byte blocks *)
				IF size > psize * (dev.blockSize DIV BS) THEN	(* limit to partition/disk size *)
					size := psize * (dev.blockSize DIV BS)
				END;
				DEC(size, x);	(* file system size in 512-byte blocks *)
				INC(x, fsofs);	(* file system offset in 512-byte blocks *)
				ASSERT(x MOD (dev.blockSize DIV BS) = 0);	(* correctly aligned *)
				startfs := pstart + x DIV (dev.blockSize DIV BS);	(* offset from start of device in device blocks *)
				size := size DIV (NSS DIV BS)	(* convert 512-byte blocks to volume blocks *)
			ELSE
				res := 1	(* unknown file system *)
			END
		ELSE
			res := 1	(* boot block id not found (unformatted?) *)
		END
	END;
	ASSERT((startfs >= 0) & (size >= 0))
END GetOberonFS;

PROCEDURE InitCache;
VAR i: LONGINT; str: ARRAY 16 OF CHAR;
BEGIN
	IF cache = NIL THEN
		Machine.GetConfig("CacheSize", str);
		i := 0; cacheSize := Machine.StrToInt(i, str);
		IF cacheSize # 0 THEN
			writeback := cacheSize < 0;
			cacheSize := ABS(cacheSize);
			IF cacheSize < CacheMin THEN cacheSize := CacheMin END;
			IF cacheSize >= CacheHash4 THEN cacheHash := CacheHash4
			ELSIF cacheSize >= CacheHash3 THEN cacheHash := CacheHash3
			ELSIF cacheSize >= CacheHash2 THEN cacheHash := CacheHash2
			ELSE cacheHash := CacheHash1
			END;
			NEW(cache, CacheSS, cacheHash, cacheSize)
		END
	END
END InitCache;

(* Initialize a volume.  The startfs parameter is the start offset of the file system in device blocks.  The size parameter is the volume size in volume blocks.  The vbs parameter is the size of a volume block.  The part parameter is the partition index in the ptable.  The readonly parameter specifies if the volume should be mounted read only.  If the device is read only, the volume is always mounted read only. *)
PROCEDURE InitVol(vol: Volume; startfs, size, vbs, part: LONGINT; ptable: Disks.PartitionTable; readonly: BOOLEAN);
VAR vflags: SET;
BEGIN
	vflags := {};
	IF readonly OR (Disks.ReadOnly IN vol.dev.flags) THEN INCL(vflags, Files.ReadOnly) END;
	IF Disks.Removable IN vol.dev.flags THEN INCL(vflags, Files.Removable) END;
	ASSERT(vbs MOD BS = 0);
	vol.blockSize := vbs;
	ASSERT(vbs MOD vol.dev.blockSize = 0);	(* volume block size must be multiple of device block size *)
	vol.blocks := vbs DIV vol.dev.blockSize;	(* number of device blocks in a volume block *)
	vol.Init(vflags, size, SystemReserved);	(* initialize volume free block map *)
	COPY(vol.dev.name, vol.name); Files.AppendStr("#", vol.name); Files.AppendInt(part, vol.name);
	vol.startfs := startfs;
	INCL(ptable[part].flags, Disks.Mounted);
	IF (cache = NIL) & (CacheSS >= vbs) THEN InitCache END;	(* initialize cache the first time (fixme: race) *)
	IF (cache # NIL) & (cache.blockSize >= vbs) THEN vol.cache := cache ELSE vol.cache := NIL END
END InitVol;

(* Try to open the specified volume.  Sets p.vol # NIL on success. *)

PROCEDURE TryOpen(context: Files.Parameters; dev: Disks.Device; part, dbs: LONGINT; readonly: BOOLEAN);
VAR vol: Volume; startfs, size, vbs, res: LONGINT; ptable: Disks.PartitionTable;
BEGIN
	context.out.String(Header); context.out.String(dev.name);
	context.out.Char("#"); context.out.Int(part, 1); context.out.Char(" ");
	dev.Open(res);
	IF res = Disks.Ok THEN
		ptable := dev.table;
		IF ((LEN(ptable) = 1) & (part = 0)) OR ((part > 0) & (part < LEN(ptable))) THEN
			IF (dbs = -1) OR (dev.blockSize = dbs) THEN
				IF ~(Disks.Mounted IN ptable[part].flags) THEN
					GetOberonFS(dev, ptable[part].start, ptable[part].size, startfs, size, vbs, res);
					IF (res = Disks.Ok) & (size > 0) & (vbs MOD dev.blockSize = 0) THEN
						NEW(vol); vol.dev := dev;
						InitVol(vol, startfs, size, vbs, part, ptable, readonly);
						context.vol := vol
					ELSE
						CASE res OF
							|1: context.error.String(" partition not formatted")
							|2: context.error.String(" bad block size")
							|3: context.error.String(" not bootable CD")
						ELSE
							context.error.String(" boot block error "); context.error.Int(res, 1);
							context.error.String(" startfs="); context.error.Int(startfs, 1);
							context.error.String(" size="); context.error.Int(size, 1);
							context.error.String(" vbs="); context.error.Int(vbs, 1);
							context.error.String(" start="); context.error.Int(ptable[part].start, 1);
						END;
						context.error.Ln;
					END
				ELSE context.error.String(" already mounted"); context.error.Ln;
				END
			ELSE context.error.String(" wrong block size"); context.error.Ln;
			END
		ELSE context.error.String(" invalid partition"); context.error.Ln;
		END;
		IF context.vol = NIL THEN
			dev.Close(res)	(* close again - ignore res *)
		END
	ELSE
		context.error.String(" error "); context.error.Int(res, 1); context.error.Ln;
	END
END TryOpen;

(** Generate a new disk volume object. Files.Par: [device] ["#" part] [",R"] *)
PROCEDURE New*(context : Files.Parameters);
VAR
	name: Plugins.Name; part, i: LONGINT;
	options : ARRAY 8 OF CHAR; ch : CHAR;
	table: Plugins.Table; readonly, retry: BOOLEAN;
BEGIN
	context.vol := NIL; retry := FALSE;
	Files.GetDevPart(context.arg, name, part);

	(* read optional parameter *)
	context.arg.SkipWhitespace; ch := context.arg.Peek();
	IF (ch = ",") THEN context.arg.String(options); END;
	readonly := options = ",R";

	Disks.registry.GetAll(table);
	IF table # NIL THEN
		IF name # "" THEN
			i := 0; WHILE (i # LEN(table)) & (table[i].name # name) DO INC(i) END;
			IF i # LEN(table) THEN
				TryOpen(context, table[i](Disks.Device), part, -1, readonly)
			ELSE
				context.error.String(Header); context.error.String(name); context.error.String(" not found"); context.error.Ln;
			END
		ELSE
			i := 0;
			LOOP
				TryOpen(context, table[i](Disks.Device), part, CDBS, readonly);
				INC(i);
				IF (context.vol # NIL) OR (i >= LEN(table)) THEN EXIT END;
			END
		END
	ELSE
		context.error.String(Header); context.error.String("no devices"); context.error.Ln;
	END;
END New;

BEGIN
	cdid := "?CD001?EL TORITO SPECIFICATION?";
	cdid[0] := 0X; cdid[6] := 1X; cdid[30] := 0X; cdid[31] := 0X;
	cache := NIL; writeback := FALSE
END OldDiskVolumes.

(*
to do:
o fix races here, so that concurrent tools other than OFSTools and AosConsole can be used for mounting
o do not HALT blindly when drivers returns a bad res
*)
