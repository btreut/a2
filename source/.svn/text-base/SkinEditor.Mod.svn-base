MODULE SkinEditor; (** AUTHOR "FN"; PURPOSE "Skin Editor GUI"; *)

IMPORT
	SkinEngine, SkinLanguage,
	KernelLog, Modules, Commands, Streams, WMRestorable, XML, Files, Archives, Codecs,
	FNHistories, Strings, TextUtilities, Texts, Configuration,
	WMStandardComponents, WMGraphics, WMGraphicUtilities, WMComponents, WMRectangles, WMMessages,
	WMDialogs,	WMTextView, WMEditors, WMBitmapFont, WMGrids, WMMacros, WMSearchComponents,
	WMTrees, WMArchives, WMColorComponents,
	WM := WMWindowManager;

CONST
	EditorFocus = 1;
	SplitEditorFocus = 2;

	MaxErrors = 64;

	TutorialFileName = "SkinTutorial.Text";

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	String = Strings.String;

	HistoryItem = POINTER TO RECORD
		skin : SkinEngine.Skin;
		text : Texts.Text
	END;

	ErrorInfo = OBJECT
	VAR pos : POINTER TO ARRAY OF WMTextView.PositionMarker;
		msg : ARRAY 128 OF CHAR;

		PROCEDURE & Init*;
		BEGIN
			NEW(pos, 2)
		END Init;

	END ErrorInfo;

	ErrorList= OBJECT
	VAR errors : ARRAY MaxErrors OF ErrorInfo;
		size : LONGINT;

		PROCEDURE & Init*;
		VAR i : LONGINT;
		BEGIN
			size := 0;
			FOR i := 0 TO MaxErrors-1 DO NEW(errors[i]) END
		END Init;

	END ErrorList;

TYPE

	PreviewPanel= OBJECT(WMStandardComponents.Panel)
	VAR image : WMStandardComponents.ImagePanel;
		titleLbl, infoLbl : WMStandardComponents.Label;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(StrPreviewPanel);
				(* title *)
			NEW(titleLbl); titleLbl.alignment.Set(WMComponents.AlignTop);
			titleLbl.fillColor.Set(0CCCCCCFFH);
			titleLbl.SetCaption("Entry Info"); titleLbl.bounds.SetHeight(20);
			SELF.AddContent(titleLbl);
				(* entry info *)
			NEW(infoLbl); infoLbl.alignment.Set(WMComponents.AlignTop);
			infoLbl.SetCaption("No entry marked"); infoLbl.bounds.SetHeight(20);
			SELF.AddContent(infoLbl);
				(* image preview *)
			NEW(image); image.alignment.Set(WMComponents.AlignClient);
			SELF.AddContent(image);
		END Init;

		PROCEDURE ChangeImageHandler(sender, data : ANY);
		VAR node : WMTrees.TreeNode; tree : WMTrees.Tree;
			any : ANY; infoString : String;
		BEGIN
			IF (sender IS WMTrees.TreeView) & (data IS WMTrees.TreeNode) THEN
				node := data(WMTrees.TreeNode);
				tree := sender(WMTrees.TreeView).GetTree();
					(* entry info *)
				any := tree.GetNodeData(node);
				IF any # NIL THEN
					infoString := any(Archives.EntryInfo).GetName();
					infoLbl.SetCaption(infoString^)
				ELSE
					infoLbl.SetCaption("No info available.")
				END;
					(* image *)
				image.SetImage(SELF, tree.GetNodeImage(node));
			END
		END ChangeImageHandler;

	END PreviewPanel;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		filenameEdit, editor, splitEditor, logEdit : WMEditors.Editor;
		logPanel, editPanel, topToolbar, splitPanel, sidePanel : WMStandardComponents.Panel;
		load, store, set, apply, check, splitBtn, searchBtn, backBtn, forwardBtn, tutorialBtn, configBtn : WMStandardComponents.Button;
		previewPanel : PreviewPanel;
		colorChooser : WMColorComponents.ColorChooser;
		searchPanel : WMSearchComponents.SearchPanel;
		errorLog : WMGrids.GenericGrid;
		compileErrors : ErrorList;
		colWidths : WMGrids.Spacings;
		archiveTree : WMArchives.ArchiveTree;
		history : FNHistories.History;
		modified, splitted : BOOLEAN;
		focus : LONGINT;
		originalSkin : SkinEngine.Skin;
		skinFile : Archives.Archive;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, p : WMStandardComponents.Panel;
			resizerH, resizerV, resizerV2 : WMStandardComponents.Resizer;
		BEGIN
				(* main panel *)
			NEW(panel); panel.bounds.SetExtents(850, 700); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);
				(* top toolbar *)
			NEW(topToolbar); topToolbar.bounds.SetHeight(20); topToolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(topToolbar);
					(* filename edit *)
			NEW(filenameEdit); filenameEdit.alignment.Set(WMComponents.AlignLeft); filenameEdit.fillColor.Set(0FFFFFFFFH);
			filenameEdit.multiLine.Set(FALSE); filenameEdit.bounds.SetWidth(200);
			filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			topToolbar.AddContent(filenameEdit);
			filenameEdit.tv.showBorder.Set(TRUE); filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			filenameEdit.onEnter.Add(LoadHandler);
					(* load button*)
			NEW(load); load.caption.SetAOC("Load"); load.alignment.Set(WMComponents.AlignLeft);
			load.onClick.Add(LoadHandler); topToolbar.AddContent(load);
					(* store button *)
			NEW(store); store.caption.SetAOC("Store"); store.alignment.Set(WMComponents.AlignLeft);
			store.onClick.Add(StoreHandler); topToolbar.AddContent(store);
					(* search button *)
			NEW(searchBtn); searchBtn.caption.SetAOC("Search"); searchBtn.alignment.Set(WMComponents.AlignLeft);
			searchBtn.onClick.Add(SearchHandler); topToolbar.AddContent(searchBtn);
					(* split button *)
			NEW(splitBtn); splitBtn.caption.SetAOC("Split"); splitBtn.alignment.Set(WMComponents.AlignLeft);
			splitBtn.onClick.Add(Split); topToolbar.AddContent(splitBtn);
					(* check button *)
			NEW(check); check.caption.SetAOC("Check"); check.alignment.Set(WMComponents.AlignLeft);
			check.onClick.Add(CheckHandler); topToolbar.AddContent(check);
					(* apply button *)
			NEW(apply); apply.caption.SetAOC("Apply"); apply.alignment.Set(WMComponents.AlignLeft);
			apply.onClick.Add(ApplyHandler); topToolbar.AddContent(apply);
					(*set as default button *)
			NEW(set); set.bounds.SetWidth(100); set.caption.SetAOC("SetAsDefault"); set.alignment.Set(WMComponents.AlignLeft);
			set.onClick.Add(SetHandler); topToolbar.AddContent(set);
					(* history back button *)
			NEW(backBtn); backBtn.caption.SetAOC("Back"); backBtn.alignment.Set(WMComponents.AlignLeft);
			backBtn.onClick.Add(BackHandler); backBtn.useBgBitmaps.Set(FALSE);
			backBtn.clDefault.Set(1010C080H); backBtn.clHover.Set(1010C080H); backBtn.clPressed.Set(1010C080H);
			backBtn.clTextDefault.Set(WMGraphics.Yellow); backBtn.clTextHover.Set(WMGraphics.Yellow); backBtn.clTextPressed.Set(WMGraphics.White);
			topToolbar.AddContent(backBtn);
					(* history forward button *)
			NEW(forwardBtn); forwardBtn.caption.SetAOC("Forward"); forwardBtn.alignment.Set(WMComponents.AlignLeft);
			forwardBtn.onClick.Add(ForwardHandler); forwardBtn.useBgBitmaps.Set(FALSE);
			forwardBtn.clDefault.Set(1010C080H); forwardBtn.clHover.Set(1010C080H); forwardBtn.clPressed.Set(1010C080H);
			forwardBtn.clTextDefault.Set(WMGraphics.Yellow); forwardBtn.clTextHover.Set(WMGraphics.Yellow); forwardBtn.clTextPressed.Set(WMGraphics.White);
			topToolbar.AddContent(forwardBtn);
					(* show tutorial *)
			NEW(tutorialBtn); tutorialBtn.caption.SetAOC("Tutorial"); tutorialBtn.alignment.Set(WMComponents.AlignLeft);
			tutorialBtn.onClick.Add(ShowTutorialHandler); topToolbar.AddContent(tutorialBtn);
					(* show configuration *)
			NEW(configBtn); configBtn.caption.SetAOC("Config"); configBtn.alignment.Set(WMComponents.AlignLeft);
			configBtn.onClick.Add(ShowConfigHandler); topToolbar.AddContent(configBtn);
				(* left side panel *)
			NEW(sidePanel); sidePanel.bounds.SetWidth(250); sidePanel.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(sidePanel);
					(* resizer *)
			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignRight); sidePanel.AddContent(resizerH);
					(* color chooser *)
			NEW(colorChooser); colorChooser.bounds.SetHeight(200); colorChooser.alignment.Set(WMComponents.AlignBottom);
			colorChooser.title.caption.Set(Strings.NewString("Colors")); sidePanel.AddContent(colorChooser);
					(* image preview panel *)
			NEW(p); p.bounds.SetHeight(100); p.alignment.Set(WMComponents.AlignBottom); sidePanel.AddContent(p);
						(* preview resizer *)
			NEW(resizerV2); resizerV2.alignment.Set(WMComponents.AlignTop); p.AddContent(resizerV2);
						(* image preview *)
			NEW(previewPanel); previewPanel.alignment.Set(WMComponents.AlignClient);
			p.AddContent(previewPanel);
					(* ressources index tree *)
			NEW(archiveTree); archiveTree.alignment.Set(WMComponents.AlignClient);
			sidePanel.AddContent(archiveTree);
			archiveTree.treeView.onClickNode.Add(previewPanel.ChangeImageHandler);
				(* right side panel *)
			NEW(editPanel); editPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(editPanel);
					(* search panel *)
			NEW(searchPanel); searchPanel.alignment.Set(WMComponents.AlignBottom);
			searchPanel.bounds.SetHeight(45); searchPanel.visible.Set(FALSE); editPanel.AddContent(searchPanel);
					(* log panel *)
			NEW(logPanel);	logPanel.alignment.Set(WMComponents.AlignBottom); logPanel.bounds.SetHeight(130);
			editPanel.AddContent(logPanel);
						(* editor *)
			NEW(logEdit); logEdit.bounds.SetHeight(30); logEdit.alignment.Set(WMComponents.AlignBottom);
			logEdit.allowScrollbars.Set(FALSE); logEdit.tv.showBorder.Set(TRUE); logEdit.visible.Set(FALSE);
			editPanel.AddContent(logEdit);
						(* error list *)
			NEW(errorLog); errorLog.alignment.Set(WMComponents.AlignClient); errorLog.nofCols.Set(2); errorLog.fixedRows.Set(1);
			NEW(colWidths, 2); colWidths[0] := errorLog.defaultColWidth.Get() DIV 2; colWidths[1] := errorLog.defaultColWidth.Get() * 4;
			errorLog.SetColSpacings(colWidths); errorLog.SetDrawCellProc(DrawCell); errorLog.onClick.Add(ErrorClick);
			errorLog.SetSelectionMode(WMGrids.GridSelectSingleRow); logPanel.AddContent(errorLog);
					(* second editor for splitted mode *)
			NEW(splitPanel); splitPanel.alignment.Set(WMComponents.AlignBottom);
			splitPanel.bounds.SetHeight(400); editPanel.AddContent(splitPanel);
					(* main editor *)
			NEW(editor); editor.alignment.Set(WMComponents.AlignClient); editor.tv.showBorder.Set(TRUE);
			editor.tv.SetExtFocusHandler(EditorFocusHandler); editor.macros.Add(WMMacros.Handle);
			editor.multiLine.Set(TRUE);
			editor.tv.wrapMode.Set(WMTextView.NoWrap);
			editor.text.onTextChanged.Add(TextChanged);
			editPanel.AddContent(editor);
					(* searchPanel reprise *)
			searchPanel.SetText(editor.text);
					(* resizer for split-editor *)
			NEW(resizerV); resizerV.alignment.Set(WMComponents.AlignTop); splitPanel.AddContent(resizerV);
					(* second editor for splitted mode *)
			NEW(splitEditor); splitEditor.alignment.Set(WMComponents.AlignClient); splitEditor.tv.showBorder.Set(TRUE);
			splitEditor.tv.SetExtFocusHandler(SplitEditorFocusHandler); splitPanel.AddContent(splitEditor);
			splitEditor.macros.Add(WMMacros.Handle); splitEditor.multiLine.Set(TRUE);
			splitEditor.tv.wrapMode.Set(WMTextView.NoWrap);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR fl, cp : LONGINT;
			 vc : WMComponents.VisualComponent;
			 xml : XML.Element;
			 s : Strings.String;
		BEGIN
			IncCount;
			vc := CreateForm();
			splitEditor.SetText(editor.text);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			logPanel.visible.Set(FALSE);
			splitPanel.visible.Set(FALSE);
			SetContent(vc);

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					xml := c.appData(XML.Element);
					s := xml.GetAttributeValue("firstLine");IF s # NIL THEN Strings.StrToInt(s^, fl) END;
					s := xml.GetAttributeValue("cursorPos");IF s # NIL THEN Strings.StrToInt(s^, cp) END;

					s := xml.GetAttributeValue("file");
					IF s # NIL THEN Load(s^) END;
					editor.tv.firstLine.Set(fl);
					editor.tv.cursor.SetPosition(cp);
					Resized(GetWidth(), GetHeight())
				END
			ELSE
				WM.DefaultAddWindow(SELF)
			END;
			SetTitle(Strings.NewString("Skin Editor"));
			NEW(history);
			originalSkin := SkinEngine.current;
		END New;

		(* sets the loaded skin as default skin in Configuration *)
		PROCEDURE SetHandler(sender, data : ANY);
		VAR val : ARRAY 128 OF CHAR; res : LONGINT;
		BEGIN
			IF SkinEngine.current # NIL THEN
				IF SkinEngine.current.xml # NIL THEN
					val := "SkinEngine.Load "; Strings.Append(val, SkinEngine.current.filename);
					Configuration.Put("Autostart.DefaultSkin", val, res);
					KernelLog.String("Set "); KernelLog.String(SkinEngine.current.filename); KernelLog.String(" as default."); KernelLog.Ln
				ELSE (* ZeroSkin *)
					val := "SkinEngine.Unload";
					Configuration.Put("Autostart.DefaultSkin", val, res);
					KernelLog.String("Set ZeroSkin as default."); KernelLog.Ln
				END
			END
		END SetHandler;

		(* open an editor with the current skin-language configuration *)
		PROCEDURE ShowConfigHandler(sender, data : ANY);
		BEGIN
			ShowDocument(SkinLanguage.ConfigFileName)
		END ShowConfigHandler;

		(* show skin-tutorial *)
		PROCEDURE ShowTutorialHandler(sender, data : ANY);
		BEGIN
			ShowDocument(TutorialFileName)
		END ShowTutorialHandler;

		(* open an editor-window with showing a document *)
		PROCEDURE ShowDocument(CONST docname : ARRAY OF CHAR);
		VAR res : LONGINT;
			msg : ARRAY 32 OF CHAR;
			cmd : ARRAY 128 OF CHAR;
		BEGIN
			cmd := "Notepad.Open ";
			Strings.Append(cmd, docname);
			Commands.Call(cmd, {}, res, msg)
		END ShowDocument;

		PROCEDURE EditorFocusHandler(hasFocus : BOOLEAN);
		BEGIN
			IF hasFocus THEN
				focus := EditorFocus;
				searchPanel.SetTextView(editor.tv);
			END;
		END EditorFocusHandler;

		PROCEDURE SplitEditorFocusHandler(hasFocus : BOOLEAN);
		BEGIN
			IF hasFocus THEN
				focus := SplitEditorFocus;
				searchPanel.SetTextView(splitEditor.tv);
			END
		END SplitEditorFocusHandler;

		PROCEDURE ErrorClick(sender, data : ANY);
		VAR scol, srow, ecol, erow, y : LONGINT;
			focusEditor : WMEditors.Editor;
			index : LONGINT;
		BEGIN
			errorLog.GetSelection(scol, srow, ecol, erow);
			y := srow;
			IF (compileErrors # NIL) & (y > 0) & (y <= compileErrors.size) THEN
				DEC(y);	(* first row is header row *)
				IF focus = EditorFocus THEN focusEditor := editor; index := 0
				ELSIF focus = SplitEditorFocus THEN focusEditor := splitEditor; index := 1
				ELSE RETURN
				END;
				IF compileErrors.errors[y].pos[index] # NIL THEN
					focusEditor.tv.cursor.SetPosition(compileErrors.errors[y].pos[index].GetPosition());
					focusEditor.SetFocus
				END
			END
		END ErrorClick;

		PROCEDURE LoadHandler(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR;
		BEGIN
			filenameEdit.GetAsString(filename);
			Strings.TrimWS(filename);
			IF (filename # "") THEN
				Load(filename);
			END;
		END LoadHandler;

		PROCEDURE Load(filename : ARRAY OF CHAR);
		VAR text : Texts.Text;
			res : LONGINT;
			decoder : Codecs.TextDecoder;
			in : Streams.Reader;
			hi  : HistoryItem;
		BEGIN
			IF modified & (
				WMDialogs.Confirmation("Confirmation", "The current text was not stored. Continue ?") = WMDialogs.ResNo)
			THEN RETURN
			END;
			skinFile := Archives.Old(filename, "skin");
			IF skinFile = NIL THEN
				skinFile := Archives.New(filename, "skin")
			END;
			archiveTree.SetArchive(skinFile);
			filenameEdit.SetAsString(skinFile.name);
			text := editor.text;
			modified := TRUE; (* avoid the ! on the store button while loading *)
			text.AcquireWrite;
			text.Delete(0, text.GetLength());
			decoder := Codecs.GetTextDecoder("UTF-8");
			IF decoder # NIL THEN
				Strings.Append(filename, "://skin.bsl");
				in := Codecs.OpenInputStream(filename);
				IF in # NIL THEN
					decoder.Open(in, res);
					editor.SetText(decoder.GetText());
					splitEditor.SetText(editor.text);
					editor.text.onTextChanged.Add(TextChanged);
					searchPanel.SetText(editor.text);
				ELSE
					KernelLog.String("Can't open Stream: "); KernelLog.String(filename); KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("No decoder/file found: UTF-8 / "); KernelLog.String(filename); KernelLog.Ln;
			END;
			text.ReleaseWrite;
			editor.tv.firstLine.Set(0);
			editor.tv.cursor.SetPosition(0);
			editor.tv.SetFocus;
			sidePanel.visible.Set(TRUE);
			modified := FALSE; store.caption.SetAOC("Store");
			(* original skin *)
			originalSkin := SkinEngine.current;
			(* init history *)
			NEW(history);
			NEW(hi);
			NEW(hi.text);
			CopyText(editor.text, hi.text);
			hi.skin := originalSkin;
			history.Insert(hi)
		END Load;

		PROCEDURE StoreHandler(sender, data : ANY);
		VAR filename : Files.FileName;
		BEGIN
			filenameEdit.GetAsString(filename);
			Strings.TrimWS(filename);
			IF filename # "" THEN
				Store(filename);
			ELSE
				WMDialogs.Error("Error", "Filename invalid");
			END;
		END StoreHandler;

		PROCEDURE Store(CONST filename : ARRAY OF CHAR);
		VAR text : Texts.Text; res : LONGINT;
			w : Streams.Writer;
			encoder : Codecs.TextEncoder;
			newSkinFile : Archives.Archive;
		BEGIN
			IF (skinFile = NIL) THEN
				WMDialogs.Error("Error", "No skin loaded -> Cannot store!"); (* ignore res *)
				RETURN;
			END;
			IF filename # skinFile.name THEN (* clone archive *)
				KernelLog.String("Cloning"); KernelLog.Ln;
				skinFile.Acquire;
				newSkinFile := skinFile.Copy(filename);
				skinFile.Release;
				skinFile := newSkinFile;
				archiveTree.SetArchive(skinFile)
			END;
			text := editor.text;
			text.AcquireWrite;
			IF skinFile = NIL THEN
				skinFile := Archives.Old(filename, "skin");
				IF skinFile = NIL THEN skinFile := Archives.New(filename, "skin") END
			END;
			skinFile.Acquire;
			skinFile.RemoveEntry("skin.bsl");
			Streams.OpenWriter(w, skinFile.OpenSender("skin.bsl"));
			skinFile.Release;
			encoder := Codecs.GetTextEncoder("UTF-8");
			encoder.Open(w);
			encoder.WriteText(text, res);
			text.ReleaseWrite;
			modified := FALSE; store.caption.SetAOC("Store")
		END Store;

		PROCEDURE SearchHandler(sender, data : ANY);
		BEGIN
			searchPanel.ToggleVisibility;
		END SearchHandler;

		PROCEDURE DrawCell(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR color : LONGINT; str : ARRAY 128 OF CHAR;
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
					| 1 : str := "Error Str"
				ELSE
				END
			ELSE
				CASE x OF
					| 0 : IF compileErrors.errors[y - 1].pos[0] # NIL THEN Strings.IntToStr(compileErrors.errors[y-1].pos[0].GetPosition(), str) END
					| 1 : COPY(compileErrors.errors[y-1].msg, str)
				ELSE
				END
			END;
			canvas.DrawString(4, h-4, str)
		END DrawCell;

		PROCEDURE TextChanged(sender, data : ANY);
		BEGIN
			IF logPanel.visible.Get() THEN
				logPanel.Invalidate
			END;
			IF ~modified THEN
				store.caption.SetAOC("Store !");
				modified := TRUE
			END
		END TextChanged;

		PROCEDURE Split(sender, data : ANY);
		BEGIN
			IF splitted THEN
				splitBtn.caption.Set(Strings.NewString("Split"));
				splitPanel.visible.Set(FALSE);
			ELSE
				splitBtn.caption.Set(Strings.NewString("Unsplit"));
				splitPanel.visible.Set(TRUE);
			END;
			splitted := ~splitted;
		END Split;

		PROCEDURE BackHandler(sender, data : ANY);
		VAR a : ANY;
		BEGIN
			IF history.Back() THEN
				a := history.GetCurrent();
				CopyText(a(HistoryItem).text, editor.text);
				editor.tv.cursor.SetPosition(0);
				SkinEngine.InstallSkin(a(HistoryItem).skin)
			END
		END BackHandler;

		PROCEDURE ForwardHandler(sender, data : ANY);
		VAR a : ANY;
		BEGIN
			IF history.Forward() THEN
				a := history.GetCurrent();
				CopyText(a(HistoryItem).text, editor.text);
				editor.tv.cursor.SetPosition(0);
				SkinEngine.InstallSkin(a(HistoryItem).skin)
			END
		END ForwardHandler;

		PROCEDURE ApplyHandler(sender, data : ANY);
		VAR hi : HistoryItem;
			skin : SkinEngine.Skin;
		BEGIN
			skin := CheckSkin(FALSE);
			IF skin # NIL THEN
				NEW(hi); NEW(hi.text);
				CopyText(editor.text, hi.text);
				hi.skin := skin;
				history.Insert(hi);
				SkinEngine.InstallSkin(skin)
			END
		END ApplyHandler;

		PROCEDURE CheckHandler(sender, data : ANY);
		VAR trash : SkinEngine.Skin;
		BEGIN
			trash := CheckSkin(TRUE)
		END CheckHandler;

		PROCEDURE CheckSkin(warnings : BOOLEAN) : SkinEngine.Skin;
		VAR
			tw : TextUtilities.TextWriter;
			skin : SkinEngine.Skin; skinfilename : ARRAY 128 OF CHAR;
		BEGIN
			RemovePositionMarkers();
			logEdit.text.AcquireWrite;
			logEdit.text.Delete(0, logEdit.text.GetLength());
			logEdit.tv.firstLine.Set(0); logEdit.tv.cursor.SetPosition(0);
			logEdit.text.ReleaseWrite;
			NEW(compileErrors);
			logPanel.visible.Set(FALSE);
			filenameEdit.GetAsString(skinfilename);
			skin := SkinEngine.GetSkinFromText(skinfilename, editor.text, ReportError, warnings);
			IF compileErrors.size = 0 THEN
				NEW(tw, logEdit.text);
				tw.String("No errors");
				tw.Update();
				logEdit.visible.Set(TRUE);
			ELSE
				logEdit.visible.Set(FALSE)
			END;
			RETURN skin
		END CheckSkin;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR data : XML.Element; a : XML.Attribute; n, str : ARRAY 16 OF CHAR;
			filename : ARRAY 256 OF CHAR;
		BEGIN
			IF x.msgType = WMMessages.MsgKey THEN
				IF ~searchPanel.HandleShortcut(x.x, x.flags, x.y) THEN
					Handle^(x);
				END;
			ELSIF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data); n := "SkinEditorData"; data.SetName(n);
					filenameEdit.GetAsString(filename);
					NEW(a); n := "file"; a.SetName(n); a.SetValue(filename); data.AddAttribute(a);
					NEW(a); n := "firstLine"; a.SetName(n); Strings.IntToStr(editor.tv.firstLine.Get(), str); a.SetValue(str); data.AddAttribute(a);
					NEW(a); n := "cursorPos"; a.SetName(n); Strings.IntToStr(editor.tv.cursor.GetPosition(), str); a.SetValue(str); data.AddAttribute(a);
					x.ext(WMRestorable.Storage).Add("SkinEditor", "SkinEditor.Restore", SELF, data)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE ReportError(pos, line, col : LONGINT; msg : String);
		VAR i : LONGINT;
		BEGIN
			i := 	compileErrors.size; IF i = MaxErrors THEN RETURN END; (* too many errors *)
			(* main editor *)
			compileErrors.errors[i].pos[0] := editor.tv.CreatePositionMarker();
			compileErrors.errors[i].pos[0].Load("errorpos.png");
			compileErrors.errors[i].pos[0].SetPosition(pos);
			(* split editor *)
			compileErrors.errors[i].pos[1] := splitEditor.tv.CreatePositionMarker();
			compileErrors.errors[i].pos[1].Load("errorpos.png");
			compileErrors.errors[i].pos[1].SetPosition(pos);

			COPY(msg^, compileErrors.errors[i].msg);
			logPanel.visible.Set(TRUE);
			INC(compileErrors.size);
			errorLog.nofRows.Set(errorLog.nofRows.Get()+1)
		END ReportError;

		PROCEDURE RemovePositionMarkers;
		VAR i : LONGINT;
		BEGIN
			IF compileErrors = NIL THEN RETURN END;
			FOR i := 0 TO compileErrors.size - 1 DO
				IF compileErrors.errors[i].pos[0] # NIL THEN
					editor.tv.RemovePositionMarker(compileErrors.errors[i].pos[0]);
					KernelLog.String("removed");
					compileErrors.errors[i].pos[0] := NIL;
				END;
				IF compileErrors.errors[i].pos[1] # NIL THEN
					splitEditor.tv.RemovePositionMarker(compileErrors.errors[i].pos[1]);
					compileErrors.errors[i].pos[1] := NIL
				END
			END
		END RemovePositionMarkers;

		PROCEDURE CopyText(from, to : Texts.Text);
		BEGIN
			to.AcquireWrite;
			from.AcquireRead;
			to.Delete(0, to.GetLength());
			to.CopyFromText(from, 0, from.GetLength(), 0);
			from.ReleaseRead;
			to.ReleaseWrite;
		END CopyText;

	END Window;

VAR
	nofWindows : LONGINT;

	StrPreviewPanel : String;

PROCEDURE Open*(context : Commands.Context);
VAR window : Window; filename : Files.FileName;
BEGIN
	NEW(window, NIL);
	IF context.arg.GetString(filename) THEN
		window.Load(filename);
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context)
END Restore;

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
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
	KernelLog.String("SkinEditor terminated")
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	StrPreviewPanel := Strings.NewString("PreviewPanel");
END SkinEditor.

SystemTools.Free SkinEditor ~
SkinEditor.Open ~