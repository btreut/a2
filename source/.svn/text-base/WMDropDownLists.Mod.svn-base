MODULE WMDropDownLists; (** AUTHOR "staubesv"; PURPOSE "DropDownList widget"; *)
(*
	TODO:
		- editor field should get cursor focus back when the drop down list window is closed
		- make key accessible so the result of a selection can be a key (~constant)
		- DropDownListModel could support sorting of list entries, maybe timestamps and usage counters for dynamic lists (e.g. recently/often used)
		- Maybe split the non-editable drop down list into a separate object so it can never become editable
*)


IMPORT
	Objects, Inputs, Strings, XML,
	WMRectangles, WMGraphics, WMGraphicUtilities, WMProperties, WMEvents, WMWindowManager, WMComponents, WMStandardComponents,
	WMEditors, WMGrids, WMStringGrids;

CONST
	(** Operation modes for DropDownList *)
	Mode_SelectOnly* = 0;	(** The user can only select one of the list entries. The field is not editable *)
	Mode_Editable* = 1;		(** The user can select items from the list and/or edit the text field *)
	Mode_Eager* = 2;		(** The user can select items from the list and/or edit the text field. The DropDownList will open whenever the text field content matches a list item's name *)

	(** DropDownListModel Add and Remove result codes *)
	Ok* = 0;
	NotFound* = 1;
	DuplicateEntry* = 2;

	(** Entry has no key *)
	NoKey* = MIN(LONGINT);

	InitialEntryArraySize = 4;
	ShadowWidth = 5;

TYPE

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		grid : WMStringGrids.StringGrid;
		dropDownList : DropDownList;
		isClosed : BOOLEAN;
		shadowRect, borderRect : WMRectangles.Rectangle;

		PROCEDURE&New(x, y, width, height : LONGINT; grid : WMStringGrids.StringGrid; dropDownList : DropDownList);
		BEGIN
			ASSERT((width > 0) & (height > 0) & (grid # NIL) & (dropDownList # NIL));
			SELF.grid := grid;
			SELF.dropDownList := dropDownList;
			isClosed := FALSE;

			Init(width, height, TRUE);

			grid.bearing.Set(WMRectangles.MakeRect(1, 1, ShadowWidth, ShadowWidth));
			grid.alignment.Set(WMComponents.AlignClient);
			grid.onClick.Add(Clicked);

			SetContent(grid);

			borderRect := WMRectangles.MakeRect(0, 0, width - ShadowWidth, height - ShadowWidth);
			shadowRect := WMRectangles.MakeRect(ShadowWidth, ShadowWidth, width, height);

			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagStayOnTop, WMWindowManager.FlagHidden});
			manager.SetFocus(SELF);
			CSChanged;
		END New;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; w, h, q : LONGINT); (** override *)
		BEGIN
			canvas.Fill(shadowRect, 04FH, WMGraphics.ModeSrcOverDst);
			Draw^(canvas, w, h, q);
			WMGraphicUtilities.DrawRect(canvas, borderRect, WMGraphics.Black, WMGraphics.ModeCopy);
		END Draw;

		PROCEDURE Clicked(sender, data : ANY);
		BEGIN
			PropagateSelection;
			Close;
		END Clicked;

		PROCEDURE PropagateSelection;
		VAR scol, srow, ecol, erow : LONGINT; ptr : ANY;
		BEGIN
			grid.GetSelection(scol, srow, ecol, erow);
			 IF (srow # -1) THEN
			 	grid.model.Acquire;
			 	ptr := grid.model.GetCellData(0, srow);
			 	grid.model.Release;
			 	IF (ptr # NIL) & (ptr IS Entry) THEN
				 	dropDownList.SetSelection(ptr(Entry));
				 ELSE
				 	dropDownList.SetSelection(NIL);
				 END;
			 END;
		END PropagateSelection;

		PROCEDURE Close;
		BEGIN
			Close^;
			isClosed := TRUE;
			dropDownList.editor.tv.alwaysShowCursor.Set(FALSE);
		END Close;

		PROCEDURE SelectEntry(next : BOOLEAN);
		VAR selectRow, scol, srow, ecol, erow, nofRows : LONGINT;
		BEGIN
			grid.GetSelection(scol, srow, ecol, erow);
			IF (srow # -1) THEN
				selectRow := srow;
				grid.model.Acquire;
				nofRows := grid.model.GetNofRows();
				grid.model.Release;
				IF next THEN
					IF (srow < nofRows-1) THEN INC(selectRow); END;
				ELSE
					IF (srow > 0) THEN DEC(selectRow); END;
				END;
			ELSE
				selectRow := 0;
			END;
			IF (srow # selectRow) THEN grid.SetSelection(0, selectRow, 0, selectRow); END;
		END SelectEntry;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT); (* override *)
		VAR handled : BOOLEAN;
		BEGIN
			IF ~(Inputs.Release IN flags) THEN
				IF keysym = 0FF54H THEN (* Cursor Down *)
					SelectEntry(TRUE);
				ELSIF keysym = 0FF52H THEN (* Cursor Up *)
					SelectEntry(FALSE);
				ELSIF (keysym = Inputs.KsTab) OR (keysym = Inputs.KsReturn) THEN
					Clicked(NIL, NIL);
				ELSIF (keysym = Inputs.KsEscape) THEN
					Close;
				ELSE
					dropDownList.KeyPressed(ucs, flags, keysym, handled);
				END;
			ELSE
				dropDownList.KeyPressed(ucs, flags, keysym, handled);
			END;
		END KeyEvent;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			Close;
		END FocusLost;

	END Window;

TYPE

	Entry* = POINTER TO RECORD
		key- : LONGINT;
		name- : Strings.String;
	END;

	EntryArray = POINTER TO ARRAY OF Entry;

	EnumeratorProcedure* = PROCEDURE {DELEGATE} (entry : Entry; index : LONGINT);

TYPE

	DropDownListModel* = OBJECT
	VAR
		onChanged- : WMEvents.EventSource; (** does not hold the lock, if called *)

		(* all fields below are private! *)
		entries : EntryArray;
		nofEntries : LONGINT;

		lockLevel : LONGINT;
		lockedBy : ANY;
		viewChanged : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			NEW(onChanged, SELF, Strings.NewString("DropDownListModelChanged"), NIL, NIL);
			NEW(entries, InitialEntryArraySize);
			nofEntries := 0;
			lockLevel := 0;
			lockedBy := NIL;
			viewChanged := FALSE;
		END Init;

		(** acquire a read/write lock on the object *)
		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			IF lockedBy = me THEN
				ASSERT(lockLevel # -1);	(* overflow *)
				INC(lockLevel)
			ELSE
				AWAIT(lockedBy = NIL); viewChanged := FALSE;
				lockedBy := me; lockLevel := 1
			END
		END Acquire;

		(** release the read/write lock on the object *)
		PROCEDURE Release*;
		VAR hasChanged : BOOLEAN;
		BEGIN
			BEGIN {EXCLUSIVE}
				ASSERT(lockedBy = Objects.ActiveObject(), 3000);
				hasChanged := FALSE;
				DEC(lockLevel);
				IF lockLevel = 0 THEN lockedBy := NIL; hasChanged := viewChanged END
			END;
			IF hasChanged THEN onChanged.Call(NIL) END
		END Release;

		PROCEDURE GetNofEntries*() : LONGINT;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			RETURN nofEntries;
		END GetNofEntries;

		PROCEDURE Add*(key : LONGINT; CONST name : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN
			Acquire;
			IF (FindDuplicate(key, name) = NIL) THEN
				IF (nofEntries = LEN(entries)) THEN ResizeEntryArray; END;
				NEW(entries[nofEntries]);
				entries[nofEntries].key := key;
				entries[nofEntries].name := Strings.NewString(name);
				INC(nofEntries);
				viewChanged := TRUE;
				res := Ok;
			ELSE
				res := DuplicateEntry;
			END;
			Release;
		END Add;

		PROCEDURE Remove*(CONST name : ARRAY OF CHAR; VAR res : LONGINT);
		VAR i : LONGINT;
		BEGIN
			Acquire;
			IF (nofEntries > 0) THEN
				i := 0; WHILE (i < nofEntries) & (entries[i].name^ # name) DO INC(i); END;
				IF (i < nofEntries) THEN
					IF (i = nofEntries-1) THEN
						entries[i] := NIL;
					ELSE
						entries[i] := entries[nofEntries-1];
					END;
					DEC(nofEntries);
					res := Ok;
					viewChanged := TRUE;
				ELSE
					res := NotFound;
				END;
			END;
			Release;
		END Remove;

		PROCEDURE Enumerate*(CONST mask : ARRAY OF CHAR; proc : EnumeratorProcedure);
		VAR index, i : LONGINT;
		BEGIN
			ASSERT(proc # NIL);
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			index := 0;
			FOR i := 0 TO nofEntries-1 DO
				IF Strings.Match(mask, entries[i].name^) THEN proc(entries[i], index); INC(index); END;
			END;
		END Enumerate;

		PROCEDURE GetNofMatches*(CONST mask : ARRAY OF CHAR) : LONGINT;
		VAR nofMatches, i : LONGINT;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			nofMatches := 0;
			FOR i := 0 TO nofEntries-1 DO
				IF Strings.Match(mask, entries[i].name^) THEN INC(nofMatches); END;
			END;
			RETURN nofMatches;
		END GetNofMatches;

		(** Returns the first entry with the specified key and/or name. *)
		PROCEDURE FindDuplicate*(key : LONGINT; CONST name : ARRAY OF CHAR) : Entry;
		VAR entry : Entry; i : LONGINT;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			entry := NIL;
			i := 0;
			WHILE (i < nofEntries) & ((entries[i].key # key) OR (entries[i].key = NoKey)) & (entries[i].name^ # name) DO INC(i); END;
			IF (i < nofEntries) THEN entry := entries[i]; END;
			RETURN entry;
		END FindDuplicate;

		PROCEDURE FindByName*(CONST name : ARRAY OF CHAR) : Entry;
		VAR entry : Entry; i : LONGINT;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			entry := NIL;
			i := 0;
			WHILE (i < nofEntries) & (entries[i].name^ # name) DO INC(i); END;
			IF (i < nofEntries) THEN entry := entries[i]; END;
			RETURN entry;
		END FindByName;

		PROCEDURE FindByKey*(key : LONGINT) : Entry;
		VAR entry : Entry; i : LONGINT;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject(), 3000);
			entry := NIL;
			i := 0;
			WHILE (i < nofEntries) & (entries[i].key # key) DO INC(i); END;
			IF (i < nofEntries) THEN entry := entries[i]; END;
			RETURN entry;
		END FindByKey;

		PROCEDURE ResizeEntryArray; (* private *)
		VAR newEntries : EntryArray; i : LONGINT;
		BEGIN
			NEW(newEntries, 2 * LEN(entries));
			FOR i := 0 TO LEN(entries)-1 DO newEntries[i] := entries[i]; END;
			entries := newEntries;
		END ResizeEntryArray;

	END DropDownListModel;

TYPE

	DropDownList* = OBJECT(WMComponents.VisualComponent)
	VAR
		mode- : WMProperties.Int32Property;
		textColor- : WMProperties.ColorProperty;
		minGridWidth- : WMProperties.Int32Property;
		maxGridHeight- : WMProperties.Int32Property;

		model- : DropDownListModel;

		onSelect- : WMEvents.EventSource;
		selectedEntry : Entry;

		window : Window;
		grid : WMStringGrids.StringGrid;

		button : WMStandardComponents.Button;
		editor : WMEditors.Editor;

		captionI : Strings.String;

		currentMask : ARRAY 128 OF CHAR; (* protected by model.Acquire/Release *)
		nofMatches : LONGINT;

		PROCEDURE &Init*;  (* override *)
		BEGIN
			Init^;
			SetNameAsString(StrDropDownList);

			NEW(mode, PrototypeMode, NIL, NIL); properties.Add(mode);
			NEW(textColor, PrototypeTextColor, NIL, NIL); properties.Add(textColor);
			NEW(minGridWidth, PrototypeMinGridWidth, NIL, NIL); properties.Add(minGridWidth);
			NEW(maxGridHeight, PrototypeMaxGridHeight, NIL, NIL); properties.Add(maxGridHeight);

			NEW(model); model.onChanged.Add(ModelChanged);
			NEW(onSelect, NIL, NIL, NIL, NIL); events.Add(onSelect);
			selectedEntry := NIL;

			window := NIL;
			NEW(grid); InitGrid;

			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.caption.SetAOC("^");
			button.bounds.SetWidth(14);
			button.onClick.Add(ShowDropDownList);
			AddInternalComponent(button);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.multiLine.Set(FALSE);
			editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editor.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1));
			editor.tv.showBorder.Set(TRUE);
			editor.tv.SetExtKeyEventHandler(KeyPressed);
			editor.text.onTextChanged.Add(TextChanged);
			AddInternalComponent(editor);

			captionI := NIL;
			currentMask := "*";
			nofMatches := 0;

			mode.Set(Mode_Eager);
			SetMode(Mode_Eager);
			
			SetGenerator("WMDropDownLists.GenDropDownList");
		END Init;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			SetMode(mode.Get());
		END Initialize;

		PROCEDURE Finalize; (* override *)
		BEGIN
			Finalize^;
			model.onChanged.Remove(ModelChanged);
			editor.text.onTextChanged.Remove(TextChanged);
			IF (window # NIL) & ~(window.isClosed) THEN window.Close; window := NIL; END;
		END Finalize;

		(* Called by window when the user selects an entry *)
		PROCEDURE SetSelection*(entry : Entry);
		BEGIN
			Acquire;
			IF (entry # selectedEntry) THEN
				selectedEntry := entry;
				IF (entry # NIL) THEN
					editor.SetAsString(entry.name^); ELSE editor.SetAsString("");
				END;
				Invalidate;
				Release;
				onSelect.Call(selectedEntry);
			ELSE
				Release;
			END;
		END SetSelection;

		PROCEDURE SelectKey*(key : LONGINT);
		VAR e : Entry;
		BEGIN
			model.Acquire;
			e := model.FindByKey(key);
			model.Release;
			SetSelection(e);
		END SelectKey;

		PROCEDURE GetSelection*() : Entry;
		VAR e : Entry;
		BEGIN
			Acquire;
			e := selectedEntry;
			Release;
			RETURN e;
		END GetSelection;

		PROCEDURE SetModel*(model : DropDownListModel);
		BEGIN {EXCLUSIVE}
			ASSERT(model # NIL);
			SELF.model.onChanged.Remove(ModelChanged);
			SELF.model := model;
			model.onChanged.Add(ModelChanged);
			UpdateGrid;
		END SetModel;

		PROCEDURE TextChanged(sender, data : ANY);
		BEGIN
			IF (mode.Get() = Mode_Eager) THEN
				model.Acquire;
				editor.GetAsString(currentMask);
				Strings.Append(currentMask, "*");
				nofMatches := model.GetNofMatches(currentMask);
				model.Release;
				UpdateGrid;
				IF (nofMatches > 0) THEN
					ShowDropDownList(NIL, NIL);
				ELSIF (window # NIL) & ~window.isClosed THEN
					window.Close;
				END;
			END;
		END TextChanged;

		PROCEDURE ModelChanged(sender, data : ANY);
		VAR e : Entry;
		BEGIN
			Acquire;
			IF (selectedEntry # NIL) THEN
				model.Acquire;
				e := model.FindDuplicate(e.key, e.name^);
				model.Release;
				IF e # NIL THEN SetSelection(NIL); END;
			END;
			Release;
			UpdateGrid;
		END ModelChanged;

		PROCEDURE KeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			IF ~(Inputs.Release IN flags) THEN
				IF (keySym = 0FF54H) OR (keySym = 0FF52H) THEN (* Cursor Down/Up *)
					ShowDropDownList(NIL, NIL);
				ELSIF ((keySym = Inputs.KsTab) OR (keySym = Inputs.KsReturn)) & (window # NIL) & ~window.isClosed THEN
					window.Clicked(NIL, NIL); window.Close;
				ELSIF (keySym = Inputs.KsEscape) THEN
					window.Close;
				ELSE
					editor.KeyPressed(ucs, flags, keySym, handled);
				END;
			ELSE
				editor.KeyPressed(ucs, flags, keySym, handled);
			END;
		END KeyPressed;

		PROCEDURE ShowDropDownList(sender, data : ANY);
		VAR gx, gy : LONGINT; width, height : LONGINT;  rect : WMRectangles.Rectangle;
		BEGIN
			IF (window = NIL) OR (window.isClosed) THEN
				rect := GetClientRect();
				ToWMCoordinates(rect.l, rect.b, gx, gy);
				IF (nofMatches > 0) THEN height := 20 * (nofMatches + 1); ELSE height := 20;  END;
				width := rect.r - rect.l + ShadowWidth;
				IF (width < minGridWidth.Get()) THEN width := minGridWidth.Get(); END;
				IF (height > maxGridHeight.Get()) THEN height := maxGridHeight.Get(); END;
				IF (mode.Get() # Mode_SelectOnly) THEN editor.tv.alwaysShowCursor.Set(TRUE); END;
				NEW(window, gx, gy, width, height, grid, SELF);
			END;
		END ShowDropDownList;

		PROCEDURE InitGrid;
		BEGIN
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.model.Release;
			grid.Release;
			grid.fillColor.Set(WMGraphics.White);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
		END InitGrid;

		PROCEDURE AddRow(entry : Entry; index : LONGINT);
		BEGIN (* has grid.model locked *)
			grid.model.SetCellText(0, index, entry.name);
			grid.model.SetCellData(0, index, entry);
		END AddRow;

		PROCEDURE UpdateGrid;
		VAR nofMatches : LONGINT;
		BEGIN
			grid.Acquire;
			grid.model.Acquire;
			model.Acquire;
			nofMatches := model.GetNofMatches(currentMask);
			SELF.nofMatches := nofMatches;
			IF (nofMatches > 0) THEN
				grid.model.SetNofRows(nofMatches);
				model.Enumerate(currentMask, AddRow);
			ELSE
				grid.model.SetNofRows(1);
				grid.model.SetCellText(0, 0, Strings.NewString(""));
			END;
			model.Release;
			grid.model.Release;
			grid.Release;
		END UpdateGrid;

		PROCEDURE PropertyChanged(sender, property : ANY); (* override *)
		BEGIN
			IF (property = textColor) THEN
				Invalidate;
			ELSIF (property = mode) THEN
				SetMode(mode.Get());
				Invalidate;
			ELSIF (property = minGridWidth) OR (property = maxGridHeight) THEN
				IF (window # NIL) & ~window.isClosed THEN
					window.Close;
					ShowDropDownList(NIL, NIL);
				END;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE SetMode(mode : LONGINT);
		BEGIN
			ASSERT((mode = Mode_SelectOnly) OR (mode = Mode_Editable) OR (mode = Mode_Eager));
			CASE mode OF
				|Mode_SelectOnly:
					editor.readOnly.Set(TRUE);
					editor.enabled.Set(FALSE);
				|Mode_Editable:
					editor.readOnly.Set(FALSE);
					editor.takesFocus.Set(TRUE);
				|Mode_Eager:
					editor.readOnly.Set(FALSE);
					editor.takesFocus.Set(TRUE);
			ELSE
				HALT(100);
			END;
		END SetMode;

	END DropDownList;

VAR
	StrDropDownList : Strings.String;
	PrototypeTextColor : WMProperties.ColorProperty;
	PrototypeMode, PrototypeMinGridWidth, PrototypeMaxGridHeight : WMProperties.Int32Property;
	PrototypeIsEditable : WMProperties.BooleanProperty;

PROCEDURE GenDropDownList*() : XML.Element;
VAR dropDownList : DropDownList;
BEGIN
	NEW(dropDownList); RETURN dropDownList;
END GenDropDownList;

PROCEDURE Init;
BEGIN
	StrDropDownList := Strings.NewString("DropDownList");
	NEW(PrototypeTextColor, NIL, Strings.NewString("TextColor"), Strings.NewString("text color"));
	PrototypeTextColor.Set(WMGraphics.Black);
	NEW(PrototypeMode, NIL, Strings.NewString("Mode"), Strings.NewString("operation mode for drop down list"));
	NEW(PrototypeMinGridWidth, NIL, Strings.NewString("MinGridWidth"), Strings.NewString("minimum width of selection grid"));
	PrototypeMinGridWidth.Set(100);
	NEW(PrototypeMaxGridHeight, NIL, Strings.NewString("MaxGridHeight"), Strings.NewString("maximum height of selection grid"));
	PrototypeMaxGridHeight.Set(100);
	NEW(PrototypeIsEditable, NIL, Strings.NewString("IsEditable"), Strings.NewString("is the user allowed to insert text into the editor?"));
	PrototypeIsEditable.Set(TRUE);
END Init;

BEGIN
	Init;
END WMDropDownLists.