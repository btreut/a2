MODULE PieTest;	(** AUTHOR "PL"; PURPOSE "TEST"; *)

IMPORT
	WMStandardComponents, WMComponents,
	WMMessages, Strings, WMRectangles, Modules, KernelLog,
	WMPieMenu,
	WM := WMWindowManager;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	(* Simple Window *)
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		panel : WMStandardComponents.Panel;
		bear : WMRectangles.Rectangle;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			bear := WMRectangles.MakeRect(5, 5, 5, 5);
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			SetTitle(Strings.NewString("Pie test"));
			WM.DefaultAddWindow(SELF)
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			testComp1 : SomePanel;
			tl : WMStandardComponents.Label; (* Button *)
		BEGIN
			NEW(panel); panel.bounds.SetExtents(400, 300); panel.fillColor.Set(01144AA80H);

			NEW(tl); tl.alignment.Set(WMComponents.AlignTop); tl.fillColor.Set(LONGINT(0FF000080H));
			panel.AddContent(tl); tl.caption.SetAOC("Top"); tl.bounds.SetHeight(40); tl.bearing.Set(bear);

			NEW(tl); tl.alignment.Set(WMComponents.AlignBottom); tl.fillColor.Set(00000FF80H);
			panel.AddContent(tl); tl.caption.SetAOC("Bottom"); tl.bounds.SetHeight(40); tl.bearing.Set(bear);

			NEW(tl); tl.alignment.Set(WMComponents.AlignLeft); tl.fillColor.Set(LONGINT(088FF0080H));
			panel.AddContent(tl); tl.caption.SetAOC("Left"); tl.bounds.SetWidth(40); tl.bearing.Set(bear);

			NEW(tl); tl.alignment.Set(WMComponents.AlignRight); tl.fillColor.Set(000FF8880H);
			panel.AddContent(tl); tl.caption.SetAOC("Right"); tl.bounds.SetWidth(40); tl.bearing.Set(bear);

			NEW(tl); tl.alignment.Set(WMComponents.AlignClient); tl.fillColor.Set(000FF0080H);
			panel.AddContent(tl); tl.caption.SetAOC("Client"); tl.bearing.Set(bear);

			NEW(testComp1);
			testComp1.bearing.Set(WMRectangles.MakeRect(20, 20, 20, 20));
			testComp1.fillColor.Set(01144AA50H);
			testComp1.alignment.Set(WMComponents.AlignClient);

			tl.AddContent(testComp1);

			RETURN panel
		END CreateForm;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle (VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^ (x)
			END
		END Handle;

	END Window;

	(* Test Visual Component *)
	SomePanel* = OBJECT(WMStandardComponents.Panel)
	VAR

		(* overwrite PointerDown method *)
		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		BEGIN
			IF keys * {0, 1, 2} = {2} THEN 					(* right mouse button pressed *)
				ShowContextMenu(x, y);
			END
		END PointerDown;

		PROCEDURE ShowContextMenu(x, y :  LONGINT);
		VAR bimbo : WMPieMenu.Menu;
			manager : WM.WindowManager;
			window : WM.Window;
		BEGIN
			NEW(bimbo); bimbo.SetEnabled({1, 3});
			bimbo.SetText(1, Strings.NewString("Open"));
			bimbo.SetText(3, Strings.NewString("Start"));
			bimbo.SetText(2, Strings.NewString("Copy"));
			bimbo.SetText(0, Strings.NewString("Paste"));
			bimbo.on1.Add(TestHandler);

			manager := WM.GetDefaultManager();
			window := manager.GetPositionOwner(x, y);
			IF window = NIL THEN RETURN END;

			Acquire; ToWMCoordinates(x, y, x, y); Release;
			bimbo.Show(window, x, y, FALSE)
		END ShowContextMenu;

		PROCEDURE TestHandler(sender, data : ANY);
		BEGIN
			KernelLog.String("FASEL!!");
		END TestHandler;

	END SomePanel;

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
END PieTest.

SystemTools.Free PieTest ~
PieTest.Open ~
