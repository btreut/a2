MODULE WMShapes; (** AUTHOR "staubesv, PH"; PURPOSE "Basic geormetric shapes as visual components"; *)
(*! to do: thread safety*)
IMPORT
	Strings, XML, WMRectangles, WMGraphics, WMGraphicUtilities, WMProperties, WMComponents, Math, KernelLog;

TYPE
	(* generic line. can have an arrowhead on either end *)
	Line* = OBJECT(WMComponents.VisualComponent)
	VAR
		color- : WMProperties.ColorProperty;
		colorI : LONGINT;

		isVertical- : WMProperties.BooleanProperty;
		isVerticalI : BOOLEAN;
		
		start-, end-: WMProperties.PointProperty;
		startI, endI: WMGraphics.Point2d;
		
		arrowAtStart-, arrowAtEnd-:WMProperties.BooleanProperty;
		arrowAtStartI, arrowAtEndI: BOOLEAN;		

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMShapes.GenLine");
			SetNameAsString(StrLine);
			NEW(color, NIL, StrColor, StrLineColorDescription); properties.Add(color);
			color.Set(WMGraphics.Black); colorI := color.Get();
			NEW(isVertical, NIL, StrIsVertical, StrIsVerticalDescription); properties.Add(isVertical);
			isVertical.Set(FALSE); isVerticalI := isVertical.Get();
			NEW(start, NIL, StrStart, StrStartDescription); properties.Add(start);
			start.SetCoordinate(0,0); startI := start.Get();
			NEW(end, NIL, StrEnd, StrEndDescription); properties.Add(end);
			end.SetCoordinate(100,100); endI := end.Get();
			NEW(arrowAtStart, NIL, StrArrowStart, StrArrowStartDescription); properties.Add(arrowAtStart);
			arrowAtStart.Set(FALSE); arrowAtStartI := arrowAtStart.Get();
			NEW(arrowAtEnd, NIL, StrArrowEnd, StrArrowEndDescription); properties.Add(arrowAtEnd);
			arrowAtEnd.Set(TRUE); arrowAtEndI := arrowAtEnd.Get();
			PropertyChanged(SELF, start); (* recompute bounding box *)
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR dx, dy :LONGINT; rect, rect0: WMRectangles.Rectangle; 
		BEGIN
			IF (property = color) THEN colorI := color.Get(); Invalidate; 
			ELSIF (property = isVertical) THEN isVerticalI := isVertical.Get(); Invalidate;
			ELSIF (property = start) OR (property = end) THEN	 
				rect0:=bounds.Get();	startI := start.Get(); endI := end.Get();
				
				rect:=WMRectangles.MakeRect(MIN(startI.x,endI.x)+rect0.l-5, MIN(startI.y,endI.y)+rect0.t-5, MAX(startI.x, endI.x)+rect0.l+5, MAX(startI.y,endI.y)+rect0.t+5); (* add border for arrowhead display *)

				dx:=rect.l - rect0.l;
				dy:=rect.t - rect0.t;
				startI.x:=startI.x-dx; endI.x:=endI.x-dx;
				startI.y:=startI.y-dy; endI.y:=endI.y-dy;
				
				IF ~WMRectangles.IsEqual(rect,rect0) THEN bounds.Set(rect); END;
				start.Set(startI);
				end.Set(endI);
				Invalidate;
			ELSIF (property = arrowAtStart) THEN arrowAtStartI := arrowAtStart.Get(); Invalidate;
			ELSIF (property = arrowAtEnd) THEN	arrowAtEndI := arrowAtEnd.Get(); Invalidate;
			ELSE PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		(* position a line line in parent coordinates*)
		PROCEDURE Set*(x0,y0, x1, y1: LONGINT); 
		VAR rect:WMRectangles.Rectangle; changed:BOOLEAN;
		BEGIN
			rect:=bounds.Get(); 
			changed:=FALSE;
			IF (x0 # rect.l + startI.x) OR (y0#rect.t+startI.y) THEN start.SetCoordinate(x0-rect.l, y0-rect.t); changed:=TRUE END;
			IF (x1 # rect.l + endI.x) OR (y1#rect.t+endI.y) THEN end.SetCoordinate(x1-rect.l, y1-rect.t); changed:=TRUE END;
			IF changed THEN	PropertyChanged(SELF, start); PropertyChanged(SELF, end) END;
		END Set;
		
		(** Return if the line is hit at (x, y) in parent coordinates *)
		PROCEDURE IsHit*(x, y: LONGINT): BOOLEAN; 
		VAR r: WMRectangles.Rectangle; X0,Y0, X1,Y1: LONGINT; hit:BOOLEAN;
		BEGIN
			IF ~visible.Get() THEN hit:= FALSE 
			ELSE
				r:=GetClientRect();
				X0:=startI.x+r.l; Y0:=startI.y+r.t; 
				X1:=endI.x+r.l; Y1:=endI.y+r.t;
				IF X0=X1 THEN hit:=WMRectangles.PointInRect(x, y, r) & (2>ABS(x-X0))
				ELSIF Y0=Y1 THEN hit:=WMRectangles.PointInRect(x, y, r) & (2>ABS(y-Y0))
				ELSE hit:= WMRectangles.PointInRect(x, y, r) & (2>ABS((y-Y0) - ((x-X0)*(Y1-Y0)/(X1-X0))))
				END;
			END;
			RETURN hit;
		END IsHit;
		
		PROCEDURE SetArrowheads*(arrows:SET);
		BEGIN
			IF (0 IN arrows)#arrowAtStartI THEN arrowAtStart.Set(0 IN arrows); PropertyChanged(SELF, arrowAtStart); END;
			IF (1 IN arrows)#arrowAtEndI THEN arrowAtEnd.Set(1 IN arrows); PropertyChanged(SELF, arrowAtEnd); END;
		END SetArrowheads;
		
		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		CONST pi=3.1516; headscale= 0.25;
		VAR  alpha: REAL;
			dx,dy: LONGINT;
			size:LONGINT; head: LONGREAL;
		BEGIN
			DrawBackground^(canvas);
			IF (colorI # 0) THEN
				dx:=endI.x-startI.x; dy:=endI.y-startI.y;
				alpha:=arctan2(dx,dy);
				size:= 40; (*! to do: parametrize arrow size *)
				head:=size * headscale (*  + 2 *);
				canvas.Line(startI.x, startI.y, endI.x, endI.y, colorI, WMGraphics.ModeSrcOverDst);
				IF arrowAtEndI THEN
					canvas.Line(endI.x,endI.y, endI.x - ENTIER(0.5+head * Math.cos(alpha + pi/8)), endI.y - ENTIER(0.5+head * Math.sin(alpha + pi/8)), colorI, WMGraphics.ModeSrcOverDst);
					canvas.Line(endI.x,endI.y, endI.x - ENTIER(0.5+head * Math.cos(alpha - pi/8)), endI.y - ENTIER(0.5+head * Math.sin(alpha - pi/8)), colorI, WMGraphics.ModeSrcOverDst);
				END;
				IF arrowAtStartI THEN
					canvas.Line(startI.x,startI.y, startI.x + ENTIER(0.5+head * Math.cos(alpha + pi/8)), startI.y + ENTIER(0.5+head * Math.sin(alpha + pi/8)), colorI, WMGraphics.ModeSrcOverDst);
					canvas.Line(startI.x,startI.y, startI.x + ENTIER(0.5+head * Math.cos(alpha - pi/8)), startI.y + ENTIER(0.5+head * Math.sin(alpha - pi/8)), colorI, WMGraphics.ModeSrcOverDst);
				END
			END;
		END DrawBackground;

	END Line;

TYPE

	Rectangle* = OBJECT(WMComponents.VisualComponent)
	VAR
		clBorder- : WMProperties.ColorProperty;
		clBorderI : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetGenerator("WMShapes.GenRectangle");
			SetNameAsString(StrRectangle);
			NEW(clBorder, NIL, StrClBorder, StrClBorderDescription); properties.Add(clBorder);
			clBorder.Set(WMGraphics.Black); clBorderI := clBorder.Get();
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = clBorder) THEN
				clBorderI := clBorder.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			DrawBackground^(canvas);
			IF (clBorderI # 0) THEN
				rect := GetClientRect();
				WMGraphicUtilities.DrawRect(canvas, rect, clBorderI, WMGraphics.ModeSrcOverDst);
			END;
		END DrawBackground;

	END Rectangle;

TYPE

	Circle* = OBJECT(WMComponents.VisualComponent)
	VAR
		color : WMProperties.ColorProperty;
		colorI : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetGenerator("WMShapes.GenCircle");
			SetNameAsString(StrCircle);
			NEW(color, NIL, Strings.NewString("Color"), Strings.NewString("Color")); properties.Add(color);
			color.Set(WMGraphics.Black); colorI := color.Get();
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = color) THEN
				colorI := color.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR rect : WMRectangles.Rectangle; radius : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			IF (colorI # 0) THEN
				rect := bounds.Get();
				canvas.SetColor(colorI);
				radius := Strings.Min((rect.r - rect.l) DIV 2, (rect.b - rect.t) DIV 2) - 1;
				WMGraphicUtilities.Circle(canvas, (rect.r - rect.l) DIV 2, (rect.b - rect.t) DIV 2, radius);
			END;
		END DrawBackground;

	END Circle;

TYPE

	Ellipse* = OBJECT(WMComponents.VisualComponent)
	VAR
		color : WMProperties.ColorProperty;
		colorI : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetGenerator("WMShapes.GenEllipse");
			SetNameAsString(StrEllipse);
			NEW(color, NIL, StrColor, StrColorDescription);
			color.Set(WMGraphics.Black); colorI := color.Get();
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = color) THEN
				colorI := color.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			DrawBackground^(canvas);
			IF (colorI # 0) THEN
				rect := bounds.Get();
				canvas.SetColor(colorI);
				WMGraphicUtilities.Ellipse(canvas, (rect.r - rect.l) DIV 2, (rect.b - rect.t) DIV 2, (rect.r - rect.l) DIV 2 - 1, (rect.b - rect.t) DIV 2 - 1);
			END;
		END DrawBackground;

	END Ellipse;

VAR
	StrLine, StrRectangle, StrCircle, StrEllipse : Strings.String;
	StrClBorder, StrClBorderDescription, StrColor, StrColorDescription, StrLineColorDescription,
	StrIsVertical, StrIsVerticalDescription,
	StrStart,StrEnd,StrArrowStart, StrArrowEnd,
	StrStartDescription, StrEndDescription, StrArrowStartDescription,StrArrowEndDescription: Strings.String;

PROCEDURE GenLine*() : XML.Element;
VAR line : Line;
BEGIN
	NEW(line); RETURN line;
END GenLine;

PROCEDURE GenRectangle*() : XML.Element;
VAR rectangle : Rectangle;
BEGIN
	NEW(rectangle); RETURN rectangle;
END GenRectangle;

PROCEDURE GenCircle*() : XML.Element;
VAR circle : Circle;
BEGIN
	NEW(circle); RETURN circle;
END GenCircle;

PROCEDURE GenEllipse*() : XML.Element;
VAR ellipse : Ellipse;
BEGIN
	NEW(ellipse); RETURN ellipse;
END GenEllipse;

PROCEDURE InitStrings;
BEGIN
	StrLine := Strings.NewString("Line");
	StrRectangle := Strings.NewString("StrRectangle");
	StrCircle := Strings.NewString("StrCircle");
	StrEllipse := Strings.NewString("StrEllipse");
	StrClBorder := Strings.NewString("ClBorder");
	StrClBorderDescription := Strings.NewString("Border color");
	StrColor := Strings.NewString("Color");
	StrColorDescription := Strings.NewString("Color");
	StrLineColorDescription := Strings.NewString("Color of line");
	StrStart := Strings.NewString("LineStart");
	StrStartDescription := Strings.NewString("start point of line");
	StrEnd := Strings.NewString("LineEnd");
	StrEndDescription := Strings.NewString("end point of line");
	StrArrowStart := Strings.NewString("ArrowAtStart");
	StrArrowStartDescription := Strings.NewString("arrows at start of line ?");
	StrArrowEnd := Strings.NewString("ArrowAtEnd");
	StrArrowEndDescription := Strings.NewString("arrows at end of line ?");
	StrIsVertical := Strings.NewString("IsVertical");
	StrIsVerticalDescription := Strings.NewString("Horizontal or vertical line?");
END InitStrings;

PROCEDURE arctan2(x,y: REAL): REAL; (*arctan in range 0..2pi*)
	BEGIN
		IF (x>0) & (y>=0) THEN RETURN Math.arctan(y/x)
		ELSIF (x>0) & (y<0) THEN RETURN Math.arctan(y/x)+2*Math.pi
		ELSIF x<0 THEN RETURN Math.arctan(y/x)+Math.pi
		ELSIF (x=0) & (y>0) THEN RETURN Math.pi/2
		ELSIF (x=0) & (y<0) THEN RETURN 3*Math.pi/2
		ELSE (*( x=0) & (y=0) *) RETURN 0 (*or RETURN NaN ?*) 
		END
	END arctan2;

BEGIN
	InitStrings;
END WMShapes.

SystemTools.FreeDownTo WMShapes ~
