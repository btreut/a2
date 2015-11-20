MODULE DTPView; (** AUTHOR "PL"; PURPOSE "View for simple DTP Editor"; *)

IMPORT
	WMStandardComponents, WMGraphics, Inputs,
	WMComponents, WMRectangles, WMEditors, Strings,
	WMWindowManager, DTPData, DTPUtilities; (* , DTPFrame *)

CONST
	RULERSIZE = 20;
	HIGHLIGHT = LONGINT(0FF8800FFH);
	ACTIVEFRAMECOLOR = 00000FFFFH;
	FRAMECOLOR = 00088FFFFH;
	MASTERFRAMECOLOR = 000FF88FFH;
	BORDERCOLOR = LONGINT(0FF00FFFFH);
	GUIDECOLOR = 000FFFFFFH;
	GRIDCOLOR = LONGINT(0BABABAFFH);
	SUBGRIDCOLOR = LONGINT(0DDDDDDFFH);
	point = 0.3527777778;						(* 1/72 inch *)

VAR

TYPE

	DrawPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		(* parentWindow : Window; *)
		document : DTPData.Document;
		cpage: DTPData.PageObject;
		cframe, activeFrame*: DTPData.FrameObject;
		cguide: DTPData.GuideObject;
		ccontent: DTPData.ContentObject;
		ready* : BOOLEAN;

		vScrollbar- : WMStandardComponents.Scrollbar;
		hScrollbar- : WMStandardComponents.Scrollbar;
		zoomFactor : REAL; quality : BOOLEAN;
		zoomUser : REAL;
		zoomMode- : LONGINT;									(* 0 : ZoomFitDoc *)
																(* 1 : ZoomFitWidth *)
																(* 2 : ZoomFitHeight *)
																(* 3 : ZoomFitFrame *)
																(* 4 : ZoomFitOriginal *)
																(* 5 : ZoomFitUser *)
		docOriginX, docOriginY : LONGINT; snapDistance: REAL;
		showGrid, snapToGrid : BOOLEAN; gridDistance : REAL; gridDivision : LONGINT;
		wheelMode- : LONGINT;
		previewMode* : BOOLEAN;
		mpageMode* : BOOLEAN;
		render : BOOLEAN;
		selectionON* : BOOLEAN;
		snapOnCreate: BOOLEAN;
		activeTool*: Strings.String;
		x0, y0, x1, y1, dx, dy, gx, gy, vx0, vy0, vx1, vy1: LONGINT;
		fx0, fy0, fx1, fy1, tx0, ty0, tx1, ty1: REAL;
		res, res2: LONGINT;
		down, move, resize, addobject, addguide, moveguide, oldpointer: BOOLEAN;
		prevPointerInfo: WMWindowManager.PointerInfo;
		oldPointerInfo: LONGINT;
		plugPointer: BOOLEAN;
		manager : WMWindowManager.WindowManager;
		oldfx0, oldfy0, oldfx1, oldfy1: REAL;

		props*: PropertyWindow;
		propertyOpen*: BOOLEAN;
		propsX*, propsY*: LONGINT;

(*		nObj*: NewObjectDialog;
		newObjOpen*: BOOLEAN;
*)
		(* DELEGATES *)
		newPluginObject* : PROCEDURE {DELEGATE} (): DTPData.ContentObject;
		ownerWindowSetFocus* : PROCEDURE {DELEGATE};
		ownerWindowUpdatePageNumber* : PROCEDURE {DELEGATE};
		ownerWindowExitFullScreen*: PROCEDURE {DELEGATE};

		PROCEDURE &Init*;
		BEGIN
			Init^;
			ready := FALSE;
			document := NIL;
			(* default values *)
			fillColor.Set(0888888FFH);
			docOriginX := 30; docOriginY := 30;
			propsX := 820; propsY := 350;
			showGrid := TRUE; snapToGrid := FALSE; gridDistance := 50; gridDivision := 10;
			previewMode := FALSE;
			down := FALSE; move := FALSE; resize := FALSE; addguide := FALSE; moveguide := FALSE; addobject := FALSE;
			takesFocus.Set(TRUE); oldpointer := TRUE; plugPointer := FALSE;
			snapDistance := 2.0;
			zoomMode := 0;
			selectionON := TRUE;
			snapOnCreate := FALSE;
			quality := TRUE;
			render := FALSE;
			needsTab.Set(TRUE);
			wheelMode := 0;

			NEW(props, SELF); props.Show; propertyOpen := TRUE;
			(* newObjOpen := FALSE; *)
			manager := WMWindowManager.GetDefaultManager();

		END Init;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF property = fillColor THEN Invalidate
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE Resized*;
		VAR
			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			ccontent : DTPData.ContentObject;
		BEGIN
			CASE zoomMode OF										(* zoom current view *)
					0: ZoomFitDoc;
				|	1: ZoomFitWidth;
				|	2: ZoomFitHeight;
				|	3: ZoomFitFrame;
				|	4: ZoomFitOriginal;
				|	5: ZoomFitUser;
			ELSE
			END;
			cpage := document.GetCurrentMasterPage();
			IF (cpage # NIL) THEN
				cframe := cpage.GetFirstFrame();
				WHILE (cframe # NIL) DO
					ccontent := cframe.GetContent();
					IF ccontent # NIL THEN
						ccontent.Resize(zoomFactor);
						ccontent.SetSize(ENTIER(cframe.GetWidth()*zoomFactor), ENTIER(cframe.GetHeight()*zoomFactor));
					END;
					cframe := cframe.next;
				END;
			END;
			cpage := document.GetCurrentPage();
			IF (cpage # NIL) THEN
				cframe := cpage.GetFirstFrame();
				WHILE (cframe # NIL) DO
					(* tempString := cframe.GetName(); *)
					(* KernelLog.String("Setting: "); KernelLog.String(tempString^); KernelLog.Int(ENTIER(cframe.GetWidth()*zoomFactor), 0); KernelLog.Int(ENTIER(cframe.GetHeight()*zoomFactor), 0); KernelLog.Ln; *)
					ccontent := cframe.GetContent();
					IF ccontent # NIL THEN
						ccontent.Resize(zoomFactor);
						ccontent.SetSize(ENTIER(cframe.GetWidth()*zoomFactor), ENTIER(cframe.GetHeight()*zoomFactor));
					END;
					cframe := cframe.next;
				END;
			END;
			Invalidate;

		END Resized;

		PROCEDURE Render*(state : BOOLEAN);
		BEGIN
			render := state;
		END Render;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			Invalidate;
		END RecacheProperties;

		PROCEDURE SetScrollbars*(hScrollbar, vScrollbar : WMStandardComponents.Scrollbar);
		BEGIN
			Acquire;
			IF hScrollbar # NIL THEN hScrollbar.onPositionChanged.Remove(ScrollbarsChanged) END;
			IF vScrollbar # NIL THEN vScrollbar.onPositionChanged.Remove(ScrollbarsChanged) END;
			SELF.hScrollbar := hScrollbar; SELF.vScrollbar := vScrollbar;
			hScrollbar.onPositionChanged.Add(ScrollbarsChanged);
			vScrollbar.onPositionChanged.Add(ScrollbarsChanged);
			UpdateScrollbars;
			Release;
		END SetScrollbars;

		PROCEDURE ScrollbarsChanged*(sender, data : ANY);
		BEGIN
			IF document # NIL THEN
				IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.ScrollbarsChanged, sender, data)
				ELSE
					IF sender = vScrollbar THEN
						docOriginY := -ENTIER(vScrollbar.pos.Get()/100*(zoomFactor*document.GetPageHeight()+50)) + 30;
						(* KernelLog.Int(docOriginY, 0); KernelLog.Ln; *)
					ELSIF sender = hScrollbar THEN
						docOriginX := -ENTIER(hScrollbar.pos.Get()/100*(zoomFactor*document.GetPageWidth()+50)) + 30;
						(* KernelLog.Int(docOriginX, 0); KernelLog.Ln; *)
					END;
					Invalidate;
				END;
			END;
		END ScrollbarsChanged;

		PROCEDURE UpdateScrollbars;
		BEGIN
			IF document # NIL THEN
				IF vScrollbar # NIL THEN
					(* vScrollbar.max.Set(ENTIER(document.GetPageHeight()*zoomFactor)); *)
					(* vScrollbar.pageSize.Set(bounds.GetHeight());  *)
					vScrollbar.pos.Set(docOriginY);
				END;
				IF hScrollbar # NIL THEN
					(* hScrollbar.visible.Set(layout.textWidth > bounds.GetWidth()); *)
					(* hScrollbar.max.Set(ENTIER(document.GetPageWidth()*zoomFactor)); *)
					(* hScrollbar.pageSize.Set(bounds.GetWidth()); *)
					hScrollbar.pos.Set(docOriginX);
				END;
			END;
		END UpdateScrollbars;

		PROCEDURE SetDocument*(doc: DTPData.Document);
		BEGIN
			document := doc;
(*			IF (document.GetPageWidth() > 0) & (document.GetPageHeight() > 0) & THEN
				ready := TRUE;
			END;
*)		END SetDocument;

		PROCEDURE GetDocument*(): DTPData.Document;
		BEGIN
			RETURN document;
		END GetDocument;

		PROCEDURE SetZoomMode*(mode : LONGINT);
		BEGIN
			zoomMode := mode;
			Resized;
			Invalidate;
			zoomUser := zoomFactor;
		END SetZoomMode;

		PROCEDURE SetRenderZoomMode*(mode: LONGINT);
		VAR (* tempString: Strings.String; *)
			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			ccontent : DTPData.ContentObject;
		BEGIN
			zoomMode := mode;
			CASE zoomMode OF										(* zoom current view *)
					0: ZoomFitDoc;
				|	1: ZoomFitWidth;
				|	2: ZoomFitHeight;
				|	3: ZoomFitFrame;
				|	4: ZoomFitOriginal;
				|	5: ZoomFitUser;
			ELSE
			END;
			cpage := document.GetCurrentMasterPage();
			IF (cpage # NIL) THEN
				cframe := cpage.GetFirstFrame();
				WHILE (cframe # NIL) DO
					ccontent := cframe.GetContent();
					IF ccontent # NIL THEN
						ccontent.Resize(zoomFactor);
						ccontent.SetSize(ENTIER(cframe.GetWidth()*zoomFactor), ENTIER(cframe.GetHeight()*zoomFactor));
					END;
					cframe := cframe.next;
				END;
			END;
			cpage := document.GetCurrentPage();
			IF (cpage # NIL) THEN
				cframe := cpage.GetFirstFrame();
				WHILE (cframe # NIL) DO
					(* tempString := cframe.GetName(); *)
					(* KernelLog.String("Setting: "); KernelLog.String(tempString^); KernelLog.Int(ENTIER(cframe.GetWidth()*zoomFactor), 0); KernelLog.Int(ENTIER(cframe.GetHeight()*zoomFactor), 0); KernelLog.Ln; *)
					ccontent := cframe.GetContent();
					IF ccontent # NIL THEN
						ccontent.Resize(zoomFactor);
						ccontent.SetSize(ENTIER(cframe.GetWidth()*zoomFactor), ENTIER(cframe.GetHeight()*zoomFactor));
					END;
					cframe := cframe.next;
				END;
			END;
			(* Invalidate; *)
		END SetRenderZoomMode;

		PROCEDURE ZoomFitHeight*;
		VAR drawPanelW, drawPanelH : REAL;
			docW, docH : REAL;
		BEGIN
			docW := document.GetPageWidth();
			docH := document.GetPageHeight();
			drawPanelW := bounds.GetWidth();
			drawPanelH := bounds.GetHeight();
			zoomFactor := (drawPanelH - 2*RULERSIZE)/docH;

		END ZoomFitHeight;

		PROCEDURE ZoomFitWidth*;
		VAR drawPanelW, drawPanelH : REAL;
			docW, docH : REAL;
		BEGIN
			docW := document.GetPageWidth();
			docH := document.GetPageHeight();
			drawPanelW := bounds.GetWidth();
			drawPanelH := bounds.GetHeight();
			zoomFactor := (drawPanelW - 2*RULERSIZE)/docW;

		END ZoomFitWidth;

		PROCEDURE ZoomFitDoc*;
		VAR drawPanelW, drawPanelH : REAL;
			docW, docH : REAL;
			ratioPanel, ratioDoc : REAL;
		BEGIN
			docW := document.GetPageWidth();
			docH := document.GetPageHeight();
			drawPanelW := bounds.GetWidth();
			drawPanelH := bounds.GetHeight();
			ratioPanel := (drawPanelW-RULERSIZE) / (drawPanelH-RULERSIZE);
			ratioDoc := docW / docH;

			IF ratioDoc > ratioPanel THEN
				zoomFactor := (drawPanelW-2*RULERSIZE)/docW;		(* zoom fit width *)
			ELSE
				zoomFactor := (drawPanelH-2*RULERSIZE)/docH;		(* zoom fit height *)
			END

		END ZoomFitDoc;

		PROCEDURE ZoomFitFrame*;
		VAR drawPanelW, drawPanelH : REAL;
			frameW, frameH : REAL;
			cpage : DTPData.PageObject;
		BEGIN
			IF (document # NIL) THEN
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;
				IF (cpage # NIL) & (cpage.currentFrame # NIL) THEN
					frameW := cpage.currentFrame.GetWidth();
					frameH := cpage.currentFrame.GetHeight();
					drawPanelW := bounds.GetWidth();
					drawPanelH := bounds.GetHeight();
					IF frameW > frameH THEN
						zoomFactor := (drawPanelW-2*RULERSIZE)/frameW;
					ELSE
						zoomFactor := (drawPanelH-2*RULERSIZE)/frameH;
					END;
					docOriginX := ENTIER(30-cpage.currentFrame.GetX()*zoomFactor);
					docOriginY := ENTIER(30-cpage.currentFrame.GetY()*zoomFactor);
					(* KernelLog.Int(docOriginX, 0); KernelLog.Ln; *)
				END;
				zoomUser := zoomFactor;
				SetZoomMode(5);
			END;

		END ZoomFitFrame;

		PROCEDURE ZoomFitUser*;
		BEGIN
			zoomFactor := zoomUser;
		END ZoomFitUser;

		PROCEDURE ZoomFitOriginal*;
		BEGIN
			zoomFactor := 1/point;
		END ZoomFitOriginal;

		PROCEDURE ZoomIncrease*;
		VAR (* tempString : ARRAY 64 OF CHAR; *)
		BEGIN
			zoomUser := 1.1*zoomFactor;
			(* Strings.FloatToStr(zoomUser, 0,4,0,tempString); KernelLog.String(tempString); *)
			(* ZoomFitUser; *)
		END ZoomIncrease;

		PROCEDURE ZoomDecrease*;
		VAR (* tempString : ARRAY 64 OF CHAR; *)
		BEGIN
			zoomUser := 0.9*zoomFactor;
			(* Strings.FloatToStr(zoomUser, 0,4,0,tempString); KernelLog.String(tempString); *)
			(* ZoomFitUser; *)
		END ZoomDecrease;

		PROCEDURE SetZoomUser*(factor: REAL);
		BEGIN
			zoomUser := factor;
		END SetZoomUser;

		PROCEDURE SetZoomFactor*(factor : REAL);
		BEGIN
			zoomFactor := factor;
		END SetZoomFactor;

		PROCEDURE GetZoomFactor*() : REAL;
		BEGIN
			RETURN zoomFactor
		END GetZoomFactor;

		PROCEDURE SetOrigin*(x, y : LONGINT);
		BEGIN
			docOriginX := x;
			docOriginY := y;
		END SetOrigin;

		PROCEDURE GetOriginX*(): LONGINT;
		BEGIN
			RETURN docOriginX
		END GetOriginX;

		PROCEDURE GetOriginY*(): LONGINT;
		BEGIN
			RETURN docOriginY
		END GetOriginY;

		PROCEDURE SetSnapDistance*(distance: REAL);
		BEGIN
			snapDistance := distance;
		END SetSnapDistance;

		PROCEDURE GetSnapDistance*(): REAL;
		BEGIN
			RETURN snapDistance;
		END GetSnapDistance;

		PROCEDURE SetSnap*(s2grid: BOOLEAN);
		BEGIN
			snapToGrid := s2grid;
		END SetSnap;

		PROCEDURE GetSnap*(): BOOLEAN;
		BEGIN
			RETURN snapToGrid;
		END GetSnap;

		PROCEDURE SetPreviewMode*(prevMode : BOOLEAN);
		BEGIN
			previewMode := prevMode;
		END SetPreviewMode;

		PROCEDURE GetPreviewMode*() : BOOLEAN;
		BEGIN
			RETURN previewMode;
		END GetPreviewMode;

		PROCEDURE SetMasterEditMode*(masterMode: BOOLEAN);
		BEGIN
			mpageMode := masterMode;
		END SetMasterEditMode;

		PROCEDURE GetMasterEditMode*(): BOOLEAN;
		BEGIN
			RETURN mpageMode;
		END GetMasterEditMode;

		PROCEDURE ShowGrid*(sGrid : BOOLEAN);
		BEGIN
			showGrid := sGrid;
		END ShowGrid;

		PROCEDURE SetGrid*(gDist : REAL; gDiv : LONGINT);
		BEGIN
			gridDistance := gDist;
			gridDivision := gDiv;
		END SetGrid;

		PROCEDURE WheelMove(dz: LONGINT);
		BEGIN
			IF ~previewMode THEN
				IF wheelMode = 0 THEN								(* wheel zoom *)
					zoomMode := 5;
					zoomUser := (1+dz/30)*zoomFactor;
					(* ZoomFitUser; *)
					Resized;
					Invalidate;
				ELSIF wheelMode = 1 THEN							(* wheel scroll vertical *)

				ELSIF wheelMode = 2 THEN							(* wheel scroll horizontal *)

				ELSE
				END;
			END;
		END WheelMove;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)
			fx, fy: REAL;
			px, py, pw, ph: LONGINT;
			horizontal: BOOLEAN;
			snapLeft, snapTop, snapRight, snapBottom : BOOLEAN;

		BEGIN
			down := 0 IN keys;
			IF document # NIL THEN
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;
				IF ~previewMode THEN									(* Document Edit Mode *)
					x0 := x; y0 := y;
					IF WillSnap((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, snapLeft, snapTop, snapRight, snapBottom, fx, fy) THEN
						IF snapLeft OR snapRight THEN tx0 := fx ELSE tx0 := -1; END;
						IF snapTop OR snapBottom THEN ty0 := fy ELSE ty0 := -1; END;
						snapOnCreate := TRUE;
					END;
					IF ~selectionON THEN								(* plugin Selected *)
						cframe := cpage.GetCurrentFrame();
						(* click inside Frame Bounds *)
						IF (cframe # NIL) & WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER(cframe.GetX()*zoomFactor)+docOriginX, ENTIER(cframe.GetY()*zoomFactor)+docOriginY, ENTIER((cframe.GetX()+cframe.GetWidth())*zoomFactor)+docOriginX, ENTIER((cframe.GetY()+cframe.GetHeight())*zoomFactor)+docOriginY)) THEN
							ccontent := cframe.GetContent();
							ccontent.FocusReceived;
							ccontent.PointerDown(x-ENTIER(cframe.GetX()*zoomFactor)-docOriginX, y-ENTIER(cframe.GetY()*zoomFactor)-docOriginY, keys);
							addobject := FALSE;
						ELSE
							addobject := TRUE;
							IF ccontent # NIL THEN
								ccontent.FocusLost();
							END;
						END;

						props.SetInactive;
						props.InitValues;

					ELSE												(* selectiontool *)
						cframe := cpage.GetCurrentFrame();
						cguide := cpage.GetCurrentGuide();
						IF ccontent # NIL THEN							(* Plugin Focus Lost *)
							ccontent.FocusLost;
						END;
						IF cframe # NIL THEN
							px := ENTIER(cframe.GetX()*zoomFactor)+docOriginX;
							py := ENTIER(cframe.GetY()*zoomFactor)+docOriginY;
							pw := ENTIER(cframe.GetWidth()*zoomFactor);
							ph := ENTIER(cframe.GetHeight()*zoomFactor);
							IF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(px+2, py+2, px+pw-2, py+ph-2)) THEN
								move := TRUE; quality := FALSE;
								dx := px - x;
								dy := py - y;
							ELSE
								(* resize *)
								res := IsInFrameHandle(x, y);
								IF res >= 0 THEN
									fx0 := ENTIER(cframe.GetX()*zoomFactor)+docOriginX;
									fy0 := ENTIER(cframe.GetY()*zoomFactor)+docOriginY;
									fx1 := ENTIER(cframe.GetWidth()*zoomFactor)+fx0;
									fy1 := ENTIER(cframe.GetHeight()*zoomFactor)+fy0;
									resize := TRUE; quality := FALSE;
								END;
							END;
						ELSIF cguide # NIL THEN
							horizontal := cguide.GetHorizontal();
							IF horizontal THEN
								IF (y1<(cguide.GetPosition()*zoomFactor+docOriginY+1)) & (y1>(cguide.GetPosition()*zoomFactor+docOriginY-1)) THEN
									moveguide := TRUE;
								END;
							ELSE
								IF (x1<(cguide.GetPosition()*zoomFactor+docOriginX+1)) & (x1>(cguide.GetPosition()*zoomFactor+docOriginX-1)) THEN
									moveguide := TRUE;
								END;
							END;
						END;
						(* add guide *)
						res2 := IsInRuler(x, y);
						IF res2 >= 0 THEN
							addguide := TRUE;
						END;
					END;
					UpdateProps;
				ELSE															(* preview Mode *)
					IF 0 IN keys THEN
						document.NextPage;
						Resized;
						Invalidate;
					ELSIF 2 IN keys THEN
						document.PrevPage;
						Resized;
						Invalidate;
					END;
					ownerWindowUpdatePageNumber;
				END;
			END;
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)			fx, fy, tx, ty: REAL;
			xs, ys, xe, ye, w, h: LONGINT;
			oldx1, oldy1 : LONGINT;
			pointerres: LONGINT;
			manager: WMWindowManager.WindowManager;
			snapLeft, snapTop, snapRight, snapBottom : BOOLEAN;

		BEGIN
			IF document # NIL THEN
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;
				IF ~previewMode THEN											(* Document Edit Mode *)
					cframe := cpage.GetCurrentFrame();
					cguide := cpage.GetCurrentGuide();
					oldx1 := x1; oldy1:= y1;
					x1 := x; y1 := y;
					IF selectionON THEN										(* selection tool *)
						IF move THEN											(* move frame *)
							quality := FALSE;
							IF WillSnap((x+dx-docOriginX)/zoomFactor, (y+dy-docOriginY)/zoomFactor, (x+dx-docOriginX)/zoomFactor+cframe.GetWidth(), (y+dy-docOriginY)/zoomFactor+cframe.GetHeight(), snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN			(* snap upper/left & lower/right*)
								IF snapLeft THEN fx := tx;
								ELSIF snapRight THEN fx := tx-cframe.GetWidth();
								ELSE fx := (x+dx-docOriginX)/zoomFactor; END;
								IF snapTop THEN fy := ty;
								ELSIF snapBottom THEN fy := ty-cframe.GetHeight();
								ELSE fy := (y+dy-docOriginY)/zoomFactor; END;

								cframe.SetPosition(fx, fy);
							ELSE
								fx := (x + dx - docOriginX)/zoomFactor;
								fy := (y + dy - docOriginY)/zoomFactor;
								cframe.SetPosition(fx, fy);
							END;
							x1 := ENTIER(fx*zoomFactor)-dx+docOriginX; y1 := ENTIER(fy*zoomFactor)-dy+docOriginY;
							InvalidateRect(WMRectangles.MakeRect(Strings.Min(x1, oldx1)+dx-10, Strings.Min(oldy1, y1)+dy-10, ENTIER(cframe.GetWidth()*zoomFactor)+Strings.Max(x1, oldx1)+dx+10, ENTIER(cframe.GetHeight()*zoomFactor)+Strings.Max(y1, oldy1)+dy+10));
						ELSIF resize THEN										(* resize frame *)
							quality := FALSE;
							xs := ENTIER(cframe.GetX()*zoomFactor)+docOriginX;
							ys := ENTIER(cframe.GetY()*zoomFactor)+docOriginY;
							w := ENTIER(cframe.GetWidth()*zoomFactor);
							h := ENTIER(cframe.GetHeight()*zoomFactor);
							xe := xs + w; ye := ys +h;
							CASE res OF
								  0: cframe.SetExtent((x-docOriginX)/zoomFactor, cframe.GetY(), (fx1-x)/zoomFactor, cframe.GetHeight());
								| 1: cframe.SetExtent((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (fx1-x)/zoomFactor, (fy1-y)/zoomFactor);
								| 2: cframe.SetExtent(cframe.GetX(), (y-docOriginY)/zoomFactor, cframe.GetWidth(), (fy1-y)/zoomFactor);
								| 3: cframe.SetExtent(cframe.GetX(), (y-docOriginY)/zoomFactor, (x-fx0)/zoomFactor, (fy1-y)/zoomFactor);
								| 4:	fx := (x-xs)/zoomFactor; fy := cframe.GetHeight();
									IF WillSnap((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN
										IF snapLeft OR snapRight THEN fx := tx-cframe.GetX(); END;
									END; cframe.SetSize(fx, fy);
									cframe.SetSize(fx, fy);
								| 5: fx := (x-xs)/zoomFactor; fy := (y-ys)/zoomFactor;
									IF WillSnap((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN
										IF snapLeft OR snapRight THEN fx := tx-cframe.GetX(); END;
										IF snapTop OR snapBottom THEN fy := ty-cframe.GetY(); END;
									END; cframe.SetSize(fx, fy);
								| 6:	fx := cframe.GetWidth(); fy := (y-ys)/zoomFactor;
									IF WillSnap((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN
										IF snapTop OR snapBottom THEN fy := ty-cframe.GetY(); END;
									END; cframe.SetSize(fx, fy);
								| 7: cframe.SetExtent((x-docOriginX)/zoomFactor, cframe.GetY(), (fx1-x)/zoomFactor, (y-fy0)/zoomFactor);
							ELSE
							END;
							ccontent := cframe.GetContent(); ccontent.SetSize(ENTIER(cframe.GetWidth()*zoomFactor), ENTIER(cframe.GetHeight()*zoomFactor));
							InvalidateRect(WMRectangles.MakeRect(ENTIER(DTPUtilities.Min(cframe.GetX(), DTPUtilities.Min(oldfx0, oldfx1))*zoomFactor)+docOriginX-10, ENTIER(DTPUtilities.Min(cframe.GetY(), DTPUtilities.Min(oldfy0, oldfy1))*zoomFactor)+docOriginY-10, ENTIER(DTPUtilities.Max((cframe.GetX()+cframe.GetWidth()), DTPUtilities.Max(oldfx1, oldfx0))*zoomFactor)+docOriginX+15, ENTIER(DTPUtilities.Max(cframe.GetY()+cframe.GetHeight(), DTPUtilities.Max(oldfy1, oldfy0))*zoomFactor)+docOriginY+15));
							oldfx0 := cframe.GetX(); oldfy0 := cframe.GetY(); oldfx1:= cframe.GetX()+cframe.GetWidth(); oldfy1:= cframe.GetY()+cframe.GetHeight();
						ELSIF moveguide THEN									(* move guide *)
							IF cguide.GetHorizontal() THEN
								IF WillSnap(0, (y-docOriginY)/zoomFactor, 1,(y-docOriginY)/zoomFactor, snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN
									IF snapTop THEN cguide.SetPosition(ty); 		(* snap guide *)
									ELSE cguide.SetPosition((y-docOriginY)/zoomFactor); END;
								END;
								oldy1 := gy; gy := y;
								InvalidateRect(WMRectangles.MakeRect(0, Strings.Min(oldy1, gy)-10, ENTIER(document.GetPageWidth()*zoomFactor)+docOriginX, Strings.Max(oldy1, gy)+10));
							ELSE
								IF WillSnap((x-docOriginX)/zoomFactor, 0, (x-docOriginX)/zoomFactor,1, snapLeft, snapTop, snapRight, snapBottom, tx, ty) THEN
									IF snapLeft THEN cguide.SetPosition(tx);		(* snap guide *)
									ELSE cguide.SetPosition((x-docOriginX)/zoomFactor); END;
								END;
								oldx1 := gx; gx := x;
								InvalidateRect(WMRectangles.MakeRect(Strings.Min(oldx1, gx)-10, 0, Strings.Max(oldx1, gx)+10, ENTIER(document.GetPageHeight()*zoomFactor)+docOriginX));
							END;
						ELSIF addguide THEN									(* create new guide object *)
							oldx1 := gx; gx := x;
							IF res2 = 0 THEN										(* Horizontal guide *)
								InvalidateRect(WMRectangles.MakeRect(0, Strings.Min(oldy1, gy)-10, ENTIER(document.GetPageWidth()*zoomFactor)+docOriginX, Strings.Max(oldy1, gy)+10));
							ELSE												(* Vertical guide *)
								InvalidateRect(WMRectangles.MakeRect(Strings.Min(oldx1, gx)-10, 0, Strings.Max(oldx1, gx)+10, ENTIER(document.GetPageHeight()*zoomFactor)+docOriginX));
							END;
						ELSE
						END;
						manager := WMWindowManager.GetDefaultManager();
						IF cframe # NIL THEN
							(* change pointerinfo *)
							pointerres := IsInFrameHandle(x, y);

							CASE pointerres OF
									0: IF (oldPointerInfo # 0) & ~down THEN
										oldPointerInfo := 0;
										SetPointerInfo(manager.pointerLeftRight); END;
								|	1: IF (oldPointerInfo # 1) & ~down THEN
										oldPointerInfo := 1;
										SetPointerInfo(manager.pointerULDR); END;
								|	2: IF (oldPointerInfo # 2) & ~down THEN
										oldPointerInfo := 2;
										SetPointerInfo(manager.pointerUpDown); END;
								|	3: IF (oldPointerInfo # 3) & ~down THEN
										oldPointerInfo := 3;
										SetPointerInfo(manager.pointerURDL); END;
								|	4: IF (oldPointerInfo # 4) & ~down THEN
										oldPointerInfo := 4;
										SetPointerInfo(manager.pointerLeftRight); END;
								|	5: IF (oldPointerInfo # 5) & ~down THEN
										oldPointerInfo := 5;
										SetPointerInfo(manager.pointerULDR); END;
								|	6: IF (oldPointerInfo # 6) & ~down THEN
										oldPointerInfo := 6;
										SetPointerInfo(manager.pointerUpDown); END;
								|	7: IF (oldPointerInfo # 7) & ~down THEN
										oldPointerInfo := 7;
										SetPointerInfo(manager.pointerURDL); END;
								|	8: IF (oldPointerInfo # 8) & ~down THEN
										oldPointerInfo := 8;
										SetPointerInfo(manager.pointerMove); END;
							ELSE
								IF (oldPointerInfo # -1) & ~down THEN
									SetPointerInfo(manager.pointerStandard); oldPointerInfo := -1;
								END;
							END;
						ELSIF cguide # NIL THEN
							IF cguide.GetHorizontal() THEN
								IF (y>(cguide.GetPosition()*zoomFactor)+docOriginY-1) & (y<(cguide.GetPosition()*zoomFactor)+docOriginY+1) THEN
									IF (x<(document.GetPageWidth()*zoomFactor)+docOriginX) & (x>docOriginX) & ~down THEN
										SetPointerInfo(manager.pointerUpDown);
									END;
								ELSIF ~down THEN
									SetPointerInfo(manager.pointerStandard);
								END;
							ELSE
								IF (x>(cguide.GetPosition()*zoomFactor)+docOriginX-1) & (x<(cguide.GetPosition()*zoomFactor)+docOriginX+1) THEN
									IF (y<(document.GetPageHeight()*zoomFactor)+docOriginY) & (y>docOriginY) & ~down THEN
										SetPointerInfo(manager.pointerLeftRight);
									END;
								ELSIF ~down THEN
									SetPointerInfo(manager.pointerStandard);
								END;
							END;
						ELSE
							(* fix pointer *)
							IF GetPointerInfo() # manager.pointerStandard THEN
								SetPointerInfo(manager.pointerStandard);
							END;
						END;
					ELSE												(* plugin selected *)
						IF down THEN
							IF addobject THEN							(* on create new content object *)
								InvalidateRect(WMRectangles.MakeRect(Strings.Min(vx0, vx1)-10, Strings.Min(vy0, vy1)-10, Strings.Max(vx0, vx1)+10, Strings.Max(vy0, vy1)+10));
							ELSE
								IF  (cframe # NIL) & WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER(cframe.GetX()*zoomFactor)+docOriginX, ENTIER(cframe.GetY()*zoomFactor)+docOriginY, ENTIER((cframe.GetX()+cframe.GetWidth())*zoomFactor)+docOriginX, ENTIER((cframe.GetY()+cframe.GetHeight())*zoomFactor)+docOriginY)) THEN
									ccontent := cframe.GetContent();
									ccontent.PointerMove(x-ENTIER(cframe.GetX()*zoomFactor)-docOriginX, y-ENTIER(cframe.GetY()*zoomFactor)-docOriginY, keys);
								END;
							END;
						ELSE
							manager := WMWindowManager.GetDefaultManager();
							IF  (cframe # NIL) & WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER(cframe.GetX()*zoomFactor)+docOriginX, ENTIER(cframe.GetY()*zoomFactor)+docOriginY, ENTIER((cframe.GetX()+cframe.GetWidth())*zoomFactor)+docOriginX, ENTIER((cframe.GetY()+cframe.GetHeight())*zoomFactor)+docOriginY)) THEN
								ccontent := cframe.GetContent();
								ccontent.PointerMove(x-ENTIER(cframe.GetX()*zoomFactor)-docOriginX, y-ENTIER(cframe.GetY()*zoomFactor)-docOriginY, keys);
								(* Set Plugin Pointer *)
								IF ~plugPointer THEN
									plugPointer := TRUE;
									SetPointerInfo(ccontent.GetPluginPointer());
								END;
							ELSE
								(* Set Normal Pointer *)
								IF plugPointer THEN
									plugPointer := FALSE;
									SetPointerInfo(manager.pointerStandard);
								END;
							END;
						END;

					END;

					IF down THEN
						(* Invalidate; *)
						IF propertyOpen THEN
							quality := FALSE;
							UpdateProps;
							quality := TRUE;
						END;
					ELSE
						UpdateCoordinates;
					END;
				ELSE													(* preview Mode *)

				END;
			END;
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR string, tempString, tempString2: ARRAY 32 OF CHAR;
			content, activeContent: DTPData.ContentObject;
			resguide: DTPData.GuideObject;
			resframe: DTPData.FrameObject;
			horizontal : BOOLEAN;
			fx, fy, fw, fh: REAL;
			px, py, pw, ph: LONGINT;
			snapL, snapT, snapR, snapB: BOOLEAN;
		BEGIN
			down :=  0 IN keys;
			IF document # NIL THEN
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF ~previewMode THEN									(* Document Edit Mode *)
					IF ~selectionON THEN								(* -- create Object -- *)
						IF (x0 = x1) & (y0 = y1) THEN						(* not dragged only clicked *)
							IF (cframe # NIL) & WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER(cframe.GetX()*zoomFactor)+docOriginX, ENTIER(cframe.GetY()*zoomFactor)+docOriginY, ENTIER((cframe.GetX()+cframe.GetWidth())*zoomFactor)+docOriginX, ENTIER((cframe.GetY()+cframe.GetHeight())*zoomFactor)+docOriginY)) THEN
								ccontent := cframe.GetContent();
								ccontent.PointerUp(x-ENTIER(cframe.GetX()*zoomFactor)-docOriginX, y-ENTIER(cframe.GetY()*zoomFactor)-docOriginY, keys);
							ELSE
(*							(* input dialog frame size *)					(* disable pointerevent?? *)
								IF ~newObjOpen THEN
									newObjOpen := TRUE;
									NEW(nObj, SELF);
									dRes := nObj.Show(fw, fh);
									IF dRes THEN
										cpage.AddFrame((x0-docOriginX)/zoomFactor, (y0-docOriginY)/zoomFactor, fw, fh);
									END;
								END;
*)							END;
						ELSE											(* dragged *)
							IF addobject THEN
								IF (cpage # NIL) THEN					(* create frame *)
(*									fx := (Strings.Min(x0,x1)-docOriginX)/zoomFactor;
									fy := (Strings.Min(y0,y1)-docOriginY)/zoomFactor;
									fw := (Strings.Max(x0,x1)-Strings.Min(x0,x1))/zoomFactor;
									fh := (Strings.Max(y0,y1)-Strings.Min(y0,y1))/zoomFactor;
*)
									fx := (x0-docOriginX)/zoomFactor;
									fy := (y0-docOriginY)/zoomFactor;
									fw := (x1-x0)/zoomFactor;
									fh := (y1-y0)/zoomFactor;
									IF snapOnCreate THEN
										IF tx0 > -1 THEN fx := tx0; fw := (x1-docOriginX)/zoomFactor - tx0; END;
										IF ty0 > -1 THEN  fy := ty0; fh := (y1-docOriginY)/zoomFactor - ty0; END;
										snapOnCreate := FALSE;
										tx0 := -1; ty0 := -1;
									END;
									IF WillSnap((x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, (x-docOriginX)/zoomFactor, (y-docOriginY)/zoomFactor, snapL, snapT, snapR, snapB, tx1, ty1) THEN
										IF snapL OR snapR THEN fw := tx1-fx END;
										IF snapT OR snapB THEN fh := ty1-fy END;
									END;
									cpage.AddFrame(fx, fy, fw, fh);

									(* create content & add it *)
									content := newPluginObject();
									content.SetSize(ENTIER(fw*zoomFactor), ENTIER(fh*zoomFactor));
									content.Resize(zoomFactor);
									cframe := cpage.GetCurrentFrame();
									cframe.FixExtent();
									COPY(activeTool^, string);
									IF string = "Frame" THEN string := "Empty" END;
									Strings.Append(string, "Frame"); COPY(string, tempString2);
									Strings.IntToStr(document.objectCounter, tempString);
									Strings.Append(string, tempString);
									WHILE document.GetContentByName(string) # NIL DO (* find next free name *)
										INC(document.objectCounter);
										Strings.IntToStr(document.objectCounter, tempString);
										COPY(tempString2, string);
										Strings.Append(string, tempString);
									END;
									cframe.SetName(Strings.NewString(string));
									cframe.SetType(activeTool);
									content.contentName := Strings.NewString(string);
									content.ownerDoc := document;
									cframe.SetContent(content);
									document.AddContent(content);
									IF activeFrame # NIL THEN
										activeContent := activeFrame.GetContent();
										activeContent.Hide;
									END;
									content.Show(propsX, propsY); activeFrame := cframe;
									InvalidateRect(WMRectangles.MakeRect(Strings.Min(x0, x1)-5, Strings.Min(y0, y1)-5, Strings.Max(x0, x1)+5, Strings.Max(y0, y1)+5));
								END;
							ELSE										(* forward click to plugin *)
								IF (cframe # NIL) & WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER(cframe.GetX()*zoomFactor)+docOriginX, ENTIER(cframe.GetY()*zoomFactor)+docOriginY, ENTIER((cframe.GetX()+cframe.GetWidth())*zoomFactor)+docOriginX, ENTIER((cframe.GetY()+cframe.GetHeight())*zoomFactor)+docOriginY)) THEN
									ccontent := cframe.GetContent();
									ccontent.PointerUp(x, y, keys);
								ELSE

								END;
							END;
							addobject := FALSE;
						END;
					ELSE												(* -- select -- *)
						IF (x0 = x1) & (y0 = y1) & ~resize THEN			(* select frame at x, y top *)
							cframe := cpage.GetLastFrame(); resframe := NIL;
							WHILE (cframe # NIL) & (resframe = NIL) DO
								px := ENTIER(cframe.GetX()*zoomFactor)+docOriginX;
								py := ENTIER(cframe.GetY()*zoomFactor)+docOriginY;
								pw := ENTIER(cframe.GetWidth()*zoomFactor);
								ph := ENTIER(cframe.GetHeight()*zoomFactor);
								IF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(px, py, px+pw, py+ph)) THEN
									resframe := cframe;
								END;
								cframe := cframe.prev;
							END;										(* select guide *)
							cguide := cpage.GetLastGuide(); resguide := NIL;
							WHILE (cguide # NIL) & (resguide = NIL) DO
								horizontal := cguide.GetHorizontal();
								IF horizontal THEN
									IF (y1<(cguide.GetPosition()*zoomFactor+docOriginY+1)) & (y1>(cguide.GetPosition()*zoomFactor+docOriginY-1)) THEN
										resguide := cguide;
									END;
								ELSE
									IF (x1<(cguide.GetPosition()*zoomFactor+docOriginX+1)) & (x1>(cguide.GetPosition()*zoomFactor+docOriginX-1)) THEN
										resguide := cguide;
									END;
								END;
								cguide := cguide.prev
							END;
							cpage.currentGuide := resguide;
							cpage.currentFrame := resframe;
							(* display the current content properties *)
							IF resframe # NIL THEN
								IF resframe # activeFrame THEN
									IF activeFrame # NIL THEN
										activeContent := activeFrame.GetContent();
										activeContent.Hide;
									END;
									activeFrame := resframe;
									activeContent := activeFrame.GetContent();
									activeContent.Show(propsX, propsY);
								END;
							ELSE
								IF activeFrame # NIL THEN
									activeContent := activeFrame.GetContent();
									activeContent.Hide;
								END;
								activeFrame := NIL;
							END;
						END;
						IF resize THEN 									(* fix beyond zero resize *)
							cframe := cpage.GetCurrentFrame();
							IF cframe # NIL THEN
								cframe.FixExtent();
							END;
						ELSIF addguide THEN							(* create guide object *)
							IF (x>docOriginX) & (y>docOriginY) THEN		(* only add if on page *)
								IF res2 = 0 THEN							(* Horizontal *)
									cpage.AddGuide((y-docOriginY)/zoomFactor, TRUE);
								ELSE									(* Vertical *)
									cpage.AddGuide((x-docOriginX)/zoomFactor, FALSE);
								END;
							END;
						END;
						move := FALSE;
						resize := FALSE;
						addguide := FALSE;
						moveguide := FALSE;
						quality := TRUE;
					END;
					Invalidate;
					UpdateProps;
					ownerWindowSetFocus;
				ELSE													(* Preview Mode *)

				END;
			END;
		END PointerUp;

		PROCEDURE KeyEvent(ucs: LONGINT; flags: SET; VAR keySym: LONGINT);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)			newFrame : DTPData.FrameObject;
			newContent: DTPData.ContentObject;
		BEGIN
			(* document := parentWindow.GetDocument(); *)
			IF document # NIL THEN
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;
				IF ~previewMode THEN									(* Document Edit Mode *)
					cframe := cpage.GetCurrentFrame();
					cguide := cpage.GetCurrentGuide();
					IF selectionON THEN								(* selection tool *)
						IF (cframe = NIL) & (cguide = NIL) THEN			(* nothing selected *)
							IF keySym =  016H THEN (* Ctrl-V *)
								IF DTPData.dollyFrame # NIL THEN
									newFrame := DTPData.dollyFrame.Clone();
									newContent := newFrame.GetContent();
									newContent.redrawProc := InvalidateCurrentFrame;
									newContent.updatePropsPosition := SetContentPropsPosition;
									newContent.Resize(zoomFactor);
									newContent.SetSize(ENTIER(newFrame.GetWidth()*zoomFactor), ENTIER(newFrame.GetHeight()*zoomFactor));
									cpage.InsertFrame(newFrame);
									UpdateProps;
									UpdateContentProps;
								ELSIF document.dollyGuide # NIL THEN
									cpage.AddGuide(document.dollyGuide.GetPosition(), document.dollyGuide.GetHorizontal());
									UpdateProps;
								END;
							ELSE
							END;
						ELSIF (cframe # NIL) THEN						(* frame selected *)
							IF keySym = 03H THEN (* Ctrl-C *)
								DTPData.dollyFrame := cframe.Clone();
								document.dollyGuide := NIL;
					 		ELSIF (keySym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
	 							DTPData.dollyFrame := cframe.Clone();
								document.dollyGuide := NIL;
							ELSIF keySym = 0FF51H THEN (* Cursor Left *)
								IF flags * Inputs.Shift = {} THEN
									IF flags * Inputs.Alt # {} THEN
										cframe.SetPosition(cframe.GetX()-2.5, cframe.GetY());
									ELSE
										cframe.SetPosition(cframe.GetX()-1/4, cframe.GetY());
									END;
									UpdateProps;
								END;
							ELSIF keySym = 0FF53H THEN (* Cursor Right *)
								IF flags * Inputs.Shift = {} THEN
									IF flags * Inputs.Alt # {} THEN
										cframe.SetPosition(cframe.GetX()+2.5, cframe.GetY());
									ELSE
										cframe.SetPosition(cframe.GetX()+1/4, cframe.GetY());
									END;
									UpdateProps;
								END;
							ELSIF keySym = 0FF54H THEN (* Cursor Down *)
								IF flags * Inputs.Shift = {} THEN
									IF flags * Inputs.Alt # {} THEN
										cframe.SetPosition(cframe.GetX(), cframe.GetY()+2.5);
									ELSE
										cframe.SetPosition(cframe.GetX(), cframe.GetY()+1/4);
									END;
									UpdateProps;
								END;
							ELSIF keySym = 0FF52H THEN (* Cursor Up *)
								IF flags * Inputs.Shift = {} THEN
									IF flags * Inputs.Alt # {} THEN
										cframe.SetPosition(cframe.GetX(), cframe.GetY()-2.5);
									ELSE
										cframe.SetPosition(cframe.GetX(), cframe.GetY()-1/4);
									END;
								END;
								UpdateProps;
							ELSIF keySym = 018H THEN (* Ctrl-X *)
								(* clone frame (to buffer) and remove current *)
								DTPData.dollyFrame := cframe.Clone();
								document.dollyGuide := NIL;
								cpage.DeleteFrame();
								UpdateProps;
								UpdateContentProps;
							ELSIF keySym =  016H THEN (* Ctrl-V *)
								IF DTPData.dollyFrame # NIL THEN
									newFrame := DTPData.dollyFrame.Clone();
									newContent := newFrame.GetContent();
									newContent.redrawProc := InvalidateCurrentFrame;
									newContent.updatePropsPosition := SetContentPropsPosition;
									newContent.Resize(zoomFactor);
									newContent.SetSize(ENTIER(newFrame.GetWidth()*zoomFactor), ENTIER(newFrame.GetHeight()*zoomFactor));
									cpage.InsertFrame(newFrame);
									UpdateProps;
									UpdateContentProps;
								END;
							ELSIF keySym = 0FFFFH THEN (* Delete *)
								newFrame := cpage.GetCurrentFrame();
								IF newFrame # NIL THEN
									newContent := newFrame.GetContent();
									newContent.OnDelete;
									cpage.DeleteFrame;
									UpdateProps;
									UpdateContentProps;
								END;
							ELSIF keySym = 0FFADH THEN (* grey minus *)
								IF cframe # NIL THEN
									cpage.Move2BackStep;
								END;
							ELSIF keySym = 0FFABH THEN (* grey plus *)
								IF cframe # NIL THEN
									cpage.Move2FrontStep;
								END;
							ELSE

							END;
						ELSIF (cguide # NIL) THEN					(* guide selected *)
							IF keySym = 0FFFFH THEN (* Delete *)
								(* delete currend guide *)
								cpage.DeleteGuide;
							END;
						ELSE

						END;
					ELSE 											(* plugins active *)
						IF cframe # NIL THEN
							ccontent := cframe.GetContent();
							ccontent.KeyEvent(ucs, flags, keySym);
						END;
					END;

					(* stateless keys *)
					IF keySym = 0FF56H THEN (* Page Down *)
						document.NextPage;
						UpdateProps;
						UpdateContentProps;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF55H THEN (* Page Up *)
						document.PrevPage;
						UpdateProps;
						UpdateContentProps;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF50H THEN (* Cursor Home *)
						document.FirstPage;
						UpdateProps;
						UpdateContentProps;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF57H THEN (* Cursor End *)
						document.LastPage;
						UpdateProps;
						UpdateContentProps;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF1BH THEN (* ESC *)
						ownerWindowExitFullScreen;
					ELSE
					END;

					Invalidate;
				ELSE													(* Preview Mode *)
					IF keySym = 0FF51H THEN (* Cursor Left *)
						document.PrevPage;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF53H THEN (* Cursor Right *)
						document.NextPage;
						ownerWindowUpdatePageNumber;
						Resized;
					ELSIF keySym = 0FF1BH THEN (* ESC *)
						ownerWindowExitFullScreen;
					ELSE
						(* KernelLog.Hex(keySym, 8); KernelLog.Ln; *)
					END;
					Invalidate;
				END;
			END;
		END KeyEvent;

		PROCEDURE WillSnap*(sx,sy, ex, ey: REAL; VAR leftSnap, topSnap, rightSnap, bottomSnap: BOOLEAN; VAR resX, resY: REAL): BOOLEAN;
		VAR
			result, point, rect: BOOLEAN;
			cpage, cmpage: DTPData.PageObject;
			cguide: DTPData.GuideObject;
			mTop, mBottom, mLeft, mRight, tempmLeft, tempmRight,  mWidth, mHeight, nx, ny, mx, my: REAL;
			gridInc : REAL;
			pageNumber : LONGINT;
		BEGIN
			result:= FALSE; leftSnap := FALSE; topSnap := FALSE; rightSnap := FALSE; bottomSnap := FALSE;
			gridInc := gridDistance/gridDivision;
			IF document # NIL THEN
				mTop := document.GetMarginTop(); mBottom:= document.GetPageHeight()-document.GetMarginBottom();
				mLeft := document.GetMarginLeft(); mRight := document.GetPageWidth()-document.GetMarginRight();
				mWidth := document.GetPageWidth(); mHeight := document.GetPageHeight();
				resX := 0; resY := 0;
				IF mpageMode THEN
					cpage := document.GetCurrentMasterPage();
				ELSE
					cpage := document.GetCurrentPage();
				END;

				(* grid snap *)
				IF snapToGrid THEN
					nx := sx+snapDistance; ny := sy+snapDistance;
					mx := ex+snapDistance; my := ey+snapDistance;
					(* vertical snap *)
					IF (((nx/gridInc)-ENTIER(nx/gridInc))*gridInc<2*snapDistance) THEN
						resX := ENTIER(nx/gridInc)*gridInc; leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
					ELSIF (((mx/gridInc)-ENTIER(mx/gridInc))*gridInc<2*snapDistance) THEN
						resX := ENTIER(mx/gridInc)*gridInc; rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
					END;
					(* horizontal snap *)
					IF (((ny/gridInc)-ENTIER(ny/gridInc))*gridInc<2*snapDistance) THEN
						resY := ENTIER(ny/gridInc)*gridInc; topSnap := TRUE; bottomSnap := FALSE; result := TRUE;
					ELSIF (((my/gridInc)-ENTIER(my/gridInc))*gridInc<2*snapDistance) THEN
						resY := ENTIER(my/gridInc)*gridInc; bottomSnap := TRUE; topSnap := FALSE; result := TRUE;
					END;
				END;

				(* margin snap *)
				IF document.GetFacingPages() THEN
					IF mpageMode THEN pageNumber := document.GetCurrentMasterPageNumber(); ELSE pageNumber := document.GetCurrentPageNumber(); END;
					IF  (pageNumber MOD 2 = 0) THEN
						tempmLeft := mWidth-mLeft;
						tempmRight := mWidth-mRight;
					ELSE
						tempmLeft := mLeft;
						tempmRight := mRight;
					END;
				ELSE
					tempmLeft := mLeft;
					tempmRight := mRight;
				END;
				IF (tempmLeft>ex-snapDistance) & (tempmLeft<ex+snapDistance) THEN
					resX := tempmLeft; rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
				ELSIF (tempmRight>ex-snapDistance) & (tempmRight<ex+snapDistance) THEN
					resX := tempmRight; rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
				END;
				IF (tempmLeft>sx-snapDistance) & (tempmLeft<sx+snapDistance) THEN
					resX := tempmLeft; leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
				ELSIF (tempmRight>sx-snapDistance) & (tempmRight<sx+snapDistance) THEN
					resX := tempmRight; leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
				END;
				IF (mBottom>ey-snapDistance) & (mBottom<ey+snapDistance) THEN
					resY := mBottom; bottomSnap := TRUE; topSnap := FALSE; result := TRUE;
				ELSIF (mTop>ey-snapDistance) & (mTop<ey+snapDistance) THEN
					resY := mTop; bottomSnap := TRUE; topSnap := FALSE; result := TRUE;
				END;
				IF (mBottom>sy-snapDistance) & (mBottom<sy+snapDistance) THEN
					resY := mBottom; topSnap := TRUE; bottomSnap := FALSE; result := TRUE;
				ELSIF (mTop>sy-snapDistance) & (mTop<sy+snapDistance) THEN
					resY := mTop; topSnap := TRUE; bottomSnap := FALSE; result := TRUE;
				END;

				(* guide snap *)
				point := (sx=ex) & (sy=ey);
				rect := (sx#ex) & (sy#ey);
				IF (point OR rect) THEN
					IF ~mpageMode THEN
						(* master guides *)
						cmpage := cpage.GetMasterPage();
						IF cmpage # NIL THEN
							cguide := cmpage.GetFirstGuide();
							WHILE (cguide # NIL) DO
								IF cguide.GetHorizontal() THEN
									IF (cguide.GetPosition()>sy-snapDistance) & (cguide.GetPosition()<sy+snapDistance) THEN
										resY := cguide.GetPosition(); topSnap := TRUE; bottomSnap:= FALSE; result := TRUE;
									ELSIF (cguide.GetPosition()>ey-snapDistance) & (cguide.GetPosition()<ey+snapDistance) THEN
										resY := cguide.GetPosition(); bottomSnap := TRUE; topSnap:= FALSE; result := TRUE;
									END;
								END;
								IF ~cguide.GetHorizontal() THEN
									IF (cguide.GetPosition()>sx-snapDistance) & (cguide.GetPosition()<sx+snapDistance) THEN
										resX := cguide.GetPosition(); leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
									ELSIF (cguide.GetPosition()>ex-snapDistance) & (cguide.GetPosition()<ex+snapDistance) THEN
										resX := cguide.GetPosition(); rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
									END;
								END;
								cguide := cguide.next;
							END;
						END;
					END;
					cguide := cpage.GetFirstGuide();
					(* document guides *)
					WHILE (cguide # NIL) DO
						IF cguide.GetHorizontal() THEN
							IF (cguide.GetPosition()>sy-snapDistance) & (cguide.GetPosition()<sy+snapDistance) THEN
								resY := cguide.GetPosition(); topSnap := TRUE; bottomSnap:= FALSE; result := TRUE;
							ELSIF (cguide.GetPosition()>ey-snapDistance) & (cguide.GetPosition()<ey+snapDistance) THEN
								resY := cguide.GetPosition(); bottomSnap := TRUE; topSnap:= FALSE; result := TRUE;
							END;
						END;
						IF ~cguide.GetHorizontal() THEN
							IF (cguide.GetPosition()>sx-snapDistance) & (cguide.GetPosition()<sx+snapDistance) THEN
								resX := cguide.GetPosition(); leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
							ELSIF (cguide.GetPosition()>ex-snapDistance) & (cguide.GetPosition()<ex+snapDistance) THEN
								resX := cguide.GetPosition(); rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
							END;
						END;
						cguide := cguide.next;
					END;
				END;

				(* document snap *)
				IF (0>sx-snapDistance) & (0<sx+snapDistance) THEN
					resX := 0; leftSnap := TRUE; rightSnap := FALSE; result := TRUE;
				END;
				IF (mWidth>ex-snapDistance) & (mWidth<ex+snapDistance) THEN
					resX := mWidth; rightSnap := TRUE; leftSnap := FALSE; result := TRUE;
				END;
				IF (0>sy-snapDistance) & (0<sy+snapDistance) THEN
					resY := 0; topSnap := TRUE; bottomSnap := FALSE; result := TRUE;
				END;
				IF (mHeight>ey-snapDistance) & (mHeight<ey+snapDistance) THEN
					resY := mHeight; bottomSnap := TRUE; topSnap := FALSE; result := TRUE;
				END;

			END;
			RETURN result;
		END WillSnap;

		PROCEDURE IsInRuler*(x, y: LONGINT): LONGINT;
		VAR result: LONGINT;
		BEGIN
			result := -2;
			IF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(RULERSIZE, 1, bounds.GetWidth(), RULERSIZE))) THEN
				result := 0;												(* Horizontal *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(1, RULERSIZE, RULERSIZE, bounds.GetHeight()))) THEN
				result := 1;												(* Vertical *)
			ELSE
				result := -1;
			END;
			RETURN result;
		END IsInRuler;

		PROCEDURE IsInFrameHandle*(x, y: LONGINT): LONGINT;
		VAR res, xs, ys, xe, ye, w, h: LONGINT;
			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
		BEGIN
			IF mpageMode THEN
				cpage := document.GetCurrentMasterPage();
			ELSE
				cpage := document.GetCurrentPage();
			END;
			cframe := cpage.GetCurrentFrame();
			res:= -1;
			xs := ENTIER(cframe.GetX()*zoomFactor)+docOriginX;
			ys := ENTIER(cframe.GetY()*zoomFactor)+docOriginY;
			w := ENTIER(cframe.GetWidth()*zoomFactor);
			h := ENTIER(cframe.GetHeight()*zoomFactor);
			xe := xs + w; ye := ys + h;
			IF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ENTIER((ys+ye)/2)-2, xs+1, ENTIER((ys+ye)/2)+2))) THEN
				res := 0;													(* left *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ys-4, xs+1, ys+1))) THEN
				res := 1;													(* top-left *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ys-4, ENTIER((xs+xe)/2)+3, ys+1))) THEN
				res := 2;													(* top *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ys-4, xe+5, ys+1))) THEN
				res := 3;													(* top-right *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ENTIER((ys+ye)/2)-2, xe+5, ENTIER((ys+ye)/2)+2))) THEN
				res := 4;													(* right *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ye, xe+5, ye+5))) THEN
				res := 5;													(* bottom-right *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ye, ENTIER((xs+xe)/2)+3, ye+5))) THEN
				res := 6;													(* bottom *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ye, xs+1, ye+5))) THEN
				res := 7;													(* bottom-left *)
			ELSIF (WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs+1, ys+1, xe-1, ye-1))) THEN
				res := 8;													(* inside *)
			ELSE
			END;
			RETURN res;
		END IsInFrameHandle;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas);
		VAR
		BEGIN
			Draw^(canvas);
			IF ~render THEN
				IF (document # NIL) & ready THEN
					CASE zoomMode OF										(* zoom current view *)
							0: ZoomFitDoc;
						|	1: ZoomFitWidth;
						|	2: ZoomFitHeight;
						|	3: ZoomFitFrame;
						|	4: ZoomFitOriginal;
						|	5: ZoomFitUser;
					ELSE
					END;

					DrawDocument(canvas);				(* document paper *)
					DrawContent(canvas);					(* content objects (frames)(grid..) *)
					DrawHelpers(canvas);					(* guides, pagemargin *)
					DrawSelectedFrame(canvas);			(* current frame/guide *)
					DrawRuler(canvas);						(* document ruler *)
					DrawUserAction(canvas);				(* user actions *)
				END;
			END;

		END Draw;

		PROCEDURE DrawRuler(canvas : WMGraphics.Canvas);
		VAR i, j: LONGINT;
			s : ARRAY 8OF CHAR;
			sc : ARRAY 1 OF CHAR;
			font : WMGraphics.Font;
		BEGIN
			font := GetFont();

			canvas.Fill(WMRectangles.MakeRect(RULERSIZE+1,0,bounds.GetWidth(), RULERSIZE+1), 0222222FFH, WMGraphics.ModeCopy);
			canvas.Fill(WMRectangles.MakeRect(0,RULERSIZE+1,RULERSIZE+1, bounds.GetHeight()), 0222222FFH, WMGraphics.ModeCopy);

			canvas.Fill(WMRectangles.MakeRect(RULERSIZE,1,bounds.GetWidth(), RULERSIZE), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			canvas.Fill(WMRectangles.MakeRect(1,RULERSIZE,RULERSIZE, bounds.GetHeight()), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			(* canvas.Line(0,0,200,200, 0FF0000FFH, WMGraphics.ModeSrcOverDst); *)
			canvas.Line(docOriginX, 1, docOriginX, RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
			canvas.Line(1, docOriginY, RULERSIZE-1, docOriginY, 0000000FFH, WMGraphics.ModeSrcOverDst);

			IF zoomFactor > 3 THEN
				(* horizontal ruler *)
				FOR i := 0 TO ENTIER (2*bounds.GetWidth()/zoomFactor)-1 BY 10 DO
					canvas.Line(docOriginX+ENTIER(i*zoomFactor), 1, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					Strings.IntToStr(i, s);
					canvas.DrawString(docOriginX+ENTIER(i*zoomFactor)+2, font.GetHeight()-3 , s);
				END;
				FOR i := 0 TO ENTIER (2*bounds.GetWidth()/zoomFactor)-1 DO
					IF i MOD 5 = 0 THEN
						canvas.Line(docOriginX+ENTIER(i*zoomFactor), RULERSIZE-6, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(docOriginX+ENTIER(i*zoomFactor), RULERSIZE-3, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					END;
				END;
				(* vertical ruler *)
				FOR i := 0 TO ENTIER (2*bounds.GetHeight()/zoomFactor)-1 BY 10 DO
					canvas.Line(1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					s := "       ";							(* remove old contents *)
					Strings.IntToStr(i, s);
					FOR j := 0 TO LEN(s)-1 DO
						sc[0] := s[j];
						canvas.DrawString(2, docOriginY+ENTIER(i*zoomFactor)+(j+1)*(font.GetHeight()-4)+1, sc);
					END;
				END;
				FOR i := 0 TO ENTIER (2*bounds.GetHeight()/zoomFactor)-1 DO
					IF i MOD 5 = 0 THEN
						canvas.Line(RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-6, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-3, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					END;
				END;
			ELSE
				(* horizontal ruler *)
				FOR i := 0 TO ENTIER (2*bounds.GetWidth()/zoomFactor)-1 BY 50 DO
					canvas.Line(docOriginX+ENTIER(i*zoomFactor), 1, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					Strings.IntToStr(i, s);
					canvas.DrawString(docOriginX+ENTIER(i*zoomFactor)+2, font.GetHeight()-3 , s);
				END;
				FOR i := 0 TO ENTIER (2*bounds.GetWidth()/zoomFactor)-1 BY 2 DO
					IF i MOD 10 = 0 THEN
						canvas.Line(docOriginX+ENTIER(i*zoomFactor), RULERSIZE-6, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(docOriginX+ENTIER(i*zoomFactor), RULERSIZE-3, docOriginX+ENTIER(i*zoomFactor), RULERSIZE-1, 0000000FFH, WMGraphics.ModeSrcOverDst);
					END;
				END;
				(* vertical ruler *)
				FOR i := 0 TO ENTIER (2*bounds.GetHeight()/zoomFactor)-1 BY 50 DO
					canvas.Line(1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					s := "       ";							(* remove old contents *)
					Strings.IntToStr(i, s);
					FOR j := 0 TO LEN(s)-1 DO
						sc[0] := s[j];
						canvas.DrawString(2, docOriginY+ENTIER(i*zoomFactor)+(j+1)*(font.GetHeight()-4)+1, sc);
					END;
				END;
				FOR i := 0 TO ENTIER (2*bounds.GetHeight()/zoomFactor)-1 BY 2 DO
					IF i MOD 5 = 0 THEN
						canvas.Line(RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-6, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(RULERSIZE-1, docOriginY+ENTIER(i*zoomFactor), RULERSIZE-3, docOriginY+ENTIER(i*zoomFactor), 0000000FFH, WMGraphics.ModeSrcOverDst);
					END;
				END;
			END;
			canvas.Fill(WMRectangles.MakeRect(0,0,RULERSIZE, RULERSIZE), LONGINT(0888888FFH), WMGraphics.ModeCopy);


		END DrawRuler;

		PROCEDURE DrawDocument*(canvas : WMGraphics.Canvas);
		BEGIN
			(* shadow *)
			canvas.Fill(WMRectangles.MakeRect(docOriginX+5, docOriginY+5, ENTIER(document.GetPageWidth()*zoomFactor)+docOriginX+5, ENTIER(document.GetPageHeight()*zoomFactor)+docOriginY+5), 0444444FFH, WMGraphics.ModeCopy);
			canvas.Fill(WMRectangles.MakeRect(docOriginX, docOriginY, ENTIER(document.GetPageWidth()*zoomFactor)+docOriginX, ENTIER(document.GetPageHeight()*zoomFactor)+docOriginY), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);

			(* draw Grid in Background *)
			IF mpageMode THEN DrawGrid(canvas); END;

		END DrawDocument;

		PROCEDURE DrawGrid(canvas: WMGraphics.Canvas);
		VAR
			w, h, mt, mb, ml, mr, subGridCounter : LONGINT;
			gridSubSize, i : REAL;
		BEGIN
			(* calc pixels *)
			w := ENTIER(document.GetPageWidth()*zoomFactor);
			h := ENTIER(document.GetPageHeight()*zoomFactor);
			mt := ENTIER(document.GetMarginTop()*zoomFactor);
			mb := ENTIER(document.GetMarginBottom()*zoomFactor);
			ml := ENTIER(document.GetMarginLeft()*zoomFactor);
			mr := ENTIER(document.GetMarginRight()*zoomFactor);

			IF ~previewMode THEN
				(* grid *)
				IF showGrid THEN
					gridSubSize := gridDistance/gridDivision;
					(* subGrid horizontal *)
					i := 0; subGridCounter := 0;
					WHILE i < document.GetPageHeight() DO
						IF subGridCounter MOD gridDivision = 0 THEN			(* GridLine *)
							canvas.Line(docOriginX, docOriginY+ENTIER(i*zoomFactor), docOriginX+w-1, docOriginY+ENTIER(i*zoomFactor), GRIDCOLOR, WMGraphics.ModeSrcOverDst);
						ELSE													(* SubGridLine *)
							canvas.Line(docOriginX, docOriginY+ENTIER(i*zoomFactor), docOriginX+w-1, docOriginY+ENTIER(i*zoomFactor), SUBGRIDCOLOR, WMGraphics.ModeSrcOverDst);
						END;
						INC(subGridCounter); i := subGridCounter * gridSubSize;
					END;
					(* subGrid vertical *)
					i := 0; subGridCounter := 0;
					WHILE i < document.GetPageWidth() DO
						IF subGridCounter MOD gridDivision = 0 THEN			(* GridLine *)
							canvas.Line(docOriginX+ENTIER(i*zoomFactor), docOriginY, docOriginX+ENTIER(i*zoomFactor), docOriginY+h-1, GRIDCOLOR, WMGraphics.ModeSrcOverDst);
						ELSE													(* SubGridLine *)
							canvas.Line(docOriginX+ENTIER(i*zoomFactor), docOriginY, docOriginX+ENTIER(i*zoomFactor), docOriginY+h-1, SUBGRIDCOLOR, WMGraphics.ModeSrcOverDst);
						END;
						INC(subGridCounter); i := subGridCounter * gridSubSize;
					END;
				END;
			END;

		END DrawGrid;

		PROCEDURE DrawHelpers(canvas : WMGraphics.Canvas);
		VAR
			w, h, mt, mb, ml, mr, tempml, tempmr, pageNumber : LONGINT;
(*			cpage: DTPData.PageObject;
			cguide: DTPData.GuideObject;
*)			guidePos: REAL; guideOrientation: BOOLEAN;
		BEGIN
			(* calc pixels *)
			w := ENTIER(document.GetPageWidth()*zoomFactor);
			h := ENTIER(document.GetPageHeight()*zoomFactor);
			mt := ENTIER(document.GetMarginTop()*zoomFactor);
			mb := ENTIER(document.GetMarginBottom()*zoomFactor);
			ml := ENTIER(document.GetMarginLeft()*zoomFactor);
			mr := ENTIER(document.GetMarginRight()*zoomFactor);

			IF ~previewMode THEN
				IF mpageMode THEN							(* draw current Master Guides *)
					cpage := document.GetCurrentMasterPage();
					cguide := cpage.GetFirstGuide();
					WHILE cguide # NIL DO
						guidePos := cguide.GetPosition(); guideOrientation:= cguide.GetHorizontal();
						IF guideOrientation THEN
							canvas.Line(docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, w+docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
						ELSE
							canvas.Line(ENTIER(guidePos*zoomFactor)+docOriginX, docOriginY, ENTIER(guidePos*zoomFactor)+docOriginX, h+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
						END;
						cguide := cguide.next;
					END;
				ELSE											(* draw document guides & appropriate Master Guides *)
					(* master guides *)
					cpage := document.GetCurrentPage(); cpage := cpage.GetMasterPage();
					IF cpage # NIL THEN
						cguide := cpage.GetFirstGuide();
						WHILE cguide # NIL DO
							guidePos := cguide.GetPosition(); guideOrientation:= cguide.GetHorizontal();
							IF guideOrientation THEN
								canvas.Line(docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, w+docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
							ELSE
								canvas.Line(ENTIER(guidePos*zoomFactor)+docOriginX, docOriginY, ENTIER(guidePos*zoomFactor)+docOriginX, h+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
							END;
							cguide := cguide.next;
						END;
					END;

					(* document guides *)
					cpage := document.GetCurrentPage();
					cguide := cpage.GetFirstGuide();
					WHILE cguide # NIL DO
						guidePos := cguide.GetPosition(); guideOrientation:= cguide.GetHorizontal();
						IF guideOrientation THEN
							canvas.Line(docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, w+docOriginX, ENTIER(guidePos*zoomFactor)+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
						ELSE
							canvas.Line(ENTIER(guidePos*zoomFactor)+docOriginX, docOriginY, ENTIER(guidePos*zoomFactor)+docOriginX, h+docOriginY, GUIDECOLOR, WMGraphics.ModeSrcOverDst);
						END;
						cguide := cguide.next;
					END;
				END;

				(* margin *)
				IF document.GetFacingPages() THEN
					IF mpageMode THEN pageNumber := document.GetCurrentMasterPageNumber(); ELSE pageNumber := document.GetCurrentPageNumber(); END;
					IF  (pageNumber MOD 2 = 0) THEN
						tempml := mr;
						tempmr := ml;
					ELSE
						tempml := ml;
						tempmr := mr;
					END;
				ELSE
					tempml := ml;
					tempmr := mr;
				END;
				canvas.Line(docOriginX+tempml, docOriginY+mt, docOriginX+w-tempmr, docOriginY+mt, BORDERCOLOR, WMGraphics.ModeSrcOverDst);
				canvas.Line(docOriginX+tempml, docOriginY+h-mb, docOriginX+w-tempmr, docOriginY+h-mb, BORDERCOLOR, WMGraphics.ModeSrcOverDst);
				canvas.Line(docOriginX+tempml, docOriginY+mt, docOriginX+tempml, docOriginY+h-mb, BORDERCOLOR, WMGraphics.ModeSrcOverDst);
				canvas.Line(docOriginX+w-tempmr, docOriginY+mt, docOriginX+w-tempmr, docOriginY+h-mb, BORDERCOLOR, WMGraphics.ModeSrcOverDst);
			END;

		END DrawHelpers;

		PROCEDURE DrawContent*(canvas : WMGraphics.Canvas);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)			content: DTPData.ContentObject;
			x, y, w, h: REAL;
			color: LONGINT;
		BEGIN
			(* Draw current Page with (content)Frames, selected Frame *)
			color := FRAMECOLOR;

			IF mpageMode THEN										(* master page *)
				cpage := document.GetCurrentMasterPage();
				cframe := cpage.GetFirstFrame();
				WHILE cframe # NIL DO									(* draw frames & their content *)
					x := cframe.GetX(); y := cframe.GetY();
					w := cframe.GetWidth(); h := cframe.GetHeight();

					(* draw content *)
					content := cframe.GetContent();
					IF content # NIL THEN
						content.Draw(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), ENTIER(w*zoomFactor), ENTIER(h*zoomFactor), zoomFactor, quality, previewMode);
					END;

					(* draw bounding box *)
					IF ~previewMode THEN
						DrawRectangle(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), docOriginX+ENTIER((x+w)*zoomFactor), docOriginY+ENTIER((y+h)*zoomFactor), color);
					END;

					cframe := cframe.next;
				END;

			ELSE														(* draw current page & app. master *)
				(* master page *)
				cpage := document.GetCurrentPage(); cpage := cpage.GetMasterPage();
				IF cpage # NIL THEN										(* if there is a masterpage.. *)
					cframe := cpage.GetFirstFrame();
					WHILE cframe # NIL DO								(* draw frames & their content *)
						x := cframe.GetX(); y := cframe.GetY();
						w := cframe.GetWidth(); h := cframe.GetHeight();

						(* draw content *)
						content := cframe.GetContent();
						IF content # NIL THEN
							content.Draw(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), ENTIER(w*zoomFactor), ENTIER(h*zoomFactor), zoomFactor, quality, previewMode);
						END;

						(* draw bounding box *)
						IF ~previewMode THEN
							DrawRectangle(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), docOriginX+ENTIER((x+w)*zoomFactor), docOriginY+ENTIER((y+h)*zoomFactor), MASTERFRAMECOLOR);
						END;

						cframe := cframe.next;
					END;
				END;

				(* maybe call DrawGrid after MasterPage Again... *)
				IF ~mpageMode THEN DrawGrid(canvas); END;

				(* document page *)
				cpage := document.GetCurrentPage();
				cframe := cpage.GetFirstFrame();
				WHILE cframe # NIL DO									(* draw frames & their content *)
					x := cframe.GetX(); y := cframe.GetY();
					w := cframe.GetWidth(); h := cframe.GetHeight();

					(* draw content *)
					content := cframe.GetContent();
					IF content # NIL THEN
						content.Draw(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), ENTIER(w*zoomFactor), ENTIER(h*zoomFactor), zoomFactor, quality, previewMode);
					END;

					(* draw bounding box *)
					IF ~previewMode THEN
						DrawRectangle(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), docOriginX+ENTIER((x+w)*zoomFactor), docOriginY+ENTIER((y+h)*zoomFactor), color);
					END;

					cframe := cframe.next;
				END;
			END;

		END DrawContent;

		PROCEDURE DrawSelectedFrame(canvas : WMGraphics.Canvas);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)			x, y, w, h, pos: REAL;
			color: LONGINT;
			horizontal: BOOLEAN;
		BEGIN

			IF mpageMode THEN
				cpage := document.GetCurrentMasterPage();
			ELSE
				cpage := document.GetCurrentPage();
			END;

			(* draw current frame (border) *)
			color := ACTIVEFRAMECOLOR;
			cframe := cpage.GetCurrentFrame();
			cguide := cpage.GetCurrentGuide();
			IF cguide # NIL THEN
				pos := cguide.GetPosition();
				horizontal := cguide.GetHorizontal();
				IF ~previewMode THEN
					IF horizontal THEN
						canvas.Line(docOriginX, docOriginY+ENTIER(pos*zoomFactor), docOriginX+ENTIER(document.GetPageWidth()*zoomFactor), docOriginY+ENTIER(pos*zoomFactor), color, WMGraphics.ModeSrcOverDst);
					ELSE
						canvas.Line(docOriginX+ENTIER(pos*zoomFactor), docOriginY, docOriginX+ENTIER(pos*zoomFactor), docOriginY+ENTIER(document.GetPageHeight()*zoomFactor), color, WMGraphics.ModeSrcOverDst);
					END;
				END;
			ELSIF cframe # NIL THEN
				x := cframe.GetX(); y := cframe.GetY();
				w := cframe.GetWidth(); h := cframe.GetHeight();
				IF ~previewMode THEN
					DrawRectangle(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), docOriginX+ENTIER((x+w)*zoomFactor), docOriginY+ENTIER((y+h)*zoomFactor), color);
					IF selectionON THEN
						DrawFrameHandles(canvas, docOriginX+ENTIER(x*zoomFactor), docOriginY+ENTIER(y*zoomFactor), docOriginX+ENTIER((x+w)*zoomFactor), docOriginY+ENTIER((y+h)*zoomFactor), color);
					END
				END
			ELSE
			END;

		END DrawSelectedFrame;

		PROCEDURE DrawRectangle(canvas: WMGraphics.Canvas; xs, ys, xe, ye, color: LONGINT);
		BEGIN
				canvas.Line(xs,ys,xs,ye, color, WMGraphics.ModeSrcOverDst);
				canvas.Line(xs,ys,xe,ys, color, WMGraphics.ModeSrcOverDst);
				canvas.Line(xe,ys,xe,ye, color, WMGraphics.ModeSrcOverDst);
				canvas.Line(xs,ye,xe,ye, color, WMGraphics.ModeSrcOverDst);
		END DrawRectangle;

		PROCEDURE DrawFrameHandles(canvas: WMGraphics.Canvas; xs, ys, xe, ye, color: LONGINT);
		BEGIN
				canvas.Fill(WMRectangles.MakeRect(xs-4, ys-4, xs+1, ys+1), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(xe, ys-4, xe+5, ys+1), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(xs-4, ye, xs+1, ye+5), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(xe, ye, xe+5, ye+5), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(xs-4, ENTIER((ys+ye)/2)-2, xs+1, ENTIER((ys+ye)/2)+2), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ys-4, ENTIER((xs+xe)/2)+3, ys+1), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(xe, ENTIER((ys+ye)/2)-2, xe+5, ENTIER((ys+ye)/2)+2), color, WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ye, ENTIER((xs+xe)/2)+3, ye+5), color, WMGraphics.ModeSrcOverDst);
		END DrawFrameHandles;

		PROCEDURE DrawUserAction(canvas: WMGraphics.Canvas);
		VAR color: LONGINT;
			rx, ry: REAL;
			snapL, snapT, snapR, snapB: BOOLEAN;
		BEGIN
			color := FRAMECOLOR;
			IF ~previewMode THEN											(* Document Edit Mode *)
				IF ~selectionON THEN										(* plugin tools *)
					IF addobject THEN
						IF down THEN
							IF snapOnCreate THEN
								IF tx0 >-1 THEN vx0 := ENTIER(tx0*zoomFactor)+docOriginX; ELSE vx0 := x0; END;
								IF ty0 >-1 THEN vy0 := ENTIER(ty0*zoomFactor)+docOriginY; ELSE vy0 := y0; END;
							ELSE
								vx0 := x0; vy0 := y0;
							END;
							IF WillSnap((x1-docOriginX)/zoomFactor, (y1-docOriginY)/zoomFactor, (x1-docOriginX)/zoomFactor, (y1-docOriginY)/zoomFactor, snapL, snapT, snapR, snapB, rx, ry) THEN

								IF snapR OR snapL THEN vx1 := ENTIER(rx*zoomFactor)+docOriginX; ELSE vx1 := x1; END;
								IF snapT OR snapB THEN vy1 := ENTIER(ry*zoomFactor)+docOriginY; ELSE vy1 := y1; END;
							ELSE
								vx1 := x1; vy1 := y1;
							END;

							(* create object *)
							canvas.Line(vx0,vy0,vx0,vy1, color, WMGraphics.ModeSrcOverDst);
							canvas.Line(vx0,vy0,vx1,vy0, color, WMGraphics.ModeSrcOverDst);
							canvas.Line(vx1,vy0,vx1,vy1, color, WMGraphics.ModeSrcOverDst);
							canvas.Line(vx0,vy1,vx1,vy1, color, WMGraphics.ModeSrcOverDst);
						END;
					END;
				ELSE														(* selection tool *)
					IF down THEN
						IF addguide THEN									(* add guide *)
							IF res2 = 0 THEN
								canvas.Line(docOriginX, y1,  ENTIER(document.GetPageWidth()*zoomFactor)+docOriginX, y1, color, WMGraphics.ModeSrcOverDst);
							ELSE
								canvas.Line(x1, docOriginY, x1, ENTIER(document.GetPageHeight()*zoomFactor)+docOriginY, color, WMGraphics.ModeSrcOverDst);
							END;
						END;
					END;
				END;
			ELSE														(* Preview Mode *)

			END;

		END DrawUserAction;

		PROCEDURE InvalidateCurrentFrame*;
		BEGIN
			Invalidate;
		END InvalidateCurrentFrame;

		PROCEDURE SetContentPropsPosition*(x, y: LONGINT);
		BEGIN
			propsX := x; propsY := y;
		END SetContentPropsPosition;

		PROCEDURE UpdateContentProps*;
		VAR activeContent, content : DTPData.ContentObject;

		BEGIN
			IF activeFrame # NIL THEN
				activeContent := activeFrame.GetContent();
				activeContent.Hide;
			END;
			IF mpageMode THEN
				cpage := document.GetCurrentMasterPage();
			ELSE
				cpage := document.GetCurrentPage();
			END;
			cframe := cpage.GetCurrentFrame();
			IF cframe # NIL THEN
				content := cframe.GetContent();
				content.Show(propsX, propsY); activeFrame := cframe;
			END;
			ownerWindowSetFocus;
		END UpdateContentProps;

		PROCEDURE UpdateProps*;
		VAR
			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
		BEGIN
			(* props := parentWindow.props; *)
			IF props # NIL THEN
				(* document := parentWindow.GetDocument(); *)
				IF document # NIL THEN
					IF mpageMode THEN
						cpage := document.GetCurrentMasterPage();
					ELSE
						cpage := document.GetCurrentPage();
					END;
					cframe := cpage.GetCurrentFrame();
					cguide := cpage.GetCurrentGuide();
					IF selectionON THEN									(* selection tool *)
						IF (cframe = NIL) & (cguide = NIL) THEN				(* no frame/guide selected *)
							IF addguide THEN
								props.SetActive;
								IF res2 = 0 THEN
									props.SetCoordinates(0, (y1-docOriginY)/zoomFactor, 0,0);
								ELSE
									props.SetCoordinates((x1-docOriginX)/zoomFactor, 0, 0, 0);
								END;
							ELSE
								props.SetInactive;
								props.InitValues;
							END;
						ELSIF (cframe # NIL) THEN							(* frame selected *)
							props.SetActiveALL;
							IF quality THEN
								props.SetProperties(cframe.GetX(), cframe.GetY(), cframe.GetWidth(), cframe.GetHeight(), cframe.GetName(), cframe.GetStyle(), cframe.GetWrap(), cframe.GetWrapTop(), cframe.GetWrapBottom(), cframe.GetWrapLeft(), cframe.GetWrapRight());
							ELSE
								props.SetCoordinates(cframe.GetX(), cframe.GetY(), cframe.GetWidth(), cframe.GetHeight());
							END;
						ELSIF (cguide # NIL) THEN
							props.SetActive;
							IF cguide.GetHorizontal() THEN
								props.SetCoordinates(0, cguide.GetPosition(), 0, 0);
							ELSE
								props.SetCoordinates(cguide.GetPosition(), 0, 0, 0);
							END;
						ELSE
						END;
					ELSE													(* plugins *)
						IF down THEN
							props.SetActive;
							props.SetCoordinates((x0-docOriginX)/zoomFactor, (y0-docOriginY)/zoomFactor, (x1-x0)/zoomFactor, (y1-y0)/zoomFactor);
						ELSE												(* display current frame *)
							cpage := document.GetCurrentPage();
							cframe := cpage.GetCurrentFrame();
							IF (cframe # NIL) THEN							(* frame selected *)
								props.SetActiveALL;
								props.SetProperties(cframe.GetX(), cframe.GetY(), cframe.GetWidth(), cframe.GetHeight(), cframe.GetName(), cframe.GetStyle(), cframe.GetWrap(), cframe.GetWrapTop(), cframe.GetWrapBottom(), cframe.GetWrapLeft(), cframe.GetWrapRight());
							ELSE
								props.SetInactive;
								props.InitValues;
							END;
						END;
					END;
				END;
			END;
		END UpdateProps;

		PROCEDURE UpdateCoordinates*;
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)		BEGIN
			(* props := parentWindow.props; *)
			IF props # NIL THEN
				(* document := parentWindow.GetDocument(); *)
				IF document # NIL THEN
					IF mpageMode THEN
						cpage := document.GetCurrentMasterPage();
					ELSE
						cpage := document.GetCurrentPage();
					END;
					cframe := cpage.GetCurrentFrame();
					cguide := cpage.GetCurrentGuide();
					IF (cframe = NIL) & (cguide = NIL) THEN
						props.SetCoordinates((x1-docOriginX)/zoomFactor, (y1-docOriginY)/zoomFactor, 0, 0);
					END;
				END;
			END;
		END UpdateCoordinates;

		PROCEDURE CloseContentProps*;
		VAR activeContent: DTPData.ContentObject;
		BEGIN
			IF activeFrame # NIL THEN
				activeContent := activeFrame.GetContent();
				activeContent.Close;
			END;
		END CloseContentProps;

	END DrawPanel;

	PropertyWindow* = OBJECT(WMComponents.FormWindow);
	VAR frameName : Strings.String;
		frameX,frameY, frameW, frameH : REAL;
		frameStyle : DTPData.StyleObject;
		textwrapON : BOOLEAN;
		twrapTop, twrapBottom, twrapLeft, twrapRight : REAL;
		theCaller : DrawPanel;
		tempLabel* : WMStandardComponents.Label;

		cdoc: DTPData.Document;
		cpage: DTPData.PageObject;
		cframe: DTPData.FrameObject;
		cguide: DTPData.GuideObject;

		shown, active, activeALL : BOOLEAN;
		leftPanel, rightPanel: WMStandardComponents.Panel;
		efx, efy, efw, efh, efn, efs, eftw, efwt, efwb, efwl, efwr: WMEditors.Editor;

		PROCEDURE &New*(caller: DrawPanel);
		VAR vc: WMComponents.VisualComponent;
		BEGIN
			theCaller := caller;
			manager := WMWindowManager.GetDefaultManager();
			vc := CreatePropertyForm();
			InitValues;
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			SetTitle(Strings.NewString("Frame"));
			shown := FALSE; active := TRUE; activeALL := FALSE;
			SetInactive;

		END New;

		PROCEDURE CreatePropertyForm(): WMComponents.VisualComponent;
		VAR panel: WMStandardComponents.Panel;
			label: WMStandardComponents.Label;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;
		BEGIN
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel);
			(* panel.bounds.SetExtents(190, 230); *)
			panel.bounds.SetExtents(190, 130);
			panel.fillColor.Set(panelColor);
			panel.takesFocus.Set(TRUE);
			NEW(leftPanel); leftPanel.bounds.SetWidth(90); leftPanel.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(leftPanel);
			NEW(rightPanel); rightPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(rightPanel);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" X:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(efx); efx.bounds.SetHeight(20); efx.alignment.Set(WMComponents.AlignTop);
			efx.tv.showBorder.Set(TRUE); efx.multiLine.Set(FALSE); efx.fillColor.Set(0FFFFFFFFH);
			efx.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efx.onEnter.Add(SetValueHandler); efx.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			rightPanel.AddContent(efx);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Y:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(efy); efy.bounds.SetHeight(20); efy.alignment.Set(WMComponents.AlignTop);
			efy.tv.showBorder.Set(TRUE); efy.multiLine.Set(FALSE); efy.fillColor.Set(0FFFFFFFFH);
			efy.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efy.onEnter.Add(SetValueHandler); efy.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			rightPanel.AddContent(efy);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Width:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(efw); efw.bounds.SetHeight(20); efw.alignment.Set(WMComponents.AlignTop);
			efw.tv.showBorder.Set(TRUE); efw.multiLine.Set(FALSE); efw.fillColor.Set(0FFFFFFFFH);
			efw.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efw.onEnter.Add(SetValueHandler); efw.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			rightPanel.AddContent(efw);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Height:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(efh); efh.bounds.SetHeight(20); efh.alignment.Set(WMComponents.AlignTop);
			efh.tv.showBorder.Set(TRUE); efh.multiLine.Set(FALSE); efh.fillColor.Set(0FFFFFFFFH);
			efh.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efh.onEnter.Add(SetValueHandler); efh.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			rightPanel.AddContent(efh);

			(* add spacer *)
			NEW(label); label.bounds.SetHeight(10); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption("");
			leftPanel.AddContent(label);
			NEW(label); label.bounds.SetHeight(10); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption("");
			rightPanel.AddContent(label);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Name:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(efn); efn.bounds.SetHeight(20); efn.alignment.Set(WMComponents.AlignTop);
			efn.tv.showBorder.Set(TRUE); efn.multiLine.Set(FALSE); efn.fillColor.Set(0FFFFFFFFH);
			efn.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efn.onEnter.Add(SetValueHandler); efn.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			rightPanel.AddContent(efn);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Style:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(efs); efs.bounds.SetHeight(20); efs.alignment.Set(WMComponents.AlignTop);
			efs.tv.showBorder.Set(TRUE); efs.multiLine.Set(FALSE); efs.fillColor.Set(0FFFFFFFFH);
			efs.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efs.onEnter.Add(SetValueHandler); efs.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(efs); *)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TextWrapON:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(eftw); eftw.bounds.SetHeight(20); eftw.alignment.Set(WMComponents.AlignTop);
			eftw.tv.showBorder.Set(TRUE); eftw.multiLine.Set(FALSE); eftw.fillColor.Set(0FFFFFFFFH);
			eftw.tv.textAlignV.Set(WMGraphics.AlignCenter);
			eftw.onEnter.Add(SetValueHandler); eftw.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(eftw);	*)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TWTop:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(efwt); efwt.bounds.SetHeight(20); efwt.alignment.Set(WMComponents.AlignTop);
			efwt.tv.showBorder.Set(TRUE); efwt.multiLine.Set(FALSE); efwt.fillColor.Set(0FFFFFFFFH);
			efwt.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efwt.onEnter.Add(SetValueHandler); efwt.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(efwt); *)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TWBottom:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(efwb); efwb.bounds.SetHeight(20); efwb.alignment.Set(WMComponents.AlignTop);
			efwb.tv.showBorder.Set(TRUE); efwb.multiLine.Set(FALSE); efwb.fillColor.Set(0FFFFFFFFH);
			efwb.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efwb.onEnter.Add(SetValueHandler); efwb.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(efwb); *)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TWLeft:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(efwl); efwl.bounds.SetHeight(20); efwl.alignment.Set(WMComponents.AlignTop);
			efwl.tv.showBorder.Set(TRUE); efwl.multiLine.Set(FALSE); efwl.fillColor.Set(0FFFFFFFFH);
			efwl.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efwl.onEnter.Add(SetValueHandler); efwl.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(efwl); *)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TWRight:"); label.textColor.Set(0000000FFH);
			(* leftPanel.AddContent(label); *)
			NEW(efwr); efwr.bounds.SetHeight(20); efwr.alignment.Set(WMComponents.AlignTop);
			efwr.tv.showBorder.Set(TRUE); efwr.multiLine.Set(FALSE); efwr.fillColor.Set(0FFFFFFFFH);
			efwr.tv.textAlignV.Set(WMGraphics.AlignCenter);
			efwr.onEnter.Add(SetValueHandler); efwr.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			(* rightPanel.AddContent(efwr); *)

			RETURN panel;
		END CreatePropertyForm;

		PROCEDURE Show*;
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				WMWindowManager.ExtAddWindow(SELF, 820, 90,
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

		PROCEDURE SetActiveALL*;
		BEGIN
			IF ~activeALL THEN
				rightPanel.takesFocus.Set(TRUE); (* make field NONEDITABLE? *)
				efx.fillColor.Set(0FFFFFFFFH); efx.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efy.fillColor.Set(0FFFFFFFFH); efy.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efw.fillColor.Set(0FFFFFFFFH); efw.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efh.fillColor.Set(0FFFFFFFFH); efh.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efn.fillColor.Set(0FFFFFFFFH); efn.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efs.fillColor.Set(0FFFFFFFFH); efs.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				eftw.fillColor.Set(0FFFFFFFFH); eftw.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efwt.fillColor.Set(0FFFFFFFFH); efwt.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efwb.fillColor.Set(0FFFFFFFFH); efwb.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efwl.fillColor.Set(0FFFFFFFFH); efwl.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efwr.fillColor.Set(0FFFFFFFFH); efwr.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				rightPanel.Invalidate;
				activeALL := TRUE;
			END;
		END SetActiveALL;

		PROCEDURE SetActive*;
		BEGIN
			IF ~active THEN
				rightPanel.takesFocus.Set(TRUE); (* make field NONEDITABLE? *)
				efx.fillColor.Set(0FFFFFFFFH); efx.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efy.fillColor.Set(0FFFFFFFFH); efy.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efw.fillColor.Set(0FFFFFFFFH); efw.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				efh.fillColor.Set(0FFFFFFFFH); efh.tv.defaultTextBgColor.Set(0FFFFFFFFH);
(*				efn.fillColor.Set(0BBBBBBFFH); efn.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efs.fillColor.Set(0BBBBBBFFH); efs.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				eftw.fillColor.Set(0BBBBBBFFH); eftw.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwt.fillColor.Set(0BBBBBBFFH); efwt.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwb.fillColor.Set(0BBBBBBFFH); efwb.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwl.fillColor.Set(0BBBBBBFFH); efwl.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwr.fillColor.Set(0BBBBBBFFH); efwr.tv.defaultTextBgColor.Set(0BBBBBBFFH);
*)				rightPanel.Invalidate;
				active := TRUE;
			END;
		END SetActive;

		PROCEDURE SetInactive*;
		BEGIN
			IF active OR activeALL THEN
				rightPanel.takesFocus.Set(FALSE); (* make field EDITABLE? *)
				efx.fillColor.Set(0BBBBBBFFH); efx.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efy.fillColor.Set(0BBBBBBFFH); efy.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efw.fillColor.Set(0BBBBBBFFH); efw.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efh.fillColor.Set(0BBBBBBFFH); efh.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efn.fillColor.Set(0BBBBBBFFH); efn.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efs.fillColor.Set(0BBBBBBFFH); efs.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				eftw.fillColor.Set(0BBBBBBFFH); eftw.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwt.fillColor.Set(0BBBBBBFFH); efwt.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwb.fillColor.Set(0BBBBBBFFH); efwb.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwl.fillColor.Set(0BBBBBBFFH); efwl.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				efwr.fillColor.Set(0BBBBBBFFH); efwr.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				rightPanel.Invalidate;
				active := FALSE; activeALL := FALSE;
			END;
		END SetInactive;

		PROCEDURE SetProperties*(x, y, w, h: REAL; name: Strings.String; style: DTPData.StyleObject; tw: BOOLEAN; twt, twb, twl, twr: REAL);
		VAR propString: ARRAY 32 OF CHAR;
		BEGIN
			frameX := x; frameY := y; frameW := w; frameH := h;
			frameName := name;
			frameStyle := style;
			textwrapON := tw;
			twrapTop := twt; twrapBottom := twb; twrapLeft := twl; twrapRight := twr;

			Strings.FloatToStr(frameX, 0, 4, 0, propString);
			efx.SetAsString(propString);
			Strings.FloatToStr(frameY, 0, 4, 0, propString);
			efy.SetAsString(propString);
			Strings.FloatToStr(frameW, 0, 4, 0, propString);
			efw.SetAsString(propString);
			Strings.FloatToStr(frameH, 0, 4, 0, propString);
			efh.SetAsString(propString);

			COPY(frameName^, propString);
			efn.SetAsString(propString);

			(* style.. *)

			Strings.BoolToStr(textwrapON, propString);
			eftw.SetAsString(propString);
			Strings.FloatToStr(twrapTop, 0, 4, 0, propString);
			efwt.SetAsString(propString);
			Strings.FloatToStr(twrapBottom, 0, 4, 0, propString);
			efwb.SetAsString(propString);
			Strings.FloatToStr(twrapLeft, 0, 4, 0, propString);
			efwl.SetAsString(propString);
			Strings.FloatToStr(twrapRight, 0, 4, 0, propString);
			efwr.SetAsString(propString);

		END SetProperties;

		PROCEDURE SetCoordinates*(x, y, w, h: REAL);
		VAR propString: ARRAY 32 OF CHAR;
		BEGIN
			frameX := x; frameY := y; frameW := w; frameH := h;

			Strings.FloatToStr(frameX, 0, 4, 0, propString);
			efx.SetAsString(propString);
			Strings.FloatToStr(frameY, 0, 4, 0, propString);
			efy.SetAsString(propString);
			Strings.FloatToStr(frameW, 0, 4, 0, propString);
			efw.SetAsString(propString);
			Strings.FloatToStr(frameH, 0, 4, 0, propString);
			efh.SetAsString(propString);

		END SetCoordinates;

		PROCEDURE InitValues*;
		VAR propString: ARRAY 32 OF CHAR;
		BEGIN
			propString := "";
			efx.SetAsString(propString);
			efy.SetAsString(propString);
			efw.SetAsString(propString);
			efh.SetAsString(propString);
			efn.SetAsString(propString);
			efs.SetAsString(propString);
			eftw.SetAsString(propString);
			efwt.SetAsString(propString);
			efwb.SetAsString(propString);
			efwl.SetAsString(propString);
			efwr.SetAsString(propString);

		END InitValues;

		PROCEDURE SetValueHandler(sender, data: ANY);
		VAR
			plreal, plreal2, plreal3, plreal4 : LONGREAL;
			pstring, pstring2, pstring3, pstring4 : ARRAY 128 OF CHAR;
			pbool : BOOLEAN;
			content : DTPData.ContentObject;
		BEGIN
			cdoc := theCaller.GetDocument();
			IF theCaller.mpageMode THEN
				cpage := cdoc.GetCurrentMasterPage();
			ELSE
				cpage := cdoc.GetCurrentPage();
			END;
			cframe := cpage.GetCurrentFrame();
			cguide := cpage.GetCurrentGuide();
			IF cframe # NIL THEN									(* update frame values *)
				IF (sender = efx) THEN
					efx.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					efy.GetAsString(pstring2); Strings.StrToFloat(pstring2, plreal2);
					cframe.SetPosition(SHORT(plreal), SHORT(plreal2));
				ELSIF (sender = efy) THEN
					efx.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					efy.GetAsString(pstring2); Strings.StrToFloat(pstring2, plreal2);
					cframe.SetPosition(SHORT(plreal), SHORT(plreal2));
				ELSIF (sender = efw) THEN
					efw.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					efh.GetAsString(pstring2); Strings.StrToFloat(pstring2, plreal2);
					cframe.SetSize(SHORT(plreal), SHORT(plreal2));
				ELSIF (sender = efh) THEN
					efw.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					efh.GetAsString(pstring2); Strings.StrToFloat(pstring2, plreal2);
					cframe.SetSize(SHORT(plreal), SHORT(plreal2));
				ELSIF (sender = efn) THEN
					efn.GetAsString(pstring);
					content := cdoc.GetContentByName(pstring);
					IF (content = NIL) THEN
						cframe.SetName(Strings.NewString(pstring));
						content := cframe.GetContent();
						IF content # NIL THEN content.contentName := Strings.NewString(pstring); END;
					ELSE
						cframe.SetName(Strings.NewString("already exists"));
						content := cframe.GetContent();
						IF content # NIL THEN content.contentName := Strings.NewString(pstring); END;
						efn.SetAsString("already exists");
					END;

				ELSIF (sender = efs) THEN

				ELSIF (sender = eftw) THEN
					eftw.GetAsString(pstring); Strings.StrToBool(pstring, pbool);
					cframe.SetWrap(pbool);
				ELSIF (sender = efwt) OR (sender = efwb) OR (sender = efwl) OR (sender = efwr) THEN
					efwt.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					efwb.GetAsString(pstring2); Strings.StrToFloat(pstring2, plreal2);
					efwl.GetAsString(pstring3); Strings.StrToFloat(pstring3, plreal3);
					efwr.GetAsString(pstring4); Strings.StrToFloat(pstring4, plreal4);
					cframe.SetWrapSize(SHORT(plreal), SHORT(plreal2), SHORT(plreal3), SHORT(plreal4));
				ELSE

				END;
			ELSIF cguide # NIL THEN									(* update guide values *)
				IF cguide.GetHorizontal() THEN
					efy.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					cguide.SetPosition(SHORT(plreal));
				ELSE
					efx.GetAsString(pstring); Strings.StrToFloat(pstring, plreal);
					cguide.SetPosition(SHORT(plreal));
				END;
			ELSE
			END;
			theCaller.Invalidate;
		END SetValueHandler;

		PROCEDURE Close;
		BEGIN
			theCaller.propertyOpen := FALSE;
			Hide;
			Close^;
		END Close;

	END PropertyWindow;

(* New  Object Dialog Window *)
(*	NewObjectDialog* = OBJECT(WMComponents.FormWindow)
	VAR content: WMComponents.VisualComponent;
		result: LONGINT;
		objectWidthField, objectHeightField: WMEditors.Editor;
		shown: BOOLEAN;
		theCaller: DrawPanel;

		PROCEDURE &New(caller: DrawPanel);
		BEGIN
			theCaller := caller;
			content := CreateDialog();
			Init(content.bounds.GetWidth(), content.bounds.GetHeight(), FALSE);
			SetContent(content);
			SetTitle(Strings.NewString("New Object"));
			manager := WMWindowManager.GetDefaultManager();

		END New;

		PROCEDURE Show*(VAR w, h: REAL): BOOLEAN;
		VAR resultString: ARRAY 8 OF CHAR;
			resW, resH: LONGREAL;
		BEGIN
				result := -1;
				WMWindowManager.ExtAddWindow(SELF, 200, 100, {WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop});
				manager.SetFocus(SELF);
				BEGIN {EXCLUSIVE}
					AWAIT (result >= 0)
				END;
				manager.Remove(SELF);
				IF result = 0 THEN
					objectWidthField.GetAsString(resultString);
					Strings.StrToFloat(resultString, resW); w := SHORT(resW);
					objectHeightField.GetAsString(resultString);
					Strings.StrToFloat(resultString, resH); h := SHORT(resH);
					RETURN TRUE;
				ELSE h := 0; w := 0;
					RETURN FALSE;
				END;


		END Show;

		PROCEDURE CreateDialog(): WMStandardComponents.Panel;
		VAR label: WMStandardComponents.Label;
			panel, buttonPanel, paramPanel, editorsPanel, labelPanel : WMStandardComponents.Panel;
			cancel, ok : WMStandardComponents.Button;
		BEGIN

			NEW(panel); panel.bounds.SetExtents(300, 200); panel.fillColor.Set(09999FFFFH);
			panel.takesFocus.Set(TRUE);

			NEW(buttonPanel); buttonPanel.bounds.SetHeight(40); buttonPanel.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(buttonPanel);

			NEW(ok); ok.caption.SetAOC("OK"); ok.alignment.Set(WMComponents.AlignRight);
			buttonPanel.AddContent(ok); ok.onClick.Add(Ok);

			NEW(cancel); cancel.caption.SetAOC("Cancel"); cancel.alignment.Set(WMComponents.AlignRight);
			buttonPanel.AddContent(cancel); cancel.onClick.Add(Cancel);

			NEW(paramPanel); paramPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(paramPanel);

			NEW(editorsPanel); editorsPanel.bounds.SetWidth(100); editorsPanel.alignment.Set(WMComponents.AlignRight);
			paramPanel.AddContent(editorsPanel);

			NEW(labelPanel); labelPanel.alignment.Set(WMComponents.AlignClient);
			paramPanel.AddContent(labelPanel);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop); label.SetCaption(" Object Width [mm]:");
			labelPanel.AddContent(label);

			NEW(objectWidthField); objectWidthField.bounds.SetHeight(20); objectWidthField.alignment.Set(WMComponents.AlignTop);
			objectWidthField.tv.showBorder.Set(TRUE); objectWidthField.multiLine.Set(FALSE); objectWidthField.fillColor.Set(0FFFFFFFFH);
			objectWidthField.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(objectWidthField);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop); label.SetCaption(" Object Height [mm]:");
			labelPanel.AddContent(label);

			NEW(objectHeightField); objectHeightField.bounds.SetHeight(20); objectHeightField.alignment.Set(WMComponents.AlignTop);
			objectHeightField.tv.showBorder.Set(TRUE); objectHeightField.multiLine.Set(FALSE); objectHeightField.fillColor.Set(0FFFFFFFFH);
			objectHeghtField.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(objectHeightField);

			RETURN panel;
		END CreateDialog;

		PROCEDURE Ok(sender, data : ANY);
		BEGIN {EXCLUSIVE}
			result := 0;
			theCaller.newObjOpen := FALSE;
		END Ok;

		PROCEDURE Cancel*(sender, data : ANY);
		BEGIN {EXCLUSIVE}
			result := 1;
			theCaller.newObjOpen := FALSE;
		END Cancel;

	BEGIN

	END NewObjectDialog;
*)

END DTPView.