MODULE WMBuilder; (** AUTHOR "staubesv"; PURPOSE "GUI builder"; *)

IMPORT
	Modules, Kernel, KernelLog, Streams, Commands, Inputs, Strings, Files, XML, XMLObjects, XMLScanner, XMLParser,
	Math, Repositories, WMRepositories, WMUtilities,
	WMRectangles, WMGraphics, WMMessages, WMWindowManager, WMRestorable, WMProperties, WMComponents, WMStandardComponents, WMEditors,
	WMTrees, WMInspectionComponents, WMDialogs, Models;

CONST
	WindowWidth = 128; WindowHeight = 320;
	EditWindowWidth = 640; EditWindowHeight = 480;

	Invalid = MIN(LONGINT);

	(* ComponentEditor.Mode *)
	UseMode = 0;
	EditMode = 1;

	(* ComponentEditor:IsInFrameHandle/IsInCurrentFrame result codes *)
	No = -1;
	Left = 0;
	TopLeft = 1;
	Top = 2;
	TopRight = 3;
	Right = 4;
	BottomRight = 5;
	Bottom = 6;
	BottomLeft = 7;
	Inside = 8;

	Paint = 999;

	(* ComponentEditor:pointerMode *)
	None = 0;
	SelectComponent = 1;
	ResizeMove = 2;
	Spawn = 3;
	PaintComponent = 5;

	(* ComponentEditor.state *)
	State_Running = 0;
	State_Terminating = 99;
	State_Terminated = 100;

	(* Frame types *)
	Frame_Selection = 0;
	Frame_Selection_InsertAt = 1;

	DistanceLimit = 4;

	DarkYellow = 505000FFH;

	(* Colors *)
	ColorLocked = DarkYellow;
	ColorSelected = WMGraphics.Red;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

TYPE

	HelperWindow = OBJECT(WMComponents.FormWindow)

		PROCEDURE &New(CONST windowTitle : ARRAY OF CHAR; component : WMComponents.VisualComponent; x, y, width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			Init(width, height, alpha);
			component.alignment.Set(WMComponents.AlignClient);
			SetContent(component);
			SetTitle(Strings.NewString(windowTitle));
			WMWindowManager.ExtAddWindow(SELF, x, y, {WMWindowManager.FlagFrame, WMWindowManager.FlagHidden});
		END New;

	END HelperWindow;

TYPE

	ComponentWindow = OBJECT(WMComponents.FormWindow)
	VAR
		repositories : WMRepositories.RepositoriesView;
		repository : WMRepositories.RepositoryView;

		loadBtn, storeBtn, unloadBtn : WMStandardComponents.Button;
		filenameEditor : WMEditors.Editor;
		statusLabel : WMStandardComponents.Label;

		selection : WMRepositories.EntryWrapper;

		opNum : LONGINT;

		PROCEDURE &Init(width, height : LONGINT; alpha : BOOLEAN);
		VAR slib : Repositories.Repository;
		BEGIN
			Init^(width, height, FALSE);
			SetContent(CreateForm());
			repository.UpdateGridSpacings;
			slib := Repositories.ThisRepository("Standard");
			IF (slib # NIL) THEN
				repositories.SelectByRepository(slib);
			END;
			SetTitle(Strings.NewString("Repositories"));
			SetIcon(WMGraphics.LoadImage("WMRepositories.Tar://WMRepositories.png", TRUE));
			selection := NIL;
			opNum := 1;
		END Init;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, treePanel, toolbar : WMStandardComponents.Panel; resizer : WMStandardComponents.Resizer;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignBottom);
			statusLabel.bounds.SetHeight(20);
			statusLabel.fillColor.Set(0CCCCCCCCH);
			statusLabel.caption.SetAOC("0: OK");
			panel.AddContent(statusLabel);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			panel.AddContent(toolbar);

			NEW(loadBtn); loadBtn.alignment.Set(WMComponents.AlignLeft);
			loadBtn.caption.SetAOC("Load");
			loadBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(loadBtn);

			NEW(filenameEditor); filenameEditor.alignment.Set(WMComponents.AlignClient);
			filenameEditor.multiLine.Set(FALSE);
			filenameEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filenameEditor.tv.showBorder.Set(TRUE);
			filenameEditor.onEnter.Add(OnEnter);
			toolbar.AddContent(filenameEditor);

			NEW(unloadBtn); unloadBtn.alignment.Set(WMComponents.AlignRight);
			unloadBtn.caption.SetAOC("Unload");
			unloadBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(unloadBtn);

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignRight);
			storeBtn.caption.SetAOC("Store");
			storeBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(storeBtn);

			NEW(treePanel); treePanel.alignment.Set(WMComponents.AlignLeft);
			treePanel.bounds.SetWidth(100);
			panel.AddContent(treePanel);

			NEW(resizer); resizer.alignment.Set(WMComponents.AlignRight);
			resizer.bounds.SetWidth(5);
			treePanel.AddContent(resizer);

			NEW(repositories); repositories.alignment.Set(WMComponents.AlignClient);
			treePanel.AddContent(repositories);
			repositories.grid.onClick.Add(OnRepositoriesClicked);

			NEW(repository); repository.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(repository);
			repository.showDetails.Set(FALSE);
			repository.grid.onClick.Add(OnComponentClicked);
			repository.grid.onClickSelected.Add(OnClickedSelected);

			RETURN panel;
		END CreateForm;

		PROCEDURE SetStatusLabel(CONST m1, m2, m3 : ARRAY OF CHAR);
		VAR caption : ARRAY 256 OF CHAR; nbr : ARRAY 8 OF CHAR;
		BEGIN
			caption := " ";
			Strings.IntToStr(opNum, nbr); INC(opNum);
			Strings.Append(caption, nbr);
			Strings.Append(caption, ": ");
			Strings.Append(caption, m1);
			Strings.Append(caption, m2);
			Strings.Append(caption, m3);
			statusLabel.caption.SetAOC(caption);
		END SetStatusLabel;

		PROCEDURE LoadRepository(CONST filename : ARRAY OF CHAR);
		VAR repository : Repositories.Repository; timer : Kernel.Timer;
		BEGIN
			repository := Repositories.ThisRepository(filename);
			IF (repository # NIL) THEN
				NEW(timer); timer.Sleep(200);
				repositories.SelectByRepository(repository);
				SetStatusLabel("Repository '", filename, "' loaded");
			ELSE
				SetStatusLabel("Repository '", filename, "' not found");
			END;
		END LoadRepository;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR; res : LONGINT;
		BEGIN
			IF (sender = loadBtn) THEN
				filenameEditor.GetAsString(filename);
				LoadRepository(filename);
			ELSIF (sender = storeBtn) THEN
				filenameEditor.GetAsString(filename);
				Repositories.StoreRepository(filename, res);
				IF (res # Repositories.Ok) THEN
					SetStatusLabel("Could not store repository '", filename, "'");
					WMDialogs.Error("Error", "Could not store repository");
				ELSE
					SetStatusLabel("Repository '", filename, "' stored");
				END;
			ELSIF (sender = unloadBtn) THEN
				filenameEditor.GetAsString(filename);
				Repositories.UnloadRepository(filename, res);
				IF (res # Repositories.Ok) THEN
					SetStatusLabel("Could not unload repository '", filename, "'");
					WMDialogs.Error("Error", "Could not unload repository");
				ELSE
					SetStatusLabel("Repository '", filename, "' unloaded");
				END;
			END;
		END HandleButtons;

		PROCEDURE OnEnter(sender, data : ANY);
		VAR filename : ARRAY 256 OF CHAR;
		BEGIN
			filenameEditor.GetAsString(filename);
			LoadRepository(filename);
		END OnEnter;

		PROCEDURE GetSelectedComponent() : Repositories.Component;
		VAR component : Repositories.Component; string : Strings.String; id : LONGINT;
		BEGIN
			component := NIL;
			IF (selection # NIL) & (selection.repository # NIL) & (selection.element # NIL) THEN
				string := selection.element.GetAttributeValue("id");
				IF (string # NIL) THEN Strings.StrToInt(string^, id); ELSE id := 0; END;
				string := selection.element.GetAttributeValue("name");
				IF (string # NIL) THEN
					component := selection.repository.GetComponent(string^, id);
				END;
			END;
			RETURN component;
		END GetSelectedComponent;

		PROCEDURE OnRepositoriesClicked(sender, data : ANY);
		BEGIN
			IF (data # NIL) & (data IS Repositories.Repository) THEN
				repository.SetThisRepository(data(Repositories.Repository));
				filenameEditor.SetAsString(data(Repositories.Repository).name);
			END;
		END OnRepositoriesClicked;

		PROCEDURE OnComponentClicked(sender, data : ANY);
		BEGIN
			IF (data # NIL) & (data IS WMRepositories.EntryWrapper) & (data(WMRepositories.EntryWrapper).repository # NIL) THEN
				selection := data (WMRepositories.EntryWrapper);
			ELSE
				selection := NIL;
			END;
		END OnComponentClicked;

		PROCEDURE OnClickedSelected(sender, data : ANY);
		VAR command, msg : ARRAY 384 OF CHAR; res : LONGINT; string : Strings.String;
		BEGIN
			IF (data # NIL) & (data IS WMRepositories.EntryWrapper) THEN
				IF (data(WMRepositories.EntryWrapper).repository # NIL) & (data(WMRepositories.EntryWrapper).element # NIL) THEN
					string := data(WMRepositories.EntryWrapper).element.GetAttributeValue("source");
					IF (string # NIL) THEN
						command := "PET.Open ";
						Strings.Append(command, data(WMRepositories.EntryWrapper).repository.filename);
						Strings.Append(command, "://");
						Strings.Append(command, string^);
						Commands.Call(command, {}, res, msg);
						IF (res # Commands.Ok) THEN KernelLog.String(msg); END;
					END;
				END;
			END;
		END OnClickedSelected;

	END ComponentWindow;

TYPE

	TreeNode = OBJECT(WMTrees.TreeNode)
	VAR
		color, bgColor : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			color := 0FFH; bgColor := 0;
		END Init;

	END TreeNode;

TYPE

	(** Tree component that displays all window instances and their component hierarchies *)
	ComponentTree = OBJECT(WMComponents.VisualComponent)
	VAR
		refreshBtn : WMStandardComponents.Button;

		treeView : WMTrees.TreeView;
		tree : WMTrees.Tree;

		(* the two fields below are protected by the tree lock *)
		rootComponent : Repositories.Component;
		selection : Selection;

		insertAtObj : ANY;

		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignTop);
			refreshBtn.bounds.SetHeight(20);
			refreshBtn.caption.SetAOC("Refresh");
			refreshBtn.onClick.Add(Refresh);
			AddContent(refreshBtn);

			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treeView.SetDrawNodeProc(DrawNode);
			treeView.clSelected.Set(0);
			tree := treeView.GetTree();
			AddContent(treeView);

			rootComponent := NIL;
			selection := NIL; insertAtObj := NIL;
		END Init;

		PROCEDURE AddComponents(component : Repositories.Component; parent : WMTrees.TreeNode);
		VAR
			node : WMTrees.TreeNode;
			n : TreeNode;
			name : Strings.String;
			caption, value : ARRAY 256 OF CHAR;
			enum : XMLObjects.Enumerator;
			p : ANY;
		BEGIN
			IF ~((component IS WMComponents.Component) & (component(WMComponents.Component).internal)) THEN
				name := component.GetName();
				IF (name # NIL) THEN
					COPY(name^, caption);
				ELSE
					caption := "NoName";
				END;

				IF (component IS WMComponents.Component) THEN
					value := "";
					IF component(WMComponents.Component).properties.GetPropertyValue("caption", value) THEN
						Strings.Append(caption, " (");
						Strings.Append(caption, value);
						Strings.Append(caption, ")");
					END;
				END;

				NEW(n);
				tree.SetNodeCaption(n, Strings.NewString(caption));
				tree.SetNodeData(n, component);
				tree.AddChildNode(parent, n);
				tree.InclNodeState(n, WMTrees.NodeExpanded);
				tree.ExpandToRoot(n);
				node := n;
			ELSE
				node := parent;
			END;

			enum := component.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF (p IS Repositories.Component) THEN
					AddComponents(p(Repositories.Component), node);
				END;
			END;
		END AddComponents;

		PROCEDURE Refresh(sender, data : ANY);
		VAR root : WMTrees.TreeNode;
		BEGIN
			ASSERT(tree # NIL);
			tree.Acquire;

			NEW(root);
			tree.SetRoot(root);
			tree.SetNodeCaption(root, Strings.NewString("Root"));
			tree.InclNodeState(root, WMTrees.NodeExpanded);

			IF (rootComponent # NIL) THEN
				AddComponents(rootComponent, root);
			END;
			UpdateColors;
			tree.Release;
		END Refresh;

		PROCEDURE UpdateNodeColor(node : WMTrees.TreeNode);
		VAR ptr : ANY; n : TreeNode;
		BEGIN
			ASSERT(node # NIL);
			IF (node IS TreeNode) THEN
				n := node( TreeNode);
				ptr := tree.GetNodeData(node);
				IF (ptr # NIL) THEN
					IF (ptr IS Repositories.Component) & selection.Contains(ptr (Repositories.Component)) THEN
						n.color := ColorSelected;
						IF (ptr = insertAtObj) THEN n.bgColor := 0FF60H; ELSE n.bgColor := 0; END;
					ELSIF (ptr IS Repositories.Component) & ptr(Repositories.Component).IsLocked() THEN
						n.color := ColorLocked;
					ELSIF (ptr = insertAtObj) THEN
						n.color := WMGraphics.White; n.bgColor := 0FF60H;
					ELSE
						n.color := WMGraphics.Black; n.bgColor := 0;
					END;
				ELSE
					n.color := WMGraphics.Black; n.bgColor := 0;
				END;
			END;
		END UpdateNodeColor;

		PROCEDURE TraverseNodes(parent : WMTrees.TreeNode);
		VAR n : WMTrees.TreeNode;
		BEGIN
			ASSERT(parent # NIL);
			UpdateNodeColor(parent);
			n := tree.GetChildren(parent);
			WHILE (n # NIL) DO
				TraverseNodes(n);
				n := tree.GetNextSibling(n);
			END;
		END TraverseNodes;

		PROCEDURE UpdateColors;
		VAR root : WMTrees.TreeNode;
		BEGIN
			tree.Acquire;
			root := tree.GetRoot();
			TraverseNodes(root);
			tree.Release;
			Invalidate;
		END UpdateColors;

		PROCEDURE DrawNode(canvas: WMGraphics.Canvas; w, h: LONGINT; node: WMTrees.TreeNode; state: SET);
		VAR
			dx, tdx, tdy, bgColor : LONGINT; f : WMGraphics.Font; image : WMGraphics.Image;
			caption: Strings.String;
		BEGIN
			dx := 0;
			f := treeView.GetFont();

			image := tree.GetNodeImage(node);
			IF image # NIL THEN
				canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst); dx := image.width + 5;
			END;

			IF (node IS TreeNode) THEN
				IF (node(TreeNode).color # 0) THEN
					canvas.SetColor(node(TreeNode).color);
				ELSE
					canvas.SetColor(treeView.clTextDefault.Get());
				END;
				bgColor := node(TreeNode).bgColor;
			ELSE
				canvas.SetColor(treeView.clTextDefault.Get());
				bgColor := 0;
			END;

			caption := tree.GetNodeCaption(node);
			f.GetStringSize(caption^, tdx, tdy);

			IF (bgColor # 0) THEN
				canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), bgColor, WMGraphics.ModeSrcOverDst)
			END;

			IF WMTrees.StateSelected IN state THEN
				canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clSelected.Get(), WMGraphics.ModeSrcOverDst)
			ELSIF WMTrees.StateHover IN state THEN
				canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clHover.Get(), WMGraphics.ModeSrcOverDst)
			END;
			IF caption # NIL THEN canvas.DrawString(dx, h - f.descent - 1 , caption^); END;
		END DrawNode;

		PROCEDURE SetComponent(rootComponent : Repositories.Component; selection : Selection);
		BEGIN
			tree.Acquire;
			SELF.rootComponent := rootComponent;
			SELF.selection := selection;
			tree.Release;
			Refresh(NIL, NIL);
			Invalidate;
		END SetComponent;

		PROCEDURE SetInsertAtObj(insertAtObj : ANY);
		BEGIN
			IF (SELF.insertAtObj # insertAtObj) THEN
				SELF.insertAtObj := insertAtObj;
				UpdateColors;
			END;
		END SetInsertAtObj;

	END ComponentTree;

TYPE

	Indicator = OBJECT(WMStandardComponents.Panel)
	VAR
		value : ARRAY 128 OF CHAR;
		textColor : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			value := "";
			textColor := 0;
		END Init;

		PROCEDURE SetCaption(CONST x : ARRAY OF CHAR);
		BEGIN
			Acquire; COPY(x, value); Release;
			Invalidate;
		END SetCaption;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			canvas.SetColor(textColor);
			Acquire;
			WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMComponents.AlignNone, WMGraphics.AlignCenter, value);
			Release;
		END DrawBackground;
	END Indicator;


TYPE

	PropertyWindow = OBJECT(WMComponents.FormWindow)
	VAR
		propertyPanel : WMInspectionComponents.PropertyPanel;

		PROCEDURE &Init(width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			Init^(width, height, alpha);

			NEW(propertyPanel); propertyPanel.alignment.Set(WMComponents.AlignClient);
			propertyPanel.fillColor.Set(WMGraphics.White);
			SetContent(propertyPanel);
			SetTitle(Strings.NewString("Component Properties"));
		END Init;

		PROCEDURE SetComponent(sender, component : ANY);
		BEGIN
			propertyPanel.SetComponent(SELF, component);
		END SetComponent;

	END PropertyWindow;

TYPE
	ComponentArray = POINTER TO ARRAY OF Repositories.Component;
	BufferArray = POINTER TO ARRAY OF Strings.String;

	Clipboard = OBJECT
	VAR
		nofComponents : LONGINT;
		buffers : BufferArray;

		PROCEDURE &Init;
		VAR i : LONGINT;
		BEGIN
			nofComponents := 0;
			NEW(buffers, 32);
			FOR i := 0 TO LEN(buffers) - 1 DO buffers[i] := NIL; END;
		END Init;

		PROCEDURE Put(components : ComponentArray);
		VAR buf : Strings.Buffer; writer : Streams.Writer; i : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(components # NIL);
			Clear;
			i := 0;
			WHILE (i < LEN(components)) DO
				IF (components[i] # NIL) THEN
					INC(nofComponents);
					IF (i >= LEN(buffers)) THEN Resize; END;
					NEW(buf, 1024);
					writer := buf.GetWriter();
					components[i].Write(writer, NIL,0);
					writer.Update;
					buffers[i] := buf.GetString();
				END;
				INC(i);
			END;
		END Put;

		PROCEDURE Get() : ComponentArray;
		VAR components : ComponentArray; content : XML.Content; i : LONGINT;
		BEGIN {EXCLUSIVE}
			components := NIL;
			IF (nofComponents > 0) THEN
				NEW(components, nofComponents);
				i := 0;
				WHILE (i < LEN(buffers)) DO
					IF (buffers[i] # NIL) THEN
						content := LoadContent(buffers[i]);
						IF (content # NIL) & (content IS Repositories.Component) THEN
							components[i] := content (Repositories.Component);
						ELSE
							components[i] := NIL;
						END;
					END;
					INC(i);
				END;
			END;
			RETURN components;
		END Get;

		PROCEDURE LoadContent(buffer : Strings.String) : XML.Content;
		VAR content : XML.Content; parser : Parser; document : XML.Document; reader : Streams.StringReader;
		BEGIN
			content := NIL;
			IF (buffer # NIL) THEN
				NEW(reader, LEN(buffer)); reader.Set(buffer^);
				NEW(parser);
				IF parser.Parse(reader, document) THEN
					content := document.GetRoot();
				END;
			END;
			RETURN content;
		END LoadContent;

		PROCEDURE Clear;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(buffers) - 1 DO buffers[i] := NIL; END;
		END Clear;

		PROCEDURE Resize;
		VAR newBuffers : BufferArray; i : LONGINT;
		BEGIN
			NEW(newBuffers, 2 * LEN(buffers));
			FOR i := 0 TO LEN(buffers) - 1 DO newBuffers[i] := buffers[i]; END;
			WHILE (i < LEN(newBuffers)) DO newBuffers[i] := NIL; INC(i); END;
			buffers := newBuffers;
		END Resize;

	END Clipboard;

TYPE

	Parser = OBJECT
	VAR
		hasError : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			hasError := FALSE;
		END Init;

		PROCEDURE ReportError(pos, line, col: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			hasError := TRUE;
			KernelLog.String("WMBuilder.Clipboard.Parser.Parse: line = "); KernelLog.Int(line, 0);
			KernelLog.String(", col = "); KernelLog.Int(col, 0); KernelLog.String(", pos = "); KernelLog.Int(pos, 0);
			KernelLog.String(": "); KernelLog.String(msg); KernelLog.Ln;
		END ReportError;

		PROCEDURE Parse(reader : Streams.Reader; VAR document : XML.Document) : BOOLEAN;
		VAR scanner : XMLScanner.Scanner; parser : XMLParser.Parser;
		BEGIN
			ASSERT(reader # NIL);
			NEW(scanner, reader);
			NEW(parser, scanner);
			parser.reportError := ReportError;
			parser.elemReg := Repositories.registry;
			document := parser.Parse();
			RETURN ~hasError;
		END Parse;

	END Parser;

TYPE

	ComponentInfo = RECORD
		originX, originY : LONGINT;
	END;

	SnapGrid = OBJECT
	VAR
		offsetX, offsetY : LONGINT;
		deltaX, deltaY : LONGINT;
		nX, nY : LONGINT;

		PROCEDURE &Init;
		BEGIN
			offsetX := 0; offsetY := 0;
			deltaX := 5; deltaY := 5;
			nX := 8; nY := 4;
		END Init;

		PROCEDURE Snap(x, y : LONGINT; VAR snapX, snapY : LONGINT);
		VAR r : REAL; f : LONGINT;
		BEGIN
			x := x - offsetX;
			y := y - offsetY;
			r := (x / deltaX);
			f := ENTIER(r);
			IF (r - f <= 0.5) THEN snapX := offsetX +  f * deltaX;
			ELSIF (r - f > 0.5) THEN snapX := offsetX + (f + 1) * deltaX;
			END;
			r := (y / deltaY);
			f := ENTIER(r);
			IF (r - f <= 0.5) THEN snapY := offsetY + f * deltaY;
			ELSIF (r - f > 0.5) THEN snapY := offsetY + (f + 1) * deltaY;
			END;
		END Snap;

	END SnapGrid;

	Frame = OBJECT
	VAR
		bounds : WMRectangles.Rectangle;
		activeHandles : SET;
		clLine0, clLine1, clActiveHandles, clInactiveHandles : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Clear;
			SetFrameType(Frame_Selection);
		END Init;

		PROCEDURE GetWidth() : LONGINT;
		BEGIN
			RETURN bounds.r - bounds.l;
		END GetWidth;

		PROCEDURE GetHeight() : LONGINT;
		BEGIN
			RETURN bounds.b - bounds.t
		END GetHeight;

		PROCEDURE IsValid() : BOOLEAN;
		BEGIN
			RETURN (bounds.l # 0) OR (bounds.t # 0) OR (bounds.r # 0) OR (bounds.b # 0);
		END IsValid;

		PROCEDURE SetFrameType(type : LONGINT);
		BEGIN
			CASE type OF
				|Frame_Selection:
					clLine0 := WMGraphics.Black;
					clLine1 := WMGraphics.Green;
					clActiveHandles := WMGraphics.Green;
					clInactiveHandles := WMGraphics.Black;
				|Frame_Selection_InsertAt:
					clLine0 := WMGraphics.Black;
					clLine1 := WMGraphics.Blue;
					clActiveHandles := WMGraphics.Blue;
					clInactiveHandles := WMGraphics.Black;
			ELSE
			END;
		END SetFrameType;

		PROCEDURE Clear;
		BEGIN
			bounds := WMRectangles.MakeRect(0, 0, 0, 0);
			activeHandles := {};
		END Clear;

		PROCEDURE SetActiveHandlesFor(alignment : LONGINT);
		BEGIN
			CASE alignment OF
				|WMComponents.AlignNone: activeHandles := {0..31};
				|WMComponents.AlignLeft: activeHandles := {Right};
				|WMComponents.AlignRight: activeHandles := {Left};
				|WMComponents.AlignTop: activeHandles := {Bottom};
				|WMComponents.AlignBottom: activeHandles := {Top};
				|WMComponents.AlignClient: activeHandles := {};
			ELSE
				activeHandles := {0..31};
			END;
		END SetActiveHandlesFor;

		PROCEDURE SetActiveHandles(activeHandles : SET);
		BEGIN
			SELF.activeHandles := activeHandles;
		END SetActiveHandles;

		PROCEDURE FixBounds;
		BEGIN
			bounds := WMRectangles.MakeRect(
				Strings.Min(bounds.l, bounds.r),
				Strings.Min(bounds.t, bounds.b),
				Strings.Max(bounds.l, bounds.r),
				Strings.Max(bounds.t, bounds.b)
			);
		END FixBounds;

		PROCEDURE IsInActiveFrameHandle(x, y : LONGINT) : LONGINT;
		VAR res : LONGINT;
		BEGIN
			res := IsInFrameHandle(x, y);
			IF (res # No) & ~(res IN activeHandles) THEN
				res := No;
			END;
			RETURN res;
		END IsInActiveFrameHandle;

		PROCEDURE IsInFrameHandle(x, y : LONGINT): LONGINT;
		VAR xs, ys, xe, ye, res : LONGINT;
		BEGIN
			IF IsValid() THEN
				xs := bounds.l; ys := bounds.t; xe := bounds.r; ye := bounds.b;
				IF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ENTIER((ys+ye)/2)-2, xs+1, ENTIER((ys+ye)/2)+2)) THEN
					res := Left;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ys-4, xs+1, ys+1)) THEN
					res := TopLeft;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ys-4, ENTIER((xs+xe)/2)+3, ys+1)) THEN
					res := Top;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ys-4, xe+5, ys+1)) THEN
					res := TopRight;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ENTIER((ys+ye)/2)-2, xe+5, ENTIER((ys+ye)/2)+2)) THEN
					res := Right;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xe, ye, xe+5, ye+5)) THEN
					res := BottomRight;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ye, ENTIER((xs+xe)/2)+3, ye+5)) THEN
					res := Bottom;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs-4, ye, xs+1, ye+5)) THEN
					res := BottomLeft;
				ELSIF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(xs+1, ys+1, xe-1, ye-1)) THEN
					res := Inside;
				ELSE
					res := No;
				END;
			ELSE
				res := No;
			END;
			RETURN res;
		END IsInFrameHandle;

		PROCEDURE DrawFrameHandles(canvas: WMGraphics.Canvas; xs, ys, xe, ye , activeColor, inactiveColor : LONGINT; active : SET);
		VAR color : LONGINT;
		BEGIN
			IF (TopLeft IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xs-4, ys-4, xs+1, ys+1), color, WMGraphics.ModeSrcOverDst);

			IF (TopRight IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xe, ys-4, xe+5, ys+1), color, WMGraphics.ModeSrcOverDst);

			IF (BottomLeft IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xs-4, ye, xs+1, ye+5), color, WMGraphics.ModeSrcOverDst);

			IF (BottomRight IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xe, ye, xe+5, ye+5), color, WMGraphics.ModeSrcOverDst);

			IF (Left IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xs-4, ENTIER((ys+ye)/2)-2, xs+1, ENTIER((ys+ye)/2)+2), color, WMGraphics.ModeSrcOverDst);

			IF (Top IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ys-4, ENTIER((xs+xe)/2)+3, ys+1), color, WMGraphics.ModeSrcOverDst);

			IF (Right IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(xe, ENTIER((ys+ye)/2)-2, xe+5, ENTIER((ys+ye)/2)+2), color, WMGraphics.ModeSrcOverDst);

			IF (Bottom IN active) THEN color := activeColor; ELSE color := inactiveColor; END;
			canvas.Fill(WMRectangles.MakeRect(ENTIER((xs+xe)/2)-1, ye, ENTIER((xs+xe)/2)+3, ye+5), color, WMGraphics.ModeSrcOverDst);
		END DrawFrameHandles;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		BEGIN
			IF IsValid() THEN
				DrawDashedRectangle(canvas, bounds.l, bounds.t, bounds.r, bounds.b, clLine0, clLine1, 4, 2);
				IF (activeHandles # {}) THEN
					DrawFrameHandles(canvas, bounds.l, bounds.t, bounds.r, bounds.b, clActiveHandles, clInactiveHandles, activeHandles);
				END;
			END;
		END Draw;

	END Frame;

TYPE
	RectangleReal = RECORD
		l, t, b, r : REAL;
	END;

	BoundsArray = POINTER TO ARRAY OF RectangleReal;

	Selection = OBJECT (** not thread-safe!*)
	VAR
		frame : WMRectangles.Rectangle;
		activeFrameHandles : SET;

		root : WMComponents.VisualComponent;

		parent : XML.Element;

		nofComponents : LONGINT;
		components : ComponentArray;

		bounds : BoundsArray;

		PROCEDURE &Init(root : WMComponents.VisualComponent);
		BEGIN
			ASSERT(root # NIL);
			SELF.root := root;
			parent := NIL;
			activeFrameHandles := {};
			NEW(components, 32);
			Clear;
			bounds := NIL;
		END Init;

		PROCEDURE NofComponents() : LONGINT;
		BEGIN
			RETURN nofComponents;
		END NofComponents;

		PROCEDURE NofVisualComponents() : LONGINT;
		VAR nofVisualComponents, i : LONGINT;
		BEGIN
			nofVisualComponents := 0;
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] IS WMComponents.VisualComponent) THEN
					INC(nofVisualComponents);
				END;
			END;
			RETURN nofVisualComponents;
		END NofVisualComponents;

		PROCEDURE NofLockedComponents() : LONGINT;
		VAR nofLockedComponents, i : LONGINT;
		BEGIN
			nofLockedComponents := 0;
			FOR i := 0 TO nofComponents - 1 DO
				IF components[i].IsLocked() THEN INC(nofLockedComponents); END;
			END;
			RETURN nofLockedComponents;
		END NofLockedComponents;

		PROCEDURE GetParent() : XML.Element;
		BEGIN
			RETURN parent;
		END GetParent;

		PROCEDURE Contains(component : Repositories.Component) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofComponents) & (components[i] # component) DO INC(i); END;
			RETURN (i < nofComponents);
		END Contains;

		PROCEDURE GetFirst() : Repositories.Component;
		VAR component : Repositories.Component;
		BEGIN
			IF (nofComponents > 0) THEN
				component := components[0];
			ELSE
				component := NIL;
			END;
			RETURN component;
		END GetFirst;

		PROCEDURE ModificationsAllowed() : BOOLEAN;
		BEGIN
			RETURN NofLockedComponents() = 0;
		END ModificationsAllowed;

		PROCEDURE Delete;
		VAR parent : XML.Element; i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # root) THEN
					parent := components[i].GetParent();
					parent.RemoveContent(components[i]);
				END;
			END;
			Reset;
		END Delete;

		PROCEDURE ToFront;
		VAR parent : XML.Element; i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # root) THEN
					parent := components[i].GetParent();
					parent.RemoveContent(components[i]);
					parent.AddContent(components[i]);
				END;
			END;
		END ToFront;

		PROCEDURE SetExtents(width, height : LONGINT);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] IS WMComponents.VisualComponent) THEN
					components[i](WMComponents.VisualComponent).bounds.SetExtents(width, height);
				END;
			END;
		END SetExtents;

		PROCEDURE SetLimit(rect : WMRectangles.Rectangle; mode : LONGINT);
		VAR bounds : WMRectangles.Rectangle; dx, dy, i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # NIL) & (components[i] IS WMComponents.VisualComponent) THEN
					dx := 0; dy := 0;
					bounds := components[i](WMComponents.VisualComponent).bounds.Get();
					CASE mode OF
						|No: (* ignore *)
						|Left: dx := rect.l - bounds.l
						|TopLeft: dx := rect.l - bounds.l; dy := rect.t - bounds.t;
						|Top: dy := rect.t - bounds.t;
						|TopRight: dy := rect.t - bounds.t; dx := rect.r - bounds.r;
						|Right: dx := rect.r - bounds.r;
						|BottomRight: dy := rect.b - bounds.b; dx := rect.r - bounds.r;
						|Bottom: dy := rect.b - bounds.b;
						|BottomLeft: dy := rect.b - bounds.b; dx := rect.l - bounds.l;
						|Inside:
					ELSE
					END;
					WMRectangles.MoveRel(bounds, dx, dy);
					components[i](WMComponents.VisualComponent).bounds.Set(bounds);
				END;
			END;
		END SetLimit;

		PROCEDURE MoveRelative(dx, dy : LONGINT);
		VAR bounds : WMRectangles.Rectangle; i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # NIL) & (components[i] IS WMComponents.VisualComponent) THEN
					bounds := components[i](WMComponents.VisualComponent).bounds.Get();
					WMRectangles.MoveRel(bounds, dx, dy);
					components[i](WMComponents.VisualComponent).bounds.Set(bounds);
				END;
			END;
		END MoveRelative;

		PROCEDURE InitResize(x0, y0, width0, height0 : LONGINT);
		VAR i : LONGINT; r, temp : WMRectangles.Rectangle;
		BEGIN
			IF (bounds = NIL) OR (LEN(bounds) < nofComponents) THEN NEW(bounds, nofComponents); END;
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] IS WMComponents.VisualComponent) THEN
					temp.l := x0; temp.t := y0;
					ToComponentCoordinates(components[i](WMComponents.VisualComponent), temp);
					r := components[i](WMComponents.VisualComponent).bounds.Get();
					bounds[i].l := (r.l - temp.l) / width0;
					bounds[i].t := (r.t - temp.t) / height0;
					bounds[i].r := (r.r - temp.l) / width0;
					bounds[i].b := (r.b - temp.t) / height0;
				END;
			END;
		END InitResize;

		PROCEDURE ResizeProportional(x, y, width, height : LONGINT; snapX, snapY : LONGINT);
		VAR r, temp : WMRectangles.Rectangle; i : LONGINT;

			PROCEDURE Snap(r : WMRectangles.Rectangle; snapX, snapY : LONGINT);
			BEGIN

			END Snap;

		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # NIL) & (components[i] IS WMComponents.VisualComponent) THEN
					temp.l := x; temp.t := y;
					ToComponentCoordinates(components[i](WMComponents.VisualComponent), temp);
					r.l := temp.l + ENTIER(bounds[i].l * width);
					r.t := temp.t + ENTIER(bounds[i].t * height);
					r.r := temp.l + ENTIER(bounds[i].r * width);
					r.b := temp.t + ENTIER(bounds[i].b * height);
					IF (snapX # Invalid) & (snapY # Invalid) THEN
						Snap(r, snapX, snapY);
					END;
					components[i](WMComponents.VisualComponent).bounds.Set(r);
				END;
			END;
		END ResizeProportional;

		PROCEDURE Resize(mode : LONGINT; dx, dy : LONGINT);
		VAR bounds : WMRectangles.Rectangle; i : LONGINT;
		BEGIN
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] # NIL) & (components[i] IS WMComponents.VisualComponent) THEN
					bounds := components[i](WMComponents.VisualComponent).bounds.Get();
					IF (mode = TopLeft) OR (mode = Left) OR  (mode = BottomLeft) THEN
						bounds.l := bounds.l + dx;
					END;
					IF (mode = TopLeft) OR (mode = Top) OR (mode = TopRight) THEN
						bounds.t := bounds.t + dy;
					END;
					IF (mode = TopRight) OR (mode = Right) OR (mode = BottomRight) THEN
						bounds.r := bounds.r + dx;
					END;
					IF (mode = BottomLeft) OR (mode = Bottom) OR (mode = BottomRight) THEN
						bounds.b := bounds.b + dy;
					END;
					components[i](WMComponents.VisualComponent).bounds.Set(bounds);
				END;
			END;
		END Resize;

		PROCEDURE Get() : ComponentArray;
		VAR components : ComponentArray; i : LONGINT;
		BEGIN
			IF (nofComponents > 0) THEN
				NEW(components, nofComponents);
				FOR i := 0 TO nofComponents - 1 DO
					components[i] := SELF.components[i];
				END;
			ELSE
				components := NIL;
			END;
			RETURN components;
		END Get;

		PROCEDURE Set(component : Repositories.Component);
		BEGIN
			Reset;
			IF (component # NIL) THEN
				Add(component);
				IF (component IS WMComponents.Component) THEN parent := component.GetParent(); END;
			END;
		END Set;

		PROCEDURE Determine(rect : WMRectangles.Rectangle);
		VAR enum : XMLObjects.Enumerator; p : ANY; vc : WMComponents.VisualComponent; r : WMRectangles.Rectangle; valid : BOOLEAN;
		BEGIN
			IF (nofComponents = 0) THEN
				vc := FindVisualComponentInRectangle(root, rect);
				IF (vc # NIL) THEN
					parent := vc.GetParent();
				END;
			END;
			Clear;
			IF (parent # NIL) & (parent IS WMComponents.Component) THEN
				enum := parent.GetContents(); enum.Reset;
				WHILE enum.HasMoreElements() DO
					p := enum.GetNext();
					IF (p IS WMComponents.VisualComponent) THEN
						vc := p (WMComponents.VisualComponent);
						IF (vc # parent) & (parent = vc.GetParent()) THEN
							r := vc.bounds.Get();
							ToEditorCoordinates(vc, r);
							IF WMRectangles.IsContained(rect, r) & ~vc.internal THEN
								Add(vc);
							END;
						END;
					END;
				END;
			END;
			valid := nofComponents > 0;
			IF valid THEN
				GetBoundingBox(frame, activeFrameHandles);
			ELSE
				parent := NIL;
			END;
		END Determine;

		(* Find an element that rect in parent coordinate system *)
		PROCEDURE FindVisualComponentInRectangle(parent : XML.Element; rect : WMRectangles.Rectangle) : WMComponents.VisualComponent;
		VAR enum : XMLObjects.Enumerator; p : ANY; vc : WMComponents.VisualComponent; r, rP : WMRectangles.Rectangle;
		BEGIN
			ASSERT(parent # NIL);
			vc := NIL;
			enum := parent.GetContents(); enum.Reset;
			WHILE (vc = NIL) & enum.HasMoreElements() DO
				p := enum.GetNext();
				IF (p IS WMComponents.VisualComponent) THEN
					vc := p (WMComponents.VisualComponent);
					r := vc.bounds.Get();
					IF WMRectangles.IsContained(rect, r) & ~vc.internal THEN
						(* found *)
					ELSE
						rP := rect;
						WMRectangles.MoveRel(rP, -r.l, -r.t);
						vc := FindVisualComponentInRectangle(vc, rP);
					END;
				END;
			END;
			RETURN vc;
		END FindVisualComponentInRectangle;

		PROCEDURE GetBoundingBox(VAR rect : WMRectangles.Rectangle; VAR active : SET);
		VAR bounds : WMRectangles.Rectangle; alignment, i : LONGINT;
		BEGIN
			rect := WMRectangles.MakeRect(0, 0, 0, 0); active := {0..31};
			FOR i := 0 TO nofComponents - 1 DO
				IF (components[i] IS WMComponents.VisualComponent) THEN
					IF (rect.l # 0) OR (rect.t # 0) OR (rect.r # 0) OR (rect.b # 0) THEN
						bounds := components[i](WMComponents.VisualComponent).bounds.Get();
						ToEditorCoordinates(components[i](WMComponents.VisualComponent), bounds);
						rect.l := Strings.Min(rect.l, bounds.l);
						rect.t := Strings.Min(rect.t, bounds.t);
						rect.r := Strings.Max(rect.r, bounds.r);
						rect.b := Strings.Max(rect.b, bounds.b);
					ELSE
						rect := components[i](WMComponents.VisualComponent).bounds.Get();
						ToEditorCoordinates(components[i](WMComponents.VisualComponent), rect);
					END;
					alignment := components[i](WMComponents.VisualComponent).alignment.Get();
					CASE alignment OF
						|WMComponents.AlignNone: (* do nothing *)
						|WMComponents.AlignLeft: active := active * {Right};
						|WMComponents.AlignTop: active := active * {Bottom};
						|WMComponents.AlignRight : active := active * {Left};
						|WMComponents.AlignBottom: active := active * {Top};
						|WMComponents.AlignClient: active := {};
					ELSE
					END;
				END;
			END;
			IF ~ModificationsAllowed() THEN active := {}; END;
		END GetBoundingBox;

		(** Get bounds of component in ComponentEditor coordinates *)
		PROCEDURE ToEditorCoordinates(component : WMComponents.Component; VAR rect : WMRectangles.Rectangle);
		VAR c : XML.Element; bounds : WMRectangles.Rectangle;
		BEGIN
			ASSERT(component # NIL);
			c := component.GetParent();
			WHILE (c # NIL) & (c IS WMComponents.VisualComponent) & (c # root)  DO
				bounds := c(WMComponents.VisualComponent).bounds.Get();
				WMRectangles.MoveRel(rect, bounds.l, bounds.t);
				c := c.GetParent();
			END;
		END ToEditorCoordinates;

		PROCEDURE ToComponentCoordinates(component : WMComponents.Component; VAR rect : WMRectangles.Rectangle);
		VAR c : XML.Element; bounds : WMRectangles.Rectangle;
		BEGIN
			ASSERT(component # NIL);
			IF (c # root) THEN
				c := component.GetParent();
				WHILE (c # NIL) & (c IS WMComponents.VisualComponent) & (c # root)  DO
					bounds := c(WMComponents.VisualComponent).bounds.Get();
					WMRectangles.MoveRel(rect, -bounds.l, -bounds.t);
					c := c.GetParent();
				END;
			END;
		END ToComponentCoordinates;

		PROCEDURE CanAdd(component : Repositories.Component) : BOOLEAN;
		BEGIN
			ASSERT(component # NIL);
			RETURN (parent = NIL) OR (component.GetParent() = parent);
		END CanAdd;

		PROCEDURE Add(component : Repositories.Component);
		BEGIN
			ASSERT((component # NIL) & (~Contains(component)));
			IF (nofComponents >= LEN(components)) THEN ResizeComponentsArray; END;
			components[nofComponents] := component;
			INC(nofComponents);
		END Add;

		PROCEDURE Remove(component : Repositories.Component);
		VAR i, j, nofRemoved : LONGINT;
		BEGIN
			ASSERT(component # NIL);
			nofRemoved := 0;
			i := 0; j := 0;
			WHILE (i < nofComponents) DO
				IF (components[i] # component) THEN
					components[j] := components[i];
					INC(j);
				ELSE
					INC(nofRemoved);
				END;
				INC(i);
			END;
			nofComponents := nofComponents - nofRemoved;
		END Remove;

		PROCEDURE Clear;
		VAR i : LONGINT;
		BEGIN
			nofComponents := 0;
			FOR i := 0 TO LEN(components)-1 DO
				components[i] := NIL;
			END;
		END Clear;

		PROCEDURE Reset;
		BEGIN
			Clear;
			parent := NIL;
		END Reset;

		PROCEDURE ResizeComponentsArray;
		VAR newComponents : ComponentArray; i : LONGINT;
		BEGIN
			NEW(newComponents, 2 * LEN(components));
			FOR i := 0 TO LEN(components)-1 DO
				newComponents[i] := components[i];
			END;
			components := newComponents;
		END ResizeComponentsArray;

	END Selection;

TYPE

	ComponentEditor = OBJECT(WMComponents.VisualComponent)
	VAR
		panel : WMComponents.VisualComponent;
		mode : LONGINT;

		selection : Selection;
		selectionFrame : Frame;

		frame, dragFrame : Frame;

		limitMode : LONGINT;

		insertObjAt : WMComponents.VisualComponent;

		downX, downY, lastX, lastY, dragX, dragY : LONGINT;
		oldPointerInfo: LONGINT;
		selectInsertObjAt : BOOLEAN;

		showSnapGrid : WMProperties.BooleanProperty;
		showSnapGridI : BOOLEAN;

		enableSnap : WMProperties.BooleanProperty;
		enableSnapI : BOOLEAN;

		showHelperLines : WMProperties.BooleanProperty;
		showHelperLinesI : BOOLEAN;

		showFrames : WMProperties.BooleanProperty;
		showFramesI : BOOLEAN;

		snapgrid : SnapGrid;

		owner : MainWindow;
		manager : WMWindowManager.WindowManager;

		pointerMode : LONGINT;

		frameResizeOrigin : WMRectangles.Rectangle;
		frameResizeMode : LONGINT;

		modifierFlags, mouseKeys : SET;

		clipboard : Clipboard;

		paint : BOOLEAN;

		state : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrComponentEditor);
			(*SetGenerator("WMBuilder.GenComponentEditor");*)

			mode := EditMode;
			SetExtGetPositionOwnerHandler(ExtGetPositionOwnerHandler);

			takesFocus.Set(TRUE);
			needsTab.Set(TRUE);

			NEW(showSnapGrid, NIL, Strings.NewString("SnapGrid"), NIL); properties.Add(showSnapGrid);
			showSnapGrid.Set(TRUE);
			showSnapGridI := showSnapGrid.Get();

			NEW(enableSnap, NIL, Strings.NewString("Snap"), NIL); properties.Add(enableSnap);
			enableSnap.Set(TRUE);
			enableSnapI := enableSnap.Get();

			NEW(showHelperLines, NIL, Strings.NewString("HelperLines"), NIL); properties.Add(showHelperLines);
			showHelperLines.Set(TRUE);
			showHelperLinesI := showHelperLines.Get();

			NEW(showFrames, NIL, Strings.NewString("Frames"), NIL); properties.Add(showFrames);
			showFrames.Set(TRUE);
			showFramesI := showFrames.Get();

			NEW(snapgrid);

			NEW(panel);
			panel.SetName("VisualComponent");
			panel.alignment.Set(WMComponents.AlignClient);
			panel.takesFocus.Set(FALSE);
			AddContent(panel);

			NEW(selection, panel);
			NEW(selectionFrame);
			NEW(frame);
			NEW(dragFrame);

			SelectInsertAtObj(panel);

			downX := Invalid; downY := Invalid;
			lastX := Invalid; lastY := Invalid;

			oldPointerInfo := No;
			selectInsertObjAt := FALSE;
			limitMode := No;

			modifierFlags := {};

			manager := WMWindowManager.GetDefaultManager();
			pointerMode := None;
			NEW(clipboard);
			paint := FALSE;
			state := State_Running;
			NEW(timer);
		END Init;

		PROCEDURE SetPanel(panel : WMComponents.VisualComponent);
		BEGIN
			ASSERT(panel # NIL);
			IF (SELF.panel # NIL) THEN RemoveContent(SELF.panel); END;
			SELF.panel := panel;
			NEW(selection, panel);
			AddContent(panel);
			SelectInsertAtObj(panel);
			panel.Reset(NIL, NIL);
			Reset(NIL, NIL);
			Invalidate;
		END SetPanel;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = showSnapGrid) OR (property = enableSnap) OR (property = showHelperLines) OR (property = showFrames) THEN
				RecacheProperties;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			showSnapGridI := showSnapGrid.Get();
			enableSnapI := enableSnap.Get();
			showHelperLinesI := showHelperLines.Get();
			showFramesI := showFrames.Get();
			Invalidate;
		END RecacheProperties;

		PROCEDURE SetPaint(paint : BOOLEAN);
		BEGIN
			SELF.paint := paint;
		END SetPaint;

		PROCEDURE SetMode(mode : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT((mode = UseMode) OR (mode = EditMode));
			IF (mode = UseMode) THEN
				SetExtGetPositionOwnerHandler(NIL);
			ELSE
				SetExtGetPositionOwnerHandler(ExtGetPositionOwnerHandler);
			END;
			panel.SetFocus;
			SELF.mode := mode;
			UpdateFramePosition;
			Invalidate;
		END SetMode;

		PROCEDURE GetMode() : LONGINT;
		BEGIN
			RETURN mode;
		END GetMode;

		PROCEDURE ExtGetPositionOwnerHandler(x, y : LONGINT; VAR pointerOwner : WMComponents.VisualComponent; VAR handled : BOOLEAN);
		BEGIN
			(* let editpanel handle all messages *)
			pointerOwner := SELF; handled := TRUE;
		END ExtGetPositionOwnerHandler;

		PROCEDURE Delete;
		BEGIN
			IF selection.ModificationsAllowed() THEN
				IF selection.Contains(insertObjAt) THEN
					SelectInsertAtObj(panel);
				END;
				selection.Delete;
				selectionFrame.Clear;
				UpdateFramePosition;
				panel.Invalidate;
				IF (owner # NIL) THEN
					IF (owner.componentTree # NIL) THEN owner.componentTree.Refresh(NIL, NIL); END;
					IF (owner.propertyWindow # NIL) THEN owner.propertyWindow.SetComponent(SELF, NIL); END;
				END;
			END;
		END Delete;

		PROCEDURE ToFront;
		BEGIN
			IF selection.ModificationsAllowed() THEN
				selection.ToFront;
				UpdateFramePosition;
				panel.Invalidate;
				IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.Refresh(NIL, NIL); END;
			END;
		END ToFront;

		PROCEDURE AddComponent(c :Repositories.Component; x, y : LONGINT);
		VAR vc : WMComponents.VisualComponent; bounds : WMRectangles.Rectangle;
		BEGIN
			ASSERT(c # NIL);
			ASSERT(insertObjAt # NIL);
			IF c IS Models.Model THEN HALT(100) END;
			IF (c IS WMComponents.VisualComponent) THEN
				vc := c (WMComponents.VisualComponent);
				vc.alignment.Set(WMComponents.AlignNone);
				IF (vc.bounds.GetWidth() < 10) OR (vc.bounds.GetHeight() < 10) THEN
					vc.bounds.SetExtents(40, 20);
				END;
				bounds := vc.bounds.Get();
				WMRectangles.MoveRel(bounds, x, y);
				vc.bounds.Set(bounds);
				LabelComponent(vc);
				insertObjAt.AddContent(vc);
				vc.Reset(NIL, NIL);
				insertObjAt.Invalidate;
				panel.Invalidate;
				Select(vc);
			ELSE
				insertObjAt.AddContent(c);
			END;
			IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.Refresh(NIL, NIL); END;
		END AddComponent;

		PROCEDURE Select(c : Repositories.Component);
		VAR ci : ComponentInfo; vc : WMComponents.VisualComponent; alignment : LONGINT; bounds : WMRectangles.Rectangle;
		BEGIN
			selection.Reset;
			IF (c # NIL) THEN selection.Set(c); END;
			IF (c # NIL) & (c IS WMComponents.VisualComponent) THEN
				vc := c(WMComponents.VisualComponent);
				bounds := vc.bounds.Get();
				alignment := vc.alignment.Get();
				selectionFrame.SetFrameType(Frame_Selection);
				IF vc.IsLocked() THEN
					selectionFrame.SetActiveHandles({});
				ELSE
					selectionFrame.SetActiveHandlesFor(alignment);
				END;
				ci := GetComponentInfo(vc);
				WMRectangles.MoveRel(bounds, ci.originX, ci.originY);
				selectionFrame.bounds := bounds;
			ELSE
				InvalidateFrame(selectionFrame);
			END;
			owner.propertyWindow.SetComponent(SELF, c);
			UpdateFramePosition;
			IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
			Invalidate;
		END Select;

		PROCEDURE SelectInsertAtObj(vc : WMComponents.VisualComponent);
		BEGIN
			ASSERT(vc # NIL);
			IF ~vc.IsLocked() THEN
				IF selection.Contains(vc) THEN
					selection.Reset;
					InvalidateFrame(selectionFrame);
					UpdateFramePosition;
				END;
				insertObjAt := vc;
				IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.SetInsertAtObj(insertObjAt); END;
				Invalidate;
			ELSE
			END;
		END SelectInsertAtObj;

		PROCEDURE InvalidateRegion(frame, oldFrame : WMRectangles.Rectangle);
		VAR invalidateRect : WMRectangles.Rectangle;
		BEGIN
			IF ~WMRectangles.IsEqual(frame, oldFrame) THEN
				invalidateRect := oldFrame;
				WMRectangles.ExtendRect(invalidateRect, frame);
				invalidateRect := WMRectangles.ResizeRect(invalidateRect, 5);
				InvalidateRect(invalidateRect);
			END;
		END InvalidateRegion;

		PROCEDURE InvalidateFrame(frame : Frame);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			ASSERT(frame # NIL);
			IF frame.IsValid() THEN
				rect := frame.bounds;
				rect := WMRectangles.ResizeRect(rect, 5);
				frame.Clear;
				InvalidateRect(rect);
			END;
		END InvalidateFrame;

		PROCEDURE GetLimitMode(x, y : LONGINT; VAR bounds : WMRectangles.Rectangle) : LONGINT;
		VAR
			vc : WMComponents.VisualComponent; mode : LONGINT;
			ci : ComponentInfo;

			PROCEDURE Near(x, xRef : LONGINT) : BOOLEAN;
			BEGIN
				RETURN (xRef - DistanceLimit <= x) & (x  <= xRef + DistanceLimit);
			END Near;

		BEGIN
			mode := No;
			vc := FindPositionOwner(x, y);
			IF (vc # NIL) & (vc # panel) THEN
				bounds := vc.bounds.Get();
				ci := GetComponentInfo(vc);
				WMRectangles.MoveRel(bounds, -ci.originX, -ci.originY);
				IF Near(x, bounds.l) THEN
					IF Near(y, bounds.t) THEN mode := TopLeft;
					ELSIF Near(y, bounds.b) THEN mode := BottomLeft;
					ELSE mode := Left;
					END;
				ELSIF Near(x, bounds.r) THEN
					IF Near(y, bounds.t) THEN mode := TopRight;
					ELSIF Near(y, bounds.b) THEN mode := BottomRight;
					ELSE mode := Right;
					END;
				ELSIF Near(y, bounds.t) THEN
					mode := Top;
				ELSIF Near(y, bounds.b) THEN
					mode := Bottom;
				ELSE
					IF WMRectangles.PointInRect(x, y, WMRectangles.MakeRect(bounds.l + DistanceLimit, bounds.t + DistanceLimit, bounds.r - DistanceLimit, bounds.b - DistanceLimit)) THEN
						mode := Inside;
					END;
				END;
			END;
			RETURN mode;
		END GetLimitMode;

		PROCEDURE MoveFrame(direction : LONGINT);
		VAR oldFrame : WMRectangles.Rectangle; dx, dy : LONGINT;
		BEGIN
			ASSERT((direction = Left) OR (direction = Top) OR (direction = Right) OR (direction = Bottom));
			IF selectionFrame.IsValid() & selection.ModificationsAllowed() THEN
				oldFrame := selectionFrame.bounds;
				IF enableSnapI & (Inputs.Alt * modifierFlags = {}) THEN
					CASE direction OF
						|Left:
							dx := -(selectionFrame.bounds.l MOD snapgrid.deltaX); IF (dx = 0) THEN dx := -snapgrid.deltaX; END;
							dy := 0;
						|Top:
							dx := 0;
							dy := -(selectionFrame.bounds.t MOD snapgrid.deltaY); IF (dy = 0) THEN dy := -snapgrid.deltaY; END;
						|Right:
							dx := snapgrid.deltaX - (selectionFrame.bounds.r MOD snapgrid.deltaX); IF (dx = 0) THEN dx := snapgrid.deltaX; END;
							dy := 0;
						|Bottom:
							dx := 0;
							dy := snapgrid.deltaY - (selectionFrame.bounds.b MOD snapgrid.deltaY); IF (dy = 0) THEN dy := snapgrid.deltaY; END;
					END;
				ELSE
					CASE direction OF
						|Left: dx := -1; dy := 0;
						|Top: dx := 0; dy := -1;
						|Right: dx := 1; dy := 0;
						|Bottom: dx := 0; dy := 1;
					END;
				END;
				WMRectangles.MoveRel(selectionFrame.bounds, dx, dy);
				IF (selection.NofVisualComponents() > 1) THEN
					DisableUpdate;
					selection.MoveRelative(dx, dy);
					UpdateFramePosition;
					EnableUpdate;
					Invalidate;
				ELSE
					selection.MoveRelative(dx, dy);
					UpdateFramePosition;
					InvalidateRegion(oldFrame, selectionFrame.bounds);
				END;
			END;
		END MoveFrame;

		PROCEDURE CheckSelectionFrame;
		VAR oldBounds, bounds : WMRectangles.Rectangle; activeHandles : SET;
		BEGIN
			selection.GetBoundingBox(bounds, activeHandles);
			IF ~WMRectangles.IsEqual(selectionFrame.bounds, bounds) OR (selectionFrame.activeHandles # activeHandles) THEN
				oldBounds := selectionFrame.bounds;
				selectionFrame.bounds := bounds; selectionFrame.activeHandles := activeHandles;
				InvalidateRegion(oldBounds, selectionFrame.bounds);
			END;
		END CheckSelectionFrame;

		PROCEDURE CheckCursor(x, y : LONGINT; keys, modifierFlags : SET);
		CONST ShiftValue = 256;
		VAR ignore : WMRectangles.Rectangle; res : LONGINT;
		BEGIN
			IF paint THEN
				IF (oldPointerInfo # Paint) THEN
					SetPointerInfo(crosshair);
					oldPointerInfo := Paint;
				END;
			ELSE
				IF (Inputs.Alt * modifierFlags # {}) THEN
					res := GetLimitMode(x, y, ignore);
					IF (oldPointerInfo - ShiftValue # res) THEN
						CASE res OF
							| Left: SetPointerInfo(leftLimit);
							| TopLeft: SetPointerInfo(topLeftLimit);
							| Top: SetPointerInfo(topLimit);
							| TopRight: SetPointerInfo(topRightLimit);
							| Right: SetPointerInfo(rightLimit);
							| BottomRight: SetPointerInfo(bottomRightLimit);
							| Bottom: SetPointerInfo(bottomLimit);
							| BottomLeft: SetPointerInfo(bottomLeftLimit);
							| Inside: SetPointerInfo(sizeLimit);
						ELSE
							SetPointerInfo(manager.pointerStandard);
							oldPointerInfo := No - ShiftValue;
						END;
						oldPointerInfo := res + ShiftValue;
					END;
				ELSE
					IF selectionFrame.IsValid() THEN
						(* change pointerinfo *)
						res := selectionFrame.IsInActiveFrameHandle(x, y);
						IF (oldPointerInfo # res) & ~(0 IN keys) THEN
							CASE res OF
								| Left: SetPointerInfo(manager.pointerLeftRight);
								| TopLeft: SetPointerInfo(manager.pointerULDR);
								| Top: SetPointerInfo(manager.pointerUpDown);
								| TopRight: SetPointerInfo(manager.pointerURDL);
								| Right: SetPointerInfo(manager.pointerLeftRight);
								| BottomRight: SetPointerInfo(manager.pointerULDR);
								| Bottom: SetPointerInfo(manager.pointerUpDown);
								| BottomLeft: SetPointerInfo(manager.pointerURDL);
								| Inside: SetPointerInfo(manager.pointerMove);
							ELSE
								SetPointerInfo(manager.pointerStandard);
							END;
							oldPointerInfo := res;
						END;
					ELSE
						IF (oldPointerInfo # No) THEN
							SetPointerInfo(manager.pointerStandard);
							oldPointerInfo := res;
						END;
					END;
				END;
			END;
		END CheckCursor;

		PROCEDURE CheckSelection;
		VAR component : Repositories.Component; nofComponents : LONGINT;
		BEGIN
			nofComponents := selection.NofComponents();
			IF (nofComponents = 1) THEN
				component := selection.GetFirst();
				owner.propertyWindow.SetComponent(SELF, component);
			ELSE
				owner.propertyWindow.SetComponent(SELF, NIL);
			END;
		END CheckSelection;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR
			down : BOOLEAN; oldFrame : WMRectangles.Rectangle;
			snapX, snapY, snapDownX, snapDownY, dx, dy : LONGINT; f : WMRectangles.Rectangle;
			oldParent : XML.Element;
		BEGIN
			PointerMove^(x, y, keys);
			down := 0 IN keys;
			IF enableSnapI & (Inputs.Alt * modifierFlags = {}) THEN
				snapgrid.Snap(x, y, snapX, snapY);
				snapgrid.Snap(downX, downY, snapDownX, snapDownY);
			ELSE
				snapX := x; snapY := y;
				snapDownX := downX; snapDownY := downY;
			END;
			IF down THEN
				IF (pointerMode = SelectComponent) THEN
					IF Distance(snapDownX, snapDownY, snapX, snapY) > 2.0 THEN
						frame.bounds := WMRectangles.MakeRect(snapDownX, snapDownY, snapX, snapY);
						frame.FixBounds;
						pointerMode := Spawn;
						selection.Reset;
						IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
						UpdateFramePosition;
					END;
				ELSIF (pointerMode = ResizeMove) THEN
					oldFrame := selectionFrame.bounds;
					f := frameResizeOrigin;
					CASE frameResizeMode OF
						|Left: f.l := snapX;
						|TopLeft: f.l := snapX; f.t := snapY;
						|Top: f.t := snapY;
						|TopRight: f.t := snapY; f.r := snapX;
						|Right: f.r := snapX;
						|BottomRight: f.b := snapY; f.r := snapX;
						|Bottom: f.b := snapY;
						|BottomLeft: f.b := snapY; f.l := snapX;
						|Inside: WMRectangles.MoveRel(f, snapX - snapDownX, snapY - snapDownY);
					ELSE
					END;
					selectionFrame.bounds := f;
					selectionFrame.FixBounds;
					IF ~WMRectangles.IsEqual(oldFrame, selectionFrame.bounds) THEN
						dx := 0; dy := 0;
						IF (frameResizeMode = Inside) THEN
							dx := selectionFrame.bounds.l - oldFrame.l; dy := selectionFrame.bounds.t - oldFrame.t;
							DisableUpdate;
							selection.MoveRelative(dx, dy);
							EnableUpdate;
							Invalidate;
						ELSE
							CASE frameResizeMode OF
								|Left: dx := selectionFrame.bounds.l - oldFrame.l;
								|TopLeft: dx := selectionFrame.bounds.l - oldFrame.l; dy := selectionFrame.bounds.t - oldFrame.t;
								|Top: dy := selectionFrame.bounds.t - oldFrame.t;
								|TopRight: dy := selectionFrame.bounds.t - oldFrame.t; dx := selectionFrame.bounds.r - oldFrame.r;
								|Right: dx := selectionFrame.bounds.r - oldFrame.r;
								|BottomRight: dy := selectionFrame.bounds.b - oldFrame.b; dx := selectionFrame.bounds.r - oldFrame.r;
								|Bottom: dy := selectionFrame.bounds.b - oldFrame.b;
								|BottomLeft: dy := selectionFrame.bounds.b - oldFrame.b; dx := selectionFrame.bounds.l - oldFrame.l;
							ELSE
							END;
(*							selection.Resize(frameResizeMode, dx, dy); *)
							DisableUpdate;
							selection.ResizeProportional(selectionFrame.bounds.l, selectionFrame.bounds.t, selectionFrame.GetWidth(), selectionFrame.GetHeight(), 0, 0);
							EnableUpdate;
							Invalidate;
						END;
						UpdateFramePosition;
					END;
					(* InvalidateRegion(oldFrame, selectionFrame.bounds); *)
				ELSIF (pointerMode = Spawn) THEN
					IF frame.IsValid() THEN
						oldFrame := frame.bounds;
						frame.bounds := WMRectangles.MakeRect(snapDownX, snapDownY, snapX, snapY);
						frame.FixBounds;
						oldParent := selection.GetParent();
						selection.Determine(frame.bounds);
						IF (oldParent # selection.GetParent()) THEN Invalidate; END;
						CheckSelection;
						IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
						IF (selection.NofComponents() > 0) THEN
							selection.GetBoundingBox(selectionFrame.bounds, selectionFrame.activeHandles);
						ELSE
							InvalidateFrame(selectionFrame);
						END;
						UpdateFramePosition;
						InvalidateRegion(oldFrame, frame.bounds);
					END;
				ELSIF (pointerMode = PaintComponent) THEN
					oldFrame := frame.bounds;
					frame.bounds := WMRectangles.MakeRect(snapDownX, snapDownY, snapX, snapY);
					frame.FixBounds;
					InvalidateRegion(oldFrame, frame.bounds);
					UpdateFramePosition;
				END;
			END;
			CheckCursor(x, y, keys, modifierFlags);
			lastX := x; lastY := y;
			IF (owner # NIL) THEN owner.UpdateCursorPosition(x, y); END;
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
			lastX := Invalid; lastY := Invalid;
			IF (owner # NIL) THEN owner.UpdateCursorPosition(Invalid, Invalid); END;
		END PointerLeave;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR down : BOOLEAN; res : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			PointerDown^(x, y, keys);
			mouseKeys := keys;
			selectInsertObjAt := selectInsertObjAt OR (2 IN keys);
			down := (0 IN keys);
			IF down THEN
				IF (Inputs.Alt * modifierFlags = {}) THEN
					downX := x; downY := y;
					IF ~paint THEN
						res := selectionFrame.IsInFrameHandle(x, y);
						IF (res = No) THEN
							pointerMode := SelectComponent;
							UpdateFramePosition;
							InvalidateFrame(selectionFrame);
						ELSIF selection.ModificationsAllowed() THEN
							frameResizeOrigin := selectionFrame.bounds;
							frameResizeMode := res;
							pointerMode := ResizeMove;
							selection.InitResize(selectionFrame.bounds.l, selectionFrame.bounds.t, selectionFrame.GetWidth(), selectionFrame.GetHeight());
						END;
					ELSE
						pointerMode := PaintComponent;
					END;
				ELSIF selection.ModificationsAllowed() THEN
					res := GetLimitMode(x, y, rect);
					IF (res = Inside) THEN
						TakeOverSize(x, y);
					ELSIF (res # No) THEN
						selection.SetLimit(rect, res);
						CheckSelectionFrame;
					END;
				END;
			END;
		END PointerDown;

		PROCEDURE TakeOverSize(x, y : LONGINT);
		VAR vc : WMComponents.VisualComponent; rect : WMRectangles.Rectangle;
		BEGIN
			IF selection.ModificationsAllowed() & (selection.NofVisualComponents() > 0) THEN
				vc := FindPositionOwner(x, y);
				IF (vc # NIL) THEN
					InvalidateFrame(selectionFrame);
					rect := vc.bounds.Get();
					selection.SetExtents(rect.r - rect.l, rect.b - rect.t);
					selection.GetBoundingBox(selectionFrame.bounds, selectionFrame.activeHandles);
					UpdateFramePosition;
					panel.Invalidate;
				END;
			END;
		END TakeOverSize;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR
			vc : WMComponents.VisualComponent; down : BOOLEAN; oldParent : XML.Element;
			component : Repositories.Component;
			cx, cy : LONGINT;
		BEGIN
			PointerUp^(x, y, keys);
			mouseKeys := keys;
			down := 0 IN keys;
			IF ~down THEN
				IF paint THEN
					IF frame.IsValid() THEN
						component := owner.componentWindow.GetSelectedComponent();
						IF (component # NIL) THEN
							IF (component IS WMComponents.VisualComponent) THEN
								ToComponentCoordinates(insertObjAt, frame.bounds.l, frame.bounds.t, cx, cy);
								component(WMComponents.VisualComponent).bounds.Set(WMRectangles.MakeRect(cx, cy, cx + (frame.bounds.r - frame.bounds.l), cy + (frame.bounds.b - frame.bounds.t)));
							END;
							AddComponent(component, 0, 0);
						END;
						InvalidateFrame(frame);
					END;
				ELSE
					IF (Inputs.Ctrl * modifierFlags = {}) THEN
						IF (pointerMode = SelectComponent) THEN
							InvalidateFrame(selectionFrame);
							vc := FindPositionOwner(x, y);
							IF  (vc # panel) THEN
								Select(vc);
							ELSE
								Select(NIL);
							END;
						ELSIF (pointerMode = Spawn) THEN
							oldParent := selection.GetParent();
							selection.Determine(frame.bounds);
							IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
							IF (oldParent # selection.GetParent()) THEN Invalidate; END;
							IF (selection.NofComponents() > 0) THEN
								selection.GetBoundingBox(selectionFrame.bounds, selectionFrame.activeHandles);
							ELSE
								selectionFrame.Clear;
							END;
							frame.Clear;
							panel.Invalidate;
							UpdateFramePosition;
						END;
						pointerMode := None;
					ELSE
						vc := FindPositionOwner(x, y);
						IF (vc # panel) THEN
							IF selection.Contains(vc) THEN
								selection.Remove(vc);
							ELSE
								selection.Add(vc);
							END;
							CheckSelection;
							CheckSelectionFrame;
							IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
							UpdateFramePosition;
						END;
					END;
				END;
			END;
			IF selectInsertObjAt & ~(2 IN keys) THEN
				selectInsertObjAt := FALSE;
				vc := FindPositionOwner(x, y);
				IF (vc # NIL) THEN
					SelectInsertAtObj(vc);
				END;
			END;
		END PointerUp;

		PROCEDURE KeyEvent(ucs : LONGINT; flags: SET; VAR keySym: LONGINT);

			PROCEDURE ControlKey(flags : SET) : BOOLEAN;
			BEGIN
				RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
			END ControlKey;

			PROCEDURE Copy;
			VAR components : ComponentArray;
			BEGIN
				components := selection.Get();
				IF (components # NIL) THEN
					clipboard.Put(components);
				END;
			END Copy;

			PROCEDURE Paste;
			VAR components : ComponentArray; i : LONGINT;
			BEGIN
				components := clipboard.Get();
				IF (components # NIL) THEN
					selection.Reset;
					InvalidateFrame(selectionFrame);
					FOR i := 0 TO LEN(components) - 1 DO
						IF (components[i] # NIL) THEN
							selection.Add(components[i]);
							insertObjAt.AddContent(components[i]);
							IF (components[i] IS WMComponents.VisualComponent) THEN
								components[i](WMComponents.VisualComponent).Reset(NIL, NIL);
							END;
						END;
					END;
					CheckSelection;
					IF (selection.NofComponents() > 0) THEN
						selection.GetBoundingBox(selectionFrame.bounds, selectionFrame.activeHandles);
						UpdateFramePosition;
						panel.Invalidate;
						Invalidate;
					END;
				END;
				IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.Refresh(NIL, NIL); END;
			END Paste;

			PROCEDURE SelectAll;
			VAR c : XML.Content;
			BEGIN
				ASSERT(insertObjAt # NIL);
				selection.Reset;
				c := insertObjAt.GetFirst();
				WHILE (c # NIL) DO
					IF (c IS Repositories.Component) THEN
						selection.Add(c(Repositories.Component));
					END;
					c := insertObjAt.GetNext(c);
				END;
				CheckSelection;
				CheckSelectionFrame;
				IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.UpdateColors; END;
			END SelectAll;

		BEGIN
			KeyEvent^(ucs, flags, keySym);
			IF (flags # modifierFlags) THEN
				modifierFlags := flags;
				CheckCursor(lastX, lastY, mouseKeys, modifierFlags);
			END;
			IF Inputs.Release IN flags THEN RETURN; END;
			IF (keySym = Inputs.KsLeft) THEN MoveFrame(Left);
			ELSIF (keySym = Inputs.KsUp) THEN MoveFrame(Top);
			ELSIF (keySym = Inputs.KsRight) THEN MoveFrame(Right);
			ELSIF (keySym = Inputs.KsDown) THEN MoveFrame(Bottom);
			ELSIF (keySym = Inputs.KsDelete) THEN Delete;
			ELSIF ControlKey(flags) & (ucs = 20H) THEN (* CTRL-SPACE *)
				SetPaint(~paint);
				owner.paintBtn.SetPressed(paint);
			ELSIF ControlKey(flags) & (ucs = 03H) THEN (* CTRL-C *)
				Copy;
			ELSIF ControlKey(flags) & (ucs = 16H) THEN (* CTRL-V *)
				Paste;
			ELSIF ControlKey(flags) & (ucs = 18H) THEN (* CTRL-X *)
				Copy;
				selection.Delete;
				CheckSelection;
				CheckSelectionFrame;
				IF (owner # NIL) & (owner.componentTree # NIL) THEN owner.componentTree.Refresh(NIL, NIL); END;
				panel.Invalidate;
			ELSIF ControlKey(flags) & (ucs = 01H) THEN (* CTRL-A *)
				SelectAll;
				panel.Invalidate;
			END;
		END KeyEvent;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			modifierFlags := {};
			downX := Invalid; downY := Invalid; lastX := Invalid; lastY := Invalid;
		END FocusLost;

		PROCEDURE DragOver(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		BEGIN
			IF takesFocus.Get() THEN
				dragX := x; dragY := y;
			END;
		END DragOver;

		PROCEDURE DragAddComponent(component : Repositories.Component; VAR res : LONGINT); (* ! needs work work hierarchical buildup *)
		VAR x, y : LONGINT; c: WMComponents.VisualComponent; 
			rect:WMRectangles.Rectangle; id:ARRAY 64 OF CHAR; b:BOOLEAN;
		BEGIN
			ASSERT(component # NIL);
			IF (dragX < 0) OR (dragY < 0) THEN (*??*)
				AddComponent(component, 0, 0);
			ELSIF ~(component IS WMComponents.Component) THEN (*??*)
			ELSIF ~(component IS WMComponents.VisualComponent) THEN
				ToComponentCoordinates(insertObjAt, dragX, dragY, x, y);
				c:=FindPositionOwner(x,y);
				c.AddContent(component);
				(* button/event pairs are connected implicitly *)
				IF (c IS WMStandardComponents.Button) & ((component IS WMStandardComponents.SystemCommand)OR(component IS WMStandardComponents.Event)) THEN
					id:="";
					IF ~component(WMComponents.Component).properties.GetPropertyValue("ID",id) OR (id="") THEN id:="X"; b:=component(WMComponents.Component).properties.SetPropertyValue("ID",id) END; 
					id:="";
					IF ~ c.properties.GetPropertyValue("OnClickHandler",id) OR (id="") THEN id:="X Run"; b:=c.properties.SetPropertyValue("OnClickHandler",id) END;
				END;
			ELSE
				ToComponentCoordinates(insertObjAt, dragX, dragY, x, y);
				rect:=component(WMComponents.VisualComponent).bounds.Get();
				c:=FindPositionOwner(x,y);
				c.AddContent(component);
				WMRectangles.MoveRel(rect, x-c.bounds.GetLeft(), y-c.bounds.GetTop());
				component(WMComponents.VisualComponent).bounds.Set(rect);	
				component(WMComponents.VisualComponent).Invalidate;
			END;
		END DragAddComponent;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dc : WMRepositories.DropTarget;
		BEGIN
			IF takesFocus.Get() THEN
				NEW(dc, SELF, DragAddComponent);
				dragInfo.data := dc;
				ConfirmDrag(TRUE, dragInfo);
			ELSE
				ConfirmDrag(FALSE, dragInfo);
			END;
		END DragDropped;

		PROCEDURE UpdateFramePosition;
		BEGIN
			IF (owner # NIL) THEN
				IF frame.IsValid() THEN
					owner.UpdateFramePosition(frame.IsValid(), frame.bounds);
				ELSE
					owner.UpdateFramePosition(selectionFrame.IsValid(), selectionFrame.bounds);
				END;
			END;
		END UpdateFramePosition;

		PROCEDURE FindPositionOwner(x, y : LONGINT) : WMComponents.VisualComponent;
		VAR vc, po, positionOwner : WMComponents.VisualComponent; bounds : WMRectangles.Rectangle;
		BEGIN
			vc := SELF;
			positionOwner := GetPositionOwner(x, y);
			WHILE (vc # positionOwner) DO
				vc := positionOwner;
				bounds := vc.bounds.Get();
				po := vc.GetPositionOwner(x - bounds.l, y - bounds.t);
				IF ~po.internal THEN positionOwner := po; ELSE positionOwner := vc; END;
			END;
			RETURN positionOwner;
		END FindPositionOwner;

		PROCEDURE GetComponentInfo(component : WMComponents.VisualComponent) : ComponentInfo;
		VAR ci : ComponentInfo;
		BEGIN
			ASSERT(component # NIL);
			ToMyCoordinates(component, 0, 0, ci.originX, ci.originY);
			RETURN ci;
		END GetComponentInfo;

		(** Get bounds of component in ComponentEditor coordinates *)
		PROCEDURE ToMyCoordinates(component : WMComponents.VisualComponent; x, y : LONGINT; VAR myX,myY : LONGINT);
		VAR c : XML.Element; bounds : WMRectangles.Rectangle;
		BEGIN
			ASSERT(component # NIL);
			myX := x; myY := y;
			c := component.GetParent();
			WHILE (c # NIL) & (c IS WMComponents.VisualComponent) & (c # panel)  DO
				bounds := c(WMComponents.VisualComponent).bounds.Get();
				INC(myX, bounds.l);
				INC(myY, bounds.t);
				c := c.GetParent();
			END;
		END ToMyCoordinates;

		PROCEDURE ToComponentCoordinates(component : WMComponents.VisualComponent; x, y : LONGINT; VAR cx, cy : LONGINT);
		VAR c : XML.Element; bounds : WMRectangles.Rectangle;
		BEGIN
			ASSERT(component # NIL);
			cx := x; cy := y;
			c := component;
			WHILE (c # NIL) & (c # panel) DO
				IF (c IS WMComponents.VisualComponent) THEN
					bounds := c(WMComponents.VisualComponent).bounds.Get();
					DEC(cx, bounds.l);
					DEC(cy, bounds.t);
				END;
				c := c.GetParent();
			END;
		END ToComponentCoordinates;

		PROCEDURE DrawHorizontalLine(canvas : WMGraphics.Canvas; y, color : LONGINT);
		BEGIN
			canvas.Line(0, y, bounds.GetWidth(), y, color, WMGraphics.ModeSrcOverDst);
		END DrawHorizontalLine;

		PROCEDURE DrawVerticalLine(canvas : WMGraphics.Canvas; x, color : LONGINT);
		BEGIN
			canvas.Line(x, 0, x, bounds.GetHeight(), color, WMGraphics.ModeSrcOverDst);
		END DrawVerticalLine;

		PROCEDURE DrawFrames(canvas : WMGraphics.Canvas; parent : WMComponents.VisualComponent; ofsX, ofsY : LONGINT);
		VAR c : XML.Content; vc : WMComponents.VisualComponent; rect : WMRectangles.Rectangle; color : LONGINT;
		BEGIN
			ASSERT((canvas # NIL) & (parent # NIL));
			c := parent.GetFirst();
			WHILE (c # NIL) DO
				IF (c IS WMComponents.VisualComponent) THEN
					vc := c (WMComponents.VisualComponent);
					rect := vc.bounds.Get();
					DrawFrames(canvas, vc, ofsX + rect.l, ofsY + rect.t);
					IF ~vc.internal THEN
						WMRectangles.MoveRel(rect, ofsX, ofsY);
						IF selection.Contains(vc) THEN
							color := WMGraphics.Magenta;
						ELSIF (vc = insertObjAt) THEN
							color := WMGraphics.Blue;
						ELSIF vc.IsLocked() THEN
							color := ColorLocked;
						ELSE
							color := WMGraphics.Green;
						END;
						DrawRectangle(canvas, rect.l, rect.t, rect.r, rect.b, color);
					END;
				END;
				c := parent.GetNext(c);
			END;
		END DrawFrames;

		PROCEDURE DrawHelperLines(canvas : WMGraphics.Canvas; parent : WMComponents.VisualComponent; level : LONGINT; ofsX, ofsY : LONGINT);
		VAR c : XML.Content; vc : WMComponents.VisualComponent; rect : WMRectangles.Rectangle;
		CONST Color = LONGINT(0A0A0FFFFH);
		BEGIN
			ASSERT((canvas # NIL) & (parent # NIL));
			c := parent.GetFirst();
			WHILE (c # NIL) DO
				IF (c IS WMComponents.VisualComponent) THEN
					vc := c (WMComponents.VisualComponent);
					rect := vc.bounds.Get();
					DrawHelperLines(canvas, vc, level + 1, ofsX + rect.l, ofsY + rect.t);
					IF ~vc.internal THEN
						DrawHorizontalLine(canvas, rect.t + ofsY, Color);
						DrawHorizontalLine(canvas, rect.b + ofsY, Color);
						DrawVerticalLine(canvas, rect.l + ofsX, Color);
						DrawVerticalLine(canvas, rect.r + ofsX, Color);
					END;
				END;
				c := parent.GetNext(c);
			END;
		END DrawHelperLines;

		PROCEDURE DrawForeground(canvas : WMGraphics.Canvas);
		VAR rect : WMRectangles.Rectangle; e : XML.Element; x0, y0 : LONGINT;
		BEGIN
			DrawForeground^(canvas);
			IF (mode = EditMode) THEN
				IF showSnapGridI THEN
					DrawSnapGrid(canvas);
				END;
				IF showHelperLinesI THEN
					DrawHelperLines(canvas, panel, 0, 0, 0);
				END;
				IF showFramesI THEN
					DrawFrames(canvas, panel, 0, 0);
				END;
				selectionFrame.Draw(canvas);
				frame.Draw(canvas);
				dragFrame.Draw(canvas);
				IF (insertObjAt # NIL) THEN
					rect := insertObjAt.bounds.Get();
					ToMyCoordinates(insertObjAt, rect.l, rect.t, x0, y0);
					DrawIndication(canvas, x0, y0, x0 + (rect.r - rect.l), y0 + (rect.b - rect.t), 4, 0FF50H);
				END;
				e := selection.GetParent();
				IF (e # NIL) & (e IS WMComponents.VisualComponent) THEN
					rect := e(WMComponents.VisualComponent).bounds.Get();
					ToMyCoordinates(e(WMComponents.VisualComponent), rect.l, rect.t, x0, y0);
					DrawIndication(canvas, x0, y0, x0 + (rect.r - rect.l), y0 + (rect.b - rect.t), 2, LONGINT(0FF000090H));
				END;
			END;
		END DrawForeground;

		PROCEDURE DrawSnapGrid(canvas : WMGraphics.Canvas);
		VAR x, y, width, height, count, deltaN: LONGINT;
		BEGIN
			width := bounds.GetWidth();
			height := bounds.GetHeight();

			count := 0; deltaN := snapgrid.deltaX * snapgrid.nX;
			x := snapgrid.offsetX;
			WHILE (x < width) DO
				canvas.Line(x, 0, x, height, LONGINT(0D0D0D0FFH), WMGraphics.ModeSrcOverDst);
				INC(x, deltaN);
			END;

			count := 0; deltaN := snapgrid.deltaY * snapgrid.nY;
			y := snapgrid.offsetY;
			WHILE (y < height) DO
				canvas.Line(0, y, width, y, LONGINT(0D0D0D0FFH), WMGraphics.ModeSrcOverDst);
				INC(y, deltaN);
			END;

			x := snapgrid.offsetX;
			WHILE (x < width) DO
				y := snapgrid.offsetY;
				WHILE (y < height) DO
					canvas.SetPixel(x, y, WMGraphics.Black, WMGraphics.ModeSrcOverDst);
					INC(y, snapgrid.deltaY);
				END;
				INC(x, snapgrid.deltaX);
			END;
		END DrawSnapGrid;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			IF (mode = EditMode) THEN
				FillWithRectangles(canvas, GetClientRect(), 10, LONGINT(0F0F0F0FFH), WMGraphics.White);
				IF showSnapGridI THEN
					DrawSnapGrid(canvas);
				END;
			END;
		END DrawBackground;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			state := State_Terminating;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = State_Terminated); END;
		END Finalize;

		PROCEDURE UpdateState;
		VAR p : ANY; vc : WMComponents.VisualComponent; alignment : LONGINT; ci : ComponentInfo;
		BEGIN
		(*	p := selectedObj;
			IF (p # NIL) & (p IS WMComponents.VisualComponent) THEN
				vc := p(WMComponents.VisualComponent);
				alignment := vc.alignment.Get();
				IF (alignment # selectedAlignment) THEN
					selectedAlignment := alignment;
					activeFrameHandles := GetActiveFrameHandles(alignment);
					selectedBounds := vc.bounds.Get();
					ci := GetComponentInfo(vc);
					WMRectangles.MoveRel(selectedBounds, ci.originX, ci.originY);
					frame := selectedBounds; (* LOCKING!! *)
					frameIsValid := TRUE;
					Invalidate;
				END;
			END; *)
		END UpdateState;

	BEGIN {ACTIVE}
		WHILE (state = State_Running)  DO
			timer.Sleep(200);
			UpdateState;
		END;
		BEGIN {EXCLUSIVE} state := State_Terminated; END;
	END ComponentEditor;

TYPE

	EditWindow = OBJECT(WMComponents.FormWindow)
	VAR
		editor : ComponentEditor;
		filename : Files.FileName;
		owner : MainWindow;
		modified : BOOLEAN;
		id : LONGINT;
		next : EditWindow;

		PROCEDURE FocusGot;
		BEGIN
			FocusGot^;
			owner.SetActiveEditor(SELF);
			editor.CheckSelection;
		END FocusGot;

		PROCEDURE Close;
		BEGIN
			Close^;
			owner.RemoveEditor(SELF);
		END Close;

		PROCEDURE &New(owner : MainWindow; width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			ASSERT(owner # NIL);
			SELF.owner := owner;
			Init(width, height, alpha);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.fillColor.Set(0);
			editor.owner := owner;
			editor.SetFocus;

			filename := "";
			next := NIL;
			modified := FALSE;
			id := GetId();

			SetContent(editor);
			editor.Invalidate;
		END New;

	END EditWindow;

TYPE
	WindowArray = POINTER TO ARRAY OF EditWindow;

	WindowList = OBJECT
	VAR
		windows : EditWindow;

		PROCEDURE &Init;
		BEGIN
			windows := NIL;
		END Init;

		PROCEDURE IsContained(window : EditWindow) : BOOLEAN;
		VAR w : EditWindow;
		BEGIN
			ASSERT(window # NIL);
			w := windows;
			WHILE (w # NIL) & (w # window) DO w := w.next; END;
			RETURN (w # NIL);
		END IsContained;

		PROCEDURE Add(window : EditWindow);
		BEGIN {EXCLUSIVE}
			ASSERT(window # NIL);
			IF ~IsContained(window) THEN
				window.next := windows;
				windows := window;
			END;
		END Add;

		PROCEDURE Remove(window : EditWindow);
		VAR w : EditWindow;
		BEGIN {EXCLUSIVE}
			ASSERT(window # NIL);
			IF (windows = window) THEN
				windows := window.next;
			ELSE
				w := windows;
				WHILE (w # NIL) & (w.next # window) DO w := w.next; END;
				IF (w # NIL) THEN
					w.next := w.next.next;
				END;
			END;
			window.next := NIL;
		END Remove;

		PROCEDURE Get(id : LONGINT) : EditWindow;
		VAR w : EditWindow;
		BEGIN {EXCLUSIVE}
			w := windows; WHILE(w # NIL) & (w.id # id) DO w := w.next; END;
			RETURN w;
		END Get;

		PROCEDURE GetAll() : WindowArray;
		VAR result : WindowArray; w, temp : EditWindow; nofWindows, i, j : LONGINT;
		BEGIN {EXCLUSIVE}
			nofWindows := 0;
			w := windows; WHILE (w # NIL) DO INC(nofWindows); w := w.next; END;
			IF (nofWindows > 0) THEN
				NEW(result, nofWindows);
				w := windows; i := 0;
				WHILE (w # NIL) DO
					result[i] := w;
					w := w.next; INC(i);
				END;
				(* sort by ID *)
				FOR i := 0 TO LEN(result)-1 DO
					FOR j := 0 TO LEN(result)-2 DO
						IF (result[j].id > result[j + 1].id) THEN
							temp := result[j + 1];
							result[j + 1] := result[j];
							result[j] := temp;
						END;
					END;
				END;
			ELSE
				result := NIL;
			END;
			RETURN result;
		END GetAll;

		PROCEDURE SetActive(window : EditWindow);
		VAR w, temp : EditWindow;
		BEGIN {EXCLUSIVE}
			ASSERT(window # NIL);
			IF (window # windows) THEN
				w := windows;
				WHILE (w # NIL) & (w.next # window) DO w := w.next; END;
				IF (w # NIL) THEN
					temp := w.next;
					w.next := w.next.next;
					temp.next := windows;
					windows := temp;
				END;
			END;
		END SetActive;

		PROCEDURE GetActive() : EditWindow;
		BEGIN {EXCLUSIVE}
			RETURN windows;
		END GetActive;

	END WindowList;

TYPE

	MainWindow = OBJECT(WMComponents.FormWindow)
	VAR
		openBtn, saveBtn, addBtn, paintBtn, loadBtn, deleteBtn, toFrontBtn, getXmlBtn, storeBtn : WMStandardComponents.Button;

		positionXLbl, positionYLbl : Indicator;
		frameTopLeft, frameBottomRight, frameSize : Indicator;

		lastFrame : WMRectangles.Rectangle; lastValid : BOOLEAN;

		toggleEditModeBtn : WMStandardComponents.Button;

		toggleSnapGridBtn, toggleHelperLinesBtn, toggleFramesBtn : WMStandardComponents.Button;

		(* window hide/unhide buttons *)
		toggleEditBtn, toggleComponentsBtn, toggleStructureBtn, togglePropertiesBtn : WMStandardComponents.Button;

		componentTree : ComponentTree;

		windowList : WindowList;
		componentWindow : ComponentWindow;
		componentTreeWindow : HelperWindow;
		propertyWindow : PropertyWindow;

		windowInfo : WMWindowManager.WindowInfo;

		PROCEDURE &New(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			IF (c # NIL) THEN
				Init(c.r - c.l, c.b - c.t, FALSE);
			ELSE
				Init(WindowWidth, WindowHeight, FALSE);
			END;
			vc := CreateForm();
			SetContent(vc);
			SetTitle(Strings.NewString("GUI Editor"));
			SetIcon(WMGraphics.LoadImage("WMBuilder.tar://WMBuilder.png", TRUE));

			lastFrame := WMRectangles.MakeRect(-1, -1, -1, -1);
			lastValid := FALSE;

			NEW(windowList);

			NEW(componentWindow, 250, 300, FALSE);
			componentWindow.SetIcon(WMGraphics.LoadImage("WMBuilder.tar://repositories.png", TRUE));
			WMWindowManager.ExtAddWindow(componentWindow, 20, 100, {WMWindowManager.FlagFrame, WMWindowManager.FlagHidden});

			NEW(propertyWindow, 600, 400, FALSE);
			propertyWindow.SetIcon(WMGraphics.LoadImage("WMBuilder.tar://properties.png", TRUE));
			WMWindowManager.ExtAddWindow(propertyWindow, 600, 100, {WMWindowManager.FlagFrame, WMWindowManager.FlagHidden});

			NEW(componentTree);
			componentTree.fillColor.Set(WMGraphics.White);
			componentTree.treeView.onClickNode.Add(HandleNodeClicked);
			componentTree.treeView.SetExtContextMenuHandler(HandleNodeContextMenu);
			NEW(componentTreeWindow, "Structure", componentTree, 20, 600, 250, 200, FALSE);
			componentTreeWindow.SetIcon(WMGraphics.LoadImage("WMBuilder.tar://structure.png", TRUE));

			IF (c # NIL) THEN
				WMRestorable.AddByContext(SELF, c);
				IF (c.appData # NIL) THEN
					LoadWindows(c.appData(XML.Element));
				END;
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
			END;
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			statusbar, toolbar : WMStandardComponents.Panel;
			panel : WMStandardComponents.Panel;

			PROCEDURE NewButton(CONST caption, image : ARRAY OF CHAR) : WMStandardComponents.Button;
			VAR button : WMStandardComponents.Button;
			BEGIN
				NEW(button); button.alignment.Set(WMComponents.AlignLeft);
				button.isToggle.Set(TRUE);
				button.bounds.SetWidth(32);
				button.SetPressed(TRUE);
				button.imageName.SetAOC(image);
				button.onClick.Add(ButtonHandler);
				toolbar.AddContent(button);
				RETURN button;
			END NewButton;

		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(statusbar); statusbar.alignment.Set(WMComponents.AlignBottom);
			statusbar.bounds.SetHeight(20);
			panel.AddContent(statusbar);

			NEW(frameSize); frameSize.alignment.Set(WMComponents.AlignClient);
			frameSize.SetCaption("w = - / h = -");
			statusbar.AddContent(frameSize);

			NEW(statusbar); statusbar.alignment.Set(WMComponents.AlignBottom);
			statusbar.bounds.SetHeight(20);
			panel.AddContent(statusbar);

			NEW(frameTopLeft); frameTopLeft.alignment.Set(WMComponents.AlignLeft);
			frameTopLeft.bounds.SetWidth(70);
			frameTopLeft.SetCaption("(-, -)");
			statusbar.AddContent(frameTopLeft);

			NEW(frameBottomRight); frameBottomRight.alignment.Set(WMComponents.AlignLeft);
			frameBottomRight.bounds.SetWidth(50);
			frameBottomRight.SetCaption("(-, -)");
			statusbar.AddContent(frameBottomRight);

			NEW(statusbar); statusbar.alignment.Set(WMComponents.AlignBottom);
			statusbar.bounds.SetHeight(20);
			panel.AddContent(statusbar);

			statusbar.AddContent(WMInspectionComponents.CreateLabel("X:", 20, WMComponents.AlignLeft));
			positionXLbl := CreateIndicator("-", 25, WMComponents.AlignLeft);
			statusbar.AddContent(positionXLbl);
			statusbar.AddContent(WMInspectionComponents.CreateLabel("Y:", 20, WMComponents.AlignLeft));
			positionYLbl := CreateIndicator("-", 25, WMComponents.AlignLeft);
			statusbar.AddContent(positionYLbl);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignBottom);
			toolbar.bounds.SetHeight(32);
			panel.AddContent(toolbar);

			toggleSnapGridBtn := NewButton("Grid", "WMBuilder.tar://grid.png");
			toggleHelperLinesBtn := NewButton("HelperLines", "WMBuilder.tar://lines.png");
			toggleFramesBtn := NewButton("Frames", "WMBuilder.tar://frames.png");

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignBottom);
			toolbar.bounds.SetHeight(32);
			panel.AddContent(toolbar);

			toggleEditBtn := NewButton("Edit", "WMBuilder.tar://edit.png");
			toggleComponentsBtn := NewButton("Components", "WMBuilder.tar://repositories.png");
			toggleStructureBtn := NewButton("Structure", "WMBuilder.tar://structure.png");
			togglePropertiesBtn := NewButton("Prop", "WMBuilder.tar://properties.png");

			NEW(openBtn); openBtn.alignment.Set(WMComponents.AlignTop);
			openBtn.caption.SetAOC("Open ...");
			openBtn.onClick.Add(HandleOpenBtn);
			panel.AddContent(openBtn);

			NEW(saveBtn); saveBtn.alignment.Set(WMComponents.AlignTop);
			saveBtn.caption.SetAOC("Save as ...");
			saveBtn.onClick.Add(HandleSaveBtn);
			panel.AddContent(saveBtn);

			NEW(addBtn); addBtn.alignment.Set(WMComponents.AlignTop);
			addBtn.caption.SetAOC("Add");
			addBtn.onClick.Add(HandleAddBtn);
			panel.AddContent(addBtn);

			NEW(deleteBtn); deleteBtn.alignment.Set(WMComponents.AlignTop);
			deleteBtn.caption.SetAOC("Delete");
			deleteBtn.onClick.Add(HandleDeleteBtn);
			panel.AddContent(deleteBtn);

			NEW(toFrontBtn); toFrontBtn.alignment.Set(WMComponents.AlignTop);
			toFrontBtn.caption.SetAOC("ToFront");
			toFrontBtn.onClick.Add(HandleToFrontBtn);
			panel.AddContent(toFrontBtn);

			NEW(getXmlBtn); getXmlBtn.alignment.Set(WMComponents.AlignTop);
			getXmlBtn.caption.SetAOC("GetXML");
			getXmlBtn.onClick.Add(HandleGetXmlBtn);
			panel.AddContent(getXmlBtn);

			NEW(loadBtn); loadBtn.alignment.Set(WMComponents.AlignTop);
			loadBtn.caption.SetAOC("Load");
			loadBtn.onClick.Add(HandleLoadBtn);
			panel.AddContent(loadBtn);

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignTop);
			storeBtn.caption.SetAOC("Store");
			storeBtn.onClick.Add(HandleStoreBtn);
			panel.AddContent(storeBtn);

			NEW(paintBtn); paintBtn.alignment.Set(WMComponents.AlignTop);
			paintBtn.caption.SetAOC("Paint");
			paintBtn.isToggle.Set(TRUE);
			paintBtn.SetPressed(FALSE);
			paintBtn.onClick.Add(HandlePaintBtn);
			panel.AddContent(paintBtn);

			NEW(toggleEditModeBtn); toggleEditModeBtn.alignment.Set(WMComponents.AlignTop);
			toggleEditModeBtn.caption.SetAOC("Edit Mode");
			toggleEditModeBtn.onClick.Add(HandleToggleEditModeBtn);
			toggleEditModeBtn.isToggle.Set(TRUE);
			toggleEditModeBtn.SetPressed(TRUE);
			panel.AddContent(toggleEditModeBtn);

			RETURN panel;
		END CreateForm;

		PROCEDURE UpdateInfo;
		VAR i, j : LONGINT; windows : WindowArray; focusWindow : EditWindow;
		BEGIN
			FOR i := 0 TO LEN(windowInfo.openDocuments)-1 DO windowInfo.openDocuments[i].name := ""; END;
			windowInfo.handleDocumentInfo := HandleDocumentInfo;
			windowInfo.vc.generator := NIL;
			windows := windowList.GetAll();
			IF (windows # NIL) THEN
				focusWindow := windowList.GetActive();
				j := 0;
				FOR i := 0 TO LEN(windows)-1 DO
					IF (j < LEN(windowInfo.openDocuments)) THEN
						windowInfo.openDocuments[j].id := windows[i].id;
						COPY(windows[i].filename, windowInfo.openDocuments[j].name);
						COPY(windows[i].filename, windowInfo.openDocuments[j].fullname);
						windowInfo.openDocuments[j].modified := windows[i].modified;
						windowInfo.openDocuments[j].hasFocus := windows[i] = focusWindow;
						INC(j);
					END;
				END;
			END;
			SetInfo(windowInfo);
		END UpdateInfo;

		PROCEDURE HandleDocumentInfo(CONST info : WMWindowManager.DocumentInfo; new : BOOLEAN; VAR res : LONGINT);
		VAR w : EditWindow;
		BEGIN
			w := windowList.Get(info.id);
			IF (w # NIL) THEN
				SetActiveEditor(w);
				manager.ToFront(w);
				manager.SetFocus(w);
			END;
		END HandleDocumentInfo;

		PROCEDURE SetActiveEditor(window : EditWindow);
		BEGIN
			ASSERT(window # NIL);
			windowList.SetActive(window);
			componentTree.SetComponent(window.editor.panel, window.editor.selection);
			toggleSnapGridBtn.SetPressed(window.editor.showSnapGrid.Get());
			toggleHelperLinesBtn.SetPressed(window.editor.showHelperLines.Get());
			toggleFramesBtn.SetPressed(window.editor.showFrames.Get());
			toggleEditModeBtn.SetPressed(window.editor.GetMode() = EditMode);
			UpdateInfo;
		END SetActiveEditor;

		PROCEDURE RemoveEditor(window : EditWindow);
		VAR w : EditWindow; c : Repositories.Component; component : WMComponents.Component;
		BEGIN
			ASSERT(window # NIL);
			windowList.Remove(window);
			w := windowList.GetActive();
			IF (w # NIL) THEN
				toggleSnapGridBtn.SetPressed(w.editor.showSnapGrid.Get());
				toggleHelperLinesBtn.SetPressed(w.editor.showHelperLines.Get());
				toggleFramesBtn.SetPressed(w.editor.showFrames.Get());
				componentTree.SetComponent(w.editor.panel, w.editor.selection);
				component := NIL;
				IF (w.editor.selection.NofComponents() = 1) THEN
					c := w.editor.selection.GetFirst();
					IF (c IS WMComponents.Component) THEN
						component := c (WMComponents.Component);
					END;
				END;
				propertyWindow.SetComponent(SELF, component);
			ELSE
				componentTree.SetComponent(NIL, NIL);
				propertyWindow.SetComponent(SELF, NIL);
			END;
			UpdateInfo;
		END RemoveEditor;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				IF (sender = toggleEditBtn) THEN
					manager.SetIsVisible(w, ~w.isVisible);
					IF (w.isVisible) THEN manager.ToFront(w); END;
				ELSIF (sender = toggleComponentsBtn) THEN
					manager.SetIsVisible(componentWindow, ~componentWindow.isVisible);
					IF (componentWindow.isVisible) THEN manager.ToFront(componentWindow); END;
				ELSIF (sender = toggleStructureBtn) THEN
					manager.SetIsVisible(componentTreeWindow, ~componentTreeWindow.isVisible);
					IF (componentTreeWindow.isVisible) THEN manager.ToFront(componentTreeWindow); END;
				ELSIF (sender = togglePropertiesBtn) THEN
					manager.SetIsVisible(propertyWindow, ~propertyWindow.isVisible);
					IF (propertyWindow.isVisible) THEN manager.ToFront(propertyWindow); END;
				ELSIF (sender = toggleSnapGridBtn) THEN
					w.editor.showSnapGrid.Set(~w.editor.showSnapGrid.Get());
				ELSIF (sender = toggleHelperLinesBtn) THEN
					w.editor.showHelperLines.Set(~w.editor.showHelperLines.Get());
				ELSIF (sender = toggleFramesBtn) THEN
					w.editor.showFrames.Set(~w.editor.showFrames.Get());
				END;
			END;
		END ButtonHandler;

		PROCEDURE HandleOpenBtn(sender, data : ANY);
		VAR filename : Files.FileName; res, ignoreRes : LONGINT;
		BEGIN
			res := WMDialogs.QueryString("Open...", filename);
			IF (res = WMDialogs.ResOk) THEN
				Load(filename, ignoreRes);
			END;
		END HandleOpenBtn;

		PROCEDURE HandleSaveBtn(sender, data : ANY);
		VAR w : EditWindow; filename : Files.FileName; res : LONGINT;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				res := WMDialogs.QueryString("Save...", filename);
				IF (res = WMDialogs.ResOk) THEN
					Store(filename, w, res);
					IF (res = 0) THEN
						w.SetTitle(Strings.NewString(filename));
					ELSE
						WMDialogs.Error("Error", "Could not store");
					END;
				END;
			ELSE
				WMDialogs.Error("Error", "No active window");
			END;
		END HandleSaveBtn;

		PROCEDURE HandleAddBtn(sender, data : ANY);
		VAR c : Repositories.Component; w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				c := componentWindow.GetSelectedComponent();
				IF (c # NIL) THEN
					w.editor.AddComponent(c, 0, 0);
					componentTree.Refresh(NIL, NIL);
				END;
			END;
		END HandleAddBtn;

		PROCEDURE HandlePaintBtn(sender,data : ANY);
		VAR w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				w.editor.SetPaint(paintBtn.GetPressed());
			END;
		END HandlePaintBtn;

		PROCEDURE HandleLoadBtn(sender, data : ANY);
		VAR
			c : Repositories.Component; width, height : LONGINT;
			manager : WMWindowManager.WindowManager;
			w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				c := componentWindow.GetSelectedComponent();
				IF (c # NIL) THEN
					IF (c IS WMComponents.VisualComponent) THEN
						width := c(WMComponents.VisualComponent).bounds.GetWidth();
						height := c(WMComponents.VisualComponent).bounds.GetHeight();

						IF (width < 20) THEN width := 640; END;
						IF (height < 20) THEN height := 480; END;

						w.editor.SetPanel(c(WMComponents.VisualComponent));

						manager := WMWindowManager.GetDefaultManager();
						manager.SetWindowSize(w, width, height);
					ELSE
						WMDialogs.Error("Error", "Can only load visual components");
					END;
				ELSE
					WMDialogs.Error("Error", "Could not load component");
				END;
			END;
		END HandleLoadBtn;

		PROCEDURE HandleDeleteBtn(sender, data : ANY);
		VAR w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				w.editor.Delete;
				componentTree.Refresh(NIL, NIL);
			END;
		END HandleDeleteBtn;

		PROCEDURE HandleToFrontBtn(sender, data : ANY);
		VAR w : EditWindow;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				w.editor.ToFront;
				componentTree.Refresh(NIL, NIL);
			END;
		END HandleToFrontBtn;

		PROCEDURE HandleGetXmlBtn(sender, data : ANY);
		VAR w : EditWindow; writer : WMUtilities.WindowWriter;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				NEW(writer, "GUI Builder XML", 640, 480, FALSE);
				IF (w.editor.insertObjAt # NIL) THEN
					w.editor.insertObjAt.Write(writer, NIL, 0);
				ELSE
					w.editor.panel.Write(writer, NIL, 0);
				END;
				writer.Update;
			END;
		END HandleGetXmlBtn;

		PROCEDURE HandleStoreBtn(sender, data : ANY);
		VAR
			w : EditWindow;
			repositoryName, componentName : ARRAY 64 OF CHAR; refNum : LONGINT;
			name, filename : Files.FileName;
			repository : Repositories.Repository;
			res : LONGINT;
		BEGIN
			w := windowList.GetActive();
			IF (w = NIL) THEN RETURN; END;
			res := WMDialogs.QueryString("Store as...", name);
			IF (res = WMDialogs.ResOk) THEN
				IF Repositories.SplitName(name, repositoryName, componentName, refNum) THEN
					repository := Repositories.ThisRepository(repositoryName);
					IF (repository = NIL) THEN
						res := WMDialogs.Confirmation("Please choose...", "Repository not found, create new repository?");
						IF (res = WMDialogs.ResYes) THEN
							COPY(repositoryName, filename); Strings.Append(filename, "."); Strings.Append(filename, Repositories.DefaultFileExtension);
							Repositories.CreateRepository(filename, res);
							IF (res = Repositories.Ok) THEN
								repository := Repositories.ThisRepository(repositoryName);
							ELSE
								WMDialogs.Error("Error", "Could not create repository");
							END;
						END;
					END;
					IF (repository # NIL) THEN
						IF (w.editor.insertObjAt # NIL) THEN
							repository.PutComponent(w.editor.insertObjAt, componentName, refNum, res);
						ELSE
							repository.PutComponent(w.editor.panel, componentName, refNum, res);
						END;
						IF (res = Repositories.Ok) THEN
							repository.UnbindComponent(componentName, refNum, res);
							IF (res # Repositories.Ok) THEN
								WMDialogs.Warning("Warning", "Could not unbind component from repository...");
							END;
						ELSE
							WMDialogs.Error("Error", "Could not put component into repository");
						END;
					END;
				ELSE
					WMDialogs.Error("Error", "Expected repositoryName:componentName:refNum");
				END;
			END;
		END HandleStoreBtn;

		PROCEDURE HandleToggleEditModeBtn(sender, data : ANY);
		VAR w : EditWindow; mode : LONGINT;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				IF (sender = toggleEditModeBtn) THEN
					mode := w.editor.GetMode();
					IF (mode = EditMode) THEN mode := UseMode; ELSE mode := EditMode; END;
					toggleEditModeBtn.SetPressed(mode = EditMode);
					w.editor.SetMode(mode);
				END;
			END;
		END HandleToggleEditModeBtn;

		PROCEDURE HandleNodeClicked(sender, data : ANY);
		VAR w : EditWindow; ptr : ANY;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) & (data # NIL) & (data IS WMTrees.TreeNode) THEN
				componentTree.tree.Acquire;
				ptr := componentTree.tree.GetNodeData(data(WMTrees.TreeNode));
				componentTree.tree.Release;
				IF (ptr # NIL) & (ptr IS Repositories.Component) THEN
					w.editor.Select(ptr(Repositories.Component));
				END;
			END;
		END HandleNodeClicked;

		PROCEDURE HandleNodeContextMenu(sender : ANY; x, y : LONGINT);
		VAR  w : EditWindow; node : WMTrees.TreeNode; ptr : ANY;
		BEGIN
			w := windowList.GetActive();
			IF (w # NIL) THEN
				componentTree.treeView.Acquire;
				node := componentTree.treeView.GetNodeAtPos(x, y);
				componentTree.tree.Acquire;
				IF (node # NIL) THEN
					ptr := componentTree.tree.GetNodeData(node);
				END;
				componentTree.tree.Release;
				componentTree.treeView.Release;
				IF (ptr # NIL) & (ptr IS WMComponents.VisualComponent) THEN
					w.editor.SelectInsertAtObj(ptr(WMComponents.VisualComponent));
				END;
			END;
		END HandleNodeContextMenu;

		PROCEDURE UpdateCursorPosition(x, y : LONGINT);
		VAR nbr : ARRAY 16 OF CHAR;
		BEGIN
			IF (x # Invalid) THEN Strings.IntToStr(x, nbr); ELSE nbr := "-"; END;
			positionXLbl.SetCaption(nbr);
			IF (y # Invalid) THEN Strings.IntToStr(y, nbr); ELSE nbr := "-"; END;
			positionYLbl.SetCaption(nbr);
		END UpdateCursorPosition;

		PROCEDURE UpdateFramePosition(valid : BOOLEAN; frame : WMRectangles.Rectangle);
		VAR string : ARRAY 32 OF CHAR;

			PROCEDURE AppendNumber(VAR string : ARRAY OF CHAR; number : LONGINT);
			VAR nbr : ARRAY 8 OF CHAR;
			BEGIN
				Strings.IntToStr(number, nbr);
				Strings.Append(string, nbr);
			END AppendNumber;

		BEGIN
			IF ~WMRectangles.IsEqual(lastFrame, frame) OR (lastValid # valid) THEN
				IF valid THEN
					IF (lastFrame.l # frame.l) OR (lastFrame.t # frame.t) THEN
						string := "("; AppendNumber(string, frame.l); Strings.Append(string, ", "); AppendNumber(string, frame.t); Strings.Append(string, ")");
						frameTopLeft.SetCaption(string);
					END;
					IF (lastFrame.r # frame.r) OR (lastFrame.b # frame.b) THEN
						string := "("; AppendNumber(string, frame.r); Strings.Append(string, ", "); AppendNumber(string, frame.b); Strings.Append(string, ")");
						frameBottomRight.SetCaption(string);
					END;
					IF (lastFrame.r - lastFrame.l # frame.r - frame.l) OR (lastFrame.b - lastFrame.t # frame.b - frame.t) THEN
						string := "w = "; AppendNumber(string, frame.r - frame.l); Strings.Append(string, ", h = "); AppendNumber(string, frame.b - frame.t);
						frameSize.SetCaption(string);
					END;
				ELSE
					frameTopLeft.SetCaption("(-, -)");
					frameBottomRight.SetCaption("(-, -)");
					frameSize.SetCaption("w = -, h = -");
				END;
				lastFrame := frame;
				lastValid := valid;
			END;
		END UpdateFramePosition;

		PROCEDURE Load(CONST filename : ARRAY OF CHAR; VAR res : LONGINT);
		VAR window : EditWindow; content : XML.Content; panel : WMStandardComponents.Panel; width, height : LONGINT;
		BEGIN
			content := WMComponents.Load(filename);
			IF (content # NIL) & (content IS WMStandardComponents.Panel) THEN
				panel := content (WMStandardComponents.Panel);
				width := panel.bounds.GetWidth(); height := panel.bounds.GetHeight();
				IF (width > 0) & (height > 0) THEN
					NEW(window, SELF, width, height, FALSE);
					window.SetIcon(WMGraphics.LoadImage("WMBuilder.tar://edit.png", TRUE));
					window.SetTitle(Strings.NewString(filename));
					WMWindowManager.AddWindow(window, 100, 100);
					windowList.Add(window);
					window.editor.SetPanel(panel);
					COPY(filename, window.filename);
					SetActiveEditor(window);
				ELSE
					WMDialogs.Error("Error", "Expected valid width and height");
				END;
				res := 0;
			ELSE
				NEW(window, SELF, EditWindowWidth, EditWindowHeight, FALSE);
				window.SetIcon(WMGraphics.LoadImage("WMBuilder.tar://edit.png", TRUE));
				window.SetTitle(Strings.NewString(filename));
				WMWindowManager.AddWindow(window, 100, 100);
				COPY(filename, window.filename);
				windowList.Add(window);
				SetActiveEditor(window);
			END;
		END Load;

		PROCEDURE Store(CONST filename : ARRAY OF CHAR; window : EditWindow; VAR res : LONGINT);
		VAR file : Files.File; writer : Files.Writer;
		BEGIN
			ASSERT(window # NIL);
			file := Files.New(filename);
			IF (file # NIL) THEN
				window.modified := FALSE;
				NEW(writer, file, 0);
				window.editor.panel.Write(writer, NIL, 0);
				COPY(filename, window.filename);
				writer.Update;
				Files.Register(file);
				res := 0;
				UpdateInfo;
			ELSE
				res := 99;
			END;
		END Store;

		PROCEDURE LoadWindows(data : XML.Element);
		VAR c : XML.Content; e : XML.Element; s : Strings.String; bounds : WMRectangles.Rectangle; filename : Files.FileName; res : LONGINT;
		BEGIN
			ASSERT(data # NIL);
			c := data.GetFirst();
			WHILE (c # NIL) DO
				IF (c IS XML.Element) THEN
					e := c (XML.Element);
					s := e.GetName();
					IF (s # NIL) & (s^ = "Window") THEN
						s := e.GetAttributeValue("l"); IF (s # NIL) THEN Strings.StrToInt(s^, bounds.l); END;
						s := e.GetAttributeValue("t"); IF (s # NIL) THEN Strings.StrToInt(s^, bounds.t); END;
						s := e.GetAttributeValue("r"); IF (s # NIL) THEN Strings.StrToInt(s^, bounds.r); END;
						s := e.GetAttributeValue("b"); IF (s # NIL) THEN Strings.StrToInt(s^, bounds.b); END;
						s := e.GetAttributeValue("file"); IF (s # NIL) THEN COPY(s^, filename); ELSE filename := "Unknown.wm"; END;
					END;
					Load(filename, res);
				END;
				c := data.GetNext(c);
			END;
		END LoadWindows;

		PROCEDURE StoreWindows() : XML.Element;
		VAR
			windows : WindowArray; data, w : XML.Element;
			string : ARRAY 32 OF CHAR; bounds : WMRectangles.Rectangle;
			i : LONGINT;
		BEGIN
			windows := windowList.GetAll();
			IF (windows # NIL) THEN
				NEW(data); data.SetName("Data");
				FOR i := 0 TO LEN(windows)-1 DO
					bounds := windows[i].bounds;
					NEW(w); w.SetName("Window");
					Strings.IntToStr(bounds.l, string); w.SetAttributeValue("l", string);
					Strings.IntToStr(bounds.t, string); w.SetAttributeValue("t", string);
					Strings.IntToStr(bounds.r, string); w.SetAttributeValue("r", string);
					Strings.IntToStr(bounds.b, string); w.SetAttributeValue("b", string);
					w.SetAttributeValue("file", windows[i].filename);
					data.AddContent(w);
				END;
			ELSE
				data := NIL;
			END;
			RETURN data;
		END StoreWindows;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR data : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close;
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					data := StoreWindows();
					x.ext(WMRestorable.Storage).Add("WMBuilder", "WMBuilder.Restore", SELF, data);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		VAR windows : WindowArray; i : LONGINT;
		BEGIN
			windows := windowList.GetAll();
			IF (windows # NIL) THEN
				FOR i := 0 TO LEN(windows)-1 DO
					windows[i].Close;
				END;
			END;
			componentWindow.Close;
			componentTreeWindow.Close;
			propertyWindow.Close;
			Close^;
			DecCount;
		END Close;

	END MainWindow;

VAR
	nofWindows, nextId : LONGINT;

	StrComponentEditor : Strings.String;

	(* cursors *)
	leftLimit, topLeftLimit, topLimit, topRightLimit,
	rightLimit, bottomRightLimit, bottomLimit, bottomLeftLimit, sizeLimit, crosshair : WMWindowManager.PointerInfo;

PROCEDURE CreateIndicator(CONST content : ARRAY OF CHAR; width, alignment : LONGINT) : Indicator;
VAR i : Indicator;
BEGIN
	NEW(i); i.alignment.Set(alignment); i.bounds.SetWidth(width);
	i.SetCaption(content);
	RETURN i;
END CreateIndicator;

PROCEDURE Distance(x0, y0, x1, y1 : LONGINT) : REAL;
BEGIN
	RETURN Math.sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1));
END Distance;

PROCEDURE DrawDashedLine(canvas : WMGraphics.Canvas; xs, ys, xe, ye, color0, color1, width0, width1 : LONGINT);
VAR p0, p1, color, width : LONGINT;
BEGIN
	ASSERT((width0 > 0) & (width1 > 0));
	color := color0;
	width := width0;
	IF (xs = xe) THEN (* vertical line *)
		p0 := ys;
		WHILE (p0 <= ye) DO
			p1 := p0 + width;
			IF (p1 > ye) THEN p1 := ye; END;
			canvas.Line(xs, p0, xs, p1, color, WMGraphics.ModeSrcOverDst);
			IF (color = color0) THEN
				color := color1; width := width1;
			ELSE
				color := color0; width := width0;
			END;
			p0 := p1 + 1;
		END;
	ELSIF (ys = ye) THEN (* horizontal line *)
		p0 := xs;
		WHILE (p0 <= xe) DO
			p1 := p0 + width;
			IF (p1 > xe) THEN p1 := xe; END;
			canvas.Line(p0, ys, p1, ye, color, WMGraphics.ModeSrcOverDst);
			IF (color = color0) THEN
				color := color1; width := width1;
			ELSE
				color := color0; width := width0;
			END;
			p0 := p1 + 1;
		END;
	ELSE
		HALT(99); (* only works for horizontal or vertical lines! *)
	END;
END DrawDashedLine;

PROCEDURE DrawRectangle(canvas: WMGraphics.Canvas; xs, ys, xe, ye, color: LONGINT);
BEGIN
	canvas.Line(xs, ys, xs, ye, color, WMGraphics.ModeSrcOverDst);
	canvas.Line(xs, ys, xe, ys, color, WMGraphics.ModeSrcOverDst);
	canvas.Line(xe, ys, xe, ye, color, WMGraphics.ModeSrcOverDst);
	canvas.Line(xs, ye, xe, ye, color, WMGraphics.ModeSrcOverDst);
END DrawRectangle;

PROCEDURE DrawDashedRectangle(canvas : WMGraphics.Canvas; xs, ys, xe, ye, color0, color1, width0, width1 : LONGINT);
BEGIN
	DrawDashedLine(canvas, xs, ys, xs, ye, color0, color1, width0, width1);
	DrawDashedLine(canvas, xs, ys, xe, ys, color0, color1, width0, width1);
	DrawDashedLine(canvas, xe, ys, xe, ye, color0, color1, width0, width1);
	DrawDashedLine(canvas, xs, ye, xe, ye, color0, color1, width0, width1);
END DrawDashedRectangle;

PROCEDURE DrawIndication(canvas: WMGraphics.Canvas; xs, ys, xe, ye , width, color : LONGINT);
CONST CornerWidth = 8; EdgeWidth = 20;
BEGIN
	(* top-left *)
	canvas.Fill(WMRectangles.MakeRect(xs, ys, xs + width, ys + CornerWidth), color, WMGraphics.ModeSrcOverDst);
	canvas.Fill(WMRectangles.MakeRect(xs, ys, xs + CornerWidth, ys + width), color, WMGraphics.ModeSrcOverDst);
	(* top-right *)
	canvas.Fill(WMRectangles.MakeRect(xe - width, ys, xe, ys + CornerWidth), color, WMGraphics.ModeSrcOverDst);
	canvas.Fill(WMRectangles.MakeRect(xe - CornerWidth, ys, xe, ys + width), color, WMGraphics.ModeSrcOverDst);
	(* bottom-left *)
	canvas.Fill(WMRectangles.MakeRect(xs, ye - width, xs +CornerWidth, ye), color, WMGraphics.ModeSrcOverDst);
	canvas.Fill(WMRectangles.MakeRect(xs, ye - CornerWidth, xs + width, ye), color, WMGraphics.ModeSrcOverDst);
	(* bottom-right *)
	canvas.Fill(WMRectangles.MakeRect(xe - CornerWidth, ye - width, xe, ye), color, WMGraphics.ModeSrcOverDst);
	canvas.Fill(WMRectangles.MakeRect(xe - width, ye - CornerWidth, xe, ye), color, WMGraphics.ModeSrcOverDst);
	IF (xe - xs > 50) THEN
		(* top *)
		canvas.Fill(WMRectangles.MakeRect(ENTIER((xs + xe) / 2) - EdgeWidth, ys, ENTIER((xs + xe) / 2) + EdgeWidth, ys + width), color, WMGraphics.ModeSrcOverDst);
		(* bottom *)
		canvas.Fill(WMRectangles.MakeRect(ENTIER((xs+xe)/2)-EdgeWidth, ye - width, ENTIER((xs+xe)/2)+EdgeWidth, ye), color, WMGraphics.ModeSrcOverDst);
	END;
	IF (ye - ys > 50) THEN
		(* left *)
		canvas.Fill(WMRectangles.MakeRect(xs, ENTIER((ys + ye) / 2) - EdgeWidth, xs + width, ENTIER((ys + ye) / 2) + EdgeWidth), color, WMGraphics.ModeSrcOverDst);
		(* right *)
		canvas.Fill(WMRectangles.MakeRect(xe - width, ENTIER((ys+ye)/2)-EdgeWidth, xe, ENTIER((ys+ye)/2)+EdgeWidth), color, WMGraphics.ModeSrcOverDst);
	END;
END DrawIndication;

PROCEDURE FillWithRectangles(canvas : WMGraphics.Canvas; rectangle : WMRectangles.Rectangle; width : LONGINT; color1, color2 : LONGINT);
VAR column, row, nofColumns, nofRows : LONGINT; x, y : LONGINT; color : LONGINT;
BEGIN
	nofColumns := (rectangle.r - rectangle.l) DIV width + 1;
	nofRows := (rectangle.b - rectangle.t) DIV width + 1;
	FOR column := 0 TO nofColumns - 1 DO
		IF (column MOD 2 = 0) THEN color := color1; ELSE color := color2; END;
		x := column * width;
		FOR row := 0 TO nofRows - 1 DO
			y := row * width;
			canvas.Fill(WMRectangles.MakeRect(x, y, x + width, y + width), color, WMGraphics.ModeCopy);
			IF (color = color1) THEN color := color2; ELSE color := color1; END;
		END;
	END;
END FillWithRectangles;

PROCEDURE ShowComponent*(component : WMComponents.Component);
VAR string : Strings.String;
BEGIN
	IF (component # NIL) THEN
		string := component.GetName();
		IF (string # NIL) THEN KernelLog.String(string^); ELSE KernelLog.String("NoName"); END;
		KernelLog.String(" [");
		string := component.uid.Get();
		IF (string # NIL) THEN KernelLog.String(string^); ELSE KernelLog.String("NIL"); END;
		IF (component IS WMComponents.VisualComponent) THEN
			KernelLog.String(", "); KernelLog.Boolean(component(WMComponents.VisualComponent).takesFocus.Get());
		END;
		KernelLog.String("]");
	ELSE
		KernelLog.String("NIL?");
	END;
END ShowComponent;

PROCEDURE ShowRect*(CONST name : ARRAY OF CHAR; rect : WMRectangles.Rectangle);
BEGIN
	KernelLog.String(name); KernelLog.String(": l=");
	KernelLog.Int(rect.l, 0); KernelLog.String(", t="); KernelLog.Int(rect.t, 0); KernelLog.String(", r=");
	KernelLog.Int(rect.r, 0); KernelLog.String(", b="); KernelLog.Int(rect.b, 0); KernelLog.String(" (w=");
	KernelLog.Int(rect.r - rect.l, 0); KernelLog.String(", h="); KernelLog.Int(rect.b - rect.t, 0); KernelLog.String(")");
	KernelLog.Ln;
END ShowRect;

PROCEDURE LabelComponent(vc : WMComponents.VisualComponent);
BEGIN
	ASSERT(vc # NIL);
	IF (vc IS WMStandardComponents.Button) THEN
		IF (vc(WMStandardComponents.Button).caption.Get() = NIL) THEN
			vc(WMStandardComponents.Button).caption.SetAOC("Button");
		END;
	ELSIF (vc IS WMStandardComponents.Label) THEN
		IF (vc(WMStandardComponents.Label).caption.Get() = NIL) THEN
			vc(WMStandardComponents.Label).caption.SetAOC("Label");
		END;
	ELSIF (vc IS WMStandardComponents.GroupPanel) THEN
		IF (vc(WMStandardComponents.GroupPanel).caption.Get() = NIL) THEN
			vc(WMStandardComponents.GroupPanel).caption.SetAOC("GroupPanel");
		END;
	END;
END LabelComponent;

PROCEDURE Open*(context : Commands.Context); (** {filename} ~ *)
VAR window : MainWindow; filename : Files.FileName; count, ignoreRes : LONGINT;
BEGIN
	NEW(window, NIL);
	count := 0;
	WHILE context.arg.GetString(filename) DO
		window.Load(filename, ignoreRes); INC(count)
	END;
	IF count = 0 THEN window.Load("untitled.wm", ignoreRes); END;
END Open;

PROCEDURE GenComponentEditor*(): XML.Element;
VAR editPanel: ComponentEditor;
BEGIN
	NEW(editPanel); RETURN editPanel;
END GenComponentEditor;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : MainWindow;
BEGIN
	NEW(w, context)
END Restore;

PROCEDURE LoadCursors;
BEGIN
	WMWindowManager.LoadCursor("WMBuilder.tar://leftlimit.png", 4, 14, leftLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://topleftlimit.png", 7, 5, topLeftLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://toplimit.png", 13, 3, topLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://toprightlimit.png", 24, 5, topRightLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://rightlimit.png", 27, 14, rightLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://bottomrightlimit.png", 24, 26, bottomRightLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://bottomlimit.png", 13, 28, bottomLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://bottomleftlimit.png", 7, 26, bottomLeftLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://sizelimit.png", 16, 17, sizeLimit);
	WMWindowManager.LoadCursor("WMBuilder.tar://crosshair.png", 13, 12, crosshair);
END LoadCursors;

PROCEDURE LoadRepositories;
VAR ignore : Repositories.Repository;
BEGIN
	ignore := Repositories.ThisRepository("Standard");
	ignore := Repositories.ThisRepository("Models");
	ignore := Repositories.ThisRepository("Shapes");
END LoadRepositories;

PROCEDURE GetId() : LONGINT;
BEGIN {EXCLUSIVE}
	INC(nextId);
	RETURN nextId;
END GetId;

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
	nofWindows := 0; nextId := 0;
	StrComponentEditor := Strings.NewString("ComponentEditor");
	LoadCursors;
	LoadRepositories;
	Modules.InstallTermHandler(Cleanup);
END WMBuilder.

WMBuilder.Open ~

SystemTools.Free WMBuilder WMInspector WMInspectionComponents ~
SystemTools.FreeDownTo WMBuilder ~

PC.Compile \s
	Repositories.Mod WMRepositories.Mod
	WMModels.Mod
	WMInspectionComponents.Mod
	WMBuilder.Mod
~


