MODULE WMCharMap;	(** AUTHOR "PL"; PURPOSE "Unicode Character Table"; *)

IMPORT
	WMStandardComponents, WMComponents,
	WMMessages, WMGraphics, Strings, WMRectangles, Modules,
	WMEditors, WMGrids, Texts, UTF8Strings,
	WM := WMWindowManager;

CONST
	NofCols = 16;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		mainPanel : WMStandardComponents.Panel;
		preview : WMStandardComponents.Label;
		characters : WMGrids.GenericGrid;
		decEd, hexEd : WMEditors.Editor;
		copyButton : WMStandardComponents.Button;

		prevFont, font : WMGraphics.Font;
		nofCharacters, curChar : LONGINT;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			prevFont := WMGraphics.GetFont("Cyberbit", 150, {});
			font := WMGraphics.GetFont("Cyberbit", 20, {});
			preview.SetFont(prevFont);

			nofCharacters := 10000H;
			characters.nofRows.Set(nofCharacters DIV NofCols + 1);

			SetTitle(Strings.NewString("Unicode Character Table"));
			WM.DefaultAddWindow(SELF);
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			NEW(mainPanel); mainPanel.bounds.SetExtents(710, 300); mainPanel.fillColor.Set(LONGINT(0CCCCCCFFH));

			(* -- Info Panel -- *)
			NEW(panel); panel.alignment.Set(WMComponents.AlignBottom); panel.bounds.SetHeight(20);
			panel.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 10));
			mainPanel.AddContent(panel);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(100);
			label.textColor.Set(0000000FFH); label.caption.SetAOC(" UniCode: ");
			panel.AddContent(label);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(50);
			label.textColor.Set(0000000FFH); label.caption.SetAOC("   Dec: ");
			panel.AddContent(label);

			NEW(decEd); decEd.alignment.Set(WMComponents.AlignLeft); decEd.multiLine.Set(FALSE);
			decEd.tv.textAlignV.Set(WMGraphics.AlignCenter);
			decEd.bounds.SetWidth(100); decEd.onEnter.Add(FindChar);
			decEd.fillColor.Set(LONGINT(0FFFFFFFFH)); decEd.tv.showBorder.Set(TRUE);
			decEd.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			panel.AddContent(decEd);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(50);
			label.textColor.Set(0000000FFH); label.caption.SetAOC("   Hex: ");
			panel.AddContent(label);

			NEW(hexEd); hexEd.alignment.Set(WMComponents.AlignLeft); hexEd.multiLine.Set(FALSE);
			hexEd.tv.textAlignV.Set(WMGraphics.AlignCenter);
			hexEd.bounds.SetWidth(100); hexEd.onEnter.Add(FindChar);
			hexEd.fillColor.Set(LONGINT(0FFFFFFFFH)); hexEd.tv.showBorder.Set(TRUE);
			hexEd.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			panel.AddContent(hexEd);

			NEW(copyButton); copyButton.alignment.Set(WMComponents.AlignRight); copyButton.bounds.SetWidth(120);
			copyButton.caption.SetAOC("Copy Character"); copyButton.onClick.Add(CopyChar);
			panel.AddContent(copyButton);

			(* -- Character Panel -- *)
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			mainPanel.AddContent(panel);

			NEW(preview); preview.alignment.Set(WMComponents.AlignLeft); preview.bounds.SetWidth(200);
			preview.fillColor.Set(LONGINT(0FFFFFFCCH));
			preview.textColor.Set(0000000FFH); preview.caption.SetAOC("");
			preview.alignH.Set(WMGraphics.AlignCenter); preview.alignV.Set(WMGraphics.AlignCenter);
			panel.AddContent(preview);

			NEW(characters); characters.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(characters);
			characters.nofCols.Set(NofCols); characters.nofRows.Set(4);
			characters.defaultColWidth.Set(30); characters.defaultRowHeight.Set(30);
			characters.SetDrawCellProc(DrawAll);
			characters.onSelect.Add(SelectChar);

			RETURN mainPanel
		END CreateForm;

		PROCEDURE DrawAll(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR pos, i, dx, dy : LONGINT; charString : ARRAY 16 OF CHAR;
		BEGIN
			IF WMGrids.CellSelected IN state THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(08888FFFFH), WMGraphics.ModeCopy)
			ELSIF WMGrids.CellHighlighted IN state THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy)
			END;
			pos := y * NofCols + x;

			IF pos < nofCharacters THEN
				canvas.SetColor(0FFH);
				canvas.SetFont(font);
				IF ~UTF8Strings.EncodeChar(pos, charString, i) THEN COPY("", charString) END;
				font.GetStringSize(charString, dx, dy);
				canvas.DrawString(w-30+((30 - dx) DIV 2) ,h-8 , charString);
			END
		END DrawAll;

		PROCEDURE SelectChar(sender, data : ANY);
		VAR l, t, r, b, i, pos : LONGINT; charString, tempString : ARRAY 16 OF CHAR;
		BEGIN
			characters.GetSelection(l, t, r, b);
			pos := t * NofCols + l;

			IF pos < nofCharacters THEN
				curChar := pos; i := 0;
				IF UTF8Strings.EncodeChar(curChar, charString, i) THEN preview.caption.SetAOC(charString)
				ELSE preview.caption.SetAOC("") END;

				Strings.IntToHexStr(pos, 8, tempString);
				hexEd.SetAsString(tempString);
				Strings.IntToStr(pos, tempString);
				decEd.SetAsString(tempString);
			END
		END SelectChar;

		PROCEDURE FindChar(sender, data : ANY);
		VAR tempString : ARRAY 16 OF CHAR;
			pos, res : LONGINT;
		BEGIN
			IF sender IS WMEditors.Editor THEN
				IF sender(WMEditors.Editor) = hexEd THEN
					hexEd.GetAsString(tempString);
					Strings.HexStrToInt(tempString, pos, res);
					curChar := pos; characters.SetSelection(pos MOD NofCols, pos DIV NofCols, pos MOD NofCols, pos DIV NofCols);
					characters.SetTopPosition(0, pos DIV NofCols, TRUE);
					SelectChar(SELF, NIL)
				ELSIF sender(WMEditors.Editor) = decEd THEN
					decEd.GetAsString(tempString);
					Strings.StrToInt(tempString, pos);
					curChar := pos; characters.SetSelection(pos MOD NofCols, pos DIV NofCols, pos MOD NofCols, pos DIV NofCols);
					characters.SetTopPosition(0, pos DIV NofCols, TRUE);
					SelectChar(SELF, NIL)
				ELSE
				END
			END
		END FindChar;

		PROCEDURE CopyChar(sender, data : ANY);
		VAR charString : ARRAY 16 OF CHAR; i : LONGINT; buf : Texts.PUCS32String;
		BEGIN
			Texts.clipboard.AcquireWrite; i := 0;
			IF UTF8Strings.EncodeChar(curChar, charString, i) THEN
				(* clear the clipboard *)
				IF Texts.clipboard.GetLength() > 0 THEN Texts.clipboard.Delete(0, Texts.clipboard.GetLength()) END;
				NEW(buf, 2); buf[0] := curChar; buf[1] := 0;
				Texts.clipboard.InsertUCS32(0, buf^);
			END;
			Texts.clipboard.ReleaseWrite;
		END CopyChar;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle (VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^ (x)
			END
		END Handle;

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
END WMCharMap.

SystemTools.Free WMCharMap ~
WMCharMap.Open ~
