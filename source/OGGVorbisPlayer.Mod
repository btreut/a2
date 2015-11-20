(** AUTHOR "Christian Wassmer, chwassme@student.ethz.ch";
	 PURPOSE "an audio-player for Ogg/Vorbis-radiostations and -files";
	 DATE "Avril 2004" *)
MODULE OGGVorbisPlayer;

IMPORT
	SYSTEM, Strings, KernelLog, Streams, Files, Commands, SoundDevices, BIT, Math,
	OGGUtilities, Modules, Kernel,
	TCP, WebHTTP, WebHTTPClient;

CONST
	(* Debugging Set *)
	Trace = 1;
	Error = 2;
	Codec = 3;
	Debug = {Error};

	(* oggstream-types, are also recognition-pattern for calling the correct decoder *)
	Vorbis = "vorbis";
	CodebookSynchPattern = 564342H;

	(* return codes *)
	Ok = 0;
	ErrorIdentification = 1;
	ErrorSetup = 2;
	ErrorDataPacket = 3;
	PacketTooBig = 4;
	InvalidSerialNumber = 5;
	UnexpectedEOS = 6;
	OggStreamNotFound = 7;
	NoDecoderFound = 8;
	LogicalOggStreamFinished = 8;
	ErrorCapturePattern = 9;
	TooManyLogicalOggStreams = 10;
	NoDataPacket = 11;
	InvalidCodebookNumber = 12;
	ChannelNotUsed = 13;
	PacketUndecodable = 14;
	ErrorWindowDecode = 15;

	(* maximum ogg-page-size, as defined in the specs *)
	MaxPageSize = 65307;

	(* length of all header field of an Ogg-page *)
	BaseHeaderLength = 27;

	(* 'vorbis' as example, others seems to be also of the same length*)
	OggStreamTypeLength = 6;

	(* constants for sound output *)
	MaxChannels* = 6;
	DefaultSamplingResolution = 16;

	(* data structure constants *)
	MaxNrOfSegments = 255;
	MaxLogicalStreams = 8;
	MaxVendorLength = 64;
	MaxCommentLength = 256;
	MaxNumberOfCodebooks = 256;
	MaxNumberOfMultiplicands = 65536;
	MaxNumberOfFloors = 64;
	MaxNumberOfResidues = 64;
	MaxNumberOfMappings = 64;
	MaxNumberOfModes = 64;
	Floor0BookListSize = 16;
	Floor1PartitionClassListSize = 32;
	Floor1ClassSize = 16;
	Floor1SubclassSize = 16;
	Floor1XListSize = 256; (* >= 32 * 7 + 7 *)
	ResidueCascadeSize = 64;
	ResidueBookSize = 64;
	MappingMagnitudeSize = 256;
	MappingMuxSize = 256;
	MappingSubmapFloorSize = 16;
	(* floor1Y: 0..288 = 32 * (3 bit "+ 1") *)
	Floor1Final = 288;
	(* used for partword01, partword2 and decodemap (residues) *)
	PartwordSize = 8;
	NrOfBlocksizes = 8;
	InverseDBLookupSize = 256;

	(* some marker constants *)
	ResidueBookUnused = -1;
	UnusedCodebookEntry = -2;
	(* returned by AbstractFloorType::DecodePacket() if the floor is unused *)
	SerialNumberUnset = -4;

VAR
	frameCnt: LONGINT;
	OggS: ARRAY 4 OF CHAR;
	nrOfPages: LONGINT;
	FloorRanges: ARRAY 4 OF LONGINT;
	InverseDBLookup: ARRAY InverseDBLookupSize OF LONGINT;

	(** state of the player *);
	stopped*, playing*: BOOLEAN;

TYPE
	BitReader = OBJECT
		VAR
			r: Streams.Reader;
			bsBuff, bsLive: LONGINT;
			bytesRead: LONGINT;

			PROCEDURE &Init*(r: Streams.Reader);
			BEGIN
				SELF.r := r;
				bsLive := 0
			END Init;

			(* is stream still available *)
			PROCEDURE IsOk() : BOOLEAN;
			BEGIN
				RETURN r.res = Streams.Ok
			END IsOk;

			(* get the number of bytes read *)
			PROCEDURE GetBytesRead(): LONGINT;
			BEGIN
				RETURN SELF.bytesRead
			END GetBytesRead;

			(* read a number of bits (lsb first) from the reader (max: 32)
				note: if n is 32 (bigger is not allowed) then the last bit will be interpreted as the sign
				and may give wrong results, otherwise the sign-bit of the returned longint will not be affected anyway *)
			PROCEDURE GetBits(n: LONGINT): LONGINT;
			VAR r, factor: LONGINT;
			BEGIN
				r := 0; factor := 1;
				WHILE (n > 0) DO
					r := r + factor * GetBit();
					factor := factor * 2;
					DEC(n)
				END;
				RETURN r
			END GetBits;

			(* get the next bit from the stream (lsb first) *)
			PROCEDURE GetBit(): LONGINT;
			VAR res: LONGINT;
			BEGIN
				IF (bsLive = 0) THEN
					bsBuff := ORD(r.Get());
					IF (r.res = Streams.Ok) THEN bsLive := 8
					ELSE StreamEOF()
					END;
					INC(bytesRead)
				END;
				DEC(bsLive);
				res := bsBuff MOD 2;
				bsBuff := bsBuff DIV 2;
				RETURN res;
			END GetBit;

			(* get a hugeint *)
			PROCEDURE GetHugeInt(): HUGEINT;
			VAR
				huge: HUGEINT;
			BEGIN
				huge := GetBits(16);
				huge := huge + 10000H * GetBits(16);
				huge := huge + 10000H * GetBits(16);
				huge := huge + 10000H * GetBits(16);
				RETURN huge
			END GetHugeInt;

			(* get a char *)
			PROCEDURE GetChar(): CHAR;
			BEGIN
				RETURN CHR(GetBits(8))
			END GetChar;

			PROCEDURE StreamEOF;
			BEGIN
				KernelLog.String("unexpected end of stream"); KernelLog.Ln;
				RETURN
			END StreamEOF;
	END BitReader;

	(* read from a buffer, returning various sized integers *)
	BufferReader = OBJECT
		VAR
			bsBuff, bsLive, pos, len: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			bsLive := 0; pos := 0; len := 0
		END Init;


		(* print the state of it *)
		PROCEDURE Print;
		BEGIN
			OGGUtilities.String("*** state of BufferReader ***");
			OGGUtilities.Var("bsLive", bsLive);
			OGGUtilities.Var("len", len);
			OGGUtilities.Var("pos", pos);
			OGGUtilities.String("*** --- ***")
		END Print;

		PROCEDURE SetLen(len: LONGINT);
		BEGIN
			SELF.len := len
		END SetLen;

		PROCEDURE GetLen(): LONGINT;
		BEGIN
			RETURN SELF.len
		END GetLen;

		(* is buffer still available *)
		PROCEDURE IsOk(VAR buf: ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			RETURN ((LEN(buf) # pos) & (len # pos));
		END IsOk;

		(* get the current position in the buffer *)
		PROCEDURE GetPos(): LONGINT;
		BEGIN
			RETURN pos
		END GetPos;

		PROCEDURE GetBitCount(): LONGINT;
		BEGIN
			RETURN (pos - 1) * 8 + (8 - bsLive)
		END GetBitCount;

		(* get the current byte from the buffer as a longint *)
		PROCEDURE GetCurByte(VAR buf: ARRAY OF CHAR): LONGINT;
		BEGIN
			RETURN ORD(buf[pos])
		END GetCurByte;

		(* get the next bit from the buffer (lsb first) *)
		PROCEDURE GetBit(VAR buf: ARRAY OF CHAR): LONGINT;
		VAR res: LONGINT;
		BEGIN
			IF ((LEN(buf) # pos) & (len # pos) & (bsLive = 0)) THEN
				bsBuff := ORD(buf[pos]);
				bsLive := 8;
				INC(pos)
			END;
			DEC(bsLive);
			res := bsBuff MOD 2;
			bsBuff := bsBuff DIV 2;
			RETURN res
		END GetBit;

		(* read a number of bits (lsb first) from the buffer (max: 32)
				note: if n is 32 (bigger is not allowed) then the last bit will be interpreted as the sign (by the processor)
				and may give wrong results, otherwise the sign-bit of the returned longint will not be affected anyway *)
		PROCEDURE GetBits(VAR buf: ARRAY OF CHAR; n: LONGINT): LONGINT;
		VAR r, factor: LONGINT;
		BEGIN
			r := 0;
			factor := 1;
			WHILE (n > 0) DO
				r := r + factor * GetBit(buf);
				factor := factor * 2;
				DEC(n)
			END;
			RETURN r
		END GetBits;

		(* get a hugeint *)
		PROCEDURE GetHugeInt(VAR buf: ARRAY OF CHAR): HUGEINT;
		VAR
			huge: HUGEINT;
		BEGIN
			huge := GetBits(buf, 16);
			huge := huge + 10000H * GetBits(buf, 16);
			huge := huge + 10000H * GetBits(buf, 16);
			huge := huge + 10000H * GetBits(buf, 16);
			RETURN huge
		END GetHugeInt;

		(* get a 32 bit unsigned integer *)
		PROCEDURE Get32UnsignedBits (VAR buf: ARRAY OF CHAR): HUGEINT;
		VAR
			res: HUGEINT;
			tmp: LONGINT;
			BEGIN
			tmp := 1;
			res := GetBits(buf, 31) + GetBit(buf) * LSH(tmp, 31);
			RETURN res;
		END Get32UnsignedBits;

		(* get the next char *)
		PROCEDURE GetChar (VAR buf: ARRAY OF CHAR): CHAR;
		BEGIN
			RETURN CHR(GetBits(buf, 8))
		END GetChar;
	END BufferReader;

	OggPageHeader = RECORD
		headerTypeFlag, pageSegments,pageSize,headerLength, streamSerialNo: LONGINT;
		pageNo, checksum, absGranulePos: HUGEINT;
		segTable: ARRAY MaxNrOfSegments OF LONGINT
	END;

	OggPage = RECORD
		buf: ARRAY MaxPageSize OF CHAR;
		header: OggPageHeader
	END;

	(* not really a stream, more a structure to keep stream-serialnumber, decoder and it's type together *)
	LogicalOggStream = OBJECT
		VAR
			serialNumber*: LONGINT;
			decoder*: Decoder;
			soundOutput: SoundOutput;
			type*: ARRAY OggStreamTypeLength OF CHAR;
			finished*: BOOLEAN;

		(* init a new LogicalOggStream, type must have a length of 6 *)
		PROCEDURE &Init*(dec: Decoder; soundOutput: SoundOutput; type: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ LogicalOggStream::Init()")
			END;
			serialNumber := SerialNumberUnset;
			SELF.decoder := dec;
			SELF.soundOutput := soundOutput;
			IF (LEN(type)- 1 # OggStreamTypeLength) THEN
				KernelLog.String("ASSERTION failed - type-string isn't 0X terminated"); KernelLog.Ln
			END;
			ASSERT(LEN(type) - 1= OggStreamTypeLength); (* -1: string is 0X terminated *)
			FOR i:=0 TO OggStreamTypeLength-1 DO SELF.type[i] := type[i] END;
			finished := FALSE
		END Init;
	END LogicalOggStream;

	 OggStreamReader* = OBJECT
		VAR
			bitReader: BitReader;
			page: OggPage;
			streams: ARRAY MaxLogicalStreams OF LogicalOggStream;
			nrOfStreams*: LONGINT;

		(* init the OggStreamReader *)
		PROCEDURE &Init*(reader: Streams.Reader);
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ Init()");
			END;
			NEW(SELF.bitReader, reader);
			nrOfStreams := 0;
			stopped := FALSE;
			playing := FALSE;
		END Init;

		(** register an ogg-stream decoder of a given oggstream-type, type must have a length of 6*)
		PROCEDURE RegisterDecoder*(dec: Decoder; soundOutput: SoundOutput; type: ARRAY OF CHAR): LONGINT;
		VAR
			logOggStream: LogicalOggStream;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ RegisterDecoder()");
			END;
			IF nrOfStreams < MaxLogicalStreams THEN
				NEW(logOggStream, dec, soundOutput, type);
				streams[nrOfStreams] := logOggStream;
				INC(nrOfStreams);
				RETURN Ok
			ELSE
				IF (Error IN Debug) THEN
					OGGUtilities.Var("no more logical streams allowed, maximum", MaxLogicalStreams);
				END;
				RETURN TooManyLogicalOggStreams
			END
		END RegisterDecoder;

		(** unregister an logical ogg-stream , usually used when it's finished *)
		PROCEDURE UnregisterLogicalOggStream*(stream: LogicalOggStream);
		VAR
			i: LONGINT;
			found: BOOLEAN;
		BEGIN
			i := 0; found := FALSE;
			WHILE ((i # nrOfStreams) & (~found)) DO
				IF streams[i] = stream THEN
					found := TRUE;
					streams[i] := NIL
				ELSE
					INC(i)
				END;
			END;
			(* shift the remaining streams into the generated gap *)
			IF found THEN
				DEC(nrOfStreams);
				WHILE (i # nrOfStreams) DO
					streams[i] := streams[i+1]; INC(i)
				END
			END
		END UnregisterLogicalOggStream;

		(* dispatches a whole ogg-page to the correspondant Decoder by calling DecodePage() *)
		PROCEDURE Dispatch(VAR oggStream: LogicalOggStream);
		VAR
			type: ARRAY OggStreamTypeLength OF CHAR;
			firstPage: BOOLEAN;
			pos, i: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ Dispatch()")
			END;
			firstPage := (((page.header.headerTypeFlag DIV 2) MOD 2) = 1);

			(* determine packet type and get correct LogicalOggStream *)
			pos := page.header.headerLength + 1; (* set current position to start packet identification string *)
			IF firstPage THEN
				i := 0;
				pos := 1(* page.header.headerLength + 1 *); (* set current position to start packet identification string *)
				WHILE (i # OggStreamTypeLength) DO (* get type-string *)
					type[i] := page.buf[pos + i];
					INC(i)
				END;
				oggStream := GetLogicalOggStreamByType(type); (* find it's LogicalOggStream *)
				(* and update it's serial-number *)
				IF oggStream # NIL THEN oggStream.serialNumber := page.header.streamSerialNo END
			ELSE oggStream := GetLogicalOggStreamBySerialNr(page.header.streamSerialNo)
			END;
		END Dispatch;

		PROCEDURE DecodePage(VAR oggStream: LogicalOggStream): LONGINT;
		VAR
			res, seg, pos, len, i: LONGINT;
			decodingSuccess: BOOLEAN;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ DecodePage()");
			END;
			decodingSuccess := TRUE;
			len := 0; i := 0; pos := 1 + OggStreamTypeLength;
			(* while there are more lacing-values *)
			WHILE (i # page.header.pageSegments) DO
				seg := page.header.segTable[i];
				INC(len,seg);
				(* new packets are indicated by a number unequal to 255 *)
				IF (seg # 255) THEN
					res := oggStream.decoder(page.buf, pos, len, FALSE, oggStream.soundOutput);
					INC(pos,len);
					len := 0
				END;
				IF res # Ok THEN RETURN res END;
				INC(i)
			END;
			IF (seg = 255) THEN
				res := oggStream.decoder(page.buf, pos, len, TRUE, oggStream.soundOutput)
			END;
			RETURN res
		END DecodePage;

		(* get a LogicalOggStream by serial-number *)
		PROCEDURE GetLogicalOggStreamBySerialNr(serialNr: LONGINT): LogicalOggStream;
		VAR
			i: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ GetLogicalOggStreamBySerialNr()")
			END;
			i := 0;
			WHILE (i # nrOfStreams) DO
				IF streams[i].serialNumber = serialNr THEN RETURN streams[i] END;
				INC(i);
			END;
			IF (Error IN Debug) THEN
				OGGUtilities.String("no oggStream (by serialnr) found !!!")
			END;
			RETURN NIL
		END GetLogicalOggStreamBySerialNr;

		(* get a LogicalOggStream by type-string *)
		PROCEDURE GetLogicalOggStreamByType(type: ARRAY OF CHAR): LogicalOggStream;
		VAR
			i, j: LONGINT;
			oggStream: LogicalOggStream;
			found: BOOLEAN;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ GetLogicalOggStreamBySerialType()")
			END;
			found := FALSE; i := 0;
			WHILE (~found) & (i # nrOfStreams) DO
				oggStream := streams[i]; j := 0;
				WHILE (j # OggStreamTypeLength) & (oggStream.type[j] = type[j]) DO INC(j) END;
				found := (j = OggStreamTypeLength);
				INC(i)
			END;
			IF ~found THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("no oggStream (by type) found !!!")
				END;
				RETURN NIL
			ELSE
				RETURN oggStream
			END
		END GetLogicalOggStreamByType;

		PROCEDURE Stop*;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO LEN(streams) - 1 DO
				IF streams[i] # NIL THEN
					streams[i].soundOutput.CloseSoundChannel()
				END
			END
		END Stop;


		(** start playing an ogg-stream *)
		PROCEDURE Start*(): LONGINT;
		VAR
			retCode: LONGINT;
			lastPage: BOOLEAN;
			oggStream: LogicalOggStream;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ Start()");
			END;

			(* start a loop for all logical ogg-stream header packets *)
			LOOP
				(* if playback is stopped from outside ... *)
				IF stopped THEN
					KernelLog.String("playback stopped"); KernelLog.Ln;
					stopped := FALSE;
					playing := FALSE;
					RETURN retCode;
				END;
				retCode := NextPage(); (* (try to) read the next ogg-page *)
				IF retCode = Ok THEN

					(* get the right LogicalOggStream *)
					Dispatch(oggStream);

					(* if a LogicalOggStream found, call it's Decode()-procedure *)
					IF (oggStream # NIL) & (~oggStream.finished) THEN
						lastPage := (((page.header.headerTypeFlag DIV 4) MOD 2) = 1);
						IF lastPage THEN oggStream.finished := TRUE END;

						(* try to decode it *)
						retCode := DecodePage(oggStream);

						(* if it is finished then unregister it *)
						IF oggStream.finished THEN
							UnregisterLogicalOggStream(oggStream);
							oggStream.soundOutput.CloseSoundChannel();
							retCode := LogicalOggStreamFinished
						ELSE
							retCode := Ok
						END
					ELSIF oggStream = NIL THEN retCode := NoDecoderFound
					END;

					IF retCode # Ok THEN
						(* if no logical ogg-stream is left, the physical ogg-stream is finished correctly *)
						IF nrOfStreams = 0 THEN RETURN Ok ELSE RETURN retCode END
					END
				ELSE
					RETURN retCode
				END;
				IF ~bitReader.IsOk() THEN
					RETURN UnexpectedEOS
				END
			END; (* LOOP *)
			RETURN Ok
		END Start;

		(* reads the next page of the stream buffering its content *)
		PROCEDURE NextPage(): LONGINT;
		VAR
			res, i: LONGINT;
			ch: CHAR;
		BEGIN
			(* look for the capture pattern *)
			i := 0;
			ch := bitReader.GetChar();
			WHILE (i # 4) & (ch = OggS[i]) DO
				ch := bitReader.GetChar();
				INC(i)
			END;
			IF (i#4) THEN RETURN ErrorCapturePattern ELSE res := Ok END;

			(* continue with the header, step-by-step *)
			(* stream structure version already done (read one step ahead in previous loop *)
			page.header.headerTypeFlag := bitReader.GetBits(8);
			page.header.absGranulePos := bitReader.GetHugeInt();
			page.header.streamSerialNo := bitReader.GetBits(32);
			page.header.pageNo := bitReader.GetBits(32);
			page.header.checksum := bitReader.GetBits(32);
			page.header.pageSegments := bitReader.GetBits(8);
			page.header.headerLength := page.header.pageSegments + BaseHeaderLength;

			(* calculate page size and save segment sizes *)
			page.header.pageSize := 0;
			FOR i := 0 TO page.header.pageSegments-1 DO
				page.header.segTable[i] := (bitReader.GetBits(8)); (* SHORT(.) removed *)
				page.header.pageSize := page.header.pageSize + page.header.segTable[i];
			END;

			(* buffer whole page *)
			FOR i:=0 TO page.header.pageSize-1 DO
				ch := bitReader.GetChar();
				page.buf[i] := ch;
			END;
			INC(nrOfPages);
			RETURN res
		END NextPage;
	END OggStreamReader;

	(* simple data-container for decoding *)
	DecoderState = OBJECT
		VAR
			(* internal state *)
			bufferAllocated: BOOLEAN;

			(* some single information *)
			resSize, n, residueType, cacheSize, lastWindowFlag, nrOfSamples: LONGINT;
			preCached: BOOLEAN;

			(* information needed during decoding process *)
			codec: CodecSetup;
			mode: Mode;
			mapping: Mapping;
			win: Window;
			info: Info;
			resInfo: ResidueInfo;

			(* buffers for temporary and final (floor) data *)
			floor, rightCache, residues: ARRAY MaxChannels OF OGGUtilities.PCMBuffer;

			(* Residue *)
			residuePartitionProc: ARRAY 3 OF ResiduePartitionProc;
			doNotDecode, noResidue: ARRAY MaxChannels OF BOOLEAN;
			residueNumbers: ARRAY MaxChannels OF LONGINT; (* stores info of residue vector of each channel *)

			(* FloorType1 *)
			floor1Y: ARRAY Floor1Final OF LONGINT;
			floor1Step2Flag: ARRAY Floor1Final OF BOOLEAN;

		PROCEDURE &Init*(channels: LONGINT);
		BEGIN
			bufferAllocated := FALSE;
			NEW(codec);
			NEW(resInfo);
			residuePartitionProc[0] := ResiduePartitionProc0;
			residuePartitionProc[1] := ResiduePartitionProc1;
			residuePartitionProc[2] := ResiduePartitionProc2
		END Init;

		PROCEDURE AllocateBuffers(channels: LONGINT);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO channels - 1 DO
				NEW(residues[i]);
				NEW(floor[i]);
				NEW(rightCache[i])
			END;
			bufferAllocated := TRUE
		END AllocateBuffers;
	END DecoderState;

	(** contains information about current window sizes during decode process *)
	Window = OBJECT
		VAR
			small, long: LONGINT;
			center*, leftStart*, leftEnd*, leftSize*, rightStart*, rightEnd*, rightSize*: LONGINT;
			lookupsLeft*, lookupsRight*: ARRAY 2 OF Slope;

		PROCEDURE &Init*(small, long: LONGINT);
		BEGIN
			SELF.small := small DIV 2;
			SELF.long := long DIV 2;

			NEW(lookupsLeft[0], SELF.small, SlopeLeft);
			NEW(lookupsLeft[1], SELF.long, SlopeLeft);

			NEW(lookupsRight[0], SELF.small, SlopeRight);
			NEW(lookupsRight[1], SELF.long, SlopeRight)
		END Init;

		(* return the correct lookup-table index for blocksize n *)
		PROCEDURE GetLookupTable(n: LONGINT): LONGINT;
		BEGIN
			IF n = small THEN
				RETURN 0
			ELSIF n = long THEN
				RETURN 1
			END
		END GetLookupTable;

		PROCEDURE ApplyWindow(VAR data: ARRAY OF HUGEINT; VAR decState: DecoderState);
		VAR i, rIdx, lIdx, n: LONGINT;
		BEGIN
			lIdx := GetLookupTable(leftSize);
			rIdx := GetLookupTable(rightSize);
			n := decState.n;
			IF (decState.mode.windowType = 0) THEN
				FOR i := 0 TO leftStart - 1 DO
					(* no data from this area *)
					data[i] := 0
				END;
				FOR i := leftStart TO leftEnd - 1 DO
					(* increasing window *)
					data[i] := OGGUtilities.MultHugeFP(data[i], lookupsLeft[lIdx].data[i - leftStart])
				END;
				(* in between window is equal 1 => do nothing *)
				FOR i := rightStart TO rightEnd - 1 DO
					(* descending window *)
					data[i] := OGGUtilities.MultHugeFP(data[i], lookupsRight[rIdx].data[i - rightStart])
				END;
				FOR i := rightEnd TO n - 1 DO
					(* no data from this area *)
					data[i] := 0
				END
			ELSE
				IF (Error IN Debug) THEN
					KernelLog.String("ERROR @ VorbisCodec::Window::ApplyWindows() - undefined windowType");
					KernelLog.Ln
				END
			END;
		END ApplyWindow;

		PROCEDURE Print;
		BEGIN
			OGGUtilities.String("### Window ###");
			OGGUtilities.Var("center", center);
			OGGUtilities.Var("leftStart", leftStart);
			OGGUtilities.Var("leftEnd", leftEnd);
			OGGUtilities.Var("leftSize", leftSize);
			OGGUtilities.Var("rightStart", rightStart);
			OGGUtilities.Var("rightEnd", rightEnd);
			OGGUtilities.Var("rightSize", rightSize);
			OGGUtilities.String("### END ")
		END Print;
	END Window;

	Slope = OBJECT
		VAR data: ARRAY OGGUtilities.MaxBlocksize OF LONGINT;
			length: LONGINT;

		PROCEDURE &Init*(length: LONGINT; slope: SlopeFunction);
		VAR i: LONGINT;
			tmp: REAL;
		BEGIN
			SELF.length := length;
			FOR i := 0 TO length - 1 DO
				tmp := slope(i, length);
				data[i] := OGGUtilities.ScaleUp(tmp);
			END
		END Init;

		PROCEDURE Print;
		BEGIN
			PrintLen(length);
		END Print;

		PROCEDURE PrintLen(len: LONGINT);
		BEGIN
			OGGUtilities.String("### SLOPE ###");
			OGGUtilities.Var("length", length);
			OGGUtilities.ArrayLen("data", data, len);
			OGGUtilities.String("### END (slope) ###");
		END PrintLen;
	END Slope;

	AbstractFloorType = OBJECT
		(** no common fields yet *)

		(** abstract method *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
									VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		BEGIN
			HALT(301)
		END DecodeHeader;

		(** abstract method *)
		PROCEDURE DecodePacket(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR; VAR decState: DecoderState): LONGINT;
		BEGIN
			HALT(301)
		END DecodePacket;

		(** abstract method *)
		PROCEDURE ComputeCurve(VAR decState: DecoderState; ch: LONGINT);
		BEGIN
			HALT(301)
		END ComputeCurve;

		(** abstract method *)
		PROCEDURE Print;
		BEGIN
			HALT(301)
		END Print;
	END AbstractFloorType;

(*
	(* FloorType0 is no longer supported by Xiph.Org and therefore nearly deprecated *)
	FloorType0 = OBJECT(AbstractFloorType)
		VAR
			order, rate, barkMapSize, amplitudeBits, amplitudeOffset, numberOfBooks: LONGINT;
			bookList: ARRAY Floor0BookListSize OF LONGINT;

		(** print to the logfile *)
		PROCEDURE Print;
		BEGIN
			(*
			OGGUtilities.String("### FloorType0 ###");
			OGGUtilities.Var("order", order);
			OGGUtilities.Var("rate", rate);
			OGGUtilities.Var("barkMapSize", barkMapSize);
			OGGUtilities.Var("amplitudeBits", amplitudeBits);
			OGGUtilities.Var("amplitudeOffset", amplitudeOffset);
			OGGUtilities.Var("numberOfBooks", numberOfBooks);
			OGGUtilities.Array("bookList", bookList);
			OGGUtilities.String("### END (FloorType0) ###"); OGGUtilities.String("")
			*)
		END Print;

		(** decode floor0-description from codec setup header*)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
									VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		BEGIN
			(*
			order := bufReader.GetBits(buf, 8);
			rate := bufReader.GetBits(buf, 16);
			barkMapSize := bufReader.GetBits(buf, 16);
			amplitudeBits := bufReader.GetBits(buf, 6);
			amplitudeOffset := bufReader.GetBits(buf, 8);
			numberOfBooks := bufReader.GetBits(buf, 4) + 1;
			FOR i := 0 TO numberOfBooks - 1 DO
				bookList[i] := bufReader.GetBits(buf, 8);
				IF (bookList[i] > info.codec.codebookCnt) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@VorbisCodec::Floor0::DecodeHeader() - invalid codebook number (too big)")
					END;
					RETURN FALSE
				END
			END;
			*)
			RETURN TRUE
		END DecodeHeader;

		PROCEDURE DecodePacket(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR; VAR decState: DecoderState): LONGINT;
	(*	VAR
			amplitude, booknumber, lookupOffset: LONGINT;
			lastFP: HUGEINT;
			codebook: Codebook; *)
		BEGIN
		(*
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@VorbisCodec::FloorType0::DecodePacket()")
			END;
			amplitude := bufReader.GetBits(buf, amplitudeBits);
			IF (amplitude > 0) THEN
				booknumber := bufReader.GetBits(buf, OGGUtilities.ILog(numberOfBooks));
				codebook := decState.codec.codebooks[booknumber];
				decState.coeffVectorFP.Init;
				IF (booknumber >= decState.codec.codebookCnt) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@VorbisCodec::Floor0::DecodePacket() - invalid codebook number")
					END;
					RETURN InvalidCodebookNumber
				END;
				lastFP := 0; (* lastval from docu [8] eliminated (seems strange) *)
				REPEAT
					lookupOffset := codebook.GetCodeword(bufReader, buf);
					codebook.GetVectorVQ(decState.tempVectorFP, lookupOffset);
					decState.tempVectorFP.Increase(lastFP);
					lastFP := decState.tempVectorFP.GetLast();
					decState.coeffVectorFP.Concatenate(decState.tempVectorFP);
					decState.tempVectorFP.Init;
				UNTIL (decState.coeffVectorFP.GetLen() >= order)
			ELSE
				RETURN ChannelNotUsed
			END;
			*)
			RETURN Ok
		END DecodePacket;

		PROCEDURE ComputeCurve(VAR decState: DecoderState; ch: LONGINT);
			(*
		VAR
			n, i, linearFloorValue, iterationCond: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@FloorType0::ComputeCurve()")
			END;
			n := decState.codec.blocksizes[decState.mode.blockflag] DIV 2;

			(* calculate barkmap *)
			FOR i := 0 TO n-1 DO
				decState.barkMap[i] := Bark((rate * i) / (2 * n)) * barkMapSize DIV Bark(rate DIV 2);
				IF (barkMapSize - 1 < decState.barkMap[i]) THEN decState.barkMap[i] := barkMapSize - 1 END
			END;
			decState.barkMap[n] := -1;

			i := 0;
			LOOP
				IF (order MOD 2 = 1) THEN (* if order is odd *)
					(* TO DO: calculate p and q like this *)
				ELSE
					(* TO DO: calculate p and q like that *)
				END;
				(* TO DO: calculate linearFloorValue *)
				iterationCond := decState.barkMap[i];
				LOOP
					(* TO DO: output element i = linearFloorValue *)
					INC(i);
					IF (decState.barkMap[i] # iterationCond) THEN EXIT END (* else continue inner loop *)
				END;
				IF (i >= n) THEN EXIT END; (* else continue outer loop *)
			END
			*)
		END ComputeCurve;

		(* calculate a bark value *)
		PROCEDURE Bark(x: REAL): LONGINT;
			(*
		VAR res: REAL;
		BEGIN
			res := 13.1 * Math.arctan(0.00074 * x);
			res := res + 2.24 * Math.arctan(0.0000000158 * x * x);
			res := res + 0.0001 * x;
			RETURN ENTIER(res)
			*)
		END Bark;
	END FloorType0;
*)

	FloorType1 = OBJECT(AbstractFloorType)
		VAR
			partitions*, multiplier*, rangebits*, maxClass*, values*: LONGINT;
			partitionClassList*: ARRAY Floor1PartitionClassListSize OF LONGINT;
			classDimensions*, classSubclasses*, classMasterbooks*: ARRAY Floor1ClassSize OF LONGINT;
			subclassBooks*: ARRAY Floor1ClassSize, Floor1SubclassSize OF LONGINT;
			xList*, xListSortPtr: ARRAY Floor1XListSize OF LONGINT;
			xListSize*, confNr*: LONGINT;

		PROCEDURE &Init*;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Floor1XListSize - 1 DO
				xListSortPtr[i] := i
			END
		END Init;

		(** print to the logfile *)
		PROCEDURE Print;
		VAR i: LONGINT;
		BEGIN
			OGGUtilities.String("### FloorType1 ###");
			OGGUtilities.Var("partitions", partitions);
			OGGUtilities.Var("multiplier", multiplier);
			OGGUtilities.Var("rangebits", rangebits);
			OGGUtilities.Var("maxClass", maxClass);
			OGGUtilities.Var("values", values);
			OGGUtilities.Var("xListSize", xListSize);
			OGGUtilities.Array("partitionsClassList", partitionClassList);
			OGGUtilities.Array("classDimensions", classDimensions);
			OGGUtilities.Array("classSubclasses", classSubclasses);
			OGGUtilities.Array("classMasterbooks", classMasterbooks);
			OGGUtilities.Array("xList", xList);
			FOR i := 0 TO Floor1ClassSize - 1 DO
				OGGUtilities.Var("subclassBookNr", i);
				OGGUtilities.Array("subclassBook", subclassBooks[i])
			END;
			OGGUtilities.String("### END (FloorType1) ###"); OGGUtilities.String("")
		END Print;

		PROCEDURE ComputeCurve(VAR decState: DecoderState; ch: LONGINT);
		VAR
			i: LONGINT;
			range, lowNeighborOff, highNeighborOff, predicted, val, highroom, lowroom, room: LONGINT; (* step 1 variables *)
			n, hx, hy, lx, ly: LONGINT; (* step 2 variables *)
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@VorbisCodec::FloorType1::ComputeCurve()")
			END;
			(* step 1: amplitude value synthesis *)
			range := FloorRanges[multiplier-1];
			decState.floor1Step2Flag[0] := TRUE;
			decState.floor1Step2Flag[1] := TRUE;

			FOR i := 2 TO values - 1 DO
				lowNeighborOff := OGGUtilities.LowNeighbor(xList, i);
				highNeighborOff := OGGUtilities.HighNeighbor(xList, i);
				predicted := OGGUtilities.RenderPoint(xList[lowNeighborOff], decState.floor1Y[lowNeighborOff],
																			xList[highNeighborOff], decState.floor1Y[highNeighborOff], xList[i]);
				val := decState.floor1Y[i];
				highroom := range - predicted;
				lowroom := predicted;
				IF (highroom < lowroom) THEN
					room := highroom*2
				ELSE
					room := lowroom*2
				END;
				IF (val # 0) THEN
					decState.floor1Step2Flag[lowNeighborOff] := TRUE;
					decState.floor1Step2Flag[highNeighborOff] := TRUE;
					decState.floor1Step2Flag[i] := TRUE;
					IF (val >= room) THEN
						IF (highroom > lowroom) THEN
							decState.floor1Y[i] := val - lowroom + predicted
						ELSE
							decState.floor1Y[i] := predicted - val + highroom - 1;
						END
					ELSE (* val < room *)
						IF (val MOD 2 = 1) THEN (* val is odd *)
							decState.floor1Y[i] := predicted - ((val + 1) DIV 2)
						ELSE (* val is even *)
							decState.floor1Y[i] := predicted + (val DIV 2)
						END
					END
				ELSE (* val = 0 *)
					decState.floor1Step2Flag[i] := FALSE;
					decState.floor1Y[i] := predicted
				END
			END;

			(* step 2: curve synthesis *)

			(* render the lines *)
			hx := 0; lx := 0;
			ly := decState.floor1Y[xListSortPtr[0]] * multiplier;
			FOR i := 1 TO values - 1 DO
				IF (decState.floor1Step2Flag[xListSortPtr[i]]) THEN
					hy := decState.floor1Y[xListSortPtr[i]] * multiplier;
					hx := xList[xListSortPtr[i]];
					OGGUtilities.RenderLine(lx, ly, hx, hy, decState.floor[ch].data);
					lx := hx;
					ly := hy
				END
			END;

			n := decState.n DIV 2;
			IF (hx < n) THEN
				OGGUtilities.RenderLine(hx, hy, n, hy, decState.floor[ch].data)
			END;
			IF (hx > n) THEN
				(* truncate floor-vector to n elements *)
				FOR i := n TO hx - 1 DO
					decState.floor[ch].data[i] := 0
				END
			END;

			(* inverse dB lookup and DotProduct with Residue *)
			FOR i := 0 TO n- 1 DO
				decState.floor[ch].data[i] :=  InverseDBLookup[decState.floor[ch].data[i]]
			END;
		END ComputeCurve;

		PROCEDURE DecodePacket(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR; VAR decState: DecoderState): LONGINT;
		VAR
			range, book, i, j, class, cdim, cbits, csub, cval, offset, nonzero: LONGINT;
			codebook: Codebook;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@VorbisCodec::FloorType1::DecodePacket()")
			END;
			nonzero := bufReader.GetBits(buf, 1);
			IF (nonzero = 1) THEN
				range := FloorRanges[multiplier-1];
				decState.floor1Y[0] := bufReader.GetBits(buf, OGGUtilities.ILog(range-1));
				decState.floor1Y[1] := bufReader.GetBits(buf, OGGUtilities.ILog(range-1));
				offset := 2;
				FOR i := 0 TO partitions-1 DO
					class := partitionClassList[i];
					cdim := classDimensions[class];
					cbits := classSubclasses[class];
					csub := LSH(LONG(LONG(1)), cbits) - 1;
					cval := 0;
					IF (cbits > 0) THEN
						book := classMasterbooks[class];
						codebook := decState.codec.codebooks[book];
						cval := codebook.GetCodeword(bufReader, buf)
					END;
					FOR j := 0 TO cdim-1 DO
						book := subclassBooks[class, BIT.LAND(cval, csub)];
						cval := LSH(cval, -cbits); (* right shift cval by cbits *)
						IF (book >= 0) THEN
							codebook := decState.codec.codebooks[book];
							decState.floor1Y[j + offset] := codebook.GetCodeword(bufReader, buf)
						ELSE
							decState.floor1Y[j + offset] := 0
						END
					END; (* cdim *)
					INC(offset, cdim)
				END; (* partitions *)
			ELSE (* nonzero = 0 *)
				 (* channel contains no audio energy in this frame *)
				 IF (Trace IN Debug) THEN
				 	OGGUtilities.String("VorbisCodec::Floor1::DecodePacket() - RETURN ChannelNotUsed")
				 END;
				 RETURN ChannelNotUsed
			END;
			 IF (Trace IN Debug) THEN
			 	OGGUtilities.String("VorbisCodec::Floor1::DecodePacket() - RETURN Ok")
			 END;

			 (* check if there happened an end-of-packet (and therefore an end-of-stream) situation *)
			 IF bufReader.IsOk(buf) THEN RETURN Ok ELSE RETURN ChannelNotUsed END
		END DecodePacket;

		(* decode floor1-description from codec setup header *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
										VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		VAR i, j, k: LONGINT;
		BEGIN
			partitions := bufReader.GetBits(buf, 5);
			maxClass := -1;
			FOR i := 0 TO partitions - 1 DO
				partitionClassList[i] := bufReader.GetBits(buf, 4);
				IF (partitionClassList[i] > maxClass) THEN maxClass := partitionClassList[i] END
			END;
			FOR i := 0 TO maxClass DO
				classDimensions[i] := bufReader.GetBits(buf, 3) + 1;
				classSubclasses[i] := bufReader.GetBits(buf, 2);
				IF (classSubclasses[i] # 0) THEN
					classMasterbooks[i] := bufReader.GetBits(buf, 8);
					IF (classMasterbooks[i] > codec.codebookCnt) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@VorbisCodec::Floor1::DecodeHeader() - invalid master-codebook number (too big)")
						END;
						RETURN FALSE
					END
				END;
				FOR j := 0 TO (LSH(LONG(LONG(1)),classSubclasses[i])) - 1 DO
					subclassBooks[i, j] := bufReader.GetBits(buf, 8) - 1;
					IF (subclassBooks[i, j] > codec.codebookCnt) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@VorbisCodec::Floor1::DecodeHeader() - invalid subclass-codebook number (too big)")
						END;
						RETURN FALSE
					END
				END
			END;
			multiplier := bufReader.GetBits(buf, 2) + 1;
			rangebits := bufReader.GetBits(buf, 4);

			(* version of jOrbis' *)
			values := 0;
			k := 0;
			FOR j := 0 TO partitions - 1 DO
				INC(values, classDimensions[partitionClassList[j]]);
				WHILE (k < values) DO
					xList[k + 2] := bufReader.GetBits(buf, rangebits);
					INC(k)
				END
			END;
			INC(values, 2);
			xList[0] := 0;
			xList[1] := LSH(LONG(LONG(1)), rangebits);

			(* sort xList => do not apply, xList is used unsorted only: xListSortPtr *)
			xListSize := 2;
			FOR i := 0 TO partitions - 1 DO
				INC(xListSize, classDimensions[partitionClassList[i]])
			END;
			OGGUtilities.EasySortRemember(xList, xListSortPtr, xListSize);

			RETURN TRUE
		END DecodeHeader;
	END FloorType1;

	(* container for values needed by ResiduePartitionProc *)
	ResidueInfo = OBJECT
	VAR
		partitionSize, outputVectorNr, offset, codebookNr, ch: LONGINT;

		PROCEDURE Init(partitionSize, outputVectorNr, offset, codebookNr, ch: LONGINT);
		BEGIN
			SELF.partitionSize := partitionSize;
			SELF.outputVectorNr := outputVectorNr;
			SELF.offset := offset;
			SELF.codebookNr := codebookNr;
			SELF.ch := ch
		END Init;
	END ResidueInfo;

	Residue = OBJECT
		VAR
			begin, end, partitionSize, classifications, classbook: LONGINT;
			cascades: ARRAY ResidueCascadeSize OF LONGINT;
			books: ARRAY ResidueBookSize, 8 OF LONGINT;
			nr: LONGINT;
			decodemap, partword2: ARRAY 1024, PartwordSize OF LONGINT;
			partword01: ARRAY MaxChannels, 1024, PartwordSize OF LONGINT;

		(** print to the logfile *)
		PROCEDURE Print;
		VAR i: LONGINT;
		BEGIN
			OGGUtilities.String("### Residue ###");
			OGGUtilities.Var("begin", begin);
			OGGUtilities.Var("end", end);
			OGGUtilities.Var("partitionSize", partitionSize);
			OGGUtilities.Var("classifications", classifications);
			OGGUtilities.Var("classbook", classbook);
			OGGUtilities.Array("cascades", cascades);
			FOR i := 0 TO ResidueBookSize - 1 DO
				OGGUtilities.Var("books[i]", i);
				OGGUtilities.Array("book", books[i])
			END;
			OGGUtilities.String("### END (Residue) ###"); OGGUtilities.String("")
		END Print;

		(* decode residue configuration from codec setup header (for all three residue types the same *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
										VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		VAR i, j, k, highBits, lowBits, bitFlag, val, mult, deco, partvals, dim: LONGINT;
			tmpSet: SET;
		BEGIN
			begin := bufReader.GetBits(buf, 24);
			end := bufReader.GetBits(buf, 24);
			partitionSize := bufReader.GetBits(buf, 24) + 1;
			classifications := bufReader.GetBits(buf, 6) + 1;
			classbook := bufReader.GetBits(buf, 8);
			IF (classbook > codec.codebookCnt) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@VorbisCodec::Residue::DecodeHeader() - invalid class-codebook number (too big)")
				END;
				RETURN FALSE
			END;
			FOR i := 0 TO classifications - 1 DO
				highBits := 0;
				lowBits := bufReader.GetBits(buf, 3);
				bitFlag := bufReader.GetBits(buf, 1);
				IF (bitFlag = 1) THEN highBits := bufReader.GetBits(buf, 5) END;
				cascades[i] := highBits * 8 + lowBits
			END;
			FOR i := 0 TO classifications - 1 DO
				FOR j := 0 TO 7 DO
					tmpSet := SYSTEM.VAL(SET, cascades[i]);
					IF (j IN tmpSet) THEN
						books[i, j] := bufReader.GetBits(buf, 8);
						IF (books[i, j] > codec.codebookCnt) THEN
							IF (Error IN Debug) THEN
								OGGUtilities.String("error@VorbisCodec::Residue::DecodeHeader() - invalid codebook number (too big)")
							END;
							RETURN FALSE
						END
					ELSE
						books[i, j] := ResidueBookUnused
					END
				END;
			END;

			(* decodemap *)
			dim := codec.codebooks[classbook].dimensions;
			partvals := OGGUtilities.Power(classifications, dim);
			FOR j := 0 TO partvals - 1 DO
				val := j;
				mult := partvals DIV classifications;
				FOR k := 0 TO dim - 1 DO
					deco := val DIV mult;
					val := val - deco * mult;
					mult := mult DIV classifications;
					decodemap[j, k] := deco;
				END
			END;
			RETURN TRUE
		END DecodeHeader;

		(* decode residue vectors filling residue-array, residueNumbers will serve as an index into that array *)
		PROCEDURE DecodePacket(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
														VAR decState: DecoderState; ch: LONGINT);
		VAR
			i, j, k, l, s, t: LONGINT;
			samplesPerPartition, partitionsPerWord, n, partvals, offset, temp, vqclass, vqbook: LONGINT;
			codebook: Codebook;
			dim, used: LONGINT;
		BEGIN
			(* decodemap, macht jOrbis so. vielleicht funktionierts ja so ... *)
			dim := decState.codec.codebooks[classbook].dimensions;
			partvals := OGGUtilities.Power(classifications, dim);
			FOR i := 0 TO ch - 1 DO
				decState.residues[i].ZeroBuffer()
			END;

			IF decState.residueType # 2 THEN (* residue-type 0 or 1 *)
				used := 0;
				FOR t := 0 TO ch - 1 DO
					IF ~decState.doNotDecode[t] THEN
						INC(used)
					END
				END;
				IF (used = 0) THEN
					RETURN
				ELSE
					samplesPerPartition := partitionSize;
					partitionsPerWord := decState.codec.codebooks[classbook].dimensions;
					n := end - begin;
					partvals := n DIV samplesPerPartition;
					codebook := decState.codec.codebooks[classbook];
					FOR s := 0 TO 7 DO
						i := 0;
						l := 0;
						WHILE (i < partvals) DO
							IF (s = 0) THEN
								FOR j := 0 TO ch - 1 DO
									temp := codebook.GetCodeword(bufReader, buf);
									FOR t := 0 TO PartwordSize - 1 DO
										partword01[j, l, t] := decodemap[temp, t];
									END
								END (* for ch *)
							END; (* if s = 0 *)
							k := 0;
							WHILE ((k < partitionsPerWord) & (i < partvals)) DO
								FOR j := 0 TO ch - 1 DO
									IF ~decState.doNotDecode[j] THEN
										offset := begin + i * samplesPerPartition;
										vqclass := partword01[j, l, k];
										vqbook := books[vqclass, s];
										IF (vqbook # ResidueBookUnused) THEN
											decState.resInfo.Init(samplesPerPartition, j, offset, vqbook, ch);
											decState.residuePartitionProc[decState.residueType](bufReader, buf, decState)
										END
									END
								END; (* for ch *)
								INC(i);
								INC(k);
							END;
							INC(l);
						END (* while *)
					END (* for s *)
				END (* if doNotDecode *)

			ELSE (* residue-type 2 *)
				t := 0;
				WHILE ((t # ch) & decState.doNotDecode[t]) DO
					INC(t);
				END;
				IF (t = ch) THEN
					(* no residue-vector need to be decoded *)
					RETURN
				END;

				samplesPerPartition := partitionSize;
				partitionsPerWord := decState.codec.codebooks[classbook].dimensions;
				n := end - begin;

				partvals := n DIV samplesPerPartition;
				FOR s := 0 TO 7 DO (* s = pass *)
					i := 0;
					l := 0;
					WHILE (i < partvals) DO
						IF s = 0 THEN
							codebook := decState.codec.codebooks[classbook];
							temp := codebook.GetCodeword(bufReader, buf);
							(* neue version mit decodemap *)
							partword2[l] := decodemap[temp];

						END; (* s = 0 *)
						k := 0;
						WHILE (k < partitionsPerWord) & (i < partvals) DO
							offset := begin + i * samplesPerPartition;
							vqclass := partword2[l, k];
							vqbook := books[vqclass, s];
							IF (vqbook # ResidueBookUnused) THEN
								decState.resInfo.Init(samplesPerPartition, -1, offset, vqbook, ch);
								decState.residuePartitionProc[decState.residueType](bufReader, buf, decState);
							END;
							INC(k);
							INC(i)
						END; (* while *)
						INC(l)
					END; (* while *)
				END (* for s *)
			END; (* if residueType *)
		END DecodePacket;
	END Residue;

	Mapping = OBJECT
		VAR
			submaps*, couplingSteps*: LONGINT;
			magnitude*, angle*: ARRAY MappingMagnitudeSize OF LONGINT;
			mux*: ARRAY MappingMuxSize OF LONGINT;
			submapFloor*, submapResidue*: ARRAY MappingSubmapFloorSize OF LONGINT;
			nr*: LONGINT;

		(** print to the logfile *)
		PROCEDURE Print;
		BEGIN
			OGGUtilities.String("### Mapping ###");
			OGGUtilities.Var("nr", nr);
			OGGUtilities.Var("submaps", submaps);
			OGGUtilities.Var("couplingSteps", couplingSteps);
			OGGUtilities.Array("magnitude", magnitude);
			OGGUtilities.Array("angle", angle);
			OGGUtilities.Array("mux", mux);
			OGGUtilities.Array("submapFloor", submapFloor);
			OGGUtilities.Array("submapResidue", submapResidue);
			OGGUtilities.String("### END (Mapping) ###"); OGGUtilities.String("")
		END Print;

		(* decode mapping configuration from codec setup header *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
										VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		VAR tmp, i: LONGINT;
		BEGIN
			IF (bufReader.GetBits(buf, 1) = 1) THEN
				submaps := bufReader.GetBits(buf, 4) + 1
			ELSE
				submaps := 1
			END;

			IF (bufReader.GetBits(buf, 1) = 1) THEN
				(* square polar channel mapping is in use *)
				couplingSteps := bufReader.GetBits(buf, 8) + 1;
				FOR i := 0 TO couplingSteps - 1 DO
					magnitude[i] := bufReader.GetBits(buf, OGGUtilities.ILog(info.channels - 1));
					angle[i] := bufReader.GetBits(buf, OGGUtilities.ILog(info.channels - 1));
					IF (magnitude[i] = angle[i]) THEN
						IF ((angle[i] > info.channels - 1) OR (magnitude[i] > info.channels - 1)) THEN
							IF (Error IN Debug) THEN
								OGGUtilities.String("error@VorbisCodec::Mapping::DecodeHeader() - invalid angle-magnitude-channels constelation")
							END;
							RETURN FALSE
						END
					END
				END
			ELSE
				couplingSteps := 0
			END;

			IF (bufReader.GetBits(buf, 2) # 0) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@VorbisCodec::Mapping::DecodeHeader() - reserved field wrongly in use")
				END;
				RETURN FALSE
			END;

			IF (submaps > 1) THEN
				(* read channel multiplex settings *)
				FOR i := 0 TO info.channels - 1 DO
					mux[i] := bufReader.GetBits(buf, 4);
					IF (mux[i] > submaps - 1) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@VorbisCodec::Mapping::DecodeHeader() - current mux value is greater than submap-1")
						END;
						RETURN FALSE
					END
				END
			END;

			FOR i := 0 TO submaps - 1 DO
				(* read the floor and residue numbers for use in decoding that supmap *)
				tmp := bufReader.GetBits(buf, 8);
				submapFloor[i] := bufReader.GetBits(buf, 8);
				IF (submapFloor[i] > codec.floorCnt) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@VorbisCodec::Mapping::DecodeHeader() - invalid floor number (too big)")
					END;
					RETURN FALSE
				END;
				submapResidue[i] := bufReader.GetBits(buf, 8);
				IF (submapResidue[i] > codec.residueCnt) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@VorbisCodec::Mapping::DecodeHeader() - invalid residue number (too big)")
					END;
					RETURN FALSE
				END
			END;

			RETURN TRUE
		END DecodeHeader;
	END Mapping;

	Mode = OBJECT
		VAR blockflag*, windowType*, transformType*, mapping*: LONGINT;

		(** print to the logfile *)
		PROCEDURE Print;
		BEGIN
			OGGUtilities.String("### Mode ###");
			OGGUtilities.Var("blockflag", blockflag);
			OGGUtilities.Var("windowType", windowType);
			OGGUtilities.Var("transformType", transformType);
			OGGUtilities.Var("mapping", mapping);
			OGGUtilities.String("### END (Mode) ###"); OGGUtilities.String("")
		END Print;

		(* decode mode configurations from codec setup header *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
										VAR info: Info; VAR codec: CodecSetup): BOOLEAN;
		BEGIN
			blockflag := bufReader.GetBits(buf, 1);
			windowType := bufReader.GetBits(buf, 16);
			transformType := bufReader.GetBits(buf, 16);
			mapping := bufReader.GetBits(buf, 8);
			IF (mapping > codec.mappingCnt) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@VorbisCodec::Mode::DecodeHeader() - illegal mapping number (too big)")
				END;
				RETURN FALSE
			END;
			IF ((windowType # 0) OR (transformType # 0)) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@VorbisCodec::Mode::DecodeHeader() - illegal window- and/or transform-type")
				END;
				RETURN FALSE
			END;
			RETURN TRUE
		END DecodeHeader;
	END Mode;

	Codebook = OBJECT
		VAR
			entries*, dimensions*, lookupType*, valueBits*, lookupValues*: LONGINT;
			sequenceP*: BOOLEAN;
			minimumValueFP*, deltaValueFP*: HUGEINT; (* fixed-point values *)
			codewordLengths*: OGGUtilities.IntList;
			multiplicandsFP, valuelistFP*: ARRAY MaxNumberOfMultiplicands OF HUGEINT;
			huffmanTree*: OGGUtilities.HuffmanTree;
			valid*: BOOLEAN;
			cbNumber-: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			NEW(codewordLengths, NIL);
		END Init;

		(* print to the logfile *)
		PROCEDURE Print;
		BEGIN
			OGGUtilities.String("### Codebook ###");
			OGGUtilities.Var("cbNumber", cbNumber);
			OGGUtilities.VarH("minimumValueFP", minimumValueFP);
			OGGUtilities.VarH("deltaValueFP", deltaValueFP);
			OGGUtilities.Var("entries", entries);
			OGGUtilities.Var("dimensions", dimensions);
			OGGUtilities.Var("lookupType", lookupType);
			OGGUtilities.Var("valueBits", valueBits);
			OGGUtilities.Var("lookupValues", lookupValues);
			OGGUtilities.ArrayHugeLen("valuelist", valuelistFP, dimensions * entries);
			OGGUtilities.ArrayHugeLen("multiplicands", multiplicandsFP, 32);
			OGGUtilities.String("codewordLengths: ..."); codewordLengths.Print;
			OGGUtilities.String("### END (Codebook) ###"); OGGUtilities.String("")
		END Print;

		(* decode codebooks from codec setup header *)
		PROCEDURE DecodeHeader(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR; nr: LONGINT): BOOLEAN;
		VAR
			curEntry, curLength, number, i, j, k, sparsecount, indexDiv, index: LONGINT;
			valFP, lastFP: HUGEINT;
			newEntry: OGGUtilities.IntElement;
			ordered, sparse, flag: BOOLEAN;
			codewords: OGGUtilities.IntList;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@VorbisCodec::Codebook::DecodeHeader()")
			END;
			SELF.cbNumber := nr;

			(* every codebook starts with a synch-pattern *)
			IF (~(bufReader.GetBits(buf, 24) = CodebookSynchPattern)) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("@VorbisCodec::Codebook::DecodeHeader() - error with synch-pattern of codebook")
				END;
				RETURN FALSE
			END;
			dimensions := bufReader.GetBits(buf, 16);
			entries := bufReader.GetBits(buf, 24);
			ordered := (bufReader.GetBit(buf) = 1);
			IF ~ordered THEN
				(* codeword-list not length-ordered, read each codeword one-by-one *)
				sparse := (bufReader.GetBit(buf) = 1);
				FOR i := 0 TO entries - 1 DO
					IF sparse THEN
						flag := (bufReader.GetBit(buf) = 1);
						IF flag THEN
							curLength := bufReader.GetBits(buf, 5) + 1
						ELSE
							curLength := UnusedCodebookEntry
						END; (* IF flag set *)
					ELSE
						curLength := bufReader.GetBits(buf, 5) + 1;
					END; (* IF sparse set *)
					(* generate new entry and add it to codeword-lengths *)
					IF (curLength > 31) THEN
						KernelLog.String("ASSERTION failed - codeword too long"); KernelLog.Ln
					END;
					(* codewords mustn't be longer than a (positive) LONGINT *)
					ASSERT (curLength <= 31);
					NEW(newEntry, curLength);
					codewordLengths.Append(newEntry)
				END; (* FOR entries *)
			ELSE
				(* codeword-list is in ascending length order, read a number of codewords per length *)
				(* and a total of 'entries' codewords *)
				curEntry := 0;
				curLength := bufReader.GetBits(buf, 5) + 1;
				LOOP
					number := bufReader.GetBits(buf, OGGUtilities.ILog(entries - curEntry));
					IF (curLength > 31) THEN
						KernelLog.String("ASSERTION failed - codeword too long"); KernelLog.Ln
					END;
					(* codewords mustn't be longer than a (positive) LONGINT *)
					ASSERT (curLength <= 31);
					FOR i := curEntry TO (curEntry + number - 1) DO
						NEW(newEntry, curLength);
						codewordLengths.Append(newEntry);
					END;
					curEntry := number + curEntry;
					INC(curLength);
					IF (curEntry > entries) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@VorbisCodec::Codebook::DecodeHeader() - decoding-error (more codebook-entries than expected)");
							RETURN FALSE
						END
					ELSIF curEntry = entries THEN
						EXIT
					(* ELSE
						continue loop *)
					END;
				END; (* LOOP *)
			END;

			(* build a huffman-tree from the codewordLengths *)
			NEW(huffmanTree);
			sparsecount := CountValidCodewords(codewordLengths);
			IF (huffmanTree.IsValidLengthList(codewordLengths, UnusedCodebookEntry)) THEN
				MakeCodewords(codewordLengths, sparsecount, codewords);
				huffmanTree.BuildTree(codewordLengths, codewords, UnusedCodebookEntry);
				valid := TRUE
			ELSIF (~huffmanTree.HasUsedEntries(codewordLengths, UnusedCodebookEntry)) THEN
				valid := FALSE;
			ELSE
				valid := FALSE;
				IF (Error IN Debug) THEN
					OGGUtilities.w.String("error@VorbisCodec::Codebook::DecodeHeader() - invalid huffmanTree");
					IF (huffmanTree.IsOverspecified(codewordLengths, UnusedCodebookEntry)) THEN
						OGGUtilities.w.String(" (overspecified)")
					ELSIF (huffmanTree.IsUnderspecified(codewordLengths, UnusedCodebookEntry)) THEN
						OGGUtilities.w.String(" (underspecified)")
					END;
					OGGUtilities.String("");
				END;
				RETURN FALSE
			END;

			(* prepare for vector-lookup *)
			lookupType := bufReader.GetBits(buf, 4);
			IF (lookupType > 2) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@VorbisCodec::Codebook::DecodeHeader() - decoding-error (invalid codebook-lookupType)")
				END;
			ELSIF (lookupType # 0) THEN
			(* neue Version, a la jOrbis *)
				minimumValueFP := OGGUtilities.Float32Unpack(bufReader.GetBits(buf, 32));
				deltaValueFP := OGGUtilities.Float32Unpack(bufReader.GetBits(buf, 32));
				valueBits := bufReader.GetBits(buf, 4) + 1;
				sequenceP := (bufReader.GetBit(buf) = 1);

				IF (lookupType = 1) THEN
					lookupValues := OGGUtilities.Lookup1Values(entries, dimensions)
				ELSIF (lookupType = 2) THEN
					lookupValues := entries * dimensions
				END;
				IF (lookupValues > MaxNumberOfMultiplicands) THEN
					KernelLog.String("ASSERTION failed - MaxNumberrOfMultiplicands too small"); KernelLog.Ln
				END;
				ASSERT (lookupValues <= MaxNumberOfMultiplicands);

				FOR i := 0 TO lookupValues - 1 DO
					multiplicandsFP[i] := OGGUtilities.ScaleUpHugeInt(bufReader.GetBits(buf, valueBits));
				END;

				IF (lookupType = 1) THEN
					FOR j := 0 TO entries - 1 DO
						lastFP := 0;
						indexDiv := 1;
						FOR k := 0 TO dimensions - 1 DO
							index := (j DIV indexDiv) MOD lookupValues;
							valFP := multiplicandsFP[index];

							(* we need the absolute value *)
							IF valFP < 0 THEN
								valFP := -1 * valFP
							END;
							valFP := OGGUtilities.MultFP(valFP, deltaValueFP);
							valFP := valFP + minimumValueFP + lastFP;
							IF sequenceP THEN lastFP := valFP END;
							valuelistFP[j * dimensions + k] := valFP;
							indexDiv := indexDiv * lookupValues
						END
					END
				ELSIF (lookupType = 2) THEN
					FOR j := 0 TO entries - 1 DO
						lastFP := 0;
						FOR k := 0 TO dimensions - 1 DO
							valFP := multiplicandsFP[j * dimensions + k];
							(* we need the absolute value *)
							IF valFP < 0 THEN
								valFP := -1 * valFP
							END;
							valFP := OGGUtilities.MultFP(valFP, deltaValueFP);
							valFP := valFP + minimumValueFP + lastFP;
							IF sequenceP THEN lastFP := valFP END;
							valuelistFP[j * dimensions + k] := valFP
						END
					END
				END
			END;
			RETURN TRUE
		END DecodeHeader;

		(* read the next codeword from the buffer *)
		PROCEDURE GetCodeword(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR): LONGINT;
		VAR
			bit: LONGINT;
			hNode: OGGUtilities.HuffmanNode;
		BEGIN
			hNode := huffmanTree.start;
			REPEAT
				bit := bufReader.GetBits(buf, 1);
				huffmanTree.GoLeftOrRight(hNode, bit)
			UNTIL (hNode.IsLeaf());
			RETURN hNode.GetValue();
		END GetCodeword;

		(* build the list of codewods from a list of lengths (algorithm from Tremor-source code) *)
		PROCEDURE MakeCodewords(VAR list: OGGUtilities.IntList; sparsecount: LONGINT; VAR res: OGGUtilities.IntList);
		VAR
			i: HUGEINT; j, count, length, entry, tmp: LONGINT;
			marker: ARRAY OGGUtilities.MaxCodewordLength OF LONGINT;
			cur, curRes: OGGUtilities.IntElement;
		BEGIN
			NEW(res, NIL);
			count := 0;
			cur := list.start(OGGUtilities.IntElement);
			FOR i := 0 TO list.length - 1 DO
				length := cur.long;
				IF (length # UnusedCodebookEntry) THEN
					entry := marker[length];
					tmp := LSH(entry, -1*length); (* <=> entry >> length in C *)
					IF ((length < 32) & (tmp # 0)) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@OGGUtilities::HuffmanTree::MakeCodewords() - lengths must specify an overpopulated tree");
						END;
						RETURN
					END;
					(* update ourself *)
					NEW(curRes, entry);
					res.Append(curRes);
					INC(count);

					(* look to see if the next shorter marker points to the node above. if so, update it and repeat *)
					LOOP
						FOR j := length TO 1 BY -1 DO
							IF ((marker[j] MOD 2) = 1) THEN
								IF (j = 1) THEN
									INC(marker[1])
								ELSE
									marker[j] := LSH(marker[j-1], 1) (* <=> marker[j-1] << 1 *)
								END;
								EXIT
							END;
							INC(marker[j]);
						END;
						EXIT (* exit the loop anyway *)
					END; (* LOOP *)

					(* prune the tree; implicit invariant says alle the longer markers were dangling from our just-taken node.
						dangle them from our *new* node *)
					LOOP
						FOR j := length+1 TO OGGUtilities.MaxCodewordLength-1 DO
							IF (LSH(marker[j], -1) = entry) THEN
								entry := marker[j];
								marker[j] := LSH(marker[j-1], 1)
							ELSE
								EXIT
							END
						END;
						EXIT
					END; (* LOOP *)
				ELSE
					IF (sparsecount = 0) THEN INC(count) END
				END; (* IF length > 0 *)
				IF (cur.next # NIL) THEN cur := cur.next(OGGUtilities.IntElement) END
			END(* FOR i=0..n-1 *)
		END MakeCodewords;

		(* count the number of valid codewords *)
		PROCEDURE CountValidCodewords(VAR list: OGGUtilities.IntList): LONGINT;
		VAR
			cur: OGGUtilities.IntElement;
			cnt: LONGINT;
		BEGIN
			cur := list.start(OGGUtilities.IntElement);
			cnt := 0;
			WHILE (cur # NIL) DO
				IF (cur.long # UnusedCodebookEntry) THEN INC(cnt) END;
				IF (cur.next = NIL) THEN cur := NIL ELSE cur := cur.next(OGGUtilities.IntElement) END
			END;
			RETURN cnt
		END CountValidCodewords;
	END Codebook;

	CodecSetup = OBJECT
		VAR
			codebookCnt*, floorCnt*, residueCnt*, mappingCnt*, modeCnt*: LONGINT;
			codebooks*: ARRAY MaxNumberOfCodebooks OF Codebook;
			floorTypes*: ARRAY MaxNumberOfFloors OF LONGINT;
			floorConf*: ARRAY MaxNumberOfFloors OF AbstractFloorType;
			residueTypes*: ARRAY MaxNumberOfResidues OF LONGINT;
			residues*: ARRAY MaxNumberOfResidues OF Residue;
			mappings*: ARRAY MaxNumberOfMappings OF Mapping;
			modes*: ARRAY MaxNumberOfModes OF Mode;

		(** print all elements of the codec setup *)
		PROCEDURE Print;
		VAR i: LONGINT;
		BEGIN
			OGGUtilities.String("***** CodecSetup *****");
			OGGUtilities.Var("codebookCnt", codebookCnt);
			FOR i := 0 TO codebookCnt - 1 DO
				OGGUtilities.Var("codebookNr", i); (* invalid codebooks are NIL *)
				IF (codebooks[i] # NIL) THEN codebooks[i].Print END
			END;

			OGGUtilities.Array("floorTypes", floorTypes);
			OGGUtilities.Var("floorCnt", floorCnt);
			FOR i := 0 TO floorCnt - 1 DO OGGUtilities.Var("floorConfNr", i); floorConf[i].Print END;

			OGGUtilities.Array("residueTypes", residueTypes);
			OGGUtilities.Var("residueCnt", residueCnt);
			FOR i := 0 TO residueCnt - 1 DO OGGUtilities.Var("residueNr", i); residues[i].Print END;

			OGGUtilities.Var("mappingCnt", mappingCnt);
			FOR i := 0 TO mappingCnt - 1 DO OGGUtilities.Var("mappingNr", i); mappings[i].Print END;

			OGGUtilities.Var("modeCnt", modeCnt);
			FOR i := 0 TO modeCnt - 1 DO OGGUtilities.Var("modeNr", i); modes[i].Print END;
			OGGUtilities.String("***** END (CodecSetup) *****");
		END Print;
	END CodecSetup;

	CommentListElement = OBJECT (OGGUtilities.ListElement)
		VAR
			length*: HUGEINT;
			text*: ARRAY MaxCommentLength OF CHAR;

			PROCEDURE Print;
			BEGIN
				KernelLog.String(text); KernelLog.Ln
			END Print;
	END CommentListElement;

	 CommentList = OBJECT (OGGUtilities.List)
		 VAR
			vendorLength*: HUGEINT;
			vendorString*: ARRAY MaxVendorLength OF CHAR;
			(* other comment fields are already defined in OGGUtilities.List *)

		PROCEDURE Print;
		VAR cur: CommentListElement;
		BEGIN
			IF cur = NIL THEN
				cur := NIL
			ELSE
				cur := start(CommentListElement)
			END;
			WHILE cur # NIL DO
				cur.Print();
				IF cur.next = NIL THEN
					cur := NIL
				ELSE
					cur := cur.next(CommentListElement)
				END
			END
		END Print;
	END CommentList;

	Info = OBJECT
	VAR
		version, sampleRate: HUGEINT;
		channels, bitrateMax, bitrateNom, bitrateMin: LONGINT;
		blocksizes: ARRAY 2 OF LONGINT;
		comment: CommentList;

		PROCEDURE &Init*;
		BEGIN
			NEW(comment, NIL)
		END Init;

		PROCEDURE Print;
		BEGIN
			OGGUtilities.VarH("version",version);
			OGGUtilities.VarH("sampleRate",sampleRate);
			OGGUtilities.Var("channels",channels);
			OGGUtilities.Var("bitrateMax",bitrateMax);
			OGGUtilities.Var("bitrateNom",bitrateNom);
			OGGUtilities.Var("bitrateMin",bitrateMin);
			OGGUtilities.Var("blocksize0",blocksizes[0]);
			OGGUtilities.Var("blocksize1",blocksizes[1])
		END Print;
	END Info;

	(* buffer for the inverse MDCT *)
	MdctBufferT = ARRAY OGGUtilities.MaxBlocksize DIV 2 OF HUGEINT;
	MdctBuffer = POINTER TO MdctBufferT;

	(** does nothing except printing arguments of Decode()-procedure *)
	DumpDecoder* = OBJECT
		VAR
			packetNr-: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			packetNr := 0;
		END Init;

		PROCEDURE Decode*(VAR buf: ARRAY OF CHAR; pos, len: LONGINT; continuedPacket: BOOLEAN; VAR soundOutput: SoundOutput): BOOLEAN;
		BEGIN
			INC(packetNr);
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@DumpDecoder::Decode()"); OGGUtilities.w.Ln;
			END;
			RETURN TRUE;
		END Decode;
	END DumpDecoder;

	MdctObject = OBJECT
		VAR
			n, log2n: LONGINT;
			bitrev: ARRAY OGGUtilities.MaxBlocksize DIV 4 OF LONGINT;
			trig: ARRAY OGGUtilities.MaxBlocksize + (OGGUtilities.MaxBlocksize DIV 4) OF LONGINT;
			x, w: MdctBuffer;

		PROCEDURE &Init*(n: LONGINT);
		VAR ae, ao, be, bo, ce, co, i, j, acc, mask, msb, notAcc: LONGINT;
			float: LONGREAL;
		BEGIN
			NEW(x);
			NEW(w);
			SELF.n := n;
			log2n := OGGUtilities.Log2n(n);
			ae := 0;
			ao := 1;
			be := ae + n DIV 2;
			bo := be + 1;
			ce := be + n DIV 2;
			co := ce + 1;
			FOR i := 0 TO n DIV 4 - 1 DO
				float := Math.cos((Math.pi / n) * 4 * i);
				trig[ae + i * 2] := OGGUtilities.ScaleUp(float);
				float := - Math.sin((Math.pi / n) * 4 * i);
				trig[ao + i * 2] := OGGUtilities.ScaleUp(float);
				float := Math.cos((Math.pi / (2 * n)) * (2 * i + 1));
				trig[be + i * 2] := OGGUtilities.ScaleUp(float);
				float := Math.sin((Math.pi / (2 * n)) * (2 * i + 1));
				trig[bo + i * 2] := OGGUtilities.ScaleUp(float);
			END;
			FOR i := 0 TO n DIV 8 - 1 DO
				float := Math.cos((Math.pi / n) * (4 * i + 2));
				trig[ce + i * 2] := OGGUtilities.ScaleUp(float);
				float := - Math.sin((Math.pi / n) * (4 * i + 2));
				trig[co + i * 2] := OGGUtilities.ScaleUp(float);
			END;
			mask := LSH(LONG(LONG(1)), log2n - 1) - 1;
			msb := LSH(LONG(LONG(1)), log2n - 2);
			FOR i := 0 TO n DIV 8 - 1 DO
				acc := 0;
				j := 0;
				WHILE (LSH(msb, -j) # 0) DO
					IF ((BIT.LAND(LSH(msb, -j), i)) # 0) THEN
						acc := BIT.LOR(acc, LSH(LONG(LONG(1)), j))
					END;
					INC(j)
				END;
				notAcc := BIT.LXOR(acc, -1); (* !acc, bitwise not *)
				bitrev[i * 2] := BIT.LAND(notAcc, mask);
				bitrev[i * 2 + 1] := acc
			END
		END Init;

		(** performs the inverse MDCT *)
		PROCEDURE Backward(VAR data: ARRAY OF HUGEINT);
		VAR n2, n4, n8, inO, xO, a, i, xx, b, o1, o2, o3, o4: LONGINT;
			temp1, temp2: HUGEINT;
		BEGIN
			n2 := n DIV 2;
			n4 := n DIV 4;
			n8 := n DIV 8;

			(* step 1 and rotation *)
			inO := 1;
			xO := 0;
			a := n2;
			FOR i := 0 TO n8 - 1 DO
				DEC(a, 2);
				x[xO] := OGGUtilities.MultHugeFP(-data[inO + 2], trig[a + 1]);
				DEC(x[xO], OGGUtilities.MultHugeFP(data[inO], trig[a]));
				INC(xO);
				x[xO] := OGGUtilities.MultHugeFP(data[inO], trig[a + 1]);
				DEC(x[xO], OGGUtilities.MultHugeFP(data[inO + 2], trig[a]));
				INC(xO);
				INC(inO, 4);
			END;
			inO := n2 - 4;
			FOR i := 0 TO n8 - 1 DO
				DEC(a, 2);
				x[xO] := OGGUtilities.MultHugeFP(data[inO], trig[a + 1]);
				INC(x[xO], OGGUtilities.MultHugeFP(data[inO + 2], trig[a]));
				INC(xO);
				x[xO] := OGGUtilities.MultHugeFP(data[inO], trig[a]);
				DEC(x[xO], OGGUtilities.MultHugeFP(data[inO + 2], trig[a + 1]));
				INC(xO);
				DEC(inO, 4);
			END;

			(* steps 2 to 7 *)
			Kernel(n, n2, n4, n8);

			xx := 0;
			(* step 8 *)
			b := n2;
			o1 := n4;
			o2 := o1 - 1;
			o3 := n4 + n2;
			o4 := o3 - 1;
			FOR i := 0 TO n4 - 1 DO
				temp1 := OGGUtilities.MultHugeFP(x[xx], trig[b + 1]);
				DEC(temp1, OGGUtilities.MultHugeFP(x[xx + 1], trig[b]));

				temp2 := OGGUtilities.MultHugeFP(x[xx], trig[b]);
				INC(temp2, OGGUtilities.MultHugeFP(x[xx + 1], trig[b + 1]));
				temp2 := -temp2;

				data[o1] := -temp1;
				data[o2] := temp1;
				data[o3] := temp2;
				data[o4] := temp2;
				INC(o1);
				DEC(o2);
				INC(o3);
				DEC(o4);
				INC(xx, 2);
				INC(b, 2)
			END
		END Backward;


		(* Mdct-Kernel: xxx is an out-parameter *)
		PROCEDURE Kernel(n, n2, n4, n8: LONGINT);
		BEGIN
			KernelStep1(n2, n4);
			KernelStep2(n2);
			KernelStep3(n2, n8);
		END Kernel;

		PROCEDURE Swap(VAR a,b: MdctBuffer);
		VAR tmp: MdctBuffer;
		BEGIN
			tmp := a;
			a := b;
			b := tmp
		END Swap;


		(* step 2 *)
		PROCEDURE KernelStep1(n2, n4: LONGINT);
		VAR xA, xB, w2, a, i: LONGINT;
			x0, x1: HUGEINT;
		BEGIN
			xA := n4;
			xB := 0;
			w2 := n4;
			a := n2;
			i := 0;
			WHILE (i < n4) DO
				x0 := x[xA] - x[xB];
				w[w2 + i] := x[xA] + x[xB];
				INC(xA);
				INC(xB);
				x1 := x[xA] - x[xB];
				DEC(a, 4);
				w[i] := OGGUtilities.MultHugeFP(x0, trig[a]);
				INC(w[i], OGGUtilities.MultHugeFP(x1, trig[a + 1]));
				INC(i);
				w[i] := OGGUtilities.MultHugeFP(x1, trig[a]);
				DEC(w[i], OGGUtilities.MultHugeFP(x0, trig[a + 1]));
				w[w2 + i] := x[xA] + x[xB];
				INC(xA);
				INC(xB);
				INC(i)
			END;
		END KernelStep1;

		(* step 3 *)
		PROCEDURE KernelStep2(n2: LONGINT);
		VAR i, s, r, w1, w2, k0, k1, a, wbase, sEnd: LONGINT;
			wA, wB, aev, aov: HUGEINT;
		BEGIN
			FOR i := 0 TO log2n - 3 - 1 DO
				k0 := LSH(n, -(i + 2));
				k1 := LSH(LONG(LONG(1)), i + 3);
				wbase := n2 - 2;
				a := 0;
				FOR r := 0 TO (k0 DIV 4) - 1 DO
					w1 := wbase;
					w2 := w1 - (k0 DIV 2);
					aev := trig[a];
					aov := trig[a + 1];
					DEC(wbase, 2);
					INC(k0);
					sEnd := LSH((LONG(LONG(2))), i);
					FOR s := 0 TO sEnd - 1 DO
						wB := w[w1] - w[w2];
						x[w1] := w[w1] + w[w2];
						INC(w1);
						INC(w2);
						wA := w[w1] - w[w2];
						x[w1] := w[w1] + w[w2];
						x[w2] := OGGUtilities.MultHugeFP(wA, aev);
						DEC(x[w2], OGGUtilities.MultHugeFP(wB, aov));
						x[w2 - 1] := OGGUtilities.MultHugeFP(wB, aev);
						INC(x[w2 - 1], OGGUtilities.MultHugeFP(wA, aov));
						DEC(w1, k0);
						DEC(w2, k0)
					END;
					DEC(k0);
					INC(a, k1)
				END;
				Swap(x, w)
			END;
		END KernelStep2;

		(* step 4, 5, 6, 7 *)
		PROCEDURE KernelStep3(n2, n8: LONGINT);
		VAR c, bit, x1, x2, t1, t2, i: LONGINT;
			wa, wb, wc, wd, wace, waco, wbce, wbco: HUGEINT;
		BEGIN
			c := n;
			bit := 0;
			x1 := 0;
			x2 := n2 - 1;
			FOR i := 0 TO n8 -1 DO
				t1 := bitrev[bit];
				INC(bit);
				t2 := bitrev[bit];
				INC(bit);
				wa := w[t1] - w[t2 + 1];
				wb := w[t1 - 1] + w[t2];
				wc := w[t1] + w[t2 + 1];
				wd := w[t1 - 1] - w[t2];
				wace := OGGUtilities.MultHugeFP(wa, trig[c]);
				wbce := OGGUtilities.MultHugeFP(wb, trig[c]);
				INC(c);
				waco := OGGUtilities.MultHugeFP(wa, trig[c]);
				wbco := OGGUtilities.MultHugeFP(wb, trig[c]);
				INC(c);
				x[x1] := (wc + waco + wbce) DIV 2;
				INC(x1);
				x[x2] := (-wd + wbco - wace) DIV 2;
				DEC(x2);
				x[x1] := (wd + wbco - wace) DIV 2;
				INC(x1);
				x[x2] := (wc - waco - wbce) DIV 2;
				DEC(x2)
			END;
		END KernelStep3;
	END MdctObject;


	(** structure for holding all necessary information for last step in the decode-process like #channels ... *)
	SoundOutput = OBJECT
		VAR
			output: OGGUtilities.BufferPool;
			nrOfBuffers, nrOfChannels, samplingRate, samplingResolution, volume: LONGINT;
			minAmplitude, maxAmplitude: LONGINT;
			initSoundChannelDone*: BOOLEAN;
			channel: SoundDevices.Channel;
			driver: SoundDevices.Driver;

		PROCEDURE &Init*(nrOfBuffers, volume: LONGINT);
		BEGIN
			SELF.volume := volume;
			SELF.nrOfBuffers := nrOfBuffers;
			initSoundChannelDone := FALSE;
			NEW(output, nrOfBuffers)
		END Init;

		PROCEDURE CloseSoundChannel*;
		BEGIN
		 	IF (Trace IN Debug) THEN
		 		OGGUtilities.String("@SoundOutput::CloseSoundChannel()")
		 	END;
			IF channel # NIL THEN channel.Close() END
		END CloseSoundChannel;

		PROCEDURE InitSoundChannel*(nrOfChannels, samplingRate, samplingResolution: LONGINT);
		VAR i, res: LONGINT;
			buffer: SoundDevices.Buffer;
		BEGIN
		 	IF (Trace IN Debug) THEN
		 		OGGUtilities.String("@SoundOutput::InitSoundChannel()")
		 	END;
			SELF.samplingRate := samplingRate;
			SELF.samplingResolution := samplingResolution;
			SELF.nrOfChannels := nrOfChannels;
			SetMinMaxAmplitudes();

			(* allocate sound-buffers *)
			FOR i := 0 TO nrOfBuffers - 1 DO
				NEW(buffer);
				(* factor 2 because samplingResolution of 16 results in two 8-bit numbers *)
				NEW(buffer.data, 2 * OGGUtilities.MaxBlocksize);
				buffer.len := 2 * OGGUtilities.MaxBlocksize;
				output.Append(buffer);
			END;

			driver := SoundDevices.GetDefaultDevice();
			driver.OpenPlayChannel(channel, samplingRate, samplingResolution, nrOfChannels, SoundDevices.FormatPCM, res);
			IF (volume < 0) THEN volume := 255 ELSIF (volume > 255) THEN volume := 255 END;
			channel.SetVolume(volume);
			IF (channel # NIL) THEN
				channel.RegisterBufferListener(BufferListener);
				channel.Start
			END;
			initSoundChannelDone := TRUE;
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@END - SoundOutput::Init...()")
			END
		END InitSoundChannel;

		PROCEDURE Output*(VAR input: ARRAY OF OGGUtilities.PCMBuffer; nrOfSamples: LONGINT);
		VAR buffer: SoundDevices.Buffer;
			i, ch, current, bufferPos: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@SoundOutput::Output()")
			END;
			buffer := output.Remove();
			(* adjust buffer.len: samplingResolution of 16 results in twice as many 8-bit chars *)
			buffer.len := nrOfSamples * nrOfChannels * (samplingResolution DIV 8);
			bufferPos := 0;

			FOR i := 0 TO nrOfSamples - 1 DO
				FOR ch := 0 TO nrOfChannels - 1 DO
					IF input[ch].data[i] # 0 THEN
						current := GetSample(input[ch].data[i]);
					ELSE
						current := 0;
					END;

					IF (samplingResolution = 8) THEN
						buffer.data[bufferPos] := CHR(current);
						INC(bufferPos);
					ELSIF (samplingResolution = 16) THEN
						buffer.data[bufferPos] := CHR(current MOD 256);
						buffer.data[bufferPos + 1] := CHR(current DIV 256);
						INC(bufferPos, 2);
					ELSE
						(* no other samplingRate supported yet *)
					END (* samplingRate *)
				END (* nrOfChannels *)
			END; (* nrOfSamples *)

			channel.QueueBuffer(buffer);
			channel.Start;
			IF (Trace IN Debug) THEN
				OGGUtilities.String("finished - SoundOutput::Output()")
			END
		END Output;

		PROCEDURE SetMinMaxAmplitudes;
		BEGIN
			(* so far, only resolutions of 8 resp. 16 bits are supported *)
			IF (samplingResolution = 8) THEN
				maxAmplitude := 127;
				minAmplitude := -128
			ELSIF (samplingResolution = 16) THEN
				maxAmplitude := 32767;
				minAmplitude := -32768
			END
		END SetMinMaxAmplitudes;

		(* calculate the current sample:
			- scales down the fixpoint-number
			- upsizes with the max amplitude
			- does the clipping
		*)
		PROCEDURE GetSample(sample: HUGEINT): LONGINT;
		VAR retSample: LONGINT;
		BEGIN
			(* can do a normal multiplication here *)
			sample := sample * maxAmplitude;
			retSample := OGGUtilities.ScaleDownRoundedHuge(sample);

			IF retSample > maxAmplitude THEN
				RETURN maxAmplitude
			END;
			IF retSample < minAmplitude THEN
				RETURN minAmplitude
			END;
			RETURN retSample
		END GetSample;

		PROCEDURE BufferListener(buffer: SoundDevices.Buffer);
		BEGIN
			output.Append(buffer);
		END BufferListener;

	END SoundOutput;

	(** writes a raw pcm-date to a file *)
	TYPE FileOutput = OBJECT(SoundOutput)
		VAR
			filename-: ARRAY 64 OF CHAR;
			filenameSet: BOOLEAN;
			file: Files.File;
			writer: Files.Writer;
			frameCnt: LONGINT;

		PROCEDURE &Init*(nrOfBuffers, volume: LONGINT);
		BEGIN
			filenameSet := FALSE;
			file := NIL;
			frameCnt := 0;
			filename := ""
		END Init;

		PROCEDURE SetFilename*(VAR filename: ARRAY OF CHAR);
		BEGIN
			Strings.Append(SELF.filename, filename);
			filenameSet := TRUE
		END SetFilename;

		PROCEDURE CloseSoundChannel*;
		BEGIN
			(* close file *)
			IF file # NIL THEN
				writer.Update;
				Files.Register(file)
			END
		END CloseSoundChannel;

		PROCEDURE InitSoundChannel*(localNrOfChannels, samplingRate, localSamplingResolution: LONGINT);
		BEGIN
			nrOfChannels := localNrOfChannels;
			samplingResolution := localSamplingResolution;
			SetMinMaxAmplitudes();
			(* open a file *)
			IF filenameSet THEN
				file := Files.New(filename);
				Files.OpenWriter(writer, file, 0);
			END;
			initSoundChannelDone := TRUE
		END InitSoundChannel;

		PROCEDURE Output*(VAR input: ARRAY OF OGGUtilities.PCMBuffer; nrOfSamples: LONGINT);
			VAR i, ch, current: LONGINT;
		BEGIN
			INC(frameCnt);
			IF file # NIL THEN
				FOR i := 0 TO nrOfSamples - 1 DO
					FOR ch := nrOfChannels - 1 TO 0 BY -1 DO
						current := GetSample(input[ch].data[i]);
						IF samplingResolution = 8 THEN
							writer.Char(CHR(current))
						ELSIF samplingResolution = 16 THEN
							writer.RawInt(SHORT(current))
						END
					END
				END
			ELSE
				KernelLog.String("could not write frame# "); KernelLog.Int(frameCnt, 0); KernelLog.Ln
			END;
			writer.Update
		END Output;
	END FileOutput;

	VorbisDecoder* = OBJECT
		VAR
			buf: ARRAY MaxPageSize OF CHAR; (* why not this size? *)
			pos, packetCnt: LONGINT;
			appendPacket, firstDataPacket: BOOLEAN;
			info: Info;
			soundOutput: SoundOutput;
			bufReader: BufferReader;
			decState: DecoderState;
			nrOfSamplesPlayed: LONGINT;
			mdct: ARRAY 2 OF MdctObject; (* for each of the two blocksizes one Mdct *)

		PROCEDURE &Init*;
		BEGIN
			pos := 0; packetCnt := 0;
			firstDataPacket := TRUE;
			frameCnt := 0;
			NEW(info);
			NEW(bufReader);
			NEW(decState, info.channels)
		END Init;

		PROCEDURE ResetDecoder;
		BEGIN
			SELF.pos := 0
		END ResetDecoder;


		PROCEDURE Decode*(VAR buf: ARRAY OF CHAR; pos,len: LONGINT; continuedPacket:
					BOOLEAN; VAR soundOutput: SoundOutput): LONGINT;
		VAR
			i, typeLen: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@Decode()"); OGGUtilities.w.Ln;
			END;
			(* adjust pos ('vorbis'-string appears only in the three header packets
			or if it's a spanned packet over several pages and first byte with packet type will be used) *)
			typeLen := OggStreamTypeLength + 1;
			IF packetCnt > 2 THEN
				DEC(pos, typeLen)
			ELSIF packetCnt <= 2 THEN
				IF ~appendPacket THEN
					DEC(len, typeLen)
				ELSE
					DEC(pos, typeLen)
				END
			END;

			(* reset BufferReader if it's a new packet *)
			IF (~appendPacket) THEN bufReader.Init() END;

			(* save buf to SELF.buf *)
			i := 0;
			WHILE (i # len) DO
				SELF.buf[SELF.pos + i] := buf[pos + i]; INC(i)
			END;
			INC(SELF.pos, len);

			(* current position is equal to the length of the logical packet *)
			bufReader.SetLen(SELF.pos);

			(* start decoding (if packet is not going to be continued) *)
			IF ~continuedPacket THEN
				appendPacket := FALSE;
				RETURN StartDecode(soundOutput)
			ELSE
				appendPacket := TRUE;
				RETURN Ok
			END
		END Decode;

		(* start the decoding proccess *)
		PROCEDURE StartDecode(VAR soundOutput: SoundOutput): LONGINT;
		VAR res: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@StartDecode()")
			END;
			INC(packetCnt);
			 (* identification header *)
			IF (packetCnt = 1) THEN
				res := DecodeIdentificationHeader();
				IF (Codec IN Debug) THEN info.Print END

			 (* comment header *)
			ELSIF (packetCnt = 2) THEN
				res := DecodeCommentHeader();
				IF (Codec IN Debug) THEN info.comment.Print END

			 (* setup header *)
			ELSIF (packetCnt = 3) THEN
				res := DecodeSetupHeader(decState.codec);
				decState.info := info;
				IF ((info.bitrateMin > 0) & (info.bitrateMax > 0)) THEN
					KernelLog.String("bitrates (min/avg/max): ");
					KernelLog.Int(info.bitrateMin, 0);
					KernelLog.String(" / ");
					KernelLog.Int(info.bitrateNom, 0);
					KernelLog.String(" / ");
					KernelLog.Int(info.bitrateMax, 0);
					KernelLog.String(" bps")
				ELSE
					KernelLog.String("average bitrate: ");
					KernelLog.Int(info.bitrateNom, 0);
					KernelLog.String(" bps")
				END;
				KernelLog.Ln;
				IF (Codec IN Debug) THEN decState.codec.Print END

			 (* regular data packet *)
			ELSE
				IF ~decState.bufferAllocated THEN decState.AllocateBuffers(info.channels) END;
				DecodeDataPacket(res);
				IF ~soundOutput.initSoundChannelDone THEN
					soundOutput.InitSoundChannel(decState.info.channels, SHORT(decState.info.sampleRate), DefaultSamplingResolution)
				END;
				IF ~firstDataPacket THEN
					soundOutput.Output(decState.floor, decState.nrOfSamples);
					INC(nrOfSamplesPlayed, decState.nrOfSamples);
				ELSE
					firstDataPacket := FALSE
				END;

				res := Ok
			END;
			ResetDecoder();
			RETURN res
		END StartDecode;

		PROCEDURE DecodeIdentificationHeader(): LONGINT;
		VAR
			tmp: LONGINT;
			set: SET;
		BEGIN
			(* version *)
			info.version := bufReader.GetBits(buf, 32);
			IF (info.version # 0) THEN RETURN ErrorIdentification END;

			(* bitrate and samplerate *)
			info.channels := bufReader.GetBits(buf, 8);
			IF (info.channels > MaxChannels) THEN
				KernelLog.String("ASSERTION failed - too much channels"); KernelLog.Ln
			END;
			ASSERT(info.channels <= MaxChannels);
			info.sampleRate := bufReader.GetBits(buf, 32);
			info.bitrateMax := bufReader.GetBits(buf, 32);
			info.bitrateNom := bufReader.GetBits(buf, 32);
			info.bitrateMin := bufReader.GetBits(buf, 32);

			(* blocksizes *)
			tmp := bufReader.GetBits(buf, 4);
			info.blocksizes[0] := LSH(LONG(LONG(1)), tmp); (* blocksize0 := 2^tmp *)
			tmp := bufReader.GetBits(buf, 4);
			info.blocksizes[1] := LSH(LONG(LONG(1)), tmp); (* blocksize1 := 2^tmp *)
			IF (info.blocksizes[0] > info.blocksizes[1]) THEN RETURN ErrorIdentification END;

			(* framing bit *)
			set := SYSTEM.VAL(SET,bufReader.GetBit(buf));
			IF (set = {}) THEN RETURN ErrorIdentification END;

			RETURN Ok
		END DecodeIdentificationHeader;

		PROCEDURE DecodeCommentHeader(): LONGINT;
		VAR
			i, j: HUGEINT;
			commentElement: CommentListElement;
		BEGIN
			info.comment.vendorLength := bufReader.Get32UnsignedBits(buf);
			IF (info.comment.vendorLength > MaxVendorLength) THEN
				KernelLog.String("ASSERTION failed - vendorLength exceeds MaxVendorLength"); KernelLog.Ln
			END;
			ASSERT(info.comment.vendorLength <= MaxVendorLength);
			i := 0;
			FOR i := 0 TO info.comment.vendorLength-1 DO
				info.comment.vendorString[i] := bufReader.GetChar(buf);
			END;
			info.comment.length := bufReader.Get32UnsignedBits(buf);
			FOR i := 0 TO info.comment.length-1 DO
				NEW(commentElement);
				commentElement.length := bufReader.Get32UnsignedBits(buf);
				FOR j := 0 TO commentElement.length-1 DO
					commentElement.text[j] := bufReader.GetChar(buf);
				END;
				info.comment.Append(commentElement);
			END;
			info.comment.Print();
			RETURN Ok
		END DecodeCommentHeader;

		PROCEDURE DecodeSetupHeader(VAR codec: CodecSetup): LONGINT;
		VAR
			tmp, i, timeCnt: LONGINT;
			codebook: Codebook;
			floor1: FloorType1;
			residue: Residue;
			mapping: Mapping;
			mode: Mode;
		BEGIN
			(* read codebooks *)
			codec.codebookCnt := bufReader.GetBits(buf, 8) + 1;
			FOR i := 0 TO codec.codebookCnt - 1 DO
				NEW(codebook);
				IF ~codebook.DecodeHeader(bufReader, buf, i) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.Var("#codebooks", codec.codebookCnt);
						OGGUtilities.Var("error@VorbisCodec::Codebook::DecodeHeader() - error decoding codebookNr", i)
					END;
					RETURN ErrorSetup
				END;
				codec.codebooks[i] := codebook;
			END;

			(* time domain transforms *)
			timeCnt := bufReader.GetBits(buf, 6) + 1;
			FOR i := 0 TO timeCnt-1 DO
				tmp := bufReader.GetBits(buf, 16);
				IF (tmp # 0) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - time domain transformation error (see Vorbis documentation for further details")
					END;
					RETURN ErrorSetup
				END
			END;

			(* floor decode *)
			codec.floorCnt := bufReader.GetBits(buf, 6) + 1;
			FOR i := 0 TO codec.floorCnt - 1 DO
				codec.floorTypes[i] := bufReader.GetBits(buf, 16);
				IF codec.floorTypes[i] # 1 THEN
					KernelLog.String("ASSERTTION failed - FloorType0 not yet implemented")
				END;
				(* see FloorType0 for reason *)
				ASSERT(codec.floorTypes[i] = 1);
				(*
				IF (codec.floorTypes[i] = 0) THEN
					NEW(floor0);
					IF ~floor0.DecodeHeader(bufReader, buf, info) THEN
							IF (Error IN Debug) THEN
								OGGUtilities.String("error@DecodeSetupHeader() - error decoding floor0-header")
							END;
						RETURN ErrorSetup
					END;
					codec.floorConf[i] := floor0
					*)
				IF (codec.floorTypes[i] = 1) THEN
					NEW(floor1);
					IF ~floor1.DecodeHeader(bufReader, buf, info, codec) THEN
						IF (Error IN Debug) THEN
							OGGUtilities.String("error@DecodeSetupHeader() - error decoding floor type 1")
						END;
						RETURN ErrorSetup
					END;
					floor1.confNr := i;
					codec.floorConf[i] := floor1
				ELSE
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - invalid floor type")
					END;
					RETURN ErrorSetup
				END;
			END;

			(* residue decode *)
			codec.residueCnt := bufReader.GetBits(buf, 6) + 1;
			FOR i := 0 TO codec.residueCnt - 1 DO
				codec.residueTypes[i] := bufReader.GetBits(buf, 16);
				NEW(residue);
				IF (codec.residueTypes[i] > 2) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - invalid residue type")
					END;
					RETURN ErrorSetup
				END;
				NEW(residue);
				IF ~residue.DecodeHeader(bufReader, buf, info, codec) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - error decoding residue header")
					END;
					RETURN ErrorSetup;
				END;
				residue.nr := i;
				codec.residues[i] := residue;
			END;

			(* mapping decode *)
			codec.mappingCnt := bufReader.GetBits(buf, 6) + 1;
			FOR i := 0 TO codec.mappingCnt - 1 DO
				tmp := bufReader.GetBits(buf, 16);
				IF (tmp # 0) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - invalid mapping type")
					END;
					RETURN ErrorSetup;
				END;
				NEW(mapping);
				IF ~mapping.DecodeHeader(bufReader, buf, info, codec) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - error decoding mapping info")
					END;
					RETURN ErrorSetup
				END;
				mapping.nr := i;
				codec.mappings[i] := mapping
			END;

			(* mode decode *)
			codec.modeCnt := bufReader.GetBits(buf, 6) + 1;
			FOR i := 0 TO codec.modeCnt - 1 DO
				NEW(mode);
				IF ~mode.DecodeHeader(bufReader, buf, info, codec) THEN
					IF (Error IN Debug) THEN
						OGGUtilities.String("error@DecodeSetupHeader() - error decoding mode info")
					END;
					RETURN ErrorSetup
				END;
				codec.modes[i] := mode
			END;

			(* check framing *)
			tmp := bufReader.GetBits(buf, 1);
			IF (tmp = 0) THEN
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@DecodeSetupHeader() - framing-bit not set at the end of the codec-header")
				END;
				RETURN ErrorSetup
			END;
			RETURN Ok
		END DecodeSetupHeader;

		PROCEDURE DecodeDataPacket(res: LONGINT);
		BEGIN
			IF (Trace IN Debug) THEN OGGUtilities.String("@DecodeDataPacket()") END;
			INC(frameCnt);
			IF firstDataPacket THEN
				(* do stuff that is required only once *)
				NEW(mdct[0], info.blocksizes[0]);
				NEW(mdct[1], info.blocksizes[1]);
				NEW(decState.win, info.blocksizes[0], info.blocksizes[1])
			END;

			IF (bufReader.GetBits(buf, 1) # 0) THEN
				(* it's not a vorbis data packet *)
				IF (Error IN Debug) THEN
					OGGUtilities.String("error@DecodeDataPacket() - wrong packet type (0 expected)")
				END;
				decState.nrOfSamples := 0;
				res := NoDataPacket;
				RETURN
			END;

			decState.nrOfSamples := WindowDecode(res);
			IF res # Ok THEN RETURN END;

			res := FloorCurveDecode();
			NonzeroVectorPropagate();
			ResidueDecode();
			InverseCoupling();
			DotProduct();
			Mdct();
			WindowData();
			OverlapAdd();
			CacheRightHandData();

			res := Ok
		END DecodeDataPacket;

		(* cache the second half of the data and set the cache size correctly
		(cached data starts at offset 0) *)
		PROCEDURE CacheRightHandData;
		VAR ch, i: LONGINT;
		BEGIN
			IF decState.preCached THEN
				FOR ch := 0 TO decState.info.channels - 1 DO
					FOR i := 0 TO decState.n DIV 2 - 1 DO
						decState.rightCache[ch].data[i] := decState.residues[ch].data[i]
					END
				END
			ELSE
				FOR ch := 0 TO decState.info.channels - 1 DO
					FOR i := decState.n DIV 2 TO decState.n - 1 DO
						decState.rightCache[ch].data[i - decState.n DIV 2] := decState.floor[ch].data[i]
					END
				END
			END;
			decState.cacheSize := decState.n DIV 2
		END CacheRightHandData;

		(* overlap cached-data from previous frame with data from current frame
		data starts at offset 0 *)
		PROCEDURE OverlapAdd;
		VAR ch, i, start: LONGINT;
		BEGIN
			FOR ch := 0 TO decState.info.channels - 1 DO
				IF (decState.cacheSize = decState.n DIV 2) THEN
					decState.preCached := FALSE;
					(* previous frame had same size than current: just add cached data to current data *)
					FOR i := 0 TO decState.n DIV 2 - 1 DO
						INC(decState.floor[ch].data[i], decState.rightCache[ch].data[i]);
					END

				ELSIF (decState.cacheSize > decState.n DIV 2) THEN
					(* previous frame was a LONG one: add current data to cached data and insert it as current data *)
					start := (decState.cacheSize DIV 2) - (decState.n DIV 4);
					decState.preCached := TRUE;

					(* add floor data to cached data *)
					FOR i := 0 TO decState.n DIV 2 - 1 DO
						INC(decState.rightCache[ch].data[i + start], decState.floor[ch].data[i])
					END;

					(* pre-cache right floor-data *)
					FOR i:= decState.n DIV 2 TO decState.n - 1 DO
						decState.residues[ch].data[i - decState.n DIV 2] := decState.floor[ch].data[i]
					END;

					(* then copy all cached data to floor-data-vector *)
					FOR i := 0 TO decState.cacheSize - 1 DO
						decState.floor[ch].data[i] := decState.rightCache[ch].data[i]
					END

				ELSIF (decState.cacheSize < decState.n DIV 2) THEN
					(* previous frame was a SHORT one: add cached data to current data *)
					start := (decState.n DIV 4) - (decState.cacheSize DIV 2);
					decState.preCached := FALSE;
					FOR i := start TO start + decState.cacheSize - 1 DO
						INC(decState.floor[ch].data[i], decState.rightCache[ch].data[i - start])
					END;

					(* now, data from [0..leftStart] is all zero, move data to offset 0 *)
					FOR i := decState.win.leftStart TO decState.n DIV 2 - 1 DO
						decState.floor[ch].data[i - decState.win.leftStart] := decState.floor[ch].data[i]
					END
				END
			END
		END OverlapAdd;

		PROCEDURE WindowData;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO decState.info.channels - 1 DO
				decState.win.ApplyWindow(decState.floor[i].data, decState)
			END
		END WindowData;

		PROCEDURE Mdct;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO decState.info.channels - 1 DO
				mdct[decState.mode.blockflag].Backward(decState.floor[i].data)
			END
		END Mdct;

		PROCEDURE DotProduct;
		VAR i, n, chptr: LONGINT;
			residueVal, floorVal: HUGEINT;
		BEGIN
			(* multiply each element of the floor-vector with each element of the residue-vector *)
			n := decState.n DIV 2;
			FOR chptr := 0 TO decState.info.channels - 1 DO
				IF ~decState.doNotDecode[chptr] THEN
					FOR i := 0 TO n - 1 DO
						residueVal := decState.residues[chptr].data[i];
						floorVal := decState.floor[chptr].data[i];

						(* arguments must be in this order *)
						decState.floor[chptr].data[i] := OGGUtilities.MultDotProductFP(residueVal, floorVal);
					END
				ELSE
					decState.floor[chptr].ZeroBuffer()
				END
			END
		END DotProduct;

		PROCEDURE InverseCoupling;
		VAR
			i, j, angIdx, magIdx: LONGINT;
			newM, newA, m, a: HUGEINT; (* all fixed-point *)
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@InverseCoupling()")
			END;
			FOR i := decState.mapping.couplingSteps - 1 TO 0 BY -1 DO
				magIdx := decState.residueNumbers[decState.mapping.magnitude[i]];
				angIdx := decState.residueNumbers[decState.mapping.angle[i]];
				FOR j := 0 TO decState.n DIV 2 - 1 DO
					m := decState.residues[magIdx].data[j];
					a := decState.residues[angIdx].data[j];
					IF (m > 0) THEN
						IF (a > 0) THEN
							newM := m; newA := m - a
						ELSE
							newA := m; newM := m + a
						END
					ELSE
						IF (a > 0) THEN
							newM := m; newA := m + a
						ELSE
							newA := m; newM := m - a
						END
					END;
					decState.residues[magIdx].data[j] := newM;
					decState.residues[angIdx].data[j] := newA;
				END
			END;
		END InverseCoupling;

		PROCEDURE ResidueDecode;
		VAR i, j, residueNr, ch: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@ResidueDecode()")
			END;
			FOR i := 0 TO decState.mapping.submaps - 1 DO
				ch := 0;
				FOR j := 0 TO info.channels - 1 DO
					(* if channel [j] is in submap [i] *)
					IF (decState.mapping.mux[j] = i) THEN
						decState.doNotDecode[j] := decState.noResidue[j];
						INC(ch)
					END
				END;
				residueNr := decState.mapping.submapResidue[i];
				decState.residueType := decState.codec.residueTypes[residueNr];

				decState.codec.residues[residueNr].DecodePacket(bufReader, buf, decState, ch);

				ch := 0;
				FOR j := 0 TO info.channels - 1 DO
					(* if channel [j] is in submap [i] *)
					IF (decState.mapping.mux[j] = i) THEN
						decState.residueNumbers[j] := ch; (* used as an index for the residue-array *)
						INC(ch);
					END
				END (* FOR info.channels *)
			END (* FOR submaps *)
		END ResidueDecode;

		PROCEDURE NonzeroVectorPropagate;
		VAR i, magnitude, angle: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@NonZeroVectorPropagate()")
			END;
			FOR i := 0 TO decState.mapping.couplingSteps - 1 DO
				magnitude := decState.mapping.magnitude[i];
				angle := decState.mapping.angle[i];
				IF (~decState.noResidue[magnitude] OR ~decState.noResidue[angle]) THEN
					decState.noResidue[magnitude] := FALSE;
					decState.noResidue[angle] := FALSE
				END
			END
		END NonzeroVectorPropagate;

		PROCEDURE FloorCurveDecode(): LONGINT;
		VAR
			submapNumber, floorNumber, floorType, i, res: LONGINT;
			floor: AbstractFloorType;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@FloorCurveDecode()")
			END;
			FOR i := 0 TO info.channels - 1 DO
				submapNumber := decState.mapping.mux[i];
				floorNumber := decState.mapping.submapFloor[submapNumber];
				floorType := decState.codec.floorTypes[floorNumber];
				floor := decState.codec.floorConf[floorNumber];
				res := floor.DecodePacket(bufReader, buf, decState);
				IF (res = Ok) THEN
					floor.ComputeCurve(decState, i)
				END;
				decState.noResidue[i] := (res = ChannelNotUsed)
			END;
			RETURN res
		END FloorCurveDecode;

		(* calculate determining points of the window and return the amount of data to be returned *)
		PROCEDURE WindowDecode(VAR res: LONGINT): LONGINT;
		VAR modeNr, previousWindowFlag, nextWindowFlag, previousSize, currentSize: LONGINT;
		BEGIN
			IF (Trace IN Debug) THEN
				OGGUtilities.String("@WindowDecode()")
			END;
			res := Ok;
			modeNr := bufReader.GetBits(buf, OGGUtilities.ILog(decState.codec.modeCnt-1));

			decState.mode := decState.codec.modes[modeNr];
			decState.mapping := decState.codec.mappings[decState.mode.mapping];

			decState.n := info.blocksizes[decState.mode.blockflag];
			currentSize := decState.n;

			(* if end-of-stream (=packet) then return an error *)
			IF ~bufReader.IsOk(buf) THEN
				res := ErrorWindowDecode;
				RETURN 0
			END;

			IF (decState.mode.blockflag = 1) THEN
				(* its a long window *)
				previousWindowFlag := bufReader.GetBits(buf, 1);
				nextWindowFlag := bufReader.GetBits(buf, 1)
			ELSE
				previousWindowFlag := 0;
				nextWindowFlag := 0
			END;

			previousSize := decState.info.blocksizes[decState.lastWindowFlag];
			decState.lastWindowFlag := decState.mode.blockflag;

			decState.win.center := decState.n DIV 2;
			IF ((decState.mode.blockflag = 1) & (previousWindowFlag = 0)) THEN
				(* left side of window is a hybrid window for lapping with a short block *)
				decState.win.leftStart := decState.n DIV 4 - info.blocksizes[0] DIV 4;
				decState.win.leftEnd := decState.n DIV 4 + info.blocksizes[0] DIV 4;
				decState.win.leftSize := info.blocksizes[0] DIV 2
			ELSE
				(* left side will have normal shape *)
				decState.win.leftStart := 0;
				decState.win.leftEnd := decState.win.center;
				decState.win.leftSize := decState.n DIV 2
			END;
			IF ((decState.mode.blockflag = 1) & (nextWindowFlag = 0)) THEN
				(* right side of window is a hybrid window for lapping with a short block *)
				decState.win.rightStart := (decState.n * 3) DIV 4 - info.blocksizes[0] DIV 4;
				decState.win.rightEnd := (decState.n * 3) DIV 4 + info.blocksizes[0] DIV 4;
				decState.win.rightSize := info.blocksizes[0] DIV 2;

			ELSE
				(* right side will have normal shape *)
				decState.win.rightStart := decState.win.center;
				decState.win.rightEnd := decState.n;
				decState.win.rightSize := decState.n DIV 2
			END;
			RETURN (previousSize + currentSize) DIV 4
		END WindowDecode;
	END VorbisDecoder;

	(** DELEGATES *)
	(* delegate for residue-type-specific packet decoding *)
	ResiduePartitionProc = PROCEDURE {DELEGATE} (VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
													VAR decSate: DecoderState);
	(* slope-function vorbis window-type 0 *)
	SlopeFunction = PROCEDURE {DELEGATE} (x, n: LONGINT): REAL;
	(** decodes len bytes from the buffer starting at pos to a valid soundOutput *)
	Decoder* = PROCEDURE {DELEGATE} (VAR buf: ARRAY OF CHAR; pos, len: LONGINT; continuedPage: BOOLEAN;
										VAR soundOutput: SoundOutput): LONGINT;

	(* descending part of the window *)
	PROCEDURE SlopeRight(x, n: LONGINT): REAL;
		VAR res: REAL;
	BEGIN
		res := Math.sin( ((n - x - 0.5) / n) * (Math.pi / 2) );
		res := Math.sin( res * res * Math.pi / 2);
		RETURN res
	END SlopeRight;

	(* ascending part of the window *)
	PROCEDURE SlopeLeft(x, n: LONGINT): REAL;
		VAR res: REAL;
	BEGIN
		res := Math.sin( ((x + 0.5) / n) * (Math.pi / 2) );
		res := Math.sin( res * res * Math.pi / 2);
		RETURN res
	END SlopeLeft;

	(* for residue-type 0, used as a delegate *)
	PROCEDURE ResiduePartitionProc0(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
										VAR decState: DecoderState);
	VAR
		step, i, j, o, offset, entry, outputVectorNr: LONGINT;
		codebook: Codebook;
		t: OGGUtilities.Vector;
		resInfo: ResidueInfo;
	BEGIN
		resInfo := decState.resInfo;
		NEW(t);
		codebook := decState.codec.codebooks[resInfo.codebookNr];
		offset := resInfo.offset;
		outputVectorNr := resInfo.outputVectorNr;
		step := resInfo.partitionSize DIV codebook.dimensions;

		FOR i := 0 TO step - 1 DO
			entry := codebook.GetCodeword(bufReader, buf);
			t.Add(entry * codebook.dimensions)
		END;

		i := 0;
		o := 0;
		WHILE (i < codebook.dimensions) DO
			FOR j := 0 TO step - 1 DO
				INC(decState.residues[outputVectorNr].data[offset + o + j], codebook.valuelistFP[t.GetValueAt(j) + i])
			END;
			INC(o, step);
			INC(i)
		END
	END ResiduePartitionProc0;


	(* for residue-type 1, used as a delegate *)
	PROCEDURE ResiduePartitionProc1(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
											VAR decState: DecoderState);
	VAR
		i, j, t, outputVectorNr, offset, entry: LONGINT;
		codebook: Codebook;
		resInfo: ResidueInfo;
	BEGIN
		resInfo := decState.resInfo;
		codebook := decState.codec.codebooks[resInfo.codebookNr];
		outputVectorNr := resInfo.outputVectorNr;
		offset := resInfo.offset;

		WHILE (i < resInfo.partitionSize) DO
			entry := codebook.GetCodeword(bufReader, buf);
			t := entry * codebook.dimensions;
			j := 0;
			WHILE (j < codebook.dimensions) DO
				INC(decState.residues[outputVectorNr].data[offset + i], codebook.valuelistFP[t + j]);
				INC(j);
				INC(i)
			END
		END
	END ResiduePartitionProc1;

	(* for residue-type 2, used as a delegate *)
	PROCEDURE ResiduePartitionProc2(VAR bufReader: BufferReader; VAR buf: ARRAY OF CHAR;
												VAR decState: DecoderState);
	VAR i, j, entry, chptr, t, ch, offset, n, dim: LONGINT;
		cb: Codebook;
		resInfo: ResidueInfo;
	BEGIN
		resInfo := decState.resInfo;
		chptr := 0;
		cb := decState.codec.codebooks[resInfo.codebookNr];
		ch := resInfo.ch;
		offset := resInfo.offset;
		n := resInfo.partitionSize;
		dim := cb.dimensions;
		i := offset DIV resInfo.ch;
		WHILE (i < (offset + n) DIV ch) DO
			entry := cb.GetCodeword(bufReader, buf);
			t := entry * dim;
			FOR j := 0 TO dim - 1 DO
				INC(decState.residues[chptr].data[i], cb.valuelistFP[t + j]);
				INC(chptr);
				IF (chptr = ch) THEN
					chptr := 0;
					INC(i)
				END
			END
		END
	END ResiduePartitionProc2;

	(* lookup table for calculated floor values *)
	PROCEDURE InitInverseDBLookup;
	VAR InverseDBLookupReal: ARRAY 256 OF REAL;
		i: LONGINT;
	BEGIN
InverseDBLookupReal[0] := 0.00000010649863;
InverseDBLookupReal[1] := 0.00000011341951;
InverseDBLookupReal[2] := 0.00000012079015;
InverseDBLookupReal[3] := 0.00000012863978;
InverseDBLookupReal[4] := 0.00000013699951;
InverseDBLookupReal[5] := 0.00000014590251;
InverseDBLookupReal[6] := 0.00000015538408;
InverseDBLookupReal[7] := 0.00000016548181;
InverseDBLookupReal[8] := 0.00000017623575;
InverseDBLookupReal[9] := 0.00000018768855;
InverseDBLookupReal[10] := 0.00000019988561;
InverseDBLookupReal[11] := 0.0000002128753;
InverseDBLookupReal[12] := 0.00000022670913;
InverseDBLookupReal[13] := 0.00000024144197;
InverseDBLookupReal[14] := 0.00000025713223;
InverseDBLookupReal[15] := 0.00000027384213;
InverseDBLookupReal[16] := 0.00000029163793;
InverseDBLookupReal[17] := 0.00000031059021;
InverseDBLookupReal[18] := 0.00000033077411;
InverseDBLookupReal[19] := 0.00000035226968;
InverseDBLookupReal[20] := 0.00000037516214;
InverseDBLookupReal[21] := 0.00000039954229;
InverseDBLookupReal[22] := 0.0000004255068;
InverseDBLookupReal[23] := 0.00000045315863;
InverseDBLookupReal[24] := 0.00000048260743;
InverseDBLookupReal[25] := 0.00000051396998;
InverseDBLookupReal[26] := 0.00000054737065;
InverseDBLookupReal[27] := 0.00000058294187;
InverseDBLookupReal[28] := 0.00000062082472;
InverseDBLookupReal[29] := 0.00000066116941;
InverseDBLookupReal[30] := 0.00000070413592;
InverseDBLookupReal[31] := 0.00000074989464;
InverseDBLookupReal[32] := 0.00000079862701;
InverseDBLookupReal[33] := 0.0000008505263;
InverseDBLookupReal[34] := 0.00000090579828;
InverseDBLookupReal[35] := 0.00000096466216;
InverseDBLookupReal[36] := 0.0000010273513;
InverseDBLookupReal[37] := 0.0000010941144;
InverseDBLookupReal[38] := 0.0000011652161;
InverseDBLookupReal[39] := 0.0000012409384;
InverseDBLookupReal[40] := 0.0000013215816;
InverseDBLookupReal[41] := 0.0000014074654;
InverseDBLookupReal[42] := 0.0000014989305;
InverseDBLookupReal[43] := 0.0000015963394;
InverseDBLookupReal[44] := 0.0000017000785;
InverseDBLookupReal[45] := 0.0000018105592;
InverseDBLookupReal[46] := 0.0000019282195;
InverseDBLookupReal[47] := 0.0000020535261;
InverseDBLookupReal[48] := 0.0000021869758;
InverseDBLookupReal[49] := 0.0000023290978;
InverseDBLookupReal[50] := 0.0000024804557;
InverseDBLookupReal[51] := 0.0000026416497;
InverseDBLookupReal[52] := 0.000002813319;
InverseDBLookupReal[53] := 0.0000029961443;
InverseDBLookupReal[54] := 0.0000031908506;
InverseDBLookupReal[55] := 0.0000033982101;
InverseDBLookupReal[56] := 0.0000036190449;
InverseDBLookupReal[57] := 0.0000038542308;
InverseDBLookupReal[58] := 0.0000041047004;
InverseDBLookupReal[59] := 0.000004371447;
InverseDBLookupReal[60] := 0.0000046555282;
InverseDBLookupReal[61] := 0.0000049580707;
InverseDBLookupReal[62] := 0.000005280274;
InverseDBLookupReal[63] := 0.000005623416;
InverseDBLookupReal[64] := 0.0000059888572;
InverseDBLookupReal[65] := 0.0000063780469;
InverseDBLookupReal[66] := 0.0000067925283;
InverseDBLookupReal[67] := 0.0000072339451;
InverseDBLookupReal[68] := 0.0000077040476;
InverseDBLookupReal[69] := 0.0000082047;
InverseDBLookupReal[70] := 0.0000087378876;
InverseDBLookupReal[71] := 0.0000093057248;
InverseDBLookupReal[72] := 0.0000099104632;
InverseDBLookupReal[73] := 0.000010554501;
InverseDBLookupReal[74] := 0.000011240392;
InverseDBLookupReal[75] := 0.000011970856;
InverseDBLookupReal[76] := 0.000012748789;
InverseDBLookupReal[77] := 0.000013577278;
InverseDBLookupReal[78] := 0.000014459606;
InverseDBLookupReal[79] := 0.000015399272;
InverseDBLookupReal[80] := 0.000016400004;
InverseDBLookupReal[81] := 0.000017465768;
InverseDBLookupReal[82] := 0.000018600792;
InverseDBLookupReal[83] := 0.000019809576;
InverseDBLookupReal[84] := 0.000021096914;
InverseDBLookupReal[85] := 0.000022467911;
InverseDBLookupReal[86] := 0.000023928002;
InverseDBLookupReal[87] := 0.000025482978;
InverseDBLookupReal[88] := 0.000027139006;
InverseDBLookupReal[89] := 0.000028902651;
InverseDBLookupReal[90] := 0.000030780908;
InverseDBLookupReal[91] := 0.000032781225;
InverseDBLookupReal[92] := 0.000034911534;
InverseDBLookupReal[93] := 0.000037180282;
InverseDBLookupReal[94] := 0.000039596466;
InverseDBLookupReal[95] := 0.000042169667;
InverseDBLookupReal[96] := 0.00004491009;
InverseDBLookupReal[97] := 0.000047828601;
InverseDBLookupReal[98] := 0.000050936773;
InverseDBLookupReal[99] := 0.000054246931;
InverseDBLookupReal[100] := 0.000057772202;
InverseDBLookupReal[101] := 0.000061526565;
InverseDBLookupReal[102] := 0.000065524908;
InverseDBLookupReal[103] := 0.000069783085;
InverseDBLookupReal[104] := 0.000074317983;
InverseDBLookupReal[105] := 0.000079147585;
InverseDBLookupReal[106] := 0.00008429104;
InverseDBLookupReal[107] := 0.000089768747;
InverseDBLookupReal[108] := 0.000095602426;
InverseDBLookupReal[109] := 0.00010181521;
InverseDBLookupReal[110] := 0.00010843174;
InverseDBLookupReal[111] := 0.00011547824;
InverseDBLookupReal[112] := 0.00012298267;
InverseDBLookupReal[113] := 0.00013097477;
InverseDBLookupReal[114] := 0.00013948625;
InverseDBLookupReal[115] := 0.00014855085;
InverseDBLookupReal[116] := 0.00015820453;
InverseDBLookupReal[117] := 0.00016848555;
InverseDBLookupReal[118] := 0.00017943469;
InverseDBLookupReal[119] := 0.00019109536;
InverseDBLookupReal[120] := 0.00020351382;
InverseDBLookupReal[121] := 0.00021673929;
InverseDBLookupReal[122] := 0.00023082423;
InverseDBLookupReal[123] := 0.00024582449;
InverseDBLookupReal[124] := 0.00026179955;
InverseDBLookupReal[125] := 0.00027881276;
InverseDBLookupReal[126] := 0.00029693158;
InverseDBLookupReal[127] := 0.00031622787;
InverseDBLookupReal[128] := 0.00033677814;
InverseDBLookupReal[129] := 0.00035866388;
InverseDBLookupReal[130] := 0.00038197188;
InverseDBLookupReal[131] := 0.00040679456;
InverseDBLookupReal[132] := 0.00043323036;
InverseDBLookupReal[133] := 0.00046138411;
InverseDBLookupReal[134] := 0.00049136745;
InverseDBLookupReal[135] := 0.00052329927;
InverseDBLookupReal[136] := 0.00055730621;
InverseDBLookupReal[137] := 0.00059352311;
InverseDBLookupReal[138] := 0.00063209358;
InverseDBLookupReal[139] := 0.00067317058;
InverseDBLookupReal[140] := 0.000716917;
InverseDBLookupReal[141] := 0.0007635063;
InverseDBLookupReal[142] := 0.00081312324;
InverseDBLookupReal[143] := 0.00086596457;
InverseDBLookupReal[144] := 0.00092223983;
InverseDBLookupReal[145] := 0.00098217216;
InverseDBLookupReal[146] := 0.0010459992;
InverseDBLookupReal[147] := 0.0011139742;
InverseDBLookupReal[148] := 0.0011863665;
InverseDBLookupReal[149] := 0.0012634633;
InverseDBLookupReal[150] := 0.0013455702;
InverseDBLookupReal[151] := 0.0014330129;
InverseDBLookupReal[152] := 0.0015261382;
InverseDBLookupReal[153] := 0.0016253153;
InverseDBLookupReal[154] := 0.0017309374;
InverseDBLookupReal[155] := 0.0018434235;
InverseDBLookupReal[156] := 0.0019632195;
InverseDBLookupReal[157] := 0.0020908006;
InverseDBLookupReal[158] := 0.0022266726;
InverseDBLookupReal[159] := 0.0023713743;
InverseDBLookupReal[160] := 0.0025254795;
InverseDBLookupReal[161] := 0.0026895994;
InverseDBLookupReal[162] := 0.0028643847;
InverseDBLookupReal[163] := 0.0030505286;
InverseDBLookupReal[164] := 0.0032487691;
InverseDBLookupReal[165] := 0.0034598925;
InverseDBLookupReal[166] := 0.0036847358;
InverseDBLookupReal[167] := 0.0039241906;
InverseDBLookupReal[168] := 0.0041792066;
InverseDBLookupReal[169] := 0.004450795;
InverseDBLookupReal[170] := 0.0047400328;
InverseDBLookupReal[171] := 0.0050480668;
InverseDBLookupReal[172] := 0.0053761186;
InverseDBLookupReal[173] := 0.0057254891;
InverseDBLookupReal[174] := 0.0060975636;
InverseDBLookupReal[175] := 0.0064938176;
InverseDBLookupReal[176] := 0.0069158225;
InverseDBLookupReal[177] := 0.0073652516;
InverseDBLookupReal[178] := 0.0078438871;
InverseDBLookupReal[179] := 0.0083536271;
InverseDBLookupReal[180] := 0.0088964928;
InverseDBLookupReal[181] := 0.009474637;
InverseDBLookupReal[182] := 0.010090352;
InverseDBLookupReal[183] := 0.01074608;
InverseDBLookupReal[184] := 0.011444421;
InverseDBLookupReal[185] := 0.012188144;
InverseDBLookupReal[186] := 0.012980198;
InverseDBLookupReal[187] := 0.013823725;
InverseDBLookupReal[188] := 0.014722068;
InverseDBLookupReal[189] := 0.015678791;
InverseDBLookupReal[190] := 0.016697687;
InverseDBLookupReal[191] := 0.017782797;
InverseDBLookupReal[192] := 0.018938423;
InverseDBLookupReal[193] := 0.020169149;
InverseDBLookupReal[194] := 0.021479854;
InverseDBLookupReal[195] := 0.022875735;
InverseDBLookupReal[196] := 0.02436233;
InverseDBLookupReal[197] := 0.025945531;
InverseDBLookupReal[198] := 0.027631618;
InverseDBLookupReal[199] := 0.029427276;
InverseDBLookupReal[200] := 0.031339626;
InverseDBLookupReal[201] := 0.033376252;
InverseDBLookupReal[202] := 0.035545228;
InverseDBLookupReal[203] := 0.037855157;
InverseDBLookupReal[204] := 0.040315199;
InverseDBLookupReal[205] := 0.042935108;
InverseDBLookupReal[206] := 0.045725273;
InverseDBLookupReal[207] := 0.048696758;
InverseDBLookupReal[208] := 0.051861348;
InverseDBLookupReal[209] := 0.055231591;
InverseDBLookupReal[210] := 0.05882085;
InverseDBLookupReal[211] := 0.062643361;
InverseDBLookupReal[212] := 0.066714279;
InverseDBLookupReal[213] := 0.071049749;
InverseDBLookupReal[214] := 0.075666962;
InverseDBLookupReal[215] := 0.080584227;
InverseDBLookupReal[216] := 0.085821044;
InverseDBLookupReal[217] := 0.091398179;
InverseDBLookupReal[218] := 0.097337747;
InverseDBLookupReal[219] := 0.1036633;
InverseDBLookupReal[220] := 0.11039993;
InverseDBLookupReal[221] := 0.11757434;
InverseDBLookupReal[222] := 0.12521498;
InverseDBLookupReal[223] := 0.13335215;
InverseDBLookupReal[224] := 0.14201813;
InverseDBLookupReal[225] := 0.15124727;
InverseDBLookupReal[226] := 0.16107617;
InverseDBLookupReal[227] := 0.1715438;
InverseDBLookupReal[228] := 0.18269168;
InverseDBLookupReal[229] := 0.19456402;
InverseDBLookupReal[230] := 0.20720788;
InverseDBLookupReal[231] := 0.22067342;
InverseDBLookupReal[232] := 0.23501402;
InverseDBLookupReal[233] := 0.25028656;
InverseDBLookupReal[234] := 0.26655159;
InverseDBLookupReal[235] := 0.28387361;
InverseDBLookupReal[236] := 0.30232132;
InverseDBLookupReal[237] := 0.32196786;
InverseDBLookupReal[238] := 0.34289114;
InverseDBLookupReal[239] := 0.36517414;
InverseDBLookupReal[240] := 0.38890521;
InverseDBLookupReal[241] := 0.41417847;
InverseDBLookupReal[242] := 0.44109412;
InverseDBLookupReal[243] := 0.4697589;
InverseDBLookupReal[244] := 0.50028648;
InverseDBLookupReal[245] := 0.53279791;
InverseDBLookupReal[246] := 0.56742212;
InverseDBLookupReal[247] := 0.6042964;
InverseDBLookupReal[248] := 0.64356699;
InverseDBLookupReal[249] := 0.68538959;
InverseDBLookupReal[250] := 0.72993007;
InverseDBLookupReal[251] := 0.77736504;
InverseDBLookupReal[252] := 0.8278826;
InverseDBLookupReal[253] := 0.88168307;
InverseDBLookupReal[254] := 0.9389798;
InverseDBLookupReal[255] := 1;

		(* scale the values according to current scale factor*)
		FOR i := 0 TO 255 DO
			InverseDBLookup[i] := OGGUtilities.ScaleUp(InverseDBLookupReal[i])
		END
	END InitInverseDBLookup;

	(** Tools *)
	(** start playing an ogg-stream
			= possible arguments are:
				- ogg/vorbis-file
				- URL of a ogg/vorbis radio-station ( *.ogg or *.m3u)
			= no need to stop any old sources
		*)
	PROCEDURE PlayURL*(url: Strings.String): BOOLEAN;
	VAR
		isWebStream: BOOLEAN;
		dec: VorbisDecoder;
		ogg: OggStreamReader;
		f: Files.File;
		fr: Files.Reader;
		r : Streams.Reader;
		output: SoundOutput;
		rh : WebHTTP.RequestHeader;
		h : WebHTTP.ResponseHeader;
		res, volume, nrOfBuffers: LONGINT;
		con : TCP.Connection;
		outputFilename: ARRAY 64 OF CHAR;
		timer: Kernel.Timer;
	BEGIN
		IF playing THEN
			(* if it's already playing sth, stop old song and start new one *)
			stopped := TRUE;
			NEW(timer);
			timer.Sleep(1000);
		END;

		IF ~playing THEN

			(* prepare playing *)
			NEW(dec);
			nrOfBuffers := 32;
			volume := 55;
			NEW(output, nrOfBuffers, volume);

			IF IsWebStream(url) THEN
				(* streaming from the internet *)
				IF IsM3UPlaylist(url) THEN
					GetURLFromM3U(url)
				END;

				(* if interpretation failed (it's still a m3u) for some reason exit *)
				IF IsM3UPlaylist(url) THEN
					KernelLog.String("can not interpret m3u-playlist - exiting"); KernelLog.Ln;
					RETURN FALSE
				END;

				KernelLog.String("playing ogg-radio: "); KernelLog.String(url^); KernelLog.Ln;
				isWebStream := TRUE;
				rh.useragent := "Bluebottle OGG Player/0.1";
				WebHTTPClient.Get(url^, rh, con, h, r, res);
				IF res # 0 THEN
					KernelLog.String("Could not open stream");
					KernelLog.Ln;
					RETURN FALSE
				END
			ELSE
				(* playing from a local file *)
				isWebStream := FALSE;
				KernelLog.String("playing ogg-soundfile: "); KernelLog.String(url^); KernelLog.Ln;
				IF (output IS FileOutput) THEN
					Strings.Append(outputFilename, url^);
					Strings.Append(outputFilename, ".pcm");
					KernelLog.String(outputFilename); KernelLog.Ln;
					output(FileOutput).SetFilename(outputFilename)
				END;
				f := Files.Old(url^);
				Files.OpenReader(fr, f, 0);
				r := fr;
				IF r = NIL THEN
					KernelLog.String("Could not open file");
					KernelLog.Ln;
					RETURN FALSE
				END
			END;

			(* allocate an OggStreamReader ... *)
			NEW(ogg, r);

			(* ... and start playing *)
			res:= ogg.RegisterDecoder(dec.Decode, output, Vorbis);
			IF res = Ok THEN
				playing := TRUE;
				res := ogg.Start();
				playing := FALSE;
				stopped := FALSE
			END;
			ogg.Stop()
			(* finished playing *)
		ELSE
			KernelLog.String("is already playing something"); KernelLog.Ln
		END;

		(* close tcp-connection if any *)
		IF con # NIL THEN
			KernelLog.String("closing connection"); KernelLog.Ln;
			con.Close()
		END;
		RETURN TRUE;
	END PlayURL;

	(** start playing an ogg-stream
			= possible arguments ("command line") are:
				- ogg/vorbis-file
				- URL of a ogg/vorbis radio-station ( *.ogg or *.m3u)
			= no need to stop any old sources
		*)
	PROCEDURE Play*(context : Commands.Context);
	VAR
		url: ARRAY 256 OF CHAR;
		tmpBool: BOOLEAN;
	BEGIN
		context.arg.String(url);
		tmpBool := PlayURL(Strings.NewString(url));
	END Play;

	PROCEDURE StopURL*;
	BEGIN
		stopped := TRUE
	END StopURL;

	PROCEDURE Stop*(context : Commands.Context);
	BEGIN
		StopURL();
		context.out.String("Player stopped."); context.out.Ln;
	END Stop;

	PROCEDURE IsWebStream(VAR url: Strings.String): BOOLEAN;
	BEGIN
		RETURN Strings.Pos("http://", url^) > -1
	END IsWebStream;

	PROCEDURE IsM3UPlaylist(VAR url: Strings.String): BOOLEAN;
	BEGIN
		RETURN Strings.Pos(".m3u", url^) > -1
	END IsM3UPlaylist;

	PROCEDURE GetURLFromM3U(VAR url: Strings.String);
	VAR res: LONGINT;
		rh : WebHTTP.RequestHeader;
		h : WebHTTP.ResponseHeader;
		con : TCP.Connection;
		r : Streams.Reader;
	BEGIN
		WebHTTPClient.Get(url^, rh, con, h, r, res);
		r.Token(url^)
	END GetURLFromM3U;

	PROCEDURE Cleanup;
	VAR
		timer: Kernel.Timer;
	BEGIN
		NEW(timer);
		stopped := TRUE;
		(* give some time to close the sound-channel properly *)
		timer.Sleep(2000);
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	FloorRanges[0] := 256;
	FloorRanges[1] := 128;
	FloorRanges[2] := 86;
	FloorRanges[3] := 64;
	OggS[0] := "O";
	OggS[1] := "g";
	OggS[2] := "g";
	OggS[3] := "S";
	nrOfPages := 0;
	stopped := FALSE;
	playing := FALSE;
	InitInverseDBLookup;

	OGGUtilities.InitLogger;
END OGGVorbisPlayer.

SystemTools.Free WMOGGPlayer OGGVorbisPlayer OGGUtilities ~
MixerComponents.MasterIncVol ~
MixerComponents.MasterDecVol ~
OGGVorbisPlayer.Stop ~

#Free Audio
OGGVorbisPlayer.Play epoq.ogg ~
OGGVorbisPlayer.Play hydrate.ogg ~
OGGVorbisPlayer.Play mistoftime.ogg ~
OGGVorbisPlayer.Play lumme.ogg ~
