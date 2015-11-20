MODULE WMTextView; (** AUTHOR "TF"; PURPOSE "Generic unicode text viewer"; *)

IMPORT
	Kernel, Modules, Inputs, KernelLog, XML, Texts, TextUtilities, SyntaxHighlighter,
	WMGraphics, WMGraphicUtilities, WMMessages, WMComponents,
	WMStandardComponents, Strings, WMDropTarget, Raster,
	WMRectangles, WMWindowManager, WMProperties,
	Commands, FileHandlers, Streams, WMPopups, FP1616,
	WMPieMenu, WMEvents, UnicodeBidirectionality, PositionDebugging, ContextualDependency;

CONST
	TraceRenderOptimize = 0;
	TraceLayout = 1;
	TraceBaseLine = 2;
	TraceInvalidate = 3;
	TraceCopy = 4;
	TraceCommands = 5;
	Trace = {};

	(* 	When pressing the middle mouse button and holding down ALT, execute this command with
		the actual command and its parameters as parameter *)
	AltMMCommand = "WMUtilities.Call";

	CallURLPointer = 0;	(* mousebutton which will invoke the URL *)

	(** Text wrapping modes (default = WrapWord) *)
	NoWrap* = 0; Wrap* = 1; WrapWord* = 2;

	AlignLeft = 0; AlignCenter = 1; AlignRight = 2;

	DragDist = 5;
	MaxCallParameterBuf = 1 * 1024 * 1024;
	MaxCommandLength = 256; (* without parameters *)

	(* If TRUE, a mouse right click will open a pie menu *)
	UsePieMenu = TRUE;

	InterclickNone = 0;
	Interclick01 = 1;	(* mouse button 0 & 1 *)
	Interclick02 = 2; (* mouse button 0 & 2 *)
	InterclickCancelled = 99;

	SelectionColor = 0000FF60H;
	SelectionColorInterclick01 = LONGINT(0FFFF0060H);
	SelectionColorInterclick02 = LONGINT(0FF000060H);

TYPE
	Char32 = Texts.Char32;

	ClickInfo = OBJECT
	VAR
		cmd, cmdPar : Strings.String;
	END ClickInfo;

	TabStops* = OBJECT
	VAR tabDist : LONGINT;
		(* return the next TabStop from the x position *)
		PROCEDURE GetNextTabStop*(x : LONGINT) : LONGINT;
		BEGIN
			RETURN ((x DIV tabDist) + 1) * tabDist
		END GetNextTabStop;
	END TabStops;

	TabPositions* = POINTER TO ARRAY OF LONGINT;

	CustomTabStops* = OBJECT (TabStops)
	VAR
		positions : TabPositions;

		PROCEDURE GetNextTabStop*(x : LONGINT) : LONGINT;
		VAR
			idx : LONGINT;
		BEGIN
			idx := 0;
			ASSERT(positions # NIL);
			IF x >= positions[LEN(positions) - 1] THEN RETURN GetNextTabStop^(x) END; (* return default tab stop *)
			WHILE x >= positions[idx] DO INC(idx) END;
			RETURN positions[idx]
		END GetNextTabStop;

		PROCEDURE &New *(tp : TabPositions);
		VAR
			idx : LONGINT;
		BEGIN
			idx := 0; tabDist := 150;
			WHILE idx < LEN(tp)-1 DO ASSERT(tp[idx] <= tp[idx+1]); INC(idx) END;
			positions := tp
		END New;
	END CustomTabStops;

	LineInfo = RECORD
		leftIndent, rightIndent, firstIndent, spaceBefore, spaceAfter : LONGINT;
		firstInParagraph, lastInParagraph : BOOLEAN;
		height, width, ascent : LONGINT;
		pos : LONGINT; (* the position in the text, where this line starts *)
		align : LONGINT;
		tabStops : TabStops;
	END;

	LineInfoArray = POINTER TO ARRAY OF LineInfo;

TYPE

	Layout = OBJECT
	VAR
		nofLines : LONGINT;
		lines : LineInfoArray;
		text : Texts.Text;
		paperWidth : LONGINT;
		textWidth : LONGINT; (* maximal width of the text <= textWidth *)
		textHeight : LONGINT;
		layoutLineProc : PROCEDURE {DELEGATE} (VAR pos : LONGINT; VAR ch : Char32; VAR lineInfo : LineInfo; wrapWidth, stopPos, stopXPos : LONGINT);
		bidiFormatter : UnicodeBidirectionality.BidiFormatter;
		initialized : BOOLEAN;

		PROCEDURE &New*;
		BEGIN
			NEW(lines, 4);
			(* this helps saving some bidi computations *)
			initialized := FALSE;
		END New;

		(** Replace the text *)
		PROCEDURE SetText(text : Texts.Text);
		BEGIN
			ASSERT(text # NIL);
			SELF.text := text;
		END SetText;

		PROCEDURE GrowLines;
		VAR i : LONGINT; newLines : LineInfoArray;
		BEGIN
			NEW(newLines, LEN(lines) * 2);
			FOR i := 0 TO LEN(lines) - 1 DO newLines[i] := lines[i] END;
			lines := newLines
		END GrowLines;

		(** find the linenumber by the position *)
		PROCEDURE FindLineNrByPos(pos : LONGINT) : LONGINT;
		VAR a, b, m : LONGINT;
		BEGIN
			a := 0; b := nofLines - 1;
			WHILE (a < b) DO m := (a + b) DIV 2;
				IF lines[m].pos <= pos THEN a := m + 1
				ELSE b := m
				END
			END;
			(* last line hack *)
			IF lines[a].pos <= pos THEN INC(a) END;
			RETURN a - 1
		END FindLineNrByPos;

		PROCEDURE GetLineStartPos(lineNr : LONGINT) : LONGINT;
		BEGIN
			IF (lineNr >= 0) & (lineNr < nofLines) THEN RETURN lines[lineNr].pos ELSE RETURN 0 END
		END GetLineStartPos;

		(** return the length in characters of this line *)
		PROCEDURE GetLineLength(lineNr : LONGINT) : LONGINT;
		BEGIN
			IF (lineNr >= 0) & (lineNr < nofLines - 1) THEN RETURN lines[lineNr + 1].pos - lines[lineNr].pos
			ELSE
				IF (lineNr >= 0) & (lineNr < nofLines) THEN RETURN  text.GetLength() - lines[lineNr].pos + 1
				ELSE RETURN 0
				END
			END
		END GetLineLength;

		PROCEDURE GetNofLines() : LONGINT;
		BEGIN
			RETURN nofLines
		END GetNofLines;

		PROCEDURE LayoutLine(VAR pos : LONGINT; VAR lineInfo : LineInfo);
		VAR
			dummyCh : Char32;
		BEGIN
			IF layoutLineProc # NIL THEN layoutLineProc(pos, dummyCh, lineInfo, paperWidth, -1, -1) END
		END LayoutLine;

		(* generate a new layout from scratch. if the text has not actually changed, no bidi-reformatting needs to be done *)
		PROCEDURE FullLayout(textChanged : BOOLEAN);
		VAR i, pos, oldpos : LONGINT;
		BEGIN
			ASSERT((text # NIL) & (lines#NIL));
			text.AcquireRead;
			textWidth := 0;
			IF TraceLayout IN Trace THEN KernelLog.String("FullLayout"); KernelLog.Ln END;

			(* create a new bidiformatter and reformat the whole text if necessary *)
			IF textChanged & initialized & text.isUTF THEN
				NEW(bidiFormatter,text);
				bidiFormatter.ReformatText;
			END;

			i := 0;
			pos := 0; nofLines := 0; textHeight := 0;
			WHILE pos < text.GetLength() DO
				oldpos := pos;
				LayoutLine(pos, lines[nofLines]); INC(textHeight, lines[nofLines].height);
				textWidth := Strings.Max(textWidth, lines[nofLines].width);
				ASSERT(pos > oldpos);
				IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
				INC(nofLines); IF nofLines >= LEN(lines) THEN GrowLines END
			END;
			IF TraceLayout IN Trace THEN KernelLog.String("FullLayout found "); KernelLog.Int(nofLines, 4); KernelLog.String(" lines"); KernelLog.Ln END;
			text.ReleaseRead
		END FullLayout;

			(** Fix the layouting of the text starting at pos where delta characters have been inserted (delta negativ if deleted) *)
		PROCEDURE FixLayoutFrom(pos, delta : LONGINT; VAR first, last : LONGINT; VAR linesChanged : BOOLEAN);
		VAR l, dl, oldh : LONGINT;
		BEGIN
			ASSERT(text # NIL);
			text.AcquireRead;
			linesChanged := FALSE;
			l := FindLineNrByPos(pos);
			IF (l < 0) THEN FullLayout(TRUE); first := 0; last := nofLines; text.ReleaseRead; RETURN END;
			pos := lines[l].pos;
			oldh := lines[l].height;
			LayoutLine(pos, lines[l]);
			IF oldh # lines[l].height THEN linesChanged := TRUE END;
			first := l;
			INC(l); dl := 0;
			IF (delta < 0) THEN
				IF (l >= nofLines) OR (lines[l].pos + delta = pos) THEN
					last := l;
					WHILE (l < nofLines) DO lines[l].pos := lines[l].pos + delta; INC(l) END
				ELSE
					linesChanged := TRUE;
					WHILE (pos < text.GetLength())   DO
						DEC(textHeight, lines[l].height);
						LayoutLine(pos, lines[l]);
						textWidth := Strings.Max(textWidth, lines[l].width);
						INC(textHeight, lines[nofLines].height);
						INC(dl);
						IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
						INC(l);
						IF l >= LEN(lines) THEN GrowLines END
					END;
					nofLines := l ;
					last := nofLines - 1
				END
			ELSE
				WHILE (pos < text.GetLength()) & (lines[l].pos + delta # pos)  DO
					linesChanged := TRUE;
					DEC(textHeight, (lines[l].height));
					LayoutLine(pos, lines[l]);
					textWidth := Strings.Max(textWidth, lines[l].width);
					INC(textHeight, (lines[nofLines].height));
					INC(dl);
					IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
					INC(l); IF l >= LEN(lines) THEN GrowLines END
				END;
				last := l;
				IF TraceLayout IN Trace THEN
					KernelLog.String("Delta Lines : "); KernelLog.Int(dl, 4); KernelLog.Ln;
					KernelLog.String("Lines to redraw : "); KernelLog.Int(first, 5); KernelLog.String(" to "); KernelLog.Int(last, 5); KernelLog.Ln
				END;
				(* fix up the positions *)
				IF l < nofLines THEN WHILE (l < nofLines) DO lines[l].pos := lines[l].pos + delta; INC(l) END
				ELSE nofLines := l
				END
			END;
			text.ReleaseRead
		END FixLayoutFrom;

	END Layout;

CONST HLOver* = 0; HLUnder* = 1; HLWave* = 2;

TYPE
	Highlight* = OBJECT
	VAR
		kind : LONGINT;
		from*, to* : Texts.TextPosition;
		a*, b* : LONGINT; (* only valid after sort, while holding the lock *)
		active* : BOOLEAN; (* only valid after sort, while holding the lock *)
		oldFrom, oldTo : LONGINT;
		oldColor, color : WMGraphics.Color;
		text : Texts.UnicodeText;
		onChanged : WMMessages.CompCommand;

		PROCEDURE &New*;
		BEGIN
			color := SelectionColor;
			oldColor := color;
		END New;

		PROCEDURE SetKind*(kind : LONGINT);
		BEGIN
			IF SELF.kind # kind THEN
				SELF.kind := kind;
				onChanged(SELF, NIL)
			END
		END SetKind;

		PROCEDURE SetColor*(color : WMGraphics.Color);
		BEGIN
			oldColor := SELF.color;
			IF SELF.color # color THEN
				SELF.color := color;
				onChanged(SELF, NIL)
			END
		END SetColor;

		PROCEDURE SetFrom*(from : LONGINT);
		BEGIN
			IF text = NIL THEN RETURN END; (* if no text is set, the position within is undef *)
			text.AcquireRead;
			oldFrom := SELF.from.GetPosition();
			IF oldFrom # from THEN
				SELF.from.SetPosition(from);
				onChanged(SELF, NIL)
			END;
			text.ReleaseRead
		END SetFrom;

		PROCEDURE SetTo*(to : LONGINT);
		BEGIN
			IF text = NIL THEN RETURN END; (* if no text is set, the position within is undef *)
			text.AcquireRead;
			oldTo := SELF.to.GetPosition();
			IF oldTo # to THEN
				SELF.to.SetPosition(to);
				onChanged(SELF, NIL)
			END;
			text.ReleaseRead
		END SetTo;

		PROCEDURE SetFromTo*(from, to : LONGINT);
		BEGIN
			IF text = NIL THEN RETURN END; (* if no text is set, the position within is undef *)
			text.AcquireRead;
			oldTo := SELF.to.GetPosition();
			oldFrom := SELF.from.GetPosition();

			IF (oldTo # to) OR (oldFrom # from) THEN
				IF  ((oldTo = oldFrom) & (to = from)) THEN
					SELF.to.SetPosition(to);
					SELF.from.SetPosition(from)
				ELSE
					SELF.to.SetPosition(to);
					SELF.from.SetPosition(from);
					onChanged(SELF, NIL)
				END
			END;
			text.ReleaseRead
		END SetFromTo;

		PROCEDURE Sort*;
		VAR t : LONGINT;
		BEGIN
			a := from.GetPosition();
			b := to.GetPosition();
			IF a > b THEN t := a; a := b; b := t END;
			active := a # b
		END Sort;

		PROCEDURE SetText(text : Texts.UnicodeText);
		BEGIN
			IF text # NIL THEN SELF.text := text; NEW(from, text); NEW(to, text) END
		END SetText;

	END Highlight;

	HighlightArray = POINTER TO ARRAY OF Highlight;

TYPE
	PositionMarker* = OBJECT
	VAR
		pos : Texts.TextPosition;

		img : WMGraphics.Image;
		color : WMGraphics.Color;

		hotX, hotY : LONGINT;
		currentArea : WMRectangles.Rectangle;
		text : Texts.UnicodeText;
		onChanged : WMMessages.CompCommand;
		visible : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			color := LONGINT(0FF0000CCH); visible := TRUE
		END Init;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; x, y, ascent : LONGINT);
		BEGIN
			IF ~visible THEN RETURN END;
			IF img # NIL THEN canvas.DrawImage(x - hotX, y - hotY, img, WMGraphics.ModeSrcOverDst)
			ELSE
				currentArea := GetArea(x, y, ascent);
				canvas.Fill(currentArea, LONGINT(0FF0000CCH), WMGraphics.ModeSrcOverDst)
			END
		END Draw;

		PROCEDURE GetArea(x, y, ascent : LONGINT) : WMRectangles.Rectangle;
		BEGIN
			IF img # NIL THEN RETURN WMRectangles.MakeRect(x - hotX, y - hotY, x - hotX + img.width, y - hotY + img.height)
			ELSE RETURN WMRectangles.MakeRect(x , y - ascent, x + 2, y)
			END
		END GetArea;

		PROCEDURE Load*(CONST filename : ARRAY OF CHAR);
		BEGIN
			img := WMGraphics.LoadImage(filename, TRUE);
			IF img # NIL THEN hotX := img.width DIV 2; hotY := img.height DIV 2 END;
			onChanged(SELF, NIL)
		END Load;

		PROCEDURE SetVisible*(visible : BOOLEAN);
		BEGIN
			IF SELF.visible # visible THEN
				SELF.visible := visible;
				onChanged(SELF, NIL)
			END
		END SetVisible;

		PROCEDURE SetPosition*(pos : LONGINT);
		BEGIN
			IF text = NIL THEN RETURN END; (* if no text is set, the position within is undef *)
			text.AcquireRead;
			IF pos # SELF.pos.GetPosition() THEN
				SELF.pos.SetPosition(pos);
				onChanged(SELF, NIL)
			END;
			text.ReleaseRead
		END SetPosition;

		PROCEDURE GetPosition*() : LONGINT;
		BEGIN
			RETURN pos.GetPosition()
		END GetPosition;

		PROCEDURE SetColor*(color : WMGraphics.Color);
		BEGIN
			IF SELF.color # color THEN
				SELF.color := color;
				onChanged(SELF, NIL)
			END
		END SetColor;

		PROCEDURE SetText(text : Texts.UnicodeText);
		BEGIN
			IF text # NIL THEN
				SELF.text := text;
				NEW(pos, text);
			END
		END SetText;

		PROCEDURE SetNextInternalPosition*(next : LONGINT);
		BEGIN
			pos.nextInternalPos := next;
		END SetNextInternalPosition;

		PROCEDURE GetNextInternalPosition*() : LONGINT;
		BEGIN
			RETURN pos.nextInternalPos;
		END GetNextInternalPosition;

	END PositionMarker;

	PositionMarkerArray = POINTER TO ARRAY OF PositionMarker;

TYPE

	Cursor = OBJECT(PositionMarker)
	VAR
		isVisible : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			isVisible := TRUE;
		END Init;

		PROCEDURE SetCurrentVisibility(isVisible : BOOLEAN);
		BEGIN
			IF (SELF.isVisible # isVisible) THEN
				SELF.isVisible := isVisible;
				onChanged(SELF, NIL);
			END;
		END SetCurrentVisibility;

		PROCEDURE GetArea(x, y, ascent : LONGINT) : WMRectangles.Rectangle;
		BEGIN
			IF img # NIL THEN RETURN WMRectangles.MakeRect(x - hotX, y - hotY, x - hotX + img.width, y - hotY + img.height)
			ELSE RETURN WMRectangles.MakeRect(x , y - ascent - 2, x + 1, y + 2)
			END
		END GetArea;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; x, y, ascent : LONGINT);
		BEGIN
			IF ~visible OR ~isVisible THEN RETURN END;
			IF img # NIL THEN canvas.DrawImage(x - hotX, y - hotY, img, WMGraphics.ModeSrcOverDst)
			ELSE
				currentArea := GetArea(x, y, ascent);
				canvas.Fill(currentArea, WMGraphics.Black, WMGraphics.ModeSrcOverDst)
			END
		END Draw;

	END Cursor;

TYPE

	CursorBlinkerCallback = PROCEDURE {DELEGATE} (isVisible : BOOLEAN);

	(** Global thread that periodically toggles the visibility of the currently active cursor *)
	CursorBlinker* = OBJECT
	VAR
		cursor : ANY;
		callback : CursorBlinkerCallback;
		interval : LONGINT;
		isVisible : BOOLEAN;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE &Init;
		BEGIN
			cursor := NIL; callback := NIL;
			interval := 500;
			isVisible := TRUE;
			alive := TRUE; dead := FALSE;
			NEW(timer);
		END Init;

		(** Set the currently active cursor and a callback that will be periodically called *)
		PROCEDURE Set*(cursor : ANY; callback : CursorBlinkerCallback);
		BEGIN {EXCLUSIVE}
			ASSERT((cursor # NIL) & (callback # NIL));
			IF (SELF.cursor # NIL) THEN callback(TRUE); END;
			SELF.cursor := cursor;
			SELF.callback := callback;
			isVisible := TRUE;
			timer.Wakeup;
		END Set;

		(** Set the cursor blinking interval in milliseconds. An interval of MAX(LONGINT) means don't blink *)
		PROCEDURE SetInterval*(ms : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(ms > 0);
			interval := ms;
			timer.Wakeup;
			IF (interval = MAX(LONGINT)) & (cursor # NIL) THEN
				isVisible := TRUE;
				callback(isVisible);
			END;
		END SetInterval;

		(** If 'cursor' is the currently active cursor, set the currently active cursor to NIL *)
		PROCEDURE Remove*(cursor : ANY);
		BEGIN {EXCLUSIVE}
			ASSERT(cursor # NIL);
			IF (SELF.cursor = cursor) THEN
				SELF.cursor := NIL;
				SELF.callback := NIL;
			END;
		END Remove;

		(** If 'cursor' is the currently active cursor, show it for one period *)
		PROCEDURE Show*(cursor : ANY);
		BEGIN {EXCLUSIVE}
			ASSERT(cursor # NIL);
			IF (SELF.cursor = cursor) THEN
				isVisible := TRUE;
				timer.Wakeup;
			END;
		END Show;

		PROCEDURE Finalize;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Finalize;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT(~alive OR ((cursor # NIL) & (interval # MAX(LONGINT))));
				IF alive THEN
					callback(isVisible);
					isVisible := ~isVisible;
				END;
			END;
			timer.Sleep(interval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END CursorBlinker;

TYPE

	TextDropTarget* = OBJECT(WMDropTarget.DropTarget);
	VAR text : Texts.Text;
		pos : Texts.TextPosition;

		PROCEDURE &New*(text : Texts.Text; pos : Texts.TextPosition);
		BEGIN
			SELF.text := text; SELF.pos := pos
		END New;

		PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : WMDropTarget.DropText;
		BEGIN
			IF type = WMDropTarget.TypeText THEN
				NEW(di); di.text := text; di.pos := pos;
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;

	END TextDropTarget;

TYPE
	LinkWrapper* = POINTER TO RECORD
		link* : Texts.Link;
	END;

TYPE
	TextView* = OBJECT(WMComponents.VisualComponent)
	VAR
		defaultTextColor-, defaultTextBgColor- : WMProperties.ColorProperty;
		defaultTextColorI, defaultTextBgColorI : LONGINT;

		isMultiLine- : WMProperties.BooleanProperty;
		isMultiLineI : BOOLEAN;

		(** Text wrapping mode: NoWrap, Wrap or WrapWord (default : WrapWord) *)
		wrapMode- : WMProperties.Int32Property;
		wrapModeI : LONGINT;

		firstLine- : WMProperties.Int32Property;
		firstLineI : LONGINT;

		leftShift- : WMProperties.Int32Property;
		leftShiftI : LONGINT; (* number of units, the view is shifted to left -> line scrolling *)

		showBorder- : WMProperties.BooleanProperty;
		showBorderI : BOOLEAN;

		borders- : WMProperties.RectangleProperty;
		bordersI, borderClip : WMRectangles.Rectangle;
		x0 : LONGINT; (* text starts at x = x0. Used to get column for line numbers in subclass CodeView *)

		alwaysShowCursor- : WMProperties.BooleanProperty;
		alwaysShowCursorI : BOOLEAN;

		showLabels- : WMProperties.BooleanProperty;

		(** Is set to TRUE, the characters will be replaced by passwordChar *)
		isPassword- : WMProperties.BooleanProperty;
		isPasswordI : BOOLEAN; (* cache of the property value to avoid per-character-locks *)

		passwordChar- : WMProperties.Int32Property; (* not cached *)

		(** Mouse wheel scrolling speed multiplier? (default: 3, 0: disable mouse wheel scrolling) *)
		mouseWheelScrollSpeed- : WMProperties.Int32Property;
		mouseWheelScrollSpeedI : LONGINT;

		(** Allow middle-click command execution? (default: TRUE) *)
		allowCommandExecution- : WMProperties.BooleanProperty;

		(** Allow text selection using the mouse? (default: TRUE) *)
		allowTextSelection- : WMProperties.BooleanProperty;

		(** Should a mouse right-click open the pie menu? (default : TRUE) *)
		allowPiemenu- : WMProperties.BooleanProperty;

		(** Syntax highlighting *)
		highlighting- : WMProperties.StringProperty;
		highlighter : SyntaxHighlighter.Highlighter;
		state : SyntaxHighlighter.State;
		fontCache : FontCache;
		
		(** vertical centering -- momentarily only working for a single line *)
		textAlignV-: WMProperties.Int32Property;

		showLineNumbers- : WMProperties.BooleanProperty;
		showLineNumbersI : BOOLEAN;

		lineNumberColor-, lineNumberBgColor- : WMProperties.ColorProperty;
		lineNumberColorI, lineNumberBgColorI : LONGINT;
		lineNumberFont, lineNumberFont10 : WMGraphics.Font;

		indicateTabs- : WMProperties.BooleanProperty;
		indicateTabsI : BOOLEAN;

		clBgCurrentLine- : WMProperties.ColorProperty;
		clBgCurrentLineI : LONGINT;

		selection- : Highlight;
		cursor- : Cursor;

		onLinkClicked- : WMEvents.EventSource;
		onCtrlClicked- : WMEvents.EventSource;

		(** Commands.Context.caller will be set to this object when executing a command *)
		commandCaller*: OBJECT;
		commandWriter*, errorWriter*: Streams.Writer;

		(** Called whenever the cursor position changes *)
		onCursorChanged* : PROCEDURE {DELEGATE};

		optimize* : BOOLEAN;

		piemenu : WMPieMenu.Menu;

		text : Texts.Text;

		layout : Layout;
		utilreader : Texts.TextReader; (* single process ! *)

		clipState : WMGraphics.CanvasState;

		defaultTabStops : TabStops;
		vScrollbar : WMStandardComponents.Scrollbar;
		hScrollbar : WMStandardComponents.Scrollbar;

		(* highlighting *)
		nofHighlights : LONGINT;
		highlights : HighlightArray;

		(* marked positions *)
		nofPositionMarkers : LONGINT;
		positionMarkers : PositionMarkerArray;

		lastCursorPos: LONGINT;
		selecting : BOOLEAN;
		doubleclickedWord : BOOLEAN;

		dragPossible : BOOLEAN;
		dragSelA, dragSelB : Texts.TextPosition;
		dragCopy : BOOLEAN;

		canStart, openFile : BOOLEAN; (* set for command selection mode *)
		commandMarker : Highlight;

		downX, downY : LONGINT;
		selectWords : BOOLEAN;
		wordSelOrdered : BOOLEAN;
		lineEnter : LONGINT;
		modifierFlags : SET;
		oldFlags : SET;	(* old pointer flags *)
		interclick : LONGINT;

		lastTimeStamp : LONGINT;

		oldObject, focusObject : ANY;
		oldPos, focusPos : LONGINT;
		objHasFocus : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMTextView.GenTextView");
			SetNameAsString(StrTextView);
			(* properties *)
			NEW(defaultTextColor, PTVdefaultTextColor, NIL, NIL); properties.Add(defaultTextColor);
			NEW(defaultTextBgColor, PTVdefaultTextBgColor, NIL, NIL); properties.Add(defaultTextBgColor);
			NEW(isMultiLine, PTVIsMultiLine, NIL, NIL); properties.Add(isMultiLine);
			NEW(wrapMode, PTVWrapMode, NIL, NIL); properties.Add(wrapMode);
			NEW(firstLine, PTVfirstLine, NIL, NIL); properties.Add(firstLine);
			NEW(leftShift, PTVleftShift, NIL, NIL); properties.Add(leftShift);
			NEW(showBorder, PTVShowBorder, NIL, NIL); properties.Add(showBorder);
			NEW(borders, PTVborders, NIL, NIL); properties.Add(borders);
			NEW(alwaysShowCursor, PTValwaysShowCursor, NIL, NIL); properties.Add(alwaysShowCursor);
			NEW(showLabels, PTVShowLabels, NIL, NIL); properties.Add(showLabels);
			NEW(isPassword, PTVIsPassword, NIL, NIL); properties.Add(isPassword);
			NEW(passwordChar, PTVPasswordChar, NIL, NIL); properties.Add(passwordChar);
			NEW(mouseWheelScrollSpeed, PTVMouseWheelScrollSpeed, NIL, NIL); properties.Add(mouseWheelScrollSpeed);
			NEW(allowCommandExecution, PTVAllowCommandExecution, NIL, NIL); properties.Add(allowCommandExecution);
			NEW(allowTextSelection, PTVAllowTextSelection, NIL, NIL); properties.Add(allowTextSelection);
			NEW(allowPiemenu, PTVAllowPiemenu, NIL, NIL); properties.Add(allowPiemenu);
			NEW(highlighting, PTVHighlighting, NIL, NIL); properties.Add(highlighting);
			highlighter := NIL; state := NIL; fontCache := NIL;
			NEW(showLineNumbers, PTVShowLineNumbers, NIL, NIL); properties.Add(showLineNumbers);
			NEW(lineNumberColor, PTVLineNumberColor, NIL, NIL); properties.Add(lineNumberColor);
			NEW(lineNumberBgColor, PTVLineNumberBgColor, NIL, NIL); properties.Add(lineNumberBgColor);
			lineNumberFont := NIL; lineNumberFont10 := NIL;
			NEW(indicateTabs, PTVIndicateTabs, NIL, NIL); properties.Add(indicateTabs);
			NEW(clBgCurrentLine, PTVclBgCurrentLine, NIL, NIL); properties.Add(clBgCurrentLine);
			NEW(textAlignV, PVTtextAlignV, NIL, NIL); properties.Add(textAlignV);

			(* events *)
			NEW(onLinkClicked, SELF, PTVonLinkClick, PTVonLinkClickInfo, SELF.StringToCompCommand); events.Add(onLinkClicked);
			onLinkClicked.Add(LinkClicked);
			NEW(onCtrlClicked, SELF, PTVonCtrlLinkClick, PTVonCtrlLinkClickInfo, SELF.StringToCompCommand); events.Add(onCtrlClicked);

			(* selection and cursor *)
			NEW(layout);
			layout.layoutLineProc := LayoutLine;
			nofHighlights := 0;
			NEW(highlights, 4);
			nofPositionMarkers := 0;
			NEW(positionMarkers, 4); nofPositionMarkers := 0;
			selection := CreateHighlight();
			selection.kind := HLOver;
			selection.color := SelectionColor;
			cursor := CreateCursor();
			commandCaller := NIL;
			commandWriter := NIL;
			onCursorChanged := NIL;
			(* Initialization of internal fields *)
			optimize := FALSE;
			piemenu := NIL;
			text := NIL;
			utilreader := NIL;
			NEW(defaultTabStops); defaultTabStops.tabDist := 20;
			vScrollbar := NIL; hScrollbar := NIL;
			lastCursorPos := -1;
			selecting := FALSE;
			doubleclickedWord := FALSE;
			dragPossible := FALSE;
			dragSelA := NIL; dragSelB := NIL;
			canStart := FALSE; openFile := FALSE;
			downX := 0; downY := 0;
			selectWords := FALSE;
			wordSelOrdered := FALSE;
			lineEnter := 0;
			modifierFlags := {}; oldFlags := {};
			interclick := InterclickNone;
			lastTimeStamp := 0;
			oldObject := NIL; focusObject := NIL;
			oldPos := 0; focusPos := 0;
			objHasFocus := FALSE;

			takesFocus.Set(TRUE);
			needsTab.Set(TRUE);
			SetPointerInfo(manager.pointerText);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			ASSERT(IsCallFromSequencer());
			Initialize^;
			RecacheProperties;
			cursor.SetVisible(FALSE);
			IF text#NIL THEN	Resized 	END;

			(* from now on, bidi-formatting can be done *)
			layout.initialized := TRUE;
			(*Initialize^;*)
		END Initialize;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF text # NIL THEN text.onTextChanged.Remove(TextChanged); END;
			cursorBlinker.Remove(cursor);
		END Finalize;

		PROCEDURE FocusReceived*;
		BEGIN
			FocusReceived^;
			cursor.SetVisible(TRUE);
			cursorBlinker.Set(cursor, cursor.SetCurrentVisibility);

			(* let the module know that this is the currently visible TextView *)
			currentTextView := SELF;
		END FocusReceived;

		PROCEDURE FocusLost*;
		BEGIN
			FocusLost^;
			modifierFlags := {};
			cursorBlinker.Remove(cursor);
			SetInterclick(InterclickNone);
			IF ~alwaysShowCursorI THEN cursor.SetVisible(FALSE); END;
		END FocusLost;

		(* Inserts a character directly into the text. This should be used by external tools that insert character
			without the usage of the keyboard, e.g. WMUnicodeMarkerTool) *)
		PROCEDURE InsertChar(char : Char32) : INTEGER;
		VAR oneCharString : ARRAY 2 OF Texts.Char32;
		BEGIN
			(* Only insert a character into a valid text, that is either utf-formatted or gets a simple ASCII-character
				as input. *)
			IF text # NIL THEN
				IF text.isUTF OR (char < 256) THEN
					oneCharString[0] := char;
					oneCharString[1] := 0H;
					text.AcquireWrite;
					text.InsertUCS32(GetInternalPos(cursor.GetPosition()),oneCharString);
					text.ReleaseWrite;
					RETURN 0;
				ELSE
					RETURN -1;
				END;
			ELSE
				RETURN -2;
			END;
		END InsertChar;

		PROCEDURE RecacheProperties;
		VAR
			highlighter : SyntaxHighlighter.Highlighter;
			oldBorders : WMRectangles.Rectangle;
			string : Strings.String;
		BEGIN
			ASSERT(IsCallFromSequencer());
			RecacheProperties^;
			defaultTextColorI := defaultTextColor.Get();
			defaultTextBgColorI := defaultTextBgColor.Get();
			isMultiLineI := isMultiLine.Get();
			wrapModeI := wrapMode.Get();
			firstLineI := firstLine.Get();
			leftShiftI := leftShift.Get();
			showBorderI := showBorder.Get();
			oldBorders := bordersI;
			bordersI := borders.Get();
			alwaysShowCursorI := alwaysShowCursor.Get();
			mouseWheelScrollSpeedI := mouseWheelScrollSpeed.Get();
			isPasswordI := isPassword.Get();
			showLineNumbersI := showLineNumbers.Get();
			ShowLineNumbers(showLineNumbersI);
			lineNumberColorI := lineNumberColor.Get();
			lineNumberBgColorI := lineNumberBgColor.Get();
			indicateTabsI := indicateTabs.Get();
			clBgCurrentLineI := clBgCurrentLine.Get();
			string := highlighting.Get();
			
			IF (string # NIL) THEN
				highlighter := SyntaxHighlighter.GetHighlighter(string^);
			ELSE
				highlighter := NIL;
			END;
			IF text#NIL THEN 
				SetSyntaxHighlighter(highlighter);
				UpdateScrollbars;
				IF ~WMRectangles.IsEqual(oldBorders, bordersI) THEN BordersChanged END;
			END;
			(*Invalidate;*)
		END RecacheProperties;

		PROCEDURE SetScrollbars*(hScrollbar, vScrollbar : WMStandardComponents.Scrollbar);
		BEGIN
			Acquire;
			IF hScrollbar # NIL THEN hScrollbar.onPositionChanged.Remove(ScrollbarsChanged) END;
			IF vScrollbar # NIL THEN vScrollbar.onPositionChanged.Remove(ScrollbarsChanged) END;
			SELF.hScrollbar := hScrollbar; SELF.vScrollbar := vScrollbar;
			IF hScrollbar # NIL THEN hScrollbar.onPositionChanged.Add(ScrollbarsChanged) END;
			IF vScrollbar # NIL THEN vScrollbar.onPositionChanged.Add(ScrollbarsChanged) END;
			UpdateScrollbars;
			Release
		END SetScrollbars;

		PROCEDURE ScrollbarsChanged(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.ScrollbarsChanged, sender, data)
			ELSE
				IF sender = vScrollbar THEN firstLine.Set(vScrollbar.pos.Get())
				ELSIF sender = hScrollbar THEN leftShift.Set(hScrollbar.pos.Get())
				END
			END
		END ScrollbarsChanged;

		PROCEDURE UpdateScrollbars;
		BEGIN
			IF vScrollbar # NIL THEN
				vScrollbar.max.Set(layout.GetNofLines());
				vScrollbar.pos.Set(firstLineI);
			END;
			IF hScrollbar # NIL THEN
				IF (wrapModeI # NoWrap) THEN
					hScrollbar.visible.Set(FALSE);
				ELSE
					hScrollbar.visible.Set(TRUE);
				(*	hScrollbar.visible.Set(layout.textWidth > bounds.GetWidth()); *)
					hScrollbar.max.Set(layout.textWidth);
					hScrollbar.pageSize.Set(bounds.GetWidth());
					hScrollbar.pos.Set(leftShiftI);
				END;
			END;
		END UpdateScrollbars;

		PROCEDURE BordersChanged;
		VAR vScroll : LONGINT;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (vScrollbar # NIL) & (vScrollbar.visible.Get()) THEN vScroll := vScrollbar.bounds.GetWidth() ELSE vScroll := 0 END;
			borderClip := WMRectangles.MakeRect(bordersI.l, bordersI.t, bounds.GetWidth() - bordersI.r, bounds.GetHeight() - bordersI.b);
			layout.paperWidth := bounds.GetWidth() - (bordersI.l + bordersI.r) - vScroll;
			layout.FullLayout(FALSE); CheckNumberOfLines;
		END BordersChanged;

		PROCEDURE WrapModeChanged;
		BEGIN
			ASSERT(IsCallFromSequencer());
			wrapModeI := wrapMode.Get();
			IF (wrapModeI # NoWrap) THEN
				leftShift.Set(0); leftShiftI := 0; (* no scrollbars -> don't shift *)
			END;
			optimize := TRUE;
			Resized;
			optimize := FALSE;
			UpdateScrollbars;
			(*Invalidate;*)
		END WrapModeChanged;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR
			highlighter : SyntaxHighlighter.Highlighter;
			oldBorders : WMRectangles.Rectangle;
			string : Strings.String;
		BEGIN
			IF property = defaultTextColor THEN
				defaultTextColorI := defaultTextColor.Get(); Invalidate;
			ELSIF property = defaultTextBgColor THEN
				defaultTextBgColorI := defaultTextBgColor.Get(); Invalidate;
			ELSIF property = isMultiLine THEN
				isMultiLineI := isMultiLine.Get(); Invalidate;
			ELSIF property = wrapMode THEN
				wrapModeI := wrapMode.Get(); WrapModeChanged; Invalidate;
			ELSIF property = firstLine THEN
				firstLineI := firstLine.Get(); UpdateScrollbars; Invalidate;
			ELSIF property = leftShift THEN
				leftShiftI := leftShift.Get(); UpdateScrollbars; Invalidate;
			ELSIF property = showBorder THEN
				showBorderI := showBorder.Get(); Invalidate;
			ELSIF property = borders THEN
				oldBorders := bordersI; bordersI := borders.Get(); BordersChanged; Invalidate;
			ELSIF property = alwaysShowCursor THEN
				alwaysShowCursorI := alwaysShowCursor.Get();
				IF (alwaysShowCursorI = TRUE) THEN cursor.SetVisible(TRUE);
				ELSIF ~hasFocus THEN cursor.SetVisible(FALSE);
				END;
				Invalidate;
			ELSIF property = mouseWheelScrollSpeed THEN
				mouseWheelScrollSpeedI := mouseWheelScrollSpeed.Get();
			ELSIF property = isPassword THEN
				isPasswordI := isPassword.Get(); Invalidate;
			ELSIF (property = highlighting) THEN
				string := highlighting.Get();
				IF (string # NIL) THEN
					highlighter := SyntaxHighlighter.GetHighlighter(string^);
				ELSE
					highlighter := NIL;
				END;
				SetSyntaxHighlighter(highlighter);
			ELSIF (property = showLineNumbers) THEN
				showLineNumbersI := showLineNumbers.Get();
				ShowLineNumbers(showLineNumbersI);
				Invalidate;
			ELSIF (property = indicateTabs) THEN
				indicateTabsI := indicateTabs.Get(); Invalidate;
			ELSIF (property = clBgCurrentLine) THEN
				clBgCurrentLineI := clBgCurrentLine.Get(); Invalidate;
			ELSIF (property = textAlignV) THEN
				Invalidate;
			ELSIF (property = lineNumberColor) OR (property = lineNumberBgColor) THEN
				lineNumberColorI := lineNumberColor.Get();
				lineNumberBgColorI := lineNumberBgColor.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property)
			END
		END PropertyChanged;

		PROCEDURE Resized;
		BEGIN
			ASSERT(IsCallFromSequencer());
			Resized^;
			layout.paperWidth := bounds.GetWidth() - (bordersI.l + bordersI.r);
			borderClip.r := bounds.GetWidth() - bordersI.r; borderClip.b := bounds.GetHeight() - bordersI.b;
			layout.FullLayout(optimize);
			CheckNumberOfLines;
		END Resized;

		(** Replace the text *)
		PROCEDURE SetText*(text : Texts.Text);
		VAR i : LONGINT;
		BEGIN
			ASSERT(text # NIL);
			Acquire;
			IF SELF.text # NIL THEN SELF.text.onTextChanged.Remove(TextChanged) END; (* unregister the TextChanged listener from the old text *)
			SELF.text := text;
			text.onTextChanged.Add(TextChanged); (* register the TextChanged listener with the new text*)
			NEW(utilreader, text);
			(* update all highlights *)
			FOR i := 0 TO nofHighlights - 1 DO highlights[i].SetText(text) END;
			FOR i := 0 TO nofPositionMarkers - 1 DO
				positionMarkers[i].SetText(text);
				(* Let the cursor know about the local position-translation procedures *)
				IF text.isUTF THEN
					positionMarkers[i].pos.SetInternalPositionTranslator(GetInternalPos);
					positionMarkers[i].pos.SetDisplayPositionTranslator(GetDisplayPos);
				END;
			END;
			text.AcquireRead; (* also protect SELF.highlighter and SELF.state here *)
			IF (highlighter # NIL) THEN
				ASSERT(state # NIL);
				highlighter.RebuildRegions(utilreader, state);
			END;
			layout.SetText(text);
			layout.FullLayout(TRUE);
			CheckNumberOfLines;
			ASSERT(((highlighter = NIL) & (state = NIL)) OR ((highlighter # NIL) & (state # NIL)));
			text.ReleaseRead;
			Invalidate;(*! Redundant ?*)
			Release;
		END SetText;

		PROCEDURE SetSyntaxHighlighter*(highlighter : SyntaxHighlighter.Highlighter);
		BEGIN
			ASSERT(text # NIL);
			Acquire;
			IF (SELF.highlighter # highlighter) & ((SELF.highlighter # NIL) OR (highlighter # NIL)) THEN
				text.AcquireRead; (* also protect SELF.highlighter and SELF.state here *)
				SELF.highlighter := highlighter;
				IF (highlighter # NIL) THEN
					IF (state = NIL) THEN
						state := highlighter.GetState();
						ASSERT(state # NIL);
					END;
					highlighter.RebuildRegions(utilreader, state);
				ELSE
					state := NIL;
				END;
				layout.FullLayout(TRUE);
				CheckNumberOfLines;
				ASSERT(((highlighter = NIL) & (state = NIL)) OR ((highlighter # NIL) & (state # NIL)));
				text.ReleaseRead;
				Invalidate;
			END;
			Release;
		END SetSyntaxHighlighter;

		PROCEDURE ShowLineNumbers(enabled : BOOLEAN);
		VAR font : WMGraphics.Font;
		BEGIN
			font := GetFont( );
			IF enabled THEN
				x0 := 55;
				lineNumberFont := WMGraphics.GetFont(font.name, font.size, {});
				lineNumberFont10 := WMGraphics.GetFont(font.name, font.size, {WMGraphics.FontBold});
			ELSE
				x0 := 0;
				lineNumberFont := NIL;
				lineNumberFont10 := NIL;
			END;
		END ShowLineNumbers;

		PROCEDURE SetTabStops*(ts : TabStops);
		BEGIN
			Acquire;
			defaultTabStops := ts;
			layout.FullLayout(TRUE);
			CheckNumberOfLines;
			Release;
		END SetTabStops;

(* BEGIN highlighting *)
		PROCEDURE AddHighlight(highlight : Highlight);
		VAR newHighlights : HighlightArray; i : LONGINT;
		BEGIN
			INC(nofHighlights);
			IF nofHighlights > LEN(highlights) THEN
				NEW(newHighlights, LEN(highlights) * 2);
				FOR i := 0 TO LEN(highlights) - 1 DO newHighlights[i] := highlights[i] END;
				highlights := newHighlights;
			END;
			highlights[nofHighlights - 1] := highlight;
			HighlightChanged(highlight, NIL);
		END AddHighlight;

		PROCEDURE CreateHighlight*() : Highlight;
		VAR h : Highlight;
		BEGIN
			Acquire;
			NEW(h); h.SetText(text);
			h.onChanged := HighlightChanged;
			AddHighlight(h);
			Release;
			RETURN h
		END CreateHighlight;

		PROCEDURE RemoveHighlight*(x : Highlight);
		VAR i : LONGINT;
		BEGIN
			Acquire;
			i := 0; WHILE (i < nofHighlights) & (highlights[i] # x) DO INC(i) END;
			IF i < nofHighlights THEN
				WHILE (i < nofHighlights - 1) DO highlights[i] := highlights[i+1]; INC(i) END;
				DEC(nofHighlights);
				highlights[nofHighlights] := NIL
			END;
			HighlightChanged(NIL, NIL);
			Release
		END RemoveHighlight;

		PROCEDURE InvalidateRange(a, b : LONGINT);
		VAR
			t, l0, l1 : LONGINT;
			x0, y0, x1, y1, d : LONGINT;
			ia, ib : LONGINT;
		BEGIN
			ia := GetDisplayPos(a);
			ib := GetDisplayPos(b);

			(* Sort the display positions, not the internal positions so as not to get weird results! *)
			IF ia > ib THEN t := ia; ia := ib; ib := t END;

			l0 := layout.FindLineNrByPos(ia);
			l1 := layout.FindLineNrByPos(ib);
			IF l0 = l1 THEN (* only one line... optimize *)
				LineYPos(l0, y0, y1);
				(* if text is UTF-formatted (and thus might content RTL-text) the whole line is invalidated.
					this might - in some rare cases - be a bit slower than invalidating the minimum rectangle
					but is guaranteed to always be correct. *)
				IF text.isUTF OR (~(FindScreenPos(ia, x0, d) & FindScreenPos(ib, x1, d))) THEN
					x0 := 0; x1 := bounds.GetWidth();
				END;
				InvalidateRect(WMRectangles.MakeRect(x0, y0, x1, y1));
			ELSE
				LineYPos(l0, y0, d); LineYPos(l1, d, y1);
				InvalidateRect(WMRectangles.MakeRect(0, y0, bounds.GetWidth(), y1));
			END;
			IF TraceInvalidate IN Trace THEN KernelLog.String("ir ") END;
		END InvalidateRange;

		PROCEDURE HighlightChanged(sender, data : ANY);
		VAR hl : Highlight; min, max : LONGINT;
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.HighlightChanged, sender, data)
			ELSE
				text.AcquireRead;
				IF (sender # NIL) & (sender IS Highlight) THEN
					hl := sender(Highlight);
					IF ((hl.oldFrom # hl.from.GetPosition()) & (hl.oldTo # hl.to.GetPosition())) OR (hl.oldColor # hl.color) THEN (* both changed *)
						min := Strings.Min(
										Strings.Min(hl.oldFrom, hl.from.GetPosition()),
										Strings.Min(hl.oldTo, hl.to.GetPosition()));
						max := Strings.Max(
										Strings.Max(hl.oldFrom, hl.from.GetPosition()),
										Strings.Max(hl.oldTo, hl.to.GetPosition()));
						InvalidateRange(min, max)
					ELSIF hl.oldTo # hl.to.GetPosition() THEN (* to changed *)
						InvalidateRange(hl.oldTo, hl.to.GetPosition())
					ELSIF hl.oldFrom # hl.from.GetPosition() THEN (* from changed *)
						InvalidateRange(hl.oldFrom, hl.from.GetPosition())
					ELSE (* position noch changed... probably color, style or visibility changed, invalidate range *)
						InvalidateRange(hl.from.GetPosition(),hl.to.GetPosition())
					END
				ELSE
					IF TraceInvalidate IN Trace THEN KernelLog.String("H") END;
					Invalidate
				END;
				text.ReleaseRead
			END
		END HighlightChanged;
(* END highlighting *)

(* BEGIN PositionMarkers *)
		PROCEDURE AddPositionMarker(pm : PositionMarker);
		VAR newPositionMarkers : PositionMarkerArray; i : LONGINT;
		BEGIN
			INC(nofPositionMarkers);
			IF nofPositionMarkers > LEN(positionMarkers) THEN
				NEW(newPositionMarkers, LEN(positionMarkers) * 2);
				FOR i := 0 TO LEN(positionMarkers) - 1 DO newPositionMarkers[i] := positionMarkers[i] END;
				positionMarkers := newPositionMarkers
			END;
			positionMarkers[nofPositionMarkers - 1] := pm
		END AddPositionMarker;

		PROCEDURE CreatePositionMarker*() : PositionMarker;
		VAR p : PositionMarker;
		BEGIN
			Acquire;
			NEW(p); p.SetText(text);
			p.onChanged := PositionMarkerChanged;
			AddPositionMarker(p);
			Release;
			RETURN p
		END CreatePositionMarker;

		PROCEDURE CreateCursor*() : Cursor;
		VAR p : Cursor;
		BEGIN
			Acquire;
			NEW(p); p.SetText(text);
			p.onChanged := PositionMarkerChanged;
			AddPositionMarker(p);
			Release;
			RETURN p
		END CreateCursor;

		PROCEDURE RemovePositionMarker*(x : PositionMarker);
		VAR i, xp, yp, l, ascent : LONGINT; newRect : WMRectangles.Rectangle;
		BEGIN
			Acquire;
			i := 0; WHILE (i < nofPositionMarkers) & (positionMarkers[i] # x) DO INC(i) END;
			IF i < nofPositionMarkers THEN
				WHILE (i < nofPositionMarkers - 1) DO positionMarkers[i] := positionMarkers[i+1]; INC(i) END;
				DEC(nofPositionMarkers);
				positionMarkers[nofPositionMarkers] := NIL
			END;
			IF FindScreenPos(x.pos.GetPosition(), xp, yp) THEN
				l := layout.FindLineNrByPos(x.pos.GetPosition());
				IF (l < LEN(layout.lines^)) & (l >= 0) THEN
					ascent := layout.lines[l].ascent;
(*					IF ascent = 0 THEN ascent := layout.lines[l].height END;
					IF ascent = 0 THEN ascent := 10 END; *)

					newRect := x.GetArea(xp, yp, ascent);
					InvalidateRect(newRect)
				END
			END;
			Release
		END RemovePositionMarker;

		PROCEDURE PositionMarkerChanged(sender, data : ANY);
		VAR newRect, combinedRect : WMRectangles.Rectangle; x, y, l, ascent : LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PositionMarkerChanged, sender, data)
			ELSE
				data := sender;
				IF (data # NIL) & (data IS PositionMarker) THEN
					text.AcquireRead;
					IF data = cursor THEN CheckCursor; END;
					IF (data = cursor) & (clBgCurrentLineI # 0) THEN
						Invalidate; (* HACK to handle clBgCurrentLine correcty. Should be replaced by a more efficient solution *)
					ELSE
						IF FindScreenPos(data(PositionMarker).pos.GetPosition(), x, y) THEN
							l := layout.FindLineNrByPos(data(PositionMarker).pos.GetPosition());
							IF (l < LEN(layout.lines^)) & (l >= 0) THEN
								ascent := layout.lines[l].ascent;
	(*							IF ascent = 0 THEN ascent := layout.lines[l].height END;
								IF ascent = 0 THEN ascent := 10 END;*)
								newRect := data(PositionMarker).GetArea(x, y, ascent)
							END
						END;

						combinedRect := data(PositionMarker).currentArea;
						IF WMRectangles.RectEmpty(combinedRect) THEN combinedRect := newRect
						ELSE WMRectangles.ExtendRect(combinedRect, newRect)
						END;
						IF ~WMRectangles.RectEmpty(combinedRect) THEN
							IF (WMRectangles.Area(data(PositionMarker).currentArea) + WMRectangles.Area(newRect)) * 5 <  WMRectangles.Area(combinedRect) THEN
								InvalidateRect(data(PositionMarker).currentArea);
								InvalidateRect(newRect)
							ELSE
								InvalidateRect(combinedRect)
							END
						END;
					END;
					text.ReleaseRead;
				ELSE
					Invalidate;
				END;
			END
		END PositionMarkerChanged;
(* END PositionMarkers *)

		PROCEDURE CheckNumberOfLines;
		BEGIN
			UpdateScrollbars;
			firstLine.SetBounds(0, layout.GetNofLines() - 1)
		END CheckNumberOfLines;

		PROCEDURE CheckCursor;
		VAR
			cp, l, i : LONGINT;
			ty : LONGINT;
			lineStartPosition, lineLength: LONGINT;
			li: LineInfo;
			dummyCh : Char32;
			x, dummyY, xend, paperWidth, newShift: LONGINT;
			dummyBool : BOOLEAN;
		BEGIN
			ASSERT(IsCallFromSequencer() & text.HasReadLock());
			(* Scroll up, down to make cursor visible *)
			cp := cursor.GetPosition();
			IF cp = lastCursorPos THEN
				RETURN
			ELSE
				lastCursorPos := cp
			END;

			IF (cp < 0) THEN
				cursor.SetPosition(GetDisplayPos(0));
			ELSIF (cp > text.GetLength()) THEN
				cursor.SetPosition(text.GetLength());
			END;
			l := layout.FindLineNrByPos(cursor.GetPosition());
			IF (l < firstLineI) THEN
				(* move the cursor down by 3 lines to get more context *)
				l := Strings.Max(0, l - 3);
				firstLine.Set(l);
			ELSIF (l < layout.GetNofLines()) THEN
				ty := bordersI.t; i := firstLineI;
				WHILE i < l DO
					ty := ty + layout.lines[i].height;
					CheckParagraphBegin(i, ty);
					CheckParagraphEnd(i, ty);
					INC(i);
				END;
				ty := ty + layout.lines[i].height;
				IF ty >= bounds.GetHeight() - bordersI.b THEN
					l := Strings.Max(0, l - 3);
					firstLine.Set(l)
				END
			END;

			(* fof071127: Scroll left right to make cursor visible *)
			lineStartPosition := layout.GetLineStartPos(l);
			lineLength := layout.GetLineLength(l);

			(* compute x position of the cursor on the line *)
			IF optimize OR ~text.isUTF THEN
				LayoutLine(lineStartPosition,dummyCh,li,layout.paperWidth,cp,-1);
				x := li.width + GetLineLeftIndent(l);
			ELSE
				dummyBool := FindScreenPos(cp,x,dummyY);
				IF x < 0 THEN
					x := 0;
				END;
				INC(x,GetLineLeftIndent(l));
			END;

			(* compute x position of the end of the cursor's line *)
			lineStartPosition := layout.GetLineStartPos(l);
			lineLength := layout.GetLineLength(l);
			LayoutLine(lineStartPosition, dummyCh, li, layout.paperWidth, lineStartPosition+lineLength-1, -1);
			xend := li.width + GetLineLeftIndent(l);

			newShift := leftShiftI;

			(* align shift such that the cursor is visible *)
			paperWidth := layout.paperWidth - bordersI.l - x0;

			IF paperWidth > 0 THEN
				IF x-leftShiftI  > paperWidth  THEN (* cursor right of displayed area *)
					newShift := x-paperWidth; (* move content such that cursor is barely visible to the right *)
				ELSIF x-leftShiftI  < 0  THEN (* cursor is left of displayed area *)
					newShift := x;  (* move content such that cursor is barely visible to the left *)
				END;

				(* now check some possibly more optimal ways of displaying *)
				IF xend-newShift < paperWidth THEN
					(* line can be shown more fully to the left, we don't want to waste space to the right *)
					newShift := xend-paperWidth;
					IF newShift < 0 THEN newShift := 0 END;
				END;
				(* do the shift *)
				IF newShift # leftShiftI THEN
					leftShift.Set(newShift);
				END;
			END;
		END CheckCursor;

		PROCEDURE CheckParagraphBegin(lineNr : LONGINT; VAR height: LONGINT);
		BEGIN
			IF layout.lines[lineNr].firstInParagraph THEN height := height + layout.lines[lineNr].spaceBefore END
		END CheckParagraphBegin;

		PROCEDURE CheckParagraphEnd(lineNr : LONGINT; VAR height: LONGINT);
		BEGIN
			IF layout.lines[lineNr].lastInParagraph THEN height := height + layout.lines[lineNr].spaceAfter; END;
		END CheckParagraphEnd;

		PROCEDURE TextChanged(sender, data : ANY);
		VAR
			f, l, t, b, i, p, pa, pb, h: LONGINT; linesChanged, fullLayout : BOOLEAN;
			info : Texts.TextChangeInfo;
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.TextChanged, sender, data)
			ELSE
				IF (data # NIL) & (data IS Texts.TextChangeInfo) & (data(Texts.TextChangeInfo).op # Texts.OpMulti) THEN
					text.AcquireRead;
					info := data(Texts.TextChangeInfo);
					IF text.GetTimestamp() = info.timestamp THEN
						info := data(Texts.TextChangeInfo);

						IF (highlighter # NIL) THEN

							ASSERT(state # NIL);
							fullLayout := FALSE;
							IF ((info.op = Texts.OpInsert) OR (info.op = Texts.OpDelete)) THEN
								highlighter.PatchRegions(info, utilreader, state, fullLayout);
							ELSIF (info.op = Texts.OpAttributes) THEN
								(* do nothing here *)
							ELSE
								highlighter.RebuildRegions(utilreader, state);
								fullLayout := TRUE;
							END;

							IF fullLayout THEN
								layout.FullLayout(TRUE);
								lastTimeStamp := text.GetTimestamp();
								CheckCursor;
								CheckNumberOfLines;
								text.ReleaseRead;
								InvalidateRect(GetClientRect());
								cursorBlinker.Show(cursor);
								RETURN;
							END;
						END;

						(* Upon an insertion or deletion in the text, parts of the text may need reformatting *)
						IF info.op = Texts.OpInsert THEN
							(* If necessary, reformat the affected text *)
							IF layout.initialized & text.isUTF & (layout.bidiFormatter # NIL) THEN
								layout.bidiFormatter.ReformatTextFrom(info.pos,info.len);
							END;
							layout.FixLayoutFrom(info.pos, info.len, f, l, linesChanged);
						ELSE
							(* If necessary, reformat the affected text *)
							IF layout.initialized & text.isUTF & (layout.bidiFormatter # NIL) THEN
								layout.bidiFormatter.ReformatTextFrom(info.pos,-info.len)
							END;
							layout.FixLayoutFrom(info.pos, -info.len, f, l, linesChanged);
						END;

						t := bordersI.t;
						FOR i := firstLineI TO f - 1 DO
							t := t + (layout.lines[i].height);
							CheckParagraphBegin(i, t);
							CheckParagraphEnd(i, t);
						END;

						h := bounds.GetHeight();
						IF linesChanged THEN b := h ELSE
							b := t; i := f;
							WHILE (i <= l) & (b < h) DO
								b := b + (layout.lines[i].height);
								CheckParagraphBegin(i, b);
								CheckParagraphEnd(i, b);
								INC(i);
							END
						END;

						pa := layout.lines[f].pos;
						IF l + 1 < layout.nofLines THEN pb := layout.lines[l + 1].pos ELSE pb := text.GetLength() END;
						FOR i := 0 TO nofPositionMarkers - 1 DO
							p := positionMarkers[i].pos.GetPosition();
							IF (p >= pa) & (p < pb) THEN
								(* very conservative *)
								h := positionMarkers[i].currentArea.b - positionMarkers[i].currentArea.t;
								t := t - h;
								b := b + h
							END
						END;
						CheckCursor;

						UpdateScrollbars;
						InvalidateRect(WMRectangles.MakeRect(0, t, bounds.GetWidth(), b));
					ELSIF (lastTimeStamp -  info.timestamp) > 0 THEN
						(* Don't update lastTimeStamp since we didn't update the layout *)
					ELSE
						IF (highlighter # NIL) THEN
							ASSERT(state # NIL);
							highlighter.RebuildRegions(utilreader, state);
						END;
						layout.FullLayout(TRUE);
						lastTimeStamp := text.GetTimestamp();
						CheckCursor;
						InvalidateRect(GetClientRect())
					END;
					CheckNumberOfLines;
					text.ReleaseRead
				ELSE
					text.AcquireRead;
					IF (highlighter # NIL) THEN
						ASSERT(state # NIL);
						highlighter.RebuildRegions(utilreader, state);
					END;
					layout.FullLayout(TRUE);
					lastTimeStamp := text.GetTimestamp();
					CheckCursor;
					CheckNumberOfLines;
					text.ReleaseRead;
					InvalidateRect(GetClientRect())
				END;
				cursorBlinker.Show(cursor);
			END;
		END TextChanged;

(* BEGIN view dependant layout functions *)
		(** Return the left indent of a line - depending on alignment *)
		(* returns left border, in case of errors *)
		PROCEDURE GetLineLeftIndent(linenr : LONGINT): LONGINT;
		VAR indent : LONGINT;
		BEGIN
			IF (linenr < 0) OR (linenr >= layout.nofLines) THEN RETURN 0 END;
			IF layout.lines[linenr].firstInParagraph THEN indent := layout.lines[linenr].firstIndent ELSE indent := layout.lines[linenr].leftIndent END;
			CASE layout.lines[linenr].align OF
				AlignLeft : RETURN indent;
				|AlignCenter : RETURN ((layout.paperWidth - (layout.lines[linenr].width)) DIV 2 - indent DIV 2);
				|AlignRight : RETURN (layout.paperWidth - layout.lines[linenr].width - layout.lines[linenr].rightIndent);
			ELSE
				 RETURN 0;
			END;
		END GetLineLeftIndent;

		(** Find the line number that currently contains the y value (y relative to 0 in component)*)
		PROCEDURE FindLineByY*(firstLine, y : LONGINT) : LONGINT;
		VAR i : LONGINT; ypos : LONGINT;
		BEGIN
			ASSERT(text.HasReadLock());
			ypos := bordersI.t; i := firstLine;
			IF y < 0 THEN RETURN 0 END;
			WHILE (i < layout.nofLines) & (ypos <= y) DO
				ypos := ypos + layout.lines[i].height;
				CheckParagraphBegin(i, ypos);
				CheckParagraphEnd(i, ypos);
				INC(i);
			END;
			RETURN Strings.Max(i -1, 0)
		END FindLineByY;

		PROCEDURE ViewToTextPos*(x, y: LONGINT; VAR pos : LONGINT);
		VAR
			l : LONGINT;
			dummy : LineInfo;
			dummyCh : Char32;
			indent : LONGINT;
		BEGIN
			text.AcquireRead;
			pos := -1;
			x := Strings.Max(0, Strings.Min(x, bounds.GetWidth()));
			y := Strings.Max(0, Strings.Min(y, bounds.GetHeight()));

			l := FindLineByY(firstLineI, Strings.Min(Strings.Max(y, bordersI.t), bounds.GetHeight() - bordersI.b));

			x := x - bordersI.l - x0 + leftShiftI;
			IF x < 0 THEN x := 0 END;

			IF l >= 0 THEN
				dummy := layout.lines[l]; (* this line belongs in here! *)
				pos := layout.GetLineStartPos(l);
				IF dummy.firstInParagraph THEN indent := dummy.firstIndent
				ELSE indent := dummy.leftIndent END;

				IF dummy.align = 0 THEN (* Left *)
					LayoutLine(pos, dummyCh, dummy, layout.paperWidth, -1, x-indent)
				ELSIF dummy.align = 1 THEN (* Center *)
					LayoutLine(pos, dummyCh, dummy, layout.paperWidth, -1, x-((layout.paperWidth - dummy.width - indent) DIV 2))
				ELSIF dummy.align = 2 THEN (* Right *)
					LayoutLine(pos, dummyCh, dummy, layout.paperWidth, -1, x-(layout.paperWidth - dummy.width - dummy.rightIndent))
				END;

				(* Adjust the position if necessary *)
				IF IsRightToLeft(pos) THEN
					DEC(pos);
				END;
			END;
			text.ReleaseRead
		END ViewToTextPos;

		(* Returns the height for the given width *)
		PROCEDURE GetHeight*(width: LONGINT): LONGINT;
		VAR oldWidth, height : LONGINT;
		BEGIN
			oldWidth := layout.paperWidth;
			layout.paperWidth := width;
			layout.FullLayout(FALSE);
			height := layout.textHeight;

			(* reset old state *)
			layout.paperWidth := oldWidth;
			layout.FullLayout(FALSE);
			RETURN height
		END GetHeight;

		(* Returns the size of the largest word and line in pixels *)
		PROCEDURE GetMinMaxWidth*(VAR word, line : LONGINT);
		VAR dx, pos : LONGINT;
			cws, cls : LONGINT;
			f,cf : WMGraphics.Font;
			ch : Char32;
			tabstring : ARRAY 256 OF CHAR; tabs : CustomTabStops; tp : TabPositions;
			sr : Streams.StringReader; tabCounter, tabPos : LONGINT; token : ARRAY 16 OF CHAR;
			pStyle : Texts.ParagraphStyle;
			cStyle : Texts.CharacterStyle;

			PROCEDURE GetWidth(ch : Char32; VAR dx : LONGINT);
			VAR gs : WMGraphics.GlyphSpacings; vc : WMComponents.VisualComponent;
			BEGIN
				IF ch = Texts.ObjectChar THEN
					IF (utilreader.object # NIL) & (utilreader.object IS WMGraphics.Image) THEN
						dx :=  utilreader.object(WMGraphics.Image).width
					ELSIF (utilreader.object # NIL) & (utilreader.object IS WMComponents.VisualComponent) THEN
						vc := utilreader.object(WMComponents.VisualComponent);
						dx := vc.bounds.GetWidth();
					END
				ELSIF ch = Texts.TabChar THEN
					IF tabs # NIL THEN dx := tabs.GetNextTabStop(cls) - cls
					ELSE dx := defaultTabStops.GetNextTabStop(cls) - cls
					END;
				ELSE
					IF isPasswordI THEN ch := passwordChar.Get() END;
					IF f.HasChar(ch) THEN
						f.GetGlyphSpacings(ch, gs);
					ELSE
						WMGraphics.FBGetGlyphSpacings(ch, gs);
					END;
					dx := gs.bearing.l + gs.width + gs.bearing.r
				END
			END GetWidth;

		BEGIN
			cf := GetFont(); (* set the default component font *)
			f := cf;
			pos := 0; cws := 0; cls := 0; word := 0; line := 0;

			text.AcquireRead;
			utilreader.SetDirection(1); utilreader.SetPosition(pos);

			REPEAT
				utilreader.ReadCh(ch);

				(* Get the Paragraph Style *)
				IF utilreader.pstyle # NIL THEN
					pStyle := utilreader.pstyle;
					(* parse tabstops *)
					COPY(pStyle.tabStops, tabstring);
					IF (tabstring # "default") & (tabstring # "0") & (tabstring # "") THEN
						NEW(sr, LEN(tabstring)); sr.Set(tabstring); tabCounter := 0;
						WHILE (sr.res = Streams.Ok) DO
							sr.SkipWhitespace; sr.String(token);
							INC(tabCounter);
						END;
						NEW(tp, tabCounter);
						sr.Reset; tabCounter := 0;
						WHILE (sr.res = Streams.Ok) DO
							sr.SkipWhitespace; sr.String(token);
							Strings.StrToInt(token, tabPos);
							tp[tabCounter] := tabPos;
							INC(tabCounter);
						END;
						NEW(tabs, tp)
					END
				END;
				(* Get the Character Styles / Attributes *)
				IF utilreader.cstyle # NIL THEN
					cStyle := utilreader.cstyle;
					IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
						f := cStyle.fontcache(WMGraphics.Font);
					ELSE
						 f := WMGraphics.GetFont(cStyle.family, ENTIER(FP1616.FixpToFloat(cStyle.size)), cStyle.style);
						utilreader.cstyle.fontcache := f
					END;
				ELSIF utilreader.pstyle # NIL THEN
					IF pStyle.charStyle # NIL THEN
						cStyle := pStyle.charStyle;
						IF (cStyle.fontcache #NIL) &
							(cStyle.fontcache IS WMGraphics.Font) THEN
							f := cStyle.fontcache(WMGraphics.Font);
						ELSE
							 f := WMGraphics.GetFont(cStyle.family, ENTIER(FP1616.FixpToFloat(cStyle.size)), cStyle.style);
							utilreader.pstyle.charStyle.fontcache := f
						END
					END;
				ELSIF utilreader.attributes # NIL THEN
					IF utilreader.attributes.fontInfo # NIL THEN
						IF (utilreader.attributes.fontInfo.fontcache # NIL)
							& (utilreader.attributes.fontInfo.fontcache IS WMGraphics.Font) THEN
							f := utilreader.attributes.fontInfo.fontcache(WMGraphics.Font);
						ELSE
							f := GetFontFromAttr(utilreader.attributes.fontInfo);
							utilreader.attributes.fontInfo.fontcache := f
						END
					ELSE f := cf
					END
				ELSE f := cf;
				END;

				INC(pos);
				GetWidth(ch, dx);

				IF (ch = Texts.ObjectChar) THEN
					word := Strings.Max(word, dx);
					cls := cls + dx;
					cws := 0
				ELSIF (ch = Texts.NewLineChar) THEN
					line := Strings.Max(line, cls);
					cls := 0
				ELSIF (ch = 32) THEN
					word := Strings.Max(word, cws);
					cws := 0
				ELSE
					cws := cws + dx;
					cls := cls + dx;
				END;

			UNTIL utilreader.eot;
			line := Strings.Max(line, cls);
			word := Strings.Max(word, cws);
			text.ReleaseRead;

		END GetMinMaxWidth;

(* END view dependant layout functions *)

		PROCEDURE LineYPos(lineNr : LONGINT; VAR y0, y1 : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF (lineNr >= firstLineI) & (lineNr < layout.GetNofLines()) THEN
				y0 := bordersI.t; i := firstLineI;
				WHILE i < lineNr DO
					y0 := y0 + layout.lines[i].height;
					CheckParagraphBegin(i, y0);
					CheckParagraphEnd(i, y0);
					INC(i);
				END;
				y1 := y0 + layout.lines[i].height;
				CheckParagraphBegin(i, y1);
			ELSE y0 := 0; y1 := 0
			END
		END LineYPos;

		PROCEDURE FindScreenPos*(pos : LONGINT; VAR x, y : LONGINT) : BOOLEAN;
		VAR
			l, i, startPos, intPos: LONGINT;
			ty : LONGINT;
			li : LineInfo;
			thisCh, lastCh : Char32;
			lastLine : BOOLEAN;
			f : WMGraphics.Font;
			gs: WMGraphics.GlyphSpacings;
		BEGIN
			text.AcquireRead;
			lastLine := FALSE;
			IF (pos = text.GetLength()) THEN
				utilreader.SetDirection(1); utilreader.SetPosition(text.GetLength() - 1);
				utilreader.ReadCh(thisCh);
				IF thisCh = Texts.NewLineChar THEN lastLine := TRUE END
			END;

			IF lastLine THEN
				ty := bordersI.t; i := firstLineI;
				WHILE i < layout.nofLines DO
					ty := ty + layout.lines[i].height;
					CheckParagraphBegin(i, ty);
					CheckParagraphEnd(i, ty);
					INC(i);
				END;
				IF i > 0 THEN
					y := (ty + layout.lines[i - 1].ascent)
				ELSE
					f := GetFont();
					y := (ty + f.GetAscent());
				END;
				x := bordersI.l + x0 - leftShiftI;
				text.ReleaseRead;
				RETURN TRUE
			ELSIF (pos = 0) & (firstLineI = 0) THEN
				ty := bordersI.t;
				IF layout.GetNofLines() > 0 THEN
					y := (ty + layout.lines[0].ascent);
				ELSE
					f := GetFont();
					y := ty+f.GetAscent();
				END;
				CheckParagraphBegin(0, y);
				x := bordersI.l + x0 - leftShiftI;
				text.ReleaseRead;
				RETURN TRUE
			ELSE
				l := layout.FindLineNrByPos(pos);
				IF (l >= firstLineI) & (l < layout.GetNofLines()) THEN
					ty := bordersI.t; i := firstLineI;
					WHILE i < l DO
						ty := ty + layout.lines[i].height;
						CheckParagraphBegin(i, ty);
						CheckParagraphEnd(i, ty);
						INC(i);
					END;
					y := (ty + layout.lines[i].ascent);
					CheckParagraphBegin(i, y);
					startPos := layout.GetLineStartPos(i);

					f := GetFont();
					intPos := GetInternalPos(pos);
					utilreader.SetPosition(intPos-1);
					utilreader.ReadCh(lastCh);
					utilreader.ReadCh(thisCh);

					(* if this character is rtl and its predecessor is ltr, move the position to the right of the previous character *)
					IF (intPos # 0) & (IsRightToLeft(intPos) & ~IsRightToLeft(intPos-1) & (intPos # startPos)) OR
					((~IsRightToLeft(intPos) OR (thisCh = 0AH)) & ~IsRightToLeft(intPos-1) & ODD(GetParagraphEmbeddingLevel(pos))) THEN

						LayoutLine(startPos, lastCh, li, layout.paperWidth, GetDisplayPos(intPos-1), -1);
						IF f.HasChar(lastCh) THEN
							f.GetGlyphSpacings(lastCh, gs);
						ELSE
							WMGraphics.FBGetGlyphSpacings(lastCh, gs);
						END;

						x := li.width + GetLineLeftIndent(l) + bordersI.l  + x0 - leftShiftI + gs.bearing.l + gs.width + gs.bearing.r;

					ELSIF (intPos # 0) & ((thisCh = 0AH) OR (thisCh = 0H)) & IsRightToLeft(intPos-1) THEN

						LayoutLine(startPos, thisCh,  li, layout.paperWidth, GetDisplayPos(intPos-1), -1);
						x := (li.width + GetLineLeftIndent(l) + bordersI.l + x0 - leftShiftI);

					(* if this and its predecessor are rtl, move the position to the right of this character *)
					ELSIF IsRightToLeft(intPos) THEN

						LayoutLine(startPos, thisCh,  li, layout.paperWidth, pos, -1);
						IF f.HasChar(thisCh) THEN
							f.GetGlyphSpacings(thisCh, gs);
						ELSE
							WMGraphics.FBGetGlyphSpacings(thisCh, gs);
						END;

						x := li.width + GetLineLeftIndent(l) + bordersI.l + x0 - leftShiftI + gs.bearing.l + gs.width + gs.bearing.r;

					(* if this character is ltr and its predecessor is rtl move the position to the left of the predecessor *)
					ELSIF (intPos # 0) & (~IsRightToLeft(intPos) OR (thisCh = 0AH)) & IsRightToLeft(intPos-1) THEN
						LayoutLine(startPos, thisCh, li, layout.paperWidth, GetDisplayPos(intPos-1), -1);
						x := (li.width + GetLineLeftIndent(l) + bordersI.l + x0 - leftShiftI);

					(* if this and the previous character are ltr, leave the position at the left of this character *)
					ELSE

						LayoutLine(startPos, thisCh, li, layout.paperWidth, pos, -1);
						x := (li.width + GetLineLeftIndent(l) + bordersI.l + x0 - leftShiftI);
					END;

					text.ReleaseRead;
					RETURN TRUE
				ELSE
					text.ReleaseRead;
					RETURN FALSE
				END
			END
		END FindScreenPos;

		(* Get the internal position for a given display position. *)
		PROCEDURE GetInternalPos*(pos : LONGINT) : LONGINT;
		VAR
			lineNr, startPos, lineLength : LONGINT;
			dummyTextReader : Texts.TextReader;
		BEGIN
			(* if the text is non-utf formatted, the internal position and the display position are the same *)
			IF ~text.isUTF OR (layout.bidiFormatter = NIL) THEN
				RETURN pos;
			END;

			text.AcquireRead;
			lineNr := layout.FindLineNrByPos(pos);
			startPos := layout.GetLineStartPos(lineNr);
			lineLength := layout.GetLineLength(lineNr);
			dummyTextReader := layout.bidiFormatter.ReorderLine(startPos,lineLength);
			text.ReleaseRead;

			RETURN layout.bidiFormatter.GetInternalPosition(pos,startPos);
		END GetInternalPos;


		(* Get the display position for a given display position. *)
		PROCEDURE GetDisplayPos*(pos : LONGINT) : LONGINT;
		VAR
			lineNr, startPos, lineLength : LONGINT;
			dummyTextReader : Texts.TextReader;
		BEGIN

			(* if the text is non-utf formatted, the internal position and the display position are the same *)
			IF ~text.isUTF OR (layout.bidiFormatter = NIL) THEN
				RETURN pos;
			END;

			lineNr := layout.FindLineNrByPos(pos);
			startPos := layout.GetLineStartPos(lineNr);
			lineLength := layout.GetLineLength(lineNr);
			dummyTextReader := layout.bidiFormatter.ReorderLine(startPos,lineLength);

			RETURN layout.bidiFormatter.GetDisplayPosition(pos,startPos);
		END GetDisplayPos;

		(* Checks if the current position is in an rtl context *)
		PROCEDURE IsRightToLeft*(pos : LONGINT) : BOOLEAN;
		VAR
			lineNr, startPos, lineLength : LONGINT;
			dummyTextReader : Texts.TextReader;
		BEGIN
			IF ~text.isUTF OR (layout.bidiFormatter = NIL) THEN
				RETURN FALSE;
			END;

			lineNr := layout.FindLineNrByPos(pos);
			startPos := layout.GetLineStartPos(lineNr);
			lineLength := layout.GetLineLength(lineNr);

			IF layout.initialized THEN
				dummyTextReader := layout.bidiFormatter.ReorderLine(startPos,lineLength);
			END;

			RETURN ODD(layout.bidiFormatter.GetImplicitLevel(pos));
		END IsRightToLeft;

		(* Gets the paragraph embedding level of the current position's line *)
		PROCEDURE GetParagraphEmbeddingLevel*(pos : LONGINT) : LONGINT;
		BEGIN
			IF ~text.isUTF OR (layout.bidiFormatter = NIL) THEN
				RETURN 0;
			END;

			RETURN layout.bidiFormatter.GetParagraphEmbeddingLevel(pos);
		END GetParagraphEmbeddingLevel;


		PROCEDURE LayoutLine(VAR pos : LONGINT; VAR ch : Char32; VAR l : LineInfo; wrapwidth, stopPos, stopXPos : LONGINT);
		VAR
			i, wrapPos : LONGINT;
			eol, first : BOOLEAN;
			ascent, descent, leading, ld, a, d, dx, x : LONGINT;
			align, firstIndent, leftIndent, rightIndent, spaceBefore, spaceAfter : LONGINT;
			tabstring : ARRAY 256 OF CHAR; tabs : CustomTabStops; tp : TabPositions;
			sr : Streams.StringReader; tabCounter, tabPos : LONGINT; token : ARRAY 16 OF CHAR;
			pStyle : Texts.ParagraphStyle;
			start, stop, isFirst : BOOLEAN;
			bidiTextReader, localTextReader : Texts.TextReader;
			regionStart, regionEnd,lastEnd : LONGINT;
			readerPosition : LONGINT;
			highlighterStyle, lastHighlighterStyle : SyntaxHighlighter.Style;
			currentStyle, lastStyle : ANY;
			cf:  WMGraphics.Font;
			style : RECORD
				voff : LONGINT;
				font : WMGraphics.Font;
			END;

			PROCEDURE GetExtents(ch : Char32; VAR dx, ascent, descent: LONGINT);
			VAR gs : WMGraphics.GlyphSpacings; vc : WMComponents.VisualComponent; font : WMGraphics.Font;
			BEGIN
				IF ch = Texts.ObjectChar THEN
					IF (localTextReader.object # NIL) & (localTextReader.object IS WMGraphics.Image) THEN
						ascent := localTextReader.object(WMGraphics.Image).height - style.voff;
						descent := style.voff;
						dx :=  localTextReader.object(WMGraphics.Image).width
					ELSIF (localTextReader.object # NIL) & (localTextReader.object IS WMComponents.VisualComponent) THEN
						vc := localTextReader.object(WMComponents.VisualComponent);
						dx := vc.bounds.GetWidth();
						ascent := vc.bounds.GetHeight() - style.voff;
						descent := style.voff;
						(* Add a Sequencer to the object if none exists *)
			
						IF (vc.sequencer = NIL) OR (vc.sequencer # sequencer) THEN
							vc.SetSequencer(sequencer);
							IF sequencer#NIL THEN vc.Reset(NIL, NIL); END; 
						END;
					END
				ELSIF ch = Texts.TabChar THEN
					IF l.tabStops # NIL THEN dx := l.tabStops.GetNextTabStop(x) - x
					ELSE dx := defaultTabStops.GetNextTabStop(x) - x
					END;
					ascent := style.font.GetAscent() - style.voff;
					descent := style.font.GetDescent() + style.voff
				ELSIF ch = Texts.LabelChar THEN
					IF showLabels.Get() THEN
						font := cf;
						font.GetStringSize(localTextReader.object(Texts.LabelPiece).label^, dx, ascent);
						INC(dx, 4);
					ELSE
						ascent := 0; descent := 0;
						dx := 0;
					END;
				ELSE
					IF isPasswordI THEN ch := passwordChar.Get() END;
					IF style.font.HasChar(ch) THEN
						style.font.GetGlyphSpacings(ch, gs);
					ELSE
						WMGraphics.FBGetGlyphSpacings(ch, gs);
					END;
					ascent := gs.ascent - style.voff;
					descent := gs.descent + style.voff;
					dx := gs.bearing.l + gs.width + gs.bearing.r
				END
			END GetExtents;

		BEGIN
			style.voff := 0;
			cf := GetFont();
			style.font := cf;

			x := 0; l.pos := pos; l.height := style.font.GetHeight();

			(* For layouting a reordered line, the reordered text is needed, to correctly measure
				the extends of each character. *)
			IF text.isUTF & (layout.bidiFormatter # NIL) THEN
				isFirst := FALSE;
				bidiTextReader := layout.bidiFormatter.ReadyTextReader(pos,isFirst);
			END;

			(* if a reformatted text is available initialize it correpsondingly *)
			IF (bidiTextReader # NIL) THEN
				(* if a reordered line is available, the contextual dependency rules are applied *)
				bidiTextReader.CloneProperties(utilreader);
				localTextReader := bidiTextReader;
				localTextReader.text.AcquireRead;
				localTextReader.SetPosition(0);
			(* or initialize to default otherwise *)
			ELSE
				localTextReader := utilreader;
				localTextReader.SetPosition(pos);
			END;

			localTextReader.SetDirection(1); first := TRUE;

			(* the bidi formatter needs special treatment when finding out about the first line of the paragraph *)
			start := FALSE; stop := FALSE;
			IF (pos = 0) THEN start := TRUE;
			ELSIF (bidiTextReader = NIL) THEN
				localTextReader.SetPosition(pos-1);
				localTextReader.ReadCh(ch);
				IF (ch = Texts.NewLineChar) THEN start := TRUE;
				ELSE start := FALSE;
				END;
			ELSE (* bidiTextReader # NIL *)
				IF isFirst THEN
					start := TRUE;
				ELSE
					start := FALSE;
				END;
			END;

			i := 0;  leading := 0; ascent := style.font.GetAscent(); descent := style.font.GetDescent();
			align := AlignLeft; l.tabStops := NIL; COPY("", tabstring);
			firstIndent := 0; leftIndent := 0; rightIndent := 0; spaceBefore := 0; spaceAfter := 0;

			lastEnd := -1;
			highlighterStyle := NIL; lastHighlighterStyle := NIL;
			currentStyle := NIL; lastStyle := NIL;

			eol := FALSE;
			REPEAT
				readerPosition := localTextReader.GetPosition();
				localTextReader.ReadCh(ch);

				IF (highlighter # NIL) THEN
					ASSERT(state # NIL);
					IF (lastEnd < readerPosition) THEN
						highlighterStyle := highlighter.GetRegionStyle(readerPosition, state, regionStart, regionEnd);
						IF (highlighterStyle # NIL) THEN
							lastEnd := regionEnd;
						ELSE
							IF (ch > 32) THEN
								highlighterStyle := highlighter.GetWordStyle(localTextReader, readerPosition, lastEnd);
							END;
						END;
						localTextReader.SetPosition(readerPosition);
						localTextReader.ReadCh(ch); (* restore text reader state *)
					END;
					IF (highlighterStyle = NIL) THEN
						highlighterStyle := highlighter.GetDefaultStyle();
					END;
				END;

				(* Get the Paragraph Style *)
				IF localTextReader.pstyle # NIL THEN
					pStyle := localTextReader.pstyle;
					(* pStyle := Texts.GetParagraphStyleByName(pStyle.name); *)
					spaceBefore := ENTIER(FP1616.FixpToFloat(pStyle.spaceBefore));
					spaceAfter := ENTIER(FP1616.FixpToFloat(pStyle.spaceAfter));
					firstIndent := ENTIER(FP1616.FixpToFloat(pStyle.firstIndent));
					leftIndent := ENTIER(FP1616.FixpToFloat(pStyle.leftIndent));
					rightIndent := ENTIER(FP1616.FixpToFloat(pStyle.rightIndent));
					align := pStyle.alignment;
					(* parse tabstops *)
					COPY(pStyle.tabStops, tabstring);
					IF (tabstring # "default") & (tabstring # "0") & (tabstring # "") THEN
						NEW(sr, LEN(tabstring)); sr.Set(tabstring); tabCounter := 0;
						WHILE (sr.res = Streams.Ok) DO
							sr.SkipWhitespace; sr.String(token);
							INC(tabCounter);
						END;
						NEW(tp, tabCounter);
						sr.Reset; tabCounter := 0;
						WHILE (sr.res = Streams.Ok) DO
							sr.SkipWhitespace; sr.String(token);
							Strings.StrToInt(token, tabPos);
							tp[tabCounter] := tabPos;
							INC(tabCounter);
						END;
						NEW(tabs, tp);
						IF l.tabStops = NIL THEN l.tabStops := tabs END
					END;
				END;

				IF (highlighterStyle = NIL) OR (highlighterStyle.defined * SyntaxHighlighter.DefineMask # SyntaxHighlighter.DefineMask) THEN

					IF localTextReader.cstyle # NIL THEN
						IF (currentStyle # localTextReader.cstyle) THEN
							currentStyle := localTextReader.cstyle;
							style.voff := ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.baselineShift));
							ld := ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.leading));
							IF (localTextReader.cstyle.fontcache #NIL) & (localTextReader.cstyle.fontcache IS WMGraphics.Font) THEN
								style.font := localTextReader.cstyle.fontcache(WMGraphics.Font);
							ELSE
								style.font := WMGraphics.GetFont(localTextReader.cstyle.family, ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.size)), localTextReader.cstyle.style);
								localTextReader.cstyle.fontcache := style.font;
							END;
						END;
					ELSIF localTextReader.pstyle # NIL THEN
						IF pStyle.charStyle # NIL THEN
							style.voff := ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.baselineShift));
							ld := ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.leading));
							IF (localTextReader.cstyle.fontcache #NIL) & (localTextReader.cstyle.fontcache IS WMGraphics.Font) THEN
								style.font := localTextReader.cstyle.fontcache(WMGraphics.Font);
							ELSE
								 style.font := WMGraphics.GetFont(localTextReader.cstyle.family, ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.size)), localTextReader.cstyle.style);
								localTextReader.pstyle.charStyle.fontcache := style.font
							END
						END;
					ELSIF localTextReader.attributes # NIL THEN
						IF (currentStyle # localTextReader.attributes) THEN
							currentStyle := localTextReader.attributes;
							style.voff := localTextReader.attributes.voff;
							ld := 0;
							IF localTextReader.attributes.fontInfo # NIL THEN
								IF (localTextReader.attributes.fontInfo.fontcache # NIL) & (localTextReader.attributes.fontInfo.fontcache IS WMGraphics.Font) THEN
									style.font := localTextReader.attributes.fontInfo.fontcache(WMGraphics.Font);
								ELSE
									style.font := GetFontFromAttr(localTextReader.attributes.fontInfo);
									localTextReader.attributes.fontInfo.fontcache := style.font;
								END
							ELSE
								style.font := cf
							END
						END;
					ELSE
						IF (currentStyle # DefaultStyle) THEN
							currentStyle := DefaultStyle;
							style.voff := 0;
							style.font := cf;
							ld := 0;
						END;
					END;
					ASSERT(style.font # NIL);
				END;

				IF (highlighterStyle # NIL) THEN
					IF (highlighterStyle # lastHighlighterStyle) OR (currentStyle # lastStyle) THEN
						IF SyntaxHighlighter.Voff IN highlighterStyle.defined THEN style.voff := highlighterStyle.attributes.voff; END;
						IF (SyntaxHighlighter.FontMask * highlighterStyle.defined # {}) THEN
							CheckFont(highlighterStyle, style.font, fontCache);
							style.font := highlighterStyle.attributes.fontInfo.fontcache (WMGraphics.Font);
						END;
					END;
					currentStyle := NIL;
				END;
				lastStyle := currentStyle;
				lastHighlighterStyle := highlighterStyle;

				IF first THEN
					IF (ch = Texts.NewLineChar) OR (ch = 0) THEN
						ascent := style.font.GetAscent(); descent := style.font.GetDescent();
					ELSE
						descent := 0; ascent := 0;
					END;
					IF start THEN wrapwidth := wrapwidth - firstIndent - rightIndent;
					ELSE wrapwidth := wrapwidth - leftIndent - rightIndent;
					END;
					first := FALSE;
				END;
				INC(pos);
				IF (stopPos < 0) OR (pos <= stopPos) THEN
					IF (ch # Texts.NewLineChar) & (ch # 0) THEN
						GetExtents(ch, dx, a, d); ascent := Strings.Max(ascent, a); descent := Strings.Max(descent, d);
						IF ld = 0 THEN ld := ascent + descent; ELSE ld := Strings.Max(ld, ascent + descent); END; leading := Strings.Max(leading, ld);
						IF isMultiLineI & (wrapModeI # NoWrap) & (i > 0) & (x0 + x + dx > wrapwidth) THEN
							eol := TRUE; DEC(pos); wrapPos := pos;
							(* Go left for last space *)
							IF wrapModeI = WrapWord THEN
								pos := TextUtilities.FindPosWordLeft(localTextReader, pos);
								IF pos <= l.pos THEN pos := wrapPos (* no word break found. wrap at latest possible pos *)
								ELSE (* decrease width to actual size.. *)
(*									localTextReader.SetPosition(pos);
									WHILE pos < wrapPos DO
										localTextReader.ReadCh(ch); GetExtents(ch, dx, a, d); x := x - dx; INC(pos)
									END
*)								END
							END
						ELSE
							IF (stopXPos >= 0) & (x + dx DIV 2 > stopXPos) THEN
								DEC(pos);

								(* the bidi formatted text's lock needs to be released explicitly *)
								IF (bidiTextReader # NIL) THEN
									localTextReader.text.ReleaseRead;
								END;
								RETURN
							END;
							INC(x, dx)
						END;
					ELSE
						eol := TRUE;
						stop := TRUE;
						IF (stopXPos >= 0) THEN DEC(pos) END;
					END;
				ELSE
					eol := TRUE
				END;
				INC(i);
			UNTIL eol OR localTextReader.eot;

			l.width := x;
			l.ascent := ascent; l.height := leading; (* ascent + descent; *)
			l.align := align; l.leftIndent := leftIndent; l.rightIndent := rightIndent;
			IF l.height = 0 THEN l.height := style.font.GetHeight() END;
			IF start THEN l.firstInParagraph := TRUE; l.firstIndent := firstIndent;	l.spaceBefore := spaceBefore;
			ELSE l.firstInParagraph := FALSE;	END;
			IF stop THEN l.lastInParagraph := TRUE; l.spaceAfter := spaceAfter;
			ELSE l.lastInParagraph := FALSE END;

			(* the bidi formatted text's lock needs to be released explicitly *)
			IF (bidiTextReader # NIL) THEN
				localTextReader.text.ReleaseRead;
			END;
		END LayoutLine;

		(* llen = -1 to render until the end of line > 0 to render llen elements in the line *)
		PROCEDURE RenderLine*(canvas : WMGraphics.Canvas; VAR l : LineInfo; linenr, top, llen : LONGINT);
		VAR sx, dx, dy, x, sp, i, j, k, t, tx, linelength, w, p : LONGINT; char : Char32; gs: WMGraphics.GlyphSpacings;
	 		font : WMGraphics.Font;
	 		vc : WMComponents.VisualComponent;
	 		hc : BOOLEAN;
	 		bidiTextReader, localTextReader : Texts.TextReader;
			cursorPosition : LONGINT;
			regionStart, regionEnd, lastEnd: LONGINT;
			readerPosition : LONGINT;
			lineNumberString : ARRAY 16 OF CHAR;
			canvasState : WMGraphics.CanvasState;
			cliprect, temp : WMRectangles.Rectangle;
			highlighterStyle, lastHighlighterStyle : SyntaxHighlighter.Style;
			currentStyle, lastStyle : ANY;
			lastColor : LONGINT;
			cf: WMGraphics.Font;
			style : RECORD
				color, bgColor, voff : LONGINT;
				font : WMGraphics.Font;
			END;
		BEGIN
			IF TraceRenderOptimize IN Trace THEN
				KernelLog.String("RenderLine : "); KernelLog.Int(linenr, 5); KernelLog.String(" from position : ");
				KernelLog.Int(layout.GetLineStartPos(linenr), 5); KernelLog.Ln;
			END;

			sp := l.pos;
			IF sp >= text.GetLength() THEN RETURN END;

			style.color := defaultTextColorI;
			canvas.SetColor(style.color); lastColor := style.color;
			style.bgColor := defaultTextBgColorI;
			style.voff := 0;
			cf := GetFont();
			style.font := cf;

			IF llen < 0 THEN
				linelength := layout.GetLineLength(linenr);
				(* hack for the bidi formatter *)
				IF linenr = layout.GetNofLines() - 1 THEN
					DEC(linelength);
				END;
			ELSE
				linelength := llen
			END;

			(* if there is a bidi formatter, reorder the current line *)
			IF text.isUTF & (layout.bidiFormatter # NIL) THEN
				bidiTextReader := layout.bidiFormatter.ReorderLine(sp,linelength);
			END;

			(* the bidi text reader needs special treatment for the initialization *)
			IF (bidiTextReader # NIL) THEN
				(* after reordering the line, contextual dependency rules are applied *)
				bidiTextReader := ContextualDependency.AnalyzeLine(bidiTextReader,-1,-1);
				layout.bidiFormatter.SetReadyTextReader(sp,bidiTextReader);
				bidiTextReader.CloneProperties(utilreader);
				localTextReader := bidiTextReader;
				localTextReader.text.AcquireRead;
				localTextReader.SetPosition(0);
			ELSE
				(* revert the hack for the bidi formatter *)
				IF (llen < 0) & (linenr = layout.GetNofLines() - 1) THEN
					INC(linelength);
				END;
				localTextReader := utilreader;
				localTextReader.text.AcquireRead;
				localTextReader.SetPosition(sp);
			END;

			i := 0;
			x := GetLineLeftIndent(linenr);
			sx := - leftShiftI + bordersI.l + x0;
			IF TraceBaseLine IN Trace THEN
				canvas.Line(0, top + (l.ascent), bounds.GetWidth(), top + (l.ascent), 01F0000FFH, WMGraphics.ModeCopy)
			END;

			selection.Sort;
			IF (cursor.visible) & (selection.b - selection.a <= 0) & (clBgCurrentLineI # 0) THEN
				cursorPosition := cursor.GetPosition();
				IF (l.pos <= cursorPosition) & (cursorPosition < l.pos + linelength) THEN
					canvas.Fill(WMRectangles.MakeRect(0, top, bounds.GetWidth() - bordersI.r, top + l.height), clBgCurrentLineI, WMGraphics.ModeSrcOverDst);
				END;
			END;

			IF showLineNumbersI THEN
				canvas.SaveState(canvasState);
				Strings.IntToStr(linenr + 1, lineNumberString);
				temp := WMRectangles.MakeRect(bordersI.l, top, x0 - 1, top + l.height);
				IF (lineNumberBgColorI # 0) THEN
					canvas.Fill(temp, lineNumberBgColorI, WMGraphics.ModeSrcOverDst);
				END;
				temp.r := temp.r - 4;
				IF ((linenr + 1) MOD 10 = 0) THEN
					canvas.SetFont(lineNumberFont10);
				ELSE
					canvas.SetFont(lineNumberFont);
				END;
				canvas.SetColor(lineNumberColorI);
				WMGraphics.DrawStringInRect(canvas, temp, FALSE, WMGraphics.AlignRight, WMGraphics.AlignCenter, lineNumberString);
				canvas.RestoreState(canvasState); (* restore font and font color *)

				canvas.SaveState(canvasState);
				canvas.GetClipRect(cliprect);
				cliprect.l := x0;
				canvas.SetClipRect(cliprect);
			END;

			w := bounds.GetWidth() - bordersI.r;

			localTextReader.SetDirection(1);

			lastEnd := -1;
			highlighterStyle := NIL; lastHighlighterStyle := NIL;
			currentStyle := DefaultStyle; lastStyle := NIL;

			REPEAT

				readerPosition := localTextReader.GetPosition();
				localTextReader.ReadCh(char);

				IF (highlighter # NIL) THEN
					ASSERT(state # NIL);
					IF (lastEnd < readerPosition) THEN
						highlighterStyle := highlighter.GetRegionStyle(readerPosition, state, regionStart, regionEnd);
						IF (highlighterStyle # NIL) THEN
							lastEnd := regionEnd;
						ELSE
							IF (char > 32) THEN
								highlighterStyle := highlighter.GetWordStyle(localTextReader, readerPosition, lastEnd);
							END;
						END;
						localTextReader.SetPosition(readerPosition);
						localTextReader.ReadCh(char); (* restore text reader state *)
					END;
					IF (highlighterStyle = NIL) THEN
						highlighterStyle := highlighter.GetDefaultStyle();
					END;
				END;

				IF (highlighterStyle = NIL) OR (highlighterStyle.defined * SyntaxHighlighter.DefineMask # SyntaxHighlighter.DefineMask) THEN

					IF (localTextReader.cstyle # NIL) THEN
						IF (currentStyle # localTextReader.cstyle) THEN
							currentStyle := localTextReader.cstyle;
							style.color := localTextReader.cstyle.color;
							style.bgColor := localTextReader.cstyle.bgColor;
							style.voff := localTextReader.cstyle.baselineShift;
							IF (localTextReader.cstyle.fontcache # NIL) & (localTextReader.cstyle.fontcache IS WMGraphics.Font) THEN
								style.font := localTextReader.cstyle.fontcache(WMGraphics.Font);
							ELSE
								style.font := WMGraphics.GetFont(localTextReader.cstyle.family, ENTIER(FP1616.FixpToFloat(localTextReader.cstyle.size)), localTextReader.cstyle.style);
								localTextReader.cstyle.fontcache := style.font;
							END;
						END;
					ELSIF (localTextReader.attributes # NIL) THEN
						IF (currentStyle # localTextReader.attributes) THEN
							currentStyle := localTextReader.attributes;
							style.color := localTextReader.attributes.color;
							style.bgColor := localTextReader.attributes.bgcolor;
							style.voff := localTextReader.attributes.voff;
							IF (localTextReader.attributes.fontInfo # NIL) THEN
								IF (localTextReader.attributes.fontInfo.fontcache # NIL) & (localTextReader.attributes.fontInfo.fontcache IS WMGraphics.Font) THEN
									style.font := localTextReader.attributes.fontInfo.fontcache (WMGraphics.Font);
								ELSE
									style.font := GetFontFromAttr(localTextReader.attributes.fontInfo);
									localTextReader.attributes.fontInfo.fontcache := style.font;
								END;
							ELSE
								style.font := cf;
							END;
						END;
					ELSE
						IF (currentStyle # DefaultStyle) THEN
							currentStyle := DefaultStyle;
							style.color := defaultTextColorI;
							style.bgColor := defaultTextBgColorI;
							style.voff := 0;
							style.font := cf;
						END;
					END;
					ASSERT(style.font # NIL);
				END;

				IF (highlighterStyle # NIL) THEN
					IF (highlighterStyle # lastHighlighterStyle) OR (currentStyle # lastStyle) THEN
						IF SyntaxHighlighter.Voff IN highlighterStyle.defined THEN style.voff := highlighterStyle.attributes.voff; END;
						IF SyntaxHighlighter.Color IN highlighterStyle.defined THEN style.color := highlighterStyle.attributes.color; END;
						IF SyntaxHighlighter.BgColor IN highlighterStyle.defined THEN style.bgColor := highlighterStyle.attributes.bgcolor; END;
						IF (SyntaxHighlighter.FontMask * highlighterStyle.defined # {}) THEN
							CheckFont(highlighterStyle, style.font, fontCache);
							style.font := highlighterStyle.attributes.fontInfo.fontcache (WMGraphics.Font);
						END;
					END;
					currentStyle := NIL; (* force reevaluation of localTextReader style *)
				END;
				lastStyle := currentStyle;
				lastHighlighterStyle := highlighterStyle;

				IF (style.color # lastColor) THEN canvas.SetColor(style.color); lastColor := style.color; END;

				IF char = Texts.ObjectChar THEN
					IF (localTextReader.object # NIL) & (localTextReader.object IS WMGraphics.Image) THEN
						canvas.DrawImage(x, top + (l.ascent) + style.voff - localTextReader.object(WMGraphics.Image).height, localTextReader.object(WMGraphics.Image),
							WMGraphics.ModeSrcOverDst);
						dx := localTextReader.object(WMGraphics.Image).width
					ELSIF (localTextReader.object # NIL) & (localTextReader.object IS WMComponents.VisualComponent) THEN
						vc := localTextReader.object(WMComponents.VisualComponent);
						dx := vc.bounds.GetWidth();
						dy := vc.bounds.GetHeight();
						canvas.SaveState(clipState); (* save the current clip-state *)
						canvas.SetClipRect(WMRectangles.MakeRect(x + sx, top + (l.ascent - dy), x + dx + sx, top + (l.height)));
						canvas.ClipRectAsNewLimits(x + sx, top + (l.ascent - dy));
						(* assuming the component will not delay --> otherwise a buffer is needed *)
						vc.Acquire; vc.Draw(canvas); vc.Release;
						canvas.RestoreState(clipState)
					END
				ELSIF char = 0 THEN (* EOT *)
				ELSIF char = Texts.TabChar THEN
					tx := x;
					IF l.firstInParagraph THEN tx := tx - l.firstIndent
					ELSE tx := tx - l.leftIndent END;
					IF l.tabStops # NIL THEN dx := l.tabStops.GetNextTabStop(tx) - tx
					ELSE dx := defaultTabStops.GetNextTabStop(tx) - tx
					END;
					IF style.bgColor # 0 THEN
						canvas.Fill(WMRectangles.MakeRect(x + sx, top, x + dx + sx, top + (l.height)), style.bgColor, WMGraphics.ModeSrcOverDst)
					END;
					IF indicateTabsI THEN canvas.SetPixel(x + sx + ((dx + 1) DIV 2), top + ((l.ascent + 1) DIV 2), WMGraphics.Blue, WMGraphics.ModeCopy); END;
				ELSIF char = Texts.LabelChar THEN
					IF showLabels.Get() THEN
						font := cf;
						font.GetStringSize(localTextReader.object(Texts.LabelPiece).label^, dx, dy);
						font.RenderString(canvas, x + sx+2, top + (l.ascent), localTextReader.object(Texts.LabelPiece).label^);
						INC(dx, 4);
						canvas.Fill(WMRectangles.MakeRect(x + sx, top, x + dx + sx, top + (l.height)), LONGINT(0FF880050H), WMGraphics.ModeSrcOverDst);
						WMGraphicUtilities.RectGlassShade(canvas, WMRectangles.MakeRect(x + sx, top, x + dx + sx, top + (l.height)), 1, FALSE)
					ELSE dx := 0; END;
				ELSE
					IF char = Texts.NewLineChar THEN
						localTextReader.text.ReleaseRead;
						IF showLineNumbersI THEN canvas.RestoreState(canvasState); END;
						RETURN
					END;
					IF isPasswordI THEN
						char := passwordChar.Get()
					END;

					(* If the text is utf-formatted get the display version of the character.
						Note, that only some special invisible characters differ from their actual representation. *)
					IF text.isUTF THEN
						UnicodeBidirectionality.GetDisplayCharacter(char);
					END;
					hc := style.font.HasChar(char);
					IF hc THEN style.font.GetGlyphSpacings(char, gs)
					ELSE WMGraphics.FBGetGlyphSpacings(char, gs)
					END;
					dx := gs.bearing.l + gs.width + gs.bearing.r;

					IF style.bgColor MOD 256 # 0 THEN
						canvas.Fill(WMRectangles.MakeRect(x + sx, top, x + dx + sx, top + (l.height)), style.bgColor, WMGraphics.ModeCopy)
					END;
					IF hc THEN style.font.RenderChar(canvas, x + sx, top + (l.ascent) + style.voff, char)
					ELSE WMGraphics.FBRenderChar(canvas, x + sx, top + (l.ascent) + style.voff, char)
					END
				END;

				(* link *)
				IF localTextReader.link # NIL THEN
					canvas.Line(x + sx, top + (l.ascent)+1, x + dx + sx, top + (l.ascent)+1, canvas.color, WMGraphics.ModeSrcOverDst);
				END;

				(* highlight - since highlights store the global text position, the line's starting position needs to be added,
					when operating on the local, bidirectional text reader. *)
				IF bidiTextReader # NIL THEN
					p := GetInternalPos(localTextReader.GetPosition()+sp-1);
				ELSE
					p := localTextReader.GetPosition() - 1;
				END;
				FOR j := 0 TO nofHighlights - 1 DO
					IF (p >= highlights[j].a) & (p < highlights[j].b) THEN
						CASE highlights[j].kind OF
							|HLOver: canvas.Fill(WMGraphics.MakeRectangle(x + sx, top, x + dx + sx, top + (l.height)), highlights[j].color, WMGraphics.ModeSrcOverDst)
							|HLUnder: canvas.Line(x + sx, top + (l.ascent), x + dx + sx, top + (l.ascent), highlights[j].color, WMGraphics.ModeSrcOverDst);
							|HLWave:
								FOR k := 0 TO dx - 1 DO
									t := 1 - ABS((x + k) MOD 4 - 2); (* because of compiler bug on intel *)
									canvas.SetPixel(x + k + sx, top + l.ascent + t, highlights[j].color, WMGraphics.ModeSrcOverDst);
								END;
						ELSE
						END
					END
				END;
				x := x + dx;
				INC(i)
			UNTIL (i >= linelength) OR localTextReader.eot OR (x + sx > w);
			localTextReader.text.ReleaseRead;
			IF showLineNumbersI THEN canvas.RestoreState(canvasState); END;
		END RenderLine;

		PROCEDURE RenderAboveTextMarkers*(canvas : WMGraphics.Canvas);
		VAR x, y, l, pos, i, ascent : LONGINT;
		BEGIN
			AssertLock;
			IF text = NIL THEN RETURN END;
			IF optimize THEN RETURN END;
			text.AcquireRead;
			FOR i := nofPositionMarkers - 1 TO 0 BY -1 DO
				pos := positionMarkers[i].pos.GetPosition();
				l := layout.FindLineNrByPos(pos);
				IF FindScreenPos(pos, x, y) THEN
					IF (l >= 0) & (l < layout.GetNofLines()) THEN
						ascent := layout.lines[l].ascent;
					(*	IF ascent = 0 THEN ascent := layout.lines[l].height END;
						IF ascent = 0 THEN ascent := 10 END; *)
					ELSE ascent := 10 END;
					positionMarkers[i].Draw(canvas, x, y, ascent)
				END
			END;
			text.ReleaseRead;
		END RenderAboveTextMarkers;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR la, lb, i, top, t, b : LONGINT; rect, clip : WMRectangles.Rectangle; cstate : WMGraphics.CanvasState;
		BEGIN
			ASSERT(layout # NIL);

			canvas.GetClipRect(clip);
			IF WMRectangles.RectEmpty(clip) THEN RETURN END;
			rect := GetClientRect();
			canvas.SaveState(cstate);

			IF WMRectangles.Intersect(rect, clip) THEN
				DrawBackground^(canvas);
				IF showBorderI THEN
					WMGraphicUtilities.DrawBevel(canvas, rect,
						1, TRUE, LONGINT(0808080FFH), WMGraphics.ModeCopy)
				END;
			END;

			(* allow clean clipping in at inner border *)
			WMRectangles.ClipRect(rect, borderClip);
			WMRectangles.ClipRect(clip, borderClip);
			canvas.SetClipRect(clip);

			(* draw gutter *)
			rect.r := x0 - 1;
			IF showLineNumbersI & (lineNumberBgColorI # 0) & WMRectangles.Intersect(rect, clip) THEN
				canvas.Fill(rect, lineNumberBgColorI, WMGraphics.ModeSrcOverDst);
			END;

			text.AcquireRead;
			la := FindLineByY(firstLineI, clip.t);
			lb := FindLineByY(firstLineI, clip.b);

			(* prepare selections *)
			FOR i := 0 TO nofHighlights - 1 DO
				highlights[i].a := highlights[i].from.GetPosition();
				highlights[i].b := highlights[i].to.GetPosition();
				IF highlights[i].a > highlights[i].b THEN t := highlights[i].a; highlights[i].a := highlights[i].b; highlights[i].b := t END
			END;

			top := borderClip.t;
			IF (la = lb) & (textAlignV.Get() = WMGraphics.AlignCenter) THEN 
				top := (borderClip.t+borderClip.b-layout.lines[la].height) DIV 2;
				(* something is wrong with ascent and height here, does not comply with the notions in fonts *)
			END;

			FOR i := firstLineI TO la - 1 DO
				top := top + (layout.lines[i].height);
				CheckParagraphBegin(i, top);
				CheckParagraphEnd(i, top);
			END;

			IF la >= 0 THEN
				(* draw the lines that intersect the clipping rectangle *)
				FOR i := la TO lb DO
					CheckParagraphBegin(i, top);
					RenderLine(canvas, layout.lines[i], i, top, -1);
					top := top + (layout.lines[i].height);
					CheckParagraphEnd(i, top);
				END
			END;

			RenderAboveTextMarkers(canvas);
			text.ReleaseRead;
			canvas.RestoreState(cstate);
		END DrawBackground;

		PROCEDURE StoreLineEnter;
		VAR pos, cl : LONGINT;
		BEGIN
			pos := cursor.GetPosition();
			cl := layout.FindLineNrByPos(pos);
			lineEnter := pos - layout.GetLineStartPos(cl)
		END StoreLineEnter;

	(* navigation *)
		PROCEDURE WheelMove*(dz: LONGINT); (** PROTECTED *)
		BEGIN
			IF mouseWheelScrollSpeedI # 0 THEN
				firstLine.Set(firstLine.Get() + mouseWheelScrollSpeedI * dz)
			END;
		END WheelMove;

		(* abort a possible start of a command. Clear the command start indicator, if it was set *)
		PROCEDURE AbortStart;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF commandMarker # NIL THEN
				RemoveHighlight(commandMarker);
				commandMarker := NIL
			END;
			canStart := FALSE
		END AbortStart;

		(*
			Handle double-click at text position <pos>.
			Select the double-clicked word, whitespace or line.

			Some explanations:
			Why utilreader.GetPosition()+2 when searching to the left?
			After we read the last character that should be included, the position of the reader is decremented.
			When we now read the next character and see that it should not be included, the reader is decremented again.
			-> The last character to be included was found at position utilreader.GetPosition()+2 (except when we reach EOT)

			The same applies when search to the right. But to highlight the character at, for example,  position 4, we need a highlight from 4-5.
			That's why utilreader.GetPosition()-1 is used instead of utilreader.GetPosition()-2.
		*)
		PROCEDURE DoubleClickSelect(pos : LONGINT);
		CONST
			LineFeed = 0AH;
			Underscore = 05FH;
		VAR
			char : Texts.Char32;
			from, to : LONGINT;
		BEGIN
			ASSERT(text.HasReadLock());
			utilreader.SetPosition(pos);
			utilreader.SetDirection(1);
			utilreader.ReadCh(char);
			IF (char = LineFeed) OR utilreader.eot THEN (* select line *)
				IF utilreader.eot THEN to := pos;
				ELSE to := pos+1;
				END;
				from := TextUtilities.FindPosLineStart(utilreader, pos);
			ELSIF TextUtilities.IsWhiteSpace(char,text.isUTF) THEN
				WHILE ~utilreader.eot & TextUtilities.IsWhiteSpace(char,text.isUTF) & (char # LineFeed) DO utilreader.ReadCh(char); END;
				IF utilreader.eot THEN to := utilreader.text.GetLength();
				ELSE to := utilreader.GetPosition()-1;
				END;
				utilreader.SetPosition(pos);
				utilreader.SetDirection(-1);
				utilreader.ReadCh(char);
				WHILE ~utilreader.eot & TextUtilities.IsWhiteSpace(char,text.isUTF) & (char # LineFeed) DO utilreader.ReadCh(char); END;
				IF utilreader.eot THEN from := 0;
				ELSE from := utilreader.GetPosition()+2;
				END;
			ELSIF TextUtilities.IsAlphaNum(char) OR (char = Underscore) THEN (* select word *)
				WHILE ~utilreader.eot & (TextUtilities.IsAlphaNum(char) OR (char = Underscore)) DO utilreader.ReadCh(char); END;
				IF utilreader.eot THEN to := utilreader.text.GetLength();
				ELSE to := utilreader.GetPosition()-1;
				END;
				utilreader.SetPosition(pos);
				utilreader.SetDirection(-1);
				utilreader.ReadCh(char);
				WHILE ~utilreader.eot & (TextUtilities.IsAlphaNum(char) OR (char = Underscore)) DO utilreader.ReadCh(char); END;
				IF utilreader.eot THEN from := 0;
				ELSE from := utilreader.GetPosition()+2;
				END;
			ELSE (* select the character at text position pos *)
				from := pos; to := pos+1;
			END;
			selection.SetFromTo(from, to);
			cursor.SetVisible(to - from > 0);
		END DoubleClickSelect;

		PROCEDURE SetInterclick(new : LONGINT);
		VAR old : LONGINT;
		BEGIN
			old := interclick;
			IF (old # new) THEN
				interclick := new;
				CASE new OF
					| Interclick01: selection.SetColor(SelectionColorInterclick01);
					| Interclick02: selection.SetColor(SelectionColorInterclick02);
				ELSE
					selection.SetColor(SelectionColor);
				END;
			END;
		END SetInterclick;

		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		VAR pos, a, b, internalPos : LONGINT; oldInterclick : LONGINT;
		BEGIN
			ViewToTextPos(x,y,pos);
			internalPos := GetInternalPos(pos);

			oldInterclick := interclick;
			IF (keys * {0, 1} = {0,1}) THEN SetInterclick(Interclick01);
			ELSIF (keys * {0,2} = {0,2}) THEN SetInterclick(Interclick02);
			ELSE SetInterclick(InterclickNone);
			END;
			(* Determine whether to cancel an interclick if any *)
			IF (oldInterclick = InterclickCancelled) OR
				((oldInterclick # InterclickNone) & (interclick # InterclickNone)) THEN
				SetInterclick(InterclickCancelled);
			END;
			IF allowCommandExecution.Get() & (keys * {0, 1, 2} = {1}) THEN
				canStart := TRUE; openFile := FALSE;
				IF commandMarker = NIL THEN
					commandMarker := CreateHighlight();
					commandMarker.SetKind(HLUnder);
					commandMarker.SetColor(LONGINT(0FF0000FFH));
					text.AcquireRead;
					FindCommand(internalPos, a, b);
					commandMarker.SetFromTo(a, b);
					cursor.SetPosition(pos);
					text.ReleaseRead
				END;
			END;
			IF canStart & (2 IN keys) THEN openFile := TRUE; SetInterclick(InterclickCancelled); END;
			IF keys * {0, 1, 2} = {0, 1, 2} THEN AbortStart END;

			IF allowPiemenu.Get() & (keys * {0, 1, 2} = {2}) THEN
				text.AcquireRead;
				ViewToTextPos(x, y, pos);
				cursor.SetPosition(pos);
				text.ReleaseRead;
				ShowContextMenu(x, y)
			END;

			IF allowTextSelection.Get() &
			( (keys * {0, 1, 2} = {0})  (* left mouse for select *)
			   OR (keys * {0, 1, 2} = {1}) & doubleclickedWord  (* remove selection when double clicking *)
			   OR (keys * {0,1,2} = {2}) & (~allowPiemenu.Get())) (* right mouse for selection if pie menu is not enabled *)
			THEN
				AbortStart;
				text.AcquireRead;
				ViewToTextPos(x, y, pos);
				dragPossible := FALSE; selectWords := FALSE;
				IF internalPos >= 0 THEN
					selection.Sort;
					IF (internalPos >= selection.a) & (internalPos < selection.b) & (interclick = InterclickNone) THEN
						dragPossible := TRUE; downX := x; downY := y
					ELSIF (interclick = InterclickNone) THEN
						(* clicking the same position twice --> Word Selection Mode *)
						IF (internalPos = GetInternalPos(cursor.GetPosition())) OR ((internalPos - 1 = GetInternalPos(cursor.GetPosition())) & (internalPos - 1 = text.GetLength())) THEN
							(* Workaround: The 2nd check is for the very last line of a text. LayoutLine gives pos = text.GetLength()+1 *)
							selectWords := TRUE; wordSelOrdered := TRUE;
							doubleclickedWord := TRUE;
							DoubleClickSelect(internalPos);
						ELSE
							selection.SetFromTo(internalPos, internalPos); (* reset selection *)
							cursor.SetVisible(TRUE);
						END;
						selecting := TRUE;
					END
				END;
				cursor.SetPosition(pos);
				text.ReleaseRead;
				CursorChanged
			END;
		END PointerDown;

		PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		VAR pos, a, b, internalPos : LONGINT;
		BEGIN
			IF ~canStart & dragPossible THEN
				IF (ABS(x - downX) > DragDist) OR (ABS(y - downY) > DragDist) THEN dragPossible := FALSE; AutoStartDrag END
			ELSE
				IF (selecting OR canStart) & (interclick = InterclickNone) THEN
					text.AcquireRead;
					ViewToTextPos(x, y, pos);
					internalPos := GetInternalPos(pos);
					IF selecting & ~doubleclickedWord THEN
						selection.Sort;
						IF selectWords THEN
							IF internalPos < selection.from.GetPosition() THEN
								pos := TextUtilities.FindPosWordLeft(utilreader, internalPos - 1);
							ELSE
								pos := TextUtilities.FindPosWordRight(utilreader, internalPos + 1);
							END;
							selection.SetTo(internalPos)
						ELSE
							selection.SetTo(internalPos);
						END;
						selection.Sort;
						cursor.SetVisible(selection.b - selection.a <= 0);
						Texts.SetLastSelection(text, selection.from, selection.to);
						cursor.SetPosition(pos);
						StoreLineEnter;
					ELSIF canStart THEN
						IF commandMarker # NIL THEN
							FindCommand(internalPos, a, b);
							commandMarker.SetFromTo(a, b)
						END
					END;
					IF doubleclickedWord THEN doubleclickedWord := FALSE; END; (* allow selecting again *)
					text.ReleaseRead;
					CursorChanged
				END
			END
		END PointerMove;

		PROCEDURE PointerUp*(x, y : LONGINT; keys : SET);
		BEGIN
			IF canStart & (commandMarker # NIL) THEN
				commandMarker.Sort;
				StartCommand((commandMarker.a + commandMarker.b) DIV 2, openFile);
				AbortStart
			END;
			IF modifierFlags * Inputs.Ctrl # {} THEN
				onCtrlClicked.Call(NIL)
			END;
			selecting := FALSE;
			doubleclickedWord := FALSE;
			IF (keys * {0,1,2} = {}) THEN
				IF (interclick = Interclick02) THEN
					DeleteSelection;
				END;
				SetInterclick(InterclickNone);
			END;
			IF dragPossible THEN selection.SetFromTo(0, 0); cursor.SetVisible(TRUE); Texts.ClearLastSelection (* reset selection *) END;
			dragPossible := FALSE
		END PointerUp;

		(* Transforms the TextView Coordinates into TextObject obj Coordinates *)
		PROCEDURE TransformCoordinates(VAR x, y : LONGINT; obj : WMComponents.VisualComponent);
		VAR line, pos, x0, y0, y1 : LONGINT;
		BEGIN
			ViewToTextPos(x, y, pos);
			IF FindScreenPos(pos, x0, y0) THEN
				IF x0 > x THEN pos := pos - 1;
					IF FindScreenPos(pos, x0, y0) THEN END;
				END;
				line := layout.FindLineNrByPos(GetInternalPos(pos));
				LineYPos(line, y0, y1);
				x := x - x0;
				y := y - y0;
				IF line >= 0 THEN y := y - (layout.lines[line].ascent - obj.bounds.GetHeight()); END
			END
		END TransformCoordinates;

		(* Change the pointer according to the underlaying component *)
		PROCEDURE ChangePointer(pointerInfo : WMWindowManager.PointerInfo);
		BEGIN
			IF GetPointerInfo() # pointerInfo THEN
				SetPointerInfo(pointerInfo)
			END
		END ChangePointer;

		(* Returns TRUE if an Object is Hit, FALSE otherwise *)
		PROCEDURE HitObject(x, y : LONGINT; (* keys : SET;*)  VAR pos : LONGINT; VAR obj : ANY): BOOLEAN;
		VAR ch, tx, ty : LONGINT;
		BEGIN
			text.AcquireRead;
			ViewToTextPos(x, y, pos);
			IF FindScreenPos(pos, tx, ty) THEN
				IF tx > x THEN pos := pos - 1 END
			END;
			utilreader.SetPosition(GetInternalPos(pos));
			utilreader.ReadCh(ch);
			text.ReleaseRead;
			IF ch = Texts.ObjectChar THEN obj := utilreader.object;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END HitObject;

		(* Returns TRUE if a Link is Hit, FALSE otherwise *)
		PROCEDURE HitLink(x, y : LONGINT;  VAR pos : LONGINT; VAR link : Texts.Link): BOOLEAN;
		VAR ch, tx, ty : LONGINT;
		BEGIN
			text.AcquireRead;
			ViewToTextPos(x, y, pos);
			IF FindScreenPos(pos, tx, ty) THEN
				IF tx > x THEN pos := pos - 1 END
			END;
			utilreader.SetPosition(GetInternalPos(pos));
			utilreader.ReadCh(ch);
			text.ReleaseRead;
			IF utilreader.link # NIL THEN
				link := utilreader.link;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END HitLink;

		PROCEDURE LinkClick(link : Texts.Link);
		VAR w : LinkWrapper;
		BEGIN
			NEW(w); w.link := link;
			onLinkClicked.Call(w)
		END LinkClick;

		(* builtin behaviour *)
		PROCEDURE LinkClicked*(sender, data : ANY);
		VAR tempLink : ARRAY 2048 OF CHAR;
			tempLabel : ARRAY 256 OF CHAR;
			pos, i : LONGINT;
		BEGIN
			IF data IS LinkWrapper THEN
				COPY(data(LinkWrapper).link^, tempLink);
				IF tempLink[0] = "#" THEN	(* internal link *)
					i := 0;
					WHILE tempLink[i] # 0X DO
						tempLabel[i] := tempLink[i+1];
						INC(i);
					END;
					tempLink[i] := 0X;
					(* find label in tv *)
					IF FindLabel(tempLabel, pos) THEN
						i := layout.nofLines-1;
						WHILE (i >= 0) DO
							IF layout.GetLineStartPos(i) < pos THEN firstLine.Set(i); RETURN END;
							DEC(i);
						END;
					END;
				ELSE	(* other links *)

				END
			END
		END LinkClicked;

		(* Returns the position of the label in text *)
		PROCEDURE FindLabel*(CONST label : ARRAY OF CHAR; VAR pos : LONGINT): BOOLEAN;
		VAR ch : LONGINT;
			found : BOOLEAN;
		BEGIN
			found := FALSE; pos := 0;
			text.AcquireRead;
			utilreader.SetDirection(1); utilreader.SetPosition(pos);
			REPEAT
				utilreader.ReadCh(ch);
				IF ch = Texts.LabelChar THEN
					IF utilreader.object(Texts.LabelPiece).label^ = label THEN
						found := TRUE;
					END;
				END;
				INC(pos);
			UNTIL utilreader.eot OR found;
			text.ReleaseRead;
			RETURN found;
		END FindLabel;

		(* Drag away operations *)
		PROCEDURE AutoStartDrag*;
		VAR img : WMGraphics.Image;
			c : WMGraphics.BufferCanvas;
			w, h, i, la, lb, top : LONGINT;
			l : LineInfo;
		BEGIN
			text.AcquireRead;
			selection.Sort;
			NEW(dragSelA, text);NEW(dragSelB, text);
			dragSelA.SetPosition(selection.a); dragSelB.SetPosition(selection.b);

			la := Limit(layout.FindLineNrByPos(selection.a), 0, layout.GetNofLines() - 1);
			lb := Limit(layout.FindLineNrByPos(selection.b), 0, layout.GetNofLines() - 1);
			(* estimate the size of the selection *)
			h := 0; w := 0;
			FOR i := la TO lb DO
				h := h + (layout.lines[i].height);
				w := Strings.Max(w, layout.lines[i].width);
			END;
			h := Limit(h, 20, 200);
			w := Limit(w, 20, 400);

			(* render to bitmap *)
			NEW(img); Raster.Create(img, w, h, Raster.BGRA8888);
			NEW(c, img);
			top := 0;
			(* hack the startpos of the first line *)
			l := layout.lines[la]; l.pos := selection.a;
			IF la = lb THEN RenderLine(c, l, la, top, selection.b - selection.a)
			ELSE
				RenderLine(c, l, la, top, -1);
				top := top + l.height
			END;

			FOR i := la + 1 TO lb DO
				IF i = lb THEN
					RenderLine(c, layout.lines[i], i, top, selection.b - layout.lines[i].pos)
				ELSE
					RenderLine(c, layout.lines[i], i, top, -1);
					top := top + (l.height)
				END
			END;
			text.ReleaseRead;

			IF StartDrag(NIL, img, 0,0,DragWasAccepted, NIL) THEN
			ELSE KernelLog.String("WMTextView : Drag could not be started")
			END;
		END AutoStartDrag;
		PROCEDURE DragWasAccepted(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			targetText, temp : Texts.Text;
			string : Strings.String;
			pos, a, b, res : LONGINT;
		BEGIN
			IF (dragSelA = NIL) OR (dragSelB = NIL)  THEN RETURN END;

			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget)
				ELSE RETURN
				END
			ELSE RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				targetText := itf(WMDropTarget.DropText).text;
				IF targetText # NIL THEN
					targetText.AcquireWrite;
					IF ~dragCopy THEN
						IF TraceCopy IN Trace THEN KernelLog.String("WMTextView: Not copy"); KernelLog.Ln; END;
						text.AcquireWrite;
						a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
						pos := itf(WMDropTarget.DropText).pos.GetPosition();
						IF (targetText # text) OR (pos < a) OR (pos > b) THEN
							NEW(temp); temp.AcquireWrite; temp.CopyFromText(text, a, b-a, 0);	temp.ReleaseWrite;
							text.Delete(a, b- a);
							pos := itf(WMDropTarget.DropText).pos.GetPosition();
							temp.AcquireRead;
							targetText.CopyFromText(temp, 0, temp.GetLength(), pos);
							temp.ReleaseRead;
						END;
						text.ReleaseWrite
					ELSE
						IF TraceCopy IN Trace THEN KernelLog.String("WMTextView: Copy"); KernelLog.Ln; END;
						text.AcquireRead;
						pos := itf(WMDropTarget.DropText).pos.GetPosition();
						a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
						targetText.CopyFromText(text, a, b-a, pos);
						text.ReleaseRead;
					END;
					targetText.ReleaseWrite
				END;
				RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeString);
			IF (itf # NIL) THEN
				IF ~dragCopy THEN
					text.AcquireWrite;
					a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
					NEW(temp);
					temp.AcquireWrite;
					temp.CopyFromText(text, a, b-a, 0);
					IF (temp.GetLength() > 0) THEN NEW(string, temp.GetLength() * 5); ELSE NEW(string, 1); string[0] := 0X; END;
					temp.ReleaseWrite;
					text.ReleaseWrite;
					TextUtilities.TextToStr(temp, string^);
					itf(WMDropTarget.DropString).Set(string^, res);
					IF res = 0 THEN
					text.AcquireWrite;
					text.Delete(a, b- a);
					text.ReleaseWrite;
					END;
				ELSE
					text.AcquireRead;
					a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
					NEW(temp);
					temp.AcquireWrite;
					temp.CopyFromText(text, a, b-a, 0);
					IF (temp.GetLength() > 0) THEN NEW(string, temp.GetLength() * 5); ELSE NEW(string, 1); string[0] := 0X; END;
					temp.ReleaseWrite;
					text.ReleaseRead;
					TextUtilities.TextToStr(temp, string^);
					itf(WMDropTarget.DropString).Set(string^, res);
				END;
			END;
		END DragWasAccepted;

		(* Drag onto operations *)
		PROCEDURE DragOver(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR pos : LONGINT;
		BEGIN
			IF takesFocus.Get() THEN
				text.AcquireRead;
				ViewToTextPos(x, y, pos);
				cursor.SetVisible(TRUE);
				cursor.SetPosition(pos);
				StoreLineEnter;
				text.ReleaseRead
			END;
		END DragOver;

		PROCEDURE DragDropped*(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dropTarget : TextDropTarget;
			pos, internalPos : LONGINT;
			p : Texts.TextPosition;
		BEGIN
			IF takesFocus.Get() THEN
				text.AcquireRead;
				ViewToTextPos(x, y, pos)	;

				(* prevent a selection from being dropped behind the paragraph separator *)
				internalPos := GetInternalPos(pos);
				IF text.isUTF & (layout.bidiFormatter # NIL) THEN
					IF layout.bidiFormatter.IsLastCharacterInLine(internalPos) THEN
						DEC(internalPos);
					END;
				END;

				NEW(p, text); p.SetPosition(internalPos);
				NEW(dropTarget, text, p);
				text.ReleaseRead;
				IF ~hasFocus & ~alwaysShowCursorI THEN cursor.SetVisible(FALSE) END;
				dragInfo.data := dropTarget;
				ConfirmDrag(TRUE, dragInfo);
				IF dragInfo.onAccept # NIL THEN dragInfo.onAccept(SELF, dragInfo) END;
			ELSE
				ConfirmDrag(FALSE, dragInfo);
				IF dragInfo.onReject # NIL THEN dragInfo.onReject(SELF, dragInfo) END;
			END;
		END DragDropped;

		PROCEDURE CopySelection*;
		BEGIN
			IF isPassword.Get() THEN RETURN END;
			text.AcquireRead;
			Texts.clipboard.AcquireWrite;
			selection.Sort;
			IF selection.b - selection.a > 0 THEN
				(* clear the clipboard *)
				IF Texts.clipboard.GetLength() > 0 THEN Texts.clipboard.Delete(0, Texts.clipboard.GetLength()) END;
				Texts.clipboard.CopyFromText(text, selection.a, selection.b - selection.a, 0);
			END;
			Texts.clipboard.ReleaseWrite;
			text.ReleaseRead
		END CopySelection;

		PROCEDURE DeleteSelection*;
		BEGIN
			Acquire; (* protect cursor *)
			text.AcquireWrite;
			selection.Sort;
			text.Delete(selection.a, selection.b - selection.a);
			cursor.SetVisible(TRUE);
			text.ReleaseWrite;
			Release;
		END DeleteSelection;

		PROCEDURE Paste*;
		BEGIN
			text.AcquireWrite;
			Texts.clipboard.AcquireRead;
			IF Texts.clipboard.GetLength() > 0 THEN
				IF selection.b - selection.a # 0 THEN DeleteSelection() END;
				text.CopyFromText(Texts.clipboard, 0, Texts.clipboard.GetLength(), cursor.GetPosition())
			END;
			Texts.clipboard.ReleaseRead;
			text.ReleaseWrite
		END Paste;

		PROCEDURE SelectAll*;
		BEGIN
			Acquire; (* protect cursor *)
			text.AcquireRead;
			selection.SetFromTo(0, text.GetLength());
			cursor.SetVisible(text.GetLength() <= 0);
			Texts.SetLastSelection(text, selection.from, selection.to);
			text.ReleaseRead;
			Release;
		END SelectAll;

		(* Prepare to start the selection by keyboard. Clear the selection, if it is not contigous *)
		PROCEDURE KeyStartSelection(pos : LONGINT);
		BEGIN
			IF selection.to.GetPosition() # pos THEN selection.SetFromTo(pos, pos); cursor.SetVisible(TRUE); Texts.ClearLastSelection END;
		END KeyStartSelection;

		(* update the keyboard selection with the new position, redraw from the last StartSelection *)
		PROCEDURE KeyUpdateSelection(pos : LONGINT);
		BEGIN
			selection.SetTo(pos);
			selection.Sort;
			cursor.SetVisible(selection.b - selection.a <= 0);
			Texts.SetLastSelection(text, selection.from, selection.to)
		END KeyUpdateSelection;

		PROCEDURE CursorChanged;
		BEGIN
			cursorBlinker.Show(cursor);
			IF (onCursorChanged # NIL) THEN onCursorChanged END
		END CursorChanged;

		PROCEDURE CursorUp*(select : BOOLEAN);
		VAR
			pos, cPos, cl, lineStart : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;

			cl := layout.FindLineNrByPos(pos);
			IF cl > 0 THEN
				DEC(cl);
				lineStart := layout.GetLineStartPos(cl);
				cPos := lineStart + Strings.Min(layout.GetLineLength(cl) - 1, lineEnter);
				cursor.SetPosition(cPos);
				IF cl < firstLineI THEN firstLine.Set(cl) END
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()));
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END CursorUp;

		PROCEDURE CursorDown*(select : BOOLEAN);
		VAR pos, cPos, cl, lineStart : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;

			cl := layout.FindLineNrByPos(pos);
			IF cl < layout.GetNofLines() - 1 THEN
				INC(cl);
				lineStart := layout.GetLineStartPos(cl);
				cPos := lineStart + Strings.Min(layout.GetLineLength(cl) - 1, lineEnter);

				cursor.SetPosition(cPos);
				IF cl > FindLineByY(firstLineI, bounds.GetHeight() - bordersI.b) THEN firstLine.Set(firstLineI + 1 ) END
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END CursorDown;

		(* Move the cursor one character/word to the left *)
		PROCEDURE CursorLeft*(word, select : BOOLEAN);
		VAR
			pos, cPos, wPos : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			PositionDebugging.SetPos(GetInternalPos(cursor.GetPosition()),cursor.GetPosition());
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			cPos := GetInternalPos(cursor.GetPosition()) - 1;
			IF ~word THEN
				cursor.SetPosition(GetDisplayPos(cPos));
			ELSE
				wPos := TextUtilities.FindPosWordLeft(utilreader, cPos);
				cursor.SetPosition(GetDisplayPos(wPos));
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			StoreLineEnter;
			text.ReleaseRead;
			Release;
			CursorChanged
		END CursorLeft;

		(* Move the cursor one character/word to the right *)
		PROCEDURE CursorRight*(word, select : BOOLEAN);
		VAR
			pos, cPos, wPos : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			PositionDebugging.SetPos(GetInternalPos(cursor.GetPosition()),cursor.GetPosition());
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			cPos := GetInternalPos(cursor.GetPosition()) + 1;
			IF ~word THEN
				cursor.SetPosition(GetDisplayPos(cPos));
			ELSE
				wPos := TextUtilities.FindPosWordRight(utilreader, cPos);
				cursor.SetPosition(GetDisplayPos(wPos));
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			StoreLineEnter;
			text.ReleaseRead;
			Release;
			CursorChanged
		END CursorRight;

		PROCEDURE PageDown*(select : BOOLEAN);
		VAR dy : LONGINT; i, pos, iPos : LONGINT;
			cx, cy : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			iPos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(iPos)
			ELSE
				selection.SetFromTo(iPos, iPos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			IF firstLineI = layout.GetNofLines() - 1  THEN
				cursor.SetPosition(text.GetLength());
			ELSE
				(* save cursor screen pos for repositioning *)
				IF ~FindScreenPos(cursor.GetPosition(), cx, cy) THEN cx := 0; cy := 0 END;
				i := firstLineI; dy := 0;
				WHILE (i < layout.GetNofLines() - 1) & (dy < bounds.GetHeight() - bordersI.t - bordersI.b) DO
					INC(i); dy := dy + (layout.lines[i].height)
				END;
				firstLine.Set(i);
				(* set cursor to nearest pos on new page *)
				ViewToTextPos(cx, cy, pos);
				IF pos >= 0 THEN
					cursor.SetPosition(pos);
				END;
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END PageDown;

		PROCEDURE PageUp*(select : BOOLEAN);
		VAR dy : LONGINT; i, pos, iPos : LONGINT;
			cx, cy : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			iPos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(iPos)
			ELSE
				selection.SetFromTo(iPos, iPos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			IF firstLineI = 0 THEN
				cursor.SetPosition(0);
			ELSE
				(* save cursor screen pos for repositioning *)
				IF ~FindScreenPos(cursor.GetPosition(), cx, cy) THEN cx := 0; cy := 0 END;
				(* go up one page but at least one page *)
				i := firstLineI; dy := 0;
				WHILE (i > 0) & (dy < bounds.GetHeight() - bordersI.t - bordersI.b) DO
					DEC(i); dy := dy + (layout.lines[i].height)
				END;
				IF (i > 0) & (i = firstLineI) THEN DEC(i) END;
				firstLine.Set(i);
				(* set cursor to nearest pos on new page *)
				ViewToTextPos(cx, cy, pos);
				IF pos >= 0 THEN
					cursor.SetPosition(pos);
				END
			END;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END PageUp;

		PROCEDURE Home*(ctrl, select : BOOLEAN);
		VAR
			lineStart, cl, pos : LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			IF ctrl THEN
				cursor.SetPosition(GetDisplayPos(0));
				firstLine.Set(0)
			ELSE
				cl := layout.FindLineNrByPos(cursor.GetPosition());
				lineStart := layout.GetLineStartPos(cl);

				cursor.SetPosition(GetDisplayPos(lineStart));
			END;
			StoreLineEnter;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END Home;

		PROCEDURE End*(ctrl, select : BOOLEAN);
		VAR lineEnd, textLength, cl, pos, dispPos: LONGINT;
		BEGIN
			Acquire;
			text.AcquireRead;
			pos := GetInternalPos(cursor.GetPosition());
			IF select THEN
				KeyStartSelection(pos)
			ELSE
				selection.SetFromTo(pos, pos);
				cursor.SetVisible(TRUE);
				Texts.ClearLastSelection
			END;
			IF ctrl THEN
				textLength := text.GetLength();

				cursor.SetPosition(GetDisplayPos(textLength));
				firstLine.Set(layout.FindLineNrByPos(text.GetLength()))
			ELSE
				cl := layout.FindLineNrByPos(cursor.GetPosition());
				lineEnd := layout.GetLineStartPos(cl) + layout.GetLineLength(cl) - 1;
				dispPos := GetDisplayPos(lineEnd);
				cursor.SetPosition(dispPos);
			END;

			StoreLineEnter;
			IF select THEN
				KeyUpdateSelection(GetInternalPos(cursor.GetPosition()))
			END;
			text.ReleaseRead;
			Release;
			CursorChanged
		END End;

		PROCEDURE KeyEvent*(ucs :LONGINT; flags : SET; VAR keysym : LONGINT);
		BEGIN
			modifierFlags := flags;
			IF Inputs.Release IN flags THEN RETURN END;
			dragCopy := modifierFlags * Inputs.Ctrl # {};
			IF keysym = 01H THEN (* Ctrl-A *)
				SelectAll
			ELSIF keysym = 03H THEN (* Ctrl-C *)
				CopySelection
 			ELSIF (keysym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
				CopySelection
			ELSIF keysym = 12H THEN (* Ctrl-R *)
				layout.FullLayout(TRUE); Invalidate;CheckNumberOfLines;
				KernelLog.String("Refreshed"); KernelLog.Ln;
			ELSIF keysym = 0FF51H THEN (* Cursor Left *)
				CursorLeft(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keysym = 0FF53H THEN (* Cursor Right *)
				CursorRight(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keysym = 0FF54H THEN (* Cursor Down *)
				CursorDown(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF52H THEN (* Cursor Up *)
				CursorUp(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF56H THEN (* Page Down *)
				PageDown(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF55H THEN (* Page Up *)
				PageUp(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF50H THEN (* Cursor Home *)
				Home(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keysym = 0FF57H THEN (* Cursor End *)
				End(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			END
		END KeyEvent;

		(* called by users that override the KeyEvents to allow copy drag drop *)
		PROCEDURE SetFlags*(flags : SET);
		BEGIN
			modifierFlags := flags;
			dragCopy := modifierFlags * Inputs.Ctrl # {};
		END SetFlags;

		PROCEDURE FindCommandRange*(pos: LONGINT; VAR start, end, nofLastSelections : LONGINT);
		VAR ch : LONGINT; string : ARRAY 23 OF CHAR; i : LONGINT; sDoCommands, lastWasTilde : BOOLEAN;
			escapeString: ARRAY 32 OF LONGINT; escapePos: LONGINT; escape: BOOLEAN;

			(* note: this simple algorithm can be emplyed if  the substring to be implicitly searched for does not contain its first character *)
			PROCEDURE String(escape: BOOLEAN; CONST escapeString: ARRAY OF LONGINT);
			VAR done: BOOLEAN; escapePos: LONGINT;
			BEGIN
				done := FALSE; escapePos := -1;
				REPEAT
					utilreader.ReadCh(ch);
					IF ch = ORD('"') THEN
						IF escape THEN
							escapePos := 0;
						ELSE
							 done := TRUE
						END;
					ELSIF escapePos >= 0 THEN
						IF escapeString[escapePos] = 0 THEN
							IF ch =ORD("\") THEN done := TRUE
							ELSE escapePos := -1
							END;
						ELSIF escapeString[escapePos] # ch THEN
							escapePos := -1;
						ELSE
							INC(escapePos);
						END;
					END;
				UNTIL done OR utilreader.eot;
			END String;

		BEGIN
			nofLastSelections := 0;
			text.AcquireRead;
			utilreader.SetDirection(-1); utilreader.SetPosition(pos);
			REPEAT	utilreader.ReadCh(ch) UNTIL TextUtilities.IsWhiteSpace(ch,text.isUTF) OR utilreader.eot;
			start := utilreader.GetPosition() + 2;
			IF utilreader.eot THEN DEC(start, 2) END;
			(* search ~ *)
			i := 0; sDoCommands := FALSE; lastWasTilde := FALSE;
			utilreader.SetDirection(1); utilreader.SetPosition(start);
			REPEAT
				utilreader.ReadCh(ch);

				IF ch = ORD('"') THEN
					escapeString[escapePos] := 0;
					String(escape, escapeString);
				ELSIF ch =ORD("\") THEN
					escape := TRUE;
					escapePos := 0;
				ELSIF escape THEN
					IF TextUtilities.IsWhiteSpace(ch,text.isUTF) THEN escape := FALSE
					ELSE escapeString[escapePos] := ch; INC(escapePos);
					END;
				END;

				(* check whether the command is SystemTools.DoCommands *)
				IF (i < 22) THEN
					string[i] := CHR(ch);
					INC(i);
					IF (i = 22) THEN
						string[22] := 0X;
						IF (string = "SystemTools.DoCommands") OR Strings.StartsWith2("PreliminaryCommands",string) THEN
							sDoCommands := TRUE;
						END;
					END;
				END;

				IF (CHR(ch) = "^") THEN
					INC(nofLastSelections);
				END;

				(* We do a special treatment of the command SystemTools.DoCommands since we don't want a single
				tilde character to delimit the parameter string for the particular command - but two tilde characters *)
				IF sDoCommands THEN
					IF (ch = ORD("~")) THEN
						IF ~lastWasTilde THEN
							lastWasTilde := TRUE;
							utilreader.ReadCh(ch);
						ELSE
							(* Two tilde characters only separated with whitespace means this is the
							end of the SystemTools.DoCommands parameter string *)
						END;
					ELSIF lastWasTilde & ~TextUtilities.IsWhiteSpace(ch,text.isUTF)  THEN
						lastWasTilde := FALSE;
					END;
				END;
			UNTIL (ch = ORD("~")) OR (utilreader.eot);
			end := utilreader.GetPosition() - 1;
			IF utilreader.eot THEN INC(end) END;
			text.ReleaseRead
		END FindCommandRange;

		PROCEDURE FindCommand*(pos: LONGINT; VAR start, end : LONGINT);
		VAR ch : LONGINT;
		BEGIN
			text.AcquireRead;
			utilreader.SetDirection(-1); utilreader.SetPosition(pos);
			REPEAT utilreader.ReadCh(ch) UNTIL TextUtilities.IsWhiteSpace(ch,text.isUTF) OR utilreader.eot;
			start := utilreader.GetPosition() + 2;
			IF utilreader.eot THEN DEC(start, 2) END;

			utilreader.SetDirection(1); utilreader.SetPosition(pos);
			REPEAT utilreader.ReadCh(ch) UNTIL TextUtilities.IsWhiteSpace(ch,text.isUTF) OR utilreader.eot;
			end := utilreader.GetPosition() - 1;
			IF utilreader.eot THEN INC(end) END;
			text.ReleaseRead;
		END FindCommand;

		(**	Start the command in the text, starting on pos (or wordboundary before),
			caller should hold lock on text  to make the pos stable *)
		PROCEDURE StartCommand*(pos : LONGINT; openFile : BOOLEAN);
		VAR
			start, end, bufSize : LONGINT;
			context : Commands.Context;
			arg : Streams.StringReader;
			command : ARRAY MaxCommandLength OF CHAR;
			parameters : POINTER TO ARRAY OF CHAR;
			s : Strings.String;
			msg : ARRAY 128 OF CHAR;
			ignore : Modules.Name;
			paramSize, nofLastSelections, i, j, a, b, res : LONGINT;
			selectionText : Texts.Text;
			selectionOk : BOOLEAN;
			from, to: Texts.TextPosition;
			commandCaller:OBJECT;
			commandWriter, errorWriter: Streams.Writer;
		BEGIN
			Acquire;
			text.AcquireRead;
			IF openFile THEN FindCommand(pos, start, end)
			ELSE FindCommandRange(pos, start, end, nofLastSelections)
			END;
			bufSize := Strings.Max(Strings.Min((end - start) * 5 + 1 (* for UTF *), MaxCallParameterBuf), 1);
			NEW(s, bufSize);
			paramSize := 0;
			TextUtilities.SubTextToStrAt(text, start, end - start, paramSize, s^);
			INC(paramSize);

			text.ReleaseRead;
			Release;
			IF  Inputs.Shift * modifierFlags # {} THEN
				 (*
				 	Command / open will not see the caller => called as if no calling context was specified.
				 	=> Opening a text while holding a shift key down will usually result in a new viewer being opened.
				 *)
				commandCaller := NIL
			ELSE
				commandCaller := SELF.commandCaller;
			END;

			IF openFile THEN
				FileHandlers.OpenFile(s^, NIL, commandCaller)
			ELSE
				command := "";
				i := 0;
				WHILE (i < MaxCommandLength) & (s[i] # 0X) & (s[i] # ";") & (s[i] # " ") & (s[i] # 09X) & (s[i] # 0DX) & (s[i] # 0AX) DO
					command[i] := s[i]; INC(i);
				END;

				IF i < MaxCommandLength THEN
					command[i] := 0X;
					INC(i);
					Commands.Split(command, ignore, ignore, res, msg);
					IF res # Commands.Ok THEN
						KernelLog.String("WMTextView: Command parsing error, res: "); KernelLog.Int(res, 0);
						KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")"); KernelLog.Ln;
						RETURN;
					END;
				ELSE
					KernelLog.String("WMTextView: Command execution error: Command too long"); KernelLog.Ln;
					RETURN;
				END;

				IF (Inputs.Alt * modifierFlags # {}) THEN
					(* execute AltMMCommand with actual command and its parameters as parameter *)
					COPY(AltMMCommand, command);
					commandWriter := NIL; errorWriter := NIL;
					i := 0;
				ELSE
					commandWriter := SELF.commandWriter;
					errorWriter := SELF.errorWriter;
				END;

				IF (i < LEN(s)) THEN (* copy parameter string *)
					selectionOk := FALSE;
					IF (nofLastSelections > 0) THEN
						IF Texts.GetLastSelection(selectionText, from, to) THEN
							selectionOk := TRUE;
							selectionText.AcquireRead;
							a := Strings.Min(from.GetPosition(), to.GetPosition());
							b := Strings.Max(from.GetPosition(), to.GetPosition());
							INC(paramSize, b - a + 1);
						END;
					END;
					NEW(parameters, paramSize);
					j := 0;
					WHILE (i < LEN(s)) & (j < LEN(parameters)-1) DO
						IF (s[i] = "^") & selectionOk THEN
							TextUtilities.SubTextToStrAt(selectionText, a, b - a, j, parameters^);
						ELSE
							parameters[j] := s[i]; INC(j);
						END;
						INC(i);
					END;
					parameters[j] := 0X;
					IF selectionOk THEN
						selectionText.ReleaseRead;
					END;
				ELSE
					NEW(parameters, 1); parameters[0] := 0X;
				END;

				NEW(arg, LEN(parameters)); arg.SetRaw(parameters^, 0, LEN(parameters));
				NEW(context, NIL, arg, commandWriter, errorWriter, commandCaller);

				IF TraceCommands IN Trace THEN
					KernelLog.String("WMTextView: Executing command: '"); KernelLog.String(command); KernelLog.String("'");
					KernelLog.String(", parameters: ");
					IF (parameters[0] =  0X)  THEN KernelLog.String("None"); ELSE KernelLog.String("'"); KernelLog.String(parameters^); KernelLog.String("'"); END;
					KernelLog.Ln;
				END;
				Commands.Activate(command, context, {}, res, msg);
				IF (res # Commands.Ok) THEN
					IF commandWriter # NIL THEN
						commandWriter.String("WMTextView: Command execution error, res: "); commandWriter.Int(res, 0);
						commandWriter.String(" ("); commandWriter.String(msg); commandWriter.String(")"); commandWriter.Ln;
						commandWriter.Update;
					ELSE
						KernelLog.String("WMTextView: Command execution error, res: "); KernelLog.Int(res, 0);
						KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")"); KernelLog.Ln;
					END;
				END;
			END;
		END StartCommand;

		PROCEDURE Start(sender, data: ANY);
		VAR msg: ARRAY 512 OF CHAR; res: LONGINT;
		BEGIN
			IF (data # NIL) & (data IS ClickInfo) THEN
				IF data(ClickInfo).cmdPar # NIL THEN
					Commands.Call(data(ClickInfo).cmdPar^, {}, res, msg);
					IF res # 0 THEN KernelLog.String("WMTextView: "); KernelLog.String(msg); KernelLog.Ln END;
				END
			END
		END Start;

		PROCEDURE Open(sender, data: ANY);
		BEGIN
			IF (data # NIL) & (data IS ClickInfo) THEN
				IF data(ClickInfo).cmd # NIL THEN
					FileHandlers.OpenFile(data(ClickInfo).cmd^, NIL, commandCaller)
				END
			END
		END Open;

		PROCEDURE PieMenuStart(sender, data: ANY);
		BEGIN
			Start(piemenu, piemenu.userData)
		END PieMenuStart;

		PROCEDURE PieMenuOpen(sender, data: ANY);
		BEGIN
			Open(piemenu, piemenu.userData)
		END PieMenuOpen;

		PROCEDURE PieMenuCopy(sender, data: ANY);
		BEGIN
			CopySelection;
		END PieMenuCopy;

		PROCEDURE PieMenuPaste(sender, data: ANY);
		BEGIN
			Paste;
		END PieMenuPaste;

		PROCEDURE ShowContextMenu(x, y: LONGINT);
		VAR
			popup : WMPopups.Popup;
			start, end, bufSize : LONGINT;
			command, s : Strings.String;
			clickInfo : ClickInfo;
			str : ARRAY 256 OF CHAR;
			window : WMWindowManager.Window;
			nofLastSelections : LONGINT;
		BEGIN
			ASSERT(IsCallFromSequencer());
			text.AcquireRead;
			FindCommand(cursor.GetPosition(), start, end);
			bufSize := Strings.Max(Strings.Min((end - start) * 5 + 1 (* for UTF *), 4096), 1);
			NEW(command, bufSize);
			TextUtilities.SubTextToStr(text, start, end - start, command^);

			FindCommandRange(cursor.GetPosition(), start, end, nofLastSelections);
			bufSize := Strings.Max(Strings.Min((end - start) * 5 + 1 (* for UTF *), MaxCallParameterBuf), 1);
			NEW(s, bufSize);
			TextUtilities.SubTextToStr(text, start, end - start, s^);
			text.ReleaseRead;

			NEW(clickInfo);
			clickInfo.cmd := command;
			clickInfo.cmdPar := s;

			IF UsePieMenu THEN
				NEW(piemenu); piemenu.SetEnabled({0, 1, 2, 3});
				piemenu.SetText(1, Strings.NewString("Open"));
				piemenu.SetText(3, Strings.NewString("Start"));
				piemenu.SetText(2, Strings.NewString("Copy"));
				piemenu.SetText(0, Strings.NewString("Paste"));

				piemenu.userData := clickInfo;

				piemenu.on1.Add(PieMenuOpen);
				piemenu.on2.Add(PieMenuCopy);
				piemenu.on3.Add(PieMenuStart);
				piemenu.on0.Add(PieMenuPaste);

				manager := WMWindowManager.GetDefaultManager();
				window := manager.GetPositionOwner(x, y);
				IF window = NIL THEN RETURN END;

				Acquire; ToWMCoordinates(x, y, x, y); Release;
				piemenu.Show(window, x, y, FALSE);
				(* TODO: Can't set  := NIL, since its used by the button handlers *)
			ELSE
				NEW(popup);
				str := "Start "; Strings.Append(str, command^); popup.AddParButton(str, Start, clickInfo);
				str := "Open "; Strings.Append(str, command^); popup.AddParButton(str, Open, clickInfo);
				Acquire; ToWMCoordinates(x, y, x, y); Release;
				popup.Popup(x, y);
			END
		END ShowContextMenu;

		PROCEDURE HandleInternal(VAR x: WMMessages.Message);
		VAR pos : LONGINT; obj : ANY; link : Texts.Link;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (x.msgType = WMMessages.MsgKey) & objHasFocus THEN (* forward KeyMsg *)
				WITH focusObject : WMComponents.VisualComponent DO
					focusObject.Handle(x);
					InvalidateRange(focusPos, focusPos+1)
				END
			ELSIF (x.msgType # WMMessages.MsgKey) & HitObject(x.x, x.y, pos, obj) THEN (* forward Msg *)
				SetFocus; cursor.SetVisible(FALSE);
				IF obj IS WMComponents.VisualComponent THEN
					WITH obj : WMComponents.VisualComponent DO
						(* remove oldObject first *)
						IF (oldObject # NIL) & (oldObject # obj) THEN
							oldObject(WMComponents.VisualComponent).Handle(x);
							InvalidateRange(oldPos, oldPos+1);
						END;

						TransformCoordinates(x.x, x.y, obj);		(* transform to obj coords *)
						obj.Handle(x);								(* call obj Handle *)
						ChangePointer(obj.GetPointerInfo());		(* change the pointer Image *)
						InvalidateRange(pos, pos+1);				(* redraw obj *)
						oldObject := obj; oldPos := pos;			(* store last object *)
						(* transfer focus to Object *)
						IF (x.msgType = WMMessages.MsgPointer) & (x.flags * {0, 1, 2} = {0}) THEN
							(* remove old focus first *)
							IF (focusObject # NIL) & (focusObject # obj) THEN
								focusObject(WMComponents.VisualComponent).FocusLost;
								InvalidateRange(focusPos, focusPos+1)
							END;

							objHasFocus := TRUE;
							focusObject := obj; focusPos := pos;
(*							FocusLost *)
						END
					END
				END
			ELSIF (x.msgType = WMMessages.MsgPointer) & HitLink(x.x, x.y, pos, link) THEN (* Link *)
				ChangePointer(manager.pointerLink);
				IF (x.msgSubType = 2) &(oldFlags / x.flags =  {CallURLPointer}) THEN LinkClick(link); END;
				oldFlags := x.flags;
			ELSE
				ChangePointer(manager.pointerText);	 (* change Pointer back *)
				(* transfer focus back to TextView *)
				IF (focusObject # NIL) & (x.msgType = WMMessages.MsgPointer) & (x.flags * {0, 1, 2} = {0}) THEN
					focusObject(WMComponents.VisualComponent).FocusLost;
					objHasFocus := FALSE;
					InvalidateRange(focusPos, focusPos+1);
					FocusReceived;
					focusObject := NIL
				END;
				(* update last Object *)
				IF (oldObject # NIL) & (x.msgType = WMMessages.MsgPointer) THEN
					oldObject(WMComponents.VisualComponent).Handle(x);
					InvalidateRange(oldPos, oldPos+1);
					oldObject := NIL
				END;
				IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS Texts.StyleChangedMsg) THEN
					layout.FullLayout(TRUE); Invalidate; CheckNumberOfLines;
				ELSE
					HandleInternal^(x);
				END;
			END
		END HandleInternal;

	END TextView;

TYPE

	FontEntry = OBJECT
	VAR
		name : ARRAY 256 OF CHAR;
		attributes : FontAttributes;
		next : FontEntry;

		PROCEDURE &Init(CONST name : ARRAY OF CHAR);
		BEGIN
			COPY(name, SELF.name);
			attributes := NIL;
			next := NIL;
		END Init;
	END FontEntry;

	FontAttributes = OBJECT
	VAR
		font : WMGraphics.Font; (* { font # {} *)
		size : LONGINT;
		style : SET;
		next : FontAttributes;

		PROCEDURE &Init(size : LONGINT; style : SET);
		BEGIN
			font := NIL;
			SELF.size := size;
			SELF.style := style;
			next := NIL;
		END Init;

	END FontAttributes;

	(* not thread-safe! not global to avoid locking and keep size smaller *)
	FontCache = 	OBJECT
	VAR
		entries : FontEntry;
		defaultFont : WMGraphics.Font;

		PROCEDURE &Init;
		BEGIN
			NEW(entries, "head"); (* head of list *)
			defaultFont := WMGraphics.GetDefaultFont();
		END Init;

		PROCEDURE Find(CONST name : ARRAY OF CHAR; size : LONGINT; style : SET) : WMGraphics.Font;
		VAR font : WMGraphics.Font; e : FontEntry; a : FontAttributes;
		BEGIN
			font := NIL;
			e := entries.next;
			WHILE (e # NIL ) & (e.name < name) DO e := e.next; END;
			IF (e # NIL) & (e.name = name) THEN
				a := e.attributes;
				WHILE (a # NIL) & (a.size < size) DO a := a.next; END;
				WHILE (a # NIL) & (a.size = size) & (a.style # style) DO a := a.next; END;
				IF (a # NIL) & (a.size = size) THEN
					ASSERT(a.font # NIL);
					font := a.font;
				END;
			END;
			RETURN font;
		END Find;

		PROCEDURE Add(CONST name : ARRAY OF CHAR; size : LONGINT; style : SET) : WMGraphics.Font;
		VAR entry, e : FontEntry; attribute, a : FontAttributes;
		BEGIN
			e := entries;
			WHILE (e.next # NIL) & (e.next.name < name) DO e := e.next; END;
			IF (e.next # NIL) & (e.next.name = name) THEN
				entry := e.next;
			ELSE
				NEW(entry, name);
				entry.next := e.next;
				e.next := entry;
			END;
			ASSERT(entry # NIL);

			NEW(attribute, size, style);
			attribute.font := WMGraphics.GetFont(name, size, style);

			IF (entry.attributes = NIL) THEN
				entry.attributes := attribute;
			ELSIF (entry.attributes.size >= attribute.size) THEN
				attribute.next := entry.attributes;
				entry.attributes := attribute;
			ELSE
				a := entry.attributes;
				WHILE (a.next # NIL) & (a.next.size < attribute.size) DO a := a.next; END;
				attribute.next := a.next;
				a.next := attribute;
			END;

			ASSERT(attribute.font # NIL);
			RETURN attribute.font;
		END Add;

		(* Get specified font. If not available, the system default font is returned *)
		PROCEDURE GetFont(CONST name : ARRAY OF CHAR; size : LONGINT; style : SET) : WMGraphics.Font;
		VAR font : WMGraphics.Font;
		BEGIN
			font := Find(name, size, style);
			IF (font = NIL) THEN
				font := Add(name, size, style);
			END;
			ASSERT(font # NIL);
			RETURN font;
		END GetFont;

	END FontCache;

VAR
	manager : WMWindowManager.WindowManager;
	cursorBlinker- : CursorBlinker;

	PTVIsMultiLine, PTVIsPassword, PTVShowBorder, PTValwaysShowCursor, PTVShowLabels : WMProperties.BooleanProperty;
	PTVAllowCommandExecution, PTVAllowTextSelection, PTVAllowPiemenu : WMProperties.BooleanProperty;
	PTVWrapMode, PTVMouseWheelScrollSpeed, PVTtextAlignV : WMProperties.Int32Property;
	PTVfirstLine, PTVleftShift, PTVPasswordChar : WMProperties.Int32Property;
	PTVdefaultTextColor, PTVdefaultTextBgColor : WMProperties.ColorProperty;
	PTVborders : WMProperties.RectangleProperty;
	PTVonLinkClick, PTVonLinkClickInfo : Strings.String;
	PTVonCtrlLinkClick, PTVonCtrlLinkClickInfo : Strings.String;
	PTVShowLineNumbers, PTVIndicateTabs : WMProperties.BooleanProperty;
	PTVHighlighting : WMProperties.StringProperty;
	PTVLineNumberColor, PTVLineNumberBgColor, PTVclBgCurrentLine : WMProperties.ColorProperty;
	currentTextView : TextView;

	StrTextView : Strings.String;

	DefaultStyle : POINTER TO RECORD END;

PROCEDURE Limit(x, min, max : LONGINT) : LONGINT;
BEGIN
	IF x < min THEN x := min END;
	IF x > max THEN x := max END;
	RETURN x
END Limit;

PROCEDURE GetFontFromAttr(info : Texts.FontInfo) : WMGraphics.Font;
BEGIN
	RETURN WMGraphics.GetFont(info.name, info.size, info.style);
END GetFontFromAttr;

PROCEDURE IsSameFont(f1, f2 : WMGraphics.Font) : BOOLEAN;
BEGIN
	RETURN (f1 = f2) OR ((f1 # NIL) & (f2 # NIL) & (f1.size  = f2.size) & (f1.style = f2.style) & (f1.name = f2.name));
END IsSameFont;

PROCEDURE CheckFont(style : SyntaxHighlighter.Style; font : WMGraphics.Font; VAR fontCache : FontCache);
VAR fontname : ARRAY 256 OF CHAR; fontsize : LONGINT; fontstyle : SET;
BEGIN
	ASSERT(style # NIL);
	IF (fontCache = NIL) THEN NEW(fontCache); END;
	IF (style.defined * SyntaxHighlighter.FontMask = SyntaxHighlighter.FontMask) OR (font = NIL) THEN
		COPY(style.attributes.fontInfo.name, fontname);
		fontsize := style.attributes.fontInfo.size;
		fontstyle := style.attributes.fontInfo.style;
	ELSIF (font # NIL) THEN
		IF (SyntaxHighlighter.FontName IN style.defined) THEN COPY(style.attributes.fontInfo.name, fontname); ELSE COPY(font.name, fontname); END;
		IF (SyntaxHighlighter.FontSize IN style.defined) THEN fontsize := style.attributes.fontInfo.size; ELSE fontsize := font.size; END;
		IF (SyntaxHighlighter.FontStyle IN style.defined) THEN fontstyle := style.attributes.fontInfo.style; ELSE fontstyle := font.style; END;
	END;
	IF (style.attributes.fontInfo.fontcache = NIL) OR ~IsSameFont(style.attributes.fontInfo.fontcache (WMGraphics.Font), font) THEN
		style.attributes.fontInfo.fontcache := fontCache.GetFont(fontname, fontsize, fontstyle);
	END;
	ASSERT(style.attributes.fontInfo.fontcache # NIL);
END CheckFont;

PROCEDURE InitStrings;
BEGIN
	StrTextView := Strings.NewString("TextView");
	PTVonLinkClick := Strings.NewString("Link Click Event");
	PTVonLinkClickInfo := Strings.NewString("fired when a link is pressed");
	PTVonCtrlLinkClick := Strings.NewString("Ctrl Click Event");
	PTVonCtrlLinkClickInfo := Strings.NewString("fired when Ctrl pressend and clicked");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PTVIsMultiLine, NIL, Strings.NewString("multiLine"), Strings.NewString("defines if more than one line is visible"));
	PTVIsMultiLine.Set(TRUE);
	NEW(PTVShowBorder, NIL, Strings.NewString("ShowBorder"), Strings.NewString("show border"));
	PTVShowBorder.Set(FALSE);
	NEW(PTVIsPassword, NIL, Strings.NewString("password"),
		Strings.NewString("defines if the view is a password text. Characters are replaced by passwordChar"));
	NEW(PTVPasswordChar, NIL, Strings.NewString("passwordChar"),
		Strings.NewString("character that is the placeholder for a character in a password"));
	PTVPasswordChar.Set(43);
	NEW(PTValwaysShowCursor, NIL, Strings.NewString("alwaysShowCursor"),
		Strings.NewString("set to true, if the cursor should not be hidden when focus is lost"));
	PTValwaysShowCursor.Set(FALSE);
	NEW(PTVShowLabels, NIL, Strings.NewString("ShowLabels"),
		Strings.NewString("set to true, if the labels should be shown in the text"));
	PTVShowLabels.Set(FALSE);
	NEW(PTVMouseWheelScrollSpeed, NIL, Strings.NewString("MouseWheelScrollSpeed"),
		Strings.NewString("Multiplier for mouse wheel, 0 to disable mouse wheel scrolling"));
	PTVMouseWheelScrollSpeed.Set(3);
	NEW(PTVAllowCommandExecution, NIL, Strings.NewString("allowCommandExecution"),
		Strings.NewString("if set to true, middle-clicked words are executed as command"));
	PTVAllowCommandExecution.Set(TRUE);
	NEW(PTVAllowTextSelection, NIL, Strings.NewString("allowTextSelection"),
		Strings.NewString("is the user allowed to select text using the mouse?"));
	PTVAllowTextSelection.Set(TRUE);
	NEW(PTVAllowPiemenu, NIL, Strings.NewString("allowPiemenu"),
		Strings.NewString("if set to true, a mouse right-click opens the pie menu"));
	PTVAllowPiemenu.Set(TRUE);
	NEW(PTVWrapMode, NIL, Strings.NewString("wrapMode"), Strings.NewString("Set text wrapping mode"));
	PTVWrapMode.Set(WrapWord);
	NEW(PTVfirstLine, NIL, Strings.NewString("firstLine"),
		Strings.NewString("the first visible line of text in the view"));
	PTVfirstLine.Set(0);
	NEW(PTVleftShift, NIL, Strings.NewString("leftShift"),
		Strings.NewString("how many pixels the text in the view is shifted to the left"));
	 PTVleftShift.Set(0);
	NEW(PTVdefaultTextColor, NIL, Strings.NewString("defaultTextColor"),
		Strings.NewString("the color of a text that does not explicitly specify a color"));
	PTVdefaultTextColor.Set(0FFH);
	NEW(PTVdefaultTextBgColor, NIL, Strings.NewString("defaultTextBgColor"),
		Strings.NewString("The color of a text background if not specified otherwise in the text"));
	PTVdefaultTextBgColor.Set(0);
	NEW(PTVborders, NIL, Strings.NewString("borders"),
		Strings.NewString("spaces from bounds of the component to the text"));
	PTVborders.Set(WMRectangles.MakeRect(5, 5, 5, 5));
	NEW(PTVIndicateTabs, NIL, Strings.NewString("IndicateTabs"), Strings.NewString("Indicate tabs?"));
	PTVIndicateTabs.Set(FALSE);
	NEW(PTVShowLineNumbers, NIL, Strings.NewString("ShowLineNumbers"), Strings.NewString("Show line numbers?"));
	PTVShowLineNumbers.Set(FALSE);
	NEW(PTVLineNumberColor, NIL, Strings.NewString("LineNumberColor"), Strings.NewString("Color of line numbers"));
	PTVLineNumberColor.Set(WMGraphics.Black);
	NEW(PTVLineNumberBgColor, NIL, Strings.NewString("LineNumberBgColor"), Strings.NewString("Background color of line numbers"));
	PTVLineNumberBgColor.Set(0CCCCCCFFH);
	NEW(PTVHighlighting, NIL, Strings.NewString("Highlighting"), Strings.NewString("Name of highlighting to be applied"));
	PTVHighlighting.Set(NIL);
	NEW(PTVclBgCurrentLine, NIL, Strings.NewString("ClBgCurrentLine"), Strings.NewString("Background color of currently edited line"));
	PTVclBgCurrentLine.Set(0);
	NEW(PVTtextAlignV, NIL, Strings.NewString("TextAlignV"), Strings.NewString("vertical Text Alignment"));
	PVTtextAlignV.Set(WMGraphics.AlignTop);
END InitPrototypes;


PROCEDURE EnablePiemenu*;
BEGIN
	PTVAllowPiemenu.Set( TRUE );
	KernelLog.String( "Piemenu enabled" );  KernelLog.Ln
END EnablePiemenu;

PROCEDURE DisablePiemenu*;
BEGIN
	PTVAllowPiemenu.Set( FALSE );
	KernelLog.String( "Piemenu disabled" );  KernelLog.Ln
END DisablePiemenu;


PROCEDURE TextViewFactory*() : XML.Element;
VAR e : TextView;
BEGIN
	NEW(e); RETURN e
END TextViewFactory;

(* Inserts a ocharacter from the outside into the current textView's text at its current position *)
PROCEDURE InsertChar*(newChar : Char32) : INTEGER;
BEGIN
	IF currentTextView # NIL THEN
		RETURN currentTextView.InsertChar(newChar);
	ELSE
		RETURN -3;
	END;
END InsertChar;

PROCEDURE Refresh*;
BEGIN
	IF currentTextView # NIL THEN
		currentTextView.layout.FullLayout(TRUE);
		currentTextView.Invalidate;
		currentTextView.CheckNumberOfLines;
	END;
END Refresh;

PROCEDURE Cleanup;
BEGIN
	cursorBlinker.Finalize;
END Cleanup;

PROCEDURE GenTextView*(): XML.Element;
VAR e : TextView;
BEGIN
	NEW(e); RETURN e
END GenTextView;


BEGIN
	NEW(cursorBlinker);
	NEW(DefaultStyle);
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
	InitPrototypes;
	manager := WMWindowManager.GetDefaultManager();
END WMTextView.