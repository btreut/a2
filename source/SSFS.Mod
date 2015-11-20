MODULE SSFS; (** AUTHOR "staubesv"; PURPOSE "Simple Silly File System"; *)
(*
The Simple Silly File System (SSFS) is a very simple file system the can be useful for educational purposes. It is not supposed to be used in a
productive environment and has many limitations that make it impractical. Nevertheless, it's a good starting point for student exercises.

Volume Layout:

	| SuperBlock	| Root Directory				| Free Block Bitmap				| DNodes and INodes (mixed) 	|

	0				superBlock.rootDirectory	superBlock.freeBlockBitMap		superBlock.firstDataBlock

The SuperBlock contains information about the file system volume layout. The root directory is a DirectoryBlock, i.e. it contains the mapping of
filenames to Inode numbers.
Note that we mix Inodes and Dnodes in the data section of the file system.
This filesystem is not quite what we teached you in the lecture in that it does not distinct in block sizes in the metadata part and the data section.
It is implemented like that to make the interface much easier: note that for block accesses the filesystem only makes use of the provided Volume object.
*)

IMPORT
	SYSTEM,
	KernelLog, Commands, Plugins, Dates, Strings, Disks, Files;

CONST
	Ok* = 0;
	InvalidBlockNumber* = 1000;
	InvalidFilePosition* = 1001;
	BlockSizeNotSupported* = 2000;
	NotFormatted* = 2001;
	WrongVersion* = 2002;
	VolumeFull* = 3000;
	DeviceNotFound* = 4000;
	DeviceError* = 4001;
	PartitionTooSmall* = 5000;

	(* Magic number used to identify our file system *)
	SSFS_MagicNumber = LONGINT(99887766H);
	SSFS_Version = 01H;

	BlockSize = 4096; (* must be multiple of device.blockSize *)

	DirectoryEntrySize = 256;
	DirectoryEntriesPerBlock = BlockSize DIV DirectoryEntrySize; (* {BlockSize MOD DirectoryEntrySize = 0} *)

	(* Offsets of some special blocks *)
	Offset_SuperBlock = 0;

	BlockNotAllocated = 0;

	MinVolumeSize = 5; (* Superblock, Root Directory Block, Free Bitmap (min. 1 Block), 1x I-Node + 1x D-Note *)

	BitsPerSET = SIZEOF(SET) * 8;

	Trace = FALSE;

TYPE

	Block = ARRAY BlockSize OF CHAR;

	(* abstract interface to the volume: read and write blocks *)
	(* simplification in this simple file system: any blocks are file system blocks  *)
	Volume = OBJECT
	VAR
		device : Disks.Device; partition : LONGINT;
		nofBlocks : LONGINT;

		sectorsPerBlock : LONGINT;

		(* read a block as array of character *)
		PROCEDURE ReadBlock(blockNumber : LONGINT; VAR block : Block; VAR res : LONGINT);
		BEGIN
			IF (0 <= blockNumber) & (blockNumber < nofBlocks) THEN
				device.Transfer(Disks.Read, device.table[partition].start + blockNumber * sectorsPerBlock, sectorsPerBlock, block, 0, res);
			ELSE
				res := InvalidBlockNumber;
			END;
		END ReadBlock;

		(* write a block to disk *)
		PROCEDURE WriteBlock(blockNumber : LONGINT; VAR block : Block; VAR res : LONGINT);
		BEGIN
			IF (0 <= blockNumber) & (blockNumber < nofBlocks) THEN
				device.Transfer(Disks.Write, device.table[partition].start + blockNumber * sectorsPerBlock, sectorsPerBlock, block, 0, res);
			ELSE
				res := InvalidBlockNumber;
			END;
		END WriteBlock;

		(* finalizer: called when the filesystem goes down. As we do not make use of caches, this only closes the device for the time being *)
		PROCEDURE Finalize;
		VAR ignore : LONGINT;
		BEGIN
			device.Close(ignore);
		END Finalize;

		(* constructor of Volume: set variables for device, partition and geometry plus some sanity checks *)
		PROCEDURE &Init*(device : Disks.Device; partition : LONGINT; VAR res : LONGINT);
		BEGIN
			ASSERT((device # NIL) & (device.table # NIL) & (partition < LEN(device.table)));
			SELF.device := device; SELF.partition := partition;
			IF (BlockSize MOD device.blockSize = 0) THEN
				nofBlocks := device.table[partition].size * device.blockSize DIV BlockSize; (* not fully used blocks are truncated *)
				IF (nofBlocks >= MinVolumeSize) THEN
					sectorsPerBlock := BlockSize DIV device.blockSize;
					res := Ok;
					IF Trace THEN
						KernelLog.String("Volume created on partition "); KernelLog.String(device.name); KernelLog.String("#"); KernelLog.Int(partition, 0);
						KernelLog.String(", size: "); KernelLog.Int(nofBlocks, 0); KernelLog.String(" blocks a "); KernelLog.Int(BlockSize, 0);
						KernelLog.String(" Bytes"); KernelLog.Ln;
					END;
				ELSE
					res := PartitionTooSmall;
				END;
			ELSE
				res := BlockSizeNotSupported;
			END;
		END Init;

	END Volume;

TYPE

	(** This object is NOT thread-safe!!! *)
	(* handling of the freeblocks bitmap *)
	BlockBitmap = OBJECT
	VAR
		(* Block usage bitmap:  bit set <-> block used *)
		bitmap : POINTER TO ARRAY OF SET;

		(* Block number of next free block. May be out-of-date *)
		hint : LONGINT;

		fileSystem : FileSystem;

		(** Mark the specified block as free *)
		PROCEDURE FreeBlock(blockNumber : LONGINT; VAR res : LONGINT);
		BEGIN {EXCLUSIVE}
			IF (0 <= blockNumber) & (blockNumber < fileSystem.volume.nofBlocks) THEN
				SetUsed(blockNumber, FALSE);
				(* immediately write this back to the bitmap on the volume, iinefficient but ok for this purpose  *)
				WriteBack(blockNumber, res);
			ELSE
				res := InvalidBlockNumber;
			END;
		END FreeBlock;

		(** Get the address of the next free block and mark it as used *)
		PROCEDURE AllocateBlock(VAR res : LONGINT) : LONGINT;
		VAR blockNumber : LONGINT;
		BEGIN {EXCLUSIVE}
			blockNumber := FindFreeBlock(res, TRUE);
			IF (res = Ok) THEN
				SetUsed(blockNumber, TRUE);
				(* immediately write this back to the bitmap on the volume *)
				WriteBack(blockNumber, res);
			END;
			RETURN blockNumber;
		END AllocateBlock;

		(* Find a free block and return its block number. *)
		PROCEDURE FindFreeBlock(VAR res : LONGINT; useHint : BOOLEAN) : LONGINT; (* private *)
		VAR blockNumber : LONGINT;
		BEGIN
			IF useHint & (hint >= fileSystem.superBlock.firstDataBlock) THEN
				blockNumber := hint;
			ELSE
				blockNumber := fileSystem.superBlock.firstDataBlock;
			END;
			ASSERT(blockNumber >= fileSystem.superBlock.firstDataBlock); (* don't overwrite the file system metadata *)
			WHILE (blockNumber < fileSystem.volume.nofBlocks) & IsUsed(blockNumber) DO INC(blockNumber); END;
			IF (blockNumber < fileSystem.volume.nofBlocks) THEN
				hint := blockNumber + 1;
				res := Ok;
			ELSE
				IF useHint THEN
					blockNumber := FindFreeBlock(res, FALSE);
				ELSE
					res := VolumeFull;
				END;
			END;
			RETURN blockNumber;
		END FindFreeBlock;

		(** Is the block <blockNumber> in use? *)
		PROCEDURE IsUsed(blockNumber : LONGINT) : BOOLEAN; (* private *)
		BEGIN
			ASSERT((0 <= blockNumber) & (blockNumber < fileSystem.volume.nofBlocks));
			RETURN (blockNumber MOD BitsPerSET) IN bitmap[blockNumber DIV BitsPerSET];
		END IsUsed;

		(* in- or exclude a used bit in the block-bitmap *)
		PROCEDURE SetUsed(blockNumber : LONGINT; used : BOOLEAN);  (* private *)
		BEGIN
			ASSERT((0 <= blockNumber) & (blockNumber < fileSystem.volume.nofBlocks));
			IF used THEN
				ASSERT(~IsUsed(blockNumber));
				INCL(bitmap[blockNumber DIV BitsPerSET], blockNumber MOD BitsPerSET);
			ELSE
				ASSERT(IsUsed(blockNumber));
				EXCL(bitmap[blockNumber DIV BitsPerSET], blockNumber MOD BitsPerSET);
			END;
		END SetUsed;

		(* Writes the block of the block bitmap that has changed back to disk *)
		PROCEDURE WriteBack(blockNumber : LONGINT; VAR res : LONGINT); (* private *)
		VAR data : Block; blockIdx, index : LONGINT;
		BEGIN
			ClearBlock(data);
			blockIdx := 0;
			(* determine the index of the SET that has changed...*)
			index := blockNumber DIV BitsPerSET;
			(* ... but we need the first index of bitmap of the block in the free block bitmap that has changed *)
			index := index - (index MOD (BlockSize DIV BitsPerSET));
			ASSERT((0 <= index) & (index < LEN(bitmap)));
			WHILE (blockIdx < BlockSize) & (index < LEN(bitmap)) DO
				SYSTEM.PUT32(ADDRESSOF(data[blockIdx]), bitmap[index]);
				INC(index); INC(blockIdx, SIZEOF(SET));
			END;
			ASSERT((blockNumber DIV BlockSize) < fileSystem.superBlock.freeBlockBitmapSize); (* write to free block bitmap!! *)
			fileSystem.volume.WriteBlock(fileSystem.superBlock.freeBlockBitmapFirst + (blockNumber DIV BlockSize), data, res);
		END WriteBack;

		(* load all bitmap-blocks from the disk *)
		PROCEDURE LoadFromDisk(VAR res : LONGINT); (* Called only once by FileSystem.Init *)
		VAR data : Block; blockNumber, blockIdx, index : LONGINT;
		BEGIN
			ASSERT(fileSystem.superBlock.freeBlockBitmapSize # 0); (* volume formatted? *)
			index := 0;
			FOR blockNumber := 0 TO fileSystem.superBlock.freeBlockBitmapSize-1 DO
				fileSystem.volume.ReadBlock(fileSystem.superBlock.freeBlockBitmapFirst + blockNumber, data, res);
				IF (res = Ok) THEN
					blockIdx := 0;
					WHILE (blockIdx < BlockSize) & (index < LEN(bitmap)) DO
						bitmap[index] := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(data[blockIdx])));
						INC(index); INC(blockIdx, SIZEOF(SET));
					END;
				ELSE
					RETURN;
				END;
			END;
			IF Trace THEN
				KernelLog.String("Loaded bitmap from disk: "); KernelLog.Ln;
				Show;
			END;
		END LoadFromDisk;

		(* Displays the bitmap's first 256 entries (debugging) *)
		PROCEDURE Show;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO 7 DO
				IF (i MOD 2 = 0) THEN KernelLog.Ln; END;
				KernelLog.Bits(bitmap[i], 0, 32); KernelLog.String(" ");
			END;
			KernelLog.Ln;
		END Show;

		PROCEDURE &Init*(fileSystem : FileSystem);
		VAR bitmapSize : LONGINT; i : LONGINT;
		BEGIN
			ASSERT((fileSystem # NIL) & (fileSystem.volume # NIL));
			ASSERT(BlockSize MOD BitsPerSET = 0); (* entries of bitmap must not cross block boundaries *)
			SELF.fileSystem := fileSystem;
			(* allocate one bit for each file system block (rounded up to BitsPerSET)  *)
			bitmapSize := (fileSystem.volume.nofBlocks + BitsPerSET-1) DIV BitsPerSET;
			NEW(bitmap, bitmapSize);
			FOR i := 0 TO LEN(bitmap)-1 DO bitmap[i] := {}; END;
			IF Trace THEN
				KernelLog.String("Bitmap start: "); KernelLog.Int(fileSystem.superBlock.freeBlockBitmapFirst, 0); KernelLog.Ln;
				KernelLog.String("BlockBitmap created, size: "); KernelLog.Int(bitmapSize, 0); KernelLog.String(" entries");
				KernelLog.Ln;
				Show;
			END;
		END Init;

	END BlockBitmap;

TYPE

	(* Our file system has four kinds of blocks... *)

	DirectoryEntry = RECORD
		name : ARRAY 252 OF CHAR;
		inode : LONGINT;
	END;

	DirectoryBlock = ARRAY DirectoryEntriesPerBlock OF DirectoryEntry;

	SuperBlock = RECORD
		magicNumber : LONGINT; (* magic number of the file system *)
		version : LONGINT; (* SSFS Version *)
		rootDirectory : LONGINT; (* cluster that is reserved for the root directory *)
		freeBlockBitmapFirst : LONGINT; (* first cluster that is reserved for the bitmap *)
		freeBlockBitmapSize  : LONGINT; (* number of clusters that are reserved for the bitmap *)
		firstDataBlock : LONGINT; (* number of block where the data start *)
		filler : ARRAY BlockSize - 6 * 4 OF CHAR; (* unused remainder *)
	END;

	Inode = RECORD
		size : LONGINT; (* file size in bytes *)
		attributes : SET; (* attributes, to be defined *)
		date, time : LONGINT; (* time and date of modification *)
		unused : LONGINT; (* currently unused *)
		direct : ARRAY (BlockSize - 5 * 4) DIV 4 OF LONGINT; (* direct links to dnodes *)
	END;

	Dnode = Block;

TYPE

	(* the concrete implementation of our filesystem is done by implementing the methods defined by Files.FileSystem *)
	FileSystem = OBJECT(Files.FileSystem)
	VAR
		volume : Volume; (* volume, the file system is operating on *)
		superBlock : SuperBlock; (* superblock meta information, read at startup *)
		rootDirectory : DirectoryBlock; (* rootDirectory *)
		bitmap : BlockBitmap; (* free blocks bitmap *)

		(* constructor: set variables and read super block, check if file system is formatted, res = Ok indicates success  *)
		PROCEDURE &Init*(volume : Volume; VAR res : LONGINT);
		VAR block : Block;
		BEGIN
			ASSERT(volume # NIL);
			SELF.volume := volume;
			COPY("SSFS", desc);
			flags := {}; vol := NIL;
			volume.ReadBlock(Offset_SuperBlock, block, res);
			IF (res = Ok) THEN
				superBlock := SYSTEM.VAL(SuperBlock, block);
				IF (superBlock.magicNumber = SSFS_MagicNumber) THEN
					IF (superBlock.version = SSFS_Version) THEN
						volume.ReadBlock(superBlock.rootDirectory, block, res);
						IF (res = Ok) THEN
							rootDirectory := SYSTEM.VAL(DirectoryBlock, block);
							IF (superBlock.freeBlockBitmapFirst # BlockNotAllocated) & (superBlock.freeBlockBitmapSize <= volume.nofBlocks) THEN
								NEW(bitmap, SELF);
								bitmap.LoadFromDisk(res);
							END;
						END;
					ELSE
						res := WrongVersion;
					END;
				ELSE
					res := NotFormatted;
				END;
			END;
		END Init;

		(** Create a new file with the specified name.  End users use Files.New instead. *)
		PROCEDURE New0*(name: ARRAY OF CHAR): Files.File;
		VAR
			file : File; filename : Files.FileName; fileExists : BOOLEAN;
			inodeAdr, index, i, res : LONGINT; dateTime : Dates.DateTime;
			inode : Inode; block : Block;
		BEGIN {EXCLUSIVE}
			IF Trace THEN KernelLog.String("New: "); KernelLog.String(name); KernelLog.Ln; END;
			file := NIL; fileExists := FALSE;
			IF GetFilename(name, filename) THEN
				index := FindEntry(filename);
				IF (index = -1) THEN (* file does not exist yet... find a free directory entry *)
					index := FindEntry("");
				ELSE
					fileExists := TRUE;
				END;
				IF (index >= 0) THEN
					(* first try to allocate a inode for the file *)
					IF fileExists THEN
						ASSERT(rootDirectory[index].inode # 0);
						inodeAdr := rootDirectory[index].inode;
						volume.ReadBlock(inodeAdr, block, res);
						inode := SYSTEM.VAL(Inode, block);
						DeleteDnodes(inode, res);
						FOR i := 0 TO LEN(inode.direct)-1 DO inode.direct[i] := BlockNotAllocated; END;
					ELSE
						inodeAdr := bitmap.AllocateBlock(res);
						ClearInode(inode);
					END;
					IF (res = Ok) THEN
						dateTime := Dates.Now();
						Dates.DateTimeToOberon(dateTime, inode.date, inode.time);
						volume.WriteBlock(inodeAdr, SYSTEM.VAL(Block, inode), res);
						IF (res = Ok) THEN
							(* create directory entry now *)
							COPY(filename, rootDirectory[index].name);
							rootDirectory[index].inode := inodeAdr;
							volume.WriteBlock(superBlock.rootDirectory, SYSTEM.VAL(Block, rootDirectory), res);
							IF (res = Ok) THEN
								NEW(file, filename, inode, inodeAdr, SELF);
							ELSE
								KernelLog.String("Could not write back root directory, res: "); KernelLog.Int(res, 0); KernelLog.Ln;
							END;
						ELSE
							KernelLog.String("Could not write Inode, res: "); KernelLog.Int(res, 0); KernelLog.Ln;
						END;
					ELSE
						KernelLog.String("Could not allocate Inode for file "); KernelLog.String(filename);
						KernelLog.String(", res: "); KernelLog.Int(res, 0); KernelLog.Ln;
					END;
				ELSE
					KernelLog.String("Cannot create file "); KernelLog.String(filename); KernelLog.String(": root directory is full.");
					KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("Invalid filename: "); KernelLog.String(filename);  KernelLog.Ln;
			END;
			RETURN file;
		END New0;

		(** Open an existing file. The same file descriptor is returned if a file is opened multiple times.  End users use Files.Old instead. *)
		PROCEDURE Old0*(name: ARRAY OF CHAR): Files.File;
		VAR file : File; filename : Files.FileName; block : Block; inode : Inode;  index, res : LONGINT;
		BEGIN {EXCLUSIVE}
			IF Trace THEN KernelLog.String("Old: "); KernelLog.String(name); KernelLog.Ln; END;
			file := NIL;
			IF GetFilename(name, filename) THEN
				index := FindEntry(filename);
				IF (index >= 0) THEN
					ASSERT(rootDirectory[index].inode # 0);
					volume.ReadBlock(rootDirectory[index].inode, block, res);
					IF (res = Ok) THEN
						inode := SYSTEM.VAL(Inode, block);
						NEW(file, filename, inode, rootDirectory[index].inode, SELF);
					ELSE
						KernelLog.String("Could not read Inode for file "); KernelLog.String(filename); KernelLog.String(", res: ");
						KernelLog.Int(res, 0); KernelLog.Ln;
					END;
				END;
			ELSE
				KernelLog.String("Invalid filename: "); KernelLog.String(filename);  KernelLog.Ln;
			END;
			RETURN file;
		END Old0;

		(* Called by File.Update. We write back the Inode here since we want the file system to be locked while doing that *)
		PROCEDURE UpdateInode(inode : Inode; inodeAdr : LONGINT);
		VAR res : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(inodeAdr >= superBlock.firstDataBlock);
			volume.WriteBlock(inodeAdr, SYSTEM.VAL(Block, inode), res);
			IF (res # Ok) THEN
				KernelLog.String("Error when writing back Inode of file, res: "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
		END UpdateInode;

		(* For now, this just removes a path delimiter character at the beginning of the filename *)
		PROCEDURE GetFilename(name : ARRAY OF CHAR; VAR filename : ARRAY OF CHAR) : BOOLEAN;
		VAR ch : CHAR; i, j : LONGINT;
		BEGIN
			Strings.TrimWS(name);
			ch := name[0];
			i := 0; j := 0;
			IF (ch = Files.PathDelimiter) THEN
				INC(i);
			END;
			WHILE (i < LEN(name)) & (j < LEN(filename)-1) & (name[i] # 0X) DO
				filename[j] := name[i];
				INC(i); INC(j);
			END;
			filename[j] := 0X;
			RETURN (filename # "");
		END GetFilename;

		(** Returns the index of the filename entry in the root directory or -1 if not found *)
		PROCEDURE FindEntry(CONST name : ARRAY OF CHAR) : LONGINT;
		VAR index : LONGINT;
		BEGIN
			index := 0;
			WHILE (index < LEN(rootDirectory)) & (rootDirectory[index].name # name) DO INC(index); END;
			IF (index >= LEN(rootDirectory)) THEN (* file not found *) index := -1; END;
			ASSERT((index = -1) OR ((0 <= index) & (index < LEN(rootDirectory))));
			RETURN index;
		END FindEntry;

		(** Delete a file. res = 0 indicates success.  End users use Files.Delete instead. *)
		PROCEDURE Delete0*(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		VAR filename : Files.FileName; index : LONGINT; block : Block;
		BEGIN {EXCLUSIVE}
			IF Trace THEN KernelLog.String("Delete: "); KernelLog.String(name); KernelLog.Ln; END;
			IF GetFilename(name, filename) THEN
				index := FindEntry(filename);
				IF (index >= 0) THEN
					ASSERT(rootDirectory[index].inode # 0);
					volume.ReadBlock(rootDirectory[index].inode, block, res);
					IF (res = Ok) THEN
						DeleteFile(SYSTEM.VAL(Inode, block), rootDirectory[index].inode,  res);
						IF (res # Ok) THEN
							KernelLog.String("Could not delete Inode or Dnodes"); KernelLog.Ln;
							res := -99;
						END;
						rootDirectory[index].name := "";
						rootDirectory[index].inode := 0;
						volume.WriteBlock(superBlock.rootDirectory, SYSTEM.VAL(Block, rootDirectory), res);
					END;
				ELSE
					res := Files.FileNotFound;
				END;
			ELSE
				KernelLog.String("Invalid filename: "); KernelLog.String(name); KernelLog.Ln;
				res := Files.FileNotFound;
			END;
		END Delete0;

		PROCEDURE DeleteFile(inode : Inode; inodeAdr : LONGINT; VAR res : LONGINT);
		BEGIN
			DeleteDnodes(inode, res);
			bitmap.FreeBlock(inodeAdr, res);
		END DeleteFile;

		PROCEDURE DeleteDnodes(inode : Inode; VAR res : LONGINT);
		VAR i : LONGINT; finished : BOOLEAN;
		BEGIN
			finished := FALSE;
			(* mark direct linked blocks as free *)
			i := 0;
			WHILE ~finished & (i < LEN(inode.direct)) DO
				IF (inode.direct[i] # BlockNotAllocated) THEN
					bitmap.FreeBlock(inode.direct[i], res);
					IF (res # Ok) THEN RETURN; END;
				ELSE
					finished := TRUE;
				END;
				INC(i);
			END;
		END DeleteDnodes;

		(** Rename a file. res = 0 indicates success.  End users use Files.Rename instead. *)
		PROCEDURE Rename0*(old, new: ARRAY OF CHAR; f: Files.File; VAR res: LONGINT);
		BEGIN  {EXCLUSIVE}
			res := -1; (* not supported *)
		END Rename0;

		(** Enumerate canonical file names. mask may contain * wildcards.  For internal use only.  End users use Enumerator instead. *)
		PROCEDURE Enumerate0*(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
		VAR i : LONGINT; block : Block; inode : Inode; name : Files.FileName; attributes : SET; time, date, size, res : LONGINT;
		BEGIN {EXCLUSIVE}
			IF( mask # "") THEN
				FOR i := 0 TO LEN(rootDirectory)-1 DO
					IF Strings.Match(mask, rootDirectory[i].name) THEN
						IF (rootDirectory[i].inode # BlockNotAllocated) THEN
							IF (flags # {}) THEN (* enumerate attributes  *)
								volume.ReadBlock(rootDirectory[i].inode, block, res);
								IF (res = Ok) THEN
									inode := SYSTEM.VAL(Inode, block);
									attributes := inode.attributes;
									time := inode.time; date := inode.date;
									size := inode.size;
								ELSE
									KernelLog.String("Enumerate0: Could not read block, res: "); KernelLog.Int(res, 0);
									KernelLog.Ln;
								END;
							END;
							Files.JoinName(prefix, rootDirectory[i].name, name);
							enum.PutEntry(name, attributes, time, date, size);
						ELSIF rootDirectory[i].name # "" THEN
							KernelLog.String("Enumerate0: entry for file "); KernelLog.String(rootDirectory[i].name);
							KernelLog.String(" but file seems to be unallocated."); KernelLog.Ln;
						END;
					END;
				END;
			END;
		END Enumerate0;

		(** Return the unique non-zero key of the named file, if it exists. *)
		PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
		VAR key, index : LONGINT;
		BEGIN {EXCLUSIVE}
			key := 0;
			IF (name # "") THEN
				index := FindEntry(name);
				IF (index >= 0) THEN
					key := rootDirectory[index].inode;
				END;
			END;
			RETURN key;
		END FileKey;

		(** Create a new directory structure. May not be supported by the actual implementation.
			End users use Files.CreateDirectory instead.*)
		PROCEDURE CreateDirectory0*(name: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			res := -1; (* not supported *)
		END CreateDirectory0;

		(** Remove a directory. If force=TRUE, any subdirectories and files should be automatically deleted.
			End users use Files.RemoveDirectory instead. *)
		PROCEDURE RemoveDirectory0*(name: ARRAY OF CHAR; force: BOOLEAN; VAR key, res: LONGINT);
		BEGIN {EXCLUSIVE}
			res := -1; (* not supported *)
		END RemoveDirectory0;

		(* format a volume for using this file system *)
		PROCEDURE Format(VAR res : LONGINT);
		VAR block : Block; i : LONGINT;
		BEGIN {EXCLUSIVE}
			(* Volume layout - SuperBlock is block 0 *)
			superBlock.magicNumber := SSFS_MagicNumber;
			superBlock.version := SSFS_Version;
			superBlock.rootDirectory := 1;
			superBlock.freeBlockBitmapFirst := 2;
			(* number of file system blocks for the bitmap incl rounding *)
			superBlock.freeBlockBitmapSize := (volume.nofBlocks + BlockSize-1) DIV BlockSize;
			superBlock.firstDataBlock := superBlock.freeBlockBitmapFirst + superBlock.freeBlockBitmapSize;
			(* some initialization of the unused regions *)
			FOR i := 0 TO LEN(superBlock.filler)-1 DO superBlock.filler[i] := 0X; END;
			(* now write the superblock *)
			volume.WriteBlock(Offset_SuperBlock, SYSTEM.VAL(Block, superBlock), res);

			IF Trace THEN
				KernelLog.String("Fomat information: "); KernelLog.Ln;
				KernelLog.String("SSFS Version: "); KernelLog.Int(superBlock.version, 0); KernelLog.Ln;
				KernelLog.String("Root Directory Block: "); KernelLog.Int(superBlock.rootDirectory, 0); KernelLog.Ln;
				KernelLog.String("Free Block Bitmap Start: "); KernelLog.Int(superBlock.freeBlockBitmapFirst, 0); KernelLog.Ln;
				KernelLog.String("Free Block Bitmap Size: "); KernelLog.Int(superBlock.freeBlockBitmapSize, 0); KernelLog.Ln;
				KernelLog.String("First Data Block: "); KernelLog.Int(superBlock.firstDataBlock, 0); KernelLog.Ln;
			END;
			(* clear directory *)
			IF (res = Ok) THEN
				ClearBlock(block);
				volume.WriteBlock(superBlock.rootDirectory, block, res);
				(* Clear the free block bitmap *)
				FOR i := 0 TO superBlock.freeBlockBitmapSize-1 DO
					volume.WriteBlock(superBlock.freeBlockBitmapFirst + i, block, res);
					IF (res # Ok) THEN
						RETURN;
					END;
				END;
			END;

		END Format;

		(* finalizer: called when the filesystem goes down, could be used to close all open files and flush cashes. We do not use any caches in this silly file system  *)
		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			volume.Finalize;
		END Finalize;

	END FileSystem;

TYPE

	File = OBJECT(Files.File)
	VAR
		inode : Inode;
		inodeModified : BOOLEAN; (* inode modified? *)

		fileSystem : FileSystem;
		name : Files.FileName;

		PROCEDURE &Init*(CONST name : ARRAY OF CHAR; inode : Inode; inodeAddress : LONGINT; fileSystem : FileSystem);
		BEGIN
			ASSERT((name # "")  & (fileSystem # NIL) & (fileSystem.volume # NIL));
			COPY(name, SELF.name);
			SELF.inode := inode;
			key := inodeAddress;
			SELF.fileSystem := fileSystem;
			SELF.fs := fileSystem;
		END Init;

		(** Position a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file.
		A Rider cannot be positioned beyond the end of a file. *)
		PROCEDURE Set*(VAR r: Files.Rider; pos: LONGINT);
		BEGIN {EXCLUSIVE}
			r.res := Ok; r.eof := FALSE; r.fs := fs; r.file := SELF;
			IF (pos < 0) THEN
				pos := 0;
			ELSIF (pos < inode.size) THEN
				r.apos := pos MOD BlockSize; r.bpos := pos DIV BlockSize;
			ELSE (* position beyond end of file -> set to end of file *)
				r.apos := inode.size MOD BlockSize; r.bpos := inode.size DIV BlockSize;
			END;
		END Set;	(* abstract *)

		(** Return the offset of a Rider positioned on a file. *)

		PROCEDURE Pos*(VAR r:  Files.Rider): LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
			RETURN r.apos + BlockSize * r.bpos;
		END Pos;	(* abstract *)

		(** Read a byte from a file, advancing the Rider one byte further.  R.eof indicates if the end of the file has been passed. *)
		PROCEDURE Read*(VAR r: Files.Rider; VAR x: CHAR);
		VAR a: ARRAY 1 OF CHAR;
		BEGIN
			ReadBytes(r, a, 0, 1); x := a[0];
		END Read;

		(** Read a sequence of len bytes into the buffer x at offset ofs, advancing the Rider.
		Less bytes will be read when reading over the end of the file.
		r.res indicates the number of unread bytes. x must be big enough to hold all the bytes. *)
		PROCEDURE ReadBytes*(VAR r:  Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR dnode : Dnode; dataLeft, nofBytes, pos, res : LONGINT; eof : BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
			ASSERT(LEN(x) >= ofs + len); (* buffer big enough *)
			eof := FALSE;
			LOOP
				IF (len = 0) THEN (* all data read *)
					EXIT;
				ELSIF (r.bpos < LEN(inode.direct)) & (inode.direct[r.bpos] # BlockNotAllocated) THEN
					fileSystem.volume.ReadBlock(inode.direct[r.bpos], dnode, res);
					IF (res = Ok) THEN
						(* determine the number of bytes to be read from this dnode *)
						dataLeft := BlockSize - r.apos; (* data in this dnode starting at offset r.apos *)
						IF (len < dataLeft) THEN
							nofBytes := len;
						ELSE
							nofBytes := dataLeft;
						END;

						(* check against file length *)
						pos := r.bpos * BlockSize + r.apos;
						IF (pos + nofBytes > inode.size) THEN
							nofBytes := inode.size - pos;
							IF (nofBytes < 0) THEN nofBytes := 0; END;
							eof := TRUE;
						END;

						SYSTEM.MOVE(ADDRESSOF(dnode[r.apos]), ADDRESSOF(x[ofs]), nofBytes);

						len := len - nofBytes;
						ofs := ofs + len;
						r.apos := (r.apos + nofBytes) MOD BlockSize;
						IF (nofBytes = dataLeft) THEN
							r.bpos := r.bpos + 1; (* rider positioned at next dnode now *)
						END;
						IF eof THEN
							r.eof := TRUE;
							EXIT;
						END;
					ELSE (* error: could not read dnode *)
						r.res := res;
						EXIT;
					END;
				ELSE (* no more dnodes -> end of file reached *)
					r.eof := TRUE;
					EXIT;
				END;
			END;
			r.res := len;
		END ReadBytes;

		(** Write a byte into the file at the Rider position, advancing the Rider by one. *)
		PROCEDURE Write*(VAR r:  Files.Rider; x: CHAR);
		VAR a: ARRAY 1 OF CHAR;
		BEGIN
			a[0] := x; WriteBytes(r, a, 0, 1);
		END Write;

		(** Write the buffer x containing len bytes (starting at offset ofs) into a file at the Rider position. *)
		PROCEDURE WriteBytes*(VAR r: Files.Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR dnode : Dnode; blockNumber, spaceLeft, nofBytes, pos, res : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
			ASSERT(r.bpos * BlockSize + r.apos <= inode.size); (* rider not positioned beyond end of file *)
			LOOP
				IF (len = 0) THEN (* all data written *)
					EXIT;
				ELSE
					ASSERT(r.bpos < LEN(inode.direct)); (* file not getting bigger than maximum file size *)

					(* allocate or load dnode we want to write to *)
					IF (inode.direct[r.bpos] = BlockNotAllocated) THEN
						blockNumber := fileSystem.bitmap.AllocateBlock(res);
						IF (res = Ok) THEN
							ClearBlock(dnode);
							inode.direct[r.bpos] := blockNumber;
							inodeModified := TRUE;
						ELSE
							r.res := res;
							EXIT;
						END;
					ELSE
						blockNumber := inode.direct[r.bpos];
						fileSystem.volume.ReadBlock(blockNumber, dnode, res);
						IF (res # Ok) THEN
							r.res := res;
							EXIT;
						END;
					END;
					ASSERT(blockNumber >= fileSystem.superBlock.firstDataBlock);

					(* determine how much bytes we write to this dnode *)
					spaceLeft := BlockSize - r.apos;
					IF (len < spaceLeft) THEN
						nofBytes := len;
					ELSE
						nofBytes := spaceLeft;
					END;

					SYSTEM.MOVE(ADDRESSOF(x[ofs]), ADDRESSOF(dnode[r.apos]), nofBytes);

					fileSystem.volume.WriteBlock(blockNumber, dnode, res);
					IF (res = Ok) THEN
						len := len - nofBytes;
						ofs := ofs + nofBytes;
						r.apos := (r.apos + nofBytes) MOD BlockSize;
						IF (r.apos = 0) THEN
							INC(r.bpos);
							IF (r.bpos >= LEN(inode.direct)) THEN (* maximum file size reached *)
								DEC(r.bpos);
								r.eof := TRUE;
								KernelLog.String("Maximum file length reached."); KernelLog.Ln;
								EXIT;
							END;
						END;
					ELSE
						r.res := res;
						EXIT;
					END;
				END;
			END;
			pos := r.bpos * BlockSize + r.apos;
			IF (pos > inode.size) THEN
				inode.size := pos;
				inodeModified := TRUE;
			END;
			r.res := len;
		END WriteBytes;

		(** Return the current length of a file. *)
		PROCEDURE Length*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN inode.size;
		END Length;

		(** Return the time (t) and date (d) when a file was last modified. *)
		PROCEDURE GetDate*(VAR t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			t := inode.time; d := inode.date;
		END GetDate;

		(** Set the modification time (t) and date (d) of a file. *)
		PROCEDURE SetDate*(t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			inode.time := t; inode.date := d;
			inodeModified := TRUE;
		END SetDate;

		(** Return the canonical name of a file. *)
		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			Files.JoinName(fileSystem.prefix, SELF.name, name)
		END GetName;

		(** Register a file created with New in the directory, replacing the previous file in the directory with the same name.
		The file is automatically updated.  End users use Files.Register instead. *)
		PROCEDURE Register0*(VAR res: LONGINT);
		BEGIN
			Update;
		END Register0;

		(** Flush the changes made to a file from its buffers. Register0 will automatically update a file. *)
		PROCEDURE Update*;
		BEGIN {EXCLUSIVE}
			IF inodeModified THEN
				ASSERT(key >= fileSystem.superBlock.firstDataBlock);
				fileSystem.UpdateInode(inode, key);
			END;
		END Update;

	END File;

PROCEDURE ClearBlock(VAR block : Block);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(block)-1 DO
		block[i] := 0X;
	END;
END ClearBlock;

PROCEDURE ClearInode(VAR inode : Inode);
VAR i : LONGINT;
BEGIN
	inode.size := 0;
	inode.attributes := {};
	inode.date := 0; inode.time := 0;
	FOR i := 0 TO LEN(inode.direct)-1 DO inode.direct[i] := 0; END;
END ClearInode;

PROCEDURE GetFileSystem(context : Commands.Context; VAR res : LONGINT) : FileSystem;
VAR
	devPart, devicename : ARRAY 64 OF CHAR; partition : LONGINT;
	device : Disks.Device;
	plugin : Plugins.Plugin;
	volume : Volume;
	fileSystem : FileSystem;

	(* Splits up string device#partition into devicename string and partition number *)
	PROCEDURE ParseDevPart(CONST devPart : ARRAY OF CHAR; VAR devicename : ARRAY OF CHAR; VAR partition : LONGINT) : BOOLEAN;
	VAR stringArray : Strings.StringArray;
	BEGIN
		stringArray := Strings.Split(devPart, "#");
		IF (LEN(stringArray) = 2) THEN
			COPY(stringArray[0]^, devicename);
			Strings.StrToInt(stringArray[1]^, partition);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END ParseDevPart;

BEGIN
	fileSystem := NIL;
	IF context.arg.GetString(devPart) & ParseDevPart(devPart, devicename, partition) THEN
		plugin := Disks.registry.Get(devicename);
		IF (plugin # NIL) & (plugin IS Disks.Device) THEN
			device := plugin (Disks.Device);
			device.Open(res);
			IF (res = Disks.Ok) THEN
				IF (device.table # NIL) & (partition < LEN(device.table)) THEN
					IF ~(Disks.Mounted IN device.table[partition].flags) THEN
						NEW(volume, device, partition, res);
						IF (res = Ok) THEN
							NEW(fileSystem, volume, res);
							IF (res # Ok) & (res # NotFormatted) THEN
								fileSystem := NIL;
								context.error.String("Could not mount file system, res: "); context.error.Ln;
							END;
						ELSE
							(* res set by NEW(volume,...) *)
							context.error.String("Could not create volume, res: "); context.error.Int(res, 0); context.error.Ln;
						END;
					ELSE
						res := DeviceError;
						context.error.String("Partition is already mounted."); context.error.Ln;
					END;
				ELSE
					res := DeviceError;
					context.error.String("Partition "); context.error.Int(partition, 0); context.error.String(" not available on device ");
					context.error.String(devicename); context.error.Ln;
				END;
			ELSE
				(* res set by device.Open(res) *)
				context.error.String("Could not open device "); context.error.String(devicename); context.error.String(", res: ");
				context.error.Int(res, 0); context.error.Ln;
			END;
		ELSE
			res := DeviceNotFound;
			context.error.String("Device "); context.error.String(devicename); context.error.String(" not found.");
			context.error.Ln;
		END;
	ELSE
		res := DeviceNotFound;
		context.error.String("Expected device#partition argument."); context.error.Ln;
	END;
	RETURN fileSystem;
END GetFileSystem;

(** Format the specified disk or partition with the SSFS file system *)
PROCEDURE Format*(context : Commands.Context); (** device#partition ~ *)
VAR fileSystem : FileSystem; res : LONGINT;
BEGIN
	fileSystem := GetFileSystem(context, res);
	IF (res = Ok) OR (res = NotFormatted) THEN
		fileSystem.Format(res);
		fileSystem.Finalize;
		IF (res = Ok) THEN
			context.out.String("Disk formatted."); context.out.Ln;
		ELSE
			context.error.String("Formatting disk failed, res: "); context.out.Int(res, 0); context.error.Ln;
		END;
	END;
END Format;

(** Mount the specified SSFS file system *)
PROCEDURE Mount*(context : Commands.Context); (** prefix device#partition ~*)
VAR prefix : Files.Prefix; fileSystem : FileSystem; res : LONGINT;
BEGIN
	IF context.arg.GetString(prefix) THEN
		IF (Files.This(prefix) = NIL) THEN
			fileSystem := GetFileSystem(context, res);
			IF (res = Ok) THEN
				Files.Add(fileSystem, prefix);
				context.out.String(prefix); context.out.String(" mounted."); context.out.Ln;
			ELSE
				(* error message by GetFileSystem procedure *)
			END;
		ELSE
			context.error.String("Prefix "); context.error.String(prefix); context.error.String(" is already used.");
			context.error.Ln;
		END;
	ELSE
		context.error.String("Usage: SSFS.Mount prefix device#partition ~"); context.error.Ln;
	END;
END Mount;

(** Unmount the specified SSFS file system *)
PROCEDURE Unmount*(context : Commands.Context); (** prefix ~ *)
VAR prefix : Files.Prefix; filesystem : Files.FileSystem;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(prefix);
	filesystem := Files.This(prefix);
	IF (filesystem # NIL) THEN
		IF (filesystem IS FileSystem) THEN
			IF Trace THEN filesystem(FileSystem).bitmap.Show; END;
			Files.Remove(filesystem);
			context.out.String(prefix); context.out.String(" ummounted."); context.out.Ln;
		ELSE
			context.error.String(prefix); context.error.String(" is not a SSFS file system."); context.error.Ln;
		END;
	ELSE
		context.error.String(prefix); context.error.String(" not found"); context.error.Ln;
	END
END Unmount;

BEGIN
	ASSERT(BlockSize MOD DirectoryEntrySize = 0); (* we don't want that directory entries spawn blocks *)
END SSFS.

SystemTools.Free SSFS ~

SSFS.Format Test0#0 ~

SSFS.Mount SSFS Test0#0 ~

SSFS.Unmount SSFS ~

VirtualDisks.Create SSFS.Dsk 8000 512 ~

FSTools.DeleteFiles SSFS.Dsk ~

VirtualDisks.Install Test0 Test.Dsk ~

VirtualDisks.Uninstall Test0 ~
