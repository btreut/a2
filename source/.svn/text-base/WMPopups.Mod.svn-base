MODULE WMPopups;	(** AUTHOR "BF"; PURPOSE "Popup Windows"; *)

IMPORT
	Strings, WMRectangles, WMGraphics, WMEvents, WMWindowManager, WMComponents, WMStandardComponents;

CONST

	LineHeight = 20;

TYPE

	Entry = OBJECT
	VAR
		caption : Strings.String; (* {caption # NIL} *)
		onClickHandler : WMEvents.EventListener; (* {onClickHandler # NIL} *)
		parameter : ANY;
		next : Entry;

		PROCEDURE &Init(caption : Strings.String; onClickHandler : WMEvents.EventListener; parameter : ANY);
		BEGIN
			ASSERT((caption # NIL) & (onClickHandler # NIL));
			SELF.caption := caption;
			SELF.onClickHandler := onClickHandler;
			SELF.parameter := parameter;
			next := NIL;
		END Init;

	END Entry;

TYPE

	PopupWindow = OBJECT(WMComponents.FormWindow)
	VAR
		isClosed : BOOLEAN;

		PROCEDURE &New(entries : Entry);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			ASSERT(entries # NIL);
			vc := CreateForm(entries);
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			isClosed := FALSE;
		END New;

		PROCEDURE CreateForm(entries : Entry) : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
			font : WMGraphics.Font;
			entry : Entry;
			width, height, w, h : LONGINT;
		BEGIN
			NEW(panel);
			panel.fillColor.Set(WMGraphics.White);

			width := 100; height := 0;

			entry := entries;
			WHILE (entry # NIL) DO
				NEW(button);
				button.alignment.Set(WMComponents.AlignTop);
				button.bounds.SetExtents(width, LineHeight);
				button.caption.Set(entry.caption);
				button.onClick.Add(entry.onClickHandler);
				button.onClick.Add(Clicked);
				button.userData := entry.parameter;
				panel.AddInternalComponent(button);

				font := button.GetFont();
				font.GetStringSize(entry.caption^, w, h);
				IF (w + 10 > width) THEN
					width := w + 10;
				END;
				height := height + LineHeight;

				entry := entry.next;
			END;

			width := Strings.Min(width, 1024);

			panel.bounds.SetExtents(width, height);

			RETURN panel;
		END CreateForm;

		PROCEDURE Clicked(sender, data : ANY);
		BEGIN
			Close;
		END Clicked;

		PROCEDURE FocusLost;
		BEGIN
			Close;
		END FocusLost;

		PROCEDURE Close;
		BEGIN
			BEGIN {EXCLUSIVE}
				IF isClosed THEN RETURN; END;
				isClosed := TRUE;
			END;

			Close^;
		END Close;

		PROCEDURE FocusGot;
		BEGIN
			manager.SetFocus(SELF)
		END FocusGot;

	END PopupWindow;


	(* Open a Popup *)
	Popup* = OBJECT
	VAR
		first, last : Entry;

		window : PopupWindow;

		PROCEDURE &New*;
		BEGIN
			first := NIL; last := NIL;
			window := NIL;
		END New;

		PROCEDURE Add*(CONST caption : ARRAY OF CHAR; onClickHandler : WMEvents.EventListener);
		BEGIN
			AddParButton(caption, onClickHandler, NIL);
		END Add;

		PROCEDURE AddParButton*(CONST caption : ARRAY OF CHAR; onClickHandler : WMEvents.EventListener; par : ANY);
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			NEW(entry, Strings.NewString(caption), onClickHandler, par);
			IF (first = NIL) THEN
				first := entry; last := entry;
			ELSE
				last.next := entry; last := entry;
			END;
		END AddParButton;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			IF (window # NIL) THEN
				window.Close;
				window := NIL;
			END;
		END Close;

		PROCEDURE Popup* (x, y : LONGINT);
		VAR manager : WMWindowManager.WindowManager;
		BEGIN {EXCLUSIVE}
			IF (first # NIL) THEN
				IF (window # NIL) THEN window.Close; END;
				NEW(window, first);
				manager := WMWindowManager.GetDefaultManager();
				manager.Add(x, y, window, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
				manager.SetFocus(window);
			END;
		END Popup;

	END Popup;

(** Open a color swatch dialog *)
	ColorSwatchPopup* = OBJECT (WMComponents.FormWindow)
	VAR colorPanel : ColorSwatchPanel;
		color- : LONGINT;
		onColorChosen* : PROCEDURE {DELEGATE} (color : LONGINT);

		PROCEDURE &New*;
		BEGIN
			color := 0H;
			CreatePopup;
			Init(colorPanel.bounds.GetWidth(), colorPanel.bounds.GetHeight(), FALSE);
			SetContent(colorPanel);
		END New;

		PROCEDURE CreatePopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.ChosenColorProc := SetColor;
		END CreatePopup;

		PROCEDURE Popup*(x, y : LONGINT);
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
			manager.SetFocus(SELF);
		END Popup;

		PROCEDURE Clicked(sender, data : ANY);
		BEGIN
			manager.Remove(SELF)
		END Clicked;

		PROCEDURE FocusLost;
		BEGIN
			manager.Remove(SELF)
		END FocusLost;

		PROCEDURE FocusGot;
		BEGIN
			manager.SetFocus(SELF)
		END FocusGot;

		PROCEDURE SetColor(color : LONGINT);
		BEGIN
			SELF.color := color;
			IF onColorChosen # NIL THEN onColorChosen(color) END;
			manager.Remove(SELF)
		END SetColor;

	END ColorSwatchPopup;

(** Color Swatch Visual Component *)
	ColorSwatchPanel* = OBJECT(WMComponents.VisualComponent)
	VAR colors : ARRAY 19 OF LONGINT;
		ChosenColorProc* : PROCEDURE {DELEGATE} (color: LONGINT);
		(* CloseProc : PROCEDURE {DELEGATE}; *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			bounds.SetExtents(190, 70);
			BuildPalette;
		END Init;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR r, g, b, a, i, j, cColor: LONGINT;
		BEGIN
			i := y DIV 10; j := x DIV 10;
			IF (i>= 0) & (i<=2) THEN
				WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
				r := ENTIER((i+1)/4*r); g:= ENTIER((i+1)/4*g); b:= ENTIER((i+1)/4*b);
				cColor := WMGraphics.RGBAToColor(r, g, b, a);
			ELSIF (i= 3) THEN
				cColor := colors[j];
			ELSIF (i>=4) & (i<=6) THEN
				i := i - 4;
				WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
				r := 255-ENTIER((3-i)/4*(255-r)); g:= 255-ENTIER((3-i)/4*(255-g)); b:= 255-ENTIER((3-i)/4*(255-b));
				cColor := WMGraphics.RGBAToColor(r, g, b, a);
			ELSE
			END;
			IF (y>0) & (y<bounds.GetHeight()) & (x>0) &(x<bounds.GetWidth())THEN
				ChosenColorProc(cColor);
			END;
		END PointerDown;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR r, g, b, a, i, j, color: LONGINT;
		BEGIN
			DrawBackground^(canvas);

			FOR i := 0 TO 2 DO
				FOR j := 0 TO 18 DO
					WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
					r := ENTIER((i+1)/4*r); g:= ENTIER((i+1)/4*g); b:= ENTIER((i+1)/4*b);
					color := WMGraphics.RGBAToColor(r, g, b, a);
					canvas.Fill(WMRectangles.MakeRect(10*j,10*i,10*j+10,10*i+10),color , WMGraphics.ModeCopy);
				END;
			END;

			FOR j := 0 TO 18 DO
				color := colors[j];
				canvas.Fill(WMRectangles.MakeRect(10*j,30,10*j+10,10+30),color , WMGraphics.ModeCopy);
			END;

			FOR i := 0 TO 2 DO
				FOR j := 0 TO 18 DO
					WMGraphics.ColorToRGBA(colors[j], r, g, b, a);
					r := 255-ENTIER((3-i)/4*(255-r)); g:= 255-ENTIER((3-i)/4*(255-g)); b:= 255-ENTIER((3-i)/4*(255-b));
					color := WMGraphics.RGBAToColor(r, g, b, a);
					canvas.Fill(WMRectangles.MakeRect(10*j,10*i+40,10*j+10,10*i+10+40),color , WMGraphics.ModeCopy);
				END;
			END;
		END DrawBackground;

		PROCEDURE BuildPalette;
		BEGIN
			colors[0] := LONGINT(0FF0000FFH);							(* red *)
			colors[1] := LONGINT(0FF5500FFH);
			colors[2] := LONGINT(0FFAA00FFH);
			colors[3] := LONGINT(0FFFF00FFH);							(* yellow *)
			colors[4] := LONGINT(0AAFF00FFH);
			colors[5] := LONGINT(055FF00FFH);
			colors[6] := 000FF00FFH;							(* green *)
			colors[7] := 000FF55FFH;
			colors[8] := 000FFAAFFH;
			colors[9] := 000FFFFFFH;							(* cyan *)
			colors[10] := 000AAFFFFH;
			colors[11] := 00055FFFFH;
			colors[12] := 00000FFFFH;						(* blue *)
			colors[13] := 05500FFFFH;
			colors[14] :=LONGINT( 0AA00FFFFH);
			colors[15] :=LONGINT( 0FF00FFFFH);						(* magenta *)
			colors[16] :=LONGINT( 0FF00AAFFH);
			colors[17] :=LONGINT( 0FF0055FFH);
			colors[18] :=LONGINT( 0888888FFH);						(* grey *)
		END BuildPalette;

	END ColorSwatchPanel;

END WMPopups.
-----------------------------------------------------
SystemTools.Free WMPopups
