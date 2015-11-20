MODULE SambaClient; (** AUTHOR "mancos"; PURPOSE "SMB Client"; *)

IMPORT
	SYSTEM, Streams, KernelLog, Dates, Strings, Locks, Files, DNS, IP, TCP;

CONST
	PID = 9876;
	NativeOS = "A2";
	NativeLanMan = "STECIFS";
	PrimaryDomain = "WORKGROUP";
	Trace = FALSE;
	SendBufferSize = 32000;
	RWLimit = 2048;
	SMBPort* = 445;

TYPE
	Connection = POINTER TO RECORD
		out: Streams.Writer;
		in: Streams.Reader;
		tid, uid, sid: INTEGER;
		ipaddr: ARRAY 16 OF CHAR;
		user, pw: ARRAY 64 OF CHAR;
		path, mask, fnLast: ARRAY 256 OF CHAR;
	END;

	FileSystem* = OBJECT(Files.FileSystem)	(** shareable *)
		VAR
			c: Connection;
			connection: TCP.Connection;
			lock: Locks.RecursiveLock;

		(** Create a new file with the specified name.  End users use Files.New instead. *)

		PROCEDURE New0*(name: ARRAY OF CHAR): Files.File;
		VAR
			key: LONGINT;
			f: File;
		BEGIN
			IF Trace THEN KernelLog.String("FileSystem.New - Name: "); KernelLog.String(name); KernelLog.Ln(); END;
			lock.Acquire();
			key := OpenAndX(c, name, 41H, TRUE);
			lock.Release();

			IF key # 0 THEN
				NEW(f);
				f.fs := SELF;
				f.c := c;
				f.key := key;
				f.openRead := FALSE;
				COPY(name, f.filename);
				RETURN f;
			ELSE
				RETURN NIL;
			END;
		END New0;

		(** Open an existing file. The same file descriptor is returned if a file is opened multiple times.  End users use Files.Old instead. *)

		PROCEDURE Old0*(name: ARRAY OF CHAR): Files.File;
		VAR
			f: File;
			key: LONGINT;
		BEGIN
			IF Trace THEN KernelLog.String("FileSystem.Old - Name: "); KernelLog.String(name); KernelLog.Ln(); END;

			key := FileKey(name);

			IF key # 0 THEN
				NEW(f);
				f.c := c;
				f.fs := SELF;
				f.key := key;
				f.openRead := TRUE;
				COPY(name, f.filename);
				RETURN f;
			ELSE
				RETURN NIL;
			END;
		END Old0;

		(** Delete a file. res = 0 indicates success.  End users use Files.Delete instead. *)

		PROCEDURE Delete0*(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		VAR
			check : BOOLEAN;
			closekey : LONGINT;
		BEGIN
			IF Trace THEN
				KernelLog.String("FileSystem.Delete"); KernelLog.Ln();
				KernelLog.String(" -- Name: "); KernelLog.String(name); KernelLog.Ln();
			END;

			lock.Acquire();
			closekey := OpenAndX(c, name, 40H, FALSE);
			CloseFile(c, closekey);
			lock.Release();
			Strings.TrimLeft(name, CHR(2FH));

			lock.Acquire();
			(* SEND *)
			SendSMBHeader(SHORT(39 + Strings.Length(name)), 06X, c);
			c.out.Net8(1);								(* Word count *)
			c.out.RawInt(22);							(* search attributes *)
			c.out.RawInt(SHORT(2 + Strings.Length(name)));
			c.out.Net8(4);								(* ascii *)
			c.out.RawString(name);						(* name *)
			c.out.Update();

			(* RECEIVE *)
		 	check := RecieveResponse(06X, c);
		 	lock.Release();

			IF ~check THEN
				IF Trace THEN KernelLog.String(" -- ERROR on Delete"); KernelLog.Ln(); END;
 				res := -1;
 			ELSE
 				res := 0;
 			END;
		END Delete0;

		(** Rename a file. res = 0 indicates success.  End users use Files.Rename instead. *)

		PROCEDURE Rename0*(old, new: ARRAY OF CHAR; f: Files.File; VAR res: LONGINT);
		VAR
			check : BOOLEAN;
			closekey : LONGINT;
		BEGIN
			IF Trace THEN
				KernelLog.String("FileSystem.Rename"); KernelLog.Ln();
				KernelLog.String(" -- Old: "); KernelLog.String(old); KernelLog.Ln();
				KernelLog.String(" -- New: "); KernelLog.String(new); KernelLog.Ln();
			END;

			lock.Acquire();
			closekey := OpenAndX(c, old, 40H, FALSE);
			CloseFile(c, closekey);
			lock.Release();
			ReplaceSlash(old);
			ReplaceSlash(new);

			lock.Acquire();
			(* SEND *)
			SendSMBHeader(SHORT(41 + Strings.Length(new) + Strings.Length(old)), 07X, c);
			c.out.Net8(1);			(* Word count *)
			c.out.RawInt(22);		(* search attributes *)
			c.out.RawInt(SHORT(4 + Strings.Length(new) + Strings.Length(old)));
			c.out.Net8(4);			(* ascii *)
			c.out.RawString(old);	(* old name *)
			c.out.Net8(4);			(* ascii *)
			c.out.RawString(new);	(* new name *)
			c.out.Update();

			(* RECEIVE *)
		 	check := RecieveResponse(07X, c);
		 	lock.Release();

			IF ~check THEN
				IF Trace THEN KernelLog.String(" -- ERROR on Rename"); KernelLog.Ln(); END;
 				res := -1;
 			ELSE
 				res := 0;
 			END;
		END Rename0;

		(** Enumerate canonical file names. mask may contain * wildcards.  For internal use only.  End users use Enumerator instead. *)

		PROCEDURE Enumerate0*(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
		VAR
			check, endOfSearch, findFirst: BOOLEAN;
			byteCount, dataOff, paraOff, eos: INTEGER;
			fileFlags : SET;
			attr, curPos, nextEntryOff, progress, maskLen: LONGINT;
			t: ARRAY 2 OF LONGINT;
			ch: ARRAY 2 OF CHAR;
			dt: Dates.DateTime;
			date, time, size: LONGINT;
			dirMask, filename: ARRAY 256 OF CHAR;
		BEGIN
			endOfSearch := FALSE;
			findFirst := TRUE;
			maskLen := Strings.Length(mask);
			COPY(mask, dirMask);
			ReplaceSlash(mask);

			IF Trace THEN
				KernelLog.String("FileSystem.Enumerate"); KernelLog.Ln();
				KernelLog.String(" -- Mask: "); KernelLog.String(mask); KernelLog.Ln();
			END;

			IF mask = "*" THEN
				ch[0] := CHR(92); ch[1] := 0X;
				Strings.Concat(ch, "*", c.mask);
				dirMask := "/";
			ELSIF Strings.EndsWith("\\*", mask) THEN
				Strings.Truncate(mask, maskLen - 2);
				Strings.Truncate(dirMask, maskLen - 2);
				Strings.Concat(mask, "*", c.mask);
			ELSIF Strings.EndsWith("\*", mask) THEN
				Strings.Truncate(mask, maskLen - 1);
				Strings.Truncate(dirMask, maskLen - 1);
				Strings.Concat(mask, "*", c.mask);
			ELSE
				RETURN;
			END;

			WHILE ~endOfSearch DO

				lock.Acquire();

				IF findFirst THEN
					check := Trans2Find(c, 1);
				ELSE
					check := Trans2Find(c, 2);
				END;

				IF ~check THEN
					IF Trace THEN KernelLog.String(" -- ERROR on Enumerate"); KernelLog.Ln(); END;
	 				lock.Release();
 					RETURN;
 				END;

				(* RECEIVE *)
				c.in.SkipBytes(1);		(* wct *)
				c.in.SkipBytes(2);		(* parameter count *)
				c.in.SkipBytes(2);		(* data count *)
				c.in.SkipBytes(2);		(* reserved *)
				c.in.SkipBytes(2);		(* parameter count *)
				c.in.RawInt(paraOff);	(* parameter offset *)
				c.in.SkipBytes(2);		(* parameter displacement *)
				c.in.RawInt(byteCount);	(* data count *)
				c.in.RawInt(dataOff);	(* data offset *)
				c.in.SkipBytes(2);		(* data displacement *)
				c.in.SkipBytes(1);		(* setup count *)
				c.in.SkipBytes(1);		(* reserved *)
				c.in.SkipBytes(2);		(* byte count *)
				c.in.SkipBytes(paraOff - 55);

				IF findFirst THEN
					c.in.RawInt(c.sid);	(* search id *)
				END;

				c.in.SkipBytes(2);		(* search count *)
				c.in.RawInt(eos);		(* end of search *)

				IF eos = 1 THEN
					endOfSearch := TRUE;
				END;

				c.in.SkipBytes(2);		(* EA error *)
				c.in.SkipBytes(2);		(* last name offset *)

				IF findFirst THEN
					c.in.SkipBytes(dataOff - paraOff - 10);
				ELSE
					c.in.SkipBytes(dataOff - paraOff - 8);
				END;

				progress := 0;
				check := TRUE;

				WHILE progress < byteCount DO
					curPos := c.in.Pos();
					c.in.RawLInt(nextEntryOff);
					IF nextEntryOff = 0 THEN
						check := FALSE;
						progress := byteCount;
					ELSE
						progress := progress + nextEntryOff;	(* next entry offset *)
						curPos := curPos + nextEntryOff;
					END;
					c.in.SkipBytes(4);		(* file index *)
					c.in.SkipBytes(8);		(* creation time *)
					c.in.SkipBytes(8);		(* last access *)
					c.in.RawLInt(t[0]);
					c.in.RawLInt(t[1]);		(* last write *)
					GetDateTime(t, dt);
					IF ~Dates.ValidDateTime(dt) THEN
						dt := Dates.Now();
						KernelLog.String("SambaClient: Replaced invalid date & time by current time"); KernelLog.Ln;
					END;
					Dates.DateTimeToOberon(dt, date, time);
					c.in.SkipBytes(8);		(* change *)
					c.in.RawLInt(size);
					c.in.SkipBytes(4);		(* end of file *)
					c.in.SkipBytes(8);		(* allocation *)
					c.in.RawLInt(attr);		(* attributes *)
					fileFlags := {};
					IF (4 IN SYSTEM.VAL(SET, attr)) THEN INCL(fileFlags, Files.Directory); END;
					IF (0 IN SYSTEM.VAL(SET, attr)) THEN INCL(fileFlags, Files.ReadOnly); END;
					c.in.SkipBytes(4);		(* name len *)
					c.in.SkipBytes(4);		(* ea len *)
					c.in.SkipBytes(1);		(* short file len *)
					c.in.SkipBytes(1);		(* reserved *)
					c.in.SkipBytes(24);		(* short file name *)
					c.in.RawString(filename);
					COPY(filename, c.fnLast);
					Strings.Concat(dirMask, filename, filename);
					Files.JoinName(prefix, filename, filename);

					enum.PutEntry(filename, fileFlags, time, date, size);

					WHILE (c.in.Pos() # curPos) & check DO
						c.in.SkipBytes(1);
					END;
				END;
				findFirst := FALSE;
				lock.Release();
			END;
		END Enumerate0;

		(** Return the unique non-zero key of the named file, if it exists. *)

		PROCEDURE FileKey*(name: ARRAY OF CHAR): LONGINT;
		VAR key: LONGINT;
		BEGIN
			lock.Acquire();
			key := OpenAndX(c, name, 40H, FALSE);
			lock.Release();
			RETURN key;
		END FileKey;

		(** Create a new directory structure. May not be supported by the actual implementation.
			End users use Files.CreateDirectory instead.*)

		PROCEDURE CreateDirectory0*(name: ARRAY OF CHAR; VAR res: LONGINT);
		VAR check: BOOLEAN;
		BEGIN
			IF Trace THEN
				KernelLog.String("FileSystem.CreateDirectory"); KernelLog.Ln();
				KernelLog.String(" -- Name: "); KernelLog.String(name); KernelLog.Ln();
			END;

			lock.Acquire();
			(* SEND *)
			SendSMBHeader(SHORT(37+ Strings.Length(name)), 00X, c);
			c.out.Net8(0);											(* Word count *)
			c.out.RawInt(SHORT(2 + Strings.Length(name)));			(* byte count *)
			c.out.Net8(4);											(* buffer format *)
			c.out.RawString(name);
			c.out.Update();

			(* RECEIVE *)
		 	check := RecieveResponse(00X, c);
		 	lock.Release();

			IF ~check THEN
				IF Trace THEN KernelLog.String(" -- ERROR on CreateDirectory"); KernelLog.Ln(); END;
 				res := -1;
 			ELSE
 				res := 0;
 			END;
		END CreateDirectory0;

		(** Remove a directory. If force=TRUE, any subdirectories and files should be automatically deleted.
			End users use Files.RemoveDirectory instead. *)

		PROCEDURE RemoveDirectory0*(name: ARRAY OF CHAR; force: BOOLEAN; VAR key, res: LONGINT);
		VAR check: BOOLEAN;
		BEGIN
			IF Trace THEN
				KernelLog.String("FileSystem.DeleteDirectory"); KernelLog.Ln();
				KernelLog.String(" -- Name: "); KernelLog.String(name); KernelLog.Ln();
			END;

			lock.Acquire();
			(* SEND *)
			SendSMBHeader(SHORT(37+ Strings.Length(name)), 01X, c);
			c.out.Net8(0);											(* Word count *)
			c.out.RawInt(SHORT(2 + Strings.Length(name)));			(* byte count *)
			c.out.Net8(4);											(* buffer format *)
			c.out.RawString(name);
			c.out.Update();

			(* RECEIVE *)
		 	check := RecieveResponse(01X, c);
		 	lock.Release();

			IF ~check THEN
				IF Trace THEN KernelLog.String(" -- ERROR on DeleteDirectory"); KernelLog.Ln(); END;
 				res := -1;
 			ELSE
 				res := 0;
 			END;
		END RemoveDirectory0;

		(** Finalize the file system. *)

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			connection.Close();
		END Finalize;

	END FileSystem;

TYPE

	File* = OBJECT(Files.File)	(** sharable *)
		VAR
			c: Connection;
			filename: ARRAY 256 OF CHAR;
			openRead: BOOLEAN;

		(** Position a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file. A Rider cannot be positioned beyond the end of a file. *)

		PROCEDURE Set*(VAR r: Files.Rider; pos: LONGINT);
		BEGIN
			r.apos := pos;
			r.file := SELF;
		END Set;

		(** Return the offset of a Rider positioned on a file. *)

		PROCEDURE Pos*(VAR r: Files.Rider): LONGINT;
		BEGIN
			RETURN r.apos;
		END Pos;

		(** Read a byte from a file, advancing the Rider one byte further.  R.eof indicates if the end of the file has been passed. *)

		PROCEDURE Read*(VAR r: Files.Rider; VAR x: CHAR);
		VAR a : ARRAY 1 OF CHAR;
		BEGIN
			a[0] := x;
			ReadBytes(r,a,0,1);
		END Read;

		(** Read a sequence of len bytes into the buffer x at offset ofs, advancing the Rider. Less bytes will be read when reading over the end of the file. r.res indicates the number of unread bytes. x must be big enough to hold all the bytes. *)

		PROCEDURE ReadBytes*(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR
			check: BOOLEAN;
			dataOff, byteCount, padding: INTEGER;
			i : LONGINT;
			adjLen, adjOff: INTEGER;
			localKey: INTEGER;
		BEGIN
			IF Trace THEN KernelLog.String("File.ReadBytes - Read AndX"); KernelLog.Ln(); END;

 			fs(FileSystem).lock.Acquire();

 			IF ~(openRead & (key # 0)) THEN
				localKey := OpenAndX(c, filename, 40H, FALSE);

				IF localKey # 0 THEN
					key := localKey;
					openRead := TRUE;
				ELSE
					r.res := len;
					fs(FileSystem).lock.Release();
					RETURN;
				END;
 			END;

		 	adjOff := 0;
			r.res := 0;
		 	WHILE len > 0 DO
	 			IF len > RWLimit THEN
	 				adjLen := RWLimit;
	 			ELSE
	 				adjLen := SHORT(len);
	 			END;

			 	(* SEND *)
			 	SendSMBHeader(55, 2EX, c);
			 	c.out.Net8(10);				(* word count *)
			 	c.out.Net8(255);			(* andx*)
			 	c.out.Net8(0);				(* reserved *)
			 	c.out.RawInt(0);				(* andx offset *)
			 	c.out.RawInt(SHORT(key));	(* fid *)
			 	c.out.RawLInt(r.apos);		(* offset *)
			 	c.out.RawInt(adjLen);		(* max count low *)
			 	c.out.RawInt(adjLen);		(* min count *)
			 	c.out.Net32(0);				(* max count 64k *)
			 	c.out.RawInt(0);				(* remaining *)
			 	c.out.RawInt(0);				(* byte count *)
			 	c.out.Update();

			 	(* RECEIVE *)
			 	check := RecieveResponse(2EX, c);

 				IF ~check THEN
 					IF Trace THEN KernelLog.String(" -- ERROR on Read AndX"); KernelLog.Ln(); END;
 					r.res := r.res + len;
 					fs(FileSystem).lock.Release();
 					RETURN;
 				END;

				c.in.SkipBytes(13);
				c.in.RawInt(dataOff);
				c.in.SkipBytes(10);
				c.in.RawInt(byteCount);

				IF (dataOff = 0) THEN
					r.res := r.res + len;
					fs(FileSystem).lock.Release();
					RETURN;
				END;

				padding := dataOff - 59;
				c.in.SkipBytes(padding);
				byteCount := byteCount - padding;

				IF Trace THEN KernelLog.String(" -- ByteCount: "); KernelLog.Int(byteCount, 0); KernelLog.Ln(); END;

				i := adjOff;

				c.in.Bytes(x, ofs, byteCount, i);
				ofs := ofs + i;
				r.apos := r.apos + i;

				r.res := r.res + adjLen - i;
				len := len - adjLen;
				adjOff := adjOff + adjLen;
			END;
			fs(FileSystem).lock.Release();
		END ReadBytes;

		(** Write a byte into the file at the Rider position, advancing the Rider by one. *)
		PROCEDURE Write*(VAR r: Files.Rider; x: CHAR);
		VAR
			a: ARRAY 1 OF CHAR;
		BEGIN
			a[0] := x;
			WriteBytes(r,a,0,1);
		END Write;

		(** Write the buffer x containing len bytes (starting at offset ofs) into a file at the Rider position. *)

		PROCEDURE WriteBytes*(VAR r: Files.Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR
			check: BOOLEAN;
			bytesWritten: INTEGER;
			adjLen, adjOff: INTEGER;
			localKey: INTEGER;
		BEGIN
			fs(FileSystem).lock.Acquire();

			IF ~(~openRead & (key # 0)) THEN
				localKey := OpenAndX(c, filename, 41H, FALSE);

				IF localKey # 0 THEN
					key := localKey;
					openRead := FALSE;
				ELSE
					r.res := len;
					fs(FileSystem).lock.Release();
					RETURN;
				END;
 			END;

			IF Trace THEN
				KernelLog.String("FileSystem.WriteBytes - Write AndX");
				KernelLog.String(" ("); KernelLog.Int(len, 0); KernelLog.String(" bytes from offset ");
				KernelLog.Int(ofs, 0); KernelLog.String(")");
				KernelLog.Ln();
			END;

	 		fs(FileSystem).lock.Acquire();
	 		adjOff := 0;

	 		WHILE len > 0 DO
	 			IF len > RWLimit THEN
	 				adjLen := RWLimit;
	 			ELSE
	 				adjLen := SHORT(len);
	 			END;

			 	(* Send *)
			 	SendSMBHeader(59 + adjLen, 2FX, c);
			 	c.out.Net8(12);				(* word count *)
			 	c.out.Net8(255);			(* andx*)
			 	c.out.Net8(0);				(* reserved *)
			 	c.out.RawInt(0);				(* andx offset *)
			 	c.out.RawInt(SHORT(key));	(* fid *)
			 	c.out.RawLInt(r.apos);		(* offset *)
			 	c.out.RawLInt(0);			(* reserved *)
			 	c.out.RawInt(0);				(* write mode *)
			 	c.out.RawInt(0);				(* remaining *)
			 	c.out.RawInt(0);				(* max count 64k *)
			 	c.out.RawInt(adjLen);		(* max count low *)
			 	c.out.RawInt(59);			(* data offset*)
			 	c.out.RawInt(adjLen);		(* byte count *)

			 	IF adjLen # 0 THEN
			 		IF Trace THEN KernelLog.String(" -- Write bytes: "); KernelLog.Int(adjLen, 0); KernelLog.Ln(); END;
			 		c.out.Bytes(x, adjOff, adjLen);
			 	ELSE
			 		IF Trace THEN KernelLog.String(" -- No bytes written!"); KernelLog.Ln(); END;
			 	END;
			 	c.out.Update();

				(* RECEIVE *)
 				check := RecieveResponse(2FX, c);

 				IF ~check THEN
	 				IF Trace THEN KernelLog.String(" -- ERROR on Write AndX"); KernelLog.Ln(); END;
 					fs(FileSystem).lock.Release();
 					RETURN;
 				END;

 				c.in.SkipBytes(5);
 				c.in.RawInt(bytesWritten);

 				IF Trace THEN
 					KernelLog.String(" -- Bytes written: "); KernelLog.Int(bytesWritten, 0); KernelLog.Ln();
				END;

				r.apos := r.apos + bytesWritten;
				len := len - adjLen;
				adjOff := adjOff + adjLen;
			END;
			fs(FileSystem).lock.Release();
		END WriteBytes;

		(** Return the current length of a file. *)

		PROCEDURE Length*(): LONGINT;
		VAR
			filesize: LONGINT;
			check: BOOLEAN;
		BEGIN
			fs(FileSystem).lock.Acquire();

			IF Trace THEN
				KernelLog.String("File.Length"); KernelLog.Ln();
				KernelLog.String(" -- Name: "); KernelLog.String(filename); KernelLog.Ln();
			END;

		 	(* SEND *)
		 	SendSMBHeader(37 + SHORT(Strings.Length(filename)), 08X, c);
			c.out.Net8(0);											(* word count *)
			c.out.RawInt(SHORT(Strings.Length(filename)) + 1);		(* byte count *)
			c.out.Net8(4);											(* buffer format ascii *)
			c.out.RawString(filename);								(* filename *)
			c.out.Update();

			IF Trace THEN KernelLog.String(" -- Query Information Request sent"); KernelLog.Ln(); END;

			(* RECEIVE *)
		 	check := RecieveResponse(08X, c);

 			IF ~check THEN
 				IF Trace THEN
	 				KernelLog.String(" -- ERROR on Query Information Request"); KernelLog.Ln();
	 			END;
 				fs(FileSystem).lock.Release();
 				RETURN 0;
 			END;

 			c.in.SkipBytes(7);
 			c.in.RawLInt(filesize);

			fs(FileSystem).lock.Release();

			IF Trace THEN KernelLog.String(" -- File size: "); KernelLog.Int(filesize, 0); KernelLog.Ln(); END;
			RETURN filesize;
		END Length;

		(** Return the time (t) and date (d) when a file was last modified. *)

		PROCEDURE GetDate*(VAR t, d: LONGINT);
		BEGIN HALT(301) END GetDate;	(* abstract *)

		(** Set the modification time (t) and date (d) of a file. *)

		PROCEDURE SetDate*(t, d: LONGINT);
		BEGIN HALT(301) END SetDate;	(* abstract *)

		(** Return the canonical name of a file. *)

		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN
			Files.JoinName(fs.prefix, filename, name);
			IF Trace THEN
				KernelLog.String("File.GetName"); KernelLog.Ln();
				KernelLog.String(" -- Name: "); KernelLog.String(name); KernelLog.Ln();
			END;
		END GetName;

		(** Register a file created with New in the directory, replacing the previous file in the directory with the same name. The file is automatically updated.  End users use Files.Register instead. *)

		PROCEDURE Register0*(VAR res: LONGINT);
		BEGIN END Register0;

		(** Flush the changes made to a file from its buffers. Register0 will automatically update a file. *)

		PROCEDURE Update*;
		BEGIN END Update;

	END File;

TYPE

	TCPSender = OBJECT
	VAR
		connection: TCP.Connection;

		PROCEDURE Connect(CONST host: ARRAY OF CHAR; port: LONGINT; VAR c: Connection);
		VAR
			fadr: IP.Adr;
			res: LONGINT;
		BEGIN {EXCLUSIVE}
			res := 0;
			DNS.HostByName(host, fadr, res);
			IF res = DNS.Ok THEN
				NEW(connection);
				connection.Open(TCP.NilPort, fadr, port, res);
				IF res = TCP.Ok THEN
					IF Trace THEN KernelLog.String("Connection open!"); KernelLog.Ln(); END;
					NEW(c.out, connection.Send, SendBufferSize);
					NEW(c.in, connection.Receive, SendBufferSize);
				END;
			END;
		END Connect;

	END TCPSender;

PROCEDURE SendSMBHeader(ntb: INTEGER; cmd: CHAR; c: Connection);
BEGIN
	(* NETBIOS *)
	c.out.Net16(0);
	c.out.Net16(ntb);

	(* SMB *)
	c.out.Char(CHR(255));
	c.out.String("SMB");
	c.out.Char(cmd);		(* Command *)
	c.out.Net32(0);			(* status code *)
	c.out.Net8(24);			(* FLAGS *)
	c.out.RawInt(1);			(* FLAGS 2 *)
	c.out.Net32(0);
	c.out.Net32(0);			(* EXTRA *)
	c.out.Net32(0);
	c.out.RawInt(c.tid);		(* TID *)
	c.out.RawInt(PID);		(* PID *)
	c.out.RawInt(c.uid);		(* UID *)
	c.out.RawInt(0);			(* MID *)
END SendSMBHeader;

PROCEDURE RecieveResponse(cmd: CHAR; c: Connection): BOOLEAN;
VAR
	check: BOOLEAN;
	variable: INTEGER;
BEGIN
	check := FALSE;
	c.in.Reset();

	(* NETBIOS *)
	c.in.SkipBytes(4);

	(* SMB *)
	check := CheckFFSMB(c);

	IF ~check THEN
		IF Trace THEN KernelLog.String("SMB Header does not start with 0xFF SMB");	 KernelLog.Ln(); END;
		c.in.Reset();
		RETURN FALSE;
	END;

	variable := SHORT(c.in.Net8());

	IF CHR(variable) # cmd THEN
		IF Trace THEN KernelLog.String("SMB Command is NOT "); KernelLog.Char(cmd); KernelLog.Ln(); END;
		c.in.Reset();
		RETURN FALSE;
	END;

	variable := SHORT(c.in.Net32());

	IF variable # 0 THEN
		IF Trace THEN KernelLog.String("There has been a DOS error"); KernelLog.Ln(); END;
		c.in.Reset();
		RETURN FALSE;
	END;

	c.in.SkipBytes(15);
	c.in.RawInt(variable);

	IF (c.tid = 0) & (variable > 0) THEN
		c.tid := variable;
	ELSIF (c.tid = variable) THEN
		(* OK *)
	ELSIF (c.tid # variable) THEN
		IF Trace THEN KernelLog.String(" -- TID does not match"); KernelLog.Ln(); END;
		RETURN FALSE;
	ELSE
		IF Trace THEN KernelLog.String(" -- TID Error "); KernelLog.Int(variable, 0); KernelLog.Ln(); END;
		RETURN FALSE;
	END;

	c.in.RawInt(variable);

	IF variable # PID THEN
		IF Trace THEN KernelLog.String(" -- PID does not match"); KernelLog.Ln(); END;
		RETURN FALSE;
	END;

	c.in.RawInt(variable);

	IF (c.uid = 0) & (variable > 0) THEN
		c.uid := variable;
	ELSIF (c.uid = variable) THEN
		(* OK *)
	ELSIF (c.uid # variable) THEN
		IF Trace THEN KernelLog.String(" -- UID does not match"); KernelLog.Ln(); END;
		RETURN FALSE;
	ELSE
		IF Trace THEN KernelLog.String(" -- UID Error "); KernelLog.Int(variable, 0); KernelLog.Ln(); END;
		RETURN FALSE;
	END;

	c.in.SkipBytes(2);
	RETURN TRUE;
END RecieveResponse;

PROCEDURE CheckFFSMB(c: Connection): BOOLEAN;
VAR
	variable: SHORTINT;
BEGIN
	c.in.RawSInt(variable);
	IF variable = -1 THEN
		c.in.RawSInt(variable);
		IF variable = 83 THEN
			c.in.RawSInt(variable);
			IF variable = 77 THEN
				c.in.RawSInt(variable);
				IF variable = 66 THEN
					RETURN TRUE;
				END;
			END;
		END;
	END;
	RETURN FALSE;
END CheckFFSMB;

PROCEDURE ReplaceSlash(VAR name: ARRAY OF CHAR);
VAR
	i: LONGINT;
BEGIN
	i := 0;
	WHILE (i < Strings.Length(name)) DO
		IF name[i] = CHR(2FH) THEN
			name[i] := CHR(5CH);
		END;
		INC(i)
	END;
END ReplaceSlash;

PROCEDURE NegotiateProtocol(c: Connection): BOOLEAN;
VAR
	check : BOOLEAN;
	variable: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Negotiate Protocol"); KernelLog.Ln(); END;

	(* SEND *)
	SendSMBHeader(47, 72X, c);
	c.out.Net8(0);			(* Word count *)
	c.out.Net8(12);			(* Byte count *)
	c.out.Net8(0);
	c.out.Char(2X);
	c.out.RawString("NT LM 0.12");
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(72X, c);

	IF ~check THEN
		RETURN FALSE;
	END;

	variable := c.in.Net8();

	IF variable # 17 THEN
		IF Trace THEN KernelLog.String(" -- Message Size is not 17: "); KernelLog.Int(variable, 2); KernelLog.Ln(); END;
		RETURN FALSE;
	ELSE
		IF Trace THEN KernelLog.String(" -- Message Size is 17: NT LM 0.12"); KernelLog.Ln(); END;
		RETURN TRUE;
	END;
END NegotiateProtocol;

PROCEDURE SessionSetup(c: Connection): BOOLEAN;
VAR
	byteCount: INTEGER;
	check : BOOLEAN;
BEGIN
	IF Trace THEN KernelLog.String("Session Setup"); KernelLog.Ln(); END;

	(* SEND *)
	byteCount := SHORT(
		Strings.Length(c.user)
		+ Strings.Length(c.pw)
		+ Strings.Length(PrimaryDomain)
		+ Strings.Length(NativeOS)
		+ Strings.Length(NativeLanMan));

	SendSMBHeader(66 + byteCount, 73X, c);
	c.out.Net8(13);			(* Word count *)
	c.out.Net8(255);		(* no andx *)
	c.out.Net8(0);			(* reserved *)
	c.out.RawInt(0);			(* andx offset *)
	c.out.RawInt(32767);	(* buffersize *)
	c.out.RawInt(2);			(* mpx *)
	c.out.RawInt(0);			(* Vc *)
	c.out.Net32(0);			(* session key *)
	c.out.RawInt(SHORT(Strings.Length(c.pw)+1));	(* ANSI len *)
	c.out.RawInt(0);	(* UNICODE len *)
	c.out.Net32(0);			(* reserved *)
	c.out.Net32(268435456);	(* capabilities *)
	c.out.Net8(byteCount + 5);
	c.out.Net8(0);
	c.out.RawString(c.pw);
	c.out.RawString(c.user);
	c.out.RawString(PrimaryDomain);
	c.out.RawString(NativeOS);
	c.out.RawString(NativeLanMan);
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(73X, c);

	IF ~check THEN
		RETURN FALSE;
	END;

	IF Trace THEN KernelLog.String(" -- UID: "); KernelLog.Int(c.uid, 0); KernelLog.Ln(); END;
	RETURN TRUE;
END SessionSetup;

PROCEDURE TreeConnect(c: Connection): BOOLEAN;
VAR
	check : BOOLEAN;
BEGIN
	IF Trace THEN KernelLog.String("Tree Connect"); KernelLog.Ln(); END;

	(* SEND *)
	SendSMBHeader(54 + SHORT(Strings.Length(c.ipaddr) + Strings.Length(c.path) + Strings.Length(c.pw)), 75X, c);
	c.out.Net8(4);			(* Word count *)
	c.out.Net8(255);		(* no andx *)
	c.out.Net8(0);			(* reserved *)
	c.out.RawInt(0);			(* andx offset *)
	c.out.RawInt(0);			(* disconnected tid *)
	c.out.RawInt(SHORT(Strings.Length(c.pw)+1));	(* pw length *)
	c.out.RawInt(SHORT(11 + Strings.Length(c.ipaddr) + Strings.Length(c.path) + Strings.Length(c.pw)));		(* bcc *)
	c.out.RawString(c.pw);
	c.out.String("\\");
	c.out.String(c.ipaddr);
	c.out.String("\");
	c.out.RawString(c.path);
	c.out.RawString("?????");
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(75X, c);

	IF ~check THEN
		RETURN FALSE;
	END;

	IF Trace THEN KernelLog.String(" -- TID : "); KernelLog.Int(c.tid, 0); KernelLog.Ln(); END;

	RETURN TRUE;
END TreeConnect;

PROCEDURE Trans2Find(c: Connection; cmd: INTEGER): BOOLEAN;
VAR
	check : BOOLEAN;
	len: INTEGER;
BEGIN
	IF Trace THEN KernelLog.String("TRANS 2 - "); END;

	IF cmd = 1 THEN			(* FIND FIRST *)
		len := SHORT(Strings.Length(c.mask));
		IF Trace THEN KernelLog.String("FIND FIRST"); KernelLog.Ln; END;
	ELSIF cmd = 2 THEN		(* FIND NEXT *)
		len := SHORT(Strings.Length(c.fnLast));
		IF Trace THEN KernelLog.String("FIND NEXT"); KernelLog.Ln; END;
	ELSE
		RETURN FALSE;
	END;

	(* SEND *)
	SendSMBHeader(81 + len, 32X, c);
	c.out.Net8(15);			(* Word count *)
	c.out.RawInt(13+len);	(* parameter count 18 *)
	c.out.RawInt(0);			(* data count *)
	c.out.RawInt(10);		(* max par count *)
	c.out.RawInt(-1);		(* max data count *)
	c.out.Net8(0);			(* max setup *)
	c.out.Net8(0);			(* reserved *)
	c.out.RawInt(0);			(* flags *)
	c.out.Net32(0);			(* timeout *)
	c.out.RawInt(0);			(* reserved *)
	c.out.RawInt(13+len);	(* parameter count 18 *)
	c.out.RawInt(68);		(* par offset *)
	c.out.RawInt(0);			(* data count *)
	c.out.RawInt(0);			(* data offset 86 *)
	c.out.Net8(1);			(* setup count *)
	c.out.Net8(0);			(* reserved *)
	c.out.RawInt(cmd);		(* subcommand *)
	c.out.RawInt(16+len);	(* byte cnt 21 *)
	c.out.Net8(0);			(* padding *)
	c.out.Net8(0);			(* padding *)
	c.out.Net8(0);			(* padding *)

	IF cmd = 1 THEN
		c.out.RawInt(22);		(* search attri *)
		c.out.RawInt(25);		(* search count 10 *)
		c.out.RawInt(6);			(* flags *)
		c.out.RawInt(260);		(* loi *)
		c.out.Net32(0);			(* storage *)
		c.out.RawString(c.mask);
	ELSIF cmd = 2 THEN
		c.out.RawInt(c.sid);		(* sid *)
		c.out.RawInt(25);		(* search count 10 *)
		c.out.RawInt(260);		(* loi *)
		c.out.Net32(0);			(* resume *)
		c.out.RawInt(6);			(* flags *)
		c.out.RawString(c.fnLast);
	ELSE
		RETURN FALSE;
	END;
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(32X, c);

	IF ~check THEN
		RETURN FALSE;
	END;

	RETURN TRUE;
END Trans2Find;

PROCEDURE OpenAndX(c: Connection; name: ARRAY OF CHAR; access: INTEGER; create: BOOLEAN): INTEGER;
VAR
	check: BOOLEAN;
	fid: INTEGER;
BEGIN
	IF Trace THEN
		KernelLog.String("Open AndX"); KernelLog.Ln();
		KernelLog.String(" -- Name: "); KernelLog.String(name); KernelLog.Ln();
		KernelLog.String(" -- Access: "); KernelLog.Int(access, 0); KernelLog.Ln();
		KernelLog.String(" -- Create: "); KernelLog.Boolean(create); KernelLog.Ln();
	END;

	ReplaceSlash(name);

	(* SEND *)
	SendSMBHeader(66 + SHORT(Strings.Length(name)), 2DX, c);
	c.out.Net8(15);			(* word count *)
	c.out.Net8(255);		(* andx*)
	c.out.Net8(0); 			(* reserved *)
	c.out.RawInt(0);			(* andx offset *)
	c.out.RawInt(0);			(* flags *)
	c.out.RawInt(access);	(* desired access *)
	c.out.RawInt(6);			(* search attributes *)
	c.out.RawInt(0);			(* file attributes *)
	c.out.Net32(0); 			(* create.time *)

	IF create THEN
		c.out.RawInt(17);
	ELSE
		c.out.RawInt(1);		(* open function *)
	END;

	c.out.Net32(0);			(* allocation size *)
	c.out.Net32(0);			(* timeout *)
	c.out.Net32(0);			(* reserved *)
	c.out.RawInt(1 + SHORT(Strings.Length(name)));	(* byte count *)
	c.out.RawString(name);
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(2DX, c);

	IF ~check THEN
		IF Trace THEN KernelLog.String(" -- ERROR on Open AndX - FID: 0"); KernelLog.Ln(); END;
		RETURN 0;
	END;

	c.in.SkipBytes(5);
	c.in.RawInt(fid);

	IF Trace THEN KernelLog.String(" -- FID: "); KernelLog.Int(fid, 0); KernelLog.Ln(); END;

	RETURN fid;
END OpenAndX;

PROCEDURE CloseFile(c: Connection; key: LONGINT);
VAR
	check: BOOLEAN;
BEGIN
	IF Trace THEN KernelLog.String("Close File"); KernelLog.Ln(); END;

	(* SEND *)
	SendSMBHeader(41, 04X, c);
	c.out.Net8(3);					(* Word count *)
	c.out.RawInt(SHORT(key));		(* fid *)
	c.out.Net32(0);					(* last write *)
	c.out.RawInt(0);					(* byte count *)
	c.out.Update();

	(* RECEIVE *)
	check := RecieveResponse(04X, c);
END CloseFile;

PROCEDURE NewFS*(context: Files.Parameters);
VAR
	fs: FileSystem;
	connection: TCP.Connection;
	c: Connection;
	check: BOOLEAN;
BEGIN
	IF Files.This(context.prefix) = NIL THEN
		NEW(c);
		context.arg.SkipWhitespace; context.arg.String(c.ipaddr);
		context.arg.SkipWhitespace; context.arg.String(c.path);
		context.arg.SkipWhitespace; context.arg.String(c.user);
		context.arg.SkipWhitespace; context.arg.String(c.pw);

		IF Trace THEN
			KernelLog.String("Connecting to "); KernelLog.String(c.ipaddr); KernelLog.Ln();
			KernelLog.String("Path: "); KernelLog.String(c.path); KernelLog.Ln();
		END;

		check := StartClient(c, connection);

		IF (~check) OR (connection = NIL) THEN
			context.error.String("CONNECTION ERROR!"); context.error.Ln;
			RETURN;
		END;

		NEW(fs);
		fs.desc := "SmbFS";
		fs.c := c;
		NEW(fs.lock);
		fs.connection := connection;
		Files.Add(fs, context.prefix);
	ELSE
		context.error.String("DiskFS: "); context.error.String(context.prefix); context.error.String(" already in use");
		context.error.Ln;
	END;
END NewFS;

PROCEDURE StartClient(VAR c: Connection; VAR connection: TCP.Connection): BOOLEAN;
VAR
	tcpsender: TCPSender;
	check: BOOLEAN;
BEGIN
	c.tid := 0;
	c.uid := 0;
	NEW(tcpsender);
	tcpsender.Connect(c.ipaddr, SMBPort, c);

	IF (c.in # NIL) & (c.out # NIL) THEN
		connection := tcpsender.connection;
		check := NegotiateProtocol(c);
		check := check & SessionSetup(c);
		check := check & TreeConnect(c);
		RETURN check;
	ELSE
		RETURN FALSE;
	END;
END StartClient;

PROCEDURE GetDateTime(t: ARRAY OF LONGINT; VAR datetime: Dates.DateTime);
VAR
	second, minute, hour, day, month, year, totalDays, NofDaysMnth: LONGINT;
	tsh: HUGEINT;
	ts: LONGINT;
	continue: BOOLEAN;
BEGIN
	tsh := t[1] * 100000000H + t[0];
	tsh := tsh DIV 10000000;
	tsh := tsh - 11644473600;
	ts := SHORT(tsh);
	second := ts MOD 60;
	minute := (ts MOD 3600) DIV 60;
	hour := (ts MOD 86400) DIV 3600;
	ts := ts - (hour * 3600) - (minute * 60) - second;
	totalDays := ts DIV 86400;
	year := 1970;
	continue := TRUE;

	WHILE (totalDays > 365) & continue DO
		IF Dates.LeapYear(year) THEN
			IF totalDays > 366 THEN
				totalDays := totalDays - 366;
			ELSE
				DEC(year);
				continue := FALSE;
			END;
		ELSE
			totalDays := totalDays - 365;
		END;
		INC(year);
	END;

	month := 1;
	continue := TRUE;

	WHILE (totalDays > 28)  & continue DO
		NofDaysMnth := Dates.NofDays(year, month);
		IF totalDays >= NofDaysMnth THEN
			INC(month);
			totalDays := totalDays - NofDaysMnth;
		ELSE
			continue := FALSE;
		END;
	END;

	day := totalDays + 1;
	datetime.year := year;
	datetime.month := month;
	datetime.day := day;
	datetime.hour := hour;
	datetime.minute := minute;
	datetime.second := second;
END GetDateTime;

END SambaClient.


SystemTools.Free SambaClient ~

FSTools.Mount SMB SmbFS 192.168.1.1 sharename userid password~

FSTools.Mount SMB2 SmbFS 127.0.0.1 SBMShared id pwd~

FSTools.Mount SMB SmbFS 192.168.1.1  ~

FSTools.Mount SMB SmbFS 192.168.1.99 test ~

FSTools.Mount SMB SmbFS 192.168.1.99 d ~


FSTools.Mount SMB SmbFS 129.132.50.25 test guest guest ~

FSTools.Mount SMB SmbFS 129.132.50.7 test ~

FSTools.Mount SMB SmbFS 192.168.1.102 test ~

FSTools.Mount SMB SmbFS 127.0.0.1 ~

FSTools.Mount SMB SmbFS 127.0.0.1 ~

FSTools.Unmount SMB ~



