MODULE IsoImages; (** AUTHOR "Roger Keller"; PURPOSE "Create bootable ISO image"; *)

IMPORT SYSTEM, Commands, Streams, Files, Dates, Strings;

CONST
	Ok* = 0;
	FileNotFound* = 1;			(* Input disk image file not found *)
	CouldNotCreateFile* = 2;	(* Creation of ISO image file failed *)

	MaxPathLen = 256;
	ISO9660Id = "CD001";
	CDSectorSize = 2048; (* size of a sector of data on a CD *)
	NumSystemSectors = 16; (* number of sectors at begin of CD which are unused *)

	ElToritoSysId = "EL TORITO SPECIFICATION"; (* boot system id for the el torito standard *)
	Platform80x86 = 0X;
	PlatformPowerPC = 0X;
	PlatformMac = 0X;

	Bootable = 88X;
	NotBootable = 00X;

	EmulationNone = 0X;
	Emulation12Floppy = 1X;
	Emulation144Floppy = 2X;
	Emulation288Floppy = 3X;
	EmulationHDD = 4X;

	BBVolumeId = "BLUEBOTTLE";
	BBPublisher = "ETH_ZURICH";

TYPE
	BootCatalogEntry = ARRAY 32 OF CHAR;
	BCValidationEntry = RECORD
		HeaderId: CHAR;
		PlatformId: CHAR;
		Reserved: INTEGER;
		IdString: ARRAY 24 OF CHAR;
		Checksum: INTEGER;
		KeyBytes: ARRAY 2 OF CHAR;
	END;
	BCInitialDefaultEntry = RECORD
		BootIndicator: CHAR;
		BootMediaType: CHAR;
		LoadSegment: INTEGER;
		SystemType: CHAR;
		Unused1: CHAR;
		SectorCount: INTEGER;
		LoadRBA: LONGINT;
		Unused2: ARRAY 20 OF CHAR;
	END;

PROCEDURE WriteImage(w: Streams.Writer; r: Streams.Reader; imageSize: LONGINT);
VAR read, padLen: LONGINT; buf: ARRAY CDSectorSize OF CHAR;
BEGIN
	padLen := CDSectorSize - (imageSize MOD CDSectorSize);

	r.Bytes(buf, 0, CDSectorSize, read);
	WHILE (read > 0) DO
		w.Bytes(buf, 0, read);
		r.Bytes(buf, 0, CDSectorSize, read);
	END;
	WriteByteRep(w, 0X, padLen);
END WriteImage;

PROCEDURE WriteElToritoDescriptor(w: Streams.Writer);
BEGIN
	w.Char(0X); (* boot record indicator *)
	w.String(ISO9660Id); (* standard identifier for ISO 9660 *)
	w.Char(1X); (* descriptor version; 1 for el torito 1.0 specification from january 25, 1995 *)
	WriteStringWithPadding(w, ElToritoSysId, 0X, 32); (* boot system id *)
	WriteByteRep(w, 0X, 32); (* unused *)
	w.RawLInt(NumSystemSectors + 1 + 1 + 1); (* absolute pointer to sector (LBA) of boot catalog *)
	WriteByteRep(w, 0X, 1973); (* unused *)
END WriteElToritoDescriptor;

PROCEDURE WriteBootCatalog(w: Streams.Writer);
VAR entry: BCValidationEntry; entry2: BCInitialDefaultEntry; len: LONGINT;
BEGIN
	len := 0;

	(* validation entry *)
	entry.HeaderId := 1X; (* header id *)
	entry.PlatformId := Platform80x86; (* platform id *)
	entry.Reserved := 0; (* reserved *)
	entry.IdString := BBVolumeId;
	entry.Checksum := 0;(* init checksum to zero *)
	entry.KeyBytes[0] := 55X; entry.KeyBytes[1] := 0AAX; (* key bytes *)
	entry.Checksum := CalcChecksum16(SYSTEM.VAL(BootCatalogEntry, entry)); (* update the checksum *)
	w.Bytes(SYSTEM.VAL(BootCatalogEntry, entry), 0, 32);
	INC(len, 32);

	(* initial / default entry *)
	entry2.BootIndicator := Bootable;
	entry2.BootMediaType := Emulation144Floppy;
	entry2.LoadSegment := 0; (* use default load segment which is 7C0H *)
	entry2.SystemType := 0X;
	entry2.Unused1 := 0X;
	entry2.SectorCount := 1;
	entry2.LoadRBA := NumSystemSectors + 7;
	w.Bytes(SYSTEM.VAL(BootCatalogEntry, entry2), 0, 32);
	INC(len, 32);

	(* pad rest of sector with zeros *)
	WriteByteRep(w, 0X, CDSectorSize - len);
END WriteBootCatalog;

PROCEDURE WriteIsoFSData(w: Streams.Writer);
VAR now: Dates.DateTime;
BEGIN
	now := Dates.Now();

	w.Char(22X); (* length of directory record *)
	w.Char(0X); (* extended attribute record length *)
	w.RawLInt(NumSystemSectors + 4); w.Net32(NumSystemSectors + 4); (* location of extent *)
	w.RawLInt(CDSectorSize); w.Net32(CDSectorSize); (* data length *)
	WriteByteRep(w, 0X, 7);
	(*w.RawSInt(SHORT(SHORT(now.Year - 1900)));
	w.RawSInt(SHORT(SHORT(now.Month + 1)));
	w.RawSInt(SHORT(SHORT(now.Day)));
	w.RawSInt(SHORT(SHORT(now.Hour)));
	w.RawSInt(SHORT(SHORT(now.Minute)));
	w.RawSInt(SHORT(SHORT(now.Second)));
	w.Char(0X);*)
	w.Char(2X); (* file flags: this is a directory *)
	w.Char(0X); (* file unit size *)
	w.Char(0X); (* interleave gap size *)
	w.RawInt(1); w.Net16(1); (* volume sequence number *)
	w.Char(1X); (* length of file identifier *)
	w.Char(0X); (* file id: 0X indicates first entry of directory *)

	w.Char(22X); (* length of directory record *)
	w.Char(0X); (* extended attribute record length *)
	w.RawLInt(NumSystemSectors + 4); w.Net32(NumSystemSectors + 4); (* location of extent *)
	w.RawLInt(CDSectorSize); w.Net32(CDSectorSize); (* data length *)
	WriteByteRep(w, 0X, 7);
	w.Char(2X); (* file flags: this is a directory *)
	w.Char(0X); (* file unit size *)
	w.Char(0X); (* interleave gap size *)
	w.RawInt(1); w.Net16(1); (* volume sequence number *)
	w.Char(1X); (* length of file identifier *)
	w.Char(1X); (* file id: 0X indicates first entry of directory *)

	WriteByteRep(w, 0X, CDSectorSize - (2 * 22H));

	WriteTypeLPathTable(w);
	WriteTypeMPathTable(w);
END WriteIsoFSData;

PROCEDURE WriteTypeLPathTable(w: Streams.Writer);
BEGIN
	w.Char(1X); (* length of directory identifier *)
	w.Char(0X); (* extended attribute record length *)
	w.RawLInt(NumSystemSectors + 4); (* location of extent *)
	w.RawInt(1); (* parent directory number *)
	w.Char(0X); (* directory identifier *)

	WriteByteRep(w, 0X, CDSectorSize - 9);
END WriteTypeLPathTable;

PROCEDURE WriteTypeMPathTable(w: Streams.Writer);
BEGIN
	w.Char(1X); (* length of directory identifier *)
	w.Char(0X); (* extended attribute record length *)
	w.Net32(NumSystemSectors + 4); (* location of extent *)
	w.Net16(1); (* parent directory number *)
	w.Char(0X); (* directory identifier *)

	WriteByteRep(w, 0X, CDSectorSize - 9);
END WriteTypeMPathTable;

PROCEDURE WritePrimaryVolumeDescriptor(w: Streams.Writer; isoImageSectorCount: LONGINT);
VAR now: Dates.DateTime; dtBuf: ARRAY 20 OF CHAR;
BEGIN
	now := Dates.Now();
	Strings.FormatDateTime("yyyymmddhhnnss00", now, dtBuf);

	w.Char(1X); (* descriptor type *)
	w.String(ISO9660Id); (* standard identifier *)
	w.Char(1X); (* volume descriptor version *)
	w.Char(0X); (* unused *)
	WriteByteRep(w, ' ', 32); (* system identifier *)
	WriteStringWithPadding(w, BBVolumeId, ' ', 32); (* volume identifier *)
	WriteByteRep(w, 0X, 8); (* unused *)
	WriteBothByteOrder32(w, isoImageSectorCount); (* volume space size *)
	WriteByteRep(w, 0X, 32); (* unused *)
	WriteBothByteOrder16(w, 1); (* volume set size *)
	WriteBothByteOrder16(w, 1); (* volume sequence number *)
	WriteBothByteOrder16(w, CDSectorSize); (* logical block size *)
	WriteBothByteOrder32(w, 10); (* path table size *)
	w.RawLInt(NumSystemSectors + 1 + 1 + 1 + 1 + 1); (* location (LBA) of occurrence of type L path table *)
	w.RawLInt(0); (* location (LBA) of optional occurrence of type L path table *)
	w.Net32(NumSystemSectors + 1 + 1 + 1 + 1 + 1 + 1); (* location (LBA) of occurrence of type M path table *)
	w.RawLInt(0); (* location (LBA) of optional occurrence of type M path table *)
	WriteDirectoryRecord(w); (* directory record for root directory *)
	WriteByteRep(w, ' ', 128); (* volume set id *)
	WriteStringWithPadding(w, BBPublisher, ' ', 128);
	WriteByteRep(w, ' ', 128 + 128); (* data preparer id, application id *)
	WriteByteRep(w, ' ', 37 + 37 + 37); (* copyright file id, abstract file id, bibliography file id *)
	w.String(dtBuf); w.Char(0X); (* volume creation date / time; time offset is set to zero *)
	w.String(dtBuf); w.Char(0X); (* volume modification date / time; time offset is set to zero *)
	dtBuf := "0000000000000000";
	w.String(dtBuf); w.Char(0X); (* volume expiration date / time; time offset is set to zero *)
	w.String(dtBuf); w.Char(0X); (* volume effective date / time; time offset is set to zero *)
	w.Char(1X); (* file structure version: 1 stands for ISO 9660 *)
	w.Char(0X); (* reserved *)
	WriteByteRep(w, 0X, 512 + 653); (* application use (512 bytes) and reserved (653 bytes) *)
END WritePrimaryVolumeDescriptor;

PROCEDURE WriteSetTerminatorDescriptor(w: Streams.Writer);
BEGIN
	w.Char(0FFX); (* descriptor type: set terminator *)
	w.String(ISO9660Id); (* standard identifier *)
	w.Char(1X); (* volume descriptor version *)
	WriteByteRep(w, 0X, 2041); (* reserved *)
END WriteSetTerminatorDescriptor;

PROCEDURE WriteDirectoryRecord(w: Streams.Writer);
VAR now: Dates.DateTime;
BEGIN
	now := Dates.Now();

	w.RawSInt(22H); (* length of this directory record *)
	w.Char(0X); (* extended attribute record length *)
	WriteBothByteOrder32(w, NumSystemSectors + 1 + 1 + 1 + 1); (* location (LBA) of extent *)
	WriteBothByteOrder32(w, CDSectorSize); (* data length *)

	(* recording date and time, one byte per field; year, month, day, hour, minute, second, time zone offset *)
	w.RawSInt(SHORT(SHORT(now.year - 1900)));
	w.RawSInt(SHORT(SHORT(now.month + 1)));
	w.RawSInt(SHORT(SHORT(now.day)));
	w.RawSInt(SHORT(SHORT(now.hour)));
	w.RawSInt(SHORT(SHORT(now.minute)));
	w.RawSInt(SHORT(SHORT(now.second)));
	w.Char(0X); (* use zero time offset *)
	w.Char(2X); (* file flags: this is a directory *)
	w.Char(0X); (* file unit size *)
	w.Char(0X); (* interleave gap size *)
	WriteBothByteOrder16(w, 1); (* volume sequence number *)
	w.Char(1X); (* length of file identifier *)
	w.Char(0X); (* self indicator *)
END WriteDirectoryRecord;

PROCEDURE CalcIsoImageSectorCount(inputImageSize: LONGINT): LONGINT;
VAR imageSectors: LONGINT;
BEGIN
	imageSectors := inputImageSize DIV CDSectorSize;
	IF (inputImageSize MOD CDSectorSize # 0) THEN
		INC(imageSectors);
	END;

	RETURN NumSystemSectors +
		1 + (* primary volume descriptor *)
		1 + (* el torito boot volume descriptor *)
		1 + (* volume descriptor set terminator *)
		1 + (* boot catalog *)
		3 + (* root directory descriptor, type L path table, type M path table *)
		imageSectors;
END CalcIsoImageSectorCount;

PROCEDURE WriteBothByteOrder32(w: Streams.Writer; x: LONGINT);
BEGIN
	w.RawLInt(x);
	w.Net32(x);
END WriteBothByteOrder32;

PROCEDURE WriteBothByteOrder16(w: Streams.Writer; x:INTEGER);
BEGIN
	w.RawInt(x);
	w.Net16(x);
END WriteBothByteOrder16;

PROCEDURE WriteByteRep(w: Streams.Writer; b: CHAR; n: LONGINT);
VAR i: LONGINT;
BEGIN
	FOR i := 1 TO n DO
		w.Char(b);
	END;
END WriteByteRep;

PROCEDURE WriteStringWithPadding(w: Streams.Writer; CONST str: ARRAY OF CHAR; padChar: CHAR; len: LONGINT);
VAR strLen: LONGINT;
BEGIN
	strLen := LEN(str) - 1; (* we don't write the terminating 0X *)
	w.String(str);
	WriteByteRep(w, padChar, len - strLen);
END WriteStringWithPadding;

PROCEDURE WriteEmptySectors(w: Streams.Writer; n: LONGINT);
VAR i, s, nLongs: LONGINT;
BEGIN
	nLongs := CDSectorSize DIV 4; (* number of 32bits per sector *)
	FOR s := 1 TO n DO
		FOR i := 1 TO nLongs DO
			w.RawLInt(0);
		END;
	END;
END WriteEmptySectors;

(*
PROCEDURE WriteStringWithPaddingToBuffer(buf: ARRAY OF CHAR; offset: LONGINT; str: ARRAY OF CHAR;
	padChar: CHAR; len: LONGINT);
VAR i, strLen: LONGINT;
BEGIN
	strLen := LEN(str) - 1; (* we don't write the terminating 0X *)
	SYSTEM.MOVE(ADDRESSOF(str), ADDRESSOF(buf) + offset, strLen);
	FOR i := 0 TO len - strLen - 1 DO
		buf[offset + i] := 0X;
	END;
END WriteStringWithPaddingToBuffer;
*)

PROCEDURE CalcChecksum16(CONST buf: ARRAY OF CHAR): INTEGER;
VAR checksum, i, numWords: LONGINT;
BEGIN
	checksum := 0;
	numWords := LEN(buf) DIV 2;
	FOR i := 0 TO numWords - 1 DO
		checksum := (checksum + SYSTEM.VAL(INTEGER, buf[i * 2])) MOD 10000H;
	END;
	RETURN SHORT(10000H - checksum);
END CalcChecksum16;

PROCEDURE MakeImage*(CONST input, output: ARRAY OF CHAR; VAR imageSize , res : LONGINT);
VAR fOut, fIn: Files.File; out: Files.Writer; in: Files.Reader; numSectors: LONGINT;
BEGIN
	res := Ok;

	fIn := Files.Old(input);
	IF (fIn = NIL) THEN
		res := FileNotFound;
		RETURN;
	END;

	fOut := Files.New(output);
	IF (fOut = NIL) THEN
		res := CouldNotCreateFile;
		RETURN;
	END;

	numSectors := CalcIsoImageSectorCount(fIn.Length());

	Files.Register(fOut);
	Files.OpenWriter(out, fOut, 0);

	WriteEmptySectors(out, NumSystemSectors);
	WritePrimaryVolumeDescriptor(out, numSectors);
	WriteElToritoDescriptor(out);
	WriteSetTerminatorDescriptor(out);
	WriteBootCatalog(out);
	WriteIsoFSData(out);
	Files.OpenReader(in, fIn, 0); (* open a reader on the raw input image *)
	WriteImage(out, in, fIn.Length()); (* write the raw image *)

	out.Update;
	fOut.Update;
	imageSize := fOut.Length();
END MakeImage;

PROCEDURE Make*(context : Commands.Context);
VAR
	imageSource, isoDest: ARRAY MaxPathLen OF CHAR;
	imageSize, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(isoDest);
	context.arg.SkipWhitespace; context.arg.String(imageSource);

	context.out.String("Making ISO-9660 Bootable Image"); context.out.Ln;

	context.out.String("Input image is ");
	context.out.String(imageSource); context.out.Ln;
	context.out.String("Writing Bootable ISO Image to ");
	context.out.String(isoDest); context.out.String(" ... ");

	MakeImage(imageSource, isoDest, imageSize, res);

	IF (res = Ok) THEN
		context.out.String("done."); context.out.Ln;
		context.out.String("Bootable ISO Image successfully written (Size: ");
		context.out.Int(imageSize DIV 1024, 0); context.out.String(" KB)"); context.out.Ln;
	ELSIF (res = FileNotFound) THEN
		context.error.String("Disk image file "); context.error.String(imageSource);
		context.error.String(" not found."); context.error.Ln;
	ELSIF (res = CouldNotCreateFile) THEN
		context.error.String("Could not create image file "); context.error.String(isoDest);
		context.error.String("."); context.error.Ln;
	ELSE
		context.error.String("Error, res: "); context.error.Int(res, 0); context.error.Ln;
	END;
END Make;

END IsoImages.


(*
IsoImages.Make AosCDPrivate.iso AosCDPrivate.Dsk ~
SystemTools.Free IsoImages ~
*)