MODULE PETTrees; (** AUTHOR "?/staubesv"; PURPOSE "Interface for PET sidepanel trees"; *)

IMPORT
	KernelLog,
	Streams, Diagnostics, Strings, Texts, WMStandardComponents, WMGraphics, WMComponents,
	WMTextView, WMEditors, WMTrees, WMEvents;

CONST
	InvalidPosition* = -1;

TYPE

	(** data parameter for onGoToExternalModule event *)
	ExternalInfo* = OBJECT
	VAR
		filename- : ARRAY 32 OF CHAR;
		position- : LONGINT;

		PROCEDURE &Init*(CONST filename : ARRAY OF CHAR; position : LONGINT);
		BEGIN
			COPY(filename, SELF.filename);
			SELF.position := position;
		END Init;
	END ExternalInfo;

	(** data parameter for onGoToExternalDefinition event *)
	ExternalDefinitionInfo* = OBJECT
	VAR
		filename-, definition- : ARRAY 256 OF CHAR;

		PROCEDURE &Init*(CONST filename, definition : ARRAY OF CHAR);
		BEGIN
			COPY(filename, SELF.filename);
			COPY(definition, SELF.definition);
		END Init;
	END ExternalDefinitionInfo;

	RefreshParameters* = OBJECT
	VAR
		diagnostics : Diagnostics.Diagnostics;
		log : Streams.Writer;

		PROCEDURE &Init*(diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		BEGIN
			ASSERT((diagnostics # NIL) & (log # NIL));
			SELF.diagnostics := diagnostics;
			SELF.log := log;
		END Init;

	END RefreshParameters;

TYPE

	TreeNode* = OBJECT(WMTrees.TreeNode)
	VAR
		pos* : Texts.TextPosition;
		color* : LONGINT;
		font* : WMGraphics.Font;
		external* : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			pos := NIL;
			color := WMGraphics.Black;
			font := FontPlain;
			external := FALSE;
		END Init;

	END TreeNode;

TYPE

	Tree* = OBJECT (WMStandardComponents.Panel)
	VAR
		(* Protected fields *)
		editor-: WMEditors.Editor;
		tree-: WMTrees.Tree;
		treeView-: WMTrees.TreeView;
		toolbar-: WMStandardComponents.Panel;

		onExpandNode-: WMEvents.EventSource;
		onGoToFile- : WMEvents.EventSource;
		onGoToDefinition- : WMEvents.EventSource;

		onRefresh- : WMEvents.EventSource;

		label: WMStandardComponents.Label;
		refreshBtn, sortBtn: WMStandardComponents.Button;
		highlight- : WMTextView.Highlight;

		PROCEDURE & Init*;
		BEGIN
			Init^;

			NEW(onGoToFile, NIL, NIL, NIL, NIL); events.Add(onGoToFile);
			NEW(onGoToDefinition, NIL, NIL, NIL, NIL); events.Add(onGoToDefinition);

			NEW(onRefresh, SELF, NIL, NIL, NIL); events.Add(onRefresh);

			NEW(label); label.alignment.Set(WMComponents.AlignTop);
			label.fillColor.Set(0CCCCCCFFH);
			label.SetCaption(""); label.bounds.SetHeight(20);
			SELF.AddContent(label);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			SELF.AddContent(toolbar);

			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treeView.clSelected.Set(0B0B0FFA0H);
			treeView.SetFont(FontPlain);
			SELF.AddContent(treeView);

			tree := treeView.GetTree();
			treeView.SetDrawNodeProc(DrawNode);
			treeView.onClickNode.Add(ClickNode);
			treeView.onMiddleClickNode.Add(MiddleClickNode);
			onExpandNode := treeView.onExpandNode;

			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignLeft);
			refreshBtn.bounds.SetWidth(30);
			refreshBtn.imageName.Set(Strings.NewString("PETIcons.tar://refresh.png"));
			refreshBtn.onClick.Add(RefreshHandler);
			toolbar.AddContent(refreshBtn);

			NEW(sortBtn); sortBtn.alignment.Set(WMComponents.AlignLeft);
			sortBtn.caption.SetAOC("Sort");
			sortBtn.onClick.Add(SortHandler);
			toolbar.AddContent(sortBtn);
		END Init;

		PROCEDURE SetTitle*(CONST title : ARRAY OF CHAR);
		BEGIN
			label.caption.SetAOC(title);
		END SetTitle;

		PROCEDURE SetEditor*(e: WMEditors.Editor);
		BEGIN {EXCLUSIVE}
			IF e = editor THEN RETURN END;
			IF (highlight # NIL) & (editor # NIL) THEN
				editor.tv.RemoveHighlight(highlight);
				highlight := NIL
			END;
			editor := e;
			highlight := editor.tv.CreateHighlight();
			highlight.SetColor(LONGINT(0DDDD0060H));
			highlight.SetKind(WMTextView.HLOver)
		END SetEditor;

		PROCEDURE Erase*;
		BEGIN
			tree.Acquire;
			tree.SetRoot(NIL);
			tree.Release;
			treeView.SetFirstLine(0, TRUE);
			label.SetCaption("");
		END Erase;

		PROCEDURE GetNextNode(this : WMTrees.TreeNode; ignoreChildren : BOOLEAN) : WMTrees.TreeNode;
		VAR state : SET;
		BEGIN
			state := tree.GetNodeState(this);
			IF ~ignoreChildren  & (tree.GetChildren(this) # NIL) THEN RETURN tree.GetChildren(this);
			ELSIF tree.GetNextSibling(this) # NIL THEN RETURN tree.GetNextSibling(this)
			ELSIF tree.GetParent(this) # NIL THEN RETURN GetNextNode(tree.GetParent(this), TRUE)
			ELSE RETURN NIL
			END
		END GetNextNode;

		PROCEDURE RefreshHandler*(sender, data: ANY);
		TYPE
			StringList = POINTER TO ARRAY OF Strings.String;
		VAR
			rootNode: TreeNode;
			diagnostics : Diagnostics.Diagnostics;
			streamDiagnostics : Diagnostics.StreamDiagnostics; log, writer : Streams.Writer;
			dummyLog : Streams.StringWriter;
			nofOpenNodes : LONGINT;
			openNodes : StringList;
			i : LONGINT;

			PROCEDURE Store;
			VAR node, tnode : WMTrees.TreeNode;
				stack : ARRAY 32 OF WMTrees.TreeNode;
				caption : Strings.String;
				tos : LONGINT;
				path : ARRAY 1024 OF CHAR;
				sl, tl : StringList;
				i : LONGINT;
			BEGIN
				nofOpenNodes := 0;
				node := tree.GetRoot();
				NEW(sl, 16);
				WHILE node # NIL DO
					IF WMTrees.NodeExpanded IN tree.GetNodeState(node) THEN
						tnode := node;
						tos := 0;
						REPEAT
							stack[tos] := tnode; INC(tos);
							tnode := tree.GetParent(tnode)
						UNTIL tnode = NIL;
						DEC(tos);
						path := "";
						WHILE tos >= 0 DO
							caption := tree.GetNodeCaption(stack[tos]);
							Strings.Append(path, caption^);
							DEC(tos);
							IF tos >= 0 THEN Strings.Append(path, "/") END
						END;

						IF nofOpenNodes >= LEN(sl) THEN
							NEW(tl, LEN(sl) * 2);
							FOR i := 0 TO LEN(sl) - 1 DO tl[i] := sl[i] END;
							sl := tl
						END;
						sl[nofOpenNodes] := Strings.NewString(path); INC(nofOpenNodes)
					END;
					node := GetNextNode(node, FALSE)
				END;
				openNodes := sl
			END Store;

			PROCEDURE Expand(path : ARRAY OF CHAR);
			VAR node, tnode : WMTrees.TreeNode;
				pos : LONGINT;
				found : BOOLEAN;
				ident : ARRAY 64 OF CHAR;
				string : Strings.String;
			BEGIN
				node := tree.GetRoot();
				pos := Strings.Pos("/", path);
				IF pos > 0 THEN
					Strings.Copy(path, 0, pos, ident);
					Strings.Delete(path, 0, pos + 1)
				END;
				WHILE (path # "") & (node # NIL) DO
					pos := Strings.Pos("/", path);
					IF pos > 0 THEN
						Strings.Copy(path, 0, pos, ident);
						Strings.Delete(path, 0, pos + 1)
					ELSE COPY(path, ident); path := ""
					END;
					tnode := tree.GetChildren(node);
					found := FALSE;
					WHILE (tnode # NIL) & ~ found DO
						string := tree.GetNodeCaption(tnode);
						IF (string # NIL) & (string^ = ident) THEN
							node := tnode;
							found := TRUE
						END;
						tnode := tree.GetNextSibling(tnode)
					END
				END;

				tree.InclNodeState(node, WMTrees.NodeExpanded);
			END Expand;

		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.RefreshHandler, sender, data);
			ELSE
				IF (data # NIL) & (data IS RefreshParameters) THEN
					diagnostics := data(RefreshParameters).diagnostics;
					log := data(RefreshParameters).log;
					writer := NIL;
				ELSE
					NEW(writer, KernelLog.Send, 256);
					NEW(streamDiagnostics, writer); diagnostics := streamDiagnostics;
					NEW(dummyLog, 32); log := dummyLog;
				END;
				tree.Acquire;
				Store;
				editor.text.AcquireRead;
				rootNode := GetNewNode();
				tree.SetRoot(rootNode);
				AddNodes(rootNode, diagnostics, log);
				editor.text.ReleaseRead;
				i := 0;
				WHILE i < nofOpenNodes DO
					Expand(openNodes[i]^); INC(i)
				END;
				tree.Release;
				IF (writer # NIL) THEN
					writer.Update;
				END;
				treeView.SetFirstLine(0, TRUE);
				treeView.TreeChanged(SELF, NIL);
				onRefresh.Call(NIL);
			END;
		END RefreshHandler;

		PROCEDURE GetNewNode*() : TreeNode;
		VAR node : TreeNode;
		BEGIN
			NEW(node); RETURN node;
		END GetNewNode;

		PROCEDURE AddNodes*(parent : TreeNode; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		BEGIN
			ASSERT((parent # NIL) & (diagnostics # NIL) & (log # NIL));
			(* abstract *)
		END AddNodes;

		PROCEDURE SortHandler(sender, data: ANY);
		BEGIN
			tree.Acquire;
			SortTree(tree.GetRoot());
			tree.Release;
		END SortHandler;

		PROCEDURE SelectNodeByPos* (pos: LONGINT);
		VAR root, node: WMTrees.TreeNode;

			PROCEDURE FindNearestNode (node: WMTrees.TreeNode; pos: LONGINT): WMTrees.TreeNode;
			VAR nearestNode: WMTrees.TreeNode; distance, nearestDistance: LONGINT;

				PROCEDURE GetDistance (node: WMTrees.TreeNode; pos: LONGINT): LONGINT;
				BEGIN
					WHILE (node # NIL) & (~(node IS TreeNode) OR (node(TreeNode).pos = NIL)) DO
						node := tree.GetChildren(node);
					END;
					IF (node # NIL) & (node IS TreeNode) & (node(TreeNode).pos # NIL) & (pos >= node(TreeNode).pos.GetPosition()) THEN
						RETURN pos - node(TreeNode).pos.GetPosition()
					ELSE
						RETURN MAX(LONGINT)
					END
				END GetDistance;

			BEGIN
				nearestNode := NIL; nearestDistance := MAX (LONGINT);
				WHILE node # NIL DO
					IF (node IS TreeNode) & (node(TreeNode).external = FALSE) THEN
						distance := GetDistance (node, pos);
						IF distance < nearestDistance THEN nearestNode := node; nearestDistance := distance END;
					END;
					node := tree.GetNextSibling (node);
				END;
				RETURN nearestNode;
			END FindNearestNode;

		BEGIN
			tree.Acquire;
			root := FindNearestNode (tree.GetRoot (), pos); node := NIL;
			WHILE (root # NIL) & (WMTrees.NodeExpanded IN tree.GetNodeState (root)) & (tree.GetChildren (root) # NIL) DO
				node := FindNearestNode (tree.GetChildren (root), pos); root := node;
			END;
			tree.Release;
			IF (node # NIL) THEN treeView.SelectNode (node); END;
		END SelectNodeByPos;

		PROCEDURE BrowseToDefinition*(sender, data : ANY);
		BEGIN
		END BrowseToDefinition;

		PROCEDURE SortTree(parent: WMTrees.TreeNode);
		VAR
			n, left, right: WMTrees.TreeNode;
			nodeCount, i: LONGINT;
		BEGIN
			n := tree.GetChildren(parent);
			WHILE n # NIL DO
				SortTree(n);
				INC(nodeCount);
				n := tree.GetNextSibling(n);
			END;
			FOR i := 1 TO nodeCount-1 DO
				n := tree.GetChildren(parent);
				WHILE tree.GetNextSibling(n) # NIL DO
					left := n; right := tree.GetNextSibling(n);
					IF IsNodeGreater(left, right) THEN
						SwapSiblings(parent, left, right);
						n := left;
					ELSE
						n := right;
					END;
				END;
			END;
		END SortTree;

		PROCEDURE IsNodeGreater*(left, right: WMTrees.TreeNode): BOOLEAN;
		VAR leftCaption, rightCaption : Strings.String;
		BEGIN
			leftCaption := tree.GetNodeCaption(left);
			rightCaption := tree.GetNodeCaption(right);
			IF (leftCaption # NIL) & (rightCaption # NIL) THEN
				RETURN leftCaption^ > rightCaption^;
			ELSE
				RETURN FALSE;
			END;
		END IsNodeGreater;

		PROCEDURE SwapSiblings(parent, left, right: WMTrees.TreeNode);
		BEGIN
			ASSERT(tree.GetNextSibling(left) = right);
			tree.RemoveNode(left);
			tree.AddChildNodeAfter(parent, right, left);
		END SwapSiblings;

		PROCEDURE DrawNode(canvas: WMGraphics.Canvas; w, h: LONGINT; node: WMTrees.TreeNode; state: SET);
		VAR dx, tdx, tdy : LONGINT; f : WMGraphics.Font; image : WMGraphics.Image; caption: Strings.String;
		BEGIN
			dx := 0;

			image := tree.GetNodeImage(node);
			IF image # NIL THEN
				canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst); dx := image.width + 5;
			END;

			IF (node IS TreeNode) THEN
				canvas.SetColor(node(TreeNode).color);
				f := node(TreeNode).font;
				canvas.SetFont(f);
			ELSE
				canvas.SetColor(treeView.clTextDefault.Get());
				canvas.SetFont(treeView.GetFont());
				f := treeView.GetFont();
			END;
			caption := tree.GetNodeCaption(node);
			f.GetStringSize(caption^, tdx, tdy);
			IF WMTrees.StateSelected IN state THEN
				canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clSelected.Get(), WMGraphics.ModeSrcOverDst)
			ELSIF WMTrees.StateHover IN state THEN
				canvas.Fill(WMGraphics.MakeRectangle(0, 0, dx + tdx, h), treeView.clHover.Get(), WMGraphics.ModeSrcOverDst)
			END;
			IF caption # NIL THEN canvas.DrawString(dx, h - f.descent - 1 , caption^) END;
		END DrawNode;

		PROCEDURE SetEditorPosition*(position : LONGINT; doHighlight : BOOLEAN);
		VAR text : Texts.Text; a, b : LONGINT;
		BEGIN
			text := editor.text;
			text.AcquireRead;
			IF (position # InvalidPosition) THEN
				editor.tv.cursor.SetPosition(position);
				editor.tv.cursor.SetVisible(TRUE);
				IF doHighlight THEN
					editor.tv.FindCommand(position, a, b);
					highlight.SetFromTo(a, b);
				ELSE
					highlight.SetFromTo(0, 0); (* deactivate *)
				END;
			ELSE
				highlight.SetFromTo(0, 0);
			END;
			text.ReleaseRead;
			editor.SetFocus;
		END SetEditorPosition;

		PROCEDURE ClickNode*(sender, node : ANY);
		BEGIN
			IF (node # NIL) & (node IS TreeNode) & (node(TreeNode).pos # NIL) THEN
				KernelLog.String("POS");
				SetEditorPosition(node(TreeNode).pos.GetPosition(), TRUE);
			ELSE
				SetEditorPosition(InvalidPosition, FALSE);
			END;
		END ClickNode;

		PROCEDURE MiddleClickNode*(sender, data : ANY);
		BEGIN
			(* abstract *)
		END MiddleClickNode;

		PROCEDURE PrefixPostfixToCaption*(node: WMTrees.TreeNode; prePost: Strings.String; prefix: BOOLEAN); (** protected *)
		VAR
			oldCaption, newCaption: Strings.String;
			len: LONGINT;
		BEGIN
			oldCaption := tree.GetNodeCaption(node);
			len := LEN(oldCaption^) + LEN(prePost^);
			NEW(newCaption, len);
			IF prefix THEN
				Strings.Concat(prePost^, oldCaption^, newCaption^);
			ELSE
				Strings.Concat(oldCaption^, prePost^, newCaption^);
			END;
			tree.SetNodeCaption(node, newCaption);
		END PrefixPostfixToCaption;

		PROCEDURE AddPrefixToCaption*(node: WMTrees.TreeNode; prefix: Strings.String); (** protected *)
		BEGIN
			PrefixPostfixToCaption(node, prefix, TRUE);
		END AddPrefixToCaption;

		PROCEDURE AddPostfixToCaption*(node: WMTrees.TreeNode; postfix: Strings.String); (** protected *)
		BEGIN
			PrefixPostfixToCaption(node, postfix, FALSE);
		END AddPostfixToCaption;

		PROCEDURE AddNumberPostfixToCaption*(node : WMTrees.TreeNode; number : LONGINT); (** protected *)
		VAR postfix, nbr : ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToStr(number, nbr);
			postfix := " ("; Strings.Append(postfix, nbr); Strings.Append(postfix, ")");
			PrefixPostfixToCaption(node, Strings.NewString(postfix), FALSE);
		END AddNumberPostfixToCaption;

	END Tree;

	Factory* = PROCEDURE() : Tree;

VAR
	FontPlain-, FontBold-, FontItalic-: WMGraphics.Font;
	font : WMGraphics.Font;

BEGIN
	font := WMGraphics.GetDefaultFont();

	FontPlain := WMGraphics.GetFont(font.name, font.size, {});
	FontBold := WMGraphics.GetFont(font.name, font.size, {WMGraphics.FontBold});
	FontItalic := WMGraphics.GetFont(font.name, font.size, {WMGraphics.FontItalic});
END PETTrees.
