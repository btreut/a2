MODULE TestComponents; (** AUTHOR "staubesv"; PURPOSE "Simple test framework  for visual components"; *)

IMPORT
	Modules, KernelLog, Commands, Strings, XML, Repositories,
	WMWindowManager, WMMessages, WMComponents,
	WMStandardComponents, WMStringGrids;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

TYPE

	TestBase = OBJECT (WMComponents.FormWindow)

		PROCEDURE CreateForm() : WMComponents.VisualComponent; (* abstract *)
		END CreateForm;

		PROCEDURE &New*(CONST windowTitle : ARRAY OF CHAR);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString(windowTitle));
			WMWindowManager.DefaultAddWindow(SELF);
		END New;

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

	END TestBase;

TYPE

	TestVisualComponent = OBJECT(TestBase)
	VAR
		vc : WMComponents.VisualComponent;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		BEGIN
			RETURN vc;
		END CreateForm;

		PROCEDURE &NewTest*(CONST windowTitle : ARRAY OF CHAR; vc : WMComponents.VisualComponent);
		BEGIN
			ASSERT(vc # NIL);
			SELF.vc := vc;
			vc.bounds.SetExtents(640, 480);
			vc.alignment.Set(WMComponents.AlignClient);
			New(windowTitle);
		END NewTest;

	END TestVisualComponent;

TYPE

	StandardComponents = OBJECT(TestBase)
	VAR
		label : WMStandardComponents.Label;

		PROCEDURE SayHello(sender, data : ANY);
		BEGIN
			KernelLog.String("SayHello"); KernelLog.Ln
		END SayHello;

		PROCEDURE SayBye(sender, data : ANY);
		BEGIN
			KernelLog.String("SayBye"); KernelLog.Ln
		END SayBye;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar : WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(640, 480);
			panel.fillColor.Set(LONGINT(0FFFFFFFFH));
			panel.takesFocus.Set(TRUE);

			NEW(toolbar);
			toolbar.fillColor.Set(000FF00FFH);
			toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(button);
			button.alignment.Set(WMComponents.AlignLeft);
			button.caption.SetAOC("Hello");
			button.onClick.Add(SayHello);
			toolbar.AddContent(button);

			NEW(button);
			button.alignment.Set(WMComponents.AlignLeft);
			button.caption.SetAOC("Bye");
			button.onClick.Add(SayBye);
			toolbar.AddContent(button);

			NEW(label);
			label.bounds.SetHeight(20);
			label.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(label);

			RETURN panel
		END CreateForm;

	END StandardComponents;

TYPE

	StringGrids = OBJECT(TestBase)
	VAR
		label: WMStandardComponents.Label;
		tabs : WMStringGrids.StringGrid;

		PROCEDURE Test(sender, data : ANY);
		VAR i : LONGINT; str : ARRAY 20 OF CHAR;
		BEGIN
			tabs.model.Acquire;
			FOR i := 0 TO 4 * 5 - 1 DO
				Strings.IntToStr(i, str);
				tabs.model.SetCellText(i MOD 4, i DIV 4, Strings.NewString(str))
			END;
			tabs.model.Release;
		END Test;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(800, 700); panel.fillColor.Set(LONGINT(0FFFFFFFFH)); panel.takesFocus.Set(TRUE);

			NEW(toolbar); toolbar.fillColor.Set(000FF00FFH); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(button); button.alignment.Set(WMComponents.AlignLeft); button.caption.SetAOC("Test");
			button.onClick.Add(Test);
			toolbar.AddContent(button);

			NEW(label); label.bounds.SetHeight(20);label.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(label);

			NEW(tabs);
			tabs.alignment.Set(WMComponents.AlignClient);
			tabs.fillColor.Set(LONGINT(0FF0000FFH));
			panel.AddContent(tabs);
			tabs.model.Acquire;
			tabs.model.SetNofCols(4);
			tabs.model.SetNofRows(10);
			tabs.model.Release;

			RETURN panel
		END CreateForm;

	END StringGrids;

VAR
	nofWindows : LONGINT;

PROCEDURE Test*(context : Commands.Context); (** name ~ *)
VAR test : TestVisualComponent; name : ARRAY 128 OF CHAR; element : XML.Element;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(name);
	element := Repositories.registry.InstantiateElement(name);
	IF (element # NIL) THEN
		IF (element IS WMComponents.VisualComponent) THEN
			NEW(test, name, element(WMComponents.VisualComponent));
		ELSE
			context.out.String("Component '"); context.out.String(name); context.out.String("' is not a VisualComponent.");
			context.out.Ln;
		END;
	ELSE
		context.out.String("Component '"); context.out.String(name); context.out.String("' not found");
		context.out.Ln;
	END;
END Test;

PROCEDURE TestComponent*(vc : WMComponents.VisualComponent);
VAR test : TestVisualComponent;
BEGIN
	ASSERT(vc # NIL);
	NEW(test, "Visual Component Test", vc);
END TestComponent;

PROCEDURE TestStandardComponents*;
VAR test : StandardComponents;
BEGIN
	NEW(test, "StandardComponents Test");
END TestStandardComponents;

PROCEDURE TestStringGrids*;
VAR test : StringGrids;
BEGIN
	NEW(test, "StringGrids Test");
END TestStringGrids;

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
	Modules.InstallTermHandler(Cleanup)
END TestComponents.

TestComponents.TestStandardComponents ~
TestComponents.TestStringGrids ~

TestComponents.Test ComponentList ~

SystemTools.Free TestComponents ~