MODULE SambaServer; (** AUTHOR "mancos"; PURPOSE "SMB Server"; *)

IMPORT SYSTEM, Modules, Streams, KernelLog, Commands, Dates, Strings, Files, TCP, TCPServices;

CONST
	PrimaryDomain = "BLUEBOTTLE";
	Server = "A2SAMBA";
	NativeOS = "A2";
	LANManager = "A2 LAN Manager";
	FileSystem = "AosFS";
	Trace = FALSE;
	SMBPort* = 445;


TYPE
	Share = POINTER TO RECORD
		path, unc : Files.FileName;
		next : Share;
	END;

	Connection = POINTER TO RECORD
			error: BOOLEAN;
			errorcode: LONGINT;
			out: Streams.Writer;
			in: Streams.Reader;
			msgSize: LONGINT;
			cmd: LONGINT;
			flags: LONGINT;
			flags2: INTEGER;
			tid: INTEGER;
			pid: INTEGER;
			uid: INTEGER;
			mid: INTEGER;
			fid: INTEGER;
			sid: INTEGER;
			pattern: ARRAY 256 OF CHAR;
			netbios: INTEGER;
			filename: ARRAY 256 OF CHAR;
			sharename: ARRAY 256 OF CHAR;
			client: TCP.Connection;
			next: Connection;
		END;

	Agent = OBJECT(TCPServices.Agent)
	VAR
		out: Streams.Writer;
		in: Streams.Reader;
		c: Connection;
	BEGIN {ACTIVE}
		(* Initialisation *)
		Streams.OpenReader(in, client.Receive);
		Streams.OpenWriter(out, client.Send);

		WHILE (client.state IN TCP.OpenStates) DO
			NEW(c);
			SetLastConnection(c);
			c.out := out;
			c.in := in;
			c.client := client;
			c.error := CheckSMBHeader(c);

			IF ~c.error THEN
				Dispatch(c);
			END;
		END;
	END Agent;

VAR
	service: TCPServices.Service;
	lastUID, lastTID, lastFID, lastSID: INTEGER;
	firstConn: Connection;
	shares : Share;

PROCEDURE GetUID(): INTEGER;
BEGIN {EXCLUSIVE}
	INC(lastUID);
	RETURN lastUID;
END GetUID;

PROCEDURE GetTID(): INTEGER;
BEGIN {EXCLUSIVE}
	INC(lastTID);
	RETURN lastTID;
END GetTID;

PROCEDURE GetFID(): INTEGER;
BEGIN {EXCLUSIVE}
	INC(lastFID);
	RETURN lastFID;
END GetFID;

PROCEDURE GetSID(): INTEGER;
BEGIN {EXCLUSIVE}
	INC(lastSID);
	RETURN lastSID;
END GetSID;

PROCEDURE SetLastConnection(c: Connection);
VAR
	oldConn: Connection;
BEGIN {EXCLUSIVE}
	oldConn := GetLastConnection();
	oldConn.next := c;
END SetLastConnection;

PROCEDURE GetSharename(VAR c: Connection);
VAR
	k: Connection;
BEGIN
	k := firstConn;
	WHILE (k.next # NIL) DO
		IF (k.tid = c.tid) & (Strings.Length(k.sharename) > 0) THEN
			COPY(k.sharename, c.sharename);
			RETURN;
		END;
		k := k.next;
	END;
END GetSharename;

PROCEDURE GetLastConnection(): Connection;
VAR
	c: Connection;
BEGIN
	c := firstConn;
	WHILE (c.next # NIL) DO
		c := c.next;
	END;
	RETURN c;
END GetLastConnection;

PROCEDURE GetPattern(sid: INTEGER; VAR pattern: ARRAY OF CHAR);
VAR
	c: Connection;
BEGIN
	c := firstConn;
	WHILE (c.sid # sid) DO
		c := c.next;
	END;
	COPY(c.pattern, pattern);
END GetPattern;

PROCEDURE RemoveConnections(tid: INTEGER);
VAR
	c, prev: Connection;
BEGIN {EXCLUSIVE}
	c := firstConn;
	WHILE (c.next # NIL) DO
		IF c.tid = tid THEN
			prev.next := c.next
		END;
		prev := c;
		c := prev.next;
	END;
END RemoveConnections;

PROCEDURE GetFileName(fid: INTEGER; VAR filename: ARRAY OF CHAR);
VAR
	c: Connection;
BEGIN
	c := firstConn;
	WHILE ((c.fid # fid) & (c.next # NIL)) DO
		c := c.next;
	END;

	IF (c.fid = fid) THEN
		COPY(c.filename, filename);
	ELSE
		IF Trace THEN KernelLog.String(" -- FID not found!"); KernelLog.Ln(); END;
		c.error := TRUE;
		c.errorcode := 393217;
		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END GetFileName;

PROCEDURE Dispatch(c: Connection);
BEGIN
	IF c.cmd = ORD(72X) THEN
		HandleNegotiate(c);
	ELSIF c.cmd = ORD(73X) THEN
		HandleSessionSetup(c);
	ELSIF c.cmd = ORD(75X) THEN
		HandleTreeConnect(c);
	ELSIF c.cmd = ORD(2DX) THEN
		HandleOpen(c);
	ELSIF c.cmd = ORD(04X) THEN
		HandleClose(c);
	ELSIF c.cmd = ORD(32X) THEN
		HandleTrans2(c);
	ELSIF c.cmd = ORD(71X) THEN
		HandleTreeDisconnect(c);
	ELSIF c.cmd = ORD(02X) THEN
		HandleOpenOld(c);
	ELSIF c.cmd = ORD(08X) THEN
		HandleQueryInformation(c);
	ELSIF c.cmd = ORD(23X) THEN
		HandleQueryInfo2(c);
	ELSIF c.cmd = ORD(2EX) THEN
		HandleRead(c);
	ELSIF c.cmd = ORD(0BX) THEN
		HandleWrite(c);
	ELSIF c.cmd = ORD(2FX) THEN
		HandleWriteAndX(c);
	ELSIF c.cmd = ORD(0A0X) THEN
		HandleTrans(c);
	ELSIF c.cmd = ORD(25X) THEN
		HandleLMTrans(c);
	ELSIF c.cmd = ORD(05X) THEN
		HandleFlush(c);
	ELSIF c.cmd = ORD(07X) THEN
		HandleRename(c);
	ELSIF c.cmd = ORD(06X) THEN
		HandleDelete(c);
	ELSIF c.cmd = ORD(09X) THEN
		HandleSetInfo2(c);
	ELSIF c.cmd = ORD(22X) THEN
		HandleSetInfo2(c);
	ELSIF c.cmd = ORD(34X) THEN
		HandleFindClose2(c);
	ELSIF c.cmd = ORD(2BX) THEN
		HandleEcho(c);
	ELSIF c.cmd = ORD(00X) THEN
		HandleCreateDir(c);
	ELSIF c.cmd = ORD(01X) THEN
		HandleDeleteDir(c);
	ELSIF c.cmd = ORD(0FX) THEN
		HandleCreateNew(c);
	ELSE
		IF Trace THEN KernelLog.String(" -- Unknown packet: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;
		c.in.SkipBytes(1);
		c.in.Reset();
	END;
END Dispatch;

PROCEDURE HandleCreateNew(c: Connection);
VAR
	filename: ARRAY 256 OF CHAR;
	f: Files.File;
	res: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Create New: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.in.SkipBytes(1);	(* skip wordCount *)
	c.in.SkipBytes(2);	(* skip file attr *)
	c.in.SkipBytes(4);	(* skip created *)
	c.in.SkipBytes(2);	(* skip byte count *)
	c.in.SkipBytes(1);	(* skip format *)
	c.in.RawString(filename);
	ReplaceSlash(filename);
	GetSharename(c);
	Strings.Concat(c.sharename, filename, filename);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(filename); KernelLog.Ln(); END;

	f := Files.Old(filename);

	IF (f # NIL) THEN
		Files.Delete(filename, res);
	END;

	f := Files.New(filename);
	Files.Register(f);

	IF res # 0 THEN	(* NOT OK *)
		c.error := TRUE;
		c.errorcode := 327681;
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
		RETURN;
	END;

	(* SEND *)
	c.netbios := 32 + 5;
	WriteSMBHeader(c);
	c.out.Net8(1);			(* word count *)
	c.fid := GetFID();
	c.out.RawInt(c.fid);
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleCreateNew;

PROCEDURE HandleCreateDir(c: Connection);
VAR
	dirname: ARRAY 256 OF CHAR;
	res: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Create Directory: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.in.SkipBytes(1);	(* skip wordCount *)
	c.in.SkipBytes(2);	(* skip byte count *)
	c.in.SkipBytes(1);	(* skip buffer format *)
	c.in.RawString(dirname);

	IF Trace THEN KernelLog.String(" -- Directory: "); KernelLog.String(dirname); KernelLog.Ln(); END;

	Files.CreateDirectory(dirname, res);

	IF res # 0 THEN
		c.error := TRUE;
	END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleCreateDir;

PROCEDURE HandleDeleteDir(c: Connection);
VAR
	dirname: ARRAY 256 OF CHAR;
	res: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Delete Directory: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.in.SkipBytes(1);	(* skip wordCount *)
	c.in.SkipBytes(2);	(* skip byte count *)
	c.in.SkipBytes(1);	(* skip buffer format *)
	c.in.RawString(dirname);

	IF Trace THEN KernelLog.String(" -- Directory: "); KernelLog.String(dirname); KernelLog.Ln(); END;

	Files.RemoveDirectory(dirname, TRUE, res);

	IF res # 0 THEN	(* NOT OK *)
		c.error := TRUE;
		c.errorcode := 327681;
	END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleDeleteDir;

PROCEDURE HandleEcho(c: Connection);
VAR
	i, len: LONGINT;
	byteCount, echoCount: INTEGER;
	buffer: ARRAY 32 OF CHAR;
BEGIN
	IF Trace THEN KernelLog.String("Handle Echo: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.in.SkipBytes(1);	(* skip wordCount *)
	c.in.RawInt(echoCount);
	c.in.RawInt(byteCount);
	c.in.Bytes(buffer, 0, byteCount, len);

	FOR i := 1 TO echoCount DO
		(* SEND *)
		c.netbios := 32 + 5 + SHORT(len);
		WriteSMBHeader(c);
		c.out.Net8(1);	(* word count *)
		c.out.RawInt(SHORT(i));
		c.out.RawInt(SHORT(len));	(* bytecount *)
		c.out.Bytes(buffer, 0, len);
		c.out.Update();
	END;
END HandleEcho;

PROCEDURE HandleLMTrans(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle LANMAN Trans: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.error := TRUE;
	c.errorcode := 140312577;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleLMTrans;

PROCEDURE HandleTrans(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle Trans: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	c.error := TRUE;
	c.errorcode := 65537;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleTrans;

PROCEDURE HandleRead(c: Connection);
VAR
	fidToRead, maxCount: INTEGER;
	offset, len: LONGINT;
	f: Files.File;
	r: Files.Reader;
	buffer: ARRAY 65536 OF CHAR;
	filename: ARRAY 256 OF CHAR;
BEGIN
	IF Trace THEN KernelLog.String("Handle Read File: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(5);
	c.in.RawInt(fidToRead);
	GetFileName(fidToRead, filename);
	ReplaceSlash(filename);

	IF Trace THEN KernelLog.String(" -- File to read: "); KernelLog.String(filename); KernelLog.Ln(); END;

	c.in.RawLInt(offset);
	c.in.RawInt(maxCount);
	f := Files.Old(filename);

	IF (f # NIL) THEN
		Files.OpenReader(r, f, offset);
		r.Bytes(buffer, 0, maxCount, len);
		c.netbios := 32 + 27 + SHORT(len);
		WriteSMBHeader(c);
		c.out.Net8(12);			(* word count *)
		c.out.Net8(255);		(* andx *)
		c.out.Net8(0);			(* reserved *)
		c.out.Net16(0);			(* andx offset *)
		c.out.RawInt(-1);		(* remaining: reserved, must be -1 *)
		c.out.RawInt(0); 		(* dataCompactionMode *)
		c.out.RawInt(0); 		(* reserved *)
		c.out.RawInt(SHORT(len));	(* low order length bytes *)
		c.out.RawInt(59);
		c.out.RawLInt(0);		(* no write-large-capability -> datalengthhigh is 0 *)
		c.out.RawInt(0);
		c.out.RawLInt(0); 		(* 6 bytes reserved *)
		c.out.RawInt(SHORT(len)); 	(* ByteCount *)

		(* write data *)
		c.out.Bytes(buffer, 0, len);
		c.out.Update();
	ELSE (* FID invalid *)
		IF Trace THEN KernelLog.String(" -- FID invalid!"); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 393217;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleRead;

PROCEDURE HandleWrite(c: Connection);
VAR
	fidToWrite, count : INTEGER;
	offset, len, res: LONGINT;
	buffer: ARRAY 65536 OF CHAR;
	filename: ARRAY 256 OF CHAR;
	f: Files.File;
	w: Files.Writer;
BEGIN
	IF Trace THEN KernelLog.String("Handle Write File: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(1);
	c.in.RawInt(fidToWrite);
	GetFileName(fidToWrite, filename);
	ReplaceSlash(filename);

	IF Trace THEN KernelLog.String(" -- File to write: "); KernelLog.String(filename); KernelLog.Ln(); END;

	c.in.RawInt(count);
	c.in.RawLInt(offset);
	c.in.SkipBytes(7);

	IF count = 0 THEN
		IF Trace THEN KernelLog.String(" -- Count was zero. "); KernelLog.Ln(); END;
		IF offset # 0 THEN
			Files.Delete(filename, res);
			f := Files.New(filename);
			Files.Register(f);
		END;
		c.netbios := 32 + 5;
		WriteSMBHeader(c);
		c.out.Net8(1);			(* word count *)
		c.out.RawInt(0);			(* count *)
		c.out.Net16(0);			(* byte count *)
		c.out.Update();
		RETURN;
	END;

	f := Files.Old(filename);

	IF (f # NIL) THEN
		c.in.Bytes(buffer, 0, count, len);
		Files.OpenWriter(w, f, offset);
		w.Bytes(buffer, 0, len);
		w.Update();

		(* SEND *)
		c.netbios := 32 + 5;
		WriteSMBHeader(c);
		c.out.Net8(1);			(* word count *)
		c.out.RawInt(count);	(* count *)
		c.out.Net16(0);			(* byte count *)
		c.out.Update();
	ELSE (* FID invalid *)
		IF Trace THEN KernelLog.String(" -- FID invalid!"); KernelLog.Ln(); END;
		c.error := TRUE;
		c.errorcode := 393217;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleWrite;

PROCEDURE HandleWriteAndX(c: Connection);
VAR
	fidToWrite, byteCount, dataOffset: INTEGER;
	offset, len: LONGINT;
	f: Files.File;
	w: Files.Writer;
	buffer: ARRAY 65536 OF CHAR;
	filename: ARRAY 256 OF CHAR;
BEGIN
	IF Trace THEN KernelLog.String("Handle Write File AndX: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(5);
	c.in.RawInt(fidToWrite);
	GetFileName(fidToWrite, filename);
	ReplaceSlash(filename);

	IF Trace THEN KernelLog.String(" -- File to write: "); KernelLog.String(filename); KernelLog.Ln(); END;

	c.in.RawLInt(offset);
	c.in.SkipBytes(12);
	c.in.RawInt(dataOffset);
	c.in.RawInt(byteCount);

	IF (dataOffset = 0) OR (byteCount = 0) THEN
		f := NIL;
		len := 0;
	ELSE
		c.in.SkipBytes(dataOffset - 59);
		f := Files.Old(filename);
	END;

	IF (f # NIL) THEN
		Files.OpenWriter(w, f, offset);
		c.in.Bytes(buffer, 0, byteCount, len);
		w.Bytes(buffer, 0, len);
		w.Update();

		(* SEND *)
		c.netbios := 32 + 15;
		WriteSMBHeader(c);
		c.out.Net8(6);			(* word count *)
		c.out.Net8(255);		(* andx *)
		c.out.Net8(0);			(* reserved *)
		c.out.Net16(0);			(* andx offset *)
		c.out.RawInt(SHORT(len));	(* len written *)
		c.out.RawInt(-1);		(* remaining *)
		c.out.RawInt(0);			(* count high *)
		c.out.RawInt(0);			(* reserved *)
		c.out.RawInt(0);			(* byte count *)
		c.out.Update();
	ELSE (* FID invalid *)
		IF Trace THEN KernelLog.String(" -- FID invalid!"); KernelLog.Ln(); END;
		c.error := TRUE;
		c.errorcode := 393217;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleWriteAndX;

PROCEDURE HandleQueryInformation(c: Connection);
VAR
	filename: ARRAY 256 OF CHAR;
	i: INTEGER;
	f: Files.File;
	t,d: LONGINT;
	dTime: Dates.DateTime;
BEGIN
	IF Trace THEN KernelLog.String("Handle Query Information: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(4);
	c.in.RawString(filename);
	ReplaceSlash(filename);
	GetSharename(c);
	Strings.Concat(c.sharename, filename, filename);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(filename); KernelLog.Ln(); END;

	f := Files.Old(filename);

	IF (f # NIL) OR (filename = c.sharename) THEN

		(* SEND *)
		c.netbios := 32 + 23;
		WriteSMBHeader(c);
		c.out.Net8(10);			(* word count *)
		IF (filename = c.sharename) OR (Files.Directory IN f.flags)  THEN (* is Directory *)
			c.out.RawInt(10H);
		ELSE
			c.out.RawInt(0H);
		END;

		IF (f # NIL) THEN
			f.GetDate(t,d);
			dTime := Dates.OberonToDateTime(d,t);
			GetUnixTimeStamp(dTime, t);
			c.out.RawLInt(t);		(* last write *)
			c.out.RawLInt(f.Length());		(* file size *)
		ELSE
			c.out.RawLInt(0);		(* last write *)
			c.out.RawLInt(0);		(* file size *)
		END;

		FOR i := 1 TO 5 DO
			c.out.RawInt(0);
		END;

		c.out.RawInt(0);
		c.out.Update();
	ELSE
		IF Trace THEN KernelLog.String(" -- File not found!"); KernelLog.Ln(); END;
		c.error := TRUE;
		c.errorcode := 131073;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;

END HandleQueryInformation;

PROCEDURE HandleOpenOld(c: Connection);
VAR
	filename: ARRAY 256 OF CHAR;
	f: Files.File;
	d,t : LONGINT;
	dTime: Dates.DateTime;
BEGIN
	IF Trace THEN KernelLog.String("Handle Open (old) File: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(8);
	c.in.RawString(filename);
	ReplaceSlash(filename);
	GetSharename(c);
	Strings.Concat(c.sharename, filename, filename);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(filename); KernelLog.Ln(); END;

	f := Files.Old(filename);

	IF (f # NIL) THEN
		COPY(filename, c.filename);

		(* SEND *)
		c.netbios := 32 + 17;
		WriteSMBHeader(c);
		c.out.Net8(7);			(* word count *)
		c.fid := GetFID();
		c.out.RawInt(c.fid);		(* FID *)

		IF (Files.Directory IN f.flags) THEN
			c.out.RawInt(10H);
		ELSE
			c.out.RawInt(0H);
		END;

		f.GetDate(t,d);
		dTime := Dates.OberonToDateTime(d,t);
		GetUnixTimeStamp(dTime, t);
		c.out.RawLInt(t);		(* last write *)
		c.out.RawLInt(f.Length());			(* datasize *)
		c.out.RawInt(0);			(* granted access *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	ELSE
		IF Trace THEN KernelLog.String(" -- File not found!"); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 131073;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleOpenOld;

PROCEDURE HandleNegotiate(VAR c: Connection);
VAR
	variable: LONGINT;
	name: ARRAY 64 OF CHAR;
	support: BOOLEAN;
	size: LONGINT;
	dialectIndex: INTEGER;
	t: ARRAY 2 OF LONGINT;
BEGIN
	support := FALSE;
	size := c.msgSize;
	dialectIndex := 0;

	IF Trace THEN KernelLog.String("Handle Negotiation: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(3);

	WHILE (size - 35 > 0) &( ~support) DO
		variable := c.in.Net8();
		c.in.RawString(name);

		IF (variable = 2) & (name = "NT LM 0.12") THEN
			support := TRUE;
			IF Trace THEN
				KernelLog.String(" -- NTLM 0.12 OK");
				KernelLog.Ln();
			END;
		ELSE
			INC(dialectIndex);
		END;

		size := size - 2 - Strings.Length(name);
	END;

	IF ~support THEN
		c.error := TRUE;
	END;

	(* SEND *)
	c.netbios := 32 + 37 + 10 + SHORT(Strings.Length(PrimaryDomain) + Strings.Length(Server));
	WriteSMBHeader(c);
	c.out.Net8(17);			(* word count *)
	c.out.RawInt(dialectIndex);
	c.out.Net8(1);			(* security mode *)
	c.out.RawInt(1);			(* max mpx count *)
	c.out.RawInt(1);			(* max vc *)
	c.out.RawLInt(32767);	(* max buffer size *)
	c.out.RawLInt(32767);	(* max raw buffer *)
	c.out.RawLInt(0);		(* sessionkey *)
	c.out.RawLInt(0);		(* capabilities *)
	GetSMBTimeStamp(Dates.Now(), t);
	c.out.RawLInt(t[0]);		(* system time *)
	c.out.RawLInt(t[1]);		(* system time*)
	c.out.Char(CHR(0));		(* time zone *)
	c.out.Char(CHR(0));		(* time zone *)
	c.out.Net8(8);			(* key length *)
	c.out.RawInt(SHORT(Strings.Length(PrimaryDomain) + Strings.Length(Server)));
	c.out.String("serverpw");
	c.out.RawString(PrimaryDomain);
	c.out.RawString(Server);
	c.out.Update();
END HandleNegotiate;

PROCEDURE HandleSessionSetup(c: Connection);
VAR
	ansiPwLen: INTEGER;
	ansiPass: ARRAY 256 OF CHAR;
	ucPwLen: INTEGER;
	uniPass: ARRAY 256 OF CHAR;
	username: ARRAY 256 OF CHAR;
	i: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Session setup: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(15);
	c.in.RawInt(ansiPwLen);
	c.in.RawInt(ucPwLen);
	c.in.SkipBytes(10);

	IF ansiPwLen > 0 THEN
		c.in.Bytes(ansiPass, 0, ansiPwLen, i);
	END;

	IF ucPwLen > 0 THEN
		c.in.Bytes(uniPass, 0, ucPwLen, i);
	END;

	c.in.RawString(username);

	IF Trace THEN KernelLog.String(" -- Username: "); KernelLog.String(username); KernelLog.Ln(); END;

	(* NO USERNAME *)
	IF username = "" THEN
		c.error := TRUE;
		c.errorcode := 262146;
		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
		RETURN;
	END;

	(* SEND *)
	c.netbios := 32 + 12 + SHORT(Strings.Length(NativeOS) + Strings.Length(PrimaryDomain) + Strings.Length(LANManager));
	WriteSMBHeader(c);
	c.out.Net8(3);			(* word count *)
	c.out.Char(CHR(255));	(* and x *)
	c.out.Net8(0);			(* reserved *)
	c.out.Net16(0);			(* andx offset *)
	c.out.RawInt(1);			(* logged in as guest *)
	c.out.RawInt(3 + SHORT(Strings.Length(NativeOS) + Strings.Length(PrimaryDomain) + Strings.Length(LANManager)));	(* max vc *)
	c.out.RawString(NativeOS);
	c.out.RawString(LANManager);
	c.out.RawString(PrimaryDomain);
	c.out.Update();
END HandleSessionSetup;

PROCEDURE HandleTreeConnect(c: Connection);
VAR
	i,offset: LONGINT;
	pwLen: INTEGER;
	byteCount: INTEGER;
	password: ARRAY 256 OF CHAR;
	path: ARRAY 256 OF CHAR;
	service: ARRAY 256 OF CHAR;
	string : Strings.String;
	share : Share;
BEGIN
	IF Trace THEN KernelLog.String("Handle Tree Connect: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(7);
	c.in.RawInt(pwLen);
	c.in.RawInt(byteCount);

	IF pwLen > 0 THEN
		c.in.Bytes(password, 0, pwLen, i);
	END;

	c.in.RawString(path);
	c.in.RawString(service);

	IF Trace THEN
		KernelLog.String(" -- Service: "); KernelLog.String(service); KernelLog.Ln();
		KernelLog.String(" -- Path: "); KernelLog.String(path);
	END;

	IF Strings.EndsWith("IPC$", path) THEN
		IF Trace THEN KernelLog.String(" -- IPC"); KernelLog.Ln; END;
		service := "IPC";
	ELSE
		IF Trace THEN KernelLog.String(" - FILESYSTEM"); KernelLog.Ln; END;
		service := "A:";
	END;

	offset := Strings.Find(path, 3, CHR(5CH));
	string := Strings.Substring2(offset, path);
	IF (string # NIL) THEN COPY(string^, path); END;

	share := FindShare(path);

	IF (share # NIL) THEN
		COPY(share.path, c.sharename);
		KernelLog.String(" -- Sharename: "); KernelLog.String(c.sharename); KernelLog.Ln();
	ELSIF (service = "IPC") THEN
		KernelLog.String(" -- IPC Connected"); KernelLog.Ln();
	ELSE
		KernelLog.String(" NO SHARE FOUND"); KernelLog.Ln();

		c.error := TRUE;
		c.errorcode := 4390913;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;

	(* SEND *)
	c.netbios := 32 + 19 + SHORT(Strings.Length(FileSystem) + Strings.Length(service));
	WriteSMBHeader(c);
	c.out.Net8(7);				(* word count *)
	c.out.Char(CHR(255));		(* and x *)
	c.out.Net8(0);				(* reserved *)
	c.out.Net16(0);				(* andx offset *)
	c.out.RawInt(0);				(* optional support *)
	c.out.RawLInt(268435456); 	(* rights *)
	c.out.RawLInt(268435456); 	(* rights *)
	c.out.RawInt(2 + SHORT(Strings.Length(FileSystem) + Strings.Length(service)));
	c.out.RawString(service);
	c.out.RawString(FileSystem);
	c.out.Update();
END HandleTreeConnect;

PROCEDURE HandleTreeDisconnect(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle Tree Disonnect: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();

	c.client.Discard();
	RemoveConnections(c.tid);
END HandleTreeDisconnect;

PROCEDURE HandleOpen(c: Connection);
VAR
	byteCount, openFunc: INTEGER;
	filename: ARRAY 256 OF CHAR;
	f: Files.File;
	t,d: LONGINT;
	dTime: Dates.DateTime;
BEGIN
	IF Trace THEN KernelLog.String("Handle Open: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(17);
	c.in.RawInt(openFunc);
	c.in.SkipBytes(12);
	c.in.RawInt(byteCount);
	c.in.RawString(filename);

	ReplaceSlash(filename);
	GetSharename(c);
	Strings.Concat(c.sharename, filename, filename);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(filename); KernelLog.Ln(); END;

	f := Files.Old(filename);

	IF ((f # NIL) OR (filename = c.sharename)) & (0 IN SYSTEM.VAL(SET, openFunc)) THEN
		IF Trace THEN KernelLog.String(" -- opening file..."); KernelLog.Ln(); END;

		COPY(filename, c.filename);

		(* SEND *)
		c.netbios := 32 + 33;
		WriteSMBHeader(c);
		c.out.Net8(15);			(* word count *)
		c.out.Char(CHR(255));	(* and x *)
		c.out.Net8(0);			(* reserved *)
		c.out.Net16(0);			(* andx offset *)
		c.fid := GetFID();
		c.out.RawInt(c.fid);		(* FID *)

		IF ((f # NIL) & (Files.Directory IN f.flags)) OR (filename = c.sharename) THEN (* is Directory *)
			c.out.RawInt(10H);
		ELSE
			c.out.RawInt(0H);
		END;

		IF (f # NIL) THEN
			f.GetDate(t,d);
			dTime := Dates.OberonToDateTime(d,t);
			GetUnixTimeStamp(dTime, t);
			c.out.RawLInt(t);		(* last write *)
			c.out.RawLInt(f.Length());		(* file size *)
		ELSE
			c.out.RawLInt(0);		(* last write *)
			c.out.RawLInt(0);		(* file size *)
		END;

		c.out.RawInt(0);			(* granted access *)
		c.out.RawInt(0);			(* filetype *)
		c.out.RawInt(0);			(* ipc state *)
		c.out.RawInt(1);			(* action *)
		c.out.RawLInt(0);		(* serverfid*)
		c.out.RawInt(0);			(* reserved *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	ELSIF (f = NIL) & (4 IN SYSTEM.VAL(SET, openFunc)) THEN
		IF Trace THEN KernelLog.String(" -- creating file..."); KernelLog.Ln(); END;

		f := Files.New(filename);
		COPY(filename, c.filename);
		Files.Register(f);

		(* SEND *)
		c.netbios := 32 + 33;
		WriteSMBHeader(c);
		c.out.Net8(15);			(* word count *)
		c.out.Char(CHR(255));	(* and x *)
		c.out.Net8(0);			(* reserved *)
		c.out.Net16(0);			(* andx offset *)
		c.fid := GetFID();
		c.out.RawInt(c.fid);		(* FID *)
		c.out.RawInt(0H);
		GetUnixTimeStamp(Dates.Now(), t);
		c.out.RawLInt(t);		(* last write *)
		c.out.RawLInt(f.Length());		 (* filesize *)
		c.out.RawInt(0);			(* granted access *)
		c.out.RawInt(0);			(* filetype *)
		c.out.RawInt(0);			(* ipc state *)
		c.out.RawInt(2);			(* action *)
		c.out.RawLInt(0);		(* serverfid*)
		c.out.RawInt(0);			(* reserved *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	ELSIF (f # NIL) & ~(0 IN SYSTEM.VAL(SET, openFunc)) THEN
		IF Trace THEN KernelLog.String(" -- Invalid open mode!."); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 786433;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	ELSIF Strings.StartsWith("/PIPE/", 0, filename) THEN
		IF Trace THEN KernelLog.String(" -- opening pipe..."); KernelLog.Ln(); END;

		COPY(filename, c.filename);

		(* SEND *)
		c.netbios := 32 + 33;
		WriteSMBHeader(c);
		c.out.Net8(15);			(* word count *)
		c.out.Char(CHR(255));	(* and x *)
		c.out.Net8(0);			(* reserved *)
		c.out.Net16(0);			(* andx offset *)
		c.fid := GetFID();
		c.out.RawInt(c.fid);		(* FID *)
		c.out.RawInt(0H);
		c.out.RawLInt(0);		(* lastwrite *)
		c.out.RawLInt(0);		(* filesize *)
		c.out.RawInt(0);			(* granted access *)
		c.out.RawInt(0);			(* filetype *)
		c.out.RawInt(0);			(* ipc state *)
		c.out.RawInt(1);			(* action *)
		c.out.RawLInt(0);		(* serverfid*)
		c.out.RawInt(0);			(* reserved *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	ELSE
		IF Trace THEN KernelLog.String(" -- File not found!"); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 131073;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleOpen;

PROCEDURE HandleClose(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle File close: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleClose;

PROCEDURE HandleFindClose2(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle find close 2: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleFindClose2;

PROCEDURE HandleFlush(c : Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle Flush: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleFlush;

PROCEDURE HandleRename(c : Connection);
VAR
	oldName, newName,
	oldPath, newPath: ARRAY 256 OF CHAR;
	res: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Rename: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(6);
	c.in.RawString(oldName);
	ReplaceSlash(oldName);
	Files.SplitPath(oldName, oldPath, oldName);
	c.in.SkipBytes(1);
	c.in.RawString(newName);
	ReplaceSlash(newName);
	Files.SplitPath(newName, newPath, newName);

	IF Trace THEN
		KernelLog.String(" -- Old: "); KernelLog.String(oldName); KernelLog.Ln();
		KernelLog.String(" -- New: "); KernelLog.String(newName); KernelLog.Ln();
	END;

	IF oldPath = newPath THEN
		Files.Rename(oldName, newName, res);
	END;

	IF res # 0 THEN
		c.error := TRUE;
		c.errorcode := 327681;
	END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleRename;

PROCEDURE HandleDelete(c: Connection);
VAR
	name, path: ARRAY 256 OF CHAR;
	res: LONGINT;
BEGIN
	IF Trace THEN KernelLog.String("Handle Delete: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(6);
	c.in.RawString(name);
	ReplaceSlash(name);
	Files.SplitPath(name, path, name);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(name); KernelLog.Ln(); END;

	Files.Delete(name, res);

	IF res # 0 THEN
		c.error := TRUE;
		c.errorcode := 327681;
	END;

	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleDelete;

PROCEDURE HandleQueryInfo2(c: Connection);
VAR
	filename: ARRAY 256 OF CHAR;
	fid: INTEGER;
	f: Files.File;
	t,d: LONGINT;
	dTime: Dates.DateTime;
BEGIN
	IF Trace THEN KernelLog.String("Handle Query Information 2: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(1);
	c.in.RawInt(fid);
	GetFileName(fid, filename);
	ReplaceSlash(filename);

	IF Trace THEN KernelLog.String(" -- Filename: "); KernelLog.String(filename); KernelLog.Ln(); END;

	f := Files.Old(filename);

	IF (f # NIL) THEN
		(* SEND *)
		c.netbios := 32 + 25;
		WriteSMBHeader(c);
		c.out.Net8(11);			(* word count *)
		c.out.RawLInt(0);		(* creation time *)
		c.out.RawLInt(0);		(* last access *)
		f.GetDate(t,d);
		dTime := Dates.OberonToDateTime(d,t);
		GetDOSTimeStamp(dTime, t);
		c.out.RawLInt(t);		(* last write *)
		c.out.RawLInt(f.Length());		(* file data size *)
		c.out.RawLInt(f.Length());		(* file alloc *)
		c.out.RawInt(0);		(* attr *)
		c.out.RawInt(0);		(* byte count *)
		c.out.Update();
	ELSE
		IF Trace THEN KernelLog.String(" -- File not found!"); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 131073;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
	END;
END HandleQueryInfo2;

PROCEDURE HandleSetInfo2(c: Connection);
BEGIN
	IF Trace THEN KernelLog.String("Handle Set Information 2: "); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;
	(* SEND *)
	c.netbios := 32 + 3;
	WriteSMBHeader(c);
	c.out.Net8(0);			(* word count *)
	c.out.RawInt(0);			(* bytecount *)
	c.out.Update();
END HandleSetInfo2;

PROCEDURE HandleTrans2(c: Connection);
VAR
	offset: INTEGER;
	subcommand: INTEGER;
BEGIN
	IF Trace THEN KernelLog.String("Handle Trans2 Request..."); KernelLog.Int(c.cmd, 0); KernelLog.Ln(); END;

	(* RECEIVE *)
	c.in.SkipBytes(21);
	c.in.RawInt(offset);
	offset := offset - 63;
	c.in.SkipBytes(6);
	c.in.RawInt(subcommand);
	c.in.SkipBytes(offset);

	IF Trace THEN KernelLog.String(" -- Subcommand: "); KernelLog.Int(subcommand, 0); KernelLog.Ln(); END;

	Trans2Logic(subcommand, c);
END HandleTrans2;

PROCEDURE Trans2Logic(subcmd: INTEGER; c: Connection);
VAR
	enum: Files.Enumerator;
	eName, fullName, pathname, prefix, pattern, resumeFn, modPat: ARRAY 256 OF CHAR;
	eFlags, flags : SET;
	eTime, eDate, eSize : LONGINT;
	success, eos: BOOLEAN;
	i,j,z, searchCount, totalFileNameLen, lastlen, loi, sidnext: INTEGER;
	f: Files.File;
	tarray: ARRAY 2 OF LONGINT;
	t,d: LONGINT;
	dTime: Dates.DateTime;
BEGIN
	IF (subcmd = 7)  THEN
		IF Trace THEN KernelLog.String(" -- QUERY FILE INFO"); KernelLog.Ln(); END;

		c.error := TRUE;
		c.errorcode := 327681;

		(* SEND *)
		c.netbios := 32 + 3;
		WriteSMBHeader(c);
		c.out.Net8(0);			(* word count *)
		c.out.RawInt(0);			(* bytecount *)
		c.out.Update();
		RETURN;
	ELSIF (subcmd = 3)  THEN
		IF Trace THEN KernelLog.String(" -- QUERY FS INFO"); KernelLog.Ln(); END;

		(* SEND *)
		c.netbios := 32 + 25 + 10 + SHORT(Strings.Length(FileSystem) + 1);
		WriteSMBHeader(c);
		c.out.Net8(10);
		c.out.RawInt(0);
		c.out.RawInt(12 + SHORT(Strings.Length(FileSystem) + 1));
		c.out.Net16(0);
		c.out.RawInt(0);
		c.out.RawInt(55);
		c.out.RawInt(0);
		c.out.RawInt(12 + SHORT(Strings.Length(FileSystem) + 1));
		c.out.RawInt(55);
		c.out.RawInt(0);
		c.out.Net8(0);
		c.out.Net8(0);
		c.out.RawInt(12 + SHORT(Strings.Length(FileSystem) + 1));
		c.out.RawLInt(32);
		c.out.RawLInt(64);
		c.out.RawLInt(Strings.Length(FileSystem) + 1);
		c.out.RawString(FileSystem);
		c.out.Update();
	ELSIF (subcmd = 5)  THEN
		IF Trace THEN KernelLog.String(" -- QUERY PATH INFO"); KernelLog.Ln(); END;

		c.in.SkipBytes(6);
		c.in.RawString(eName);

		IF Trace THEN KernelLog.String(" -- Path name:  "); KernelLog.String(eName); KernelLog.Ln(); END;

		f := Files.Old(eName);

		IF ((f = NIL) & (eName[0] # 0X)) THEN

			(* NOT FOUND *)
			c.error := TRUE;
			c.errorcode := 131073;

			(* SEND *)
			c.netbios := 32 + 3;
			WriteSMBHeader(c);
			c.out.Net8(0);			(* word count *)
			c.out.RawInt(0);			(* bytecount *)
			c.out.Update();
			RETURN;
		END;

		(* SEND *)
		c.netbios := SHORT(32 + 89 + Strings.Length(eName));
		WriteSMBHeader(c);
		c.out.Net8(10);			(* Word count *)
		c.out.RawInt(2);			(* total para count *)
		c.out.RawInt(82);		(* total data count *)
		c.out.Net16(0);			(* reserved *)
		c.out.RawInt(2);			(* parameter count *)
		c.out.RawInt(55);		(* para offset *)
		c.out.RawInt(0);			(* para displacement *)
		c.out.RawInt(82);		(* data count *)
		c.out.RawInt(57);		(* data offset *)
		c.out.RawInt(0);			(* data displacement *)
		c.out.Net8(0);			(* setup count *)
		c.out.Net8(0);			(* reserved *)
		c.out.RawInt(84);		(* byte count *)

		(* query path info params *)
		c.out.RawInt(0);			(* ea error offset *)

		(* query path info data*)
		c.out.RawLInt(0);		(* created *)
		c.out.RawLInt(0);		(* created *)
		c.out.RawLInt(0);		(* last access *)
		c.out.RawLInt(0);		(* last access *)
		c.out.RawLInt(0);		(* last write *)
		c.out.RawLInt(0);		(* last write *)
		c.out.RawLInt(0);		(* change *)
		c.out.RawLInt(0);		(* change *)

		IF eName[0] = 0X THEN
			c.out.RawInt(16);	(* attr *)
		ELSE
			c.out.RawInt(0);		(* attr *)
		END;

		c.out.RawLInt(0);		(* alloc *)
		c.out.RawLInt(0);		(* alloc *)
		c.out.RawLInt(0);		(* eof *)
		c.out.RawLInt(0);		(* eof *)
		c.out.RawLInt(1);		(* link count *)
		c.out.Net8(0);			(* delete pending *)

		IF eName[0] = 0X THEN
			c.out.Net8(1);		(* is dir *)
		ELSE
			c.out.Net8(0);		(* is dir *)
		END;

		c.out.RawLInt(0);		(* ea list *)
		c.out.RawLInt(Strings.Length(eName));		(* filename len*)
		c.out.RawString(eName);		(* file name*)
		c.out.Update();
	ELSIF (subcmd = 1) THEN
		IF Trace THEN KernelLog.String(" -- FIND FIRST 2"); KernelLog.Ln(); END;

		c.in.SkipBytes(2);
		c.in.RawInt(searchCount);
		c.in.SkipBytes(2);
		c.in.RawInt(loi);
		c.in.SkipBytes(4);
		c.in.RawString(pattern);

		IF Trace THEN KernelLog.String(" -- Search Count: "); KernelLog.Int(searchCount, 0); KernelLog.Ln(); END;

		RemoveSlash(pattern);
		ReplaceSlash(pattern);
		RemoveQuotes(pattern);
		GetSharename(c);

		IF Trace THEN
			KernelLog.String(" -- Pattern: "); KernelLog.String(pattern); KernelLog.Ln();
			KernelLog.String(" -- Level of Interest: "); KernelLog.Int(loi, 0); KernelLog.Ln();
			KernelLog.String(" -- Sharename: "); KernelLog.String(c.sharename); KernelLog.Ln();
		END;

		COPY(pattern, c.pattern);

		Strings.Concat(c.sharename, pattern, modPat);

		IF Trace THEN KernelLog.String(" -- Modprefix: "); KernelLog.String(modPat); KernelLog.Ln(); END;

		NEW(enum);
		enum.Open(modPat, {});

		IF searchCount > 100 THEN
			searchCount := 100;
		END;

		i := 0;
		totalFileNameLen := 0;

		WHILE (enum.HasMoreEntries()) & (i < searchCount) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);
			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
				totalFileNameLen := totalFileNameLen + SHORT(Strings.Length(eName));
				lastlen := SHORT(Strings.Length(eName));
				INC(i);
			END;
		END;

		eos := ~enum.HasMoreEntries();

		IF Trace THEN KernelLog.String(" -- Files found: "); KernelLog.Int(i, 0); KernelLog.Ln(); END;

		(* NO FILES FOUND *)
		IF i = 0 THEN
			c.error := TRUE;
			c.errorcode := 131073; (* 1179649; *)

			(* SEND *)
			c.netbios := 32 + 3;
			WriteSMBHeader(c);
			c.out.Net8(0);			(* word count *)
			c.out.RawInt(0);			(* bytecount *)
			c.out.Update();
			RETURN;
		END;

		IF loi = 260 THEN
			j := 96*i + totalFileNameLen;
			lastlen := lastlen + 96;
		ELSIF loi = 1 THEN
			j := 28*i + totalFileNameLen;
			lastlen := lastlen + 28;
		ELSE
			IF Trace THEN KernelLog.String(" -- LEVEL OF INTEREST NOT SUPPORTED "); KernelLog.Ln(); END;
			RETURN;
		END;

		(* SEND *)
		c.netbios := 32 + 23 + 10 + j;
		WriteSMBHeader(c);
		c.out.Net8(10);
		c.out.RawInt(10); 		(* total parameter count *)
		c.out.RawInt(j); 			(* total data count *)
		c.out.Net16(0);
		c.out.RawInt(10);  		(* parameter count *)
		c.out.RawInt(55); 		(* parameter offset *)
		c.out.RawInt(0);
		c.out.RawInt(j); 			(* data count *)
		c.out.RawInt(65); 		(* data offset *)
		c.out.RawInt(0);
		c.out.Net8(0);
		c.out.Net8(0);
		c.out.RawInt(10 +  j); 	(* byte count *)
		c.sid := GetSID();
		c.out.RawInt(c.sid);		(* search id *)
		c.out.RawInt(i); 			(* search count *)

		IF eos THEN
			c.out.RawInt(1); 	(* end of search *)
		ELSE
			c.out.RawInt(0); 	(* end of search *)
		END;

		c.out.RawInt(0); 		(* ea error *)
		c.out.RawInt(j - lastlen);(* lastnameoffset *)
		enum.Reset();

		WHILE (i > 0) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);

			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
				f := Files.Old(eName);

				IF loi = 260 THEN
					c.out.RawLInt(96 + Strings.Length(eName));		(* next entry offset *)
					c.out.RawLInt(0);		(* file index*)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* last access *)
					c.out.RawLInt(0);		(* last access *)
					IF (f # NIL) THEN
						f.GetDate(t,d);
						dTime := Dates.OberonToDateTime(d,t);
						GetSMBTimeStamp(dTime, tarray);
						c.out.RawLInt(tarray[0]);		(* last write *)
						c.out.RawLInt(tarray[1]);		(* last write *)
					ELSE
						c.out.RawLInt(0);		(* last write *)
						c.out.RawLInt(0);		(* last write *)
					END;

					c.out.RawLInt(0);		(* change *)
					c.out.RawLInt(0);		(* change *)

					IF (f # NIL) THEN
						c.out.RawLInt(f.Length());		(* eof *)
						c.out.RawLInt(0);		(* eof *)
					ELSE
						c.out.RawLInt(0);		(* eof *)
						c.out.RawLInt(0);		(* eof *)
					END;

					IF (f # NIL) THEN
						c.out.RawLInt(f.Length());		(* alloc *)
					ELSE
						c.out.RawLInt(0);		(* alloc *)
					END;

					c.out.RawLInt(0);		(* alloc *)
					flags := {};
					IF (Files.Directory IN eFlags) THEN INCL(flags, 4); END;
					IF (Files.ReadOnly IN eFlags) THEN INCL(flags, 0) END;
					c.out.RawLInt(SYSTEM.VAL(LONGINT, flags));		(* file attr *)
					c.out.RawLInt(1 + Strings.Length(eName));		(* filename len *)
					c.out.RawLInt(0);		(* ea list *)
					c.out.RawSInt(0);		(* short fn len *)
					c.out.RawSInt(0);		(* reserved *)

					FOR z := 1 TO 24 DO
						c.out.Net8(0);
					END;				(* short filename *)

					c.out.RawString(eName);		(* file name*)
					c.out.RawSInt(0);		(* padding *)
				ELSIF loi = 1 THEN
					c.out.RawLInt(0);		(* resume key *)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* last access *)

					IF (f # NIL) THEN
						f.GetDate(t,d);
						dTime := Dates.OberonToDateTime(d,t);
						GetUnixTimeStamp(dTime, t);
						c.out.RawLInt(t);		(* last write *)
						c.out.RawLInt(f.Length());		(* data size *)
						c.out.RawLInt(f.Length());		(* alloc size *)
					ELSE
						c.out.RawLInt(0);		(* last write *)
						c.out.RawLInt(0);
						c.out.RawLInt(0);
					END;

					flags := {};
					IF (Files.Directory IN eFlags) THEN INCL(flags, 4); END;
					IF (Files.ReadOnly IN eFlags) THEN INCL(flags, 0) END;
					c.out.RawInt(SYSTEM.VAL(INTEGER, flags));			(* file attri *)
					c.out.RawSInt(SHORT(SHORT(Strings.Length(eName))));	(* filename len *)
					c.out.RawString(eName);		(* file name*)
				END;
			END;
			DEC(i);
		END;
		c.out.Update();
		enum.Close();
	ELSIF (subcmd = 2) THEN
		IF Trace THEN KernelLog.String(" -- FIND Next 2"); KernelLog.Ln(); END;
		c.in.RawInt(sidnext);
		c.in.RawInt(searchCount);
		c.in.RawInt(loi);
		c.in.SkipBytes(6);
		c.in.RawString(resumeFn);
		GetPattern(sidnext, pattern);
		ReplaceSlash(pattern);
		GetSharename(c);

		IF Trace THEN
			KernelLog.String(" _- Search Count: "); KernelLog.Int(searchCount, 0); KernelLog.Ln();
			KernelLog.String(" _- Resume Filename: "); KernelLog.String(resumeFn); KernelLog.Ln();
			KernelLog.String(" -- Pattern: "); KernelLog.String(pattern); KernelLog.Ln();
			KernelLog.String(" -- Level of Interest: "); KernelLog.Int(loi, 0); KernelLog.Ln();
			KernelLog.String(" -- sharename: "); KernelLog.String(c.sharename); KernelLog.Ln();
		END;

		Strings.Concat(c.sharename, pattern, modPat);

		IF Trace THEN KernelLog.String(" -- Modprefix: "); KernelLog.String(modPat); KernelLog.Ln(); END;

		NEW(enum);
		enum.Open(modPat, {});

		IF searchCount > 100 THEN
			searchCount := 100;
		END;

		i := 0;
		totalFileNameLen := 0;

		WHILE (eName # resumeFn) & (enum.HasMoreEntries()) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);
			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
			END;
		END;

		WHILE (enum.HasMoreEntries()) & (i < searchCount) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);
			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
				totalFileNameLen := totalFileNameLen + SHORT(Strings.Length(eName));
				lastlen := SHORT(Strings.Length(eName));
				INC(i);
			END;
		END;

		eos := ~enum.HasMoreEntries();

		IF Trace THEN KernelLog.String(" -- Files found: "); KernelLog.Int(i, 0); KernelLog.Ln(); END;

		IF loi = 260 THEN
			j := 96*i + totalFileNameLen;
			lastlen := lastlen + 96;
		ELSIF loi = 1 THEN
			j := 28*i + totalFileNameLen;
			lastlen := lastlen + 28;
		ELSE
			IF Trace THEN KernelLog.String(" -- LEVEL OF INTEREST NOT SUPPORTED "); KernelLog.Ln(); END;
			RETURN;
		END;

		(* SEND *)
		c.netbios := 32 + 23 + 8 + j;
		WriteSMBHeader(c);
		c.out.Net8(8);
		c.out.RawInt(8); 		(* total parameter count *)
		c.out.RawInt(j); 			(* total data count *)
		c.out.Net16(0);
		c.out.RawInt(8);  		(* parameter count *)
		c.out.RawInt(55); 		(* parameter offset *)
		c.out.RawInt(0);
		c.out.RawInt(j); 			(* data count *)
		c.out.RawInt(63); 		(* data offset *)
		c.out.RawInt(0);
		c.out.Net8(0);
		c.out.Net8(0);
		c.out.RawInt(10 +  j); 	(* byte count *)
		c.out.RawInt(i); 			(* search count *)

		IF eos THEN
			c.out.RawInt(1); 	(* end of search *)
		ELSE
			c.out.RawInt(0); 	(* end of search *)
		END;

		c.out.RawInt(0); 		(* ea error *)
		c.out.RawInt(j - lastlen);(* lastnameoffset *)
		enum.Reset();

		WHILE (eName # resumeFn) & (enum.HasMoreEntries()) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);
			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
			END;
		END;

		WHILE (i > 0) DO
			success := enum.GetEntry(fullName, eFlags, eTime, eDate, eSize);
			IF success THEN
				Files.SplitName(fullName, prefix, eName);
				Files.SplitPath(eName, pathname, eName);
				f := Files.Old(eName);

				IF loi = 260 THEN
					c.out.RawLInt(96 + Strings.Length(eName));		(* next entry offset *)
					c.out.RawLInt(0);		(* file index*)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* last access *)
					c.out.RawLInt(0);		(* last access *)

					IF (f # NIL) THEN
						f.GetDate(t,d);
						dTime := Dates.OberonToDateTime(d,t);
						GetSMBTimeStamp(dTime, tarray);
						c.out.RawLInt(tarray[0]);		(* last write *)
						c.out.RawLInt(tarray[1]);		(* last write *)
					ELSE
						c.out.RawLInt(0);		(* last write *)
						c.out.RawLInt(0);		(* last write *)
					END;

					c.out.RawLInt(0);		(* change *)
					c.out.RawLInt(0);		(* change *)

					IF (f # NIL) THEN
						c.out.RawLInt(f.Length());		(* eof *)
						c.out.RawLInt(0);		(* eof *)
						c.out.RawLInt(f.Length());		(* alloc *)
						c.out.RawLInt(0);		(* alloc *)
					ELSE
						c.out.RawLInt(0);		(* eof *)
						c.out.RawLInt(0);		(* eof *)
						c.out.RawLInt(0);		(* alloc *)
						c.out.RawLInt(0);		(* alloc *)
					END;

					flags := {};
					IF (Files.Directory IN eFlags) THEN INCL(flags, 4); END;
					IF (Files.ReadOnly IN eFlags) THEN INCL(flags, 0) END;
					c.out.RawLInt(SYSTEM.VAL(LONGINT, flags));		(* file attr *)

					c.out.RawLInt(1 + Strings.Length(eName));		(* filename len *)
					c.out.RawLInt(0);		(* ea list *)
					c.out.RawSInt(0);		(* short fn len *)
					c.out.RawSInt(0);		(* reserved *)

					FOR z := 1 TO 24 DO
						c.out.Net8(0);
					END;				(* short filename *)

					c.out.RawString(eName);		(* file name*)
					c.out.RawSInt(0);		(* padding *)
				ELSIF loi = 1 THEN
					c.out.RawLInt(0);		(* resume key *)
					c.out.RawLInt(0);		(* created *)
					c.out.RawLInt(0);		(* last access *)

					IF (f # NIL) THEN
						f.GetDate(t,d);
						dTime := Dates.OberonToDateTime(d,t);
						GetUnixTimeStamp(dTime, t);
						c.out.RawLInt(t);		(* last write *)
						c.out.RawLInt(f.Length());		(* data size *)
					ELSE
						c.out.RawLInt(0);		(* last write *)
						c.out.RawLInt(0);
					END;

					IF (f # NIL) THEN
						c.out.RawLInt(f.Length());		(* alloc size *)
					ELSE
						c.out.RawLInt(0);
					END;

					flags := {};
					IF (Files.Directory IN eFlags) THEN INCL(flags, 4); END;
					IF (Files.ReadOnly IN eFlags) THEN INCL(flags, 0) END;
					c.out.RawInt(SYSTEM.VAL(INTEGER, flags));			(* file attri *)
					c.out.RawSInt(SHORT(SHORT(Strings.Length(eName))));	(* filename len *)
					c.out.RawString(eName);		(* file name*)
				END;
			END;
			DEC(i);
		END;
		c.out.Update();
		enum.Close();
	END;
END Trans2Logic;

PROCEDURE WriteSMBHeader(c: Connection);
BEGIN
	c.in.Reset();
	c.out.Reset();
	c.out.Net16(0);			(* message type *)
	c.out.Net16(c.netbios);	(* Netbios length *)
	c.out.Char(CHR(255));
	c.out.String("SMB");
	c.out.Net8(c.cmd);		(* Command *)

	IF ~c.error THEN
		c.out.Net32(0);		(* status code *)
	ELSE
		c.out.RawLInt(c.errorcode);
	END;

	c.out.Net8(90H);		(* FLAGS *)
	c.out.RawInt(1);			(* FLAGS 2 *)
	c.out.Net32(0);
	c.out.Net32(0);			(* EXTRA *)
	c.out.Net32(0);

	IF (c.cmd = ORD(75X)) THEN
		c.tid := GetTID();
	END;

	c.out.RawInt(c.tid);		(* TID *)
	c.out.RawInt(c.pid);		(* PID *)

	IF (c.cmd = ORD(73X)) THEN
		c.uid := GetUID();
	END;

	c.out.RawInt(c.uid);		(* UID *)
	c.out.RawInt(c.mid);		(* MID *)
END WriteSMBHeader;

PROCEDURE CheckSMBHeader(VAR c: Connection): BOOLEAN;
VAR
	variable: LONGINT;
BEGIN
	c.in.SkipBytes(2);
	c.msgSize := c.in.Net16();	(* NetBios length *)
	variable := c.in.Net32();		(* 0xFF SMB *)

	IF variable # -11317950 THEN
		c.error := TRUE;			(* not correct *)
		RETURN TRUE;
	END;

	c.cmd := c.in.Net8();
	variable := c.in.Net32();		(* NT Status *)

	IF variable # 0 THEN
		c.error := TRUE;			(* not correct *)
		RETURN TRUE;
	END;

	c.flags := c.in.Net8();
	c.in.RawInt(c.flags2);
	c.in.SkipBytes(12);
	c.in.RawInt(c.tid);
	c.in.RawInt(c.pid);
	c.in.RawInt(c.uid);
	c.in.RawInt(c.mid);
	RETURN FALSE;
END CheckSMBHeader;

PROCEDURE ReplaceSlash(VAR name: ARRAY OF CHAR);
VAR
	i: LONGINT;
BEGIN
	i := 0;
	WHILE (i < Strings.Length(name)) DO
		IF name[i] = CHR(5CH) THEN
			name[i] := CHR(2FH);
		END;
		INC(i)
	END;
END ReplaceSlash;

PROCEDURE RemoveQuotes(VAR name: ARRAY OF CHAR);
VAR
	i,j: LONGINT;
	newName: ARRAY 256 OF CHAR;
BEGIN
	i := 0;
	j := 0;
	WHILE (i < Strings.Length(name)) DO
		IF name[i] # CHR(22H) THEN
			newName[j] := name[i];
			INC(i);
			INC(j);
		ELSE
			INC(i);
		END;
	END;
	COPY(newName, name);
END RemoveQuotes;

PROCEDURE RemoveSlash(VAR name: ARRAY OF CHAR);
VAR
	i: LONGINT;
BEGIN
	i := 1;
	WHILE (i <= Strings.Length(name)) DO
		name[i-1] := name[i];
		INC(i)
	END;
END RemoveSlash;

PROCEDURE NewAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR
	a: Agent;
BEGIN
	NEW(a, c, s);
	RETURN a;
END NewAgent;

PROCEDURE StartServer*(context: Commands.Context);
VAR
	res: LONGINT;
BEGIN {EXCLUSIVE}
	IF service = NIL THEN
		lastUID := 777;
		lastTID := 555;
		lastFID := 333;
		lastSID := 111;
		NEW(firstConn);

		NEW(service, SMBPort, NewAgent, res);

		context.out.String("Start SambaServer...");
		IF res = TCPServices.Ok THEN
			context.out.String("started!");
			context.out.Ln();
		ELSE
			context.out.Ln();
			context.out.String("Could not start SambaServer. Res: ");
			context.out.Int(res, 0);
			context.out.Ln();
			service := NIL;
		END;
	ELSE
		context.out.String("SambaServer already running...");
		context.out.Ln();
	END;
END StartServer;

PROCEDURE StopServer*(context: Commands.Context);
BEGIN {EXCLUSIVE}
	IF service # NIL THEN
		service.Stop();
		service := NIL;
		context.out.String("SambaServer stopped!");
		context.out.Ln();
	ELSE
		context.out.String("SambaServer was already stopped!");
		context.out.Ln();
	END;
END StopServer;

PROCEDURE FindShare(CONST unc : ARRAY OF CHAR) : Share;
VAR share : Share;
BEGIN {EXCLUSIVE}
	share := shares;
	WHILE (share # NIL) & (share.unc # unc) DO share := share.next; END;
	RETURN share;
END FindShare;

PROCEDURE AddShare*(context : Commands.Context); (** name sharepath ~ *)
VAR share : Share; prefix : Files.Prefix; path : Files.FileName;
BEGIN
	NEW(share);
	context.arg.SkipWhitespace; context.arg.String(share.unc);
	context.arg.SkipWhitespace; context.arg.String(share.path);
	Files.SplitName(share.path, prefix, path);
	IF (prefix # "") THEN
		IF FindShare(share.unc) = NIL THEN
			BEGIN {EXCLUSIVE}
				share.next := shares;
				shares := share;
			END;
			context.out.String("Added share "); context.out.String(share.unc);
			context.out.String(" ("); context.out.String(share.path);
			context.out.String(")"); context.out.Ln;
		ELSE
			context.error.String("UNC "); context.error.String(share.unc);
			context.error.String(" is already used."); context.error.Ln;
		END;
	ELSE
		context.error.String("Prefix required"); context.error.Ln;
	END;
END AddShare;

PROCEDURE ListShares*(context : Commands.Context);
VAR share : Share;
BEGIN {EXCLUSIVE}
	context.out.String("SambaServer share list: "); context.out.Ln;
	IF (shares # NIL) THEN
		share := shares;
		WHILE (share # NIL) DO
			context.out.String(share.unc); context.out.String(" -> ");
			context.out.String(share.path); context.out.Ln;
			share := share.next;
		END;
	ELSE
		context.out.String("No shares"); context.out.Ln;
	END;
END ListShares;

PROCEDURE GetSMBTimeStamp(dtNow:Dates.DateTime; VAR t: ARRAY OF LONGINT);
VAR
	dtOld : Dates.DateTime;
	diffDay, diffHour, diffMinute, diffSecond: LONGINT;
	tsNow : HUGEINT;
BEGIN
	dtOld.year := 1601;
	dtOld.month := 1;
	dtOld.day := 1;
	dtOld.hour := 0;
	dtOld.minute := 0;
	dtOld.second := 0;
	Dates.TimeDifference(dtOld, dtNow, diffDay, diffHour, diffMinute, diffSecond);
	tsNow := diffDay * 86400 + diffHour * 3600 + diffMinute * 60 + diffSecond;
	tsNow := tsNow * 10000000;
	t[0] := SHORT(tsNow);
	t[1] := SHORT(tsNow DIV 100000000H);
END GetSMBTimeStamp;

PROCEDURE GetUnixTimeStamp(dtNow: Dates.DateTime; VAR t: LONGINT);
VAR
	dtOld : Dates.DateTime;
	diffDay, diffHour, diffMinute, diffSecond: LONGINT;
BEGIN
	dtOld.year := 1970;
	dtOld.month := 1;
	dtOld.day := 1;
	dtOld.hour := 0;
	dtOld.minute := 0;
	dtOld.second := 0;
	Dates.TimeDifference(dtOld, dtNow, diffDay, diffHour, diffMinute, diffSecond);
	t := diffDay * 86400 + diffHour * 3600 + diffMinute * 60 + diffSecond;
END GetUnixTimeStamp;

PROCEDURE GetDOSTimeStamp(dtNow: Dates.DateTime; VAR t: LONGINT);
VAR
	hour, minute, second, year, month, day: LONGINT;
BEGIN
	hour := ASH(dtNow.hour, 27);
	minute := ASH(dtNow.minute, 21);
	second := ASH(dtNow.second DIV 2, 16);
	year := ASH(dtNow.year - 1980, 9);
	month := ASH(dtNow.month, 5);
	day := dtNow.day;
	t := hour + minute + second + year + month + day;
END GetDOSTimeStamp;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF service # NIL THEN
		service.Stop();
		service := NIL;
	END;
END Cleanup;

BEGIN
	shares := NIL;
	Modules.InstallTermHandler(Cleanup);
END SambaServer.

SambaServer.StartServer ~
SambaServer.StopServer ~
SystemTools.Free SambaServer ~

SambaServer.ListShares ~
SambaServer.AddShare \AOS AOS: ~
SambaServer.AddShare \FAT FAT:Test/ ~
SambaServer.AddShare \Test ../Legal/ ~

