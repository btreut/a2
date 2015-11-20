MODULE WMTextTool;	(** AUTHOR "TF"; PURPOSE "Text Tool"; *)

IMPORT
	Modules, Streams, Commands, Texts, Strings, WMComponents, WMRestorable, WMEditors, WMPopups, WMRectangles,
	WMGraphics, WMMessages, WMStandardComponents,
	WM := WMWindowManager, XML, XMLObjects;

CONST
	WindowWidth = 122; WindowHeight = 220;

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

	(* Linefeed character *)
	LF = 0AX;

TYPE

	ChangeInfo = OBJECT(Texts.Attributes);
	VAR
		name : ARRAY 128 OF CHAR; 	(* font name *)
		fgColor, bgColor : LONGINT;		(* foreground and background color *)
		deltaSize : LONGINT;			(* new font size, interpretation depends on deltaSizeMode field *)
		deltaSizeMode : LONGINT;		(* Absolute, IncrementBy or DecrementBy *)
		style : SET;						(* font style *)
		fields : SET;						(* What should be changed? *)
	END ChangeInfo;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		bold, lock, comment, stupid, assert, preferred, debug, normal, incSize, decSize, get, apply: WMStandardComponents.Button;
		famEdit, sizeEdit, styleEdit, colorEdit, bgColEdit: WMEditors.TextField;
		famCheck, sizeCheck, styleCheck, colorCheck, bgColCheck: WMStandardComponents.Checkbox;
		styleB, colB, bgColB : WMStandardComponents.Button;
		popup : WMPopups.Popup;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			label : WMStandardComponents.Label;
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;
			manager : WM.WindowManager;
			windowStyle : WM.WindowStyle;

			PROCEDURE AB(panel : WMStandardComponents.Panel; btn: WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignLeft);
				btn.fillColor.Set(0FFFFFFFFH);
				btn.clDefault.Set(windowStyle.bgColor);
				btn.clTextDefault.Set(WMGraphics.Black);
				btn.bounds.SetWidth(WindowWidth DIV 2); panel.AddContent(btn)
			END AB;

			PROCEDURE AL(panel : WMStandardComponents.Panel; lbl : WMStandardComponents.Label);
			BEGIN
				lbl.alignment.Set(WMComponents.AlignLeft); lbl.bounds.SetWidth(31); label.textColor.Set(0000000FFH);
				panel.AddContent(lbl)
			END AL;

			PROCEDURE AC(panel : WMStandardComponents.Panel; chk : WMStandardComponents.Checkbox);
			BEGIN
				chk.bounds.SetWidth(16); chk.state.Set(1); chk.bearing.Set(WMRectangles.MakeRect(2, 2, 2, 2));
				chk.alignment.Set(WMComponents.AlignRight); chk.bounds.SetWidth(20);
				panel.AddContent(chk)
			END AC;

			PROCEDURE AE(panel : WMStandardComponents.Panel; edtr : WMEditors.TextField);
			BEGIN
				edtr.alignment.Set(WMComponents.AlignClient); edtr.fillColor.Set(0FFFFFF88H);
				panel.AddContent(edtr)
			END AE;

			PROCEDURE AD(panel : WMStandardComponents.Panel; btn : WMStandardComponents.Button);
			BEGIN
				btn.alignment.Set(WMComponents.AlignRight); btn.bounds.SetWidth(17); panel.AddContent(btn)
			END AD;

		BEGIN
			manager := WM.GetDefaultManager();
			windowStyle := manager.GetStyle();
			IF (windowStyle.bgColor = 0) THEN windowStyle.bgColor := WMGraphics.White; END;

			NEW(panel); panel.bounds.SetExtents(WindowWidth, WindowHeight); panel.takesFocus.Set(TRUE);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(bold); bold.caption.SetAOC("Bold"); AB(toolbar, bold);

			NEW(lock); lock.caption.SetAOC("Lock"); AB(toolbar, lock);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(comment); comment.caption.SetAOC("Comment"); AB(toolbar, comment);
			NEW(debug); debug.caption.SetAOC("Debug"); AB(toolbar, debug);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(stupid); stupid.caption.SetAOC("Stupid"); AB(toolbar, stupid);
			NEW(assert); assert.caption.SetAOC("Assert"); AB(toolbar, assert);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(preferred); preferred.caption.SetAOC("Preferred"); AB(toolbar, preferred);
			NEW(normal); normal.caption.SetAOC("Normal"); AB(toolbar, normal);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(incSize); incSize.caption.SetAOC("Inc Size"); AB(toolbar, incSize);
			NEW(decSize); decSize.caption.SetAOC("Dec Size"); AB(toolbar, decSize);

			(* Get/Apply *)
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(get); get.caption.SetAOC("Get"); AB(toolbar, get);
			get.clDefault.Set(088000088H); get.clTextDefault.Set(WMGraphics.White);
			NEW(apply); apply.caption.SetAOC("Apply"); AB(toolbar, apply);
			apply.clDefault.Set(088000088H); apply.clTextDefault.Set(WMGraphics.White);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC("Font:"); AL(toolbar, label);
			NEW(famCheck); AC(toolbar, famCheck);
			NEW(famEdit); famEdit.SetAsString("Oberon"); AE(toolbar, famEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC("Size:"); AL(toolbar, label);
			NEW(sizeCheck); AC(toolbar, sizeCheck);
			NEW(sizeEdit); sizeEdit.SetAsString("10"); AE(toolbar, sizeEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC("Style:"); AL(toolbar, label);
			NEW(styleCheck); AC(toolbar, styleCheck);
			NEW(styleB); styleB.caption.SetAOC("+"); AD(toolbar, styleB);
			NEW(styleEdit); styleEdit.SetAsString("Regular"); AE(toolbar, styleEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC("Color:"); AL(toolbar, label);
			NEW(colorCheck); AC(toolbar, colorCheck);
			NEW(colB); colB.caption.SetAOC("+"); AD(toolbar, colB); 
			NEW(colorEdit); colorEdit.SetAsString("000000FF"); colorEdit.onChanged.Add(UpdateColors);
			AE(toolbar, colorEdit);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.fillColor.Set(windowStyle.bgColor);
			panel.AddContent(toolbar);
			NEW(label); label.caption.SetAOC("BCol:"); AL(toolbar, label);
			NEW(bgColCheck); AC(toolbar, bgColCheck);
			NEW(bgColB); bgColB.caption.SetAOC("+"); AD(toolbar, bgColB);
			NEW(bgColEdit); bgColEdit.SetAsString("00000000"); bgColEdit.onChanged.Add(UpdateColors);
			AE(toolbar, bgColEdit);

			UpdateColors(NIL, NIL);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			scaling := TRUE;
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
			incSize.onClick.Add(SetStyle);
			decSize.onClick.Add(SetStyle);
			get.onClick.Add(GetStyle);
			apply.onClick.Add(SetCustomStyle);
			styleB.SetExtPointerDownHandler(StyleDrop);
			colB.SetExtPointerDownHandler(ColorHandler);
			bgColB.SetExtPointerDownHandler(BGColorHandler);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Text Styles"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMTextTool.png", TRUE));

			IF c # NIL THEN
				IF c.appData # NIL THEN
					DisableUpdate;
					LoadData(c.appData(XML.Element));
					EnableUpdate;
				END;
				vc.Invalidate;
				WMRestorable.AddByContext(SELF, c)
			ELSE
				WM.ExtAddWindow(SELF, 50, 120, {WM.FlagStayOnTop, WM.FlagFrame, WM.FlagClose, WM.FlagMinimize})
			END;
		END New;

		PROCEDURE GetStyle(sender, data : ANY);
		VAR
			text : Texts.Text; from, to : Texts.TextPosition;
			utilreader : Texts.TextReader; tempString : ARRAY 256 OF CHAR;
			a, b, ch : LONGINT;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				text.AcquireWrite;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				NEW(utilreader, text);
				utilreader.SetPosition(a);
				utilreader.ReadCh(ch);
				IF utilreader.attributes = NIL THEN
					famEdit.SetAsString("vera");
					sizeEdit.SetAsString("20");
					styleEdit.SetAsString("regular");
					colorEdit.SetAsString("000000FF");
					bgColEdit.SetAsString("00000000");
				ELSE
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

		PROCEDURE SetStyle(sender, data : ANY);
		VAR changeInfo : ChangeInfo;
		BEGIN
			NEW(changeInfo);
			IF sender = bold THEN
				changeInfo.style := {WMGraphics.FontBold};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0, 0, 0, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = lock THEN
				changeInfo.style := {};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0FFH, 0, 0FFH, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = preferred THEN
				changeInfo.style := {WMGraphics.FontBold};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0FFH, 0, 0FFH, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = assert THEN
				changeInfo.style := {WMGraphics.FontBold};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0, 0, 0FFH, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = comment THEN
				changeInfo.style := {};
				changeInfo.fgColor := WMGraphics.RGBAToColor(80H, 80H, 080H, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = debug THEN
				changeInfo.style := {};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0H, 0H, 0FFH, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = stupid THEN
				changeInfo.style := {};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0FFH, 0H, 0H, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = normal THEN
				changeInfo.style := {};
				changeInfo.fgColor := WMGraphics.RGBAToColor(0H, 0H, 0H, 0FFH);
				changeInfo.fields := ChangeStyle + ChangeFgColor;
			ELSIF sender = incSize THEN
				changeInfo.deltaSize := 1;
				changeInfo.deltaSizeMode := IncrementBy;
				changeInfo.fields := ChangeSize;
			ELSIF sender = decSize THEN
				changeInfo.deltaSize := 1;
				changeInfo.deltaSizeMode := DecrementBy;
				changeInfo.fields := ChangeSize;
			END;
			ApplyChange(changeInfo);
		END SetStyle;

		PROCEDURE SetCustomStyle(sender, data: ANY);
		VAR
			changeInfo : ChangeInfo;
			string: ARRAY 32 OF CHAR;
			res : LONGINT;
		BEGIN
			NEW(changeInfo);
			IF (famCheck.state.Get() = 1) THEN
				famEdit.GetAsString(string); COPY(string, changeInfo.name);
				changeInfo.fields := changeInfo.fields + ChangeFont;
			END;
			IF (sizeCheck.state.Get() = 1) THEN
				sizeEdit.GetAsString(string); Strings.StrToInt(string, changeInfo.deltaSize);  changeInfo.deltaSizeMode := Absolute;
				changeInfo.fields := changeInfo.fields + ChangeSize;
			END;
			IF (styleCheck.state.Get() = 1) THEN
				styleEdit.GetAsString(string); Strings.LowerCase(string);
				IF (string = "0") OR (string = "regular") THEN	changeInfo.style := 	{};
				ELSIF (string = "1") OR (string = "bold") THEN changeInfo.style := {0};
				ELSIF (string = "2") OR (string = "italic") THEN changeInfo.style := {1};
				ELSIF (string = "3") OR (string = "bold italic") THEN changeInfo.style := {0,1};
				ELSE changeInfo.style := {};
				END;
				changeInfo.fields := changeInfo.fields + ChangeStyle;
			END;
			IF (colorCheck.state.Get() = 1) THEN
				colorEdit.GetAsString(string); Strings.HexStrToInt(string, changeInfo.fgColor, res);
				changeInfo.fields := changeInfo.fields + ChangeFgColor;
			END;
			IF (bgColCheck.state.Get() = 1) THEN
				bgColEdit.GetAsString(string); Strings.HexStrToInt(string, changeInfo.bgColor, res);
				changeInfo.fields := changeInfo.fields + ChangeBgColor;
			END;
			ApplyChange(changeInfo);
		END SetCustomStyle;

		PROCEDURE StyleDrop(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			NEW(popup);
			popup.Add("Regular", StylePopupHandler);
			popup.Add("Bold", StylePopupHandler);
			popup.Add("Italic", StylePopupHandler);
			popup.Add("Bold Italic", StylePopupHandler);
			handled := TRUE;

			popup.Popup(bounds.r-120, bounds.t+180);
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
			colorPanel.Popup(bounds.r-190, bounds.t+200);

			handled := TRUE;
		END ColorHandler;

		PROCEDURE ColorPopupHandler(result: LONGINT);
		VAR
			colorString: ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToHexStr(result, 7, colorString);
			colorEdit.SetAsString(colorString);
			colB.clDefault.Set(result);
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
			bgColB.clDefault.Set(result);
		END BGColorPopupHandler;

		PROCEDURE UpdateColors(sender, data : ANY);
		VAR colorString : ARRAY 16 OF CHAR; caption : ARRAY 2 OF CHAR;  color, res : LONGINT;
		BEGIN
			colorEdit.GetAsString(colorString);
			Strings.HexStrToInt(colorString, color, res);
			IF (res = Strings.Ok) THEN caption := "+"; ELSE caption := "E"; END;
			colB.caption.SetAOC(caption);
			colB.clDefault.Set(color);
			bgColEdit.GetAsString(colorString);
			Strings.HexStrToInt(colorString, color, res);
			IF (res = Strings.Ok) THEN caption := "+"; ELSE caption := "E"; END;
			bgColB.caption.SetAOC(caption);
			bgColB.clDefault.Set(color);
		END UpdateColors;

		PROCEDURE Close;
		BEGIN
			Close^;
			colorEdit.onChanged.Remove(UpdateColors);
			bgColEdit.onChanged.Remove(UpdateColors);
			DecCount;
		END Close;
		
		PROCEDURE LoadData(elem: XML.Element);	
		VAR i: LONGINT; str: ARRAY 128 OF CHAR;
		BEGIN
			WMRestorable.LoadLongint(elem, "famCheck", i); famCheck.state.Set(i);
			WMRestorable.LoadLongint(elem, "sizeCheck", i); sizeCheck.state.Set(i);
			WMRestorable.LoadLongint(elem, "styleCheck", i); styleCheck.state.Set(i);
			WMRestorable.LoadLongint(elem, "colorCheck", i); colorCheck.state.Set(i);
			WMRestorable.LoadLongint(elem, "bgColCheck", i); bgColCheck.state.Set(i);
			WMRestorable.LoadString(elem,"famEdit", str); famEdit.SetAsString(str); 
			WMRestorable.LoadString(elem,"sizeEdit", str); sizeEdit.SetAsString(str); 
			WMRestorable.LoadString(elem,"styleEdit", str); styleEdit.SetAsString(str); 
			WMRestorable.LoadString(elem,"colorEdit", str); colorEdit.SetAsString(str); 
			WMRestorable.LoadString(elem,"bgColEdit", str); bgColEdit.SetAsString(str); 
		END LoadData;
		
		
		PROCEDURE StoreData(): XML.Element;
		VAR elem: XML.Element; string: ARRAY 128 OF CHAR;
		BEGIN
			NEW(elem); elem.SetName("Style");
			WMRestorable.StoreLongint(elem, "famCheck", famCheck.state.Get());
			famEdit.GetAsString(string);
			WMRestorable.StoreString(elem, "famEdit", string);
			
			WMRestorable.StoreLongint(elem, "sizeCheck", sizeCheck.state.Get());
			sizeEdit.GetAsString(string);
			WMRestorable.StoreString(elem, "sizeEdit", string);
			
			WMRestorable.StoreLongint(elem, "styleCheck", styleCheck.state.Get());
			styleEdit.GetAsString(string);
			WMRestorable.StoreString(elem, "styleEdit", string);

			WMRestorable.StoreLongint(elem, "colorCheck", colorCheck.state.Get());
			colorEdit.GetAsString(string);
			WMRestorable.StoreString(elem, "colorEdit", string);
			
			WMRestorable.StoreLongint(elem, "bgColCheck", bgColCheck.state.Get());
			bgColEdit.GetAsString(string);
			WMRestorable.StoreString(elem, "bgColEdit", string);
			RETURN elem;
		END StoreData;
		

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR data: XML.Element;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					data := StoreData();
					x.ext(WMRestorable.Storage).Add("WMTextTool", "WMTextTool.Restore", SELF, data)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

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
	IF (newSize < 8) THEN newSize := 8; END;
END GetNewSize;

PROCEDURE EnsureAttribute(VAR attr : Texts.Attributes);
BEGIN
	IF (attr = NIL) THEN
		NEW(attr); NEW(attr.fontInfo);
		attr.fontInfo.name := "Oberon";
		attr.fontInfo.size := 10;
		attr.fontInfo.style := {};
		attr.color := 0000000FFH;
		attr.bgcolor := 000000000H;
	END
END EnsureAttribute;

PROCEDURE ChangeAttribute(VAR attr : Texts.Attributes; userData : ANY);
VAR changeInfo : ChangeInfo;
BEGIN
	IF (userData # NIL) & (userData IS ChangeInfo) THEN
		changeInfo := userData (ChangeInfo);
		EnsureAttribute(attr);

		IF (changeInfo.fields * ChangeFont # {}) THEN (* font change *)
			COPY(changeInfo.name, attr.fontInfo.name);
		END;

		IF (changeInfo.fields * ChangeSize # {}) THEN (* font size change *)
			GetNewSize(attr.fontInfo.name, changeInfo.deltaSizeMode, changeInfo.deltaSize, attr.fontInfo.size, attr.fontInfo.size);
		END;

		IF (changeInfo.fields * ChangeFgColor # {}) THEN attr.color := changeInfo.fgColor; END;
		IF (changeInfo.fields * ChangeBgColor # {}) THEN attr.bgcolor := changeInfo.bgColor; END;
		IF (changeInfo.fields * ChangeStyle # {}) THEN attr.fontInfo.style := changeInfo.style; END;

		attr.fontInfo.fontcache := NIL;
	END;
END ChangeAttribute;

(* Apply text formatting changes described by <changeInfo> to the currently selected text *)
PROCEDURE ApplyChange(changeInfo : ChangeInfo);
VAR
	text : Texts.Text;
	from, to : Texts.TextPosition;
	utilreader : Texts.TextReader;
	a, b : LONGINT;
	ch : Texts.Char32;
BEGIN
	ASSERT(changeInfo # NIL);
	IF Texts.GetLastSelection(text, from, to) THEN
		text.AcquireWrite;
		a := Strings.Min(from.GetPosition(), to.GetPosition());
		b := Strings.Max(from.GetPosition(), to.GetPosition());

		NEW(utilreader, text);
		utilreader.SetPosition(a);
		utilreader.ReadCh(ch);

		text.UpdateAttributes(a, b - a, ChangeAttribute, changeInfo);
		text.ReleaseWrite;
	END;
END ApplyChange;

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
	ApplyChange(changeInfo);
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
	ApplyChange(changeInfo);
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
	ApplyChange(changeInfo);
END SetFontColor;

(** Set the font for the currently selected text. Default: Oberon *)
PROCEDURE SetFontName*(context : Commands.Context); (** [fontname] ~ *)
VAR name : ARRAY 128 OF CHAR; changeInfo : ChangeInfo;
BEGIN
	IF ~context.arg.GetString(name) THEN COPY("Oberon", name); END;
	NEW(changeInfo);
	COPY(name, changeInfo.name);
	changeInfo.fields := ChangeFont;
	ApplyChange(changeInfo);
END SetFontName;

PROCEDURE CountWords*(context : Commands.Context);
VAR wordCount : LONGINT; ch : CHAR;

	PROCEDURE SkipWord(r : Streams.Reader);
	VAR ch : CHAR;
	BEGIN
		REPEAT
			ch := r.Get();
		UNTIL (r.res # Streams.Ok) OR (ORD(ch) <= 32);
	END SkipWord;

BEGIN
	wordCount := 0;
	context.arg.SkipWhitespace;
	ch := context.arg.Get();
	WHILE (ch # 0X) & (context.arg.res = Streams.Ok) DO
		INC(wordCount);
		SkipWord(context.arg);
		context.arg.SkipWhitespace;
		ch := context.arg.Peek();
	END;
	context.out.String("Number of words: "); context.out.Int(wordCount, 0); context.out.Ln;
END CountWords;

PROCEDURE CountLines*(context : Commands.Context);
VAR nofLines : LONGINT; ch : CHAR;
BEGIN
	nofLines := 1;
	REPEAT
		ch := context.arg.Get();
		IF (ch = LF) THEN INC(nofLines); END;
	UNTIL (context.arg.res # Streams.Ok);
	context.out.String("Number of lines: "); context.out.Int(nofLines, 0); context.out.Ln;
END CountLines;

PROCEDURE CountCharacters*(context : Commands.Context);
VAR nofCharacters : LONGINT; ch : CHAR;
BEGIN
	nofCharacters := 0;
	REPEAT
		ch := context.arg.Get();
		IF (ch # 0X) THEN INC(nofCharacters); END;
	UNTIL (context.arg.res # Streams.Ok);
	context.out.String("Number of characters: "); context.out.Int(nofCharacters, 0); context.out.Ln;
END CountCharacters;

PROCEDURE CountAll*(context : Commands.Context);
BEGIN
	CountCharacters(context);
	context.arg.SetPos(0); CountWords(context);
	context.arg.SetPos(0); CountLines(context);
END CountAll;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context)
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
	Modules.InstallTermHandler(Cleanup)
END WMTextTool.

SystemTools.Free WMTextTool ~

WMTextTool.Open  ~

WMTextTool.SetFontSize Absolute 20 ~	WMTextTool.SetFontSize Absolute 12 ~

WMTextTool.SetFontStyle normal ~	WMTextTool.SetFontStyle bold ~

WMTextTool.SetFontName Courier ~		WMTextTool.SetFontName Oberon ~

WMTextTool.SetFontColor 0FF0000FFH ~	WMTextTool.SetFontColor 0FFH ~

WMTextTool.CountLines ^ ~

WMTextTool.CountWords ^ ~

WMTextTool.CountCharacters ^ ~

WMTextTool.CountAll ^ ~