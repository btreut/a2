MODULE WMTabComponents; (** AUTHOR "?/staubesv"; PURPOSE "Tab component" *)

IMPORT
	KernelLog, Strings, XML, WMEvents, WMProperties,
	WMStandardComponents, WMRectangles, WMComponents, WMGraphics;

TYPE

	Tab* = OBJECT
	VAR
		caption- : Strings.String;
		w : LONGINT;
		width : LONGINT; (* if 0, automatically determine width based on caption string size *)
		color- : LONGINT;
		data- : ANY;
		inserted, attention* : BOOLEAN;
		next- : Tab;

		PROCEDURE &Init*;
		BEGIN
			caption := NIL;
			w := 0; width := 0; color := 0;
			data := NIL;
			inserted := FALSE; attention := FALSE;
			next := NIL;
		END Init;

	END Tab;

	Tabs* = OBJECT(WMComponents.VisualComponent)
	VAR
		left, right : WMStandardComponents.Button;
		leftOfs, totalWidth, border, lines : LONGINT;
		lineHeight-: WMProperties.Int32Property;
		tabs-, hover, selected- : Tab;
		canvasState : WMGraphics.CanvasState;

		onSelectTab- : WMEvents.EventSource;
		(* general look *)
		useBgBitmaps- : WMProperties.BooleanProperty;
		borderWidth- : WMProperties.Int32Property;
		(* colors *)
		clDefault-, clHover-, clSelected-, clAttention-, clSelectedAttention-,
		clTextDefault-, clTextHover-, clTextSelected-, clTextAttention, clTextSelectedAttention- : WMProperties.ColorProperty;
		(* background bitmaps *)
		bgLeftDefault-, bgMiddleDefault-, bgRightDefault-,
		bgLeftHover-, bgMiddleHover-, bgRightHover-,
		bgLeftSelected-, bgMiddleSelected-, bgRightSelected-,
		bgLeftAttention-, bgMiddleAttention-, bgRightAttention- : WMProperties.StringProperty;

		imgLeftDefault, imgMiddleDefault, imgRightDefault,
		imgLeftHover, imgMiddleHover, imgRightHover,
		imgLeftSelected, imgMiddleSelected, imgRightSelected,
		imgLeftAttention, imgMiddleAttention, imgRightAttention : WMGraphics.Image;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrTabs);
			SetGenerator("WMTabComponents.GenTabControl");
			lines := 1;
			NEW(left);
			left.alignment.Set(WMComponents.AlignLeft);
			left.bounds.SetWidth(10);
			left.isRepeating.Set(TRUE);
			left.onClick.Add(MoveLeft);
			left.visible.Set(FALSE);

			NEW(right);
			right.alignment.Set(WMComponents.AlignRight);
			right.bounds.SetWidth(10);
			right.isRepeating.Set(TRUE);
			right.onClick.Add(MoveRight);
			right.visible.Set(FALSE);

			AddInternalComponent(left); AddInternalComponent(right);

			NEW(onSelectTab, SELF, Strings.NewString("onSelectTab"), Strings.NewString("if tab clicked"), SELF.StringToCompCommand);
			(* general look *)
			NEW(borderWidth, ProtoTcBorderWidth, NIL, NIL); properties.Add(borderWidth);
			NEW(useBgBitmaps, ProtoTcUseBgBitmaps, NIL, NIL); properties.Add(useBgBitmaps);
			(* background colors *)
			fillColor.SetPrototype(ProtoTcDefault);
			NEW(clDefault, ProtoTcDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clHover, ProtoTcHover, NIL, NIL); properties.Add(clHover);
			NEW(clSelected, ProtoTcSelected, NIL, NIL); properties.Add(clSelected);
			NEW(clAttention, ProtoTcAttention, NIL, NIL); properties.Add(clAttention);
			NEW(clSelectedAttention, ProtoTcSelectedAttention, NIL, NIL); properties.Add(clSelectedAttention);
			(* text colors *)
			NEW(clTextDefault, ProtoTcTextDefault, NIL, NIL); properties.Add(clTextDefault);
			NEW(clTextHover, ProtoTcTextHover, NIL, NIL); properties.Add(clTextHover);
			NEW(clTextSelected, ProtoTcTextSelected,  NIL, NIL); properties.Add(clTextSelected);
			NEW(clTextAttention, ProtoTcTextAttention,  NIL, NIL); properties.Add(clTextAttention);
			NEW(clTextSelectedAttention, ProtoTcTextSelectedAttention, NIL, NIL); properties.Add(clTextSelectedAttention);
			(* background bitmaps *)
			NEW(bgLeftDefault, ProtoTcBgLeftDefault, NIL, NIL); properties.Add(bgLeftDefault);
			NEW(bgMiddleDefault, ProtoTcBgMiddleDefault, NIL, NIL); properties.Add(bgMiddleDefault);
			NEW(bgRightDefault, ProtoTcBgRightDefault, NIL, NIL); properties.Add(bgRightDefault);

			NEW(bgLeftHover, ProtoTcBgLeftHover, NIL, NIL); properties.Add(bgLeftHover);
			NEW(bgMiddleHover, ProtoTcBgMiddleHover, NIL, NIL); properties.Add(bgMiddleHover);
			NEW(bgRightHover, ProtoTcBgRightHover, NIL, NIL); properties.Add(bgRightHover);

			NEW(bgLeftSelected, ProtoTcBgLeftSelected, NIL, NIL); properties.Add(bgLeftSelected);
			NEW(bgMiddleSelected, ProtoTcBgMiddleSelected, NIL, NIL); properties.Add(bgMiddleSelected);
			NEW(bgRightSelected, ProtoTcBgRightSelected, NIL, NIL); properties.Add(bgRightSelected);

			NEW(bgLeftAttention, ProtoTcBgLeftAttention, NIL, NIL); properties.Add(bgLeftAttention);
			NEW(bgMiddleAttention, ProtoTcBgMiddleAttention, NIL, NIL); properties.Add(bgMiddleAttention);
			NEW(bgRightAttention, ProtoTcBgRightAttention, NIL, NIL); properties.Add(bgRightAttention);

			NEW(lineHeight, ProtoLineHeight, NIL, NIL); properties.Add(lineHeight);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			CheckLeftRightButtons;
		END Initialize;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF 	(property = useBgBitmaps) OR
				(property = bgLeftDefault) OR (property = bgMiddleDefault) OR (property = bgRightDefault) OR
				(property = bgLeftHover) OR (property = bgMiddleHover) OR (property = bgRightHover) OR
				(property = bgLeftSelected) OR (property = bgMiddleSelected) OR (property = bgRightSelected) OR
				(property = bgLeftAttention) OR (property = bgMiddleAttention) OR (property = bgRightAttention)
			THEN
				RecacheProperties;
			ELSIF (property = borderWidth) OR
				(property = clDefault) OR (property = clHover) OR (property = clSelected) OR (property = clAttention) OR
				(property = clSelectedAttention) OR (property = clTextDefault) OR (property = clTextHover) OR
				(property = clTextSelected) OR (property = clTextAttention) OR (property = clTextSelectedAttention)
			THEN
				Invalidate;
			ELSIF (property = bounds) THEN
				CalcSize; PropertyChanged^(sender, property);
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		VAR s : Strings.String;
		BEGIN
			RecacheProperties^;
			IF useBgBitmaps.Get() THEN
				s := bgLeftDefault.Get();	IF s # NIL THEN imgLeftDefault := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgMiddleDefault.Get();	IF s # NIL THEN imgMiddleDefault := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgRightDefault.Get();	IF s # NIL THEN imgRightDefault := WMGraphics.LoadImage(s^, TRUE) END;

				s := bgLeftHover.Get();	IF s # NIL THEN imgLeftHover := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgMiddleHover.Get();	IF s # NIL THEN imgMiddleHover := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgRightHover.Get();	IF s # NIL THEN imgRightHover := WMGraphics.LoadImage(s^, TRUE) END;

				s := bgLeftSelected.Get();	IF s # NIL THEN imgLeftSelected := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgMiddleSelected.Get();	IF s # NIL THEN imgMiddleSelected := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgRightSelected.Get();	IF s # NIL THEN imgRightSelected := WMGraphics.LoadImage(s^, TRUE) END;

				s := bgLeftAttention.Get();	IF s # NIL THEN imgLeftAttention := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgMiddleAttention.Get();	IF s # NIL THEN imgMiddleAttention := WMGraphics.LoadImage(s^, TRUE) END;
				s := bgRightAttention.Get();	IF s # NIL THEN imgRightAttention := WMGraphics.LoadImage(s^, TRUE) END;
			ELSE
				imgLeftDefault := NIL; imgMiddleDefault := NIL; imgRightDefault := NIL;
				imgLeftHover := NIL; imgMiddleHover := NIL; imgRightHover := NIL;
				imgLeftSelected := NIL; imgMiddleSelected := NIL; imgRightSelected := NIL;
				imgLeftAttention := NIL; imgMiddleAttention := NIL; imgRightAttention := NIL;
			END;
			Invalidate
		END RecacheProperties;

		PROCEDURE FindTabFromPos(x,y: LONGINT) : Tab;
		VAR cur : Tab; pos,posy, dl, w,h: LONGINT;
		BEGIN
			IF left.visible.Get() THEN dl := left.bounds.GetWidth() ELSE dl := 0 END;
			h := lineHeight.Get();
			IF h = 0 THEN h := bounds.GetHeight() END;
			pos := - leftOfs + dl; posy := 0;
			cur := tabs;
			WHILE cur # NIL DO
				w := cur.w;
				IF pos + w > bounds.GetWidth() THEN INC(posy, h); pos := dl; (*RETURN NIL*) END;
				pos := pos + w;
				IF (x < pos) & (y < posy+h) THEN RETURN cur END;
				cur := cur.next
			END;
			RETURN NIL
		END FindTabFromPos;

		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		VAR new : Tab;
		BEGIN
			IF 0 IN keys THEN
				new := FindTabFromPos(x,y);
				IF (selected # new) & (new # NIL) THEN
					selected := new;
					onSelectTab.Call(selected);
					Invalidate
				END
			END
		END PointerDown;

		PROCEDURE Select*(new : Tab);
		BEGIN
			Acquire;
			IF selected # new THEN
				selected := new;
				Invalidate
			END;
			Release
		END Select;

		PROCEDURE SelectByName*(CONST name : ARRAY OF CHAR);
		VAR tab : Tab; found : BOOLEAN;
		BEGIN
			found := FALSE;
			Acquire;
			tab := tabs;
			WHILE ~found & (tab # NIL) DO
				IF tab.inserted & (tab.caption # NIL) THEN
					found := tab.caption^ = name;
				END;
				IF ~found THEN tab := tab.next; END;
			END;
			IF found & (selected # tab) THEN selected := tab; Invalidate; END;
			Release;
		END SelectByName;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		VAR  new : Tab;
		BEGIN
			new := FindTabFromPos(x,y);
			IF hover # new THEN
				hover := new;
				Invalidate
			END
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			hover := NIL;
			Invalidate
		END PointerLeave;


		PROCEDURE GetLeftTabs(VAR w: LONGINT; inner: BOOLEAN): BOOLEAN;
		VAR cur : Tab; font : WMGraphics.Font; dx, dy, lh,dl : LONGINT; width, pos: LONGINT;
		BEGIN
			IF left.visible.Get() THEN dl := left.bounds.GetWidth() ELSE dl := 0 END;
			font := GetFont();
			cur := tabs;
			pos := -leftOfs+dl;
			WHILE cur # NIL DO
				IF cur.width # 0 THEN
					w := cur.width
				ELSIF cur.caption # NIL THEN
					font.GetStringSize(cur.caption^, dx, dy);
					w := dx + 2 * border
				ELSE
					w := 2 * border
				END;
				IF (pos >= 0) & inner THEN RETURN TRUE END;
				pos := pos + w;
				IF (pos >= 0) & ~inner THEN RETURN TRUE END;
				cur := cur.next;
			END;
			RETURN FALSE
		END GetLeftTabs;

		PROCEDURE MoveLeft(sender, data : ANY);
		VAR w: LONGINT;
		BEGIN
			IF GetLeftTabs(w, FALSE) THEN
				DEC(leftOfs, w)
			END;
			(*DEC(leftOfs, 10);*)
			IF leftOfs < 0 THEN leftOfs := 0 END;
			CalcSize;
			Invalidate;
		END MoveLeft;

		PROCEDURE MoveRight(sender, data : ANY);
		VAR w: LONGINT;
		BEGIN
			IF GetLeftTabs(w, TRUE) THEN
				INC(leftOfs, w)
			END;
			(*
			INC(leftOfs, 10);
			*)
			IF leftOfs > totalWidth - 10 THEN leftOfs := totalWidth - 10 END;
			CalcSize;
			Invalidate;
		END MoveRight;

		PROCEDURE AddTab*(tab : Tab);
		VAR cur : Tab;
		BEGIN
			Acquire;
			tab.next := NIL; tab.inserted := TRUE;
			IF tabs = NIL THEN tabs := tab; selected := tab;
			ELSE
				cur := tabs;
				WHILE cur.next # NIL DO cur := cur.next END;
				cur.next := tab
			END;
			CalcSize;
			Release;
			Invalidate
		END AddTab;

		PROCEDURE RemoveTab*(tab : Tab);
		VAR cur : Tab;
		BEGIN
			IF (tabs = NIL) OR (tab = NIL)  THEN RETURN END;
			Acquire;
			IF tabs = tab THEN tabs := tabs.next
			ELSE
				cur := tabs;
				WHILE (cur # NIL) & (cur.next # tab) DO cur := cur.next END;
				IF cur # NIL THEN cur.next := cur.next.next END
			END;
			CalcSize;
			tab.inserted := FALSE;
			Release;
			Invalidate
		END RemoveTab;

		PROCEDURE RemoveAllTabs*;
		BEGIN
			Acquire;
			tabs := NIL;
			CalcSize;
			Release;
			Invalidate
		END RemoveAllTabs;

		PROCEDURE CheckLeftRightButtons;
		BEGIN
			IF (totalWidth >= bounds.GetWidth()) OR (lines > 1)  THEN
				right.visible.Set(TRUE);
				left.visible.Set(TRUE)
			ELSE
				leftOfs := 0;
				right.visible.Set(FALSE);
				left.visible.Set(FALSE)
			END
		END CheckLeftRightButtons;

		PROCEDURE Resized;
		BEGIN
			Resized^;
			CheckLeftRightButtons
		END Resized;

		PROCEDURE CalcSize;
		VAR cur : Tab; font : WMGraphics.Font; dx, dy, lh : LONGINT; width, w, pos: LONGINT;
		BEGIN
			font := GetFont();
			totalWidth := 0; width := 0; lines := 1; lh := lineHeight.Get();
			cur := tabs;
			pos := -leftOfs;

			WHILE cur # NIL DO
				IF cur.width # 0 THEN
					w := cur.width
				ELSIF cur.caption # NIL THEN
					font.GetStringSize(cur.caption^, dx, dy);
					w := dx + 2 * border
				ELSE
					w := 2 * border
				END;
				IF (pos + w > bounds.GetWidth()) & (lh # 0) THEN
					width := 0; pos := 0; INC(lines);
				END;
				width := width + w; pos := pos + w;
				cur := cur.next;
				IF width > totalWidth THEN totalWidth := width END;
			END;
			IF lh # 0 THEN bounds.SetHeight(lines * lh) END;
			CheckLeftRightButtons
		END CalcSize;

		PROCEDURE SetTabCaption*(tab : Tab; caption : Strings.String);
		BEGIN
			Acquire;
			tab.caption := caption;
			CalcSize;
			Release;
			IF tab.inserted THEN Invalidate END
		END SetTabCaption;

		PROCEDURE SetTabColor*(tab : Tab; color : LONGINT);
		BEGIN
			Acquire;
			tab.color := color;
			Release;
			IF tab.inserted THEN Invalidate END
		END SetTabColor;

		(* Set fixed width for the specified tab. If width = 0, the width of the tab is detemined by the width of the caption String *)
		PROCEDURE SetTabWidth*(tab : Tab; width : LONGINT);
		BEGIN
			Acquire;
			tab.width := width;
			CalcSize;
			Release;
			IF tab.inserted THEN Invalidate; END;
		END SetTabWidth;

		PROCEDURE SetTabData*(tab : Tab; data : ANY);
		BEGIN
			Acquire;
			tab.data := data;
			Release;
			IF tab.inserted THEN Invalidate END
		END SetTabData;

		PROCEDURE NewTab*() : Tab;
		VAR tab : Tab;
		BEGIN
			NEW(tab); RETURN tab
		END NewTab;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR r : WMRectangles.Rectangle;
			w, h, lh, dl, dr, wLeft, wRight : LONGINT;
			pos,ypos : LONGINT; dx, dy, dc : LONGINT;
			cur : Tab; font : WMGraphics.Font;
			imgLeft, imgMiddle, imgRight : WMGraphics.Image;
		BEGIN
			border := borderWidth.Get();
			font := GetFont();
			dc := font.descent;
(*			DrawBackground^(canvas); *)
			lh := lineHeight.Get();
			IF lh # 0 THEN h := lh ELSE h:= bounds.GetHeight() END;
			w := bounds.GetWidth();

			IF left.visible.Get() THEN dl := left.bounds.GetWidth() ELSE dl := 0 END;
			IF right.visible.Get() THEN dr := right.bounds.GetWidth() ELSE dr := 0 END;
			canvas.SaveState(canvasState);
			canvas.SetClipRect(WMRectangles.MakeRect(dl, 0, w - dr, bounds.GetHeight()));
			canvas.ClipRectAsNewLimits(dl, 0);

			pos := - leftOfs;
			cur := tabs;
			WHILE cur # NIL DO
				IF cur.width # 0 THEN
					w := cur.width;
				ELSIF cur.caption # NIL THEN
					font.GetStringSize(cur.caption^, dx, dy); w := dx + 2 * border;
				ELSE
					w := 2 * border
				END;
				cur.w := w;
				IF pos + w >  bounds.GetWidth() THEN
					pos := 0;
					ypos := ypos + h;
				END;

				r := WMRectangles.MakeRect(pos, ypos, pos + w, ypos+h);

				IF useBgBitmaps.Get() THEN
					IF cur = hover THEN
						imgLeft := imgLeftHover;
						imgMiddle := imgMiddleHover;
						imgRight := imgRightHover;
					ELSIF cur = selected THEN
						imgLeft := imgLeftSelected;
						imgMiddle := imgMiddleSelected;
						imgRight := imgRightSelected;
					ELSIF cur.attention THEN
						imgLeft := imgLeftAttention;
						imgMiddle := imgMiddleAttention;
						imgRight := imgRightAttention;
					ELSE
						imgLeft := imgLeftDefault;
						imgMiddle := imgMiddleDefault;
						imgRight := imgRightDefault
					END;
					(* left *)
			 		IF imgLeft # NIL THEN
						wLeft := imgLeft.width;
						canvas.ScaleImage(	imgLeft,
						 	WMRectangles.MakeRect(0, 0, imgLeft.width, imgLeft.height),
							WMRectangles.MakeRect(pos, 0, pos+wLeft, bounds.GetHeight()),
							WMGraphics.ModeSrcOverDst, 10)
					ELSE
						wLeft := 0
					END;
					(* right *)
			 		IF imgRight # NIL THEN
						wRight := imgRight.width;
						canvas.ScaleImage(	imgRight,
						 	WMRectangles.MakeRect(0, 0, imgRight.width, imgRight.height),
							WMRectangles.MakeRect(pos+w-wRight, 0, pos+w, bounds.GetHeight()),
							WMGraphics.ModeSrcOverDst, 10)
					ELSE
						wRight := 0
					END;
					(* middle *)
					IF imgMiddle # NIL THEN
						canvas.ScaleImage(	imgMiddle,
								 	WMRectangles.MakeRect(0, 0, imgMiddle.width, imgMiddle.height),
									WMRectangles.MakeRect(pos+wLeft, 0, pos+w-wRight, bounds.GetHeight()), WMGraphics.ModeSrcOverDst, 10)
					END
				ELSE (* no bitmaps are used to decorate the background *)
					IF cur = hover THEN
						canvas.Fill(r, clHover.Get(), WMGraphics.ModeSrcOverDst)
					ELSIF cur = selected THEN
						IF (cur.attention) THEN
							canvas.Fill(r, clSelectedAttention.Get(), WMGraphics.ModeSrcOverDst);
						ELSE
							canvas.Fill(r, clSelected.Get(), WMGraphics.ModeSrcOverDst)
						END;
					ELSIF cur.attention THEN
						canvas.Fill(r, clAttention.Get(), WMGraphics.ModeSrcOverDst)
					ELSE
						IF cur.color # 0 THEN canvas.Fill(r, cur.color, WMGraphics.ModeSrcOverDst)
						ELSE canvas.Fill(r, clDefault.Get(), WMGraphics.ModeSrcOverDst)
						END
					END;
					RectGlassShade(canvas, r, {2}, 2, cur = selected)
				END;
				(* caption *)
				IF cur = hover THEN
					canvas.SetColor(clTextHover.Get());
				ELSIF cur = selected THEN
					IF (cur.attention) THEN
						canvas.SetColor(clTextSelectedAttention.Get());
					ELSE
						canvas.SetColor(clTextSelected.Get());
					END;
				ELSIF cur.attention THEN
					canvas.SetColor(clTextAttention.Get());
				ELSE
					canvas.SetColor(clTextDefault.Get());
				END;
				IF cur.caption # NIL THEN canvas.DrawString(r.l + border , r.b - dc - 1, cur.caption^) END;
				pos := pos + w;
				cur := cur.next
			END;
			canvas.RestoreState(canvasState)
		END DrawBackground;

	END Tabs;

TYPE

	TabEntry* = OBJECT(WMStandardComponents.Panel)
	VAR
		caption- : WMProperties.StringProperty;
		color- : WMProperties.ColorProperty;
		tabWidth- : WMProperties.Int32Property;

		tab : Tab;
		tabs : Tabs;

		next : TabEntry;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = caption) THEN
				IF (tabs # NIL) & (tab # NIL) THEN
					tabs.SetTabCaption(tab, caption.Get());
				END;
			ELSIF (property = color) THEN
				IF (tabs # NIL) & (tab # NIL) THEN
					tabs.SetTabColor(tab, color.Get());
				END;
			ELSIF (property = tabWidth) THEN
				IF (tabs # NIL) & (tab # NIL) THEN
					tabs.SetTabWidth(tab, tabWidth.Get());
				END;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrTab);
			SetGenerator("WMTabComponents.GenTab");
			NEW(caption, NIL, StrCaption, StrCaptionDescription); properties.Add(caption);
			caption.Set(StrNoCaption);
			NEW(color, NIL, StrColor, StrColorDescription); properties.Add(color);
			color.Set(0);
			NEW(tabWidth, NIL, StrTabWidth, StrTabWidthDescription); properties.Add(tabWidth);
			tabWidth.Set(0);
			tab := NIL;
			tabs := NIL;
			next := NIL;
		END Init;

	END TabEntry;

TYPE

	TabPanel* = OBJECT(WMStandardComponents.Panel)
	VAR
		selection- : WMProperties.StringProperty;
		entries : TabEntry;
		first : BOOLEAN;
		tabs : Tabs;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrTabPanel);
			SetGenerator("WMTabComponents.GenTabPanel");
			NEW(selection, NIL, StrSelection, StrSelectionDescription); properties.Add(selection);
			selection.Set(StrNoSelection);
			first := TRUE;
			tabs := NIL;
			entries := NIL;
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		VAR string : Strings.String;
		BEGIN
			IF (property = selection) THEN
				string := selection.Get();
				IF (tabs # NIL) & (string # NIL) THEN
					tabs.SelectByName(string^);
				END;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR e : TabEntry; tab : Tab;
		BEGIN
			IF (data # NIL) & (data IS Tab) THEN
				tab := data(Tab);
				DisableUpdate;
				BEGIN {EXCLUSIVE}
					e := entries;
					WHILE (e # NIL) DO
						IF (tab.data # NIL) & (tab.data IS TabEntry) THEN
							e.visible.Set(tab.data = e);
						END;
						e := e.next;
					END;
				END;
				EnableUpdate;
				Invalidate;
				selection.Set(Strings.NewString(data(Tab).caption^));
			END;
		END TabSelected;

		PROCEDURE AddContent*(c : XML.Content);
		VAR entry : TabEntry;  tab : Tab; string : Strings.String; select : BOOLEAN;
		BEGIN
			IF (c IS Tabs) THEN
				IF (tabs = NIL) THEN
					tabs := c(Tabs);
					tabs.onSelectTab.Add(TabSelected);
				ELSE
					KernelLog.String("WMTabComponents: Warning: Cannot add TabControl component (already set)");
					KernelLog.Ln;
				END;
			ELSIF (c IS TabEntry) THEN
				entry := c(TabEntry);
				IF (tabs # NIL) THEN
					tab := tabs.NewTab();
					tab.data := entry;
					tab.caption := entry.caption.Get();
					tab.color := entry.color.Get();
					tab.width := entry.tabWidth.Get();
					IF (tab.caption = NIL) THEN tab.caption := Strings.NewString("NoCaption"); END;
					entry.alignment.Set(WMComponents.AlignClient);
					string := selection.Get();
					IF (string = StrNoSelection) & first THEN
						entry.visible.Set(TRUE);
						first := FALSE;
						select := TRUE;
					ELSIF (string # NIL) & (string^ = tab.caption^) THEN
						entry.visible.Set(TRUE);
						select := TRUE;
					ELSE
						entry.visible.Set(FALSE);
						select := FALSE;
					END;
					BEGIN {EXCLUSIVE}
						IF (entries = NIL) THEN
							entries := entry;
						ELSE
							entry.next := entries;
							entries := entry;
						END;
					END;
					entry.tabs := tabs; entry.tab := tab;
					tabs.AddTab(tab);
					IF select THEN tabs.Select(tab); END;
				ELSE
					KernelLog.String("WMTabComponents: Warning: Cannot add tab (missing TabControl component)");
					KernelLog.Ln;
				END;
			END;
			AddContent^(c);
		END AddContent;

	END TabPanel;

VAR
	ColorPrototype, ProtoTcDefault*, ProtoTcHover*, ProtoTcSelected*, ProtoTcAttention*, ProtoTcSelectedAttention*,
	ProtoTcTextDefault*, ProtoTcTextHover*, ProtoTcTextSelected*, ProtoTcTextAttention, ProtoTcTextSelectedAttention* : WMProperties.ColorProperty;
	Int32Prototype, ProtoTcBorderWidth*, ProtoLineHeight : WMProperties.Int32Property;
	StringPrototype, ProtoTcBgLeftDefault, ProtoTcBgMiddleDefault, ProtoTcBgRightDefault,
	ProtoTcBgLeftHover, ProtoTcBgMiddleHover, ProtoTcBgRightHover,
	ProtoTcBgLeftSelected, ProtoTcBgMiddleSelected, ProtoTcBgRightSelected,
	ProtoTcBgLeftAttention, ProtoTcBgMiddleAttention, ProtoTcBgRightAttention : WMProperties.StringProperty;
	BooleanPrototype, ProtoTcUseBgBitmaps : WMProperties.BooleanProperty;

	StrTabs, StrTabPanel, StrTab,
	StrCaption, StrCaptionDescription, StrNoCaption,
	StrColor, StrColorDescription,
	StrTabWidth, StrTabWidthDescription,
	StrSelection, StrSelectionDescription, StrNoSelection : Strings.String;

PROCEDURE GenTabPanel*() : XML.Element;
VAR p : TabPanel;
BEGIN
	NEW(p); RETURN p;
END GenTabPanel;

PROCEDURE GenTabControl*() : XML.Element;
VAR c : Tabs;
BEGIN
	NEW(c); RETURN c;
END GenTabControl;

PROCEDURE GenTab*() : XML.Element;
VAR t : TabEntry;
BEGIN
	NEW(t); RETURN t;
END GenTab;

PROCEDURE RectGlassShade*(canvas : WMGraphics.Canvas; rect : WMRectangles.Rectangle; openSides : SET; borderWidth : LONGINT; down : BOOLEAN);
VAR i, ul, dr, da, w, a, b, c, d : LONGINT;
BEGIN
	IF down THEN ul := 090H; dr := LONGINT(0FFFFFF90H)
	ELSE dr := 090H; ul := LONGINT(0FFFFFF90H)
	END;
	da := 90H DIV borderWidth;
	FOR i := 0 TO borderWidth - 1 DO
		IF  (0 IN openSides) THEN a := 0 ELSE a := i END;
		IF  (1 IN openSides) THEN b := 0 ELSE b := i + 1 END;
		IF  (2 IN openSides) THEN c := 0 ELSE c := i END;
		IF  (3 IN openSides) THEN d := 0 ELSE d := i + 1 END;
		(* top *)
		IF ~(0 IN openSides) THEN canvas.Fill(WMRectangles.MakeRect(rect.l + b , rect.t + i, rect.r - d, rect.t + i + 1), ul, WMGraphics.ModeSrcOverDst) END;
		(* left *)
		IF ~(1 IN openSides) THEN canvas.Fill(WMRectangles.MakeRect(rect.l + i, rect.t + a, rect.l + i + 1, rect.b - c), ul, WMGraphics.ModeSrcOverDst) END;
		(* bottom *)
		IF ~(2 IN openSides) THEN canvas.Fill(WMRectangles.MakeRect(rect.l + b, rect.b - 1 - i, rect.r - d, rect.b - i), dr, WMGraphics.ModeSrcOverDst) END;
		(* right *)
		IF ~(3 IN openSides) THEN canvas.Fill(WMRectangles.MakeRect(rect.r - 1 - i, rect.t + a, rect.r - i, rect.b - c), dr, WMGraphics.ModeSrcOverDst) END;
		DEC(ul, da); DEC(dr, da)
	END;
	i := 3; ul := LONGINT(0FFFFFF40H); w := 5;
	canvas.Fill(WMRectangles.MakeRect(rect.l + i , rect.t + i, rect.l + i + w, rect.t + i + 2), ul, WMGraphics.ModeSrcOverDst);
	canvas.Fill(WMRectangles.MakeRect(rect.l + i, rect.t + i, rect.l + i + 2, rect.t + i + w), ul, WMGraphics.ModeSrcOverDst);
END RectGlassShade;

PROCEDURE InitStrings;
BEGIN
	StrTabs := Strings.NewString("Tabs");
	StrTabPanel := Strings.NewString("TabPanel");
	StrTab := Strings.NewString("Tab");
	StrCaption := Strings.NewString("Caption");
	StrNoCaption := Strings.NewString("NoCaption");
	StrCaptionDescription := Strings.NewString("Caption of tab");
	StrColor := Strings.NewString("Color");
	StrColorDescription := Strings.NewString("Color of tab (0: use tab default color)");
	StrTabWidth := Strings.NewString("TabWidth");
	StrTabWidthDescription := Strings.NewString("Width of the tab button");
	StrSelection := Strings.NewString("Selection");
	StrSelectionDescription := Strings.NewString("SelectionDescription");
	StrNoSelection := Strings.NewString("");
END InitStrings;

PROCEDURE InitPrototypes;
VAR plTabs: WMProperties.PropertyList;
BEGIN
	NEW(plTabs); WMComponents.propertyListList.Add("Tab", plTabs);
	(* tab background *)
	NEW(BooleanPrototype, NIL, Strings.NewString("UseBgBitmaps"), Strings.NewString("Will the background be decorated with bitmaps?"));
	BooleanPrototype.Set(FALSE);
	NEW(ProtoTcUseBgBitmaps, BooleanPrototype, NIL, NIL); plTabs.Add(ProtoTcUseBgBitmaps);
	(* background colors *)
	NEW(ColorPrototype, NIL, Strings.NewString("ClDefault"), Strings.NewString("color of the tab item"));
	ColorPrototype.Set(0000FF88H);
	NEW(ProtoTcDefault, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcDefault);
	NEW(ColorPrototype, NIL, Strings.NewString("ClHover"), Strings.NewString("color of the tab item, if the mouse is over it"));
	ColorPrototype.Set(LONGINT(0FFFF00FFH));
	NEW(ProtoTcHover, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcHover);
	NEW(ColorPrototype, NIL, Strings.NewString("ClSelected"), Strings.NewString("color of the the tab item, if it is selected"));
	ColorPrototype.Set(LONGINT(0FFFF00FFH));
	NEW(ProtoTcSelected, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcSelected);
	NEW(ColorPrototype, NIL, Strings.NewString("ClAttention"), Strings.NewString("color of the the tab item, if attention is required"));
	ColorPrototype.Set(LONGINT(0FF8040FFH));
	NEW(ProtoTcAttention, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcAttention);
	NEW(ColorPrototype, NIL, Strings.NewString("ClSelectedAttention"), Strings.NewString("color of the tab item, if it is selected and requires attention"));
	ColorPrototype.Set(LONGINT(0FF9020FFH));
	NEW(ProtoTcSelectedAttention, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcSelectedAttention);
	(* background bitmaps *)
	NEW(StringPrototype, NIL, Strings.NewString("BgLeftDefault"), Strings.NewString("Left default background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgLeftDefault, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgLeftDefault);
	NEW(StringPrototype, NIL, Strings.NewString("BgMiddleDefault"), Strings.NewString("Middle default background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgMiddleDefault, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgMiddleDefault);
	NEW(StringPrototype, NIL, Strings.NewString("BgRightDefault"), Strings.NewString("Right default background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgRightDefault, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgRightDefault);

	NEW(StringPrototype, NIL, Strings.NewString("BgLeftHover"), Strings.NewString("Left mouseover background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgLeftHover, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgLeftHover);
	NEW(StringPrototype, NIL, Strings.NewString("BgMiddleHover"), Strings.NewString("Middle mouseover background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgMiddleHover, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgMiddleHover);
	NEW(StringPrototype, NIL, Strings.NewString("BgRightHover"), Strings.NewString("Right mouseover background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgRightHover, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgRightHover);

	NEW(StringPrototype, NIL, Strings.NewString("BgLeftSelected"), Strings.NewString("Left selected background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgLeftSelected, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgLeftSelected);
	NEW(StringPrototype, NIL, Strings.NewString("BgMiddleSelected"), Strings.NewString("Middle selected background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgMiddleSelected, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgMiddleSelected);
	NEW(StringPrototype, NIL, Strings.NewString("BgRightSelected"), Strings.NewString("Right selected background bitmap"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgRightSelected, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgRightSelected);

	NEW(StringPrototype, NIL, Strings.NewString("BgLeftAttention"), Strings.NewString("Left background bitmap when attention is required"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgLeftAttention, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgLeftAttention);
	NEW(StringPrototype, NIL, Strings.NewString("BgMiddleAttention"), Strings.NewString("Middle background bitmap when attention is required"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgMiddleAttention, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgMiddleAttention);
	NEW(StringPrototype, NIL, Strings.NewString("BgRightAttention"), Strings.NewString("Right background bitmap when attention is required"));
	StringPrototype.Set(NIL); NEW(ProtoTcBgRightAttention, StringPrototype, NIL, NIL); plTabs.Add(ProtoTcBgRightAttention);
	(* text colors *)
	NEW(ColorPrototype, NIL, Strings.NewString("ClTextDefault"), Strings.NewString("default text color of the tab  item")); ColorPrototype.Set(WMGraphics.Yellow);
	NEW(ProtoTcTextDefault, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcTextDefault);
	NEW(ColorPrototype, NIL, Strings.NewString("ClTextHover"), Strings.NewString("text color of the tab item, if the mouse is over it")); ColorPrototype.Set(00000FFFFH);
	NEW(ProtoTcTextHover, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcTextHover);
	NEW(ColorPrototype, NIL, Strings.NewString("ClTextSelected"), Strings.NewString("text color of the tab item, when selected")); ColorPrototype.Set(0000FFFFH);
	NEW(ProtoTcTextSelected, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcTextSelected);
	NEW(ColorPrototype, NIL, Strings.NewString("ClTextAttention"), Strings.NewString("text color of the tab item, when attention is required")); ColorPrototype.Set(0000FFFFH);
	NEW(ProtoTcTextAttention, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcTextAttention);
	NEW(ColorPrototype, NIL, Strings.NewString("ClTextSelectedAttention"),
		Strings.NewString("text color of the tab item, when selected and attention is required")); ColorPrototype.Set(0000FFFFH);
	NEW(ProtoTcTextSelectedAttention, ColorPrototype, NIL, NIL); plTabs.Add(ProtoTcTextSelectedAttention);
	(* border width *)
	NEW(Int32Prototype, NIL, Strings.NewString("BorderWidth"), Strings.NewString("Width of the border of the tabs")); Int32Prototype.Set(3);
	NEW(ProtoTcBorderWidth, Int32Prototype, NIL, NIL);	plTabs.Add(ProtoTcBorderWidth);

	NEW(ProtoLineHeight, NIL, Strings.NewString("LineHeight"), Strings.NewString("height of a single line. If zero then no multiline support")); ProtoLineHeight.Set(0);

	WMComponents.propertyListList.UpdateStyle;
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMTabComponents.

SystemTools.Free WMTabComponents ~
WMTabComponents.Open ~
