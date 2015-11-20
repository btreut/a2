MODULE WMFileManager;		(** AUTHOR "ug"; PURPOSE  "file manager"; *)

IMPORT Files, Modules, WMGraphics, WMProperties,
	WMEditors, WMSystemComponents, WMComponents, WMStandardComponents, WMMessages, WMRestorable, Strings,
	WM := WMWindowManager;

CONST
	WindowWidth = 500; WindowHeight = 400;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	FileListPanel* = OBJECT (WMComponents.VisualComponent)
		VAR pathProp*, filterProp : WMProperties.StringProperty;
			filterEdit : WMEditors.Editor;
			list* : WMSystemComponents.FileList;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrFileListPanel);
			(* new properties *)
			NEW(pathProp, FileListPathProt, NIL, NIL); properties.Add(pathProp);
			NEW(filterProp, FileListFilterProt, NIL, NIL); properties.Add(filterProp);

			NEW(filterEdit); filterEdit.alignment.Set(WMComponents.AlignTop);
			filterEdit.bounds.SetHeight(25); AddContent(filterEdit);
			filterEdit.text.onTextChanged.Add(TextChanged);
			filterEdit.multiLine.Set(FALSE);
			filterEdit.tv.showBorder.Set(TRUE);
			filterEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);

			NEW(list);
			list.alignment.Set(WMComponents.AlignClient);
			AddContent(list)
		END Init;

		PROCEDURE TextChanged(sender, data : ANY);
		VAR str : ARRAY 128 OF CHAR;
		BEGIN
			filterEdit.GetAsString(str);
			filterProp.Set(Strings.NewString(str))
		END TextChanged;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		BEGIN
			IF data = pathProp THEN
				list.StartNewPath(pathProp.Get())
			ELSIF (data = filterProp) THEN
				list.StartNewFilter(filterProp.Get())
			ELSE PropertyChanged^(sender, data)
			END
		END PropertyChanged;

	END FileListPanel;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR label: WMStandardComponents.Label;
		tree : WMSystemComponents.DirectoryTree;
		flistPanel : FileListPanel;
		vol, cap, free, files : WMStandardComponents.Label;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			sidePanel, panel, status : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
			resizerH : WMStandardComponents.Resizer;

		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient); panel.fillColor.Set(LONGINT(0FFFFFFFFH)); panel.takesFocus.Set(TRUE);
			NEW(toolbar); toolbar.fillColor.Set(LONGINT(0FFFFFFFFH)); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);
			NEW(button); button.alignment.Set(WMComponents.AlignLeft); button.caption.SetAOC("Refresh FileSystems");
			toolbar.AddContent(button); button.bounds.SetWidth(150); button.onClick.Add(RefreshHandler);
			NEW(button); button.alignment.Set(WMComponents.AlignLeft); button.caption.SetAOC("Toggle Properties");
			toolbar.AddContent(button); button.bounds.SetWidth(150); button.onClick.Add(TogglePropsHandler);
			NEW(status); status.alignment.Set(WMComponents.AlignBottom); status.bounds.SetHeight(20);
			panel.AddContent(status); status.fillColor.Set(LONGINT(0CCCCCCFFH));
			NEW(label); label.bounds.SetWidth(100); label.caption.SetAOC(" Volume: "); label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(vol); vol.bounds.SetWidth(100); vol.caption.SetAOC("-"); vol.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(vol);
			NEW(label); label.bounds.SetWidth(100); label.caption.SetAOC(" Size: "); label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(cap); cap.bounds.SetWidth(100); cap.caption.SetAOC("-"); cap.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(cap);
			NEW(label); label.bounds.SetWidth(100); label.caption.SetAOC(" Free: "); label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(free); free.bounds.SetWidth(100); free.caption.SetAOC("-"); free.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(free);
			NEW(label); label.bounds.SetWidth(100); label.caption.SetAOC(" Files: "); label.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(label);
			NEW(files); files.bounds.SetWidth(100); files.caption.SetAOC("-"); files.alignment.Set(WMComponents.AlignLeft);
			status.AddContent(files);

			NEW(sidePanel); sidePanel.alignment.Set(WMComponents.AlignLeft); sidePanel.bounds.SetWidth(200);
			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignRight); resizerH.bounds.SetWidth(4);
			sidePanel.AddContent(resizerH);
			NEW(tree); tree.alignment.Set(WMComponents.AlignClient);
			sidePanel.AddContent(tree);
			panel.AddContent(sidePanel);

			NEW(flistPanel); flistPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(flistPanel);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent; s : Strings.String;
		BEGIN
			IncCount;
			vc := CreateForm();

			tree.onPathChanged.Add(PathChanged);

			IF (c # NIL) THEN
				Init(c.r - c.l, c.b - c.t, FALSE);
			ELSE
				Init(WindowWidth, WindowHeight, FALSE);
			END;

			SetContent(vc);
			SetTitle(Strings.NewString("File Manager"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMFileManager.png", TRUE));

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
			ELSE
				WM.DefaultAddWindow(SELF);
			END;

			s := tree.currentPath.Get();
		END New;

		PROCEDURE PathChanged(sender, data : ANY);
		BEGIN
			flistPanel.pathProp.Set(tree.currentPath.Get());
			UpdateStatus(tree.currentPath.Get());
		END PathChanged;

		PROCEDURE UpdateStatus(alias : Strings.String);
		VAR sfree, total, nfiles, i: LONGINT; fs: Files.FileSystem; ft: Files.FileSystemTable;
			temp : ARRAY 32 OF CHAR;
		BEGIN
			Files.GetList(ft);
			IF ft # NIL THEN
				FOR i := 0 TO LEN(ft)-1 DO
					fs := ft[i];
					COPY(fs.prefix, temp);
					Strings.Append(temp, ":");
					IF (alias^ = temp) THEN
						IF fs.vol # NIL THEN
							vol.caption.SetAOC(alias^);
							sfree := ENTIER(fs.vol.Available()/1024.0D0 * fs.vol.blockSize);
							total := ENTIER(fs.vol.size/1024.0D0 * fs.vol.blockSize);
							Strings.IntToStr(total, temp); Strings.Append(temp, " KB");
							cap.caption.SetAOC(temp);
							Strings.IntToStr(sfree, temp); Strings.Append(temp, " KB");
							free.caption.SetAOC(temp);
							nfiles := flistPanel.list.GetNofFiles();
							Strings.IntToStr(nfiles, temp);
							files.caption.SetAOC(temp);
						END;
					END;
				END
			END;
		END UpdateStatus;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE RefreshHandler(sender, data: ANY);
		BEGIN
			tree.Refresh;
		END RefreshHandler;

		PROCEDURE TogglePropsHandler(sender, data: ANY);
		BEGIN
			flistPanel.list.ToggleProps;
		END TogglePropsHandler;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSIF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS WMRestorable.Storage) THEN
				x.ext(WMRestorable.Storage).Add("FileManager", "WMFileManager.Restore", SELF, NIL)
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;
	FileListPathProt : WMProperties.StringProperty;
	FileListFilterProt : WMProperties.StringProperty;

	StrFileListPanel : Strings.String;

PROCEDURE Open*;
VAR win : Window;
BEGIN
	NEW(win, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR win : Window;
BEGIN
	NEW(win, context)
END Restore;

PROCEDURE InitStrings;
BEGIN
	StrFileListPanel := Strings.NewString("FileListPanel");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(FileListPathProt, NIL, Strings.NewString("Path"), Strings.NewString("contains the displayed path"));
	NEW(FileListFilterProt, NIL, Strings.NewString("Filter"), Strings.NewString("display filename filter"));
END InitPrototypes;

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
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
END WMFileManager.

SystemTools.Free WMFileManager WMSystemComponents ~
WMFileManager.Open ~

