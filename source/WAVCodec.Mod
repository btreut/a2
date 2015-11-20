MODULE WAVCodec; (** AUTHOR "MVT, PL"; PURPOSE "WAV audio format Codec"; *)

IMPORT
	Codecs, SoundDevices, Streams, KernelLog,SYSTEM;

CONST
	MAXBUF = 4096;

TYPE
	Chunk = ARRAY 5 OF CHAR; 								(* type of wave header part *)

	(* Header of a wave file *)
	WaveHeader* = RECORD
		chunkRIFF: Chunk; 									(* must be "RIFF" *)
		chunkWAVE: Chunk; 									(* must be "WAVE" *)
		chunkfmt: Chunk; 									(* must be "fmt " *)
		waveFormatSize: LONGINT; 							(* must be 16 for PCM wave *)
		formatTag: INTEGER; 								(* must be 1 for PCM wave *)
		nofCh: INTEGER; 									(* number of channels *)
		sRate: LONGINT; 									(* sampling rate *)
		bRate: LONGINT; 									(* byte rate *)
		blockAlign: INTEGER; 								(* bytes per sample *)
		bitsPerSample: INTEGER; 							(* sampling resolution = bits per sample for 1 channel *)
		chunkdata: Chunk; 									(* must be "data" *)
		fileSize: LONGINT;									(* size of the whole file minus 8 byte *)
		dataSize: LONGINT; 									(* size of PCM data in byte = file size minus header size *)
	END;

	(* Audio Wave PCM Encoder *)
	WAVEncoder* = OBJECT(Codecs.AudioEncoder)
	VAR
		out: Streams.Writer;
		h: WaveHeader;

		PROCEDURE Open*(out: Streams.Writer; sRate, sRes, nofCh: LONGINT; VAR res : LONGINT);
		BEGIN
			res := -1;
			IF out = NIL THEN
				KernelLog.String("WAVEncoder - Writer is NIL"); KernelLog.Ln;
				RETURN;
			END;
			SELF.out := out;

			(* Write wave header *)
			h.chunkRIFF[0] := "R"; h.chunkRIFF[1] := "I"; h.chunkRIFF[2] := "F"; h.chunkRIFF[3] := "F";
			out.Bytes(h.chunkRIFF, 0, 4);

			h.fileSize := SIZEOF(WaveHeader)-8; (* for wave file with zero-length sound - will be updated later *)
			WriteRawBELongInt(out, h.fileSize);

			h.chunkWAVE[0] := "W"; h.chunkWAVE[1] := "A"; h.chunkWAVE[2] := "V"; h.chunkWAVE[3] := "E";
			out.Bytes(h.chunkWAVE, 0, 4);

			h.chunkfmt[0] := "f"; h.chunkfmt[1] := "m"; h.chunkfmt[2] := "t"; h.chunkfmt[3] := " ";
			out.Bytes(h.chunkfmt, 0, 4);

			h.waveFormatSize := 16;
			WriteRawBELongInt(out, h.waveFormatSize);

			h.formatTag := 1;
			WriteRawBEInteger(out, h.formatTag);

			h.nofCh := SHORT(nofCh);
			WriteRawBEInteger(out, h.nofCh);

			h.sRate := sRate;
			WriteRawBELongInt(out, h.sRate);

			h.blockAlign := SHORT(nofCh * (sRes DIV 8));
			h.bRate := sRate * h.blockAlign;
			WriteRawBELongInt(out, h.bRate);
			WriteRawBEInteger(out, h.blockAlign);

			h.bitsPerSample := SHORT(sRes);
			WriteRawBEInteger(out, h.bitsPerSample);

			h.chunkdata[0] := "d"; h.chunkdata[1] := "a"; h.chunkdata[2] := "t"; h.chunkdata[3] := "a";
			out.Bytes(h.chunkdata, 0, 4);

			h.dataSize := 0; (* for wave file with zero-length sound - will be updated later *)
			WriteRawBELongInt(out, h.dataSize);

			out.Update;
			res := 0
		END Open;

		PROCEDURE Write*(buffer : SoundDevices.Buffer; VAR res : LONGINT);
		BEGIN
			out.Bytes(buffer.data^, 0, buffer.len);
			out.Update
		END Write;

	END WAVEncoder;

	(* Audio Wave PCM Decoder *)
	WAVDecoder* = OBJECT(Codecs.AudioDecoder)
	VAR in: Streams.Reader;
		h: WaveHeader;
		hasMoreBytes : BOOLEAN;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		VAR len: LONGINT; c: CHAR;
		BEGIN
			res := -1;
			IF in = NIL THEN
				KernelLog.String("WAVDecoder - InputStream is NIL"); KernelLog.Ln;
				RETURN;
			END;
			SELF.in := in;

			(* Read header and check for correctness *)
			in.Bytes(h.chunkRIFF, 0, 4, res);
			IF (res # 4) OR (h.chunkRIFF # "RIFF") THEN
				KernelLog.String("WAVDecoder - RIFF header ID not found"); KernelLog.Ln;
				RETURN;
			END;

			ReadRawBELongInt(in, h.fileSize);

			in.Bytes(h.chunkWAVE, 0, 4, res);
			IF (res # 4) OR (h.chunkWAVE # "WAVE") THEN
				KernelLog.String("WAVDecoder - WAVE header ID not found"); KernelLog.Ln;
				RETURN;
			END;

			in.Bytes(h.chunkfmt, 0, 4, res);
			IF (res # 4) OR (h.chunkfmt # "fmt ") THEN
				KernelLog.String("WAVDecoder - fmt header ID not found"); KernelLog.Ln;
				RETURN;
			END;

			ReadRawBELongInt(in, h.waveFormatSize);
			IF (h.waveFormatSize < 16) THEN
				KernelLog.String("WAVDecoder - Wrong header size"); KernelLog.Ln;
				RETURN;
			END;

			in.RawInt(h.formatTag);
			IF (h.formatTag # 1) THEN
				KernelLog.String("WAVDecoder - Wrong wave format (must be PCM)"); KernelLog.Ln;
				RETURN;
			END;

			ReadRawBEInteger(in, h.nofCh);
			ReadRawBELongInt(in, h.sRate);
			ReadRawBELongInt(in, h.bRate);
			ReadRawBEInteger(in, h.blockAlign);
			ReadRawBEInteger(in, h.bitsPerSample);

			IF (h.blockAlign*h.sRate # h.bRate) OR (h.nofCh*(h.bitsPerSample DIV 8) # h.blockAlign) THEN
				KernelLog.String("WAVDecoder - Inconsistent header info"); KernelLog.Ln;
				RETURN;
			END;

			len := h.waveFormatSize - 16;
			WHILE len > 0 DO c := in.Get(); DEC(len) END;

			REPEAT
				in.Bytes(h.chunkdata, 0, 4, res);
			UNTIL (res = 4) & (h.chunkdata = "data") OR (in.Pos() >= (h.fileSize + 8));

			IF (res # 4) OR (h.chunkdata # "data") THEN
				KernelLog.String("WAVDecoder - data header ID not found"); KernelLog.Ln;
				KernelLog.String("res= "); KernelLog.Int(res, 0);
				KernelLog.String("h.chunkdata= "); KernelLog.String(h.chunkdata);
				RETURN;
			END;

			ReadRawBELongInt(in, h.dataSize);

			hasMoreBytes := TRUE;

			res := 0
		END Open;

		PROCEDURE HasMoreData*():BOOLEAN;
		BEGIN
			RETURN hasMoreBytes
		END HasMoreData;

		PROCEDURE GetAudioInfo*(VAR nofChannels, samplesPerSecond, bitsPerSample : LONGINT);
		BEGIN
			nofChannels := h.nofCh;
			bitsPerSample := h.bitsPerSample;
			samplesPerSecond := h.sRate
		END GetAudioInfo;

		(* Dumps part of the header *)
		PROCEDURE DumpHeader;
		BEGIN
			KernelLog.String("-- WAV Header Data --"); KernelLog.Ln;
			KernelLog.String("h.nofCh= "); KernelLog.Int(h.nofCh, 0); KernelLog.Ln;
			KernelLog.String("h.sRate= "); KernelLog.Int(h.sRate, 0); KernelLog.Ln;
			KernelLog.String("h.bitsPerSample= "); KernelLog.Int(h.bitsPerSample, 0); KernelLog.Ln;
			KernelLog.String("h.bRate= "); KernelLog.Int(h.bRate, 0); KernelLog.Ln;
			KernelLog.String("h.blockAlign= "); KernelLog.Int(h.blockAlign, 0); KernelLog.Ln;
			KernelLog.String("h.fileSize= "); KernelLog.Int(h.fileSize, 0);
			KernelLog.String("h.dataSize= "); KernelLog.Int(h.dataSize, 0)
		END DumpHeader;

		PROCEDURE CanSeek*() : BOOLEAN;
		BEGIN
			KernelLog.String("Not Implemented");
			RETURN FALSE;
		END CanSeek;

		PROCEDURE GetCurrentSample*() : LONGINT;
		BEGIN
			RETURN ENTIER((in.Pos() - (h.fileSize - h.dataSize)) / h.bRate * h.sRate)
		END GetCurrentSample;

		PROCEDURE GetTotalSamples*() : LONGINT;
		BEGIN
			RETURN ENTIER(h.dataSize / h.bRate * h.sRate)
		END GetTotalSamples;

		(* Returns the current time in 1/10 sec *)
		PROCEDURE GetCurrentTime*() : LONGINT;
		BEGIN
			RETURN ENTIER((in.Pos() - (h.fileSize - h.dataSize)) / h.bRate * 10)
		END GetCurrentTime;

		PROCEDURE SetStreamLength*(length : LONGINT);
		BEGIN
			h.fileSize := length-8;
			h.dataSize := length-SIZEOF(WaveHeader);
		END SetStreamLength;

		PROCEDURE SeekSample*(sample: LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		VAR seekType: LONGINT;
		BEGIN
			seekType := Codecs.SeekByte;
			(* in.Seek(seekType, h.fileSize - h.dataSize + ENTIER(sample / h.sRate * h.bRate), itemSize, res); *)
			in.SetPos(h.fileSize - h.dataSize + ENTIER(sample / h.sRate * h.bRate))
		END SeekSample;

		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		BEGIN
			SeekSample(ENTIER(millisecond / 1000 * h.sRate), goKeySample, res)
		END SeekMillisecond;

		(** Prepare the next audio bytes not yet filled into a buffer *)
		PROCEDURE Next*;
		END Next;

		PROCEDURE FillBuffer*(buffer : SoundDevices.Buffer);
		BEGIN
			in.Bytes(buffer.data^, 0, LEN(buffer.data^), buffer.len);
			IF (in.res = Streams.EOF) OR (buffer.len < LEN(buffer.data)) THEN
				hasMoreBytes := FALSE;
				RETURN;
			END;
		END FillBuffer;
	END WAVDecoder;

	(* Audio PCM Decoder (WAV without header) *)
	PCMDecoder* = OBJECT(Codecs.AudioDecoder)
	VAR
		in: Streams.Reader;
		h : WaveHeader;
		hasMoreBytes : BOOLEAN;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		BEGIN
			res := -1;
			IF in = NIL THEN
				KernelLog.String("PCMDecoder - InputStream is NIL"); KernelLog.Ln;
				RETURN;
			END;
			SELF.in := in;

			hasMoreBytes := TRUE;
			res := 0
		END Open;

		PROCEDURE HasMoreData*():BOOLEAN;
		BEGIN
			RETURN hasMoreBytes
		END HasMoreData;

		PROCEDURE GetAudioInfo*(VAR nofChannels, samplesPerSecond, bitsPerSample : LONGINT);
		BEGIN
			nofChannels := h.nofCh;
			bitsPerSample := h.bitsPerSample;
			samplesPerSecond := h.sRate
		END GetAudioInfo;

		PROCEDURE SetAudioInfo*(nofChannels, samplesPerSecond, bitsPerSample : LONGINT);
		BEGIN
			h.nofCh := SHORT(nofChannels);
			h.bitsPerSample := SHORT(bitsPerSample);
			h.sRate := samplesPerSecond;
			(* calc the others *)
			h.bRate := h.nofCh * h.sRate * h.bitsPerSample DIV 8;
			h.blockAlign := h.nofCh * h.bitsPerSample DIV 8
		END SetAudioInfo;

		PROCEDURE CanSeek*() : BOOLEAN;
		BEGIN
			KernelLog.String("Not Implemented");
			RETURN FALSE;
		END CanSeek;

		PROCEDURE GetCurrentSample*() : LONGINT;
		BEGIN
			KernelLog.String("pi= ");
			RETURN ENTIER(8 * in.Pos() / h.bitsPerSample / h.nofCh)
		END GetCurrentSample;

		PROCEDURE GetTotalSamples*() : LONGINT;
		BEGIN
			KernelLog.String("pa= ");
			RETURN ENTIER(8 * h.dataSize / h.bitsPerSample / h.nofCh)
		END GetTotalSamples;

		(* Returns the current time in 1/10 sec *)
		PROCEDURE GetCurrentTime*() : LONGINT;
		BEGIN
			KernelLog.String("po= ");
			RETURN ENTIER(8 * in.Pos() / h.bitsPerSample / h.nofCh / h.sRate * 10)
		END GetCurrentTime;

		PROCEDURE SetStreamLength*(length : LONGINT);
		BEGIN
			h.fileSize := length+SIZEOF(WaveHeader)-8;
			h.dataSize := length
		END SetStreamLength;

		PROCEDURE SeekSample*(sample: LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		VAR seekType: LONGINT;
		BEGIN
			KernelLog.String("pu= "); KernelLog.Int(sample, 0);
			KernelLog.String("bi= "); KernelLog.Int(h.bitsPerSample, 0);
			seekType := Codecs.SeekByte;
			(* in.Seek(seekType, ENTIER(sample * h.bitsPerSample / 8 * h.nofCh), itemSize, res); *)
			in.SetPos(ENTIER(sample * h.bitsPerSample / 8 * h.nofCh))
		END SeekSample;

		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		BEGIN
			SeekSample(ENTIER(millisecond / 1000 * h.sRate), goKeySample, res)
		END SeekMillisecond;

		(** Prepare the next audio bytes not yet filled into a buffer *)
		PROCEDURE Next*;
		END Next;

		PROCEDURE FillBuffer*(buffer : SoundDevices.Buffer);
		BEGIN
			in.Bytes(buffer.data^, 0, LEN(buffer.data^), buffer.len);
			IF (in.res = Streams.EOF) OR (buffer.len < LEN(buffer.data)) THEN
				hasMoreBytes := FALSE; KernelLog.String("BOOOOM!!");
				RETURN;
			END;
		END FillBuffer;
	END PCMDecoder;

(* Routines for reading and writing numbers in Intel's big endian format *)
PROCEDURE ReadRawBEInteger(VAR r: Streams.Reader; VAR value: INTEGER);
BEGIN
	value := ORD(r.Get()) + 100H *ORD(r.Get());
END ReadRawBEInteger;

PROCEDURE ReadRawBELongInt(VAR r: Streams.Reader; VAR value: LONGINT);
BEGIN
	value := LONG(ORD(r.Get())) + 100H * LONG(ORD(r.Get()))
		+ 10000H * LONG(ORD(r.Get())) + 1000000H * LONG(ORD(r.Get()));
END ReadRawBELongInt;

PROCEDURE WriteRawBEInteger(VAR w: Streams.Writer; value: INTEGER);
BEGIN
	w.Char(CHR(value MOD 100H));
	w.Char(CHR(value DIV 100H));
END WriteRawBEInteger;

PROCEDURE WriteRawBELongInt(VAR w: Streams.Writer; value: LONGINT);
BEGIN
	w.Char(CHR(value MOD 100H));
	value := value DIV 100H;
	w.Char(CHR(value MOD 100H));
	value := value DIV 100H;
	w.Char(CHR(value MOD 100H));
	w.Char(CHR(value DIV 100H));
END WriteRawBELongInt;

(* -- Factories -- *)
PROCEDURE EncoderFactory*() : Codecs.AudioEncoder;
VAR p : WAVEncoder;
BEGIN
	NEW(p);
	RETURN p
END EncoderFactory;

PROCEDURE DecoderFactory*() : Codecs.AudioDecoder;
VAR p : WAVDecoder;
BEGIN
	NEW(p);
	RETURN p
END DecoderFactory;

PROCEDURE PCMDecoderFactory*() : Codecs.AudioDecoder;
VAR p : PCMDecoder;
BEGIN
	NEW(p);
	RETURN p
END PCMDecoderFactory

END WAVCodec.

------------------------------------------------------------------------------

SystemTools.Free WAVCodec;
