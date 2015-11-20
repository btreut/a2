MODULE WMDiagnostics; (** AUTHOR "staubesv"; PURPOSE "Visual Component for Diagnostics Interface"; *)

IMPORT
	Locks, Strings, Diagnostics, Files,
	WMRectangles, WMGraphics, WMGraphicUtilities, WMBitmapFont,
	WMEvents, WMProperties, WMGrids, WMTextView;

CONST
	TypeInformation* = Diagnostics.TypeInformation;
	TypeWarning* = Diagnostics.TypeWarning;
	TypeError* = Diagnostics.TypeError;

	Invalid* = Diagnostics.Invalid;

	(* Error grid colors *)
	ColorError = LONGINT(0FF3030A0H);
	ColorWarning = LONGINT(0D0D040C0H);
	ColorPCPosition = 0007F00A0H;

	(* Textview position marker pictures *)
	PictureError = "PETIcons.tar://errorpos.png";
	PictureWarning = "PETIcons.tar://warningpos.png";
	PicturePCPosition = "PETIcons.tar://pcpos.png";

	InitialArraySize = 16;

	Less = -1;
	Equal = 0;
	Greater = 1;

	SortByTypeAscending* = 0;
	SortByTypeDescending* = 1;
	SortByPositionAscending* = 2;
	SortByPositionDescending* = 3;
	SortByErrorCodeAscending* = 4;
	SortByErrorCodeDescending* = 5;

TYPE

	Entry* = RECORD
		type- : LONGINT;
		source- : Files.FileName;
		position-, errorCode- : LONGINT;
		message- : ARRAY 256 OF CHAR;
	END;

	EntryArray = POINTER TO ARRAY OF Entry;

TYPE

	Model* = OBJECT(Diagnostics.Diagnostics)
	VAR
		entries : EntryArray;
		nofEntries- : LONGINT;

		nofInformations: LONGINT;
		nofWarnings : LONGINT;
		nofErrors : LONGINT;

		lock : Locks.RWLock;

		onChanged- : WMEvents.EventSource;
		changed : BOOLEAN;
		notificationEnabled : BOOLEAN;

		PROCEDURE &Init*; (** proctected *)
		BEGIN
			entries := NIL;
			nofEntries := 0;
			nofErrors := 0; nofWarnings := 0; nofInformations := 0;
			NEW(lock);
			NEW(onChanged, NIL, NIL, NIL, NIL);
			changed := FALSE;
			notificationEnabled := TRUE;
		END Init;

		(** Inform views about updates *)
		PROCEDURE EnableNotification*;
		BEGIN
			AcquireWrite;
			notificationEnabled := TRUE;
			ReleaseWrite;
		END EnableNotification;

		(** Don't inform views about updates *)
		PROCEDURE DisableNotification*;
		BEGIN
			AcquireWrite;
			notificationEnabled := FALSE;
			ReleaseWrite;
		END DisableNotification;

		(** Acquire read lock. *)
		PROCEDURE AcquireRead*;
		BEGIN
			lock.AcquireRead;
		END AcquireRead;

		(** Release read lock *)
		PROCEDURE ReleaseRead*;
		BEGIN
			lock.ReleaseRead;
		END ReleaseRead;

		(** Acquire write lock *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite;
		END AcquireWrite;

		(** Release write lock. If the data has changed, all listeners will be notified when the last
			writer releases its lock *)
		PROCEDURE ReleaseWrite*;
		VAR notifyListeners : BOOLEAN;
		BEGIN
			(* If the last writer releases the lock and the model data has changed, we have to notify interested listeners *)
			notifyListeners := notificationEnabled & (lock.GetWLockLevel() = 1) & changed;
			IF notificationEnabled THEN changed := FALSE; END;
			lock.ReleaseWrite;
			IF notifyListeners THEN
				onChanged.Call(SELF);
			END;
		END ReleaseWrite;

		(** Dispose all entries *)
		PROCEDURE Clear*;
		BEGIN
			AcquireWrite;
			changed := changed OR (entries # NIL) OR (nofEntries # 0) OR (nofErrors # 0) OR (nofWarnings # 0) OR (nofInformations # 0);
			entries := NIL;
			nofEntries := 0;
			nofErrors := 0; nofWarnings := 0; nofInformations := 0;
			ReleaseWrite;
		END Clear;

		(* Make sure that <entries> cannot hold at least one more entry *)
		PROCEDURE CheckEntriesSize;
		VAR newEntries : EntryArray; i : LONGINT;
		BEGIN
			ASSERT(lock.HasWriteLock());
			IF (entries = NIL) THEN
				NEW(entries, InitialArraySize);
			ELSIF (nofEntries >= LEN(entries)) THEN
				NEW(newEntries, 2 * LEN(entries));
				FOR i := 0 TO nofEntries - 1 DO
					newEntries[i] := entries[i];
				END;
				entries := newEntries;
			END;
		END CheckEntriesSize;

		PROCEDURE Error*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			Add(TypeError, source, position, errorCode, message, nofErrors)
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			Add(TypeWarning, source, position, errorCode, message, nofWarnings);
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			Add(TypeInformation, source, position, errorCode, message, nofInformations);
		END Information;

		PROCEDURE Exists(type, position, errorCode : LONGINT; CONST message: ARRAY OF CHAR) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofEntries) & ((entries[i].type # type) OR (entries[i].position # position) OR (entries[i].errorCode # errorCode) OR (entries[i].message # message)) DO
				INC(i);
			END;
			RETURN (nofEntries > 0) & (i < nofEntries);
		END Exists;

		PROCEDURE Add(type: LONGINT; CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR; VAR counter: LONGINT);
		BEGIN
			AcquireWrite;
			IF ~Exists(type, position, errorCode,message) THEN
				CheckEntriesSize;
				entries[nofEntries].type := type;
				COPY(source, entries[nofEntries].source);
				entries[nofEntries].position := position;
				entries[nofEntries].errorCode := errorCode;
				COPY(message, entries[nofEntries].message);
				INC(nofEntries); INC(counter);
				changed := TRUE;
			END;
			ReleaseWrite;
		END Add;

		(* Returns a string summarizing the number of errors and warnings *)
		PROCEDURE GetSummary(VAR summary : ARRAY OF CHAR);
		VAR nbr : ARRAY 8 OF CHAR;
		BEGIN
			AcquireRead;
			summary := "";
			IF (nofErrors > 0) THEN
				Strings.IntToStr(nofErrors, nbr); Strings.Append(summary, nbr);
				Strings.Append(summary, " error");
				IF (nofErrors > 1) THEN
					Strings.Append(summary, "s");
				END;
			ELSE
				summary := "no errors";
			END;

			IF (nofWarnings > 0) THEN
				Strings.Append(summary, ", "); Strings.IntToStr(nofWarnings, nbr);
				Strings.Append(summary, nbr);
				Strings.Append(summary, " warning");
				IF (nofWarnings > 1) THEN
					Strings.Append(summary, "s");
				END;
			END;
			ReleaseRead;
		END GetSummary;

		PROCEDURE Synchronize(VAR entries : ViewEntryArray; VAR nofEntries : LONGINT);
		VAR dest : LONGINT;

			PROCEDURE Insert(type: LONGINT);
			VAR i: LONGINT;
			BEGIN
				FOR i := 0 TO nofEntries - 1 DO
					IF SELF.entries[i].type = type THEN
						entries[dest].type := SELF.entries[i].type;
						entries[dest].position := SELF.entries[i].position;
						entries[dest].errorCode := SELF.entries[i].errorCode;
						entries[dest].source := SELF.entries[i].source;
						entries[dest].message := SELF.entries[i].message;
						INC(dest);
					END;
				END;
			END Insert;

		BEGIN
			AcquireRead;
			IF (SELF.entries = NIL) THEN
				nofEntries := 0;
			ELSE
				IF (entries = NIL) OR (LEN(SELF.entries) > LEN(entries)) THEN NEW(entries, LEN(SELF.entries)); END;
				nofEntries := SELF.nofEntries;
				Insert(Diagnostics.TypeError);
				Insert(Diagnostics.TypeWarning);
				Insert(Diagnostics.TypeInformation);
			END;
			ReleaseRead;
		END Synchronize;

	END Model;

TYPE

	CompareProcedure = PROCEDURE(CONST entry1, entry2 : Entry) : LONGINT;


	ViewEntry* = RECORD (Entry)
		pos- : POINTER TO ARRAY OF WMTextView.PositionMarker;
	END;

	ViewEntryArray = POINTER TO ARRAY OF ViewEntry;

	CellInfo* = OBJECT(WMGrids.CellPositionInfo)
	VAR
		entryValid- : BOOLEAN;
		entry- : ViewEntry;

		PROCEDURE &Init(entryValid : BOOLEAN; CONST entry : ViewEntry; column, row : LONGINT);
		BEGIN
			SELF.entryValid := entryValid;
			SELF.entry := entry;
			pos.col := column;
			pos.row := row;
		END Init;

	END CellInfo;

TYPE

	DiagnosticsView* = OBJECT(WMGrids.GenericGrid)
	VAR
		showMarkers- : WMProperties.BooleanProperty;
		showMarkersI : BOOLEAN;

		sortBy- : WMProperties.Int32Property;
		sortByI : LONGINT;

		entries : ViewEntryArray;
		nofEntries : LONGINT;

		model : Model;
		textViews : POINTER TO ARRAY OF WMTextView.TextView;

		summary : ARRAY 256 OF CHAR;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrDiagnosticsView);
			SetDrawCellProc(DrawCell);
			NEW(showMarkers, PrototypeShowMarkers, NIL, NIL); properties.Add(showMarkers);
			showMarkersI := showMarkers.Get();
			NEW(sortBy, PrototypeSortBy, NIL, NIL); properties.Add(sortBy);
			sortByI := sortBy.Get();
			entries := NIL;
			nofEntries := 0;
			model := NIL;
			textViews := NIL;
			summary := "";
			nofCols.Set(3);
			nofRows.Set(1);
			onClick.Add(OnClickHandler);
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = showMarkers) THEN
				ShowMarkers(showMarkers.Get());
			ELSIF (property = sortBy) THEN
				SortBy(sortBy.Get());
			ELSE
				PropertyChanged^(sender, property);
			END
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			ShowMarkers(showMarkers.Get());
			SortBy(sortBy.Get());
		END RecacheProperties;

		PROCEDURE OnClickHandler(sender, data : ANY);
		CONST Position = 0; ErrorCode = 1;
		VAR column, row, newMode : LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.OnClickHandler, sender, data)
			ELSE
				IF (data # NIL) & (data IS CellInfo) & ~(data(CellInfo).entryValid) THEN
					column := data(CellInfo).pos.col;
					row := data(CellInfo).pos.row;
					IF (row = 0) THEN
						CASE sortByI OF
							|SortByTypeAscending:
								IF (column = Position) THEN
									newMode := SortByTypeDescending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeAscending;
								END;
							|SortByTypeDescending:
								IF (column = Position) THEN
									newMode := SortByTypeAscending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeDescending;
								END;
							|SortByPositionAscending:
								IF (column = Position) THEN
									newMode := SortByPositionDescending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeAscending;
								END;
							|SortByPositionDescending:
								IF (column = Position) THEN
									newMode := SortByPositionAscending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeDescending;
								END;
							|SortByErrorCodeAscending:
								IF (column = Position) THEN
									newMode := SortByTypeAscending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeDescending;
								END;
							|SortByErrorCodeDescending:
								IF (column = Position) THEN
									newMode := SortByTypeDescending;
								ELSIF (column = ErrorCode) THEN
									newMode := SortByErrorCodeAscending;
								END;
						ELSE
							newMode := sortByI; (* don't change *)
						END;
						sortBy.Set(newMode);
					END;
				END;
			END;
		END OnClickHandler;

		PROCEDURE ShowMarkers(enable : BOOLEAN);
		VAR i, j : LONGINT;
		BEGIN
			Acquire;
			IF (enable # showMarkersI) THEN
				showMarkersI := enable;
				IF (textViews # NIL) THEN
					FOR i := 0 TO nofEntries - 1 DO
						FOR j := 0 TO LEN(textViews) - 1 DO
							IF (entries[i].pos[j] # NIL) THEN
								entries[i].pos[j].SetVisible(showMarkersI);
							END;
						END;
					END;
				END;
				Invalidate;
			END;
			Release;
		END ShowMarkers;

		PROCEDURE SortBy(mode : LONGINT);
		BEGIN
			ASSERT(
				(mode = SortByTypeAscending) OR (mode = SortByTypeDescending) OR
				(mode = SortByPositionAscending) OR (mode = SortByPositionDescending) OR
				(mode = SortByErrorCodeAscending) OR (mode = SortByErrorCodeDescending)
			);
			Acquire;
			IF (mode # sortByI) THEN
				sortByI := mode;
				CASE sortByI OF
					|SortByTypeAscending: SortEntries(CompareByType, TRUE);
					|SortByTypeDescending: SortEntries(CompareByType, FALSE);
					|SortByPositionAscending: SortEntries(CompareByPosition, TRUE);
					|SortByPositionDescending: SortEntries(CompareByPosition, FALSE);
					|SortByErrorCodeAscending: SortEntries(CompareByErrorCode, TRUE);
					|SortByErrorCodeDescending: SortEntries(CompareByErrorCode, FALSE);
				END;
				Invalidate;
			END;
			Release;
		END SortBy;

		PROCEDURE GetCellData(column, row : LONGINT) : ANY; (* override *)
		VAR info : CellInfo; entryValid : BOOLEAN; entry : ViewEntry;
		BEGIN
			Acquire;
			IF (0 <= row - 1) & (row - 1 < nofEntries) THEN
				entryValid := TRUE;
				entry := entries[row - 1];
			ELSE
				entryValid := FALSE;
			END;
			NEW(info, entryValid, entry, column, row);
			Release;
			RETURN info;
		END GetCellData;

		PROCEDURE AddPositionMarkers;
		VAR picture : Files.FileName; i, j : LONGINT;
		BEGIN (* caller holds lock *)
			IF (textViews # NIL) THEN
				FOR i := 0 TO nofEntries - 1 DO

					IF (entries[i].errorCode = 400) THEN
						picture := PicturePCPosition;
					ELSIF (entries[i].type = Diagnostics.TypeError) THEN
						picture := PictureError;
					ELSIF (entries[i].type = Diagnostics.TypeWarning) THEN
						picture := PictureWarning;
					ELSE
						picture := "";
					END;

					IF (entries[i].position # Invalid) & (textViews # NIL) THEN
						NEW(entries[i].pos, LEN(textViews));
						FOR j := 0 TO LEN(textViews) - 1 DO
							entries[i].pos[j] := textViews[j].CreatePositionMarker();
							IF (picture # "") THEN entries[i].pos[j].Load(picture); END;
							entries[i].pos[j].SetPosition(entries[i].position);
						END;
					END;

				END;
			END;
		END AddPositionMarkers;

		PROCEDURE RemovePositionMarkers;
		VAR i, j : LONGINT;
		BEGIN (* caller holds lock *)
			IF (textViews # NIL) THEN
				FOR i := 0 TO nofEntries-1 DO
					FOR j := 0 TO LEN(textViews)-1 DO
						IF (entries[i].pos # NIL) & (entries[i].pos[j] # NIL) THEN
							textViews[j].RemovePositionMarker(entries[i].pos[j]);
							entries[i].pos[j] := NIL;
						END;
					END;
				END;
			END;
		END RemovePositionMarkers;

		PROCEDURE GetFirstPosition*(VAR positions : ARRAY OF LONGINT; VAR type: LONGINT);
		VAR i : LONGINT;
		BEGIN
			Acquire;
			ASSERT((textViews # NIL) & (LEN(textViews) = LEN(positions)));
			IF (nofEntries > 0) THEN
				FOR i := 0 TO LEN(textViews)-1 DO
					IF (entries[0].pos # NIL) & (entries[0].pos[i] # NIL) THEN
						positions[i] := entries[0].pos[i].GetPosition();
					ELSE
						positions[i] := Invalid;
					END;
					type := entries[0].type;
				END;
			ELSE
				FOR i := 0 TO LEN(positions)-1 DO positions[i] := Invalid; END;
			END;
			Release;
		END GetFirstPosition;

		PROCEDURE GetNearestPosition*(cursorPosition, editorIndex : LONGINT; forward : BOOLEAN; VAR nearestPosition : LONGINT; VAR number : LONGINT);
		VAR pos, i : LONGINT;
		BEGIN
			Acquire;
			ASSERT((textViews # NIL) & (0 <= editorIndex) & (editorIndex < LEN(textViews)));
			nearestPosition := -1; number := 1; (* row 0 is grid title *)
			i := 0;
			LOOP
				IF (i >= nofEntries) OR (entries[i].pos = NIL) OR (entries[i].pos[editorIndex] = NIL) THEN EXIT; END;
				pos := entries[i].pos[editorIndex].GetPosition();
				IF forward & (pos > cursorPosition) THEN
					IF (nearestPosition = -1) OR (pos < nearestPosition) THEN nearestPosition := pos; number := i+1; END;
				ELSIF ~forward & (pos < cursorPosition) THEN
					IF (nearestPosition = -1) OR (pos > nearestPosition) THEN nearestPosition := pos; number := i+1; END;
				END;
				INC(i);
			END;
			IF (nearestPosition = -1) THEN
				nearestPosition := cursorPosition;
				IF forward & (i > 1) THEN (* select maximum row *) number := i; END;
			END;
			Release;
		END GetNearestPosition;

		PROCEDURE SelectEntry*(number : LONGINT; moveTo : BOOLEAN);
		BEGIN
			Acquire;
			IF (0 <= number) & (number <= nofEntries) THEN
				SetSelection(0, number, 2, number);
				IF moveTo THEN
					SetTopPosition(0, number, TRUE);
				END;
			END;
			Release;
		END SelectEntry;

		PROCEDURE SortEntries(compare : CompareProcedure; ascending : BOOLEAN);
		VAR result, i, j : LONGINT; temp : ViewEntry;
		BEGIN
			(* caller must hold lock *)
			ASSERT(compare # NIL);
			IF (nofEntries > 1) THEN
				(* bubble sort *)
				FOR i := 0 TO nofEntries - 1 DO
					FOR j := 1 TO nofEntries - 1 DO
						result := compare(entries[j-1], entries[j]);
						IF (ascending & (result = Greater)) OR (~ascending & (result = Less)) THEN
							temp := entries[j - 1];
							entries[j - 1] := entries[j];
							entries[j] := temp;
						END;
					END;
				END;
			END;
		END SortEntries;

		PROCEDURE SetTextViews*(CONST textViews : ARRAY OF WMTextView.TextView);
		VAR i : LONGINT;
		BEGIN
			Acquire;
			RemovePositionMarkers;
			NEW(SELF.textViews, LEN(textViews));
			FOR i := 0 TO LEN(textViews)-1 DO
				ASSERT(textViews[i] # NIL);
				SELF.textViews[i]:= textViews[i];
			END;
			AddPositionMarkers;
			Release;
		END SetTextViews;

		PROCEDURE SetModel*(model : Model);
		BEGIN
			Acquire;
			IF (SELF.model # NIL) THEN SELF.model.onChanged.Remove(ModelChanged); END;
			SELF.model := model;
			IF (SELF.model # NIL) THEN SELF.model.onChanged.Add(ModelChanged); END;
			Release;
			Invalidate;
		END SetModel;

		PROCEDURE ModelChanged(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.ModelChanged, sender, data);
			ELSE
				RemovePositionMarkers;
				model.AcquireRead;
				model.Synchronize(entries, nofEntries);
				model.GetSummary(summary);
				model.ReleaseRead;
				nofRows.Set(nofEntries + 1); (* 1 for title row *)
				AddPositionMarkers;
				SetTopPosition(0, 0, TRUE);
				Invalidate;
			END;
		END ModelChanged;

		PROCEDURE DrawCell(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR color: LONGINT; str : ARRAY 128 OF CHAR;
		BEGIN
			color := WMGraphics.RGBAToColor(255, 255, 255, 255);
			IF state * {WMGrids.CellFixed, WMGrids.CellSelected} = {WMGrids.CellFixed, WMGrids.CellSelected} THEN
				color := WMGraphics.RGBAToColor(0, 128, 255, 255)
			ELSIF WMGrids.CellFixed IN state THEN
				color := WMGraphics.RGBAToColor(196, 196, 196, 255)
			ELSIF WMGrids.CellSelected IN state THEN
				color := WMGraphics.RGBAToColor(196, 196, 255, 255)
			END;
			canvas.SetColor(WMGraphics.RGBAToColor(0, 0, 0, 255));
			canvas.SetFont(WMBitmapFont.bimbofont);

			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), color, WMGraphics.ModeCopy);
			IF (WMGrids.CellFocused IN state) & ~(WMGrids.CellHighlighted IN state) THEN
				WMGraphicUtilities.DrawBevel(canvas, WMRectangles.MakeRect(0, 0, w, h), 1, TRUE, WMGraphics.RGBAToColor(0, 0, 0, 196),
				WMGraphics.ModeSrcOverDst)
			END;

			IF y = 0 THEN
				CASE x OF
					| 0 : str := "pos"
					| 1 : str := "err"
					| 2 :
						str := "Error Str";
						Strings.Append(str, " ("); Strings.Append(str, summary); Strings.Append(str, ")");
				ELSE
				END;
				canvas.DrawString(4, h - 4, str);
			ELSIF (0 <= y - 1) & (y - 1 < nofEntries) THEN
				CASE x OF
					| 0 :
						IF (entries[y - 1].pos # NIL) & (entries[y - 1].pos[0] # NIL) THEN Strings.IntToStr(entries[y - 1].pos[0].GetPosition(), str) END;
						IF entries[y - 1].type = TypeError THEN
							canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), ColorError, WMGraphics.ModeSrcOverDst);
						ELSIF entries[y - 1].type = TypeWarning THEN
							canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), ColorWarning, WMGraphics.ModeSrcOverDst);
						ELSIF entries[y - 1].type = TypeInformation THEN
							canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), ColorPCPosition, WMGraphics.ModeSrcOverDst);
						ELSIF entries[y - 1].type = TypeInformation THEN
							(* do nothing *)
						END;
					| 1 : IF (entries[y-1].errorCode # Invalid) THEN
							Strings.IntToStr(entries[y - 1].errorCode, str);
						ELSE
							COPY("", str);
						END;
					| 2 : COPY(entries[y - 1].message, str)
				ELSE
				END;
				canvas.DrawString(4, h - 4, str);
			END;

		END DrawCell;

	END DiagnosticsView;

VAR
	StrDiagnosticsView : Strings.String;

	PrototypeShowMarkers : WMProperties.BooleanProperty;
	PrototypeSortBy : WMProperties.Int32Property;

PROCEDURE CompareByPosition(CONST e1, e2 : Entry) : LONGINT;
VAR result : LONGINT;
BEGIN
	IF (e1.position < e2.position) THEN result := Less;
	ELSIF (e1.position > e2.position) THEN result := Greater;
	ELSE
		result := Equal;
	END;
	RETURN result;
END CompareByPosition;

PROCEDURE CompareByErrorCode(CONST e1, e2 : Entry) : LONGINT;
VAR result : LONGINT;
BEGIN
	IF (e1.errorCode < e2.errorCode) THEN result := Less;
	ELSIF (e1.errorCode > e2.errorCode) THEN result := Greater;
	ELSE
		result := CompareByPosition(e1, e2);
	END;
	RETURN result;
END CompareByErrorCode;

PROCEDURE CompareByType(CONST e1, e2 : Entry) : LONGINT;
VAR result : LONGINT;
BEGIN
	IF (e1.type < e2.type) THEN result := Less;
	ELSIF (e1.type > e2.type) THEN result := Greater;
	ELSE
		result := CompareByPosition(e1, e2);
	END;
	RETURN result;
END CompareByType;

PROCEDURE InitStrings;
BEGIN
	StrDiagnosticsView := Strings.NewString("DiagnosticsView");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeShowMarkers, NIL, Strings.NewString("ShowMarkers"), Strings.NewString("Highlight errors in TextView?"));
	PrototypeShowMarkers.Set(TRUE);
	NEW(PrototypeSortBy, NIL, Strings.NewString("SortBy"), Strings.NewString("Sort grid by 0=type | 1=position | 2=errorCode"));
	PrototypeSortBy.Set(SortByTypeDescending);
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMDiagnostics.
