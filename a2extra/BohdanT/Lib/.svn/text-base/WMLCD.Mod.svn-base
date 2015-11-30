MODULE WMLCD;	(** AUTHOR "BohdanT"; 19/01/2009 *) 

IMPORT	
	Modules,Random, (*KernelLog,*) WM := WMWindowManager, WMGraphics, Strings, WMProperties,
	WMEvents,WMComponents, WSC:=WMStandardComponents, XML, WMRectangles; (* A *)

CONST
	(* Window position relative to the upper left display corner. *)
	Width=650;
	Height=240;   
	AlignNone=WMComponents.AlignNone;

	Black* = 0FFH; White* = LONGINT(0FFFFFFFFH);
	Red* = LONGINT(0FF0000FFH); Green* = 000FF00FFH; Blue* = 0FFFFH;
	Yellow* = LONGINT(0FFFF00FFH); Magenta* = LONGINT(0FF00FFFFH); Cyan* = 00FFFFFFH; 

TYPE
	Canvas = WMGraphics.Canvas;
	String =Strings.String;
	LCD* = OBJECT( WSC.Panel)
	VAR
		Spacing* : WMProperties.Int32Property;
		Colorb* : WMProperties.ColorProperty;
		Colora* : WMProperties.ColorProperty;
		Colorn* : WMProperties.ColorProperty;
		ndig,nd,nf,fact:LONGINT;
		str:String;
		PROCEDURE &Init;
		BEGIN 
			Init^;
			str:=Strings.NewString("-012.3456789");
			NEW(Spacing, NIL,NIL,NIL );Spacing.Set(1); properties.Add(Spacing);
			NEW(Colorb, NIL,NIL,NIL );Colorb.Set(WMGraphics.Black); properties.Add(Colorb);
			NEW(Colora, NIL,NIL,NIL );Colora.Set((0222222FFH)); properties.Add(Colora);
			NEW(Colorn, NIL,NIL,NIL );Colorn.Set(0FFFFC0FFH); properties.Add(Colorn);
			
			SetNameAsString(Strings.NewString("LCD"));
		END Init;
		PROCEDURE  SetFormat*(n, nd, nf: LONGINT);
		VAR
		 i:LONGINT;
		BEGIN
			SELF.ndig:=n;
			SELF.nf:=nf;
			SELF.nd:=nd;
			NEW(str,ndig+2);
			fact:=1;
			FOR i:=1 TO nf DO
				fact:=fact*10;
			END;
(*			KernelLog.String("fact= "); KernelLog.Int(fact, 0); KernelLog.Ln;*)
			
		END SetFormat;
		PROCEDURE FloatToStr(r:REAL;VAR s:ARRAY OF CHAR);
		VAR
			neg:BOOLEAN;
			pos,i,
			dec,float:LONGINT;
		BEGIN
			s[ndig+1]:=0X;
			IF r<0 THEN 
				neg:=TRUE;
			ELSE
				neg:=FALSE
			END;
			dec:=ENTIER(ABS(r)*fact+0.5) DIV fact;
			float:=ENTIER(ABS(r)*fact+0.5) MOD fact;
			pos:=ndig;
			IF nf>0 THEN
				FOR i:=1 TO nf DO
					s[pos]:=CHR(ORD("0")+(float MOD 10));
					DEC(pos);
					float:=float DIV 10;
				END;
				s[pos]:=".";
				DEC(pos);
			END;
			REPEAT
				s[pos]:=CHR(ORD("0")+(dec MOD 10));
				DEC(pos);
				dec:=dec DIV 10;
			UNTIL (dec=0)OR((~neg)&(pos=-1))OR((neg)&(pos=0));
			IF dec#0 THEN
				FOR i:=0 TO ndig DO
				 s[i]:="-";
				END;
			ELSE
				IF (neg) THEN
					s[pos]:="-";
					DEC(pos);
				END;

				FOR i:=0 TO pos DO
					s[i]:=" ";
				END;

			END;
		END FloatToStr;
(*		
		PROCEDURE FloatToStr2(r:REAL;VAR s:ARRAY OF CHAR);
		VAR
			i,pos,len:LONGINT;
			ss:ARRAY 20 OF CHAR;
			str:ARRAY 20 OF CHAR;
		BEGIN
			IF nf>0 THEN
				s[ndig+1]:=0X;
			ELSE
				s[ndig]:=0X;
			END;
			pos:=-1;

			IF r>=0 THEN
				KernelLog.String("++++"); 
				r:=ENTIER(r*fact+0.5)/fact;
				Strings.IntToStr(ENTIER(r),str);
			ELSE
				KernelLog.String("----"); 
				r:=ENTIER(ABS(r)*fact+0.5)/fact;
				Strings.FloatToStr(r,4,9,4,ss);
				KernelLog.String("ss= "); KernelLog.String(ss);
				
				Strings.IntToStr(-ENTIER(r),str);
			END;
			len:=Strings.Length(str);
			IF len>nd THEN 
				s:="ERROR";
				RETURN;
			END;
			
			FOR i:=0 TO len-1 DO
					s[pos+nd-i]:=str[len-i-1];
(*			KernelLog.String("dc= "); KernelLog.Char(str[len-i-1]); KernelLog.Ln;
			KernelLog.String("dc= "); KernelLog.Char(str[len-i-1]); KernelLog.Ln;
			KernelLog.String("di= "); KernelLog.Int(pos+nd-i, 0); KernelLog.Ln;
			KernelLog.String("ds= "); KernelLog.String(s); KernelLog.Ln;
*)			END;
			
			FOR i:=1 TO (nd-len) DO
					s[pos+i]:=" ";
			END;
			IF nf=0 THEN RETURN END;
			
			pos:=pos+nd+1;
			s[pos]:=".";
			intr:=ABS(r*fact);
			FOR i:=1 TO nf DO
				intr:=intr DIV 10;
				KernelLog.Ln;
				Strings.FloatToStr(r,4,9,4,ss);
				KernelLog.String("###= "); KernelLog.String(ss);
				KernelLog.Ln;			
				
				KernelLog.String(".= "); KernelLog.Int(ENTIER(r), 0); 
				s[pos+i]:=CHR(ORD("0")+(intr MOD 10));
			END;
		END FloatToStr;*)
		PROCEDURE SetValue*(r:REAL);
		VAR
		 s:ARRAY 20 OF CHAR;
		BEGIN
			FloatToStr(r,str^);
			Strings.FloatToStr(r,0,9,4,s);
(*			KernelLog.String("di= "); KernelLog.String(s);
			KernelLog.String("dstr= "); KernelLog.String(str^); 			KernelLog.Ln;
*)			Invalidate;
		END SetValue;
		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			Invalidate;	
		END PropertyChanged;
PROCEDURE GetLED7(c: CHAR): SET;
BEGIN
  CASE c OF
       '-': RETURN {4};|
       '0': RETURN {1..3,5..7};|
       '1': RETURN {3,6};|
       '2': RETURN {1,3..5,7};|
       '3': RETURN {1,3,4,6,7};|
       '4': RETURN {2..4,6};|
       '5': RETURN {1,2,4,6,7};|
       '6': RETURN {1,2,4..7};|
       '7': RETURN {1,3,6};|
       '8': RETURN {1..7};|
       '9': RETURN {1..4,6,7};|
  'A', 'a': RETURN {1..6};|
  'B', 'b': RETURN {2,4..7};|
  'C', 'c': RETURN {1,2,5,7};|
  'D', 'd': RETURN {3..7};|
  'E', 'e': RETURN {1,2,4,5,7};|
  'F', 'f': RETURN {1,2,4,5};|
  'G', 'g': RETURN {1,2,4..7};|
  'H', 'h': RETURN {2,3,4,5,6};|
  'I', 'i': RETURN {3,6};|
  'J', 'j': RETURN {3,6,7};|
  'K', 'k': RETURN {};|
  'L', 'l': RETURN {2,5,7};|
  'M', 'm': RETURN {};|
  'N', 'n': RETURN {};|
  'O', 'o': RETURN {1..3,5..7};|
  'P', 'p': RETURN {1..5};|
  'Q', 'q': RETURN {};|
  'R', 'r': RETURN {1..6};|
  'S', 's': RETURN {1,2,4,6,7};|
  'T', 't': RETURN {};|
  'U', 'u': RETURN {2,3,5..7};|
  'V', 'v': RETURN {};|
  'W', 'w': RETURN {};|
  'X', 'x': RETURN {};|
  'Y', 'y': RETURN {};|
  'Z', 'z': RETURN {};|
  ',', '.': RETURN {8};
  ELSE RETURN {};
  END;
END GetLED7;
	PROCEDURE Point(x,y:LONGINT):WMGraphics.Point2d;
	VAR
	 p:WMGraphics.Point2d;
	BEGIN
		p.x:=x;
		p.y:=y;
		RETURN p;
	END Point;
	PROCEDURE DrawBackground*(canvas : Canvas);
	VAR
	 j,i,n:LONGINT;
	 seg:SET;
	 color:LONGINT;
	 w,h:LONGINT;
	 MitteH,D,S:LONGINT;
	 CharRect, SegRect:WMRectangles.Rectangle;
	 PointArray:ARRAY 6 OF WMGraphics.Point2d;
	 s:ARRAY 32 OF CHAR;
	BEGIN
		canvas.Fill(GetClientRect(), Colorb.Get(), WMGraphics.ModeSrcOverDst) ;
		COPY(str^,s);
		n:=Strings.Pos(".",s);
		IF n#-1 THEN
			Strings.Delete(s,n,1);
		END;
		DEC(n);
		w:=bounds.GetWidth() DIV (ndig);
		D:=(w DIV 10);
(*		KernelLog.String("D= "); KernelLog.Int(D, 0); *)
		S:=(w DIV 20);
(*		KernelLog.String("S= "); KernelLog.Int(S, 0); *)
		w:=w-S;
		h:=bounds.GetHeight();
		MitteH:=h DIV 2;
		
	FOR j:=0 TO Strings.Length(s)-1 DO 
		seg:=GetLED7(s[j]);
		IF j=n THEN seg:=seg+{8} END;
      CharRect := WMRectangles.MakeRect(j*(w+S), 0,
                           (j+1)*(w+S)-S, h-1);
		
		FOR i:=1 TO 8 DO
			CASE i OF
				1: SegRect := WMRectangles.MakeRect(CharRect.l+D+S+1, CharRect.t+D+1,    CharRect.r-D-S,  CharRect.t+D+1);|
				2: SegRect := WMRectangles.MakeRect(CharRect.l+D+1,   CharRect.t+D+S+1,  CharRect.l+D+1,   MitteH-S);|
				3: SegRect := WMRectangles.MakeRect(CharRect.r-D,    CharRect.t+D+S+1,  CharRect.r-D,    MitteH-S);|
				4: SegRect := WMRectangles.MakeRect(CharRect.l+D+S+1, MitteH,              CharRect.r-D-S,  MitteH);|
				5: SegRect := WMRectangles.MakeRect(CharRect.l+D+1,   MitteH+S,            CharRect.l+D+1,   CharRect.b-D-S);|
				6: SegRect := WMRectangles.MakeRect(CharRect.r-D,    MitteH+S,            CharRect.r-D,    CharRect.b-D-S);|
				7: SegRect := WMRectangles.MakeRect(CharRect.l+D+S+1, CharRect.b-D,   CharRect.r-D-S,  CharRect.b-D);|
				8: SegRect := WMRectangles.MakeRect(CharRect.r-D+S,     CharRect.b-D, CharRect.r+2*D-S, CharRect.b-D);
			END;
	        CASE i OF
	        1,4,7,8:
	               PointArray[0] := Point(SegRect.l,    SegRect.t);
	               PointArray[1] := Point(SegRect.l+D,  SegRect.t-D);
	               PointArray[2] := Point(SegRect.r-D, SegRect.b-D);
	               PointArray[3] := Point(SegRect.r,   SegRect.b);
	               PointArray[4] := Point(SegRect.r-D, SegRect.b+D);
	               PointArray[5] := Point(SegRect.l+D,  SegRect.t+D);|
	        2,3,5,6:
	               PointArray[0] := Point(SegRect.l,    SegRect.t);
	               PointArray[1] := Point(SegRect.l+D,  SegRect.t+D);
	               PointArray[2] := Point(SegRect.r+D, SegRect.b-D);
	               PointArray[3] := Point(SegRect.r,   SegRect.b);
	               PointArray[4] := Point(SegRect.r-D, SegRect.b-D);
	               PointArray[5] := Point(SegRect.l-D,  SegRect.t+D);
	        END;
			IF i IN seg THEN color := Colorn.Get();
			ELSE color := Colora.Get();
			END;
    			canvas.FillPolygonFlat(PointArray,6,color,1);
			IF i=j THEN
    			END;
		END;
(*				KernelLog.Ln;*)
	END
	
	END DrawBackground;
END LCD;
	

	Window* = OBJECT(WMComponents.FormWindow);	(* B *)
	VAR
		RND:Random.Generator;
 		lcd,lcd2,lcd3:LCD;
		panel  : WSC.Panel;
		tm:WSC.Timer;
		i:LONGINT;
		cnt:LONGINT;
	PROCEDURE &New ;	(* C *)
	BEGIN
		cnt:=-120;
		panel:=NewPanel(LONGINT(0C4C4C4FFH),WMComponents.AlignTop, 0,0,Width, Height);
	
		NEW(lcd);
		lcd.bounds.SetExtents(600,90);
		lcd.SetFormat(9,7,2);
		panel.AddContent (lcd);

		NEW(lcd2);
		lcd2.bounds.SetExtents(200,30);
		lcd2.bounds.SetLeft(100);lcd2.bounds.SetTop(100);
		lcd2.SetFormat(9,7,2);
		panel.AddContent (lcd2);

		NEW(lcd3);
		lcd3.bounds.SetExtents(200,30);
		lcd3.bounds.SetLeft(100);lcd3.bounds.SetTop(140);
		lcd3.SetFormat(9,7,2);
		lcd3.Colora.Set(LONGINT(03D1B0DFFH) );
		lcd3.Colorn.Set( LONGINT(0F82E1EFFH));
		panel.AddContent (lcd3);

		NEW(RND);
		NEW(tm);		tm.interval.Set(25);		tm.onTimer.Add(Animate);		tm.Start(NIL, NIL);

		panel.AddContent (NewButton("Close", AlignNone, 10,120,60,40,CloseHandler));

		(* Create the form window framing the panel. *)	(* F *)

		Init (Width , Height , TRUE);		(* F1 *)
		SetContent (panel);	(* G *)

		WM.DefaultAddWindow (SELF);
		SetTitle (WM.NewString ("LCD - Example window"));	(* I *)
	END New;
		
		PROCEDURE Close;
		BEGIN
			IF tm # NIL THEN
				tm.Stop(NIL, NIL)
			END;
			Close^;
		END Close;

		PROCEDURE CloseHandler(sender, data : ANY);
		BEGIN
			SELF.Close
		END CloseHandler;
		
		PROCEDURE Animate(sender, par : ANY);
		VAR
		 i:LONGINT;
		BEGIN
		  lcd.SetValue(cnt/100);
		  lcd2.SetValue(cnt);
		  lcd3.SetValue(cnt/3);
		  INC(cnt);
		END Animate;		
	END Window;

VAR
	winstance : Window;

(** Open an empty window. No parameter used. *)
PROCEDURE Open*;
BEGIN
	NEW (winstance);
END Open;

(** Termination handler. Removes the window from the display space when the module is unloaded. *)
PROCEDURE Cleanup;	(* K *)
BEGIN
	winstance.Close ();
	winstance := NIL
END Cleanup;
(** Helper procedures *)
PROCEDURE NewLCD*(alignment, left,top,width, height : LONGINT;
LEDCount,Spacing,Min,Max, Color1, Color2: LONGINT) : LCD;
VAR lcd : LCD;
BEGIN
 NEW(lcd);
 lcd.alignment.Set(alignment); 
 lcd.bounds.SetLeft(left);lcd.bounds.SetTop(top);
 lcd.bounds.SetExtents(width, height);
 

 RETURN lcd;
END NewLCD;

PROCEDURE GenLCD*() : XML.Element;
VAR x: LCD;
BEGIN
	NEW(x); RETURN x;
END GenLCD;

PROCEDURE NewButton(CONST caption : ARRAY OF CHAR; alignment, left,top,width, height : LONGINT;observer :WMEvents. EventListener) : WSC.Button;
VAR button: WSC.Button;
BEGIN
	NEW (button); button.caption.SetAOC (caption); button.alignment.Set (alignment);	
	button.bounds.SetTop(top);		button.bounds.SetLeft(left);	button.bounds.SetHeight(height );	button.bounds.SetWidth(width); 
	button.onClick.Add (observer );
	RETURN button;
END NewButton;

PROCEDURE NewPanel*(fillColor, alignment, left,top,width, height : LONGINT) : WSC.Panel;
VAR panel : WSC.Panel;
BEGIN
	NEW(panel); panel.alignment.Set(alignment); 
	panel.bounds.SetLeft(left);panel.bounds.SetTop(top);panel.bounds.SetExtents(width, height);
	panel.fillColor.Set(fillColor);
	RETURN panel;
END NewPanel;


BEGIN	(* L *)
	Modules.InstallTermHandler(Cleanup)
END WMLCD.Open~

SystemTools.Free WMLCD ~
