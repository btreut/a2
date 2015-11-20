MODULE WMNavigator; (** AUTHOR "staubesv"; PURPOSE "Viewport in a window for navigation"; *)

(* STATUS: First draft - NOT STABLE!!! *)

IMPORT
	Modules, Kernel, Locks, Displays, Raster, Strings, XML, WMRectangles, WMGraphics, WMGraphicUtilities, WMWindowManager, WMComponents;

TYPE

	Level = RECORD
		x, y, width, height : LONGINT;
	END;

	OnDrawnProc = PROCEDURE {DELEGATE};

	ViewPort* = OBJECT (WMWindowManager.ViewPort);
	VAR
		backbuffer- : WMGraphics.Image;
		deviceRect : WMRectangles.Rectangle;
		width, height : LONGINT;
		canvas : WMGraphics.BufferCanvas;
		state : WMGraphics.CanvasState;
		internnavig, navig : BOOLEAN;
		fx, fy, inffx, inffy, factor, intfactor : REAL;
		lock : Locks.Lock;
		onDrawn : OnDrawnProc;

		zoomLevel : ARRAY 7 OF Level;
		currentZoomLevel : LONGINT;

		PROCEDURE &New*;
		BEGIN
			NEW(backbuffer);
			Raster.Create(backbuffer, 1280, 1024, Raster.DisplayFormat(Displays.color8888));
			range.l := 0; range.t := 0;
			range.r := range.l + 1280; range.b := range.t + 1024;
			width := 1280; height := 1024;
			deviceRect.l := 0; deviceRect.t := 0;
			deviceRect.r := 1280; deviceRect.b := 1024;
			width0 := 1280; height0 := 1024;
			desc := "Graphics adapter view";
			NEW(canvas, backbuffer);
			canvas.SetFont(WMGraphics.GetDefaultFont());
			canvas.SaveState(state);
			factor := 1; intfactor := 1;
			fx := factor; fy := factor; inffx := 1 ; inffy := inffx;
			internnavig := FALSE;
			NEW(lock);
			onDrawn := NIL;
			currentZoomLevel := 0;
			SetZoomLevels(1280, 1024);
		END New;

		PROCEDURE SetZoomLevels(width, height : LONGINT);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(zoomLevel)-1 DO
				zoomLevel[i].width := (i + 1) * width;
				zoomLevel[i].height :=(i + 1) * height ;
				zoomLevel[i].x := (zoomLevel[i].width - width) DIV 2;
				zoomLevel[i].y := (zoomLevel[i].height - height) DIV 2;
			END;
		END SetZoomLevels;

		PROCEDURE SetZoomLevel(level, xg, yg : LONGINT);
		BEGIN
			IF (level < 0) THEN level := 0;
			ELSIF (level >= LEN(zoomLevel)) THEN level := LEN(zoomLevel)-1; END;
			SetRange(xg - zoomLevel[level].x, yg - zoomLevel[level].y, zoomLevel[level].width, zoomLevel[level].height, TRUE);
			currentZoomLevel := level;
		END SetZoomLevel;

		PROCEDURE ChangeZoom(dz, xg, yg : LONGINT);
		BEGIN
			SetZoomLevel(currentZoomLevel + dz, xg, yg);
		END ChangeZoom;

		PROCEDURE ReInit(width, height, format : LONGINT; onDrawn : OnDrawnProc);
		VAR tf : REAL;
		BEGIN
			SELF.onDrawn := onDrawn;
			IF (width # SELF.width) OR (height # SELF.height) THEN
				lock.Acquire;
				SELF.width := width; SELF.height := height;
				IF (width > 0) & (height > 0) THEN
					NEW(backbuffer);
					Raster.Create(backbuffer, width, height, Raster.DisplayFormat(format));
					deviceRect.l := 0; deviceRect.t := 0;
					deviceRect.r := width; deviceRect.b := height;
					width0 := width; height0 := height;
					NEW(canvas, backbuffer);
					canvas.SetFont(WMGraphics.GetDefaultFont());
					canvas.SaveState(state);

					factor := width / (range.r - range.l);
					tf := height / (range.b - range.t);
					IF factor > tf THEN factor := tf END;
					fx := factor; fy := factor; inffx := 1 / factor; inffy := inffx;
					intfactor := factor;
					range.r := range.l + inffx * width;
					range.b := range.t + inffy * height;
					SetZoomLevels(width, height);
				ELSE
					canvas := NIL;
				END;
				lock.Release;
			END;
		END ReInit;

		PROCEDURE GetWMCoordinates*(CONST r : WMRectangles.Rectangle) : WMRectangles.Rectangle;
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			rect.l := ENTIER(range.l + r.l * inffx);
			rect.r := ENTIER(range.l + r.r * inffx + 0.5);
			rect.t := ENTIER(range.t + r.t * inffy);
			rect.b := ENTIER(range.t + r.b * inffy + 0.5);
			RETURN rect;
		END GetWMCoordinates;

		PROCEDURE GetWMPosition(x, y : LONGINT; VAR xg, yg : LONGINT);
		BEGIN
			xg := ENTIER(range.l + x * inffx);
			yg := ENTIER(range.t + y * inffy);
		END GetWMPosition;

		(**  Return the modifier keys that are pressed in the view *)
		PROCEDURE GetKeyState*(VAR state : SET);
		BEGIN
			state := {};
		END GetKeyState;

		(** Set the observed range. *)
		PROCEDURE SetRange*(x, y, w, h : REAL; showTransition : BOOLEAN);
		VAR
			sx, sy, sx2, sy2, dx, dy, dx2, dy2, x2, y2  : REAL;
			i, steps : LONGINT;
		CONST Steps = 16;

			PROCEDURE Set(x, y, w, h : REAL);
			VAR tf : REAL;
			BEGIN
				range.l := x;
				range.t := y;
				factor := (width) / w;
				tf := (height) / h;
				IF factor > tf THEN factor := tf END;
				fx := factor; fy := factor; inffx := 1 / factor; inffy := inffx;
				range.r := x + width * inffx;
				range.b := y + height * inffy;
				intfactor := factor;
				manager.RefreshView(SELF);
				IF onDrawn # NIL THEN onDrawn(); END;
			END Set;

		BEGIN
			IF w = 0 THEN w := 0.001 END;
			IF h = 0 THEN h := 0.001 END;
			IF showTransition THEN
				sx := range.l; sy := range.t;
				sx2 := range.r; sy2 := range.b;
				x2 := x + w; y2 := y + h;
				steps := Steps;
				IF (sx = x) & (sy = y) & (sx2 - sx = w) & (sy2- sy = h) THEN steps := 1 END;
				dx := (x - sx) / steps;
				dy := (y - sy) / steps;
				dx2 := (x2 - sx2) / steps;
				dy2 := (y2 - sy2) / steps;

				internnavig := TRUE; navig := TRUE;
				FOR i := 1 TO steps-1 DO
					Set(sx + dx * i, sy + dy * i, (sx2 + dx2 * i) - (sx + dx * i), (sy2 + dy2 * i) - (sy + dy * i))
				END;
				internnavig := FALSE; navig := FALSE
			END;
			Set(x, y, w, h)
		END SetRange;

		(** r in wm coordinates *)
		PROCEDURE Update*(r : WMRectangles.Rectangle; top : WMWindowManager.Window);
		BEGIN
			lock.Acquire;
			Draw(WMRectangles.ResizeRect(r, 1), top.prev);(* assuming the src-domain is only 1 *)
			lock.Release;
		END Update;

		PROCEDURE Refresh*(top : WMWindowManager.Window);
		BEGIN
			Update(WMRectangles.MakeRect(ENTIER(range.l)-1, ENTIER(range.t)-1, ENTIER(range.r) + 1, ENTIER(range.b) + 1), top)
		END Refresh;

		PROCEDURE DrawWindow(window : WMWindowManager.Window) : BOOLEAN;
		VAR title : Strings.String;
		BEGIN
			ASSERT(window # NIL);
			IF (window.isVisible & ~(WMWindowManager.FlagNavigation IN window.flags)) THEN
				title := window.GetTitle();
				RETURN (title = NIL) OR ((title^ # "Mouse Cursor"));
			ELSE
				RETURN FALSE;
			END;
		END DrawWindow;

		(* in wm coordinates *)
		PROCEDURE Draw(r : WMRectangles.Rectangle; top : WMWindowManager.Window);
		VAR cur : WMWindowManager.Window;
			wr, nr : WMRectangles.Rectangle;

			PROCEDURE InternalDraw(r : WMRectangles.Rectangle; cur : WMWindowManager.Window);
			VAR nr, cb, dsr : WMRectangles.Rectangle; width, height : LONGINT;
			BEGIN
				ASSERT(cur.isVisible);
				IF cur.useAlpha & (cur.prev # NIL)  THEN Draw(r, cur.prev)
				ELSE
					WHILE (cur # NIL) DO (* draw r in wm coordinates in all the windows from cur to top *)
						IF DrawWindow(cur) THEN
							cb := cur.bounds;
							nr := r; WMRectangles.ClipRect(nr, cb);
							dsr.l := ENTIER((nr.l - range.l) * fx) ; dsr.t := ENTIER((nr.t - range.t) * fy);
							dsr.r := ENTIER((nr.r - range.l) * fx + 0.5); dsr.b := ENTIER((nr.b - range.t) * fy + 0.5);
							IF  (~WMRectangles.RectEmpty(dsr)) & (WMRectangles.Intersect(dsr, deviceRect)) THEN
								canvas.SetClipRect(dsr);  (* Set clip rect to dsr, clipped at current window *)
								(* range can not be factored out because of rounding *)
								canvas.ClipRectAsNewLimits(ENTIER((cur.bounds.l - range.l) * fx), ENTIER((cur.bounds.t - range.t) * fy));
								width := ENTIER((cb.r - range.l)* fx) - ENTIER((cb.l - range.l) * fx);
								height := ENTIER((cb.b - range.t) * fy) - ENTIER((cb.t - range.t) * fy);
								IF navig THEN
									cur.Draw(canvas, width, height, WMGraphics.ScaleBox);
								ELSE
									cur.Draw(canvas, width, height, WMGraphics.ScaleBilinear);
								END;
								canvas.RestoreState(state);
							END;
						END;
						cur := cur.next
					END;
				END
			END InternalDraw;

		BEGIN
			IF (canvas # NIL) THEN
				cur := top;
				IF (cur # NIL) & (~WMRectangles.RectEmpty(r)) THEN
					IF DrawWindow(cur) THEN
						wr := cur.bounds;
						IF ~WMRectangles.IsContained(wr, r) THEN
							IF WMRectangles.Intersect(r, wr) THEN
								(* r contains wr calculate r -  wr and recursively call for resulting rectangles*)
								(* calculate top rectangle *)
								IF wr.t > r.t THEN WMRectangles.SetRect(nr, r.l, r.t, r.r, wr.t); Draw(nr, cur.prev) END;
								(* calculate bottom rectangle *)
								IF wr.b < r.b THEN WMRectangles.SetRect(nr, r.l, wr.b, r.r, r.b); Draw(nr, cur.prev) END;
								(* calculate left rectangle *)
								IF wr.l > r.l THEN WMRectangles.SetRect(nr, r.l, Strings.Max(r.t, wr.t), wr.l, Strings.Min(r.b, wr.b)); Draw(nr, cur.prev) END;
								(* calculate left rectangle *)
								IF wr.r < r.r THEN WMRectangles.SetRect(nr, wr.r, Strings.Max(r.t, wr.t), r.r, Strings.Min(r.b, wr.b)); Draw(nr, cur.prev) END;
								(* calculate overlapping *)
								nr := r; WMRectangles.ClipRect(nr, wr);
								IF ~WMRectangles.RectEmpty(nr) THEN InternalDraw(nr, cur) END
							ELSE Draw(r, cur.prev)
							END
						ELSE InternalDraw(r, cur)
						END
					ELSE
						Draw(r, cur.prev);
					END;
				END;
			END;
			IF (onDrawn # NIL) THEN onDrawn(); END;
		END Draw;

	END ViewPort;

TYPE

	Navigator = OBJECT(WMComponents.VisualComponent)
	VAR
		viewPort : ViewPort;

		selectedWindow : WMWindowManager.Window;

		timer : Kernel.Timer;
		alive, dead, refresh, doRefresh : BOOLEAN;

		offsetX, offsetY : LONGINT;
		lastX, lastY : LONGINT;

		PROCEDURE &Init;
		VAR style : WMWindowManager.WindowStyle;
		BEGIN
			Init^;
			NEW(viewPort);
			NEW(timer);
			alive := TRUE; dead := FALSE; refresh := TRUE; doRefresh := FALSE;
			manager.AddView(viewPort);
			style := manager.GetStyle();
			IF (style # NIL) THEN
				fillColor.Set(style.desktopColor);
			END;
		END Init;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			manager.RemoveView(viewPort);
		END Finalize;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			PropertyChanged^(sender, data);
			IF (data = bounds) THEN
				RecacheProperties;
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			viewPort.ReInit(bounds.GetWidth(), bounds.GetHeight(), Displays.color8888, Refresh);
			viewPort.manager.RefreshView(viewPort);
			Invalidate;
		END RecacheProperties;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
		END PointerLeave;

		PROCEDURE PointerDown(x, y: LONGINT; keys: SET);
		VAR xg, yg : LONGINT; rect : WMRectangles.Rectangle; title : Strings.String;
		BEGIN
			PointerDown^(x, y, keys);
			IF (0 IN keys) THEN
				viewPort.GetWMPosition(x, y, xg, yg);
				selectedWindow := manager.GetPositionOwner(xg, yg);
				IF (selectedWindow # NIL) THEN
					title := selectedWindow.GetTitle();
					IF (title # NIL) & ((title^ = "Old background") OR (title^ = "New background")) THEN selectedWindow := NIL; RETURN; END;
					manager.lock.AcquireRead;
					offsetX := (xg - selectedWindow.bounds.l);
					offsetY := (yg - selectedWindow.bounds.t);
					manager.lock.ReleaseRead;
				ELSE
					offsetX := 0; offsetY := 0;
				END;
			ELSIF (keys = {1}) THEN
				manager.GetPopulatedArea(rect);
				manager.lock.AcquireWrite;
				viewPort.SetRange(rect.l, rect.t, rect.r - rect.l, rect.b - rect.t, TRUE);
				manager.lock.ReleaseWrite;
			END;
		END PointerDown;

		PROCEDURE PointerMove(x, y: LONGINT; keys: SET);
		VAR xg, yg : LONGINT;
		BEGIN
			lastX := x; lastY := y;
			PointerMove^(x, y, keys);
			IF (0 IN keys) THEN
				IF (selectedWindow # NIL) THEN
					viewPort.GetWMPosition(x, y, xg, yg);
					manager.SetWindowPos(selectedWindow, xg - offsetX, yg - offsetY);
				END;
			END;
		END PointerMove;

		PROCEDURE WheelMove(dz: LONGINT);
		VAR xg, yg : LONGINT;
		BEGIN
			WheelMove^(dz);
			viewPort.GetWMPosition(lastX, lastY, xg, yg);
			viewPort.ChangeZoom(dz, xg, yg);
		END WheelMove;

		PROCEDURE PointerUp(x, y: LONGINT; keys: SET);
		BEGIN
			PointerUp^(x, y, keys);
			selectedWindow := NIL;
		END PointerUp;

		PROCEDURE Refresh;
		BEGIN {EXCLUSIVE}
			refresh := TRUE;
		END Refresh;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		VAR r0, r1, res : WMWindowManager.RealRect; rect : WMRectangles.Rectangle;
		BEGIN
			IF (viewPort.backbuffer.width = bounds.GetWidth()) & (viewPort.backbuffer.height = bounds.GetHeight()) THEN
				canvas.DrawImage(0, 0, viewPort.backbuffer,WMGraphics.ModeSrcOverDst);
			ELSE
				canvas.ScaleImage(viewPort.backbuffer, WMRectangles.MakeRect(0, 0, viewPort.backbuffer.width, viewPort.backbuffer.height),
					WMRectangles.MakeRect(0, 0, bounds.GetWidth(), bounds.GetHeight()), WMGraphics.ModeSrcOverDst, 1)
			END;
			r0 := viewport.range;
			r1 := viewPort.range;
			IF (r0.l > r1.l) THEN res.l := r0.l; ELSE res.l := r1.l; END;
			IF (r0.t > r1.t) THEN res.t := r0.t; ELSE res.t := r1.t; END;
			IF (r0.r < r1.r) THEN res.r := r0.r; ELSE res.r := r1.r; END;
			IF (r0.b < r1.b) THEN res.b := r0.b; ELSE res.b := r1.b; END;

			rect := WMRectangles.MakeRect(ENTIER(viewPort.fx * (res.l - r1.l)), ENTIER(viewPort.fy * (res.t - r1.t)), ENTIER(viewPort.fx * (res.r - r1.l)), ENTIER(viewPort.fy * (res.b - r1.t)));
			WMGraphicUtilities.DrawRect(canvas, rect, LONGINT(0FF0000FFH), WMGraphics.ModeCopy);
		END Draw;

	BEGIN {ACTIVE}
		manager.lock.AcquireWrite;
		viewPort.SetRange(-1280, -1024, 2560, 2048, FALSE);
		manager.lock.ReleaseWrite;
		manager.RefreshView(viewPort);
		Invalidate;
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(refresh OR ~alive);
				doRefresh := refresh;
				refresh := FALSE;
			END;
			timer.Sleep(30);
			IF ~alive THEN EXIT; END;
			IF doRefresh THEN
				doRefresh := FALSE;
				 Invalidate;
			END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Navigator;

TYPE

	Window = OBJECT(WMComponents.FormWindow)

		PROCEDURE Close;
		BEGIN
			Close^;
			window := NIL;
		END Close;

	END Window;

VAR
	manager : WMWindowManager.WindowManager;
	viewport : WMWindowManager.ViewPort;
	window : Window;

PROCEDURE GenNavigator*() : XML.Element;
VAR n : Navigator;
BEGIN
	NEW(n); RETURN n;
END GenNavigator;

PROCEDURE Init;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	viewport := WMWindowManager.GetDefaultView();
END Init;

PROCEDURE Open*;
VAR n : Navigator;
BEGIN {EXCLUSIVE}
	IF (window = NIL) THEN
		NEW(n); n.alignment.Set(WMComponents.AlignClient);
		NEW(window, 400, 200, TRUE);
		window.SetContent(n);
		WMWindowManager.ExtAddViewBoundWindow(window, 20, 20, NIL,
			{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagNavigation, WMWindowManager.FlagHidden});
	END;
END Open;

PROCEDURE Close*;
BEGIN {EXCLUSIVE}
	IF (window # NIL) THEN window.Close; window := NIL; END;
END Close;

BEGIN
	Modules.InstallTermHandler(Close);
	Init;
END WMNavigator.

WMNavigator.Open ~

WMNavigator.Close ~

SystemTools.Free WMNavigator ~
