MODULE WMSystemComponents;	(** AUTHOR "TF/UG"; PURPOSE "Components for File-Listings etc"; *)

IMPORT
	Files, Dates, Strings, XML, XMLObjects, WMProperties, WMEvents, WMComponents, WMTrees, WMGrids, WMStringGrids,
	WMRectangles, WMGraphics, Raster,
	KernelLog, Configuration,
	WMDropTarget, Texts, TextUtilities, Streams, WMPopups, WMDialogs, FileHandlers, Commands,
	Archives, UTF8Strings,
	Notepad,
	WM := WMWindowManager;

CONST
	BufSize = 16*1024; (* internal buffer size, used for copy *)

	FileNameLength = 256;

	TraceCopy = 0;
	TraceDragging = 1;

	Trace = {0};

	FilenamePlaceholder = "@filename";

TYPE
	 FilesDropInterface = OBJECT(WMDropTarget.DropFiles)
	 VAR
	 	path : Files.FileName;
		f : Files.File;
		w : Files.Writer;
		refresh : WMEvents.EventSource;
		overwriteOnce, overwriteAll, overwriteNever, abort : BOOLEAN;

		PROCEDURE &New*(CONST str : ARRAY OF CHAR);
		BEGIN
			COPY(str, path);
			NEW(refresh, SELF, NIL, NIL, NIL);
			overwriteAll := FALSE; overwriteNever := FALSE; abort := FALSE;
		END New;

		PROCEDURE OpenPut(CONST remoteName : ARRAY OF CHAR; VAR outw : Streams.Writer; VAR res : LONGINT);
		VAR oldFile : Files.File; name : ARRAY 1024 OF CHAR;
		BEGIN
			res := -1;
			IF abort THEN RETURN; END;
			COPY(path, name); Strings.Append(name, remoteName);
			overwriteOnce := FALSE;
			oldFile := Files.Old(name);
			IF (oldFile # NIL) & ~overwriteAll & ~overwriteNever THEN
				res := WMDialogs.Message(WMDialogs.TConfirmation, "Confirm overwriting", remoteName, {WMDialogs.ResNo, WMDialogs.ResYes, WMDialogs.ResAll, WMDialogs.ResAbort, WMDialogs.ResNever});
				CASE res OF
					|WMDialogs.ResYes: overwriteOnce := TRUE;
					|WMDialogs.ResNo: overwriteOnce := FALSE;
					|WMDialogs.ResAll: overwriteAll := TRUE;
					|WMDialogs.ResAbort: abort := TRUE;
					|WMDialogs.ResNever: overwriteNever := TRUE;
				ELSE
					KernelLog.String("WMSystemComponents: Implementation error, unexpected WMDialog result type."); KernelLog.Ln;
				END;
			END;

			IF TraceCopy IN Trace THEN KernelLog.String(name); KernelLog.String(" ... "); END;
			IF (oldFile = NIL) OR overwriteOnce OR overwriteAll THEN
				f := Files.New(name);
				IF f # NIL THEN
					Files.OpenWriter(w, f, 0);
					outw := w;
					res := Files.Ok;
					IF TraceCopy IN Trace THEN
						KernelLog.String(" done");
						IF (oldFile # NIL) THEN KernelLog.String(" (overwritten)"); END;
						KernelLog.String(".");
					END;
				ELSE
					KernelLog.String("Error: Could not create file "); KernelLog.String(name); KernelLog.Ln;
				END;
			ELSE
				IF (TraceCopy IN Trace) & (oldFile # NIL) THEN KernelLog.String("skipped."); KernelLog.Ln; END;
			END;
			IF TraceCopy IN Trace THEN KernelLog.Ln; END;
		END OpenPut;

		PROCEDURE ClosePut(VAR res : LONGINT);
		BEGIN
			IF (f # NIL) & (w # NIL)  THEN
				w.Update;
				f.Update;
				Files.Register(f);
				refresh.Call(NIL)
			END
		END ClosePut;

	END FilesDropInterface;

	FilesDropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR path : Files.FileName; eh : WMEvents.EventListener;

		PROCEDURE &New*(str : Strings.String; e : WMEvents.EventListener);
		BEGIN
			IF str # NIL THEN COPY(str^, path) END;
			MakePathString(path);
			eh := e
		END New;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : FilesDropInterface;
		BEGIN
			IF type = WMDropTarget.TypeFiles THEN
				NEW(di, path);
				IF eh # NIL THEN di.refresh.Add(eh) END;
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;
	END FilesDropTarget;

TYPE

	TreeData = OBJECT
	VAR
		path, name : Strings.String;
	END TreeData;

	DirectoryTree* = OBJECT(WMTrees.TreeView)
	VAR
		enumerator : Files.Enumerator;
		tree : WMTrees.Tree;
		currentPath* : WMProperties.StringProperty;
		onPathChanged* : WMEvents.EventSource;
		tr : WMTrees.TreeNode;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(GSDirectoryTree);
			SetGenerator("WMSystemComponents.GenDirectoryTree");
			(* new properties *)
			NEW(currentPath, DirTreePathProt, NIL, NIL); properties.Add(currentPath);
			(* new events *)
			NEW(onPathChanged, SELF, GSonPathChanged, GSonPathChangedInfo, SELF.StringToCompCommand);
			events.Add(onPathChanged);

			tree := GetTree();
			NEW(enumerator);
			onSelectNode.Add(NodeSelected);
			onExpandNode.Add(NodeExpanded);
			tree.Acquire;
			NEW(tr);
			tree.SetRoot(tr);
			tree.SetNodeCaption(tr, WMComponents.NewString("FileSystems"));
			tree.InclNodeState(tr, WMTrees.NodeAlwaysExpanded);
			FillMountedFS(tree, tr);
			tree.Release;
		END Init;

		PROCEDURE Refresh*;
		BEGIN
			tree.Acquire;
			FillMountedFS(tree, tr);
			tree.Release;
		END Refresh;

		PROCEDURE NodeExpanded(sender, data : ANY);
		VAR p : ANY;
		BEGIN
			IF (data = NIL) OR ~(data IS WMTrees.TreeNode) THEN RETURN END;
			tree.Acquire;
			p := tree.GetNodeData(data(WMTrees.TreeNode));
			IF (p # NIL) & (p IS TreeData) THEN
				IF WMTrees.NodeSubnodesUnknown IN tree.GetNodeState(data(WMTrees.TreeNode)) THEN
					EnumerateSubDirectories(tree, data(WMTrees.TreeNode), p(TreeData).path)
				END
			END;
			tree.Release
		END NodeExpanded;

		PROCEDURE NodeSelected(sender, data : ANY);
		VAR p : ANY;
		BEGIN
			IF (data = NIL) OR ~(data IS WMTrees.TreeNode) THEN RETURN END;
			tree.Acquire;
			p := tree.GetNodeData(data(WMTrees.TreeNode));
			IF (p # NIL) & (p IS TreeData) THEN
				EnumerateSubDirectories(tree, data(WMTrees.TreeNode), p(TreeData).path);
				currentPath.Set(p(TreeData).path);
				onPathChanged.Call(p(TreeData).path)
			END;
			tree.Release
		END NodeSelected;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WM.DragInfo);
		VAR node : WMTrees.TreeNode;
			dropTarget : FilesDropTarget;
			p : ANY;
		BEGIN
			tree.Acquire;
			node := GetNodeAtPos(x, y);
			p := tree.GetNodeData(node);
			tree.Release;
			IF (p # NIL) & (p IS TreeData) THEN
				NEW(dropTarget, p(TreeData).path, NIL);
				dragInfo.data := dropTarget;
				ConfirmDrag(TRUE, dragInfo)
			END
		END DragDropped;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = currentPath) THEN (*SetPath(currentPath.Get()) *)
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		(* binary insertion algorithm from "Algorithms and Data Structures" by N. Wirth *)
		PROCEDURE SortDirs(VAR dir: ARRAY OF TreeData);
		VAR i, j, m, L, R : LONGINT;
			x : TreeData;
			dirName, xName: Strings.String;
		BEGIN
			FOR i := 1 TO LEN(dir) - 1 DO
				x := dir[i]; L := 0; R := i; xName := Strings.NewString(x.name^); Strings.UpperCase(xName^);
				WHILE L < R DO
					m := (L + R) DIV 2;
					dirName := Strings.NewString(dir[m].name^); Strings.UpperCase(dirName^);
					IF UTF8Strings.Compare(dirName^, xName^) = UTF8Strings.CmpGreater THEN
						R := m
					ELSE
						L := m + 1
					END
				END;
				FOR j := i TO R + 1 BY -1 DO dir[j] := dir[j - 1] END;
				dir[R] := x
			END
		END SortDirs;

		PROCEDURE EnumerateSubDirectories(tree : WMTrees.Tree; node : WMTrees.TreeNode; dir : Strings.String);
		VAR name, path, filename, mask : Files.FileName; flags : SET; time, date, size : LONGINT;
			dirNode : WMTrees.TreeNode;
			td : TreeData; has : BOOLEAN;
			dirArray: POINTER TO ARRAY OF TreeData;
			i, sz: LONGINT;
		BEGIN
			tree.Acquire;
			IF tree.GetChildren(node) # NIL THEN tree.Release; RETURN END; (* assuming there will be no changes in the structures *)
			WHILE tree.GetChildren(node) # NIL DO tree.RemoveNode(tree.GetChildren(node)) END;
			COPY(dir^, mask);
			IF Strings.Length(mask) >= 1 THEN
				IF mask[Strings.Length(mask) - 1] = ':' THEN Strings.Append(mask, '*')
				ELSE Strings.Append(mask, '/*')
				END
			ELSE mask := '*'
			END;
			enumerator.Open(mask, {});
			has := FALSE;
			WHILE enumerator.HasMoreEntries() DO
				IF enumerator.GetEntry(name, flags, time, date, size) THEN
					IF Files.Directory IN flags THEN
						has := TRUE; INC(sz)
					END
				END
			END;
			enumerator.Reset();
			IF has THEN
				NEW(dirArray, sz);
				WHILE enumerator.HasMoreEntries() DO
					IF enumerator.GetEntry(name, flags, time, date, size) THEN
						IF Files.Directory IN flags THEN
							has := TRUE;
							Files.SplitPath(name, path, filename);
							NEW(td); td.path := WMComponents.NewString(name); td.name := WMComponents.NewString(filename);
							dirArray[i] := td; INC(i)
						END
					END
				END;
				SortDirs(dirArray^);
				FOR i := 0 TO sz-1 DO
					NEW(dirNode); td := dirArray[i];
					tree.SetNodeData(dirNode, td);
					tree.SetNodeCaption(dirNode, td.name);
					tree.InclNodeState(dirNode, WMTrees.NodeSubnodesUnknown);
					tree.AddChildNode(node, dirNode)
				END
			END;
			IF has THEN tree.SetNodeState(node, {WMTrees.NodeExpanded})
			ELSE tree.SetNodeState(node, {})
			END;
			enumerator.Close;
			tree.Release
		END EnumerateSubDirectories;

		PROCEDURE FillMountedFS(tree : WMTrees.Tree; node : WMTrees.TreeNode);
		VAR list: Files.FileSystemTable;
			prefixNode : WMTrees.TreeNode;
			td : TreeData;
			i : LONGINT;
			prefix : Files.Prefix;
		BEGIN
			Files.GetList(list);
			tree.Acquire;
			WHILE tree.GetChildren(node) # NIL DO tree.RemoveNode(tree.GetChildren(node)) END;
			FOR i := 0 TO LEN(list) - 1 DO
				NEW(prefixNode);
				tree.SetNodeCaption(prefixNode, WMComponents.NewString(list[i].prefix));
				COPY(list[i].prefix, prefix); Strings.Append(prefix, ":");
				NEW(td); td.path := WMComponents.NewString(prefix);
				tree.SetNodeData(prefixNode, td);
				tree.SetNodeState(prefixNode, {WMTrees.NodeSubnodesUnknown});
				tree.AddChildNode(node, prefixNode);
			END;
			tree.Release;
		END FillMountedFS;

	END DirectoryTree;

TYPE
	DirEntry* = OBJECT
	VAR
		name*, path- : Strings.String;
		time, date, size*: LONGINT;
		flags : SET;
		visible : BOOLEAN;
		node* : WMTrees.TreeNode;

		PROCEDURE &Init*(name, path : Strings.String; time, date, size : LONGINT; flags : SET);
		BEGIN
			SELF.name := name;
			SELF.path := path;
			SELF.time := time;
			SELF.date := date;
			SELF.size := size;
			SELF.flags := flags;
			visible := FALSE;
			NEW(node)
		END Init;

	END DirEntry;

	DirEntries* = POINTER TO ARRAY OF DirEntry;

	SelectionWrapper* = POINTER TO RECORD
		sel* : DirEntries;
		user* : ANY;
	END;

	StringWrapper* = POINTER TO RECORD
		string* : Strings.String;
	END;

	FileList* = OBJECT(WMComponents.VisualComponent)
	VAR
		grid : WMStringGrids.StringGrid;
		prefixSearch : WMProperties.BooleanProperty;
		path, filter : Strings.String;
		fullView, fromSearchReq : BOOLEAN;
		popup: WMPopups.Popup;
		enumerator : Files.Enumerator;
		dir : DirEntries;
		selection : DirEntries;
		nfiles, nofRows : LONGINT;
		px, py : LONGINT;
		colWidths : WMGrids.Spacings;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(GSFileList);
			SetGenerator("WMSystemComponents.GenFileList");
			(* new properties *) (* it is not possible to change this property at any time but we leave it for the moment *)
			NEW(prefixSearch, FileListPrefixSearchProt, NIL, NIL); properties.Add(prefixSearch);

			fullView := FALSE;
			fromSearchReq := FALSE;

			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			AddContent(grid);
			grid.SetExtDragDroppedHandler(MyDragDropped);
			grid.onClickSelected.Add(ClickSelected);
			grid.SetExtContextMenuHandler(ContextMenu);
			grid.onStartDrag.Add(MyStartDrag);
			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.model.SetNofRows(1);
			grid.fixedRows.Set(1);
			NEW(colWidths, 3);
			grid.model.SetCellText(0, 0, Strings.NewString("Filename"));
			grid.model.SetCellText(1, 0, Strings.NewString("Size"));
			grid.model.SetCellText(2, 0, Strings.NewString("Modified"));
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.model.Release;
			NEW(enumerator);

			SELF.path := Strings.NewString("");
			SELF.filter := Strings.NewString("");
		END Init;

		PROCEDURE SetSearchReqFlag*;
		BEGIN
			fromSearchReq := TRUE
		END SetSearchReqFlag;

		PROCEDURE GetSelection*() : DirEntries;
		VAR selection : DirEntries;
			l, t, r, b, i, j : LONGINT;
			p : ANY;
		BEGIN
			grid.model.Acquire;
			grid.GetSelection(l, t, r, b);
			NEW(selection, b- t + 1);
			j := 0;
			FOR i := t TO b DO
				p := grid.model.GetCellData(0, i);
				IF (p # NIL) & (p IS DirEntry) THEN
					selection[j] := p(DirEntry);
					INC(j)
				END
			END;
			grid.model.Release;
			RETURN selection
		END GetSelection;

		PROCEDURE ClickSelected(sender, data : ANY);
		VAR curSel : DirEntries;
			w : SelectionWrapper;
			p : Files.FileName;
		BEGIN
			IF (data # NIL) & (data IS DirEntry) THEN
				NEW(curSel, 1);
				curSel[0] := data(DirEntry);
				IF Files.Directory IN curSel[0].flags THEN
					COPY(curSel[0].path^, p); Strings.Append(p, curSel[0].name^);
					MakePathString(p);
					StartNewPath(Strings.NewString(p));
				ELSE
					NEW(w); w.sel := curSel; w.user := NIL;
					Open(sender, w)
				END
			END
		END ClickSelected;

		PROCEDURE HandleCommands(sender, data : ANY);
		VAR
			w : SelectionWrapper;
			filename : Files.FileName;
			command : ARRAY 1024 OF CHAR;
			position, res : LONGINT;
			msg : ARRAY 256 OF CHAR;
		BEGIN
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				w := data (SelectionWrapper);
				IF (w.user # NIL) & (w.user IS StringWrapper) & (w.user(StringWrapper).string # NIL) THEN
					IF (w.sel[0].path # NIL) THEN
						COPY(w.sel[0].path^, filename);
						Strings.Append(filename, w.sel[0].name^);
					ELSE
						COPY(w.sel[0].name^, filename);
					END;

					COPY(w.user(StringWrapper).string^, command);
					position := Strings.Pos(FilenamePlaceholder, command);
					IF (position # -1) THEN
						ASSERT(w.sel[0].name^ # FilenamePlaceholder);
						REPEAT
							Strings.Delete(command, position, Strings.Length(FilenamePlaceholder));
							Strings.Insert(filename, command, position);
							position := Strings.Pos(FilenamePlaceholder, command);
						UNTIL (position = -1);
					ELSE
						Strings.Append(command, " ");
						Strings.Append(command, w.sel[0].name^);
					END;

					Commands.Call(command, {}, res, msg);

					IF (res # Commands.Ok) THEN
						KernelLog.String("WMSystemComponents: Execution of command '");
						KernelLog.String(command); KernelLog.String("' failed, res: ");
						KernelLog.Int(res, 0);
						KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")");
						KernelLog.Ln;
					END;
				END;
			END;
		END HandleCommands;

		PROCEDURE ContextMenu(sender : ANY; x, y: LONGINT);
		VAR wmx, wmy : LONGINT;
			curSel : DirEntries;
			w : SelectionWrapper;
			sw : StringWrapper;
			filename, extension : Files.FileName;
			config : ARRAY 256 OF CHAR;
			ptr : ANY;
			element : XML.Element;
			enumerator : XMLObjects.Enumerator;
			name, value : XML.String;
		BEGIN
			px := x; py := y;
			NEW(popup);
			curSel := GetSelection();
			NEW(w); w.sel := curSel; w.user := NIL;
			IF ~fromSearchReq THEN
				(* allow operations on files such as renaming, duplicating, deleting, etc. only in not content-based search lists *)
				IF LEN(curSel) = 1 THEN
					popup.AddParButton("Open", Open, w);
					popup.AddParButton("Rename", Rename, w);
					popup.AddParButton("Duplicate", Duplicate, w);
					popup.AddParButton("EditText", EditText, w);
				END;
				popup.AddParButton("Tar", Tar, w);
				popup.AddParButton("Delete", Delete, w);
				IF (LEN(curSel) = 1) & (curSel[0] # NIL) & (curSel[0].name # NIL)  THEN
					Files.SplitExtension(curSel[0].name^, filename, extension);
					Strings.LowerCase(extension);
					config := "Filehandlers.";
					Strings.Append(config, extension);
					element := Configuration.GetSection(config);
					IF (element # NIL) THEN
						enumerator := element.GetContents();
						WHILE (enumerator.HasMoreElements()) DO
							ptr := enumerator.GetNext();
							IF (ptr # NIL) & (ptr IS XML.Element) THEN
								element := ptr (XML.Element);
								name := element.GetAttributeValue("name");
								IF (name # NIL) & (name^ # "Open") THEN
									value := element.GetAttributeValue("value");
									IF (value # NIL) THEN
										NEW(sw); sw.string := value;
										w.user := sw;
										popup.AddParButton(name^, HandleCommands, w);
									ELSE
										KernelLog.String("WMSystemComponents: No value attribute in section ");
										KernelLog.String(config); KernelLog.Ln;
									END;
								END;
							END;
						END;
					END;
				END;
			ELSE
				IF LEN(curSel) = 1 THEN
					(* only allow opening of files in this case *)
					popup.AddParButton("Open", Open, w);
				END
			END;
			grid.Acquire; grid.ToWMCoordinates(x, y, wmx, wmy); grid.Release;
			popup.Popup(wmx, wmy)
		END ContextMenu;

		PROCEDURE Rename(sender, data : ANY);
		VAR  d : DirEntry; rename : WMDialogs.MiniStringInput;
			wmx, wmy, res : LONGINT;
			name, op, np : ARRAY FileNameLength (* was 128*) OF CHAR;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel[0];
				IF d # NIL THEN
					grid.Acquire; grid.ToWMCoordinates(px, py, wmx, wmy); grid.Release;
					NEW(rename);
					COPY(d.name^, name);
					IF rename.Show(wmx, wmy, name) = WMDialogs.ResOk THEN
						IF name # d.name^ THEN
							COPY(d.path^, op); Strings.Append(op, d.name^);
							COPY(d.path^, np); Strings.Append(np, name);
							IF ~FileExists(np) OR
								(WMDialogs.Confirmation("Confirm overwriting existing file", np) = WMDialogs.ResYes) THEN
								Files.Rename(op, np, res);
								IF res # 0 THEN
									KernelLog.Int(res, 0); KernelLog.Ln;
									WMDialogs.Error("Renaming failed", np);
								END;
								Refresh(NIL, NIL)
							END
						END
					END
				END
			END
		END Rename;

		PROCEDURE Delete(sender, data : ANY);
		VAR  d : DirEntry;
			dr, res, i  : LONGINT;
			dp : Files.FileName;
			delete, always, never : BOOLEAN;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				always := FALSE; never := FALSE;
				FOR i := 0 TO LEN(data(SelectionWrapper).sel) - 1 DO
					d := data(SelectionWrapper).sel[i];
					delete := FALSE;
					IF d # NIL THEN
						COPY(d.path^, dp); Strings.Append(dp, d.name^);
						IF ~always & ~never THEN
							dr := WMDialogs.Message(WMDialogs.TConfirmation, "Confirm deleting file", dp,
								{WMDialogs.ResNo, WMDialogs.ResAbort, WMDialogs.ResYes, WMDialogs.ResAll});
							IF dr IN {WMDialogs.ResYes, WMDialogs.ResAll} THEN delete := TRUE END;
							IF dr = WMDialogs.ResAll THEN always := TRUE END;
							IF dr = WMDialogs.ResAbort THEN never := TRUE END;
						END;
						IF ~never & (delete OR always) THEN
							Files.Delete(dp, res);
							IF res # 0 THEN
								WMDialogs.Error("Deleting failed", dp)
							END;
							(* if the dialog was shown then visually update *)
							IF delete THEN Refresh(NIL, NIL) END
						END
					END
				END;
				(* end of the operation refresh list *)
				Refresh(NIL, NIL)
			END
		END Delete;

		PROCEDURE Duplicate(sender, data : ANY);
		VAR  d : DirEntry;
			name : ARRAY FileNameLength (* was 128*) OF CHAR;
			res : LONGINT;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel[0];
				IF d # NIL THEN
					COPY(d.path^, name);
					Strings.Append(name, d.name^);
					Files.Copy(name, res);
					IF res = 0 THEN
						Strings.Append(name, ".COPY");
						Files.Paste(name, res);
						WHILE res # 0 DO
							IF res = 2908 THEN
								IF WMDialogs.QueryString("File already exists. Enter a new Name", name) = WMDialogs.ResOk THEN
									Files.Paste(name, res);
								ELSE
									res := 0;
								END;
							ELSIF res = 2909 THEN
								IF WMDialogs.QueryString("FileName too long. Enter a new Name", name) = WMDialogs.ResOk THEN
									Files.Paste(name, res);
								ELSE
									res := 0;
								END;
							ELSE
								WMDialogs.Error("Error", "Some Error occoured while duplicating");
							END;
						END;
					END;
				END;
				Refresh(NIL, NIL);
			END;
		END Duplicate;

		PROCEDURE Tar(sender, data : ANY);
		VAR
			d : DirEntry; i, len : LONGINT;
			filename, format, temp : Files.FileName;
			buf: ARRAY BufSize OF CHAR;
			arc : Archives.Archive;
			file : Files.File; reader : Files.Reader;
			writer : Streams.Writer;

			PROCEDURE GetFormatFromFilename(CONST filename : ARRAY OF CHAR; VAR format : ARRAY OF CHAR);
			VAR file : ARRAY FileNameLength (* was 128*) OF CHAR;
			BEGIN
				IF filename = "" THEN COPY("tar", format);
				ELSE
					Strings.GetExtension(filename, file, format);
					Strings.LowerCase(format);
				 END
			END GetFormatFromFilename;

		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				IF (WMDialogs.QueryString("Enter Name of Archive: ", filename) = WMDialogs.ResOk) THEN

					GetFormatFromFilename(filename, format);
					arc := Archives.Old(filename, format);
					IF arc = NIL THEN
						arc := Archives.New(filename, format)
					END;

					KernelLog.String("File Manager: building "); KernelLog.String(filename);
					FOR i := 0 TO LEN(data(SelectionWrapper).sel) - 1 DO
						d := data(SelectionWrapper).sel[i];
						COPY(d.path^, temp); Strings.Append(temp, d.name^);
						file := Files.Old(temp);
						IF file # NIL THEN
							Files.OpenReader(reader, file, 0);
							arc.Acquire;
							Streams.OpenWriter(writer, arc.OpenSender(d.name^));

							REPEAT
								reader.Bytes(buf, 0, LEN(buf), len); writer.Bytes(buf, 0, len);
							UNTIL reader.res # 0;
							IF writer # NIL THEN writer.Update END;
							arc.Release;
						END;
					END;
					KernelLog.String(" - done!"); KernelLog.Ln;
					(* end of the operation refresh list *)
					Refresh(NIL, NIL)
				END
			END
		END Tar;

		PROCEDURE Open(sender, data : ANY);
		VAR d : DirEntry; filename : Files.FileName;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel[0];
				IF d # NIL THEN
					COPY(d.path^, filename);
					Strings.Append(filename, d.name^);
					FileHandlers.OpenFile(filename, NIL, NIL)
				END
			END
		END Open;

	PROCEDURE EditText(sender, data : ANY);
		VAR d : DirEntry; filename : Files.FileName; window : Notepad.Window; format : ARRAY 32 OF CHAR;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel[0];
				IF d # NIL THEN
					COPY(d.path^, filename);
					Strings.Append(filename, d.name^);
					format := "AUTO";
					NEW(window, NIL);
					window.editor.Load(filename, format);
				END
			END
		END EditText;
		
		(*
		PROCEDURE Open*(sender, data : ANY); 
VAR options : Options.Options; window : Window; filename : Files.FileName; format : ARRAY 32 OF CHAR;
BEGIN
	NEW(options);
	options.Add("f", "format", Options.String);
	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("format", format) THEN format := "AUTO"; END;
		NEW(window, NIL);
		IF context.arg.GetString(filename) THEN
			window.editor.Load(filename, format);
		END;
	END;
END Open;
		
		*)

		PROCEDURE MyDragDropped(x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			DragDropped(x, y, dragInfo)
		END MyDragDropped;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WM.DragInfo);
		VAR dropTarget : FilesDropTarget;
		BEGIN
			NEW(dropTarget, path, Refresh);
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo)
		END DragDropped;

		PROCEDURE MyStartDrag(sender, data : ANY);
		VAR img : WMGraphics.Image;
			c : WMGraphics.BufferCanvas;
			top, i : LONGINT;
		BEGIN
			selection := GetSelection();
			(* render to bitmap *)
			NEW(img);	Raster.Create(img, 100, 200, Raster.BGRA8888);
			NEW(c, img);
			c.SetColor(LONGINT(0FFFF00FFH));
			top := 0;
			FOR i := 0 TO LEN(selection) - 1 DO
				IF selection[i] # NIL THEN
					c.Fill(WMRectangles.MakeRect(0, top, 100, top + 25), 0FF80H, WMGraphics.ModeCopy);
					c.DrawString(3, top + 20, selection[i].name^);
					INC(top, 25)
				END
			END;
			IF grid.StartDrag(NIL, img, 0,0,DragArrived, NIL) THEN
				IF TraceDragging IN Trace THEN KernelLog.String("WMSystemComponents: DraggingStarted"); END;
			ELSE
				IF TraceDragging IN Trace THEN KernelLog.String("WMSystemComponents: Drag could not be started"); END;
			END;
		END MyStartDrag;

		PROCEDURE CopyFile(target : WMDropTarget.DropFiles; CONST local, remote : ARRAY OF CHAR; VAR res : LONGINT);
		VAR w : Streams.Writer;
			f : Files.File;
			r : Files.Reader;
			buf: ARRAY BufSize OF CHAR; len: LONGINT;
		BEGIN
			res := -1;
			f := Files.Old(local);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				target.OpenPut(remote, w, res);
				IF res = 0 THEN
					REPEAT
						r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
					UNTIL r.res # 0;
					target.ClosePut(res)
				END;
			END
		END CopyFile;

		PROCEDURE Refresh(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Refresh, sender, data)
			ELSE
				ScanPath; PrepareList;
				grid.Acquire;
				grid.SetSelection(-1, -1, -1, -1);
				selection := NIL;
				grid.Release;
			END
		END Refresh;

		PROCEDURE Resized;
		BEGIN
			grid.model.Acquire;
			IF fullView THEN
				colWidths[0] := (bounds.GetWidth() DIV 3)*2 - 20;
				colWidths[1] := bounds.GetWidth() DIV 6;
				colWidths[2] := bounds.GetWidth() DIV 6;
			ELSE
				colWidths[0] := bounds.GetWidth();
			END;
			grid.SetColSpacings(colWidths);
			grid.model.Release;
			Resized^;
		END Resized;

		PROCEDURE DragArrived(sender, data : ANY);
		VAR di : WM.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			i, res : LONGINT;
			sel : DirEntries;
			url : ARRAY 1024 OF CHAR;
			text : Texts.Text;
			textPos : Texts.TextPosition;
			nl: ARRAY 2 OF CHAR;
		BEGIN
			sel := selection;
			IF sel = NIL THEN RETURN END;

			IF (data # NIL) & (data IS WM.DragInfo) THEN
				di := data(WM.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget)
				ELSE RETURN
				END
			ELSE RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeFiles);
			IF itf # NIL THEN
				FOR i := 0 TO LEN(selection) - 1 DO
					IF selection[i] # NIL THEN
						COPY(selection[i].path^, url);
						Strings.Append(url, selection[i].name^);
						CopyFile(itf(WMDropTarget.DropFiles), url, selection[i].name^, res);
					END
				END;
				RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeURL);
			IF itf # NIL THEN
				FOR i := 0 TO LEN(selection) - 1 DO
					IF selection[i] # NIL THEN
						COPY(selection[i].path^, url);
						Strings.Append(url, selection[i].name^);
						itf(WMDropTarget.DropURLs).URL(url, res)
					END
				END;
				RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				text := itf(WMDropTarget.DropText).text;
				textPos := itf(WMDropTarget.DropText).pos;
				IF (text # NIL) & (textPos # NIL) THEN
					text.AcquireWrite;
					FOR i := 0 TO LEN(selection) - 1 DO
						IF selection[i] # NIL THEN
							COPY(selection[i].path^, url);
							Strings.Append(url, selection[i].name^);
							nl[0] := CHR(Texts.NewLineChar);
							nl[1] := 0X;
							Strings.Append(url, nl);
							TextUtilities.StrToText(text, textPos.GetPosition(), url)
						END
					END;
					text.ReleaseWrite
				END;
				RETURN
			END;
		END DragArrived;

		PROCEDURE ResetGrid*;
		BEGIN
			nofRows := 1;
			grid.model.Acquire;
			grid.model.SetNofRows(nofRows);
			grid.SetTopPosition(0, 0, TRUE);
			grid.SetSelection(0, 0, 0, 0);
			grid.model.Release
		END ResetGrid;

		PROCEDURE DisplayGrid*(CONST data : ARRAY OF DirEntry; noEl : LONGINT);
		VAR i, gridindex : LONGINT;
			d : DirEntry;
			t : ARRAY FileNameLength (* was 128*) OF CHAR;
		BEGIN
			grid.model.Acquire;
			grid.model.SetNofRows(nofRows + noEl);
			FOR i := 0 TO noEl -1 DO
				d := data[i];
				gridindex := nofRows + i;
				grid.model.SetCellText(0, gridindex , d.name);
				grid.model.SetCellData(0, gridindex, d);
				IF fullView THEN
					Strings.IntToStr(d.size, t);
					grid.model.SetCellText(1, gridindex, Strings.NewString(t));
					Strings.FormatDateTime(" yyyy mmm dd hh:nn ", Dates.OberonToDateTime(d.date, d.time), t);
					grid.model.SetCellText(2, gridindex, Strings.NewString(t));
				END;
				IF Files.Directory IN d.flags THEN
					grid.model.SetCellImage(0, gridindex, WMGraphics.LoadImage("icons.tar://Folder.png", TRUE))
				ELSE
					grid.model.SetCellImage(0, gridindex, NIL)
				END
			END;
			grid.model.Release;
			nofRows := nofRows + noEl;
		END DisplayGrid;

		PROCEDURE ToggleProps*;
		BEGIN
			grid.model.Acquire;
			IF fullView THEN
				fullView := FALSE;
				grid.model.SetNofCols(1);
				colWidths[0] := bounds.GetWidth();
			ELSE
				fullView := TRUE;
				grid.model.SetNofCols(3);
				colWidths[0] := (bounds.GetWidth() DIV 3)*2 - 20;
				colWidths[1] := bounds.GetWidth() DIV 6;
				colWidths[2] := bounds.GetWidth() DIV 6;
				grid.model.SetCellText(1, 0, Strings.NewString("Size"));
				grid.model.SetCellText(2, 0, Strings.NewString("Modified"));
			END;
			grid.SetColSpacings(colWidths);
			grid.model.Release;
			Refresh(NIL, NIL);
		END ToggleProps;

		PROCEDURE FillGridRow(rowNo : LONGINT; dir : DirEntry);
		VAR t : ARRAY FileNameLength (* was 128*) OF CHAR;
		BEGIN
			grid.model.SetCellText(0, rowNo, dir.name);
			grid.model.SetCellData(0, rowNo, dir);
			IF fullView THEN
				Strings.IntToStr(dir.size, t);
				grid.model.SetCellText(1, rowNo, Strings.NewString(t));
				Strings.FormatDateTime(" yyyy mmm dd hh:nn ", Dates.OberonToDateTime(dir.date, dir.time), t);
				grid.model.SetCellText(2, rowNo, Strings.NewString(t));
			END;
			IF Files.Directory IN dir.flags THEN
				grid.model.SetCellImage(0, rowNo, WMGraphics.LoadImage("icons.tar://Folder.png", TRUE))
			ELSE
				grid.model.SetCellImage(0, rowNo, NIL)
			END;
		END FillGridRow;

		PROCEDURE PrepareList;
		VAR i, vis : LONGINT; mask : ARRAY FileNameLength (* was 128*) OF CHAR; s : Strings.String;
		BEGIN
			IF dir = NIL THEN RETURN END;
			s := SELF.filter;
			mask := "";
			IF s # NIL THEN COPY(s^, mask) END;
			IF mask = "" THEN
				FOR i := 0 TO LEN(dir) - 1 DO dir[i].visible := TRUE END;
				vis := LEN(dir)
			ELSE
				IF prefixSearch.Get() & ( mask[Strings.Length(mask)] # "*") THEN Strings.Append(mask, "*") END;
				vis := 0;
				FOR i := 0 TO LEN(dir) - 1 DO
					IF Strings.Match(mask, dir[i].name^) THEN
						dir[i].visible := TRUE;
						INC(vis)
					ELSE dir[i].visible := FALSE
					END
				END;
			END;

			grid.model.Acquire;
			grid.model.SetNofRows(vis + 1);

			vis := 0;
			FOR i := 0 TO LEN(dir) - 1 DO
				IF dir[i].visible THEN
					FillGridRow(vis + 1, dir[i]);
					INC(vis)
				END
			END;
			grid.SetTopPosition(0, 0, TRUE);
			grid.model.Release;
		END PrepareList;


		PROCEDURE ScanPath;
		VAR s, pathS : Strings.String;
			i, l : LONGINT;
			name, path, filename, mask : Files.FileName; flags : SET; time, date, size : LONGINT;
			sorted : BOOLEAN;
		BEGIN
			s := SELF.path;
			IF s = NIL THEN RETURN END;
			COPY(s^, mask);
			IF Strings.Length(mask) > 1 THEN
				IF mask[Strings.Length(mask) - 1] = ':' THEN Strings.Append(mask, '*')
				ELSE Strings.Append(mask, '/*')
				END
			ELSE mask := '*'
			END;

			IF fullView THEN enumerator.Open(mask, {Files.EnumSize, Files.EnumTime}); ELSE enumerator.Open(mask, {}); END;
			nfiles := enumerator.size;
			i := 0;
			sorted := TRUE;
			NEW(dir, enumerator.size);
			WHILE enumerator.HasMoreEntries() DO
				IF enumerator.GetEntry(name, flags, time, date, size) THEN
					Files.SplitPath(name, path, filename);
					l := Strings.Length(path);
					path[l] := Files.PathDelimiter; path[l + 1] := 0X;
					IF (pathS = NIL) OR (pathS^ # path) THEN pathS := Strings.NewString(path) END;
					NEW(dir[i], Strings.NewString(filename), pathS, time, date, size, flags);
				END;
				INC(i)
			END;
			enumerator.Close;
			IF fullView THEN SortDirDate ELSE SortDir END;
		END ScanPath;

		PROCEDURE StartNewPath*(path : Strings.String);
		BEGIN
			SELF.path := path;
			ScanPath;
			PrepareList
		END StartNewPath;

		PROCEDURE StartNewFilter*(filter : Strings.String);
		BEGIN
			SELF.filter := filter;
			PrepareList
		END StartNewFilter;

		PROCEDURE GetNofFiles*() : LONGINT;
		BEGIN
			RETURN nfiles
		END GetNofFiles;

		(* binary insertion algorithm from "Algorithms and Data Structures" by N. Wirth *)
		PROCEDURE SortDir;
		VAR
			i, j, m, L, R : LONGINT;
			x : DirEntry;
			dirName, xName: Strings.String;
			dirFlag, xFlag: SHORTINT;
		BEGIN
			FOR i := 1 TO LEN(dir) - 1 DO
				x := dir[i]; L := 0; R := i; xName := Strings.NewString(x.name^); Strings.UpperCase(xName^);
				IF Files.Directory IN x.flags THEN xFlag := 0 ELSE xFlag := 1 END;
				WHILE L < R DO
					m := (L + R) DIV 2; dirName := Strings.NewString(dir[m].name^); Strings.UpperCase(dirName^);
					IF Files.Directory IN dir[m].flags THEN dirFlag := 0 ELSE dirFlag := 1 END;
					IF (dirFlag < xFlag) OR ((dirFlag=xFlag) & (UTF8Strings.Compare(dirName^, xName^) = UTF8Strings.CmpGreater)) THEN
						R := m
					ELSE
						L := m + 1
					END
				END;
				FOR j := i TO R + 1 BY -1 DO dir[j] := dir[j - 1] END;
				dir[R] := x
			END
		END SortDir;

		(* binary insertion algorithm from "Algorithms and Data Structures" by N. Wirth *)
		PROCEDURE SortDirDate;
		VAR
			i, j, m, L, R : LONGINT;
			x : DirEntry;
			dirTime,dirDate:LONGINT;
			dirFlag, xFlag: SHORTINT;
		BEGIN
			FOR i := 1 TO LEN(dir) - 1 DO
				x := dir[i]; L := 0; R := i;
				IF Files.Directory IN x.flags THEN xFlag := 0 ELSE xFlag := 1 END;
				WHILE L < R DO
					m := (L + R) DIV 2; 
					dirTime := dir[m].time; dirDate:= dir[m].date; 
					IF Files.Directory IN dir[m].flags THEN dirFlag := 0 ELSE dirFlag := 1 END;
					IF (dirFlag < xFlag) OR ((dirFlag=xFlag) & ((dirDate< x.date) OR ((dirDate=x.date)&(dirTime<x.time)))) THEN
						R := m
					ELSE
						L := m + 1
					END
				END;
				FOR j := i TO R + 1 BY -1 DO dir[j] := dir[j - 1] END;
				dir[R] := x
			END
		END SortDirDate;

	END FileList;

VAR
	DirTreePathProt : WMProperties.StringProperty;
	FileListPrefixSearchProt : WMProperties.BooleanProperty;

	GSonPathChanged, GSonPathChangedInfo : Strings.String;
	GSDirectoryTree, GSFileList : Strings.String;

PROCEDURE GenFileList*() : XML.Element;
VAR f : FileList;
BEGIN
	NEW(f); RETURN f;
END GenFileList;

PROCEDURE GenDirectoryTree*() : XML.Element;
VAR t : DirectoryTree;
BEGIN
	NEW(t); RETURN t;
END GenDirectoryTree;

PROCEDURE InitStrings;
BEGIN
	GSonPathChanged := Strings.NewString("onPathChanged");
	GSonPathChangedInfo := Strings.NewString("called when the path is changed");
	GSDirectoryTree := Strings.NewString("DirectoryTree");
	GSFileList := Strings.NewString("FileList");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(DirTreePathProt, NIL, Strings.NewString("CurrentPath"), Strings.NewString("contains the selected path"));
	NEW(FileListPrefixSearchProt, NIL, Strings.NewString("PrefixSearch"), Strings.NewString("match prefix only"));
	FileListPrefixSearchProt.Set(TRUE);
END InitPrototypes;

PROCEDURE FileExists*(CONST name : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN Files.Old(name) # NIL
END FileExists;

PROCEDURE MakePathString*(VAR s : ARRAY OF CHAR);
VAR l : LONGINT;
BEGIN
	l := Strings.Length(s);
	IF (l > 1) & (s[l - 1] # ":") & (s[l - 1] # "/") THEN Strings.Append(s, "/") END;
END MakePathString;

BEGIN
	InitStrings;
	InitPrototypes;
END WMSystemComponents.

SystemTools.Free WMSystemComponents ~

