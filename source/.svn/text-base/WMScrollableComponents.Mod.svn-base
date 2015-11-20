MODULE WMScrollableComponents; (** AUTHOR "Ingmar Nebel"; PURPOSE "Scrollable Container"; *)

IMPORT
	Strings, XML, WMGraphics, WMRectangles, WMMessages, WMProperties, WMComponents, WMStandardComponents;

TYPE
	(* Local type-alias for convenience *)
	String = Strings.String;
	Panel = WMStandardComponents.Panel;

	(* special component to adapt to scroll target, in total conrol by ScrollablePanel, never use otherwise *)
	ScrollPanel*= OBJECT(WMComponents.VisualComponent)
	VAR
		left, top, dx, dy: LONGINT;
		CheckScrollbars: WMMessages.CompCommand;
		resizing: BOOLEAN; (* distinguish whether AlignSubComponents is called from children or from Resized *)

		PROCEDURE &New*(CheckScrollbars: WMMessages.CompCommand);
		BEGIN
			Init;
			SELF.CheckScrollbars := CheckScrollbars;
			left := 0; top := 0;
			SetNameAsString(StrScrollPanel);
		END New;

		(* store total width and height of subcomponents, check it *)
		PROCEDURE AlignSubComponents;
		VAR c: XML.Content; vc : WMComponents.VisualComponent;
			r, rCopy, rEnclosing, vcBounds, b : WMRectangles.Rectangle;
		BEGIN
			Acquire;
			IF aligning THEN Release; RETURN END;
			aligning := TRUE;
			r := GetClientRect(); rCopy := r; rEnclosing := r;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS WMComponents.VisualComponent THEN
					vc := c(WMComponents.VisualComponent);
					IF vc.visible.Get() THEN
						b := vc.bearing.Get();
						CASE vc.alignment.Get() OF
						| WMComponents.AlignTop : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.t + b.t + vc.bounds.GetHeight())); INC(r.t, vc.bounds.GetHeight() + b.t + b.b);
						| WMComponents.AlignLeft : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l, r.t + b.t, r.l + b.l + vc.bounds.GetWidth(), r.b - b.b)); INC(r.l, vc.bounds.GetWidth() + b.l + b.r)
						| WMComponents.AlignBottom : vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l, r.b - vc.bounds.GetHeight() - b.b, r.r - b.r, r.b - b.b)); DEC(r.b, vc.bounds.GetHeight() + b.t + b.b)
						| WMComponents.AlignRight : vc.bounds.Set(WMRectangles.MakeRect(r.r - vc.bounds.GetWidth() - b.r , r.t + b.t, r.r - b.r, r.b - b.b)); DEC(r.r, vc.bounds.GetWidth() + b.l + b.r);
						| WMComponents.AlignClient : IF ~WMRectangles.RectEmpty(r) THEN vc.bounds.Set(WMRectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.b  - b.b)) END
						ELSE (* nothing *)
						END;
						vcBounds := vc.bounds.Get();
						WMRectangles.ExtendRect(rEnclosing, vcBounds);
					END
				END;
				c := GetNext(c);
			END;
			dx :=  Strings.Max(0, (rEnclosing.r-rEnclosing.l)-(rCopy.r-rCopy.l));
			dy := Strings.Max(0, (rEnclosing.b-rEnclosing.t)-(rCopy.b-rCopy.t));
			CheckLeftTop;
			aligning := FALSE;
			Release;
			IF ~resizing THEN CheckScrollbars(NIL, NIL) END;
		END AlignSubComponents;

		PROCEDURE CheckLeftTop;
		BEGIN
			left := Strings.Min(left, dx);
			top := Strings.Min(top, dy);
		END CheckLeftTop;

		PROCEDURE SetLeftTop(dxf, dyf: REAL);
		BEGIN
			SELF.left := ENTIER(dx * dxf); SELF.top := ENTIER(dy * dyf); CheckLeftTop;
		END SetLeftTop;

		(** Special methods *)
		PROCEDURE Resized;
		BEGIN
			IF sequencer # NIL THEN ASSERT(sequencer.lock.HasWriteLock()) END;
			resizing := TRUE;
			DisableUpdate;
			(* don't need to adjust parent, because bounds are always changed by parent, not third party
			p := SELF.GetParent();
			IF (p # NIL) & (p IS VisualComponent) THEN p(VisualComponent).AlignSubComponents END;
			*)
			AlignSubComponents;
			EnableUpdate;
			(*IF (p # NIL) & (p IS VisualComponent) THEN p(VisualComponent).Invalidate
			ELSE Invalidate()
			END*)
			resizing := FALSE;
			Invalidate;
		END Resized;

		(** declare a rectangle area as dirty *)
		PROCEDURE InvalidateRect(r: WMRectangles.Rectangle);
		VAR parent : XML.Element;
			m : WMMessages.Message; b, cr : WMRectangles.Rectangle;
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~visible.Get() THEN RETURN END;
			IF ~IsCallFromSequencer() THEN
				m.msgType := WMMessages.MsgExt;
				m.ext := WMComponents.invalidateRectMsg; m.x := r.l; m.y := r.t; m.dx := r.r; m.dy := r.b; m.sender := SELF;
				IF ~sequencer.Add(m) THEN END;
			ELSE
				parent := GetParent();
				IF (parent # NIL) & (parent IS WMComponents.VisualComponent) THEN
					cr := GetClientRect();
					WMRectangles.MoveRel(r, -left, -top);
					WMRectangles.ClipRect(r, cr);
					IF ~WMRectangles.RectEmpty(r) THEN
						b := bounds.Get();
						WMRectangles.MoveRel(r, b.l, b.t);
						parent(WMComponents.VisualComponent).InvalidateRect(r)
					END
				END
			END
		END InvalidateRect;

		PROCEDURE InvalidateCommand(sender, par : ANY);
		VAR cr: WMRectangles.Rectangle;
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.InvalidateCommand, sender, par)
			ELSIF visible.Get() THEN
				cr := GetClientRect(); WMRectangles.MoveRel(cr, left, top);
				InvalidateRect(cr)
			END
		END InvalidateCommand;

		PROCEDURE HandleInternal(VAR msg : WMMessages.Message); (** PROTECTED *)
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (msg.msgType = WMMessages.MsgPointer) OR (msg.msgType = WMMessages.MsgDrag) THEN
				msg.x := msg.x + left; msg.y := msg.y + top;
			END;
			HandleInternal^(msg);
		END HandleInternal;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		VAR canvasState: WMGraphics.CanvasState;
		BEGIN
				canvas.SaveState(canvasState);
				canvas.SetDelta(canvas.dx - left, canvas.dy - top);
				DrawSubComponents(canvas);
				canvas.RestoreState(canvasState)
		END Draw;

	END ScrollPanel;

TYPE

	(** just shows an image, showing scrollbars if necessairy *)
	ScrollableContainer* = OBJECT(Panel)
	VAR
		vScrollbar, hScrollbar : WMStandardComponents.Scrollbar;
		scrollPanel: ScrollPanel;
		dx, dy : LONGINT;
		minNofLevels*, nofLevelsPerPage* : WMProperties.Int32Property;
		wheelScrolling- : WMProperties.BooleanProperty;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetGenerator("WMScrollableComponents.GenScrollableContainer");
			(* scrollbars *)
			NEW(vScrollbar); vScrollbar.alignment.Set(WMComponents.AlignRight); AddInternalComponent^(vScrollbar);
			vScrollbar.onPositionChanged.Add(ScrollbarsChanged); vScrollbar.visible.Set(FALSE);
			NEW(hScrollbar); hScrollbar.alignment.Set(WMComponents.AlignBottom); AddInternalComponent^(hScrollbar);
			hScrollbar.vertical.Set(FALSE); hScrollbar.onPositionChanged.Add(ScrollbarsChanged);
			hScrollbar.visible.Set(FALSE);
			NEW(scrollPanel, FitScrollTarget); scrollPanel.alignment.Set(WMComponents.AlignClient); AddInternalComponent^(scrollPanel);
			SetNameAsString(StrScrollableContainer);
			dx := 0;  dy := 0 ;
			NEW(minNofLevels, PrototypeSCMinNofLevels, NIL, NIL); properties.Add(minNofLevels);
			NEW(nofLevelsPerPage, PrototypeSCNofLevelsPerPage, NIL, NIL); properties.Add(nofLevelsPerPage);
			NEW(wheelScrolling, PrototypeSCWheelScrolling, NIL, NIL); properties.Add(wheelScrolling);
		END Init;

		PROCEDURE AlignSubComponents;
		BEGIN
			(* align scrollbars and scrollPanel first *)
			Acquire;
			IF aligning THEN Release; RETURN END;
			AlignSubComponents^;
			(* the own bounds or client bounds may have changed *)
			aligning := TRUE;
			FitScrollTarget(NIL, NIL);
			aligning := FALSE;
			Release;
		END AlignSubComponents;

		PROCEDURE HandleInternal(VAR msg : WMMessages.Message);
		BEGIN
			IF wheelScrolling.Get() & (msg.msgType = WMMessages.MsgPointer) & (msg.msgSubType = WMMessages.MsgSubPointerMove) & (msg.dz # 0) THEN
				WheelMove(msg.dz);
				msg.dz := 0;
			END;
			HandleInternal^(msg);
		END HandleInternal;

		PROCEDURE FitScrollTarget(sender, par: ANY);
		VAR spw, sph, tw, th, sw, sh, w, h, rw, rh, nofLevels: LONGINT;
		BEGIN
			IF (sequencer # NIL) & ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(FitScrollTarget, NIL, NIL)
			END;
			IF nofLevelsPerPage.Get() = 0 THEN RETURN END;
			ASSERT(nofLevelsPerPage.Get() > 0);
			IF (scrollPanel # NIL) THEN
				spw := scrollPanel.bounds.GetWidth(); sph := scrollPanel.bounds.GetHeight();
				tw := spw + scrollPanel.dx; th := sph + scrollPanel.dy;
				sw := vScrollbar.width.Get(); sh := hScrollbar.width.Get();
				w := bounds.GetWidth(); h := bounds.GetHeight();
				(* is hScrollbar visible ? *)
				IF (tw > w) OR ((th>h) & (tw>(w-sw))) THEN
					(* is vScrollbar visible ? *)
					IF (th > (h-sh)) OR (tw<=w) THEN rw := w - sw ELSE rw := w END;
					dx := tw- rw;
					hScrollbar.visible.Set(TRUE);
					IF rw > 0 THEN
					nofLevels := Strings.Max(minNofLevels.Get(), nofLevelsPerPage.Get() * dx DIV rw);
					END;
					hScrollbar.max.Set(nofLevels);
					(* hScrollbar.pageSize.Set(Strings.Max(1, (rw * nofLevels) DIV dx)); *)
					hScrollbar.pageSize.Set(Strings.Max(1, (rw * nofLevels) DIV th) + 1);
					IF (sequencer # NIL) & sequencer.IsCallFromSequencer() THEN
						hScrollbar.RecacheProperties; (* workaround because, InternalPropertyChanged is InUpdate *)
					END;
				ELSE
					dx := 0;
					hScrollbar.visible.Set(FALSE);
				END;
				(* is vScrollbar visible ? *)
				IF (th > h) OR ((tw>w) & (th>(h-sh))) THEN
					(* is hScrollbar visible ? *)
					IF (tw > (w-sw)) OR (th<=h)  THEN rh := h - sh ELSE rh := h END;
					dy := th - rh;
					vScrollbar.visible.Set(TRUE);
					IF rh > 0 THEN
						nofLevels := Strings.Max(minNofLevels.Get(), nofLevelsPerPage.Get() * dy DIV rh)
					END;
					vScrollbar.max.Set(nofLevels);
					(* vScrollbar.pageSize.Set(Strings.Max(1, (rh * nofLevels) DIV dy)); *)
					vScrollbar.pageSize.Set(Strings.Max(1, (rh * nofLevels) DIV th) + 1);
					vScrollbar.RecacheProperties; (* workaround because, InternalPropertyChanged is InUpdate *)
				ELSE
					dy := 0;
					vScrollbar.visible.Set(FALSE);
				END
			END;
			IF ~aligning THEN AlignSubComponents END;
			Invalidate;
		END FitScrollTarget;

		PROCEDURE ScrollbarsChanged(sender, data : ANY);
		BEGIN
			scrollPanel.SetLeftTop(hScrollbar.pos.Get() / (hScrollbar.max.Get() - hScrollbar.min.Get()),
				vScrollbar.pos.Get() / (vScrollbar.max.Get() - vScrollbar.min.Get()));
			Invalidate
		END ScrollbarsChanged;

		PROCEDURE WheelMove(dz : LONGINT);
		CONST Multiplier  = 3;
		VAR pos : LONGINT;
		BEGIN
			WheelMove^(dz);
			IF vScrollbar.visible.Get() THEN
				pos := vScrollbar.pos.Get() + Multiplier * dz;
				IF pos < vScrollbar.min.Get() THEN pos := vScrollbar.min.Get(); END;
				IF pos > vScrollbar.max.Get() THEN pos := vScrollbar.max.Get(); END;
				vScrollbar.pos.Set(pos);
				ScrollbarsChanged(NIL, NIL);
			END;
		END WheelMove;

		PROCEDURE AddInternalComponent*(component : WMComponents.Component);
		BEGIN
			scrollPanel.AddInternalComponent(component);
		END AddInternalComponent;

		(** Iff data IS WMGraphics.Image, it is set as background. Else the background is set to white *)
		(* Note: Only use for anonymous Images without a specific Name *)
		PROCEDURE AddContent(content : XML.Content);
		BEGIN
			IF (content IS WMProperties.Properties) OR (content = vScrollbar) OR (content = hScrollbar) OR (content = scrollPanel) THEN
				AddContent^(content);
			ELSE
				scrollPanel.AddContent(content);
			END;
		END AddContent;

	END ScrollableContainer;

VAR

	Int32Prototype : WMProperties.Int32Property;

	(* Scrollable Container prototypes *)
	PrototypeSCMinNofLevels*, PrototypeSCNofLevelsPerPage*: WMProperties.Int32Property;
	PrototypeSCWheelScrolling : WMProperties.BooleanProperty;
	StrScrollPanel, StrScrollableContainer : String;

PROCEDURE InitStrings;
BEGIN
	StrScrollableContainer := Strings.NewString("ScrollableContainer");
	StrScrollPanel := Strings.NewString("ScrollPanel");
END InitStrings;

PROCEDURE InitPrototypes;
VAR
	plScrollableContainer : WMProperties.PropertyList;
BEGIN
	(* ScrollablePanel prototypes *)
	NEW(plScrollableContainer); WMComponents.propertyListList.Add("Scrollable Container", plScrollableContainer);
	NEW(Int32Prototype, NIL, NewString("MinNofLevels"), NewString("")); Int32Prototype.Set(8);
	NEW(PrototypeSCMinNofLevels, Int32Prototype, NIL, NIL); plScrollableContainer.Add(PrototypeSCMinNofLevels);
	NEW(Int32Prototype, NIL, NewString("NofLevelsPerPage"), NewString("")); Int32Prototype.Set(8);
	NEW(PrototypeSCNofLevelsPerPage, Int32Prototype, NIL, NIL); plScrollableContainer.Add(PrototypeSCNofLevelsPerPage);
	NEW(PrototypeSCWheelScrolling, NIL, NewString("WheelScrolling"), NewString("Mouse wheel scrolling?"));
	PrototypeSCWheelScrolling.Set(TRUE);
	WMComponents.propertyListList.UpdateStyle
END InitPrototypes;

PROCEDURE GenScrollableContainer*() : XML.Element;
VAR scrollCont: ScrollableContainer;
BEGIN NEW(scrollCont); RETURN scrollCont
END GenScrollableContainer;

PROCEDURE NewString(CONST x : ARRAY OF CHAR) : String;
VAR t : String;
BEGIN
	NEW(t, LEN(x)); COPY(x, t^); RETURN t
END NewString;

BEGIN
	InitStrings;
	InitPrototypes;
END WMScrollableComponents.

SystemTools.Free WMScrollableComponents~
