MODULE TestComponentDragDrop;	(** AUTHOR "TF"; PURPOSE "Testing Component Drag & Drop"; *)

IMPORT
	KernelLog, Modules, WMStandardComponents,
	WMComponents, WMGraphics, WMDialogs,
	WM := WMWindowManager;

TYPE
	TestComponent = OBJECT(WMComponents.VisualComponent)
		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			IF 0 IN keys THEN
				IF StartDrag(NIL, WMGraphics.LoadImage("Bart.Pict", TRUE), 0,0,DragAccepted, DragRejected) THEN KernelLog.String("DraggingStarted")
				ELSE KernelLog.String("Drag could not be started")
				END;
			ELSE
				ToWMCoordinates(x, y, x, y);
				KernelLog.Int(x, 5); KernelLog.String(", "); KernelLog.Int(y, 4); KernelLog.Ln;
				KernelLog.Int(WMDialogs.MessageXY(WMDialogs.TInformation, x, y, "Hello", "This should always be where you clicked the panel", {WMDialogs.ResOk}), 5);
			END
		END PointerDown;

		PROCEDURE DragOver(x, y : LONGINT; dragInfo : WM.DragInfo);
		BEGIN
			KernelLog.String("Drag Over @ "); KernelLog.Int(x, 4); KernelLog.Int(y, 4); KernelLog.Ln
		END DragOver;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WM.DragInfo);
		BEGIN
			KernelLog.String("Drag dropped @ "); KernelLog.Int(x, 4); KernelLog.Int(y, 4); KernelLog.Ln;
			IF dragInfo.sender = SELF THEN ConfirmDrag(FALSE, dragInfo)
			ELSE ConfirmDrag(TRUE, dragInfo)
			END
		END DragDropped;

		PROCEDURE DragAccepted(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(DragAccepted, sender, data)
			ELSE
				KernelLog.String("Accepted"); KernelLog.Ln
			END;
		END DragAccepted;

		PROCEDURE DragRejected(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(DragRejected, sender, data)
			ELSE
				KernelLog.String("Rejected"); KernelLog.Ln
			END;
		END DragRejected;

	END TestComponent;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		panel : WMStandardComponents.Panel;
		testComponent : TestComponent;

		PROCEDURE &New*;
		BEGIN
			(* add a panel *)
			NEW(panel); panel.bounds.SetExtents(640, 420); panel.fillColor.Set(WMGraphics.RGBAToColor(255, 255, 255, 255));

			(* add a test component *)
			NEW(testComponent); testComponent.alignment.Set(WMComponents.AlignTop);
			 testComponent.bounds.SetExtents(200, 20); testComponent.fillColor.Set(0FFFFH);
			panel.AddContent(testComponent);

			(* add a test component *)
			NEW(testComponent); testComponent.alignment.Set(WMComponents.AlignTop);
			testComponent.bounds.SetExtents(200, 20); testComponent.fillColor.Set(0FF00FFH);
			panel.AddContent(testComponent);

			(* create the form window with panel size *)
			Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE);
			SetContent(panel);

			manager := WM.GetDefaultManager();
			SetTitle(WM.NewString("Drag drop panels"));
			(* open the window *)
			manager.Add(100, 100, SELF, {WM.FlagFrame})
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			window := NIL
		END Close;

	END Window;

VAR window : Window;

PROCEDURE Open*;
BEGIN
	IF window = NIL THEN NEW(window)
	ELSE KernelLog.String("Already open"); KernelLog.Ln
	END;
END Open;

PROCEDURE Cleanup;
BEGIN
	IF window # NIL THEN window.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END TestComponentDragDrop.

TestComponentDragDrop.Open ~
SystemTools.Free TestComponentDragDrop ~

