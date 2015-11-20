(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE FATVolumes; (** AUTHOR "be"; PURPOSE "FAT file system volumes" *)

(* Files.Volume implementation for [V]FAT volumes based on Disks *)

IMPORT SYSTEM, Kernel, Plugins, Streams, Disks, Files, Strings, KernelLog;

CONST
	Ok*	= Disks.Ok;
	BS*	= 512; (** supported block size *)

	ErrReadOnly* = 2901;
	ErrDiskFull* = 2902;
	ErrInvalidParams* = 2903;
	ErrIOError* = 2904;

	Override = 3;	(* volume property flag *)

	FREE* = 0;
	EOC* = -1;
	BAD* = -2;
	IOERROR* = -3;

	(* Cache *)
	FAT* = 0;
	Data* = 0;

	FATCacheEnabled = TRUE;
	FATCacheSize = 127;
	FATWriteBehind = TRUE;
	DfltDataCacheSize = 256;	(* default # of data cache blocks that are allocated for every mounted FAT volume, unless otherwise specified *)
	CacheUpdateTime = 5*1000;	(* ms *)

TYPE
	Address = Files.Address;
	BPB = ARRAY BS OF CHAR;

	CacheElement = RECORD
		adr: Address;
		valid, dirty: BOOLEAN;
	END;

	Cache = POINTER TO RECORD
		data: POINTER TO ARRAY OF CHAR;
		index: POINTER TO ARRAY OF CacheElement;
		startAdr: LONGINT; dataAdr: ADDRESS;
		blockSize, numBlocks: LONGINT;
		writeBehind, dirty: BOOLEAN;
	END;

	Volume* = OBJECT(Files.Volume)
		VAR
			dev-: Disks.Device;
			start-,	(* first sector of partition *)
			startFAT-, (* first sector of the first FAT copy  *)
			endFAT-,	(* last sector of FAT area (includes root directory on FAT12/FAT16 volumes *)
			startData-,	(* first physical sector of cluster 0 (although clusters 0 and 1 do not exist) *)
			maxClusters-,	(* total number of clusters. First data cluster = 2, last data cluster = maxClusters+1 *)
			freeCluster: Address;	(* # of cluster where search for free clusters begins *)
			freeCount,	(* # of free clusters, -1 if unknown *)
			sectorsPC-,	(* # of sectors per cluster *)
			clusterSize-,	(* # of bytes per cluster *)
			fatSize-,	(* # of sectors occupied by one FAT *)
			numFATs-: LONGINT;	(* # of FAT copies *)
			ioError: BOOLEAN;
			label: ARRAY 12 OF CHAR;	(* volume label *)
			unsafe*, quit, syncNow, dead: BOOLEAN;
			fatCache, dataCache: Cache;
			timer: Kernel.Timer;
			NreadSector*, NwriteSector*, NreadCluster*, NwriteCluster*, NreadFAT*, NwriteFAT*, NallocCluster*: LONGINT;	(* stats *)

		PROCEDURE Init*(flags: SET; size, reserved: LONGINT);
		BEGIN HALT(301)	(* abstract *)
		END Init;

		PROCEDURE AllocBlock(hint: Address; VAR adr: Address);
		BEGIN HALT(301) (* not available on FAT volumes *)
		END AllocBlock;

		PROCEDURE FreeBlock(adr: Address);
		BEGIN HALT(301) (* not available on FAT volumes *)
		END FreeBlock;

		PROCEDURE MarkBlock(adr: Address);
		BEGIN HALT(301) (* not available on FAT volumes *)
		END MarkBlock;

		PROCEDURE Marked(adr: Address): BOOLEAN;
		BEGIN HALT(301) (* not available on FAT volumes *)
		END Marked;

		PROCEDURE Initialize(VAR bpb: BPB; MaxClusters: LONGINT): BOOLEAN;
		BEGIN (* must be exclusive in overridden methods *)
			(* check BPB signature *)
			IF ~((bpb[510]=055X) & (bpb[511]=0AAX)) THEN RETURN FALSE END;
			IF ~(((bpb[0] = 0EBX) & (bpb[2] = 090X)) OR (bpb[0] = 0E9X)) THEN RETURN FALSE END;

			sectorsPC := ORD(bpb[13]);
			numFATs := ORD(bpb[16]);
			startFAT := GetUnsignedInteger(bpb, 14);
			maxClusters := MaxClusters;
			clusterSize := sectorsPC * BS;
			unsafe := FALSE; quit := FALSE; syncNow := FALSE;
			fatCache := NIL;
			dataCache := NIL;
			NreadSector := 0; NwriteSector := 0; NreadCluster := 0; NwriteCluster := 0; NallocCluster := 0; NreadFAT := 0; NwriteFAT := 0;
			RETURN TRUE
		END Initialize;

		(** This procedure is intended to provide low level access to FAT volume objects to disk utilities.
			Don't use it for mounting volumes! Initialise should be called before calling this procedure *)
		PROCEDURE InitLowLevel*(bpbin : ARRAY OF CHAR; numClusters : LONGINT; dev : Disks.Device; start, size, blockSize : LONGINT) : BOOLEAN;
		VAR bpb : BPB;
		BEGIN
			ASSERT((LEN(bpbin)=512) & (bpbin[510]=055X) & (bpbin[511]=0AAX));
			SYSTEM.MOVE(ADDRESSOF(bpbin[0]), ADDRESSOF(bpb[0]), 512);
			SELF.dev := dev; SELF.start := start; SELF.size := size; SELF.blockSize := BS;
			flags := {};
			IF Initialize(bpb, numClusters) THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END InitLowLevel;

		PROCEDURE Finalize;
		VAR i, j, res: LONGINT; ptable: Disks.PartitionTable;
		BEGIN (* must be exclusive in overridden methods *)
			quit := TRUE;
			timer.Wakeup;
			IF (fatCache # NIL) THEN FlushCache(fatCache); fatCache := NIL END;
			IF (dataCache # NIL) THEN FlushCache(dataCache); dataCache := NIL END;
			i := 0; j := -1; ptable := dev.table;	(* todo: fix race! *)
			WHILE i # LEN(ptable) DO
				IF (start = ptable[i].start) THEN j := i END;
				INC(i)
			END;
			IF j # -1 THEN
				ASSERT(Disks.Mounted IN ptable[j].flags);
				EXCL(ptable[j].flags, Disks.Mounted)
			END;
			dev.Close(res);	(* ignore res *)
			dev := NIL;
			Finalize^	(* see note in Files *)
		END Finalize;

		PROCEDURE Available(): LONGINT;
		VAR i: Address;
		BEGIN {EXCLUSIVE}
			IF (freeCount = -1) THEN
				freeCount := 0;
				FOR i := 2 TO maxClusters+1 DO
					IF (ReadFATEntryX(i) = FREE) THEN INC(freeCount) END
				END
			END;
			RETURN freeCount*sectorsPC
		END Available;

		PROCEDURE SetCache*(CacheType, NumBlocks: LONGINT; WriteBehind: BOOLEAN);
		BEGIN
			IF (CacheType = FAT) THEN
				InitCache(fatCache, start, BS, NumBlocks, WriteBehind)
			ELSIF (CacheType = Data) THEN
				InitCache(dataCache, startData, clusterSize, NumBlocks, WriteBehind)
			END
		END SetCache;

		PROCEDURE InitCache(VAR cache: Cache; StartAdr, BlockSize, NumBlocks: LONGINT; WriteBehind: BOOLEAN);
		VAR i: LONGINT;
		BEGIN
			IF (cache # NIL) THEN
				IF cache.writeBehind THEN FlushCache(cache) END
			ELSIF (NumBlocks > 0) THEN
				NEW(cache)
			END;

			IF (NumBlocks > 0) THEN
				cache.startAdr := StartAdr; cache.blockSize := BlockSize;
				cache.numBlocks := NumBlocks; cache.writeBehind := WriteBehind;

				NEW(cache.data, BlockSize*NumBlocks); cache.dataAdr := ADDRESSOF(cache.data[0]);
				NEW(cache.index, NumBlocks);

				FOR i := 0 TO NumBlocks-1 DO
					cache.index[i].adr := -1;
					cache.index[i].valid := FALSE;
					cache.index[i].dirty := FALSE
				END
			END
		END InitCache;

		PROCEDURE FlushCache(cache: Cache);
		VAR i, firstDirty, lastDirty, adr, num, ofs, res: LONGINT; start: LONGINT;
		BEGIN
			IF (cache # NIL) & cache.dirty THEN
				cache.dirty := FALSE;
				i := 0; firstDirty := -1; lastDirty := -1;
				WHILE (i < cache.numBlocks) DO
					IF (cache.index[i].dirty) THEN
						cache.index[i].dirty := FALSE;
						firstDirty := i; lastDirty := i; adr := cache.index[i].adr;
						INC(i);
						WHILE (i < cache.numBlocks) & (cache.index[i].adr = adr+1) & (cache.index[i].valid) DO
							IF cache.index[i].dirty THEN cache.index[i].dirty := FALSE; lastDirty := i END;
							INC(adr); INC(i)
						END;

						start := cache.startAdr + cache.index[firstDirty].adr*(cache.blockSize DIV BS);
						num := (cache.blockSize DIV BS)*(lastDirty-firstDirty+1);
						ofs := firstDirty*cache.blockSize;
						dev.Transfer(Disks.Write, start, num, cache.data^, ofs, res)
					ELSE
						INC(i)
					END
				END
			END
		END FlushCache;

		(** ReadSector: reads a sector from the FAT area. Use ReadCluster to read a data cluster *)
		PROCEDURE ReadSector*(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE} ReadSectorX(adr, data, 0, res)
		END ReadSector;

		PROCEDURE ReadSectorX(adr: Address; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		VAR block, idx: LONGINT;
		BEGIN
			INC(NreadSector);
			ASSERT((adr >= 0) & (adr < endFAT) & (ofs >= 0) & (LEN(data) >= ofs + BS), ErrInvalidParams);
			block := start + adr;
			IF (fatCache # NIL) THEN
				idx := adr MOD fatCache.numBlocks;
				IF (fatCache.index[idx].adr = adr) & (fatCache.index[idx].valid) THEN
					SYSTEM.MOVE(fatCache.dataAdr + idx*BS, ADDRESSOF(data[ofs]), BS);
					res := Ok
				ELSE
					IF fatCache.index[idx].dirty THEN FlushCache(fatCache) END;
					fatCache.index[idx].adr := adr; fatCache.index[idx].valid := TRUE; fatCache.index[idx].dirty := FALSE;
					dev.Transfer(Disks.Read, block, 1, fatCache.data^, idx*BS, res);
					SYSTEM.MOVE(fatCache.dataAdr + idx*BS, ADDRESSOF(data[ofs]), BS)
				END
			ELSE dev.Transfer(Disks.Read, block, 1, data, ofs, res)
			END;
			ioError := ioError OR (res # Ok)
		END ReadSectorX;

		(** WriteSector: writes a sector to the FAT area. Use WriteCluster to write a data cluster *)
		PROCEDURE WriteSector*(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE} WriteSectorX(adr, data, 0, res)
		END WriteSector;

		PROCEDURE WriteSectorX(adr: Address; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		VAR block, idx: LONGINT;
		BEGIN
			INC(NwriteSector);
			ASSERT((adr >= 0) & (adr < endFAT) & (ofs >= 0) & (LEN(data) >= ofs + BS), ErrInvalidParams);
			IF Files.ReadOnly IN flags THEN HALT(ErrReadOnly) END; (* TODO pass as res *)
			block := start + adr;
			IF (fatCache # NIL) THEN
				idx := adr MOD fatCache.numBlocks;
				IF fatCache.writeBehind & (fatCache.index[idx].adr # adr) & (fatCache.index[idx].dirty) THEN
					FlushCache(fatCache)
				END;
				fatCache.index[idx].adr := adr; fatCache.index[idx].valid := TRUE;
				fatCache.index[idx].dirty := fatCache.writeBehind; fatCache.dirty := fatCache.writeBehind;
				SYSTEM.MOVE(ADDRESSOF(data[ofs]), fatCache.dataAdr + idx*BS, BS);
				IF ~fatCache.writeBehind THEN
					dev.Transfer(Disks.Write, block, 1, data, ofs, res)
				END
			ELSE dev.Transfer(Disks.Write, block, 1, data, ofs, res)
			END;
			ioError := ioError OR (res # Ok)
		END WriteSectorX;

		PROCEDURE ReadFATEntry*(adr: Address): Address;
		BEGIN {EXCLUSIVE} RETURN ReadFATEntryX(adr)
		END ReadFATEntry;

		PROCEDURE ReadFATEntryX(adr: Address): Address;
		BEGIN HALT(301) (* abstract *)
		END ReadFATEntryX;

		PROCEDURE WriteFATEntry*(adr, link: Address; VAR res: LONGINT);
		BEGIN {EXCLUSIVE} WriteFATEntryX(adr, link, res)
		END WriteFATEntry;

		PROCEDURE WriteFATEntryX(adr, link: Address; VAR res: LONGINT);
		BEGIN HALT(301) (* abstract *)
		END WriteFATEntryX;

		(** ReadCluster: reads a cluster from the data area. Use ReadSector to read a sector from the FAT area *)
		PROCEDURE ReadCluster*(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE} ReadClusterX(adr, data, res)
		END ReadCluster;

		PROCEDURE ReadClusterX(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		VAR block, idx: LONGINT;
		BEGIN
			INC(NreadCluster);
			IF (adr < 2) OR (adr > maxClusters+1) THEN HALT(ErrInvalidParams) END;
			block := startData + (adr * sectorsPC);
			IF (dataCache # NIL) THEN
				idx := adr MOD dataCache.numBlocks;
				IF (dataCache.index[idx].adr = adr) & (dataCache.index[idx].valid) THEN
					SYSTEM.MOVE(dataCache.dataAdr + idx*clusterSize, ADDRESSOF(data[0]), clusterSize);
					res := Ok
				ELSE
					IF dataCache.index[idx].dirty THEN FlushCache(dataCache) END;
					dataCache.index[idx].adr := adr; dataCache.index[idx].valid := TRUE; dataCache.index[idx].dirty := FALSE;
					dev.Transfer(Disks.Read, block, sectorsPC, dataCache.data^, idx*clusterSize, res);
					SYSTEM.MOVE(dataCache.dataAdr + idx*clusterSize, ADDRESSOF(data[0]), clusterSize)
				END
			ELSE dev.Transfer(Disks.Read, block, sectorsPC, data, 0, res)
			END;
			ioError := ioError OR (res # Ok)
		END ReadClusterX;

		(** WriteCluster: writes a cluster to the data area. Use WriteSector to write a sector to the FAT area *)
		PROCEDURE WriteCluster*(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE} WriteClusterX(adr, data, res)
		END WriteCluster;

		PROCEDURE WriteClusterX(adr: Address; VAR data: ARRAY OF CHAR; VAR res: LONGINT);
		VAR block, idx: LONGINT;
		BEGIN
			INC(NwriteCluster);
			IF (adr < 2) OR (adr > maxClusters+1) THEN HALT(ErrInvalidParams) END;
			IF Files.ReadOnly IN flags THEN HALT(ErrReadOnly) END;
			block := startData + (adr * sectorsPC);
			IF (dataCache # NIL) THEN
				idx := adr MOD dataCache.numBlocks;
				IF dataCache.writeBehind & (dataCache.index[idx].adr # adr) & (dataCache.index[idx].dirty) THEN
					FlushCache(dataCache)
				END;
				dataCache.index[idx].adr := adr; dataCache.index[idx].valid := TRUE;
				dataCache.index[idx].dirty := dataCache.writeBehind; dataCache.dirty := dataCache.writeBehind;
				SYSTEM.MOVE(ADDRESSOF(data[0]), dataCache.dataAdr + idx*clusterSize, clusterSize);
				IF ~dataCache.writeBehind THEN
					dev.Transfer(Disks.Write, block, sectorsPC, data, 0, res)
				END
			ELSE dev.Transfer(Disks.Write, block, sectorsPC, data, 0, res)
			END;
			ioError := ioError OR (res # Ok)
		END WriteClusterX;

		PROCEDURE AllocCluster*(link: Address; VAR res: LONGINT): Address;
		VAR c, cnt, entry: Address;
		BEGIN {EXCLUSIVE}
			INC(NallocCluster);
			IF Files.ReadOnly IN flags THEN res := ErrReadOnly; RETURN BAD END;

			c := freeCluster; entry := ReadFATEntryX(c); cnt := 1;
			WHILE (entry # FREE) & (cnt <= maxClusters+1) DO
				INC(c); IF (c = maxClusters+2) THEN c := 2 END;
				INC(cnt);
				entry := ReadFATEntryX(c)
			END;

			IF (entry = FREE) THEN
				IF (link >= 2) THEN WriteFATEntryX(link, c, res)
				ELSE res := Ok
				END;
				IF (res = Ok) THEN
					WriteFATEntryX(c, EOC, res);
					IF (freeCount > 0) THEN DEC(freeCount) END;
					freeCluster := c + 1;
					IF (freeCluster = maxClusters+2) THEN freeCluster := 2 END;
					IF (res = Ok) THEN RETURN c END
				END;
				ioError := TRUE;
				res := ErrIOError
			ELSE res := ErrDiskFull
			END;
			RETURN BAD
		END AllocCluster;

		PROCEDURE FreeClusterChain*(cluster: Address; VAR res: LONGINT);
		VAR c, new: Address;
		BEGIN {EXCLUSIVE}
			c := cluster; res := Ok;
			WHILE (c >= 2) & (res = Ok) DO
				new := ReadFATEntryX(c);
				WriteFATEntryX(c, FREE, res);
				IF (freeCount > 0) THEN INC(freeCount) END;
				c := new
			END
		END FreeClusterChain;

		PROCEDURE QuickFormat*;
		VAR sec: ARRAY BS OF CHAR; i, res: LONGINT; entries: ARRAY 2 OF LONGINT;
		BEGIN {EXCLUSIVE}
			unsafe := TRUE; entries[0] := ReadFATEntryX(0);
			unsafe := TRUE; entries[1] := ReadFATEntryX(1);
			FOR i := 0 TO fatSize*numFATs-1 DO
				WriteSectorX(startFAT + i, sec, 0, res) (* ignore res *)
			END;
			unsafe := TRUE; WriteFATEntryX(0, entries[0], res);
			unsafe := TRUE; WriteFATEntryX(1, entries[1], res);
			freeCluster := 2; freeCount := maxClusters;
			InitRoot;
		END QuickFormat;

		PROCEDURE InitRoot;
		BEGIN HALT(301)
		END InitRoot;

		PROCEDURE Synchronize;
		BEGIN {EXCLUSIVE}
			IF (fatCache # NIL) THEN FlushCache(fatCache) END;
			IF (dataCache # NIL) THEN FlushCache(dataCache) END
		END Synchronize;

		PROCEDURE AwaitDeath*;
		BEGIN {EXCLUSIVE}
			AWAIT(dead)
		END AwaitDeath;

	BEGIN {ACTIVE, SAFE}
		dead := FALSE; NEW(timer);
		WHILE ~quit DO
			timer.Sleep(CacheUpdateTime);
			IF ~quit THEN Synchronize END
		END;
		dead := TRUE
	END Volume;

	FAT1216Volume* = OBJECT(Volume)
		VAR
			firstRootSector-: Address;
			numRootSectors-: LONGINT; (* first sector & number of sectors of root directory relative to start *)

		PROCEDURE Initialize(VAR bpb: BPB; MaxClusters: LONGINT): BOOLEAN;
		VAR i: LONGINT;
		BEGIN (* must be exclusive in overridden methods *)
			IF Initialize^(bpb, MaxClusters) THEN
				fatSize := GetUnsignedInteger(bpb, 22);
				firstRootSector := startFAT + (numFATs*fatSize);
				numRootSectors := (GetUnsignedInteger(bpb, 17)*32 + BS - 1) DIV BS;
				endFAT := start + firstRootSector + numRootSectors - 1;
				startData := start + firstRootSector + numRootSectors - 2*sectorsPC;
				IF (bpb[38] = 029X) THEN
					FOR i := 0 TO 10 DO label[i] := bpb[43+i] END; label[11] := 0X;
					Strings.TrimRight(label, " ")
				END;
				freeCluster := 2;
				freeCount := -1;
				RETURN TRUE
			ELSE RETURN FALSE
			END
		END Initialize;

		PROCEDURE InitRoot;
		VAR sec: ARRAY BS OF CHAR; i, res: LONGINT;
		BEGIN
			FOR i := 0 TO numRootSectors-1 DO
				WriteSectorX(firstRootSector + i, sec, 0, res) (* ignore res *)
			END;
		END InitRoot;
	END FAT1216Volume;

CONST
	fat12EOC = 0FF8H; (* end of clusterchain; test for greater or equal *)
	fat12BAD = 0FF7H; (* bad cluster *)
	fat12FREE = 0;	(* free cluster *)

TYPE
	FAT12Volume* = OBJECT(FAT1216Volume)
		PROCEDURE Initialize(VAR bpb: BPB; MaxClusters: LONGINT): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN Initialize^(bpb, MaxClusters)	(* see note in Volumes.Initialize *)
		END Initialize;

		PROCEDURE Finalize;
		BEGIN {EXCLUSIVE}
			Finalize^	(* see note in Volumes.Finalize *)
		END Finalize;

		PROCEDURE ReadFATEntryX(adr: Address): Address;
		VAR offset, res: LONGINT;
			entry: Address;
			data: ARRAY 2*BS OF CHAR;
		BEGIN
			INC(NreadFAT);
			IF ~unsafe & ((adr < 2) OR (adr > maxClusters+1)) THEN HALT(ErrInvalidParams) END;

			offset := adr + adr DIV 2;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (offset MOD BS = BS-1) & (res = Disks.Ok) THEN (* this entry spans a sector boundary *)
				ReadSectorX(startFAT + offset DIV BS + 1, data, BS, res)
			END;
			IF (res = Disks.Ok) THEN
				entry := GetUnsignedInteger(data, offset MOD BS);

				IF ODD(adr) THEN entry := LSH(entry, -4)	(* get high 12 bits *)
				ELSE entry := AND(entry, 0FFFH)	(* get low 12 bits *)
				END;

				IF ~unsafe THEN
					IF (entry >= fat12EOC) THEN entry := EOC
					ELSIF (entry = fat12BAD) THEN entry := BAD
					END
				ELSE
					unsafe := FALSE
				END
			ELSE
				entry := IOERROR; ioError := TRUE; unsafe := FALSE
			END;
			RETURN entry
		END ReadFATEntryX;

		PROCEDURE WriteFATEntryX(adr, link: Address; VAR res: LONGINT);
		VAR offset, entry: Address; i: LONGINT;
			data: ARRAY 2*BS OF CHAR;
		BEGIN
			INC(NwriteFAT);
			IF ~unsafe THEN
				IF ((adr < 2) OR (adr > maxClusters+1)) OR ((link # EOC) & (link # FREE) & ((link < 2) OR (link > maxClusters+1))) THEN
					HALT(ErrInvalidParams)
				END;

				IF (link = EOC) THEN link := fat12EOC
				ELSIF (link = BAD) THEN link := fat12BAD
				ELSIF (link = FREE) THEN link := fat12FREE
				END
			END;

			offset := adr + adr DIV 2;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (offset MOD BS = BS-1) & (res = Disks.Ok) THEN (* this entry spans a sector boundary *)
				ReadSectorX(startFAT + offset DIV BS + 1, data, BS, res)
			END;
			IF (res = Disks.Ok) THEN
				entry := GetUnsignedInteger(data, offset MOD BS);
				IF ODD(adr) THEN (* set high 12 bits, preserve low 4 bits *)
					entry := LSH(link, 4) + AND(entry, 0FH)
				ELSE (* preserve high 4 bits, set low 12 bits *)
					entry := AND(entry, 0F000H) + link
				END;
				PutUnsignedInteger(data, offset MOD BS, entry);

				FOR i := 0 TO numFATs-1 DO
					WriteSectorX(startFAT + i*fatSize + offset DIV BS, data, 0, res);
					IF (offset MOD BS = BS-1) & (res = Disks.Ok) THEN (* this entry spans a sector boundary *)
						WriteSectorX(startFAT + i*fatSize + offset DIV BS + 1, data, BS, res)
					END;
					IF (res # Disks.Ok) THEN
						res := IOERROR; ioError := TRUE
					END
				END
			ELSE
				res := IOERROR; ioError := TRUE
			END
		END WriteFATEntryX;
	END FAT12Volume;

CONST
	fat16EOC = 0FFF8H;	(* end of clusterchain; test for greater or equal *)
	fat16BAD = 0FFF7H;	(* bad cluster *)
	fat16FREE = 0H;	(* free cluster *)
	fat16CleanShutdown = {15};
	fat16IOError	= {14};
	fat16VCF = fat16CleanShutdown + fat16IOError; 	(* Volume Clean Flags *)

TYPE
	FAT16Volume* = OBJECT(FAT1216Volume)
		PROCEDURE Initialize(VAR bpb: BPB; MaxClusters: LONGINT): BOOLEAN;
		VAR vcf: SET; res: LONGINT;
		BEGIN {EXCLUSIVE}
			IF Initialize^(bpb, MaxClusters) THEN	(* see note in Volumes.Initialize *)
				unsafe := TRUE; vcf := SYSTEM.VAL(SET, ReadFATEntryX(1));
				IF (vcf * fat16VCF = fat16VCF) THEN	(* volume is clean *)
					unsafe := TRUE;
					IF ~(Files.ReadOnly IN flags) THEN WriteFATEntryX(1, SYSTEM.VAL(LONGINT, vcf - fat16CleanShutdown), res) END
				ELSE
					KernelLog.Ln; KernelLog.Enter;
					IF (Override IN flags) THEN
						KernelLog.String(" WARNING: volume was not properly unmounted; volume might be damaged !!!")
					ELSE
						INCL(flags, Files.ReadOnly);
						KernelLog.String(" volume was not properly unmounted; mounting read-only. Run Scandisk under DOS/Windows")
					END;
					KernelLog.Exit
				END;
				RETURN TRUE
			ELSE RETURN FALSE
			END
		END Initialize;

		PROCEDURE Finalize;
		VAR vcf: SET; res: LONGINT;
		BEGIN {EXCLUSIVE}
			IF ~(Files.ReadOnly IN flags) THEN
				unsafe := TRUE; vcf := SYSTEM.VAL(SET, ReadFATEntryX(1));
				vcf := vcf + fat16CleanShutdown;
				IF ioError THEN vcf := vcf - fat16IOError ELSE vcf := vcf + fat16IOError END;
				unsafe := TRUE; WriteFATEntryX(1, SYSTEM.VAL(LONGINT, vcf), res) (* ignore res *)
			END;
			Finalize^ (* see note in Volume.Finalize *)
		END Finalize;

		PROCEDURE ReadFATEntryX(adr: Address): Address;
		VAR offset, entry: Address;
			res: LONGINT;
			data: ARRAY BS OF CHAR;
		BEGIN
			INC(NreadFAT);
			IF ~unsafe & ((adr < 2) OR (adr > maxClusters+1)) THEN HALT(ErrInvalidParams) END;

			offset := adr*2;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (res = Disks.Ok) THEN
				entry := GetUnsignedInteger(data, offset MOD BS);
				IF ~unsafe THEN
					IF (entry >= fat16EOC) THEN entry := EOC
					ELSIF (entry = fat16BAD) THEN entry := BAD
					END
				ELSE
					unsafe := FALSE
				END
			ELSE
				entry := IOERROR; ioError := TRUE; unsafe := FALSE
			END;
			RETURN entry
		END ReadFATEntryX;

		PROCEDURE WriteFATEntryX(adr, link: Address; VAR res: LONGINT);
		VAR offset: Address; i: LONGINT;
			data: ARRAY BS OF CHAR;
		BEGIN
			INC(NwriteFAT);
			IF ~unsafe THEN
				IF ((adr < 2) OR (adr > maxClusters+1)) OR ((link # EOC) & (link # FREE) & ((link < 2) OR (link > maxClusters+1))) THEN
					HALT(ErrInvalidParams)
				END;

				IF (link = EOC) THEN link := fat16EOC
				ELSIF (link = BAD) THEN link := fat16BAD
				ELSIF (link = FREE) THEN link := fat16FREE
				END
			ELSE
				unsafe := FALSE
			END;

			offset := adr*2;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (res = Disks.Ok) THEN
				PutUnsignedInteger(data, offset MOD BS, link);
				FOR i := 0 TO numFATs-1 DO
					WriteSectorX(startFAT + i*fatSize + offset DIV BS, data, 0, res);
					IF (res # Disks.Ok) THEN
						res := IOERROR; ioError := TRUE
					END
				END
			ELSE
				res := IOERROR; ioError := TRUE
			END;
		END WriteFATEntryX;
	END FAT16Volume;

CONST
	fat32EOC = 0FFFFFF8H;	(* end of clusterchain; test for greater or equal *)
	fat32BAD = 0FFFFFF7H;	(* bad cluster *)
	fat32FREE = 0H;	(* free cluster *)
	fat32CleanShutdown = {27};
	fat32IOError	= {26};
	fat32VCF = fat32CleanShutdown + fat32IOError; 	(* Volume Clean Flags *)

TYPE
	FAT32Volume* = OBJECT(Volume)
		VAR
			rootCluster-,	(* first cluster of root directory *)
			fsInfo-: Address; 	(* sector number of FSInfo sector (relative to 'start') *)

		PROCEDURE Initialize(VAR bpb: BPB; MaxClusters: LONGINT): BOOLEAN;
		VAR i, res: LONGINT; result: BOOLEAN; info: ARRAY BS OF CHAR; vcf: SET;
		BEGIN {EXCLUSIVE}
			result := FALSE;
			IF Initialize^(bpb, MaxClusters) THEN	(* see note in Volumes.Initialize *)
				IF (bpb[42] = 0X) & (bpb[43] = 0X) THEN (* version 0.0 supported *)
					fatSize := GetLongint(bpb, 36);
					endFAT := start + startFAT + (numFATs*fatSize) - 1;
					startData := start + startFAT + (numFATs*fatSize) - 2*sectorsPC;
					rootCluster := GetLongint(bpb, 44);

					IF (bpb[66] = 029X) THEN
						FOR i := 0 TO 10 DO label[i] := bpb[71+i] END; label[11] := 0X;
						Strings.TrimRight(label, " ")
					END;

					fsInfo := GetUnsignedInteger(bpb, 48);
					dev.Transfer(Disks.Read, start + fsInfo, 1, info, 0, res);
					IF (res = Ok) &
						(GetLongint(info, 0) = 041615252H) & (GetLongint(info, 508) = 0AA550000H)  & (* lead & trail signature *)
						(GetLongint(info, 484) = 061417272H)	(* struc signature *)
					THEN
						freeCount := GetLongint(info, 488);
						freeCluster := GetLongint(info, 492);

						IF (freeCluster < 2) OR (freeCluster > maxClusters+1) OR (freeCount < 0) OR (freeCount > maxClusters) THEN
							KernelLog.Enter; KernelLog.String("WARNING: free cluster, free count info in BPB invalid (");
							KernelLog.Int(freeCluster, 0); KernelLog.String(", "); KernelLog.Int(freeCount, 0); KernelLog.Char(")");
							KernelLog.Exit;
							freeCount := -1;
							freeCluster := 2
						END
					ELSE
						freeCount := -1;
						freeCluster := 2
					END;

					result := TRUE;
					unsafe := TRUE; vcf := SYSTEM.VAL(SET, ReadFATEntryX(1));
					IF (vcf * fat32VCF = fat32VCF) THEN	(* volume is clean *)
						unsafe := TRUE;
						IF ~(Files.ReadOnly IN flags) THEN WriteFATEntryX(1, SYSTEM.VAL(LONGINT, vcf - fat32CleanShutdown), res) END
					ELSE
						KernelLog.Ln; KernelLog.Enter;
						IF (Override IN flags) THEN
							KernelLog.String(" WARNING: volume was not properly unmounted; volume might be damaged !!!")
						ELSE
							INCL(flags, Files.ReadOnly);
							KernelLog.String(" volume was not properly unmounted; mounting read-only. Run Scandisk under DOS/Windows")
						END;
						KernelLog.Exit
					END
				ELSE
					KernelLog.String(" unsupported FAT32 version")
				END
			END;
			RETURN result
		END Initialize;

		PROCEDURE Finalize;
		VAR vcf: SET; res: LONGINT; info: ARRAY BS OF CHAR;
		BEGIN {EXCLUSIVE}
			IF ~(Files.ReadOnly IN flags) THEN
				dev.Transfer(Disks.Read, start + fsInfo, 1, info, 0, res);
				IF (res = Ok) &
					(GetLongint(info, 0) = 041615252H) & (GetLongint(info, 508) = 0AA550000H)  & (* lead & trail signature *)
					(GetLongint(info, 484) = 061417272H)	(* struc signature *)
				THEN
					PutLongint(info, 488, freeCount);
					PutLongint(info, 492, freeCluster);
					dev.Transfer(Disks.Write, start + fsInfo, 1, info, 0, res);
					ioError := ioError OR (res # Ok)
				END;

				unsafe := TRUE; vcf := SYSTEM.VAL(SET, ReadFATEntryX(1));
				vcf := vcf + fat32CleanShutdown;
				IF ioError THEN vcf := vcf - fat32IOError ELSE vcf := vcf + fat32IOError END;
				unsafe := TRUE; WriteFATEntryX(1, SYSTEM.VAL(LONGINT, vcf), res) (* ignore res *)
			END;
			Finalize^ (* see note in Volumes.Finalize *)
		END Finalize;

		PROCEDURE InitRoot;
		VAR cluster: POINTER TO ARRAY OF CHAR; res: LONGINT;
		BEGIN
			NEW(cluster,clusterSize);
			WriteFATEntryX(rootCluster, EOC, res); (* ignore res *)
			WriteClusterX(rootCluster, cluster^, res) (* ignore res *)
		END InitRoot;

		PROCEDURE ReadFATEntryX(adr: Address): Address;
		VAR offset, entry: Address; res: LONGINT; data: ARRAY BS OF CHAR;
		BEGIN
			INC(NreadFAT);
			IF ~unsafe & ((adr < 2) OR (adr > maxClusters+1)) THEN HALT(ErrInvalidParams) END;

			offset := adr*4;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (res = Disks.Ok) THEN
				entry := AND(GetLongint(data, offset MOD BS), 0FFFFFFFH);
				IF ~unsafe THEN
					IF (entry >= fat32EOC) THEN entry := EOC
					ELSIF (entry = fat32BAD) THEN entry := BAD
					END
				ELSE
					unsafe := FALSE
				END
			ELSE
				entry := IOERROR; ioError := TRUE; unsafe := FALSE
			END;
			RETURN entry
		END ReadFATEntryX;

		PROCEDURE WriteFATEntryX(adr, link: Address; VAR res: LONGINT);
		VAR offset: Address; i: LONGINT; data: ARRAY BS OF CHAR;
		BEGIN
			INC(NwriteFAT);
			IF ~unsafe THEN
				IF ((adr < 2) OR (adr > maxClusters+1)) OR ((link # EOC) & (link # FREE) & ((link < 2) OR (link > maxClusters+1))) THEN
					HALT(ErrInvalidParams)
				END;

				IF (link = EOC) THEN link := fat32EOC
				ELSIF (link = BAD) THEN link := fat32BAD
				ELSIF (link = FREE) THEN link := fat32FREE
				END;
			ELSE
				unsafe := FALSE
			END;

			offset := adr*4;
			ReadSectorX(startFAT + offset DIV BS, data, 0, res);
			IF (res = Disks.Ok) THEN
				PutLongint(data, offset MOD BS, AND(GetLongint(data, offset MOD BS), LONGINT(0F0000000H)) + link);
				FOR i := 0 TO numFATs-1 DO
					WriteSectorX(startFAT + i*fatSize + offset DIV BS, data, 0, res);
					IF (res # Disks.Ok) THEN
						res := IOERROR; ioError := TRUE
					END
				END
			ELSE
				res := IOERROR; ioError := TRUE
			END
		END WriteFATEntryX;
	END FAT32Volume;

PROCEDURE New*(context : Files.Parameters);
VAR
	part, res, type, cacheSize: LONGINT; flags: SET; stop: BOOLEAN;
	name: Plugins.Name; plugin: Plugins.Plugin; dev: Disks.Device;
	ptable: Disks.PartitionTable; ch : CHAR;
BEGIN {EXCLUSIVE}
	context.vol := NIL;
	cacheSize := DfltDataCacheSize;

	Files.GetDevPart(context.arg, name, part);

	(* read parameters: [",R"] [",X"] [",C:"<cache size>] *)
	flags := {}; stop := FALSE;
	context.arg.SkipWhitespace;
	ch := context.arg.Peek();
	WHILE (ch = ",") & (context.arg.res = Streams.Ok) & (~stop)  DO
		context.arg.Char(ch); (* consume "," *)
		context.arg.Char(ch);
		CASE ch OF
			|"R": INCL(flags, Files.ReadOnly);
			|"X": INCL(flags, Override);
			|"C":
				context.arg.Char(ch); (* consume ":" *)
				context.arg.Int(cacheSize, FALSE);
		ELSE
			stop := TRUE;
		END;
		context.arg.SkipWhitespace;
		ch := context.arg.Peek();
	END;

	context.out.String("FATVolumes: Device "); context.out.String(name);
	plugin := Disks.registry.Get(name);
	IF (plugin # NIL) THEN
		dev := plugin(Disks.Device);
		dev.Open(res);
		IF res = Disks.Ok THEN
			ptable := dev.table;
			context.out.Char("#"); context.out.Int(part, 1);
			IF ((LEN(ptable) = 1) & (part = 0)) OR ((part > 0) & (part < LEN(ptable))) THEN
				type := ptable[part].type;
				IF (type = 1) OR (* FAT12 *)
					(type = 4) OR (* FAT16, up to 32MB *)
					(type = 6) OR (type = 0EH) OR (* FAT16, over 32MB / FAT16 LBA *)
					(type = 0BH) OR (type = 0CH) OR (* FAT32, up to 2047GB / FAT32 LBA *)
					~IsPartitioned(dev)
				THEN
					IF ~(Disks.Mounted IN ptable[part].flags) THEN
						InitVol(dev, part, type, context.vol, flags, cacheSize);
						IF (context.vol # NIL) THEN
							IF (Files.ReadOnly IN flags) THEN INCL(ptable[part].flags, Disks.ReadOnly) END;
							INCL(ptable[part].flags, Disks.Mounted)
						END
					ELSE context.error.String(" already mounted"); context.error.Ln;
					END
				ELSE context.error.String(" wrong partition type"); context.error.Ln;
				END
			ELSE context.error.String(" invalid partition"); context.error.Ln;
			END;
			IF context.vol = NIL THEN
				dev.Close(res); (* close again - ignore res *)
			END
		ELSE context.error.String(" error "); context.error.Int(res, 1); context.error.Ln;
		END
	ELSE context.error.String(" not found"); context.error.Ln;
	END;
END New;

PROCEDURE WritePartitionType(type: LONGINT);
BEGIN
	IF (type = 1) THEN KernelLog.String("FAT12")
	ELSIF (type = 4) OR (type = 6) OR (type = 0EH) THEN KernelLog.String("FAT16")
	ELSIF (type = 0BH) OR (type = 0CH) THEN KernelLog.String("FAT32")
	END
END WritePartitionType;

PROCEDURE InitVol(dev: Disks.Device; partIdx, type: LONGINT; VAR vol: Files.Volume; flags: SET; cacheSize: LONGINT);
VAR
	bpb: BPB; vol12: FAT12Volume; vol16: FAT16Volume; vol32: FAT32Volume; fatString : ARRAY 12 OF CHAR;
	fatSize, numSectors, numClusters, reserved, numFATs, rootEntryCount, sectPC, res, fat : LONGINT;
BEGIN
	dev.Transfer(Disks.Read, dev.table[partIdx].start, 1, bpb, 0, res);
	IF (res = Ok) THEN
		IF (bpb[510]=055X) & (bpb[511]=0AAX) THEN (* boot sector signature ok *)
			(* determine FAT type *)
			fatSize := GetUnsignedInteger(bpb, 22);
			IF (fatSize = 0) THEN fatSize := GetLongint(bpb, 36) END;
			numSectors := GetUnsignedInteger(bpb, 19);
			IF (numSectors = 0) THEN numSectors := GetLongint(bpb, 32) END;
			reserved := GetUnsignedInteger(bpb, 14);
			numFATs := ORD(bpb[16]);
			rootEntryCount := GetUnsignedInteger(bpb, 17);
			sectPC := ORD(bpb[13]);

			(* FAT type determination *)
			numClusters := (numSectors - (reserved + (numFATs*fatSize) + (rootEntryCount*32 + BS - 1) DIV BS)) DIV sectPC;

			IF (numClusters < 4085) THEN NEW(vol12); vol := vol12; fat := 12; fatString := "FAT12";
			ELSIF (numClusters < 65525) THEN NEW(vol16); vol := vol16; fat := 16; fatString := "FAT16";
			ELSE NEW(vol32); vol := vol32; fat := 32; fatString := "FAT32";
			END;

			IF ~IsPartitioned(dev) THEN
				KernelLog.String(" ("); KernelLog.String(fatString); KernelLog.String(" volume)"); KernelLog.Ln;
			ELSE
				(* check if partition type matches with determined FS type *)
				IF ((type = 1) & (fat # 12)) OR
					(((type = 4) OR (type = 6) OR (type = 0EH)) & (fat # 16)) OR
					(((type = 0BH) OR (type = 0CH)) & (fat # 32))
				THEN
					KernelLog.String(" failed: BPB (bios parameter block) or partition table corrupt"); KernelLog.Ln;
					KernelLog.String("   file system type according to partition table: "); WritePartitionType(type); KernelLog.Ln;
					KernelLog.String("   determined file system type: FAT"); KernelLog.Int(fat, 0);
					vol := NIL;
					RETURN
				END;
			END;

			WITH vol: Volume DO
				vol.name := "<no name>";
				vol.size := dev.table[partIdx].size;
				vol.blockSize := BS; vol.flags := flags;
				vol.dev := dev; vol.start := dev.table[partIdx].start;
				IF (Disks.ReadOnly IN dev.flags) THEN INCL(flags, Files.ReadOnly) END;
				IF ~vol.Initialize(bpb, numClusters) THEN
					EXCL(dev.table[partIdx].flags, Disks.Mounted);
					vol := NIL
				ELSE
					IF FATCacheEnabled & (FATCacheSize > 0) THEN vol.SetCache(FAT, FATCacheSize, FATWriteBehind) END;
					IF (cacheSize # 0) THEN vol.SetCache(Data, ABS(cacheSize), cacheSize < 0)
					ELSE vol.SetCache(Data, 0, FALSE)
					END
				END
			END
		ELSE KernelLog.String(" BPB signature wrong")
		END;
	ELSE KernelLog.String(" cannot read BPB (bios parameter block")
	END
END InitVol;

(** ---------- helper functions --------------*)

(** AND - bitwise AND *)
PROCEDURE AND*(a,b: LONGINT): LONGINT;
BEGIN RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a) * SYSTEM.VAL(SET, b))
END AND;

(** Or - bitwise OR *)
PROCEDURE Or*(a,b: LONGINT): LONGINT;
BEGIN RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a) + SYSTEM.VAL(SET, b))
END Or;

(** GetUnsignedInteger - returns an unsigned integer at offset 'ofs' in 'b' which is assumed to be little endian *)
PROCEDURE GetUnsignedInteger*(VAR b: ARRAY OF CHAR; ofs: LONGINT): LONGINT;
BEGIN
	RETURN 100H*LONG(ORD(b[ofs+1])) + LONG(ORD(b[ofs]))
END GetUnsignedInteger;

(** PutUnsignedInteger - writes an unsigned integer at offset 'ofs' in 'b' which is assumed to be little endian *)
PROCEDURE PutUnsignedInteger*(VAR b: ARRAY OF CHAR; ofs, value: LONGINT);
BEGIN
	b[ofs] := CHR(value);
	b[ofs+1] := CHR(value DIV 100H)
END PutUnsignedInteger;

(** GetLongint - returns a long integer at offset 'ofs' in 'b' which is assumed to be little endian *)
PROCEDURE GetLongint*(VAR b: ARRAY OF CHAR; ofs: LONGINT): LONGINT;
BEGIN
	RETURN 1000000H*LONG(ORD(b[ofs+3])) + 10000H*LONG(ORD(b[ofs+2])) +
		100H*LONG(ORD(b[ofs+1])) + LONG(ORD(b[ofs]))
END GetLongint;

(** PutLongint - writes a long integer at offset 'ofs' in 'b' which is assumed to be little endian *)
PROCEDURE PutLongint*(VAR b: ARRAY OF CHAR; ofs, value: LONGINT);
VAR i : INTEGER;
BEGIN
	FOR i := 0 TO 3 DO b[ofs+i] := CHR(value); value := value DIV 100H END
END PutLongint;

PROCEDURE IsPartitioned(dev : Disks.Device) : BOOLEAN;
BEGIN
	ASSERT((dev # NIL) & (dev.table # NIL));
	RETURN dev.table[0].flags * {Disks.Valid} # {};
END IsPartitioned;

END FATVolumes.

History:

	20.02.2006	Allow unpartitioned devices to be mounted (staubesv)

System.Free FATVolumes ~
