MODULE Bimso;	(** AUTHOR "TF"; PURPOSE "Template/Example  for component windows"; *)

(** This program shows the implementation of a multi instance component containing window *)

IMPORT
	Strings, WMGraphics, WMMessages, WMComponents, WMStandardComponents,
	Modules, KernelLog, WMRectangles, WMGraphicUtilities, Random, Kernel, WMDialogs,
	WM := WMWindowManager;


CONST
	MaxLevel = 1000;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR b : ARRAY 4 OF WMStandardComponents.Button;
		startButton : WMStandardComponents.Button;
		start, alive : BOOLEAN;
		c, cflash : ARRAY 4 OF WMGraphics.Color;
		random : Random.Generator;
		game : ARRAY MaxLevel OF SHORTINT;
		level : LONGINT;
		step : LONGINT;
		error : BOOLEAN;
		timer : Kernel.Timer;
		s, levelStr : ARRAY 32 OF CHAR;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			i : LONGINT;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(200, 200);
			panel.fillColor.Set(LONGINT(0DDFFDDFFH)); panel.takesFocus.Set(TRUE);

			NEW(b[0]); b[0].alignment.Set(WMComponents.AlignTop); b[0].bounds.SetHeight(50);
			b[0].bearing.Set(WMRectangles.MakeRect(50,0,50,0));
			panel.AddContent(b[0]);

			NEW(b[1]); b[1].alignment.Set(WMComponents.AlignBottom); b[1].bounds.SetHeight(50);
			b[1].bearing.Set(WMRectangles.MakeRect(50,0,50,0));
			panel.AddContent(b[1]);

			NEW(b[2]); b[2].alignment.Set(WMComponents.AlignLeft); b[2].bounds.SetWidth(50);
			panel.AddContent(b[2]);

			NEW(b[3]); b[3].alignment.Set(WMComponents.AlignRight); b[3].bounds.SetWidth(50);
			panel.AddContent(b[3]);

			NEW(startButton); startButton.alignment.Set(WMComponents.AlignClient);
			startButton.caption.SetAOC("Start!"); startButton.onClick.Add(Start);
			panel.AddContent(startButton);

			(* set the default colours of the buttons *)
			FOR i := 0 TO 3 DO b[i].clDefault.Set(c[i]) END;
			(* set the same color for the case where the mouse is over *)
			FOR i := 0 TO 3 DO b[i].clHover.Set(c[i]) END;
			(* set the flashcolor for the case where the button is pressed*)
			FOR i := 0 TO 3 DO b[i].clPressed.Set(cflash[i]) END;

			FOR i := 0 TO 3 DO b[i].onClick.Add(Evaluate) END;

			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
			i : LONGINT;
		BEGIN
			IncCount;
			(* initialize the button colours *)
			cflash[0] := WMGraphics.Green; cflash[1] := WMGraphics.Red;
			cflash[2] := WMGraphics.Blue; cflash[3] := WMGraphics.Magenta;
			(* scale the default colours to 50% of the flash colour *)
			FOR i := 0 TO 3 DO c[i] := WMGraphicUtilities.ScaleColor(cflash[i], 128) END;

			(* a timer may not be shared between processes so instantiate a new one *)
			NEW(timer);

			(* To create a multi language app, try loading the respective XML instead of CreateForm()
			if the XML was not found or does not contain all needed elements, use CreateForm as fallback *)
			vc := CreateForm();

			(* create a new random number generator *)
			NEW(random);
			random.InitSeed(Kernel.GetTicks());

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			 WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Bimso Game"));
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE CreateLevel;
		BEGIN
			game[level] := SHORT(SHORT(random.Dice(4)));
			INC(level)
		END CreateLevel;

		PROCEDURE ShowLevel;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO level - 1 DO
				b[game[i]].clDefault.Set(cflash[game[i]]);
				timer.Sleep(150);
				b[game[i]].clDefault.Set(c[game[i]]);
				timer.Sleep(150);
			END;
		END ShowLevel;

		PROCEDURE EnableInput;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO 3 DO b[i].enabled.Set(TRUE) END;
		END EnableInput;

		PROCEDURE DisableInput;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO 3 DO b[i].enabled.Set(FALSE) END;
		END DisableInput;

		PROCEDURE Evaluate(sender, data : ANY);
		VAR i : LONGINT;
		BEGIN  {EXCLUSIVE}
			FOR i := 0 TO 3 DO
				IF sender = b[i] THEN
					IF game[step] = i THEN INC(step) ELSE error := TRUE END;
					RETURN
				END
			END
		END Evaluate;

		PROCEDURE Start(sender, data : ANY);
		BEGIN
			Started;
			startButton.visible.Set(FALSE)
		END Start;

		PROCEDURE Started;
		BEGIN	{EXCLUSIVE}
			start := TRUE
		END Started;

		PROCEDURE Play;
		BEGIN {EXCLUSIVE}
			step := 0;
			EnableInput;
			AWAIT(error OR (step = level))
		END Play;

	BEGIN {ACTIVE}
		alive := TRUE;
		WHILE alive DO
			start := FALSE;
			error := FALSE; level := 0;
			startButton.visible.Set(TRUE);
			BEGIN {EXCLUSIVE}
				AWAIT(start)
			END;
			error := FALSE;
			REPEAT
				KernelLog.Ln;
				DisableInput;
				timer.Sleep(500);
				CreateLevel;
				ShowLevel;
				Play;
			UNTIL error OR (level >= MaxLevel);
			IF level = MaxLevel THEN
				WMDialogs.Information("You win !!", "There are no more levels")
			ELSE
				Strings.IntToStr(level, levelStr);
				s := "You made it to level "; Strings.Append(s, levelStr);
				WMDialogs.Information("You lose !!", s)
			END;
			alive := WMDialogs.Message(WMDialogs.TQuestion, "Play again ?", "Do you want to play again ?",
					{WMDialogs.ResYes, WMDialogs.ResNo}) = WMDialogs.ResYes

		END;
		Close
	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance);
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END Bimso.

SystemTools.Free Bimso ~
Bimso.Open ~
