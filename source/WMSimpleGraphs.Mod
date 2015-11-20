MODULE WMSimpleGraphs;	(** AUTHOR "Patrick Hunziker"; PURPOSE "Minimum-overhead graph drawing and storing"; *)

(** right-click on navigator thumbnail allows window storage as image file *)

(*ToDo: ticks for Graph. labels on axes *)
(*ToDo: catch NaN and Inf in data and other strategies to avoid erratic window sizes*)

IMPORT Strings, WMGraphics, WMRectangles, Modules, Reals, WM:=WMWindowManager, MathL;

CONST Colors=[WMGraphics.Red,WMGraphics.Blue,WMGraphics.Green,WMGraphics.Yellow, WMGraphics.Magenta, WMGraphics.Cyan, WMGraphics.Gray];

TYPE 
	Regressor=PROCEDURE{DELEGATE}(CONST data: ARRAY [*,*] OF LONGREAL; VAR slope,intercept: LONGREAL);

TYPE
	Window=OBJECT(WM.Window);
	VAR width,height:LONGINT;
	END Window;
	
	Histogram* = OBJECT (Window);
	VAR 
		data:ARRAY [*] OF LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		VAR max:LONGREAL; 
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			width:=LEN(data,0); height:=ENTIER(max)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			FOR i:=0 TO LEN(data,0)-1 DO
				canvas.Fill(WMRectangles.MakeRect(      i*w DIV width , h-ENTIER(data[i]*h / height), 
														(i+1)*w DIV width , h), WMGraphics.Black, WMGraphics.ModeCopy);
			END;
			INC(timestamp);
		END Draw;
	END Histogram;
	
	(** display matrix values in checkerboard like fashion. positive values are in black/grey/white, negative values in red*)
	Matrix* = OBJECT (Window);
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		max,min, offset, gain:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			min:=MIN(data); max:=MAX(data);
			max:=MAX(ABS(min), ABS(max));
			min:=MIN(0, min); 
			IF max=0 THEN max:=1 END;
			width:=MAX(1,LEN(data,0)); 
			height:=MAX(1,LEN(data,1));
			Init(width, height, TRUE);
			offset:=0; gain:=255/max;
			IF( width<10) OR (height<10) THEN 
				bounds := WMGraphics.MakeRectangle(0, 0, 10*width, 10*height);(* grow small images *)
			END;
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR col: WMGraphics.Color; x,y:LONGINT; val:LONGREAL; valI:LONGINT;
		BEGIN
			FOR y:=0 TO LEN(data,0)-1 DO
				FOR x:=0 TO LEN(data,1)-1 DO
					val:=data[y,x]; IF Reals.IsNaNL(val) THEN val:=0 END;
					valI:=ENTIER(offset+gain*val);
					valI:=MAX(-255, MIN( 255, valI));
					IF valI>=0 THEN	col:=WMGraphics.RGBAToColor(valI,valI,valI,255);
					ELSE				col:=WMGraphics.RGBAToColor(-valI,0,0,255);
					END;
					canvas.Fill(WMRectangles.MakeRect(x*w DIV width, h-ENTIER(0.5+(y+1)*h/height),  
														(x+1)*w DIV width, h-ENTIER(0.5+y*h/height)), 
														col, WMGraphics.ModeCopy);
				END;
			END;
			INC(timestamp);
		END Draw;
	END Matrix;

	Graph* = OBJECT (Window);
	CONST border=5;
	VAR 
		data:ARRAY [*] OF LONGREAL;
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			min:=MIN(0, MIN(data)); 
			width:=LEN(data,0); height:=ENTIER(max-min)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT; mn,mx:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=-border+ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR i:=0 TO LEN(data,0)-2 DO
				canvas.Line(border+i*w DIV width, 	h+mn-ENTIER(0.5+data[i]*h / height),  
							border+(i+1)*w DIV width, h+mn-ENTIER(0.5+data[i+1]*h / height), 
							WMGraphics.Black, WMGraphics.ModeCopy);
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy);	END;
			INC(timestamp);
		END Draw;
END Graph;

Graphs* = OBJECT (Window);
	CONST border=5;
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		max,min:LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			max:=MAX(data);
			min:=MIN(0, MIN(data)); 
			width:=LEN(data,1); height:=ENTIER(max-min)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
		END New;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i,j:LONGINT; mn,mx:LONGINT;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			mn:=-border+ENTIER(0.5+min*h / height);
			mx:=ENTIER(0.5+max*h / height);
			FOR j:=0 TO LEN(data,0)-1 DO
				FOR i:=0 TO LEN(data,1)-2 DO
					canvas.Line(border+i*w DIV width, 	h+mn-ENTIER(0.5+data[j,i]*h / height),  
								border+(i+1)*w DIV width, h+mn-ENTIER(0.5+data[j,i+1]*h / height), 
								Colors[j MOD LEN(Colors,0)], WMGraphics.ModeCopy);
				END;
			END;
			IF mn#0 THEN canvas.Line(0, h+mn, w, h+mn, WMGraphics.Black, WMGraphics.ModeCopy); END;
			INC(timestamp);
		END Draw;
END Graphs;

GraphXY* = OBJECT (Window);
	CONST border=5;
	VAR 
		data:ARRAY [*,*] OF LONGREAL;
		minx,miny,maxx,maxy:LONGREAL;
		ticks: ARRAY [*,*] OF LONGREAL;

		PROCEDURE &New*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR);
		BEGIN
			SELF.data:=data;
			maxx:=MAX(0,MAX(data[0]));maxy:=MAX(0,MAX(data[1]));
			minx:=MIN(0, MIN(data[0])); miny:=MIN(0, MIN(data[1])); 
			width:=ENTIER(maxx-minx)+1; height:=ENTIER(maxy-miny)+1;
			Init(10*width, 10*height, FALSE);
			WM.GetDefaultManager().Add(PosX, PosY, SELF, {WM.FlagFrame,WM.FlagClose});
			NewWindowPos(GetWidth());
			SetTitle(Strings.NewString(title));
			SetPointerInfo(manager.pointerCrosshair);
			ticks:=GetTicks(data);
		END New;
		
		PROCEDURE Axes(canvas: WMGraphics.Canvas; w,h,mnw,mnh:LONGINT; scalex,scaley:REAL);
		VAR i:LONGINT;
		BEGIN
			IF mnh#0 THEN canvas.Line(0, h+mnh, w, h+mnh, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			IF mnw#0 THEN canvas.Line(-mnw, 0, -mnw, h, WMGraphics.Black, WMGraphics.ModeCopy)	END;
			FOR i:=0 TO LEN(ticks,1)-1 DO 
				canvas.Line(-mnw+ENTIER(0.5+ticks[0,i]*scalex), h+mnh-1, -mnw+ENTIER(0.5+ticks[0,i]*scalex), h+mnh+1, WMGraphics.Black, WMGraphics.ModeCopy); (* ticks are at multiples of largest decimal unit *)
				canvas.Line(-mnw-1, h+mnh-ENTIER(0.5+ticks[1,i]*scaley), -mnw+1, h+mnh-ENTIER(0.5+ticks[1,i]*scaley), WMGraphics.Black, WMGraphics.ModeCopy)
			END;
		END Axes;
		
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT; mnw,mnh,mxw,mxh:LONGINT; scalex,scaley:REAL;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			scalex:=w/width; scaley:=h/height;
			mnw:=-border+ENTIER(0.5+minx* scalex);	mxw:=ENTIER(0.5+maxx* scalex);
			mnh:=-border+ENTIER(0.5+miny* scaley);	mxh:=ENTIER(0.5+maxy* scaley);
			FOR i:=0 TO LEN(data,1)-2 DO
				canvas.Line(-mnw+ENTIER(0.5+data[0,i]*scalex), 	h+mnh-ENTIER(0.5+data[1,i]*scaley),  
							-mnw+ENTIER(0.5+data[0,i+1]*scalex), h+mnh-ENTIER(0.5+data[1,i+1]*scaley), 
							WMGraphics.Blue, WMGraphics.ModeCopy);
			END;
			Axes(canvas, w,h,mnw,mnh,scalex,scaley);
			INC(timestamp);
		END Draw;
END GraphXY;

	(** scatter plot with optional error bars. 
	data[0,..]: x coordinates
	data[1,..]: y coordinates
	optional data[2,..]: y error bars
	optional data[3,..]: x error bars *)
TYPE Scatter* = OBJECT (GraphXY);
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		VAR i:LONGINT; mnw,mnh,mxw,mxh, x,y, ex,ey:LONGINT; scalex,scaley:REAL; rect:WMRectangles.Rectangle;
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), WMGraphics.White, WMGraphics.ModeCopy);
			scalex:=w/width; 
			scaley:=h/height;
			mnw:=-border+ENTIER(0.5+minx* scalex);	mxw:=ENTIER(0.5+maxx* scalex);
			mnh:=-border+ENTIER(0.5+miny* scaley);	mxh:=ENTIER(0.5+maxy* scaley);
			FOR i:=0 TO LEN(data,1)-1 DO
				x:=-mnw+ENTIER(0.5+data[0,i]*scalex);
				y:=h+mnh-ENTIER(0.5+data[1,i]*scaley);
				WMRectangles.SetRect(rect, x-1,y-1,x+2,y+2 );
				canvas.Fill(rect, WMGraphics.Black, WMGraphics.ModeCopy);
				IF LEN(data,0)>2 THEN (* vertical error bars*)
					ey:=ENTIER(0.5+data[2,i]*scaley);
					canvas.Line(x, y-ey, x, y+ey,WMGraphics.Blue, WMGraphics.ModeCopy);  
					IF LEN(data,0)>3 THEN (*horizontal error bars*)
						ex:=ENTIER(0.5+data[3,i]*scalex);
						canvas.Line(x-ex, y, x+ex, y,WMGraphics.Red, WMGraphics.ModeCopy);  
					END;
				END;
			END;
			Axes(canvas,w,h,mnw,mnh,scalex,scaley); 
			INC(timestamp);
		END Draw;
END Scatter;

(** Regression plot. requires computation of slope,intercept by suited procedure, e.g. derived from /Matrix/StatisticsLinearRegression.SimpleRegression()  *)
TYPE Regression*= OBJECT (Scatter)
	VAR slope,intercept: LONGREAL;
	
	PROCEDURE &Initialize*(CONST data: ARRAY [*,*] OF LONGREAL; CONST title: ARRAY OF CHAR; regressor:Regressor);
	BEGIN
		New(data,title);
		regressor(data,slope,intercept);
	END Initialize;
	
	PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
	VAR mnw,mnh,x,y,xx,yy:LONGINT; scalex,scaley, x0, y0, x1, y1:LONGREAL; 
	BEGIN
		Draw^(canvas,w,h,q);
		x0:= minx; y0:= x0*slope+intercept;
		IF (y0<miny) THEN y0:=miny; x0:=(y0-intercept)/slope;
		ELSIF y1>maxy THEN y0:=maxy; x0:=(y0-intercept)/slope;
		END;
		x1:=maxx; y1:=x1*slope+intercept;
		IF (y1<miny) THEN y1:=miny; x1:=(y1-intercept)/slope;
		ELSIF y1>maxy THEN y1:=maxy; x1:=(y1-intercept)/slope;
		END;
		scalex:=w/width; scaley:=h/height;
		mnw:=-border+ENTIER(0.5+minx* scalex); mnh:=-border+ENTIER(0.5+miny* scaley);	
		x:=-mnw+ENTIER(0.5+x0*scalex);  y:=h+mnh-ENTIER(0.5+y0*scaley);
		xx:=-mnw+ENTIER(0.5+x1*scalex); yy:=h+mnh-ENTIER(0.5+y1*scaley);
		canvas.Line(x,y,xx,yy,WMGraphics.Red, WMGraphics.ModeCopy);  
	END Draw;	
	END Regression;

PROCEDURE NewWindowPos(dx:LONGINT);
BEGIN
	INC(Pos,dx);
	PosX:=Pos MOD 900;
	PosY:=100+ (Pos DIV 900)*100 MOD 700;
END NewWindowPos;

PROCEDURE Log10(x:LONGREAL):LONGREAL;
BEGIN RETURN MathL.ln(x)/MathL.ln(10);
END Log10;

PROCEDURE Exp10(x:LONGREAL):LONGREAL;
BEGIN RETURN MathL.exp(ENTIER(x)*MathL.ln(10));
END Exp10;

PROCEDURE GetTicks(CONST data: ARRAY [*,*] OF LONGREAL): ARRAY [*, *] OF LONGREAL; (*ticks along X, along Y, at decimal units*)
VAR maxx,maxy,stepx,stepy: LONGREAL; log:LONGREAL; steps,i:LONGINT;
BEGIN
	maxx:=MAX(ABS(data[0]));
	log:=Log10(maxx);
	stepx:=Exp10(log);
	
	maxy:=MAX(ABS(data[1]));
	log:=Log10(maxy);
	stepy := Exp10(log);
	
	steps:=MAX(ENTIER(maxx/stepx), ENTIER(maxy/stepy));
	NEW(RESULT,2,steps);
	FOR i:=0 TO steps-1 DO
		RESULT[0,i]:=i*stepx;
		RESULT[1,i]:=i*stepy;
	END;
	
	RETURN RESULT
END GetTicks;

PROCEDURE DummyRegressor(CONST data: ARRAY [*,*] OF LONGREAL; VAR slope,intercept:LONGREAL);
BEGIN
	slope:=1; intercept:=2;
END DummyRegressor;

VAR Pos, PosX,PosY: LONGINT;

PROCEDURE Demo*;
VAR h:Histogram; g:Graph; k: Graphs; gx:GraphXY; m:Matrix; s:Scatter; r:Regression;
BEGIN {EXCLUSIVE}
	NEW(h, [4,7,8,4,5,9,6,5,3,2,12,17,3,0,2], "Histogram"); 
	NEW(g, [4,7,8,4,5,9,6,5,3,2,12,17,3,-3,2], "Graph"); 
	NEW(k, [[-2,7,8,4,5,9,6,4,7,8,4,5,9,6],
			[5,3,2,12,21,3,0,5,3,-2,12,17,4,1]], "MultiGraph"); 
	NEW(gx, [[0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1]], "GraphXY"); 
	NEW(s, [  [0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1],
				[1,0.6,1.1,1,1.4,1,1,1,0.7,1,1,0.8,1,1],
				[0.5,0.3,0.6,0.4,0.5,0.3,0.6,0.5,0.5,0.4,0.7,0.5,0.5,0.5]], "Scatter with x and y error bars"); 
	NEW(r, [  [0.2,-1,0,1,5,9,6,4,7,3,4,5,9,6],
				[0.2,3,4,7,12,3,0,5,3,-2,12,17,4,1],
				[1,1,1,1,1,1,1,1,1,1,1,1,1,1]], "Regression with y error bars", DummyRegressor); 
	NEW(m, [[1,2,3,4],[4,3,2,4],[5,4,-2,-6],[3,1,0,-1]], "Matrix"); 
END Demo;

PROCEDURE Cleanup;
VAR manager:WM.WindowManager; w,remove:WM.Window;
BEGIN {EXCLUSIVE}
	manager:=WM.GetDefaultManager();
	manager.lock.AcquireWrite;
	w:=manager.GetFirst();
	WHILE w#NIL DO
		remove:=w;
		w:=manager.GetNext(w);
		IF (remove#NIL) & (remove IS Window) THEN manager.Remove(remove) END;
	END;
	manager.lock.ReleaseWrite;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Pos:=0; NewWindowPos(0);
END WMSimpleGraphs.

SystemTools.Free WMSimpleGraphs ~

WMSimpleGraphs.Demo ~

