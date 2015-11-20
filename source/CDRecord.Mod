MODULE CDRecord;

(*
References:
	Mt. Fuji Commands for Multimedia Devices (SFF8090i v6)
	ECMA-130 Data interchange on read-only 120 mm optical data disks
*)

IMPORT SYSTEM, Kernel, ATADisks, Lib := CDRecordLib, Utils := CDRecordUtils, Disks, Plugins, KernelLog, Files, Strings, Objects, MakeIsoImages;

CONST
	ResOk=0; ResErr=1;
	Debug = FALSE;
	UseDma = TRUE;
	UseBufferedReader = TRUE;
	MaxRecorders* = 2;
	BufferSize = 16*1024*1024;

	RawSectorSize = 2352;
	BlockSize = 2048;
	DataSectorSize = 2048; (* Yellow Book Mode 1 *)
	AudioSectorSize = RawSectorSize;
	TrackLimit = 99;
	TransferSize = 200; (* in sectors *)
	MinTrackSize = 300; (* in sectors *)
	DefaultPregap = 150; (* in sectors *)
	InitialPregap = 150; (* initial pregap which is not accessible with logical addressing *)

	(* incremental writing *)
	NoRunInBlocks = 2;
	NoRunOutBlocks = 1;
	NoLinkBlocks = 4;

	FifoSize = 16*1024*1024;
	ListCurrentMaxSpeeds = FALSE; (* not recommended *)
	NotificationPeriod = 1000; (* client is informed every NotificationPeriod about status *)

	SingleSpeed* = 176; (* kByte/s *)

	(* Burn Settings *)
	TrackAtOnce* = Lib.WTTao; SessionAtOnce* = Lib.WTSao;

	tnoLeadout* = 0AAH; (* track number of lead out*)
	(* Track Types *)
	AudioTrack* = 0; DataTrack* = 1;

	BestSpeed = 0FFFFH;
	(* track properties *)

	(* media functions *)
	MFCdRw* = 0; MFCdr* = 1; MFSao* = 2; MFBufe* = 3; MFMultisession* = 4; MFCaddy* = 5; MFTray* = 6; MFPopup* = 7;

	(* Errors *)
	ErrFileNotFound* = 3000;
	ErrTrackSizeExceeded* = 3001;
	ErrNotEnoughFreeSpace* = 3003;
	ErrNoMediumPresent* = 3004;
	ErrDriveNotReady* = 3005;
	ErrNoIsoFile* = 3006;
	ErrWrongWaveFile* = 3007; (* not an appropriate wav file (must be 16 bit encoded, 44.1kHz and 2 channel) *)
	ErrCalibrationFailed* = 3008;
	ErrDiscNotEmpty* = 3009;
	ErrCDRWNotEmpty* = 3010;
	ErrDiscNotAppendable*=  3011;
	ErrCDRWNotAppendable* = 3012;
	ErrSendingCueSheet* = 3013;
	ErrIncompatibleMedium* = 3014;
	ErrWriting* = 3015;
	ErrVerificationFailed* = 3016;

	(* record operations *)
	Writing* = 0; ClosingTrack* = 1; ClosingSession* = 2; SendingCueSheet* = 3; Calibrating* = 4; FillingFifo* = 5; FlushingCache* = 6; Verifying* = 7;
TYPE
	Buffer = POINTER TO ARRAY OF CHAR;

	Capabilities* = RECORD
		writeSpeeds* : POINTER TO ARRAY OF LONGINT;
		mediaFunc* : SET;
	END;

	WriteParams = RECORD
		writeType, multisession, trackMode, DBType: LONGINT;
		testWrite, bufe: BOOLEAN;
	END;

	RecordingStatus* = OBJECT(Utils.Status)
	VAR
		currentSpeed*: LONGINT; (* raw speed *)
		freeBuffer*, bufferSize*, operation*, secsTransferred*, secsVerified*: LONGINT;
		empty*: LONGINT; (* number of times sw buffer was empty *)
	END RecordingStatus;

	BurnSettings* = RECORD
		writeType*: LONGINT;
		verify*, bufe*, multisession*, append*: BOOLEAN;
		speed*: LONGINT;
	END;

	Disc* = OBJECT
		VAR
			erasable*: BOOLEAN;
			status*, statusLastSession*, nofSessions*: LONGINT;
			usedBlocks*, freeBlocks*: LONGINT;
			type*: LONGINT;
			latestLeadOut*: MSF;
	END Disc;

	(* extended disc information for CDR/CDRW media*)
	DiscEx* = OBJECT(Disc)
		VAR
			refSpeed*: LONGINT; (* valid only for CDRW *)
			minSpeed*, maxSpeed*: LONGINT;
			subtype*: LONGINT;
	END DiscEx;

	Track = OBJECT
		VAR
			tno, padding, nofsecs, startSec, secsize, type: LONGINT;
			bytespt: LONGINT; (* bytes per transfer *)
			secspt: LONGINT; (* secs per transfer *)
			pregap: LONGINT; (* pregap in sectors *)
			size: LONGINT; (* size of track in bytes *)
			permission: BOOLEAN;

		PROCEDURE &New*(tno, trackType: LONGINT; permitCopy: BOOLEAN);
		BEGIN
			SELF.tno := tno;
			SELF.permission := permitCopy;
			SELF.type := trackType;
			IF type = AudioTrack THEN
				secsize := AudioSectorSize;
			ELSE
				secsize := DataSectorSize;
			END;
			secspt := TransferSize;
			bytespt := secsize*secspt;
		END New;
	END Track;

	InformationTrack* = OBJECT(Track)
		VAR
			file-: Files.File;

		PROCEDURE &NewInfTrack*(tno, trackType: LONGINT; permitCopy: BOOLEAN; file: Files.File);
		BEGIN
			New(tno, trackType, permitCopy);
			SELF.file := file;
			pregap := DefaultPregap;
			InitTrack();
		END NewInfTrack;

		PROCEDURE InitTrack;
		BEGIN
			padding := 0;
			nofsecs := file.Length() DIV secsize;
			IF file.Length() MOD secsize # 0 THEN
				INC(nofsecs);
				padding := secsize - (file.Length() MOD secsize);
			END;
			IF nofsecs < MinTrackSize THEN
				INC(padding, (MinTrackSize - nofsecs) * secsize);
				nofsecs := MinTrackSize;
			END;
			size := nofsecs*secsize;
		END InitTrack;
	END InformationTrack;

	MSF = RECORD
		min, sec, frame: LONGINT;
	END;

	CueSheetEntry = RECORD
			ctladr, tNo, index, dataForm: CHAR;
			scms, min, sec, frame: CHAR;
	END;

	CueSheet = OBJECT
		VAR
			nofEntries, cur: LONGINT;
			adr: ADDRESS;
			buf: POINTER TO ARRAY OF CueSheetEntry;

		PROCEDURE &New*(compilation: Compilation);
		BEGIN
			nofEntries := 2*compilation.nofTracks - 2;
			NEW(buf, nofEntries);
			adr := ADDRESSOF(buf[0]);
			GenerateSheet(compilation.tracks, compilation.nofTracks);
		END New;

		PROCEDURE GenerateSheet(CONST tracks: ARRAY OF Track; nofTracks: LONGINT);
		VAR
			i: LONGINT;
			df: CHAR;
		BEGIN
			FOR i := 0 TO nofTracks - 1 DO
				IF i = 0 THEN (* leadin *)
					Lib.SetField(df, Lib.DFMMask, Lib.DFMOfs, Lib.DFMLeadin);
					AddEntry(tracks[i], 0, df);
				ELSIF i = nofTracks-1 THEN (* leadout *)
					Lib.SetField(df, Lib.DFMMask, Lib.DFMOfs, Lib.DFMLeadout);
					AddEntry(tracks[i], 1, df);
				ELSE
					IF tracks[i].type = AudioTrack THEN
						Lib.SetField(df, Lib.DFMMask, Lib.DFMOfs, Lib.DFMDigitalAudio);
					ELSE
						Lib.SetField(df, Lib.DFMMask, Lib.DFMOfs, Lib.DFMCdRomMode1);
					END;
					(* we always add index 0 even if there is no pregap*)
					AddEntry(tracks[i], 0, df);
					AddEntry(tracks[i], 1, df);
				END;
			END;
		END GenerateSheet;

		PROCEDURE AddEntry(track: Track; index: LONGINT; df: CHAR);
		VAR
			ctladr: CHAR;
			startSec: LONGINT;
			msf: MSF;
			entry: CueSheetEntry;
			nibble: SET; (* q channel nibble *)
		BEGIN
			startSec := track.startSec;
			IF index = 0 THEN
				DEC(startSec, track.pregap);
			END;

			nibble := {};
			IF track.type = DataTrack THEN INCL(nibble, Lib.QCDataTrack) END;
			IF track.permission THEN INCL(nibble, Lib.QCCopyPermitted) END;
			Lib.SetField(ctladr, Lib.CTLMask, Lib.CTLOfs, SYSTEM.VAL(LONGINT, nibble));
			Lib.SetField(ctladr, Lib.ADRMask, Lib.ADROfs, Lib.ADRTno);

			SectorToMsf(startSec, msf);

			entry.ctladr := ctladr;
			entry.tNo := CHR(track.tno);
			entry.index := CHR(index);
			entry.dataForm := df;
			entry.scms := 0X;
			entry.min := CHR(msf.min);
			entry.sec := CHR(msf.sec);
			entry.frame :=CHR(msf.frame);

			buf[cur] := entry;
			INC(cur);
		END AddEntry;

		PROCEDURE Print;
		VAR
			i: LONGINT;
			entry: CueSheetEntry;
		BEGIN
			KernelLog.Ln;
			FOR i := 0 TO nofEntries - 1 DO
				entry := buf[i];
				KernelLog.Int(ORD(entry.ctladr), 5);
				KernelLog.Int(ORD(entry.tNo), 5);
				KernelLog.Int(ORD(entry.index), 5);
				KernelLog.Int(ORD(entry.dataForm), 5);
				KernelLog.Int(ORD(entry.scms), 5);
				KernelLog.Int(ORD(entry.min), 5);
				KernelLog.Int(ORD(entry.sec), 5);
				KernelLog.Int(ORD(entry.frame), 5);
				KernelLog.Ln;
			END;
		END Print;
	END CueSheet;

	Compilation* = OBJECT
	VAR
		nofTracks-, totalSize-: LONGINT;
		tracks-: ARRAY TrackLimit OF Track;

		PROCEDURE &New*;
		BEGIN
			nofTracks := 0;
			totalSize := -InitialPregap; (* 150 sector pregap of first track is not accessible with logical addressing *)
		END New;

		PROCEDURE Finish*;
		VAR
			i: LONGINT;
		BEGIN
			ASSERT(nofTracks >= 1);

			(* leadin *)
			NEW(tracks[0], 0H, tracks[1].type, tracks[1].permission);
			tracks[0].pregap := InitialPregap;
			INC(nofTracks, 1);

			(* leadout *)
			NEW(tracks[nofTracks], tnoLeadout, tracks[nofTracks-1].type, tracks[nofTracks-1].permission);
			INC(nofTracks, 1);
			(* set the start sector for each track *)

			FOR i := 1 TO nofTracks-1 DO
				INC(totalSize, tracks[i].pregap);
				tracks[i].startSec := totalSize;
				INC(totalSize, tracks[i].nofsecs);
			END;
		END Finish;

		(* Returns the number of total sectors *)
		PROCEDURE GetSize*(raw, secs: BOOLEAN): LONGINT;
		VAR
			i, size: LONGINT;
		BEGIN
			size := 0;
			IF raw THEN (* incl lead in  ... *)
				FOR i := 1 TO nofTracks - 1 DO
					IF secs THEN
						INC(size, tracks[i].nofsecs + tracks[i].pregap);
					ELSE
						INC(size, tracks[i].nofsecs * tracks[i].secsize + tracks[i].pregap*tracks[i].secsize);
					END;
				END;
			ELSE
				FOR i := 1 TO nofTracks -2 DO
					IF secs THEN
						INC(size, tracks[i].nofsecs);
					ELSE
						INC(size, tracks[i].nofsecs * tracks[i].secsize);
					END;
				END;
			END;
			RETURN size;
		END GetSize;

		PROCEDURE AddTrack*(filename: Strings.String; trackType : LONGINT; permitCopy: BOOLEAN) : LONGINT;
		VAR
			res: LONGINT;
			track: InformationTrack;
			file: Files.File;
		BEGIN
			IF nofTracks >= TrackLimit THEN
				RETURN ErrTrackSizeExceeded;
			ELSIF FileExists(filename) THEN
				IF trackType = AudioTrack THEN
					IF ~IsWavFile(filename) THEN
						RETURN ErrWrongWaveFile;
					END;
				ELSE
					IF ~IsIsoFile(filename) THEN
						RETURN ErrNoIsoFile;
					END;
				END;
				INC(nofTracks, 1);
				file := Files.Old(filename^);
				NEW(track, nofTracks, trackType, permitCopy, file);
				tracks[nofTracks] := track;
				res := ResOk;
			ELSE
				res := ErrFileNotFound;
			END;
			RETURN ResOk;
		END AddTrack;
	END Compilation;

	CDRecorder* = OBJECT
		VAR
			cap*: Capabilities;
			dev*: ATADisks.DeviceATAPI;
			recStatus*: RecordingStatus;
			onRecordStatusChanged: Utils.StatusProc;
			name*: ARRAY 128 OF CHAR;
			reader: Reader;
			locked*: BOOLEAN;
			dma*: BOOLEAN;
			timer: Kernel.Timer;

		PROCEDURE &New*(VAR dev: ATADisks.DeviceATAPI; cap: Capabilities);
		BEGIN
			SELF.dev := dev;
			dma := ATADisks.DMABit IN SYSTEM.VAL(SET, dev.id.type);
			SELF.cap := cap;
			COPY(dev.desc, name);
			onRecordStatusChanged := NIL;
			NEW(timer);
		END New;

		PROCEDURE UpdateCapacity*;
		VAR
			size, res: LONGINT;
		BEGIN
			dev.GetSize(size, res);
		END UpdateCapacity;

		PROCEDURE GetBufferCapacity(VAR totalCapacity, unusedCapacity: LONGINT): LONGINT;
		VAR
			capacity: Lib.BufferCapacity;
			res: LONGINT;
		BEGIN
			res := Lib.ReadBufferCapacity(dev, FALSE, ADDRESSOF(capacity), SIZEOF(Lib.BufferCapacity));
			IF res = ResOk THEN
				totalCapacity := Utils.ConvertBE32Int(capacity.BufferLength);
				unusedCapacity := Utils.ConvertBE32Int(capacity.BlankLength);
			END;
			RETURN res;
		END GetBufferCapacity;

		PROCEDURE Record*(VAR compilation: Compilation; settings: BurnSettings; onRecordStatusChanged: Utils.StatusProc): LONGINT;
		VAR
			disc: Disc;
			res, i, op, nwa, secs: LONGINT;
			nibble: SET; (* the control nibble of the q channel *)
			params: WriteParams;
			cuesheet: CueSheet;
			track: InformationTrack;
			uReader: UnbufferedReader;
			bufReader: BufferedReader;
		BEGIN {EXCLUSIVE}
			SELF.onRecordStatusChanged := onRecordStatusChanged;
			NEW(recStatus);
			NEW(disc);
			res := GetDiscInfo(disc);
			IF res # ResOk THEN RETURN res END;

			IF settings.append  THEN
				IF (disc.status # Lib.DSEmpty) & (disc.status # Lib.DSAppendable) THEN
					IF disc.erasable THEN
						RETURN ErrCDRWNotAppendable;
					ELSE
						RETURN ErrDiscNotAppendable;
					END;
				END;
			ELSE
				IF (disc.status # Lib.DSEmpty) THEN
					IF  disc.erasable THEN
						RETURN ErrCDRWNotEmpty;
					ELSE
						RETURN ErrDiscNotEmpty;
					END;
				END;
			END;

			IF compilation.GetSize(TRUE, TRUE) > disc.freeBlocks THEN RETURN ErrNotEnoughFreeSpace END;
			Lock();
			IF SetWriteSpeed(settings.speed) # ResOk THEN Abort(); RETURN ResErr END;

			recStatus.operation := Calibrating; StatusChanged();
			IF Lib.SendOPCInformation(dev, TRUE) # ResOk THEN Abort(); RETURN ErrCalibrationFailed END;

			(* IF settings.verify THEN op := ATADisks.WriteAndVerify ELSE op := Disks.Write END; *)
			op := Disks.Write; (* we only verify after having written the whole compilation *)
			InitWriteParams(settings, params);

			IF UseBufferedReader THEN
				NEW(bufReader, compilation, TransferSize*RawSectorSize);
				recStatus.operation := FillingFifo; StatusChanged();
				bufReader.Init();
				reader := bufReader;
			ELSE
				NEW(uReader, compilation, TransferSize*RawSectorSize);
				reader := uReader;
			END;

			IF settings.writeType = SessionAtOnce THEN
				IF SetWriteParams(params, FALSE) # ResOk THEN Abort(); RETURN ResErr END;
				IF Debug THEN res := PrintWriteParams() END;
				NEW(cuesheet, compilation);
				IF Debug THEN cuesheet.Print() END;
				recStatus.operation := SendingCueSheet; StatusChanged();
				IF Lib.SendCueSheet(dev, cuesheet.adr, cuesheet.nofEntries*SIZEOF(CueSheetEntry)) # ResOk THEN
					res := dev.RequestSense(); Abort(); RETURN ErrSendingCueSheet;
				END;
				(* in case of multisession. but most recorder don't support multisession in sao mode anyway *)
				IF Lib.GetNextAddress(dev, nwa) # ResOk THEN RETURN ResErr END;
				(* some drive return wrong start sec for sao if disc is empty *)
				IF nwa <= 0 THEN nwa := -InitialPregap END;
				IF settings.multisession  THEN
					FOR i := 0 TO compilation.nofTracks - 1 DO
						INC(compilation.tracks[i].startSec, nwa + InitialPregap);
					END;
				END;
			END;

			(* Read Capacity returns a capacity of 1 for empty media so we have to set it explicitly*)
			MsfToSector(disc.latestLeadOut, secs);
			dev.SetCapacity(secs);
			EXCL(dev.flags, Disks.ReadOnly);

			FOR i := 1 TO compilation.nofTracks-2 DO
				track := compilation.tracks[i](InformationTrack);
				(* set blockSize *)
				dev.SetBlockSize(track.secsize);

				IF settings.writeType = TrackAtOnce THEN
					nibble := {};
					IF track.type = DataTrack THEN
						INCL(nibble, Lib.QCDataTrack);
						params.DBType := Lib.DBIsoMode1;
					ELSE
						params.DBType := Lib.DBRaw;
					END;
					IF track.permission THEN INCL(nibble, Lib.QCCopyPermitted) END;
					params.trackMode := SYSTEM.VAL(LONGINT, nibble);
					IF (SetWriteParams(params, FALSE) # ResOk) OR (Lib.GetNextAddress(dev, track.startSec) # ResOk) THEN Abort(); RETURN ResErr END;
					IF Debug THEN res := PrintWriteParams() END;
				ELSE
					res := PadTrack(op, track);
					IF res # ResOk THEN Abort(); RETURN ErrWriting END;
				END;
				res := WriteTrack(op, track);
				IF res # ResOk THEN Abort(); RETURN ErrWriting END;

				IF settings.writeType = TrackAtOnce THEN
					(* close Track: Write PMA *)
					recStatus.operation := ClosingTrack; StatusChanged();
					res := Lib.CloseTrackSess(dev, TRUE, Lib.CFTrack, Lib.TRInvisible);
					WaitUntilFinished();
				END;
			END;
			IF settings.writeType = TrackAtOnce THEN
				(* close Session: write PMA to toc *)
				recStatus.operation := ClosingSession; StatusChanged();
				res := Lib.CloseTrackSess(dev, TRUE, Lib.CFSession, Lib.Ignore);
			ELSE
				recStatus.operation := FlushingCache; StatusChanged();
				res := Lib.SynchronizeCache(dev, TRUE);
			END;
			WaitUntilFinished();
			IF settings.verify THEN
				recStatus.operation := Verifying; StatusChanged();
				IF VerifyCompilation(compilation) # ResOk THEN
					IF Debug THEN GetSense(dev) END;
					Abort(); RETURN ErrVerificationFailed
				END;
			END;
			Unlock();
			INCL(dev.flags, Disks.ReadOnly);
			IF (reader # NIL) & (reader IS BufferedReader) THEN
				recStatus.empty := reader(BufferedReader).empty;
			ELSE
				recStatus.empty := -1;
			END;
			reader := NIL;
			RETURN ResOk;
		END Record;

		PROCEDURE InitWriteParams(VAR settings: BurnSettings; VAR params: WriteParams);
		BEGIN
			params.writeType := settings.writeType;
			params.bufe := settings.bufe;
			IF settings.multisession THEN
				params.multisession := Lib.MSNextSessB0;
			ELSE
				params.multisession := Lib.MSNoNextSessNoB0;
			END;
		END InitWriteParams;

		(* only data tracks are verified. reading DA is not accurate enough since there is no sync pattern. *)
		PROCEDURE VerifyCompilation(compilation: Compilation): LONGINT;
		VAR
			i: LONGINT;
			track: InformationTrack;
		BEGIN
			(* reloading not possible for notebook drives but LMT is the same in the capability page *)
			(*
			Unlock();
			IF (dev.MediaEject(FALSE, FALSE) # ResOk) OR (dev.MediaEject(FALSE, TRUE) # ResOk) THEN
				Abort(); RETURN ResErr;
			END;
			Lock();
			WHILE (~IsReady()) & (~CheckNoMediumPresent()) DO
				GetSense(dev);
				Objects.Yield();
			END;
			*)
			FOR i := 1 TO compilation.nofTracks-2 DO
				track := compilation.tracks[i](InformationTrack);
				IF (track.type = DataTrack) & (VerifyTrack(track) # ResOk) THEN RETURN ResErr END;
			END;
			RETURN ResOk;
		END VerifyCompilation;

		PROCEDURE VerifyTrack(track: InformationTrack): LONGINT;
		VAR
			lba, secs, count, nofBlocks, timestamp, ofs: LONGINT;
			discBuf: POINTER TO ARRAY OF LONGINT;
			fileBuf: POINTER TO ARRAY OF CHAR;
			r: Files.Reader;
		BEGIN
			(*
			IF track.type = DataTrack THEN
				type := Lib.STMode1;
			ELSE
				type := Lib.STCdDa;
			END;
			flags := Lib.HNone + Lib.UserData + Lib.EFNone;
			*)
			ASSERT(track.type = DataTrack);
			dev.SetBlockSize(track.secsize);
			timestamp := Kernel.GetTicks ();
			NEW(discBuf, track.bytespt DIV 4);
			NEW(fileBuf, track.bytespt + 4);
			ofs := SYSTEM.VAL (LONGINT, 4 - ADDRESSOF(fileBuf^) MOD 4);

			Files.OpenReader(r, track.file, 0);
			secs := track.nofsecs; lba := track.startSec;
			nofBlocks := track.secspt;
			WHILE secs > 0 DO
				IF secs < track.secspt THEN
					nofBlocks := secs;
				END;
				IF dev.TransferEx(Disks.Read, lba, nofBlocks, ADDRESSOF(discBuf^), dma & UseDma) # ResOk THEN RETURN ResErr END;
				(* IF Lib.ReadCD(dev, lba, nofBlocks, ADDRESSOF(discBuf^), nofBlocks*track.secsize, type, Lib.SCNoData, flags, dma & UseDma) # ResOk THEN RETURN ResErr END; *)

				r.Bytes(fileBuf^, ofs, nofBlocks*track.secsize, count);
				IF ~CompareData(ADDRESSOF(fileBuf^) + ofs, ADDRESSOF(discBuf^), nofBlocks*track.secsize) THEN RETURN ResErr END;
				INC(lba, nofBlocks); DEC(secs, nofBlocks);

				INC(recStatus.secsVerified, nofBlocks);
				IF Kernel.GetTicks () - timestamp >= NotificationPeriod THEN
					StatusChanged();
				END;
			END;
			StatusChanged();
			RETURN ResOk;
		END VerifyTrack;

		PROCEDURE CompareData(adr1, adr2: ADDRESS; len: LONGINT): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			FOR i:= 0 TO (len DIV 4) - 1 DO
				IF SYSTEM.GET32(adr1) # SYSTEM.GET32(adr2) THEN KernelLog.String("ERROR"); RETURN FALSE END;
				INC(adr1, 4); INC(adr2, 4);
			END;
			RETURN TRUE;
		END CompareData;

		PROCEDURE Abort;
		VAR
			size, res: LONGINT;
		BEGIN
			Unlock();
			(* restore previous blockSize *)
			dev.GetSize(size, res);
			INCL(dev.flags, Disks.ReadOnly);
			IF (reader # NIL) & (reader IS BufferedReader) THEN
				reader(BufferedReader).Abort();
			END;
			reader := NIL;
		END Abort;

		PROCEDURE Write(op, startSec, nofBlocks: LONGINT; adr: ADDRESS): LONGINT;
		VAR
			res: LONGINT;
		BEGIN
			LOOP
				res := dev.TransferEx(op, startSec, nofBlocks, adr, dma & UseDma);
				IF (res # ResOk) & IsInProgress() THEN
					timer.Sleep(150);
				ELSE
					EXIT;
				END;
			END;
			RETURN res;
		END Write;

		PROCEDURE PadTrack(op: LONGINT; track: InformationTrack) : LONGINT;
		VAR
			res: LONGINT;
			startSec, secsToPad, nofBlocks: LONGINT;
			buf: POINTER TO ARRAY OF CHAR;
		BEGIN
			recStatus.operation := Writing;
			StatusChanged();
			secsToPad := track.pregap;
			NEW(buf, track.bytespt);
			IF secsToPad >= track.secspt THEN
				(* Utils.ClearBuffer(buf^, 0, track.bytespt); *) (* memory is already cleared on allocation *)
			ELSE
				(* Utils.ClearBuffer(buf^, 0, secsToPad*track.secsize); *) (* memory is already cleared on allocation *)
			END;

			startSec := track.startSec - track.pregap;
			REPEAT
				IF secsToPad >= track.secspt THEN
					nofBlocks := track.secspt;
				ELSE
					nofBlocks := secsToPad;
				END;

				res := Write(op, startSec, nofBlocks, ADDRESSOF(buf^));

				IF res # ResOk THEN RETURN ResErr END;
				INC(startSec, nofBlocks);

			UNTIL startSec >= track.startSec;
			RETURN res;
		END PadTrack;

		PROCEDURE WriteTrack(op: LONGINT; VAR track: InformationTrack) : LONGINT;
		VAR
			res, startSec, bytesRead, count, nofBlocks: LONGINT;
			timestamp, lastSecs: LONGINT;
			buf: Buffer;
		BEGIN
			lastSecs := recStatus.secsTransferred;
			startSec := track.startSec;
			recStatus.operation := Writing;
			StatusChanged();
			timestamp := Kernel.GetTicks ();

			REPEAT
				count := reader.GetBuffer(buf);
				nofBlocks := count DIV track.secsize;

				res := Write(op, startSec, nofBlocks, ADDRESSOF(buf^));
				IF res # ResOk THEN RETURN ResErr END;

				INC(startSec, nofBlocks);
				INC(bytesRead, count);
				reader.ReleaseBuffer();

				INC(recStatus.secsTransferred, nofBlocks);
				IF Kernel.GetTicks () - timestamp >= NotificationPeriod THEN
					recStatus.currentSpeed := ASH(1000*((RawSectorSize * (recStatus.secsTransferred-lastSecs)) DIV (Kernel.GetTicks () - timestamp)) , -10);
					res := GetBufferCapacity(recStatus.bufferSize, recStatus.freeBuffer);
					StatusChanged();
					timestamp := Kernel.GetTicks (); lastSecs := recStatus.secsTransferred;
				END;
			UNTIL bytesRead >= track.size;

			recStatus.currentSpeed := 0;
			recStatus.freeBuffer := recStatus.bufferSize;
			RETURN ResOk;
		END WriteTrack;

		PROCEDURE SetWriteSpeed(speed: LONGINT): LONGINT;
		BEGIN
			RETURN Lib.SetCDSpeed(dev, BestSpeed, speed*SingleSpeed, 0H);
		END SetWriteSpeed;

		PROCEDURE IsReady*(): BOOLEAN;
		BEGIN
			RETURN dev.TestUnitReady() = ResOk;
		END IsReady;

		PROCEDURE GetDiscInfo*(disc: Disc): LONGINT;
		VAR
			info: Lib.DiscInfo;
			res, secsize,secs, nwa: LONGINT;
		BEGIN
			IF dev.TestUnitReady() # ResOk THEN
				res := dev.RequestSense();
				IF CheckNoMediumPresent() THEN
					RETURN ErrNoMediumPresent;
				ELSE
					RETURN  ErrDriveNotReady;
				END;
			END;

			IF dev.ReadCapacity(secsize, disc.usedBlocks) # ResOk THEN RETURN ResErr END;

			IF  Lib.ReadDiscInformation(dev, Lib.DTDiscInfoBlock, ADDRESSOF(info), SIZEOF(Lib.DiscInfo)) # ResOk THEN RETURN ResErr END;

			disc.erasable := Lib.DIBErasableBit IN SYSTEM.VAL(SET, info.Byte2);
			disc.status := Lib.GetField(info.Byte2, Lib.DIBDiscStatusMask, Lib.DIBDiscStatusOfs);
			disc.statusLastSession := Lib.GetField(info.Byte2, Lib.DIBSessionStatusMask, Lib.DIBSessionStatusOfs);

			disc.nofSessions := ORD(info.NofSessions);
			disc.type := ORD(info.DiscType);

			disc.latestLeadOut.min := ORD(info.LastLeadOut[1]);
			disc.latestLeadOut.sec := ORD(info.LastLeadOut[2]);
			disc.latestLeadOut.frame := ORD(info.LastLeadOut[3]);

			IF disc.status = Lib.DSComplete THEN
				disc.freeBlocks := 0;
			ELSE
				IF Lib.GetNextAddress(dev, nwa) # ResOk THEN RETURN ResErr END;
				MsfToSector(disc.latestLeadOut, secs);
				disc.freeBlocks := secs - nwa;
			END;
			RETURN ResOk;
		END GetDiscInfo;

		PROCEDURE GetDiscInfoEx*(disc: DiscEx): LONGINT;
		VAR
			adr: ADDRESS;
			res, clvLow, clvHigh: LONGINT;
			descr: Lib.ATIPDescriptorPtr;
			buf: POINTER TO ARRAY OF CHAR;
		BEGIN
			res := GetDiscInfo(disc);
			IF res # ResOk THEN RETURN res END;

			NEW(buf, SIZEOF(Lib.ATIPHeader) + SIZEOF(Lib.ATIPDescriptor));

			adr := ADDRESSOF(buf[0]);
			IF Lib.ReadToc(dev, FALSE, Lib.TCFormatATIP, 0, adr, LEN(buf^)) # ResOk THEN RETURN ResErr END;

			descr := SYSTEM.VAL(Lib.ATIPDescriptorPtr, adr + SIZEOF(Lib.ATIPHeader));
			ASSERT(ADDRESSOF(descr^) = SYSTEM.VAL(ADDRESS, descr));

			disc.subtype := Lib.GetField(descr.Byte2, Lib.ATSubTypeMask, Lib.ATSubTypeOfs);
			IF Lib.ATCdRwBit IN SYSTEM.VAL(SET, descr.Byte2) THEN
				disc.refSpeed := Lib.CLVToSpeed(Lib.GetField(descr.Byte0, Lib.ATRefSpeedMask, Lib.ATRefSpeedOfs));
			END;

			IF Lib.ATA1ValidBit IN SYSTEM.VAL(SET, descr.Byte2) THEN
				clvLow := Lib.GetField(descr.A1Values[0], Lib.ATCLVLowMask, Lib.ATCLVLowOfs);
				clvHigh := Lib.GetField(descr.A1Values[0], Lib.ATCLVHighMask, Lib.ATCLVHighOfs);
				IF clvLow # 0 THEN disc.minSpeed := Lib.CLVToSpeed(clvLow) END;
				IF clvHigh # 0 THEN disc.maxSpeed := Lib.CLVToSpeed(clvHigh) END;
				IF disc.erasable & (disc.subtype = Lib.ATCdRwHighSpeed) & (clvHigh # 0) THEN
					disc.maxSpeed := Lib.CLVToHighSpeed(clvHigh);
				END;
			END;

			IF (Lib.ATA2ValidBit IN SYSTEM.VAL(SET, descr.Byte2)) & disc.erasable & ((disc.subtype = Lib.ATCdRwUltraHighSpeed) OR (disc.subtype = Lib.ATCdRwUltraHighSpeedPlus)) THEN
				clvLow := Lib.GetField(descr.A2Values[0], Lib.ATCLVLowMask, Lib.ATCLVLowOfs);
				clvHigh := Lib.GetField(descr.A2Values[0], Lib.ATCLVHighMask, Lib.ATCLVHighOfs);
				IF (clvLow # 0) THEN disc.minSpeed := Lib.CLVToUltraHighSpeed(clvLow) END;
				IF (clvHigh # 0) THEN disc.maxSpeed := Lib.CLVToUltraHighSpeed(clvHigh) END;
			END;
			RETURN ResOk;
		END GetDiscInfoEx;

		PROCEDURE GetWriteParams(VAR  params: WriteParams): LONGINT;
		VAR
			res: LONGINT;
			page: Lib.WriteParameterPage;
		BEGIN
			res := Lib.ModeSense(dev, Lib.MPCurrent, Lib.MPWriteParameters, ADDRESSOF(page), SIZEOF(Lib.WriteParameterPage));
			IF res = ResOk THEN
				params.writeType := Lib.GetField(page.Byte2, Lib.MPWWriteTypeMask, Lib.MPWWriteTypeOfs);
				params.testWrite := Lib.MPWTestWriteBit IN SYSTEM.VAL(SET, page.Byte2);
				params.multisession := Lib.GetField(page.Byte3, Lib.MPWMultisessionMask, Lib.MPWMultisessionOfs);
				params.trackMode := Lib.GetField(page.Byte3, Lib.MPWTrackModeMask, Lib.MPWTrackModeOfs);
				params.bufe := Lib.MPWBufeBit IN SYSTEM.VAL(SET, page.Byte3);
				params.DBType := Lib.GetField(page.Byte3, Lib.MPWDataBlockMask, Lib.MPWDataBlockOfs);
			END;
			RETURN res;
		END GetWriteParams;

		PROCEDURE SetWriteParams(VAR params: WriteParams; save: BOOLEAN): LONGINT;
		VAR
			page: Lib.WriteParameterPage;
			tmp: LONGINT;

		BEGIN
			IF Lib.ModeSense(dev, Lib.MPCurrent, Lib.MPWriteParameters, ADDRESSOF(page), SIZEOF(Lib.WriteParameterPage)) # ResOk THEN
				tmp :=dev.RequestSense(); RETURN ResErr;
			 END;

			Utils.SetBE16(0H, page.Header.DataLength);
			EXCL(SYSTEM.VAL(SET, page.Byte0), Lib.MPPSBit);

			Lib.SetField(page.Byte2, Lib.MPWWriteTypeMask, Lib.MPWWriteTypeOfs, params.writeType);
			IF params.testWrite THEN
				Lib.SetBit(page.Byte2, Lib.MPWTestWriteBit);
			ELSE
				Lib.ClearBit(page.Byte2, Lib.MPWTestWriteBit);
			END;
			IF params.bufe THEN
				Lib.SetBit(page.Byte2, Lib.MPWBufeBit);
			ELSE
				Lib.ClearBit(page.Byte2, Lib.MPWBufeBit);
			END;

			Lib.SetField(page.Byte3, Lib.MPWTrackModeMask, Lib.MPWTrackModeOfs, params.trackMode);
			Lib.SetField(page.Byte3, Lib.MPWMultisessionMask, Lib.MPWMultisessionOfs, params.multisession);

			Lib.SetField(page.Byte4, Lib.MPWDataBlockMask, Lib.MPWDataBlockOfs, params.DBType);

			IF Lib.ModeSelect(dev, save, ADDRESSOF(page), SIZEOF(Lib.WriteParameterPage)) # ResOk THEN
				tmp := dev.RequestSense(); RETURN ResErr;
			END;
			RETURN ResOk;
		END SetWriteParams;

		PROCEDURE PrintWriteParams(): LONGINT;
		VAR
			page: Lib.WriteParameterPage;
			tmp: LONGINT;
		BEGIN
			IF Lib.ModeSense(dev, Lib.MPCurrent, Lib.MPWriteParameters, ADDRESSOF(page), SIZEOF(Lib.WriteParameterPage)) # ResOk THEN
				tmp := dev.RequestSense(); RETURN ResErr;
			END;
			KernelLog.String("Byte 0: "); KernelLog.Bits(SYSTEM.VAL(SET, page.Byte0), 0, 8); KernelLog.Ln;
			KernelLog.String("Page Length: "); KernelLog.Int(ORD(page.Length), 5); KernelLog.Ln;
			KernelLog.String("Byte 2: "); KernelLog.Bits(SYSTEM.VAL(SET, page.Byte2), 0, 8); KernelLog.Ln;
			KernelLog.String("Byte 3: "); KernelLog.Bits(SYSTEM.VAL(SET, page.Byte3), 0, 8); KernelLog.Ln;
			KernelLog.String("Byte 4: "); KernelLog.Bits(SYSTEM.VAL(SET, page.Byte4), 0, 8); KernelLog.Ln;
			KernelLog.String("Link Size: "); KernelLog.Int(ORD(page.LinkSize), 5); KernelLog.Ln;
			KernelLog.String("Byte7: "); KernelLog.Bits(SYSTEM.VAL(SET, page.Byte7), 0, 8); KernelLog.Ln;
			KernelLog.String("Session Format: "); KernelLog.Int(ORD(page.SessionFormat), 8); KernelLog.Ln;
			KernelLog.String("Packet Size: "); KernelLog.Int(Utils.ConvertBE32Int(page.PacketSize), 5); KernelLog.Ln;
			KernelLog.String("Audio Pause Length: "); KernelLog.Int(Utils.ConvertBE16Int(page.PauseLength), 5); KernelLog.Ln;
			RETURN ResOk;
		END PrintWriteParams;

		PROCEDURE Lock;
		BEGIN
			IF dev.MediaLock(TRUE) = ResOk THEN
				locked := TRUE;
			END;
		END Lock;

		PROCEDURE Unlock;
		BEGIN
			IF locked THEN
				IF dev.MediaLock(FALSE) = ResOk THEN locked := FALSE END;
			END;
		END Unlock;

		PROCEDURE StatusChanged;
		BEGIN
			IF onRecordStatusChanged # NIL THEN
					onRecordStatusChanged(recStatus);
			END;
		END StatusChanged;

		PROCEDURE CheckIncompatibleMedium(): BOOLEAN;
		VAR
			msg: ATADisks.GetSenseMsg;
			res: LONGINT;
		BEGIN
			dev.Handle(msg, res);
			RETURN (msg.sense = 5) & (msg.asc = 30);
		END CheckIncompatibleMedium;

		(* wait until completion of long immediate operations *)
		PROCEDURE WaitUntilFinished*;
		VAR
			msg: ATADisks.GetSenseMsg;
			res, tmp: LONGINT;
			timer: Kernel.Timer;
		BEGIN
			NEW(timer);
			REPEAT
				timer.Sleep(1000);
				res := dev.TestUnitReady();
				res := dev.RequestSense();
				dev.Handle(msg, tmp);
			UNTIL (msg.sense # 2) OR (msg.asc # 4) OR (res # ResOk);
		END WaitUntilFinished;

		(* check if no medium present *)
		PROCEDURE CheckNoMediumPresent*(): BOOLEAN;
		VAR
			msg: ATADisks.GetSenseMsg;
			res: LONGINT;
		BEGIN
			dev.Handle(msg, res);
			RETURN (msg.sense = 2) & (msg.asc = 3AH) & ((msg.ascq = 0) OR (msg.ascq = 1) OR (msg.ascq = 2));
		END CheckNoMediumPresent;

		(* long operation in progress *)
		PROCEDURE IsInProgress*(): BOOLEAN;
		VAR
			msg: ATADisks.GetSenseMsg;
			res: LONGINT;
		BEGIN
			dev.Handle(msg, res);
			RETURN (msg.sense = 2) & (msg.asc = 4) & ((msg.ascq = 4) OR (msg.ascq = 7) OR (msg.ascq = 8));
		END IsInProgress;

	END CDRecorder;

	Reader = OBJECT
		VAR
			compilation: Compilation;

		PROCEDURE GetBuffer(VAR buf: Buffer): LONGINT;
			(* abstract *)
		END GetBuffer;

		PROCEDURE ReleaseBuffer;
			(* abstract *)
		END ReleaseBuffer;
	END Reader;

	UnbufferedReader = OBJECT(Reader)
		VAR
			r: Files.Reader;
			buffer: Buffer;
			trackno, bytesRead: LONGINT;
			track: InformationTrack;

		PROCEDURE &New*(compilation: Compilation; bufSize: LONGINT);
		BEGIN
			SELF.compilation := compilation;
			r := NIL; track := NIL;
			trackno := 0;
			NEW(buffer, bufSize);
		END New;

		PROCEDURE GetBuffer(VAR buf: Buffer): LONGINT;
		VAR
			amount, rem: LONGINT;
		BEGIN
			IF  (r = NIL) & (track = NIL) THEN
				INC(trackno);
				track := compilation.tracks[trackno](InformationTrack);
				Files.OpenReader(r, track.file, 0);
				bytesRead := 0;
			END;

			amount := 0;
			IF r # NIL THEN
				r.Bytes(buffer^, 0, track.bytespt, amount);
			END;

			INC(bytesRead, amount);
			IF (amount < track.bytespt) THEN
				r := NIL;
				rem := Strings.Min(track.bytespt-amount, track.size  - bytesRead);
				Utils.ClearBuffer(buffer^, amount, rem);
				INC(amount, rem); INC(bytesRead, rem);
			END;

			IF bytesRead >= track.size THEN
				track := NIL;
			END;

			buf := buffer;
			RETURN amount;
		END GetBuffer;

		PROCEDURE ReleaseBuffer;
			(* nothing to do for sequential reader *)
		END ReleaseBuffer;
	END UnbufferedReader;

	(* buffer for 1 consumer / 1 producer *)
	(* shared variables have single writer *)
	ReadBuffer = OBJECT
		VAR
			buf: Buffer;
			len: LONGINT;

		PROCEDURE &New*(bufSize: LONGINT);
		BEGIN
			len := 0;
			NEW(buf, bufSize);
		END New;
	END ReadBuffer;

	Fifo = POINTER TO ARRAY OF ReadBuffer;

	BufferedReader = OBJECT(Reader)
		VAR
			nBuffers: LONGINT;
			fifo: Fifo;
			pIndex, cIndex: LONGINT;
			finished: BOOLEAN;
			empty*: LONGINT; (* number of times buffer was empty, should be zero *)
			aborted: BOOLEAN;

		PROCEDURE &New*(compilation: Compilation; bufSize: LONGINT);
		VAR
			i: LONGINT;
		BEGIN
			finished := FALSE; empty := 0;
			SELF.compilation := compilation;
			nBuffers := FifoSize DIV bufSize;
			NEW(fifo, nBuffers);
			FOR i:=0  TO nBuffers-1 DO
				NEW(fifo[i], bufSize);
			END;
			cIndex := 0; pIndex := 0;
			aborted := FALSE;
		END New;

		PROCEDURE Abort;
		BEGIN
			aborted := TRUE;
		END Abort;

		PROCEDURE GetBuffer(VAR buf: Buffer): LONGINT;
		VAR
			rBuffer: ReadBuffer;
		BEGIN
			rBuffer := WaitBufferAvailable(TRUE);
			buf := rBuffer.buf;
			RETURN rBuffer.len;
		END GetBuffer;

		PROCEDURE Read;
		VAR
			i: LONGINT;
			track: InformationTrack;
		BEGIN
			FOR i := 1 TO compilation.nofTracks-2 DO
				IF aborted THEN RETURN END;
				track := compilation.tracks[i](InformationTrack);
				ReadTrack(track);
			END;
			finished := TRUE;
		END Read;

		PROCEDURE ReadTrack(track: InformationTrack);
		VAR
			bytesRead, amount, rem: LONGINT;
			r: Files.Reader;
			rBuffer: ReadBuffer;
		BEGIN
			Files.OpenReader(r, track.file, 0);
			bytesRead := 0;
			REPEAT
				rBuffer := WaitBufferAvailable(FALSE);
				IF aborted THEN RETURN END;
				r.Bytes(rBuffer.buf^, 0, track.bytespt, amount);
				INC(bytesRead, amount);
				IF amount < track.bytespt THEN
					rem := Strings.Min(track.bytespt-amount, track.size - bytesRead);
					Utils.ClearBuffer(rBuffer.buf^, amount, rem);
					INC(amount, rem); INC(bytesRead, rem);
				END;
				rBuffer.len := amount;
				pIndex := (pIndex + 1) MOD nBuffers;
			UNTIL bytesRead >= track.file.Length();

			WHILE bytesRead < track.size DO
				rBuffer := WaitBufferAvailable(FALSE);
				amount := Strings.Min(track.bytespt, track.size  - bytesRead);
				Utils.ClearBuffer(rBuffer.buf^, 0, amount);
				rBuffer.len := amount;
				INC(bytesRead, amount);
				pIndex := (pIndex + 1) MOD nBuffers;
			END;

		END ReadTrack;

		PROCEDURE ReleaseBuffer;
		BEGIN
			cIndex := (cIndex + 1) MOD nBuffers;
		END ReleaseBuffer;

		(* fill half of buffer *)
		PROCEDURE Init;
		BEGIN
			WHILE (pIndex < nBuffers DIV 2) & ~finished & ~aborted DO
				Objects.Yield();
			END
		END Init;

		PROCEDURE WaitBufferAvailable(read: BOOLEAN): ReadBuffer;
		BEGIN
			IF read THEN
				IF cIndex = pIndex THEN
					INC(empty);
				END;
				WHILE (cIndex = pIndex) DO (* buffer empty *)
					Objects.Yield();
				END;
				RETURN fifo[cIndex];
			ELSE
				WHILE ((pIndex + 1) MOD nBuffers = cIndex) & ~aborted  DO
					Objects.Yield();
				END;
				RETURN fifo[pIndex];
			END;
		END WaitBufferAvailable;

		BEGIN {ACTIVE}
			Read();
	END BufferedReader;


PROCEDURE IdentifyRecorders*(VAR recorders: ARRAY OF CDRecorder): LONGINT;
VAR
	devTable: Plugins.Table;
	device : ATADisks.DeviceATAPI;
	i, cur: LONGINT;
	cap: Capabilities;
	res : LONGINT;
BEGIN
	res := ResErr;
	FOR i := 0 TO MaxRecorders-1 DO
		recorders[i] := NIL;
	END;
	Disks.registry.GetAll(devTable);
	cur := 0;
	IF devTable # NIL THEN
		FOR i := 0 TO LEN(devTable^) - 1 DO
			IF devTable[i] IS ATADisks.DeviceATAPI THEN
				(* KernelLog.String("Identifying"); *)
				device := devTable[i](ATADisks.DeviceATAPI);
				IF GetCapabilities(device, cap) # ResOk THEN RETURN ResErr END;
				IF MFCdr IN cap.mediaFunc THEN
					NEW(recorders[cur], device, cap);
					INC(cur, 1);
				END;
			END;
		END;
	END;
	RETURN ResOk;
END IdentifyRecorders;

PROCEDURE GetCapabilities(VAR dev: ATADisks.DeviceATAPI; VAR cap: Capabilities) : LONGINT;
VAR
	buf : POINTER TO ARRAY OF CHAR;
	ofs, size, numSpeeds, i, curSpeed, maxSpeed, speed, tmp: LONGINT;
	adr: ADDRESS;
	header: Lib.ModeHeader;
	page: Lib.CapabilityPagePtr;
	speedDescr: Lib.SpeedDescriptorPtr;
	feature: Lib.MasteringFeature;
	writeSpeedHeader: Lib.WriteSpeedHeader;
	writeSpeedDescr: Lib.WriteSpeedDescrPtr;
BEGIN
	(* get mode parameter header to determine size of whole page *)

	IF Lib.ModeSense(dev, Lib.MPCurrent, Lib.MPCapabilities, ADDRESSOF(header), SIZEOF(Lib.ModeHeader)) # ResOk THEN RETURN ResErr END;

	size := Utils.ConvertBE16Int(header.DataLength)+ 2;  (* size of whole page *)
	(* we need an array here since Capability mode page has variable length *)
	NEW(buf, size);

	(* now get whole capabilites page *)

	adr := ADDRESSOF(buf[0]);
	IF Lib.ModeSense(dev, Lib.MPCurrent, Lib.MPCapabilities, adr, size) # ResOk THEN RETURN ResErr END;
	page := SYSTEM.VAL(Lib.CapabilityPagePtr, adr);
	ASSERT(ADDRESSOF(page^) = SYSTEM.VAL(ADDRESS, page));

	(* Media Functions *)
	IF Lib.MPCCdrBit IN SYSTEM.VAL(SET, page.Byte3) THEN INCL(cap.mediaFunc, MFCdr) END;
	IF Lib.MPCCdRwBit IN SYSTEM.VAL(SET, page.Byte3) THEN INCL(cap.mediaFunc, MFCdRw) END;
	IF Lib.MPCMultisessionBit IN SYSTEM.VAL(SET, page.Byte4) THEN INCL(cap.mediaFunc, MFMultisession) END;
	IF Lib.MPCBufeBit IN SYSTEM.VAL(SET, page.Byte4) THEN INCL(cap.mediaFunc, MFBufe) END;

	CASE Lib.GetField(page.Byte6, Lib.LMTMask, Lib.LMTOfs) OF
		  Lib.LMTCaddy: INCL(cap.mediaFunc, MFCaddy);
		| Lib.LMTTray: INCL(cap.mediaFunc, MFTray);
		| Lib.LMTPopUp: INCL(cap.mediaFunc, MFCaddy);
		ELSE
	END;

	numSpeeds := Utils.ConvertBE16Int(page.NofWriteDescriptors);

	(* some drives do not list maximum and current write speed in descriptor table, but fields are actually obsoleted *)

	curSpeed := Utils.ConvertBE16Int(page.CurWriteSpeed2); DEC(curSpeed, curSpeed MOD 2*SingleSpeed);
	maxSpeed := Utils.ConvertBE16Int(page.MaxWriteSpeed); DEC(maxSpeed, maxSpeed MOD 2*SingleSpeed);

	(* get first descriptor *)
	INC(adr, SIZEOF(Lib.CapabilityPage));
	speedDescr := SYSTEM.VAL(Lib.SpeedDescriptorPtr, adr);
	INC(adr, SIZEOF(Lib.SpeedDescriptor));
	speed := Utils.ConvertBE16Int(speedDescr.WriteSpeed);

	IF ListCurrentMaxSpeeds THEN
		IF (maxSpeed > curSpeed) & (curSpeed > speed) THEN
			INC(numSpeeds, 2);
			NEW(cap.writeSpeeds, numSpeeds);
			cap.writeSpeeds[0] := maxSpeed; cap.writeSpeeds[1] := curSpeed; ofs := 2;
		ELSIF maxSpeed > speed THEN
			INC(numSpeeds);
			NEW(cap.writeSpeeds, numSpeeds); cap.writeSpeeds[0] := maxSpeed; ofs := 1;
		ELSE
			NEW(cap.writeSpeeds, numSpeeds); ofs := 0;
		END;
	ELSE
		NEW(cap.writeSpeeds, numSpeeds); ofs := 0;
	END;

	cap.writeSpeeds[ofs] := speed; INC(ofs);
	FOR i := ofs TO numSpeeds-1 DO
		speedDescr := SYSTEM.VAL(Lib.SpeedDescriptorPtr, adr);
		cap.writeSpeeds[i] := Utils.ConvertBE16Int(speedDescr.WriteSpeed);
		INC(adr, SIZEOF(Lib.SpeedDescriptor));
	END;

	(* Get Performance. If we get more speeds here, we use the descriptors provided by this command *)
	(* first only get header *)

	IF Lib.GetPerformance(dev, Lib.PTypeWriteSpeed, 0H, 0H, 0, ADDRESSOF(writeSpeedHeader), SIZEOF(Lib.WriteSpeedHeader)) # ResOk THEN
		size := Utils.ConvertBE32Int(writeSpeedHeader.DataLength) + 4;
		tmp := (size - SIZEOF(Lib.WriteSpeedHeader)) DIV SIZEOF(Lib.WriteSpeedDescr);
		IF tmp > numSpeeds THEN
			numSpeeds := tmp;
			NEW(buf, size);
			adr := ADDRESSOF(buf[0]);
			IF Lib.GetPerformance(dev, Lib.PTypeWriteSpeed, 0H, 0H, numSpeeds, adr, size) # ResOk THEN RETURN ResErr END;
			INC(adr, SIZEOF(Lib.WriteSpeedHeader));
			NEW(cap.writeSpeeds, numSpeeds);
			FOR i:=0 TO numSpeeds-1 DO
				writeSpeedDescr := SYSTEM.VAL(Lib.WriteSpeedDescrPtr, adr);
				cap.writeSpeeds[i] := Utils.ConvertBE32Int(writeSpeedDescr.WriteSpeed);
				INC(adr, SIZEOF(Lib.WriteSpeedDescr));
			END;
		END;
	END;

	(* although spec says that speeds are sorted in descending order, this is not always the case *)
	InsertionSort(cap.writeSpeeds^, LEN(cap.writeSpeeds));

	(* GetConfiguration provides further information *)
	IF Lib.GetConfiguration(dev, Lib.FOne, Lib.FMastering, ADDRESSOF(feature), SIZEOF(Lib.MasteringFeature)) # ResOk THEN RETURN ResErr END;
	IF  Lib.FDMSaoBit IN SYSTEM.VAL(SET, feature.Byte4) THEN INCL(cap.mediaFunc, MFSao) END;
	RETURN ResOk;
END GetCapabilities;

PROCEDURE InsertionSort(VAR arr: ARRAY OF LONGINT; size: LONGINT);
VAR
	i, j, index: LONGINT;
BEGIN
	FOR i := 1 TO size - 1 DO
		index := arr[i]; j := i;
		WHILE (j > 0) & (arr[j-1] < index) DO
			arr[j] := arr[j-1]; DEC(j);
		END;
		arr[j] := index;
	END;
END InsertionSort;

PROCEDURE GetSense*(dev: ATADisks.DeviceATAPI);
VAR
	msg: ATADisks.GetSenseMsg;
	res: LONGINT;
BEGIN
	res := dev.RequestSense();
	dev.Handle(msg, res);
	KernelLog.String("sense: "); KernelLog.Hex(msg.sense, 5);
	KernelLog.String(" asc: "); KernelLog.Hex(msg.asc, 5);
	KernelLog.String(" ascq: "); KernelLog.Hex(msg.ascq, 5);
	KernelLog.Ln;
END GetSense;

PROCEDURE FileExists(filename: Strings.String): BOOLEAN;
BEGIN
	RETURN (filename # NIL) & (Files.Old(filename^) # NIL);
END FileExists;

PROCEDURE IsIsoFile(filename: Strings.String): BOOLEAN;
VAR
	info: MakeIsoImages.ISOInfo;
BEGIN
	NEW(info);
	RETURN info.Open(filename) = ResOk;
END IsIsoFile;

PROCEDURE IsWavFile(filename: Strings.String): BOOLEAN;
VAR
	info: Utils.WAVInfo;
BEGIN
	NEW(info);
	IF info.Open(filename) = ResOk THEN
		IF (info.nofchannels = 2) & (info.samplerate = 44100) & (info.encoding = 16) THEN
			RETURN TRUE;
		END;
	END;
	RETURN FALSE;
END IsWavFile;

PROCEDURE SectorToMsf(sector: LONGINT; VAR msf: MSF);
VAR
	rem: LONGINT;
BEGIN
	rem := sector + InitialPregap; (* see Mt. Fuji Table 621 LBA to MSF Translation *)
	msf.min := ENTIER(rem / (60*75));
	DEC(rem, msf.min*60*75);
	msf.sec := ENTIER(rem / 75);
	DEC(rem, msf.sec*75);
	msf.frame := rem;
END SectorToMsf;

PROCEDURE MsfToSector(VAR msf: MSF; VAR sector: LONGINT);
BEGIN
	sector := 75*(60*msf.min + msf.sec) + msf.frame - InitialPregap;
END MsfToSector;

PROCEDURE Test*;
VAR
	res: LONGINT;
	settings: BurnSettings;
	compilation: Compilation;
	recorders: ARRAY MaxRecorders OF CDRecorder;
BEGIN
	res := IdentifyRecorders(recorders);
	IF recorders[0] # NIL THEN
			KernelLog.String("Recording");

			(* audio test: wav files must be 16 bit encoded, 44.1kHz and 2 channel*)
			NEW(compilation);
			res := compilation.AddTrack(Strings.NewString("Auto0:/Data/TRACK0.WAV"), AudioTrack, FALSE);
			compilation.Finish();

			(* iso file *)
			(*
			NEW(compilation);
			res := compilation.AddTrack(Strings.NewString("Auto0:/Data/TEST1.ISO"), DataTrack, FALSE);
			Print("res track 1", res);
			compilation.Finish();
			*)

			settings.speed := 16;
			settings.writeType := TrackAtOnce;
			settings.verify := FALSE;

			res :=recorders[0].Record(compilation, settings, PrintStatus);
	ELSE
		KernelLog.String("no ready recorder found");
	END;
END Test;

PROCEDURE PrintStatus(status: Utils.Status);
VAR
	recStatus: RecordingStatus;
BEGIN
	recStatus := status(RecordingStatus);
	KernelLog.String("current Speed: "); KernelLog.Int(recStatus.currentSpeed, 8); KernelLog.Ln;
	KernelLog.String("secs Transferred: "); KernelLog.Int(recStatus.secsTransferred, 8); KernelLog.Ln;
	KernelLog.String("free Buffer: "); KernelLog.Int(recStatus.freeBuffer, 8); KernelLog.Ln;
	KernelLog.String("buffer Size: "); KernelLog.Int(recStatus.bufferSize, 8); KernelLog.Ln;
END PrintStatus;

END CDRecord.


CDRecord.Test~


