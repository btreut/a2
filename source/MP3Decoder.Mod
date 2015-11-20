(* MP3 Decoder written by Christof Dornbierer , adapted to Codecs by Urs Müller, cleaned by PL *)
MODULE MP3Decoder;

IMPORT SYSTEM, Files, Streams, KernelLog,  Math, SoundDevices, Codecs;

CONST 	MAXBUF = 4096;
		MPEGLAYER1 = 1;
		MPEGLAYER2 = 2;
		MPEGLAYER3 = 3;

		(* Constants representing Shortint Values of Headerfields *)
		MPEG1LAYER3 = 65530;
		MPEG1LAYER3CRC = 65531;
		MPEG1LAYER2 = 65532;
		MPEG1LAYER2CRC = 65533;
		MPEG1LAYER1 = 65534;
		MPEG1LAYER1CRC = 65535;

TYPE
	Channel =  RECORD
		scfsi: ARRAY 4 OF BOOLEAN;
		gr: ARRAY 2 OF RECORD	(* each frame consists of 2 granules *)
		part23length, bigvalues, globalgain, scalefaccompress,
		blocktype, region0count, region1count : INTEGER;
		tableselect, subblockgain : ARRAY 3 OF INTEGER;
		windowswitchingflag, mixedblockflag,
		preflag, scalefacscale, count1tableselect : BOOLEAN;
		END;
	END;

	Scalefactors = RECORD
		l: ARRAY 23 OF INTEGER;
		s: ARRAY 3, 13 OF INTEGER;
	END;

	Frame = OBJECT
	VAR
		stereo: INTEGER;
		jsbound : INTEGER;

		single: INTEGER;
		lsd: INTEGER;
		mpeg25: INTEGER;
		headerchange: INTEGER;
		layer: INTEGER;
		errorprotection: INTEGER;
		bitrate: INTEGER;
		samplerate: INTEGER;
		padding: BOOLEAN;
		extension: BOOLEAN;
		channelmode: INTEGER;
		modeextension: INTEGER;
		copyright: BOOLEAN;
		original: BOOLEAN;
		emphasis: INTEGER;
		nofSlots: INTEGER;	(* Framegroesse *)

		crc: BOOLEAN;
		maindatabegin : INTEGER;

		hsynth: BOOLEAN;
		store: ARRAY 2, 32, 18 OF REAL;

		ssynth: BOOLEAN;
		ch: ARRAY 2 OF Channel;

		header: ARRAY 36 OF CHAR;
		curByte : INTEGER;
		curBit: INTEGER;
		tempVal: LONGINT;

		scalefactors : ARRAY 2 OF Scalefactors;
	END Frame;

	HuffDecoded = ARRAY 32+1,18 OF LONGINT;
	Granule = ARRAY 32,18 OF REAL;
	Stereo = ARRAY 2 OF Granule;

	PcmStereo = ARRAY 2304 OF CHAR;

	Raw3 = ARRAY 3 OF REAL;
	Raw4 = ARRAY 4 OF REAL;
	Raw5 = ARRAY 5 OF REAL;
	Raw9 = ARRAY 9 OF REAL;
	Raw18 = ARRAY 18 OF REAL;
	Raw32 = ARRAY 32 OF REAL;
	Raw36 = ARRAY 36 OF REAL;

	MpstrPtr* = POINTER TO Mpstr;
	Mpstr* = RECORD
		head: SoundDevices.Buffer;
		tail: SoundDevices.Buffer;
		bsize: INTEGER;
		framesize*: INTEGER;
		fsizeold: INTEGER;
		fr: Frame;
		bsspace: ARRAY 2,2304 OF CHAR;
		hybridblock: ARRAY 2,2,576 OF REAL;
		hybridblc: ARRAY 2 OF INTEGER;
		header: LONGINT;
		bsnum: INTEGER;
		synthbuffs: ARRAY 2,2, 272OF REAL;
		synthbo: INTEGER;
	END;

VAR
	(* Tables, initialized once the Module loads*)
	JSBTABLE : ARRAY 4 OF INTEGER;
	BITRATE : ARRAY 15 OF INTEGER;
	FREQUENCY : ARRAY 4 OF REAL;
	SFBTABLE: RECORD
				l: ARRAY 5 OF INTEGER;
				s: ARRAY 3 OF INTEGER;
			END;
	SLEN: ARRAY 2, 16 OF INTEGER;
	SFBIDX: ARRAY 3 OF RECORD
				l: ARRAY 23 OF INTEGER;
				s: ARRAY 14 OF INTEGER;
			END;
	PRETAB: ARRAY 22 OF INTEGER;

	H: ARRAY 34 OF RECORD
				len, xlen, ylen: INTEGER;
				linbits: INTEGER;
				v: POINTER TO ARRAY OF POINTER TO ARRAY OF INTEGER;
			END;

	ISPOW: ARRAY 8207 OF REAL;
	GGPOW : ARRAY 256 OF REAL;
	SGPOW : ARRAY 8 OF REAL;
	SFSPOW : ARRAY 2,16 OF REAL;
	SFLPOW: ARRAY 2,16,2,22 OF REAL;

	STEREOTAN : ARRAY 8 OF REAL;

	CI, CA, CS : ARRAY 8 OF REAL;

	IMDCTWIN : ARRAY 4, 36 OF REAL;
	IMDCTCOS : ARRAY 5 OF REAL;
	IMDCTSIN : ARRAY 4 OF REAL;
	IMDCTSQRT : REAL;

	POSTTWIDDLE6: ARRAY 3 OF REAL;
	POSTTWIDDLE9: ARRAY 4 OF REAL;
	POSTTWIDDLE12: ARRAY 6 OF REAL;
	POSTTWIDDLE18: ARRAY 9 OF REAL;
	POSTTWIDDLE36: ARRAY 18 OF REAL;

	GS: ARRAY 512 OF REAL;

	DCTCOS: ARRAY 2,2 OF REAL;
	DCTTWIDDLE: ARRAY 16, 33 OF REAL;

TYPE
	(** The Player object can be used to play a MP3 file or to decode it into a PCM file *)
	(** The input file is specified by the variable inFile and the output file by the variable outFile *)
	(** The Procedure Play of the object plays a file and DecodeToFile decodes a MP3 file *)
	(** Only works correctly for CBR files as the bitrate is used for some calcualtions *)
	 MP3Decoder* = OBJECT(Codecs.AudioDecoder)
	VAR
		encFrame: Frame;
		fHeader: ARRAY 5 OF CHAR;			(* first Header read from file *)
		cHeader: ARRAY 5 OF CHAR;			(* currently read Header *)

		(* Variables used for buffer control*)
		data : ARRAY MAXBUF OF CHAR;
		curBit, curByte, tempVal, offset : INTEGER;
		totBits : LONGINT;
		mainDataEnd, frameStart: INTEGER;

		vVec : ARRAY 2, 1024 OF REAL;
		vectIdx0, vectIdx1 : LONGINT;

		(* Number of Frames decoded *)
		frameNum: LONGINT;

		(* First Time status: for initialising some values *)
		first: BOOLEAN;
		paranoia : BOOLEAN;				(* when in paranoia mode header must match exactly *)

		s: Streams.Reader;

		channels: LONGINT;
		bitsPerSample: LONGINT;
		samplesPerSec: LONGINT;
		bitRate: LONGINT;

		totSamples : LONGINT;

		hasMoreBytes: BOOLEAN;

		(* Variables for internal buffercontrol *)
		out : ARRAY 2 OF PcmStereo;		(* The actual buffer *)
		gr: INTEGER;						(* needed for changing buffer *)
		outBufferPos: LONGINT;				(* Current Position in buffer *)


		(*                                                                  *)
		(*            Layer 3 Decoding Functions          *)
		(*                                                                  *)


		(* Searches for next frame header, reads header info and caches frame main data,	*)
		(* if underlying stream is FileINputStream										*)
		(* @params: none																*)
		(* @returns: nothing															*)
		PROCEDURE Next*;
		VAR c:CHAR;
			i: LONGINT;
			found: BOOLEAN;
			n: LONGINT;
		BEGIN
			(* One method: read single Bytes and decide on them. Not sure whats better
			REPEAT
				s.Char(c);
				(* In this part we could find out the layer, depending on 0FB or 0FA, etc... *)
				IF (c = 0FFX) & (s.res = Streams.Ok) THEN
					s.Char(c);
					found := ((c = 0FBX) OR (c = 0FAX));
					encFrame.layer := MPEGLAYER3;

					IF (c = 0FDX) OR (c = 0FCX) THEN;
						encFrame.layer := MPEGLAYER2;
					END;

					IF ((c = 0FFX) OR (c = 0FEX)) THEN
						encFrame.layer := MPEGLAYER1;
					END;
					encFrame.crc := ((c = 0FAX) OR (c = 0FCX) OR (c = 0FEX));
				END;
			UNTIL found OR (s.res # Streams.Ok);
*)
			(* The other Variant: read Shortintegers *)
			IF (s.res = Streams.EOF) THEN KernelLog.String("Peng!"); RETURN END;

			REPEAT
				i := s.Net16();
				IF ((i = MPEG1LAYER3) OR (i = MPEG1LAYER3CRC)) & (s.res = Streams.Ok) THEN
					encFrame.layer := MPEGLAYER3;
					encFrame.crc := (i = MPEG1LAYER3);

					s.Char(c);
					encFrame.header[0] := c;
					s.Char(c);
					encFrame.header[1] := c;

					IF paranoia THEN		(* check for exactly the same header - doesnt work for VBR *)
						(* check if first header matches current header *)
						IF (encFrame.header[1] = fHeader[3]) THEN
							paranoia := FALSE; found := TRUE
						(* check if current header is same than the last one read *)
						ELSIF (encFrame.header[0] = cHeader[2]) & (encFrame.header[1] = cHeader[3]) THEN
							paranoia := FALSE; found := TRUE
						ELSE
							cHeader[0] := 0FFX;
							IF encFrame.crc THEN cHeader[1] := 0FBX
							ELSE cHeader[1] := 0FAX END;
							cHeader[2] := encFrame.header[0];
							cHeader[3] := encFrame.header[1];
							cHeader[4] := 0X;
							s.SkipBytes(ENTIER(144 * encFrame.bitrate / encFrame.samplerate));
						END
					ELSE found := TRUE END

				ELSE
					IF ((i = MPEG1LAYER2) OR (i = MPEG1LAYER3CRC)) & (s.res = Streams.Ok) THEN
						encFrame.layer := MPEGLAYER2;
						encFrame.crc := (i = MPEG1LAYER2);
					ELSE
						IF ((i = MPEG1LAYER1) OR (i = MPEG1LAYER1CRC)) & (s.res = Streams.Ok) THEN
							encFrame.layer := MPEGLAYER1;
							encFrame.crc := (i = MPEG1LAYER1);
						END;
					END;

					s.Char(c);
					encFrame.header[0] := c;
					s.Char(c);
					encFrame.header[1] := c;
				END;
			UNTIL found OR (s.res # Streams.Ok);

			IF found & (s.res = Streams.Ok) THEN
				IF encFrame.crc THEN
					s.Char(c);
					s.Char(c);
				END;
			END;
			encFrame.curByte := -1;
			encFrame.curBit := 8;
			IF found & (s.res = Streams.Ok) THEN
				GetHeaderInfo();
				(* save those header infos before overwritting.. *)
				encFrame.header[32] := encFrame.header[0];
				encFrame.header[33] := encFrame.header[1];

				IF encFrame.stereo = 1 THEN
					FOR n:= 0 TO 16 DO
						s.Char(c);
						encFrame.header[n] := c;
					END;
				ELSE
					FOR n:= 0 TO 31 DO
						s.Char(c);
						encFrame.header[n] := c;
					END;
				END;

				encFrame.curByte := -1;
				encFrame.curBit := 8;
				GetSideInfo();

				FOR n :=  0 TO encFrame.nofSlots-1 DO
					s.Char(c);
					data[offset MOD MAXBUF] := c;
					INC(offset);
				END
			END;
		END Next;

		(* Get general mpeg header info of a frame *)
		PROCEDURE GetHeaderInfo;
		VAR
			i : LONGINT;

		BEGIN
			encFrame.bitrate := GetBits(4);
			IF encFrame.bitrate >= 15 THEN encFrame.bitrate := 7 END;

			encFrame.samplerate := GetBits(2);

			encFrame.padding := GetBit();
			encFrame.extension := GetBit();

			encFrame.channelmode := GetBits(2);

			encFrame.modeextension := GetBits(2);

			IF encFrame.channelmode = 1 THEN
				encFrame.jsbound := JSBTABLE[i];
			ELSE
				encFrame.jsbound :=  32;
			END;

			encFrame.copyright := GetBit();
			encFrame.original := GetBit();

			encFrame.emphasis := GetBits(2);

			(* Calculate no of mainslots *)
			encFrame.nofSlots := SHORT(ENTIER((144 * LONG(BITRATE[encFrame.bitrate]))  / FREQUENCY[encFrame.samplerate])) - 4;

			IF encFrame.padding THEN INC(encFrame.nofSlots); END;

			IF encFrame.channelmode = 3 THEN
				encFrame.stereo := 1;
				encFrame.nofSlots := encFrame.nofSlots - 17;
			ELSE
				encFrame.stereo := 2;
				encFrame.nofSlots := encFrame.nofSlots - 32;
			END;

			IF encFrame.crc THEN encFrame.nofSlots := encFrame.nofSlots - 2; END;

		END GetHeaderInfo;


		(* Get the layer 3 specific side infos *)
		PROCEDURE GetSideInfo;
		VAR i,j,k: INTEGER;
				dummy: BOOLEAN;
		BEGIN
			encFrame.maindatabegin := GetBits(9);

			IF encFrame.stereo = 1 THEN
				j:= 4;
			ELSE
				j := 2;
			END;

			FOR i:= 0 TO j DO
				dummy := GetBit();
			END;

			FOR i:= 0 TO encFrame.stereo-1 DO
				FOR j:= 0 TO 3 DO
					encFrame.ch[i].scfsi[j] := GetBit();
				END;
			END;

			FOR j:= 0 TO 1 DO
				FOR i:= 0 TO encFrame.stereo-1 DO
					encFrame.ch[i].gr[j].part23length := GetBits(12);
					encFrame.ch[i].gr[j].bigvalues := GetBits(9);
					encFrame.ch[i].gr[j].globalgain := GetBits(8);
					encFrame.ch[i].gr[j].scalefaccompress := GetBits(4);
					encFrame.ch[i].gr[j].windowswitchingflag := GetBit();
					IF encFrame.ch[i].gr[j].windowswitchingflag THEN
						encFrame.ch[i].gr[j].blocktype := GetBits(2);
						encFrame.ch[i].gr[j].mixedblockflag := GetBit();
						FOR k := 0 TO 1 DO
								encFrame.ch[i].gr[j].tableselect[k] := GetBits(5);
						END;
						FOR k := 0 TO 2 DO
							encFrame.ch[i].gr[j].subblockgain[k] := GetBits(3);
						END;

						IF (encFrame.ch[i].gr[j].blocktype = 2) &  (~encFrame.ch[i].gr[j].mixedblockflag) THEN
							encFrame.ch[i].gr[j].region0count := 8;
						ELSE
							encFrame.ch[i].gr[j].region0count := 7;
						END;
						encFrame.ch[i].gr[j].region1count :=  20 - encFrame.ch[i].gr[j].region0count;
					ELSE
						FOR k := 0 TO 2 DO encFrame.ch[i].gr[j].tableselect[k] := GetBits(5); END;
						encFrame.ch[i].gr[j].region0count := GetBits(4);
						encFrame.ch[i].gr[j].region1count := GetBits(3);
						encFrame.ch[i].gr[j].blocktype := 0;
					END;
					encFrame.ch[i].gr[j].preflag := GetBit();
					encFrame.ch[i].gr[j].scalefacscale := GetBit();
					encFrame.ch[i].gr[j].count1tableselect := GetBit();
				END;
			END;
		END GetSideInfo;


		(* Get the scalefactors *)
		PROCEDURE GetScaleFactors(ch, gr: INTEGER);
		VAR i, j, k: LONGINT;
		BEGIN
			IF (encFrame.ch[ch].gr[gr].windowswitchingflag) & (encFrame.ch[ch].gr[gr].blocktype = 2) THEN
				IF encFrame.ch[ch].gr[gr].mixedblockflag THEN

					FOR i:= 0 TO 7 DO
						encFrame.scalefactors[ch].l[i] := GetDataBits(SLEN[0][encFrame.ch[ch].gr[gr].scalefaccompress]);
					END;

					FOR i:= 3 TO 5 DO
						FOR j:=0 TO 2 DO
							encFrame.scalefactors[ch].s[j][i] := GetDataBits(SLEN[0][encFrame.ch[ch].gr[gr].scalefaccompress]);
						END;
					END;

					FOR i:= 6 TO 11 DO
						FOR j:=0 TO 2 DO
							encFrame.scalefactors[ch].s[j][i] := GetDataBits(SLEN[1][encFrame.ch[ch].gr[gr].scalefaccompress]);
						END;
					END;

					FOR j:=0 TO 2 DO
						encFrame.scalefactors[ch].s[j][12] := 0;
					END;
				ELSE

					FOR k:= 0 TO 1 DO
						FOR i:=SFBTABLE.s[k] TO SFBTABLE.s[k+1]-1 DO
							FOR j:=0 TO 2 DO
								encFrame.scalefactors[ch].s[j][i] := GetDataBits(SLEN[k][encFrame.ch[ch].gr[gr].scalefaccompress]);
							END;
						END;
					END;

					FOR j:=0 TO 2 DO
						encFrame.scalefactors[ch].s[j][12] := 0;
					END;
				END;
			ELSE
				FOR k:=0 TO 3 DO
					IF ~encFrame.ch[ch].scfsi[k]  OR (gr = 0) THEN
						FOR i:=SFBTABLE.l[k] TO SFBTABLE.l[k+1]-1 DO

							IF k < 2 THEN
								encFrame.scalefactors[ch].l[i] := GetDataBits(SLEN[0][encFrame.ch[ch].gr[gr].scalefaccompress]);
							ELSE
								encFrame.scalefactors[ch].l[i] := GetDataBits(SLEN[1][encFrame.ch[ch].gr[gr].scalefaccompress]);
							END;
						END;
					END;
				END;
			encFrame.scalefactors[ch].l[22] := 0;
			END;
		END GetScaleFactors;

		(* General Huffman decoding using table lookups *)
		PROCEDURE HuffDec(t: INTEGER; VAR x, y, v, w: INTEGER);
		VAR point, i : INTEGER;
				error : BOOLEAN;
		BEGIN
			point := 0;
			error := TRUE;
			IF H[t].len = 0 THEN
				x := 0; y:= 0;
			ELSE
				i:= 0;

				REPEAT
					IF H[t].v[point][0] =  0 THEN
						x := H[t].v[point][1] DIV 16;
						y := H[t].v[point][1] MOD 16;
						error := FALSE;
					ELSE
						IF GetDataBit() THEN
							WHILE H[t].v[point][1] >= 250 DO point := point + H[t].v[point][1]; END;
							point := point + H[t].v[point][1];
						ELSE
							WHILE H[t].v[point][0] >= 250 DO point := point + H[t].v[point][0]; END;
							point := point + H[t].v[point][0];
						END;
					END;
					INC(i);
				UNTIL ((i = 32) OR (point >= H[t].len) OR ~error);

				IF error THEN
					KernelLog.String("Error in Huffman Codes"); KernelLog.Ln();
					x := (H[t].xlen-1) *2;
					y := (H[t].ylen-1) *2;
				END;

				IF (t >= 32) THEN
					v := (y DIV 8) MOD 2;
					w := (y DIV 4) MOD 2;
					x := (y DIV 2) MOD 2;
					y := y MOD 2;

					IF v = 1 THEN IF GetDataBit() THEN v := - 1; END; END;
					IF w = 1 THEN IF GetDataBit() THEN w := - 1; END; END;
					IF x = 1 THEN IF GetDataBit() THEN x := - 1; END; END;
					IF y = 1 THEN IF GetDataBit() THEN y := - 1; END; END;

				ELSE
					IF H[t].linbits  > 0 THEN
						IF (H[t].xlen-1) = x THEN
							x := x + GetDataBits(H[t].linbits);
						END;
					END;
					IF x > 0 THEN
						IF GetDataBit() THEN
							x:= -x;
						END;
					END;

					IF H[t].linbits  > 0 THEN
						IF (H[t].ylen-1) = y THEN
							y := y + GetDataBits(H[t].linbits);
						END;
					END;
					IF y > 0 THEN
						IF GetDataBit() THEN
							y:= -y;
						END;
					END;
				END;
			END;
		END HuffDec;

		(* Layer 3 specific Huffman decoding of the different regions*)
		PROCEDURE L3HuffDec (VAR is : HuffDecoded; ch, gr: INTEGER; part2Start :LONGINT);
		VAR i, j, x, y, v, w, r1Start, r2Start, ht : INTEGER;
				bt : BOOLEAN;
		BEGIN
			bt :=  encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2);
			IF bt THEN
				r1Start := 36;
				r2Start := 576;

			ELSE
				r1Start := SFBIDX[encFrame.samplerate].l[encFrame.ch[ch].gr[gr].region0count + 1];
				r2Start := SFBIDX[encFrame.samplerate].l[encFrame.ch[ch].gr[gr].region0count +
												encFrame.ch[ch].gr[gr].region1count + 2];
			END;

			FOR i:= 0 TO (encFrame.ch[ch].gr[gr].bigvalues -1)*2 BY 2 DO
				IF i < r1Start THEN
					ht := encFrame.ch[ch].gr[gr].tableselect[0];
				ELSIF i < r2Start THEN
					ht := encFrame.ch[ch].gr[gr].tableselect[1];
				ELSE
					ht := encFrame.ch[ch].gr[gr].tableselect[2];
				END;

				HuffDec(ht, x, y, v, w);

				is[i DIV 18][i MOD 18] := x;
				is[(i+1) DIV 18][(i+1) MOD 18] := y;
			END;

			 i:= encFrame.ch[ch].gr[gr].bigvalues * 2;
			 IF encFrame.ch[ch].gr[gr].count1tableselect THEN ht := 33; ELSE ht := 32; END;

			WHILE (totBits < (part2Start + encFrame.ch[ch].gr[gr].part23length)) & (i < 576) DO
				HuffDec(ht, x, y, v, w);
				is[i DIV 18][i MOD 18] := v;
				is[(i+1) DIV 18][(i+1) MOD 18] := w;
				is[(i+2) DIV 18][(i+2) MOD 18] := x;
				is[(i+3) DIV 18][(i+3) MOD 18] := y;
				i := i + 4;
			END;

			IF totBits > (part2Start + encFrame.ch[ch ].gr[gr].part23length) THEN
				i := i -4;
				GoBackNBits(SHORT(totBits - part2Start - LONG(encFrame.ch[ch].gr[gr].part23length)));
			END;

			IF totBits < (part2Start + encFrame.ch[ch ].gr[gr].part23length) THEN
				j := GetDataBits(SHORT(part2Start + LONG(encFrame.ch[ch].gr[gr].part23length) - totBits));
			END;

			FOR j := i TO 575 DO
				is[j DIV 18][j MOD 18] := 0;
			END;

		END L3HuffDec;

		(* Dequantizes the huffman decoded samples (samples quantized to make bitrate constant) *)
		PROCEDURE Dequantize(is: HuffDecoded; VAR xr: Granule; ch, gr : INTEGER);
		VAR ss, sb, cb, sr, nextCbBoundary, cbBegin, cbWidth, tmp, tmp2 : LONGINT;
				sign : BOOLEAN;
		BEGIN
			cb := 0; sr := encFrame.samplerate;

			IF encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2) THEN
				IF encFrame.ch[ch].gr[gr].mixedblockflag THEN
					nextCbBoundary := SFBIDX[sr].l[1]
				ELSE
					nextCbBoundary := SFBIDX[sr].s[1] * 3;
					cbWidth := SFBIDX[sr].s[1];
					cbBegin := 0;
				END;
			ELSE
				nextCbBoundary := SFBIDX[sr].l[1];
			END;

			FOR sb := 0 TO 31 DO
				FOR ss := 0 TO 17 DO

					IF (18*sb + ss) = nextCbBoundary THEN
						IF encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2) THEN
							IF encFrame.ch[ch].gr[gr].mixedblockflag THEN
								IF (18*sb +ss) = SFBIDX[sr].l[8] THEN
									nextCbBoundary := SFBIDX[sr].s[4] * 3;
									cb := 3;
									cbWidth := SFBIDX[sr].s[cb+1] - SFBIDX[sr].s[cb];
									cbBegin := SFBIDX[sr].s[cb] * 3;
								ELSIF (18*sb +ss) < SFBIDX[sr].l[8] THEN
									INC(cb);
									nextCbBoundary := SFBIDX[sr].l[cb+1];
								ELSE
									INC(cb);
									nextCbBoundary := SFBIDX[sr].s[cb+1]*3;
									cbWidth := SFBIDX[sr].s[cb+1] - SFBIDX[sr].s[cb];
									cbBegin := SFBIDX[sr].s[cb] * 3;
								END;
							ELSE
								INC(cb);
								nextCbBoundary := SFBIDX[sr].s[cb+1]*3;
								cbWidth := SFBIDX[sr].s[cb+1] - SFBIDX[sr].s[cb];
								cbBegin := SFBIDX[sr].s[cb] * 3;
							END;
						ELSE
							INC(cb);
							nextCbBoundary := SFBIDX[sr].l[cb+1];
						END;
					END;

					xr[sb][ss] := GGPOW[encFrame.ch[ch].gr[gr].globalgain];

					IF encFrame.ch[ch].gr[gr].scalefacscale THEN tmp := 1; ELSE tmp := 0; END;

					IF encFrame.ch[ch].gr[gr].windowswitchingflag & (
						((encFrame.ch[ch].gr[gr].blocktype = 2) & ~encFrame.ch[ch].gr[gr].mixedblockflag) OR
						((encFrame.ch[ch].gr[gr].blocktype = 2) & encFrame.ch[ch].gr[gr].mixedblockflag & (sb >= 2)) ) THEN

						xr[sb][ss] := xr[sb][ss] * SGPOW[encFrame.ch[ch].gr[gr].subblockgain[(18*sb +ss - cbBegin) DIV cbWidth]];
						xr[sb][ss] := xr[sb][ss] * SFSPOW[tmp][encFrame.scalefactors[ch].s[(18*sb +ss - cbBegin) DIV cbWidth][cb]];
					ELSE
						IF encFrame.ch[ch].gr[gr].preflag THEN tmp2 := 1; ELSE tmp2 := 0; END;
						xr[sb][ss] := xr[sb][ss] * SFLPOW[tmp][encFrame.scalefactors[ch].l[cb]][tmp2][cb];
					END;

					IF is[sb][ss] < 0 THEN sign := TRUE ELSE sign := FALSE; END;
					xr[sb][ss] := xr[sb][ss] * ISPOW[ABS(is[sb][ss])];
					IF sign THEN xr[sb][ss] := -xr[sb][ss] END;
				END;
			END;
		END Dequantize;

		(* Does the joint stereo processing by decoding ms-stereo and i-stereo *)
		PROCEDURE JointStereo(ro : Stereo; VAR lr: Stereo; gr: INTEGER);
		VAR	 i, j, sb, ss, sfb, sfbCnt, c, maxSfb,  lines : LONGINT;
					isPos: ARRAY 576 OF LONGINT;
					isRatio: ARRAY 576 OF REAL;
					msStereo, iStereo : BOOLEAN;
		BEGIN
			msStereo := ((encFrame.channelmode =  1) & ((encFrame.modeextension DIV 2) MOD 2 = 1));
			iStereo := ((encFrame.channelmode =  1) & (encFrame.modeextension MOD 2 = 1));

			FOR i:= 0 TO 575 DO isPos[i] := 7; END;
			IF (encFrame.stereo = 2) & iStereo THEN
				IF encFrame.ch[0].gr[gr].windowswitchingflag & (encFrame.ch[0].gr[gr].blocktype = 2) THEN
					IF encFrame.ch[0].gr[gr].mixedblockflag THEN
						maxSfb := 0;
						FOR j:= 0 TO 2 DO
							sfbCnt := 2;
							FOR sfb:= 12 TO 3 BY -1 DO
								lines :=SFBIDX[encFrame.samplerate].s[sfb+1] - SFBIDX[encFrame.samplerate].s[sfb];
								i:= 3* SFBIDX[encFrame.samplerate].s[sfb] + (j+1)* lines -1 ;
								WHILE lines  > 0 DO
									IF ro[1][i DIV 18][i MOD 18] # 0.0 THEN
										sfbCnt := sfb;
										sfb := -10;
										lines := -10;
									END;
									DEC(lines);
									DEC(i);
								END;
							END;
							sfb := sfbCnt + 1;

							IF sfb > maxSfb THEN maxSfb := sfb; END;

							WHILE sfb < 12 DO
								sb :=SFBIDX[encFrame.samplerate].s[sfb+1] - SFBIDX[encFrame.samplerate].s[sfb];
								i:= 3* SFBIDX[encFrame.samplerate].s[sfb] + j* sb ;
								FOR sb := sb TO 1 BY -1 DO
									isPos[i] := encFrame.scalefactors[1].s[j][sfb];
									IF isPos[i] # 7 THEN isRatio[i] := STEREOTAN[isPos[i]]; END;
									INC(i);
								END;
								INC (sfb);
							END;

							sb := SFBIDX[encFrame.samplerate].s[11] - SFBIDX[encFrame.samplerate].s[10];
							sfb := 3* SFBIDX[encFrame.samplerate].s[10] + j* sb ;
							sb := SFBIDX[encFrame.samplerate].s[12] - SFBIDX[encFrame.samplerate].s[11];
							i := 3* SFBIDX[encFrame.samplerate].s[11] + j* sb ;

							FOR sb := sb TO 1 BY -1 DO
									isPos[i] := isPos[sfb];
									isRatio[i] := isRatio[sfb];
									INC(i);
							END;
						END;

						IF maxSfb <= 3 THEN
							i := 2; ss := 17; sb := -1;
							WHILE i >= 0 DO
								IF ro[1][i][ss] # 0.0 THEN
									sb := i * 18 + ss;
									i := -1;
								ELSE
									DEC(ss);
									IF ss < 0 THEN
										DEC(i);
										ss := 17;
									END;
								END;
							END;

							i := 0;
							WHILE SFBIDX[encFrame.samplerate].l[i] <= sb DO INC(i); END;
							sfb := i;
							i := SFBIDX[encFrame.samplerate].l[i];
							FOR sfb := sfb TO 7 DO
								sb := SFBIDX[encFrame.samplerate].l[sfb+1] - SFBIDX[encFrame.samplerate].l[sfb];
								FOR sb := sb TO 1 BY -1 DO
									isPos[i] := encFrame.scalefactors[1].l[sfb];
									IF isPos[i] # 7 THEN isRatio[i] := STEREOTAN[isPos[i]]; END;
									INC(i);
								END;
							END;

						ELSE

							FOR j := 0 TO 2 DO
								sfbCnt := -1;
								FOR sfb := 12 TO 0 BY -1 DO
									KernelLog.Int(sfb,5); KernelLog.Ln;
									lines :=SFBIDX[encFrame.samplerate].s[sfb+1] - SFBIDX[encFrame.samplerate].s[sfb];
									i := 3* SFBIDX[encFrame.samplerate].s[sfb] + (j+1)* lines -1 ;
									WHILE lines  > 0 DO
										IF ro[1][i DIV 18][i MOD 18] # 0.0 THEN
											sfbCnt := sfb;
											sfb := -10;
											lines := -10;
										END;
										DEC(lines);
										DEC(i);
									END;
								END;
								sfb := sfbCnt + 1;

								WHILE sfb < 12 DO
									sb :=SFBIDX[encFrame.samplerate].s[sfb+1] - SFBIDX[encFrame.samplerate].s[sfb];
									i:= 3* SFBIDX[encFrame.samplerate].s[sfb] + j* sb ;
									FOR sb := sb TO 1 BY -1 DO
										isPos[i] := encFrame.scalefactors[1].s[j][sfb];
										IF isPos[i] # 7 THEN isRatio[i] := STEREOTAN[isPos[i]]; END;
										INC(i);
									END;
									INC (sfb);
								END;

								sb := SFBIDX[encFrame.samplerate].s[11] - SFBIDX[encFrame.samplerate].s[10];
								sfb := 3* SFBIDX[encFrame.samplerate].s[10] + j* sb ;
								sb := SFBIDX[encFrame.samplerate].s[12] - SFBIDX[encFrame.samplerate].s[11];
								i := 3* SFBIDX[encFrame.samplerate].s[11] + j* sb ;

								FOR sb := sb TO 1 BY -1 DO
									isPos[i] := isPos[sfb];
									isRatio[i] := isRatio[sfb];
									INC(i);
								END;
							END;
						END;

					ELSE

						i := 31; ss := 17; sb := 0;
						WHILE i >= 0 DO
							IF ro[1][i][ss] # 0.0 THEN
								sb := i * 18 + ss;
								i := -1;
							ELSE
								DEC(ss);
								IF ss < 0 THEN
									DEC(i);
									ss := 17;
								END;
							END;
						END;
					END;

					i := 0;

					WHILE SFBIDX[encFrame.samplerate].l[i] <= sb DO INC(i); END;
					sfb := i;
					i := SFBIDX[encFrame.samplerate].l[i];
					FOR sfb := sfb TO 20 DO
						sb := SFBIDX[encFrame.samplerate].l[sfb+1] - SFBIDX[encFrame.samplerate].l[sfb];
						FOR sb := sb TO 1 BY -1 DO
							isPos[i] := encFrame.scalefactors[1].l[sfb];
							IF isPos[i] # 7 THEN isRatio[i] := STEREOTAN[isPos[i]]; END;
							INC(i);
						END;
					END;

					sfb := SFBIDX[encFrame.samplerate].l[20];
					FOR sb := 576 - SFBIDX[encFrame.samplerate].l[21] TO 1 BY -1 DO
						isPos[i] := isPos[sfb];
						isRatio[i] := isRatio[sfb];
						INC(i);
					END;
				END;
			END;

			FOR c := 0 TO 1 DO
				FOR sb := 0 TO 31 DO
					FOR ss := 0 TO 17 DO
						lr[c][sb][ss] := 0;
					END;
				END;
			END;

			IF encFrame.stereo = 2 THEN
				FOR sb := 0 TO 31 DO
					FOR ss := 0 TO 17 DO
						i := sb*18 + ss;
						IF isPos[i] = 7 THEN
							IF msStereo THEN
								lr[0][sb][ss] := (ro[0][sb][ss] + ro[1][sb][ss]) / 1.41421356;
								lr[1][sb][ss] := (ro[0][sb][ss] - ro[1][sb][ss]) / 1.41421356;
							ELSE
								lr[0][sb][ss] := ro[0][sb][ss];
								lr[1][sb][ss] := ro[1][sb][ss];
							END;
						ELSIF iStereo THEN
							lr[0][sb][ss] := ro[0][sb][ss] * (isRatio[i] / (1+isRatio[i]));
							lr[1][sb][ss] := ro[0][sb][ss] * (1 / (1+isRatio[i]));
						ELSE
							KernelLog.String("Error occoured in stereo processing!");
						END;
					END;
				END;
			ELSE
				FOR sb := 0 TO 31 DO
					FOR ss := 0 TO 17 DO
						lr[0][sb][ss] := ro[0][sb][ss]
					END;
				END;
			END;

		END JointStereo;


		(* Reorders the samples (samples reordered for better compression 123 123 123 -> 111 222 333) *)
		PROCEDURE Reorder(xr : Granule; VAR re : Granule; ch, gr : INTEGER);
		VAR sfb, sfbStart, sfbLines, sb, ss, window, freq, srcLine, dstLine : LONGINT;
		BEGIN
			FOR sb := 0 TO 31 DO
				FOR ss := 0 TO 17 DO
					re[sb][ss] := 0;
				END;
			END;

			IF encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2) THEN
				IF encFrame.ch[ch].gr[gr].mixedblockflag THEN
					FOR sb := 0  TO 1 DO
						FOR ss := 0 TO 17 DO
							re[sb][ss] := xr[sb][ss];
						END;
					END;

					sfbStart := SFBIDX[encFrame.samplerate].s[3];
					sfbLines := SFBIDX[encFrame.samplerate].s[4] - sfbStart;
					FOR sfb := 3 TO 12 DO
						FOR window := 0 TO 2 DO
							FOR freq := 0 TO sfbLines -1 DO
								srcLine := sfbStart * 3 + window * sfbLines + freq;
								dstLine := sfbStart * 3 + window + freq * 3;
								re[dstLine DIV 18][dstLine MOD 18] := xr[srcLine DIV 18][srcLine MOD 18];
							END;
							END;
						IF sfb # 12 THEN
							sfbStart := SFBIDX[encFrame.samplerate].s[sfb+1];
							sfbLines := SFBIDX[encFrame.samplerate].s[sfb+2] - sfbStart;
						END;
					END;
				ELSE
					sfbStart := 0;
					sfbLines := SFBIDX[encFrame.samplerate].s[1];
					FOR sfb := 0 TO 12 DO
						FOR window := 0 TO 2 DO
							FOR freq := 0 TO sfbLines -1 DO
								srcLine := sfbStart * 3 + window * sfbLines + freq;
								dstLine := sfbStart * 3 + window + freq * 3;
								re[dstLine DIV 18][dstLine MOD 18] := xr[srcLine DIV 18][srcLine MOD 18];
							END;
						END;
						IF sfb # 12 THEN
							sfbStart := SFBIDX[encFrame.samplerate].s[sfb+1];
							sfbLines := SFBIDX[encFrame.samplerate].s[sfb+2] - sfbStart;
						END;
					END;
				END;
			ELSE
				FOR sb := 0 TO 31 DO
					FOR ss := 0 TO 17 DO
						re[sb][ss] := xr[sb][ss];
					END;
				END;
			END;
		END Reorder;


		(* Compensates the alias effects that wereproduced by the polyphase filterbank of the encoder *)
		PROCEDURE Antialias(xr: Granule; VAR hybridIn: Granule; ch, gr : INTEGER);
		VAR ss, sb, sblim : INTEGER;
				bu, bd : REAL;
		BEGIN
			FOR sb := 0 TO 31 DO
				FOR ss := 0 TO 17 DO
					hybridIn[sb][ss] := xr[sb][ss];
				END;
			END;

			IF ~(encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2)
				& ~encFrame.ch[ch].gr[gr].mixedblockflag) THEN

				IF encFrame.ch[ch].gr[gr].windowswitchingflag & (encFrame.ch[ch].gr[gr].blocktype = 2)
				& encFrame.ch[ch].gr[gr].mixedblockflag THEN
					sblim := 1;
				ELSE
					sblim := 31;
				END;

				FOR sb := 0 TO sblim - 1 DO
					FOR ss := 0 TO 7 DO
						bu := xr[sb][17-ss];
						bd := xr[sb+1][ss];
						hybridIn[sb][17-ss] := (bu * CS[ss]) - (bd * CA[ss]);
						hybridIn[sb+1][ss] := (bd * CS[ss]) + (bu * CA[ss]);
					END;
				END;

			END;

		END Antialias;


		(* Do the IMDCT and the overlapping *)
		PROCEDURE HybridSynthesis(hybridIn : Granule; VAR hybridOut: Granule; ch, gr: INTEGER);
		VAR sb, i, j : LONGINT;
				bt: INTEGER;
				rawout : Raw36;
				rawin : Raw18;
		BEGIN
			IF encFrame.hsynth THEN
				FOR j:=0 TO 1 DO
					FOR sb:=0 TO 31 DO
						FOR i:=0 TO 17 DO
							encFrame.store[j][sb][i] := 0.0;
						END;
					END;
				END;
				encFrame.hsynth := FALSE;
			END;

			FOR sb:=0 TO 31 DO
				IF encFrame.ch[ch].gr[gr].windowswitchingflag & encFrame.ch[ch].gr[gr].mixedblockflag & (sb <2) THEN
					bt := 0;
				ELSE
					bt:= encFrame.ch[ch].gr[gr].blocktype;
				END;

				FOR i:=0 TO 17 DO
					rawin[i] := hybridIn[sb][i];
				END;

				IMDCT(rawin, rawout, bt);

				FOR i:=0 TO 17 DO
					hybridOut[sb][i] := rawout[i] + encFrame.store[ch][sb][i];
					encFrame.store[ch][sb][i] := rawout[i + 18];
				END;

			END;

		END HybridSynthesis;

		(* The optimized inverse discrete consine transform *)
		PROCEDURE IMDCT(in: Raw18; VAR out: Raw36; bt: INTEGER);
		VAR
			i, m : LONGINT;
			tin, hl : ARRAY 18 OF REAL;
			tmp : ARRAY 12 OF REAL;
			hs : ARRAY 6 OF REAL;
			evens, odds, evenidcts, oddidcts : Raw3;
			evenl, oddl, evenidctl, oddidctl : Raw9;

		BEGIN
			IF bt = 2 THEN
				FOR i:= 0 TO 35 DO
					out[i] := 0.0;
				END;

				FOR i:=0 TO 2 DO
					FOR m :=0 TO 5 DO
						tin[i * 6 + m] := in[i + 3 * m];
					END;
				END;

				FOR i:=0 TO 2 DO
					(* IMDCT SHORT *)
					hs[0] := tin[6 * i];
					FOR m := 1 TO 5 DO
						hs[m] := tin[6 * i -1 + m] + tin[6 * i + m] ;
					END;

					evens[0] := hs[0]; evens[1] := hs[2]; evens[2] := hs[4];

					IMDCT3pt(evens, evenidcts);

					odds[0] := hs[1]; odds[1] := hs[1] + hs[3]; odds[2] := hs[3] + hs[5];

					IMDCT3pt(odds, oddidcts);

					oddidcts[0] :=  oddidcts[0] * POSTTWIDDLE6[0];
					oddidcts[1] :=  oddidcts[1] * POSTTWIDDLE6[1];
					oddidcts[2] :=  oddidcts[2] * POSTTWIDDLE6[2];

					hs[0] := evenidcts[0] + oddidcts[0];
					hs[1] := evenidcts[1] + oddidcts[1];
					hs[2] := evenidcts[2] + oddidcts[2];

					hs[3] := evenidcts[2] - oddidcts[2];
					hs[4] := evenidcts[1] - oddidcts[1];
					hs[5] := evenidcts[0] - oddidcts[0];

					FOR m:=0 TO 5 DO
						hs[m] := hs[m] * POSTTWIDDLE12[m];
					END;

					tmp[0] := 	hs[3];
					tmp[1] := 	hs[4];
					tmp[2] := 	hs[5];
					tmp[3] := 	-hs[5];
					tmp[4] := 	-hs[4];
					tmp[5] := 	-hs[3];
					tmp[6] := 	-hs[2];
					tmp[7] := 	-hs[1];
					tmp[8] := 	-hs[0];
					tmp[9] := 	-hs[0];
					tmp[10] :=   -hs[1];
					tmp[11] :=  -hs[2];


					FOR m:=0 TO 11 DO
						out[6 * i + m + 6] := out[6 * i + m + 6] + tmp[m] * IMDCTWIN[bt][m];
					END;
				END;

			ELSE
				(* IMDCT LONG *)

				hl[0] := in[0];
				FOR i:=1 TO 17 DO
					hl[i] := in[i-1] + in[i];
				END;

				FOR i:= 0 TO 8 DO
					evenl[i] := hl[i * 2];
				END;

				IMDCT9pt(evenl, evenidctl);

				oddl[0] := hl[1];
				FOR i:= 1 TO 8 DO
					oddl[i] := hl[i * 2 - 1] + hl[i * 2  + 1];
				END;

				IMDCT9pt(oddl, oddidctl);

				FOR i:= 0 TO 8 DO
					oddidctl[i] := oddidctl[i] * POSTTWIDDLE18[i];
				END;

				FOR i:= 0 TO 8 DO
					hl[i] := evenidctl[i] + oddidctl[i];
				END;

				FOR i:= 9 TO 17 DO
					hl[i] := evenidctl[17 - i] - oddidctl[17 - i];
				END;

				FOR i:= 0 TO 17 DO
					hl[i] := hl[i] * POSTTWIDDLE36[i];
				END;

				out[0] := 	hl[9];			out[1] := 	hl[10];
				out[2] := 	hl[11];			out[3] := 	hl[12];
				out[4] := 	hl[13];			out[5] := 	hl[14];
				out[6] := 	hl[15];			out[7] := 	hl[16];
				out[8] := 	hl[17];			out[9] := 	-hl[17];
				out[10] := 	-hl[16];			out[11] := 	-hl[15];
				out[12] := 	-hl[14];			out[13] := 	-hl[13];
				out[14] := 	-hl[12];			out[15] := 	-hl[11];
				out[16] := 	-hl[10];			out[17] := 	-hl[9];
				out[18] := 	-hl[8];			out[19] := 	-hl[7];
				out[20] := 	-hl[6];			out[21] := 	-hl[5];
				out[22] := 	-hl[4];			out[23] := 	-hl[3];
				out[24] := 	-hl[2];			out[25] := 	-hl[1];
				out[26] := 	-hl[0];			out[27] := 	-hl[0];
				out[28] := 	-hl[1];			out[29] := 	-hl[2];
				out[30] := 	-hl[3];			out[31] := 	-hl[4];
				out[32] := 	-hl[5];			out[33] := 	-hl[6];
				out[34] := 	-hl[7];			out[35] := 	-hl[8];


				FOR i:=0 TO 35 DO
					out[i] := out[i] * IMDCTWIN[bt][i];
				END;

			END;

		END IMDCT;

		(* 3 point inverse discrete consine transform *)
		PROCEDURE IMDCT3pt(in: Raw3; VAR out: Raw3);
		VAR t0, t1 : REAL;
		BEGIN
			t0 := in[2] / 2 + in[0];
			t1 := in[1] * IMDCTSQRT;

			out[0] := t0 + t1;
			out[1] := in[0] - in[2];
			out[2] := t0 - t1;

		END IMDCT3pt;

		(* 4 point inverse discrete consine transform *)
		PROCEDURE IMDCT4pt(in: Raw4; VAR out: Raw4);
		VAR t0, t1 : REAL;
		BEGIN
			t0 := in[3] / 2 + in[0];
			t1 := in[1] - in[2];

			out[0] := t0 + in[1] * IMDCTCOS[1] + in[2] * IMDCTCOS[2];
			out[1] := t1 / 2 + in[0] - in[3];
			out[2] := t0 - in[1] * IMDCTCOS[4] - in[2] * IMDCTCOS[1];
			out[3] := t0 - in[1] * IMDCTCOS[2] + in[2] * IMDCTCOS[4];

		END IMDCT4pt;

		(* 5 point inverse discrete consine transform *)
		PROCEDURE IMDCT5pt(in: Raw5; VAR out: Raw5);
		VAR t0, t1, t2 : REAL;
		BEGIN
			t0 := in[3] /2 + in[0];
			t1 := in[0] - in[3];
			t2 := in[1] - in[2] -in[4];

			out[0] := t0 + in[1] * IMDCTCOS[1] + in[2] * IMDCTCOS[2] + in[4] * IMDCTCOS[4];
			out[1] := t2 / 2 + t1;
			out[2] := t0 - in[1] * IMDCTCOS[4] - in[2] * IMDCTCOS[1] + in[4] * IMDCTCOS[2];
			out[3] := t0 - in[1] * IMDCTCOS[2] + in[2] * IMDCTCOS[4] - in[4] * IMDCTCOS[1];
			out[4] := t1 - t2;

		END IMDCT5pt;


		(* 9 point inverse discrete consine transform *)
		PROCEDURE IMDCT9pt(in: Raw9; VAR out: Raw9);
		VAR i: LONGINT;
				even, evenidct : Raw5;
				odd, oddidct: Raw4;
		BEGIN
			FOR i:= 0 TO 4 DO
				even[i] := in[2 * i];
			END;

			IMDCT5pt(even, evenidct);

			odd[0] := in[1];
			FOR i:= 1 TO 3 DO
				odd[i] := in[2 * i -1] + in[2 * i +1];
			END;

			IMDCT4pt(odd, oddidct);

			oddidct[0] := oddidct[0] + in[7] * IMDCTSIN[0];
			oddidct[1] := oddidct[1] - in[7] * IMDCTSIN[1];
			oddidct[2] := oddidct[2] + in[7] * IMDCTSIN[2];
			oddidct[3] := oddidct[3] - in[7] * IMDCTSIN[3];

			FOR i:=0 TO 3 DO
				oddidct[i] := oddidct[i] * POSTTWIDDLE9[i];
			END;

			FOR i:=0 TO 3 DO
				out[i] := evenidct[i] + oddidct[i];
			END;

			out[4] := evenidct[4];

			FOR i:=5 TO 8 DO
				out[i] := evenidct[8-i] - oddidct[8-i];
			END;

		END IMDCT9pt;

		(* does the conversion from the frequency domain into the time domain *)
		PROCEDURE SubbandSynthesis(in : Granule; VAR out :  PcmStereo; ch, gr : INTEGER);
		VAR i, j, ss, tmp1, tmp2 : LONGINT;
			samp : LONGINT;
			sVec, tmp : Raw32;
			sum : REAL;
		BEGIN
			(* Initialisation *)
			IF encFrame.ssynth THEN
				FOR i:=0 TO 1 DO
					FOR j:=0 TO 1023 DO
						vVec[i][j] := 0.0;
					END;
				END;
				vectIdx0 := 64;
				vectIdx1 := 64;
				encFrame.ssynth := FALSE;
			END;

			(* Channels explicitly separated for performance reasons *)
			IF (ch = 0)  THEN

				FOR ss:=0 TO 17 DO

					(* Use vVect as a ring puffer *)
					vectIdx0 := vectIdx0 - 64;
					IF vectIdx0 < 0 THEN vectIdx0 :=  960; END;

					FOR i:=0 TO 31 DO
						sVec[i] := in[i][ss];
					END;

					(* Polyphase Matrixing *)
					DCT(sVec, tmp, 32);

					FOR i:=0 TO 15 DO
						vVec[0][(i + vectIdx0) MOD 1024] := tmp[i + 16];
					END;
					vVec[0][(16 + vectIdx0) MOD 1024] := 0.0;
					FOR i:=17 TO 47 DO
						vVec[0][(i + vectIdx0) MOD 1024] := -tmp[48 - i];
					END;
					FOR i:=48 TO 63 DO
						vVec[0][(i + vectIdx0) MOD 1024] := -tmp[i - 48];
					END;

					FOR i:=0 TO 31 DO
						sum := 0.0;
						tmp2:= i;
						FOR j:=0 TO 15 DO
							tmp1 :=  j * 32 + i;
							sum := sum + vVec[0][(tmp2 + vectIdx0) MOD 1024] * GS[tmp1];
							tmp2 :=  tmp2 + 96 - (j MOD 2)* 64;
						END;

						samp := ENTIER(sum * 32767);
						IF samp > 32767 THEN
							samp := 32767;
						ELSIF samp < -32767 THEN
							samp := -32767;
						END;

						SYSTEM.PUT(ADDRESSOF(out[128 * ss  + 4 * i ]),SHORT(samp));

					END;

				END;

			ELSE

				FOR ss:=0 TO 17 DO

					(* Use vVect as a ring puffer *)
					vectIdx1 := vectIdx1 - 64;
					IF vectIdx1 < 0 THEN vectIdx1 :=  960; END;

					FOR i:=0 TO 31 DO
						sVec[i] := in[i][ss];
					END;

					(* Polyphase Matrixing *)
					DCT(sVec, tmp, 32);

					FOR i:=0 TO 15 DO
						vVec[1][(i + vectIdx1) MOD 1024] := tmp[i + 16];
					END;
					vVec[1][(16 + vectIdx1) MOD 1024] := 0.0;
					FOR i:=17 TO 47 DO
						vVec[1][(i + vectIdx1) MOD 1024] := -tmp[48 - i];
					END;
					FOR i:=48 TO 63 DO
						vVec[1][(i + vectIdx1) MOD 1024] := -tmp[i - 48];
					END;


					FOR i:=0 TO 31 DO
						sum := 0.0;
						tmp2:= i;
						FOR j:=0 TO 15 DO
							tmp1 :=  j * 32 + i;
							sum := sum + vVec[1][(tmp2 + vectIdx1) MOD 1024] * GS[tmp1];
							tmp2 :=  tmp2 + 96 - (j MOD 2)* 64;
						END;

						samp := ENTIER(sum * 32767);
						IF samp > 32767 THEN
							samp := 32767;
						ELSIF samp < -32767 THEN
							samp := -32767;
						END;

						SYSTEM.PUT(ADDRESSOF(out[128 * ss  + 4 * i + 2*1 ]),SHORT(samp));

					END;
				END;

			END;

		END SubbandSynthesis;

		(* used in the subband synthesis *)
		PROCEDURE DCT(in : Raw32; VAR out : Raw32; n : INTEGER);
		VAR i : LONGINT;
				evenin, evenout, oddin, oddout : Raw32;
		BEGIN
			IF n = 2 THEN
				(* Do the 2pt DCT *)
				out[0] := in[0] * DCTCOS[0][0] + in[1]*DCTCOS[1][0];
				out[1] := in[0] * DCTCOS[0][1] + in[1]*DCTCOS[1][1];
			ELSE
				FOR i:=0 TO (n DIV 2) -1 DO
					evenin[i] := in[i] + in[n-1-i];
				END;

				DCT(evenin, evenout, n DIV 2);

				FOR i:=0 TO (n DIV 2) -1 DO
					oddin[i] := (in[i] - in[n-1-i]) * DCTTWIDDLE[i][n];
				END;

				DCT(oddin, oddout, n DIV 2);

				FOR i:= 0 TO (n DIV 2) -1 DO
					out[2 * i] := evenout[i];
				END;

				FOR i:= 0 TO (n DIV 2) -2 DO
					out[2 * i + 1] := oddout[i] + oddout[i + 1];
				END;

				out[n-1] := oddout[(n DIV 2) -1];

			END;
		END DCT;

		PROCEDURE Open*(in: Streams.Reader; VAR res: LONGINT);
		VAR
			tmp: LONGINT;
		BEGIN
			SELF.s := in;

			s.SetPos(0);
			tmp := s.Pos();

			NEW(encFrame);
			frameNum:=1; totBits := 0; frameStart := 0; offset := 0; curByte := -1; curBit := 8;
			encFrame.hsynth := TRUE; encFrame.ssynth := TRUE;

			Next();
			(* store paranoia information *)
			paranoia := FALSE;
			fHeader[0] := 0FFX;
			IF encFrame.crc THEN fHeader[1] := 0FBX
			ELSE fHeader[1] := 0FAX END;
			fHeader[2] := encFrame.header[32];
			fHeader[3] := encFrame.header[33];
			fHeader[4] := 0X;

			IF s.res = Streams.EOF THEN
				hasMoreBytes := FALSE;
				res := Codecs.ResFailed;
			ELSE
				IF encFrame.samplerate = 0 THEN
					samplesPerSec := 44100;
				ELSIF encFrame.samplerate = 1 THEN
					samplesPerSec := 48000;
				ELSIF encFrame.samplerate = 2 THEN
					samplesPerSec := 32000;
				ELSE
					samplesPerSec := 44100;
				END;

				channels := 2;
				totSamples := -1;

				bitRate := BITRATE[encFrame.bitrate];

				(* Problem: This decoder only works for framesizes of constant size 2304 Bytes 	*)
				(* In Layer 3, every Frame has 1152 samples, so we get a constant of 16 		*)
				(* And SoundDevices for now only supports 16 bits per sample						*)
				bitsPerSample := 16;

				s.SetPos(tmp);

				res := Codecs.ResOk;
				first := TRUE;
				hasMoreBytes := TRUE;
			END;
		END Open;

		(* Returns the current sample position *)
		PROCEDURE GetCurrentSample*() : LONGINT;
		BEGIN
			RETURN ENTIER(8 * s.Pos() / bitRate / 1000 * samplesPerSec)
		END GetCurrentSample;

		(* Returns the current time in 1/10 sec *)
		PROCEDURE GetCurrentTime*() : LONGINT;
		BEGIN
			RETURN ENTIER(10 * GetCurrentSample() / samplesPerSec)
		END GetCurrentTime;

		PROCEDURE GetAudioInfo*(VAR nofChannels, samplesPerSecond, bitsPerSample: LONGINT);
		BEGIN
			nofChannels := channels;
			bitsPerSample := SELF.bitsPerSample;
			samplesPerSecond := SELF.samplesPerSec;
		END GetAudioInfo;

		(* Returns the total number of Samples in this file or -1 if streaming or VBR *)
		PROCEDURE GetTotalSamples*() : LONGINT;
		BEGIN
			RETURN totSamples
		END GetTotalSamples;

		(* Sets the size of the Stream in Bytes. Only works for CBR *)
		PROCEDURE SetStreamLength*(length : LONGINT);
		BEGIN
			totSamples := ENTIER(8 * length / bitRate / 1000 * samplesPerSec)
		END SetStreamLength;

		(* Returns TRUE if the underlying stream and therefore this decoder supports seeking.			*)
		(* @params: none																			*)
		(* @returns: seekability of underlying stream/fileabstraction									*)
		PROCEDURE CanSeek*(): BOOLEAN;
		BEGIN
			RETURN (s # NIL) & (s.CanSetPos());
		END CanSeek;

		(* This method is for seeking in the stream. 													*)
		(* @params: sample: the sample to seek, goKeySample: if we have a containerformat which 	*)
		(*		        specifies keysamples, this flag can be set, res: the result of the seekoperation		*)
		(* @returns: nothing																		*)
		PROCEDURE SeekSample*(sample : LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		BEGIN
			IF ~CanSeek() THEN res := Codecs.ResFailed; RETURN; END;
			COPY("0000", cHeader);
			paranoia := TRUE;			(* sets paranoia mode, the next frame MUST match exactly *)
			s.SetPos(ENTIER(sample / samplesPerSec * bitRate / 8 * 1000));
			first := TRUE;
			IF s.Available() > 0 THEN hasMoreBytes := TRUE; ELSE hasMoreBytes := FALSE; END;
		END SeekSample;

		(* Seeks the Sample at the position given in ms *)
		PROCEDURE SeekMillisecond*(millisecond : LONGINT; goKeySample : BOOLEAN; VAR res : LONGINT);
		BEGIN
			SeekSample(ENTIER(millisecond*samplesPerSec/1000), goKeySample, res);
		END SeekMillisecond;

		(* This Procedure is of no use, since the buffering of audio must be done in Playerapplications 	*)
		(* Later versions of Codecs will probably adapt this										*)
		(* @params: none																			*)
		(* @returns: audioTime in milliseconds or microseconds										*)
		PROCEDURE GetAudioTime*():HUGEINT;
		BEGIN
			KernelLog.String("AudioTime calculation must be done in Playerapplication!"); KernelLog.Ln();
			RETURN -1;
		END GetAudioTime;

		(* This Procedure fillles an SoundDevices Buffer with the number of Bytes calculated out of the	*)
		(* buffersize																				*)
		(* @params: buffer: SoundDevices.Buffer														*)
		(* @returns: nothing																	*)
		PROCEDURE FillBuffer*(buffer: SoundDevices.Buffer);
		VAR
			j: LONGINT;
		BEGIN
			IF first THEN
				NEW(encFrame);
				curBit := 8;
				curByte := -1;
				tempVal := 0;
				offset := 0;
				totBits := 0;
				mainDataEnd := 0;
				frameStart := 0;
				vectIdx0 := 0;
				vectIdx1 := 0;
				frameNum:=1;

				encFrame.hsynth := TRUE;
				encFrame.ssynth := TRUE;
				encFrame.curByte := -1;
				encFrame.curBit := 8;
				first := FALSE;
				gr:=0;
				outBufferPos := 0;
				Next();
				DoLayer3();
			END;

			IF s.res = Streams.EOF THEN
				hasMoreBytes := FALSE;
				RETURN;
			END;

			FOR j := 0 TO buffer.len-1 DO
				IF outBufferPos > 2303 THEN
					IF gr = 1 THEN
						gr := 0;
						IF (s.res = Streams.EOF) & (s.res = Streams.Ok) THEN
							hasMoreBytes := FALSE;
							RETURN;
						END;
						Next();
						IF (s.res = Streams.EOF) & (s.res = Streams.Ok) THEN
							hasMoreBytes := FALSE;
							RETURN;
						END;
						DoLayer3();
						outBufferPos := 0;
						INC(frameNum);
					ELSE
						gr := 1;
						outBufferPos := 0;
						INC(frameNum);
					END;
				END;
				buffer.data[j] := out[gr][outBufferPos];
				INC(outBufferPos);
			END;
		END FillBuffer;

		(* This Procedure prepares a layer3 frame, so that it can be filled in a buffer				*)
		(* @params: none																		*)
		(* @returns: nothing																	*)
		PROCEDURE DoLayer3;
		VAR
			j, ch, grt, dummy, flushMain, bytesToDiscard, sb, ss : INTEGER;
			part2Start : LONGINT;
			is : HuffDecoded;
			ro, lr : Stereo;
			re, hybridIn, hybridOut : Granule;

		BEGIN
			mainDataEnd := SHORT(ENTIER(totBits / 8));
			flushMain := SHORT(totBits - mainDataEnd*8);
			IF flushMain # 0 THEN
				dummy := GetDataBits(8-flushMain);
				INC(mainDataEnd);
			END;

			bytesToDiscard := frameStart - mainDataEnd - encFrame.maindatabegin;

			IF mainDataEnd > 4096 THEN
				frameStart := frameStart - 4096;
				totBits := (totBits - 8* 4096);
				curByte := curByte - 4096;
			END;

			frameStart := frameStart + encFrame.nofSlots;


			IF bytesToDiscard < 0 THEN
				DEC(frameNum);
			ELSE
				FOR j:= 1 TO bytesToDiscard DO dummy := GetDataBits(8); END;
					FOR grt:=0 TO 1 DO
						FOR ch:=0 TO encFrame.stereo-1 DO
							part2Start := totBits;
							GetScaleFactors(ch,grt);
							L3HuffDec(is,ch,grt,part2Start);
							Dequantize(is, ro[ch], ch, grt);
						END;

						JointStereo(ro, lr,grt);

						FOR ch:=0 TO encFrame.stereo-1 DO
							Reorder(lr[ch], re, ch, grt);
							Antialias(re, hybridIn, ch, grt);
							HybridSynthesis(hybridIn, hybridOut, ch, grt);
							(* Frequency inversion *)
							FOR ss:=0 TO 17 DO
								FOR sb:=0 TO 31 DO
									IF (ss MOD 2 = 1) & (sb MOD 2 = 1) THEN hybridOut[sb][ss] := -hybridOut[sb][ss]; END;
								END;
							END;

							SubbandSynthesis(hybridOut, out[grt], ch, gr);
						END;
					END; (* FOR *)
				END;
		END DoLayer3;

		(* This procedure returns the status of filereading: FALSE -> EOF has been reached				*)
		(* @params: none																			*)
		(* @returns: flag, indicating the status of filereading											*)
		PROCEDURE HasMoreData*(): BOOLEAN;
		BEGIN
			RETURN hasMoreBytes;
		END HasMoreData;


		(* Gets next bit of current frame header*)
		PROCEDURE GetBit() : BOOLEAN;
		VAR b:BOOLEAN;
		BEGIN
			INC(encFrame.curBit);
			IF encFrame.curBit > 7 THEN
				encFrame.curBit := 0;
				INC(encFrame.curByte);
				encFrame.tempVal := ORD(encFrame.header[encFrame.curByte]);
			END;
			b := (encFrame.tempVal DIV 128 # 0);
			IF b THEN encFrame.tempVal := encFrame.tempVal - 128; END;
			encFrame.tempVal := encFrame.tempVal  *  2;
			RETURN b;
		END GetBit;

		(* Gets some bits of current frame header*)
		PROCEDURE GetBits(count:INTEGER) : INTEGER;
		VAR i,c,pot :INTEGER;
		BEGIN
			i := 0; pot:=1;

			FOR c:= 1 TO count -1 DO
				pot:= 2* pot;
			END;

			FOR c:= 1 TO count DO
				IF GetBit() THEN i:= i+pot; END;
				pot := pot DIV 2;
			END;

			RETURN i;
		END GetBits;


		(* Gets next data bit out of buffer*)
		PROCEDURE GetDataBit() : BOOLEAN;
		VAR b:BOOLEAN;
		BEGIN
			INC(curBit);
			IF curBit > 7 THEN
				curBit := 0;
				INC(curByte);
				tempVal := ORD(data[curByte MOD MAXBUF]);
			END;
			b := (tempVal DIV 128 # 0);
			IF b THEN tempVal := tempVal - 128; END;
			tempVal := tempVal  *  2;
			INC(totBits);
			RETURN b;
		END GetDataBit;

		(* Gets some data bits  out of buffer*)
		PROCEDURE GetDataBits(count:INTEGER) : INTEGER;
		VAR i,c,pot :INTEGER;
		BEGIN
			i := 0; pot:=1;

			FOR c:= 1 TO count -1 DO
				pot:= 2* pot;
			END;

			FOR c:= 1 TO count DO
				IF GetDataBit() THEN i:= i+pot; END;
				pot := pot DIV 2;
			END;

			RETURN i;
		END GetDataBits;


		(* Go back n bits in the buffer *)
		PROCEDURE GoBackNBits( n: INTEGER);
		BEGIN
			totBits := totBits - n;
			curBit := curBit + n;
			WHILE curBit >= 8 DO
				curBit := curBit - 8;
				DEC(curByte);
			END;
		END GoBackNBits;

	END MP3Decoder;

(*                                                                  *)
(*                 Table Initialisations                  *)
(*                                                                  *)

(* Read in the Huffman decoding tables *)
PROCEDURE LoadHuffmanTables;
VAR f: Files.File;
		r: Files.Reader;
		c: CHAR;
		tableNo, i : INTEGER;
BEGIN
	f := Files.Old("MP3Huffman.Bin");
	Files.OpenReader(r, f, 0);
	tableNo:=0;
		LOOP
			r.Char(c);
			H[tableNo].len := ORD(c);
			IF (tableNo >= 13) & (tableNo < 24) & (H[tableNo].len #0) THEN H[tableNo].len := H[tableNo].len + 256; END;
		IF (tableNo >=24) & (tableNo < 32) THEN H[tableNo].len := H[tableNo].len + 512; END;
			r.Char(c);
			H[tableNo].xlen := ORD(c);
			r.Char(c);
			H[tableNo].ylen := ORD(c);
			r.Char(c);
			H[tableNo].linbits := ORD(c);
			NEW (H[tableNo].v,H[tableNo].len);
			FOR i := 0 TO H[tableNo].len -1 DO
				NEW (H[tableNo].v[i],2);
				r.Char(c);
				H[tableNo].v[i][0] := ORD(c);
				r.Char(c);
				H[tableNo].v[i][1] := ORD(c);
			END;
			INC(tableNo);
			IF (r.res # Streams.Ok) OR (tableNo >= 34) THEN EXIT END;
		END;
END LoadHuffmanTables;


(* Initialize certain tables *)
PROCEDURE InitTables;
VAR i, j, k, l: INTEGER;
		LN2, sq: REAL;
BEGIN
	JSBTABLE[0] := 0; JSBTABLE[1] := 4; JSBTABLE[2] := 8;  JSBTABLE[3] := 16;

	BITRATE[0] := 0; 	BITRATE[1] := 32;	BITRATE[2] := 40;	BITRATE[3] := 48;	BITRATE[4] := 56;
	BITRATE[5] := 64;	BITRATE[6] := 80;	BITRATE[7] := 96;	BITRATE[8] := 112;	BITRATE[9] := 128;
	BITRATE[10] := 160;	BITRATE[11] := 192;	BITRATE[12] := 224;	BITRATE[13] := 256;	BITRATE[14] := 320;

	FREQUENCY [0] := 44.1; FREQUENCY [1] := 48; FREQUENCY [2] := 32; FREQUENCY [3] := 0;

	SFBTABLE.l[0] := 0; SFBTABLE.l[1] := 6; SFBTABLE.l[2] := 11; SFBTABLE.l[3] := 16; SFBTABLE.l[4] := 21;
	SFBTABLE.s[0] := 0; SFBTABLE.s[1] := 6; SFBTABLE.s[2] := 12;

	SLEN[0][0] := 0; SLEN[0][1] := 0; SLEN[0][2] := 0; SLEN[0][3] := 0;
	SLEN[0][4] := 3; SLEN[0][5] := 1; SLEN[0][6] := 1; SLEN[0][7] := 1;
	SLEN[0][8] := 2; SLEN[0][9] := 2; SLEN[0][10] := 2; SLEN[0][11] := 3;
	SLEN[0][12] := 3; SLEN[0][13] := 3; SLEN[0][14] := 4; SLEN[0][15] := 4;

	SLEN[1][0] := 0; SLEN[1][1] := 1; SLEN[1][2] := 2; SLEN[1][3] := 3;
	SLEN[1][4] := 0; SLEN[1][5] := 1; SLEN[1][6] := 2; SLEN[1][7] := 3;
	SLEN[1][8] := 1; SLEN[1][9] := 2; SLEN[1][10] := 3; SLEN[1][11] := 1;
	SLEN[1][12] := 2; SLEN[1][13] := 3; SLEN[1][14] := 2; SLEN[1][15] := 3;

	SFBIDX[0].l[0] := 0; SFBIDX[0].l[1] := 4; SFBIDX[0].l[2] := 8; SFBIDX[0].l[3] := 12;
	SFBIDX[0].l[4] := 16; SFBIDX[0].l[5] := 20; SFBIDX[0].l[6] := 24; SFBIDX[0].l[7] := 30;
	SFBIDX[0].l[8] := 36; SFBIDX[0].l[9] := 44; SFBIDX[0].l[10] := 52; SFBIDX[0].l[11] := 62;
	SFBIDX[0].l[12] := 74; SFBIDX[0].l[13] := 90; SFBIDX[0].l[14] := 110; SFBIDX[0].l[15] := 134;
	SFBIDX[0].l[16] := 162; SFBIDX[0].l[17] := 196; SFBIDX[0].l[18] := 238; SFBIDX[0].l[19] := 288;
	SFBIDX[0].l[20] := 342; SFBIDX[0].l[21] := 418; SFBIDX[0].l[22] := 576;

	SFBIDX[0].s[0] := 0; SFBIDX[0].s[1] := 4; SFBIDX[0].s[2] := 8; SFBIDX[0].s[3] := 12;
	SFBIDX[0].s[4] := 16; SFBIDX[0].s[5] := 22; SFBIDX[0].s[6] := 30; SFBIDX[0].s[7] := 40;
	SFBIDX[0].s[8] := 52; SFBIDX[0].s[9] := 66; SFBIDX[0].s[10] := 84; SFBIDX[0].s[11] := 106;
	SFBIDX[0].s[12] := 136; SFBIDX[0].s[13] := 192;

	SFBIDX[1].l[0] := 0; SFBIDX[1].l[1] := 4; SFBIDX[1].l[2] := 8; SFBIDX[1].l[3] := 12;
	SFBIDX[1].l[4] := 16; SFBIDX[1].l[5] := 20; SFBIDX[1].l[6] := 24; SFBIDX[1].l[7] := 30;
	SFBIDX[1].l[8] := 36; SFBIDX[1].l[9] := 42; SFBIDX[1].l[10] := 50; SFBIDX[1].l[11] := 60;
	SFBIDX[1].l[12] := 72; SFBIDX[1].l[13] := 88; SFBIDX[1].l[14] := 106; SFBIDX[1].l[15] := 128;
	SFBIDX[1].l[16] := 156; SFBIDX[1].l[17] := 190; SFBIDX[1].l[18] := 230; SFBIDX[1].l[19] := 276;
	SFBIDX[1].l[20] := 330; SFBIDX[1].l[21] := 384; SFBIDX[1].l[22] := 576;

	SFBIDX[1].s[0] := 0; SFBIDX[1].s[1] := 4; SFBIDX[1].s[2] := 8; SFBIDX[1].s[3] := 12;
	SFBIDX[1].s[4] := 16; SFBIDX[1].s[5] := 22; SFBIDX[1].s[6] := 28; SFBIDX[1].s[7] := 38;
	SFBIDX[1].s[8] := 50; SFBIDX[1].s[9] := 64; SFBIDX[1].s[10] := 80; SFBIDX[1].s[11] := 100;
	SFBIDX[1].s[12] := 126; SFBIDX[1].s[13] := 192;

	SFBIDX[2].l[0] := 0; SFBIDX[2].l[1] := 4; SFBIDX[2].l[2] := 8; SFBIDX[2].l[3] := 12;
	SFBIDX[2].l[4] := 16; SFBIDX[2].l[5] := 20; SFBIDX[2].l[6] := 24; SFBIDX[2].l[7] := 30;
	SFBIDX[2].l[8] := 36; SFBIDX[2].l[9] := 44; SFBIDX[2].l[10] := 54; SFBIDX[2].l[11] := 66;
	SFBIDX[2].l[12] := 82; SFBIDX[2].l[13] := 102; SFBIDX[2].l[14] := 126; SFBIDX[2].l[15] := 156;
	SFBIDX[2].l[16] := 194; SFBIDX[2].l[17] := 240; SFBIDX[2].l[18] := 296; SFBIDX[2].l[19] := 364;
	SFBIDX[2].l[20] := 448; SFBIDX[2].l[21] := 550; SFBIDX[2].l[22] := 576;

	SFBIDX[2].s[0] := 0; SFBIDX[2].s[1] := 4; SFBIDX[2].s[2] := 8; SFBIDX[2].s[3] := 12;
	SFBIDX[2].s[4] := 16; SFBIDX[2].s[5] := 22; SFBIDX[2].s[6] := 30; SFBIDX[2].s[7] := 42;
	SFBIDX[2].s[8] := 58; SFBIDX[2].s[9] := 78; SFBIDX[2].s[10] := 104; SFBIDX[2].s[11] := 138;
	SFBIDX[2].s[12] := 180; SFBIDX[2].s[13] := 192;

	LoadHuffmanTables();


	(* Initialize tables for dequantization *)
	PRETAB[0]:=0; PRETAB[1]:=0; PRETAB[2]:=0; PRETAB[3]:=0; PRETAB[4]:=0; PRETAB[5]:=0; PRETAB[6]:=0;
	PRETAB[7]:=0; PRETAB[8]:=0; PRETAB[9]:=0; PRETAB[10]:=0; PRETAB[11]:=1; PRETAB[12]:=1; PRETAB[13]:=1;
	PRETAB[14]:=1; PRETAB[15]:=2; PRETAB[16]:=2; PRETAB[17]:=3; PRETAB[18]:=3; PRETAB[19]:=3; PRETAB[20]:=2;
	PRETAB[21]:=0;

	ISPOW[0] := 0.0;
	FOR i:= 1 TO 8206 DO
		ISPOW[i] := Math.exp(4/3*Math.ln(i));
	END;

	LN2 := Math.ln(2);

	FOR i:= 0 TO 255 DO
		GGPOW[i] :=Math.exp( 0.25 * (i -210.0) * LN2);
	END;

	FOR i:= 0 TO 7 DO
		SGPOW[i] := Math.exp( -2.0 * i * LN2);
	END;

	FOR i:= 0 TO 1 DO
		FOR j:= 0 TO 15 DO
			SFSPOW[i][j] := Math.exp( -0.5 * (1.0 + i) * j * LN2);
		END;
	END;

	FOR i:= 0 TO 1 DO
		FOR j:= 0 TO 15 DO
			FOR k:= 0 TO 1 DO
				FOR l:= 0 TO 21 DO
					SFLPOW[i][j][k][l] := Math.exp( (-0.5 * (1.0 + i) * (j + (k*PRETAB[l]))) * LN2);
				END;
			END;
		END;
	END;

	(* Init tangens table for joint stereo processing *)

	FOR i:= 0 TO 7 DO
		STEREOTAN[i] := Math.sin(i * Math.pi /12) / Math.cos(i * Math.pi /12);
	END;

	(* Init tables used to reduce antialiasing *)

	CI[0] := -0.6; CI[1] := -0.535; CI[2] := -0.33; CI[3] := -0.185;
	CI[4] := -0.095; CI[5] := -0.041; CI[6] := -0.0142; CI[7] := -0.0037;

	FOR i := 0 TO 7 DO
		sq := Math.sqrt(1.0 + CI[i]*CI[i]);
		CS[i] := 1.0 / sq;
		CA[i] := CI[i]/sq;
	END;

	(* Init table for IMDCT *)
	FOR i:=0 TO 35 DO
		IMDCTWIN[0][i] := Math.sin(Math.pi / 36 * (i + 0.5));
	END;
		FOR i:=0 TO 17 DO
		IMDCTWIN[1][i] := Math.sin(Math.pi / 36 * (i + 0.5));
	END;
	FOR i:=18 TO 23 DO
		IMDCTWIN[1][i] := 1.0;
	END;
	FOR i:=24 TO 29 DO
		IMDCTWIN[1][i] := Math.sin(Math.pi / 12 * (i + 0.5 - 18.0));
	END;
	FOR i:=30 TO 35 DO
		IMDCTWIN[1][i] := 0.0;
	END;

	FOR i:=0 TO 11 DO
		IMDCTWIN[2][i] := Math.sin(Math.pi / 12 * (i + 0.5));
	END;
	FOR i:=12 TO 35 DO
		IMDCTWIN[2][i] := 0.0;
	END;

	FOR i:=0 TO 5 DO
		IMDCTWIN[3][i] := 0.0;
	END;
	FOR i:=6 TO 11 DO
		IMDCTWIN[3][i] := Math.sin(Math.pi / 12 * (i + 0.5 - 6.0));
	END;
	FOR i:=12 TO 17 DO
		IMDCTWIN[3][i] := 1.0;
	END;
	FOR i:=18 TO 35 DO
		IMDCTWIN[3][i] := Math.sin(Math.pi / 36 * (i + 0.5));
	END;

	FOR i:= 0 TO 2 DO
		POSTTWIDDLE6[i] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * 6))));
	END;

	FOR i:= 0 TO 3 DO
		POSTTWIDDLE9[i] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * 9))));
	END;

	FOR i:= 0 TO 5 DO
		POSTTWIDDLE12[i] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * 12))));
	END;

	FOR i:= 0 TO 8 DO
		POSTTWIDDLE18[i] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * 18))));
	END;

	FOR i:= 0 TO 17 DO
		POSTTWIDDLE36[i] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * 36))));
	END;

	FOR i:=0 TO 4 DO
		IMDCTCOS[i] := Math.cos((i * Math.pi) / 9);
	END;

	FOR i:=0 TO 3 DO
		IMDCTSIN[i] := Math.sin((2 * i + 1) * (Math.pi / 18));
	END;

	IMDCTSQRT := Math.sqrt(3) / 2;

	(* Init table for Subband Synthesis *)

	GS[0] := 0.000000000; GS[1] := -0.000015259; GS[2] := -0.000015259; GS[3] := -0.000015259;
	GS[4] := -0.000015259; GS[5] := -0.000015259; GS[6] := -0.000015259; GS[7] := -0.000030518;
	GS[8] := -0.000030518; GS[9] := -0.000030518; GS[10] := -0.000030518; GS[11] := -0.000045776;
	GS[12] := -0.000045776; GS[13] := -0.000061035; GS[14] := -0.000061035; GS[15] := -0.000076294;
	GS[16] := -0.000076294; GS[17] := -0.000091553; GS[18] := -0.000106812; GS[19] := -0.000106812;
	GS[20] := -0.000122070; GS[21] := -0.000137329; GS[22] := -0.000152588; GS[23] := -0.000167847;
	GS[24] := -0.000198364; GS[25] := -0.000213623; GS[26] := -0.000244141; GS[27] := -0.000259399;
	GS[28] := -0.000289917; GS[29] := -0.000320435; GS[30] := -0.000366211; GS[31] := -0.000396729;
	GS[32] := -0.000442505; GS[33] := -0.000473022; GS[34] := -0.000534058; GS[35] := -0.000579834;
	GS[36] := -0.000625610; GS[37] := -0.000686646; GS[38] := -0.000747681; GS[39] := -0.000808716;
	GS[40] := -0.000885010; GS[41] := -0.000961304; GS[42] := -0.001037598; GS[43] := -0.001113892;
	GS[44] := -0.001205444; GS[45] := -0.001296997; GS[46] := -0.001388550; GS[47] := -0.001480103;
	GS[48] := -0.001586914; GS[49] := -0.001693726; GS[50] := -0.001785278; GS[51] := -0.001907349;
	GS[52] := -0.002014160; GS[53] := -0.002120972; GS[54] := -0.002243042; GS[55] := -0.002349854;
	GS[56] := -0.002456665; GS[57] := -0.002578735; GS[58] := -0.002685547; GS[59] := -0.002792358;
	GS[60] := -0.002899170; GS[61] := -0.002990723; GS[62] := -0.003082275; GS[63] := -0.003173828;
	GS[64] := 0.003250122; GS[65] := 0.003326416; GS[66] := 0.003387451; GS[67] := 0.003433228;
	GS[68] := 0.003463745; GS[69] := 0.003479004; GS[70] := 0.003479004; GS[71] := 0.003463745;
	GS[72] := 0.003417969; GS[73] := 0.003372192; GS[74] := 0.003280640; GS[75] := 0.003173828;
	GS[76] := 0.003051758; GS[77] := 0.002883911; GS[78] := 0.002700806; GS[79] := 0.002487183;
	GS[80] := 0.002227783; GS[81] := 0.001937866; GS[82] := 0.001617432; GS[83] := 0.001266479;
	GS[84] := 0.000869751; GS[85] := 0.000442505; GS[86] := -0.000030518; GS[87] := -0.000549316;
	GS[88] := -0.001098633; GS[89] := -0.001693726; GS[90] := -0.002334595; GS[91] := -0.003005981;
	GS[92] := -0.003723145; GS[93] := -0.004486084; GS[94] := -0.005294800; GS[95] := -0.006118774;
	GS[96] := -0.007003784; GS[97] := -0.007919312; GS[98] := -0.008865356; GS[99] := -0.009841919;
	GS[100] := -0.010848999; GS[101] := -0.011886597; GS[102] := -0.012939453; GS[103] := -0.014022827;
	GS[104] := -0.015121460; GS[105] := -0.016235352; GS[106] := -0.017349243; GS[107] := -0.018463135;
	GS[108] := -0.019577026; GS[109] := -0.020690918; GS[110] := -0.021789551; GS[111] := -0.022857666;
	GS[112] := -0.023910522; GS[113] := -0.024932861; GS[114] := -0.025909424; GS[115] := -0.026840210;
	GS[116] := -0.027725220; GS[117] := -0.028533936; GS[118] := -0.029281616; GS[119] := -0.029937744;
	GS[120] := -0.030532837; GS[121] := -0.031005859; GS[122] := -0.031387329; GS[123] := -0.031661987;
	GS[124] := -0.031814575; GS[125] := -0.031845093; GS[126] := -0.031738281; GS[127] := -0.031478882;
	GS[128] := 0.031082153; GS[129] := 0.030517578; GS[130] := 0.029785156; GS[131] := 0.028884888;
	GS[132] := 0.027801514; GS[133] := 0.026535034; GS[134] := 0.025085449; GS[135] := 0.023422241;
	GS[136] := 0.021575928; GS[137] := 0.019531250; GS[138] := 0.017257690; GS[139] := 0.014801025;
	GS[140] := 0.012115479; GS[141] := 0.009231567; GS[142] := 0.006134033; GS[143] := 0.002822876;
	GS[144] := -0.000686646; GS[145] := -0.004394531; GS[146] := -0.008316040; GS[147] := -0.012420654;
	GS[148] := -0.016708374; GS[149] := -0.021179199; GS[150] := -0.025817871; GS[151] := -0.030609131;
	GS[152] := -0.035552979; GS[153] := -0.040634155; GS[154] := -0.045837402; GS[155] := -0.051132202;
	GS[156] := -0.056533813; GS[157] := -0.061996460; GS[158] := -0.067520142; GS[159] := -0.073059082;
	GS[160] := -0.078628540; GS[161] := -0.084182739; GS[162] := -0.089706421; GS[163] := -0.095169067;
	GS[164] := -0.100540161; GS[165] := -0.105819702; GS[166] := -0.110946655; GS[167] := -0.115921021;
	GS[168] := -0.120697021; GS[169] := -0.125259399; GS[170] := -0.129562378; GS[171] := -0.133590698;
	GS[172] := -0.137298584; GS[173] := -0.140670776; GS[174] := -0.143676758; GS[175] := -0.146255493;
	GS[176] := -0.148422241; GS[177] := -0.150115967; GS[178] := -0.151306152; GS[179] := -0.151962280;
	GS[180] := -0.152069092; GS[181] := -0.151596069; GS[182] := -0.150497437; GS[183] := -0.148773193;
	GS[184] := -0.146362305; GS[185] := -0.143264771; GS[186] := -0.139450073; GS[187] := -0.134887695;
	GS[188] := -0.129577637; GS[189] := -0.123474121; GS[190] := -0.116577148; GS[191] := -0.108856201;
	GS[192] := 0.100311279; GS[193] := 0.090927124; GS[194] := 0.080688477; GS[195] := 0.069595337;
	GS[196] := 0.057617188; GS[197] := 0.044784546; GS[198] := 0.031082153; GS[199] := 0.016510010;
	GS[200] := 0.001068115; GS[201] := -0.015228271; GS[202] := -0.032379150; GS[203] := -0.050354004;
	GS[204] := -0.069168091; GS[205] := -0.088775635; GS[206] := -0.109161377; GS[207] := -0.130310059;
	GS[208] := -0.152206421; GS[209] := -0.174789429; GS[210] := -0.198059082; GS[211] := -0.221984863;
	GS[212] := -0.246505737; GS[213] := -0.271591187; GS[214] := -0.297210693; GS[215] := -0.323318481;
	GS[216] := -0.349868774; GS[217] := -0.376800537; GS[218] := -0.404083252; GS[219] := -0.431655884;
	GS[220] := -0.459472656; GS[221] := -0.487472534; GS[222] := -0.515609741; GS[223] := -0.543823242;
	GS[224] := -0.572036743; GS[225] := -0.600219727; GS[226] := -0.628295898; GS[227] := -0.656219482;
	GS[228] := -0.683914185; GS[229] := -0.711318970; GS[230] := -0.738372803; GS[231] := -0.765029907;
	GS[232] := -0.791213989; GS[233] := -0.816864014; GS[234] := -0.841949463; GS[235] := -0.866363525;
	GS[236] := -0.890090942; GS[237] := -0.913055420; GS[238] := -0.935195923; GS[239] := -0.956481934;
	GS[240] := -0.976852417; GS[241] := -0.996246338; GS[242] := -1.014617920; GS[243] := -1.031936646;
	GS[244] := -1.048156738; GS[245] := -1.063217163; GS[246] := -1.077117920; GS[247] := -1.089782715;
	GS[248] := -1.101211548; GS[249] := -1.111373901; GS[250] := -1.120223999; GS[251] := -1.127746582;
	GS[252] := -1.133926392; GS[253] := -1.138763428; GS[254] := -1.142211914; GS[255] := -1.144287109;
	GS[256] := 1.144989014; GS[257] := 1.144287109; GS[258] := 1.142211914; GS[259] := 1.138763428;
	GS[260] := 1.133926392; GS[261] := 1.127746582; GS[262] := 1.120223999; GS[263] := 1.111373901;
	GS[264] := 1.101211548; GS[265] := 1.089782715; GS[266] := 1.077117920; GS[267] := 1.063217163;
	GS[268] := 1.048156738; GS[269] := 1.031936646; GS[270] := 1.014617920; GS[271] := 0.996246338;
	GS[272] := 0.976852417; GS[273] := 0.956481934; GS[274] := 0.935195923; GS[275] := 0.913055420;
	GS[276] := 0.890090942; GS[277] := 0.866363525; GS[278] := 0.841949463; GS[279] := 0.816864014;
	GS[280] := 0.791213989; GS[281] := 0.765029907; GS[282] := 0.738372803; GS[283] := 0.711318970;
	GS[284] := 0.683914185; GS[285] := 0.656219482; GS[286] := 0.628295898; GS[287] := 0.600219727;
	GS[288] := 0.572036743; GS[289] := 0.543823242; GS[290] := 0.515609741; GS[291] := 0.487472534;
	GS[292] := 0.459472656; GS[293] := 0.431655884; GS[294] := 0.404083252; GS[295] := 0.376800537;
	GS[296] := 0.349868774; GS[297] := 0.323318481; GS[298] := 0.297210693; GS[299] := 0.271591187;
	GS[300] := 0.246505737; GS[301] := 0.221984863; GS[302] := 0.198059082; GS[303] := 0.174789429;
	GS[304] := 0.152206421; GS[305] := 0.130310059; GS[306] := 0.109161377; GS[307] := 0.088775635;
	GS[308] := 0.069168091; GS[309] := 0.050354004; GS[310] := 0.032379150; GS[311] := 0.015228271;
	GS[312] := -0.001068115; GS[313] := -0.016510010; GS[314] := -0.031082153; GS[315] := -0.044784546;
	GS[316] := -0.057617188; GS[317] := -0.069595337; GS[318] := -0.080688477; GS[319] := -0.090927124;
	GS[320] := 0.100311279; GS[321] := 0.108856201; GS[322] := 0.116577148; GS[323] := 0.123474121;
	GS[324] := 0.129577637; GS[325] := 0.134887695; GS[326] := 0.139450073; GS[327] := 0.143264771;
	GS[328] := 0.146362305; GS[329] := 0.148773193; GS[330] := 0.150497437; GS[331] := 0.151596069;
	GS[332] := 0.152069092; GS[333] := 0.151962280; GS[334] := 0.151306152; GS[335] := 0.150115967;
	GS[336] := 0.148422241; GS[337] := 0.146255493; GS[338] := 0.143676758; GS[339] := 0.140670776;
	GS[340] := 0.137298584; GS[341] := 0.133590698; GS[342] := 0.129562378; GS[343] := 0.125259399;
	GS[344] := 0.120697021; GS[345] := 0.115921021; GS[346] := 0.110946655; GS[347] := 0.105819702;
	GS[348] := 0.100540161; GS[349] := 0.095169067; GS[350] := 0.089706421; GS[351] := 0.084182739;
	GS[352] := 0.078628540; GS[353] := 0.073059082; GS[354] := 0.067520142; GS[355] := 0.061996460;
	GS[356] := 0.056533813; GS[357] := 0.051132202; GS[358] := 0.045837402; GS[359] := 0.040634155;
	GS[360] := 0.035552979; GS[361] := 0.030609131; GS[362] := 0.025817871; GS[363] := 0.021179199;
	GS[364] := 0.016708374; GS[365] := 0.012420654; GS[366] := 0.008316040; GS[367] := 0.004394531;
	GS[368] := 0.000686646; GS[369] := -0.002822876; GS[370] := -0.006134033; GS[371] := -0.009231567;
	GS[372] := -0.012115479; GS[373] := -0.014801025; GS[374] := -0.017257690; GS[375] := -0.019531250;
	GS[376] := -0.021575928; GS[377] := -0.023422241; GS[378] := -0.025085449; GS[379] := -0.026535034;
	GS[380] := -0.027801514; GS[381] := -0.028884888; GS[382] := -0.029785156; GS[383] := -0.030517578;
	GS[384] := 0.031082153; GS[385] := 0.031478882; GS[386] := 0.031738281; GS[387] := 0.031845093;
	GS[388] := 0.031814575; GS[389] := 0.031661987; GS[390] := 0.031387329; GS[391] := 0.031005859;
	GS[392] := 0.030532837; GS[393] := 0.029937744; GS[394] := 0.029281616; GS[395] := 0.028533936;
	GS[396] := 0.027725220; GS[397] := 0.026840210; GS[398] := 0.025909424; GS[399] := 0.024932861;
	GS[400] := 0.023910522; GS[401] := 0.022857666; GS[402] := 0.021789551; GS[403] := 0.020690918;
	GS[404] := 0.019577026; GS[405] := 0.018463135; GS[406] := 0.017349243; GS[407] := 0.016235352;
	GS[408] := 0.015121460; GS[409] := 0.014022827; GS[410] := 0.012939453; GS[411] := 0.011886597;
	GS[412] := 0.010848999; GS[413] := 0.009841919; GS[414] := 0.008865356; GS[415] := 0.007919312;
	GS[416] := 0.007003784; GS[417] := 0.006118774; GS[418] := 0.005294800; GS[419] := 0.004486084;
	GS[420] := 0.003723145; GS[421] := 0.003005981; GS[422] := 0.002334595; GS[423] := 0.001693726;
	GS[424] := 0.001098633; GS[425] := 0.000549316; GS[426] := 0.000030518; GS[427] := -0.000442505;
	GS[428] := -0.000869751; GS[429] := -0.001266479; GS[430] := -0.001617432; GS[431] := -0.001937866;
	GS[432] := -0.002227783; GS[433] := -0.002487183; GS[434] := -0.002700806; GS[435] := -0.002883911;
	GS[436] := -0.003051758; GS[437] := -0.003173828; GS[438] := -0.003280640; GS[439] := -0.003372192;
	GS[440] := -0.003417969; GS[441] := -0.003463745; GS[442] := -0.003479004; GS[443] := -0.003479004;
	GS[444] := -0.003463745; GS[445] := -0.003433228; GS[446] := -0.003387451; GS[447] := -0.003326416;
	GS[448] := 0.003250122; GS[449] := 0.003173828; GS[450] := 0.003082275; GS[451] := 0.002990723;
	GS[452] := 0.002899170; GS[453] := 0.002792358; GS[454] := 0.002685547; GS[455] := 0.002578735;
	GS[456] := 0.002456665; GS[457] := 0.002349854; GS[458] := 0.002243042; GS[459] := 0.002120972;
	GS[460] := 0.002014160; GS[461] := 0.001907349; GS[462] := 0.001785278; GS[463] := 0.001693726;
	GS[464] := 0.001586914; GS[465] := 0.001480103; GS[466] := 0.001388550; GS[467] := 0.001296997;
	GS[468] := 0.001205444; GS[469] := 0.001113892; GS[470] := 0.001037598; GS[471] := 0.000961304;
	GS[472] := 0.000885010; GS[473] := 0.000808716; GS[474] := 0.000747681; GS[475] := 0.000686646;
	GS[476] := 0.000625610; GS[477] := 0.000579834; GS[478] := 0.000534058; GS[479] := 0.000473022;
	GS[480] := 0.000442505; GS[481] := 0.000396729; GS[482] := 0.000366211; GS[483] := 0.000320435;
	GS[484] := 0.000289917; GS[485] := 0.000259399; GS[486] := 0.000244141; GS[487] := 0.000213623;
	GS[488] := 0.000198364; GS[489] := 0.000167847; GS[490] := 0.000152588; GS[491] := 0.000137329;
	GS[492] := 0.000122070; GS[493] := 0.000106812; GS[494] := 0.000106812; GS[495] := 0.000091553;
	GS[496] := 0.000076294; GS[497] := 0.000076294; GS[498] := 0.000061035; GS[499] := 0.000061035;
	GS[500] := 0.000045776; GS[501] := 0.000045776; GS[502] := 0.000030518; GS[503] := 0.000030518;
	GS[504] := 0.000030518; GS[505] := 0.000030518; GS[506] := 0.000015259; GS[507] := 0.000015259;
	GS[508] := 0.000015259; GS[509] := 0.000015259; GS[510] := 0.000015259; GS[511] := 0.000015259;

	DCTCOS[0][0] := Math.cos((2 * 0 + 1) * 0 * (Math.pi/4));
	DCTCOS[0][1] := Math.cos((2 * 0 + 1) * 1* (Math.pi/4));
	DCTCOS[1][0] := Math.cos((2 * 1 + 1) * 0 * (Math.pi/4));
	DCTCOS[1][1] := Math.cos((2 * 1 + 1) * 1 * (Math.pi/4));

	FOR j:=0 TO 32 DO
		FOR i:= 0 TO 15 DO
			DCTTWIDDLE[i][j] := 1.0 / (2.0 * Math.cos((2 * i + 1) * (Math.pi / (2 * j))));
		END;
	END;

END InitTables;

PROCEDURE Factory*() : Codecs.AudioDecoder;
	VAR p: MP3Decoder;
	BEGIN
		NEW(p);
		RETURN p
	END Factory;

BEGIN
	InitTables()
END MP3Decoder.

-------------------------------------
SystemTools.Free MP3Decoder~