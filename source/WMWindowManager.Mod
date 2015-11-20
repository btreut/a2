MODULE WMWindowManager;	(** AUTHOR "TF"; PURPOSE "Generic window manager"; *)

IMPORT
	Modules, KernelLog, Plugins, Locks, Strings, Messages := WMMessages, Graphics := WMGraphics, Raster, Rectangles := WMRectangles;

CONST
	FlagFrame* = 0; (** The window has a frame *)
	FlagClose* = 1; (** The window offers a close button; only frame windows *)
	FlagMinimize* = 2; (** The window offers a minimize button; only frame windows *)
	FlagStayOnTop* = 3; (** The window will always stay above all non stay on top windows *)
	FlagNonDispatched* = 4; (** The window has no message queue --> BE CAREFUL *)
	FlagNoFocus* = 5; (** The window can never get the keyboard focus *)
	FlagDecorWindow* = 6; (** The window is a decor window, associated to a master window *)
	FlagStayOnBottom* = 7; (** The window can not be moved up *)
	FlagNavigation* = 8; (** The window will always appear at the same position/size on the screen independent of the range of the viewport displaying it. *)
	FlagHidden* = 9; (** This flag indicates whether a window should be managed by window navigation tools. It does not influence the visibiliy or behaviour of the window *)
	FlagNoResizing* = 10; (** If set, window resizing is disabled *)
	FlagNoPointer*=11; (* if set, in window there will be no pointer visible --> touch screens *)
	FlagStorable*=12; (* window storable*)

	SizeMinHeight = 3; (* Minimum height of a window *)
	SizeMinWidth = 3; (* Minimum width of a window *)

	(* result codes for Window.OpenDocument *)
	Ok* = 0;
	Error* = 1;
	NotSupported* = 2;

	(* Window position for new windows added *)
	X0 = 30;
	Y0 = 80;

TYPE
	Rectangle = Rectangles.Rectangle;
	String = Strings.String;
	Message = Messages.Message;
	RealRect* = RECORD l*, t*, r*, b* : REAL END;

	PointerInfo* = OBJECT
	VAR hotX*, hotY* : LONGINT; img* : Graphics.Image;
	END PointerInfo;

	(**	All fields are read-only except for the module SkinEngine.Mod!
		Modifications of the instance that is owned by the window manager require
		the window manager write lock being held!
		Most of the information is used by WMDefaultWindows.Mod *)
	WindowStyle* = OBJECT
	VAR
		(** use bitmaps for frame windows? *)
		useBitmaps* : BOOLEAN;

		(** frame color if not using bitmaps (a = active, i = inactive) *)
		baCol*, biCol* : LONGINT;

		(** frame shading width if not using bitmaps (a = active, i = inactive) *)
		basw*, bisw* : LONGINT;

		(** height / width of frame windows th = top height, bh = bottom height, lw = left width, rw = right width *)
		th*, bh*, lw*, rw* : LONGINT;

		(** frame window bitmaps
			1st letter:	t = top, l = left, r = right, b = bottom decor window
			2nd letter:	a = active, i = inactive
			3rd letter:	a = left bitmap, b = middle bitmap (repeated), c = right bitmap
		*)
		taa*, tab*, tac*, tia*, tib*, tic*,
		laa*, lab*, lac*, lia*, lib*, lic*,
		raa*, rab*, rac*, ria*, rib*, ric*,
		baa*, bab*, bac*, bia*, bib*, bic* : Graphics.Image;

		(** Close and minimize button images (a = active, i = inactive) *)
		ca*, ci*, closeHover*,
		ma*, mi*, minimizeHover* : Graphics.Image;

		minimizeOffset* : LONGINT; (** offset correction for minimize button *)

		(** Window title position and color (a = active, i = inactive) *)
		atextX*, atextY*, atextColor*, itextX*, itextY*, itextColor* : LONGINT;

		bgColor*, fgColor*, selectCol*, desktopColor* : Graphics.Color;

		topFocusThreshold*, topThreshold*, bottomFocusThreshold*, bottomThreshold*,
		leftFocusThreshold*, leftThreshold*, rightFocusThreshold*, rightThreshold* : LONGINT;

		(* Initialize/reset to zero-style for windows *)
		PROCEDURE &Init*;
		BEGIN
			useBitmaps := FALSE;
			baCol := 0FFFFH; biCol := 0FF40H;
			basw := 4; bisw := 3;
			th := 20; bh := 3; lw := 3; rw := 3;

			(* images *)
			taa := NIL; tab := NIL; tac := NIL; tia := NIL; tib := NIL; tic := NIL;
			laa := NIL; lab := NIL; lac := NIL; lia := NIL; lib := NIL; lic := NIL;
			raa := NIL; rab := NIL; rac := NIL; ria := NIL; rib := NIL; ric := NIL;
			baa := NIL; bab := NIL; bac := NIL; bia := NIL; bib := NIL; bic := NIL;
			ca := Graphics.LoadImage("ZeroSkin.zip://aclose.png", TRUE);
			ci := Graphics.LoadImage("ZeroSkin.zip://iclose.png", TRUE);
			closeHover := NIL;
			ma := NIL; mi := NIL; minimizeHover := NIL;
			minimizeOffset := 0;

			(* window caption *)
			atextX := 5; atextY := 15; atextColor := LONGINT(0FFFF00FFH);
			itextX := 5; itextY := 15; itextColor := 04444FFH;

			(* desktop *)
			bgColor := LONGINT(08080FFFFH);
			fgColor := 0000000FFH;
			selectCol := 0FFFFH;
			desktopColor := LONGINT(08080FFFFH);

			topFocusThreshold := 0; topThreshold := 0;
			bottomFocusThreshold := 0; bottomThreshold := 0;
			leftFocusThreshold := 0; leftThreshold := 0;
			rightFocusThreshold := 0; rightThreshold := 0;
		END Init;

		(** calculate distances from images *)
		PROCEDURE Initialize*;
		BEGIN
			IF useBitmaps THEN
				IF tab # NIL THEN th := tab.height END;
				IF bab # NIL THEN bh := bab.height END;
				IF lab # NIL THEN lw := lab.width END;
				IF rab # NIL THEN rw := rab.width END;
			END
		END Initialize;

	END WindowStyle;

	DragInfo* = OBJECT
	VAR
		data*, sender* : ANY;
		onAccept*, onReject* : Messages.CompCommand;
		offsetX*, offsetY*: LONGINT;
	END DragInfo;

	(** List of decoration - windows to a master window *)
	DecorList* = OBJECT
	VAR next* : DecorList;
		w* : Window;
	END DecorList;

	(** A message preview procedure can set discard to TRUE to discard the message *)
	MessagePreviewProc* = PROCEDURE (VAR msg : Message; VAR discard : BOOLEAN);
	MessagePreviewList* = OBJECT
	VAR proc*: MessagePreviewProc;
			next*:MessagePreviewList;
	END MessagePreviewList;

	DocumentInfo* = RECORD
		id* : LONGINT;
		name* : ARRAY 32 OF CHAR; (* if name = "", this document info is not valid *)
		fullname* : ARRAY 256 OF CHAR;
		modified*, hasFocus* : BOOLEAN;
	END;

	VisualComponentInfo* = RECORD
		width*, height* : LONGINT; (* preferred width and height of visual component *)
		generator* : PROCEDURE {DELEGATE} () : ANY; (* NIL if no visual component available *)
	END;

	(** A window may provide information about currently opened documents. Additionally, it can provide a visual component that controls it. *)
	WindowInfo* = RECORD
		openDocuments* : ARRAY 16 OF DocumentInfo;
		handleDocumentInfo* : PROCEDURE {DELEGATE} (CONST info : DocumentInfo; new : BOOLEAN; VAR res : LONGINT);
		vc* : VisualComponentInfo;
	END;

	WindowInfoPtr = POINTER TO WindowInfo;

	Window* = OBJECT
	VAR
		id- : LONGINT;

		timestamp* : LONGINT; (* incremented at each call of procedure Draw *)

		(** Ranges in global coordinates *)
		bounds* : Rectangle; (** current range *)
		initialBounds* : Rectangle; (** range at window creation *)
		normalBounds* : Rectangle; (** range before toggling to fullscreen *)

		manager* : WindowManager;
		sequencer* : Messages.MsgSequencer;

		(** window state that may only be accessed by the window manager *)
		prev*, next* : Window; (** previous and next  window in z order *)
		title : String; (* window title *)
		info* : WindowInfoPtr;
		master* : Window; (** is only set if the window is a decor window *)
		view* : ViewPort;
		decor* : DecorList;
		flags* : SET;
		icon* : Graphics.Image; (** Optional icon for Window *)
		topW*, bottomW*, leftW*, rightW* : Window; (** Optional decor windows *)
		useAlpha* : BOOLEAN;
		isVisible* : BOOLEAN;
		pointerInfo- : PointerInfo;
		acceptDrag : BOOLEAN;
		reduceQuality- : BOOLEAN;

		PROCEDURE &Init*(w, h : LONGINT; alpha : BOOLEAN);
		BEGIN
			id := GetId();
			timestamp := 0;
			bounds := Graphics.MakeRectangle(0, 0, w, h);
			initialBounds := bounds;
			normalBounds := bounds;
			manager := NIL; sequencer := NIL;
			prev := NIL; next := NIL;
			title := NIL;
			info := NIL;
			master := NIL; decor := NIL;
			view := NIL;
			flags := {};
			icon := NIL;
			topW := NIL; bottomW := NIL; leftW := NIL; rightW := NIL;
			useAlpha := alpha;
			isVisible := TRUE;
			pointerInfo := NIL;
			acceptDrag := FALSE;
			reduceQuality := FALSE;
		END Init;

		PROCEDURE IsCallFromSequencer*() : BOOLEAN;
		BEGIN
			RETURN (sequencer # NIL) & (sequencer.IsCallFromSequencer())
		END IsCallFromSequencer;

		(** Return the window manager that handles the window *)
		PROCEDURE GetManager*() : WindowManager;
		BEGIN
			RETURN manager
		END GetManager;

		(** Set the window title as UTF8 string. *)
		PROCEDURE SetTitle*(title : String);
		BEGIN
			IF manager # NIL THEN manager.SetWindowTitle(SELF, title) ELSE SELF.title := title END
		END SetTitle;

		(** Return the title as UTF8 string. Returns NIL if no title is set *)
		PROCEDURE GetTitle*() : String;
		BEGIN
			IF manager # NIL THEN RETURN manager.GetWindowTitle(SELF) ELSE RETURN title END
		END GetTitle;

		PROCEDURE SetIcon*(icon : Graphics.Image);
		BEGIN
			IF (manager # NIL) THEN manager.SetWindowIcon(SELF, icon); ELSE SELF.icon := icon; END;
		END SetIcon;

		(** Return the height in client space *) (* go via manager *)
		PROCEDURE GetHeight*() : LONGINT;
		BEGIN
			RETURN bounds.b - bounds.t
		END GetHeight;

		(** Return the width in client space *) (* go via manager *)
		PROCEDURE GetWidth*() : LONGINT;
		BEGIN
			RETURN bounds.r - bounds.l
		END GetWidth;

		PROCEDURE SetInfo*(CONST info : WindowInfo);
		BEGIN
			IF (manager # NIL) THEN
				manager.SetWindowInfo(SELF, info);
			ELSE
				IF (SELF.info = NIL) THEN NEW(SELF.info); END;
				SELF.info^ := info;
			END;
		END SetInfo;

		PROCEDURE GetInfo*(VAR info : WindowInfo) : BOOLEAN;
		VAR infoPtr : WindowInfoPtr;
		BEGIN
			IF (manager # NIL) THEN
				RETURN manager.GetWindowInfo(SELF, info);
			ELSE
				infoPtr := SELF.info;
				IF (infoPtr # NIL) THEN
					info := infoPtr^;
				END;
				RETURN (infoPtr # NIL);
			END;
		END GetInfo;

		(** Resize is called by the WM if it wants to resize the window.
			width and height contain the desired new size. The Window should set width and height to acceptable
			values or return the current size, if resize is not supported *)
		PROCEDURE Resizing*(VAR width, height : LONGINT);
		BEGIN
			IF FlagNoResizing IN flags THEN
				width := GetWidth(); height := GetHeight();
			ELSIF width < SizeMinWidth THEN
				width := GetWidth();
			ELSIF height < SizeMinHeight THEN
				height := GetHeight();
			END
		END Resizing;

		(** May replace the back-image, if needed. MUST check if requested size is reasonable (0 < x * y < memory) *)
		PROCEDURE Resized*(width, height : LONGINT);
		END Resized;

		(** Invalidate a rectangle in window coordinates*)
		PROCEDURE Invalidate*(rect : Rectangle);
		BEGIN
			Rectangles.MoveRel(rect, bounds.l, bounds.t);
			Rectangles.ClipRect(rect, bounds);
			IF manager # NIL THEN manager.AddVisibleDirty(SELF, rect) END
		END Invalidate;

(** Message procedures *)
	(** Pointer Messages *)
		(** PointerDown is called via the generic message handler if the pointer (or a mouse button) is pressed down and
			a) the pointer is in the bounding box of the window AND IsHit returns TRUE for this position
			or
			b) another mouse button was pressed down on a position where a) was met and has not yet been released.

			x and y are in window coordinates but may lie out of the window boundaries in case b)
			keys is the set of buttons that are down
		*)
		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		END PointerDown;

		(** PointerMove is called via the generic message handler if the pointer (mouse) is moved and
			a) the pointer is in the bounding box of the window AND IsHit returns TRUE for this position
			or
			b) the pointer was pressed down on a position where a) was met and has not yet been released.

			x and y are in window coordinates but may lie out of the window boundaries.
			keys is the set of buttons that are down
		*)
		PROCEDURE PointerMove*(x, y : LONGINT; keys : SET);
		END PointerMove;

		PROCEDURE WheelMove*(dz : LONGINT);
		END WheelMove;

		(** PointerUp is called via the generic message handler if the pointer (or a mouse button) went up.
			x and y are in window coordinates but may lie out of the window boundaries.
			keys is the set of buttons that are STILL DOWN
		*)
		PROCEDURE PointerUp*(x, y : LONGINT; keys : SET);
		END PointerUp;

		(** PointerLeave is called via the generic message handler if the pointer has left the window with no button pressed. *)
		PROCEDURE PointerLeave*;
		END PointerLeave;

		(** DragOver is called via the message handler. *)
		PROCEDURE DragOver*(x, y: LONGINT; dragInfo : DragInfo);
		END DragOver;

		(** Dropped is called via the message handler to indicate an item has been dropped. *)
		PROCEDURE DragDropped*(x, y: LONGINT; dragInfo : DragInfo);
		END DragDropped;

		(** send the srcWindow a confirmation for the completed drag operation *)
		PROCEDURE ConfirmDrag*(accept : BOOLEAN; dragInfo : DragInfo);
		BEGIN
			IF dragInfo # NIL THEN
				IF accept THEN
					IF dragInfo.onAccept # NIL THEN dragInfo.onAccept(SELF, dragInfo) END
				ELSE
					IF dragInfo.onReject # NIL THEN dragInfo.onReject(SELF, dragInfo) END
				END
			END
		END ConfirmDrag;

		(** Start a drag operation. *)
		PROCEDURE StartDrag*(sender, data : ANY; img : Graphics.Image; offsetX, offsetY: LONGINT; onAccept, onReject : Messages.CompCommand) : BOOLEAN;
		BEGIN
			RETURN manager.StartDrag(SELF, sender, data, img, offsetX, offsetY, onAccept, onReject)
		END StartDrag;

(** Keyboard message *)

		(** KeyEvent is called via the generic message handler to signal a keyboard event.
			The window can determine wheter the key was pressed or released by examining the
			Inputs.Release flag in flags. ucs contains the unicode equivalent of the key. Special input editors
			send the generated unicode characters via KeyEvent.  *)
		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keysym : LONGINT);
		END KeyEvent;

(**  Focus messages *)

		(** FocusGot is called via the generic message handler if the keyboard focus is transfered to this window *)
		PROCEDURE FocusGot*;
		END FocusGot;

		(** FocusList is called via the generic message handler if the keyboard focus is transfered to some other window *)
		PROCEDURE FocusLost*;
		END FocusLost;

(** Style *)

		(** StyleChanged is called via the generic message handler if a change in the global style occurs. The
			Window should read all the style information it relies on and redraw itself *)
		PROCEDURE StyleChanged*;
		END StyleChanged;

(** Closing *)

		PROCEDURE CanClose*() : BOOLEAN;
		BEGIN
			RETURN TRUE
		END CanClose;

		(** Close is called via the generic message handler. *)
		PROCEDURE Close*;
		BEGIN
			IF manager # NIL THEN manager.Remove(SELF) END;
		END Close;

		(** Return true if the window is hit at the coordinates x and y (in window coordinates). Use
			this to generate non-rectangular windows.
			This Method will be called directly by the window manager. __> Don't block, don't crash !!
			*)
		PROCEDURE IsHit*(x, y : LONGINT) : BOOLEAN;
		BEGIN
			RETURN TRUE
		END IsHit;

		PROCEDURE SetPointerInfo*(pi : PointerInfo);
		BEGIN
			IF FlagNoPointer IN flags THEN pi := pointerNull END;
			IF pi # pointerInfo THEN
				pointerInfo := pi;
				IF manager # NIL THEN manager.CheckPointerImage END;
			END
		END SetPointerInfo;

		(** Generic message handler distributes messages to the different msg-handler methods *)
		PROCEDURE Handle*(VAR m : Message);
		BEGIN
			IF m.msgType = Messages.MsgKey THEN
				KeyEvent(m.x, m.flags, m.y)
			ELSIF m.msgType = Messages.MsgPointer THEN
				IF m.msgSubType = Messages.MsgSubPointerMove THEN
					IF (m.dz # 0) THEN WheelMove(m.dz) END;
					PointerMove(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerDown THEN PointerDown(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerUp THEN PointerUp(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerLeave THEN PointerLeave
				END
			ELSIF m.msgType = Messages.MsgDrag THEN
				IF m.msgSubType = Messages.MsgDragOver THEN
					IF (m.ext # NIL) THEN
						DragOver(m.x, m.y, m.ext(DragInfo))
					END
				ELSIF m.msgSubType = Messages.MsgDragDropped THEN
					IF (m.ext # NIL) THEN
						DragDropped(m.x, m.y, m.ext(DragInfo))
					END
				END
			ELSIF m.msgType = Messages.MsgClose THEN Close
			ELSIF m.msgType = Messages.MsgFocus THEN
				IF m.msgSubType = Messages.MsgSubFocusGot THEN FocusGot
				ELSIF m.msgSubType = Messages.MsgSubFocusLost THEN FocusLost
				END
			ELSIF m.msgType = Messages.MsgStyleChanged THEN StyleChanged
			ELSIF m.msgType = Messages.MsgResized THEN Resized(m.x, m.y)
			END;
		END Handle;

		(** Draw request form the window manager. The canvas becomes invalid when the method ends. The
		draw method may not modify window or WindowManager properties.
		w, h is the area in view coordinates, q is the Quality 0 lowest 1 mid 2 high. A window may ignore q  *)
		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		END Draw;

		(** Is called by the windowmanager with reduce set, if the window is resized or moved on slow machines *)
		PROCEDURE HintReduceQuality*(reduce : BOOLEAN);
		BEGIN
			IF reduce # reduceQuality THEN
				reduceQuality := reduce;
				IF ~reduceQuality THEN
					IF manager # NIL THEN manager.AddVisibleDirty(SELF, bounds) END
				END
			END
		END HintReduceQuality;

	END Window;

	(** assumes the window is size agnostic, handles all the zooming issues directly *)
	BufferWindow* = OBJECT(Window)
	VAR
		img* : Graphics.Image;
		canvas* : Graphics.BufferCanvas;
		canvasGen-: Graphics.CanvasGenerator;
		pointerThreshold* : LONGINT;

		PROCEDURE &Init*(w, h : LONGINT; alpha : BOOLEAN);
		BEGIN
			Init^(w, h, alpha);
			NEW(img);
			IF alpha THEN Raster.Create(img, w, h, Raster.BGRA8888) ELSE Raster.Create(img, w, h, format) END;
			SetCanvasGenerator(Graphics.GenCanvas);
			pointerThreshold := 1; (* invisible pixels are treated as invisble *)
		END Init;

		PROCEDURE SetCanvasGenerator*(canvasGen:Graphics.CanvasGenerator);
		BEGIN{EXCLUSIVE}
			SELF.canvasGen:=canvasGen; canvas:=canvasGen(img); 
			IF manager # NIL THEN manager.AddVisibleDirty(SELF, bounds) END
		END SetCanvasGenerator;
		
		PROCEDURE IsHit(x, y  : LONGINT) : BOOLEAN;
		VAR w, h : LONGINT; fx, fy : REAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # img.width) OR (h # img.height)) THEN
				fx := img.width / w; fy := img.height / h;
				RETURN Graphics.IsBitmapHit(ENTIER(x * fx), ENTIER(y * fy), pointerThreshold, img)
			ELSE RETURN Graphics.IsBitmapHit(x, y, pointerThreshold, img)
			END
		END IsHit;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		BEGIN
			IF reduceQuality THEN q := 0 END;
			IF img # NIL THEN
				IF (w = img.width) & (h = img.height) THEN
					IF useAlpha THEN canvas.DrawImage(0, 0, img, Graphics.ModeSrcOverDst)
					ELSE canvas.DrawImage(0, 0, img, Graphics.ModeCopy)
					END
				ELSE
					IF useAlpha THEN
						canvas.ScaleImage(img, Rectangles.MakeRect(0, 0, img.width, img.height),
							Rectangles.MakeRect(0, 0, w, h), Graphics.ModeSrcOverDst, q)
					ELSE
						canvas.ScaleImage(img, Rectangles.MakeRect(0, 0, img.width, img.height),
							Rectangles.MakeRect(0, 0, w, h), Graphics.ModeCopy, q)
					END
				END
			END;
			INC(timestamp);
		END Draw;

		PROCEDURE Invalidate*(rect : Rectangle);
		VAR w, h : LONGINT; fx, fy : REAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # img.width) OR (h # img.height))  THEN
				fx := w / img.width; fy := h / img.height;
				rect.l := ENTIER(rect.l * fx); rect.t := ENTIER(rect.t * fy);
				rect.r := ENTIER(rect.r * fx + 0.5); rect.b := ENTIER(rect.b * fy + 0.5)
			END;
			Invalidate^(rect)
		END Invalidate;

		PROCEDURE Handle*(VAR m : Message);
		VAR w, h : LONGINT; fx, fy : REAL;
		BEGIN
			w := GetWidth(); h := GetHeight();
			IF (w > 0) & (h > 0) & ((w # img.width) OR (h # img.height)) & (m.msgType = Messages.MsgPointer) THEN
				fx := img.width / w; fy := img.height / h; m.x := ENTIER(m.x * fx); m.y := ENTIER(m.y * fy)
			END;
			Handle^(m)
		END Handle;

	END BufferWindow;

	DoubleBufferWindow* = OBJECT(BufferWindow)
	VAR
		visibleCanvas : Graphics.BufferCanvas;
		backImg* : Graphics.Image;
		swapping, drawing : BOOLEAN;

		PROCEDURE &Init*(w, h: LONGINT; alpha : BOOLEAN);
		BEGIN
			NEW(backImg); 
			IF alpha THEN Raster.Create(backImg, w, h, Raster.BGRA8888) ELSE Raster.Create(backImg, w, h, format) END;
			Init^(w, h, alpha);
		END Init;

		PROCEDURE ReInit*(w, h : LONGINT);
		BEGIN {EXCLUSIVE}
			AWAIT(~drawing);
			IF useAlpha THEN
				 Raster.Create(img, w, h, Raster.BGRA8888);
				 Raster.Create(backImg, w, h, Raster.BGRA8888)
			ELSE
				Raster.Create(img, w, h, format);
				Raster.Create(backImg, w, h, format)
			END;
			visibleCanvas:=canvasGen(img);
			canvas:=canvasGen(backImg);
		END ReInit;
		
		PROCEDURE SetCanvasGenerator*(canvasGen:Graphics.CanvasGenerator);
		BEGIN
			SELF.canvasGen:=canvasGen; 
			visibleCanvas:=canvasGen(img);
			canvas:=canvasGen(backImg); 
			IF manager # NIL THEN manager.AddVisibleDirty(SELF, bounds) END
		END SetCanvasGenerator;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		BEGIN
			BEGIN{EXCLUSIVE}
				AWAIT(~swapping); drawing := TRUE;
			END;
			IF reduceQuality THEN q := 0 END;
			IF img # NIL THEN
				IF (w = img.width) & (h = img.height) THEN
					IF useAlpha THEN canvas.DrawImage(0, 0, img, Graphics.ModeSrcOverDst)
					ELSE canvas.DrawImage(0, 0, img, Graphics.ModeCopy)
					END
				ELSE
					IF useAlpha THEN
						canvas.ScaleImage(img, Rectangles.MakeRect(0, 0, img.width, img.height),
							Rectangles.MakeRect(0, 0, w, h), Graphics.ModeSrcOverDst, q)
					ELSE
						canvas.ScaleImage(img, Rectangles.MakeRect(0, 0, img.width, img.height),
							Rectangles.MakeRect(0, 0, w, h), Graphics.ModeCopy, q)
					END
				END
			END;
			BEGIN{EXCLUSIVE}
				drawing := FALSE;
			END;
			INC(timestamp);
		END Draw;

		PROCEDURE CopyRect*(rect : Rectangle);
		BEGIN {EXCLUSIVE}
			swapping := TRUE;
			AWAIT(~drawing);
			visibleCanvas.SetClipRect(rect);
			visibleCanvas.DrawImage(0, 0, backImg, Graphics.ModeCopy);
			visibleCanvas.SetClipRect(visibleCanvas.limits);
			swapping := FALSE
		END CopyRect;

		PROCEDURE Swap*;
		VAR tmp : Graphics.Image; tmpc : Graphics.BufferCanvas;
		BEGIN {EXCLUSIVE}
			swapping := TRUE;
			AWAIT(~drawing);
			tmp := img; img := backImg; backImg := tmp;
			tmpc := canvas; canvas := visibleCanvas; visibleCanvas := tmpc;
			swapping := FALSE
		END Swap;

	END DoubleBufferWindow;


	(** A ViewPort observes the global coordinate space. The WindowManager calls the view on all changes that occur
		in the observed range. *)
	ViewPort* = OBJECT (Plugins.Plugin)
	VAR
		next* : ViewPort;
		manager* : WindowManager;
		range* : RealRect;

		(* Width and height of viewport at 1:1 zoom. Will be set once in the constructor of the ViewPort implementation *)
		width0*, height0* : LONGINT; (* read-only! *)

		(** The WindowManager calls the Update Procedure in locked state. *)
		PROCEDURE Update*(r : Rectangle; top : Window);
		END Update;

		(** The WindowManager calls the Update Procedure in locked state. *)
		PROCEDURE Refresh*(top : Window);
		END Refresh;

		(** Set the observed range *)
		PROCEDURE SetRange*(x, y, w, h : REAL; showTransition : BOOLEAN);
		END SetRange;

		(**  Return the modifier keys that are pressed in the view *)
		PROCEDURE GetKeyState*(VAR state : SET);
		END GetKeyState;

	END ViewPort;

	Decorator* = PROCEDURE {DELEGATE} (w : Window);

	WindowManager* = OBJECT(Plugins.Plugin)
	VAR
		pointerNull*, pointerStandard*, pointerMove*, pointerText*, pointerCrosshair*,
		pointerLeftRight*, pointerUpDown*, pointerULDR*, pointerURDL*, pointerLink* : PointerInfo;
		decorate* : Decorator;
		viewRegistry- : Plugins.Registry;
		sequencer- : Messages.MsgSequencer; (** PROTECTED *)
		lock- : Locks.RWLock; (** PROTECTED *)
		messagePreviewList : MessagePreviewList;
		style : WindowStyle;

		PROCEDURE &Init*;
		BEGIN
			NEW(pointerNull);
			InitCursors;
			decorate := NIL;
			NEW(viewRegistry, "View#", "Views Port Window Manager");
			NEW(sequencer, Handle); lock := sequencer.lock;
			messagePreviewList := NIL;
			NEW(style);
		END Init;

		PROCEDURE InitCursors;
		BEGIN
			LoadCursor("ZeroSkin.zip://arrow.png", 0, 0, pointerStandard);
			LoadCursor("ZeroSkin.zip://move.png", 15, 15, pointerMove);
			LoadCursor("ZeroSkin.zip://text.png", 13, 12, pointerText);
			LoadCursor("ZeroSkin.zip://crosshair.png", 13, 12, pointerCrosshair);
			LoadCursor("ZeroSkin.zip://leftright.png", 13, 12, pointerLeftRight);
			LoadCursor("ZeroSkin.zip://updown.png", 13, 12, pointerUpDown);
			LoadCursor("ZeroSkin.zip://uldr.png", 13, 12, pointerULDR);
			LoadCursor("ZeroSkin.zip://urdl.png", 13, 12, pointerURDL);
			LoadCursor("ZeroSkin.zip://hand.png", 6, 0, pointerLink);
		END InitCursors;

		PROCEDURE ZeroSkin*;
		BEGIN
			lock.AcquireWrite;
			style.Init;
			SetStyle(style);
			InitCursors;
			lock.ReleaseWrite
		END ZeroSkin;

		PROCEDURE ShutDown*;
		BEGIN
			ASSERT(lock.HasWriteLock());
			Plugins.main.Remove(viewRegistry)
		END ShutDown;

(** Window management *)

		(** Add adds a window at pos l, t with flags *)
		PROCEDURE Add*(l, t : LONGINT; item : Window; flags:SET);
		END Add;

		(** Remove removes a window *)
		PROCEDURE Remove*(item : Window);
		END Remove;

		(** Set the position of a window *)
		PROCEDURE SetWindowPos*(vs : Window; x, y : LONGINT);
		END SetWindowPos;

		(** Set the size of a window. Return the new size in width and height *)
		(** If the window contains left, top, right or bottom, SetWindowSize is called
			appropriately *)
		PROCEDURE SetWindowSize*(vs : Window; VAR width, height : LONGINT);
		END SetWindowSize;

		(** Add a region to be refreshed *)
		PROCEDURE AddDirty*(VAR rect:Rectangle);
		END AddDirty;

		(** Add a dirty region. The region is in window coordinates and will be clipped against non transparent
			windows above *)
		PROCEDURE AddVisibleDirty*(w : Window; rect : Rectangle);
		END AddVisibleDirty;

		(** Set the keyboard focus to the window w *)
		PROCEDURE SetFocus*(w : Window);
		END SetFocus;

		(** Add a decoration window w to window to. The window w must separately be added to the wm *)
		(** A window MUST NOT be added more than once *)
		(** MUST hold lock *)
		PROCEDURE AddDecorWindow*(to, decor : Window);
		VAR dl : DecorList;
		BEGIN
			lock.AcquireWrite;
			INCL(decor.flags, FlagDecorWindow);
			INCL(decor.flags, FlagHidden);
			decor.master := to;
			NEW(dl); dl.w := decor; dl.next := to.decor; to.decor := dl;
			lock.ReleaseWrite
		END AddDecorWindow;

		(** Remove a decoration window w from window from. The window w must separately be removed from the wm *)
		(** MUST hold lock *)
		PROCEDURE RemoveDecorWindow*(w, from : Window);
		VAR dl : DecorList;
		BEGIN
			lock.AcquireWrite;
			IF (from.decor # NIL) & (from.decor.w = w) THEN from.decor := from.decor.next
			ELSE
				dl := from.decor;
				WHILE (dl.next # NIL) & (dl.next.w # w) DO dl := dl.next END;
				IF dl.next # NIL THEN dl.next := dl.next.next END
			END;
			lock.ReleaseWrite
		END RemoveDecorWindow;

		PROCEDURE SetStyle*(x : WindowStyle);
		VAR m : Message;
		BEGIN
			ASSERT(style # NIL);
			style := x; m.msgType := Messages.MsgStyleChanged; m.ext := style;
			Broadcast(m)
		END SetStyle;

		PROCEDURE GetStyle*() : WindowStyle;
		BEGIN
			ASSERT(style # NIL);
			RETURN style
		END GetStyle;

		(** Move Window w to front. If FlagStayOnTop is not set in w.flags, w will stay behind all windows with this flag set *)
		PROCEDURE ToFront*(w : Window);
		END ToFront;

		(** Move Window w to the background. If FlagStayOnTop is not set in w.flags, w will stay behind all windows *)
		PROCEDURE ToBack*(w : Window);
		END ToBack;

		PROCEDURE SetIsVisible*(w : Window; isVisible : BOOLEAN);
		VAR d : DecorList;
		BEGIN
			ASSERT(w # NIL);
			lock.AcquireWrite;
			IF (w.isVisible # isVisible) THEN
				w.isVisible := isVisible;
				IF (w.leftW # NIL) THEN w.leftW.isVisible := isVisible; END;
				IF (w.rightW # NIL) THEN w.rightW.isVisible := isVisible; END;
				IF (w.topW # NIL) THEN w.topW.isVisible := isVisible; END;
				IF (w.bottomW # NIL) THEN w.bottomW.isVisible := isVisible; END;
				AddDirty(w.bounds);
				IF (w.decor # NIL) THEN
					d := w.decor;
					WHILE (d # NIL) & (d.w # NIL) DO
						AddDirty(d.w.bounds);
						d := d.next;
					END;
				END;
				IncOTimestamp;
			END;
			lock.ReleaseWrite;
		END SetIsVisible;

		(** Set icon for a given window. Icon may be set to NIL. *)
		PROCEDURE SetWindowIcon*(w : Window; icon : Graphics.Image);
		VAR tw : Window;
		BEGIN
			ASSERT(w # NIL);
			lock.AcquireWrite;
			w.icon := icon;
			tw := w.topW;
			IF tw # NIL THEN AddVisibleDirty(tw, tw.bounds) END;
			lock.ReleaseWrite;
			IncOTimestamp;
		END SetWindowIcon;

		(** Return the window at postition x, y in global space. *)
		(** Windows that have the FlagNavigate flag set will not be considered *)
		(** Must hold WM lock *)
		PROCEDURE GetPositionOwner*(x, y : LONGINT) : Window;
		END GetPositionOwner;

		PROCEDURE GetFocusOwner*() : Window;
		END GetFocusOwner;

		(** Set the title of a window as UTF-8 string *)
		PROCEDURE SetWindowTitle*(w : Window; title : String);
		VAR tw : Window;
		BEGIN
			lock.AcquireWrite;
			w.title := title;
			tw := w.topW;
			IF tw # NIL THEN AddVisibleDirty(tw, tw.bounds) END;
			lock.ReleaseWrite;
			IncWTimestamp; (* since navigation elements care about window title *)
		END SetWindowTitle;

		(** Get the title of a window as UTF-8 string *)
		PROCEDURE GetWindowTitle*(w : Window) : String;
		BEGIN
			RETURN w.title
		END GetWindowTitle;

		PROCEDURE SetWindowInfo*(w : Window; CONST info : WindowInfo);
		BEGIN
			ASSERT(w # NIL);
			lock.AcquireWrite;
			IF (w.info = NIL) THEN NEW(w.info); END;
			w.info^ := info;
			lock.ReleaseWrite;
			IncOTimestamp;
		END SetWindowInfo;

		PROCEDURE GetWindowInfo*(w : Window; VAR info : WindowInfo) : BOOLEAN;
		VAR infoPtr : WindowInfoPtr;
		BEGIN
			ASSERT(w # NIL);
			lock.AcquireRead;
			infoPtr := w.info;
			IF (infoPtr # NIL) THEN
				info := infoPtr^;
			END;
			lock.ReleaseRead;
			RETURN (infoPtr # NIL);
		END GetWindowInfo;

		(**	Set or unset a window flag
			Note: Setting FlagStayOnTop unsets FlagStayOnBottom and vice versa *)
		PROCEDURE SetWindowFlag*(w : Window; flag : LONGINT; value : BOOLEAN);
		BEGIN
			ASSERT(w # NIL);
			ASSERT((flag = FlagFrame) OR (flag = FlagStayOnTop) OR (flag = FlagStayOnBottom) OR (flag = FlagHidden));
		END SetWindowFlag;

		(** Set if the window is willing to accept a dropped item *)
		PROCEDURE SetAcceptDrag*(w : Window; accept : BOOLEAN);
		BEGIN
			lock.AcquireWrite;
			w.acceptDrag := accept;
			lock.ReleaseWrite
		END SetAcceptDrag;

		PROCEDURE StartDrag*(w : Window; sender, data : ANY; img : Graphics.Image; offsetX, offsetY: LONGINT; onAccept, onReject : Messages.CompCommand) : BOOLEAN;
		END StartDrag;

		(** a pointer button must be pressed *)
		PROCEDURE TransferPointer*( to : Window) : BOOLEAN;
		END TransferPointer;

		(** Adjust pointer to new position / check picture *)
		PROCEDURE CheckPointerImage*;
		END CheckPointerImage;

(** View management *)

		(** Add a view *)
		PROCEDURE AddView*(v : ViewPort);
		END AddView;

		(** Add the whole View.range as dirty and cause a redraw *)
		PROCEDURE RefreshView*(v : ViewPort);
		END RefreshView;

		(** RemoveView from windowmanager *)
		PROCEDURE RemoveView*(v : ViewPort);
		END RemoveView;

(** Messages *)

		PROCEDURE Broadcast*(VAR m : Message);
		END Broadcast;

		PROCEDURE SendMessage*(dest : Window; VAR m : Message) : BOOLEAN;
		BEGIN
			IF dest.sequencer # NIL THEN RETURN dest.sequencer.Add(m)
			ELSE dest.Handle(m); RETURN TRUE
			END
		END SendMessage;

		(** Install a message preview procedure. The window manager calls the MessagePreviewProc for
		all external messages so that they can be recorded, changed or discarded *)
		PROCEDURE InstallMessagePreview*(x : MessagePreviewProc);
		VAR mpl : MessagePreviewList;
		BEGIN
			lock.AcquireWrite;
			NEW(mpl); mpl.next := messagePreviewList; mpl.proc := x; messagePreviewList := mpl;
			lock.ReleaseWrite
		END InstallMessagePreview;

		(** Remove a MessagePreviewProc *)
		PROCEDURE RemoveMessagePreview*(x : MessagePreviewProc);
		VAR cur : MessagePreviewList;
		BEGIN
			lock.AcquireWrite;
			IF (messagePreviewList # NIL) & (messagePreviewList.proc = x) THEN messagePreviewList := messagePreviewList.next
			ELSE
				cur := messagePreviewList;
				WHILE cur # NIL DO
					IF (cur.next # NIL) & (cur.next.proc = x) THEN cur.next := cur.next.next; lock.ReleaseWrite; RETURN
					ELSE cur := cur.next END
				END
			END;
			lock.ReleaseWrite
		END RemoveMessagePreview;

		(** Preview message to all installed message preview handlers. Only to be used by WindowManager itself *)
		PROCEDURE PreviewMessage*(VAR m : Message; VAR discard : BOOLEAN); (* protected *)
		VAR mpl : MessagePreviewList;
		BEGIN
			ASSERT(lock.HasReadLock());
			discard := FALSE;
			mpl := messagePreviewList;
			WHILE (mpl # NIL) & ~discard DO mpl.proc(m, discard); mpl := mpl.next END;
		END PreviewMessage;

(** Enumeration *)

	(** Get the first "user" window --> May return NIL if only background and pointer window are installed *)
	(** Must hold lock *)
		PROCEDURE GetFirst*() : Window;
		END GetFirst;

		(** Get the window next "user" window on top of x *)
		PROCEDURE GetNext*(x : Window) : Window;
		END GetNext;

		(** Get the "user" window below x *)
		PROCEDURE GetPrev*(x : Window) : Window;
		END GetPrev;

		(** Replace the background window with w. Return the current background window *)
		PROCEDURE ReplaceBackground*(w : Window) : Window;
		END ReplaceBackground;

		(** Return the area that is actually occupied *)
		PROCEDURE GetPopulatedArea*(VAR r : Rectangle);
		END GetPopulatedArea;

		(** Internal handler for message that are directed to the window manager never call directly ! *)
		PROCEDURE HandleInternal*(VAR msg : Messages.Message); (** PROTECTED *)
		BEGIN
			ASSERT(sequencer.IsCallFromSequencer())
		END HandleInternal;

		(** All external events of the window manager are inserted here *)
		PROCEDURE Handle*(VAR msg : Messages.Message);
		VAR discard : BOOLEAN;
		BEGIN
			IF sequencer.IsCallFromSequencer() THEN
				PreviewMessage(msg, discard);
				IF ~discard THEN HandleInternal(msg) END
			ELSE
				IF ~sequencer.Add(msg) THEN
					KernelLog.String("A message sent to the WM could not be handled "); KernelLog.Ln
				END
			END
		END Handle;

	END WindowManager;

VAR
	registry- : Plugins.Registry;
	pointerNull: PointerInfo;

	(* Changes whenever a Window is added or removed to/from a WindowManager *)
	wTimestamp- : LONGINT;

	(* Changes whenever the keyboard focus is given to another window or the visibility of a window changed *)
	oTimestamp- : LONGINT;

	(* Coordinate offsets use to determine position of a new window *)
	x1, y1 : LONGINT;

	format* : Raster.Format;

	nextId : LONGINT;
	
	standardCursorImage: Graphics.Image;

(* Get a unique identifier *)
PROCEDURE GetId() : LONGINT;
BEGIN {EXCLUSIVE}
	INC(nextId);
	RETURN nextId;
END GetId;

PROCEDURE IncWTimestamp*;
BEGIN {EXCLUSIVE}
	INC(wTimestamp);
END IncWTimestamp;

PROCEDURE IncOTimestamp*;
BEGIN {EXCLUSIVE}
	INC(oTimestamp);
END IncOTimestamp;

(** Block until a window is added/removed, changes its visibility or the keyboard focus changes *)
PROCEDURE AwaitChange*(wTs, oTs : LONGINT);
BEGIN {EXCLUSIVE}
	AWAIT((wTimestamp # wTs) OR (oTimestamp # oTs));
END AwaitChange;

PROCEDURE ClearInfo*(VAR info : WindowInfo);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(info.openDocuments)-1 DO
		info.openDocuments[i].id := 0;
		info.openDocuments[i].name := "";
		info.openDocuments[i].fullname := "";
		info.openDocuments[i].modified := FALSE;
		info.openDocuments[i].hasFocus := FALSE;
	END;
	info.handleDocumentInfo := NIL;
	info.vc.width := 0;
	info.vc.height := 0;
	info.vc.generator := NIL;
END ClearInfo;

PROCEDURE NewString*(CONST x : ARRAY OF CHAR) : String;
VAR t : String;
BEGIN
	NEW(t, LEN(x)); COPY(x, t^); RETURN t
END NewString;

PROCEDURE LoadCursor*(CONST name : ARRAY OF CHAR; hx, hy : LONGINT; VAR pi : PointerInfo);
BEGIN
	IF pi = NIL THEN NEW(pi) END;
	pi.img := Graphics.LoadImage(name, TRUE); pi.hotX := hx; pi.hotY := hy;
	IF pi.img = NIL THEN
		KernelLog.String("Picture not loaded : "); KernelLog.String(name); KernelLog.Ln;
		IF standardCursorImage = NIL THEN CreateStandardCursorImage END;
		pi.img := standardCursorImage; pi.hotX := 0; pi.hotY := 0;
	END
END LoadCursor;

PROCEDURE GetDefaultManager*() : WindowManager;
VAR p : Plugins.Plugin;
BEGIN
	p := registry.Await("");
	RETURN p(WindowManager)
END GetDefaultManager;

PROCEDURE GetDefaultView*() : ViewPort;
VAR p : Plugins.Plugin; m : WindowManager;
BEGIN
	m := GetDefaultManager();
	p := m.viewRegistry.Await("");
	RETURN p(ViewPort)
END GetDefaultView;

PROCEDURE ResetNextPosition*;
BEGIN {EXCLUSIVE}
	x1 := 0; y1 := 0;
END ResetNextPosition;

PROCEDURE GetNextPosition*(window : Window; manager : WindowManager; view : ViewPort; VAR dx, dy : LONGINT);
VAR style : WindowStyle; x, y : LONGINT;
BEGIN {EXCLUSIVE}
	ASSERT((window # NIL) & (manager # NIL) & (view # NIL));
	style := manager.GetStyle();
	x := style.lw; y := style.th;
	dx := x + X0 + x1; dy := y + Y0 + y1;
	INC(x1, x); INC(y1, y);
	IF (x1 > ENTIER(0.3 * view.width0)) OR (y1 > ENTIER(0.3 * view.height0)) THEN
		x1 := 0; y1 := 0;
	END;
END GetNextPosition;

PROCEDURE DefaultAddWindow*(w : Window);
VAR manager : WindowManager; view : ViewPort; dy, dx : LONGINT;
BEGIN
	manager := GetDefaultManager();
	view := GetDefaultView();
	GetNextPosition(w, manager, view, dx, dy);
	manager.Add(ENTIER(view.range.l) + dx, ENTIER(view.range.t) + dy, w, {FlagFrame, FlagClose, FlagMinimize});
	manager.SetFocus(w)
END DefaultAddWindow;

PROCEDURE AddWindow*(w : Window; dx, dy : LONGINT);
VAR manager : WindowManager; view : ViewPort;
BEGIN
	manager := GetDefaultManager();
	view := GetDefaultView();
	manager.Add(ENTIER(view.range.l) + dx, ENTIER(view.range.t) + dy, w, {FlagFrame, FlagClose, FlagMinimize})
END AddWindow;

PROCEDURE ExtAddWindow*(w : Window; dx, dy : LONGINT; flags : SET);
VAR manager : WindowManager; view : ViewPort;
BEGIN
	manager := GetDefaultManager();
	view := GetDefaultView();
	manager.Add(ENTIER(view.range.l) + dx, ENTIER(view.range.t) + dy, w, flags)
END ExtAddWindow;

PROCEDURE ExtAddViewBoundWindow*(w : Window; dx, dy : LONGINT; view : ViewPort; flags : SET);
VAR manager : WindowManager;
BEGIN
	flags := flags + {FlagNavigation};
	manager := GetDefaultManager();
	manager.Add(dx, dy, w, flags);
END ExtAddViewBoundWindow;

(** move a window to the default view *)
PROCEDURE DefaultBringToView*(w : Window; toFront : BOOLEAN);
VAR manager : WindowManager; view : ViewPort; dy, dx : LONGINT;
BEGIN
	manager := GetDefaultManager();
	view := GetDefaultView();
	GetNextPosition(w, manager, view, dx, dy);
	manager.SetWindowPos(w, ENTIER(view.range.l) + dx, ENTIER(view.range.t) + dy);
	manager.SetFocus(w);
	IF toFront THEN manager.ToFront(w) END
END DefaultBringToView;

PROCEDURE CleanUp;
BEGIN
	Plugins.main.Remove(registry)
END CleanUp;

PROCEDURE CreateStandardCursorImage;
CONST Width = 32; Height = 32;
VAR canvas: Graphics.BufferCanvas; rect: Rectangles.Rectangle; points: ARRAY 3 OF Graphics.Point2d;
BEGIN
	NEW(standardCursorImage);
	Raster.Create(standardCursorImage, Width, Height, Raster.BGRA8888);
	NEW(canvas, standardCursorImage);
	Rectangles.SetRect (rect, 0, 0, Width, Height);
	canvas.Fill(rect, 0H, Graphics.ModeCopy);
	points[0].x := Width; points[0].y := Height DIV 2;
	points[1].x := 0; points[1].y := 0;
	points[2].x := Width DIV 2; points[2].y := Height;
	canvas.FillPolygonFlat(points, 3, Graphics.White - 080H, Graphics.ModeCopy);
	canvas.PolyLine(points, 3, FALSE, Graphics.Black, Graphics.ModeCopy);
END CreateStandardCursorImage;

BEGIN
	Modules.InstallTermHandler(CleanUp);
	NEW(registry, "WM#", "Window Managers");
	nextId := 0; x1 := 0; y1 := 0;
	wTimestamp := 0; oTimestamp := 0;
	format := Raster.BGRA8888;
	NEW(pointerNull);
	standardCursorImage := NIL;
END WMWindowManager.