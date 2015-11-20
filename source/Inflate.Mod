MODULE Inflate; (** AUTHOR "ejz"; PURPOSE "Aos inflate stream"; *)
	IMPORT SYSTEM, Streams;

	(*
		Implementation of the Inflate algorithm, as described in RFC1951.
	
	Note that due to an assymetry with RFC1950, some Deflated streams have 2 header characters that need to be dropped before applying this reader
	The zlib and deflate formats are related; the compressed data part of zlib-formatted data may be stored in the deflate format. 
	In particular, if the compression method in the zlib header is set to 8, then the compressed data is stored in the deflate format. 
	The DeflateStream implemented here represents the deflate specification (RFC 1951) but not RFC 1950. 
	So a workaround of skipping past the first 2 bytes to get to the deflate data will work for certain deflated data, e.g. in pdf stream segments. 
	
	see http://connect.microsoft.com/VisualStudio/feedback/details/97064/deflatestream-throws-exception-when-inflating-pdf-streams
	*)

	CONST
		Error = 9999; DefaultReaderSize = 4096;
		WindowSize = 32*1024;

	TYPE
		Tree = RECORD
			maxbits, len: LONGINT;
			code: POINTER TO ARRAY OF RECORD code, len: LONGINT END;
			blcount, nextcode: POINTER TO ARRAY OF LONGINT
		END;

		Window = RECORD
			data: ARRAY WindowSize OF CHAR;
			in, out, size: LONGINT
		END;

		Reader* = OBJECT (Streams.Reader)
			VAR
				input: Streams.Reader;
				bits, nbits: LONGINT;
				buffer: RECORD
					data: ARRAY DefaultReaderSize OF CHAR;
					size: LONGINT
				END;
				eof: BOOLEAN;

			PROCEDURE Receive*(VAR data: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
				VAR n: LONGINT;
			BEGIN
				len := 0;
				WHILE len < min DO
					BEGIN {EXCLUSIVE}
						AWAIT((buffer.size > 0) OR eof OR (SELF.res # Streams.Ok));
						IF buffer.size > 0 THEN
							n := buffer.size; IF n > size THEN n := size END;
							SYSTEM.MOVE(ADDRESSOF(buffer.data[0]), ADDRESSOF(data[ofs]), n);
							INC(len, n); DEC(buffer.size, n);
							IF buffer.size > 0 THEN
								SYSTEM.MOVE(ADDRESSOF(buffer.data[n]), ADDRESSOF(buffer.data[0]), buffer.size)
							END
						ELSE
							IF SELF.res # Streams.Ok THEN
								res := SELF.res
							ELSE
								res := Streams.EOF; SELF.res := Streams.EOF
							END;
							RETURN
						END
					END
				END;
				res := Streams.Ok
			END Receive;

			PROCEDURE &Init*(input: Streams.Reader);
			BEGIN
				SELF.input := input; bits := 0; nbits := 0; eof := FALSE;
				buffer.size := 0;
				res := Streams.Ok; InitReader(SELF.Receive, DefaultReaderSize);
			END Init;

			PROCEDURE ReadBits(nbits: LONGINT; VAR bits: LONGINT);
				VAR ch: CHAR;
			BEGIN
				WHILE SELF.nbits < nbits DO
					input.Char(ch);
					INC(SELF.bits, ASH(ORD(ch), SELF.nbits));
					INC(SELF.nbits, 8)
				END;
				bits := SELF.bits;
				SELF.bits := ASH(SELF.bits, -nbits); DEC(SELF.nbits, nbits)
			END ReadBits;

			PROCEDURE SwapBits(VAR bits: LONGINT; n: LONGINT);
				VAR x, y: LONGINT;
			BEGIN
				x := 0; y := bits;
				WHILE n > 0 DO
					x := 2*x + y MOD 2;
					y := y DIV 2;
					DEC(n)
				END;
				bits := x
			END SwapBits;

			PROCEDURE BuildTree(VAR T: Tree; VAR ncode: ARRAY OF LONGINT; ncodes, maxbits: LONGINT);
				VAR code, len, n, i, j, x: LONGINT;
			BEGIN
				ASSERT(maxbits <= 16);
				T.maxbits := maxbits;
				IF (T.blcount = NIL) OR (LEN(T.blcount) <= maxbits) THEN
					NEW(T.blcount, maxbits+1)
				END;
				IF (T.nextcode = NIL) OR (LEN(T.nextcode) <= maxbits) THEN
					NEW(T.nextcode, maxbits+1)
				END;
				n := ASH(1, maxbits); T.len := n;
				IF (T.code = NIL) OR (LEN(T.code) < n) THEN
					NEW(T.code, n)
				END;
				i := 0;
				WHILE i <= maxbits DO
					T.blcount[i] := 0; INC(i)
				END;
				i := 0;
				WHILE i < ncodes DO
					INC(T.blcount[ncode[i]]); INC(i)
				END;
				T.nextcode[0] := 0; T.blcount[0] := 0;
				code := 0; i := 1;
				WHILE i <= maxbits DO
					code := (code + T.blcount[i-1])*2;
					T.nextcode[i] := code; INC(i)
				END;
				i := 0;
				WHILE i < ncodes DO
					len := ncode[i];
					IF len > 0 THEN
						code := T.nextcode[len];
						IF len < maxbits THEN
							n := maxbits-len; code := ASH(code, n);
							n := ASH(1, n); j := 0;
							WHILE j < n DO
								x := code; SwapBits(x, maxbits);
								T.code[x].code := i; T.code[x].len := len;
								INC(j); INC(code)
							END
						ELSE
							x := code; SwapBits(x, maxbits);
							T.code[x].code := i; T.code[x].len := maxbits
						END;
						INC(T.nextcode[len])
					END;
					INC(i)
				END
			END BuildTree;

			PROCEDURE ReadCode(VAR T: Tree; VAR code: LONGINT);
				VAR bits, i, l, n: LONGINT;
			BEGIN
				ReadBits(T.maxbits, bits); i := bits MOD T.len;
				code := T.code[i].code; l := T.code[i].len; n := T.maxbits-l;
				IF n > 0 THEN
					SELF.bits := ASH(SELF.bits, n) + ASH(i, -l); INC(SELF.nbits, n)
				END
			END ReadCode;

			PROCEDURE DynamicHuffman(VAR Temp,litT, distT: Tree);
				VAR
					bits, hlit, hdist, hclen, i, j, n, max: LONGINT;
					clen: ARRAY 286+32 OF LONGINT; lit: ARRAY 286 OF LONGINT; dist: ARRAY 32 OF LONGINT;
			BEGIN
				ReadBits(5, bits); hlit := 257 + bits MOD 32;
				ASSERT((hlit >= 257) & (hlit <= 286));
				ReadBits(5, bits); hdist := 1 + bits MOD 32;
				ASSERT((hdist >= 1) & (hdist <= 32));
				ReadBits(4, bits); hclen := 4 + bits MOD 16;
				ASSERT((hclen >= 4) & (hclen <= 19));
				i := 0;
				WHILE i < hclen DO
					ReadBits(3, bits); clen[clenTab[i]] := bits MOD 8; INC(i)
				END;
				WHILE i < 19 DO
					clen[clenTab[i]] := 0; INC(i)
				END;
				BuildTree(Temp, clen, 19, 7);
				i := 0;
				WHILE i < (hlit+hdist) DO
					ReadCode(Temp, bits);
					CASE bits OF
						16: ReadBits(2, bits); n := 3 + (bits MOD 4); bits := clen[i-1];
								WHILE n > 0 DO
									clen[i] := bits; INC(i); DEC(n)
								END
						|17: ReadBits(3, bits);  n := 3 + (bits MOD 8);
								WHILE n > 0 DO
									clen[i] := 0; INC(i); DEC(n)
								END
						|18: ReadBits(7, bits); n := 11 + (bits MOD 128);
								WHILE n > 0 DO
									clen[i] := 0; INC(i); DEC(n)
								END
					ELSE
						clen[i] := bits; INC(i)
					END
				END;
				ASSERT(i = (hlit+hdist));
				i := 0; max := 0;
				WHILE i < hlit DO
					n := clen[i]; IF n > max THEN max := n END;
					lit[i] := n; INC(i)
				END;
				WHILE i < 286 DO
					lit[i] := 0; INC(i)
				END;
				BuildTree(litT, lit, 286, max);
				i := 0; j := hlit; max := 0;
				WHILE i < hdist DO
					n := clen[j]; IF n > max THEN max := n END;
					dist[i] := n; INC(i); INC(j)
				END;
				WHILE i < 32 DO
					dist[i] := 0; INC(i)
				END;
				BuildTree(distT, dist, 32, max)
			END DynamicHuffman;

			PROCEDURE FixedHuffman(VAR litT, distT: Tree);
				VAR i: LONGINT; clen: ARRAY 288 OF LONGINT;
			BEGIN
				i := 0;
				WHILE i <= 143 DO
					clen[i] := 8; INC(i)
				END;
				WHILE i <= 255 DO
					clen[i] := 9; INC(i)
				END;
				WHILE i <= 279 DO
					clen[i] := 7; INC(i)
				END;
				WHILE i <= 287 DO
					clen[i] := 8; INC(i)
				END;
				BuildTree(litT, clen, 288, 9);
				i := 0;
				WHILE i < 32 DO
					clen[i] := 5; INC(i)
				END;
				BuildTree(distT, clen, 32, 5)
			END FixedHuffman;

			PROCEDURE CopyData(VAR win: Window);
				VAR n, m: LONGINT;
			BEGIN {EXCLUSIVE}
				AWAIT(buffer.size = 0);
				n := win.size; IF n > DefaultReaderSize THEN n := DefaultReaderSize END;
				IF win.out < win.in THEN
					SYSTEM.MOVE(ADDRESSOF(win.data[win.out]), ADDRESSOF(buffer.data[0]), n)
				ELSE
					m := WindowSize-win.out;
					IF m >= n THEN
						SYSTEM.MOVE(ADDRESSOF(win.data[win.out]), ADDRESSOF(buffer.data[0]), n)
					ELSE
						SYSTEM.MOVE(ADDRESSOF(win.data[win.out]), ADDRESSOF(buffer.data[0]), m);
						SYSTEM.MOVE(ADDRESSOF(win.data[0]), ADDRESSOF(buffer.data[m]), n-m)
					END
				END;
				win.out := (win.out+n) MOD WindowSize; DEC(win.size, n); buffer.size := n
			END CopyData;

			PROCEDURE Inflate;
				VAR win: POINTER TO Window; litT, distT,temp: Tree; bits, i, d, l: LONGINT; final: BOOLEAN;
			BEGIN
				NEW(win);
				win.in := 0; win.out := 0; win.size := 0;
				REPEAT
					ReadBits(1, bits); final := (bits MOD 2) # 0;
					ReadBits(2, bits); bits := bits MOD 4;
					IF bits = 0 THEN (* uncompressed *)
						IF nbits < 8 THEN
							nbits := 0
						ELSE
							ReadBits(nbits MOD 8, bits)
						END;
						ReadBits(16, bits); l := bits MOD ASH(1, 16);
						ReadBits(16, bits); i := bits MOD ASH(1, 16);
						ASSERT((nbits = 0) & (i = (-l-1) MOD ASH(1, 16)));
						WHILE l > 0 DO
							IF (win.in+l) > WindowSize THEN
								i := WindowSize-win.in
							ELSE
								i := l
							END;
							WHILE win.size > (WindowSize-i) DO
								CopyData(win^)
							END;
							input.Bytes(win.data, win.in, i, i);
							DEC(l, i); INC(win.size, i);
							win.in := (win.in + i) MOD WindowSize
						END
					ELSIF bits < 3 THEN (* compressed *)
						IF bits = 2 THEN
							DynamicHuffman(temp,litT, distT)
						ELSE
							FixedHuffman(litT, distT)
						END;
						ReadCode(litT, l);
						WHILE l # 256 DO
							IF l < 256 THEN
								WHILE win.size > (WindowSize-1) DO
									CopyData(win^)
								END;
								win.data[win.in] := CHR(l); INC(win.size);
								win.in := (win.in + 1) MOD WindowSize
							ELSE
								DEC(l, 257);
								i := lenTab[l].extra; l := lenTab[l].base;
								IF i > 0 THEN
									ReadBits(i, bits); INC(l, bits MOD ASH(1, i))
								END;
								ReadCode(distT, d);
								i := distTab[d].extra; d := distTab[d].base;
								IF i > 0 THEN
									ReadBits(i, bits); INC(d, bits MOD ASH(1, i))
								END;
								WHILE win.size > (WindowSize-l) DO
									CopyData(win^)
								END;
								i := (win.in-d) MOD WindowSize;
								WHILE l > 0 DO
									win.data[win.in] := win.data[i];
									i := (i + 1) MOD WindowSize;
									win.in := (win.in + 1) MOD WindowSize;
									DEC(l); INC(win.size)
								END
							END;
							ReadCode(litT, l)
						END
					ELSE
						BEGIN {EXCLUSIVE} SELF.res := Error; RETURN END
					END
				UNTIL final OR (input.res # Streams.Ok);
				WHILE win.size > 0 DO CopyData(win^) END;
				BEGIN {EXCLUSIVE}
					SELF.eof := TRUE;
					IF ~final & (SELF.res = Streams.Ok) THEN
						SELF.res := input.res
					END
				END
			END Inflate;

		BEGIN {ACTIVE}
			Inflate()
		END Reader;

	VAR
		clenTab: ARRAY 19 OF LONGINT;
		lenTab: ARRAY 285-257+1 OF RECORD base, extra: LONGINT END;
		distTab: ARRAY 29-0+1 OF RECORD base, extra: LONGINT END;

	PROCEDURE OpenReader*(VAR R: Reader; input: Streams.Reader);
	BEGIN
		NEW(R, input)
	END OpenReader;

	PROCEDURE Init;
	BEGIN
		clenTab[0] := 16; clenTab[1] := 17; clenTab[2] := 18; clenTab[3] := 0;
		clenTab[4] := 8; clenTab[5] := 7; clenTab[6] := 9; clenTab[7] := 6;
		clenTab[8] := 10; clenTab[9] := 5; clenTab[10] := 11; clenTab[11] := 4;
		clenTab[12] := 12; clenTab[13] := 3; clenTab[14] := 13; clenTab[15] := 2;
		clenTab[16] := 14; clenTab[17] := 1; clenTab[18] := 15;

		lenTab[0].base := 3; lenTab[0].extra := 0; lenTab[1].base := 4; lenTab[1].extra := 0;
		lenTab[2].base := 5; lenTab[2].extra := 0; lenTab[3].base := 6; lenTab[3].extra := 0;
		lenTab[4].base := 7; lenTab[4].extra := 0; lenTab[5].base := 8; lenTab[5].extra := 0;
		lenTab[6].base := 9; lenTab[6].extra := 0; lenTab[7].base := 10; lenTab[7].extra := 0;
		lenTab[8].base := 11; lenTab[8].extra := 1; lenTab[9].base := 13; lenTab[9].extra := 1;
		lenTab[10].base := 15; lenTab[10].extra := 1; lenTab[11].base := 17; lenTab[11].extra := 1;
		lenTab[12].base := 19; lenTab[12].extra := 2; lenTab[13].base := 23; lenTab[13].extra := 2;
		lenTab[14].base := 27; lenTab[14].extra := 2; lenTab[15].base := 31; lenTab[15].extra := 2;
		lenTab[16].base := 35; lenTab[16].extra := 3; lenTab[17].base := 43; lenTab[17].extra := 3;
		lenTab[18].base := 51; lenTab[18].extra := 3; lenTab[19].base := 59; lenTab[19].extra := 3;
		lenTab[20].base := 67; lenTab[20].extra := 4; lenTab[21].base := 83; lenTab[21].extra := 4;
		lenTab[22].base := 99; lenTab[22].extra := 4; lenTab[23].base := 115; lenTab[23].extra := 4;
		lenTab[24].base := 131; lenTab[24].extra := 5; lenTab[25].base := 163; lenTab[25].extra := 5;
		lenTab[26].base := 195; lenTab[26].extra := 5; lenTab[27].base := 227; lenTab[27].extra := 5;
		lenTab[28].base := 258; lenTab[28].extra := 0;

		distTab[0].base := 1; distTab[0].extra := 0; distTab[1].base := 2; distTab[1].extra := 0;
		distTab[2].base := 3; distTab[2].extra := 0; distTab[3].base := 4; distTab[3].extra := 0;
		distTab[4].base := 5; distTab[4].extra := 1; distTab[5].base := 7; distTab[5].extra := 1;
		distTab[6].base := 9; distTab[6].extra := 2; distTab[7].base := 13; distTab[7].extra := 2;
		distTab[8].base := 17; distTab[8].extra := 3; distTab[9].base := 25; distTab[9].extra := 3;
		distTab[10].base := 33; distTab[10].extra := 4; distTab[11].base := 49; distTab[11].extra := 4;
		distTab[12].base := 65; distTab[12].extra := 5; distTab[13].base := 97; distTab[13].extra := 5;
		distTab[14].base := 129; distTab[14].extra := 6; distTab[15].base := 193; distTab[15].extra := 6;
		distTab[16].base := 257; distTab[16].extra := 7; distTab[17].base := 385; distTab[17].extra := 7;
		distTab[18].base := 513; distTab[18].extra := 8; distTab[19].base := 769; distTab[19].extra := 8;
		distTab[20].base := 1025; distTab[20].extra := 9; distTab[21].base := 1537; distTab[21].extra := 9;
		distTab[22].base := 2049; distTab[22].extra := 10; distTab[23].base := 3073; distTab[23].extra := 10;
		distTab[24].base := 4097; distTab[24].extra := 11; distTab[25].base := 6145; distTab[25].extra := 11;
		distTab[26].base := 8193; distTab[26].extra := 12; distTab[27].base := 12289; distTab[27].extra := 12;
		distTab[28].base := 16385; distTab[28].extra := 13; distTab[29].base := 24577; distTab[29].extra := 13
	END Init;

BEGIN
	Init()
END Inflate.
