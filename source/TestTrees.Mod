MODULE TestTrees;	(** AUTHOR "TF"; PURPOSE "Testing Tree Component"; *)

IMPORT
	Strings, Modules,
	WMStandardComponents, WMComponents, WMGraphics, WMTrees, WMEditors,
	WM := WMWindowManager;

TYPE
	String = Strings.String;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		panel : WMStandardComponents.Panel;
		tree : WMTrees.TreeView;
		delete, add : WMStandardComponents.Button;
		node : WMTrees.TreeNode;
		editor : WMEditors.Editor;

		PROCEDURE &New*;
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(640, 420);
			panel.fillColor.Set(WMGraphics.RGBAToColor(255, 255, 255, 255));

			NEW(tree);
			tree.bounds.SetWidth(200);
			tree.alignment.Set(WMComponents.AlignLeft);
			tree.onSelectNode.Add(NodeSelected);
			panel.AddContent(tree);

			NEW(delete);
			delete.bounds.SetExtents(200, 20);
			delete.caption.SetAOC("Delete node");
			delete.alignment.Set(WMComponents.AlignTop);
			delete.onClick.Add(DeleteNode);
			panel.AddContent(delete);

			NEW(add);
			delete.bounds.SetExtents(200, 20);
			add.caption.SetAOC("Add sub-node");
			add.alignment.Set(WMComponents.AlignTop);
			add.onClick.Add(AddNode);
			panel.AddContent(add);

			NEW(editor);		(* A single line editor *)
			editor.bounds.SetHeight(30);
			editor.alignment.Set(WMComponents.AlignTop);
			editor.multiLine.Set(FALSE);
			editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editor.onEnter.Add(RenameNode);
			panel.AddContent(editor);

			FillTree;

			(* create the form window with panel size *)
			Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE);
			SetContent(panel);
			editor.SetAsString("Sub-Element");

			SetTitle(Strings.NewString("Hierarchy editor"));
			WM.DefaultAddWindow(SELF)
		END New;

		PROCEDURE NodeSelected(sender, data : ANY);
		VAR t : WMTrees.Tree; caption : String;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				node := data(WMTrees.TreeNode);
				t := tree.GetTree();
				t.Acquire;
				caption := t.GetNodeCaption(node);
				t.Release;
				IF caption # NIL THEN editor.SetAsString(caption^) END
			END
		END NodeSelected;

		PROCEDURE DeleteNode(sender, data : ANY);
		VAR t : WMTrees.Tree;
		BEGIN
			IF node # NIL THEN
				t := tree.GetTree();
				t.Acquire;
				t.RemoveNode(node);
				node := NIL;
				t.Release
			END
		END DeleteNode;

		PROCEDURE RenameNode(sender, data : ANY);
		VAR t : WMTrees.Tree; string : ARRAY 64 OF CHAR;
		BEGIN
			IF node # NIL THEN
				t := tree.GetTree();
				t.Acquire;
				editor.GetAsString(string);
				t.SetNodeCaption(node, Strings.NewString(string));
				t.Release
			END
		END RenameNode;

		PROCEDURE AddNode(sender, data : ANY);
		VAR t : WMTrees.Tree; new : WMTrees.TreeNode; string : ARRAY 64 OF CHAR;
		BEGIN
			IF node # NIL THEN
				t := tree.GetTree();
				t.Acquire;
				NEW(new);
				t.AddChildNode(node, new);
				editor.GetAsString(string);
				t.SetNodeCaption(new, Strings.NewString(string));
				t.Release
			END
		END AddNode;

		PROCEDURE FillTree;
		VAR t : WMTrees.Tree;
			root , sub : WMTrees.TreeNode;
		BEGIN
			t := tree.GetTree();
			t.Acquire;
			NEW(root);
			t.SetRoot(root);
			t.InclNodeState(root, WMTrees.NodeAlwaysExpanded);
			t.SetNodeCaption(root, Strings.NewString("Root"));

			NEW(sub);
			t.AddChildNode(root, sub);
			t.SetNodeCaption(sub, Strings.NewString("Sub"));
			t.Release
		END FillTree;

		PROCEDURE Close;
		BEGIN
			Close^;
			winstance := NIL
		END Close;

	END Window;

VAR
	winstance : Window;

PROCEDURE Open*;
BEGIN
	IF winstance = NIL THEN NEW(winstance) END;
END Open;

PROCEDURE Cleanup;
BEGIN
	IF winstance # NIL THEN winstance.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END TestTrees.

TestTrees.Open ~
SystemTools.Free TestTrees WMTrees ~
