MODULE WMOberonFonts;	 (** AUTHOR "TF"; PURPOSE "Support for oberon bitmap fonts"; *)

IMPORT
	KernelLog, Streams, Files, WMGraphics, Raster, WMFontManager, Strings;

CONST TraceImport = FALSE;

TYPE
	Glyph = RECORD
		img : WMGraphics.Image;
		available : BOOLEAN;
		dx, x, y, w, h : LONGINT;
	END;

	Font* = OBJECT(WMGraphics.Font)
	VAR glyphs : ARRAY 256 OF Glyph;
		placeholderimg : WMGraphics.Image;

		idch, typech, famch, varch : CHAR;
		height, minX, maxX, minY, maxY, nofRuns : INTEGER;

		runs : ARRAY 32 OF RECORD beg, end : LONGINT END;

		(* map unicode to oberon *)
		PROCEDURE MapChars(VAR ch : LONGINT);
		BEGIN

			CASE ch OF
				0C4H :	 ch := 128;
			|	0D6H :	 ch := 129;
			|	0DCH :	 ch := 130;
			|	0E4H :	 ch := 131;
			|	0F6H :	 ch := 132;
			|	0FCH :	 ch := 133;
			|	0E2H :	 ch := 134;
			|	0EAH :	 ch := 135;
			|	0EEH :	 ch := 136;
			|	0F4H :	 ch := 137;
			|	0FBH :	 ch := 138;
			|	0E0H :	 ch := 139;
			|	0E8H :	 ch := 140;
			|	0ECH :	 ch := 141;
			|	0F2H :	 ch := 142;
			|	0F9H :	 ch := 143;
			|	0E9H :	 ch := 144;
			|	0EBH :	 ch := 145;
			|	0EFH :	 ch := 146;
			|	0E7H :	 ch := 147;
			|	0E1H :	 ch := 148;
			|	0F1H :	 ch := 149;
			|	0DFH :	 ch := 150;
			|	0A3H :	 ch := 151;
			|	0B6H :	 ch := 152;
			|	0C7H :	 ch := 153;
			ELSE
				IF ch = 2030H THEN ch := 154
				ELSIF ch = 2013H THEN ch := 155
				END
			END;

		END MapChars;

		PROCEDURE &Init*;
		VAR mode : Raster.Mode; pix : Raster.Pixel;
		BEGIN
			Init^;
			NEW(placeholderimg); Raster.Create(placeholderimg, 16, 16, Raster.A1);
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.SetRGBA(pix, 0, 0, 0, 0);
			Raster.Fill(placeholderimg, 0, 0, 15, 15, pix, mode)
		END Init;

		PROCEDURE GetGlyphMap*(code : LONGINT; VAR map : WMGraphics.Image);
		BEGIN
			MapChars(code);
			IF (code >= 0) & (code < 256) & (glyphs[code].available) & (glyphs[code].img # NIL) THEN
				map := glyphs[code].img
			ELSE map := placeholderimg
			END
		END GetGlyphMap;

		PROCEDURE HasChar*(code : LONGINT) : BOOLEAN;
		BEGIN
			MapChars(code);
			RETURN (code >= 0) & (code < 256) & (glyphs[code].available)
		END HasChar;

		PROCEDURE GetGlyphSpacings*(code : LONGINT; VAR glyphSpacings : WMGraphics.GlyphSpacings);
		BEGIN
			MapChars(code);
			IF (code >= 0) & (code < 256) & (glyphs[code].available) (* & (glyphs[code].img # NIL) *) THEN
				glyphSpacings.width := glyphs[code].w;
				glyphSpacings.ascent := ascent; glyphSpacings.descent := descent;
				glyphSpacings.bearing.l := glyphs[code].x;
				glyphSpacings.bearing.r := glyphs[code].dx - (glyphs[code].w + glyphs[code].x);

				glyphSpacings.height := glyphs[code].h;
				glyphSpacings.dy := ascent - glyphs[code].h - glyphs[code].y

			ELSE glyphSpacings.width := 5; glyphSpacings.height := 15; glyphSpacings.ascent := 16;
			END
		END GetGlyphSpacings;
	END Font;

VAR
	bit: ARRAY 100H, 8 OF BOOLEAN;	(* Bit[b, i] means bit i in byte b is set *)


PROCEDURE LoadFont*(name : ARRAY OF CHAR) : Font;
VAR r : Files.Reader;  f : Files.File;
BEGIN
	f := Files.Old(name);
	IF f = NIL THEN RETURN NIL END;
	Files.OpenReader(r, f, 0);
	RETURN StreamLoad(r)
END LoadFont;

PROCEDURE StreamLoad(r : Streams.Reader) : Font;
VAR
	font : Font;
	ch : CHAR;
	minY, maxY, t, rbeg, rend : INTEGER;
	nofGlyphs, i, j, run, bits, b, pos, xw : LONGINT;
	p1 : Raster.Pixel;
	mode : Raster.Mode;
	mem: POINTER TO ARRAY OF CHAR;
	img: WMGraphics.Image;
	w,h: LONGINT;
	adr: LONGINT;
CONST
	MemoryOptimization = TRUE;
BEGIN
	Raster.SetRGBA(p1, 255, 0, 0, 255);
	Raster.InitMode(mode, Raster.srcCopy);

	NEW(font);
	r.Char(font.idch); (* id *)
	r.Char(font.typech); (* metric or font *)
	r.Char(font.famch); (* family *)
	r.Char(font.varch); (* variant *)
	r.RawInt(font.height);
	r.RawInt(font.minX);
	r.RawInt(font.maxX);
	r.RawInt(minY); font.descent := -minY;
	r.RawInt(maxY); font.ascent := maxY;
	r.RawInt(font.nofRuns);
	IF TraceImport THEN
		KernelLog.String("id :"); KernelLog.Int(ORD(font.idch), 4); KernelLog.Ln;
		KernelLog.String("type :"); KernelLog.Int(ORD(font.typech), 4); KernelLog.Ln;
		KernelLog.String("family :"); KernelLog.Int(ORD(font.famch), 4); KernelLog.Ln;
		KernelLog.String("variant :"); KernelLog.Int(ORD(font.varch), 4); KernelLog.Ln;
		KernelLog.String("height :"); KernelLog.Int(font.height, 4); KernelLog.Ln;
		KernelLog.String("minX :"); KernelLog.Int(font.minX, 4); KernelLog.Ln;
		KernelLog.String("maxX :"); KernelLog.Int(font.ascent, 4); KernelLog.Ln;
		KernelLog.String("minY :"); KernelLog.Int(minY, 4); KernelLog.Ln;
		KernelLog.String("maxY :"); KernelLog.Int(font.maxY, 4); KernelLog.Ln;
		KernelLog.String("nofRuns :"); KernelLog.Int(font.nofRuns, 4); KernelLog.Ln;
	END;

	nofGlyphs := 0; i := 0;
	WHILE i < font.nofRuns DO
		r.RawInt(rbeg); font.runs[i].beg := rbeg;
		r.RawInt(rend); font.runs[i].end := rend;
		nofGlyphs := nofGlyphs + rend - rbeg;
		INC(i)
	END;

	run := 0;
	i := font.runs[run].beg;
	FOR j := 0 TO nofGlyphs  - 1 DO
		r.RawInt(t); font.glyphs[i].dx := t;
		r.RawInt(t); font.glyphs[i].x := t;
		r.RawInt(t); font.glyphs[i].y := t;
		r.RawInt(t); font.glyphs[i].w := t;
		r.RawInt(t); font.glyphs[i].h := t;
		font.glyphs[i].available := TRUE;
		INC(i);
		IF i >= font.runs[run].end THEN INC(run); i := font.runs[run].beg END
	END;

	IF MemoryOptimization THEN
		w := 0; h := 0;
		FOR i := 0 TO 255 DO
			IF font.glyphs[i].available THEN
				INC(w, ((font.glyphs[i].w + 7) DIV 8) * 8);
				h := MAX(h, font.glyphs[i].h);
			END;
		END;
		NEW(img);
		Raster.Create(img, w, h, Raster.A1);
		mem := img.mem;
		adr := img.adr;
	END;

	FOR i := 0 TO 255 DO
		IF font.glyphs[i].available THEN
			xw := ((font.glyphs[i].w + 7) DIV 8) * 8;
			j := xw * font.glyphs[i].h DIV 8;
			IF xw *  font.glyphs[i].h > 0 THEN
				NEW(font.glyphs[i].img);
				IF MemoryOptimization THEN
					Raster.CreateWithBuffer(font.glyphs[i].img, xw, font.glyphs[i].h, Raster.A1, mem, adr);
				ELSE
					Raster.Create(font.glyphs[i].img, xw, font.glyphs[i].h, Raster.A1);
				END;

				pos := 0;
				WHILE j > 0 DO
					r.Char(ch); bits := ORD(ch); DEC(j);
					FOR b := 0 TO 7 DO
						IF bit[ORD(ch), b]  THEN
							IF pos MOD xw < font.glyphs[i].w THEN
								Raster.Put(font.glyphs[i].img, pos MOD xw, font.glyphs[i].h - pos DIV xw - 1, p1, mode);
							END
						ELSE
						END;
						INC(pos)
					END
				END
			END
		END
	END;
	RETURN font
END StreamLoad;

PROCEDURE StoreFont*(name : ARRAY OF CHAR; font : Font);
VAR w : Files.Writer;  f : Files.File;
BEGIN
	f := Files.New(name);
	IF f = NIL THEN RETURN END;
	Files.OpenWriter(w, f, 0);
	StreamStore(w, font);
	w.Update;
	Files.Register(f)
END StoreFont;

PROCEDURE StreamStore(w : Streams.Writer; font : Font);
VAR
	nofGlyphs, i, j, run, bits, b, pos, xw : LONGINT;
	p1 : Raster.Pixel;
	mode : Raster.Mode;

BEGIN
	Raster.InitMode(mode, Raster.srcCopy);

	w.Char(font.idch); (* id *)
	w.Char(font.typech); (* metric or font *)
	w.Char(font.famch); (* family *)
	w.Char(font.varch); (* variant *)
	w.RawInt(font.height);
	w.RawInt(font.minX);
	w.RawInt(font.maxX);
	w.RawInt(-SHORT(font.descent));
	w.RawInt(SHORT(font.ascent));
	w.RawInt(font.nofRuns);

	nofGlyphs := 0; i := 0;
	WHILE i < font.nofRuns DO
		w.RawInt(SHORT(font.runs[i].beg));
		w.RawInt(SHORT(font.runs[i].end));
		nofGlyphs := nofGlyphs + font.runs[i].end - font.runs[i].beg;
		INC(i)
	END;

	run := 0;
	i := font.runs[run].beg;
	FOR j := 0 TO nofGlyphs  - 1 DO
		w.RawInt(SHORT(font.glyphs[i].dx));
		w.RawInt(SHORT(font.glyphs[i].x));
		w.RawInt(SHORT(font.glyphs[i].y));
		w.RawInt(SHORT(font.glyphs[i].w));
		w.RawInt(SHORT(font.glyphs[i].h));
		INC(i);
		IF i >= font.runs[run].end THEN INC(run); i := font.runs[run].beg END
	END;

	FOR i := 0 TO 255 DO
		IF font.glyphs[i].available THEN
			xw := ((font.glyphs[i].w + 7) DIV 8) * 8;
			j := xw * font.glyphs[i].h DIV 8;
			IF xw *  font.glyphs[i].h > 0 THEN
				pos := 0;
				WHILE j > 0 DO
					DEC(j);
					bits := 0;
					FOR b := 0 TO 7 DO
						Raster.Get(font.glyphs[i].img, pos MOD xw, font.glyphs[i].h - pos DIV xw - 1, p1, mode);
						IF p1[Raster.a] # 0X THEN INC(bits, 256) END;
						bits := bits DIV 2;
						INC(pos)
					END;
					w.Char(CHR(bits))
				END
			END
		END
	END
END StreamStore;

PROCEDURE InitBitTable;
VAR b, i: LONGINT;
BEGIN
	FOR b := 0 TO 0FFH DO
		FOR i := 0 TO 7 DO
			bit[b, i] := ODD(ASH(b, -i))
		END
	END
END InitBitTable;

PROCEDURE LoadExactFont*(fi : WMFontManager.FontInfo) : WMGraphics.Font;
VAR exactName : ARRAY 256 OF CHAR;
	str : ARRAY 16 OF CHAR; f : WMGraphics.Font;
BEGIN
	COPY(fi.name^, exactName);
	Strings.IntToStr(fi.size, str); Strings.Append(exactName, str);
	IF WMGraphics.FontBold IN fi.style THEN Strings.Append(exactName, "b") END;
	IF WMGraphics.FontItalic IN fi.style THEN Strings.Append(exactName, "i") END;
	Strings.Append(exactName, ".Scn.Fnt");
	f := LoadFont(exactName);
	IF f # NIL THEN
		COPY(fi.name^, f.name);
		f.size := fi.size;
		f.style := fi.style;
	END;
	RETURN f
END LoadExactFont;

PROCEDURE LoadApproximateFont*(fi : WMFontManager.FontInfo) : WMGraphics.Font;
VAR exactName : ARRAY 256 OF CHAR;
	str : ARRAY 16 OF CHAR; f : WMGraphics.Font;
BEGIN
	COPY(fi.name^, exactName);
	Strings.IntToStr(fi.size, str); Strings.Append(exactName, str);
	Strings.Append(exactName, ".Scn.Fnt");
	f := LoadFont(exactName);
	IF f # NIL THEN
		f.size := fi.size;
		f.style := fi.style
	END;
	RETURN f
END LoadApproximateFont;

BEGIN
	InitBitTable
END WMOberonFonts.


System.Free WMOberonFonts~

