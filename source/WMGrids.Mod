MODULE WMGrids;	(** AUTHOR "TF"; PURPOSE "Generic grid component"; *)

IMPORT
	Inputs, XML, WMComponents,
	WMStandardComponents, Strings, Graphics := WMGraphics, WMRectangles,
	WMProperties, WMEvents,
	WM := WMWindowManager;

TYPE
	(* Local type - alias for convenience *)
	String = Strings.String;

	(* return the desired size of the cell. Only used for auto-sizing. *)
	MeasureCellProc* = PROCEDURE {DELEGATE} (x, y : LONGINT; VAR width, height : LONGINT);
	(** Draw the cell (from 0, 0 to w, h) into canvas. state may include ??? *)
	DrawCellProc* = PROCEDURE {DELEGATE} (canvas : Graphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
	(** Return the number of cells spaned in x an d y direction. *)
	GetCellSpansProc* = PROCEDURE {DELEGATE} (x, y : LONGINT; VAR spanx, spany : LONGINT);
	GetCellStateProc* = PROCEDURE {DELEGATE} (x, y : LONGINT) : SET;

	Spacings* = POINTER TO ARRAY OF LONGINT;

CONST
	CellHighlighted* = 0; CellSelected* = 1; CellFocused* = 2; CellFixed* = 3;
	GridSelectNone* = 0; (** not selectable *)
	GridSelectSingleCell* = 1; (** only a single cell can be selected *)
	GridSelectSingleCol* = 2; (** only a single column can be selected *)
	GridSelectSingleRow* = 3; (** only a single row can be selected *)
	GridSelectHorizontal = 4; (** horizontal strips can be selected *)
	GridSelectVertical = 5; (** vertical strips can be selected *)
	GridSelectCols* = 6; (** only columns can be selected *)
	GridSelectRows* = 7; (** only rows can be selected *)
	GridSelectBlock* = 8;

CONST
	PixelRange = 2; (* sensitive pixels left and right of a column/row separation *)
	DragDist = 10;

TYPE
	CellPos* = RECORD col*, row* : LONGINT END;

	CellPositionInfo* = OBJECT
	VAR
		pos* : CellPos;
	END CellPositionInfo;
	(** Generic grid component. Supports :
		Spacing : equal/variable  row / column spacing
		Number of fixed rows/colums (Fixed cells may NOT span multiple colums or rows)
		Cells can span multiple rows and/or colums
	*)
	GenericGrid* = OBJECT(WMComponents.VisualComponent)
	VAR
		getCellSpans : GetCellSpansProc;
		drawCell : DrawCellProc;
		getCellState : GetCellStateProc;
		tableStart* : CellPos;
		state, tempState : Graphics.CanvasState;
		scrollx-, scrolly- : WMStandardComponents.Scrollbar;
		showScrollX-, showScrollY- : WMProperties.BooleanProperty;  (* show scrollbars if needed *)
		showScrollXC, showScrollYC : BOOLEAN;
		alwaysShowScrollX-, alwaysShowScrollY- : WMProperties.BooleanProperty;  (* always show scrollbars even if not needed, overruled by showScroll *)
		alwaysShowScrollXC, alwaysShowScrollYC : BOOLEAN;
		nofRows-, nofCols-, cellDist- : WMProperties.Int32Property;
		nofRowsC, nofColsC, cellDistC : LONGINT; (* internal count of rows and colums *)
		rowHeights, colWidths : Spacings; (* variable sizes of rows and cols *)
		fixedCols-, fixedRows- : WMProperties.Int32Property; (* number of cols/rows that are fixed *)
		fixedColsC, fixedRowsC : LONGINT; (* internal cache of the respective property values *)
		defaultColWidth-, defaultRowHeight- : WMProperties.Int32Property;
		defaultColWidthC, defaultRowHeightC : LONGINT; (* internal cache of the respective property values *)
		allowColResize-, allowRowResize- : WMProperties.BooleanProperty;

		(**
		 * If set to TRUE,
		 *	- clicking on a cell which is not completely visible will scroll the grid so it's visible
		 *	- when dragging and the pointer leaves the visible part of the grid, the grid is scrolled
		 * default : TRUE;
		 *)
		adjustFocusPosition- : WMProperties.BooleanProperty;

		focus, focusCell, highlight : CellPos; (* focusCell is the master Cell of focus *)
		selectionMode : LONGINT;
		selStart, selEnd : CellPos;
		selA : CellPos;
		selecting : BOOLEAN;
		drag : BOOLEAN;
		pointerInside : BOOLEAN; (* the last position of the pointer is needed for correct highlighting when scrolling with kb *)
		lastPointerX, lastPointerY :LONGINT;
		wasSelected- : BOOLEAN;
		onSelect- : WMEvents.EventSource;
		onClick- : WMEvents.EventSource;
		onClickSelected- : WMEvents.EventSource;
		shiftDown : BOOLEAN;
		hasOldPointer : BOOLEAN;
		prevPointerInfo : WM.PointerInfo;

		(* drag cell spacing *)
		dragCellSpacingNr : LONGINT;
		dragCellSpacingPos : LONGINT;
		dragCellSpacingWidth : BOOLEAN;
		dragCellSpacingHeight : BOOLEAN;

		downX, downY : LONGINT;
		dragPossible : BOOLEAN;
		selectOnPointerOver : BOOLEAN;
		lastkeys : SET;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(GSGenericGrid);
			takesFocus.Set(TRUE);
			NEW(scrollx); NEW(scrolly);
			AddInternalComponent(scrollx); AddInternalComponent(scrolly);
			scrollx.alignment.Set(WMComponents.AlignBottom);
			scrollx.vertical.Set(FALSE);
			scrolly.alignment.Set(WMComponents.AlignRight);
			scrolly.vertical.Set(TRUE);

			scrollx.onPositionChanged.Add(Scrolled);
			scrolly.onPositionChanged.Add(Scrolled);
			scrollx.pageSize.Set(1);
			scrolly.pageSize.Set(1);

			selectionMode := GridSelectSingleCell;
			selStart.col := -1; selStart.row := -1;
			selEnd.col := -1; selEnd.row := -1;
			highlight.col := -1; highlight.row := -1;

			(* properites *)
			NEW(defaultColWidth, defaultColWidthProto, NIL, NIL); properties.Add(defaultColWidth);
			NEW(defaultRowHeight, defaultRowHeightProto, NIL, NIL); properties.Add(defaultRowHeight);
			NEW(fixedCols, fixedColsProto, NIL, NIL); properties.Add(fixedCols);
			NEW(fixedRows, fixedRowsProto, NIL, NIL); properties.Add(fixedRows);
			NEW(allowColResize, allowColResizeProto, NIL, NIL); properties.Add(allowColResize);
			NEW(allowRowResize, allowRowResizeProto, NIL, NIL); properties.Add(allowRowResize);
			NEW(nofRows, nofRowsProto, NIL, NIL); properties.Add(nofRows);
			NEW(nofCols, nofColsProto, NIL, NIL); properties.Add(nofCols);
			NEW(cellDist, cellDistProto, NIL, NIL); properties.Add(cellDist);
			NEW(showScrollX, showScrollXProto, NIL, NIL); properties.Add(showScrollX);
			NEW(showScrollY, showScrollYProto, NIL, NIL); properties.Add(showScrollY);
			NEW(alwaysShowScrollX, alwaysShowScrollXProto, NIL, NIL); properties.Add(alwaysShowScrollX);
			NEW(alwaysShowScrollY, alwaysShowScrollYProto, NIL, NIL); properties.Add(alwaysShowScrollY);
			NEW(adjustFocusPosition, adjustFocusPositionProto, NIL, NIL); properties.Add(adjustFocusPosition);

			pointerInside := FALSE;

			selectOnPointerOver := FALSE;
			(* events *)
			NEW(onSelect, SELF, GSonSelect, GSonSelectInfo, SELF.StringToCompCommand); events.Add(onSelect);
			NEW(onClick, SELF, GSonClick, GSonClickInfo, SELF.StringToCompCommand); events.Add(onClick);
			NEW(onClickSelected, SELF, GSonClickSelected, GSonClickSelectedInfo, SELF.StringToCompCommand); events.Add(onClickSelected);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			RecacheAllProperties
		END Initialize;

		PROCEDURE RecacheAllProperties;
		BEGIN
			defaultColWidthC := defaultColWidth.Get();
			defaultRowHeightC := defaultRowHeight.Get();
			fixedColsC := fixedCols.Get();
			fixedRowsC := fixedRows.Get();
			tableStart.row := Strings.Max(tableStart.row, fixedRowsC);
			tableStart.col := Strings.Max(tableStart.col, fixedColsC);

			nofRowsC := nofRows.Get();
			nofColsC := nofCols.Get();
			IF nofColsC = 1 THEN defaultColWidthC := bounds.GetWidth() END; (* list case *)
			cellDistC := cellDist.Get();
			showScrollXC := showScrollX.Get();
			showScrollYC := showScrollY.Get();
			alwaysShowScrollXC := alwaysShowScrollX.Get();
			alwaysShowScrollYC := alwaysShowScrollY.Get();
			CheckScrollbarsNeeded;
			AlignSubComponents
		END RecacheAllProperties;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			RecacheAllProperties
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			RecacheAllProperties;
			Invalidate;
			PropertyChanged^(sender, property)
		END PropertyChanged;

		PROCEDURE GetColWidth*(i : LONGINT) : LONGINT;
		BEGIN
			CheckReadLock;
			IF colWidths = NIL THEN RETURN defaultColWidthC
			ELSIF (i < 0) OR (i > nofColsC) THEN RETURN 0
			ELSE
				IF i >= LEN(colWidths^) THEN RETURN defaultColWidthC ELSE RETURN colWidths[i] END
			END
		END GetColWidth;

		(** Set the width of columns. IF NIL, all columns have the default column width. If the spacings
		array is smaller than the number of columns, the additional columns have the default column width *)
		PROCEDURE SetColSpacings*(colWidths : Spacings);
		BEGIN
			Acquire;
			SELF.colWidths := colWidths;
			Invalidate();
			Release
		END SetColSpacings;

		(** returns a spacings array filled with the column width. The array contains only so many elements
		as the one set with SetColSpacings. The result is NIL, if not set with SetColSpacings *)
		PROCEDURE GetColSpacings*() : Spacings;
		VAR t : Spacings; i : LONGINT;
		BEGIN
			Acquire;
			IF colWidths # NIL THEN NEW(t, LEN(colWidths)); FOR i := 0 TO LEN(colWidths) - 1 DO t[i] := colWidths[i] END END;
			Release;
			RETURN t
		END GetColSpacings;

		(** Set the height of rows. IF NIL, all rows have the default row height. If the spacings
		array is smaller than the number of rows, the additional rows have the default row height *)
		PROCEDURE SetRowSpacings*(rowHeights : Spacings);
		BEGIN
			Acquire;
			SELF.rowHeights := rowHeights;
			Invalidate();
			Release
		END SetRowSpacings;

		(** returns a spacings array filled with the row heights. The array contains only so many elements
		as the one set with SetRowSpacings. The result is NIL, if not set with SetRowSpacings *)
		PROCEDURE GetRowSpacings*() : Spacings;
		VAR t : Spacings; i : LONGINT;
		BEGIN
			Acquire;
			IF rowHeights # NIL THEN NEW(t, LEN(rowHeights)); FOR i := 0 TO LEN(rowHeights) - 1 DO t[i] := rowHeights[i] END END;
			Release;
			RETURN t
		END GetRowSpacings;

		PROCEDURE SetSelectOnPointerOver*(select : BOOLEAN);
		BEGIN
			selectOnPointerOver := select;
		END SetSelectOnPointerOver;

(** Scrollbars *)
		(** Define if the scrollbars should always be visible, if not needed. Overruled by ShowScrollbars *)
		PROCEDURE GetRowHeight*(i : LONGINT) : LONGINT;
		BEGIN
			CheckReadLock;
			IF rowHeights = NIL THEN RETURN defaultRowHeightC
			ELSIF (i < 0) OR (i > nofRowsC) THEN RETURN 0
			ELSE
				IF i >= LEN(rowHeights^) THEN RETURN defaultRowHeightC ELSE RETURN rowHeights[i] END
			END
		END GetRowHeight;

		PROCEDURE SetSelectionMode*(mode : LONGINT);
		BEGIN
			Acquire;
			IF mode # selectionMode THEN
				selectionMode := mode;
				Invalidate()
			END;
			Release
		END SetSelectionMode;

		PROCEDURE GetSelectionMode*():LONGINT;
		BEGIN
			RETURN selectionMode
		END GetSelectionMode;

		PROCEDURE SetDrawCellProc*(dcp :DrawCellProc);
		BEGIN
			Acquire;
			IF SELF.drawCell # dcp THEN
				SELF.drawCell := dcp;
				Invalidate()
			END;
			Release
		END SetDrawCellProc;

		PROCEDURE GetFixedPixels*(VAR w, h :LONGINT);
		VAR i : LONGINT;
		BEGIN
			w := 0; h := 0;
			FOR i := 0 TO fixedColsC - 1 DO INC(w, GetColWidth(i) + cellDistC) END;
			FOR i := 0 TO fixedRowsC - 1 DO INC(h, GetRowHeight(i) + cellDistC) END;
		END GetFixedPixels;

		PROCEDURE  SetCellSpansProc*(gcsp : GetCellSpansProc);	(* Dan *)
		BEGIN
			IF getCellSpans # gcsp THEN
				Acquire;
				getCellSpans := gcsp;
				Release
			END
		END SetCellSpansProc;

		PROCEDURE GetCellSpans(x, y : LONGINT; VAR spanx, spany : LONGINT);
		BEGIN
			IF getCellSpans # NIL THEN getCellSpans(x, y, spanx, spany)
			ELSE spanx := 1; spany := 1
			END
		END GetCellSpans;

		PROCEDURE IsSkipCell*(x, y : LONGINT) : BOOLEAN;
		VAR spanx, spany : LONGINT;
		BEGIN
			GetCellSpans(x, y, spanx, spany);
			RETURN (spanx = 0) OR (spany = 0)
		END IsSkipCell;

		PROCEDURE GetCellDimensions*(x, y : LONGINT; VAR width, height : LONGINT);
		VAR spanx, spany, i : LONGINT;
		BEGIN
			GetCellSpans(x, y, spanx, spany);
			width := -cellDistC; height := -cellDistC;
			FOR i := 0 TO spanx - 1 DO width := width + GetColWidth(x) + cellDistC END;
			FOR i := 0 TO spany - 1 DO height := height + GetRowHeight(y) + cellDistC END
		END GetCellDimensions;

		(* override by subclass *)
		PROCEDURE GetCellData*(col, row : LONGINT) : ANY;
		VAR position : CellPositionInfo;
		BEGIN
			NEW(position); position.pos.row := row; position.pos.col := col;
			RETURN position
		END GetCellData;

		PROCEDURE GetCellState(x, y : LONGINT) : SET;
		VAR state : SET;
		BEGIN
			IF getCellState # NIL THEN RETURN getCellState(x, y)
			ELSE
				state := {};
				IF (x = focus.col) & (y = focus.row) THEN state := state + {CellFocused} END;
				IF (x < fixedColsC) OR (y < fixedRowsC) THEN state := state + {CellFixed} END;
				CASE selectionMode OF
					| GridSelectSingleCell :
						IF (x = selStart.col) & (y = selStart.row) THEN state := state + {CellSelected} END;
						IF (x = highlight.col) & (y = highlight.row) THEN state := state + {CellHighlighted} END
					| GridSelectSingleCol, GridSelectCols :
						IF (x >= selStart.col) & (x <= selEnd.col) THEN state := state + {CellSelected} END;
						IF (x = highlight.col) THEN state := state + {CellHighlighted} END
					| GridSelectSingleRow, GridSelectRows :
						IF (y >= selStart.row) & (y <= selEnd.row) THEN state := state + {CellSelected} END;
						IF (y = highlight.row)  THEN state := state + {CellHighlighted} END
					| GridSelectBlock, GridSelectHorizontal, GridSelectVertical :
						IF (x >= selStart.col) & (x <= selEnd.col) &(y >= selStart.row) & (y <= selEnd.row) THEN state := state + {CellSelected} END;
						IF (x = highlight.col) & (y = highlight.row) THEN state := state + {CellHighlighted} END;
				ELSE
				END;
				RETURN state
			END
		END GetCellState;

		(** col, row point to the master cell of (x, y). dx, dy are decreased by the respective decrement *)
		PROCEDURE FindMasterCell*(x, y : LONGINT; VAR col, row, xpos, ypos : LONGINT);
		VAR cw, ch : LONGINT;
		BEGIN
			col := x; row := y;
			GetCellSpans(col, row, cw, ch);
			WHILE (cw = 0) OR (ch = 0) DO
				IF cw = 0 THEN DEC(col); DEC(xpos, GetColWidth(col) + cellDistC) END;
				IF ch = 0 THEN DEC(row); DEC(ypos, GetRowHeight(row) + cellDistC) END;
				GetCellSpans(col, row, cw, ch)
			END
		END FindMasterCell;

		(* Find the cell at position x, y (also fixed cells are returned) *)
		PROCEDURE FindCellXY* (x, y : LONGINT; VAR col, row : LONGINT);
		VAR tx, ty, dummy : LONGINT;
		BEGIN
			GetFixedPixels(tx, ty);
			IF (x < tx) & (y < ty) THEN (* row and column fixed *)
				col := 0; row := 0; tx := 0; ty := 0;
				REPEAT tx := tx + GetColWidth(col) + cellDistC; INC(col) UNTIL (col >= fixedColsC) OR (tx >= x); DEC(col);
				REPEAT ty := ty + GetRowHeight(row) + cellDistC; INC(row) UNTIL (row >= fixedRowsC) OR (ty >= y); DEC(row);
			ELSIF (x < tx) THEN (* column fixed *)
				col := 0; row := tableStart.row; tx := 0;
				REPEAT tx := tx + GetColWidth(col) + cellDistC; INC(col) UNTIL (col >= fixedColsC) OR (tx >= x); DEC(col);
				REPEAT ty := ty + GetRowHeight(row) + cellDistC; INC(row) UNTIL (row >= nofRowsC) OR (ty >= y); DEC(row);
			ELSIF (y < ty) THEN  (* row fixed *)
				col := tableStart.col; row := 0; ty := 0;
				REPEAT tx := tx + GetColWidth(col) + cellDistC; INC(col) UNTIL (col >= nofColsC) OR (tx >= x); DEC(col);
				REPEAT ty := ty + GetRowHeight(row) + cellDistC; INC(row) UNTIL (row >= fixedRowsC) OR (ty >= y); DEC(row);
			ELSE (* normal cells *)
				col := tableStart.col; row := tableStart.row;
				REPEAT tx := tx + GetColWidth(col) + cellDistC; INC(col) UNTIL (col >= nofColsC) OR (tx >= x); DEC(col);
				REPEAT ty := ty + GetRowHeight(row) + cellDistC; INC(row) UNTIL (row >= nofRowsC) OR (ty >= y); DEC(row);
			END;
			FindMasterCell(col, row, col, row, dummy, dummy)
		END FindCellXY;

		PROCEDURE CheckScrollbarsNeeded;
		VAR xmax, ymax : LONGINT;
		BEGIN
			xmax := nofColsC - 1; ymax := nofRowsC - 1;
			scrollx.max.Set(xmax); scrolly.max.Set(ymax);
			scrollx.visible.Set((alwaysShowScrollXC OR (xmax > 1)) & showScrollXC);
			scrolly.visible.Set((alwaysShowScrollYC OR (ymax > 1)) & showScrollYC)
		END CheckScrollbarsNeeded;

		PROCEDURE GetVisibleCellRect(col, row : LONGINT): WMRectangles.Rectangle;
		VAR x, y, i, tc, tr, tx, ty, w, h: LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			GetFixedPixels(tx, ty);
			IF (col < fixedColsC) & (row < fixedRowsC) THEN
				x := 0; FOR i := 0 TO col - 1 DO INC(x, GetColWidth(i) + cellDistC) END;
				y := 0; FOR i := 0 TO row -1 DO INC(y, GetRowHeight(i) + cellDistC) END
			ELSIF col < fixedColsC THEN
				x := 0; FOR i := 0 TO col - 1 DO INC(x, GetColWidth(i) + cellDistC) END;
				y := ty; FOR i := tableStart.row TO row -1 DO INC(y, GetRowHeight(i) + cellDistC) END
			ELSIF row < fixedRowsC THEN
				x := tx; FOR i := tableStart.col TO col - 1 DO INC(x, GetColWidth(i) + cellDistC) END;
				y := 0; FOR i := 0 TO row -1 DO INC(y, GetRowHeight(i) + cellDistC) END
			ELSE
				x := tx; FOR i := tableStart.col TO col - 1 DO INC(x, GetColWidth(i) + cellDistC) END;
				y := ty; FOR i := tableStart.row TO row -1 DO INC(y, GetRowHeight(i) + cellDistC) END;
			END;
			FindMasterCell(col, row, tc, tr, x, y);
			rect.l := x; rect.t := y;
			GetCellDimensions(tc, tr, w, h); rect.r := rect.l + w; rect.b := rect.t + h;
			RETURN rect
		END GetVisibleCellRect;

		PROCEDURE DrawBackground(canvas : Graphics.Canvas);
		VAR i, j, x, y, w, h, cw, ch, ti, tj, tx, ty, fx, fy : LONGINT;
				skip : BOOLEAN;
				r, clip : WMRectangles.Rectangle;
		BEGIN
			DrawBackground^(canvas);
			tableStart.row := Strings.Max(tableStart.row, fixedRowsC);
			tableStart.col := Strings.Max(tableStart.col, fixedColsC);

			canvas.GetClipRect(clip);
			canvas.SaveState(state); (* save the current clip-state for the scrollbars *)
			GetFixedPixels(fx, fy);
			(* draw both side fixed area *)
			y := 0;
			FOR j := 0 TO fixedRowsC - 1 DO
				x := 0; h := GetRowHeight(j);
				FOR i := 0 TO fixedColsC - 1 DO
					w := GetColWidth(i);
					r := WMRectangles.MakeRect(x, y, x + w, y + h);
					IF WMRectangles.Intersect(r, clip) THEN
						canvas.SetClipRect(r);
						canvas.ClipRectAsNewLimits(x, y);
						IF drawCell # NIL THEN drawCell(canvas, w, h, GetCellState(i, j), i, j) END;
						canvas.RestoreState(state)
					END;
					INC(x, w + cellDistC)
				END;
				INC(y, h + cellDistC)
			END;
			(* draw the fixed rows *)
			y := 0;
			FOR j := 0 TO fixedRowsC - 1 DO
				h := GetRowHeight(j);
				i := tableStart.col; x := fx;
				WHILE (i < nofColsC) & (x < bounds.GetWidth()) DO
					w := GetColWidth(i);
					r := WMRectangles.MakeRect(x, y, x + w, y + h);
					IF WMRectangles.Intersect(r, clip) THEN
						canvas.SetClipRect(r);
						canvas.ClipRectAsNewLimits(x, y);
						IF drawCell # NIL THEN drawCell(canvas, w, h, GetCellState(i, j), i, j) END;
						canvas.RestoreState(state)
					END;
					INC(i);
					INC(x, w + cellDistC)
				END;
				INC(y, h + cellDistC)
			END;

			(* draw the fixed columns *)
			y := fy;
			j := tableStart.row;
			WHILE (j < nofRowsC) & (y < bounds.GetHeight()) DO
				h := GetRowHeight(j);
				i := 0; x := 0;
				FOR i := 0 TO fixedColsC - 1 DO
					w := GetColWidth(i);
					r := WMRectangles.MakeRect(x, y, x + w, y + h);
					IF WMRectangles.Intersect(r, clip) THEN
						canvas.SetClipRect(r);
						canvas.ClipRectAsNewLimits(x, y);
						IF drawCell # NIL THEN drawCell(canvas, w, h, GetCellState(i, j), i, j) END;
						canvas.RestoreState(state)
					END;
					INC(x, w + cellDistC)
				END;
				INC(j);
				INC(y, h + cellDistC)
			END;

			(* draw the table *)
			canvas.SetClipRect(WMRectangles.MakeRect(fx, fy, bounds.GetWidth(), bounds.GetHeight()));
			canvas.ClipRectAsNewLimits(0, 0);canvas.SaveState(tempState);
			j := tableStart.row; y := fy;
			WHILE (j < nofRowsC) & (y < bounds.GetHeight()) DO
				i := tableStart.col; x := fx;
				h := GetRowHeight(j);
				WHILE (i < nofColsC) & (x < bounds.GetWidth()) DO
					w := GetColWidth(i);
					tx := x; ty := y; ti := i; tj := j;
					skip := IsSkipCell(ti, tj);
					IF (~skip) OR (i = tableStart.col) OR (j = tableStart.row) THEN
						IF skip THEN (* handle spans that leap in *)
							FindMasterCell(ti, tj, ti, tj, tx, ty);
						END;
						GetCellDimensions(ti, tj, cw, ch);
						r := WMRectangles.MakeRect(tx, ty, tx + cw, ty + ch);
						IF WMRectangles.Intersect(r, clip) THEN
							canvas.SetClipRect(r);
							canvas.ClipRectAsNewLimits(tx, ty);
							IF drawCell # NIL THEN drawCell(canvas, w, h, GetCellState(i, j), i, j) END;
							canvas.RestoreState(tempState)
						END
					END;
					INC(i); INC(x, w + cellDistC)
				END;
				INC(j); INC(y, h + cellDistC)
			END;
			canvas.RestoreState(state) (* restore the original clip-state *)
		END DrawBackground;

		PROCEDURE InvalidateCell*(col, row : LONGINT);
		BEGIN
			Acquire;
			InvalidateRect(GetVisibleCellRect(col, row));
			Release
		END InvalidateCell;

		PROCEDURE SetTopPosition*(col, row : LONGINT; updateScrollbar : BOOLEAN);
		BEGIN
			Acquire;
			col := Strings.Min(Strings.Max(col, fixedColsC), nofColsC - 1);
			row := Strings.Min(Strings.Max(row, fixedRowsC), nofRowsC - 1);
			IF (col # tableStart.col) OR (row # tableStart.row) THEN
				tableStart.col := col; tableStart.row := row;
				IF pointerInside THEN FindCellXY(lastPointerX, lastPointerY, highlight.col, highlight.row) END;
				Invalidate();
				IF updateScrollbar THEN scrollx.pos.Set(col); scrolly.pos.Set(row) END
			END;
			Release
		END SetTopPosition;

		PROCEDURE GetTopPosition*(VAR col, row : LONGINT);
		BEGIN
			Acquire;
			col := tableStart.col; row := tableStart.row;
			Release
		END GetTopPosition;

		PROCEDURE ScrollCellVisible(col, row : LONGINT);
		VAR cur : CellPos; r : WMRectangles.Rectangle; w, h: LONGINT;
		BEGIN
			cur := tableStart;
			w := bounds.GetWidth(); h := bounds.GetHeight();
			r := GetVisibleCellRect(col, row);
			WHILE (r.r > w) & (cur.col < col) DO DEC(r.r, GetColWidth(cur.col)); INC(cur.col) END;
			WHILE (r.b > h) & (cur.row < row) DO DEC(r.b, GetRowHeight(cur.row)); INC(cur.row) END;
			cur.col := Strings.Min(cur.col, col);
			cur.row := Strings.Min(cur.row, row);
			SetTopPosition(cur.col, cur.row, TRUE)
		END ScrollCellVisible;

		(* set the focus pos to col, row. The acutal focusCell is the master cell of col, row *)
		PROCEDURE SetFocusPos(col, row : LONGINT);
		VAR oldfocus : CellPos; dummy : LONGINT;
		BEGIN
			IF ~adjustFocusPosition.Get() THEN RETURN; END;
			oldfocus := focus; focus.col := col; focus.row := row;
			FindMasterCell(focus.col, focus.row, focusCell.col, focusCell.row, dummy, dummy);
			InvalidateCell(oldfocus.col, oldfocus.row); InvalidateCell(focusCell.col, focusCell.row);
			ScrollCellVisible(focusCell.col, focusCell.row)
		END SetFocusPos;

		PROCEDURE KeyEvent(ucs : LONGINT; flags: SET; VAR keysym: LONGINT);
			PROCEDURE AdjustSelection;
			BEGIN
				IF shiftDown THEN SetSelection(selA.col, selA.row, focus.col, focus.row)
				ELSE selA := focus; SetSelection(focus.col, focus.row, focus.col, focus.row)
				END
			END AdjustSelection;
		BEGIN
			shiftDown := Inputs.Shift * flags # {};
			IF (keysym = 0FF51H) & (focus.col > fixedColsC) THEN SetFocusPos(focus.col - 1, focus.row); AdjustSelection
			ELSIF (keysym = 0FF53H) & (focus.col < nofColsC - 1) THEN SetFocusPos(focus.col + 1, focus.row); AdjustSelection
			ELSIF (keysym = 0FF52H) & (focus.row > fixedRowsC) THEN SetFocusPos(focus.col, focus.row - 1); AdjustSelection
			ELSIF (keysym = 0FF54H) & (focus.row < nofRowsC - 1) THEN SetFocusPos(focus.col, focus.row + 1); AdjustSelection
			END
		END KeyEvent;

		PROCEDURE Scrolled(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Scrolled, sender, data)
			ELSE
				SetTopPosition(scrollx.pos.Get(), scrolly.pos.Get(), FALSE);
				AlignSubComponents
			END
		END Scrolled;

		PROCEDURE SetHighlight(col, row : LONGINT);
		VAR or, nr, cr : WMRectangles.Rectangle;
		BEGIN
			Acquire;
			IF (col = highlight.col) & (row = highlight.row)
				OR (selectionMode IN {GridSelectSingleCol, GridSelectCols}) & (col = highlight.col)
				OR (selectionMode IN {GridSelectSingleRow, GridSelectRows}) & (row = highlight.row)
			 THEN Release; RETURN
			END;
			CASE selectionMode OF
				| GridSelectSingleCol, GridSelectCols : nr := GetVisibleColRect(col); or := GetVisibleColRect(highlight.col)
				| GridSelectSingleRow, GridSelectRows : nr := GetVisibleRowRect(row); or := GetVisibleRowRect(highlight.row)
			ELSE
				or := GetVisibleCellRect(highlight.col, highlight.row);
				nr := GetVisibleCellRect(col, row);
			END;
			highlight.col := col; highlight.row := row;
			cr := or; WMRectangles.ExtendRect(cr, nr);
			IF WMRectangles.Area(or) + WMRectangles.Area(nr) < WMRectangles.Area(cr) THEN InvalidateRect(or); InvalidateRect(nr)
			ELSE InvalidateRect(cr)
			END;
			Release
		END SetHighlight;

		PROCEDURE GetVisibleColRect(col : LONGINT) : WMRectangles.Rectangle;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := GetVisibleCellRect(col, tableStart.row);
			r.t := 0; r.b := bounds.GetHeight();
			RETURN r
		END GetVisibleColRect;

		PROCEDURE GetVisibleRowRect(row: LONGINT) : WMRectangles.Rectangle;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := GetVisibleCellRect(tableStart.col, row);
			r.l := 0; r.r := bounds.GetWidth();
			RETURN r
		END GetVisibleRowRect;

		PROCEDURE SetSelection*(scol, srow, ecol, erow : LONGINT);
		VAR or, nr, cr : WMRectangles.Rectangle; done : BOOLEAN;
			oldStart, oldEnd : CellPos;
		BEGIN
			Acquire;
			oldStart := selStart; oldEnd := selEnd;
			selStart.col := Strings.Min(scol, ecol); selStart.row := Strings.Min(srow, erow);
			selEnd.col := Strings.Max(scol, ecol); selEnd.row := Strings.Max(srow, erow);
			IF (oldStart.col = selStart.col) & (oldStart.row= selStart.row) &
				(oldEnd.col = selEnd.col) & (oldEnd.row= selEnd.row) THEN
				Release;
				RETURN
			END;

			done := FALSE;
			CASE selectionMode OF
				| GridSelectSingleCell :
					or := GetVisibleCellRect(oldStart.col, oldStart.row); nr := GetVisibleCellRect(selStart.col, selStart.row)
				| GridSelectSingleCol : or := GetVisibleColRect(oldStart.col); nr := GetVisibleColRect(selStart.col)
				| GridSelectSingleRow : or := GetVisibleRowRect(oldStart.row); nr := GetVisibleRowRect(selStart.row)
			ELSE
				Invalidate(); done := TRUE
			END;
			IF ~done THEN
				cr := or; WMRectangles.ExtendRect(cr, nr);
				IF WMRectangles.Area(or) + WMRectangles.Area(nr) < WMRectangles.Area(cr) THEN InvalidateRect(or); InvalidateRect(nr)
				ELSE InvalidateRect(cr)
				END;
			END;
			Release;
			onSelect.Call(NIL)
		END SetSelection;

		(** must be interpreted according to SelectionMode *)
		PROCEDURE GetSelection*(VAR scol, srow, ecol, erow : LONGINT);
		BEGIN
			Acquire;
			scol := selStart.col; srow := selStart.row;
			ecol := selEnd.col; erow := selEnd.row;
			Release
		END GetSelection;

		PROCEDURE OnFixedXGridLine(x, y : LONGINT; VAR xCell, pos : LONGINT) : BOOLEAN;
		VAR ty, tx : LONGINT;
			PROCEDURE Find(startX, endX, startCol, endCol : LONGINT; VAR col, xPos : LONGINT) : BOOLEAN;
			VAR cw : LONGINT;
			BEGIN
				col := startCol; xPos := startX;
				REPEAT
					cw := GetColWidth(col);
					IF ABS(xPos + cw + cellDistC - x) < PixelRange THEN RETURN TRUE END;
					xPos := xPos + cw + cellDistC; INC(col);
				UNTIL (col >= endCol) OR (xPos >= endX);
				RETURN FALSE
			END Find;
		BEGIN
			GetFixedPixels(tx, ty);
			IF (x < tx) & (y < ty) OR (x < tx) THEN (* column fixed *)
				RETURN Find(0, x + PixelRange, 0, fixedColsC, xCell, pos)
			ELSIF (y < ty) THEN  (* row fixed *)
				RETURN Find(tx, x + PixelRange, tableStart.col, nofColsC, xCell, pos)
			ELSE (* normal cells *)
				RETURN FALSE
			END
		END OnFixedXGridLine;

		PROCEDURE OnFixedYGridLine(x, y : LONGINT; VAR yCell, pos : LONGINT) : BOOLEAN;
		VAR ty, tx : LONGINT;
			PROCEDURE Find(startY, endY, startRow, endRow : LONGINT; VAR row, yPos : LONGINT) : BOOLEAN;
			VAR ch : LONGINT;
			BEGIN
				row := startRow; yPos := startY;
				REPEAT
					ch := GetRowHeight(row);
					IF ABS(yPos + ch + cellDistC - y) < PixelRange THEN RETURN TRUE END;
					yPos := yPos + ch + cellDistC; INC(row);
				UNTIL (row >= endRow) OR (yPos >= endY);
				RETURN FALSE
			END Find;
		BEGIN
			GetFixedPixels(tx, ty);
			IF (y < ty) THEN (* column fixed *)
				RETURN Find(0, y + PixelRange, 0, fixedRowsC, yCell, pos)
			ELSIF (x < tx) THEN  (* row fixed *)
				RETURN Find(ty, y + PixelRange, tableStart.row, nofRowsC, yCell, pos)
			ELSE (* normal cells *)
				RETURN FALSE
			END
		END OnFixedYGridLine;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET); (** PROTECTED *)
		VAR col, row : LONGINT; state : SET;
		BEGIN
			PointerDown^(x, y, keys);
			lastkeys := keys;
			IF keys * {0,1} # {} THEN
				IF allowColResize.Get() & (colWidths # NIL) & OnFixedXGridLine(x, y, dragCellSpacingNr, dragCellSpacingPos) THEN
					dragCellSpacingWidth := TRUE;
				ELSIF  allowRowResize.Get() & (rowHeights # NIL) & OnFixedYGridLine(x, y, dragCellSpacingNr, dragCellSpacingPos) THEN
					dragCellSpacingHeight := TRUE;
				ELSE
					FindCellXY(x, y, col, row);
					state := GetCellState(col, row);
					wasSelected := CellSelected IN state;
					IF shiftDown & (0 IN keys) THEN
						SetSelection(selA.col, selA.row, col, row);
						dragPossible := FALSE; selecting := TRUE
					ELSE
						IF CellSelected IN state THEN selecting := FALSE; dragPossible := TRUE; downX := x; downY := y
						ELSE
							dragPossible := FALSE; selecting := TRUE;
							selA.col := col; selA.row := row; SetFocusPos(col, row);
							SetSelection(col, row, col, row)
						END
					END
				END
			END
		END PointerDown;

		PROCEDURE PointerLeave;
		BEGIN
			SetHighlight(-1, -1); pointerInside := FALSE
		END PointerLeave;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		VAR col, row : LONGINT; manager : WM.WindowManager; cell, pos : LONGINT;
		BEGIN
			IF dragCellSpacingWidth THEN
				x := Strings.Min(x, bounds.GetWidth());
				IF (colWidths # NIL) & (dragCellSpacingNr < LEN(colWidths)) THEN
					colWidths[dragCellSpacingNr] := Strings.Max(x - dragCellSpacingPos, 1);
					Invalidate()
				END;
			ELSIF dragCellSpacingHeight THEN
				y := Strings.Min(y, bounds.GetHeight());
				IF (rowHeights # NIL) & (dragCellSpacingNr < LEN(rowHeights)) THEN
					rowHeights[dragCellSpacingNr] := Strings.Max(y - dragCellSpacingPos, 1);
					Invalidate()
				END;
			ELSIF dragPossible THEN
				IF (ABS(x - downX) > DragDist) OR (ABS(y - downY) > DragDist) THEN
					dragPossible := FALSE;
					drag := TRUE;
					AutoStartDrag
				END
			ELSE
				FindCellXY(x, y, col, row); pointerInside := TRUE; lastPointerX := x; lastPointerY := y;
				IF allowColResize.Get() & (colWidths # NIL) & OnFixedXGridLine(x, y, cell, pos) THEN
					IF ~hasOldPointer THEN
						prevPointerInfo := GetPointerInfo();
						hasOldPointer := TRUE;
						manager := WM.GetDefaultManager();
						SetPointerInfo(manager.pointerLeftRight)
					END;
				ELSIF allowRowResize.Get() & (rowHeights # NIL) & OnFixedYGridLine(x, y, cell, pos) THEN
					IF ~hasOldPointer THEN
						prevPointerInfo := GetPointerInfo();
						hasOldPointer := TRUE;
						manager := WM.GetDefaultManager();
						SetPointerInfo(manager.pointerUpDown)
					END;
				ELSE
					IF hasOldPointer THEN SetPointerInfo(prevPointerInfo); hasOldPointer := FALSE END;
				END;

				IF selecting THEN
					IF 0 IN keys THEN
						CASE selectionMode OF
							| GridSelectSingleCell, GridSelectSingleCol, GridSelectSingleRow : SetSelection(col, row, col, row)
							| GridSelectCols, GridSelectRows, GridSelectBlock, GridSelectHorizontal, GridSelectVertical:
									SetSelection(selA.col, selA.row, col, row)
						ELSE
						END;
						SetFocusPos(col, row)
					END
				END;
				IF selectOnPointerOver THEN SetSelection(col, row, col, row) END;
				SetHighlight(col, row)
			END;
			IF keys = {} THEN dragPossible := FALSE; selecting := FALSE END
		END PointerMove;

		PROCEDURE CellClicked*(col, row : LONGINT); (** PROTECTED *)
		BEGIN
			IF wasSelected & onClickSelected.HasListeners() THEN
				dragPossible := FALSE;
				onClickSelected.Call(GetCellData(col, row))
			END;
			IF onClick.HasListeners() THEN
				onClick.Call(GetCellData(col, row))
			END
		END CellClicked;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET); (** PROTECTED *)
		VAR col, row : LONGINT; d : BOOLEAN;
		BEGIN
			IF 2 IN lastkeys THEN lastkeys := keys; RETURN END;
			d := dragCellSpacingWidth OR dragCellSpacingHeight OR
				(selecting & (selStart.row # selEnd.row) OR (selStart.col # selEnd.col));
			IF ~d THEN
				FindCellXY(x, y, col, row);
				SetSelection(col, row, col, row); SetFocusPos(col, row);
				IF ~drag THEN CellClicked(col, row) END
			END;
			drag := FALSE;
			dragCellSpacingWidth := FALSE; dragCellSpacingHeight := FALSE;
			selecting := FALSE
		END PointerUp;

		PROCEDURE WheelMove*(dz: LONGINT); (** PROTECTED *)
		VAR t, l : LONGINT;
		BEGIN
			GetTopPosition(l, t); t := t + dz; SetTopPosition(l, t, TRUE)
		END WheelMove;

	END GenericGrid;

VAR
	GSonSelect, GSonClick, GSonClickSelected,
	GSonSelectInfo, GSonClickInfo, GSonClickSelectedInfo: String;
	GSGenericGrid : String;
	fixedColsProto, fixedRowsProto : WMProperties.Int32Property;
	defaultColWidthProto, defaultRowHeightProto : WMProperties.Int32Property;
	allowColResizeProto, allowRowResizeProto, adjustFocusPositionProto : WMProperties.BooleanProperty;
	nofColsProto, nofRowsProto, cellDistProto : WMProperties.Int32Property;
	showScrollXProto, showScrollYProto, alwaysShowScrollXProto, alwaysShowScrollYProto : WMProperties.BooleanProperty;

PROCEDURE Init;
BEGIN
	GSonSelect := NewString("onSelect");
	GSonClick := NewString("onClick");
	GSonClickSelected := NewString("onClickSelected");
	GSonSelectInfo := NewString("Is called when a cell is selected");
	GSonClickInfo := NewString("is called on a click");
	GSonClickSelectedInfo := NewString("is called when a selected cell is clicked");
	GSGenericGrid := NewString("GenericGrid");
END Init;

PROCEDURE InitProto;
BEGIN
	NEW(fixedColsProto, NIL, NewString("fixedCols"), NewString("number of fixed columns"));
	NEW(fixedRowsProto, NIL, NewString("fixedRows"), NewString("number of fixed rows"));
	NEW(defaultColWidthProto, NIL, NewString("defaultColWidth"), NewString("default width of a column"));
	NEW(defaultRowHeightProto, NIL, NewString("defaultRowHeight"), NewString("default height of a row"));
	defaultColWidthProto.Set(100); defaultRowHeightProto.Set(20);
	NEW(allowColResizeProto, NIL, NewString("allowColResize"), NewString("can columns be resized"));
	allowColResizeProto.Set(TRUE);
	NEW(allowRowResizeProto, NIL, NewString("allowRowResize"), NewString("can rows be resized"));
	allowRowResizeProto.Set(TRUE);
	NEW(adjustFocusPositionProto, NIL, NewString("adjustFocusPosition"), NewString("focus adjusting when clicking/dragging cells"));
	adjustFocusPositionProto.Set(TRUE);
	NEW(nofColsProto, NIL, NewString("nofCols"), NewString("number of columns in the table"));
	nofColsProto.Set(1);
	NEW(nofRowsProto, NIL, NewString("nofRows"), NewString("number of rows in the table"));
	nofRowsProto.Set(1);
	NEW(cellDistProto, NIL, NewString("cellDist"), NewString("distance between cells"));
	cellDistProto.Set(1);
	NEW(showScrollXProto, NIL, NewString("showScrollX"), NewString("horizontal scrollbar is displayed if needed"));
	showScrollXProto.Set(TRUE);
	NEW(showScrollYProto, NIL, NewString("showScrollY"), NewString("vertical scrollbar is displayed if needed"));
	showScrollYProto.Set(TRUE);
	NEW(alwaysShowScrollXProto, NIL, NewString("alwaysShowScrollX"), NewString("horizontal scrollbar is always displayed"));
	NEW(alwaysShowScrollYProto, NIL, NewString("alwaysShowScrollY"), NewString("vertical scrollbar is always displayed"));
END InitProto;

PROCEDURE GenGrid*() : XML.Element;
VAR grid : GenericGrid;
BEGIN
	NEW(grid);
	RETURN grid
END GenGrid;

PROCEDURE NewString*(CONST x : ARRAY OF CHAR) : String;
BEGIN
	RETURN Strings.NewString(x)
END NewString;

BEGIN
	Init;
	InitProto;
END WMGrids.

SystemTools.Free WMGrids ~

History:

	03.04.2006	Added AlignSubComponents in last line for GenericGrid.RecacheAllProperties

