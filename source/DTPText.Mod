MODULE DTPText; (** AUTHOR "PL"; PURPOSE "Text Plugin for DTPEditor"; *)

IMPORT
	KernelLog, Modules, Inputs, Streams, Files, XML, WMGrids,
	WMStandardComponents, WMGraphics, WMGraphicUtilities, WMDropTarget, WMStringGrids,
	WMComponents, WMRectangles, WMDialogs, WMProperties, WMRasterScale,
	WMEditors, Strings, TextUtilities, Texts, XMLObjects, UTF8Strings,
	WMWindowManager, Raster, DTPEditor, DTPData, DTPUtilities;

CONST
	pluginVersion = 1.00;
	pluginName = "Text";
	pluginDesc = "Text Plugin for DTPEditor";
	point = 0.3527777778;						(* 1/72 inch *)

	TraceRenderOptimize = 0;
	TraceLayout = 1;
	TraceBaseLine = 2;
	TraceInvalidate = 3;
	Trace = { };

	Wrap* = 0; WrapWord* = 1;
	AlignLeft = 0; AlignCenter = 1; AlignRight = 2; AlignJustified = 3;

	HLOver* = 0; HLUnder* = 1; HLWave* = 2;

	DragDist = 5;

	CR = 0DX; LF = 0AX;
VAR

TYPE
	Char32 = Texts.Char32;
	String = Strings.String;

	Image* = OBJECT
	VAR
		image* : WMGraphics.Image;
		file* : String;
	END Image;

	TabStops* = OBJECT
	VAR tabDist : LONGINT;
		(* return the next TabStop from the x position *)
		PROCEDURE GetNextTabStop*(x : LONGINT) : LONGINT;
		BEGIN
			RETURN ((x DIV tabDist) + 1) * tabDist
		END GetNextTabStop;
	END TabStops;

	LineInfo = RECORD
		height, ascent, spaceSize : REAL;
		width : LONGINT;
		pos : LONGINT; (* the position in the text, where this line starts *)
		align : LONGINT;
		flags : SET;
		tabStops : TabStops;
		firstInParagraph, lastInParagraph, lastInText: BOOLEAN;
		eotSize: LONGINT;
		leading, firstIndent, leftIndent, rightIndent, spaceBefore, spaceAfter: REAL;
	END;

	LineInfoArray = POINTER TO ARRAY OF LineInfo;

	Layout = OBJECT
	VAR
		nofLines : LONGINT;
		lines : LineInfoArray;
		text : Texts.Text;
		paperWidth: LONGINT;
		textWidth : LONGINT; (* maximal width of the text <= textWidth *)
		textHeight : LONGINT;
		realHeight, realWidth: REAL;
		layoutLineProc : PROCEDURE {DELEGATE} (VAR pos : LONGINT; VAR lineInfo : LineInfo; lineNr, wrapWidth, stopPos, stopXPos : LONGINT; fcur: BOOLEAN);

		PROCEDURE &New*;
		BEGIN
			NEW(lines, 4)
		END New;

		(** Replace the text *)
		PROCEDURE SetText*(t : Texts.Text);
		BEGIN
			text := t
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
		VAR a, b, m: LONGINT;
		BEGIN
			a := 0; b := nofLines - 1;
			WHILE (a < b) DO m := (a + b) DIV 2;
				IF lines[m].pos <= pos THEN a := m + 1
				ELSE b := m
				END
			END;
			(* last line hack *)
			IF lines[a].pos <= pos THEN INC(a) END;
(*			i := 0; WHILE (i < nofLines) & (lines[i].pos <= pos) DO INC(i) END;
			IF a - 1 # i - 1 THEN
				KernelLog.String("OffByOne"); KernelLog.String("a - 1 = "); KernelLog.Int(a - 1, 0); KernelLog.String(" i - 1 = "); KernelLog.Int(i - 1, 0); KernelLog.Ln;
			END; *)
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

		PROCEDURE LayoutLine(VAR pos : LONGINT; VAR lineInfo : LineInfo; currentLine: LONGINT);
		BEGIN
			IF layoutLineProc # NIL THEN layoutLineProc(pos, lineInfo, currentLine, paperWidth, -1, -1, FALSE) END
		END LayoutLine;

		(* generate a new layout from scratch *)
		PROCEDURE FullLayout(startpos, startline: LONGINT);
		VAR i, pos, oldpos : LONGINT;
		BEGIN
			IF text = NIL THEN RETURN END;
			textWidth := 0;
			ASSERT(lines#NIL);
			text.AcquireRead;
			IF TraceLayout IN Trace THEN KernelLog.String("FullLayout"); KernelLog.Ln END;
			i := 0;
			pos := startpos; nofLines := startline;
			textHeight := 0; realHeight := 0;
			WHILE pos < text.GetLength() DO
				oldpos := pos;
				(* KernelLog.String("LineNR: "); KernelLog.Int(nofLines, 0); KernelLog.Ln; *)
				LayoutLine(pos, lines[nofLines], nofLines);
				realHeight := realHeight + lines[nofLines].height; textHeight := ENTIER(realHeight);
				textWidth := ENTIER(DTPUtilities.Max(textWidth, lines[nofLines].width));
				ASSERT(pos > oldpos);
				IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
				(* lines[nofLines].align := AlignLeft; *)
				INC(nofLines); IF nofLines >= LEN(lines) THEN GrowLines END
			END;
			IF TraceLayout IN Trace THEN KernelLog.String("FullLayout found "); KernelLog.Int(nofLines, 4); KernelLog.String(" lines"); KernelLog.Ln END;
			text.ReleaseRead
		END FullLayout;

		(** Fix the layouting of the text starting at pos where delta characters have been inserted (delta negativ if deleted) *)
		PROCEDURE FixLayoutFrom(pos, delta : LONGINT; VAR first, last : LONGINT; VAR linesChanged : BOOLEAN; firstpos, firstline: LONGINT);
		VAR l, dl : LONGINT;
			oldh, tempHeight: REAL;
		BEGIN
			ASSERT(text#NIL);
			text.AcquireRead;
			linesChanged := FALSE;
			l := FindLineNrByPos(pos);
			(* KernelLog.String("Linenr: "); KernelLog.Int(l, 0); KernelLog.Ln; *)
			(* KernelLog.String("RealHeight: "); DTPUtilities.OutReal(realHeight, 4); KernelLog.Ln; *)
			IF (l < 0) THEN FullLayout(firstpos, firstline); first := 0; last := nofLines; text.ReleaseRead; RETURN END;
			pos := lines[l].pos;
			oldh := lines[l].height;
			LayoutLine(pos, lines[l], l);
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
					(*	KernelLog.String("Line: "); KernelLog.Int(l, 0);
						IF (l>=LEN(lines)) THEN KernelLog.String("height: NIL") ELSE KernelLog.String("height: "); DTPUtilities.OutReal(lines[l].height,4); END;
						KernelLog.Ln;
					*)	IF (l >= LEN(lines)) THEN tempHeight := 0.0 ELSE tempHeight := lines[l].height; END;
						realHeight := realHeight -  tempHeight;
						LayoutLine(pos, lines[l], l);
						textWidth := ENTIER(DTPUtilities.Max(textWidth, lines[l].width));
						realHeight := realHeight + lines[nofLines].height;
						INC(dl);
						IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
						INC(l); IF l >= LEN(lines) THEN GrowLines END;
					END;
					textHeight := ENTIER(realHeight);
					nofLines := l ;
					last := nofLines - 1
				END
			ELSE
				WHILE (pos < text.GetLength()) & (lines[l].pos + delta # pos)  DO
					linesChanged := TRUE;
					realHeight := realHeight - lines[l].height;
					LayoutLine(pos, lines[l], l);
					textWidth := ENTIER(DTPUtilities.Max(textWidth, lines[l].width));
					realHeight := realHeight + lines[nofLines].height;
					INC(dl);
					IF TraceLayout IN Trace THEN KernelLog.String("Line from : "); KernelLog.Int(lines[nofLines].pos, 5); KernelLog.Ln END;
					INC(l); IF l >= LEN(lines) THEN GrowLines END;
				END;
				textHeight := ENTIER(realHeight);
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

	Highlight* = OBJECT
	VAR
		kind : LONGINT;
		from*, to* : Texts.TextPosition;
		a*, b* : LONGINT; (* only valid after sort, while holding the lock *)
		active* : BOOLEAN; (* only valid after sort, while holding the lock *)
		oldFrom, oldTo : LONGINT;
		color : WMGraphics.Color;
		text : Texts.UnicodeText;
		(* onChanged : WMMessages.CompCommand; *)
		onChanged* : PROCEDURE {DELEGATE} (sender, data: ANY);
		owner : TextObject;

		PROCEDURE &New*;
		BEGIN
			color := 0FF80H
		END New;

		PROCEDURE SetOwner(owner : TextObject);
		BEGIN
			SELF.owner := owner;
			onChanged := owner.HighlightChanged;
		END SetOwner;

		PROCEDURE SetKind*(kind : LONGINT);
		BEGIN
			IF SELF.kind # kind THEN
				SELF.kind := kind;
				onChanged(SELF, NIL)
			END
		END SetKind;

		PROCEDURE SetColor*(color : WMGraphics.Color);
		BEGIN
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


	PositionMarker* = OBJECT
	VAR
		pos : Texts.TextPosition;

		img : WMGraphics.Image;
		str : String;
		color : WMGraphics.Color;

		hotX, hotY : LONGINT;
		currentArea : WMRectangles.Rectangle;
		ascent : LONGINT;
		text : Texts.UnicodeText;
		(* onChanged : WMMessages.CompCommand; *)
		visible : BOOLEAN;

		onChanged : PROCEDURE {DELEGATE} (sender, data: ANY);
		owner : TextObject;

		PROCEDURE SetOwner(owner : TextObject);
		BEGIN
			SELF.owner := owner;
			onChanged := owner.PositionMarkerChanged;
		END SetOwner;

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
			IF img # NIL THEN hotX := img.width DIV 2; hotY := img.height END;
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
				onChanged(SELF, NIL);
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
			IF text # NIL THEN SELF.text := text; NEW(pos, text); END
		END SetText;
	END PositionMarker;

	PositionMarkerArray = POINTER TO ARRAY OF PositionMarker;

TYPE TextDropTarget* = OBJECT(WMDropTarget.DropTarget);
	VAR text : Texts.Text;
		pos : Texts.TextPosition;

		PROCEDURE &New*(text : Texts.Text; pos : Texts.TextPosition);
		BEGIN
			SELF.text := text; SELF.pos := pos
		END New;

(*		PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : WMDropTarget.DropText;
		BEGIN
			IF type = WMDropTarget.TypeText THEN
				NEW(di); di.text := text; di.pos := pos;
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;
*)
	END TextDropTarget;

CONST
	vAlignTop = 0; vAlignCenter = 1; vAlignBottom = 2; vAlignJustified = 3;

TYPE
	TextObject* = OBJECT(DTPData.ContentObject);
	VAR text : Texts.Text;

		properties: WMProperties.PropertyList;
		props: TextPropWindow;

		firstLine* : WMProperties.Int32Property;
		firstLineI* : LONGINT;
		firstPos* : LONGINT;
		firstIsFirstInP*: BOOLEAN;

		chainNext* : TextObject;
		chainPrev* : TextObject;
		chainNextN* : ARRAY 128 OF CHAR;
		chainPrevN* : ARRAY 128 OF CHAR;
		vAlign* : LONGINT;

		showBorders : BOOLEAN;
		bordersI, borderClip : WMRectangles.Rectangle;
		borders* : WMProperties.RectangleProperty;
		bounds* : WMProperties.RectangleProperty;

		layout : Layout;
		utilreader : Texts.TextReader; (* single process ! *)
		firstInParagraph: BOOLEAN;
		jSpaceSize : REAL;

		defaultTextColor*, defaultTextBgColor* : LONGINT;
		defaultAttr : Texts.Attributes;
		(* default style ?? *)
		defaultFont : WMGraphics.Font;
		fStyle : Texts.CharacterStyle;
		fZoom : REAL;

		(* wrapping *)
		wrap : SET;

		clipState : WMGraphics.CanvasState;

		defaultTabStops : TabStops;

		(* highlighting *)
		nofHighlights : LONGINT;
		highlights : HighlightArray;

		(* marked positions *)
		nofPositionMarkers : LONGINT;
		positionMarkers : PositionMarkerArray;

		cursor- : PositionMarker;
		selection- : Highlight;
		selecting : BOOLEAN;

		dragPossible : BOOLEAN;
		dragSelA, dragSelB : Texts.TextPosition;
		dragCopy : BOOLEAN;

		downX, downY : LONGINT;
		selectWords : BOOLEAN;
		wordSelOrdered : BOOLEAN;
		lineEnter : LONGINT;
		modifierFlags : SET;

		i : LONGINT;
		quality : BOOLEAN;
		preview : BOOLEAN;

	PROCEDURE &New*;
		BEGIN
			NEW(properties);
			NEW(props, SELF); vAlign := 0;
			NEW(firstLine, PTVfirstLine, NIL, NIL); properties.Add(firstLine);
			NEW(borders, PTVborders, NIL, NIL); properties.Add(borders);
			NEW(bounds, PTVbounds, NIL, NIL); properties.Add(bounds);

			NEW(layout);
			layout.layoutLineProc := LayoutLine;
			NEW(defaultAttr);
			NEW(defaultTabStops); defaultTabStops.tabDist := 20;
			NEW(highlights, 4); nofHighlights := 0;
			NEW(positionMarkers, 4); nofPositionMarkers := 0;
			NEW(text); SetText(text);
			cursor := CreatePositionMarker();
			showBorders := FALSE;
			selection := CreateHighlight();
			selection.kind := HLOver;
			selection.color := 0000FF80H;
			wrap := { WrapWord };
			(* properties *)
			(* firstLineI := 0; *)
			firstPos := 0;
			defaultTextColor := 0000000FFH;
			defaultTextBgColor := LONGINT(0FFFFFF00H);
			quality := TRUE;
			preview := FALSE;
			firstInParagraph := FALSE;
			(* RecacheProperties *)
		END New;

		PROCEDURE ClickHandler*(sender, data: ANY);
		BEGIN
			Redraw;
		END ClickHandler;

		PROCEDURE Clone*(): DTPData.ContentObject;			(* clone all the current properties *)
		VAR newObj: TextObject;
		BEGIN
			NEW(newObj); newObj.contentName := Strings.NewString(contentName^);
			newObj.redrawProc := redrawProc; newObj.updatePropsPosition := updatePropsPosition;
			newObj.contentWidth := contentWidth; newObj.contentHeight := contentHeight; newObj.zoomFactor := zoomFactor;
			newObj.ownerDoc := ownerDoc;

			(* text specific clones *)
			text.AcquireRead;
			newObj.text.AcquireWrite;
			newObj.text.CopyFromText(text, 0, text.GetLength(), 0);
			newObj.text.ReleaseWrite;
			text.ReleaseRead;

			RETURN newObj;
		END Clone;

		PROCEDURE Invalidate;
		BEGIN
			Redraw;
		END Invalidate;

		PROCEDURE InvalidateRect(rect: WMRectangles.Rectangle);
		BEGIN
			Redraw;
		END InvalidateRect;

		PROCEDURE SetFocus*(focus: BOOLEAN);
		BEGIN
			SetFocus^(focus);
			Redraw;
		END SetFocus;

		PROCEDURE FocusLost*;
		BEGIN
			FocusLost^;
			cursor.SetVisible(FALSE);
			selection.SetFromTo(0, 0); Texts.ClearLastSelection;
			Redraw;
		END FocusLost;

		PROCEDURE FocusReceived*;
		BEGIN
			FocusReceived^;
			cursor.SetVisible(TRUE);
			Redraw;
		END FocusReceived;

		PROCEDURE GetPluginPointer*(): WMWindowManager.PointerInfo;
		VAR manager : WMWindowManager.WindowManager;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			RETURN manager.pointerText;
		END GetPluginPointer;

		PROCEDURE BordersChanged;
		BEGIN
			borderClip := WMRectangles.MakeRect(bordersI.l, bordersI.t, bounds.GetWidth() - bordersI.r, bounds.GetHeight() - bordersI.b);
			layout.paperWidth := bounds.GetWidth() - (bordersI.l + bordersI.r);
			layout.FullLayout(firstPos, firstLineI); CheckNumberOfLines;
		END BordersChanged;

		PROCEDURE SetSize(w, h: LONGINT);
		VAR obj: TextObject;
		BEGIN
			SetSize^(w, h);
			(* KernelLog.Int(w, 0); KernelLog.String(" : "); KernelLog.Int(h, 0); KernelLog.Ln; *)
			bounds.SetExtents(w, h);
			layout.paperWidth := bounds.GetWidth() - (bordersI.l + bordersI.r);
			borderClip.r := bounds.GetWidth() - bordersI.r; borderClip.b := bounds.GetHeight() - bordersI.b;
			layout.FullLayout(firstPos, firstLineI); CheckNumberOfLines;
			(* update frames in chain.. *)
			obj := chainNext;
			WHILE (obj # NIL) DO
				obj.Update;
				obj := obj.chainNext;
			END;
		END SetSize;

		PROCEDURE Resize(zoom : REAL);
		BEGIN
			Resize^(zoom);
			(* layout.FullLayout; CheckNumberOfLines; *)
			(* Invalidate; *)
		END Resize;

		PROCEDURE ChainUpdate*;
		VAR obj: TextObject;
		BEGIN
			obj := chainNext;
			WHILE (obj # NIL) DO
				obj.Update;
				obj := obj.chainNext;
			END;
		END ChainUpdate;

		PROCEDURE Update*;
		BEGIN
			layout.FullLayout(firstPos, firstLineI); CheckNumberOfLines;
			Invalidate;
		END Update;

		(** Replace the text *)
		PROCEDURE SetText*(t : Texts.Text);
		VAR i : LONGINT;
		BEGIN
			ASSERT(t # NIL);
			(* Acquire; *)
			IF text # NIL THEN text.onTextChanged.Remove(TextChanged) END;  (* unregister the TextChanged listener from the old text *)
			text := t;
			text.onTextChanged.Add(TextChanged); (* register the TextChanged listener with the new text*)
			NEW(utilreader, text);
			(* update all highlights *)
			FOR i := 0 TO nofHighlights - 1 DO highlights[i].SetText(text) END;
			FOR i := 0 TO nofPositionMarkers - 1 DO positionMarkers[i].SetText(text) END;
			layout.SetText(text);
			layout.FullLayout(firstPos, firstLineI);
			CheckNumberOfLines;
			(* Invalidate; *)
			(* Release *)
		END SetText;

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
			HighlightChanged(NIL, NIL);
		END AddHighlight;

		PROCEDURE CreateHighlight*() : Highlight;
		VAR h : Highlight;
		BEGIN
			(* Acquire; *)
			NEW(h); h.SetText(text);
			h.onChanged := HighlightChanged;
			AddHighlight(h);
			(* Release; *)
			RETURN h
		END CreateHighlight;

		PROCEDURE RemoveHighlight*(x : Highlight);
		VAR i : LONGINT;
		BEGIN
			(* Acquire; *)
			i := 0; WHILE (i < nofHighlights) & (highlights[i] # x) DO INC(i) END;
			IF i < nofHighlights THEN
				WHILE (i < nofHighlights - 1) DO highlights[i] := highlights[i+1]; INC(i) END;
				DEC(nofHighlights);
				highlights[nofHighlights] := NIL
			END;
			HighlightChanged(NIL, NIL);
			(* Release *)
		END RemoveHighlight;

		PROCEDURE InvalidateRange(a, b : LONGINT);
		VAR t, l0, l1 : LONGINT; x0, y0, x1, y1, d : LONGINT;
		BEGIN
			IF a > b THEN t := a; a := b; b := t END;

			l0 := layout.FindLineNrByPos(a);
			l1 := layout.FindLineNrByPos(b);
			IF l0 = l1 THEN (* only one line... optimize *)
				LineYPos(l0, y0, y1);
				IF ~(FindScreenPos(a, x0, d) & FindScreenPos(b, x1, d)) THEN
					x0 := 0; x1 := bounds.GetWidth()
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

				text.AcquireRead;
				IF (sender # NIL) & (sender IS Highlight) THEN
					hl := sender(Highlight);
					IF (hl.oldFrom # hl.from.GetPosition()) & (hl.oldTo # hl.to.GetPosition()) THEN (* both changed *)
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
			(* Acquire; *)
			NEW(p); p.SetText(text);
			p.onChanged := PositionMarkerChanged;
			AddPositionMarker(p);
			(* Release; *)
			RETURN p
		END CreatePositionMarker;

		PROCEDURE RemovePositionMarker*(x : PositionMarker);
		VAR i, xp, yp, l : LONGINT; newRect : WMRectangles.Rectangle;
		BEGIN
			(* Acquire; *)
			i := 0; WHILE (i < nofPositionMarkers) & (positionMarkers[i] # x) DO INC(i) END;
			IF i < nofPositionMarkers THEN
				WHILE (i < nofPositionMarkers - 1) DO positionMarkers[i] := positionMarkers[i+1]; INC(i) END;
				DEC(nofPositionMarkers);
				positionMarkers[nofPositionMarkers] := NIL
			END;
			IF FindScreenPos(x.pos.GetPosition(), xp, yp) THEN
				l := layout.FindLineNrByPos(x.pos.GetPosition());
				IF (l < LEN(layout.lines^)) & (l >= 0) THEN
					newRect := x.GetArea(xp, yp, ENTIER(layout.lines[l].ascent));
					InvalidateRect(newRect)
				END
			END;
			(* Release *)
		END RemovePositionMarker;

		PROCEDURE PositionMarkerChanged(sender, data : ANY);
		VAR newRect, combinedRect : WMRectangles.Rectangle; x, y, l : LONGINT;
		BEGIN

				data := sender;
				IF (data # NIL) & (data IS PositionMarker) THEN
					IF data = cursor THEN CheckCursor END;
					text.AcquireRead;
					IF FindScreenPos(data(PositionMarker).pos.GetPosition(), x, y) THEN
						l := layout.FindLineNrByPos(data(PositionMarker).pos.GetPosition());
(*						KernelLog.String("Position: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
						KernelLog.String("Line: "); KernelLog.Int(l, 0); KernelLog.Ln;
*)						IF (l < LEN(layout.lines^)) & (l >= 0) THEN
							newRect := data(PositionMarker).GetArea(x, y, ENTIER(layout.lines[l].ascent))
						END
					END;

					combinedRect := data(PositionMarker).currentArea;
					IF WMRectangles.RectEmpty(combinedRect) THEN combinedRect := newRect
					ELSE WMRectangles.ExtendRect(combinedRect, newRect)
					END;
(*					KernelLog.String("Posii+: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)					IF ~WMRectangles.RectEmpty(combinedRect) THEN
						IF (WMRectangles.Area(data(PositionMarker).currentArea) + WMRectangles.Area(newRect)) * 5 <  WMRectangles.Area(combinedRect) THEN
(*							KernelLog.String("Posii++: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)							InvalidateRect(data(PositionMarker).currentArea);
(*							KernelLog.String("Posii+1: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)							InvalidateRect(newRect);
(*							KernelLog.String("Posii+2: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)						ELSE
(*							KernelLog.String("Posii+3: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)							InvalidateRect(combinedRect);
(*							KernelLog.String("Posii+4: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)						END
					END;
					text.ReleaseRead;
				ELSE
(*					KernelLog.String("Posii+5: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)					Invalidate; KernelLog.String("Editor: XXX")
				END;
(*				KernelLog.String("Posii+++: "); KernelLog.Int(data(PositionMarker).pos.GetPosition(), 0); KernelLog.Ln;
*)

		END PositionMarkerChanged;
(* END PositionMarkers *)

		PROCEDURE CheckNumberOfLines;
		BEGIN
			firstLine.SetBounds(0, layout.GetNofLines() - 1)
		END CheckNumberOfLines;

		PROCEDURE CheckCursor;
		VAR cp, l, i : LONGINT; ty : REAL;
		BEGIN
			(* Scroll up, down to make cursor visible *)
			text.AcquireRead;
			cp := cursor.GetPosition();
			IF (cp < 0) THEN cursor.SetPosition(0)
			ELSIF (cp > text.GetLength()) THEN cursor.SetPosition(text.GetLength())
			END;
			l := layout.FindLineNrByPos(cursor.GetPosition());
			IF (l < firstLineI) THEN
				(* move the cursor down by 3 lines to get more context *)
				l := Strings.Max(0, l - 3);
				firstLine.Set(l);
			ELSIF (l < layout.GetNofLines()) THEN
				ty := bordersI.t; i := firstLineI;
				WHILE i < l DO
					ty := ty + layout.lines[i].height; INC(i);
					IF layout.lines[i].firstInParagraph THEN ty := ty + layout.lines[i].spaceBefore; END;
					IF (i>0) & layout.lines[i-1].lastInParagraph THEN ty := ty + layout.lines[i-1].spaceAfter; END;
				END;
				ty := ty + layout.lines[i].height;
				IF ty >= bounds.GetHeight() - bordersI.b THEN
					l := Strings.Max(0, l - 3);
					firstLine.Set(l)
				END
			END;
			text.ReleaseRead;
			(* Scroll left right to make cursor visible *)
			(* $$$ TODO *)
		END CheckCursor;

		PROCEDURE TextChanged(sender, data : ANY);
		VAR f, l, t, b, i, h: LONGINT; linesChanged : BOOLEAN;
			info : Texts.TextChangeInfo;
			realT, realB: REAL;
		BEGIN
				IF (data # NIL) & (data IS Texts.TextChangeInfo) & (data(Texts.TextChangeInfo).op # Texts.OpMulti) THEN
					text.AcquireRead;
					(* Acquire; *)
					info := data(Texts.TextChangeInfo);
					IF text.GetTimestamp() = info.timestamp THEN
						info := data(Texts.TextChangeInfo);
						IF info.op = Texts.OpInsert THEN layout.FixLayoutFrom(info.pos, info.len, f, l, linesChanged, firstPos, firstLineI)
						ELSE layout.FixLayoutFrom(info.pos, -info.len, f, l, linesChanged, firstPos, firstLineI)
						END;
						t := bordersI.t; realT := t;
						FOR i := firstLineI TO f - 1 DO
							realT := realT + (layout.lines[i].height);
							IF layout.lines[i].firstInParagraph THEN realT := realT + layout.lines[i].spaceBefore; END;
							IF (i>0) & layout.lines[i-1].lastInParagraph THEN realT := realT + layout.lines[i-1].spaceAfter; END;
						END;
						t := ENTIER(realT);

						h := bounds.GetHeight();
						IF linesChanged THEN b := h ELSE
							b := t; i := f;
							WHILE (i <= l) & (b < h) DO
								realB := realB + (layout.lines[i].height);
								IF layout.lines[i].firstInParagraph THEN realB := realB + layout.lines[i].spaceBefore; END;
								IF (i>0) & layout.lines[i-1].lastInParagraph THEN realB := realB + layout.lines[i-1].spaceAfter; END;
								INC(i);
							END;
							b := ENTIER(realB);
						END;
						CheckCursor; (* UpdateScrollbars; *)
						(* Release; *)
						InvalidateRect(WMRectangles.MakeRect(0, t, bounds.GetWidth(), b));
					ELSE
						IF TraceRenderOptimize IN Trace THEN KernelLog.String("Timestamp not equal ==> Complete re_layout"); KernelLog.Ln
						END;
						layout.FullLayout(firstPos, firstLineI);
						CheckCursor;
						(* InvalidateRect(GetClientRect()) *)
						Invalidate;
					END;
					text.ReleaseRead
				ELSE
					layout.FullLayout(firstPos, firstLineI);
					CheckCursor;
					(* InvalidateRect(GetClientRect()) *)
					Invalidate;
				END;
				CheckNumberOfLines;

		END TextChanged;

(* BEGIN view dependant layout functions *)
		(** Return the left indent of a line - depending on alignment *)
		(* returns left border, in case of errors *)
		PROCEDURE GetLineLeftIndent(linenr : LONGINT): LONGINT;
		VAR result, boundsWidth: REAL;
		BEGIN
			IF (linenr < 0) OR (linenr >= layout.nofLines) THEN RETURN 0 END;
			(* KernelLog.Int(layout.lines[linenr].align, 0); *)
			(* KernelLog.String("bounds: "); KernelLog.Int(bounds.GetWidth(), 0); KernelLog.Ln; *)
			CASE layout.lines[linenr].align OF
				AlignLeft :		result := 0;
				|AlignRight : 	IF layout.lines[linenr].lastInText THEN
									result := (bounds.GetWidth() - (layout.lines[linenr].width)+layout.lines[linenr].eotSize);
								ELSE
									result := (bounds.GetWidth() - (layout.lines[linenr].width)); (* + ENTIER(layout.lines[linenr].rightIndent) *)
								END;
								result := result - layout.lines[linenr].rightIndent;
								IF (layout.lines[linenr].pos = 0) OR (layout.lines[linenr].firstInParagraph) OR ((firstPos = layout.lines[linenr].pos) & firstIsFirstInP) THEN
									result := result - layout.lines[linenr].firstIndent;
								ELSE
									result := result - layout.lines[linenr].leftIndent;
								END;
				|AlignCenter : 	boundsWidth := bounds.GetWidth() - layout.lines[linenr].rightIndent;
								IF (layout.lines[linenr].pos = 0) OR (layout.lines[linenr].firstInParagraph) THEN
									boundsWidth := boundsWidth - layout.lines[linenr].firstIndent;
								ELSE
									boundsWidth := boundsWidth - layout.lines[linenr].leftIndent;
								END;
								IF layout.lines[linenr].lastInText THEN
									result := (boundsWidth - (layout.lines[linenr].width)+layout.lines[linenr].eotSize) / 2;
								ELSE
									result := (boundsWidth - (layout.lines[linenr].width)) / 2;
								END;
			ELSE
				 result := 0;
			END;
			IF (layout.lines[linenr].pos = 0) OR (layout.lines[linenr].firstInParagraph) OR ((linenr>0) & layout.lines[linenr-1].lastInParagraph) OR ((firstPos = layout.lines[linenr].pos) & firstIsFirstInP)THEN
				result := result + layout.lines[linenr].firstIndent;
(*				KernelLog.String("firstIndent: "); DTPUtilities.OutReal(layout.lines[linenr].firstIndent, 4); KernelLog.Ln;
				KernelLog.String("line: "); KernelLog.Int(linenr, 0); KernelLog.Ln;
*)			ELSE
				result := result + layout.lines[linenr].leftIndent;
			END;
			RETURN ENTIER(result);
		END GetLineLeftIndent;

		(** Find the line number that currently contains the y value (y relative to 0 in component)*)
		PROCEDURE FindLineByY*(firstLine, y : LONGINT) : LONGINT;
		VAR i : LONGINT; ypos : REAL;
		BEGIN
			ypos := bordersI.t; i := firstLine;
			IF y < 0 THEN RETURN 0 END;
			WHILE (i < layout.nofLines) & (ypos <= y) DO
				ypos := ypos + layout.lines[i].height; INC(i);
				IF layout.lines[i].firstInParagraph THEN ypos := ypos + layout.lines[i].spaceBefore; END;
				IF (i>0) & layout.lines[i-1].lastInParagraph THEN ypos := ypos + layout.lines[i-1].spaceAfter; END;
			END;
			RETURN Strings.Max(i -1, 0)
		END FindLineByY;

		PROCEDURE ViewToTextPos*(x, y: LONGINT; VAR pos : LONGINT);
		VAR l : LONGINT; dummy : LineInfo;
			boundsWidth : REAL;
		BEGIN
			text.AcquireRead;
			pos := -1;
			x := Strings.Max(0, Strings.Min(x, bounds.GetWidth()));
			y := Strings.Max(0, Strings.Min(y, bounds.GetHeight()));

			l := FindLineByY(firstLineI, Strings.Min(Strings.Max(y, bordersI.t), bounds.GetHeight() - bordersI.b));
			(* KernelLog.String("Line: "); KernelLog.Int(l, 0); KernelLog.Ln; *)

			x := x - bordersI.l; (* + leftShiftI; *)
			IF x < 0 THEN x := 0 END;
			dummy := layout.lines[l];
			IF l >= 0 THEN
				pos := layout.GetLineStartPos(l);

				IF dummy.align = 0 THEN
					IF (pos = 0) OR dummy.firstInParagraph THEN
						LayoutLine(pos, dummy, l,layout.paperWidth, -1, x-ENTIER(dummy.firstIndent), FALSE)
					ELSE
						LayoutLine(pos, dummy, l,layout.paperWidth, -1, x-ENTIER(dummy.leftIndent), FALSE)
					END;
				ELSIF dummy.align = 1 THEN
					boundsWidth := bounds.GetWidth() - dummy.rightIndent;
					IF dummy.lastInText THEN
						boundsWidth := boundsWidth - dummy.width + dummy.eotSize;
					ELSE
						boundsWidth := boundsWidth - dummy.width;
					END;
					IF (pos = 0) OR (dummy.firstInParagraph) THEN
						boundsWidth := boundsWidth - dummy.firstIndent;
						LayoutLine(pos, dummy, l, layout.paperWidth, -1, x-(ENTIER(boundsWidth)) DIV 2-ENTIER(dummy.firstIndent), FALSE);
					ELSE
						boundsWidth := boundsWidth - dummy.leftIndent;
						LayoutLine(pos, dummy, l, layout.paperWidth, -1, x-(ENTIER(boundsWidth)) DIV 2-ENTIER(dummy.leftIndent), FALSE);
					END;
				ELSIF dummy.align = 2 THEN
					boundsWidth := bounds.GetWidth() - dummy.rightIndent;
					IF dummy.lastInText THEN
						LayoutLine(pos, dummy, l, layout.paperWidth, -1, x-(ENTIER(boundsWidth)-(dummy.width)+dummy.eotSize), FALSE)
					ELSE
						LayoutLine(pos, dummy, l, layout.paperWidth, -1, x-(ENTIER(boundsWidth)-(dummy.width)), FALSE);
					END;
				ELSE
					jSpaceSize := dummy.spaceSize;
					IF (pos = 0) OR dummy.firstInParagraph THEN
						LayoutLine(pos, dummy, l,layout.paperWidth, -1, x-ENTIER(dummy.firstIndent), TRUE);
					ELSE
						LayoutLine(pos, dummy, l,layout.paperWidth, -1, x-ENTIER(dummy.leftIndent), TRUE);
					END;
				END;

			END;
			text.ReleaseRead;
			(* KernelLog.String("Pos: "); KernelLog.Int(pos, 0); KernelLog.Ln; *)
		END ViewToTextPos;

(* END view dependant layout functions *)

		PROCEDURE GetFontFromAttr(info : Texts.FontInfo) : WMGraphics.Font;
		BEGIN
			RETURN WMGraphics.GetFont(info.name, info.size, info.style);
		END GetFontFromAttr;

		PROCEDURE GetFontFromStyle(VAR style : Texts.CharacterStyle) : WMGraphics.Font;
		VAR font : WMGraphics.Font;
		BEGIN

			IF (style.fontcache #NIL) & (style.fontcache IS WMGraphics.Font) THEN
				font := style.fontcache(WMGraphics.Font);
			ELSE
				font := WMGraphics.GetFont(style.family, ENTIER(DTPUtilities.FixpToFloat(style.size)), style.style);
				style.fontcache := font;
			END;

			RETURN font;
		END GetFontFromStyle;


		PROCEDURE LayoutLine(VAR pos : LONGINT; VAR l : LineInfo; linenr, wrapwidth, stopPos, stopXPos : LONGINT; justyfindcursor: BOOLEAN);
		VAR i, j, wrapPos: LONGINT; ch : Char32;
			f : WMGraphics.Font;
			eol, first, wrapped : BOOLEAN;
			voff, x, wrapX, align, nofSpaces: LONGINT;
			ascent, descent, realX, dx, realWX, a, d, spaceSize, spaceRSize: REAL;
			pStyle: Texts.ParagraphStyle;
			curStyle, cStyle: Texts.CharacterStyle;
			firstIndent, leftIndent, rightIndent, spaceBefore, spaceAfter, leading, leadi: REAL;

			PROCEDURE GetExtents(ch : Char32; VAR dx, ascentE, descentE: REAL);
			VAR gs : WMGraphics.GlyphSpacings; vc : WMComponents.VisualComponent;
				img : Image;
			BEGIN
				IF ch = Texts.ObjectChar THEN
					IF (utilreader.object # NIL) & (utilreader.object IS Image) THEN
						img := utilreader.object(Image);
						ascentE := (img.image.height*zoomFactor*point) - voff;
						(* KernelLog.String("ascent: "); DTPUtilities.OutReal(ascent, 4); KernelLog.Ln; *)
						descentE := voff;
						dx :=  (img.image.width*zoomFactor*point);
						leadi := (ascentE + descentE)+descent;
					ELSIF (utilreader.object # NIL) & (utilreader.object IS WMComponents.VisualComponent) THEN
						vc := utilreader.object(WMComponents.VisualComponent);
						dx := (vc.bounds.GetWidth()*zoomFactor*point);
						ascentE := (vc.bounds.GetHeight()*zoomFactor*point) - voff;
						descentE := voff;
					END
				ELSIF ch = Texts.TabChar THEN
					IF l.tabStops # NIL THEN dx := (l.tabStops.GetNextTabStop(ENTIER((x+1)/(zoomFactor*point)))*zoomFactor*point) - x
					ELSE dx := (defaultTabStops.GetNextTabStop(ENTIER((x+1)/(zoomFactor*point)))*zoomFactor*point) - x
					END;
					ascentE := (f.GetAscent()*zoomFactor*point) - voff;
					descentE := (f.GetDescent()*zoomFactor*point) + voff
				ELSE
					IF f.HasChar(ch) THEN
						f.GetGlyphSpacings(ch, gs);
(*						KernelLog.Int(f.GetAscent(), 0 ); KernelLog.Ln;
						KernelLog.Int(f.GetDescent(), 0); KernelLog.Ln;
						KernelLog.Int(voff, 0); KernelLog.Ln;
*)						ascentE := (f.GetAscent()*zoomFactor*point) - voff;
						descentE := (f.GetDescent()*zoomFactor*point) + voff;
						(* KernelLog.Int(ch, 0); KernelLog.Ln; *)
					ELSE
						WMGraphics.FBGetGlyphSpacings(ch, gs);
						ascentE := (gs.ascent*zoomFactor*point) - voff;
						descentE := (gs.descent*zoomFactor*point) + voff;
						(* KernelLog.String("FB: "); KernelLog.Int(ch, 0); KernelLog.Ln; *)
					END;
					dx := ((gs.bearing.l + gs.width + gs.bearing.r)*zoomFactor*point);
					(* KernelLog.String("Size (dx): "); KernelLog.Int(dx, 0); KernelLog.Ln; *)
				END
			END GetExtents;

		BEGIN
			f := GetFont(); (* set the default component font *)
			x := 0; realX := x;
			l.pos := pos; l.height := ENTIER(f.GetHeight()*zoomFactor*point); eol := FALSE;
			utilreader.SetDirection(1); utilreader.SetPosition(pos); first := TRUE; wrapped := FALSE;
			i := 0; ascent := (f.GetAscent()*zoomFactor*point); descent := (f.GetDescent()*zoomFactor*point);
			l.spaceBefore := 0; l.spaceAfter := 0; l.firstInParagraph := FALSE; l.lastInParagraph := FALSE;
			leading := 0; leadi := 0; l.firstIndent := 0; firstIndent := 0; leftIndent := 0; rightIndent := 0;
			nofSpaces := 0;
			utilreader.ReadCh(ch);
			IF utilreader.pstyle # NIL THEN							(* Get ParagraphStyle *)
				pStyle := utilreader.pstyle;							(* reget style, because of some mysterious error*)
				pStyle := Texts.GetParagraphStyleByName(pStyle.name);
				spaceBefore := DTPUtilities.FixpToFloat(pStyle.spaceBefore)*zoomFactor;
				spaceAfter := DTPUtilities.FixpToFloat(pStyle.spaceAfter)*zoomFactor;
				firstIndent := DTPUtilities.FixpToFloat(pStyle.firstIndent)*zoomFactor;
				leftIndent := DTPUtilities.FixpToFloat(pStyle.leftIndent)*zoomFactor;
				rightIndent := DTPUtilities.FixpToFloat(pStyle.rightIndent)*zoomFactor;
				align := pStyle.alignment;
(*				KernelLog.String(pStyle.name); KernelLog.Ln;
				DTPUtilities.OutReal(spaceBefore, 4); KernelLog.Ln;
				DTPUtilities.OutReal(spaceAfter, 4); KernelLog.Ln;
				DTPUtilities.OutReal(firstIndent, 4); KernelLog.Ln;
				DTPUtilities.OutReal(leftIndent, 4); KernelLog.Ln;
				DTPUtilities.OutReal(rightIndent, 4); KernelLog.Ln;
*)			END;
			IF (pos = 0) OR firstInParagraph OR ((linenr > 0) & layout.lines[linenr-1].lastInParagraph) OR ((firstPos = layout.lines[linenr].pos) & firstIsFirstInP)THEN
				wrapwidth := ENTIER(wrapwidth - firstIndent - rightIndent);
(*				KernelLog.String("firstIndent: "); DTPUtilities.OutReal(layout.lines[linenr].firstIndent, 4); KernelLog.Ln;
				KernelLog.String("line: "); KernelLog.Int(linenr, 0); KernelLog.Ln;
*)			ELSE
				wrapwidth := ENTIER(wrapwidth - leftIndent - rightIndent);
			END;
			IF firstInParagraph OR ((linenr>0) &layout.lines[linenr-1].lastInParagraph) THEN
				l.spaceBefore := spaceBefore;
				l.firstInParagraph := TRUE;
				firstInParagraph := FALSE;
(*				l.firstIndent := firstIndent;
				IF ~findCursor THEN
					realX := firstIndent; x := ENTIER(realX);
				END;
			ELSIF pos = 0 THEN
				l.firstIndent := firstIndent;
			ELSE
				l.firstIndent := 0;
				IF ~findCursor THEN
					realX := leftIndent; x := ENTIER(realX);
				END;
*)			END;

			REPEAT
				leadi := -1;
				IF ~first THEN utilreader.ReadCh(ch); END;
				IF utilreader.cstyle # NIL THEN							(* Get CharacterStyle *)
					cStyle := utilreader.cstyle;
					voff := ENTIER(DTPUtilities.FixpToFloat(utilreader.cstyle.baselineShift)*zoomFactor*point);
					leadi := DTPUtilities.FixpToFloat(cStyle.leading)*zoomFactor*point;

					f := GetFontFromStyle(cStyle);
(*					IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
						f := cStyle.fontcache(WMGraphics.Font);
					ELSE
						 f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
						utilreader.cstyle.fontcache := f
					END;
*)(*					 f := WMGraphics.GetFont(utilreader.cstyle.family, ENTIER(DTPUtilities.FixpToFloat(utilreader.cstyle.size)), utilreader.cstyle.style);
*)				ELSIF (pStyle # NIL) & (pStyle.charStyle # NIL) THEN									(* Get CharacterStyle from ParagraphStyle *)
					cStyle := pStyle.charStyle;

					voff := ENTIER(DTPUtilities.FixpToFloat(cStyle.baselineShift)*zoomFactor*point);
					leadi := DTPUtilities.FixpToFloat(cStyle.leading)*zoomFactor*point;
					f := GetFontFromStyle(cStyle);
(*					IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
						f := cStyle.fontcache(WMGraphics.Font);
					ELSE
						 f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
						utilreader.cstyle.fontcache := f
					END;
*)(*					f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
*)
				ELSIF utilreader.attributes # NIL THEN					(* Get Attributes *)
					voff := ENTIER(utilreader.attributes.voff*zoomFactor*point);
					IF utilreader.attributes.fontInfo # NIL THEN
						IF (utilreader.attributes.fontInfo.fontcache # NIL)
							& (utilreader.attributes.fontInfo.fontcache IS WMGraphics.Font) THEN
							f := utilreader.attributes.fontInfo.fontcache(WMGraphics.Font);
						ELSE
							f := GetFontFromAttr(utilreader.attributes.fontInfo);
							utilreader.attributes.fontInfo.fontcache := f
						END
					ELSE f := GetFont()
					END;
				ELSE voff := 0; f := GetFont();
				END;
				IF first THEN
					ascent := (f.GetAscent()*zoomFactor*point);
					descent := (f.GetDescent()*zoomFactor*point); first := FALSE;
					IF cStyle # NIL THEN leading := DTPUtilities.FixpToFloat(cStyle.leading)*zoomFactor*point ELSE leading := ascent + descent; END;
				END;
				INC(pos);
				IF (stopPos < 0) OR (pos <= stopPos) THEN
					IF ch # Texts.NewLineChar THEN
						GetExtents(ch, dx, a, d);
						(* KernelLog.String("Char: "); KernelLog.Int(ch, 0); KernelLog.Ln; *)
						IF (ch = 32) THEN
							INC(nofSpaces); DTPUtilities.Inc(spaceSize, dx);
							IF justyfindcursor THEN dx := jSpaceSize; END;
							(* KernelLog.String("space: "); DTPUtilities.OutReal(dx, 4); KernelLog.Ln; *)
							(* KernelLog.String("nofSpaces: "); KernelLog.Int(nofSpaces, 0); KernelLog.Ln; *)
						END;
						IF (leadi = -1) THEN leadi := ascent + descent; END;
						ascent := DTPUtilities.Max(ascent, a); descent := DTPUtilities.Max(descent, d);
						leading := DTPUtilities.Max(leading, leadi);
						IF (wrap # {}) & (i > 0) & (x + dx > wrapwidth) THEN
							eol := TRUE; DEC(pos); wrapPos := pos;
							(* Go left for last space *)
							IF wrap * { WrapWord } # {} THEN
								wrapped := TRUE;
								pos := TextUtilities.FindPosWordLeft(utilreader, pos);
								IF pos <= l.pos THEN pos := wrapPos END; (* no word break found. wrap at latest possible pos *)
							END
						ELSE
							IF (stopXPos >= 0) & (x + ENTIER(dx) DIV 2 > stopXPos) THEN DEC(pos); RETURN END;
							(* INC(x, dx) *)
							DTPUtilities.Inc(realX, dx);
							x := ENTIER(realX);
						END;
					ELSE eol := TRUE; IF (stopXPos >= 0) THEN DEC(pos) END;
						l.lastInParagraph := TRUE;
						l.spaceAfter := spaceAfter;
						firstInParagraph := TRUE;
						(* KernelLog.String("last in para.."); KernelLog.Ln; *)
					END;
				ELSE eol := TRUE
				END;
				INC(i)
			UNTIL eol OR utilreader.eot;
			(* KernelLog.String("Line width: "); KernelLog.Int(x, 3); KernelLog.Ln; *)
			(* KernelLog.String("Real width: "); DTPUtilities.OutReal(realX, 4); KernelLog.Ln; *)
			x := ENTIER(realX);												(* Real Fix *)
			IF utilreader.eot THEN											(* EOT Fix *)
				(* KernelLog.String("EOT: "); KernelLog.Int(ch, 0); KernelLog.String(" length: "); KernelLog.Int(dx, 0); KernelLog.Ln; *)
				l.lastInText := TRUE;
				l.eotSize := ENTIER(dx);
			ELSE
				l.lastInText := FALSE;
			END;
			IF wrapped THEN
				i := pos - l.pos;
				IF (i>1) THEN
					wrapX := 0; realWX := 0; j := 0; utilreader.SetDirection(1); utilreader.SetPosition(l.pos);
					(* KernelLog.String("startpos: "); KernelLog.Int(l.pos, 0); KernelLog.Ln; *)
					WHILE (j <i-1) DO
						utilreader.ReadCh(ch);
						(* KernelLog.String("char: "); KernelLog.Int(ch, 0); KernelLog.Ln; *)
						IF utilreader.pstyle # NIL THEN							(* Get ParagraphStyle *)
							pStyle := utilreader.pstyle;
						END;
						IF utilreader.cstyle # NIL THEN							(* Get CharacterStyle *)
							cStyle := utilreader.cstyle;
							(* KernelLog.String("cstyle # NIL"); KernelLog.Ln; *)
							voff := ENTIER(DTPUtilities.FixpToFloat(utilreader.cstyle.baselineShift)*zoomFactor*point);
							IF curStyle # cStyle THEN
								f := GetFontFromStyle(cStyle);
(*								IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
									f := cStyle.fontcache(WMGraphics.Font);
								ELSE
									 f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
									utilreader.cstyle.fontcache := f
								END;

*)(*								 f := WMGraphics.GetFont(utilreader.cstyle.family, ENTIER(DTPUtilities.FixpToFloat(utilreader.cstyle.size)), utilreader.cstyle.style);
*)							END;
							curStyle := cStyle
						ELSIF pStyle # NIL THEN									(* Get CharacterStyle from ParagraphStyle *)
							cStyle := pStyle.charStyle;
							voff := ENTIER(DTPUtilities.FixpToFloat(cStyle.baselineShift)*zoomFactor*point);
							IF curStyle # cStyle THEN
								f := GetFontFromStyle(cStyle);
(*								IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
									f := cStyle.fontcache(WMGraphics.Font);
								ELSE
									 f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
									utilreader.cstyle.fontcache := f
								END;

*)(*								f := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
*)							END;
							curStyle := cStyle
						ELSE voff := 0; f := GetFont();
						END;
						GetExtents(ch, dx, a, d);
						IF (ch = 32) & justyfindcursor THEN dx := jSpaceSize; END;
						(* KernelLog.String("adding: "); KernelLog.Int(dx, 0); KernelLog.Ln; *)
						realWX := realWX + dx;
						wrapX := ENTIER(wrapX + dx);
						INC(j);
					END;
					l.width := ENTIER(realWX);
					(* KernelLog.String("wrapped width: "); KernelLog.Int(wrapX, 0); KernelLog.Ln; *)
				ELSE
					l.width := x;
				END;
				(* KernelLog.Int(i, 0); KernelLog.String(":"); KernelLog.Int(x, 0); KernelLog.Ln; *)
			ELSE l.width := x; END;
			IF ~(l.lastInParagraph OR utilreader.eot) THEN
				utilreader.SetDirection(1); utilreader.SetPosition(pos-1); utilreader.ReadCh(ch);
			(*	KernelLog.String("LastCharInLine: "); KernelLog.Int(ch, 0); KernelLog.Ln; *)
				IF (ch = 32) THEN spaceRSize := (wrapwidth - l.width + spaceSize-(spaceSize/nofSpaces))/(nofSpaces-1);
				ELSE spaceRSize := (wrapwidth - l.width + spaceSize)/(nofSpaces); END;
(*				KernelLog.String("panelwidth: "); KernelLog.Int(wrapwidth, 0); KernelLog.Ln;
				KernelLog.String("textwidth: "); KernelLog.Int(l.width, 0); KernelLog.Ln;
				KernelLog.String("spacewidth: "); DTPUtilities.OutReal(spaceSize, 4); KernelLog.Ln;
				KernelLog.String("nofSpaces: "); KernelLog.Int(nofSpaces, 0); KernelLog.Ln;
				KernelLog.String("realSpaceWidth: "); DTPUtilities.OutReal(spaceRSize, 4); KernelLog.Ln;
*)			END;
			IF ~justyfindcursor THEN
				IF (align = 3) THEN l.spaceSize := spaceRSize; ELSE l.spaceSize := 0; END;
			END;
			l.firstIndent := firstIndent; l.leftIndent := leftIndent; l.rightIndent := rightIndent; l.align := align;
			l.ascent := ascent; l.height := leading; (* DTPUtilities.Max(leading, ascent + descent); *)
(*			KernelLog.String("Height(ascent): "); DTPUtilities.OutReal(ascent, 4); KernelLog.Ln;
			KernelLog.String("Height(descent): "); DTPUtilities.OutReal(descent, 4); KernelLog.Ln;
			KernelLog.String("Size(height): "); DTPUtilities.OutReal(ascent + descent, 4); KernelLog.Ln;
			KernelLog.String("Leading: "); DTPUtilities.OutReal(leading, 4); KernelLog.Ln;
*)			IF l.height = 0 THEN l.height := (f.GetHeight()*zoomFactor*point) END;
			(* KernelLog.Int(ascent + descent, 0);  KernelLog.Int(l.align, 0); *)
		END LayoutLine;

		PROCEDURE LineYPos(lineNr : LONGINT; VAR y0, y1 : LONGINT);
		VAR i : LONGINT;
			realY0, realY1: REAL;
		BEGIN
			IF (lineNr >= firstLineI) & (lineNr < layout.GetNofLines()) THEN
				y0 := bordersI.t; realY0:= y0; i := firstLineI;
				WHILE i < lineNr DO
					realY0 := realY0 + layout.lines[i].height; INC(i);
					IF layout.lines[i].firstInParagraph THEN realY0 := realY0 + layout.lines[i].spaceBefore; END;
					IF (i>0) & layout.lines[i-1].lastInParagraph THEN realY0 := realY0 + layout.lines[i-1].spaceAfter; END;
				END;
				realY1 := realY0 + layout.lines[i].height
			ELSE realY0 := 0; realY1 := 0;
			END;
			y0 := ENTIER(realY0); y1 := ENTIER(realY1);
		END LineYPos;

		PROCEDURE FindScreenPos*(pos : LONGINT; VAR x, y : LONGINT) : BOOLEAN;
		VAR l, i, startPos: LONGINT; ty : LONGINT; li : LineInfo; ch : Char32; lastLine : BOOLEAN;
			f : WMGraphics.Font;
			realTY: REAL;
		BEGIN
			text.AcquireRead;
			lastLine := FALSE;
			IF (pos = text.GetLength()) THEN
				utilreader.SetDirection(1); utilreader.SetPosition(text.GetLength() - 1);
				utilreader.ReadCh(ch);
				IF ch = Texts.NewLineChar THEN lastLine := TRUE END
			END;
			IF lastLine THEN
				ty := bordersI.t; realTY := ty; i := firstLineI;
				WHILE i < layout.nofLines DO
					realTY := realTY + layout.lines[i].height; INC(i);
					IF layout.lines[i].firstInParagraph THEN realTY := realTY + layout.lines[i].spaceBefore; END;
					IF (i>0) & layout.lines[i-1].lastInParagraph THEN realTY := realTY + layout.lines[i-1].spaceAfter; END;
				END;
				ty := ENTIER(realTY);
				IF i > 0 THEN y := ENTIER(realTY + layout.lines[i - 1].ascent) ELSE y := (ty + 10) END;
				x := bordersI.l; (*  - leftShiftI; *)
				text.ReleaseRead; RETURN TRUE
			ELSIF (pos = 0) & (firstLineI = 0) THEN x := bordersI.l; f := GetFont();  y := f.GetAscent(); (* x := bordersI.l - leftShiftI; *)
				text.ReleaseRead; RETURN TRUE
			ELSE
				l := layout.FindLineNrByPos(pos);
				(* KernelLog.String("Pos: "); KernelLog.Int(pos, 0); KernelLog.Ln; *)
				(* KernelLog.String("Line: "); KernelLog.Int(l, 0); KernelLog.Ln; *)
				IF (l >= firstLineI) & (l < layout.GetNofLines()) THEN
					realTY := bordersI.t; i := firstLineI;
					WHILE i < l DO
						realTY := realTY + layout.lines[i].height; INC(i);
						IF layout.lines[i].firstInParagraph THEN realTY := realTY + layout.lines[i].spaceBefore; END;
						IF (i>0) & layout.lines[i-1].lastInParagraph THEN realTY := realTY + layout.lines[i-1].spaceAfter; END;
					END;
					y := ENTIER(realTY + layout.lines[i].ascent);
					startPos := layout.GetLineStartPos(i);

(*					IF layout.lines[i].align = 0 THEN
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, FALSE);
						x := (li.width + GetLineLeftIndent(l) + bordersI.l);
					ELSIF layout.lines[i].align = 1 THEN
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, FALSE);
						IF ~layout.lines[i].lastInParagraph THEN
							IF layout.lines[i].firstInParagraph THEN
								x := (li.width + GetLineLeftIndent(l) + bordersI.l- ENTIER(layout.lines[i].firstIndent));
							ELSE
								x := (li.width + GetLineLeftIndent(l) + bordersI.l- ENTIER(layout.lines[i].leftIndent));
							END;
						ELSE
							x := (li.width + GetLineLeftIndent(l) + bordersI.l - ENTIER(layout.lines[i].leftIndent));
						END;
					ELSIF layout.lines[i].align = 2 THEN
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, FALSE);
						IF ~layout.lines[i].lastInParagraph THEN
							x := (li.width + GetLineLeftIndent(l) + bordersI.l - ENTIER(layout.lines[i].rightIndent));
						ELSE
							x := (li.width + GetLineLeftIndent(l) + bordersI.l - ENTIER(layout.lines[i].leftIndent));
						END;
					ELSE
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, FALSE);
						x := (li.width + GetLineLeftIndent(l) + bordersI.l);
					END;
*)
					IF (layout.lines[i].align = 3) THEN
						jSpaceSize := layout.lines[i].spaceSize;
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, TRUE);
						(* KernelLog.String("finding justy position..."); DTPUtilities.OutReal(jSpaceSize, 4); KernelLog.Ln; *)
					ELSE
						LayoutLine(startPos, li, i,layout.paperWidth, pos, -1, FALSE);
					END;
					x := (li.width + GetLineLeftIndent(l) + bordersI.l);
					(*  - leftShiftI); *)
					text.ReleaseRead; RETURN TRUE
				ELSE
					text.ReleaseRead; RETURN FALSE
				END
			END
		END FindScreenPos;

		(* llen = -1 to render until the end of line > 0 to render llen elements in the line *)
		PROCEDURE RenderLine*(canvas : WMGraphics.Canvas; VAR l : LineInfo; linenr, top, llen : LONGINT);
		VAR sx, x, sp, i, j, k, linelength, w, voff, color, bgcolor, p : LONGINT; char : Char32; gs: WMGraphics.GlyphSpacings;
	 		curAttr : Texts.Attributes; font : WMGraphics.Font; vc : WMComponents.VisualComponent;
	 		hc : BOOLEAN;
	 		realX, dx: REAL;
	 		curStyle, cStyle: Texts.CharacterStyle;
	 		imh, imw: LONGINT;
		BEGIN
			font := GetFont();
			ASSERT(defaultAttr # NIL);
			curAttr := defaultAttr; canvas.SetColor(defaultAttr.color);
			bgcolor := defaultAttr.bgcolor;
			IF TraceRenderOptimize IN Trace THEN
				KernelLog.String("RenderLine : "); KernelLog.Int(linenr, 5); KernelLog.String(" from position : ");
				KernelLog.Int(layout.GetLineStartPos(linenr), 5); KernelLog.Ln;
			END;

		(*	sp := layout.GetLineStartPos(linenr);  *)
			sp := l.pos;
			IF sp >= text.GetLength() THEN RETURN END;
			utilreader.SetDirection(1); utilreader.SetPosition(sp);
			IF llen < 0 THEN 	linelength := layout.GetLineLength(linenr)
			ELSE linelength := llen
			END;
			i := 0;
			x := GetLineLeftIndent(linenr); realX := x;
(*			KernelLog.String("start: "); KernelLog.Int(x, 0); KernelLog.Ln;
			KernelLog.String("line: "); KernelLog.Int(linenr, 0); KernelLog.Ln;
			IF l.pos = 0 THEN
				realX := realX + layout.lines[linenr].firstIndent;
			ELSE
				IF layout.lines[linenr].align = 0 THEN
					IF layout.lines[linenr].firstInParagraph THEN
						realX := realX + layout.lines[linenr].firstIndent;
					ELSE
						realX := realX + layout.lines[linenr].leftIndent;
					END;
				ELSIF layout.lines[linenr].align = 2 THEN
					realX := realX - layout.lines[linenr].rightIndent;
					IF layout.lines[linenr].lastInParagraph THEN
						realX := realX + layout.lines[linenr].leftIndent;
					END;
				ELSIF layout.lines[linenr].align = 3 THEN
					IF layout.lines[linenr].firstInParagraph THEN
						realX := realX + layout.lines[linenr].firstIndent;
					ELSE
						realX := realX + layout.lines[linenr].leftIndent;
					END;
				END;
			END;
			x := ENTIER(realX);
*)

			sx := bordersI.l;						 (* sx := - leftShiftI + bordersI.l; *)
(*			KernelLog.String("line: "); KernelLog.Int(linenr, 0); KernelLog.String(" width: "); KernelLog.Int(layout.lines[linenr].width, 3); KernelLog.String(" start: "); KernelLog.Int(x, 3); KernelLog.String(" bounds: "); KernelLog.Int(bounds.GetWidth(), 3); KernelLog.Ln;
*)			IF TraceBaseLine IN Trace THEN
				canvas.Line(0, top + ENTIER(l.ascent), bounds.GetWidth(), top + ENTIER(l.ascent), 01F0000FFH, WMGraphics.ModeCopy)
			END;

			w := bounds.GetWidth() - bordersI.r;
			REPEAT
				utilreader.ReadCh(char);

				IF curAttr # utilreader.attributes THEN
					IF utilreader.attributes # NIL THEN
						(* Black is the default color *)
						IF utilreader.attributes.color # 0FFH THEN canvas.SetColor(utilreader.attributes.color);
						ELSE canvas.SetColor(defaultAttr.color)
						END;
						IF utilreader.attributes.fontInfo # NIL THEN
							IF (utilreader.attributes.fontInfo.fontcache # NIL)
								& (utilreader.attributes.fontInfo.fontcache IS WMGraphics.Font) THEN
								font := utilreader.attributes.fontInfo.fontcache(WMGraphics.Font);
							ELSE
								font := GetFontFromAttr(utilreader.attributes.fontInfo);
								utilreader.attributes.fontInfo.fontcache := font
							END
						ELSE font := GetFont()
						END;
						bgcolor := utilreader.attributes.bgcolor;
						color := utilreader.attributes.color;
						voff := utilreader.attributes.voff;
						curAttr := utilreader.attributes
					ELSE
						IF curAttr # defaultAttr THEN
							canvas.SetColor(defaultAttr.color);
							bgcolor := defaultAttr.bgcolor;
							voff := defaultAttr.voff;
							color := defaultAttr.color;
							curAttr := defaultAttr;
							font := GetFont()
						END
					END;
				END;

				IF (utilreader.cstyle # NIL) THEN
					cStyle := utilreader.cstyle;
					IF (utilreader.pstyle # NIL) & (cStyle.name = "defaultCharacterStyle") THEN
						IF utilreader.pstyle.charStyle # NIL THEN
							cStyle := utilreader.pstyle.charStyle;
						END;
					END;
					IF cStyle # curStyle THEN
						font := GetFontFromStyle(cStyle);
(*						IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
							font := cStyle.fontcache(WMGraphics.Font);
						ELSE
							 font := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
							utilreader.cstyle.fontcache := font
						END;

*)(*						font := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
*)					END;
					curStyle := cStyle;
					bgcolor := cStyle.bgColor;
					color := cStyle.color;
					voff := ENTIER(DTPUtilities.FixpToFloat(cStyle.baselineShift));
				ELSIF utilreader.pstyle # NIL THEN
					cStyle := utilreader.pstyle.charStyle;
					IF cStyle # curStyle THEN
						font := GetFontFromStyle(cStyle);
(*						IF (cStyle.fontcache #NIL) & (cStyle.fontcache IS WMGraphics.Font) THEN
							font := cStyle.fontcache(WMGraphics.Font);
						ELSE
							 font := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
							utilreader.cstyle.fontcache := font
						END;

*)(*						font := WMGraphics.GetFont(cStyle.family, ENTIER(DTPUtilities.FixpToFloat(cStyle.size)), cStyle.style);
*)					END;
					curStyle := cStyle;
					bgcolor := cStyle.bgColor;
					color := cStyle.color;
					voff := ENTIER(DTPUtilities.FixpToFloat(cStyle.baselineShift));
				ELSE
					(* default values *)
					color := 0000000FFH;
					bgcolor := LONGINT(0FFFFFF00H);
					font := WMGraphics.GetFont("Oberon", 12, {});
					voff := 0;
					curStyle := NIL
				END;

				IF char = Texts.ObjectChar THEN
					IF (utilreader.object # NIL) & (utilreader.object IS Image) THEN
						imh := utilreader.object(Image).image.height;
						imw := utilreader.object(Image).image.width;
						(* canvas.DrawImage(x, top + (l.ascent) + voff - utilreader.object(Image).height, utilreader.object(Image),
							WMGraphics.ModeSrcOverDst); *)
							canvas.ScaleImage(utilreader.object(Image).image, WMRectangles.MakeRect(0,0, imw, imh),
							WMRectangles.MakeRect(x, top + ENTIER(l.ascent) + voff - ENTIER(imh*zoomFactor*point),
							x + ENTIER(imw*zoomFactor*point), top + ENTIER(l.ascent) + voff),
							WMRasterScale.ModeSrcOverDst, WMRasterScale.ScaleBox);
						dx := imw*zoomFactor*point;
					ELSIF (utilreader.object # NIL) & (utilreader.object IS WMComponents.VisualComponent) THEN
						vc := utilreader.object(WMComponents.VisualComponent);
						dx := (vc.bounds.GetWidth()*zoomFactor*point);
						canvas.SaveState(clipState); (* save the current clip-state *)
						canvas.SetClipRect(WMRectangles.MakeRect(x + sx, top, x + ENTIER(dx) + sx, top + ENTIER(l.height)));
						canvas.ClipRectAsNewLimits(x + sx, top);
						(* assuming the component will not delay --> otherwise a buffer is needed *)
						vc.Acquire; vc.Draw(canvas); vc.Release;
						canvas.RestoreState(clipState)
					END
				ELSIF char = 0 THEN (* EOT *)
				ELSIF char = Texts.TabChar THEN
					IF l.tabStops # NIL THEN dx := (l.tabStops.GetNextTabStop(ENTIER((x+1)/(zoomFactor*point)))*zoomFactor*point) - x
					ELSE dx := (defaultTabStops.GetNextTabStop(ENTIER((x+1)/(zoomFactor*point)))*zoomFactor*point) - x
					END;
					(* KernelLog.String("drawing tab: "); DTPUtilities.OutReal(dx, 4); KernelLog.Ln; *)
					IF bgcolor # 0FFFFFF00H THEN
						canvas.Fill(WMRectangles.MakeRect(x + sx, top, x + ENTIER(dx) + sx, top + ENTIER(l.height)), bgcolor, WMGraphics.ModeCopy)
					END
				ELSE
					IF char = Texts.NewLineChar THEN RETURN END;
					hc := font.HasChar(char);

					IF hc THEN font.GetGlyphSpacings(char, gs)
					ELSE WMGraphics.FBGetGlyphSpacings(char, gs); END;

					dx := ((gs.bearing.l + gs.width + gs.bearing.r)*zoomFactor*point);
					IF bgcolor MOD 256 # 0 THEN
						canvas.Fill(WMRectangles.MakeRect(x + sx, top, x + ENTIER(dx) + sx, top + ENTIER(l.height)), bgcolor, WMGraphics.ModeCopy)
					END;
					IF hc THEN
						(* font.RenderChar(canvas, x + sx, top + (l.ascent) + voff, char) *)
						IF curStyle # NIL THEN fStyle := curStyle END;
						RenderChar(canvas, x + sx, top + ENTIER(l.ascent) + voff, char, font, color);
					ELSE WMGraphics.FBRenderChar(canvas, x + sx, top + ENTIER(l.ascent) + voff, char)
					END
				END;

				(* highlight *)
				IF ~preview THEN
					p := utilreader.GetPosition();
					FOR j := 0 TO nofHighlights - 1 DO
						IF (p > highlights[j].a) & (p <= highlights[j].b) THEN
							CASE highlights[j].kind OF
								|HLOver: canvas.Fill(WMGraphics.MakeRectangle(x + sx, top, x + ENTIER(dx) + sx+1, top + ENTIER(l.height)), highlights[j].color, WMGraphics.ModeSrcOverDst)
								|HLUnder: canvas.Line(x + sx, top + ENTIER(l.ascent), x + ENTIER(dx) + sx+1, top + ENTIER(l.ascent), highlights[j].color, WMGraphics.ModeSrcOverDst);
								|HLWave: FOR k := 0 TO ENTIER (dx) - 1 DO
									canvas.SetPixel(x + k + sx, top + ENTIER(l.ascent) + (1 - ABS((x + k) MOD 4 - 2)), highlights[j].color, WMGraphics.ModeSrcOverDst);
								END;
							ELSE
							END
						END
					END;
				END;

				IF (layout.lines[linenr].spaceSize # 0) & (char = 32) THEN realX := realX + layout.lines[linenr].spaceSize;
				ELSE realX := realX + dx; END;
				x := ENTIER(realX);
				(* x := x + ENTIER(dx); *)
(*				KernelLog.String("width: "); KernelLog.Int(x, 3); KernelLog.Ln;
				KernelLog.String("real: "); DTPUtilities.OutReal(realX, 4); KernelLog.Ln;
*)				INC(i)
			UNTIL (i >= linelength) OR utilreader.eot OR (x + sx > w)
		END RenderLine;

		PROCEDURE RenderChar(canvas : WMGraphics.Canvas; x, y: REAL; char: Char32; font: WMGraphics.Font; color: LONGINT);
		VAR g: WMGraphics.GlyphSpacings; img: WMGraphics.Image;
			glyphCanvas: WMGraphics.BufferCanvas;
			glyphImg: WMGraphics.Image;
			mode : LONGINT;

			curve : BOOLEAN;
		BEGIN
(*			IF (font IS WMOTFonts.Font) OR (font IS WMCCGFonts.Font) THEN
				font := GetFontFromStyle(fStyle); curve := TRUE
			ELSE
				curve := FALSE;
			END;
*)
			font.GetGlyphSpacings(char, g);
			font.GetGlyphMap(char, img);
			IF img # NIL THEN
				IF (glyphImg = NIL) OR (img.width > glyphImg.width) OR (img.height > glyphImg.height)  THEN
					NEW(glyphImg);
					Raster.Create(glyphImg, img.width,img.height, Raster.BGRA8888);
					NEW(glyphCanvas, glyphImg);
				END;
				glyphCanvas.SetColor(color);
				glyphCanvas.DrawImage(0, 0,img, WMGraphics.ModeSrcOverDst);
				IF ~quality THEN
					mode := WMGraphics.ScaleBox;
				ELSE
					mode := WMGraphics.ScaleBilinear;
				END;

		(*	canvas.DrawImage(ENTIER(x+g.bearing.l) + g.dx, ENTIER(y - font.ascent) +g.dy, img, WMGraphics.ModeSrcOverDst); *)
		(*	canvas.ScaleImage(img, WMRectangles.MakeRect(0,0, img.width, img.height), WMRectangles.MakeRect(ENTIER(x + g.bearing.l) + g.dx, ENTIER(y-font.ascent) + g.dy, ENTIER(x+g.bearing.l) + g.dx + ENTIER(img.width*zoomFactor*point), ENTIER(y - font.ascent) +g.dy + ENTIER(img.height*zoomFactor*point)), WMRasterScale.ModeSrcOverDst, WMRasterScale.ScaleBox);  	*)

				IF curve THEN
					canvas.DrawImage(ENTIER(x+g.bearing.l) + g.dx, ENTIER(y - font.ascent) +g.dy, img, WMGraphics.ModeSrcOverDst);
				ELSE
					canvas.ScaleImage(glyphImg, WMRectangles.MakeRect(0,0, img.width, img.height),
					WMRectangles.MakeRect(ENTIER(x + (g.bearing.l + g.dx)*zoomFactor*point), ENTIER(y  + (g.dy - font.ascent)*zoomFactor*point),
						ENTIER(x + (g.bearing.l + g.dx)*zoomFactor*point) + ENTIER(img.width*zoomFactor*point), ENTIER(y  + (g.dy - font.ascent)*zoomFactor*point) + ENTIER(img.height*zoomFactor*point)), WMRasterScale.ModeSrcOverDst, mode);
				END;
			END;

		END RenderChar;

		PROCEDURE RenderAboveTextMarkers*(canvas : WMGraphics.Canvas);
		VAR x, y, l, pos, i, ascent : LONGINT;
		BEGIN
			(* AssertLock; *)
			IF text = NIL THEN RETURN END;
			IF ~preview THEN
				text.AcquireRead;
				FOR i := nofPositionMarkers - 1 TO 0 BY -1 DO
					pos := positionMarkers[i].pos.GetPosition();
					l := layout.FindLineNrByPos(pos);
					IF FindScreenPos(pos, x, y) THEN
						IF (l >= 0) & (l < layout.GetNofLines()) THEN ascent := ENTIER(layout.lines[l].ascent) ELSE ascent := 10 END;
						positionMarkers[i].Draw(canvas, x, y, ascent);
					END
				END;
				text.ReleaseRead;
			END;
		END RenderAboveTextMarkers;

		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET);
		VAR pos, a, b : LONGINT; ch: Char32;
			selectionText: Texts.Text;
			from, to: Texts.TextPosition;
		BEGIN
			(* KernelLog.String("Pointer Down"); KernelLog.Ln; *)
			IF (Inputs.Alt * modifierFlags # {}) & (0 IN keys) THEN	(* copy attributes /style *)
				text.AcquireWrite;
				IF Texts.GetLastSelection(selectionText, from, to) THEN
					selectionText.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					b := Strings.Max(from.GetPosition(), to.GetPosition());

					ViewToTextPos(x, y, pos);
					utilreader.SetPosition(pos);
					utilreader.ReadCh(ch);
					IF utilreader.cstyle # NIL THEN
						selectionText.SetCharacterStyle(a, b - a, utilreader.cstyle);
					ELSIF utilreader.attributes # NIL THEN
						selectionText.SetAttributes(a, b - a, utilreader.attributes.Clone());
					END;
					selectionText.ReleaseWrite
				END;
				text.ReleaseWrite;
			ELSIF 0 IN keys THEN						(* left mouse button pressed *)
				text.AcquireRead;
				dragPossible := FALSE; selectWords := FALSE;
				ViewToTextPos(x, y, pos);
(*					KernelLog.String("Pos: "); KernelLog.Int(pos, 0); KernelLog.Ln;
					KernelLog.String("X: "); KernelLog.Int(x, 0); KernelLog.Ln;
					KernelLog.String("Y: "); KernelLog.Int(y, 0); KernelLog.Ln;
					KernelLog.String("cursor: "); KernelLog.Int(cursor.GetPosition(), 0); KernelLog.Ln;
*)				IF pos >= 0 THEN
					(* KernelLog.Int(pos, 0); *)
					selection.Sort;
					(* clicking the same position twice --> Word Selection Mode *)
					IF pos = cursor.GetPosition() THEN
						selectWords := TRUE; wordSelOrdered  := TRUE;
						selection.SetFromTo(TextUtilities.FindPosWordLeft(utilreader, pos - 1),
								TextUtilities.FindPosWordRight(utilreader, pos + 1))
					ELSE
						selection.SetFromTo(pos, pos) (* reset selection *)
					END;
					selecting := TRUE
				END;
(*				KernelLog.String("setting cursor to: "); KernelLog.Int(pos, 0); KernelLog.Ln;
*)				cursor.SetPosition(pos);
(*				KernelLog.String("cursor: "); KernelLog.Int(cursor.GetPosition(), 0); KernelLog.Ln;
*)				text.ReleaseRead
			END;
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET);
		VAR pos: LONGINT;
		BEGIN
			(*KernelLog.String("Pointer Move"); KernelLog.Ln; *)
				IF selecting THEN
					(* KernelLog.String("Selecting"); KernelLog.Ln; *)
					text.AcquireRead;
					ViewToTextPos(x, y, pos);
					IF selecting THEN
						IF selectWords THEN
							IF pos < selection.from.GetPosition() THEN pos := TextUtilities.FindPosWordLeft(utilreader, pos - 1);
							ELSE pos := TextUtilities.FindPosWordRight(utilreader, pos + 1)
							END;
							selection.SetTo(pos)
						ELSE
							selection.SetTo(pos);
						END;
						Texts.SetLastSelection(text, selection.from, selection.to);
						cursor.SetPosition(pos);
						StoreLineEnter;
					END;
					text.ReleaseRead
				END;
			(* KernelLog.Int(x, 0); KernelLog.String(" : "); KernelLog.Int(y, 0);KernelLog.Ln; *)
		END PointerMove;

		PROCEDURE PointerUp*(x, y: LONGINT; keys: SET);
		BEGIN
			(* KernelLog.String("Pointer Up (selecting = FALSE)"); KernelLog.Ln; *)
			selecting := FALSE;
			IF dragPossible THEN selection.SetFromTo(0, 0); Texts.ClearLastSelection (* reset selection *) END;
			dragPossible := FALSE
		END PointerUp;

		PROCEDURE KeyEvent*(ucs: LONGINT; flags: SET; VAR keysym: LONGINT);
		BEGIN
			modifierFlags := flags;
			(* KernelLog.String("KeyPressed"); KernelLog.Int(ucs, 0); KernelLog.Ln; *)
			text.AcquireWrite;

			IF keysym = 14H THEN (* Ctrl-T *)
				text.CheckHealth
			ELSIF keysym = 01H THEN (* Ctrl-A *)
				SelectAll
			ELSIF keysym = 03H THEN (* Ctrl-C *)
				CopySelection
 			ELSIF (keysym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
				CopySelection
			ELSIF keysym = 12H THEN (* Ctrl-R *)
				layout.FullLayout(firstPos, firstLineI); Invalidate;CheckNumberOfLines;
				KernelLog.String("Refreshed"); KernelLog.Ln;
			ELSIF keysym = 0FF51H THEN (* Cursor Left *)
				IF flags * Inputs.Alt # {} THEN IndentLeft
				ELSE CursorLeft(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				END
			ELSIF keysym = 0FF53H THEN (* Cursor Right *)
				IF flags * Inputs.Alt # {} THEN IndentRight
				ELSE CursorRight(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				END
			ELSIF keysym = 0FF54H THEN (* Cursor Down *)
				CursorDown(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF52H THEN (* Cursor Up *)
				CursorUp(flags * Inputs.Shift # {})
			ELSIF keysym = 0FF56H THEN (* Page Down *)

			ELSIF keysym = 0FF55H THEN (* Page Up *)

			ELSIF keysym = 0FF50H THEN (* Cursor Home *)
				Home(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keysym = 0FF57H THEN (* Cursor End *)
				End(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keysym =  016H THEN (* Ctrl-V *) Paste
			ELSIF keysym = 018H THEN (* Ctrl-X *) CopySelection; DeleteSelection
			ELSIF keysym = 0FFFFH THEN (* Delete *) Delete(flags)
			ELSIF keysym = 0FF08H THEN (* Backspace *) Backspace(flags * Inputs.Ctrl # {})
			ELSIF keysym = 0FF0DH THEN (* CR *) Enter(flags);
			ELSIF (keysym = 0FF63H) & (flags * Inputs.Shift # {}) THEN  (* Shift Insert *) Paste
			(* ELSIF (keysym = 0FF1BH) THEN onEscape.Call(NIL); FocusNext (* Escape *) *)
			ELSE
				InsertChar(ucs);
				IF text.GetLength() = 1 THEN
					text.SetCharacterStyle(0,1, Texts.GetCharacterStyleByName("defaultCharacterStyle"));
					text.SetParagraphStyle(0,1, Texts.GetParagraphStyleByName("defaultParagrahStyle"));
				END;
			END;
			text.ReleaseWrite
		END KeyEvent;

		(* Drag away operations *)
		PROCEDURE AutoStartDrag*;
		VAR img : WMGraphics.Image;
			c : WMGraphics.BufferCanvas;
			w, h, i, la, lb, top : LONGINT;
			l : LineInfo;
			realH, realTop: REAL;
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
				realH := realH + (layout.lines[i].height);
				w := ENTIER(DTPUtilities.Max(w, layout.lines[i].width));
			END;
			h := Limit(ENTIER(realH), 20, 200);
			w := Limit(w, 20, 400);

			(* render to bitmap *)
			NEW(img);	Raster.Create(img, w, h, Raster.BGRA8888);
			NEW(c, img);
			top := 0; realTop := top;
			(* hack the startpos of the first line *)
			l := layout.lines[la]; l.pos := selection.a;
			IF la = lb THEN RenderLine(c, l, la, top, selection.b - selection.a)
			ELSE
				RenderLine(c, l, la, ENTIER(realTop), -1);
				realTop := realTop + l.height;
			END;

			FOR i := la + 1 TO lb DO
				IF i = lb THEN
					RenderLine(c, layout.lines[i], i, ENTIER(realTop), selection.b - layout.lines[i].pos)
				ELSE
					RenderLine(c, layout.lines[i], i, top, -1);
					realTop := realTop + (l.height)
				END
			END;

			text.ReleaseRead;

(*			IF StartDrag(NIL, img, DragWasAccepted, NIL) THEN
			ELSE KernelLog.String("WMTextView : Drag could not be started")
			END;
*)		END AutoStartDrag;

		PROCEDURE DragWasAccepted(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
		(*	itf : WMDropTarget.DropInterface;
			res : LONGINT;
			targetText, temp : Texts.Text;
			pos, a, b : LONGINT; *)
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

(*			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				targetText := itf(WMDropTarget.DropText).text;
				IF targetText # NIL THEN
					targetText.AcquireWrite;
					IF ~dragCopy THEN
						KernelLog.String("not copy"); KernelLog.Ln;
						text.AcquireWrite;
						a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
						pos := itf(WMDropTarget.DropText).pos.GetPosition();
						IF (targetText # text) OR (pos < a) OR (pos > b) THEN
							NEW(temp); temp.AcquireWrite; text.CopyToText(a, b- a, temp, 0); temp.ReleaseWrite;
							text.Delete(a, b- a);
							pos := itf(WMDropTarget.DropText).pos.GetPosition();
							temp.AcquireRead;	temp.CopyToText(0, temp.GetLength(), targetText, pos); temp.ReleaseRead;
						END;
						text.ReleaseWrite
					ELSE
						KernelLog.String("copy"); KernelLog.Ln;
						text.AcquireRead;
						pos := itf(WMDropTarget.DropText).pos.GetPosition();
						a := dragSelA.GetPosition(); b := dragSelB.GetPosition();
						text.CopyToText(a, b- a, targetText, pos);
						text.ReleaseRead
					END;
					targetText.ReleaseWrite
				END;
				RETURN
			END;
*)		END DragWasAccepted;

		(* Drag onto operations *)
		PROCEDURE DragOver(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR pos : LONGINT;
		BEGIN
			text.AcquireRead;
			ViewToTextPos(x, y, pos);
			cursor.SetVisible(TRUE);
			cursor.SetPosition(pos);
			StoreLineEnter;
			text.ReleaseRead
		END DragOver;

		PROCEDURE DragDropped*(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dropTarget : TextDropTarget;
			pos : LONGINT;
			p : Texts.TextPosition;
		BEGIN
			text.AcquireRead;
			ViewToTextPos(x, y, pos)	;
			NEW(p, text); p.SetPosition(pos);
			NEW(dropTarget, text, p);
			text.ReleaseRead;
			dragInfo.data := dropTarget;
			(* ConfirmDrag(TRUE, dragInfo) *)
		END DragDropped;

		PROCEDURE InsertChar*(ch : Texts.Char32);
		VAR buf : ARRAY 2 OF Texts.Char32;
		BEGIN
			buf[0] := ch; buf[1] := 0;
			text.InsertUCS32(cursor.GetPosition(), buf) (* cursor moves automagically *)
		END InsertChar;

		PROCEDURE CopySelection*;
		BEGIN
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
			text.AcquireWrite;
			selection.Sort;
			text.Delete(selection.a, selection.b - selection.a);
			text.ReleaseWrite
		END DeleteSelection;

		PROCEDURE Paste*;
		BEGIN
			text.AcquireWrite;
			Texts.clipboard.AcquireRead;
			text.CopyFromText(Texts.clipboard, 0,  Texts.clipboard.GetLength(), cursor.GetPosition());
			Texts.clipboard.ReleaseRead;
			text.ReleaseWrite
		END Paste;

		PROCEDURE Delete(flags : SET);
		VAR pos : LONGINT;
		BEGIN
			pos := cursor.GetPosition();
			(* shift delete *)
			IF flags * Inputs.Shift # {} THEN
				selection.Sort;
				IF selection.active & (pos >= selection.a) & (pos <= selection.b) THEN
					CopySelection
				END;
			END;
			IF flags * Inputs.Ctrl # {} THEN
				text.Delete(pos, TextUtilities.FindPosWordRight(utilreader, pos) - pos)
			ELSE
				selection.Sort;
				IF selection.active & (pos >= selection.a) & (pos <= selection.b) THEN DeleteSelection
				ELSE text.Delete(pos, 1)
				END
			END
		END Delete;

		PROCEDURE Backspace(word : BOOLEAN);
		VAR pos, np : LONGINT;
		BEGIN
			pos := cursor.GetPosition();
			IF word THEN
				np := TextUtilities.FindPosWordLeft(utilreader, pos - 1);
				text.Delete(np, pos - np)
			ELSE
				selection.Sort;
				IF selection.active & (pos >= selection.a) & (pos <= selection.b) THEN DeleteSelection
				ELSE text.Delete(pos - 1, 1)
				END
			END
		END Backspace;

		PROCEDURE Enter(flags : SET);
		VAR pos, lineStart, nofWhitespace : LONGINT;
			ctrl : BOOLEAN;
			(* for call *)
		BEGIN
			ctrl := flags * Inputs.Ctrl # {};
			IF ctrl THEN (* put into different module ??? *)
				pos := cursor.GetPosition();
				(* tv.StartCommand(pos); *)
			ELSE

					pos := cursor.GetPosition();
					lineStart := TextUtilities.FindPosLineStart(utilreader, pos);
					nofWhitespace := TextUtilities.CountWhitespace(utilreader, lineStart);
					nofWhitespace := Strings.Min(nofWhitespace, pos - lineStart);
					InsertChar(Texts.NewLineChar);
					IF nofWhitespace > 0 THEN
						text.CopyFromText(text, lineStart, nofWhitespace, pos + 1)
					END;

			END;
			(* onEnter.Call(NIL) *)
		END Enter;

		PROCEDURE IndentLeft;
		BEGIN
			text.AcquireWrite;
			selection.Sort;
			TextUtilities.IndentText(text, selection.a, selection.b, TRUE);
			text.ReleaseWrite
		END IndentLeft;

		PROCEDURE IndentRight;
		BEGIN
			text.AcquireWrite;
			selection.Sort;
			TextUtilities.IndentText(text, selection.a, selection.b, FALSE);
			text.ReleaseWrite
		END IndentRight;

		PROCEDURE SelectAll*;
		BEGIN
			text.AcquireRead;
			selection.SetFromTo(0, text.GetLength());
			Texts.SetLastSelection(text, selection.from, selection.to);
			text.ReleaseRead
		END SelectAll;

		(* Prepare to start the selection by keyboard. Clear the selection, if it is not contigous *)
		PROCEDURE KeyStartSelection(pos : LONGINT);
		BEGIN
			IF selection.to.GetPosition() # pos THEN selection.SetFromTo(pos, pos); Texts.ClearLastSelection END;
		END KeyStartSelection;

		(* update the keyboard selection with the new position, redraw from the last StartSelection *)
		PROCEDURE KeyUpdateSelection(pos : LONGINT);
		BEGIN
			selection.SetTo(pos);
			Texts.SetLastSelection(text, selection.from, selection.to)
		END KeyUpdateSelection;

		PROCEDURE CursorUp*(select : BOOLEAN);
		VAR pos, cl : LONGINT;
		BEGIN
			text.AcquireRead;
			pos := cursor.GetPosition();
			IF select THEN KeyStartSelection(pos)
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			cl := layout.FindLineNrByPos(pos);
			IF cl > 0 THEN
				DEC(cl);
				cursor.SetPosition(layout.GetLineStartPos(cl) + Strings.Min(layout.GetLineLength(cl) - 1, lineEnter));
				IF cl < firstLineI THEN firstLine.Set(cl) END
			END;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			text.ReleaseRead
		END CursorUp;

		PROCEDURE CursorDown*(select : BOOLEAN);
		VAR pos, cl : LONGINT;
		BEGIN
			text.AcquireRead;
			pos := cursor.GetPosition();
			IF select THEN KeyStartSelection(pos)
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			cl := layout.FindLineNrByPos(pos);
			IF cl < layout.GetNofLines() - 1 THEN
				INC(cl);
				cursor.SetPosition(layout.GetLineStartPos(cl) + Strings.Min(layout.GetLineLength(cl) - 1, lineEnter));
				IF cl > FindLineByY(firstLineI, bounds.GetHeight() - bordersI.b) THEN firstLine.Set(firstLineI + 1 ) END
			END;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			text.ReleaseRead
		END CursorDown;

		(* Move the cursor one character/word to the left *)
		PROCEDURE CursorLeft*(word, select : BOOLEAN);
		BEGIN
			text.AcquireRead;
			IF select THEN KeyStartSelection(cursor.GetPosition())
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			IF ~ word THEN cursor.SetPosition(cursor.GetPosition() - 1)
			ELSE cursor.SetPosition(TextUtilities.FindPosWordLeft(utilreader, cursor.GetPosition() - 1))
			END;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			StoreLineEnter;
			text.ReleaseRead
		END CursorLeft;

		(* Move the cursor one character/word to the right *)
		PROCEDURE CursorRight*(word, select : BOOLEAN);
		BEGIN
			text.AcquireRead;
			IF select THEN KeyStartSelection(cursor.GetPosition())
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			IF ~ word THEN cursor.SetPosition(cursor.GetPosition() + 1)
			ELSE cursor.SetPosition(TextUtilities.FindPosWordRight(utilreader, cursor.GetPosition() + 1))
			END;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			StoreLineEnter;
			text.ReleaseRead
		END CursorRight;

		PROCEDURE Home*(ctrl, select : BOOLEAN);
		VAR cl : LONGINT;
		BEGIN
			text.AcquireRead;
			IF select THEN KeyStartSelection(cursor.GetPosition())
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			IF ctrl THEN cursor.SetPosition(0); firstLine.Set(0)
			ELSE cl := layout.FindLineNrByPos(cursor.GetPosition());
				cursor.SetPosition(layout.GetLineStartPos(cl))
			END;
			StoreLineEnter;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			text.ReleaseRead
		END Home;

		PROCEDURE End*(ctrl, select : BOOLEAN);
		VAR cl : LONGINT;
		BEGIN
			text.AcquireRead;
			IF select THEN KeyStartSelection(cursor.GetPosition())
			ELSE selection.SetFromTo(cursor.GetPosition(), cursor.GetPosition()); Texts.ClearLastSelection
			END;
			IF ctrl THEN cursor.SetPosition(text.GetLength()); firstLine.Set(layout.FindLineNrByPos(text.GetLength()))
			ELSE cl := layout.FindLineNrByPos(cursor.GetPosition());
				cursor.SetPosition(layout.GetLineStartPos(cl) + layout.GetLineLength(cl) - 1)
			END;
			StoreLineEnter;
			IF select THEN KeyUpdateSelection(cursor.GetPosition()) END;
			text.ReleaseRead
		END End;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; x, y, w, h : LONGINT;  zoomF: REAL; quality, preview: BOOLEAN);
		VAR la, lb, i, top, t : LONGINT; cliprect : WMRectangles.Rectangle; cstate : WMGraphics.CanvasState;
			color: LONGINT;
			realTop: REAL;
			overflow: BOOLEAN;
			chained: BOOLEAN;
			newText: Texts.Text;
		BEGIN
			overflow := FALSE; INC(y, 1);
			IF chainNext # NIL THEN chained := TRUE; ELSE chained := FALSE; END;
			SELF.quality := quality;
			SELF.preview := preview;
			zoomFactor := zoomF;
			ASSERT(layout # NIL);
			canvas.SaveState(cstate);
			canvas.ClipRectAsNewLimits(x, y);

			canvas.GetClipRect(cliprect);
			IF WMRectangles.RectEmpty(cliprect) THEN RETURN END;

(*			color := 0BBBBBBFFH;
			canvas.Fill(WMRectangles.MakeRect(0, 0, 0+w+1, 0+h+1), color, WMGraphics.ModeCopy);
			color := 000FF00FFH;
			canvas.Line(0, 0, 0+w, 0+h, color, WMGraphics.ModeCopy);
			canvas.Line(0+w, 0, 0, 0+h, color, WMGraphics.ModeCopy);
*)
			IF showBorders THEN
				WMGraphicUtilities.DrawBevel(canvas, WMRectangles.ResizeRect(bounds.Get(), -1),
					1, TRUE, LONGINT(0808080FFH), WMGraphics.ModeCopy)
			END;
			text.AcquireRead;
			la := FindLineByY(firstLineI, Strings.Max(cliprect.t, bordersI.t));
			lb := FindLineByY(firstLineI, Strings.Min(cliprect.b, bounds.GetHeight() - bordersI.b));
			(* KernelLog.String("FrameHeight: "); KernelLog.Int(h, 0); KernelLog.Ln; *)
			(* KernelLog.String("bounds Height: "); KernelLog.Int(bounds.GetHeight(), 0); KernelLog.Ln; *)

			(* allow clean clipping in at inner border *)
			WMRectangles.ClipRect(cliprect, borderClip);
			canvas.SetClipRect(cliprect);

			(* prepare selections *)
			FOR i := 0 TO nofHighlights - 1 DO
				highlights[i].a := highlights[i].from.GetPosition();
				highlights[i].b := highlights[i].to.GetPosition();
				IF highlights[i].a > highlights[i].b THEN t := highlights[i].a; highlights[i].a := highlights[i].b; highlights[i].b := t END
			END;

			top := bordersI.t; realTop := top;
			FOR i := firstLineI TO la - 1 DO
				realTop := realTop + (layout.lines[i].height);
				IF layout.lines[i].firstInParagraph THEN realTop := realTop + layout.lines[i].spaceBefore; END;
				IF layout.lines[i].lastInParagraph THEN realTop := realTop + layout.lines[i].spaceAfter; END;
			END;
			IF la >= 0 THEN
				(* draw the lines that intersect the clipping rectangle *)
				FOR i := la TO lb DO
					IF (layout.lines[i].firstInParagraph) & (i # firstLineI) THEN realTop := realTop + layout.lines[i].spaceBefore; END;
					IF ~(ENTIER(realTop + (layout.lines[i].height)) > h) THEN
						RenderLine(canvas, layout.lines[i], i, ENTIER(realTop), -1);
						IF layout.lines[i].lastInParagraph & (ENTIER(realTop +(layout.lines[i].spaceAfter)) > h) & chained THEN
							(* chainNext.firstLineI := i+1; *)
							chainNext.firstLine.Set(i+1);
							chainNext.firstPos := layout.lines[i+1].pos;
							IF layout.lines[i].lastInParagraph THEN chainNext.firstIsFirstInP := TRUE ELSE  chainNext.firstIsFirstInP := FALSE END;
							IF chainNext.text # text THEN chainNext.SetText(text); END;
							i := lb;
						ELSIF chained & (layout.GetNofLines() < lb+2) THEN
							NEW(newText); chainNext.SetText(newText);
							(* chainNext.firstLineI := 0; *)
							chainNext.firstLine.Set(0);
							chainNext.firstPos := 0;
						END;
					ELSE
						IF chained THEN
							(* chainNext.firstLineI := i; *)
							chainNext.firstLine.Set(i);
							chainNext.firstPos := layout.lines[i].pos;
							IF (i>0) & layout.lines[i-1].lastInParagraph THEN chainNext.firstIsFirstInP := TRUE ELSE  chainNext.firstIsFirstInP := FALSE END;
							IF chainNext.text # text THEN chainNext.SetText(text); END;
						END;
						i := lb;
					END;
					realTop := realTop + (layout.lines[i].height);
					IF layout.lines[i].lastInParagraph THEN realTop := realTop + layout.lines[i].spaceAfter; END;
					(* KernelLog.String("TextHeight: "); KernelLog.Int(ENTIER(realTop), 0); KernelLog.Ln; *)
					IF (ENTIER(realTop) > h) THEN overflow := TRUE; END;
				END
			END;
			IF (overflow OR (layout.GetNofLines() > lb+1)) & ~preview THEN
(*				KernelLog.String("lines: "); KernelLog.Int(layout.GetNofLines(), 0); KernelLog.Ln;
				KernelLog.String("lb: "); KernelLog.Int(lb, 0); KernelLog.Ln;
*)				IF chained THEN color := 000FF00FFH;
				ELSE color := LONGINT(0FF0000FFH); END;
				canvas.Line(w-6, h-6, w, h-6, color, WMGraphics.ModeCopy);
				canvas.Line(w-6, h-6, w-6, h, color, WMGraphics.ModeCopy);
				canvas.Line(w-6, h, w, h, color, WMGraphics.ModeCopy);
				canvas.Line(w, h-6, w, h, color, WMGraphics.ModeCopy);
				canvas.Line(w-4, h-3, w-2, h-3, color, WMGraphics.ModeCopy);
				canvas.Line(w-3, h-4, w-3, h-2, color, WMGraphics.ModeCopy);
			END;
			RenderAboveTextMarkers(canvas);
			text.ReleaseRead;
			canvas.RestoreState(cstate);

(*			canvas.SaveState(canvasState);
			canvas.ClipRectAsNewLimits(x, y);

			canvas.RestoreState(canvasState);
*)		END Draw;

		PROCEDURE Redraw;
		BEGIN
			Redraw^;
		END Redraw;

		PROCEDURE StoreLineEnter;
		VAR pos, cl : LONGINT;
		BEGIN
			pos := cursor.GetPosition();
			cl := layout.FindLineNrByPos(pos);
			lineEnter := pos - layout.GetLineStartPos(cl)
		END StoreLineEnter;

		PROCEDURE GetFont(): WMGraphics.Font;
		BEGIN
			IF defaultFont = NIL THEN
				RETURN WMGraphics.GetDefaultFont();
			ELSE
				RETURN defaultFont;
			END;
		END GetFont;

		PROCEDURE OnDelete*;
		VAR textObj, tempObj : TextObject;
			text: Texts.Text;
		BEGIN
			IF (chainPrev # NIL) THEN					(* remove chain from prev frame *)
				chainPrev.chainNext := NIL;
			END;
			IF (chainNext # NIL) THEN					(* remove whole chain in chain *)
				textObj := chainNext; chainNext := NIL; chainPrev := NIL;
				WHILE (textObj # NIL) DO
					tempObj := textObj.chainNext;
					textObj.chainPrev := NIL;
					textObj.chainNext := NIL;
					NEW(text);
					textObj.SetText(text);
					textObj.firstPos := 0; textObj.firstLineI := 0; textObj.firstLine.Set(0);
					textObj := tempObj;
				END;
			END;
		END OnDelete;

		PROCEDURE Load*(elem: XML.Element);
		VAR str : Strings.String;
			node, para, span, tc: XMLObjects.Enumerator;
			ptr: ANY;
			text: Texts.Text;
			pstyle : Texts.ParagraphStyle;
			cstyle : Texts.CharacterStyle;
			len : LONGINT;
			attr: Texts.Attributes;
			fonti: Texts.FontInfo;
			done: BOOLEAN;
			img: Image;
			image: WMGraphics.Image;
			obj: Texts.ObjectPiece;

			PROCEDURE GetUTF8Char(r : Streams.Reader; VAR u : Texts.Char32; VAR pos : LONGINT) : BOOLEAN;
			VAR ch : ARRAY 8 OF CHAR; i : LONGINT;
			BEGIN
				ch[0] := r.Get(); INC(pos);
				FOR i := 1 TO ORD(UTF8Strings.CodeLength[ORD(ch[0])]) - 1 DO ch[i] := r.Get(); INC(pos) END;
				i := 0;
				RETURN UTF8Strings.DecodeChar(ch, i, u)
			END GetUTF8Char;

			PROCEDURE InsertPiece(charContent : XML.ArrayChars);
			VAR i, j, m, tpos : LONGINT; ch, last : Char32;	tempUCS32 : ARRAY 1024 OF Char32;
				oldpos, len : LONGINT; tstr : ARRAY 10 OF CHAR;
				sr : Streams.StringReader;
				lengthCounter : LONGINT;
				string : Strings.String;
			BEGIN
				KernelLog.String("INSERT PIECE!!!!");
				m := LEN(tempUCS32) - 1;
				NEW(sr, charContent.GetLength());
				string := charContent.GetStr();
				IF (charContent.GetLength()<1) THEN RETURN END;
				sr.SetRaw(string^, 0, charContent.GetLength());
				(* Files.OpenReader(r, charContent.GetFile(), charContent.GetPos()); *)
				oldpos := text.GetLength();
				len := charContent.GetLength();
				KernelLog.String("StartPos : "); KernelLog.Int(charContent.GetPos(), 5); KernelLog.String(" len : ");
				KernelLog.Int(charContent.GetLength(), 5); KernelLog.Ln;
				tpos := 0; lengthCounter := 0;
				REPEAT
					IF GetUTF8Char(sr, ch, tpos) THEN
						IF ch = ORD("&") THEN
							j := 0; tstr[j] := "&";
							REPEAT
								INC(j);
								IF GetUTF8Char(sr, ch, tpos) THEN tstr[j] := CHR(ch) END
							UNTIL (j >= LEN(tstr)-2) OR (tstr[j] = ";");
							tstr[j+1] := 0X;
							IF tstr ="&amp;" THEN ch := ORD("&")
							ELSIF tstr ="&lt;" THEN ch := ORD("<")
							ELSIF tstr ="&gt;" THEN ch := ORD(">")
							ELSIF tstr ="&rbrk;" THEN ch := ORD("]")
							END;
						END;
						IF i = m  THEN tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32); i := 0 END;
						IF (last # ORD(CR)) OR (ch # ORD(LF)) THEN
							IF ch = ORD(CR) THEN tempUCS32[i] := ORD(LF)
							ELSE tempUCS32[i] := ch
							END;
							INC(i)
						END;
						last := ch;
						INC(lengthCounter);
					END
				UNTIL (tpos >= len) OR (sr.res # Streams.Ok);
				tempUCS32[i] := 0; text.InsertUCS32(text.GetLength(), tempUCS32);

				IF pstyle # NIL THEN text.SetParagraphStyle(oldpos, len, pstyle); END;
				IF cstyle # NIL THEN
					(* KernelLog.String("Setting Style: "); KernelLog.String(cstyle.name); KernelLog.Ln; *)
					text.SetCharacterStyle(oldpos, lengthCounter, cstyle);
					NEW(attr); attr.color := cstyle.color;
					attr.bgcolor := cstyle.bgColor;
					NEW(fonti); COPY(cstyle.family, fonti.name);
					fonti.size := ENTIER(DTPUtilities.FixpToFloat(cstyle.size));
					fonti.style := cstyle.style;
					attr.fontInfo := fonti;
					(* text.SetAttributes(oldpos, len, attr); *)
				ELSIF (cstyle = NIL) & (pstyle # NIL) THEN
					KernelLog.String("empty"); KernelLog.Ln;
					cstyle := pstyle.charStyle;
					text.SetCharacterStyle(oldpos, len, cstyle);
					NEW(attr); attr.color := cstyle.color;
					attr.bgcolor := cstyle.bgColor;
					NEW(fonti); COPY(cstyle.family, fonti.name);
					fonti.size := ENTIER(DTPUtilities.FixpToFloat(cstyle.size));
					fonti.style := cstyle.style;
					attr.fontInfo := fonti;
					(* text.SetAttributes(oldpos, len, attr); *)
				END;
			END InsertPiece;

			PROCEDURE InsertChar(ch : Texts.Char32);
			VAR buf : ARRAY 2 OF Texts.Char32;
				oldpos: LONGINT;
			BEGIN
				oldpos := text.GetLength(); len := 1;
				buf[0] := ch; buf[1] := 0;
				text.InsertUCS32(text.GetLength(), buf);  (* cursor moves automagically *)
				IF pstyle # NIL THEN text.SetParagraphStyle(oldpos, len, pstyle); END;
				IF cstyle # NIL THEN
					text.SetCharacterStyle(oldpos, len, cstyle);
					NEW(attr); attr.color := cstyle.color;
					attr.bgcolor := cstyle.bgColor;
					NEW(fonti); COPY(cstyle.family, fonti.name);
					fonti.size := ENTIER(DTPUtilities.FixpToFloat(cstyle.size));
					fonti.style := cstyle.style;
					attr.fontInfo := fonti;
					(* text.SetAttributes(oldpos, len, attr); *)
				ELSIF (cstyle = NIL) & (pstyle # NIL) THEN
					cstyle := pstyle.charStyle;
					text.SetCharacterStyle(oldpos, len, cstyle);
					NEW(attr); attr.color := cstyle.color;
					attr.bgcolor := cstyle.bgColor;
					NEW(fonti); COPY(cstyle.family, fonti.name);
					fonti.size := ENTIER(DTPUtilities.FixpToFloat(cstyle.size));
					fonti.style := cstyle.style;
					attr.fontInfo := fonti;
					(* text.SetAttributes(oldpos, len, attr); *)
				END;
			END InsertChar;

		BEGIN
			NEW(text); len := 0;
			text.AcquireWrite;
			node := elem.GetContents(); node.Reset();
			WHILE node.HasMoreElements() DO
				ptr := node.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					IF (str # NIL) & (str^ = "node-attribute") THEN		(* process node-attributes *)
						str := ptr(XML.Element).GetAttributeValue("name");
						IF (str # NIL) & (str^ = "chain-next") THEN
							str := ptr(XML.Element).GetAttributeValue("value");
							IF (str # NIL) THEN
								COPY(str^, chainNextN);
							END;
						ELSIF (str # NIL) & (str^ = "chain-prev") THEN
							str := ptr(XML.Element).GetAttributeValue("value");
							IF (str # NIL) THEN
								COPY(str^, chainPrevN);
							END
						END;
					ELSIF (str # NIL) & (str^ = "node") THEN				(* process paragraphs *)
						str := ptr(XML.Element).GetAttributeValue("name");
						IF (str # NIL) & (str^ = "paragraph") THEN
							para := ptr(XML.Element).GetContents(); para.Reset();
							WHILE para.HasMoreElements() DO
								ptr := para.GetNext();
								IF ptr IS XML.Element THEN
									str := ptr(XML.Element).GetName();
									IF (str # NIL) & (str^ = "node-attribute") THEN	(* process paragraph-attributes *)
										str := ptr(XML.Element).GetAttributeValue("name");
										IF (str # NIL) & (str^ = "style") THEN
											str := ptr(XML.Element).GetAttributeValue("value");
											IF (str # NIL) THEN
												pstyle := Texts.GetParagraphStyleByName(str^);
											ELSE
											END;
										END;
									ELSIF (str # NIL) & (str^ = "node") THEN			(* process spans *)
										str := ptr(XML.Element).GetAttributeValue("name");
										IF (str # NIL) & (str^ = "span") THEN
											span := ptr(XML.Element).GetContents(); span.Reset();
											WHILE span.HasMoreElements() DO
												ptr := span.GetNext();
												IF ptr IS XML.Element THEN
													str := ptr(XML.Element).GetName();
													IF (str # NIL) & (str^ = "node-attribute") THEN	(* process span-attributes *)
														str := ptr(XML.Element).GetAttributeValue("name");
														IF (str # NIL) & (str^ = "style") THEN
															str := ptr(XML.Element).GetAttributeValue("value");
															IF (str # NIL) THEN
																cstyle := Texts.GetCharacterStyleByName(str^);
																(* KernelLog.String("Loading: "); KernelLog.String(cstyle.name); KernelLog.Ln; *)
															ELSE
																IF (pstyle # NIL) THEN
																	cstyle := pstyle.charStyle;
																END;
															END;
														END;
													ELSIF (str # NIL) & (str^ = "node") THEN			(* process content *)
														str := ptr(XML.Element).GetAttributeValue("name");
														IF (str # NIL) & (str^ = "CDATA") THEN
															tc := ptr(XML.Element).GetContents(); tc.Reset();
															IF tc.HasMoreElements() THEN
																ptr := tc.GetNext();
																IF ptr IS XML.CDataSect THEN
																	InsertPiece(ptr(XML.CDataSect));
																END;
															END;
														END;
													ELSE
													END;	(* end content *)
												END;
											END;
										ELSIF (str # NIL) & (str^ = "object") THEN (* object char *)
											span := ptr(XML.Element).GetContents(); span.Reset();
											WHILE span.HasMoreElements() DO
												ptr := span.GetNext();
												IF ptr IS XML.Element THEN
													str := ptr(XML.Element).GetName();
													IF (str # NIL) & (str^ = "node-attribute") THEN	(* process object-attributes *)
														str := ptr(XML.Element).GetAttributeValue("name");
														IF (str # NIL) & (str^ = "file") THEN
															str := ptr(XML.Element).GetAttributeValue("value");
															IF (str # NIL) THEN
																(* KernelLog.String("loading object piece: "); KernelLog.String(str^); KernelLog.Ln; *)
																NEW(img); done := FALSE;
																(* Raster.Load(img, str^, done); *)
																image := WMGraphics.LoadImage(str^, FALSE);
																IF image # NIL THEN
																	img.image := image;
																	img.file := str;
																	NEW(obj); obj.object := img;
																	text.InsertPiece(text.GetLength(), obj);
																END;
															END;
														END;
													END;
												END;
											END;
										END;				(* end object *)
									ELSE
									END;					(* end spans *)
								END;
							END;
						END;
						IF node.HasMoreElements() THEN
							InsertChar(10);
						END;
					ELSE
					END;									(* end paragraphs *)
				END;
			END;
			text.ReleaseWrite;
			SetText(text);

		END Load;

		PROCEDURE FixLinks*;
		VAR obj: DTPData.ContentObject;
		BEGIN
			obj := ownerDoc.GetContentByName(chainNextN);
			IF obj # NIL THEN chainNext := obj(TextObject); END;
			obj := ownerDoc.GetContentByName(chainPrevN);
			IF obj # NIL THEN chainPrev := obj(TextObject); END;
		END FixLinks;

		PROCEDURE Store*(VAR w: Files.Writer);
		VAR tempString: ARRAY 256 OF CHAR;
			cStyle : Texts.CharacterStyle;
			pStyle : Texts.ParagraphStyle;
			ch : Texts.Char32;
			r : Texts.TextReader;
			forceStyle: BOOLEAN;

			PROCEDURE WriteParagraph(pstyle: BOOLEAN);
			BEGIN
				w.String('  <node name="paragraph">'); w.Ln;
				IF pstyle THEN
					w.String('    <node-attribute name="style" value="'); w.String(pStyle.name); w.String('" />'); w.Ln;
				ELSE
					w.String('    <node-attribute name="style" value="defaultParagraphStyle" />'); w.Ln;
				END;
			END WriteParagraph;

			PROCEDURE WriteSpan(cstyle: BOOLEAN);
			BEGIN
				w.String('    <node name="span">'); w.Ln;
				IF cstyle THEN
					w.String('      <node-attribute name="style" value="'); w.String(cStyle.name); w.String('" />'); w.Ln;
				ELSE
					w.String('      <node-attribute name="style" value="defaultCharacterStyle" />'); w.Ln;
				END;
				w.String('      <node name="CDATA"><![CDATA[');
			END WriteSpan;

		BEGIN
			text.AcquireRead;
			NEW(r, text); forceStyle := FALSE;
			w.String('  <node-attribute name="type" value="Text" />'); w.Ln;
			IF chainPrev # NIL THEN COPY(chainPrev.contentName^, tempString); ELSE tempString := "none"; END;
			w.String('  <node-attribute name="chain-prev" value="'); w.String(tempString); w.String('" />'); w.Ln;
			IF chainNext # NIL THEN COPY(chainNext.contentName^, tempString); ELSE tempString := "none"; END;
			w.String('  <node-attribute name="chain-next" value="'); w.String(tempString); w.String('" />'); w.Ln;
(*			w.String('  <node-attribute name="first-pos" value="'); w.String(tempString); w.String('" />'); w.Ln;
			w.String('  <node-attribute name="first-line" value="'); w.String(tempString); w.String('" />'); w.Ln;
*)			r.ReadCh(ch);
			IF chainPrev = NIL THEN
				IF (r.pstyle # NIL) THEN
					pStyle := r.pstyle;
					WriteParagraph(TRUE);
				ELSE
					pStyle := NIL;
				 	WriteParagraph(FALSE);
				END;
				IF (r.cstyle # NIL) THEN
					cStyle := r.cstyle;
					WriteSpan(TRUE);
				ELSE
					IF (r.pstyle # NIL) THEN
						cStyle := r.pstyle.charStyle;
					ELSE
						cStyle := NIL;
					END;
					WriteSpan(FALSE);
				END;

				(* WriteSection(TRUE, TRUE); *)
				WHILE ~r.eot DO

					IF ch = Texts.ObjectChar THEN
						IF (r.object # NIL) & (r.object IS Image) THEN
							(* KernelLog.String("objectchar found"); KernelLog.Ln; *)
							w.String(']]></node>'); w.Ln;							(* close CDATA *)
							w.String('    </node>'); w.Ln;						(* close Span *)
							w.String('    <node name="object">'); w.Ln;			(* open new Object *)
							w.String('      <node-attribute name="file" value="'); w.String(r.object(Image).file^); w.String('" />'); w.Ln;
							w.String('    </node>'); w.Ln;						(* close Object *)
							WriteSpan(FALSE);									(* open new Span *)
						END;
					ELSIF ch < 128 THEN
						CASE CHR(ch) OF
							|"<" : w.String("&lt;");
							|">" : w.String("&gt;");
							|"&" : w.String("&amp;");
							|"]" : w.String("&rbrk;");
						ELSE
							IF (ch = 10) THEN
								w.String(']]></node>'); w.Ln;
								w.String('    </node>'); w.Ln;
								w.String('  </node>'); w.Ln;
								forceStyle := TRUE;
							ELSE
							TextUtilities.WriteUTF8Char(w, ch);
							END;
						END;
					ELSE TextUtilities.WriteUTF8Char(w, ch);
					END;

					r.ReadCh(ch);
					IF (forceStyle) THEN						(* newline, open new paragraph & span *)
						IF (r.pstyle # NIL) THEN
							pStyle := r.pstyle;
							WriteParagraph(TRUE);
						ELSE
							pStyle := NIL;
						 	WriteParagraph(FALSE);
						END;
						IF (r.cstyle # NIL) THEN
							cStyle := r.cstyle;
							WriteSpan(TRUE);
						ELSE
							IF (r.pstyle # NIL) THEN
								cStyle := r.pstyle.charStyle;
								WriteSpan(TRUE);
							ELSE
								cStyle := NIL;
								WriteSpan(FALSE);
							END;
						END;
						forceStyle := FALSE;
					ELSIF (cStyle = NIL) & (r.cstyle # NIL)THEN
						w.String(']]></node>'); w.Ln;
						w.String('    </node>'); w.Ln;
						cStyle := r.cstyle;
						WriteSpan(TRUE);
					ELSIF (cStyle # NIL) & (r.cstyle = NIL) THEN
						w.String(']]></node>'); w.Ln;
						w.String('    </node>'); w.Ln;
						IF (pStyle # NIL) THEN
							cStyle := pStyle.charStyle;
							WriteSpan(TRUE);
						ELSE
							cStyle := NIL;
							WriteSpan(FALSE);
						END;
					ELSIF (cStyle # NIL) & (r.cstyle # NIL) & (cStyle.name # r.cstyle.name) THEN
						w.String(']]></node>'); w.Ln;
						w.String('    </node>'); w.Ln;
						cStyle := r.cstyle;
						WriteSpan(TRUE);
					END;

				END;
				w.String(']]></node>'); w.Ln;
				w.String('    </node>'); w.Ln;
				w.String('  </node>'); w.Ln;
			END;
			text.ReleaseRead;

		END Store;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			props.Show(x, y);
		END Show;

		PROCEDURE Hide*;
		VAR viewport: WMWindowManager.ViewPort;
		BEGIN
			viewport := WMWindowManager.GetDefaultView();
			UpdatePosition(props.bounds.l-ENTIER(viewport.range.l), props.bounds.t-ENTIER(viewport.range.t));
			props.Hide;
		END Hide;

		PROCEDURE Close*;
		BEGIN
			Hide;
		END Close;

	END TextObject;

	TextPropWindow = OBJECT(WMComponents.FormWindow)
	VAR theCaller : TextObject;
		shown: BOOLEAN;
		chain, vAlign: WMEditors.Editor;
		pList, cList, gList, customList : WMStringGrids.StringGrid;
		insert: WMStandardComponents.Button;

		PROCEDURE &New*(caller: TextObject);
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
		VAR panel, panel2, panel3: WMStandardComponents.Panel;
			resizerV: WMStandardComponents.Resizer;
			label: WMStandardComponents.Label;
			windowStyle : WMWindowManager.WindowStyle;
			labelWidth, panelColor : LONGINT;
		BEGIN
			labelWidth := 90;
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel); panel.bounds.SetExtents(190 , 350); panel.fillColor.Set(panelColor);
			panel.takesFocus.Set(TRUE);

			NEW(panel2); panel2.bounds.SetHeight(20); panel2.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(panel2);
			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.SetCaption(" Chain next:");
			panel2.AddContent(label); label.bounds.SetWidth(labelWidth); label.textColor.Set(0000000FFH);
			NEW(chain); chain.alignment.Set(WMComponents.AlignClient);
			chain.tv.showBorder.Set(TRUE); chain.multiLine.Set(FALSE); chain.fillColor.Set(0FFFFFFFFH);
			chain.tv.textAlignV.Set(WMGraphics.AlignCenter);
			chain.onEnter.Add(SetValueHandler); chain.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			chain.SetAsString("none");
			panel2.AddContent(chain);

			NEW(panel2); panel2.bounds.SetHeight(20); panel2.alignment.Set(WMComponents.AlignTop);
			(* panel.AddContent(panel2); *)
			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.SetCaption(" Vertical Align:");
			panel2.AddContent(label); label.bounds.SetWidth(labelWidth); label.textColor.Set(0000000FFH);
			NEW(vAlign); vAlign.alignment.Set(WMComponents.AlignClient);
			vAlign.tv.showBorder.Set(TRUE); vAlign.multiLine.Set(FALSE); vAlign.fillColor.Set(0FFFFFFFFH);
			vAlign.tv.textAlignV.Set(WMGraphics.AlignCenter);
			vAlign.onEnter.Add(SetValueHandler); vAlign.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			vAlign.SetAsString("Top");
			panel2.AddContent(vAlign);

			NEW(panel2); panel2.bounds.SetHeight(20); panel2.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(panel2);
			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.SetCaption(" Object:");
			panel2.AddContent(label); label.bounds.SetWidth(labelWidth); label.textColor.Set(0000000FFH);
			NEW(insert); insert.alignment.Set(WMComponents.AlignClient); insert.caption.SetAOC("Insert");
			insert.onClick.Add(InsertHandler);
			panel2.AddContent(insert);

			(* style choosers *)
			NEW(panel2); panel2.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(panel2);

			NEW(panel3); panel3.bounds.SetHeight(5); panel3.alignment.Set(WMComponents.AlignTop);
			panel2.AddContent(panel3);
			NEW(panel3); panel3.bounds.SetHeight(150); panel3.alignment.Set(WMComponents.AlignTop); panel3.fillColor.Set(0FFCCCCFFH);
			NEW(label); label.alignment.Set(WMComponents.AlignTop); label.SetCaption(" Paragraph Styles:");
			label.fillColor.Set(panelColor); label.bounds.SetHeight(20); label.textColor.Set(0000000FFH);
			panel3.AddContent(label);
			NEW(pList); pList.alignment.Set(WMComponents.AlignClient);
			pList.onClick.Add(PClickSelected);
			pList.model.Acquire;
			pList.model.SetNofCols(1);
			pList.model.SetNofRows(1);
			pList.SetSelectionMode(WMGrids.GridSelectRows);
			pList.model.Release;
			panel3.AddContent(pList);
			panel2.AddContent(panel3);

			NEW(resizerV); resizerV.alignment.Set(WMComponents.AlignBottom);
			resizerV.bounds.SetHeight(4);
			panel3.AddContent(resizerV);

			NEW(panel3); panel3.alignment.Set(WMComponents.AlignClient); panel3.fillColor.Set(0CCFFCCFFH);
			NEW(label); label.alignment.Set(WMComponents.AlignTop); label.SetCaption(" Character Styles:");
			label.fillColor.Set(panelColor); label.bounds.SetHeight(20); label.textColor.Set(0000000FFH);
			panel3.AddContent(label);
			NEW(cList); cList.alignment.Set(WMComponents.AlignClient);
			cList.onClick.Add(CClickSelected);
			cList.model.Acquire;
			cList.model.SetNofCols(1);
			cList.model.SetNofRows(1);
			cList.SetSelectionMode(WMGrids.GridSelectRows);
			cList.model.Release;
			panel3.AddContent(cList);
			panel2.AddContent(panel3);

			RETURN panel;
		END CreatePropertyForm;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				RefreshValues;
				LoadStyleList;
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
		VAR content: TextObject;
			tempString: ARRAY 32 OF CHAR;
		BEGIN
			content := theCaller.chainNext;
			IF (content = NIL) THEN tempString := "none"; ELSE COPY(content.contentName^, tempString); END;
			chain.SetAsString(tempString);
			chain.Invalidate;

			IF (theCaller.vAlign = 0) THEN
				tempString := "Top";
			ELSIF (theCaller.vAlign = 1) THEN
				tempString := "Center";
			ELSIF (theCaller.vAlign = 2) THEN
				tempString := "Bottom";
			ELSIF (theCaller.vAlign = 3) THEN
				tempString := "Justified";
			ELSE
				tempString := "Top";
			END;
			vAlign.SetAsString(tempString);
			vAlign.Invalidate;

	END RefreshValues;

	PROCEDURE SetValueHandler(sender, data: ANY);
		VAR content: DTPData.ContentObject;
			fieldValue: ARRAY 32 OF CHAR;
			textObj, nextTextObj: TextObject;
			text : Texts.Text;
		BEGIN

			IF (sender = vAlign) THEN
				vAlign.GetAsString(fieldValue);
				Strings.LowerCase(fieldValue);
				IF (fieldValue = "0") OR (fieldValue = "top") THEN
					theCaller.vAlign := 0; vAlign.SetAsString("Top");
				ELSIF (fieldValue = "1") OR (fieldValue = "center") THEN
					theCaller.vAlign := 1; vAlign.SetAsString("Center");
				ELSIF (fieldValue = "2") OR (fieldValue = "bottom") THEN
					theCaller.vAlign := 2; vAlign.SetAsString("Bottom");
				ELSIF (fieldValue = "3") OR (fieldValue = "justified") THEN
					theCaller.vAlign := 3; vAlign.SetAsString("Justified");
				ELSE
					theCaller.vAlign := 0; vAlign.SetAsString("Top");
				END;
				(* call vAlign changed *)

			ELSIF (sender = chain) THEN
				chain.GetAsString(fieldValue);
				(* KernelLog.String("Chain: "); KernelLog.String(fieldValue); KernelLog.Ln; *)
				(* IF (fieldValue # "none") THEN *)
					content := theCaller.ownerDoc.GetContentByName(fieldValue);
					IF (content # NIL) THEN
						IF (content IS TextObject) THEN
							IF (content.contentName # theCaller.contentName) THEN
								(* remove previous chain first, if any *)
								textObj := theCaller.chainNext;
								WHILE textObj # NIL DO
									nextTextObj := textObj.chainNext;
									textObj.chainPrev := NIL;
									textObj.chainNext := NIL;
									NEW(text); textObj.SetText(text);
									textObj := nextTextObj;
								END;
								(* set the new chain *)
								theCaller.chainNext := content(TextObject);
								content(TextObject).chainPrev := theCaller;
								content(TextObject).SetText(theCaller.text);
								theCaller.Update;
								theCaller.ChainUpdate;
							ELSE
								textObj := theCaller.chainNext;
								WHILE textObj # NIL DO
									nextTextObj := textObj.chainNext;
									textObj.chainPrev := NIL;
									textObj.chainNext := NIL;
									NEW(text); textObj.SetText(text);
									textObj := nextTextObj;
								END;
								theCaller.chainNext := NIL;
								chain.SetAsString("none");
							END;
						ELSE
							textObj := theCaller.chainNext;
							WHILE textObj # NIL DO
								nextTextObj := textObj.chainNext;
								textObj.chainPrev := NIL;
								textObj.chainNext := NIL;
								NEW(text); textObj.SetText(text);
								textObj := nextTextObj;
							END;
							theCaller.chainNext := NIL;
							chain.SetAsString("none");
						END;
					ELSE
						textObj := theCaller.chainNext;
						WHILE textObj # NIL DO
							nextTextObj := textObj.chainNext;
							textObj.chainPrev := NIL;
							textObj.chainNext := NIL;
							NEW(text); textObj.SetText(text);
							textObj := nextTextObj;
						END;
						theCaller.chainNext := NIL;
						chain.SetAsString("none");
					END;
				(* END; *)
			END;
			theCaller.Redraw;
			RefreshValues;

		END SetValueHandler;

		PROCEDURE InsertHandler(sender, data: ANY);
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "star.gif";
			IF WMDialogs.QueryString("Insert Image:", filename) = WMDialogs.ResOk THEN
				InsertImg(filename);
			END;
		END InsertHandler;

		PROCEDURE InsertImg(CONST file: ARRAY OF CHAR);
		VAR done: BOOLEAN;
			img: Image;
			image : WMGraphics.Image;
			obj: Texts.ObjectPiece;
		BEGIN
			NEW(img); NEW(image); done := FALSE;
			(* Raster.Load(img, file, done); *)
			image := WMGraphics.LoadImage(file, FALSE);
			IF image # NIL THEN
				img.image := image;
				img.file := Strings.NewString(file);
				NEW(obj); obj.object := img;
				(* KernelLog.String("inserting piece in text: "); KernelLog.String(file); KernelLog.Ln; *)
				theCaller.text.AcquireWrite;
				theCaller.text.InsertPiece(theCaller.cursor.GetPosition(), obj);
				theCaller.text.ReleaseWrite;
			END;
		END InsertImg;

		PROCEDURE Close;
		BEGIN
			shown := FALSE;
			Hide;
			Close^;
		END Close;

		PROCEDURE LoadStyleList*;
		VAR i : LONGINT;
			doc : DTPData.Document;
		BEGIN
			doc := theCaller.ownerDoc;
			pList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(doc.pStyles))  & (doc.pStyles[i] # NIL)) DO
				pList.model.SetNofRows(i+1);
				pList.model.SetCellText(0, i, Strings.NewString(doc.pStyles[i].name));
				pList.model.SetCellData(0, i, doc.pStyles[i]);
				INC(i);
			END;
			(* PClickSelected(NIL, pList.model.GetCellData(0, 0)); *)
			pList.model.Release;

			cList.model.Acquire;
			i := 0;
			WHILE ((i<LEN(doc.cStyles))  & (doc.cStyles[i] # NIL)) DO
				cList.model.SetNofRows(i+1);
				cList.model.SetCellText(0, i, Strings.NewString(doc.cStyles[i].name));
				cList.model.SetCellData(0, i, doc.cStyles[i]);
				INC(i);
			END;
			(* CClickSelected(NIL, cList.model.GetCellData(0, 0)); *)
			cList.model.Release;

		END LoadStyleList;

		PROCEDURE PClickSelected(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			utilreader : Texts.TextReader;
			attr : Texts.Attributes;
			currentPStyle : DTPData.ParagraphStyleObject;
			pStyle : Texts.ParagraphStyle;
			cStyle : Texts.CharacterStyle;
			a, b, ch : LONGINT;
		BEGIN
			IF (data # NIL ) THEN
				currentPStyle := data(DTPData.ParagraphStyleObject);
				IF Texts.GetLastSelection(text, from, to) THEN
					(* check if there is a style with that name *)
					pStyle := Texts.GetParagraphStyleByName(currentPStyle.name);
					IF (pStyle = NIL) THEN (* create the style & add to list *)
						NEW(pStyle); COPY(currentPStyle.name, pStyle.name);
						Texts.AddParagraphStyle(pStyle);
					END;
					pStyle.alignment := currentPStyle.alignment;
					pStyle.spaceBefore := DTPUtilities.FloatToFixp(currentPStyle.spaceBefore);
					pStyle.spaceAfter := DTPUtilities.FloatToFixp(currentPStyle.spaceAfter);
					pStyle.leftIndent := DTPUtilities.FloatToFixp(currentPStyle.leftIndent);
					pStyle.rightIndent := DTPUtilities.FloatToFixp(currentPStyle.rightIndent);
					pStyle.firstIndent := DTPUtilities.FloatToFixp(currentPStyle.firstIndent);
					NEW(cStyle);
					COPY(currentPStyle.charStyle.name, cStyle.name);
					COPY(currentPStyle.charStyle.family, cStyle.family);
					cStyle.style := currentPStyle.charStyle.style;
					cStyle.size := DTPUtilities.FloatToFixp(currentPStyle.charStyle.size);
					cStyle.leading := DTPUtilities.FloatToFixp(currentPStyle.charStyle.leading);
					cStyle.baselineShift := DTPUtilities.FloatToFixp(currentPStyle.charStyle.baselineShift);
					cStyle.color := currentPStyle.charStyle.color;
					cStyle.bgColor := currentPStyle.charStyle.bgColor;
					cStyle.tracking := DTPUtilities.FloatToFixp(currentPStyle.charStyle.tracking);
					(* cStyle.kerning := currentPStyle.charStyle.kerning; *)
					cStyle.scaleHorizontal := DTPUtilities.FloatToFixp(currentPStyle.charStyle.scaleHorizontal);
					cStyle.scaleVertical := DTPUtilities.FloatToFixp(currentPStyle.charStyle.scaleVertical);
					pStyle.charStyle := cStyle;

					(* prepare attributes *)
					NEW(attr); NEW(attr.fontInfo);
					COPY(currentPStyle.charStyle.family, attr.fontInfo.name);
					attr.fontInfo.size := ENTIER(currentPStyle.charStyle.size);
					attr.fontInfo.style := currentPStyle.charStyle.style;
					attr.color := currentPStyle.charStyle.color;
					attr.fontInfo.fontcache := NIL;

					text.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					b := Strings.Max(from.GetPosition(), to.GetPosition());
					NEW(utilreader, text);
					utilreader.SetPosition(a);
					utilreader.ReadCh(ch);
					text.SetParagraphStyle(a, b - a, pStyle);
					(* set attributes for back compatibility - dont*)
					(* text.SetAttributes(a, b - a, attr); *)
					text.ReleaseWrite;

					theCaller.layout.FullLayout(theCaller.firstPos, theCaller.firstLineI); theCaller.CheckNumberOfLines;
				END;
			END;

		END PClickSelected;

		PROCEDURE CClickSelected(sender, data: ANY);
		VAR text : Texts.Text;
			from, to : Texts.TextPosition;
			utilreader : Texts.TextReader;
			attr : Texts.Attributes;
			currentCStyle : DTPData.CharacterStyleObject;
			cStyle : Texts.CharacterStyle;
			a, b, ch : LONGINT;
		BEGIN
			IF (data # NIL ) THEN
				currentCStyle := data(DTPData.CharacterStyleObject);
				IF Texts.GetLastSelection(text, from, to) THEN
					(* check if there is a style with that name *)
					cStyle := Texts.GetCharacterStyleByName(currentCStyle.name);
					IF (cStyle = NIL) THEN (* create the style & add to list *)
						NEW(cStyle); COPY(currentCStyle.name, cStyle.name);
						Texts.AddCharacterStyle(cStyle);
					END;
					COPY(currentCStyle.family, cStyle.family);
					cStyle.style := currentCStyle.style;
					cStyle.size := DTPUtilities.FloatToFixp(currentCStyle.size);
					cStyle.leading := DTPUtilities.FloatToFixp(currentCStyle.leading);
					cStyle.baselineShift := DTPUtilities.FloatToFixp(currentCStyle.baselineShift);
					cStyle.color := currentCStyle.color;
					cStyle.bgColor := currentCStyle.bgColor;
					cStyle.tracking := DTPUtilities.FloatToFixp(currentCStyle.tracking);
					(* cStyle.kerning := currentCStyle.kerning; *)
					cStyle.scaleHorizontal := DTPUtilities.FloatToFixp(currentCStyle.scaleHorizontal);
					cStyle.scaleVertical := DTPUtilities.FloatToFixp(currentCStyle.scaleVertical);

					(* prepare attributes *)
					NEW(attr); NEW(attr.fontInfo);
					COPY(cStyle.family, attr.fontInfo.name);
					attr.fontInfo.size := ENTIER(DTPUtilities.FixpToFloat(cStyle.size));
					attr.fontInfo.style := cStyle.style;
					attr.color := cStyle.color;
					attr.fontInfo.fontcache := NIL;

					text.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					b := Strings.Max(from.GetPosition(), to.GetPosition());
					NEW(utilreader, text);
					utilreader.SetPosition(a);
					utilreader.ReadCh(ch);
					text.SetCharacterStyle(a, b - a, cStyle);
					(* set attributes for back compatibility *)
					(* text.SetAttributes(a, b - a, attr); *)
					text.ReleaseWrite;

					theCaller.layout.FullLayout(theCaller.firstPos, theCaller.firstLineI); theCaller.CheckNumberOfLines;
				END;
			END;

		END CClickSelected;

	END TextPropWindow;

(* --------------------------------------------------------------------------- *)
VAR
	PTVfirstLine : WMProperties.Int32Property;
	PTVborders, PTVbounds : WMProperties.RectangleProperty;

PROCEDURE GenText*() : DTPData.ContentObject;
VAR text: TextObject;
BEGIN
	NEW(text);
	RETURN text;
END GenText;

PROCEDURE Register*;
BEGIN
	DTPEditor.plugRegistry.RegisterPlugin(pluginName, GenText);
END Register;

PROCEDURE Cleanup;
BEGIN
	DTPEditor.plugRegistry.UnregisterPlugin(pluginName);
END Cleanup;

PROCEDURE Limit(x, min, max : LONGINT) : LONGINT;
BEGIN
	IF x < min THEN x := min END;
	IF x > max THEN x := max END;
	RETURN x
END Limit;

PROCEDURE TextViewDefaults;
BEGIN
	NEW(PTVfirstLine, NIL, Strings.NewString("firstLine"),
		Strings.NewString("the first visible line of text in the view"));
	PTVfirstLine.Set(0);
	NEW(PTVborders, NIL, Strings.NewString("borders"),
		Strings.NewString("spaces from bounds of the component to the text"));
	PTVborders.Set(WMRectangles.MakeRect(5, 5, 5, 5));
	NEW(PTVbounds, NIL, Strings.NewString("bounds"),
		Strings.NewString("bounds of the component"));
	PTVbounds.Set(WMRectangles.MakeRect(100, 100, 100, 100));
END TextViewDefaults;

BEGIN
	TextViewDefaults;
	Modules.InstallTermHandler(Cleanup);
END DTPText.

SystemTools.Free DTPText

