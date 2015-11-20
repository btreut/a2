MODULE WMRepositories; (** AUTHOR "staubesv"; PURPOSE "Repository inspection tool"; *)

IMPORT
	Modules, Kernel, KernelLog, Commands, Strings, XML, XMLObjects, Repositories, Texts,
	Raster, WMRectangles, WMMessages, WMRestorable, WMGraphics, WMWindowManager, WMProperties, WMComponents, WMStandardComponents,
	WMEditors, WMGrids, WMStringGrids, WMDialogs, WMDropTarget;

CONST
	WindowWidth = 640; WindowHeight = 480;

	State_NotInitialized = 0;
	State_Running = 1;
	State_Finalizing = 9;
	State_Finalized = 10;

TYPE

	(* Drag'n'Drop for components *)

	AddComponentProcedure* = PROCEDURE {DELEGATE} (component : Repositories.Component; VAR res : LONGINT);

	DropTarget* = OBJECT(WMDropTarget.DropTarget)
	VAR
		originator : ANY;
		addComponent : AddComponentProcedure;

		PROCEDURE &Init*(originator : ANY; addComponent : AddComponentProcedure);
		BEGIN
			ASSERT(addComponent # NIL);
			SELF.originator := originator;
			SELF.addComponent := addComponent;
		END Init;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR dc : DropComponent;
		BEGIN
			IF (type = WMDropTarget.TypeUser) THEN
				NEW(dc, originator, addComponent); RETURN dc;
			ELSE
				RETURN NIL;
			END;
		END GetInterface;

	END DropTarget;

	DropComponent* = OBJECT(WMDropTarget.DropInterface)
	VAR
		originator : ANY;
		addComponent : AddComponentProcedure;

		PROCEDURE &Init*(originator : ANY; addComponent : AddComponentProcedure);
		BEGIN
			ASSERT(addComponent # NIL);
			SELF.originator := originator;
			SELF.addComponent := addComponent;
		END Init;

		PROCEDURE Set(component : Repositories.Component; VAR res : LONGINT);
		BEGIN
			addComponent(component, res);
		END Set;

	END DropComponent;

TYPE

	RepositoriesView* = OBJECT(WMComponents.VisualComponent)
	VAR
		grid- : WMStringGrids.StringGrid;

		repositories : Repositories.Repositories;

		lastTimestamp : LONGINT;
		state : LONGINT;

		PROCEDURE &Init*;
		VAR i : LONGINT;
		BEGIN
			Init^;
			NEW(repositories, 20);
			FOR i := 0 TO LEN(repositories)-1 DO repositories := NIL; END;
			InitGrid;
			lastTimestamp := Repositories.GetTimestamp();
			state := State_NotInitialized;
		END Init;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			BEGIN {EXCLUSIVE} state := State_Running; END;
		END Initialize;

		PROCEDURE SelectByRepository*(repository : Repositories.Repository);
		VAR row, nofRows, selectRow : LONGINT; data : ANY;
		BEGIN
			selectRow:= -1;
			IF (repository # NIL) THEN
				grid.Acquire;
				grid.model.Acquire;
				nofRows := grid.model.GetNofRows();
				row := 0;
				WHILE (selectRow = -1) & (row < nofRows) DO
					data := grid.model.GetCellData(0, row);
					IF (data = repository) THEN
						selectRow := row;
					END;
					INC(row);
				END;
				grid.model.Release;
				grid.Release;
			END;
			grid.SetSelection(0, selectRow, 0, selectRow);
		END SelectByRepository;

		PROCEDURE InitGrid;
		BEGIN
			NEW(grid); grid.alignment.Set(WMComponents.AlignClient);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(TRUE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(TRUE);
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.model.SetNofRows(0);
			grid.model.Release;
			grid.Release;
			AddContent(grid);
		END InitGrid;

		PROCEDURE UpdateGrid;
		VAR nofRepositories, row : LONGINT;

			PROCEDURE CountRepositories(repositories : Repositories.Repositories) : LONGINT;
			VAR nofRepositories : LONGINT;
			BEGIN
				nofRepositories := 0;
				IF (repositories # NIL) THEN
					WHILE (nofRepositories < LEN(repositories)) & (repositories[nofRepositories] # NIL) DO
						INC(nofRepositories);
					END;
				END;
				RETURN nofRepositories;
			END CountRepositories;

		BEGIN
			Repositories.GetAll(repositories);
			nofRepositories := CountRepositories(repositories);
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofRows(nofRepositories);
			FOR row := 0 TO nofRepositories-1 DO
				grid.model.SetCellText(0, row, Strings.NewString(repositories[row].name));
				grid.model.SetCellData(0, row, repositories[row]);
			END;
			grid.model.Release;
			grid.Release;
		END UpdateGrid;

		PROCEDURE Finalize;
		VAR ignore : LONGINT;
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE} state := State_Finalizing; END;
			Repositories.IncrementTimestamp(ignore); (* Unblock Repositories.AwaitChange in body *)
			BEGIN {EXCLUSIVE} AWAIT(state = State_Finalized); END;
		END Finalize;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(state > State_NotInitialized); END;
		WHILE (state = State_Running) DO
			UpdateGrid;
			Repositories.AwaitChange(lastTimestamp);
		END;
		BEGIN {EXCLUSIVE} state := State_Finalized; END;
	END RepositoriesView;

TYPE

	EntryWrapper* = OBJECT
	VAR
		repository- : Repositories.Repository;
		element- : XML.Element;

		PROCEDURE &Init*(repository : Repositories.Repository; CONST element : XML.Element);
		BEGIN
			SELF.repository := repository;
			SELF.element := element;
		END Init;

	END EntryWrapper;

	RepositoryView* = OBJECT(WMComponents.VisualComponent)
	VAR
		showDetails- : WMProperties.BooleanProperty;
		showDetailsI : BOOLEAN;

		grid- : WMStringGrids.StringGrid;
		spacings : WMGrids.Spacings;

		thisRepository : Repositories.Repository;

		enum : XMLObjects.Enumerator;
		draggedComponent : Repositories.Component;

		lastTimestamp, lastRepositoryTimestamp : LONGINT;
		state : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(showDetails, NIL, NIL, NIL); properties.Add(showDetails);
			showDetails.Set(TRUE);
			showDetailsI := showDetails.Get();
			InitGrid;
			thisRepository := NIL;
			enum := NIL;
			draggedComponent := NIL;
			lastTimestamp := Repositories.GetTimestamp();
			lastRepositoryTimestamp := 0;
			state := State_NotInitialized;
		END Init;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = showDetails) THEN
				showDetailsI := showDetails.Get();
				SetDetails(showDetailsI);
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			BEGIN {EXCLUSIVE} state := State_Running; END;
		END Initialize;

		PROCEDURE InitGrid;
		BEGIN
			NEW(grid); grid.alignment.Set(WMComponents.AlignClient);
			grid.onStartDrag.Add(MyStartDrag);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			grid.adjustFocusPosition.Set(FALSE);
			grid.alwaysShowScrollX.Set(FALSE);
			grid.alwaysShowScrollY.Set(FALSE);
			grid.allowColResize.Set(TRUE); grid.allowRowResize.Set(FALSE);
			NEW(spacings, 4); spacings[0] := 30; spacings[1] := 130; spacings[2] := 200; spacings[3] := 20;
			SetDetails(TRUE);
			AddContent(grid);
		END InitGrid;

		PROCEDURE GetSelectedComponent() : Repositories.Component;
		VAR
			component : Repositories.Component; string : Strings.String; id : LONGINT;
			wrapper : EntryWrapper;
			scol, srow, ecol, erow : LONGINT;
			ptr : ANY;
		BEGIN
			component := NIL;
			wrapper := NIL;
			grid.Acquire;
			grid.model.Acquire;
			grid.GetSelection(scol, srow, ecol, erow);
			IF (srow >= 0) & (srow = erow) THEN
				ptr := grid.model.GetCellData(0, srow);
				IF (ptr # NIL) & (ptr IS EntryWrapper) THEN
					wrapper := ptr (EntryWrapper);
				END;
			END;
			grid.model.Release;
			grid.Release;
			IF (wrapper # NIL) & (wrapper.repository # NIL) & (wrapper.element # NIL) THEN
				string := wrapper.element.GetAttributeValue("id");
				IF (string # NIL) THEN Strings.StrToInt(string^, id); ELSE id := 0; END;
				string := wrapper.element.GetAttributeValue("name");
				IF (string # NIL) THEN
					component := wrapper.repository.GetComponent(string^, id);
				END;
			END;
			RETURN component;
		END GetSelectedComponent;

		(* Drag away operations *)
		PROCEDURE MyStartDrag(sender, data : ANY);
		VAR
			component : Repositories.Component;
			vc : WMComponents.VisualComponent;
			name : Strings.String;
			bounds : WMRectangles.Rectangle;
			image : WMGraphics.Image; canvas : WMGraphics.BufferCanvas;
			font : WMGraphics.Font;
			w, h : LONGINT;
		BEGIN
			component := GetSelectedComponent();
			IF (component # NIL) THEN
				image := NIL;
				IF (component IS WMComponents.VisualComponent) THEN
					vc := component (WMComponents.VisualComponent);
					bounds := vc.bounds.Get();
					IF (bounds.r - bounds.l < 10) THEN bounds.r := bounds.l + 100; vc.bounds.Set(bounds); END;
					IF (bounds.b - bounds.t < 10) THEN bounds.b := bounds.t + 50; vc.bounds.Set(bounds); END;
					(* render to bitmap *)
					NEW(image); Raster.Create(image, bounds.r - bounds.l, bounds.b - bounds.t, Raster.BGRA8888);
					NEW(canvas, image);
					canvas.Fill(WMRectangles.MakeRect(0, 0, bounds.r-bounds.l, bounds.b-bounds.t), 0FF60H, WMGraphics.ModeSrcOverDst);
					vc.Draw(canvas);
				ELSE
					name := component.GetName();
					IF (name = NIL) THEN name := Strings.NewString("NoName"); END;
					ASSERT(name # NIL);
					w := 0; h := 0;
					font := GetFont();
					font.GetStringSize(name^, w, h);
					IF (w =0) THEN w := 100 END;
					IF (h=0) THEN h := 50 END;
					IF (w > 0) & (h > 0) THEN
						(* render to bitmap *)
						NEW(image); Raster.Create(image, w, h, Raster.BGRA8888);
						NEW(canvas, image);
						canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), 0FF60H, WMGraphics.ModeSrcOverDst);
						canvas.SetColor(WMGraphics.Black);
						WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(0, 0, w, h), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, name^)
					END;
				END;
				IF ~StartDrag(component, image, 0,0,DragWasAccepted, NIL) THEN component := NIL; END;
			END;
			draggedComponent := component;
		END MyStartDrag;

		PROCEDURE DragWasAccepted(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			dropText : WMDropTarget.DropText;
			op : Texts.ObjectPiece;
			res : LONGINT;
		BEGIN
			IF (draggedComponent = NIL) THEN RETURN END;

			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget);
					itf := dt.GetInterface(WMDropTarget.TypeUser);
					IF (itf # NIL) & (itf IS DropComponent) THEN
						itf(DropComponent).Set(draggedComponent(Repositories.Component), res);
					ELSE
						itf := dt.GetInterface(WMDropTarget.TypeText);
						IF (itf # NIL) & (itf IS WMDropTarget.DropText) THEN
							dropText := itf(WMDropTarget.DropText);
							NEW(op); op.object := draggedComponent;
							dropText.text.AcquireWrite;
							dropText.text.InsertPiece(dropText.pos.GetPosition(), op);
							dropText.text.ReleaseWrite;
						END;
					END;
				END;
			END;
		END DragWasAccepted;

		PROCEDURE SetDetails(details : BOOLEAN);
		BEGIN
			grid.Acquire;
			grid.model.Acquire;
			IF details THEN
				grid.showScrollX.Set(TRUE);
				grid.showScrollY.Set(TRUE);
				grid.fixedRows.Set(1);
				grid.SetColSpacings(spacings);
				grid.model.SetNofCols(4);
				grid.model.SetNofRows(1);
				grid.model.SetCellText(0, 0, StrName);
				grid.model.SetCellText(1, 0, StrID);
				grid.model.SetCellText(2, 0, StrParameter);
				grid.model.SetCellText(3, 0, StrInstance);
			ELSE
				grid.showScrollX.Set(FALSE);
				grid.showScrollY.Set(TRUE);
				grid.SetColSpacings(NIL);
				grid.fixedRows.Set(0);
				grid.model.SetNofCols(1);
				grid.model.SetNofRows(0);
			END;
			grid.model.Release;
			grid.Release;
		END SetDetails;

		PROCEDURE Resized;
		BEGIN
			UpdateGridSpacings;
			Resized^;
		END Resized;

		PROCEDURE UpdateGridSpacings*;
		VAR sum, w, i : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			rect := bounds.Get(); w := rect.r - rect.l;
			FOR i := 0 TO LEN(spacings)-1 DO sum := sum + spacings[i]; END;
			IF w > sum THEN
				grid.Acquire;
				grid.model.Acquire;
				spacings[0] := spacings[0] + (w - sum) DIV 2;
				spacings[2] := spacings[2] + (w - sum) DIV 2 + (w - sum) MOD 2;
				grid.model.Release;
				grid.Release;
			ELSIF (w > 190) THEN
				spacings[0] := 130; spacings[1] := 30; spacings[2] := w - 180; spacings[3] := 20;
			ELSE
				spacings[0] := 130; spacings[1] := 30; spacings[2] := 200; spacings[3] := 20;
			END;
		END UpdateGridSpacings;

		PROCEDURE SetThisRepository*(repository : Repositories.Repository);
		VAR ignore : LONGINT;
		BEGIN
			SELF.thisRepository := repository;
			IF (repository # NIL) THEN
				lastTimestamp := Repositories.GetTimestamp();
				lastRepositoryTimestamp := repository.timestamp - 1;
			ELSE
				lastRepositoryTimestamp := 0;
			END;
			Repositories.IncrementTimestamp(ignore);
		END SetThisRepository;

		PROCEDURE UpdateGrid;
		VAR
			repository : Repositories.Repository; wrapper : EntryWrapper;
			element : XML.Element; image : WMGraphics.Image;
			row, nofEntries : LONGINT;

			PROCEDURE CountElements(enum : XMLObjects.Enumerator) : LONGINT;
			VAR nofElements : LONGINT; ptr : ANY;
			BEGIN
				ASSERT(enum # NIL);
				nofElements := 0;
				WHILE enum.HasMoreElements() DO
					ptr := enum.GetNext();
					IF (ptr IS XML.Element) THEN
						INC(nofElements);
					END;
				END;
				RETURN nofElements;
			END CountElements;

			PROCEDURE GetNext(enum : XMLObjects.Enumerator) : XML.Element;
			VAR element : XML.Element; ptr : ANY;
			BEGIN
				element := NIL;
				WHILE (element = NIL) & (enum.HasMoreElements()) DO
					ptr := enum.GetNext();
					IF (ptr IS XML.Element) THEN
						element := ptr (XML.Element);
					END;
				END;
				RETURN element;
			END GetNext;

			PROCEDURE GetImage(element : XML.Element) : WMGraphics.Image;
			VAR image : WMGraphics.Image; imageName : Strings.String;
			BEGIN
				imageName := element.GetAttributeValue("image");
				IF (imageName # NIL) THEN
					image := WMGraphics.LoadImage(imageName^, TRUE);
				ELSE
					image := NIL;
				END;
				RETURN image;
			END GetImage;

		BEGIN
			repository := thisRepository;
			IF ((repository = NIL) & (lastRepositoryTimestamp = 0)) OR ((repository # NIL) & (repository.timestamp # lastRepositoryTimestamp)) THEN
				IF (repository # NIL) THEN
					lastRepositoryTimestamp := repository.timestamp;
					enum := repository.GetComponentEnumerator();
					nofEntries := CountElements(enum);
					enum.Reset;
				ELSE
					lastRepositoryTimestamp := 1;
					nofEntries := 0;
				END;
				IF (nofEntries > 0) THEN
					grid.Acquire;
					grid.model.Acquire;
					grid.model.SetNofRows(nofEntries + 1);
					enum.Reset;
					IF showDetailsI THEN
						FOR row := 1 TO nofEntries DO
							element := GetNext(enum);
							grid.model.SetCellText(0, row, element.GetAttributeValue("name"));
							image := GetImage(element);
							grid.model.SetCellImage(0, row, image);
							grid.model.SetCellText(1, row, element.GetAttributeValue("id"));
							grid.model.SetCellText(2, row, element.GetAttributeValue("source"));
(*							IF (index[row-1].instance # NIL) THEN
								grid.model.SetCellText(3, row, StrYes);
							ELSE
								grid.model.SetCellText(3, row, StrNo);
							END; *)
							NEW(wrapper, repository, element);
							grid.model.SetCellData(0, row, wrapper);
							grid.model.SetCellData(1, row, wrapper);
							grid.model.SetCellData(2, row, wrapper);
							grid.model.SetCellData(3, row, wrapper);
						END;
					ELSE
						FOR row := 0 TO nofEntries-1 DO
							element := GetNext(enum);
							grid.model.SetCellText(0, row, element.GetAttributeValue("name"));
							image := GetImage(element);
							grid.model.SetCellImage(0, row, image);
							NEW(wrapper, repository, element);
							grid.model.SetCellData(0, row, wrapper);
						END;
					END;
					grid.model.Release;
					grid.Release;
				END;
			END;
		END UpdateGrid;

		PROCEDURE Finalize;
		VAR ignore : LONGINT;
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE} state := State_Finalizing; END;
			Repositories.IncrementTimestamp(ignore); (* Unblock Repositories.AwaitChange in body *)
			BEGIN {EXCLUSIVE} AWAIT(state = State_Finalized); END;
		END Finalize;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(state > State_NotInitialized); END;
		WHILE (state = State_Running) DO
			UpdateGrid;
			Repositories.AwaitChange(lastTimestamp);
		END;
		BEGIN {EXCLUSIVE} state := State_Finalized; END;
	END RepositoryView;


	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		repositories : RepositoriesView;
		repository : RepositoryView;

		loadBtn, storeBtn, unloadBtn : WMStandardComponents.Button;
		filenameEditor : WMEditors.Editor;
		statusLabel : WMStandardComponents.Label;

		opNum : LONGINT;

		PROCEDURE &New(context : WMRestorable.Context);
		BEGIN
			Init(WindowWidth, WindowHeight, FALSE);
			IncCount;
			SetContent(CreateForm());
			repository.UpdateGridSpacings;
			SetTitle(Strings.NewString("Repositories"));
			SetIcon(WMGraphics.LoadImage("WMRepositories.tar://WMRepositories.png", TRUE));
			opNum := 1;
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, treePanel, toolbar : WMStandardComponents.Panel; resizer : WMStandardComponents.Resizer;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignBottom);
			statusLabel.bounds.SetHeight(20);
			statusLabel.fillColor.Set(0CCCCCCCCH);
			statusLabel.caption.SetAOC("0: OK");
			panel.AddContent(statusLabel);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			panel.AddContent(toolbar);

			NEW(loadBtn); loadBtn.alignment.Set(WMComponents.AlignLeft);
			loadBtn.caption.SetAOC("Load");
			loadBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(loadBtn);

			NEW(filenameEditor); filenameEditor.alignment.Set(WMComponents.AlignClient);
			filenameEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filenameEditor.multiLine.Set(FALSE);
			filenameEditor.tv.showBorder.Set(TRUE);
			toolbar.AddContent(filenameEditor);

			NEW(unloadBtn); unloadBtn.alignment.Set(WMComponents.AlignRight);
			unloadBtn.caption.SetAOC("Unload");
			unloadBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(unloadBtn);

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignRight);
			storeBtn.caption.SetAOC("Store");
			storeBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(storeBtn);

			NEW(treePanel); treePanel.alignment.Set(WMComponents.AlignLeft);
			treePanel.bounds.SetWidth(150);
			panel.AddContent(treePanel);

			NEW(resizer); resizer.alignment.Set(WMComponents.AlignRight);
			resizer.bounds.SetWidth(5);
			treePanel.AddContent(resizer);

			NEW(repositories); repositories.alignment.Set(WMComponents.AlignClient);
			treePanel.AddContent(repositories);
			repositories.grid.onClick.Add(OnRepositoriesClicked);

			NEW(repository); repository.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(repository);
			repository.grid.onClickSelected.Add(OnComponentClicked);

			RETURN panel;
		END CreateForm;

		PROCEDURE SetStatusLabel(CONST m1, m2, m3 : ARRAY OF CHAR);
		VAR caption : ARRAY 256 OF CHAR; nbr : ARRAY 8 OF CHAR;
		BEGIN
			caption := " ";
			Strings.IntToStr(opNum, nbr); INC(opNum);
			Strings.Append(caption, nbr);
			Strings.Append(caption, ": ");
			Strings.Append(caption, m1);
			Strings.Append(caption, m2);
			Strings.Append(caption, m3);
			statusLabel.caption.SetAOC(caption);
		END SetStatusLabel;

		PROCEDURE LoadRepository(CONST filename : ARRAY OF CHAR);
		VAR repository : Repositories.Repository; timer : Kernel.Timer;
		BEGIN
			repository := Repositories.ThisRepository(filename);
			IF (repository # NIL) THEN
				NEW(timer); timer.Sleep(200);
				repositories.SelectByRepository(repository);
				SetStatusLabel("Repository '", filename, "' loaded");
			ELSE
				SetStatusLabel("Repository '", filename, "' not found");
			END;
		END LoadRepository;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR; res : LONGINT;
		BEGIN
			IF (sender = loadBtn) THEN
			filenameEditor.GetAsString(filename);
				LoadRepository(filename);
			ELSIF (sender = storeBtn) THEN
				filenameEditor.GetAsString(filename);
				Repositories.StoreRepository(filename, res);
				IF (res # Repositories.Ok) THEN
					SetStatusLabel("Could not store repository '", filename, "'");
					WMDialogs.Error("Error", "Could not store repository");
				ELSE
					SetStatusLabel("Repository '", filename, "' stored");
				END;
			ELSIF (sender = unloadBtn) THEN
				filenameEditor.GetAsString(filename);
				Repositories.UnloadRepository(filename, res);
				IF (res # Repositories.Ok) THEN
					SetStatusLabel("Could not unload repository '", filename, "'");
					WMDialogs.Error("Error", "Could not unload repository");
				ELSE
					SetStatusLabel("Repository '", filename, "' unloaded");
				END;
			END;
		END HandleButtons;

		PROCEDURE OnRepositoriesClicked(sender, data : ANY);
		BEGIN
			IF (data # NIL) & (data IS Repositories.Repository) THEN
				repository.SetThisRepository(data(Repositories.Repository));
				filenameEditor.SetAsString(data(Repositories.Repository).name);
			END;
		END OnRepositoriesClicked;

		PROCEDURE OnComponentClicked(sender, data : ANY);
		VAR command, msg : ARRAY 384 OF CHAR; res : LONGINT; string : Strings.String;
		BEGIN
			IF (data # NIL) & (data IS EntryWrapper) THEN
				IF (data(EntryWrapper).repository # NIL) & (data(EntryWrapper).element # NIL) THEN
					string := data(EntryWrapper).element.GetAttributeValue("source");
					IF (string # NIL) THEN
						command := "PET.Open ";
						Strings.Append(command, data(EntryWrapper).repository.filename);
						Strings.Append(command, "://");
						Strings.Append(command, string^);
						Commands.Call(command, {}, res, msg);
						IF (res # Commands.Ok) THEN KernelLog.String(msg); END;
					END;
				END;
			END;
		END OnComponentClicked;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMRepositories", "WMRepositories.Restore", SELF, NIL);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount;
		END Close;

	END Window;

VAR
	nofWindows : LONGINT;

	StrID, StrName, StrType, StrParameter, StrInstance : Strings.String;
	StrYes, StrNo : Strings.String;

PROCEDURE Open*;
VAR window : Window;
BEGIN
	NEW(window, NIL);
	WMWindowManager.AddWindow(window, 100, 100);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context);
	WMRestorable.AddByContext(window, context);
END Restore;

PROCEDURE InitStrings;
BEGIN
	StrID := Strings.NewString("ID");
	StrName := Strings.NewString("Name");
	StrType := Strings.NewString("Type");
	StrParameter := Strings.NewString("Parameter");
	StrInstance := Strings.NewString("Instance");
	StrYes := Strings.NewString("Yes");
	StrNo := Strings.NewString("No");
END InitStrings;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	nofWindows := 0;
	InitStrings;
	Modules.InstallTermHandler(Cleanup);
END WMRepositories.

WMRepositories.Open ~

SystemTools.Free WMRepositories ~
