(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE GfxImages; (** non-portable *)	(* eos  **)
(** AUTHOR "eos"; PURPOSE "Gfx raster image transformations"; *)

	(*
		24.05.2000 - adapted to new Raster module
	*)

	IMPORT
		SYSTEM, Raster, GfxMatrix;


	(**
		Image transformations are decomposed into a series of one-dimensional shift and scale transforms. These
		are delegated to a filter object provided by the caller. The caller controls visual quality and execution time
		by selecting a filter which complies with its demands.
	**)

	TYPE
		Image* = Raster.Image;

		ShiftProc* = PROCEDURE (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; t: REAL);
		ScaleProc* = PROCEDURE (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; xy, dxy: REAL);

		(** transformation filter **)
		Filter* = RECORD (Raster.Mode)
			hshift*, vshift*: ShiftProc;	(** procedures for shifting rows and columns **)
			hscale*, vscale*: ScaleProc;	(** procedures for scaling rows and columns **)
		END;


	VAR
		PreCache, Cache: Image;	(* caches for image transformations *)
		hshift*, vshift*: ShiftProc;

	(**--- Filters ---**)

	(** predefined filter procedures using box filter (i.e. no filtering): fast and ugly **)

	PROCEDURE HShift* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; tx: REAL);
	BEGIN
		IF tx >= 0.5 THEN
			dbit := dbit + dst.fmt.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len)
		END;
		Raster.Bind(filter, src.fmt, dst.fmt);
		filter.transfer(filter, sadr, sbit, dadr, dbit, len)
	END HShift;

	PROCEDURE VShift* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; ty: REAL);
	BEGIN
		IF ty >= 0.5 THEN
			INC(dadr, dst.bpr);
			DEC(len)
		END;
		Raster.Bind(filter, src.fmt, dst.fmt);
		WHILE len > 0 DO
			filter.transfer(filter, sadr, sbit, dadr, dbit, 1);
			INC(sadr, src.bpr); INC(dadr, dst.bpr);
			DEC(len)
		END
	END VShift;

	PROCEDURE HScale* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, dlen: LONGINT; x, dx: REAL);
		VAR i0, i1: LONGINT;
	BEGIN
		Raster.Bind(filter, src.fmt, dst.fmt);
		i0 := 0;
		WHILE dlen > 0 DO
			i1 := ENTIER(x);
			IF i0 < i1 THEN
				IF i1 >= src.width THEN i1 := src.width-1 END;
				sbit := sbit + (i1 - i0) * src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
				i0 := i1
			END;
			filter.transfer(filter, sadr, sbit, dadr, dbit, 1);
			dbit := dbit + dst.fmt.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			x := x + dx; DEC(dlen)
		END
	END HScale;

	PROCEDURE VScale* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, dlen: LONGINT; y, dy: REAL);
		VAR j0, j1: LONGINT;
	BEGIN
		Raster.Bind(filter, src.fmt, dst.fmt);
		j0 := 0;
		WHILE dlen > 0 DO
			j1 := ENTIER(y);
			IF j0 < j1 THEN
				IF j1 >= src.height THEN j1 := src.height-1 END;
				INC(sadr, (j1 - j0) * src.bpr);
				j0 := j1
			END;
			filter.transfer(filter, sadr, sbit, dadr, dbit, 1);
			INC(dadr, dst.bpr);
			y := y + dy; DEC(dlen)
		END
	END VScale;

	(** predefined filter procedures for linearly filtered transformations: slow and less ugly **)

	PROCEDURE LinearHShift* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; tx: REAL);
		CONST r = Raster.r; g = Raster.g; b = Raster.b; a = Raster.a;
		VAR w0, w1, sinc, dinc, i, red, green, blue, alpha: LONGINT; da: ADDRESS; spix, dpix: Raster.Pixel;
	BEGIN
		w0 := ENTIER(1000H*tx + 0.5); w1 := 1000H-w0;
		IF (w0 < 10H) OR (w1 < 10H) THEN
			HShift(filter, src, dst, sadr, sbit, dadr, dbit, len, tx)
		ELSE
			Raster.Bind(filter, Raster.PixelFormat, dst.fmt);
			sinc := src.fmt.bpp; dinc := dst.fmt.bpp; da := dadr;
			src.fmt.unpack(src.fmt, sadr, sbit, spix);
			FOR i := 0 TO 3 DO dpix[i] := CHR(w1 * ORD(spix[i]) DIV 1000H) END;
			filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
			INC(dbit, dinc); INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len);
			WHILE len > 0 DO
				red := w0 * ORD(spix[r]); green := w0 * ORD(spix[g]); blue := w0 * ORD(spix[b]); alpha := w0 * ORD(spix[a]);
				INC(sbit, sinc); INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
				src.fmt.unpack(src.fmt, sadr, sbit, spix);
				dpix[r] := CHR((red + w1 * ORD(spix[r])) DIV 1000H);
				dpix[g] := CHR((green + w1 * ORD(spix[g])) DIV 1000H);
				dpix[b] := CHR((blue + w1 * ORD(spix[b])) DIV 1000H);
				dpix[a] := CHR((alpha + w1 * ORD(spix[a])) DIV 1000H);
				filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
				INC(dbit, dinc); INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
				DEC(len)
			END;
			IF (da - dst.adr) DIV dst.bpr = (dadr - dst.adr) DIV dst.bpr THEN
				FOR i := 0 TO 3 DO dpix[i] := CHR(w0 * ORD(spix[i]) DIV 1000H) END;
				filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1)
			END
		END
	END LinearHShift;

	PROCEDURE LinearVShift* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT; ty: REAL);
		CONST r = Raster.r; g = Raster.g; b = Raster.b; a = Raster.a;
		VAR w0, w1, i, red, green, blue, alpha: LONGINT; spix, dpix: Raster.Pixel;
	BEGIN
		w0 := ENTIER(1000H*ty + 0.5); w1 := 1000H-w0;
		IF (w0 < 10H) OR (w1 < 10H) THEN
			VShift(filter, src, dst, sadr, sbit, dadr, dbit, len, ty)
		ELSE
			Raster.Bind(filter, Raster.PixelFormat, dst.fmt);
			src.fmt.unpack(src.fmt, sadr, sbit, spix);
			FOR i := 0 TO 3 DO dpix[i] := CHR(w1 * ORD(spix[i]) DIV 1000H) END;
			filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
			INC(dadr, dst.bpr);
			DEC(len);
			WHILE len > 0 DO
				red := w0 * ORD(spix[r]); green := w0 * ORD(spix[g]); blue := w0 * ORD(spix[b]); alpha := w0 * ORD(spix[a]);
				INC(sadr, src.bpr);
				src.fmt.unpack(src.fmt, sadr, sbit, spix);
				dpix[r] := CHR((red + w1 * ORD(spix[r])) DIV 1000H);
				dpix[g] := CHR((green + w1 * ORD(spix[g])) DIV 1000H);
				dpix[b] := CHR((blue + w1 * ORD(spix[b])) DIV 1000H);
				dpix[a] := CHR((alpha + w1 * ORD(spix[a])) DIV 1000H);
				filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
				INC(dadr, dst.bpr);
				DEC(len)
			END;
			IF (dst.adr < dadr) & (dadr < dst.adr + dst.height * dst.bpr) THEN
				FOR i := 0 TO 3 DO dpix[i] := CHR(w0 * ORD(spix[i]) DIV 1000H) END;
				filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1)
			END
		END
	END LinearVShift;

	PROCEDURE LinearHScale* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, dlen: LONGINT; x, dx: REAL);
		VAR i0, i1,  w1, w0, j: LONGINT; spix: ARRAY 2 OF Raster.Pixel; dpix: Raster.Pixel;
	BEGIN
		Raster.Bind(filter, Raster.PixelFormat, dst.fmt);
		x := x+0.5;	(* displace sample position to midpoint between candidate pixels *)
		i0 := 0;
		src.fmt.unpack(src.fmt, sadr, sbit, spix[0]); spix[1] := spix[0];
		WHILE dlen > 0 DO
			i1 := ENTIER(x);
			IF i1 > i0 THEN
				INC(i0);
				IF i0 >= src.width THEN
					spix[0] := spix[1]
				ELSIF i1 = i0 THEN
					spix[0] := spix[1];
					sbit := sbit + src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
					src.fmt.unpack(src.fmt, sadr, sbit, spix[1])
				ELSIF i1 < src.width THEN
					sbit := sbit + (i1 - i0) * src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
					src.fmt.unpack(src.fmt, sadr, sbit, spix[0]);
					sbit := sbit + src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
					src.fmt.unpack(src.fmt, sadr, sbit, spix[1])
				ELSE
					sbit := sbit + (src.width - i0) * src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
					src.fmt.unpack(src.fmt, sadr, sbit, spix[0]); spix[1] := spix[0]
				END;
				i0 := i1
			END;
			w1 := ENTIER(1000H*(x - i1)); w0 := 1000H-w1;
			FOR j := 0 TO 3 DO
				dpix[j] := Raster.Clamp[200H + (ORD(spix[0, j]) * w0 + ORD(spix[1, j]) * w1) DIV 1000H]
			END;
			filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
			dbit := dbit + dst.fmt.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			x := x + dx; DEC(dlen)
		END
	END LinearHScale;

	PROCEDURE LinearVScale* (VAR filter: Raster.Mode; src, dst: Image; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, dlen: LONGINT; y, dy: REAL);
		VAR j0, j1, w1, w0, j: LONGINT; spix: ARRAY 2 OF Raster.Pixel; dpix: Raster.Pixel;
	BEGIN
		Raster.Bind(filter, Raster.PixelFormat, dst.fmt);
		y := y+0.5;	(* displace sample position to midpoint between candidate pixels *)
		j0 := 0;
		src.fmt.unpack(src.fmt, sadr, sbit, spix[0]); spix[1] := spix[0];
		WHILE dlen > 0 DO
			j1 := ENTIER(y);
			IF j1 > j0 THEN
				INC(j0);
				IF j0 >= src.height THEN
					spix[0] := spix[1]
				ELSIF j1 = j0 THEN
					spix[0] := spix[1];
					INC(sadr, src.bpr);
					src.fmt.unpack(src.fmt, sadr, sbit, spix[1])
				ELSIF j1 < src.height THEN
					INC(sadr, (j1 - j0) * src.bpr);
					src.fmt.unpack(src.fmt, sadr, sbit, spix[0]);
					INC(sadr, src.bpr);
					src.fmt.unpack(src.fmt, sadr, sbit, spix[1])
				ELSE
					INC(sadr, src.bpr);
					src.fmt.unpack(src.fmt, sadr, sbit, spix[0]); spix[1] := spix[0]
				END;
				j0 := j1
			END;
			w1 := ENTIER(1000H*(y - j1)); w0 := 1000H-w1;
			FOR j := 0 TO 3 DO
				dpix[j] := Raster.Clamp[200H + (ORD(spix[0, j]) * w0 + ORD(spix[1, j]) * w1) DIV 1000H]
			END;
			filter.transfer(filter, ADDRESSOF(dpix[0]), 0, dadr, dbit, 1);
			INC(dadr, dst.bpr);
			y := y + dy; DEC(dlen)
		END
	END LinearVScale;

	(** initialize filter with compositing operation and transformation procedures **)
	PROCEDURE InitFilter* (VAR filter: Filter; op: SHORTINT; hshift, vshift: ShiftProc; hscale, vscale: ScaleProc);
	BEGIN
		Raster.InitMode(filter, op);
		filter.hshift := hshift; filter.vshift := vshift;
		filter.hscale := hscale; filter.vscale := vscale
	END InitFilter;

	(* get temporary pixel format image for storing intermediate images *)
	PROCEDURE GetTempImage (VAR img, cache: Raster.Image; w, h: LONGINT);
		VAR size: LONGINT;
	BEGIN
		size := w * h;
		IF (size >= 10000H) OR (cache = NIL) THEN
			NEW(img)
		ELSE
			img := cache; cache := NIL
		END;
		Raster.Create(img, w, h, Raster.PixelFormat)
	END GetTempImage;

	PROCEDURE FreeTempImage (VAR img, cache: Raster.Image);
	BEGIN
		IF img.width * img.height < 10000H THEN
			cache := img
		END
	END FreeTempImage;

	(* depending on matrix elements, transpose/mirror image to avoid bottleneck problems *)
	PROCEDURE Preprocess (VAR src: Raster.Image; VAR m: GfxMatrix.Matrix; VAR filter: Filter);
		CONST
			r = Raster.r; g = Raster.g; b = Raster.b;
		VAR
			dst: Raster.Image; mode: Raster.Mode; dinc, sinc, h, w, sbit: LONGINT;
			dadr, sadr, sa, da: ADDRESS;
			mat: GfxMatrix.Matrix; t: REAL;
	BEGIN
		IF ABS(m[0, 0] * m[1, 1]) >= ABS(m[0, 1] * m[1, 0]) THEN	(* no need to swap rows and columns *)
			IF (m[0, 0] <= 0) OR (m[1, 1] <= 0) THEN
				GetTempImage(dst, PreCache, src.width, src.height);
				Raster.InitModeColor(mode, Raster.srcCopy, ORD(filter.col[r]), ORD(filter.col[g]), ORD(filter.col[b]));
				Raster.Bind(mode, src.fmt, dst.fmt);
				IF m[0, 0] >= 0 THEN dadr := dst.adr; dinc := 4
				ELSE dadr := dst.adr + 4*(dst.width-1); dinc := -4
				END;
				IF m[1, 1] >= 0 THEN sadr := src.adr; sinc := src.bpr
				ELSE sadr := src.adr + (src.height-1) * src.bpr; sinc := -src.bpr
				END;
				h := 0;
				WHILE h < src.height DO
					w := 0; sa := sadr; sbit := 0; da := dadr;
					WHILE w < src.width DO
						mode.transfer(mode, sa, sbit, da, 0, 1);
						sbit := sbit + src.fmt.bpp; INC(sa, sbit DIV 8); sbit := sbit MOD 8;
						INC(da, dinc); INC(w)
					END;
					INC(sadr, sinc); INC(dadr, dst.bpr); INC(h)
				END;
				IF m[0, 0] < 0 THEN
					GfxMatrix.Init(mat, -1, 0, 0, 1, w, 0);
					GfxMatrix.Concat(mat, m, m)
				END;
				IF m[1, 1] < 0 THEN
					GfxMatrix.Init(mat, 1, 0, 0, -1, 0, h);
					GfxMatrix.Concat(mat, m, m)
				END;
				src := dst;
				FreeTempImage(dst, PreCache)	(* reuse allocated image in next call *)
			END
		ELSE	(* need to transpose *)
			t := m[0, 0]; m[0, 0] := m[1, 0]; m[1, 0] := t;
			t := m[0, 1]; m[0, 1] := m[1, 1]; m[1, 1] := t;
			GetTempImage(dst, PreCache, src.height, src.width);
			Raster.InitModeColor(mode, Raster.srcCopy, ORD(filter.col[r]), ORD(filter.col[g]), ORD(filter.col[b]));
			Raster.Bind(mode, src.fmt, dst.fmt);
			IF m[0, 0] <= 0 THEN dadr := dst.adr; dinc := dst.bpr
			ELSE dadr := dst.adr + (dst.height-1) * dst.bpr; dinc := -dst.bpr
			END;
			IF m[1, 1] <= 0 THEN sadr := src.adr; sinc := src.bpr
			ELSE sadr := src.adr + (src.height-1) * src.bpr; sinc := -src.bpr
			END;
			h := 0;
			WHILE h < src.height DO
				w := 0; sa := sadr; sbit := 0; da := dadr;
				WHILE w < src.width DO
					mode.transfer(mode, sa, sbit, da, 0, 1);
					sbit := sbit + src.fmt.bpp; INC(sa, sbit DIV 8); sbit := sbit MOD 8;
					INC(da, dinc); INC(w)
				END;
				INC(sadr, sinc); INC(dadr, 4); INC(h)
			END;
			IF m[0, 0] < 0 THEN
				GfxMatrix.Init(mat, -1, 0, 0, 1, dst.width, 0);
				GfxMatrix.Concat(mat, m, m)
			END;
			IF m[1, 1] < 0 THEN
				GfxMatrix.Init(mat, 1, 0, 0, -1, 0, dst.height);
				GfxMatrix.Concat(mat, m, m)
			END;
			src := dst;
			FreeTempImage(dst, PreCache)
		END
	END Preprocess;

	(* shift source row by fractional amount *)
	PROCEDURE SkewRow (src, dst: Image; si, sj, w, di, dj: LONGINT; tx: REAL; VAR filter: Filter);
		VAR sbit, dbit: LONGINT; sadr, dadr: ADDRESS;
	BEGIN
		ASSERT((0.0 <= tx) & (tx <= 1.0), 100);	(* rounding problem if using tx < 1.0 *)
		IF si < 0 THEN INC(w, si); DEC(di, si); si := 0 END;
		IF si + w > src.width THEN w := src.width - si END;
		IF w > 0 THEN
			sbit := si * src.fmt.bpp; sadr := src.adr + sj * src.bpr + sbit DIV 8; sbit := sbit MOD 8;
			dbit := di * dst.fmt.bpp; dadr := dst.adr + dj * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			filter.hshift(filter, src, dst, sadr, sbit, dadr, dbit, w, tx)
		END
	END SkewRow;

	(* shear rectangle in source image horizontally; clip to destination boundary *)
	PROCEDURE SkewRows (src, dst: Image; si, sj, w, h, dj: LONGINT; x, dx: REAL; VAR filter: Filter);
		VAR j, di, n: LONGINT;
	BEGIN
		j := 0;
		IF dj < 0 THEN
			j := -dj;
			IF j >= h THEN RETURN END
		END;
		IF dj + h > dst.height THEN
			h := dst.height - dj;
			IF h <= 0 THEN RETURN END
		END;

		IF dx > 0 THEN
			IF x + h * dx >= dst.width THEN
				h := -ENTIER((x - dst.width)/dx)
			END;
			x := x + j * dx;
			IF x + w < 0 THEN
				n := -ENTIER((x + w)/dx);
				INC(j, n); x := x + n * dx
			END;
			IF x < 0 THEN
				n := j - ENTIER(x/dx);
				IF n > h THEN n := h END;
				WHILE j < n DO
					di := ENTIER(x);
					IF di + w > dst.width THEN w := dst.width END;
					SkewRow(src, dst, si - di, sj + j, di + w, 0, dj + j, x - di, filter);
					INC(j); x := x + dx
				END
			END;
			WHILE j < h DO
				di := ENTIER(x);
				IF di + w > dst.width THEN w := dst.width - di END;
				SkewRow(src, dst, si, sj + j, w, di, dj + j, x - di, filter);
				INC(j); x := x + dx
			END

		ELSIF dx < 0 THEN
			IF x + w + h * dx < 0 THEN
				h := -ENTIER((x + w)/dx)
			END;
			x := x + j * dx;
			IF x >= dst.width THEN
				n := ENTIER((dst.width - x)/dx) + 1;
				INC(j, n); x := x + n * dx
			END;
			n := j - ENTIER(x/dx);	(* row at which x drops below zero *)
			IF n > h THEN n := h END;
			WHILE j < n DO
				di := ENTIER(x);
				IF di + w < dst.width THEN
					SkewRow(src, dst, si, sj + j, w, di, dj + j, x - di, filter)
				ELSE
					SkewRow(src, dst, si, sj + j, dst.width - di, di, dj + j, x - di, filter)
				END;
				INC(j); x := x + dx
			END;
			WHILE j < h DO
				di := ENTIER(x);
				IF di + w < dst.width THEN
					SkewRow(src, dst, si - di, sj + j, di + w, 0, dj + j, x - di, filter)
				ELSE
					SkewRow(src, dst, si - di, sj + j, dst.width, 0, dj + j, x - di, filter)
				END;
				INC(j); x := x + dx
			END

		ELSIF x < 0 THEN
			di := ENTIER(x);
			IF di + w > dst.width THEN
				si := si - di; x := x - di;
				WHILE j < h DO
					SkewRow(src, dst, si, sj + j, dst.width, 0, dj + j, x, filter);
					INC(j)
				END
			ELSIF di + w >= 0 THEN
				si := si - di; w := w + di; x := x - di;
				WHILE j < h DO
					SkewRow(src, dst, si, sj + j, w, 0, dj + j, x, filter);
					INC(j)
				END
			END

		ELSIF x < dst.width THEN
			di := ENTIER(x); x := x - di;
			IF di + w > dst.width THEN w := dst.width - di END;
			WHILE j < h DO
				SkewRow(src, dst, si, sj + j, w, di, dj + j, x, filter);
				INC(j)
			END
		END
	END SkewRows;

	(* shift source column by fractional amount *)
	PROCEDURE SkewCol (src, dst: Image; si, sj, h, di, dj: LONGINT; ty: REAL; VAR filter: Filter);
		VAR sbit, dbit: LONGINT; sadr, dadr: ADDRESS;
	BEGIN
		ASSERT((0.0 <= ty) & (ty <= 1.0), 100);	(* rounding problem with ty < 1.0 *)
		IF sj < 0 THEN INC(h, sj); DEC(dj, sj); sj := 0 END;
		IF sj + h > src.height THEN h := src.height - sj END;
		IF h > 0 THEN
			sbit := si * src.fmt.bpp; sadr := src.adr + sj * src.bpr + sbit DIV 8; sbit := sbit MOD 8;
			dbit := di * dst.fmt.bpp; dadr := dst.adr + dj * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			filter.vshift(filter, src, dst, sadr, sbit, dadr, dbit, h, ty)
		END
	END SkewCol;

	(* shear rectangle in source image vertically; clip to destination boundary *)
	PROCEDURE SkewCols (src, dst: Image; si, sj, w, h, di: LONGINT; y, dy: REAL; VAR filter: Filter);
		VAR i, dj, n: LONGINT;
	BEGIN
		i := 0;
		IF di < 0 THEN
			i := -di;
			IF i >= w THEN RETURN END
		END;
		IF di + w > dst.width THEN
			w := dst.width - di;
			IF w <= 0 THEN RETURN END
		END;

		IF dy > 0 THEN
			IF y + w * dy >= dst.height THEN
				w := -ENTIER((y - dst.height)/dy)
			END;
			y := y + i * dy;
			IF y + h < 0 THEN
				n := -ENTIER((y + h)/dy);
				INC(i, n); y := y + n * dy
			END;
			IF y < 0 THEN
				n := i - ENTIER(y/dy);
				IF n > w THEN n := w END;
				WHILE i < n DO
					dj := ENTIER(y);
					IF dj + h > dst.height THEN h := dst.height END;
					SkewCol(src, dst, si + i, sj - dj, dj + h, di + i, 0, y - dj, filter);
					INC(i); y := y + dy
				END
			END;
			WHILE i < w DO
				dj := ENTIER(y);
				IF dj + h > dst.height THEN h := dst.height - dj END;
				SkewCol(src, dst, si + i, sj, h, di + i, dj, y - dj, filter);
				INC(i); y := y + dy
			END

		ELSIF dy < 0 THEN
			IF y + h + w * dy < 0 THEN
				w := -ENTIER((y + h)/dy)
			END;
			y := y + i * dy;
			IF y >= dst.height THEN
				n := ENTIER((dst.height - y)/dy) + 1;
				INC(i, n); y := y + n * dy
			END;
			n := i - ENTIER(y/dy);	(* column at which y drops below zero *)
			IF n > w THEN n := w END;
			WHILE i < n DO
				dj := ENTIER(y);
				IF dj + h < dst.height THEN
					SkewCol(src, dst, si + i, sj, h, di + i, dj, y - dj, filter)
				ELSE
					SkewCol(src, dst, si + i, sj, dst.height - dj, di + i, dj, y - dj, filter)
				END;
				INC(i); y := y + dy
			END;
			WHILE i < w DO
				dj := ENTIER(y);
				IF dj + h < dst.height THEN
					SkewCol(src, dst, si + i, sj - dj, h + dj, di + i, 0, y - dj, filter)
				ELSE
					SkewCol(src, dst, si + i, sj - dj, dst.height, di + i, 0, y - dj, filter)
				END;
				INC(i); y := y + dy
			END

		ELSIF y < 0 THEN
			dj := ENTIER(y);
			IF dj + h > dst.height THEN
				sj := sj - dj; y := y - dj;
				WHILE i < w DO
					SkewCol(src, dst, si + i, sj, dst.height, di + i, 0, y, filter);
					INC(i)
				END
			ELSIF dj + h >= 0 THEN
				sj := sj - dj; h := h + dj; y := y - dj;
				WHILE i < w DO
					SkewCol(src, dst, si + i, sj, h, di + i, 0, y, filter);
					INC(i)
				END
			END

		ELSIF y < dst.height THEN
			dj := ENTIER(y); y := y - dj;
			IF dj + h > dst.height THEN h := dst.height - di END;
			WHILE i < w DO
				SkewCol(src, dst, si + i, sj, h, di + i, dj, y, filter);
				INC(i)
			END
		END
	END SkewCols;

	(** render translated image on destination **)
	PROCEDURE Translate* (src, dst: Image; tx, ty: REAL; VAR filter: Filter);
		VAR ti, tj, i, j, w, h: LONGINT; tmp: Image;
	BEGIN
		ti := ENTIER(tx); tx := tx - ti;
		tj := ENTIER(ty); ty := ty - tj;
		IF tx < 0.01 THEN
			SkewCols(src, dst, 0, 0, src.width, src.height, ti, tj + ty, 0, filter)
		ELSIF ty < 0.01 THEN
			SkewRows(src, dst, 0, 0, src.width, src.height, tj, ti + tx, 0, filter)
		ELSE
			i := 0; j := 0; w := src.width; h := src.height;
			IF ti < 0 THEN i := -ti; INC(w, ti) END;
			IF ti + w >= dst.width THEN w := dst.width - ti - 1 END;
			IF tj < 0 THEN j := -tj; INC(h, tj) END;
			IF tj + h >= dst.height THEN h := dst.height - tj - 1 END;
			GetTempImage(tmp, Cache, w, h+1);
			SkewCols(src, tmp, i, j, w, h, 0, ty, 0, filter);
			SkewRows(tmp, dst, 0, 0, tmp.width, tmp.height, tj, ti + tx, 0, filter);
			FreeTempImage(tmp, Cache)
		END
	END Translate;

	(** render scaled image on destination **)
	PROCEDURE Scale* (src, dst: Image; sx, sy, tx, ty: REAL; VAR filter: Filter);
		VAR xl, xr, yb, yt, w, h, sbit, dbit, i: LONGINT; sadr, dadr: ADDRESS; dy, y, dx, x: REAL; tmp: Image;
	BEGIN
		ASSERT((sx > 0) & (sy > 0), 100);
		xl := ENTIER(tx); xr := -ENTIER(-(tx + sx * src.width));
		IF xl < 0 THEN xl := 0 END;
		IF xr > dst.width THEN
			xr := dst.width;
			IF xr <= xl THEN RETURN END;
		END;
		yb := ENTIER(ty); yt := -ENTIER(-(ty + sy * src.height));
		IF yb < 0 THEN yb := 0 END;
		IF yt > dst.height THEN
			yt := dst.height;
			IF yt <= yb THEN RETURN END
		END;
		w := xr - xl; h := yt - yb;

		IF ABS(w - src.width) < 1 THEN
			dy := 1.0/sy; y := (0.5 - (ty - ENTIER(ty))) * dy;
			sadr := src.adr; sbit := 0;
			dbit := xl * dst.fmt.bpp; dadr := dst.adr + yb * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			i := 0;
			WHILE i < src.width DO
				filter.vscale(filter, src, dst, sadr, sbit, dadr, dbit, h, y, dy);
				sbit := sbit + src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
				dbit := dbit + dst.fmt.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
				INC(i)
			END

		ELSIF ABS(h - src.height) < 1 THEN
			dx := 1.0/sx; x := (0.5 - (tx - ENTIER(tx))) * dx;
			sadr := src.adr; sbit := 0;
			dbit := xl * dst.fmt.bpp; dadr := dst.adr + yb * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			i := 0;
			WHILE i < src.height DO
				filter.hscale(filter, src, dst, sadr, sbit, dadr, dbit, w, x, dx);
				INC(sadr, src.bpr); INC(dadr, dst.bpr);
				INC(i)
			END

		ELSE
			GetTempImage(tmp, Cache, src.width, h);
			dy := 1.0/sy; y := (0.5 - (ty - ENTIER(ty))) * dy;
			sadr := src.adr; sbit := 0; dadr := tmp.adr; dbit := 0;
			i := 0;
			WHILE i < src.width DO
				filter.vscale(filter, src, tmp, sadr, sbit, dadr, dbit, h, y, dy);
				sbit := sbit + src.fmt.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
				dbit := dbit + tmp.fmt.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
				INC(i)
			END;
			dx := 1.0/sx; x := (0.5 - (tx - ENTIER(tx))) * dx;
			sadr := tmp.adr; sbit := 0;
			dbit := xl * dst.fmt.bpp; dadr := dst.adr + yb * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			i := 0;
			WHILE i < h DO
				filter.hscale(filter, tmp, dst, sadr, sbit, dadr, dbit, w, x, dx);
				INC(sadr, tmp.bpr); INC(dadr, dst.bpr);
				INC(i)
			END;
			FreeTempImage(tmp, Cache)
		END
	END Scale;

	(** render rotated image on destination **)
	PROCEDURE Rotate* (src, dst: Image; sin, cos, tx, ty: REAL; VAR filter: Filter);
		VAR m: GfxMatrix.Matrix; tan, htan, wsin, hcos, x, y: REAL; wmax, h, iy, sw, sh: LONGINT; tmp: Image;
	BEGIN
		ASSERT(ABS(sin * sin + cos * cos - 1) < 0.0001, 100);
		m[0, 0] := cos; m[0, 1] := sin; m[1, 0] := -sin; m[1, 1] := cos; m[2, 0] := tx; m[2, 1] := ty;
		Preprocess(src, m, filter);
		cos := m[0, 0]; sin := m[0, 1]; tx := m[2, 0]; ty := m[2, 1];
		tan := sin/(1.0 + cos);	(* identity for tan(phi/2); 1/2 SQRT(3) <= cos <= 1 *)
		sw := src.width; sh := src.height;
		htan := ABS(tan) * sh;
		wsin := ABS(sin) * sw;
		hcos := cos * sh;
		wmax := sw + ENTIER(htan) + 1;	(* width of intermediate image *)
		h := ENTIER(wsin + hcos) + 2;	(* second extra pixel for ty - tj *)
		GetTempImage(tmp, Cache, wmax, h + sh);	(* stack two intermediate images on top of each other *)
		IF sin >= 0 THEN
			x := htan; tx := tx - x; y := hcos - sh
		ELSE
			x := 0; y := wsin; tx := tx + wsin * tan; ty := ty - y
		END;
		iy := ENTIER(ty); y := y + (ty - iy);
		SkewRows(src, tmp, 0, 0, sw, sh, h, x, -tan, filter);	(* first pass: skew horizontal scanlines *)
		SkewCols(tmp, tmp, 0, h, wmax, sh, 0, y, sin, filter);	(* second pass: skew vertical scanlines *)
		SkewRows(tmp, dst, 0, 0, wmax, h, iy, tx, -tan, filter);	(* third pass: skew horizontal scanlines *)
		FreeTempImage(tmp, Cache)
	END Rotate;

	(** render horizontally sheared image on destination **)
	PROCEDURE ShearRows* (src, dst: Image; sx, tx: REAL; VAR filter: Filter);
	BEGIN
		SkewRows(src, dst, 0, 0, src.width, src.height, 0, tx, sx, filter)
	END ShearRows;

	(** render vertically sheared image on destination **)
	PROCEDURE ShearCols* (src, dst: Image; sy, ty: REAL; VAR filter: Filter);
	BEGIN
		SkewCols(src, dst, 0, 0, src.width, src.height, 0, ty, sy, filter)
	END ShearCols;

	(** render affinely transformed image on destination **)
	PROCEDURE Transform* (src, dst: Image; m: GfxMatrix.Matrix; VAR filter: Filter);
		CONST eps = 0.003;
		VAR det, s, dx, x: REAL; iy, w, h, ix: LONGINT; tmp: Image;
	BEGIN
		Preprocess(src, m, filter);
		IF (ABS(m[0, 0]) >= eps) & (ABS(m[1, 1]) >= eps) THEN	(* matrix isn't singular *)
			IF (ABS(m[0, 1]) < eps) & (ABS(m[1, 0]) < eps) THEN	(* no rotation or shear *)
				IF (ABS(m[0, 0]-1) < eps) & (ABS(m[1, 1]-1) < eps) THEN	(* not even scaled *)
					Translate(src, dst, m[2, 0], m[2, 1], filter)
				ELSE
					Scale(src, dst, m[0, 0], m[1, 1], m[2, 0], m[2, 1], filter)
				END
			ELSE
				det := m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0];
				IF ABS(det) >= eps THEN
					IF (ABS(det-1) < eps) & (ABS(m[0, 0] - m[1, 1]) < eps) & (ABS(m[0, 1] + m[1, 0]) < eps) THEN
						Rotate(src, dst, m[0, 1], m[0, 0], m[2, 0], m[2, 1], filter)
					ELSIF ABS(m[0, 1]) < eps THEN	(* horizontal shear *)
						iy := ENTIER(m[2, 1]);
						IF ABS(det-1) >= eps THEN	(* scaled *)
							w := ENTIER(m[0, 0] * src.width)+1;
							h := ENTIER(m[1, 1] * src.height)+1;
							GetTempImage(tmp, Cache, w, h);
							Scale(src, tmp, m[0, 0], m[1, 1], 0, m[2, 1] - iy, filter);
							SkewRows(tmp, dst, 0, 0, tmp.width, tmp.height, iy, m[2, 0], m[1, 0]/m[1, 1], filter);
							FreeTempImage(tmp, Cache)
						ELSIF m[2, 1] - iy < eps THEN	(* integer translation *)
							SkewRows(src, dst, 0, 0, src.width, src.height, iy, m[2, 0], m[1, 0], filter)
						ELSE
							GetTempImage(tmp, Cache, src.width, src.height+1);
							Translate(src, tmp, 0, m[2, 1] - iy, filter);
							SkewRows(tmp, dst, 0, 0, tmp.width, tmp.height, iy, m[2, 0], m[1, 0], filter);
							FreeTempImage(tmp, Cache)
						END
					ELSIF ABS(m[1, 0]) < eps THEN	(* vertical shear *)
						ix := ENTIER(m[2, 0]);
						IF ABS(det-1) >= eps THEN	(* scaled *)
							w := ENTIER(m[0, 0] * src.width)+1;
							h := ENTIER(m[1, 1] * src.height)+1;
							GetTempImage(tmp, Cache, w, h);
							Scale(src, tmp, m[0, 0], m[1, 1], m[2, 0] - ix, 0, filter);
							SkewCols(tmp, dst, 0, 0, tmp.width, tmp.height, ix, m[2, 1], m[0, 1]/m[0, 0], filter);
							FreeTempImage(tmp, Cache)
						ELSIF m[2, 0] - ix < eps THEN	(* integer translation *)
							SkewCols(src, dst, 0, 0, src.width, src.height, ix, m[2, 1], m[0, 1], filter)
						ELSE
							GetTempImage(tmp, Cache, src.width+1, src.height);
							Translate(src, tmp, m[2, 0] - ix, 0, filter);
							SkewRows(tmp, dst, 0, 0, tmp.width, tmp.height, ix, m[2, 1], m[0, 1], filter);
							FreeTempImage(tmp, Cache)
						END
					ELSE
						(*
							use the following identity:
								[ a b ]	[ a         0       ] [        1           0 ] [ 1 b/a ]
								[ c d ] = [ 0 (ad-bc)/a ] [ ca/(ad-bc) 1 ]  [ 0   1   ]
						*)
						s := det/m[0, 0];
						w := ENTIER(m[0, 0] * src.width)+1;
						h := ENTIER(s * src.height)+1;
						dx := m[1, 0]/s; x := (h-1) * ABS(dx) + 2;
						GetTempImage(tmp, Cache, w - 2*ENTIER(-x) + 1, 2*h);
						Scale(src, tmp, m[0, 0], s, x, h, filter);
						ix := ENTIER(m[2, 0]);
						SkewRows(tmp, tmp, 0, h, tmp.width, h, 0, m[2, 0] - ix, dx, filter);
						w := ENTIER(x);
						IF dx >= 0 THEN
							SkewCols(tmp, dst, w, 0, tmp.width - w, h, ix, m[2, 1], m[0, 1]/m[0, 0], filter)
						ELSE
							s := m[0, 1]/m[0, 0];
							SkewCols(tmp, dst, 0, 0, tmp.width - w, h, ix - w, m[2, 1] - w * s, s, filter)
						END;
						FreeTempImage(tmp, Cache)
					END
				END
			END
		END
	END Transform;

	(** uses nearest-neighbor resampling (box filter); bad aliasing when downscaling **)
	PROCEDURE InitNoFilter*(VAR filter: Filter);
	BEGIN
		InitFilter(filter, Raster.srcOverDst, HShift, VShift, HScale, VScale)
	END InitNoFilter;

	(** uses linear interpolation (triangle filter); blurry when upscaling **)
	PROCEDURE InitLinearFilter*(VAR filter: Filter);
	BEGIN
		InitFilter(filter, Raster.srcOverDst, LinearHShift, LinearVShift, LinearHScale, LinearVScale);
	END InitLinearFilter;

BEGIN
	hshift := HShift; vshift := VShift
END GfxImages.
