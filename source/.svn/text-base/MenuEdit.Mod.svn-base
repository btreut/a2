MODULE MenuEdit;	(** AUTHOR "TF"; PURPOSE "Template/Example  for component windows"; *)

(** This program shows the implementation of a multi instance component containing window *)

IMPORT
	Strings, WMGraphics, WMMessages, WMComponents, WMStandardComponents,
	Modules, KernelLog, WMRectangles,
	Streams, MultiLogger, Random, WMDialogs, XML, XMLObjects,
	WM := WMWindowManager;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR add, store, delete, edit, toFront : WMStandardComponents.Button;
		panel, toolbar : WMStandardComponents.Panel;
		selectedObj : WMComponents.VisualComponent;
		lx, ly : LONGINT;
		generator : Random.Generator;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR e : WMStandardComponents.Panel;
		BEGIN
			NEW(e); e.bounds.SetExtents(500, 520); e.fillColor.Set(0); e.takesFocus.Set(TRUE);
			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.fillColor.Set(0); toolbar.takesFocus.Set(TRUE);
			toolbar.alignment.Set(WMComponents.AlignTop);
			e.AddContent(toolbar);

			NEW(add); add.caption.SetAOC("Add"); add.onClick.Add(AddButton); add.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(add);

			NEW(store); store.caption.SetAOC("Get XML"); store.onClick.Add(Store); store.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(store);

			NEW(delete); delete.caption.SetAOC("Delete"); delete.onClick.Add(Delete); delete.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(delete);

			NEW(edit); edit.caption.SetAOC("Edit"); edit.onClick.Add(Edit); edit.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(edit);

			NEW(toFront); toFront.caption.SetAOC("To Front"); toFront.onClick.Add(ToFront); toFront.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(toFront);


			NEW(panel); panel.bounds.SetExtents(500, 500); panel.fillColor.Set(0); panel.alignment.Set(WMComponents.AlignTop); panel.takesFocus.Set(TRUE);
			e.AddContent(panel);
			RETURN e
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			NEW(generator);
			IncCount;
			(* To create a multi language app, try loading the respective XML instead of CreateForm()
			if the XML was not found or does not contain all needed elements, use CreateForm as fallback *)
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Menu Edit"));
		END New;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR button : WMStandardComponents.Button;
		BEGIN
			IF 1 IN keys THEN
				NEW(button);
				button.bounds.SetExtents(64, 64);
				panel.AddContent(button);
				panel.Invalidate;
				Select(button);
			END;
		END PointerDown;

		PROCEDURE AddButton(sender, data : ANY);
		VAR button : WMStandardComponents.Button;
			name, nameD, nameH, str : ARRAY 64 OF CHAR;
			type, direction : LONGINT;
			img : WMGraphics.Image;
			sc : WMStandardComponents.SystemCommand;

		BEGIN
			name := "present.tar://present";
			type := generator.Dice(5) + 1; direction := generator.Dice(3) + 1;
			Strings.IntToStr(type, str); Strings.Append(name, str);
			Strings.Append(name, "-");
			Strings.IntToStr(direction, str); Strings.Append(name, str);

			COPY(name, nameD); Strings.Append(nameD, ".png");
			COPY(name, nameH); Strings.Append(nameH, "h.png");

			img := WMGraphics.LoadImage(nameD, TRUE);
			IF img # NIL THEN
				NEW(button);
				button.bounds.SetExtents(img.width, img.height);
				button.imgDefaultName.SetAOC(nameD);
				button.imgHoverName.SetAOC(nameH);
				button.clTextDefault.Set(0FFFFH);
				button.useBgBitmaps.Set(TRUE);
				button.onClick.Add(SelectPresent);
				button.onClickHandler.SetAOC("X Run");

				NEW(sc);
				sc.id.SetAOC("X");
				button.AddContent(sc);
				panel.AddContent(button);
				button.Reset(NIL, NIL);
				panel.Invalidate;
				Select(button);
			END
		END AddButton;

		PROCEDURE Delete(sender, data : ANY);
		BEGIN
			IF selectedObj # NIL THEN
				panel.RemoveContent(selectedObj);
				selectedObj := NIL;
				panel.Invalidate
			END
		END Delete;

		PROCEDURE ToFront(sender, data : ANY);
		BEGIN
			IF selectedObj # NIL THEN
				panel.RemoveContent(selectedObj);
				panel.AddContent(selectedObj);
				panel.Invalidate
			END
		END ToFront;

		PROCEDURE Edit(sender, data : ANY);
		VAR caption, command : ARRAY 1024 OF CHAR;
			s : Strings.String;
			sc : WMStandardComponents.SystemCommand;
			e : XMLObjects.Enumerator; c : ANY;
		BEGIN
			IF selectedObj # NIL THEN
				s := selectedObj(WMStandardComponents.Button).caption.Get();
				IF s # NIL THEN COPY(s^, caption) END;
				IF WMDialogs.QueryString("Caption", caption) = WMDialogs.ResOk THEN
					selectedObj(WMStandardComponents.Button).caption.SetAOC(caption);
				END;

				sc := NIL;
				e := selectedObj.GetContents();
				IF e.HasMoreElements() THEN
					c := e.GetNext();
					s := c(XML.Element).GetName(); KernelLog.String("s^= "); KernelLog.String(s^); KernelLog.Ln;
					IF (c IS WMStandardComponents.SystemCommand) THEN sc := c(WMStandardComponents.SystemCommand) END;
				END;

				IF sc # NIL THEN
					s := sc.commandString.Get();
					IF s # NIL THEN COPY(s^, command) END;
					IF WMDialogs.QueryString("Command", command) = WMDialogs.ResOk THEN
						sc.commandString.SetAOC(command);
					END;
				END;

				panel.Invalidate
			END
		END Edit;

		PROCEDURE Store(sender, data : ANY);
		VAR ml : MultiLogger.LogWindow;
			w : Streams.Writer;
		BEGIN
			NEW(ml, "XML", w);
			panel.Write(w, NIL, 0);
			w.Update;
		END Store;

		PROCEDURE Select(vc : WMComponents.VisualComponent);
		BEGIN
			IF selectedObj # NIL THEN
				selectedObj.SetExtPointerDownHandler(NIL);
				selectedObj.SetExtPointerMoveHandler(NIL)
			END;
			selectedObj	:= vc;
			selectedObj.SetExtPointerMoveHandler(HandlePointerMove);
			selectedObj.SetExtPointerDownHandler(HandlePointerDown);
		END Select;

		PROCEDURE SelectPresent(sender, data : ANY);
		BEGIN
			IF (sender # NIL) & (sender IS WMComponents.VisualComponent) THEN
				Select(sender(WMComponents.VisualComponent))
			END
		END SelectPresent;


		PROCEDURE HandlePointerDown(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		BEGIN
			lx := x; ly := y; handled := TRUE
		END HandlePointerDown;

		PROCEDURE HandlePointerMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy : LONGINT; r : WMRectangles.Rectangle;
		BEGIN
			IF 0 IN keys THEN
				IF selectedObj # NIL THEN
					dy := y - ly;	dx := x - lx;
					r := selectedObj.bounds.Get();
					WMRectangles.MoveRel(r, dx, dy);
					selectedObj.bounds.Set(r);
					panel.Invalidate;
				END
			END;
			handled := TRUE
		END HandlePointerMove;


		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance);
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
	Modules.InstallTermHandler(Cleanup)
END MenuEdit.

SystemTools.Free MenuEdit ~
MenuEdit.Open ~
