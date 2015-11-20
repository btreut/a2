(**
	AUTHOR: "Alexey Morozov";
	PURPOSE: "Smooth (antialiased) graphics";
*)
MODULE WMGraphicsSmooth;

IMPORT Raster, Strings, WMGraphics, WMWindowManager, Math;

TYPE

	(**
		Cancas used for smooth (antialiased) graphics
	*)
	Canvas* = OBJECT(WMGraphics.BufferCanvas)
	VAR
		lineWidth-: REAL; (** line width in pixels *)

		kernelRadius: REAL; (* radius of the smoothing kernel in pixels *)
		rmode: Raster.Mode;

		PROCEDURE &New*(img : Raster.Image);
		BEGIN
			New^(img);
			generator := Strings.NewString("WMGraphicsSmooth.GenCanvas");
			kernelRadius := 1.0;
			rmode.op := WMGraphics.ModeCopy;
			SetLineWidth(1.0);
			SetColor(WMGraphics.Blue);
		END New;

		(**
			Set line width in pixels
		*)
		PROCEDURE SetLineWidth*(w: REAL);
		BEGIN
			IF w < 0.5 THEN w := 0.5; END;
			lineWidth := w;
		END SetLineWidth;

		(**
			Draw a smooth (antialiased) line

			Remark: parameter "mode" does not have any effect; ModeSrcOverDst is used in all cases
		*)
		PROCEDURE Line*(x0, y0, x1, y1: LONGINT; lineColor: WMGraphics.Color; mode: LONGINT); (*this is a heavy duty procedure that can be called millions of times in time-varying or scrolled graphs - optimize*)
		VAR
			xr0, yr0, xr1, yr1: REAL;
			pix: Raster.Pixel;
			r, g, b, a: LONGINT;
			dxr, dyr, grad, c, n, s02, b02, b13, v: REAL;
			d00, d10, d20, d30, d0, d1, d2, d3, d02, d13: REAL;
			xi, xiend, yi, yyi: LONGINT;

			PROCEDURE HorizontalLine;
			VAR
				d, xi0, xi1, yi0, yi1: LONGINT;
			BEGIN
				IF xr0 <= xr1 THEN
					xi0 := ENTIER(xr0+0.5); xi1 := ENTIER(xr1+0.5);
				ELSE
					xi0 := ENTIER(xr1+0.5); xi1 := ENTIER(xr0+0.5);
				END;

				yi0 := ENTIER((yr0-0.5*lineWidth)+0.5);
				yi1 := ENTIER((yi0 + lineWidth-1)+0.5);
				yi0 := MAX(0,yi0);
				yi1 := MIN(limits.b-1,yi1);

				xi0 := MAX(0,xi0); xi1 := MIN(limits.r-1,xi1);

				IF yi0 = yi1 THEN
					FOR xi0 := xi0 TO xi1 DO Raster.Put(img,xi0,yi0,pix,rmode); END;
				ELSE
					FOR yi0 := yi0 TO yi1 DO
						FOR d := xi0 TO xi1 DO Raster.Put(img,d,yi0,pix,rmode); END;
					END;
				END;
			END HorizontalLine;

			PROCEDURE VerticalLine;
			VAR
				d, xi0, xi1, yi0, yi1: LONGINT;
			BEGIN
				IF yr0 <= yr1 THEN
					yi0 := ENTIER(yr0+0.5); yi1 := ENTIER(yr1+0.5);
				ELSE
					yi0 := ENTIER(yr1+0.5); yi1 := ENTIER(yr0+0.5);
				END;

				xi0 := ENTIER(xr0-0.5*lineWidth+0.5);
				xi1 := ENTIER((xi0 + lineWidth - 1)+0.5);
				xi0 := MAX(0,xi0);
				xi1 := MIN(limits.r-1,xi1);

				yi0 := MAX(0,yi0); yi1 := MIN(limits.b-1,yi1);

				IF xi0 = xi1 THEN
					FOR yi0 := yi0 TO yi1 DO Raster.Put(img,xi0,yi0,pix,rmode); END;
				ELSE
					FOR yi0 := yi0 TO yi1 DO
						FOR d := xi0 TO xi1 DO Raster.Put(img,d,yi0,pix,rmode); END;
					END;
				END;
			END VerticalLine;

		BEGIN
			IF lineColor # color THEN
				SetColor(lineColor);
			END;

			xr0 := x0; yr0 := y0; xr1 := x1; yr1 := y1;

			(* change to the global coordinate system *)
			xr0 := xr0 + SELF.dx; yr0 := yr0 + SELF.dy;
			xr1 := xr1 + SELF.dx; yr1 := yr1 + SELF.dy;

			(* does the line cross the canvas rectangle? *)
			IF ~LineRectIntersection(limits.l,limits.t,limits.r-1,limits.b-1,xr0,yr0,xr1,yr1)
			THEN (*! TODO: handle cases of thick lines, where LineRectIntersection can return FALSE while the thick line intersect the canvas *)
				RETURN;
			END;

			IF rmode.op # Raster.srcOverDst THEN
				Raster.InitMode(rmode,Raster.srcOverDst); (* use ModeSrcOverDst in all cases *)
			END;

			(* prepare pixel *)
			WMGraphics.ColorToRGBA(color,r,g,b,a);
			Raster.SetRGBA(pix,r,g,b,a);

			IF xr0 > xr1 THEN
				dxr := xr0; xr0 := xr1; xr1 := dxr;
				dyr := yr0; yr0 := yr1; yr1 := dyr;
			END;

			dxr := xr1 - xr0;
			dyr := yr1 - yr0;

			IF dyr = 0 THEN (* horizontal line *)
				HorizontalLine; (*! TODO: smooth horizontal lines too - for esthetic reasons *)
			ELSIF dxr = 0 THEN (* vertical line *)
				VerticalLine; (*! TODO: smooth vertical lines too - for esthetic reasons *)
			ELSE
				n := Math.sqrt(dxr*dxr+dyr*dyr);
				c := 1.0/n;
				dxr := dxr*c;
				dyr := dyr*c;
				grad := dyr/dxr;
				c := 0.5*lineWidth+kernelRadius;

				(* distance scaling factor *)
				IF lineWidth >= 2.0*kernelRadius THEN s02 := 1.0/(2.0*kernelRadius);
				ELSE s02 := 1.0/c; END;

				b02 := yr0*dxr-xr0*dyr;
				b13 := -(xr0*dxr+yr0*dyr);

				xi := ENTIER(xr0+0.5);
				xiend := ENTIER(xr1+0.5);
				WHILE xi <= xiend DO

					yi := ENTIER(yr0+0.5);

					d00 := xi*dyr - yi*dxr + b02;
					d20 := d00 + c;
					d00 := c - d00;

					d10 := xi*dxr+yi*dyr+b13;
					d30 := 1.0+n-d10;
					d10 := 1.0+d10;

					d02 := MIN(d00,d20); d13 := MIN(d10,d30);
					IF (d02 > 0) & (d13 > 0) & (yi >= limits.t) & (yi < limits.b) THEN
						v := d02*s02;
						IF v > 1.0 THEN v := 1.0; END;
						v := v*v; (* inverse quadratic intensity mapping *)
						a := ENTIER(v*255+0.5);
						Raster.SetRGBA(pix,r,g,b,a);

						IF (xi >= 0) & (xi < img.width) & (yi >= 0) & (yi < img.height) THEN
							Raster.Put(img,xi,yi,pix,rmode);
						END;
					END;

					yyi := yi + 1;
					(* avoid direct evaluation of the distance functions by using neighbor evaluation *)
					d0 := d00 + dxr; d2 := d20 - dxr; d1 := d10 + dyr; d3 := d30 - dyr;
					d02 := MIN(d0,d2); d13 := MIN(d1,d3);
					WHILE d02 > 0 DO

						IF (d13 > 0) & (yyi >= limits.t) & (yyi < limits.b) THEN
							v := d02*s02;
							IF v > 1.0 THEN v := 1.0; END;
							v := v*v; (* inverse quadratic intensity mapping *)
							a := ENTIER(v*255+0.5);
							Raster.SetRGBA(pix,r,g,b,a);

							IF (xi >= 0) & (xi < img.width) & (yyi >= 0) & (yyi < img.height) THEN
								Raster.Put(img,xi,yyi,pix,rmode);
							END;
						END;

						INC(yyi);
						d0 := d0 + dxr; d2 := d2 - dxr; d1 := d1 + dyr; d3 := d3 - dyr;
						d02 := MIN(d0,d2); d13 := MIN(d1,d3);
					END;

					yyi := yi - 1;
					d0 := d00 - dxr; d2 := d20 + dxr; d1 := d10 - dyr; d3 := d30 + dyr;
					d02 := MIN(d0,d2); d13 := MIN(d1,d3);
					WHILE d02 > 0 DO

						IF (d13 > 0) & (yyi >= limits.t) & (yyi < limits.b) THEN
							v := d02*s02;
							IF v > 1.0 THEN v := 1.0; END;
							v := v*v; (* inverse quadratic intensity mapping *)
							a := ENTIER(v*255+0.5);
							Raster.SetRGBA(pix,r,g,b,a);

							IF (xi >= 0) & (xi < img.width) & (yyi >= 0) & (yyi < img.height) THEN
								Raster.Put(img,xi,yyi,pix,rmode);
							END;
						END;

						DEC(yyi);
						d0 := d0 - dxr; d2 := d2 + dxr; d1 := d1 - dyr; d3 := d3 + dyr;
						d02 := MIN(d0,d2); d13 := MIN(d1,d3);
					END;

					yr0 := yr0 + grad;
					INC(xi);
				END;
			END;

		END Line;

	END Canvas;

	PROCEDURE GenCanvas*(img:Raster.Image):WMGraphics.BufferCanvas; (* generator procedure *)
	VAR c:Canvas;
	BEGIN
		NEW(c,img); RETURN c (* img is NIL, needs a call of c.New(img) later on *)
	END GenCanvas;

	(*
		Find intersection of a line with a given rectangle

		l, r, t, b: left,right,top,bottom coordinates of the rectangle
		x0, y0: starting line point
		x1, y1: end line point

		Intersection points are returned in x0, y0, x1, y1
	*)
	PROCEDURE LineRectIntersection(l, t, r, b: REAL; VAR x0, y0, x1, y1: REAL): BOOLEAN;
	VAR
		dy, dx, x00, y00: REAL;
	BEGIN

		dx := x1 - x0;
		dy := y1 - y0;

		IF dy = 0 THEN (* horizontal line *)
			IF (y0 >= t) & (y0 <= b) THEN
				IF x0 <= x1 THEN
					RETURN (x0 <= r) & (x1 >= l);
				ELSE
					RETURN (x1 <= r) & (x0 >= l);
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSIF dx = 0 THEN (* vertical line *)
			IF (x0 >= l) & (x0 <= r) THEN
				IF y0 <= y1 THEN
					RETURN (y0 <= b) & (y1 >= t);
				ELSE
					RETURN (y1 <= b) & (y0 >= t);
				END;
			ELSE
				RETURN FALSE;
			END;
		ELSE

			IF x0 < x1 THEN
				IF (x0 <= r) & (x1 >= l) THEN
					IF y0 <= y1 THEN

						IF (y0 <= b) & (y1 >= t) THEN
							x00 := x0;
							y00 := y0;

							IF x0 < l THEN
								(* intersection with x = left *)
								y0 := y00 + (dy*(l-x00)) / dx; x0 := l;
								IF y0 < t THEN
									(* intersection with y = tody *)
									x0 := x00 + (dx*(t-y00)) / dy; y0 := t;
								END;
							ELSIF y0 < t THEN
								(* intersection with y = tody *)
								x0 := x00 + (dx*(t-y00)) / dy; y0 := t;
								IF x0 < l THEN
									(* intersection with x = left *)
									y0 := y00 + (dy*(l-x00)) / dx; x0 := l;
								END;
							END;


							IF x1 > r THEN
								(* intersection with x = right *)
								y1 := y00 + (dy*(r-x00)) / dx; x1 := r;
								IF y1 > b THEN
									(* intersection with y = bottom *)
									x1 := x00 + (dx*(b-y00)) / dy; y1 := b;
								END;
							ELSIF y1 > b THEN
								(* intersection with y = bottom *)
								x1 := x00 + (dx*(b-y00)) / dy; y1 := b;
								IF x1 > r THEN
								(* intersection with x = right *)
									y1 := y00 + (dy*(r-x00)) / dx; x1 := r;
								END;
							END;

							ASSERT(x0 >= l);
							ASSERT(y0 >= t);
							ASSERT(x1 <= r);
							ASSERT(y1 <= b);

						ELSE
							RETURN FALSE;
						END;

					ELSIF (y1 <= b) & (y0 >= t) THEN (* y0 > y1, dy < 0 *)

						x00 := x0;
						y00 := y0;
						dy := -dy;

						IF x0 < l THEN
							(* intersection with x = left *)
							y0 := y00 - (dy*(l-x00)) / dx; x0 := l;
							IF y0 > b THEN
								(* intersection with y = bottom *)
								x0 := x00 - (dx*(b-y00)) / dy; y0 := b;
							END;
						ELSIF y0 > b THEN
							(* intersection with y = bottom *)
							x0 := x00 - (dx*(b-y00)) / dy; y0 := b;
							IF x0 < l THEN
								(* intersection with x = left *)
								y0 := y00 - (dy*(l-x00)) / dx; x0 := l;
							END;
						END;

						IF x1 > r THEN
							(* intersection with x = right *)
							y1 := y00 - (dy*(r-x00)) / dx; x1 := r;
							IF y1 < t THEN
								(* intersection with y = tody *)
								x1 := x00 - (dx*(t-y00)) / dy; y1 := t;
							END;
						ELSIF y1 < t THEN
							(* intersection with y = tody *)
							x1 := x00 - (dx*(t-y00)) / dy; y1 := t;
							IF x1 > r THEN
								(* intersection with x = right *)
								y1 := y00 - (dy*(r-x00)) / dx; x1 := r;
							END;
						END;

						ASSERT(x0 >= l);
						ASSERT(y0 <= b);
						ASSERT(x1 <= r);
						ASSERT(y1 >= t);

					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;

			ELSE (* x0 >= x1 *)

				IF (x1 <= r) & (x0 >= l) THEN

					IF y0 <= y1 THEN

						IF (y0 <= b) & (y1 >= t) THEN

							x00 := x0;
							y00 := y0;
							dx := -dx;

							IF x0 > r THEN
								(* intersection with x = right *)
								y0 := y00 - (dy*(r-x00)) / dx; x0 := r;
								IF y0 < t THEN
									(* intersection with y = tody *)
									x0 := x00 - (dx*(t-y00)) / dy; y0 := t;
								END;
							ELSIF y0 < t THEN
								(* intersection with y = tody *)
								x0 := x00 - (dx*(t-y00)) / dy; y0 := t;
								IF x0 > r THEN
									(* intersection with x = right *)
									y0 := y00 - (dy*(r-x00)) / dx; x0 := r;
								END;
							END;

							IF x1 < l THEN
								(* intersection with x = left *)
								y1 := y00 - (dy*(l-x00)) / dx; x1 := l;
								IF y1 > b THEN
									(* intersection with y = bottom *)
									x1 := x00 - (dx*(b-y00)) / dy; y1 := b;
								END;
							ELSIF y1 > b THEN
								(* intersection with y = bottom *)
								x1 := x00 - (dx*(b-y00)) / dy; y1 := b;
								IF x1 < l THEN
									(* intersection with x = left *)
									y1 := y00 - (dy*(l-x00)) / dx; x1 := l;
								END;
							END;

							ASSERT(x0 <= r);
							ASSERT(y0 >= t);
							ASSERT(x1 >= l);
							ASSERT(y1 <= b);

						ELSE
							RETURN FALSE;
						END;

					ELSIF (y1 <= b) & (y0 >= t) THEN (* dy < 0, dx < 0 *)

						x00 := x0;
						y00 := y0;
						dy := -dy;
						dx := -dx;

						IF x0 > r THEN
							(* intersection with x = right *)
							y0 := y00 + (dy*(r-x00)) / dx; x0 := r;
							IF y0 > b THEN
								(* intersection with y = bottom *)
								x0 := x00 + (dx*(b-y00)) / dy; y0 := b;
							END;
						ELSIF y0 > b THEN
							(* intersection with y = bottom *)
							x0 := x00 + (dx*(b-y00)) / dy; y0 := b;
							IF x0 > r THEN
								(* intersection with x = right *)
								y0 := y00 + (dy*(r-x00)) / dx; x0 := r;
							END;
						END;

						IF x1 < l THEN
							(* intersection with x = left *)
							y1 := y00 + (dy*(l-x00)) / dx; x1 := l;
							IF y1 < t THEN
								(* intersection with y = tody *)
								x1 := x00 + (dx*(t-y00)) / dy; y1 := t;
							END;
						ELSIF y1 < t THEN
							(* intersection with y = tody *)
							x1 := x00 + (dx*(t-y00)) / dy; y1 := t;
							IF x1 < l THEN
								(* intersection with x = left *)
								y1 := y00 + (dy*(l-x00)) / dx; x1 := l;
							END;
						END;

						ASSERT(x0 <= r);
						ASSERT(y0 <= b);
						ASSERT(x1 >= l);
						ASSERT(y1 >= t);

					ELSE
						RETURN FALSE;
					END;
				ELSE
					RETURN FALSE;
				END;
			END;
		END;

		RETURN TRUE
	END LineRectIntersection;

END WMGraphicsSmooth.

