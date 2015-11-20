MODULE DTPEditor; (** AUTHOR "PL"; PURPOSE "Simple DTP Editor"; *)

IMPORT
	KernelLog, Modules, Commands, Files, WMRestorable, XML,
	WMStandardComponents, WMGraphics, WMComponents, WMRectangles, WMMessages, WMDialogs,
	WMEditors, Strings, Texts,
	WMWindowManager, WMPopups, Raster, XMLObjects, XMLParser, XMLScanner,
	DTPData, DTPView, DTPUtilities;

CONST
	WINDOWWIDTH = 850;
	WINDOWHEIGHT = 700;
(*
	SCREENWIDTH = 1280;
	SCREENHEIGHT = 1024;
	RULERSIZE = 20;
	HIGHLIGHT = 0FF8800FFH;
	ACTIVEFRAMECOLOR = 00000FFFFH;
	FRAMECOLOR = 00088FFFFH;
	BORDERCOLOR = 0FF00FFFFH;
	GUIDECOLOR = 000FFFFFFH;
	GRIDCOLOR = 0BABABAFFH;
	SUBGRIDCOLOR = 0DDDDDDFFH;
	ACTIVEBUTTONCOLOR = 088CCFF80H;
*)

TYPE
	pluginButtons = POINTER TO ARRAY OF WMStandardComponents.Button;

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		vc : WMComponents.VisualComponent;
		vScrollbar- : WMStandardComponents.Scrollbar;
		hScrollbar- : WMStandardComponents.Scrollbar;
		drawPanel* : DTPView.DrawPanel;
		styleEditor : DTPUtilities.StyleEditor;
		topToolbar, sideToolbar, workspace, pluginPanel : WMStandardComponents.Panel;
		masterLabel : WMStandardComponents.Label;
		filenameEdit, pageNumber, masterNumber : WMEditors.Editor;
		fileMenu, objectMenu, pageMenu, miscMenu : WMStandardComponents.Button;
		select, frame, cbutton : WMStandardComponents.Button;
		modePreview, modeMaster : WMStandardComponents.Button;
		popup : WMPopups.Popup;
		nDialog : NewDialog;
		nDiagOpen : BOOLEAN;
		scrollbar: BOOLEAN;

		currentDocument : DTPData.Document;
		cpage : DTPData.PageObject;
		cframe : DTPData.FrameObject;
		cguide : DTPData.GuideObject;

		plugName : ARRAY 32 OF CHAR;

		previewON, masterON, gridON : BOOLEAN;

		(* Plugin Buttons *)
		pbuttons : pluginButtons;
		numberOfPlugs : LONGINT;

		fileFormat : LONGINT;
		modified : BOOLEAN;
		fullScreen-: BOOLEAN;
		currentWidth, currentHeight: LONGINT;
		XMLdocLayout, XMLdocStyle, XMLdocContent: XML.Document;


		PROCEDURE CreatePluginButton(CONST pluginName: ARRAY OF CHAR): WMStandardComponents.Button;
		VAR button: WMStandardComponents.Button;
		BEGIN
			NEW(button); button.caption.SetAOC(pluginName); button.alignment.Set(WMComponents.AlignTop);
			button.onClick.Add(SetPluginHandler);
			(* button.clDefault.Set(01010C080H); *)
			button.isToggle.Set(TRUE);
			RETURN button;
		END CreatePluginButton;

		PROCEDURE LoadPlugins;
		VAR plugName : ARRAY 16 OF CHAR;
			plugList : PluginList;
			plugListEntry : PluginListEntry;
			i : LONGINT;
			(* button: WMStandardComponents.Button;	*)
		BEGIN
			plugList := plugRegistry.GetPluginList();
			numberOfPlugs := plugRegistry.GetNumberOfPlugins();
			NEW(pbuttons, numberOfPlugs);
			KernelLog.String("DTPEditor Registered Plugins: "); KernelLog.Int(plugRegistry.GetNumberOfPlugins(), 0); KernelLog.Ln;

			plugListEntry := plugList.first; i := 0;
			(* Loop over plugs *)
			WHILE plugListEntry # NIL DO
				COPY(plugListEntry.pname, plugName);
				KernelLog.String("Initializing "); KernelLog.String(plugName); KernelLog.Ln;
				pbuttons[i] := CreatePluginButton(plugName);
				plugListEntry := plugListEntry.next; INC(i);
			END;

(*
			plugName := "Rectangle";
			NEW(button); button.caption.SetAOC(plugName); button.alignment.Set(WMComponents.AlignTop);
			button.onClick.Add(SetPluginHandler);
			pbuttons[0] := button;

			plugName := "Image";
			NEW(button); button.caption.SetAOC(plugName); button.alignment.Set(WMComponents.AlignTop);
			button.onClick.Add(SetPluginHandler);
			pbuttons[1] := button;
*)
		END LoadPlugins;

		PROCEDURE AddPlugins(): WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel;
			button: WMStandardComponents.Button;
			i : LONGINT;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignTop); panel.bounds.SetHeight(30*numberOfPlugs);
			FOR i := 0 TO numberOfPlugs-1 DO
				button := pbuttons[i];
				panel.AddContent(button);
			END;
			RETURN panel;
		END AddPlugins;

		PROCEDURE CreateFormWindow() : WMComponents.VisualComponent;
		VAR
			panel, cpan : WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
			label : WMStandardComponents.Label;
			manager : WMWindowManager.WindowManager;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;

		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel); panel.bounds.SetExtents(WINDOWWIDTH,WINDOWHEIGHT);
			panel.fillColor.Set(0FFFFFFFFH);
			panel.takesFocus.Set(TRUE);
			NEW(topToolbar); topToolbar.bounds.SetHeight(20);
			topToolbar.alignment.Set(WMComponents.AlignTop); topToolbar.fillColor.Set(panelColor);
			panel.AddContent(topToolbar);

			NEW(filenameEdit);
			filenameEdit.alignment.Set(WMComponents.AlignLeft);
			filenameEdit.multiLine.Set(FALSE); filenameEdit.bounds.SetWidth(200);
			topToolbar.AddContent(filenameEdit); filenameEdit.fillColor.Set(0FFFFFFFFH);
			filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filenameEdit.tv.showBorder.Set(TRUE);
			filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			filenameEdit.onEnter.Add(LoadHandler);

			NEW(fileMenu); fileMenu.caption.SetAOC("Document"); fileMenu.alignment.Set(WMComponents.AlignLeft);
			fileMenu.SetExtPointerDownHandler(FileMenuHandler);fileMenu.bounds.SetWidth(80);
			topToolbar.AddContent(fileMenu);

			NEW(pageMenu); pageMenu.caption.SetAOC("Page"); pageMenu.alignment.Set(WMComponents.AlignLeft);
			pageMenu.SetExtPointerDownHandler(PageMenuHandler);
			topToolbar.AddContent(pageMenu);

			NEW(objectMenu); objectMenu.caption.SetAOC("Object"); objectMenu.alignment.Set(WMComponents.AlignLeft);
			objectMenu.SetExtPointerDownHandler(ObjectMenuHandler);
			topToolbar.AddContent(objectMenu);

			NEW(miscMenu); miscMenu.caption.SetAOC("Misc"); miscMenu.alignment.Set(WMComponents.AlignLeft);
			miscMenu.SetExtPointerDownHandler(MiscMenuHandler);
			topToolbar.AddContent(miscMenu);

			NEW(label); label.bounds.SetWidth(100); label.alignment.Set(WMComponents.AlignLeft);
			label.SetCaption(" "); label.fillColor.Set(panelColor);
			topToolbar.AddContent(label);

(*			(* linked masterpage *)
			NEW(masterLabel); masterLabel.bounds.SetWidth(100); masterLabel.alignment.Set(WMComponents.AlignLeft);
			masterLabel.SetCaption(" Linked Master:"); masterLabel.fillColor.Set(panelColor);
			topToolbar.AddContent(masterLabel);
			NEW(masterNumber);
			masterNumber.alignment.Set(WMComponents.AlignLeft);
			masterNumber.multiLine.Set(FALSE); masterNumber.bounds.SetWidth(150);
			masterNumber.fillColor.Set(0FFFFFFFFH);
			masterNumber.tv.textAlignV.Set(WMGraphics.AlignCenter);
			masterNumber.tv.showBorder.Set(TRUE);
			masterNumber.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			masterNumber.onEnter.Add(SetMasterHandler);
			masterNumber.SetAsString("none");
			topToolbar.AddContent(masterNumber);
*)
			(* workspace *)
			NEW(workspace);
			workspace.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(workspace);

			NEW(sideToolbar); sideToolbar.bounds.SetWidth(100);
			sideToolbar.alignment.Set(WMComponents.AlignLeft); sideToolbar.fillColor.Set(panelColor);
			workspace.AddContent(sideToolbar);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" TOOLS"); label.fillColor.Set(panelColor);
			sideToolbar.AddContent(label);

			NEW(select); select.caption.SetAOC("Select"); select.alignment.Set(WMComponents.AlignTop);
			select.onClick.Add(SelectHandler);
			select.isToggle.Set(TRUE); select.SetPressed(TRUE);
			sideToolbar.AddContent(select);
			cbutton := select;
			(* cbutton.clDefault.Set(ACTIVEBUTTONCOLOR); *)
			(* cbutton.clDefault.Set(01010C080H); *)

			NEW(frame); frame.caption.SetAOC("Frame"); frame.alignment.Set(WMComponents.AlignTop);
			frame.onClick.Add(SetPluginHandler); (* frame.clDefault.Set(01010C080H); *)
			frame.isToggle.Set(TRUE);
			sideToolbar.AddContent(frame);

			(* ADD PLUGINS here *)
			pluginPanel := AddPlugins();
			sideToolbar.AddContent(pluginPanel);

			NEW(button); button.caption.SetAOC("## DEBUG ##"); button.alignment.Set(WMComponents.AlignTop);
			button.onClick.Add(TestHandler);	 button.clDefault.Set(000FF0080H);
			(* sideToolbar.AddContent(button); *)

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" VIEW"); label.fillColor.Set(panelColor);
			sideToolbar.AddContent(label);

			NEW(cpan); (* cpan.fillColor.Set(0FF0000FFH); *) cpan.bounds.SetWidth(100); cpan.bounds.SetHeight(40);
			cpan.alignment.Set(WMComponents.AlignTop);
			sideToolbar.AddContent(cpan);

			NEW(modeMaster); modeMaster.caption.SetAOC(" MasterPage"); modeMaster.alignment.Set(WMComponents.AlignTop);
			modeMaster.onClick.Add(MasterHandler);
			cpan.AddContent(modeMaster);

			NEW(modePreview); modePreview.caption.SetAOC(" PreviewMode"); modePreview.alignment.Set(WMComponents.AlignTop);
			modePreview.onClick.Add(PreviewHandler);
			cpan.AddContent(modePreview);

			(* linked masterpage *)
			NEW(masterLabel); masterLabel.bounds.SetHeight(16); masterLabel.alignment.Set(WMComponents.AlignTop);
			masterLabel.SetCaption(" Linked Master:"); masterLabel.fillColor.Set(panelColor);
			masterLabel.SetFont(WMGraphics.GetFont("Oberon", 10, {}));
			sideToolbar.AddContent(masterLabel);
			NEW(masterNumber);
			masterNumber.alignment.Set(WMComponents.AlignTop);
			masterNumber.multiLine.Set(FALSE); masterNumber.bounds.SetHeight(20);
			masterNumber.fillColor.Set(0FFFFFFFFH);
			masterNumber.tv.textAlignV.Set(WMGraphics.AlignCenter);
			masterNumber.tv.showBorder.Set(TRUE);
			masterNumber.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			masterNumber.onEnter.Add(SetMasterHandler);
			masterNumber.SetAsString("none");
			sideToolbar.AddContent(masterNumber);

			NEW(label); label.bounds.SetHeight(16); label.alignment.Set(WMComponents.AlignTop);
			label.SetFont(WMGraphics.GetFont("Oberon", 10, {}));
			label.SetCaption(" Page / Zoom:"); label.fillColor.Set(panelColor);
			sideToolbar.AddContent(label);

			(*  |<  <<  page >>  >| *)
			NEW(cpan); (* cpan.fillColor.Set(0000000FFH); *) cpan.bounds.SetWidth(100); cpan.bounds.SetHeight(20);
			cpan.alignment.Set(WMComponents.AlignTop);
			sideToolbar.AddContent(cpan);

			NEW(button); button.caption.SetAOC("|<"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(FirstPageHandler); button.bounds.SetWidth(18);
			cpan.AddContent(button);
			NEW(button); button.caption.SetAOC("<<"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(PrevPageHandler); button.bounds.SetWidth(18);
			cpan.AddContent(button);
			NEW(pageNumber);
			pageNumber.alignment.Set(WMComponents.AlignLeft);
			pageNumber.multiLine.Set(FALSE); pageNumber.bounds.SetWidth(28);
			cpan.AddContent(pageNumber); pageNumber.fillColor.Set(0FFFFFFFFH);
			pageNumber.tv.textAlignV.Set(WMGraphics.AlignCenter);
			pageNumber.tv.showBorder.Set(TRUE);
			pageNumber.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			pageNumber.onEnter.Add(GoToPageHandler);
			pageNumber.SetAsString("0");
			NEW(button); button.caption.SetAOC(">>"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(NextPageHandler); button.bounds.SetWidth(18);
			cpan.AddContent(button);
			NEW(button); button.caption.SetAOC(">|"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(LastPageHandler); button.bounds.SetWidth(18);
			cpan.AddContent(button);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Zoom:"); label.fillColor.Set(panelColor);
(*			sideToolbar.AddContent(label); *)

			NEW(cpan); (* cpan.fillColor.Set(0000000FFH); *) cpan.bounds.SetHeight(20);
			cpan.alignment.Set(WMComponents.AlignTop);
			sideToolbar.AddContent(cpan);
			NEW(button); button.caption.SetAOC("-"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(ZoomUserHandler); button.bounds.SetWidth(50);
			cpan.AddContent(button);
			NEW(button); button.caption.SetAOC("+"); button.alignment.Set(WMComponents.AlignLeft);
			button.onClick.Add(ZoomUserHandler); button.bounds.SetWidth(50);
			cpan.AddContent(button);

			(* DrawPanel *)
			NEW(vScrollbar); vScrollbar.alignment.Set(WMComponents.AlignRight);
			workspace.AddContent(vScrollbar);
			NEW(hScrollbar); hScrollbar.alignment.Set(WMComponents.AlignBottom);
			hScrollbar.vertical.Set(FALSE);
			workspace.AddContent(hScrollbar);
			NEW(drawPanel); drawPanel.alignment.Set(WMComponents.AlignClient);
			(* Settings *)
			drawPanel.newPluginObject := CreateContent;
			drawPanel.ownerWindowSetFocus := SetActive;
			drawPanel.ownerWindowUpdatePageNumber := UpdatePageNumber;
			drawPanel.ownerWindowExitFullScreen := EscFullScreen;
			drawPanel.ShowGrid(gridON);
			drawPanel.SetScrollbars(hScrollbar, vScrollbar);
			workspace.AddContent(drawPanel);

			RETURN panel
		END CreateFormWindow;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR
			(* vc : WMComponents.VisualComponent;
			s : Strings.String;	*)

		BEGIN
			IncCount;
			fileFormat := 0;
			previewON := FALSE; masterON := FALSE; gridON := TRUE;
			manager := WMWindowManager.GetDefaultManager();
			LoadPlugins;
			vc := CreateFormWindow();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(),FALSE);
			SetContent(vc);
			modified := FALSE;
			currentDocument := NIL;
			plugName := "none";

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
				(*	xml := c.appData(XML.Element);
					s := xml.GetAttributeValue("fileFormat");	IF s # NIL THEN Strings.StrToInt(s^, fileFormat) END;
					s := xml.GetAttributeValue("firstLine");IF s # NIL THEN Strings.StrToInt(s^, fl) END;
					s := xml.GetAttributeValue("cursorPos");IF s # NIL THEN Strings.StrToInt(s^, cp) END;
					s := xml.GetAttributeValue("file");
					IF s # NIL THEN Load(s^, fileFormat) END;
					editor.tv.firstLine.Set(fl);
					editor.tv.cursor.SetPosition(cp) *)
				END
			ELSE WMWindowManager.DefaultAddWindow(SELF)
			END;
			SetTitle(Strings.NewString("DTPEditor"));
			(* NEW(props, SELF); props.Show; propertyOpen := TRUE; *)

			nDiagOpen := FALSE;
			scrollbar := TRUE;
			fullScreen := FALSE;

		END New;

		PROCEDURE CheckScrollbars*;
		BEGIN
			IF scrollbar THEN
				vScrollbar.visible.Set(TRUE); hScrollbar.visible.Set(TRUE)
			ELSE
				vScrollbar.visible.Set(FALSE); hScrollbar.visible.Set(FALSE)
			END
		END CheckScrollbars;

		PROCEDURE SetActive*;
		BEGIN
			manager:= WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
			drawPanel.SetFocus();
		END SetActive;

		PROCEDURE SetDocument(newdocument : DTPData.Document);
		BEGIN
			currentDocument := newdocument;
		END SetDocument;

(*
		PROCEDURE GetDocument(): DTPData.Document;
		BEGIN
			RETURN currentDocument;
		END GetDocument;
*)
		PROCEDURE SelectHandler(sender, data : ANY);
		VAR i : LONGINT;
		BEGIN
			drawPanel.selectionON := TRUE;
			(* cbutton.clDefault.Set(01010C080H); *) (* restore old Color *)
			(* reset toggles *)
			frame.SetPressed(FALSE);
			FOR i := 0 TO numberOfPlugs-1 DO
				pbuttons[i].SetPressed(FALSE);
			END;
			cbutton.Invalidate;
			cbutton := sender(WMStandardComponents.Button);
			(* cbutton.clDefault.Set(ACTIVEBUTTONCOLOR); *)
			cbutton.Invalidate;
		END SelectHandler;

		PROCEDURE SetPluginHandler(sender, data : ANY);
		VAR name, msg: ARRAY 32 OF CHAR;
			string: Strings.String;
			i : LONGINT;
			(* res : LONGINT;	*)
		BEGIN
			drawPanel.selectionON := FALSE;
			msg := "";

			string := sender(WMStandardComponents.Button).caption.Get();
			drawPanel.activeTool := string;
			COPY(string^, name);
			COPY(name, plugName);
			KernelLog.String("Active Plugin: ");KernelLog.String(name); KernelLog.Ln;

			(* reset toggles *)
			select.SetPressed(FALSE);
			IF sender(WMStandardComponents.Button) # frame THEN frame.SetPressed(FALSE) END;
			FOR i := 0 TO numberOfPlugs-1 DO
				IF sender(WMStandardComponents.Button) # pbuttons[i] THEN
					pbuttons[i].SetPressed(FALSE)
				END
			END;
			(* cbutton.clDefault.Set(01010C080H); *)(* restore old Color *)
			cbutton.Invalidate;
			cbutton := sender(WMStandardComponents.Button);
			(* cbutton.clDefault.Set(ACTIVEBUTTONCOLOR); *)
			cbutton.Invalidate;

(*			(* set the current Plugin *)
			IF name = "Frame" THEN
				(* Commands.Call("DTPFrame.Set", {}, res, msg); *)
				(* drawPanel.newPluginObject := CreateContent(); *)

			ELSIF name = "Rectangle" THEN

			ELSIF name = "Image" THEN
				(* Commands.Call("DTPImage.Set", {}, res, msg); *)
			ELSE
			END;
*)
		END SetPluginHandler;

		PROCEDURE CreateContent*():DTPData.ContentObject;
		VAR content : DTPData.ContentObject;
		BEGIN

			IF plugName = "Frame" THEN
				KernelLog.String("Create Content Object: Empty Frame"); KernelLog.Ln;
				content := DTPData.NewObject();
			ELSE
				content := plugRegistry.InstantiatePlugin(plugName);
				content.redrawProc := drawPanel.InvalidateCurrentFrame;
				content.updatePropsPosition := drawPanel.SetContentPropsPosition;
				KernelLog.String("Create Content Object: "); KernelLog.String(plugName); KernelLog.Ln;
			END;
			content.OnCreate;

(*			IF plugName = "Frame" THEN
				KernelLog.String("..Creating Frame.."); KernelLog.Ln;
				content := DTPFrame.NewObject();
			ELSIF plugName = "Rectangle" THEN
				KernelLog.String("..Creating Rectangle.."); KernelLog.Ln;
				content := plugRegistry.InstantiatePlugin("Rectangle");
			ELSIF plugName = "Image" THEN
				KernelLog.String("..Creating Image.."); KernelLog.Ln;
				content := plugRegistry.InstantiatePlugin("Image");
			ELSE

			END;
*)

			RETURN content;
		END CreateContent;

		PROCEDURE TestHandler(sender, data : ANY);
		VAR str : ARRAY 16 OF CHAR;
			i: LONGINT;
		BEGIN
			IF currentDocument = NIL THEN
				KernelLog.String("##DEBUG: No Document present");
			ELSE
				Strings.FloatToStr(currentDocument.GetPageWidth(), 0,9,0, str);
				KernelLog.String("##DEBUG: current PageWidth: "); KernelLog.String(str); KernelLog.Ln;
				Strings.FloatToStr(currentDocument.GetPageHeight(), 0,9,0, str);
				KernelLog.String("##DEBUG: current PageHeight: "); KernelLog.String(str); KernelLog.Ln;
				Strings.FloatToStr(drawPanel.GetZoomFactor(), 0,9,0, str);
				KernelLog.String("##DEBUG: current zoomFactor: "); KernelLog.String(str); KernelLog.Ln;
				i := 0; cpage := currentDocument.GetCurrentPage();
				IF cpage # NIL THEN
					cframe := cpage.GetFirstFrame();
					WHILE cframe # NIL DO
						cframe := cframe.next;
						INC(i);
					END;
					KernelLog.String("##DEBUG: Frames on current page: "); KernelLog.Int(i, 0); KernelLog.Ln;
				END;
			END;
(*			drawPanel.ready := TRUE;
			drawPanel.Invalidate;
*)
		END TestHandler;

		PROCEDURE MasterHandler(sender, data: ANY);
		BEGIN
			IF masterON THEN
				masterON := FALSE;
				modeMaster.caption.SetAOC("MasterPage");
				masterNumber.fillColor.Set(0FFFFFFFFH); masterNumber.tv.defaultTextBgColor.Set(0FFFFFFFFH);
				masterLabel.caption.SetAOC(" Linked Master:");
			ELSE
				masterON := TRUE;
				modeMaster.caption.SetAOC("Document");
				masterNumber.fillColor.Set(0BBBBBBFFH); masterNumber.tv.defaultTextBgColor.Set(0BBBBBBFFH);
				masterLabel.caption.SetAOC(" Master Name:");
			END;
			drawPanel.SetMasterEditMode(masterON);
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			UpdatePageNumber;
		END MasterHandler;

		PROCEDURE PreviewHandler(sender, data: ANY);
		VAR
		BEGIN
			IF previewON THEN
				previewON := FALSE;
				modePreview.caption.SetAOC("PreviewMode");
			ELSE
				previewON := TRUE;
				modePreview.caption.SetAOC("EditMode");
			END;
			(* Remove Current Selection to avoid updating the Content Property Window *)
			IF ~masterON THEN
				cpage := currentDocument.GetCurrentPage();
			ELSE
				cpage := currentDocument.GetCurrentMasterPage();
			END;
			cpage.SetCurrentFrame(NIL);

			drawPanel.SetPreviewMode(previewON);
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			drawPanel.Invalidate;
			SetActive;
		END PreviewHandler;

		PROCEDURE FileMenuHandler(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			NEW(popup);
			popup.Add("New", NewHandler);
			popup.Add("Open", LoadHandler);
			popup.Add("Save", StoreHandler);
			popup.Add("Export Page", ExportHandler);
			handled := TRUE;
			rectangle := fileMenu.bounds.Get();
			popup.Popup(bounds.l + rectangle.l, bounds.t + rectangle.b);
		END FileMenuHandler;

		PROCEDURE ObjectMenuHandler(x, y: LONGINT; keys: SET; VAR handled: BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			NEW(popup);
			popup.Add("Cut", ObjectCutHandler);
			popup.Add("Copy", ObjectCopyHandler);
			popup.Add("Paste", ObjectPasteHandler);
			popup.Add("Delete", ObjectDeleteHandler);
			popup.Add("Move Front", ObjectToFrontHandler);
			popup.Add("Front Step", ObjectFrontStepHandler);
			popup.Add("Back Step", ObjectBackStepHandler);
			popup.Add("Move Back", ObjectToBackHandler);
			popup.Add("Select Previous", ObjectPrevHandler);
			popup.Add("Select Next", ObjectNextHandler);
			handled := TRUE;
			rectangle := objectMenu.bounds.Get();
			popup.Popup(bounds.l + rectangle.l, bounds.t + rectangle.b);
		END ObjectMenuHandler;

		PROCEDURE PageMenuHandler(x, y: LONGINT; keys: SET; VAR handled: BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			NEW(popup);
			popup.Add("Insert Before", AddBeforePageHandler);
			popup.Add("Insert After", AddAfterPageHandler);
			popup.Add("Delete", DeletePageHandler);
			handled := TRUE;
			rectangle := pageMenu.bounds.Get();
			popup.Popup(bounds.l + rectangle.l, bounds.t + rectangle.b);
		END PageMenuHandler;

		PROCEDURE MiscMenuHandler(x, y: LONGINT; keys: SET; VAR handled: BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			NEW(popup);
			popup.Add("StyleEditor", MiscStyleEditorHandler);
			popup.Add("Snap To Grid", SnapHandler);
			popup.Add("Toggle Grid", GridHandler);
			popup.Add("Show Properties", PropsHandler);
			popup.Add("FullScreen", FullScreenHandler);
			popup.Add("Zoom Fit Doc", ZoomHandler);
			popup.Add("Zoom Fit Width", ZoomHandler);
			popup.Add("Zoom Fit Height", ZoomHandler);
			popup.Add("Zoom Fit Frame", ZoomHandler);
			popup.Add("Zoom Orig. Size", ZoomHandler);
			(* popup.Add("Reload Plugins", PlugHandler);	 *)
			handled := TRUE;
			rectangle := miscMenu.bounds.Get();
			popup.Popup(bounds.l + rectangle.l, bounds.t + rectangle.b);
		END MiscMenuHandler;

		PROCEDURE ZoomHandler(sender, data: ANY);
		VAR button: WMStandardComponents.Button;
			tempString: Strings.String;
		BEGIN
			popup.Close;
			IF sender IS WMStandardComponents.Button THEN
				button := sender(WMStandardComponents.Button);
				tempString := button.caption.Get();
				IF (tempString^ = "Zoom Fit Doc") THEN
					drawPanel.SetZoomMode(0);
				ELSIF (tempString^ = "Zoom Fit Width") THEN
					drawPanel.SetZoomMode(1);
				ELSIF (tempString^ = "Zoom Fit Height") THEN
					drawPanel.SetZoomMode(2);
				ELSIF (tempString^ = "Zoom Fit Frame") THEN
					drawPanel.SetZoomMode(3);
				ELSIF (tempString^ = "Zoom Orig. Size") THEN
					drawPanel.SetZoomMode(4);
				ELSE
					drawPanel.SetZoomMode(0);
				END;
			END;
		END ZoomHandler;

		PROCEDURE ZoomUserHandler(sender, data: ANY);
		VAR button : WMStandardComponents.Button;
			tempString: Strings.String;
		BEGIN
			IF sender IS WMStandardComponents.Button THEN
				button := sender(WMStandardComponents.Button);
				tempString := button.caption.Get();
				IF (tempString^ = "-") THEN
					drawPanel.ZoomDecrease;
					drawPanel.SetZoomMode(5);
				ELSIF (tempString^ = "+") THEN
					drawPanel.ZoomIncrease;
					drawPanel.SetZoomMode(5);
				ELSE
				END;
			END;

		END ZoomUserHandler;

		PROCEDURE GridHandler(sender, data: ANY);
		BEGIN
			IF gridON THEN
				gridON := FALSE;
				drawPanel.ShowGrid(gridON);
			ELSE
				gridON := TRUE;
				drawPanel.ShowGrid(gridON);
			END;
			popup.Close;
			drawPanel.Invalidate;
		END GridHandler;

		PROCEDURE SnapHandler(sender, data: ANY);
		BEGIN
			drawPanel.SetSnap(~drawPanel.GetSnap());
			popup.Close;
		END SnapHandler;

		PROCEDURE FullScreenHandler*(sender, data: ANY);
		VAR rect : WMRectangles.Rectangle;
			height, width : LONGINT;
			view : WMWindowManager.ViewPort;
		BEGIN
			popup.Close;
			view := WMWindowManager.GetDefaultView();
			IF ~fullScreen THEN
				(* drawPanel.SetZoomMode(0); *)
				rect := bounds; fullScreen := TRUE;
				currentWidth := GetWidth(); currentHeight := GetHeight();
				(* width := SCREENWIDTH+160; height := SCREENHEIGHT+85; *)
				width := ENTIER(view.range.r - view.range.l) + ((bounds.r - bounds.l) - (drawPanel.bounds.GetWidth())) + 45;
				height := ENTIER(view.range.b - view.range.t) + ((bounds.b - bounds.t) - (drawPanel.bounds.GetHeight()) + 45);
				manager := WMWindowManager.GetDefaultManager();
				manager.SetWindowPos(SELF,  ENTIER(view.range.l) - ((bounds.r - bounds.l) - (drawPanel.bounds.GetWidth()))- 15,
					ENTIER(view.range.t) - ((bounds.b - bounds.t) - (drawPanel.bounds.GetHeight())) - 15);
				manager.SetWindowSize(SELF, width, height);
				Resized(width, height);
			ELSE
				fullScreen := FALSE;
				width := currentWidth; height := currentHeight;
				manager := WMWindowManager.GetDefaultManager();
				manager.SetWindowSize(SELF, width, height);
				manager.SetWindowPos(SELF, ENTIER(view.range.l), ENTIER(view.range.t));
				Resized(width, height);
			END;
			drawPanel.Resized;

		END FullScreenHandler;

		PROCEDURE EscFullScreen*;
		VAR height, width : LONGINT;
		BEGIN
			IF fullScreen THEN
				fullScreen := FALSE;
				width := currentWidth; height := currentHeight;
				manager := WMWindowManager.GetDefaultManager();
				manager.SetWindowSize(SELF, width, height);
				manager.SetWindowPos(SELF, bounds.l+135, bounds.t+70);
				Resized(width, height);
			END;
		END EscFullScreen;

		PROCEDURE LoadHandler(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR;
		BEGIN
			filenameEdit.GetAsString(filename);
			Load(filename, fileFormat);
			IF popup # NIL THEN popup.Close; END;
		END LoadHandler;

		PROCEDURE LoadCharacterStyle(cstyle : DTPData.CharacterStyleObject);
		VAR style : Texts.CharacterStyle;
		BEGIN
			NEW(style);
			COPY(cstyle.name, style.name);
			COPY(cstyle.family, style.family);
			style.style := cstyle.style;
			style.size := DTPUtilities.FloatToFixp(cstyle.size);
			style.leading := DTPUtilities.FloatToFixp(cstyle.leading);
			style.baselineShift := DTPUtilities.FloatToFixp(cstyle.baselineShift);
			style.color := cstyle.color;
			style.bgColor := cstyle.bgColor;
			style.tracking := DTPUtilities.FloatToFixp(cstyle.tracking);
			(* style.kerning := cstyle.kerning; *)
			style.scaleHorizontal := DTPUtilities.FloatToFixp(cstyle.scaleHorizontal);
			style.scaleVertical := DTPUtilities.FloatToFixp(cstyle.scaleVertical);

			Texts.AddCharacterStyle(style);
		END LoadCharacterStyle;

		PROCEDURE LoadParagraphStyle(pstyle : DTPData.ParagraphStyleObject);
		VAR style : Texts.ParagraphStyle;
			cstyle : Texts.CharacterStyle;
		BEGIN
			NEW(style);
			COPY(pstyle.name, style.name);
			style.alignment := pstyle.alignment;
			style.firstIndent := DTPUtilities.FloatToFixp(pstyle.firstIndent);
			style.leftIndent := DTPUtilities.FloatToFixp(pstyle.leftIndent);
			style.rightIndent := DTPUtilities.FloatToFixp(pstyle.rightIndent);
			style.spaceBefore := DTPUtilities.FloatToFixp(pstyle.spaceBefore);
			style.spaceAfter := DTPUtilities.FloatToFixp(pstyle.spaceAfter);
			NEW(cstyle);
			COPY(pstyle.charStyle.name, cstyle.name);
			COPY(pstyle.charStyle.family, cstyle.family);
			cstyle.style := pstyle.charStyle.style;
			cstyle.size := DTPUtilities.FloatToFixp(pstyle.charStyle.size);
			cstyle.leading := DTPUtilities.FloatToFixp(pstyle.charStyle.leading);
			cstyle.baselineShift := DTPUtilities.FloatToFixp(pstyle.charStyle.baselineShift);
			cstyle.color := pstyle.charStyle.color;
			cstyle.bgColor := pstyle.charStyle.bgColor;
			cstyle.tracking := DTPUtilities.FloatToFixp(pstyle.charStyle.tracking);
			(* cstyle.kerning := pstyle.charStyle.kerning; *)
			cstyle.scaleHorizontal := DTPUtilities.FloatToFixp(pstyle.charStyle.scaleHorizontal);
			cstyle.scaleVertical := DTPUtilities.FloatToFixp(pstyle.charStyle.scaleVertical);
			style.charStyle := cstyle;

			Texts.AddParagraphStyle(style);
		END LoadParagraphStyle;

		PROCEDURE Load(CONST filename : ARRAY OF CHAR; format : LONGINT);
		VAR tempString : ARRAY 256 OF CHAR;
			parser : XMLParser.Parser;
			scanner : XMLScanner.Scanner;
			reader : Files.Reader;
			f : Files.File;
		BEGIN
			fileFormat := format;
			filenameEdit.SetAsString(filename);

			(* Load Style File *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Style.XML");
			f := Files.Old(tempString);
			IF f = NIL THEN RETURN END;
			NEW(reader, f, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			XMLdocStyle := parser.Parse();

			(* Load Content File *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Content.XML");
			f := Files.Old(tempString);
			IF f = NIL THEN RETURN END;
			NEW(reader, f, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			XMLdocContent := parser.Parse();

			(* Load Layout File *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Layout.XML");
			f := Files.Old(tempString);
			IF f = NIL THEN RETURN END;
			NEW(reader, f, 0);
			NEW(scanner, reader);
			NEW(parser, scanner);
			XMLdocLayout := parser.Parse();

			BuildDocFromXML;
			modified := FALSE;
		END Load;

		PROCEDURE BuildDocFromXML;
		VAR built : DTPData.Document;
			root: XML.Element;
			cont, pagecont: XMLObjects.Enumerator;
			contptr, ptr: ANY; str, name : Strings.String;
			pStyle: DTPData.ParagraphStyleObject;
			cStyle: DTPData.CharacterStyleObject;
			content : DTPData.ContentObject;
			page : DTPData.PageObject; mpage: DTPData.MasterPageObject;
			frame : DTPData.FrameObject;
			tempReal: LONGREAL; tempInt, res : LONGINT; tempBool: BOOLEAN;
			mt, mb, ml, mr: REAL;
		BEGIN
			NEW(built, 0, 0, 0, 0, 0, 0, FALSE);
			(* build styleArray *)
			root := XMLdocStyle.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					(* KernelLog.String(str^); KernelLog.Ln; *)
					IF (str # NIL) & (str^ = "character-style") THEN					(* character styles *)
						NEW(cStyle);
						str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, cStyle.name) END;
						str := ptr(XML.Element).GetAttributeValue("font-family"); IF str # NIL THEN COPY(str^, cStyle.family) END;
						str := ptr(XML.Element).GetAttributeValue("font-style");
						IF str # NIL THEN
							IF (str^ = "0") THEN cStyle.style := {};
							ELSIF (str^ = "1") THEN cStyle.style := {0};
							ELSIF (str^ = "2") THEN cStyle.style := {1};
							ELSIF (str^ = "3") THEN cStyle.style := {0,1};
							ELSE cStyle.style := {};
							END;
						END;
						str := ptr(XML.Element).GetAttributeValue("font-size"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.size := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("leading"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.leading := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("baseline-shift"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.baselineShift := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("color"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.color := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("bgcolor"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, res); cStyle.bgColor := tempInt; END;
						str := ptr(XML.Element).GetAttributeValue("tracking"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.tracking := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("kerning"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.kerning := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("h-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleHorizontal := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("v-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleVertical := SHORT(tempReal); END;
						built.AddStyle(cStyle);
						LoadCharacterStyle(cStyle);									(* Load the Style into Texts *)

					ELSIF (str # NIL) & (str^ = "paragraph-style") THEN				(* paragraph styles *)
						NEW(pStyle);
						str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, pStyle.name) END;
						str := ptr(XML.Element).GetAttributeValue("alignment"); IF str # NIL THEN Strings.StrToInt(str^, pStyle.alignment) END;
						str := ptr(XML.Element).GetAttributeValue("first-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.firstIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("left-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.leftIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("right-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.rightIndent := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("space-before"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceBefore := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("space-after"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceAfter := SHORT(tempReal); END;
						str := ptr(XML.Element).GetAttributeValue("character-style");
						IF str # NIL THEN
							cStyle := built.GetCharacterStyleByName(str^);
							IF cStyle # NIL THEN pStyle.charStyle := cStyle; END;
						END;
						built.AddStyle(pStyle);
						LoadParagraphStyle(pStyle);
					END;
				END;
			END;

			(* build contentArray *)
			root := XMLdocContent.GetRoot();
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext(); contptr := ptr;
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					(* KernelLog.String(str^); KernelLog.Ln; *)
					IF (str # NIL) & (str^ = "node") THEN					(* contents *)
						name := ptr(XML.Element).GetAttributeValue("name");

						pagecont := ptr(XML.Element).GetContents(); pagecont.Reset();
						WHILE pagecont.HasMoreElements() DO
							ptr := pagecont.GetNext();
							IF ptr IS XML.Element THEN
								str := ptr(XML.Element).GetAttributeValue("name");
								IF (str # NIL) & (str^ = "type") THEN
									str := ptr(XML.Element).GetAttributeValue("value");

									IF str # NIL THEN								(* instantiate plugin *)
										(* KernelLog.String(str^); *)
										IF str^ = "Frame" THEN
											content := DTPData.NewObject();
										ELSE
											content := plugRegistry.InstantiatePlugin(str^);
										END;
										IF content # NIL THEN
											content.contentName := name;
											content.ownerDoc := built;
											content.redrawProc := drawPanel.InvalidateCurrentFrame;
											content.updatePropsPosition := drawPanel.SetContentPropsPosition;
											content.Load(contptr(XML.Element));
											built.AddContent(content);
										ELSE
											KernelLog.String("DTPEditor Load ERROR: plugin not found - cannot load object"); KernelLog.Ln;
											content := DTPData.NewObject();
											content.contentName := name;
											content.ownerDoc := built;
											content.redrawProc := drawPanel.InvalidateCurrentFrame;
											content.updatePropsPosition := drawPanel.SetContentPropsPosition;
											built.AddContent(content);

										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
			(* Fix all Links in ContentArray *)
			built.FixContents;

			(* build layout & wire styles/contents *)
			root := XMLdocLayout.GetRoot();
			IF root # NIL THEN													(* load document attributes *)
				str := root.GetAttributeValue("page-width"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); built.SetPageWidth(SHORT(tempReal)) END;
				str := root.GetAttributeValue("page-height"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); built.SetPageHeight(SHORT(tempReal)) END;
				str := root.GetAttributeValue("margin-top"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mt := SHORT(tempReal) END;
				str := root.GetAttributeValue("margin-bottom"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mb := SHORT(tempReal) END;
				str := root.GetAttributeValue("margin-left"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); ml := SHORT(tempReal) END;
				str := root.GetAttributeValue("margin-right"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mr := SHORT(tempReal) END;
				built.SetMargins(mt, mb, ml, mr);
				str := root.GetAttributeValue("facing-pages"); IF str # NIL THEN Strings.StrToBool(str^, tempBool); built.SetFacingPages(tempBool) END;
			END;
			cont := root.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN
					str := ptr(XML.Element).GetName();
					(* KernelLog.String(str^); KernelLog.Ln; *)
					IF (str # NIL) & (str^ = "masterpage") THEN					(* masterpage *)
						str := ptr(XML.Element).GetAttributeValue("name");
						built.AddMasterPage(TRUE);	page := built.GetLastMasterPage();
						IF str # NIL THEN page(DTPData.MasterPageObject).mpageName := str; END;

						pagecont := ptr(XML.Element).GetContents(); pagecont.Reset();
						WHILE pagecont.HasMoreElements() DO
							ptr := pagecont.GetNext();
							IF ptr IS XML.Element THEN
								str := ptr(XML.Element).GetName();
								(* KernelLog.String(str^); KernelLog.Ln; *)
								IF (str # NIL) & (str^ = "guide") THEN				(* guide *)
									str := ptr(XML.Element).GetAttributeValue("type");
									IF (str # NIL) & (str^ = "horizontal") THEN	tempBool := TRUE ELSE tempBool := FALSE; END;
									str := ptr(XML.Element).GetAttributeValue("position"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); page.AddGuide(SHORT(tempReal), tempBool) END;
								ELSIF (str # NIL) & (str^ = "frame") THEN			(* frame *)
									str := ptr(XML.Element).GetAttributeValue("x"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mt := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("y"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mb := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("width"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); ml := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("height"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mr := SHORT(tempReal); END;
									page.AddFrame(mt, mb, ml, mr); frame := page.GetLastFrame();
									str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN frame.SetName(str); END;
									str := ptr(XML.Element).GetAttributeValue("type"); IF str # NIL THEN frame.SetType(str); END;
									str := ptr(XML.Element).GetAttributeValue("textwrap"); IF (str # NIL) & (str^ = "1") THEN frame.SetWrap(TRUE); END;
									str := ptr(XML.Element).GetAttributeValue("twrap-top"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mt := SHORT(tempReal); ELSE mt := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-bottom"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mb := SHORT(tempReal); ELSE mb := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-left");  IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); ml := SHORT(tempReal); ELSE ml := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-right"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mr := SHORT(tempReal); ELSE mr := 0 END;
									frame.SetWrapSize(mt, mb, ml, mr);
									str := ptr(XML.Element).GetAttributeValue("z-index"); IF str # NIL THEN Strings.StrToInt(str^, tempInt); END; (* not yet implemented *)
									str := ptr(XML.Element).GetAttributeValue("frame-content");
									IF str # NIL THEN
										content := built.GetContentByName(str^);
										IF content # NIL THEN
											frame.SetContent(content);
										END;
									END;
								END;
							END;
						END;
						page.currentFrame := NIL;
					ELSIF (str # NIL) & (str^ = "page") THEN						(* page *)
						str := ptr(XML.Element).GetAttributeValue("masterpage");
						built.AddPage(TRUE); page := built.GetLastPage();
						IF str # NIL THEN
							mpage := built.GetMasterByName(str);
							page.masterpage := mpage;
						END;

						pagecont := ptr(XML.Element).GetContents(); pagecont.Reset();
						WHILE pagecont.HasMoreElements() DO
							ptr := pagecont.GetNext();
							IF ptr IS XML.Element THEN
								str := ptr(XML.Element).GetName();
								(* KernelLog.String(str^); KernelLog.Ln; *)
								IF (str # NIL) & (str^ = "guide") THEN				(* guide *)
									str := ptr(XML.Element).GetAttributeValue("type");
									IF (str # NIL) & (str^ = "horizontal") THEN	tempBool := TRUE ELSE tempBool := FALSE; END;
									str := ptr(XML.Element).GetAttributeValue("position"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); page.AddGuide(SHORT(tempReal), tempBool) END;
								ELSIF (str # NIL) & (str^ = "frame") THEN			(* frame *)
									str := ptr(XML.Element).GetAttributeValue("x"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mt := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("y"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mb := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("width"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); ml := SHORT(tempReal); END;
									str := ptr(XML.Element).GetAttributeValue("height"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); mr := SHORT(tempReal); END;
									page.AddFrame(mt, mb, ml, mr); frame := page.GetLastFrame();
									str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN frame.SetName(str); END;
									str := ptr(XML.Element).GetAttributeValue("type"); IF str # NIL THEN frame.SetType(str); END;
									str := ptr(XML.Element).GetAttributeValue("textwrap"); IF (str # NIL) & (str^ = "1") THEN frame.SetWrap(TRUE); END;
									str := ptr(XML.Element).GetAttributeValue("twrap-top"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mt := SHORT(tempReal); ELSE mt := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-bottom"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mb := SHORT(tempReal); ELSE mb := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-left");  IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); ml := SHORT(tempReal); ELSE ml := 0 END;
									str := ptr(XML.Element).GetAttributeValue("twrap-right"); IF (str # NIL) THEN Strings.StrToFloat(str^, tempReal); mr := SHORT(tempReal); ELSE mr := 0 END;
									frame.SetWrapSize(mt, mb, ml, mr);
									str := ptr(XML.Element).GetAttributeValue("z-index"); IF str # NIL THEN Strings.StrToInt(str^, tempInt); END; (* not yet implemented *)
									str := ptr(XML.Element).GetAttributeValue("frame-content");
									IF str # NIL THEN
										content := built.GetContentByName(str^);
										IF content # NIL THEN
											frame.SetContent(content);
										END;
									END;
								END;
							END;
						END;
						page.currentFrame := NIL;
					END;
				END;
			END;

			(* set current to the built Document *)
			SetDocument(built);
			drawPanel.SetDocument(built);
			drawPanel.ZoomFitDoc;
			FirstPageHandler(NIL, NIL);
			UpdatePageNumber;
			drawPanel.Resized;
			drawPanel.ready := TRUE;
			drawPanel.Invalidate;

		END BuildDocFromXML;

		PROCEDURE StoreHandler(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR;
		BEGIN
			filenameEdit.GetAsString(filename);
			(* KernelLog.String("Saving file: "); KernelLog.String(filename); KernelLog.Ln; *)
			Store(filename, fileFormat);
			popup.Close;
		END StoreHandler;

		PROCEDURE Store(CONST filename : ARRAY OF CHAR; format : LONGINT);
		VAR tempString : ARRAY 256 OF CHAR;
			string : Strings.String;
			w : Files.Writer; f : Files.File;
			cStyles : DTPData.CStyles; pStyle : DTPData.ParagraphStyleObject;
			pStyles : DTPData.PStyles; cStyle : DTPData.CharacterStyleObject;
			contents : DTPData.Contents; content : DTPData.ContentObject;
			page : DTPData.PageObject;
			mpage: DTPData.MasterPageObject;
			frame : DTPData.FrameObject;
			guide : DTPData.GuideObject;
			i : LONGINT; style : SET;
		BEGIN
			filenameEdit.SetAsString(filename);

			(* -- Save Style File -- *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Style.XML");
			f := Files.New(tempString); IF f = NIL THEN RETURN END;
			Files.OpenWriter(w, f, 0);
			w.String('<?xml version="1.0" encoding="UTF-8"?>'); w.Ln;
			w.String("<styles>"); w.Ln;

			(* processing character styles *)
			cStyles := currentDocument.cStyles; i := 0;
			WHILE (i<currentDocument.nofCStyles) DO
				cStyle := cStyles[i];
				w.String('<character-style name="'); w.String(cStyle.name);
				w.String('" font-family="'); w.String(cStyle.family);
				w.String('" font-style="'); style := cStyle.style;
				IF (style = {}) THEN
					w.Int(0, 0);
				ELSIF (style = {0}) THEN
					w.Int(1, 0);
				ELSIF (style = {1}) THEN
					w.Int(2, 0);
				ELSIF (style = {0,1}) THEN
					w.Int(3, 0);
				ELSE
					w.Int(0, 0);
				END;
				w.String('" font-size="');	 Strings.FloatToStr(cStyle.size, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" leading="');  Strings.FloatToStr(cStyle.leading, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" baseline-shift="');  Strings.FloatToStr(cStyle.baselineShift, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" color="'); w.Hex(cStyle.color, 8);
				w.String('" bgcolor="');  w.Hex(cStyle.bgColor, 8);
				w.String('" tracking="');  Strings.FloatToStr(cStyle.tracking, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" kerning="');  Strings.FloatToStr(cStyle.kerning, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" h-scale="');  Strings.FloatToStr(cStyle.scaleHorizontal, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" v-scale="');  Strings.FloatToStr(cStyle.scaleVertical, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" />'); w.Ln;
				INC(i);
			END;

			(* processing paragraph styles *)
			pStyles := currentDocument.pStyles; i := 0;
			WHILE (i<currentDocument.nofPStyles) DO
				pStyle := pStyles[i];
				w.String('<paragraph-style name="'); w.String(pStyle.name);
				w.String('" alignment="'); w.Int(pStyle.alignment, 0);
				w.String('" first-indent="'); Strings.FloatToStr(pStyle.firstIndent, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" left-indent="'); Strings.FloatToStr(pStyle.leftIndent, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" right-indent="'); Strings.FloatToStr(pStyle.rightIndent, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" space-before="'); Strings.FloatToStr(pStyle.spaceBefore, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" space-after="'); Strings.FloatToStr(pStyle.spaceAfter, 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
				w.String('" character-style="'); w.String(pStyle.charStyle.name);
				w.String('" />'); w.Ln;
				INC(i);
			END;

			(* do other styles if needed *)

			w.String("</styles>"); w.Ln;
			w.Update; Files.Register(f);

			(* -- Save Content File -- *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Content.XML");
			f := Files.New(tempString); IF f = NIL THEN RETURN END;
			Files.OpenWriter(w, f, 0);
			w.String('<?xml version="1.0" encoding="UTF-8"?>'); w.Ln;
			w.String("<content>"); w.Ln;
			(* processing character styles *)
 			contents := currentDocument.contents; i := 0;
			WHILE (i<currentDocument.nofContents) DO
				content := contents[i];
				w.String('<node name="'); w.String(content.contentName^); w.String('">'); w.Ln;
				(* Call Save in Plugin *)
				content.Store(w);
				w.String("</node>"); w.Ln;
				INC(i);
			END;

			w.String("</content>"); w.Ln;
			w.Update; Files.Register(f);

			(* -- Save Layout File -- *)
			COPY(filename, tempString);
			Strings.Append(tempString, ".Layout.XML");
			f := Files.New(tempString); IF f = NIL THEN RETURN END;
			Files.OpenWriter(w, f, 0);
			w.String('<?xml version="1.0" encoding="UTF-8"?>'); w.Ln;
			w.String('<document page-width="'); Strings.FloatToStr(currentDocument.GetPageWidth(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" page-height="'); Strings.FloatToStr(currentDocument.GetPageHeight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" margin-top="'); Strings.FloatToStr(currentDocument.GetMarginTop(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" margin-bottom="'); Strings.FloatToStr(currentDocument.GetMarginBottom(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" margin-left="'); Strings.FloatToStr(currentDocument.GetMarginLeft(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" margin-right="'); Strings.FloatToStr(currentDocument.GetMarginRight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('" facing-pages="'); Strings.BoolToStr(currentDocument.GetFacingPages(), tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
			w.String('">'); w.Ln;

			(* processing masterpages *)
			page := currentDocument.GetFirstMasterPage();
			(* KernelLog.Int(currentDocument.nofMPages, 0); *)
			WHILE (page # NIL) DO
				w.String('<masterpage name="'); w.String(page(DTPData.MasterPageObject).mpageName^); w.String('">'); w.Ln;
				(* processing guides on masterpage *)
				guide := page.GetFirstGuide();
				WHILE (guide # NIL) DO
					w.String('<guide type="'); IF guide.GetHorizontal() THEN w.String("horizontal"); ELSE w.String("vertical"); END;
					w.String('" position="'); Strings.FloatToStr(guide.GetPosition(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" />'); w.Ln;
					guide := guide.next;
				END;

				(* processing frames on masterpage *)
				frame := page.GetFirstFrame(); i := 0;
				WHILE (frame # NIL) DO
					w.String('<frame name="'); string := frame.GetName(); w.String(string^);
					w.String('" type="'); string := frame.GetType(); w.String(string^);
					w.String('" x="'); Strings.FloatToStr(frame.GetX(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" y="'); Strings.FloatToStr(frame.GetY(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" width="'); Strings.FloatToStr(frame.GetWidth(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" height="'); Strings.FloatToStr(frame.GetHeight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" frame-content="'); content := frame.GetContent(); IF content # NIL THEN w.String(content.contentName^); ELSE w.String("none"); END;
					w.String('" textwrap="'); IF frame.GetWrap() THEN w.String("1") ELSE w.String("0"); END;
					w.String('" twrap-top="'); Strings.FloatToStr(frame.GetWrapTop(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-bottom="'); Strings.FloatToStr(frame.GetWrapBottom(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-left="'); Strings.FloatToStr(frame.GetWrapLeft(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-right="'); Strings.FloatToStr(frame.GetWrapRight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" z-index="'); w.Int(i, 0);
					w.String('" />'); w.Ln;
					frame := frame.next;
					INC(i);
				END;

				page := page(DTPData.MasterPageObject).next; w.String("</masterpage>"); w.Ln;
			END;

			(* processing pages *)
			page := currentDocument.GetFirstPage();
			WHILE (page # NIL) DO
				w.String('<page masterpage="'); mpage := page.masterpage;
				IF (mpage # NIL) THEN w.String(mpage.mpageName^); ELSE w.String("none"); END;
				w.String('">'); w.Ln;
				(* processing guides on masterpage *)
				guide := page.GetFirstGuide();
				WHILE (guide # NIL) DO
					w.String('<guide type="'); IF guide.GetHorizontal() THEN w.String("horizontal"); ELSE w.String("vertical"); END;
					w.String('" position="'); Strings.FloatToStr(guide.GetPosition(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" />'); w.Ln;
					guide := guide.next;
				END;

				(* processing frames on masterpage *)
				frame := page.GetFirstFrame(); i := 0;
				WHILE (frame # NIL) DO
					w.String('<frame name="'); string := frame.GetName(); w.String(string^);
					w.String('" type="'); string := frame.GetType(); w.String(string^);
					w.String('" x="'); Strings.FloatToStr(frame.GetX(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" y="'); Strings.FloatToStr(frame.GetY(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" width="'); Strings.FloatToStr(frame.GetWidth(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" height="'); Strings.FloatToStr(frame.GetHeight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" frame-content="'); content := frame.GetContent(); IF content # NIL THEN w.String(content.contentName^); ELSE w.String("none"); END;
					w.String('" textwrap="'); IF frame.GetWrap() THEN w.String("1") ELSE w.String("0"); END;
					w.String('" twrap-top="'); Strings.FloatToStr(frame.GetWrapTop(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-bottom="'); Strings.FloatToStr(frame.GetWrapBottom(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-left="'); Strings.FloatToStr(frame.GetWrapLeft(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" twrap-right="'); Strings.FloatToStr(frame.GetWrapRight(), 0,4,0, tempString); Strings.TrimLeft(tempString, " "); w.String(tempString);
					w.String('" z-index="'); w.Int(i, 0);
					w.String('" />'); w.Ln;
					frame := frame.next;
					INC(i);
				END;

				page := page.next; w.String("</page>"); w.Ln;
			END;

			w.String("</document>"); w.Ln;
			w.Update; Files.Register(f);

			modified := FALSE;
		END Store;

		PROCEDURE ExportHandler(sender, data: ANY);
		VAR expFileName: ARRAY 256 OF CHAR;
			pixelPerMM : REAL;
			renderCanvas: WMGraphics.BufferCanvas;
			renderImg: Raster.Image;
			res: LONGINT;
			oldDocOriginX, oldDocOriginY : LONGINT;
			oldZoomFactor: REAL;
			oldZoomMode: LONGINT;
			tempString: ARRAY 256 OF CHAR;
			tempReal: LONGREAL;
			wait: PleaseWaitWindow;
		BEGIN
			popup.Close;
			IF (currentDocument # NIL) THEN
				expFileName := "export.bmp";
				pixelPerMM := 5;
				IF WMDialogs.QueryString("Export as Image:", expFileName) = WMDialogs.ResOk THEN
					Strings.FloatToStr(pixelPerMM, 0,4,0, tempString);
					IF WMDialogs.QueryString("Export Image Resolution [pixel/mm]:", tempString) = WMDialogs.ResOk THEN
						Strings.StrToFloat(tempString, tempReal); pixelPerMM := SHORT(tempReal);
						NEW(wait); wait.SetColor(LONGINT(09999FFFFH)); wait.SetMessage("Rendering Image - please wait!");
						wait.Show;
						drawPanel.Render(TRUE);
						IF ~previewON THEN									(* change to preview *)
							drawPanel.SetPreviewMode(TRUE);
						END;
						oldDocOriginX := drawPanel.GetOriginX();				(* store old values *)
						oldDocOriginY := drawPanel.GetOriginY();
						oldZoomFactor := drawPanel.GetZoomFactor();
						oldZoomMode := drawPanel.zoomMode;
						drawPanel.SetZoomUser(pixelPerMM);					(* change values *)
						drawPanel.SetZoomFactor(pixelPerMM);
						drawPanel.SetRenderZoomMode(5);
						drawPanel.SetOrigin(0, 0);
						NEW(renderImg);
						Raster.Create(renderImg, ENTIER(currentDocument.GetPageWidth()*pixelPerMM), ENTIER(currentDocument.GetPageHeight()*pixelPerMM), Raster.BGRA8888);
						NEW(renderCanvas, renderImg);
						drawPanel.DrawDocument(renderCanvas);				(* document paper *)
						drawPanel.DrawContent(renderCanvas);					(* content objects (frames)(grid..) *)
						(* Raster.Store(renderImg, expFileName, res); *)
						WMGraphics.StoreImage(renderImg, expFileName, res);
						drawPanel.SetOrigin(oldDocOriginX, oldDocOriginY);	(* restore stored values *)
						drawPanel.SetZoomFactor(oldZoomFactor);
						drawPanel.SetZoomUser(oldZoomFactor);
						drawPanel.SetRenderZoomMode(oldZoomMode);
						(* drawPanel.Resized; *)
						IF ~previewON THEN									(* change to edit *)
							drawPanel.SetPreviewMode(FALSE);
						END;
						IF res # -1 THEN
							KernelLog.String("DTPEditor: Page exported as Image"); KernelLog.Ln;
						END;
						drawPanel.Render(FALSE);
						wait.Hide;
						drawPanel.Invalidate;
					END;
				END;
			END;
		END ExportHandler;

		PROCEDURE NewHandler(sender, data : ANY);
		BEGIN
			CreateNew;
			modified := FALSE;
		END NewHandler;

		PROCEDURE CreateNew;
		BEGIN
			IF ~nDiagOpen THEN
				nDiagOpen := TRUE;
				NEW(nDialog, SELF);
				nDialog.Show;
			END;
		END CreateNew;

		PROCEDURE CreateDoc(w, h, mt, mb, ml, mr : REAL; fp : BOOLEAN);
		VAR document : DTPData.Document;
		BEGIN

			NEW(document, w, h, mt, mb, ml, mr, fp);
			currentDocument := document;
			(* add a page and masterpage on that document *)
			currentDocument.AddPage(FALSE);
			currentDocument.AddMasterPage(FALSE);
			drawPanel.SetDocument(currentDocument);
			LoadCharacterStyle(document.GetCharacterStyleByName("defaultCharacterStyle"));
			LoadParagraphStyle(document.GetParagraphStyleByName("defaultParagraphStyle"));

			UpdatePageNumber;
			drawPanel.ready := TRUE;
			drawPanel.Invalidate;

		END CreateDoc;

		PROCEDURE ObjectCutHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				cguide := cpage.GetCurrentGuide();
				IF cframe # NIL THEN						(* clone frame (to buffer) and remove current *)
					DTPData.dollyFrame := cframe.Clone();
					currentDocument.dollyGuide := NIL;
					cpage.DeleteFrame();
				ELSIF cguide # NIL THEN						(* clone guide (to buffer) and remove current *)
					currentDocument.dollyGuide := cguide.Clone();
					DTPData.dollyFrame := NIL;
					cpage.DeleteGuide();
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END ObjectCutHandler;

		PROCEDURE ObjectCopyHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				cguide := cpage.GetCurrentGuide();
				IF cframe # NIL THEN						(* clone frame to buffer *)
					DTPData.dollyFrame := cframe.Clone();
					currentDocument.dollyGuide := NIL;
				ELSIF cguide # NIL THEN						(* clone guide to buffer *)
					currentDocument.dollyGuide := cguide.Clone();
					DTPData.dollyFrame := NIL;
				END;
			END;
			popup.Close;
		END ObjectCopyHandler;

		PROCEDURE ObjectPasteHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)			newFrame: DTPData.FrameObject;
			newContent: DTPData.ContentObject;
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := DTPData.dollyFrame;
				cguide := currentDocument.dollyGuide;
				IF cframe # NIL THEN						(* paste frame from buffer *)
					newFrame := cframe.Clone();
					newContent := newFrame.GetContent();
					newContent.redrawProc := drawPanel.InvalidateCurrentFrame;
					newContent.updatePropsPosition := drawPanel.SetContentPropsPosition;
					newContent.Resize(drawPanel.GetZoomFactor());
					newContent.SetSize(ENTIER(newFrame.GetWidth()*drawPanel.GetZoomFactor()), ENTIER(newFrame.GetHeight()*drawPanel.GetZoomFactor()));
					cpage.InsertFrame(newFrame);
				ELSIF cguide # NIL THEN						(* paste guide from buffer *)
					cpage.AddGuide(cguide.GetPosition(), cguide.GetHorizontal());
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END ObjectPasteHandler;

		PROCEDURE ObjectDeleteHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
			cguide: DTPData.GuideObject;
*)			ccontent: DTPData.ContentObject;
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				cguide := cpage.GetCurrentGuide();
				IF cframe # NIL THEN						(* delete current frame *)
					ccontent := cframe.GetContent();
					ccontent.OnDelete;
					cpage.DeleteFrame;
				ELSIF cguide # NIL THEN						(* delete currend guide *)
					cpage.DeleteGuide;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END ObjectDeleteHandler;

		PROCEDURE ObjectToFrontHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe # NIL THEN
					cpage.Move2Front;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			SetActive;
		END ObjectToFrontHandler;

		PROCEDURE ObjectFrontStepHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe # NIL THEN
					cpage.Move2FrontStep;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			SetActive;
		END ObjectFrontStepHandler;

		PROCEDURE ObjectToBackHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe # NIL THEN
					cpage.Move2Back;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			SetActive;
		END ObjectToBackHandler;

		PROCEDURE ObjectBackStepHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe # NIL THEN
					cpage.Move2BackStep;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			SetActive;
		END ObjectBackStepHandler;

		PROCEDURE ObjectPrevHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe = NIL THEN
					cframe := cpage.GetLastFrame();
					cpage.SetCurrentFrame(cframe);
				ELSE
					cpage.PrevFrame;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END ObjectPrevHandler;

		PROCEDURE ObjectNextHandler(sender, data: ANY);
		VAR
(*			cpage: DTPData.PageObject;
			cframe: DTPData.FrameObject;
*)		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				cframe := cpage.GetCurrentFrame();
				IF cframe = NIL THEN
					cframe := cpage.GetFirstFrame();
					cpage.SetCurrentFrame(cframe);
				ELSE
					cpage.NextFrame;
				END;
			END;
			popup.Close;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END ObjectNextHandler;

		PROCEDURE AddBeforePageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.AddMasterPage(FALSE);
				ELSE
					currentDocument.AddPage(FALSE);
				END;
			END;
			popup.Close;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END AddBeforePageHandler;

		PROCEDURE AddAfterPageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.AddMasterPage(TRUE);
				ELSE
					currentDocument.AddPage(TRUE);
				END;
			END;
			popup.Close;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END AddAfterPageHandler;

		PROCEDURE DeletePageHandler(sender, data: ANY);
		VAR
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.DeleteMasterPage;
				ELSE
					currentDocument.DeletePage;
				END;
			END;
			popup.Close;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END DeletePageHandler;

		PROCEDURE NextPageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.NextMasterPage;
				ELSE
					currentDocument.NextPage;
				END;
			END;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			drawPanel.Resized;
		END NextPageHandler;

		PROCEDURE PrevPageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.PrevMasterPage;
				ELSE
					currentDocument.PrevPage;
				END;
			END;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			drawPanel.Resized;
		END PrevPageHandler;

		PROCEDURE LastPageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.LastMasterPage;
				ELSE
					currentDocument.LastPage;
				END;
			END;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			drawPanel.Resized;
		END LastPageHandler;

		PROCEDURE FirstPageHandler(sender, data: ANY);
		BEGIN
			IF currentDocument # NIL THEN
				IF masterON THEN
					currentDocument.FirstMasterPage;
				ELSE
					currentDocument.FirstPage;
				END;
			END;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
			drawPanel.Resized;
		END FirstPageHandler;

		PROCEDURE GoToPageHandler(sender, data: ANY);
		VAR gotoPage: ARRAY 8 OF CHAR;
			gPage, i: LONGINT;
		BEGIN
			IF currentDocument # NIL THEN
				pageNumber.GetAsString(gotoPage);
				Strings.StrToInt(gotoPage, gPage);
				IF masterON THEN
					IF gPage > currentDocument.nofMPages THEN
						gPage := currentDocument.nofMPages;
					ELSIF gPage < 1 THEN
						gPage := 1;
					END;
					currentDocument.FirstMasterPage; i := 0;
					WHILE i < gPage DO
						currentDocument.NextMasterPage;
						INC(i);
					END;
				ELSE
					IF gPage > currentDocument.nofPages THEN
						gPage := currentDocument.nofPages;
					ELSIF gPage < 1 THEN
						gPage := 1;
					END;
					currentDocument.FirstPage; i := 0;
					WHILE i < gPage DO
						currentDocument.NextPage;
						INC(i);
					END;
				END;
			END;
			UpdatePageNumber;
			drawPanel.Invalidate;
			drawPanel.UpdateProps;
			drawPanel.UpdateContentProps;
		END GoToPageHandler;

		PROCEDURE UpdatePageNumber;
		VAR pageNumberString : ARRAY 8 OF CHAR;
			masterNumberString : Strings.String;
			mpage : DTPData.MasterPageObject;
		BEGIN
			IF masterON THEN
				Strings.IntToStr(currentDocument.GetCurrentMasterPageNumber(), pageNumberString);
				mpage := currentDocument.GetCurrentMasterPage();
				masterNumberString := mpage.GetName();
			ELSE
				Strings.IntToStr(currentDocument.GetCurrentPageNumber(), pageNumberString);
				cpage := currentDocument.GetCurrentPage();
				mpage := cpage.GetMasterPage();
				IF mpage # NIL THEN
					masterNumberString := mpage.GetName();
				ELSE
					masterNumberString := Strings.NewString("none");
				END;
			END;
			pageNumber.SetAsString(pageNumberString);
			masterNumber.SetAsString(masterNumberString^);
		END UpdatePageNumber;

		PROCEDURE MiscStyleEditorHandler(sender, data: ANY);
		BEGIN
			NEW(styleEditor);
			styleEditor.UpdateProc := TextPropUpdateHandler;
			styleEditor.LoadStyleList(currentDocument);
			styleEditor.Show(200, 150);
			popup.Close;
		END MiscStyleEditorHandler;

		PROCEDURE TextPropUpdateHandler*;
		VAR cpage : DTPData.PageObject;
			cframe : DTPData.FrameObject;
			ccontent: DTPData.ContentObject;
		BEGIN
			IF currentDocument # NIL THEN
				IF drawPanel.mpageMode THEN
					cpage := currentDocument.GetCurrentMasterPage();
				ELSE
					cpage := currentDocument.GetCurrentPage();
				END;
				IF cpage # NIL THEN
					cframe := cpage.GetCurrentFrame();
					IF cframe # NIL THEN
						ccontent := cframe.GetContent();
						IF ccontent # NIL THEN
							ccontent.Hide; ccontent.Show(drawPanel.propsX, drawPanel.propsY);
						END;
					END;
				END;
				drawPanel.Resized;
			END;
		END TextPropUpdateHandler;

		PROCEDURE PropsHandler(sender, data: ANY);
		VAR
		BEGIN
			(* NEW(props, SELF); *)
			IF ~drawPanel.propertyOpen THEN
				drawPanel.props.Show;
				drawPanel.propertyOpen := TRUE;
				popup.Close;
			END;
		END PropsHandler;

(*
		PROCEDURE RefreshPlugins();
		BEGIN
			LoadPlugins;
			pluginPanel := AddPlugins();
			pluginPanel.visible.Set(TRUE);
			(* sideToolbar.AddContent(pluginPanel); *)
			sideToolbar.Invalidate;
		END RefreshPlugins;

		PROCEDURE PlugHandler(sender, data: ANY);
		BEGIN
			RefreshPlugins;
			popup.Close;
		END PlugHandler;
*)
		PROCEDURE SetMasterHandler(sender, data: ANY);
		VAR master: DTPData.MasterPageObject;
			mastername: ARRAY 16 OF CHAR;
		BEGIN
			masterNumber.GetAsString(mastername);
			IF masterON THEN											(* set name for Masterpage *)
				master := currentDocument.GetCurrentMasterPage();
				master.SetName(Strings.NewString(mastername));
			ELSE														(* set masterpage for current doc page *)
				master := currentDocument.GetMasterByName(Strings.NewString(mastername));
				cpage := currentDocument.GetCurrentPage();
				cpage.SetMasterPage(master);
				drawPanel.Invalidate;
			END;
			UpdatePageNumber;
		END SetMasterHandler;

		PROCEDURE Close;
		BEGIN
			Close^;
			drawPanel.CloseContentProps;
			IF styleEditor # NIL THEN styleEditor.Hide; END;
			IF drawPanel.propertyOpen THEN drawPanel.props.Close END;
			IF nDiagOpen THEN nDialog.Cancel(SELF, NIL) END;
			DecCount
		END Close;

	END Window;

	NewDialog* = OBJECT(WMComponents.FormWindow)
	VAR content : WMComponents.VisualComponent;
		result : LONGINT;
		dhe, dwe, dmte, dmbe, dmle, dmre, dfpe : WMEditors.Editor;
		dhs, dws, dmts, dmbs, dmls, dmrs, dfps : ARRAY 256 OF CHAR;
		dhr, dwr, dmtr, dmbr, dmlr, dmrr, dfpr : LONGREAL;
		fpCheck: DTPUtilities.Checkbox;
		facep : BOOLEAN;
		theCaller : Window;

		PROCEDURE &New*(caller : Window);
		BEGIN
			theCaller := caller;
			manager := WMWindowManager.GetDefaultManager();
			CreateNewDialog;
			Init(content.bounds.GetWidth(), content.bounds.GetHeight(), FALSE);
			SetContent(content);
			SetTitle(Strings.NewString("New Document"));

		END New;

		PROCEDURE CreateNewDialog;
		VAR
			(* NewDialog Stuff *)
			(* newDialog : WMComponents.FormWindow; *)
			panel, buttonPanel, paramPanel : WMStandardComponents.Panel;
			cancel, ok : WMStandardComponents.Button;
			labelPanel, editorsPanel : WMStandardComponents.Panel;
		 	dh, dw, dmt, dmb, dml, dmr, dfp : WMStandardComponents.Label;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;
		BEGIN
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel); panel.bounds.SetExtents(300, 200); panel.fillColor.Set(panelColor);
			panel.takesFocus.Set(TRUE);

			NEW(buttonPanel); buttonPanel.bounds.SetHeight(40); buttonPanel.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(buttonPanel);

			NEW(ok); ok.caption.SetAOC("OK"); ok.alignment.Set(WMComponents.AlignRight);
			buttonPanel.AddContent(ok);
			(* add button handler *)
			ok.onClick.Add(Ok);

			NEW(cancel); cancel.caption.SetAOC("Cancel"); cancel.alignment.Set(WMComponents.AlignRight);
			buttonPanel.AddContent(cancel);
			cancel.onClick.Add(Cancel);

			NEW(paramPanel); paramPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(paramPanel);

			NEW(editorsPanel); editorsPanel.bounds.SetWidth(100); editorsPanel.alignment.Set(WMComponents.AlignRight);
			paramPanel.AddContent(editorsPanel);

			NEW(labelPanel); labelPanel.alignment.Set(WMComponents.AlignClient);
			paramPanel.AddContent(labelPanel);

			NEW(dw); dw.bounds.SetHeight(20); dw.alignment.Set(WMComponents.AlignTop); dw.SetCaption(" Document Width [mm]:");
			labelPanel.AddContent(dw);

			NEW(dwe); dwe.bounds.SetHeight(20); dwe.alignment.Set(WMComponents.AlignTop);
			dwe.tv.showBorder.Set(TRUE); dwe.multiLine.Set(FALSE); dwe.fillColor.Set(0FFFFFFFFH);
			dwe.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dwe); dwe.onEnter.Add(FocusNextField);

			NEW(dh); dh.bounds.SetHeight(20); dh.alignment.Set(WMComponents.AlignTop); dh.SetCaption(" Document Height [mm]:");
			labelPanel.AddContent(dh);

			NEW(dhe); dhe.bounds.SetHeight(20); dhe.alignment.Set(WMComponents.AlignTop);
			dhe.tv.showBorder.Set(TRUE); dhe.multiLine.Set(FALSE); dhe.fillColor.Set(0FFFFFFFFH);
			dhe.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dhe); dhe.onEnter.Add(FocusNextField);

			NEW(dmt); dmt.bounds.SetHeight(20); dmt.alignment.Set(WMComponents.AlignTop); dmt.SetCaption(" Document Margin Top [mm]:");
			labelPanel.AddContent(dmt);

			NEW(dmte); dmte.bounds.SetHeight(20); dmte.alignment.Set(WMComponents.AlignTop);
			dmte.tv.showBorder.Set(TRUE); dmte.multiLine.Set(FALSE); dmte.fillColor.Set(0FFFFFFFFH);
			dmte.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dmte);	dmte.onEnter.Add(FocusNextField);

			NEW(dmb); dmb.bounds.SetHeight(20); dmb.alignment.Set(WMComponents.AlignTop); dmb.SetCaption(" Document Margin Bottom [mm]:");
			labelPanel.AddContent(dmb);

			NEW(dmbe); dmbe.bounds.SetHeight(20); dmbe.alignment.Set(WMComponents.AlignTop);
			dmbe.tv.showBorder.Set(TRUE); dmbe.multiLine.Set(FALSE); dmbe.fillColor.Set(0FFFFFFFFH);
			dmbe.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dmbe); dmbe.onEnter.Add(FocusNextField);

			NEW(dml); dml.bounds.SetHeight(20); dml.alignment.Set(WMComponents.AlignTop); dml.SetCaption(" Document Margin Left [mm]:");
			labelPanel.AddContent(dml);

			NEW(dmle); dmle.bounds.SetHeight(20); dmle.alignment.Set(WMComponents.AlignTop);
			dmle.tv.showBorder.Set(TRUE); dmle.multiLine.Set(FALSE); dmle.fillColor.Set(0FFFFFFFFH);
			dmle.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dmle); dmle.onEnter.Add(FocusNextField);

			NEW(dmr); dmr.bounds.SetHeight(20); dmr.alignment.Set(WMComponents.AlignTop); dmr.SetCaption(" Document Margin Right [mm]:");
			labelPanel.AddContent(dmr);

			NEW(dmre); dmre.bounds.SetHeight(20); dmre.alignment.Set(WMComponents.AlignTop);
			dmre.tv.showBorder.Set(TRUE); dmre.multiLine.Set(FALSE); dmre.fillColor.Set(0FFFFFFFFH);
			dmre.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editorsPanel.AddContent(dmre); dmre.onEnter.Add(FocusNextField);

			NEW(dfp); dfp.bounds.SetHeight(20); dfp.alignment.Set(WMComponents.AlignTop); dfp.SetCaption(" Facing Pages:");
			labelPanel.AddContent(dfp);

			NEW(dfpe); dfpe.bounds.SetHeight(20); dfpe.alignment.Set(WMComponents.AlignTop);
			dfpe.tv.showBorder.Set(TRUE); dfpe.multiLine.Set(FALSE); dfpe.fillColor.Set(0FFFFFFFFH);
			dfpe.tv.textAlignV.Set(WMGraphics.AlignCenter);
			(* editorsPanel.AddContent(dfpe); *)  dfpe.onEnter.Add(FocusNextField);

			NEW(fpCheck); fpCheck.bounds.SetHeight(20); fpCheck.alignment.Set(WMComponents.AlignTop);
			editorsPanel.AddContent(fpCheck); fpCheck.leftBorder := 0;

			content := panel;

		END CreateNewDialog;

		PROCEDURE FocusNextField(sender, data: ANY);
		BEGIN
			IF (sender = dwe) THEN
				dhe.tv.SetFocus;
			ELSIF (sender = dhe) THEN
				dmte.tv.SetFocus;
			ELSIF (sender = dmte) THEN
				dmbe.tv.SetFocus;
			ELSIF (sender = dmbe) THEN
				dmle.tv.SetFocus;
			ELSIF (sender = dmle) THEN
				dmre.tv.SetFocus;
			ELSIF (sender = dmre) THEN
				dwe.tv.SetFocus;
			ELSIF (sender = dfpe) THEN
				dwe.tv.SetFocus;
			END;
		END FocusNextField;

		PROCEDURE Show*;
		BEGIN
			result := -1;
			InitFieldValues;
			WMWindowManager.ExtAddWindow(SELF, 300, 200,
				{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			manager.SetFocus(SELF);
			dwe.tv.SetFocus;
			BEGIN {EXCLUSIVE}
				AWAIT (result >= 0)
			END;
			manager.Remove(SELF);
			IF result = 0 THEN (* OK pressed, fill in values *)
				dhe.GetAsString(dhs);
				dwe.GetAsString(dws);
				dmte.GetAsString(dmts);
				dmbe.GetAsString(dmbs);
				dmle.GetAsString(dmls);
				dmre.GetAsString(dmrs);
				dfpe.GetAsString(dfps);
				Strings.StrToFloat(dhs, dhr);
				Strings.StrToFloat(dws, dwr);
				Strings.StrToFloat(dmts, dmtr);
				Strings.StrToFloat(dmbs, dmbr);
				Strings.StrToFloat(dmls, dmlr);
				Strings.StrToFloat(dmrs, dmrr);
				Strings.StrToFloat(dfps, dfpr);
				(* IF dfpr = 0 THEN facep := FALSE ELSE facep := TRUE END; *)
				IF fpCheck.checked THEN facep:= TRUE ELSE facep:= FALSE END;
				theCaller.CreateDoc(SHORT(dwr), SHORT(dhr), SHORT(dmtr), SHORT(dmbr), SHORT(dmlr), SHORT(dmrr), facep);
				(* force redraw *)
				theCaller.drawPanel.Invalidate;

			END;
		END Show;

		PROCEDURE InitFieldValues;
		VAR doc : DTPData.Document;
			fieldContent : ARRAY 8 OF CHAR;
		BEGIN
			IF theCaller.currentDocument = NIL THEN			(* no document open yet *)
				dwe.SetAsString("210");
				dhe.SetAsString("297");
				dmte.SetAsString("12");
				dmbe.SetAsString("12");
				dmle.SetAsString("12");
				dmre.SetAsString("12");
				dfpe.SetAsString("0");
			ELSE
				doc := theCaller.currentDocument;
				Strings.FloatToStr(doc.GetPageWidth(), 0,4,0, fieldContent);
				dwe.SetAsString(fieldContent);
				Strings.FloatToStr(doc.GetPageHeight(), 0,4,0, fieldContent);
				dhe.SetAsString(fieldContent);
				Strings.FloatToStr(doc.GetMarginTop(), 0,4,0, fieldContent);
				dmte.SetAsString(fieldContent);
				Strings.FloatToStr(doc.GetMarginBottom(), 0,4,0, fieldContent);
				dmbe.SetAsString(fieldContent);
				Strings.FloatToStr(doc.GetMarginLeft(), 0,4,0, fieldContent);
				dmle.SetAsString(fieldContent);
				Strings.FloatToStr(doc.GetMarginRight(), 0,4,0, fieldContent);
				dmre.SetAsString(fieldContent);
				IF doc.GetFacingPages() THEN fieldContent := "1" ELSE fieldContent := "0" END;
				dfpe.SetAsString(fieldContent);
			END;
		END InitFieldValues;

		PROCEDURE Ok(sender, data : ANY);
		BEGIN {EXCLUSIVE}
			result := 0;
			theCaller.nDiagOpen := FALSE;
		END Ok;

		PROCEDURE Cancel(sender, data : ANY);
		BEGIN {EXCLUSIVE}
			result := 1;
			theCaller.nDiagOpen := FALSE;
		END Cancel;

	END NewDialog;

	PleaseWaitWindow* = OBJECT(WMComponents.FormWindow)
	VAR
		label : WMStandardComponents.Label;
		status: WMStandardComponents.Label;
		spacer: WMStandardComponents.Panel;
		panel : WMStandardComponents.Panel;
		container: WMStandardComponents.Panel;
		button*: WMStandardComponents.Button;
		mode: LONGINT;						(* 0 = Text/Status only *)
												(* 1 = Animated Bar *)
												(* 2 = Status Bar *)
		shown : BOOLEAN;
		x, y : LONGINT;
		progress : LONGINT;
		(* abortProc: PROCEDURE {DELEGATE} ;	*)

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(350, 150);

			NEW(spacer); spacer.alignment.Set(WMComponents.AlignTop);
			spacer.bounds.SetHeight(40);
 			panel.AddContent(spacer);

			NEW(label); label.alignment.Set(WMComponents.AlignTop);
			label.bounds.SetHeight(20);
			label.alignH.Set(1); label.alignV.Set(1);
			label.caption.SetAOC("");
			panel.AddContent(label);

			NEW(spacer); spacer.alignment.Set(WMComponents.AlignBottom);
			spacer.bounds.SetHeight(20);
			panel.AddContent(spacer);

			NEW(container); container.alignment.Set(WMComponents.AlignBottom);
			container.bounds.SetHeight(20);
			NEW(spacer); spacer.alignment.Set(WMComponents.AlignLeft);
			spacer.bounds.SetWidth(110);
			container.AddContent(spacer);
			NEW(spacer); spacer.alignment.Set(WMComponents.AlignRight);
			spacer.bounds.SetWidth(110);
			container.AddContent(spacer);
			NEW(button); button.caption.SetAOC("Cancel"); button.alignment.Set(WMComponents.AlignClient);
			container.AddContent(button);
			panel.AddContent(container);

			NEW(spacer); spacer.alignment.Set(WMComponents.AlignBottom);
			spacer.bounds.SetHeight(25);
 			panel.AddContent(spacer);

			NEW(status); status.alignment.Set(WMComponents.AlignBottom);
			status.bounds.SetHeight(20);
			status.alignH.Set(1); status.alignV.Set(1);
			status.caption.SetAOC("");
			panel.AddContent(status);

			RETURN panel;
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			mode := 0;
			progress := 0;
			x := 300; y := 200; shown := FALSE;
			vc := CreateForm();
			button.visible.Set(FALSE);
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString(""));
		END New;

		PROCEDURE SetMessage(CONST msg: ARRAY OF CHAR);
		BEGIN
			label.caption.SetAOC(msg);
			panel.Invalidate;
		END SetMessage;

(*
		PROCEDURE SetStatus(msg: ARRAY OF CHAR);
		BEGIN
			status.caption.SetAOC(msg);
			panel.Invalidate;
		END SetStatus;

		PROCEDURE SetProgress(progress: LONGINT);
		BEGIN
			SELF.progress := progress;
		END SetProgress;

		PROCEDURE AbortHandler(sender, data: ANY);
		BEGIN
			IF abortProc # NIL THEN abortProc; END;
		END AbortHandler;
*)

		PROCEDURE SetColor(color: LONGINT);
		BEGIN
			panel.fillColor.Set(color);
			label.fillColor.Set(color);
			status.fillColor.Set(color);
		END SetColor;

		PROCEDURE Show*;
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				manager := WMWindowManager.GetDefaultManager();
				WMWindowManager.ExtAddWindow(SELF, x, y,
					{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF); shown := FALSE;
		END Hide;

	BEGIN {ACTIVE}
		IF shown THEN

		END;
	END PleaseWaitWindow;

(*
	AnimBar = OBJECT(WMComponents.VisualComponent)

		PROCEDURE Draw(canvas: WMGraphics.Canvas);
		BEGIN

		END Draw;

	END AnimBar;

	StatusBar = OBJECT(WMComponents.VisualComponent)

	END StatusBar;
*)
	(* --- Plugin Registry ----------------------------------- *)

	PluginListEntry = OBJECT
	VAR pname: ARRAY 16 OF CHAR;
		next: PluginListEntry;
	END PluginListEntry;

	PluginList = OBJECT
	VAR first: PluginListEntry;

		PROCEDURE &Init*;
		BEGIN
			first := NIL;
		END Init;

		PROCEDURE Add(CONST name: ARRAY OF CHAR);
		VAR nEntry : PluginListEntry;
		BEGIN
			NEW(nEntry); COPY(name, nEntry.pname); nEntry.next := first; first := nEntry;
		END Add;

		PROCEDURE Remove(CONST name: ARRAY OF CHAR);
		VAR nEntry, oldEntry: PluginListEntry;
		BEGIN
			nEntry := first; oldEntry := NIL;
			WHILE (nEntry # NIL) DO
				IF (nEntry.pname = name) THEN 						(* remove *)
					IF oldEntry = NIL THEN							(* remove first *)
						first := nEntry.next;
					ELSE											(* remove other *)
						oldEntry.next := nEntry.next;
					END;
				END;
				oldEntry := nEntry;
				nEntry := nEntry.next;
			END;
		END Remove;

	END PluginList;

	PluginEntry = OBJECT
	VAR
		generator: DTPData.ContentFactory;
		generatorName: Modules.Name;
	END PluginEntry;

	PluginRegistry* = OBJECT
	VAR generators: XMLObjects.Dictionary;
		plugList: PluginList;

		PROCEDURE &Init*;
		VAR arrDict: XMLObjects.ArrayDict;
		BEGIN
			NEW(arrDict); generators := arrDict;
			NEW(plugList);
		END Init;

		PROCEDURE RegisterPlugin*(CONST name: ARRAY OF CHAR; generator: DTPData.ContentFactory);
		VAR pe: PluginEntry; pp: ANY;
		BEGIN
			IF generator # Unassigned THEN
				pp := generators.Get(name);
				IF pp = NIL THEN
					NEW(pe); pe.generator := generator;
					generators.Add(name, pe);
					plugList.Add(name);
				ELSE
					pp(PluginEntry).generator := generator;				(* redefinition *)
				END;
				KernelLog.String("DTPEditor Plugin registered: "); KernelLog.String(name); KernelLog.Ln;
			END;
		END RegisterPlugin;

		PROCEDURE RegisterPluginByName*(CONST name: ARRAY OF CHAR; CONST generatorName: Modules.Name);
		VAR pe: PluginEntry; pp: ANY;
		BEGIN
			IF generatorName # "" THEN
				pp := generators.Get(name);
				IF pp = NIL THEN
					NEW(pe); pe.generatorName := generatorName;
					generators.Add(name, pe);
					plugList.Add(name);
				ELSE
					pe(PluginEntry).generatorName := generatorName;	(* redefinition *)
				END;
				KernelLog.String("DTPEditor Plugin registered: "); KernelLog.String(name); KernelLog.Ln;
			END;
		END RegisterPluginByName;

		PROCEDURE UnregisterPlugin*(CONST name: ARRAY OF CHAR);
		BEGIN
			generators.Remove(name);
			plugList.Remove(name);
		END UnregisterPlugin;

		PROCEDURE InstantiatePlugin*(CONST name: ARRAY OF CHAR): DTPData.ContentObject;
		VAR
			contentObject : DTPData.ContentObject; gen: DTPData.ContentFactory;
			moduleName, procedureName : Modules.Name; msg : ARRAY 16 OF CHAR; res : LONGINT;
			pp : ANY;
		BEGIN
			contentObject := NIL;
			pp := generators.Get(name);
			IF pp # NIL THEN
				IF pp(PluginEntry).generator # NIL THEN
					contentObject := pp(PluginEntry).generator();
				ELSE
					Commands.Split(pp(PluginEntry).generatorName, moduleName, procedureName, res, msg);
					IF (res = Commands.Ok) THEN
						GETPROCEDURE(moduleName, procedureName, gen);
						IF gen # NIL THEN
							contentObject := gen();
						END;
					END;
				END;
			END;
			RETURN contentObject;
		END InstantiatePlugin;

		PROCEDURE GetNumberOfPlugins*(): LONGINT;
		BEGIN
			RETURN generators.GetNumberOfElements();
		END GetNumberOfPlugins;

		PROCEDURE GetPluginList*(): PluginList;
		BEGIN
			RETURN plugList;
		END GetPluginList;

		PROCEDURE GetPlugins*(): XMLObjects.Enumerator;
		BEGIN
			RETURN generators.GetEnumerator();
		END GetPlugins;

	END PluginRegistry;

(*	MasterPages = POINTER TO ARRAY OF MasterPageObject;
	ContentPages = POINTER TO ARRAY OF PageObject;

	Styles = POINTER TO ARRAY OF StyleObject;
	Contents = POINTER TO ARRAY OF DTPFrame.ContentObject;
*)

VAR
	nofWindows : LONGINT;
	plugRegistry*: PluginRegistry;
	Unassigned: DTPData.ContentFactory;

(*
PROCEDURE Min(a, b: REAL): REAL;
BEGIN
	IF a <= b THEN RETURN a ELSE RETURN b END;
END Min;

PROCEDURE Max(a, b: REAL): REAL;
BEGIN
	IF a >= b THEN RETURN a ELSE RETURN b END;
END Max;
*)

PROCEDURE OpenNew*;
VAR instance : Window;
BEGIN
	NEW(instance, NIL);
	instance.CreateNew;
END OpenNew;

PROCEDURE OpenEmptyA4portrait*;
VAR instance : Window;
BEGIN
	NEW(instance, NIL);
	instance.CreateDoc(210, 297, 15, 15, 15, 15, FALSE);
END OpenEmptyA4portrait;

PROCEDURE OpenEmptyA4landscape*;
VAR instance : Window;
BEGIN
	NEW(instance, NIL);
	instance.CreateDoc(297, 210, 15, 15, 15, 15, FALSE);
END OpenEmptyA4landscape;

PROCEDURE OpenEmptyA5portrait*;
VAR instance : Window;
BEGIN
	NEW(instance, NIL);
	instance.CreateDoc(148, 210, 15, 15, 15, 15, FALSE);
END OpenEmptyA5portrait;

PROCEDURE OpenEmptyA5landscape*;
VAR instance : Window;
BEGIN
	NEW(instance, NIL);
	instance.CreateDoc(210, 148, 15, 15, 15, 15, FALSE);
END OpenEmptyA5landscape;

PROCEDURE OpenEmpty*(context : Commands.Context);
VAR instance : Window;
	w, h, mt, mb, ml, mr : REAL; f : LONGINT; fp : BOOLEAN;
	dstring : ARRAY 16 OF CHAR;
	lreal : LONGREAL;
BEGIN
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); w := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); h := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); mt := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); mb := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); ml := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Token(dstring);
	Strings.StrToFloat(dstring, lreal); mr := SHORT(lreal);
	context.arg.SkipWhitespace; context.arg.Int(f, FALSE);

	IF f = 0 THEN fp := FALSE ELSE fp:= TRUE END;
	NEW(instance, NIL);

	instance.CreateDoc(w, h, mt, mb, ml, mr, fp);
END OpenEmpty;

PROCEDURE Open*(context : Commands.Context);
VAR instance : Window; name : ARRAY 256 OF CHAR;
BEGIN
	IF context.arg.GetString(name) THEN
		NEW(instance, NIL);
		instance.CreateDoc(10, 10, 0, 0, 0, 0, FALSE);
		instance.Load(name, 0);
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context)
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
	NEW(plugRegistry);
	Modules.InstallTermHandler(Cleanup)
END DTPEditor.

--- DTP Stuff -----------------------------------
DTPRect.Register~
DTPImage.Register~
DTPText.Register~

DTPEditor.OpenNew ~
DTPEditor.OpenEmptyA4portrait ~
DTPEditor.OpenEmptyA5portrait ~
DTPEditor.OpenEmptyA4landscape ~
DTPEditor.OpenEmptyA5landscape ~
DTPEditor.OpenEmpty 100 100 5.5 5.5 7.5 7.5 0 ~
DTPEditor.OpenEmpty 297 420 15 15 15 15 0 ~
DTPEditor.OpenEmpty 320 240 10 10 10 10 0 ~
DTPEditor.OpenEmpty 126 178 10 10 10 10 0 ~
DTPEditor.Open myDTPdocument ~

SystemTools.Free DTPText DTPImage DTPRect DTPEditor DTPView DTPUtilities DTPData~
PC.Compile DTPData.Mod DTPUtilities.Mod DTPView.Mod DTPEditor.Mod DTPRect.Mod DTPImage.Mod DTPText.Mod~

