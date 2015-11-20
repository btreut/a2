(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxFonts; (** non-portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "Gfx font engine"; *)

	(*
		8.1.98 - GetInstance now transforms an existing bounding box correctly
		13.1.98 - bug fix in OpenRaster, font.ymax was not computed correctly for scaled raster fonts in OpenRaster
		13.1.98 - improved GetStringWidth; uses outline metrics now if images would be taken from outline, too
		9.2.98 - adapted SplineToBezier to new behaviour of GfxPaths.EnumSpline (no Enter/Exit)
		18.9.98 - major cleanup of both interface and implementation (support for other font formats, switch to GfxMaps,
			aging of cached chars, use GfxFonts0 to enumerate available raster fonts)
		9.12.98 - raster files; adaptation to new GfxMaps
		16.2.99 - bugfix in InitDefault (m[1, 1] wasn't set), tnx to pjm
		12.3.99 - bugfix in WFGetWidth (dy = dx)
		20.4.99 - put point size in separate field instead of merging it with font matrix
		8.6.99 - don't set niceMaps for large raster fonts if outline exists
		16.7.99 - try to open raster font before calling extensions
		25.8.99 - use Images and GfxImages instead of GfxMaps, PictImages instead of GfxPictures
		28.10.99 - WarpMap doesn't try to create empty images anymore
		21.02.2000 - introduced registered font families to improve opening foreign font file formats
		14.03.2000 - improved wildcard handling for registered font families (key without value is command)
		30.03.2000 - accept "M.P=*" as wildcard
		24.05.2000 - integrated GfxFonts0, no longer imports Fonts, for the moment no registered extensions
	*)

	IMPORT
		SYSTEM, KernelLog, Commands, Files, Configuration, Math, Raster, GfxMatrix,
		GfxImages, GfxPaths, GfxRegions;


	CONST
		FontNameLen* = 64;
		MaxCachedChars = 512;	(* maximal number of cached characters *)
		MetaFontTag = 01F7H; OldMetaFontTag = 701H - 1000H;	(* = F701H *)
		MaxBezierPoints = 3*GfxPaths.MaxSplinePoints + 1;
		DPI = 91.44;
		FontId = 0DBX;


	TYPE
		FontName* = ARRAY FontNameLen OF CHAR;

		(* Metafont outlines **)
		Outline = POINTER TO OutlineDesc;
		OutlineDesc = RECORD
			width: ARRAY 256 OF REAL;	(* width including left and right side bearings (0 if character undefined) *)
			len: ARRAY 256 OF SHORTINT;	(* number of subpaths of each character *)
			path: GfxPaths.Path;	(* path containing character outlines *)
			pos: ARRAY 256 OF INTEGER;	(* positions of characters within path *)
			xmin, ymin, xmax, ymax: REAL;	(* union of character bounding boxes *)
		END;

		(* cached characters *)
		Char = POINTER TO CharDesc;
		CharDesc = RECORD
			x, y, dx, dy: REAL;	(* metrics *)
			map: Raster.Image;	(* pixels *)
			used: INTEGER;	(* number of accesses to this character *)
		END;

		(* raster file *)
		RasterChar = POINTER TO RasterCharDesc;
		RasterCharDesc = RECORD
			dx, x, y, w, h: INTEGER;
			adr: ADDRESS;
		END;
		RasterFile = POINTER TO RasterFileDesc;
		RasterFileDesc = RECORD
			xmin, ymin, xmax, ymax: INTEGER;
			char: ARRAY 256 OF RasterChar;
			mem: POINTER TO ARRAY OF CHAR;
		END;

		(** font structure **)
		Font* = POINTER TO FontDesc;
		Methods* = POINTER TO MethodDesc;
		FontDesc* = RECORD
			class*: Methods;
			name*: FontName;	(** font name **)
			ptsize*: INTEGER;	(** point size **)
			mat*, wmat: GfxMatrix.Matrix;	(** font matrix **)
			xmin*, ymin*, xmax*, ymax*: INTEGER;	(** union of character bounding boxes **)
			niceMaps*: BOOLEAN;	(** true if returned bitmaps look better than the filled outlines **)
			outline: Outline;	(* outline, if available *)
			prev, next: Font;	(* previous and next font in font cache *)
			char: ARRAY 256 OF Char;	(* cached characters *)
			rfile: RasterFile;	(* link to raster file *)
		END;

		MethodDesc* = RECORD
			derive*: PROCEDURE (font: Font; ptsize: INTEGER; VAR mat: GfxMatrix.Matrix): Font;
			getwidth*: PROCEDURE (font: Font; ch: CHAR; VAR dx, dy: REAL);
			getmap*: PROCEDURE (font: Font; ch: CHAR; VAR x, y, dx, dy: REAL; VAR map: Raster.Image);
			getoutline*: PROCEDURE (font: Font; ch: CHAR; x, y: REAL; path: GfxPaths.Path);
		END;

		PathEnumData = RECORD (GfxPaths.EnumData)
			xc, yc: ARRAY MaxBezierPoints OF REAL;	(* control points for spline-Bezier conversion *)
			n: INTEGER;	(* number of control points *)
			lx, ly: REAL;	(* current point for converting path to region *)
			px, py: INTEGER;	(* current region point coordinates *)
			region: GfxRegions.Region;
		END;

		RegEnumData = RECORD (GfxRegions.EnumData)
			map: Raster.Image;
			dx, dy: INTEGER;
		END;


	VAR
		Default*: Font;	(** system default font **)
		OpenProc*: PROCEDURE (VAR family, style: ARRAY OF CHAR; ptsize: INTEGER; VAR mat: GfxMatrix.Matrix): Font;
		FClass, OFClass, WFClass, OWFClass, OClass: Methods;	(* builtin font classes *)
		Cache: Font;	(* sentinel for list of cached fonts *) (* RACE ?*)
		Chars: LONGINT;	(* current number of cached characters *)
	(*	TmpPath: GfxPaths.Path;
		TmpRegion: GfxRegions.Region; *)

	(*--- File Directory ---*)

	PROCEDURE Append(VAR to(** in/out *): ARRAY OF CHAR; this: ARRAY OF CHAR);
		VAR i, j, l: LONGINT;
	BEGIN
		i := 0;
		WHILE to[i] # 0X DO
			INC(i)
		END;
		l := LEN(to)-1; j := 0;
		WHILE (i < l) & (this[j] # 0X) DO
			to[i] := this[j]; INC(i); INC(j)
		END;
		to[i] := 0X
	END Append;

	PROCEDURE AppendCh(VAR to(** in/out *): ARRAY OF CHAR; this: CHAR);
		VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE to[i] # 0X DO
			INC(i)
		END;
		IF i < (LEN(to)-1) THEN
			to[i] := this; to[i+1] := 0X
		END
	END AppendCh;

	PROCEDURE IntToStr(val: LONGINT; VAR str: ARRAY OF CHAR);
		VAR
			i, j: LONGINT;
			digits: ARRAY 16 OF LONGINT;
	BEGIN
		IF val = MIN(LONGINT) THEN
			COPY("-2147483648", str);
			RETURN
		END;
		IF val < 0 THEN
			val := -val; str[0] := "-"; j := 1
		ELSE
			j := 0
		END;
		i := 0;
		REPEAT
			digits[i] := val MOD 10; INC(i); val := val DIV 10
		UNTIL val = 0;
		DEC(i);
		WHILE i >= 0 DO
			str[j] := CHR(digits[i]+ORD("0")); INC(j); DEC(i)
		END;
		str[j] := 0X
	END IntToStr;

	PROCEDURE Find (VAR family, style: ARRAY OF CHAR; sppm: INTEGER; VAR fname: ARRAY OF CHAR; VAR fppm: INTEGER);
		VAR
			enum: Files.Enumerator; i, time, date, size: LONGINT; error, ppm: INTEGER;
			s: ARRAY 4 OF CHAR; pattern: ARRAY 64 OF CHAR; name: Files.FileName; flags: SET;
	BEGIN
		fname[0] := 0X; fppm := 0;
		error := MAX(INTEGER);
		COPY(family, pattern); AppendCh(pattern, "*");
		IF style = "Bold" THEN AppendCh(pattern, "b")
		ELSIF style = "Italic" THEN AppendCh(pattern, "i")
		ELSIF style = "Medium" THEN AppendCh(pattern, "m")
		ELSIF style = "BoldItalic" THEN AppendCh(pattern, "j")
		END;
		Append(pattern, ".*.Fnt");
		NEW(enum); enum.Open(pattern, {});
		WHILE (error # 0) & enum.GetEntry(name, flags, time, date, size) DO
			i := 0; ppm := 0;
			WHILE (name[i] # 0X) & (name[i] # ".") & (name[i] < "0") OR ("9" < name[i]) DO INC(i) END;
			WHILE ("0" <= name[i]) & (name[i] <= "9") DO
				ppm := 10*ppm + ORD(name[i]) - ORD("0");
				INC(i)
			END;
			IF ppm = 0 THEN ppm := 10 END;
			IF (style = "") & (name[i] = ".") OR (CAP(style[0]) = CAP(name[i])) THEN
				WHILE (name[i] # 0X) & (name[i] # ".") DO INC(i) END;
				IF name[i] = "." THEN INC(i) END;
				s[0] := name[i]; s[1] := name[i+1]; s[2] := name[i+2]; s[3] := 0X;
				IF s = "Scn" THEN
				ELSIF s = "Pr2" THEN ppm := SHORT(200 * LONG(ppm) DIV 91)
				ELSIF s = "Pr3" THEN ppm := SHORT(300 * LONG(ppm) DIV 91)
				ELSIF s = "Pr6" THEN ppm := SHORT(600 * LONG(ppm) DIV 91)
				ELSE ppm := MIN(INTEGER)
				END;
				IF ABS(sppm - ppm) < error THEN
					error := ABS(sppm - ppm); COPY(name, fname); fppm := ppm
				END
			END
		END;
		enum.Close
	END Find;


	(*--- Outlines ---*)

	(* append path element to Bezier control points *)
	PROCEDURE AddSplineElem (VAR data: GfxPaths.EnumData);
		CONST
			sqrt3 = 1.7320508; t = 4/3*(sqrt3 - 1);
		VAR
			rx, ry, trx, try: REAL;
	BEGIN
		WITH data: PathEnumData DO
			CASE data.elem OF
			| GfxPaths.Line:	(* spline is line *)
				data.xc[data.n] := data.x; data.yc[data.n] := data.y; INC(data.n)
			| GfxPaths.Arc:	(* spline is full circle *)
				rx := data.x - data.x0; ry := data.y - data.y0;
				trx := t * rx; try := t * ry;
				data.xc[data.n] := data.x0 + rx - try; data.yc[data.n] := data.y0 + ry + trx; INC(data.n);
				data.xc[data.n] := data.x0 - ry + trx; data.yc[data.n] := data.y0 + rx + try; INC(data.n);
				data.xc[data.n] := data.x0 - ry; data.yc[data.n] := data.y0 + rx; INC(data.n);
				data.xc[data.n] := data.x0 - ry - trx; data.yc[data.n] := data.y0 + rx + try; INC(data.n);
				data.xc[data.n] := data.x0 - rx - try; data.yc[data.n] := data.y0 - ry + trx; INC(data.n);
				data.xc[data.n] := data.x0 - rx; data.yc[data.n] := data.y0 - ry; INC(data.n);
				data.xc[data.n] := data.x0 - rx + try; data.yc[data.n] := data.y0 - ry - trx; INC(data.n);
				data.xc[data.n] := data.x0 + ry - trx; data.yc[data.n] := data.y0 - rx - try; INC(data.n);
				data.xc[data.n] := data.x0 + ry; data.yc[data.n] := data.y0 - rx; INC(data.n);
				data.xc[data.n] := data.x0 + ry + trx; data.yc[data.n] := data.y0 - rx + try; INC(data.n);
				data.xc[data.n] := data.x0 + rx + try; data.yc[data.n] := data.y0 + ry - trx; INC(data.n);
				data.xc[data.n] := data.x0 + rx; data.yc[data.n] := data.y0 + ry; INC(data.n)
			| GfxPaths.Bezier:
				data.xc[data.n] := data.x1; data.yc[data.n] := data.y1; INC(data.n);
				data.xc[data.n] := data.x2; data.yc[data.n] := data.y2; INC(data.n);
				data.xc[data.n] := data.x; data.yc[data.n] := data.y; INC(data.n)
			END
		END
	END AddSplineElem;

	(* convert natural spline to Bezier control points *)
	PROCEDURE SplineToBezier (VAR x, y: ARRAY OF REAL; VAR n: LONGINT; closed: BOOLEAN);
		VAR data: PathEnumData;
	BEGIN
		data.n := 1; data.x := x[0]; data.y := y[0];
		GfxPaths.EnumSpline(x, y, SHORT(n), closed, AddSplineElem, data);
		n := 1;
		WHILE n < data.n DO
			x[n] := data.xc[n]; y[n] := data.yc[n]; INC(n)
		END
	END SplineToBezier;

	(* convert Bezier2 to Bezier *)
	PROCEDURE Bezier2ToBezier (VAR x, y: ARRAY OF REAL; VAR n: LONGINT);
		VAR nout, m: LONGINT;
	BEGIN
		IF ODD(n) THEN
			nout := (n - 1) DIV 2 * 3 + 1;
			m := nout
		ELSE	(* ends with line *)
			nout := (n - 2) DIV 2 * 3 + 2;
			m := nout-1;
			x[m] := x[n-1]; y[m] := y[n-1]
		END;
		WHILE m > 0 DO
			DEC(m); DEC(n);
			x[m] := x[n]; y[m] := y[n];
			DEC(m); DEC(n);
			x[m] := (1/3)*(2*x[n] + x[m+1]); y[m] := (1/3)*(2*y[n] + y[m+1]);
			DEC(m);
			x[m] := (1/3)*(2*x[n] + x[n-1]); y[m] := (1/3)*(2*y[n] + y[n-1])
		END;
		n := nout
	END Bezier2ToBezier;

	(* load character outlines *)
		PROCEDURE LoadOutline (outline: Outline; VAR r: Files.Reader);
		CONST
			polygon = 0; bezier = 1; spline = 2; bezier2 = 3;
			maxNofContours = 128;

		VAR
			minY, maxY, base, i, y, ntypes, nchars, x, left, ncontours, n, m, cont, k: LONGINT; scale: REAL; ch: CHAR;
			type, pred, succ, last: ARRAY maxNofContours OF LONGINT; str: ARRAY 32 OF CHAR; kind: ARRAY 5 OF INTEGER;
			closed: BOOLEAN; px, py: POINTER TO ARRAY maxNofContours, MaxBezierPoints OF REAL;
			done: ARRAY maxNofContours OF BOOLEAN;

		PROCEDURE coincident (px, py, qx, qy: REAL; dist: LONGINT): BOOLEAN;
		BEGIN
			RETURN (ABS(px - qx) <= dist) & (ABS(py - qy) <= dist)
		END coincident;

	BEGIN
		minY := MAX(LONGINT); maxY := MIN(LONGINT); base := minY;
		FOR i := 1 TO 5 DO
			r.RawNum(y);
			IF y > maxY THEN maxY := y END;
			IF y < minY THEN base := minY; minY := y
			ELSIF y < base THEN base := y
			END
		END;
		scale := 1/(maxY - minY);

		NEW(outline.path);
		GfxPaths.Clear(outline.path);
		outline.xmin := MAX(REAL); outline.ymin := MAX(REAL);
		outline.xmax := MIN(REAL); outline.ymax := MIN(REAL);
		NEW(px); NEW(py);
		ntypes := 1;
		r.RawNum(nchars);
		WHILE nchars > 0 DO
			DEC(nchars);
			r.Char(ch); r.RawNum(x); left := x;
			r.RawNum(x);
			IF x >= left THEN
				outline.width[ORD(ch)] := scale * SHORT(x - left)
			ELSE
				outline.width[ORD(ch)] := scale * SHORT(left - x);
				left := x
			END;

			(* read contour curves *)
			r.RawNum(ncontours);
			n := 0;
			WHILE n < ncontours DO
				r.RawNum(type[n]);
				IF type[n] = ntypes THEN
					r.RawString(str);
					ASSERT(str = "Graphic");
					r.RawString(str);
					IF str = "PolygonDesc" THEN kind[type[n]] := polygon
					ELSIF str = "BezierDesc" THEN kind[type[n]] := bezier
					ELSIF str = "SplineDesc" THEN kind[type[n]] := spline
					ELSIF str = "Bezier2Desc" THEN kind[type[n]] := bezier2
					ELSE HALT(101)
					END;
					INC(ntypes)
				END;
				r.RawBool(closed);
				IF closed THEN pred[n] := n; succ[n] := n
				ELSE pred[n] := -1; succ[n] := -1
				END;
				r.RawNum(m);
				DEC(m);
				FOR i := 0 TO m DO
					r.RawNum(x); r.RawNum(y);
					px[n, i] := x - left; py[n, i] := y - base
				END;
				IF m < 1 THEN
					DEC(ncontours)
				ELSE
					IF closed THEN
						INC(m); px[n, m] := px[n, 0]; py[n, m] := py[n, 0]
					END;
					IF kind[type[n]] = spline THEN
						INC(m);
						SplineToBezier(px[n], py[n], m, closed);
						DEC(m)
					ELSIF kind[type[n]] = bezier2 THEN
						INC(m);
						Bezier2ToBezier(px[n], py[n], m);
						DEC(m)
					END;
					FOR i := 0 TO m DO
						IF px[n, i] < outline.xmin THEN outline.xmin := px[n, i] END;
						IF px[n, i] > outline.xmax THEN outline.xmax := px[n, i] END;
						IF py[n, i] < outline.ymin THEN outline.ymin := py[n, i] END;
						IF py[n, i] > outline.ymax THEN outline.ymax := py[n, i] END
					END;
					last[n] := m;
					INC(n)
				END
			END;
			outline.len[ORD(ch)] := SHORT(SHORT(ncontours));

			(* find connected curves *)
			FOR i := 0 TO 3 DO
				n := 0;
				WHILE n < outline.len[ORD(ch)] DO
					m := n + 1;
					WHILE (pred[n] < 0) & (m < outline.len[ORD(ch)]) DO
						IF (succ[m] < 0) & coincident(px[n, 0], py[n, 0], px[m, last[m]], py[m, last[m]], i) THEN
							px[m, last[m]] := px[n, 0]; py[m, last[m]] := py[n, 0];
							pred[n] := m; succ[m] := n
						END;
						INC(m)
					END;
					m := n + 1;
					WHILE (succ[n] < 0) & (m < outline.len[ORD(ch)]) DO
						IF (pred[m] < 0) & coincident(px[n, last[n]], py[n, last[n]], px[m, 0], py[m, 0], i) THEN
							px[n, last[n]] := px[m, 0]; py[n, last[n]] := py[m, 0];
							succ[n] := m; pred[m] := n
						END;
						INC(m)
					END;
					INC(n)
				END
			END;
			FOR cont := 0 TO outline.len[ORD(ch)] - 1 DO
				(*done[cont] := (succ[cont] < 0) OR (pred[cont] < 0)*)	(* ignore open curves *)
				done[cont] := FALSE
			END;

			(* append contour curves to path *)
			outline.pos[ORD(ch)] := outline.path.elems;
			cont := 0; k := 0;
			WHILE cont < outline.len[ORD(ch)] DO
				IF ~done[cont] THEN
					n := cont; m := pred[n];
					IF m < 0 THEN
						GfxPaths.AddEnter(outline.path, scale * px[n, 0], scale * py[n, 0], 0, 0)
					ELSE
						i := last[m];
						GfxPaths.AddEnter(outline.path, scale * px[n, 0], scale * py[n, 0], scale * (px[m, i] - px[m, i - 1]), scale * (py[m, i] - py[m, i - 1]))
					END;
					REPEAT
						i := 1;
						WHILE i <= last[n] DO
							IF (kind[type[n]] = polygon) OR (i+2 > last[n]) THEN
								GfxPaths.AddLine(outline.path, scale * px[n, i], scale * py[n, i]);
								INC(i)
							ELSE
								GfxPaths.AddBezier(outline.path, scale * px[n, i+2], scale * py[n, i+2], scale * px[n, i], scale * py[n, i],
								  scale * px[n, i+1], scale * py[n, i+1]);
								INC(i, 3)
							END
						END;
						done[n] := TRUE;
						n := succ[n]
					UNTIL (n < 0) OR (n = cont);
					IF n < 0 THEN
						GfxPaths.AddExit(outline.path, 0, 0)
					ELSE
						GfxPaths.AddExit(outline.path, scale * (px[n, 1] - px[n, 0]), scale * (py[n, 1] - py[n, 0]))
					END;
					INC(k)
				END;
				INC(cont)
			END;
			outline.len[ORD(ch)] := SHORT(SHORT(k))
		END;
		outline.xmin := scale * outline.xmin; outline.ymin := scale * outline.ymin;
		outline.xmax := scale * outline.xmax; outline.ymax := scale * outline.ymax
	END LoadOutline;


	(*--- Font Cache ---*)

	(* enter font in font cache *)
	PROCEDURE CacheFont (font: Font);
	BEGIN {EXCLUSIVE}
		font.prev := Cache.prev; Cache.prev.next := font;
		font.next := Cache; Cache.prev := font
	END CacheFont;

	(* put character into cache *)
	PROCEDURE CacheChar (font: Font; ch: CHAR; x, y, dx, dy: REAL; map: Raster.Image);
		VAR char: Char; n, m: LONGINT;
	BEGIN {EXCLUSIVE}
		NEW(char); font.char[ORD(ch)] := char;
		char.x := x; char.y := y; char.dx := dx; char.dy := dy; char.map := map;
		INC(Chars); char.used := 4;	(* extra bonus for new character in cache *)
		WHILE Chars = MaxCachedChars DO
			font := Cache.next;
			WHILE font # Cache DO
				n := 0; m := 0;
				WHILE n < 256 DO
					char := font.char[n];
					IF char # NIL THEN
						char.used := char.used DIV 2;	(* age number of uses *)
						IF char.used = 0 THEN	(* remove character from cache *)
							DEC(Chars); font.char[n] := NIL
						ELSE
							INC(m)
						END
					END;
					INC(n)
				END;
				IF m = 0 THEN	(* no characters cached => remove font from cache *)
					font.prev.next := font.next; font.next.prev := font.prev
				END;
				font := font.next
			END
		END
	END CacheChar;

	(* return cached character *)
	PROCEDURE CachedChar (font: Font; ch: CHAR): Char;
		VAR char: Char;
	BEGIN {EXCLUSIVE}
		char := font.char[ORD(ch)];
		IF char # NIL THEN INC(char.used) END;
		RETURN char
	END CachedChar;


	(**--- Fonts ---**)

	(* extract family and style from font name *)
	PROCEDURE SplitName (name: ARRAY OF CHAR; VAR fam, style: ARRAY OF CHAR);
		VAR i, j: LONGINT;
	BEGIN
		fam[0] := name[0];
		i := 1;
		WHILE (name[i] >= "a") & (name[i] <= "z") DO
			fam[i] := name[i];
			INC(i)
		END;
		fam[i] := 0X;
		WHILE (name[i] >= "0") & (name[i] <= "9") DO INC(i) END;
		IF (name[i] = "-") OR (name[i] = " ") THEN INC(i) END;
		j := 0;
		WHILE (name[i] # 0X) & (CAP(name[i]) >= "A") & (CAP(name[i]) <= "Z") DO
			style[j] := name[i];
			INC(i); INC(j)
		END;
		IF j = 1 THEN
			CASE CAP(style[0]) OF
			| "I": COPY("Italic", style)
			| "B": COPY("Bold", style)
			| "M": COPY("Medium", style)
			| "J": COPY("BoldItalic", style)
			ELSE style[1] := 0X
			END
		ELSE
			style[j] := 0X
		END
	END SplitName;

	(* create font name from family and style *)
	PROCEDURE BuildName (fam, style: ARRAY OF CHAR; VAR name: ARRAY OF CHAR);
	BEGIN
		COPY(fam, name);
		IF style # "" THEN
			AppendCh(name, "-");
			Append(name, style)
		END
	END BuildName;

	(* open MetaFont *)
	PROCEDURE OpenOutline (VAR family, style: ARRAY OF CHAR): Outline;
		VAR fname: FontName; file: Files.File; r: Files.Reader; tag: INTEGER; outline: Outline;
	BEGIN
		COPY(family, fname); Append(fname, style); Append(fname, ".MTF");
		file := Files.Old(fname);
		IF file # NIL THEN
			Files.OpenReader(r, file, 0);
			r.RawInt(tag);
			IF (tag = OldMetaFontTag) OR (tag = MetaFontTag) THEN
				NEW(outline); LoadOutline(outline, r);
				RETURN outline
			END
		END;
		RETURN NIL
	END OpenOutline;

	PROCEDURE LoadRaster (VAR name: ARRAY OF CHAR): RasterFile;
		VAR
			rfile: RasterFile; file: Files.File; r: Files.Reader; id, ch: CHAR; type: SHORTINT; height, runs, i, j: INTEGER;
			beg, end: ARRAY 32 OF INTEGER; size: LONGINT; adr: ADDRESS;
	BEGIN
		rfile := NIL;
		file := Files.Old(name);
		IF file = NIL THEN RETURN NIL END;
		Files.OpenReader(r, file, 0);
		r.Char(id); r.RawSInt(type);
		IF (id = FontId) & (type = 0) THEN
			NEW(rfile);
			r.Char(ch); r.Char(ch); r.RawInt(height);
			r.RawInt(rfile.xmin); r.RawInt(rfile.xmax);
			r.RawInt(rfile.ymin); r.RawInt(rfile.ymax);
			r.RawInt(runs);
			i := 0;
			WHILE i < runs DO
				r.RawInt(beg[i]); r.RawInt(end[i]); INC(i)
			END;
			i := 0; size := 0;
			WHILE i < runs DO
				j := beg[i];
				WHILE j < end[i] DO
					NEW(rfile.char[j]);
					r.RawInt(rfile.char[j].dx);
					r.RawInt(rfile.char[j].x); r.RawInt(rfile.char[j].y);
					r.RawInt(rfile.char[j].w); r.RawInt(rfile.char[j].h);
					size := size + (rfile.char[j].w + 7) DIV 8 * rfile.char[j].h;
					INC(j)
				END;
				INC(i)
			END;
			NEW(rfile.mem, size);
			i := 0; adr := ADDRESSOF(rfile.mem[0]);
			WHILE i < runs DO
				j := beg[i];
				WHILE j < end[i] DO
					rfile.char[j].adr := adr;
					size := (rfile.char[j].w + 7) DIV 8 * rfile.char[j].h;
					WHILE size > 0 DO
						r.Char(ch);
						SYSTEM.PUT(adr, ch);
						INC(adr); DEC(size)
					END;
					INC(j)
				END;
				INC(i)
			END
		END;
		RETURN rfile
	END LoadRaster;

	(* open raster font *)
	PROCEDURE OpenRaster (VAR family, style: ARRAY OF CHAR; ptsize: INTEGER; VAR mat: GfxMatrix.Matrix; outline: Outline): Font;
		VAR
			rfile: RasterFile; font: Font; scale, xmin, ymin, xmax, ymax: REAL; ppm, fppm: INTEGER;
			ext, pstr: ARRAY 9 OF CHAR; name: FontName;
	BEGIN
		rfile := NIL; font := NIL;
		scale := Math.sqrt(ABS(GfxMatrix.Det(mat)));

		(* look for exactly matching raster font *)
		IF scale < 2.5 THEN ppm := SHORT(ENTIER(ptsize * scale + 0.5)); ext := ".Scn.Fnt"
		ELSIF scale < 4.5 THEN ppm := SHORT(ENTIER(ptsize * scale * DPI/300 + 0.5)); ext := ".Pr3.Fnt"
		ELSE ppm := SHORT(ENTIER(ptsize * scale * DPI/600 + 0.5)); ext := ".Pr6.Fnt"
		END;
		COPY(family, name); fppm := ppm;
		IntToStr(ppm, pstr); Append(name, pstr);
		IF style = "BoldItalic" THEN AppendCh(name, "j")
		ELSIF style # "" THEN AppendCh(name, CHR(ORD(CAP(style[0])) - ORD("A") + ORD("a")))
		END;
		Append(name, ext);
		rfile := LoadRaster(name);

		(* check available raster font files *)
		IF rfile = NIL THEN
			ppm := SHORT(ENTIER(ptsize * scale + 0.5));
			Find(family, style, ppm, name, fppm);
			IF name # "" THEN
				rfile := LoadRaster(name)
			END
		END;

		IF rfile # NIL THEN	(* have raster font of requested family *)
			IF (fppm = ppm) & ~GfxMatrix.Rotated(mat) & (mat[0, 0] > 0) & (mat[1, 1] > 0) & (mat[0, 0] = mat[1, 1]) THEN
				NEW(font); font.outline := outline; font.rfile := rfile; font.niceMaps := (outline = NIL) OR (scale < 5);
				IF outline = NIL THEN font.class := FClass
				ELSE font.class := OFClass
				END;
				font.xmin := rfile.xmin; font.ymin := rfile.ymin; font.xmax := rfile.xmax; font.ymax := rfile.ymax
			ELSIF (outline = NIL) OR (scale < 2) THEN	(* use warped raster font *)
				NEW(font); font.outline := outline; font.rfile := rfile; font.niceMaps := TRUE;
				IF outline = NIL THEN font.class := WFClass
				ELSE font.class := OWFClass
				END;
				scale := 1/scale * ppm/fppm;
				GfxMatrix.Scale(mat, scale, scale, font.wmat);
				GfxMatrix.ApplyToRect(font.wmat, rfile.xmin, rfile.ymin, rfile.xmax, rfile.ymax, xmin, ymin, xmax, ymax);
				font.xmin := SHORT(ENTIER(xmin)); font.ymin := SHORT(ENTIER(ymin));
				font.xmax := -SHORT(ENTIER(-xmax)); font.ymax := -SHORT(ENTIER(-ymax))
			END
		END;

		IF (font = NIL) & (outline # NIL) THEN	(* use outline only, no raster *)
			NEW(font); font.class := OClass; font.outline := outline; font.niceMaps := FALSE;
			scale := ptsize * DPI/72.27;	(* scale to display resolution *)
			GfxMatrix.Scale(mat, scale, scale, font.wmat);
			GfxMatrix.ApplyToRect(font.wmat, outline.xmin, outline.ymin, outline.xmax, outline.ymax, xmin, ymin, xmax, ymax);
			font.xmin := SHORT(ENTIER(xmin)); font.ymin := SHORT(ENTIER(ymin));
			font.xmax := -SHORT(ENTIER(-xmax)); font.ymax := -SHORT(ENTIER(-ymax))
		END;

		RETURN font
	END OpenRaster;

	PROCEDURE OpenExtension (VAR family, style: ARRAY OF CHAR; ptsize: INTEGER; VAR m: GfxMatrix.Matrix): Font;
		VAR
			i, j, n, res: LONGINT;
			enum: Files.Enumerator; time, date, size: LONGINT;  continue: BOOLEAN;
			name: Files.FileName; msg, cmd: ARRAY 64 OF CHAR; flags: SET;
	BEGIN
		cmd := "";
		NEW(enum); enum.Open(family, {});
		continue := TRUE;
		WHILE continue & enum.GetEntry(name, flags, time, date, size) DO
			i := 0; j := 0;
			WHILE name[i] # 0X DO
				IF name[i] = "." THEN j := i END;
				INC(i)
			END;
			IF j > 0 THEN
				msg := "FontFormats"; i := 11;
				WHILE name[j] # 0X DO msg[i] := name[j]; INC(i); INC(j) END;
				Configuration.Get(msg, cmd, res);
				continue := (res = Configuration.Ok);
			END
		END;
		enum.Close;
			(* if found, invoke it *)
		IF cmd # "" THEN
			OpenProc := NIL;
			Commands.Call (cmd, {Commands.Wait}, res, msg);
			IF res = Commands.Ok THEN
				IF OpenProc # NIL THEN
					RETURN OpenProc(family, style, ptsize, m)
				END
			ELSE
				KernelLog.Enter; KernelLog.String("GfxFonts: "); KernelLog.String(msg); KernelLog.Exit
			END
		END;
		RETURN NIL
	END OpenExtension;

	(**
		open font given point size and transformation matrix. the transformation is applied to the display font at that size.
		the preferred way to specify a font is "Family-Style" (e.g. "Oberon-Bold"), although others are accepted as well
		("OberonBold", "Oberon10b")
	**)
	PROCEDURE Open* (name: ARRAY OF CHAR; ptsize: INTEGER; mat: GfxMatrix.Matrix): Font;
		VAR family, style, fname: FontName; font, cand: Font;
	BEGIN
		mat[2, 0] := 0; mat[2, 1] := 0;
		SplitName(name, family, style);
		BuildName(family, style, fname);

		(* search in cache *)
		font := Cache.next; cand := NIL;
		WHILE font # Cache DO
			IF font.name = fname THEN
				cand := font;	(* keep for deriving font *)
				IF (ptsize = font.ptsize) & GfxMatrix.Equal(font.mat, mat) THEN
					RETURN font
				END
			END;
			font := font.next
		END;

		(* derive from existing font if possible *)
		IF cand # NIL THEN
			font := cand.class.derive(cand, ptsize, mat);
			IF font # NIL THEN
				COPY(fname, font.name); font.ptsize := ptsize; font.mat := mat;
				CacheFont(font);
				RETURN font
			END
		END;

		(* try standard raster/outline fonts *)
		font := OpenRaster(family, style, ptsize, mat, OpenOutline(family, style));
		IF font # NIL THEN
			COPY(fname, font.name); font.ptsize := ptsize; font.mat := mat;
			CacheFont(font);
			RETURN font
		END;

		(* try registered font formats *)
		font := OpenExtension(family, style, ptsize, mat);
		IF font # NIL THEN
			COPY(fname, font.name); font.ptsize := ptsize; font.mat := mat;
			CacheFont(font);
			RETURN font
		END;

		RETURN NIL
	END Open;

	(** open font of specified point size at display resolution **)
	PROCEDURE OpenSize* (name: ARRAY OF CHAR; ptsize: INTEGER): Font;
	BEGIN
		RETURN Open(name, ptsize, GfxMatrix.Identity)
	END OpenSize;

	(** return character advance vector **)
	PROCEDURE GetWidth* (font: Font; ch: CHAR; VAR dx, dy: REAL);
		VAR char: Char;
	BEGIN
		char := CachedChar(font, ch);
		IF char # NIL THEN
			dx := char.dx; dy := char.dy
		ELSE
			font.class.getwidth(font, ch, dx, dy)
		END
	END GetWidth;

	(** return character bitmap **)
	PROCEDURE GetMap* (font: Font; ch: CHAR; VAR x, y, dx, dy: REAL; VAR map: Raster.Image);
		VAR char: Char;
	BEGIN
		char := CachedChar(font, ch);
		IF char # NIL THEN
			x := char.x; y := char.y; dx := char.dx; dy := char.dy; map := char.map
		ELSE
			font.class.getmap(font, ch, x, y, dx, dy, map);
			CacheChar(font, ch, x, y, dx, dy, map)
		END
	END GetMap;

	(** store character outline rooted at given position in given path **)
	PROCEDURE GetOutline* (font: Font; ch: CHAR; x, y: REAL; path: GfxPaths.Path);
	BEGIN
		font.class.getoutline(font, ch, x, y, path)
	END GetOutline;

	(** compute advance vector for complete string **)
	PROCEDURE GetStringWidth* (font: Font; str: ARRAY OF CHAR; VAR dx, dy: REAL);
		VAR i: LONGINT; ddx, ddy: REAL;
	BEGIN
		i := 0; dx := 0; dy := 0;
		WHILE str[i] # 0X DO
			GetWidth(font, str[i], ddx, ddy);
			dx := dx + ddx; dy := dy + ddy;
			INC(i)
		END
	END GetStringWidth;


	(*--- Derive Methods ---*)

	(* cannot derive font if no outline is known *)
	PROCEDURE FDerive (font: Font; ptsize: INTEGER; VAR mat: GfxMatrix.Matrix): Font;
	BEGIN
		RETURN NIL
	END FDerive;

	(* derive font with same outline *)
	PROCEDURE ODerive (font: Font; ptsize: INTEGER; VAR mat: GfxMatrix.Matrix): Font;
		VAR family, style: FontName;
	BEGIN
		SplitName(font.name, family, style);
		RETURN OpenRaster(family, style, ptsize, mat, font.outline)
	END ODerive;


	(*--- GetWidth Methods ---*)

	(* ... from raster font *)
	PROCEDURE FGetWidth (font: Font; ch: CHAR; VAR dx, dy: REAL);
		VAR rfile: RasterFile;
	BEGIN
		rfile := font.rfile;
		IF rfile.char[ORD(ch)] # NIL THEN dx := rfile.char[ORD(ch)].dx ELSE dx :=0 END; dy := 0
	END FGetWidth;

	(* ... from warped raster font *)
	PROCEDURE WFGetWidth (font: Font; ch: CHAR; VAR dx, dy: REAL);
	BEGIN
		FGetWidth(font, ch, dx, dy);
		dy := dx * font.wmat[0, 1];
		dx := dx * font.wmat[0, 0]
	END WFGetWidth;

	(* ... from outline *)
	PROCEDURE OGetWidth (font: Font; ch: CHAR; VAR dx, dy: REAL);
		VAR w: REAL;
	BEGIN
		w := font.outline.width[ORD(ch)];
		dx := w * font.wmat[0, 0]; dy := w * font.wmat[0, 1]
	END OGetWidth;


	(*--- GetMap Methods ---*)

	PROCEDURE WarpMap (src: Raster.Image; mat: GfxMatrix.Matrix; VAR x, y: REAL; VAR dst: Raster.Image);
		VAR x0, y0, x1, y1: REAL; w, h: LONGINT; filter: GfxImages.Filter;
	BEGIN
		GfxImages.InitLinearFilter(filter);
		GfxMatrix.Apply(mat, x, y, x, y);
		x0 := 0; y0 := 0; x1 := 0; y1 := 0;
		IF mat[0, 0] > 0 THEN x1 := src.width * mat[0, 0] ELSE x0 := src.width * mat[0, 0] END;
		IF mat[0, 1] > 0 THEN y1 := src.width * mat[0, 1] ELSE y0 := src.width * mat[0, 1] END;
		IF mat[1, 0] > 0 THEN x1 := x1 + src.height * mat[1, 0] ELSE x0 := x0 + src.height * mat[1, 0] END;
		IF mat[1, 1] > 0 THEN y1 := y1 + src.height * mat[1, 1] ELSE y0 := y0 + src.height * mat[1, 1] END;
		mat[2, 0] := -x0; mat[2, 1] := -y0;
		x := x + x0; y := y + y0;
		w := -ENTIER(-x1) - ENTIER(x0); h := -ENTIER(-y1) - ENTIER(y0);
		IF w * h # 0 THEN
			NEW(dst); Raster.Create(dst, w, h, Raster.A8);
			GfxImages.Transform(src, dst, mat, filter)
		ELSE
			dst := NIL
		END
	END WarpMap;

	(* ... from raster font *)
	PROCEDURE FGetMap (font: Font; ch: CHAR; VAR x, y, dx, dy: REAL; VAR map: Raster.Image);
		VAR char: RasterChar; stride: LONGINT;
	BEGIN
		char := font.rfile.char[ORD(ch)];
		IF char = NIL THEN
			dx := 0; dy := 0; x := 0; y := 0; map := NIL
		ELSE
			dx := char.dx; dy := 0;
			IF char.w * char.h = 0 THEN
				x := 0; y := 0; map := NIL
			ELSE
				x := char.x; y := -char.h-char.y; stride:=(char.w+7) DIV 8;
				NEW(map); Raster.Init(map, char.w, char.h, Raster.A1, -stride, char.adr+(char.h-1)*stride)
			END
		END
	END FGetMap;

	(* ... by warping raster font *)
	PROCEDURE WFGetMap (font: Font; ch: CHAR; VAR x, y, dx, dy: REAL; VAR map: Raster.Image);
	BEGIN
		FGetMap(font, ch, x, y, dx, dy, map);
		dy := dx * font.wmat[0, 1];
		dx := dx * font.wmat[0, 0];
		IF map # NIL THEN
			WarpMap(map, font.wmat, x, y, map)
		END
	END WFGetMap;

	PROCEDURE AddElem (VAR data: GfxPaths.EnumData);
		VAR px, py, x, y, xstep, ystep, steps: INTEGER; dx, ex, dy, ey, e: REAL;
	BEGIN
		WITH data: PathEnumData DO
			CASE data.elem OF
			| GfxPaths.Enter:
				data.lx := data.x; data.ly := data.y;
				data.px := SHORT(ENTIER(data.x + 0.5)); data.py := SHORT(ENTIER(data.y + 0.5))
			| GfxPaths.Line:
				px := SHORT(ENTIER(data.x + 0.5)); py := SHORT(ENTIER(data.y + 0.5));
				x := data.px; y := data.py;
				IF py = y THEN	(* horizontal line => ignore *)
					data.px := px
				ELSE
					dx := data.x - data.lx; dy := data.y - data.ly;
					IF dx >= 0 THEN xstep := 1; ex := data.lx - x
					ELSE xstep := -1; dx := -dx; ex := x - data.lx
					END;
					IF dy >= 0 THEN ystep := 1; ey := data.ly - y
					ELSE ystep := -1; dy := -dy; ey := y - data.ly
					END;
					e := dx * ey - dy * ex + 0.5 * (dy - dx);
					steps := ABS(px - x) + ABS(py - y);
					WHILE steps > 0 DO
						IF (e >= 0) & ((e > 0) OR (xstep <= 0)) THEN
							INC(y, ystep); e := e - dx;
							GfxRegions.AddPoint(data.region, x, y, ystep)
						ELSE
							INC(x, xstep); e := e + dy
							(* don't have to insert point here because regions are sliced horizontally *)
						END;
						DEC(steps)
					END;
					data.px := px; data.py := py
				END;
				data.lx := data.x; data.ly := data.y
			ELSE	(* ignore other elements *)
			END
		END
	END AddElem;

	PROCEDURE FillRect (llx, lly, urx, ury: INTEGER; VAR data: GfxRegions.EnumData);
		VAR pix: Raster.Pixel; mode: Raster.Mode;
	BEGIN
		WITH data: RegEnumData DO
			pix[Raster.a] := 0FFX;
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.Fill(data.map, llx - data.dx, lly - data.dy, urx - data.dx, ury - data.dy, pix, mode)
		END
	END FillRect;

	(* ... by filling interior of warped outline *)
	PROCEDURE OGetMap (font: Font; ch: CHAR; VAR x, y, dx, dy: REAL; VAR map: Raster.Image);
		VAR w: REAL; pathdata: PathEnumData; llx, lly, urx, ury: INTEGER; regdata: RegEnumData;
		tmpPath: GfxPaths.Path; tmpRegion: GfxRegions.Region; (* was global --> now local for concurrency ... cost? *)
	BEGIN
		NEW(tmpPath);
		NEW(tmpRegion); GfxRegions.Init(tmpRegion, GfxRegions.Winding);
		w := font.outline.width[ORD(ch)];
		dx := w * font.wmat[0, 0]; dy := w * font.wmat[0, 1];
		font.class.getoutline(font, ch, 0, 0, tmpPath);
		GfxRegions.Clear(tmpRegion);
		pathdata.region := tmpRegion;
		GfxPaths.EnumFlattened(tmpPath, 0.5, AddElem, pathdata);
		IF GfxRegions.Empty(tmpRegion) THEN
			x := 0; y := 0; map := NIL
		ELSE
			llx := tmpRegion.llx; lly := tmpRegion.lly; urx := tmpRegion.urx; ury := tmpRegion.ury;
			NEW(map); Raster.Create(map, urx - llx, ury - lly, Raster.A1);
			regdata.map := map; regdata.dx := llx; regdata.dy := lly;
			GfxRegions.Enumerate(tmpRegion, llx, lly, urx, ury, FillRect, regdata);
			x := llx; y := lly
		END
	END OGetMap;


	(*--- GetOutline Methods ---*)

	(* ... undefined outline for raster fonts *)
	PROCEDURE FGetOutline (font: Font; ch: CHAR; x, y: REAL; path: GfxPaths.Path);
		VAR rfile: RasterFile; w, h: INTEGER; l: REAL;
	BEGIN
		GfxPaths.Clear(path);
		rfile := font.rfile;
		w := rfile.char[ORD(ch)].w; h := rfile.char[ORD(ch)].h;
		IF w * h > 0 THEN
			x := x + rfile.char[ORD(ch)].x; y := y + rfile.char[ORD(ch)].y;
			l := 0.1*(rfile.ymax - rfile.ymin);
			GfxPaths.AddRect(path, x, y, x + w, y + h);
			GfxPaths.AddRect(path, x + l, y + h - l, x + w - l, y + l)
		END
	END FGetOutline;

	(* ... undefined outline for warped raster fonts *)
	PROCEDURE WFGetOutline (font: Font; ch: CHAR; x, y: REAL; path: GfxPaths.Path);
		VAR rfile: RasterFile; w, h, bx, by: INTEGER; l: REAL; m: GfxMatrix.Matrix;
	BEGIN
		GfxPaths.Clear(path);
		rfile := font.rfile;
		w := rfile.char[ORD(ch)].w; h := rfile.char[ORD(ch)].h;
		IF w * h > 0 THEN
			bx := rfile.char[ORD(ch)].x; by := rfile.char[ORD(ch)].y;
			l := 0.1*(rfile.ymax - rfile.ymin);
			GfxPaths.AddRect(path, bx, by, bx + w, by + h);
			GfxPaths.AddRect(path, bx + l, by + h - l, bx + w - l, by + l);
			m := font.wmat; m[2, 0] := m[2, 0] + x; m[2, 1] := m[2, 1] + y;
			GfxPaths.Apply(path, m)
		END
	END WFGetOutline;

	(* ... from outline structure *)
	PROCEDURE OGetOutline (font: Font; ch: CHAR; x, y: REAL; path: GfxPaths.Path);
		VAR outline: Outline; len: LONGINT; mat: GfxMatrix.Matrix; s: GfxPaths.Scanner; scale, dx, dy, x0, y0, x1, y1, x2, y2: REAL;
	BEGIN
		GfxPaths.Clear(path);
		outline := font.outline; len := outline.len[ORD(ch)];
		IF len > 0 THEN
			scale := font.ptsize * DPI/72.27;
			GfxMatrix.Scale(font.mat, scale, scale, mat);
			mat[2, 0] := mat[2, 0] + x; mat[2, 1] := mat[2, 1] + y;
			GfxPaths.Open(s, outline.path, outline.pos[ORD(ch)]);
			REPEAT
				CASE s.elem OF
				| GfxPaths.Enter:
					GfxMatrix.Apply(mat, s.x, s.y, x, y); GfxMatrix.ApplyToVector(mat, s.dx, s.dy, dx, dy);
					GfxPaths.AddEnter(path, x, y, dx, dy)
				| GfxPaths.Line:
					GfxMatrix.Apply(mat, s.x, s.y, x, y);
					GfxPaths.AddLine(path, x, y)
				| GfxPaths.Arc:
					GfxMatrix.Apply(mat, s.x, s.y, x, y); GfxMatrix.Apply(mat, s.x0, s.y0, x0, y0);
					GfxMatrix.Apply(mat, s.x1, s.y1, x1, y1); GfxMatrix.Apply(mat, s.x2, s.y2, x2, y2);
					GfxPaths.AddArc(path, x, y, x0, y0, x1, y1, x2, y2)
				| GfxPaths.Bezier:
					GfxMatrix.Apply(mat, s.x, s.y, x, y);
					GfxMatrix.Apply(mat, s.x1, s.y1, x1, y1); GfxMatrix.Apply(mat, s.x2, s.y2, x2, y2);
					GfxPaths.AddBezier(path, x, y, x1, y1, x2, y2)
				| GfxPaths.Exit:
					GfxMatrix.Apply(mat, s.dx, s.dy, dx, dy);
					GfxPaths.AddExit(path, dx, dy);
					DEC(len)
				END;
				GfxPaths.Scan(s)
			UNTIL len = 0
		END
	END OGetOutline;

	PROCEDURE InitClasses;
	BEGIN
		NEW(FClass); FClass.derive := FDerive; FClass.getwidth := FGetWidth;
		FClass.getmap := FGetMap; FClass.getoutline := FGetOutline;
		NEW(OFClass); OFClass.derive := ODerive; OFClass.getwidth := FGetWidth;
		OFClass.getmap := FGetMap; OFClass.getoutline := OGetOutline;
		NEW(WFClass); WFClass.derive := FDerive; WFClass.getwidth := WFGetWidth;
		WFClass.getmap := WFGetMap; WFClass.getoutline := WFGetOutline;
		NEW(OWFClass); OWFClass.derive := ODerive; OWFClass.getwidth := WFGetWidth;
		OWFClass.getmap := WFGetMap; OWFClass.getoutline := OGetOutline;
		NEW(OClass); OClass.derive := ODerive; OClass.getwidth := OGetWidth;
		OClass.getmap := OGetMap; OClass.getoutline := OGetOutline
	END InitClasses;

	PROCEDURE InitDefault;
	BEGIN
		Default := OpenSize("Oberon", 10)
	END InitDefault;


BEGIN
	InitClasses;
	NEW(Cache); Cache.next := Cache; Cache.prev := Cache; Chars := 0;
	(* NEW(TmpPath);
	NEW(TmpRegion); GfxRegions.Init(TmpRegion, GfxRegions.Winding); *)
	InitDefault
END GfxFonts.

From:	oswald@inf.ethz.ch
Subject:	Re: Aos specific packages
Date:	Thu, 22 Jun 2000 17:08:58 +0200 (MET DST)

> What settings do I need?

The usual suspects

ImageFormats.Pict PictImages.Install
ImageFormats.bmp BMPImages.Install
ImageFormats.gif GIFImages.Install
ImageFormats.jpg JPEGImages.Install

FontFormats.TTF GfxOType.Install
FontFormats.pk GfxPKFonts.Install

Actually, the FontFormats entries have once again changed in
their semantics. GfxFonts now searches "Arial*" if "Arial-..."
is requested. If it finds e.g. "Arial.TTF" it uses the TTF
extension as a key into FontFormats.
--
eos


(*
to do:
o change OpenExtension to use new style commands to avoid races
*)
