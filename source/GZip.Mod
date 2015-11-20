MODULE GZip;	(** DK **)

IMPORT Streams, Files, Strings, ZlibInflate, ZlibDeflate, Zlib, ZlibBuffers, Commands;

CONST
	WriteError = 2907;
	DefaultWriterSize = 4096;
	DefaultReaderSize = 4096;


	BufSize = 4000H;
	FileError  = -1;


	(** compression levels **)
	DefaultCompression* = ZlibDeflate.DefaultCompression; NoCompression* = ZlibDeflate.NoCompression;
	BestSpeed* = ZlibDeflate.BestSpeed; BestCompression* = ZlibDeflate.BestCompression;


		(** compression strategies **)
	DefaultStrategy* = ZlibDeflate.DefaultStrategy; Filtered* = ZlibDeflate.Filtered; HuffmanOnly* = ZlibDeflate.HuffmanOnly;



	DeflateMethod = 8;

	(** flush values **)
	NoFlush* = ZlibDeflate.NoFlush;
	SyncFlush* = ZlibDeflate.SyncFlush;
	FullFlush* = ZlibDeflate.FullFlush;



TYPE

	(** Reader for buffered reading of a file via Streams.Read* procedures.  See OpenReader. *)
	Deflator* = OBJECT	(** not sharable between multiple processes *)
		VAR
			writer: Streams.Writer;
			s : ZlibDeflate.Stream;
			res : LONGINT;
			crc32-: LONGINT; (*crc32 of uncompressed data*)
			out : POINTER TO ARRAY BufSize OF CHAR;
			flush: SHORTINT;
			inputsize : LONGINT;

		PROCEDURE WriteHeader(w: Streams.Writer);
		VAR
			i: INTEGER;
		BEGIN
			w.Char(1FX);
			w.Char(8BX);
			w.Char(CHR(DeflateMethod));
			FOR i := 0 TO 6 DO w.Char(0X); END;
		END WriteHeader;


		PROCEDURE &Init*(writer: Streams.Writer; level, strategy, flush: SHORTINT);
		BEGIN
			IF writer = NIL THEN
				res := Zlib.StreamError; RETURN;
			ELSE
				SELF.writer := writer;
				SELF.flush := flush;
				SELF.WriteHeader(writer);
				res := writer.res;
				IF res = Streams.Ok THEN
					ZlibDeflate.Open(s, level, strategy, FALSE);
					IF s.res = ZlibDeflate.Ok THEN
						NEW(out); ZlibBuffers.Init(s.out, out^, 0, BufSize, BufSize);
						crc32 := Zlib.CRC32(0, out^, -1, -1);
						inputsize := 0;
					ELSE
						res := s.res;
					END;
				END;
			END;
		END Init;

		PROCEDURE Send* (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR
			done : BOOLEAN;
		BEGIN
			ASSERT((0 <= ofs) & (0 <= len) & (len <= LEN(buf)), 110);
			IF ~SELF.s.open THEN
				SELF.res := Zlib.StreamError;
			ELSIF (SELF.res < ZlibDeflate.Ok) OR (len <= 0) THEN
				res := SELF.res;
			ELSE
				ZlibBuffers.Init(SELF.s.in, buf, ofs, len, len);
				INC(inputsize, len);
				WHILE (SELF.res = ZlibDeflate.Ok) & (SELF.s.in.avail # 0) DO
					IF (SELF.s.out.avail = 0) THEN
						writer.Bytes(SELF.out^, 0, BufSize);
						ZlibBuffers.Rewrite(SELF.s.out)
					END;
					IF SELF.res = Streams.Ok THEN
						ZlibDeflate.Deflate(SELF.s, SELF.flush);
						SELF.res := SELF.s.res
					END
				END;
				SELF.crc32 := Zlib.CRC32(SELF.crc32, buf, ofs, len - SELF.s.in.avail);
			END;
			res := SELF.res;
			IF propagate THEN
				ASSERT(SELF.s.in.avail = 0, 110);
				done := FALSE;
				LOOP
					len := BufSize - SELF.s.out.avail;
					IF len # 0 THEN
						writer.Bytes(SELF.out^, 0, len);
						ZlibBuffers.Rewrite(SELF.s.out)
					END;
					IF done THEN EXIT END;
					ZlibDeflate.Deflate(SELF.s, ZlibDeflate.Finish);
					IF (len = 0) & (SELF.s.res = ZlibDeflate.BufError) THEN
						SELF.res := Streams.Ok
					ELSE
						SELF.res := SELF.s.res
					END;
					done := (SELF.s.out.avail # 0) OR (SELF.res = ZlibDeflate.StreamEnd);
					IF (SELF.res # ZlibDeflate.Ok) & (SELF.res # ZlibDeflate.StreamEnd) THEN EXIT END
				END;
				ZlibDeflate.Close(SELF.s);
				SELF.res := SELF.s.res;
				writer.RawLInt(crc32);
				writer.RawLInt(inputsize);
				writer.Update();
			END;
		END Send;

	END Deflator;


	(** Reader for buffered reading of a file via Streams.Read* procedures.  See OpenReader. *)
	Inflator* = OBJECT	(** not sharable between multiple processes *)
		VAR
			reader: Streams.Reader;
			res: LONGINT;
			transparent : BOOLEAN;
			crc32-: LONGINT; (*crc32 of uncompressed data*)
			in : POINTER TO ARRAY BufSize OF CHAR;
			s: ZlibInflate.Stream;

		PROCEDURE &Init*(reader: Streams.Reader);
		BEGIN
			IF reader = NIL THEN
				res := Zlib.StreamError; RETURN;
			ELSE
				SELF.reader := reader;
				CheckHeader();
				IF (res = Streams.Ok) THEN
					ZlibInflate.Open(s, FALSE);
					IF s.res.code = ZlibInflate.Ok THEN
						NEW(in); ZlibBuffers.Init(s.in, in^,0, BufSize,0);
						crc32 := Zlib.CRC32(9, in^, -1 , -1);
					END;
				END;
			END;
		END Init;


		PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR
			intlen : LONGINT;
		BEGIN
			ASSERT((0 <= ofs) & (0 <= len) & (ofs + size <= LEN(buf)), 100);
			IF transparent THEN
				reader.Bytes(buf, ofs, size, len);
				IF len >= min THEN res := Streams.Ok ELSE res := Streams.EOF (* end of file *) END;
			ELSE
				IF ~s.open THEN
					res := Zlib.StreamError; len := 0
				ELSE
					ZlibBuffers.Init(s.out, buf, ofs, size, size);
					WHILE (s.out.avail # 0) & (s.res.code # Zlib.StreamEnd) DO
						IF s.in.avail = 0 THEN
							reader.Bytes(in^, 0, BufSize, intlen);
							ZlibBuffers.Rewind(s.in, intlen);
							IF s.in.avail = 0 THEN
								IF reader.res < 0 THEN
									res := FileError
								END
							END
						END;
						IF res = Zlib.Ok THEN
							ZlibInflate.Inflate(s, ZlibInflate.NoFlush);
						END
					END;
					crc32 := Zlib.CRC32(crc32, buf, ofs, size - s.out.avail);
					len := size - s.out.avail
				END;

			END;
			IF len >= min THEN res := Streams.Ok ELSE res := Streams.EOF (* end of file *)END;
		END Receive;

		PROCEDURE CheckHeader;
		CONST
			headCRC = 2; extraField = 4; origName = 8; comment = 10H; reserved = 20H;
		VAR
			ch, method, flags: CHAR; len: INTEGER;
		BEGIN
			ch := reader.Get();
			IF reader.res = Streams.EOF THEN
				res := Streams.EOF;
			ELSIF ch # 1FX THEN
				transparent := TRUE; res := Streams.Ok
			ELSE	(* first byte of magic id ok *)
				ch := reader.Get();
				IF (reader.res = Streams.EOF) OR (ch # 8BX)THEN
					transparent := TRUE;  res := Streams.Ok
				ELSE	(* second byte of magic id ok *)
					method := reader.Get(); flags := reader.Get();
					IF (reader.res = Streams.EOF) OR (ORD(method) # DeflateMethod) OR (ORD(flags) >= reserved) THEN
						res := Zlib.DataError
					ELSE
						FOR len := 1 TO 6 DO ch := reader.Get(); END;	(* skip time, xflags and OS code *)
						IF ODD(ORD(flags) DIV extraField) THEN	(* skip extra field *)
							ch := reader.Get(); len := ORD(ch);
							ch := reader.Get(); len := len + 100H*ORD(ch);
							WHILE (reader.res = Streams.EOF) & (len # 0) DO
								ch := reader.Get(); DEC(len)
							END
						END;
						IF ODD(ORD(flags) DIV origName) THEN	(* skip original file name *)
							REPEAT ch := reader.Get(); UNTIL (reader.res = Streams.EOF) OR (ch = 0X)
						END;
						IF ODD(ORD(flags) DIV comment) THEN	(* skip the .gz file comment *)
							REPEAT ch := reader.Get(); UNTIL (reader.res = Streams.EOF) OR (ch = 0X)
						END;
						IF ODD(ORD(flags) DIV headCRC) THEN	(* skip header crc *)
							ch := reader.Get(); ch := reader.Get();
						END;
						IF (reader.res = Streams.EOF) THEN res := Zlib.DataError
						ELSE res := Streams.Ok
						END
					END
				END
			END
		END CheckHeader;

	END Inflator;


PROCEDURE Deflate*(in,out :Files.File; level, strategy, flush: SHORTINT);
VAR
	d : Deflator;
	R: Files.Reader;
	W2 : Streams.Writer;
	W1 : Files.Writer;
	buf : ARRAY  16384 OF CHAR;
	read : LONGINT;
BEGIN
	ASSERT((in # NIL) & (out # NIL));
	Files.OpenReader(R, in, 0);

	Files.OpenWriter(W1,out,0);

	NEW(d, W1 , level, strategy, flush);
	Streams.OpenWriter(W2, d.Send);

	R.Bytes(buf, 0, LEN(buf), read);
	WHILE (read > 0) & (W2.res = Streams.Ok) DO
		W2.Bytes(buf,0, read);
		R.Bytes(buf, 0, LEN(buf), read);
	END;
	W2.Update();
END Deflate;


PROCEDURE Inflate*(in,out :Files.File);
VAR
	d : Inflator;
	R1 : Files.Reader;
	R2 : Streams.Reader;
	W : Files.Writer;
	buf : ARRAY  16384 OF CHAR;
	read : LONGINT;
BEGIN
	ASSERT((in # NIL) & (out # NIL));
	Files.OpenReader(R1, in, 0);

	NEW(d,R1);
	Streams.OpenReader(R2, d.Receive);

	Files.OpenWriter(W,out,0);
	R2.Bytes(buf, 0, LEN(buf), read);
	WHILE (read > 0) & (R2.res = Streams.Ok) DO
		W.Bytes(buf,0, read);
		R2.Bytes(buf, 0, LEN(buf), read);
	END;
	W.Update();

END Inflate;

PROCEDURE GZip*(context:Commands.Context);
VAR filename: Files.FileName; from,to: Files.File; compression, strategy: LONGINT;
BEGIN
	IF context.arg.GetString(filename) THEN
		from:=Files.Old(filename); 
		Strings.Append(filename, ".gz");
		to:=Files.New(filename);
		IF (from#NIL)&(to#NIL) THEN
			IF ~context.arg.GetInteger(compression,FALSE) THEN 
				compression:=DefaultCompression;
				strategy:=DefaultStrategy;
			ELSIF ~context.arg.GetInteger(strategy,FALSE) THEN
				strategy:=DefaultStrategy;
			END;
			Deflate(from,to,SHORTINT(compression), SHORTINT(strategy), FullFlush(*?*));
			Files.Register(to);
			context.out.String("gzipped "); context.out.String(filename);context.out.Ln; context.out.Update;	
		ELSE
			context.out.String("gzip failed for "); context.out.String(filename);context.out.Ln; context.out.Update;
		END;
	ELSE 
		context.error.String("file not found"); context.error.Ln; context.error.Update;
	END;
END GZip;

PROCEDURE UnGZip*(context:Commands.Context);
VAR filename: Files.FileName; from,to: Files.File; pos:LONGINT;
BEGIN
	IF context.arg.GetString(filename) THEN
		pos:=Strings.Pos(".gz", filename);
		IF pos<0 THEN 
			context.error.String("no .gz file found"); context.error.Ln; context.error.Update;
		ELSE
			from:=Files.Old(filename); 
			filename[pos]:=0X;
			to:=Files.New(filename);
			Inflate(from,to);
			Files.Register(to);
			context.out.String("un-gzipped "); context.out.String(filename);context.out.Ln; context.out.Update;	
		END;
	ELSE
		context.error.String("no file to UnGZip"); context.error.Ln; context.error.Update;
	END;
END UnGZip;


END GZip.

GZip.GZip "../httproot/raphael-min.js" ~
GZip.UnGZip "../httproot/raphael-min2.js.gz" ~


