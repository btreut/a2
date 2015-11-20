MODULE OpenTypeFonts; (** AUTHOR "eos, PL"; PURPOSE "Bluebottle port of OpenType"; *)

	(**
		Make OpenType fonts available to Oberon System
	**)

	(*
		18.11.1999 - portability fix for big_endian architectures in FillRect (pjm)
		10.12.1999 - assert valid memory access in FillRect (eos)
	*)

	IMPORT
		SYSTEM, Strings, OTInt := OpenTypeInt, OType := OpenType, OpenTypeScan, Files, KernelLog, Commands;

	CONST
		ScreenDPI = 71;
		FontId = 0DBX;
		FontFont = 0;
		FontMetric = 1;


	TYPE
		RasterData* = RECORD (OType.RasterData)
			adr*: ADDRESS;							(* base address of pattern *)
			bpr*: LONGINT;									(* number of bytes per row *)
			len*: LONGINT;									(* pattern length *)
		END;

		Char* = POINTER TO CharDesc;
		CharDesc* = RECORD								(** The objects in a font library. *)	(* Note: offset used in GetCharObj *)
			dx*, x*, y*, w*, h*: INTEGER;					(** Character width, pattern offset (x, y), pattern size (w, h). *)
			pat*: LONGINT									(** Character raster data. *)
		END;

	VAR
		Pattern: ARRAY 360*360 DIV 8 OF CHAR;				(* enough for 36 point at 720 dpi *)
		Glyph: OType.Glyph;
		Char2: Char;


	(* fill rectangle in pattern *)
	PROCEDURE FillRect*(llx, lly, urx, ury, opacity: INTEGER; VAR data: OType.RasterData0);
		VAR x0, x1, h, n: INTEGER; adr, a: ADDRESS; mask: SET; byte: CHAR;
	BEGIN
		WITH data: RasterData DO
			x0 := llx DIV 8; x1 := urx DIV 8;
			adr := data.adr + data.bpr * lly + x0;
			h := ury - lly;
			IF x0 = x1 THEN
				mask := {(llx MOD 8) .. ((urx-1) MOD 8)}
			ELSE
				mask := {(llx MOD 8) .. 7}
			END;
			n := h; a := adr;
			WHILE n > 0 DO
				ASSERT((data.adr <= a) & (a < data.adr + data.len), 110);
				SYSTEM.GET(a, byte);
				SYSTEM.PUT(a, CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(ORD(byte))) + mask)));
				DEC(n); INC(a, data.bpr)
			END;
			IF x0 < x1 THEN
				INC(x0); INC(adr);
				WHILE x0 < x1 DO
					n := h; a := adr;
					WHILE n > 0 DO
						ASSERT((data.adr <= a) & (a < data.adr + data.len), 111);
						SYSTEM.PUT(a, 0FFX);
						DEC(n); INC(a, data.bpr)
					END;
					INC(x0); INC(adr)
				END;
				IF 8*x1 # urx THEN
					mask := {0 .. (urx-1) MOD 8};
					n := h; a := adr;
					WHILE n > 0 DO
						ASSERT((data.adr <= a) & (a < data.adr + data.len), 112);
						SYSTEM.GET(a, byte);
						SYSTEM.PUT(a, CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(ORD(byte))) + mask)));
						DEC(n); INC(a, data.bpr)
					END
				END
			END
		END
	END FillRect;

	PROCEDURE MakeFont (inst: OType.Instance; name: ARRAY OF CHAR);
		CONST
			mode = {OType.Hinted, OType.Width, OType.Raster};
		VAR
			file: Files.File; r, m: Files.Rider; font: OType.Font; i, chars, ranges, xmin, ymin, xmax, ymax, j: INTEGER;
			beg, end: ARRAY 64 OF INTEGER; data: RasterData; no, bytes, k: LONGINT;
 			ras: OpenTypeScan.Rasterizer;
	BEGIN
		file := Files.New(name);
		ASSERT(file # NIL);
		file.Set(r, 0);
		file.Write(r, FontId);																	(* Id *)
		file.Write(r, 0X);																		(* type (metric/font) *)
		file.Write(r, 0X);																		(* family *)
		file.Write(r, 0X);																		(* variant *)
		i := inst.font.hhea.ascender + inst.font.hhea.descender + inst.font.hhea.lineGap;
		Files.WriteInt(r, SHORT(OTInt.MulDiv(i, inst.yppm, 40H*LONG(inst.font.head.unitsPerEm))));	(* height *)
		Files.WriteInt(r, 0); Files.WriteInt(r, 0); Files.WriteInt(r, 0); Files.WriteInt(r, 0);	(* fix later *) (* min/max X/Y *)

		font := inst.font;
		i := 0; chars := 0; ranges := 0;
		IF OType.UnicodeToGlyph(font, OType.CharToUnicode[1]) = 0 THEN
			i := 2; chars := 1; beg[0] := 0; end[0] := 1; ranges := 1								(* make range for 0X *)
		END;
		REPEAT
			WHILE (i < 256) & (i # 9) & (OType.UnicodeToGlyph(font, OType.CharToUnicode[i]) = 0) DO INC(i) END;
			IF i < 256 THEN
				beg[ranges] := i; INC(i); INC(chars);
				WHILE (i < 256) & (OType.UnicodeToGlyph(font, OType.CharToUnicode[i]) # 0) DO INC(i); INC(chars) END;
				end[ranges] := i; INC(ranges)
			END
		UNTIL i = 256;
		Files.WriteInt(r, ranges);															(* number of runs *)
		i := 0;
		WHILE i < ranges DO
			Files.WriteInt(r, beg[i]); Files.WriteInt(r, end[i]);								(* start/end of run *)
			INC(i)
		END;

		file.Set(m, file.Pos(r));																(* open rider for later writing metrics *)
		i := 0;
		WHILE i < chars DO
			Files.WriteInt(r, 0); Files.WriteInt(r, 0); Files.WriteInt(r, 0); Files.WriteInt(r, 0); Files.WriteInt(r, 0);
			INC(i)
		END;

		xmin := MAX(INTEGER); ymin := MAX(INTEGER); xmax := MIN(INTEGER); ymax := MIN(INTEGER);
		i := 0;
		WHILE i < ranges DO
			j := beg[i];
			WHILE j < end[i] DO
				no := OType.UnicodeToGlyph(font, OType.CharToUnicode[j]);
				IF (j = 9) & (no = 0) THEN
					no := OType.UnicodeToGlyph(font, OType.CharToUnicode[ORD("I")]);
					OType.LoadGlyph(inst, Glyph, ras, SHORT(no), {OType.Hinted, OType.Width});
					Glyph.awx := 8*Glyph.awx;
					Glyph.hbx := 0; Glyph.hby := 0; Glyph.rw := 0; Glyph.rh := 0
				ELSE
					OType.LoadGlyph(inst, Glyph, ras, SHORT(no), mode)
				END;
				Files.WriteInt(m, Glyph.awx);												(* advance *)
				Files.WriteInt(m, Glyph.hbx);												(* horizontal bearing x *)
				Files.WriteInt(m, Glyph.hby);												(* horizontal bearing y *)
				Files.WriteInt(m, Glyph.rw);												(* image width *)
				Files.WriteInt(m, Glyph.rh);													(* image height *)
				IF Glyph.rw * Glyph.rh # 0 THEN
					IF Glyph.hbx < xmin THEN xmin := Glyph.hbx END;
					IF Glyph.hby < ymin THEN ymin := Glyph.hby END;
					IF Glyph.hbx + Glyph.rw > xmax THEN xmax := Glyph.hbx + Glyph.rw END;
					IF Glyph.hby + Glyph.rh > ymax THEN ymax := Glyph.hby + Glyph.rh END;
					data.rect := FillRect; data.adr := ADDRESSOF(Pattern); data.bpr := (Glyph.rw+7) DIV 8; data.len := LEN(Pattern);
					bytes := Glyph.rh * data.bpr;
					ASSERT(bytes < LEN(Pattern));
					k := 0; REPEAT Pattern[k] := 0X; INC(k) UNTIL k = bytes;
					OType.EnumRaster(ras, data);
					k := 0; REPEAT r.file.Write(r, Pattern[k]); INC(k) UNTIL k = bytes			(* pattern *)
				END;
				INC(j)
			END;
			INC(i)
		END;

		file.Set(r, 6);
		Files.WriteInt(r, xmin); Files.WriteInt(r, xmax);										(* minX/maxX *)
		Files.WriteInt(r, ymin); Files.WriteInt(r, ymax);										(* minY/maxY *)
		Files.Register(file)
	END MakeFont;

	(**
		command for creating Oberon raster font files from an OpenType font file
		syntax:
			file - name of OpenType font file (e.g. "Arialb.TTF")
			font - Oberon name (e.g. "Arial")
			[style] - optional style character for Oberon name (e.g. "b")
			{size} - list of point sizes (e.g. "8 10 12 14 16 20 24")
			{dev} - list of device specifiers (e.g. "Scn Pr2 Pr3 Pr6")
	**)
	PROCEDURE Make*(context : Commands.Context);
	VAR
		temp : ARRAY 256 OF CHAR; tempInt : LONGINT;
		font: OType.Font; name, fname, str: ARRAY 32 OF CHAR; style: ARRAY 3 OF CHAR; sizes, i: LONGINT;
		size: ARRAY 16 OF LONGINT; res: INTEGER; inst: OType.Instance;
	BEGIN
		context.arg.SkipWhitespace; context.arg.String(name);
		context.out.String(name); context.out.Ln;

		font := OType.Open(name);
		IF font # NIL THEN
			OType.InitGlyph(Glyph, font);

				context.arg.SkipWhitespace(); context.arg.Token(name);
				context.arg.SkipWhitespace(); context.arg.Token(temp);
				IF ((Strings.Length(temp) = 1)
				   OR (Strings.Length(temp) = 2))&
				   ~IsNumber(temp) THEN
					COPY(temp, style);
					context.arg.SkipWhitespace(); context.arg.Token(temp);
				ELSE
					style[0] := 0X;
				END;

				sizes := 0;
				WHILE IsNumber(temp) DO
					ASSERT(sizes < LEN(size));
					Strings.StrToInt(temp, tempInt);
					size[sizes] := tempInt; INC(sizes);
					context.arg.SkipWhitespace(); context.arg.Token(temp);
				END;

				IF temp = "Scn" THEN res := ScreenDPI
				ELSIF temp = "Pr2" THEN res := 200
				ELSIF temp = "Pr3" THEN res := 300
				ELSIF temp = "Pr6" THEN res := 600
				ELSE res := 0
				END;
				IF res # 0 THEN
					FOR i := 0 TO sizes-1 DO
						COPY(name, fname);
						Strings.IntToStr(size[i], str);
						Strings.Append(fname, str);
						IF style # "" THEN Strings.Append(fname, style) END;
						Strings.Append(fname, "."); Strings.Append(fname, temp); Strings.Append(fname, ".Fnt");
						OType.GetInstance(font, 40H*size[i], res, res, OType.Identity, inst);
						KernelLog.String(fname); KernelLog.Ln;
						MakeFont(inst, fname);
					END
				END;

		END;
	END Make;

	PROCEDURE IsNumber(str : ARRAY OF CHAR): BOOLEAN;
	VAR i : LONGINT;
	BEGIN
		Strings.StrToInt(str, i);
		IF i # 0 THEN RETURN TRUE ELSE RETURN FALSE END
	END IsNumber;

BEGIN
	NEW(Glyph);
	NEW(Char2);
END OpenTypeFonts.

----------------------------------------------------------

SystemTools.Free OpenTypeFonts OpenType~
OpenTypeFonts.Make schweif.ttf Schweif 12 14 16 18 Scn ~

OpenTypeFonts.Install~
