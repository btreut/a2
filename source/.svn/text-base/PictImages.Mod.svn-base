(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE PictImages; (** non-portable *)	(* eos  **)
(** AUTHOR "eos"; PURPOSE "Pict image format"; *)

	(**
		Support for images in Oberon Picture format
	**)

	(*
		9.12.1998 - first release (together with GfxMaps)
		23.8.1999 - migrated from GfxPictures
		17.11.1999 - replaced F8 format by D8
		17.11.1999 - always use white/black for pictures with depth=1
		18.11.1999 - bugfix in run_length encoding (buf[0]+1 overflowed for buf[0]=127)
		19.11.1999 - don't dither when storing as picture
		19.06.2000 - Aos version
	*)

	IMPORT
		SYSTEM, Files, Raster;


	CONST
		R = Raster.r; G = Raster.g; B = Raster.b; A = Raster.a;


(*
	VAR
		PrntPat*: ARRAY 9 OF Raster.Image;	(** printer patterns (same as in Printer3) **)
*)

	(**--- Oberon Pictures ---**)

	(* pack/unpack procedures for 1 and 4 bit formats *)

	PROCEDURE PackP1 (VAR fmt: Raster.Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Raster.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF ORD(pix[R]) + ORD(pix[G]) + ORD(pix[B]) >= 3*128 THEN
			IF ~ODD(ASH(ORD(b), -bit)) THEN
				SYSTEM.PUT(adr, CHR(ORD(b) + ASH(1, bit)))
			END
		ELSE
			IF ODD(ASH(ORD(b), -bit)) THEN
				SYSTEM.PUT(adr, CHR(ORD(b) - ASH(1, bit)))
			END
		END
	END PackP1;

	PROCEDURE UnpackP1 (VAR fmt: Raster.Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Raster.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF ODD(ASH(ORD(b), -bit)) THEN pix[R] := 0X; pix[G] := 0X; pix[B] := 0X; pix[A] := 0FFX
		ELSE pix[R] := 0FFX; pix[G] := 0FFX; pix[B] := 0FFX; pix[A] := 0FFX
		END
	END UnpackP1;

	PROCEDURE PackP4 (VAR fmt: Raster.Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Raster.Pixel);
		VAR b: CHAR; i: LONGINT;
	BEGIN
		SYSTEM.GET(adr, b);
		i := Raster.PaletteIndex(fmt.pal, ORD(pix[R]), ORD(pix[G]), ORD(pix[B])) MOD 10H;
		IF bit = 0 THEN SYSTEM.PUT(adr, CHR(ORD(b) - ORD(b) MOD 10H + i))
		ELSE SYSTEM.PUT(adr, CHR(ORD(b) MOD 10H + 10H*i))
		END
	END PackP4;

	PROCEDURE UnpackP4 (VAR fmt: Raster.Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Raster.Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b); pix := fmt.pal.col[ASH(ORD(b), -bit) MOD 10H]
	END UnpackP4;

	(* load Oberon picture from file *)
	PROCEDURE LoadPict (img: Raster.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		VAR
			file: Files.File; r: Files.Reader; id, w, h, depth: INTEGER; gen: ARRAY 64 OF CHAR; i, n: LONGINT;
			adr, a: ADDRESS; pal: Raster.Palette; red, green, blue, byte: CHAR; fmt: Raster.Format;
	BEGIN
		file := Files.Old(fname);
		IF file # NIL THEN
			Files.OpenReader(r, file, 0); r.RawInt(id);
			IF id = 07F7H THEN	(* document *)
				r.RawString(gen); r.SkipBytes(4*2);
				r.RawInt(id)
			END;

			IF id = -4093 THEN	(* Pictures.PictFileId *)
				r.RawInt(w); r.RawInt(h); r.RawInt(depth);

				(* load picture palette *)
				i := 0; n := ASH(1, depth); NEW(pal);
				WHILE i < n DO
					r.Char(red); r.Char(green); r.Char(blue);
					Raster.SetRGB(pal.col[i], ORD(red), ORD(green), ORD(blue));
					INC(i)
				END;
				IF depth = 1 THEN
					Raster.SetRGB(pal.col[0], 255, 255, 255);
					Raster.SetRGB(pal.col[1], 0, 0, 0)
				END;
				Raster.InitPalette(pal, SHORT(n), 2 + depth DIV 4);

				(* initialize image *)
				IF depth = 1 THEN
					Raster.InitFormat(fmt, Raster.custom, 1, 1, {Raster.index}, pal, PackP1, UnpackP1)
				ELSIF depth = 4 THEN
					Raster.InitFormat(fmt, Raster.custom, 4, 1, {Raster.index}, pal, PackP4, UnpackP4)
				ELSE
					Raster.InitPaletteFormat(fmt, pal)
				END;
				Raster.Create(img, w, h, fmt);

				(* load run-length encoded pixels *)
				adr := img.adr + h * img.bpr;
				WHILE h > 0 DO
					a := adr - img.bpr;
					WHILE a < adr DO
						r.Char(byte); n := ORD(byte);
						IF n < 128 THEN
							REPEAT
								r.Char(byte);
								SYSTEM.PUT(a, byte); INC(a);
								DEC(n)
							UNTIL n < 0
						ELSE
							n := 100H - n;
							r.Char(byte);
							REPEAT
								SYSTEM.PUT(a, byte); INC(a);
								DEC(n)
							UNTIL n < 0
						END
					END;
					DEC(h); DEC(adr, img.bpr)
				END;

				done := TRUE
			END
		END
	END LoadPict;

	(* store Oberon picture *)
	PROCEDURE StorePict (img: Raster.Image; VAR fname: ARRAY OF CHAR; VAR done: BOOLEAN);
		TYPE Bytes129 = ARRAY 129 OF CHAR;
		VAR
			file: Files.File; w: Files.Writer; pal: Raster.Palette; i, y, inc, x: LONGINT; fmt: Raster.Format; depth: INTEGER;
			pix: POINTER TO ARRAY OF CHAR; buf: ARRAY 129 OF SHORTINT;
			SrcCopy: Raster.Mode;
	BEGIN
		file := Files.New(fname);
		IF file # NIL THEN
			Raster.InitMode(SrcCopy, Raster.srcCopy);
			Files.OpenWriter(w, file, 0);
			w.RawInt(-4093);	(* Pictures.PictFileId *)
			w.RawInt(SHORT(img.width)); w.RawInt(SHORT(img.height));

			(* find out which format to use *)
			pal := img.fmt.pal;
			IF (img.fmt.components = {Raster.index}) & (pal # NIL) THEN	(* contains index information *)
				IF img.fmt.bpp > 4 THEN
					Raster.InitPaletteFormat(fmt, pal);
					depth := 8
				ELSIF img.fmt.bpp > 1 THEN
					Raster.InitFormat(fmt, Raster.custom, 4, 1, {Raster.index}, pal, PackP4, UnpackP4);
					depth := 4
				ELSE
					Raster.InitFormat(fmt, Raster.custom, 1, 1, {Raster.index}, pal, PackP1, UnpackP1);
					depth := 1
				END
			ELSE	(* calculate palette *)
				NEW(pal);
				Raster.ComputePalette(img, pal, 0, 255, 4);	(* no reserved colors *)
				Raster.InitPaletteFormat(fmt, pal);
				depth := 8
			END;

			(* write palette *)
			w.RawInt(depth);
			i := 0;
			WHILE i < ASH(1, depth) DO
				w.Char(pal.col[i, R]); w.Char(pal.col[i, G]); w.Char(pal.col[i, B]);
				INC(i)
			END;

			(* write run-length encoded pixels *)
			NEW(pix, img.width); y := img.height; inc := 8 DIV depth;
			WHILE y > 0 DO
				DEC(y);
				Raster.GetPixels(img, 0, y, img.width, fmt, pix^, 0, SrcCopy);
				buf[0] := 0; buf[1] := SHORT(ORD(pix[0])); x := inc; i := 1;
				WHILE x < img.width DO
					IF buf[0] < 0 THEN	(* accumulating equal bytes *)
						IF (buf[0] > -128) & (pix[i] = CHR(buf[1])) THEN
							DEC(buf[0])
						ELSE
							w.Bytes(SYSTEM.VAL(Bytes129, buf), 0, 2);
							buf[0] := 0; buf[1] := SHORT(ORD(pix[i]))
						END
					ELSIF buf[0] > 0 THEN	(* accumulating different bytes *)
						IF buf[0] = 127 THEN	(* buffer full *)
							w.Bytes(SYSTEM.VAL(Bytes129, buf), 0, buf[0]+2);
							buf[0] := 0; buf[1] := SHORT(ORD(pix[i]))
						ELSIF pix[i] # pix[i-1] THEN
							INC(buf[0]); buf[LONG(buf[0])+1] := SHORT(ORD(pix[i]))
						ELSE
							DEC(buf[0]);
							w.Bytes(SYSTEM.VAL(Bytes129, buf), 0, buf[0]+2);
							buf[0] := -1; buf[1] := SHORT(ORD(pix[i]))
						END
					ELSIF pix[i] = CHR(buf[1]) THEN	(* starting to accumulate equal bytes *)
						buf[0] := -1
					ELSE	(* starting to accumulate different bytes *)
						buf[0] := 1; buf[2] := SHORT(ORD(pix[i]))
					END;
					INC(x, inc); INC(i)
				END;
				IF buf[0] >= 0 THEN w.Bytes(SYSTEM.VAL(Bytes129, buf), 0, buf[0]+2)
				ELSE w.Bytes(SYSTEM.VAL(Bytes129, buf), 0, 2)
				END
			END;
			w.Update;
			Files.Register(file);
			done := TRUE
		END
	END StorePict;

	(* * install load/store procedures for handling Oberon pictures **)
(*	PROCEDURE Install*;
	BEGIN
		Raster.LoadProc := LoadPict; Raster.StoreProc := StorePict
	END Install;*)

	PROCEDURE AosLoad*(x: ANY) : ANY;
	BEGIN
		IF x IS Raster.PictureTransferParameters THEN WITH x:Raster.PictureTransferParameters DO
			LoadPict(x.img, x.name, x.done);
			Raster.Init(x.img, x.img.width, x.img.height, x.img.fmt, -x.img.bpr, ADDRESSOF(x.img.mem[0]) + (x.img.height-1)*x.img.bpr);
		END END;
		RETURN NIL
	END AosLoad;

	PROCEDURE AosStore*(x: ANY) : ANY;
	BEGIN
		IF x IS Raster.PictureTransferParameters THEN WITH x:Raster.PictureTransferParameters DO
			StorePict(x.img, x.name, x.done)
		END END;
		RETURN NIL
	END AosStore;


(*
	(**--- Oberon Patterns ---**)

	(** create image from Oberon pattern (format=A1) **)
	PROCEDURE PatternToImage* (pat: ADDRESS): Raster.Image;
		VAR w, h: INTEGER; byte: CHAR; img: Raster.Image;
	BEGIN
		ASSERT(pat # 0, 100);
		IF (1 <= pat) & (pat <= 8) THEN RETURN PrntPat[pat] END;
		SYSTEM.GET(pat, byte); w := ORD(byte);
		SYSTEM.GET(pat+1, byte); h := ORD(byte);
		NEW(img); Raster.Init(img, w, h, Raster.A1, (w+7) DIV 8, pat+2);
		RETURN img
	END PatternToImage;

	(** initialize pattern from sets **)
	PROCEDURE NewPattern* (w, h: LONGINT; VAR image: ARRAY OF SET): Raster.Image;
		VAR bpr, y: LONGINT; sa, da: ADDRESS; img: Raster.Image;
	BEGIN
		bpr := (w+7) DIV 8;
		NEW(img); Raster.Create(img, w, h, Raster.A1);
		y := 0; sa := ADDRESSOF(image[0]); da := img.adr;
		WHILE y < h DO
			SYSTEM.MOVE(sa, da, bpr); INC(sa, 4); INC(da, bpr); INC(y)
		END;
		RETURN img
	END NewPattern;

	PROCEDURE InitPatterns;
		VAR pat: ARRAY 8 OF SET; i: LONGINT;
	BEGIN
		(* adapted from Printer3 *)
		pat[0] := {}; pat[1] := {}; pat[2] := {}; pat[3] := {0,4,8,12,16,20,24,28};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[1] := NewPattern(32, 8, pat);
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {}; pat[2] := {2,6,10,14,18,22,26,30}; pat[3] := {};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[2] := NewPattern(32, 8, pat);
		pat[0] := {}; pat[1] := {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30};
		FOR i := 0 TO 5 DO pat[2 + i] := pat[i] END;
		PrntPat[3] := NewPattern(32, 8, pat);
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {2,6,10,14,18,22,26,30};
		FOR i := 0 TO 5 DO pat[2 + i] := pat[i] END;
		PrntPat[4] := NewPattern(32, 8, pat);
		FOR i := 0 TO 7 DO pat[i] := {0..31} END;
		PrntPat[5] := NewPattern(32, 8, pat);
		pat[0] := {0,4,8,12,16,20,24,28}; pat[1] := {1,5,9,13,17,21,25,29};
		pat[2] := {2,6,10,14,18,22,26,30}; pat[3] := {3,7,11,15,19,23,27,31};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[6] := NewPattern(32, 8, pat);
		pat[0] := {3,7,11,15,19,23,27,31}; pat[1] := {2,6,10,14,18,22,26,30};
		pat[2] := {1,5,9,13,17,21,25,29}; pat[3] := {0,4,8,12,16,20,24,28};
		FOR i := 0 TO 3 DO pat[4 + i] := pat[i] END;
		PrntPat[7] := NewPattern(32, 8, pat);
		FOR i := 0 TO 7 DO pat[i] := {0,4,8,12,16,20,24,28} END;
		PrntPat[8] := NewPattern(32, 8, pat)
	END InitPatterns;

BEGIN
	InitPatterns
*)
END PictImages.
