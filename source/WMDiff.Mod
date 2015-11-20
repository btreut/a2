MODULE WMDiff; (** AUTHOR "Ingmar Nebel"; PURPOSE "The difference is in the file text-file!"; *)

IMPORT
	Modules, WM := WMWindowManager, WMRestorable, WMStringGrids, WMGrids, WMGraphics, WMRectangles,
	WMComponents, WMStandardComponents, DiffLib, Streams, Commands, Strings, WMEvents, Raster,
	WMEditors, WMTextView, Texts, Files, UTF8Strings, WMMessages, WMScrollableComponents;

CONST
	Width = 1024;
	Height = 768;

	ShowLineNumbers = TRUE;

	DiffStateEmpty = 0;
	DiffStateCommon = 1;
	DiffStateDifferent = 2;

	ScrollbarWidth = 15;
	OverviewWidth = 10;

	DarkGreen = 000C000FFH;
	DarkRed = LONGINT(0C00000FFH);

	DiffColorLeft = LONGINT(0FF000030H);
	DiffColorRight = 00000FF30H;
	EmptyLineColor = WMGraphics.White;

	LineNbrBgColor = LONGINT(0E0E0FFFFH);
	BgColor = LONGINT(0CCCCCCFFH);

	MouseWheelMultiplier = 3;


	NonDefaultFont = FALSE;

	(* Font to be used when NonDefaultFont = TRUE *)
	FontName = "Oberon";
	FontSize = 10;
	FontStyle = {};

TYPE

	NoWheelGrid* = OBJECT(WMStringGrids.StringGrid);

		PROCEDURE WheelMove*(dz : LONGINT); (* do nothing *) END WheelMove;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrNoWheelGrid);
		END Init;

	END NoWheelGrid;


	DiffState= OBJECT
	VAR state:LONGINT;
	END DiffState;

	DiffView = OBJECT (WMComponents.VisualComponent)
	VAR
		filenameEdit: WMEditors.Editor;
		lineNbr, grid: NoWheelGrid;
		colWidths : WMGrids.Spacings;
		commonLines, diffLines: LONGINT;
		diffColor, maxLineWidth, minLineWidth: LONGINT;
		curLine: LONGINT;
		font : WMGraphics.Font;
		onPropertyChange, onResized: WMEvents.EventSource;

		PROCEDURE CreateFilenamePanel() : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel; label: WMStandardComponents.Label;
		BEGIN
			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			panel.fillColor.Set(WMGraphics.White);

			NEW(label); label.bounds.SetWidth(60); label.alignment.Set(WMComponents.AlignLeft);
			label.alignH.Set(WMComponents.AlignLeft);
			label.SetCaption("Filename:");
			label.textColor.Set(WMGraphics.Black);
			label.fillColor.Set(BgColor);

			NEW(filenameEdit);
			filenameEdit.alignment.Set(WMComponents.AlignClient);
			filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filenameEdit.multiLine.Set(FALSE);
			filenameEdit.fillColor.Set(LONGINT(0FFFFFFFFH));
			filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			filenameEdit.tv.showBorder.Set(TRUE);
			filenameEdit.tv.SetExtDragOverHandler(FileNameEditDragOver);
			filenameEdit.tv.SetExtDragDroppedHandler(FileNameEditDragDropped);

			panel.AddContent(label);
			panel.AddContent(filenameEdit);

			RETURN panel;
		END CreateFilenamePanel;

		PROCEDURE CreateGrid() : NoWheelGrid;
		VAR grid : NoWheelGrid;
		BEGIN
			NEW(grid);
			grid.alignment.Set(WMComponents.AlignLeft);
			grid.clTextDefault.Set(WMGraphics.Black);
			grid.SetSelectionMode(WMGrids.GridSelectNone);
			grid.showScrollY.Set(FALSE);
			grid.showScrollX.Set(FALSE);
			grid.adjustFocusPosition.Set(FALSE);
			grid.defaultRowHeight.Set(15);
			grid.cellDist.Set(0);

			IF NonDefaultFont THEN
				grid.SetFont(WMGraphics.GetFont(FontName, FontSize, FontStyle));
			END;

			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.model.Release;

			RETURN grid;
		END CreateGrid;

		PROCEDURE &Init*;
		VAR scrollPanel : WMScrollableComponents.ScrollableContainer; VAR dx, dy : LONGINT;
		BEGIN
			Init^;
			SetNameAsString(StrDiffView);

			NEW(onPropertyChange, SELF, NIL, NIL, NIL);
			NEW(onResized, SELF, NIL, NIL, NIL);

			lineNbr := CreateGrid();
			IF ~ShowLineNumbers THEN lineNbr.visible.Set(FALSE); END;

			grid := CreateGrid();

			NEW(colWidths, 1); colWidths[0] := 256;

			AddContent(CreateFilenamePanel());
			AddContent(lineNbr);

			NEW(scrollPanel); scrollPanel.alignment.Set(WMComponents.AlignClient);
			scrollPanel.AddContent(grid);
			AddContent(scrollPanel);

			font := grid.GetFont();
			font.GetStringSize("0000", dx, dy); INC(dx, 4);

			lineNbr.bounds.SetWidth(dx);

			onPropertyChange.Call(NIL);
		END Init;

		PROCEDURE ToggleLineNumbers;
		BEGIN {EXCLUSIVE}
			lineNbr.visible.Set(~lineNbr.visible.Get());
			Invalidate;
		END ToggleLineNumbers;

		PROCEDURE SetNofLines(nofLines: LONGINT);
		BEGIN
			lineNbr.model.Acquire;
			grid.model.Acquire;
			lineNbr.model.SetNofRows(nofLines);
			grid.model.SetNofRows(nofLines);
			grid.model.Release;
			lineNbr.model.Release;
		END SetNofLines;

		PROCEDURE FileNameEditDragOver(x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
		BEGIN
			filenameEdit.tv.SelectAll;
			filenameEdit.tv.SetFocus;
			handled := TRUE;
		END FileNameEditDragOver;

		PROCEDURE FileNameEditDragDropped(x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
		VAR dropTarget : WMTextView.TextDropTarget; p : Texts.TextPosition;
		BEGIN
			filenameEdit.SetAsString("");
			filenameEdit.text.AcquireRead;
			NEW(p, filenameEdit.text); p.SetPosition(0);
			NEW(dropTarget, filenameEdit.text, p);
			filenameEdit.text.ReleaseRead;
			IF ~filenameEdit.tv.hasFocus & ~filenameEdit.tv.alwaysShowCursor.Get() THEN filenameEdit.tv.cursor.SetVisible(FALSE) END;
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo);
			handled := TRUE;
		END FileNameEditDragDropped;

		PROCEDURE FillLines(nofRows, nofLines: LONGINT);
		VAR i: LONGINT;
		BEGIN
			grid.model.Acquire;
			FOR i := nofRows TO nofLines DO
				lineNbr.model.InsertEmptyRow(i);
				grid.model.InsertEmptyRow(i);
			END;
			grid.model.Release;
		END FillLines;

		PROCEDURE InsertLine (pos, line: LONGINT; string: Strings.String; out : Streams.Writer);
		VAR intStr: ARRAY 32 OF CHAR; nofRows: LONGINT; diffState : DiffState; lineWidth, dy: LONGINT;
		BEGIN
			font.GetStringSize(string^, lineWidth, dy); INC(lineWidth,4);
			maxLineWidth := Strings.Max(lineWidth, maxLineWidth);
			lineNbr.model.Acquire;
			grid.model.Acquire;
			nofRows := grid.model.GetNofRows();
			IF nofRows <= curLine THEN
				FillLines(nofRows, curLine)
			END;
			(* line number *)
			Strings.IntToStr(line, intStr);
			lineNbr.model.SetCellText(0, curLine, Strings.NewString(intStr));
			lineNbr.model.SetTextAlign(0, curLine, WMGraphics.AlignCenter);
			lineNbr.model.SetCellColors(0, curLine, LineNbrBgColor, WMGraphics.Black);

			grid.model.SetCellText (0, curLine, string);
			grid.model.SetCellColors(0, curLine, diffColor, WMGraphics.Black);

			NEW(diffState); diffState.state := DiffStateDifferent;
			grid.model.SetCellData(0, curLine, diffState);
			grid.model.Release;
			lineNbr.model.Release;
			INC(curLine); INC(diffLines);
		END InsertLine;

		PROCEDURE InsertEmptyLine;
		VAR nofRows: LONGINT;
		BEGIN
			lineNbr.model.Acquire;
			grid.model.Acquire;
			nofRows  := grid.model.GetNofRows();
			IF nofRows <= curLine THEN
				FillLines(nofRows, curLine)
			END;
			lineNbr.model.SetCellText(0, curLine, NIL);
			lineNbr.model.SetCellColors(0, curLine, LineNbrBgColor, WMGraphics.Black);
			grid.model.SetCellText(0, curLine, NIL);
			grid.model.SetCellData(0, curLine, NIL);
			grid.model.SetCellColors(0, curLine, EmptyLineColor, WMGraphics.Black);
			grid.model.Release;
			lineNbr.model.Release;
			INC(curLine);
		END InsertEmptyLine;

		PROCEDURE InsertCommonLine (pos, line: LONGINT; string: Strings.String; out : Streams.Writer);
		VAR intStr: ARRAY 32 OF CHAR; nofRows, lineWidth, dy: LONGINT;
		BEGIN
			font.GetStringSize(string^, lineWidth, dy); INC(lineWidth, 4);
			maxLineWidth := Strings.Max(lineWidth, maxLineWidth);
			lineNbr.model.Acquire;
			grid.model.Acquire;
			nofRows := grid.model.GetNofRows();
			IF nofRows <= curLine THEN
				FillLines(nofRows, curLine)
			END;

			Strings.IntToStr(line, intStr);
			lineNbr.model.SetCellText(0, curLine, Strings.NewString(intStr));
			lineNbr.model.SetTextAlign(0, curLine, WMGraphics.AlignCenter);
			lineNbr.model.SetCellColors(0, curLine, LineNbrBgColor, WMGraphics.AlignCenter);

			grid.model.SetCellText (0, curLine, string);
			grid.model.SetCellData(0, curLine, NIL);
			grid.model.Release;
			lineNbr.model.Release;
			INC (commonLines); INC(curLine);
		END InsertCommonLine;

		PROCEDURE SetFileName(fileName: ARRAY OF CHAR);
		BEGIN
			filenameEdit.SetAsString(fileName);
		END SetFileName;

		PROCEDURE GetFileName(): Strings.String;
		VAR string, fileName: Files.FileName; count: LONGINT; sr: Streams.StringReader;
		BEGIN
			filenameEdit.GetAsString(string);
			count := UTF8Strings.UTF8toASCII(string, " ", fileName);
			(* parse filename *)
			NEW(sr, LEN(fileName)); sr.Set(fileName);
			sr.SkipWhitespace; sr.String(fileName);
			RETURN Strings.NewString(fileName);
		END GetFileName;

		PROCEDURE Setup;
		BEGIN
			filenameEdit.tv.defaultTextColor.Set(WMGraphics.Black);
			maxLineWidth := minLineWidth; commonLines  := 0; diffLines := 0; curLine := 0;
			SetNofLines(1);
		END Setup;

		PROCEDURE Update;
		BEGIN
			IF diffLines > 0 THEN
				filenameEdit.tv.defaultTextColor.Set(DarkRed);
			ELSE
				filenameEdit.tv.defaultTextColor.Set(DarkGreen);
			END;
			colWidths[0] := maxLineWidth;
			grid.SetColSpacings(colWidths);
			grid.bounds.SetWidth(maxLineWidth);
			SetNofLines(curLine);
			Invalidate;
		END Update;

		PROCEDURE Resized*;
		BEGIN
			Resized^;
			onResized.Call(NIL);
		END Resized;

	END DiffView;

TYPE

	Overview= OBJECT(WMComponents.VisualComponent)
	VAR
		view: DiffView;
		img: WMGraphics.Image;
		nofRows, pageStart, pageSize: LONGINT;
		showPage: BOOLEAN;
		diffColor : LONGINT;

		PROCEDURE &New*(view: DiffView);
		BEGIN
			Init;
			SetNameAsString(StrOverview);
			SELF.view:= view;
		END New;

		PROCEDURE SetPage(pageStart, pageSize: LONGINT);
		VAR barHeight: LONGINT;
		BEGIN
			IF nofRows < 1 THEN RETURN; END;
			showPage := TRUE;
			barHeight := bounds.GetHeight()- 2*ScrollbarWidth;
			pageStart := barHeight * pageStart DIV nofRows;
			pageSize := pageSize * barHeight DIV nofRows;
			SELF.pageStart := Strings.Max(pageStart, 0);
			SELF.pageSize := Strings.Min(barHeight-pageStart, Strings.Max(pageSize, 1));
			Invalidate;
		END SetPage;

		PROCEDURE Resized*;
		VAR rect: WMRectangles.Rectangle;
		BEGIN
			Resized^;
			NEW(img);
			rect := GetClientRect();
			INC(rect.t, ScrollbarWidth); DEC(rect.b, ScrollbarWidth);
			IF ~WMRectangles.RectEmpty(rect) THEN
				Raster.Create(img, rect.r-rect.l, rect.b-rect.t, Raster.BGR565);
				Update;
			END;
		END Resized;

		PROCEDURE Setup;
		VAR c: WMGraphics.BufferCanvas; rect: WMRectangles.Rectangle;
		BEGIN
			IF img # NIL THEN
				NEW(c,img);
				rect := WMRectangles.MakeRect(0,0,img.width, img.height);
				c.Fill(rect, LONGINT(0808080FFH), WMGraphics.ModeCopy);
				Invalidate;
			END;
		END Setup;

		PROCEDURE Update;
		VAR pos: LONGINT; fact: REAL; c: WMGraphics.BufferCanvas;
			rect : WMRectangles.Rectangle;
			i: LONGINT;
			data:ANY;
			prev: BOOLEAN;
		BEGIN
			IF img = NIL THEN
				NEW(img);
				Raster.Create(img, bounds.GetWidth(), bounds.GetHeight()- 2* ScrollbarWidth, Raster.BGR565);
			END;
			NEW(c,img);
			rect := WMRectangles.MakeRect(0, 0,img.width, img.height);
			c.Fill(rect, LONGINT(0808080FFH), WMGraphics.ModeCopy);
			view.grid.model.Acquire;
			nofRows:= view.grid.model.GetNofRows();
			IF nofRows > 0 THEN
				fact := img.height / nofRows;
				WMRectangles.SetRect(rect, 0, 0, img.width, 1);
				(* draw different lines in left View *)
				prev := FALSE;
				FOR i := 1 TO nofRows-1 DO
					data := view.grid.model.GetCellData(0, i);
					IF data # NIL THEN
						pos := ENTIER(fact * i + 0.5);
						IF ~prev THEN rect.t := pos; rect.b := pos + 1; prev := TRUE
						ELSE
							rect.b := Strings.Max(rect.b, pos+1);
						END;
					ELSE
						IF prev THEN
							c.Fill(rect, diffColor, WMGraphics.ModeCopy);
							prev := FALSE;
						END;
					END;
				END;
				IF prev THEN
					c.Fill(rect, diffColor, WMGraphics.ModeCopy);
					prev := FALSE;
				END;
			END;
			view.grid.model.Release;
			Invalidate;
		END Update;

		(** Is called before any sub-components are drawn *)
		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR rect: WMRectangles.Rectangle; (* x0, x1: LONGINT; *)
		BEGIN
			rect := GetClientRect();
			canvas.Fill(rect, LONGINT(0CCCCCCFFH), WMGraphics.ModeCopy);
			IF img # NIL THEN
				canvas.DrawImage(0,ScrollbarWidth,img, WMGraphics.ModeCopy);
				IF showPage THEN
					canvas.Fill(WMRectangles.MakeRect(rect.l, pageStart + ScrollbarWidth, rect.r, pageStart + pageSize + ScrollbarWidth), 040H, WMGraphics.ModeSrcOverDst);
				END
			END;
		END DrawBackground;

	END Overview;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		leftView, rightView: DiffView;
		lblcommonLines, lbldiffLinesLeft, lbldiffLinesRight : WMStandardComponents.Label;
		scrolly : WMStandardComponents.Scrollbar;
		leftOverview, rightOverview: Overview;
		pageSize: LONGINT;

		PROCEDURE &New *(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			Init (vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent (vc);
			SetTitle (WM.NewString("Diff"));
			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
			ELSE
				WM.DefaultAddWindow(SELF);
			END;
			IncCount;
		END New;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			label: WMStandardComponents.Label;
			panel, status, middlePanel, scrollPanel: WMStandardComponents.Panel;
			diffBtn: WMStandardComponents.Button;
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents (Width, Height); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set (WMGraphics.White);

			NEW(status); status.alignment.Set(WMComponents.AlignBottom); status.bounds.SetHeight(20);
			panel.AddContent(status); status.fillColor.Set(BgColor);

			NEW(label); label.bounds.SetWidth(100); label.caption.SetAOC("Common Lines: "); label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(lblcommonLines); lblcommonLines.bounds.SetWidth(100); lblcommonLines.caption.SetAOC("-");
			lblcommonLines.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(lblcommonLines);

			NEW(label); label.bounds.SetWidth(150); label.caption.SetAOC("Different Lines Left File: ");
			label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(lbldiffLinesLeft); lbldiffLinesLeft.bounds.SetWidth(100); lbldiffLinesLeft.caption.SetAOC("-");
			lbldiffLinesLeft.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(lbldiffLinesLeft);

			NEW(label); label.bounds.SetWidth(150); label.caption.SetAOC("Different Lines Right File: ");
			label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(lbldiffLinesRight); lbldiffLinesRight.bounds.SetWidth(100); lbldiffLinesRight.caption.SetAOC("-");
			lbldiffLinesRight.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(lbldiffLinesRight);

			NEW(leftView);
			leftView.bounds.SetWidth ((Width - 2*OverviewWidth - ScrollbarWidth) DIV 2);
			leftView.alignment.Set(WMComponents.AlignLeft);
			leftView.onPropertyChange.Add(OnViewPropertyChange);
			leftView.onResized.Add(OnViewResized);
			leftView.diffColor := DiffColorLeft;
			panel.AddContent (leftView);

			NEW(rightView);
			rightView.bounds.SetWidth ((Width - 2*OverviewWidth - ScrollbarWidth) DIV 2);
			rightView.alignment.Set(WMComponents.AlignLeft);
			rightView.diffColor := DiffColorRight;
			rightView.onPropertyChange.Add(OnViewPropertyChange);
			rightView.onResized.Add(OnViewResized);

			leftView.filenameEdit.onEnter.Add(DiffHandler);
			rightView.filenameEdit.onEnter.Add(DiffHandler);

			NEW(middlePanel);
			middlePanel.bounds.SetWidth (2*OverviewWidth + ScrollbarWidth); middlePanel.alignment.Set(WMComponents.AlignLeft);
			middlePanel.fillColor.Set (LONGINT(0FFFFFFFFH));

			NEW(diffBtn); diffBtn.caption.SetAOC("Diff"); diffBtn.alignment.Set(WMComponents.AlignTop);
			diffBtn.onClick.Add(DiffHandler);
			diffBtn.bounds.SetHeight(20);
			middlePanel.AddContent(diffBtn);

			NEW(scrollPanel); scrollPanel.alignment.Set(WMComponents.AlignClient);
			scrollPanel.fillColor.Set (LONGINT(0FFFFFFFFH));

			NEW(leftOverview, leftView);
			leftOverview.bounds.SetWidth(OverviewWidth); leftOverview.alignment.Set(WMComponents.AlignLeft);
			leftOverview.diffColor := WMGraphics.Red;
			scrollPanel.AddContent(leftOverview);

			NEW(scrolly);
			scrolly.bounds.SetWidth(ScrollbarWidth); scrolly.alignment.Set(WMComponents.AlignLeft);
			scrolly.vertical.Set(TRUE);
			scrolly.onPositionChanged.Add(SELF.Scrolled);
			scrollPanel.AddContent(scrolly);

			NEW(rightOverview, rightView);
			rightOverview.bounds.SetWidth(OverviewWidth); rightOverview.alignment.Set(WMComponents.AlignLeft);
			rightOverview.diffColor := WMGraphics.Blue;
			scrollPanel.AddContent(rightOverview);

			middlePanel.AddContent(scrollPanel);
			panel.AddContent(middlePanel);

			panel.AddContent (rightView);
			RETURN panel
		END CreateForm;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE Load*(leftFilename,  rightFilename : ARRAY OF CHAR);
		BEGIN
			leftView.SetFileName(leftFilename);
			rightView.SetFileName(rightFilename);
			IF (leftFilename # "") OR  (rightFilename # "") THEN DiffHandler(NIL, NIL) END;
			Resized(Width, Height);
		END Load;

		PROCEDURE Resized*(width, height : LONGINT);
		VAR viewWidth: LONGINT;
		BEGIN
			Resized^(width, height);
			viewWidth := (width - 2*OverviewWidth - ScrollbarWidth) DIV 2;
			leftView.bounds.SetWidth(viewWidth);
			rightView.bounds.SetWidth(viewWidth);
		END Resized;

		PROCEDURE OnViewResized(sender, par: ANY);
		BEGIN
			SetScrollbarProperties;
			Scrolled(NIL, NIL)
		END OnViewResized;

		PROCEDURE Setup(nofLines: LONGINT);
		BEGIN
			leftView.SetNofLines(nofLines + 1);
			rightView.SetNofLines(nofLines + 1);
		END Setup;

		PROCEDURE SetScrollbarProperties;
		BEGIN
			pageSize := leftView.grid.bounds.GetHeight() DIV leftView.grid.defaultRowHeight.Get();
			scrolly.pageSize.Set(pageSize);
			scrolly.min.Set(0); scrolly.max.Set(Strings.Max(leftView.curLine, rightView.curLine) - pageSize);
		END SetScrollbarProperties;

		PROCEDURE Update;
		VAR intStr: ARRAY 32 OF CHAR;
		BEGIN
			leftView.Update;
			rightView.Update;
			Strings.IntToStr(leftView.commonLines, intStr);
			lblcommonLines.caption.SetAOC(intStr);
			Strings.IntToStr(rightView.diffLines, intStr);
			IF rightView.diffLines > 0 THEN
				lbldiffLinesRight.textColor.Set(DarkRed);
			ELSE
				lbldiffLinesRight.textColor.Set(DarkGreen);
			END;
			lbldiffLinesRight.caption.SetAOC(intStr);
			IF leftView.diffLines > 0 THEN
				lbldiffLinesLeft.textColor.Set(DarkRed);
			ELSE
				lbldiffLinesLeft.textColor.Set(DarkGreen);
			END;
			Strings.IntToStr(leftView.diffLines, intStr);
			lbldiffLinesLeft.caption.SetAOC(intStr);
			leftOverview.Update;
			rightOverview.Update;
			SetScrollbarProperties;
			Scrolled(NIL, NIL);
		END Update;

		PROCEDURE DiffHandler(sender, par: ANY);
		VAR leftFile, rightFile: Strings.String;
		BEGIN
			lbldiffLinesLeft.textColor.Set(WMGraphics.Black); lbldiffLinesLeft.caption.SetAOC("-");
			lbldiffLinesRight.textColor.Set(WMGraphics.Black); lblcommonLines.caption.SetAOC("-");
			lbldiffLinesRight.caption.SetAOC("-");
			leftView.Setup; leftOverview.Setup;
			rightView.Setup; rightOverview.Setup;
			leftFile := leftView.GetFileName();
			rightFile := rightView.GetFileName();
			DisableUpdate;
			DiffLib.Diff (leftFile^, rightFile^, Setup, leftView.InsertLine, rightView.InsertLine, leftView.InsertCommonLine, rightView.InsertCommonLine, leftView.InsertEmptyLine, rightView.InsertEmptyLine, NIL);
			EnableUpdate;
			Update;
		END DiffHandler;

		PROCEDURE OnViewPropertyChange(sender, par: ANY);
		VAR ymax: LONGINT;
		BEGIN
			ymax := sender(DiffView).grid.nofRows.Get();
			scrolly.max.Set(ymax);
		END OnViewPropertyChange;

		PROCEDURE Scrolled(sender, data : ANY);
		VAR col, coll, row, rowl : LONGINT;
		BEGIN
			rightView.lineNbr.GetTopPosition(coll, rowl);
			rightView.grid.GetTopPosition(col, row);
			rightView.lineNbr.SetTopPosition(coll,  scrolly.pos.Get(), FALSE);
			rightView.grid.SetTopPosition(col, scrolly.pos.Get(), FALSE);

			leftView.lineNbr.GetTopPosition(coll, rowl);
			leftView.grid.GetTopPosition(col, row);
			leftView.lineNbr.SetTopPosition(coll,  scrolly.pos.Get(), FALSE);
			leftView.grid.SetTopPosition(col, scrolly.pos.Get(), FALSE);
			leftOverview.SetPage(scrolly.pos.Get(), pageSize);
			rightOverview.SetPage(scrolly.pos.Get(), pageSize);
		END Scrolled;

		PROCEDURE HandleKey(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;
		VAR handled : BOOLEAN;
		BEGIN
			handled := TRUE;
			IF (ucs = 0A2H) THEN (* PgUp *)
				scrolly.PageUp(NIL, NIL);
			ELSIF (ucs = 0A3H) THEN (* PgDn *)
				scrolly.PageDown(NIL, NIL);
			ELSIF (ucs = 0A8H) THEN (* Home *)
				scrolly.pos.Set(scrolly.min.Get()); Scrolled(NIL, NIL);
			ELSIF (ucs = 0A9H) THEN (* End *)
				scrolly.pos.Set(scrolly.max.Get()); Scrolled(NIL, NIL);
			ELSIF (ucs = 0A0H) THEN (* Insert *)
				leftView.ToggleLineNumbers;
				rightView.ToggleLineNumbers;
			ELSIF (ucs = 0C1H) THEN (* Cursor Up *)
				scrolly.DecPos(NIL, NIL);
			ELSIF (ucs = 0C2H) THEN (* Cursor Down *)
				scrolly.IncPos(NIL, NIL);
			ELSE
				handled := FALSE;
			END;
			RETURN handled;
		END HandleKey;

		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF (m.msgType = WMMessages.MsgKey) THEN
				IF ~HandleKey(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSIF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext IS KillerMsg) THEN Close
				ELSE Handle^(m)
				END
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE WheelMove*(dz : LONGINT);
		VAR pos : LONGINT;
		BEGIN
			pos := scrolly.pos.Get() + MouseWheelMultiplier * dz;
			IF pos < scrolly.min.Get() THEN pos := scrolly.min.Get(); END;
			IF pos > scrolly.max.Get() THEN pos := scrolly.max.Get(); END;
			scrolly.pos.Set(pos);
			scrolly.onPositionChanged.Call(scrolly.pos)
		END WheelMove;
	END Window;

VAR
	nofWindows : LONGINT;

	StrDiffView, StrOverview, StrNoWheelGrid : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrDiffView := Strings.NewString("DiffView");
	StrOverview := Strings.NewString("Overview");
	StrNoWheelGrid := Strings.NewString("NoWheelGrid");
END InitStrings;

PROCEDURE Open* (context : Commands.Context); (** [filename1 filename2] ~ *)
VAR left, right : ARRAY 64 OF CHAR; window: Window;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(left);
	context.arg.SkipWhitespace; context.arg.String(right);
	NEW(window, NIL); window.Load(left, right);
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
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
END WMDiff.

PC.Compile \s DiffLib.Mod XStandardComponents.Mod WMDiff.Mod~

SystemTools.Free WMDiff DiffLib~

Problem: When the overview bar is drawn, it is scaled for speedup. This may lead to the disappearance of marking for line differences.
Therefore documents with different lines are marked additionally by a red filename.

WMDiff.Open ~

WMDiff.Open UsbEhci.Mod UsbEhci.Mod ~

WMDiff.Open AosSetup.Text AosSetup.Text ~

WMDiff.Open WMPerfMon.Mod WMPerfMon.Mod.Bak ~

WMDiff.Open WMDiff.Mod WMDiff.Mod.Bak ~