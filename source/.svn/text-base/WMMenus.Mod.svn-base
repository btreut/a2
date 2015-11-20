MODULE WMMenus;	(** AUTHOR "TF/staubesv"; PURPOSE "Menu support"; *)
(*

	Vertical menu entry layout:

	| HMenuDistance | image.width OR MinImageWidth | HMenuDistance | TextImageDistance | TextWidth | HMenuDistance |

*)
IMPORT
	Inputs, Strings, Raster, WMRectangles, WMGraphics, WMGraphicUtilities, WMComponents,
	WMWindowManager, WMProperties, WMEvents, WMDropTarget, WMTrees;

CONST
	OpenDefault* = OpenDownRight;
	OpenUpLeft* = 1;
	OpenUpRight* = 2;
	OpenDownLeft* = 3;
	OpenDownRight* = 4;

	(* ShadowWindow.type *)
	Right = 0;
	Bottom = 1;

	ShadowWidth = 5;
	ShadowHeight = 5;
	ShadowOffsetVertical = 5;
	ShadowOffsetHorizontal = 5;

	LightGrey = LONGINT(0C0C0C0FFH);
	LightGreyDrag = LONGINT(0C0C0C0C0H);
	WhiteDrag = LONGINT(0FFFFFFC0H);

	TextImageDistance = 4;
	MinImageWidth = 4;

	HMenuDistance = 8;
	VMenuDistance = 4;

	SeparatorCaption = "---";
	SeparatorWidth = 9;
	SeparatorHeight = 5;

	DragDist = 10;

TYPE

	Separator* = OBJECT(WMTrees.TreeNode)
	END Separator;

TYPE

	DragWrapper* = OBJECT
	END DragWrapper;

TYPE

	MenuPanel*= OBJECT(WMComponents.VisualComponent)
	VAR
		horizontal- : WMProperties.BooleanProperty;
		horizontalI : BOOLEAN;

		openDirection- : WMProperties.Int32Property;
		openDirectionI : LONGINT;

		clSelected : WMProperties.ColorProperty;

		onSelect- : WMEvents.EventSource;

		menu : WMTrees.Tree;
		root, selection, hover : WMTrees.TreeNode;

		subMenuIndicatorImg : WMGraphics.Image;

		subMenu, parentWindow : MenuWindow;

		parentMenuPanel, focusPanel, rootMenuPanel : MenuPanel;

		greyBoxWidth : LONGINT;

		dragNode : WMTrees.TreeNode;
		dragObject : ANY;

		(* pointer handling *)
		leftClick, dragPossible : BOOLEAN;
		downX, downY : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrMenuPanel);
			NEW(horizontal, NIL, NIL, NIL); properties.Add(horizontal);
			horizontalI := horizontal.Get();
			NEW(openDirection, NIL, NIL, NIL); properties.Add(openDirection);
			NEW(clSelected, NIL, NIL, NIL); properties.Add(clSelected);
			clSelected.Set(WMGraphics.Blue);
			NEW(onSelect, SELF, NIL, NIL, NIL);
			openDirectionI := OpenDefault;
			openDirection.Set(openDirectionI);
			menu := NIL;
			root := NIL; selection := NIL; hover := NIL;
			subMenuIndicatorImg := NIL;
			subMenu := NIL; parentWindow := NIL;
			greyBoxWidth := 2 * HMenuDistance + MinImageWidth;
			dragObject := NIL;
			parentMenuPanel := NIL; focusPanel := SELF; rootMenuPanel := SELF;
			takesFocus.Set(TRUE);
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = clSelected) THEN
				Invalidate;
			ELSIF (property = horizontal) THEN
				horizontalI := horizontal.Get();
				Invalidate;
			ELSIF (property = openDirection) THEN
				openDirectionI := openDirection.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			horizontalI := horizontal.Get();
			openDirectionI := openDirection.Get();
			Invalidate;
		END RecacheProperties;

		PROCEDURE SetParent(parentMenuPanel : MenuPanel);
		BEGIN
			SELF.parentMenuPanel := parentMenuPanel;
			IF (parentMenuPanel # NIL) THEN
				rootMenuPanel := parentMenuPanel.rootMenuPanel;
			END;
		END SetParent;

		(* If menus are used as popup menus, the initial window most be registered here so it can be closed when an item has been selected *)
		PROCEDURE SetParentWindow(parentWindow : MenuWindow);
		BEGIN
			ASSERT(parentWindow # NIL);
			SELF.parentWindow := parentWindow;
		END SetParentWindow;

		PROCEDURE SetMenu*(menu : WMTrees.Tree; root : WMTrees.TreeNode);
		BEGIN
			ASSERT((menu # NIL) & (root # NIL));
			Acquire;
			SELF.menu := menu; SELF.root := root; hover := NIL;
			greyBoxWidth := Strings.Max(MinImageWidth + 2 * HMenuDistance , MaxImageWidth() + 2 * HMenuDistance);
			Invalidate;
			Release
		END SetMenu;

		PROCEDURE Measure(VAR width, height : LONGINT);
		VAR child : WMTrees.TreeNode;
		BEGIN
			ASSERT((menu # NIL) & (root # NIL));
			width := 0; height := 0;
			IF horizontal.Get() THEN
				menu.Acquire;
				child := menu.GetChildren(root);
				WHILE (child # NIL) DO
					width := width + ItemWidth(child, TRUE);
					child := menu.GetNextSibling(child);
				END;
				menu.Release;
			ELSE
				menu.Acquire;
				child := menu.GetChildren(root);
				WHILE (child # NIL) DO
					height := height + ItemHeight(child);
					width := Strings.Max(width, ItemWidth(child, FALSE));
					child := menu.GetNextSibling(child);
				END;
				menu.Release;
			END;
		END Measure;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			child : WMTrees.TreeNode;
			x, y, dx, dy, t, textY : LONGINT;
			font : WMGraphics.Font;
			caption : Strings.String;
			image : Raster.Image;
		BEGIN
			DrawBackground^(canvas);
			IF (menu = NIL) OR (root = NIL) THEN RETURN; END;
			font := GetFont();
			canvas.SetFont(font);
			canvas.SetColor(WMGraphics.Black);
			IF horizontalI THEN
				x := 0;
				menu.Acquire;
				child := menu.GetChildren(root);
				WHILE (child # NIL) DO
					IF ~(child IS Separator) THEN
						IF (child = hover) THEN
							canvas.Fill(WMRectangles.MakeRect(x, 0, x + ItemWidth(child, horizontalI), bounds.GetHeight()), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy);
						ELSIF (child = selection) THEN
							canvas.Fill(WMRectangles.MakeRect(x, 0, x + ItemWidth(child, horizontalI), bounds.GetHeight()), clSelected.Get(), WMGraphics.ModeCopy);
						END;
						x := x + HMenuDistance;
						image := menu.GetNodeImage(child);
						IF (image # NIL) THEN
							canvas.DrawImage(x, 0, image, WMGraphics.ModeSrcOverDst);
							x := x + image.width + HMenuDistance + TextImageDistance;
						END;

						caption := menu.GetNodeCaption(child);
						IF (caption # NIL) THEN
							font.GetStringSize(caption^, dx, dy); canvas.DrawString(x, dy, caption^);
							x := x + dx;
						END;
						INC(x, HMenuDistance);
					ELSE
						INC(x, HMenuDistance);
						canvas.Line(x + (SeparatorWidth DIV 2) + 1, 2, x + (SeparatorWidth DIV 2) + 1, bounds.GetHeight() - 2, WMGraphics.Black, WMGraphics.ModeCopy);
						x := x + SeparatorWidth + HMenuDistance;
					END;
					child := menu.GetNextSibling(child)
				END;
				menu.Release;
			ELSE
				y := 0;
				menu.Acquire;
				IF (openDirectionI = OpenDownLeft) OR (openDirectionI = OpenUpLeft) THEN
					canvas.Fill(WMRectangles.MakeRect(bounds.GetWidth() - greyBoxWidth, 0, bounds.GetWidth() - greyBoxWidth, bounds.GetHeight()), LightGrey, WMGraphics.ModeCopy);
				ELSE
					canvas.Fill(WMRectangles.MakeRect(0, 0, greyBoxWidth, bounds.GetHeight()), LightGrey, WMGraphics.ModeCopy);
				END;
				child := menu.GetChildren(root);
				WHILE (child # NIL) DO
					x := HMenuDistance;
					IF ~(child IS Separator) THEN
						IF (child = hover) THEN
							canvas.Fill(WMRectangles.MakeRect(0, y, bounds.GetWidth(), y + ItemHeight(child)), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy);
						ELSIF (child = selection) THEN
							canvas.Fill(WMRectangles.MakeRect(0, y, bounds.GetWidth(), y + ItemHeight(child)), clSelected.Get(), WMGraphics.ModeCopy);
						END;
						INC(y, VMenuDistance);
						dy := 0;
						image := menu.GetNodeImage(child);
						IF (image # NIL) THEN
							canvas.DrawImage(x, y, image, WMGraphics.ModeSrcOverDst);
							x := x + image.width + HMenuDistance + TextImageDistance;
							dy := image.height;
						ELSE
							x := x + MinImageWidth + HMenuDistance + TextImageDistance;
						END;

						caption := menu.GetNodeCaption(child);
						IF (caption # NIL) THEN
							font.GetStringSize(caption^, dx, t);
							IF (image # NIL) & (image.height > t) THEN
								textY := y + ((image.height + t - font.GetDescent()) DIV 2);
							ELSE
								textY := y + font.ascent;
								dy := t;
							END;
							canvas.DrawString(x, textY, caption^);
						END;

						IF menu.GetChildren(child) # NIL THEN
							IF subMenuIndicatorImg # NIL THEN
								canvas.DrawImage(bounds.GetWidth() - subMenuIndicatorImg.width, 0, subMenuIndicatorImg, WMGraphics.ModeSrcOverDst)
							ELSE
								canvas.DrawString(bounds.GetWidth() - 10, textY, "...")
							END
						END;
						y := y + dy + VMenuDistance;
					ELSE
						y := y + VMenuDistance;
						canvas.Line(greyBoxWidth + 4, y + (SeparatorHeight DIV 2) + 1, bounds.GetWidth(), y + (SeparatorHeight DIV 2) + 1, LightGrey, WMGraphics.ModeCopy);
						y := y + SeparatorHeight + VMenuDistance;
					END;
					child := menu.GetNextSibling(child)
				END;
				menu.Release;
			END;
		END DrawBackground;

		(* caller must hold tree lock *)
		PROCEDURE ItemWidth(item : WMTrees.TreeNode; isHorizontal : BOOLEAN) : LONGINT;
		VAR
			width, dx, dy : LONGINT;
			font : WMGraphics.Font;
			caption : Strings.String;
			image : Raster.Image;
		BEGIN
			ASSERT(menu.HasLock());
			width := 0;
			IF ~(item IS Separator) THEN

				image := menu.GetNodeImage(item);
				IF (image # NIL) THEN
					width := image.width + HMenuDistance + TextImageDistance;
				ELSIF ~(isHorizontal) THEN
					width := width + MinImageWidth + HMenuDistance + TextImageDistance;
				END;

				caption := menu.GetNodeCaption(item);
				IF (caption # NIL) THEN
					font := GetFont(); font.GetStringSize(caption^, dx, dy);
					width := width + dx;
				END;

			ELSE
				width := SeparatorWidth;
			END;
			width := width + 2*HMenuDistance;
			RETURN width;
		END ItemWidth;

		(* caller must hold tree lock *)
		PROCEDURE ItemHeight(item : WMTrees.TreeNode) : LONGINT;
		VAR
			height, dx, dy : LONGINT;
			font : WMGraphics.Font;
			caption : Strings.String;
			image : Raster.Image;
		BEGIN
			height := 0;
			IF ~(item IS Separator) THEN

				caption := menu.GetNodeCaption(item);
				IF (caption # NIL) THEN
					font := GetFont(); font.GetStringSize(caption^, dx, dy);
					height := dy;
				END;

				image := menu.GetNodeImage(item);
				IF (image # NIL) THEN
					IF (image.height  > height) THEN
						height := image.height;
					END;
				END;
			ELSE
				height := SeparatorHeight;
			END;
			height := height + 2 * VMenuDistance;
			RETURN height
		END ItemHeight;

		PROCEDURE MaxImageWidth() : LONGINT;
		VAR child : WMTrees.TreeNode; image : WMGraphics.Image; maxWidth : LONGINT;
		BEGIN
			maxWidth := 0;
			menu.Acquire;
			child := menu.GetChildren(root);
			WHILE (child # NIL) DO
				image := menu.GetNodeImage(child);
				IF (image # NIL) & (image.width > maxWidth) THEN
					maxWidth := image.width;
				END;
				child := menu.GetNextSibling(child);
			END;
			menu.Release;
			RETURN maxWidth;
		END MaxImageWidth;

		PROCEDURE IsSelectable(node : WMTrees.TreeNode) : BOOLEAN;
		BEGIN
			ASSERT(node # NIL);
			RETURN ~(node IS Separator);
		END IsSelectable;

		PROCEDURE FindHorizontal(x : LONGINT) : WMTrees.TreeNode;
		VAR p : LONGINT; child : WMTrees.TreeNode;
		BEGIN
			p := 0;
			menu.Acquire;
			child := menu.GetChildren(root);
			IF (child # NIL) THEN
				REPEAT
					p := p + ItemWidth(child, horizontalI);
					IF p < x THEN child := menu.GetNextSibling(child); END;
				UNTIL (child = NIL) OR (p >= x);
			END;
			menu.Release;
			RETURN child;
		END FindHorizontal;

		PROCEDURE FindVertical(y : LONGINT) : WMTrees.TreeNode;
		VAR p : LONGINT; child : WMTrees.TreeNode;
		BEGIN
			p := 0;
			menu.Acquire;
			child := menu.GetChildren(root);
			IF (child # NIL) THEN
				REPEAT
					p := p + ItemHeight(child);
					IF p < y THEN child := menu.GetNextSibling(child); END;
				UNTIL (child = NIL) OR (p >= y);
			END;
			menu.Release;
			RETURN child;
		END FindVertical;

		PROCEDURE GetItemRect(i : WMTrees.TreeNode; VAR r : WMRectangles.Rectangle);
		VAR child : WMTrees.TreeNode;
		BEGIN
			r.l := 0; r.t := 0;
			menu.Acquire;
			child := menu.GetChildren(root);
			WHILE (child # NIL) & (child # i) DO
				IF horizontal.Get() THEN
					INC(r.l, ItemWidth(child, horizontalI));
				ELSE
					INC(r.t, ItemHeight(child));
				END;
				child := menu.GetNextSibling(child);
			END;
			IF (child # NIL) THEN r.r := r.l + ItemWidth(child, horizontalI); r.b := r.t + ItemHeight(child) END;
			menu.Release
		END GetItemRect;

		PROCEDURE LeafSelect(item : WMTrees.TreeNode);
		VAR data : ANY;
		BEGIN
			IF parentMenuPanel = NIL THEN
				CloseSubMenu(FALSE);
				menu.Acquire;
				data := menu.GetNodeData(item);
				menu.Release;
				IF (data # NIL) THEN
					onSelect.Call(data);
				ELSE
					onSelect.Call(item);
				END;
				IF (parentWindow # NIL) THEN
					parentWindow.CloseMenu(SELF, NIL); parentWindow := NIL;
				END;
			ELSE
				parentMenuPanel.LeafSelect(item);
			END
		END LeafSelect;

		PROCEDURE SetSelection(node : WMTrees.TreeNode);
		BEGIN
			IF (selection # node) THEN
				selection := node;
				Invalidate;
			END;
		END SetSelection;

		PROCEDURE SelectNode(node : WMTrees.TreeNode; indicateLast : BOOLEAN);
		VAR child : WMTrees.TreeNode; r : WMRectangles.Rectangle; x, y : LONGINT;
		BEGIN
			ASSERT(node # NIL);
			menu.Acquire;
			child := menu.GetChildren(node);
			IF (child # NIL) THEN
				GetItemRect(node, r);
				IF horizontal.Get() THEN
					IF openDirection.Get() IN {OpenUpLeft, OpenUpRight} THEN ToWMCoordinates(r.l, r.t, x, y);
					ELSE ToWMCoordinates(r.l, r.b, x, y);
					END
				ELSE
					CASE openDirection.Get() OF
						|OpenUpLeft : ToWMCoordinates(r.l, r.b, x, y);
						|OpenUpRight : ToWMCoordinates(r.r, r.b, x, y);
						|OpenDownLeft : ToWMCoordinates(r.l, r.t, x, y);
						|OpenDownRight : ToWMCoordinates(r.r, r.t, x, y);
					ELSE
						ToWMCoordinates(r.r, r.t, x, y);
					END;
				END;
				CloseSubMenu(indicateLast);
				SetSelection(node);
				NEW(subMenu, x, y, openDirection.Get(), menu, node, SELF, FALSE, TRUE);
				rootMenuPanel.focusPanel := subMenu.menuPanel;
				PointerLeave;
			ELSE
				LeafSelect(node)
			END;
			menu.Release;
		END SelectNode;

		PROCEDURE CloseSubMenu(indicateLast : BOOLEAN);
		BEGIN
			IF (subMenu # NIL) THEN
				subMenu.CloseMenu(NIL, NIL); subMenu := NIL;
				IF (selection # NIL) THEN
					IF indicateLast THEN hover := selection; END;
					selection := NIL;
					Invalidate;
				END;
				rootMenuPanel.focusPanel := SELF;
			END;
		END CloseSubMenu;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR node : WMTrees.TreeNode;
		BEGIN
			IF horizontal.Get() THEN
				node := FindHorizontal(x);
			ELSE
				node := FindVertical(y);
			END;
			leftClick := (0 IN keys);
			IF leftClick & (node # NIL) & IsSelectable(node) THEN
				dragObject := GetDragWrapper(node, menu);
				IF (dragObject # NIL) THEN
					dragPossible := TRUE;
					dragNode := node;
				END;
			ELSE
				CloseSubMenu(FALSE);
			END;
		END PointerDown;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR node : WMTrees.TreeNode;
		BEGIN
			IF leftClick THEN
				IF horizontal.Get() THEN
					node := FindHorizontal(x);
				ELSE
					node := FindVertical(y);
				END;
				IF (node # NIL) THEN
					IF IsSelectable(node) THEN
						SelectNode(node, FALSE);
					END;
				ELSE
					CloseSubMenu(FALSE);
				END;
			END;
			dragPossible := FALSE;
		END PointerUp;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR node : WMTrees.TreeNode;
		BEGIN
			IF dragPossible THEN
				IF (ABS(x - downX) > DragDist) OR (ABS(y - downY) > DragDist) THEN
					dragPossible := FALSE;
					IF (dragObject # NIL) THEN
						leftClick := FALSE;
						MyStartDrag(dragNode, dragObject);
					END;
				END;
			ELSE
				IF horizontal.Get() THEN
					node := FindHorizontal(x);
				ELSE
					node := FindVertical(y);
				END;
				IF (node # NIL) & ~IsSelectable(node) THEN node := NIL; END;
				IF (node # hover) THEN hover := node; Invalidate; END;
			END;
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			IF hover # NIL THEN hover := NIL; Invalidate; END;
		END PointerLeave;

		PROCEDURE MyStartDrag(node : WMTrees.TreeNode; object : ANY);
		VAR
			image, canvasImage : WMGraphics.Image; VAR caption : Strings.String;
			canvas : WMGraphics.BufferCanvas;
			width, height, x : LONGINT;
		BEGIN
			ASSERT((node # NIL) & (object # NIL));
			menu.Acquire;
			image := menu.GetNodeImage(node);
			caption := menu.GetNodeCaption(node);
			height := ItemHeight(node);
			menu.Release;
			width := bounds.GetWidth();
			NEW(canvasImage); Raster.Create(canvasImage, width, height, Raster.BGRA8888);
			NEW(canvas, canvasImage);
			(* actually should factor out node rendering code in DrawBackground and re-use it here... *)
			x := HMenuDistance;
			canvas.Fill(WMRectangles.MakeRect(0, 0, greyBoxWidth, height), LightGreyDrag, WMGraphics.ModeSrcOverDst);
			canvas.Fill(WMRectangles.MakeRect(greyBoxWidth, 0, width, height), WhiteDrag, WMGraphics.ModeSrcOverDst);
			IF (image # NIL) THEN
				canvas.DrawImage(x, VMenuDistance, image, WMGraphics.ModeSrcOverDst);
				x := x + image.width + HMenuDistance + TextImageDistance;
			END;
			IF (caption # NIL) THEN
				canvas.SetColor(WMGraphics.Black);
				WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(x, 0, width, height), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, caption^);
			END;
			IF ~StartDrag(object, canvasImage, 0,0,DragWasAccepted, NIL) THEN dragNode := NIL; dragObject := NIL; END;
		END MyStartDrag;

		PROCEDURE DragWasAccepted(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo; itf : WMDropTarget.DropInterface; ignoreRes : LONGINT;
		BEGIN
			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					itf := di.data(WMDropTarget.DropTarget).GetInterface(WMDropTarget.TypeObject);
					IF (itf # NIL) & (itf IS WMDropTarget.DropObject) THEN
						itf(WMDropTarget.DropObject).Set(dragObject, ignoreRes);
					END;
				END;
			END;
			IF (rootMenuPanel.parentWindow # NIL) THEN
				rootMenuPanel.parentWindow.Close;
			ELSE
				rootMenuPanel.CloseSubMenu(FALSE);
			END;
		END DragWasAccepted;

		PROCEDURE CursorUp;
		BEGIN
			IF horizontal.Get() THEN
				IF (openDirectionI = OpenUpLeft) OR (openDirectionI = OpenUpRight) THEN
					IF (hover # NIL) & HasChildren(hover, menu) THEN
						SelectNode(hover, TRUE);
					END;
				END;
			ELSE
				MoveToPrevious;
			END;
		END CursorUp;

		PROCEDURE CursorDown;
		BEGIN
			IF horizontal.Get() THEN
				IF (openDirectionI = OpenDownLeft) OR (openDirectionI = OpenDownRight) THEN
					IF (hover # NIL) & HasChildren(hover, menu) THEN
						SelectNode(hover, TRUE);
					END;
				END;
			ELSE
				MoveToNext;
			END;
		END CursorDown;

		PROCEDURE CursorLeft;
		BEGIN
			IF horizontal.Get() THEN
				MoveToPrevious;
			ELSE
				IF (openDirectionI = OpenUpLeft) OR (openDirectionI = OpenDownLeft) THEN
					Acquire;
					IF (hover # NIL) & HasChildren(hover, menu) THEN
						SelectNode(hover, TRUE);
					END;
					Release;
				ELSE
					IF (parentMenuPanel # NIL) THEN
						parentMenuPanel.CloseSubMenu(TRUE);
					END;
				END;
			END;
		END CursorLeft;

		PROCEDURE CursorRight;
		BEGIN
			IF horizontal.Get() THEN
				MoveToNext;
			ELSE
				IF (openDirectionI = OpenUpRight) OR (openDirectionI = OpenDownRight) THEN
					Acquire;
					IF (hover # NIL) & HasChildren(hover, menu) THEN
						SelectNode(hover, TRUE);
					END;
					Release;
				ELSE
					IF (parentMenuPanel # NIL) THEN
						parentMenuPanel.CloseSubMenu(TRUE);
					END;
				END;
			END;
		END CursorRight;

		PROCEDURE MoveToPrevious;
		BEGIN
			Acquire;
			menu.Acquire;
			IF (hover # NIL) THEN
				hover := menu.GetPrevSibling(hover);
				IF (hover = NIL) THEN
					hover := menu.GetLastChild(root);
				END;
			ELSE
				hover := menu.GetLastChild(root);
			END;
			menu.Release;
			Release;
			Invalidate;
		END MoveToPrevious;

		PROCEDURE MoveToNext;
		BEGIN
			Acquire;
			menu.Acquire;
			IF (hover # NIL) THEN
				hover := menu.GetNextSibling(hover);
				IF (hover = NIL) THEN
					hover := menu.GetChildren(root);
				END;
			ELSE
				hover := menu.GetChildren(root);
			END;
			menu.Release;
			Release;
			Invalidate;
		END MoveToNext;

		PROCEDURE SelectCurrent;
		BEGIN
			Acquire;
			IF (hover # NIL) THEN
				SelectNode(hover, TRUE);
			END;
			Release;
		END SelectCurrent;

		PROCEDURE KeyEvent*(ucs : LONGINT; flags: SET; VAR keySym: LONGINT); (** PROTECTED *)
		VAR focusPanel : MenuPanel;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (Inputs.Release IN flags) THEN RETURN; END;
			focusPanel := rootMenuPanel.focusPanel;
			IF (focusPanel # NIL) THEN
				IF (keySym = Inputs.KsUp) THEN focusPanel.CursorUp;
				ELSIF (keySym = Inputs.KsDown) THEN focusPanel.CursorDown;
				ELSIF (keySym = Inputs.KsLeft) THEN focusPanel.CursorLeft;
				ELSIF (keySym = Inputs.KsRight) THEN focusPanel.CursorRight;
				ELSIF (ucs = 20H) OR (keySym = Inputs.KsReturn) THEN focusPanel.SelectCurrent;
				ELSIF (keySym = Inputs.KsEscape) THEN
					IF (focusPanel.parentMenuPanel # NIL) THEN
						focusPanel.parentMenuPanel.CloseSubMenu(TRUE);
					ELSIF (focusPanel.parentWindow # NIL) THEN
						focusPanel.parentWindow.CloseMenu(NIL, NIL);
					END;
				ELSE
				END;
			END;
		END KeyEvent;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			CloseSubMenu(FALSE);
			IF (selection # NIL) OR (hover # NIL) THEN
				selection := NIL; hover := NIL;
				Invalidate;
			END;
		END FocusLost;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			CloseSubMenu(FALSE);
		END Finalize;

	END MenuPanel;

TYPE

	ShadowWindow = OBJECT(WMWindowManager.Window)
	VAR
		type, color : LONGINT;

		PROCEDURE &New(type : LONGINT);
		BEGIN
			ASSERT((type = Right) OR (type = Bottom));
			SELF.type := type;
			Init(0, 0, TRUE);
			color := 04FH;
		END New;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		BEGIN
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, WMGraphics.ModeSrcOverDst);
		END Draw;

	END ShadowWindow;

TYPE

	MenuWindow= OBJECT(WMComponents.FormWindow)
	VAR
		menuPanel : MenuPanel;
		takesFocus : BOOLEAN;

		PROCEDURE &Open*(x, y : LONGINT; openDirection : LONGINT; menu : WMTrees.Tree; root : WMTrees.TreeNode; parent : MenuPanel; takesFocus, indicate : BOOLEAN);
		VAR width, height, dx, dy : LONGINT; ignore : BOOLEAN; flags : SET;
		BEGIN
			NEW(menuPanel);
			menuPanel.openDirection.Set(openDirection);
			menuPanel.SetMenu(menu, root);
			menuPanel.SetParent(parent);
			IF (indicate) THEN
				menu.Acquire;
				menuPanel.hover := menu.GetChildren(root);
				menu.Release;
			END;
			SELF.takesFocus := takesFocus;

			menuPanel.Measure(width, height);
			IF (height < 5) THEN height := 5; END;
			IF (width < 5) THEN width := 5; END;

			CASE openDirection OF
				|OpenUpLeft : dx := -width; dy := -height;
				|OpenUpRight : dy := -height;
				|OpenDownLeft : dx := -width;
			ELSE
				dx := 0; dy := 0;
			END;
			menuPanel.bounds.SetExtents(width, height);
			menuPanel.fillColor.Set(WMGraphics.White);

			Init(menuPanel.bounds.GetWidth(), menuPanel.bounds.GetHeight(), FALSE);
			SetContent(menuPanel);
			flags := {WMWindowManager.FlagFrame, WMWindowManager.FlagHidden, WMWindowManager.FlagStayOnTop};
			IF ~takesFocus THEN flags := flags + {WMWindowManager.FlagNoFocus}; END;
			AddWindow(SELF, x + dx, y + dy, flags);
			ignore := manager.TransferPointer(SELF);
			manager.SetFocus(SELF);
		END Open;

		PROCEDURE CloseMenu(sender, data : ANY);
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.CloseMenu, NIL, NIL);
			ELSE
				Close;
			END
		END CloseMenu;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			IF takesFocus THEN
				Close;
			END;
		END FocusLost;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; w, h, q : LONGINT); (** override *)
		BEGIN
			Draw^(canvas, w, h, q);
			WMGraphicUtilities.DrawRect(canvas, WMRectangles.MakeRect(0, 0, w, h), WMGraphics.Black, WMGraphics.ModeCopy);
		END Draw;

	END MenuWindow;

VAR
	StrMenuPanel : Strings.String;

PROCEDURE AddWindow(window : WMWindowManager.Window; x, y : LONGINT; flags : SET);
VAR
	manager : WMWindowManager.WindowManager;
	view : WMWindowManager.ViewPort;
	oldDecorator : WMWindowManager.Decorator;
BEGIN
	ASSERT(window # NIL);
	manager := WMWindowManager.GetDefaultManager();
	view := WMWindowManager.GetDefaultView();
	ASSERT((manager # NIL) & (view # NIL));
	manager.lock.AcquireWrite;
	oldDecorator := manager.decorate;
	manager.decorate := ShadowDecorator;
	manager.Add((*ENTIER(view.range.l) +*) x, (*ENTIER(view.range.t) + *)y, window, flags);
	manager.decorate := oldDecorator;
	manager.lock.ReleaseWrite;
END AddWindow;

PROCEDURE ShadowDecorator(window : WMWindowManager.Window);
VAR shadow : ShadowWindow; l, r, t, b : LONGINT;

	PROCEDURE InsertAfter(old, new : WMWindowManager.Window);
	BEGIN
		new.next := old.next;
		new.prev := old;
		old.next := new;
		new.next.prev := new
	END InsertAfter;

	PROCEDURE InitShadow(shadow : ShadowWindow);
	BEGIN
		shadow.manager := window.manager;
		shadow.flags := {WMWindowManager.FlagNoFocus, WMWindowManager.FlagHidden};
		IF WMWindowManager.FlagStayOnBottom IN window.flags THEN INCL(shadow.flags, WMWindowManager.FlagStayOnBottom); END;
		IF WMWindowManager.FlagNoResizing IN window.flags THEN INCL(shadow.flags, WMWindowManager.FlagNoResizing); END;
		IF WMWindowManager.FlagNavigation IN window.flags THEN
			shadow.view := window.view;
			INCL(shadow.flags, WMWindowManager.FlagNavigation);
		END;
		InsertAfter(window, shadow);

		shadow.manager.AddDecorWindow(window, shadow);
		shadow.manager.AddVisibleDirty(shadow, shadow.bounds);
	END InitShadow;

BEGIN
	ASSERT((window.manager # NIL) & (window.manager.lock.HasWriteLock()));
	l := window.bounds.l; r := window.bounds.r; t := window.bounds.t; b := window.bounds.b;

	NEW(shadow, Right); window.rightW := shadow;
	shadow.bounds := WMRectangles.MakeRect(r, t + ShadowOffsetVertical, r + ShadowWidth, b + ShadowHeight);
	InitShadow(shadow);

	NEW(shadow, Bottom); window.bottomW := shadow;
	shadow.bounds := WMRectangles.MakeRect(l + ShadowOffsetHorizontal, b, r, b + ShadowHeight);
	InitShadow(shadow);
END ShadowDecorator;

PROCEDURE HasChildren(parent : WMTrees.TreeNode; tree : WMTrees.Tree) : BOOLEAN;
VAR hasChildren : BOOLEAN;
BEGIN
	ASSERT(tree # NIL);
	IF (parent # NIL) THEN
		tree.Acquire;
		hasChildren := tree.GetChildren(parent) # NIL;
		tree.Release;
	ELSE
		hasChildren := FALSE;
	END;
	RETURN hasChildren;
END HasChildren;

PROCEDURE GetCaption*(data : ANY; menu : WMTrees.Tree) : Strings.String;
VAR caption : Strings.String;
BEGIN
	ASSERT(menu # NIL);
	IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
		menu.Acquire;
		caption := menu.GetNodeCaption(data(WMTrees.TreeNode));
		menu.Release;
	ELSE
		caption := NIL;
	END;
	RETURN caption;
END GetCaption;

PROCEDURE GetDragWrapper*(node : WMTrees.TreeNode; menu : WMTrees.Tree) : DragWrapper;
VAR data: ANY; drag : DragWrapper
BEGIN
	ASSERT(menu # NIL);
	drag := NIL;
	IF (node # NIL) THEN
		menu.Acquire;
		data := menu.GetNodeData(node);
		menu.Release;
		IF (data # NIL) & (data IS DragWrapper) THEN
			drag := data(DragWrapper);
		END;
	END;
	RETURN drag;
END GetDragWrapper;

PROCEDURE FindChild(CONST caption : ARRAY OF CHAR; parent : WMTrees.TreeNode; tree : WMTrees.Tree) : WMTrees.TreeNode;
VAR child : WMTrees.TreeNode; string : Strings.String; found : BOOLEAN;
BEGIN
	ASSERT((parent # NIL) & (tree # NIL) & (tree.HasLock()));
	found := FALSE;
	child := tree.GetChildren(parent);
	WHILE (child # NIL) & ~found DO
		string := tree.GetNodeCaption(child);
		found := (string # NIL) & (string^ = caption);
		IF ~found THEN
			child := tree.GetNextSibling(child);
		END;
	END;
	RETURN child;
END FindChild;

PROCEDURE AddChild*(CONST caption : ARRAY OF CHAR; parent : WMTrees.TreeNode; tree : WMTrees.Tree) : WMTrees.TreeNode;
VAR node : WMTrees.TreeNode; separator : Separator;
BEGIN
	ASSERT((parent # NIL) & (tree # NIL) & (tree.HasLock()));
	IF (caption # SeparatorCaption) THEN
		NEW(node);
		tree.SetNodeCaption(node, Strings.NewString(caption));
	ELSE
		NEW(separator);
		node := separator;
	END;
	tree.AddChildNode(parent, node);
	RETURN node;
END AddChild;

PROCEDURE Find*(CONST path : ARRAY OF CHAR; menu : WMTrees.Tree) : WMTrees.TreeNode;
VAR caption : ARRAY 256 OF CHAR; child, node, parent : WMTrees.TreeNode; i, j : LONGINT;
BEGIN
	ASSERT(menu # NIL);
	node := NIL;
	menu.Acquire;
	parent := menu.GetRoot();
	IF (parent # NIL) THEN
		caption := "";
		i := 0; j := 0;
		LOOP
			IF (i >= LEN(path)) THEN
				EXIT;
			ELSIF (path[i] = ".") OR (path[i] = 0X) THEN
				caption[j] := 0X;
				child := FindChild(caption, parent, menu);
				IF (child = NIL) THEN
					EXIT;
				END;
				parent := child;
				IF (path[i] = 0X) THEN
					node := child;
					EXIT;
				ELSE
					caption := ""; j := 0;
				END;
			ELSIF (j < LEN(caption) - 1) THEN
				caption[j] := path[i];
				INC(j);
			END;
			INC(i);
		END;
	END;
	menu.Release;
	RETURN node;
END Find;

PROCEDURE AddItemNode*(CONST path : ARRAY OF CHAR; menu : WMTrees.Tree) : WMTrees.TreeNode;
VAR caption : ARRAY 256 OF CHAR; node, parent : WMTrees.TreeNode; i, j : LONGINT;
BEGIN
	ASSERT(menu # NIL);
	menu.Acquire;
	IF (menu.GetRoot() = NIL) THEN
		NEW(node); menu.SetRoot(node)
	END;
	i := 0; j := 0;
	caption := ""; parent := menu.GetRoot();
	LOOP
		IF (i >= LEN(path)) THEN
			EXIT;
		ELSIF (path[i] = ".") OR (path[i] = 0X) THEN
			caption[j] := 0X;
			node := FindChild(caption, parent, menu);
			IF (node = NIL) THEN
				node := AddChild(caption, parent, menu);
			END;
			parent := node;
			caption := ""; j := 0;
			IF (path[i] = 0X) THEN EXIT; END;
		ELSIF (j < LEN(caption) - 1) THEN
			caption[j] := path[i];
			INC(j);
		END;
		INC(i);
	END;
	menu.Release;
	ASSERT(node # NIL);
	RETURN node;
END AddItemNode;

PROCEDURE AddItem*(CONST path : ARRAY OF CHAR; menu : WMTrees.Tree);
VAR ignore : WMTrees.TreeNode;
BEGIN
	ignore := AddItemNode(path, menu);
END AddItem;

PROCEDURE Show*(menu : WMTrees.Tree; x, y : LONGINT; handler : WMEvents.EventListener);
VAR window : MenuWindow; root : WMTrees.TreeNode;
BEGIN
	ASSERT((menu # NIL) & (handler # NIL));
	menu.Acquire;
	root := menu.GetRoot();
	menu.Release;
	IF (root # NIL) THEN
		NEW(window, x, y, OpenDefault, menu, root, NIL, TRUE, FALSE);
		window.menuPanel.SetParentWindow(window);
		window.menuPanel.onSelect.Add(handler);
	END;
END Show;

BEGIN
	StrMenuPanel := Strings.NewString("MenuPanel");
END WMMenus.