MODULE WMLEDLadder;	(** AUTHOR "BohdanT"; March, 2008 *)

IMPORT	
	Modules,Random, KernelLog, WM := WMWindowManager, WMGraphics, Strings, WMProperties,
	WMEvents,WMComponents, WSC:=WMStandardComponents, XML; (* A *)

CONST
	(* Window position relative to the upper left display corner. *)
	Width=300;
	Height=240;   
	AlignNone=WMComponents.AlignNone;

	Black* = 0FFH; White* = LONGINT(0FFFFFFFFH);
	Red* = LONGINT(0FF0000FFH); Green* = 000FF00FFH; Blue* = 0FFFFH;
	Yellow* = LONGINT(0FFFF00FFH); Magenta* = LONGINT(0FF00FFFFH); Cyan* = 00FFFFFFH; 

TYPE
	Canvas = WMGraphics.Canvas;

	LEDLadder* = OBJECT( WSC.Panel)
	VAR
		LEDCount* : WMProperties.Int32Property;
		Spacing* : WMProperties.Int32Property;
		Min* : WMProperties.Int32Property;
		Max* : WMProperties.Int32Property;
		Position* : WMProperties.Int32Property;
		Color1* : WMProperties.ColorProperty;
		Color2* : WMProperties.ColorProperty;
		
		
		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(LEDCount, NIL,NIL,NIL );LEDCount.Set(10); properties.Add(LEDCount);
			NEW(Spacing, NIL,NIL,NIL );Spacing.Set(1); properties.Add(Spacing);
			NEW(Min, NIL,NIL,NIL );Min.Set(0); properties.Add(Min);
			NEW(Max, NIL,NIL,NIL );Max.Set(100); properties.Add(Max);
			NEW(Position, NIL,NIL,NIL );Position.Set(50); properties.Add(Position);
			NEW(Color1, NIL,NIL,NIL );Color1.Set(WMGraphics.Green); properties.Add(Color1);
			NEW(Color2, NIL,NIL,NIL );Color2.Set(WMGraphics.Black); properties.Add(Color2);
			
			SetNameAsString(Strings.NewString("LEDLadder"));
		END Init;
		
		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			Invalidate;	
		END PropertyChanged;
			
	PROCEDURE DrawBackground*(canvas : Canvas);
	VAR
		posLED , i:LONGINT;
		rect : WMGraphics.Rectangle;
		ledHeight:LONGINT; 
		color:LONGINT;
	BEGIN
		DrawBackground^(canvas); 

		  posLED := ((Position.Get() * LEDCount.Get() + LEDCount.Get() DIV 2) * LEDCount.Get() - 1) DIV (Max.Get() * LEDCount.Get());;
		   IF bounds.GetHeight()>bounds.GetWidth() THEN
		      ledHeight := bounds.GetHeight() DIV LEDCount.Get();
	      
		      FOR i := 0 TO LEDCount.Get()- 1 DO
		      	IF i < posLED THEN color := Color1.Get()
				ELSE  color := Color2.Get()
				END;
				rect.l := 1;
				rect.r := bounds.GetWidth() - 1;
				rect.t := (LEDCount.Get() - i - 1) * ledHeight;
				rect.b := rect.t + ledHeight - Spacing.Get();
				canvas.Fill(rect, color, WMGraphics.ModeSrcOverDst) 
			END
		   ELSE
			ledHeight := bounds.GetWidth() DIV LEDCount.Get()- Spacing.Get();
			
			FOR i := 0 TO LEDCount.Get()- 1 DO
				IF i < posLED THEN   color := Color1.Get()
				ELSE   color := Color2.Get();
				END;
				rect.t := 1;
				rect.b:= bounds.GetHeight() - 1;
				rect.l := i * (ledHeight + Spacing.Get());
				rect.r := rect.l + ledHeight ;
				canvas.Fill(rect, color, WMGraphics.ModeSrcOverDst) 
			END;
		   END;
		   IF ledHeight<1 THEN KernelLog.String("ledHeight=");KernelLog.Int(ledHeight,3); KernelLog.Ln(); END;
	END DrawBackground;
END LEDLadder;
	

	Window* = OBJECT(WMComponents.FormWindow);	(* B *)
	VAR
		RND:Random.Generator;
 		ll:ARRAY 5 OF LEDLadder;
		panel  : WSC.Panel;
		tm:WSC.Timer;
		i:LONGINT;
	PROCEDURE &New ;	(* C *)
	BEGIN
		panel:=NewPanel(LONGINT(0C4C4C4FFH),WMComponents.AlignTop, 0,0,Width, Height);

		FOR i:=0 TO 4 DO NEW (ll[i]); END;

		ll[0]:=NewLEDLadder(AlignNone, 0,0,200, 20,50,1,0,100, Green,LONGINT(0C0FFC0FFH));
		panel.AddContent (ll[0]); 
		ll[1]:=NewLEDLadder(AlignNone, 0,30,200, 20,50,1,0,100, Red, Green);
		panel.AddContent (ll[1]); 
		ll[2]:=NewLEDLadder(AlignNone, 0,60,200, 40,10,3,0,100, Magenta, Green);
		panel.AddContent (ll[2]); 
		ll[3]:=NewLEDLadder(AlignNone, 220,0,30, 200,10,1,0,100, Yellow, Cyan);
		panel.AddContent (ll[3]); 
		ll[4]:=NewLEDLadder(AlignNone, 280,0,10, 200,30,2,0,100, Black, White);
		panel.AddContent (ll[4]); 

		NEW(RND);(*ÐÐµÐ½ÐµÑÐ°ÑÐ¾Ñ ÑÐ»ÑÑÐ°Ð¹Ð½ÑÑ ÑÐ¸ÑÐµÐ»*)
		NEW(tm);		tm.interval.Set(50);		tm.onTimer.Add(Animate);		tm.Start(NIL, NIL);

		panel.AddContent (NewButton("Close", AlignNone, 10,120,60,40,CloseHandler));

		(* Create the form window framing the panel. *)	(* F *)

		Init (Width , Height , TRUE);		(* F1 *)
		SetContent (panel);	(* G *)

		WM.DefaultAddWindow (SELF);
		SetTitle (WM.NewString ("LEDLadder - Example window"));	(* I *)
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
(*		 IF ll#NIL THEN*)
			FOR i:=0 TO 4 DO
				 ll[i].Position.Set(RND.Dice(100));
			 END;
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
PROCEDURE NewLEDLadder*(alignment, left,top,width, height : LONGINT;
LEDCount,Spacing,Min,Max, Color1, Color2: LONGINT) : LEDLadder;
VAR ledladder : LEDLadder;
BEGIN
 NEW(ledladder);
 ledladder.alignment.Set(alignment); 
 ledladder.bounds.SetLeft(left);ledladder.bounds.SetTop(top);
 ledladder.bounds.SetExtents(width, height);
 
 ledladder.LEDCount.Set(LEDCount);
 ledladder.Spacing.Set(Spacing);
 ledladder.Min.Set(Min);
 ledladder.Max.Set(Max );
 ledladder.Color1.Set(Color1);
 ledladder.Color2 .Set(Color2);

 RETURN ledladder;
END NewLEDLadder;

PROCEDURE GenLEDLadder*() : XML.Element;
VAR x: LEDLadder;
BEGIN
	NEW(x); RETURN x;
END GenLEDLadder;

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
END WMLEDLadder.Open~

SystemTools.Free WMLEDLadder~