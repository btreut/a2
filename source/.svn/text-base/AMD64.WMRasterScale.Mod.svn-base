MODULE WMRasterScale;	(** AUTHOR "TF"; PURPOSE "Support scaling of images"; *)
(** AUTHOR "MZ"; PURPOSE "Speedup rasterops with SSE2"; *)

IMPORT
	SYSTEM, Raster, Rect := WMRectangles;

CONST
	(** Copy Modes *)
	ModeCopy* = 0; ModeSrcOverDst* = 1;

	(** Scale Modes *)
	ScaleBox* = 0; ScaleBilinear* = 1;

TYPE
	Rectangle = Rect.Rectangle;
	Image = Raster.Image;
	ScalerProc = PROCEDURE (src, dst : Image; VAR dr : Rectangle; sx, sy, sdx, sdy : LONGINT);
	XScalerProc = PROCEDURE (srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);

(* copy sr in 16.16 fix rectangle  from src to dr integer rectangle in dst *)
PROCEDURE Q0GenericCopy(src, dst : Image; VAR dr : Rectangle; sx, sy, sdx, sdy : LONGINT);
VAR x, y : LONGINT; col : Raster.Pixel;
	getMode, putMode : Raster.Mode;
	fx, fy : LONGINT;
BEGIN
	Raster.InitMode(getMode, Raster.srcCopy);
	Raster.InitMode(putMode, Raster.srcCopy);
	fy := sy;
	FOR y := dr.t TO dr.b - 1 DO
		fx := sx;
		FOR x := dr.l TO dr.r - 1 DO
			Raster.Get(src, fx DIV 65536, fy DIV 65536, col, getMode);
			INC(fx, sdx);
			Raster.Put(dst, x, y, col, putMode)
		END;
		INC(fy, sdy)
	END
END Q0GenericCopy;

PROCEDURE Q0GenericSrcOverDst(src, dst : Image; VAR dr : Rectangle; sx, sy, sdx, sdy : LONGINT);
VAR x, y : LONGINT; col : Raster.Pixel;
	getMode, putMode : Raster.Mode;
	fx, fy : LONGINT;
BEGIN
	Raster.InitMode(getMode, Raster.srcCopy);
	Raster.InitMode(putMode, Raster.srcOverDst);
	fy := sy;
	FOR y := dr.t TO dr.b - 1 DO
		fx := sx;
		FOR x := dr.l TO dr.r - 1 DO
			Raster.Get(src, fx DIV 65536, fy DIV 65536, col, getMode);
			INC(fx, sdx);
			Raster.Put(dst, x, y, col, putMode)
		END;
		INC(fy, sdy)
	END
END Q0GenericSrcOverDst;

(* copy sr in 16.16 fix rectangle  from src to dr integer rectangle in dst *)
PROCEDURE Q1GenericCopy(src, dst : Image; VAR dr : Rectangle; sx, sy, sdx, sdy : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; col, col0, col1, col2, col3 : Raster.Pixel;
	b0, g0, r0, a0, b1, g1, r1, a1, cb, cg, cr, ca : LONGINT;
	getMode, putMode : Raster.Mode;
	fx, fy : LONGINT; x0, x1, y0, y1 : LONGINT;
BEGIN
	Raster.InitMode(getMode, Raster.srcCopy);
	Raster.InitMode(putMode, Raster.srcCopy);
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dr.t TO dr.b - 1 DO
		fx := sx; y0 := Bounds(fy DIV 65536, 0, src.height - 1); y1 := Bounds(fy DIV 65536 + 1, 0, src.height - 1);
		FOR x := dr.l TO dr.r - 1 DO
			x0 := Bounds(fx DIV 65536, 0, src.width - 1); x1 := Bounds(fx DIV 65536 + 1, 0, src.width - 1);
			Raster.Get(src, x0, y0, col0, getMode);
			Raster.Get(src, x1, y0, col1, getMode);
			Raster.Get(src, x0, y1, col2, getMode);
			Raster.Get(src, x1, y1, col3, getMode);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);

			b0 := (ORD(col0[Raster.b]) * xfleft + ORD(col1[Raster.b]) * xfright) DIV 65536;
			g0 := (ORD(col0[Raster.g]) * xfleft + ORD(col1[Raster.g]) * xfright) DIV 65536;
			r0 := (ORD(col0[Raster.r]) * xfleft + ORD(col1[Raster.r]) * xfright) DIV 65536;
			a0 := (ORD(col0[Raster.a]) * xfleft + ORD(col1[Raster.a]) * xfright) DIV 65536;

			b1 := (ORD(col2[Raster.b]) * xfleft + ORD(col3[Raster.b]) * xfright) DIV 65536;
			g1 := (ORD(col2[Raster.g]) * xfleft + ORD(col3[Raster.g]) * xfright) DIV 65536;
			r1 := (ORD(col2[Raster.r]) * xfleft + ORD(col3[Raster.r]) * xfright) DIV 65536;
			a1 := (ORD(col2[Raster.a]) * xfleft + ORD(col3[Raster.a]) * xfright) DIV 65536;

			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
			cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
			cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
			ca := (a0 * yftop + a1 * yfbottom) DIV 65536;

			col[Raster.b] := CHR(cb);
			col[Raster.g] := CHR(cg);
			col[Raster.r] := CHR(cr);
			col[Raster.a] := CHR(ca);
			INC(fx, sdx);
			Raster.Put(dst, x, y, col, putMode)
		END;
		INC(fy, sdy)
	END
END Q1GenericCopy;

(* copy sr in 16.16 fix rectangle  from src to dr integer rectangle in dst *)
PROCEDURE Q1GenericSrcOverDst(src, dst : Image; VAR dr : Rectangle; sx, sy, sdx, sdy : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; col, col0, col1, col2, col3 : Raster.Pixel;
	b0, g0, r0, a0, b1, g1, r1, a1, cb, cg, cr, ca : LONGINT;
	getMode, putMode : Raster.Mode;
	fx, fy : LONGINT; x0, x1, y0, y1 : LONGINT;
BEGIN
	Raster.InitMode(getMode, Raster.srcCopy);
	Raster.InitMode(putMode, Raster.srcOverDst);
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dr.t TO dr.b - 1 DO
		fx := sx; y0 := Bounds(fy DIV 65536, 0, src.height - 1); y1 := Bounds(fy DIV 65536 + 1, 0, src.height - 1);
		FOR x := dr.l TO dr.r - 1 DO
			x0 := Bounds(fx DIV 65536, 0, src.width - 1); x1 := Bounds(fx DIV 65536 + 1, 0, src.width - 1);
			Raster.Get(src, x0, y0, col0, getMode);
			Raster.Get(src, x1, y0, col1, getMode);
			Raster.Get(src, x0, y1, col2, getMode);
			Raster.Get(src, x1, y1, col3, getMode);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);

			b0 := (ORD(col0[Raster.b]) * xfleft + ORD(col1[Raster.b]) * xfright) DIV 65536;
			g0 := (ORD(col0[Raster.g]) * xfleft + ORD(col1[Raster.g]) * xfright) DIV 65536;
			r0 := (ORD(col0[Raster.r]) * xfleft + ORD(col1[Raster.r]) * xfright) DIV 65536;
			a0 := (ORD(col0[Raster.a]) * xfleft + ORD(col1[Raster.a]) * xfright) DIV 65536;

			b1 := (ORD(col2[Raster.b]) * xfleft + ORD(col3[Raster.b]) * xfright) DIV 65536;
			g1 := (ORD(col2[Raster.g]) * xfleft + ORD(col3[Raster.g]) * xfright) DIV 65536;
			r1 := (ORD(col2[Raster.r]) * xfleft + ORD(col3[Raster.r]) * xfright) DIV 65536;
			a1 := (ORD(col2[Raster.a]) * xfleft + ORD(col3[Raster.a]) * xfright) DIV 65536;

			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
			cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
			cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
			ca := (a0 * yftop + a1 * yfbottom) DIV 65536;

			col[Raster.b] := CHR(cb);
			col[Raster.g] := CHR(cg);
			col[Raster.r] := CHR(cr);
			col[Raster.a] := CHR(ca);
			INC(fx, sdx);
			Raster.Put(dst, x, y, col, putMode)
		END;
		INC(fy, sdy)
	END
END Q1GenericSrcOverDst;

(*
PROCEDURE Q0BGR565BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y : LONGINT; yadr, adr, sa, col : LONGINT;
	fx, fy : LONGINT;
BEGIN
	fy := sy;
	yadr := dstadr + dl * 2 + dt * dstbpr;
	FOR y := dt TO db - 1 DO
		fx := sx;
		adr := yadr;
		sa := srcadr + (fy DIV 65536) * srcbpr;
		FOR x := dl TO dr - 1 DO
			col := SYSTEM.GET16(sa + (fx DIV 65536) * 2);
			INC(fx, sdx);
			SYSTEM.PUT16(adr, col);
			INC(adr, 2);
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q0BGR565BGR565;
*)

(* this asm version is 2.3 times faster than the portable version. (P3/600/Dell precision 420 (dual)) *)
PROCEDURE XQ0BGR565BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR yadr : LONGINT;
(*
CODE {SYSTEM.i386}
	MOV	EDX, dstadr[EBP]
	MOV	EBX, dl[EBP]
	SHL	EBX, 1
	ADD	EDX, EBX
	MOV	EBX, dt[EBP]
	IMUL	EBX, dstbpr[EBP]
	ADD	EDX, EBX	; edx = dstadr + 2 * dl + dt * dstbpr
	MOV	yadr[EBP], EDX
	; init first EDI
	MOV	EDI, EDX

	MOV	ECX, dt[EBP]
	SUB	db[EBP], ECX	; counter in db

	MOV	EDX, sdx[EBP]	; keep EDX

	; init first ESI
	MOV	ESI, srcadr[EBP]	; calc new source adr
	MOV	EAX, sy[EBP]
	SHR	EAX, 16	; integer part of sy
	IMUL 	EAX, srcbpr[EBP]	; sy * srcbpr
	ADD	ESI, EAX	; first source adr in ESI

outerloop:
	MOV	EBX, sx[EBP]
	MOV	ECX, dr[EBP]	; FOR x := dl TO dr - 1 DO
	SUB	ECX, dl[EBP]
innerloop:
	MOV	EAX, EBX
	SHR	EAX, 16
	MOV	AX, WORD PTR [ESI + EAX * 2]	; read the pixel
	ADD	EBX, EDX	; INC fx, sdx
	MOV	[EDI], AX	; set the pixel
	ADD	EDI, 2	; inc adr
	LOOP	innerloop

	; free : EAX, EBX, ECX
	MOV	EAX, sy[EBP]	; sy := sy + sdy
	ADD	EAX, sdy[EBP]
	MOV	sy[EBP], EAX	; keep sy in EAX

	MOV	ESI, srcadr[EBP]	; calc new source adr
	SHR	EAX, 16	; integer part of sy
	IMUL 	EAX, srcbpr[EBP]	; sy * srcbpr
	ADD	ESI, EAX	; new source adr in ESI

	; new dst address
	MOV	ECX, dstbpr[EBP]
	MOV	EAX, yadr[EBP]
	ADD	EAX, ECX
	MOV	EDI, EAX
	MOV	yadr[EBP], EAX

	DEC	db[EBP]
	JNLE	outerloop
*)
END XQ0BGR565BGR565;


PROCEDURE SSE2Q0BGR565BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT (*; VAR  mysrc, mydest, myres: ARRAY OF LONGINT*));
VAR yadr : LONGINT;
(*
CODE {SYSTEM.i386, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
	PUSHFD
	PUSH 		EBX
	; CLI

	MOV		EDX, dstadr[EBP]
	MOV		EBX, dl[EBP]
	SHL			EBX, 1
	ADD		EDX, EBX
	MOV		EBX, dt[EBP]
	IMUL		EBX, dstbpr[EBP]
	ADD		EDX, EBX	; edx = dstadr + 2 * dl + dt * dstbpr
	MOV		yadr[EBP], EDX

	; init first EDI
	MOV		EDI, EDX

	MOV		ECX, dt[EBP]
	SUB		db[EBP], ECX	; counter in db
	JLE			endyloop
	MOV		EDX, sdx[EBP]	; keep EDX

	; init first ESI
	MOV		ESI, srcadr[EBP]	; calc new source adr
	MOV		EAX, sy[EBP]
	SHR		EAX, 16			; integer part of sy
	IMUL 		EAX, srcbpr[EBP]	; sy * srcbpr
	ADD		ESI, EAX		; first source adr in ESI

outerloop:
	MOV		EBX, sx[EBP]
	MOV		ECX, dr[EBP]	; FOR x := dl TO dr - 1 DO
	SUB		ECX, dl[EBP]
	JLE			endyloop

innerloop:
	CMP 		ECX, 8
	 JLE			singlepixel

	PXOR 		XMM0, XMM0

	; 8pixels at the time
	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,0
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,1
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,2
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,3
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,4
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,5
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,6
	ADD		EBX, EDX			; INC fx, sdx

	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2] ; read the pixel
	PINSRW  	XMM0, EAX,7
	ADD		EBX, EDX			; INC fx, sdx

	MOVDQU 	[EDI], XMM0 		;	MOV	[EDI], AX							; set the pixels
	ADD		EDI, 16				; inc adr
	SUB 		ECX, 8
	CMP 		ECX, 0
	JE			outside2
	; LOOP 	innerloop
	JMP 		innerloop

singlepixel:
	MOV		EAX, EBX
	SHR		EAX, 16
	MOV		AX, WORD PTR [ESI + EAX * 2]	; read the pixel
	ADD		EBX, EDX			; INC fx, sdx
	MOV		[EDI], AX			; set the pixel
	ADD		EDI, 2				; inc adr
	SUB 		ECX, 1
	CMP 		ECX, 0
	JE			outside2
	; LOOP 	innerloop
	JMP 		innerloop

outside2:
	; free : EAX, EBX, ECX
	MOV		EAX, sy[EBP]		; sy := sy + sdy
	ADD		EAX, sdy[EBP]
	MOV		sy[EBP], EAX		; keep sy in EAX

	MOV		ESI, srcadr[EBP]		; calc new source adr
	SHR		EAX, 16				; integer part of sy
	IMUL 		EAX, srcbpr[EBP]	; sy * srcbpr
	ADD		ESI, EAX			; new source adr in ESI

	; new dst address
	MOV		ECX, dstbpr[EBP]
	MOV		EAX, yadr[EBP]
	ADD		EAX, ECX
	MOV		EDI, EAX
	MOV		yadr[EBP], EAX

	DEC		db[EBP]
	JNLE		outerloop

endyloop:
	EMMS 							; declare FPU registers free
	POP 		EBX
	POPFD
*)
END SSE2Q0BGR565BGR565;


PROCEDURE Q1BGR565BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr, adr: ADDRESS; col0, col1, col2, col3  : LONGINT;
	b0, g0, r0, b1, g1, r1, cb, cg, cr : LONGINT;
	fx, fy, xadd1, xadd2 : LONGINT;
	yadd1, yadd2: ADDRESS;
BEGIN

	yadr := dstadr + dl * 2 + dt * dstbpr;
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dt TO db - 1 DO
		fx := sx;
		adr := yadr;
		yadd1 := srcadr + Bounds(fy DIV 65536, 0, sh - 1) * srcbpr;
		yadd2 := srcadr + Bounds(fy DIV 65536 + 1, 0, sh - 1) * srcbpr;
		FOR x := dl TO dr - 1 DO
			xadd1 := Bounds(fx DIV 65536, 0, sw - 1) * 2;
			xadd2 := Bounds(fx DIV 65536 + 1, 0, sw - 1) * 2;
			col0 := SYSTEM.GET16(yadd1 + xadd1);
			col1 := SYSTEM.GET16(yadd1 + xadd2);
			col2 := SYSTEM.GET16(yadd2 + xadd1);
			col3 := SYSTEM.GET16(yadd2 + xadd2);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);

			b0 := ((col0 MOD 32) * 8 * xfleft + (col1 MOD 32) * 8 * xfright) DIV 65536;
			g0 := ((col0 DIV 32 MOD 64) * 4 * xfleft + (col1 DIV 32 MOD 64) * 4 * xfright) DIV 65536;
			r0 := ((col0 DIV 2048 MOD 32) * 8 * xfleft + (col1 DIV 2048 MOD 32) * 8 * xfright) DIV 65536;

			b1 := ((col2 MOD 32) * 8 * xfleft + (col3 MOD 32) * 8 * xfright) DIV 65536;
			g1 := ((col2 DIV 32 MOD 64) * 4 * xfleft + (col3 DIV 32 MOD 64) * 4 * xfright) DIV 65536;
			r1 := ((col2 DIV 2048 MOD 32) * 8 * xfleft + (col3 DIV 2048 MOD 32) * 8 * xfright) DIV 65536;


			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
			cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
			cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
			INC(fx, sdx);
			SYSTEM.PUT16(adr, ASH(cb, -3) + ASH(ASH(cg, -2), 5) + ASH(ASH(cr, -3), 11));
			INC(adr, 2);
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q1BGR565BGR565;

PROCEDURE SSE2Q1BGR565BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
(*
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr, adr, col, col0, col1, col2, col3 : LONGINT;
	b0, g0, r0, b1, g1, r1, cb, cg, cr : LONGINT;
	fx, fy, yadd1, yadd2, xadd1, xadd2 : LONGINT;

CODE {SYSTEM.i386, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
	PUSHFD
	PUSH 		EBX
	; CLI

	; create masks

	; PXOR	XMM2, XMM2
	; PXOR		XMM3, XMM3

	PXOR		XMM4, XMM4
	PXOR		XMM5, XMM5
	PXOR		XMM6, XMM6

	; PXOR		XMM7, XMM7

	; dest red -> XMM4
	; dest green -> XMM5
	; dest blue-> XMM6

	MOV	 	EAX, 0F800H
	MOV	 	EBX, 07E0H
	MOV		ECX, 01FH
	PINSRW	XMM4, EAX,0
	PINSRW	XMM5, EBX,0
	PINSRW	XMM6, ECX,0
	PINSRW	XMM4, EAX,1
	PINSRW	XMM5, EBX,1
	PINSRW	XMM6, ECX,1
	PINSRW	XMM4, EAX,2
	PINSRW	XMM5, EBX,2
	PINSRW	XMM6, ECX,2
	PINSRW	XMM4, EAX,3
	PINSRW	XMM5, EBX,3
	PINSRW	XMM6, ECX,3
;	introallq1(dstadr,dl,dt,dstbpr,sy,yadr,sx,fy);

	MOV		EDX, dstadr[EBP]
	MOV		EBX, dl[EBP]
	SHL			EBX, 1
	ADD		EDX, EBX
	MOV		EBX, dt[EBP]
	IMUL		EBX, dstbpr[EBP]
	ADD		EDX, EBX
	MOV		yadr[EBP], EDX

	MOV		EDX, sy[EBP]
	SUB		EDX, 8000H 			;edx = sy-8000H
	MOV		fy[EBP], EDX

	; sx := sx - 8000H;

	SUB		sx[EBP], 8000H ;edx = sx-8000H

	;FOR y := dt TO db - 1 DO
	MOV		ECX, db[EBP]
	SUB		ECX, dt[EBP]			; counter in y
	JLE			endyloop
	MOV		y[EBP], ECX


outerloop:
	;q1xxall(adr,fx,sw,yadd1,yadd2,yftop,yfbottom,sdx,dr,dl);
	MOV		EDX, yadr[EBP]
	MOV		EDI, EDX 				; adr in EDI
	;MOV	adr[EBP], EDX

	MOV		EDX, sx[EBP]			; keep EDX
	MOV		fx[EBP], EDX


	MOV 		EAX, fy[EBP]
	PINSRW	XMM3, EAX,0 			; prepare for top, bottom

	SAR 		EAX, 16
	CMP 		EAX, 0
	JE			zero
	JL			negativ
	MOV		EBX, sh[EBP]
	SUB		EBX, 1
	CMP		EAX, EBX
	JGE			bigger

ok:
	MOV		EBX, EAX
	ADD		EBX, 1
	JMP 		different

zero:
	MOV 		EAX, 0
	MOV		EBX, 1
	JMP 		different

negativ:
	MOV 		EAX, 0
	MOV		EBX, 0
	JMP			samepixel

bigger:
	MOV		EAX, EBX
	JMP			samepixel

different:
	MOV		ECX, srcbpr[EBP]
	MUL		EAX, ECX
	MOV		EBX, EAX
	ADD		EBX, ECX
	MOV		ECX, srcadr[EBP]
	ADD		EAX, ECX
	ADD		EBX, ECX
	JMP			endyadd

samepixel:
	MOV		ECX, srcbpr[EBP]
	MUL		EAX, ECX
	MOV		ECX, srcadr[EBP]
	ADD		EAX, ECX
	MOV		EBX, EAX

endyadd:
	MOV		yadd1[EBP], EAX
	MOV		yadd2[EBP], EBX

	; yfbottom := (fy MOD 65536);
	; yftop := (65536 - fy MOD 65536);
	PEXTRW	EDX, XMM3,0
	AND		EDX, 0FFFFH
	PINSRW 	XMM3, EDX, 1
	NEG		EDX
	ADD		EDX, 65535
	PINSRW 	XMM3, EDX, 0
	PSRLW 		XMM3, 1

	MOV		ECX, dr[EBP]
	SUB		ECX, dl[EBP]			; counter in y
	JLE			endyloop				;exit
	MOV		x[EBP], ECX

innerloop:
	MOV 		ECX, fx[EBP]

	PINSRW	XMM7, ECX,0 ; prepare for l,r

	SAR 		ECX, 16
	CMP 		ECX, 0
	JE			zerox
	JL			negativx
	MOV		EDX, sw[EBP]
	SUB		EDX, 1
	CMP		ECX, EDX
	JGE			biggerx

okx:
	MOV		EDX, ECX
	ADD		EDX, 1
	JMP			endbound2
zerox:
	MOV 		ECX, 0
	MOV		EDX, 1
	JMP 		endbound2
negativx:
	MOV 		ECX, 0
	MOV		EDX, 0
	JMP			endbound2
biggerx:
	MOV		ECX, EDX
endbound2:
	SHL			ECX, 1
	SHL			EDX, 1
endaddx:
	MOV		EAX, yadd1[EBP]
	MOV		EBX, yadd2[EBP]

	PINSRW	XMM2, [EAX+ECX], 0
	PINSRW	XMM2, [EAX+EDX], 1
	PINSRW	XMM2, [EBX+ECX], 2
	PINSRW	XMM2, [EBX+EDX], 3

	PEXTRW	EAX, XMM7,0
	AND		EAX, 0FFFFH
	PINSRW 	XMM7, EAX,1
	PINSRW	XMM7, EAX, 3
	NEG		EAX
	ADD		EAX, 65535
	PINSRW 	XMM7, EAX, 0
	PINSRW	XMM7, EAX, 2
	PSRLW 		XMM7, 1

	; calculate red
	MOVDQU	XMM0, XMM2
	PAND		XMM0, XMM4

	PSRLW  	XMM0, 8			;SRL16bit XMM0,8

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15
	PSHUFLW	XMM0, XMM0, 58H

	PMADDWD	XMM0, XMM3

	PSRLD		XMM0,7   			; XMM3 already shifted by 1
	PAND		XMM0, XMM4
	PEXTRW 	EBX, XMM0,0

	; red done

; calculate green
	MOVDQU	XMM0, XMM2
	PAND		XMM0, XMM5		;SLL 16bit XMM0, 8
	PSRLW  	XMM0, 3			;SRL16bit XMM0,24

	PMADDWD XMM0,XMM7
	PSRLD		XMM0,15     		; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H

	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,12    			; XMM3 already shifted by 1, 5 more to get correct position

	PAND		XMM0, XMM5
	PEXTRW 	EAX, XMM0,0
	OR			EBX,EAX

	; green done

	; calculate blue
	MOVDQU	XMM0, XMM2
	PAND		XMM0, XMM6
	PSLLW  		XMM0, 3			;SLL16bit XMM0,3

	PMADDWD XMM0,XMM7
	PSRLD		XMM0,15     		; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H

	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,18    			; XMM3 already shifted by 1, 11 more to get correct position

	PAND		XMM0, XMM6
	PEXTRW 	EAX, XMM0,0
	OR			EBX,EAX
	; blue done

	MOV		[EDI], BX

	MOV		ECX, fx[EBP]
	ADD		ECX, sdx[EBP]
	MOV		fx[EBP],ECX

	ADD		EDI, 2				; inc adr

	SUB		x[EBP], 1
	JNZ			innerloop

endxloop:
	MOV		EAX,fy[EBP]			; fy := fy + sdy
	ADD		EAX, sdy[EBP]
	MOV		fy[EBP], EAX

	MOV		EAX,yadr[EBP]
	ADD		EAX, dstbpr[EBP]
	MOV		EDI, EAX
	MOV		yadr[EBP], EAX

	SUB		y[EBP], 1
	JNZ			outerloop

endyloop:
	EMMS 							; declare FPU registers free
	POP 		EBX
	POPFD
*)
END SSE2Q1BGR565BGR565;

PROCEDURE Q1BGRA8888BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr: ADDRESS; col, col0, col1, col2, col3 : LONGINT;
	b0, g0, r0, a0, b1, g1, r1, a1, cb, cg, cr, ca, dstb, dstg, dstr : LONGINT;
	fx, fy, xadd0, xadd1: LONGINT; yadd0, yadd1: ADDRESS;
BEGIN
	yadr := dstadr + dl * 2 + dt * dstbpr;
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dt TO db - 1 DO
		fx := sx;
		dstadr := yadr;
		yadd0 := srcadr + Bounds(fy DIV 65536, 0, sh - 1) * srcbpr;
		yadd1 := srcadr + Bounds(fy DIV 65536 + 1, 0, sh - 1) * srcbpr;
		FOR x := dl TO dr - 1 DO
			(* destination color *)
			col := SYSTEM.GET16(dstadr);
			dstb := (col MOD 32) * 8; dstg := (col DIV 32 MOD 64) * 4; dstr := (col DIV 2048 MOD 32) * 8;
			xadd0 := Bounds(fx DIV 65536, 0, sw - 1) * 4;
			xadd1 := Bounds(fx DIV 65536 + 1, 0, sw - 1) * 4;
			col0 := SYSTEM.GET32(yadd0 + xadd0);
			col1 := SYSTEM.GET32(yadd0 + xadd1);
			col2 := SYSTEM.GET32(yadd1 + xadd0);
			col3 := SYSTEM.GET32(yadd1 + xadd1);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);
			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			a0 := ((col0 DIV 1000000H MOD 100H) * xfleft + (col1 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			a1 := ((col2 DIV 1000000H MOD 100H) * xfleft + (col3 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			ca := (a0 * yftop + a1 * yfbottom) DIV 65536;

			IF ca # 0 THEN
				b0 := ((col0 MOD 100H) * xfleft + (col1 MOD 100H) * xfright) DIV 65536;
				g0 := ((col0 DIV 100H MOD 100H) * xfleft + (col1 DIV 100H MOD 100H) * xfright) DIV 65536;
				r0 := ((col0 DIV 10000H MOD 100H) * xfleft + (col1 DIV 10000H MOD 100H) * xfright) DIV 65536;

				b1 := ((col2 MOD 100H) * xfleft + (col3 MOD 100H) * xfright) DIV 65536;
				g1 := ((col2 DIV 100H MOD 100H) * xfleft + (col3 DIV 100H MOD 100H) * xfright) DIV 65536;
				r1 := ((col2 DIV 10000H MOD 100H) * xfleft + (col3 DIV 10000H MOD 100H) * xfright) DIV 65536;

				cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
				cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
				cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
				IF ca # 255 THEN
					cb := (cb * 256 + (256 - ca) * dstb) DIV 256; IF cb > 256 THEN cb := 256 END;
					cg := (cg * 256 + (256 - ca) * dstg) DIV 256; IF cg > 256 THEN cg := 256 END;
					cr := (cr * 256 + (256 - ca) * dstr) DIV 256; IF cr > 256 THEN cr := 256 END
				END;
				SYSTEM.PUT16(dstadr, ASH(cb, -3) + ASH(ASH(cg, -2), 5) + ASH(ASH(cr, -3), 11))
			END;
			INC(fx, sdx);
			INC(dstadr, 2);
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q1BGRA8888BGR565;

PROCEDURE SSE2Q1BGRA8888BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh:LONGINT);
(*
	VAR x, y, z,xfleft, xfright, yftop, yfbottom : LONGINT; yadr, adr, col, col0, col1, col2, col3 : LONGINT;
	b0, g0, r0, a0, a01,b1, g1, r1, a1, cb, cg, cr,cb2, cg2, cr2, ca, ca2,dstb, dstg, dstr,res : LONGINT;
	fx, fy, yadd1, yadd2, xadd1, xadd2: LONGINT;

CODE {SYSTEM.i386, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
	PUSHFD
	PUSH 		EBX
	; CLI
	PXOR		MM3,MM3
	PXOR		MM4,MM4
	PXOR		MM5, MM5
	PXOR		MM6, MM6
	PXOR		XMM1, XMM1
	PXOR		XMM3, XMM3
	PXOR		XMM4, XMM4
	PXOR		XMM6, XMM6
	PXOR		XMM7, XMM7

	MOV		EDX, dstadr[EBP]
	MOV		EBX, dl[EBP]
	SHL			EBX, 1
	ADD		EDX, EBX
	MOV		EBX, dt[EBP]
	IMUL		EBX, dstbpr[EBP]
	ADD		EDX, EBX
	MOV		yadr[EBP], EDX

	MOV		EDX, sy[EBP]
	SUB		EDX, 8000H 			;edx = sy-8000H
	MOV	 	fy[EBP], EDX

	; sx := sx - 8000H;
	MOV		EDX, sx[EBP]
	SUB		EDX, 8000H 			;sx = sx-8000H
	MOV		sx[EBP] , EDX

	MOV		ECX, db[EBP]
	SUB		ECX, dt[EBP]			; counter in y
	JLE			endyloop				;exit
	MOV		y[EBP], ECX

outerloop:
	MOV		EDX, yadr[EBP]
	MOV		EDI, EDX ; adr in EDI

	MOV		adr[EBP], EDX

	MOV		EDX, sx[EBP]			; keep EDX
	MOV		fx[EBP], EDX

	MOV 		EAX, fy[EBP]
	MOVD		XMM3, EAX 			; prepare for top, bottom
	SAR 		EAX, 16
	CMP 		EAX, 0
	JE			zero
	JL			negativ
	MOV		EBX, sh[EBP]
	SUB		EBX, 1
	CMP		EAX, EBX
	JGE			bigger

ok:
	MOV		EBX, EAX
	ADD		EBX, 1
	JMP 		different

zero:
	MOV 		EAX, 0
	MOV		EBX, 1
	JMP 		different

negativ:
	MOV 		EAX, 0
	MOV		EBX, 0
	JMP			samepixel

bigger:
	MOV		EAX, EBX
	JMP			samepixel

different:
	MOV		ECX, srcbpr[EBP]
	MUL		EAX, ECX
	MOV		EBX, EAX
	ADD		EBX, ECX
	MOV		ECX, srcadr[EBP]
	ADD		EAX, ECX
	ADD		EBX, ECX
	JMP			endyadd

samepixel:
	MOV		ECX, srcbpr[EBP]
	MUL		EAX, ECX
	MOV		ECX, srcadr[EBP]
	ADD		EAX, ECX
	MOV		EBX, EAX

endyadd:
	MOV		yadd1[EBP], EAX
	MOV		yadd2[EBP], EBX

	; yfbottom := (fy MOD 65536);
	; yftop := (65536 - fy MOD 65536);

	MOVD		ECX, XMM3
	AND		ECX, 0FFFFH
	MOV		yfbottom[EBP],ECX
	PINSRW 	XMM3, ECX, 1

	NEG		ECX
	ADD		ECX, 65535
	MOV		yftop[EBP],ECX
	PINSRW 	XMM3, ECX, 0

	PSRLW		XMM3, 1

	MOV		ECX, dr[EBP]
	SUB		ECX, dl[EBP]			; counter in x
	JLE			endyloop				;exit
	MOV		x[EBP], ECX

innerloop:
	MOV 		ECX, x[EBP]
	; if x < 8 then do one pixel at the time
	CMP		ECX, 8
	JL 			singlepixel
	; else
	; take 8 at the time

	MOV		EBX, EDI
	AND 		EBX, 0FH
	CMP		EBX, 0
	JNE	 		singlepixel

alleightpixels:
	MOV	 	EAX, 0000000FFH
	MOVD		MM3, EAX

	; dest red -> MM4
	MOV	 	EAX, 0F800F800H
	MOVD		MM4, EAX

	; dest green -> MM5
	MOV	 	EAX, 07E007E0H
	MOVD		MM5, EAX

	; dest blue -> MM6 ; moved as MM6 is used in singlepixel
	; MOV	 EAX, 001F001FH
	; MOVD		MM6, EAX

	MOV		ECX, yfbottom[EBP]
	PINSRW 	XMM3, ECX, 1
	MOV		ECX, yftop[EBP]
	PINSRW 	XMM3, ECX, 0
	PSRLW 		XMM3,1

	PXOR		XMM5, XMM5
	PXOR 		XMM2,XMM2
	MOV		z[EBP], 4

loop03:
	; shift everything left
	MOV 		ECX, fx[EBP]
	PSLLDQ		XMM5, 4

	PINSRW	XMM7, ECX,0 ; prepare for l,r

	SAR 		ECX, 16
	CMP 		ECX, 0
	JE			zerox03
	JL			negativx03
	MOV		EDX, sw[EBP]
	SUB		EDX, 1
	CMP		ECX, EDX
	JGE			biggerx03

okx03:
	MOV		EDX, ECX
	ADD		EDX, 1
	JMP			endbound203
zerox03:
	MOV 		ECX, 0
	MOV		EDX, 1
	JMP 		endbound203

negativx03:
	MOV 		ECX, 0
	MOV		EDX, 0
	JMP			endbound203

biggerx03:
	MOV		ECX, EDX
endbound203:
	SHL			ECX, 2 					; xadd1
	SHL			EDX, 2 					; xadd2

	MOV		EAX, yadd1[EBP]
	MOV		EBX, yadd2[EBP]

	MOVD		XMM2, [EBX+EDX]
	PSLLDQ   	XMM2,4
	MOVD		XMM1, [EBX+ECX]
	POR		XMM2,XMM1
	PSLLDQ   	XMM2,4
	MOVD		XMM1, [EAX+EDX]
	POR		XMM2,XMM1
	PSLLDQ		XMM2,4
	MOVD		XMM1, [EAX+ECX]
	POR		XMM2,XMM1

	PEXTRW	EAX,XMM7,0
	AND		EAX, 0FFFFH
	PINSRW 	XMM7, EAX,1
	PINSRW	XMM7, EAX, 3 			;xfright

	NEG		AX
	ADD		EAX, 65535
	PINSRW 	XMM7, EAX, 0
	PINSRW	XMM7, EAX, 2 			;xfleft

	PSRLW 		XMM7, 1

	MOVDQU	XMM0, XMM2
	PSRLD		XMM0, 24
	PXOR		XMM1, XMM1

	MOV		ECX, 0FFH 				; ECX locked for ca

	PINSRW	XMM1, ECX,0
	PINSRW	XMM1, ECX,2
	PINSRW	XMM1, ECX,4
	PINSRW	XMM1, ECX,6

	PCMPEQW	XMM1, XMM0

	PMOVMSKB	EAX, XMM1
	CMP		EAX, 0FFFFH
	JE 			endofalpha03

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H
	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW	ECX, XMM0, 0

endofalpha03:
	; alpha done

	CMP		ECX,0
	JE			alphazero03

	SHL			ECX, 24

	; calculate red

	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 8
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0

	SHL	EBX,16
	OR	ECX,EBX

	; red done

	; calculate green
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 16
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0
	SHL 		EBX,8
	OR 			ECX,EBX

	; green done

	; calculate blue
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0,24
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0, XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0

	OR			ECX,EBX
	; blue done

	; put color in correct position
	MOVD		XMM4,ECX
	POR		XMM5, XMM4 ; results in XMM5

	; prepared source

alphazero03: ; set mask is done later
	MOV		ECX,fx[EBP]
	ADD		ECX, sdx[EBP]
	MOV		fx[EBP],ECX

	SUB 		z[EBP], 1
	JNZ 		loop03

endofloop03:
	MOV		z[EBP], 4

loop47:
	; shift everything left
	PSLLDQ		XMM6, 4

	PINSRW	XMM7, ECX,0 ; prepare for l,r

	SAR 		ECX, 16
	CMP 		ECX, 0
	JE			zerox47
	JL			negativx47
	MOV		EDX, sw[EBP]
	SUB		EDX, 1
	CMP		ECX, EDX
	JGE			biggerx47

okx47:
	MOV		EDX, ECX
	ADD		EDX, 1
	JMP			endbound247
zerox47:
	MOV 		ECX, 0
	MOV		EDX, 1
	JMP 		endbound247

negativx47:
	MOV 		ECX, 0
	MOV		EDX, 0
	JMP			endbound247

biggerx47:
	MOV		ECX, EDX
endbound247:
	SHL			ECX, 2 						; xadd1
	SHL			EDX, 2 						; xadd2

	MOV		EAX, yadd1[EBP]
	MOV		EBX, yadd2[EBP]

	MOVD		XMM2, [EBX+EDX]
	PSLLDQ   	XMM2,4
	MOVD		XMM1, [EBX+ECX]
	POR		XMM2,XMM1
	PSLLDQ   	XMM2,4
	MOVD		XMM1, [EAX+EDX]
	POR		XMM2,XMM1
	PSLLDQ		XMM2,4
	MOVD		XMM1, [EAX+ECX]
	POR		XMM2,XMM1

	PEXTRW	EAX,XMM7,0
	AND		EAX, 0FFFFH
	PINSRW 	XMM7, EAX,1
	PINSRW	XMM7, EAX, 3 				;xfright

	NEG		EAX
	ADD		EAX, 65535
	PINSRW 	XMM7, EAX, 0
	PINSRW	XMM7, EAX, 2 				;xfleft

	PSRLW 		XMM7, 1

	MOVDQU	XMM0, XMM2
	PSRLD		XMM0, 24
	PXOR		XMM1, XMM1

	MOV		ECX, 0FFH 					; ECX locked for ca

	PINSRW	XMM1, ECX,0
	PINSRW	XMM1, ECX,2
	PINSRW	XMM1, ECX,4
	PINSRW	XMM1, ECX,6

	PCMPEQW	XMM1, XMM0

	PMOVMSKB	EAX, XMM1
	CMP		EAX, 0FFFFH
	JE 			endofalpha47

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H
	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW	ECX, XMM0, 0

endofalpha47:
	; alpha done
	CMP		ECX,0
	JE			alphazero47

	SHL			ECX, 24

	; calculate red

	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 8
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0

	SHL			EBX,16
	OR			ECX,EBX

	; red done

	; calculate green
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 16
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0
	SHL 		EBX,8
	OR 			ECX,EBX

	; green done

	; calculate blue
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0,24
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 				; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   				; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0

	OR			ECX,EBX

	; blue done

	; put color in correct position
	MOVD		XMM4,ECX
	POR		XMM6, XMM4 			; results in XMM6

	; prepared source

alphazero47: ; set mask is done later
	MOV		ECX,fx[EBP]
	ADD		ECX, sdx[EBP]
	MOV		fx[EBP],ECX

	SUB		 z[EBP], 1
	JNZ 		loop47

endofloop47:
	; all sources calculated, but in reversed order
	PSHUFD 	XMM2,XMM5, 1AH
	PSHUFD 	XMM1,XMM6, 1AH

	; now sources ready for further calculation with destination
	; get alphas
	MOVQ2DQ	XMM4,  MM3
	MOVDQU 	XMM6, XMM2
	PSHUFD		XMM4, XMM4, 0
	MOVDQU 	XMM5, XMM1
	PSLLD 		XMM4, 24
	PAND 		XMM6, XMM4 			; alpha 5-8 in XMM6
	PAND 		XMM5, XMM4  			; alpha 1-4 in XMM5
	PSRLD 		XMM5, 24
	PSHUFHW 	XMM5, XMM5, 85H
	PSRLD 		XMM6, 24

	; put both alphas into 1 register
	PSHUFHW 	XMM6, XMM6, 85H
	PSHUFLW 	XMM5, XMM5, 85H
	PSHUFLW 	XMM6, XMM6, 58H
	PSHUFD		XMM5, XMM5, 0D0H  	; 0102030400000000
	PSHUFD 	XMM6, XMM6, 5CH 		; 0000000005060708
	PXOR 		XMM0,XMM0
	POR		XMM5, XMM6            	; XMM5 = alphas 0102030405060708

	PCMPEQD 	XMM0, XMM5
	PMOVMSKB EAX, XMM0
	CMP 		EAX, 0FFFFH				; all alphas = zero; TEST not possible, because only 8 bits compared
	JE      		endloop

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
	MOVQ2DQ 	XMM3, MM3
	PSHUFD 	XMM3, XMM3, 0
	MOVDQU 	XMM5, XMM1
	MOVDQU 	XMM6, XMM2
	PSLLD 		XMM3, 16

	; sred14 = src14 && (srcMask << 24)
	; src14 must be copied because it mustn't be changed
	PAND 		XMM5, XMM3 				; sred14
	PSRLD 		XMM5, 16

	; sred14s = shuffled sred14
	PSHUFHW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM3 				; sred58
	PSRLD 		XMM6, 16

	PSHUFLW 	XMM5, XMM5,85H
	PSHUFHW 	XMM6, XMM6,85H
	PSHUFD  	XMM5, XMM5,0D0H 		; sred14s
	PSHUFLW 	XMM6, XMM6,58H
	PSHUFD  	XMM6, XMM6,5CH 			; sred58s
	POR 		XMM5, XMM6 				; sred18

	; sred18255 = sred18 * 256- sred18
	MOVDQU 	XMM7, XMM5
	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 				; sred18255

	; src is now ready

	; destination
	; dest18 must be copied because it mustn't be changed
	; Load data into memory
	MOV 		EDI, adr[EBP]
	MOVDQU 	XMM3, [EDI]  				;dest 1-8
	MOVQ2DQ  XMM6, MM4
	PSHUFD 	XMM6, XMM6, 0
	MOVDQU 	XMM7, XMM3

	PAND 		XMM7, XMM6 				; dred18
	PSRLW 		XMM7, 8
	;  dred18alpha = dred18 * negalpha
	PMULLW 	XMM7, XMM4 				; dred18alpha

	; dest is prepared
	; combining dest and src

	; dred18big = sred18255 + dred18alpha

	PADDUSW 	XMM7, XMM5 ; dred18big
	; dred18f = dred18big && destMaskred128  because >> 11 and << 11 is && mask
	PAND 		XMM7, XMM6 ; dred18f

 	; dest18nr0 = dest18 && (~destMaskred128)
 	PANDN 	XMM6, XMM3  				; dest18nr0

 	; dest18nrf = dest18nr0 || dred18f
 	POR 		XMM6, XMM7

	MOVDQU 	XMM3, XMM6

	; red is calculated

	; calculate green:
	; get source

	; sgreen14 = src14 && (srcMask <<8)
	; srcMask << 8
	MOVQ2DQ 	XMM7, MM3

	PSHUFD 	XMM7, XMM7, 0
	MOVDQU 	XMM5, XMM1
	PSLLD 		XMM7, 8
	PAND 		XMM5, XMM7 				; sgreen14
	PSRLD 		XMM5, 8

	; sgreen14s = shuffled sgreen14
	PSHUFHW 	XMM5, XMM5,85H
	MOVDQU 	XMM6, XMM2
	PSHUFLW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM7 				; sgreen58
	PSRLD 		XMM6, 8
	PSHUFD  	XMM5, XMM5,0D0H 		; sgreen14s

	; sgreen58 = src58&& (srcMask << 8)
	; src58 must be copied because it mustn't be changed

	; sgreen58s = shuffled sgreen58
	PSHUFHW 	XMM6, XMM6,85H
	PSHUFLW	XMM6, XMM6,58H
	PSHUFD  	XMM6, XMM6,5CH 			; sgreen58s

	; sgreen18 = sgreen14s || sgreen58s
	POR 		XMM5, XMM6 ; sgreen18

	; sgreen18255 = sgreen18 * 256- sgreen18
	MOVDQU 	XMM7, XMM5
	MOVQ2DQ	XMM6, MM5

	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 				; sgreen18255
	PSHUFD 	XMM6, XMM6, 0

	MOVDQU 	XMM7, XMM3

	PAND 		XMM7, XMM6 ; dgreen18
	PSRLW 		XMM7,3
	;  dgreen18alpha = dgreen18 * negalpha
	PMULLW 	XMM7, XMM4 				; dgreen18alpha

	; dest is prepared
	; combining dest and src

	; dgreen18big = sgreen18255 + dgreen18alpha
	PADDUSW 	XMM7, XMM5 				; dgreen18big
	PANDN 	XMM6, XMM3  ; dest18ng0

	; dgreen18f = (dgreen18big >> 11) <<5
	PSRLW 		XMM7, 10 					; dgreen18f
	PSLLW 		XMM7, 5

 	; dest18ng0 = dest18 && (~destMaskgreen128)

 	; dest18ngf = dest18ng0 || dred18f
 	POR 		XMM6, XMM7
	MOVDQU 	XMM3, XMM6
	; green is calculated

	; calculate blue

	MOV	 	EAX, 001F001FH
	MOVD		MM6, EAX

	; get source

	; sblue14 = src14 && (srcMask)
	; srcMask
	MOVQ2DQ 	XMM7, MM3
	MOVDQU 	XMM5, XMM1

	PSHUFD 	XMM7, XMM7, 0
	MOVDQU 	XMM6, XMM2

	; sblue14 = src14 && (srcMask)
	; src14 must be copied because it mustn't be changed
	PAND 		XMM5, XMM7 				; sblue14

	; sblue14s = shuffled sblue14
	PSHUFHW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM7 ; sblue58
	PSHUFHW 	XMM6, XMM6,85H

	PSHUFLW 	XMM5, XMM5,85H
	PSHUFLW 	XMM6, XMM6,58H

	PSHUFD  	XMM5, XMM5,0D0H 		; sblue14s
	PSHUFD  	XMM6, XMM6,5CH 			; sblue58s

	POR 		XMM5, XMM6 				; sblue18

	; sblue18255 = sblue18 * 256- sblue18
	MOVDQU 	XMM7, XMM5
	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 				; sblue18255
	MOVQ2DQ	XMM6, MM6
	PSHUFD 	XMM6, XMM6, 0
	MOVDQU 	XMM7, XMM3
	PAND 		XMM7, XMM6 				; dblue18
	PSLLW 		XMM7, 3

	PMULLW 	XMM7, XMM4 				; dblue18alpha

	; dest is prepared
	; combining dest and src

	; dblue18big = sblue18255 + dblue18alpha

	PADDUSW 	XMM7, XMM5 				; dblue18big
	; dblue18f = (dblue18big >> 11)
	PANDN 	XMM6, XMM3  				; dest18nr0
 	PSRLW 		XMM7, 11 					; dblue18f

  	; dest18nr0 = dest18 && (~destMaskblue128)

 	; dest18nbf = dest18nb0 || dblue18f
 	POR 		XMM6, XMM7
	MOVDQU 	XMM3, XMM6

	; blue is calculated

	; now dest is calculated, store it
	; get 0 stuff

	MOVDQU	XMM5, [EDI]
	PAND		XMM5,XMM0
	PANDN		XMM0, XMM3
	POR		XMM0, XMM5

	MOVDQU [EDI],XMM0

endloop:
	;fx already inc  ; by sdx
	ADD 		EDI, 16
	MOV 		adr[EBP],EDI
	SUB 		x[EBP], 8
	JNZ 		innerloop 					; x>=0
	JZ 			endxloop

singlepixel: 									; original code from MMXBGRA8888Over565, adjusted to fit this procedure
	MOV 		EDI, adr[EBP]
	MOV	 	EAX, 0000000FFH
	MOVD		MM3, EAX

	; dest red -> MM4
	MOV	 	EAX, 0F800F800H
	MOVD		MM4, EAX

	; dest green -> MM5
	MOV	 	EAX, 07E007E0H
	MOVD		MM5, EAX

	; dest blue -> MM6 ; moved as MM6 is used in singlepixel
	; MOV	 EAX, 001F001FH
	; MOVD		MM6, EAX

	MOV		ECX, yfbottom[EBP]
	PINSRW 	XMM3, ECX, 1
	MOV		ECX, yftop[EBP]
	PINSRW 	XMM3, ECX, 0
	PSRLW 		XMM3,1

	MOV 		ECX, fx[EBP]

	PINSRW	XMM7, ECX,0 				; prepare for l,r

	SAR 		ECX, 16
	CMP 		ECX, 0
	JE			zerox
	JL			negativx
	MOV		EDX, sw[EBP]
	SUB		EDX, 1
	CMP		ECX, EDX
	JGE			biggerx

okx:
	MOV		EDX, ECX
	ADD		EDX, 1
	JMP			endbound2
zerox:
	MOV 		ECX, 0
	MOV		EDX, 1
	JMP 		endbound2

negativx:
	MOV 		ECX, 0
	MOV		EDX, 0
	JMP			endbound2

biggerx:
	MOV		ECX, EDX
endbound2:
	SHL			ECX, 2 						; xadd1
	SHL			EDX, 2 						; xadd2

	MOV		EAX, yadd1[EBP]
	MOV		EBX, yadd2[EBP]

	MOVD		XMM2, [EBX+EDX]
	PSLLDQ   	XMM2,4
	MOVD		XMM1, [EBX+ECX]
	POR		XMM2,XMM1
	PSLLDQ  	XMM2,4
	MOVD		XMM1, [EAX+EDX]
	POR		XMM2,XMM1
	PSLLDQ		XMM2,4
	MOVD		XMM1, [EAX+ECX]
	POR		XMM2,XMM1

	PEXTRW	EAX,XMM7,0
	AND		EAX, 0FFFFH
	PINSRW 	XMM7, EAX,1
	PINSRW	XMM7, EAX, 3 				;xfright

	NEG		EAX
	ADD		EAX, 65535
	PINSRW 	XMM7, EAX, 0
	PINSRW	XMM7, EAX, 2 				;xfleft

	PSRLW 		XMM7, 1

	MOVDQU	XMM0, XMM2
	PSRLD		XMM0, 24
	PXOR		XMM1, XMM1

	MOV		ECX, 0FFH 					; ECX locked for ca

	PINSRW	XMM1, ECX,0
	PINSRW	XMM1, ECX,2
	PINSRW	XMM1, ECX,4
	PINSRW	XMM1, ECX,6

	PCMPEQW	XMM1, XMM0

	PMOVMSKB	EAX, XMM1
	CMP		EAX, 0FFFFH
	JE 			endofalpha

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H
	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 					; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   					; XMM3 already shifted by 1
	PEXTRW	ECX, XMM0, 0

endofalpha:
	; alpha done
	CMP		ECX,0
	JE			alphazero

	; calculate red
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 8
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 					; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   					; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0
	PINSRW	XMM4, EBX, 4
	; red done

	; calculate green
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0, 16
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 					; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   					; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0
	PINSRW	XMM4, EBX, 2

	; green done

	; calculate blue
	MOVDQU	XMM0, XMM2
	PSLLD		XMM0,24
	PSRLD		XMM0, 24

	PSHUFLW	XMM0, XMM0,58H
	PSHUFHW	XMM0, XMM0,58H
	PSHUFD		XMM0,XMM0,58H

	PMADDWD XMM0,XMM7
	PSRLD		XMM0, 15 					; XMM7 already shifted by 1
	PSHUFLW	XMM0, XMM0, 58H
	PMADDWD	XMM0, XMM3
	PSRLD		XMM0,15   					; XMM3 already shifted by 1
	PEXTRW 	EBX, XMM0,0
	PINSRW	XMM4, EBX, 0

	; blue done

	; prepared source
	CMP		ECX, 0FFH   					; ECX released
	JE			alpha255

	NEG		ECX
	ADD		ECX, 0FFH
	PINSRW	XMM1, ECX, 1  				; 255-ca
	PINSRW	XMM1, ECX, 3  				; 255-ca
	PINSRW	XMM1, ECX, 5 				; 255-ca

	MOV		EAX, 0FFH
	PINSRW	XMM1, EAX, 0 				; 255
	PINSRW	XMM1, EAX, 2  				; 255
	PINSRW	XMM1, EAX, 4  				; 255

	;prepare destination
	MOV		EBX, adr[EBP]

	MOV		EBX, [EBX]

	MOV		EAX, EBX
	AND 		EAX, 01FH
	SHL			EAX,3
	PINSRW	XMM4, EAX, 1  				; dstb

	MOV		EAX, EBX
	AND 		EAX, 07E0H
	SHR		EAX, 3
	PINSRW	XMM4, EAX, 3  				; dstg

	AND 		EBX, 0F800H
	SHR		EBX,8
	PINSRW	XMM4, EBX, 5  				; dstr

	PMADDWD	XMM4, XMM1

	PSRLD		XMM4, 8
	PXOR		XMM1,XMM1
	PACKUSWB	XMM4,XMM1

	; put results into their words
	PEXTRW	EAX, XMM4, 2 				; end red
	PINSRW	XMM4,  EAX, 4

	PEXTRW	EAX, XMM4, 1 				; end green
	PINSRW	XMM4,  EAX, 2

alpha255:
	; red in XMM4,4; green in XMM4, 2; blue in XMM4,0
	;SYSTEM.PUT16(adr, ASH(cb, -3) + ASH(ASH(cg, -2), 5) + ASH(ASH(cr, -3), 11))
	PEXTRW	EAX, XMM4, 0 				; end blue
	SHR		EAX,3
	AND		EAX, 001FH

	PEXTRW	EBX, XMM4, 2 				; end green
	SHL			EBX,3
	AND		EBX, 07E0H
	OR			EAX, EBX

	PEXTRW	EBX, XMM4, 4				; end red
	SHL			EBX,8
	AND		EBX, 0F800H
	OR			EAX, EBX

	MOV		EDI,adr[EBP]
	MOV		[EDI], AX

alphazero: 									; alpha = 0, no writeback
	MOV		ECX,fx[EBP]
	ADD		ECX, sdx[EBP]
	MOV		fx[EBP],ECX

	MOV		EDI,adr[EBP]
	ADD		EDI, 2						; inc adr
	MOV		adr[EBP],EDI


	SUB		x[EBP], 1
	JNZ			innerloop

endxloop:
	MOV		EAX,fy[EBP]					; fy := fy + sdy
	ADD		EAX, sdy[EBP]
	MOV		fy[EBP], EAX

	MOV		EAX,yadr[EBP]
	ADD		EAX, dstbpr[EBP]
	;MOV	EDI, EAX
	MOV		yadr[EBP], EAX

	SUB		y[EBP], 1
	JNZ			outerloop

endyloop:
	EMMS									; declare FPU registers free
	POP 		EBX
	POPFD
*)
END SSE2Q1BGRA8888BGR565;

PROCEDURE Q0BGRA8888BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y : LONGINT; yadr, adr: ADDRESS; col, col0 : LONGINT;
	cb, cg, cr, ca, dstb, dstg, dstr: LONGINT; yadd: ADDRESS;
	fx, fy : LONGINT;
BEGIN
	fy := sy;
	yadr := dstadr + dl * 2 + dt * dstbpr;
	FOR y := dt TO db - 1 DO
		fx := sx;
		adr := yadr;
		yadd := srcadr + (fy DIV 65536) * srcbpr;
		FOR x := dl TO dr - 1 DO
			(* destination color *)
			col := SYSTEM.GET16(adr);
			dstb := (col MOD 32) * 8; dstg := (col DIV 32 MOD 64) * 4; dstr := (col DIV 2048 MOD 32) * 8;

			col0 := SYSTEM.GET32(yadd + (fx DIV 65536) * 4);

			ca := (col0 DIV 1000000H MOD 100H);
			IF ca # 0 THEN
				cb := (col0 MOD 100H);
				cg := (col0 DIV 100H MOD 100H);
				cr := (col0 DIV 10000H MOD 100H);

				IF ca # 255 THEN
					cb := (cb * 256 + (256 - ca) * dstb) DIV 256; IF cb > 256 THEN cb := 256 END;
					cg := (cg * 256 + (256 - ca) * dstg) DIV 256; IF cg > 256 THEN cg := 256 END;
					cr := (cr * 256 + (256 - ca) * dstr) DIV 256; IF cr > 256 THEN cr := 256 END
				END;
				SYSTEM.PUT16(adr, ASH(cb, -3) + ASH(ASH(cg, -2), 5) + ASH(ASH(cr, -3), 11))
			END;
			INC(fx, sdx);
			INC(adr, 2)
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q0BGRA8888BGR565;

PROCEDURE Q0BGRA8888BGRA8888(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y : LONGINT; yadr, adr: ADDRESS; col, col0 : LONGINT;
	cb, cg, cr, ca, dstb, dstg, dstr, dsta : LONGINT; yadd: ADDRESS;
	fx, fy : LONGINT;
BEGIN
	fy := sy;
	yadr := dstadr + dl * 4 + dt * dstbpr;
	FOR y := dt TO db - 1 DO
		fx := sx;
		adr := yadr;
		yadd := srcadr + (fy DIV 65536) * srcbpr;
		FOR x := dl TO dr - 1 DO
			(* destination color *)
			col := SYSTEM.GET32(adr);
			dstb := (col MOD 100H);
			dstg := (col DIV 100H) MOD 100H;
			dstr := (col DIV 10000H) MOD 100H;
			dsta := (col DIV 1000000H) MOD 100H;

			col0 := SYSTEM.GET32(yadd + (fx DIV 65536) * 4);

			ca := (col0 DIV 1000000H MOD 100H);
			IF ca # 0 THEN
				cb := (col0 MOD 100H);
				cg := (col0 DIV 100H MOD 100H);
				cr := (col0 DIV 10000H MOD 100H);

				IF ca # 255 THEN
					cb := (cb * 256 + (256 - ca) * dstb) DIV 256; IF cb > 256 THEN cb := 256 END;
					cg := (cg * 256 + (256 - ca) * dstg) DIV 256; IF cg > 255 THEN cg := 256 END;
					cr := (cr * 256 + (256 - ca) * dstr) DIV 256; IF cr > 256 THEN cr := 256 END;
					ca := (ca * 256 + (256 - ca) * dsta) DIV 256; IF ca > 256 THEN ca := 256; END;
				END;

				SYSTEM.PUT32(adr, cb + LSH(cg, 8) + LSH(cr, 16) + LSH(ca, 24));
			END;
			INC(fx, sdx);
			INC(adr, 4)
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q0BGRA8888BGRA8888;

PROCEDURE Q0BGRA8888BGRA8888Copy(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y  : LONGINT; yadr, adr: ADDRESS; col, col0 : LONGINT; yadd : ADDRESS;
	fx, fy : LONGINT;
BEGIN
	fy := sy;
	yadr := dstadr + dl * 4 + dt * dstbpr;
	FOR y := dt TO db - 1 DO
		fx := sx;
		adr := yadr;
		yadd := srcadr + (fy DIV 65536) * srcbpr;
		FOR x := dl TO dr - 1 DO
			col0 := SYSTEM.GET32(yadd + (fx DIV 65536) * 4);
			SYSTEM.PUT32(adr, col0);
			INC(fx, sdx);
			INC(adr, 4)
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q0BGRA8888BGRA8888Copy;

PROCEDURE Q1BGRA8888BGRA8888(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr: ADDRESS; col, col0, col1, col2, col3 : LONGINT;
	b0, g0, r0, a0, b1, g1, r1, a1, cb, cg, cr, ca, dstb, dstg, dstr, dsta : LONGINT;
	fx, fy, xadd0, xadd1: LONGINT; yadd0, yadd1: ADDRESS;
BEGIN
	yadr := dstadr + dl * 4 + dt * dstbpr;
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dt TO db - 1 DO
		fx := sx;
		dstadr := yadr;
		yadd0 := srcadr + Bounds(fy DIV 65536, 0, sh - 1) * srcbpr;
		yadd1 := srcadr + Bounds(fy DIV 65536 + 1, 0, sh - 1) * srcbpr;
		FOR x := dl TO dr - 1 DO
			(* destination color *)
			col := SYSTEM.GET32(dstadr);
			dstb := col MOD 100H;
			dstg := col DIV 100H MOD 100H;
			dstr := col DIV 10000H MOD 100H;
			dsta := col DIV 1000000H MOD 100H;
			xadd0 := Bounds(fx DIV 65536, 0, sw - 1) * 4;
			xadd1 := Bounds(fx DIV 65536 + 1, 0, sw - 1) * 4;
			col0 := SYSTEM.GET32(yadd0 + xadd0);
			col1 := SYSTEM.GET32(yadd0 + xadd1);
			col2 := SYSTEM.GET32(yadd1 + xadd0);
			col3 := SYSTEM.GET32(yadd1 + xadd1);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);
			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			a0 := ((col0 DIV 1000000H MOD 100H) * xfleft + (col1 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			a1 := ((col2 DIV 1000000H MOD 100H) * xfleft + (col3 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			ca := (a0 * yftop + a1 * yfbottom) DIV 65536;

			IF ca # 0 THEN
				b0 := ((col0 MOD 100H) * xfleft + (col1 MOD 100H) * xfright) DIV 65536;
				g0 := ((col0 DIV 100H MOD 100H) * xfleft + (col1 DIV 100H MOD 100H) * xfright) DIV 65536;
				r0 := ((col0 DIV 10000H MOD 100H) * xfleft + (col1 DIV 10000H MOD 100H) * xfright) DIV 65536;
				a0 := ((col0 DIV 1000000H MOD 100H) * xfleft + (col1 DIV 1000000H MOD 100H) * xfright) DIV 65536;

				b1 := ((col2 MOD 100H) * xfleft + (col3 MOD 100H) * xfright) DIV 65536;
				g1 := ((col2 DIV 100H MOD 100H) * xfleft + (col3 DIV 100H MOD 100H) * xfright) DIV 65536;
				r1 := ((col2 DIV 10000H MOD 100H) * xfleft + (col3 DIV 10000H MOD 100H) * xfright) DIV 65536;
				a1 := ((col2 DIV 1000000H MOD 100H) * xfleft + (col3 DIV 1000000H MOD 100H) * xfright) DIV 65536;

				cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
				cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
				cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
				ca := (a0 * yftop + a1 * yfbottom) DIV 65536;
				IF ca # 255 THEN
					cb := (cb * 256 + (256 - ca) * dstb) DIV 256; IF cb > 256 THEN cb := 256 END;
					cg := (cg * 256 + (256 - ca) * dstg) DIV 256; IF cg > 256 THEN cg := 256 END;
					cr := (cr * 256 + (256 - ca) * dstr) DIV 256; IF cr > 256 THEN cr := 256 END;
					ca := (ca * 256 + (256 - ca) * dsta) DIV 256; IF ca > 256 THEN ca := 256; END;
				END;
				SYSTEM.PUT32(dstadr, cb + LSH(cg, 8) + LSH(cr, 16) + LSH(ca, 24));
			END;
			INC(fx, sdx);
			INC(dstadr, 4);
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q1BGRA8888BGRA8888;

PROCEDURE Q1BGRA8888BGRA8888Copy(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr: ADDRESS; col, col0, col1, col2, col3 : LONGINT;
	b0, g0, r0, a0, b1, g1, r1, a1, cb, cg, cr, ca : LONGINT;
	fx, fy, xadd0, xadd1: LONGINT; yadd0, yadd1: ADDRESS;
BEGIN
	yadr := dstadr + dl * 4 + dt * dstbpr;
	fy := sy - 8000H; sx := sx - 8000H;
	FOR y := dt TO db - 1 DO
		fx := sx;
		dstadr := yadr;
		yadd0 := srcadr + Bounds(fy DIV 65536, 0, sh - 1) * srcbpr;
		yadd1 := srcadr + Bounds(fy DIV 65536 + 1, 0, sh - 1) * srcbpr;
		FOR x := dl TO dr - 1 DO
			(* destination color *)
			xadd0 := Bounds(fx DIV 65536, 0, sw - 1) * 4;
			xadd1 := Bounds(fx DIV 65536 + 1, 0, sw - 1) * 4;
			col0 := SYSTEM.GET32(yadd0 + xadd0);
			col1 := SYSTEM.GET32(yadd0 + xadd1);
			col2 := SYSTEM.GET32(yadd1 + xadd0);
			col3 := SYSTEM.GET32(yadd1 + xadd1);

			xfleft := (65536 - fx MOD 65536);
			xfright := (fx MOD 65536);
			yftop := (65536 - fy MOD 65536);
			yfbottom := (fy MOD 65536);
			a0 := ((col0 DIV 1000000H MOD 100H) * xfleft + (col1 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			a1 := ((col2 DIV 1000000H MOD 100H) * xfleft + (col3 DIV 1000000H MOD 100H) * xfright) DIV 65536;
			ca := (a0 * yftop + a1 * yfbottom) DIV 65536;

			IF ca # 0 THEN
				b0 := ((col0 MOD 100H) * xfleft + (col1 MOD 100H) * xfright) DIV 65536;
				g0 := ((col0 DIV 100H MOD 100H) * xfleft + (col1 DIV 100H MOD 100H) * xfright) DIV 65536;
				r0 := ((col0 DIV 10000H MOD 100H) * xfleft + (col1 DIV 10000H MOD 100H) * xfright) DIV 65536;

				b1 := ((col2 MOD 100H) * xfleft + (col3 MOD 100H) * xfright) DIV 65536;
				g1 := ((col2 DIV 100H MOD 100H) * xfleft + (col3 DIV 100H MOD 100H) * xfright) DIV 65536;
				r1 := ((col2 DIV 10000H MOD 100H) * xfleft + (col3 DIV 10000H MOD 100H) * xfright) DIV 65536;

				cb := (b0 * yftop + b1 * yfbottom) DIV 65536;
				cg := (g0 * yftop + g1 * yfbottom) DIV 65536;
				cr := (r0 * yftop + r1 * yfbottom) DIV 65536;
				SYSTEM.PUT32(dstadr, cb + LSH(cg, 8) + LSH(cr, 16) + LSH(ca, 24));
			END;
			INC(fx, sdx);
			INC(dstadr, 4);
		END;
		INC(fy, sdy);
		INC(yadr, dstbpr)
	END
END Q1BGRA8888BGRA8888Copy;

PROCEDURE SSE2Q0BGRA8888BGR565(srcadr, dstadr: ADDRESS; srcbpr, dstbpr, dl, dt, dr, db, sx, sy, sdx, sdy, sw, sh : LONGINT);
(*
VAR x, y, xfleft, xfright, yftop, yfbottom : LONGINT; yadr, adr, col, col0, col1, col2, col3 : LONGINT;
	cb, cg, cr, ca, dstb, dstg, dstr, yadd : LONGINT;
	fx, fy : LONGINT;
	w : LONGINT;

CODE {SYSTEM.i386, SYSTEM.MMX, SYSTEM.SSE, SYSTEM.SSE2}
	PUSHFD
	PUSH 		EBX
	; CLI

	PXOR		MM0, MM0
	PXOR		MM1, MM1
	PXOR		MM2, MM2
	PXOR		MM3, MM3
	PXOR		MM4, MM4
	PXOR		MM5, MM5
	PXOR		MM6, MM6
	PXOR		MM7, MM7
	PXOR		XMM1, XMM1
	PXOR		XMM2, XMM2
	PXOR		XMM3, XMM3
	MOV	 	EAX, 0000000FFH
	MOVD		MM3, EAX

	; dest red -> MM4
	MOV	 	EAX, 0F800F800H
	MOVD		MM4, EAX

	; dest green -> MM5
	MOV	 	EAX, 07E007E0H
	MOVD		MM5, EAX

	; dest blue -> MM6  ; moved as MM6 is used in singlepixel
	; MOV	 EAX, 001F001FH
	; MOVD		MM6, EAX

	MOV		EAX,sy[EBP]
	MOV		fy[EBP],EAX

	MOV		EDX, dstadr[EBP]
	MOV		EBX, dl[EBP]
	SHL			EBX, 1
	ADD		EDX, EBX
	MOV		EBX, dt[EBP]
	IMUL		EBX, dstbpr[EBP]
	ADD		EDX, EBX
	MOV		yadr[EBP], EDX

	MOV		ECX, db[EBP]
	SUB		ECX, dt[EBP]		; counter in y
	JLE			endyloop			;exit
	MOV		y[EBP], ECX

outerloop:
	MOV		EDX, sx[EBP]		; keep EDX
	MOV		fx[EBP], EDX

	MOV		EDI, yadr[EBP]
	MOV		adr[EBP], EDI

	MOV		ESI, srcadr[EBP]		; calc new source adr
	MOV		EAX, fy[EBP]
	SHR		EAX, 16				; integer part of sy
	IMUL 		EAX, srcbpr[EBP]	; sy * srcbpr
	ADD		ESI, EAX			; first source adr in ESI
	MOV		yadd[EBP], ESI

	MOV		ECX, dr[EBP]
	SUB		ECX, dl[EBP]		; counter in x
	JLE			endyloop			;exit
	MOV		x[EBP], ECX

innerloop:
	MOV 		ECX, x[EBP]
	; if x < 8 then do one pixel at the time
	CMP		ECX, 8
	JL 			singlepixel
	; else
	; take 8 at the time

	MOV		EBX, EDI
	AND 		EBX, 0FH
	CMP		EBX, 0
	JNE 		singlepixel

alleightpixels:
	MOV	 	EAX, 0000000FFH
	MOVD		MM3, EAX

	; dest red -> MM4
	MOV	 	EAX, 0F800F800H
	MOVD		MM4, EAX

	; dest green -> MM5
	MOV	 	EAX, 07E007E0H
	MOVD		MM5, EAX

	; dest blue -> MM6 ; moved as MM6 is used in singlepixel
	; MOV	 EAX, 001F001FH
	; MOVD		MM6, EAX

	; dest blue -> MM6
	MOV		EAX, 001F001FH
	MOVD		MM6, EAX

	; Load data from memory
	MOV		EBX, fx[EBP]
	MOV		ECX, EBX ; copy of fx
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX] ; col0 in EAX
	MOVD		XMM2,EAX

	MOV 		EDX, sdx[EBP]
	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX] ; col1 in EAX
	MOVD		XMM1,EAX
	PSLLDQ		XMM1,4
	POR		XMM2,XMM1

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX] ; col2 in EAX
	MOVD		XMM1,EAX
	PSLLDQ		XMM1,8
	POR		XMM2,XMM1

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX] ; col3 in EAX
	MOVD		XMM1,EAX
	PSLLDQ		XMM1,12
	POR		XMM2,XMM1

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX]; col4 in EAX
	MOVD		XMM1,EAX

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX]; col5 in EAX
	MOVD		XMM3,EAX
	PSLLDQ		XMM3,4
	POR		XMM1,XMM3

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX]; col6 in EAX
	MOVD		XMM3,EAX
	PSLLDQ		XMM3,8
	POR		XMM1,XMM3

	ADD		ECX, EDX
	MOV		EBX, ECX
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV		EAX,[EBX] ; col7 in EAX
	MOVD		XMM3,EAX
	PSLLDQ		XMM3,12
	POR		XMM1,XMM3

	ADD 		ECX, EDX
	MOV		fx[EBP], ECX

	; swap regs
	; MOVDQU 	XMM4, XMM2
	; MOVDQU 	XMM2, XMM1
	; MOVDQU 	XMM1, XMM4

	; get alphas
	MOVQ2DQ	XMM4,  MM3
	MOVDQU 	XMM6, XMM2
	PSHUFD		XMM4, XMM4, 0
	MOVDQU 	XMM5, XMM1
	PSLLD 		XMM4, 24
	PAND 		XMM6, XMM4 		; alpha 5-8 in XMM6
	PAND 		XMM5, XMM4  		; alpha 1-4 in XMM5
	PSRLD 		XMM5, 24
	PSHUFHW 	XMM5, XMM5, 85H
	PSRLD 		XMM6, 24

	; put both alphas into 1 register
	PSHUFHW 	XMM6, XMM6, 85H
	PSHUFLW 	XMM5, XMM5, 85H
	PSHUFLW 	XMM6, XMM6, 58H
	PSHUFD		XMM5, XMM5, 0D0H  	; 0102030400000000
	PSHUFD 	XMM6, XMM6, 5CH 		; 0000000005060708
	PXOR 		XMM0,XMM0
	POR		XMM5, XMM6            	; XMM5 = alphas 0102030405060708

	PCMPEQD 	XMM0, XMM5
	PMOVMSKB EAX, XMM0
	CMP 		EAX, 0FFFFH 			; all alphas = zero; TEST not possible, because only 8 bits compared
	JE      		endloop

	; mask out alpha = zero

	; fd := 255-ORD(src[a]); fd = XMM4
	; MOV 	XMM4, 00FF00FF00FF00FF00FF00FF00FF00FFH
	PXOR 		XMM4, XMM4
	MOV	 	EAX, 00FFH
	PINSRW	XMM4, EAX ,0
	PSHUFLW 	XMM4, XMM4, 0
	PSHUFD 	XMM4, XMM4, 0
	PSUBW 	XMM4, XMM5
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
	MOVQ2DQ 	XMM3, MM3
	PSHUFD 	XMM3, XMM3, 0
	MOVDQU 	XMM5, XMM1
	MOVDQU 	XMM6, XMM2
	PSLLD 		XMM3, 16

	; sred14 = src14 && (srcMask << 24)
	; src14 must be copied because it mustn't be changed
	PAND 		XMM5, XMM3 			; sred14
	PSRLD 		XMM5, 16

	; sred14s = shuffled sred14
	PSHUFHW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM3 			; sred58
	PSRLD 		XMM6, 16

	PSHUFLW 	XMM5, XMM5,85H
	PSHUFHW 	XMM6, XMM6,85H
	PSHUFD  	XMM5, XMM5,0D0H 	; sred14s
	PSHUFLW 	XMM6, XMM6,58H
	PSHUFD  	XMM6, XMM6,5CH 		; sred58s
	POR 		XMM5, XMM6 			; sred18

	; sred18255 = sred18 * 256- sred18
	MOVDQU 	XMM7, XMM5
	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 			; sred18255

	; src is now ready

	;destination
	; dest18 must be copied because it mustn't be changed
	; Load data into memory
	MOV 		EDI, adr[EBP]
	MOVDQU 	XMM3, [EDI]  			;dest 1-8
	MOVQ2DQ	XMM6, MM4
	PSHUFD 	XMM6, XMM6, 0
	MOVDQU 	XMM7, XMM3

	PAND 		XMM7, XMM6 			; dred18
	PSRLW 		XMM7, 8
	;  dred18alpha = dred18 * negalpha
	PMULLW 	XMM7, XMM4 			; dred18alpha

	; dest is prepared
	; combining dest and src

	; dred18big = sred18255 + dred18alpha
	 PADDUSW XMM7, XMM5 			; dred18big
	; dred18f = dred18big && destMaskred128  because >> 11 and << 11 is && mask
	PAND 		XMM7, XMM6 			; dred18f

  	; dest18nr0 = dest18 && (~destMaskred128)
 	PANDN 	XMM6, XMM3  			; dest18nr0

 	 ; dest18nrf = dest18nr0 || dred18f
 	POR 		XMM6, XMM7

	MOVDQU 	XMM3, XMM6

	; red is calculated

	; calculate green:
	; get source

	; sgreen14 = src14 && (srcMask <<8)
	; srcMask << 8
	MOVQ2DQ 	XMM7, MM3

	PSHUFD 	XMM7, XMM7, 0
	MOVDQU 	XMM5, XMM1
	PSLLD 		XMM7, 8
	PAND 		XMM5, XMM7 			; sgreen14
	PSRLD 		XMM5, 8

	; sgreen14s = shuffled sgreen14
	PSHUFHW 	XMM5, XMM5,85H
	MOVDQU 	XMM6, XMM2
	PSHUFLW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM7 			; sgreen58
	PSRLD 		XMM6, 8
	PSHUFD  	XMM5, XMM5,0D0H 	; sgreen14s

	; sgreen58 = src58&& (srcMask << 8)
	; src58 must be copied because it mustn't be changed

	; sgreen58s = shuffled sgreen58
	PSHUFHW 	XMM6, XMM6,85H
	PSHUFLW 	XMM6, XMM6,58H
	PSHUFD  	XMM6, XMM6,5CH 		; sgreen58s

	; sgreen18 = sgreen14s || sgreen58s
	POR 		XMM5, XMM6 ; sgreen18

	; sgreen18255 = sgreen18 * 256- sgreen18
	MOVDQU 	XMM7, XMM5
	MOVQ2DQ	XMM6, MM5

	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 			; sgreen18255
	PSHUFD 	XMM6, XMM6, 0

	MOVDQU 	XMM7, XMM3

	PAND 		XMM7, XMM6 			; dgreen18
	PSRLW 		XMM7,3
	;  dgreen18alpha = dgreen18 * negalpha
	PMULLW 	XMM7, XMM4 			; dgreen18alpha

	; dest is prepared
	; combining dest and src

	; dgreen18big = sgreen18255 + dgreen18alpha

	PADDUSW 	XMM7, XMM5 			; dgreen18big
	PANDN 	XMM6, XMM3  			; dest18ng0

	; dgreen18f = (dgreen18big >> 11) <<5

	PSRLW 		XMM7, 10 				; dgreen18f
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
	MOVQ2DQ 	XMM7, MM3
	MOVDQU 	XMM5, XMM1

	PSHUFD 	XMM7, XMM7, 0
	MOVDQU 	XMM6, XMM2

	; sblue14 = src14 && (srcMask)
	; src14 must be copied because it mustn't be changed
	PAND 		XMM5, XMM7 			; sblue14

	; sblue14s = shuffled sblue14
	PSHUFHW 	XMM5, XMM5,85H
	PAND 		XMM6, XMM7 			; sblue58
	PSHUFHW 	XMM6, XMM6,85H

	PSHUFLW 	XMM5, XMM5,85H
	PSHUFLW 	XMM6, XMM6,58H

	PSHUFD  	XMM5, XMM5,0D0H 	; sblue14s
	PSHUFD  	XMM6, XMM6,5CH 		; sblue58s

	POR 		XMM5, XMM6 			; sblue18

	; sblue18255 = sblue18 * 256- sblue18
	MOVDQU 	XMM7, XMM5
	PSLLW 		XMM5, 8
	PSUBUSW 	XMM5, XMM7 			; sblue18255
	MOVQ2DQ 	XMM6, MM6
	PSHUFD 	XMM6, XMM6, 0
	MOVDQU 	XMM7, XMM3
	PAND 		XMM7, XMM6 			; dblue18
	PSLLW 		XMM7, 3

	PMULLW 	XMM7, XMM4 			; dblue18alpha

	; dest is prepared
	; combining dest and src

	; dblue18big = sblue18255 + dblue18alpha
	 PADDUSW 	XMM7, XMM5 			; dblue18big
	; dblue18f = (dblue18big >> 11)
	PANDN 	XMM6, XMM3  			; dest18nr0
 	PSRLW 		XMM7, 11 				; dblue18f

 	; dest18nr0 = dest18 && (~destMaskblue128)

  	; dest18nbf = dest18nb0 || dblue18f
 	POR 		XMM6, XMM7
	MOVDQU 	XMM3, XMM6

	; blue is calculated

	; now dest is calculated, store it
	; get 0 stuff
	MOVDQU	XMM5, [EDI]
	PAND		XMM5,XMM0
	PANDN		XMM0, XMM3
	POR		XMM0, XMM5

	MOVDQU 	[EDI],XMM0

endloop:
	;fx already inc  ; by sdx
	ADD 		EDI, 16
	MOV 		adr[EBP],EDI
	SUB 		x[EBP], 8
	JNZ 		innerloop 				; x>=0
	JZ 			endxloop

singlepixel: ; original code from MMXBGRA8888Over565, adjusted to fit this procedure
	MOV 		EDI, adr[EBP]

	MOV	 	EAX, 0000000FFH
	MOVD		MM3, EAX

	; dest red -> MM4
	MOV	 	EAX, 0F800F800H
	MOVD		MM4, EAX

	; dest green -> MM5
	MOV	 	EAX, 07E007E0H
	MOVD		MM5, EAX

	; dest blue -> MM6 				; moved as MM6 is used in singlepixel
	; MOV	 	EAX, 001F001FH
	; MOVD		MM6, EAX

	MOV	 	EAX, 0FFFFFFFFH
	MOVD		MM7, EAX
	PUNPCKLBW	MM7, MM0 		 	; 00FF00FF00FF00FF

	MOV		EBX, fx[EBP]
	SHR		EBX,16
	SHL			EBX, 2
	ADD		EBX, yadd[EBP]

	MOV 		EAX,[EBX]
	XOR		EBX, EBX
	MOV 		BX,	[EDI]

	; 255 - alpha
	MOV		EDX, EAX
	SHR		EDX, 24

	CMP		EDX, 0
	JE			empty
	CMP		EDX, 255
	JE			full

alpha:
	NEG		EDX
	ADD		EDX, 255

	MOVD 		MM6, EDX
	PUNPCKLWD MM6, MM6
	PUNPCKLDQ MM6, MM6

	MOVD 		MM1, EAX
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

	MOVD		MM2, EAX
	PUNPCKLBW	MM1, MM0  		; 0000ARGB --> 0A0R0G0B
	PMULLW 	MM1, MM7
	PUNPCKLBW	MM2, MM0  		; 0000ARGB --> 0A0R0G0B
	PMULLW 	MM2, MM6
	PADDUSW 	MM1, MM2

	;	PSRLW	MM1, 8 ; normalize
	DB 			0FH, 71H, 0D1H, 08H
	PACKUSWB 	MM1, MM0

	; HUGA BIMBO Muell
	MOVD		EAX, MM1

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

	MOV 		[EDI], DX

empty:
	MOV		ECX,fx[EBP]
	ADD		ECX, sdx[EBP]
	MOV		fx[EBP],ECX

	MOV		EDI,adr[EBP]
	ADD		EDI, 2					; inc adr
	MOV		adr[EBP],EDI

	SUB		x[EBP], 1
	JNZ			innerloop

endxloop:
	MOV		EAX,fy[EBP]				; fy := fy + sdy
	ADD		EAX, sdy[EBP]
	MOV		fy[EBP], EAX

	MOV		EAX, yadr[EBP]
	ADD		EAX, dstbpr[EBP]
	MOV		EDI, EAX
	MOV		yadr[EBP], EAX

	SUB		y[EBP], 1
	JNZ			outerloop

endyloop:
	EMMS 								; declare FPU registers free
	POP 		EBX
	POPFD
*)
END SSE2Q0BGRA8888BGR565;


PROCEDURE Scale*(src : Image; sr : Rectangle; dst : Image; dr : Rectangle; clip : Rectangle; copyMode, scaleMode : LONGINT);
VAR dw, dh, sw, sh : LONGINT;
	fw, fh : LONGREAL; sx, sy : LONGINT;
	scaler : ScalerProc; xscaler : XScalerProc;
	mode : Raster.Mode;
	SSE2enabled : BOOLEAN;
BEGIN
	ASSERT((clip.l >= 0) & (clip.t >= 0) & (clip.r <= dst.width) & (clip.b <= dst.height));
	ASSERT((sr.l >= 0) & (sr.t >= 0) & (sr.r <= src.width) & (sr.b <= src.height));
	dw := dr.r - dr.l; dh := dr.b - dr.t;
	sw := sr.r - sr.l; sh := sr.b - sr.t;

	IF (sw = dw) & (sh = dh) THEN (* optimize special case *)
		IF ~Rect.IsContained(clip, dr) THEN
			IF dr.l < clip.l THEN DEC(dw, (clip.l - dr.l)); INC(sr.l, (clip.l - dr.l)); dr.l := clip.l END;
			IF dr.t < clip.t THEN DEC(dh, (clip.t - dr.t)); INC(sr.t, (clip.t - dr.t)); dr.t := clip.t END;
			IF dr.r > clip.r THEN DEC(dw, (dr.r - clip.r)) END;
			IF dr.b > clip.b THEN DEC(dh, (dr.b - clip.b)) END;
		END;
		IF (dw > 0) & (dh > 0) THEN
			IF copyMode = ModeCopy THEN Raster.InitMode(mode, Raster.srcCopy)
			ELSE Raster.InitMode(mode, Raster.srcOverDst)
			END;
			Raster.Copy(src, dst, sr.l, sr.t, sr.l + dw, sr.t + dh, dr.l, dr.t, mode)
		END;
		RETURN
	END;

	fw := sw / dw;
	fh := sh / dh;
	sx := sr.l * 65536;
	sy := sr.t * 65536;
	(* clipping *)
	IF ~Rect.IsContained(clip, dr) THEN
		sw := sr.r - sr.l; sh := sr.b - sr.t;
		dw := dr.r - dr.l; dh := dr.b - dr.t;
		IF dr.r > clip.r THEN dr.r := clip.r END;
		IF dr.b > clip.b THEN dr.b := clip.b END;
		IF dr.l < clip.l THEN sx := ENTIER(65536 * (sr.l +  sw * (clip.l - dr.l) / dw)); dr.l := clip.l END;
		IF dr.t < clip.t THEN sy := ENTIER(65536 * (sr.t + sh * (clip.t - dr.t) / dh)); dr.t := clip.t END;
	END;
	IF Rect.RectEmpty(dr) THEN RETURN END;
	xscaler := NIL;
	SSE2enabled :=Raster.SSE2enabled; (*Machine.SSE2Support; *)
SSE2enabled := FALSE;
	IF SSE2enabled THEN
		IF (src.fmt.code = Raster.bgr565) & (dst.fmt.code = Raster.bgr565) THEN
			IF copyMode = ModeCopy THEN
				IF scaleMode = 0 THEN xscaler := SSE2Q0BGR565BGR565;
				ELSIF scaleMode = 1 THEN xscaler:= SSE2Q1BGR565BGR565;
				END;
			END;
		ELSIF (src.fmt.code = Raster.bgra8888) & (dst.fmt.code = Raster.bgr565) THEN
			IF copyMode = ModeSrcOverDst THEN
				IF scaleMode = 0 THEN xscaler :=  SSE2Q0BGRA8888BGR565;
				ELSIF scaleMode = 1 THEN xscaler := SSE2Q1BGRA8888BGR565;
				END;
			END;
		END;
	END;
	IF (xscaler = NIL) THEN
		IF (src.fmt.code = Raster.bgr565) & (dst.fmt.code = Raster.bgr565) THEN
			IF copyMode = ModeCopy THEN
				IF scaleMode = 0 THEN xscaler := XQ0BGR565BGR565;
				ELSIF scaleMode = 1 THEN xscaler := Q1BGR565BGR565;
		 		END;
			END;
		ELSIF (src.fmt.code = Raster.bgra8888) & (dst.fmt.code = Raster.bgr565) THEN
			IF copyMode = ModeSrcOverDst THEN
				IF scaleMode = 0 THEN xscaler := Q0BGRA8888BGR565;
				ELSIF scaleMode = 1 THEN xscaler := Q1BGRA8888BGR565;
				END;
			END;
		ELSIF (src.fmt.code = Raster.bgra8888) & (dst.fmt.code = Raster.bgra8888) THEN
			IF (copyMode = ModeSrcOverDst) THEN
				IF (scaleMode = 0) THEN xscaler := Q0BGRA8888BGRA8888;
				ELSIF (scaleMode = 1) THEN xscaler := Q1BGRA8888BGRA8888;
				END;
			ELSIF (copyMode = ModeCopy) THEN
				IF (scaleMode = 0) THEN xscaler := Q0BGRA8888BGRA8888Copy;
				ELSIF (scaleMode = 1) THEN xscaler := Q1BGRA8888BGRA8888Copy;
				END;
			END;
		END;
	END;

	IF xscaler # NIL THEN
		xscaler(src.adr, dst.adr, src.bpr, dst.bpr, dr.l, dr.t, dr.r, dr.b, sx, sy,
			ENTIER(fw * 65536), ENTIER(fh * 65536), src.width, src.height)
	ELSE
		scaler := Q0GenericSrcOverDst; (* fallback case *)
		IF copyMode = ModeCopy THEN
			IF scaleMode = 0 THEN scaler := Q0GenericCopy
			ELSIF scaleMode = 1 THEN scaler := Q1GenericCopy
			END
		ELSIF copyMode = ModeSrcOverDst THEN
			IF scaleMode = 0 THEN scaler := Q0GenericSrcOverDst
			ELSIF scaleMode = 1 THEN scaler := Q1GenericSrcOverDst
			END;
		END;
		scaler(src, dst, dr, sx, sy, ENTIER(fw * 65536), ENTIER(fh * 65536));
	END;
END Scale;

PROCEDURE Bounds(val, min, max : LONGINT) : LONGINT;
BEGIN
	IF val < min THEN RETURN min ELSIF val > max THEN RETURN max ELSE RETURN val END
END Bounds;

END WMRasterScale.


SpeedTest.Mod