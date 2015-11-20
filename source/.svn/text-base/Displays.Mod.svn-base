(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Displays; (** AUTHOR "pjm"; PURPOSE "Abstract display device driver"; *)

IMPORT SYSTEM, Plugins;

CONST
		(** formats for Transfer.  value = bytes per pixel. *)
	index8* = 1; color565* = 2; color888* = 3; color8888* = 4;

		(** operations for Transfer. *)
	get* = 0; set* = 1;

		(** color components. *)
	red* = 00FF0000H; green* = 0000FF00H; blue* = 000000FFH;

	trans* = LONGINT(80000000H);	(** transparency for Mask. *)
	invert* = 40000000H;	(** inverting. *)
	(*alpha = 0C0000000H;	(** alpha blending. *)*)

	BufSize = 65536;
VAR
	reverse*:BOOLEAN;

TYPE
	Display* = OBJECT (Plugins.Plugin)
		VAR
			width*, height*: LONGINT;	(** dimensions of visible display. *)
			offscreen*: LONGINT;	(** number of non-visible lines at the bottom of the display. *)
			format*: LONGINT;	(** format for Transfer. *)
			unit*: LONGINT;	(** approximate square pixel size = unit/36000 mm. *)
			fbadr-: ADDRESS; fbsize-, fbstride-: LONGINT; (** frame buffer address, size and stride *)

		(** Transfer a block of pixels in "raw" display format to (op = set) or from (op = get) the display.  Pixels in the rectangular area are transferred from left to right and top to bottom.  The pixels are transferred to or from "buf", starting at "ofs".  The line byte increment is "stride", which may be positive, negative or zero. *)
		PROCEDURE Transfer*(VAR buf: ARRAY OF CHAR; ofs, stride, x, y, w, h, op: LONGINT);
		VAR bufadr, buflow, bufhigh, dispadr,w0,b,d: ADDRESS;
		BEGIN
			IF w > 0 THEN
				ASSERT(fbadr # 0);
				bufadr := ADDRESSOF(buf[ofs]);
				dispadr := fbadr + y * fbstride + x * format;
				IF reverse THEN
				dispadr := fbadr + (height-y-1) * fbstride + (width-x-1) * format;
				END;
				
				ASSERT((dispadr >= fbadr) & ((y+h-1)*fbstride + (x+w-1)*format <=  fbsize));	(* display index check *)
				w := w * format;	(* convert to bytes *)
				CASE op OF
					set:
						IF reverse THEN
						WHILE h > 0 DO
							w0 := w DIV format; b:= bufadr; d := dispadr;
							WHILE w0 > 0 DO
								SYSTEM.MOVE(b, d, format);
								INC(b,format);
								DEC(d, format);
								DEC(w0);
							END;
							INC(bufadr, stride); DEC(dispadr, fbstride);
							DEC(h)
						END
						ELSE
						WHILE h > 0 DO
							SYSTEM.MOVE(bufadr, dispadr, w);
							INC(bufadr, stride); INC(dispadr, fbstride);
							DEC(h)
						END
						END;
					|get:
						IF reverse THEN
						buflow := ADDRESSOF(buf[0]); bufhigh := buflow + LEN(buf);
						WHILE h > 0 DO
							ASSERT((bufadr >= buflow) & (bufadr+w <= bufhigh));	(* index check *)
							w0 := w DIV format; b:= bufadr; d := dispadr;
							WHILE w0 > 0 DO
								SYSTEM.MOVE(d, b, format);
								INC(b,format);
								DEC(d, format);
								DEC(w0);
							END;
							INC(bufadr, stride); DEC(dispadr, fbstride);
							DEC(h)
						END;
						ELSE
						buflow := ADDRESSOF(buf[0]); bufhigh := buflow + LEN(buf);
						WHILE h > 0 DO
							ASSERT((bufadr >= buflow) & (bufadr+w <= bufhigh));	(* index check *)
							SYSTEM.MOVE(dispadr, bufadr, w);
							INC(bufadr, stride); INC(dispadr, fbstride);
							DEC(h)
						END;
						END;
					ELSE (* skip *)
				END
			END
		END Transfer;

		(** Fill a rectangle in color "col". *)
		PROCEDURE Fill*(col, x, y, w, h: LONGINT);
		BEGIN
			Fill0(SELF, col, x, y, w, h)
		END Fill;

		(** Equivalent to Fill(col, x, y, 1, 1). *)
		PROCEDURE Dot*(col, x, y: LONGINT);
		BEGIN
			Fill(col, x, y, 1, 1)
		END Dot;

		(** Transfer a block of pixels from a 1-bit mask to the display.  Pixels in the rectangular area are transferred from left to right and top to bottom.  The pixels are transferred from "buf", starting at bit offset "bitofs".  The line byte increment is "stride", which may be positive, negative or zero. "fg" and "bg" specify the colors for value 1 and 0 pixels respectively. *)
		PROCEDURE Mask*(VAR buf: ARRAY OF CHAR; bitof, stride, fg, bg, x, y, w, h: LONGINT);
		CONST SetSize = MAX (SET) + 1;
		VAR p: ADDRESS; i, bitofs: LONGINT; s: SET;
		BEGIN
			IF (w > 0) & (h > 0) THEN
				i := ADDRESSOF(buf[0]) MOD SIZEOF (SET);
				bitofs := bitof + i * 8;
				p := ADDRESSOF(buf[0])-i + bitofs DIV SetSize * SIZEOF (SET);	(* p always aligned to 32-bit boundary *)
				bitofs := bitofs MOD SetSize; stride := stride*8;
				LOOP
					SYSTEM.GET(p, s); i := bitofs;
					LOOP
						IF (i MOD SetSize) IN s THEN
							IF fg >= 0 THEN Dot(fg, SHORT(x+i-bitofs), y) END
						ELSE
							IF bg >= 0 THEN Dot(bg, SHORT (x+i-bitofs), y) END
						END;
						INC(i);
						IF i-bitofs = w THEN EXIT END;
						IF i MOD SetSize = 0 THEN SYSTEM.GET(p+i DIV 8, s) END
					END;
					DEC(h);
					IF h = 0 THEN EXIT END;
					INC(y); INC(bitofs, stride);
					IF (bitofs >= SetSize) OR (bitofs < 0) THEN	(* moved outside s *)
						INC(p, bitofs DIV SetSize * SIZEOF (SET)); bitofs := bitofs MOD SetSize
					END
				END
			END
		END Mask;

		(** Copy source block sx, sy, w, h to destination dx, dy.  Overlap is allowed. *)
		PROCEDURE Copy*(sx, sy, w, h, dx, dy: LONGINT);
		BEGIN
			Copy0(SELF, sx, sy, w, h, dx, dy)
		END Copy;

		(** Update the visible display (if caching is used). *)
		PROCEDURE Update*;
		END Update;

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

		(** Initialize a linear frame buffer for Transfer. *)
		PROCEDURE InitFrameBuffer*(adr: ADDRESS; size, stride: LONGINT);
		BEGIN
			ASSERT((height+offscreen)*stride <= size);
			fbadr := adr; fbsize := size; fbstride := stride;
		END InitFrameBuffer;

(*
		(** Draw a line. *)
		PROCEDURE Line*(col, x1, y1, x2, y2: LONGINT);	(* error term, major, minor? *)
		BEGIN
			HALT(99)
		END Line;

		(* Like Mask, but replicate the mask in the specified rectangular area. *)
		PROCEDURE ReplMask*(VAR buf: ARRAY OF CHAR; bitofs, stride, fg, bg, px, py, pw, ph, x, y, w, h: LONGINT);
		BEGIN
			HALT(99)
		END ReplMask;
*)

		(** Finalize the display.  Further calls to display methods are not allowed, and may cause exceptions. *)
		PROCEDURE Finalize*;
		BEGIN	(* should really be exclusive with Transfer, but we assume the caller keeps to the rules above *)
			fbadr := 0; fbsize := 0
		END Finalize;

	END Display;

VAR
	registry*: Plugins.Registry;
	buf: POINTER TO ARRAY OF CHAR;

PROCEDURE Fill0(d: Display; col, x, y, w, h: LONGINT);
VAR j, w0, h0, s: LONGINT; p: ADDRESS; t, c: SET; invert: BOOLEAN;
BEGIN {EXCLUSIVE}
	IF (w > 0) & (h > 0) & (col >= 0) THEN	(* opaque or invert *)
		invert := ASH(col, 1) < 0;
		IF buf = NIL THEN NEW(buf, BufSize) END;
		CASE d.format OF
			index8:
				s := 4; col := d.ColorToIndex(col);
				c := SYSTEM.VAL(SET, ASH(col, 24) + ASH(col, 16) + ASH(col, 8) + col)
			|color565:
				s := 4;
				col := SYSTEM.VAL(LONGINT,
						SYSTEM.VAL(SET, ASH(col, 15-23)) * {11..15} +
						SYSTEM.VAL(SET, ASH(col, 10-15)) * {5..10} +
						SYSTEM.VAL(SET, ASH(col, 4-7)) * {0..4});
				c := SYSTEM.VAL(SET, ASH(col MOD 10000H, 16) + col MOD 10000H)
			|color888:
				s := 3; c := SYSTEM.VAL(SET, col MOD 1000000H)
			|color8888:
				s := 4; c := SYSTEM.VAL(SET, col MOD 1000000H)
		END;
		w0 := w*d.format; h0 := (LEN(buf^)-3) DIV w0;	(* -3 for 32-bit loops below *)
		ASSERT(h0 > 0);
		IF h < h0 THEN h0 := h END;
		IF ~invert THEN
			p := ADDRESSOF(buf[0]);
			FOR j := 0 TO (w0*h0-1) DIV s DO SYSTEM.PUT32(p, c); INC(p, s) END
		ELSE
			IF c = {} THEN c := {0..31} END
		END;
		LOOP
			IF invert THEN
				d.Transfer(buf^, 0, w0, x, y, w, h0, get);
				p := ADDRESSOF(buf[0]);
				FOR j := 0 TO (w0*h0-1) DIV s DO
					t := SYSTEM.VAL (SET, SYSTEM.GET32(p)); SYSTEM.PUT32(p, t / c); INC(p, s)
				END
			END;
			d.Transfer(buf^, 0, w0, x, y, w, h0, set);
			DEC(h, h0);
			IF h <= 0 THEN EXIT END;
			INC(y, h0);
			IF h < h0 THEN h0 := h END
		END
	END
END Fill0;

PROCEDURE Copy0(d: Display; sx, sy, w, h, dx, dy: LONGINT);
VAR w0, h0, s: LONGINT;
BEGIN {EXCLUSIVE}
	IF (w > 0) & (h > 0) THEN
		IF buf = NIL THEN NEW(buf, BufSize) END;
		w0 := w*d.format; h0 := LEN(buf^) DIV w0;
		ASSERT(h0 > 0);
		IF (sy >= dy) OR (h <= h0) THEN
			s := 1
		ELSE
			s := -1; INC(sy, h-h0); INC(dy, h-h0)
		END;
		LOOP
			IF h < h0 THEN
				IF s = -1 THEN INC(sy, h0-h); INC(dy, h0-h) END;
				h0 := h
			END;
			d.Transfer(buf^, 0, w0, sx, sy, w, h0, get);
			d.Transfer(buf^, 0, w0, dx, dy, w, h0, set);
			DEC(h, h0);
			IF h <= 0 THEN EXIT END;
			INC(sy, s*h0); INC(dy, s*h0)
		END
	END
END Copy0;

PROCEDURE Reverse*;
BEGIN
	reverse := ~reverse;
END Reverse;

BEGIN
	NEW(registry, "Displays", "Display drivers");
	buf := NIL;
	reverse := FALSE;
END Displays.

(**
o The display origin (0,0) is at the top left.
o The display is "width" pixels wide and "height" pixels high.
o The offscreen area is a possibly empty extension below the visible display.  Its height is "offscreen" pixels.
o Rectangles are specified with the top left corner as pinpoint.
o No clipping is performed.
o The offset and stride parameters must always specify values inside the supplied buffer (otherwise results undefined).
o Accessing coordinates outside the display space (including offscreen) is undefined.
o "Undefined" in this case means a trap could occur, or garbage can be displayed, but memory will never be corrupted.
o Colors are 888 truecolor values represented in RGB order with B in the least significant byte.  The top 2 bits of a 32-bit color value are used for flags.  The other bits are reserved.
o The "invert" flag means the destination color is inverted with the given color.  The effect is implementation-defined, but must be reversible with the same color.  Usually an XOR operation is performed.
o The "trans" flag means the color is transparent and drawing in this color has no effect.  It is defined for Mask only.
o The transfer "format" should be chosen close to the native framebuffer format for efficiency.
o Transfer uses raw framebuffer values, and does not support color flags.
o A concrete Display must implement at least the Transfer function, or initialize a linear frame buffer and call the InitFrameBuffer method.
o An optimized Display driver should override all the primitives with accellerated versions.
o An "index8" display uses a fixed palette and map a truecolor value to an equivalent color in the palette.
o The palette can be chosen freely by a concrete 8-bit Display, which should override the ColorToIndex and IndexToColor methods.  These methods are not defined for other formats.
o The default ColorToIndex method assumes a direct-mapped palette with 3 bits each for red and green, and 2 bits for blue.
o Palette animation is not supported.
*)
