(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Files;	(* pjm *)

(** Aos file system base. *)

IMPORT SYSTEM, Streams, KernelLog, Modules, Kernel, Commands;

CONST
	(** Volume & file flags *)
	ReadOnly* = 0;

	(** Volume flags *)
	Removable* = 1;
	Boot* = 2;

	(** File flags *)
	Directory* = 1;
	Hidden* = 2;
	System* = 3;
	Archive* = 4;
	Temporary* = 5;

	Ok* = 0;

	(* Volume level errors *)
	ReadOnlyError = 2901;		(* Tried to modify read-only volume. Causes HALT *)
	VolumeFull = 2902;			(* Tried to allocate block on full volume. Causes HALT *)
	InvalidAdr= 2903;			(* Block address outside of volume. Causes HALT *)

	(* File level errors *)
	VolumeReadOnly* = 2905; 	(** Cannot modify read-only volume *)
	FsNotFound* = 2906; 		(** File system not found *)
	FileAlreadyExists* = 2908;	(** File already exists *)
	BadFileName* = 2909;		(** Bad file name *)
	FileNotFound* = 2910;		(** File not found *)

	EnumSize* = 0; EnumTime* = 1;	(** Enumerate flags. *)

	PrefixLength* = 16;	(** maximum length of a file system prefix. *)
	NameLength* = 256;	(** maximum length of a file name. *)

	Trace = FALSE;

	WriteError = 2907;

	DefaultWriterSize = 4096;
	DefaultReaderSize = 4096;

	PathDelimiter* = "/";	(** Path delimiter *)

	BufferSize = 32*1024; 	(* Buffersize for file copy operation *)

	SetSize = MAX (SET) + 1;

	(* file system behaviour flags *)
	NeedsPrefix* = 0; (* if no prefix given, then this file system cannot handle it, to prevent file systems from being in the search path *)

TYPE
(** All record fields are read-only for users, and read-write for extenders. *)

	FileName* = ARRAY PrefixLength+NameLength OF CHAR;

		(** A rider points to some location in a file, where reading and writing will be done. *)
	Rider* = RECORD	(** not shareable between multiple processes *)
		(* the rider must be a record, otherwise the Oberon text system will not work *)
		eof*: BOOLEAN;	(** has end of file been passed *)
		res*: LONGINT;	(** leftover byte count for ReadBytes/WriteBytes *)
			(** private fields for implementors *)
		apos*, bpos*: LONGINT;
		hint*: Hint;
		file*: File;
		fs*: FileSystem;
	END;

TYPE

	(** Reader for buffered reading of a file via Streams.Read* procedures.  See OpenReader. *)
	Reader* = OBJECT (Streams.Reader)	(** not sharable between multiple processes *)
	VAR
		file : File;
		r: Rider;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		BEGIN
			file.ReadBytes(r, buf, ofs, size);
			len := size - r.res;
			IF len >= min THEN res := Streams.Ok ELSE res := Streams.EOF (* end of file *) END
		END Receive;

		PROCEDURE CanSetPos*() : BOOLEAN;
		BEGIN
			RETURN TRUE;
		END CanSetPos;

		PROCEDURE SetPos*(pos : LONGINT);
		BEGIN
			file.Set(r, pos);
			Reset;
			received := pos; (* this effects that Streams.Reader.Pos() returns the correct location in the file *)
		END SetPos;

		PROCEDURE &InitFileReader*(file : File; pos: LONGINT);
		BEGIN
			ASSERT(file # NIL);
			SELF.file := file;
			file.Set(r, pos);
			received := pos; (* this effects that Streams.Reader.Pos() returns the correct location in the file *)
			InitReader(SELF.Receive, DefaultReaderSize);
		END InitFileReader;

	END Reader;

TYPE

		(** Writer for buffered writing of a file via Streams.Write* procedures.  See OpenWriter. *)
	Writer* = OBJECT (Streams.Writer)	(** not sharable between multiple processes *)
	VAR
		file : File;
		r: Rider;

		PROCEDURE Send(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		BEGIN
			r.file.WriteBytes(r, buf, ofs, len);
			IF propagate THEN r.file.Update END;
			IF r.res = 0 THEN res := Streams.Ok ELSE res := WriteError (* not all bytes written *) END
		END Send;

		PROCEDURE CanSetPos*() : BOOLEAN;
		BEGIN
			RETURN TRUE;
		END CanSetPos;

		PROCEDURE SetPos*(pos : LONGINT);
			BEGIN
			Update;
			file.Set(r, pos);
			Reset;
		END SetPos;

		PROCEDURE Pos*(): LONGINT;
		BEGIN
			Update;
			RETURN file.Pos(r)
		END Pos;

		PROCEDURE &InitFileWriter*(file: File; pos: LONGINT);
		BEGIN
			ASSERT(file # NIL);
			SELF.file := file;
			file.Set(r, pos);
			InitWriter(SELF.Send, DefaultWriterSize);
		END InitFileWriter;

	END Writer;

	Prefix* = ARRAY PrefixLength OF CHAR;

	Address* = LONGINT;	(** Volume block address [1..size] *)

	Hint* = POINTER TO RECORD END;	(** for use by file system implementors. *)

	Bytes2 = ARRAY 2 OF CHAR;
	Bytes4 = ARRAY 4 OF CHAR;
	Bytes8 = ARRAY 8 OF CHAR;

TYPE
(** Volume is the base type of all volumes.  It provides operations on an abstract array of file system data blocks of blockSize bytes, numbered from 1 to size.  It is mainly used by file system implementations. *)

	Volume* = OBJECT	(** shareable *)
		VAR
			size*: LONGINT;	(** size in blocks *)
			blockSize*: LONGINT;	(** block size in bytes *)
			flags*: SET;	(** ReadOnly, Removable, Boot *)
			name*: ARRAY 32 OF CHAR;	(** descriptive name - e.g. for matching with Partitions.Show *)

			map: POINTER TO ARRAY OF SET;	(* Block allocation table *)
			used: LONGINT;	(* used blocks *)
			reserved: LONGINT;	(* blocks reserved for system *)

		PROCEDURE AllocBlock*(hint: Address; VAR adr: Address);
		BEGIN {EXCLUSIVE}
			IF ReadOnly IN flags THEN HALT(ReadOnlyError) END;
			IF size - used <= reserved THEN HALT(VolumeFull) END;
			ASSERT(hint >= 0);
			IF hint > size THEN hint := 0 END;
			adr := hint+1;
			LOOP
				IF adr > size THEN adr := 0 END;
				IF (adr MOD SetSize) IN map[adr DIV SetSize] THEN
					INC(adr) (* Block in use *)
				ELSE
					INCL(map[adr DIV SetSize], adr MOD SetSize);
					EXIT
				END;
				IF adr = hint THEN HALT(VolumeFull) END
			END;
			INC(used)
		END AllocBlock;

		PROCEDURE FreeBlock*(adr: Address);
		BEGIN {EXCLUSIVE}
			IF (adr < 1) OR (adr > size) THEN HALT(InvalidAdr) END;
			IF ReadOnly IN flags THEN HALT(ReadOnlyError) END;
			EXCL(map[adr DIV SetSize], adr MOD SetSize);
			DEC(used)
		END FreeBlock;

		PROCEDURE MarkBlock*(adr: Address);
		BEGIN {EXCLUSIVE}
			IF (adr < 1) OR (adr > size) THEN HALT(InvalidAdr) END;
			IF ReadOnly IN flags THEN HALT(ReadOnlyError) END;
			INCL(map[adr DIV SetSize], adr MOD SetSize);
			INC(used)
		END MarkBlock;

		PROCEDURE Marked*(adr: Address): BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (adr < 1) OR (adr > size) THEN HALT(InvalidAdr) END;
			IF ReadOnly IN flags THEN HALT(ReadOnlyError) END;
			RETURN (adr MOD SetSize) IN map[adr DIV SetSize]
		END Marked;

		PROCEDURE Available*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN size-used
		END Available;

		PROCEDURE GetBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		BEGIN HALT(301) END GetBlock;	(* abstract *)

		PROCEDURE PutBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		BEGIN HALT(301) END PutBlock;	(* abstract *)

		(* FIX: This procedure can not be declared exclusive, because it will be overridden by an exclusive procedure in the actual implementation, from where it will be supercalled.  This could be a good example for allowing recursive locks, or an example of where an alternative for overriding methods is needed. In this case the procedure is only called from the exclusive overridden procedure, so it is not a real problem (although it is ugly). *)
		PROCEDURE Finalize*;
		BEGIN
			map := NIL; size := 0; blockSize := 0
		END Finalize;

		(** Init procedure for private data of above methods only.  If the above methods are not required, this procedure should not be called, and the volume fields should be initialized directly.  The flags parameter defines the volume flags, the size parameter its size, and the reserved parameter says how many blocks are reserved for the system (out of disk space trap occurs when less than this amount of blocks are present). *)

		PROCEDURE Init*(flags: SET; size, reserved: LONGINT);
		VAR maplen: LONGINT;
		BEGIN
			SELF.flags := flags; SELF.size := size; SELF.reserved := reserved;
			IF ~(ReadOnly IN flags) THEN
				maplen := (size+1+SetSize - 1) DIV SetSize;
				NEW(map, maplen);
				WHILE maplen > 0 DO DEC(maplen); map[maplen] := {} END;
				INCL(map[0], 0);	(* reserve sector 0 (illegal to use) *)
				used := 0
			ELSE
				used := size
			END
		END Init;

	END Volume;

TYPE
	FileSystem* = OBJECT	(** shareable *)
		VAR
			next: FileSystem;	(* list of known file systems *)
			prefix*: Prefix;	(** mount prefix *)
			desc*: ARRAY 32 OF CHAR;	(** description of file system *)
			vol*: Volume;	(** underlying volume, if any (a boot FS must have a volume) *)
			flags*: SET; (* flags like propagate prefix / can process  files without prefix *)

		(** Create a new file with the specified name.  End users use Files.New instead. *)

		PROCEDURE New0*(name: ARRAY OF CHAR): File;
		BEGIN HALT(301) END New0;	(* abstract *)

		(** Open an existing file. The same file descriptor is returned if a file is opened multiple times.  End users use Files.Old instead. *)

		PROCEDURE Old0*(name: ARRAY OF CHAR): File;
		BEGIN HALT(301) END Old0;	(* abstract *)

		(** Delete a file. res = 0 indicates success.  End users use Files.Delete instead. *)

		PROCEDURE Delete0*(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		BEGIN HALT(301) END Delete0;	(* abstract *)

		(** Rename a file. res = 0 indicates success.  End users use Files.Rename instead. *)

		PROCEDURE Rename0*(old, new: ARRAY OF CHAR; f: File; VAR res: LONGINT);
		BEGIN HALT(301) END Rename0;	(* abstract *)

		(** Enumerate canonical file names. mask may contain * wildcards.  For internal use only.  End users use Enumerator instead. *)

		PROCEDURE Enumerate0*(mask: ARRAY OF CHAR; flags: SET; enum: Enumerator);
		BEGIN HALT(301) END Enumerate0;	(* abstract *)

		(** Return the unique non-zero key of the named file, if it exists. *)

		PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
		BEGIN HALT(301) END FileKey;	(* abstract *)

		(** Create a new directory structure. May not be supported by the actual implementation.
			End users use Files.CreateDirectory instead.*)

		PROCEDURE CreateDirectory0*(name: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN res := -1	(* not supported *)
		END CreateDirectory0;

		(** Remove a directory. If force=TRUE, any subdirectories and files should be automatically deleted.
			End users use Files.RemoveDirectory instead. *)

		PROCEDURE RemoveDirectory0*(name: ARRAY OF CHAR; force: BOOLEAN; VAR key, res: LONGINT);
		BEGIN res := -1	(* not supported *)
		END RemoveDirectory0;

		(** Finalize the file system. *)

		PROCEDURE Finalize*;
		BEGIN	(* see note in Volume.Finalize *)
			vol := NIL
		END Finalize;

(* GC
		PROCEDURE Purge*(f: File);	(* race! *)
		BEGIN HALT(301) END Purge;	(* by default not allowed to purge files *)
*)

	END FileSystem;

	FileSystemTable* = POINTER TO ARRAY OF FileSystem;

TYPE
	File* = OBJECT	(** sharable *)
		VAR
				(** private fields for implementors *)
			flags*: SET;			(** (read-only!) file-specific flags, i.e. Directory. *)
			key*: LONGINT;	(* unique id for registered file, never 0 *)
			fs*: FileSystem;	(* file system containing file *)

		(** Position a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file. A Rider cannot be positioned beyond the end of a file. *)

		PROCEDURE Set*(VAR r: Rider; pos: LONGINT);
		BEGIN HALT(301) END Set;	(* abstract *)

		(** Return the offset of a Rider positioned on a file. *)

		PROCEDURE Pos*(VAR r: Rider): LONGINT;
		BEGIN HALT(301) END Pos;	(* abstract *)

		(** Read a byte from a file, advancing the Rider one byte further.  R.eof indicates if the end of the file has been passed. *)

		PROCEDURE Read*(VAR r: Rider; VAR x: CHAR);
		BEGIN HALT(301) END Read;	(* abstract *)

		(** Read a sequence of len bytes into the buffer x at offset ofs, advancing the Rider. Less bytes will be read when reading over the end of the file. r.res indicates the number of unread bytes. x must be big enough to hold all the bytes. *)

		PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN HALT(301) END ReadBytes;	(* abstract *)

		(** Write a byte into the file at the Rider position, advancing the Rider by one. *)

		PROCEDURE Write*(VAR r: Rider; x: CHAR);
		BEGIN HALT(301) END Write;	(* abstract *)

		(** Write the buffer x containing len bytes (starting at offset ofs) into a file at the Rider position. *)

		PROCEDURE WriteBytes*(VAR r: Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN HALT(301) END WriteBytes;	(* abstract *)

		(** Return the current length of a file. *)

		PROCEDURE Length*(): LONGINT;
		BEGIN HALT(301) END Length;	(* abstract *)

		(** Return the time (t) and date (d) when a file was last modified. *)

		PROCEDURE GetDate*(VAR t, d: LONGINT);
		BEGIN HALT(301) END GetDate;	(* abstract *)

		(** Set the modification time (t) and date (d) of a file. *)

		PROCEDURE SetDate*(t, d: LONGINT);
		BEGIN HALT(301) END SetDate;	(* abstract *)

		(** Get file attributes. *)
		PROCEDURE GetAttributes*(): SET;
		BEGIN HALT(301) END GetAttributes; (* abstract *)

		(** Set file attributes. *)
		PROCEDURE SetAttributes*(flags: SET);
		BEGIN HALT(301) END SetAttributes; (* abstract *)

		(** Return the canonical name of a file. *)
		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN HALT(301) END GetName;	(* abstract *)

		(** Register a file created with New in the directory, replacing the previous file in the directory with the same name. The file is automatically updated.  End users use Files.Register instead. *)
		PROCEDURE Register0*(VAR res: LONGINT);
		BEGIN HALT(301) END Register0;	(* abstract *)

		(** Flush the changes made to a file from its buffers. Register0 will automatically update a file. *)

		PROCEDURE Update*;
		BEGIN HALT(301) END Update;	(* abstract *)

		(*
			Usually, in Oberon a file is not closed explicitly but by a call to finalizers by the garbage colloector.
			However, for systems running in a host environment such as WinAos or UnixAos, explicitly closing a file may release files/handles that otherwise are blocked by the system.
			Close is not necessarily implemented by a file system, therefore a call to Close may or may not have any effect.
			Implementers of Close have to make sure that a call to close does not possibly contradict with file finalization.
		*)
		PROCEDURE Close*;
		BEGIN
			(* abstract, potentially empty *)
		END Close;

	END File;

TYPE
	Enumerator* = OBJECT	(** not shareable *)
		VAR
			r: Rider;	(* data is stored in an anonymous file, because it is potentially very long *)
			adding: BOOLEAN;	(* prevent user calls of PutEntry *)
			size-: LONGINT;	(** total number of entries *)

		(** Open an enumerator and enumerate the files that match mask. *)

		PROCEDURE Open*(mask: ARRAY OF CHAR; flags: SET);
		BEGIN
			r.file := New("");
			r.file.Set(r, 0);
			size := 0;
			adding := TRUE;
			Enumerate(mask, flags, SELF);
			adding := FALSE;
			r.file.Set(r, 0)
		END Open;

		(** reset the enumerator to the first entry *)

		PROCEDURE Reset*;
		BEGIN
			r.file.Set(r, 0)
		END Reset;

		(** returns TRUE if the enumerator contains more entries *)

		PROCEDURE HasMoreEntries*(): BOOLEAN;
		BEGIN
			RETURN r.file.Pos(r) < r.file.Length()
		END HasMoreEntries;

		(** Get one entry from the enumerator. *)

		PROCEDURE GetEntry*(VAR name: ARRAY OF CHAR; VAR flags: SET; VAR time, date, size: LONGINT): BOOLEAN;
		VAR len: LONGINT;
		BEGIN
			ReadNum(r, len);
			IF ~r.eof THEN
				name[len] := 0X;	(* index check *)
				r.file.ReadBytes(r, name, 0, len);
				ReadSet(r, flags); ReadNum(r, time); ReadNum(r, date); ReadNum(r, size);
				ASSERT(~r.eof)
			END;
			RETURN ~r.eof
		END GetEntry;

		(** Close the enumerator. *)

		PROCEDURE Close*;
		BEGIN
			(*r.fs.Purge(r.file);*)
			r.hint := NIL; r.file := NIL; r.fs := NIL
		END Close;

		(** For internal use only. *)

		PROCEDURE PutEntry*(VAR name: ARRAY OF CHAR; flags: SET; time, date, size: LONGINT);
		VAR len: LONGINT;
		BEGIN
			ASSERT(adding);
			INC(SELF.size);
			len := 0; WHILE name[len] # 0X DO INC(len) END;
			WriteNum(r, len); r.file.WriteBytes(r, name, 0, len);
			WriteSet(r, flags); WriteNum(r, time); WriteNum(r, date); WriteNum(r, size)
		END PutEntry;

	END Enumerator;

TYPE
	(* FinalizedCollection enumerator searching for a file by (fs,key). *)
	FileSearcher = OBJECT
		VAR fs: FileSystem; key: LONGINT; found: File;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN
			WITH f: File DO
				IF (f.fs = fs) & (f.key = key) THEN
					found := f; cont := FALSE
				END
			END
		END EnumFile;

	END FileSearcher;

TYPE
		(** Parameters passed to volume and file system generator commands.  The str field contains a generic parameter string from the mount command.  The vol field returns the new volume from volume generators and passes the volume parameter to file system generators.  The prefix field contains the mount prefix, mainly for file system generators to add themselves with Files.Add. *)
	Parameters* = OBJECT(Commands.Context)
	VAR
		vol*: Volume;	(** out parameter of volume generators and in parameter of file system generators. *)
		prefix*: Prefix;
	END Parameters;

	FileSystemFactory* = PROCEDURE(context : Parameters);

VAR
	fsroot: FileSystem;	(* list of known file systems *)
	files: Kernel.FinalizedCollection;	(* all open files - cleaned up by GC *)
	seacher: FileSearcher;	(* enumerator shared by various procedures, protected with module EXCLUSIVE *)
	fileClipboard : File; (* contains the pointer to the file in the clipboard opened with Copy *)

(** Buffered reading and writing. *)

(** Open a reader on a file at the specified position. *)

PROCEDURE OpenReader*(VAR b: Reader; f: File; pos: LONGINT);
BEGIN
	IF b = NIL THEN
		NEW(b, f, pos)
	ELSE
		b.InitFileReader(f,pos)
	END;
END OpenReader;

(** Open a writer on a file at the specified position.  Remember to call Streams.Update before registering or closing the file! *)

PROCEDURE OpenWriter*(VAR b: Writer; f: File; pos: LONGINT);
BEGIN
	NEW(b, f, pos)
END OpenWriter;

(** File name prefix support. *)

(** Split fullname = ( prefix ":" name ) into prefix and name *)

PROCEDURE SplitName*(fullname: ARRAY OF CHAR; VAR prefix, name: ARRAY OF CHAR);
VAR i, j, len: LONGINT;
BEGIN
	i := 0; WHILE (fullname[i] # ":") & (fullname[i] # 0X) DO INC(i) END;
	IF (fullname[i] # ":") OR (i >= LEN(prefix)) THEN
		COPY("", prefix); COPY(fullname, name);
	ELSE
		j := 0; WHILE j # i DO prefix[j] := fullname[j]; INC(j) END;
		prefix[j] := 0X;
		j := 0; INC(i); len := LEN(name)-1;
		WHILE (j < len) & (fullname[i] # 0X) DO name[j] := fullname[i]; INC(j); INC(i) END;
		name[j] := 0X
	END
END SplitName;

(** Join prefix and name to fullname = ( prefix ":" name ) *)

PROCEDURE JoinName*(prefix, name: ARRAY OF CHAR; VAR fullname: ARRAY OF CHAR);
VAR i, j, len: LONGINT;
BEGIN
	len := LEN(fullname)-1;
	i := 0; WHILE (i < len) & (prefix[i] # 0X) DO fullname[i] := prefix[i]; INC(i) END;
	IF (i < len) THEN fullname[i] := ":"; INC(i) END;
	j := 0; WHILE (i < len) & (name[j] # 0X) DO fullname[i] := name[j]; INC(i); INC(j) END;
	fullname[i] := 0X
END JoinName;

(** Split a pathname at the last PathDelimiter or ":" into path and filename = ( {path (PathDelimiter|":")} filename ) *)

PROCEDURE SplitPath*(pathname: ARRAY OF CHAR; VAR path, name: ARRAY OF CHAR);
VAR i,j,len: LONGINT;
BEGIN
	i := 0; j := -1;
	WHILE pathname[i] # 0X DO
		IF (pathname[i] = PathDelimiter) OR (pathname[i] = ":") THEN j := i END;
		INC(i)
	END;
	i := 0; len := LEN(path)-1;
	WHILE (i < len) & (i < j) DO path[i] := pathname[i]; INC(i) END; path[i] := 0X;

	IF pathname[i] = ":" THEN path[i] := ":"; path[i+1] := 0X;  END; (* fof  for correct splitting of filenames such as c:test into c: and test*)

	INC(j); i := 0; len := LEN(name)-1;
	WHILE (i < len) & (pathname[j] # 0X) DO name[i] := pathname[j]; INC(i); INC(j) END;
	name[i] := 0X
END SplitPath;

(** Join path and file name = ( path PathDelimiter name ) *)

PROCEDURE JoinPath*(path, name: ARRAY OF CHAR; VAR pathname: ARRAY OF CHAR);
VAR i,j,len: LONGINT;
BEGIN
	len := LEN(pathname)-1;
	i := 0; WHILE (i < len) & (path[i] # 0X) DO pathname[i] := path[i]; INC(i) END;
	IF ((i = 0) OR (pathname[i-1] # PathDelimiter)) & (i < len) THEN pathname[i] := PathDelimiter; INC(i) END;
	j := 0; WHILE (i < len) & (name[j] # 0X) DO pathname[i] := name[j]; INC(i); INC(j) END;
	pathname[i] := 0X
END JoinPath;

(** Split a filename at the last '.' into name and extension = ( name "." extension ) *)

PROCEDURE SplitExtension*(filename: ARRAY OF CHAR; VAR name, extension: ARRAY OF CHAR);
VAR i,j,len: LONGINT;
BEGIN
	i := 0; j := -1;
	WHILE filename[i] # 0X DO
		IF filename[i] = "." THEN j := i END;
		INC(i)
	END;
	IF (j = -1) THEN (* no extension *)
		COPY(filename, name); COPY("", extension)
	ELSE
		i := 0; len := LEN(name)-1;
		WHILE (i < len) & (i < j) DO name[i] := filename[i]; INC(i) END; name[i] := 0X;
		INC(j); i := 0; len := LEN(extension)-1;
		WHILE (i < len) & (filename[j] # 0X) DO extension[i] := filename[j]; INC(i); INC(j) END;
		extension[i] := 0X
	END
END SplitExtension;

(** Join name and extension = ( name "." extension ) *)

PROCEDURE JoinExtension*(name, extension: ARRAY OF CHAR; VAR filename: ARRAY OF CHAR);
VAR i,j,len: LONGINT;
BEGIN
	len := LEN(filename)-1;
	i := 0; WHILE (i < len) & (name[i] # 0X) DO filename[i] := name[i]; INC(i) END;
	IF ((i = 0) OR (filename[i-1] # ".")) & (i < len) THEN filename[i] := "."; INC(i) END;
	j := 0; IF extension[0] = "." THEN INC(j) END;
	WHILE (i < len) & (extension[j] # 0X) DO filename[i] := extension[j]; INC(i); INC(j) END;
	filename[i] := 0X
END JoinExtension;

(** Append the path delimiter to path if path does not contain one *)

PROCEDURE ForceTrailingDelimiter*(VAR path: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0; WHILE path[i] # 0X DO INC(i) END;
	IF (i = 0) OR (path[i-1] # PathDelimiter) THEN
		path[i] := PathDelimiter;
		path[i+1] := 0X
	END
END ForceTrailingDelimiter;

(** File system list support. *)

PROCEDURE WriteFS(fs: FileSystem);
BEGIN
	IF Trace THEN
		IF fs.vol # NIL THEN KernelLog.String(fs.vol.name); KernelLog.Char(" ") END;
		KernelLog.String(fs.desc)
	END
END WriteFS;

(** Add file system at end of list, with specified prefix, which must be unique. *)

PROCEDURE Add*(fs: FileSystem; prefix: ARRAY OF CHAR);
VAR p, c: FileSystem;
BEGIN {EXCLUSIVE}
	IF Trace THEN
		KernelLog.Enter; KernelLog.String("Files: Adding "); WriteFS(fs); KernelLog.Exit
	END;
	COPY(prefix, fs.prefix);
	p := NIL; c := fsroot;
	WHILE c # NIL DO
		ASSERT((c # fs) & (c.prefix # fs.prefix));	(* duplicate insertion not allowed *)
		p := c; c := c.next
	END;
	IF p = NIL THEN fsroot := fs ELSE p.next := fs END;
	fs.next := NIL
END Add;

PROCEDURE DeleteFS(fs: FileSystem);
VAR p, c: FileSystem;
BEGIN
	p := NIL; c := fsroot;
	WHILE c # fs DO p := c; c := c.next END;	(* fs must be in list *)
	IF p = NIL THEN fsroot := c.next ELSE p.next := c.next END;
	c.next := NIL
END DeleteFS;

(** Promote fs to the start of the list. *)

PROCEDURE Promote*(fs: FileSystem);
BEGIN {EXCLUSIVE}
	DeleteFS(fs);
	fs.next := fsroot; fsroot := fs
END Promote;

(** Remove the file system and finalize it. *)

PROCEDURE Remove*(fs: FileSystem);
VAR
	enum: OBJECT
		VAR count: LONGINT; fs: FileSystem;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN
			WITH f: File DO
				IF f.fs = fs THEN INC(count); f.Update(); f.fs := NIL END
				(* if Update procedure calls back to this module deadlock can result *)
			END
		END EnumFile;

	END;

BEGIN {EXCLUSIVE}
	IF Trace THEN
		KernelLog.Enter; KernelLog.String("Files: Removing "); WriteFS(fs); KernelLog.Exit
	END;
	NEW(enum); enum.count := 0; enum.fs := fs;
	files.Enumerate(enum.EnumFile);
	IF enum.count # 0 THEN
		KernelLog.Enter; KernelLog.String("Files: "); KernelLog.Int(enum.count, 1);
		KernelLog.String(" open files");
		IF fs.vol # NIL THEN
			KernelLog.String(" on "); KernelLog.String(fs.vol.name)
		END;
		KernelLog.Exit
	END;
	fs.Finalize();	(* potential deadlock *)
	DeleteFS(fs)
END Remove;

(* Find the file system with specified prefix. *)

PROCEDURE FindFS(prefix: ARRAY OF CHAR): FileSystem;
VAR fs: FileSystem;
BEGIN
	fs := fsroot; WHILE (fs # NIL) & (fs.prefix # prefix) DO fs := fs.next END;
	RETURN fs
END FindFS;

(** Find file system with specified prefix. *)

PROCEDURE This*(prefix: ARRAY OF CHAR): FileSystem;
BEGIN {EXCLUSIVE}
	RETURN FindFS(prefix)
END This;

(** Get a list of file systems. *)

PROCEDURE GetList*(VAR list: FileSystemTable);
VAR fs: FileSystem; n, i: LONGINT;
BEGIN {EXCLUSIVE}
	fs := fsroot; n := 0;
	WHILE (fs # NIL) DO fs := fs.next; INC(n) END;
	IF n # 0 THEN
		NEW(list, n);
		fs := fsroot;
		FOR i := 0 TO n-1 DO
			list[i] := fs; fs := fs.next
		END
	ELSE
		list := NIL
	END
END GetList;

(* GC
PROCEDURE Collect(f: ANY);
BEGIN
	WITH f: File DO
		IF (f.fs # NIL) & (f.fs.vol # NIL) & ~(ReadOnly IN f.fs.vol.flags) THEN
			IF ~f.fs.Registered(f) THEN f.fs.Purge(f) END
		END
	END
END Collect;
*)

(* Find file in open file list, or open and add it. *)

PROCEDURE OpenOld(enum: FileSearcher; fs: FileSystem; VAR fname: ARRAY OF CHAR): File;
VAR f: File; key: LONGINT;
BEGIN
	f := NIL;
	IF (fs # NIL) & (fname # "") THEN
		key := fs.FileKey(fname);
		IF key # 0 THEN f := FindOpenFile(enum, fs, key) END;
		IF f = NIL THEN	(* not found *)
			f := fs.Old0(fname);
			IF f # NIL THEN
				ASSERT(f.key # 0);	(* key must be set *)
				files.Add(f, NIL);
(* GC
				Heaps.RegisterFinalizer(f, Collect);	(* to do: use one finalizer for ordering *)
*)
			END
		END
	END;
	RETURN f
END OpenOld;

(** Open an existing file, searching through the mounted file system list if no prefix is specified. *)

PROCEDURE Old*(name: ARRAY OF CHAR): File;
VAR fs: FileSystem; f: File; prefix: Prefix; fname: FileName;
BEGIN {EXCLUSIVE}
	f := NIL;
	SplitName(name, prefix, fname);
	IF prefix = "" THEN
		fs := fsroot;
		WHILE (fs # NIL) & (f = NIL) DO
			IF ~(NeedsPrefix IN fs.flags) THEN (* fof *)
			f := OpenOld(seacher, fs, fname);
			END;
			fs := fs.next
		END
	ELSE
		f := OpenOld(seacher, FindFS(prefix), fname)
	END;
	RETURN f
END Old;

(** Create a new file.  If no prefix is specified, create the file on the first file system in the mounted list. *)

PROCEDURE New*(name: ARRAY OF CHAR): File;
VAR fs: FileSystem; f: File; prefix: Prefix; fname: FileName;
BEGIN {EXCLUSIVE}
	f := NIL; SplitName(name, prefix, fname);
	IF prefix = "" THEN
		fs := fsroot;	(* use default file system *)
		IF fname = "" THEN	(* anonymous file on unspecified file system *)
			WHILE (fs # NIL) & ((fs.vol = NIL) OR (fs.vol.flags * {Boot,ReadOnly} # {Boot})) DO
				fs := fs.next	(* find a writable boot file system *)
			END;
			IF fs = NIL THEN fs := fsroot END	(* none found, relapse to default *)
		END
	ELSE
		fs := FindFS(prefix);
	END;
	IF fs # NIL THEN
		IF (fs.vol = NIL) OR ~(ReadOnly IN fs.vol.flags) THEN
			f := fs.New0(fname);
(* GC
			IF f # NIL THEN
				Heaps.RegisterFinalizer(f, Collect)
			END
*)
		END
	END;
	RETURN f
END New;

(** Delete a file. res = 0 indicates success. *)

PROCEDURE Delete*(VAR name: ARRAY OF CHAR; VAR res: LONGINT);
VAR fs: FileSystem; f: File; key: LONGINT; prefix: Prefix; fname: FileName;
BEGIN {EXCLUSIVE}
	SplitName(name, prefix, fname);
	IF prefix = "" THEN fs := fsroot ELSE fs := FindFS(prefix) END;

	IF fs # NIL THEN
		IF (fs.vol = NIL) OR ~(ReadOnly IN fs.vol.flags) THEN
			fs.Delete0(fname, key, res);
			IF key # 0 THEN
				LOOP	(* remove all occurances of file (fs,key) from collection. *)
					f := FindOpenFile(seacher, fs, key);
					IF f = NIL THEN EXIT END;
					files.Remove(f)
				END
			END
		ELSE
			res := VolumeReadOnly	(* can not modify read-only volume *)
		END
	ELSE
		res := FsNotFound	(* file system not found *)
	END
END Delete;

(* copies the file with the given name to the fileClipboard *)
PROCEDURE Copy*(name: ARRAY OF CHAR; VAR res: LONGINT);
VAR file: File;
BEGIN
	res := -1;
	file := Old(name);
	IF file = NIL THEN RETURN END;
	fileClipboard := file;
	res := 0;
END Copy;

(* pastes the fileClipboard into the file with the given name if it doesn't exist already *)
PROCEDURE Paste*(name: ARRAY OF CHAR; VAR res: LONGINT);
VAR writer : Writer;
	reader : Reader;
	file : File;
	chunk : ARRAY 4096 OF CHAR;
	len : LONGINT;
BEGIN
	IF fileClipboard = NIL THEN RETURN END;
	IF Old(name) # NIL THEN res := FileAlreadyExists;			(* File already exists *)
	ELSE
		file := New(name);
		IF file = NIL THEN res := BadFileName; RETURN END;	(* Bad Filename *)
		NEW(writer, file, 0);
		NEW(reader, fileClipboard, 0);
		WHILE (reader.res = Streams.Ok) DO
			reader.Bytes(chunk, 0, LEN(chunk), len);
			writer.Bytes(chunk, 0, len);
		END;
		writer.Update;
		Register(file);
		res := 0;
	END;
END Paste;

(**
 * Make a copy of a file
 * @param source: Prefix, path and name of file to be copied
 * @param destination: Prefix, path and name of file to be created
 * @param overwrite: @in: Overwrite existing files? @out: Has an existing file been overwritten?
 * @param res: @out: Result code
 *)
PROCEDURE CopyFile*(source, destination : ARRAY OF CHAR; VAR overwrite : BOOLEAN; VAR res : LONGINT);
VAR
	sprefix, dprefix : Prefix;
	sname, dname, dpath, dfilename: FileName;
	sPos, dPos : Rider;
	sfs, dfs : FileSystem;
	sfile, dfile : File;
	buffer : ARRAY BufferSize OF CHAR;
	i : LONGINT;
BEGIN
	SplitName(source, sprefix, sname);
	SplitName(destination, dprefix, dname);
	BEGIN {EXCLUSIVE}
		IF sprefix = "" THEN sfs := fsroot; ELSE sfs := FindFS(sprefix); END;
		IF dprefix = "" THEN dfs := fsroot; ELSE dfs := FindFS(dprefix); END;

		IF (sfs # NIL) & (dfs # NIL) THEN (* We found the file system *)
			IF (dfs.vol = NIL) OR ~(ReadOnly IN dfs.vol.flags) THEN (* We may write to the target volume *)
				sfile := OpenOld(seacher, sfs, sname);
				IF sfile # NIL THEN (* We found the source file *)
					SplitName(dname, dpath, dfilename);
					IF (dfilename # "") THEN
						dfile := OpenOld(seacher, dfs, dname);
						IF (dfile = NIL) OR overwrite THEN (* We may write to the target file *)
							IF dfile # NIL THEN overwrite := TRUE; ELSE overwrite := FALSE; END;
							IF overwrite THEN
								dfile.GetName(dname);
								SplitName(dname, dprefix, dname);
							END;
							dfile := dfs.New0(dname);
							IF dfile # NIL THEN (* We could create the target file *)
								res := Ok;
							ELSE res := BadFileName;
							END;
						ELSE res := FileAlreadyExists;
						END;
					ELSE res := BadFileName;
					END;
				ELSE res := FileNotFound;
				END;
			ELSE res :=VolumeReadOnly;
			END;
		ELSE res := FsNotFound;
		END;
	END;

	IF res # Ok THEN RETURN END;

	(* copy file content *)
	sfile.Set(sPos, 0); dfile.Set(dPos, 0);
	i := 0;
	WHILE i < (sfile.Length() DIV BufferSize) DO
		sfile.ReadBytes(sPos, buffer, 0, BufferSize);
		dfile.WriteBytes(dPos, buffer, 0, BufferSize);
		INC(i);
	END;
	sfile.ReadBytes(sPos, buffer, 0, sfile.Length() MOD BufferSize);
	dfile.WriteBytes(dPos, buffer, 0, sfile.Length() MOD BufferSize);
	dfile.Update;
	Register(dfile); (* Will enter exclusive region *)
END CopyFile;

(** Rename a file. res = 0 indicates success. *)

PROCEDURE Rename*(CONST old, new: ARRAY OF CHAR; VAR res: LONGINT);
VAR
	key: LONGINT; ofs, nfs: FileSystem; f: File; pold, pnew: Prefix;
	fold, fnew: FileName;
BEGIN {EXCLUSIVE}
	SplitName(old, pold, fold);
	SplitName(new, pnew, fnew);
	IF pold = "" THEN ofs := fsroot ELSE ofs := FindFS(pold) END;
	IF pnew = "" THEN nfs := fsroot ELSE nfs := FindFS(pnew) END;
	IF (nfs # NIL) & (ofs = nfs) THEN
		IF (nfs.vol = NIL) OR ~(ReadOnly IN nfs.vol.flags) THEN
			key := nfs.FileKey(fold);
			IF key # 0 THEN f := FindOpenFile(seacher, nfs, key) ELSE f := NIL END;
			nfs.Rename0(fold, fnew, f, res)
		ELSE
			res := VolumeReadOnly	(* can not modify read-only volume *)
		END
	ELSE
		res := FsNotFound	(* file system not found *)
	END
END Rename;

(** Register a file created with New in the directory, replacing the previous file in the directory with the same name. The file is automatically closed. *)

PROCEDURE Register*(f: File);
VAR res: LONGINT;
BEGIN {EXCLUSIVE}
	IF f # NIL THEN
		f.Register0(res);
		IF res = 0 THEN	(* if register went ok (first time register) *)
			ASSERT(f.key # 0);
			files.Add(f, NIL)
		END
	END
END Register;

(** Create a directory structure. Directories are automatically registered. res=0 indicates success.
	Use Files.RemoveDirectory to delete a directory *)
PROCEDURE CreateDirectory*(path: ARRAY OF CHAR; VAR res: LONGINT);
VAR prefix: Prefix; fs: FileSystem; fpath: FileName;
BEGIN {EXCLUSIVE}
	SplitName(path, prefix, fpath);
	IF prefix = "" THEN fs := fsroot
	ELSE fs := FindFS(prefix)
	END;
	IF fs # NIL THEN fs.CreateDirectory0(fpath, res)
	ELSE res := -1
	END
END CreateDirectory;

(** Remove a directory. res=0 indicates success. If force=TRUE, any files and subdirectories are automatically deleted. *)
PROCEDURE RemoveDirectory*(path: ARRAY OF CHAR; force: BOOLEAN; VAR res: LONGINT);
VAR prefix: Prefix; fs: FileSystem; f: File; key: LONGINT; fpath: FileName;
BEGIN {EXCLUSIVE}
	SplitName(path, prefix, fpath);
	IF prefix = "" THEN fs := fsroot ELSE fs := FindFS(prefix) END;
	IF fs # NIL THEN
		IF (fs.vol = NIL) OR ~(ReadOnly IN fs.vol.flags) THEN
			fs.RemoveDirectory0(fpath, force, key, res);
			IF key # 0 THEN
				LOOP	(* remove all aoccurances of file (fs,key) from collection. *)
					f := FindOpenFile(seacher, fs, key);
					IF f = NIL THEN EXIT END;
					files.Remove(f)
				END
			END
		ELSE
			res := VolumeReadOnly	(* can not modify read-only volume *)
		END
	ELSE
		res := FsNotFound	(* file system not found *)
	END
END RemoveDirectory;

(* Enumerates files matching mask *)

PROCEDURE Enumerate(VAR mask: ARRAY OF CHAR; flags: SET; enum: Enumerator);
VAR
	fs: FileSystem; ft: FileSystemTable; i: LONGINT;
	prefix: Prefix; fmask: FileName
;BEGIN
	SplitName(mask, prefix, fmask);
	IF prefix = "" THEN
		GetList(ft);
		IF ft # NIL THEN
				(* FIX: deadlock possible if fs containing anonymous file does not allow concurrent Enumerate and Write *)
			FOR i := 0 TO LEN(ft^)-1 DO
				IF ~(NeedsPrefix IN ft[i].flags) THEN
					ft[i].Enumerate0(fmask, flags, enum)
				END;
			END
		END
	ELSE
		fs := This(prefix);
		IF fs # NIL THEN fs.Enumerate0(fmask, flags, enum) END
	END
END Enumerate;

(* Find an open file. *)

PROCEDURE FindOpenFile(enum: FileSearcher; fs: FileSystem; key: LONGINT): File;
BEGIN	(* not exported, because of possible race condition *)
	enum.fs := fs; enum.key := key; enum.found := NIL;
	files.Enumerate(enum.EnumFile);
	RETURN enum.found
END FindOpenFile;

(** Portable routines to read the standard Oberon types.  DEPRECATED, use Streams instead. *)

PROCEDURE ReadSInt*(VAR r: Rider; VAR x: SHORTINT);
BEGIN
	r.file.Read(r, SYSTEM.VAL(CHAR, x))
END ReadSInt;

PROCEDURE ReadInt*(VAR r: Rider; VAR x: INTEGER);
BEGIN
	r.file.ReadBytes(r, SYSTEM.VAL(Bytes2, x), 0, 2)
END ReadInt;

PROCEDURE ReadLInt*(VAR r: Rider; VAR x: LONGINT);
BEGIN
	r.file.ReadBytes(r, SYSTEM.VAL(Bytes4, x), 0, 4)
END ReadLInt;

PROCEDURE ReadSet*(VAR r: Rider; VAR x: SET);
CONST Size = SIZEOF (SET);
TYPE Bytes = ARRAY Size OF CHAR;
BEGIN
	r.file.ReadBytes(r, SYSTEM.VAL(Bytes, x), 0, Size)
END ReadSet;

PROCEDURE ReadBool*(VAR r: Rider; VAR x: BOOLEAN);
VAR ch: CHAR;
BEGIN
	r.file.Read(r, ch); x := ch # 0X
END ReadBool;

PROCEDURE ReadReal*(VAR r: Rider; VAR x: REAL);
BEGIN
	r.file.ReadBytes(r, SYSTEM.VAL(Bytes4, x), 0, 4)
END ReadReal;

PROCEDURE ReadLReal*(VAR r: Rider; VAR x: LONGREAL);
BEGIN
	r.file.ReadBytes(r, SYSTEM.VAL(Bytes8, x), 0, 8)
END ReadLReal;

PROCEDURE ReadString*(VAR r: Rider; VAR x: ARRAY OF CHAR);
VAR i: LONGINT; ch: CHAR; f: File;
BEGIN
	i := 0; f := r.file;
	LOOP
		f.Read(r, ch); x[i] := ch; INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN
			x[i-1] := 0X;
			REPEAT f.Read(r, ch) UNTIL ch = 0X;
			EXIT
		END
	END
END ReadString;

(* Reads a number in compressed format. *)

PROCEDURE ReadNum*(VAR r: Rider; VAR x: LONGINT);
VAR ch: CHAR; n, y: LONGINT; f: File;
BEGIN
	n := 0; y := 0; f := r.file;
	f.Read(r, ch);
	WHILE ch >= 80X DO
		INC(y, LSH(LONG(ORD(ch)) - 128, n)); INC(n, 7);
		f.Read(r, ch)
	END;
	x := ASH(LSH(LONG(ORD(ch)), 25), n-25) + y
END ReadNum;

(** Portable routines to write the standard Oberon types. DEPRECATED, used Streams instead. *)

PROCEDURE WriteSInt*(VAR r: Rider; x: SHORTINT);
BEGIN
	r.file.Write(r, SYSTEM.VAL(CHAR, x))
END WriteSInt;

PROCEDURE WriteInt*(VAR r: Rider; x: INTEGER);
BEGIN
	r.file.WriteBytes(r, SYSTEM.VAL(Bytes2, x), 0, 2)
END WriteInt;

PROCEDURE WriteLInt*(VAR r: Rider; x: LONGINT);
BEGIN
	r.file.WriteBytes(r, SYSTEM.VAL(Bytes4, x), 0, 4)
END WriteLInt;

PROCEDURE WriteSet*(VAR r: Rider; x: SET);
CONST Size = SIZEOF (SET);
TYPE Bytes = ARRAY Size OF CHAR;
BEGIN
	r.file.WriteBytes(r, SYSTEM.VAL(Bytes, x), 0, Size)
END WriteSet;

PROCEDURE WriteBool*(VAR r: Rider; x: BOOLEAN);
BEGIN
	IF x THEN r.file.Write(r, 1X) ELSE r.file.Write(r, 0X) END
END WriteBool;

PROCEDURE WriteReal*(VAR r: Rider; x: REAL);
BEGIN
	r.file.WriteBytes(r, SYSTEM.VAL(Bytes4, x), 0, 4)
END WriteReal;

PROCEDURE WriteLReal*(VAR r: Rider; x: LONGREAL);
BEGIN
	r.file.WriteBytes(r, SYSTEM.VAL(Bytes8, x), 0, 8)
END WriteLReal;

PROCEDURE WriteString*(VAR r: Rider; x: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0; WHILE x[i] # 0X DO INC(i) END;
	r.file.WriteBytes(r, x, 0, i+1)
END WriteString;

(* Writes a number in a compressed format. *)

PROCEDURE WriteNum*(VAR r: Rider; x: LONGINT);
VAR f: File;
BEGIN
	f := r.file;
	WHILE (x < - 64) OR (x > 63) DO
		f.Write(r, CHR(x MOD 128 + 128)); x := x DIV 128
	END;
	f.Write(r, CHR(x MOD 128))
END WriteNum;

(** Help procedures. *)

(** Append first string to second string, truncating on overflow. *)

PROCEDURE AppendStr*(from: ARRAY OF CHAR; VAR to: ARRAY OF CHAR);
VAR i, j, m: LONGINT;
BEGIN
	j := 0; WHILE to[j] # 0X DO INC(j) END;
	m := LEN(to)-1;
	i := 0; WHILE (from[i] # 0X) & (j # m) DO to[j] := from[i]; INC(i); INC(j) END;
	to[j] := 0X
END AppendStr;

(** Append unsigned integer to string in ASCII format. *)

PROCEDURE AppendInt*(x: LONGINT; VAR to: ARRAY OF CHAR);
VAR i, m: LONGINT;
BEGIN
	ASSERT(x >= 0);
	i := 0; WHILE to[i] # 0X DO INC(i) END;
	IF x # 0 THEN
		m := 1000000000;
		WHILE x < m DO m := m DIV 10 END;
		REPEAT
			to[i] := CHR(48 + (x DIV m) MOD 10); INC(i);
			m := m DIV 10
		UNTIL m = 0
	ELSE
		to[i] := "0"; INC(i)
	END;
	to[i] := 0X
END AppendInt;

(** Get the dev#part string from the stream *)
PROCEDURE GetDevPart*(arg : Streams.Reader; VAR deviceName : ARRAY OF CHAR; VAR partition : LONGINT);
VAR i : LONGINT; ch : CHAR;
BEGIN
	arg.SkipWhitespace;
	deviceName := ""; partition := 0;

	i := 0;
	ch := arg.Peek();
	WHILE (i < LEN(deviceName)-1) & (ch > " ") & (ch # "#") & (ch # ",") & (arg.res = Streams.Ok) DO
		arg.Char(ch); (* consume ch *)
		deviceName[i] := ch; INC(i);
		ch := arg.Peek();
	END;
	deviceName[i] := 0X;

	IF (ch = "#") THEN
		arg.Char(ch); (* consume "#" *)
		arg.Int(partition, FALSE);
	ELSE
		partition := 0;
	END;
END GetDevPart;

(* Clean up file systems when shutting down or unloading module. *)

PROCEDURE FSCleanup;
VAR ft: FileSystemTable; i: LONGINT;
BEGIN
	GetList(ft);
	IF ft # NIL THEN
		FOR i := 0 TO LEN(ft^)-1 DO Remove(ft[i]) END
	END
END FSCleanup;

(* debugging *)

(*
PROCEDURE ShowList*;
VAR
	enum: OBJECT
		VAR i: LONGINT;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		VAR name: FileName;
		BEGIN
			WITH f: File DO
				KernelLog.Int(i, 1); KernelLog.Char(" ");
				(*KernelLog.String(f.fs.prefix); KernelLog.Char(" ");*)
				KernelLog.Address(SYSTEM.VAL(ADDRESS, f)); KernelLog.Char(" ");
				KernelLog.Int(f.key, 1); KernelLog.Char(" ");
				KernelLog.Int(f.Length(), 1); KernelLog.Char(" ");
				f.GetName(name);
				KernelLog.String(name); KernelLog.Ln;
				INC(i)
			END
		END EnumFile;
	END;

BEGIN
	NEW(enum); enum.i := 0; KernelLog.Ln;
	files.Enumerate(enum.EnumFile)
END ShowList;
*)

BEGIN
	fsroot := NIL; NEW(seacher); NEW(files);
	Modules.InstallTermHandler(FSCleanup)
END Files.

(**
Notes:
o A typical code pattern for reading a file is:

	VAR f: Files.File; r: Files.Reader; ch: CHAR;

	f := Files.Old(filename);	(* open an existing file *)
	IF f # NIL THEN
		Files.OpenReader(r, f, 0);	(* open a buffer on the file *)
		LOOP
			ch := r.Get();	(* read a character from the buffer *)
			IF r.res # Streams.Ok THEN EXIT END;	(* end-of-file, or other error *)
			"do something with ch"
		END
	END

o A typical code pattern for writing a file is:

	VAR f: Files.File; w: Files.Writer; ch: CHAR;

	f := Files.New(filename);	(* create a new file (not visible yet) *)
	IF f # NIL THEN
		Files.OpenWriter(w, f, 0);	(* open a buffer on the file *)
		WHILE "not done" DO
			"assign ch"
			w.Char(ch)	(* write a character to the buffer (if the buffer is full, it is written to the file) *)
		END;
		w.Update;	(* write the last buffer to the file *)
		Files.Register(f)	(* enter the file in the directory *)

o See the Streams module for more procedures operating on Reader and Writer buffers, e.g. ReadRawInt, WriteRawInt, etc.
o Never use an exported identifier with a name ending in "0", unless you are implementing a file system.
o Never use an exported identifier that is documented as "private".
o File system implementations must implement the FileKey procedure to assign a unique key value to every file in the file system.  The key is used by the Files module to ensure that the Old procedure returns an existing file if it is already open.  The key need not be persistent, but must stay unique during a whole session (between mount and unmount).  The 0 key is reserved to indicate non-existent files.
*)

(*
	On-the-fly GC by bsm

	In order to be non-leaking, a file system must provide the following:
	- FileSystem.Purge -- to reclaim blocks of an open (being closed) file
	- FileSystem.Registered -- reports if a particular open file is registered in the file directory

	The following procedures need to be modified to purge file blocks when appropriate.
	- FileSystem.Register0 -- if an entry to a file, F, which is not open is replaced, purge F.
	- FileSystem.Rename0 -- same as register.
	- FileSystem.Delete0 -- if the entry being deleted refers to a file, F, which is not open, purge F.
*)

(*
Lock order: Files, File, FileSystem
*)

Files.File
Files.File

Files.Rider
Files.Reader
Files.Writer

Files.Old
Files.Old

Files.Set
Files.OpenReader
Files.OpenWriter

Files.ReadNum
Streams.ReadRawNum

Files.ReadInt
Streams.ReadRawInt

Files.ReadLInt
Streams.ReadRawLInt

Files.ReadString
Streams.ReadRawString

Files.ReadBytes
Streams.ReadBytes [add 0 ofs parameter, and len parameter]

Files.Read(
Streams.Read(

Files.ReadBool
Streams.ReadRawBool

Files.WriteInt
Streams.WriteRawInt

Files.Write(
Streams.Write(

Files.WriteBytes
Streams.WriteBytes [add 0 ofs parameter]
