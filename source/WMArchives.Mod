MODULE WMArchives; (** AUTHOR "FN,PL"; PURPOSE "GUI for Archives"; *)

IMPORT
	Commands, Streams, Modules, Files, FileHandlers, Archives, Strings, KernelLog, Texts, TextUtilities, Raster,
	WMDropTarget, WMComponents, WMStandardComponents, WMTrees, WMPopups,
	WMGraphics, WMDialogs, WMRectangles,
	WMEditors, WMRestorable, WMMessages, WMGrids, WMStringGrids, WMProperties, XML,
	WM := WMWindowManager;

CONST
	WindowWidth = 600; WindowHeight = 400;

	NameSize = 128;
	BufSize = 16*1024;

	TreePreviewSize = 16;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	EntryInfo = Archives.EntryInfo;

	 ArchiveDropInterface* = OBJECT(WMDropTarget.DropFiles)
	VAR
		out : Streams.Writer;
		at : ArchiveTree;
		parent : WMTrees.TreeNode;
		entryName, caption : Strings.String;

		PROCEDURE &New*(t : ArchiveTree; n : WMTrees.TreeNode);
		BEGIN
			at := t; parent := n
		END New;

		PROCEDURE OpenPut*(CONST remoteName : ARRAY OF CHAR; VAR outw : Streams.Writer; VAR res : LONGINT);
		BEGIN
			res := -1;
			caption := Strings.NewString(remoteName);
			entryName := at.GetPath(parent);
			Strings.Append(entryName^, remoteName);
			(* check if exists *)
			at.archive.Acquire;
			IF (at.archive.GetEntryInfo(entryName^) = NIL) OR
				(WMDialogs.Confirmation("Confirm overwriting", remoteName) = WMDialogs.ResYes) THEN
				Streams.OpenWriter(out, at.archive.OpenSender(entryName^));
				res := 0
			END;
			at.archive.Release;
			outw := out;
		END OpenPut;

		PROCEDURE ClosePut*(VAR res : LONGINT);
		VAR ei : EntryInfo;
		BEGIN
			IF out # NIL THEN out.Update END;
			at.archive.Acquire; ei := at.archive.GetEntryInfo(entryName^); at.archive.Release;
			at.AddChildNode(parent, caption, ei, TRUE);
		END ClosePut;

	END ArchiveDropInterface;

	ArchiveDropTarget* = OBJECT(WMDropTarget.DropTarget)
	VAR
		tree : ArchiveTree;
		node : WMTrees.TreeNode;

		PROCEDURE &New*(t : ArchiveTree; n : WMTrees.TreeNode);
		BEGIN
			tree := t; node := n
		END New;

		PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : ArchiveDropInterface;
		BEGIN
			IF type = WMDropTarget.TypeFiles THEN
				NEW(di, tree, node);
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;

	END ArchiveDropTarget;

	ArchiveTree* = OBJECT(WMStandardComponents.Panel)
	VAR
		tree -: WMTrees.Tree;
		treeView -: WMTrees.TreeView;
		archive : Archives.Archive;
		archiveName : ARRAY NameSize OF CHAR;
		popup : WMPopups.Popup;
		label : WMStandardComponents.Label;
		toolbar : WMStandardComponents.Panel;
		refreshBtn : WMStandardComponents.Button;
		px, py : LONGINT;
		draggedString : Strings.String;
		showFiles : WMProperties.BooleanProperty;
		showImagePreview : WMProperties.BooleanProperty;

		NodeChanged* : PROCEDURE {DELEGATE} (sender, data : ANY);

		PROCEDURE & Init*;
		BEGIN
			Init^;
				(* title *)
			NEW(label); label.alignment.Set(WMComponents.AlignTop);
			label.fillColor.Set(0CCCCCCFFH);
			label.SetCaption("Resource Index"); label.bounds.SetHeight(20);
			SELF.AddContent(label);
				(* toolbar *)
			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			SELF.AddContent(toolbar);
				(* refresh button *)
			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignLeft);
			refreshBtn.caption.SetAOC("Refresh");
			refreshBtn.onClick.Add(RefreshHandler);
			toolbar.AddContent(refreshBtn);
				(* treeView *)
			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			SELF.AddContent(treeView);
			treeView.SetExtContextMenuHandler(ContextMenu);
			treeView.SetDrawNodeProc(DrawTreeNode);
			treeView.SetMeasureNodeProc(MeasureTreeNode);
			treeView.SetExtDragDroppedHandler(MyDragDropped);
			treeView.onStartDrag.Add(MyStartDrag);
			tree := treeView.GetTree();

			NEW(showFiles, ProtShowFiles, NIL, NIL); properties.Add(showFiles);
			NEW(showImagePreview, ProtShowImgPrev, NIL, NIL); properties.Add(showImagePreview);

			SetNameAsString(StrArchiveTree)
		END Init;

		(** set a new model. the view is re-initialized *)
		PROCEDURE SetArchive*(archive : Archives.Archive);
		VAR i : LONGINT;
			node : WMTrees.TreeNode;
			name : Strings.String;
			archiveEntries : Archives.Index;
		BEGIN
			ASSERT(archive # NIL);
			SELF.archive := archive;
			NEW(node);
			tree.Acquire;
			tree.SetRoot(node);
			tree.InclNodeState(node, WMTrees.NodeAlwaysExpanded);
			RemovePartitionLabel(archive.name, archiveName);
			tree.SetNodeCaption(node, Strings.NewString(archiveName));
			tree.Release;
			treeView.SetFirstLine(0, TRUE);
			archive.Acquire; archiveEntries := archive.GetIndex(); archive.Release;
			FOR i := 0 TO LEN(archiveEntries^)-1 DO
				name := archiveEntries[i].GetName();
				InsertTreeNode(node, name, archiveEntries[i])
			END;
		END SetArchive;

		(* ----- handlers ------------------------------------------------- *)

		(* called when a drag-operation has been started *)
		PROCEDURE MyStartDrag(sender, data : ANY);
		VAR img : WMGraphics.Image;
			c : WMGraphics.BufferCanvas;
			w : LONGINT;
			a : ANY;
			s : Strings.String;
		BEGIN
			tree.Acquire; a := tree.GetNodeData(treeView.draggedNode); tree.Release;
			IF a # NIL THEN
				(* render to bitmap *)
				s := a(EntryInfo).GetName();
				NEW(draggedString, LEN(s^)+64);
				AppendToArchiveName(s^, draggedString^);
				w := Strings.Length(draggedString^) * 7;
				IF w > 400 THEN w := 400 END;
				NEW(img); Raster.Create(img, w, 25, Raster.BGRA8888);
				NEW(c, img); c.SetColor(LONGINT(0FFFF00FFH));
				c.Fill(WMRectangles.MakeRect(0, 0, w, 25), 0FF80H, WMGraphics.ModeCopy);
				c.DrawString(3, 20, draggedString^);
				IF treeView.StartDrag(a, img, 0,0, DragArrived, NIL) THEN KernelLog.String("DraggingStarted"); KernelLog.Ln
				ELSE KernelLog.String("Drag could not be started"); KernelLog.Ln
				END
			END;
		END MyStartDrag;

		(* called when an object dragged from this treeView has been dropped anywhere *)
		PROCEDURE DragArrived(sender, data : ANY);
		VAR di : WM.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			res : LONGINT;
			text : Texts.Text;
			textPos : Texts.TextPosition;
			caption, entryName : Strings.String;
			a : ANY;
			rec : Streams.Receiver;
		BEGIN
			IF (data # NIL) & (data IS WM.DragInfo) THEN
				di := data(WM.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget)
				ELSE RETURN
				END
			ELSE RETURN
			END;
				(* drop text *)
			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				text := itf(WMDropTarget.DropText).text;
				textPos := itf(WMDropTarget.DropText).pos;
				IF (text # NIL) & (textPos # NIL) THEN
					text.AcquireWrite;
					TextUtilities.StrToText(text, textPos.GetPosition(), draggedString^);
					text.ReleaseWrite;
					draggedString := NIL
				END;
				RETURN
			END;
				(* drop file *)
			itf := dt.GetInterface(WMDropTarget.TypeFiles);
			IF itf # NIL THEN
				tree.Acquire;
				caption := tree.GetNodeCaption(treeView.draggedNode);
				a := tree.GetNodeData(treeView.draggedNode);
				IF a = NIL THEN RETURN END;
				entryName := a(EntryInfo).GetName();
				tree.Release;
				archive.Acquire;
				rec := archive.OpenReceiver(entryName^);
				CopyFile(rec, itf(WMDropTarget.DropFiles), caption^, res);
				archive.Release;
				RETURN
			END;
		END DragArrived;

		(* refresh archive index *)
		PROCEDURE RefreshHandler(sender, data: ANY);
		BEGIN
			SetArchive(archive)
		END RefreshHandler;

		(* called when an object has been dropped on this treeView *)
		PROCEDURE MyDragDropped(x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			DragDropped(x, y, dragInfo);
			IF NodeChanged # NIL THEN NodeChanged(SELF, dragInfo) END
		END MyDragDropped;

		(* called by MyDraggedDropped *)
		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WM.DragInfo);
		VAR dropTarget : ArchiveDropTarget;
			parent : WMTrees.TreeNode;
			accept : BOOLEAN;
			data : ANY;
		BEGIN
			tree.Acquire;
			parent := treeView.GetNodeAtPos(x, y);
			data := tree.GetNodeData(parent);
			tree.Release;
			IF (parent = NIL) OR (data # NIL) THEN
				accept := FALSE
			ELSE
				accept := TRUE;
				NEW(dropTarget, SELF, parent);
				dragInfo.data := dropTarget;
			END;
			ConfirmDrag(accept, dragInfo)
		END DragDropped;

		(* pop up context-menu *)
		PROCEDURE ContextMenu(sender : ANY; x, y: LONGINT);
		VAR wmx, wmy : LONGINT;
			node : WMTrees.TreeNode;
			data : ANY;
		BEGIN
			node := treeView.GetNodeAtPos(x, y);
			IF node # NIL THEN
				px := x; py := y;
				NEW(popup);
				tree.Acquire; data := tree.GetNodeData(node); tree.Release;
				IF data = NIL THEN (* directory *)
					popup.AddParButton("Create Folder", CreateFolder, node);
				ELSE (* leaf-node *)
					popup.AddParButton("Delete", DeleteEntry, node);
					popup.AddParButton("Rename", RenameEntry, node);
				END;
				ToWMCoordinates(x, y, wmx, wmy);
				popup.Popup(wmx, wmy+40)
			END
		END ContextMenu;

		PROCEDURE CreateFolder(sender, data : ANY);
		VAR node : WMTrees.TreeNode;
			wmx, wmy : LONGINT;
			name : ARRAY 128 OF CHAR;
			input : WMDialogs.MiniStringInput;
		BEGIN
			tree.Acquire;
			ToWMCoordinates(px, py, wmx, wmy);
			NEW(input);
			IF input.Show(wmx, wmy, name) = WMDialogs.ResOk THEN
				IF name # "" THEN
					NEW(node);
					tree.InclNodeState(data(WMTrees.TreeNode), WMTrees.NodeExpanded);
					tree.AddChildNode(data(WMTrees.TreeNode), node);
					tree.SetNodeCaption(node, Strings.NewString(name));
				END
			END;
			tree.Release;
		END CreateFolder;

		PROCEDURE DeleteEntry(sender, data : ANY);
		VAR node : WMTrees.TreeNode;
			nodeData : ANY;
			name : Strings.String;
		BEGIN
			tree.Acquire;
			node := data(WMTrees.TreeNode);
			nodeData := tree.GetNodeData(data(WMTrees.TreeNode));
			name := nodeData(EntryInfo).GetName();
			KernelLog.String("Delete entry "); KernelLog.String(name^); KernelLog.Ln;
			archive.Acquire; archive.RemoveEntry(name^); archive.Release;
			tree.RemoveNode(node);
			tree.Release;
		END DeleteEntry;

		PROCEDURE RenameEntry(sender, data : ANY);
		VAR rename : WMDialogs.MiniStringInput;
			wmx, wmy : LONGINT;
			name, caption : ARRAY 128 OF CHAR;
			entryInfo : ANY;
			s : Strings.String;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			NEW(rename);
			tree.Acquire;
			entryInfo := tree.GetNodeData(data(WMTrees.TreeNode));
			s :=  entryInfo(EntryInfo).GetName();
			COPY(s^, name);
			ToWMCoordinates(px, py, wmx, wmy);
			IF rename.Show(wmx, wmy+40, name) = WMDialogs.ResOk THEN
				IF s^ # name THEN
					archive.Acquire; entryInfo := archive.RenameEntry(s^, name); archive.Release;
					IF entryInfo # NIL THEN
						tree.SetNodeData(data(WMTrees.TreeNode), entryInfo);
						RemovePath(name, caption);
						tree.SetNodeCaption(data(WMTrees.TreeNode), Strings.NewString(caption))
					END
				END
			END;
			tree.Release
		END RenameEntry;

		(* ----- internal functions ------------------------------------------*)

		(* concatenate the captions of all nodes from NODE to the tree's root separated by '/' *)
		PROCEDURE GetPath(node : WMTrees.TreeNode) : Strings.String;
		VAR result : Strings.String;

			(* recursive method *)
			PROCEDURE GetPathRecursive(node : WMTrees.TreeNode) : Strings.String;
			VAR parent : WMTrees.TreeNode;
				name, path : Strings.String;
			BEGIN
				IF node = tree.GetRoot() THEN NEW(path, 128); path[0] := 0X; RETURN path END;
				parent := tree.GetParent(node);
				path := GetPath(parent);
				name := tree.GetNodeCaption(node);
				Strings.Append(path^, name^);
				Strings.Append(path^, "/");
				RETURN path
			END GetPathRecursive;

		BEGIN
			tree.Acquire; result := GetPathRecursive(node); tree.Release;
			RETURN result
		END GetPath;

		(* return parent's child with name. return NIL if there is no such child *)
		PROCEDURE FindChildNode(parent : WMTrees.TreeNode; name : Strings.String) : WMTrees.TreeNode;
		VAR child : WMTrees.TreeNode;
			temp : Strings.String;
		BEGIN
			tree.Acquire;
			child := tree.GetChildren(parent);
			WHILE child # NIL DO
				temp := tree.GetNodeCaption(child);
				IF temp^ = name^ THEN
					tree.Release;
					RETURN child
				END;
				child := tree.GetNextSibling(child);
			END;
			tree.Release;
			RETURN NIL
		END FindChildNode;

		(* add a child with caption and data to parent. if REPLACE is TRUE, existing nodes with the same name will be replaced *)
		PROCEDURE AddChildNode(parent : WMTrees.TreeNode; caption : Strings.String; data : EntryInfo; replace : BOOLEAN);
		VAR child : WMTrees.TreeNode;
			imgName : Strings.String;
			imgPath : ARRAY 512 OF CHAR;
			img : WMGraphics.Image;
			state : SET;
		BEGIN
			IF (caption^ # "") THEN
				IF replace THEN child := FindChildNode(parent, caption) END;
				tree.Acquire;
				IF child = NIL THEN
					NEW(child);
					tree.AddChildNode(parent, child);
					tree.SetNodeCaption(child, caption);
					IF ~showFiles.Get() THEN
						state := tree.GetNodeState(child); INCL(state, WMTrees.NodeHidden);
						tree.SetNodeState(child, state)
					END
				END;
				tree.SetNodeData(child, data);
				IF showImagePreview.Get() THEN
					COPY(archive.name, imgPath);
					Strings.Append(imgPath, "://");
					imgName := data.GetName();
					Strings.Append(imgPath, imgName^); Strings.Append(imgPath, "");
					img := WMGraphics.LoadImage(imgPath, FALSE);
					tree.SetNodeImage(child, img);
				END;
				tree.Release;
			END
		END AddChildNode;

		(* recursive method insert a new node at the right place *)
		PROCEDURE InsertTreeNode(parent : WMTrees.TreeNode; name : Strings.String; data : EntryInfo);
		VAR posOfSlash : LONGINT;
			subnode : WMTrees.TreeNode;
			dirName, tail : Strings.String;
		BEGIN
			posOfSlash := Strings.Pos("/", name^);
			IF posOfSlash > -1 THEN (* go deeper in tree *)
				SplitString(name, dirName, tail, posOfSlash);
				subnode := FindChildNode(parent, dirName);
				IF subnode = NIL THEN (* add new directory *)
					NEW(subnode);
					tree.Acquire;
					tree.AddChildNode(parent, subnode);
					tree.SetNodeCaption(subnode, dirName);
					tree.Release
				END;
				InsertTreeNode(subnode, tail, data)
			ELSE (* add a leaf *)
				AddChildNode(parent, name, data, FALSE)
			END
		END InsertTreeNode;

		(* plug-in method for treeView *)
		PROCEDURE DrawTreeNode(canvas : WMGraphics.Canvas; w, h : LONGINT; node : WMTrees.TreeNode; state : SET);
		VAR dx, tdx, tdy, width, height : LONGINT; f : WMGraphics.Font;
			img : WMGraphics.Image;
			caption : Strings.String;
		BEGIN
			tree.Acquire;
			img := tree.GetNodeImage(node);
			caption := tree.GetNodeCaption(node);
			tree.Release;
			dx := 0;
			f := GetFont();
			IF img # NIL THEN
					IF img.width > 16 THEN width := 16 ELSE width := img.width END;
				IF img.height > 16 THEN height := 16 ELSE height := img.height END;
				canvas.ScaleImage(img, WMGraphics.MakeRectangle(0, 0, img.width, img.height), WMGraphics.MakeRectangle(0, 0, width, height), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBox);
				dx := 21;
			END;
			canvas.SetFont(f);
			IF WMTrees.StateSelected IN state THEN canvas.SetColor(treeView.clTextSelected.Get())
			ELSIF WMTrees.StateHover IN state THEN canvas.SetColor(treeView.clTextHover.Get())
			ELSE canvas.SetColor(treeView.clTextDefault.Get())
			END;
			f.GetStringSize(caption^, tdx, tdy);
			IF WMTrees.StateSelected IN state THEN canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clSelected.Get(), WMGraphics.ModeSrcOverDst)
			ELSIF WMTrees.StateHover IN state THEN canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clHover.Get(), WMGraphics.ModeSrcOverDst)
			END;

			IF caption # NIL THEN canvas.DrawString(dx, h - f.descent -1, caption^) END;
		END DrawTreeNode;

		(* plug-in method for treeView *)
		PROCEDURE MeasureTreeNode(node : WMTrees.TreeNode; VAR w, h : LONGINT);
		BEGIN
			h := TreePreviewSize; w := 400
		END MeasureTreeNode;

		(* ----- helper -------------------------------------------------- *)

		(* dest := archive.name || :// || src *)
		PROCEDURE AppendToArchiveName(CONST src: ARRAY OF CHAR;  VAR dest : ARRAY OF CHAR);
		VAR i, j : LONGINT;
		BEGIN
			i := 0;
			WHILE archiveName[i] # 0X DO dest[i] := archiveName[i]; INC(i) END;
			dest[i] := ':'; INC(i);
			dest[i] := '/'; INC(i);
			dest[i] := '/'; INC(i);
			j := 0;
			WHILE src[j] # 0X DO dest[i+j] := src[j]; INC(j) END
		END AppendToArchiveName;

	END ArchiveTree;

	NodeEntry = OBJECT
	VAR
		name, full, size : Strings.String;
		node : WMTrees.TreeNode;
	END NodeEntry;

	NodeList = POINTER TO ARRAY OF NodeEntry;

	SelectionWrapper = POINTER TO RECORD
		sel : NodeList;
	END;

	(* GUI Window to perform basic operations on Archives *)
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		topToolbar, statusbar, sidePanel : WMStandardComponents.Panel;
		load : WMStandardComponents.Button;
		statusLabel : WMStandardComponents.Label;
		filenameEdit : WMEditors.Editor;
		archiveTree : ArchiveTree;
		list : WMStringGrids.StringGrid;
		nodeContent, selection : NodeList;
		curArc : Archives.Archive;
		popup : WMPopups.Popup;
		px, py: LONGINT;
		node : WMTrees.TreeNode;
		curFiles, curFolders, curBytes : LONGINT;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent; xml : XML.Element; s : Strings.String;
		BEGIN
			IncCount;
			vc := CreateForm();

			Init(WindowWidth, WindowHeight, FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("WMArchives"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMArchives.png", TRUE));

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					xml := c.appData(XML.Element);
					s := xml.GetAttributeValue("file");
					IF s # NIL THEN Load(s^) END;
					Resized(GetWidth(), GetHeight())
				END
			ELSE
				WM.DefaultAddWindow(SELF)
			END;
			CSChanged;
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; resizerH : WMStandardComponents.Resizer;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient); panel.fillColor.Set(0FFFFFFFFH);

			(* -- topToolbar -- *)
			NEW(topToolbar); topToolbar.bounds.SetHeight(20); topToolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(topToolbar);

			NEW(filenameEdit); filenameEdit.alignment.Set(WMComponents.AlignLeft); filenameEdit.multiLine.Set(FALSE);
			filenameEdit.bounds.SetWidth(200); filenameEdit.fillColor.Set(0FFFFFFFFH); filenameEdit.tv.showBorder.Set(TRUE);
			filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); filenameEdit.onEnter.Add(LoadHandler);
			filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			topToolbar.AddContent(filenameEdit);

			NEW(load); load.caption.SetAOC("Load"); load.alignment.Set(WMComponents.AlignLeft); load.onClick.Add(LoadHandler);
			topToolbar.AddContent(load);

			(* -- statusbar -- *)
			NEW(statusbar); statusbar.bounds.SetHeight(20); statusbar.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(statusbar); statusbar.fillColor.Set(0CCCCCCFFH);

			NEW(statusLabel); statusLabel.bounds.SetWidth(WindowWidth); statusLabel.textColor.Set(0000000FFH); statusLabel.alignment.Set(WMComponents.AlignLeft);
			statusLabel.caption.SetAOC(" Total -- Folder(s) and -- Byte(s) in -- File(s)");
			statusbar.AddContent(statusLabel);

			(* -- main Archive Panel -- *)
			NEW(sidePanel); sidePanel.bounds.SetWidth(200); sidePanel.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(sidePanel);

			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignRight); sidePanel.AddContent(resizerH);

			NEW(archiveTree); archiveTree.alignment.Set(WMComponents.AlignClient);
			archiveTree.treeView.onClickNode.Add(NodeClicked); archiveTree.showFiles.Set(FALSE); archiveTree.showImagePreview.Set(FALSE);
			sidePanel.AddContent(archiveTree);
			archiveTree.NodeChanged := RefreshList;

			(* File-List *)
			NEW(list); list.alignment.Set(WMComponents.AlignClient);
			list.bounds.SetWidth(WindowWidth - 200);
			list.SetExtContextMenuHandler(ContextMenu);
			list.SetExtDragDroppedHandler(MyDragDropped);
			list.onClickSelected.Add(OpenFile);
			list.onStartDrag.Add(MyStartDrag);
			panel.AddContent(list);
			InitList;
			RETURN panel
		END CreateForm;

		PROCEDURE InitList;
		BEGIN
			list.model.Acquire;
			list.model.SetNofCols(2);
			list.model.SetNofRows(1);
			list.fixedRows.Set(1);
			list.adjustFocusPosition.Set(FALSE);
			list.model.SetCellText(0, 0, Strings.NewString("Filename"));
			list.model.SetCellText(1, 0, Strings.NewString("Size"));
			list.SetSelectionMode(WMGrids.GridSelectRows);
			list.SetSelection(-1, -1, -1, -1);
			AdjustTabSize;
			list.model.Release
		END InitList;

		PROCEDURE Resized(width, height : LONGINT);
		BEGIN
			Resized^(width, height);
			AdjustTabSize;
		END Resized;

		(* --- helpers --------------------------------------------------- *)

		(* adjusts the Tab sizes to the current windwo width *)
		PROCEDURE AdjustTabSize;
		VAR colWidths : WMGrids.Spacings; col0Width : LONGINT;
		BEGIN
			NEW(colWidths, 2);
			col0Width := (list.bounds.GetWidth() DIV 6)*5;
			colWidths[0] := col0Width;
			colWidths[1] := list.bounds.GetWidth() - col0Width;
			list.SetColSpacings(colWidths);
		END AdjustTabSize;

		(* removes the multiline input *)
		PROCEDURE FixFilename(VAR filename : ARRAY OF CHAR);
		VAR i : LONGINT; found : BOOLEAN;
		BEGIN
			i := 0;
			WHILE (i < LEN(filename)) & ~found DO
				IF ORD(filename[i]) = 10 THEN filename[i] := 0X; found := TRUE;
				ELSIF filename[i] = 0X THEN found := TRUE END;
				INC(i);
			END;
		END FixFilename;

		PROCEDURE GetFormatFromFilename(CONST filename : ARRAY OF CHAR; VAR format : ARRAY OF CHAR);
		VAR file : ARRAY 128 OF CHAR;
		BEGIN
			IF filename = "" THEN COPY("tar", format);
			ELSE
				Strings.GetExtension(filename, file, format);
				Strings.LowerCase(format);
			 END
		END GetFormatFromFilename;

		(* --- handlers --------------------------------------------------- *)

		PROCEDURE NodeClicked(sender, data : ANY);
		VAR curNode : WMTrees.TreeNode;
			tree : WMTrees.Tree; entry : NodeEntry;
			any : ANY;
			string : Strings.String; temp : ARRAY 128 OF CHAR;
			counter, tempInt : LONGINT;
			img : WMGraphics.Image;
		BEGIN
			IF (sender IS WMTrees.TreeView) & (data IS WMTrees.TreeNode) THEN
				node := data(WMTrees.TreeNode);
				tree := sender(WMTrees.TreeView).GetTree();

				tree.Acquire;
				(* count elements in node *)
				curNode := tree.GetChildren(node);

				counter := 0;
				WHILE curNode # NIL DO
					IF tree.GetNodeData(curNode) # NIL THEN INC(counter) END;
					curNode := tree.GetNextSibling(curNode);
				END;

				(* build array with elements *)
				NEW(nodeContent, counter);
				curNode := tree.GetChildren(node); counter := 0; curFiles := 0; curFolders := 0; curBytes := 0;
				WHILE curNode # NIL DO
					NEW(entry);
					entry.node := curNode;
					any := tree.GetNodeData(curNode);
					IF any # NIL THEN
						string := any(Archives.EntryInfo).GetName();
						entry.full := Strings.NewString(string^);
						tempInt := any(Archives.EntryInfo).GetSize();
						Strings.IntToStr(tempInt, string^);
						entry.size := string;

						entry.name := tree.GetNodeCaption(curNode);
						nodeContent[counter] := entry;
						INC(counter); INC(curFiles); INC(curBytes, tempInt)
					ELSE
						INC(curFolders)
					END;
					curNode := tree.GetNextSibling(curNode)
				END;
				tree.Release;

				COPY("icons.tar://", temp);
				Strings.Append(temp, "File.png");
				img := WMGraphics.LoadImage(temp, TRUE);
				(* fill list with array *)
				list.model.Acquire;
				list.model.SetNofRows(counter+1);
				WHILE counter > 0 DO
					list.model.SetCellText(0, counter, nodeContent[counter-1].name);
					list.model.SetCellText(1, counter, nodeContent[counter-1].size);
					list.model.SetCellData(0, counter, nodeContent[counter-1]);
					list.model.SetCellImage(0, counter, img);
					DEC(counter);
				END;
				list.model.Release;
				UpdateStatusbar;
			END
		END NodeClicked;

		PROCEDURE LoadHandler(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR;
		BEGIN
			filenameEdit.GetAsString(filename);
			FixFilename(filename);
			filenameEdit.SetAsString(filename);
			Load(filename)
		END LoadHandler;

		PROCEDURE Load(CONST filename : ARRAY OF CHAR);
		VAR format : ARRAY 16 OF CHAR;
		BEGIN
			GetFormatFromFilename(filename, format);
			curArc := Archives.Old(filename, format);
			IF curArc = NIL THEN
				curArc := Archives.New(filename, format)
			END;
			IF curArc # NIL THEN filenameEdit.SetAsString(curArc.name); archiveTree.SetArchive(curArc) END
		END Load;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR data : XML.Element; a : XML.Attribute; n : ARRAY 16 OF CHAR;
			filename : ARRAY 256 OF CHAR;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data);  n := "WMArchivesData"; data.SetName(n);
					filenameEdit.GetAsString(filename);
					NEW(a); n := "file"; a.SetName(n); a.SetValue(filename); data.AddAttribute(a);
					x.ext(WMRestorable.Storage).Add("WMArchives", "WMArchives.Restore", SELF, data)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE ContextMenu(sender : ANY; x, y: LONGINT);
		VAR curSel : NodeList;
			w : SelectionWrapper;
		BEGIN
			px := x; py := y;
			NEW(popup);
			curSel := GetSelection();
			NEW(w); w.sel := curSel;

			IF LEN(curSel) = 0 THEN RETURN END;
			popup.AddParButton("Open", Open, w);
			popup.AddParButton("Delete", DeleteEntries, w);
			IF LEN(curSel) = 1 THEN
				popup.AddParButton("Rename", RenameEntry, w)
			END;

			list.ToWMCoordinates(x, y, px, py);
			popup.Popup(px, py)
		END ContextMenu;

		PROCEDURE GetSelection() : NodeList;
		VAR selection : NodeList;
			l, t, r, b, i, j : LONGINT;
			p : ANY;
		BEGIN
			list.model.Acquire;
			list.GetSelection(l, t, r, b);
			NEW(selection, b- t + 1);
			j := 0;
			FOR i := t TO b DO
				p := list.model.GetCellData(0, i);
				IF (p # NIL) & (p IS NodeEntry) THEN
					selection[j] := p(NodeEntry);
					INC(j)
				END
			END;
			list.model.Release;
			RETURN selection
		END GetSelection;

		PROCEDURE Open(sender, data : ANY);
		VAR d: NodeList; i : LONGINT;
		BEGIN
			IF (popup # NIL) THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel;
				IF (d # NIL) THEN
					FOR i := 0 TO LEN(d)-1 DO
						OpenFile(SELF, d[i]);
					END;
				END;
			END;
		END Open;

		PROCEDURE OpenFile(sender, data : ANY);
		VAR filename : Files.FileName;
		BEGIN
			IF (data # NIL) & (data IS NodeEntry) THEN
				COPY(curArc.name, filename);
				Strings.Append(filename, "://");
				Strings.Append(filename, data(NodeEntry).full^);
				FileHandlers.OpenFile(filename, NIL, SELF);
			END;
		END OpenFile;

		PROCEDURE RenameEntry(sender, data : ANY);
		VAR rename : WMDialogs.MiniStringInput;
			name, caption : ARRAY 128 OF CHAR;
			entryInfo : ANY; entry : NodeEntry;
			s : Strings.String;
		BEGIN
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				entry := data(SelectionWrapper).sel[0];
				IF entry # NIL THEN
					NEW(rename);
					archiveTree.tree.Acquire;

					entryInfo := archiveTree.tree.GetNodeData(entry.node);
					s :=  entryInfo(EntryInfo).GetName();
					COPY(s^, name);
					IF rename.Show(px, py, name) = WMDialogs.ResOk THEN
						IF s^ # name THEN
							archiveTree.archive.Acquire; entryInfo := archiveTree.archive.RenameEntry(s^, name); archiveTree.archive.Release;
							IF entryInfo # NIL THEN
								archiveTree.tree.SetNodeData(entry.node, entryInfo);
								RemovePath(name, caption);
								archiveTree.tree.SetNodeCaption(entry.node, Strings.NewString(caption));
								NodeClicked(archiveTree.treeView, archiveTree.tree.GetParent(entry.node))
							END
						END
					END;
					archiveTree.tree.Release;
				END
			END
		END RenameEntry;

		PROCEDURE DeleteEntries(sender, data : ANY);
		VAR parent : WMTrees.TreeNode;
			entry : NodeEntry; entryInfo : ANY; s : Strings.String;
			dr, i : LONGINT; name : ARRAY 128 OF CHAR;
			delete, always, never : BOOLEAN;
		BEGIN
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				always := FALSE; never := FALSE;
				archiveTree.tree.Acquire;
				FOR i := 0 TO LEN(data(SelectionWrapper).sel) - 1 DO
					entry := data(SelectionWrapper).sel[i];
					delete := FALSE;
					IF entry # NIL THEN
						entryInfo := archiveTree.tree.GetNodeData(entry.node);
						parent := archiveTree.tree.GetParent(entry.node);
						s :=  entryInfo(EntryInfo).GetName();
						COPY(s^, name);

						IF ~always & ~never THEN
							dr := WMDialogs.Message(WMDialogs.TConfirmation, "Confirm deleting file", name,
								{WMDialogs.ResNo, WMDialogs.ResAbort, WMDialogs.ResYes, WMDialogs.ResAll});
							IF dr IN {WMDialogs.ResYes, WMDialogs.ResAll} THEN delete := TRUE END;
							IF dr = WMDialogs.ResAll THEN always := TRUE END;
							IF dr = WMDialogs.ResAbort THEN never := TRUE END;
						END;
						IF ~never & (delete OR always) THEN
							archiveTree.archive.Acquire; archiveTree.archive.RemoveEntry(name); archiveTree.archive.Release;
							archiveTree.tree.RemoveNode(entry.node);
							NodeClicked(archiveTree.treeView, parent)
						END
					END
				END;
				archiveTree.tree.Release;
			END
		END DeleteEntries;

		PROCEDURE RefreshList(sender, data : ANY);
		VAR selected : WMTrees.TreeNode;
		BEGIN
			IF node # NIL THEN selected := node;
			ELSE selected := archiveTree.tree.GetRoot() END;
			NodeClicked(archiveTree.treeView, selected)
		END RefreshList;

		PROCEDURE UpdateStatusbar;
		VAR statusStr, tempStr : ARRAY 256 OF CHAR;
		BEGIN
			COPY(" Total ", statusStr);
			Strings.IntToStr(curFolders, tempStr); Strings.Append(statusStr, tempStr);
			Strings.Append(statusStr, " Folder(s) and ");
			Strings.IntToStr(curBytes, tempStr); Strings.Append(statusStr, tempStr);
			Strings.Append(statusStr, " Byte(s) in ");
			Strings.IntToStr(curFiles, tempStr); Strings.Append(statusStr, tempStr);
			Strings.Append(statusStr, " File(s)");
			statusLabel.caption.SetAOC(statusStr);
		END UpdateStatusbar;

		(* ----- drag operations ----------------------------------------- *)

		(* called when an object has been dropped on the file-list *)
		PROCEDURE MyDragDropped(x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			ListDragDropped(x, y, dragInfo);
			RefreshList(SELF, node)
		END MyDragDropped;

		(* called by MyDraggedDropped *)
		PROCEDURE ListDragDropped(x, y : LONGINT; dragInfo : WM.DragInfo);
		VAR dropTarget : ArchiveDropTarget;
			parent : WMTrees.TreeNode;
			accept : BOOLEAN;
			data : ANY;
		BEGIN
			archiveTree.tree.Acquire;
			IF node # NIL THEN parent := node
			ELSE parent := archiveTree.tree.GetRoot() END;

			data := archiveTree.tree.GetNodeData(parent);
			archiveTree.tree.Release;
			IF (parent = NIL) OR (data # NIL) THEN
				accept := FALSE
			ELSE
				accept := TRUE;
				NEW(dropTarget, archiveTree, parent);
				dragInfo.data := dropTarget;
			END;
			ConfirmDrag(accept, dragInfo)
		END ListDragDropped;

		(* called when a drag-operation has been started *)
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
			IF list.StartDrag(NIL, img, 0,0,ListDragArrived, NIL) THEN KernelLog.String("Dragging started")
			ELSE KernelLog.String("Drag could not be started")
			END;
		END MyStartDrag;

		(* called when an object dragged from the list has been dropped anywhere *)
		PROCEDURE ListDragArrived(sender, data : ANY);
		VAR di : WM.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			i, res : LONGINT;
			sel : NodeList;
			url, caption : ARRAY 1024 OF CHAR;
			text : Texts.Text;
			textPos : Texts.TextPosition;
			rec : Streams.Receiver;
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

			(* File *)
			itf := dt.GetInterface(WMDropTarget.TypeFiles);
			IF itf # NIL THEN
				FOR i := 0 TO LEN(selection) - 1 DO
					IF selection[i] # NIL THEN
						COPY(selection[i].full^, url);
						COPY(selection[i].name^, caption);
						archiveTree.archive.Acquire;
						rec := archiveTree.archive.OpenReceiver(url);
						CopyFile(rec, itf(WMDropTarget.DropFiles), caption, res);
						archiveTree.archive.Release;
					END
				END;
				RETURN
			END;
			(* Text *)
			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				text := itf(WMDropTarget.DropText).text;
				textPos := itf(WMDropTarget.DropText).pos;
				IF (text # NIL) & (textPos # NIL) THEN
					text.AcquireWrite;
					FOR i := 0 TO LEN(selection) - 1 DO
						IF selection[i] # NIL THEN
							COPY(selection[i].name^, url);
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
		END ListDragArrived;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount;
		END Close;

	END Window;

VAR
	nofWindows : LONGINT;
	ProtShowFiles, ProtShowImgPrev : WMProperties.BooleanProperty;
	StrArchiveTree : Strings.String;

(* ----- helpers ------------------------------------------------------- *)

(* copy the head of string to head and the tail of string to tail *)
PROCEDURE SplitString(string : Strings.String;  VAR head, tail : Strings.String; index : LONGINT);
VAR i : LONGINT;
BEGIN
	NEW(head, index+1);
	NEW(tail, LEN(string^)-index);
	(* head *)
	i := 0;
	WHILE i < index DO
		head[i] := string[i];
		INC(i)
	END;
	head[i] := 0X;
	(* tail *)
	i := 0;
	WHILE string[index+1+i] # 0X DO
		tail[i] := string[index+1+i];
		INC(i)
	END;
	tail[i] := 0X
END SplitString;

(* "path1/path2/.../name"  =>  "name" *)
PROCEDURE RemovePath(CONST src : ARRAY OF CHAR; VAR dest : ARRAY OF CHAR);
VAR i, j : LONGINT;
BEGIN
	i := LEN(src) - 1;
	WHILE (i > 0) & (src[i] # '/') DO DEC(i) END;
	IF i > 0 THEN INC(i) END;
	FOR j := 0 TO LEN(src) - 1 - i DO
		dest[j] := src[i];
		INC(i)
	END
END RemovePath;

(* "PART:file.ext"  =>  "file.ext" *)
PROCEDURE RemovePartitionLabel(CONST src : ARRAY OF CHAR; VAR dest : ARRAY OF CHAR);
VAR i, j : LONGINT;
BEGIN
	i := 0;
	WHILE (i < LEN(src)) & (src[i] # ':') DO INC(i) END;
	IF i = LEN(src) THEN
		COPY(src, dest)
	ELSE
		j := 0;
		WHILE j + i + 1 < LEN(src) DO
			dest[j] := src[i+j+1];
			INC(j)
		END
	END
END RemovePartitionLabel;

(* transfer data from rec to target *)
PROCEDURE CopyFile(rec : Streams.Receiver; target : WMDropTarget.DropFiles; CONST remote : ARRAY OF CHAR; VAR res : LONGINT);
VAR w : Streams.Writer; r : Streams.Reader; buf: ARRAY BufSize OF CHAR; len: LONGINT;
BEGIN
	res := -1;
	Streams.OpenReader(r, rec);
	target.OpenPut(remote, w, res);
	IF res = 0 THEN
		REPEAT
			r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
		UNTIL r.res # 0;
		target.ClosePut(res)
	END
END CopyFile;

(* ---- window stuff -------------------------------------------------------------------- *)

PROCEDURE InitPrototypes;
VAR plArchiveTree : WMProperties.PropertyList;
BEGIN
	(* archive tree *)
	NEW(plArchiveTree); WMComponents.propertyListList.Add("Archive Tree", plArchiveTree);
	NEW(ProtShowFiles, NIL, Strings.NewString("Show Files"), Strings.NewString("Enables Tree to show the Files")); plArchiveTree.Add(ProtShowFiles);
	ProtShowFiles.Set(TRUE);
	NEW(ProtShowImgPrev, NIL, Strings.NewString("Show Image Preview"), Strings.NewString("Enables Tree to show Image Previews")); plArchiveTree.Add(ProtShowImgPrev);
	ProtShowImgPrev.Set(TRUE);
	StrArchiveTree := Strings.NewString("Archive Tree")
END InitPrototypes;

PROCEDURE Open*(context : Commands.Context);
VAR window : Window; filename : Files.FileName;
BEGIN
	NEW(window, NIL);
	IF context.arg.GetString(filename) THEN
		window.Load(filename);
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR win : Window;
BEGIN
	ASSERT(context # NIL);
	NEW(win, context)
END Restore;

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
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
END WMArchives.

WMArchives.Open ~
WMArchives.Open traditional.skin ~
SystemTools.Free WMArchives ~