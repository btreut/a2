MODULE WMSlideshow;
(****
 *
 *  A simple slideshow/presentation tool with transition effect (see: WMTransitions.Mod).
 *
 *  Represents a  Model-View-Controller pattern
 *	(some controlling parts are also in the view):
 *	- Controller	= SlideshowApp
 *	- Model		= SlideshowData
 *	- View		= SlideshowWindow & SlideshowNavigation
 *
 *  Keyboard and mouse controls:
 *		- Next:		Spacebar/LeftMouseButton/PageDown/RightArrow
 *		- Previous:	PageUp/LeftArrow
 *		- First:		Home/UpArrow
 *		- Last:		End/DownArrow
 *		- Exit:		ESC
 *		- (Re)Open navigation panel: "n"
 *		- (Re)Open slide window: "w"
 *		- Show/Dump internal file list: "l"
 *
 *
 * Usage description:
 *	Drag & Drop new images on navigator window or use a predefinied XML file.
 *
 ****)

IMPORT
	Codecs, Inputs, Modules, Streams, KernelLog, Files, Commands,
	Raster,
	Strings,
	WMDropTarget, (* Drag&Drop interface *)
	WMWindowManager, WMGraphics, WMRectangles,
	WMComponents, WMStandardComponents, WMDialogs,
	WMTransitions,
	XML, XMLObjects, XMLScanner, XMLParser;
CONST
	DEBUG= FALSE;

(****
 *
 *  Just some type alias (typedefs)
 *
 ****)
TYPE String =  Strings.String;
TYPE Image =  WMGraphics.Image;
TYPE TransitionMask =  WMTransitions.TransitionMask;
TYPE TransitionFade =  WMTransitions.TransitionFade;
TYPE ObjectArray = POINTER TO ARRAY OF ANY;   (* Data Container for List Object *)

(****
 *
 *  A Slide contains:
 *	- an image filename
 *	- a transition effect to the next slide (optional)
 *	- duration of the transition (optional) STILL IN FRAMES -> MS IS BETTER
 *	- a short description (optional)
 *
 ****)
TYPE Slide* = OBJECT
	VAR
		img, trans	: String;
		dur			: LONGINT;
		desc		: String;
	PROCEDURE &New*(img : String;   trans : String; dur : LONGINT;   desc : String);
	BEGIN
		SELF.img := img; SELF.trans := trans; SELF.dur := dur; SELF.desc := desc;
	END New;
END Slide;


(****
 *
 *  Generic Lockable Object List
 *
 *  Author		: TF (-> TFClasses.Mod), with a few modification by Reto Ghioldi
 *  Purpose		: Generic helper (similar to the well known vector class)
 *  Note			: Needed userdefinied initial size of the vector
 *
 ****)
TYPE List* = OBJECT
	VAR
		list : ObjectArray;
		count : LONGINT;
		readLock : LONGINT;

	PROCEDURE &New*(size: LONGINT);
	BEGIN
		NEW(list, size); readLock := 0
	END New;

	(* ****
	 *
	 * Return the number of objects in the list. If count is used for indexing elements
	 * (e.g. FOR - Loop) in a multi-process situation, the process calling the GetCount method
	 * should call Lock before GetCount and Unlock after the last use of an index based on GetCount
	 *
	 *** *)
	PROCEDURE GetCount*():LONGINT;
	BEGIN
		RETURN count
	END GetCount;

	PROCEDURE Grow;
	VAR
		old: ObjectArray; i : LONGINT;
	BEGIN
		old := list;  NEW(list, LEN(list)*2);
		FOR i := 0 TO count-1 DO list[i] := old[i] END;
	END Grow;

	(* ***
	 *
	 * Add an object to the list. Add may block if number of calls to Lock is bigger than the number of calls to Unlock
	 *
	 *** *)
	PROCEDURE Add*(x : ANY);
	BEGIN {EXCLUSIVE}
		AWAIT(readLock = 0);
		IF (count = LEN(list)) THEN Grow END; list[count] := x;  INC(count);
	END Add;

	(* ***
	 *
	 * Atomic replace x by y
	 *
	 *** *)
	PROCEDURE Replace*(x, y : ANY);
	VAR
		i : LONGINT;
	BEGIN {EXCLUSIVE}
		AWAIT(readLock = 0);
		i := IndexOf(x);  IF (i >= 0) THEN list[i] := y END;
	END Replace;

	(* ***
	 *
	 * Return the index of an object. In a multi-process situation, the process calling the IndexOf method
	 * should call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
	 *
	 * If the object is not found, -1 is returned
	 *
	 *** *)
	PROCEDURE IndexOf *(x:ANY) : LONGINT;
	VAR
		i : LONGINT;
	BEGIN
		i := 0 ;
		WHILE (i < count) DO   IF (list[i] = x) THEN RETURN i END;   INC(i); END;
		RETURN -1;
	END IndexOf;

	(* ***
	 *
	 * Remove an object from the list. Remove may block if number of calls to Lock is bigger than the
	 *  number of calls to Unlock
	 *
	 *** *)
	PROCEDURE Remove*(x : ANY);
	VAR i : LONGINT;
	BEGIN {EXCLUSIVE}
		AWAIT(readLock = 0);
		i:=0;
		WHILE ( (i<count) & (list[i]#x) ) DO INC(i)  END;
		IF (i<count) THEN
			WHILE (i<count-1) DO  list[i]:=list[i+1]; INC(i);  END;
			DEC(count); list[count]:=NIL
		END
	END Remove;

	PROCEDURE RemoveByIndex*(index : LONGINT);
	VAR i : LONGINT;
	BEGIN {EXCLUSIVE}
		AWAIT(readLock = 0);
		i := index;
		IF (i >= 0) & (i < count) THEN
			WHILE (i<count-1) DO  list[i]:=list[i+1]; INC(i);  END;
			DEC(count); list[count]:=NIL;
		END;
	END RemoveByIndex;

	(* ***
	 *
	 * Removes all objects from the list. Clear may block if number of calls to Lock is bigger than the
	 *  number of calls to Unlock
	 *
	 *** *)
	PROCEDURE Clear*;
	VAR i : LONGINT;
	BEGIN {EXCLUSIVE}
		AWAIT(readLock = 0);
		FOR i := 0 TO count - 1 DO  list[i] := NIL;  END;
		count := 0
	END Clear;

	(* ***
	 *
	 * Return an object based on an index. In a multi-process situation, GetItem is only safe in a locked
	 * region Lock / Unlock
	 *
	 *** *)
	PROCEDURE GetItem*(i:LONGINT) : ANY;
	BEGIN
		ASSERT((i >= 0) & (i < count), 101);
		RETURN list[i];
	END GetItem;

	(* ***
	 *
	 * Lock prevents modifications to the list. All calls to Lock must be followed by a call to Unlock.
	 * Lock can be nested.
	 *
	 *** *)
	PROCEDURE Lock*;
	BEGIN {EXCLUSIVE}
		INC(readLock);
		ASSERT(readLock > 0);
	END Lock;

	(* ***
	 *
	 * Unlock removes one modification lock. All calls to Unlock must be preceeded by a call to Lock.
	 *
	 *** *)
	PROCEDURE Unlock*;
	BEGIN {EXCLUSIVE}
		DEC(readLock);
		ASSERT(readLock >= 0);
	END Unlock;
END List;





(****
 *
 *  The slideshow application
 *
 ****)
TYPE SlideshowApp= OBJECT
	VAR
		data : SlideshowData;
		win : SlideshowWindow;
		nav : SlideshowNavigation;
		slideNr : LONGINT;
		fullscreen : BOOLEAN;
	(*****
	 *
	 *  Constructor
	 *
	 *****)
	PROCEDURE &New*(CONST filename : ARRAY OF CHAR);
	BEGIN
		NEW(data);
		(* Load slides via drag & drop *)
		IF (filename # "") THEN
			data.LoadSlideshow(filename);
		END;
		IF app = NIL THEN  app := SELF  END;  (* fld, adapt to new semantc of NEW *)
		(* Create a application window *)
		NEW(win, 320, 240, FALSE, data);
		fullscreen := FALSE;
		WMWindowManager.DefaultAddWindow(win);
		NEW(nav, data);
		WMWindowManager.DefaultAddWindow(nav);
		slideNr := 0;
	END New;

	(*****
	 *
	 *  Handles the navigation inputs from the views
	 *
	 *****)
	PROCEDURE Next;
	BEGIN
		IF (data.CountSlides() = 0) THEN RETURN; END;
		IF ( slideNr < data.CountSlides() ) THEN
			win.Show(slideNr+1);
			INC(slideNr);
			nav.UpdatePreview();
		END;
	END Next;

	PROCEDURE Previous;
	BEGIN
		IF (data.CountSlides() = 0) THEN RETURN; END;
		slideNr := slideNr-1;
		IF (slideNr < 0) THEN slideNr := 0; RETURN; END;
		win.Update();
		nav.UpdatePreview();
	END Previous;

	PROCEDURE First;
	BEGIN
		IF (data.CountSlides() = 0) THEN RETURN; END;
		slideNr := 0;
		win.Update();
		nav.UpdatePreview();
	END First;

	PROCEDURE Last;
	BEGIN
		IF (data.CountSlides() = 0) THEN RETURN; END;
		slideNr := data.CountSlides()-1;
		IF (slideNr< 0) THEN slideNr := 0; END;
		win.Update();
		nav.UpdatePreview();
	END Last;


	(*****
	 *
	 *  Handles the important keyboard events from the views
	 *
	 *****)
	PROCEDURE ToggleFullscreen;
	VAR
		view : WMWindowManager.ViewPort;
		manager : WMWindowManager.WindowManager;
		w, h : LONGINT;
	BEGIN
		IF (win = NIL) THEN RETURN; END;
		fullscreen := ~fullscreen;
		manager := WMWindowManager.GetDefaultManager();
		view := WMWindowManager.GetDefaultView();
		IF (fullscreen) THEN
			w := ENTIER(view.range.r - view.range.l);
			h := ENTIER(view.range.b - view.range.t);
			manager.SetWindowSize(win, w, h);
			manager.SetWindowPos(win, ENTIER(view.range.l), ENTIER(view.range.t));
			win.Resized(w, h);
			win.Invalidate( WMRectangles.MakeRect(0, 0, w, h) );
		ELSE
			w := win.img.width;  h := win.img.height;
			manager.SetWindowSize(win, w, h);
			manager.SetWindowPos(win, ENTIER(view.range.l)+50, ENTIER(view.range.t)+50);
			win.Resized(w, h);
			win.Invalidate( WMRectangles.MakeRect(0, 0, w, h) );
		END;
	END ToggleFullscreen;

	(*****
	 *
	 *  Outputs the internal filelist of the slideshow
	 *
	 *****)
	PROCEDURE ShowFileList;
	VAR
		dummy : ARRAY 2048 OF CHAR;
		nl : ARRAY 2 OF CHAR;
		slide : Slide;
		i : LONGINT;
	BEGIN
		nl[0] := 0DX; nl[1] := 0X;
		dummy[0] := 0X;
		FOR i := 0 TO data.CountSlides()-1 DO
			slide := data.GetSlide(i);
			Strings.Append(dummy, slide.img^);
			Strings.Append(dummy, nl);
		END;
		WMDialogs.Information("Slideshow file list", dummy); (* don't care for user click *)
	END ShowFileList;

	(*****
	 *
	 *  Display a exit confirmation dialog
	 *
	 *****)
	PROCEDURE ExitDialog;
	BEGIN
		IF (WMDialogs.Confirmation("Exit Slideshow?", "You pressed ESC. Do you really want to exit the slideshow?") = WMDialogs.ResOk) THEN
			Cleanup();
		END;
	END ExitDialog;

	(*****
	 *
	 *  Remove current slide
	 *
	 *****)
	PROCEDURE RemoveCurrentSlide;
	VAR
		isLast : BOOLEAN;
	BEGIN
		IF (DEBUG) THEN KernelLog.String("Remove slide nr."); KernelLog.Int(slideNr, 0); KernelLog.Ln; END;
		isLast := slideNr = data.CountSlides()-1;
		data.RemoveSlide(slideNr);
		IF (~isLast) THEN
			IF (data.CountSlides() > 0) THEN
				nav.UpdatePreview();
				win.Update();
			ELSE

			END;
		ELSE
			IF (DEBUG) THEN KernelLog.String("# of remaining slides is "); KernelLog.Int(data.CountSlides(), 0); KernelLog.Ln; END;
			IF (data.CountSlides() > 0) THEN
				DEC(slideNr);
				win.Update();
			ELSE
				(* there was just one slide left *)
				IF (DEBUG) THEN
					KernelLog.String("All slides deleted!"); KernelLog.Ln;
				END;
				slideNr := 0;
				win.Close();
				data.ClearSlides();
				NEW(win, 320, 240, FALSE, data);
				WMWindowManager.DefaultAddWindow(win);
			END;
		END;
	END RemoveCurrentSlide;

	(*****
	 *
	 *  Destructor
	 *
	 *****)
	PROCEDURE Close;
	BEGIN
		(* close WM stuff *)
		win.Close();
		nav.Close();
	END Close;
END SlideshowApp;


(****
 *
 *  The slideshow application
 *
 ****)
TYPE  SlideshowNavigation = OBJECT(WMComponents.FormWindow);
	VAR
		data : SlideshowData;
		imageP : WMStandardComponents.ImagePanel;
		prevLen : LONGINT;

	PROCEDURE &New*(data : SlideshowData);
	VAR
		panel, nav: WMStandardComponents.Panel;
		button : WMStandardComponents.Button;
		manager : WMWindowManager.WindowManager;
		windowStyle : WMWindowManager.WindowStyle;
	BEGIN
		SELF.data := data;
		prevLen := 180;
		Init(prevLen, prevLen+20, FALSE);

		manager := WMWindowManager.GetDefaultManager();
		windowStyle := manager.GetStyle();

		NEW(panel);
		panel.bounds.SetExtents(prevLen, prevLen+20);
		panel.fillColor.Set(0000000H);
		panel.takesFocus.Set(TRUE);

		NEW(imageP);
		imageP.bounds.SetExtents(prevLen, prevLen);
		imageP.alignment.Set(WMComponents.AlignTop);

		NEW(nav);
		nav.bounds.SetExtents(prevLen, 20);
		nav.fillColor.Set(LONGINT(0AAAAAAAAH));
		nav.takesFocus.Set(TRUE);
		nav.alignment.Set(WMComponents.AlignTop);

		NEW(button);
		button.caption.SetAOC("|<");
		button.alignment.Set(WMComponents.AlignLeft);
		button.onClick.Add(ButtonHandlerFirst);
		button.bounds.SetWidth(40); button.bounds.SetHeight(20);
		nav.AddContent(button);

		NEW(button);
		button.caption.SetAOC("Previous");
		button.alignment.Set(WMComponents.AlignLeft);
		button.onClick.Add(ButtonHandlerPrevious);
		button.bounds.SetWidth(50); button.bounds.SetHeight(20);
		nav.AddContent(button);

		NEW(button);
		button.caption.SetAOC("Next");
		button.alignment.Set(WMComponents.AlignLeft);
		button.onClick.Add(ButtonHandlerNext);
		button.bounds.SetWidth(50); button.bounds.SetHeight(20);
		nav.AddContent(button);

		NEW(button);
		button.caption.SetAOC(">|");
		button.alignment.Set(WMComponents.AlignLeft);
		button.onClick.Add(ButtonHandlerLast);
		button.bounds.SetWidth(40); button.bounds.SetHeight(20);
		nav.AddContent(button);

		panel.AddContent(nav);
		panel.AddContent(imageP);

		SetContent(panel);
		SetTitle( Strings.NewString("Slideshow Navigation") );

		IF (data.CountSlides() > 0) THEN
			UpdatePreview();
		END;
	END New;

	PROCEDURE UpdatePreview;
	VAR
		nextSlide : Slide;
		nextIndex : LONGINT;
		image : Image;
		fact : REAL;
		c : WMGraphics.BufferCanvas;
		w, h : LONGINT;
	BEGIN
		(* End? -> indiacted with a white preview panel *)
		IF (app.slideNr >= data.CountSlides()-1) THEN
			imageP.SetImage(SELF, NIL);
		ELSE
			(* load next image and scale slide to correct size *)
			nextIndex := app.slideNr+1;
			nextSlide := data.GetSlide(nextIndex);
			image := LoadImage(nextSlide.img^, Raster.BGR565);
			WHILE (image = NIL) & (nextIndex < data.CountSlides()) DO
				IF (DEBUG) THEN KernelLog.String("Error in UpdatePreview(): Remove invalid image "); KernelLog.String(nextSlide.img^); KernelLog.String("."); KernelLog.Ln; END;
				data.RemoveSlide(nextIndex);
				IF (nextIndex < data.CountSlides()) THEN
					nextSlide := data.GetSlide(nextIndex);
					image := LoadImage(nextSlide.img^, Raster.BGR565);
				END;
			END;
			IF (image = NIL) THEN
				imageP.SetImage(SELF, NIL);
			ELSE
				NEW(c, image);
				IF (image.width > prevLen) OR (image.height > prevLen) THEN
					IF (image.width >= image.height) THEN
						fact := image.width / prevLen;
					ELSE
						fact := image.height / prevLen;
					END;
					c.ScaleImage(image, WMRectangles.MakeRect(0, 0, image.width, image.height),
						WMRectangles.MakeRect(0, 0, ENTIER(image.width/fact), ENTIER(image.height/fact)), WMGraphics.ModeCopy, WMGraphics.ScaleBilinear);
					image.width := ENTIER(image.width/fact);
					image.height := ENTIER(image.height/fact);
				END;
				w := image.width; h := image.height + 20; (* Buttons = 20px *)
				imageP.SetImage(SELF, image);
			END;
		END;
		(* correct window width & height *)
		manager := WMWindowManager.GetDefaultManager();
		w := Strings.Max(w, 180);
		manager.SetWindowSize(SELF, w, h);
		Resized(w, h);
		Invalidate( WMRectangles.MakeRect(0, 0, w, h) );
	END UpdatePreview;

	PROCEDURE ButtonHandlerNext(sender, data: ANY);
	BEGIN
		app.Next();
	END ButtonHandlerNext;

	PROCEDURE ButtonHandlerPrevious(sender, data: ANY);
	BEGIN
		app.Previous();
	END ButtonHandlerPrevious;

	PROCEDURE ButtonHandlerFirst(sender, data: ANY);
	BEGIN
		app.First();
	END ButtonHandlerFirst;

	PROCEDURE ButtonHandlerLast(sender, data: ANY);
	BEGIN
		app.Last();
	END ButtonHandlerLast;

	PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT);
	BEGIN
		IF Inputs.Release IN flags THEN RETURN; END;
		IF ucs = ORD("f") THEN
			app.ToggleFullscreen();
			RETURN;
		ELSIF ucs = ORD("w") THEN
			app.win.Close();
			NEW(app.win, 320, 240, FALSE, data);
			WMWindowManager.DefaultAddWindow(app.win);
			RETURN;
		ELSIF ucs = ORD("l") THEN
			app.ShowFileList();
			RETURN;
		END;
		IF (keysym = 0FF51H) THEN (* Cursor Left *)
			app.Previous();
		ELSIF (keysym = 0FF53H) THEN (* Cursor Right *)
			app.Next();
		ELSIF (keysym = 0FF54H) THEN (* Cursor Down *)
			app.Last();
		ELSIF (keysym = 0FF52H) THEN (* Cursor Up *)
			app.First();
		ELSIF (keysym = 0FF56H) THEN (* Page Down *)
			app.Next();
		ELSIF (keysym = 0FF55H) THEN (* Page Up *)
			app.Previous();
		ELSIF (keysym = 0FF50H) THEN (* Cursor Home *)
			app.First();
		ELSIF (keysym = 0FF57H) THEN (* Cursor End *)
			app.Last();
		ELSIF (keysym = 00020H) THEN (* Spacebar *)
			app.Next();
		ELSIF (keysym = 0FF1BH) THEN (* ESC = 65307*)
			app.ExitDialog();
		ELSIF (keysym = 0FFFFH) THEN (* DEL = 65535*)
			app.RemoveCurrentSlide();
		ELSE
			IF (DEBUG) THEN KernelLog.String("unknown keysym= "); KernelLog.Int(keysym, 0); KernelLog.Ln; END;
		END;
	END KeyEvent;

	(** Dropped is called via the message handler to indicate an item has been dropped. *)
	PROCEDURE DragDropped*(x, y: LONGINT; dragInfo : WMWindowManager.DragInfo);
	VAR
		dropTarget : URLDropTarget;
	BEGIN
		KernelLog.Ln; (* fix to begin with new line later on *)
		NEW(dropTarget);
		dragInfo.data := dropTarget;
		ConfirmDrag(TRUE, dragInfo)
	END DragDropped;

END SlideshowNavigation;

(****
 *
 *  When drag & dropping files/URLs into window (build slideshow on the fly, without transition!)
 *
 ****)
TYPE URLDropTarget* = OBJECT(WMDropTarget.DropTarget);
	PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
	VAR di : DropURL;
	BEGIN
		IF (type = WMDropTarget.TypeURL) THEN
			NEW(di);
			RETURN di;
		ELSE
			RETURN NIL;
		END
	END GetInterface;
END URLDropTarget;

TYPE DropURL* = OBJECT(WMDropTarget.DropURLs)
	PROCEDURE URL*(CONST url : ARRAY OF CHAR; VAR res : LONGINT);
	BEGIN
		(* handle dropped files -> build up SlideshowData on-the-fly (not via XML file) *)
		KernelLog.String("Dropped new URL: "); KernelLog.String(url); KernelLog.Ln;
		IF (app # NIL) THEN
			app.data.AddSlide(url);
			IF (app.data.CountSlides() = 1) THEN
				(* Load first slide *)
				app.win.Update();
			ELSE
				app.nav.UpdatePreview();
			END;
			res := 0
		ELSE
			res := -1;
		END;
	END URL;
END DropURL;


(****
 *
 *  The slideshow application
 *
 ****)
TYPE  SlideshowWindow = OBJECT(WMWindowManager.DoubleBufferWindow);
	VAR
		data: SlideshowData;

	PROCEDURE &New*( width, height : LONGINT; alpha : BOOLEAN; data : SlideshowData);
	BEGIN
		Init(width, height, alpha);
		SetTitle( Strings.NewString("Bluebottle Slideshow (ETHZ, 2005)") );
		SELF.data := data;
		IF (data.CountSlides() = 0) THEN RETURN; END;
		(* Load first slide *)
		Update();
	END New;


	PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
	BEGIN
		IF (0 IN keys) THEN
			(* Go to next Slide  *)
			app.Next();
		END;
	END PointerDown;

	PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT);
	BEGIN
		IF Inputs.Release IN flags THEN RETURN; END;
		IF ucs = ORD("f") THEN
			app.ToggleFullscreen();
			RETURN;
		ELSIF ucs = ORD("n") THEN
			app.nav.Close();
			NEW(app.nav, data);
			WMWindowManager.DefaultAddWindow(app.nav);
			RETURN;
		ELSIF ucs = ORD("l") THEN
			app.ShowFileList();
			RETURN;
		END;
		IF (keysym = 0FF51H) THEN (* Cursor Left *)
			app.Previous();
		ELSIF (keysym = 0FF53H) THEN (* Cursor Right *)
			app.Next();
		ELSIF (keysym = 0FF54H) THEN (* Cursor Down *)
			app.Last();
		ELSIF (keysym = 0FF52H) THEN (* Cursor Up *)
			app.First();
		ELSIF (keysym = 0FF56H) THEN (* Page Down *)
			app.Next();
		ELSIF (keysym = 0FF55H) THEN (* Page Up *)
			app.Previous();
		ELSIF (keysym = 0FF50H) THEN (* Cursor Home *)
			app.First();
		ELSIF (keysym = 0FF57H) THEN (* Cursor End *)
			app.Last();
		ELSIF (keysym = 00020H) THEN (* Spacebar *)
			app.Next();
		ELSIF (keysym = 0FF1BH) THEN (* ESC = 65307*)
			app.ExitDialog();
		ELSIF (keysym = 0FFFFH) THEN (* DEL = 65535*)
			app.RemoveCurrentSlide();
		ELSE
			IF (DEBUG) THEN KernelLog.String("unknown keysym= "); KernelLog.Int(keysym, 0); KernelLog.Ln; END;
		END;
	END KeyEvent;

	(*
	PROCEDURE Jump(slideNr : LONGINT);
	VAR s : Slide;
		w, h : LONGINT;
	BEGIN
		(*  Load image *)
		s := data.GetSlide(slideNr);
		img := LoadImage(s.img^, Raster.BGR565);
		manager := WMWindowManager.GetDefaultManager();
		w := img.width;  h := img.height;
		manager.SetWindowSize(SELF, w, h);
		Resized(w, h);
		Invalidate( WMRectangles.MakeRect(0, 0, w, h) );
	END Jump;
	*)

	PROCEDURE Show(nextSlideNr : LONGINT );
	VAR
		current, next : Slide;
		src, dest : Image;
		maskFile : String;
	BEGIN
		(* At least two slides are needed *)
		IF (data.CountSlides() < 2) THEN RETURN; END;
		(* End? *)
		IF (nextSlideNr > data.CountSlides()-1) THEN RETURN; END;
		(* Advance to the next for transition rendering *)
		current := data.GetSlide(app.slideNr);
		next := data.GetSlide(nextSlideNr);
		src := LoadImage(current.img^, Raster.BGR565);
		dest := LoadImage(next.img^, Raster.BGR565);
		IF (dest = NIL) THEN
			IF (DEBUG) THEN KernelLog.String("Error: Invalid image - no decoder found for "); KernelLog.String(next.img^); KernelLog.Ln; END;
			data.RemoveSlide(nextSlideNr);
			Update();
			RETURN;
		END;
		IF (src = NIL) OR (dest = NIL) THEN HALT(99); END;
		(*
		 	1) Mask
		 	2) Fade
		 	3) None
		 *)
		IF (current.trans^ = "") THEN
			ShowNone(dest);
		ELSIF (Strings.Match("mask:*", current.trans^)) THEN
			maskFile := Strings.NewString(current.trans^);
			Strings.Delete(maskFile^, 0, 5);
			ShowMask(src, dest, maskFile^, current.dur);
		ELSIF (Strings.Match("fade", current.trans^)) THEN
			ShowFade(src, dest, current.dur);
		ELSE
			KernelLog.String("Invalid transition. Use 'mask:[URL]', 'fade' or '' (empty) in XML file!"); KernelLog.Ln;
			HALT(99);
		END;
	END Show;

	PROCEDURE ShowMask(current, next : Image; CONST mask: ARRAY OF CHAR; len : LONGINT);
	VAR
		tm : TransitionMask;
		i, step: LONGINT;
		w, h : LONGINT;
	BEGIN
		IF (DEBUG) THEN KernelLog.String("Mask transition: "); KernelLog.String(mask); KernelLog.Ln; END;
		w := current.width; h := current.height;
		i := 0;
		step := 256 DIV len;
		NEW(tm);
		tm.Init(w, h);
		tm.SetMask(WMGraphics.LoadImage(mask, TRUE));
		WHILE (i < 256) DO
			tm.CalcImage(next, current, img, i);
			Invalidate(WMRectangles.MakeRect(0, 0, w, h));
			i := i + step;
		END;
		IF (i # 255) THEN
			img := next;
			Invalidate(WMRectangles.MakeRect(0, 0, w, h));
		END;
	END ShowMask;


	PROCEDURE ShowFade(current, next : Image; len : LONGINT);
	VAR
		tf : TransitionFade;
		i,step : LONGINT;
		w, h : LONGINT;
	BEGIN
		IF (DEBUG) THEN KernelLog.String("Fade transition"); KernelLog.Ln; END;
		w := current.width; h := current.height;
		i := 0;
		step := 256 DIV len;
		NEW(tf);
		tf.Init(w, h);
		WHILE (i < 256) DO
			tf.CalcImage(current, next, img, i);
			Invalidate(WMRectangles.MakeRect(0, 0, w, h));
			i := i + step;
		END;
		IF (i #255) THEN
			img := next;
			Invalidate(WMRectangles.MakeRect(0, 0, w, h));
		END;
	END ShowFade;

	PROCEDURE ShowNone(next : Image);
	BEGIN
		img := next;
		Invalidate(WMRectangles.MakeRect(0, 0, next.width, next.height));
	END ShowNone;

	PROCEDURE Update;
	VAR s : Slide;
		w, h : LONGINT;
		manager : WMWindowManager.WindowManager;
	BEGIN
		(* Load current slide *)
		IF (app.slideNr > data.CountSlides()-1) THEN RETURN; END;
		s := data.GetSlide(app.slideNr);
		img := LoadImage(s.img^, Raster.BGR565);
		WHILE (img = NIL) DO
			IF (DEBUG) THEN KernelLog.String("Error: Invalid image - no decoder found for "); KernelLog.String(s.img^); KernelLog.Ln; END;
			data.RemoveSlide(app.slideNr);
			IF (app.slideNr < data.CountSlides()-1) THEN
				s := data.GetSlide(app.slideNr);
				img := LoadImage(s.img^, Raster.BGR565);
			ELSIF ( (data.CountSlides() > 0) & (app.slideNr > 0) ) THEN
				DEC(app.slideNr);
				s := data.GetSlide(app.slideNr);
				img := LoadImage(s.img^, Raster.BGR565);
			ELSE
				(* no more slides -> can't display one :-) *)
				IF (DEBUG) THEN KernelLog.String("Error: No more images in slideshow. Add new ones by dropping URLs in navigation window."); KernelLog.Ln; END;
				RETURN;
			END;
		END;
		manager := WMWindowManager.GetDefaultManager();
		w := img.width;  h := img.height;
		manager.SetWindowSize(SELF, w, h);
		Resized(w, h);
		Invalidate( WMRectangles.MakeRect(0, 0, w, h) );
		IF (app.nav # NIL) THEN
			app.nav.UpdatePreview();
		END;
	END Update;


END SlideshowWindow;


 TYPE SlideshowData= OBJECT
 	VAR
		slides : List;
		hasErrors : BOOLEAN; (* XML Parsing *)

	PROCEDURE &New*;
	BEGIN
		NEW(slides, 50);
		IF (DEBUG) THEN KernelLog.String("All slides have been loaded!"); KernelLog.Ln; END;
	END New;

	PROCEDURE GetSlide(i : LONGINT) : Slide;
	VAR
		p : ANY; 	s : Slide;
	BEGIN
		p := slides.GetItem(i);
		IF (p = NIL) THEN
			IF (DEBUG) THEN KernelLog.String("Slide nr. "); KernelLog.Int(i, 0); KernelLog.String(" doesn't exist!");  KernelLog.Ln; END;
			RETURN NIL;
		END;
		 s := p(Slide); RETURN s;
	END GetSlide;

	PROCEDURE CountSlides() : LONGINT;
	BEGIN
		RETURN slides.GetCount();
	END CountSlides;

	PROCEDURE LoadSlideshow(CONST name : ARRAY OF CHAR);
	VAR
		f : Files.File;
		scanner : XMLScanner.Scanner;
		parser : XMLParser.Parser;
		reader : Files.Reader;
		doc : XML.Document;
	BEGIN {EXCLUSIVE}
		hasErrors := FALSE;
		f := Files.Old(name);
		IF (f = NIL) THEN
			IF (DEBUG) THEN KernelLog.String("Couldn't open "); KernelLog.String(name); KernelLog.String(". Slideshow NOT loaded."); KernelLog.Ln; END;
			HALT (99);
		END;
		(* Build up XML parser structure *)
		NEW(reader, f, 0);
		NEW(scanner, reader); scanner.reportError := ErrorReport;
		NEW(parser, scanner); parser.reportError := ErrorReport;
		(* Parse the XML file (without DTD/Schema checking) *)
		doc := parser.Parse();
		(* Check for parser errors *)
		IF (hasErrors) THEN
			IF (DEBUG) THEN KernelLog.String("Slideshow "); KernelLog.String(name); KernelLog.String("NOT ok."); KernelLog.Ln; END;
			HALT (99);
		END;
		IF (LoadSlides(doc)) THEN
			IF (DEBUG) THEN KernelLog.String("Slideshow "); KernelLog.String(name); KernelLog.String(" loaded."); KernelLog.Ln; END;
		ELSE
			IF (DEBUG) THEN KernelLog.String("Slideshow "); KernelLog.String(name); KernelLog.String(" NOT loaded."); KernelLog.Ln; END;
			HALT (99);
		END;
	END LoadSlideshow;

	PROCEDURE LoadSlides(doc: XML.Document) : BOOLEAN;
	VAR
		enum: XMLObjects.Enumerator;
		e, root: XML.Element;
		p: ANY;
		s, imgStr, transStr, durStr, descStr : String;
		dur : LONGINT;
		slide : Slide;
	BEGIN
		IF (doc = NIL) THEN
			IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): doc = NIL"); END;
			RETURN FALSE;
		END;
		root := doc.GetRoot();
		IF (root = NIL) THEN
			IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): root = NIL"); END;
			RETURN FALSE;
		END;
		enum := root.GetContents();
		WHILE ( enum.HasMoreElements() ) DO
			p := enum.GetNext();
			IF ~(p IS XML.Element) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): p # XML.Element"); END;
				RETURN FALSE;
			END;
			(* Try to read 'Slide' element *)
			e := p(XML.Element);
			s := e.GetName();
			IF (s = NIL) OR (s^ # "Slide") THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s = NIL OR s # 'Slide'"); END;
				RETURN FALSE;
			END;
			(*
				(* 0. try to read 'key' attribut -> not yet used!!! *)
				s := e.GetAttributeValue("key");
				IF (s = NIL) THEN
					IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s(key) = NIL"); END;
					RETURN FALSE;
				END;
				Strings.StrToInt(s^, i);
				IF (i<=0) & (i>WMTrans.duration) THEN KernelLog.String("Error: wrong index in XML"); RETURN FALSE; END;
			*)
			(* **
			 *
			 * WARNING: Values  NOT yet zero terminated!!! Bug in XML Parser?!?
			 *                    ==> create a new String with Strings.NewString()
			 *
			 ** *)
			(** 1. try to read 'imgage' attribut **)
			s := e.GetAttributeValue("image");
			IF (s = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s(image) = NIL"); END;
				RETURN FALSE;
			END;
			imgStr := Strings.NewString(s^);
			IF ( (imgStr = NIL) OR (imgStr^ = "") ) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): filename = NIL   OR   empty"); END;
				RETURN FALSE;
			END;
			(** 2. try to read 'transition' attribut **)
			s := e.GetAttributeValue("transition");
			IF (s = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s(transition) = NIL"); END;
				RETURN FALSE;
			END;
			transStr := Strings.NewString(s^);
			IF (transStr = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): transition = NIL"); END;
				RETURN FALSE;
			END;
			(** 3. try to read 'duration' attribut **)
			s := e.GetAttributeValue("duration");
			IF (s = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s(duration) = NIL"); END;
				RETURN FALSE;
			END;
			durStr := Strings.NewString(s^);
			Strings.StrToInt(durStr^, dur);
			(** 4. try to read 'description' attribut **)
			s := e.GetAttributeValue("description");
			IF (s = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): s(description) = NIL"); END;
				RETURN FALSE;
			END;
			descStr := Strings.NewString(s^);
			IF (descStr = NIL) THEN
				IF (DEBUG) THEN KernelLog.String("Error in LoadSlides(): description = NIL"); END;
				RETURN FALSE;
			END;
			(** create slide entry and add it to list **)
			IF (DEBUG) THEN
				KernelLog.String("Loading Slide (image="); KernelLog.String(imgStr^); KernelLog.String(", transition="); KernelLog.String(transStr^);   KernelLog.String(")."); KernelLog.Ln;
			END;
			NEW(slide, imgStr, transStr, dur, descStr);
			slides.Add(slide);
		END; (* while loop *)
		IF (slides.GetCount() = 0) THEN
			IF (DEBUG) THEN KernelLog.String("Slideshow "); KernelLog.String(" NOT loaded (empty file)."); KernelLog.Ln; END;
			RETURN FALSE;
		ELSE
			RETURN TRUE;
		END;
	END LoadSlides;

	(*****
	 *
	 *  XML slideshow file reading stuff
	 *
	 *****)
	PROCEDURE ErrorReport(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.String("Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
		KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
		hasErrors := TRUE
	END ErrorReport;

	(*****
	 *
	 *  Add a slide on the fly (uses a short fade transition)
	 *
	 *****)
	PROCEDURE AddSlide(CONST filename : ARRAY OF CHAR);
	VAR
		slide : Slide;
	BEGIN
		NEW(slide, Strings.NewString(filename), Strings.NewString("fade"), 15, Strings.NewString(filename));
		slides.Add(slide);
	END AddSlide;

	(*****
	 *
	 *  Remove a slide on the fly (if it has been detected as invalid image format)
	 *
	 *****)
	PROCEDURE RemoveSlide(i : LONGINT);
	BEGIN
		slides.RemoveByIndex(i);
	END RemoveSlide;

	(*****
	 *
	 *  Clears everything
	 *
	 *****)
	PROCEDURE ClearSlides;
	BEGIN
		slides.Clear();
	END ClearSlides;

 END SlideshowData;



(****
 *
 *  Global variables
 *
 ****)
VAR
	app : SlideshowApp; (* using the singleton pattern *)

(****
 *
 *  Global functions
 *
 ****)
PROCEDURE Open*(context : Commands.Context);
VAR dstring : ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	IF (app # NIL) THEN
		app.Close();
	END;
	context.arg.SkipWhitespace; context.arg.String(dstring);
	NEW(app, dstring);
END Open;

PROCEDURE Cleanup;
BEGIN
	IF (app # NIL) THEN app.Close(); END
END Cleanup;


(****
 *
 *  Load Image in given Format as WM class, Image is NOT SHAREABLE although it has a key!
 *
 * 	NOTE: With the "Raster.Image" you will have many type troubles with WM Framework
 *
 ****)
PROCEDURE LoadImage(CONST name : ARRAY OF CHAR; fmt : Raster.Format): Image;
VAR img : Image;
	res, w, h, x : LONGINT;
	decoder : Codecs.ImageDecoder;
	in : Streams.Reader;
	ext : ARRAY 16 OF CHAR;
BEGIN
	IF (name = "") THEN RETURN NIL END;
	GetExtension(name, ext);
	Strings.UpperCase(ext);
	decoder := Codecs.GetImageDecoder(ext);
	IF (decoder = NIL) THEN
		KernelLog.String("No decoder found for "); KernelLog.String(ext); KernelLog.Ln;
		RETURN NIL;
	END;
	in := Codecs.OpenInputStream(name);
	IF (in # NIL) THEN
		decoder.Open(in, res);
		IF (res = 0) THEN
			decoder.GetImageInfo(w, h, x, x);
			NEW(img);
			Raster.Create(img, w, h, fmt);
			decoder.Render(img);
			NEW(img.key, LEN(name)); COPY(name, img.key^);
		END;
	END;
	RETURN img;
END LoadImage;

(*****
 *
 *  Procedure to split filename in the name and the extension
 *
 *****)
PROCEDURE GetExtension (CONST name: ARRAY OF CHAR; VAR ext: ARRAY OF CHAR);
VAR
	i, j: LONGINT;
	ch: CHAR;
BEGIN
	i := 0; j := 0;
	WHILE (name[i] # 0X) DO
		IF (name[i] = ".") THEN j := i+1 END;
		INC(i)
	END;
	i := 0;
	REPEAT
		ch := name[j]; ext[i] := ch; INC(i); INC(j)
	UNTIL (ch = 0X) OR (i = LEN(ext));
	ext[i-1] := 0X
END GetExtension;

BEGIN
	Modules.InstallTermHandler(Cleanup)

END WMSlideshow.

(* Testing commands *)
SystemTools.Free WMSlideshow WMTransFade WMTransMask WMTrans ~
SystemTools.Free WMSlideshow~

PC.Compile RetoWMTrans.Mod RetoWMTransMask.Mod RetoWMTransFade.Mod RetoWMSlideshow.Mod~

WMSlideshow.Open ~
WMSlideshow.Open RetoWMSlideshow.XML~