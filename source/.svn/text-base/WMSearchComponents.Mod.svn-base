MODULE WMSearchComponents; (** AUTHOR "staubesv"; PURPOSE "Search components"; *)

IMPORT
	Inputs, Strings, Texts, TextUtilities, UTF8Strings, WMWindowManager,
	WMRectangles, WMGraphics, WMMessages, WMComponents, WMStandardComponents, WMTextView, WMEditors;

CONST

	SearchStringMaxLen = 128;

TYPE

	SearchString* = ARRAY SearchStringMaxLen OF CHAR;
	UcsSearchString* = ARRAY SearchStringMaxLen OF Texts.Char32;

	StackData = POINTER TO ARRAY OF LONGINT;

	PositionStack = OBJECT
	VAR
		data: StackData;
		size, top: LONGINT;

		PROCEDURE & Init*;
		BEGIN
			size := 32;
			NEW(data, 32);
		END Init;

		PROCEDURE Push(l: LONGINT);
		BEGIN
			IF top = size THEN Expand END;
			data[top] := l;
			INC(top);
		END Push;

		PROCEDURE Pop(): LONGINT;
		VAR val: LONGINT;
		BEGIN
			IF top > 0 THEN
				DEC(top);
				val := data[top];
			ELSE
				val := -1;
			END;
			RETURN val;
		END Pop;

		PROCEDURE Expand;
		VAR
			newSize, i: LONGINT;
			newData: StackData;
		BEGIN
			newSize := 2*size;
			NEW(newData, newSize);
			FOR i := 0 TO size-1 DO
				data[i] := newData[i];
			END;
			size := newSize;
			data := newData;
		END Expand;

		PROCEDURE Invalidate;
		BEGIN
			IF size > 32 THEN Init END;
			top := 0;
		END Invalidate;

	END PositionStack;

TYPE

	Highlight = POINTER TO RECORD
		this : WMTextView.Highlight;
		next : Highlight;
	END;

	Highlights = OBJECT
	VAR
		textView : WMTextView.TextView;
		highlights : Highlight;

		PROCEDURE Add(from, to : LONGINT);
		VAR h : Highlight;
		BEGIN {EXCLUSIVE}
			NEW(h); h.next := highlights; highlights := h;
			h.this := textView.CreateHighlight();
			h.this.SetColor(LONGINT(0FFFF0080H));
			h.this.SetKind(WMTextView.HLOver);
			h.this.SetFromTo(from, to);
		END Add;

		PROCEDURE RemoveAll;
		VAR h : Highlight;
		BEGIN {EXCLUSIVE}
			h := highlights;
			WHILE (h # NIL) DO
				textView.RemoveHighlight(h.this);
				h := h.next;
			END;
			highlights := NIL;
		END RemoveAll;

		PROCEDURE &Init*(textView : WMTextView.TextView);
		BEGIN
			ASSERT(textView # NIL);
			SELF.textView := textView;
		END Init;

	END Highlights;

TYPE

	SearchPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		wrap, caseSensitive, backwards*, highlightAll : BOOLEAN;

		upperPanel, lowerPanel: WMStandardComponents.Panel;
		searchBtn, replBtn, replAllBtn, closeBtn, wrapBtn, caseSensitiveBtn, directionBtn, markAllBtn : WMStandardComponents.Button;
		searchEdit-, replEdit-: WMEditors.Editor;
		searchLabel, replLabel: WMStandardComponents.Label;

		textView: WMTextView.TextView;
		text: Texts.Text;

		pos, len: LONGINT;
		hitCount : LONGINT;
		posValid : BOOLEAN;
		positionStack: PositionStack;
		highlights : Highlights;

		lastPos : LONGINT;
		lastBackwards : BOOLEAN;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(StrSearchPanel);

			wrap := FALSE;
			caseSensitive := TRUE;
			highlightAll := FALSE;

			hitCount := 0;
			backwards := FALSE;
			lastPos := -1; lastBackwards := FALSE;

			NEW(upperPanel);
			upperPanel.alignment.Set(WMComponents.AlignTop);
			upperPanel.bounds.SetHeight(20);
			AddInternalComponent(upperPanel);

			NEW(searchLabel);
			searchLabel.alignment.Set(WMComponents.AlignLeft);
			searchLabel.bounds.SetWidth(40); searchLabel.fillColor.Set(LONGINT(0FFFFFFFFH));
			searchLabel.alignH.Set(WMGraphics.AlignCenter);
			searchLabel.SetCaption("Search");
			upperPanel.AddInternalComponent(searchLabel);

			NEW(searchEdit);
			searchEdit.alignment.Set(WMComponents.AlignLeft);
			searchEdit.bounds.SetWidth(200); searchEdit.multiLine.Set(FALSE);
			searchEdit.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1));
			searchEdit.tv.showBorder.Set(TRUE);
			searchEdit.fillColor.Set(LONGINT(0FFFFFFFFH));
			searchEdit.onEnter.Add(SearchHandler);
			searchEdit.text.onTextChanged.Add(TextChanged);
			searchEdit.tv.SetExtFocusHandler(FocusHandler);
			searchEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			upperPanel.AddInternalComponent(searchEdit);

			NEW(replLabel);
			replLabel.alignment.Set(WMComponents.AlignLeft);
			replLabel.bounds.SetWidth(50); replLabel.fillColor.Set(LONGINT(0FFFFFFFFH));
			replLabel.alignH.Set(WMGraphics.AlignCenter);
			replLabel.SetCaption("Replace");
			upperPanel.AddInternalComponent(replLabel);

			NEW(replEdit);
			replEdit.alignment.Set(WMComponents.AlignClient);
			replEdit.bounds.SetWidth(150); replEdit.multiLine.Set(FALSE);
			replEdit.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1));
			replEdit.tv.showBorder.Set(TRUE);
			replEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);

			replEdit.fillColor.Set(LONGINT(0FFFFFFFFH));
			replEdit.onEnter.Add(ReplaceHandler);
			upperPanel.AddInternalComponent(replEdit);

			NEW(lowerPanel);
			lowerPanel.alignment.Set(WMComponents.AlignTop);
			lowerPanel.bounds.SetHeight(20);
			AddInternalComponent(lowerPanel);

			NEW(searchBtn);
			searchBtn.alignment.Set(WMComponents.AlignLeft);
			searchBtn.caption.SetAOC("Search");
			searchBtn.bounds.SetWidth(80);
			searchBtn.onClick.Add(SearchHandler);
			lowerPanel.AddInternalComponent(searchBtn);

			NEW(replBtn);
			replBtn.alignment.Set(WMComponents.AlignLeft);
			replBtn.caption.SetAOC("Replace");
			replBtn.bounds.SetWidth(80);
			replBtn.onClick.Add(ReplaceHandler);
			lowerPanel.AddInternalComponent(replBtn);

			NEW(replAllBtn);
			replAllBtn.alignment.Set(WMComponents.AlignLeft);
			replAllBtn.caption.SetAOC("Replace All");
			replAllBtn.bounds.SetWidth(80);
			replAllBtn.onClick.Add(ReplaceAllHandler);
			lowerPanel.AddInternalComponent(replAllBtn);

			NEW(wrapBtn);
			wrapBtn.alignment.Set(WMComponents.AlignLeft);
			wrapBtn.caption.SetAOC("Wrap");
			wrapBtn.isToggle.Set(TRUE);
			wrapBtn.SetPressed(wrap);
			wrapBtn.onClick.Add(WrapHandler);
			lowerPanel.AddInternalComponent(wrapBtn);

			NEW(caseSensitiveBtn);
			caseSensitiveBtn.alignment.Set(WMComponents.AlignLeft);
			caseSensitiveBtn.caption.SetAOC("CaseSensitive");
			caseSensitiveBtn.isToggle.Set(TRUE);
			caseSensitiveBtn.SetPressed(caseSensitive);
			caseSensitiveBtn.bounds.SetWidth(80);
			caseSensitiveBtn.onClick.Add(CaseSensitiveHandler);
			lowerPanel.AddInternalComponent(caseSensitiveBtn);

			NEW(directionBtn);
			directionBtn.alignment.Set(WMComponents.AlignLeft);
			directionBtn.caption.SetAOC("Backwards");
			directionBtn.isToggle.Set(TRUE);
			directionBtn.SetPressed(backwards);
			directionBtn.bounds.SetWidth(80);
			directionBtn.onClick.Add(DirectionHandler);
			lowerPanel.AddInternalComponent(directionBtn);

			NEW(markAllBtn);
			markAllBtn.alignment.Set(WMComponents.AlignLeft);
			markAllBtn.bounds.SetWidth(80);
			markAllBtn.caption.SetAOC("Highlight");
			markAllBtn.isToggle.Set(TRUE);
			markAllBtn.SetPressed(highlightAll);
			markAllBtn.onClick.Add(HighlightAllHandler);
			lowerPanel.AddInternalComponent(markAllBtn);

			NEW(closeBtn);
			closeBtn.alignment.Set(WMComponents.AlignLeft);
			closeBtn.caption.SetAOC("Close");
			closeBtn.bounds.SetWidth(80);
			closeBtn.onClick.Add(CloseHandler);
			lowerPanel.AddInternalComponent(closeBtn);

			NEW(positionStack);
		END Init;

		PROCEDURE SetToLastSelection*;
		VAR
			currentSearchString, searchString : SearchString;
			selectionText : Texts.Text; from, to : Texts.TextPosition;
			a, b : LONGINT;
		BEGIN
			searchString := "";
			IF Texts.GetLastSelection(selectionText, from, to) THEN
				selectionText.AcquireRead;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				IF ((b - a) <= SearchStringMaxLen) THEN
					TextUtilities.SubTextToStr(selectionText, a, b - a, searchString);
				END;
				Strings.TrimWS(searchString);
				selectionText.ReleaseRead;
			END;
			searchEdit.GetAsString(currentSearchString);
			IF (searchString # "") & (searchString # currentSearchString) THEN
				searchEdit.SetAsString(searchString);
				searchEdit.text.AcquireRead;
				searchEdit.tv.selection.SetFromTo(0, searchEdit.text.GetLength());
				searchEdit.text.ReleaseRead;
			END;
		END SetToLastSelection;

		PROCEDURE SetText*(t: Texts.Text);
		BEGIN
			text := t;
			posValid := FALSE
		END SetText;

		PROCEDURE SetTextView*(tv: WMTextView.TextView);
		BEGIN
			IF (textView # tv) THEN
				textView := tv;
				IF highlights # NIL THEN
					DisableUpdate; highlights.RemoveAll; EnableUpdate; textView.Invalidate;
				END;
				NEW(highlights, textView);
			END;
			posValid := FALSE;
		END SetTextView;

		PROCEDURE ToggleVisibility*;
		VAR searchString : SearchString;
		BEGIN
			IF ~visible.Get() THEN
				visible.Set(TRUE);
				searchEdit.SetAsString("");
				SetToLastSelection;
				searchEdit.SetFocus;
			ELSE
				searchEdit.GetAsString(searchString);
				IF searchString = "" THEN
					replEdit.SetAsString("");
					visible.Set(FALSE);
					IF (textView # NIL) THEN textView.SetFocus; END;
				ELSE
					searchEdit.SetAsString("");
					searchEdit.SetFocus;
				END;
			END;
		END ToggleVisibility;

		PROCEDURE HandlePreviousNext*(forward : BOOLEAN);
		VAR oldBackwards : BOOLEAN;
		BEGIN
			IF (textView # NIL) THEN textView.SetFocus; END;
			IF visible.Get() THEN
				oldBackwards := backwards;
				backwards := ~forward;
				SearchHandler(NIL, NIL);
				backwards := oldBackwards;
			END;
		END HandlePreviousNext;

		PROCEDURE HandleTab*() : BOOLEAN;
		BEGIN
			IF (visible.Get()) THEN
				(* hack - should not access hasFocus field *)
				IF searchEdit.tv.hasFocus THEN
					replEdit.SetFocus;
					replEdit.Invalidate;
					RETURN TRUE;
				ELSIF replEdit.tv.hasFocus THEN
					searchEdit.SetFocus;
					searchEdit.Invalidate;
					RETURN TRUE;
				END;
			END;
			RETURN FALSE;
		END HandleTab;

		PROCEDURE HandleShortcut*(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;

			PROCEDURE ControlKeyDown(flags : SET) : BOOLEAN;
			BEGIN
				RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
			END ControlKeyDown;

		BEGIN
			IF (keysym = 06H) & ControlKeyDown(flags)THEN (* CTRL-F *)
				ToggleVisibility;
			ELSIF (keysym= 0EH) & ControlKeyDown(flags) THEN (* CTRL-N *)
				HandlePreviousNext(TRUE);
			ELSIF (keysym = 10H) & ControlKeyDown(flags) THEN (* CTRL-P *)
				HandlePreviousNext(FALSE);
			ELSIF (keysym = Inputs.KsTab) & (flags = {}) THEN (* TAB *)
				RETURN HandleTab();
			ELSE
				RETURN FALSE; (* Key not handled *)
			END;
			RETURN TRUE;
		END HandleShortcut;

		PROCEDURE FocusHandler(hasFocus: BOOLEAN);
		BEGIN
			IF textView = NIL THEN RETURN END;
			IF hasFocus THEN
				pos := textView.cursor.GetPosition();
				positionStack.Invalidate;
			END;
		END FocusHandler;

		PROCEDURE WrapHandler(sender, data: ANY);
		BEGIN
			wrap := ~wrap;
		END WrapHandler;

		PROCEDURE CaseSensitiveHandler(sender, data : ANY);
		BEGIN
			caseSensitive := ~caseSensitive;
		END CaseSensitiveHandler;

		PROCEDURE DirectionHandler(sender, data : ANY);
		BEGIN
			backwards := ~backwards;
		END DirectionHandler;

		PROCEDURE HighlightAllHandler(sender, data : ANY);
		BEGIN
			highlightAll := ~highlightAll;
			IF highlightAll THEN
				DisableUpdate; SearchAndHighlightAll; EnableUpdate; markAllBtn.Invalidate; textView.Invalidate;
			ELSE
				DisableUpdate; RemoveHighlights; EnableUpdate; textView.Invalidate;
				markAllBtn.SetCaption("Highlight");
			END;
		END HighlightAllHandler;

		PROCEDURE TextChanged(sender, data: ANY);
		VAR
			changeInfo: Texts.TextChangeInfo;
			from : LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				(* 	We need to use DisableUpdate/EnableUpdate in order to get reasonable performance... This requires
					the call to come from the component's sequencer *)
				sequencer.ScheduleEvent(SELF.TextChanged, sender, data)
			ELSE
				IF data IS Texts.TextChangeInfo THEN
					changeInfo := data(Texts.TextChangeInfo);
					IF (changeInfo.op = Texts.OpInsert) & (changeInfo.len = 1) THEN
						positionStack.Push(pos);
						IF highlightAll THEN DisableUpdate; RemoveHighlights; SearchAndHighlightAll; EnableUpdate; markAllBtn.Invalidate; textView.Invalidate; END;
						SearchAndHighlight(pos);
					ELSIF (changeInfo.op = Texts.OpDelete) & (changeInfo.len = 1) THEN
						from := positionStack.Pop();
						IF from = 1 THEN from := pos END;
						IF highlightAll THEN DisableUpdate; RemoveHighlights; SearchAndHighlightAll; EnableUpdate; markAllBtn.Invalidate; textView.Invalidate;END;
						SearchAndHighlight(from);
					ELSE
						positionStack.Invalidate();
						IF (textView # NIL) THEN  textView.selection.SetFromTo(0, 0); END;
						IF highlightAll THEN DisableUpdate; RemoveHighlights; EnableUpdate; markAllBtn.Invalidate; textView.Invalidate; END;
					END;
				END;
			END;
		END TextChanged;

		PROCEDURE SearchHandler*(sender, data: ANY);
		BEGIN
			IF textView = NIL THEN RETURN END;
			SearchAndHighlight(textView.cursor.GetPosition());
		END SearchHandler;

		PROCEDURE ReplaceHandler(sender, data: ANY);
		VAR replStr : SearchString; ucsStr: UcsSearchString; idx: LONGINT;
		BEGIN
			IF text = NIL THEN RETURN END;
			IF posValid THEN
				replEdit.GetAsString(replStr);
				idx := 0;
				UTF8Strings.UTF8toUnicode(replStr, ucsStr, idx);
				text.AcquireWrite();
				Replace(ucsStr);
				text.ReleaseWrite();
				Highlight;
				SearchHandler(sender, data);
			END;
		END ReplaceHandler;

		PROCEDURE ReplaceAllHandler(sender, data: ANY);
		VAR
			searchStr, replStr : SearchString;
			ucsSearchStr, ucsReplStr : UcsSearchString;
			oldBackwards : BOOLEAN;
			idx: LONGINT;
		BEGIN
			IF text = NIL THEN RETURN END;
			replEdit.GetAsString(replStr);
			idx := 0;
			UTF8Strings.UTF8toUnicode(replStr, ucsReplStr, idx);
			searchEdit.GetAsString(searchStr);
			idx := 0;
			UTF8Strings.UTF8toUnicode(searchStr, ucsSearchStr, idx);
			text.AcquireWrite();
			text.AcquireRead();
			oldBackwards := backwards;
			backwards := FALSE;
			Search(ucsSearchStr, 0);
			WHILE posValid DO
				Replace(ucsReplStr);
				Search(ucsSearchStr, pos + len);
			END;
			backwards := oldBackwards;
			text.ReleaseRead();
			text.ReleaseWrite();
		END ReplaceAllHandler;

		PROCEDURE Replace(CONST ucsStr: ARRAY OF Texts.Char32);
		BEGIN
			text.Delete(pos, len);
			text.InsertUCS32(pos, ucsStr);
			len := TextUtilities.UCS32StrLength(ucsStr);
			posValid := FALSE;
		END Replace;

		PROCEDURE Search(CONST ucsStr: ARRAY OF Texts.Char32; from: LONGINT);
		BEGIN
			IF ucsStr[0] = 0 THEN posValid := FALSE; RETURN; END;
			IF caseSensitive & ~backwards THEN
				pos := TextUtilities.Pos(ucsStr, from, text);
			ELSE
				(* We want to search the text that's on the left hand side of the cursor. If we start searching at position 'from',
				we also consider the character at the current cursor position, which is on the left hand side of the cursro *)
				IF (backwards) & (from > 1) THEN DEC(from); END;

				pos := TextUtilities.GenericPos(ucsStr, from, text, ~caseSensitive, backwards);
			END;
			len := TextUtilities.UCS32StrLength(ucsStr);
			IF pos > -1 THEN posValid := TRUE
			ELSE posValid := FALSE
			END;
		END Search;

		PROCEDURE SearchAndHighlight(from: LONGINT);
		VAR searchStr : SearchString; ucsStr: UcsSearchString; length, idx : LONGINT;
		BEGIN
			IF text = NIL THEN RETURN END;
			searchEdit.GetAsString(searchStr);
			IF searchStr # "" THEN
				idx := 0;
				UTF8Strings.UTF8toUnicode(searchStr, ucsStr, idx);
				text.AcquireRead();
				Search(ucsStr, from);
				(* Detect whether we have found the last search result again but in different search direction *)
				IF (((pos = lastPos) OR (lastPos = -1)) & (lastBackwards # backwards))  THEN
					length := TextUtilities.UCS32StrLength(ucsStr);
					IF backwards THEN
						IF from >= length - 1 THEN
							Search(ucsStr, from - Strings.Length(searchStr));
						END;
					ELSE
						IF from + length < text.GetLength() THEN
							Search(ucsStr, from + Strings.Length(searchStr));
						END;
					END;
				END;
				IF (pos = -1) & wrap THEN
					IF backwards THEN
						Search(ucsStr, text.GetLength() - 1);
					ELSE
						Search(ucsStr, 0);
					END;
				END;
				text.ReleaseRead();
			END;
			lastPos := pos; lastBackwards := backwards;
			Highlight;
		END SearchAndHighlight;

		PROCEDURE SearchAndHighlightAll;
		VAR
			searchString : SearchString;
			ucsStr : UcsSearchString;
			caption : ARRAY 32 OF CHAR; nbr : ARRAY 12 OF CHAR;
			length, idx, pos : LONGINT; from : LONGINT;
		BEGIN
			IF (text = NIL) OR (highlights = NIL) THEN RETURN; END;
			hitCount := 0;
			searchEdit.GetAsString(searchString);
			IF searchString # "" THEN
				idx := 0;
				UTF8Strings.UTF8toUnicode(searchString, ucsStr, idx);
				length := TextUtilities.UCS32StrLength(ucsStr);
				from := 0; pos := 0;
				WHILE(pos >=0) DO
					text.AcquireRead;
					IF caseSensitive THEN pos := TextUtilities.Pos(ucsStr, from, text);
					ELSE pos := TextUtilities.GenericPos(ucsStr, from, text, ~caseSensitive, FALSE);
					END;
					text.ReleaseRead;
					IF pos >= 0 THEN
						INC(hitCount);
						highlights.Add(pos, pos + length);
						from := pos + 1;
					END;
				END;
			END;
			caption := "Highlight:";
			Strings.IntToStr(hitCount, nbr); Strings.Append(caption, nbr);
			markAllBtn.caption.SetAOC(caption);
		END SearchAndHighlightAll;

		PROCEDURE RemoveHighlights;
		BEGIN
			IF (highlights # NIL) THEN highlights.RemoveAll; END;
		END RemoveHighlights;

		PROCEDURE Highlight;
		VAR searchString : SearchString;
		BEGIN
			IF textView = NIL THEN RETURN END;
			IF posValid THEN
				textView.selection.SetFrom(pos);
				textView.selection.SetTo(pos + len);
				IF backwards THEN
					textView.cursor.SetPosition(pos);
				ELSE
					textView.cursor.SetPosition(pos + len);
				END;
			END;
			searchEdit.GetAsString(searchString);
			IF (searchString = "") THEN textView.selection.SetFromTo(0, 0); END;
		END Highlight;

		PROCEDURE CloseHandler(sender, data: ANY);
		BEGIN
			IF highlights # NIL THEN
				DisableUpdate; RemoveHighlights; EnableUpdate; textView.Invalidate;
			END;
			visible.Set(FALSE);
			IF textView # NIL THEN  textView.selection.SetFromTo(0, 0); END;
		END CloseHandler;

		PROCEDURE SetSettings*(wrap, caseSensitive, backwards, highlightAll : BOOLEAN);
		BEGIN
			SELF.wrap := wrap;
			SELF.caseSensitive := caseSensitive;
			SELF.backwards := backwards;
			SELF.highlightAll := highlightAll;

			wrapBtn.SetPressed(wrap);
			caseSensitiveBtn.SetPressed(caseSensitive);
			directionBtn.SetPressed(backwards);
			markAllBtn.SetPressed(highlightAll);
		END SetSettings;

		PROCEDURE GetSettings*(VAR wrap, caseSensitive, backwards, highlightAll : BOOLEAN);
		BEGIN
			wrap := SELF.wrap;
			caseSensitive := SELF.caseSensitive;
			backwards := SELF.backwards;
			highlightAll := SELF.highlightAll;
		END GetSettings;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF searchEdit # NIL THEN searchEdit.text.onTextChanged.Remove(TextChanged); END;
		END Finalize;

	END SearchPanel;

TYPE

	SearchWindow* = OBJECT(WMComponents.FormWindow)
	VAR
		searchPanel : SearchPanel;
		hasBeenClosed- : BOOLEAN;

		PROCEDURE SetTextView*(textView : WMTextView.TextView; text : Texts.Text);
		BEGIN
			ASSERT((textView # NIL) & (text # NIL));
			searchPanel.SetText(text);
			searchPanel.SetTextView(textView);
		END SetTextView;

		PROCEDURE &New*(textView : WMTextView.TextView; text : Texts.Text);
		BEGIN
			ASSERT((textView # NIL) & (text # NIL));
			hasBeenClosed := FALSE;
			NEW(searchPanel);
			searchPanel.fillColor.Set(WMGraphics.White);
			searchPanel.alignment.Set(WMComponents.AlignClient);
			searchPanel.bounds.SetExtents(700, 40);
			searchPanel.closeBtn.visible.Set(FALSE);
			SetTextView(textView, text);
			Init(searchPanel.bounds.GetWidth(), searchPanel.bounds.GetHeight(), FALSE);
			SetContent(searchPanel);
			SetTitle(Strings.NewString("Search"));
			WMWindowManager.DefaultAddWindow(SELF);
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			IF searchPanel.highlights # NIL THEN
				searchPanel.RemoveHighlights; searchPanel.textView.Invalidate;
			END;
			searchPanel.textView.selection.SetFromTo(0, 0);
			hasBeenClosed := TRUE;
		END Close;

		PROCEDURE HandleShortcut(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;

			PROCEDURE ControlKeyDown(flags : SET) : BOOLEAN;
			BEGIN
				RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
			END ControlKeyDown;

			PROCEDURE HandlePreviousNext(forward : BOOLEAN);
			VAR oldBackwards : BOOLEAN;
			BEGIN
				IF searchPanel.visible.Get() THEN
					oldBackwards := searchPanel.backwards;
					searchPanel.backwards := ~forward;
					searchPanel.SearchHandler(NIL, NIL);
					searchPanel.backwards := oldBackwards;
				END;
			END HandlePreviousNext;

		BEGIN
			IF (keysym = 06H) & ControlKeyDown(flags)THEN (* CTRL-F *)
				searchPanel.searchEdit.SetAsString("");
				searchPanel.searchEdit.SetFocus;
			ELSIF (keysym= 0EH) & ControlKeyDown(flags) THEN (* CTRL-N *)
				HandlePreviousNext(TRUE);
			ELSIF (keysym = 10H) & ControlKeyDown(flags) THEN (* CTRL-P *)
				HandlePreviousNext(FALSE);
			ELSE
				RETURN FALSE; (* Key not handled *)
			END;
			RETURN TRUE;
		END HandleShortcut;

		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF m.msgType = WMMessages.MsgKey THEN
				IF ~HandleShortcut(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSE Handle^(m)
			END
		END Handle;

	END SearchWindow;

VAR
	StrSearchPanel : Strings.String;

BEGIN
	StrSearchPanel := Strings.NewString("SearchPanel");
END WMSearchComponents.
