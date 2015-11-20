(* $VCS   1, edgar@edgarschwarz.de, 06.01.02 22:37:41 $
	$Log$
$   1, edgar@edgarschwarz.de, 06.01.02 22:37:41
First baseline of DAVDeltav stuff.
$   1, edgar@edgarschwarz.de, 06.01.02 22:28:44
Extensions for DelatV under AOS.
$   3, Edgar.Schwarz@z.zgs.de, 10 Sep 99, 22:4:40
prefixLen -> PrefixLen  (typo)
$   2, Edgar.Schwarz@z.zgs.de, 1 Feb 99, 22:6:51
with makro flag stuff
$   1, Edgar.Schwarz@z.zgs.de, 31 Jan 99, 1:7:28
$ first version for new format
*)
MODULE OdVCSBase;
(* old delta format
kk	fol. data bytes	tot. bits offset	tot. bits len	max. start offset	max. len.
----------------------------------------------------------------
00	ss					   16					    5					64 KB					32 byte
01	ssl					  16					  13					64 KB					  8 KB
10	sssl					 24					  13				   16 MB					  8 KB
11	sssslll				  32					  29					 4 GB				  512 MB
*)
(** new delta file format
description
	(ci) = compressed integer in Oberon style
	(d) =  data as array of bytes
	tags = numbers coded as a byte
---------
DeltaFile =  # newest revision of file + deltas
	FormatName Flags Text 1{ Diff } .
FormatName = "dsfantf1" .
Flags = SET{31..1,MakroBit}.
Text = TextTag TextLen(ci) Text(d) .
Diff = # newer before older diffs
	DiffTag DiffLen(ci) OldTextLen(ci)
	Versiontag Version(ci)
	DateTag DateLen(ci) Date(d)
	AuthorTag AuthorLen(ci) Author(d)
	LogTextTag  LogTextLen(ci)  LogText(d)
	{ DeltaAddTag   AddLen(ci) AddData(d)
	  | DeltaCopyTag CopyLen(ci) CopyOffset(ci) }
	[ AttachmentTag AttachmentLen(ci) Attachment(d) ] .
*)
(*
	Michael Pitra, crea@wildsau.idv-edu.uni-linz.ac.at

	Dialog.Open Versions.Dlg

	implementatory details:

	I used an algorithm based on one invented by Christoph Reichenberger.
	[Delta Storage for Arbitrary Non-Text Files,
	Proceedings of the 3rd International Workshop on Software Configuration Management,
	Trondheim, Norway, June 12-14, 1991]

	The delta file consists of 3 sorts of different commandos, each commando only needs one byte:
	end	[0,0,0,0,0,0,0,0]
		ends delta file
	add	[0,n,n,n,n,n,n,n]
		initiates an add of the following x bytes. If there are more than 127 bytes to add,
		just more than one add commando take place
	copy	[1,k,k,n,n,n,n,n]
		There are 4 different forms of the copy command:


		s ... start offset byte
		l ... length byte (SHL 5)
		n ... lowest 5 bits of length

	The version control system file is using following format:


		the delta1 ... files are of the format described above.

	Last Update:
*)
IMPORT SYSTEM, Dates, Strings, Files, Out := KernelLog, Clock;

CONST
	BaseDir* = "FTP:/WebDAV/repo/";
	TmpDFile="FTP:/WebDAV/repo/VCSBaseD.Temp";  (* New delta file. TODO: Better with <name>.Temp ?  *)
	FormatLen* = 8;
	FormatName* ="dsfantf1";  (* delta storage for arbitrary non-text files,
		invented by Christoph Reichenberger, format 0 is the original one by
		Michael Pitras implementation *)
	(* up to 32 flags *)
	MakroBit* = 0;  (* makro expansion yes/no *)
	(* some tags for log info *)
	VersionTag = 1X;
	DateTag = 2X;
	AuthorTag = 3X;
	LogTextTag = 4X;
	DeltaAddTag = 5X;
	DeltaCopyTag = 6X;
	AttachmentTag = 7X;
	TextTag = 8X;
	DiffTag = 9X;
	AccessTag = 0AX;

	HashLen = 16381;					(* prime near 2^15 *)
	D = 256;								(* byte-oriented *)
	PrefixLen = 7;
	MaxVersions* = 100;            (* !!! should be removed (es) *)
TYPE
	PLinkNode = POINTER TO TLinkNode;
	TLinkNode = RECORD
						next: PLinkNode;
						pos: LONGINT;
					END;
	THashList = ARRAY HashLen OF PLinkNode;
	PHashList = POINTER TO THashList;
	TWorkBytes = ARRAY PrefixLen OF CHAR;
	TData = POINTER TO ARRAY OF CHAR;
	TLog* = RECORD
		versionID*: LONGINT;
		author*: ARRAY 127 OF CHAR;
		logText*: ARRAY 256 OF CHAR;
		date*: ARRAY 22 OF CHAR;
		lenOfDelta: LONGINT;
		lenOfOld: LONGINT; (* file length of old version to allocate
			a matching buffer *)
		flags* : SET;
	END;
	TFileName* = ARRAY 256 OF CHAR;
	TDeltaEntry* = ARRAY 20 OF CHAR;
	TDList* = ARRAY MaxVersions OF TDeltaEntry;

VAR
	errMsg*: ARRAY 256 OF CHAR;
	formatStr: ARRAY FormatLen+1 OF CHAR;
	res: LONGINT;

(* Split a filename in it's directory part and member name.
	filename = [ filesystem ":" ] ["/"] [ dir "/" ] base. *)
PROCEDURE splitDirBase(fileName: ARRAY OF CHAR; VAR dir, base: ARRAY OF CHAR);
CONST CollCh = "/"; FileSystemCh = ":";
VAR collPos, len, i: LONGINT;
BEGIN
	len := Strings.Length(fileName);
	(* Get last collection delimiter. *)
	collPos := -1;
	LOOP
		FOR i := 0 TO len -1 DO
			IF fileName[len-i] = CollCh THEN
				collPos := len-i;
				EXIT;
			ELSIF fileName[len-i] = FileSystemCh THEN
				EXIT;
			END;
		END;
	END;
	IF collPos = -1 THEN
		COPY("", dir); COPY(fileName, base);
	ELSE
		FOR i := 0 TO collPos-1 DO dir[i] := fileName[i]; END;
		dir[collPos] := 0X;
		FOR i := collPos+1 TO len -1 DO base[i-collPos-1] := fileName[i]; END;
		base[i-collPos] := 0X;
	END;
END splitDirBase;

(** Create directory for a filename if it doesn't exist. *)
PROCEDURE makeDirs(name: ARRAY OF CHAR): LONGINT;
VAR
	dir, base: ARRAY 128 OF CHAR;
	res: LONGINT;
	dirFile: Files.File;
BEGIN
	Files.SplitPath(name, dir, base);
	dirFile := Files.Old(dir);
	IF dirFile = NIL THEN
		Files.CreateDirectory(dir, res);
		RETURN res;
	ELSE
		RETURN 0; (* Directory already exists. *)
	END;
END makeDirs;

PROCEDURE DateTime*(VAR s: ARRAY OF CHAR);
VAR date, time: LONGINT; dateTime: Dates.DateTime; timeStr: ARRAY 16 OF CHAR;
BEGIN
	Clock.Get(time, date);
	dateTime := Dates.OberonToDateTime(date, time);
	Strings.DateToStr(dateTime, s); 			Strings.Append(s, " ");
	Strings.TimeToStr(dateTime, timeStr);  Strings.Append(s, timeStr);
END DateTime;

(** Hashing stuff *)

PROCEDURE Hash(toHash: TWorkBytes): LONGINT;

VAR
	i, h: LONGINT;

BEGIN
	h := 0;
	FOR i := 0 TO PrefixLen - 1 DO
		h := (h * D + ORD(toHash[i])) MOD HashLen;
	END;
	RETURN h;
END Hash;


PROCEDURE AccessArray(arr: TData; len, left, right: LONGINT; VAR ret: ARRAY OF CHAR);

VAR
	i: LONGINT;

BEGIN
	IF (arr = NIL) OR (left > len - 1) OR (right > len - 1) THEN RETURN END;
	IF left > right THEN i := left; left := right; right := i; END;
	FOR i := left TO right DO
		ret[i-left] := arr[i];
	END;
END AccessArray;


PROCEDURE BuildLinkList(new: TData; lenNew: LONGINT; hashList: PHashList);

VAR
	actBytes: TWorkBytes;
	i, h: LONGINT;
	oldNode, newNode: PLinkNode;

BEGIN
	IF new = NIL THEN RETURN END;
	FOR i := 0 TO lenNew - PrefixLen - 1 DO
		AccessArray(new, lenNew, i, i + PrefixLen - 1, actBytes);
		h := Hash(actBytes);
		NEW(newNode);
		newNode.pos := i;
		newNode.next := NIL;
		IF hashList[h] = NIL THEN
			hashList[h] := newNode;
		ELSE
			oldNode := hashList[h];
			WHILE oldNode.next # NIL DO oldNode := oldNode.next; END;
			oldNode.next := newNode;
		END;
	END;
END BuildLinkList;

PROCEDURE FindLongest(old, new: TData; lenOld, lenNew, oldPos: LONGINT;
		VAR copyStart: PLinkNode; VAR copyLen: LONGINT; hashList: PHashList);

VAR
	work: TWorkBytes;
	h, n: LONGINT;
	start: PLinkNode;

BEGIN
	AccessArray(old, lenOld, oldPos, oldPos + PrefixLen - 1, work);
	h := Hash(work);
	start := hashList[h];
	copyLen := 0;
	WHILE start # NIL DO						(* sentinel is the nil-element in hashList and linkList *)
		n := 0;
		WHILE (oldPos+n < lenOld) & (start.pos+n < lenNew) & (old[oldPos+n] = new[start.pos+n]) DO
			INC(n);
		END;
		(* Find maximal n such that
			old[oldPos..oldPos+n-1] = new[start..start+n-1]	*)
		IF (oldPos+n <= lenOld) & (start.pos+n <= lenNew) & (n > copyLen) THEN
			copyLen := n; copyStart := start;
		END;
		start := start.next;
	END;

(*	Out.String("ol,nl,op,n"); Out.Int(lenOld,5); Out.Int(lenNew,5);
	Out.Int(oldPos,5); Out.Int(n,5); Out.Ln; *)

END FindLongest;

(** Delta stuff *)

(** DeltaAddTag   AddLen(ci) AddData(d) *)
PROCEDURE EmitAdd(old: TData; VAR dr: Files.Rider; offset, length: LONGINT);
VAR
	i: LONGINT;
BEGIN
	dr.file.Write(dr, DeltaAddTag);
	Files.WriteNum(dr, length);
	FOR i := 0 TO length-1 DO dr.file.Write(dr, old[offset + i]); END;
END EmitAdd;

(**  DeltaCopyTag CopyLen(ci) CopyOffset(ci)  *)
PROCEDURE EmitCopy(VAR dr: Files.Rider; offset, length: LONGINT);
BEGIN
	dr.file.Write(dr, DeltaCopyTag);
	Files.WriteNum(dr, length);
	Files.WriteNum(dr, offset);
END EmitCopy;

(** add delta information to diff data *)
PROCEDURE CreateDelta*(old, new: TData; VAR dr: Files.Rider;
	lenOld, lenNew: LONGINT);

VAR
	oldPos, addStart, copyLen: LONGINT;
	copyStart: PLinkNode;
	hashList: PHashList;

BEGIN
	NEW(hashList);
	BuildLinkList(new, lenNew, hashList);
	oldPos := 0;
	addStart := 0;
	WHILE oldPos < lenOld - PrefixLen DO
		FindLongest(old, new, lenOld, lenNew, oldPos, copyStart, copyLen,
							hashList);
		IF copyLen >= PrefixLen THEN		(* block move found *)
			IF addStart < oldPos THEN		(* emit pending add command *)
			EmitAdd(old, dr, addStart, (oldPos (* -1 *) )-addStart);

(*	Out.String("add: "); Out.Int(addStart, 5); Out.String(", ");
	Out.Int((oldPos-1)-addStart, 5); Out.Ln;*)

			END;
			EmitCopy(dr, copyStart.pos, copyLen);

(*Out.String("cpy: "); Out.Int(copyStart.pos, 5); Out.String(", ");
		Out.Int(copyLen, 5); Out.Ln;	*)

			oldPos := oldPos + copyLen;
			addStart := oldPos;
		ELSE											(* old[oldPos] must be marked for adding *)
			INC(oldPos);
		END;
	END;
	IF addStart < lenOld -1 THEN
		EmitAdd(old, dr, addStart, (lenOld (* -1 *) )-addStart);

(*Out.String("add: "); Out.Int(addStart, 5); Out.String(", ");
	Out.Int((lenOld-1)-addStart, 5); Out.Ln;	*)

	END;
	hashList := NIL;
END CreateDelta;

(** create previous from current version *)
PROCEDURE ApplyDelta*(old, new: TData; dr: Files.Rider);

VAR
	oldPos, newPos, len, i, kk: LONGINT;
	tag: CHAR;
BEGIN
	oldPos := 0;
	LOOP
		dr.file.Read(dr, tag);
		CASE tag OF
			DeltaAddTag: (* add some stuff from delta data *)
				Files.ReadNum(dr, len);
				FOR i := 0 TO len-1 DO
					dr.file.Read(dr, old[oldPos]); INC(oldPos);
			   END;
			| DeltaCopyTag: (* copy some stuff from new version *)
					Files.ReadNum(dr, len);
				Files.ReadNum(dr, newPos);
				FOR i := 0 TO len - 1 DO
					old[oldPos] := new[newPos + i]; INC(oldPos);
				END;
			ELSE
				EXIT
		END;
	END;
END ApplyDelta;


PROCEDURE NameToDelta(name: TFileName; VAR df: TFileName);
VAR
	i, ofs: LONGINT;
BEGIN
	i := Strings.Pos(":", name);
	IF i = -1 THEN (* Add BaseDir *)
		df := BaseDir;
		ofs := Strings.Length(df);
	ELSE
		ofs := 0;
	END;
	i := 0;
	WHILE (name[i] # 0X) DO
		df[i+ofs] := name[i];
		INC(i);
	END;
	df[i+ofs] := "."; df[i+ofs+1] := "V"; df[i+ofs+2] := "C"; df[i+ofs+3] := "S"; df[i+ofs+4] := 0X;
END NameToDelta;

PROCEDURE NameToBak(name: TFileName; VAR df: TFileName);
VAR
	i: INTEGER;
BEGIN
	i := 0;
	WHILE (name[i] # 0X) DO
		df[i] := name[i];
		INC(i);
	END;
	df[i] := "."; df[i+1] := "B"; df[i+2] := "a"; df[i+3] := "k"; df[i+4] := 0X;
END NameToBak;

(* get text length from delta file, rider is set to beginning of text *)
PROCEDURE GetTextLen(VAR fr: Files.Rider; f: Files.File): LONGINT;
VAR
	len: LONGINT;
BEGIN
	f.Set(fr, FormatLen+4+1); (* skip format + flags(SET) + TextTag *)
	Files.ReadNum(fr, len);
	RETURN len
END GetTextLen;


(* get newest version number from first diff in file with rider *)
PROCEDURE GetNewestVersion(fr: Files.Rider; f: Files.File): LONGINT;
VAR
	newestVersion, len: LONGINT;
	tag: CHAR;
	df: Files.File;
	dfr: Files.Rider;
	dfn: TFileName;
BEGIN
	f.Set(fr, FormatLen+4+1); (* skip format + flags(SET) + TextTag *)
	Files.ReadNum(fr, len); (* text len *)
	f.Set(fr, fr.file.Pos(fr)+len+1); (* skip text + DiffTag *)
	Files.ReadNum(fr, len); (* diff len *)
	Files.ReadNum(fr, len); (* old text len *)
	fr.file.Read(fr, tag); (* VersionTag *)
	Files.ReadNum(fr, newestVersion);
	RETURN newestVersion
END GetNewestVersion;

(* get position of diff from version n to n-1 *)
PROCEDURE GetDiffPos(fr: Files.Rider; f: Files.File; n: LONGINT): LONGINT;
VAR
	diffPos,  nextDiffPos, len, diffLen, version: LONGINT;
	tag: CHAR;
	df: Files.File;
	dfr: Files.Rider;
	dfn: TFileName;
BEGIN
	f.Set(fr, FormatLen+4+1); (* skip format + flags(SET) + TextTag *)
	Files.ReadNum(fr, len); (* text len *)
(*	Out.String("GetDiffPos"); Out.Int(n,5); Out.Ln; *)
	diffPos := fr.file.Pos(fr)+len;
	LOOP
		f.Set(fr, diffPos+1); (* skip DiffTag *)
		Files.ReadNum(fr, diffLen); (* diff len *)
		nextDiffPos := fr.file.Pos(fr) + diffLen;
		Files.ReadNum(fr, len); (* old text len *)
		fr.file.Read(fr, tag); (* VersionTag *)
		Files.ReadNum(fr, version);
(*	Out.Int(diffPos,10); Out.Int(version, 10); Out.Ln;*)
		IF version <= n THEN
			EXIT; (* got it *)
		ELSE
			diffPos := nextDiffPos;
		END;
	END;
	RETURN diffPos
END GetDiffPos;

(** get newest version number from first diff in file by name *)
PROCEDURE Init*(name: TFileName): LONGINT;
VAR
	newestVersion: LONGINT;
	df: Files.File;
	dfr: Files.Rider;
	dfn: TFileName;
BEGIN
	NameToDelta(name, dfn);
	df := Files.Old(dfn);
	IF df = NIL THEN
		errMsg := " *.VCS file not found ";
		newestVersion := -1;
	ELSE
		newestVersion := GetNewestVersion(dfr, df);
	END;
	RETURN newestVersion
END Init;


(** get log data for version n *)
PROCEDURE GetLog*(name: TFileName; n: LONGINT; VAR log: TLog);

VAR
	diffLen, diffStart, num: LONGINT;
	textLen: LONGINT;
	dFileName: TFileName;
	df: Files.File;
	dr: Files.Rider;
	tag: CHAR;
BEGIN
	NameToDelta(name, dFileName);
	df := Files.Old(dFileName);
	IF df=NIL THEN
		log.author  := ""; (*"no author";*)
		log.logText := ""; (*"no log text";*)
		log.versionID := -1;
		log.date := "";
		log.flags := {};
		RETURN;
	END;
	IF n > GetNewestVersion(dr, df) THEN
		log.author  := ""; (*"no author";*)
		log.logText := ""; (*"no log text";*)
		log.versionID := -1;
		log.date := "";
		log.flags := {};
		RETURN;
	END;
	(* get flags *)
	df.Set(dr, FormatLen); Files.ReadSet(dr, log.flags);
	(* look for version loginfo *)
	textLen := GetTextLen(dr, df); (* dr is at be beginning of text now *)
	df.Set(dr, dr.file.Pos(dr)+textLen);
	LOOP
		dr.file.Read(dr, tag); (* DiffTag *)
		IF tag # DiffTag THEN
			Out.String("DiffTag expected"); Out.Ln;
		END;
		Files.ReadNum(dr, diffLen);
		diffStart := dr.file.Pos(dr);
		Files.ReadNum(dr, log.lenOfOld); (* old text len *)
		dr.file.Read(dr, tag); (* VersionTag *)
		IF tag # VersionTag THEN
			Out.String("VersionTag expected"); Out.Ln;
		END;
		Files.ReadNum(dr, log.versionID);
(*		Out.String("GetLog:"); Out.Int(log.versionID, 5);
		Out.Int(n, 5); Out.Ln;
*)
		IF log.versionID > n THEN
			(* go to next difference *)
			df.Set(dr, diffStart+diffLen);
		ELSIF log.versionID < n THEN
			(* version not found *)
			dr.eof := TRUE; RETURN;
		ELSE (* found my version *)
			LOOP
				dr.file.Read(dr, tag);
				IF dr.eof THEN RETURN END; (* looking for last log *)
				CASE tag OF
					DiffTag: (* end of diff reached *)
						RETURN;
					| DateTag:
						Files.ReadNum(dr, num);
						dr.file.ReadBytes(dr, log.date, 0, num);
					| AuthorTag:
						Files.ReadNum(dr, num);
						dr.file.ReadBytes(dr, log.author, 0, num);
					| LogTextTag:
						Files.ReadNum(dr, num);
						dr.file.ReadBytes(dr, log.logText, 0, num);
						RETURN;
					ELSE
						(* discard and go on *)
						Files.ReadNum(dr, num);
						df.Set(dr, dr.file.Pos(dr)+num);
				END;
			END;
			RETURN;
		END;
	END;
END GetLog;

(** get delta information for a version, set dr to beginning *)
PROCEDURE GetDelta*(name: TFileName; n: LONGINT; VAR df: Files.File;
	VAR dr: Files.Rider);
VAR
	diffStart, diffLen, version: LONGINT;
	dFileName: TFileName;
	log: TLog;
	tag: CHAR; num: LONGINT;
BEGIN
	IF df = NIL THEN
		NameToDelta(name, dFileName);
		df := Files.Old(dFileName);
	END;
	df.Set(dr, FormatLen+4); (* skip format + flags *)
	dr.file.Read(dr, tag); (* TextTag *)
	Files.ReadNum(dr, num);
	df.Set(dr, dr.file.Pos(dr)+num); (* skip text *)
	LOOP
		dr.file.Read(dr, tag); (* DiffTag *)
		IF tag # DiffTag THEN
			Out.String("DiffTag expected"); Out.Ln;
		END;
		Files.ReadNum(dr, diffLen);
		diffStart := dr.file.Pos(dr);
		Files.ReadNum(dr, num); (* old text len *)
		dr.file.Read(dr, tag); (* VersionTag *)
		IF tag # VersionTag THEN
			Out.String("VersionTag expected"); Out.Ln;
		END;
		Files.ReadNum(dr, version);
		IF version > n THEN
			(* go to next difference *)
			df.Set(dr, diffStart+diffLen);
		ELSIF version < n THEN
			(* version not found *)
			dr.eof := TRUE; RETURN;
		ELSE (* found my version *)
			LOOP (* look for beginning of delta information in diff data *)
				dr.file.Read(dr, tag);
				CASE tag OF
					DeltaAddTag, DeltaCopyTag:
						df.Set(dr, dr.file.Pos(dr)-1); RETURN;
					| DiffTag:
						(* no delta found *)
						dr.eof := TRUE; RETURN;
					ELSE
						(* other tag, get next one *)
						Files.ReadNum(dr, num);
						df.Set(dr, dr.file.Pos(dr)+num);
				END;
			END;
		END;
	END;
END GetDelta;

(** set log data for a version *)
PROCEDURE SetLog*(name: TFileName; n: INTEGER; log: TLog);

VAR
	nrOfDeltas: INTEGER;
	fPos: LONGINT;
	dFileName: TFileName;
	oldLog: TLog;
	df: Files.File;
	dr: Files.Rider;
	bytes: POINTER TO ARRAY OF CHAR;

BEGIN
	NameToDelta(name, dFileName);
	df := Files.Old(dFileName);
	IF df=NIL THEN RETURN; END;
	df.Set(dr, 0);
	Files.ReadInt(dr, nrOfDeltas);
	IF n > nrOfDeltas THEN RETURN; END;
	Files.ReadLInt(dr, fPos);
	REPEAT
		NEW(bytes, SIZEOF(TLog));
		dr.file.ReadBytes(dr, bytes^, 0, SIZEOF(TLog));
		SYSTEM.MOVE(ADDRESSOF(bytes^), ADDRESSOF(oldLog), SIZEOF(TLog));
		IF oldLog.versionID=n THEN
			df.Set(dr, dr.file.Pos(dr)-SIZEOF(TLog));
			SYSTEM.MOVE(ADDRESSOF(log), ADDRESSOF(bytes^), SIZEOF(TLog));
			dr.file.WriteBytes(dr, bytes^, 0, SIZEOF(TLog));
		END;
		IF oldLog.lenOfDelta > 0 THEN
			df.Set(dr, dr.file.Pos(dr)+oldLog.lenOfDelta);
		END;
	UNTIL oldLog.versionID=n;
	Files.Register(df);
END SetLog;

(** not yet implemented *)
PROCEDURE GetDeltaList*(name: TFileName; VAR list: TDList): INTEGER;

VAR
	log: TLog;
	i: INTEGER;

BEGIN
	i := 1;
	GetLog(name, i, log);
	WHILE log.versionID # -1 DO
		COPY(log.logText, list[i-1]);
		INC(i);
		GetLog(name, i, log);
	END;
	RETURN i-1;
END GetDeltaList;

(* write: tag, its data length, its data *)
PROCEDURE WriteTag(VAR rdr: Files.Rider;
	tag: CHAR; len: LONGINT; VAR data: ARRAY OF CHAR);
BEGIN
	rdr.file.Write(rdr, tag);
	Files.WriteNum(rdr, len);
	rdr.file.WriteBytes(rdr, data, 0, len);
END WriteTag;

(** DeltaV.Create: Create a new version of <name> in <history path><name>.VCS. Also for initial version..*)
PROCEDURE Create*(historyName, name: TFileName; log: TLog; flags: SET): LONGINT;
BEGIN
	RETURN newVersion(historyName, name, log, flags)
END Create;

(** Create a new version of <name> in <name>.VCS. Also for initial version.
Old variant without an explicit history path.*)
PROCEDURE NewVersion*(name: TFileName; log: TLog; flags: SET): LONGINT;
BEGIN
	RETURN newVersion(name, name, log, flags)
END NewVersion;

PROCEDURE newVersion(historyName, name: TFileName; log: TLog; flags: SET): LONGINT;
VAR
	i: LONGINT;
	ch: CHAR;
	tmpDFileName, dFileName, dFileNameBak: TFileName;
	old, new: TData;
	lenNew, oldDiffStart: LONGINT;
	odf, ndf, f, diff: Files.File; (* old/new delta file *)
	odfRdr, ndfRdr, fRdr, diffRdr: Files.Rider;
	msg: ARRAY 256 OF CHAR;
BEGIN
	(* Set temporary, history and history backup filenames. *)
	tmpDFileName := TmpDFile;
	(* get file for new version *)
	(** )Out.Enter; Out.String("VCSBase.Create: name"); Out.String(name); Out.Exit;( **)
	f := Files.Old(name);
	IF f # NIL THEN
	f.Set(fRdr, 0);
		lenNew := f.Length();
		NEW(new, lenNew);
		(* read new file version in buffer new *)
		fRdr.file.ReadBytes(fRdr, new^, 0, lenNew);
	ELSE
		errMsg := " file not found "; RETURN -1;
	END;
	diff := Files.New("");
	diff.Set(diffRdr, 0);
	(* open old history file *)
	NameToDelta(historyName, dFileName);
	NameToBak(dFileName, dFileNameBak);
	(**)Out.Enter; Out.String("VCSBase.Create: "); Out.String(name); Out.Char(" "); Out.String(dFileName); Out.Exit;(**)
	odf := Files.Old(dFileName);
	(* write new delta file header *)
	ndf := Files.New(TmpDFile);
	ndf.Set(ndfRdr, 0);
	(* write format string *)
	ndfRdr.file.WriteBytes(ndfRdr, formatStr, 0, FormatLen);
	(* write flags, only one flag for makro expansion for now *)
	Files.WriteSet(ndfRdr, flags);
	(* write new text *)
	WriteTag(ndfRdr, TextTag, lenNew, new^);
	(* create new diff *)
	IF odf # NIL THEN
		log.versionID :=  GetNewestVersion(odfRdr, odf);
		INC(log.versionID);
		log.lenOfOld := GetTextLen(odfRdr, odf);
		oldDiffStart := odfRdr.file.Pos(odfRdr) + log.lenOfOld;
	ELSE (* first version *)
		log.versionID := 1;
		log.lenOfOld := 0;
	END;
	(* collect the whole diff info in a temporary file: version, ... , delta *)
	Files.WriteNum(diffRdr, log.lenOfOld);
	diffRdr.file.Write(diffRdr, VersionTag); Files.WriteNum(diffRdr, log.versionID);
	IF log.date = "" THEN DateTime(log.date); END;
	WriteTag(diffRdr, DateTag, Strings.Length(log.date)+1, log.date);
	WriteTag(diffRdr, AuthorTag, Strings.Length(log.author)+1, log.author);
	WriteTag(diffRdr, LogTextTag,Strings.Length(log.logText)+1,log.logText);
	IF odf # NIL THEN
		(* create new delta *)
		NEW(old, log.lenOfOld);
		odfRdr.file.ReadBytes(odfRdr, old^, 0, log.lenOfOld);
		CreateDelta(old, new, diffRdr, log.lenOfOld, lenNew);
	END;
	(* write diff *)
	ndfRdr.file.Write(ndfRdr, DiffTag);
	Files.WriteNum(ndfRdr, diff.Length());
	diff.Set(diffRdr, 0);
	FOR i := 0 TO diff.Length() - 1 DO
		diffRdr.file.Read(diffRdr, ch); ndfRdr.file.Write(ndfRdr, ch);
	END;
	IF odf # NIL THEN
		(* copy old diffs *)
		odf.Set(odfRdr, oldDiffStart);
		FOR i := 0 TO odf.Length() - 1 - oldDiffStart DO
			odfRdr.file.Read(odfRdr, ch); ndfRdr.file.Write(ndfRdr, ch);
		END;
	END;
	Files.Register(ndf);
	IF odf # NIL THEN
		(* HACK: Backup old VCS file and primary backup. Doing a Delete dFileNameBak seems not to work if
			immediately followed by a rename on a FAT partition. *)
		Files.Delete(dFileNameBak, res);
		Files.Rename(dFileName, dFileNameBak, res);
		IF res # 0 THEN
			msg := "VCSBase: "; Strings.Append(msg, dFileName); Strings.Append(msg, " => ");
			Strings.Append(msg, dFileNameBak); Strings.Append(msg, " = ");
			Out.Enter; Out.String(msg); Out.Int(res, 4); Out.Exit;
		END;
	END;
	Files.Rename(tmpDFileName, dFileName, res);
	IF res # 0 THEN
		errMsg := "VCSBase.Create: 'Error on Rename' "; Strings.Append(errMsg, TmpDFile);
		Strings.Append(errMsg, " to ");  Strings.Append(errMsg, dFileName);
		log.versionID := 0;
	END;
	RETURN log.versionID;
END newVersion;

(** Get a version from <name>.VCS and save it as <newFileName>.
DeltaV.Select: can be used because the complete paths are already given for source and sink.
*)
PROCEDURE View*(name: TFileName; n: LONGINT; newFileName: TFileName): LONGINT;
VAR
	version, res: LONGINT;
	ok: BOOLEAN;
	dFileName: TFileName;
	old, new: TData;
	log: TLog;
	lenOld, lenNew: LONGINT;
	df, f: Files.File;
	dr, r: Files.Rider;
BEGIN
	(** ) Out.String("VCSBase.View: "); Out.String(name); Out.Char(' '); Out.String(newFileName); Out.Int(n, 3); Out.Ln; ( **)
	NameToDelta(name, dFileName);
	df := Files.Old(dFileName);
	IF df=NIL THEN errMsg := " file not found "; RETURN -1; END;
	version := GetNewestVersion(dr, df);
	IF n > version THEN
		errMsg := " not so many versions "; RETURN -1;
	END;
	(* read newest version of text in buffer new *)
	lenNew := GetTextLen(dr,df);
	NEW(new, lenNew);
	dr.file.ReadBytes(dr, new^, 0, lenNew);
	WHILE version > n DO
		(* apply deltas until wanted version is reached *)
		GetLog(name, version, log);
(**
		Out.String("Extracting Version "); Out.Int(log.versionID, 2); Out.Ln;
**)
		GetDelta(name, version, df, dr); (* delta to create version-1 *)
		(* create previous version in buffer old *)
		lenOld := log.lenOfOld;
		NEW(old, lenOld);
		ApplyDelta(old, new, dr);
		(* move old to new for next iteration *)
		lenNew := lenOld;
		new := old;
		DEC(version);
	END;
	(* write version to versioned file *)
	(** ) Out.Enter; Out.String("New"); Out.Exit; ( **)
	res := makeDirs(newFileName);
	IF res = 0 THEN
		f := Files.New(newFileName);
		IF f = NIL THEN
			errMsg := " couldn't create new file "; Strings.Append(errMsg, newFileName);
			RETURN -1;
		END;
	ELSE
		errMsg := " couldn't create directories for "; Strings.Append(errMsg, newFileName);
		RETURN res;
	END;
	(** ) Out.Enter; Out.String("Set"); Out.Exit; ( **)
	f.Set(r, 0);
	(** ) Out.Enter; Out.String("Write"); Out.Exit; ( **)
	r.file.WriteBytes(r, new^, 0, lenNew);
	(** ) Out.Enter; Out.String("Register"); Out.Exit; ( **)
	Files.Register(f);
	(** ) Out.Enter; Out.String("RETURN"); Out.Exit; ( **)
	RETURN version;
END View;

(** remove versions newer than <n> and create new working file if it doesn't exist *)
PROCEDURE Extract*(name: TFileName; n: LONGINT): LONGINT;

VAR
	version: LONGINT;
	ok: BOOLEAN;
	tmpDFileName, dFileName, dFileNameBak: TFileName;
	old, new: TData;
	log: TLog;
	lenOld, lenNew, lenDelta, fPos: LONGINT;
	tdf, df, f: Files.File;
	tdr, dr, r, deltaRdr: Files.Rider;
	i: LONGINT; ch: CHAR;
	flags: SET;
BEGIN
	tmpDFileName := TmpDFile;
	f := Files.Old(name);
	IF f #NIL THEN
		errMsg := " don't want to overwrite working file ";
		RETURN -1;
	END;
	df := Files.Old(dFileName);
	IF df=NIL THEN
		errMsg := " delta file not found ";
		RETURN -1;
	END;
	version := GetNewestVersion(dr, df);
	IF n > version THEN
		errMsg := " not so many versions "; RETURN -1;
	ELSIF n = version THEN
		errMsg := " is newest version "; RETURN -1;
	END;
	(* read newest version of text in buffer new *)
	lenNew := GetTextLen(dr,df);
	NEW(new, lenNew);
	dr.file.ReadBytes(dr, new^, 0, lenNew);
	WHILE version>n DO
		GetLog(name, version, log);
(**
		Out.String("Extracting Version "); Out.Int(log.versionID, 2); Out.Ln;
**)
		GetDelta(name, version, df, deltaRdr); (* delta to create version-1 *)
		lenOld := log.lenOfOld;
		NEW(old, lenOld);
		ApplyDelta(old, new, deltaRdr);
		(* move old to new for next iteration *)
		lenNew := lenOld;
		new := old;
		DEC(version);
	END;
	(* write newest surviving text  to working file *)
	f := Files.New(name);
	f.Set(r, 0);
	r.file.WriteBytes(r, new^, 0, lenNew);
	Files.Register(f);
	(* new delta file *)
	tdf := Files.New(TmpDFile);
	tdf.Set(tdr, 0);
	(* write format string *)
	tdr.file.WriteBytes(tdr, formatStr, 0, FormatLen);
	(* write flags, empty for now *)
	df.Set(dr, FormatLen);
	Files.ReadSet(dr, flags); Files.WriteSet(tdr, flags);
	(* write newest surviving text to delta file*)
	WriteTag(tdr, TextTag, lenNew, new^);

	(* get valid logs and deltas to new delta file *)
	df.Set(dr, GetDiffPos(dr, df, n));
	LOOP
		dr.file.Read(dr, ch);
		IF dr.eof THEN EXIT; END;
		tdr.file.Write(tdr, ch);
	END;
	Files.Register(tdf);

	(*       cleanup             *)
	(* backup old VCS file and primary backup file. *)
	Files.Delete(dFileNameBak, res);
	Files.Rename(dFileName, dFileNameBak, res);
	(* new delta file *)
	Files.Rename(tmpDFileName, dFileName, res);
	new := NIL; old := NIL;
	RETURN version;
END Extract;

BEGIN
	formatStr := FormatName;
END OdVCSBase.
