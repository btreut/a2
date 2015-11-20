MODULE WMProfiler; (** AUTHOR "staubesv"; PURPOSE "GUI for hierarchical profiler"; *)

IMPORT
	Modules, Kernel, Strings, HierarchicalProfiler, WMGraphics, WMMessages, WMRestorable,
	WMWindowManager, WMComponents, WMStandardComponents, WMEditors, WMTrees, WMErrors, WMProgressComponents;

CONST
	DefaultTime = 30;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		startBtn, stopBtn,continueBtn, getProfileBtn, flattenBtn, filterBtn : WMStandardComponents.Button;
		timeEdit, typeEdit, infoEdit, filterMaskEdit, filterCountEdit : WMEditors.Editor;

		tree : WMTrees.Tree;
		treeView : WMTrees.TreeView;

		lastSelectedNode : HierarchicalProfiler.Node;
		lastState : LONGINT;

		statusLabel : WMStandardComponents.Label;

		progressBar : WMProgressComponents.ProgressBar;

		profile : HierarchicalProfiler.Profile;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE HasVisibleChildren(node : HierarchicalProfiler.Node) : BOOLEAN;
		VAR child : HierarchicalProfiler.Node;
		BEGIN
			ASSERT(node # NIL);
			child := node.child;
			WHILE (child # NIL) & (child.marked # TRUE) DO child := child.sibling; END;
			RETURN (child # NIL);
		END HasVisibleChildren;

		PROCEDURE AddChildNodes(parent : WMTrees.TreeNode; node : HierarchicalProfiler.Node; expand : BOOLEAN);
		VAR n : WMTrees.TreeNode; temp : HierarchicalProfiler.Node;
		BEGIN
			ASSERT(parent # NIL);
			temp := node.child;
			node.extern := TRUE;
			WHILE (temp # NIL) DO
				NEW(n);
				tree.AddChildNode(parent, n);
				tree.SetNodeCaption(n, temp.GetCaption());
				tree.SetNodeData(n, temp);
				IF (temp.marked) THEN
					tree.ExclNodeState(n, WMTrees.NodeHidden);
					IF HasVisibleChildren(temp) THEN tree.InclNodeState(n, WMTrees.NodeSubnodesOnExpand); END;
				ELSE
					tree.InclNodeState(n, WMTrees.NodeHidden);
				END;
				IF expand THEN
					tree.ExpandToRoot(n);
					AddChildNodes(n, temp, FALSE);
				END;
				temp := temp.sibling;
			END;
		END AddChildNodes;

		PROCEDURE ClearExternField(node : HierarchicalProfiler.Node);
		BEGIN
			ASSERT(node # NIL);
			node.extern := FALSE;
		END ClearExternField;

		PROCEDURE UpdateTree;
		VAR root : WMTrees.TreeNode;
		BEGIN
			tree.Acquire;
			NEW(root);
			tree.SetRoot(root);
			IF (profile # NIL) THEN
				profile.Visit(ClearExternField);
				tree.SetNodeCaption(root, profile.nodes.GetCaption());
				tree.SetNodeData(root, profile);
				AddChildNodes(root, profile.nodes, TRUE);
			ELSE
				tree.SetNodeCaption(root, Strings.NewString("No profile data"));
			END;
			tree.Release;
			treeView.SetFirstLine(0, TRUE);
		END UpdateTree;

		PROCEDURE UpdateStatusBar(forceUpdate : BOOLEAN);
		VAR
			state, currentNofSamples, maxNofSamples : LONGINT;
			caption : ARRAY 256 OF CHAR; number : ARRAY 16 OF CHAR;
		BEGIN
			state := HierarchicalProfiler.GetState(currentNofSamples, maxNofSamples);
			IF (state # lastState) OR forceUpdate THEN
				IF (state = HierarchicalProfiler.Running) THEN
					progressBar.SetRange(0, maxNofSamples);
				END;

				CASE state OF
					|HierarchicalProfiler.Running: caption := "Profiler is running...";
					|HierarchicalProfiler.NotRunningNoDataAvailable: caption := "Profiler is not running. No profile data available.";
					|HierarchicalProfiler.NotRunningDataAvailable: caption := "Profiler is not running.";
				ELSE
					caption := "Profiler is in undefined state.";
				END;
				IF (profile # NIL) THEN
					Strings.Append(caption, " [Loaded profile: ");
					Strings.IntToStr(profile.nofSamples, number); Strings.Append(caption, number);
					Strings.Append(caption, " samples on ");
					Strings.IntToStr(profile.nofProcessors, number); Strings.Append(caption, number);
					Strings.Append(caption, " processor(s), ");
					Strings.IntToStr(profile.nofSamplesNotStored, number); Strings.Append(caption, number);
					Strings.Append(caption, " discarded, ");
					Strings.IntToStr(profile.nofRunsTooDeep, number); Strings.Append(caption, number);
					Strings.Append(caption, " call chain too deep]");
				ELSE
					Strings.Append(caption, " [No profile loaded]");
				END;
				statusLabel.caption.SetAOC(caption);
				lastState := state;
			END;
			IF (state = HierarchicalProfiler.Running) THEN
				progressBar.SetCurrent(currentNofSamples);
			END;
		END UpdateStatusBar;

		PROCEDURE HandleNodeClicked(sender, data : ANY);
		VAR treeNode : WMTrees.TreeNode; node : HierarchicalProfiler.Node; ptr : ANY;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				treeNode := data (WMTrees.TreeNode);
				ptr := tree.GetNodeData(treeNode);
				IF (ptr # NIL) & (ptr IS HierarchicalProfiler.Node) THEN
					node := ptr (HierarchicalProfiler.Node);
					IF ~node.extern THEN
						AddChildNodes(treeNode, node, FALSE);
					END;
				END;
				tree.Release;
			END;
		END HandleNodeClicked;

		PROCEDURE HandleNodeSelected(sender, data : ANY);
		VAR ptr : ANY;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				ptr := tree.GetNodeData(data(WMTrees.TreeNode));
				tree.Release;
				IF (ptr # NIL) & (ptr IS HierarchicalProfiler.Node) THEN
					lastSelectedNode := ptr (HierarchicalProfiler.Node);
				END;
			END;
		END HandleNodeSelected;

		PROCEDURE GetTypeAndInfo(VAR type, info : LONGINT);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			type := HierarchicalProfiler.Hierarchical;
			typeEdit.GetAsString(string);
			Strings.StrToInt(string, type);

			info := HierarchicalProfiler.None;
			infoEdit.GetAsString(string);
			Strings.StrToInt(string, info);
		END GetTypeAndInfo;

		PROCEDURE GetFilterMask(VAR mask : ARRAY OF CHAR; VAR minPercent : LONGINT);
		VAR number : ARRAY 16 OF CHAR;
		BEGIN
			filterMaskEdit.GetAsString(mask);
			filterCountEdit.GetAsString(number);
			Strings.StrToInt(number, minPercent);
		END GetFilterMask;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR
			tempProfile : HierarchicalProfiler.Profile;
			mask : ARRAY 128 OF CHAR; timeStr : ARRAY 16 OF CHAR;
			minPercent : LONGINT;
			time, type, info, res : LONGINT;
			root : WMTrees.TreeNode;
		BEGIN
			IF (sender = startBtn) THEN
				time := 0;
				timeEdit.GetAsString(timeStr);
				Strings.StrToInt(timeStr, time);
				IF (time > 0) THEN
					HierarchicalProfiler.StartProfiling(time, res);
					IF (res # HierarchicalProfiler.Ok) THEN WMErrors.Show(res); END;
				ELSE
					WMErrors.ShowMessage("Invalid sampling time");
				END;
			ELSIF (sender = stopBtn) THEN
				HierarchicalProfiler.StopProfiling(res);
				IF (res # HierarchicalProfiler.Ok) THEN WMErrors.Show(res); END;
			ELSIF (sender = continueBtn) THEN
				HierarchicalProfiler.ContinueProfiling(res);
				IF (res # HierarchicalProfiler.Ok) THEN WMErrors.Show(res); END;
			ELSIF (sender = flattenBtn) THEN
				IF (lastSelectedNode # NIL) THEN
					IF (profile # NIL) THEN
						profile.Flatten(lastSelectedNode);
						UpdateTree;
					ELSE
						WMErrors.ShowMessage("No profile");
					END;
				ELSE
					WMErrors.ShowMessage("No node selected");
				END;
			ELSIF (sender = getProfileBtn) THEN
				GetTypeAndInfo(type, info);
				HierarchicalProfiler.GetProfile(type, info, tempProfile, res);
				IF (res = HierarchicalProfiler.Ok) THEN
					profile := tempProfile;
					UpdateTree;
					UpdateStatusBar(TRUE);
				ELSE
					WMErrors.Show(res);
				END;
			ELSIF (sender = filterBtn) THEN
				IF (profile # NIL) THEN
					GetFilterMask(mask, minPercent);
					profile.Mark(mask, minPercent);
					tree.Acquire;
					root := tree.GetRoot();
					tree.Release;
					UpdateTree;
				ELSE
					WMErrors.ShowMessage("No profile");
				END;
			END;
		END HandleButtons;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel, toolbar, filterbar, statusbar : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			timeStr : ARRAY 16 OF CHAR;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient); panel.fillColor.Set(WMGraphics.White);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop); toolbar.bounds.SetHeight(20);
			panel.AddContent(toolbar);

			NEW(startBtn); startBtn.alignment.Set(WMComponents.AlignLeft);
			startBtn.caption.SetAOC("Start");
			startBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(startBtn);

			NEW(stopBtn); stopBtn.alignment.Set(WMComponents.AlignLeft);
			stopBtn.caption.SetAOC("Stop");
			stopBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(stopBtn);

			NEW(continueBtn); continueBtn.alignment.Set(WMComponents.AlignLeft);
			continueBtn.caption.SetAOC("Continue");
			continueBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(continueBtn);

			NEW(getProfileBtn); getProfileBtn.alignment.Set(WMComponents.AlignLeft);
			getProfileBtn.bounds.SetWidth(80);
			getProfileBtn.caption.SetAOC("Get Profile");
			getProfileBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(getProfileBtn);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(120);
			label.caption.SetAOC(" Max. sampling time: ");
			toolbar.AddContent(label);

			NEW(timeEdit); timeEdit.alignment.Set(WMComponents.AlignLeft); timeEdit.bounds.SetWidth(40);
			timeEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			timeEdit.multiLine.Set(FALSE);
			timeEdit.tv.showBorder.Set(TRUE);
			Strings.IntToStr(DefaultTime, timeStr);
			timeEdit.SetAsString(timeStr);
			toolbar.AddContent(timeEdit);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(45);
			label.caption.SetAOC(" seconds");
			toolbar.AddContent(label);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(35);
			label.caption.SetAOC(" Type: ");
			toolbar.AddContent(label);

			NEW(typeEdit); typeEdit.alignment.Set(WMComponents.AlignLeft); typeEdit.bounds.SetWidth(40);
			typeEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			typeEdit.multiLine.Set(FALSE);
			typeEdit.tv.showBorder.Set(TRUE);
			Strings.IntToStr(HierarchicalProfiler.Hierarchical, timeStr);
			typeEdit.SetAsString(timeStr);
			toolbar.AddContent(typeEdit);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(30);
			label.caption.SetAOC(" Info: ");
			toolbar.AddContent(label);

			NEW(infoEdit); infoEdit.alignment.Set(WMComponents.AlignLeft); infoEdit.bounds.SetWidth(40);
			infoEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			infoEdit.multiLine.Set(FALSE);
			infoEdit.tv.showBorder.Set(TRUE);
			Strings.IntToStr(0, timeStr);
			infoEdit.SetAsString(timeStr);
			toolbar.AddContent(infoEdit);

			NEW(flattenBtn); flattenBtn.alignment.Set(WMComponents.AlignRight);
			flattenBtn.caption.SetAOC("Flatten");
			flattenBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(flattenBtn);

			NEW(statusbar); statusbar.alignment.Set(WMComponents.AlignBottom); statusbar.bounds.SetHeight(20);
			statusbar.fillColor.Set(0CCCCCCFFH);
			panel.AddContent(statusbar);

			NEW(progressBar); progressBar.alignment.Set(WMComponents.AlignRight);
			progressBar.bounds.SetWidth(80);
			progressBar.color.Set(WMGraphics.Blue);
			progressBar.textColor.Set(WMGraphics.White);
			progressBar.SetRange(0, 100);
			progressBar.SetCurrent(0);
			progressBar.showPercents.Set(TRUE);
			statusbar.AddContent(progressBar);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignClient);
			statusbar.AddContent(statusLabel);

			NEW(filterbar); filterbar.alignment.Set(WMComponents.AlignBottom); filterbar.bounds.SetHeight(20);
			panel.AddContent(filterbar);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(110);
			label.caption.SetAOC(" Filter mask: Name: ");
			filterbar.AddContent(label);

			NEW(filterBtn); filterBtn.alignment.Set(WMComponents.AlignRight);
			filterBtn.caption.SetAOC("Apply");
			filterBtn.onClick.Add(HandleButtons);
			filterbar.AddContent(filterBtn);

			NEW(filterCountEdit); filterCountEdit.alignment.Set(WMComponents.AlignRight); filterCountEdit.bounds.SetWidth(40);
			filterCountEdit.multiLine.Set(FALSE);
			filterCountEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filterCountEdit.tv.showBorder.Set(TRUE);
			filterCountEdit.SetAsString("0");
			filterbar.AddContent(filterCountEdit);

			NEW(label); label.alignment.Set(WMComponents.AlignRight); label.bounds.SetWidth(40);
			label.caption.SetAOC(" Min %: ");
			filterbar.AddContent(label);

			NEW(filterMaskEdit); filterMaskEdit.alignment.Set(WMComponents.AlignClient);
			filterMaskEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filterMaskEdit.multiLine.Set(FALSE);
			filterMaskEdit.tv.showBorder.Set(TRUE);
			filterMaskEdit.SetAsString("*");
			filterbar.AddContent(filterMaskEdit);

			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treeView.onSelectNode.Add(HandleNodeSelected);
			tree := treeView.GetTree();
			tree.beforeExpand.Add(HandleNodeClicked);
			panel.AddContent(treeView);

			RETURN panel;
		END CreateForm;

		PROCEDURE &New*(context : WMRestorable.Context);
		BEGIN
			NEW(timer);
			alive := TRUE; dead := FALSE;
			lastSelectedNode := NIL;
			lastState := -1; (* invalid state *)
			profile := NIL;
			Init(640, 480, FALSE);
			SetContent(CreateForm());
			UpdateStatusBar(TRUE);
			SetTitle(Strings.NewString("Profiler"));
			IF (context # NIL) THEN
				WMRestorable.AddByContext(SELF, context);
				Resized(context.r - context.l, context.b - context.t);
			ELSE
				WMWindowManager.DefaultAddWindow(SELF)
			END;
			IncCount;
		END New;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMProfiler", "WMProfiler.Restore", SELF, NIL);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		BEGIN
			Close^;
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			DecCount;
		END Close;

	BEGIN {ACTIVE}
		WHILE alive DO
			UpdateStatusBar(FALSE);
			timer.Sleep(500);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR window : Window;
BEGIN
	NEW(window, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context);
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
	Modules.InstallTermHandler(Cleanup)
END WMProfiler.


WMProfiler.Open ~

SystemTools.Free WMProfiler ~