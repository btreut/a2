MODULE Raster; (** non-portable *)	(* eos, TF  **)
(** AUTHOR "eos"; PURPOSE "Raster operations"; *)

	(**
		Raster image bitmaps and basic image processing
	**)


	(*
		19.9.1999 - spawned from GfxMaps
		25.10.1999 - fixed bytes-per-row calculation in Create (need to make arguments LONG)
		17.11.1999 - eliminated F8 format, replaced by D8 (implemented with module Colors)
		19.11.1999 - fixed missing alpha component in computed palettes
		16.05.2000 - module Raster as Oberon-independent part of Images
		19.06.2000 - replaced DisplayFormat and InitDisplay by DisplayFormat()
		25.02.2006 - raster operations with SSE2 added (student project by Myrto Zehnder)
		28.02.2008 - added capabilities for 16-bit palette & grayscale images often used in scientific,medical imaging and professional photography (Patrick Hunziker)

		To do:
		- store in compressed format
		- add capabilities for RGB and multiplane images with >8 bits per color as used in scientific imaging and professional photography
	*)

	IMPORT
		SYSTEM, KernelLog, Machine, Streams, CLUTs, Displays;


	(*
		Interfacing with display hardware and foreign framebuffers may suffer a performance hit if their
		bit or byte ordering can't be made compatible with that of a built-in format and has to be converted
		manually. Predefined format A1 has the leftmost pixel in the least significant bit of a byte, and
		all hi/true color formats have their blue component at the lowest address, followed by green,
		red, and possibly alpha (which conforms to the specification of the transfer formats in Displays).

		As SYSTEM is imported, the module is not portable and has always to be compiled to native code.
		However, it should usually suffice to recompile the module on other platforms without changing
		any code.

		Assumptions:
			* CHR(l) = CHR(l MOD 100H) for all l: LONGINT
			* SIZEOF(LONGINT)=4
	*)


	CONST
		b* = 0; g* = 1; r* = 2; a* = 3;	(** index of blue, green, red, and alpha components in a Pixel **)

		(** format codes **)
		custom* = 0; a1* = 1; a8* = 2; d8* = 3; p8* = 4; bgr555* = 5; bgr565* = 6; bgr466* = 7; bgr888* = 8; bgra8888* = 9; p16* =10;

		(** components **)
		color* = 0; alpha* = 1; index* = 2;

		(** compositing operations (srcCopy = replace, srcOverDst = paint **)
		clear* = 0; srcCopy* = 1; dstCopy* = 2; srcOverDst* = 3; dstOverSrc* = 4; srcInDst* = 5; dstInSrc* = 6;
		srcWithoutDst* = 7; dstWithoutSrc* = 8; srcAtopDst* = 9; dstAtopSrc* = 10; srcXorDst* = 11; InvDst*=12;
		InvOverDst*=13;

		MAXCOL = 10000H; (*current implementation limitation for number of color indexes *)

	TYPE
		(** general pixels with red, green, blue, and alpha information in range 0..255; alpha is pre-multiplied into RGB **)
		Pixel* = ARRAY 4 OF CHAR;

		(** palette structure for indexed formats **)
		Palette* = OBJECT
			VAR
			col*: POINTER TO ARRAY OF Pixel;	(** color table **)
			used*: LONGINT;	(** number of valid entries in color table **)
			clut: CLUTs.CLUT;	(* reverse color lookup structure *)
			PROCEDURE &New*; BEGIN NEW(col,256); used:=256 END New; (*initialized to 256 colors; for backwards compatibility*)
			PROCEDURE Init*(used:LONGINT); BEGIN SELF.used:=used; NEW(col,used) END Init; (*initialize to size # 256*) (*bugfix PH090122*)
		END Palette;

		(** image format **)
		Format0* = RECORD
			code*: SHORTINT;	(** format code for quick format checks **)
			bpp*: SHORTINT;	(** number of bits per pixel **)
			align*: SHORTINT;	(** bytes per row must be multiple of this **)
			components*: SET;	(** components that are stored in a pixel **)
			pal*: Palette;	(** optional palette for indexed formats **)
		END;

		PackProc* = PROCEDURE (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);

		Format* = RECORD (Format0)
			pack*: PackProc;	(** store supported pixel components at given address **)
			unpack*: PackProc;	(** load supported pixel components from given address **)
		END;

		(** raster image **)
		Image* = OBJECT (* POINTER TO ImageDesc;
		ImageDesc* = RECORD *)
		VAR
			width*, height*: LONGINT;	(** image dimensions **)
			fmt*: Format;	(** pixel format **)
			bpr*: LONGINT;	(** number of bytes per row (may be negative) **)
			adr*: ADDRESS;	(** address of lower left pixel **)
			mem*: POINTER TO ARRAY OF CHAR;	(** block where pixels are stored; mem#NIL implies adr=ADR(mem[0]) **)
		END Image;

		(** transfer mode **)
		Mode0* = RECORD
			src*, dst*: Format;	(** source and destination format **)
			op*: LONGINT;	(** compositing operation **)
			col*: Pixel;	(** substitute color used when transfering from pure alpha formats to colored ones **)
			buf: Pixel;	(* constant area for special-case moving *)
			map: POINTER TO ARRAY OF INTEGER;	(* color map for transfer between indexed formats *)
		END;

		TransferProc* = PROCEDURE (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);

		Mode* = RECORD (Mode0)
			transfer*: TransferProc;	(** procedure transfering pixels from source to destination **)
		END;

		PictureTransferParameters* = POINTER TO RECORD
			img* : Image;
			name* : ARRAY 128 OF CHAR;
			done* : BOOLEAN
		END;

	VAR
		A1*, A8*, D8*, BGR555*, BGR565*, BGR466*, BGR888*, BGRA8888*: Format;	(** predefined formats **)
		PixelFormat*: Format;	(** special formats **)

		Clamp*: ARRAY 500H OF CHAR;	(** Clamp[200H+i] = CHR(min(max(i, 0), 0FFH)) **)

		Zero: Pixel;	(* pixel with all components cleared *)
		Bit: ARRAY 100H, 8 OF BOOLEAN;	(* Bit[b, i] means bit i in byte b is set *)
		Set, Clr: ARRAY 100H, 8 OF CHAR;	(* Set/Clr[b, i] is byte b with bit i set/cleared *)

(*		d8display: Displays.Display;	(* only one system-wide D8 display supported *)
		plugin: Plugins.Plugin; *)

		MMXenabled*,SSE2enabled*  : BOOLEAN;

	(**--- Color/Pixel conversions ---**)

	(** set pixel to opaque RGB value **)
	PROCEDURE SetRGB* (VAR pix: Pixel; red, green, blue: LONGINT);
	BEGIN
		pix[b] := CHR(blue); pix[g] := CHR(green); pix[r] := CHR(red); pix[a] := 0FFX
	END SetRGB;

	(** set pixel to partly transparent RGB value **)
	PROCEDURE SetRGBA* (VAR pix: Pixel; red, green, blue, alpha: LONGINT);
	BEGIN
		pix[b] := CHR(blue * alpha DIV 255);
		pix[g] := CHR(green * alpha DIV 255);
		pix[r] := CHR(red * alpha DIV 255);
		pix[a] := CHR(alpha)
	END SetRGBA;

	(** retrieve RGB and alpha values from pixel **)
	PROCEDURE GetRGBA* (pix: Pixel; VAR red, green, blue, alpha: LONGINT);
	BEGIN
		alpha := ORD(pix[a]);
		IF alpha = 0 THEN	(* color has disappeared *)
			red := 255; green := 255; blue := 255
		ELSE
			red := ORD(pix[r]); green := ORD(pix[g]); blue := ORD(pix[b]);
			IF alpha # 255 THEN	(* un-multiply alpha *)
				red := 255 * red DIV alpha; IF red > 255 THEN red := 255 END;
				green := 255 * green DIV alpha; IF green > 255 THEN green := 255 END;
				blue := 255 * blue DIV alpha; IF blue > 255 THEN blue := 255 END
			END
		END
	END GetRGBA;


	(**--- Palettes ---**)

	(** return index of color in palette which approximates the requested color reasonably well **)
	PROCEDURE PaletteIndex* (pal: Palette; red, green, blue: LONGINT): LONGINT;
	BEGIN
		IF pal.used>256 THEN
			RETURN CLUTs.Match(pal.clut, ASH(red, 16) + ASH(green, 8) +  blue) *pal.used DIV 256 (*PH090122*)
		ELSE RETURN CLUTs.Match(pal.clut, ASH(red, 16) + ASH(green, 8) +  blue)
		END;
	END PaletteIndex;

	(** compute internal palette structures whenever palette colors have been modified **)
	PROCEDURE InitPalette* (pal: Palette; used, bits: LONGINT);
		VAR n, red, green, blue, alpha: LONGINT;
	BEGIN
		n := 0;
		IF used>pal.used THEN NEW(pal.col,used);END;
		pal.used:=used;
		WHILE n < used DO
			GetRGBA(pal.col[n], red, green, blue, alpha);
			CLUTs.Set(pal.clut, (*n*) n*255 DIV used, ASH(red, 16) + ASH(green, 8) + blue);
			INC(n)
		END;
		CLUTs.Init(pal.clut, MIN (used,256), bits);
	END InitPalette;

	(** (re)compute grayscale palette, typically used for pictures with >256 gray scale values**)
	PROCEDURE InitGrayPalette* (pal: Palette; used, bits: LONGINT);
		VAR n, gray: LONGINT;
	BEGIN
		n := 0;
		IF used>pal.used THEN NEW(pal.col,used); END;
		pal.used := used;
		WHILE n < used DO
			gray:= n*255 DIV used;
			SetRGBA(pal.col[n],gray,gray,gray,255); (*PH 090122*)
			CLUTs.Set(pal.clut, gray, ASH(gray, 16) + ASH(gray, 8) + gray);
			INC(n)
		END;
		CLUTs.Init(pal.clut, MIN(used,256), bits);
	END InitGrayPalette;

	(** copy palette contents **)
	PROCEDURE CopyPalette* (from, to: Palette);
		VAR n: LONGINT;
	BEGIN
		n := 0;
		IF to.used<from.used THEN NEW(to.col,from.used) END;
		to.used:=from.used;
		WHILE n < from.used DO
			to.col[n] := from.col[n]; INC(n)
		END;
		CLUTs.Copy(from.clut, to.clut)
	END CopyPalette;

	(** compute and initialize a pseudo-optimal palette for an image (in hi-color or true-color format) **)
	PROCEDURE ComputePalette* (img: Image; pal: Palette; reservedcols, maxcols, bits: LONGINT);
		(*
			uses octree-quantization
		*)

		TYPE
			Node = POINTER TO RECORD	(* octree node *)
				dsc: ARRAY 8 OF Node;	(* descendants *)
				link: Node;	(* next reducible node on same level *)
				leaf: BOOLEAN;
				weight: LONGINT;	(* accumulated number of pixels represented by this node *)
				r, g, b: LONGINT;	(* accumulated color values *)
			END;

		VAR
			sent, root: Node; reducible: ARRAY 8 OF Node; colors, maxDepth, y, x, bb, used: LONGINT; adr, aa: ADDRESS; pix: Pixel;

		PROCEDURE insert (VAR node: Node; depth: LONGINT; pix: Pixel);
			VAR idx, bit: LONGINT;
		BEGIN
			IF node = NIL THEN
				NEW(node);
				IF depth = maxDepth THEN
					node.leaf := TRUE;
					INC(colors)
				ELSE
					node.leaf := FALSE;
					node.link := reducible[depth]; reducible[depth] := node
				END
			END;
			INC(node.weight);	(* node represents more pixels *)
			IF node.leaf THEN
				INC(node.r, LONG(ORD(pix[r])));
				INC(node.g, LONG(ORD(pix[g])));
				INC(node.b, LONG(ORD(pix[b])))
			ELSE
				idx := 0; bit := 7-depth;
				IF ODD(ASH(ORD(pix[r]), -bit)) THEN INC(idx, 4) END;
				IF ODD(ASH(ORD(pix[g]), -bit)) THEN INC(idx, 2) END;
				IF ODD(ASH(ORD(pix[b]), -bit)) THEN INC(idx) END;
				insert(node.dsc[idx], depth+1, pix)
			END
		END insert;

		PROCEDURE reduce;
			VAR d, min, n, i: LONGINT; node, prev, dsc: Node;
		BEGIN
			d := maxDepth-1;
			WHILE reducible[d] = NIL DO
				DEC(d); DEC(maxDepth)
			END;
			sent.link := reducible[d];
			node := sent; min := MAX(LONGINT);
			WHILE node.link # NIL DO
				IF node.link.weight < min THEN
					min := node.link.weight; prev := node
				END;
				node := node.link
			END;
			node := prev.link; prev.link := node.link;
			reducible[d] := sent.link;
			n := 1;	(* number of colors is initially one for the node itself *)
			FOR i := 0 TO 7 DO
				dsc := node.dsc[i];
				IF dsc # NIL THEN
					DEC(n);	(* reducing one color *)
					INC(node.r, dsc.r); INC(node.g, dsc.g); INC(node.b, dsc.b);
					node.dsc[i] := NIL
				END
			END;
			node.leaf := TRUE;
			INC(colors, n)
		END reduce;

		PROCEDURE traverse (node: Node);
			VAR i: LONGINT;
		BEGIN
			IF node # NIL THEN
				IF node.leaf THEN
					pal.col[used, r] := CHR(node.r DIV node.weight);
					pal.col[used, g] := CHR(node.g DIV node.weight);
					pal.col[used, b] := CHR(node.b DIV node.weight);
					pal.col[used, a] := 0FFX;
					INC(used)
				ELSE
					FOR i := 0 TO 7 DO
						traverse(node.dsc[i])
					END
				END
			END
		END traverse;

	BEGIN	(* ComputePalette *)
		ASSERT(reservedcols + maxcols <= MAXCOL, 100);
		NEW(sent);
		root := NIL; colors := 0; maxDepth := 8;
		y := 0; adr := img.adr;
		WHILE y < img.height DO
			IF img.fmt.bpp < 8 THEN
				x := 0; aa := adr; bb := 0;
				WHILE x < img.width DO
					img.fmt.unpack(img.fmt, aa, bb, pix);
					insert(root, 0, pix);
					WHILE colors > maxcols DO
						reduce()
					END;
					INC(x); bb := bb + img.fmt.bpp; INC(aa, bb DIV 8); bb := bb MOD 8
				END
			ELSE
				x := 0; aa := adr; bb := img.fmt.bpp DIV 8;
				WHILE x < img.width DO
					img.fmt.unpack(img.fmt, aa, 0, pix);
					insert(root, 0, pix);
					WHILE colors > maxcols DO
						reduce()
					END;
					INC(x); INC(aa, bb)
				END
			END;
			INC(y); INC(adr, img.bpr)
		END;
		used := reservedcols;
		traverse(root);
		InitPalette(pal, used, bits)
	END ComputePalette;


	(**--- Formats ---**)

	(* A1 - one bit alpha, MSB leftmost *)
	PROCEDURE PackA1 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF pix[a] >= 80X THEN SYSTEM.PUT(adr, Set[ORD(b), bit])
		ELSE SYSTEM.PUT(adr, Clr[ORD(b), bit])
		END
	END PackA1;

	PROCEDURE UnpackA1 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR b: CHAR;
	BEGIN
		SYSTEM.GET(adr, b);
		IF Bit[ORD(b), bit] THEN pix[a] := 0FFX
		ELSE pix := Zero
		END
	END UnpackA1;

	(* A8 - 8 bit alpha *)
	PROCEDURE PackA8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		SYSTEM.PUT(adr, pix[a])
	END PackA8;

	PROCEDURE UnpackA8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR alpha: LONGINT;
	BEGIN
		SYSTEM.GET(adr, pix[a]);
		IF pix[a] = 0X THEN
			pix := Zero
		ELSIF pix[a] # 0FFX THEN
			alpha := ORD(pix[a]);
			pix[r] := CHR(ORD(pix[r]) * alpha DIV 255);
			pix[g] := CHR(ORD(pix[g]) * alpha DIV 255);
			pix[b] := CHR(ORD(pix[b]) * alpha DIV 255)
		END
	END UnpackA8;

	(* P8 - 8 bit indexed format with custom palette *)
	PROCEDURE PackP8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			SYSTEM.PUT(adr, CHR(CLUTs.Match(fmt.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))))
		END
	END PackP8;

	PROCEDURE UnpackP8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR idx: CHAR;
	BEGIN
		SYSTEM.GET(adr, idx); pix := fmt.pal.col[ORD(idx)]
	END UnpackP8;

	(* D8 - 8 bit indexed format with display palette *)
	PROCEDURE PackD8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			SYSTEM.PUT(adr, CHR(ColorToIndex(ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))))
		END
	END PackD8;

	PROCEDURE UnpackD8 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR idx: CHAR; col: LONGINT;
	BEGIN
		SYSTEM.GET(adr, idx); col := IndexToColor(ORD(idx));
		pix[b] := CHR(col MOD 100H); pix[g] := CHR(ASH(col, -8) MOD 100H); pix[r] := CHR(ASH(col, -16) MOD 100H)
	END UnpackD8;

		(* P16 - 16 bit indexed format with custom palette *)
	PROCEDURE PackP16 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	VAR val:LONGINT;
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			(*SYSTEM.PUT16(adr, PaletteIndex(fmt.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b])))*)
			val:=CLUTs.Match(fmt.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]),16));
			IF fmt.pal.used>256 THEN val:=val*fmt.pal.used DIV 256 END;
			SYSTEM.PUT16(adr, SHORT(val))
		END
	END PackP16;

	PROCEDURE UnpackP16 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		pix := fmt.pal.col[SYSTEM.GET16(adr) MOD 1000H] 	(*unsigned 16 bit entity*)
	END UnpackP16;


	(* BGR555 - 16 hi-color with 5 bit blue, 5 bit green and 5 bit red in ascending order *)
	PROCEDURE PackBGR555 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR int: LONGINT;
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			int := ASH(ORD(pix[b]), -3) + ASH(ASH(ORD(pix[g]), -3), 5) + ASH(ASH(ORD(pix[r]), -3), 10);
			SYSTEM.PUT(adr, CHR(int)); SYSTEM.PUT(adr+1, CHR(ASH(int, -8)))
		END
	END PackBGR555;

	PROCEDURE UnpackBGR555 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR lo, hi: CHAR; int: LONGINT;
	BEGIN
		SYSTEM.GET(adr, lo); SYSTEM.GET(adr+1, hi); int := ASH(ORD(hi), 8) + ORD(lo);
		pix[b] := CHR(ASH(int MOD 20H, 3) + 4);
		pix[g] := CHR(ASH(ASH(int, -5) MOD 20H, 3) + 4);
		pix[r] := CHR(ASH(ASH(int, -10) MOD 20H, 3) + 4);
		pix[a] := 0FFX
	END UnpackBGR555;

	(* BGR565 - 16 hi-color with 5 bit blue, 6 bit green and 5 bit red in ascending order *)
	PROCEDURE PackBGR565 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR int: LONGINT;
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			int := ASH(ORD(pix[b]), -3) + ASH(ASH(ORD(pix[g]), -2), 5) + ASH(ASH(ORD(pix[r]), -3), 11);
			SYSTEM.PUT(adr, CHR(int)); SYSTEM.PUT(adr+1, CHR(ASH(int, -8)))
		END
	END PackBGR565;

	PROCEDURE UnpackBGR565 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR lo, hi: CHAR; int: LONGINT;
	BEGIN
		SYSTEM.GET(adr, lo); SYSTEM.GET(adr+1, hi); int := ASH(ORD(hi), 8) + ORD(lo);
		pix[b] := CHR(ASH(int MOD 20H, 3) + 4);
		pix[g] := CHR(ASH(ASH(int, -5) MOD 40H, 2) + 2);
		pix[r] := CHR(ASH(ASH(int, -11) MOD 20H, 3) + 4);
		pix[a] := 0FFX
	END UnpackBGR565;

	(* BGR466 - 16 hi-color with 4 bit blue, 6 bit green and 6 bit red in ascending order *)
	PROCEDURE PackBGR466 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR int: LONGINT;
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			int := ASH(ORD(pix[b]), -4) + ASH(ASH(ORD(pix[g]), -2), 4) + ASH(ASH(ORD(pix[r]), -2), 10);
			SYSTEM.PUT(adr, CHR(int)); SYSTEM.PUT(adr+1, CHR(ASH(int, -8)))
		END
	END PackBGR466;

	PROCEDURE UnpackBGR466 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
		VAR lo, hi: CHAR; int: LONGINT;
	BEGIN
		SYSTEM.GET(adr, lo); SYSTEM.GET(adr+1, hi); int := ASH(ORD(hi), 8) + ORD(lo);
		pix[b] := CHR(ASH(int MOD 10H, 4) + 8);
		pix[g] := CHR(ASH(ASH(int, -4) MOD 40H, 2) + 2);
		pix[r] := CHR(ASH(ASH(int, -10) MOD 40H, 2) + 2);
		pix[a] := 0FFX
	END UnpackBGR466;

	(* BGR888 - 24 bit true color with blue in lower, green in middle, and red in upper byte *)
	PROCEDURE PackBGR888 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		IF pix[a] # 0X THEN	(* model alpha as brightness *)
			SYSTEM.MOVE(ADDRESSOF(pix[0]), adr, 3)
		END
	END PackBGR888;

	PROCEDURE UnpackBGR888 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		SYSTEM.MOVE(adr, ADDRESSOF(pix[0]), 3); pix[a] := 0FFX
	END UnpackBGR888;

	(* BGRA8888 - 32 bit true color with blue in lowest, green in lower middle, red in upper middle, and alpha in top byte *)
	PROCEDURE PackBGRA8888 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		SYSTEM.MOVE(ADDRESSOF(pix[0]), adr, 4)
	END PackBGRA8888;

	PROCEDURE UnpackBGRA8888 (VAR fmt: Format0; adr: ADDRESS; bit: LONGINT; VAR pix: Pixel);
	BEGIN
		SYSTEM.MOVE(adr, ADDRESSOF(pix[0]), 4)
	END UnpackBGRA8888;

	(** return image format for given Displays transfer format **)
	PROCEDURE DisplayFormat* (format: LONGINT): Format;
	BEGIN
		CASE format OF
		| Displays.index8: RETURN D8
		| Displays.color565: RETURN BGR565
		| Displays.color888: RETURN BGR888
		| Displays.color8888: RETURN BGRA8888
		END
	END DisplayFormat;

	(** initialize format **)
	PROCEDURE InitFormat* (VAR fmt: Format; code, bpp, align: SHORTINT; comps: SET; pal: Palette; pack, unpack: PackProc);
	BEGIN
		fmt.code := code; fmt.bpp := bpp; fmt.align := align; fmt.components := comps; fmt.pal := pal;
		fmt.pack := pack; fmt.unpack := unpack
	END InitFormat;

	(** initialize 8 bit index format with custom palette **)
	PROCEDURE InitPaletteFormat* (VAR fmt: Format; pal: Palette);
	BEGIN
		(*fmt.code := p8; fmt.bpp := 8; fmt.align := 1; fmt.components := {index}; fmt.pal := pal;
		fmt.pack := PackP8; fmt.unpack := UnpackP8*)
		fmt.components := {index}; fmt.pal := pal;
		IF pal.used<=256 THEN
			fmt.align := 1;
			fmt.code := p8; fmt.bpp := 8;
			fmt.pack := PackP8; fmt.unpack := UnpackP8
		ELSIF pal.used <= 10000H THEN
			fmt.align := 2;
			fmt.code := p16; fmt.bpp := 16;
			fmt.pack := PackP16; fmt.unpack := UnpackP16
		ELSE HALT(199)
		END
	END InitPaletteFormat;

	(** return if two formats are the same **)
	PROCEDURE Same* (VAR fmt0, fmt1: Format): BOOLEAN;
	BEGIN
		RETURN
			(fmt0.pack = fmt1.pack) & (fmt0.unpack = fmt1.unpack) &
			(~(index IN fmt0.components) OR (fmt0.pal = fmt1.pal))	(* doesn't work if palette has been re-initialized *)
	END Same;


	(**--- Images ---**)

	(** initialize custom image **)
	PROCEDURE Init* (img: Image; width, height: LONGINT; VAR fmt: Format; bpr: LONGINT; adr: ADDRESS);
	BEGIN
		ASSERT((width > 0) & (height > 0), 100);
		img.width := width; img.height := height; img.fmt := fmt; img.bpr := bpr; img.adr := adr
	END Init;

	(** initialize custom image on byte buffer **)
	PROCEDURE InitBuf* (img: Image; width, height: LONGINT; VAR fmt: Format; bpr, offset: LONGINT; VAR buf: ARRAY OF CHAR);
	BEGIN
		ASSERT((0 <= offset) & (offset + height * ABS(bpr) <= LEN(buf)), 100);
		IF bpr >= 0 THEN Init(img, width, height, fmt, bpr, ADDRESSOF(buf[0]))
		ELSE Init(img, width, height, fmt, bpr, ADDRESSOF(buf[offset]) + LEN(buf) - bpr)
		END
	END InitBuf;

	(** initialize image on rectangular area within existing image (lower left corner must fall on byte boundary) **)
	PROCEDURE InitRect* (img, base: Image; x, y, w, h: LONGINT);
	BEGIN
		ASSERT((0 <= x) & (x + w <= base.width) & (0 <= y) & (y + h <= base.height), 100);
		ASSERT(x * base.fmt.bpp MOD 8 = 0, 101);
		Init(img, w, h, base.fmt, base.bpr, base.adr + y * base.bpr + x * base.fmt.bpp DIV 8)
	END InitRect;

	(** create image in requested format (allocating or reusing necessary memory) **)
	PROCEDURE Create* (img: Image; width, height: LONGINT; fmt: Format);
		VAR size: LONGINT; a0, a1: ADDRESS;
	BEGIN
		ASSERT((width > 0) & (height > 0), 100);
		img.width := width; img.height := height;
		img.fmt := fmt;
		img.bpr := (width * fmt.bpp + 7) DIV 8;
		IF fmt.align > 1 THEN
			img.bpr := (img.bpr + fmt.align - 1) DIV fmt.align * fmt.align
		END;
		size := height * img.bpr; INC(size, (-size) MOD 4);
		IF (img.mem = NIL) OR (size < LEN(img.mem^) DIV 2) OR (LEN(img.mem^) < size) THEN
			NEW(img.mem, size)
		ELSE
			a0 := ADDRESSOF(img.mem[0]); a1 := a0 + size;
			WHILE a0 # a1 DO
				SYSTEM.PUT32(a0,0); INC(a0, SIZEOF(LONGINT))
			END
		END;
		img.adr := ADDRESSOF(img.mem[0])
	END Create;


	(**--- Transfer Modes ---**)

	(** initialize transfer mode **)
	PROCEDURE InitMode* (VAR mode: Mode; op: SHORTINT);
	BEGIN
		mode.op := op;
		IF (mode.src.pal # NIL) & ((mode.map = NIL) OR (LEN(mode.map^) # mode.src.pal.used)) THEN
			NEW(mode.map, mode.src.pal.used)
		END;
		(*SetRGB(mode.col, 255, 255, 255);*)
		mode.col := SYSTEM.VAL(Pixel, -1);
		mode.src.pack := NIL; mode.dst.pack := NIL	(* force re-evaluation of transfer procedure *)
	END InitMode;

	(** initialize transfer mode with color components for pure alpha sources **)
	PROCEDURE InitModeColor* (VAR mode: Mode; op: SHORTINT; red, green, blue: LONGINT);
	BEGIN
		mode.op := op;
		IF (mode.src.pal # NIL) & ((mode.map = NIL) OR (LEN(mode.map^) # mode.src.pal.used)) THEN
			NEW(mode.map, mode.src.pal.used)
		END;
		SetRGB(mode.col, red, green, blue);
		mode.src.pack := NIL; mode.dst.pack := NIL
	END InitModeColor;

	(** set new source color for transfer mode **)
	PROCEDURE SetModeColor* (VAR mode: Mode; red, green, blue: LONGINT);
	BEGIN
		SetRGB(mode.col, red, green, blue);
		IF (mode.src.pal # NIL) & ((mode.map = NIL) OR (LEN(mode.map^) # mode.src.pal.used)) THEN
			NEW(mode.map, mode.src.pal.used)
		END;
		mode.src.pack := NIL; mode.dst.pack := NIL
	END SetModeColor;

	(** blend source pixel into destination pixel according to compositing operation **)
	PROCEDURE Blend* (op: LONGINT; VAR src, dst: Pixel);
		VAR fs, fd, i: LONGINT;
	BEGIN
		CASE op OF
		| clear: fs := 0; fd := 0
		| srcCopy: fs := 255; fd := 0
		| dstCopy: fs := 0; fd := 255
		| srcOverDst: fs := 255; fd := 255-ORD(src[a])
		| dstOverSrc: fs := 255-ORD(dst[a]); fd := 255
		| srcInDst: fs := ORD(dst[a]); fd := 0
		| dstInSrc: fs := 0; fd := ORD(src[a])
		| srcWithoutDst: fs := 255-ORD(dst[a]); fd := 0
		| dstWithoutSrc: fs := 0; fd := 255-ORD(src[a])
		| srcAtopDst: fs := ORD(dst[a]); fd := 255-ORD(src[a])
		| dstAtopSrc: fs := 255-ORD(dst[a]); fd := ORD(src[a])
		| srcXorDst: fs := 255-ORD(dst[a]); fd := 255-ORD(src[a])
		END;

		IF fs + fd = 0 THEN
			FOR i := 0 TO 3 DO dst[i] := 0X END
		ELSIF fs = 0 THEN
			IF fd # 255 THEN
				FOR i := 0 TO 3 DO
					dst[i] := Clamp[200H + fd * ORD(dst[i]) DIV 255]
				END
			END
		ELSIF fd = 0 THEN
			IF fs = 255 THEN
				dst := src
			ELSE
				FOR i := 0 TO 3 DO
					dst[i] := Clamp[200H + fs * ORD(src[i]) DIV 255]
				END
			END
		ELSE
			dst[0] := Clamp[200H + (fs * ORD(src[0]) + fd * ORD(dst[0])) DIV 255];
			dst[1] := Clamp[200H + (fs * ORD(src[1]) + fd * ORD(dst[1])) DIV 255];
			dst[2] := Clamp[200H + (fs * ORD(src[2]) + fd * ORD(dst[2])) DIV 255];
			dst[3] := Clamp[200H + (fs * ORD(src[3]) + fd * ORD(dst[3])) DIV 255]
		END
	END Blend;


	(*--- General Transfer ---*)

	PROCEDURE AnyBlendAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR spix, dpix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, spix);
			mode.dst.unpack(mode.dst, dadr, dbit, dpix);
			Blend(mode.op, spix, dpix);
			mode.dst.pack(mode.dst, dadr, dbit, dpix);
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len)
		END
	END AnyBlendAny;


	(* --- invert --- *)

	PROCEDURE InvAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			mode.dst.unpack(mode.dst, dadr, dbit, mode.buf);
			mode.buf[r]:=CHR(255-ORD(mode.buf[r]));
			mode.buf[g]:=CHR(255-ORD(mode.buf[g]));
			mode.buf[b]:=CHR(255-ORD(mode.buf[b]));
			mode.dst.pack(mode.dst, dadr, dbit, mode.buf);
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len)
		END
	END InvAny;

	(* --- alpha invert --- *)

	PROCEDURE InvOverAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	VAR pix:Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, pix);
			IF pix[a]>=80X THEN
				mode.dst.unpack(mode.dst, dadr, dbit, mode.buf);
				mode.buf[r]:=CHR(255-ORD(mode.buf[r]));
				mode.buf[g]:=CHR(255-ORD(mode.buf[g]));
				mode.buf[b]:=CHR(255-ORD(mode.buf[b]));
				mode.dst.pack(mode.dst, dadr, dbit, mode.buf)
			END;
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len)
		END
	END InvOverAny;

	(*--- clear ---*)

	PROCEDURE ClearAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR inc: LONGINT;
	BEGIN
		IF mode.dst.bpp MOD 8 = 0 THEN
			inc := mode.dst.bpp DIV 8;
			WHILE len > 0 DO
				mode.dst.pack(mode.dst, dadr, 0, Zero);
				INC(dadr, inc); DEC(len)
			END
		ELSE
			WHILE len > 0 DO
				mode.dst.pack(mode.dst, dadr, dbit, Zero);
				dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
				DEC(len)
			END
		END
	END ClearAny;

	PROCEDURE Clear1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out: CHAR;
	BEGIN
		IF (dbit > 0) OR (len < 8) THEN
			SYSTEM.GET(dadr, out);
			WHILE (dbit < 8) & (len > 0) DO
				out := Clr[ORD(out), dbit];
				INC(dbit); DEC(len)
			END;
			SYSTEM.PUT(dadr, out)
		END;
		WHILE len >= 32 DO
			SYSTEM.PUT(dadr, LONG(LONG(0))); INC(dadr, 4); DEC(len, 32)
		END;
		WHILE len >= 8 DO
			SYSTEM.PUT(dadr, 0X); INC(dadr); DEC(len, 8)
		END;
		IF len > 0 THEN
			SYSTEM.GET(dadr, out); dbit := 0;
			REPEAT
				out := Clr[ORD(out), dbit];
				INC(dbit); DEC(len)
			UNTIL len = 0;
			SYSTEM.PUT(dadr, out)
		END
	END Clear1;

	PROCEDURE ClearBytes (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		len := len * mode.dst.bpp DIV 8;
		WHILE len >= 4 DO
			SYSTEM.PUT(dadr, LONG(LONG(0))); INC(dadr, 4); DEC(len)
		END;
		WHILE len > 0 DO
			SYSTEM.PUT(dadr, 0X); INC(dadr); DEC(len)
		END
	END ClearBytes;


	(*--- srcCopy Transfer ---*)

	(* constant values *)
	PROCEDURE Set1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out: CHAR;
	BEGIN
		IF (dbit > 0) OR (len < 8) THEN
			SYSTEM.GET(dadr, out);
			WHILE (dbit < 8) & (len > 0) DO
				out := Set[ORD(out), dbit];
				INC(dbit); DEC(len)
			END;
			SYSTEM.PUT(dadr, out)
		END;
		WHILE len >= 8 DO
			SYSTEM.PUT(dadr, 0FFX);
			INC(dadr); DEC(len, 8)
		END;
		IF len > 0 THEN
			SYSTEM.GET(dadr, out); dbit := 0;
			REPEAT
				out := Set[ORD(out), dbit];
				INC(dbit); DEC(len)
			UNTIL len = 0;
			SYSTEM.PUT(dadr, out)
		END
	END Set1;

	PROCEDURE ConstCopy8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.PUT(dadr, mode.buf[0]); INC(dadr); DEC(len)
		END
	END ConstCopy8;

	PROCEDURE ConstCopy16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(ADDRESSOF(mode.buf[0]), dadr, 2); INC(dadr, 2); DEC(len)
		END
	END ConstCopy16;

	PROCEDURE ConstCopy24 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(ADDRESSOF(mode.buf[0]), dadr, 3); INC(dadr, 3); DEC(len)
		END
	END ConstCopy24;


	(* identical formats *)
	PROCEDURE Copy1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE (sbit = 0) & (dbit = 0) & (len >= 8) DO
			SYSTEM.PUT(dadr, in);
			INC(sadr); INC(dadr); DEC(len, 8);
			SYSTEM.GET(sadr, in)
		END;
		IF (dbit > 0) OR (len < 8) THEN
			SYSTEM.GET(dadr, out)
		END;
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN out := Set[ORD(out), dbit]
			ELSE out := Clr[ORD(out), dbit]
			END;
			INC(sbit); INC(dbit); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END;
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				IF len < 8 THEN
					SYSTEM.GET(dadr, out)
				END
			END
		END;
		IF dbit > 0 THEN
			SYSTEM.PUT(dadr, out)
		END
	END Copy1;

	PROCEDURE Copy8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		SYSTEM.MOVE(sadr, dadr, len)
	END Copy8;

	PROCEDURE I8CopyI8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR byte: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte); SYSTEM.PUT(dadr, mode.map[ORD(byte)]);
			INC(sadr); INC(dadr); DEC(len)
		END
	END I8CopyI8;

	PROCEDURE Copy16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		SYSTEM.MOVE(sadr, dadr, 2*len)
	END Copy16;

	PROCEDURE I16CopyI16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR val: INTEGER;
	BEGIN
		WHILE len > 0 DO
			val:=SYSTEM.GET16(sadr); SYSTEM.PUT16(dadr, mode.map[val MOD 10000H]);
			INC(sadr); INC(dadr); DEC(len)
		END
	END I16CopyI16;


	PROCEDURE Copy24 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		SYSTEM.MOVE(sadr, dadr, 3*len)
	END Copy24;

	PROCEDURE Copy32 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		SYSTEM.MOVE(sadr, dadr, 4*len)
	END Copy32;


	(* general methods *)
	PROCEDURE AnyCopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, mode.buf);
			mode.dst.pack(mode.dst, dadr, dbit, mode.buf);
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8;
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8;
			DEC(len)
		END
	END AnyCopyAny;

	PROCEDURE AnyBytesCopyAnyBytes (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR sinc, dinc: LONGINT; pix: Pixel;
	BEGIN
		sinc := mode.src.bpp DIV 8; dinc := mode.dst.bpp DIV 8;
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, mode.buf);
			mode.dst.pack(mode.dst, dadr, dbit, mode.buf);
			INC(sadr, sinc); INC(dadr, dinc); DEC(len)
		END
	END AnyBytesCopyAnyBytes;


	(* A1 *)
	PROCEDURE AnyCopyA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out: CHAR; pix: Pixel;
	BEGIN
		SYSTEM.GET(dadr, out); pix[a] := 0FFX;
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, pix);
			sbit := sbit + mode.src.bpp; INC(sadr, sbit MOD 8); sbit := sbit MOD 8;
			IF pix[a] >= 80X THEN out := Set[ORD(out), dbit]
			ELSE out := Clr[ORD(out), dbit]
			END;
			INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out); INC(dadr); SYSTEM.GET(dadr, out); dbit := 0
			END
		END;
		SYSTEM.PUT(dadr, out)
	END AnyCopyA1;

	PROCEDURE A8CopyA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out, in: CHAR;
	BEGIN
		IF (dbit > 0) OR (len < 8) THEN
			SYSTEM.GET(dadr, out)
		END;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, in);
			IF in >= 80X THEN out := Set[ORD(out), dbit]
			ELSE out := Clr[ORD(out), dbit]
			END;
			INC(sadr); INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				IF len < 8 THEN
					SYSTEM.GET(dadr, out)
				END
			END
		END;
		IF dbit > 0 THEN
			SYSTEM.PUT(dadr, out)
		END
	END A8CopyA1;

	PROCEDURE BGRA8888CopyA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out, in: CHAR;
	BEGIN
		INC(sadr, a);	(* only look at alpha component *)
		IF (dbit > 0) OR (len < 8) THEN
			SYSTEM.GET(dadr, out)
		END;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, in);
			IF in >= 80X THEN out := Set[ORD(out), dbit]
			ELSE out := Clr[ORD(out), dbit]
			END;
			INC(sadr, 4); INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				IF len < 8 THEN
					SYSTEM.GET(dadr, out)
				END
			END
		END;
		IF dbit > 0 THEN
			SYSTEM.PUT(dadr, out)
		END
	END BGRA8888CopyA1;

	PROCEDURE A1CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN mode.dst.pack(mode.dst, dadr, dbit, mode.buf)
			ELSE mode.dst.pack(mode.dst, dadr, dbit, Zero)
			END;
			INC(sbit); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1CopyAny;

	PROCEDURE A1CopyA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN SYSTEM.PUT(dadr, 0FFX)
			ELSE SYSTEM.PUT(dadr, 0X)
			END;
			INC(sbit); INC(dadr); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1CopyA8;

	PROCEDURE A1CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel; in: CHAR;
	BEGIN
		pix := mode.buf;
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN pix[a] := 0FFX
			ELSE pix[a] := 0X
			END;
			SYSTEM.MOVE(ADDRESSOF(pix), dadr, 4);
			INC(sbit); INC(dadr, 4); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1CopyBGRA8888;


	(* A8 *)
	PROCEDURE AnyCopyA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.PUT(dadr, pix[a]);
			INC(dadr); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyA8;

	PROCEDURE BGRA8888CopyA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR byte: CHAR;
	BEGIN
		INC(sadr, 3);
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte);
			SYSTEM.PUT(dadr, byte);
			INC(sadr, 4); INC(dadr); DEC(len)
		END
	END BGRA8888CopyA8;

	PROCEDURE A8CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		pix := mode.buf;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, pix[a]);
			SYSTEM.MOVE(ADDRESSOF(pix), dadr, 4);
			INC(sadr); INC(dadr, 4); DEC(len)
		END
	END A8CopyBGRA8888;


	(* P8 *)
	PROCEDURE AnyCopyP8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.PUT(dadr, CHR(CLUTs.Match(mode.dst.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(dadr); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyP8;

	PROCEDURE Any16CopyP8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			SYSTEM.PUT(dadr, CHR(CLUTs.Match(mode.dst.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 2); INC(dadr); DEC(len)
		END
	END Any16CopyP8;

	PROCEDURE BGR888CopyP8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 3);
			SYSTEM.PUT(dadr, CHR(CLUTs.Match(mode.dst.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 3); INC(dadr); DEC(len)
		END
	END BGR888CopyP8;

	PROCEDURE BGRA8888CopyP8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 4);
			SYSTEM.PUT(dadr, CHR(CLUTs.Match(mode.dst.pal.clut, ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 4); INC(dadr); DEC(len)
		END
	END BGRA8888CopyP8;

	PROCEDURE P8CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR b: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, b);
			mode.dst.pack(mode.dst, dadr, dbit, mode.src.pal.col[ORD(b)]);
			INC(sadr); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END P8CopyAny;

	PROCEDURE P8CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR b: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, b);
			mode.dst.pack(mode.dst, dadr, 0, mode.src.pal.col[ORD(b)]);
			INC(sadr); INC(dadr, 2); DEC(len)
		END
	END P8CopyAny16;

	PROCEDURE P8CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR b: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, b);
			SYSTEM.MOVE(ADDRESSOF(mode.src.pal.col[ORD(b)]), dadr, 3);
			INC(sadr); INC(dadr, 3); DEC(len)
		END
	END P8CopyBGR888;

	PROCEDURE P8CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR b: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, b);
			SYSTEM.MOVE(ADDRESSOF(mode.src.pal.col[ORD(b)]), dadr, 4);
			INC(sadr); INC(dadr, 4); DEC(len)
		END
	END P8CopyBGRA8888;


	(* D8 *)
	PROCEDURE AnyCopyD8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.PUT(dadr, CHR(ColorToIndex(ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(dadr); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyD8;

	PROCEDURE Any16CopyD8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			SYSTEM.PUT(dadr, CHR(ColorToIndex(ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 2); INC(dadr); DEC(len)
		END
	END Any16CopyD8;

	PROCEDURE BGR888CopyD8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 3);
			SYSTEM.PUT(dadr, CHR(ColorToIndex(ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 3); INC(dadr); DEC(len)
		END
	END BGR888CopyD8;

	PROCEDURE BGRA8888CopyD8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 4);
			SYSTEM.PUT(dadr, CHR(ColorToIndex(ORD(pix[b]) + ASH(ORD(pix[g]), 8) + ASH(ORD(pix[r]), 16))));
			INC(sadr, 4); INC(dadr); DEC(len)
		END
	END BGRA8888CopyD8;

	PROCEDURE D8CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel; byte: CHAR; col: LONGINT;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte); col := IndexToColor(ORD(byte));
			pix[b] := CHR(col MOD 100H); pix[g] := CHR(ASH(col, -8) MOD 100H); pix[r] := CHR(ASH(col, -16) MOD 100H);
			mode.dst.pack(mode.dst, dadr, dbit, pix);
			INC(sadr); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END D8CopyAny;

	PROCEDURE D8CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel; byte: CHAR; col: LONGINT;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte); col := IndexToColor(ORD(byte));
			pix[b] := CHR(col MOD 100H); pix[g] := CHR(ASH(col, -8) MOD 100H); pix[r] := CHR(ASH(col, -16) MOD 100H);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(sadr); INC(dadr, 2); DEC(len)
		END
	END D8CopyAny16;

	PROCEDURE D8CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR byte: CHAR; col: LONGINT; pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte); col := IndexToColor(ORD(byte));
			pix[b] := CHR(col MOD 100H); pix[g] := CHR(ASH(col, -8) MOD 100H); pix[r] := CHR(ASH(col, -16) MOD 100H);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 3);
			INC(sadr); INC(dadr, 3); DEC(len)
		END
	END D8CopyBGR888;

	PROCEDURE D8CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel; byte: CHAR; col: LONGINT;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			SYSTEM.GET(sadr, byte); col := IndexToColor(ORD(byte));
			pix[b] := CHR(col MOD 100H); pix[g] := CHR(ASH(col, -8) MOD 100H); pix[r] := CHR(ASH(col, -16) MOD 100H);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 4);
			INC(sadr); INC(dadr, 4); DEC(len)
		END
	END D8CopyBGRA8888;

	(*
	(* P816*)
	PROCEDURE AnyCopyP16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.PUT16(dadr, PaletteIndex(mode.dst.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b])));
			INC(dadr,2); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyP16;

	PROCEDURE Any16CopyP16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			SYSTEM.PUT16(dadr, PaletteIndex(mode.dst.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b])));
			INC(sadr, 2); INC(dadr,2); DEC(len)
		END
	END Any16CopyP16;

	PROCEDURE BGR888CopyP16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 3);
			SYSTEM.PUT16(dadr, PaletteIndex(mode.dst.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b])));
			INC(sadr, 3); INC(dadr,2); DEC(len)
		END
	END BGR888CopyP16;

	PROCEDURE BGRA8888CopyP16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 4);
			SYSTEM.PUT16(dadr, PaletteIndex(mode.dst.pal, ORD(pix[r]), ORD(pix[g]), ORD(pix[b])));
			INC(sadr, 4); INC(dadr,2); DEC(len)
		END
	END BGRA8888CopyP16;

	PROCEDURE P16CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			mode.dst.pack(mode.dst, dadr, dbit, mode.src.pal.col[LONG(SYSTEM.GET16(sadr)) MOD 10000H]);
			INC(sadr,2); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END P16CopyAny;

	PROCEDURE P16CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			mode.dst.pack(mode.dst, dadr, 0, mode.src.pal.col[LONG(SYSTEM.GET16(sadr)) MOD 10000H]);
			INC(sadr,2); INC(dadr, 2); DEC(len)
		END
	END P16CopyAny16;
	*)

	PROCEDURE P16CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(ADDRESSOF(mode.src.pal.col[LONG(SYSTEM.GET16(sadr)) MOD 10000H]), dadr, 3);
			INC(sadr,2); INC(dadr, 3); DEC(len)
		END
	END P16CopyBGR888;

	PROCEDURE P16CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	VAR val:LONGINT;
	BEGIN
		WHILE len > 0 DO
			val:=LONG(SYSTEM.GET16(sadr)) MOD 10000H;
			SYSTEM.MOVE(ADDRESSOF(mode.src.pal.col[val]), dadr, 4);
			INC(sadr,2); INC(dadr, 4); DEC(len)
		END
	END P16CopyBGRA8888;



	(* BGR555, BGR565, BGR466 *)
	PROCEDURE AnyCopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, 0, pix);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(dadr, 2); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyAny16;

	PROCEDURE Any16CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(sadr, 2); INC(dadr, 2); DEC(len)
		END
	END Any16CopyAny16;

	PROCEDURE BGR888CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 3);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(sadr, 3); INC(dadr, 2); DEC(len)
		END
	END BGR888CopyAny16;

	PROCEDURE BGRA8888CopyAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 4);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(dadr, 2); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END BGRA8888CopyAny16;

	PROCEDURE Any16CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			mode.dst.pack(mode.dst, dadr, 0, pix);
			INC(sadr, 2); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END Any16CopyAny;

	PROCEDURE Any16CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 3);
			INC(sadr, 2); INC(dadr, 3); DEC(len)
		END
	END Any16CopyBGR888;

	PROCEDURE Any16CopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, 0, pix);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 4);
			INC(sadr, 2); INC(dadr, 4); DEC(len)
		END
	END Any16CopyBGRA8888;


	(* BGR888 *)
	PROCEDURE AnyCopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 3);
			INC(dadr, 3); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyBGR888;

	PROCEDURE BGRA8888CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, dadr, 3);
			INC(sadr, 4); INC(dadr, 3); DEC(len)
		END
	END BGRA8888CopyBGR888;

	PROCEDURE SSE2BGRA8888CopyBGR888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	CODE {SYSTEM.AMD64, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
		PUSHFQ
		PUSH 		RBX
		; CLI

		MOV		RSI, [RBP + sadr]	; source adr
		MOV 		RDI, [RBP + dadr]  ; source adr

		MOV		ECX, [RBP + len]

	loop:
		CMP		ECX, 0
		JLE			end
   		CMP 		ECX, 4
		 JL			singlepixel

	fourpixel:
		; 4pixels at the time
		MOV 		EAX,      [RSI] ; pixel 0
		MOV 		EBX,    [RSI + 4] ; pixel 1

		AND 		EAX, 0FFFFFFH
		AND 		EBX, 0FFFFFFH
		MOV 		EDX, EBX
		SHL			EDX, 24
		OR			EAX, EDX ; 1000
		MOV		[RDI], EAX ; write back to mem

		MOV 		EAX,    [RSI + 8] ; pixel 2
		AND 		EAX, 0FFFFFFH
		SHR		EBX,8
		MOV		EDX, EAX
		SHL			EDX, 16
		OR			EBX, EDX ; 2211
		MOV		[RDI + 4], EBX

		MOV 		EDX, [RSI + 12] ; pixel 3
		SHL			EDX, 8
		SHR		EAX, 16
		OR			EAX, EDX ; 3332

		MOV		[RDI], EAX

		ADD 		RSI, 16
		ADD 		RDI, 12
		SUB 		ECX, 4
		JG			loop
		JMP 		end

	singlepixel:
		MOV 		EAX, [RSI]

		MOV		[RDI], AX
		SHR		EAX, 16
		MOV		[RDI + 2], AL

		ADD 		RSI, 4
		ADD		RDI, 3
		SUB 		ECX, 1
		JG			loop

	end:
		EMMS ; declare FPU registers free
		POP 		RBX
		POPFQ
	END SSE2BGRA8888CopyBGR888;

	PROCEDURE BGR888CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		pix[a] := 0FFX;
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 3);
			mode.dst.pack(mode.dst, dadr, dbit, pix);
			INC(sadr, 3); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END BGR888CopyAny;

	PROCEDURE BGR888CopyBGRA8888(VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, dadr, 3); SYSTEM.PUT(dadr+3, 0FFX);
			INC(sadr, 3); INC(dadr, 4); DEC(len)
		END

	END BGR888CopyBGRA8888;

	PROCEDURE SSE2BGR888CopyBGRA8888(VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	CODE {SYSTEM.AMD64, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
		PUSHFQ
		PUSH 		RBX
		; CLI

		PXOR 		XMM0, XMM0

		MOV 		EAX, 0FF00H
		PINSRW 	XMM0, EAX, 1
		PINSRW 	XMM0, EAX, 3
		PINSRW 	XMM0, EAX, 5
		PINSRW 	XMM0, EAX, 7 ; prepare for fourpixel

		SHL 		EAX, 16 ; prepare for singlepixel

		MOV		RSI, [RBP + sadr]	; source adr
		MOV 		RDI, [RBP + dadr]  ; source adr

		MOV		ECX, [RBP + len]

	loop:
		CMP		ECX, 0
		JLE			end
   		CMP 		ECX, 4
		 JL			singlepixel

	fourpixel:
	; 4pixels at the time
		PXOR 		XMM2,XMM2
		PXOR 		XMM1,XMM1

		MOV		EBX, [RSI + 9] ; read 1st source pixel
		MOVD 		XMM2, EBX

		PSLLDQ		XMM2, 4
		MOV		EBX, [RSI + 6] ; read 2nd source pixel
		MOVD 		XMM1, EBX
		POR 		XMM2, XMM1

		PSLLDQ		XMM2, 4
		MOV		EBX, [RSI + 3] ; read 3rd source pixel
		MOVD 		XMM1, EBX
		POR 		XMM2, XMM1

		PSLLDQ		XMM2, 4
		MOV		EBX, [RSI] ; read 4th source pixel
		MOVD 		XMM1, EBX
		POR 		XMM2, XMM1
		ADD 		RSI, 12

		POR 		XMM2, XMM0

		MOVDQU 	[RDI], XMM2 ; set the pixels
		ADD		RDI, 16	; inc adr
		SUB 		ECX, 4
		JG			loop
		JMP 		end

	singlepixel:
		MOV		EBX, [RSI] ; read source pixel
		OR 			EBX, EAX
		ADD 		RSI, 3
		MOV 		[RDI], EBX

		ADD		RDI, 4	; inc adr
		SUB 		ECX, 1
		JG			loop
	end:
		EMMS ; declare FPU registers free
		POP 		RBX
		POPFQ
	END SSE2BGR888CopyBGRA8888;

	(* BGRA8888 *)
	PROCEDURE AnyCopyBGRA8888 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			pix := mode.buf;
			mode.src.unpack(mode.src, sadr, sbit, pix);
			SYSTEM.MOVE(ADDRESSOF(pix[0]), dadr, 4);
			INC(dadr, 4); sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; DEC(len)
		END
	END AnyCopyBGRA8888;

	PROCEDURE BGRA8888CopyAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.MOVE(sadr, ADDRESSOF(pix[0]), 4);
			mode.dst.pack(mode.dst, dadr, dbit, pix);
			INC(sadr, 4); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len)
		END
	END BGRA8888CopyAny;


	(*--- dstCopy Transfer ---*)

	PROCEDURE EmptyTransfer (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	END EmptyTransfer;


	(*--- srcOverDst Transfer ---*)

	(* A1 *)
	PROCEDURE AnyOverA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR out: CHAR; pix: Pixel;
	BEGIN
		SYSTEM.GET(dadr, out);
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, pix);
			IF pix[a] >= 80X THEN
				out := Set[ORD(out), dbit]
			END;
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				SYSTEM.GET(dadr, out)
			END
		END;
		SYSTEM.PUT(dadr, out)
	END AnyOverA1;

	PROCEDURE A1OverA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in); SYSTEM.GET(dadr, out);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				out := Set[ORD(out), dbit]
			END;
			INC(sbit); INC(dbit); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END;
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				SYSTEM.GET(dadr, out)
			END
		END;
		SYSTEM.PUT(dadr, out)
	END A1OverA1;

	PROCEDURE A8OverA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		SYSTEM.GET(dadr, out);
		WHILE len > 0 DO
			SYSTEM.GET(sadr, in);
			IF in >= 80X THEN
				out := Set[ORD(out), dbit]
			END;
			INC(sadr); INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				SYSTEM.GET(dadr, out)
			END
		END;
		SYSTEM.PUT(dadr, out)
	END A8OverA1;

	PROCEDURE BGRA8888OverA1 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		SYSTEM.GET(dadr, out);
		WHILE len > 0 DO
			SYSTEM.GET(sadr + a, in);
			IF in >= 80X THEN
				out := Set[ORD(out), dbit]
			END;
			INC(sadr, 4); INC(dbit); DEC(len);
			IF dbit = 8 THEN
				SYSTEM.PUT(dadr, out);
				INC(dadr); dbit := 0;
				SYSTEM.GET(dadr, out)
			END
		END;
		SYSTEM.PUT(dadr, out)
	END BGRA8888OverA1;

	PROCEDURE A1OverAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				mode.dst.pack(mode.dst, dadr, dbit, mode.buf)
			END;
			INC(sbit); dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8; DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1OverAny;

	PROCEDURE A1OverConst8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				SYSTEM.PUT(dadr, mode.buf[0])
			END;
			INC(sbit); INC(dadr); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1OverConst8;

	PROCEDURE A1OverConst16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				SYSTEM.MOVE(ADDRESSOF(mode.buf[0]), dadr, 2)
			END;
			INC(sbit); INC(dadr, 2); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1OverConst16;

	PROCEDURE A1OverConst24 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				SYSTEM.MOVE(ADDRESSOF(mode.buf[0]), dadr, 3)
			END;
			INC(sbit); INC(dadr, 3); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1OverConst24;

	PROCEDURE A1OverConst32 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in: CHAR;
	BEGIN
		SYSTEM.GET(sadr, in);
		WHILE len > 0 DO
			IF Bit[ORD(in), sbit] THEN
				SYSTEM.MOVE(ADDRESSOF(mode.buf[0]), dadr, 4)
			END;
			INC(sbit); INC(dadr, 4); DEC(len);
			IF sbit = 8 THEN
				INC(sadr); sbit := 0;
				SYSTEM.GET(sadr, in)
			END
		END
	END A1OverConst32;


	(* A8 *)
	PROCEDURE AnyOverA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR pix: Pixel; b: CHAR;
	BEGIN
		WHILE len > 0 DO
			mode.src.unpack(mode.src, sadr, sbit, pix);
			IF pix[a] = 0FFX THEN
				SYSTEM.PUT(dadr, 0FFX)
			ELSIF pix[a] # 0X THEN
				SYSTEM.GET(dadr, b);
				SYSTEM.PUT(dadr, CHR(ORD(pix[a]) + ORD(b) * LONG(255-ORD(pix[a])) DIV 255))
			END;
			sbit := sbit + mode.src.bpp; INC(sadr, sbit DIV 8); sbit := sbit MOD 8; INC(dadr); DEC(len)
		END
	END AnyOverA8;

	PROCEDURE A8OverAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR dpix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, mode.buf[a]);
			IF mode.buf[a] = 0FFX THEN
				mode.dst.pack(mode.dst, dadr, dbit, mode.buf)
			ELSIF mode.buf[a] # 0X THEN
				mode.dst.unpack(mode.dst, dadr, dbit, dpix);
				Blend(mode.op, mode.buf, dpix);
				mode.dst.pack(mode.dst, dadr, dbit, dpix)
			END;
			INC(sadr); DEC(len);
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8
		END
	END A8OverAny;

	PROCEDURE A8OverA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr, in);
			IF in = 0FFX THEN
				SYSTEM.PUT(dadr, 0FFX)
			ELSIF in # 0X THEN
				SYSTEM.GET(dadr, out);
				SYSTEM.PUT(dadr, CHR(ORD(in) + ORD(out) * LONG(255-ORD(in)) DIV 255))
			END;
			INC(sadr); INC(dadr); DEC(len)
		END
	END A8OverA8;


	(* BGRA8888 *)
	PROCEDURE BGRA8888OverAny (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR spix, dpix: Pixel;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET (sadr, spix);
			IF spix[a] = 0FFX THEN
				mode.dst.pack(mode.dst, dadr, dbit, spix)
			ELSIF spix[a] # 0X THEN
				mode.dst.unpack(mode.dst, dadr, dbit, dpix);
				Blend(mode.op, spix, dpix);
				mode.dst.pack(mode.dst, dadr, dbit, dpix)
			END;
			INC(sadr, SIZEOF (Pixel)); DEC(len);
			dbit := dbit + mode.dst.bpp; INC(dadr, dbit DIV 8); dbit := dbit MOD 8
		END
	END BGRA8888OverAny;

	PROCEDURE BGRA8888OverA8 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR in, out: CHAR;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET(sadr + a, in);
			IF in = 0FFX THEN
				SYSTEM.PUT(dadr, 0FFX)
			ELSIF in # 0X THEN
				SYSTEM.GET(dadr, out);
				SYSTEM.PUT(dadr, CHR(ORD(in) + ORD(out) * (255 - ORD(in)) DIV 255))
			END;
			INC(sadr, 4); INC(dadr); DEC(len)
		END
	END BGRA8888OverA8;

	PROCEDURE BGRA8888OverAny16 (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR src, dst: Pixel; fd, t: LONGINT;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET (sadr, src);
			IF src[a] = 0FFX THEN
				mode.dst.pack(mode.dst, dadr, dbit, src)
			ELSIF src[a] # 0X THEN
				mode.dst.unpack(mode.dst, dadr, 0, dst);
				fd := 255-ORD(src[a]);
				t := (256 * ORD(src[0]) + fd * ORD(dst[0])) DIV 256;
				IF t < 255 THEN dst[0] := CHR(t) ELSE dst[0] := CHR(255) END;

				t := (256 * ORD(src[1]) + fd * ORD(dst[1])) DIV 256;
				IF t < 255 THEN dst[1] := CHR(t) ELSE dst[1] := CHR(255) END;
				t := (256 * ORD(src[2]) + fd * ORD(dst[2])) DIV 256;
				IF t < 255 THEN dst[2] := CHR(t) ELSE dst[2] := CHR(255) END;
				t := (256 * ORD(src[3]) + fd * ORD(dst[3])) DIV 256;
				IF t < 255 THEN dst[3] := CHR(t) ELSE dst[3] := CHR(255) END;
				mode.dst.pack(mode.dst, dadr, 0, dst);
			END;
			INC(dadr, 2); INC(sadr, SIZEOF (Pixel)); DEC(len)
		END
	END BGRA8888OverAny16;

	PROCEDURE BGRA8888Over565* (VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
		VAR src, dst: Pixel; fd, t: LONGINT;
	BEGIN
		WHILE len > 0 DO
			SYSTEM.GET (sadr, src);
			IF src[a] = 0FFX THEN
				SYSTEM.PUT16(dadr, ASH(ORD(src[b]), -3) + ASH(ASH(ORD(src[g]), -2), 5) + ASH(ASH(ORD(src[r]), -3), 11));
			ELSIF src[a] # 0X THEN
				t := SYSTEM.GET16(dadr);
				dst[b] := CHR((t MOD 32) * 8); dst[g] := CHR((t DIV 32 MOD 64) * 4); dst[r] := CHR((t DIV 2048 MOD 32) * 8);

				fd := 256-ORD(src[a]);
				t := (256 * ORD(src[0]) + fd * ORD(dst[0])) DIV 256;
				IF t < 255 THEN dst[0] := CHR(t) ELSE dst[0] := CHR(255) END;

				t := (256 * ORD(src[1]) + fd * ORD(dst[1])) DIV 256;
				IF t < 255 THEN dst[1] := CHR(t) ELSE dst[1] := CHR(255) END;
				t := (256 * ORD(src[2]) + fd * ORD(dst[2])) DIV 256;
				IF t < 255 THEN dst[2] := CHR(t) ELSE dst[2] := CHR(255) END;
				t := (256 * ORD(src[3]) + fd * ORD(dst[3])) DIV 256;
				IF t < 255 THEN dst[3] := CHR(t) ELSE dst[3] := CHR(255) END;
				SYSTEM.PUT16(dadr, ASH(ORD(dst[b]), -3) + ASH(ASH(ORD(dst[g]), -2), 5) + ASH(ASH(ORD(dst[r]), -3), 11));
			END;
			INC(dadr, 2); INC(sadr, 4); DEC(len)
		END
	END BGRA8888Over565;


	PROCEDURE MMXBGRA8888Over565(VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	CODE {SYSTEM.AMD64, SYSTEM.MMX}
		PUSHFQ
		; CLI
		MOV 		RSI, [RBP + sadr]
		MOV 		RDI, [RBP + dadr]
		PXOR 		MMX0, MMX0
		PXOR 		MMX1, MMX1

		MOV		EAX, 0FFFFFFFFH
		MOVD		MMX7, EAX
		PUNPCKLBW MMX7, MMX0  ; 00FF00FF00FF00FF

		MOV		ECX, [RBP + len]
	loop:
		CMP		ECX, 0
		JE 			WORD end

		MOV		EAX, [RSI]
		XOR		EBX, EBX
		MOV		BX, [RDI]

		; 255 - alpha
		MOV		EDX, EAX
		SHR		EDX, 24
		CMP		EDX, 0
		JE			WORD empty
		CMP		EDX, 255
		JE			full

	alpha:
		NEG		EDX
		ADD		EDX, 255
		MOVD 		MMX6, EDX
		PUNPCKLWD MMX6, MMX6
		PUNPCKLDQ MMX6, MMX6

		MOVD 		MMX1, EAX

		; unpack dst
		MOV		EDX, EBX ; b
		SHL			EDX, 3
		AND		EDX, 0F8H
		MOV		EAX, EDX

		MOV		EDX, EBX ; g
		SHL			EDX, 5
		AND		EDX, 0FC00H
		OR			EAX, EDX

		MOV		EDX, EBX ; r
		SHL			EDX, 8
		AND		EDX, 0F80000H
		OR			EAX, EDX

		MOVD		MMX2, EAX

		PUNPCKLBW  MMX1, MMX0  ; 0000ARGB --> 0A0R0G0B
		PMULLW  	MMX1, MMX7

		PUNPCKLBW  MMX2, MMX0  ; 0000ARGB --> 0A0R0G0B
		PMULLW 	MMX2, MMX6

		PADDUSW 	MMX1, MMX2

		;	PSRLW	MM1, 8 ; normalize
		DB 			0FH, 71H, 0D1H, 08H
		PACKUSWB MMX1, MMX0

		; HUGA BIMBO Muell
		MOVD		EAX, MMX1

	full:
;			XOR EDX, EDX
;			SHR EAX, 3
;			MOV EDX, EAX
;			AND EDX, 1FH
;			SHR EAX, 2
;			AND EAX, 0FFFFFFE0H
;			OR EDX, EAX
;			AND EDX, 7FFH
;
;			SHR EAX, 3
;			AND EAX,
;
;
;			SHR AL, 3
;			SHR AH, 2
;			MOV EDX, EAX
;			SHR EAX, 3
;			AND EAX, 01F0000H
;			OR EDX, EAX
;			AND EDX, 01F3F1FH


		MOV		EBX, EAX
		AND		EBX, 0FFH
		SHR		EBX, 3
		MOV		EDX, EBX

		MOV		EBX, EAX
		SHR		EBX, 8
		AND		EBX, 0FFH
		SHR		EBX, 2
		SHL			EBX, 5
		OR			EDX, EBX

		MOV		EBX, EAX
		SHR		EBX, 16
		AND		EBX, 0FFH
		SHR		EBX, 3
		SHL			EBX, 11
		OR			EDX, EBX

		MOV 		[RDI], DX
	empty:
		ADD 		RSI, 4;
		ADD 		RDI, 2;
		DEC		ECX
		JMP 		WORD loop
	end:
		EMMS ; declare FPU registers free
		POPFQ
	END MMXBGRA8888Over565;


	PROCEDURE SSE2BGRA8888Over565(VAR mode: Mode0; sadr: ADDRESS; sbit: LONGINT; dadr: ADDRESS; dbit, len: LONGINT);
	CODE {SYSTEM.AMD64, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
		PUSHFQ
		PUSH 		RBX
		; CLI

		PXOR 		MMX0, MMX0
		PXOR 		MMX1, MMX1
		PXOR 		MMX2, MMX2
		PXOR 		MMX3, MMX3
		PXOR 		MMX4, MMX4
		PXOR 		MMX5, MMX5
		PXOR 		MMX6, MMX6
		PXOR 		MMX7, MMX7

		PXOR 		XMM3, XMM3
		PXOR 		XMM4, XMM4

		MOV 		RSI, [RBP + sadr]
		MOV 		RDI, [RBP + dadr]
		MOV 		ECX, [RBP + len]

		;  create masks

		; src only FF which is rotated -> MM3
		MOV		EAX, 0000000FFH
		MOVD		MMX3, EAX

		; dest red -> MM4
		MOV		EAX, 0F800F800H
		MOVD		MMX4, EAX

		; dest green -> MM5
		MOV		EAX, 07E007E0H
		MOVD		MMX5, EAX

		; dest blue -> MM6 ; moved as MM6 is used in singlepixel
		; MOV	 	EAX, 001F001FH
		; MOVD		MMX6, EAX

		; BEGIN
		; 		WHILE len > 0 DO

	loop:
		CMP 		ECX,0
		JE 			WORD end ; jump to end if ECX = 0

		; if len < 8 then do one pixel at the time
		CMP		ECX, 8
		JL 			WORD singlepixel
		; else
		; take 8 at the time

		MOV		EBX, ESI
		AND 		EBX, 0FH
		CMP		EBX, 0
		JNE 		WORD singlepixel

	alleightpixels:
		; dest blue -> MM6
		MOV		EAX, 001F001FH
		MOVD		MMX6, EAX

		; src := SYSTEM.VAL(Pixel, SYSTEM.GET32(sadr));
		; Load data into memory
		;MOV 	XMM4, 0FF000000FF000000FF000000FF000000H

		MOVDQA 	XMM2, [RSI] ;src 5-8
		MOVQ2DQ	XMM4,  MMX3     ; 000000000000000000000000000000FFH
		MOVDQA 	XMM1, [RSI + 16]  ;src 1-4
		PREFETCHNTA		[RSI + 32] ; prepare src 9-15

		; get alphas
		MOVDQU 	XMM6, XMM2
		PSHUFD		XMM4, XMM4, 0
		MOVDQU 	XMM5, XMM1
		PSLLD 		XMM4, 24
		PAND 		XMM6, XMM4 ; alpha 5-8 in XMM6
		PAND 		XMM5, XMM4  ; alpha 1-4 in XMM5
		PSRLD 		XMM5, 24
		PSHUFHW 	XMM5, XMM5, 85H
		PSRLD 		XMM6, 24

		; put both alphas into 1 register
		PSHUFHW 	XMM6, XMM6, 85H
		PSHUFLW 	XMM5, XMM5, 85H
		PSHUFLW 	XMM6, XMM6, 58H
		PSHUFD		XMM5, XMM5, 0D0H  ; 0102030400000000
		PSHUFD 	XMM6, XMM6, 5CH ; 0000000005060708
		PXOR 		XMM0,XMM0
		POR		XMM5, XMM6            ; XMM5 = alphas 0102030405060708

		PCMPEQD 	XMM0, XMM5
		PMOVMSKB EAX, XMM0
		CMP 		EAX, 0FFFFH ; all alphas = zero; TEST not possible, because only 8 bits compared
		JE      		WORD endloop

		; mask out alpha = zero

		; fd := 255-ORD(src[a]); fd = XMM4
		; MOV 	XMM4, 00FF00FF00FF00FF00FF00FF00FF00FFH
		PXOR 		XMM4, XMM4
		MOV	 	EAX, 00FFH
		PINSRW	XMM4, EAX ,0
		PSHUFLW 	XMM4, XMM4, 0
		PSHUFD 	XMM4, XMM4, 0
		PSUBW 		XMM4, XMM5
		MOV 		EAX,1H
		PINSRW	XMM3, EAX ,0
		PSHUFLW 	XMM3, XMM3, 0
		PSHUFD 	XMM3, XMM3, 0
		PADDUSW 	XMM4, XMM3

		; new red
		; calculate red 2

		; get source

		; sred14 = src14 && (srcMask <<16)
		; srcMask << 16
		MOVQ2DQ 	XMM3, MMX3
		PSHUFD 	XMM3, XMM3, 0
		MOVDQU 	XMM5, XMM1
		MOVDQU 	XMM6, XMM2
		PSLLD 		XMM3, 16

		; sred14 = src14 && (srcMask << 24)
		; src14 must be copied because it mustn't be changed
		PAND 		XMM5, XMM3 ; sred14
		PSRLD 		XMM5, 16

		; sred14s = shuffled sred14
		PSHUFHW 	XMM5, XMM5,85H
		PAND 		XMM6, XMM3 ; sred58
		PSRLD 		XMM6, 16

		PSHUFLW 	XMM5, XMM5,85H
		PSHUFHW 	XMM6, XMM6,85H
		PSHUFD  	XMM5, XMM5,0D0H ; sred14s
		PSHUFLW 	XMM6, XMM6,58H
		PSHUFD  	XMM6, XMM6,5CH ; sred58s
		POR 		XMM5, XMM6 ; sred18

		; sred18255 = sred18 * 256- sred18
		MOVDQU 	XMM7, XMM5
		PSLLW 		XMM5, 8
		PSUBUSW 	XMM5, XMM7 ; sred18255

		; src is now ready

		; destination
		; dest18 must be copied because it mustn't be changed
		; Load data into memory
		MOVDQU 	XMM3, [RDI]  ;dest 1-8
		MOVQ2DQ 	XMM6, MMX4
		PSHUFD 	XMM6, XMM6, 0
		MOVDQU 	XMM7, XMM3

		PAND 		XMM7, XMM6 ; dred18
		PSRLW 		XMM7, 8
		;  dred18alpha = dred18 * negalpha
		PMULLW XMM7, XMM4 ; dred18alpha

		; dest is prepared
		; combining dest and src

		; dred18big = sred18255 + dred18alpha
		PADDUSW 	XMM7, XMM5 ; dred18big
		; dred18f = dred18big && destMaskred128  because >> 11 and << 11 is && mask
		PAND 		XMM7, XMM6 ; dred18f

 		; dest18nr0 = dest18 && (~destMaskred128)
 		PANDN 	XMM6, XMM3  ; dest18nr0

 		; dest18nrf = dest18nr0 || dred18f
 		POR 		XMM6, XMM7

		MOVDQU 	XMM3, XMM6

		; red is calculated

		; calculate green:
		; get source

		; sgreen14 = src14 && (srcMask <<8)
		; srcMask << 8
		MOVQ2DQ 	XMM7, MMX3

		PSHUFD 	XMM7, XMM7, 0
		MOVDQU 	XMM5, XMM1
		PSLLD 		XMM7, 8
		PAND 		XMM5, XMM7 ; sgreen14
		PSRLD 		XMM5, 8

		; sgreen14s = shuffled sgreen14
		PSHUFHW 	XMM5, XMM5,85H
		MOVDQU 	XMM6, XMM2
		PSHUFLW 	XMM5, XMM5,85H
		PAND 		XMM6, XMM7 ; sgreen58
		PSRLD 		XMM6, 8
		PSHUFD  	XMM5, XMM5,0D0H ; sgreen14s

		; sgreen58 = src58&& (srcMask << 8)
		; src58 must be copied because it mustn't be changed

		; sgreen58s = shuffled sgreen58
		PSHUFHW 	XMM6, XMM6,85H
		PSHUFLW 	XMM6, XMM6,58H
		PSHUFD  	XMM6, XMM6,5CH ; sgreen58s

		; sgreen18 = sgreen14s || sgreen58s
		POR 		XMM5, XMM6 ; sgreen18

		; sgreen18255 = sgreen18 * 256- sgreen18
		MOVDQU 	XMM7, XMM5
		MOVQ2DQ	XMM6, MMX5

		PSLLW 		XMM5, 8
		PSUBUSW 	XMM5, XMM7 ; sgreen18255
		PSHUFD 	XMM6, XMM6, 0

		MOVDQU 	XMM7, XMM3

		PAND 		XMM7, XMM6 ; dgreen18
		PSRLW 		XMM7,3
		;  dgreen18alpha = dgreen18 * negalpha
		PMULLW 	XMM7, XMM4 ; dgreen18alpha

		; dest is prepared
		; combining dest and src

		; dgreen18big = sgreen18255 + dgreen18alpha

	 	PADDUSW 	XMM7, XMM5 ; dgreen18big
		PANDN 	XMM6, XMM3  ; dest18ng0

		; dgreen18f = (dgreen18big >> 11) <<5

		PSRLW 		XMM7, 10 ; dgreen18f
		PSLLW 		XMM7, 5

 		; dest18ng0 = dest18 && (~destMaskgreen128)

  		; dest18ngf = dest18ng0 || dred18f
 		POR 		XMM6, XMM7
		MOVDQU 	XMM3, XMM6

		; green is calculated

		; calculate blue
		; get source

		; sblue14 = src14 && (srcMask)
		; srcMask
		MOVQ2DQ 	XMM7, MMX3
		MOVDQU 	XMM5, XMM1

		PSHUFD 	XMM7, XMM7, 0
		MOVDQU 	XMM6, XMM2

		; sblue14 = src14 && (srcMask)
		; src14 must be copied because it mustn't be changed
		PAND 		XMM5, XMM7 ; sblue14

		; sblue14s = shuffled sblue14
		PSHUFHW 	XMM5, XMM5,85H
		PAND 		XMM6, XMM7 ; sblue58
		PSHUFHW 	XMM6, XMM6,85H

		PSHUFLW 	XMM5, XMM5,85H
		PSHUFLW 	XMM6, XMM6,58H

		PSHUFD  	XMM5, XMM5,0D0H ; sblue14s
		PSHUFD  	XMM6, XMM6,5CH ; sblue58s

		POR 		XMM5, XMM6 ; sblue18

		; sblue18255 = sblue18 * 256- sblue18
		MOVDQU 	XMM7, XMM5
		PSLLW 		XMM5, 8
		PSUBUSW 	XMM5, XMM7 ; sblue18255
		MOVQ2DQ	XMM6, MMX6
		PSHUFD 	XMM6, XMM6, 0
		MOVDQU 	XMM7, XMM3
		PAND 		XMM7, XMM6 ; dblue18
		PSLLW 		XMM7, 3

		PMULLW 	XMM7, XMM4 ; dblue18alpha

		; dest is prepared
		; combining dest and src

		; dblue18big = sblue18255 + dblue18alpha

	 	PADDUSW 	XMM7, XMM5 ; dblue18big
		; dblue18f = (dblue18big >> 11)
		PANDN 	XMM6, XMM3  ; dest18nr0
 		PSRLW 		XMM7, 11 ; dblue18f

  		; dest18nr0 = dest18 && (~destMaskblue128)

  		; dest18nbf = dest18nb0 || dblue18f
 		POR 		XMM6, XMM7
		MOVDQU 	XMM3, XMM6

		; blue is calculated

		; now dest is calculated, store it
		; get 0 stuff
		MOVDQU	XMM5, [RDI]
		PAND		XMM5,XMM0
		PANDN		XMM0, XMM3
		POR		XMM0, XMM5

		MOVDQU 	[RDI],XMM0
		PREFETCHNTA		[RDI + 16] ; prepare dest 9-15
	endloop:
		ADD 		RSI, 32 ; num of bytes
		ADD 		RDI, 16
		SUB 		ECX, 8
		JMP 		WORD loop

	singlepixel: ; original code from MMXBGRA8888Over565, adjusted to fit this procedure
		MOV	 	EAX, 0FFFFFFFFH
		MOVD		MMX7, EAX
		PUNPCKLBW  MMX7, MMX0  ; 00FF00FF00FF00FF

		MOV 		EAX,[RSI]
		XOR		EBX, EBX
		MOV 		BX,	[RDI]

		; 255 - alpha
		MOV		EDX, EAX
		SHR		EDX, 24

		CMP		EDX, 0
		JE			WORD empty
		CMP		EDX, 255
		JE			full

	alpha:
		NEG		EDX
		ADD		EDX, 255

		MOVD 		MMX6, EDX
		PUNPCKLWD MMX6, MMX6
		PUNPCKLDQ MMX6, MMX6

		MOVD 		MMX1, EAX
		; unpack dst
		MOV		EDX, EBX ; b
		SHL			EDX, 3
		AND		EDX, 0F8H
		MOV		EAX, EDX

		MOV		EDX, EBX ; g
		SHL			EDX, 5
		AND		EDX, 0FC00H
		OR			EAX, EDX

		MOV		EDX, EBX ; r
		SHL			EDX, 8
		AND		EDX, 0F80000H
		OR			EAX, EDX

		MOVD		MMX2, EAX
		PUNPCKLBW MMX1, MMX0  ; 0000ARGB --> 0A0R0G0B
		PMULLW 	MMX1, MMX7
		PUNPCKLBW MMX2, MMX0  ; 0000ARGB --> 0A0R0G0B
		PMULLW 	MMX2, MMX6
		PADDUSW 	MMX1, MMX2

	;	PSRLW	MM1, 8 ; normalize
		DB 			0FH, 71H, 0D1H, 08H
		PACKUSWB 	MMX1, MMX0

		; HUGA BIMBO Muell
		MOVD		EAX, MMX1

	full:
		MOV		EBX, EAX
		AND		EBX, 0FFH
		SHR		EBX, 3
		MOV		EDX, EBX

		MOV		EBX, EAX
		SHR		EBX, 8
		AND		EBX, 0FFH
		SHR		EBX, 2
		SHL			EBX, 5
		OR			EDX, EBX

		MOV		EBX, EAX
		SHR		EBX, 16
		AND		EBX, 0FFH
		SHR		EBX, 3
		SHL			EBX, 11
		OR			EDX, EBX

		MOV 		[RDI], DX

	empty:
		ADD 		RSI, 4;
		ADD 		RDI, 2;
		DEC		ECX
		JMP 		WORD loop

	end:
		EMMS ; declare FPU registers free
		POP 		RBX
		POPFQ

	END SSE2BGRA8888Over565;


	(** find (optimized) pixel transfer procedure for transfer mode and given source and destination formats **)
	PROCEDURE Bind* (VAR mode: Mode; VAR src, dst: Format);
		VAR op: LONGINT; val,i: LONGINT;
	BEGIN
		IF Same(src, mode.src) & Same(dst, mode.dst) THEN
			ASSERT(mode.transfer # NIL, 120);
			RETURN	(* assume transfer procedure is still valid *)
		END;
		mode.src := src; mode.dst := dst; mode.buf := mode.col;
		IF  (src.pal # NIL) & ((mode.map = NIL) OR (LEN(mode.map^) # src.pal.used) ) THEN
			NEW(mode.map, src.pal.used)
		END;
		(* try to convert complex composite operations into simpler ones *)
		IF alpha IN src.components * dst.components THEN	(* source and destination contain alpha information *)
			op := mode.op
		ELSIF alpha IN src.components THEN	(* only source contains alpha *)
			CASE mode.op OF
			| dstOverSrc: op := dstCopy
			| srcInDst: op := srcCopy
			| srcWithoutDst: op := clear
			| srcAtopDst: op := srcOverDst
			| dstAtopSrc: op := dstInSrc
			| srcXorDst: op := dstWithoutSrc
			ELSE op := mode.op
			END
		ELSIF alpha IN dst.components THEN	(* only destination contains alpha *)
			CASE mode.op OF
			| srcOverDst: op := srcCopy
			| dstInSrc: op := dstCopy
			| dstWithoutSrc: op := clear
			| srcAtopDst: op := srcInDst
			| dstAtopSrc: op := dstOverSrc
			| srcXorDst: op := srcWithoutDst
			ELSE op := mode.op
			END
		ELSE	(* no alpha in either source or destination *)
			CASE mode.op OF
			| srcOverDst, srcInDst, srcAtopDst: op := srcCopy
			| dstOverSrc, dstInSrc, dstAtopSrc: op := dstCopy
			| srcWithoutDst, dstWithoutSrc, srcXorDst: op := clear
			ELSE op := mode.op
			END
		END;

		IF op = InvDst THEN
			mode.transfer:=InvAny;
		ELSIF op = InvOverDst THEN
			mode.transfer:=InvOverAny;
		ELSIF op = clear THEN
			CASE dst.code OF
			| a1: mode.transfer := Clear1
			| a8, bgr555, bgr565, bgr466, bgr888, bgra8888: mode.transfer := ClearBytes
			| p8:
				mode.buf[0] := CHR(CLUTs.Match(dst.pal.clut, 0));
				IF mode.buf[0] = 0X THEN mode.transfer := ClearBytes
				ELSE mode.transfer := ConstCopy8
				END
			| d8:
				mode.buf[0] := CHR(ColorToIndex(0));
				IF mode.buf[0] = 0X THEN mode.transfer := ClearBytes
				ELSE mode.transfer := ConstCopy8
				END
			| p16:
				val:=CLUTs.Match(dst.pal.clut, 0);
				IF dst.pal.used>256 THEN val:=val*dst.pal.used DIV 256 END;
				SYSTEM.PUT16(ADDRESSOF(mode.buf[0]),SHORT(val)); (*PH090122*)
				(*mode.buf[0] := CHR(PaletteIndex(dst.pal, 0, 0, 0));*)
				IF val = 0 THEN mode.transfer := ClearBytes
				ELSE mode.transfer := ConstCopy16
				END
			ELSE mode.transfer := ClearAny
			END

		ELSIF op = srcCopy THEN
			CASE dst.code OF
			| a1:
				CASE src.code OF
				| a1: mode.transfer := Copy1
				| a8: mode.transfer := A8CopyA1
				| bgra8888: mode.transfer := BGRA8888CopyA1
				ELSE
					IF alpha IN src.components THEN mode.transfer := AnyCopyA1
					ELSE mode.transfer := Set1
					END
				END
			| a8:
				CASE src.code OF
				| a1: mode.transfer := A1CopyA8
				| a8: mode.transfer := Copy8
				| bgra8888: mode.transfer := BGRA8888CopyA8
				ELSE
					IF alpha IN src.components THEN mode.transfer := AnyCopyA8
					ELSE mode.buf[0] := 0FFX; mode.transfer := ConstCopy8
					END
				END
			| p8:
				CASE src.code OF
				| a1, a8:
					mode.buf[0] := CHR(CLUTs.Match(dst.pal.clut, ORD(mode.col[b]) + ASH(ORD(mode.col[g]), 8) +
						ASH(ORD(mode.col[r]), 16)));
					mode.transfer := ConstCopy8
				| p8:
					IF src.pal = dst.pal THEN mode.transfer := Copy8
					ELSE
						FOR i := 0 TO src.pal.used-1 DO
							mode.map[i] := SHORT(CLUTs.Match(dst.pal.clut, ORD(src.pal.col[i, b]) + ASH(ORD(src.pal.col[i, g]), 8) +
								ASH(ORD(src.pal.col[i, r]), 16)))
						END;
						mode.transfer := I8CopyI8
					END
				| d8:
					FOR i := 0 TO 255 DO
						mode.map[i] := SHORT(CLUTs.Match(dst.pal.clut, IndexToColor(i) MOD 1000000H))
					END;
					mode.transfer := I8CopyI8
				| bgr555, bgr565, bgr466,p16: mode.transfer := Any16CopyP8
				| bgr888: mode.transfer := BGR888CopyP8
				| bgra8888: mode.transfer := BGRA8888CopyP8
				ELSE mode.transfer := AnyCopyP8
				END
			| d8:
				CASE src.code OF
				| a1, a8:
					mode.buf[0] := CHR(ColorToIndex(
						ORD(mode.col[b]) + ASH(ORD(mode.col[g]), 8) + ASH(ORD(mode.col[r]), 16)));
					mode.transfer := ConstCopy8
				| p8:
					FOR i := 0 TO src.pal.used-1 DO
						mode.map[i] := SHORT(ColorToIndex(
							ORD(src.pal.col[i, b]) + ASH(ORD(src.pal.col[i, g]), 8) + ASH(ORD(src.pal.col[i, r]), 16)))
					END;
					mode.transfer := I8CopyI8
				| d8: mode.transfer := Copy8
				| bgr555, bgr565, bgr466, p16: mode.transfer := Any16CopyD8
				| bgr888: mode.transfer := BGR888CopyD8
				| bgra8888: mode.transfer := BGRA8888CopyD8
				ELSE mode.transfer := AnyCopyD8
				END
			| p16:
				CASE src.code OF
				| a1, a8: dst.pack(dst, ADDRESSOF(mode.buf[0]), 0, mode.col); mode.transfer := ConstCopy16
				| p8: mode.transfer := P8CopyAny16
				| d8: mode.transfer := D8CopyAny16
				| p16:
					IF src.pal = dst.pal THEN mode.transfer := Copy16
					ELSE
						FOR i := 0 TO src.pal.used-1 DO
							val:=CLUTs.Match(dst.pal.clut, ORD(src.pal.col[i, b]) + ASH(ORD(src.pal.col[i, g]), 8) +
								ASH(ORD(src.pal.col[i, r]), 16));
							IF dst.pal.used>256 THEN val := val * dst.pal.used DIV 256 END;
							mode.map[i] := SHORT(val)
						END;
						mode.transfer := I16CopyI16
					END
				| bgr555, bgr565, bgr466:  mode.transfer := Any16CopyAny16
				| bgr888: mode.transfer := BGR888CopyAny16
				| bgra8888: mode.transfer := BGRA8888CopyAny16
				ELSE mode.transfer := AnyCopyAny16
				END;
			| bgr555, bgr565, bgr466:
				CASE src.code OF
				| a1, a8: dst.pack(dst, ADDRESSOF(mode.buf[0]), 0, mode.col); mode.transfer := ConstCopy16
				| p8: mode.transfer := P8CopyAny16
				| d8: mode.transfer := D8CopyAny16
				| bgr555, bgr565, bgr466,p16:
					IF src.code = dst.code THEN mode.transfer := Copy16
					ELSE mode.transfer := Any16CopyAny16
					END
				| bgr888: mode.transfer := BGR888CopyAny16
				| bgra8888: mode.transfer := BGRA8888CopyAny16
				ELSE mode.transfer := AnyCopyAny16
				END;
			| bgr888:
				CASE src.code OF
				| a1, a8: mode.buf := mode.col; mode.transfer := ConstCopy24
				| p8: mode.transfer := P8CopyBGR888
				| d8: mode.transfer := D8CopyBGR888
				| p16: mode.transfer := P16CopyBGR888	(*PH090122*)
				| bgr555, bgr565, bgr466: mode.transfer := Any16CopyBGR888
				| bgr888: mode.transfer := Copy24
				| bgra8888: IF SSE2enabled THEN mode.transfer := SSE2BGRA8888CopyBGR888
							ELSE mode.transfer := BGRA8888CopyBGR888
							END;
				ELSE mode.transfer := AnyCopyBGR888
				END
			| bgra8888:
				CASE src.code OF
				| a1: mode.transfer := A1CopyBGRA8888
				| a8: mode.transfer := A8CopyBGRA8888
				| p8: mode.transfer := P8CopyBGRA8888
				| d8: mode.transfer := D8CopyBGRA8888
				| p16: mode.transfer := P16CopyBGRA8888	(*PH090122*)
				| bgr555, bgr565, bgr466: mode.transfer := Any16CopyBGRA8888
				| bgr888:  	IF SSE2enabled THEN mode.transfer := SSE2BGR888CopyBGRA8888
							ELSE mode.transfer :=BGR888CopyBGRA8888;
							END;
				| bgra8888: mode.transfer := Copy32
				ELSE mode.transfer := AnyCopyBGRA8888
				END
			ELSE
				CASE src.code OF
				| a1: mode.transfer := A1CopyAny
				| p8: mode.transfer := P8CopyAny
				| d8: mode.transfer := D8CopyAny
				| bgr555, bgr565, bgr466,p16: mode.transfer := Any16CopyAny
				| bgr888: mode.transfer := BGR888CopyAny
				| bgra8888: mode.transfer := BGRA8888CopyAny
				ELSE
					IF (src.bpp MOD 8 = 0) & (dst.bpp MOD 8 = 0) THEN mode.transfer := AnyBytesCopyAnyBytes
					ELSE mode.transfer := AnyCopyAny
					END
				END
			END

		ELSIF op = dstOverSrc THEN
			mode.transfer := EmptyTransfer

		ELSIF op = srcOverDst THEN
			CASE dst.code OF
			| a1:
				CASE src.code OF
				| a1: mode.transfer := A1OverA1
				| a8: mode.transfer := A8OverA1
				| bgra8888: mode.transfer := BGRA8888OverA1
				ELSE mode.transfer := AnyOverA1
				END
			| a8:
				CASE src.code OF
				| a1: mode.buf[0] := 0FFX; mode.transfer := A1OverConst8
				| a8: mode.transfer := A8OverA8
				| bgra8888: mode.transfer := BGRA8888OverA8
				ELSE mode.transfer := AnyOverA8
				END
			| bgra8888:
				CASE src.code OF
				| a1: mode.buf := mode.col; mode.transfer := A1OverConst32
				| a8: mode.buf := mode.col; mode.transfer := A8OverAny
				ELSE mode.transfer := BGRA8888OverAny
				END
			ELSE
				CASE src.code OF
				| a1:
					CASE dst.code OF
					| p8:
						mode.buf[0] := CHR(CLUTs.Match(dst.pal.clut, ORD(mode.col[b]) + ASH(ORD(mode.col[g]), 8) +
							ASH(ORD(mode.col[r]), 16)));
						mode.transfer := A1OverConst8
					| d8:
						mode.buf[0] := CHR(ColorToIndex(ORD(mode.col[b]) + ASH(ORD(mode.col[g]), 8) +
							ASH(ORD(mode.col[r]), 16)));
						mode.transfer := A1OverConst8
					| p16: (* this is probably not correct ... *)
						mode.buf[0] := CHR(PaletteIndex(dst.pal, ORD(mode.col[r]), ORD(mode.col[g]), ORD(mode.col[b])));
						mode.transfer := A1OverConst16
					| bgr555, bgr565, bgr466: dst.pack(dst, ADDRESSOF(mode.buf[0]), 0, mode.col); mode.transfer := A1OverConst16
					| bgr888: mode.buf := mode.col; mode.transfer := A1OverConst24
					ELSE mode.transfer := A1OverAny
					END
				| a8: mode.buf := mode.col; mode.transfer := A8OverAny
				| bgra8888:
					CASE dst.code OF
					| bgr555, bgr466, p16: mode.transfer := BGRA8888OverAny16
					| bgr565 : IF MMXenabled THEN
							mode.transfer := MMXBGRA8888Over565;
							IF SSE2enabled THEN mode.transfer := SSE2BGRA8888Over565; END;
						ELSE mode.transfer := BGRA8888Over565
						END
					ELSE mode.transfer := BGRA8888OverAny
					END
				ELSE
					mode.transfer := AnyBlendAny
				END
			END
		ELSE
			mode.transfer := AnyBlendAny
		END;

		ASSERT(mode.transfer # NIL, 120)
	END Bind;


	(**--- Image Operations ---**)

	(** get pixel from image **)
	PROCEDURE Get* (img: Image; x, y: LONGINT; VAR pix: Pixel; VAR mode: Mode);
		VAR bit: LONGINT; adr: ADDRESS;
	BEGIN
		ASSERT((0 <= x) & (x < img.width) & (0 <= y) & (y < img.height), 100);
		bit := x * img.fmt.bpp; adr := img.adr + y * img.bpr + bit DIV 8; bit := bit MOD 8;
		Bind(mode, img.fmt, PixelFormat);
		(*mode.transfer(mode, adr, bit, ADDRESSOF(pix), 0, 1)*)

		mode.transfer(mode, adr, bit, ADDRESSOF(pix[0]), 0, 1) (*PH090122*)
	END Get;

	(** put pixel into image **)
	PROCEDURE Put* (img: Image; x, y: LONGINT; pix: Pixel; VAR mode: Mode);
		VAR bit: LONGINT; adr: ADDRESS;
	BEGIN
		(*ASSERT((0 <= x) & (x < img.width) & (0 <= y) & (y < img.height), 100);*) (*avoid a HALT if roundoff errors from higher levels occur here*)
		IF (0 > x) OR (x >= img.width) OR (0 > y) & (y >= img.height) THEN RETURN END;
		bit := x * img.fmt.bpp; adr := img.adr + y * img.bpr + bit DIV 8; bit := bit MOD 8;
		Bind(mode, PixelFormat, img.fmt);
		mode.transfer(mode, ADDRESSOF(pix[0]), 0, adr, bit, 1)
	END Put;

	(** fill rectangular area **)
	PROCEDURE Fill* (img: Image; llx, lly, urx, ury: LONGINT; pix: Pixel; VAR mode: Mode);
		VAR bit, bb, x, c, t: LONGINT; m: Mode; adr, aa: ADDRESS;
		PROCEDURE Fill16(destAdr: ADDRESS; size: SIZE; filler: LONGINT);
		CODE {SYSTEM.AMD64}
			MOV RDI, [RBP + destAdr]
			MOV RCX, [RBP + size]
			MOV EAX, [RBP + filler]
			CLD
			REP STOSW
		END Fill16;

	BEGIN
		ASSERT((0 <= llx) & (llx < urx) & (urx <= img.width) & (0 <= lly) & (lly < ury) & (ury <= img.height), 100);
		bit := llx * img.fmt.bpp; adr := img.adr + lly * img.bpr + bit DIV 8; bit := bit MOD 8;

		IF (mode.op = srcCopy) & (img.fmt.code IN {bgr565}) THEN (* shortcut for speed in important cases *)
			c := ASH(ORD(pix[b]), -3) + ASH(ASH(ORD(pix[g]), -2), 5) + ASH(ASH(ORD(pix[r]), -3), 11);
			t := urx - llx;
			WHILE lly < ury DO
				Fill16(adr, t, c);
				INC(lly); INC(adr, img.bpr)
			END
		ELSE

			Bind(mode, PixelFormat, img.fmt);
			IF (mode.op IN {clear, srcCopy}) OR (pix[a] = 0FFX) & (mode.op IN {srcOverDst, dstWithoutSrc}) THEN	(* dst is replaced *)
				(* copy one pixel to lower left corner of rect *)
				mode.transfer(mode, ADDRESSOF(pix[0]), 0, adr, bit, 1);

				(* copy pixel to rest of bottom row *)
				InitMode(m, srcCopy); Bind(m, img.fmt, img.fmt);
				IF (bit = 0) & (img.fmt.bpp MOD 8 = 0) THEN	(* use simple address calculation *)
					bb := img.fmt.bpp DIV 8; aa := adr + bb; x := llx+1;
					WHILE x < urx DO
						m.transfer(m, adr, 0, aa, 0, 1);
						INC(aa, bb); INC(x)
					END
				ELSE
					bb := bit + img.fmt.bpp; aa := adr + bb DIV 8; bb := bb MOD 8; x := llx+1;
					WHILE x < urx DO
						m.transfer(m, adr, bit, aa, bb, 1);
						bb := bb + img.fmt.bpp; aa := aa + bb DIV 8; bb := bb MOD 8; INC(x)
					END
				END;

				(* now copy bottom row to others *)
				INC(lly); aa := adr + img.bpr;
				WHILE lly < ury DO
					m.transfer(m, adr, bit, aa, bit, urx - llx);
					INC(lly); INC(aa, img.bpr)
				END

			ELSE	(* fill pixel by pixel *)
				WHILE lly < ury DO
					x := llx; aa := adr; bb := bit;
					WHILE x < urx DO
						mode.transfer(mode, ADDRESSOF(pix[0]), 0, aa, bb, 1);
						bb := bb + img.fmt.bpp; aa := aa + bb DIV 8; bb := bb MOD 8; INC(x)
					END;
					INC(lly); INC(adr, img.bpr)
				END
			END
		END
	END Fill;

	(** clear image **)
	PROCEDURE Clear* (img: Image);
		VAR mode: Mode;
	BEGIN
		InitMode(mode, clear);
		Bind(mode, PixelFormat, img.fmt);
		Fill(img, 0, 0, img.width, img.height, Zero, mode)
	END Clear;

	(** get several pixels and store them in array in requested format **)
	PROCEDURE GetPixels* (img: Image; x, y, w: LONGINT; VAR fmt: Format; VAR buf: ARRAY OF CHAR; ofs : LONGINT; VAR mode: Mode);
		VAR sbit: LONGINT; sadr: ADDRESS;
	BEGIN
		ASSERT((0 <= x) & (x + w <= img.width) & (0 <= y) & (y <= img.height), 100);
		ASSERT(ofs + w * fmt.bpp DIV 8 <= LEN(buf), 101);
		Bind(mode, img.fmt, fmt);
		sbit := x * img.fmt.bpp; sadr := img.adr + y * img.bpr + sbit DIV 8; sbit := sbit MOD 8;
		mode.transfer(mode, sadr, sbit, ADDRESSOF(buf[ofs]), 0, w)
	END GetPixels;

	(** put several pixels from array in given format into image **)
	PROCEDURE PutPixels* (img: Image; x, y, w: LONGINT; VAR fmt: Format; VAR buf: ARRAY OF CHAR; ofs : LONGINT; VAR mode: Mode);
		VAR dbit: LONGINT; dadr: ADDRESS;
	BEGIN
		ASSERT((0 <= x) & (x + w <= img.width) & (0 <= y) & (y <= img.height), 100);
		ASSERT(ofs + w * fmt.bpp DIV 8 <= LEN(buf), 101);
		dbit := x * img.fmt.bpp; dadr := img.adr + y * img.bpr + dbit DIV 8; dbit := dbit MOD 8;
		Bind(mode, fmt, img.fmt);
		mode.transfer(mode, ADDRESSOF(buf[ofs]), 0, dadr, dbit, w)
	END PutPixels;

	(** copy rectangular area to the same or another image in specified mode **)
	PROCEDURE Copy* (src, dst: Image; llx, lly, urx, ury, dx, dy: LONGINT; VAR mode: Mode);
		VAR w, h, sbit, dbit, slen, sb, db, len, l: LONGINT; sadr, dadr, sa, da: ADDRESS;
	BEGIN
		ASSERT((0 <= llx) & (llx <= urx) & (urx <= src.width) & (0 <= lly) & (lly <= ury) & (ury <= src.height), 100);
		ASSERT((0 <= dx) & (dx + urx - llx <= dst.width) & (0 <= dy) & (dy + ury - lly <= dst.height), 101);
		Bind(mode, src.fmt, dst.fmt);
		w := urx - llx; h := ury - lly;
		IF (src # dst) OR (lly > dy) OR (lly = dy) & ((llx > dx) OR (urx <= dx)) THEN	(* copy lines bottom-up *)
			sbit := llx * src.fmt.bpp; sadr := src.adr + lly * src.bpr + sbit DIV 8; sbit := sbit MOD 8;
			dbit := dx * dst.fmt.bpp; dadr := dst.adr + dy * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			WHILE h > 0 DO
				mode.transfer(mode, sadr, sbit, dadr, dbit, w);
				INC(sadr, src.bpr); INC(dadr, dst.bpr); DEC(h)
			END
		ELSIF lly < dy THEN	(* copy lines top-down *)
			sbit := llx * src.fmt.bpp; sadr := src.adr + ury * src.bpr + sbit DIV 8; sbit := sbit MOD 8;
			dbit := dx * dst.fmt.bpp; dadr := dst.adr + (dy + h) * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			WHILE h > 0 DO
				DEC(sadr, src.bpr); DEC(dadr, dst.bpr); DEC(h);
				mode.transfer(mode, sadr, sbit, dadr, dbit, w)
			END
		ELSIF llx # dx THEN	(* uh oh! overlapping spans *)
			slen := dx + w - urx;	(* maximal span length guaranteeing non-overlapping spans *)
			sbit := urx * src.fmt.bpp; sadr := src.adr + lly * src.bpr + sbit DIV 8; sbit := sbit MOD 8;
			dbit := (dx + w) * dst.fmt.bpp; dadr := dst.adr + dy * dst.bpr + dbit DIV 8; dbit := dbit MOD 8;
			WHILE h > 0 DO
				sa := sadr; sb := sbit; da := dadr; db := dbit; len := w;
				WHILE len > 0 DO
					l := slen;
					IF l > len THEN l := len END;
					DEC(sb, l * src.fmt.bpp); INC(sa, sb DIV 8); sb := sb MOD 8;
					DEC(db, l * dst.fmt.bpp); INC(da, db DIV 8); db := db MOD 8;
					mode.transfer(mode, sa, sb, da, db, l);
					DEC(len, l)
				END;
				INC(sadr, src.bpr); INC(dadr, dst.bpr); DEC(h)
			END
		END
	END Copy;

	(** replicate pattern within rectangular area of image using given mode **)
	PROCEDURE FillPattern* (pat, dst: Image; llx, lly, urx, ury, px, py: LONGINT; VAR mode: Mode);
		VAR pw, ph, olx, oby, ilx, olw, irw, dy, sy, dx, sx, ty: LONGINT;
	BEGIN
		ASSERT((0 <= llx) & (llx <= urx) & (urx <= dst.width) & (0 <= lly) & (lly <= ury) & (ury <= dst.height), 100);
		pw := pat.width; ph := pat.height;
		olx := px + (llx - px) DIV pw * pw;
		oby := py + (lly - py) DIV ph * ph;
		ilx := olx + pw; olw := llx - olx;
		irw := (urx - px) MOD pw;
		IF urx - irw < ilx THEN irw := olw + urx - llx END;
		dy := lly; sy := lly - oby;
		IF (oby < lly) & (oby + ph <= ury) THEN
			dx := llx; sx := olw;
			IF (olx < llx) & (ilx <= urx) THEN
				Copy(pat, dst, sx, sy, pw, ph, llx, lly, mode);
				dx := ilx; sx := 0
			END;
			WHILE dx + pw <= urx DO
				Copy(pat, dst, 0, sy, pw, ph, dx, lly, mode);
				INC(dx, pw)
			END;
			IF dx < urx THEN
				Copy(pat, dst, sx, sy, irw, ph, dx, lly, mode)
			END;
			dy := oby + ph; sy := 0
		END;
		WHILE dy + ph <= ury DO
			dx := llx; sx := olw;
			IF (olx < llx) & (ilx <= urx) THEN
				Copy(pat, dst, sx, 0, pw, ph, llx, dy, mode);
				dx := ilx; sx := 0
			END;
			WHILE dx + pw <= urx DO
				Copy(pat, dst, 0, 0, pw, ph, dx, dy, mode);
				INC(dx, pw)
			END;
			IF dx < urx THEN
				Copy(pat, dst, sx, 0, irw, ph, dx, dy, mode)
			END;
			INC(dy, ph)
		END;
		IF dy < ury THEN
			ty := sy + ury - dy;
			dx := llx; sx := olw;
			IF (olx < llx) & (ilx <= urx) THEN
				Copy(pat, dst, sx, sy, pw, ty, llx, dy, mode);
				dx := ilx; sx := 0
			END;
			WHILE dx + pw <= urx DO
				Copy(pat, dst, 0, sy, pw, ty, dx, dy, mode);
				INC(dx, pw)
			END;
			IF dx < urx THEN
				Copy(pat, dst, sx, sy, irw, ty, dx, dy, mode)
			END
		END
	END FillPattern;

	(** darken image while maintaining coverage **)
	PROCEDURE Darken* (img: Image; factor: REAL);
		VAR s, i, j, k, y, x, bit: LONGINT; adr: ADDRESS; clamp: ARRAY 256 OF CHAR; pix: Pixel;
	BEGIN
		s := ABS(ENTIER(255*factor + 0.5));
		IF (s # 255) & (img.fmt.components # {alpha}) THEN
			i := 256; j := 256*s;
			REPEAT
				DEC(i); DEC(j, s); k := j DIV 255;
				IF k <= 255 THEN clamp[i] := CHR(k) ELSE clamp[i] := 0FFX END
			UNTIL i = 0;
			y := 0;
			WHILE y < img.height DO
				x := 0; adr := img.adr + y * img.bpr; bit := 0;
				WHILE x < img.width DO
					img.fmt.unpack(img.fmt, adr, bit, pix);
					pix[r] := clamp[ORD(pix[r])]; pix[g] := clamp[ORD(pix[g])]; pix[b] := clamp[ORD(pix[b])];
					img.fmt.pack(img.fmt, adr, bit, pix);
					bit := bit + img.fmt.bpp; INC(adr, bit); bit := bit MOD 8;
					INC(x)
				END;
				INC(y)
			END
		END
	END Darken;

	(** fade image **)
	PROCEDURE Fade* (img: Image; factor: REAL);
		VAR s, i, j, k, y, x, bit: LONGINT; adr: ADDRESS; clamp: ARRAY 256 OF CHAR; pix: Pixel;
	BEGIN
		s := ABS(ENTIER(255*factor + 0.5));
		IF s = 0 THEN
			Clear(img)
		ELSIF s # 255 THEN
			i := 256; j := 256*s;
			REPEAT
				DEC(i); DEC(j, s); k := j DIV 255;
				IF k <= 255 THEN clamp[i] := CHR(k) ELSE clamp[i] := 0FFX END
			UNTIL i = 0;
			y := 0;
			WHILE y < img.height DO
				x := 0; adr := img.adr + y * img.bpr; bit := 0;
				WHILE x < img.width DO
					img.fmt.unpack(img.fmt, adr, bit, pix);
					pix[r] := clamp[ORD(pix[r])]; pix[g] := clamp[ORD(pix[g])];
					pix[b] := clamp[ORD(pix[b])]; pix[a] := clamp[ORD(pix[a])];
					img.fmt.pack(img.fmt, adr, bit, pix);
					bit := bit + img.fmt.bpp; INC(adr, bit); bit := bit MOD 8;
					INC(x)
				END;
				INC(y)
			END
		END
	END Fade;

	(** make image brighter and more transparent; Opaque(I, f) = Darken(Fade(I, f), 1/f) **)
	PROCEDURE Opaque* (img: Image; factor: REAL);
		VAR s, i, j, k, y, x, bit: LONGINT; adr: ADDRESS; clamp: ARRAY 256 OF CHAR; pix: Pixel;
	BEGIN
		s := ABS(ENTIER(255*factor + 0.5));
		IF s = 0 THEN
			Clear(img)
		ELSIF s # 255 THEN
			i := 256; j := 256*s;
			REPEAT
				DEC(i); DEC(j, s); k := j DIV 255;
				IF k <= 255 THEN clamp[i] := CHR(k) ELSE clamp[i] := 0FFX END
			UNTIL i = 0;
			y := 0;
			WHILE y < img.height DO
				x := 0; adr := img.adr + y * img.bpr; bit := 0;
				WHILE x < img.width DO
					img.fmt.unpack(img.fmt, adr, bit, pix);
					pix[a] := clamp[ORD(pix[a])];
					img.fmt.pack(img.fmt, adr, bit, pix);
					bit := bit + img.fmt.bpp; INC(adr, bit); bit := bit MOD 8;
					INC(x)
				END;
				INC(y)
			END
		END
	END Opaque;

	(** add components of two (faded) images **)
	PROCEDURE Add* (i, j, res: Image);
		VAR y, x, ibit, jbit, rbit, k: LONGINT; iadr, jadr, radr: ADDRESS; ipix, jpix, rpix: Pixel;
	BEGIN
		ASSERT((i.width = j.width) & (i.height = j.height) & (i.width <= res.width) & (i.height <= res.height), 100);
		y := 0;
		WHILE y < i.height DO
			x := 0; iadr := i.adr + y * i.bpr; ibit := 0; jadr := j.adr + y * j.bpr; jbit := 0; radr := res.adr + y * res.bpr; rbit := 0;
			WHILE x < i.width DO
				i.fmt.unpack(i.fmt, iadr, ibit, ipix); j.fmt.unpack(j.fmt, jadr, jbit, jpix);
				FOR k := 0 TO 3 DO
					rpix[k] := Clamp[ORD(ipix[k]) + ORD(jpix[k])]
				END;
				res.fmt.pack(res.fmt, radr, rbit, rpix);
				ibit := ibit + i.fmt.bpp; INC(iadr, ibit); ibit := ibit MOD 8;
				jbit := jbit + j.fmt.bpp; INC(jadr, jbit); jbit := jbit MOD 8;
				rbit := rbit + res.fmt.bpp; INC(radr, rbit); rbit := rbit MOD 8;
				INC(x)
			END;
			INC(y)
		END
	END Add;

	(** copy image to another using error diffusion dithering (Floyd-Steinberg) **)
	PROCEDURE Dither* (src, dst: Image);
		TYPE
			error = RECORD r, g, b: LONGINT END;
		VAR
			e351: POINTER TO ARRAY OF error;
			y, x, sb, db, ex, e, e3, e5: LONGINT;
			sadr, dadr, sa, da: ADDRESS;
			e7, e51, e1: error;
			spix, dpix: Pixel;
	BEGIN
		ASSERT((src.width <= dst.width) & (src.height <= dst.height), 100);
		NEW(e351, src.width+2);	(* accumulated error for next row *)
		y := 0; sadr := src.adr; dadr := dst.adr;
		WHILE y < src.height DO 	(* scan from left to right *)
			e7.r := 0; e7.g := 0; e7.b := 0;
			e51.r := 0; e51.g := 0; e51.b := 0;
			e1.r := 0; e1.g := 0; e1.b := 0;
			x := 0; sa := sadr; sb := 0; da := dadr; db := 0;
			WHILE x < src.width DO
				ex := x+1;
				src.fmt.unpack(src.fmt, sa, sb, spix);
				spix[r] := Clamp[200H + ORD(spix[r]) + e351[ex].r + e7.r];
				spix[g] := Clamp[200H + ORD(spix[g]) + e351[ex].g + e7.g];
				spix[b] := Clamp[200H + ORD(spix[b]) + e351[ex].b + e7.b];
				dst.fmt.pack(dst.fmt, da, db, spix);
				dst.fmt.unpack(dst.fmt, da, db, dpix);
				e := ORD(spix[r]) - ORD(dpix[r]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
				e7.r := 7*e DIV 16; e351[x].r := e3 + e51.r; e51.r := e5 + e1.r; e1.r := e - e3 - e5 - e7.r;
				e := ORD(spix[g]) - ORD(dpix[g]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
				e7.g := 7*e DIV 16; e351[x].g := e3 + e51.g; e51.g := e5 + e1.g; e1.g := e - e3 - e5 - e7.g;
				e := ORD(spix[b]) - ORD(dpix[b]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
				e7.b := 7*e DIV 16; e351[x].b := e3 + e51.b; e51.b := e5 + e1.b; e1.b := e - e3 - e5 - e7.b;
				sb := sb + src.fmt.bpp; INC(sa, sb DIV 8); sb := sb MOD 8;
				db := db + dst.fmt.bpp; INC(da, db DIV 8); db := db MOD 8;
				x := ex
			END;
			INC(y); INC(sadr, src.bpr); INC(dadr, dst.bpr);
			IF y < src.height THEN	(* scan from right to left *)
				e351[x] := e51;
				e7.r := 0; e7.g := 0; e7.b := 0;
				e51.r := 0; e51.g := 0; e51.b := 0;
				e1.r := 0; e1.g := 0; e1.b := 0;
				INC(sa, src.bpr); INC(da, dst.bpr);
				WHILE x > 0 DO
					ex := x; DEC(x);
					sb := sb - src.fmt.bpp; INC(sa, sb DIV 8); sb := sb MOD 8;
					db := db - dst.fmt.bpp; INC(da, db DIV 8); db := db MOD 8;
					src.fmt.unpack(src.fmt, sa, sb, spix);
					spix[r] := Clamp[200H + ORD(spix[r]) + e351[ex].r + e7.r];
					spix[g] := Clamp[200H + ORD(spix[g]) + e351[ex].g + e7.g];
					spix[b] := Clamp[200H + ORD(spix[b]) + e351[ex].b + e7.b];
					dst.fmt.pack(dst.fmt, da, db, spix);
					dst.fmt.unpack(dst.fmt, da, db, dpix);
					INC(ex);
					e := ORD(spix[r]) - ORD(dpix[r]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
					e7.r := 7*e DIV 16; e351[x].r := e3 + e51.r; e51.r := e5 + e1.r; e1.r := e - e3 - e5 - e7.r;
					e := ORD(spix[g]) - ORD(dpix[g]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
					e7.g := 7*e DIV 16; e351[x].g := e3 + e51.g; e51.g := e5 + e1.g; e1.g := e - e3 - e5 - e7.g;
					e := ORD(spix[b]) - ORD(dpix[b]); e3 := 3*e DIV 16; e5 := 5*e DIV 16;
					e7.b := 7*e DIV 16; e351[x].b := e3 + e51.b; e51.b := e5 + e1.b; e1.b := e - e3 - e5 - e7.b
				END;
				e351[1] := e51;
				INC(y); INC(sadr, src.bpr); INC(dadr, dst.bpr)
			END
		END
	END Dither;


	(**--- File I/O ---**)

	(** write image to file rider **)
	PROCEDURE Write* (VAR fr: Streams.Writer; img: Image);
	VAR m: Image; h, w, len: LONGINT; adr, aa: ADDRESS; buf: ARRAY 256 OF CHAR;
			SrcCopy:Mode;
	BEGIN
		InitMode(SrcCopy, srcCopy);
		IF ~(img.fmt.code IN {a1..bgra8888,p16}) THEN
			NEW(m);
			IF img.fmt.components = {color} THEN Create(m, img.width, img.height, BGR888)
			ELSIF img.fmt.components = {alpha} THEN Create(m, img.width, img.height, A8)
			ELSIF img.fmt.components = {index} THEN Create(m, img.width, img.height, D8)
			ELSE Create(m, img.width, img.height, BGRA8888)
			END;
			Copy(img, m, 0, 0, img.width, img.height, 0, 0, SrcCopy);
			img := m
		END;
		fr.RawNum(2);	(* version *)
		fr.RawNum(img.fmt.code);
		fr.RawNum(img.width); fr.RawNum(img.height);
		fr.RawNum(ABS(img.bpr));
		h := img.height; adr := img.adr;
		WHILE h > 0 DO
			w := ABS(img.bpr); aa := adr;
			WHILE w > 0 DO
				len := 256;
				IF len > w THEN len := w END;
				SYSTEM.MOVE(aa, ADDRESSOF(buf[0]), len);
				fr.Bytes(buf, 0, len);
				DEC(w, len); INC(aa, len)
			END;
			DEC(h); INC(adr, img.bpr)
		END;
		IF img.fmt.code IN {p8,p16} THEN
			fr.RawNum(img.fmt.pal.used);
			len := 0;
			WHILE len < img.fmt.pal.used DO
				fr.Char(img.fmt.pal.col[len, r]);
				fr.Char(img.fmt.pal.col[len, g]);
				fr.Char(img.fmt.pal.col[len, b]);
				INC(len)
			END
		END;
		fr.Update	(* optional *)
	END Write;

	(** read image from file rider **)
	PROCEDURE Read* (VAR fr: Streams.Reader; img: Image);
		VAR ver, code, w, h, bpr, len, bytesRead: LONGINT; adr, aa: ADDRESS; fmt: Format; buf: ARRAY 256 OF CHAR; used: LONGINT;
	BEGIN
		ASSERT(img#NIL,100);
		fr.RawNum(ver);	(* know version 1&2*)
		ASSERT(ver IN {1,2},101);
		fr.RawNum(code);
		CASE code OF
		| a1: fmt := A1
		| a8: fmt := A8
		| p8: InitFormat(fmt, p8, 8, 1, {index}, NIL, PackP8, UnpackP8)
		| d8: fmt := D8
		| p16: InitFormat(fmt, p16, 16, 2, {index}, NIL, PackP16, UnpackP16);
		| bgr555: fmt := BGR555
		| bgr565: fmt := BGR565
		| bgr466: fmt := BGR466
		| bgr888: fmt := BGR888
		| bgra8888: fmt := BGRA8888
		END;
		fr.RawNum(w); fr.RawNum(h);
		Create(img, SHORT(w), SHORT(h), fmt);
		fr.RawNum(bpr);
		ASSERT(bpr <= img.bpr);
		adr := img.adr;
		WHILE h > 0 DO
			w := bpr; aa := adr;
			WHILE w > 0 DO
				len := 256;
				IF len > w THEN len := w END;
				fr.Bytes(buf, 0, len, bytesRead);	(* ignore bytesRead *)
				SYSTEM.MOVE(ADDRESSOF(buf[0]), aa, len);
				DEC(w, len); INC(aa, len)
			END;
			DEC(h); INC(adr, img.bpr)
		END;
		IF code IN {p8,p16} THEN
			fr.RawNum(used);
			len := 0;
			NEW(img.fmt.pal); img.fmt.pal.Init(used);
			WHILE len < used DO
				fr.Char(img.fmt.pal.col[len, r]);
				fr.Char(img.fmt.pal.col[len, g]);
				fr.Char(img.fmt.pal.col[len, b]);
				img.fmt.pal.col[len, a] := 0FFX;
				INC(len)
			END;
			InitPalette(img.fmt.pal, used, 4)
		END
	END Read;

	(*--- Initialization ---*)

	PROCEDURE InitBitTables;
		VAR b, i: LONGINT;
	BEGIN
		FOR b := 0 TO 0FFH DO
			FOR i := 0 TO 7 DO
				IF ODD(ASH(b, -i)) THEN
					Bit[b, i] := TRUE; Set[b, i] := CHR(b); Clr[b, i] := CHR(b - ASH(1, i))
				ELSE
					Bit[b, i] := FALSE; Set[b, i] := CHR(b + ASH(1, i)); Clr[b, i] := CHR(b)
				END
			END
		END
	END InitBitTables;

	PROCEDURE InitClamp;
		VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 1FFH DO Clamp[i] := 0X END;
		FOR i := 0 TO 0FFH DO Clamp[200H+i] := CHR(i) END;
		FOR i := 300H TO 4FFH DO Clamp[i] := 0FFX END
	END InitClamp;

	PROCEDURE ToggleMMX*;
	BEGIN
		MMXenabled := ~MMXenabled
	END ToggleMMX;

	PROCEDURE ToggleSSE2*;
	BEGIN
		SSE2enabled := ~SSE2enabled;
		KernelLog.String("SSE2 toggled! Is now: ");  KernelLog.Boolean(SSE2enabled);KernelLog.Ln;
	END ToggleSSE2;

	(** Map a color value to an 8-bit CLUT index.  Only used if format = index8. *)
	PROCEDURE ColorToIndex*(col: LONGINT): LONGINT;
	BEGIN
			(* default implementation is not very useful and should be overridden. *)
		RETURN SYSTEM.VAL(LONGINT,
				SYSTEM.VAL(SET, ASH(col, 7-23)) * {5..7} +
				SYSTEM.VAL(SET, ASH(col, 4-15)) * {2..4} +
				SYSTEM.VAL(SET, ASH(col, 1-7)) * {0..1})
	END ColorToIndex;

	(** Map an 8-bit CLUT index to a color value.  Only used if format = index8. *)
	PROCEDURE IndexToColor*(index: LONGINT): LONGINT;
	BEGIN
			(* default implementation is not very useful and should be overridden. *)
		RETURN
				ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, index) * {5..7}), 23-7) +
				ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, index) * {2..4}), 15-4) +
				ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, index) * {0..1}), 7-1)
	END IndexToColor;

BEGIN
	MMXenabled := 23 IN Machine.features;
	SSE2enabled := Machine.SSE2Support;
(*	plugin := Displays.registry.Await("");	(* assume only one system-wide D8 display driver *)
	d8display := plugin(Displays.Display); *)
	InitFormat(A1, a1, 1, 1, {alpha}, NIL, PackA1, UnpackA1);
	InitFormat(A8, a8, 8, 1, {alpha}, NIL, PackA8, UnpackA8);
	InitFormat(D8, d8, 8, 1, {index}, NIL, PackD8, UnpackD8);
	InitFormat(BGR555, bgr555, 16, 2, {color}, NIL, PackBGR555, UnpackBGR555);
	InitFormat(BGR565, bgr565, 16, 2, {color}, NIL, PackBGR565, UnpackBGR565);
	InitFormat(BGR466, bgr466, 16, 2, {color}, NIL, PackBGR466, UnpackBGR466);
	InitFormat(BGR888, bgr888, 24, 4, {color}, NIL, PackBGR888, UnpackBGR888);
	InitFormat(BGRA8888, bgra8888, 32, 4, {color, alpha}, NIL, PackBGRA8888, UnpackBGRA8888);
	PixelFormat := BGRA8888;
	Zero[0] := 0X; Zero[1] := 0X; Zero[2] := 0X; Zero[3] := 0X;
	InitBitTables; InitClamp
END Raster.

(**
Remarks

1. Images
While many applications wish to handle images of any kind without having to care about details, other applications need low-level access to image interna for maximum effiency. With this in mind, the Images module provides an abstract procedural interface but also discloses low-level information to those clients needing it:
	* an image references a contiguous block of memory holding pixel data
	* the point of reference is the address of the pixel in the lower-left corner
	* pixels are organized in rows (either bottom-up or top-down)
	* rows can be aligned to an arbitrary number of bytes
	* the leftmost pixel in a row has the lowest address of all pixels in that row
	* every pixel uses the same number of bits
Memory for images can be automatically allocated by using Create(). Alternatively, an image can be initialized on an existing memory block (Init(), InitBuf()) or even on part of an other image (InitRect()).

2. Pixels
A general pixel pix[] contains four components (in range 0X..255X), specifying red, green, blue, and alpha value of the pixel and accessable as pix[r], pix[g], pix[b] and pix[a]. Note that in order to speed up compositing operations, the alpha value is premultiplied into the color components. Example: a red pixel with 50% coverage can be initialized with SetRGBA(pix, 255, 0, 0, 127), after which pix[r]=pix[a]=7FX and pix[g]=pix[b]=0X. Use GetRGBA() to recover the original color and alpha values.

3. Palettes
Many bitmap images and Oberon display drivers use some kind of indexed format to store colors, i.e. the value stored in the bitmap serves as an index into an array of colors. A Palette stores up to 256 colors as an array of pixels, making the mapping of an index to the corresponding color straightforward. To speed up the inverse mapping from an RGB triple to an index with PaletteIndex(), additional data is initialized when InitPalette() is called. Use ComputePalette() to compute a palette that best approximates the colors in a given image (e.g. before quantizing it to indexed format).

4. Formats
While general pixels accurately describe color and alpha information, they use a lot of memory (32 bits). Most images therefore only store part of that information. A Format record describes how pixels are represented within an image. It contains
	* the number of bits used per pixel (must be 1, 2, 4, 8, 16, 24 or 32)
	* the set of components stored in a pixel (color, index and/or alpha)
	* a palette if the format uses one
	* procedures for storing (packing) and loading (unpacking) a general pixel
The pack and unpack procedures are given an address and a bit number specifying where the pixel is located in memory, with bit numbers ascending from left to right (although a format is free to choose any bit ordering within a pixel).

5. Predefined Formats
The following global variables contain formats which are special and have a unique code number identifying them. Besides, most operations have better performance if acting on images using them.
	* A1 (code a1): one bit alpha, MSB leftmost (corresponds to Oberon display patterns)
	* A8 (code a8): 8 bit alpha (mainly for anti-aliased character patterns)
	* - (code p8): 8 bit indexed with custom palette (Oberon pictures, use InitPaletteFormat to initialize)
	* D8 (code d8): 8 bit indexed with display palette (no palette structure attached)
	* - (code p16): 16 bit indexed with 16bit Palette. This type is, e.g.,  often used in medical imaging (DICOM-3 standard) (*PH 2004*)
	* BGR555 (code bgr555), BGR565 (code bgr565), BGR466 (code bgr466): 16 bit hi-color
	* BGR888 (code bgr888): 24 bit true-color
	* BGRA8888 (code bgra8888), PixelFormat: 32 bit true-color with alpha channel (general pixel format)
Procedure DisplayFormat() returns the format that best matches the supplied kind of display transfer format. The returned image format is preferably used for allocating shadow bitmaps.

6. Compositing
Most operations require a transfer mode for specifying how source and destination pixels should be combined when alpha information is present. The following compositing operations are supported:
	* clear: destination becomes black and completely transparent
	* srcCopy: source completely replaces destination (cf. Display.replace)
	* dstCopy: no effect
	* srcOverDst: source replaces destination where source is opaque (cf. Display.paint)
	* dstOverSrc: destination replaces source where destination is opaque
	* srcInDst: source where destination is opaque
	* dstInSrc: destination where source is opaque
	* srcWithoutDest*: source is cleared where destination is opaque
	* dstWithoutSrc*: destination is cleared where source is opaque
	* srcAtopDst*: source replaces destination where destination is opaque
	* dstAtopSrc*: destination replaces source where source is opaque
	* srcXorDst*: destination is cleared where both source and destination are opaque (cf. Display.invert)
A transfer mode is initialized with a compositing operation and optionally with a color. (The color is used when the source is a pure alpha format which doesn't contain any color of its own.) An initialized mode can be bound to a source and destination format by calling Bind(), by which the mode's transfer procedure is set appropriately. A transfer procedure unpacks pixels from source and destination, blends them according to the compositing operation, and packs the resulting pixel in the destination. Bind() chooses an optimal transfer procedure for the given combination of compositing operation, source format, and destination format.

7. Internalization and Externalization
Images can be loaded from file and stored to file using one of many popular image file formats. The Load() and Store() procedures rely on a section 'ImageFormats' in the Aos registry. This section contains a list of file types that are associated with command procedures. When one of these commands is called, it should initialize the global 'LoadProc' and 'StoreProc' variables. These, when called, should read an image from or write an image to the file and set 'done' to TRUE if successful.
**)

