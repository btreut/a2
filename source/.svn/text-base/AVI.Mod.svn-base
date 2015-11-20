MODULE AVI;

(* Procedures to read an .avi file *)
(* Written by Thomas Trachsel, ttrachsel@web.de, 18.9.2003 *)
(* Extended with indexfunctionality and adaptation on Codecs by Urs Müller, October 2004 *)
(* Cleaned by PL, March 2005 *)

IMPORT
	SYSTEM, Machine, Streams, KernelLog, AOC := Codecs;

	CONST
		Debug = FALSE;
		DefaultReaderSize = 4096;
		WriteError = 2907;

	(* Steht jetzt einmal hier, kann man vielleicht in AVIDemux reinpacken, mal schauen *)
	TYPE
		(* Structure that contains the main informations of the .avi file *)
		MainAVIHeaderDesc* = OBJECT
		VAR
			microSecsPerFrame*: LONGINT;
			maxBytesPerSec*: LONGINT;
			reserved1*: LONGINT;
			flags*: LONGINT;
			totalFrames*: LONGINT;
			initialFrames*: LONGINT;
			streams*: LONGINT;
			suggestedBufferSize*: LONGINT;
			width*: LONGINT;
			height*: LONGINT;
			reserved*: ARRAY 4 OF LONGINT;
		END MainAVIHeaderDesc;

		(* Structure that contains the main Info of a stream in a .avi file *)
		AVIStreamHeader* = OBJECT
		VAR
			fccType*: ARRAY 4 OF CHAR;
			fccHandler*: ARRAY 4 OF CHAR;
			flags*: LONGINT;
			priority*: LONGINT;
			initialFrames*: LONGINT;
			scale*: LONGINT;
			rate*: LONGINT;
			start*: LONGINT;
			length*: LONGINT;
			suggestedBufferSize*: LONGINT;
			quality*: LONGINT;
			sampleSize*: LONGINT;
			left*: LONGINT;
			top*: LONGINT;
			right*: LONGINT;
			bottom*: LONGINT;
			streamIdentifier*: ARRAY 4 OF CHAR;
			bitMapInfo*: BitMapInfo;
			waveFormatEx*: WAVEFormatEx;
		END AVIStreamHeader;

		(* video stream specific infos *)
		BitMapInfo = OBJECT
		VAR
			size*: LONGINT;
			width*: LONGINT;
			height*: LONGINT;
			planes*: LONGINT;
			bitCount*: LONGINT;
			compression*: LONGINT;
			sizeImage*: LONGINT;
			xPelsPerMeter*: LONGINT;
			yPelsPerMeter*: LONGINT;
			clrUsed*: LONGINT;
			clrImportant*: LONGINT;
		END BitMapInfo;

		(* audio stream specific infos *)
		WAVEFormatEx* = OBJECT
		VAR
			formatTag*: LONGINT;
			channels*: LONGINT;
			samplesPerSec*: LONGINT;
			avgBytesPerSec*: LONGINT;
			blockAlign*: LONGINT;
			bitsPerSample*: LONGINT;
			cbSize*: LONGINT;
		END WAVEFormatEx;

		(* IndexChunk infos *)
		AVIIndexEntry* = RECORD
			ckid*: LONGINT;
			flags*: LONGINT;
			offset*: LONGINT;
			length*: LONGINT;
			tot*: LONGINT;
		END;

	TYPE IndexArrayPointer* = POINTER TO ARRAY OF AVIIndexEntry;

	(* Stream for reading a Stream of an .avi file *)
	TYPE AVIStream* = OBJECT(AOC.DemuxStream)
		VAR
			bufAdr: LONGINT;
			r : Streams.Reader;
			chunkSize*: LONGINT;	(* Bytes in actual AVI Chunk *)
			streamHeader: AVIStreamHeader;
			stuffByte*: LONGINT;
			eof*: BOOLEAN;	(* End of File *)

		(* Constructor *)
		PROCEDURE & Init*( r: Streams.Reader;  streamHdr: AVIStreamHeader);
		BEGIN
			bufAdr := 0;
			chunkSize := 0;
			streamHeader := streamHdr;
			SELF.r := r;
			ASSERT(SELF.r # NIL);
			stuffByte := 0;
			eof := FALSE;
		END Init;

		(* Returns TRUE if the underlying reader supports seeking.  *)
		PROCEDURE CanSetPos*() : BOOLEAN;
		BEGIN
			RETURN r.CanSetPos();
		END CanSetPos;

		(* Compare two array up to len bytes *)
		PROCEDURE CompareCharArrays(ar1,ar2 : ARRAY OF CHAR; len: LONGINT ): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			IF ( len > LEN( ar1 ) ) OR ( len > LEN( ar2 ) ) THEN
				RETURN FALSE
			END;

			FOR i := 0 TO len-1 DO
				IF ar1[i] # ar2[i] THEN
					RETURN FALSE
				END;
			END;
			RETURN TRUE
		END CompareCharArrays;

		(* Seek the next chunk of our stream in the avi file and read it *)
		PROCEDURE  ReadNextChunk(VAR buf:  ARRAY OF CHAR);
		VAR
			tempBuf: ARRAY 4 OF CHAR;
			len: LONGINT;
			done: BOOLEAN;
		BEGIN
			IF Debug THEN KernelLog.String("Read next Chunk"); KernelLog.Ln; END;
			done := FALSE;
			eof := FALSE;

			(* Undocument in .avi docu; if the size of a chunk is odd, we have to skip one byte *)
			IF stuffByte > 0 THEN
				r.SkipBytes( 1 );
				stuffByte := 0
			END;

			REPEAT
				r.Bytes(tempBuf, 0, 4, len );
				IF r.res = Streams.Ok THEN
					r.RawLInt(len);
					stuffByte := len MOD 2;
					IF r.res = Streams.Ok THEN
						IF Debug THEN
							KernelLog.String( "AVIStream: Found Chunk : " );
							KernelLog.Hex( ORD( tempBuf[0] ), 0 ); KernelLog.Hex( ORD( tempBuf[1] ), 0 );
							KernelLog.Hex( ORD( tempBuf[2] ), 0 ); KernelLog.Hex( ORD( tempBuf[3] ), 0 ); KernelLog.String(" ");
							KernelLog.Char( tempBuf[0] ); KernelLog.Char( tempBuf[1] ); KernelLog.Char( tempBuf[2] );
							KernelLog.Char( tempBuf[3] ); KernelLog.String( "@Pos: "); KernelLog.Int( r.Pos() - 8, 0 );
							KernelLog.String( " SkipBytes: " ); KernelLog.Int( len, 0 ); KernelLog.Ln();
						END;
						IF CompareCharArrays( tempBuf, streamHeader.streamIdentifier, 4 ) THEN
							(* We found the correct chunk *)
							IF len > 0 THEN
								done := TRUE;
								bufAdr := ADDRESSOF( buf[0] );
								r.Bytes( buf, 0, len, chunkSize );
								buf[len] := CHR( 0 ); buf[len+1] := CHR( 0 ); buf[len+2] := CHR( 0 ); buf[len+3] := CHR( 0 );
								ASSERT( len = chunkSize );
							END;
						ELSE
							r.SkipBytes( len + stuffByte )
						END;
					ELSE
						eof := TRUE;
						res := Streams.EOF;
						KernelLog.String("ENDE");
					END;
				ELSE
					eof := TRUE;
					res := Streams.EOF;
					KernelLog.String("ENDE");
				END;
			UNTIL ( done OR eof );
		END ReadNextChunk;

		(* Go to the beginnig of the next frame -> Read next chunk *)
		PROCEDURE Resynch*(VAR buf: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			ReadNextChunk(buf);
			RETURN ~eof
		END Resynch;

		(* Return Pos in Avi File, relativ to the beginning of the stream data *)
		PROCEDURE Pos*(): LONGINT;
		BEGIN
			RETURN r.Pos()
		END Pos;

		(* Set the Position of the AVIReader. If frame flag is set, position is interpreted as a framenumber *)
		PROCEDURE SetAVIPos*(pos: LONGINT;  VAR retPos: LONGINT);
		BEGIN
			IF Debug THEN KernelLog.String("DemuxStream.SetAVIPos"); KernelLog.Ln; END;
			r.SetPos(pos);
			stuffByte := 0;
			retPos := r.Pos();
			Reset;
		END SetAVIPos;

		PROCEDURE Bytes*(VAR x: ARRAY OF CHAR; ofs, size: LONGINT; VAR len: LONGINT);
		VAR
			min, res: LONGINT;
		BEGIN
			IF Debug THEN KernelLog.String("Bytes"); KernelLog.Ln; END;
			demultiplexer.GetData(streamNr, x, ofs, size, min, len, res);
		END Bytes;

		(* Set Byte Position *)
		PROCEDURE SetPos*(pos : LONGINT);
		VAR seekType, itemSize, res : LONGINT;
		BEGIN
			IF Debug THEN KernelLog.String("DemuxStream.SetPos"); KernelLog.Ln; END;
			seekType := AOC.SeekByte;
			demultiplexer.SetStreamPos(streamNr, seekType, pos, itemSize, res);
			Reset;
		END SetPos;

	END AVIStream;

	(* The .avi File Demultiplexer *)
	AVIDemux* = OBJECT(AOC.AVDemultiplexer)
	VAR
		r : Streams.Reader;
		filename* : ARRAY 256 OF CHAR;

		(* We need just these 3 Headers *)
		aviHeader: MainAVIHeaderDesc;
		audioStreamHeader: AVIStreamHeader;
		videoStreamHeader: AVIStreamHeader;
		riffLength: LONGINT;

		movieBeginPos: LONGINT;
		indexStart: LONGINT;
		videoFrames: LONGINT;
		audioChunks: LONGINT;
		videoIndex: IndexArrayPointer;
		audioIndex: IndexArrayPointer;
		audioBytes: LONGINT;

		videoBufferIndex: LONGINT;

		audioChunkSize: LONGINT;

		audioStream: AVIStream;
		videoStream: AVIStream;
		videoFramePos: LONGINT;
		audioFramePos: LONGINT;

		PROCEDURE Open*(in : Streams.Reader; VAR res : LONGINT);
		BEGIN
			r := in;
			res := AOC.ResFailed;

			IF in IS AOC.FileInputStream	THEN
				in(AOC.FileInputStream).f.GetName(filename);
				IF ReadHeader() THEN res := AOC.ResOk 	END
			ELSE RETURN END;													(* bad bad bad *)

		END Open;

		PROCEDURE GetAVIHeader*(): MainAVIHeaderDesc;
		BEGIN
			RETURN aviHeader
		END  GetAVIHeader;

		(* Compare two arrays up to len bytes *)
		PROCEDURE CompareCharArrays( ar1,ar2 : ARRAY OF CHAR; len: LONGINT ): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			IF ( len > LEN( ar1 ) ) OR ( len > LEN( ar2 ) ) THEN
				RETURN FALSE
			END;

			FOR i := 0 TO len-1 DO
				IF ar1[i] # ar2[i] THEN
					RETURN FALSE
				END;
			END;
			RETURN TRUE
		END CompareCharArrays;

		(* Read .avi FIle Header *)
		PROCEDURE ReadHeader*(): BOOLEAN;
		VAR
			buf : ARRAY 8 OF CHAR;
			len: LONGINT;
			done: BOOLEAN;
			headerLength: LONGINT;
			headerBeginPos: LONGINT;

			tempHeader: AVIStreamHeader;
			streamNumber: SHORTINT;

		BEGIN
			done := FALSE;
			streamNumber := 0;
			riffLength := 0;
			aviHeader := NIL;
			audioStreamHeader := NIL;
			videoStreamHeader := NIL;

			ASSERT(r # NIL);

			(* Check, if we have a valid avi file *)
			r.Bytes( buf,0,4,len );
			IF CompareCharArrays( buf, "RIFF" ,4 ) # TRUE THEN
				KernelLog.String( "Not a valid .avi File!" ); KernelLog.Ln;
				RETURN FALSE
			END;
			r.RawLInt(riffLength);

			r.Bytes( buf,0,4, len );
			IF CompareCharArrays( buf, "AVI ",4 ) # TRUE THEN
				KernelLog.String( "Only .avi Files that contain a video stream are allowed" ); KernelLog.Ln();
				RETURN FALSE
			END;

			(* Read AVI Headers *)
			REPEAT
				r.Bytes( buf,0,4, len );
				IF CompareCharArrays( buf, "LIST",4 ) THEN
					(* We found an additional Header *)
					(* Store Infos about header *)
					r.RawLInt(headerLength);

					headerLength := headerLength + headerLength MOD 2;
					headerBeginPos := r.Pos();
					r.Bytes( buf,0,4, len );

					(* Main AVI Header *)
					IF CompareCharArrays(buf, "hdrl",4) THEN
						r.Bytes( buf,0,4, len );
						IF CompareCharArrays(buf, "avih",4) THEN
								aviHeader := ReadMainAVIHeader()
						ELSE
							SkipHeader()
						END;
					(* Stream Header *)
					ELSIF CompareCharArrays( buf, "strl",4 ) THEN
						r.Bytes( buf,0,4, len );
						IF CompareCharArrays( buf, "strh",4 ) THEN
							tempHeader := ReadAVIStreamHeader();

							IF CompareCharArrays(tempHeader.fccType, "vids",4) THEN
								r.SkipBytes(4); (* Skip "strf" *)

								IF videoStreamHeader = NIL THEN
									videoStreamHeader := tempHeader;
									videoStreamHeader.streamIdentifier[0] := "0";
									videoStreamHeader.streamIdentifier[1] := CHR( ORD( '0' ) + streamNumber );
									videoStreamHeader.streamIdentifier[2] := "d";
									videoStreamHeader.streamIdentifier[3] := "c";
									INC(streamNumber)
								END;
								tempHeader := NIL;

								IF videoStreamHeader.bitMapInfo = NIL THEN
									videoStreamHeader.bitMapInfo := ReadBitMapInfo();
									videoStreamHeader.waveFormatEx := NIL
								ELSE
									SkipHeader()
								END;
							ELSIF CompareCharArrays(tempHeader.fccType, "auds",4) THEN
								r.SkipBytes(4);

								IF audioStreamHeader = NIL THEN
									audioStreamHeader := tempHeader;
									audioStreamHeader.streamIdentifier[0] := "0";
									audioStreamHeader.streamIdentifier[1] := CHR( ORD('0') + streamNumber );
									audioStreamHeader.streamIdentifier[2] := "w";
									audioStreamHeader.streamIdentifier[3] := "b";
									INC(streamNumber)
								END;
								tempHeader := NIL;

								IF audioStreamHeader.waveFormatEx = NIL THEN
									audioStreamHeader.waveFormatEx := ReadWaveFormatEx();
									audioStreamHeader.bitMapInfo := NIL
								ELSE
									SkipHeader()
								END;
							ELSE
								IF Debug THEN
									KernelLog.String( "AVIDemux: Unknown AviStream found; " ); KernelLog.String(tempHeader.fccType);
									KernelLog.Ln()
								END;
							END;
						END;
					ELSIF CompareCharArrays(buf, "movi",4) THEN
						(* movie data begin, including movi Tag *)
 						movieBeginPos := r.Pos()-4;

 						(* this could be improved... *)
 						r.SetPos(headerLength+movieBeginPos);			(* headerLength); *)

						r.Bytes(buf,0,4,len);

 						IF CompareCharArrays(buf, "idx1",4) THEN
 							(* There is an index *)

 							(* Start of Index including idx1 Tag *)
 							indexStart := r.Pos()-4;
 							ReadIndex();
							IF Debug THEN
								KernelLog.String("AVIDemux: Start of movie stream found " ); KernelLog.Ln()
							END;
						ELSE
							videoIndex := NIL;
							audioIndex := NIL;
						END;
						r.SetPos(movieBeginPos+4);

						done := TRUE;
					ELSE
						IF Debug THEN
							KernelLog.String("AVIDemux: Unknown StreamHeader found: " ); KernelLog.String(buf); KernelLog.Ln()
						END;
						r.SkipBytes( headerLength - ( r.Pos() - headerBeginPos ) )
					END;
				ELSE
					(* Unknown Header -> Skip *)
					IF Debug THEN
						KernelLog.String("AVIDemux: Unknown Header found: " ); KernelLog.Buffer(buf,0,4); KernelLog.Ln()
					END;
					SkipHeader();
				END;
			UNTIL done;

			IF Debug THEN
				DumpHeaders();
			END;

			RETURN TRUE
		END ReadHeader;

		(* Noch ueberlegen: BOOLEAN Rueckgabe, wenn kein Index dann False *)
		PROCEDURE ReadIndex*;
		VAR
			buf : ARRAY 8 OF CHAR;
			buf2 : ARRAY 8 OF CHAR;
			indexLength: LONGINT;
			nidx: LONGINT;
			idxType: INTEGER;
			i: LONGINT;
			pos: LONGINT;
			length: LONGINT;
			len: LONGINT;
			temp: LONGINT;
			nai: LONGINT;
			nvi: LONGINT;
			tot: LONGINT;
			ioff: LONGINT;

		BEGIN
 			r.RawLInt(indexLength);

 			nidx := indexLength DIV 16;
 			idxType := 0;
 			i := 0;
 			LOOP
 				r.Bytes(buf, 0, 4, len);
 				IF CompareCharArrays(buf, videoStreamHeader.streamIdentifier, 3) THEN
 					i := i+1;
 					(* Not shure, wether this is necessary - but everything works fine with it *)
 					indexStart := r.Pos()-4;
 					EXIT;
 				END;
 				IF i >= nidx THEN
 					KernelLog.String("No Index found"); KernelLog.Ln();
 					EXIT;
 				END;
 			END;

 			r.SkipBytes(4);
 			r.RawLInt(pos);
 			r.RawLInt(length);
 			r.SetPos(pos);

 			(* Index from start of File*)
 			IF CompareCharArrays(buf2, buf, 4) THEN
 				r.RawLInt(temp);

 				IF (temp = length) THEN
 					idxType := 1;
 				END;
 			ELSE
 				r.SetPos(pos + movieBeginPos);

 				r.Bytes(buf2, 0, 4, len);
 				IF CompareCharArrays(buf2, buf, 4) THEN
 					r.RawLInt(temp);

 					IF (temp = length) THEN
 						idxType := 2;
 					END;
 				END;
 			END;

 			(* now go on according to indexType *)
 			IF idxType = 0 THEN
 				KernelLog.String("File without index: Not supported yet");
 				(* And trap here ... *)
 			END;

 			(* The 0 case: no index. It is possible to generate an index b y traversing the whole file 	*)
 			(* For now we simply declare the file as not seekable										*)

 			IF idxType # 0 THEN
 				nai := 0;
 				nvi := 0;

 				r.SetPos(indexStart);

 				i := 0;
 				(* Count, how many entries there are (the number would also be in the header, 	*)
 				(* but if there is no index, you have to do this anyway)							*)
 				REPEAT
 					r.Bytes(buf, 0, 4, len);
 					IF CompareCharArrays(buf, videoStreamHeader.streamIdentifier, 3) THEN
 						nvi := nvi+1;
 					ELSE
 						IF audioStreamHeader # NIL THEN
 							IF CompareCharArrays(buf, audioStreamHeader.streamIdentifier, 4) THEN
 								nai := nai+1;
 							END;
 						END;
 					END;
 					r.SkipBytes(12);
 					i := i+1;
 				UNTIL (i = nidx-1);

 				videoFrames := nvi;
 				audioChunks := nai;
				NEW(videoIndex, nvi);

 				(* Vielleicht haben wir ja nur Bilder... *)
 				IF (audioChunks > 0) THEN
 					NEW(audioIndex, nai);
 				END;

 				(* So, und jetzt die Arrays fuellen *)
 				nvi := 0;
 				nai := 0;
 				tot := 0;
 				r.SetPos(indexStart);

 				IF (idxType = 1) THEN
 					ioff := 8;
 				ELSE
 					ioff := movieBeginPos;
 				END;

 				i := 0;
 				REPEAT
 					r.Bytes(buf, 0, 4, len);
 					IF CompareCharArrays(buf, videoStreamHeader.streamIdentifier, 3) THEN
 						r.RawLInt(videoIndex[nvi].flags);
 						r.RawLInt(videoIndex[nvi].offset);
 						videoIndex[nvi].offset := videoIndex[nvi].offset + ioff;
 						r.RawLInt(videoIndex[nvi].length);
 						nvi := nvi+1;
 					ELSE
 						IF CompareCharArrays(buf, audioStreamHeader.streamIdentifier, 4) THEN
 							r.SkipBytes(4);
 							r.RawLInt(audioIndex[nai].offset);
 							audioIndex[nai].offset := audioIndex[nai].offset + ioff;
 							r.RawLInt(audioIndex[nai].length);
 							audioIndex[nai].tot := tot;
 							tot := tot + audioIndex[nai].length;
 							nai := nai+1;
 						END;
 					END;
 					i := i+1;
 				UNTIL (i = nidx-1);
 				audioBytes := tot;
 			END;
		END ReadIndex;

		(* Skip chunk *)
		PROCEDURE SkipHeader*;
		VAR
			length: LONGINT;
		BEGIN
			r.RawLInt(length);
			r.SkipBytes( length + length MOD 2)
		END SkipHeader;

		(* Read Main AVI Header *)
		PROCEDURE ReadMainAVIHeader(): MainAVIHeaderDesc;
		VAR
			aviHeader: MainAVIHeaderDesc;
			headerLength: LONGINT;
			startPos: LONGINT;
		BEGIN
			NEW( aviHeader );

			r.RawLInt(headerLength);
			startPos := r.Pos();

			r.RawLInt( aviHeader.microSecsPerFrame );
			r.RawLInt( aviHeader.maxBytesPerSec );
			r.RawLInt( aviHeader.reserved1 );
			r.RawLInt( aviHeader.flags );
			r.RawLInt( aviHeader.totalFrames );
			r.RawLInt( aviHeader.initialFrames );
			r.RawLInt( aviHeader.streams );
			r.RawLInt( aviHeader.suggestedBufferSize );
			r.RawLInt( aviHeader.width );
			r.RawLInt( aviHeader.height );
			r.RawLInt( aviHeader.reserved[0] );
			r.RawLInt( aviHeader.reserved[1] );
			r.RawLInt( aviHeader.reserved[2] );
			r.RawLInt( aviHeader.reserved[3] );

			(* Skip Bytes if we have still available *)
			IF r.Pos() - startPos < headerLength THEN
				r.SkipBytes( headerLength - ( r.Pos() - startPos ) )
			END;

			RETURN aviHeader;
		END ReadMainAVIHeader;

		(* Read Header of this avi Stream *)
		PROCEDURE ReadAVIStreamHeader(): AVIStreamHeader;
		VAR
			header: AVIStreamHeader;
			headerLength: LONGINT;
			startPos: LONGINT;
			len: LONGINT;
			temp: INTEGER;
		BEGIN
			NEW(header);

			r.RawLInt(headerLength);
			startPos := r.Pos();

			r.Bytes( header.fccType,0,4, len );
			r.Bytes( header.fccHandler,0,4, len );
			r.RawLInt( header.flags );
			r.RawLInt( header.priority );
			r.RawLInt( header.initialFrames );
			r.RawLInt( header.scale );
			r.RawLInt( header.rate );
			r.RawLInt( header.start );
			r.RawLInt( header.length );
			r.RawLInt( header.suggestedBufferSize );
			r.RawLInt( header.quality );
			r.RawLInt( header.sampleSize );
			r.RawInt( temp ); header.left := temp;
			r.RawInt( temp ); header.top := temp;
			r.RawInt( temp ); header.right := temp;
			r.RawInt( temp ); header.bottom := temp;

			(* Skio Bytes if we have still available *)
			IF r.Pos() - startPos < headerLength THEN
				r.SkipBytes( headerLength - ( r.Pos() - startPos ) )
			END;

			RETURN header
		END ReadAVIStreamHeader;

		(* Read BitMapInfo Structure *)
		PROCEDURE ReadBitMapInfo(): BitMapInfo;
		VAR
			header: BitMapInfo;
			headerLength: LONGINT;
			startPos: LONGINT;
			temp: INTEGER;
		BEGIN
			NEW(header);

			r.RawLInt(headerLength);
			startPos := r.Pos();

			r.RawLInt( header.size );
			r.RawLInt( header.width );
			r.RawLInt( header.height );
			r.RawInt( temp ); header.planes := temp;
			r.RawInt( temp ); header.bitCount := temp;
			r.RawLInt( header.compression );
			r.RawLInt( header.sizeImage );
			r.RawLInt( header.xPelsPerMeter );
			r.RawLInt( header.yPelsPerMeter );
			r.RawLInt( header.clrUsed );
			r.RawLInt( header.clrImportant );

			IF r.Pos() - startPos < headerLength THEN
				r.SkipBytes( headerLength - ( r.Pos() - startPos ) )
			END;

			RETURN header
		END  ReadBitMapInfo;

		(* Read WaveFormatEX Structure *)
		PROCEDURE ReadWaveFormatEx(): WAVEFormatEx;
		VAR
			header: WAVEFormatEx;
			headerLength: LONGINT;
			startPos: LONGINT;
			temp: INTEGER;
		BEGIN
			NEW(header);

			r.RawLInt(headerLength);
			startPos := r.Pos();

			r.RawInt( temp ); header.formatTag := temp;
			r.RawInt( temp ); header.channels := temp;
			r.RawLInt( header.samplesPerSec );
			r.RawLInt( header.avgBytesPerSec );
			r.RawInt( temp ); header.blockAlign := temp;
			r.RawInt( temp ); header.bitsPerSample := temp;
			r.RawInt( temp ); header.cbSize := temp;

			IF r.Pos() - startPos < headerLength THEN
				r.SkipBytes( headerLength - ( r.Pos() - startPos ) )
			END;

			RETURN header
		END ReadWaveFormatEx;

		(* Write Avi Headers to KernelLog *)
		PROCEDURE DumpHeaders*;
		BEGIN
			KernelLog.String("AviDemux: Dump of Avi Headers: "); KernelLog.Ln();

			IF aviHeader # NIL THEN
				KernelLog.String( "aviHeader.microSecsPerFrame =  " ); KernelLog.Int( aviHeader.microSecsPerFrame, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.maxBytesPerSec =  " ); KernelLog.Int( aviHeader.maxBytesPerSec, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.reserved1 =  " ); KernelLog.Int( aviHeader.reserved1, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.flags =  " ); KernelLog.Int( aviHeader.flags, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.totalFrames =  " ); KernelLog.Int( aviHeader.totalFrames, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.initialFrames =  " ); KernelLog.Int( aviHeader.initialFrames, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.streams =  " ); KernelLog.Int( aviHeader.streams, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.suggestedBufferSize =  " ); KernelLog.Int( aviHeader.suggestedBufferSize, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.width =  " ); KernelLog.Int( aviHeader.width, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.height =  " ); KernelLog.Int( aviHeader.height, 0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.reserved[0] =  " ); KernelLog.Int( aviHeader.reserved[0],0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.reserved[1] =  " ); KernelLog.Int( aviHeader.reserved[1],0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.reserved[2] =  " ); KernelLog.Int( aviHeader.reserved[2],0 ); KernelLog.Ln();
				KernelLog.String( "aviHeader.reserved[3] =  " ); KernelLog.Int( aviHeader.reserved[3],0 ); KernelLog.Ln()
			ELSE
				KernelLog.String("AVIDemux.aviHeader = NIL"); KernelLog.Ln()
			END;

			IF audioStreamHeader # NIL THEN
				KernelLog.String( "audioStreamHeader.fccType =  " ); KernelLog.String( audioStreamHeader.fccType ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.fccHandler =  " ); KernelLog.String( audioStreamHeader.fccHandler );
					KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.flags =  " ); KernelLog.Int( audioStreamHeader.flags, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.priority =  " ); KernelLog.Int( audioStreamHeader.priority, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.initialFrames =  " ); KernelLog.Int( audioStreamHeader.initialFrames, 0 );
					KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.scale =  " ); KernelLog.Int( audioStreamHeader.scale, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.rate =  " ); KernelLog.Int( audioStreamHeader.rate, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.start =  " ); KernelLog.Int( audioStreamHeader.start, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.length =  " ); KernelLog.Int( audioStreamHeader.length, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.suggestedBufferSize =  " );
					KernelLog.Int( audioStreamHeader.suggestedBufferSize, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.quality =  " ); KernelLog.Int( audioStreamHeader.quality, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.sampleSize =  " ); KernelLog.Int( audioStreamHeader.sampleSize, 0 );
					KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.left =  " ); KernelLog.Int( audioStreamHeader.left, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.top =  " ); KernelLog.Int( audioStreamHeader.top, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.right =  " ); KernelLog.Int( audioStreamHeader.right, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.bottom =  " ); KernelLog.Int( audioStreamHeader.bottom, 0 ); KernelLog.Ln();
				KernelLog.String( "audioStreamHeader.streamIdentifier =  " );
				KernelLog.Buffer( audioStreamHeader.streamIdentifier, 0, 4 ); KernelLog.Ln()
			ELSE
				KernelLog.String("AVIDemux.audioStreamHeader = NIL"); KernelLog.Ln()
			END;

			IF videoStreamHeader # NIL THEN
				KernelLog.String( "videoStreamHeader.fccType =  " ); KernelLog.String( videoStreamHeader.fccType ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.fccHandler =  " ); KernelLog.String( videoStreamHeader.fccHandler );
					KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.flags =  " ); KernelLog.Int( videoStreamHeader.flags, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.priority =  " ); KernelLog.Int( videoStreamHeader.priority, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.initialFrames =  " ); KernelLog.Int( videoStreamHeader.initialFrames, 0 );
					KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.scale =  " ); KernelLog.Int( videoStreamHeader.scale, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.rate =  " ); KernelLog.Int( videoStreamHeader.rate, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.start =  " ); KernelLog.Int( videoStreamHeader.start, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.length =  " ); KernelLog.Int( videoStreamHeader.length, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.suggestedBufferSize =  " );
					KernelLog.Int( videoStreamHeader.suggestedBufferSize, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.quality =  " ); KernelLog.Int( videoStreamHeader.quality, 0 ); KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.sampleSize =  " ); KernelLog.Int( videoStreamHeader.sampleSize, 0 );
					KernelLog.Ln();
				KernelLog.String( "videoStreamHeader.streamIdentifier =  " );
				KernelLog.Buffer( videoStreamHeader.streamIdentifier, 0, 4 ); KernelLog.Ln()
			ELSE
				KernelLog.String("AVIDemux.videoStreamHeader = NIL"); KernelLog.Ln()
			END;

			IF videoStreamHeader.bitMapInfo # NIL THEN
				KernelLog.String( "bitMapInfo.size =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.size ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.width =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.width ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.height =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.height ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.planes =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.planes ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.bitCount =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.bitCount ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.compression =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.compression ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.sizeImage =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.sizeImage ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.xPelsPerMeter =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.xPelsPerMeter ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.yelsPerMeter =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.yPelsPerMeter ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.clrUsed =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.clrUsed ,0 ); KernelLog.Ln();
				KernelLog.String( "bitMapInfo.clrImportant =  " ); KernelLog.Int( videoStreamHeader.bitMapInfo.clrImportant ,0 ); KernelLog.Ln()
			ELSE
				KernelLog.String("AVIDemux.bitMapInfo = NIL"); KernelLog.Ln()
			END;

			IF (audioStreamHeader # NIL) & (audioStreamHeader.waveFormatEx # NIL) THEN
				KernelLog.String( "waveFormat.formatTag =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.formatTag ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.channel =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.channels ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.samplesPerSec =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.samplesPerSec ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.avgBytesPerSec =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.avgBytesPerSec ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.blockAlign =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.blockAlign ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.bitsPerSample =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.bitsPerSample ,0 ); KernelLog.Ln();
				KernelLog.String( "waveFormat.cbSize =  " ); KernelLog.Int( audioStreamHeader.waveFormatEx.cbSize ,0 ); KernelLog.Ln()
			ELSE
				KernelLog.String("AVIDemux.waveFormat = NIL"); KernelLog.Ln()
			END;

			KernelLog.Ln()
		END DumpHeaders;

		(* Write AVI video index to Kernel Log *)
		PROCEDURE DumpVideoIndex*;
		VAR i : LONGINT;
		BEGIN
			KernelLog.String("AviDemux: Dump of Video-Index: "); KernelLog.Ln();
			IF videoIndex = NIL THEN KernelLog.String("no index in AVI"); KernelLog.Ln; RETURN END;

			FOR i := 0 TO LEN(videoIndex)-1 DO
				KernelLog.String("Index: "); KernelLog.Int(i, 0);
				KernelLog.String(" ckid= "); KernelLog.Int(videoIndex[i].ckid, 0);
				KernelLog.String(" flags= "); KernelLog.Int(videoIndex[i].flags, 0);
				KernelLog.String(" offset= "); KernelLog.Int(videoIndex[i].offset, 0);
				KernelLog.String(" length= "); KernelLog.Int(videoIndex[i].length, 0);
				KernelLog.String(" tot= "); KernelLog.Int(videoIndex[i].tot, 0);
				IF (i > 0) THEN KernelLog.String(" deltaOFF= "); KernelLog.Int(videoIndex[i].offset - videoIndex[i-1].offset, 0); END;
				KernelLog.Ln;
			END

		END DumpVideoIndex;

		(* Write AVI audio index to Kernel Log *)
		PROCEDURE DumpAudioIndex*;
		VAR i : LONGINT;
		BEGIN
			KernelLog.String("AviDemux: Dump of Audio-Index: "); KernelLog.Ln();
			IF audioIndex = NIL THEN KernelLog.String("no index in AVI"); KernelLog.Ln; RETURN END;

			FOR i := 0 TO LEN(audioIndex)-1 DO
				KernelLog.String("Index: "); KernelLog.Int(i, 0);
				KernelLog.String(" ckid= "); KernelLog.Int(audioIndex[i].ckid, 0);
				KernelLog.String(" flags= "); KernelLog.Int(audioIndex[i].flags, 0);
				KernelLog.String(" offset= "); KernelLog.Int(audioIndex[i].offset, 0);
				KernelLog.String(" length= "); KernelLog.Int(audioIndex[i].length, 0);
				KernelLog.String(" tot= "); KernelLog.Int(audioIndex[i].tot, 0);
				IF (i > 0) THEN KernelLog.String(" deltaOFF= "); KernelLog.Int(audioIndex[i].offset - audioIndex[i-1].offset, 0); END;
				KernelLog.Ln;
			END

		END DumpAudioIndex;

		(* Return AudioStreamHeader *)
		PROCEDURE GetAudioStreamHeader*(): AVIStreamHeader;
		BEGIN
			RETURN audioStreamHeader
		END GetAudioStreamHeader;

		(* Return VideoStreamHeader *)
		PROCEDURE GetVideoStreamHeader*():AVIStreamHeader;
		BEGIN
			RETURN videoStreamHeader
		END GetVideoStreamHeader;

		(* Muss noch generischer werden *)
		PROCEDURE GetStream*(streamNr: LONGINT): AOC.DemuxStream;
		VAR
			(* reader : AVIReader; *)
			(* reader: AOC.FileInputStream; *)
			reader : Streams.Reader;
			i: LONGINT;

			streamInfo : AOC.AVStreamInfo;
			tag : ARRAY 4 OF CHAR;

		BEGIN

			reader := AOC.OpenInputStream(filename);				(* should be only one reader ideally... *)
			reader.SetPos(r.Pos());

			IF streamNr = 0 THEN
				NEW(videoStream, reader, videoStreamHeader);
				videoFramePos := 0;
				(* Add streamInfo to Stream *)
				streamInfo.streamType := AOC.STVideo;
				FOR i := 0 TO 3 DO streamInfo.contentType[i] := videoStreamHeader.fccHandler[i] END;
				IF videoIndex = NIL THEN streamInfo.seekability := {};
				ELSE streamInfo.seekability := {3,4}; END;
				streamInfo.length := videoFrames;
				streamInfo.frames := videoFrames;
				streamInfo.rate := videoStreamHeader.rate;

				videoStream.streamInfo := streamInfo;
				RETURN videoStream;
			ELSE
				NEW(audioStream, reader, audioStreamHeader);
				audioFramePos := 0;
				(* Add streamInfo to Stream *)
				streamInfo.streamType := AOC.STAudio;
				IF (audioStreamHeader.waveFormatEx # NIL) THEN
					CASE audioStreamHeader.waveFormatEx.formatTag OF
						1 :	COPY("PCM", tag);
					|	85: 	COPY("MP3", tag);
					ELSE
					END;
					FOR i := 0 TO 3 DO streamInfo.contentType[i] := tag[i]; END;
				END;
				IF audioIndex = NIL THEN streamInfo.seekability := {};
				ELSE streamInfo.seekability := {1,2}; END;
				streamInfo.length := audioStreamHeader.length*GetSampleSize();
				streamInfo.frames := audioChunks;
				streamInfo.rate := audioStreamHeader.rate;

				audioStream.streamInfo := streamInfo;
				RETURN audioStream;
			END;
		END GetStream;

		PROCEDURE GetMilliSecondsPerFrame*(): LONGINT;
		BEGIN
			RETURN aviHeader.microSecsPerFrame DIV 1000;
		END GetMilliSecondsPerFrame;

		PROCEDURE GetNofChannels*(): LONGINT;
		BEGIN
			RETURN audioStreamHeader.waveFormatEx.channels;
		END GetNofChannels;

		PROCEDURE GetSamplesPerSecond*(): LONGINT;
		BEGIN
			RETURN audioStreamHeader.waveFormatEx.samplesPerSec;
		END GetSamplesPerSecond;

		PROCEDURE GetBitsPerSample*(): LONGINT;
		BEGIN
			RETURN audioStreamHeader.waveFormatEx.bitsPerSample;
		END GetBitsPerSample;

		PROCEDURE GetVideoIndex*(): IndexArrayPointer;
		BEGIN
			RETURN videoIndex;
		END GetVideoIndex;

		PROCEDURE GetAudioIndex*(): IndexArrayPointer;
		BEGIN
			RETURN audioIndex;
		END GetAudioIndex;

		PROCEDURE GetAudioChunks*(): LONGINT;
		BEGIN
			RETURN audioChunks;
		END GetAudioChunks;

		PROCEDURE GetAudioBytes*(): LONGINT;
		BEGIN
			RETURN audioBytes;
		END GetAudioBytes;

		PROCEDURE GetVideoFrames*(): LONGINT;
		BEGIN
			RETURN videoFrames;
		END GetVideoFrames;

		PROCEDURE GetNumberOfStreams*(): LONGINT;
		BEGIN
			RETURN aviHeader.streams;
		END GetNumberOfStreams;

		(* Could be optimized, as we assume videostream beeing at index 0 and that there is only one *)
		PROCEDURE GetStreamInfo*(streamNr: LONGINT): AOC.AVStreamInfo;
		VAR streamInfo : AOC.AVStreamInfo;
			i: INTEGER;
			tag : ARRAY 4 OF CHAR;
		BEGIN

 			IF streamNr = 0 THEN							(* Video *)
				streamInfo.streamType := AOC.STVideo;
				FOR i := 0 TO 3 DO
					streamInfo.contentType[i] := videoStreamHeader.fccHandler[i];
				END;

				IF videoIndex = NIL THEN
					streamInfo.seekability := {};
				ELSE
					streamInfo.seekability := {3,4};
				END;
				streamInfo.length := videoFrames;
				streamInfo.frames := videoFrames;
				streamInfo.rate := videoStreamHeader.rate;
			ELSE											(* Audio *)
				streamInfo.streamType := AOC.STAudio;

				IF (audioStreamHeader.waveFormatEx # NIL) THEN
					CASE audioStreamHeader.waveFormatEx.formatTag OF
						1 :	COPY("PCM", tag);
					|	85: 	COPY("MP3", tag);
					ELSE
					END;
					FOR i := 0 TO 3 DO
						streamInfo.contentType[i] := tag[i];
					END;
				END;

				IF audioIndex = NIL THEN
					streamInfo.seekability := {};
				ELSE
					streamInfo.seekability := {1,2};
				END;
				streamInfo.length := audioStreamHeader.length*GetSampleSize();
				streamInfo.frames := audioChunks;
				streamInfo.rate := audioStreamHeader.rate;
			END;

			RETURN streamInfo
		END GetStreamInfo;

		PROCEDURE GetStreamType*(streamNr : LONGINT): LONGINT;
		VAR type : LONGINT;
		BEGIN
			IF streamNr = 0 THEN type :=  AOC.STVideo;
			ELSIF streamNr = 1 THEN type := AOC.STAudio;
			ELSE type := AOC.STUnknown;
			END;
			RETURN type
		END GetStreamType;

		(* Returns Information, which can be read out from file and which is useful/needed *)
		PROCEDURE GetInfo*(VAR vl, vf, vr, mspf, al, af, ar : LONGINT);
		BEGIN
			vl := videoFrames;
			vf := videoFrames;
			vr := videoStreamHeader.rate;
			mspf := aviHeader.microSecsPerFrame;
			IF audioStreamHeader # NIL THEN
				al := audioStreamHeader.length*GetSampleSize();
				af := audioChunks;
				ar := audioStreamHeader.rate;
			END;

		END GetInfo;

		PROCEDURE GetData*(streamNr: LONGINT;  VAR buf:  ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR
			rres: BOOLEAN;
		BEGIN
			IF streamNr = 0 THEN
				IF videoIndex # NIL THEN
					IF videoFramePos < videoFrames THEN
						len := videoIndex[videoFramePos].length;
						IF (len > (size-4)) THEN
							len := len+4;
							res := AOC.ResFailed;
							RETURN;
						END;
						rres := videoStream.Resynch(buf);
						INC(videoFramePos);
						IF rres THEN
							videoStream.res := Streams.Ok;
							res := AOC.ResOk;
						ELSE
							res := AOC.ResFailed;
							videoStream.res := Streams.EOF;
						END
					ELSE
						res := AOC.ResFailed;
						videoStream.res := Streams.EOF;
						len := 0;
					END;
				END;
			ELSE
				IF audioIndex # NIL THEN
					IF audioFramePos < audioChunks THEN
						len := audioIndex[audioFramePos].length;
						IF (LEN(buf) < len+4) THEN
							len := len+4;
							res := AOC.ResFailed;
							audioStream.res := Streams.EOF;
							RETURN;
						END;
						len := audioIndex[audioFramePos].length;
						rres := audioStream.Resynch(buf);
						INC(audioFramePos);
						IF rres THEN
							audioStream.res := Streams.Ok;
							res := AOC.ResOk;
						ELSE
							(* res := AOC.ResFailed; *)
							audioStream.res := Streams.EOF;
						END
					ELSE
						res := AOC.ResFailed;
						audioStream.res := Streams.EOF;
						len := 0;
					END;
				END;
			END;
		END GetData;

		PROCEDURE SetStreamPos*(streamNr: LONGINT; seekType: LONGINT; pos: LONGINT; VAR itemSize: LONGINT; VAR res: LONGINT);
		(* PROCEDURE SetStreamPos*(streamNr, pos : LONGINT; VAR res: LONGINT); *)
		VAR
			n0, n1, n, spos: LONGINT;
			(* seekType, itemSize : LONGINT; *)
		BEGIN
			IF Debug THEN KernelLog.String("AVIDemux.SetStreamPos: "); KernelLog.Int(pos, 0); KernelLog.Ln; END;
			IF streamNr = 0 THEN
				IF videoIndex # NIL THEN
					IF seekType = AOC.SeekKeyFrame THEN
						IF pos > itemSize THEN
							IF pos >= videoStreamHeader.length-1 THEN
								pos := videoStreamHeader.length-1;
							ELSE
								WHILE ((pos < videoFrames-1) & (videoIndex[pos].flags # 16)) DO
									INC(pos);
								END;
							END;
						ELSE
							IF(pos > 0) THEN
								DEC(pos);
							END;
							WHILE ((videoIndex[pos].flags # 16) & (pos > 0)) DO
								DEC(pos);
							END;
						END;
					END;
					IF ((seekType = AOC.SeekFrame) OR (seekType = AOC.SeekKeyFrame)) THEN
						IF pos < LEN(videoIndex) THEN
							videoStream.SetAVIPos(videoIndex[pos].offset, itemSize);
							itemSize := pos;
							videoFramePos := pos;
						END
					ELSE
						videoStream.SetAVIPos(pos, itemSize);
					END;
				END;
			ELSE
				IF audioIndex # NIL THEN
					IF seekType = AOC.SeekSample THEN
						IF pos < 0 THEN
							pos := 0;
						END;
						IF pos = 0 THEN
							n0 := 0;
						ELSE
							n0 := 0;
							n1 := audioChunks;

							WHILE (n0 < n1 - 1) DO
								n := (n0 + n1) DIV 2;
								IF (audioIndex[n].tot > pos) THEN
									n1 := n;
								ELSE
									n0 := n;
								END;
							END;
						END;
						audioStream.SetAVIPos(audioIndex[n0].offset, itemSize);
						audioFramePos := n0;
					ELSIF seekType = AOC.SeekByte THEN
						(* spos := ENTIER(pos * 8 *  audioStreamHeader.waveFormatEx.samplesPerSec/audioStreamHeader.rate / 1000); *)
						spos := ENTIER(pos / audioStreamHeader.rate * audioStreamHeader.waveFormatEx.samplesPerSec);

						IF Debug THEN KernelLog.String("spos= "); KernelLog.Int(spos, 0); KernelLog.Ln; END;
						IF spos < 0 THEN spos := 0 END;
						IF spos = 0 THEN n0 := 0
						ELSE
							n0 := 0;
							n1 := audioChunks;

							WHILE (n0 < n1 - 1) DO
								n := (n0 + n1) DIV 2;
								IF (audioIndex[n].tot > spos) THEN
									n1 := n;
								ELSE
									n0 := n;
								END;
							END;
						END;

						audioStream.SetAVIPos(audioIndex[n0].offset, itemSize);
						audioFramePos := n0;
						IF Debug THEN
							KernelLog.String("audioIndex[n].tot= "); KernelLog.Int(audioIndex[n].tot, 0);
							KernelLog.String("audioIndex[n0].offset= "); KernelLog.Int(audioIndex[n0].offset, 0);
							KernelLog.String("audioFramePos= "); KernelLog.Int(audioFramePos, 0);
							KernelLog.String("itemSize= "); KernelLog.Int(itemSize, 0);  KernelLog.Ln;
						END
					ELSE
						audioStream.SetAVIPos(pos, itemSize);
					END;
				END;
			END;
		END SetStreamPos;

		PROCEDURE GetVideoWidth*(): LONGINT;
		BEGIN
			RETURN videoStreamHeader.bitMapInfo.width;
		END GetVideoWidth;

		PROCEDURE GetVideoHeight*(): LONGINT;
		BEGIN
			RETURN videoStreamHeader.bitMapInfo.height;
		END GetVideoHeight;

		PROCEDURE GetNextFrameSize*(streamNr: LONGINT): LONGINT;
		BEGIN
			IF streamNr = 0 THEN
				IF videoFramePos < videoFrames THEN
					RETURN videoIndex[videoFramePos].length;
				ELSE
					RETURN AOC.ResFailed;
				END;
			ELSE
				IF audioFramePos < audioChunks THEN
					RETURN audioIndex[audioFramePos].length;
				ELSE
					RETURN AOC.ResFailed;
				END;
			END;
		END GetNextFrameSize;

		PROCEDURE GetSampleSize*(): LONGINT;
		VAR
			s: LONGINT;
		BEGIN
			s := ((audioStreamHeader.waveFormatEx.bitsPerSample+7) DIV 8)*audioStreamHeader.waveFormatEx.channels;
			IF s = 0 THEN
				s := 1;
			END;
			RETURN s;
		END GetSampleSize;

	END AVIDemux;

	(* -- Helper Procedures -- *)

(* Align stream to next Byte *)
PROCEDURE Align*(VAR  index: LONGINT);
BEGIN
	IF ( index MOD 8 ) # 0 THEN
		index :=  index - ( index MOD 8 ) + 8
	END;
END Align;

(* True if actual position is on byte boundary *)
PROCEDURE IsAligned*(index: LONGINT): BOOLEAN;
BEGIN
	IF ( index MOD 8 ) = 0 THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END IsAligned;

(* Read next n Bits (max 32), without advancing in stream. Max 32 Bits are allowed *)
(* Very slow but portable *)
PROCEDURE ShowBitsSlow*( n: LONGINT; VAR buf: ARRAY OF CHAR; VAR index: LONGINT): LONGINT;
VAR
	ret: LONGINT;
	count: LONGINT;
BEGIN
	ret := 0;
	count := 0;

	WHILE count < n DO
		ret := ret * 2;
		IF ( 7 - ( index MOD 8 ) ) IN SYSTEM.VAL( SET, buf[index DIV 8] ) THEN
			INC(ret)
		END;
		INC( index );
		INC( count )
	END;

	index := index - count;

	RETURN ret
END ShowBitsSlow;

(* Read next n Bits (max 32), without advancing in stream. Max 32 Bits are allowed *)
(* Fast, but im not sure if it's portable *)
PROCEDURE ShowBits*( n: LONGINT; VAR buf: ARRAY OF CHAR; VAR index: LONGINT): LONGINT;
VAR
	nbit: LONGINT;
	posInLONGINT: LONGINT;
	bufa, bufb: LONGINT;
	temp: LONGINT;
	bufAdr: LONGINT;
BEGIN
	bufAdr := ADDRESSOF( buf[0] );
	posInLONGINT := index MOD 32;
	nbit := ( posInLONGINT+ n ) - 32;

	IF nbit > 0 THEN
		(* We have to read two 32 bit values *)
		temp := LSH( index - posInLONGINT , -3 ) + bufAdr;
		bufa := Machine.ChangeByteOrder( SYSTEM.GET32( temp ) );
		bufb := Machine.ChangeByteOrder( SYSTEM.GET32( temp + 4 ) );

		 temp := LSH( LSH( bufa, posInLONGINT ),  nbit - posInLONGINT );
		RETURN SYSTEM.VAL( LONGINT, SYSTEM.VAL( SET, LSH( bufb, nbit - 32 ) ) + SYSTEM.VAL( SET, temp ) )
	ELSE
		(* Reading one 32 value is sufficient *)
		bufa := Machine.ChangeByteOrder( SYSTEM.GET32( LSH( index - posInLONGINT, -3 ) + bufAdr ) );

		RETURN LSH( LSH( bufa, posInLONGINT ),  n - 32 )
	END;
END ShowBits;

(* Show n bits, byte aligned without advancing in bit stream *)
PROCEDURE ShowBitsByteAligned*(n: LONGINT; VAR buf: ARRAY OF CHAR; VAR index: LONGINT): LONGINT;
VAR
	count: LONGINT;
	ret: LONGINT;
BEGIN
	count := 8 - ( index MOD 8 );

	IF count = 8 THEN
		IF ShowBits(8, buf, index) = 7FH THEN (* Spezial case: see iso spec *)
			count := 8
		ELSE
			count := 0
		END;
	END;

	index := index + count;
	ret := ShowBits(n, buf, index);
	index := index - count;
	RETURN ret
END ShowBitsByteAligned;

(* Read next n Bits and advance in Bit Stream. Max 32 Bits are allowed *)
PROCEDURE GetBits*( n: LONGINT; VAR buf: ARRAY OF CHAR; VAR index: LONGINT): LONGINT;
VAR
	ret: LONGINT;
BEGIN
	ret := ShowBits(n, buf, index);
	SkipBits(n, index);
	RETURN ret
END GetBits;

(* Skip Next n Bits *)
PROCEDURE SkipBits*(n: LONGINT; VAR index: LONGINT );
BEGIN
	index := index + n
END SkipBits;

PROCEDURE Factory*() : AOC.AVDemultiplexer;
VAR p: AVIDemux;
BEGIN
	NEW(p);
	RETURN p
END Factory;

END AVI.