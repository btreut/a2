MODULE WMStandardComponents;	(** AUTHOR "TF"; PURPOSE "Standard components"; *)

IMPORT
	KernelLog, Kernel, Types, Models, Repositories, WMComponents, Strings, Files,
	WMGraphics, WMGraphicUtilities, WMRectangles,
	WMEvents, XML, Inputs, WMProperties, WMWindowManager,Modules;

TYPE
	(* Local type-alias for convenience *)
	String = Strings.String;
	EventSource = WMEvents.EventSource;
	EventListener = WMEvents.EventListener ;
	EventListenerInfo = WMEvents.EventListenerInfo;
	Canvas = WMGraphics.Canvas;

	(** Timer *)
	Timer* = OBJECT (WMComponents.Component)
	VAR
		onTimer-: EventSource;
		eStart-, eStop- : EventListenerInfo;
		interval-, delay- : WMProperties.Int32Property;
		wait-: LONGINT;
		alive: BOOLEAN;
		timer: Kernel.Timer;
		internalEnabled : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^();
			SetGenerator("WMStandardComponents.GenTimer");
			NEW(timer);
			alive := TRUE;
			enabled.Set(FALSE); internalEnabled := FALSE;
			NEW(onTimer, SELF, GSonTimer, GSonTimerInfo, SELF.StringToCompCommand); events.Add(onTimer);
			NEW(interval, PrototypeInterval, NIL, NIL); properties.Add(interval);
			NEW(delay, PrototypeDelay, NIL, NIL); properties.Add(interval);
			NEW(eStart, GSStart, GSStartTimerInfo, SELF.Start); eventListeners.Add(eStart);
			NEW(eStop, GSStop, GSStopTimerInfo, SELF.Stop); eventListeners.Add(eStop);
			SetNameAsString(StrTimer)
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF property = enabled THEN
				IF internalEnabled # enabled.Get() THEN
					IF enabled.Get() THEN Start(SELF, NIL) ELSE Stop(SELF, NIL) END
				END
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE Start*(sender, par : ANY); (** Eventhandler *)
		BEGIN
			enabled.Set(TRUE); BEGIN {EXCLUSIVE} internalEnabled := TRUE;wait := delay.Get() END;
		END Start;

		PROCEDURE Stop*(sender, par : ANY); (** Eventhandler *)
		BEGIN
			enabled.Set(FALSE); BEGIN {EXCLUSIVE} internalEnabled := FALSE; END;
		END Stop;

		PROCEDURE Finalize*; (** PROTECTED *)
		BEGIN
			timer.Wakeup; internalEnabled := FALSE; BEGIN {EXCLUSIVE} alive := FALSE END; Finalize^
		END Finalize;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE} AWAIT(internalEnabled OR ~alive) END;
			IF alive THEN
				timer.Sleep(wait);
				BEGIN {EXCLUSIVE} wait := interval.Get() END;
				IF internalEnabled & (onTimer # NIL) THEN onTimer.Call(NIL) END;
			END
		END
	END Timer;

	CursorBlinkerCallback = PROCEDURE {DELEGATE} (sender, data: ANY);

	(** Global thread that periodically toggles the visibility of the registered component *)
	Blinker* = OBJECT
	VAR
		events- : WMEvents.EventSource;

		interval : LONGINT;
		visible-: BOOLEAN;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE &Init;
		BEGIN
			interval := 500;
			visible := TRUE;
			alive := TRUE; dead := FALSE;
			NEW(timer);
			NEW(events, SELF, NIL, NIL,NIL);
			SetInterval(500);
		END Init;

		(** Set the cursor blinking interval in milliseconds. An interval of MAX(LONGINT) means don't blink *)
		PROCEDURE SetInterval*(ms : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(ms > 0);
			interval := ms;
			timer.Wakeup;
			IF (interval = MAX(LONGINT)) THEN
				visible := TRUE;
				events.Call(SELF);
			END;
		END SetInterval;

		PROCEDURE Finalize;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Finalize;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT(~alive OR ((interval # MAX(LONGINT))));
				IF alive THEN
					events.Call(SELF);
					visible := ~visible;
				END;
			END;
			timer.Sleep(interval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Blinker;


TYPE

	(** Timer *)
	InternalTimer* = OBJECT
	VAR
		onTimer : WMEvents.EventListener;
		interval : LONGINT;
		timer: Kernel.Timer;
		alive, dead, enabled: BOOLEAN;

		PROCEDURE &Init*(onTimer : WMEvents.EventListener);
		BEGIN
			ASSERT(onTimer # NIL);
			SELF.onTimer := onTimer;
			interval := 100; (* ms *)
			NEW(timer);
			alive := TRUE; dead := FALSE; enabled := FALSE;
		END Init;

		PROCEDURE SetInterval*(ms : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(ms > 0);
			interval := ms;
			timer.Wakeup;
		END SetInterval;

		PROCEDURE Start*;
		BEGIN {EXCLUSIVE}
			enabled := TRUE;
		END Start;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			enabled := FALSE;
		END Stop;

		PROCEDURE Finalize*;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; enabled := FALSE; END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Finalize;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE} AWAIT(enabled OR ~alive) END;
			IF alive THEN
				timer.Sleep(interval);
				IF enabled THEN onTimer(SELF, NIL); END;
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END InternalTimer;

	(** SystemCommand executes an AosCommand string *)
	(** Example : <SystemCommand execute="Bunny.Insert BunnyLinear.gif 8 16" /> *)
	SystemCommand* = OBJECT(WMComponents.Component)
	VAR
		commandString- : WMProperties.StringProperty;
		eRun- : EventListenerInfo;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenSystemCommand");
			NEW(commandString, PrototypeCommandString, NIL, NIL); properties.Add(commandString);
			NEW(eRun, GSRun, GSRunSystemCommandInfo, SELF.Run); eventListeners.Add(eRun);
			SetNameAsString(StrSystemCommand)
		END Init;

		PROCEDURE Run*(sender, par : ANY); (** Eventhandler *)
		VAR res : LONGINT; execute : String; msg : ARRAY 128 OF CHAR;
		BEGIN
			(* synchronize if not synchronized *)
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Run, sender, par)
			ELSE
				(* actual business logic *)
				execute := commandString.Get();
				IF execute # NIL THEN
					WMComponents.Call(execute^, SELF, {}, res, msg);
					IF res # 0 THEN KernelLog.Enter; KernelLog.String(msg); KernelLog.Exit END
				 END
			END
		END Run;
	END SystemCommand;

	(** Event executes a Component Event *)
	(** Example : <Event execute=%Timer1 Stop" /> *)
	Event* = OBJECT(WMComponents.Component)
	VAR
		commandString- : WMProperties.StringProperty;
		eRun- : EventListenerInfo;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenEvent");
			NEW(commandString, PrototypeCommandString, NIL, NIL); properties.Add(commandString);
			NEW(eRun, GSRun, GSCallEventInfo, SELF.Run); eventListeners.Add(eRun);
			SetNameAsString(StrEvent)
		END Init;

		PROCEDURE Run*(sender, par : ANY); (** Eventhandler *)
		VAR execute : String; event : EventListener;
		BEGIN
			(* synchronize if not synchronized *)
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Run, sender, par)
			ELSE
				(* actual business logic *)
				execute := commandString.Get();
				IF execute # NIL THEN
					event := StringToCompCommand(execute);
					IF event # NIL THEN event(sender, par) END;
				END
			END
		END Run;
	END Event;

(** Visual components *)
TYPE
	Panel* = OBJECT (WMComponents.VisualComponent)
	VAR
		blinking-: WMProperties.BooleanProperty;
		blink: BOOLEAN;
		show-: BOOLEAN; (* state for blinking *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			show := TRUE;
			SetGenerator("WMStandardComponents.GenPanel");
			SetNameAsString(StrPanel);
			NEW(blinking, PrototypeBlinking, NIL, NIL); properties.Add(blinking);
			blink := blinking.Get();
		END Init;
		
		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			PropertyChanged(SELF,blinking)
		END RecacheProperties;

		PROCEDURE SetBlinker(sender, data: ANY);	(* quite generic => might be moved to VisualComponent *)
		BEGIN
			WITH sender: Blinker DO
				show := sender.visible;
				(*visible.Set(sender.visible)*) (* more generic *)
			END;
			Invalidate;
		END SetBlinker;
		
		(* currently, the Panel has no own Draw method. 
		For this reason, blinking does not work in display of native Panels, but only on derived components 
		which handle the "show" variable in their DrawBackground method.
		could be done with the 'visible' property, too. 
		*)

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR b: BOOLEAN; element : XML.Element;
		BEGIN
			IF property = blinking THEN
				b := blinking.Get();
				IF b # blink THEN
					blink := b;
					IF b THEN
						blinker.events.Add(SetBlinker);
					ELSE
						blinker.events.Remove(SetBlinker);
						show := TRUE;
						(*? visible.Set(TRUE);*)
					END;
					Invalidate;
				END;
			ELSE
				PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

(*
		PROCEDURE Draw*(canvas : WMGraphics.Canvas);
		BEGIN
			IF show THEN Draw^(canvas) END;
		END Draw;
*)

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			blinker.events.Remove(SetBlinker);
		END Finalize;

	END Panel;


TYPE
	Decoration= POINTER TO RECORD
		TL, T, TR, L, M, R, BL, B, BR: WMGraphics.Image;
	END;

	(*
	DecoratorPanel* = OBJECT (WMComponents.VisualComponent)
	CONST TopLeft=0; Top=1; TopRight=2; Left=3; Right=4; BottomLeft =5; Bottom=6; BottomRight=7;Middle=8;
	VAR
		defaultImageName:  WMProperties.StringProperty;
		defaultDecoration: Decoration;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenDecoratorPanel");
			SetNameAsString(StrPanel);
			defaultDecoration := NIL;
			NEW(defaultImageName, PrototypeDecoratorName, NIL, NIL); properties.Add(defaultImageName);
		END Init;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			Invalidate
		END RecacheProperties;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR mode, mid, borderWidth : LONGINT;
			 tc : WMGraphics.Color; r, rect : WMGraphics.Rectangle; down : BOOLEAN;
			 str : String; deco: Decoration;
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			GetDecoration(defaultImageName.Get(), defaultDecoration);
			deco := defaultDecoration;

			Acquire;
				rect := bounds.Get();
				inner := rect;
				IF deco.TL # NIL THEN
					IF inner.left < deco.
				END;
			Release;
		END DrawBackground;

	END DecoratorPanel;
	*)

TYPE

	Label* = OBJECT(Panel)
	VAR
		caption- : WMProperties.StringProperty;
		textColor- : WMProperties.ColorProperty;
		alignH- : WMProperties.Int32Property;
		alignV- : WMProperties.Int32Property;

		PROCEDURE &Init*;
		BEGIN
			Init^;

			NEW(caption, PrototypeCaption, NIL, NIL); properties.Add(caption);
			NEW(textColor, PrototypeTextColor, NIL, NIL); properties.Add(textColor);
			NEW(alignH, PrototypeAlignH, NIL, NIL); properties.Add(alignH);
			NEW(alignV, PrototypeAlignV, NIL, NIL); properties.Add(alignV);

			SetGenerator("WMStandardComponents.GenLabel");
			SetNameAsString(StrLabel)
		END Init;
		
	
		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			SetFont(font.Get());
		END RecacheProperties;
		

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR element : XML.Element;
		BEGIN
			IF (property = caption) OR (property = textColor) OR (property = alignH) OR (property = alignV) THEN
				Invalidate
			ELSIF (property = font) THEN
				RecacheProperties; 
				Invalidate
			ELSIF property = model THEN Invalidate
			ELSE
				PropertyChanged^(sender, property)
			END;
		END PropertyChanged;


		PROCEDURE SetCaption*(CONST x : ARRAY OF CHAR);
		BEGIN
			caption.SetAOC(x)
		END SetCaption;

		PROCEDURE LinkChanged(sender, data : ANY);
		VAR string : Types.String256; res : LONGINT; m: Models.Model;
		BEGIN
			IF (sender = model) & WMProperties.GetModel(model,m) THEN
				m.GetGeneric(string, res);
				IF (res = Models.Ok) THEN
					SetCaption(string.value);
				END;
			END;
		END LinkChanged;

		PROCEDURE DrawBackground*(canvas : Canvas);
		VAR str : String;
		BEGIN
			DrawBackground^(canvas); str := caption.Get();
			IF (str # NIL) & show THEN
				canvas.SetColor(textColor.Get());
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, alignH.Get(), alignV.Get(), str^)
			END;
		END DrawBackground;

	END Label;

TYPE



	(** Button *)
	Button* = OBJECT (WMComponents.VisualComponent)
	CONST
		TextBorder=0;
	VAR
		caption- : WMProperties.StringProperty;
		isRepeating-, isToggle-, indicateToggle- : WMProperties.BooleanProperty;
		isInverse-: WMProperties.BooleanProperty;

		onClickHandler- : WMProperties.StringProperty;

		clDefault-, clHover-, clPressed-, clInactive-,
		clTextDefault-, clTextHover-, clTextPressed-, clTextInactive- : WMProperties.ColorProperty;
		effect3D- : WMProperties.Int32Property;

		(* single images *)
		imgDefaultName-, imgInactiveName-, imgHoverName-, imgPressedName-, imageName- : WMProperties.StringProperty;
		imgDefault, imgInactive, imgHover, imgPressed : WMGraphics.Image;

		useBgBitmaps-, isHorizontal-, repeatMiddleImg-  : WMProperties.BooleanProperty;

	 	(* 3 x 3 background images for horizontal representation *)
	 	imgDefaultNameLeft-, imgDefaultNameRight-, imgDefaultNameMiddle-,
	 	imgHoverNameLeft-, imgHoverNameRight-, imgHoverNameMiddle-,
	 	imgPressedNameLeft-, imgPressedNameRight-, imgPressedNameMiddle- : WMProperties.StringProperty;
	 	imgDefaultLeft, imgDefaultRight, imgDefaultMiddle,
	 	imgHoverLeft, imgHoverRight, imgHoverMiddle,
	 	imgPressedLeft, imgPressedRight, imgPressedMiddle : WMGraphics.Image;

	 	(* 3 x 2 background images for vertical representation *)
	 	imgDefaultNameTop-, imgDefaultNameBottom-,
	 	imgHoverNameTop-, imgHoverNameBottom-,
	 	imgPressedNameTop-, imgPressedNameBottom- : WMProperties.StringProperty;
	 	imgDefaultTop, imgDefaultBottom,
	 	imgHoverTop, imgHoverBottom,
	 	imgPressedTop, imgPressedBottom : WMGraphics.Image;

		useDeco-: WMProperties.BooleanProperty;
		(* 3x9 backgound images for scalable representation *)
		decoDefaultName-, decoHoverName-, decoPressedName-: WMProperties.StringProperty;
		decoDefault-, decoHover-, decoPressed-: Decoration;


		onClick- : EventSource;

	 	(* foreground image *)
	 	image : WMGraphics.Image;
		pressed, keyboardPressed, mouseOver: BOOLEAN;
		handler : WMEvents.EventListener;
		invert3d : BOOLEAN;
		repeater : Timer;

		userData* : ANY;

		textAlignH- : WMProperties.Int32Property;
		textAlignV- : WMProperties.Int32Property;
		horizontalFit: WMProperties.BooleanProperty;
		textBorder: WMProperties.Int32Property;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrButton);
			NEW(caption, PrototypeBcaption, NIL, NIL); properties.Add(caption);

			(* behavior *)
			NEW(isRepeating, PrototypeBisRepeating, NIL, NIL); properties.Add(isRepeating);
			NEW(isToggle, PrototypeBisToggle, NIL, NIL); properties.Add(isToggle);
			NEW(isInverse, PrototypeBisInverse, NIL, NIL); properties.Add(isInverse);
			NEW(indicateToggle, PrototypeBindicateToggle, NIL, NIL); properties.Add(indicateToggle);
			NEW(onClickHandler, PrototypeBonClickHandler, NIL, NIL); properties.Add(onClickHandler);
			(* look *)
			bounds.SetPrototype(PrototypeBBounds); (* override the defaults *)
			NEW(clDefault, PrototypeBclDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clHover, PrototypeBclHover, NIL, NIL); properties.Add(clHover);
			NEW(clPressed, PrototypeBclPressed, NIL, NIL); properties.Add(clPressed);
			NEW(clInactive, PrototypeBclInactive, NIL, NIL); properties.Add(clInactive);
			NEW(clTextDefault, PrototypeBclTextDefault, NIL, NIL); properties.Add(clTextDefault);
			NEW(clTextHover, PrototypeBclTextHover, NIL, NIL); properties.Add(clTextHover);
			NEW(clTextPressed, PrototypeBclTextPressed,  NIL, NIL); properties.Add(clTextPressed);
			NEW(clTextInactive, PrototypeBclTextInactive, NIL, NIL); properties.Add(clTextInactive);
			NEW(effect3D, PrototypeBEffect3D, NIL, NIL); properties.Add(effect3D);
				(* --- *)
			NEW(imgDefaultName, PrototypeBimgDefaultName, NIL, NIL); properties.Add(imgDefaultName);
			NEW(imgInactiveName, PrototypeBimgInactiveName, NIL, NIL); properties.Add(imgInactiveName);
			NEW(imgHoverName, PrototypeBimgHoverName, NIL, NIL); properties.Add(imgHoverName);
			NEW(imgPressedName, PrototypeBimgPressedName, NIL, NIL); properties.Add(imgPressedName);
			NEW(imageName, PrototypeBimageName, NIL, NIL); properties.Add(imageName);
				(* --- *)
			NEW(useBgBitmaps, PrototypeBUseBgImages, NIL, NIL); properties.Add(useBgBitmaps);
			NEW(isHorizontal, PrototypeBIsHorizontal, NIL, NIL); properties.Add(isHorizontal);
			NEW(repeatMiddleImg, PrototypeBRepeatMiddleImg, NIL, NIL); properties.Add(repeatMiddleImg);
				(* --- *)
			NEW(imgDefaultNameLeft, PrototypeImgDefaultNameLeft, NIL, NIL); properties.Add(imgDefaultNameLeft);
		 	NEW(imgDefaultNameRight, PrototypeImgDefaultNameRight, NIL, NIL); properties.Add(imgDefaultNameRight);
		 	NEW(imgDefaultNameMiddle, PrototypeImgDefaultNameMiddle, NIL, NIL); properties.Add(imgDefaultNameMiddle);
			NEW(imgHoverNameLeft, PrototypeImgHoverNameLeft, NIL, NIL); properties.Add(imgHoverNameLeft);
		 	NEW(imgHoverNameRight, PrototypeImgHoverNameRight, NIL, NIL); properties.Add(imgHoverNameRight);
		 	NEW(imgHoverNameMiddle, PrototypeImgHoverNameMiddle, NIL, NIL); properties.Add(imgHoverNameMiddle);
			NEW(imgPressedNameLeft, PrototypeImgPressedNameLeft, NIL, NIL); properties.Add(imgPressedNameLeft);
		 	NEW(imgPressedNameRight, PrototypeImgPressedNameRight, NIL, NIL); properties.Add(imgPressedNameRight);
		 	NEW(imgPressedNameMiddle, PrototypeImgPressedNameMiddle, NIL, NIL); properties.Add(imgPressedNameMiddle);
 				(* --- *)
 			NEW(useDeco, PrototypeUseDeco, NIL, NIL); properties.Add(useDeco);
			NEW(decoDefaultName, PrototypeDecoDefaultName, NIL, NIL); properties.Add(decoDefaultName);
			NEW(decoHoverName, PrototypeDecoHoverName, NIL, NIL); properties.Add(decoHoverName);
			NEW(decoPressedName, PrototypeDecoPressedName, NIL, NIL); properties.Add(decoPressedName);
 				(* --- *)
			NEW(imgDefaultNameTop, PrototypeImgDefaultNameTop, NIL, NIL); properties.Add(imgDefaultNameTop);
		 	NEW(imgDefaultNameBottom, PrototypeImgDefaultNameBottom, NIL, NIL); properties.Add(imgDefaultNameBottom);
			NEW(imgHoverNameTop, PrototypeImgHoverNameTop, NIL, NIL); properties.Add(imgHoverNameTop);
		 	NEW(imgHoverNameBottom, PrototypeImgHoverNameBottom, NIL, NIL); properties.Add(imgHoverNameBottom);
			NEW(imgPressedNameTop, PrototypeImgPressedNameTop, NIL, NIL); properties.Add(imgPressedNameTop);
		 	NEW(imgPressedNameBottom, PrototypeImgPressedNameBottom, NIL, NIL); properties.Add(imgPressedNameBottom);

			NEW(textAlignH, PrototypeButtonAlignH, NIL, NIL); properties.Add(textAlignH);
			NEW(textAlignV, PrototypeButtonAlignV, NIL, NIL); properties.Add(textAlignV);
			NEW(horizontalFit, PrototypeHorizontalFit, NIL, NIL); properties.Add(horizontalFit);
			NEW(textBorder, PrototypeTextBorder, NIL, NIL); properties.Add(textBorder);

			(* events *)
			NEW(onClick, SELF, GSonClick, GSonClickButtonInfo, SELF.StringToCompCommand); events.Add(onClick);
			SetGenerator("WMStandardComponents.GenButton");
		END Init;

		PROCEDURE CheckClickHandler;
		VAR th : WMEvents.EventListener; s : String;
		BEGIN
			s := onClickHandler.Get();
			IF s # NIL THEN
				th := StringToCompCommand(s);
				IF (handler # NIL) THEN onClick.Remove(handler) END;
				IF th # NIL THEN onClick.Add(th); handler := th END
			END
		END CheckClickHandler;

		PROCEDURE ExecuteClickHandler;
		VAR s : Strings.String; res : LONGINT; msg : ARRAY 64 OF CHAR;
		BEGIN
			s := onClickHandler.Get();
			IF s # NIL THEN
				IF Strings.StartsWith2(Repositories.CommandPrefix, s^) THEN
					WMComponents.Call(s^, SELF, {}, res, msg);
				END;
			END;
		END ExecuteClickHandler;

		PROCEDURE ScaleFont*(height: LONGINT; percent: LONGINT);
		VAR fh,hfh,ntw,newSize,width: LONGINT; f,hf: WMGraphics.Font; str: String; tw, th: LONGINT; oldFontSize: LONGINT;
		BEGIN
			height := height - 2*textBorder.Get();
			IF height < 4 THEN height := 4 END;
			IF percent <= 0 THEN RETURN END;
			
			Acquire;
			oldFontSize := font.GetSize(); 
			
			(* vertical scaling *)
			f := GetFont();
			hf := WMGraphics.GetFont(f.name, 100, f.style); (* expensive ? *)
			hfh := hf.GetAscent() + hf.GetDescent();
			fh := height * percent DIV hfh;

			IF fh > 128 THEN fh := fh - fh MOD 8
			ELSIF fh > 64 THEN fh := fh - fh MOD 4
			ELSIF fh > 32 THEN fh := fh - fh MOD 2
			END;
			
			font.SetSize(fh);
			f := GetFont();
			
			IF horizontalFit.Get()  THEN
				width := bounds.GetWidth() - 2*textBorder.Get();
				str := caption.Get();
				IF str # NIL THEN
					f.GetStringSize(str^, tw, th);
					IF tw > width THEN 
						fh :=fh * width DIV tw;
						IF fh > 100 THEN fh := fh - fh MOD 8
						ELSIF fh > 32 THEN fh := fh - fh MOD 4
						ELSIF fh > 12 THEN fh := fh - fh MOD 2
						END;
						
						(* correction loop if scaling does not fit correctly *)
						REPEAT 
						font.SetSize(fh);
							f := GetFont();
							f.GetStringSize(str^, tw, th);
							DEC(fh);
						UNTIL (fh <= 4) OR (tw <= width);
							
						

					END;
				END;
			END;
			
			IF font.GetSize() # oldFontSize THEN
				Invalidate;
			END;
				
			Release;
		END ScaleFont;

		PROCEDURE RecacheProperties;
		VAR element : XML.Element; s : String;
		BEGIN
			RecacheProperties^;
			s := imageName.Get(); IF s # NIL THEN image := WMGraphics.LoadImage(s^, TRUE) END;
			(* --- *)
			IF useBgBitmaps.Get() THEN
				s := imgDefaultNameLeft.Get();		IF s # NIL THEN imgDefaultLeft		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultNameRight.Get();		IF s # NIL THEN imgDefaultRight		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultNameMiddle.Get();	IF s # NIL THEN imgDefaultMiddle	:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverNameLeft.Get();		IF s # NIL THEN imgHoverLeft		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverNameRight.Get();		IF s # NIL THEN imgHoverRight		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverNameMiddle.Get();		IF s # NIL THEN imgHoverMiddle		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedNameLeft.Get();		IF s # NIL THEN imgPressedLeft		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedNameRight.Get();		IF s # NIL THEN imgPressedRight		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedNameMiddle.Get();	IF s # NIL THEN imgPressedMiddle	:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultNameTop.Get();		IF s # NIL THEN imgDefaultTop		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultNameBottom.Get();	IF s # NIL THEN imgDefaultBottom	:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverNameTop.Get();		IF s # NIL THEN imgHoverTop			:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverNameBottom.Get();	IF s # NIL THEN imgHoverBottom		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedNameTop.Get();		IF s # NIL THEN imgPressedTop		:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedNameBottom.Get();	IF s # NIL THEN imgPressedBottom	:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgHoverName.Get();			IF s # NIL THEN imgHover			:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgPressedName.Get();			IF s # NIL THEN imgPressed			:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultName.Get();			IF s # NIL THEN imgDefault			:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgInactiveName.Get(); 		IF s # NIL THEN imgInactive			:= WMGraphics.LoadImage(s^, TRUE) END;
			ELSE
				imgDefaultLeft := NIL; imgDefaultRight := NIL; imgDefaultMiddle := NIL;
				imgHoverLeft := NIL; imgHoverRight := NIL; imgHoverMiddle := NIL;
				imgPressedLeft := NIL; imgPressedRight := NIL; imgPressedMiddle := NIL;
				imgDefaultTop := NIL; imgDefaultBottom := NIL;
				imgHoverTop := NIL; imgHoverBottom := NIL;
				imgPressedTop := NIL; imgPressedBottom := NIL;
				imgHover := NIL;
				imgPressed := NIL;
				imgDefault := NIL;
			END;
			IF useDeco.Get() THEN
				GetDecoration(decoDefaultName.Get(), decoDefault);
				GetDecoration(decoHoverName.Get(), decoHover);
				GetDecoration(decoPressedName.Get(), decoPressed);
			ELSE
				decoDefault := NIL; decoHover := NIL; decoPressed := NIL;
			END;

			(*?PH drop this, as it belongs to parent type recaching ?*)SetFont(font.Get());
			CheckClickHandler;
		END RecacheProperties;

		PROCEDURE LinkChanged(sender, data : ANY);
		VAR boolean : Types.Boolean; res : LONGINT; m: Models.Model;
		BEGIN
			IF (sender = model) & WMProperties.GetModel(model,m) THEN
				m.GetGeneric(boolean, res);
				IF isInverse.Get() THEN boolean.value := ~boolean.value END;
				IF (res = Models.Ok) & (pressed # boolean.value) THEN
					SetPressed(boolean.value);
				END;
			END;
		END LinkChanged;

		PROCEDURE ChangeModel(value : BOOLEAN);
		VAR boolean : Types.Boolean; res : LONGINT; m: Models.Model;
		BEGIN
			IF WMProperties.GetModel(model, m) THEN
				IF isInverse.Get() THEN boolean.value := ~value ELSE boolean.value := value END;
				m.SetGeneric(boolean, res);
			END;
		END ChangeModel;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		VAR element : XML.Element;
		BEGIN
			IF (data = caption)  THEN 
				IF horizontalFit.Get() THEN ScaleFont(bounds.GetHeight(), scaleFont.Get()) END; 
				Invalidate;
			ELSIF (data = textAlignH) OR (data = textAlignV) THEN Invalidate;
			ELSIF (data = onClickHandler) THEN CheckClickHandler
			ELSIF (data = clDefault) OR (data = clHover) OR (data = clPressed) OR (data = clTextInactive)
				OR (data = clTextDefault) OR (data = clTextHover) OR (data = clTextPressed) OR (data = clTextInactive) THEN Invalidate;
			(*ELSIF (data = font) THEN SetFont(font.Get()); Invalidate;*) (*? drop this, as PropertyChanged^ handles this *)
			ELSIF (data = isToggle) OR (data = indicateToggle) OR (data = isHorizontal) OR (data = repeatMiddleImg) OR (data = effect3D) THEN Invalidate;
			ELSIF (data = imageName) OR (data = useBgBitmaps)
				OR (data = imgDefaultNameLeft) OR (data = imgDefaultNameMiddle) OR (data = imgDefaultNameRight)
				OR (data = imgHoverNameLeft) OR (data = imgHoverNameMiddle) OR (data = imgHoverNameRight)
				OR (data = imgPressedNameLeft) OR (data = imgPressedNameMiddle) OR (data = imgPressedNameRight)
				OR (data = imgDefaultNameTop) OR (data = imgDefaultNameBottom)
				OR (data = imgHoverNameTop) OR (data = imgHoverNameBottom)
				OR (data = imgPressedNameTop) OR (data = imgPressedNameBottom)
				OR (data = imgDefaultName) OR (data = imgPressedName)
				OR (data = imgHoverName) OR (data = imgInactiveName) OR (data = enabled)
				OR (data = decoDefaultName) OR (data = decoHoverName) OR (data= decoPressedName) OR (data = useDeco) OR (data=horizontalFit) OR (data = textBorder)
				THEN
					RecacheProperties; Invalidate;
			ELSIF (data = model) THEN Invalidate
			ELSE
				PropertyChanged^(sender, data);
			END;
		END PropertyChanged;

		PROCEDURE CheckRepeating(start : BOOLEAN);
		BEGIN
			IF isRepeating.Get() THEN
				IF start THEN
					IF repeater = NIL THEN NEW(repeater); AddContent(repeater); repeater.onTimer.Add(Click) END;
					repeater.Start(SELF, NIL)
				ELSE
					IF repeater # NIL THEN repeater.Stop(SELF, NIL) END
				END
			END
		END CheckRepeating;

		PROCEDURE SetInvert3d*(invert : BOOLEAN);
		BEGIN
			Acquire;
			IF invert # invert3d THEN invert3d := invert; Invalidate END;
			Release
		END SetInvert3d;

		PROCEDURE SetPressed*(down : BOOLEAN);
		VAR changed : BOOLEAN;
		BEGIN
			Acquire;
			IF pressed # down THEN
				changed := TRUE;
				pressed := down;
				Invalidate;
			END;
			Release;
			IF changed THEN ChangeModel(pressed); END;
		END SetPressed;

		PROCEDURE GetPressed*() : BOOLEAN;
		BEGIN
			RETURN pressed;
		END GetPressed;

		PROCEDURE FocusReceived*;
		BEGIN
			FocusReceived^;
			Invalidate
		END FocusReceived;

		PROCEDURE FocusLost*;
		BEGIN
			FocusLost^;
			Invalidate
		END FocusLost;

		PROCEDURE Down;
		BEGIN
			IF ~isToggle.Get() THEN
				IF ~pressed THEN pressed := TRUE; Invalidate; CheckRepeating(TRUE) END;
				ChangeModel(pressed);
			ELSE
				pressed := ~pressed; Invalidate;
			END;
		END Down;

		PROCEDURE Up;
		BEGIN
			IF isToggle.Get() THEN
				ChangeModel(pressed); Click(SELF, userData); 
				RETURN 
			END;
			IF pressed & (mouseOver OR keyboardPressed) THEN
				CheckRepeating(FALSE);  
				Click(SELF, userData);
				pressed := FALSE;
				Invalidate
			END;
			pressed := FALSE;
			ChangeModel(pressed);
		END Up;

		PROCEDURE PointerDown(x, y: LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			IF enabled.Get() THEN Down END;
			PointerDown^(x, y, keys)
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			IF enabled.Get() THEN
				IF IsHit(x, y) THEN
					IF ~mouseOver THEN mouseOver := TRUE; IF pressed THEN CheckRepeating(TRUE) END; Invalidate END
				ELSE
					IF mouseOver THEN mouseOver := FALSE; IF pressed THEN CheckRepeating(FALSE) END; Invalidate END
				END
			ELSE mouseOver := FALSE
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			Up;
			PointerUp^(x, y, keys)
		END PointerUp;

		PROCEDURE PointerLeave*; (** PROTECTED *)
		BEGIN
			 mouseOver := FALSE; Invalidate
		END PointerLeave;

		PROCEDURE SetCaption*(CONST x : ARRAY OF CHAR);
		BEGIN
			caption.Set(WMComponents.NewString(x))
		END SetCaption;

		PROCEDURE IsHit(x, y: LONGINT) : BOOLEAN;
		VAR t : BOOLEAN;
		BEGIN
			IF ~visible.Get() THEN RETURN FALSE END;
			Acquire;
			t := WMRectangles.PointInRect(x, y, GetClientRect());
			IF useBgBitmaps.Get() THEN
				IF isHorizontal.Get() THEN
					t := t & IsHitHorizontal(x, y)
				ELSE
					t := t & IsHitVertical(x, y)
				END
			END;
			Release;
			RETURN t
		END IsHit;

 		PROCEDURE IsHitHorizontal(x, y: LONGINT) : BOOLEAN;
 		VAR a, b, c : WMGraphics.Image; aw, bw, cw : LONGINT;
 		BEGIN
			IF imgDefault # NIL THEN
				RETURN WMGraphics.IsScaledBitmapHit (x,y,bounds.GetWidth(), bounds.GetHeight(), 64,imgDefault);
			ELSE
	 			GetHorizontalImages(a, b, c);
		 		IF a # NIL THEN aw := a.width ELSE aw := 0 END;
		 		IF c # NIL THEN cw := c.width ELSE cw := 0 END;
		 		bw := bounds.GetWidth() - aw - cw;
		 		IF x < aw THEN
		 			y := y * a.height DIV bounds.GetHeight();
	 				RETURN WMGraphics.IsBitmapHit(x, y, 64, a)
		 		ELSIF x > bounds.GetWidth() - cw THEN
		 			y := y * c.height DIV bounds.GetHeight();
	 				RETURN WMGraphics.IsBitmapHit(x-aw-bw, y, 64, c)
		 		ELSE (* middle image *)
		 			IF b = NIL THEN RETURN FALSE END; (* no image loaded, so the button cannot be hit *)
		 			y := y * b.height DIV bounds.GetHeight();
		 			IF repeatMiddleImg.Get() THEN
		 				RETURN WMGraphics.IsBitmapHit((x-aw) MOD b.width, y, 64, b)
		 			ELSE
			 			RETURN WMGraphics.IsBitmapHit((x-aw) * b.width DIV bw, y, 64, b)
		 			END
				END
			END
 		END IsHitHorizontal;

 		PROCEDURE IsHitVertical(x, y: LONGINT) : BOOLEAN;
 		VAR a, b, c : WMGraphics.Image; ah, bh, ch : LONGINT;
 		BEGIN
 			GetVerticalImages(a, b, c);
	 		IF a # NIL THEN ah := a.height ELSE ah := 0 END;
	 		IF c # NIL THEN ch := c.height ELSE ch := 0 END;
	 		bh := bounds.GetHeight() - ah - ch;
	 		IF y < ah THEN
	 			x := x * a.width DIV bounds.GetWidth();
 				RETURN WMGraphics.IsBitmapHit(x, y, 64, a)
	 		ELSIF y > bounds.GetHeight() - ch THEN
	 			x := x * c.width DIV bounds.GetWidth();
 				RETURN WMGraphics.IsBitmapHit(x, y-ah-bh, 64, c)
	 		ELSE (* middle image *)
	 			IF b = NIL THEN RETURN FALSE END; (* no image loaded, so the button cannot be hit *)
	 			x := x * b.width DIV bounds.GetWidth();
	 			IF repeatMiddleImg.Get() THEN
	 				RETURN WMGraphics.IsBitmapHit(x, (y-ah) MOD b.height, 64, b)
	 			ELSE
		 			RETURN WMGraphics.IsBitmapHit(x, (y-ah) * b.height DIV bh, 64, b)
	 			END
			END
 		END IsHitVertical;

 		(* load images appropriate to the actual state of the button. a: left, b: middle, c: right *)
 		PROCEDURE GetHorizontalImages(VAR a, b, c : WMGraphics.Image);
 		VAR down : BOOLEAN;
 		BEGIN
 			down := pressed & (mouseOver OR isToggle.Get() OR keyboardPressed);
			IF down THEN
				IF imgPressedMiddle # NIL THEN
					a := imgPressedLeft; b := imgPressedMiddle; c := imgPressedRight; RETURN
				ELSIF imgHoverMiddle # NIL THEN
					a := imgHoverLeft; b := imgHoverMiddle; c := imgHoverRight; RETURN
				ELSE
					a := imgDefaultLeft; b := imgDefaultMiddle; c := imgDefaultRight; RETURN
				END
			ELSIF mouseOver THEN
				IF imgHoverMiddle # NIL THEN
					a := imgHoverLeft; b := imgHoverMiddle; c := imgHoverRight; RETURN
				ELSE
					a := imgDefaultLeft; b := imgDefaultMiddle; c := imgDefaultRight; RETURN
				END
			ELSE
				a := imgDefaultLeft; b := imgDefaultMiddle; c := imgDefaultRight; RETURN
			END
 		END GetHorizontalImages;

 		(* load images appropriate to the actual state of the button. a: top, b: middle, c: bottom *)
 		PROCEDURE GetVerticalImages(VAR a, b, c : WMGraphics.Image);
 		VAR down : BOOLEAN;
 		BEGIN
 			down := pressed & (mouseOver OR isToggle.Get() OR keyboardPressed);
			IF down THEN
				IF imgPressedMiddle # NIL THEN
					a := imgPressedTop; b := imgPressedMiddle; c := imgPressedBottom; RETURN
				ELSIF imgHoverMiddle # NIL THEN
					a := imgHoverTop; b := imgHoverMiddle; c := imgHoverBottom; RETURN
				ELSE
					a := imgDefaultTop; b := imgDefaultMiddle; c := imgDefaultBottom; RETURN
				END
			ELSIF mouseOver THEN
				IF imgHoverMiddle # NIL THEN
					a := imgHoverTop; b := imgHoverMiddle; c := imgHoverBottom; RETURN
				ELSE
					a := imgDefaultTop; b := imgDefaultMiddle; c := imgDefaultBottom; RETURN
				END
			ELSE
				a := imgDefaultTop; b := imgDefaultMiddle; c:= imgDefaultBottom; RETURN
			END
 		END GetVerticalImages;

 		PROCEDURE GetDecorationImage(name: String; CONST suffix: ARRAY OF CHAR; VAR image:WMGraphics.Image);
		VAR fileName, extension: Files.FileName;
		BEGIN
			IF (name = NIL) OR (name^="") THEN
				image := NIL;
			ELSE
				Files.SplitExtension(name^, fileName, extension);
				Strings.Append(fileName, suffix);
				Files.JoinExtension(fileName,extension, fileName);
				image := WMGraphics.LoadImage(fileName, TRUE);
			END;
		END GetDecorationImage;

		PROCEDURE GetDecoration(name: String; VAR d: Decoration);
		BEGIN
			IF (name = NIL) OR (name^ = "") THEN d := NIL; RETURN END;
			IF d = NIL THEN
				NEW(d);
			END;
			GetDecorationImage(name, "TL", d.TL);
			GetDecorationImage(name, "T", d.T);
			GetDecorationImage(name, "TR", d.TR);
			GetDecorationImage(name, "L", d.L);
			GetDecorationImage(name, "M", d.M);
			GetDecorationImage(name, "R", d.R);
			GetDecorationImage(name, "BL", d.BL);
			GetDecorationImage(name, "B", d.B);
			GetDecorationImage(name, "BR", d.BR);
			IF (d.M = NIL) & (d.T = NIL) & (d.TR = NIL) & (d.L = NIL) & (d.M = NIL) & (d.R= NIL) & (d.BR = NIL) & (d.B=NIL) & (d.BR = NIL) THEN
				d := NIL
			END;
		END GetDecoration;

		 (* load images appropriate to the actual state of the button. a: left, b: middle, c: right *)
 		PROCEDURE GetThisDecoration(VAR d : Decoration);
 		VAR down : BOOLEAN;
 		BEGIN
 			down := pressed & (mouseOver OR isToggle.Get() OR keyboardPressed);
			IF down THEN
				IF decoPressed # NIL THEN d := decoPressed;
				ELSIF decoHover # NIL THEN d := decoHover
				ELSE d := decoDefault;
				END
			ELSIF mouseOver THEN
				IF decoHover # NIL THEN d := decoHover
				ELSE d := decoDefault
				END
			ELSE d := decoDefault
			END
 		END GetThisDecoration;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR mode, mid, borderWidth : LONGINT;
			 tc : WMGraphics.Color; r, rect : WMGraphics.Rectangle; down : BOOLEAN;
			 str : String;
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			down := pressed;
			IF ~enabled.Get() THEN mid := clInactive.Get(); tc := clTextInactive.Get()
			ELSIF down THEN mid := clPressed.Get(); tc := clTextPressed.Get()
			ELSIF mouseOver THEN 	mid := clHover.Get(); tc := clTextHover.Get()
			ELSE mid := clDefault.Get();	tc := clTextDefault.Get()	END;
			IF useBgBitmaps.Get() THEN
				IF isHorizontal.Get() THEN
					DrawHorizontalBackground(canvas)
				ELSE
					DrawVerticalBackground(canvas)
				END
			ELSIF useDeco.Get() THEN
				DrawDecoBackground(canvas)
			ELSE
				IF invert3d THEN down := ~down END;
				rect := GetClientRect();
				mode := WMGraphics.ModeSrcOverDst;
				borderWidth := 1;
				IF mid # 0 THEN canvas.Fill(rect, mid, mode) END;
				IF SELF.effect3D.Get() > 0 THEN WMGraphicUtilities.RectGlassShade(canvas, rect, SELF.effect3D.Get(), down) END
			END;
			(* focus *)
			IF hasFocus THEN WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, -1), LONGINT(0FF000080H), mode) END;
			(* foreground *)
			IF image # NIL THEN canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst) END;
			str := caption.Get();
			IF str # NIL THEN
				r := GetClientRect();
				r := WMRectangles.MakeRect(r.l + TextBorder, r.t+TextBorder, r.r - TextBorder, r.b - TextBorder );
				canvas.SetColor(tc);
				WMGraphics.DrawStringInRect(canvas, r, FALSE, textAlignH.Get(), textAlignV.Get(), str^)
			END;
			IF isToggle.Get() & indicateToggle.Get() THEN
				IF pressed THEN tc := WMGraphics.Green;
				ELSE tc := WMGraphics.Red;
				END;
				canvas.Fill(WMRectangles.MakeRect(bounds.GetWidth()-8, 4, bounds.GetWidth()-4, 5), tc, WMGraphics.ModeSrcOverDst);
				WMGraphicUtilities.ExtRectGlassShade(canvas,
					WMRectangles.MakeRect(bounds.GetWidth()-9, 3, bounds.GetWidth()-3, 6), {},
					1, TRUE);
			END;
			Release
		END DrawBackground;


		PROCEDURE DrawDecoBackground(canvas : WMGraphics.Canvas);
		VAR
			 deco: Decoration;

			 l,r,t,b: LONGINT;
			 (* left and right boundaries *)
			 tl, ml, bl, tr, mr, br: LONGINT;
			 (* top and bottom boundaries *)
			 lt, mt, rt, lb, mb, rb: LONGINT;

			 maxBorder: LONGINT;

			 PROCEDURE Draw(img:WMGraphics.Image; l,t,r,b: LONGINT );
			 BEGIN
			 	IF (r>l) & (b>t) & (img # NIL) THEN
		 			canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, img.width, img.height),	WMRectangles.MakeRect(l,t,r,b), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
		 		END;
			 END Draw;

			 PROCEDURE Scale(i: LONGINT): LONGINT;
			 BEGIN
			 	IF i > maxBorder THEN RETURN maxBorder ELSE RETURN i END;
			 END Scale;


		BEGIN
			GetThisDecoration(deco);
			l := bounds.GetLeft(); r := bounds.GetRight();
			t := bounds.GetTop(); b := bounds.GetBottom();
			(* but we are drawing relative to 0,0 : *)
			r := r-l; b := b-t; l := 0; t := 0;
			IF r > b THEN maxBorder := b DIV 5 ELSE maxBorder := r DIV 5 END;

			IF deco = NIL THEN RETURN END;

			IF deco.TL # NIL THEN tl := Scale(deco.TL.width); lt := Scale(deco.TL.height); Draw(deco.TL, l,t,l+tl,t+lt)
			ELSE tl := 0; lt := 0;
			END;
			IF deco.TR # NIL THEN tr := Scale(deco.TR.width); rt := Scale(deco.TR.height); Draw(deco.TR, r-tr, t, r, t+rt);
			ELSE tr := 0; rt := 0;
			END;
			IF deco.BL # NIL THEN bl := Scale(deco.BL.width); lb := Scale(deco.BL.height); Draw(deco.BL, l, b-lb, l + bl, b);
			ELSE bl := 0; lb := 0;
			END;
			IF deco.BR # NIL THEN br := Scale(deco.BR.width); rb := Scale(deco.BR.height); Draw(deco.BR, r-br, b-rb, r, b);
			ELSE br := 0; rb := 0;
			END;
			IF deco.L # NIL THEN ml := Scale(deco.L.width); Draw(deco.L, l, t+lt, l+ml, b-lb);
			ELSE ml := 0;
			END;
			IF deco.R # NIL THEN mr := Scale(deco.R.width); Draw(deco.R, r-br, t+rt, r, b-rb);
			ELSE mr := 0;
			END;
			IF deco.T # NIL THEN mt := Scale(deco.T.height); Draw(deco.T, l+tl, t, r-tr, t+mt);
			ELSE mt := 0;
			END;
			IF deco.B # NIL THEN mb := Scale(deco.B.height); Draw(deco.B, l+bl, b-mb, r-br, b);
			ELSE mb := 0;
			END;
			IF deco.M # NIL THEN Draw(deco.M, l+ml, t+mt, r-br, b-mb);
			END;
		END DrawDecoBackground;

		PROCEDURE DrawHorizontalBackground(canvas : WMGraphics.Canvas);
		VAR imgLeft, imgMiddle, imgRight, img : WMGraphics.Image;
			 wLeft, wRight : LONGINT;
			 down : BOOLEAN;
		BEGIN
			IF ~enabled.Get() & (imgInactive # NIL) THEN
				img := imgInactive;
				canvas.ScaleImage(	img,
				 	WMRectangles.MakeRect(0, 0, img.width, img.height),
					WMRectangles.MakeRect(0, 0, bounds.GetWidth(), bounds.GetHeight()),
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
			ELSIF imgDefault # NIL THEN
				down := pressed & (mouseOver OR isToggle.Get() OR keyboardPressed);
				IF down & (imgPressed # NIL) THEN
					img := imgPressed
				ELSIF mouseOver & (imgHover # NIL) THEN
					img := imgHover
				ELSE
					img := imgDefault
				END;
				canvas.ScaleImage(	img,
				 	WMRectangles.MakeRect(0, 0, img.width, img.height),
					WMRectangles.MakeRect(0, 0, bounds.GetWidth(), bounds.GetHeight()),
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
			ELSE
				GetHorizontalImages(imgLeft, imgMiddle, imgRight);
		 		(* left *)
		 		IF imgLeft # NIL THEN
					wLeft := imgLeft.width;
					canvas.ScaleImage(	imgLeft,
					 	WMRectangles.MakeRect(0, 0, imgLeft.width, imgLeft.height),
						WMRectangles.MakeRect(0, 0, imgLeft.width, bounds.GetHeight()),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
				ELSE
					wLeft := 0
				END;
				canvas.Line(wLeft, bounds.GetTop(), wLeft, bounds.GetBottom(), LONGINT(0FF0000FFH), WMGraphics.ModeSrcOverDst);

				(* right *)
				IF imgRight # NIL THEN
					wRight := imgRight.width;
					canvas.ScaleImage(	imgRight,
					 	WMRectangles.MakeRect(0, 0, imgRight.width, imgRight.height),
						WMRectangles.MakeRect(bounds.GetWidth()-wRight, 0, bounds.GetWidth(), bounds.GetHeight()),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
				ELSE
					wRight := 0
				END;
				(* middle *)
				IF imgMiddle # NIL THEN
					IF SELF.repeatMiddleImg.Get() THEN (* repeat image *)
						WMGraphicUtilities.RepeatImageHorizontal(canvas, wLeft , 0, bounds.GetWidth()-wLeft-wRight, bounds.GetHeight(), imgMiddle)
					ELSE (* scale image *)
						canvas.ScaleImage(	imgMiddle,
								 	WMRectangles.MakeRect(0, 0, imgMiddle.width, imgMiddle.height),
									WMRectangles.MakeRect(wLeft, 0, bounds.GetWidth()-wRight, bounds.GetHeight()), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
					END
				END
			END
		END DrawHorizontalBackground;

		PROCEDURE DrawVerticalBackground(canvas : WMGraphics.Canvas);
		VAR imgMiddle, imgTop, imgBottom : WMGraphics.Image;
			 hTop, hBottom : LONGINT;
		BEGIN
			GetVerticalImages(imgTop, imgMiddle, imgBottom);
	 		(* top*)
			IF imgTop # NIL THEN
				hTop := imgTop.height;
				canvas.ScaleImage(	imgTop,
				 	WMRectangles.MakeRect(0, 0, imgTop.width, imgTop.height),
					WMRectangles.MakeRect(0, 0, bounds.GetWidth(), imgTop.height),
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
			ELSE
				hTop := 0
			END;
			(* bottom*)
			IF imgBottom # NIL THEN
				hBottom := imgBottom.height;
				canvas.ScaleImage(	imgBottom,
				 	WMRectangles.MakeRect(0, 0, imgBottom.width, imgBottom.height),
					WMRectangles.MakeRect(0, bounds.GetHeight()-hBottom, bounds.GetWidth(), bounds.GetHeight()),
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
			ELSE
				hBottom := 0
			END;
			(* middle *)
			IF imgMiddle # NIL THEN
				IF SELF.repeatMiddleImg.Get() THEN (* repeat image *)
					WMGraphicUtilities.RepeatImageVertical(canvas, 0, hTop, bounds.GetWidth(), bounds.GetHeight()-hTop-hBottom, imgMiddle)
				ELSE (* scale image *)
					canvas.ScaleImage(	imgMiddle,
							 	WMRectangles.MakeRect(0, 0, imgMiddle.width, imgMiddle.height),
								WMRectangles.MakeRect(0, hTop, bounds.GetWidth(), bounds.GetHeight()-hBottom), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear)
				END
			END
		END DrawVerticalBackground;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; VAR keyCode : LONGINT);
		BEGIN
			IF ~ (Inputs.Release IN flags) THEN
				IF keyCode = 20H THEN keyboardPressed := TRUE; Down
				(*	pressed := TRUE; keyboardPressed := TRUE; Invalidate *)
				ELSE keyboardPressed := FALSE; Invalidate (* abort *)
				END
			ELSE
				IF pressed THEN
					 Up; keyboardPressed := FALSE
				END
			END
		END KeyEvent;

		PROCEDURE Click*(sender, par : ANY); (** Eventhandler *)
		VAR event : WMComponents.PointerEvent; command : Strings.String;
		BEGIN
			(* synchronize if not synchronized *)
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Click, sender, par)
			ELSE
				(* actual business logic *)
				onClick.Call(par);
				ExecuteClickHandler;
			END;
			command := GetAttributeValue("command");
			IF command # NIL THEN WMComponents.HandleEvent(event, SELF, command) END;

		END Click;

	END Button;

CONST
	None = -1;
	MinusButton = 0;
	MinusPage = 1;
	Tracker = 2;
	PlusPage = 3;
	PlusButton = 4;


TYPE
	Area = RECORD
		rect : WMRectangles.Rectangle;
	END;

	(** Scrollbar *)
	Scrollbar* = OBJECT (WMComponents.VisualComponent)
	VAR
		min-, max-, pos-, pageSize-, width- : WMProperties.Int32Property;

		vertical- : WMProperties.BooleanProperty;
		minTrackerSize- : WMProperties.Int32Property;

		clDefault-, clHover-, clPressed- : WMProperties.ColorProperty;
		clBtnDefault-, clBtnHover-, clBtnPressed- : WMProperties.ColorProperty;

		effect3D- : WMProperties.Int32Property;

		(* background *)
		useBgBitmaps-, repeatBgBitmap- : WMProperties.BooleanProperty;
		hBgDefaultName-, hBgHoverName-, hBgPressedName-,
		vBgDefaultName-, vBgHoverName-, vBgPressedName- : WMProperties.StringProperty;

		hBgDefault, hBgHover, hBgPressed,
		vBgDefault, vBgHover, vBgPressed : WMGraphics.Image;

		(* tracker images *)
		useTrackerImages-, repeatMiddleBitmap- : WMProperties.BooleanProperty;
		(* horizontal thumb *)
		hTrackerDefaultNameLeft-, hTrackerHoverNameLeft-, hTrackerPressedNameLeft-,
		hTrackerDefaultNameMiddle-, hTrackerHoverNameMiddle-, hTrackerPressedNameMiddle-,
		hTrackerDefaultNameRight-, hTrackerHoverNameRight-, hTrackerPressedNameRight- : WMProperties.StringProperty;

		hTrackerDefaultLeft, hTrackerHoverLeft, hTrackerPressedLeft,
		hTrackerDefaultMiddle, hTrackerHoverMiddle, hTrackerPressedMiddle,
		hTrackerDefaultRight, hTrackerHoverRight, hTrackerPressedRight : WMGraphics.Image;

		(* vertical thumb *)
		vTrackerDefaultNameTop-, vTrackerHoverNameTop-, vTrackerPressedNameTop-,
		vTrackerDefaultNameMiddle-, vTrackerHoverNameMiddle-, vTrackerPressedNameMiddle-,
		vTrackerDefaultNameBottom-, vTrackerHoverNameBottom-, vTrackerPressedNameBottom- : WMProperties.StringProperty;

		vTrackerDefaultTop, vTrackerHoverTop, vTrackerPressedTop,
		vTrackerDefaultMiddle, vTrackerHoverMiddle, vTrackerPressedMiddle,
		vTrackerDefaultBottom, vTrackerHoverBottom, vTrackerPressedBottom : WMGraphics.Image;

		(* arrow images *)
		useArrowImages : WMProperties.BooleanProperty;
		arrowLeftDefaultName-, arrowLeftHoverName-, arrowLeftPressedName-,
		arrowUpDefaultName-, arrowUpHoverName-, arrowUpPressedName-,
		arrowRightDefaultName-, arrowRightHoverName-, arrowRightPressedName-,
		arrowDownDefaultName-, arrowDownHoverName-, arrowDownPressedName- : WMProperties.StringProperty;

		arrowLeftDefault, arrowLeftHover, arrowLeftPressed,
		arrowUpDefault, arrowUpHover, arrowUpPressed,
		arrowRightDefault, arrowRightHover, arrowRightPressed,
		arrowDownDefault, arrowDownHover, arrowDownPressed : WMGraphics.Image;

		onPositionChanged- : EventSource;

		(* bounds and state of logical subcomponents *)
		areas : ARRAY 5 OF Area;

		down, pressed, hover : SHORTINT;

		timer : InternalTimer;

		ts, tp, tDownX, tDownY : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenScrollbar");
			SetNameAsString(StrScrollbar);
			NEW(min, PrototypeSmin, NIL, NIL); properties.Add(min);
			NEW(max, PrototypeSmax,  NIL, NIL); properties.Add(max);
			NEW(pos, PrototypeSpos, NIL, NIL); properties.Add(pos);
			NEW(pageSize, PrototypeSpageSize, NIL, NIL); properties.Add(pageSize);
			NEW(vertical, PrototypeSvertical, NIL, NIL); properties.Add(vertical);
			pos.SetBounds(min.Get(), max.Get());
			NEW(width, PrototypeSWidth, NIL, NIL);
			NEW(minTrackerSize, PrototypeSMinTrackerSize, NIL, NIL); properties.Add(minTrackerSize);
			NEW(effect3D, PrototypeSEffect3D, NIL, NIL); properties.Add(effect3D);

			(* simple representation *)
			NEW(clDefault, PrototypeSClDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clHover, PrototypeSClHover, NIL, NIL); properties.Add(clHover);
			NEW(clPressed, PrototypeSClPressed, NIL, NIL); properties.Add(clPressed);
			NEW(clBtnDefault, PrototypeSClBtnDefault, NIL, NIL); properties.Add(clBtnDefault);
			NEW(clBtnHover, PrototypeSClBtnHover, NIL, NIL); properties.Add(clBtnHover);
			NEW(clBtnPressed, PrototypeSClBtnPressed, NIL, NIL); properties.Add(clBtnPressed);

		(* --- background of scrollbar --- *)

			NEW(useBgBitmaps, PrototypeSUseBgBitmaps, NIL, NIL); properties.Add(useBgBitmaps);
			NEW(repeatBgBitmap, PrototypeSRepeateBgBitmap, NIL, NIL); properties.Add(repeatBgBitmap);

			(* bitmap representation *)
			NEW(hBgDefaultName, PrototypeShBgDefault, NIL, NIL); properties.Add(hBgDefaultName);
			NEW(hBgHoverName, PrototypeShBgHover, NIL, NIL); properties.Add(hBgHoverName);
			NEW(hBgPressedName, PrototypeShBgPressed, NIL, NIL); properties.Add(hBgPressedName);
			NEW(vBgDefaultName, PrototypeSvBgDefault, NIL, NIL); properties.Add(vBgDefaultName);
			NEW(vBgHoverName, PrototypeSvBgHover, NIL, NIL); properties.Add(vBgHoverName);
			NEW(vBgPressedName, PrototypeSvBgPressed, NIL, NIL); properties.Add(vBgPressedName);

		(* --- tracker --- *)

			NEW(useTrackerImages, PrototypeSUseTrackerImages, NIL, NIL); properties.Add(useTrackerImages);
			NEW(repeatMiddleBitmap, PrototypeSRepeatMiddleBitmap, NIL, NIL); properties.Add(repeatMiddleBitmap);

			(* horizontal decoration bitmaps *)
			NEW(hTrackerDefaultNameLeft, PrototypeShTrackerDefaultLeft, NIL, NIL); properties.Add(hTrackerDefaultNameLeft);
			NEW(hTrackerHoverNameLeft, PrototypeShTrackerHoverLeft, NIL, NIL); properties.Add(hTrackerHoverNameLeft);
			NEW(hTrackerPressedNameLeft, PrototypeShTrackerPressedLeft, NIL, NIL); properties.Add(hTrackerPressedNameLeft);
			NEW(hTrackerDefaultNameMiddle, PrototypeShTrackerDefaultMiddle, NIL, NIL); properties.Add(hTrackerDefaultNameMiddle);
			NEW(hTrackerHoverNameMiddle, PrototypeShTrackerHoverMiddle, NIL, NIL); properties.Add(hTrackerHoverNameMiddle);
			NEW(hTrackerPressedNameMiddle, PrototypeShTrackerPressedMiddle, NIL, NIL); properties.Add(hTrackerPressedNameMiddle);
			NEW(hTrackerDefaultNameRight, PrototypeShTrackerDefaultRight, NIL, NIL); properties.Add(hTrackerDefaultNameRight);
			NEW(hTrackerHoverNameRight, PrototypeShTrackerHoverRight, NIL, NIL); properties.Add(hTrackerHoverNameRight);
			NEW(hTrackerPressedNameRight, PrototypeShTrackerPressedRight, NIL, NIL); properties.Add(hTrackerPressedNameRight);

			(* vertical decoration bitmaps *)
			NEW(vTrackerDefaultNameTop, PrototypeSvTrackerDefaultTop, NIL, NIL); properties.Add(vTrackerDefaultNameTop);
			NEW(vTrackerHoverNameTop, PrototypeSvTrackerHoverTop, NIL, NIL); properties.Add(vTrackerHoverNameTop);
			NEW(vTrackerPressedNameTop, PrototypeSvTrackerPressedTop, NIL, NIL); properties.Add(vTrackerPressedNameTop);
			NEW(vTrackerDefaultNameMiddle, PrototypeSvTrackerDefaultMiddle, NIL, NIL); properties.Add(vTrackerDefaultNameMiddle);
			NEW(vTrackerHoverNameMiddle, PrototypeSvTrackerHoverMiddle, NIL, NIL); properties.Add(vTrackerHoverNameMiddle);
			NEW(vTrackerPressedNameMiddle, PrototypeSvTrackerPressedMiddle, NIL, NIL); properties.Add(vTrackerPressedNameMiddle);
			NEW(vTrackerDefaultNameBottom, PrototypeSvTrackerDefaultBottom, NIL, NIL); properties.Add(vTrackerDefaultNameBottom);
			NEW(vTrackerHoverNameBottom, PrototypeSvTrackerHoverBottom, NIL, NIL); properties.Add(vTrackerHoverNameBottom);
			NEW(vTrackerPressedNameBottom, PrototypeSvTrackerPressedBottom, NIL, NIL); properties.Add(vTrackerPressedNameBottom);

			NEW(onPositionChanged, SELF, GSonPositionChanged, GSonPositionChangedInfo, SELF.StringToCompCommand);
			events.Add(onPositionChanged);

			(* --- arrow buttons --- *)

			NEW(useArrowImages, PrototypeSUseArrowImages, NIL, NIL); properties.Add(useArrowImages);

			(* left *)
			NEW(arrowLeftDefaultName, PrototypeSArrowLeftDefault, NIL, NIL); properties.Add(arrowLeftDefaultName);
			NEW(arrowLeftHoverName, PrototypeSArrowLeftHover, NIL, NIL); properties.Add(arrowLeftHoverName);
			NEW(arrowLeftPressedName, PrototypeSArrowLeftPressed, NIL, NIL); properties.Add(arrowLeftPressedName);

			(* right *)
			NEW(arrowRightDefaultName, PrototypeSArrowRightDefault, NIL, NIL); properties.Add(arrowRightDefaultName);
			NEW(arrowRightHoverName, PrototypeSArrowRightHover, NIL, NIL); properties.Add(arrowRightHoverName);
			NEW(arrowRightPressedName, PrototypeSArrowRightPressed, NIL, NIL); properties.Add(arrowRightPressedName);

			(* up *)
			NEW(arrowUpDefaultName, PrototypeSArrowUpDefault, NIL, NIL); properties.Add(arrowUpDefaultName);
			NEW(arrowUpHoverName, PrototypeSArrowUpHover, NIL, NIL); properties.Add(arrowUpHoverName);
			NEW(arrowUpPressedName, PrototypeSArrowUpPressed, NIL, NIL); properties.Add(arrowUpPressedName);

			(* down *)
			NEW(arrowDownDefaultName, PrototypeSArrowDownDefault, NIL, NIL); properties.Add(arrowDownDefaultName);
			NEW(arrowDownHoverName, PrototypeSArrowDownHover, NIL, NIL); properties.Add(arrowDownHoverName);
			NEW(arrowDownPressedName, PrototypeSArrowDownPressed, NIL, NIL); properties.Add(arrowDownPressedName);

			down := None; pressed := None; hover := None;

			timer := NIL;

			bounds.SetExtents(SELF.width.Get(), SELF.width.Get());
			takesFocus.Set(FALSE);
			RecacheImages;
		END Init;

		PROCEDURE Resized;
		BEGIN
			Resized^;
			UpdateLayout;
			Invalidate;
		END Resized;

		PROCEDURE LinkChanged(sender, data : ANY);
		VAR integer : Types.Integer; res : LONGINT; m: Models.Model;
		BEGIN
			IF (sender = model) & WMProperties.GetModel(model,m) THEN
				m.GetGeneric(integer, res);
				IF (res = Models.Ok) & (pos.Get() # integer.value) THEN
					pos.Set(integer.value);
				END;
			END;
		END LinkChanged;

		PROCEDURE ChangeModel(value : LONGINT);
		VAR integer : Types.Integer; res : LONGINT; m: Models.Model;
		BEGIN
			IF WMProperties.GetModel(model, m) THEN
				integer.value := value;
				m.SetGeneric(integer, res);
			END;
		END ChangeModel;

		PROCEDURE TimerCallback(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.TimerCallback, sender, data);
			ELSE
				Down(pressed);
			END;
		END TimerCallback;

		PROCEDURE CheckRepeating(start : BOOLEAN);
		BEGIN
			IF start THEN
				IF (timer = NIL) THEN NEW(timer, TimerCallback); END;
				timer.Start;
			ELSE
				IF (timer # NIL) THEN
					timer.Finalize; timer := NIL;
				END;
			END;
		END CheckRepeating;

		PROCEDURE Down(area : SHORTINT);
		BEGIN
			IF (area = MinusButton) THEN DecPos(NIL, NIL);
			ELSIF (area = MinusPage) THEN PageUp(NIL, NIL);
			ELSIF (area = PlusPage) THEN PageDown(NIL, NIL);
			ELSIF (area = PlusButton) THEN IncPos(NIL, NIL);
			END;
		END Down;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			PointerDown^(x, y, keys);
			IF (0 IN keys) THEN
				down := FindArea(x, y);
				IF (down # None) THEN
					Down(down);
					CheckRepeating(TRUE);
					pressed := down;
					InvalidateRect(areas[pressed].rect);
				END;
				tDownX := x - tp ; tDownY := y - tp;
			ELSIF (1 IN keys) THEN
				TrackerMove(x, y, keys);
				pressed := Tracker;
				down := pressed;
				InvalidateRect(areas[pressed].rect); 
			END;
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR oldHover, oldPressed, area : SHORTINT;
		BEGIN
			PointerMove^(x, y, keys);
			area := FindArea(x, y);
			IF (down = None) THEN
				IF (hover # area) THEN
					oldHover := hover;
					hover := area;
					IF (oldHover # None) THEN InvalidateRect(areas[oldHover].rect); END;
					IF (hover # None) THEN InvalidateRect(areas[hover].rect); END;
				END;
			ELSE
				IF (hover # None) THEN oldHover := hover; hover := None; InvalidateRect(areas[oldHover].rect); END;
				IF (down # Tracker) THEN
					IF (area = None) OR (area # down) THEN
						IF (pressed # None) THEN oldPressed := pressed; pressed := None; InvalidateRect(areas[oldPressed].rect); END;
					ELSIF (area = down) THEN
						pressed := down; InvalidateRect(areas[pressed].rect);
					END;
				ELSE
					TrackerMove(x, y, keys);
				END;
			END;
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR oldPressed : SHORTINT;
		BEGIN
			PointerUp^(x, y, keys);
			IF ~(0 IN keys) THEN
				down := None;
				IF (pressed # None) THEN
					CheckRepeating(FALSE);
					oldPressed := pressed;
					pressed := None;
					InvalidateRect(areas[oldPressed].rect);
				END;
			END;
		END PointerUp;

		PROCEDURE PointerLeave;
		VAR oldHover : SHORTINT;
		BEGIN
			PointerLeave^;
			IF (hover # None) THEN
				oldHover := hover;
				hover := None;
				InvalidateRect(areas[oldHover].rect);
			END;
		END PointerLeave;

		PROCEDURE FindArea(x, y : LONGINT) : SHORTINT;
		VAR result : SHORTINT;
		BEGIN
			result := 0;
			WHILE (result < LEN(areas)) & ~WMRectangles.PointInRect(x, y, areas[result].rect) DO INC(result); END;
			IF (result >= LEN(areas)) THEN result := None; END;
			RETURN result;
		END FindArea;

		PROCEDURE TrackerMove(x, y : LONGINT; keys : SET);
		VAR newPosition, value, d, dy, dp, dx : LONGINT; f : REAL; tmax, tmin, a, b : LONGINT;
		BEGIN
			tmin := min.Get(); tmax := max.Get();
			IF 1 IN keys  THEN
				IF vertical.Get() THEN
					a := bounds.GetWidth() + (ts DIV 2);
					b := bounds.GetHeight() - a;
					d := (b - a);
					value := y - a;
				ELSE
					a := bounds.GetHeight() + (ts DIV 2);
					b := bounds.GetWidth() - a;
					d := (b - a);
					value := x - a;
				END;
				IF (d > 0) THEN
					IF (value < 0) THEN value := 0; ELSIF (value > b) THEN value := b; END;
					f := tmax - tmin;
					f := f * (value / d); newPosition := ENTIER(f);
					IF (pos.Get() # newPosition) THEN pos.Set(newPosition); onPositionChanged.Call(pos); END;
				END;
			ELSIF 0 IN keys THEN
				IF vertical.Get() THEN
					d := (bounds.GetHeight() - 2 * bounds.GetWidth());
					IF d > 0 THEN
						dy := (y - tp) - tDownY;
						f := tmax - tmin; f := f * dy / d; dp := ENTIER(f);
					ELSE
						dp := 0;
					END;
				ELSE
					d := (bounds.GetWidth() - 2 * bounds.GetHeight());
					IF d > 0 THEN
						dx := (x - tp) - tDownX;
						f := tmax - tmin; f := f * dx / d; dp := ENTIER(f);
					ELSE
						dp := 0;
					END;
				END;
				IF dp # 0 THEN pos.Set(pos.Get() + dp); onPositionChanged.Call(pos); END;
			END;
		END TrackerMove;

		PROCEDURE RecacheImages;

			PROCEDURE GetImage(string : WMProperties.StringProperty) : WMGraphics.Image;
			VAR s : Strings.String; image : WMGraphics.Image;
			BEGIN
				s := string.Get(); IF (s # NIL) THEN image := WMGraphics.LoadImage(s^, TRUE); ELSE image := NIL; END;
				RETURN image;
			END GetImage;

		BEGIN
			hBgDefault := GetImage(hBgDefaultName); hBgHover := GetImage(hBgHoverName); hBgPressed := GetImage(hBgPressedName);
			vBgDefault := GetImage(vBgDefaultName); vBgHover := GetImage(vBgHoverName); vBgPressed := GetImage(vBgPressedName);
			hTrackerDefaultLeft := GetImage(hTrackerDefaultNameLeft);
			hTrackerHoverLeft := GetImage(hTrackerHoverNameLeft);
			hTrackerPressedLeft := GetImage(hTrackerPressedNameLeft);
			hTrackerDefaultMiddle := GetImage(hTrackerDefaultNameMiddle);
			hTrackerHoverMiddle := GetImage(hTrackerHoverNameMiddle);
			hTrackerPressedMiddle := GetImage(hTrackerPressedNameMiddle);
			hTrackerDefaultRight := GetImage(hTrackerDefaultNameRight);
			hTrackerHoverRight := GetImage(hTrackerHoverNameRight);
			hTrackerPressedRight := GetImage(hTrackerPressedNameRight);
			vTrackerDefaultTop := GetImage(vTrackerDefaultNameTop);
			vTrackerHoverTop := GetImage(vTrackerHoverNameTop);
			vTrackerPressedTop := GetImage(vTrackerPressedNameTop);
			vTrackerDefaultMiddle := GetImage(vTrackerDefaultNameMiddle);
			vTrackerHoverMiddle := GetImage(vTrackerHoverNameMiddle);
			vTrackerPressedMiddle := GetImage(vTrackerPressedNameMiddle);
			vTrackerDefaultBottom := GetImage(vTrackerDefaultNameBottom);
			vTrackerHoverBottom := GetImage(vTrackerHoverNameBottom);
			vTrackerPressedBottom := GetImage(vTrackerPressedNameBottom);
			arrowLeftDefault := GetImage(arrowLeftDefaultName);
			arrowLeftHover := GetImage(arrowLeftHoverName);
			arrowLeftPressed := GetImage(arrowLeftPressedName);
			arrowUpDefault := GetImage(arrowUpDefaultName);
			arrowUpHover := GetImage(arrowUpHoverName);
			arrowUpPressed := GetImage(arrowUpPressedName);
			arrowRightDefault := GetImage(arrowRightDefaultName);
			arrowRightHover := GetImage(arrowRightHoverName);
			arrowRightPressed := GetImage(arrowRightPressedName);
			arrowDownDefault := GetImage(arrowDownDefaultName);
			arrowDownHover := GetImage(arrowDownHoverName);
			arrowDownPressed := GetImage( arrowDownPressedName);
		END RecacheImages;

		PROCEDURE RecacheProperties;
		VAR element : XML.Element;
		BEGIN
			RecacheProperties^;
			RecacheImages;
			pos.SetBounds(min.Get(), max.Get());
			IF SELF.vertical.Get() THEN
				bounds.SetWidth(SELF.width.Get())
			ELSE
				bounds.SetHeight(SELF.width.Get())
			END;
			Resized; (*?implies Invalidate -> redundant*)
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = pos) THEN
				UpdateLayout; ChangeModel(pos.Get()); Invalidate;
			ELSIF (property = model) THEN Invalidate;
			ELSIF (property = vertical) THEN
				IF SELF.vertical.Get() THEN
					bounds.SetWidth(SELF.width.Get())
				ELSE
					bounds.SetHeight(SELF.width.Get())
				END;
				Resized;  (*implies Invalidate*)
			ELSIF (property = minTrackerSize) THEN UpdateLayout; Invalidate;
			ELSIF (property = min) OR (property = max) OR (property = pageSize) THEN
				pos.SetBounds(min.Get(), max.Get());
				UpdateLayout;
				Invalidate;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DecPos*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.DecPos, sender, par);
			ELSE pos.Set(pos.Get() - 1); onPositionChanged.Call(pos);
			END;
		END DecPos;

		PROCEDURE IncPos*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.IncPos, sender, par);
			ELSE pos.Set(pos.Get() + 1); onPositionChanged.Call(pos);
			END;
		END IncPos;

		PROCEDURE PageUp*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PageUp, sender, par);
			ELSE pos.Set(pos.Get() - pageSize.Get()); onPositionChanged.Call(pos);
			END;
		END PageUp;

		PROCEDURE PageDown*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PageDown, sender, par);
			ELSE pos.Set(pos.Get() + pageSize.Get()); onPositionChanged.Call(pos);
			END;
		END PageDown;

		PROCEDURE UpdateLayout;
		VAR h, w, ps, tmin, tmax : LONGINT; f : REAL; width, height : LONGINT;
		BEGIN
			width := bounds.GetWidth(); height := bounds.GetHeight();
			tmin := min.Get(); tmax := max.Get();
			ps := Strings.Min(tmax - tmin, pageSize.Get());
			IF vertical.Get() THEN
				IF tmax > tmin THEN
					h := (height - 2 * width);
					f := ps / (tmax - tmin);
					ts := Strings.Min(h, Strings.Max(ENTIER(f * h), SELF.minTrackerSize.Get()));
					tp := (pos.Get() - tmin) * (h - ts) DIV (tmax - tmin);
				ELSE
					ts := (height - 2 * width); tp := 0;
				END;
				areas[MinusButton].rect := WMRectangles.MakeRect(0, 0, width, width);
				areas[MinusPage].rect := WMRectangles.MakeRect(0, width, width, width + tp);
				areas[Tracker].rect := WMRectangles.MakeRect(0, width + tp, width, width + tp + ts);
				areas[PlusPage].rect := WMRectangles.MakeRect(0, width + tp + ts, width, width + h);
				areas[PlusButton].rect := WMRectangles.MakeRect(0, height - width, width, height);
			ELSE
				IF tmax > tmin THEN
					w := (width - 2 * height);
					f := ps / (tmax - tmin);
					ts := Strings.Min(w, Strings.Max(ENTIER(f * w), SELF.minTrackerSize.Get()));
					tp := (pos.Get() - tmin) * (w - ts) DIV (tmax - tmin);
				ELSE
					ts := (width - 2 * height); tp := 0;
				END;
				areas[MinusButton].rect := WMRectangles.MakeRect(0, 0, height, height);
				areas[MinusPage].rect := WMRectangles.MakeRect(height, 0, height + tp, height);
				areas[Tracker].rect := WMRectangles.MakeRect(height + tp, 0, height + tp + ts, height);
				areas[PlusPage].rect := WMRectangles.MakeRect(height + tp + ts, 0, width - height, height);
				areas[PlusButton].rect := WMRectangles.MakeRect(width - height, 0, width, height);
			END;
		END UpdateLayout;

		PROCEDURE GetButtonColor(area : SHORTINT) : LONGINT;
		VAR color : LONGINT;
		BEGIN
			IF (area = pressed) THEN color := clBtnPressed.Get();
			ELSIF (area = hover) THEN color := clBtnHover.Get();
			ELSE color := clBtnDefault.Get();
			END;
			RETURN color;
		END GetButtonColor;

		PROCEDURE GetPageColor(area : SHORTINT) : LONGINT;
		VAR color : LONGINT;
		BEGIN
			IF (area = pressed) THEN color := clPressed.Get();
			ELSIF (area = hover) THEN color := clHover.Get();
			ELSE color := clDefault.Get();
			END;
			RETURN color;
		END GetPageColor;

		PROCEDURE GetMinusButtonImage(vertical : BOOLEAN; area : SHORTINT; VAR image : WMGraphics.Image);
		BEGIN
			IF vertical THEN
				IF (area = pressed) THEN image := arrowUpPressed;
				ELSIF (area = hover) THEN image := arrowUpHover;
				ELSE image := arrowUpDefault;
				END;
			ELSE
				IF (area = pressed) THEN image := arrowLeftPressed;
				ELSIF (area = hover) THEN image := arrowLeftHover;
				ELSE image := arrowLeftDefault;
				END;
			END;
		END GetMinusButtonImage;

		PROCEDURE GetPlusButtonImage(vertical : BOOLEAN; area : SHORTINT; VAR image : WMGraphics.Image);
		BEGIN
			IF vertical THEN
				IF (area = pressed) THEN image := arrowDownPressed;
				ELSIF (area = hover) THEN image := arrowDownHover;
				ELSE image := arrowDownDefault;
				END;
			ELSE
				IF (area = pressed) THEN image := arrowRightPressed;
				ELSIF (area = hover) THEN image := arrowRightHover;
				ELSE image := arrowRightDefault;
				END;
			END;
		END GetPlusButtonImage;

		PROCEDURE GetTrackerImages( vertical : BOOLEAN; area : SHORTINT; VAR a, b, c : WMGraphics.Image);
		BEGIN
			IF vertical THEN
				IF (area = pressed) THEN a := vTrackerPressedTop; b := vTrackerPressedMiddle; c := vTrackerPressedBottom;
				ELSIF (area = hover) THEN a := vTrackerHoverTop; b := vTrackerHoverMiddle; c := vTrackerHoverBottom;
				ELSE a := vTrackerDefaultTop; b := vTrackerDefaultMiddle; c := vTrackerDefaultBottom;
				END;
			ELSE
				IF (area = pressed) THEN a := hTrackerPressedLeft; b := hTrackerPressedMiddle; c := hTrackerPressedRight;
				ELSIF (area = hover) THEN a := hTrackerHoverLeft; b := hTrackerHoverMiddle; c := hTrackerHoverRight;
				ELSE a := hTrackerDefaultLeft; b := hTrackerDefaultMiddle; c := hTrackerDefaultRight;
				END;
			END;
		END GetTrackerImages;

		PROCEDURE GetBgImage(vertical : BOOLEAN; area : SHORTINT;  VAR image : WMGraphics.Image);
		BEGIN
			IF vertical THEN
				IF (area = pressed) THEN image := vBgPressed;
				ELSIF (area = hover) THEN image := vBgHover;
				ELSE image := vBgDefault;
				END;
			ELSE
				IF (area = pressed) THEN image := hBgPressed;
				ELSIF (area = hover) THEN image := hBgHover;
				ELSE image := hBgDefault;
				END;
			END;
		END GetBgImage;

		PROCEDURE DrawHorizontalBackground(canvas : WMGraphics.Canvas; rect : WMRectangles.Rectangle;  image, imgLeft, imgMiddle, imgRight : WMGraphics.Image);
		VAR  wLeft, wRight : LONGINT;
		BEGIN
			IF image # NIL THEN
				canvas.ScaleImage(image,
				 	WMRectangles.MakeRect(0, 0, image.width, image.height), rect,
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
			ELSE
		 		IF imgLeft # NIL THEN
					wLeft := imgLeft.width;
					canvas.ScaleImage(	imgLeft,
					 	WMRectangles.MakeRect(0, 0, imgLeft.width, imgLeft.height),
						WMRectangles.MakeRect(rect.l, rect.t, rect.l + imgLeft.width, rect.b),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				ELSE
					wLeft := 0;
				END;
				IF imgRight # NIL THEN
					wRight := imgRight.width;
					canvas.ScaleImage(	imgRight,
					 	WMRectangles.MakeRect(0, 0, imgRight.width, imgRight.height),
						WMRectangles.MakeRect(rect.r - wRight, rect.t, rect.r, rect.b),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				ELSE
					wRight := 0;
				END;
				IF imgMiddle # NIL THEN
					IF SELF.repeatMiddleBitmap.Get() THEN
						WMGraphicUtilities.RepeatImageHorizontal(canvas, rect.l + wLeft , rect.t, (rect.r - rect.l) - wLeft - wRight, rect.b, imgMiddle);
					ELSE
						canvas.ScaleImage(imgMiddle,
							WMRectangles.MakeRect(0, 0, imgMiddle.width, imgMiddle.height),
							WMRectangles.MakeRect(rect.l + wLeft, rect.t, rect.r - wRight, rect.b), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
					END;
				END;
			END;
		END DrawHorizontalBackground;

		PROCEDURE DrawVerticalBackground(canvas : WMGraphics.Canvas; rect : WMRectangles.Rectangle; image, imgTop, imgMiddle, imgBottom : WMGraphics.Image);
		VAR hTop, hBottom : LONGINT;
		BEGIN
			IF image # NIL THEN
				canvas.ScaleImage(image,
				 	WMRectangles.MakeRect(0, 0, image.width, image.height), rect,
					WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
			ELSE
				IF imgTop # NIL THEN
					hTop := imgTop.height;
					canvas.ScaleImage(	imgTop,
					 	WMRectangles.MakeRect(0, 0, imgTop.width, imgTop.height),
						WMRectangles.MakeRect(rect.l, rect.t, rect.r, rect.t + imgTop.height),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				ELSE
					hTop := 0;
				END;
				IF imgBottom # NIL THEN
					hBottom := imgBottom.height;
					canvas.ScaleImage(	imgBottom,
					 	WMRectangles.MakeRect(0, 0, imgBottom.width, imgBottom.height),
						WMRectangles.MakeRect(rect.l, rect.b - hBottom, rect.r, rect.b),
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				ELSE
					hBottom := 0;
				END;
				IF imgMiddle # NIL THEN
					IF SELF.repeatMiddleBitmap.Get() THEN (* repeat image *)
						WMGraphicUtilities.RepeatImageVertical(canvas, rect.l, rect.t + hTop, rect.r, (rect.b - rect.t) - hTop - hBottom, imgMiddle);
					ELSE (* scale image *)
						canvas.ScaleImage(	imgMiddle,
								 	WMRectangles.MakeRect(0, 0, imgMiddle.width, imgMiddle.height),
									WMRectangles.MakeRect(rect.l, rect.t + hTop, rect.r, rect.b-hBottom), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
					END;
				END;
			END;
		END DrawVerticalBackground;

		PROCEDURE DrawSimpleRepresentation(canvas : WMGraphics.Canvas; area : LONGINT; rect : WMRectangles.Rectangle; color , effect3D : LONGINT);
		BEGIN
			IF (color # 0) THEN canvas.Fill(rect, color, WMGraphics.ModeSrcOverDst) END;
			IF (effect3D > 0) THEN WMGraphicUtilities.RectGlassShade(canvas, rect, effect3D, area = pressed) END
		END DrawSimpleRepresentation;

		PROCEDURE DrawImage(canvas : WMGraphics.Canvas; rect : WMRectangles.Rectangle; image : WMGraphics.Image; repeat, vertical : BOOLEAN);
		BEGIN
			IF (image # NIL) THEN
				IF repeat THEN
					IF vertical THEN
						WMGraphicUtilities.RepeatImageVertical(canvas, rect.l, rect.t, rect.r, rect.b, image);
					ELSE
						WMGraphicUtilities.RepeatImageHorizontal(canvas, rect.l, rect.t, rect.r, rect.b, image);
					END;
				ELSE
					canvas.ScaleImage(image,
					 	WMRectangles.MakeRect(0, 0, image.width, image.height), rect,
						WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
				END;
			END;
		END DrawImage;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR image, a, b, c : WMGraphics.Image; vertical : BOOLEAN;
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			vertical := SELF.vertical.Get();
			IF useBgBitmaps.Get() THEN
				GetBgImage(vertical, MinusPage, image);
				DrawImage(canvas, areas[MinusPage].rect, image, repeatBgBitmap.Get(), vertical);
				GetBgImage(vertical, PlusPage, image);
				DrawImage(canvas, areas[PlusPage].rect, image, repeatBgBitmap.Get(), vertical);
			ELSE
				DrawSimpleRepresentation(canvas, MinusPage, areas[MinusPage].rect, GetPageColor(MinusPage), 0);
				DrawSimpleRepresentation(canvas, PlusPage, areas[PlusPage].rect, GetPageColor(PlusPage), 0);
			END;
			IF useArrowImages.Get() THEN
				GetMinusButtonImage(vertical, MinusButton, image);
				DrawImage(canvas, areas[MinusButton].rect, image, FALSE, vertical);
				GetPlusButtonImage(vertical, PlusButton, image);
				DrawImage(canvas, areas[PlusButton].rect, image, FALSE, vertical);
			ELSE
				DrawSimpleRepresentation(canvas, MinusButton, areas[MinusButton].rect, GetButtonColor(MinusButton), effect3D.Get());
				DrawSimpleRepresentation(canvas, PlusButton, areas[PlusButton].rect, GetButtonColor(PlusButton), effect3D.Get());
			END;
			IF useTrackerImages.Get() THEN
				GetTrackerImages(vertical, Tracker, a, b, c);
				IF vertical THEN
					DrawVerticalBackground(canvas, areas[Tracker].rect, NIL, a, b, c);
				ELSE
					DrawHorizontalBackground(canvas, areas[Tracker].rect, NIL, a, b, c);
				END;
			ELSE
				DrawSimpleRepresentation(canvas, Tracker, areas[Tracker].rect, GetButtonColor(Tracker), effect3D.Get());
			END;
			Release
		END DrawBackground;

	END Scrollbar;

TYPE

	Slider* = OBJECT (WMComponents.VisualComponent)
	VAR
		min-, max-, pos-, pageSize-, trackerSize- : WMProperties.Int32Property;

		vertical- : WMProperties.BooleanProperty;
		clDefault-, clHover-, clPressed-, clBar : WMProperties.ColorProperty;

		(* background *)
		useBgBitmaps-, repeatBgBitmap- : WMProperties.BooleanProperty;
		hBgDefaultName-, hBgHoverName-, hBgPressedName-,
		vBgDefaultName-, vBgHoverName-, vBgPressedName- : WMProperties.StringProperty;

		useTrackerImages- : WMProperties.BooleanProperty;
		hTrackerDefaultName-, hTrackerHoverName-, hTrackerPressedName-,
		vTrackerDefaultName-, vTrackerHoverName-, vTrackerPressedName- : WMProperties.StringProperty;

		onPositionChanged- : WMEvents.EventSource;

		minusPage, plusPage, tracker : Button;
		ts, tp, lx, ly : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenSlider");
			SetNameAsString(NewString("Slider"));
			NEW(min, PrototypeSmin, NIL, NIL); properties.Add(min);
			NEW(max, PrototypeSmax,  NIL, NIL); properties.Add(max);
			NEW(pos, PrototypeSpos, NIL, NIL); properties.Add(pos);
			NEW(pageSize, PrototypeSpageSize, NIL, NIL); properties.Add(pageSize);
			NEW(trackerSize, PrototypeTrackerSize, NIL, NIL); properties.Add(trackerSize);
			trackerSize.Set(10);
			NEW(vertical, PrototypeSvertical, NIL, NIL); properties.Add(vertical);
			pos.SetBounds(min.Get(), max.Get());

			(* --- tracker --- *)

			(* simple representation *)
			NEW(clDefault, PrototypeSlClDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clHover, PrototypeSlClHover, NIL, NIL); properties.Add(clHover);
			NEW(clPressed, PrototypeSlClPressed, NIL, NIL); properties.Add(clPressed);
			NEW(clBar, PrototypeSlClBar, NIL, NIL); properties.Add(clBar);

			NEW(useTrackerImages, PrototypeSlUseTrackerImages, NIL, NIL); properties.Add(useTrackerImages);

			NEW(tracker); tracker.takesFocus.Set(FALSE);
			tracker.alignment.Set(WMComponents.AlignClient);

			NEW(hTrackerDefaultName, PrototypeSlhTrackerDefault, NIL, NIL); properties.Add(hTrackerDefaultName);
			NEW(hTrackerHoverName, PrototypeSlhTrackerHover, NIL, NIL); properties.Add(hTrackerHoverName);
			NEW(hTrackerPressedName, PrototypeSlhTrackerPressed, NIL, NIL); properties.Add(hTrackerPressedName);

			NEW(vTrackerDefaultName, PrototypeSlvTrackerDefault, NIL, NIL); properties.Add(vTrackerDefaultName);
			NEW(vTrackerHoverName, PrototypeSlvTrackerHover, NIL, NIL); properties.Add(vTrackerHoverName);
			NEW(vTrackerPressedName, PrototypeSlvTrackerPressed, NIL, NIL); properties.Add(vTrackerPressedName);

			(* --- background of scrollbar --- *)

			NEW(useBgBitmaps, PrototypeSlUseBgBitmaps, NIL, NIL); properties.Add(useBgBitmaps);
			NEW(repeatBgBitmap, PrototypeSlRepeatBgBitmap, NIL, NIL); properties.Add(repeatBgBitmap);

			(* bitmap representation *)
			NEW(hBgDefaultName, PrototypeSlhBgDefault, NIL, NIL); properties.Add(hBgDefaultName);
			NEW(hBgHoverName, PrototypelShBgHover, NIL, NIL); properties.Add(hBgHoverName);
			NEW(hBgPressedName, PrototypeSlhBgPressed, NIL, NIL); properties.Add(hBgPressedName);
			NEW(vBgDefaultName, PrototypeSlvBgDefault, NIL, NIL); properties.Add(vBgDefaultName);
			NEW(vBgHoverName, PrototypeSlvBgHover, NIL, NIL); properties.Add(vBgHoverName);
			NEW(vBgPressedName, PrototypeSlvBgPressed, NIL, NIL); properties.Add(vBgPressedName);

			NEW(onPositionChanged, SELF, NIL, NIL, SELF.StringToCompCommand);
			events.Add(onPositionChanged);

			(* minus page *)
			NEW(minusPage); minusPage.takesFocus.Set(FALSE); minusPage.onClick.Add(PageUp); minusPage.isRepeating.Set(TRUE);

			(* simple representation *)
			minusPage.effect3D.Set(0);

			(* plus page *)
			NEW(plusPage); plusPage.takesFocus.Set(FALSE);  plusPage.onClick.Add(PageDown); plusPage.isRepeating.Set(TRUE);

			(* simple representation *)
			plusPage.effect3D.Set(0);

			SetDirection;

			AddInternalComponent(minusPage);
			AddInternalComponent(plusPage);
			AddInternalComponent(tracker);
			tracker.SetExtPointerUpHandler(TrackerPointerUp);
			tracker.SetExtPointerDownHandler(TrackerPointerDown);
			tracker.SetExtPointerMoveHandler(TrackerPointerMove);

			takesFocus.Set(FALSE)
		END Init;

		PROCEDURE LinkChanged(sender, link: ANY);
		VAR m: Models.Model; integer: LONGINT;
		BEGIN
			IF sender = model THEN
				IF WMProperties.GetModel(model,m) THEN
					IF Models.GetInteger(m, integer) THEN
						pos.Set(integer);
					END;
				END;
			ELSE
				LinkChanged^(sender, link)
			END;
		END LinkChanged;


		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		CONST BarWidth = 8;
		VAR rect : WMRectangles.Rectangle; width, height : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			IF ~useBgBitmaps.Get() & (clBar.Get() # 0) THEN
				width := bounds.GetWidth();
				height := bounds.GetHeight();
				IF vertical.Get() THEN
					IF (width > BarWidth) THEN
						rect := WMRectangles.MakeRect((width - BarWidth) DIV 2, 0, width - ((width - BarWidth) DIV 2), height);
					ELSE
						rect := WMRectangles.MakeRect(0, 0, width, height);
					END;
				ELSE
					IF (height > BarWidth) THEN
						rect := WMRectangles.MakeRect(0, (height - BarWidth) DIV 2, width, height - ((height - BarWidth) DIV 2));
					ELSE
						rect := WMRectangles.MakeRect(0, 0, width, height);
					END;
				END;
				rect := WMRectangles.ResizeRect(rect, -1);
				canvas.Fill(rect, clBar.Get(), WMGraphics.ModeSrcOverDst);
				WMGraphicUtilities.RectGlassShade(canvas, rect, 1, TRUE);
			END;
		END DrawBackground;

		PROCEDURE TrackerPointerDown(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			lx := x; ly := y; handled := FALSE
		END TrackerPointerDown;

		PROCEDURE TrackerPointerUp(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			ChangeModel
		END TrackerPointerUp;

		PROCEDURE ChangeModel;
		VAR m: Models.Model; real: Types.Integer; res : LONGINT;
		BEGIN
			IF WMProperties.GetModel(model,m) THEN
				real.value := pos.Get();
				m.SetGeneric(real,res)
			END;
		END ChangeModel;

		PROCEDURE TrackerPointerMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy, dp, d : LONGINT; f : REAL; tmax, tmin : LONGINT;
		BEGIN
			tmax := max.Get();
			tmin := min.Get();
			IF 0 IN keys THEN
				dy := y - ly;
				IF vertical.Get() THEN
					d := bounds.GetHeight();
					IF d > 0 THEN
						 f := tmax; f := (f - tmin); f := f * dy / d; dp := ENTIER(f);
					ELSE dp := 0
					END;
				ELSE
					dx := x - lx;
					d := bounds.GetWidth();
					IF d > 0 THEN
						 f := tmax; f := (f - tmin); f := f * dx / d; dp := ENTIER(f);
					ELSE dp := 0
					END;
				END;
				IF dp # 0 THEN pos.Set(pos.Get() + dp); onPositionChanged.Call(pos) END;
			END;
			handled := FALSE
		END TrackerPointerMove;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			tracker.useBgBitmaps.Set(useTrackerImages.Get());
			minusPage.useBgBitmaps.Set(useBgBitmaps.Get());
			minusPage.clDefault.Set(clDefault.Get());
			minusPage.clHover.Set(clHover.Get());
			minusPage.clPressed.Set(clPressed.Get());
			minusPage.repeatMiddleImg.Set(repeatBgBitmap.Get());
			plusPage.useBgBitmaps.Set(useBgBitmaps.Get());
			plusPage.clDefault.Set(clDefault.Get());
			plusPage.clHover.Set(clHover.Get());
			plusPage.clPressed.Set(clPressed.Get());
			plusPage.repeatMiddleImg.Set(repeatBgBitmap.Get());
			pos.SetBounds(min.Get(), max.Get());
			SetDirection;
			AlignSubComponents;
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = pos) THEN
				AlignSubComponents; Invalidate;
			ELSIF (property = vertical) THEN
				SetDirection
			ELSIF (property = min) OR (property = max) OR (property = pageSize) THEN
				AlignSubComponents;
				pos.SetBounds(min.Get(), max.Get());
				Invalidate
			ELSIF (property = useTrackerImages) OR (property = useBgBitmaps) OR
				(property = clDefault) OR (property = clHover) OR (property = clPressed) THEN
				RecacheProperties;
				Invalidate;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DecPos*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.DecPos, sender, par)
			ELSE pos.Set(pos.Get() - 1); onPositionChanged.Call(pos)
			END
		END DecPos;

		PROCEDURE IncPos*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.IncPos, sender, par)
			ELSE pos.Set(pos.Get() + 1); onPositionChanged.Call(pos)
			END
		END IncPos;

		PROCEDURE PageUp*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PageUp, sender, par)
			ELSE pos.Set(pos.Get() - pageSize.Get()); onPositionChanged.Call(pos)
			END
		END PageUp;

		PROCEDURE PageDown*(sender, par : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PageDown, sender, par)
			ELSE pos.Set(pos.Get() + pageSize.Get()); onPositionChanged.Call(pos)
			END
		END PageDown;

		PROCEDURE AlignSubComponents*;
		VAR h, w, ps, tmin, tmax : LONGINT;
		BEGIN
			Acquire; DisableUpdate;
			(* break a possible endless realignment  *)
			IF aligning THEN EnableUpdate; Release; RETURN END;
			aligning := TRUE;
			tmin := min.Get(); tmax := max.Get();
			ps := Strings.Min(tmax - tmin, pageSize.Get());
			IF vertical.Get() THEN
				IF tmax > tmin THEN
					h := bounds.GetHeight();
					ts := trackerSize.Get();
					tp := (pos.Get() - tmin) * (h - ts) DIV (tmax - tmin);
				ELSE ts := 0; tp := 0;
				END;
				minusPage.bounds.SetHeight(tp);
				plusPage.bounds.SetHeight(h - tp - ts);
			ELSE
				IF tmax > tmin THEN
					w := bounds.GetWidth();
					ts := trackerSize.Get();
					tp := (pos.Get() - tmin) * (w - ts) DIV (tmax - tmin);
				ELSE ts := 0; tp := 0;
				END;
				minusPage.bounds.SetWidth(tp);
				plusPage.bounds.SetWidth(w - tp - ts);
			END;
			aligning := FALSE; (* must set to false before super call *)
			AlignSubComponents^;
			EnableUpdate;
			Release
		END AlignSubComponents;

		PROCEDURE SetDirection;
		BEGIN
			Acquire;
			properties.AcquireWrite;
			SetBackgroundDirection();
			SetTrackerDirection();
			properties.ReleaseWrite;
			Release
		END SetDirection;

		(* set direction of tracker (thumb) *)
		PROCEDURE SetTrackerDirection;
		BEGIN
			tracker.isHorizontal.Set(~SELF.vertical.Get());
			IF vertical.Get() THEN
				tracker.imgDefaultName.Set(vTrackerDefaultName.Get());
				tracker.imgHoverName.Set(vTrackerHoverName.Get());
				tracker.imgPressedName.Set(vTrackerPressedName.Get());
			ELSE
				tracker.imgDefaultName.Set(hTrackerDefaultName.Get());
				tracker.imgHoverName.Set(hTrackerHoverName.Get());
				tracker.imgPressedName.Set(hTrackerPressedName.Get());
			END
		END SetTrackerDirection;

		(* set direction of background (minusPage, plusPage *)
		PROCEDURE SetBackgroundDirection;
		BEGIN
			minusPage.isHorizontal.Set(~SELF.vertical.Get());
			plusPage.isHorizontal.Set(~SELF.vertical.Get());
			IF vertical.Get() THEN
				minusPage.alignment.Set(WMComponents.AlignTop);
				minusPage.imgDefaultNameMiddle.Set(vBgDefaultName.Get());
				minusPage.imgHoverNameMiddle.Set(vBgHoverName.Get());
				minusPage.imgPressedNameMiddle.Set(vBgPressedName.Get());
				plusPage.alignment.Set(WMComponents.AlignBottom);
				plusPage.imgDefaultNameMiddle.Set(vBgDefaultName.Get());
				plusPage.imgHoverNameMiddle.Set(vBgHoverName.Get());
				plusPage.imgPressedNameMiddle.Set(vBgPressedName.Get())
			ELSE
				minusPage.alignment.Set(WMComponents.AlignLeft);
				minusPage.imgDefaultNameMiddle.Set(hBgDefaultName.Get());
				minusPage.imgHoverNameMiddle.Set(hBgHoverName.Get());
				minusPage.imgPressedNameMiddle.Set(hBgPressedName.Get());
				plusPage.alignment.Set(WMComponents.AlignRight);
				plusPage.imgDefaultNameMiddle.Set(hBgDefaultName.Get());
				plusPage.imgHoverNameMiddle.Set(hBgHoverName.Get());
				plusPage.imgPressedNameMiddle.Set(hBgPressedName.Get())
			END
		END SetBackgroundDirection;

	END Slider;

TYPE

	Resizer* = OBJECT(WMComponents.VisualComponent)
	VAR
		clDefault- : WMProperties.ColorProperty;
		isFlat- : WMProperties.BooleanProperty;
		dnx, dny : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenResizer");
			SetNameAsString(StrResizer);
			NEW(clDefault, PrototypeRclDefault, NIL, NIL); properties.Add(clDefault);
			NEW(isFlat, PrototypeRisFlat, NIL, NIL); properties.Add(isFlat);
			bounds.SetPrototype(PrototypeRBounds)
		END Init;

		PROCEDURE RecacheProperties;
		VAR align: LONGINT;
		BEGIN
			RecacheProperties^;
			align := alignment.Get();
			IF (align = WMComponents.AlignRight) OR (align = WMComponents.AlignLeft) THEN
				SetPointerInfo(manager.pointerLeftRight)
			ELSIF (align = WMComponents.AlignBottom) OR (align = WMComponents.AlignTop) THEN
				SetPointerInfo(manager.pointerUpDown)
			END;
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		BEGIN
			IF (data = properties) OR (data = alignment) THEN RecacheProperties; (*? PH added *) Invalidate;
			ELSIF (data = clDefault) OR (data = isFlat) THEN Invalidate;
			ELSE PropertyChanged^(sender, data)
			END;
		END PropertyChanged;

		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		BEGIN
			dnx := x; dny := y
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		VAR dx, dy, align, myWidth, myHeight, newL, newR, newT, newB: LONGINT;
			p, pp : WMComponents.VisualComponent;
			parent : XML.Element;
			pRect, ppRect: WMRectangles.Rectangle;
		BEGIN
			RecacheProperties;
			IF 0 IN keys THEN
				dx := x - dnx; dy := y - dny;
				parent := GetParent();
				IF (parent # NIL) & (parent IS WMComponents.VisualComponent) THEN
					p := parent(WMComponents.VisualComponent);
					parent := p.GetParent();
					IF (parent # NIL) & (parent IS WMComponents.VisualComponent) THEN
						pp := parent(WMComponents.VisualComponent);
						align := alignment.Get();
						pRect := p.bounds.Get();
						ppRect := pp.bounds.Get();
						myWidth := bounds.GetWidth();
						myHeight := bounds.GetHeight();
						IF align = WMComponents.AlignRight THEN
							newR := pRect.r + dx;
							IF newR > ppRect.r - myWidth THEN
								newR := ppRect.r - myWidth;
							ELSIF newR < pRect.l + myWidth + 1 THEN
								newR := pRect.l + myWidth + 1;
							END;
							pRect.r := newR;
						ELSIF align = WMComponents.AlignLeft THEN
							newL := pRect.l + dx;
							IF newL < ppRect.l + myWidth THEN
								newL := ppRect.l + myWidth;
							ELSIF newL > pRect.r - myWidth THEN
								newL := pRect.r - myWidth;
							END;
							pRect.l := newL;
						ELSIF align = WMComponents.AlignBottom THEN
							newB := pRect.b + dy;
							IF newB > ppRect.b - myHeight THEN
								newB := ppRect.b - myHeight
							ELSIF newB < pRect.t + myHeight THEN
								newB := pRect.t + myHeight
							END;
							pRect.b := newB;
						ELSIF align = WMComponents.AlignTop THEN
							newT := pRect.t + dy;
							IF newT > pRect.b - myHeight THEN
								newT := pRect.b - myHeight
							ELSIF newT < ppRect.t + myHeight THEN
								newT := ppRect.t + myHeight
							END;
							pRect.t := newT;
						END;
						p.bounds.Set(pRect);
					END
				END
			END
		END PointerMove;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			canvas.Fill(GetClientRect(), SELF.clDefault.Get(), WMGraphics.ModeSrcOverDst);
			IF ~SELF.isFlat.Get() THEN WMGraphicUtilities.RectGlassShade(canvas, GetClientRect(), 2, FALSE) END
		END DrawBackground;

	END Resizer;

	(* Group Panel *)
	GroupPanel* = OBJECT(Panel)
	VAR
		caption-: WMProperties.StringProperty;
		textColor- : WMProperties.ColorProperty;

		border : WMRectangles.Rectangle;
		captionFont : WMGraphics.Font;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenGroupPanel");
			SetNameAsString(StrGroupPanel);
			NEW(caption, ProtGPCaption, NIL, NIL); properties.Add(caption);
			NEW(textColor, ProtGPTextColor, NIL, NIL); properties.Add(textColor);
			border := WMRectangles.MakeRect(10,14,10,10);
			captionFont := WMGraphics.GetFont("Oberon", 8, {});
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = caption) OR (property = textColor) THEN Invalidate
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground(canvas: WMGraphics.Canvas);
		VAR rect: WMRectangles.Rectangle;
			highlight, shadow, w, h : LONGINT;
			tempString : Strings.String;
		BEGIN
			DrawBackground^(canvas);
			highlight := LONGINT(0FFFFFF80H);
			shadow := 000000080H;
			rect := GetClientRect();
			tempString := caption.Get();
			(* group line *)
			IF (tempString = NIL) OR (tempString^ = "") THEN
				canvas.Line(rect.l+3, rect.t+5, rect.r-4, rect.t+5, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+4, rect.t+6, rect.r-5, rect.t+6, highlight, WMGraphics.ModeSrcOverDst);
			ELSE
				captionFont.GetStringSize(tempString^, w, h);
				canvas.Line(rect.l+3, rect.t+5, rect.l+12, rect.t+5, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+4, rect.t+6, rect.l+12, rect.t+6, highlight, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+w+17, rect.t+5, rect.r-4, rect.t+5, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+w+17, rect.t+6, rect.r-5, rect.t+6, highlight, WMGraphics.ModeSrcOverDst);
			END;
			canvas.Line(rect.l+3, rect.b-4, rect.r-4, rect.b-4, shadow, WMGraphics.ModeSrcOverDst);
			canvas.Line(rect.l+3, rect.t+5, rect.l+3, rect.b-4, shadow, WMGraphics.ModeSrcOverDst);
			canvas.Line(rect.r-4, rect.t+5, rect.r-4, rect.b-4, shadow, WMGraphics.ModeSrcOverDst);

			canvas.Line(rect.l+3, rect.b-3, rect.r-3, rect.b-3, highlight, WMGraphics.ModeSrcOverDst);
			canvas.Line(rect.l+4, rect.t+6, rect.l+4, rect.b-5, highlight, WMGraphics.ModeSrcOverDst);
			canvas.Line(rect.r-3, rect.t+5, rect.r-3, rect.b-3, highlight, WMGraphics.ModeSrcOverDst);
			(* caption *)
			IF (tempString # NIL) & (tempString^ # "") THEN
				canvas.SetColor(textColor.Get());
				captionFont.RenderString(canvas, rect.l+15, rect.t+9, tempString^);
			END;
		END DrawBackground;

		PROCEDURE AlignSubComponents*; (** override *)
		VAR c : XML.Content; vc : WMComponents.VisualComponent;
			r, b : WMRectangles.Rectangle;
		BEGIN
			Acquire;
			IF aligning THEN Release; RETURN END;
			aligning := TRUE;
			r := GetClientRect();
			r.l := r.l + border.l; r.t := r.t + border.t; r.r := r.r - border.r; r.b := r.b - border.b;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS WMComponents.VisualComponent THEN
					vc := c(WMComponents.VisualComponent);
					IF vc.visible.Get() THEN
						b := vc.bearing.Get();
						CASE vc.alignment.Get() OF
						| WMComponents.AlignTop : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.t + b.t + vc.bounds.GetHeight())); INC(r.t, vc.bounds.GetHeight() + b.t + b.b)
						| WMComponents.AlignLeft : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l, r.t + b.t, r.l + b.l + vc.bounds.GetWidth(), r.b - b.b)); INC(r.l, vc.bounds.GetWidth() + b.l + b.r)
						| WMComponents.AlignBottom : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l, r.b - vc.bounds.GetHeight() - b.b, r.r - b.r, r.b - b.b)); DEC(r.b, vc.bounds.GetHeight() + b.t + b.b)
						|WMComponents.AlignRight : vc.bounds.Set(WMRectangles.MakeRect(r.r - vc.bounds.GetWidth() - b.r , r.t + b.t, r.r - b.r, r.b - b.b)); DEC(r.r, vc.bounds.GetWidth() + b.l + b.r);
						| WMComponents.AlignClient : IF ~WMRectangles.RectEmpty(r) THEN vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.b  - b.b)) END
						ELSE (* nothing *)
						END;
					END;
				END;
				c := GetNext(c);
			END;
			aligning := FALSE;
			Release;
		END AlignSubComponents;

	END GroupPanel;

CONST
	(** checkbox states *)
	Default* = -1;
	Unchecked* = 0;
	Checked* = 1;

	(** checkbox caption position *)
	Left* = 0;
	Right* = 1;

TYPE
	(** Checkbox component *)
	Checkbox* = OBJECT(WMComponents.VisualComponent)
	VAR
		caption- , onClickHandler-: WMProperties.StringProperty;
		hasThreeStates-, useImages-, scaleImages- : WMProperties.BooleanProperty;
		state- : WMProperties.Int32Property;	 (* 0 = unchecked, 1 = checked, -1 = use default *)
		clBack-, clCheck-, clDefault-, clInactive- : WMProperties.ColorProperty;
		imgCheckedName-, imgUncheckedName-, imgDefaultName-, imgCheckedInactiveName-, imgUncheckedInactiveName-, imgDefaultInactiveName-: WMProperties.StringProperty;
		imgChecked, imgUnchecked, imgDefault, imgCheckedInactive, imgUncheckedInactive, imgDefaultInactive: WMGraphics.Image;
		mouseOver: BOOLEAN;
		onClick- : EventSource;
		handler : WMEvents.EventListener;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenCheckbox");
			NEW(caption, ProtCBCaption, NIL, NIL); properties.Add(caption);
			NEW(hasThreeStates, ProtCBHasThreeStates, NIL, NIL); properties.Add(hasThreeStates);
			NEW(state, ProtCBState, NIL, NIL); properties.Add(state);
			NEW(onClickHandler, PrototypeCBonClickHandler, NIL, NIL); properties.Add(onClickHandler);

			bounds.SetPrototype(ProtCBBounds); (* override the defaults *)

			(* colors *)
			NEW(clBack, ProtCBclBack, NIL, NIL); properties.Add(clBack);
			NEW(clCheck, ProtCBclCheck, NIL, NIL); properties.Add(clCheck);
			NEW(clDefault, ProtCBclDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clInactive, ProtCBclInactive, NIL, NIL); properties.Add(clInactive);

			(* images *)
			NEW(useImages, ProtCBUseImages, NIL, NIL); properties.Add(useImages);
			NEW(scaleImages, ProtCBScaleImages, NIL, NIL); properties.Add(scaleImages);

			NEW(imgCheckedName, ProtCBImgCheckedN, NIL, NIL); properties.Add(imgCheckedName);
			NEW(imgUncheckedName, ProtCBImgUncheckedN, NIL, NIL); properties.Add(imgUncheckedName);
			NEW(imgDefaultName, ProtCBImgDefaultN, NIL, NIL); properties.Add(imgDefaultName);
			NEW(imgCheckedInactiveName, ProtCBImgCheckedInactiveN, NIL, NIL); properties.Add(imgCheckedInactiveName);
			NEW(imgUncheckedInactiveName, ProtCBImgUncheckedInactiveN, NIL, NIL); properties.Add(imgUncheckedInactiveName);
			NEW(imgDefaultInactiveName, ProtCBImgDefaultInactiveN, NIL, NIL); properties.Add(imgDefaultInactiveName);

			(* events *)
			NEW(onClick, SELF, GSonClick, GSonClickCheckboxInfo, SELF.StringToCompCommand); events.Add(onClick);
			SetNameAsString(StrCheckbox);
		END Init;

		PROCEDURE CheckClickHandler;
		VAR th : WMEvents.EventListener; s : String;
		BEGIN
			s := onClickHandler.Get();
			IF s # NIL THEN
				th := StringToCompCommand(s);
				IF (handler # NIL) THEN onClick.Remove(handler) END;
				IF th # NIL THEN onClick.Add(th); handler := th END
			END
		END CheckClickHandler;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		BEGIN
			IF (data = caption) THEN Invalidate
			ELSIF (data = onClickHandler) THEN CheckClickHandler;
			ELSIF (data = scaleImages) THEN Invalidate;
			ELSIF (data = state) THEN Invalidate;
			ELSIF (data = clBack) OR (data = clCheck) OR (data = clDefault) OR (data = clInactive) THEN Invalidate;
			ELSIF (data = useImages)
				OR (data = imgCheckedName) OR (data = imgUncheckedName) OR (data = imgDefaultName)
				OR (data = imgCheckedInactiveName) OR (data = imgUncheckedInactiveName) OR (data = imgDefaultInactiveName)  THEN
				RecacheProperties; Invalidate
			ELSE PropertyChanged^(sender, data)
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		VAR s : String;
		BEGIN
			RecacheProperties^;
			IF useImages.Get() THEN
				s := imgCheckedName.Get(); IF s # NIL THEN imgChecked := WMGraphics.LoadImage(s^, TRUE) END;
				s := imgUncheckedName.Get(); IF s # NIL THEN imgUnchecked := WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultName.Get(); IF s # NIL THEN imgDefault	:= WMGraphics.LoadImage(s^, TRUE) END;
				s := imgCheckedInactiveName.Get(); IF s # NIL THEN imgCheckedInactive := WMGraphics.LoadImage(s^, TRUE) END;
				s := imgUncheckedInactiveName.Get(); IF s # NIL THEN imgUncheckedInactive := WMGraphics.LoadImage(s^, TRUE) END;
				s := imgDefaultInactiveName.Get(); IF s # NIL THEN imgDefaultInactive := WMGraphics.LoadImage(s^, TRUE) END;
			ELSE
				imgChecked := NIL; imgUnchecked := NIL;
				imgDefault := NIL;
				imgCheckedInactive := NIL; imgUncheckedInactive := NIL;
				imgDefaultInactive := NIL;
			END;
			CheckClickHandler;
		END RecacheProperties;

		PROCEDURE FocusReceived*;
		BEGIN
			FocusReceived^;
			Invalidate
		END FocusReceived;

		PROCEDURE FocusLost*;
		BEGIN
			FocusLost^;
			Invalidate
		END FocusLost;

		PROCEDURE PointerDown(x, y: LONGINT; keys: SET);
		VAR value : LONGINT;
		BEGIN
			IF enabled.Get() THEN
				value := state.Get();
				IF value = -1 THEN state.Set(0);
				ELSIF value = 0 THEN state.Set(1);
				ELSIF (value = 1) THEN
					IF hasThreeStates.Get() THEN
						state.Set(-1);
					ELSE
						state.Set(0);
					END;
				END;
				Click(SELF, NIL);
			END;
			Invalidate; 
			PointerDown^(x, y, keys)
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			IF IsHit(x, y) THEN
				IF ~mouseOver THEN mouseOver := TRUE; Invalidate END
			ELSE
				IF mouseOver THEN mouseOver := FALSE; Invalidate END
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE PointerLeave*; (** PROTECTED *)
		BEGIN
			 mouseOver := FALSE; Invalidate
		END PointerLeave;

		PROCEDURE Click*(sender, par : ANY); (** Eventhandler *)
		BEGIN
			(* synchronize if not synchronized *)
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Click, sender, par)
			ELSE
				(* actual business logic *)
				onClick.Call(par)
			END
		END Click;

		PROCEDURE DrawBackground(canvas: WMGraphics.Canvas);
		VAR
			rect: WMRectangles.Rectangle;
			string : Strings.String;
			font : WMGraphics.Font;
			img : WMGraphics.Image;
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			rect := GetClientRect();
			font := GetFont();

			DrawBackground^(canvas);
			(* checkbox *)
			IF ~SELF.useImages.Get() THEN
				IF enabled.Get() THEN
					canvas.Fill(WMRectangles.MakeRect(0, 0, rect.r-rect.l, rect.b-rect.t), clBack.Get(), WMGraphics.ModeSrcOverDst);
				ELSE
					canvas.Fill(WMRectangles.MakeRect(0, 0, rect.r-rect.l, rect.b-rect.t), clInactive.Get(), WMGraphics.ModeSrcOverDst);
				END;
				WMGraphicUtilities.RectGlassShade(canvas, WMRectangles.MakeRect(0, 0, rect.r-rect.l, rect.b-rect.t), 2, TRUE);
				IF state.Get() = 1 THEN
					canvas.Line(0, 0, rect.r-rect.l-1, rect.b-rect.t-1, clCheck.Get(), WMGraphics.ModeSrcOverDst);
					canvas.Line(0, rect.b-rect.t-1, rect.r-rect.l-1, 0, clCheck.Get(), WMGraphics.ModeSrcOverDst);
				ELSIF state.Get() = -1 THEN
					canvas.Line(0, 0, rect.r-rect.l-1, rect.b-rect.t-1, clDefault.Get(), WMGraphics.ModeSrcOverDst);
					canvas.Line(0, rect.b-rect.t-1, rect.r-rect.l-1, 0, clDefault.Get(), WMGraphics.ModeSrcOverDst);
				END;
			ELSE  (* the checkbox is decorated by images *)
				IF enabled.Get() THEN
					IF state.Get() = -1 THEN
						img := imgDefault;
					ELSIF state.Get() = 0 THEN
						img := imgUnchecked;
					ELSIF state.Get() = 1 THEN
						img := imgChecked;
					END;
				ELSE
					IF state.Get() = -1 THEN
						img := imgDefaultInactive;
					ELSIF state.Get() = 0 THEN
						img := imgUncheckedInactive;
					ELSIF state.Get() = 1 THEN
						img := imgCheckedInactive;
					END;
				END;

				IF img # NIL THEN
					IF scaleImages.Get() THEN
						canvas.ScaleImage(	img,
					 		WMRectangles.MakeRect(0, 0, img.width, img.height),
							WMRectangles.MakeRect(0, 0, ENTIER(bounds.GetHeight()/img.height*img.width), bounds.GetHeight()),
							WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
					ELSE
						canvas.DrawImage(0, ((rect.b-rect.t)-img.height) DIV 2, img, WMGraphics.ModeSrcOverDst);
					END;
				END;
			END;
			(* checkbox hover *)
			IF mouseOver THEN
				IF useImages.Get() THEN
					IF scaleImages.Get() THEN
						canvas.Fill(WMRectangles.MakeRect(0, 0, ENTIER(bounds.GetHeight()/img.height*img.width), bounds.GetHeight()), LONGINT(0FFFF0040H), WMGraphics.ModeSrcOverDst)
					ELSE
						canvas.Fill(WMRectangles.MakeRect(0, ((rect.b-rect.t)-img.height) DIV 2, img.width, img.height), LONGINT(0FFFF0040H), WMGraphics.ModeSrcOverDst)
					END
				ELSE
					canvas.Fill(WMRectangles.MakeRect(0, 0, rect.r-rect.l, rect.b-rect.t), LONGINT(0FFFF0040H), WMGraphics.ModeSrcOverDst)
				END
			END;
			(* caption *)
			string := caption.Get();
			canvas.DrawString(rect.r-rect.l+5, (((rect.b-rect.t)- font.GetHeight()) DIV 2) + font.ascent+1, string^);
			Release
		END DrawBackground;

	END Checkbox;

TYPE

	Image* = OBJECT(Panel)
	VAR
		imageName- : WMProperties.StringProperty;
		image- : WMGraphics.Image;

		scaleImage- : WMProperties.BooleanProperty;
		scaleImageI : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenImage");
			SetNameAsString(StrImage);
			NEW(imageName, PrototypeImageName, NIL, NIL); properties.Add(imageName);
			image := NIL;
			NEW(scaleImage, PrototypeScaleImage, NIL, NIL); properties.Add(scaleImage);
			scaleImageI := scaleImage.Get();
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = imageName) THEN
				RecacheProperties; (*? PH*) Invalidate;
			ELSIF (property = scaleImage) THEN
				scaleImageI := scaleImage.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property)
			END
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		VAR s : String;
		BEGIN
			RecacheProperties^;
			scaleImageI := scaleImage.Get();
			s := imageName.Get();
			IF (s # NIL) THEN
				image := WMGraphics.LoadImage(s^, TRUE);
			ELSE
				image := NIL;
			END;
		END RecacheProperties;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR width, height : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			IF (image # NIL) & show THEN
				IF scaleImageI THEN
					width := bounds.GetWidth();
					height := bounds.GetHeight();
					IF (image.width # width) OR (image.height # height) THEN
						canvas.ScaleImage(image,
							WMRectangles.MakeRect(0, 0, image.width, image.height),
							WMRectangles.MakeRect(0, 0, width, height),
							WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
					ELSE
						canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst);
					END;
				ELSE
					canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst);
				END;
			END
		END DrawBackground;

	END Image;

TYPE

	(** just shows an image, showing scrollbars if necessairy *)
	ImagePanel* = OBJECT(Panel)
	VAR
		imgName- : WMProperties.StringProperty;
		img : WMGraphics.Image;
		vScrollbar, hScrollbar : Scrollbar;
		dx, dy : LONGINT;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetGenerator("WMStandardComponents.GenImagePanel");
			(* properties *)
			NEW(imgName, ProtoIpImgName, NIL, NIL); properties.Add(imgName);
			(* scrollbars *)
			NEW(vScrollbar);
			vScrollbar.alignment.Set(WMComponents.AlignRight); AddInternalComponent(vScrollbar);
			vScrollbar.onPositionChanged.Add(ScrollbarsChanged); vScrollbar.visible.Set(FALSE);
			NEW(hScrollbar);
			hScrollbar.alignment.Set(WMComponents.AlignBottom); AddInternalComponent(hScrollbar);
			hScrollbar.vertical.Set(FALSE); hScrollbar.onPositionChanged.Add(ScrollbarsChanged);
			hScrollbar.visible.Set(FALSE);
			SetNameAsString(StrImagePanel);
			dx := 0;  dy := 0
		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF property = imgName THEN
				RecacheProperties; Invalidate;
			ELSE
				PropertyChanged^(sender, property)
			END
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		VAR s : String;
		BEGIN
			s := imgName.Get(); IF s # NIL THEN SetImage(SELF, WMGraphics.LoadImage(s^, TRUE)) END
		END RecacheProperties;

		PROCEDURE ScrollbarsChanged(sender, data : ANY);
		BEGIN
			Invalidate
		END ScrollbarsChanged;

		(** Iff data IS WMGraphics.Image, it is set as background. Else the background is set to white *)
		(* Note: Only use for anonymous Images without a specific Name *)
		PROCEDURE SetImage*(sender, data : ANY); (*? PH is Invalidate always handled in PropertyChanged here, or does this exporte procedure occur in other contexts ?*)
		BEGIN
			IF (data # NIL) & (data IS WMGraphics.Image) THEN
				img := data(WMGraphics.Image);
				IF img.width > bounds.GetWidth() THEN
					dx := img.width - bounds.GetWidth();
					hScrollbar.visible.Set(TRUE)
				ELSE
					dx := 0;
					hScrollbar.visible.Set(FALSE)
				END;
				IF img.height > bounds.GetHeight() THEN
					dy := img.height - bounds.GetHeight();
					vScrollbar.visible.Set(TRUE)
				ELSE
					dx := 0;
					vScrollbar.visible.Set(FALSE)
				END;
				Invalidate
			ELSE
				img := NIL; Invalidate
			END
		END SetImage;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR x, y : LONGINT;
		BEGIN
			IF show THEN
				DrawBackground^(canvas);
				IF img # NIL THEN
					x := dx * hScrollbar.pos.Get() DIV 100;
					y := dy * vScrollbar.pos.Get() DIV 100;
					canvas.DrawImage(-x, -y, img, WMGraphics.ModeSrcOverDst)
				END
			END;
		END DrawBackground;

	END ImagePanel;

VAR
	manager : WMWindowManager.WindowManager;
	blinker-: Blinker;

	(* global strings *)
	GSonTimer, GSonTimerInfo, GSStart, GSStartTimerInfo, GSStop, GSStopTimerInfo : String;
	GSRun, GSRunSystemCommandInfo, GSCallEventInfo : String;
	GSonClick, GSonClickButtonInfo, GSonClickCheckboxInfo : String;
	GSonPositionChanged, GSonPositionChangedInfo : String;

	PrototypeDelay*, PrototypeInterval* : WMProperties.Int32Property;
	PrototypeCommandString*, PrototypeCaption* : WMProperties.StringProperty;
	PrototypeFont- : WMProperties.FontProperty;
	PrototypeTextColor*: WMProperties.ColorProperty;
	PrototypeAlignH*, PrototypeButtonAlignH*: WMProperties.Int32Property;
	PrototypeAlignV*, PrototypeButtonAlignV*: WMProperties.Int32Property;
	 (* temporary prototype-prototypes *)
	 ColorPrototype : WMProperties.ColorProperty;
	 BooleanPrototype : WMProperties.BooleanProperty;
	 StringPrototype : WMProperties.StringProperty;
	 Int32Prototype : WMProperties.Int32Property;
	 RectanglePrototype : WMProperties.RectangleProperty;
	 PrototypeBlinking*: WMProperties.BooleanProperty;

 	 (* Button prototypes *)
	 PrototypeBBounds* : WMProperties.RectangleProperty;
	 PrototypeBUseBgImages* : WMProperties.BooleanProperty;
	 PrototypeBclDefault*, PrototypeBclHover*, PrototypeBclPressed*, PrototypeBclInactive*,
	 PrototypeBclTextDefault*, PrototypeBclTextHover*, PrototypeBclTextPressed* , PrototypeBclTextInactive*: WMProperties.ColorProperty;
	 PrototypeBRepeatMiddleImg*, PrototypeBisRepeating*, PrototypeBisToggle*, PrototypeBisInverse*, PrototypeBindicateToggle*, PrototypeBIsHorizontal* : WMProperties.BooleanProperty;
	 PrototypeBcaption*, PrototypeBonClickHandler* : WMProperties.StringProperty;
	 PrototypeBimgDefaultName*, PrototypeBimgInactiveName*, PrototypeBimgHoverName*, PrototypeBimgPressedName*, PrototypeBimageName* : WMProperties.StringProperty;
 	 PrototypeImgDefaultNameLeft*, PrototypeImgDefaultNameRight*, PrototypeImgDefaultNameMiddle*,
 	 PrototypeImgDefaultNameTop*, PrototypeImgDefaultNameBottom*,
 	 PrototypeImgHoverNameLeft*, PrototypeImgHoverNameRight*, PrototypeImgHoverNameMiddle*,
 	 PrototypeImgHoverNameTop*, PrototypeImgHoverNameBottom*,
 	 PrototypeImgPressedNameLeft*, PrototypeImgPressedNameRight*, PrototypeImgPressedNameMiddle*,
 	 PrototypeImgPressedNameTop*, PrototypeImgPressedNameBottom* : WMProperties.StringProperty;
	 PrototypeBEffect3D : WMProperties.Int32Property;

	PrototypeUseDeco*: WMProperties.BooleanProperty;
	PrototypeDecoDefaultName*, PrototypeDecoHoverName*, PrototypeDecoPressedName*: WMProperties.StringProperty;

	 (* Scrollbar prototypes *)
	 PrototypeSvertical* : WMProperties.BooleanProperty;
	 PrototypeSmin*, PrototypeSmax*, PrototypeSpos*, PrototypeSpageSize*, PrototypeTrackerSize*, PrototypeSWidth*,
	 PrototypeSMinTrackerSize* : WMProperties.Int32Property;
		 (* presentation : colors / images *)
 	 PrototypeSUseArrowImages*, PrototypeSUseTrackerImages*, PrototypeSRepeatMiddleBitmap* : WMProperties.BooleanProperty;
	 	(* background *)
	 PrototypeSUseBgBitmaps*, PrototypeSRepeateBgBitmap* : WMProperties.BooleanProperty;
 	 PrototypeSClDefault*, PrototypeSClHover*, PrototypeSClPressed*,
 	 PrototypeSClBtnDefault*, PrototypeSClBtnHover*, PrototypeSClBtnPressed* : WMProperties.ColorProperty;
 	 PrototypeSEffect3D* : WMProperties.Int32Property;
 	 PrototypeSvBgDefault*, PrototypeSvBgHover*, PrototypeSvBgPressed*,
 	 PrototypeShBgDefault*, PrototypeShBgHover*, PrototypeShBgPressed* : WMProperties.StringProperty;
 	 	(* arrow images *)
 	 PrototypeSArrowLeftDefault*, PrototypeSArrowLeftHover*, PrototypeSArrowLeftPressed*,
 	 PrototypeSArrowUpDefault*, PrototypeSArrowUpHover*, PrototypeSArrowUpPressed*,
 	 PrototypeSArrowRightDefault*, PrototypeSArrowRightHover*, PrototypeSArrowRightPressed*,
 	 PrototypeSArrowDownDefault*, PrototypeSArrowDownHover*, PrototypeSArrowDownPressed*  : WMProperties.StringProperty;
 	 	(* horizontal tracker *)
 	 PrototypeShTrackerDefaultLeft*, PrototypeShTrackerHoverLeft*, PrototypeShTrackerPressedLeft*,
 	 PrototypeShTrackerDefaultMiddle*, PrototypeShTrackerHoverMiddle*, PrototypeShTrackerPressedMiddle*,
 	 PrototypeShTrackerDefaultRight*, PrototypeShTrackerHoverRight*, PrototypeShTrackerPressedRight*,
 	 	(* vertical tracker *)
 	 PrototypeSvTrackerDefaultTop*, PrototypeSvTrackerHoverTop*, PrototypeSvTrackerPressedTop*,
 	 PrototypeSvTrackerDefaultMiddle*, PrototypeSvTrackerHoverMiddle*, PrototypeSvTrackerPressedMiddle*,
 	 PrototypeSvTrackerDefaultBottom*, PrototypeSvTrackerHoverBottom*, PrototypeSvTrackerPressedBottom* : WMProperties.StringProperty;

 	 (* Slider prototypes *)
	PrototypeSlhTrackerDefault*, PrototypeSlhTrackerHover*, PrototypeSlhTrackerPressed*,
	PrototypeSlvTrackerDefault*, PrototypeSlvTrackerHover*, PrototypeSlvTrackerPressed*,
	PrototypeSlhBgDefault*, PrototypelShBgHover*, PrototypeSlhBgPressed*,
	PrototypeSlvBgDefault*, PrototypeSlvBgHover*, PrototypeSlvBgPressed* : WMProperties.StringProperty;
	PrototypeSlUseTrackerImages*, PrototypeSlUseBgBitmaps*, PrototypeSlRepeatBgBitmap* : WMProperties.BooleanProperty;
	PrototypeSlClDefault*, PrototypeSlClHover*, PrototypeSlClPressed*, PrototypeSlClBar* : WMProperties.ColorProperty;

	 PrototypeSlvertical* : WMProperties.BooleanProperty;
	 PrototypeSlmin*, PrototypeSlmax*, PrototypeSlpos*, PrototypeSlpageSize*,
	 PrototypeSlMinTrackerSize* : WMProperties.Int32Property;

 	 (* Resizer prototypes *)
	 PrototypeRclDefault* : WMProperties.ColorProperty;
	 PrototypeRisFlat* : WMProperties.BooleanProperty;
	 PrototypeRBounds* : WMProperties.RectangleProperty;

	(* Checkbox Prototypes *)
	ProtCBBounds* : WMProperties.RectangleProperty;
	ProtCBCaption*, PrototypeCBonClickHandler* : WMProperties.StringProperty;
	ProtCBCaptionPos* : WMProperties.Int32Property;
	ProtCBHasThreeStates* : WMProperties.BooleanProperty;
	ProtCBState* : WMProperties.Int32Property;
	ProtCBclBack*, ProtCBclCheck*, ProtCBclDefault*, ProtCBclInactive* : WMProperties.ColorProperty;
	ProtCBUseImages* : WMProperties.BooleanProperty;
	ProtCBScaleImages* : WMProperties.BooleanProperty;
	ProtCBImgCheckedN*, ProtCBImgUncheckedN*, ProtCBImgDefaultN*,
	ProtCBImgCheckedInactiveN*, ProtCBImgUncheckedInactiveN*, ProtCBImgDefaultInactiveN* : WMProperties.StringProperty;

	(* Group Panel *)
	ProtGPCaption* : WMProperties.StringProperty;
	ProtGPTextColor* : WMProperties.ColorProperty;

	(* Image *)
	PrototypeImageName- : WMProperties.StringProperty;
	PrototypeScaleImage : WMProperties.BooleanProperty;

	(* Image Panel *)
	ProtoIpImgName* : WMProperties.StringProperty;
	PrototypeHorizontalFit : WMProperties.BooleanProperty;
	PrototypeTextBorder : WMProperties.Int32Property;


	StrTimer*, StrSystemCommand*, StrEvent*, StrPanel*, StrDecoratorPanel*, StrLabel*, StrButton*, StrScrollbar*, StrResizer* ,
	StrCheckbox, StrGroupPanel, StrImagePanel, StrModel, StrModelInfo, StrImage : String;

PROCEDURE InitStrings;
BEGIN
	GSonTimer := NewString("onTimer"); GSonTimerInfo := NewString("generates an event if the timer runs out");
	GSStart := NewString("Start"); GSStartTimerInfo := NewString("start the timer");
	GSStop := NewString("Stop"); GSStopTimerInfo := NewString("stop the timer");
	GSRun := NewString("Run");

	GSRunSystemCommandInfo := NewString("run the system command specified in commandString");
	GSCallEventInfo := NewString("call the event listener specified in commandString");

	GSonClick := NewString("onClick"); GSonClickButtonInfo := NewString("generates an event if the button is clicked");
	GSonClickCheckboxInfo := NewString("generates an event if the checkbox is clicked");
	GSonPositionChanged := NewString("onPositionChanged");
	GSonPositionChangedInfo := NewString("generates an event if the position is changed");

	StrTimer := NewString("Timer");
	StrSystemCommand := NewString("SystemCommand");
	StrEvent := NewString("Event");
	StrPanel := NewString("Panel");
	StrDecoratorPanel := NewString("DecoratorPanel");
	StrLabel := NewString("Label");
	StrButton := NewString("Button");
	StrScrollbar := NewString("Scrollbar");
	StrResizer := NewString("Resizer");
	StrCheckbox := NewString("Checkbox");
	StrGroupPanel := NewString("GroupPanel");
	StrImage := NewString("Image");
	StrImagePanel := NewString("ImagePanel");
	StrModel := NewString("Model");
	StrModelInfo := NewString("Model used by component");
END InitStrings;

PROCEDURE InitPrototypes;
VAR
	plTimer, plLabel, plButton, plDecorator, plScrollbar, plSlider, plResizer, plCheckbox, plGroupPanel, plImagePanel : WMProperties.PropertyList;
BEGIN
	(* Timer properties *)
	NEW(plTimer);
	NEW(PrototypeInterval, NIL, NewString("Interval"),  NewString("time between two timer ticks in ms"));
	PrototypeInterval.Set(100);
	plTimer.Add(PrototypeInterval);
	NEW(PrototypeDelay, NIL, NewString("Delay"),  NewString("delay before timer ticks run"));
	PrototypeDelay.Set(1000);
	plTimer.Add(PrototypeDelay);
	WMComponents.propertyListList.Add("Timer", plTimer);

	(* SystemCommand properties *)
	NEW(PrototypeCommandString, NIL, NewString("CommandString"), NewString("command to be executed uppon call to Run"));

	(* Label properties *)
	NEW(plLabel); WMComponents.propertyListList.Add("Label", plLabel);
	NEW(PrototypeCaption, NIL, NewString("Caption"), NewString("caption text"));
	NEW(PrototypeFont, NIL, NewString("Font"), NewString("Font"));
	PrototypeFont.Set(WMGraphics.GetDefaultFont());
	NEW(PrototypeTextColor, NIL, NewString("TextColor"), NewString("text color")); plLabel.Add(PrototypeTextColor);
	PrototypeTextColor.Set(0FFH);
	NEW(PrototypeAlignH, NIL, NewString("AlignH"), NewString("horizontal alignment")); plLabel.Add(PrototypeAlignH);
	PrototypeAlignH.Set(WMGraphics.AlignLeft);
	NEW(PrototypeAlignV, NIL, NewString("AlignV"), NewString("vertical alignment")); plLabel.Add(PrototypeAlignV);
	PrototypeAlignV.Set(WMGraphics.AlignCenter);

	(*
	NEW(plDecorator); WMComponents.propertyListList.Add("Decorator", plDecorator);
	NEW(PrototypeTopLeftName, NIL, NewString("TopLeft"), NewString("Default Top Left Decorator Bitmap")); PrototypeTopLeftName.Set(NewString("")); plDecorator.Add(PrototypeTopLeftName);
	NEW(PrototypeTopName, NIL, NewString("Top"), NewString("Default Top Decorator Bitmap")); PrototypeLeftName.Set(NewString("")); plDecorator.Add(PrototypeTopName);
	NEW(PrototypeTopRightName, NIL, NewString("TopRight"), NewString("Default Top Right Decorator Bitmap")); PrototypeRightName.Set(NewString("")); plDecorator.Add(PrototypeTopRightName);
	NEW(PrototypeBottomLeftName, NIL, NewString("BottomLeft"), NewString("Default Bottom Left Decorator Bitmap")); PrototypeBottomLeftName.Set(NewString("")); plDecorator.Add(PrototypeBottomLeftName);
	NEW(PrototypeBottomName, NIL, NewString("Bottom"), NewString("Default Bottom Decorator Bitmap")); PrototypeBottomName.Set(NewString("")); plDecorator.Add(PrototypeBottomName);
	NEW(PrototypeBottomRightName, NIL, NewString("BottomRight"), NewString("Default Bottom Right Decorator Bitmap")); PrototypeBottomRightName.Set(NewString("")); plDecorator.Add(PrototypeBottomRightName);
	NEW(PrototypeLeftName, NIL, NewString("Left"), NewString("Default Left Decorator Bitmap")); PrototypeLeftName.Set(NewString("")); plDecorator.Add(PrototypeLeftName);
	NEW(PrototypeRightName, NIL, NewString("Right"), NewString("Default Right Decorator Bitmap")); PrototypeRightName.Set(NewString("")); plDecorator.Add(PrototypeRightName);
	*)

	(* Button properties *)
	NEW(plButton);	WMComponents.propertyListList.Add("Button", plButton);
		(* caption *)
	NEW(PrototypeBcaption, NIL, NewString("Caption"), NewString("defines the button text"));
		(* font size *)
	NEW(Int32Prototype, NIL, NewString("FontHeight"), NewString("height of the button text")); Int32Prototype.Set(12);
	NEW(PrototypeBisRepeating, NIL, NewString("IsRepeating"), NewString("defines if the button repeats sending click events while being pressed down"));
	NEW(PrototypeBisToggle, NIL, NewString("IsToggle"), NewString("defines if the button is a toggle button"));
	NEW(PrototypeBisInverse, NIL, NewString("IsInverse"), NewString("defines if the button is the inverse of the model"));
	NEW(PrototypeBindicateToggle, NIL, NewString("IndicateToggle"), NewString("Display small LED in toggle buttons"));
	PrototypeBindicateToggle.Set(TRUE);
		(* behaviour *)
	NEW(PrototypeBonClickHandler, NIL, NewString("OnClickHandler"), NewString("handler"));
		(* single images *)
	NEW(StringPrototype, NIL, NewString("BgDefault"), NewString("Default background bitmap")); StringPrototype.Set(NewString(""));
	NEW(PrototypeBimgDefaultName, StringPrototype, NIL, NIL); plButton.Add(PrototypeBimgDefaultName);
	NEW(StringPrototype, NIL, NewString("BgInactive"), NewString("Default disabled background bitmap")); StringPrototype.Set(NewString(""));
	NEW(PrototypeBimgInactiveName, StringPrototype, NIL, NIL); plButton.Add(PrototypeBimgInactiveName);
	NEW(StringPrototype, NIL, NewString("BgHover"), NewString("Mouseover background bitmap")); StringPrototype.Set(NewString(""));
	NEW(PrototypeBimgHoverName, StringPrototype, NIL, NIL); plButton.Add(PrototypeBimgHoverName);
	NEW(StringPrototype, NIL, NewString("BgPressed"), NewString("Pressed background bitmap")); StringPrototype.Set(NewString(""));
	NEW(PrototypeBimgPressedName, StringPrototype, NIL, NIL); plButton.Add(PrototypeBimgPressedName);
	NEW(StringPrototype, NIL, NewString("BgImage"), NewString("background bitmap")); StringPrototype.Set(NewString(""));
	NEW(PrototypeBimageName, StringPrototype, NIL, NIL); plButton.Add(PrototypeBimageName);
		(* presentation *)
	NEW(BooleanPrototype, NIL, NewString("UseBgBitmaps"), NewString("Is the button decorated by bitmaps or simple colors?")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeBUseBgImages, BooleanPrototype, NIL, NIL); plButton.Add(PrototypeBUseBgImages);
	NEW(PrototypeBIsHorizontal, NIL, NewString("IsHorizontal"), NewString("Specifies if the button is horizontal or vertical")); PrototypeBIsHorizontal.Set(TRUE);
	NEW(BooleanPrototype, NIL, NewString("RepeatMiddleImage"), NewString("If TRUE, the middle image of the button representation will be repeated, scaled if FALSE"));
	BooleanPrototype.Set(FALSE);
	NEW(PrototypeBRepeatMiddleImg, BooleanPrototype, NIL, NIL); plButton.Add(PrototypeBRepeatMiddleImg);
		(* button size *)
	NEW(RectanglePrototype, WMComponents.PrototypeBounds, NewString("Bounds"), NIL); RectanglePrototype.Set(WMRectangles.MakeRect(0, 0, 50, 20));
	NEW(PrototypeBBounds, RectanglePrototype, NewString("Bounds"), NIL); plButton.Add(PrototypeBBounds);
		(* background color *)
	NEW(ColorPrototype, NIL, NewString("ClDefault"), NewString("Default background color")); ColorPrototype.Set(1010C080H);
	NEW(PrototypeBclDefault, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclDefault);
	NEW(ColorPrototype, NIL, NewString("ClHover"), NewString("Mouseover background color")); ColorPrototype.Set(LONGINT(0EEEE00FFH));
	NEW(PrototypeBclHover, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclHover);
	NEW(ColorPrototype, NIL, NewString("ClPressed"), NewString("Pressed background color")); ColorPrototype.Set(LONGINT(0EEEE00FFH));
	NEW(PrototypeBclPressed, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclPressed);
	NEW(ColorPrototype, NIL, NewString("ClInactive"), NewString("Inactive background color")); ColorPrototype.Set(LONGINT(80808080H));
	NEW(PrototypeBclInactive, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclInactive);
		(* font color *)
	NEW(ColorPrototype, NIL, NewString("ClTextDefault"), NewString("Default text color")); ColorPrototype.Set(LONGINT(0FFFF00FFH));
	NEW(PrototypeBclTextDefault, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclTextDefault);
	NEW(ColorPrototype, NIL, NewString("ClTextHover"), NewString("Mouseover text color")); ColorPrototype.Set(00000FFFFH);
	NEW(PrototypeBclTextHover, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclTextHover);
	NEW(ColorPrototype, NIL, NewString("ClTextPressed"), NewString("Pressed text color")); ColorPrototype.Set(00000FFFFH);
	NEW(PrototypeBclTextPressed, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclTextPressed);
	NEW(ColorPrototype, NIL, NewString("ClTextInactive"), NewString("Inactive text color")); ColorPrototype.Set(0FFFFFF80H);
	NEW(PrototypeBclTextInactive, ColorPrototype, NIL, NIL); plButton.Add(PrototypeBclTextInactive);

		(* effect3D *)
	NEW(Int32Prototype, NIL, NewString("Effect3D"), NewString("Degree of 3d-effect. Zero for flat presentation")); Int32Prototype.Set(2);
	NEW(PrototypeBEffect3D, Int32Prototype, NIL, NIL); plButton.Add(PrototypeBEffect3D);
	(* 3 x 5 background images *)
	NEW(StringPrototype, NIL, NewString("BgLeftDefault"), NewString("Default background bitmap left")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgDefaultNameLeft, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgDefaultNameLeft);
	NEW(StringPrototype, NIL, NewString("BgRightDefault"), NewString("Default background bitmap right")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgDefaultNameRight, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgDefaultNameRight);
	NEW(StringPrototype, NIL, NewString("BgMiddleDefault"), NewString("Default background bitmap middle")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgDefaultNameMiddle, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgDefaultNameMiddle);
	NEW(StringPrototype, NIL, NewString("BgTopDefault"), NewString("Default background bitmap top")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgDefaultNameTop, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgDefaultNameTop);
	NEW(StringPrototype, NIL, NewString("BgBottomDefault"), NewString("Default background bitmap bottom")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgDefaultNameBottom, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgDefaultNameBottom);

	NEW(BooleanPrototype, NIL, NewString("UseDeco"), NewString("Is the button decorated by decoration?")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeUseDeco, BooleanPrototype, NIL, NIL); plButton.Add(PrototypeUseDeco);
	NEW(StringPrototype, NIL, NewString("DecoDefault"), NewString("Default background decoration name")); StringPrototype.Set(NewString(""));
	NEW(PrototypeDecoDefaultName, StringPrototype, NIL, NIL); plButton.Add(PrototypeDecoDefaultName);
	NEW(StringPrototype, NIL, NewString("DecoHover"), NewString("Hover background decoration name")); StringPrototype.Set(NewString(""));
	NEW(PrototypeDecoHoverName, StringPrototype, NIL, NIL); plButton.Add(PrototypeDecoHoverName);
	NEW(StringPrototype, NIL, NewString("DecoPressed"), NewString("Pressed background decoration name")); StringPrototype.Set(NewString(""));
	NEW(PrototypeDecoPressedName, StringPrototype, NIL, NIL); plButton.Add(PrototypeDecoPressedName);


	NEW(StringPrototype, NIL, NewString("BgLeftHover"), NewString("Mouseover background bitmap left")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgHoverNameLeft, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgHoverNameLeft);
	NEW(StringPrototype, NIL, NewString("BgRightHover"), NewString("Mouseover background bitmap right")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgHoverNameRight, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgHoverNameRight);
	NEW(StringPrototype, NIL, NewString("BgMiddleHover"), NewString("Mouseover background bitmap middle")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgHoverNameMiddle, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgHoverNameMiddle);
	NEW(StringPrototype, NIL, NewString("BgTopHover"), NewString("Mouseover background bitmap top")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgHoverNameTop, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgHoverNameTop);
	NEW(StringPrototype, NIL, NewString("BgBottomHover"), NewString("Mouseover background bitmap bottom")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgHoverNameBottom, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgHoverNameBottom);

	NEW(StringPrototype, NIL, NewString("BgLeftPressed"), NewString("Pressed background bitmap left")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgPressedNameLeft, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgPressedNameLeft);
	NEW(StringPrototype, NIL, NewString("BgRightPressed"), NewString("Pressed background bitmap right")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgPressedNameRight, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgPressedNameRight);
	NEW(StringPrototype, NIL, NewString("BgMiddlePressed"), NewString("Pressed background bitmap middle")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgPressedNameMiddle, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgPressedNameMiddle);
	NEW(StringPrototype, NIL, NewString("BgTopPressed"), NewString("Pressed background bitmap top")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgPressedNameTop, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgPressedNameTop);
	NEW(StringPrototype, NIL, NewString("BgBottomPressed"), NewString("Pressed background bitmap bottom")); StringPrototype.Set(NewString(""));
	NEW(PrototypeImgPressedNameBottom, StringPrototype, NIL, NIL); plButton.Add(PrototypeImgPressedNameBottom);
	NEW(PrototypeButtonAlignH, NIL, NewString("TextAlignH"), NewString("horizontal text alignment")); plButton.Add(PrototypeAlignH);
	PrototypeButtonAlignH.Set(WMGraphics.AlignCenter);
	NEW(PrototypeButtonAlignV, NIL, NewString("TextAlignV"), NewString("vertical text alignment")); plButton.Add(PrototypeAlignV);
	PrototypeButtonAlignV.Set(WMGraphics.AlignCenter);

	(* Scrollbar prototypes *)
	NEW(plScrollbar); WMComponents.propertyListList.Add("Scrollbar", plScrollbar);
	NEW(PrototypeSmin, NIL,  NewString("Min"), NewString("defines the scrollbar min position"));
	NEW(PrototypeSmax, NIL, NewString("Max"), NewString("defines the scrollbar max position"));
	PrototypeSmax.Set(100);
	NEW(PrototypeSpos, NIL, NewString("Pos"), NewString("defines the scrollbar position"));
	NEW(PrototypeSpageSize, NIL, NewString("PageSize"), NewString("defines the scrollbar page size"));
	PrototypeSpageSize.Set(20);
	NEW(PrototypeTrackerSize, NIL, NewString("TrackerSize"), NewString("defines the tracker size"));
	PrototypeTrackerSize.Set(20);
		(* scrollbar width *)
	NEW(Int32Prototype, NIL, NewString("Width"), NewString("defines the scrollbar width")); Int32Prototype.Set(14);
	NEW(PrototypeSWidth, Int32Prototype, NIL, NIL); plScrollbar.Add(PrototypeSWidth);

	NEW(PrototypeSvertical, NIL, NewString("Vertical"),	NewString("defines if the scrollbar is vertical"));
	PrototypeSvertical.Set(TRUE);
	NEW(Int32Prototype, NIL, NewString("MinTrackerSize"), NewString("")); Int32Prototype.Set(5);
	NEW(PrototypeSMinTrackerSize, Int32Prototype, NIL, NIL); plScrollbar.Add(PrototypeSMinTrackerSize);
			(* color *)
	NEW(ColorPrototype, NIL, NewString("ClDefault"), NewString("Default background color")); ColorPrototype.Set(000000077H);
 	NEW(PrototypeSClDefault, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClDefault);
	NEW(ColorPrototype, NIL, NewString("ClHover"), NewString("Mouseover background color")); ColorPrototype.Set(WMGraphics.Yellow);
 	NEW(PrototypeSClHover, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClHover);
	NEW(ColorPrototype, NIL, NewString("ClPressed"), NewString("Pressed background color")); ColorPrototype.Set(WMGraphics.Yellow);
 	NEW(PrototypeSClPressed, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClPressed);
	NEW(ColorPrototype, NIL, NewString("ClBtnDefault"), NewString("Default background color")); ColorPrototype.Set(1010C080H);
 	NEW(PrototypeSClBtnDefault, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClBtnDefault);
	NEW(ColorPrototype, NIL, NewString("ClBtnHover"), NewString("Mouseover background color")); ColorPrototype.Set(LONGINT(0EEEE00FFH));
 	NEW(PrototypeSClBtnHover, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClBtnHover);
	NEW(ColorPrototype, NIL, NewString("ClBtnPressed"), NewString("Pressed background color")); ColorPrototype.Set(LONGINT(0EEEE00FFH));
 	NEW(PrototypeSClBtnPressed, ColorPrototype, NIL, NIL); plScrollbar.Add(PrototypeSClBtnPressed);
 	NEW(PrototypeSEffect3D, NIL, NewString("Effect3D"), NewString("Degree of 3d-effect. Zero for flat presentation")); PrototypeSEffect3D.Set(2);
		(* background *)
	NEW(BooleanPrototype, NIL, NewString("UseBackgroundBitmaps"), NewString("Should background be decorated by bitmaps or simple color?")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeSUseBgBitmaps, BooleanPrototype, NIL, NIL);  plScrollbar.Add(PrototypeSUseBgBitmaps);
	NEW(BooleanPrototype, NIL, NewString("RepeatBgBitmaps"), NewString("Should background bitmap be repeated or streched?")); BooleanPrototype.Set(TRUE);
	NEW(PrototypeSRepeateBgBitmap, BooleanPrototype, NIL, NIL);  plScrollbar.Add(PrototypeSRepeateBgBitmap);
			(* bitmaps *)
	NEW(StringPrototype, NIL, NewString("HorizontalBgDefault"), NewString("Default background bitmap for the horizontal scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShBgDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShBgDefault);
	NEW(StringPrototype, NIL, NewString("HorizontalBgHover"), NewString("Hover background bitmap for the horizontal scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShBgHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShBgHover);
	NEW(StringPrototype, NIL, NewString("HorizontalBgPressed"), NewString("Pressed background bitmap for the horizontal scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShBgPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShBgPressed);
	NEW(StringPrototype, NIL, NewString("VerticalBgDefault"), NewString("Default background bitmap for the vertical scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvBgDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvBgDefault);
	NEW(StringPrototype, NIL, NewString("VerticalBgHover"), NewString("Hover background bitmap for the vertical scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvBgHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvBgHover);
	NEW(StringPrototype, NIL, NewString("VerticalBgPressed"), NewString("Pressed background bitmap for the vertical scrollbar")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvBgPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvBgPressed);
		(* trackers *)
	NEW(BooleanPrototype, NIL, NewString("UseTrackerBitmaps"), NewString("Should thumbs be decorated by bitmaps or simple color?")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeSUseTrackerImages, BooleanPrototype, NIL, NIL);  plScrollbar.Add(PrototypeSUseTrackerImages);
	NEW(BooleanPrototype, NIL, NewString("RepeatMiddleBitmaps"), NewString("Has the middle thumb bitmap to be repeated or streched?")); BooleanPrototype.Set(TRUE);
	NEW(PrototypeSRepeatMiddleBitmap, BooleanPrototype, NIL, NIL);  plScrollbar.Add(PrototypeSRepeatMiddleBitmap);
			(* horizontal*)
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerDefaultLeft"), NewString("Default background bitmap left of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerDefaultLeft, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerDefaultLeft);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerHoverLeft"), NewString("Mouseover background bitmap left of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerHoverLeft, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerHoverLeft);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerPressedLeft"), NewString("Pressed background bitmap left of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerPressedLeft, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerPressedLeft);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerDefaultMiddle"), NewString("Default background bitmap middle of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerDefaultMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerDefaultMiddle);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerHoverMiddle"), NewString("Mouseover background bitmap middle of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerHoverMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerHoverMiddle);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerPressedMiddle"), NewString("Pressed background bitmap middle of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerPressedMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerPressedMiddle);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerDefaultRight"), NewString("Default background bitmap right of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerDefaultRight, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerDefaultRight);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerHoverRight"), NewString("Mouseover background bitmap right of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerHoverRight, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerHoverRight);
	NEW(StringPrototype, NIL, NewString("HorizontalTrackerPressedRight"), NewString("Pressed background bitmap right of the horizontal thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeShTrackerPressedRight, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeShTrackerPressedRight);
			(* vertical *)
	NEW(StringPrototype, NIL, NewString("VerticalTrackerDefaultTop"), NewString("Default background bitmap top of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerDefaultTop, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerDefaultTop);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerHoverTop"), NewString("Mouseover background bitmap top of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerHoverTop, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerHoverTop);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerPressedTop"), NewString("Pressed background bitmap top of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerPressedTop, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerPressedTop);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerDefaultMiddle"), NewString("Default background bitmap middle of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerDefaultMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerDefaultMiddle);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerHoverMiddle"), NewString("Mouseover background bitmap middle of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerHoverMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerHoverMiddle);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerPressedMiddle"), NewString("Pressed background bitmap middle of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerPressedMiddle, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerPressedMiddle);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerDefaultBottom"), NewString("Default background bitmap bottom of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerDefaultBottom, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerDefaultBottom);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerHoverBottom"), NewString("Mouseover background bitmap bottom of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerHoverBottom, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerHoverBottom);
	NEW(StringPrototype, NIL, NewString("VerticalTrackerPressedBottom"), NewString("Pressed background bitmap bottom of the vertical thumb")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSvTrackerPressedBottom, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSvTrackerPressedBottom);
		(* arrows *)
	NEW(BooleanPrototype, NIL, NewString("UseArrowBitmaps"), NewString("Have the arrow-buttons to be decorated by bitmaps or simple colors")); BooleanPrototype.Set(FALSE);
	NEW(PrototypeSUseArrowImages, BooleanPrototype, NIL, NIL);  plScrollbar.Add(PrototypeSUseArrowImages);
 			(* left *)
 	NEW(StringPrototype, NIL, NewString("ArrowLeftDefault"), NewString("Default bitmap for the left-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowLeftDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowLeftDefault);
 	NEW(StringPrototype, NIL, NewString("ArrowLeftHover"), NewString("Mouseover bitmap for the left-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowLeftHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowLeftHover);
 	NEW(StringPrototype, NIL, NewString("ArrowLeftPressed"), NewString("Pressed bitmap for the left-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowLeftPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowLeftPressed);
			(* right *)
	NEW(StringPrototype, NIL, NewString("ArrowRightDefault"), NewString("Default bitmap for the right-arrow")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSArrowRightDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowRightDefault);
	NEW(StringPrototype, NIL, NewString("ArrowRightHover"), NewString("Mouseover bitmap for the right-arrow")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSArrowRightHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowRightHover);
	NEW(StringPrototype, NIL, NewString("ArrowRightPressed"), NewString("Pressed bitmap for the right-arrow")); StringPrototype.Set(NewString(""));
	NEW(PrototypeSArrowRightPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowRightPressed);
			(* up *)
 	NEW(StringPrototype, NIL, NewString("ArrowUpDefault"), NewString("Default bitmap for the up-arrow"));StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowUpDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowUpDefault);
 	NEW(StringPrototype, NIL, NewString("ArrowUpHover"), NewString("Mouseover bitmap for the up-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowUpHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowUpHover);
	NEW(StringPrototype, NIL, NewString("ArrowUpPressed"), NewString("Pressed bitmap for the up-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowUpPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowUpPressed);
			(* down *)
	NEW(StringPrototype, NIL, NewString("ArrowDownDefault"), NewString("Default bitmap for the down-arrow"));StringPrototype.Set(NewString(""));
	NEW(PrototypeSArrowDownDefault, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowDownDefault);
	NEW(StringPrototype, NIL, NewString("ArrowDownHover"), NewString("Mouseover bitmap for the down-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowDownHover, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowDownHover);
	NEW(StringPrototype, NIL, NewString("ArrowDownPressed"), NewString("Pressed bitmap for the down-arrow")); StringPrototype.Set(NewString(""));
 	NEW(PrototypeSArrowDownPressed, StringPrototype, NIL, NIL); plScrollbar.Add(PrototypeSArrowDownPressed);

	 (* Slider prototypes *)
	NEW(plSlider); WMComponents.propertyListList.Add("Slider", plSlider);
	NEW(PrototypeSlhTrackerDefault, NIL, NewString("HTrackerDefaultName"), NewString("Default tracker image for the horizontal slider"));
	NEW(PrototypeSlhTrackerHover, NIL, NewString("HTrackerHoverName"), NewString("Hover tracker image for the horizontal slider"));
	NEW(PrototypeSlhTrackerPressed, NIL, NewString("HTrackerPressedName"), NewString("Pressed tracker image for the horizontal slider"));
	NEW(PrototypeSlvTrackerDefault, NIL, NewString("VTrackerDefaultName"), NewString("Default tracker image for the vertical slider"));
	NEW(PrototypeSlvTrackerHover, NIL, NewString("VTrackerHoverName"), NewString("Hover tracker image for the vertical slider"));
	NEW(PrototypeSlvTrackerPressed, NIL, NewString("VTrackerPressedName"), NewString("Pressed tracker image for the vertical slider"));

	NEW(PrototypeSlhBgDefault, NIL, NewString("HBgDefaultName"), NewString("Default background image for the horizontal slider"));
	NEW(PrototypelShBgHover, NIL, NewString("HBgHoverName"), NewString("Hover background image for the horizontal slider"));
	NEW(PrototypeSlhBgPressed, NIL, NewString("HBgPressedName"), NewString("Pressed background image for the horizontal slider"));
	NEW(PrototypeSlvBgDefault, NIL, NewString("VBgDefaultName"), NewString("Default background image for the vertical slider"));
	NEW(PrototypeSlvBgHover, NIL, NewString("VBgHoverName"), NewString("Hover background image for the vertical slider"));
	NEW(PrototypeSlvBgPressed, NIL, NewString("VBgPressedName"), NewString("Pressed background image for the vertical slider"));

	NEW(PrototypeSlUseTrackerImages, NIL, NewString("UseTrackerImages"), NewString("Use images for the tracker of the slider?"));
	NEW(PrototypeSlUseBgBitmaps, NIL, NewString("UseBgBitmaps"), NewString("Use backgroun images for slider?"));
	NEW(PrototypeSlRepeatBgBitmap, NIL, NewString("RepeatBgBitamp"), NewString("Repeat middle bitmap of background image?"));

	NEW(PrototypeSlClDefault, NIL, NewString("ClDefault"), NewString("Default color of slider"));
	PrototypeSlClDefault.Set(0);
	NEW(PrototypeSlClHover, NIL, NewString("ClHover"), NewString("Hover color of slider"));
	PrototypeSlClHover.Set(0);
	NEW(PrototypeSlClPressed, NIL, NewString("ClPressed"), NewString("Pressed color of slider"));
	PrototypeSlClPressed.Set(0);
	NEW(PrototypeSlClBar, NIL, NewString("ClBar"), NewString("Color of slider bar"));
	PrototypeSlClBar.Set(0CCCCCCCCH);

	NEW(PrototypeSlvertical, NIL, NewString("Vertical"),NewString("defines if the slider is vertical"));
	PrototypeSlvertical.Set(TRUE);
	NEW(PrototypeSlmin, NIL, NewString("Min"), NewString("defines the slider min position"));
	PrototypeSlmin.Set(0);
	NEW(PrototypeSlmax, NIL, NewString("Max"), NewString("defines the slider max position"));
	PrototypeSlmax.Set(100);
	NEW(PrototypeSlpos, NIL, NewString("Pos"), NewString("defines the slider position"));
	NEW(PrototypeSlpageSize, NIL, NewString("PageSize"),NewString("defines the slider page size"));
	PrototypeSlpageSize.Set(20);

 	(* Resizer *)
 	NEW(plResizer);	WMComponents.propertyListList.Add("Resizer", plResizer);
 	NEW(ColorPrototype, NIL, NewString("ClDefault"), NewString("Default Color")); ColorPrototype.Set(WMGraphics.White);
 	NEW(PrototypeRclDefault, ColorPrototype, NIL, NIL); plResizer.Add(PrototypeRclDefault);
	NEW(BooleanPrototype, NIL, NewString("IsFlat"), NewString("Is the resizer flat or 3d?")); BooleanPrototype.Set(FALSE);
 	NEW(PrototypeRisFlat, BooleanPrototype, NIL, NIL); plResizer.Add(PrototypeRisFlat);
 	NEW(RectanglePrototype, NIL, NewString("Bounds"), NewString("Default width and height")); RectanglePrototype.SetWidth(5); RectanglePrototype.SetHeight(5);
 	NEW(PrototypeRBounds, RectanglePrototype, NIL, NIL); plResizer.Add(PrototypeRBounds);
 	(* Checkbox *)
	NEW(plCheckbox); WMComponents.propertyListList.Add("Checkbox", plCheckbox);

	NEW(ProtCBCaption, NIL, NewString("Caption"), NewString("caption text")); plCheckbox.Add(ProtCBCaption);
	ProtCBCaption.SetAOC("");
	NEW(ProtCBCaptionPos, NIL, NewString("CaptionPos"), NewString("caption position"));  plCheckbox.Add(ProtCBCaptionPos);
	ProtCBCaptionPos.Set(Right);
		(* Checkbox size *)
	NEW(RectanglePrototype, WMComponents.PrototypeBounds, NewString("Bounds"), NIL); RectanglePrototype.Set(WMRectangles.MakeRect(0, 0, 100, 20));
	NEW(ProtCBBounds, RectanglePrototype, NewString("Bounds"), NIL); plCheckbox.Add(ProtCBBounds);
		(* Checkbox state *)
	NEW(ProtCBHasThreeStates, NIL, NewString("HasThreeStates"), NewString("enables three state checkbox")); plCheckbox.Add(ProtCBHasThreeStates);
	ProtCBHasThreeStates.Set(FALSE);
	NEW(ProtCBState, NIL, NewString("State"), NewString("current state")); plCheckbox.Add(ProtCBState);
	ProtCBState.Set(Unchecked);
	NEW(PrototypeCBonClickHandler, NIL, NewString("onClickHandler"), NewString("onClickHandler")); plCheckbox.Add(PrototypeCBonClickHandler);
	
			(* background color *)
	NEW(ColorPrototype, NIL, NewString("ClBack"), NewString("Checkbox Background Color")); ColorPrototype.Set(LONGINT(0FFFFFF80H));
	NEW(ProtCBclBack, ColorPrototype, NIL, NIL); plCheckbox.Add(ProtCBclBack);
	NEW(ColorPrototype, NIL, NewString("ClCheck"), NewString("Checkbox Check Color")); ColorPrototype.Set(0000000FFH);
	NEW(ProtCBclCheck, ColorPrototype, NIL, NIL); plCheckbox.Add(ProtCBclCheck);
	NEW(ColorPrototype, NIL, NewString("ClDefault"), NewString("Checkbox 3rd state Check Color")); ColorPrototype.Set(0555555FFH);
	NEW(ProtCBclDefault, ColorPrototype, NIL, NIL); plCheckbox.Add(ProtCBclDefault);
	NEW(ColorPrototype, NIL, NewString("ClInactive"), NewString("Checkbox Inactive Color")); ColorPrototype.Set(LONGINT(088888880H));
	NEW(ProtCBclInactive, ColorPrototype, NIL, NIL); plCheckbox.Add(ProtCBclInactive);
		(* presentation *)
	NEW(BooleanPrototype, NIL, NewString("UseBitmaps"), NewString("Have the Checkbox decorated by Images")); BooleanPrototype.Set(FALSE);
	NEW(ProtCBUseImages, BooleanPrototype, NIL, NIL); plCheckbox.Add(ProtCBUseImages);
	NEW(BooleanPrototype, NIL, NewString("ScaleBitmaps"), NewString("Have the Images scaled with the component siye")); BooleanPrototype.Set(FALSE);
	NEW(ProtCBScaleImages, BooleanPrototype, NIL, NIL); plCheckbox.Add(ProtCBScaleImages);
		(* Checkbox images *)
	NEW(StringPrototype, NIL, NewString("ImgUnchecked"), NewString("Unchecked Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgUncheckedN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgUncheckedN);
	NEW(StringPrototype, NIL, NewString("ImgChecked"), NewString("Checked Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgCheckedN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgCheckedN);
	NEW(StringPrototype, NIL, NewString("ImgDefault"), NewString("3rd state Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgDefaultN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgDefaultN);
	NEW(StringPrototype, NIL, NewString("ImgUncheckedInactive"), NewString("Unchecked Inactive Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgUncheckedInactiveN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgUncheckedInactiveN);
	NEW(StringPrototype, NIL, NewString("ImgCheckedInactive"), NewString("Checked Inactive Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgCheckedInactiveN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgCheckedInactiveN);
	NEW(StringPrototype, NIL, NewString("ImgDefaultInactive"), NewString("3rd state Inactive Image")); StringPrototype.SetAOC("");
	NEW(ProtCBImgDefaultInactiveN, StringPrototype, NIL, NIL); plCheckbox.Add(ProtCBImgDefaultInactiveN);
	(* Group Panel *)
	NEW(plGroupPanel); WMComponents.propertyListList.Add("GroupPanel", plGroupPanel);
	NEW(ProtGPCaption, NIL, NewString("Caption"), NewString("caption text")); plGroupPanel.Add(ProtGPCaption);
	NEW(ProtGPTextColor, NIL, NewString("TextColor"), NewString("Text color of group panel caption")); plGroupPanel.Add(ProtGPTextColor);
	(* Image *)
	NEW(PrototypeImageName, NIL, NewString("ImageName"), NewString("Name of image to be displayed"));
	PrototypeImageName.Set(NIL);
	NEW(PrototypeScaleImage, NIL, NewString("ScaleImage"), NewString("Scale image to fit size of component?"));
	PrototypeScaleImage.Set(TRUE);
	(* Image Panel *)
	NEW(plImagePanel); WMComponents.propertyListList.Add("ImagePanel", plImagePanel);
	NEW(ProtoIpImgName, NIL, NewString("Image"), NewString("Name of image to be displayed")); plImagePanel.Add(ProtoIpImgName);
	NEW(PrototypeBlinking, NIL, NewString("Blinking"), NewString("Toggle Display of Component")); PrototypeBlinking.Set(FALSE);
	NEW(PrototypeHorizontalFit, NIL, Strings.NewString("HorFit"), Strings.NewString("horiztonal fit")); PrototypeHorizontalFit.Set(TRUE);
	NEW(PrototypeTextBorder, NIL, Strings.NewString("TextBorder"), Strings.NewString("inner text border")); PrototypeTextBorder.Set(1);
	WMComponents.propertyListList.UpdateStyle
END InitPrototypes;

(**  Generators  *********************************************************************************)

PROCEDURE GenTimer*() : XML.Element;
VAR timer : Timer;
BEGIN NEW(timer); RETURN timer
END GenTimer;

PROCEDURE GenSystemCommand*() : XML.Element;
VAR systemCommand : SystemCommand;
BEGIN NEW(systemCommand); RETURN systemCommand
END GenSystemCommand;

PROCEDURE GenEvent*() : XML.Element;
VAR event : Event;
BEGIN NEW(event); RETURN event
END GenEvent;

PROCEDURE GenPanel*() : XML.Element;
VAR panel : Panel;
BEGIN NEW(panel); RETURN panel
END GenPanel;

(*
PROCEDURE GenDecoratorPanel*() : XML.Element;
VAR panel : DecoratorPanel;
BEGIN NEW(panel); RETURN panel
END GenDecoratorPanel;
*)

PROCEDURE GenLabel*() : XML.Element;
VAR label : Label;
BEGIN NEW(label); RETURN label
END GenLabel;

PROCEDURE GenButton*() : XML.Element;
VAR button : Button;
BEGIN NEW(button); RETURN button
END GenButton;

PROCEDURE GenScrollbar*() : XML.Element;
VAR scrollbar : Scrollbar;
BEGIN NEW(scrollbar); RETURN scrollbar
END GenScrollbar;

PROCEDURE GenSlider*() : XML.Element;
VAR slider : Slider;
BEGIN NEW(slider); RETURN slider;
END GenSlider;

PROCEDURE GenResizer*() : XML.Element;
VAR resizer : Resizer;
BEGIN NEW(resizer); RETURN resizer
END GenResizer;

PROCEDURE GenCheckbox*() : XML.Element;
VAR checkbox : Checkbox;
BEGIN NEW(checkbox); RETURN checkbox
END GenCheckbox;

PROCEDURE GenGroupPanel*() : XML.Element;
VAR groupPanel : GroupPanel;
BEGIN NEW(groupPanel); RETURN groupPanel
END GenGroupPanel;

PROCEDURE GenImage*() : XML.Element;
VAR image : Image;
BEGIN
	NEW(image); RETURN image;
END GenImage;

PROCEDURE GenImagePanel*() : XML.Element;
VAR ip : ImagePanel;
BEGIN NEW(ip); RETURN ip
END GenImagePanel;

(**********************************************************************************************)

PROCEDURE FindLabel*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : Label;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS Label) THEN
		RETURN c (Label);
	ELSE
		RETURN NIL;
	END;
END FindLabel;

PROCEDURE FindButton*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : Button;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS Button) THEN
		RETURN c (Button);
	ELSE
		RETURN NIL;
	END;
END FindButton;

PROCEDURE FindCheckbox*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : Checkbox;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS Checkbox) THEN
		RETURN c (Checkbox);
	ELSE
		RETURN NIL;
	END;
END FindCheckbox;

PROCEDURE NewString*(CONST x : ARRAY OF CHAR) : String;
VAR t : String;
BEGIN
	NEW(t, LEN(x)); COPY(x, t^); RETURN t
END NewString;

PROCEDURE Cleanup;
BEGIN
	blinker.Finalize;
END Cleanup;

BEGIN
	NEW(blinker);
	Modules.InstallTermHandler(Cleanup);
	manager := WMWindowManager.GetDefaultManager();
	InitStrings;
	InitPrototypes;
END WMStandardComponents.

Release.Rebuild WinAos WMStandardComponents.Mod ~
