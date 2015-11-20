MODULE WMPieMenu; (** AUTHOR "TF"; PURPOSE "Pie Menu"; *)

IMPORT
	Strings, WMMessages, WMEvents, WMWindowManager, WMComponents, WMGraphics, WMProperties;

CONST
	MenuPoints = 8;
	InnerRadius = 15; OuterRadius = 84;

TYPE
	String = Strings.String;

	PieMenu = OBJECT(WMComponents.VisualComponent)
	VAR
		lastX, lastY : LONGINT;
		dir : ARRAY 4 * MenuPoints OF RECORD x, y : LONGINT END;
		clDefault, clHover, clShadow, clLine : WMProperties.ColorProperty;
		useBgBitmap : WMProperties.BooleanProperty;
		bgBitmapName : WMProperties.StringProperty;
		bgBitmap : WMGraphics.Image;
		shadow: WMProperties.Int32Property;
		dx, dy : LONGINT;
		dirNr : LONGINT;
		on0, on1, on2, on3, closeIt : WMEvents.EventSource;
		images : ARRAY 4 OF WMGraphics.Image;
		texts : ARRAY 4 OF Strings.String;
		enabled, hover : SET;
		sent : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;

			NEW(on0, SELF, NIL, NIL, NIL);
			NEW(on1, SELF, NIL, NIL, NIL);
			NEW(on2, SELF, NIL, NIL, NIL);
			NEW(on3, SELF, NIL, NIL, NIL);
			NEW(closeIt, SELF, NIL, NIL, NIL);
			dir[0].x := 181; dir[0].y := -182;
			dir[1].x := 212; dir[1].y := -143;
			dir[2].x := 236; dir[2].y := -98;
			dir[3].x := 251; dir[3].y := -50;
			dir[4].x := 256; dir[4].y := 0;
			dir[5].x := 251; dir[5].y := 49;
			dir[6].x := 236; dir[6].y := 97;
			dir[7].x := 212; dir[7].y := 142;
			dir[8].x := 181; dir[8].y := 181;
			dir[9].x := 142; dir[9].y := 212;
			dir[10].x := 97; dir[10].y := 236;
			dir[11].x := 49; dir[11].y := 251;
			dir[12].x := -1; dir[12].y := 255;
			dir[13].x := -50; dir[13].y := 251;
			dir[14].x := -98; dir[14].y := 236;
			dir[15].x := -143; dir[15].y := 212;
			dir[16].x := -182; dir[16].y := 181;
			dir[17].x := -213; dir[17].y := 142;
			dir[18].x := -237; dir[18].y := 97;
			dir[19].x := -252; dir[19].y := 49;
			dir[20].x := -256; dir[20].y := -1;
			dir[21].x := -252; dir[21].y := -50;
			dir[22].x := -237; dir[22].y := -98;
			dir[23].x := -213; dir[23].y := -143;
			dir[24].x := -182; dir[24].y := -182;
			dir[25].x := -143; dir[25].y := -213;
			dir[26].x := -98; dir[26].y := -237;
			dir[27].x := -50; dir[27].y := -252;
			dir[28].x := 0; dir[28].y := -256;
			dir[29].x := 49; dir[29].y := -252;
			dir[30].x := 97; dir[30].y := -237;
			dir[31].x := 142; dir[31].y := -213;

			NEW(clDefault, ProtoPmClDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clHover, ProtoPmClHover, NIL, NIL); properties.Add(clHover);
			NEW(clShadow, ProtoPmClShadow, NIL, NIL); properties.Add(clShadow);
			NEW(clLine, ProtoPmClLine, NIL, NIL); properties.Add(clLine);
			NEW(useBgBitmap, ProtoPmUseBgBitmap, NIL, NIL); properties.Add(useBgBitmap);
			NEW(bgBitmapName, ProtoPmBgBitmapName, NIL, NIL); properties.Add(bgBitmapName);
			NEW(shadow, ProtoPmShadow, NIL, NIL); properties.Add(shadow);
			takesFocus.Set(TRUE);
			enabled := {0..3};
			SetNameAsString(StrPieMenu);
		END Init;

		PROCEDURE RecacheProperties;
		VAR s : String;
		BEGIN
			IF useBgBitmap.Get() THEN
				s := bgBitmapName.Get(); IF s # NIL THEN bgBitmap := WMGraphics.LoadImage(s^, TRUE) END
			END;
		END RecacheProperties;

		PROCEDURE PropertyChanged(sender, prop : ANY);
		BEGIN
			IF prop = bgBitmapName THEN
				RecacheProperties
			ELSE
				PropertyChanged^(sender, prop)
			END
		END PropertyChanged;

		PROCEDURE GetSector(nr : LONGINT; VAR s : ARRAY OF WMGraphics.Point2d);
		VAR i, j : LONGINT; VAR x, y : LONGINT;
		BEGIN
			x := bounds.GetWidth() DIV 2 - 4;
			y := bounds.GetHeight() DIV 2 - 4;
			nr := nr * MenuPoints;
			s[i].x := x + (InnerRadius * dir[nr MOD (4*MenuPoints)].x DIV 100H);
			s[i].y := y - (InnerRadius * dir[nr MOD (4*MenuPoints)].y DIV 100H);
			INC(i);
			s[i].x := x + (OuterRadius * dir[nr MOD (4*MenuPoints)].x DIV 100H);
			s[i].y := y - (OuterRadius * dir[nr MOD (4*MenuPoints)].y DIV 100H);
			INC(i);
			FOR j := 1 TO MenuPoints - 1 DO
				s[i].x := x + (OuterRadius * dir[(nr + j) MOD (4*MenuPoints)].x DIV 100H);
				s[i].y := y - (OuterRadius * dir[(nr + j) MOD (4*MenuPoints)].y DIV 100H);
				INC(i)
			END;
			s[i].x := x + (OuterRadius * dir[(nr + MenuPoints)MOD (4*MenuPoints)].x DIV 100H);
			s[i].y := y - (OuterRadius * dir[(nr + MenuPoints) MOD (4*MenuPoints)].y DIV 100H);
			INC(i);
			s[i].x := x + (InnerRadius * dir[(nr + MenuPoints) MOD (4*MenuPoints)].x DIV 100H);
			s[i].y := y - (InnerRadius * dir[(nr + MenuPoints) MOD (4*MenuPoints)].y DIV 100H);
			INC(i);
			FOR j := MenuPoints-1  TO 1 BY -1 DO
				s[i].x := x + (InnerRadius * dir[(nr + j) MOD (4*MenuPoints)].x DIV 100H);
				s[i].y := y - (InnerRadius * dir[(nr + j) MOD (4*MenuPoints)].y DIV 100H);
				INC(i)
			END
		END GetSector;

		PROCEDURE SetImage(nr : LONGINT; image : WMGraphics.Image);
		BEGIN
			images[nr] := image;
			Invalidate
		END SetImage;

		PROCEDURE SetText(nr: LONGINT; text: Strings.String);
		BEGIN
			texts[nr] := text;
			Invalidate
		END SetText;

		PROCEDURE SetEnabled(s : SET);
		BEGIN
			Acquire;
			enabled := s;
			Release;
			Invalidate
		END SetEnabled;

		PROCEDURE SetHover(s : SET);
		BEGIN
			Acquire;
			hover := s;
			Release;
			Invalidate
		END SetHover;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR tdist, tx, ty : LONGINT;
		BEGIN
			dx := x - bounds.GetWidth() DIV 2 + 4;
			dy := y - bounds.GetHeight() DIV 2 + 4;
			tx := (dx * dx);
			ty := (dy * dy);
			tdist := tx + ty;

			IF tdist > InnerRadius * InnerRadius THEN
				IF (dx * dx) > (dy * dy) THEN
					IF dx > 0 THEN SetHover({0})
					ELSE SetHover({2}) END
				ELSE
					IF dy > 0 THEN SetHover({3})
					ELSE SetHover({1}) END
				END
			ELSE SetHover({}) END
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR tdist, tx, ty : LONGINT;
		BEGIN
			IF sent THEN RETURN END;
			lastX := x; lastY := y;
			dx := x - bounds.GetWidth() DIV 2 + 4;
			dy := y - bounds.GetHeight() DIV 2 + 4;
			tx := (dx * dx);
			ty := (dy * dy);
			tdist := tx + ty;

			IF tdist > InnerRadius * InnerRadius THEN
				IF (dx * dx) > (dy * dy) THEN
					IF dx > 0 THEN
						IF 0 IN enabled THEN on0.Call(NIL) END; dirNr := 0
					ELSE IF 2 IN enabled THEN on2.Call(NIL) END; dirNr := 2
					END
				ELSE
					IF dy > 0 THEN IF 3 IN enabled THEN on3.Call(NIL) END; dirNr := 3
					ELSE IF 1 IN enabled THEN on1.Call(NIL) END; dirNr := 1 END
				END
			END;
			closeIt.Call(NIL); dirNr := -1
		END PointerUp;

		PROCEDURE KeyEvent*(ucs :LONGINT; flags : SET; VAR keySym : LONGINT);
		BEGIN
			IF keySym = 0FF51H THEN (* Cursor Left *)
				SetHover({2}); on2.Call(NIL); dirNr := 2; closeIt.Call(NIL)
			ELSIF keySym = 0FF53H THEN (* Cursor Right *)
				SetHover({0}); on0.Call(NIL); dirNr := 0; closeIt.Call(NIL)
			ELSIF keySym = 0FF54H THEN (* Cursor Down *)
				SetHover({3}); on3.Call(NIL); dirNr := 3; closeIt.Call(NIL)
			ELSIF keySym = 0FF52H THEN (* Cursor Up *)
				SetHover({1}); on1.Call(NIL); dirNr := 1; closeIt.Call(NIL)
			ELSIF keySym = 0FF1BH THEN (* ESC *)
				SetHover({}); closeIt.Call(NIL); dirNr := -1
			END;
		END KeyEvent;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		VAR sector, shadow : ARRAY 2 * MenuPoints + 2 OF WMGraphics.Point2d;
			i, j, shadowEffect : LONGINT;
			x, y, dx, dy : LONGINT;
			font : WMGraphics.Font;
		BEGIN
			x := bounds.GetWidth() DIV 2;
			y := bounds.GetHeight() DIV 2;

			(* shadow *)
			shadowEffect := SELF.shadow.Get();
			IF shadowEffect > 0 THEN
				FOR i := 0 TO 3 DO
					GetSector(i, sector);
					FOR j := 0 TO 2 * MenuPoints +2 - 1 DO 	shadow[j].x := sector[j].x + shadowEffect; shadow[j].y := sector[j].y + shadowEffect END;
					canvas.FillPolygonFlat(shadow, 2 * MenuPoints + 2, clShadow.Get(), WMGraphics.ModeCopy);
					FOR j := 0 TO 2 * MenuPoints +2 - 2 DO canvas.Line(shadow[j].x, shadow[j].y, shadow[j + 1].x, shadow[j + 1].y,  clShadow.Get(), WMGraphics.ModeCopy) END;
					canvas.Line(shadow[2 * MenuPoints + 2- 1].x, shadow[2 * MenuPoints + 2 -1].y, shadow[0].x, shadow[0].y, clShadow.Get(), WMGraphics.ModeCopy)
				END
			END;
			(* pie *)
			FOR i := 0 TO 3 DO
				GetSector(i, sector);
				IF i IN enabled THEN
					IF i IN hover THEN
						canvas.FillPolygonFlat(sector, 2 * MenuPoints + 2, clHover.Get(), WMGraphics.ModeCopy);
					ELSIF ~useBgBitmap.Get() THEN
						canvas.FillPolygonFlat(sector, 2 * MenuPoints + 2, clDefault.Get(), WMGraphics.ModeCopy)
					END;
				ELSE
					canvas.FillPolygonFlat(sector, 2 * MenuPoints + 2, LONGINT(0CCCC0030H), WMGraphics.ModeCopy)
				END;
				IF ~useBgBitmap.Get() THEN
					FOR j := 0 TO 2 * MenuPoints +2 - 2 DO canvas.Line(sector[j].x, sector[j].y, sector[j + 1].x, sector[j + 1].y,  clLine.Get(), WMGraphics.ModeCopy) END;
					canvas.Line(sector[2 * MenuPoints + 2- 1].x, sector[2 * MenuPoints + 2 -1].y, sector[0].x, sector[0].y, clLine.Get(), WMGraphics.ModeCopy)
				END
			END;
			(* background image *)
			IF useBgBitmap.Get() & (bgBitmap # NIL) THEN
				canvas.DrawImage(26, 26, bgBitmap, WMGraphics.ModeSrcOverDst)
			END;
			(* caption *)
			font := WMGraphics.GetFont("Oberon", 14, {0}); canvas.SetColor(0FFH); canvas.SetFont(font);
			IF images[0] # NIL THEN
				canvas.DrawImage(x + (InnerRadius + OuterRadius) DIV 2 - images[0].width DIV 2, y - images[0].height DIV 2, images[0], WMGraphics.ModeSrcOverDst)
			ELSIF texts[0] # NIL THEN
				font.GetStringSize(texts[0]^, dx, dy);
				canvas.DrawString(x-4 + (InnerRadius + OuterRadius) DIV 2 - dx DIV 2, y+11 - dy DIV 2, texts[0]^)
			END;
			IF images[1] # NIL THEN
				canvas.DrawImage(x - images[1].width DIV 2, y - (InnerRadius + OuterRadius) DIV 2 - images[1].height DIV 2, images[1], WMGraphics.ModeSrcOverDst)
			ELSIF texts[1] # NIL THEN
				font.GetStringSize(texts[1]^, dx, dy);
				canvas.DrawString(x-4 - dx DIV 2, y+11 - (InnerRadius + OuterRadius) DIV 2 - dy DIV 2, texts[1]^)
			END;
			IF images[2] # NIL THEN
				canvas.DrawImage(x - (InnerRadius + OuterRadius) DIV 2 - images[2].width DIV 2, y - images[2].height DIV 2, images[2], WMGraphics.ModeSrcOverDst)
			ELSIF texts[2] # NIL THEN
				font.GetStringSize(texts[2]^, dx, dy);
				canvas.DrawString(x-4 - (InnerRadius + OuterRadius) DIV 2 - dx DIV 2, y+11 - dy DIV 2, texts[2]^)
			END;
			IF images[3] # NIL THEN
				canvas.DrawImage(x - images[3].width DIV 2, y + (InnerRadius + OuterRadius) DIV 2 - images[3].height DIV 2, images[3],WMGraphics.ModeSrcOverDst)
			ELSIF texts[3] # NIL THEN
				font.GetStringSize(texts[3]^, dx, dy);
				canvas.DrawString(x-4 - dx DIV 2, y+11 + (InnerRadius + OuterRadius) DIV 2 - dy DIV 2, texts[3]^)
			END;
		END Draw;
	END PieMenu;

	Menu* = OBJECT (WMComponents.FormWindow)
	VAR piemenu: PieMenu;
		on0-, on1-, on2-, on3- , onClose-: WMEvents.EventSource;
		lastX*, lastY* : LONGINT;
		caller : WMWindowManager.Window;
		pointerReturned, bt* : BOOLEAN;
		userData* : ANY;
		shown : BOOLEAN;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		BEGIN
			NEW(piemenu); piemenu.bounds.SetExtents(230, 230);
			NEW(onClose, SELF, NIL, NIL, NIL);
			on0 := piemenu.on0;
			on1 := piemenu.on1;
			on2 := piemenu.on2;
			on3 := piemenu.on3;
			onClose := piemenu.closeIt;
			piemenu.fillColor.Set(LONGINT(0FFFFFF80H)); piemenu.takesFocus.Set(TRUE);
			onClose.Add(CloseIt);
			RETURN piemenu;
		END CreateForm;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			Close;
		END FocusLost;

		PROCEDURE CloseIt(sender, data : ANY);
		BEGIN
			Close
		END CloseIt;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			(* To create a multi language app, try loading the respective XML instead of CreateForm()
			if the XML was not found or does not contain all needed elements, use CreateForm as fallback *)
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			pointerThreshold := 100
		END New;

		PROCEDURE SetImage*(nr : LONGINT; image : WMGraphics.Image);
		BEGIN
			piemenu.SetImage(nr, image);
		END SetImage;

		PROCEDURE SetText*(nr: LONGINT; text: Strings.String);
		BEGIN
			piemenu.SetText(nr, text);
		END SetText;

		PROCEDURE SetEnabled*(enabled : SET);
		BEGIN
			piemenu.SetEnabled(enabled)
		END SetEnabled;

		PROCEDURE Show*(caller : WMWindowManager.Window; x, y : LONGINT; bt : BOOLEAN);
		VAR nm : WMMessages.Message;
		BEGIN
			IF ~shown THEN shown := TRUE;
				SELF.bt := bt;
				lastX := x - 50;
				lastY :=  y - 50;
				SELF.caller := caller;
				pointerReturned := FALSE;
				manager := WMWindowManager.GetDefaultManager();
				(* simulate a pointer movement so the component system is not "surprised" when suddenly
					a pressed mouse move message occurs. The component system builds up its internal owner
					chain and will forward following drag messages to the component hit with this message *)
				nm.msgType := WMMessages.MsgPointer;
				nm.msgSubType := WMMessages.MsgSubPointerMove;
				nm.x := 100; nm.y := 100;
				Handle(nm);
				manager.Add(x - piemenu.bounds.GetWidth() DIV 2, y - piemenu.bounds.GetWidth() DIV 2, SELF, {WMWindowManager.FlagHidden, WMWindowManager.FlagStayOnTop});
				IF manager.TransferPointer(SELF) THEN END;
				manager.SetFocus(SELF)
			END;
		END Show;

		PROCEDURE Close;
		BEGIN
			Close^;
			shown := FALSE;
		END Close;

	END Menu;

VAR
	ColorPrototype, ProtoPmClDefault, ProtoPmClHover, ProtoPmClShadow, ProtoPmClLine : WMProperties.ColorProperty;
	Int32Prototype, ProtoPmShadow : WMProperties.Int32Property;
	BooleanPrototype, ProtoPmUseBgBitmap : WMProperties.BooleanProperty;
	StringPrototype, ProtoPmBgBitmapName : WMProperties.StringProperty;

	StrPieMenu : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrPieMenu := Strings.NewString("PieMenu");
END InitStrings;

PROCEDURE InitPrototypes;
VAR plPieMenu : WMProperties.PropertyList;
BEGIN
	NEW(plPieMenu); WMComponents.propertyListList.Add("PieMenu", plPieMenu);
	(* use background bitmap *)
	NEW(BooleanPrototype, NIL, Strings.NewString("UseBgBitmap"), Strings.NewString("Use background bitmap")); BooleanPrototype.Set(FALSE);
	NEW(ProtoPmUseBgBitmap, BooleanPrototype, NIL, NIL); plPieMenu.Add(ProtoPmUseBgBitmap);
	(* background bitmap *)
	NEW(StringPrototype, NIL, Strings.NewString("BgBitmap"), Strings.NewString("Name of the background bitmap")); StringPrototype.Set(Strings.NewString(""));
	NEW(ProtoPmBgBitmapName, StringPrototype, NIL, NIL); plPieMenu.Add(ProtoPmBgBitmapName);
	(* colors *)
	NEW(ColorPrototype, NIL, Strings.NewString("ClDefault"), Strings.NewString("Default color")); ColorPrototype.Set(LONGINT(0CCCC0080H));
	NEW(ProtoPmClDefault, ColorPrototype, NIL, NIL); plPieMenu.Add(ProtoPmClDefault);
	NEW(ColorPrototype, NIL, Strings.NewString("ClHover"), Strings.NewString("Mouseover color")); ColorPrototype.Set(LONGINT(0CC880080H));
	NEW(ProtoPmClHover , ColorPrototype, NIL, NIL); plPieMenu.Add(ProtoPmClHover);
	NEW(ColorPrototype, NIL, Strings.NewString("ClShadow"), Strings.NewString("Shadow color")); ColorPrototype.Set(80H);
	NEW(ProtoPmClShadow, ColorPrototype, NIL, NIL); plPieMenu.Add(ProtoPmClShadow);
	NEW(ColorPrototype, NIL, Strings.NewString("ClLine"), Strings.NewString("Line color")); ColorPrototype.Set(80H);
	NEW(ProtoPmClLine, ColorPrototype, NIL, NIL); plPieMenu.Add(ProtoPmClLine);
	(* shadow *)
	NEW(Int32Prototype, NIL, Strings.NewString("UseShadow"), Strings.NewString("Draw a shadow or not")); Int32Prototype.Set(0);
	NEW(ProtoPmShadow, Int32Prototype, NIL, NIL); plPieMenu.Add(ProtoPmShadow);
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMPieMenu.



