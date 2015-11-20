(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE FATFiles;	(** AUTHOR "be"; PURPOSE "FAT file systems" *)

IMPORT SYSTEM, Kernel, Modules, Strings, UTF8Strings, Files, FATVolumes, Clock, KernelLog;

CONST
	moduleName = "FATFiles: ";

	Ok* = FATVolumes.Ok;
	NotAssigned = FATVolumes.EOC; (* must be -1 *)
	PathDelimiter = Files.PathDelimiter;

	EOC = FATVolumes.EOC;
	FREE = FATVolumes.FREE;

	ErrReadOnly* = FATVolumes.ErrReadOnly;
	ErrInvalidParams* = FATVolumes.ErrInvalidParams;
	ErrIOError* = FATVolumes.ErrIOError;
	ErrFileReadOnly* = 2921;
	ErrParentNotFound* = 2922;
	ErrInvalidFilename* = 2923;
	ErrTooManySimilarFiles* = 2924;
	ErrRootDirFull* = 2925;
	ErrFileNotFound* = 2926;
	ErrFileExists* = 2927;
	ErrHasOpenFiles* = 2928;
	ErrNoRelativePaths* = 2929;
	ErrDirectoryProtection* = 2930;
	ErrDirectoryNotEmpty* = 2931;
	ErrNotADirectory* = 2932;
	ErrDirectoryOpen* = 2933;

	MaxFilenameLen* = 3*255 + 1;	(** max. 255 characters (UTF8) plus 0X *)

	faReadOnly* = 0;
	faHidden* = 1;
	faSystem* = 2;
	faVolumeID* = 3;
	faDirectory* = 4;
	faArchive* = 5;
	faLongName = 15; (* = { faReadOnly, faHidden, faSystem, faVolumeID } *)
	faValidMask = {faReadOnly, faHidden, faSystem, faArchive};	(* attributes that can be set by the user *)

	WriteProtected = {faReadOnly, faSystem};	(* files containing one of these flags are automatically write-protected *)

	deFree = 0E5X;
	deLast = 0X;

TYPE
	Address = Files.Address;
	Filename* = ARRAY MaxFilenameLen OF CHAR;
	Shortname = ARRAY 12 OF CHAR;

	Parameter* = POINTER TO RECORD END;

	EnumParam = POINTER TO RECORD(Parameter)
		flags: SET;
		mask, path: Filename;
		enum: Files.Enumerator
	END;

	CountFiles = POINTER TO RECORD(Parameter)
		count: LONGINT;
	END;

	SearchByName = OBJECT
		VAR directory: Address; name: Filename; found: File;

		PROCEDURE &Init*(Directory: Address; Name: Filename);
		BEGIN
			directory := Directory; UTF8Strings.UpperCase(Name, name)
		END Init;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		VAR filename: Filename;
		BEGIN
			UTF8Strings.UpperCase(f(File).long, filename);
			IF (directory = f(File).parent) & (name = filename) THEN found := f(File) END;
			cont := (found = NIL)
		END EnumFile;
	END SearchByName;

	SearchByCluster = OBJECT
		VAR cluster: Address; found: File;

		PROCEDURE &Init*(Cluster: Address);
		BEGIN cluster := Cluster
		END Init;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN
			IF (cluster = f(File).cluster) THEN found := f(File) END;
			cont := (found = NIL)
		END EnumFile;
	END SearchByCluster;

	FilePurger = OBJECT
		VAR count: LONGINT;
		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		VAR res: LONGINT;
		BEGIN ASSERT(~f(File).registered);
			KernelLog.Enter;
			KernelLog.String(moduleName); KernelLog.String("purging anonymous file '"); KernelLog.String(f(File).long); KernelLog.String("'...");
			KernelLog.Exit;
			f(File).DeleteClusterChain(res); (* ignore res *)
			INC(count); cont := TRUE
		END EnumFile;
	END FilePurger;

	FileUpdater = OBJECT
		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN f(File).Update; cont := TRUE
		END EnumFile;
	END FileUpdater;

	FileEnumerator = OBJECT
		VAR
			count: LONGINT;
			directory: Address;

		PROCEDURE &Init*(dir: Address);
		BEGIN directory := dir; count := 0
		END Init;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN IF (f(File).parent = directory) OR (directory = NotAssigned) THEN INC(count) END; cont := TRUE
		END EnumFile;
	END FileEnumerator;

	FileSystem* = OBJECT(Files.FileSystem)
		VAR
			rootDir-: Directory;
			openFiles, anonymousFiles: Kernel.FinalizedCollection;	(* contains open files with length 0 *)
			fileKey: LONGINT;

		PROCEDURE &Init*;
		BEGIN fileKey := -1; NEW(openFiles); NEW(anonymousFiles)
		END Init;

		PROCEDURE Initialize;
		VAR b: BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(vol # NIL); rootDir := NIL;
			b := SetRootDirectoryX("")	(* ignore result *)
		END Initialize;

		(* Finalize the file system. *)
		PROCEDURE Finalize;
		VAR purge: FilePurger; update: FileUpdater;
		BEGIN {EXCLUSIVE}
			NEW(purge); purge.count := 0;
			anonymousFiles.Enumerate(purge.EnumFile);
			IF (purge.count # 0) THEN
				KernelLog.Enter;
				KernelLog.String(moduleName); KernelLog.Int(purge.count, 0); KernelLog.String(" anonymous files purged. ");
				KernelLog.Exit
			END;
			NEW(update);
			openFiles.Enumerate(update.EnumFile);
			vol.Finalize;
			Finalize^;	(* see note in Files *)
			(* do not release exclusive lock ! *)
		END Finalize;

		PROCEDURE GetNextFileKey(): LONGINT;
		BEGIN
			DEC(fileKey);
			RETURN fileKey
		END GetNextFileKey;

		PROCEDURE SetRootDirectory*(name: ARRAY OF CHAR): BOOLEAN;
		BEGIN {EXCLUSIVE} RETURN SetRootDirectoryX(name)
		END SetRootDirectory;

		PROCEDURE SetRootDirectoryX(name: ARRAY OF CHAR): BOOLEAN;
		VAR dir1216: RootDirectory1216; dir32: RootDirectory32; f: File;
		BEGIN
			IF (name = "") THEN	(* default root *)
				IF (vol IS FATVolumes.FAT1216Volume) THEN
					NEW(dir1216, SELF); dir1216.cluster := 0;
					rootDir := dir1216
				ELSIF (vol IS FATVolumes.FAT32Volume) THEN
					NEW(dir32, SELF); dir32.cluster := vol(FATVolumes.FAT32Volume).rootCluster;
					rootDir := dir32; COPY(Files.PathDelimiter, rootDir.long)
				END;
				rootDir.long := ""; rootDir.parent := NotAssigned; rootDir.key := -1
			ELSE
				f := OldX(name);
				IF (f # NIL) & (f IS Directory) THEN rootDir := f(Directory)
				ELSE RETURN FALSE
				END
			END;
			rootDir.long := ""; rootDir.parent := NotAssigned; rootDir.key := -1;
			RETURN TRUE
		END SetRootDirectoryX;

		(* Create a new file with the specified name.  End users use Files.New instead. *)
		PROCEDURE New0*(name: ARRAY OF CHAR): Files.File;
		VAR path, filename: Filename; dir: Directory; f: File;
		BEGIN {EXCLUSIVE}
			IF UTF8Strings.Valid(name) THEN
				Files.SplitPath(name, path, filename);
				IF ((filename = "") OR ValidateName(filename)) THEN
					IF (path # "") THEN
						UTF8Strings.UpperCase(path, path);
						dir := FindDirectory(path)
					ELSE dir := rootDir
					END;

					IF (dir # NIL) THEN
						NEW(f, SELF);
						COPY(filename, f.long); f.attr := {}; f.NTres := 0X;
						f.cluster := EOC; f.parent := dir.cluster; f.size := 0;
						Clock.Get(f.time, f.date);
						f.writeTime := f.time; f.writeDate := f.date; f.accessDate := f.date;
						f.modH := TRUE; f.modName := TRUE; f.registered := FALSE;
						f.entry.len := NotAssigned; f.entry.ofs := NotAssigned;
						f.key := 0;
						anonymousFiles.Add(f, PurgeFile); openFiles.Add(f, NIL)
					END
				END
			END;
			RETURN f
		END New0;

		(* Open an existing file. The same file descriptor is returned if a file is opened multiple times.  End users use Files.Old instead. *)
		PROCEDURE Old0*(name: ARRAY OF CHAR): Files.File;
		BEGIN {EXCLUSIVE} RETURN OldX(name)
		END Old0;

		PROCEDURE OldX(name: ARRAY OF CHAR): File;
		VAR path, filename: Filename; dir: Directory; f: File;
		BEGIN
			IF UTF8Strings.Valid(name) THEN
				UTF8Strings.UpperCase(name, name);
				IF (name = PathDelimiter) THEN RETURN rootDir
				ELSE
					Files.SplitPath(name, path, filename);
					IF ValidateName(filename) THEN
						IF (path # "") THEN dir := FindDirectory(path)
						ELSE dir := rootDir
						END;

						IF (dir # NIL) THEN
							f := dir.Find(filename);
							IF (f # NIL) THEN
								openFiles.Add(f, NIL);
								IF (f.cluster = 0) THEN
									(* we don't need to check if this file is open since Files.Old already checks this *)
									f.key := GetNextFileKey();
									f.cluster := EOC
								ELSE
									f.key := f.cluster
								END
							END
						END
					END
				END
			END;
			RETURN f
		END OldX;

		(** Delete a file. res = 0 indicates success.  End users use Files.Delete instead. *)
		PROCEDURE Delete0*(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		BEGIN {EXCLUSIVE} Delete0X(name, key, res)
		END Delete0;

		PROCEDURE Delete0X(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		VAR path, filename: Filename; dir: Directory; f: File; s: SearchByName; dcc: BOOLEAN;
		BEGIN
			res := ErrInvalidFilename; key := 0;
			IF UTF8Strings.Valid(name) THEN
				UTF8Strings.UpperCase(name, name);
				Files.SplitPath(name, path, filename);
				IF ValidateName(filename) THEN
					res := ErrFileNotFound;
					IF (path # "") THEN dir := FindDirectory(path)
					ELSE dir := rootDir
					END;

					IF (dir # NIL) THEN
						res := ErrFileNotFound;

						NEW(s, dir.cluster, filename); openFiles.Enumerate(s.EnumFile);
						IF (s.found # NIL) THEN f := s.found; dcc := FALSE
						ELSE f := dir.Find(filename); dcc := TRUE
						END;

						IF (f # NIL) THEN
							IF (f IS Directory) & (f.attr * WriteProtected # {}) THEN res := ErrDirectoryProtection
							ELSE
								IF (f.attr * WriteProtected = {}) THEN
									key := f.key;
									IF dcc THEN	(* file is not open, remove cluster chain *)
										f.DeleteClusterChain(res);	(* ignore res *)
										anonymousFiles.Remove(f)
									ELSE	(* file is open and now anonymous *)
										anonymousFiles.Add(f, PurgeFile)
									END;
									dir.RemoveFileHeader(f);
									res := Ok
								ELSE res := ErrFileReadOnly
								END
							END
						END
					END
				END
			END
		END Delete0X;

		(* Rename a file. res = 0 indicates success.  End users use Files.Rename instead. *)
		PROCEDURE Rename0*(old, new: ARRAY OF CHAR; f: Files.File; VAR res: LONGINT);
		VAR oldpath, oldname, newpath, newname: Filename; r: File; dir: Directory; s: SearchByName;
		BEGIN {EXCLUSIVE}
			res := ErrInvalidFilename;
			IF UTF8Strings.Valid(old) & UTF8Strings.Valid(new) THEN
				Files.SplitPath(old, oldpath, oldname);
				Files.SplitPath(new, newpath, newname);
				IF ((oldpath = newpath) OR (newpath = "")) & ValidateName(newname) THEN
					IF (f = NIL) THEN f := OldX(old)
					ELSIF ~(f IS File) THEN HALT(ErrInvalidParams)
					END;
					IF (f # NIL) THEN
						r := OldX(new);
						IF (r # NIL) THEN (* replace existing file *)
							IF (r IS Directory) THEN res := ErrDirectoryProtection; RETURN
							ELSE
								NEW(s, r.parent, r.long); openFiles.Enumerate(s.EnumFile);
								IF (s.found = NIL) THEN r.DeleteClusterChain(res) END; (* file not open, remove cluster chain (ignore res) *)

								IF r.registered THEN	(* remove file header *)
									dir := GetDirectoryX(r.parent);
									dir.RemoveFileHeader(r)
								END
							END
						END;

						COPY(newname, f(File).long);
						f(File).modH := TRUE; f(File).modName := TRUE;
						f.Update;
						res := Ok
					ELSE res := ErrFileNotFound
					END
				END
			END
		END Rename0;

		(* Enumerate canonical file names. mask may contain * wildcards.  For internal use only.  End users use Enumerator instead. *)
		PROCEDURE Enumerate(file: File; par: Parameter): BOOLEAN;
		VAR name: Filename; len: LONGINT; flags: SET;
		BEGIN
			WITH par: EnumParam DO
				UTF8Strings.UpperCase(file.long, name);
				IF (par.mask = "") OR Strings.Match(par.mask, name) THEN
					Strings.Concat(par.path, file.long, name);
					IF (faDirectory IN file.attr) THEN len := 0; flags := { Files.Directory }
					ELSE len := file.Length(); flags := {}
					END;
					par.enum.PutEntry(name, flags, file.writeTime, file.writeDate, len)
				END;
				RETURN TRUE
			END
		END Enumerate;

		PROCEDURE Enumerate0*(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
		VAR d: Directory; path: Filename; par: EnumParam;
		BEGIN {EXCLUSIVE}
			IF UTF8Strings.Valid(mask) THEN
				NEW(par); par.flags := flags; par.enum := enum; par.mask := "";

				UTF8Strings.UpperCase(mask, mask);
				d := FindDirectory(mask);
				IF (d = NIL) THEN
					Files.SplitPath(mask, path, par.mask);
					IF (path # "") THEN d := FindDirectory(path)
					ELSE d := rootDir
					END
				END;

				IF (d # NIL) THEN
					d.GetFullName(par.path, TRUE);
					d.Enumerate(Enumerate, par)
				END
			END
		END Enumerate0;

		(* Return the unique non-zero key of the named file, if it exists. *)
		PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
		VAR s: SearchByName; path, filename: Filename; dir: Directory; f: File; key: LONGINT;
		BEGIN {EXCLUSIVE}
			IF UTF8Strings.Valid(name) THEN
				UTF8Strings.UpperCase(name, name);
				Files.SplitPath(name, path, filename);
				IF ValidateName(filename) THEN
					IF (path # "") THEN dir := FindDirectory(path)
					ELSE dir := rootDir
					END;

					IF (dir # NIL) THEN
						f := dir.Find(filename);
						IF (f # NIL) THEN
							IF (f.cluster = 0) THEN
								NEW(s, dir.cluster, filename); openFiles.Enumerate(s.EnumFile);
								IF (s.found # NIL) THEN key := s.found.key END
							ELSE key := f.cluster
							END
						END
					END
				END
			END;
			RETURN key
		END FileKey;

		PROCEDURE CreateDirectory0*(path: ARRAY OF CHAR; VAR res: LONGINT);
		VAR f: File; d: Directory; i,j: LONGINT; name: Filename; lookup: BOOLEAN; s: SearchByName;
		BEGIN {EXCLUSIVE}
			IF (Files.ReadOnly IN vol.flags) THEN res := ErrReadOnly; RETURN END;
			res := ErrFileExists;

			d := rootDir; i := 0; lookup := TRUE;
			IF (path[i] = PathDelimiter) THEN INC(i) END;

			WHILE (path[i] # 0X) & (d # NIL) DO
				j := 0; WHILE (path[i] # 0X) & (path[i] # PathDelimiter) DO name[j] := path[i]; INC(i); INC(j) END;
				name[j] := 0X;
				IF (path[i] = PathDelimiter) THEN INC(i) END;

				IF (name # "") & (name # ".") & (name # "..") THEN
					IF lookup THEN
						NEW(s, d.cluster, name); openFiles.Enumerate(s.EnumFile);
						IF (s.found # NIL) THEN f := s.found;
						ELSE f := d.Find(name)
						END;
					ELSE f := NIL
					END;

					IF (f # NIL) & f.registered THEN
						IF (f IS Directory) THEN d := f(Directory)
						ELSE res := ErrFileExists; d := NIL
						END
					ELSE
						lookup := FALSE;
						IF (f # NIL) THEN (* anonymous directory *)
							f.modH := TRUE; f.modName := TRUE;
							f.Register0(res)
						ELSE
							d := d.NewSubdirectory(name, res)
						END
					END
				ELSE
					IF (name = "") THEN res := ErrInvalidFilename
					ELSE res := ErrNoRelativePaths
					END;
					d := NIL
				END
			END
		END CreateDirectory0;

		PROCEDURE RmDirCallback(f: File; par: Parameter): BOOLEAN;
		BEGIN INC(par(CountFiles).count); RETURN TRUE
		END RmDirCallback;

		PROCEDURE RemoveDirectory0*(path: ARRAY OF CHAR; force: BOOLEAN; VAR key, res: LONGINT);
		VAR f: File; par: CountFiles; s: SearchByName; parent: Directory;
		BEGIN {EXCLUSIVE}
			IF (Files.ReadOnly IN vol.flags) THEN res := ErrReadOnly; RETURN END;
			res := Ok;

			f := OldX(path);
			IF (f # NIL) THEN
				IF (f IS Directory) THEN
					NEW(s, f.parent, f.long); openFiles.Enumerate(s.EnumFile);
					IF (s.found = NIL) OR (s.found = f) THEN
						NEW(par); par.count := 0;
						f(Directory).Enumerate(RmDirCallback, par);

						IF (par.count > 0) THEN
							IF force THEN f(Directory).DeleteContents(res)
							ELSE res := ErrDirectoryNotEmpty
							END
						END;

						IF (res = Ok) THEN
							key := f.key;
							f.DeleteClusterChain(res);
							parent := GetDirectoryX(f.parent);
							parent.RemoveFileHeader(f);
							openFiles.Remove(f);
							anonymousFiles.Remove(f)
						END
					ELSE res := ErrDirectoryOpen
					END
				ELSE res := ErrNotADirectory
				END
			ELSE res := ErrFileNotFound
			END
		END RemoveDirectory0;

		PROCEDURE QuickFormat*(volLabel: ARRAY OF CHAR; VAR res: LONGINT);
		VAR f: File; label: ARRAY 11 OF CHAR; i: LONGINT;
			clean: FileEnumerator; c: CHAR; dummy: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (Files.ReadOnly IN vol.flags) THEN res := ErrReadOnly; RETURN END;

			(* check and copy volume label *)
			res := Ok;
			FOR i := 0 TO 10 DO label[i] := " " END;
			i := 0;
			WHILE (i < 11) & (volLabel[i] # 0X) DO
				c := volLabel[i];
				IF ("a" <= c) & (c <= "z") THEN c := CAP(c) END;
				IF ValidShortChar(c) THEN label[i] := c
				ELSE res := ErrInvalidParams; i := 11
				END;
				INC(i)
			END;

			IF (res = Ok) THEN
				NEW(clean, NotAssigned);
				openFiles.Enumerate(clean.EnumFile);
				IF (clean.count = 0) THEN anonymousFiles.Enumerate(clean.EnumFile) END;
				IF (clean.count = 0) THEN
					vol(FATVolumes.Volume).QuickFormat;
					(* init root *)
					dummy := SetRootDirectoryX("");

					(* write volume label *)
					NEW(f, SELF);
					COPY(label, vol.name);
					COPY(label, f.long);
					f.cluster := NotAssigned; f.attr := {faVolumeID};
					Clock.Get(f.time, f.date);
					f.modH := TRUE; f.modName := TRUE;
					rootDir.firstFreePos := 0;
					rootDir.WriteFileHeader(f);
					res := Ok
				ELSE
					res := ErrHasOpenFiles
				END
			END
		END QuickFormat;

		PROCEDURE FindDirectory(path: ARRAY OF CHAR): Directory;
		VAR dir: Directory; f: File; s: SearchByName;
			pos, k: LONGINT; p: Filename;
		BEGIN
			dir := rootDir; pos := 0;
			IF (path[0] = PathDelimiter) THEN INC(pos) END;
			WHILE (path[pos] # 0X) & (dir # NIL) DO
				k := 0;
				WHILE (path[pos] # PathDelimiter) & (path[pos] # 0X) DO
					p[k] := path[pos];
					INC(k); INC(pos)
				END;
				p[k] := 0X;
				IF (path[pos] = PathDelimiter) THEN INC(pos) END;
				IF (p = ".") OR (p = "..") THEN (* error, relative paths not supported *)
					RETURN NIL
				ELSE (* down *)
					f := dir.Find(p);
					IF (f # NIL) & (f IS Directory) THEN
						NEW(s, f.parent, p); openFiles.Enumerate(s.EnumFile);
						IF (s.found # NIL) THEN dir := s.found(Directory)
						ELSE dir := f(Directory)
						END
					ELSE dir := NIL
					END
				END
			END;
			RETURN dir
		END FindDirectory;

		PROCEDURE GetDirectory(cluster: Address): Directory;
		BEGIN {EXCLUSIVE}
			RETURN GetDirectoryX(cluster)
		END GetDirectory;

		PROCEDURE GetDirectoryX(cluster: Address): Directory;
		VAR dir: Directory; r: Files.Rider; dotdot: ARRAY 3 OF CHAR; s: SearchByCluster;
		BEGIN
			IF (cluster = rootDir.cluster) OR (cluster = 0) THEN dir := rootDir
			ELSE
				(* already open ? *)
				NEW(s, cluster); openFiles.Enumerate(s.EnumFile);

				IF (s.found = NIL) THEN
					NEW(dir, SELF); dir.attr := {faDirectory, faReadOnly};
					dir.cluster := cluster;
					(* make sure directory is valid *)
					dir.Set(r, 32); dir.ReadBytes(r, dotdot, 0, 3);
					IF (dotdot[0] # ".") OR (dotdot[1] # ".") OR (dotdot[2] # " ") THEN dir := NIL
					ELSE openFiles.Add(dir, NIL)
					END
				ELSE
					dir := s.found(Directory)
				END
			END;
			RETURN dir
		END GetDirectoryX;
	END FileSystem;

TYPE
	DirEntry = RECORD
		ofs, len: LONGINT;
	END;

	Buffer = POINTER TO RECORD
		pos: LONGINT; eoc: BOOLEAN;
		cluster: Address;
		data: POINTER TO ARRAY OF CHAR;
	END;

	File* = OBJECT(Files.File)
		(* Files.Rider:
			apos: logical cluster number 0...(#clusters-1) or 'NotAssigned'
			bpos: position within cluster
		*)
		VAR
			short: Shortname;
			long-: Filename;	(** file name *)
			attr: SET;
			NTres: CHAR;
			cluster, parent: Address;	(* 'parent': cluster of directory containing file *)
			size: LONGINT;
			time, date, writeTime-, writeDate-, accessDate-: LONGINT;
			modH, modName: BOOLEAN; (* TRUE if the directory entry needs to be written back to disk, modName is TRUE if the name has changed *)
			writeEOC: BOOLEAN;
			eocCluster: LONGINT;
			entry: DirEntry; (* offset & length of directory entry *)
			registered-: BOOLEAN; (* TRUE if the file is registered in a directory. Possible race ! *)
			clusterSize: LONGINT;
			buffer: Buffer;

		PROCEDURE &Init*(fs: Files.FileSystem);
		BEGIN
			SELF.fs := fs; clusterSize := fs.vol(FATVolumes.Volume).clusterSize; writeEOC := FALSE; eocCluster := NotAssigned;
		END Init;

		(* Position a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file.
			A Rider cannot be positioned beyond the end of a file. *)
		PROCEDURE Set(VAR r: Files.Rider; pos: LONGINT);
		BEGIN {EXCLUSIVE} SetX(r, pos)
		END Set;

		PROCEDURE SetX(VAR r: Files.Rider; pos: LONGINT);
		BEGIN
			r.eof := FALSE; r.res := 0; r.file := SELF; r.fs := fs;
			IF (pos < 0) THEN pos := 0
			ELSIF (pos > size) THEN pos := size
			END;
			r.apos := pos DIV clusterSize;
			r.bpos := pos MOD clusterSize;
			IF (buffer = NIL) THEN
				NEW(buffer); NEW(buffer.data, clusterSize);
				buffer.pos := NotAssigned;
				buffer.eoc := (cluster < 2);
			END;
		END SetX;

		(* Return the offset of a Rider positioned on a file. *)
		PROCEDURE Pos(VAR r: Files.Rider): LONGINT;
		BEGIN RETURN r.apos*clusterSize + r.bpos
		END Pos;

		(* Read logical cluster 'pos', pos=0 is the first cluster. 'pos' must be <= # of clusters in file.
			If pos=# of cluster in file then a new cluster will be allocated when the buffer is written back to disk.
			buf.cluster contains the physical cluster # (>= 2), -(the physical cluster # of the last cluster of the file),
			or EOC if the file has no clusters assigned yet.
		*)
		PROCEDURE ReadBuffer(buffer: Buffer; pos: LONGINT);
		VAR
			last: Address;
			i, res: LONGINT;
			bp, bc, ctrlflow, stopc: LONGINT;
		BEGIN
			ASSERT(buffer.pos # pos);
			bp := buffer.pos; bc := buffer.cluster;
			(* 	We need to find the cluster number <pos> or possible allocate a new cluster and append it to the file's cluster chain.
				Start searching at... *)
			IF (buffer.pos # NotAssigned) & (buffer.pos < pos) THEN
				(* the currently loaded cluster *)
				last := buffer.cluster;
				ctrlflow := 1;
			ELSE
				(* the first cluster of this file *)
				buffer.pos := 0; buffer.cluster := cluster; last := cluster;
				ctrlflow := 2;
			END;
			(* Follow the cluster chain described in the FAT *)
			WHILE (buffer.pos < pos) & (buffer.cluster >= 2) DO
				last := buffer.cluster;
				buffer.cluster := fs.vol(FATVolumes.Volume).ReadFATEntry(last);
				INC(buffer.pos)
			END;
			IF (buffer.pos < pos) THEN stopc := 1 END;
			IF (buffer.cluster >= 2) THEN stopc := stopc + 10 END;

			IF (pos # buffer.pos)  THEN	(* we are going to TRAP, give some additional info to track down the bug *)
				KernelLog.Enter;
				KernelLog.String("ReadBuffer failed"); KernelLog.Ln;
				KernelLog.String("  file: "); KernelLog.String(long); KernelLog.Ln;
				KernelLog.String("  size: "); KernelLog.Int(size, 0); KernelLog.Ln;
				KernelLog.String("  cluster size: "); KernelLog.Int(clusterSize, 0); KernelLog.Ln;
				KernelLog.String("  cluster: "); KernelLog.Int(cluster, 0); KernelLog.Ln;
				KernelLog.String("  parent: "); KernelLog.Int(parent, 0); KernelLog.Ln;
				KernelLog.String("  requested position: "); KernelLog.Int(pos, 0); KernelLog.Ln;
				KernelLog.String("  buffer.pos on entry: "); KernelLog.Int(bp, 0); KernelLog.Ln;
				KernelLog.String("  buffer.cluster on entry: "); KernelLog.Int(bc, 0); KernelLog.Ln;
				KernelLog.String("  control flow: "); KernelLog.Int(ctrlflow, 0); KernelLog.Ln;
				KernelLog.String("  stop condition: "); KernelLog.Int(stopc, 0); KernelLog.Ln;
				KernelLog.String("  buffer.pos: "); KernelLog.Int(buffer.pos, 0); KernelLog.Ln;
				KernelLog.String("  buffer.cluster: "); KernelLog.Int(buffer.cluster, 0); KernelLog.Ln;
				KernelLog.String("  buffer.eoc: "); KernelLog.Boolean(buffer.eoc); KernelLog.Ln;
				KernelLog.String("  last: "); KernelLog.Int(last, 0); KernelLog.Ln;
				KernelLog.String("  cluster chain:"); KernelLog.Int(cluster, 0); KernelLog.Char(" ");
				bp := cluster;
				WHILE (bp >= 2) DO
					bp := fs.vol(FATVolumes.Volume).ReadFATEntry(bp);
					KernelLog.Int(bp, 0); KernelLog.Char(" ")
				END;
				KernelLog.Ln;
				KernelLog.Exit
			END;

			ASSERT(pos = buffer.pos);
			IF (buffer.cluster = EOC) OR (buffer.cluster = FREE) THEN
				(* Allocate new cluster when writing back the buffer. IF (-last # EOC) & (-last # FREE), create a new FAT entry
					-last -> cluster number of newly allocated buffer *)
				buffer.cluster := -last; (* remember previous cluster (= last cluster of file) *)
				FOR i := 0 TO clusterSize-1 DO buffer.data[i] := 0X END
			ELSE
				(* Just read the existing cluster *)
				fs.vol(FATVolumes.Volume).ReadCluster(buffer.cluster, buffer.data^, res);
				buffer.eoc := FALSE;
				ASSERT(res = Ok)
			END
 		END ReadBuffer;

		(* Write logical cluster. Depending on buf.cluster, a new physical cluster may be allocated. cf. ReadBuffer *)
		PROCEDURE WriteBuffer(buffer: Buffer);
		VAR link: Address; res: LONGINT;
		BEGIN
			IF (buffer.cluster < 2) THEN	(* allocate new cluster *)
				IF (buffer.cluster = -EOC) THEN link := FATVolumes.FREE
				ELSE link := -buffer.cluster; ASSERT(link >= 2)
				END;
				buffer.cluster := fs.vol(FATVolumes.Volume).AllocCluster(link, res);
				IF (res # Ok) THEN
					IF (res = FATVolumes.ErrDiskFull) THEN
						KernelLog.Enter; KernelLog.String(fs.prefix); KernelLog.String(": disk full"); KernelLog.Exit;
						HALT(FATVolumes.ErrDiskFull)
					ELSE HALT(ErrIOError)
					END
				END;
				buffer.eoc := TRUE;
				IF (link = FATVolumes.FREE) THEN cluster := buffer.cluster; modH := TRUE END;	(* first cluster of file allocated *)
				writeEOC := TRUE; eocCluster := buffer.cluster
			END;

			ASSERT((buffer.cluster >= 2) & (buffer.pos >= 0) & (LEN(buffer.data) = clusterSize));
			fs.vol(FATVolumes.Volume).WriteCluster(buffer.cluster, buffer.data^, res);
			ASSERT(res = Ok)
		END WriteBuffer;

		(* Read a byte from a file, advancing the Rider one byte further.  R.eof indicates if the end of the file has been passed. *)
		PROCEDURE Read*(VAR r: Files.Rider; VAR x: CHAR);
		BEGIN {EXCLUSIVE} ReadX(r, x)
		END Read;

		PROCEDURE ReadX(VAR r: Files.Rider; VAR x: CHAR);
		BEGIN
			IF (r.apos*clusterSize + r.bpos < size) THEN
				IF (buffer.pos # r.apos) THEN ReadBuffer(buffer, r.apos) END;
				x := buffer.data[r.bpos];
				INC(r.bpos);
				IF (r.bpos = clusterSize) THEN INC(r.apos); r.bpos := 0 END
			ELSE
				x := 0X; r.eof := TRUE
			END
		END ReadX;

		(* Read a sequence of len bytes into the buffer x at offset ofs, advancing the Rider. Less bytes will be read when
			reading over the end of the file. r.res indicates the number of unread bytes. x must be big enough to hold all the bytes. *)
		PROCEDURE ReadBytes(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN {EXCLUSIVE} ReadBytesX(r, x, ofs, len)
		END ReadBytes;

		PROCEDURE ReadBytesX(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR src: ADDRESS; m: LONGINT;
		BEGIN
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END;
			IF len > 0 THEN
				WHILE (len > 0) & (Pos(r) < size) DO
					IF (buffer.pos # r.apos) THEN ReadBuffer(buffer, r.apos) END;
					src := ADDRESSOF(buffer.data[r.bpos]);
					m := Strings.Min(Strings.Min(size - Pos(r), clusterSize - r.bpos), len);
					SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), m);
					INC(ofs, m); DEC(len, m);
					INC(r.bpos, m); ASSERT(r.bpos <= clusterSize);
					IF (r.bpos = clusterSize) THEN INC(r.apos); r.bpos := 0 END;
				END;
				r.res := len; r.eof := Pos(r) = size
			ELSE
				r.res := 0
			END
		END ReadBytesX;

		(* Write a byte into the file at the Rider position, advancing the Rider by one. *)
		PROCEDURE Write*(VAR r: Files.Rider; x: CHAR);
		BEGIN {EXCLUSIVE} WriteX(r, x)
		END Write;

		PROCEDURE WriteX(VAR r: Files.Rider; x: CHAR);
		BEGIN
			IF (attr * WriteProtected # {}) THEN HALT(ErrFileReadOnly) END;
			IF (buffer.pos # r.apos) THEN ReadBuffer(buffer, r.apos) END;
			buffer.data[r.bpos] := x;
			INC(r.bpos);
			IF (r.bpos = clusterSize) THEN INC(r.apos); r.bpos := 0 END;
			IF (Pos(r) > size) THEN
				ASSERT(Pos(r) = size+1); size := Pos(r);
				IF ~(SELF IS Directory) THEN modH := TRUE END
			END;
			WriteBuffer(buffer)
		END WriteX;

		(* Write the buffer x containing len bytes (starting at offset ofs) into a file at the Rider position. *)
		PROCEDURE WriteBytes(VAR r: Files.Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN {EXCLUSIVE} WriteBytesX(r, x, ofs, len)
		END WriteBytes;

		PROCEDURE WriteBytesX(VAR r: Files.Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR dst: ADDRESS; m: LONGINT;
		BEGIN
			IF (attr * WriteProtected # {}) THEN HALT(ErrFileReadOnly) END;
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END;
			IF len > 0 THEN
				WHILE (len > 0) DO
					IF (buffer.pos # r.apos) THEN ReadBuffer(buffer, r.apos) END;
					dst := ADDRESSOF(buffer.data[r.bpos]);
					m := Strings.Min(clusterSize-r.bpos, len);
					SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, m);
					WriteBuffer(buffer);
					INC(ofs, m); DEC(len, m);
					INC(r.bpos, m); ASSERT(r.bpos <= clusterSize);
					IF (r.bpos = clusterSize) THEN INC(r.apos); r.bpos := 0 END;
				END;
				IF (Pos(r) > size) THEN
					size := Pos(r);
					IF ~(SELF IS Directory) THEN modH := TRUE END
				END
			END
		END WriteBytesX;

		(* Return the current length of a file. *)
		PROCEDURE Length(): LONGINT;
		BEGIN
			(* Length() should in principle be exlusive, however it won't do any harm if it is not, it just reflects the
				current size if called from outside. Internal methods that call Length() are exclusive whenever needed *)
			RETURN size
		END Length;

		(* Return the time (t) and date (d) when a file was last modified. *)
		PROCEDURE GetDate*(VAR t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			t := writeTime; d := writeDate;
		END GetDate;

		(* Set the modification time (t) and date (d) of a file. *)
		PROCEDURE SetDate*(t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			writeTime := t; writeDate := d; modH := TRUE;
		END SetDate;

		(** Return the file attributes *)
		PROCEDURE GetAttributes*(): SET;
		BEGIN {EXCLUSIVE}
			RETURN attr
		END GetAttributes;

		(** Set the file attributes *)
		PROCEDURE SetAttributes*(Attr: SET);
		BEGIN {EXCLUSIVE}
			Attr := Attr * faValidMask;
			attr := attr - faValidMask + Attr;
			modH := TRUE
		END SetAttributes;

		(** Adds 'Attr' to the file's attributes *)
		PROCEDURE InclAttribute*(Attr: LONGINT);
		BEGIN {EXCLUSIVE}
			IF (Attr IN faValidMask) & ~(Attr IN attr) THEN
				INCL(attr, Attr);
				modH := TRUE
			END
		END InclAttribute;

		(** Removes 'Attr' from the file's attributes *)
		PROCEDURE ExclAttribute*(Attr: LONGINT);
		BEGIN {EXCLUSIVE}
			IF (Attr IN faValidMask) & (Attr IN attr) THEN
				EXCL(attr, Attr);
				modH := TRUE
			END
		END ExclAttribute;

		(* Return the canonical name of a file. *)
		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN (* {GetFullName is EXCLUSIVE} *)
			GetFullName(name, TRUE)
		END GetName;

		(* Register a file created with New in the directory, replacing the previous file in the directory with the same name.
			The file is automatically updated.  End users use Files.Register instead. *)
		PROCEDURE Register0(VAR res: LONGINT);
		VAR dir: Directory; old: File; s: SearchByName;
		BEGIN {EXCLUSIVE}
			IF ~registered THEN
				dir := fs(FileSystem).GetDirectoryX(parent);
				IF (dir = NIL) THEN HALT(ErrParentNotFound) END; (* uaahhh...this is bad *)
				old := dir.Find(long);
				IF (old # NIL) THEN
					IF (old IS Directory) THEN res := ErrDirectoryProtection; RETURN
					ELSE
						NEW(s, old.parent, old.long); fs(FileSystem).openFiles.Enumerate(s.EnumFile);
						IF (s.found = NIL) THEN old.DeleteClusterChain(res)	(* file not open, remove cluster chain (ignore res) *)
						ELSE (* file open, unregister *)
							old.registered := FALSE;
							fs(FileSystem).anonymousFiles.Add(old, PurgeFile)
						END;

						(* recycle file header, do not dir.RemoveFileHeader(old) ! *)
						entry := old.entry; short := old.short;
						modName := FALSE
					END
				END;

				registered := TRUE;
				UpdateX;
				IF (cluster = NotAssigned) THEN key := fs(FileSystem).GetNextFileKey()
				ELSE key := cluster
				END;
				fs(FileSystem).anonymousFiles.Remove(SELF);
				res := 0
			ELSE
				res := 1
			END
		END Register0;

		(* Flush the changes made to a file from its buffers. Register0 will automatically update a file. *)
		PROCEDURE Update;
		BEGIN {EXCLUSIVE} UpdateX
		END Update;

		PROCEDURE UpdateX;
		VAR dir: Directory;
		BEGIN
			IF registered & modH THEN
				dir := fs(FileSystem).GetDirectoryX(parent);
				IF (dir = NIL) THEN HALT(ErrParentNotFound) END; (* uaahhh...this is bad *)
				dir.WriteFileHeader(SELF)
			END
		END UpdateX;

		PROCEDURE DeleteClusterChain(VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			UpdateX;
			fs.vol(FATVolumes.Volume).FreeClusterChain(cluster, res);
			cluster := NotAssigned; size := 0
		END DeleteClusterChain;

		PROCEDURE GetFullName*(VAR name: ARRAY OF CHAR; WithPrefix: BOOLEAN);
		VAR pos, i: LONGINT;

			PROCEDURE Get(directory: Address);
			VAR dir: Directory; k: LONGINT;
			BEGIN
				dir := fs(FileSystem).GetDirectoryX(directory);
				IF ~(dir = fs(FileSystem).rootDir) THEN
					dir.Initialize;
					Get(dir.parent)
				END;
				k := 0;
				WHILE (dir.long[k] # 0X) & (pos < LEN(name)) DO
					name[pos] := dir.long[k];
					INC(pos); INC(k)
				END;
				IF (pos < LEN(name)) THEN name[pos] := PathDelimiter; INC(pos) END
			END Get;

		BEGIN {EXCLUSIVE}
			pos := 0; i := 0;
			IF WithPrefix THEN
				WHILE (fs.prefix[i] # 0X) & (pos < LEN(name)) DO
					name[pos] := fs.prefix[i];
					INC(pos); INC(i)
				END;
				name[pos] := ":"; INC(pos)
			END;
			IF (SELF = fs(FileSystem).rootDir) THEN
				name[pos] := PathDelimiter; INC(pos)
			ELSIF (pos < LEN(name)) THEN
				Get(parent);
				i := 0;
				WHILE (long[i] # 0X) & (pos < LEN(name)) DO
					name[pos] := long[i];
					INC(pos); INC(i)
				END;
				IF (faDirectory IN attr) & (pos < LEN(name)) THEN
					name[pos] := PathDelimiter; INC(pos)
				END
			END;
			name[Strings.Min(LEN(name)-1, pos)] := 0X
		END GetFullName;

	END File;

TYPE
	NameParam = POINTER TO RECORD(Parameter)
		name: Filename;
		file: File
	END;

	ClusterParam = POINTER TO RECORD(Parameter)
		cluster: Address;
		file: File
	END;

	ResultParam = POINTER TO RECORD(Parameter)
		res: LONGINT
	END;

	TailGenParam = POINTER TO RECORD(Parameter)
		short: Shortname;			(* holds the short name *)
		tailmask: SET;					(* defines what tail lengths we are checking *)
		tails: POINTER TO ARRAY OF SET; (* bit-array, if a tail is found the corresponding bit is set  *)
	END;

	EnumCallback* = PROCEDURE {DELEGATE} (f: File; par: Parameter): BOOLEAN;

	Directory* = OBJECT(File)
		VAR
			firstFreePos: LONGINT;	(* position of first known free entry in directory, 'NotAssigned' if unknown *)
			extendable: BOOLEAN; (* TRUE if the directory can grow *)

		PROCEDURE &Init*(fs: Files.FileSystem);
		BEGIN
			Init^(fs);
			attr :=  {faDirectory, faReadOnly};
			parent := NotAssigned;
			firstFreePos := MAX(LONGINT);
			extendable := TRUE
		END Init;

		PROCEDURE Initialize;
		VAR r: Files.Rider; data: ARRAY 32 OF CHAR; parentDir: Directory; f: File;
		BEGIN {EXCLUSIVE}
			IF (parent = NotAssigned) THEN (* find parent *)
				SetX(r, 32);
				ReadBytesX(r, data, 0, 32);
				IF (r.res # 0) THEN HALT(ErrIOError) END;
				(* make sure it's the ".." entry *)
				IF (data[0] # ".") OR (data[1] # ".") OR (data[2] # " ") THEN HALT(ErrParentNotFound) END;

				parent := 10000H*FATVolumes.GetUnsignedInteger(data, 20) + FATVolumes.GetUnsignedInteger(data, 26)
			END;

			IF (parent = 0) THEN parentDir := fs(FileSystem).rootDir
			ELSE NEW(parentDir, fs); parentDir.cluster := parent
			END;
			f := parentDir.FindByCluster(cluster);
			IF (f = NIL) OR ~(f IS Directory) THEN HALT(ErrParentNotFound) END;

			long := f.long; short := f.short; attr := f.attr; NTres := f.NTres;
			time := f.time; date := f.date; writeTime := f.writeTime; writeDate := f.writeDate; accessDate := f.accessDate;
			modH := FALSE; modName := FALSE; registered := TRUE;
			clusterSize := f.clusterSize;
			InitSize
		END Initialize;

		PROCEDURE InitSize;
		VAR c: Address; vol: FATVolumes.Volume;
			(* TRAP info *)
			tiFilename: Filename; tiFirstCluster, tiThisCluster, tiSize: LONGINT;
		BEGIN
			vol := fs.vol(FATVolumes.Volume);
			c := cluster; size := 0;
			IF (cluster # NotAssigned) THEN
				COPY(long, tiFilename); tiFirstCluster := c;
				REPEAT
					tiThisCluster := c; tiSize := size;
					c := vol.ReadFATEntry(c);
					INC(size, clusterSize)
				UNTIL (c < 2);
				IF (c # EOC) THEN
					KernelLog.Enter; KernelLog.String(moduleName); KernelLog.String("warning: cluster chain of directory '"); KernelLog.String(long);
					KernelLog.String("' not terminated!"); KernelLog.Exit
				END;
			END;
			ASSERT(size > 0)
		END InitSize;

		(* Position a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file.
			A Rider cannot be positioned beyond the end of a file. *)
		PROCEDURE SetX(VAR r: Files.Rider; pos: LONGINT);
		BEGIN
			IF (size = 0) THEN InitSize END;
			SetX^(r, pos)
		END SetX;

		(* Return the current length of a file. *)
		PROCEDURE Length(): LONGINT;
		BEGIN {EXCLUSIVE}
			IF (size = 0) THEN InitSize END;
			RETURN Length^()
		END Length;

		(* Enumerate - enumerates the contents of the directory *)
		PROCEDURE Enumerate(enum: EnumCallback; par: Parameter);
		BEGIN {EXCLUSIVE} EnumerateX(enum, TRUE, par)
		END Enumerate;

		PROCEDURE EnumerateX(enum: EnumCallback; parseLong: BOOLEAN; par: Parameter);
		VAR data: ARRAY 32 OF CHAR; cont: BOOLEAN;
			type, i, k, chksumI, chksumII: LONGINT;
			file, f: File; dir: Directory; r: Files.Rider; entry: DirEntry;
			attr: SET; unicode: ARRAY 261 OF LONGINT; longname: Filename;
		BEGIN
			NEW(file, fs); NEW(dir, fs);
			SetX(r, 0);
			cont := TRUE; firstFreePos := MAX(LONGINT);
			REPEAT
				ReadBytesX(r, data, 0, 32);
				IF (data[0] = deFree) THEN (* free entry *)
					IF (Pos(r) < firstFreePos) THEN firstFreePos := Pos(r)-32 END
				ELSIF (data[0] # deLast) THEN (* long/short directory entry *)
					type := FATVolumes.AND(3FH, ORD(data[11]));
					longname := "";
					entry.ofs := Pos(r) - 32; entry.len := 1;
					IF (type = faLongName) THEN
						k := -1;
						IF parseLong & (FATVolumes.AND(40H, ORD(data[0])) = 40H) THEN
							k := ORD(data[0]) MOD 40H - 1;	(* number of long entries - 1 *)
							data[0] := CHR(k+1);	(* = mask out 40H from data[0] *)
							chksumI := ORD(data[13]);
							unicode[13*(k+1)] := 0;
							WHILE (k >= 0) & (k+1 = ORD(data[0])) &
								(FATVolumes.AND(3FH, ORD(data[11])) = faLongName) & (chksumI = ORD(data[13])) DO
								FOR i := 0 TO 4 DO unicode[13*k + i] := FATVolumes.GetUnsignedInteger(data, 1 + 2*i) END;
								FOR i := 0 TO 5 DO unicode[13*k + 5 + i] := FATVolumes.GetUnsignedInteger(data, 14 + 2*i) END;
								FOR i := 0 TO 1 DO unicode[13*k + 11 + i] := FATVolumes.GetUnsignedInteger(data, 28 + 2*i) END;
								DEC(k);
								INC(entry.len);
								ReadBytesX(r, data, 0, 32)
							END
							(* k # 0 -> Error *)
						END;

						IF (k <= 0) THEN UTF8Strings.UnicodetoUTF8(unicode, longname)
						ELSE (* k # 0; skip over orphaned long entries *)
							WHILE (FATVolumes.AND(3FH, ORD(data[11])) = faLongName) DO ReadBytesX(r, data, 0, 32) END;
							entry.len := 1
						END
					END;

					IF (data[0] = deFree) OR (data[0] = deLast) THEN
						(* the long entry was ok, but the short entry is free -> this happens when a FAT driver that does not support long names
							deletes a file -> ignore entry *)
						IF (entry.ofs < firstFreePos) THEN firstFreePos := entry.ofs END
					ELSE
						(* short entry *)
						attr := SYSTEM.VAL(SET, LONG(ORD(data[11])));
						IF ~(faVolumeID IN attr) THEN
							(* ignore "." and ".." entries *)
							IF ~((faDirectory IN attr) & (data[0] = ".") & ((data[1] = " ") OR ((data[1] = ".") & (data[2] = " ")))) THEN
								IF (faDirectory IN attr) THEN f := dir; attr := attr + {faReadOnly}; f.flags := {Files.Directory}
								ELSE f := file; f.flags := {}
								END;
								f.long := longname;
								i := 0; k := 0; chksumII := 0;
								FOR i := 0 TO 10 DO
									f.short[i] := data[i];
									IF ODD(chksumII) THEN chksumII := 80H + chksumII DIV 2 ELSE chksumII := chksumII DIV 2 END;
									chksumII := (chksumII + ORD(data[i])) MOD 100H;
								END;
								f.short[11] := 0X;
								f.long := "";
								f.attr := attr;
								f.NTres := data[12];
								f.cluster := 10000H*FATVolumes.GetUnsignedInteger(data, 20) + FATVolumes.GetUnsignedInteger(data, 26);
								f.parent := cluster;
								f.size := FATVolumes.GetLongint(data, 28);
								f.time := TimeFAT2Oberon(FATVolumes.GetUnsignedInteger(data, 14), ORD(data[13]));
								f.date := DateFAT2Oberon(FATVolumes.GetUnsignedInteger(data, 16));
								f.writeTime := TimeFAT2Oberon(FATVolumes.GetUnsignedInteger(data, 22), 0);
								f.writeDate := DateFAT2Oberon(FATVolumes.GetUnsignedInteger(data, 24));
								f.accessDate := DateFAT2Oberon(FATVolumes.GetUnsignedInteger(data, 18));
								f.modH := FALSE; f.modName := FALSE;
								f.registered := TRUE;

								IF (longname # "") & (chksumI # chksumII) THEN (* chksum mismatch, ignore long name *)
									IF (entry.ofs < firstFreePos) THEN firstFreePos := entry.ofs END;
									longname := ""; f.entry.ofs := Pos(r) - 32; f.entry.len := 1
								ELSE f.long := longname; f.entry := entry
								END;
								IF (f.long = "") THEN
									i := 0;
									WHILE (i < 8) DO f.long[i] := f.short[i]; INC(i) END;
									WHILE (i > 0) & (f.long[i-1] = " ") DO DEC(i) END;
									IF (f.short[8] # " ") THEN
										f.long[i] := "."; INC(i);
										k := 8;
										WHILE (k < 11) & (f.short[k] # " ") DO f.long[i] := f.short[k]; INC(i); INC(k) END
									END;
									f.long[i] := 0X
								END;
								cont := enum(f, par)
							END
						ELSE (* set volume name *)
							i := 0;
							WHILE (i < 11) & (data[i] # " ") DO fs.vol.name[i] := data[i]; INC(i) END;
							fs.vol.name[i] := 0X
						END
					END
				END
			UNTIL (data[0] = deLast) OR r.eof OR ~cont;
			IF (firstFreePos = MAX(LONGINT)) THEN firstFreePos := Strings.Max(Pos(r)-32, 0) END;
			ASSERT(firstFreePos MOD 32 = 0)
		END EnumerateX;

		(* TailGeneration - generates a short name that does not collide with an existing long or short name *)
		PROCEDURE TailGenHandler(f: File; p: Parameter): BOOLEAN;
		VAR i,k: INTEGER;
			tail: LONGINT;
		BEGIN
			WITH p: TailGenParam DO
				(* compare names *)
				i := 0; WHILE (i < 8) & (f.short[i] = p.short[i]) DO INC(i) END;
				k := 8; WHILE (k < 11) & (f.short[k] = p.short[k]) DO INC(k) END;
				IF (k = 11) THEN
					IF (i = 8) THEN INCL(p.tails[0], 0) (* identical filename *)
					ELSE
						IF (f.short[i] = "~") THEN
							INCL(p.tails[0], 0); (* identical filename flag *)
							(* extract tail value and calculate offset in bit array *)
							tail := 0; k := i+1;
							WHILE (k < 8) & (f.short[k] >= "0") & (f.short[k] <= "9") DO
								tail := 10*tail + ORD(f.short[k]) - ORD("0");
								INC(k)
							END;
							(* set bit in bitmask *)
							IF (tail DIV 32 < LEN(p.tails)) THEN
								(* tails of the form [0]+[1-9]+ will be mapped to the same spot as
									the tail without the leading 0. We do not generate tails with
									leading zeros, so we can safely ignore that here. *)
								INCL(p.tails[tail DIV 32], tail MOD 32)
							END
						END
					END
				END
			END;
			RETURN TRUE
		END TailGenHandler;

		PROCEDURE TailFinder(p: TailGenParam; VAR tail: LONGINT): BOOLEAN;
		VAR delta,i,l,max: LONGINT;
		BEGIN
			(* calculate size of bit-array and initialize it *)
			max := 0; delta := 10;
			FOR l := 1 TO 6 DO
				IF (l IN p.tailmask) THEN max := delta END;
				delta := delta * 10
			END;

			NEW(p.tails, (max + 31) DIV 32);
			FOR i := 0 TO LEN(p.tails)-1 DO p.tails[i] := {} END;

			(* seach directory *)
			INCL(p.tailmask, 0);
			EnumerateX(TailGenHandler, FALSE, p);	(* ignore long names *)

			(* try to find a free tail number *)
			tail := 0;
			IF (0 IN p.tails[0]) THEN	(* bit 0 in p.tails[0] indicates wheter we have found a tail or not *)
				FOR i := 0 TO LEN(p.tails)-1 DO
					IF (p.tails[i] # {0..31}) THEN
						FOR l := 0 TO 31 DO
							IF ~(l IN p.tails[i]) THEN
								tail := i*32+l; RETURN TRUE
							END
						END
					END
				END
			ELSE RETURN TRUE
			END;
			RETURN FALSE
		END TailFinder;

		PROCEDURE TailGeneration(VAR shortname: Shortname; TailNeeded: BOOLEAN);
		VAR tp: TailGenParam; len, max, pos, tail: LONGINT; dummy: BOOLEAN;
		BEGIN
			NEW(tp);
			tp.short := shortname;
			(* first, we look for tails with lengths 1,2,3, or 4 (~x, ~xx, ~xxx, ~xxxx) *)
			tp.tailmask := {1, 2, 3, 4};
			IF ~TailFinder(tp, tail) THEN
				(* wow, more than 10'000 files with the same shortname in one directory.... *)
				tp.tailmask := {5,6};
				dummy := TailFinder(tp, tail)
			END;
			IF TailNeeded OR (0 IN tp.tails[0]) THEN
				IF (tail = 0) & TailNeeded THEN tail := 1 END;
				IF (tail # 0) THEN (* tail found *)
					(* calc length of tail *)
					len := 1; max := 10; WHILE (max-1 < tail) DO max := max*10; INC(len) END;
					(* insert tail, avoid spaces in short name *)
					pos := 7-len;
					WHILE (pos > 0) & (shortname[pos-1] = " ") DO DEC(pos) END;
					shortname[pos] := "~";
					WHILE (len > 0) DO
						shortname[pos+len] := CHR(ORD("0") + tail MOD 10);
						tail := tail DIV 10;
						DEC(len)
					END
				ELSE
					(* argh, all possible tails (= 1111105 !) occupied. Raise "You are a Moron" exception *)
					KernelLog.Enter;
					KernelLog.String(moduleName); KernelLog.String("Too many files with similar names");
					KernelLog.Exit;
					HALT(ErrTooManySimilarFiles)
				END
			END
		END TailGeneration;

		PROCEDURE GetShortName(VAR name: Filename; VAR shortname: Shortname; VAR checksum: CHAR);
		VAR extPos, i, k: LONGINT; ascii: ARRAY 256 OF CHAR; lossy, l, sameName: BOOLEAN;
		BEGIN
			(* step 1-4: convert name to upper case OEM (ASCII), set 'lossy conversion'-flag, strip leading and embedded spaces, strip leading periods.
				also remember, if the long name has an extension and the position of its first character *)
			lossy := UTF8Strings.UTF8toASCII(name, 0X, ascii) > 0;
			WHILE (i < 256) & (ascii[i] # 0X) DO
				ascii[k] := UpperCh(ascii[i], l);
				IF l THEN ascii[k] := "_"; lossy := TRUE END;
				IF (ascii[k] # " ") & ((ascii[k] # ".") OR (k > 0)) THEN INC(k) END; (* ignore spaces and dots at the beginning of the name *)
				IF (ascii[k] = ".") THEN extPos := k END;
				INC(i)
			END;
			(* step 5: copy primary portion of name *)
			FOR i := 0 TO 10 DO shortname[i] := " " END;
			i := 0;
			WHILE (ascii[i] # 0X) & (ascii[i] # ".") & (i < 8) DO shortname[i] := ascii[i]; INC(i) END;
			IF (i < 8) & ((ascii[i] = 0X) OR (extPos = i)) THEN sameName := TRUE END;
			(* step 6: omitted *)
			(* step 7: copy extension *)
			IF (extPos > 0) THEN
				i := 0; INC(extPos);
				WHILE (ascii[extPos + i] # 0X) & (i < 3) DO shortname[8+i] := ascii[extPos+i]; INC(i) END;
				IF (i = 3) & (ascii[extPos+i] # 0X) THEN sameName := FALSE END
			END;
			(* numeric tail generation *)
			TailGeneration(shortname, TRUE (*lossy OR sameName*));
			(*
			KernelLog.String(moduleName); KernelLog.String("GetShortName(): '"); KernelLog.String(name);
			KernelLog.String("' ==> '"); KernelLog.String(shortname); KernelLog.Char("'"); KernelLog.Ln;
			*)
			checksum := CheckSum(shortname)
		END GetShortName;

		PROCEDURE RemoveFileHeader(f: File);
		BEGIN {EXCLUSIVE} RemoveFileHeaderX(f)
		END RemoveFileHeader;

		PROCEDURE RemoveFileHeaderX(f: File);
		VAR ofs, i: LONGINT; r: Files.Rider; ro: BOOLEAN;
		BEGIN
			IF (faReadOnly IN attr) THEN EXCL(attr, faReadOnly); ro := TRUE END;
			IF (f.entry.len > 0) THEN
				ofs := f.entry.ofs;
				ASSERT((ofs # NotAssigned) & (ofs MOD 32 = 0));
				IF (ofs < firstFreePos) THEN firstFreePos := ofs END;

				FOR i := 0 TO f.entry.len-1 DO
					SetX(r, ofs);
					WriteX(r, deFree);
					INC(ofs, 32)
				END;
				UpdateX
			END;
			f.entry.ofs := NotAssigned; f.entry.len := 0;
			f.registered := FALSE;
			IF ro THEN INCL(attr, faReadOnly) END
		END RemoveFileHeaderX;

		PROCEDURE GetShortEntry(VAR entry: ARRAY OF CHAR; name: ARRAY OF CHAR; attr: SET; NTres: CHAR;
														cluster, size, time, date, wTime, wDate, aDate: LONGINT);
		VAR i, j: LONGINT;
		BEGIN
			FOR i := 0 TO 10 DO entry[i] := name[i] END;
			entry[11] := CHR(SYSTEM.VAL(LONGINT, attr));
			entry[12] := NTres;
			IF (cluster = NotAssigned) THEN cluster := 0 END;
			FATVolumes.PutUnsignedInteger(entry, 20, cluster DIV 10000H);
			FATVolumes.PutUnsignedInteger(entry, 26, cluster MOD 10000H);
			FATVolumes.PutLongint(entry, 28, size);
			TimeOberon2FAT(time, i, j);
			FATVolumes.PutUnsignedInteger(entry, 14, i); entry[13] := CHR(j);
			FATVolumes.PutUnsignedInteger(entry, 16, DateOberon2FAT(date));
			TimeOberon2FAT(wTime, i, j);
			FATVolumes.PutUnsignedInteger(entry, 22, i);
			FATVolumes.PutUnsignedInteger(entry, 24, DateOberon2FAT(wDate));
			FATVolumes.PutUnsignedInteger(entry, 18, DateOberon2FAT(aDate))
		END GetShortEntry;

		PROCEDURE WriteFileHeader(f: File);
		BEGIN {EXCLUSIVE} WriteFileHeaderX(f)
		END WriteFileHeader;

		PROCEDURE WriteFileHeaderX(f: File);
		VAR data: ARRAY 32 OF CHAR; b, ro, writeLast: BOOLEAN;
			ofs, i, k, len, numFree, s, ucs: LONGINT; unicode: ARRAY 256 OF INTEGER;
			r: Files.Rider; c, chksum: CHAR;
		BEGIN
			IF (faReadOnly IN attr) THEN EXCL(attr, faReadOnly); ro := TRUE END;
			IF f.modName THEN
				len := NameLength(f.long);

				(* delete old name *)
				IF (len > f.entry.len) THEN ofs := NotAssigned	(* new name is longer, find new position *)
				ELSE ofs := f.entry.ofs											(* reuse old position *)
				END;
				RemoveFileHeaderX(f);
				f.entry.ofs := ofs;
				f.entry.len := len;
				f.registered := TRUE;

				IF (f.entry.ofs = NotAssigned) THEN (* find 'len' subsequent free entries *)
					ofs := firstFreePos;
					IF (firstFreePos = MAX(LONGINT)) THEN ofs := 0 END;
					ASSERT(ofs MOD 32 = 0);

					numFree := 0;
					WHILE ~r.eof & (numFree < len) DO
						SetX(r, ofs); ReadX(r, c);
						IF (c = deFree) THEN
							IF (f.entry.ofs = NotAssigned) THEN f.entry.ofs := ofs END;
							INC(numFree)
						ELSIF (c = deLast) THEN
							IF (f.entry.ofs = NotAssigned) THEN f.entry.ofs := ofs END;
							numFree := len;
							writeLast := TRUE
						ELSE
							f.entry.ofs := NotAssigned; numFree := 0
						END;
						INC(ofs, 32)
					END;
					IF (numFree < len) & ((len-numFree)*32 >= Length()) & ~extendable THEN HALT(ErrRootDirFull) END;
					ASSERT(f.entry.ofs MOD 32 = 0);

				END;

				SetX(r, f.entry.ofs);

				IF (len = 1) THEN
					FOR i := 0 TO 10 DO f.short[i] := " " END;
					i := 0;
					WHILE (f.long[i] # 0X) & (f.long[i] # ".") DO f.short[i] := f.long[i]; INC(i) END;
					IF (f.long[i] = ".") THEN
						INC(i); k := 8;
						WHILE (f.long[i] # 0X) DO f.short[k] := f.long[i]; INC(i); INC(k) END;
					END
				ELSE
					GetShortName(f.long, f.short, chksum);

					FOR i := 0 TO 255 DO unicode[i] := -1 END; (* = 0FFFFH *)
					k := 0; i := 0;
					REPEAT
						b := UTF8Strings.DecodeChar(f.long, k, ucs);
						IF ~b OR (ucs < 0) OR (ucs > MAX(INTEGER)) THEN HALT(ErrInvalidFilename) END;
						unicode[i] := SHORT(ucs); INC(i)
					UNTIL (ucs = 0);

					WHILE (len > 1) DO
						IF (len  < f.entry.len) THEN data[0] := CHR(len-1) ELSE data[0] := CHR(40H + len-1) END;
						data[11] := SYSTEM.VAL(CHAR, faLongName);
						data[12] := 0X;
						data[13] := chksum;
						FATVolumes.PutUnsignedInteger(data, 26, 0);
						ofs := (len-2)*13;
						FOR k := 0 TO 4 DO FATVolumes.PutUnsignedInteger(data, 1+k*2, unicode[ofs+k]) END;
						FOR k := 0 TO 5 DO FATVolumes.PutUnsignedInteger(data, 14+k*2, unicode[ofs+5+k]) END;
						FOR k := 0 TO 1 DO FATVolumes.PutUnsignedInteger(data, 28+k*2, unicode[ofs+11+k]) END;
						WriteBytesX(r, data, 0, 32);
						IF (r.res # 0) THEN HALT(ErrIOError) END;
						DEC(len)
					END
				END
			ELSE
				ASSERT((f.entry.ofs # NotAssigned) & (f.entry.len > 0));
				SetX(r, f.entry.ofs + 32*(f.entry.len-1))
			END;

			(* create short entry *)
			IF (faDirectory IN f.attr) THEN s := 0 ELSE s := f.Length() END;
			GetShortEntry(data, f.short, f.attr, f.NTres, f.cluster, s, f.time, f.date, f.writeTime, f.writeDate, f.accessDate);

			(* wp: Pos(r) = position of short entry *)
			WriteBytesX(r, data, 0, 32);
			IF writeLast & (Pos(r) < size) THEN WriteX(r, 0X) END;
			UpdateX;
			IF (size MOD clusterSize # 0) THEN
				InitSize; ASSERT(size MOD clusterSize = 0)
			END;
			IF (r.res # 0) THEN HALT(ErrIOError) END;
			f.modH := FALSE; f.modName := FALSE;
			IF ro THEN INCL(attr, faReadOnly) END
		END WriteFileHeaderX;

		PROCEDURE NewSubdirectory(name: ARRAY OF CHAR; VAR res: LONGINT): Directory;
		VAR upName: Filename; dir: Directory; f: File; i, t, d, p: LONGINT; r: Files.Rider; entry: ARRAY 32 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF UTF8Strings.Valid(name) & ValidateName(name) THEN
				UTF8Strings.UpperCase(name, upName);
				f := FindX(upName);
				IF (f = NIL) THEN
					NEW(dir, fs);
					COPY(name, dir.long); dir.attr := {faDirectory}; dir.NTres := 0X;
					dir.cluster := fs.vol(FATVolumes.Volume).AllocCluster(EOC, res);
					IF (res = Ok) THEN
						fs.vol(FATVolumes.Volume).WriteFATEntry(dir.cluster, EOC, res);
						ASSERT(res = Ok);
						dir.parent := cluster;
						Clock.Get(dir.time, dir.date);
						dir.writeTime := dir.time; dir.writeDate := dir.date; dir.accessDate := dir.date;
						dir.modH := TRUE; dir.modName := TRUE; dir.registered := TRUE;
						dir.entry.len := NotAssigned; dir.entry.ofs := NotAssigned;
						dir.size := 0; dir.key := 0;
						WriteFileHeaderX(dir);

						dir.Set(r, 0);

						(* "."/".." entries *)
						t := dir.time; d := dir.date;
						IF (SELF IS RootDirectory) THEN p := 0 ELSE p := cluster END;
						GetShortEntry(entry, ".          ", {faDirectory}, 0X, dir.cluster, 0, t, d, t, d, t);
						dir.WriteBytes(r, entry, 0, 32);
						GetShortEntry(entry, "..         ", {faDirectory}, 0X, p, 0, t, d, t, d, t);
						dir.WriteBytes(r, entry, 0, 32);

						(* clear rest of directory cluster *)
						FOR i := 0 TO 31 DO entry[i] := 0X END;
						FOR i := 2 TO (dir.clusterSize DIV 32)-1 DO dir.WriteBytes(r, entry, 0, 32) END;

						dir.Update;
						res := r.res
					ELSE dir := NIL	(* res is already set *)
					END
				ELSE
					res := ErrFileExists
				END
			ELSE
				res := ErrInvalidFilename
			END;
			RETURN dir
		END NewSubdirectory;

		PROCEDURE DeleteCallback(f: File; par: Parameter): BOOLEAN;
		BEGIN
			WITH par: ResultParam DO
				IF (f IS Directory) THEN
					f(Directory).DeleteContents(par.res);
					IF (par.res = Ok) THEN EXCL(f.attr, faReadOnly) END;
				END;

				IF (par.res = Ok) THEN
					f.DeleteClusterChain(par.res)	(* we don't need to remove the directory entry since the directory itself will be deleted *)
				END;
				RETURN (par.res = Ok)
			END
		END DeleteCallback;

		PROCEDURE DeleteContents(VAR res: LONGINT);
		VAR par: ResultParam; enum: FileEnumerator;
		BEGIN {EXCLUSIVE}
			NEW(enum, cluster);
			fs(FileSystem).openFiles.Enumerate(enum.EnumFile);
			IF (enum.count > 0) THEN res := ErrHasOpenFiles
			ELSE
				NEW(par); par.res := Ok;
				EnumerateX(DeleteCallback, TRUE, par);
				res := par.res
			END
		END DeleteContents;

		PROCEDURE FindCallback(f: File; par: Parameter): BOOLEAN;
		VAR name: Filename;
		BEGIN
			WITH par: NameParam DO
				UTF8Strings.UpperCase(f.long, name);
				IF (name = par.name) THEN
					par.file := f;
					RETURN FALSE
				ELSE
					RETURN TRUE
				END
			END
		END FindCallback;

		PROCEDURE Find(VAR filename: ARRAY OF CHAR): File;
		BEGIN  {EXCLUSIVE}
			RETURN FindX(filename)
		END Find;

		PROCEDURE FindX(VAR filename: ARRAY OF CHAR): File;
		VAR par: NameParam; f: File;
		BEGIN
			IF (filename # "") THEN
				NEW(par); UTF8Strings.UpperCase(filename, par.name); par.file := NIL;
				EnumerateX(FindCallback, TRUE, par);
				f := par.file
			END;
			RETURN f
		END FindX;

		PROCEDURE FindByClusterCallback(f: File; par: Parameter): BOOLEAN;
		BEGIN
			WITH par: ClusterParam DO
				IF (f.cluster = par.cluster) THEN par.file := f; RETURN FALSE
				ELSE RETURN TRUE
				END
			END
		END FindByClusterCallback;

		PROCEDURE FindByCluster(cluster: Address): File;
		VAR par: ClusterParam;
		BEGIN {EXCLUSIVE}
			NEW(par); par.cluster := cluster; par.file := NIL;
			EnumerateX(FindByClusterCallback, TRUE, par);
			RETURN par.file
		END FindByCluster;
	END Directory;

	RootDirectory = OBJECT(Directory)
		PROCEDURE GetFullName(VAR name: ARRAY OF CHAR; WithPrefix: BOOLEAN);
		VAR pos, i: LONGINT;
		BEGIN {EXCLUSIVE}
			pos := 0; i := 0;
			IF WithPrefix THEN
				WHILE (fs.prefix[i] # 0X) & (pos < LEN(name)) DO
					name[pos] := fs.prefix[i];
					INC(pos); INC(i)
				END;
				name[pos] := ":"; INC(pos)
			END;
			IF (pos < LEN(name)-1) THEN
				name[pos] := PathDelimiter; INC(pos)
			END;
			name[Strings.Min(LEN(name)-1, pos)] := 0X
		END GetFullName;
	END RootDirectory;

	RootDirectory1216 = OBJECT(RootDirectory) (* for FAT12/FAT16 file systems *)
		PROCEDURE &Init*(fs: Files.FileSystem);
		BEGIN
			Init^(fs);
			clusterSize := FATVolumes.BS;
			extendable := FALSE
		END Init;

		PROCEDURE InitSize;
		BEGIN
			size := fs.vol(FATVolumes.FAT1216Volume).numRootSectors*FATVolumes.BS
		END InitSize;

		PROCEDURE ReadBuffer*(buffer: Buffer; pos: LONGINT);
		VAR vol: FATVolumes.FAT1216Volume; res: LONGINT;
		BEGIN
			vol := fs.vol(FATVolumes.FAT1216Volume);
			IF (pos < 0) OR (pos >= vol.numRootSectors) THEN HALT(ErrInvalidParams) END;
			buffer.cluster := pos; buffer.pos := pos; ASSERT(LEN(buffer.data) = clusterSize);
			vol.ReadSector(vol.firstRootSector + pos, buffer.data^, res);
			IF (res # Ok) THEN HALT(ErrIOError) END
		END ReadBuffer;

		PROCEDURE WriteBuffer*(buffer: Buffer);
		VAR vol: FATVolumes.FAT1216Volume; res: LONGINT;
		BEGIN
			vol := fs.vol(FATVolumes.FAT1216Volume);
			IF (buffer.cluster < 0) OR (buffer.cluster >= vol.numRootSectors) THEN HALT(ErrInvalidParams) END;
			vol.WriteSector(vol.firstRootSector + buffer.cluster, buffer.data^, res);
			IF (res # Ok) THEN HALT(ErrIOError) END
		END WriteBuffer;
	END RootDirectory1216;

	RootDirectory32 = OBJECT(RootDirectory) (* for FAT32 file systems *)
	END RootDirectory32;

(** Generate a new file system object.  Files.NewVol has volume parameter, Files.Par has mount prefix. *)
PROCEDURE NewFS*(context : Files.Parameters);
VAR fs: FileSystem; rootDirName : ARRAY 32 OF CHAR;
BEGIN
	IF (Files.This(context.prefix) = NIL) THEN
		NEW(fs);
		fs.vol := context.vol;
		IF (fs.vol IS FATVolumes.FAT12Volume) THEN fs.desc := "FAT 12"
		ELSIF (fs.vol IS FATVolumes.FAT16Volume) THEN fs.desc := "FAT 16"
		ELSIF (fs.vol IS FATVolumes.FAT32Volume) THEN fs.desc := "FAT 32"
		ELSE
			context.error.String("FATFiles.NewFS: wrong volume type"); context.error.Ln;
			RETURN;
		END;
		fs.Initialize;

		IF context.arg.GetString(rootDirName) THEN
			IF ~fs.SetRootDirectory(rootDirName) THEN
				context.error.String("Warning: root directory not found"); context.error.Ln;
			END;
		END;
		Files.Add(fs, context.prefix)
	ELSE
		context.error.String(moduleName); context.error.String(context.prefix); context.error.String(" already in use"); context.error.Ln;
	END;
END NewFS;

PROCEDURE PurgeFile(f: ANY);
VAR res: LONGINT;
BEGIN
	WITH f: File DO
		IF ~f.registered & (f.cluster # NotAssigned) THEN
			f.DeleteClusterChain(res) (* ignore res *)
		END
	END
END PurgeFile;

(* ValidateName - checks if 'name' is a valid long name and removes leading spaces and trailing spaces and periods *)
PROCEDURE ValidateName(VAR name: ARRAY OF CHAR): BOOLEAN;
VAR s: POINTER TO ARRAY OF CHAR; np, sp: LONGINT;
BEGIN
	NEW(s, LEN(name));
	COPY(name, s^);
	sp := 0; np := 0;
	WHILE (s[sp] = " ") DO INC(sp) END; (* ignore leading spaces *)
	WHILE (s[sp] # 0X) DO
		IF ~ValidLongChar(s[sp]) THEN RETURN FALSE END;
		name[np] := s[sp];
		INC(np); INC(sp)
	END;
	WHILE (np > 0) & ((name[np-1] = ".") OR (name[np-1] = " ")) DO DEC(np) END; (* ignore trailing spaces or periods *)
	name[np] := 0X;
	RETURN (np > 0) & (UTF8Strings.Length(name) <= 255)
END ValidateName;

PROCEDURE ValidLongChar*(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= 20X) & (ch # "\") & (ch # "/") & (ch # ":") & (ch # "*") & (ch # "?") & (ch # '"') & (ch # "<") & (ch # ">") & (ch # "|")
END ValidLongChar;

(* ValidShortChar - checks if a char 'ch' in a short name is valid *)
PROCEDURE ValidShortChar*(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (("0" <= ch) & (ch <= "9")) OR (("A" <= ch) & (ch <= "Z")) OR
		(ch = "$" ) OR (ch = "%") OR (ch = "'") OR (ch = "-") OR (ch = "_") OR (ch = "@") OR (ch = "~") OR (ch = "`") OR
		(ch = "!") OR (ch = "(") OR (ch = ")") OR (ch = "{") OR (ch = "}") OR (ch = "^") OR (ch = "#") OR (ch = "&") OR (ch = " ")
END ValidShortChar;

(* IsShortName - checks if a long name 'fn' can be stored in one "short" directory entry *)
PROCEDURE IsShortName(CONST fn: Filename): BOOLEAN;
VAR s: ARRAY 12 OF CHAR; i, k: INTEGER;
BEGIN
	IF (fn = ".") OR (fn = "..") THEN RETURN TRUE
	ELSIF (UTF8Strings.UTF8toASCII(fn, 0X, s) =  0) THEN
		i := 0;
		WHILE (i < 11) & (s[i] # 0X) & ValidShortChar(s[i]) DO INC(i) END;
		IF (s[i] = ".") & (i < 8) THEN
			INC(i); k := i;
			WHILE (i < 11) & ValidShortChar(s[i]) DO INC(i) END;
			RETURN (s[i] = 0X) & (i - k <= 3)
		ELSE RETURN (s[i] = 0X)
		END
	END;
	RETURN FALSE
END IsShortName;

PROCEDURE CheckSum*(short: Shortname): CHAR;
VAR chksum, i: LONGINT;
BEGIN
	chksum := 0;
	FOR i := 0 TO 10 DO
		IF ODD(chksum) THEN chksum := 80H + chksum DIV 2 ELSE chksum := chksum DIV 2 END;
		chksum := (chksum + ORD(short[i])) MOD 100H
	END;
	RETURN CHR(chksum)
END CheckSum;

(* NameLength - returns the number of directory entries needed to store a file with filename 'fn' *)
PROCEDURE NameLength(CONST fn: Filename): LONGINT;
VAR pos, ucs, i: LONGINT;
BEGIN
	IF IsShortName(fn) THEN RETURN 1
	ELSE
		WHILE UTF8Strings.DecodeChar(fn, pos, ucs) & (ucs # 0) DO INC(i) END;
		RETURN (i + 12) DIV 13 + 1	(* 13 characters per long entry plus 1 short entry *)
	END
END NameLength;

(* UpperCh - extended CAP function that also works for special characters. lossy=TRUE indicates a lossy conversion (e.g. â->A) *)
PROCEDURE UpperCh(ch: CHAR; VAR lossy: BOOLEAN): CHAR;
BEGIN
	lossy := TRUE;
	CASE ch OF
		"A".."Z" : lossy := FALSE |
		"a" .. "z": ch := CAP(ch); lossy := FALSE |
		"0".."9", "$", "%", "'", "-", "_", "@", "~", "`", "!", "(", ")", "{", "}", "^", "#", "&", ".", ",": lossy := FALSE (* |
		"ä": ch := "Ä"; lossy := FALSE |
		"ö": ch := "Ö"; lossy := FALSE |
		"ü": ch := "Ü"; lossy := FALSE |
		"â": ch := "A" |
		"ê": ch := "E" |
		"î": ch := "I" |
		"ô": ch := "O" |
		"û": ch := "U" |
		"à": ch := "A" |
		"è": ch := "E" |
		"ì": ch := "I" |
		"ò": ch := "O" |
		"ù": ch := "U" |
		"é": ch := "E" |
		"ë": ch := "E" |
		"ï": ch := "I" |
		"ç": ch := "C" |
		"á": ch := "A" |
		"ñ": ch := "N" |
		"ß": ch := "S" *)
		ELSE
	END;
	RETURN ch
END UpperCh;

(** DateFAT2Oberon, DateOberon2FAT, TimeFAT2Oberon, TimeOberon2FAT - conversion between FAT and
	Oberon date/time values *)

(* DOS formats:
		date: bits 15-9: count of years from 1980 (0-127)
					8-5: month of year (1-12)
					4-0: day of month (1-31)

		time: bits 15-11: hours (0-23)
					10-5: minutes (0-59)
					4-0: 2-second count (0-29)
					additional byte: bits 7-8: count of 0.01 seconds (0-199)

	Oberon formats:
		time: bits 16-12: hours
					11-6: minutes
					5-0: seconds

		date: 30-9: count of years from 1900
					8-5: month of year
					4-0: day of month
*)
PROCEDURE DateFAT2Oberon*(d: LONGINT): LONGINT;
BEGIN RETURN (d DIV 512 MOD 128 + 80) * 512 + d MOD 512
END DateFAT2Oberon;

PROCEDURE DateOberon2FAT*(d: LONGINT): LONGINT;
BEGIN RETURN (d DIV 512 - 80) MOD 128 * 512 + d MOD 512
END DateOberon2FAT;

PROCEDURE TimeFAT2Oberon*(time, tenth: LONGINT): LONGINT;
BEGIN RETURN time DIV 2048 MOD 32 * 4096 + time DIV 32 MOD 64 * 64 + time MOD 32 * 2 + tenth DIV 100
END TimeFAT2Oberon;

PROCEDURE TimeOberon2FAT*(t: LONGINT; VAR time, tenth: LONGINT);
BEGIN
	time := t DIV 4096 MOD 32 * 2048 + t DIV 64 MOD 64 * 32 + t MOD 64 DIV 2;
	tenth := 100 * SHORT(FATVolumes.AND(t, 1) MOD 200)
END TimeOberon2FAT;

(* Clean up when module unloaded. *)

PROCEDURE Finalization;
VAR ft: Files.FileSystemTable; i: LONGINT;
BEGIN
	IF Modules.shutdown = Modules.None THEN
		Files.GetList(ft);
		IF ft # NIL THEN
			FOR i := 0 TO LEN(ft^)-1 DO
				IF ft[i] IS FileSystem THEN Files.Remove(ft[i]) END
			END
		END
	END
END Finalization;

BEGIN
	IF (NotAssigned # -1) THEN HALT(ErrInvalidParams) END;
	Modules.InstallTermHandler(Finalization)
END FATFiles.

(* Notes:
	Methods with {} notation are explicitly unprotected.  They must be called only from a protected context.
*)
