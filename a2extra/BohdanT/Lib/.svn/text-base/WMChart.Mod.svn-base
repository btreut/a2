MODULE WMChart;(** AUTHOR "BohdanT"; PURPOSE "WMChart & Series components"; *)
(*TODO: mnogo chego*)
IMPORT Strings,WMComponents,WMGraphics,WMRectangles,Locks, Raster,WMGraphicUtilities,CanvasTools,KernelLog;
TYPE
	Canvas = WMGraphics.Canvas;

	Axis* = RECORD
		visable*:BOOLEAN;
		auto*:BOOLEAN;
		min*,
		max*:LONGREAL;
		txdw:LONGINT;
		txdf:LONGINT;
		invert*:BOOLEAN;
		
	END;
	
Chart* = OBJECT(WMComponents.VisualComponent)
VAR
	cl1:LONGINT;
	penstyle:LONGINT;
	pen:Raster.Image;
	cl2:LONGINT;
	gh,gw:LONGINT;
	bottomAxis*,
	leftAxis*,topAxis*,rightAxis*:Axis;
	Marque,Debut,Pas:LONGREAL;
	series*: SeriessArray;nofSeriess*:LONGINT;
	upNofChanges : LONGINT;	 
	lock : Locks.RWLock;
		(** acquire a write lock on the object *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite
		END AcquireWrite;
		
		(** release the write lock on the object *)
		PROCEDURE ReleaseWrite*;
		VAR 
			removeLock : BOOLEAN;
			nofChanges : LONGINT;
		BEGIN 
			removeLock := lock.GetWLockLevel() = 1;
			IF removeLock THEN  nofChanges := upNofChanges END;
			upNofChanges := 0; 
			lock.ReleaseWrite;
		END ReleaseWrite;
		PROCEDURE AcquireRead*;
		BEGIN
			lock.AcquireRead
		END AcquireRead;
		
		PROCEDURE ReleaseRead*;
		BEGIN
			lock.ReleaseRead
		END ReleaseRead;
		
		PROCEDURE Add*(x : Series);
		BEGIN
			AcquireWrite;
			IF nofSeriess = LEN(series) THEN Grow END;
			series[nofSeriess] := x;
			INC(nofSeriess);
			ReleaseWrite
		END Add;
	
		PROCEDURE Remove*(x : Series);
		VAR i : LONGINT;
		BEGIN
			AcquireWrite;
			i := 0; WHILE (i < nofSeriess) & (series[i] # x) DO INC(i) END;
			IF i < nofSeriess THEN 
				WHILE (i < nofSeriess - 1) DO series[i] := series[i + 1]; INC(i) END;
				DEC(nofSeriess);
				series[nofSeriess] := NIL
			END;
			ReleaseWrite
		END Remove;

		PROCEDURE Grow;
		VAR new: SeriessArray; i : LONGINT;
		BEGIN 
			NEW(new, LEN(series) * 2);
			FOR i := 0 TO nofSeriess - 1 DO new[i] := series[i] END;
			series := new
		END Grow;
		
		PROCEDURE Enumerate*() : SeriessArray;
		VAR current : SeriessArray; i : LONGINT;
		BEGIN 
			AcquireWrite;
			NEW(current, nofSeriess);
			FOR i := 0 TO nofSeriess - 1 DO current[i] := series[i] END;
			ReleaseWrite;
			RETURN current
		END Enumerate;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			penstyle:=LONGINT(0AAAAAAAAH);
			cl1:=WMGraphics.Black;
			leftAxis.visable:=TRUE;
			bottomAxis.visable:=TRUE;
			NEW(series, 8); 			
			NEW(lock);
			CanvasTools.CreatePen(1,cl1,pen);
			SetNameAsString(Strings.NewString("Chart"));
		END Init;
		PROCEDURE YToIm(Yin:LONGREAL):LONGINT;
		VAR
		 ay:LONGREAL;
		BEGIN
			IF ~leftAxis.invert THEN
				 ay:=(gh)/(leftAxis.max-leftAxis.min);
				 RETURN ENTIER(gh-ay*(Yin-leftAxis.min)+0.5);
			ELSE
				 ay:=(gh)/(leftAxis.max-leftAxis.min);
				 RETURN ENTIER(ay*(Yin-leftAxis.min)+0.5);
			END;
		END YToIm;

		PROCEDURE XToIm(Xin:LONGREAL):LONGINT;
		VAR
		 ax:LONGREAL;
		BEGIN
			IF ~bottomAxis.invert THEN
				ax:=(gw)/(bottomAxis.max-bottomAxis.min);
				RETURN ENTIER(ax*(Xin-bottomAxis.min)+0.5);
			ELSE
				ax:=(gw)/(bottomAxis.max-bottomAxis.min);
				RETURN ENTIER(gw-ax*(Xin-bottomAxis.min)+0.5);
			END;
		END XToIm; 

		PROCEDURE DrawBackground*(c : Canvas);
		VAR
			f : WMGraphics.Font;
			YTemp,XTemp:LONGINT;
			MyText:ARRAY 255 OF CHAR;
			r:WMGraphics.Rectangle;
			i:LONGINT;
			gl,gt,gb,gr:LONGINT;
			canvasState: WMGraphics.CanvasState;
		BEGIN
			WMRectangles.SetRect(r,0,0,bounds.GetWidth(),bounds.GetHeight());
			c.Fill(r,WMGraphics.White,WMGraphics.ModeCopy);
			f := GetFont();
			c.color:=WMGraphics.Black;

			IF leftAxis.visable THEN gl:=30 ELSE gl:=0; END;
			IF rightAxis.visable THEN gr:=30 ELSE gr:=0; END;

			IF topAxis.visable THEN gt:=f.GetHeight()+1;	ELSE gt:=0; END;
			IF bottomAxis.visable THEN gb:=f.GetHeight()+1;ELSE gb:=0;END;
			
			
		 	gw:=bounds.GetWidth()-gl-gr;(*TODO: Ctrl^.Canvas^.TextWidth()*)
			gh:=bounds.GetHeight()-gt-gb;
			CalculateIntervals(leftAxis.min,leftAxis.max,Debut,Pas);

			IF leftAxis.min#leftAxis.max THEN
				Marque:=Debut;
				WHILE Marque<=leftAxis.max+Pas*(1.0E-10) DO
					IF (Marque>=leftAxis.min) THEN
						YTemp:=YToIm(Marque);
						CanvasTools.Line(c, gl,YTemp,bounds.GetWidth(),YTemp,pen,penstyle,WMGraphics.ModeSrcOverDst);
						IF leftAxis.visable THEN 
							Strings.FloatToStr(Marque, 4, 0, 0,MyText);
							c.DrawString(0,YTemp+f.GetHeight(),MyText);
						END;
					END;
					Marque:=Marque+Pas;
				END;
		     END;

			IF bottomAxis.visable THEN 
				CalculateIntervals(bottomAxis.min,bottomAxis.max,Debut,Pas);
				IF bottomAxis.min#bottomAxis.max THEN
					Marque:=Debut;
					WHILE Marque<=bottomAxis.max+Pas*(1.0E-10) DO
						IF (Marque>=bottomAxis.min) THEN
							XTemp:=XToIm(Marque);
							CanvasTools.Line(c, XTemp+gl,0,XTemp+gl,gh,pen,penstyle,WMGraphics.ModeSrcOverDst);
							Strings.FloatToStr(Marque, 4, 0, 0,MyText);
							c.DrawString(XTemp+gl,gh+f.GetHeight(),MyText);
						END;
						Marque:=Marque+Pas;
					END;
		     	END;
				c.SaveState(canvasState);
				c.SetDelta(c.dx + gl, c.dy + gt);
				c.SetClipRect(WMRectangles.MakeRect(0,0,gw,gh));
				IF series#NIL THEN
					FOR i:=0 TO nofSeriess-1 DO
						series[i].DrawSeries(c);
					END;
				END;
				c.RestoreState(canvasState)
				
			END;
		END DrawBackground;
 
	PROCEDURE CalculateIntervals(Mini,Maxi:LONGREAL;VAR Debut,Pas:LONGREAL);
	VAR
	   EtENDue,EtENDueTmp:LONGREAL;
	   NbPas,Mult:ARRAY 3 OF LONGREAL;
	   Index:ARRAY 3 OF LONGINT;
	   Trouve:BOOLEAN;
	   DTmp:LONGREAL;
	   BTmp:LONGINT;
	   i,j:LONGINT;
	BEGIN
		EtENDue:=Maxi-Mini;
		IF EtENDue=0 THEN Debut:=Mini; Pas:=1; RETURN; END;
	
		Mult[0]:=1;
		EtENDueTmp:=EtENDue;
		NbPas[0]:=EtENDueTmp;
		IF NbPas[0]>=10 THEN
		   WHILE NbPas[0]>10 DO
		      EtENDueTmp:=EtENDueTmp/10;
		      Mult[0]:=Mult[0]/10;
		      NbPas[0]:=EtENDueTmp;
		   END;
		ELSE
		   WHILE EtENDueTmp*10<=10 DO
		      EtENDueTmp:=EtENDueTmp*10;
		      Mult[0]:=Mult[0]*10;
		      NbPas[0]:=EtENDueTmp;
		   END;
		END;
		
		Mult[1]:=1;
		EtENDueTmp:=EtENDue;
		NbPas[1]:=EtENDueTmp/0.5;
		IF NbPas[1]>=10 THEN
		   WHILE NbPas[1]>10 DO
		      EtENDueTmp:=EtENDueTmp/10;
		      Mult[1]:=Mult[1]/10;
		      NbPas[1]:=EtENDueTmp/0.5;
		      END;
		ELSE
		   WHILE EtENDueTmp*10/0.5<=10 DO
		      EtENDueTmp:=EtENDueTmp*10;
		      Mult[1]:=Mult[1]*10;
		      NbPas[1]:=EtENDueTmp/0.5;
		      END;
		END;
		
		Mult[2]:=1;
		EtENDueTmp:=EtENDue;
		NbPas[2]:=EtENDueTmp/0.2;
		IF NbPas[2]>=10 THEN
		   WHILE NbPas[2]>10 DO
		      EtENDueTmp:=EtENDueTmp/10;
		      Mult[2]:=Mult[2]/10;
		      NbPas[2]:=EtENDueTmp/0.2;
		   END;
		ELSE
		   WHILE EtENDueTmp*10/0.2<=10 DO
		      EtENDueTmp:=EtENDueTmp*10;
		      Mult[2]:=Mult[2]*10;
		      NbPas[2]:=EtENDueTmp/0.2;
		   END;
		END;
		FOR i:=0 TO 2 DO Index[i]:=i; END;
		
		Trouve:=TRUE;
		WHILE Trouve DO
		   Trouve:=FALSE;
		   FOR i:=0 TO 1 DO
		      IF NbPas[i]>NbPas[i+1] THEN
		         Trouve:=TRUE;
		         DTmp:=NbPas[i];
		         NbPas[i]:=NbPas[i+1];
		         NbPas[i+1]:=DTmp;
		         BTmp:=Index[i];
		         Index[i]:=Index[i+1];
		         Index[i+1]:=BTmp;
		      END;
		   END;   
		END;
		
		IF NbPas[2]<=10 THEN j:=2
		ELSIF NbPas[1]<=10 THEN j:=1
		ELSIF NbPas[0]<=10 THEN j:=0
		ELSE
		   RETURN;
		END;
	
		IF Index[j]=0 THEN Pas:=1; 
		ELSIF Index[j]=1 THEN Pas:=0.5; 
		ELSIF Index[j]=2 THEN Pas:=0.2; END;
		Pas:=Pas/Mult[Index[j]];
		IF (Mini<0)& (Maxi>0) THEN
		   Debut:=0;
		   WHILE Debut>Mini DO Debut:=Debut-Pas; END
		ELSE
		      Debut:=ENTIER((Mini-Pas)*Mult[Index[j]])/Mult[Index[j]]
		END;
	END CalculateIntervals;
	
END Chart;

Series* = OBJECT
	VAR
		chart:Chart;
		dx:LONGREAL;
		p*:DataArray;
		cl:LONGINT;
		min*,max*:LONGREAL;
		vertical*:BOOLEAN;
	PROCEDURE &Init*(chart:Chart);
	BEGIN
		SELF.chart:=chart;
	END Init;
		
	PROCEDURE InitSeries*(datacount :LONGINT; dx:LONGREAL; cl:LONGINT);
	BEGIN
		NEW(p,datacount);
		SELF.dx:=dx;
		SELF.chart:=chart;
		SELF.cl:=cl;
	END InitSeries;
	
	PROCEDURE DrawLine*(CONST c:Canvas;x1,y1,x2,y2:LONGINT);
	BEGIN
		c.Line( x1,y1,x2,y2,cl,WMGraphics.ModeCopy);
	END DrawLine;
	
	PROCEDURE DrawSeries*(CONST c:Canvas);
	VAR
		start,stop,xc, j,
		tmpx,tmpy:LONGINT;
		ay,ax:LONGREAL;
		YTemp,XTemp:LONGINT;

	BEGIN
		IF chart=NIL THEN RETURN;END;
		IF chart.leftAxis.max=chart.leftAxis.min THEN RETURN;END;
		IF chart.bottomAxis.min=chart.bottomAxis.max THEN RETURN; END;
		
		ay:=(chart.gh)/(chart.leftAxis.max-chart.leftAxis.min);
		ax:=(chart.gw)/(chart.bottomAxis.max-chart.bottomAxis.min);
		xc:=0; tmpx:=0; tmpy:=0;

		start:=ENTIER(chart.bottomAxis.min/dx);
		IF start>(LEN(p)-1) THEN RETURN;END;
		
		stop:=ENTIER(chart.bottomAxis.max/dx);
		IF stop>LEN(p) THEN stop:=LEN(p);END;
		
		tmpx:=chart.XToIm(start);
		tmpy:=chart.YToIm(p[start]);

		FOR j := start+1 TO stop-1 DO
			XTemp:=chart.XToIm(j*dx);
			YTemp:=chart.XToIm(p[j]);
			DrawLine(c, tmpx,tmpy,XTemp,YTemp);
			tmpx:=XTemp;
			tmpy:=YTemp;
		END;
	END DrawSeries;
END Series;

LineSeries* = OBJECT(Series)
	VAR
		ox,oy,
		width,
		style,wstyles:LONGINT;
		pen:Raster.Image;
(*	PROCEDURE &Init*(datacount :LONGINT; dx:LONGREAL; chart:Chart;cl:LONGINT);(*CONST color,width:LONGINT*)
	BEGIN
		Init^(datacount,dx,chart,cl);
	END Init;
*)
	PROCEDURE DrawLine*(CONST c:Canvas;x1,y1,x2,y2:LONGINT);
	BEGIN
(*TODO:NEED OPTIMIZE FOR styles
		IF (ox=x2)&(oy=y2)THEN RETURN END;
		ox:=x1;oy:=y1;*)
		IF width=1 THEN
			DrawLine^(c,x1,y1,x2,y2);
		ELSE	
			CanvasTools.Line(c, x1,y1,x2,y2,pen,wstyles,WMGraphics.ModeSrcOverDst);
		END;
	END DrawLine;
	PROCEDURE DrawSeries*(CONST c:Canvas);
	BEGIN
		wstyles:=style;
		ox:=0;
		oy:=0;
		DrawSeries^(c);
	END DrawSeries;
	PROCEDURE CreatePen*(CONST width,color,style:LONGINT);
	BEGIN
		CanvasTools.CreatePen(width,color,pen);
		SELF.style:=style;
(*		KernelLog.String("width= "); KernelLog.Int(width, 0); 
		KernelLog.String(" color= "); KernelLog.Int(color, 0); 
		KernelLog.String(" style= "); KernelLog.Int(style, 0); 
		KernelLog.Ln;		*)
		IF chart#NIL THEN chart.Invalidate; END;
	END CreatePen;
	
END LineSeries;

BasicSeries* = OBJECT(LineSeries)
VAR
	XGraphMax,XGraphMin,YGraphMax,YGraphMin:LONGREAL;

	data*: XYDataArray;nofdata*:LONGINT;
	upNofChanges : LONGINT;	 
	lock : Locks.RWLock;

		PROCEDURE &new*(chart:Chart;w,cl:LONGINT);
		BEGIN
			Init(chart);
			nofdata:=0;
			CreatePen(w,cl,LONGINT(0FFFFFFFFH));
			NEW(data, 1024);
			NEW(lock);
		END new;
	
		(** acquire a write lock on the object *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite
		END AcquireWrite;
		
		(** release the write lock on the object *)
		PROCEDURE ReleaseWrite*;
		VAR 
			removeLock : BOOLEAN;
			nofChanges : LONGINT;
		BEGIN 
			removeLock := lock.GetWLockLevel() = 1;
			IF removeLock THEN  nofChanges := upNofChanges END;
			upNofChanges := 0; 
			lock.ReleaseWrite;
		END ReleaseWrite;
		PROCEDURE AcquireRead*;
		BEGIN
			lock.AcquireRead
		END AcquireRead;
		
		PROCEDURE ReleaseRead*;
		BEGIN
			lock.ReleaseRead
		END ReleaseRead;
		PROCEDURE UpDateMax(x,y:LONGREAL);
		BEGIN
			IF x>XGraphMax THEN XGraphMax:=x; END;
			IF x<XGraphMin THEN XGraphMin:=x; END;
			IF y>YGraphMax THEN YGraphMax:=y; END;
			IF y<YGraphMin THEN YGraphMin:=y; END;
		END UpDateMax;
		
		PROCEDURE Add*(x, y: LONGREAL;c:LONGINT;s:Strings.String);
		BEGIN
			AcquireWrite;
			IF nofdata = LEN(data) THEN Grow END;
			data[nofdata].x := x;
			data[nofdata].y := y;
			data[nofdata].c := c;
			data[nofdata].str := s;
			UpDateMax(x,y);
			INC(nofdata);
			ReleaseWrite;
			chart.Invalidate;
		
		END Add;
		PROCEDURE AddXY*(x, y: LONGREAL);
		BEGIN
			AcquireWrite;
			IF nofdata = LEN(data) THEN Grow END;
			data[nofdata].x := x;
			data[nofdata].y := y;
			INC(nofdata);
			UpDateMax(x,y);
			ReleaseWrite;
		END AddXY;
	
		PROCEDURE Remove*(x : LONGREAL);
		VAR i : LONGINT;
		BEGIN
			AcquireWrite;
			i := 0; WHILE (i < nofdata) & (data[i].x # x) DO INC(i) END;
			IF i < nofdata THEN 
				WHILE (i < nofdata - 1) DO data[i] := data[i + 1]; INC(i) END;
				DEC(nofdata);
			END;
			ReleaseWrite;
			chart.Invalidate;
		END Remove;
		PROCEDURE Grow;
		VAR new: XYDataArray; i : LONGINT;
		BEGIN 
			NEW(new, LEN(data) * 2);
			FOR i := 0 TO nofdata - 1 DO new[i] := data[i] END;
			data := new
		END Grow;
		
		PROCEDURE Enumerate*() : XYDataArray;
		VAR current : XYDataArray; i : LONGINT;
		BEGIN 
			AcquireWrite;
			NEW(current, nofdata);
			FOR i := 0 TO nofdata - 1 DO current[i] := data[i] END;
			ReleaseWrite;
			RETURN current
		END Enumerate;
	PROCEDURE DrawSeries*(CONST c:Canvas);
	VAR
		xc, i,
		tmpx,tmpy:LONGINT;
		ay,ax,tx,ty:LONGREAL;
		YTemp,XTemp:LONGINT;
		bmn,bmx,lmn,lmx:LONGREAL;
		flag,oflag:BOOLEAN;
	BEGIN

		IF chart=NIL THEN RETURN;END;

		lmn:=chart.leftAxis.min;
		lmx:=chart.leftAxis.max;
		bmx:=chart.bottomAxis.max;
		bmn:=chart.bottomAxis.min;
	
		IF (lmx=lmn)OR(bmx=bmn)OR(nofdata=0) THEN RETURN; END;
		
		ay:=(chart.gh)/(lmx-lmn);
		ax:=(chart.gw)/(bmx-bmn);
		xc:=0; tmpx:=0; tmpy:=0;
		wstyles:=style;
		
		tx:=data[0].x;ty:=data[0].y;oflag:=FALSE;
		tmpx:=chart.XToIm(tx);(*ENTIER(ax*(tx-bmn)+0.5);*)
		tmpy:=chart.YToIm(ty);(*ENTIER(ay*(ty-lmn)+0.5);*)
		
		IF	(tx>=bmn)&(tx<=bmx)&
			(ty>=lmn)&(ty<=lmx)	THEN  flag:=TRUE;ELSE flag:=FALSE; END;
		
		FOR i := 1 TO nofdata-1 DO
		
			tx:=data[i].x;ty:=data[i].y;
			IF	(tx>=bmn)&(tx<=bmx)&
				(ty>=lmn)&(ty<=lmx)	THEN  flag:=TRUE;ELSE flag:=FALSE; END;
		XTemp:=chart.XToIm(tx);(*ENTIER(ax*(tx-bmn)+0.5);*)
		YTemp:=chart.YToIm(ty);(*ENTIER(ay*(ty-lmn)+0.5);*)

			IF (flag=TRUE)OR(oflag=TRUE)	THEN
				DrawLine(c,XTemp,YTemp,tmpx,tmpy);
			END;
			oflag:=flag;
			
			tmpx:=XTemp;
			tmpy:=YTemp;
		END;
	END DrawSeries;

END BasicSeries;

BarSeries* = OBJECT(Series)
	PROCEDURE DrawSeries*(CONST c:Canvas);
	VAR
		start,stop,xc, j,
		tmpx,tmpy:LONGINT;
		ay,ax,w:LONGREAL;
		rect : WMGraphics.Rectangle;
	BEGIN
		IF chart=NIL THEN RETURN;END;
		IF chart.leftAxis.max=chart.leftAxis.min THEN RETURN;END;
		IF chart.bottomAxis.min=chart.bottomAxis.max THEN RETURN; END;
		
		ay:=(chart.gh)/(chart.leftAxis.max-chart.leftAxis.min);
		ax:=(chart.gw)/(chart.bottomAxis.max-chart.bottomAxis.min);
		w:=(chart.gw)/(dx);
		xc:=0; tmpx:=0; tmpy:=0;

		start:=ENTIER(chart.bottomAxis.min/dx);
		IF start>(LEN(p)-1) THEN RETURN;END;
		
		stop:=ENTIER(chart.bottomAxis.max/dx);
		IF stop>LEN(p) THEN stop:=LEN(p);END;

		FOR j := start TO stop-1 DO
			IF ~vertical THEN
				rect:=WMRectangles.MakeRect(chart.XToIm(j*dx),chart.YToIm(p[j]),chart.XToIm((j+1)*dx),chart.gh);
			ELSE
				rect:=WMRectangles.MakeRect(0,chart.YToIm((j+1)*dx),chart.XToIm(p[j]),chart.YToIm(j*dx));
			END;	
			WMGraphicUtilities.DrawRect(c, rect, WMGraphics.Black,WMGraphics.ModeCopy);
			c.Fill(WMRectangles.ResizeRect(rect, -1),cl,WMGraphics.ModeCopy);
		END;
	END DrawSeries;

END BarSeries;

GradientSeries* = OBJECT(Series)
VAR
	fromcolor*,tocolor*:LONGINT;
	PROCEDURE DrawSeries*(CONST c:Canvas);
	VAR
		start,stop,xc, j,
		tmpx,tmpy:LONGINT;
		ay,ax,w,h:LONGREAL;
		rect : WMGraphics.Rectangle;
		gc:LONGINT;
		A1,A2,A3,B1,B2,B3,a:LONGINT;
		
		amin,amax:LONGREAL;
	BEGIN

		IF chart=NIL THEN RETURN;END;
		IF chart.leftAxis.max=chart.leftAxis.min THEN RETURN;END;
		IF chart.bottomAxis.min=chart.bottomAxis.max THEN RETURN; END;
		
		ay:=(chart.gh)/(chart.leftAxis.max-chart.leftAxis.min);
		ax:=(chart.gw)/(chart.bottomAxis.max-chart.bottomAxis.min);
		xc:=0; tmpx:=0; tmpy:=0;

		amin:=chart.bottomAxis.min;
		amax:=chart.bottomAxis.max;
		w:=(chart.gw)/(dx);
		start:=ENTIER(amin/dx);
		IF start>(LEN(p)-1) THEN RETURN;END;
		
		stop:=ENTIER(amax/dx);
		IF stop>LEN(p) THEN stop:=LEN(p);END;
		
		WMGraphics.ColorToRGBA(WMGraphics.White,A1,A2,A3,a);
		WMGraphics.ColorToRGBA(WMGraphics.Black,B1,B2,B3,a);
		
		h:=max-min;

		FOR j := start TO stop-1 DO
			IF ~vertical THEN
				rect:=WMRectangles.MakeRect(chart.XToIm(j*dx),0,chart.XToIm((j+1)*dx),chart.gh);
			ELSE
				rect:=WMRectangles.MakeRect(0,chart.YToIm((j+1)*dx),chart.gw,chart.YToIm(j*dx));
			END;
			gc:=WMGraphics.RGBAToColor(	ENTIER(A1-(A1-B1)/h*p[j]+0.5),
												ENTIER(A2-(A2-B2)/h*p[j]+0.5),
												ENTIER(A3-(A3-B3)/h*p[j]+0.5),255);
			c.Fill(rect,gc,WMGraphics.ModeCopy);
		END;
	END DrawSeries;

END GradientSeries;

	SeriessArray* =POINTER TO ARRAY OF Series;
	DataArray* =POINTER TO ARRAY OF LONGREAL;

	XYDataArray* =POINTER TO ARRAY OF RECORD x,y:LONGREAL;c:LONGINT;str:Strings.String; END;
	
END WMChart.
