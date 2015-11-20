MODULE TestMenu; (** AUTHOR "TF/staubesv" PURPOSE "Testbed for WMMenus.Mod" *)

IMPORT
	KernelLog,
	Modules, Commands,Strings, Files, XML, XMLObjects, XMLScanner, XMLParser,
	WMGraphics, WMMessages, WM := WMWindowManager,
	WMComponents, WMStandardComponents, WMTrees, WMMenus;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		menu : WMTrees.Tree;
		menuPanel : WMMenus.MenuPanel;
		hasErrors : BOOLEAN;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			root : WMTrees.TreeNode;
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(800, 700);
			panel.fillColor.Set(LONGINT(0FFFFFFFFH));
			panel.takesFocus.Set(TRUE);

			NEW(menu); NEW(root);

			NEW(menuPanel);
			menuPanel.fillColor.Set(LONGINT(WMGraphics.White));
			menuPanel.bounds.SetHeight(20);
			menuPanel.alignment.Set(WMComponents.AlignTop);
			menuPanel.horizontal.Set(TRUE);
			menuPanel.openDirection.Set(WMMenus.OpenDownRight);
			menuPanel.SetMenu(menu, root);
			menuPanel.onSelect.Add(Selected);
			panel.AddContent(menuPanel);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			(* To create a multi language app, try loading the respective XML instead of CreateForm()
			if the XML was not found or does not contain all needed elements, use CreateForm as fallback *)
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			 WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Test Window"));
		END New;

		PROCEDURE AddMenuItem(node : WMTrees.TreeNode; xml : XML.Element);
		VAR newNode : WMTrees.TreeNode;
		BEGIN
			NEW(newNode);
			menu.AddChildNode(node, newNode);
			menu.SetNodeData(newNode, xml);
			menu.SetNodeCaption(newNode, xml.GetAttributeValue("caption"));
		END AddMenuItem;

		PROCEDURE Selected(sender, data : ANY);
		VAR s : Strings.String;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Selected, sender, data)
			ELSE
				IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
					menu.Acquire;
					s := menu.GetNodeCaption(data(WMTrees.TreeNode));
					IF s # NIL THEN KernelLog.String(s^); KernelLog.Ln; END;
					menu.Release;
				END
			END
		END Selected;

		PROCEDURE AddSubMenu(node : WMTrees.TreeNode; xml : XML.Element );
		VAR en : XMLObjects.Enumerator;
			p : ANY; s : Strings.String;
			newNode : WMTrees.TreeNode;
		BEGIN
			NEW(newNode);
			menu.AddChildNode(node, newNode);
			menu.SetNodeData(newNode, xml);
			menu.SetNodeCaption(newNode, xml.GetAttributeValue("caption"));

			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					s := p(XML.Element).GetName();
					IF s # NIL THEN
						IF s^ = "MenuItem" THEN AddMenuItem(newNode, p(XML.Element))
						ELSIF s^ = "SubMenu" THEN AddSubMenu(newNode, p(XML.Element))
						END
					END
				END
			END;
		END AddSubMenu;

		PROCEDURE SetDocument(xml : XML.Element);
		VAR en : XMLObjects.Enumerator;
			p : ANY; s : Strings.String;
			node : WMTrees.TreeNode;
		BEGIN
			NEW(node);
			menu.Acquire;
			menu.SetRoot(node);
			menu.SetNodeState(node, {WMTrees.NodeAlwaysExpanded});
			menu.SetNodeData(node, xml);
			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					s := p(XML.Element).GetName();
					IF s # NIL THEN
						IF s^ = "SubMenu" THEN AddSubMenu(node, p(XML.Element))
						ELSIF s^ = "MenuItem" THEN AddMenuItem(node, p(XML.Element))
						END
					END
				END
			END;
			menu.Release;
			menuPanel.SetMenu(menu, node)
		END SetDocument;

		PROCEDURE Error(pos, line, row : LONGINT; CONST msg : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
			KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
			hasErrors := TRUE
		END Error;

		PROCEDURE Read(CONST name : ARRAY OF CHAR);
		VAR f : Files.File;
			r : Files.Reader;
			scanner : XMLScanner.Scanner;
			parser : XMLParser.Parser;
			doc : XML.Document;
		BEGIN
			hasErrors := FALSE;
			f := Files.Old(name);
			IF f # NIL THEN
				Files.OpenReader(r, f, 0);
				NEW(scanner, r); scanner.reportError := Error;
				NEW(parser, scanner); parser.reportError := Error;
				doc := parser.Parse();
				IF hasErrors THEN KernelLog.String("menu not loaded"); KernelLog.Ln
				ELSE SetDocument(doc.GetRoot());
				END
			ELSE
				KernelLog.String("name = "); KernelLog.String(name); KernelLog.String(" not found"); KernelLog.Ln
			END
		END Read;

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

TYPE

	Command = OBJECT
	VAR
		commandString : ARRAY 256 OF CHAR;

		PROCEDURE &Init(CONST commandString : ARRAY OF CHAR);
		BEGIN
			COPY(commandString, SELF.commandString);
		END Init;

		PROCEDURE Execute;
		VAR ignoreRes : LONGINT; ignoreMsg : ARRAY 1 OF CHAR;
		BEGIN
			Commands.Call(commandString, {}, ignoreRes, ignoreMsg);
		END Execute;

	END Command;

VAR
	nofWindows : LONGINT;
	lastMenu : WMTrees.Tree; (* not thread-safe *)

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance);
	winstance.Read("Menu.XML");
END Open;

PROCEDURE HandleItemSelected(sender, data : ANY);
VAR caption : Strings.String; menu : WMTrees.Tree;
BEGIN
	IF (data # NIL) THEN
		IF (data IS Command) THEN
			data(Command).Execute;
		ELSE
			menu := lastMenu;
			IF (menu # NIL) THEN
				caption := WMMenus.GetCaption(data, menu);
				KernelLog.String("Selected node: ");
				IF (caption # NIL) THEN
					KernelLog.String(caption^);
				ELSE
					KernelLog.String("NIL");
				END;
				KernelLog.Ln;
			ELSE
				KernelLog.String("Test error: Menu not available"); KernelLog.Ln;
			END;
		END;
	END;
END HandleItemSelected;

PROCEDURE OpenPopup*(context : Commands.Context);
VAR
	path, commandString : ARRAY 256 OF CHAR;
	menu : WMTrees.Tree; node : WMTrees.TreeNode;
	command : Command;
BEGIN
	NEW(menu); lastMenu := menu;
	WHILE context.arg.GetString(path) DO
		IF context.arg.GetString(commandString) THEN
			NEW(command, commandString);
			node := WMMenus.AddItemNode(path, menu);
			menu.Acquire;
			menu.SetNodeData(node, command);
			menu.Release;
		END;
	END;
	WMMenus.Show(menu, 100, 100, HandleItemSelected);
END OpenPopup;

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
END TestMenu.

SystemTools.Free TestMenu WMMenus ~
TestMenu.Open ~

TestMenu.OpenPopup
	Inspect.Performance WMPerfMon.Open
	Inspect.Profiler WMProfiler.Open
	Inspect.Events WMEvents.Open
	Inspect.Components WMInspector.Open
	--- NoCommand
	Tools.Search WMSearchTool.Open
	Tools.Archiver WMArchives.Open
	Tools.Console WMShell.Open
	"Tools.Partition Manager" WMPartitions.Open
	"Tools.Partition Editor" WMPartitionEditor.Open
	--- NoCommand
	Commands.Files.ShowFS FSTools.Watch
	Commands.Files.Directory "FSTools.Directory *"
	Commands.Partitions.Show Partitions.Show
~~
