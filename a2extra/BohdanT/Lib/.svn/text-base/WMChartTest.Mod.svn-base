MODULE WMChartTest;	(** AUTHOR "BohdanT"; PURPOSE "Testing WMChart component" *)

IMPORT	
	Modules,Random, WM := WMWindowManager, WMGraphics, 
	WMEvents,MathL,
	WMComponents, WSC:=WMStandardComponents,WMChart;

CONST
	(* Window position relative to the upper left display corner. *)
	Width=240;
	Height=240;   
	AlignNone=WMComponents.AlignNone;

TYPE

	Window* = OBJECT(WMComponents.FormWindow);	(* B *)
	VAR
		RND:Random.Generator;
		panel : WSC.Panel;
		chart:WMChart.Chart;
		grad:WMChart.GradientSeries;
		line,line13:WMChart.BasicSeries;
		bar:WMChart.BarSeries;
	PROCEDURE &New ;	(* C *)
	VAR
	 i:LONGINT;
	BEGIN
		panel:=NewPanel(WMGraphics.Cyan,WMComponents.AlignTop, 0,0,Width*2, Height*2);

		NEW(chart);
		chart.alignment.Set(WMComponents.AlignClient);
		chart.bounds.SetTop(240);		chart.bounds.SetLeft(10);		chart.bounds.SetHeight(220);		chart.bounds.SetWidth (620); 
		chart.leftAxis.max:=100;				chart.leftAxis.min:=0;		
		chart.bottomAxis.max:=100;		chart.bottomAxis.min:=0;

		NEW(grad,chart);		
		grad.InitSeries(100,1,WMGraphics.Red);grad.vertical:=TRUE;
		grad.min:=0;grad.max:=100; 
		FOR i:=0 TO 99 DO 
			grad.p[i]:=MathL.sin(i/14)*MathL.sin(i/14)*MathL.sin(i/22)*50+50;
		END;

		NEW(bar,chart);		
		bar.InitSeries(10,10, LONGINT(0FF8000FFH));bar.vertical:=FALSE;
		bar.min:=0;bar.max:=100; 
		FOR i:=0 TO 9 DO 
			bar.p[i]:=(MathL.sqrt(i)*MathL.sqrt(10)*10);
		END;


		NEW(line13,chart,13,LONGINT(0FFDF85FFH) );
		FOR i:=0 TO 1000 DO 
			line13.AddXY(i/10,MathL.sin(2*3.142*i/300)*25+75);
		END;
		
		NEW(RND);
		NEW(line,chart,1,LONGINT(080FF80FFH) );
		FOR i:=0 TO 1000 DO 
			line.AddXY(i/10,MathL.sin(2*3.142*i/300)*MathL.sin(2*3.142*i/200)*25+25+RND.Dice(10));
		END;
		
		
		chart.Add(grad);
		chart.Add(bar);
		chart.Add(line13);
		chart.Add(line);
		panel.AddContent (chart); 
		

(*			panel.AddContent (NewButton("Close", AlignNone, 10,80,60,40,CloseHandler));
			panel.AddContent (NewButton("Pass", AlignNone, 80,80,60,40,TestPass));
*)			
			
		(* Create the form window framing the panel. *)	(* F *)

		Init (Width*2 , Height*2 , TRUE);		(* F1 *)
		SetContent (panel);	(* G *)

		WM.DefaultAddWindow (SELF);
		SetTitle (WM.NewString ("WMChart - Test APP"));
	END New;
		

		PROCEDURE CloseHandler(sender, data : ANY);
		BEGIN
			SELF.Close
		END CloseHandler;

		PROCEDURE TestPass(sender, data : ANY);
		VAR
			 i:LONGINT;
			 n:LONGINT;
		BEGIN
(*		n:=RND.Dice(50)+1;
		NEW(line,chart);
		line.InitSeries(1256,0.1,WMGraphics.RGBAToColor(RND.Dice(255),RND.Dice(255),RND.Dice(255),RND.Dice(255)));
		line.CreatePen(RND.Dice(5)+1,WMGraphics.RGBAToColor(RND.Dice(255),RND.Dice(255),RND.Dice(255),RND.Dice(255)),SHORT(0FFFFFFFFH));
		
		FOR i:=0 TO LEN(line.p)-1 DO 
			line.p[i]:=MathL.sin(i/n+n)*n+50;
		END;
		chart.Add(line);
				
		chart.Invalidate;*)
		END TestPass;
		
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

PROCEDURE NewButton*(CONST caption : ARRAY OF CHAR; alignment, left,top,width, height : LONGINT;observer :WMEvents. EventListener) : WSC.Button;
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
END WMChartTest.

WMChartTest.Open ~

SystemTools.Free WMChartTest WMChart~
