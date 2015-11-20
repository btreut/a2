MODULE WMCCGFonts;	(** AUTHOR "TF"; PURPOSE "Integrate CCG fonts"; *)

IMPORT
	Files, Streams, WMGraphics, WMRectangles, KernelLog, Strings, Kernel, WMFontManager;

CONST
	CMDStrokeMove = 0;
	CMDStrokeLine = 1;
	CMDStrokeSpline = 2;
	MaxSplineSeg = 16;

TYPE
	StrokeElement* = RECORD
		cmd* : LONGINT;
		x*, y* : LONGINT;
	END;

	StrokeArray* = POINTER TO ARRAY OF StrokeElement;

	GlyphRef* = RECORD
		 x*, y*, w*, h* : LONGINT;
		 refucs*, refvariant* : LONGINT;
		 refPtr* : Glyph;
	END;

	GlyphRefArray* = POINTER TO ARRAY OF GlyphRef;

	Glyph* = POINTER TO RECORD
		ucs*, variant* : LONGINT;
		nofStrokes*, nofSubComponents* : LONGINT;
		strokes* : StrokeArray;
		subComponents* : GlyphRefArray;
		nextVariant* : Glyph;
	END;

	GlyphRange = RECORD
		firstCode, lastCode  : LONGINT;
		filePos : LONGINT;
		glyphs : POINTER TO ARRAY OF Glyph;
	END;

	RangeArray = POINTER TO ARRAY OF GlyphRange;

	Font* = OBJECT (WMGraphics.Font)
	VAR gf* : GenericFont;

		PROCEDURE &New*(gf : GenericFont; size : LONGINT; style : SET);
		BEGIN
			SELF.size := size;
			SELF.style := style;
			SELF.gf := gf;
			COPY(gf.name, name);
			ascent := size; descent := 0
		END New;

		PROCEDURE HasChar*(code : LONGINT) : BOOLEAN;
		BEGIN
			RETURN gf.GetGlyph(code, 0) # NIL
		END HasChar;


		(** Render character char to canvas at x, y (baseline) *)
		PROCEDURE RenderChar*(canvas : WMGraphics. Canvas ; x, y : REAL; char : LONGINT);
		VAR glyph : Glyph;
			points : ARRAY 2560 OF WMGraphics.Point2d;
		BEGIN
			glyph := gf.GetGlyph(char, 0);
			IF glyph # NIL THEN
				gf.RenderGlyphReal(canvas, glyph, x, y - size, size, size, 0, FALSE, canvas.color, 0, points);
			END
		END RenderChar;

		(** return spacing of character code *)
		PROCEDURE GetGlyphSpacings*(code : LONGINT; VAR glyphSpacings : WMGraphics.GlyphSpacings);
		BEGIN
			glyphSpacings.width := size;
			glyphSpacings.height := size;
			glyphSpacings.ascent := ascent;
			glyphSpacings.descent := descent;
			glyphSpacings.bearing := WMRectangles.MakeRect(0, 0, 0, 0)
		END GetGlyphSpacings;
	END Font;

	GenericFont* = OBJECT
	VAR
		glyphRanges : RangeArray;
		fontFile : Files.File;
		name : ARRAY 256 OF CHAR;

		(* find the range where a glyph is inside *)
		PROCEDURE FindGlyphRange(code : LONGINT; VAR glyphRangeIndex : LONGINT) : BOOLEAN;
		VAR a, b, m : LONGINT;
		BEGIN
			glyphRangeIndex := 0;
			a := 0; b := LEN(glyphRanges) - 1;
			WHILE (a < b) DO m := (a + b) DIV 2;
				IF glyphRanges[m].lastCode < code THEN a := m + 1
				ELSE b := m
				END
			END;
			IF (glyphRanges[a].firstCode <= code) & (glyphRanges[a].lastCode >= code) THEN
				glyphRangeIndex := a; RETURN TRUE
			ELSE RETURN FALSE
			END
		END FindGlyphRange;

		PROCEDURE ReadPackedGlyph(r : Streams.Reader; VAR glyph : Glyph);
		VAR g : Glyph;
			hasMoreVariants : BOOLEAN;
			i : LONGINT;
		BEGIN
			NEW(g); glyph := g;
			REPEAT
				(* has more variants *)
				hasMoreVariants := r.Get() = 1X;
				(* variant *)
				g.variant := ORD(r.Get());
				(* sanity check *)
				g.ucs := r.Net32();
				(* number of stroke commands *)
				g.nofStrokes := ORD(r.Get());
				NEW(g.strokes, g.nofStrokes);
				FOR i := 0 TO g.nofStrokes - 1 DO
					g.strokes[i].cmd := ORD(r.Get());
					g.strokes[i].x := ORD(r.Get());
					g.strokes[i].y := ORD(r.Get())
				END;
				(* number of sub components *)
				g.nofSubComponents := ORD(r.Get());
				NEW(g.subComponents, g.nofSubComponents);
				FOR i := 0 TO g.nofSubComponents - 1 DO
					g.subComponents[i].refucs := r.Net32();
					g.subComponents[i].refvariant := ORD(r.Get());
					g.subComponents[i].x := ORD(r.Get());
					g.subComponents[i].y := ORD(r.Get());
					g.subComponents[i].w := ORD(r.Get());
					g.subComponents[i].h := ORD(r.Get())
				END;
				IF hasMoreVariants THEN NEW(g.nextVariant); g := g.nextVariant END
			UNTIL ~hasMoreVariants;
		END ReadPackedGlyph;

		PROCEDURE LoadRange(f : Files.File; rangeIndex : LONGINT);
		VAR r : Files.Reader;
			size, i : LONGINT;
			range : GlyphRange; (* because of too complex expression otherwise ;-) *)
		BEGIN
			range := glyphRanges[rangeIndex];
			(*
			KernelLog.String("Loading range "); KernelLog.Hex(range.firstCode, 8);
			KernelLog.String(".."); KernelLog.Hex(range.lastCode, 8);
			KernelLog.Ln;
			*)
			(* glyphRanges[rangeIndex].glyphs in the new statement may not be replaced with range! *)
			NEW(glyphRanges[rangeIndex].glyphs, range.lastCode - range.firstCode + 1);
			NEW(r, f, range.filePos);
			(* sanity check *)
			size := r.Net16(); ASSERT(size = glyphRanges[rangeIndex].lastCode - glyphRanges[rangeIndex].firstCode);
				(* glyphRanges[rangeIndex].glyphs in the following loop may not be replaced with range! *)
			FOR i := 0 TO size DO ReadPackedGlyph(r, glyphRanges[rangeIndex].glyphs[i]) END
		END LoadRange;

		PROCEDURE GetGlyph*(ucs, variant : LONGINT) : Glyph;
		VAR rangeIndex : LONGINT; glyph : Glyph;
		BEGIN
			IF FindGlyphRange(ucs, rangeIndex) THEN
				IF glyphRanges[rangeIndex].glyphs = NIL THEN LoadRange(fontFile, rangeIndex) END;
				IF glyphRanges[rangeIndex].glyphs = NIL THEN RETURN NIL END;
				glyph := glyphRanges[rangeIndex].glyphs[ucs - glyphRanges[rangeIndex].firstCode];
				WHILE (glyph # NIL) & (glyph.variant # variant) DO glyph := glyph.nextVariant END;
				IF glyph # NIL THEN
					IF (glyph.ucs # ucs) THEN KernelLog.String("Not correctly loaded : "); KernelLog.Hex(glyph.ucs, 8);
						KernelLog.String(" instead of "); KernelLog.Hex(ucs, 8); KernelLog.Ln;
					END;
					ASSERT((glyph.ucs = ucs) & (glyph.variant = variant))
				END;
				RETURN glyph
			ELSE
				RETURN NIL
			END
		END GetGlyph;

		PROCEDURE Load*(fontName : ARRAY OF CHAR) : BOOLEAN;
		VAR
			r : Files.Reader;
			i, nofRanges : LONGINT;
			fileName : ARRAY 256 OF CHAR;
		BEGIN
			COPY(fontName, name);
			COPY(fontName, fileName);
			Strings.Append(fileName, ".ccg");
			fontFile := Files.Old(fileName);
			IF fontFile = NIL THEN RETURN FALSE END;
			Files.OpenReader(r, fontFile, 0);
			nofRanges := r.Net32();
			NEW(glyphRanges, nofRanges);
			FOR i := 0 TO nofRanges - 1 DO
				glyphRanges[i].firstCode := r.Net32(); glyphRanges[i].lastCode := r.Net32(); glyphRanges[i].filePos := r.Net32()
			END;
			RETURN TRUE
		END Load;

		PROCEDURE FindGlyphSubComponent(VAR ref : GlyphRef) : Glyph;
		BEGIN
			IF ref.refPtr # NIL THEN RETURN ref.refPtr END;
			ref.refPtr := GetGlyph(ref.refucs, ref.refvariant);
			RETURN ref.refPtr
		END FindGlyphSubComponent;

		PROCEDURE CalcBB(glyph : Glyph) : WMRectangles.Rectangle;
		VAR result, t : WMRectangles.Rectangle; i : LONGINT;
		BEGIN
			result := WMRectangles.MakeRect(256, 256, 0, 0);
			IF glyph.nofSubComponents > 0 THEN
				FOR i := 0 TO glyph.nofSubComponents - 1 DO
					t := WMRectangles.MakeRect(glyph.subComponents[i].x, glyph.subComponents[i].y,
					 glyph.subComponents[i].x + glyph.subComponents[i].w, glyph.subComponents[i].y + glyph.subComponents[i].h);
					WMRectangles.ExtendRect(result, t)
				END
			END;
			FOR i := 0 TO glyph.nofStrokes - 1 DO
				t := WMRectangles.MakeRect(glyph.strokes[i].x, glyph.strokes[i].y, glyph.strokes[i].x, glyph.strokes[i].y);
				WMRectangles.ExtendRect(result, t)
			END;
			RETURN result
		END CalcBB;

		(* floating point version *)
		PROCEDURE RenderGlyphReal*(canvas : WMGraphics.Canvas; glyph : Glyph;
					x, y, w, h : REAL; level : LONGINT;  filled : BOOLEAN; color, mode : LONGINT; VAR points : ARRAY OF WMGraphics.Point2d);
		VAR i : LONGINT;  tx, ty, cx, cy, dx, dy : REAL; ctrl : BOOLEAN; g : Glyph; r, bb : WMRectangles.Rectangle;
			dtx, dty, dtw, dth : REAL;
			nofPoints : LONGINT;

		BEGIN
			IF level > 0 THEN (* then we must fit the bounding box in x, y, w, h *)
				bb := CalcBB(glyph);
				dx := (bb.r - bb.l); IF dx <= 0 THEN dx := 256 END;
				dy := (bb.b - bb.t); IF dy <= 0 THEN dy := 256 END;
				x := x - (bb.l * w / 256) * 256 / dx;
				y := y - (bb.t * h / 256) * 256 / dy;
				w := w * 256 / dx;
				h := h * 256 / dy
			END;
			IF glyph.nofSubComponents > 0 THEN
				FOR i := 0 TO glyph.nofSubComponents - 1 DO
					g := FindGlyphSubComponent(glyph.subComponents[i]);
					IF g # NIL THEN
						r := CalcBB(glyph);
						dtx := x + glyph.subComponents[i].x * w / 256;
						dty := y + glyph.subComponents[i].y * h / 256;
						dtw := glyph.subComponents[i].w * w / 256;
						dth := glyph.subComponents[i].h * h / 256;
						RenderGlyphReal(canvas, g, dtx, dty, dtw, dth, level + 1, filled, color, mode, points)
					END
				END
			END;
			ctrl := FALSE;

			IF ~filled THEN
				FOR i := 0 TO glyph.nofStrokes - 1 DO
					IF glyph.strokes[i].cmd = CMDStrokeMove THEN tx := glyph.strokes[i].x; ty := glyph.strokes[i].y; ctrl := FALSE;
					ELSIF glyph.strokes[i].cmd = CMDStrokeSpline THEN cx := glyph.strokes[i].x; cy := glyph.strokes[i].y; ctrl := TRUE;
					ELSIF glyph.strokes[i].cmd = CMDStrokeLine THEN
						IF i > 0 THEN
							IF ctrl THEN SplineReal(canvas, tx, ty, cx, cy, glyph.strokes[i].x, glyph.strokes[i].y, x, y, w, h, color, WMGraphics.ModeCopy)
							ELSE
								canvas.Line(ENTIER(x + (tx * w) / 256), ENTIER(y + (ty * h) / 256),
										ENTIER(x + (glyph.strokes[i].x * w) / 256), ENTIER(y + (glyph.strokes[i].y* h) / 256), color, WMGraphics.ModeCopy)
							END
						END;
						tx := glyph.strokes[i].x; ty := glyph.strokes[i].y;
						ctrl := FALSE;
					END
				END;
			ELSE
				nofPoints := 0;
				FOR i := 0 TO glyph.nofStrokes - 1 DO
					IF glyph.strokes[i].cmd = CMDStrokeMove THEN
						IF nofPoints > 0 THEN canvas.FillPolygonFlat(points, nofPoints - 1 , color, 1) END;
						nofPoints := 0;
						tx := glyph.strokes[i].x; ty := glyph.strokes[i].y;
							AddPoint(points, nofPoints, ENTIER(x + (tx * w) / 256), ENTIER(y + (ty * h) / 256)); ctrl := FALSE
					ELSIF glyph.strokes[i].cmd = CMDStrokeSpline THEN cx := glyph.strokes[i].x; cy := glyph.strokes[i].y; ctrl := TRUE;
					ELSIF glyph.strokes[i].cmd = CMDStrokeLine THEN
						IF i > 0 THEN
							IF ctrl THEN AddSplinePoints(points, nofPoints, tx, ty, cx, cy, glyph.strokes[i].x, glyph.strokes[i].y, x, y, w, h)
							ELSE AddPoint(points, nofPoints, ENTIER(x + (glyph.strokes[i].x * w) / 256), ENTIER(y + (glyph.strokes[i].y* h) / 256))
							END
						END;
						tx := glyph.strokes[i].x; ty := glyph.strokes[i].y;
						ctrl := FALSE;
					END
				END;
				IF nofPoints > 0 THEN canvas.FillPolygonFlat(points, nofPoints - 1, color, mode) END
			END
		END RenderGlyphReal;

	END GenericFont;

VAR fontCache : Kernel.FinalizedCollection;
	searchName : ARRAY 256 OF CHAR;
	foundFont : GenericFont;

PROCEDURE AddPoint(VAR points : ARRAY OF WMGraphics.Point2d; VAR nofPoints : LONGINT; x, y : LONGINT);
BEGIN
	points[nofPoints].x := x;
	points[nofPoints].y := y;
	INC(nofPoints)
END AddPoint;

PROCEDURE SplineReal(canvas : WMGraphics.Canvas; x0, y0, x1, y1, x2, y2, x, y, w, h : REAL; color, mode : LONGINT);
VAR i: LONGINT;  tx, ty, nx, ny : REAL;
	t, onet, dt : REAL;
BEGIN
	tx := x0; ty := y0;
	dt := 1 / MaxSplineSeg; t := 0; onet := 1;
	FOR i := 0 TO MaxSplineSeg DO
		nx := onet * onet * x0 + 2 * t * onet * x1 + t * t * x2;
		ny := onet * onet * y0 + 2 * t * onet * y1 + t * t * y2;
		canvas.Line(ENTIER(x + (tx * w) / 256), ENTIER(y + (ty * h) / 256),
		ENTIER(x + (nx * w) / 256), ENTIER(y + (ny * h) / 256), color, mode);
		t := t + dt; onet := 1 - t; tx := nx; ty := ny
	END
END SplineReal;

PROCEDURE AddSplinePoints(VAR points : ARRAY OF WMGraphics.Point2d; VAR nofPoints : LONGINT;  x0, y0, x1, y1, x2, y2, x, y, w, h : REAL);
VAR i: LONGINT;  tx, ty, nx, ny : REAL;
	t, onet, dt : REAL;
BEGIN
	tx := x0; ty := y0;
	dt := 1 / MaxSplineSeg; t := 0; onet := 1;
	FOR i := 0 TO MaxSplineSeg DO
		nx := onet * onet * x0 + 2 * t * onet * x1 + t * t * x2;
		ny := onet * onet * y0 + 2 * t * onet * y1 + t * t * y2;
		AddPoint(points, nofPoints, ENTIER(x + (nx * w) / 256), ENTIER(y + (ny * h) / 256));
		t := t + dt; onet := 1 - t; tx := nx; ty := ny
	END
END AddSplinePoints;

PROCEDURE CheckFont(obj: ANY; VAR cont: BOOLEAN);
BEGIN
	IF obj IS GenericFont THEN
		IF obj(GenericFont).name = searchName THEN
			foundFont := obj(GenericFont);
			cont := FALSE
		END
	END
END CheckFont;

PROCEDURE LoadExactFont*(fi : WMFontManager.FontInfo) : WMGraphics.Font;
VAR gf : GenericFont; f : Font;
BEGIN {EXCLUSIVE}
	foundFont := NIL;
	COPY(fi.name^, searchName);
	fontCache.Enumerate(CheckFont);
	gf := foundFont;
	IF gf = NIL THEN NEW(gf); IF ~gf.Load(fi.name^) THEN gf := NIL ELSE fontCache.Add(gf, NIL) END END;
	IF gf = NIL THEN RETURN NIL
	ELSE NEW(f, gf, fi.size, fi.style); RETURN f
	END
END LoadExactFont;

BEGIN
	NEW(fontCache)
END WMCCGFonts.
