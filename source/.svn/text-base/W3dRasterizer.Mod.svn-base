MODULE W3dRasterizer;	(** AUTHOR "TF"; PURPOSE "Quick implementiation of a 3d rasterizer "; *)

IMPORT
	SYSTEM, KernelLog, Vectors := W3dVectors,  AbstractWorld := W3dAbstractWorld, Raster;

CONST Paranoid = FALSE;

TYPE
	Vertex* = OBJECT(AbstractWorld.Vertex)
	VAR
		p*, pt*, n*, nt* : Vectors.TVector3d;
		u*, v*, x*, y* : LONGREAL;
		color* : LONGINT;
		behind* : BOOLEAN;

		PROCEDURE SetPos*(p : Vectors.TVector3d);
		BEGIN
			SELF.p := p
		END SetPos;

		PROCEDURE SetUV*(u, v : LONGREAL);
		BEGIN
			SELF.u := u; SELF.v := v
		END SetUV;

		PROCEDURE SetColor*(color : LONGINT);
		BEGIN
			SELF.color := color
		END SetColor;
	END Vertex;

	Texture* = OBJECT (AbstractWorld.Texture)
	VAR
		img* : Raster.Image;
	END Texture;

	Triangle* = RECORD
		normal* : Vectors.TVector3d;
		vert* : ARRAY 3 OF Vertex;
		color* : LONGINT;
		transColor*: LONGINT;
		tex* : Texture;
		mask0*, culled* : BOOLEAN;
	END;

	Rasterizer* = OBJECT
	VAR img*, saveimg: Raster.Image;
		zBuffer, savezBuffer : POINTER TO ARRAY OF REAL;
		invBuffer : POINTER TO ARRAY OF LONGINT;

		width*, height* : LONGINT;
		(* Global to avoid stack clearing penalty, TODO: check accesstimes *)
		x0, x1, x2, x3, dxL, dxR, xL, xR, xStart, xEnd, tr: REAL;
		y0, y1, y2, dx, zStride, stride, color: LONGINT; (* buffer variables *)
		adrBase, zBufBase: ADDRESS;

		tx0, tx1, tx2, tx3, ty0, ty1, ty2, ty3, txStart, tyStart, dtxStart, dtyStart, dtx, dty: REAL; (* parameters for affine texture *)

		z0, z1, z2, z3, zStart, dzStart, dz : REAL; (* z values used for affine mapping *)
		 zinv0, zinv1, zinv2, zinv3, zinvStart, dzinvStart, dzinv : REAL; (* used for perspective mapping *)

		 invertable : BOOLEAN;
		 invAdrStride, invIdx : LONGINT;
		 invAdrBase: ADDRESS;

		 PROCEDURE CCW(tri : Triangle):BOOLEAN;
		 BEGIN
		 	RETURN (tri.vert[1].x - tri.vert[0].x) * (tri.vert[2].y - tri.vert[0].y) -
		 			(tri.vert[2].x - tri.vert[0].x) * (tri.vert[1].y - tri.vert[0].y) >= 0
		 END CCW;

		PROCEDURE SetSize*(w, h : LONGINT);
		BEGIN
			NEW(img);
			width := w; height := h;
			Raster.Create(img, w, h, Raster.BGR565);
			NEW(saveimg); Raster.Create(saveimg, w, h, Raster.BGR565);
			stride := img.bpr;
			NEW(zBuffer, w * h); NEW(savezBuffer, w * h);
			NEW(invBuffer, w * h);
			zStride := w * 4;
			invAdrStride := w * 4
		END SetSize;

		PROCEDURE Keep*;
		VAR mode : Raster.Mode;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.Copy(img, saveimg, 0, 0, width, height, 0, 0, mode);
			SYSTEM.MOVE(ADDRESSOF(zBuffer[0]), ADDRESSOF(savezBuffer[0]), width * height * SIZEOF(REAL))
		END Keep;

		PROCEDURE Restore*;
		VAR mode : Raster.Mode;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.Copy(saveimg, img, 0, 0, width, height, 0, 0, mode);
			SYSTEM.MOVE(ADDRESSOF(savezBuffer[0]), ADDRESSOF(zBuffer[0]), width * height * SIZEOF(REAL))
		END Restore;

		PROCEDURE SetInvertable*(invertable : BOOLEAN);
		BEGIN
			SELF.invertable := invertable
		END SetInvertable;

		PROCEDURE SetObjectIndex*(idx : LONGINT);
		BEGIN
			SELF.invIdx := idx
		END SetObjectIndex;

		(** Return 0 if no object found *)
		PROCEDURE GetInvIdx*(x, y : LONGINT) : LONGINT;
		BEGIN
			IF (invBuffer#NIL) & (x >= 0) & (x < width) & (y >= 0) & (y < height) THEN RETURN invBuffer[y * width + x] ELSE RETURN 0 END
		END GetInvIdx;

		PROCEDURE Clear*(color: LONGINT);
		VAR pix : Raster.Pixel;
			mode : Raster.Mode;
			i : LONGINT;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.SetRGB(pix, color DIV 65536 MOD 256, color DIV 256 MOD 256, color MOD 256);
			Raster.Fill(img, 0, 0, width, height, pix, mode);
			FOR i := 0 TO width * height - 1 DO zBuffer[i] := MAX(LONGINT) END;
			IF invertable THEN FOR i := 0 TO width * height - 1 DO invBuffer[i] := 0 END END
		END Clear;

		PROCEDURE RenderLine;
		VAR adr, zAdr, invAdr: ADDRESS; x : LONGINT; z, ttx, tty: REAL;
		BEGIN
			xL := xStart; xR := xEnd; z := zStart;
			ttx := txStart; tty := tyStart;

			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN z := z - xL * dz; xL := 0 END;

			IF xR > width THEN xR := width END;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;
				IF z < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, z));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2); z := z + dz
			END;
			INC(adrBase, stride); INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL; xEnd := xEnd + dxR;
			zStart := zStart + dzStart
		END RenderLine;

		PROCEDURE RenderLineTex(tex : Texture);
		VAR adr, zAdr, invAdr: ADDRESS; x, txi, tyi, tadr : LONGINT; z, tx, ty: REAL;
		BEGIN
			xL := xStart;
			xR := xEnd;
			tx := txStart; ty := tyStart;
			z := zStart;
			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN
				z := z - xL * dz;
				tx := tx - xL * dtx;
				ty := ty - xL * dty;
				xL := 0;
			END;

			IF xR > width THEN xR := width END;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;
				IF z < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					txi := ENTIER(tx); tyi := ENTIER(ty); tadr := 2* txi +  tyi * tex.img.bpr;
					IF  tadr < 0  THEN color := 0 ELSIF tadr  >= tex.img.height * tex.img.bpr THEN color := 0 ELSE
						color := SYSTEM.GET16(tex.img.adr + tadr);
					END;
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, z));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2);
				tx := tx + dtx; ty := ty + dty;
				z := z + dz
			END;
			INC(adrBase, stride);
			INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL;
			xEnd := xEnd + dxR;
			zStart := zStart + dzStart;
			txStart := txStart + dtxStart; tyStart := tyStart + dtyStart;
		END RenderLineTex;

		PROCEDURE RenderTriangle*(VAR tri : Triangle);
		VAR p0, p1, p2, t : Vertex; y, dy : LONGINT; f, dxinv, dyinv:REAL;
		BEGIN
			IF tri.culled & ~CCW(tri) THEN RETURN END;
			color := tri.transColor;

			p0 := tri.vert[0]; p1 := tri.vert[1]; p2 := tri.vert[2];
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			IF p2.y < p1.y THEN t := p1; p1 := p2; p2 := t END;
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			y0 := ENTIER(p0.y); y1 := ENTIER(p1.y);  y2 := ENTIER(p2.y);
			IF (y0 >= height) OR (y2 < 0) OR (y0 = y2) THEN RETURN END;

			x0 := SHORT(p0.x); x1 := SHORT(p1.x); x2 := SHORT(p2.x);
			f := (y1 - y0) / (y2 - y0); x3 := x0 + (x2 - x0) * f;

			dx := ENTIER(x3) - ENTIER(x1);
			IF dx = 0 THEN RETURN END;
			dxinv := 1 / (x3 - x1);

			z0 := SHORT(p0.pt.z);
			z1 := SHORT(p1.pt.z);
			z2 := SHORT(p2.pt.z);
			z3 := z0 + (z2 - z0) * f;

			IF tri.tex # NIL THEN
				tx0 := SHORT((tri.tex.img.width - 1) * p0.u);
				ty0 := SHORT((tri.tex.img.height - 1) * p0.v);
				tx1 := SHORT((tri.tex.img.width - 1) * p1.u);
				ty1 := SHORT((tri.tex.img.height - 1) * p1.v);
				tx2 := SHORT((tri.tex.img.width - 1) * p2.u);
				ty2 := SHORT((tri.tex.img.height - 1) * p2.v)
			END;
			tx3 := tx0 + (tx2 - tx0) * f;
			ty3 := ty0 + (ty2 - ty0) * f;

			dz := (z3 - z1) * dxinv;
			dtx := (tx3 - tx1) * dxinv;
			dty := (ty3 - ty1) * dxinv;

			IF dx < 0 THEN
				tr := x1; x1 := x3; x3 := tr;
				tx1:= tx3; ty1:= ty3;
				z1 := z3
			END;

			IF y1 >= 0 THEN (* otherwise invisible part *)
				dy := y1 - y0;
				IF dy # 0 THEN
					dyinv := 1 / dy;
					dxL := (x1 - x0) * dyinv; dxR := (x3 - x0) * dyinv;
					dzStart := (z1 - z0) * dyinv; (* z difference per raster line *)
					dtxStart := (tx1 - tx0) * dyinv; dtyStart := (ty1 - ty0) * dyinv
				END;
				xStart := x0; xEnd := x0; zStart := z0; txStart := tx0; tyStart := ty0;

				IF y0 < 0 THEN
					xStart := xStart - y0 * dxL;
					xEnd := xEnd - y0 * dxR;
					zStart := zStart - y0 * dzStart;
					txStart := txStart - y0 * dtxStart; tyStart := tyStart - y0 * dtyStart;
					y0 := 0
				END;
				adrBase := img.adr + stride * y0;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y0;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y0;
				IF y1 > height THEN y1 := height END;

				IF tri.tex # NIL THEN FOR y := y0 TO y1 - 1 DO RenderLineTex(tri.tex) END
				ELSE FOR y := y0 TO y1 - 1 DO RenderLine END
				END;
			END;

			IF y1 < height THEN (* otherwise bottom part is out *)
				dy  := y2 - y1;
				IF dy # 0 THEN
					dyinv := 1 / dy;
					dxL := (x2 - x1) * dyinv; dxR := (x2 - x3) * dyinv;
					dzStart := (z2 - z1) * dyinv; (* z difference per raster line *)
					dtxStart := (tx2 - tx1) * dyinv; dtyStart := (ty2 - ty1) * dyinv
				END;
				xStart := x1; zStart := z1; xEnd := x3; txStart := tx1; tyStart := ty1;

				IF y1 < 0 THEN
					xStart := xStart - y1 * dxL;
					xEnd := xEnd - y1 * dxR;
					zStart := zStart - y1 * dzStart;
					txStart := txStart - y1 * dtxStart; tyStart := tyStart - y1 * dtyStart;
					y1 := 0
				END;

				IF y2 > height THEN y2 := height END;
				adrBase := img.adr + stride * y1;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y1;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y1;
				IF tri.tex # NIL THEN FOR y := y1 TO y2 - 1 DO RenderLineTex(tri.tex) END
				ELSE FOR y := y1 TO y2 - 1 DO RenderLine END
				END
			END;

		END RenderTriangle;


(* Expensive perspective case *)

		PROCEDURE RenderPerspLineTex(tex : Texture);
		VAR adr, zAdr, invAdr: ADDRESS; x, txi, tyi, tadr: LONGINT; z, zinv, rzinv, tx, ty, txr, tyr: REAL;
		BEGIN
			xL := xStart;
			xR := xEnd;
			tx := txStart; ty := tyStart;
			zinv := zinvStart;
			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN
				zinv := zinv - xL * dzinv;
				tx := tx - xL * dtx;
				ty := ty - xL * dty;
				xL := 0;
			END;

			IF xR > width THEN xR := width END;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				rzinv := 1 / zinv;
				z := rzinv;
				txr := ENTIER(tx * rzinv);
				tyr := ENTIER(ty * rzinv);
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;

				IF z < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					txi := ENTIER(txr); tyi := ENTIER(tyr); tadr := 2* txi +  tyi * tex.img.bpr;
					IF  tadr < 0  THEN color := 0 ELSIF tadr  >= tex.img.height * tex.img.bpr THEN color := 0 ELSE
						color := SYSTEM.GET16(tex.img.adr + tadr)
					END;
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, z));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2);
				tx := tx + dtx; ty := ty + dty;
				 zinv:= zinv + dzinv
			END;
			INC(adrBase, stride);
			INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL;
			xEnd := xEnd + dxR;
			txStart := txStart + dtxStart; tyStart := tyStart + dtyStart;
			zinvStart := zinvStart + dzinvStart;
		END RenderPerspLineTex;

		PROCEDURE RenderPerspLineFlat;
		VAR adr, zAdr, invAdr: ADDRESS; x: LONGINT; z, zinv, rzinv: REAL;
		BEGIN
			xL := xStart;
			xR := xEnd;
			zinv := zinvStart;
			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN
				zinv := zinv - xL * dzinv;
				xL := 0;
			END;

			IF xR > width THEN xR := width END;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				rzinv := 1 / zinv;
				z := rzinv;
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;

				IF z < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, z));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2);
				 zinv:= zinv + dzinv
			END;
			INC(adrBase, stride);
			INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL;
			xEnd := xEnd + dxR;
			zinvStart := zinvStart + dzinvStart;
		END RenderPerspLineFlat;

		PROCEDURE RenderPerspTriangle*(VAR tri : Triangle);
		VAR p0, p1, p2, t : Vertex; y, dy : LONGINT; f, dyinv, dxinv : REAL;
		BEGIN
			IF tri.culled & ~CCW(tri) THEN RETURN END;
			color := tri.transColor;
			p0 := tri.vert[0]; p1 := tri.vert[1]; p2 := tri.vert[2];
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			IF p2.y < p1.y THEN t := p1; p1 := p2; p2 := t END;
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			y0 := ENTIER(p0.y); y1 := ENTIER(p1.y);  y2 := ENTIER(p2.y);
			IF (y0 >= height) OR (y2 < 0) OR (y0 = y2) THEN RETURN END;

			x0 := SHORT(p0.x); x1 := SHORT(p1.x); x2 := SHORT(p2.x);
			f := (y1 - y0) / (y2 - y0);
			x3 := x0 + (x2 - x0) * f;

			dx := (ENTIER(x3) -ENTIER(x1));
			IF dx = 0 THEN RETURN END;
			dxinv := 1 / dx (*(x3 - x1);*);

			zinv0 :=  SHORT(1 / p0.pt.z); zinv1 := SHORT(1 / p1.pt.z); zinv2 := SHORT(1 / p2.pt.z);
			zinv3 := zinv0 + (zinv2 - zinv0) * f;

			IF tri.tex # NIL THEN
				tx0 := SHORT((tri.tex.img.width - 1) * p0.u * zinv0);
				ty0 := SHORT((tri.tex.img.height - 1) * p0.v * zinv0);
				tx1 := SHORT((tri.tex.img.width - 1) * p1.u * zinv1);
				ty1 := SHORT((tri.tex.img.height - 1) * p1.v * zinv1);
				tx2 := SHORT((tri.tex.img.width - 1) * p2.u * zinv2);
				ty2 := SHORT((tri.tex.img.height - 1) * p2.v * zinv2)
			END;
			tx3 := tx0 + (tx2 - tx0) * f;
			ty3 := ty0 + (ty2 - ty0) * f;

			dtx := (tx3 - tx1) * dxinv;
			dty := (ty3 - ty1) * dxinv;
			dzinv := (zinv3 - zinv1) * dxinv;
			IF dx < 0 THEN
				tr := x1; x1 := x3; x3 := tr;
				tx1:= tx3; ty1:= ty3;
				zinv1 := zinv3;
			END;

			IF y1 >= 0 THEN (* otherwise invisible part *)
				dy := y1 - y0; dyinv := 1 / dy;
				IF dy # 0 THEN
					dxL := (x1 - x0) * dyinv; dxR := (x3 - x0) * dyinv;
					dtxStart := (tx1 - tx0) * dyinv; dtyStart := (ty1 - ty0) * dyinv;
					dzinvStart := (zinv1 - zinv0) * dyinv;
				END;
				xStart := x0; xEnd := x0; txStart := tx0; tyStart := ty0;
				zinvStart := zinv0;

				IF y0 < 0 THEN
					xStart := xStart - y0 * dxL;
					xEnd := xEnd - y0 * dxR;
					txStart := txStart - y0 * dtxStart; tyStart := tyStart - y0 * dtyStart;
					zinvStart := zinvStart - y0 * dzinvStart;
					y0 := 0
				END;
				adrBase := img.adr + stride * y0;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y0;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y0;
				IF y1 > height THEN y1 := height END;

				IF tri.tex # NIL THEN FOR y := y0 TO y1 - 1 DO RenderPerspLineTex(tri.tex) END
				ELSE FOR y := y0 TO y1 - 1 DO RenderPerspLineFlat END
				END;
			END;

			IF y1 < height THEN (* otherwise bottom part is out *)
				dy  := y2 - y1; dyinv := 1 / dy;
				IF dy # 0 THEN
					dxL := (x2 - x1) * dyinv; dxR := (x2 - x3) * dyinv;
					dtxStart := (tx2 - tx1) * dyinv; dtyStart := (ty2 - ty1) * dyinv;
					dzinvStart := (zinv2 - zinv1) * dyinv;
				END;
				xStart := x1; xEnd := x3; txStart := tx1; tyStart := ty1;
				zinvStart := zinv1;

				IF y1 < 0 THEN
					xStart := xStart - y1 * dxL;
					xEnd := xEnd - y1 * dxR;
					txStart := txStart - y1 * dtxStart; tyStart := tyStart - y1 * dtyStart;
					zinvStart := zinvStart - y1 * dzinvStart;
					y1 := 0
				END;

				IF y2 > height THEN y2 := height END;
				adrBase := img.adr + stride * y1;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y1;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y1;
				IF tri.tex # NIL THEN FOR y := y1 TO y2 - 1 DO RenderPerspLineTex(tri.tex) END
				ELSE FOR y := y1 TO y2 - 1 DO RenderPerspLineFlat END
				END
			END;

		END RenderPerspTriangle;

(* Experimental Subdivision case *)

		PROCEDURE SubDivLineTex(tex : Texture);
		VAR adr, zAdr, invAdr: ADDRESS; x, txi, tyi, tadr: LONGINT; zinv, txr, tyr, zr, rzinv, tx, ty, sdtx, sdty, stx, sty, szr, ezr, dzr, subDivInv: REAL;
				i : LONGINT;
		CONST SubDiv = 16;
		BEGIN
			subDivInv := 1 / SubDiv;
			xL := xStart;
			xR := xEnd;
			zinv := zinvStart;
			tx := txStart; ty := tyStart;
			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN
				zinv := zinv - xL * dzinv;
				tx := tx - xL * dtx;
				ty := ty - xL * dty;
				xL := 0;
			END;

			IF xR > width THEN xR := width END;

			szr := 1 / zinv;
			stx := tx * szr; sty := ty * szr;
			ezr := 1 / ( zinv + SubDiv * dzinv);

			sdtx := ((tx + SubDiv * dtx)*ezr - stx) * subDivInv;
			sdty := ((ty + SubDiv * dty)*ezr - sty) * subDivInv;
			txr := stx; tyr := sty; zr := szr;
			dzr := (ezr - szr) * subDivInv;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			i := 0;
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				INC(i);
				IF i = SubDiv THEN
					rzinv := 1 / zinv; txr := tx * rzinv; tyr := ty * rzinv; zr := rzinv;

					ezr := 1 / ( zinv + SubDiv * dzinv);
					dzr := (ezr - zr) * subDivInv;
					sdtx := ((tx + SubDiv * dtx)*ezr - txr) * subDivInv;
					sdty := ((ty + SubDiv * dty)*ezr - tyr) * subDivInv;
					i := 0;
				END;
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;

				IF zr < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					txi := ENTIER(txr); tyi := ENTIER(tyr); tadr := 2* txi +  tyi * tex.img.bpr;
					IF  tadr < 0  THEN color := 0 ELSIF tadr  >= tex.img.height * tex.img.bpr THEN color := 0 ELSE
						color := SYSTEM.GET16(tex.img.adr + tadr);
					END;
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, zr));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2);
				txr := txr + sdtx; tyr := tyr + sdty;
				tx := tx +dtx; ty := ty +dty; zinv := zinv +dzinv;
				zr := zr + dzr
			END;
			INC(adrBase, stride);
			INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL;
			xEnd := xEnd + dxR;
			txStart := txStart + dtxStart; tyStart := tyStart + dtyStart;
			zinvStart := zinvStart + dzinvStart;
		END SubDivLineTex;

		PROCEDURE SubDivLineFlat;
		VAR adr, zAdr, invAdr: ADDRESS; x: LONGINT; zinv, zr, rzinv, szr, ezr, dzr, subDivInv: REAL;
				i : LONGINT;
		CONST SubDiv = 16;
		BEGIN
			subDivInv := 1 / SubDiv;
			xL := xStart;
			xR := xEnd;
			zinv := zinvStart;
			(* Line is out left... adjust all left based parameters *)
			IF xL < 0 THEN
				zinv := zinv - xL * dzinv;
				xL := 0;
			END;

			IF xR > width THEN xR := width END;

			szr := 1 / zinv ;zr := szr;
			ezr := 1 / ( zinv + SubDiv * dzinv);

			dzr := (ezr - szr) * subDivInv;

			adr := adrBase + 2 * ENTIER(xL);
			zAdr := zBufBase + 4 * ENTIER(xL);
			invAdr := invAdrBase + 4 * ENTIER(xL);
			i := 0;
			FOR x := ENTIER(xL) TO ENTIER(xR + 0.5) - 1 DO
				INC(i);
				IF i = SubDiv THEN
					rzinv := 1 / zinv;  zr := rzinv;
					ezr := 1 / ( zinv + SubDiv * dzinv);
					dzr := (ezr - zr) * subDivInv;
					i := 0
				END;
				IF Paranoid THEN
					IF ~((adr >= img.adr) & (adr < img.adr + img.height * img.bpr)) THEN
						KernelLog.String("Assertion failed! (A)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END;
					IF ~((zAdr >= ADDRESSOF(zBuffer[0])) & (zAdr < ADDRESSOF(zBuffer[0]) + width * height * 4)) THEN
						KernelLog.String("Assertion failed! (B)"); KernelLog.Int(x, 5); KernelLog.Ln;
						RETURN
					END
				END;

				IF zr < SYSTEM.VAL(REAL, SYSTEM.GET32(zAdr)) THEN
					SYSTEM.PUT16(adr, color);
					SYSTEM.PUT32(zAdr, SYSTEM.VAL(LONGINT, zr));
					IF invertable THEN SYSTEM.PUT32(invAdr, invIdx) END
				END;
				INC(zAdr, 4); INC(invAdr, 4); INC(adr, 2);
				zinv := zinv +dzinv;
				zr := zr + dzr
			END;
			INC(adrBase, stride);
			INC(zBufBase, zStride);
			INC(invAdrBase, invAdrStride);
			xStart := xStart + dxL;
			xEnd := xEnd + dxR;
			txStart := txStart + dtxStart; tyStart := tyStart + dtyStart;
			zinvStart := zinvStart + dzinvStart;
		END SubDivLineFlat;

		PROCEDURE SubDivTriangle*(VAR tri : Triangle);
		VAR p0, p1, p2, t : Vertex; y, dy : LONGINT; f, dyinv, dxinv : REAL;
		BEGIN
			IF tri.culled & ~CCW(tri) THEN RETURN END;
			color := tri.transColor;

			p0 := tri.vert[0]; p1 := tri.vert[1]; p2 := tri.vert[2];
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			IF p2.y < p1.y THEN t := p1; p1 := p2; p2 := t END;
			IF p1.y < p0.y THEN t := p0; p0 := p1; p1 := t END;
			y0 := ENTIER(p0.y); y1 := ENTIER(p1.y);  y2 := ENTIER(p2.y);
			IF (y0 >= height) OR (y2 < 0) OR (y0 = y2) THEN RETURN END;

			x0 := SHORT(p0.x); x1 := SHORT(p1.x); x2 := SHORT(p2.x);
			f := (y1 - y0) / (y2 - y0);
			x3 := x0 + (x2 - x0) * f;

			dx := (ENTIER(x3 + 0.5) -ENTIER(x1));
			IF dx = 0 THEN RETURN END;
			dxinv := 1 / (x3 - x1);

			zinv0 :=  SHORT(1 / p0.pt.z); zinv1 := SHORT(1 / p1.pt.z); zinv2 := SHORT(1 / p2.pt.z);
			zinv3 := zinv0 + (zinv2 - zinv0) * f;

			IF tri.tex # NIL THEN
				tx0 := SHORT((tri.tex.img.width - 1) * p0.u * zinv0);
				ty0 := SHORT((tri.tex.img.height - 1) * p0.v * zinv0);
				tx1 := SHORT((tri.tex.img.width - 1) * p1.u * zinv1);
				ty1 := SHORT((tri.tex.img.height - 1) * p1.v * zinv1);
				tx2 := SHORT((tri.tex.img.width - 1) * p2.u * zinv2);
				ty2 := SHORT((tri.tex.img.height - 1) * p2.v * zinv2)
			END;
			tx3 := tx0 + (tx2 - tx0) * f;
			ty3 := ty0 + (ty2 - ty0) * f;

			dtx := (tx3 - tx1) * dxinv;
			dty := (ty3 - ty1) * dxinv;
			dzinv := (zinv3 - zinv1) * dxinv;
			IF dx < 0 THEN
				tr := x1; x1 := x3; x3 := tr;
				tx1:= tx3; ty1:= ty3;
				zinv1 := zinv3;
			END;

			IF y1 >= 0 THEN (* otherwise invisible part *)
				dy := y1 - y0; dyinv := 1 / dy;
				IF dy # 0 THEN
					dxL := (x1 - x0) * dyinv; dxR := (x3 - x0) * dyinv;
					dtxStart := (tx1 - tx0) * dyinv; dtyStart := (ty1 - ty0) * dyinv;
					dzinvStart := (zinv1 - zinv0) * dyinv;
				END;
				xStart := x0; xEnd := x0; txStart := tx0; tyStart := ty0;
				zinvStart := zinv0;

				IF y0 < 0 THEN
					xStart := xStart - y0 * dxL;
					xEnd := xEnd - y0 * dxR;
					txStart := txStart - y0 * dtxStart; tyStart := tyStart - y0 * dtyStart;
					zinvStart := zinvStart - y0 * dzinvStart;
					y0 := 0
				END;
				adrBase := img.adr + stride * y0;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y0;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y0;
				IF y1 > height THEN y1 := height END;

				IF tri.tex # NIL THEN FOR y := y0 TO y1 - 1 DO SubDivLineTex(tri.tex) END
				ELSE FOR y := y0 TO y1 - 1 DO SubDivLineFlat END
				END;
			END;

			IF y1 < height THEN (* otherwise bottom part is out *)
				dy  := y2 - y1; dyinv := 1 / dy;
				IF dy # 0 THEN
					dxL := (x2 - x1) * dyinv; dxR := (x2 - x3) * dyinv;
					dtxStart := (tx2 - tx1) * dyinv; dtyStart := (ty2 - ty1) * dyinv;
					dzinvStart := (zinv2 - zinv1) * dyinv;
				END;
				xStart := x1; xEnd := x3; txStart := tx1; tyStart := ty1;
				zinvStart := zinv1;

				IF y1 < 0 THEN
					xStart := xStart - y1 * dxL;
					xEnd := xEnd - y1 * dxR;
					txStart := txStart - y1 * dtxStart; tyStart := tyStart - y1 * dtyStart;
					zinvStart := zinvStart - y1 * dzinvStart;
					y1 := 0
				END;

				IF y2 > height THEN y2 := height END;
				adrBase := img.adr + stride * y1;
				zBufBase := ADDRESSOF(zBuffer[0]) + zStride * y1;
				invAdrBase := ADDRESSOF(invBuffer[0]) + invAdrStride * y1;
				IF tri.tex # NIL THEN FOR y := y1 TO y2 - 1 DO SubDivLineTex(tri.tex) END
				ELSE FOR y := y1 TO y2 - 1 DO SubDivLineFlat END
				END
			END;
		END SubDivTriangle;

		PROCEDURE SubDivLine*(a, b: Vertex);
		VAR tdx, tdy : LONGREAL;
			tv : Vertex;
			xr, yr, dxinv, dyinv, invdz, invaz, invbz, invz, z, dz, dx, dy : LONGREAL;
			iy, ix, i : LONGINT;
		CONST SubDiv = 8;
			SubDivInv = 1 / SubDiv;
		BEGIN
			tdx := ABS(b.x - a.x); tdy := ABS(b.y - a.y);
			IF tdx > tdy THEN
				IF a.x > b.x THEN tv := a; a := b; b := tv END;
				IF (a.x > width) OR (b.x < 0) THEN RETURN END;
				invaz := 1 / a.pt.z; invbz := 1 / b.pt.z;
				invz := invaz; z := a.pt.z;
				IF tdx > 0 THEN
					dxinv := 1 / tdx;
					invdz := (invbz - invaz) * dxinv; dz := (b.pt.z - a.pt.z) * dxinv; dy := (b.y - a.y) * dxinv
				ELSE invdz := 0; dz := 0; dy := 0
				END;

				xr := a.x; yr := a.y;
				IF xr < 0 THEN invz := invz - invdz * xr; yr := yr - dy * xr; xr := 0 END;

				z := 1 / invz;
				dz := ((1 / (invz + SubDiv * invdz)) - z) * SubDivInv;

				i := 0;
				FOR ix := ENTIER(xr) TO Min(width, ENTIER(b.x + 0.5)) - 1 DO
					INC(i);
					IF i = SubDiv THEN
						z := 1 / invz;
						dz := ((1 / (invz + SubDiv * invdz)) - z) * SubDivInv;
						i := 0;
					END;
					iy := ENTIER(yr);
					IF (iy > 0) & (iy < height) THEN
						IF zBuffer[iy * width + ix] > z THEN
							zBuffer[iy * width + ix] := SHORT(z);
							SYSTEM.PUT16(img.adr + img.bpr * iy + ix*2, color);
						END
					END;
					yr := yr + dy; invz := invz + invdz; z := z + dz
				END
			ELSE
				IF a.y > b.y THEN tv := a; a := b; b := tv END;
				IF (a.y > height) OR (b.y < 0) THEN RETURN END;

				invaz := 1 / a.pt.z;	invbz := 1 / b.pt.z;
				invz := invaz; z := a.pt.z;
				IF tdy > 0 THEN
					dyinv := 1 / tdy;
					invdz := (invbz - invaz) * dyinv; dz := (b.pt.z - a.pt.z) * dyinv; dx := (b.x - a.x) * dyinv
				ELSE invdz := 0; dz := 0; dx := 0
				END;

				xr := a.x; yr := a.y;
				IF yr < 0 THEN
					invz := invz - invdz * yr;
					xr := xr - dx * yr;
					yr := 0
				END;
				z := 1 / invz;
				dz := ((1 / (invz + SubDiv * invdz)) - z) * SubDivInv;

				i := 0;
				FOR iy := ENTIER(yr) TO Min(height, ENTIER(b.y + 0.5)) - 1 DO
					INC(i);
					IF i = SubDiv THEN
						z := 1 / invz;
						dz := ((1 / (invz + SubDiv * invdz)) - z) * SubDivInv;
						i := 0
					END;
					ix := ENTIER(xr);
					IF (ix > 0) & (ix < width) THEN
						IF zBuffer[iy * width + ix] > z THEN
							zBuffer[iy * width + ix] := SHORT(z);
							SYSTEM.PUT16(img.adr + img.bpr * iy + ix*2, color)
						END
					END;
					xr := xr + dx; invz := invz + invdz; z := z + dz
				END
			END
		END SubDivLine;

	END Rasterizer;

PROCEDURE Min(a, b: LONGINT): LONGINT;
BEGIN
	IF a < b THEN RETURN a ELSE RETURN b END
END Min;

END W3dRasterizer.
