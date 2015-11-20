MODULE DTPRect; (** AUTHOR "PL"; PURPOSE "Simple Rectangle Plugin for DTPEditor"; *)

IMPORT
	Modules, Files, XML,
	XMLObjects, WMStandardComponents, WMGraphics, WMGraphicUtilities,
	WMComponents, WMRectangles, WMEditors, Strings, WMWindowManager, WMPopups,
	DTPData, DTPEditor, DTPUtilities; (* , DTPFrame *)

CONST
	pluginVersion = 1.00;
	pluginName = "Rectangle";
	pluginDesc = "Draws a Rectangle with a given Bordercolor and Fillcolor";

	fillModeSolid = 0;
	fillModeGradient = 1;
	fillModeGradientReflected = 2;

TYPE
	ContextMenuData = OBJECT
	VAR val: LONGINT;
		PROCEDURE &New*(val: LONGINT);
		BEGIN
			SELF.val := val;
		END New;
	END ContextMenuData;

	RectObject* = OBJECT(DTPData.ContentObject);
	VAR
		lineColor, rectColor, rectColor2: LONGINT;
		lineWidth : REAL;
		fillMode : LONGINT;
		gradientHorizontal: BOOLEAN;
		properties : RectPropWindow;

		PROCEDURE &New*;
		BEGIN
			(* default values *)
			lineColor := 0000000FFH;
			rectColor := LONGINT(0FFFFFFFFH);
			rectColor2 := 000FFFFH;
			lineWidth := 0.0;
			gradientHorizontal := TRUE;
			fillMode := fillModeSolid;

			NEW(properties, SELF);
		END New;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; x, y, w, h : LONGINT; zoomFactor: REAL; quality, preview: BOOLEAN);
		VAR rw, rh: REAL; linePixel: LONGINT;
		BEGIN

			rw := w/zoomFactor; rh := h/zoomFactor; linePixel := ENTIER(lineWidth * zoomFactor);
			(* fill *)
			IF fillMode = 2 THEN
				IF gradientHorizontal THEN
					WMGraphicUtilities.FillGradientHorizontal(canvas, WMRectangles.MakeRect(x+linePixel, y+linePixel, x+(w DIV 2)+1, y+h+1-linePixel), rectColor, rectColor2, WMGraphics.ModeSrcOverDst);
					WMGraphicUtilities.FillGradientHorizontal(canvas, WMRectangles.MakeRect(x+ (w DIV 2), y+linePixel, x+w+1-linePixel, y+h+1-linePixel), rectColor2, rectColor, WMGraphics.ModeSrcOverDst);
				ELSE
					WMGraphicUtilities.FillGradientVertical(canvas, WMRectangles.MakeRect(x+linePixel, y+linePixel, x+w+1-linePixel, y+(h DIV 2)+1), rectColor, rectColor2, WMGraphics.ModeSrcOverDst);
					WMGraphicUtilities.FillGradientVertical(canvas, WMRectangles.MakeRect(x+linePixel, y+(h DIV 2), x+w+1-linePixel, y+h+1-linePixel), rectColor2, rectColor, WMGraphics.ModeSrcOverDst);
				END;
			ELSIF fillMode = 1 THEN
				IF gradientHorizontal THEN
					WMGraphicUtilities.FillGradientHorizontal(canvas, WMRectangles.MakeRect(x+linePixel, y+linePixel, x+w+1-linePixel, y+h+1-linePixel), rectColor, rectColor2, WMGraphics.ModeSrcOverDst);
				ELSE
					WMGraphicUtilities.FillGradientVertical(canvas, WMRectangles.MakeRect(x+linePixel, y+linePixel, x+w+1-linePixel, y+h+1-linePixel), rectColor, rectColor2, WMGraphics.ModeSrcOverDst);
				END;
			ELSE
				canvas.Fill(WMRectangles.MakeRect(x+linePixel, y+linePixel, x+w+1-linePixel, y+h+1-linePixel), rectColor, WMGraphics.ModeSrcOverDst);
			END;
			(* line *)
			IF linePixel >0 THEN
				canvas.Fill(WMRectangles.MakeRect(x, y, x+w+1, y+linePixel), lineColor, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(x, y+linePixel, x+linePixel, y+h+1-linePixel), lineColor, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(x, y+h+1-linePixel, x+w+1,y+h+1), lineColor, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(x+w+1-linePixel, y+linePixel, x+w+1, y+h+1-linePixel), lineColor, WMGraphics.ModeSrcOverDst);
			END;

		END Draw;

		PROCEDURE Redraw;
		BEGIN
			Redraw^;
		END Redraw;

		PROCEDURE Clone*(): DTPData.ContentObject;
		VAR newObj: RectObject;
		BEGIN
			NEW(newObj); newObj.contentName := Strings.NewString(contentName^);
			newObj.redrawProc := redrawProc; newObj.updatePropsPosition := updatePropsPosition;
			newObj.contentWidth := contentWidth; newObj.contentHeight := contentHeight; newObj.zoomFactor := zoomFactor;
			newObj.ownerDoc := ownerDoc;

			newObj.lineColor := lineColor;
			newObj.rectColor := rectColor;
			newObj.rectColor2 := rectColor2;
			newObj.lineWidth := lineWidth;
			newObj.fillMode := fillMode;
			newObj.gradientHorizontal := gradientHorizontal;
			RETURN newObj;
		END Clone;

		PROCEDURE Load*(elem: XML.Element);
		VAR name : Strings.String;
			cont: XMLObjects.Enumerator;
			ptr: ANY;
			tempInt, res : LONGINT;
			tempReal : LONGREAL;
		BEGIN
			cont := elem.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN								(* read attributes *)
					name := ptr(XML.Element).GetAttributeValue("name");
					IF (name # NIL) & (name^ = "line-width") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN Strings.StrToFloat(name^, tempReal); lineWidth := SHORT(tempReal); END;
					ELSIF (name # NIL) & (name^ = "line-color") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN Strings.HexStrToInt(name^, tempInt, res); lineColor := tempInt; END;
					ELSIF (name # NIL) & (name^ = "fill-color") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN Strings.HexStrToInt(name^, tempInt, res); rectColor := tempInt; END;
					ELSIF (name # NIL) & (name^ = "fill-color2") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN Strings.HexStrToInt(name^, tempInt, res); rectColor2 := tempInt; END;
					ELSIF (name # NIL) & (name^ = "fill-mode") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN Strings.StrToInt(name^, tempInt); fillMode := tempInt; END;
					ELSIF (name # NIL) & (name^ = "gradient-horizontal") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN
							IF (name^ = "1") THEN gradientHorizontal := TRUE ELSE gradientHorizontal := FALSE; END;
						END;
					ELSE
					END;
				END;
			END;
		END Load;

		PROCEDURE Store*(VAR w: Files.Writer);
		VAR tempString: ARRAY 256 OF CHAR;
		BEGIN
			w.String('  <node-attribute name="type" value="Rectangle" />'); w.Ln;
			w.String('  <node-attribute name="line-width" value="');  Strings.FloatToStr(lineWidth, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="line-color" value="'); w.Hex(lineColor, 8); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="fill-color" value="'); w.Hex(rectColor, 8); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="fill-color2" value="'); w.Hex(rectColor2, 8); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="fill-mode" value="'); w.Int(fillMode, 0); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="gradient-horizontal" value="'); IF gradientHorizontal THEN w.Int(1, 0); ELSE w.Int(0, 0); END; w.String('" />'); w.Ln;
		END Store;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			properties.Show(x, y);
		END Show;

		PROCEDURE Hide*;
		VAR viewport: WMWindowManager.ViewPort;
		BEGIN
			viewport := WMWindowManager.GetDefaultView();
			UpdatePosition(properties.bounds.l-ENTIER(viewport.range.l), properties.bounds.t-ENTIER(viewport.range.t));
			properties.Hide;
		END Hide;

		PROCEDURE Close*;
		BEGIN
			Hide;
		END Close;

	END RectObject;

	RectPropWindow = OBJECT(WMComponents.FormWindow)
	VAR theCaller : RectObject;

		shown: BOOLEAN;
		leftPanel, rightPanel: WMStandardComponents.Panel;
		lineButton, rectButton, rect2Button, modeButton: WMStandardComponents.Button;
		lineWidthEdit, lineColorEdit, rectColorEdit, rectColorEdit2, fillModeEdit, gradHorizEdit: WMEditors.Editor;
		popup: WMPopups.Popup;


		PROCEDURE &New*(caller: RectObject);
		VAR vc: WMComponents.VisualComponent;
		BEGIN
			theCaller := caller;
			manager := WMWindowManager.GetDefaultManager();
			vc := CreatePropertyForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			SetTitle(Strings.NewString("Content"));
			shown := FALSE;

		END New;

		PROCEDURE CreatePropertyForm(): WMComponents.VisualComponent;
		VAR panel, container: WMStandardComponents.Panel;
			label: WMStandardComponents.Label;
			colorString: ARRAY 16 OF CHAR;
			button: WMStandardComponents.Button;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;
		BEGIN
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel); panel.bounds.SetExtents(190 , 120); panel.fillColor.Set(panelColor);
			panel.takesFocus.Set(TRUE);
			NEW(leftPanel); leftPanel.bounds.SetWidth(90); leftPanel.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(leftPanel);
			NEW(rightPanel); rightPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(rightPanel);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" LineWidth:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(lineWidthEdit); lineWidthEdit.bounds.SetHeight(20); lineWidthEdit.alignment.Set(WMComponents.AlignTop);
			lineWidthEdit.tv.showBorder.Set(TRUE); lineWidthEdit.multiLine.Set(FALSE); lineWidthEdit.fillColor.Set(0FFFFFFFFH);
			lineWidthEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			lineWidthEdit.onEnter.Add(SetValueHandler); lineWidthEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.FloatToStr(theCaller.lineWidth, 0, 5, 0, colorString);
			lineWidthEdit.SetAsString(colorString);
			rightPanel.AddContent(lineWidthEdit);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" LineColor:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(button); button.bounds.SetWidth(20); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			NEW(container); container.bounds.SetHeight(20); container.alignment.Set(WMComponents.AlignTop);
			lineButton := button;
			container.AddContent(lineButton); button.SetExtPointerDownHandler(LineColorHandler);
			NEW(lineColorEdit); lineColorEdit.bounds.SetHeight(20); lineColorEdit.alignment.Set(WMComponents.AlignClient);
			lineColorEdit.tv.showBorder.Set(TRUE); lineColorEdit.multiLine.Set(FALSE); lineColorEdit.fillColor.Set(0FFFFFFFFH);
			lineColorEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			lineColorEdit.onEnter.Add(SetValueHandler); lineColorEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.IntToStr(theCaller.lineColor, colorString);
			lineColorEdit.SetAsString(colorString);
			container.AddContent(lineColorEdit);
			rightPanel.AddContent(container);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" FillColor:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(button); button.bounds.SetWidth(20); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			NEW(container); container.bounds.SetHeight(20); container.alignment.Set(WMComponents.AlignTop);
			rectButton := button;
			container.AddContent(rectButton); button.SetExtPointerDownHandler(RectColorHandler);
			NEW(rectColorEdit); rectColorEdit.bounds.SetHeight(20); rectColorEdit.alignment.Set(WMComponents.AlignClient);
			rectColorEdit.tv.showBorder.Set(TRUE); rectColorEdit.multiLine.Set(FALSE); rectColorEdit.fillColor.Set(0FFFFFFFFH);
			rectColorEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			rectColorEdit.onEnter.Add(SetValueHandler); rectColorEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.IntToStr(theCaller.rectColor, colorString);
			rectColorEdit.SetAsString(colorString);
			container.AddContent(rectColorEdit);
			rightPanel.AddContent(container);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" FillColor2:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(button); button.bounds.SetWidth(20); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			NEW(container); container.bounds.SetHeight(20); container.alignment.Set(WMComponents.AlignTop);
			rect2Button := button;
			container.AddContent(rect2Button); button.SetExtPointerDownHandler(RectColor2Handler);
			NEW(rectColorEdit2); rectColorEdit2.bounds.SetHeight(20); rectColorEdit2.alignment.Set(WMComponents.AlignClient);
			rectColorEdit2.tv.showBorder.Set(TRUE); rectColorEdit2.multiLine.Set(FALSE); rectColorEdit2.fillColor.Set(0FFFFFFFFH);
			rectColorEdit2.tv.textAlignV.Set(WMGraphics.AlignCenter);
			rectColorEdit2.onEnter.Add(SetValueHandler); rectColorEdit2.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.IntToStr(theCaller.rectColor2, colorString);
			rectColorEdit2.SetAsString(colorString);
			container.AddContent(rectColorEdit2);
			rightPanel.AddContent(container);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" FillMode:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(button); button.bounds.SetWidth(20); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			NEW(container); container.bounds.SetHeight(20); container.alignment.Set(WMComponents.AlignTop);
			modeButton := button;
			container.AddContent(modeButton); button.SetExtPointerDownHandler(FillModeHandler);
			NEW(fillModeEdit); fillModeEdit.bounds.SetHeight(20); fillModeEdit.alignment.Set(WMComponents.AlignClient);
			fillModeEdit.tv.showBorder.Set(TRUE); fillModeEdit.multiLine.Set(FALSE); fillModeEdit.fillColor.Set(0FFFFFFFFH);
			fillModeEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			fillModeEdit.onEnter.Add(SetValueHandler); fillModeEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.IntToStr(theCaller.fillMode, colorString);
			fillModeEdit.SetAsString(colorString);
			container.AddContent(fillModeEdit);
			rightPanel.AddContent(container);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Horizontal:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(gradHorizEdit); gradHorizEdit.bounds.SetHeight(20); gradHorizEdit.alignment.Set(WMComponents.AlignTop);
			gradHorizEdit.tv.showBorder.Set(TRUE); gradHorizEdit.multiLine.Set(FALSE); gradHorizEdit.fillColor.Set(0FFFFFFFFH);
			gradHorizEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			gradHorizEdit.onEnter.Add(SetValueHandler); gradHorizEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			Strings.BoolToStr(theCaller.gradientHorizontal, colorString);
			gradHorizEdit.SetAsString(colorString);
			rightPanel.AddContent(gradHorizEdit);

			RETURN panel;
		END CreatePropertyForm;

		PROCEDURE LineColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorChooser: DTPUtilities.ColorChooserWindow;
			rectangle: WMRectangles.Rectangle;
			result: LONGINT;
			replaceColor: BOOLEAN;
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(colorChooser);
			rectangle := lineButton.bounds.Get();
			replaceColor := colorChooser.Show(bounds.l, bounds.t+rectangle.b+20, result);
			IF replaceColor THEN
				Strings.IntToHexStr(result, 7, colorString);
				lineColorEdit.SetAsString(colorString);
				theCaller.lineColor := result;
				theCaller.Redraw;
			END;
			handled := TRUE;
		END LineColorHandler;

		PROCEDURE RectColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorChooser: DTPUtilities.ColorChooserWindow;
			rectangle: WMRectangles.Rectangle;
			result: LONGINT;
			replaceColor: BOOLEAN;
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(colorChooser);
			rectangle := rectButton.bounds.Get();
			replaceColor := colorChooser.Show(bounds.l, bounds.t+rectangle.b+40, result);
			IF replaceColor THEN
				Strings.IntToHexStr(result, 7, colorString);
				rectColorEdit.SetAsString(colorString);
				theCaller.rectColor := result;
				theCaller.Redraw;
			END;
			handled := TRUE;
		END RectColorHandler;

		PROCEDURE RectColor2Handler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorChooser: DTPUtilities.ColorChooserWindow;
			rectangle: WMRectangles.Rectangle;
			result: LONGINT;
			replaceColor: BOOLEAN;
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(colorChooser);
			rectangle := rect2Button.bounds.Get();
			replaceColor := colorChooser.Show(bounds.l, bounds.t+rectangle.b+60, result);
			IF replaceColor THEN
				Strings.IntToHexStr(result, 7, colorString);
				rectColorEdit2.SetAsString(colorString);
				theCaller.rectColor2 := result;
				theCaller.Redraw;
			END;
			handled := TRUE;
		END RectColor2Handler;

		PROCEDURE FillModeHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			NEW(popup);
			popup.AddParButton("Solid", FillModePopupHandler, ctxFillModeSolid);
			popup.AddParButton("Gradient", FillModePopupHandler, ctxFillModeGradient);
			popup.AddParButton("Grad. Reflected", FillModePopupHandler, ctxFillModeGradientReflected);
			handled := TRUE;
			rectangle := modeButton.bounds.Get();
			popup.Popup(bounds.l+rectangle.l, bounds.t+rectangle.t+rectangle.b+80);

		END FillModeHandler;

		PROCEDURE FillModePopupHandler(sender, data: ANY);
		VAR colorString: ARRAY 16 OF CHAR;
		BEGIN
			IF (data # NIL) THEN
				popup.Close;
				Strings.IntToStr(data(ContextMenuData).val, colorString);
				fillModeEdit.SetAsString(colorString);
				theCaller.fillMode := data(ContextMenuData).val;
				theCaller.Redraw;
			END;
		END FillModePopupHandler;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				RefreshValues;
				WMWindowManager.ExtAddWindow(SELF, x, y,
					{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			IF shown THEN
				shown := FALSE;
				manager.Remove(SELF);
			END;
		END Hide;

		PROCEDURE RefreshValues;
		VAR colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.FloatToStr(theCaller.lineWidth, 0, 5,0, colorString);
			lineWidthEdit.SetAsString(colorString);
			lineWidthEdit.Invalidate;

			Strings.IntToHexStr(theCaller.lineColor, 7, colorString);
			lineColorEdit.SetAsString(colorString);
			lineColorEdit.Invalidate;

			Strings.IntToHexStr(theCaller.rectColor, 7, colorString);
			rectColorEdit.SetAsString(colorString);
			rectColorEdit.Invalidate;

			Strings.IntToHexStr(theCaller.rectColor2, 7, colorString);
			rectColorEdit2.SetAsString(colorString);
			rectColorEdit2.Invalidate;

			Strings.IntToStr(theCaller.fillMode, colorString);
			fillModeEdit.SetAsString(colorString);
			fillModeEdit.Invalidate;

			Strings.BoolToStr(theCaller.gradientHorizontal, colorString);
			gradHorizEdit.SetAsString(colorString);
			gradHorizEdit.Invalidate;

		END RefreshValues;

		PROCEDURE SetValueHandler(sender, data: ANY);
		VAR
			colorString, origString : ARRAY 128 OF CHAR;
			color, res : LONGINT;
			width: LONGREAL;
			bool: BOOLEAN;

		BEGIN

			IF (sender = rectColorEdit) THEN
				rectColorEdit.GetAsString(colorString);
				Strings.IntToHexStr(theCaller.rectColor, 7, origString);
				IF origString # colorString THEN									(* Set new FillColor *)
					Strings.HexStrToInt(colorString, color, res);
					theCaller.rectColor := color;
				END;
			ELSIF (sender = rectColorEdit2) THEN
				rectColorEdit2.GetAsString(colorString);
				Strings.IntToHexStr(theCaller.rectColor2, 7, origString);
				IF origString # colorString THEN									(* Set new 2nd FillColor *)
					Strings.HexStrToInt(colorString, color, res);
					theCaller.rectColor2 := color;
				END;
			ELSIF (sender = lineColorEdit) THEN
				lineColorEdit.GetAsString(colorString);
				Strings.IntToHexStr(theCaller.lineColor, 7, origString);
				IF origString # colorString THEN									(* Set new LineColor *)
					Strings.HexStrToInt(colorString, color, res);
					theCaller.lineColor := color;
				END;
			ELSIF (sender = lineWidthEdit) THEN
				lineWidthEdit.GetAsString(colorString);
				Strings.FloatToStr(theCaller.lineWidth, 0, 5, 0, origString);
				IF origString # colorString THEN									(* Set new LineWidth *)
					Strings.StrToFloat(colorString, width);
					theCaller.lineWidth := SHORT(width);
				END;
			ELSIF (sender = fillModeEdit) THEN
				fillModeEdit.GetAsString(colorString);
				Strings.IntToStr(theCaller.fillMode, origString);
				IF origString # colorString THEN									(* Set new FillMode *)
					Strings.StrToInt(colorString, color);
					theCaller.fillMode := color;
				END;
			ELSIF (sender = gradHorizEdit) THEN
				gradHorizEdit.GetAsString(colorString);
				Strings.BoolToStr(theCaller.gradientHorizontal, origString);
				IF origString # colorString THEN									(* Set new GradientType *)
					Strings.StrToBool(colorString, bool);
					theCaller.gradientHorizontal := bool;
				END;
			ELSE
			END;
			theCaller.Redraw;
			RefreshValues;
		END SetValueHandler;

		PROCEDURE Close;
		BEGIN
			shown := FALSE;
			Hide;
			Close^;
		END Close;

	END RectPropWindow;

(* ----------------------------------------------------------------------- *)
VAR
	ctxFillModeSolid, ctxFillModeGradient, ctxFillModeGradientReflected: ContextMenuData;

PROCEDURE GenRect*(): DTPData.ContentObject;
VAR rectangle: RectObject;
BEGIN
	NEW(rectangle);
	RETURN rectangle;
END GenRect;

PROCEDURE Register*;
BEGIN
	DTPEditor.plugRegistry.RegisterPlugin(pluginName, GenRect);
END Register;

PROCEDURE Cleanup;
BEGIN
	DTPEditor.plugRegistry.UnregisterPlugin(pluginName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(ctxFillModeSolid, fillModeSolid);
	NEW(ctxFillModeGradient, fillModeGradient);
	NEW(ctxFillModeGradientReflected, fillModeGradientReflected);
END DTPRect.

