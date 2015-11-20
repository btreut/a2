MODULE WMNavigate; (** AUTHOR "staubesv"; PURPOSE "Windows navigation"; *)

IMPORT
	Modules, Kernel, Commands, Options, Locks, Strings, Raster, Plugins, Displays, KernelLog, Inputs, XML, WMMessages,
	WMRectangles, WMGraphics, WMGraphicUtilities, WMWindowManager, WMComponents, WMProperties, WMRestorable, Files, Dates;

CONST

	(* TaskList.style *)
	Text* = 0;
	Icons* = 1;

	(* TaskList.menuLocation *)
	Left* = 0;
	Top* = 1;
	Right* = 2;
	Bottom* = 3;

	(* TaskList.layoutMode *)
	Fixed* = 0; (* don't change entry width & size *)
	Default* =1; (* don't change entry height, decrease entry width if required to fit layout.width *)
	ScaleUp*= 2;	(* calculate default layout and then scale up to fit layout.width & layout.height *)
	ScaleUpWidthOnly* = 3;	(* calculate default layout and then scale up to fit layout.width & layout.height *)
	ScaleUpHeightOnly* = 4;	(* calculate default layout and then scale up to fit layout.width & layout.height *)
	Aspect* = 5;	(* Try to find optimum entry width & height, nofColumns, nofRows that maintains the aspect ratio desiredEntryWidth : desiredEntryHeight *)

	ThumbnailWidth = 128;
	ThumbnailHeight = 92;

	(* Specifies how often the timestamp of the window manager is polled *)
	UpdateInterval = 100; (* milliseconds *)

	(* Maximum number of windows that can be managed by components inside this module *)
	MaxNofWindows = 100;

	MaxNavigationWindows = 10;

	(* Active objects state *)
	Running = 0;
	Terminating = 1;
	Terminated = 2;

TYPE

	Layout = OBJECT
	VAR
		width, height : LONGINT; (* of overall space available *)
		entryWidth, entryHeight : LONGINT;

		(* entries in rightmost column are 'fixX + entryWidth' width and entries in last row are 'fixY + entryHeight' in height *)
		fixX, fixY : LONGINT;
		nofRows, nofColumns : LONGINT;
		nofEntries : LONGINT;

		(** Return position owning entry at x, y. Returns -1 if no entry owns the position *)
		PROCEDURE GetIndexOf(x, y : LONGINT) : LONGINT;
		VAR result, row, column  : LONGINT;
		BEGIN
			result := -1;
			IF (nofEntries > 0) & (nofRows > 0) & (nofColumns > 0) THEN
				column := x DIV entryWidth;
				row := y DIV entryHeight;
				IF (column < nofColumns) & (row < nofRows) THEN
					result := row * nofColumns + column;
					IF (result >= nofEntries) THEN result := -1; END;
				END;
			END;
			RETURN result;
		END GetIndexOf;

		(** Return the bounding box of the item hit at position x, y *)
		PROCEDURE GetPositionOf(x, y : LONGINT) : WMRectangles.Rectangle;
		VAR rect : WMRectangles.Rectangle; row, column : LONGINT;
		BEGIN
			rect := WMRectangles.MakeRect(0, 0, 0, 0);
			IF (nofEntries > 0) & (nofRows > 0) & (nofColumns > 0) THEN
				column := x DIV entryWidth;
				row := y DIV entryHeight;
				IF (column < nofColumns) & (row < nofRows) THEN
					rect.l := column * entryWidth;
					rect.r := rect.l + entryWidth;
					rect.t := row * entryHeight;
					rect.b := rect.t + entryHeight;
				END;
			END;
			RETURN rect;
		END GetPositionOf;

		PROCEDURE Compute(nofEntries, width, height, desiredEntryWidth, desiredEntryHeight, mode : LONGINT);
		BEGIN
			ASSERT(nofEntries >= 0);
			ASSERT((width >= 0) & (height >= 0));
			ASSERT((desiredEntryWidth > 0) & (desiredEntryHeight > 0));
			ASSERT((mode = Fixed) OR (mode = Default) OR (mode = ScaleUp) OR (mode = ScaleUpWidthOnly) OR (mode = ScaleUpHeightOnly) OR (mode = Aspect));
			SELF.nofEntries := nofEntries;
			SELF.width := width; SELF.height := height;
			SELF.entryWidth := desiredEntryWidth; SELF.entryHeight := desiredEntryHeight;
			fixX := 0; fixY := 0;
			IF (mode # Aspect) THEN
				ComputeDefault;
				IF (mode = Fixed) THEN
					entryWidth := desiredEntryWidth;
				END;
				IF (mode = ScaleUp) OR (mode = ScaleUpWidthOnly) THEN
					IF (nofEntries < nofColumns) THEN
						nofColumns := nofEntries;
						IF (nofColumns = 0) THEN nofColumns := 1; END;
					END;
					entryWidth := width DIV nofColumns;
					fixX := width MOD nofColumns;
				END;
				IF (mode = ScaleUp) OR (mode = ScaleUpHeightOnly) THEN
					entryHeight := height DIV nofRows;
					fixY := height MOD nofRows;
				END;
			ELSE
				ComputeAspect;
			END;
		END Compute;

		(* Try to fit the entries of size (entryWidth,entryHeight) as good as possible into a number of columns and rows. Scale down entryWidth if necessary *)
		PROCEDURE ComputeDefault; (* private *)
		VAR nofEntriesPerRow, nofAvailableRows, nofRequiredRows : LONGINT;
		BEGIN
			nofEntriesPerRow := width DIV entryWidth;
			IF (nofEntriesPerRow = 0) THEN nofEntriesPerRow := 1; END;
			IF (nofEntries > 0) & (width > 0) & (height > 0) THEN
				IF (nofEntries * entryWidth > width) THEN
					nofAvailableRows := height  DIV entryHeight;
					IF (nofAvailableRows = 0) THEN nofAvailableRows := 1; END;
					nofRequiredRows := (nofEntries + nofEntriesPerRow - 1) DIV nofEntriesPerRow;
					IF (nofAvailableRows > 1) THEN (* there is space for more than one row ... *)
						IF (nofRequiredRows <= nofAvailableRows) THEN (* place entries on multiple rows without decreasing entryWidth *)
							nofRows := nofRequiredRows;
							nofColumns := nofEntriesPerRow;
						ELSE (* place entries on multiple rows but also decrease entryWidth *)
							nofRows := nofAvailableRows;
							nofColumns := (nofEntries + nofRows - 1) DIV nofRows;
							entryWidth := width DIV nofColumns;
						END;
					ELSE (* there is only space for one row -> decrease entryWidth *)
						nofRows := 1;
						nofColumns := nofEntries;
						entryWidth := width DIV nofEntries;
						IF (entryWidth = 0) THEN entryWidth := 1; END;
					END;
				ELSE (* all entries fit on one row *)
					nofRows := 1;
					nofColumns := nofEntriesPerRow;
				END;
			ELSE (* all entries fit on one row *)
				nofRows := 1;
				nofColumns := nofEntriesPerRow;
			END;
			ASSERT((nofRows >= 1) & (nofColumns >= 0));
			ASSERT(entryWidth > 0); ASSERT(entryHeight > 0);
		END ComputeDefault;

		(* width, height of remaining area, nofEntries that still need to be placed *)
		PROCEDURE ComputeAspect;
		VAR entryRatio, areaRatio : REAL; eWidth, eHeight : LONGINT; doesFit : BOOLEAN;
		BEGIN
			entryRatio := entryWidth / entryHeight;
			areaRatio := width / height;
			doesFit := FALSE;
			IF (entryRatio >= areaRatio) THEN
				nofRows := 0;
				WHILE ~doesFit DO
					INC(nofRows);
					eHeight := height DIV nofRows;
					eWidth := ENTIER(eHeight / entryHeight * entryWidth);
					IF (eWidth = 0) THEN eWidth := 1; END;
					nofColumns := width DIV eWidth;
					IF (nofColumns = 0) THEN INC(nofColumns); END;
					doesFit := nofEntries <= nofRows * nofColumns;
				END;
			ELSE
				nofColumns := 0;
				WHILE ~doesFit DO
					INC(nofColumns);
					eWidth := width DIV nofColumns;
					eHeight := ENTIER(eWidth / entryWidth * entryHeight);
					IF (eHeight = 0) THEN eHeight := 1; END;
					nofRows := height DIV eHeight;
					IF (nofRows = 0) THEN INC(nofRows); END;
					doesFit := nofEntries <= nofRows * nofColumns;
				END;
			END;
			entryWidth := width DIV nofColumns;
			fixX := width MOD nofColumns;
			IF (entryWidth = 0) THEN entryWidth := 1; END;
			entryHeight := height DIV nofRows;
			fixY := height MOD nofRows;
			IF (entryHeight = 0) THEN entryHeight := 1; END;
			ASSERT((nofRows >= 1) & (nofColumns >= 0));
			ASSERT(entryWidth > 0); ASSERT(entryHeight > 0);
		END ComputeAspect;

		PROCEDURE Show;
		BEGIN
			KernelLog.String("--- Layout ---"); KernelLog.Ln;
			KernelLog.String("width: "); KernelLog.Int(width, 0);
			KernelLog.String(", height: "); KernelLog.Int(height, 0);
			KernelLog.Ln;
			KernelLog.String("nofEntries: "); KernelLog.Int(nofEntries, 0);
			KernelLog.Ln;
			KernelLog.String("nofRows: "); KernelLog.Int(nofRows, 0);
			KernelLog.String(", nofColumns: "); KernelLog.Int(nofColumns, 0);
			KernelLog.Ln;
			KernelLog.String("entryWidth: "); KernelLog.Int(entryWidth, 0);
			KernelLog.String(", entryHeight: "); KernelLog.Int(entryHeight, 0);
			KernelLog.Ln;
			KernelLog.String("fixX: "); KernelLog.Int(fixX, 0);
			KernelLog.String(", fixY: "); KernelLog.Int(fixY, 0);
			KernelLog.Ln;
		END Show;

	END Layout;

TYPE

	DoCloseWindow = OBJECT
	VAR
		window : WMWindowManager.Window;

		PROCEDURE &Init(window : WMWindowManager.Window);
		BEGIN
			ASSERT(window # NIL);
			SELF.window := window;
		END Init;

	BEGIN {ACTIVE}
		window.Close;
	END DoCloseWindow;

TYPE

	Info = RECORD
		nofWindows : LONGINT;
		windows : Windows;
		extImages : POINTER TO ARRAY OF WMGraphics.Image;
		focusIdx : LONGINT;
		wTimestamp : LONGINT;
		oTimestamp : LONGINT;
	END;

TYPE
	(*
	StoreCommand*=PROCEDURE{DELEGATE}(sender, par: ANY);	
	*)
	Base* = OBJECT(WMComponents.VisualComponent)
	VAR
		clDefault-, clSelected-, clMouseOver-, clSelectedMouseOver-,
		clTextDefault-, clTextSelected-, clTextMouseOver-, clTextSelectedMouseOver-,
		clIndicateHidden- : WMProperties.ColorProperty;

		borderWidth- : WMProperties.Int32Property;

		layoutMode- : WMProperties.Int32Property;
		itemWidth-, itemHeight- : WMProperties.Int32Property;

		info : Info;
		layout : Layout;
		lock : Locks.Lock; (* protects info, layout *)
		state : LONGINT;

		mouseOverIdx, lastMouseOverIdx : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrBase);
			NEW(clDefault, ProtoClDefault, NIL, NIL); properties.Add(clDefault);
			NEW(clSelected, ProtoClSelected, NIL, NIL); properties.Add(clSelected);
			NEW(clMouseOver, ProtoClMouseOver, NIL, NIL); properties.Add(clMouseOver);
			NEW(clSelectedMouseOver, ProtoClSelectedMouseOver, NIL, NIL); properties.Add(clSelectedMouseOver);
			NEW(clTextDefault, ProtoClTextDefault, NIL, NIL); properties.Add(clTextDefault);
			NEW(clTextSelected, ProtoClTextSelected, NIL, NIL); properties.Add(clTextSelected);
			NEW(clTextMouseOver, ProtoClTextMouseOver, NIL, NIL); properties.Add(clTextMouseOver);
			NEW(clTextSelectedMouseOver, ProtoClTextSelectedMouseOver, NIL, NIL); properties.Add(clTextSelectedMouseOver);
			NEW(clIndicateHidden, ProtoClIndicateHidden, NIL, NIL); properties.Add(clIndicateHidden);

			NEW(borderWidth, ProtoBorderWidth, NIL, NIL); properties.Add(borderWidth);

			NEW(layoutMode, ProtoLayoutMode, NIL, NIL); properties.Add(layoutMode);
			NEW(itemWidth, ProtoItemWidth, NIL, NIL); properties.Add(itemWidth);
			NEW(itemHeight, ProtoItemHeight, NIL, NIL); properties.Add(itemHeight);

			info.nofWindows := 0;
			Clear(info.windows);
			info.focusIdx := -1;
			info.wTimestamp := WMWindowManager.wTimestamp - 1;
			info.oTimestamp := WMWindowManager.oTimestamp - 1;
			NEW(layout);
			NEW(lock);
			state := Running;
			mouseOverIdx := -1; lastMouseOverIdx := -1;
		END Init;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			IF (data = clDefault) OR (data = clSelected) OR (data = clMouseOver) OR (data = clSelectedMouseOver) OR
				(data = clTextDefault) OR (data = clTextSelected) OR (data = clTextMouseOver) OR (data = clTextSelectedMouseOver) OR
				(data = clIndicateHidden)
			THEN
				Invalidate;
			ELSIF (data = layoutMode) OR (data = itemWidth) OR (data = itemHeight) OR (data = borderWidth) THEN
				Invalidate;
				WMWindowManager.IncWTimestamp; (* force layout update *)
			ELSE
				PropertyChanged^(sender, data);
			END;
		END PropertyChanged;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			IF enabled.Get() THEN
				lock.Acquire;
				mouseOverIdx := layout.GetIndexOf(x, y);
				lock.Release;
				IF (mouseOverIdx # lastMouseOverIdx) THEN
					lastMouseOverIdx := mouseOverIdx;
					IF (mouseOverIdx >= 0)  THEN
						Invalidate;
					END;
				END
			ELSE
				mouseOverIdx := -1; lastMouseOverIdx := -1;
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
			mouseOverIdx := -1; lastMouseOverIdx := -1;
			Invalidate
		END PointerLeave;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		VAR index : LONGINT; window : WMWindowManager.Window;
		BEGIN
			IF (keys = {}) OR ~enabled.Get()  THEN RETURN; END;
			IF (keys * {0, 2} # {}) THEN
				window := NIL;
				lock.Acquire;
				index := layout.GetIndexOf(x, y);
				IF (index >= 0) & (index < info.nofWindows) THEN
					window := info.windows[index];
				END;
				lock.Release;
				IF (window # NIL) THEN
					IF keys * {0} # {} THEN
						manager.SetIsVisible(window, TRUE);
						manager.SetFocus(window);
						manager.ToFront(window);
					ELSIF keys * {2} # {} THEN
						manager.SetIsVisible(window, ~window.isVisible);
					END;
				END;
			END;
		END PointerDown;

		PROCEDURE DrawInternal(canvas : WMGraphics.Canvas; x, y, width, height : LONGINT; window : WMWindowManager.Window; hasFocus, mouseOver : BOOLEAN; VAR extImage : WMGraphics.Image);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			ASSERT(lock.HasLock());
			ASSERT(window # NIL);
			rect := WMRectangles.MakeRect(x, y, x + width, y + height);

			IF mouseOver & hasFocus THEN
				canvas.Fill(rect, clSelectedMouseOver.Get(), WMGraphics.ModeSrcOverDst);
			ELSIF mouseOver THEN
				canvas.Fill(rect, clMouseOver.Get(), WMGraphics.ModeSrcOverDst);
			ELSIF hasFocus THEN
				canvas.Fill(rect, clSelected.Get(), WMGraphics.ModeSrcOverDst);
			ELSE
				canvas.Fill(rect, clDefault.Get(), WMGraphics.ModeSrcOverDst);
			END;

			WMGraphicUtilities.RectGlassShade(canvas, rect, borderWidth.Get(), hasFocus);
		END DrawInternal;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			row, column, x, y : LONGINT;
			width, height : LONGINT;
			i : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			lock.Acquire;
			IF (layout.nofEntries > 0) & (layout.width > 0) & (layout.height > 0) THEN
				row := 0; column := 0;
				FOR i := 0 TO info.nofWindows-1 DO
					x := column * layout.entryWidth;
					y := row * layout.entryHeight;

					width := layout.entryWidth;
					IF (column = layout.nofColumns - 1) THEN width := width + layout.fixX; END;

					height := layout.entryHeight;
					IF (row = layout.nofRows - 1) THEN height := height + layout.fixY; END;

					DrawInternal(canvas, x, y, width, height, info.windows[i], i = info.focusIdx, i = mouseOverIdx, info.extImages[i]);

					INC(column);
					IF (column >= layout.nofColumns) THEN
						column := 0;
						INC(row);
					END;
				END;
			END;
			lock.Release;
		END DrawBackground;

	END Base;

CONST

	Border = 2;
	TitleHeight = 20;

TYPE

	WindowOverview* = OBJECT(Base)
	VAR
		aux_canvas : WMGraphics.BufferCanvas;

		rect : WMRectangles.Rectangle;

		font : WMGraphics.Font;
		timer : Kernel.Timer;

		PROCEDURE CreateAuxCanvas(width, height : LONGINT; alpha : BOOLEAN) : WMGraphics.BufferCanvas;
		VAR canvas : WMGraphics.BufferCanvas; img : WMGraphics.Image;
		BEGIN
			rect := WMRectangles.MakeRect(0, 0, width, height);
			NEW(img);
			IF alpha THEN
				Raster.Create(img, width, height, Raster.BGRA8888);
			ELSE
				Raster.Create(img, width, height, WMWindowManager.format);
			END;
			NEW(canvas, img);
			RETURN canvas;
		END CreateAuxCanvas;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			PropertyChanged^(sender, data);
			IF (data = bounds) THEN
				lock.Acquire;
				UpdateLayout;
				lock.Release;
				Invalidate;
			END;
		END PropertyChanged;

		PROCEDURE UpdateLayout;
		VAR border : LONGINT;
		BEGIN
			ASSERT(lock.HasLock());
			border := borderWidth.Get();
			layout.Compute(info.nofWindows, bounds.GetWidth(), bounds.GetHeight(), itemWidth.Get() , itemHeight.Get(), layoutMode.Get());
			IF (layout.entryWidth - 2*border > 0) & (layout.entryHeight - TitleHeight - border > 0) THEN
				aux_canvas := CreateAuxCanvas(layout.entryWidth - 2*border, layout.entryHeight - TitleHeight - border, FALSE);
			ELSE
				aux_canvas := NIL;
			END;
		END UpdateLayout;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrWindowOverview);
			SetGenerator("WMNavigate.GenOverview");
			layoutMode.Set(Aspect);
			borderWidth.Set(Border);
			itemWidth.Set(ThumbnailWidth + 2*Border);
			itemHeight.Set(ThumbnailHeight + TitleHeight + Border);
			takesFocus.Set(TRUE);
			font := WMGraphics.GetFont("Oberon", 8, {});
			aux_canvas := CreateAuxCanvas(ThumbnailWidth, ThumbnailHeight, FALSE);
			NEW(timer);
		END Init;

		PROCEDURE DrawInternal(canvas : WMGraphics.Canvas; x, y, width, height : LONGINT; window : WMWindowManager.Window; hasFocus, mouseOver : BOOLEAN; VAR extImage : WMGraphics.Image);
		VAR
			image : Raster.Image;
			title : Strings.String;
			sizeX, sizeY : LONGINT;
			imgX, imgY, imgWidth, imgHeight, winWidth, winHeight : LONGINT;
			t_width, t_height : LONGINT;
			scaleX, scaleY : REAL;
			canvasState : WMGraphics.CanvasState;
		BEGIN
			DrawInternal^(canvas, x, y, width, height, window, hasFocus, mouseOver, extImage);
			canvas.SetFont(font);

			t_width := width - 2*Border;
			t_height := height - 2*Border - TitleHeight;

			IF (aux_canvas # NIL) THEN (* aux_canvas is protected by lock *)
				aux_canvas.Fill(rect, fillColor.Get(), WMGraphics.ModeSrcOverDst);

				winWidth := window.GetWidth(); (* TODO: Not threadsafe *)
				winHeight := window.GetHeight();

				scaleX := t_width / winWidth;
				scaleY := t_height / winHeight;

				IF (scaleX <= scaleY) THEN
					imgWidth := t_width;
					imgHeight := ENTIER(winHeight * scaleX);
					imgX := 0;
					imgY := t_height - imgHeight;
				ELSE
					imgWidth := ENTIER(winWidth * scaleY);
					imgHeight := t_height;
					imgX := (t_width - imgWidth) DIV 2;
					imgY := 0;
				END;

				window.Draw(aux_canvas, imgWidth, imgHeight, WMGraphics.ScaleBilinear);
				image := aux_canvas.GetImage();

				canvas.SaveState(canvasState);
				canvas.SetClipRect(WMRectangles.MakeRect(x + Border + imgX, y + TitleHeight + imgY, x + Border + imgX + imgWidth, y + imgY + TitleHeight + imgHeight));
				canvas.DrawImage(x + Border + imgX, y + TitleHeight + imgY, image, WMGraphics.ModeSrcOverDst);
				canvas.RestoreState(canvasState);
			END;

			title := window.GetTitle();
			IF (title = NIL) THEN title := StrNoName; END;

			font.GetStringSize(title^, sizeX, sizeY);

			IF ~window.isVisible THEN
				canvas.SetColor(clIndicateHidden.Get());
			ELSIF (hasFocus OR mouseOver) THEN
				canvas.SetColor(WMGraphics.White);
			ELSE
				canvas.SetColor(WMGraphics.Black);
			END;
			canvas.DrawString(x + (width - sizeX) DIV 2, y + 15, title^);
		END DrawInternal;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			state := Terminating;  timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Finalize;

		PROCEDURE Update;
		BEGIN
			IF (info.wTimestamp # WMWindowManager.wTimestamp) OR (info.oTimestamp # WMWindowManager.oTimestamp) THEN
				lock.Acquire;
				IF (info.wTimestamp # WMWindowManager.wTimestamp) THEN
					info.wTimestamp := WMWindowManager.wTimestamp;
					GetWindows(info.windows, info.nofWindows);
					IF (info.nofWindows > 0) THEN NEW(info.extImages, info.nofWindows); ELSE info.extImages := NIL; END;
					info.focusIdx := GetFocusOwnerIndex(info.windows, info.nofWindows);
					UpdateLayout;
				END;
				IF (info.oTimestamp # WMWindowManager.oTimestamp) THEN
					info.oTimestamp := WMWindowManager.oTimestamp;
					info.focusIdx := GetFocusOwnerIndex(info.windows, info.nofWindows);
				END;
				lock.Release;
			END;
			Invalidate;
		END Update;

	BEGIN {ACTIVE}
		LOOP
			IF (state # Running) THEN EXIT; END;
			Update;
			timer.Sleep(UpdateInterval);
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END WindowOverview;

TYPE

	TaskList* = OBJECT(Base)
	VAR
		style- : WMProperties.Int32Property; (* Text | Icons *)
		menuLocation- : WMProperties.Int32Property; (* Left | Top | Right | Bottom *)
		showThumbnails- : WMProperties.BooleanProperty;
		showNames- : WMProperties.BooleanProperty;

		viewport : WMWindowManager.ViewPort;
		dummyInfo : WMWindowManager.WindowInfo;

		lastKeys : SET;
		lastWindow : WMWindowManager.Window;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrTaskList);
			SetGenerator("WMNavigate.GenTaskList");
			NEW(style, ProtoTaskListStyle, NIL, NIL); properties.Add(style);
			NEW(menuLocation, ProtoTaskListMenuLocation, NIL, NIL); properties.Add(menuLocation);
			NEW(showThumbnails, ProtoTaskListShowThumbnails, NIL, NIL); properties.Add(showThumbnails);
			NEW(showNames, ProtoTaskListShowNames, NIL, NIL); showNames.Set(showWindowNames); properties.Add(showNames);

			CASE style.Get() OF
				| Text:
					itemWidth.Set(150); itemHeight.Set(20);
					layoutMode.Set(ScaleUp);
				| Icons:
					itemWidth.Set(40); itemHeight.Set(50);
					layoutMode.Set(Default); (*was Fixed*)
			ELSE
				itemWidth.Set(100); itemHeight.Set(50);
			END;

			viewport := WMWindowManager.GetDefaultView();
			WMWindowManager.ClearInfo(dummyInfo);

			lastKeys := {};
			lastWindow := NIL;
		END Init;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			PropertyChanged^(sender, data);
			IF (data = menuLocation) THEN
				Invalidate;
			ELSIF (data = bounds) OR (data = style) THEN
				lock.Acquire;
				layout.Compute(info.nofWindows, bounds.GetWidth(), bounds.GetHeight(), itemWidth.Get(), itemHeight.Get(), layoutMode.Get());
				lock.Release;
				Invalidate;
			END;
		END PropertyChanged;

		PROCEDURE GoToWindow(window : WMWindowManager.Window; moveViewport : BOOLEAN);
		VAR rect : WMRectangles.Rectangle; px, py : LONGINT;
		BEGIN
			ASSERT(window # NIL);
			manager.lock.AcquireWrite;
			manager.SetIsVisible(window, TRUE);
			manager.SetFocus(window);
			manager.ToFront(window);
			IF (viewport # NIL) THEN
				rect := WMRectangles.MakeRect(ENTIER(viewport.range.l), ENTIER(viewport.range.t), ENTIER(viewport.range.r), ENTIER(viewport.range.b));
				IF ~WMRectangles.IsContained(rect, window.bounds) THEN
					IF (window.bounds.l < viewport.range.l) OR (window.bounds.t < viewport.range.t) OR
						~WMRectangles.Intersect(rect, window.bounds)
					THEN
						IF (moveViewport) THEN (* re-position the viewport *)
							IF window.GetWidth() < (viewport.range.r - viewport.range.l) THEN
								px := window.bounds.l - ENTIER((viewport.range.r - viewport.range.l - window.GetWidth()) / 2);
							ELSE
								px := window.bounds.l - 20;
							END;
							IF window.GetHeight() < (viewport.range.b - viewport.range.t) THEN
								py := window.bounds.t - ENTIER((viewport.range.b - viewport.range.t - window.GetHeight()) / 2);
							ELSE
								py := window.bounds.t - 20;
							END;
							viewport.SetRange(px, py, viewport.range.r - viewport.range.l, viewport.range.b - viewport.range.t, TRUE);
						ELSE (* re-position the window *)
							IF window.GetWidth() < (viewport.range.r - viewport.range.l) THEN
								px := ENTIER(viewport.range.l + (viewport.range.r - viewport.range.l - window.GetWidth()) / 2);
							ELSE
								px := ENTIER(viewport.range.l) + 20;
							END;
							IF window.GetHeight() < (viewport.range.b - viewport.range.t) THEN
								py := ENTIER(viewport.range.t + (viewport.range.b - viewport.range.t - window.GetHeight()) / 2);
							ELSE
								py := ENTIER(viewport.range.t) + 20;
							END;
							manager.SetWindowPos(window, px, py);
						END;
					END;
				END;
			END;
			manager.lock.ReleaseWrite;
		END GoToWindow;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			lastKeys := {};
		END FocusLost;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		VAR
			index : LONGINT; window : WMWindowManager.Window; 
			info2 : WMWindowManager.WindowInfo;
			gx, gy: LONGINT;
			menu : MenuWindow;
			type, index2 : LONGINT;
			infoKeys : SET;
			res : LONGINT;
			rect : WMRectangles.Rectangle;
			closeWindow : DoCloseWindow;
			same: BOOLEAN;
		BEGIN
			IF ~enabled.Get() THEN RETURN; END;
			lastKeys := keys;
			IF (keys * {0, 1, 2} # {}) THEN
				window := NIL;
				lock.Acquire;
				index := layout.GetIndexOf(x, y);
				IF (index >= 0) & (index < info.nofWindows) THEN
					window := info.windows[index];
					rect := layout.GetPositionOf(x, y);
				END;
				lock.Release;
				IF (window # NIL) THEN
					same := lastWindow = window;
					IF 0 IN keys THEN lastWindow := window; ELSE lastWindow := NIL; END;
					IF keys * {0,1} # {} THEN
						IF same & window.isVisible THEN
							manager.SetIsVisible(window, FALSE);
						ELSE
							GoToWindow(window, 0 IN keys);
						END;
					ELSIF keys * {2} # {} THEN
						IF (menuLocation.Get() = Top) THEN
							ToWMCoordinates(rect.l, rect.t + ShadowWidth, gx, gy);
						ELSE
							ToWMCoordinates(rect.l, rect.b, gx, gy);
						END;
						IF window.GetInfo(info2) THEN
							NEW(menu, gx, gy, 200, menuLocation.Get(), showThumbnails.Get(), window, info2);
						ELSE
							NEW(menu, gx, gy, 200, menuLocation.Get(), showThumbnails.Get(), window, dummyInfo);
						END;
						menu.GetSelection(type, index2, infoKeys);
						IF ~(2 IN infoKeys) THEN
							IF (type = Document) THEN
								IF (info2.handleDocumentInfo # NIL) THEN
									info2.handleDocumentInfo(info2.openDocuments[index2], FALSE, res);
								END;
								GoToWindow(window, 0 IN infoKeys);
							ELSIF (type = SystemCommand) THEN
								IF (index2 = SystemCommand_Close) THEN
									NEW(closeWindow, window);
								ELSIF (index2 = SystemCommand_Hide) THEN
									manager.SetIsVisible(window, ~window.isVisible);
								ELSIF (index2 = SystemCommand_StayOnTop) THEN
									manager.SetWindowFlag(window, WMWindowManager.FlagStayOnTop, ~(WMWindowManager.FlagStayOnTop IN window.flags));
								ELSIF (index2 = SystemCommand_StayOnBottom) THEN
									manager.SetWindowFlag(window, WMWindowManager.FlagStayOnBottom, ~(WMWindowManager.FlagStayOnBottom IN window.flags));
								ELSIF (index2 = SystemCommand_WindowShot) THEN
									WindowShot(window);
								ELSIF (index2 = SystemCommand_StoreWindow) THEN
									StoreWindow(window);
							ELSIF (index2 = SystemCommand_Frame) THEN
									manager.SetWindowFlag(window, WMWindowManager.FlagFrame, ~(WMWindowManager.FlagFrame IN window.flags));
								END;
							END;
						END;
					END;
				ELSE
					lastWindow := NIL;
				END;
			END;
		END PointerDown;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR window : WMWindowManager.Window; windowCloser : DoCloseWindow; index : LONGINT;
		BEGIN
			PointerUp^(x, y, keys);
			IF ~enabled.Get() THEN RETURN; END;
			IF (lastKeys * {0, 2} = {0, 2}) & ((keys = {0}) OR (keys = {2})) THEN
				window := NIL;
				lock.Acquire;
				index := layout.GetIndexOf(x, y);
				IF (index >= 0) & (index < info.nofWindows) THEN
					window := info.windows[index];
				END;
				lock.Release;
				IF (window # NIL) & (window = lastWindow) THEN
					NEW(windowCloser, window);
				END;
			END;
			lastKeys := keys;
		END PointerUp;

		PROCEDURE DrawInternalIcons(canvas : WMGraphics.Canvas; x, y, width, height : LONGINT; window : WMWindowManager.Window; hasFocus, mouseOver : BOOLEAN; VAR extImage : WMGraphics.Image);
		VAR
			image : WMGraphics.Image;
			imageRect, indicatorRect : WMRectangles.Rectangle;
			title : Strings.String;
		BEGIN
			CASE menuLocation.Get() OF
				|Top:
					imageRect := WMRectangles.MakeRect(x + Border, y + MenuSize, x + width - Border, y + height - Border);
					indicatorRect := WMRectangles.MakeRect(x + Border, y + Border, x + width - Border, y + MenuSize - Border);
				|Left:
					imageRect := WMRectangles.MakeRect(x + MenuSize, y + Border, x + width - Border, y + height  - Border);
					indicatorRect := WMRectangles.MakeRect(x + Border, y + Border, x + MenuSize - Border, y + height - Border);
				|Right:
					imageRect := WMRectangles.MakeRect(x + Border, y + Border, x + width - MenuSize, y + height - Border);
					indicatorRect := WMRectangles.MakeRect(x + width - MenuSize + Border, y + Border, x + width - Border, y + height - Border);
				|Bottom:
					imageRect := WMRectangles.MakeRect(x + Border, y + Border, x + width - Border, y + height  - MenuSize);
					indicatorRect := WMRectangles.MakeRect(x + Border, y + height - MenuSize + Border, x + width - Border, y + height - Border);
			END;

			IF (window.icon # NIL) THEN
				image := window.icon;
			ELSE
				IF (extImage = NIL) THEN extImage := GetWindowImage(window, 64, 64); END;
				image := extImage;
			END;

			IF (image # NIL) THEN
				canvas.ScaleImage(image,
					WMRectangles.MakeRect(0, 0, image.width, image.height),
					imageRect,
					WMGraphics.ModeSrcOverDst,
					WMGraphics.ScaleBilinear
				);
				IF ~window.isVisible THEN
					canvas.Fill(indicatorRect, clIndicateHidden.Get(), WMGraphics.ModeSrcOverDst);
					WMGraphicUtilities.ExtRectGlassShade(canvas, indicatorRect, {}, 1, FALSE);
				END;
			END;
			IF (window.icon = NIL) THEN
				title := window.GetTitle();
				IF (title = NIL) THEN title := StrNoName; END;

				IF ~window.isVisible THEN
					canvas.SetColor(WMGraphics.Yellow);
				ELSIF hasFocus & ~mouseOver THEN
					canvas.SetColor(WMGraphics.White);
				ELSE
					canvas.SetColor(WMGraphics.Black);
				END;
				canvas.DrawString(x + 4, y + height - 5, title^);
			ELSE
				IF showNames.Get() & window.isVisible  & (window.info#NIL) THEN
					canvas.SetColor(WMGraphics.Black);
					canvas.DrawString(x+4, y + height-5, window.info.openDocuments[0].name); (* to do: show the ACTIVE window *)
				END;
			END;
		END DrawInternalIcons;

		PROCEDURE DrawInternalText(canvas : WMGraphics.Canvas; x, y, width, height : LONGINT; window : WMWindowManager.Window; hasFocus, mouseOver : BOOLEAN);
		VAR title : Strings.String;
		BEGIN
			title := window.GetTitle();
			IF (title = NIL) THEN title := StrNoName; END;
			IF ~window.isVisible THEN
				canvas.SetColor(clIndicateHidden.Get());
			ELSIF mouseOver & hasFocus THEN
				canvas.SetColor(clTextSelectedMouseOver.Get());
			ELSIF mouseOver THEN
				canvas.SetColor(clTextMouseOver.Get());
			ELSIF hasFocus THEN
				canvas.SetColor(clTextSelected.Get());
			ELSE
				canvas.SetColor(clTextDefault.Get());
			END;
			canvas.DrawString(x + 4, y + height - 5, title^);
		END DrawInternalText;

		PROCEDURE DrawInternal(canvas : WMGraphics.Canvas; x, y, width, height : LONGINT; window : WMWindowManager.Window; hasFocus, mouseOver : BOOLEAN; VAR extImage : WMGraphics.Image);
		BEGIN
			canvas.SetClipRect(WMRectangles.MakeRect(x, y, x + width, y + height));
			DrawInternal^(canvas, x, y, width, height, window, hasFocus, mouseOver, extImage);
			CASE style.Get() OF
				|Text: DrawInternalText(canvas, x, y, width, height, window, hasFocus, mouseOver);
				|Icons: DrawInternalIcons(canvas, x, y, width, height, window, hasFocus, mouseOver, extImage);
			ELSE
			END;
		END DrawInternal;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			state := Terminating;
			WMWindowManager.IncOTimestamp; (* unblock active body WMWindowManager.AwaitChange *)
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Finalize;

	BEGIN {ACTIVE}
		LOOP
			IF (state # Running) THEN EXIT; END;
			WMWindowManager.AwaitChange(info.wTimestamp, info.oTimestamp);
			IF (state # Running) THEN EXIT; END;
			lock.Acquire;
			IF (info.wTimestamp # WMWindowManager.wTimestamp) THEN
				info.wTimestamp := WMWindowManager.wTimestamp;
				GetWindows(info.windows, info.nofWindows);
				IF (info.nofWindows > 0) THEN NEW(info.extImages, info.nofWindows); ELSE info.extImages := NIL; END;
				info.focusIdx := GetFocusOwnerIndex(info.windows, info.nofWindows);
				layout.Compute(info.nofWindows, bounds.GetWidth(), bounds.GetHeight(), itemWidth.Get(), itemHeight.Get(), layoutMode.Get());
			END;
			IF (info.oTimestamp # WMWindowManager.oTimestamp) THEN
				info.oTimestamp := WMWindowManager.oTimestamp;
				info.focusIdx := GetFocusOwnerIndex(info.windows, info.nofWindows);
			END;
			lock.Release;
			Invalidate;
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END TaskList;

CONST
	ShadowWidth = 5;
	LineHeight = 20;

	LeftBorder = 25;
	RightBorder = 5;

	NofSystemCommands = 7;

	SystemCommand = 99;
	SystemCommand_Close = 0;
	SystemCommand_Hide = 1;
	SystemCommand_StayOnTop = 2;
	SystemCommand_StayOnBottom = 3;
	SystemCommand_Frame = 4;
	SystemCommand_WindowShot = 5;
	SystemCommand_StoreWindow = 6;
	Document = 1;

TYPE

	InfoView = OBJECT(WMComponents.VisualComponent)
	VAR
		window : WMWindowManager.Window;
		info : WMWindowManager.WindowInfo;
		nofDocuments: LONGINT;

		documentOffset, commandOffset, imageOffset : LONGINT;

		owner : MenuWindow;
		menuLocation : LONGINT;
		showThumbnails : BOOLEAN;

		type, index : LONGINT;
		keys : SET;

		xt, yt : LONGINT;

		image : WMGraphics.Image;
		imgX, imgY : LONGINT;

		imageYes, imageNo : WMGraphics.Image;

		PROCEDURE &New(owner : MenuWindow; menuLocation : LONGINT; showThumbnails : BOOLEAN);
		BEGIN
			ASSERT(owner # NIL);
			SELF.owner := owner;
			SELF.menuLocation := menuLocation;
			SELF.showThumbnails := showThumbnails;
			Init; (* no super call since Init does not exist in this scope *)
			SetNameAsString(Strings.NewString("InfoView"));
			nofDocuments := 0;
			keys := {};
			xt := -1; yt := -1;
			imageYes := WMGraphics.LoadImage("Navigation.rep://Yes.png", TRUE);
			imageNo := WMGraphics.LoadImage("Navigation.rep://No.png", TRUE);
		END New;

		PROCEDURE SetInfo(window : WMWindowManager.Window; CONST info : WMWindowManager.WindowInfo);
		VAR
			vc : WMComponents.VisualComponent; ptr : ANY; i : LONGINT; aux_canvas : WMGraphics.BufferCanvas;
			height, imageWidth, imageHeight : LONGINT;
		BEGIN
			SELF.window := window;
			Acquire;
			SELF.info := info;
			nofDocuments := 0;
			FOR i := 0 TO LEN(info.openDocuments)-1 DO
				IF (info.openDocuments[i].name # "") THEN INC(nofDocuments); END;
			END;
			vc := NIL;
			IF (info.vc.generator # NIL) THEN
				ptr := info.vc.generator();
				IF (ptr # NIL) & (ptr IS WMComponents.VisualComponent) THEN
					vc := ptr (WMComponents.VisualComponent);
				END;
			END;
			Release;

			height := NofSystemCommands * LineHeight + LineHeight; (* incl. 1 separator line *)
			IF (nofDocuments > 0) THEN
				height := height + nofDocuments * LineHeight + LineHeight;  (* incl. 1 separator line *)
			END;
			IF (vc # NIL) THEN
				vc.alignment.Set(WMComponents.AlignNone);
				vc.bounds.SetTop(height);
				vc.bounds.SetHeight(info.vc.height);
				height := height + ((info.vc.height + LineHeight - 1) DIV LineHeight) * LineHeight + RightBorder;
				vc.bounds.SetLeft(LeftBorder);
				vc.bounds.SetRight(bounds.GetWidth() - RightBorder);
			END;
			IF showThumbnails THEN
				imageWidth := bounds.GetWidth() - LeftBorder - RightBorder;
				imageHeight := ENTIER(3 * imageWidth / 4);

				NEW(image);
				Raster.Create(image, imageWidth, imageHeight, Raster.BGRA8888);

				NEW(aux_canvas, image);
				aux_canvas.Fill(WMRectangles.MakeRect(0, 0, imageWidth, imageHeight), WMGraphics.White, WMGraphics.ModeCopy);
				DrawIntoCanvas(window, aux_canvas, imageWidth, imageHeight, imgX, imgY);

				IF (menuLocation = Top) THEN
					imageOffset := RightBorder;
				ELSE
					imageOffset := height;
				END;

				height := height + ((imageHeight + LineHeight - 1) DIV LineHeight) * LineHeight + RightBorder;
			ELSE
				imageWidth := 0; imageHeight := 0;
			END;
			IF (vc # NIL) THEN
				IF (menuLocation = Top) THEN
					vc.bounds.SetTop(2*RightBorder + ((imageHeight + LineHeight - 1) DIV LineHeight) * LineHeight);
					vc.bounds.SetHeight(info.vc.height);
				END;
				AddContent(vc);
			END;

			bounds.SetHeight(height);

			IF (menuLocation = Top) THEN
				documentOffset := height - (NofSystemCommands + nofDocuments + 1) * LineHeight;
				commandOffset := height - NofSystemCommands * LineHeight;
			ELSE
				commandOffset := 0;
				documentOffset := (NofSystemCommands + 1) * LineHeight;
			END;

			Invalidate;
		END SetInfo;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			IF enabled.Get() THEN
				xt := x; yt := y;
				Invalidate;
			ELSE
				xt := -1; yt := -1;
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
			xt := -1; yt := -1;
			Invalidate
		END PointerLeave;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		BEGIN
			IF enabled.Get() THEN
				SELF.keys := keys;
				type := -1;
				index := -1;
				IF (commandOffset <= y) & (y < commandOffset + NofSystemCommands * LineHeight) THEN
					type := SystemCommand;
					IF (y < commandOffset + LineHeight) THEN
						index := SystemCommand_Close;
					ELSIF (y < commandOffset + 2 * LineHeight) THEN
						index := SystemCommand_Hide;
					ELSIF (y < commandOffset + 3 * LineHeight) THEN
						index := SystemCommand_StayOnTop;
					ELSIF (y < commandOffset + 4 * LineHeight) THEN
						index := SystemCommand_StayOnBottom;
					ELSIF (y < commandOffset + 5 * LineHeight) THEN
						index := SystemCommand_Frame;
					ELSIF (y < commandOffset + 6 * LineHeight) THEN
						index := SystemCommand_WindowShot;
					ELSIF (WMWindowManager.FlagStorable IN window.flags) & (y < commandOffset + 7 * LineHeight) THEN
						index := SystemCommand_StoreWindow;
					END;
				ELSIF (documentOffset <= y) & (y < documentOffset + nofDocuments * LineHeight) THEN
					type := Document;
					index := (y - documentOffset) DIV LineHeight;
				END;
			END;
			owner.Close;
		END PointerDown;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		VAR y : LONGINT;

			PROCEDURE IsHighlighted(y : LONGINT) : BOOLEAN;
			BEGIN
				RETURN (y <= yt) & (yt < y + LineHeight);
			END IsHighlighted;

			PROCEDURE DrawBg(y : LONGINT);
			BEGIN
				IF IsHighlighted(y) THEN
					canvas.Fill(WMRectangles.MakeRect(0, y, bounds.GetWidth(), y + LineHeight), LONGINT(060606A0H), WMGraphics.ModeSrcOverDst);
					canvas.SetColor(WMGraphics.White);
				ELSE
					canvas.SetColor(WMGraphics.Black);
				END;
			END DrawBg;

			PROCEDURE DrawDocuments(VAR y : LONGINT);
			VAR row : LONGINT;
			BEGIN
				FOR row := 1 TO nofDocuments DO
					DrawBg(y);
					IF info.openDocuments[row - 1].modified THEN
						canvas.SetColor(WMGraphics.Red);
					ELSIF (info.openDocuments[row - 1].hasFocus) THEN
						canvas.SetColor(00DA00FFH);
					ELSIF IsHighlighted(y) THEN
						canvas.SetColor(WMGraphics.White);
					ELSE
						canvas.SetColor(WMGraphics.Black);
					END;
					canvas.DrawString(LeftBorder, y + 16, info.openDocuments[row - 1].name);
					INC(y, LineHeight);
				END;
			END DrawDocuments;

			PROCEDURE DrawSystemCommands(VAR y : LONGINT);
			BEGIN
				canvas.SetColor(WMGraphics.Black);
				DrawBg(y);
				canvas.DrawString(LeftBorder, y + 16, "Close"); INC(y, LineHeight);
				DrawBg(y);
				DrawYesNo(y, window.isVisible);
				canvas.DrawString(LeftBorder, y + 16, "Visible"); INC(y, LineHeight);
				DrawBg(y);
				DrawYesNo(y, WMWindowManager.FlagStayOnTop IN window.flags);
				canvas.DrawString(LeftBorder, y + 16, "StayOnTop"); INC(y, LineHeight);


				IF (NofSystemCommands > 3) THEN
					DrawBg(y);
					DrawYesNo(y, WMWindowManager.FlagStayOnBottom IN window.flags);
					canvas.DrawString(LeftBorder, y + 16, "StayOnBottom"); INC(y, LineHeight);
				END;
				IF (NofSystemCommands > 4) THEN
					DrawBg(y);
					DrawYesNo(y, WMWindowManager.FlagFrame IN window.flags);
					canvas.DrawString(LeftBorder, y + 16, "Frame"); INC(y, LineHeight);
				END;
				IF (NofSystemCommands > 5) THEN
					DrawBg(y);
					canvas.DrawString(LeftBorder, y + 16, "WindowShot"); INC(y, LineHeight);
				END;
				IF (*(window IS WMComponents.FormWindow) &*)  (WMWindowManager.FlagStorable IN window.flags) & (NofSystemCommands > 6) THEN
					DrawBg(y);
					canvas.DrawString(LeftBorder, y + 16, "StoreWindow"); INC(y, LineHeight);
				END;
			END DrawSystemCommands;

			PROCEDURE DrawLine(VAR y : LONGINT);
			BEGIN
				canvas.Line(LeftBorder, y + (LineHeight DIV 2), bounds.GetWidth(), y + (LineHeight DIV 2), LONGINT(0C0C0C0FFH), WMGraphics.ModeCopy);
				INC(y, LineHeight);
			END DrawLine;

			PROCEDURE DrawImage(y : LONGINT);
			VAR canvasState : WMGraphics.CanvasState;
			BEGIN
				canvas.SaveState(canvasState);
				canvas.SetClipRect(WMRectangles.MakeRect(LeftBorder, y, bounds.GetWidth() - RightBorder, y + image.height));
				canvas.DrawImage(LeftBorder + imgX, y + imgY, image, WMGraphics.ModeCopy);
				WMGraphicUtilities.DrawRect(canvas,
					WMRectangles.MakeRect(LeftBorder, y, bounds.GetWidth() - RightBorder, y + image.height),
					LONGINT(0C0C0C0C0H), WMGraphics.ModeSrcOverDst
				);
				canvas.RestoreState(canvasState);
			END DrawImage;

			PROCEDURE DrawYesNo(y : LONGINT; value : BOOLEAN);
			BEGIN
				IF value & (imageYes # NIL) THEN
					canvas.DrawImage(5, y + 6, imageYes, WMGraphics.ModeSrcOverDst);
				ELSIF ~value & (imageNo # NIL) THEN
					canvas.DrawImage(5, y + 6, imageNo, WMGraphics.ModeSrcOverDst);
				END;
			END DrawYesNo;

		BEGIN
			Draw^(canvas);

			canvas.Fill(WMRectangles.MakeRect(0, 0, LeftBorder - 5, bounds.GetHeight()), LONGINT(0C0C0C0C0H), WMGraphics.ModeSrcOverDst);

			IF (menuLocation = Top) THEN
				IF (nofDocuments > 0) THEN
					y := documentOffset - LineHeight;
					DrawLine(y);
					DrawDocuments(y);
				END;
				y := commandOffset - LineHeight;
				DrawLine(y);
				DrawSystemCommands(y);
			ELSE
				y := commandOffset;
				DrawSystemCommands(y);
				DrawLine(y);
				IF (nofDocuments > 0) THEN
					DrawDocuments(y);
					DrawLine(y);
				END;
			END;
			IF showThumbnails & (image # NIL)THEN
				DrawImage(imageOffset);
			END;
		END Draw;

	END InfoView;

TYPE

	MenuWindow = OBJECT (WMComponents.FormWindow)
	VAR
		isClosed : BOOLEAN;
		shadowRectB, shadowRectR, borderRect : WMRectangles.Rectangle;
		infoView : InfoView;
		info : WMWindowManager.WindowInfo;

		close : BOOLEAN;

		PROCEDURE GetSelection(VAR type,  index : LONGINT; VAR keys : SET);
		BEGIN {EXCLUSIVE}
			AWAIT(close);
			type := infoView.type;
			index := infoView.index;
			keys := infoView.keys;
		END GetSelection;

		PROCEDURE&New(
			x, y, width, menuLocation : LONGINT;
			showThumbnails : BOOLEAN;
			window : WMWindowManager.Window; CONST info : WMWindowManager.WindowInfo
		);
		VAR height : LONGINT;
		BEGIN
			
			ASSERT((width > 0));
			isClosed := FALSE;

			SELF.info := info;

			NEW(infoView, SELF, menuLocation, showThumbnails);
			infoView.fillColor.Set(WMGraphics.White);
			infoView.bounds.SetWidth(width);
			infoView.SetInfo(window, info);
			height := infoView.bounds.GetHeight();

			Init(width+ ShadowWidth, infoView.bounds.GetHeight() + ShadowWidth, TRUE);

			SetContent(infoView);
			SetTitle(Strings.NewString("WMNavigateMenu"));
			infoView.alignment.Set(WMComponents.AlignNone);
			infoView.bounds.SetExtents(width, height);

			borderRect := WMRectangles.MakeRect(0, 0, width, height);

			shadowRectB := WMRectangles.MakeRect(ShadowWidth, height, width+ShadowWidth, height+ShadowWidth);
			shadowRectR := WMRectangles.MakeRect(width, ShadowWidth, width+ShadowWidth, height);

			IF (menuLocation = Top) THEN
				y := y - (infoView.bounds.GetHeight() + ShadowWidth);
			END;
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagNavigation, WMWindowManager.FlagHidden});
			manager.SetFocus(SELF);
		END New;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; w, h, q : LONGINT); (** override *)
		BEGIN
			Draw^(canvas, w, h, q);
			canvas.Fill(shadowRectB, 04FH, WMGraphics.ModeSrcOverDst);
			canvas.Fill(shadowRectR, 04FH, WMGraphics.ModeSrcOverDst);
			WMGraphicUtilities.DrawRect(canvas, borderRect, WMGraphics.Black, WMGraphics.ModeCopy);
		END Draw;

		PROCEDURE SetClosed;
		BEGIN
			BEGIN {EXCLUSIVE} close := TRUE; END;
		END SetClosed;

		PROCEDURE Close;
		BEGIN
			SetClosed;
			Close^;
		END Close;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT); (* override *)
		BEGIN
			IF ~(Inputs.Release IN flags) THEN
				IF keysym = 0FF54H THEN (* Cursor Down *)
				ELSIF keysym = 0FF52H THEN (* Cursor Up *)
				ELSIF (keysym = Inputs.KsTab) OR (keysym = Inputs.KsReturn) THEN
				ELSIF (keysym = Inputs.KsEscape) THEN
					Close;
				ELSE
				END;
			ELSE
			END;
		END KeyEvent;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			Close;
		END FocusLost;

	END MenuWindow;

CONST
	MenuSize = 10;

TYPE

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		myId : LONGINT;

		PROCEDURE &New*(id : LONGINT; component : WMComponents.VisualComponent; x, y, width, height : LONGINT; alpha : BOOLEAN; flags : SET);
		VAR title, nbr : ARRAY 32 OF CHAR;
		BEGIN
			ASSERT((component # NIL) & (width > 0) & (height > 0));
			Init(width, height, alpha);
			SELF.myId := id;
			SetContent(component);
			COPY("WMNavigate", title); Strings.IntToStr(id, nbr); Strings.Append(title, nbr);
			SetTitle(Strings.NewString(title));
			IF (WMWindowManager.FlagNavigation IN flags) THEN
				WMWindowManager.ExtAddViewBoundWindow(SELF, x, y, NIL, flags);
			ELSE
				WMWindowManager.ExtAddWindow(SELF, x, y, flags);
			END;
			component.bounds.SetExtents(width, height);
			pointerThreshold := 1;
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			windows[myId] := NIL;
		END Close;

	END Window;

TYPE
	Windows = ARRAY MaxNofWindows OF WMWindowManager.Window;

VAR
	windows : ARRAY MaxNavigationWindows OF Window;

	manager : WMWindowManager.WindowManager;
	viewport : WMWindowManager.ViewPort;

	StrWindowOverview : Strings.String;
	StrNoName : Strings.String;
	StrBase: Strings.String;
	StrTaskList: Strings.String;
	StrOverview: Strings.String;

	width, height : LONGINT;

	windowsAreHidden : BOOLEAN;
	navigationIsHidden : BOOLEAN;
	showWindowNames: BOOLEAN;

	ProtoClDefault, ProtoClSelected, ProtoClMouseOver, ProtoClSelectedMouseOver,
	ProtoClTextDefault, ProtoClTextSelected, ProtoClTextMouseOver, ProtoClTextSelectedMouseOver,
	ProtoClIndicateHidden : WMProperties.ColorProperty;
	ProtoBorderWidth : WMProperties.Int32Property;
	ProtoTaskListStyle, ProtoTaskListMenuLocation : WMProperties.Int32Property;
	ProtoTaskListShowThumbnails, ProtoTaskListShowNames : WMProperties.BooleanProperty;
	ProtoItemWidth, ProtoItemHeight : WMProperties.Int32Property;
	ProtoLayoutMode : WMProperties.Int32Property;

PROCEDURE GetWindowImage(window : WMWindowManager.Window; width, height : LONGINT) : WMGraphics.Image;
VAR image : WMGraphics.Image; canvas : WMGraphics.BufferCanvas; ignore : LONGINT;
BEGIN (* must hold window manager lock *)
	ASSERT((window # NIL));
	NEW(image);
	Raster.Create(image, width, height, Raster.BGRA8888);
	NEW(canvas, image);
	DrawIntoCanvas(window, canvas, width, height, ignore, ignore);
	RETURN image;
END GetWindowImage;

PROCEDURE GenerateName(prefix: Strings.String; VAR str: ARRAY OF CHAR);
VAR  i,j:LONGINT; num: ARRAY 32 OF CHAR; title: Files.FileName; c:CHAR;
BEGIN
	i:=0; j:=0;
	IF prefix#NIL THEN
		WHILE (i<LEN(prefix)) & (j<LEN(title)-1) DO
			c:=prefix[i];
			IF (c>="A")&(c<="Z") OR (c>="a")&(c<="z") OR(c>="0")&(c<="9") OR (c="_") OR (c=" ")THEN
				IF c=" " THEN c:="_" END;
				title[j]:=c; INC(i); INC(j);
			ELSE
				INC(i);
			END;
		END;
		title[j]:=0X;
		IF title="" THEN title:="ScreenShot" END;
	ELSE title:="ScreenShot"
	END;
	COPY(title, str);
END GenerateName;

PROCEDURE WindowShot(window: WMWindowManager.Window);
VAR str,fn: Files.FileName;  res: LONGINT; startTime: Dates.DateTime;
	img:WMGraphics.Image;
BEGIN
	GenerateName(window.GetTitle(),fn);
	IF fn="" THEN COPY("WindowShot",fn) END;
	startTime := Dates.Now();
	Strings.FormatDateTime("_yyyymmdd__hhnnss",startTime,str);
	Strings.Concat(fn,str,fn);
	Strings.Append(fn,".bmp");
	IF window IS WMWindowManager.DoubleBufferWindow THEN
		WMGraphics.StoreImage(window(WMWindowManager.DoubleBufferWindow).backImg, fn, res);
	ELSIF window IS WMWindowManager.BufferWindow THEN
		WMGraphics.StoreImage(window(WMWindowManager.BufferWindow).img, fn, res);
	ELSE 
		NEW(img); Raster.Create(img, window.GetWidth(), window.GetHeight(),Raster.BGRA8888);
		window.Draw(WMGraphics.GenCanvas(img), window.GetWidth(), window.GetHeight(), 0);
		WMGraphics.StoreImage(img, fn, res);
	END;
	IF res=0 THEN
		KernelLog.String("store window shot as "); KernelLog.String(fn); KernelLog.Ln;
	END;
END WindowShot;


PROCEDURE StoreWindow(window: WMWindowManager.Window);
VAR fn0,fn: Files.FileName;  s: ARRAY 6 OF CHAR; i, res: LONGINT; f:Files.File; w:Files.Writer;
	xml:XML.Content; msg: WMMessages.Message; 
BEGIN
	IF (WMWindowManager.FlagStorable IN window.flags) THEN
		GenerateName(window.GetTitle(),fn0);
		IF window IS WMComponents.FormWindow THEN
			Strings.Concat(fn0,".Cwd",fn); (* component window *)
			f:=Files.Old(fn); 
			i:=0;
			WHILE f#NIL DO 
				f:=NIL;
				Strings.IntToStr(i,s);
				COPY (fn0,fn);
				Strings.Append(fn,"_");
				Strings.Append(fn,s);
				Strings.Append(fn,".Cwd");
				f:=Files.Old(fn); 
				INC(i);
			END;
			(*? WMRestorable.StoreWindow*(window: WM.Window; CONST fileName: ARRAY OF CHAR);*)
			f:=Files.New(fn);
			IF f#NIL THEN 
				Files.OpenWriter(w,f,0);
				w.String('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'); w.Ln;
				window(WMComponents.FormWindow).ToXML().Write(w,NIL,0);
				w.Update;
				Files.Register(f);
				KernelLog.String("WMNavigate.StoreWindow  "); KernelLog.String(fn); KernelLog.Ln;
			END;	
		ELSE (* try to serialize*)
			msg.msgType := WMMessages.MsgSerialize; 
			window.Handle(msg);
		(*	IF (window.manager#NIL) & window.manager.SendMessage(window, msg) THEN END;*)
		END;
	END;
END StoreWindow;


PROCEDURE DrawIntoCanvas(window : WMWindowManager.Window; canvas : WMGraphics.BufferCanvas; width, height : LONGINT; VAR offsetX, offsetY : LONGINT);
VAR image : Raster.Image; winWidth, winHeight, imgWidth, imgHeight : LONGINT; scaleX, scaleY : REAL;
BEGIN (* must hold window manager lock *)
	ASSERT((window # NIL) & (canvas # NIL));
	image := canvas.GetImage();

	canvas.Fill(WMRectangles.MakeRect(0, 0, image.width, image.height), 0, WMGraphics.ModeCopy);

	winWidth := window.GetWidth(); (* TODO: Not threadsafe *)
	winHeight := window.GetHeight();

	scaleX := width / winWidth;
	scaleY := height / winHeight;

	IF (scaleX <= scaleY) THEN
		imgWidth := width;
		imgHeight := ENTIER(winHeight * scaleX);
		offsetX := 0;
		offsetY := height - imgHeight;
	ELSE
		imgWidth := ENTIER(winWidth * scaleY);
		imgHeight := height;
		offsetX := (width - imgWidth) DIV 2;
		offsetY := 0;
	END;
	window.Draw(canvas, imgWidth, imgHeight, WMGraphics.ScaleBilinear);
END DrawIntoCanvas;

PROCEDURE Clear(VAR windows : Windows);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(windows)-1 DO
		windows[i] := NIL;
	END;
END Clear;

PROCEDURE GetFocusOwnerIndex(CONST windows : Windows; nofWindows : LONGINT) : LONGINT; (* private *)
VAR index : LONGINT; focusOwner : WMWindowManager.Window;
BEGIN
	focusOwner := manager.GetFocusOwner();
	index := 0;
	WHILE (index < nofWindows) & (windows[index] # focusOwner) DO INC(index); END;
	IF (index >= LEN(windows)) THEN
		index := -1;
	END;
	RETURN index;
END GetFocusOwnerIndex;

(** Postcondition: {(windows # NIL) & (0 <= nofWindows < MaxNofWindows) & (windows[i < nofWindows] # NIL)} *)
PROCEDURE GetWindows(VAR windows : Windows; VAR nofWindows : LONGINT);
VAR
	window : WMWindowManager.Window;

	PROCEDURE IsUserWindow(window : WMWindowManager.Window) : BOOLEAN;
	BEGIN
		ASSERT(window # NIL);
		RETURN {WMWindowManager.FlagHidden, WMWindowManager.FlagDecorWindow} * window.flags = {};
	END IsUserWindow;

	PROCEDURE SortWindowsById(VAR windows : Windows);
	VAR temp : WMWindowManager.Window; i, j : LONGINT;
	BEGIN
		(* for now bubble sort is sufficient *)
		FOR i := 0 TO nofWindows-1 DO
			FOR j := 0 TO nofWindows-2 DO
				IF (windows[j].id > windows[j+1].id) THEN
					temp := windows[j+1];
					windows[j+1] := windows[j];
					windows[j] := temp;
				END;
			END;
		END;
	END SortWindowsById;

BEGIN
	ASSERT((manager # NIL));
	(* clear all references *)
	Clear(windows);
	manager.lock.AcquireWrite;
	nofWindows := 0;
	window := manager.GetFirst();
	WHILE (window # NIL) & (nofWindows < MaxNofWindows) DO
		IF IsUserWindow(window) THEN
			windows[nofWindows] := window;
			INC(nofWindows);
		END;
		window := manager.GetNext(window);
	END;
	manager.lock.ReleaseWrite;
	IF (nofWindows > 1) THEN SortWindowsById(windows); END;
END GetWindows;

PROCEDURE Open*(context : Commands.Context); (** [Options] id x y componentFile ~ *)
VAR
	options : Options.Options;
	id, x, y, w, h : LONGINT;
	filename : ARRAY 256 OF CHAR;
	content : XML.Content;
	flags : SET;
BEGIN {EXCLUSIVE}
	NEW(options);
	options.Add("f", "frame", Options.Flag);
	options.Add("s", "stayOnTop", Options.Flag);
	options.Add("v", "viewport", Options.Flag);
	options.Add("n", "names", Options.Flag);

	IF options.Parse(context.arg, context.out) THEN
		showWindowNames := options.GetFlag("names");
		context.arg.SkipWhitespace; context.arg.Int(id, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(x, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(y, FALSE);
		context.arg.SkipWhitespace; context.arg.String(filename);
		IF (filename # "") THEN
			IF (0 <= id) & (id < MaxNavigationWindows) THEN
				IF (windows[id] = NIL) THEN
					content := WMComponents.GetComponent(filename);
					IF (content # NIL) THEN
						IF (content IS WMComponents.VisualComponent) THEN
							w := content(WMComponents.VisualComponent).bounds.GetWidth();
							h := content(WMComponents.VisualComponent).bounds.GetHeight();
							IF (w <= 0) THEN w := width; END;
							IF (h <= 0) THEN h := height; END;
							flags := {WMWindowManager.FlagHidden};
							IF options.GetFlag("frame") THEN INCL(flags, WMWindowManager.FlagFrame); END;
							IF options.GetFlag("stayOnTop") THEN INCL(flags, WMWindowManager.FlagStayOnTop); END;
							IF options.GetFlag("viewport") THEN INCL(flags, WMWindowManager.FlagNavigation); END;
							
							NEW(windows[id], id, content(WMComponents.VisualComponent), x, y, w, h, TRUE, flags);
							WMWindowManager.IncWTimestamp;
							windows[id].CSChanged;
						ELSE
							context.out.String("WMNavigate: Expected visual component"); context.out.Ln;
						END;
					ELSE
						context.out.String("WMNavigate: Could not load component from file ");
						context.out.String(filename); context.out.Ln;
					END;
				ELSE
					context.out.String("WMNavigate: Window with id already open"); context.out.Ln;
				END;
			ELSE
				context.out.String("WMNavigate: Invalid id parameter"); context.out.Ln;
			END;
		ELSE
			context.out.String("WMNavigate.Open id x y width height componentFile ~"); context.out.Ln;
		END;
	END;
END Open;

PROCEDURE Close*(context : Commands.Context); (** id  ~ *)
VAR id : LONGINT;
BEGIN {EXCLUSIVE}
	IF context.arg.GetInteger(id, FALSE) & (0 <= id) & (id < MaxNavigationWindows) THEN
		IF (windows[id] # NIL) THEN
			windows[id].Close;
			windows[id] := NIL;
		ELSE
			context.out.String("WMNavigate: Window with id is not open"); context.out.Ln;
		END;
	ELSE
		context.out.String("WMNavigate: Invalid id parameter"); context.out.Ln;
	END;
END Close;

PROCEDURE ToggleVisibility*(context : Commands.Context); (** id ~ *)
VAR id : LONGINT;
BEGIN {EXCLUSIVE}
	IF context.arg.GetInteger(id, FALSE) & (0 <= id) & (id < MaxNavigationWindows) THEN
		IF (windows[id] # NIL) THEN
			manager.SetIsVisible(windows[id], ~windows[id].isVisible);
		ELSE
			context.out.String("WMNavigate: Window with id is not open"); context.out.Ln;
		END;
	ELSE
		context.out.String("WMNavigate: Invalid id parameter"); context.out.Ln;
	END;
END ToggleVisibility;

PROCEDURE HideNavigation*;
BEGIN {EXCLUSIVE}
	SetIsVisibleNavigation(FALSE);
	navigationIsHidden := TRUE;
END HideNavigation;

PROCEDURE RestoreNavigation*;
BEGIN {EXCLUSIVE}
	SetIsVisibleNavigation(TRUE);
	navigationIsHidden := FALSE;
END RestoreNavigation;

PROCEDURE ToggleNavigation*;
BEGIN {EXCLUSIVE}
	navigationIsHidden := ~navigationIsHidden;
	SetIsVisibleNavigation(~navigationIsHidden);
END ToggleNavigation;

PROCEDURE SetIsVisibleNavigation(isVisible : BOOLEAN);
VAR window : WMWindowManager.Window;
BEGIN
	manager.lock.AcquireWrite;
	window := manager.GetFirst();
	WHILE (window # NIL) DO
		IF (WMWindowManager.FlagNavigation IN window.flags) THEN
			manager.SetIsVisible(window, isVisible);
		END;
		window := manager.GetNext(window);
	END;
	manager.lock.ReleaseWrite;
END SetIsVisibleNavigation;

PROCEDURE FocusToNext*;
BEGIN
	SwitchFocus(FALSE);
END FocusToNext;

PROCEDURE FocusToPrevious*;
BEGIN
	SwitchFocus(TRUE);
END FocusToPrevious;

PROCEDURE SwitchFocus(backwards : BOOLEAN);
VAR windows : Windows; nofWindows, focusIdx : LONGINT;
BEGIN {EXCLUSIVE}
	GetWindows(windows, nofWindows);
	IF (nofWindows >= 1) THEN
		focusIdx := GetFocusOwnerIndex(windows, nofWindows);
		IF (focusIdx >= 0) THEN
			IF (nofWindows > 1) THEN
				IF backwards THEN
					IF focusIdx > 0 THEN
						DEC(focusIdx);
					ELSE
						focusIdx := nofWindows - 1;
					END;
				ELSE
					focusIdx := (focusIdx + 1) MOD nofWindows;
				END;
			END;
		ELSE
			focusIdx := 0; (* set focus to first user window *)
		END;
		IF (windows[focusIdx] = NIL) THEN RETURN (* can happen when no window has the focus initially *) END;
		ASSERT((0 <= focusIdx) & (focusIdx < LEN(windows)));
		manager.lock.AcquireWrite;
		manager.ToFront(windows[focusIdx]);
		manager.SetFocus(windows[focusIdx]);
		manager.lock.ReleaseWrite;
	END;
END SwitchFocus;

PROCEDURE HideAll*;
BEGIN {EXCLUSIVE}
	SetIsVisible(FALSE);
	windowsAreHidden := TRUE;
END HideAll;

PROCEDURE RestoreAll*;
BEGIN {EXCLUSIVE}
	SetIsVisible(TRUE);
	windowsAreHidden := FALSE;
END RestoreAll;

PROCEDURE ToggleAll*;
BEGIN {EXCLUSIVE}
	windowsAreHidden := ~windowsAreHidden;
	SetIsVisible(~windowsAreHidden);
END ToggleAll;

PROCEDURE SetIsVisible(isVisible : BOOLEAN);
VAR windows : Windows; nofWindows, i : LONGINT;
BEGIN
	GetWindows(windows, nofWindows);
	manager.lock.AcquireWrite;
	FOR i := 0 TO nofWindows-1 DO
		manager.SetIsVisible(windows[i], isVisible);
	END;
	manager.lock.ReleaseWrite;
END SetIsVisible;

(** Toggle minimized/fullscreen for the window that currently owns the focus *)
PROCEDURE ToggleFullscreen*;
VAR window : WMWindowManager.Window; newWidth, newHeight : LONGINT;
BEGIN {EXCLUSIVE}
	manager.lock.AcquireWrite;
	window := manager.GetFocusOwner();
	
	IF (window # NIL) & (window.flags * {WMWindowManager.FlagNavigation, WMWindowManager.FlagHidden, WMWindowManager.FlagNoResizing} = {}) THEN
		IF (window.GetWidth() = width) & (window.GetHeight() = height) THEN
			manager.SetWindowPos(window, window.normalBounds.l, window.normalBounds.t);
			newWidth := window.normalBounds.r - window.normalBounds.l;
			newHeight := window.normalBounds.b - window.normalBounds.t;
			SetIsVisibleNavigation(~navigationIsHidden);
		ELSE
			window.normalBounds := window.bounds;
			manager.SetWindowPos(window, ENTIER(viewport.range.l), ENTIER(viewport.range.t));
			newWidth := width;
			newHeight := height;
			SetIsVisibleNavigation(FALSE);
		END;
		manager.SetWindowSize(window, newWidth, newHeight);
		window.Resized(newWidth, newHeight);
	END;
	manager.lock.ReleaseWrite;
END ToggleFullscreen;

PROCEDURE MoveWindow*(context : Commands.Context);
VAR options : Options.Options; window : WMWindowManager.Window; x, y : LONGINT;
BEGIN {EXCLUSIVE}
	NEW(options);
	options.Add("d", "display", Options.Flag);
	IF options.Parse(context.arg, context.out) THEN
		IF context.arg.GetInteger(x, FALSE) & context.arg.GetInteger(y, FALSE) THEN
			IF options.GetFlag("display") THEN
				x := x * width;
				y := y * height;
			END;
			window := manager.GetFocusOwner();
			IF (window IS WMComponents.FormWindow) THEN
				manager.SetWindowPos(window, window.bounds.l + x, window.bounds.t + y);
			END;
		END;
	END;
END MoveWindow;

(** Close the window that currently owns the focus *)
PROCEDURE CloseWindow*;
VAR window : WMWindowManager.Window; formWindow : WMComponents.FormWindow;
BEGIN {EXCLUSIVE}
	window := manager.GetFocusOwner();
	IF window IS WMComponents.FormWindow THEN
		formWindow := window (WMComponents.FormWindow);
		formWindow.Close;
	END;
END CloseWindow;

(**
 * Set the range of the default view port. Can be used for virtual desktops.
 * Parameters:
 *	x, y : Position of viewport ovservable range (pixel)
 * 	w, h : width and height of viewport observable range (pixel, set to display width/height if omitted)
 *	"s" : show transition to new range
 *	"d": interpret x, y, w and h parameters as multiples of display width/height
 *)
PROCEDURE SetViewportRange*(context : Commands.Context); (** [options] [x y [w h]] ~ *)
VAR options : Options.Options; x, y, w, h : LONGINT;
BEGIN
	NEW(options);
	options.Add("s", "showTransition", Options.Flag);
	options.Add("d", "display", Options.Flag);

	IF options.Parse(context.arg, context.out) THEN
		x := 0; y := 0; w := 0; h := 0;
		context.arg.SkipWhitespace; context.arg.Int(x, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(y, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(w, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(h, FALSE);

		IF options.GetFlag("display") THEN
			x := x * width; w := w * width;
			y := y * height; h := h * height;
		END;

		IF w = 0 THEN w := width; END;
		IF h = 0 THEN h := height; END;

		viewport.SetRange(x, y, w, h, options.GetFlag("showTransition"));
	END;
END SetViewportRange;

PROCEDURE GenTaskList*() : XML.Element;
VAR t : TaskList;
BEGIN
	NEW(t); RETURN t;
END GenTaskList;

PROCEDURE GenOverview*() : XML.Element;
VAR o : WindowOverview;
BEGIN
	NEW(o); RETURN o;
END GenOverview;

PROCEDURE InitStrings;
BEGIN
	StrWindowOverview := Strings.NewString("WindowOverview");
	StrTaskList := Strings.NewString("TaskList");
	StrNoName := Strings.NewString("NoName");
	StrBase := Strings.NewString("Base");
	StrOverview:=Strings.NewString("Overview");
END InitStrings;

PROCEDURE InitProtos;
BEGIN
	NEW(ProtoClDefault, NIL, Strings.NewString("ClDefault"), Strings.NewString("Default color of item"));
	ProtoClDefault.Set(0A0A0A0A0H);
	NEW(ProtoClSelected, NIL, Strings.NewString("ClSelected"), Strings.NewString("Color of selected item"));
	ProtoClSelected.Set(060606A0H);
	NEW(ProtoClMouseOver, NIL, Strings.NewString("ClMouseOver"), Strings.NewString("Mouse over color of item"));
	ProtoClMouseOver.Set(0D0D0D0A0H);
	NEW(ProtoClSelectedMouseOver, NIL, Strings.NewString("ClSelectedMouseOver"), Strings.NewString("Mouse over color of selected item"));
	ProtoClSelectedMouseOver.Set(0F0F0F0A0H);

	NEW(ProtoClTextDefault, NIL, Strings.NewString("ClTextDefault"), Strings.NewString("Default text color"));
	ProtoClTextDefault.Set(WMGraphics.White);
	NEW(ProtoClTextSelected, NIL, Strings.NewString("ClTextSelected"), Strings.NewString("Text color of selected item"));
	ProtoClTextSelected.Set(WMGraphics.White);
	NEW(ProtoClTextMouseOver, NIL, Strings.NewString("ClTextMouseOver"), Strings.NewString("Text color of mouse over item"));
	ProtoClTextMouseOver.Set(WMGraphics.White);
	NEW(ProtoClTextSelectedMouseOver, NIL, Strings.NewString("ClTextSelectedMouseOver"), Strings.NewString("Text color of selected mouse over item"));
	ProtoClTextSelectedMouseOver.Set(WMGraphics.White);

	NEW(ProtoClIndicateHidden, NIL, Strings.NewString("ClIndicateHidden"), Strings.NewString("Color used to indicate hidden windows"));

	ProtoClIndicateHidden.Set(WMGraphics.Yellow);
	NEW(ProtoBorderWidth, NIL, Strings.NewString("BorderWidth"), Strings.NewString("Width of border"));
	ProtoBorderWidth.Set(2);
	NEW(ProtoTaskListStyle, NIL, Strings.NewString("Style"), Strings.NewString("Style of task representation"));
	ProtoTaskListStyle.Set(Icons);
	NEW(ProtoTaskListMenuLocation, NIL, Strings.NewString("MenuLocation"), Strings.NewString("Location of submenu relative to task list"));
	ProtoTaskListMenuLocation.Set(Bottom);
	NEW(ProtoTaskListShowThumbnails, NIL, Strings.NewString("ShowThumbnails"), Strings.NewString("Show window thumbnails?"));
	ProtoTaskListShowThumbnails.Set(TRUE);
	NEW(ProtoTaskListShowNames, NIL, Strings.NewString("ShowNames"), Strings.NewString("Show window names?"));
	ProtoTaskListShowNames.Set(TRUE);
	NEW(ProtoItemWidth, NIL, Strings.NewString("ItemWidth"), Strings.NewString("Width of task list item"));
	NEW(ProtoItemHeight, NIL, Strings.NewString("ItemHeight"), Strings.NewString("Height of task list item"));
	NEW(ProtoLayoutMode, NIL, Strings.NewString("LayoutMode"), Strings.NewString("Item layouting mode"));
END InitProtos;

PROCEDURE Init;
VAR plugin : Plugins.Plugin;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	viewport := WMWindowManager.GetDefaultView();
	plugin := Displays.registry.Get("");
	IF plugin # NIL THEN
		width := plugin(Displays.Display).width;
		height := plugin(Displays.Display).height;
	ELSE
		width := 1024;
		height := 768;
	END;
END Init;

PROCEDURE Cleanup;
VAR i : LONGINT;
BEGIN {EXCLUSIVE}
	FOR i := 0 TO LEN(windows)-1 DO
		IF (windows[i] # NIL) THEN windows[i].Close; END;
	END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init;
	InitStrings;
	InitProtos;
	windowsAreHidden := FALSE;
	navigationIsHidden := FALSE;
	ASSERT(manager # NIL);
END WMNavigate.

WMNavigate.SetViewportRange 0 0 ~
WMNavigate.SetViewportRange "-1" 0 1 1 sd ~

WMNavigate.MoveWindow -1280 ~

Example: Four virtual desktops with overview, depended on display resolution

WMNavigate.SetViewportRange -sd -1 0 1 1 ~	(* left desktop *)
WMNavigate.SetViewportRange -sd 0 0 1 1 ~		(* standard desktop *)
WMNavigate.SetViewportRange -sd -1 -1 1 1 ~	(* left/up desktop *)
WMNavigate.SetViewportRange -sd 0 -1 1 1 ~	(* up desktop *)

WMNavigate.SetViewportRange -sd -1 -1 2 2  ~	(* all four desktops *)

WMNavigate.Open -vs 1 0 0 Navigation:TaskList ~

WMNavigate.Open -vs 2 20 600 Navigation:TaskList ~

WMNavigate.Open -fs 6 20 20 Navigation:WindowList ~

WMNavigate.Close 1 ~

WMNavigate.ToggleVisibility 1 ~

WMNavigate.HideNavigation ~
WMNavigate.RestoreNavigation ~
WMNavigate.ToggleNavigation ~

SystemTools.Free WMNavigate ~
