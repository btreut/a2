MODULE DTPImage; (** AUTHOR "PL"; PURPOSE "Simple Image Plugin Component"; *)

IMPORT
	Modules, Files, XML,
	WMStandardComponents, WMGraphics,
	WMComponents, WMRectangles, WMDialogs,
	WMEditors, Strings, XMLObjects,
	WMWindowManager, Raster, WMRasterScale,
	DTPEditor, DTPData; (* DTPFrame *)

CONST
	pluginVersion = 1.00;
	pluginName = "Image";
	pluginDesc = "Loads an Image from the given Filename";
VAR

TYPE
	ImageObject* = OBJECT(DTPData.ContentObject);
	VAR ownerDocument: DTPData.Document;
		ownerPage: DTPData.PageObject;
		ownerFrame: DTPData.FrameObject;

		done: BOOLEAN;
		img: Raster.Image;
		filename: ARRAY 128 OF CHAR;
		properties: ImagePropWindow;

		PROCEDURE &New*;
		BEGIN
			done := FALSE;
			NEW(properties, SELF);
		END New;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; x, y, w, h : LONGINT; zoomFactor: REAL; quality, preview: BOOLEAN);
		VAR mode: LONGINT;
		BEGIN
			IF ~quality THEN
				mode := WMRasterScale.ScaleBox;
			ELSE
				mode := WMRasterScale.ScaleBilinear;
			END;
			IF done THEN
				canvas.ScaleImage(img, WMRectangles.MakeRect(0,0, img.width, img.height), WMRectangles.MakeRect(x, y, x+w+1, y+h+1), WMRasterScale.ModeSrcOverDst, mode);
			END;
		END Draw;

		PROCEDURE Clone*(): DTPData.ContentObject;			(* clone all the current properties *)
		VAR newObj: ImageObject;
			done: BOOLEAN;
		BEGIN
			NEW(newObj); newObj.contentName := Strings.NewString(contentName^);
			newObj.redrawProc := redrawProc; newObj.updatePropsPosition := updatePropsPosition;
			newObj.contentWidth := contentWidth; newObj.contentHeight := contentHeight; newObj.zoomFactor := zoomFactor;
			newObj.ownerDoc := ownerDoc;

			(* plugin specific clones *)
			NEW(newObj.img); newObj.img := WMGraphics.LoadImage(filename, FALSE);
			IF newObj.img # NIL THEN
				newObj.done := done;
				newObj.filename := filename;
			END;

			RETURN newObj;
		END Clone;

		PROCEDURE LoadImg(CONST file: ARRAY OF CHAR);
		BEGIN
			NEW(img); done := FALSE;
			img := WMGraphics.LoadImage(file, FALSE);
(*			Raster.Load(img, file, done);
			IF done THEN
*)			IF img # NIL THEN
				COPY(file, filename);
				done := TRUE;
			ELSE
				filename := "none";
			END;
		END LoadImg;

		PROCEDURE Load*(elem: XML.Element);
		VAR name : Strings.String;
			cont: XMLObjects.Enumerator;
			ptr: ANY;
		BEGIN
			cont := elem.GetContents(); cont.Reset();
			WHILE cont.HasMoreElements() DO
				ptr := cont.GetNext();
				IF ptr IS XML.Element THEN					(* read attributes *)
					name := ptr(XML.Element).GetAttributeValue("name");
					IF (name # NIL) & (name^ = "file") THEN
						name := ptr(XML.Element).GetAttributeValue("value");
						IF (name # NIL) THEN
							LoadImg(name^);
						END;
					END;
				END;
			END;
		END Load;

		PROCEDURE Store*(VAR w: Files.Writer);
		BEGIN
			w.String('  <node-attribute name="type" value="Image" />'); w.Ln;
			w.String('  <node-attribute name="file" value="'); w.String(filename); w.String('" />'); w.Ln;
		END Store;

		PROCEDURE OnCreate*;
		VAR filename: ARRAY 128 OF CHAR;
		BEGIN
			filename := "tux.bmp";
			IF WMDialogs.QueryString("Load Image:", filename) = WMDialogs.ResOk THEN
				LoadImg(filename);
			END;
		END OnCreate;

		PROCEDURE Redraw;
		BEGIN
			Redraw^;
		END Redraw;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			properties.Show(x, y);
		END Show;

		PROCEDURE Hide*;
		VAR viewport: WMWindowManager.ViewPort;
		BEGIN
			viewport := WMWindowManager.GetDefaultView();
			UpdatePosition(properties.bounds.l-ENTIER(viewport.range.l), properties.bounds.t-ENTIER(viewport.range.t));
			properties.Hide;
		END Hide;

		PROCEDURE Close*;
		BEGIN
			Hide;
		END Close;

	END ImageObject;

	ImagePropWindow = OBJECT(WMComponents.FormWindow)
	VAR theCaller : ImageObject;

		shown: BOOLEAN;
		leftPanel, rightPanel: WMStandardComponents.Panel;
		fileEdit: WMEditors.Editor;

		PROCEDURE &New*(caller: ImageObject);
		VAR vc: WMComponents.VisualComponent;
		BEGIN
			theCaller := caller;
			manager := WMWindowManager.GetDefaultManager();
			vc := CreatePropertyForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			SetTitle(Strings.NewString("Content"));
			shown := FALSE;

		END New;

		PROCEDURE CreatePropertyForm(): WMComponents.VisualComponent;
		VAR panel: WMStandardComponents.Panel;
			label: WMStandardComponents.Label;
			windowStyle : WMWindowManager.WindowStyle;
			panelColor : LONGINT;
		BEGIN
			windowStyle := manager.GetStyle();
			panelColor := windowStyle.bgColor;

			NEW(panel); panel.bounds.SetExtents(190 , 60); panel.fillColor.Set(panelColor);
			panel.takesFocus.Set(TRUE);
			NEW(leftPanel); leftPanel.bounds.SetWidth(90); leftPanel.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(leftPanel);
			NEW(rightPanel); rightPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(rightPanel);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			label.SetCaption(" Filename:"); label.textColor.Set(0000000FFH);
			leftPanel.AddContent(label);
			NEW(fileEdit); fileEdit.bounds.SetHeight(20); fileEdit.alignment.Set(WMComponents.AlignTop);
			fileEdit.tv.showBorder.Set(TRUE); fileEdit.multiLine.Set(FALSE); fileEdit.fillColor.Set(0FFFFFFFFH);
			fileEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			fileEdit.onEnter.Add(SetValueHandler); fileEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			fileEdit.SetAsString(theCaller.filename);
			rightPanel.AddContent(fileEdit);

			RETURN panel;
		END CreatePropertyForm;

		PROCEDURE Show*(x, y: LONGINT);
		BEGIN
			IF ~shown THEN
				shown := TRUE;
				RefreshValues;
				WMWindowManager.ExtAddWindow(SELF, x, y,
					{WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			END;
		END Show;

		PROCEDURE Hide*;
		BEGIN
			IF shown THEN
				shown := FALSE;
				manager.Remove(SELF);
			END;
		END Hide;

		PROCEDURE RefreshValues;
		BEGIN
			fileEdit.SetAsString(theCaller.filename);
			fileEdit.Invalidate;
		END RefreshValues;

		PROCEDURE SetValueHandler(sender, data: ANY);
		VAR
			file : ARRAY 128 OF CHAR;
		BEGIN
			(* COPY(theCaller.filename, file); *)

			IF (sender = fileEdit) THEN
				fileEdit.GetAsString(file);
				IF file # theCaller.filename THEN						(* load new picture *)
					theCaller.LoadImg(file);
					theCaller.Redraw;
					RefreshValues;
				END;
			END;

		END SetValueHandler;

		PROCEDURE Close;
		BEGIN
			shown := FALSE;
			Hide;
			Close^;
		END Close;

	END ImagePropWindow;


PROCEDURE GenImage*(): DTPData.ContentObject;
VAR image: ImageObject;
BEGIN
	NEW(image);
	RETURN image;
END GenImage;

PROCEDURE Register*;
BEGIN
	DTPEditor.plugRegistry.RegisterPlugin(pluginName, GenImage);
END Register;

PROCEDURE Cleanup;
BEGIN
	DTPEditor.plugRegistry.UnregisterPlugin(pluginName);
END Cleanup;


BEGIN
	Modules.InstallTermHandler(Cleanup);
END DTPImage.

---------------------------------
SystemTools.Free DTPImage
