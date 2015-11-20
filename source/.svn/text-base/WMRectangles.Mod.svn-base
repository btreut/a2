MODULE WMRectangles; (** AUTHOR "TF"; PURPOSE "Basic rectangles that are used by the WM and visual components"; *)

TYPE
	Rectangle* = RECORD l*, t*, r*, b*: LONGINT END;
		(* It is important to understand and respect that the point (r,b) is not included in the rectangle !
			This is to ensure consistency between the continuous and discrete case
		*)

	PROCEDURE Min(a, b:LONGINT):LONGINT;
	BEGIN
		IF a<b THEN RETURN a ELSE RETURN b END;
	END Min;

	PROCEDURE Max(a, b:LONGINT):LONGINT;
	BEGIN
		IF a>b THEN RETURN a ELSE RETURN b END;
	END Max;

	(** move the rectangle by deltaX, deltaY *)
	PROCEDURE MoveRel*(VAR x:Rectangle; deltaX, deltaY:LONGINT);
	BEGIN
		x.l:=x.l+deltaX; x.t:=x.t+deltaY; x.r:=x.r+deltaX; x.b:=x.b+deltaY
	END MoveRel;

	PROCEDURE Bound(VAR x:LONGINT; min, max:LONGINT);
	BEGIN
		IF x<min THEN x:=min ELSE IF x>max THEN x:=max END END
	END Bound;

	(** Clip rectangle rect at the boundary bounds *)
	PROCEDURE ClipRect*(VAR rect, bounds : Rectangle);
	BEGIN
		Bound(rect.l, bounds.l, bounds.r);Bound(rect.r, bounds.l, bounds.r);
		Bound(rect.t, bounds.t, bounds.b);Bound(rect.b, bounds.t, bounds.b)
	END ClipRect;

	(** return true if rectangle x is empty *)
	PROCEDURE RectEmpty*(x : Rectangle) : BOOLEAN;
	BEGIN
		RETURN (x.t >= x.b) OR (x.l >= x.r)
	END RectEmpty;

	(** return true if x and y are inside rect *)
	PROCEDURE PointInRect*(x, y : LONGINT; rect : Rectangle) : BOOLEAN;
	BEGIN
		RETURN (x >= rect.l) & (x < rect.r) & (y >= rect.t) & (y < rect.b)
	END PointInRect;

	(** return true if the inner rectangle is completely inside the outer *)
	PROCEDURE IsContained*(VAR outer, inner : Rectangle) : BOOLEAN;
	BEGIN
		RETURN (outer.l <= inner.l) & (outer.r >= inner.r) &
					 (outer.t <= inner.t) & (outer.b >= inner.b)
	END IsContained;

	PROCEDURE IsEqual*(CONST a, b : Rectangle) : BOOLEAN;
	BEGIN
		RETURN (a.l = b.l) & (a.r = b.r) & (a.t = b.t) & (a.b = b.b)
	END IsEqual;

	(** return whether a and be intersect and not only touche *)
	PROCEDURE Intersect*(VAR a, b : Rectangle) : BOOLEAN;
	BEGIN
		RETURN (a.l < b.r) & (a.r > b.l) & (a.t < b.b) & (a.b > b.t)
	END Intersect;

	(** Set rect to (l, t, r, b) *)
	PROCEDURE SetRect*(VAR rect : Rectangle; l, t, r, b : LONGINT);
	BEGIN
		rect.l := l; rect.t := t; rect.r := r; rect.b := b
	END SetRect;

	(** return the area of r. Overflow if r w * h > MAX(LONGINT) *)
	PROCEDURE Area*(VAR r : Rectangle) : LONGINT;
	BEGIN
		RETURN (r.r - r.l) * (r.b - r.t)
	END Area;

	(** Extend old to contain addition *)
	PROCEDURE ExtendRect*(VAR old, addition : Rectangle);
	BEGIN
		old.l := Min(old.l, addition.l); old.r := Max(old.r,addition.r);
		old.t := Min(old.t, addition.t); old.b := Max(old.b, addition.b)
	END ExtendRect;

	(** return the Rectangle (l, t, r, b) *)
	PROCEDURE MakeRect*(l, t, r, b: LONGINT) : Rectangle;
	VAR result : Rectangle;
	BEGIN
		result.l := l; result.t := t; result.r := r; result.b := b; RETURN result
	END MakeRect;

	(** extend the rectangle by units in each direction *)
	PROCEDURE ResizeRect*(x : Rectangle; units : LONGINT) : Rectangle;
	VAR t : Rectangle;
	BEGIN
		t.l := x.l - units; t.t := x.t - units; t.r := x.r + units; t.b := x.b + units;
		RETURN t
	END ResizeRect;

	PROCEDURE Normalize*(VAR rect: Rectangle);
	VAR
		temp: LONGINT;
	BEGIN
		IF rect.l > rect.r THEN
			temp := rect.l;
			rect.l := rect.r;
			rect.r := temp;
		END;

		IF rect.t > rect.b THEN
			temp := rect.t;
			rect.t := rect.b;
			rect.b := temp;
		END;
	END Normalize;

END WMRectangles.
