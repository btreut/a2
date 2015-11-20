MODULE WMFontCCGConverter;	(** AUTHOR "TF"; PURPOSE "CCG font support (CCG fonts by eForth Technology Corp)"; *)
(* 2003.01.29 - adapted to new single.fnt format *)

IMPORT
	KernelLog, Modules, Streams, WMRectangles, Files, UTF8Strings, WMGraphics, WMWindowManager, WMGrids,
	WMBitmapFont, WMComponents, Standard := WMStandardComponents, Editor := WMEditors,
	Classes := TFClasses, WMGraphicUtilities, Strings;

CONST
	MaxStrokes = 128;
	MaxGlyphRefs = 64;
	MaxSplineSeg = 16;
	CMDStrokeMove = 0;
	CMDStrokeLine = 1;
	CMDStrokeSpline = 2;
	MaxRangeSize = 256;

TYPE
	TestWindow = OBJECT(WMComponents.FormWindow)
	VAR mainPanel, toolbar, right, paintBox : Standard.Panel;
		l1 : Standard.Label;
		startEdit : Editor.Editor;
		grid : WMGrids.GenericGrid;
		selectedGlyph : Glyph;
		font : RawCCGFont;
		colWidths : WMGrids.Spacings;
		scaler : Standard.Scrollbar;
		scale : LONGINT;

		PROCEDURE &New*(f : RawCCGFont);
		BEGIN
			SetTitle(WMWindowManager.NewString("CCG font explorer"));
			font := f;
			NEW(mainPanel); mainPanel.bounds.SetExtents(480, 400);
			mainPanel.fillColor.Set(WMGraphics.RGBAToColor(200, 200, 200, 255));

			(* toolbar *)
			NEW(toolbar); toolbar.bounds.SetHeight(40); toolbar.alignment.Set(WMComponents.AlignTop);
			mainPanel.AddContent(toolbar);

			NEW(grid); grid.alignment.Set(WMComponents.AlignLeft); grid.bounds.SetWidth(201); mainPanel.AddContent(grid);
			NEW(colWidths, 3); colWidths[0] := 80; colWidths[1] := 50; colWidths[2] := 50;
			grid.SetColSpacings(colWidths);
			grid.nofCols.Set(3);
			grid.SetDrawCellProc(DrawCell);
			grid.nofRows.Set(font.glyphList.GetCount());
			grid.defaultRowHeight.Set(50);
			grid.defaultColWidth.Set(50);
			grid.onSelect.Add(GlyphSelected);

			NEW(l1); l1.bounds.SetExtents(150, 20); l1.SetCaption("Range Start:"); l1.alignment.Set(WMComponents.AlignLeft);
			NEW(startEdit); startEdit.bounds.SetExtents(200, 20); startEdit.SetAsString("1100"); startEdit.alignment.Set(WMComponents.AlignLeft);
			startEdit.multiLine.Set(FALSE);
			startEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			toolbar.AddContent(l1); toolbar.AddContent(startEdit);

			NEW(right); right.alignment.Set(WMComponents.AlignClient); right.fillColor.Set(0); mainPanel.AddContent(right);
			(* add paintbox to draw glyph in full res *)
			NEW(paintBox); paintBox.bounds.SetExtents(256, 256);
			paintBox.fillColor.Set(WMGraphics.RGBAToColor(255, 255, 255, 255));
			right.AddContent(paintBox);
			paintBox.SetExtDrawHandler(PaintBoxPaint);

			NEW(scaler); scaler.alignment.Set(WMComponents.AlignRight); right.AddContent(scaler);
			scaler.max.Set(256); scaler.pos.Set(256);
			scaler.onPositionChanged.Add(Rescale); scale := 256;

			Init(mainPanel.bounds.GetWidth(), mainPanel.bounds.GetHeight(), FALSE);
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(200, 200, SELF, {WMWindowManager.FlagFrame});
			SetContent(mainPanel)
		END New;

		PROCEDURE Rescale(sender, data : ANY);
		BEGIN
			scale := scaler.pos.Get();
			paintBox.Invalidate
		END Rescale;

		PROCEDURE GlyphSelected(sender, data : ANY);
		VAR sc, sr, ec, er : LONGINT; ptr : ANY;
		BEGIN
			grid.GetSelection(sc, sr, ec, er);
			IF font # NIL THEN
				font.glyphList.Lock;
				IF (sr >= 0) & (sr < font.glyphList.GetCount()) THEN
					ptr := font.glyphList.GetItem(sr); selectedGlyph := ptr(Glyph);
					paintBox.Invalidate
				END;
				font.glyphList.Unlock
			END
		END GlyphSelected;

		PROCEDURE PaintBoxPaint(canvas : WMGraphics.Canvas);
		BEGIN
			IF selectedGlyph # NIL THEN RenderGlyphReal(canvas, selectedGlyph, 0, 0, scale, scale, 0, TRUE) END
		END PaintBoxPaint;

		PROCEDURE DrawCell(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR color : LONGINT; g : Glyph; ptr : ANY; str : ARRAY 32 OF CHAR;
		BEGIN
			color := WMGraphics.RGBAToColor(255, 255, 255, 255);
			IF state * {WMGrids.CellFixed, WMGrids.CellSelected} = {WMGrids.CellFixed, WMGrids.CellSelected} THEN
				color := WMGraphics.RGBAToColor(0, 0, 255, 255)
			ELSIF WMGrids.CellFixed IN state THEN color := WMGraphics.RGBAToColor(196, 196, 196, 255)
			ELSIF WMGrids.CellSelected IN state THEN color := WMGraphics.RGBAToColor(196, 196, 255, 255)
			END;

			IF WMGrids.CellHighlighted IN state THEN color := WMGraphics.RGBAToColor(255, 255, 0, 255) END;
			IF WMGrids.CellSelected IN state THEN canvas.SetColor(WMGraphics.RGBAToColor(255, 255, 255, 255))
			ELSE canvas.SetColor(WMGraphics.RGBAToColor(0, 0, 0, 255))
			END;
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, WMGraphics.ModeCopy);
			IF (WMGrids.CellFocused IN state) & ~(WMGrids.CellHighlighted IN state) THEN
				WMGraphicUtilities.DrawRect(canvas, WMRectangles.MakeRect(0, 0, w, h), WMGraphics.RGBAToColor(0, 0, 0, 196),
					WMGraphics.ModeSrcOverDst);
			END;
			IF font # NIL THEN
				font.glyphList.Lock;
				IF (y >= 0) & (y < font.glyphList.GetCount()) THEN
					ptr := font.glyphList.GetItem(y); g := ptr(Glyph);
					IF x = 0 THEN Strings.IntToHexStr(g.ucs, 5, str);
						WMGraphics.DrawStringInRect(canvas,
							WMRectangles.MakeRect(0, 0, w, h), FALSE,
							WMGraphics.AlignCenter, WMGraphics.AlignCenter, str)
					ELSIF x = 1 THEN WMBitmapFont.bimbofont.RenderChar(canvas, 0, h - 5, g.ucs);
					ELSIF x = 2 THEN RenderGlyphReal(canvas, g, 0, 0, h, h, 0, FALSE)
					END
				END;
				font.glyphList.Unlock;
			END;
		END DrawCell;

(*		PROCEDURE RenderGlyph(canvas : WMGraphics.Canvas; glyph : Glyph; x, y, w, h, level : LONGINT; trace : BOOLEAN);
		VAR i, tx, ty, cx, cy, dx, dy : LONGINT; ctrl : BOOLEAN; g : Glyph; r, bb : WMRectangles.Rectangle;
			dtx, dty, dtw, dth : LONGINT;
		BEGIN
			IF level > 0 THEN (* then we must fit the bounding box in x, y, w, h *)
				bb := CalcBB(glyph);
				dx := (bb.r - bb.l); IF dx <= 0 THEN dx := 256 END;
				dy := (bb.b - bb.t); IF dy <= 0 THEN dy := 256 END;
				x := x - (bb.l * w DIV 256) * 256 DIV dx;
				y := y - (bb.t * h DIV 256) * 256 DIV dy;
				w := w * 256 DIV dx;
				h := h * 256 DIV dy
			 END;
			IF glyph.nofSubComponents > 0 THEN
				FOR i := 0 TO glyph.nofSubComponents - 1 DO
					g := font.FindGlyphSubComponent(glyph.subComponents[i]);
					IF g # NIL THEN
						r := CalcBB(glyph);
						dtx := x + glyph.subComponents[i].x * w DIV 256;
						dty := y + glyph.subComponents[i].y * h DIV 256;
						dtw := glyph.subComponents[i].w * w DIV 256;
						dth := glyph.subComponents[i].h * h DIV 256;
						IF trace THEN
							r := WMRectangles.MakeRect(dtx, dty, dtx + dtw, dty + dth);
							canvas.Fill(r, WMGraphics.RGBAToColor(0, 0, 255, 16), WMGraphics.ModeSrcOverDst)
						END;
						RenderGlyph(canvas, g, dtx, dty, dtw, dth, level + 1, trace)
					END
				END
			END;
(*			IF level > 0 THEN (* then we must fit the bounding box in x, y, w, h *)
				bb := CalcBB(glyph);
				dx := (bb.r - bb.l); IF dx <= 0 THEN dx := 256 END;
				dy := (bb.b - bb.t); IF dy <= 0 THEN dy := 256 END;
				x := x - (bb.l * w DIV 256) * 256 DIV dx;
				y := y - (bb.t * h DIV 256) * 256 DIV dy;
				w := w * 256 DIV dx;
				h := h * 256 DIV dy
			 END; *)
			ctrl := FALSE;
			IF TraceGlyphs IN Trace THEN
				KernelLog.String("============"); KernelLog.Ln;
				KernelLog.String("UCS : "); KernelLog.Hex(glyph.ucs, 8); KernelLog.Ln;
				KernelLog.String("NofStrokes : "); KernelLog.Int(glyph.nofStrokes, 5); KernelLog.Ln
			END;
			FOR i := 0 TO glyph.nofStrokes - 1 DO
				IF TraceGlyphs IN Trace THEN
					KernelLog.Int(glyph.strokes[i].cmd, 3); KernelLog.String(" : "); KernelLog.Int(glyph.strokes[i].x, 5);
					KernelLog.String(", "); KernelLog.Int(glyph.strokes[i].y, 5);
					KernelLog.Ln
				END;
				IF glyph.strokes[i].cmd = CMDStrokeMove THEN tx := glyph.strokes[i].x; ty := glyph.strokes[i].y; ctrl := FALSE;
					IF TraceGlyphs IN Trace THEN
	 					KernelLog.String(" --> MoveTo"); KernelLog.Int(glyph.strokes[i].x, 5); KernelLog.String(", "); KernelLog.Int(glyph.strokes[i].y, 5);
						KernelLog.Ln
					END
				ELSIF glyph.strokes[i].cmd = CMDStrokeSpline THEN cx := glyph.strokes[i].x; cy := glyph.strokes[i].y; ctrl := TRUE;
					IF TraceGlyphs IN Trace THEN
						KernelLog.String(" --> Spline"); KernelLog.Int(glyph.strokes[i].x, 5); KernelLog.String(", "); KernelLog.Int(glyph.strokes[i].y, 5);
						KernelLog.Ln
					END
				ELSIF glyph.strokes[i].cmd = CMDStrokeLine THEN
 					IF TraceGlyphs IN Trace THEN
						KernelLog.String(" --> Execute"); KernelLog.Int(glyph.strokes[i].x, 5); KernelLog.String(", "); KernelLog.Int(glyph.strokes[i].y, 5);
						KernelLog.Ln;
						IF i = 0 THEN KernelLog.String("Strange... no move to"); KernelLog.Ln END;
					END;
					IF i > 0 THEN
						IF ctrl THEN Spline(canvas, tx, ty, cx, cy, glyph.strokes[i].x, glyph.strokes[i].y, x, y, w, h, 0FFH, WMGraphics.ModeCopy)
						ELSE
							canvas.Line(x + (tx * w) DIV 256, y + (ty * h) DIV 256,
									x + (glyph.strokes[i].x * w) DIV 256, y + (glyph.strokes[i].y* h) DIV 256, 0FFH, WMGraphics.ModeCopy)
						END
					END;
					tx := glyph.strokes[i].x; ty := glyph.strokes[i].y;
					ctrl := FALSE;
				END
			END;
		END RenderGlyph; *)

		(* floating point version *)
		PROCEDURE RenderGlyphReal(canvas : WMGraphics.Canvas; glyph : Glyph; x, y, w, h : REAL; level : LONGINT; trace : BOOLEAN);
		VAR i : LONGINT;  tx, ty, cx, cy, dx, dy : REAL; ctrl : BOOLEAN; g : Glyph; r, bb : WMRectangles.Rectangle;
			dtx, dty, dtw, dth : REAL;
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
					g := font.FindGlyphSubComponent(glyph.subComponents[i]);
					IF g # NIL THEN
						r := CalcBB(glyph);
						dtx := x + glyph.subComponents[i].x * w / 256;
						dty := y + glyph.subComponents[i].y * h / 256;
						dtw := glyph.subComponents[i].w * w / 256;
						dth := glyph.subComponents[i].h * h / 256;
						IF trace THEN
							r := WMRectangles.MakeRect(ENTIER(dtx), ENTIER(dty), ENTIER(dtx + dtw), ENTIER(dty + dth));
							canvas.Fill(r, WMGraphics.RGBAToColor(0, 0, 255, 16), WMGraphics.ModeSrcOverDst)
						END;
						RenderGlyphReal(canvas, g, dtx, dty, dtw, dth, level + 1, trace)
					END
				END
			END;
			ctrl := FALSE;
			FOR i := 0 TO glyph.nofStrokes - 1 DO
				IF glyph.strokes[i].cmd = CMDStrokeMove THEN tx := glyph.strokes[i].x; ty := glyph.strokes[i].y; ctrl := FALSE;
				ELSIF glyph.strokes[i].cmd = CMDStrokeSpline THEN cx := glyph.strokes[i].x; cy := glyph.strokes[i].y; ctrl := TRUE;
				ELSIF glyph.strokes[i].cmd = CMDStrokeLine THEN
					IF i > 0 THEN
						IF ctrl THEN SplineReal(canvas, tx, ty, cx, cy, glyph.strokes[i].x, glyph.strokes[i].y, x, y, w, h, 0FFH, WMGraphics.ModeCopy)
						ELSE
							canvas.Line(ENTIER(x + (tx * w) / 256), ENTIER(y + (ty * h) / 256),
									ENTIER(x + (glyph.strokes[i].x * w) / 256), ENTIER(y + (glyph.strokes[i].y* h) / 256), 0FFH, WMGraphics.ModeCopy)
						END
					END;
					tx := glyph.strokes[i].x; ty := glyph.strokes[i].y;
					ctrl := FALSE;
				END
			END;
		END RenderGlyphReal;

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

		PROCEDURE Close;
		BEGIN
			Close^;
			testWindow := NIL
		END Close;
	END TestWindow;

	StrokeElement = RECORD
		cmd : LONGINT;
		x, y : LONGINT;
	END;

	GlyphRef = RECORD
		 x, y, w, h : LONGINT;
		 refucs, refvariant : LONGINT;
		 refPtr : Glyph;
	END;

	StrokeArray = POINTER TO ARRAY OF StrokeElement;
	GlyphRefArray = POINTER TO ARRAY OF GlyphRef;

	GlyphRange = RECORD
		firstCode, lastCode  : LONGINT;
		filePos : LONGINT;
		glyphs : POINTER TO ARRAY OF Glyph;
	END;

	RangeArray = POINTER TO ARRAY OF GlyphRange;

	Glyph = POINTER TO RECORD
		ucs, variant : LONGINT;
		nofStrokes, nofSubComponents : LONGINT;
		strokes : StrokeArray;
		subComponents : GlyphRefArray;
		nextVariant : Glyph;
	END;
	GlyphArray = POINTER TO ARRAY OF Glyph;

	RawCCGFont = OBJECT
	VAR workStrokes : StrokeArray;
		workGlyphRef : GlyphRefArray;
		nofStrokes, nofGlyphRefs : LONGINT;
		glyphList : Classes.List;
(* BEGIN variables for native font *)
		glyphRanges : RangeArray;
		fontFile : Files.File;
(* END variables for native font *)

		PROCEDURE &New*;
		BEGIN
			NEW(workStrokes, MaxStrokes);
			NEW(workGlyphRef, MaxGlyphRefs);
			NEW(glyphList);
		END New;

(* BEGIN optimized routines for native font *)
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

		PROCEDURE WritePackedGlyph(w : Streams.Writer; g : Glyph);
		VAR i : LONGINT;
		BEGIN
			REPEAT
				(* has more variants *)
				IF g.nextVariant = NIL THEN w.Char(0X) ELSE w.Char(1X) END;
				(* variant *)
				w.Char(CHR(g.variant));
				(* sanity check *)
				w.Net32(g.ucs);

				(* number of stroke commands *)
				ASSERT(g.nofStrokes <= 255);
				w.Char(CHR(g.nofStrokes));
				FOR i := 0 TO g.nofStrokes - 1 DO
					w.Char(CHR(g.strokes[i].cmd));
					w.Char(CHR(g.strokes[i].x));
					w.Char(CHR(g.strokes[i].y))
				END;

				(* number of sub components *)
				ASSERT(g.nofSubComponents <= 255);
				w.Char(CHR(g.nofSubComponents));
				FOR i := 0 TO g.nofSubComponents - 1 DO
					w.Net32(g.subComponents[i].refucs);
					w.Char(CHR(g.subComponents[i].refvariant));
					w.Char(CHR(g.subComponents[i].x));
					w.Char(CHR(g.subComponents[i].y));
					w.Char(CHR(g.subComponents[i].w));
					w.Char(CHR(g.subComponents[i].h))
				END;
				g := g.nextVariant
			UNTIL g = NIL;
		END WritePackedGlyph;

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
			(*	KernelLog.String("Found:"); KernelLog.Hex(g.ucs, 8); KernelLog.Ln; *)
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

		PROCEDURE StoreRange(w : Streams.Writer; VAR range : GlyphRange);
		VAR i : LONGINT;
		BEGIN
			(* sanity check *)
			KernelLog.String("Store range: ");
			KernelLog.Hex(range.firstCode, 8); KernelLog.String(".."); KernelLog.Hex(range.lastCode, 8);
			KernelLog.Ln;
			w.Net16(range.lastCode - range.firstCode);
			FOR i := 0 TO range.lastCode - range.firstCode DO WritePackedGlyph(w, range.glyphs[i]) END;
		END StoreRange;

		PROCEDURE LoadRange(f : Files.File; rangeIndex : LONGINT);
		VAR r : Files.Reader;
			size, i : LONGINT;
			range : GlyphRange; (* because of too complex expression otherwise ;-) *)
		BEGIN
			range := glyphRanges[rangeIndex];
			KernelLog.String("Loading range "); KernelLog.Hex(range.firstCode, 8);
			KernelLog.String(".."); KernelLog.Hex(range.lastCode, 8);
			KernelLog.Ln;
			(* glyphRanges[rangeIndex].glyphs in the new statement may not be replaced with range! *)
			NEW(glyphRanges[rangeIndex].glyphs, range.lastCode - range.firstCode + 1);
			NEW(r, f, range.filePos);
			(* sanity check *)
			size := r.Net16(); ASSERT(size = glyphRanges[rangeIndex].lastCode - glyphRanges[rangeIndex].firstCode);
				(* glyphRanges[rangeIndex].glyphs in the following loop may not be replaced with range! *)
			FOR i := 0 TO size DO ReadPackedGlyph(r, glyphRanges[rangeIndex].glyphs[i]) END
		END LoadRange;

		PROCEDURE GetGlyph(ucs, variant : LONGINT) : Glyph;
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
				KernelLog.String("Range not found"); KernelLog.Ln;
				RETURN NIL
			END
		END GetGlyph;

		PROCEDURE Save(CONST fileName : ARRAY OF CHAR);
		VAR f : Files.File;
			w : Files.Writer;
			i : LONGINT;
		BEGIN
			f := Files.New(fileName);
			Files.Register(f);
			Files.OpenWriter(w, f, 0);
			(* number of ranges *)
			w.Net32(LEN(glyphRanges));
			(* reserve space for ranges *)
			FOR i := 0 TO LEN(glyphRanges) - 1 DO
				w.Net32(0); w.Net32(0); w.Net32(0)
			END;
			(* write glyphs *)
			FOR i := 0 TO LEN(glyphRanges) - 1 DO
				KernelLog.String("Writing range "); KernelLog.Int(i, 4); KernelLog.String(" of "); KernelLog.Int(LEN(glyphRanges), 4);
				KernelLog.Ln;
				w.Update();
				glyphRanges[i].filePos := w.sent;
				StoreRange(w, glyphRanges[i]);
			END;
			w.Update();
			(* fixup ranges *)
			Files.OpenWriter(w, f, 4);
			FOR i := 0 TO LEN(glyphRanges) - 1 DO
				w.Net32(glyphRanges[i].firstCode); w.Net32(glyphRanges[i].lastCode); w.Net32(glyphRanges[i].filePos)
			END;
			w.Update
		END Save;

		PROCEDURE Load(CONST fileName : ARRAY OF CHAR);
		VAR
			r : Files.Reader;
			i, nofRanges : LONGINT;
			ptr :ANY; glyph, tg : Glyph;
		BEGIN
			fontFile := Files.Old(fileName);
			Files.OpenReader(r, fontFile, 0);
			nofRanges := r.Net32();
			NEW(glyphRanges, nofRanges);
			KernelLog.String("Loaded ranges..."); KernelLog.Ln;
			FOR i := 0 TO nofRanges - 1 DO
				glyphRanges[i].firstCode := r.Net32(); glyphRanges[i].lastCode := r.Net32(); glyphRanges[i].filePos := r.Net32()
				; DumpRange(glyphRanges[i])
			END;
			KernelLog.String("Ranges Loaded."); KernelLog.Ln;
			glyphList.Lock;
			FOR i := 0 TO glyphList.GetCount() - 1 DO
				ptr := glyphList.GetItem(i); glyph := ptr(Glyph);
				tg := GetGlyph(glyph.ucs, glyph.variant);
				IF tg = NIL THEN KernelLog.String("Not loaded : "); KernelLog.Hex(glyph.ucs, 8); KernelLog.Int(glyph.variant, 5); KernelLog.Ln
				END
			END;
			glyphList.Unlock;
			KernelLog.String("done."); KernelLog.Ln
		END Load;

		PROCEDURE DumpRange(VAR r : GlyphRange);
		VAR i : LONGINT; tg : Glyph;
		BEGIN
			KernelLog.String("Range: "); KernelLog.Hex(r.firstCode, 0); KernelLog.String(" .. "); KernelLog.Hex(r.lastCode, 0); KernelLog.Ln;
			IF r.glyphs # NIL THEN
				FOR i := r.firstCode TO r.lastCode DO
					ASSERT(r.glyphs[i - r.firstCode].ucs = i);
					IF r.glyphs[i - r.firstCode].nextVariant # NIL THEN
						KernelLog.Hex(i, 0); KernelLog.String(" has variants : ");
						tg := r.glyphs[i - r.firstCode].nextVariant;
						WHILE tg # NIL DO KernelLog.Hex(i, 0); KernelLog.String(", "); tg := tg.nextVariant END;
						KernelLog.Ln
					END
				END
			ELSE KernelLog.String("Glpyhs not loaded."); KernelLog.Ln
			END
		END DumpRange;

		PROCEDURE CreateRanges;
		VAR i, j: LONGINT;
			nofRanges, code, lastCode, rangeStart, range, firstIndex, rangeSize : LONGINT;
			glyph, tg : Glyph; ptr : ANY;
			bimboSortArray : GlyphArray;

			PROCEDURE FillRange(VAR range : GlyphRange; startIndex, endIndex : LONGINT);
			VAR glyph, tg : Glyph; i : LONGINT;
			BEGIN
				range.firstCode := bimboSortArray[startIndex].ucs;
				range.lastCode := bimboSortArray[endIndex].ucs;

				NEW(range.glyphs, range.lastCode - range.firstCode + 1);
				FOR i := startIndex TO endIndex DO
					glyph := bimboSortArray[i];
					IF range.glyphs[glyph.ucs - range.firstCode] = NIL THEN
						range.glyphs[glyph.ucs - range.firstCode] := glyph
					ELSE
						tg := range.glyphs[glyph.ucs - range.firstCode];
						WHILE tg.nextVariant # NIL DO tg := tg.nextVariant END;
						tg.nextVariant := glyph
					END;
				END;
			END FillRange;

(*
			PROCEDURE CheckAllSorted;
			VAR ptr : ANY; glyph : Glyph; i : LONGINT;
			BEGIN
				KernelLog.String("Searching all glyphs in the sorted array...");
				FOR i := 0 TO glyphList.GetCount() - 1 DO
					ptr := glyphList.GetItem(i); glyph := ptr(Glyph);
					found := FALSE; j := 0;
					WHILE ~found & (j < glyphList.GetCount()) DO
						found := glyph = bimboSortArray[j];
						INC(j)
					END;
					IF ~found THEN
						KernelLog.String("Not found:"); KernelLog.Hex(glyph.ucs, 5); KernelLog.String("v"); KernelLog.Int(glyph.variant, 5);
						KernelLog.Ln;
						HALT(123456);
					END;
				END;
				KernelLog.String("done."); KernelLog.Ln;
			END CheckAllSorted;
*)

			PROCEDURE CheckAllInRanges;
			VAR ptr : ANY; glyph, tg : Glyph; i : LONGINT;
			BEGIN
				KernelLog.String("Searching all glyphs...");
				FOR i := 0 TO glyphList.GetCount() - 1 DO
					ptr := glyphList.GetItem(i); glyph := ptr(Glyph);
					tg := GetGlyph(glyph.ucs, glyph.variant);
					IF tg = NIL THEN
						KernelLog.String("Not found:"); KernelLog.Hex(glyph.ucs, 5); KernelLog.String("v"); KernelLog.Int(glyph.variant, 5);
						HALT(8888)
					ELSIF tg # glyph THEN
						KernelLog.String("Multiple defined:"); KernelLog.Hex(glyph.ucs, 5); KernelLog.String("v"); KernelLog.Int(glyph.variant, 5);
						HALT(8888)
					END;
				END;
				KernelLog.String("done."); KernelLog.Ln;
			END CheckAllInRanges;

		BEGIN
			KernelLog.String("Creating ranges..."); KernelLog.Ln;
			glyphList.Lock;
			(* Sort *)
			KernelLog.String("Sorting...");
			NEW(bimboSortArray, glyphList.GetCount());
			ptr := glyphList.GetItem(0); bimboSortArray[0] := ptr(Glyph);
			FOR i := 1 TO glyphList.GetCount() - 1 DO
				ptr := glyphList.GetItem(i); tg := ptr(Glyph);
				(* insertion sort... (run once software ;-) ) *)
				j := i;
				WHILE (j >= 1) & ((tg.ucs < bimboSortArray[j - 1].ucs) OR
					((tg.ucs = bimboSortArray[j - 1].ucs) & (tg.variant < bimboSortArray[j - 1].variant))) DO
					bimboSortArray[j] := bimboSortArray[j - 1];
					DEC(j);
				END;
				bimboSortArray[j] := tg
			END;
			KernelLog.String("done."); KernelLog.Ln;

			(* Sanity check *)
			(* CheckAllSorted; *)

			(* identify ranges *)
			lastCode := -1; nofRanges := 0; rangeSize := 0;
			FOR i := 0 TO glyphList.GetCount() - 1 DO
				glyph := bimboSortArray[i]; code := glyph.ucs;
				ASSERT(lastCode  <= code, 12345);
						IF (code = lastCode + 1) THEN INC(rangeSize) END;
				IF  (lastCode > -1) &
					((code # lastCode + 1) & (code # lastCode) OR (code = lastCode + 1) & (rangeSize > MaxRangeSize)) THEN
						INC(nofRanges); rangeSize := 0;
						lastCode := -1;
				END;lastCode := code
			END;
			INC(nofRanges);

			(* create ranges *)
			NEW(glyphRanges, nofRanges);
			KernelLog.String("Generated "); KernelLog.Int(nofRanges, 5); KernelLog.String(" ranges."); KernelLog.Ln;

			(* fill ranges *)
			KernelLog.String("Filling ranges... ");
			range := 0; lastCode := -1; rangeSize := 0; firstIndex := 0;
			FOR i := 0 TO glyphList.GetCount() - 1 DO
				glyph := bimboSortArray[i]; code := glyph.ucs;
				IF lastCode = -1 THEN rangeStart := code; END;
						IF (code = lastCode + 1) THEN INC(rangeSize) END;
				IF  (lastCode > -1) &
					((code # lastCode + 1) & (code # lastCode) OR (code = lastCode + 1) & (rangeSize > MaxRangeSize)) THEN
					glyphRanges[range].firstCode := rangeStart;
					glyphRanges[range].lastCode := lastCode;

					(* sanity check *)
					FOR j := firstIndex TO i - 1 DO
						IF (bimboSortArray[j].ucs < glyphRanges[range].firstCode) OR
							(bimboSortArray[j].ucs > glyphRanges[range].lastCode) THEN
							KernelLog.String("Stupid!!!"); KernelLog.Int(bimboSortArray[j].ucs, 5); KernelLog.Ln
						END;
					END;

					FillRange(glyphRanges[range], firstIndex, i - 1);
					DumpRange(glyphRanges[range]);
					INC(range);
					firstIndex := i;
					rangeSize := 0; rangeStart := code
				END; lastCode := code
			END;
			FillRange(glyphRanges[range], firstIndex,  glyphList.GetCount() - 1);
			DumpRange(glyphRanges[range]);
			KernelLog.String("done."); KernelLog.Ln;

			(* Sanity check *)
			CheckAllInRanges;
			glyphList.Unlock;
			KernelLog.String("Done."); KernelLog.Ln;
		END CreateRanges;

(* END optimized routines for native font *)

		PROCEDURE FindGlyph(ucs, variant : LONGINT) : Glyph;
		VAR g, tg : Glyph; i : LONGINT; ptr : ANY;
		BEGIN
			g := NIL;
			glyphList.Lock;
			i := 0; WHILE (i < glyphList.GetCount()) & (g = NIL) DO
				ptr := glyphList.GetItem(i);
				tg := ptr(Glyph);
				IF (tg.ucs = ucs) & (tg.variant = variant) THEN g := tg END;
				INC(i)
			END;
			glyphList.Unlock;
			RETURN g
		END FindGlyph;

		PROCEDURE FindGlyphSubComponent(VAR ref : GlyphRef) : Glyph;
		BEGIN
			IF ref.refPtr # NIL THEN RETURN ref.refPtr END;
			ref.refPtr := FindGlyph(ref.refucs, ref.refvariant);
			RETURN ref.refPtr
		END FindGlyphSubComponent;

		PROCEDURE GetNCharHex(r : Streams.Reader; nofChars : LONGINT) : LONGINT;
		VAR c : CHAR; i, res : LONGINT;
		BEGIN
			res := 0;
			FOR i := 0 TO nofChars - 1 DO
				c := r.Get();
				IF (c >= "0") & (c <= "9") THEN res := res * 16 + (ORD(c)-ORD("0"))
				ELSE res := res * 16 + (ORD(CAP(c))-ORD("A") + 10)
				END
			END;
			RETURN res
		END GetNCharHex;

		(* read "XXXXXXVV|NNv=", where
			XXXXXX UCS32 (ascii-hex),
			VV variant (ascii-hex),
			| fix separator,
			NN variable sized UTF-8 encoded UCS32 value,
			VV VV
			= fix separator *)
		PROCEDURE ReadUCSVariant(r : Streams.Reader; VAR ucs, variant : LONGINT);
		VAR c : CHAR; tucs, tv : LONGINT;
		BEGIN
			ucs := GetNCharHex(r, 6);
			variant := GetNCharHex(r, 2);
			 (* sanity check *)
			c := r.Get(); ASSERT(c = "|");
			IF ~GetUTF8Char(r, tucs) THEN HALT(1000) END; ASSERT(tucs = ucs);
			tv := GetNCharHex(r, 2); ASSERT(tv = variant);
			c := r.Get(); ASSERT(c = "=")
		END ReadUCSVariant;

		PROCEDURE ReadStrokes(r : Streams.Reader; g : Glyph);
		VAR i : LONGINT;
			PROCEDURE ReadStrokeElement;
			VAR c : CHAR;
			BEGIN
				c := r.Get(); ASSERT(c = "0");
				c := r.Get(); ASSERT(c = "0");
				(* read command *)
				workStrokes[nofStrokes].cmd := GetNCharHex(r, 2);
				workStrokes[nofStrokes].x := GetNCharHex(r, 2);
				workStrokes[nofStrokes].y := GetNCharHex(r, 2);
				INC(nofStrokes);
			END ReadStrokeElement;
		BEGIN
			nofStrokes := 0;
			WHILE r.Peek() = "0" DO ReadStrokeElement END;
			NEW(g.strokes, nofStrokes);
			g.nofStrokes := nofStrokes;
			FOR i := 0 TO nofStrokes - 1 DO g.strokes[i] := workStrokes[i] END
		END ReadStrokes;

		PROCEDURE ReadBasicGlyph(r : Streams.Reader; g : Glyph);
		VAR ch : CHAR;
		BEGIN
			ch := r.Get(); ASSERT(ch = "!");
			ReadUCSVariant(r, g.ucs, g.variant);
			ReadStrokes(r, g);
			r.SkipLn
		END ReadBasicGlyph;

		PROCEDURE ReadGlyphComponents(r: Streams.Reader; g : Glyph);
		VAR i : LONGINT;
			PROCEDURE ReadComponent;
			BEGIN
				workGlyphRef[nofGlyphRefs].x := GetNCharHex(r, 2);
				workGlyphRef[nofGlyphRefs].y := GetNCharHex(r, 2);
				workGlyphRef[nofGlyphRefs].w := GetNCharHex(r, 2);
				workGlyphRef[nofGlyphRefs].h := GetNCharHex(r, 2);
				INC(nofGlyphRefs)
			END ReadComponent;
		BEGIN
			nofGlyphRefs := 0;
			WHILE (r.Peek() > " ") DO
				IF GetUTF8Char(r, workGlyphRef[nofGlyphRefs].refucs) THEN
					workGlyphRef[nofGlyphRefs].refvariant := GetNCharHex(r, 2);
					ReadComponent
				END
			END;
			NEW(g.subComponents, nofGlyphRefs);
			g.nofSubComponents := nofGlyphRefs;
			FOR i := 0 TO nofGlyphRefs - 1 DO g.subComponents[i] := workGlyphRef[i] END
		END ReadGlyphComponents;

		PROCEDURE ReadCompositGlyph(r : Streams.Reader; g : Glyph);
		VAR ch : CHAR;
		BEGIN
			ch := r.Get(); ASSERT(ch = " ");
			ReadUCSVariant(r, g.ucs, g.variant);
			ReadGlyphComponents(r, g);
			r.SkipLn
		END ReadCompositGlyph;

		PROCEDURE ParseGlyph(r : Streams.Reader) : Glyph;
		VAR new : Glyph;
		BEGIN
			NEW(new);
			IF r.Peek() = "!" THEN ReadBasicGlyph(r, new);
			ELSE ReadCompositGlyph(r, new)
			END;
			RETURN new
		END ParseGlyph;

		PROCEDURE LoadFromStream*(r : Streams.Reader) : BOOLEAN;
		BEGIN
			KernelLog.String("Loading all glyphs..."); KernelLog.Ln;
			WHILE (r.Peek() >= " ") & (r.res = 0) DO
				glyphList.Add(ParseGlyph(r));
				IF glyphList.GetCount() MOD 10000 = 0 THEN KernelLog.Int(glyphList.GetCount(), 5); KernelLog.Ln END
			END;
			KernelLog.Int(glyphList.GetCount(), 5); KernelLog.Ln;
			KernelLog.String("Finished."); KernelLog.Ln;
			RETURN TRUE
		END LoadFromStream;

		PROCEDURE LoadFromFile*(CONST fileName : ARRAY OF CHAR) : BOOLEAN;
		VAR f : Files.File; r : Files.Reader;
		BEGIN
			f := Files.Old(fileName);
			IF f = NIL THEN RETURN FALSE END;
			Files.OpenReader(r, f, 0);
			RETURN LoadFromStream(r)
		END LoadFromFile;
	END RawCCGFont;


VAR testWindow : TestWindow;

PROCEDURE Open*;
VAR f : RawCCGFont;
BEGIN
	IF testWindow = NIL THEN
		NEW(f);
		IF f.LoadFromFile("song.fnt") THEN NEW(testWindow, f); KernelLog.String("done.") ELSE KernelLog.String("failed.") END;
	END;
END Open;

PROCEDURE Export*;
BEGIN
	IF testWindow # NIL THEN
		testWindow.font.CreateRanges;
		testWindow.font.Save("Song.ccg");
		testWindow.font.Load("Song.ccg");
	END;
END Export;

(* read a UTF8 character form a stream *)
PROCEDURE GetUTF8Char(r : Streams.Reader; VAR u : LONGINT) : BOOLEAN;
VAR ch : ARRAY 8 OF CHAR; i : LONGINT;
BEGIN
	ch[0] := r.Get();
	FOR i := 1 TO ORD(UTF8Strings.CodeLength[ORD(ch[0])]) - 1 DO ch[i] := r.Get() END;
	i := 0;
	RETURN UTF8Strings.DecodeChar(ch, i, u)
END GetUTF8Char;

(*
PROCEDURE Spline(canvas : WMGraphics.Canvas; x0, y0, x1, y1, x2, y2, x, y, w, h, color, mode : LONGINT);
VAR i, tx, ty, nx, ny : LONGINT;
	t, onet, dt : REAL; (* CHECK : possible fixed-point implementation*)
BEGIN
	tx := x0; ty := y0;
	dt := 1 / MaxSplineSeg; t := 0; onet := 1;
	FOR i := 0 TO MaxSplineSeg DO
		nx := ENTIER(onet * onet * x0 + 2 * t * onet * x1 + t * t * x2);
		ny := ENTIER(onet * onet * y0 + 2 * t * onet * y1 + t * t * y2);
		canvas.Line(x + (tx * w) DIV 256, y + (ty * h) DIV 256, x + (nx * w) DIV 256, y + (ny * h) DIV 256, color, mode);
		t := t + dt; onet := 1 - t; tx := nx; ty := ny
	END
END Spline;
*)

PROCEDURE SplineReal(canvas : WMGraphics.Canvas; x0, y0, x1, y1, x2, y2, x, y, w, h : REAL; color, mode : LONGINT);
VAR i: LONGINT;  tx, ty, nx, ny : REAL;
	t, onet, dt : REAL;
BEGIN
	tx := x0; ty := y0;
	dt := 1 / MaxSplineSeg; t := 0; onet := 1;
	FOR i := 0 TO MaxSplineSeg DO
		nx := ENTIER(onet * onet * x0 + 2 * t * onet * x1 + t * t * x2);
		ny := ENTIER(onet * onet * y0 + 2 * t * onet * y1 + t * t * y2);
		canvas.Line(ENTIER(x + (tx * w) / 256), ENTIER(y + (ty * h) / 256),
		ENTIER(x + (nx * w) / 256), ENTIER(y + (ny * h) / 256), color, mode);
		t := t + dt; onet := 1 - t; tx := nx; ty := ny
	END
END SplineReal;

PROCEDURE Cleanup;
BEGIN
	IF testWindow # NIL THEN testWindow.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMFontCCGConverter.


Aos.Call WMFontCCGConverter.Open ~
Aos.Call WMFontCCGConverter.Export ~
System.Free WMFontCCGConverter ~
OFSTools.Mount RAM RamFS 4096 4096 ~
Hex.Open RAM:Single.ccg ~
System.Directory RAM:Single.ccg\d ~