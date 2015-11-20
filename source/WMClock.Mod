MODULE WMClock; (** AUTHOR "TF/staubesv"; PURPOSE "Clock components & clock application"; *)

IMPORT
	Modules, Kernel, Math, Dates, Strings, Locks, XML, Raster, WMRasterScale, WMRectangles, WMGraphics, WMGraphicUtilities,
	WMWindowManager, WMPopups, WMRestorable, WMMessages, WMComponents, WMProperties;

CONST
	(** Clock.viewMode property *)
	ViewModeStandard* = 0;
	ViewModeDateTime* = 1;
	ViewModeDayOfWeek* = 2;
	ViewModeAnalog* = 3;
	ViewModeFormatted*= 4;

	WindowWidth = 150; WindowHeight = 50;

TYPE

	ContextMenuPar = OBJECT
	VAR
		mode : LONGINT;

		PROCEDURE &New*(m : LONGINT);
		BEGIN
			mode := m;
		END New;

	END ContextMenuPar;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT(WMComponents.FormWindow);
	VAR
		clock : Clock;
		imageNameAnalog : Strings.String;
		contextMenu : WMPopups.Popup;
		dragging, resizing : BOOLEAN;
		lastX, lastY : LONGINT;

		PROCEDURE &New*(context : WMRestorable.Context; flags : SET);
		VAR configuration : WMRestorable.XmlElement; viewMode, color : LONGINT;
		BEGIN
			IncCount;
			IF (context # NIL) THEN
				Init(context.r - context.l, context.b - context.t, TRUE);
			ELSE
				Init(WindowWidth, WindowHeight, TRUE);
			END;

			NEW(clock);
			clock.alignment.Set(WMComponents.AlignClient);
			imageNameAnalog := clock.imageName.Get();
			IF (clock.viewMode.Get() # ViewModeAnalog) THEN clock.imageName.Set(NIL); END;
			SetContent(clock);
			SetTitle(Strings.NewString("Clock"));

			IF (context # NIL) THEN
				configuration := WMRestorable.GetElement(context, "Configuration");
				IF (configuration # NIL) THEN
					WMRestorable.LoadLongint(configuration, "color", color); clock.color.Set(color);
					WMRestorable.LoadLongint(configuration, "viewMode", viewMode); clock.viewMode.Set(viewMode);
				END;
				WMRestorable.AddByContext(SELF, context);
			ELSE
				IF (WMWindowManager.FlagNavigation IN flags) THEN
					WMWindowManager.ExtAddViewBoundWindow(SELF, 50, 50, NIL, flags);
				ELSE
					WMWindowManager.ExtAddWindow(SELF, 50, 50, flags)
				END;
			END;

		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE HandleClose(sender, par: ANY);
		VAR manager : WMWindowManager.WindowManager;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			Close;
		END HandleClose;

		PROCEDURE HandleToggleColor(sender, data: ANY);
		BEGIN
			IF (clock.color.Get() = 0FFH) THEN clock.color.Set(LONGINT(0FFFFFFFFH)) ELSE clock.color.Set(0FFH) END;
		END HandleToggleColor;

		PROCEDURE HandleToggleView(sender, par: ANY);
		VAR manager : WMWindowManager.WindowManager; viewMode : LONGINT;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			IF (par # NIL) & (par IS ContextMenuPar) THEN
				viewMode := par(ContextMenuPar).mode;
				IF (clock.viewMode.Get() # viewMode) THEN
					IF (par(ContextMenuPar).mode = ViewModeAnalog) THEN
						clock.imageName.Set(imageNameAnalog);
					ELSE
						clock.imageName.Set(NIL);
					END;
					clock.viewMode.Set(par(ContextMenuPar).mode);
				END;
			ELSE
				clock.viewMode.Set(ViewModeStandard);
				clock.imageName.Set(NIL);
			END
		END HandleToggleView;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		BEGIN
			lastX := bounds.l + x; lastY:=bounds.t + y;
			IF keys = {0} THEN
				dragging := TRUE
			ELSIF keys = {1,2} THEN
				dragging := FALSE;
				resizing := TRUE;
			ELSIF keys = {2} THEN
				NEW(contextMenu);
				contextMenu.Add("Close", HandleClose);
				contextMenu.AddParButton("Time", HandleToggleView, contextMenuParStandard);
				contextMenu.AddParButton("Date", HandleToggleView, contextMenuParDateTime);
				contextMenu.AddParButton("Day of Week", HandleToggleView, contextMenuParDayOfWeek);
				contextMenu.AddParButton("Analog", HandleToggleView, contextMenuParAnalog);
				contextMenu.AddParButton("Toggle Color", HandleToggleColor, NIL);
				contextMenu.Popup(bounds.l + x, bounds.t + y)
			END
		END PointerDown;

		PROCEDURE PointerMove(x,y:LONGINT; keys:SET);
		VAR dx, dy, width, height : LONGINT;
		BEGIN
			IF dragging OR resizing THEN
				x := bounds.l + x; y := bounds.t + y; dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN
					IF dragging THEN
						manager.SetWindowPos(SELF, bounds.l + dx, bounds.t + dy);
					ELSE
						width := GetWidth();
						height := GetHeight();
						width := Strings.Max(10, width + dx);
						height := Strings.Max(10, height + dy);
						manager.SetWindowSize(SELF, width, height);
					END;
				END;
			END;
		END PointerMove;

		PROCEDURE PointerUp(x, y:LONGINT; keys:SET);
		BEGIN
			dragging := FALSE;
			IF (keys # {1,2}) THEN
				IF resizing THEN
					resizing := FALSE;
					Resized(GetWidth(), GetHeight());
				END;
			END;
		END PointerUp;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN
					Close;
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					WMRestorable.StoreBoolean(configuration, "stayOnTop", WMWindowManager.FlagStayOnTop IN flags);
					WMRestorable.StoreBoolean(configuration, "navigation", WMWindowManager.FlagNavigation IN flags);
					WMRestorable.StoreLongint(configuration, "color", clock.color.Get());
					WMRestorable.StoreLongint(configuration, "viewMode", clock.viewMode.Get());
					x.ext(WMRestorable.Storage).Add("WMClock", "WMClock.Restore", SELF, configuration);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

TYPE

	Clock* = OBJECT(WMComponents.VisualComponent)
	VAR
		viewMode- : WMProperties.Int32Property;
		color- : WMProperties.ColorProperty;

		(** background image filename *)
		imageName- : WMProperties.StringProperty;

		(** time offset in hours *)
		timeOffset- : WMProperties.Int32Property;

		(** hand lengths in percent of component width/height *)
		secondHandLength-, minuteHandLength-, hourHandLength- : WMProperties.Int32Property;

		(** colors of hands *)
		secondHandColor-, minuteHandColor-, hourHandColor- : WMProperties.ColorProperty;

		(* format *)
		format-: WMProperties.StringProperty;

		currentTime : Dates.DateTime;
		lock : Locks.Lock; (* protects currentTime *)

		str : Strings.String;
		centerX, centerY : LONGINT;

		image : WMGraphics.Image;
		updateInterval : LONGINT;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrClock);
			SetGenerator("WMClock.GenClock");
			NEW(imageName, PrototypeImageName, NIL, NIL); properties.Add(imageName);
			NEW(timeOffset, PrototypeTimeOffset, NIL, NIL); properties.Add(timeOffset);
			NEW(viewMode, PrototypeViewMode, NIL, NIL); properties.Add(viewMode);
			NEW(color, PrototypeColor, NIL, NIL); properties.Add(color);
			NEW(secondHandLength, PrototypeSecondHandLength, NIL, NIL); properties.Add(secondHandLength);
			NEW(minuteHandLength, PrototypeMinuteHandLength, NIL, NIL); properties.Add(minuteHandLength);
			NEW(hourHandLength, PrototypeHourHandLength, NIL, NIL); properties.Add(hourHandLength);
			NEW(secondHandColor, PrototypeSecondHandColor, NIL, NIL); properties.Add(secondHandColor);
			NEW(minuteHandColor, PrototypeMinuteHandColor, NIL, NIL); properties.Add(minuteHandColor);
			NEW(hourHandColor, PrototypeHourHandColor, NIL, NIL); properties.Add(hourHandColor);
			NEW(format, PrototypeFormat, NIL, NIL); properties.Add(format);
			NEW(lock);
			NEW(str, 32);
			image := NIL;
			updateInterval := 500;
			alive := TRUE; dead := FALSE;
			NEW(timer);
			SetFont(WMGraphics.GetFont("Oberon", 24, {WMGraphics.FontBold}));
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		VAR vmValue : LONGINT;
		BEGIN
			IF (property = viewMode) THEN
				vmValue := viewMode.Get();
				IF vmValue = ViewModeStandard THEN
					format.SetAOC("hh:nn:ss");
				ELSIF vmValue = ViewModeDateTime THEN
					format.SetAOC("dd.mm.yy");
				ELSIF vmValue = ViewModeDayOfWeek THEN
					format.SetAOC("www dd.");
				END;
				timer.Wakeup;
			ELSIF (property = color) THEN
				timer.Wakeup;
			ELSIF (property = imageName) THEN
				RecacheProperties;
				timer.Wakeup;
			ELSIF (property = bounds) THEN
				PropertyChanged^(sender, property);
				RecacheProperties;
				timer.Wakeup;
			ELSIF (property = timeOffset) THEN
				timer.Wakeup;
			ELSIF (property = secondHandLength) OR (property = minuteHandLength) OR (property = hourHandLength) OR
				(property = secondHandColor) OR (property = minuteHandColor) OR (property = hourHandColor) THEN
				timer.Wakeup;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		VAR string : Strings.String; newImage, resizedImage : WMGraphics.Image; vmValue : LONGINT;
		BEGIN
			RecacheProperties^;
			vmValue := viewMode.Get();
			IF vmValue = ViewModeStandard THEN
				format.SetAOC("hh:nn:ss");
			ELSIF vmValue = ViewModeDateTime THEN
				format.SetAOC("dd.mm.yy");
			ELSIF vmValue = ViewModeDayOfWeek THEN
				format.SetAOC("www dd.");
			END;
			newImage := NIL;
			string := imageName.Get();
			IF (string # NIL) THEN
				newImage := WMGraphics.LoadImage(string^, TRUE);
				IF (newImage # NIL) THEN
					IF (bounds.GetWidth() # newImage.width) OR (bounds.GetHeight() # newImage.height) THEN
						NEW(resizedImage);
						Raster.Create(resizedImage, bounds.GetWidth(), bounds.GetHeight(), Raster.BGRA8888);
						WMRasterScale.Scale(
							newImage, WMRectangles.MakeRect(0, 0, newImage.width, newImage.height),
							resizedImage, WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
							WMRectangles.MakeRect(0, 0, resizedImage.width, resizedImage.height),
							WMRasterScale.ModeCopy, WMRasterScale.ScaleBilinear);
						newImage := resizedImage;
					END;
				END;
			END;
			image := newImage;
			centerX := ENTIER(bounds.GetWidth() / 2 + 0.5);
			centerY := ENTIER(bounds.GetHeight() / 2 + 0.5);
		END RecacheProperties;

		PROCEDURE DrawHands(canvas : WMGraphics.Canvas; time : Dates.DateTime);

			PROCEDURE DrawLine(handLengthInPercent : LONGINT; color : LONGINT; angle : REAL);
			VAR deltaX, deltaY : LONGINT; radiants : REAL; lengthX, lengthY : LONGINT;
			BEGIN
				lengthX := handLengthInPercent * bounds.GetWidth() DIV 2 DIV 100;
				lengthY := handLengthInPercent * bounds.GetHeight() DIV 2 DIV 100;
				radiants := (angle / 360) * 2*Math.pi;
				deltaX := ENTIER(lengthX * Math.sin(radiants) + 0.5);
				deltaY := ENTIER(lengthY * Math.cos(radiants) + 0.5);
				canvas.Line(centerX, centerY, centerX + deltaX, centerY - deltaY, color, WMGraphics.ModeSrcOverDst);
			END DrawLine;

		BEGIN
			IF (hourHandLength.Get() > 0) THEN
				time.hour := time.hour MOD 12;
				DrawLine(hourHandLength.Get(), hourHandColor.Get(), (time.hour + time.minute/60) * (360 DIV 12));
			END;
			IF (minuteHandLength.Get() > 0) THEN
				DrawLine(minuteHandLength.Get(), minuteHandColor.Get(), (time.minute + time.second/60) * (360 DIV 60));
			END;
			IF (secondHandLength.Get() > 0) THEN
				DrawLine(secondHandLength.Get(), secondHandColor.Get(), time.second  * (360 DIV 60));
			END;
		END DrawHands;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR time : Dates.DateTime; formatString: Strings.String;
		BEGIN
			DrawBackground^(canvas);
			lock.Acquire;
			time := currentTime;
			lock.Release;
			IF image # NIL THEN
				canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst);
			END;
			IF (viewMode.Get() = ViewModeAnalog) THEN
				DrawHands(canvas, time);
			ELSE
				formatString := format.Get();
				Strings.FormatDateTime(formatString^, time, str^);
				canvas.SetColor(color.Get());
				IF (image = NIL) THEN
					(*WMGraphicUtilities.DrawRect(canvas, GetClientRect(), color.Get(), WMGraphics.ModeCopy);*)
				END;
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, str^)
			END;
		END DrawBackground;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Finalize;

	BEGIN {ACTIVE}
		WHILE alive DO
			lock.Acquire;
			currentTime := Dates.Now();
			currentTime.hour := (currentTime.hour + timeOffset.Get());
			lock.Release;
			Invalidate;
			timer.Sleep(updateInterval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Clock;

VAR
	nofWindows : LONGINT;

	StrClock : Strings.String;

	PrototypeViewMode : WMProperties.Int32Property;
	PrototypeColor : WMProperties.ColorProperty;

	PrototypeImageName : WMProperties.StringProperty;
	PrototypeSecondHandLength, PrototypeMinuteHandLength, PrototypeHourHandLength : WMProperties.Int32Property;
	PrototypeSecondHandColor, PrototypeMinuteHandColor, PrototypeHourHandColor : WMProperties.ColorProperty;
	PrototypeTimeOffset, PrototypeUpdateInterval : WMProperties.Int32Property;
	PrototypeFormat: WMProperties.StringProperty;

	contextMenuParStandard, contextMenuParDateTime, contextMenuParDayOfWeek, contextMenuParAnalog : ContextMenuPar;

PROCEDURE Open*;
VAR window : Window;
BEGIN
	NEW(window, NIL, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagNavigation, WMWindowManager.FlagHidden});
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context, {});
END Restore;

PROCEDURE GenClock*() : XML.Element;
VAR clock : Clock;
BEGIN
	NEW(clock); RETURN clock;
END GenClock;

PROCEDURE InitStrings;
BEGIN
	StrClock := Strings.NewString("Clock");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	(* DigitalClock *)
	NEW(PrototypeColor, NIL, Strings.NewString("Color"), Strings.NewString("toggle clock color"));
	PrototypeColor.Set(0FFH);
	NEW(PrototypeViewMode, NIL, Strings.NewString("ViewMode"),	Strings.NewString("select view mode: time=0, date=1, dayOfWeek=2, analog=3, formatted=4"));
	PrototypeViewMode.Set(ViewModeStandard);

	(* AnalogClock *)
	NEW(PrototypeImageName, NIL, Strings.NewString("ImageName"), Strings.NewString("Clock face image name"));
	PrototypeImageName.SetAOC("WMClockImages.tar://roman_numeral_wall_clock.png");
	NEW(PrototypeTimeOffset, NIL, Strings.NewString("TimeOffset"), Strings.NewString("Time offset in hours"));
	PrototypeTimeOffset.Set(0);
	NEW(PrototypeSecondHandLength, NIL, Strings.NewString("SecondHandLength"), Strings.NewString("Length of second hand in percent of radius"));
	PrototypeSecondHandLength.Set(90);
	NEW(PrototypeMinuteHandLength, NIL, Strings.NewString("MinuteHandLength"), Strings.NewString("Length of minute hand in percent of radius"));
	PrototypeMinuteHandLength.Set(80);
	NEW(PrototypeHourHandLength, NIL, Strings.NewString("HourHandLength"), Strings.NewString("Length of hour hand in percent of radius"));
	PrototypeHourHandLength.Set(60);
	NEW(PrototypeSecondHandColor, NIL, Strings.NewString("SecondHandColor"), Strings.NewString("Color of second hand"));
	PrototypeSecondHandColor.Set(WMGraphics.Red);
	NEW(PrototypeMinuteHandColor, NIL, Strings.NewString("MinuteHandColor"), Strings.NewString("Color of minute hand"));
	PrototypeMinuteHandColor.Set(WMGraphics.Black);
	NEW(PrototypeHourHandColor, NIL, Strings.NewString("HourHandColor"), Strings.NewString("Color of hour hand"));
	PrototypeHourHandColor.Set(WMGraphics.Black);
	NEW(PrototypeUpdateInterval, NIL, Strings.NewString("UpdateInterval"), Strings.NewString("Redraw rate"));
	PrototypeUpdateInterval.Set(500);
	NEW(PrototypeFormat, NIL, Strings.NewString("Format"), Strings.NewString("Textual Format (yy, mm, dd, www, hh, nn, ss)"));
	PrototypeFormat.Set(Strings.NewString("hh:nn:ss"));
END InitPrototypes;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	nofWindows := 0;
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
	NEW(contextMenuParStandard, ViewModeStandard);
	NEW(contextMenuParDateTime, ViewModeDateTime);
	NEW(contextMenuParDayOfWeek, ViewModeDayOfWeek);
	NEW(contextMenuParAnalog, ViewModeAnalog);
END WMClock.

SystemTools.Free WMClock~

WMClock.Open ~
