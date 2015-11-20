MODULE WMFTPClient; (** AUTHOR "PL"; PURPOSE "FTPClient GUI"; *)

IMPORT
	WMStandardComponents, WMWindowManager, WMComponents, FTPClient, TextUtilities,
	WMMessages, WMGraphics, Strings, WMRectangles, Modules, KernelLog, WMPopups, Raster, Texts,
	WMEditors, WMGrids, WMStringGrids, WMDialogs, WMProperties, WMDropTarget, Streams;

CONST
	BufSize = 16*1024; (* internal buffer size, used for file transfer *)

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	SelectionWrapper = POINTER TO RECORD
		sel : FTPClient.FTPListing;
	END;

	 FTPDropInterface = OBJECT(WMDropTarget.DropFiles)
	 VAR w : Streams.Writer;
	 	ftp : FTPClient.FTPClient;

		PROCEDURE &New*(ftp : FTPClient.FTPClient);
		BEGIN
			SELF.ftp := ftp
		END New;

		PROCEDURE OpenPut*(CONST remoteName : ARRAY OF CHAR; VAR outw : Streams.Writer; VAR res : LONGINT);
		BEGIN
			res := -1;
			IF ftp = NIL THEN RETURN END;
			KernelLog.String("Uploading File: "); KernelLog.String(remoteName); KernelLog.Ln;
			ftp.OpenPut(remoteName, outw, res);
			IF res # 0 THEN KernelLog.String("Error: "); KernelLog.String(ftp.msg); KernelLog.Ln;
			ELSE w := outw END
		END OpenPut;

		PROCEDURE ClosePut*(VAR res : LONGINT);
		BEGIN
			res := -1;
			KernelLog.String("ClosePut called"); KernelLog.Ln;
			IF ftp = NIL THEN RETURN END;
			IF w # NIL THEN w.Update END;
			ftp.ClosePut(res)
		END ClosePut;

	END FTPDropInterface;

	FTPDropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR ftp : FTPClient.FTPClient;

		PROCEDURE &New*(ftp : FTPClient.FTPClient);
		BEGIN
			SELF.ftp := ftp
		END New;

		PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : FTPDropInterface;
		BEGIN
			IF type = WMDropTarget.TypeFiles THEN
				NEW(di, ftp);
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;
	END FTPDropTarget;

	(* Client Window *)
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		topToolbar, statusbar : WMStandardComponents.Panel;
		statusLabel, conLabel, busyLabel : WMStandardComponents.Label;
		connect, refresh : WMStandardComponents.Button;
		address, port, cmd : WMEditors.Editor;
		fullList : WMStandardComponents.Checkbox;
		ftpPanel : FTPPanel;
		ftp : FTPClient.FTPClient;

		connected : BOOLEAN;
		busy : BOOLEAN;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc); ftpPanel.SetColSize;
			SetTitle(Strings.NewString("WMFTPClient"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMFTPClient.png", TRUE));
			WMWindowManager.DefaultAddWindow(SELF);

			connected := FALSE;
		END New;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel, pnl : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			bearing : WMRectangles.Rectangle;

		BEGIN
			NEW(panel); panel.bounds.SetExtents(600, 400); panel.fillColor.Set(LONGINT(0CCCCCCFFH));

			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			(* --- Toolbar --- *)
			NEW(topToolbar); topToolbar.bounds.SetHeight(20); topToolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(topToolbar);

			NEW(label); label.bounds.SetWidth(40); label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC(" Host: "); label.textColor.Set(0000000FFH); topToolbar.AddContent(label);

			NEW(address); address.bounds.SetWidth(150); address.alignment.Set(WMComponents.AlignLeft);
			address.tv.textAlignV.Set(WMGraphics.AlignCenter);
			address.multiLine.Set(FALSE); address.fillColor.Set(LONGINT(0FFFFFFFFH)); address.tv.showBorder.Set(TRUE);
			address.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			address.onEnter.Add(ConnectHandler);
			topToolbar.AddContent(address);
			address.SetAsString("bluebottle.ethz.ch");

			NEW(label); label.bounds.SetWidth(40); label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC(" Port: "); label.textColor.Set(0000000FFH); topToolbar.AddContent(label);

			NEW(port); port.bounds.SetWidth(50); port.alignment.Set(WMComponents.AlignLeft);
			port.tv.textAlignV.Set(WMGraphics.AlignCenter);
			port.multiLine.Set(FALSE); port.fillColor.Set(LONGINT(0FFFFFFFFH)); port.tv.showBorder.Set(TRUE);
			port.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1)); port.SetAsString("21");
			topToolbar.AddContent(port);

			NEW(connect); connect.bounds.SetWidth(100); connect.alignment.Set(WMComponents.AlignLeft);
			connect.caption.SetAOC("Connect"); connect.onClick.Add(ConnectHandler);
			topToolbar.AddContent(connect);

			NEW(refresh); refresh.bounds.SetWidth(100); refresh.alignment.Set(WMComponents.AlignLeft);
			refresh.caption.SetAOC("Refresh"); refresh.onClick.Add(RefreshHandler);
			topToolbar.AddContent(refresh);

			NEW(fullList); fullList.bearing.Set(bearing); fullList.bounds.SetWidth(14); fullList.alignment.Set(WMComponents.AlignLeft);
			topToolbar.AddContent(fullList); fullList.state.Set(1);

			NEW(label); label.bounds.SetWidth(100); label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC(" Full Listing"); label.textColor.Set(0000000FFH); topToolbar.AddContent(label);

			(* --- statusbar --- *)
			NEW(statusbar); statusbar.bounds.SetHeight(20); statusbar.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(statusbar);

			NEW(conLabel); conLabel.bounds.SetWidth(14); conLabel.alignment.Set(WMComponents.AlignLeft);
			statusbar.AddContent(conLabel); conLabel.bearing.Set(bearing); conLabel.fillColor.Set(LONGINT(0CC0000FFH));

			NEW(busyLabel); busyLabel.bounds.SetWidth(14); busyLabel.alignment.Set(WMComponents.AlignLeft);
			statusbar.AddContent(busyLabel); busyLabel.bearing.Set(bearing); busyLabel.fillColor.Set(LONGINT(0888888FFH));

			NEW(statusLabel); statusLabel.bounds.SetWidth(400); statusLabel.alignment.Set(WMComponents.AlignLeft);
			statusLabel.textColor.Set(0000000FFH);
			(* statusbar.AddContent(statusLabel); *)

			(* --- cmd --- *)
			NEW(pnl); pnl.bounds.SetHeight(20); pnl.alignment.Set(WMComponents.AlignBottom);
			(* panel.AddContent(pnl); *)

			NEW(label); label.bounds.SetWidth(80); label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC(" Command: "); label.textColor.Set(0000000FFH); pnl.AddContent(label);

			NEW(cmd); cmd.alignment.Set(WMComponents.AlignClient);
			cmd.tv.textAlignV.Set(WMGraphics.AlignCenter);
			cmd.multiLine.Set(FALSE); cmd.fillColor.Set(LONGINT(0FFFFFFFFH)); cmd.tv.showBorder.Set(TRUE);
			cmd.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			cmd.onEnter.Add(CommandHandler);
			pnl.AddContent(cmd);

			statusbar.AddContent(pnl);

			(* --- FTP main panel --- *)
			NEW(ftpPanel); ftpPanel.alignment.Set(WMComponents.AlignClient); ftpPanel.fillColor.Set(LONGINT(0FFFFFFFFH));
			panel.AddContent(ftpPanel);
			ftpPanel.owner := SELF;

			RETURN panel
		END CreateForm;

		(* -- Handlers -------------------------------------- *)

		PROCEDURE ConnectHandler(sender, data : ANY);
		BEGIN
			IF connected THEN Disconnect ELSE Connect END
		END ConnectHandler;

		PROCEDURE Connect;
		VAR user, pass, host, temp : ARRAY 64 OF CHAR;
			port, res : LONGINT;
		BEGIN
			IF ftp # NIL THEN
				KernelLog.String("Already open"); KernelLog.Ln; RETURN
			END;
			user := "anonymous";
			pass := "anonymous@somewhere.net";
			IF WMDialogs.QueryString("Enter Username:", user) = WMDialogs.ResOk THEN
				IF WMDialogs.QueryPassword("Enter Password", pass) = WMDialogs.ResOk THEN
					address.GetAsString(host);
					IF (host = "") THEN RETURN END; (* check addy *)
					SELF.port.GetAsString(temp); Strings.StrToInt(temp, port);

					NEW(ftp);
					ftp.Open(host, user, pass, port, res);
					KernelLog.String(ftp.msg);
					IF res = 0 THEN
						KernelLog.String("Connected"); KernelLog.Ln;
						SetConnected(TRUE);
						RefreshHandler(SELF, NIL);
					ELSE
						ftp := NIL;
						KernelLog.String("Connecting failed"); KernelLog.Ln;
					END
				END
			END
		END Connect;

		PROCEDURE Disconnect;
		VAR res : LONGINT;
		BEGIN
			IF ftp = NIL THEN
				KernelLog.String("not connected"); KernelLog.Ln;
				RETURN
			END;
			ftp.Close(res);
			KernelLog.String("closed."); KernelLog.String(ftp.msg); KernelLog.Ln;
			ftp := NIL; ftpPanel.curList := NIL; ftpPanel.nofEntries := 0; ftpPanel.PrepareList; ftpPanel.pathEdit.SetAsString("/");
			SetConnected(FALSE);
			SetBusy(FALSE)
		END Disconnect;

		PROCEDURE Close;
		BEGIN
			IF ftp # NIL THEN Disconnect END;
			Close^;
			DecCount
		END Close;

		PROCEDURE CommandHandler(sender, data : ANY);
		VAR res : LONGINT; command : ARRAY 256 OF CHAR;
		BEGIN
			IF ftp = NIL THEN
				KernelLog.String("not connected"); KernelLog.Ln;
				RETURN
			END;
			SetBusy(TRUE);
			cmd.GetAsString(command);
			IF command # "" THEN ftp.Raw(command, res) END;
			cmd.SetAsString("");
			SetBusy(FALSE)
		END CommandHandler;

		PROCEDURE ListHandler(sender, data : ANY);
		BEGIN
			IF ftp = NIL THEN
				KernelLog.String("not connected"); KernelLog.Ln;
				RETURN
			END;
			SetBusy(TRUE);
			IF fullList.state.Get() = 1 THEN
				ftp.EnumerateDir("")
			ELSE
				ftp.EnumerateNames
			END;
			ftpPanel.curList := ftp.listing; ftpPanel.nofEntries := ftp.nofEntries;
			ftpPanel.PrepareList;
			SetBusy(FALSE)
		END ListHandler;

		PROCEDURE ChangeDir(path :Strings.String);
		VAR res : LONGINT; dir : ARRAY 256 OF CHAR;
		BEGIN
			IF ftp = NIL THEN
				KernelLog.String("not connected"); KernelLog.Ln;
				RETURN
			END;
			SetBusy(TRUE);
			ftp.ChangeDir(path^, res);
			IF res = 0 THEN
				ftp.GetCurrentDir(dir, res);
				IF res = 0 THEN
					ftpPanel.pathEdit.SetAsString(dir);
					ListHandler(SELF, NIL)
				END;
			ELSE
				KernelLog.String("no such directory"); KernelLog.Ln;
			END;
			SetBusy(FALSE)
		END ChangeDir;

		PROCEDURE RefreshHandler(sender, data : ANY);
		VAR test : BOOLEAN;
		BEGIN
			ftpPanel.SetColSize;
			IF ftp # NIL THEN
				test := ftp.IsAlive();
				IF test THEN ListHandler(SELF, NIL)
				ELSE Disconnect END;
			END
		END RefreshHandler;

		PROCEDURE SetConnected(con : BOOLEAN);
		BEGIN
			connected := con;
			IF con THEN
				conLabel.fillColor.Set(0CC00FFH);
				connect.caption.SetAOC("Disconnect");
			ELSE
				conLabel.fillColor.Set(LONGINT(0CC0000FFH));
				connect.caption.SetAOC("Connect");
			END
		END SetConnected;

		PROCEDURE SetBusy(bus : BOOLEAN);
		BEGIN
			busy := bus;
			IF bus THEN	busyLabel.fillColor.Set(LONGINT(0FF8800FFH))
			ELSE busyLabel.fillColor.Set(LONGINT(0888888FFH))	END
		END SetBusy;

	END Window;

	(* FTPPanel *)
 	FTPPanel = OBJECT(WMComponents.VisualComponent)
	VAR
		grid : WMStringGrids.StringGrid;
		colWidths : WMGrids.Spacings;
		path : WMProperties.StringProperty;
		filter : WMProperties.StringProperty;
		prefixSearch : WMProperties.BooleanProperty;
		filterEdit, pathEdit : WMEditors.Editor;
		popup: WMPopups.Popup;
		px, py : LONGINT;
		parent : FTPClient.FTPEntry;
		selection : FTPClient.FTPListing;

		owner : Window;
		curList : FTPClient.FTPListing;
		nofEntries : LONGINT;

		PROCEDURE &Init*;
		VAR label : WMStandardComponents.Label;
			panel : WMStandardComponents.Panel;
		BEGIN
			Init^;
			SetNameAsString(StrFTPPanel);
			NEW(parent);

			(* new properties *)
			NEW(path, FileListPathProt, NIL, NIL); properties.Add(path);
			NEW(filter, FileListFilterProt, NIL, NIL); properties.Add(filter);

			NEW(panel); panel.bounds.SetHeight(20); panel.alignment.Set(WMComponents.AlignTop);
			panel.fillColor.Set(LONGINT(0CCCCCCFFH)); AddContent(panel);
			NEW(label); label.bounds.SetWidth(40); label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC(" Path: "); panel.AddContent(label); label.textColor.Set(0000000FFH);
			NEW(pathEdit); pathEdit.alignment.Set(WMComponents.AlignClient);
			pathEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			panel.AddContent(pathEdit); pathEdit.fillColor.Set(LONGINT(0EEEEEEFFH));
			pathEdit.onEnter.Add(PathChanged); pathEdit.SetAsString("/");
			pathEdit.multiLine.Set(FALSE); pathEdit.tv.defaultTextBgColor.Set(pathEdit.fillColor.Get());
			pathEdit.tv.showBorder.Set(TRUE); pathEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));

			NEW(prefixSearch, FileListPrefixSearchProt, NIL, NIL); properties.Add(prefixSearch);
			NEW(filterEdit); filterEdit.alignment.Set(WMComponents.AlignTop);
			filterEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filterEdit.bounds.SetHeight(25); AddContent(filterEdit);
			filterEdit.text.onTextChanged.Add(TextChanged);
			filterEdit.multiLine.Set(FALSE);
			filterEdit.tv.showBorder.Set(TRUE);
			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			AddContent(grid);
			grid.onClickSelected.Add(ClickSelected);
			grid.SetExtContextMenuHandler(ContextMenu);
			grid.onStartDrag.Add(MyStartDrag);
			grid.SetExtDragDroppedHandler(MyDragDropped);
			grid.model.Acquire;
			grid.model.SetNofCols(4);
			grid.model.SetNofRows(1);
			grid.fixedRows.Set(1);
			grid.model.SetCellText(0, 0, Strings.NewString("Filename"));
			grid.model.SetCellText(1, 0, Strings.NewString("Size"));
			grid.model.SetCellText(2, 0, Strings.NewString("Modified"));
			grid.model.SetCellText(3, 0, Strings.NewString("Attributes"));
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			NEW(colWidths, 4);
			grid.model.Release
		END Init;

		PROCEDURE SetColSize;
		BEGIN
			colWidths[0] := (bounds.GetWidth() DIV 2);
			colWidths[1] := bounds.GetWidth() DIV 6;
			colWidths[2] := bounds.GetWidth() DIV 6;
			colWidths[3] := bounds.GetWidth() DIV 6;
			grid.SetColSpacings(colWidths);
		END SetColSize;

		(* -- Handlers -------------------------------------- *)

		PROCEDURE ClickSelected(sender, data : ANY);
		VAR curSel : FTPClient.FTPListing;
		BEGIN
			IF (data # NIL) & (data IS FTPClient.FTPEntry) THEN
				NEW(curSel, 1);
				curSel[0] := data(FTPClient.FTPEntry);
				owner.SetBusy(TRUE);
				IF curSel[0] = parent THEN KernelLog.String("Directory UP "); owner.ChangeDir(Strings.NewString("..")) END;
				IF IsFolder(curSel[0]) THEN	(* change into folder *)
					owner.ChangeDir(Strings.NewString(curSel[0].filename))
				END;
				owner.SetBusy(FALSE)
			END
		END ClickSelected;

		PROCEDURE ContextMenu(sender : ANY; x, y: LONGINT);
		VAR curSel : FTPClient.FTPListing;
			w : SelectionWrapper;
		BEGIN
			px := x; py := y;
			NEW(popup);
			curSel := GetSelection();
			NEW(w); w.sel := curSel;

			IF LEN(curSel) = 0 THEN RETURN END;
			IF LEN(curSel) = 1 THEN
				popup.AddParButton("Create Dir", CreateDir, w);
				popup.AddParButton("Rename", RenameEntry, w)
			END;
			popup.AddParButton("Delete", DeleteEntries, w);

			grid.ToWMCoordinates(x, y, px, py);
			popup.Popup(px, py)
		END ContextMenu;

		PROCEDURE DeleteEntries(sender, data : ANY);
		VAR  d : FTPClient.FTPEntry;
			dr, res, i  : LONGINT;
			dp : ARRAY 128 OF CHAR;
			delete, always, never : BOOLEAN;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				always := FALSE; never := FALSE;
				FOR i := 0 TO LEN(data(SelectionWrapper).sel) - 1 DO
					d := data(SelectionWrapper).sel[i];
					delete := FALSE;
					IF d # NIL THEN
						COPY(d.filename, dp);
						IF ~always & ~never THEN
							dr := WMDialogs.Message(WMDialogs.TConfirmation, "Confirm deleting file", dp,
								{WMDialogs.ResNo, WMDialogs.ResAbort, WMDialogs.ResYes, WMDialogs.ResAll});
							IF dr IN {WMDialogs.ResYes, WMDialogs.ResAll} THEN delete := TRUE END;
							IF dr = WMDialogs.ResAll THEN always := TRUE END;
							IF dr = WMDialogs.ResAbort THEN never := TRUE END;
						END;
						IF ~never & (delete OR always) THEN
							owner.SetBusy(TRUE);
							IF IsFolder(d) THEN
								owner.ftp.RemoveDir(dp, res)
							ELSE
								owner.ftp.DeleteFile(dp, res)
							END;
							IF res # 0 THEN
								WMDialogs.Error("Deleting failed", dp)
							END;
							owner.SetBusy(FALSE);
							(* if the dialog was shown then visually update *)
(*							IF delete THEN Refresh(NIL, NIL) END *)
						END
					END
				END;
				(* end of the operation refresh list *)
(*				Refresh(NIL, NIL) *)
			END
		END DeleteEntries;

		PROCEDURE RenameEntry(sender, data : ANY);
		VAR  d : FTPClient.FTPEntry; rename : WMDialogs.MiniStringInput;
			res : LONGINT;
			name, op : ARRAY 128 OF CHAR;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				d := data(SelectionWrapper).sel[0];
				IF d # NIL THEN
					(* grid.Acquire; grid.ToWMCoordinates(px, py, wmx, wmy); grid.Release; *)
					NEW(rename);
					COPY(d.filename, name);
					IF rename.Show(px, py, name) = WMDialogs.ResOk THEN
						IF name # d.filename THEN
							owner.SetBusy(TRUE);
							COPY(d.filename, op);
							KernelLog.String("Renaming File/Folder: "); KernelLog.String(op); KernelLog.Ln;
							owner.ftp.RenameFile(op, name, res);
							IF res # 0 THEN
								KernelLog.String("Renaming failed: "); KernelLog.Int(res, 0); KernelLog.Ln;
								WMDialogs.Error("Renaming failed", name)
							END;
							owner.SetBusy(FALSE);
(*							Refresh(NIL, NIL)	*)
						END
					END
				END
			END
		END RenameEntry;

		PROCEDURE CreateDir(sender, data : ANY);
		VAR res : LONGINT;
			name : ARRAY 128 OF CHAR;
		BEGIN
			COPY("NewFolder", name);
			IF WMDialogs.QueryString("Create Folder: ", name) = WMDialogs.ResOk THEN
				owner.SetBusy(TRUE);
				KernelLog.String("Creating Folder: "); KernelLog.String(name); KernelLog.Ln;
				owner.ftp.MakeDir(name, res);
				IF res # 0 THEN
					KernelLog.String("Creating Folder failed: "); KernelLog.Int(res, 0); KernelLog.Ln;
					WMDialogs.Error("Creating new Folder failed", name);
				END;
				owner.SetBusy(FALSE);
(*				Refresh(NIL, NIL)	*)
			END
		END CreateDir;

		PROCEDURE TextChanged(sender, data : ANY);
		VAR str : ARRAY 128 OF CHAR;
		BEGIN
			filterEdit.GetAsString(str);
			filter.Set(Strings.NewString(str))
		END TextChanged;

		PROCEDURE PathChanged(sender, data : ANY);
		VAR str : ARRAY 512 OF CHAR;
		BEGIN
			pathEdit.GetAsString(str);
			path.Set(Strings.NewString(str))
		END PathChanged;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		BEGIN
			IF data = path THEN
				owner.ChangeDir(path.Get());
			ELSIF (data = filter) OR (data = prefixSearch) THEN
				PrepareList
			ELSE PropertyChanged^(sender, data)
			END
		END PropertyChanged;

		PROCEDURE PrepareList;
		VAR i, vis : LONGINT; mask, t : ARRAY 128 OF CHAR; s : Strings.String;
			img: WMGraphics.Image;
		BEGIN
			IF curList = NIL THEN
				grid.model.Acquire;
				grid.model.SetNofRows(1);
				grid.model.Release;
				RETURN
			END;
			s := filter.Get();
			mask := "";
			IF s # NIL THEN COPY(s^, mask) END;
			IF mask = "" THEN
				FOR i := 0 TO nofEntries - 1 DO curList[i].visible := TRUE END;
				vis := nofEntries
			ELSE
				IF prefixSearch.Get() & ( mask[Strings.Length(mask)] # "*") THEN Strings.Append(mask, "*") END;
				vis := 0;
				FOR i := 0 TO nofEntries - 1 DO
					IF Strings.Match(mask, curList[i].filename) THEN
						curList[i].visible := TRUE;
						INC(vis)
					ELSE curList[i].visible := FALSE
					END
				END;
			END;

			grid.model.Acquire;
			grid.model.SetNofRows(vis + 2);
			grid.model.SetCellText(0, 1, Strings.NewString("Parent Directory")); grid.model.SetCellData(0, 1, parent);
			grid.model.SetCellImage(0, 1, WMGraphics.LoadImage("icons.tar://Parent.png", TRUE));

			vis := 0;
			FOR i := 0 TO nofEntries - 1 DO
				IF curList[i].visible THEN
					img := GetImage(curList[i]);
					grid.model.SetCellImage(0, vis+2, img);
					grid.model.SetCellText(0, vis+2, Strings.NewString(curList[i].filename));
					grid.model.SetCellData(0, vis+2, curList[i]);
					grid.model.SetCellText(1, vis+2, Strings.NewString(curList[i].size));
					COPY(curList[i].d0, t); Strings.Append(t, " "); Strings.Append(t, curList[i].d1); Strings.Append(t, " "); Strings.Append(t, curList[i].d2);
					grid.model.SetCellText(2, vis+2, Strings.NewString(t));
					grid.model.SetCellText(3, vis+2, Strings.NewString(curList[i].flags));
					INC(vis)
				END
			END;
			grid.SetTopPosition(0, 0, TRUE);
			grid.model.Release;
		END PrepareList;

		(* -- Drag-Drop Handlers -----------------------------*)

		(* called when an object has been dropped on this FTPList *)
		PROCEDURE MyDragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			DragDroppedList(x, y, dragInfo)
		END MyDragDropped;

		(* called by MyDraggedDropped *)
		PROCEDURE DragDroppedList(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dropTarget : FTPDropTarget;
		BEGIN
			NEW(dropTarget, owner.ftp);
			dragInfo.data := dropTarget;
			owner.SetBusy(TRUE);
			IF dragInfo.sender = grid THEN ConfirmDrag(FALSE, dragInfo)
			ELSE ConfirmDrag(TRUE, dragInfo) END;
			owner.SetBusy(FALSE)
		END DragDroppedList;

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
					c.DrawString(3, top + 20, selection[i].filename);
					INC(top, 25)
				END
			END;
			IF grid.StartDrag(NIL, img, 0,0,DragArrivedList, NIL) THEN KernelLog.String("DraggingStarted")
			ELSE KernelLog.String("Drag could not be started")
			END;
		END MyStartDrag;

		(* called when an object dragged from this FTPList has been dropped anywhere *)
		PROCEDURE DragArrivedList(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			i, res : LONGINT;
			sel : FTPClient.FTPListing;
			url : ARRAY 1024 OF CHAR;
			text : Texts.Text;
			textPos : Texts.TextPosition;
		BEGIN
			sel := selection;
			IF sel = NIL THEN RETURN END;

			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
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
						COPY(selection[i].filename, url);
						IF ~IsFolder(selection[i]) THEN
							CopyFile(itf(WMDropTarget.DropFiles), url, url, res)
						END
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
							COPY(selection[i].filename, url);
							Strings.AppendChar(url, CHR(Texts.NewLineChar));
							TextUtilities.StrToText(text, textPos.GetPosition(), url)
						END
					END;
					text.ReleaseWrite
				END;
				RETURN
			END;
		END DragArrivedList;

		(* -- Helpers --------------------------------------- *)

		PROCEDURE GetSelection() : FTPClient.FTPListing;
		VAR selection : FTPClient.FTPListing;
			l, t, r, b, i, j : LONGINT;
			p : ANY;
		BEGIN
			grid.model.Acquire;
			grid.GetSelection(l, t, r, b);
			NEW(selection, b- t + 1);
			j := 0;
			FOR i := t TO b DO
				p := grid.model.GetCellData(0, i);
				IF (p # NIL) & (p IS FTPClient.FTPEntry) THEN
					selection[j] := p(FTPClient.FTPEntry);
					INC(j)
				END
			END;
			grid.model.Release;
			RETURN selection
		END GetSelection;

		PROCEDURE CopyFile(target : WMDropTarget.DropFiles; CONST local, remote : ARRAY OF CHAR; VAR res : LONGINT);
		VAR w : Streams.Writer;
			r : Streams.Reader;
			buf: ARRAY BufSize OF CHAR; len : LONGINT;
		BEGIN
			res := -1;
			owner.SetBusy(TRUE);
			owner.ftp.OpenGet(local, r, res);
			IF  res = 0 THEN
				target.OpenPut(remote, w, res);
				KernelLog.String("Downloading File: "); KernelLog.String(local); KernelLog.Ln;
				IF res = 0 THEN
					REPEAT
						r.Bytes(buf, 0, BufSize, len); w.Bytes(buf, 0, len);
					UNTIL r.res # 0;
					target.ClosePut(res)
				END;
				owner.ftp.CloseGet(res)
			ELSE
				KernelLog.String("Error: "); KernelLog.String(owner.ftp.msg); KernelLog.Ln
			END;
			owner.SetBusy(FALSE)
		END CopyFile;

		PROCEDURE IsFolder(entry : FTPClient.FTPEntry) : BOOLEAN;
		BEGIN
			IF (entry.flags[0] = "<") OR (entry.flags[0] = "d") THEN RETURN TRUE;
			ELSE RETURN FALSE END;
		END IsFolder;

		PROCEDURE GetImage(entry : FTPClient.FTPEntry) : WMGraphics.Image;
		VAR img : WMGraphics.Image; temp: ARRAY 256 OF CHAR;
		BEGIN
			COPY("icons.tar://", temp);
			IF IsFolder(entry) THEN
				Strings.Append(temp, "Folder.png");
			ELSE
				Strings.Append(temp, "File.png");
			END;
			Strings.Append(temp, "");
			img := WMGraphics.LoadImage(temp, TRUE);
			RETURN img
		END GetImage;

	END FTPPanel;
(* ------------------------------------------------------------------ *)

VAR
	nofWindows : LONGINT;
	FileListPathProt : WMProperties.StringProperty;
	FileListFilterProt : WMProperties.StringProperty;
	FileListPrefixSearchProt : WMProperties.BooleanProperty;

	StrFTPPanel : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrFTPPanel := Strings.NewString("FTPPanel");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(FileListPathProt, NIL, Strings.NewString("Path"), Strings.NewString("contains the displayed path"));
	NEW(FileListFilterProt, NIL, Strings.NewString("Filter"), Strings.NewString("display filename filter"));
	NEW(FileListPrefixSearchProt, NIL, Strings.NewString("PrefixSearch"), Strings.NewString("match prefix only"));
	FileListPrefixSearchProt.Set(TRUE);
END InitPrototypes;

PROCEDURE Open*;
VAR instance : Window;
BEGIN
	NEW(instance);
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
END WMFTPClient.

---------------------------------------------

WMFTPClient.Open~		SystemTools.Free WMFTPClient ~
