MODULE TestVideo; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Computer Vision Experiments"; *)

IMPORT
	Kernel, Modules, Raster, VideoExample, Commands, Options, KernelLog, Random, WMGraphics, WMRectangles, Kernel32, SYSTEM, Vectors := W3dVectors, Math := MathL;

CONST
	Ok* = 0;
	TooManyLabels* = 1;
	PathTooLong* = 2;
	DirN = 0; DirNE = 1; DirE = 2; DirSE = 3; DirS = 4; DirSW = 5; DirW = 6; DirNW = 7;
	DebugLabeler = FALSE;
	DebugTracer = FALSE;
	DebugLiner = FALSE;

TYPE
	LabelInfo* = RECORD
		firstPos : LONGINT;
		nofPixels : LONGINT;
		label : INTEGER;
	END;

	Point = RECORD
		x, y : INTEGER;
	END;

VAR
	threshold, pixThreshold : LONGINT;
	labelBuffer : POINTER TO ARRAY OF INTEGER;
	equivalence : ARRAY 32*1024 OF INTEGER;
	labelInfo : ARRAY 32*1024 OF LabelInfo;
	labelColor : ARRAY 32*1024 OF LONGINT;
	g : WMGraphics.BufferCanvas;
	dirX, dirY : ARRAY 8 OF LONGINT;
	rectified : VideoExample.PreviewWindow;

	intensityBuffer, thresholdBuffer : POINTER TO ARRAY OF CHAR;

	PROCEDURE RGBToYUVReal(r, g, b : LONGINT; VAR y, u, v : LONGINT);
	BEGIN
		y := ENTIER(0.299 * r + 0.587 * g + 0.114 * b);
		u := ENTIER(128  - 0.16874 * r - 0.33126 * g + 0.5 * b);
		v := ENTIER(128 + 0.5 * r - 0.41869 * g - 0.08131 * b);
	END RGBToYUVReal;

	(** Analytical solution for homography for the case of 4 points mapping to the unit rectangle.
		According to "ProjectiveMappings for Image Warping" by Paul Heckbert, 	15-869, Image-Based Modeling and Rendering *)
	PROCEDURE CalculateUnitSquareHomography(CONST p : ARRAY OF Point; VAR H, inverse : ARRAY  OF LONGREAL);
	VAR sx, sy, dx1, dy1, dx2, dy2, a, b, c, d, e, f, g, h, z : LONGREAL;
	BEGIN
		sx := (p[0].x - p[1].x) + (p[2].x - p[3].x);
		sy := (p[0].y - p[1].y) + (p[2].y - p[3].y);
		dx1 := p[1].x - p[2].x;
		dx2 := p[3].x - p[2].x;
		dy1 := p[1].y - p[2].y;
		dy2 := p[3].y - p[2].y;

		z := dx1 * dy2 - dy1 * dx2;
		g := (sx * dy2 - sy * dx2) / z;
		h := (sy * dx1 - sx * dy1) / z;

		a := p[1].x - p[0].x + g * p[1].x;
		b := p[3].x - p[0].x + h * p[3].x;
		c := p[0].x;
		d := p[1].y - p[0].y + g * p[1].y;
		e := p[3].y - p[0].y + h * p[3].y;
		f := p[0].y;
		H[0] := a; H[1] := b; H[2] := c;
		H[3] := d; H[4] := e; H[5] := f;
		H[6] := g; H[7] := h; H[8] := 1;

		(* inverse transformation *)
		inverse[0] := e - f * h; inverse[1] := c * h - b; inverse[2] := b * f - c * e;
		inverse[3] := f * g - d; inverse[4] := a - c * g; inverse[5] := c * d - a * f;
		inverse[6] := d * h - e * g; inverse[7] := b * g - a * h; inverse[8] := a * e - b * d
	END CalculateUnitSquareHomography;

	PROCEDURE MapProjective(CONST H : ARRAY OF LONGREAL; u, v : LONGREAL; VAR x, y : LONGREAL);
	BEGIN
		x := (H[0] * u + H[1] * v + H[2]) / (H[6] * u + H[7] * v + 1);
		y := (H[3] * u + H[4] * v + H[5]) / (H[6] * u + H[7] * v + 1)
	END MapProjective;

	PROCEDURE MapInverseProjective(CONST H : ARRAY OF LONGREAL; u, v : LONGREAL; VAR x, y : LONGREAL);
	VAR z : LONGREAL;
	BEGIN
		x := (H[0] * u + H[1] * v + H[2]) / (H[6] *u + H[7] * v + 1);
		y := (H[3] * u + H[4] * v + H[5]) / (H[6] *u + H[7] * v + 1);
		z := (H[6] * u + H[7] * v + H[8]) / (H[6] *u + H[7] * v + 1);
		x := x / z;
		y := y / z;
	END MapInverseProjective;

PROCEDURE Transform(src, dst : Raster.Image; CONST points : ARRAY OF Point);
VAR h, hinv : ARRAY 9 OF LONGREAL;
	x,  y, six, siy : LONGINT;
	u, v, sx, sy : LONGREAL;
	mode : Raster.Mode;
	pix : Raster.Pixel;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	CalculateUnitSquareHomography(points, h, hinv);
	FOR y := 0 TO dst.height - 1 DO
		v := y / dst.height;
		FOR x := 0 TO dst.width - 1 DO
			u := x / dst.width;
			MapProjective(h, u, v, sx, sy);
			six := ENTIER(sx + 0.5); siy := ENTIER(sy + 0.5);
			IF (six > 0) & (siy > 0) & (six < src.width) & (siy < src.height) THEN
				Raster.Get(src, six, siy, pix, mode);
			ELSE Raster.SetRGBA(pix, 0, 0, 0, 255)
			END;
			Raster.Put(dst, x, y, pix, mode)
		END
	END
END Transform;

PROCEDURE SearchHVLines(buffer : Raster.Image);
VAR x, y, tr, tg, tb, ta : LONGINT;
	sum : LONGINT;
	hArray, vArray : ARRAY 2048 OF LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	FOR y := 0 TO buffer.height - 1 DO
		FOR x := 0 TO buffer.width - 1 DO
			Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
			sum := (tr + tg + tb);
			INC(hArray[x], sum);
			INC(vArray[y], sum);
		END
	END;
	FOR y := 0 TO buffer.height - 1 DO
		IF vArray[y] < threshold * buffer.width THEN
			rectified.canvas.Line(0, y, buffer.width, y, 0FF00FFH, WMGraphics.ModeCopy);
		END
	END;
	FOR x := 0 TO buffer.width - 1 DO
		IF hArray[x] < threshold * buffer.height THEN
			rectified.canvas.Line(x, 0, x, buffer.height, 0FF00FFH, WMGraphics.ModeCopy);
		END
	END
END SearchHVLines;

PROCEDURE IsEmptyField(buffer : Raster.Image; x, y , w, h : LONGINT) : BOOLEAN;
VAR i, j, tr, tg, tb, ta : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	nonEmpty : LONGINT;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	nonEmpty := 0;
	FOR j := y TO y + h - 1 DO
		FOR i := x TO x + w - 1 DO
			Raster.Get(buffer,i,j, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
			IF (tr + tg + tb) < threshold  THEN
				Raster.SetRGBA(pix, 255, 0, 0, 255); Raster.Put(buffer, i, j, pix, mode);
				INC(nonEmpty)
			END
		END
	END;
	RETURN nonEmpty < 8*w*h DIV 100;
END IsEmptyField;

PROCEDURE Dist(buffer : Raster.Image; x0, y0, x1, y1, w, h : LONGINT) : LONGINT;
VAR i, j, tr, tg, tb, ta, s0, s1 : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	sum : LONGINT;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	sum := 0;
	FOR j := 0 TO h - 1 DO
		FOR i := 0 TO w - 1 DO
			Raster.Get(buffer, x0 + i, y0 + j, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta); s0 := (tr + tg + tb);
			Raster.Get(buffer, x1 + i, y1 + j, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta); s1 := (tr + tg + tb);
			sum := sum + (threshold - s0) * (threshold - s1);
		END
	END;
	RETURN sum;
END Dist;

PROCEDURE CheckFields(buffer : Raster.Image);
VAR i, j, x, y, w, h : LONGINT;
	empty : ARRAY 9, 9 OF BOOLEAN;
	nofNumbers : LONGINT;
	numbers : ARRAY 81 OF LONGINT;

	cluster: ARRAY 81 OF RECORD
		nofFields : SHORTINT;
		fields : ARRAY 81 OF SHORTINT;
	END;
	distance, dist : ARRAY 81, 81 OF LONGINT;

	PROCEDURE SetDist(a, b, d : LONGINT);
	BEGIN
		IF a < b THEN dist[a, b] := d
		ELSE dist[b, a] := d
		END
	END SetDist;

	PROCEDURE GetDist(a, b : LONGINT) : LONGINT;
	BEGIN
		IF a < b THEN RETURN dist[a, b]
		ELSE RETURN dist[b, a]
		END
	END GetDist;

	PROCEDURE GetSmallest(VAR maxi, maxj : LONGINT);
	VAR max : LONGINT;
		first : BOOLEAN;
	BEGIN
		first := TRUE;
		FOR j := 0 TO nofNumbers - 1 DO
			FOR i := 0 TO j - 1 DO
				IF first THEN
					max := GetDist(i, j);
					maxi := i; maxj := j;
					first := FALSE
				ELSE
					IF GetDist(i, j) > max THEN
						max := GetDist(i, j);
						maxi := i; maxj := j;
					END
				END
			END;
		END
	END GetSmallest;

	PROCEDURE Cluster;
	VAR i : LONGINT;
	BEGIN
		FOR i := 0 TO 81 - 1 DO cluster[i].nofFields := 0; cluster[i].fields[0] := SHORT(SHORT(i)) END;
		FOR i := 0 TO nofNumbers - 1 DO cluster[i].nofFields := 1 END;
		FOR i := 0 TO nofNumbers - 1 DO

		END;
	END Cluster;

BEGIN
	w := buffer.width DIV 9 - 5;
	h := buffer.height DIV 9 - 5;
	nofNumbers := 0;
	FOR j := 0 TO 9 - 1 DO
		FOR i := 0 TO 9 - 1 DO
			x := (i * buffer.width DIV 9) + 5;
			y := (j * buffer.height DIV 9) + 5;
			IF IsEmptyField(buffer, x, y, w, h) THEN
				empty[j, i] := TRUE;
				rectified.canvas.Fill(WMRectangles.MakeRect(x, y, x + w, y + h), 00FF80H, WMGraphics.ModeSrcOverDst);
			ELSE empty[j, i] := FALSE;
				numbers[nofNumbers] := 9 * j + i;
				INC(nofNumbers)
			END
		END
	END;
	FOR j := 0 TO nofNumbers - 1 DO
		FOR i := 0 TO j - 1 DO
			distance[j, i] := Dist(buffer,
				(numbers[j] DIV 9) * buffer.width DIV 9 + 4, (numbers[j] MOD 9) * buffer.height DIV 9 + 4,
				(numbers[i] DIV 9) * buffer.width DIV 9 + 4, (numbers[i] MOD 9) * buffer.height DIV 9 + 4,
				w, h);
			SetDist(j, i, distance[j, i]);
(*			KernelLog.Int(distance[j, i], 0); KernelLog.String(" "); *)
		END;
		KernelLog.Ln;
	END;
END CheckFields;

(**
	Labels 8-way connected components in the image. Max components that can be found 32768.
	buffer : the image that should be labled
	labelBuffer : buffer with at least w * h integers for labels
	equivalenceBuffer : storage space for maxLabels label;
	colorThreshold : ...
	*)
PROCEDURE BinaryLabler*(buffer : Raster.Image; VAR labelBuffer, equivalence : ARRAY OF INTEGER; colorThreshold, pixelThreshold, maxLabels : LONGINT;
	VAR labelInfo : ARRAY OF LabelInfo;
	unifyLabels : BOOLEAN; VAR nofFLabels : LONGINT; VAR res : LONGINT);
VAR i, x, y, w , h,  color: LONGINT;
	tr, tg, tb, ta  : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	nofLabels : INTEGER;
	lbufpos, lastLineLbufPos, minClass : LONGINT;
	lastsum, sum, cl, ctl, ct, ctr, tlabel : INTEGER;
	adr : ADDRESS;
	ch : CHAR;

	PROCEDURE Equivalence(x, y : LONGINT);
	BEGIN
		IF x > y THEN equivalence[x] := SHORT(y) ELSE equivalence[y] := SHORT(x) END
	END Equivalence;

	PROCEDURE NewLabel(lbufPos : LONGINT);
	BEGIN
		IF nofLabels < maxLabels THEN
			INC(nofLabels);
			labelBuffer[lbufpos] := nofLabels;
			labelInfo[nofLabels].firstPos := lbufPos;
			labelInfo[nofLabels].nofPixels := 1
		ELSE
			res := TooManyLabels;
		END
	END NewLabel;

BEGIN
	ASSERT(maxLabels <= MAX(INTEGER));
	ASSERT(LEN(equivalence) >= maxLabels);
	ASSERT(LEN(labelBuffer) >= w*h);
	res := Ok;
	w := buffer.width; h := buffer.height;
	(* initialize equivalences *)
	FOR i := 0 TO SHORT(LEN( equivalence)) - 1 DO equivalence[i] := SHORT(i) END;

	Raster.InitMode(mode, Raster.srcCopy);

	nofLabels := 0;
	(* first line *)
	lbufpos := 0;
	FOR x := 0 TO w - 1 DO
		Raster.Get(buffer, x, 0, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
		IF (tr + tg + tb < threshold) THEN
			IF (x > 0) & (labelBuffer[lbufpos - 1] > 0) THEN
				labelBuffer[lbufpos] := labelBuffer[lbufpos - 1]
			ELSE NewLabel(lbufpos)
			END;
		ELSE labelBuffer[lbufpos] := 0
		END;
		INC(lbufpos)
	END;

	lastLineLbufPos := 0;
	FOR y := 1 TO h - 1 DO
		adr := buffer.adr + y *  buffer.bpr;
		SYSTEM.GET(adr, ch); lastsum := ORD(ch); INC(adr);
		SYSTEM.GET(adr, ch); lastsum := lastsum + ORD(ch); INC(adr);
		SYSTEM.GET(adr, ch); lastsum := lastsum + ORD(ch); INC(adr);
		INC(lbufpos); INC(lastLineLbufPos);
		FOR x := 1 TO w - 1 DO
			(*Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);*)
			SYSTEM.GET(adr, ch); sum := ORD(ch); INC(adr);
			SYSTEM.GET(adr, ch); sum := sum + ORD(ch); INC(adr);
			SYSTEM.GET(adr, ch); sum := sum + ORD(ch); INC(adr);

			lastsum := sum;
			IF ( sum (* tr + tg + tb*) < threshold) THEN
				IF (x > 0)  THEN
					cl := labelBuffer[lbufpos - 1];
					ctl := labelBuffer[lastLineLbufPos - 1];
				ELSE cl := 0; ctl := 0
				END;
				ct := labelBuffer[lastLineLbufPos];
				IF x < w - 1 THEN ctr := labelBuffer[lastLineLbufPos + 1] ELSE ctr := 0 END;
				IF (cl + ctl + ct + ctr = 0)(*(cl = 0) & (ctl = 0) & (ct = 0) & (ctr = 0)*) THEN NewLabel(lbufpos)
				ELSE
					minClass := 0FFFFH;
				 	IF (cl # 0) & (cl < minClass) THEN minClass := cl END;
				 	IF (ctl # 0) & (ctl < minClass) THEN minClass := ctl END;
				 	IF (ct # 0) & (ct < minClass) THEN minClass := ct END;
				 	IF (ctr # 0) & (ctr < minClass) THEN minClass := ctr END;
				 	IF equivalence[minClass] < minClass THEN minClass := equivalence[minClass] END;
				 	labelBuffer[lbufpos] := SHORT(minClass);
				 	INC(labelInfo[minClass].nofPixels);
				 	IF (cl # 0) & (cl # minClass) THEN Equivalence(minClass, cl) END;
				 	IF (ctl # 0) & (ctl # minClass) THEN Equivalence(minClass, ctl) END;
				 	IF (ct # 0) & (ct # minClass) THEN Equivalence(minClass, ct) END;
				 	IF (ctr # 0) & (ctr # minClass) THEN Equivalence(minClass, ctr) END;
				END;
			ELSE labelBuffer[lbufpos] := 0
			END;
			INC(lbufpos);
			INC(lastLineLbufPos)
		END
	END;

	(* ensure all equivalences are pointing to the lowest numbered label id *)
	FOR i := 1 TO nofLabels - 1 DO
		IF equivalence[i] < i THEN WHILE equivalence[equivalence[i]] < equivalence[i] DO equivalence[i] := equivalence[equivalence[i]] END END;
	END;

	IF unifyLabels THEN
		FOR i := 0 TO w * h - 1 DO labelBuffer[i] := equivalence[labelBuffer[i]] END
	END;

	(* sum up the pixel sizes and adjust the first position of the region *)
	FOR i := 1 TO nofLabels - 1 DO
		IF equivalence[i] # i THEN
			labelInfo[equivalence[i]].firstPos := MIN(labelInfo[equivalence[i]].firstPos, labelInfo[i].firstPos);
			INC(labelInfo[equivalence[i]].nofPixels, labelInfo[i].nofPixels);
			labelInfo[i].nofPixels := 0;
			labelInfo[i].label := equivalence[i]
		END;
	END;

	IF DebugLabeler THEN
		lbufpos := 0;
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO
				tlabel := equivalence[labelBuffer[lbufpos]];
				IF (tlabel>0)&(labelInfo[tlabel].nofPixels >= pixelThreshold) THEN color := labelColor[tlabel]
				ELSE color := LONGINT(0FFFFFFFFH);
					Raster.SetRGBA(pix, ((color DIV 65536) DIV 256) MOD 256, (color DIV 65536) MOD 256,
						(color DIV 256) MOD 256, 255);
					Raster.Put(buffer, x, y, pix, mode);
				END;
				INC(lbufpos);
			END
		END
	END;
	(* count and compress the labels *)
	nofFLabels := 0;
	FOR i := 1 TO nofLabels - 1 DO
		IF (equivalence[i] = i) & (labelInfo[i].nofPixels >= pixelThreshold) THEN
			labelInfo[nofFLabels] := labelInfo[i];
			INC(nofFLabels)
		END;
	END;

END BinaryLabler;

(* trace a region in the label buffer. The image buffer is used for the width and height and debug output.*)
PROCEDURE Trace(buffer : Raster.Image; CONST labelBuffer : ARRAY OF INTEGER; VAR labelInfo :  LabelInfo;
			VAR length : LONGINT; VAR path : ARRAY OF Point;
			VAR res : LONGINT);
VAR x, y, tx, ty : LONGINT;
	w, h, i, j: LONGINT;
	dir, p, p2 : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	deltaX, deltaY : ARRAY 8 OF LONGINT;
BEGIN
	res := Ok;
	w := buffer.width; h := buffer.height;
	x := labelInfo.firstPos MOD w; y := labelInfo.firstPos DIV w;
	Raster.SetRGBA(pix, 255, 255, 0, 255);
	Raster.Put(buffer, x, y, pix, mode);

	deltaX[DirN] := 0; deltaY[DirN] := -w; (* N *)
	deltaX[DirNE] := 1; deltaY[DirNE] := -w; (* NE *)
	deltaX[DirE] := 1; deltaY[DirE] := 0; (* E *)
	deltaX[DirSE] := 1; deltaY[DirSE] := w; (* SE *)
	deltaX[DirS] := 0; deltaY[DirS] := w; (* S *)
	deltaX[DirSW] := -1; deltaY[DirSW] := w; (* SW *)
	deltaX[DirW] := -1; deltaY[DirW] := 0; (* W *)
	deltaX[DirNW] := -1; deltaY[DirNW] := -w; (* NW *)

	length := 0;
	p := labelInfo.firstPos;
	x := p MOD w; y := p DIV w;
	dir := 5;
	j := 0;
	LOOP
		IF length >= LEN(path) THEN res := PathTooLong; EXIT END;
		dir := (dir + 5) MOD 8;
		i := 0;
		LOOP
			INC(i);
			IF i >  8 THEN RETURN END;
			p2 := p + deltaX[dir] + deltaY[dir];
			tx := x + dirX[dir];
			ty := y + dirY[dir];
			IF (tx >= 0) & (tx < w) & (ty >=  0) & (ty < h) & (labelBuffer[p2] # 0) THEN EXIT END;
			dir := (dir + 1) MOD 8;
		END;
		p := p2;
		x := tx; y := ty;

		IF DebugTracer THEN
			IF g = NIL THEN NEW(g, buffer) END;
			g.Fill(WMRectangles.MakeRect(x-1, y-1, x+1, y+1), 0FFFFH, WMGraphics.ModeCopy);
		END;
		(* SLOW *)
		path[length].x := SHORT(p MOD w);
		path[length].y := SHORT(p DIV w);
		INC(length);
		IF p = labelInfo.firstPos THEN EXIT END;
	END;

END Trace;

PROCEDURE SimplifyPoly(VAR path : ARRAY OF Point; nofPoints, tolerance: LONGINT; VAR resultPoint: LONGINT);
VAR i, j : LONGINT;
	dir0, dir1 : Vectors.TVector2d;
BEGIN
	IF nofPoints > 2 THEN
		i := 2; j := 1;
		WHILE i < nofPoints DO
			dir0 := Vectors.VNormed2(Vectors.Vector2d(path[j].x - path[j - 1].x, path[j].y - path[j - 1].y));
			dir1 := Vectors.VNormed2(Vectors.Vector2d(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y));
			IF Vectors.Scalar2(dir0, dir1) < 0.8 THEN INC(j) END;
			path[j] := path[i];
			INC(i);
		END
	END;
	resultPoint := j+ 1;
END SimplifyPoly;

PROCEDURE ExtractLines(buffer : Raster.Image; CONST path : ARRAY OF Point; pathLength : LONGINT; VAR poly : ARRAY OF Point; VAR nofPoints : LONGINT );
VAR i, p, nofLines, straight, nonStraight : LONGINT;
	l: LONGINT;

	PROCEDURE IsLine(from, to, l : LONGINT) : BOOLEAN;
	VAR i, d : LONGINT;
		x0, x1, y0, y1, px, py : LONGINT;
	BEGIN
		i := from;
		x0 := path[from].x; y0 := path[from].y;
		x1 := path[to].x; y1 := path[to].y;

		INC(i);
		WHILE i < to DO
			px := path[i].x; py := path[i].y;
			d := ABS((x1 - x0) * (y0 - py) - (x0 - px) * (y1 - y0));
			 (* / SQRT(SQR(x1-x0) + SQR(y1-y0)) *)
			IF d > l THEN RETURN FALSE END;
			INC(i);
		END;
		RETURN TRUE
	END IsLine;

BEGIN
	ASSERT(LEN(poly) >= 3);
	nofLines := 0; nonStraight := 0; straight := 0;
	p := 3; i := 0;
	WHILE p < pathLength DO
		IF IsLine(i, p, 2) THEN
			l := 6;
			WHILE ((i + l) < pathLength) & IsLine(i, i + l, l) DO INC(l, 2) END;
			IF (i + l) >= pathLength THEN l := pathLength - i - 1 END;
			WHILE ~IsLine(i, i + l, l) DO DEC(l) END;
			p := i + l;
			IF DebugLiner THEN
				IF g = NIL THEN NEW(g, buffer) END;
				g.Fill(WMRectangles.MakeRect(path[p].x-2, path[p].y-2, path[p].x+2, path[p].y+2), 00FFH, WMGraphics.ModeCopy);
				g.Fill(WMRectangles.MakeRect(path[p].x-1, path[p].y-1, path[p].x+1, path[p].y+1), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy);
			END;
			IF nofLines >= LEN(poly) THEN RETURN END;
			IF nofLines = 0 THEN	poly[0] := path[i]; INC(nofLines) END;
			poly[nofLines] := path[p]; INC(nofLines);
			i := p;
			INC(straight);
		ELSE INC(i);
			INC(nonStraight)
		END;
		p := i + 3;
	END;
	(* IF nonStraight - straight > 30 THEN RETURN END; *)
	(* not general : assumes closed polygon *)
	IF nofLines > 0 THEN
		poly[nofLines-1] := poly[0];
	END;
	SimplifyPoly(poly, nofLines, 0, nofLines);
	IF DebugLiner THEN
		FOR i := 0 TO nofLines - 1 DO
			g.Fill(WMRectangles.MakeRect(poly[i].x-2, poly[i].y-2, poly[i].x+2, poly[i].y+2), 00FFH, WMGraphics.ModeCopy);
			g.Fill(WMRectangles.MakeRect(poly[i].x-1, poly[i].y-1, poly[i].x+1, poly[i].y+1), LONGINT(0FF0000FFH), WMGraphics.ModeCopy);
		END
	 END;
	 nofPoints := nofLines;
END ExtractLines;

PROCEDURE GetTimer():HUGEINT;
VAR t : HUGEINT;
	res : Kernel32.BOOL;
BEGIN
	res := Kernel32.QueryPerformanceCounter(SYSTEM.VAL(Kernel32.LargeInteger, t));
	RETURN t;
END GetTimer;

PROCEDURE GetFreq():HUGEINT;
VAR t : HUGEINT;
	res : Kernel32.BOOL;
BEGIN
	res := Kernel32.QueryPerformanceFrequency(SYSTEM.VAL(Kernel32.LargeInteger, t));
	RETURN t;
END GetFreq;

PROCEDURE Label2(buffer : Raster.Image);
VAR nof, length, res, i, j : LONGINT; w, h: LONGINT;
	path : ARRAY 1024*4 OF Point;
	poly : ARRAY 40 OF Point;
	nofPoints : LONGINT;
	t0, t1, labeltime,  tracetime, linetime : HUGEINT;
	f  : LONGREAL;
	gp : ARRAY 50 OF WMGraphics.Point2d;
	PROCEDURE Sqr(x: LONGREAL):LONGREAL;
	BEGIN
		RETURN x * x
	END Sqr;
BEGIN
	w := buffer.width; h := buffer.height;
	IF (labelBuffer = NIL) OR (LEN(labelBuffer^) < w*h) THEN NEW(labelBuffer, w*h) END;
	t0 := GetTimer();
	BinaryLabler(buffer, labelBuffer^, equivalence, threshold, pixThreshold, 32767, labelInfo, TRUE, nof, res);
	t1 := GetTimer();
	labeltime := t1 - t0;
	tracetime := 0; linetime := 0;
	IF g = NIL THEN NEW(g, buffer) END;
	IF res = 0 THEN
		FOR i := 0 TO nof - 1 DO
			t0 := GetTimer();
			Trace(buffer, labelBuffer^, labelInfo[i], length, path, res);
			t1 := GetTimer(); tracetime := tracetime + (t1 - t0);
			IF res = 0 THEN
				t0 := GetTimer();
				ExtractLines(buffer, path, length, poly, nofPoints);
				IF (nofPoints = 5) THEN
					FOR j := 0 TO nofPoints - 1 DO gp[j].x := poly[j].x; gp[j].y := poly[j].y END;
					IF g = NIL THEN NEW(g, buffer) END;
					IF (Math.sqrt(Sqr(poly[1].x - poly[0].x) + Sqr(poly[1].y - poly[0].y)) > 20) &
						(Math.sqrt(Sqr(poly[2].x - poly[1].x) + Sqr(poly[2].y - poly[1].y)) > 20) &
						(Math.sqrt(Sqr(poly[3].x - poly[2].x) + Sqr(poly[3].y - poly[2].y)) > 20) &
						(Math.sqrt(Sqr(poly[4].x - poly[3].x) + Sqr(poly[4].y - poly[3].y)) > 20) &
						(Math.sqrt(Sqr(poly[2].x - poly[0].x) + Sqr(poly[2].y - poly[0].y)) > 40) &
						(Math.sqrt(Sqr(poly[1].x - poly[3].x) + Sqr(poly[1].y - poly[3].y)) > 40) &
						(Math.sqrt(
							Sqr((poly[0].x + poly[1].x) / 2 - (poly[2].x + poly[3].x) / 2) +
							Sqr((poly[0].y + poly[1].y) / 2 - (poly[2].y + poly[3].y) / 2)) > 40) &
						(Math.sqrt(
							Sqr((poly[1].x + poly[2].x) / 2 - (poly[3].x + poly[4].x) / 2) +
							Sqr((poly[1].y + poly[2].y) / 2 - (poly[3].y + poly[4].y) / 2)) > 40) THEN
						Transform(buffer, rectified.img, poly);
						CheckFields(rectified.img);
						rectified.Invalidate(WMRectangles.MakeRect(0, 0, rectified.GetWidth(), rectified.GetHeight()));
						g.Line((poly[0].x + poly[1].x) DIV 2, (poly[0].y + poly[1].y) DIV 2 , (poly[2].x + poly[3].x) DIV 2, (poly[2].y + poly[3].y) DIV 2, LONGINT(0FF0000FFH), WMGraphics.ModeSrcOverDst);

						g.FillPolygonFlat(gp, nofPoints, 000FF0080H, WMGraphics.ModeSrcOverDst);
						g.Line(poly[0].x, poly[0].y, poly[2].x, poly[2].y, 000FFFFFFH, WMGraphics.ModeSrcOverDst);
						g.Line(poly[1].x, poly[1].y, poly[3].x, poly[3].y, 000FFFFFFH, WMGraphics.ModeSrcOverDst);
					END;

(*					g.FillPolygonFlat(gp, nofPoints, LONGINT(0FF00FF80H), WMGraphics.ModeSrcOverDst)	*)
				ELSIF nofPoints = 6 THEN
					g.FillPolygonFlat(gp, nofPoints, LONGINT(0FF000020H), WMGraphics.ModeSrcOverDst);
				END;
				t1 := GetTimer(); linetime := linetime + (t1 - t0);
			END
		END
	END;
	f := GetFreq();
	f := f / 1000;
(*	KernelLog.String("nof= "); KernelLog.Int(nof, 0); KernelLog.Ln;
	KernelLog.String("labeltime = "); KernelLog.Int(ENTIER(labeltime / f), 0); KernelLog.Ln;
	KernelLog.String("tracetime = "); KernelLog.Int(ENTIER(tracetime / f), 0); KernelLog.Ln;
	KernelLog.String("linetime = "); KernelLog.Int(ENTIER(linetime / f), 0); KernelLog.Ln;
*)
END Label2;

PROCEDURE YUVFilter(buffer : Raster.Image);
VAR x, y, w , h : LONGINT;
	tr, tg, tb, ta, cy, cu, cv : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	(* rgb to yuv *)
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
			RGBToYUVReal(tr, tg, tb, cy, cu, cv);
			Raster.SetRGBA(pix, cy, cu, cv, 255);
			Raster.Put(buffer, x, y, pix, mode);

		END
	END;
END YUVFilter;

PROCEDURE SetYUVFilter*;
BEGIN
	VideoExample.InstallFrameHandler(YUVFilter)
END SetYUVFilter;

PROCEDURE BWFilter(buffer : Raster.Image);
VAR x, y, w , h : LONGINT;
	tr, tg, tb, ta, cy, cu, cv : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
			RGBToYUVReal(tr, tg, tb, cy, cu, cv);
			Raster.SetRGBA(pix, cy, cy, cy, 255);
			Raster.Put(buffer, x, y, pix, mode);

		END
	END;
END BWFilter;

PROCEDURE SetBWFilter*;
BEGIN
	VideoExample.InstallFrameHandler(BWFilter)
END SetBWFilter;

PROCEDURE RedDotFilter(buffer : Raster.Image);
VAR x, y, w , h : LONGINT;
	tr, tg, tb, ta : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta);
			IF (tr > 50) & (tg < 20) & (tb < 20) THEN
				Raster.SetRGBA(pix, 255, 255, 0, 255);
				Raster.Put(buffer, x, y, pix, mode);
			END
		END
	END;
END RedDotFilter;

PROCEDURE SetRedDotFilter*;
BEGIN
	VideoExample.InstallFrameHandler(RedDotFilter)
END SetRedDotFilter;

PROCEDURE ThresholdFilter(buffer : Raster.Image);
VAR x, y, w , h : LONGINT;
	sum, lastsum, tr, tg, tb, ta : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	tresh : LONGINT;
	darkMode : BOOLEAN;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	FOR y := 0 TO h - 1 DO
		Raster.Get(buffer, 0, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta); sum := tr + tg + tb;
		lastsum := sum;
		darkMode := sum < threshold;
		FOR x := 1 TO w - 1 DO
			Raster.Get(buffer, x, y, pix, mode); Raster.GetRGBA(pix, tr, tg, tb, ta); sum := tr + tg + tb;
			IF darkMode THEN
				IF (sum < tresh) THEN
					Raster.SetRGBA(pix, 255, 0, 0, 255);
					Raster.Put(buffer, x, y, pix, mode);
				ELSE darkMode := FALSE; tresh := threshold
				END;
			ELSE
				IF (sum < 3*lastsum DIV 4) OR (sum < tresh) THEN (*(sum > threshold) *)
					IF sum > tresh THEN tresh := 2*lastsum DIV 4 END;
					Raster.SetRGBA(pix, 255, 0, 0, 255);
					Raster.Put(buffer, x, y, pix, mode);
					darkMode := TRUE
				END
			END;
			lastsum := sum
		END
	END;
END ThresholdFilter;

PROCEDURE SetThresholdFilter*(context : Commands.Context);
VAR
	options: Options.Options;
BEGIN
	NEW(options);
	options.Add("t","threshold",Options.Integer);
	threshold := 50;
	IF options.Parse(context.arg, context.out) THEN
		IF options.GetInteger("threshold", threshold) THEN END;
	END;
	VideoExample.InstallFrameHandler(ThresholdFilter)
END SetThresholdFilter;

PROCEDURE AdaptiveThresholdFilter(buffer : Raster.Image);
VAR x, y, w, h, p, t : LONGINT;
	sum : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	ch : CHAR;
	adr : LONGINT;
	total : LONGINT;
BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	IF (intensityBuffer = NIL) OR (LEN(intensityBuffer^) < w*h) THEN NEW(intensityBuffer, w*h) END;

	p := 0; total := 0;
	FOR y := 0 TO h - 1 DO
		adr := buffer.adr + y *  buffer.bpr;
		FOR x := 0 TO w - 1 DO
			INC(adr);
			SYSTEM.GET(adr, ch); sum :=  ORD(ch); INC(adr);
			SYSTEM.GET(adr, ch); sum := sum + ORD(ch); INC(adr);
			intensityBuffer[p] := CHR(sum DIV 2);
			total := total + (sum DIV 2);
			INC(p)
		END;
	END;
	t := 5* (total DIV (w * h)) DIV 8;

	p := 0;
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			IF  ORD(intensityBuffer[p]) < t THEN
				Raster.SetRGBA(pix, 255, 0, 0, 255)
			ELSE
				Raster.SetRGBA(pix, 0, 0, 0, 255)
			END;
			Raster.Put(buffer, x, y, pix, mode);
			INC(p);
		END;
	END;
END AdaptiveThresholdFilter;

PROCEDURE SetAdaptiveThresholdFilter*(context : Commands.Context);
BEGIN
	VideoExample.InstallFrameHandler(AdaptiveThresholdFilter)
END SetAdaptiveThresholdFilter;

PROCEDURE FineAdaptiveThresholdFilter(buffer : Raster.Image);
CONST WindowX = 32;
VAR x, y, w, h, p, t : LONGINT;
	sum : LONGINT;
	mode : Raster.Mode;
	pix : Raster.Pixel;
	ch : CHAR;
	adr : LONGINT;
	total : LONGINT;

BEGIN
	Raster.InitMode(mode, Raster.srcCopy);
	w := buffer.width; h := buffer.height;
	IF (intensityBuffer = NIL) OR (LEN(intensityBuffer^) < w*h) THEN NEW(intensityBuffer, w*h) END;
	IF (thresholdBuffer = NIL) OR (LEN(thresholdBuffer^) < w*h) THEN NEW(thresholdBuffer, w*h) END;

	(* create intensity array *)
	p := 0; total := 0;
	FOR y := 0 TO h - 1 DO
		adr := buffer.adr + y *  buffer.bpr;
		FOR x := 0 TO w - 1 DO
			INC(adr);
			SYSTEM.GET(adr, ch); sum :=  ORD(ch); INC(adr);
			SYSTEM.GET(adr, ch); sum := sum + ORD(ch); INC(adr);
			intensityBuffer[p] := CHR(sum DIV 2);
			total := total + (sum DIV 2);
			INC(p)
		END;
	END;

	p := 0;
	FOR y := 0 TO h - 1 DO
		total := 0;
		FOR x := 0 TO WindowX - 1 DO INC(total, ORD(intensityBuffer[p])); INC(p) END;
		t := y * w;
		FOR x := 0 TO WindowX DIV 2 - 1 DO thresholdBuffer[t] := CHR(total DIV WindowX); INC(t) END;
		FOR x := WindowX DIV 2 TO w - WindowX DIV 2 - 1 DO
			total := total - ORD(intensityBuffer[p- WindowX]) + ORD(intensityBuffer[p]);
			thresholdBuffer[t] := CHR(total DIV WindowX ); INC(t);
			INC(p)
		END;
		FOR x := w - WindowX DIV 2 TO w - 1 DO thresholdBuffer[t] := CHR(total DIV WindowX); INC(t) END;
	END;

	p := 0;
	FOR y := 0 TO (h-1) DIV 4 - 1 DO
		FOR x := 0 TO w - 1 DO
	(*		total := 	ORD(thresholdBuffer[p]);
			total := 	total + ORD(thresholdBuffer[p + w]);
			total := 	total + ORD(thresholdBuffer[p + 2 * w]);
			total := 	total + ORD(thresholdBuffer[p + 3 * w]);
			total := 7*total DIV (4*8); *)
			total := 	ORD(thresholdBuffer[p]);
			total := 	total + ORD(thresholdBuffer[p + 1* w]);
			total := 	total + ORD(thresholdBuffer[p + 2 * w]);
			total := 	total + ORD(thresholdBuffer[p + 3 * w]);
			total := 	total + ORD(thresholdBuffer[p + 4 * w]);
			total := 	total + ORD(thresholdBuffer[p + 5 * w]);
			total := 	total + ORD(thresholdBuffer[p + 6 * w]);
			total := 	total + ORD(thresholdBuffer[p + 7 * w]);
			total := 14*total DIV (8*16);
			thresholdBuffer[p] := CHR(total); thresholdBuffer[p + w] := CHR(total); thresholdBuffer[p + 2 * w] := CHR(total); thresholdBuffer[p + 3 * w] := CHR(total);
			INC(p)
		END;
		INC(p, 3 * w);
	END;

	p := 0;
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			IF  ORD(intensityBuffer[p]) < ORD(thresholdBuffer[p]) THEN
				Raster.SetRGBA(pix, 255, 0, 0, 255)
			ELSE
				Raster.SetRGBA(pix, 0, 0, 0, 255)
			END;
			Raster.Put(buffer, x, y, pix, mode);
			INC(p);
		END;
	END;
END FineAdaptiveThresholdFilter;

PROCEDURE SetFineAdaptiveThresholdFilter*(context : Commands.Context);
BEGIN
	VideoExample.InstallFrameHandler(FineAdaptiveThresholdFilter)
END SetFineAdaptiveThresholdFilter;

PROCEDURE SetLabelFilter*(context : Commands.Context);
VAR
	options: Options.Options;
BEGIN
	NEW(options);
	options.Add("t","threshold", Options.Integer);
	options.Add("p","pixelThreshold", Options.Integer);
	threshold := 50;
	pixThreshold := 50;
	IF options.Parse(context.arg, context.out) THEN
		IF options.GetInteger("threshold", threshold) THEN END;
		IF options.GetInteger("pixelThreshold", pixThreshold) THEN END;
	END;
	VideoExample.InstallFrameHandler(Label2)
END SetLabelFilter;

PROCEDURE Uninstall*;
BEGIN
	VideoExample.InstallFrameHandler(NIL)
END Uninstall;

PROCEDURE Init;
VAR i : LONGINT;
	gen : Random.Generator;
BEGIN
	NEW(gen);
	FOR i := 1 TO LEN(labelColor) - 1 DO labelColor[i] := gen.Integer();  END;
	labelColor[0] := LONGINT(0FFFFFFFFH);

	dirX[DirN] := 0; dirY[DirN] := -1; (* N *)
	dirX[DirNE] := 1; dirY[DirNE] := -1; (* NE *)
	dirX[DirE] := 1; dirY[DirE] := 0; (* E *)
	dirX[DirSE] := 1; dirY[DirSE] := 1; (* SE *)
	dirX[DirS] := 0; dirY[DirS] := 1; (* S *)
	dirX[DirSW] := -1; dirY[DirSW] := 1; (* SW *)
	dirX[DirW] := -1; dirY[DirW] := 0; (* W *)
	dirX[DirNW] := -1; dirY[DirNW] := -1; (* NW *)
END Init;


PROCEDURE Cleanup;
VAR timer : Kernel.Timer;
BEGIN
	VideoExample.InstallFrameHandler(NIL);
	(* hack to not remove the module while a frame is still being filtered *)
	NEW(timer);
	timer.Sleep(1000);
END Cleanup;

BEGIN
	NEW(rectified, 256, 256);
	Init;
	SetYUVFilter();
	Modules.InstallTermHandler(Cleanup)
END TestVideo.

SystemTools.Free TestVideo ~
TestVideo.SetLabelFilter -t=250 ~
TestVideo.SetThresholdFilter -t=300 ~

TestVideo.SetRedDotFilter ~
TestVideo.SetYUVFilter ~
TestVideo.SetBWFilter ~
TestVideo.Uninstall ~


VideoExample.Start ~
VideoExample.Stop ~

SystemTools.Free TestVideo ~
TestVideo.SetLabelFilter -t=360 p=20 ~
VideoExample.SimulateImage "sample0.jpg" ~
