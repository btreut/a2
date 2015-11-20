MODULE WMTextStyleTool;	(** AUTHOR "TF"; PURPOSE "Text Tool"; *)

IMPORT
	Commands, Streams, Texts, Strings, WMComponents, WMRestorable, WMStringGrids, WMGrids,
	WMEditors, WMGraphics, WMMessages, WMStandardComponents, Modules,
	WMPopups, WMRectangles, WMDialogs, FP1616, Files, XMLParser, XMLScanner, XML, XMLObjects,
	WM := WMWindowManager;

CONST
	AlignLeft = 0; AlignCenter = 1; AlignRight = 2; AlignJustified = 3;
	StyleRegular = 0; StyleBold = 1; StyleItalic = 2; StyleBoldItalic = 3;

	(* field parameter for Change procedure *)
	ChangeFont = {0};
	ChangeSize = {1};
	ChangeStyle = {2};
	ChangeFgColor = {3};
	ChangeBgColor = {4};

	(* mode parameter for Change procedure *)
	Absolute = 0;
	IncrementBy = 1;
	DecrementBy = 2;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	ContextMenuData = OBJECT
	VAR val: LONGINT;

		PROCEDURE &New*(val: LONGINT);
		BEGIN
			SELF.val := val;
		END New;
	END ContextMenuData;

TYPE

	ChangeInfo= OBJECT (Texts.Attributes)
	VAR
		fields : SET; (* which fields should be changed *)
		name : ARRAY 128 OF CHAR;
		deltaSizeMode : LONGINT; (* Interpretation of deltasize field: Absolute, IncrementBy, DecrementBy *)
		deltaSize : LONGINT;
		fgColor, bgColor : LONGINT;
		style : SET;

		PROCEDURE &Init*;
		BEGIN
			fields := {};
			deltaSizeMode := 0;
			deltaSize := 0;
			fgColor := 0; bgColor := 0;
			style := {};
		END Init;

	END ChangeInfo;

TYPE

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		bold, lock, comment, stupid, assert, preferred, debug, normal,
		highlight, adhoc, more, edit, link, label: WMStandardComponents.Button;
		winpanel : WMStandardComponents.Panel;
		cList : WMStringGrids.StringGrid;
		styleEditor : StyleEditor;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;

			PROCEDURE AB(panel : WMStandardComponents.Panel; btn: WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignLeft); btn.bounds.SetWidth(60); panel.AddContent(btn)
			END AB;

		BEGIN
			NEW(panel); panel.bounds.SetExtents(120, 140); panel.takesFocus.Set(TRUE);

			(* link & label*)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(link); link.caption.SetAOC("Add Link"); AB(toolbar, link); link.clDefault.Set(080CC80H);
			NEW(label); label.caption.SetAOC("Add Label"); AB(toolbar, label); label.clDefault.Set(080CC80H);

			(* styles *)
			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(bold); bold.caption.SetAOC("Bold"); AB(toolbar, bold);
			NEW(lock); lock.caption.SetAOC("Lock"); AB(toolbar, lock);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(comment); comment.caption.SetAOC("Comment"); AB(toolbar, comment);
			NEW(debug); debug.caption.SetAOC("Debug"); AB(toolbar, debug);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(stupid); stupid.caption.SetAOC("Stupid"); AB(toolbar, stupid);
			NEW(assert); assert.caption.SetAOC("Assert"); AB(toolbar, assert);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(preferred); preferred.caption.SetAOC("Preferred"); AB(toolbar, preferred);
			NEW(normal); normal.caption.SetAOC("Normal"); AB(toolbar, normal);

			(**)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(highlight); highlight.caption.SetAOC("Highlight"); AB(toolbar, highlight);
			NEW(adhoc); adhoc.caption.SetAOC("AdHoc"); AB(toolbar, adhoc); adhoc.clDefault.Set(0CC0080H);

			(* style edit *)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(more); more.caption.SetAOC("More"); AB(toolbar, more); more.clDefault.Set(0CC000080H);
			NEW(edit); edit.caption.SetAOC("Edit"); AB(toolbar, edit); edit.clDefault.Set(0CC000080H); edit.visible.Set(FALSE);

			(* List *)
			NEW(cList); cList.alignment.Set(WMComponents.AlignClient);
			cList.onClick.Add(SetStyleFromList); cList.clCell.Set(0FFFFFFCCH); cList.clHover.Set(0FFFF00CCH);
			cList.model.Acquire;
			cList.model.SetNofCols(1);
			cList.model.SetNofRows(1);
			cList.SetSelectionMode(WMGrids.GridSelectSingleRow);
			cList.model.Release;
			panel.AddContent(cList);

			winpanel := panel;
			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
			xml : XML.Element;
			 s : Strings.String;
			 temp : BOOLEAN;
		BEGIN
			IncCount;
			vc := CreateForm();

			bold.onClick.Add(SetStyle);
			lock.onClick.Add(SetStyle);
			comment.onClick.Add(SetStyle);
			debug.onClick.Add(SetStyle);
			stupid.onClick.Add(SetStyle);
			assert.onClick.Add(SetStyle);
			preferred.onClick.Add(SetStyle);
			normal.onClick.Add(SetStyle);
			highlight.onClick.Add(SetStyle);
			(* adhoc style *)
			adhoc.onClick.Add(AdHocStyle);
			(* style editor *)
			more.onClick.Add(ShowList);
			edit.onClick.Add(EditStyles);

			link.onClick.Add(AddLink);
			label.onClick.Add(AddLabel);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			BuildList;

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					xml := c.appData(XML.Element);
					s := xml.GetAttributeValue("expanded");
					IF s # NIL THEN Strings.StrToBool(s^, temp) END;
					IF temp THEN
						more.caption.SetAOC("Less");
						edit.visible.Set(TRUE);
					END;
				END;
				Resized(GetWidth(), GetHeight());
			ELSE  WM.AddWindow(SELF, 50, 50)
			 END;
			SetTitle(Strings.NewString("Text Styles"))
		END New;

		(* -- Handlers -- *)

		PROCEDURE AdHocStyle(sender, data : ANY);
		VAR adhocStyle : AdHocStyleWindow;
		BEGIN
			NEW(adhocStyle)
		END AdHocStyle;

		PROCEDURE EditStyles(sender, data: ANY);
		BEGIN
			IF styleEditor = NIL THEN
				NEW(styleEditor);
				styleEditor.UpdateProc := BuildList;
			END;
			styleEditor.Show(200, 150);
		END EditStyles;

		PROCEDURE ShowList(sender, data: ANY);
		VAR caption : Strings.String;
			button : WMStandardComponents.Button;
			width, height : LONGINT;
		BEGIN
			button :=  sender(WMStandardComponents.Button);
			caption :=  button.caption.Get();
			manager := WM.GetDefaultManager();
			IF caption^ = "More" THEN
				button.caption.SetAOC("Less");
				width := GetWidth(); height := GetHeight()+ 300;
				edit.visible.Set(TRUE);
			ELSE
				button.caption.SetAOC("More");
				width := GetWidth(); height := 140;
				edit.visible.Set(FALSE);
			END;
			manager.SetWindowSize(SELF, width, height); Resized(width, height);
		END ShowList;

		PROCEDURE BuildList;
		VAR styles : Texts.CharacterStyleArray;
		i : LONGINT;
		BEGIN
			styles := Texts.GetCharacterStyleArray();
			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(styles))  & (styles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(styles[i].name));
				cList.model.SetCellData(0, i, styles[i]);
				INC(i);
			END;
			cList.model.Release;
		END  BuildList;

		PROCEDURE SetStyleFromList(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			a, b: LONGINT;
			cStyle : Texts.CharacterStyle;
		BEGIN
			IF (data # NIL ) THEN
				cStyle := data(Texts.CharacterStyle);
				IF Texts.GetLastSelection(text, from, to) THEN
				text.AcquireWrite;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				text.SetCharacterStyle(a, b - a, cStyle);
				text.ReleaseWrite
				END
			END;
		END SetStyleFromList;

		PROCEDURE SetStyle(sender, data : ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			a, b: LONGINT;
			cStyle : Texts.CharacterStyle;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN

				IF sender = bold THEN
					cStyle := Texts.GetCharacterStyleByName("Bold");
				ELSIF sender = lock THEN
					cStyle := Texts.GetCharacterStyleByName("Lock");
				ELSIF sender = preferred THEN
					cStyle := Texts.GetCharacterStyleByName("Preferred");
				ELSIF sender = assert THEN
					cStyle := Texts.GetCharacterStyleByName("Assertion");
				ELSIF sender = comment THEN
					cStyle := Texts.GetCharacterStyleByName("Comment");
				ELSIF sender = debug THEN
					cStyle := Texts.GetCharacterStyleByName("Debug");
				ELSIF sender = stupid THEN
					cStyle := Texts.GetCharacterStyleByName("Stupid");
				ELSIF sender = normal THEN
					cStyle := Texts.GetCharacterStyleByName("Normal");
				ELSIF sender = highlight THEN
					cStyle := Texts.GetCharacterStyleByName("Highlight");
				END;
				text.AcquireWrite;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				text.SetCharacterStyle(a, b - a, cStyle);
				text.ReleaseWrite
			END
		END SetStyle;

		PROCEDURE AddLink(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			a, b: LONGINT;
			tempLink: ARRAY 2083 OF CHAR;
			link : Texts.Link;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				IF WMDialogs.QueryString("Enter Link", tempLink) = WMDialogs.ResOk THEN
					link := Strings.NewString(tempLink);
					text.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					b := Strings.Max(from.GetPosition(), to.GetPosition());
					text.SetLink(a, b - a, link);
					text.ReleaseWrite
				END
			END
		END AddLink;

		PROCEDURE AddLabel(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			a: LONGINT;
			label : ARRAY 256 OF CHAR;
			lp : Texts.LabelPiece;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				IF WMDialogs.QueryString("Enter Label", label) = WMDialogs.ResOk THEN
					NEW(lp); lp.label := Strings.NewString(label);
					text.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					text.InsertPiece(a, lp);
					text.ReleaseWrite
				END
			END
		END AddLabel;

		PROCEDURE Close;
		BEGIN
			IF styleEditor # NIL THEN styleEditor.Close END;
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR data : XML.Element; a : XML.Attribute; n, str: ARRAY 32 OF CHAR;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data);  n := "TextStyleToolData"; data.SetName(n);
					NEW(a); n := "expanded"; a.SetName(n); Strings.BoolToStr(edit.visible.Get(), str); a.SetValue(str); data.AddAttribute(a);
					x.ext(WMRestorable.Storage).Add("WMTextStyleTool", "WMTextStyleTool.Restore", SELF, data)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

	(* Graphical User Interface to add AdHoc-Styles *)
	AdHocStyleWindow* = OBJECT(WMComponents.FormWindow)
	VAR
		get, apply: WMStandardComponents.Button;
		famEdit, sizeEdit, styleEdit, colorEdit, bgColEdit: WMEditors.Editor;
		styleB, colB, bgColB : WMStandardComponents.Button;
		popup : WMPopups.Popup;
		cStyle : Texts.CharacterStyle;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			label : WMStandardComponents.Label;
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;
			manager : WM.WindowManager;
			windowStyle : WM.WindowStyle;

			PROCEDURE AB(panel : WMStandardComponents.Panel; btn: WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignLeft); btn.bounds.SetWidth(60); panel.AddContent(btn)
			END AB;

			PROCEDURE AL(panel : WMStandardComponents.Panel; lbl : WMStandardComponents.Label);
			BEGIN
				lbl.alignment.Set(WMComponents.AlignLeft); lbl.bounds.SetWidth(45); label.textColor.Set(0000000FFH);
				lbl.fillColor.Set(windowStyle.bgColor); panel.AddContent(lbl)
			END AL;

			PROCEDURE AE(panel : WMStandardComponents.Panel; edtr : WMEditors.Editor);
			BEGIN
				edtr.alignment.Set(WMComponents.AlignClient); edtr.multiLine.Set(FALSE); edtr.fillColor.Set(0FFFFFF88H); edtr.tv.showBorder.Set(TRUE);
				edtr.tv.textAlignV.Set(WMGraphics.AlignCenter);
				edtr.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); edtr.tv.defaultTextBgColor.Set(0FFFFFF88H);
				panel.AddContent(edtr)
			END AE;

			PROCEDURE AD(panel : WMStandardComponents.Panel; btn : WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignRight); btn.bounds.SetWidth(17); panel.AddContent(btn)
			END AD;

		BEGIN
			NEW(panel); panel.bounds.SetExtents(120, 120); panel.takesFocus.Set(TRUE);
			manager := WM.GetDefaultManager();
			windowStyle := manager.GetStyle();

			(* Get/Apply *)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(get); get.caption.SetAOC("Get"); AB(toolbar, get); get.clDefault.Set(088000088H);
			NEW(apply); apply.caption.SetAOC("Apply"); AB(toolbar, apply); apply.clDefault.Set(088000088H);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC(" Font:"); AL(toolbar, label);
			NEW(famEdit); famEdit.SetAsString("Oberon"); AE(toolbar, famEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC(" Size:"); AL(toolbar, label);
			NEW(sizeEdit); sizeEdit.SetAsString("10"); AE(toolbar, sizeEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC(" Style:"); AL(toolbar, label);
			NEW(styleB); styleB.caption.SetAOC("+"); AD(toolbar, styleB);
			NEW(styleEdit); styleEdit.SetAsString("Regular"); AE(toolbar, styleEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC(" Color:"); AL(toolbar, label);
			NEW(colB); colB.caption.SetAOC("+"); AD(toolbar, colB);
			NEW(colorEdit); colorEdit.SetAsString("000000FF"); AE(toolbar, colorEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC(" BGCol:"); AL(toolbar, label);
			NEW(bgColB); bgColB.caption.SetAOC("+"); AD(toolbar, bgColB);
			NEW(bgColEdit); bgColEdit.SetAsString("00000000"); AE(toolbar, bgColEdit);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();

			get.onClick.Add(GetStyle);
			apply.onClick.Add(SetCustomStyle);
			styleB.SetExtPointerDownHandler(StyleDrop);
			colB.SetExtPointerDownHandler(ColorHandler);
			bgColB.SetExtPointerDownHandler(BGColorHandler);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			WM.ExtAddWindow(SELF, 50, 50, {WM.FlagStayOnTop, WM.FlagFrame, WM.FlagClose, WM.FlagMinimize});
			SetTitle(Strings.NewString("AdHoc Text Styles"))
		END New;

		PROCEDURE GetStyle(sender, data : ANY);
		VAR text : Texts.Text; from, to : Texts.TextPosition;
			utilreader : Texts.TextReader; tempString : ARRAY 256 OF CHAR;
			a, b, ch, temp : LONGINT;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				text.AcquireWrite;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				NEW(utilreader, text);
				utilreader.SetPosition(a);
				utilreader.ReadCh(ch);
				IF (utilreader.cstyle = NIL) & (utilreader.attributes = NIL) THEN
					famEdit.SetAsString("Oberon");
					sizeEdit.SetAsString("10");
					styleEdit.SetAsString("regular");
					colorEdit.SetAsString("000000FF");
					bgColEdit.SetAsString("00000000");
				ELSIF (utilreader.cstyle # NIL) THEN
					cStyle := utilreader.cstyle;
					famEdit.SetAsString(cStyle.family);
					temp := ENTIER(FP1616.FixpToFloat(cStyle.size));
					Strings.IntToStr(temp, tempString);
					sizeEdit.SetAsString(tempString);
					IF cStyle.style = {} THEN
						styleEdit.SetAsString("Regular");
					ELSIF cStyle.style = {0} THEN
						styleEdit.SetAsString("Bold");
					ELSIF cStyle.style = {1} THEN
						styleEdit.SetAsString("Italic");
					ELSIF cStyle.style = {0,1} THEN
						styleEdit.SetAsString("Bold Italic");
					ELSE
						styleEdit.SetAsString("Regular");
					END;
					Strings.IntToHexStr(cStyle.color, 7, tempString);
					colorEdit.SetAsString(tempString);
					Strings.IntToHexStr(cStyle.bgColor, 7, tempString);
					bgColEdit.SetAsString(tempString);
				ELSIF (utilreader.attributes # NIL) THEN
					famEdit.SetAsString(utilreader.attributes.fontInfo.name);
					Strings.IntToStr(utilreader.attributes.fontInfo.size, tempString);
					sizeEdit.SetAsString(tempString);
					IF utilreader.attributes.fontInfo.style = {} THEN
						styleEdit.SetAsString("Regular");
					ELSIF utilreader.attributes.fontInfo.style = {0} THEN
						styleEdit.SetAsString("Bold");
					ELSIF utilreader.attributes.fontInfo.style = {1} THEN
						styleEdit.SetAsString("Italic");
					ELSIF utilreader.attributes.fontInfo.style = {0,1} THEN
						styleEdit.SetAsString("Bold Italic");
					ELSE
						styleEdit.SetAsString("Regular");
					END;
					Strings.IntToHexStr(utilreader.attributes.color, 7, tempString);
					colorEdit.SetAsString(tempString);
					Strings.IntToHexStr(utilreader.attributes.bgcolor, 7, tempString);
					bgColEdit.SetAsString(tempString);
				END;
				text.ReleaseWrite
			END;
		END GetStyle;

		PROCEDURE SetCustomStyle(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			cStyle : Texts.CharacterStyle;
			a, b: LONGINT;
			style : SET;
			fgColor, bgColor : LONGINT;
			name, tempString: ARRAY 256 OF CHAR;
			res, size : LONGINT;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				(* create new AdHoc Style *)
				NEW(cStyle);
				famEdit.GetAsString(name);
				COPY(name, cStyle.family);
				sizeEdit.GetAsString(tempString);
				Strings.StrToInt(tempString, size);
				size := FP1616.FloatToFixp(size);
				cStyle.size := size;
				styleEdit.GetAsString(tempString);
				IF tempString = "Regular" THEN style := {};
				ELSIF tempString = "Bold" THEN style := {0};
				ELSIF tempString = "Italic" THEN style := {1};
				ELSIF tempString = "Bold Italic" THEN style := {0, 1};
				ELSE
					style := {};
				END;
				cStyle.style := style;
				colorEdit.GetAsString(tempString);
				Strings.HexStrToInt(tempString, fgColor, res);
				cStyle.color := fgColor;
				bgColEdit.GetAsString(tempString);
				Strings.HexStrToInt(tempString, bgColor, res);
				cStyle.bgColor := bgColor;
				(* create AdHoc Name *)
				size := ENTIER(FP1616.FixpToFloat(size));
				CreateStyleName(name, style, size, fgColor, bgColor, cStyle.name);

				(* Set the style *)
				text.AcquireWrite;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				text.SetCharacterStyle(a, b - a, cStyle);
				text.ReleaseWrite
			END
		END SetCustomStyle;

		PROCEDURE StyleDrop(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			NEW(popup);
			popup.Add("Regular", StylePopupHandler);
			popup.Add("Bold", StylePopupHandler);
			popup.Add("Italic", StylePopupHandler);
			popup.Add("Bold Italic", StylePopupHandler);
			handled := TRUE;

			popup.Popup(bounds.r-100, bounds.t+80);
		END StyleDrop;

		PROCEDURE StylePopupHandler(sender, data: ANY);
		VAR button: WMStandardComponents.Button;
			tempString: Strings.String;
		BEGIN
			popup.Close;
			IF sender IS WMStandardComponents.Button THEN
				button := sender(WMStandardComponents.Button);
				tempString := button.caption.Get();
				IF (tempString^ = "Regular") THEN
					styleEdit.SetAsString("Regular");
				ELSIF (tempString^ = "Bold") THEN
					styleEdit.SetAsString("Bold");
				ELSIF (tempString^ = "Italic") THEN
					styleEdit.SetAsString("Italic");
				ELSIF (tempString^ = "Bold Italic") THEN
					styleEdit.SetAsString("Bold Italic");
				ELSE
					styleEdit.SetAsString("Regular");
				END;
			END;
		END StylePopupHandler;

		PROCEDURE ColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorPanel : WMPopups.ColorSwatchPopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.onColorChosen := ColorPopupHandler;
			colorPanel.Popup(bounds.r-190, bounds.t+100);

			handled := TRUE;
		END ColorHandler;

		PROCEDURE ColorPopupHandler(result: LONGINT);
		VAR
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToHexStr(result, 7, colorString);
			colorEdit.SetAsString(colorString);
		END ColorPopupHandler;

		PROCEDURE BGColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorPanel: WMPopups.ColorSwatchPopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.onColorChosen := BGColorPopupHandler;
			colorPanel.Popup(bounds.r-190, bounds.t+220);

			handled := TRUE;
		END BGColorHandler;

		PROCEDURE BGColorPopupHandler(result: LONGINT);
		VAR
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToHexStr(result, 7, colorString);
			bgColEdit.SetAsString(colorString);
		END BGColorPopupHandler;

		PROCEDURE Close;
		BEGIN
			Close^;
		END Close;

	END AdHocStyleWindow;

	(* Graphical User Interface to create & edit Text Styles *)
	StyleEditor* = OBJECT(WMComponents.FormWindow)
	VAR
		shown : BOOLEAN; popup: WMPopups.Popup;
		oldPStyleName, oldCStyleName: ARRAY 256 OF CHAR;
		tabColor, tabSelectedColor : LONGINT;
		previewLabel, fontNotFound : WMStandardComponents.Label;
		tabPanel, buttonPanel, pstylePanel, cstylePanel : WMStandardComponents.Panel;
		pstyleButton, cstyleButton, button : WMStandardComponents.Button;
		pName, pAlign, pFirstIndent, pLeftIndent, pRightIndent, pSpaceBefore, pSpaceAfter, pDefCharStyle,
		cName, cFont, cSize, cStyle, cBaselineShift, cLeading, cColor, cBackColor, cTracking, cStretchH, cStretchV: WMEditors.Editor;
		pList, cList: WMStringGrids.StringGrid;

		UpdateProc* : PROCEDURE {DELEGATE};

		currentPStyle, tempPStyle : Texts.ParagraphStyle;
		currentCStyle, tempCStyle : Texts.CharacterStyle;
		pStyles: Texts.ParagraphStyleArray;
		cStyles: Texts.CharacterStyleArray;

		vc : WMComponents.VisualComponent;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, mainPanel, gridPanel, propertyPanel : WMStandardComponents.Panel;
			groupPanel : WMStandardComponents.GroupPanel;
			label : WMStandardComponents.Label;
			labelWidth : LONGINT;
			resizerH: WMStandardComponents.Resizer;
			manager : WM.WindowManager;
			windowStyle : WM.WindowStyle;

			PROCEDURE CreateEditor(): WMEditors.Editor;
			VAR editor: WMEditors.Editor;
			BEGIN
				NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
				editor.multiLine.Set(FALSE); editor.fillColor.Set(0FFFFFFFFH); editor.tv.showBorder.Set(TRUE);
				editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
				editor.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); editor.onEnter.Add(UpdateValueHandler);
				RETURN editor
			END CreateEditor;

			PROCEDURE CreateLabel(CONST caption : ARRAY OF CHAR): WMStandardComponents.Label;
			VAR label: WMStandardComponents.Label;
			BEGIN
				NEW(label); label.bounds.SetWidth(labelWidth); label.caption.SetAOC(caption);
				label.alignment.Set(WMComponents.AlignLeft);
				RETURN label
			END CreateLabel;

		BEGIN
			labelWidth := 130;
			tabColor := 0008000FFH;
			tabSelectedColor := 000CC00FFH;
			manager := WM.GetDefaultManager();
			windowStyle := manager.GetStyle();

			NEW(mainPanel); mainPanel.bounds.SetExtents(500, 420); mainPanel.fillColor.Set(windowStyle.bgColor);
			mainPanel.takesFocus.Set(TRUE);

			(* -- tabs -- *)
			NEW(tabPanel); tabPanel.bounds.SetHeight(20); tabPanel.fillColor.Set(0CCCCCCFFH);
			tabPanel.alignment.Set(WMComponents.AlignTop);
			NEW(pstyleButton); pstyleButton.caption.SetAOC("Paragraph"); pstyleButton.alignment.Set(WMComponents.AlignLeft);
			pstyleButton.onClick.Add(TabHandler); pstyleButton.clDefault.Set(tabSelectedColor);
			NEW(cstyleButton); cstyleButton.caption.SetAOC("Character"); cstyleButton.alignment.Set(WMComponents.AlignLeft);
			cstyleButton.onClick.Add(TabHandler); cstyleButton.clDefault.Set(tabColor);
			(* tabPanel.AddContent(pstyleButton); *)
			(* tabPanel.AddContent(cstyleButton); *)
			mainPanel.AddContent(tabPanel);

			(* -- paragraph style -- *)
			NEW(pstylePanel); pstylePanel.alignment.Set(WMComponents.AlignClient);
			pstylePanel.visible.Set(FALSE);
			mainPanel.AddContent(pstylePanel);
			NEW(gridPanel); gridPanel.alignment.Set(WMComponents.AlignClient);
			gridPanel.fillColor.Set(0FFFFFFFFH);
			NEW(pList); pList.alignment.Set(WMComponents.AlignClient);
			pList.onClick.Add(PClickSelected);
			pList.model.Acquire;
			pList.model.SetNofCols(1);
			pList.model.SetNofRows(1);
			pList.SetSelectionMode(WMGrids.GridSelectSingleRow);
			pList.model.Release;
			gridPanel.AddContent(pList);
			pstylePanel.AddContent(gridPanel);
			NEW(propertyPanel); propertyPanel.alignment.Set(WMComponents.AlignClient);
			pstylePanel.AddContent(propertyPanel);

			NEW(label); label.bounds.SetHeight(13); label.alignment.Set(WMComponents.AlignTop);
			propertyPanel.AddContent(label);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Paragraph Style Name:"); panel.AddContent(label);
			pName := CreateEditor(); panel.AddContent(pName);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Alignment:"); panel.AddContent(label);
			NEW(button); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			button.SetExtPointerDownHandler(AlignHandler); button.bounds.SetWidth(20); panel.AddContent(button);
			pAlign := CreateEditor(); panel.AddContent(pAlign);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" First Line Indent:"); panel.AddContent(label);
			pFirstIndent := CreateEditor(); panel.AddContent(pFirstIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Left Line Indent:"); panel.AddContent(label);
			pLeftIndent := CreateEditor(); panel.AddContent(pLeftIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Right Line Indent:"); panel.AddContent(label);
			pRightIndent := CreateEditor(); panel.AddContent(pRightIndent);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Space Before:"); panel.AddContent(label);
			pSpaceBefore := CreateEditor(); panel.AddContent(pSpaceBefore);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Space After:"); panel.AddContent(label);
			pSpaceAfter := CreateEditor(); panel.AddContent(pSpaceAfter);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Default Char Style:"); panel.AddContent(label);
			pSpaceAfter := CreateEditor(); panel.AddContent(pSpaceAfter);
			propertyPanel.AddContent(panel);

			(* -- paragraph panel buttons -- *)
			NEW(buttonPanel); buttonPanel.bounds.SetHeight(20); buttonPanel.fillColor.Set(08888FFFFH);
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
			cstylePanel.visible.Set(TRUE);
			mainPanel.AddContent(cstylePanel);
			NEW(gridPanel); gridPanel.bounds.SetWidth(200); gridPanel.alignment.Set(WMComponents.AlignLeft);
			gridPanel.fillColor.Set(0FFFFFFFFH);
			NEW(cList); cList.alignment.Set(WMComponents.AlignClient);
			cList.onClick.Add(CClickSelected);
			cList.model.Acquire;
			cList.model.SetNofCols(1);
			cList.model.SetNofRows(1);
			cList.SetSelectionMode(WMGrids.GridSelectSingleRow);
			cList.model.Release;
			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignRight);
			resizerH.bounds.SetWidth(4);
			gridPanel.AddContent(resizerH);
			gridPanel.AddContent(cList);
			cstylePanel.AddContent(gridPanel);

			NEW(propertyPanel); propertyPanel.alignment.Set(WMComponents.AlignClient);
			cstylePanel.AddContent(propertyPanel);

			NEW(label); label.bounds.SetHeight(13); label.alignment.Set(WMComponents.AlignTop);
			propertyPanel.AddContent(label);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Character Style Name:"); panel.AddContent(label);
			cName := CreateEditor(); panel.AddContent(cName);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Font Name:"); panel.AddContent(label);
			cFont := CreateEditor(); panel.AddContent(cFont);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Font Style:"); panel.AddContent(label);
			NEW(button); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			button.SetExtPointerDownHandler(StyleHandler); button.bounds.SetWidth(20); panel.AddContent(button);
			cStyle := CreateEditor(); panel.AddContent(cStyle);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Font Size:"); panel.AddContent(label);
			cSize := CreateEditor(); panel.AddContent(cSize);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Leading:"); panel.AddContent(label);
			cLeading := CreateEditor(); panel.AddContent(cLeading);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Baseline Shift:"); panel.AddContent(label);
			cBaselineShift := CreateEditor(); panel.AddContent(cBaselineShift);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Font Color:"); panel.AddContent(label);
			NEW(button); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			button.SetExtPointerDownHandler(ColorHandler); button.bounds.SetWidth(20); panel.AddContent(button);
			cColor := CreateEditor(); panel.AddContent(cColor);
			propertyPanel.AddContent(panel);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Font BG Color:"); panel.AddContent(label);
			NEW(button); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignRight);
			button.SetExtPointerDownHandler(BGColorHandler); button.bounds.SetWidth(20); panel.AddContent(button);
			cBackColor := CreateEditor(); panel.AddContent(cBackColor);
			propertyPanel.AddContent(panel);

	(* --- not used yet ---> 	*)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Tracking:"); panel.AddContent(label);
			cTracking := CreateEditor(); panel.AddContent(cTracking);
			(* propertyPanel.AddContent(panel);	*)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Stretch Horizontal:"); panel.AddContent(label);
			cStretchH := CreateEditor(); panel.AddContent(cStretchH);
			(* propertyPanel.AddContent(panel);	*)

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			label := CreateLabel(" Stretch Vertical:"); panel.AddContent(label);
			cStretchV := CreateEditor(); panel.AddContent(cStretchV);
			(* propertyPanel.AddContent(panel);	*)

	(* 		<---------------- *)

			(* preview panel *)
			NEW(panel); panel.bounds.SetHeight(15); panel.alignment.Set(WMComponents.AlignTop); propertyPanel.AddContent(panel);
			NEW(groupPanel); groupPanel.alignment.Set(WMComponents.AlignTop); groupPanel.caption.SetAOC("Preview:"); groupPanel.bounds.SetHeight(80);
			NEW(previewLabel); previewLabel.fillColor.Set(0FFFFFFFFH); previewLabel.alignment.Set(WMComponents.AlignClient);
			previewLabel.caption.SetAOC("The quick brown Fox jumped over the lazy Dog"); previewLabel.alignH.Set(1); previewLabel.alignV.Set(1);
			groupPanel.AddContent(previewLabel); propertyPanel.AddContent(groupPanel);
			NEW(fontNotFound); fontNotFound.bounds.SetHeight(20); fontNotFound.alignment.Set(WMComponents.AlignTop);
			fontNotFound.caption.SetAOC("  ERROR: Font not found! - using DefaultFont"); fontNotFound.visible.Set(FALSE);
			propertyPanel.AddContent(fontNotFound); fontNotFound.textColor.Set(0FF0000FFH);

			(* -- character style buttons -- *)
			NEW(buttonPanel); buttonPanel.bounds.SetHeight(20); buttonPanel.fillColor.Set(windowStyle.bgColor);
			buttonPanel.alignment.Set(WMComponents.AlignBottom);

			NEW(button); button.caption.SetAOC("Apply"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ApplyCHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Delete"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(RemoveCHandler);
			buttonPanel.AddContent(button);

			NEW(button); button.caption.SetAOC("Export"); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(ExportCHandler);
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

		PROCEDURE &New*;
		VAR
		BEGIN
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Style Editor"));

			pStyles := Texts.GetParagraphStyleArray();
			cStyles := Texts.GetCharacterStyleArray();
		END New;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			LoadStyleList;
			IF ~shown THEN	shown := TRUE;
			ELSE Hide; shown := TRUE; END;
			manager := WM.GetDefaultManager();
			WM.AddWindow(SELF, x, y);
			manager.SetFocus(SELF);
			cList.SetSelection(0,0,0,0)
		END Show;

		PROCEDURE Hide*;
		BEGIN
			IF shown THEN
				shown := FALSE;
				manager := WM.GetDefaultManager();
				manager.Remove(SELF);
			END;
		END Hide;

		PROCEDURE Close*;
		BEGIN
			Close^;
			IF UpdateProc # NIL THEN UpdateProc END;
			shown := FALSE;
		END Close;

		PROCEDURE LoadStyleList;
		VAR i : LONGINT;
		BEGIN
			vc.Acquire;
			pList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(pStyles))  & (pStyles[i] # NIL)) DO
				pList.model.SetNofRows(i+1);
				pList.model.SetCellText(0, i, Strings.NewString(pStyles[i].name));
				pList.model.SetCellData(0, i, pStyles[i]);
				INC(i);
			END;
			pList.model.Release;

			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(cStyles))  & (cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(cStyles[i].name));
				cList.model.SetCellData(0, i, cStyles[i]);
				INC(i);
			END;
			IF i >  0 THEN CClickSelected(NIL, cList.model.GetCellData(0, 0)); END;
			cList.model.Release;
			vc.Release;

		END LoadStyleList;

		PROCEDURE TabHandler(sender, data: ANY);
		BEGIN
			IF (sender # NIL) & (sender IS WMStandardComponents.Button) THEN
				IF sender = pstyleButton THEN
					cstylePanel.visible.Set(FALSE); cstyleButton.clDefault.Set(tabColor);
					pstylePanel.visible.Set(TRUE); pstyleButton.clDefault.Set(tabSelectedColor);
				ELSIF sender = cstyleButton THEN
					pstylePanel.visible.Set(FALSE); pstyleButton.clDefault.Set(tabColor);
					cstylePanel.visible.Set(TRUE); cstyleButton.clDefault.Set(tabSelectedColor);
				ELSE

				END;
			END;
		END TabHandler;

		PROCEDURE PClickSelected(sender, data: ANY);
		VAR tempString: ARRAY 64 OF CHAR;
		BEGIN
			IF (data # NIL) THEN
				currentPStyle := data(Texts.ParagraphStyle);
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
				currentCStyle := data(Texts.CharacterStyle);
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
				Strings.FloatToStr(FP1616.FixpToFloat(currentCStyle.size), 0,4,0, tempString);
				cSize.SetAsString(tempString);
				Strings.FloatToStr(FP1616.FixpToFloat(currentCStyle.leading), 0,4,0, tempString);
				cLeading.SetAsString(tempString);
				Strings.FloatToStr(currentCStyle.baselineShift, 0,4,0, tempString);
				cBaselineShift.SetAsString(tempString);
				Strings.IntToHexStr(currentCStyle.color, 7, tempString);
				cColor.SetAsString(tempString);
				Strings.IntToHexStr(currentCStyle.bgColor, 7, tempString);
				cBackColor.SetAsString(tempString);
				Strings.FloatToStr(FP1616.FixpToFloat(currentCStyle.tracking), 0,4,0, tempString);
				cTracking.SetAsString(tempString);
				Strings.FloatToStr(FP1616.FixpToFloat(currentCStyle.scaleHorizontal), 0,4,0, tempString);
				cStretchH.SetAsString(tempString);
				Strings.FloatToStr(FP1616.FixpToFloat(currentCStyle.scaleVertical), 0,4,0, tempString);
				cStretchV.SetAsString(tempString);
				COPY(currentCStyle.name, oldCStyleName);

				(* update preview *)
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.fillColor.Set(tempCStyle.bgColor);
				previewLabel.textColor.Set(tempCStyle.color); previewLabel.Invalidate;
			END;
		END CClickSelected;

		PROCEDURE UpdateValueHandler(sender, data: ANY);
		VAR tempString : ARRAY 64 OF CHAR;
			tempLReal : LONGREAL;
			tempInt, res : LONGINT;
			tempCharStyle : Texts.CharacterStyle;
			tempFont : WMGraphics.Font;
			tempEditor : WMEditors.Editor;
		BEGIN
			(* paragraph style *)
			IF sender IS WMEditors.Editor THEN
				tempEditor := sender(WMEditors.Editor);
				tempEditor.GetAsString(tempString);
			END;

			IF (tempEditor = pName) THEN
				COPY(tempString, tempPStyle.name);
			ELSIF (tempEditor = pAlign) THEN
				Strings.LowerCase(tempString);
				IF (tempString = "left") THEN tempPStyle.alignment := 0; pAlign.SetAsString("Left");
				ELSIF (tempString = "center") THEN tempPStyle.alignment := 1; pAlign.SetAsString("Center");
				ELSIF (tempString = "right") THEN tempPStyle.alignment := 2; pAlign.SetAsString("Right");
				ELSIF (tempString = "justified") THEN tempPStyle.alignment := 3; pAlign.SetAsString("Justified");
				ELSE tempPStyle.alignment := 0; pAlign.SetAsString("Left"); END;
			ELSIF (tempEditor = pFirstIndent) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.firstIndent := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pFirstIndent.SetAsString(tempString);
			ELSIF (tempEditor = pLeftIndent) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.leftIndent := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pLeftIndent.SetAsString(tempString);
			ELSIF (tempEditor = pRightIndent) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.rightIndent := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pRightIndent.SetAsString(tempString);
			ELSIF (tempEditor = pSpaceBefore) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.spaceBefore := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pSpaceBefore.SetAsString(tempString);
			ELSIF (tempEditor = pSpaceAfter) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempPStyle.spaceAfter := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				pSpaceAfter.SetAsString(tempString);
			ELSIF (tempEditor = pDefCharStyle) THEN
				tempCharStyle := Texts.GetCharacterStyleByName(tempString);
				IF tempCharStyle # NIL THEN
					tempPStyle.charStyle := tempCharStyle;
				ELSE
					tempPStyle.charStyle := Texts.GetCharacterStyleByName("Normal");
					pDefCharStyle.SetAsString(tempPStyle.charStyle.name);
				END;

			(* character style *)
			ELSIF (tempEditor = cName) THEN
				COPY(tempString, tempCStyle.name);
			ELSIF (tempEditor = cFont) THEN
				COPY(tempString, tempCStyle.family);
				(* load font *)
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(FP1616.FixpToFloat(tempCStyle.size))) THEN (* OR (tempFont.style # tempCStyle.style) *)
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (tempEditor = cStyle) THEN
				Strings.LowerCase(tempString);
				IF (tempString = "regular") THEN tempCStyle.style := {}; cStyle.SetAsString("Regular");
				ELSIF (tempString = "bold") THEN tempCStyle.style := {0}; cStyle.SetAsString("Bold");
				ELSIF (tempString = "italic") THEN tempCStyle.style := {1}; cStyle.SetAsString("Italic");
				ELSIF (tempString = "bold italic") THEN tempCStyle.style := {0, 1}; cStyle.SetAsString("Bold Italic");
				ELSE tempCStyle.style := {}; cStyle.SetAsString("Regular"); END;
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(FP1616.FixpToFloat(tempCStyle.size))) THEN
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (tempEditor = cSize) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.size := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cSize.SetAsString(tempString);
				(* set leading to 120% of size *)
				tempLReal := tempLReal*1.2;
				tempCStyle.leading := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cLeading.SetAsString(tempString);
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
				IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(FP1616.FixpToFloat(tempCStyle.size))) THEN
					fontNotFound.visible.Set(TRUE);
				ELSE
					fontNotFound.visible.Set(FALSE);
				END;
			ELSIF (tempEditor = cLeading) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.leading := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cLeading.SetAsString(tempString);
			ELSIF (tempEditor = cBaselineShift) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.baselineShift := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cBaselineShift.SetAsString(tempString);
			ELSIF (tempEditor = cColor) THEN
				Strings.HexStrToInt(tempString, tempInt, res);
				tempCStyle.color := tempInt;
				Strings.IntToHexStr(tempInt, 7, tempString);
				cColor.SetAsString(tempString);
				previewLabel.textColor.Set(tempInt); previewLabel.Invalidate;
			ELSIF (tempEditor = cBackColor) THEN
				Strings.HexStrToInt(tempString, tempInt, res);
				tempCStyle.bgColor := tempInt;
				Strings.IntToHexStr(tempInt, 7, tempString);
				cBackColor.SetAsString(tempString);
				previewLabel.fillColor.Set(tempInt); previewLabel.Invalidate;
			ELSIF (tempEditor = cTracking) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.tracking := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cTracking.SetAsString(tempString);
			ELSIF (tempEditor = cStretchH) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.scaleHorizontal := FP1616.FloatToFixp(SHORT(tempLReal));
				Strings.FloatToStr(tempLReal, 0,4,0, tempString);
				cStretchH.SetAsString(tempString);
			ELSIF (tempEditor = cStretchV) THEN
				Strings.StrToFloat(tempString, tempLReal);
				tempCStyle.scaleVertical := FP1616.FloatToFixp(SHORT(tempLReal));
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
			WHILE ((i<LEN(pStyles))  & (pStyles[i] # NIL)) DO
				pList.model.SetNofRows(i+1);
				pList.model.SetCellText(0, i, Strings.NewString(pStyles[i].name));
				pList.model.SetCellData(0, i, pStyles[i]);
				INC(i);
			END;
			pList.model.Release;

			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(cStyles))  & (cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(cStyles[i].name));
				cList.model.SetCellData(0, i, cStyles[i]);
				INC(i);
			END;
			cList.model.Release;
			UpdateProc;
			SendUpdateMsg;

		END UpdateList;

		PROCEDURE SendUpdateMsg;
		VAR changed : Texts.StyleChangedMsg;
			 msg : WMMessages.Message;
			 m : WM.WindowManager;
		BEGIN
			NEW(changed); msg.ext := changed; msg.msgType := WMMessages.MsgExt;
			m := WM.GetDefaultManager();
			m.Broadcast(msg);
		END SendUpdateMsg;

		PROCEDURE NewPHandler(sender, data: ANY);
		VAR newPStyle: Texts.ParagraphStyle;
			tempString: ARRAY 256 OF CHAR;
		BEGIN
			NEW(newPStyle);
			tempString := "newParagraphStyle";
			WHILE Texts.GetParagraphStyleByName(tempString) # NIL DO
				Strings.Append(tempString, "Copy");
			END;
			Strings.Append(newPStyle.name, tempString);
			newPStyle.alignment := 0;						(* Left Align *)
			newPStyle.spaceBefore := 0;
			newPStyle.spaceAfter := 0;
			newPStyle.leftIndent := 0;
			newPStyle.rightIndent := 0;
			newPStyle.firstIndent := 0;
			newPStyle.charStyle := Texts.GetCharacterStyleByName("Normal");
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

		PROCEDURE ImportParagraphStyles(CONST filename: ARRAY OF CHAR);
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
			pStyle: Texts.ParagraphStyle;
			cStyle: Texts.CharacterStyle;
		BEGIN
			COPY(filename, tempString);
			Strings.Append(tempString, ".XML");
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
						str := ptr(XML.Element).GetAttributeValue("first-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.firstIndent := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("left-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.leftIndent := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("right-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.rightIndent := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("space-before"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceBefore := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("space-after"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceAfter := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("character-style");
						IF str # NIL THEN
							cStyle := Texts.GetCharacterStyleByName(str^);
							IF cStyle # NIL THEN pStyle.charStyle := cStyle; END;
						END;
						Texts.AddParagraphStyle(pStyle);
					END;
				END;
			END;

		END ImportParagraphStyles;

		PROCEDURE RemovePHandler(sender, data: ANY);
		BEGIN
			Texts.RemoveParagraphStyle(currentPStyle);
			UpdateList;
		END RemovePHandler;

		PROCEDURE ApplyPHandler(sender, data: ANY);
		VAR tempString : ARRAY 256 OF CHAR;
			tempLReal: LONGREAL;
			tempCharStyle : Texts.CharacterStyle;
		BEGIN
			(* retrieve tempvalues first.. *)
			pName.GetAsString(tempString);
			COPY(tempString, tempPStyle.name);
			pAlign.GetAsString(tempString); Strings.LowerCase(tempString);
			IF (tempString = "left") THEN tempPStyle.alignment := 0; pAlign.SetAsString("Left");
			ELSIF (tempString = "center") THEN tempPStyle.alignment := 1; pAlign.SetAsString("Center");
			ELSIF (tempString = "right") THEN tempPStyle.alignment := 2;	pAlign.SetAsString("Right");
			ELSIF (tempString = "justified") THEN tempPStyle.alignment := 3; pAlign.SetAsString("Justified");
			ELSE tempPStyle.alignment := 0; pAlign.SetAsString("Left"); END;
			pFirstIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.firstIndent := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pFirstIndent.SetAsString(tempString);
			pLeftIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.leftIndent := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pLeftIndent.SetAsString(tempString);
			pRightIndent.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.rightIndent := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pRightIndent.SetAsString(tempString);
			pSpaceBefore.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.spaceBefore := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pSpaceBefore.SetAsString(tempString);
			pSpaceAfter.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempPStyle.spaceAfter := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			pSpaceAfter.SetAsString(tempString);
			pDefCharStyle.GetAsString(tempString);
			tempCharStyle := Texts.GetCharacterStyleByName(tempString);
			IF tempCharStyle # NIL THEN
				tempPStyle.charStyle := tempCharStyle;
			ELSE
				tempPStyle.charStyle := Texts.GetCharacterStyleByName("Normal");
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
			UpdateList;
		END ApplyPHandler;

		PROCEDURE NewCHandler(sender, data: ANY);
		VAR newCStyle: Texts.CharacterStyle;
			name : ARRAY 256 OF CHAR;
		BEGIN
			NEW(newCStyle);
			IF (currentCStyle # NIL) & (currentCStyle.name # "") THEN
				COPY(currentCStyle.name, name);
			ELSE
				COPY("NewCharacterStyle", name);
			END;
			WHILE Texts.GetCharacterStyleByName(name) # NIL DO
				Strings.Append(name, "Copy");
			END;
			COPY(name, newCStyle.name);

			IF currentCStyle = NIL THEN
				newCStyle.family := "Oberon";
				newCStyle.style := {};
				newCStyle.size := FP1616.FloatToFixp(12.0);
				newCStyle.leading := FP1616.FloatToFixp(14.0);
				newCStyle.baselineShift := 0;
				newCStyle.tracking := 0;
				newCStyle.scaleHorizontal := FP1616.FloatToFixp(100.0);
				newCStyle.scaleVertical := FP1616.FloatToFixp(100.0);
				newCStyle.color := 0000000FFH;
				newCStyle.bgColor := LONGINT(0FFFFFF00H);
			ELSE
				(* copy selected style *)
				COPY(currentCStyle.family, newCStyle.family);
				newCStyle.style := currentCStyle.style;
				newCStyle.size := currentCStyle.size;
				newCStyle.leading := currentCStyle.leading;
				newCStyle.baselineShift := currentCStyle.baselineShift;
				newCStyle.tracking := currentCStyle.tracking;
				newCStyle.scaleHorizontal := currentCStyle.scaleHorizontal;
				newCStyle.scaleVertical := currentCStyle.scaleVertical;
				newCStyle.color := currentCStyle.color;
				newCStyle.bgColor := currentCStyle.bgColor;
			END;

			Texts.AddCharacterStyle(newCStyle);
			UpdateList;
		END NewCHandler;

		PROCEDURE ExportCHandler(sender, data: ANY);
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "UserTextStyles";
			IF WMDialogs.QueryString("Export Character Styles to File:", filename) = WMDialogs.ResOk THEN
				ExportCharacterStyles(filename);
			END;
		END ExportCHandler;

		PROCEDURE ExportCharacterStyles(CONST filename: ARRAY OF CHAR);
		VAR i : LONGINT; style : SET;
			tempString : ARRAY 256 OF CHAR;
			w : Files.Writer; f : Files.File;
			cStyle : Texts.CharacterStyle;
		BEGIN
			(* -- Save Style File -- *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".XML");
			f := Files.New(tempString); IF f = NIL THEN RETURN END;
			Files.OpenWriter(w, f, 0);
			w.String('<?xml version="1.0" encoding="UTF-8"?>'); w.Ln;
			w.String("<styles>"); w.Ln;

			(* processing character styles *)
			i := 0;
			WHILE ((i<LEN(cStyles)) & (cStyles[i] #NIL)) DO
				cStyle := cStyles[i];
				w.String('<character-style name="'); w.String(cStyle.name);
				w.String('" font-family="'); w.String(cStyle.family);
				w.String('" font-style="'); style := cStyle.style;
				IF (style = {}) THEN
					w.Int(0, 0);
				ELSIF (style = {0}) THEN
					w.Int(1, 0);
				ELSIF (style = {1}) THEN
					w.Int(2, 0);
				ELSIF (style = {0,1}) THEN
					w.Int(3, 0);
				ELSE
					w.Int(0, 0);
				END;
				w.String('" font-size="');	 Strings.FloatToStr(FP1616.FixpToFloat(cStyle.size), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" leading="');  Strings.FloatToStr(FP1616.FixpToFloat(cStyle.leading), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" baseline-shift="');  Strings.FloatToStr(FP1616.FixpToFloat(cStyle.baselineShift), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" color="'); w.Hex(cStyle.color, 8);
				w.String('" bgcolor="');  w.Hex(cStyle.bgColor, 8);
				w.String('" tracking="');  Strings.FloatToStr(FP1616.FixpToFloat(cStyle.tracking), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" h-scale="');  Strings.FloatToStr(FP1616.FixpToFloat(cStyle.scaleHorizontal), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" v-scale="');  Strings.FloatToStr(FP1616.FixpToFloat(cStyle.scaleVertical), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" />'); w.Ln;
				INC(i);
			END;
			w.String("</styles>"); w.Ln;
			w.Update; Files.Register(f);

		END ExportCharacterStyles;

		PROCEDURE ImportCHandler(sender, data: ANY);
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "";
			IF WMDialogs.QueryString("Import Character Styles from File:", filename) = WMDialogs.ResOk THEN
				ImportCharacterStyles(filename);
			END;
			UpdateList;
		END ImportCHandler;

		PROCEDURE ImportCharacterStyles(CONST filename: ARRAY OF CHAR);
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
			cStyle: Texts.CharacterStyle;
		BEGIN
			COPY(filename, tempString);
			Strings.Append(tempString, ".XML");
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
						str := ptr(XML.Element).GetAttributeValue("font-size"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.size := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("leading"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.leading := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("baseline-shift"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.baselineShift := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("color"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.color := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("bgcolor"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.bgColor := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("tracking"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.tracking := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("h-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleHorizontal := FP1616.FloatToFixp(SHORT(tempReal)); END;
						str := ptr(XML.Element).GetAttributeValue("v-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleVertical := FP1616.FloatToFixp(SHORT(tempReal)); END;
						Texts.AddCharacterStyle(cStyle);

					END;
				END;
			END;

		END ImportCharacterStyles;

		PROCEDURE RemoveCHandler(sender, data: ANY);
		VAR i : LONGINT;
		BEGIN
			Texts.RemoveCharacterStyle(currentCStyle);
			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(cStyles))  & (cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(cStyles[i].name));
				cList.model.SetCellData(0, i, cStyles[i]);
				INC(i);
			END;
			CClickSelected(NIL, cList.model.GetCellData(0, i-1));
			cList.SetSelection(0,i-1, 0, i-1);
			cList.model.Release;
			UpdateProc;

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
			IF (tempString = "regular") THEN tempCStyle.style := {}; cStyle.SetAsString("Regular");
			ELSIF (tempString = "bold") THEN tempCStyle.style := {0}; cStyle.SetAsString("Bold");
			ELSIF (tempString = "italic") THEN tempCStyle.style := {1}; cStyle.SetAsString("Italic");
			ELSIF (tempString = "bold italic") THEN tempCStyle.style := {0, 1}; cStyle.SetAsString("Bold Italic");
			ELSE tempCStyle.style := {}; cStyle.SetAsString("Regular"); END;
			cSize.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.size := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cSize.SetAsString(tempString);
			cLeading.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.leading := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cLeading.SetAsString(tempString);
			tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
			previewLabel.SetFont(tempFont); previewLabel.Invalidate;
			IF (tempFont.name # tempCStyle.family) OR (tempFont.size # ENTIER(FP1616.FixpToFloat(tempCStyle.size))) THEN
				fontNotFound.visible.Set(TRUE);
			ELSE
				fontNotFound.visible.Set(FALSE);
			END;
			cLeading.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.leading := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cLeading.SetAsString(tempString);
			cBaselineShift.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.baselineShift := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cBaselineShift.SetAsString(tempString);
			cColor.GetAsString(tempString);
			Strings.HexStrToInt(tempString, tempInt, res);
			tempCStyle.color := tempInt;
			Strings.IntToHexStr(tempInt, 7, tempString);
			cColor.SetAsString(tempString);
			previewLabel.textColor.Set(tempInt); previewLabel.Invalidate;
			cBackColor.GetAsString(tempString);
			Strings.HexStrToInt(tempString, tempInt, res);
			tempCStyle.bgColor := tempInt;
			Strings.IntToHexStr(tempInt, 7, tempString);
			cBackColor.SetAsString(tempString);
			previewLabel.fillColor.Set(tempInt); previewLabel.Invalidate;
			cTracking.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.tracking := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cTracking.SetAsString(tempString);
			cStretchH.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.scaleHorizontal := FP1616.FloatToFixp(SHORT(tempLReal));
			Strings.FloatToStr(tempLReal, 0,4,0, tempString);
			cStretchH.SetAsString(tempString);
			cStretchV.GetAsString(tempString);
			Strings.StrToFloat(tempString, tempLReal);
			tempCStyle.scaleVertical := FP1616.FloatToFixp(SHORT(tempLReal));
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
			currentCStyle.scaleHorizontal := tempCStyle.scaleHorizontal;
			currentCStyle.scaleVertical := tempCStyle.scaleVertical;
			(* Invalidate Cache *)
			currentCStyle.fontcache := NIL;
			UpdateList;
		END ApplyCHandler;

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
				tempFont := WMGraphics.GetFont(tempCStyle.family, ENTIER(FP1616.FixpToFloat(tempCStyle.size)), tempCStyle.style);
				previewLabel.SetFont(tempFont); previewLabel.Invalidate;
			END;
		END StylePopupHandler;

		PROCEDURE ColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorPanel : WMPopups.ColorSwatchPopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.onColorChosen := ColorPopupHandler;
			colorPanel.Popup(bounds.r-190, bounds.t+172);

			handled := TRUE;
		END ColorHandler;

		PROCEDURE ColorPopupHandler(result: LONGINT);
		VAR
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToHexStr(result, 7, colorString);
			cColor.SetAsString(colorString);
			tempCStyle.color := result;
			previewLabel.textColor.Set(result); previewLabel.Invalidate;
		END ColorPopupHandler;

		PROCEDURE BGColorHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR colorPanel: WMPopups.ColorSwatchPopup;
		BEGIN
			NEW(colorPanel);
			colorPanel.onColorChosen := BGColorPopupHandler;
			colorPanel.Popup(bounds.r-190, bounds.t+192);

			handled := TRUE;
		END BGColorHandler;

		PROCEDURE BGColorPopupHandler(result: LONGINT);
		VAR
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToHexStr(result, 7, colorString);
			cBackColor.SetAsString(colorString);
			tempCStyle.bgColor := result;
			previewLabel.fillColor.Set(result); previewLabel.Invalidate;
		END BGColorPopupHandler;

	END StyleEditor;

VAR
	nofWindows : LONGINT;
	ctxAlignLeft, ctxAlignCenter, ctxAlignRight, ctxAlignJustified : ContextMenuData;
	ctxRegular, ctxBold, ctxItalic, ctxBoldItalic : ContextMenuData;

PROCEDURE CreateStyleName(CONST fontname : ARRAY OF CHAR; style : SET; size, fgColor, bgColor : LONGINT; VAR name : ARRAY OF CHAR);
VAR string : ARRAY 32 OF CHAR; styleInt : LONGINT;
BEGIN
	(* create AdHoc Name *)
	COPY("AdHoc", name); Strings.Append(name, " ");
	Strings.Append(name, fontname); Strings.Append(name, " ");
	Strings.IntToStr(size, string); Strings.Append(name, string); Strings.Append(name, " ");
	IF (style = {}) THEN styleInt := 0;
	ELSIF (style = {0}) THEN styleInt := 1;
	ELSIF (style ={1}) THEN styleInt := 2;
	ELSIF (style = {0, 1}) THEN styleInt := 3;
	ELSE styleInt := 0;
	END;
	Strings.IntToStr(styleInt, string); Strings.Append(name, string); Strings.Append(name, " ");
	Strings.IntToStr(0, string); Strings.Append(name, string); Strings.Append(name, " ");
	Strings.IntToHexStr(fgColor, 7, string); Strings.Append(name, string); Strings.Append(name, " ");
	Strings.IntToHexStr(bgColor, 7, string); Strings.Append(name, string);
END CreateStyleName;

PROCEDURE EnsureAttribute(VAR attr : Texts.Attributes);
BEGIN
	IF (attr = NIL) THEN
		NEW(attr); NEW(attr.fontInfo);
		attr.fontInfo.name := "Oberon";
		attr.fontInfo.size := 12;
	END
END EnsureAttribute;

(* Actually, this is a hack... but for now, do it.  *)
PROCEDURE GetNewSize(CONST fontname : ARRAY OF CHAR; mode, value, currentSize : LONGINT; VAR newSize : LONGINT);
BEGIN
	ASSERT((mode = Absolute) OR (mode = IncrementBy) OR (mode = DecrementBy));
	IF (mode = Absolute) THEN
		newSize := value;
	ELSE
		IF (fontname = "Oberon") THEN
			IF (mode = IncrementBy) THEN
				IF (currentSize = 8) THEN newSize := 10;
				ELSIF (currentSize = 10) THEN newSize := 12;
				ELSIF (currentSize = 12) THEN newSize := 14;
				ELSIF (currentSize = 14) THEN newSize := 16;
				ELSIF (currentSize = 16) THEN newSize := 20;
				ELSIF (currentSize = 20) THEN newSize := 24;
				ELSIF (currentSize = 24) THEN newSize := 24;
				ELSE (* go to default *)
					newSize := 12; (* max. size of Oberon font *)
				END;
			ELSE
				IF (currentSize = 8) THEN newSize := 8;
				ELSIF (currentSize = 10) THEN newSize := 8;
				ELSIF (currentSize = 12) THEN newSize := 10;
				ELSIF (currentSize = 14) THEN newSize := 12;
				ELSIF (currentSize = 16) THEN newSize := 14;
				ELSIF (currentSize = 20) THEN newSize := 16;
				ELSIF (currentSize = 24) THEN newSize := 20;
				ELSE
					newSize := 12;
				END;
			END;
		ELSIF (fontname = "Courier") THEN
			IF (mode = IncrementBy) THEN
				IF (currentSize = 10) THEN newSize := 12;
				ELSE
					newSize := 12;
				END;
			ELSE
				IF (currentSize = 12) THEN newSize := 10;
				ELSE
					newSize := 12;
				END;
			END;
		ELSE
			IF (mode = IncrementBy) THEN newSize := currentSize + value; ELSE newSize := currentSize - value; END;
		END;
	END;
	IF (newSize < 5) THEN newSize := 5; END;
END GetNewSize;

PROCEDURE ChangeFontSize(VAR attr : Texts.Attributes; userData : ANY);
VAR changeInfo : ChangeInfo;
BEGIN
	IF (userData # NIL) & (userData IS ChangeInfo) THEN
		changeInfo := userData (ChangeInfo);
		EnsureAttribute(attr);
		GetNewSize(attr.fontInfo.name, changeInfo.deltaSizeMode, changeInfo.deltaSize, attr.fontInfo.size, attr.fontInfo.size);
		attr.fontInfo.fontcache := NIL;
	END;
END ChangeFontSize;

PROCEDURE ChangeFontColor(VAR attr : Texts.Attributes; userData : ANY);
VAR changeInfo : ChangeInfo;
BEGIN
	IF (userData # NIL) & (userData IS ChangeInfo) THEN
		changeInfo := userData (ChangeInfo);
		EnsureAttribute(attr);
		IF (changeInfo.fields * ChangeFgColor # {}) THEN attr.color := changeInfo.fgColor; END;
		IF (changeInfo.fields * ChangeBgColor # {}) THEN attr.bgcolor := changeInfo.bgColor; END;
		attr.fontInfo.fontcache := NIL;
	END;
END ChangeFontColor;

PROCEDURE ChangeFontStyle(VAR attr : Texts.Attributes; userData : ANY);
BEGIN
	IF (userData # NIL) & (userData IS ChangeInfo) THEN
		EnsureAttribute(attr);
		attr.fontInfo.style := userData(ChangeInfo).style;
		attr.fontInfo.fontcache := NIL;
	END;
END ChangeFontStyle;

PROCEDURE ChangeFontName(VAR attr : Texts.Attributes; userData : ANY);
BEGIN
	IF (userData # NIL) & (userData IS ChangeInfo) THEN
		EnsureAttribute(attr);
		COPY(userData(ChangeInfo).name, attr.fontInfo.name);
		attr.fontInfo.fontcache := NIL;
	END;
END ChangeFontName;

PROCEDURE Change(changeInfo : ChangeInfo);
VAR
	text : Texts.Text;
	from, to : Texts.TextPosition;
	utilreader : Texts.TextReader;
	a, b : LONGINT;
	ch : Texts.Char32;
	newCstyle : Texts.CharacterStyle;
BEGIN
	ASSERT(changeInfo # NIL);
	IF Texts.GetLastSelection(text, from, to) THEN
		text.AcquireWrite;
		a := Strings.Min(from.GetPosition(), to.GetPosition());
		b := Strings.Max(from.GetPosition(), to.GetPosition());

		NEW(utilreader, text);
		utilreader.SetPosition(a);
		utilreader.ReadCh(ch);

		IF (utilreader.cstyle = NIL) & (utilreader.attributes = NIL) THEN
			changeInfo.deltaSizeMode := Absolute;
			changeInfo.deltaSize := 10; (* Set to reasonable default *)
			 text.UpdateAttributes(a, b - a, ChangeFontSize, changeInfo);
		ELSIF (utilreader.cstyle # NIL) THEN
			newCstyle := utilreader.cstyle.Clone();
			GetNewSize(newCstyle.family, changeInfo.deltaSizeMode, changeInfo.deltaSize, newCstyle.size, newCstyle.size);
			CreateStyleName(newCstyle.family, newCstyle.style, newCstyle.size, newCstyle.color, newCstyle.bgColor, newCstyle.name);
			Texts.AddCharacterStyle(newCstyle);
			text.SetCharacterStyle(a, b - a, newCstyle);
		ELSIF (utilreader.attributes # NIL) THEN
			IF (changeInfo.fields * ChangeSize # {}) THEN text.UpdateAttributes(a, b - a, ChangeFontSize, changeInfo); END;
			IF (changeInfo.fields * ChangeStyle # {}) THEN text.UpdateAttributes(a, b - a, ChangeFontStyle, changeInfo); END;
			IF (changeInfo.fields * (ChangeFgColor + ChangeBgColor) # {}) THEN
				text.UpdateAttributes(a, b - a, ChangeFontColor, changeInfo);
			END;
			IF (changeInfo.fields * ChangeFont # {}) THEN text.UpdateAttributes(a, b - a, ChangeFontName, changeInfo); END;
		END;
		text.ReleaseWrite;
	END;
END Change;

(* Set the font size of the currently selected text either relativ or absolute *)
PROCEDURE SetFontSize*(context : Commands.Context); (** ("Absolute"|"IncrementBy" |"DecrementBy") [value] ~*)
VAR changeInfo : ChangeInfo; modeStr : ARRAY 16 OF CHAR; mode, value : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(modeStr);
	context.arg.SkipWhitespace; context.arg.Int(value, FALSE);
	Strings.UpperCase(modeStr);
	IF (modeStr = "ABSOLUTE") THEN mode := Absolute;
	ELSIF (modeStr = "INCREMENTBY") THEN mode := IncrementBy;
	ELSIF (modeStr = "DECREMENTBY") THEN mode := DecrementBy;
	ELSE
		context.error.String("WMTextStyleTool.SetFontSize: Unknown mode parameter"); context.error.Ln;
		RETURN;
	END;
	NEW(changeInfo);
	changeInfo.fields := ChangeSize;
	changeInfo.deltaSizeMode := mode;
	changeInfo.deltaSize := value;
	IF (mode # Absolute) & (value = 0) THEN changeInfo.deltaSize := 1; (* default increment/ decrement *) END;
	Change(changeInfo);
END SetFontSize;

(** Set the font style of the currently selected text. Default: Normal  *)
PROCEDURE SetFontStyle*(context : Commands.Context);
VAR styleStr : ARRAY 16 OF CHAR; style : SET; changeInfo : ChangeInfo;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(styleStr);
	Strings.UpperCase(styleStr);
	IF (styleStr = "BOLD") THEN style := {WMGraphics.FontBold};
	ELSIF (styleStr = "ITALIC") THEN style := {WMGraphics.FontItalic};
	ELSIF (styleStr = "NORMAL") OR (styleStr = "") THEN style := {};
	ELSE
		context.error.String("WMTextStyleTool.SetFontStyle: Unknown font style parameter."); context.error.Ln;
		RETURN;
	END;
	NEW(changeInfo);
	changeInfo.fields := ChangeStyle;
	changeInfo.style := style;
	Change(changeInfo);
END SetFontStyle;

(** Set the font color of the currently selected text. If not parameter is specified, fgColor is black, bgColor is unchanged *)
PROCEDURE SetFontColor*(context : Commands.Context); (** [fgColor] [bgColor] ~ *)
VAR fgColor, bgColor : LONGINT; changeInfo : ChangeInfo;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(fgColor, TRUE);
	context.arg.SkipWhitespace; context.arg.Int(bgColor, TRUE);
	NEW(changeInfo);
	changeInfo.fields := ChangeFgColor;
	changeInfo.fgColor := fgColor;
	IF (context.arg.res = Streams.Ok) THEN
		changeInfo.bgColor := bgColor;
		changeInfo.fields := changeInfo.fields + ChangeBgColor;
	END;
	Change(changeInfo);
END SetFontColor;

(** Set the font for the currently selected text. Default: Oberon *)
PROCEDURE SetFontName*(context : Commands.Context); (** [fontname] ~ *)
VAR name : ARRAY 128 OF CHAR; changeInfo : ChangeInfo;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Oberon", name); END;
	NEW(changeInfo);
	COPY(name, changeInfo.name);
	changeInfo.fields := ChangeFont;
	Change(changeInfo);
END SetFontName;

(** Set the style of the currently selected text by name *)
PROCEDURE SetStyleByName*(context : Commands.Context); (* stylename ~ *)
VAR
	text : Texts.Text;
	from, to : Texts.TextPosition;
	a, b : LONGINT;
	cStyle : Texts.CharacterStyle;
	cStyleStr : ARRAY 32 OF CHAR;
BEGIN
	IF ~context.arg.GetString(cStyleStr) THEN RETURN END;

	IF Texts.GetLastSelection(text, from, to) THEN
		cStyle := Texts.GetCharacterStyleByName(cStyleStr);
		IF cStyle # NIL THEN
			text.AcquireWrite;
			a := Strings.Min(from.GetPosition(), to.GetPosition());
			b := Strings.Max(from.GetPosition(), to.GetPosition());
			text.SetCharacterStyle(a, b - a, cStyle);
			text.ReleaseWrite
		END;
	END;
END SetStyleByName;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context);
END Restore;

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
	NEW(ctxAlignLeft, AlignLeft);
	NEW(ctxAlignCenter, AlignCenter);
	NEW(ctxAlignRight, AlignRight);
	NEW(ctxAlignJustified, AlignJustified);
	NEW(ctxRegular, StyleRegular);
	NEW(ctxBold, StyleBold);
	NEW(ctxItalic, StyleItalic);
	NEW(ctxBoldItalic, StyleBoldItalic);

	Modules.InstallTermHandler(Cleanup)
END WMTextStyleTool.

SystemTools.Free WMTextStyleTool ~
WMTextStyleTool.Open  ~

WMTextStyleTool.SetStyleByName Bold ~
WMTextStyleTool.SetStyleByName Normal ~

WMTextStyleTool.SetFontName Oberon ~
WMTextStyleTool.SetFontName Courier ~

WMTextStyleTool.SetFontSize IncrementBy ~
WMTextStyleTool.SetFontSize DecrementBy ~

WMTextStyleTool.SetFontSize Absolute 20 ~

WMTextStyleTool.SetFontStyle bold ~
WMTextStyleTool.SetFontStyle normal ~

WMTextStyleTool.SetFontColor FF0000FFH ~
WMTextStyleTool.SetFontColor 0 ~