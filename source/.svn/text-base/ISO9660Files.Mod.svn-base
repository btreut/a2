(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE ISO9660Files;	(** AUTHOR "?/be"; PURPOSE "ISO 9660 File System (ported from Native Oberon)"; *)

	IMPORT SYSTEM, Modules, Files, KernelLog, Strings;

	CONST
		debug = FALSE; nameDebug = FALSE;

		SS = 2048;
		MaxBufs = 4;

		Directory = 1;

		eFileDoesNotExist = 8903;
		eCannotOpenSubDir = 8916;
		eInvalidFirstCluster = 8917;
		eNameIsWild = 8927;
		eInvalidFileName = 8941;
		eInvalidVolume = 9000;

	TYPE
		Filename = ARRAY 256 OF CHAR;

		VolDesc = POINTER TO RECORD
			root, rootDirSize: LONGINT (* sector number of root directory and root directory size *)
		END;

		Buffer = POINTER TO RECORD (Files.Hint)
			pos, lim: LONGINT;
			next: Buffer;
			data: POINTER TO ARRAY OF CHAR
		END;

		FileSystem = OBJECT(Files.FileSystem)
			VAR
				pri, sup, cur: VolDesc;
				jolietLevel: LONGINT;

			(** Open an existing file. The same file descriptor is returned if a file is opened multiple times.  End users use Files.Old instead. *)
			PROCEDURE Old0(name: ARRAY OF CHAR): Files.File;
			VAR f: File; namebuf: Filename; dircl, dirpos, time, date, filecl, len: LONGINT; attr: SET; res: INTEGER;
			BEGIN {EXCLUSIVE}
				res := 0; f := NIL;
				Check(name, namebuf, res);
				IF res = 0 THEN
					LocateFile(namebuf, SELF, dircl, dirpos, time, date, filecl, len, attr, res);
					IF debug THEN LogString("Old0; filecl: "); LogInt(filecl); LogLn END;
					IF res = 0 THEN
						IF Directory IN attr THEN res := eCannotOpenSubDir
						ELSIF filecl < 16 THEN res := eInvalidFirstCluster
						ELSE f := OpenFile(namebuf, SELF, dircl, dirpos, time, date, filecl, len, attr)
						END
					END
				END;
				RETURN f
			END Old0;

			(** Enumerate canonical file names. mask may contain * wildcards.  For internal use only.  End users use Enumerator instead. *)
			PROCEDURE Enumerate0(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
			VAR
				fname, name, mmask, pname, fullname: Filename;
				f: Files.File; R: Files.Rider;
				attr: SET; bAddToEnum: BOOLEAN;
				pos, time, date, len, cl: LONGINT; res: INTEGER;
			BEGIN {EXCLUSIVE}
				Check(mask, name, res);
				IF (res = 0) OR (res = eNameIsWild) THEN
					SeparateName(name, name, mmask); IF (mmask = "") THEN COPY("*", mmask) END;
					Files.JoinName(prefix, name, pname);
					IF nameDebug THEN LogString("Enumerate; dir name: "); LogString(pname); LogLn END;
					f := OldDir(SELF, name);
					IF f # NIL THEN
						f.Set(R, 0); pos := 0;
						LOOP
							MatchFile(R, mmask, fname, pos, cl, time, date, len, attr, res);
							IF res # 0 THEN EXIT END;
							COPY(pname, fullname);
							IF name[0] # 0X THEN Files.AppendStr("/", fullname) END;
							Files.AppendStr(fname, fullname);

							bAddToEnum := TRUE;
							IF Directory IN attr THEN
								IF (fname = ".") OR (fname = "..") THEN
									bAddToEnum := FALSE;
								END;
								flags := { Files.Directory };
								len := 0;
							ELSE
								flags := {};
							END;

							IF bAddToEnum THEN
								enum.PutEntry(fullname, flags, time, date, len)
							END;
						END;
					ELSE res := eFileDoesNotExist
					END
				END
			END Enumerate0;

			(** Return the unique non-zero key of the named file, if it exists. *)
			PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
			VAR res: INTEGER; namebuf: Filename; t, key, filecl: LONGINT; attr: SET;
			BEGIN {EXCLUSIVE}
				IF nameDebug THEN LogString("OFSFATFiles.FileKey: "); LogString(name); LogLn END;
				key := 0;
				Check(name, namebuf, res);
				IF res = 0 THEN
					LocateFile(namebuf, SELF, t, t, t, t, filecl, t, attr, res);
					IF res = 0 THEN key := filecl END
				END;
				RETURN key
			END FileKey;

			(** Finalize the file system. *)
			PROCEDURE Finalize*;
			BEGIN {EXCLUSIVE}
				vol.Finalize;
				Finalize^
			END Finalize;
		END FileSystem;

		File = OBJECT (Files.File)
		VAR
			len,
			time, date,
			filecl: LONGINT;	(* first cluster *)
			attr: SET ;	(* ISO file attributes *)
			(* directory info *)
			name: Filename;
			dircl,	(* start cluster of dir. that contains entry for file *)
			dirpos: LONGINT;		(* position in cluster of dir. in which entry lies *)
			nofbufs: INTEGER;
			firstbuf: Buffer;

			PROCEDURE Set*(VAR r: Files.Rider; pos: LONGINT);
			BEGIN {EXCLUSIVE}
				r.eof := FALSE; r.res := 0; r.file := SELF; r.fs := fs;
				IF (pos < 0) THEN r.apos := 0
				ELSIF (pos < len) THEN r.apos := pos
				ELSE r.apos := len
				END;
				r.hint := firstbuf
			END Set;

			PROCEDURE Pos*(VAR r: Files.Rider): LONGINT;
			BEGIN {EXCLUSIVE}
				RETURN r.apos
			END Pos;

			PROCEDURE FindBuf(pos: LONGINT; hint: Buffer): Buffer;
			VAR buf: Buffer;
			BEGIN
				buf := hint;
				LOOP
					IF (pos >= buf.pos) & (pos < buf.pos+buf.lim) THEN EXIT END;
					buf := buf.next;
					IF buf = hint THEN buf := NIL;  EXIT END
				END;
				RETURN buf
			END FindBuf;

			PROCEDURE ReadBuf(buf: Buffer; pos: LONGINT);
			BEGIN
				ASSERT(pos <= len, 100);
				buf.pos := pos - pos MOD fs.vol.blockSize;
				pos := pos DIV fs.vol.blockSize;
				IF pos = len DIV fs.vol.blockSize THEN buf.lim := len MOD fs.vol.blockSize
				ELSE buf.lim := fs.vol.blockSize
				END;
				IF debug THEN LogString("ReadBuf; block: "); LogInt(filecl+pos); LogLn END;
				fs.vol.GetBlock(filecl+pos, buf.data^)
			END ReadBuf;

			PROCEDURE GetBuf(pos: LONGINT; hint: Buffer): Buffer;
			VAR buf: Buffer;
			BEGIN
				buf := FindBuf(pos, hint);
				IF buf = NIL THEN
					IF nofbufs < MaxBufs THEN (*allocate new buffer*)
						NEW(buf);  NEW(buf.data, fs.vol.blockSize);
						buf.next := firstbuf.next;  firstbuf.next := buf;
						INC(nofbufs)
					ELSE (*reuse one of the buffers; round robin *)
						buf := firstbuf; firstbuf := buf.next;
					END;
					ReadBuf(buf, pos);
				END;
				RETURN buf
			END GetBuf;

			PROCEDURE Read*(VAR r: Files.Rider; VAR x: CHAR);
			VAR buf: Buffer;
			BEGIN {EXCLUSIVE}
				r.res := 0;
				IF (r.apos < len) THEN
					buf := GetBuf(r.apos, r.hint(Buffer));
					x := buf.data[r.apos-buf.pos];
					INC(r.apos)
				ELSE
					x := 0X; r.eof := TRUE
				END
			END Read;

			PROCEDURE ReadBytes*(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
			VAR m, pos: LONGINT; src: ADDRESS; buf: Buffer;
			BEGIN {EXCLUSIVE}
				IF LEN(x) < len THEN SYSTEM.HALT(19) END;
				IF len <= 0 THEN RETURN END;
				buf := r.hint(Buffer);
				m := SELF.len - r.apos;
				IF len <= m THEN r.res := 0 ELSE r.eof := TRUE; r.res := len-m; len := m END;
				WHILE len > 0 DO
					buf := GetBuf(r.apos, buf);
					pos := r.apos - buf.pos;
					src := ADDRESSOF(buf.data[pos]);  m := buf.lim-pos;
					IF m > len THEN m := len END;
					SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), m);
					DEC(len, m); INC(ofs, m); INC(r.apos, m);
				END;
				r.hint := buf
			END ReadBytes;

			PROCEDURE Length*(): LONGINT;
			BEGIN RETURN len
			END Length;

			PROCEDURE GetDate*(VAR t, d: LONGINT);
			BEGIN t := time; d := date
			END GetDate;

			PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
			BEGIN COPY(SELF.name, name)
			END GetName;

			PROCEDURE Update*;
			END Update; (* nothing *)
		END File;

	VAR	(* svr *)
		ExtractNameProc: PROCEDURE(VAR dir, name: ARRAY OF CHAR);

	(* debug procedures *)

	PROCEDURE LogString(s: ARRAY OF CHAR);
	BEGIN
		KernelLog.String(s)
	END LogString;

	PROCEDURE LogInt(i: LONGINT);
	BEGIN
		KernelLog.Int(i, 0)
	END LogInt;

	PROCEDURE LogLn;
	BEGIN
		KernelLog.Ln
	END LogLn;

	(* help procedures *)

	(* Get733 - 32 bit, both byte orders *)
	PROCEDURE Get733(VAR s: ARRAY OF CHAR; first: LONGINT; VAR d: LONGINT);
	BEGIN
		d := LONG(ORD(s[first]));
		d := d + LONG(ORD(s[first+1]))*100H;
		d := d + LONG(ORD(s[first+2]))*10000H;
		d := d + LONG(ORD(s[first+3]))*1000000H
	END Get733;

	(* Check - check filename.  Return correct name, or empty name if incorrect. *)
	PROCEDURE Check(s: ARRAY OF CHAR;  VAR name: Filename; VAR res: INTEGER);
	VAR i, j: LONGINT;  ch: CHAR;
	BEGIN
		IF nameDebug THEN LogString("Check: "); LogString(s) END;
		res := 0; i := 0;
		IF (s[0] = "/") OR (s[0] = "\") THEN j := 1 ELSE j := 0 END;		(* remove leading / or \ *)
		LOOP
			ch := s[j];
			IF ch = 0X THEN EXIT END;
			IF ch = "\" THEN ch := "/" END;
			IF (ch < " ") OR (ch >= 07FX) THEN res := eInvalidFileName; i := 0; EXIT END;
			IF (ch = "?") OR (ch = "*") THEN res := eNameIsWild END;
			name[i] := ch;
			INC(i); INC(j)
		END;
		name[i] := 0X;
		IF nameDebug THEN LogString(" => "); LogString(name); LogLn END;
	END Check;

	PROCEDURE GetVolumeDescriptors(fs: FileSystem; res: INTEGER);
	VAR b: ARRAY SS OF CHAR; i: LONGINT; vol: Files.Volume;
	BEGIN
		vol := fs.vol;
		i := 16; fs.pri := NIL; fs.sup := NIL; fs.cur := NIL; fs.jolietLevel := 0;
		REPEAT
			vol.GetBlock(i, b);	(* read boot sector *)
			CASE b[0] OF
				1X: (* Primary volume descriptor *)
					ASSERT(fs.pri = NIL, 102);	(* exactly one primary volume desc *)
					NEW(fs.pri);
					Get733(b, 158, fs.pri.root);	(* location of root directory *)
					Get733(b, 166, fs.pri.rootDirSize)	(* size of root directory in bytes *)
			|	2X: (* Supplementary volume descriptor  *)
					ASSERT(fs.sup = NIL, 103);	(* 0 or 1 supplementary volume descriptor *)
					ASSERT((b[88] = 25X) & (b[89] = 2FX) & ((b[90] = 40X) OR (b[90] = 43X) OR (b[90] = 45X)), 104);
					IF b[90] = 40X THEN fs.jolietLevel := 1
					ELSIF b[90] = 43X THEN fs.jolietLevel := 2
					ELSIF b[90] = 45X THEN fs.jolietLevel := 3
					END;
					NEW(fs.sup);
					Get733(b, 158, fs.sup.root);	(* location of root directory *)
					Get733(b, 166, fs.sup.rootDirSize)	(* size of root directory in bytes *)
			ELSE ASSERT((b[0] = 0X) OR (b[0] = 2X) OR (b[0] = 0FFX), 100)	(* boot or end *)
			END;
			INC(i)
		UNTIL (res # 0) OR (b[0] = 0FFX);
		IF res = 0 THEN
			IF fs.pri = NIL THEN res := eInvalidVolume
			ELSIF fs.sup # NIL THEN fs.cur := fs.sup; ExtractNameProc := ExtractLongName
			ELSE fs.cur := fs.pri; ExtractNameProc := ExtractShortName
			END
		END;
	END GetVolumeDescriptors;

	(* GetDir - Get information from a directory entry *)
	PROCEDURE GetDir(VAR dir, fname: ARRAY OF CHAR; VAR time, date, cl, len: LONGINT; VAR attr: SET);
	VAR t: LONGINT;
	BEGIN
		ExtractName(dir, fname);
		t (*attr*) := ORD(dir[24]); attr := SYSTEM.VAL(SET, t);
		time := LONG(ORD(dir[20]))*64*64 + LONG(ORD(dir[21]))*64 + LONG(ORD(dir[22]));
		date := LONG(ORD(dir[17]))*32*16 + LONG(ORD(dir[18]))*16 + LONG(ORD(dir[19]));
		Get733(dir, 1, cl);
		Get733(dir, 9, len)
	END GetDir;

	PROCEDURE SplitName(str: ARRAY OF CHAR; VAR prefix, name: ARRAY OF CHAR);
	VAR i, j: LONGINT;
	BEGIN
		IF nameDebug THEN LogString("SplitName: "); LogString(str) END;
		i := -1; j := -1;
		REPEAT INC(i); INC(j); prefix[j] := str[i] UNTIL (str[i] = 0X) OR (str[i] = "/");
		IF str[i] = "/" THEN
			prefix[j] := 0X; j := -1;
			REPEAT INC(i); INC(j); name[j] := str[i] UNTIL name[j] = 0X
		ELSE name[0] := 0X
		END;
		IF nameDebug THEN LogString(" => "); LogString(prefix); LogString(", "); LogString(name); LogLn END
	END SplitName;

	(* SeparateName - separate str into a prefix and a name. *)
	PROCEDURE SeparateName(str: ARRAY OF CHAR; VAR prefix: ARRAY OF CHAR; VAR name: Filename);
	VAR i, j : LONGINT;
	BEGIN
	(* Pre: str is result of a Check operation; all "\"s have been changed to "/" *)
		i := 0;  j := -1;
		WHILE str[i] # 0X DO
			IF str[i] = "/" THEN j := i END;
			INC(i)
		END;
		IF j >= 0 THEN
			COPY(str, prefix); prefix[j] := 0X;
			i := -1;
			REPEAT INC(i); INC(j); name[i] := str[j] UNTIL name[i] = 0X
		ELSE COPY(str, name); prefix[0] := 0X
		END
	END SeparateName;

	PROCEDURE ExtractShortName(VAR dir, name: ARRAY OF CHAR);
	VAR i, j, len: LONGINT;
	BEGIN
		len := ORD(dir[31]);
		i := 0;  j := 32;
		WHILE (i < len) & (dir[j] # ";") DO name[i] := dir[j];  INC(i); INC(j) END;
		name[i] := 0X;
	END ExtractShortName;

	PROCEDURE ExtractLongName(VAR dir, name: ARRAY OF CHAR);
	VAR i, j, end: LONGINT;
	BEGIN
		end := 33+ORD(dir[31]);
		i := 0;  j := 33;
		WHILE (j < end) & (dir[j] # ";") DO name[i] := dir[j];  INC(i); INC(j, 2) END;
		name[i] := 0X;
	END ExtractLongName;

	PROCEDURE ExtractName(VAR dir, name: ARRAY OF CHAR);
	VAR len: LONGINT;
	BEGIN
		len := ORD(dir[31]);
		IF len = 1 THEN
			IF dir[33] = 0X THEN COPY(".", name)
			ELSIF dir[33] = 1X THEN COPY("..", name)
			END
		ELSE ExtractNameProc(dir, name)
		END
	END ExtractName;

	PROCEDURE MatchFile(VAR R: Files.Rider; name: ARRAY OF CHAR; VAR fname: ARRAY OF CHAR;
		VAR pos, cl, time, date, len: LONGINT; VAR attr: SET; VAR res: INTEGER);
	VAR
		found: BOOLEAN; f: File; fs: FileSystem; buf: ARRAY 256 OF CHAR; entryLen, padding: LONGINT;
	BEGIN
		f := R.file(File); fs := R.fs(FileSystem);
		found := FALSE;
		LOOP
			pos := R.file.Pos(R);
			IF debug THEN LogString("MatchFile; pos: "); LogInt(pos); LogLn END;
			R.file.Read(R, buf[0]); entryLen := ORD(buf[0]);
			IF debug THEN LogString("MatchFile; entryLen: "); LogInt(entryLen); LogLn END;
			IF R.eof THEN
				IF debug THEN LogString("MatchFile; eof"); LogLn END;
				EXIT
			END;
			IF entryLen > 0 THEN
				R.file.ReadBytes(R, buf, 0, entryLen-1);
				GetDir(buf, fname, time, date, cl, len, attr);
				found := Strings.Match(name, fname);
			ELSE (* Directory entries may not cross sectors. Skip padding bytes *)
				padding := SS - (R.file.Pos(R) MOD SS);
				IF (padding > 0) & (padding <= 256) THEN
					IF debug THEN LogString("MatchFile; skip padding: "); LogInt(padding); LogLn; END;
					R.file.ReadBytes(R, buf, 0, padding); (* Skip padding *)
				ELSE
					IF debug THEN LogString("MatchFile; Confusing directory structure... givin' up"); END;
					EXIT;
				END;
			END;
			IF found THEN EXIT END;
		END;
		IF found THEN res := 0 ELSE res := eInvalidFileName END;
	END MatchFile;

	PROCEDURE FindFile(fs: FileSystem; name: ARRAY OF CHAR; dircl, dirlen: LONGINT;
		VAR dirpos, time, date, filecl, len: LONGINT; VAR attr: SET; VAR res: INTEGER);
	VAR f: File; R: Files.Rider; fname: Filename;
	BEGIN
		ASSERT(name # "", 100);
		f := OpenFile("", fs, -1, -1, -1, -1, dircl, dirlen, {});
		f.Set(R, 0);
		MatchFile(R, name, fname, dirpos, filecl, time, date, len, attr, res);
	END FindFile;

	PROCEDURE LocateFile(name: ARRAY OF CHAR; fs: FileSystem;
		VAR dircl, dirpos, time, date, filecl, len: LONGINT; VAR attr: SET; VAR res: INTEGER);
	VAR cur: Filename; dirlen: LONGINT;
	BEGIN
		res := 0;
		dircl := fs.cur.root; dirlen := fs.cur.rootDirSize;	(* start in root directory *)
		IF name[0] = 0X THEN (* root dir *)
			filecl := dircl; attr := {Directory};
			len := dirlen; dirpos := -1;
		ELSE
			LOOP
				SplitName(name, cur, name);
				FindFile(fs, cur, dircl, dirlen, dirpos, time, date, filecl, len, attr, res);
				IF (res = 0) & (name # "") & ~(Directory IN attr) THEN res := eInvalidFileName END;
				IF (res # 0) OR (name = "") THEN EXIT END;
				dircl := filecl; dirlen := len
			END
		END
	END LocateFile;

	PROCEDURE OpenFile(name: ARRAY OF CHAR; fs: FileSystem; dircl, dirpos, time, date, filecl, len: LONGINT; attr: SET): File;
	VAR f: File; buf: Buffer;
	BEGIN
		NEW(f); COPY(name, f.name); f.fs := fs; f.key := filecl;
		f.dircl := dircl; f.dirpos := dirpos; f.time := time; f.date := date;
		f.filecl := filecl; f.len := len; f.attr := attr;
		NEW(buf); buf.next := buf;
		NEW(buf.data, fs.vol.blockSize);
		IF f.len = 0 THEN buf.pos := 0; buf.lim := 0
		ELSE f.ReadBuf(buf, 0) (* file is not empty *)
		END;
		f.firstbuf := buf;  f.nofbufs := 1;
		RETURN f
	END OpenFile;

	PROCEDURE OldDir(fs: Files.FileSystem; name: ARRAY OF CHAR): Files.File;
	VAR f: File; dircl, dirpos, time, date, filecl, len: LONGINT; attr: SET; res: INTEGER;
	BEGIN
		res := 0; f := NIL;
		LocateFile(name, fs(FileSystem), dircl, dirpos, time, date, filecl, len, attr, res);
		IF res = 0 THEN
			IF ~(Directory IN attr) THEN res := eCannotOpenSubDir
			ELSIF filecl < 16 THEN res := eInvalidFirstCluster
			ELSE f := OpenFile(name, fs(FileSystem), dircl, dirpos, time, date, filecl, len, attr)
			END
		END;
		RETURN f
	END OldDir;

(** Generate a new file system object.  OFS.NewVol has volume parameter, OFS.Par has mount prefix. *)
PROCEDURE NewFS*(context : Files.Parameters);
VAR fs: FileSystem; res: INTEGER;
BEGIN
	IF Files.This(context.prefix) = NIL THEN
		NEW(fs);  fs.vol := context.vol;
		GetVolumeDescriptors(fs, res);
		IF res = 0 THEN
			IF debug THEN
				LogString("  primary root: "); LogInt(fs.pri.root); LogLn;
				LogString("  primary root dir size: "); LogInt(fs.pri.rootDirSize); LogLn
			END;
			fs.desc[0] := 0X;  Files.AppendStr(context.vol.name, fs.desc);  Files.AppendStr(" / ISO9660FS", fs.desc);
			Files.Add(fs, context.prefix)
		ELSE context.error.String("No ISO9660 file system found on "); context.error.String(context.vol.name); context.error.Ln;
		END
	ELSE context.error.String(context.prefix); context.error.String(" already in use"); context.error.Ln;
	END;
END NewFS;

(* Clean up when module freed. *)
PROCEDURE Cleanup;
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
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END ISO9660Files.

ISO9660Volumes.Mod

Partitions.Show

OFSTools.Mount CD IsoFS  IDE2 ~
OFSTools.Unmount CD0 ~

SystemTools.Free ISO9660Files  ISO9660Volumes ~

System.Directory CD:*.* ~

History:

30.05.2006	Fixed MatchFile: Directory entries may not cross sector boundaries. Skip padding bytes if necessary. (staubesv)