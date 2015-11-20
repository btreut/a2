MODULE DTPUtilities; (** AUTHOR "PL"; PURPOSE "Utilities for simple DTP Editor"; *)

IMPORT
	KernelLog, Files, XML, XMLParser, XMLScanner,
	WMStandardComponents, WMGraphics, WMGraphicUtilities, XMLObjects,
	WMComponents, WMRectangles, WMDialogs, Texts,
	WMEditors, Dates, Strings, WMGrids, WMStringGrids,
	WMWindowManager, WMPopups, Raster, WMEvents, WMRasterScale, DTPData;

CONST

VAR

TYPE
	(* --- Generic Object Property Window ---------------------------- *)

	ObjectPropertyWindow* = OBJECT(WMComponents.FormWindow)
	VAR

	END ObjectPropertyWindow;

	(* --- Object Properties ---------------------------------------- *)

	PropertyEntry* = OBJECT
	VAR

		PROCEDURE Set*;

		END Set;

		PROCEDURE Get*;

		END Get;


	END PropertyEntry;

	StringPropertyEntry* = OBJECT(PropertyEntry)
	VAR name: ARRAY 16 OF CHAR;
		value: ARRAY 32 OF CHAR;
		onClick: WMEvents.EventSource;

	END StringPropertyEntry;

	RealPropertyEntry* = OBJECT(PropertyEntry)
	VAR name: ARRAY 16 OF CHAR;
		value: REAL;
		onClick: WMEvents.EventSource;

	END RealPropertyEntry;

	IntPropertyEntry* = OBJECT(PropertyEntry)
	VAR name: ARRAY 16 OF CHAR;
		value: LONGINT;
		onClick: WMEvents.EventSource;

	END IntPropertyEntry;

	BooleanPropertyEntry* = OBJECT(PropertyEntry)
	VAR name: ARRAY 16 OF CHAR;
		value: BOOLEAN;
		onClick: WMEvents.EventSource;

	END BooleanPropertyEntry;


	PropertyList* = OBJECT
	VAR list: ARRAY 16 OF PropertyEntry;

		PROCEDURE Add(entry: PropertyEntry);

		END Add;

		PROCEDURE Grow;

		END Grow;

	END PropertyList;

	(* --- List Chooser -------------------------------------------- *)

	ListChooserWindow* = OBJECT(WMComponents.FormWindow)

	END ListChooserWindow;

	ListChooser* = OBJECT(WMComponents.VisualComponent)

	END ListChooser;


	(* --- Color Chooser ------------------------------------------- *)

	ColorChooserWindow* = OBJECT(WMComponents.FormWindow)
	VAR
		chooser : ColorChooser;
		label : WMStandardComponents.Label;
		panel : WMStandardComponents.Panel;
		button : WMStandardComponents.Button;
		result, chosenColor* : LONGINT;
		shown : BOOLEAN;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		BEGIN
			NEW(chooser); chooser.SetCaller(SELF);
			chooser.bounds.SetExtents(190, 70);


			RETURN chooser
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			(* SetTitle(Strings.NewString("Color Chooser")); *)
		END New;

		PROCEDURE Show*(x, y: LONGINT; VAR chosen: LONGINT):BOOLEAN;
		BEGIN
			IF ~shown THEN
				result := -1; shown := TRUE;
				manager := WMWindowManager.GetDefaultManager();
				manager.Add(x, y, SELF, {WMWindowManager.FlagStayOnTop});
				manager.SetFocus(SELF);
				BEGIN {EXCLUSIVE}
					AWAIT (result >= 0)
				END;
				manager.Remove(SELF); shown := FALSE;
			END;
			IF result = 0 THEN
				chosen := chosenColor;
				RETURN TRUE
			ELSE

				RETURN FALSE;
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF); shown := FALSE;
		END Hide;

		PROCEDURE FocusLost;
		BEGIN
			SetResult(1);
		END FocusLost;

		PROCEDURE PressHandler(sender, data : ANY);
		VAR value : ARRAY 32 OF CHAR;
		BEGIN
			KernelLog.String("pressed: "); KernelLog.String(value); KernelLog.Ln;
		END PressHandler;

		PROCEDURE OKHandler(sender, data : ANY);
		BEGIN
			Hide;
		END OKHandler;

		PROCEDURE SetResult(res: LONGINT);
		BEGIN {EXCLUSIVE}
			result := res;
		END SetResult;

		PROCEDURE GetFieldContent(VAR string : ARRAY OF CHAR);

		END GetFieldContent;

	END ColorChooserWindow;

	ColorChooser* = OBJECT(WMComponents.VisualComponent)
	VAR
		colors : ARRAY 19 OF LONGINT;
		theCaller: ColorChooserWindow;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			BuildPalette;
		END Init;

		PROCEDURE SetCaller(caller:  ColorChooserWindow);
		BEGIN
			theCaller := caller;
		END SetCaller;

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
			IF (y<0) & (y>70) THEN
				theCaller.SetResult(1);
			ELSE
				theCaller.chosenColor := cColor;
				theCaller.SetResult(0);
			END;
		END PointerDown;

(*		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			theCaller.SetResult(1);
		END FocusLost;
*)
		PROCEDURE Draw*(canvas: WMGraphics.Canvas);
		VAR r, g, b, a, i, j, color: LONGINT;
		BEGIN
			Draw^(canvas);

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



		END Draw;

		PROCEDURE BuildPalette;
		BEGIN
			colors[0] := LONGINT(0FF0000FFH);							(* red *)
			colors[1] := LONGINT(0FF5500FFH);
			colors[2] := LONGINT(0FFAA00FFH);
			colors[3] := LONGINT(0FFFF00FFH);							(* yellow *)
			colors[4] := LONGINT(0AAFF00FFH);
			colors[5] := 055FF00FFH;
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

	END ColorChooser;

	(* --- Style Editor ------------------------------------------- *)
CONST
	AlignLeft = 0; AlignCenter = 1; AlignRight = 2; AlignJustified = 3;
	StyleRegular = 0; StyleBold = 1; StyleItalic = 2; StyleBoldItalic = 3;

TYPE
	ContextMenuData = OBJECT
	VAR val: LONGINT;
		PROCEDURE &New*(val: LONGINT);
		BEGIN
			SELF.val := val;
		END New;
	END ContextMenuData;

	StyleEditor* = OBJECT(WMComponents.FormWindow)
	VAR
		document : DTPData.Document;
		pstyleButton, cstyleButton, gstyleButton, customButton, button, button1, button2, button3, button4 : WMStandardComponents.Button;
		shown : BOOLEAN; popup: WMPopups.Popup;
		currentPStyle, tempPStyle : DTPData.ParagraphStyleObject;
		currentCStyle, tempCStyle : DTPData.CharacterStyleObject;
		currentGStyle, tempGStyle : DTPData.GraphicStyleObject;
		currentCustomStyle, tempCustomStyle : DTPData.CustomStyleObject;
		oldPStyleName, oldCStyleName, oldGStyleName, oldCustomStyleName: ARRAY 256 OF CHAR;
		previewLabel: PreviewPanel; fontNotFound : WMStandardComponents.Label;
		tabPanel, buttonPanel : WMStandardComponents.Panel;
		tabColor, tabSelectedColor : LONGINT;
		UpdateProc* : PROCEDURE {DELEGATE};
		pstylePanel, cstylePanel, gstylePanel, customPanel : WMStandardComponents.Panel;
		pList, cList, gList, customList : WMStringGrids.StringGrid;
		pName, pAlign, pFirstIndent, pLeftIndent, pRightIndent, pSpaceBefore, pSpaceAfter, pDefCharStyle: WMEditors.Editor;
		cName, cFont, cSize, cStyle, cBaselineShift, cLeading, cColor, cBackColor, cTracking, cKerning, cStretchH, cStretchV: WMEditors.Editor;
		(* other Style EditorFields *)
		styleCounter : LONGINT;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, mainPanel, gridPanel, propertyPanel : WMStandardComponents.Panel;
			borderPanel : CustomPanel;
			groupPanel : GroupPanel;
			label : WMStandardComponents.Label;
			labelWidth : LONGINT;
			lineP: LinePanel;
			manager : WMWindowManager.WindowManager;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;

		BEGIN
			labelWidth := 130;
			tabColor := 0008000FFH;
			tabSelectedColor := 000CC00FFH;
			manager := WMWindowManager.GetDefaultManager();
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(mainPanel); mainPanel.bounds.SetExtents(500, 420); mainPanel.fillColor.Set(panelColor);
			mainPanel.takesFocus.Set(TRUE);

			(* -- tabs -- *)
			NEW(tabPanel); tabPanel.bounds.SetHeight(20); tabPanel.fillColor.Set(LONGINT(0CCCCCCFFH));
			tabPanel.alignment.Set(WMComponents.AlignTop);
			NEW(pstyleButton); pstyleButton.caption.SetAOC("Paragraph"); pstyleButton.alignment.Set(WMComponents.AlignLeft);
			(* pstyleButton.SetExtPointerDownHandler(TabHandler); *)
			pstyleButton.onClick.Add(TabHandler); pstyleButton.clDefault.Set(tabSelectedColor);
			NEW(cstyleButton); cstyleButton.caption.SetAOC("Character"); cstyleButton.alignment.Set(WMComponents.AlignLeft);
			cstyleButton.onClick.Add(TabHandler); cstyleButton.clDefault.Set(tabColor);
			tabPanel.AddContent(pstyleButton);
			tabPanel.AddContent(cstyleButton);
			mainPanel.AddContent(tabPanel);

			(* -- paragraph style -- *)
			NEW(pstylePanel); pstylePanel.alignment.Set(WMComponents.AlignClient);
			mainPanel.AddContent(pstylePanel);
			NEW(borderPanel); borderPanel.bounds.SetWidth(200); borderPanel.alignment.Set(WMComponents.AlignLeft);
			borderPanel.hasInnerBevel := TRUE; borderPanel.innerBevelDown := TRUE; borderPanel.SetBorder(8,8,8,8);
			NEW(gridPanel); gridPanel.alignment.Set(WMComponents.AlignClient);
			gridPanel.fillColor.Set(LONGINT(0FFFFFFFFH));
			NEW(pList); pList.alignment.Set(WMComponents.AlignClient);
			pList.onClick.Add(PClickSelected);
			pList.model.Acquire;
			pList.model.SetNofCols(1);
			pList.model.SetNofRows(1);
			pList.SetSelectionMode(WMGrids.GridSelectRows);
			pList.model.Release;
			gridPanel.AddContent(pList);
			borderPanel.AddContent(gridPanel);
			pstylePanel.AddContent(borderPanel);
			NEW(propertyPanel); propertyPanel.alignment.Set(WMComponents.AlignClient);
			pstylePanel.AddContent(propertyPanel);

			NEW(lineP); lineP.bounds.SetHeight(13); lineP.alignment.Set(WMComponents.AlignTop);
			lineP.caption := "Paragraph Style:";
			propertyPanel.AddContent(lineP);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Paragraph Style Name:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pName); pName.alignment.Set(WMComponents.AlignClient);
			pName.multiLine.Set(FALSE); pName.fillColor.Set(LONGINT(0FFFFFFFFH)); pName.tv.showBorder.Set(TRUE);
			pName.tv.textAlignV.Set(WMGraphics.AlignCenter);
			pName.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); pName.onEnter.Add(UpdateValueHandler);
			panel.AddContent(label);
			panel.AddContent(pName);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Alignment:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(button1); button1.caption.SetAOC("+"); button1.alignment.Set(WMComponents.AlignRight);
			button1.SetExtPointerDownHandler(AlignHandler); button1.bounds.SetWidth(20);
			NEW(pAlign); pAlign.alignment.Set(WMComponents.AlignClient);
			pAlign.multiLine.Set(FALSE); pAlign.fillColor.Set(LONGINT(0FFFFFFFFH)); pAlign.tv.showBorder.Set(TRUE);
			pAlign.tv.textAlignV.Set(WMGraphics.AlignCenter);
			pAlign.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); pAlign.onEnter.Add(UpdateValueHandler);
			panel.AddContent(label); panel.AddContent(button1);
			panel.AddContent(pAlign);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" First Line Indent:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pFirstIndent); pFirstIndent.alignment.Set(WMComponents.AlignClient);
			pFirstIndent.multiLine.Set(FALSE); pFirstIndent.fillColor.Set(LONGINT(0FFFFFFFFH)); pFirstIndent.tv.showBorder.Set(TRUE);
			pFirstIndent.tv.textAlignV.Set(WMGraphics.AlignCenter);
			pFirstIndent.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); pFirstIndent.onEnter.Add(UpdateValueHandler);
			panel.AddContent(label);
			panel.AddContent(pFirstIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Left Line Indent:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pLeftIndent); pLeftIndent := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(pLeftIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Right Line Indent:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pRightIndent); pRightIndent := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(pRightIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Space Before:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pSpaceBefore); pSpaceBefore := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(pSpaceBefore);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Space After:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pSpaceAfter); pSpaceAfter := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(pSpaceAfter);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Default Char Style:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(pDefCharStyle); pDefCharStyle := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(pDefCharStyle);
			propertyPanel.AddContent(panel);

			(* spacer panel *)
(*			NEW(panel); panel.bounds.SetHeight(15); panel.alignment.Set(WMComponents.AlignTop);
			propertyPanel.AddContent(panel);
			NEW(groupPanel); groupPanel.alignment.Set(WMComponents.AlignTop);
			groupPanel.SetCaption("Preview:"); groupPanel.bounds.SetHeight(80);
			NEW(previewLabel); previewLabel.fillColor.Set(0FFFFFFFFH); previewLabel.alignment.Set(WMComponents.AlignClient);
			previewLabel.caption.SetAOC("The quick brown Fox Jumped over the lazy Dog"); previewLabel.alignH.Set(1); previewLabel.alignV.Set(1);
			groupPanel.AddContent(previewLabel);
			propertyPanel.AddContent(groupPanel);

			NEW(check); check.bounds.SetHeight(20); check.alignment.Set(WMComponents.AlignTop);
			check.caption := "Checkbox";
			propertyPanel.AddContent(check);
*)
			(* -- paragraph panel buttons -- *)
			NEW(buttonPanel); buttonPanel.bounds.SetHeight(30); buttonPanel.fillColor.Set(panelColor);
			buttonPanel.alignment.Set(WMComponents.AlignBottom);

			NEW(button); button.caption.SetAOC("Apply"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ApplyPHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Delete"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(RemovePHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Import"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ImportPHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("New"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(NewPHandler);
			buttonPanel.AddContent(button);

			propertyPanel.AddContent(buttonPanel);


			(* -- character style -- *)
			NEW(cstylePanel); cstylePanel.alignment.Set(WMComponents.AlignClient);
			cstylePanel.visible.Set(FALSE);
			mainPanel.AddContent(cstylePanel);
			NEW(borderPanel); borderPanel.bounds.SetWidth(200); borderPanel.alignment.Set(WMComponents.AlignLeft);
			borderPanel.hasInnerBevel := TRUE; borderPanel.innerBevelDown := TRUE; borderPanel.SetBorder(8,8,8,8);
			NEW(gridPanel); gridPanel.bounds.SetWidth(200); gridPanel.alignment.Set(WMComponents.AlignClient);
			gridPanel.fillColor.Set(LONGINT(0FFFFFFFFH));
			NEW(cList); cList.alignment.Set(WMComponents.AlignClient);
			cList.onClick.Add(CClickSelected);
			cList.model.Acquire;
			cList.model.SetNofCols(1);
			cList.model.SetNofRows(1);
			cList.SetSelectionMode(WMGrids.GridSelectRows);
			cList.model.Release;
			gridPanel.AddContent(cList);
			borderPanel.AddContent(gridPanel);
			cstylePanel.AddContent(borderPanel);
			NEW(propertyPanel); propertyPanel.alignment.Set(WMComponents.AlignClient);
			cstylePanel.AddContent(propertyPanel);

			NEW(lineP); lineP.bounds.SetHeight(13); lineP.alignment.Set(WMComponents.AlignTop);
			lineP.caption := "Character Style:";
			propertyPanel.AddContent(lineP);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Character Style Name:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cName); cName := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cName);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Font Name:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cFont); cFont := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cFont);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Font Style:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cStyle); cStyle := CreateEditorField();
			panel.AddContent(label);
			NEW(button2); button2.caption.SetAOC("+"); button2.alignment.Set(WMComponents.AlignRight);
			button2.SetExtPointerDownHandler(StyleHandler); button2.bounds.SetWidth(20);
			panel.AddContent(button2);
			panel.AddContent(cStyle);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Font Size:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cSize); cSize := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cSize);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Leading:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cLeading); cLeading := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cLeading);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Baseline Shift:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cBaselineShift); cBaselineShift := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cBaselineShift);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Font Color:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cColor); cColor := CreateEditorField();
			panel.AddContent(label);
			NEW(button3); button3.caption.SetAOC("+"); button3.alignment.Set(WMComponents.AlignRight);
			button3.SetExtPointerDownHandler(ColorHandler); button3.bounds.SetWidth(20);
			panel.AddContent(button3);
			panel.AddContent(cColor);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Font BG Color:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cBackColor); cBackColor := CreateEditorField();
			panel.AddContent(label);
			NEW(button4); button4.caption.SetAOC("+"); button4.alignment.Set(WMComponents.AlignRight);
			button4.SetExtPointerDownHandler(BGColorHandler); button4.bounds.SetWidth(20);
			panel.AddContent(button4);
			panel.AddContent(cBackColor);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Tracking:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cTracking); cTracking := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cTracking);
			(* propertyPanel.AddContent(panel);	 *)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Kerning:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cKerning); cKerning := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cKerning);
			(* propertyPanel.AddContent(panel); *)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Stretch Horizontal:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cStretchH); cStretchH := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cStretchH);
			(* propertyPanel.AddContent(panel); *)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(" Stretch Vertical:");
			label.alignment.Set(WMComponents.AlignLeft);
			NEW(cStretchV); cStretchV := CreateEditorField();
			panel.AddContent(label);
			panel.AddContent(cStretchV);
			(* propertyPanel.AddContent(panel);	 *)

			(* spacer panel *)
			NEW(panel); panel.bounds.SetHeight(15); panel.alignment.Set(WMComponents.AlignTop);
			propertyPanel.AddContent(panel);
			NEW(groupPanel); groupPanel.alignment.Set(WMComponents.AlignTop);
			groupPanel.SetCaption("Preview:"); groupPanel.bounds.SetHeight(80);
			NEW(previewLabel); previewLabel.fillColor.Set(LONGINT(0FFFFFFFFH)); previewLabel.alignment.Set(WMComponents.AlignClient);
			previewLabel.caption.SetAOC("The quick brown Fox jumped over the lazy Dog"); previewLabel.alignH.Set(1); previewLabel.alignV.Set(1);
			groupPanel.AddContent(previewLabel);
			propertyPanel.AddContent(groupPanel);
			NEW(fontNotFound); fontNotFound.bounds.SetHeight(20); fontNotFound.alignment.Set(WMComponents.AlignTop);
			fontNotFound.caption.SetAOC("  ERROR: Font not found! - using DefaultFont"); fontNotFound.visible.Set(FALSE);
			propertyPanel.AddContent(fontNotFound); fontNotFound.textColor.Set(LONGINT(0FF0000FFH));

			(* -- character style buttons -- *)
			NEW(buttonPanel); buttonPanel.bounds.SetHeight(30); buttonPanel.fillColor.Set(panelColor);
			buttonPanel.alignment.Set(WMComponents.AlignBottom);

			NEW(button); button.caption.SetAOC("Apply"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ApplyCHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Delete"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(RemoveCHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Import"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ImportCHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("New"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(NewCHandler);
			buttonPanel.AddContent(button);

			propertyPanel.AddContent(buttonPanel);

			RETURN mainPanel;
		END CreateForm;

		PROCEDURE CreateEditorField(): WMEditors.Editor;
		VAR newEditor: WMEditors.Editor;
		BEGIN
			NEW(newEditor); newEditor.alignment.Set(WMComponents.AlignClient);
			newEditor.multiLine.Set(FALSE); newEditor.fillColor.Set(LONGINT(0FFFFFFFFH)); newEditor.tv.showBorder.Set(TRUE);
			newEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			newEditor.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); newEditor.onEnter.Add(UpdateValueHandler);
			newEditor.SetExtFocusHandler(FocusHandler);
			RETURN newEditor;
		END CreateEditorField;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Style Editor"));
			IF styleCounter > 0 THEN
			ELSE styleCounter := 0; END;
		END New;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				manager := WMWindowManager.GetDefaultManager();
				WMWindowManager.AddWindow(SELF, x, y);
				manager.SetFocus(SELF);
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF); shown := FALSE;
		END Hide;

		PROCEDURE Close*;
		BEGIN
			Close^;
			IF UpdateProc # NIL THEN UpdateProc END;
		END Close;

		PROCEDURE LoadStyleList*(VAR doc: DTPData.Document);
		VAR i : LONGINT;
		BEGIN
			document := doc;
			pList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(doc.pStyles))  & (doc.pStyles[i] # NIL)) DO
				pList.model.SetNofRows(i+1);
				pList.model.SetCellText(0, i, Strings.NewString(doc.pStyles[i].name));
				pList.model.SetCellData(0, i, doc.pStyles[i]);
				INC(i);
			END;
			PClickSelected(NIL, pList.model.GetCellData(0, 0));
			pList.model.Release;

			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(doc.cStyles))  & (doc.cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(doc.cStyles[i].name));
				cList.model.SetCellData(0, i, doc.cStyles[i]);
				INC(i);
			END;
			CClickSelected(NIL, cList.model.GetCellData(0, 0));
			cList.model.Release;

		END LoadStyleList;

		PROCEDURE FocusHandler(hasFocus: BOOLEAN);

		END FocusHandler;

		PROCEDURE TabHandler(sender, data: ANY);
		BEGIN
			IF (sender # NIL) & (sender IS WMStandardComponents.Button) THEN
				IF sender = pstyleButton THEN
					cstylePanel.visible.Set(FALSE); cstyleButton.clDefault.Set(tabColor);
					pstylePanel.visible.Set(TRUE); pstyleButton.clDefault.Set(tabSelectedColor);
				ELSIF sender = cstyleButton THEN
					pstylePanel.visible.Set(FALSE); pstyleButton.clDefault.Set(tabColor);
					cstylePanel.visible.Set(TRUE); cstyleButton.clDefault.Set(tabSelectedColor);
				ELSIF sender = gstyleButton THEN

				ELSIF sender = customButton THEN

				ELSE

				END;
			END;
		END TabHandler;

		PROCEDURE PClickSelected(sender, data: ANY);
		VAR tempString: ARRAY 64 OF CHAR;
		BEGIN
			IF (data # NIL) THEN
				currentPStyle := data(DTPData.ParagraphStyleObject);
				tempPStyle := currentPStyle.Clone();
				pName.SetAsString(currentPStyle.name);
				IF (currentPStyle.alignment = 0) THEN tempString := "Left";
				ELSIF (currentPStyle.alignment = 1) THEN tempString := "Center";
				ELSIF (currentPStyle.alignment = 2) THEN tempString := "Right";
				ELSE tempString := "Justified";
				END;
				pAlign.SetAsString(tempString);
				Strings.FloatToStr(currentPStyle.firstIndent, 0,4,0, tempString);
				pFirstIndent.SetAsString(tempString);
				Strings.FloatToStr(currentPStyle.leftIndent, 0,4,0, tempString);
				pLeftIndent.SetAsString(tempString);
				Strings.FloatToStr(currentPStyle.rightIndent, 0,4,0, tempString);
				pRightIndent.SetAsString(tempString);
				Strings.FloatToStr(currentPStyle.spaceBefore, 0,4,0, tempString);
				pSpaceBefore.SetAsString(tempString);
				Strings.FloatToStr(currentPStyle.spaceAfter, 0,4,0, tempString);
				pSpaceAfter.SetAsString(tempString);
				pDefCharStyle.SetAsString(currentPStyle.charStyle.name);
				COPY(currentPStyle.name, oldPStyleName);
			END;
		END PClickSelected;

		PROCEDURE CClickSelected(sender, data: ANY);
		VAR tempString: ARRAY 64 OF CHAR;
			tempFont: WMGraphics.Font;
		BEGIN
			IF (data # NIL) THEN
				currentCStyle := data(DTPData.CharacterStyleObject);
				tempCStyle := currentCStyle.Clone();
				cName.SetAsString(currentCStyle.name);
				cFont.SetAsString(currentCStyle.family);
				IF (currentCStyle.style * {0, 1} = {}) THEN
					 tempString := "Regular";
				ELSIF (currentCStyle.style * {0, 1} = {0}) THEN
					tempString := "Bold";
				ELSIF (currentCStyle.style * {0, 1} = {1}) THEN
					tempString := "Italic";
				ELSE
					tempString := "Bold Italic";
				END;
				cStyle.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.size, 0,4,0, tempString);
				cSize.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.leading, 0,4,0, tempString);
				cLeading.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.baselineShift, 0,4,0, tempString);
				cBaselineShift.SetAsString(tempString);
				Strings.IntToHexStr(currentCStyle.color, 7, tempString);
				cColor.SetAsString(tempString);
				Strings.IntToHexStr(currentCStyle.bgColor, 7, tempString);
				cBackColor.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.tracking, 0,4,0, tempString);
				cTracking.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.kerning, 0,4,0, tempString);
				cKerning.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.scaleHorizontal, 0,4,0, tempString);
				cStretchH.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.scaleVertical, 0,4,0, tempString);
				cStretchV.SetAsString(tempString);
				COPY(currentCStyle.name, oldCStyleName);

				(* update preview *)
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.fillColor.Set(tempCStyle.bgColor);
				previewLabel.fontColor := tempCStyle.color; previewLabel.Invalidate;
			END;
		END CClickSelected;

		PROCEDURE GClickSelected(sender, data: ANY);

		END GClickSelected;

		PROCEDURE CustomClickSelected(sender, data: ANY);

		END CustomClickSelected;

		PROCEDURE UpdateValueHandler(sender, data: ANY);
		VAR tempString : ARRAY 64 OF CHAR;
			tempLReal : LONGREAL;
			tempInt, res : LONGINT;
			tempCharStyle: DTPData.CharacterStyleObject;
			tempFont: WMGraphics.Font;
		BEGIN
			(* set temp values, update preview *)
			IF (sender(WMEditors.Editor) = pName) THEN
				pName.GetAsString(tempString);
				COPY(tempString, tempPStyle.name);
			ELSIF (sender(WMEditors.Editor) = pAlign) THEN
				pAlign.GetAsString(tempString); Strings.LowerCase(tempString);
				IF (tempString = "left") THEN
					tempPStyle.alignment := 0;
					pAlign.SetAsString("Left");
				ELSIF (tempString = "center") THEN
					tempPStyle.alignment := 1;
					pAlign.SetAsString("Center");
				ELSIF (tempString = "right") THEN
					tempPStyle.alignment := 2;
					pAlign.SetAsString("Right");
				ELSIF (tempString = "justified") THEN
					tempPStyle.alignment := 3;
					pAlign.SetAsString("Justified");
				ELSE
					tempPStyle.alignment := 0;
					pAlign.SetAsString("Left");
				END;
			ELSIF (sender(WMEditors.Editor) = pFirstIndent) THEN
				pFirstIndent.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.firstIndent := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pFirstIndent.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = pLeftIndent) THEN
				pLeftIndent.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.leftIndent := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pLeftIndent.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = pRightIndent) THEN
				pRightIndent.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.rightIndent := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pRightIndent.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = pSpaceBefore) THEN
				pSpaceBefore.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.spaceBefore := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pSpaceBefore.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = pSpaceAfter) THEN
				pSpaceAfter.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.spaceAfter := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pSpaceAfter.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = pDefCharStyle) THEN
				pDefCharStyle.GetAsString(tempString);
				tempCharStyle := document.GetCharacterStyleByName(tempString);
				IF tempCharStyle # NIL THEN
					tempPStyle.charStyle := tempCharStyle;
				ELSE
					tempPStyle.charStyle := document.defaultCharacterStyle;
					pDefCharStyle.SetAsString(tempPStyle.charStyle.name);
				END;

			ELSIF (sender(WMEditors.Editor) = cName) THEN
				cName.GetAsString(tempString);
				COPY(tempString, tempCStyle.name);
			ELSIF (sender(WMEditors.Editor) = cFont) THEN
				cFont.GetAsString(tempString);
				COPY(tempString, tempCStyle.family);
				(* load font *)
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(tempCStyle.size)) THEN (* OR (tempFont.style # tempCStyle.style) *)
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (sender(WMEditors.Editor) = cStyle) THEN
				cStyle.GetAsString(tempString); Strings.LowerCase(tempString);
				IF (tempString = "regular") THEN
					tempCStyle.style := {};
					cStyle.SetAsString("Regular");
				ELSIF (tempString = "bold") THEN
					tempCStyle.style := {0};
					cStyle.SetAsString("Bold");
				ELSIF (tempString = "italic") THEN
					tempCStyle.style := {1};
					cStyle.SetAsString("Italic");
				ELSIF (tempString = "bold italic") THEN
					tempCStyle.style := {0, 1};
					cStyle.SetAsString("Bold Italic");
				ELSE
					tempCStyle.style := {};
					cStyle.SetAsString("Regular");
				END;
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(tempCStyle.size)) THEN
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (sender(WMEditors.Editor) = cSize) THEN
				cSize.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.size := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cSize.SetAsString(tempString);
				(* set leading to 120% of size *)
				tempLReal := tempLReal*1.2;
				tempCStyle.leading := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cLeading.SetAsString(tempString);
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(tempCStyle.size)) THEN
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (sender(WMEditors.Editor) = cLeading) THEN
				cLeading.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.leading := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cLeading.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = cBaselineShift) THEN
				cBaselineShift.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.baselineShift := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cBaselineShift.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = cColor) THEN
				cColor.GetAsString(tempString);
				Strings.HexStrToInt(tempString, tempInt, res);
				tempCStyle.color := tempInt;
				Strings.IntToHexStr(tempInt, 7, tempString);
				cColor.SetAsString(tempString);
				previewLabel.fontColor := tempInt; previewLabel.Invalidate;
			ELSIF (sender(WMEditors.Editor) = cBackColor) THEN
				cBackColor.GetAsString(tempString);
				Strings.HexStrToInt(tempString, tempInt, res);
				tempCStyle.bgColor := tempInt;
				Strings.IntToHexStr(tempInt, 7, tempString);
				cBackColor.SetAsString(tempString);
				previewLabel.fillColor.Set(tempInt); previewLabel.Invalidate;
			ELSIF (sender(WMEditors.Editor) = cTracking) THEN
				cTracking.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.tracking := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cTracking.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = cKerning) THEN
				cKerning.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.kerning := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cKerning.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = cStretchH) THEN
				cStretchH.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.scaleHorizontal := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cStretchH.SetAsString(tempString);
			ELSIF (sender(WMEditors.Editor) = cStretchV) THEN
				cStretchV.GetAsString(tempString);
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.scaleVertical := SHORT(tempLReal);
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cStretchV.SetAsString(tempString);

			ELSE
			END;
		END UpdateValueHandler;

		PROCEDURE UpdateList;
		VAR i : LONGINT;
		BEGIN
			pList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(document.pStyles))  & (document.pStyles[i] # NIL)) DO
				pList.model.SetNofRows(i+1);
				pList.model.SetCellText(0, i, Strings.NewString(document.pStyles[i].name));
				pList.model.SetCellData(0, i, document.pStyles[i]);
				INC(i);
			END;
			pList.SetSelection(0,i-1, 0, i-1);
			PClickSelected(NIL, pList.model.GetCellData(0, i-1));
			pList.model.Release;

			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(document.cStyles))  & (document.cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(document.cStyles[i].name));
				cList.model.SetCellData(0, i, document.cStyles[i]);
				INC(i);
			END;
			CClickSelected(NIL, cList.model.GetCellData(0, i-1));
			cList.SetSelection(0,i-1, 0, i-1);
			cList.model.Release;

		END UpdateList;

		PROCEDURE NewPHandler(sender, data: ANY);
		VAR newPStyle: DTPData.ParagraphStyleObject;
			tempString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(newPStyle);
			newPStyle.name := "newParagraphStyle";
			Strings.IntToStr(styleCounter, tempString);
			Strings.Append(newPStyle.name, tempString);
			newPStyle.alignment := 0;						(* Left Align *)
			newPStyle.spaceBefore := 0;
			newPStyle.spaceAfter := 0;
			newPStyle.leftIndent := 0;
			newPStyle.rightIndent := 0;
			newPStyle.firstIndent := 0;
			newPStyle.charStyle := document.defaultCharacterStyle;

			INC(styleCounter);
			document.AddStyle(newPStyle);
			UpdateList;
		END NewPHandler;

		PROCEDURE ImportPHandler(sender, data: ANY);
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "";
			IF WMDialogs.QueryString("Import Paragraph Styles from File:", filename) = WMDialogs.ResOk THEN
				ImportParagraphStyles(filename);
			END;
			UpdateList;
		END ImportPHandler;

		PROCEDURE ImportParagraphStyles(filename: ARRAY OF CHAR);
		VAR tempString : ARRAY 256 OF CHAR;
			tempReal : LONGREAL;
			reader : Files.Reader;
			parser : XMLParser.Parser;
			scanner : XMLScanner.Scanner;
			f : Files.File;
			XMLdocStyle : XML.Document;
			root: XML.Element;
			cont: XMLObjects.Enumerator;
			ptr: ANY;
			str: Strings.String;
			pStyle: DTPData.ParagraphStyleObject;
			cStyle: DTPData.CharacterStyleObject;
		BEGIN
			COPY(filename, tempString);
			Strings.Append(tempString, ".Style.XML");
			f := Files.Old(tempString);
			IF f = NIL THEN RETURN END;
			NEW(reader, f, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			XMLdocStyle := parser.Parse();

			root := XMLdocStyle.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();

					IF (str # NIL) & (str^ = "paragraph-style") THEN				(* paragraph styles *)
						NEW(pStyle);
						str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, pStyle.name) END;
						str := ptr(XML.Element).GetAttributeValue("alignment"); IF str # NIL THEN Strings.StrToInt(str^, pStyle.alignment) END;
						str := ptr(XML.Element).GetAttributeValue("first-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.firstIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("left-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.leftIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("right-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.rightIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("space-before"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceBefore := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("space-after"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceAfter := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("character-style");
						IF str # NIL THEN
							cStyle := document.GetCharacterStyleByName(str^);
							IF cStyle # NIL THEN pStyle.charStyle := cStyle; END;
						END;
						document.AddStyle(pStyle);
					END;
				END;
			END;

		END ImportParagraphStyles;

		PROCEDURE RemovePHandler(sender, data: ANY);
		BEGIN
			document.RemoveStyle(currentPStyle);
			UpdateList;
		END RemovePHandler;

		PROCEDURE ApplyPHandler(sender, data: ANY);
		VAR tempString : ARRAY 256 OF CHAR;
			tempLReal: LONGREAL;
			tempCharStyle : DTPData.CharacterStyleObject;
		BEGIN
			(* retrieve tempvalues first.. *)
			pName.GetAsString(tempString);
			COPY(tempString, tempPStyle.name);
			pAlign.GetAsString(tempString); Strings.LowerCase(tempString);
			IF (tempString = "left") THEN
				tempPStyle.alignment := 0;
				pAlign.SetAsString("Left");
			ELSIF (tempString = "center") THEN
				tempPStyle.alignment := 1;
				pAlign.SetAsString("Center");
			ELSIF (tempString = "right") THEN
				tempPStyle.alignment := 2;
				pAlign.SetAsString("Right");
			ELSIF (tempString = "justified") THEN
				tempPStyle.alignment := 3;
				pAlign.SetAsString("Justified");
			ELSE
				tempPStyle.alignment := 0;
				pAlign.SetAsString("Left");
			END;
			pFirstIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.firstIndent := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pFirstIndent.SetAsString(tempString);
			pLeftIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.leftIndent := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pLeftIndent.SetAsString(tempString);
			pRightIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.rightIndent := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pRightIndent.SetAsString(tempString);
			pSpaceBefore.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.spaceBefore := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pSpaceBefore.SetAsString(tempString);
			pSpaceAfter.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.spaceAfter := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pSpaceAfter.SetAsString(tempString);
			pDefCharStyle.GetAsString(tempString);
			tempCharStyle := document.GetCharacterStyleByName(tempString);
			IF tempCharStyle # NIL THEN
				tempPStyle.charStyle := tempCharStyle;
			ELSE
				tempPStyle.charStyle := document.defaultCharacterStyle;
				pDefCharStyle.SetAsString(tempPStyle.charStyle.name);
			END;

			(* update currentStyle with temp, refresh list *)
			currentPStyle.name := tempPStyle.name;
			currentPStyle.alignment := tempPStyle.alignment;
			currentPStyle.firstIndent := tempPStyle.firstIndent;
			currentPStyle.leftIndent := tempPStyle.leftIndent;
			currentPStyle.rightIndent := tempPStyle.rightIndent;
			currentPStyle.spaceBefore := tempPStyle.spaceBefore;
			currentPStyle.spaceAfter := tempPStyle.spaceAfter;
			currentPStyle.charStyle := tempPStyle.charStyle;

			LoadParagraphStyle(currentPStyle);
			UpdateList;
		END ApplyPHandler;

		PROCEDURE LoadParagraphStyle(pstyle : DTPData.ParagraphStyleObject);
		VAR style : Texts.ParagraphStyle;
			cstyle : Texts.CharacterStyle;
		BEGIN
			NEW(style);
			(* COPY(pstyle.name, style.name); *)
			COPY(oldPStyleName, style.name);
			style.alignment := pstyle.alignment;
			style.firstIndent := FloatToFixp(pstyle.firstIndent);
			style.leftIndent := FloatToFixp(pstyle.leftIndent);
			style.rightIndent := FloatToFixp(pstyle.rightIndent);
			style.spaceBefore := FloatToFixp(pstyle.spaceBefore);
			style.spaceAfter := FloatToFixp(pstyle.spaceAfter);
			NEW(cstyle);
			COPY(pstyle.charStyle.name, cstyle.name);
			COPY(pstyle.charStyle.family, cstyle.family);
			cstyle.style := pstyle.charStyle.style;
			cstyle.size := FloatToFixp(pstyle.charStyle.size);
			cstyle.leading := FloatToFixp(pstyle.charStyle.leading);
			cstyle.baselineShift := FloatToFixp(pstyle.charStyle.baselineShift);
			cstyle.color := pstyle.charStyle.color;
			cstyle.bgColor := pstyle.charStyle.bgColor;
			cstyle.tracking := FloatToFixp(pstyle.charStyle.tracking);
			(* cstyle.kerning := pstyle.charStyle.kerning; *)
			cstyle.scaleHorizontal := FloatToFixp(pstyle.charStyle.scaleHorizontal);
			cstyle.scaleVertical := FloatToFixp(pstyle.charStyle.scaleVertical);
			style.charStyle := cstyle;

			Texts.AddParagraphStyle(style);
			IF pstyle.name # oldPStyleName THEN
				style := Texts.GetParagraphStyleByName(oldPStyleName);
				IF style # NIL THEN COPY(pstyle.name, style.name); END;
			END;
		END LoadParagraphStyle;

		PROCEDURE NewCHandler(sender, data: ANY);
		VAR newCStyle: DTPData.CharacterStyleObject;
			tempString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(newCStyle);
			newCStyle.name := "newCharacterStyle";
			Strings.IntToStr(styleCounter, tempString);
			Strings.Append(newCStyle.name, tempString);
			newCStyle.family := "Oberon";
			newCStyle.style := {};
			newCStyle.size := 12;
			newCStyle.leading := 14;
			newCStyle.baselineShift := 0;
			newCStyle.tracking := 0;
			newCStyle.kerning := 0;
			newCStyle.scaleHorizontal := 100;
			newCStyle.scaleVertical := 100;
			newCStyle.color := 0000000FFH;
			newCStyle.bgColor := LONGINT(0FFFFFF00H);

			INC(styleCounter);
			document.AddStyle(newCStyle);
			UpdateList;
		END NewCHandler;

		PROCEDURE ImportCHandler(sender, data: ANY);
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "";
			IF WMDialogs.QueryString("Import Character Styles from File:", filename) = WMDialogs.ResOk THEN
				ImportCharacterStyles(filename);
			END;
			UpdateList;
		END ImportCHandler;

		PROCEDURE ImportCharacterStyles(filename: ARRAY OF CHAR);
		VAR tempString : ARRAY 256 OF CHAR;
			tempReal: LONGREAL;
			tempInt, res: LONGINT;
			reader : Files.Reader;
			parser : XMLParser.Parser;
			scanner : XMLScanner.Scanner;
			f : Files.File;
			XMLdocStyle : XML.Document;
			root: XML.Element;
			cont: XMLObjects.Enumerator;
			ptr: ANY;
			str: Strings.String;
			cStyle: DTPData.CharacterStyleObject;
		BEGIN
			COPY(filename, tempString);
			Strings.Append(tempString, ".Style.XML");
			f := Files.Old(tempString);
			IF f = NIL THEN RETURN END;
			NEW(reader, f, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			XMLdocStyle := parser.Parse();

			root := XMLdocStyle.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					(* KernelLog.String(str^); KernelLog.Ln; *)
					IF (str # NIL) & (str^ = "character-style") THEN					(* character styles *)
						NEW(cStyle);
						str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, cStyle.name) END;
						str := ptr(XML.Element).GetAttributeValue("font-family"); IF str # NIL THEN COPY(str^, cStyle.family) END;
						str := ptr(XML.Element).GetAttributeValue("font-style");
						IF str # NIL THEN
							IF (str^ = "0") THEN cStyle.style := {};
							ELSIF (str^ = "1") THEN cStyle.style := {0};
							ELSIF (str^ = "2") THEN cStyle.style := {1};
							ELSIF (str^ = "3") THEN cStyle.style := {0,1};
							ELSE cStyle.style := {};
							END;
						END;
						str := ptr(XML.Element).GetAttributeValue("font-size"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.size := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("leading"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.leading := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("baseline-shift"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.baselineShift := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("color"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.color := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("bgcolor"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.bgColor := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("tracking"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.tracking := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("kerning"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.kerning := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("h-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleHorizontal := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("v-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleVertical := SHORT(tempReal); END;
						document.AddStyle(cStyle);

					END;
				END;
			END;

		END ImportCharacterStyles;

		PROCEDURE RemoveCHandler(sender, data: ANY);
		BEGIN
			document.RemoveStyle(currentCStyle);
			UpdateList
		END RemoveCHandler;

		PROCEDURE ApplyCHandler(sender, data: ANY);
		VAR tempString : ARRAY 256 OF CHAR;
			tempLReal: LONGREAL;
			tempInt, res : LONGINT;
			tempFont : WMGraphics.Font;
		BEGIN
			(* retrieve tempvalues first for those who didn't press enter after changing a value... *)
			cName.GetAsString(tempString);
			COPY(tempString, tempCStyle.name);
			cFont.GetAsString(tempString);
			COPY(tempString, tempCStyle.family);
			cStyle.GetAsString(tempString); Strings.LowerCase(tempString);
			IF (tempString = "regular") THEN
				tempCStyle.style := {};
				cStyle.SetAsString("Regular");
			ELSIF (tempString = "bold") THEN
				tempCStyle.style := {0};
				cStyle.SetAsString("Bold");
			ELSIF (tempString = "italic") THEN
				tempCStyle.style := {1};
				cStyle.SetAsString("Italic");
			ELSIF (tempString = "bold italic") THEN
				tempCStyle.style := {0, 1};
				cStyle.SetAsString("Bold Italic");
			ELSE
				tempCStyle.style := {};
				cStyle.SetAsString("Regular");
			END;
			cSize.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.size := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cSize.SetAsString(tempString);
(*			tempLReal := tempLReal*1.2; *)
(*			tempCStyle.leading := SHORT(tempLReal); *)
			cLeading.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.leading := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cLeading.SetAsString(tempString);
			tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
			previewLabel.SetFont(tempFont); previewLabel.Invalidate;
			IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(tempCStyle.size)) THEN
				fontNotFound.visible.Set(TRUE);
			ELSE
				fontNotFound.visible.Set(FALSE);
			END;
			cLeading.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.leading := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cLeading.SetAsString(tempString);
			cBaselineShift.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.baselineShift := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cBaselineShift.SetAsString(tempString);
			cColor.GetAsString(tempString);
			Strings.HexStrToInt(tempString, tempInt, res);
			tempCStyle.color := tempInt;
			Strings.IntToHexStr(tempInt, 7, tempString);
			cColor.SetAsString(tempString);
			previewLabel.fontColor := tempInt; previewLabel.Invalidate;
			cBackColor.GetAsString(tempString);
			Strings.HexStrToInt(tempString, tempInt, res);
			tempCStyle.bgColor := tempInt;
			Strings.IntToHexStr(tempInt, 7, tempString);
			cBackColor.SetAsString(tempString);
			previewLabel.fillColor.Set(tempInt); previewLabel.Invalidate;
			cTracking.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.tracking := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cTracking.SetAsString(tempString);
			cKerning.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.kerning := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cKerning.SetAsString(tempString);
			cStretchH.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.scaleHorizontal := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cStretchH.SetAsString(tempString);
			cStretchV.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.scaleVertical := SHORT(tempLReal);
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cStretchV.SetAsString(tempString);

			(* update currentStyle with temp, refresh list *)
			currentCStyle.name := tempCStyle.name;
			currentCStyle.family := tempCStyle.family;
			currentCStyle.style := tempCStyle.style;
			currentCStyle.size := tempCStyle.size;
			currentCStyle.leading := tempCStyle.leading;
			currentCStyle.baselineShift := tempCStyle.baselineShift;
			currentCStyle.color := tempCStyle.color;
			currentCStyle.bgColor := tempCStyle.bgColor;
			currentCStyle.tracking := tempCStyle.tracking;
			currentCStyle.kerning := tempCStyle.kerning;
			currentCStyle.scaleHorizontal := tempCStyle.scaleHorizontal;
			currentCStyle.scaleVertical := tempCStyle.scaleVertical;

			LoadCharacterStyle(currentCStyle);
			UpdateList;
		END ApplyCHandler;

		PROCEDURE LoadCharacterStyle(cstyle : DTPData.CharacterStyleObject);
		VAR style : Texts.CharacterStyle;
		BEGIN
			NEW(style);
			(* COPY(cstyle.name, style.name); *)
			COPY(oldCStyleName, style.name);
			COPY(cstyle.family, style.family);
			style.style := cstyle.style;
			style.size := FloatToFixp(cstyle.size);
			style.leading := FloatToFixp(cstyle.leading);
			style.baselineShift := FloatToFixp(cstyle.baselineShift);
			style.color := cstyle.color;
			style.bgColor := cstyle.bgColor;
			style.tracking := FloatToFixp(cstyle.tracking);
			(* style.kerning := cstyle.kerning; *)
			style.scaleHorizontal := FloatToFixp(cstyle.scaleHorizontal);
			style.scaleVertical := FloatToFixp(cstyle.scaleVertical);

			Texts.AddCharacterStyle(style);
			IF cstyle.name # oldCStyleName THEN
				style := Texts.GetCharacterStyleByName(oldCStyleName);
				IF style # NIL THEN COPY(cstyle.name, style.name); END;
			END;
		END LoadCharacterStyle;

		PROCEDURE AlignHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			NEW(popup);
			popup.AddParButton("Left", AlignPopupHandler, ctxAlignLeft);
			popup.AddParButton("Center", AlignPopupHandler, ctxAlignCenter);
			popup.AddParButton("Right", AlignPopupHandler, ctxAlignRight);
			popup.AddParButton("Justified", AlignPopupHandler, ctxAlignJustified);
			handled := TRUE;

			popup.Popup(bounds.r-100, bounds.t+72);
		END AlignHandler;

		PROCEDURE AlignPopupHandler(sender, data: ANY);
		BEGIN
			IF (data # NIL) THEN
				popup.Close;
				IF data(ContextMenuData).val = 0 THEN
					pAlign.SetAsString("Left"); tempPStyle.alignment := 0;
				ELSIF data(ContextMenuData).val = 1 THEN
					pAlign.SetAsString("Center"); tempPStyle.alignment := 1;
				ELSIF data(ContextMenuData).val = 2 THEN
					pAlign.SetAsString("Right"); tempPStyle.alignment := 2;
				ELSIF data(ContextMenuData).val = 3 THEN
					pAlign.SetAsString("Justified"); tempPStyle.alignment := 3;
				ELSE
				END;
			END;
		END AlignPopupHandler;

		PROCEDURE StyleHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			NEW(popup);
			popup.AddParButton("Regular", StylePopupHandler, ctxRegular);
			popup.AddParButton("Bold", StylePopupHandler, ctxBold);
			popup.AddParButton("Italic", StylePopupHandler, ctxItalic);
			popup.AddParButton("Bold Italic", StylePopupHandler, ctxBoldItalic);
			handled := TRUE;

			popup.Popup(bounds.r-100, bounds.t+92);
		END StyleHandler;

		PROCEDURE StylePopupHandler(sender, data: ANY);
		VAR tempFont : WMGraphics.Font;
		BEGIN
			IF (data # NIL) THEN
				popup.Close;
				IF data(ContextMenuData).val = 0 THEN
					cStyle.SetAsString("Regular"); tempCStyle.style := {};
				ELSIF data(ContextMenuData).val = 1 THEN
					cStyle.SetAsString("Bold"); tempCStyle.style := {0};
				ELSIF data(ContextMenuData).val = 2 THEN
					cStyle.SetAsString("Italic"); tempCStyle.style := {1};
				ELSIF data(ContextMenuData).val = 3 THEN
					cStyle.SetAsString("Bold Italic"); tempCStyle.style := {0,1};
				ELSE
				END;
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(tempCStyle.size), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
			END;
		END StylePopupHandler;

		PROCEDURE ColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorChooser: ColorChooserWindow;
			result: LONGINT;
			replaceColor: BOOLEAN;
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(colorChooser);
			replaceColor := colorChooser.Show(bounds.r-190, bounds.t+172, result);
			IF replaceColor THEN
				Strings.IntToHexStr(result, 7, colorString);
				cColor.SetAsString(colorString);
				tempCStyle.color := result;
				previewLabel.fontColor := result; previewLabel.Invalidate;
			END;
			handled := TRUE;
		END ColorHandler;

		PROCEDURE BGColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorChooser: ColorChooserWindow;
			result: LONGINT;
			replaceColor: BOOLEAN;
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			NEW(colorChooser);
			replaceColor := colorChooser.Show(bounds.r-190, bounds.t+192, result);
			IF replaceColor THEN
				Strings.IntToHexStr(result, 7, colorString);
				cBackColor.SetAsString(colorString);
				tempCStyle.bgColor := result;
				previewLabel.fillColor.Set(result); previewLabel.Invalidate;
			END;
			handled := TRUE;

		END BGColorHandler;

	END StyleEditor;

	(* -- Helper Components -- *)
CONST
	BtnStyleSimple* = 0; BtnStyleRoundH* = 1; BtnStyleRoundV* = 2; BtnStyleGlass* = 3; BtnStyleElevator* = 4;

TYPE
	Tab* = OBJECT(WMStandardComponents.Button)
	VAR openSides* : SET;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			openSides := {};
		END Init;

(*		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		VAR mode, ul, mid, borderWidth, lr, xpos, ypos : LONGINT;
			 tc : WMGraphics.Color; img : WMGraphics.Image; r, rect : WMGraphics.Rectangle; down : BOOLEAN;
			 str : Strings.String;
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			down := pressed & (mouseOver OR isToggle.Get() OR keyboardPressed);
			IF down THEN mid := clPressed.Get(); tc := clTextPressed.Get(); img := imgPressed
			ELSIF mouseOver THEN 	mid := clHover.Get(); tc := clTextHover.Get();	img := imgHover
			ELSE mid := clDefault.Get();	tc := clTextDefault.Get(); img := imgDefault
			END;
			IF img = NIL THEN
				IF invert3d THEN down := ~down END;
				rect := GetClientRect();
				mode := WMGraphics.ModeSrcOverDst;
				borderWidth := 1;
				CASE style.Get() OF
					|BtnStyleRoundH : WMGraphicUtilities.FillRoundHorizontalBar(canvas, rect, down, mid, mode);
						IF ~isFlat.Get() THEN WMGraphicUtilities.DrawBevel(canvas, WMRectangles.ResizeRect(rect, 0), borderWidth, down, mid, mode) END
					|BtnStyleRoundV : WMGraphicUtilities.FillRoundVerticalBar(canvas, rect, down, mid, mode);
						IF ~isFlat.Get() THEN WMGraphicUtilities.DrawBevel(canvas, WMRectangles.ResizeRect(rect, 0), borderWidth, down, mid, mode) END
					|BtnStyleGlass : IF mid # 0 THEN canvas.Fill(rect, mid, mode) END
					|BtnStyleElevator :
						 IF clDefault.Get() # 0 THEN
						 	WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, 0), clDefault.Get(), mode);
(*						 	WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, -1), clDefault.Get(), mode);
*)						 	canvas.Fill(WMRectangles.ResizeRect(rect, -3), clDefault.Get(), mode);
						 END;
						 IF mid # 0 THEN
						 	WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, -1), mid, mode);
						 	WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, -2), mid, mode)
						 END
					ELSE canvas.Fill(rect, mid, mode);
						IF ~isFlat.Get() THEN WMGraphicUtilities.DrawBevel(canvas, WMRectangles.ResizeRect(rect, 0), borderWidth, down, mid, mode) END
				END;
			ELSE
				canvas.DrawImage(0, 0, img, WMGraphics.ModeSrcOverDst)
			END;
			IF hasFocus THEN WMGraphicUtilities.DrawRect(canvas, WMRectangles.ResizeRect(rect, -1), 0FF000080H, mode) END;
			IF image # NIL THEN canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst) END;
			str := caption.Get();
			IF str # NIL THEN
				r := GetClientRect();
				IF down THEN
					IF style.Get() IN {BtnStyleRoundH, BtnStyleRoundV, BtnStyleGlass} THEN
						WMRectangles.MoveRel(r, 1, 1)
					END
				END;
				canvas.SetColor(tc);
				WMGraphics.DrawStringInRect(canvas, r, FALSE, 1, 1, str^)
			END;
			IF style.Get() = BtnStyleGlass THEN
				IF effect3D.Get() > 0 THEN
					WMGraphicUtilities.ExtRectGlassShade(canvas, rect, openSides, effect3D.Get(), down)
				END
			ELSIF style.Get() = BtnStyleElevator THEN
				 (* WMGraphicUtilities.RectGlassShade(canvas, WMRectangles.ResizeRect(rect, - 3), 1, down)	*)
			END;
			Release
		END Draw;
*)
	END Tab;

	Checkbox* = OBJECT(WMComponents.VisualComponent)
	VAR caption* : ARRAY 64 OF CHAR;
		leftBorder*: LONGINT;
		font : WMGraphics.Font;
		checked*, default*, hasThreeStates*, inactive*: BOOLEAN;
		imgChecked, imgUnchecked, imgCheckedDefault, imgCheckedInactive, imgUncheckedInactive: WMGraphics.Image;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			caption := "";
			font := GetFont();
			leftBorder := 5;
			imgChecked := WMGraphics.LoadImage("checkboxchecked.gif" , TRUE);
			imgUnchecked := WMGraphics.LoadImage("checkboxunchecked.gif" , TRUE);
			imgCheckedDefault := WMGraphics.LoadImage("checkboxcheckedusedefault.gif" , TRUE);
			imgCheckedInactive := WMGraphics.LoadImage("checkboxcheckedinactive.gif" , TRUE);
			imgUncheckedInactive := WMGraphics.LoadImage("checkboxuncheckedinactive.gif" , TRUE);
			checked := FALSE; hasThreeStates := FALSE; inactive := FALSE;
		END Init;

		PROCEDURE PointerDown(x, y: LONGINT; keys: SET);
		BEGIN
			IF ~inactive THEN
				IF hasThreeStates THEN
					IF checked THEN checked := FALSE; default := FALSE;
					ELSE
						IF default THEN checked := TRUE; default := FALSE;
						ELSE checked := FALSE; default := TRUE;
						END;
					END;
				ELSE
					IF checked THEN checked := FALSE; ELSE checked := TRUE; END;
				END;
			END;
			Invalidate;
		END PointerDown;

		PROCEDURE Draw(canvas: WMGraphics.Canvas);
		VAR rect: WMRectangles.Rectangle;
		BEGIN
			Draw^(canvas);
			rect := GetClientRect();
			(* checkbox *)
			IF inactive THEN
				IF checked THEN
					IF imgCheckedInactive # NIL THEN
					canvas.DrawImage(leftBorder, ((rect.b-rect.t)-imgChecked.height) DIV 2, imgCheckedInactive, WMGraphics.ModeSrcOverDst);
					END;
				ELSE
					IF imgUncheckedInactive # NIL THEN
					canvas.DrawImage(leftBorder, ((rect.b-rect.t)-imgUnchecked.height) DIV 2, imgUncheckedInactive, WMGraphics.ModeSrcOverDst);
					END;
				END;
			ELSE
				IF hasThreeStates & default THEN
					IF imgCheckedDefault # NIL THEN
					canvas.DrawImage(leftBorder, ((rect.b-rect.t)-imgChecked.height) DIV 2, imgCheckedDefault, WMGraphics.ModeSrcOverDst);
					END;
				ELSE
					IF checked THEN
						IF imgChecked # NIL THEN
						canvas.DrawImage(leftBorder, ((rect.b-rect.t)-imgChecked.height) DIV 2, imgChecked, WMGraphics.ModeSrcOverDst);
						END;
					ELSE
						IF imgUnchecked # NIL THEN
						canvas.DrawImage(leftBorder, ((rect.b-rect.t)-imgUnchecked.height) DIV 2, imgUnchecked, WMGraphics.ModeSrcOverDst);
						END;
					END;
				END;
			END;
			(* caption *)
			canvas.DrawString(leftBorder+30, (((rect.b-rect.t)-font.GetHeight()) DIV 2) + font.ascent+1, caption);
		END Draw;

	END Checkbox;

	PreviewPanel* = OBJECT(WMStandardComponents.Label)
	VAR fontColor*: LONGINT;
		fontBackColor*: LONGINT;
		oldFont : WMGraphics.Font;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			fontColor := 0000000FFH;
			fontBackColor := LONGINT(0FFFFFFFFH);
			SetFont(WMGraphics.GetFont("Oberon", 16, {})); (* WMGraphics.FontBold *)
		END Init;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR str : Strings.String;
		BEGIN
			DrawBackground^(canvas); str := caption.Get();
			IF str # NIL THEN
				canvas.SetColor(fontColor);
				oldFont := canvas.GetFont(); canvas.SetFont(GetFont());
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, alignH.Get(), alignV.Get(), str^);
				canvas.SetFont(oldFont);
			END;
		END DrawBackground;

	END PreviewPanel;

	LinePanel* = OBJECT(WMStandardComponents.Panel)
	VAR isHorizontal: BOOLEAN;
		caption* : ARRAY 64 OF CHAR;
		captionColor*: LONGINT;
		captionFont : WMGraphics.Font;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			caption := "";
			captionFont := WMGraphics.GetFont("Oberon", 8, {});
			captionColor := 0000000FFH;
			isHorizontal := TRUE;
		END Init;

		PROCEDURE DrawBackground(canvas: WMGraphics.Canvas);
		VAR rect: WMRectangles.Rectangle;
			highlight, shadow, w, h, dist : LONGINT;
		BEGIN
			highlight := LONGINT(0FFFFFF80H);
			shadow := 000000080H;
			rect := GetClientRect();
			dist := (rect.b-rect.t) DIV 2;
			IF (caption = "") THEN
				canvas.Line(rect.l+3, dist, rect.r-4, dist, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+3, dist+1, rect.r-4, dist+1, highlight, WMGraphics.ModeSrcOverDst);
			ELSE
				captionFont.GetStringSize(caption, w, h);
				canvas.Line(rect.l+3, dist, rect.l+12, dist, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+3, dist+1, rect.l+12, dist+1, highlight, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+w+17, dist, rect.r-4, dist, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+w+17, dist+1, rect.r-4, dist+1, highlight, WMGraphics.ModeSrcOverDst);
				canvas.SetColor(captionColor);
				captionFont.RenderString(canvas, rect.l+15, dist+4, caption);
			END;
		END DrawBackground;

	END LinePanel;

	GroupPanel* = OBJECT(WMStandardComponents.Panel)
	VAR
		border : WMRectangles.Rectangle;
		caption*: ARRAY 64 OF CHAR;
		captionFont : WMGraphics.Font;
		centerContent, panel: WMStandardComponents.Panel;
		spacerLeft, spacerTop, spacerRight, spacerBottom : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			border := WMRectangles.MakeRect(10,14,10,10);
			caption := "";
			captionFont := WMGraphics.GetFont("Oberon", 8, {});
			CreateComponent;
		END Init;

		PROCEDURE CreateComponent;
		BEGIN
			(* build form with spacers *)
			NEW(spacerLeft); spacerLeft.bounds.SetWidth(border.l); spacerLeft.alignment.Set(WMComponents.AlignLeft);
			NEW(spacerTop); spacerTop.bounds.SetHeight(border.t); spacerTop.alignment.Set(WMComponents.AlignTop);
			NEW(spacerRight); spacerRight.bounds.SetWidth(border.r); spacerRight.alignment.Set(WMComponents.AlignRight);
			NEW(spacerBottom); spacerBottom.bounds.SetHeight(border.b); spacerBottom.alignment.Set(WMComponents.AlignBottom);
			NEW(centerContent); centerContent.alignment.Set(WMComponents.AlignClient);
			AddContent^(spacerTop);
			AddContent^(spacerBottom);
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(spacerLeft); panel.AddContent(spacerRight); panel.AddContent(centerContent);
			AddContent^(panel);

		END CreateComponent;

		PROCEDURE DrawBackground(canvas: WMGraphics.Canvas);
		VAR rect: WMRectangles.Rectangle;
			highlight, shadow, w, h : LONGINT;

		BEGIN
			highlight := LONGINT(0FFFFFF80H);
			shadow := 000000080H;
			rect := GetClientRect();
			(* canvas.Fill(rect, 0FF0000FFH, WMGraphics.ModeSrcOverDst); *)
			IF (caption = "") THEN
				canvas.Line(rect.l+3, rect.t+5, rect.r-4, rect.t+5, shadow, WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l+4, rect.t+6, rect.r-5, rect.t+6, highlight, WMGraphics.ModeSrcOverDst);
			ELSE
				captionFont.GetStringSize(caption, w, h);
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
			IF (caption # "") THEN
				captionFont.RenderString(canvas, rect.l+15, rect.t+9, caption);
			END;
		END DrawBackground;

		PROCEDURE UpdateBorder;
		BEGIN
			spacerLeft.bounds.SetWidth(border.l); spacerRight.bounds.SetWidth(border.r);
			spacerTop.bounds.SetHeight(border.t); spacerBottom.bounds.SetHeight(border.b);
			Invalidate;
		END UpdateBorder;

		PROCEDURE SetCaption*(string: ARRAY OF CHAR);
		BEGIN
			COPY(string, caption);
		END SetCaption;

		PROCEDURE AddContent*(content: XML.Content);
		BEGIN
			centerContent.AddContent(content);
		END AddContent;

	END GroupPanel;

	BorderPanel* = OBJECT(WMStandardComponents.Panel)
	VAR
		border* : WMRectangles.Rectangle;
		centerContent, panel: WMStandardComponents.Panel;
		spacerLeft, spacerTop, spacerRight, spacerBottom : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			border := WMRectangles.MakeRect(0,0,0,0);
			CreateComponent;
		END Init;

		PROCEDURE CreateComponent;
		BEGIN
			(* build form with spacers *)
			NEW(spacerLeft); spacerLeft.bounds.SetWidth(border.l); spacerLeft.alignment.Set(WMComponents.AlignLeft);
			NEW(spacerTop); spacerTop.bounds.SetHeight(border.t); spacerTop.alignment.Set(WMComponents.AlignTop);
			NEW(spacerRight); spacerRight.bounds.SetWidth(border.r); spacerRight.alignment.Set(WMComponents.AlignRight);
			NEW(spacerBottom); spacerBottom.bounds.SetHeight(border.b); spacerBottom.alignment.Set(WMComponents.AlignBottom);
			NEW(centerContent); centerContent.alignment.Set(WMComponents.AlignClient);
			AddContent^(spacerTop);
			AddContent^(spacerBottom);
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(spacerLeft); panel.AddContent(spacerRight); panel.AddContent(centerContent);
			AddContent^(panel);

		END CreateComponent;

		PROCEDURE UpdateBorder;
		BEGIN
			spacerLeft.bounds.SetWidth(border.l); spacerRight.bounds.SetWidth(border.r);
			spacerTop.bounds.SetHeight(border.t); spacerBottom.bounds.SetHeight(border.b);
			Invalidate;
		END UpdateBorder;

		PROCEDURE SetBorder*(left, top, right, bottom: LONGINT);
		BEGIN
			border := WMRectangles.MakeRect(left, top, right, bottom);
			UpdateBorder;
		END SetBorder;

		PROCEDURE GetBorder*(): WMRectangles.Rectangle;
		BEGIN
			RETURN border;
		END GetBorder;

		PROCEDURE AddContent(content: XML.Content);
		BEGIN
			centerContent.AddContent(content);
		END AddContent;

	END BorderPanel;

	CustomPanel* = OBJECT(WMStandardComponents.Panel)
	VAR
		border* : WMRectangles.Rectangle;
		centerContent, panel : WMStandardComponents.Panel;
		spacerLeft, spacerTop, spacerRight, spacerBottom : WMStandardComponents.Panel;

		caption* : ARRAY 128 OF CHAR;
		textColor* : LONGINT;
		font*: WMGraphics.Font;
		alignH*, alignV* : LONGINT;			(*	0:	AlignLeft/AlignTop				*)
											(*	1:	AlignCenter						*)
		 									(*	2:	AlignRight/Bottom				*)
		hasBevel* : BOOLEAN;
		bevelWidth* : LONGINT;
		bevelColor* : LONGINT;
		bevelDown* : BOOLEAN;

		hasInnerBevel* : BOOLEAN;
		innerBevelWidth* : LONGINT;
		innerBevelColor* : LONGINT;
		innerBevelDown* : BOOLEAN;

		hasGlass* : BOOLEAN;
		glassWidth* : LONGINT;
		glassDown* : BOOLEAN;
		glassOpenSides* : SET;

		img* : Raster.Image;
		imgBorderWidth* : LONGINT;
		altFillColor* : LONGINT;
		fillMode* : LONGINT;				(*	0:	Solid							*)
											(*	1:	Gradient Horizontal				*)
											(*	2:	Gradient Vertical				*)
											(*	3:	Gradient Reflected Horizontal	*)
											(*	4:	Gradient Reflected Vertical		*)
											(*	5:	Image Streched					*)
											(* 	6:	Image Repeating				*)
											(* 	7:	Image Special					*)
											(* 	8:	Image Border Special			*)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			border := WMRectangles.MakeRect(0,0,0,0);
			caption := ""; textColor := 0000000FFH; alignH := 0; alignV := 0;
			hasBevel := FALSE; bevelWidth := 5; bevelColor := LONGINT(088888888H); bevelDown := FALSE;
			hasInnerBevel := FALSE; innerBevelWidth := 5; innerBevelColor := LONGINT(088888888H); innerBevelDown := TRUE;
			hasGlass := FALSE; glassWidth := 5; glassDown := TRUE; glassOpenSides := {};
			altFillColor := fillColor.Get(); fillMode := 0;
			CreateComponent;
		END Init;

		PROCEDURE CreateComponent;
		BEGIN
			(* build form with spacers *)
			NEW(spacerLeft); spacerLeft.bounds.SetWidth(border.l); spacerLeft.alignment.Set(WMComponents.AlignLeft);
			NEW(spacerTop); spacerTop.bounds.SetHeight(border.t); spacerTop.alignment.Set(WMComponents.AlignTop);
			NEW(spacerRight); spacerRight.bounds.SetWidth(border.r); spacerRight.alignment.Set(WMComponents.AlignRight);
			NEW(spacerBottom); spacerBottom.bounds.SetHeight(border.b); spacerBottom.alignment.Set(WMComponents.AlignBottom);
			NEW(centerContent); centerContent.alignment.Set(WMComponents.AlignClient); centerContent.fillColor.Set(LONGINT(0FF8800FFH));
			AddContent^(spacerTop);
			AddContent^(spacerBottom);
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(spacerLeft); panel.AddContent(spacerRight); panel.AddContent(centerContent);
			AddContent^(panel);

		END CreateComponent;

		PROCEDURE UpdateBorder;
		BEGIN
			spacerLeft.bounds.SetWidth(border.l); spacerRight.bounds.SetWidth(border.r);
			spacerTop.bounds.SetHeight(border.t); spacerBottom.bounds.SetHeight(border.b);
			Invalidate;
		END UpdateBorder;

		PROCEDURE SetBorder*(left, top, right, bottom: LONGINT);
		BEGIN
			border := WMRectangles.MakeRect(left, top,right, bottom);
			UpdateBorder;
		END SetBorder;

		PROCEDURE GetBorder*(): WMRectangles.Rectangle;
		BEGIN
			RETURN border;
		END GetBorder;

		PROCEDURE AddContent(content: XML.Content);
		BEGIN
			centerContent.AddContent(content);
		END AddContent;

		PROCEDURE Draw(canvas: WMGraphics.Canvas);
		VAR rect, rect1, rect2: WMRectangles.Rectangle;
			color, mode: LONGINT;
		BEGIN
			(* DrawBackground(canvas); *)
			rect := GetClientRect(); color := fillColor.Get(); mode := WMGraphics.ModeSrcOverDst;
			CASE fillMode OF
					0:	canvas.Fill(rect, color, mode);
				|	1:	WMGraphicUtilities.FillGradientHorizontal(canvas, rect, color, altFillColor, mode);
				|	2:	WMGraphicUtilities.FillGradientVertical(canvas, rect, color, altFillColor, mode);
				|	3:	rect1 := WMRectangles.MakeRect(rect.l, rect.t, (rect.r-rect.l) DIV 2, rect.b);
						rect2 := WMRectangles.MakeRect((rect.r-rect.l) DIV 2, rect.t, rect.r, rect.b);
						WMGraphicUtilities.FillGradientHorizontal(canvas, rect1, color, altFillColor, mode);
						WMGraphicUtilities.FillGradientHorizontal(canvas, rect2, altFillColor, color, mode);
				|	4:	rect1 := WMRectangles.MakeRect(rect.l, rect.t, rect.r, (rect.b-rect.t) DIV 2);
						rect2 := WMRectangles.MakeRect(rect.l, (rect.b-rect.t) DIV 2, rect.r, rect.b);
						WMGraphicUtilities.FillGradientHorizontal(canvas, rect1, color, altFillColor, mode);
						WMGraphicUtilities.FillGradientHorizontal(canvas, rect2, altFillColor, color, mode);
				|	5:	IF img # NIL THEN
							canvas.ScaleImage(img, WMRectangles.MakeRect(0,0, img.width, img.height), rect, mode, WMRasterScale.ScaleBox);
						END;
				|   	6:	DrawRepeating(canvas, rect, img, mode);
				|   	7:	(* not yet implemented *)
				|   	8: 	(* not yet implemented *)
(*				|	9:	WMGraphicUtilities.FillRoundHorizontalBar(canvas, rect, TRUE, color, mode);
				|   10:	WMGraphicUtilities.FillRoundVerticalBar(canvas, rect, TRUE, color, mode);
				|   11:	WMGraphicUtilities.FillRoundHorizontalBar(canvas, rect, FALSE, color, mode);
				|   12:	WMGraphicUtilities.FillRoundVerticalBar(canvas, rect, FALSE, color, mode);
*)			ELSE
			END;
			(* Draw Bevel *)
			IF hasBevel THEN
				WMGraphicUtilities.DrawBevel(canvas, rect, bevelWidth, bevelDown, bevelColor, mode);
			END;
			(* Draw Inner Bevel *)
			IF hasInnerBevel THEN
				rect1 := WMRectangles.MakeRect(rect.l+border.l-innerBevelWidth, rect.t+border.t-innerBevelWidth, rect.r-border.r+innerBevelWidth, rect.b-border.b+innerBevelWidth);
				WMGraphicUtilities.DrawBevel(canvas, rect1, innerBevelWidth, innerBevelDown, innerBevelColor, mode);
			END;
			(* Draw Glass *)
			IF hasGlass THEN
				WMGraphicUtilities.ExtRectGlassShade(canvas, rect, glassOpenSides, glassWidth, glassDown);
			END;
			(* Draw Caption *)
			IF caption # "" THEN
				canvas.SetColor(textColor); canvas.SetFont(font);
				WMGraphics.DrawStringInRect(canvas, rect, FALSE, alignH, alignV, caption);
			END;
			(* Draw Content *)
			DrawSubComponents(canvas);
			DrawForeground(canvas);
		END Draw;

		PROCEDURE DrawRepeating(canvas: WMGraphics.Canvas; rectangle: WMRectangles.Rectangle; image: Raster.Image; mode: LONGINT);

		END DrawRepeating;

	END CustomPanel;


(* ----------------------------------------------- *)

VAR
	ctxAlignLeft, ctxAlignCenter, ctxAlignRight, ctxAlignJustified: ContextMenuData;
	ctxRegular, ctxBold, ctxItalic, ctxBoldItalic: ContextMenuData;

PROCEDURE Min*(a, b: REAL): REAL;
BEGIN
	IF a <= b THEN RETURN a ELSE RETURN b END;
END Min;

PROCEDURE Max*(a, b: REAL): REAL;
BEGIN
	IF a >= b THEN RETURN a ELSE RETURN b END;
END Max;

PROCEDURE Inc*(VAR a, b: REAL);
BEGIN
	a := a + b;
END Inc;

PROCEDURE Dec*(VAR a, b: REAL);
BEGIN
	a := a - b;
END Dec;

(* converts a 16.16 fixpoint integer to float *)
PROCEDURE FixpToFloat*(x: LONGINT): REAL;
BEGIN
	RETURN (x / 65536);
END FixpToFloat;

(* converts a float into a 16.16 fixpoint integer *)
PROCEDURE FloatToFixp*(x: REAL): LONGINT;
BEGIN
	IF x > 65536 THEN x := 65536; RETURN ENTIER(x);
	ELSE RETURN ENTIER(x * (65536));
	END;
END FloatToFixp;

PROCEDURE OutReal*(input: REAL; digits: LONGINT);
VAR tempString: ARRAY 64 OF CHAR;
BEGIN
	Strings.FloatToStr(input, 0, digits, 0, tempString);
	KernelLog.String(tempString);
END OutReal;

PROCEDURE ROUND*(input: REAL): LONGINT;
VAR output: LONGINT;
BEGIN
	output := ENTIER(input+0.5);
	RETURN output;
END ROUND;

PROCEDURE RANDOM*(upperBound, lowerBound: LONGINT): LONGINT;
CONST
	a = 16807; m = 2147483647; q = m DIV a; r = m MOD a;
VAR random, seed, unused, gamma: LONGINT;
BEGIN
	(* get a seed *)
	Dates.DateTimeToOberon(Dates.Now(), unused, seed);

	(* calc *)
	gamma := a*(seed MOD q) - r*(seed DIV q);
	IF gamma > 0 THEN
		seed := gamma;
	ELSE
		seed := gamma + m;
	END;
	random := ENTIER(seed/m*(upperBound-lowerBound)) + lowerBound;
	RETURN random;
END RANDOM;


BEGIN
	NEW(ctxAlignLeft, AlignLeft);
	NEW(ctxAlignCenter, AlignCenter);
	NEW(ctxAlignRight, AlignRight);
	NEW(ctxAlignJustified, AlignJustified);
	NEW(ctxRegular, StyleRegular);
	NEW(ctxBold, StyleBold);
	NEW(ctxItalic, StyleItalic);
	NEW(ctxBoldItalic, StyleBoldItalic);

END DTPUtilities.


-----------------------------
Normal
Highlight
Types and Procedures
Lock Acquire / Lock Release
Preferred notation (comment)
Unsafe / Temporary / Stupid / requires attention
Permanent Comment
Assertion
Debug
