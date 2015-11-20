MODULE ModuleTrees; (** AUTHOR "?"; PURPOSE "Visualize module structure as tree"; *)

IMPORT
	Streams, Commands, Diagnostics, WMStandardComponents, WMGraphics, WMProperties, WMComponents,
	WMTextView, WMEditors, Strings, Texts, TextUtilities, KernelLog,
	WMTrees, WMEvents,
	FoxScanner, ModuleParser;

CONST
	TreeLabelCaption = " Program Structure";
	TreeLabelCaptionError = " Program Structure (Errors)";

	ShowImages = TRUE;

	ImageActive = "ModuleTreesIcons.tar://activity.png";
	ImageCommandProc = "ModuleTreesIcons.tar://arrow-red.png";
	ImageContextProc = "ModuleTreesIcons.tar://arrow-green.png";

	(* Coloring for types *)
	ColorTypes =  000008FFFH;
	ColorObjects = WMGraphics.Blue;
	ColorActiveObjects = ColorObjects;

	(* Coloring for procedures *)
	ColorProcedure = WMGraphics.Black;
	ColorExclusive = WMGraphics.Red;
	ColorHasExclusiveBlock = WMGraphics.Magenta;

	SortIgnore = 1;
	SortProcedure = 2;
	SortNo = 90;
	SortBody = 99;

	(* TextInfo.flags *)
	NotPublic = 0;
	PosValid = 1;
	CanExecute = 2;

	(* Special procedure types *)
	Other = 0;
	CommandProc = 1; (* PROCEDURE(); *)
	ContextProc = 2; (* PROCEDURE(context : Commands.Context); *)

TYPE

	TextInfo = OBJECT
	VAR
		flags : SET;
		pos : Texts.TextPosition;
		name : Strings.String;
		color : LONGINT;
		sortInfo : LONGINT;
		font : WMGraphics.Font;
		node : ModuleParser.Node;
		modulename : ARRAY 32 OF CHAR;
		external : BOOLEAN;
		position : LONGINT;
	END TextInfo;

	ExternalInfo* = OBJECT
	VAR
		modulename- : ARRAY 32 OF CHAR;
		position- : LONGINT;
		node- : ModuleParser.Node;

		PROCEDURE &Init(CONST modulename : ARRAY OF CHAR; position : LONGINT; node : ModuleParser.Node);
		BEGIN
			COPY(modulename, SELF.modulename);
			SELF.position := position;
			SELF.node := node;
		END Init;
	END ExternalInfo;

	ModuleTree* = OBJECT (WMStandardComponents.Panel)
	VAR
		toolbar: WMStandardComponents.Panel;
		label: WMStandardComponents.Label;
		refreshBtn, sortBtn, publicBtn: WMStandardComponents.Button;
		treeView: WMTrees.TreeView;
		tree: WMTrees.Tree;
		editor: WMEditors.Editor;
		highlight : WMTextView.Highlight;
		showPublicOnly : BOOLEAN;
		showTypeHierarchy- : WMProperties.BooleanProperty;
		onExpandNode-: WMEvents.EventSource;
		onGoToExternalModule- : WMEvents.EventSource;

		module : ModuleParser.Module;
		diagnostics : Diagnostics.StreamDiagnostics;
		writer : Streams.Writer;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			showPublicOnly := FALSE;
			module := NIL;

			NEW(writer, KernelLog.Send, 256);
			NEW(diagnostics, writer);

			NEW(showTypeHierarchy, PrototypeShowTypeHierarchy, NIL, NIL); properties.Add(showTypeHierarchy);
			NEW(onGoToExternalModule, NIL, NIL, NIL, NIL); events.Add(onGoToExternalModule);

			NEW(label); label.alignment.Set(WMComponents.AlignTop);
			label.fillColor.Set(0CCCCCCFFH);
			label.SetCaption(TreeLabelCaption); label.bounds.SetHeight(20);
			SELF.AddContent(label);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			SELF.AddContent(toolbar);

			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treeView.clSelected.Set(0B0B0FFA0H);
			treeView.SetFont(treeFontPlain);
			SELF.AddContent(treeView);

			tree := treeView.GetTree();
			treeView.SetDrawNodeProc(DrawNode);
			treeView.onClickNode.Add(ClickNode);
			treeView.onMiddleClickNode.Add(MiddleClickNode);
			onExpandNode := treeView.onExpandNode;

			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignLeft);
			refreshBtn.caption.SetAOC("Refresh");
			refreshBtn.onClick.Add(RefreshHandler);
			toolbar.AddContent(refreshBtn);

			NEW(sortBtn); sortBtn.alignment.Set(WMComponents.AlignLeft);
			sortBtn.caption.SetAOC("Sort");
			sortBtn.onClick.Add(SortHandler);
			toolbar.AddContent(sortBtn);

			NEW(publicBtn); publicBtn.alignment.Set(WMComponents.AlignClient);
			publicBtn.caption.SetAOC("PublicOnly");
			publicBtn.isToggle.Set(TRUE);
			publicBtn.onClick.Add(ShowPublicHandler);
			toolbar.AddContent(publicBtn);
		END Init;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			IF (data = showTypeHierarchy) THEN
				RefreshHandler(NIL, NIL);
			ELSE
				PropertyChanged^(sender, data);
			END;
		END PropertyChanged;

		PROCEDURE SetEditor*(e: WMEditors.Editor);
		BEGIN
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
			label.SetCaption(TreeLabelCaption);
		END Erase;

		PROCEDURE ShowPublicHandler(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ShowPublicHandler, sender, data);
				RETURN
			END;
			showPublicOnly := ~showPublicOnly;
			publicBtn.SetPressed(showPublicOnly);
			tree.Acquire;
			SetNodeVisibilities(tree.GetRoot(), showPublicOnly);
			tree.Release;
		END ShowPublicHandler;

		PROCEDURE SetNodeVisibilities(parent : WMTrees.TreeNode; showPublicOnly : BOOLEAN);
		VAR n : WMTrees.TreeNode; state : SET; info : TextInfo; ptr : ANY;
		BEGIN
			n := tree.GetChildren(parent);
			WHILE n # NIL DO
				SetNodeVisibilities(n, showPublicOnly);
				state := tree.GetNodeState(n);
				ptr := tree.GetNodeData(n);
				IF (ptr # NIL) & (ptr IS TextInfo) THEN
					info := ptr (TextInfo);
					IF NotPublic IN info.flags THEN
						IF showPublicOnly THEN INCL(state, WMTrees.NodeHidden) ELSE EXCL(state, WMTrees.NodeHidden); END;
					END;
				END;
				tree.SetNodeState(n, state);
				n := tree.GetNextSibling(n);
			END;
		END SetNodeVisibilities;

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
			module: ModuleParser.Module;
			scanner: FoxScanner.Scanner;
			reader : TextUtilities.TextReader;
			rootNode: WMTrees.TreeNode;
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
				NEW(reader, editor.text);
				scanner := FoxScanner.NewScanner("ModuleTrees", reader, 0, diagnostics);
				ModuleParser.Parse(scanner, module);
				SELF.module := module;
				IF module # NIL THEN
					IF showTypeHierarchy.Get() THEN
						ModuleParser.SetSuperTypes(module);
					END;
					tree.Acquire;
					Store;
					editor.text.AcquireRead;
					NEW(rootNode);
					tree.SetRoot(rootNode);
					tree.SetNodeData(rootNode, GetTextInfo(module, module.ident, TRUE, SortIgnore, treeView.clTextDefault.Get(), {}));
					tree.SetNodeCaption(rootNode, module.ident.name);
					IF module.context # NIL THEN
						AddPostfixToCaption(rootNode, Strings.NewString(" IN "));
						AddPostfixToCaption(rootNode, module.context.name);
					END;
					AddImportList(rootNode, module.importList);
					AddDefinitions(rootNode, module.definitions);
					AddDeclSeq(rootNode, module.declSeq);
					IF module.bodyPos # 0 THEN
						AddBody (rootNode, module, module.modifiers, module.bodyPos);
					END;
					tree.SetNodeState(rootNode, {WMTrees.NodeExpanded});
					SetNodeVisibilities(rootNode, showPublicOnly);
					editor.text.ReleaseRead;
					i := 0;
					WHILE i < nofOpenNodes DO
						Expand(openNodes[i]^); INC(i)
					END;
					tree.Release;
					treeView.SetFirstLine(0, TRUE);
					IF module.hasError THEN label.SetCaption(TreeLabelCaptionError);
					ELSE label.SetCaption(TreeLabelCaption);
					END;
				END;
				treeView.TreeChanged(NIL, NIL);
			END;
		END RefreshHandler;

		PROCEDURE SortHandler(sender, data: ANY);
		BEGIN
			tree.Acquire;
			SortTree(tree.GetRoot());
			tree.Release;
		END SortHandler;

		PROCEDURE SelectNodeByPos* (pos: LONGINT);
		VAR root, node: WMTrees.TreeNode; data : ANY;

			PROCEDURE FindNearestNode (node: WMTrees.TreeNode; pos: LONGINT): WMTrees.TreeNode;
			VAR nearestNode: WMTrees.TreeNode; distance, nearestDistance: LONGINT;

				PROCEDURE GetDistance (node: WMTrees.TreeNode; pos: LONGINT): LONGINT;
				VAR data: ANY;
				BEGIN
					data := tree.GetNodeData (node);
					WHILE (node # NIL) & ((data = NIL) OR ~(data IS TextInfo) OR (data(TextInfo).pos = NIL)) DO
						node := tree.GetChildren (node); data := tree.GetNodeData (node);
					END;
					IF (data # NIL) & (data IS TextInfo) & (data(TextInfo).pos # NIL) & (pos >= data(TextInfo).pos.GetPosition ()) THEN
						RETURN pos - data(TextInfo).pos.GetPosition ()
					ELSE
						RETURN MAX(LONGINT)
					END
				END GetDistance;

			BEGIN
				nearestNode := NIL; nearestDistance := MAX (LONGINT);
				WHILE node # NIL DO
					data := tree.GetNodeData(node);
					IF (data # NIL) & (data IS TextInfo) & (data(TextInfo).external = FALSE) THEN
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

		PROCEDURE IsNodeGreater(left, right: WMTrees.TreeNode): BOOLEAN;
		VAR
			leftCaption, rightCaption, leftTmp, rightTmp: Strings.String;
			leftData, rightData: ANY;
		BEGIN
			leftData := tree.GetNodeData(left);
			rightData := tree.GetNodeData(right);
			IF (leftData # NIL) & (rightData # NIL) &
				(leftData IS TextInfo) & (rightData IS TextInfo) &
				(leftData(TextInfo).sortInfo >= rightData(TextInfo).sortInfo) &
				(leftData(TextInfo).font = rightData(TextInfo).font) &
				(leftData(TextInfo).sortInfo # SortNo) &
				(rightData(TextInfo).sortInfo # SortNo) THEN
					(* continue *)
			ELSE
				RETURN FALSE;
			END;
			leftCaption := tree.GetNodeCaption(left);
			rightCaption := tree.GetNodeCaption(right);
			IF (leftCaption^ = "VAR") OR (rightCaption^ = "VAR") OR
				(leftCaption^ = "CONST") OR (rightCaption^ = "CONST") OR
				(leftCaption^ = "IMPORT") OR (rightCaption^ = "IMPORT")
				THEN RETURN FALSE
			END;
			leftTmp := Strings.NewString(leftCaption^);
			rightTmp := Strings.NewString(rightCaption^);
			Strings.TrimLeft(leftTmp^, '-');
			Strings.TrimLeft(rightTmp^, '-');
			RETURN leftTmp^ > rightTmp^;
		END IsNodeGreater;

		PROCEDURE SwapSiblings(parent, left, right: WMTrees.TreeNode);
		BEGIN
			ASSERT(tree.GetNextSibling(left) = right);
			tree.RemoveNode(left);
			tree.AddChildNodeAfter(parent, right, left);
		END SwapSiblings;

		PROCEDURE DrawNode(canvas: WMGraphics.Canvas; w, h: LONGINT; node: WMTrees.TreeNode; state: SET);
		VAR dx, tdx, tdy : LONGINT; f : WMGraphics.Font; image : WMGraphics.Image;
			caption: Strings.String;
			ptr: ANY;
		BEGIN
			dx := 0;
			f := treeView.GetFont();

			image := tree.GetNodeImage(node);

			IF image # NIL THEN
				canvas.DrawImage(0, 0, image, WMGraphics.ModeSrcOverDst); dx := image.width + 5;
			END;

			ptr := tree.GetNodeData(node);
			IF (ptr # NIL) & (ptr IS TextInfo) THEN
				canvas.SetColor(ptr(TextInfo).color);
				f := ptr(TextInfo).font;
				canvas.SetFont(f);
			ELSE
				canvas.SetColor(treeView.clTextDefault.Get());
				canvas.SetFont(treeView.GetFont());
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

		PROCEDURE ClickNode(sender, data : ANY);
		VAR
			d: ANY;
			node : WMTrees.TreeNode;
			textInfo: TextInfo;
			a, b  : LONGINT;
			text : Texts.Text;
			moduleNode : ModuleParser.Module;
			extInfo : ExternalInfo;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				d := tree.GetNodeData(data(WMTrees.TreeNode));
				IF (d = NIL) OR ((d # NIL) & (d IS TextInfo) & (d(TextInfo).flags * {PosValid} = {})) THEN
					(* Use pos of child (for VAR, CONST and IMPORT) *)
					node := tree.GetChildren(data(WMTrees.TreeNode));
					IF (node # NIL) THEN
						d := tree.GetNodeData(node);
					END;
				END;
				tree.Release;

				IF (d # NIL) & (d IS TextInfo) & (d(TextInfo).node # NIL) THEN
					textInfo := d(TextInfo);
					moduleNode := GetModuleNode(textInfo.node);
					IF (moduleNode = module) THEN
						IF (textInfo.pos # NIL) THEN
							text := editor.text;
							text.AcquireRead;
							editor.tv.cursor.SetPosition(textInfo.pos.GetPosition());
							editor.tv.cursor.SetVisible(TRUE);
							IF (node = NIL) THEN
								editor.tv.FindCommand(textInfo.pos.GetPosition(), a, b);
								highlight.SetFromTo(a, b);
							ELSE
								highlight.SetFromTo(0, 0); (* deactivate *)
							END;
							text.ReleaseRead;
							editor.SetFocus;
						ELSE
							KernelLog.String("ModuleTrees.ModuleTree.ClickNode: Expected TextInfo.pos # NIL"); KernelLog.Ln;
						END;
					ELSE
						NEW(extInfo, textInfo.modulename, textInfo.position, textInfo.node);
						onGoToExternalModule.Call(extInfo);
					END;
				END
			END
		END ClickNode;

		PROCEDURE MiddleClickNode(sender, data : ANY);
		VAR d : ANY; commandStr, ignoreMsg : ARRAY 128 OF CHAR; len, ignore : LONGINT;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				d := tree.GetNodeData(data(WMTrees.TreeNode));
				tree.Release;
				IF (d # NIL) & (d IS TextInfo) & (CanExecute IN d(TextInfo).flags) & (d(TextInfo).name # NIL) &
					(module # NIL) & (module.ident # NIL) & (module.ident.name # NIL)
				THEN
					COPY(module.ident.name^, commandStr);
					Strings.Append(commandStr, Commands.Delimiter);
					Strings.Append(commandStr, d(TextInfo).name^);
					len := Strings.Length(commandStr);
					IF (commandStr[len-1] = "*") THEN commandStr[len-1] := 0X; END;
					Commands.Activate(commandStr, NIL, {}, ignore, ignoreMsg);
				END;
			END;
		END MiddleClickNode;

		PROCEDURE GetTextInfo(node : ModuleParser.Node; infoItem: ModuleParser.InfoItem; isPublic : BOOLEAN; sortInfo, color: LONGINT; style: SET): TextInfo;
		VAR newInfo: TextInfo; moduleNode : ModuleParser.Module; font: WMGraphics.Font;
		BEGIN
			NEW(newInfo);
			newInfo.node := node;
			newInfo.flags := {};
			IF ~isPublic THEN INCL(newInfo.flags, NotPublic); END;
			newInfo.sortInfo := sortInfo;
			newInfo.color := color;
			IF style = {} THEN
				font := treeFontPlain;
			ELSIF style = {WMGraphics.FontBold} THEN
				font := treeFontBold;
			ELSIF style = {WMGraphics.FontItalic} THEN
				font := treeFontItalic;
			ELSE
				(* unknown style *)
				font := treeFontPlain;
			END;
			IF (node # NIL) THEN
				moduleNode := GetModuleNode(node);
			ELSE
				moduleNode := NIL;
			END;
			newInfo.font := font;
			IF (infoItem # NIL) THEN
				newInfo.name := infoItem.name;
				newInfo.position := infoItem.pos;
				INCL(newInfo.flags, PosValid);
				IF (moduleNode = NIL) OR (moduleNode = module) THEN
					newInfo.external := FALSE;
					newInfo.modulename := "";
					NEW(newInfo.pos, editor.text);
					newInfo.pos.SetPosition(infoItem.pos);
				ELSE
					newInfo.external := TRUE;
					newInfo.pos := NIL;
					COPY(moduleNode.ident.name^, newInfo.modulename);
				END;
			END;
			RETURN newInfo;
		END GetTextInfo;

		PROCEDURE IsPublic(identDef : ModuleParser.IdentDef) : BOOLEAN;
		BEGIN
			RETURN (identDef.vis = ModuleParser.Public) OR (identDef.vis = ModuleParser.PublicRO);
		END IsPublic;

		PROCEDURE HasPublicConsts(constDecl: ModuleParser.ConstDecl) : BOOLEAN;
		VAR n : ModuleParser.NodeList; c  : ModuleParser.ConstDecl;
		BEGIN
			n := constDecl;
			WHILE (n # NIL) DO
				c := n (ModuleParser.ConstDecl);
				IF IsPublic(c.identDef) THEN RETURN TRUE; END;
				n := n.next;
			END;
			RETURN FALSE;
		END HasPublicConsts;

		PROCEDURE HasPublicVars(varDecl : ModuleParser.VarDecl) : BOOLEAN;
		VAR n, ni : ModuleParser.NodeList;
		BEGIN
			n := varDecl;
			WHILE (n # NIL) DO
				ni := n(ModuleParser.VarDecl).identList;
				WHILE (ni # NIL) DO
					IF IsPublic(ni(ModuleParser.IdentList).identDef) THEN RETURN TRUE; END;
					ni := ni.next;
				END;
				n := n.next;
			END;
			RETURN FALSE;
		END HasPublicVars;

		PROCEDURE GetModuleNode(node : ModuleParser.Node) : ModuleParser.Module;
		VAR n : ModuleParser.Node;
		BEGIN
		 	ASSERT(node # NIL);
			n := node;
			WHILE (n # n.parent) DO n := n.parent; END;
			IF (n # NIL) & (n IS ModuleParser.Module) THEN
				RETURN n (ModuleParser.Module);
			ELSE
				RETURN NIL;
			END;
		END GetModuleNode;

		PROCEDURE GetProcedureType(procHead : ModuleParser.ProcHead) : LONGINT;
		VAR type : LONGINT;

			PROCEDURE InModuleScope(procHead : ModuleParser.ProcHead) : BOOLEAN;
			BEGIN
				RETURN (procHead # NIL) & (procHead.parent.parent.parent = module);
			END InModuleScope;

			PROCEDURE IsCommandProc(procHead : ModuleParser.ProcHead) : BOOLEAN;
			BEGIN
				RETURN (procHead # NIL) & (procHead.formalPars = NIL);
			END IsCommandProc;

			PROCEDURE IsContextProc(procHead : ModuleParser.ProcHead) : BOOLEAN;
			BEGIN
				RETURN (procHead # NIL) & (procHead.formalPars # NIL) & (procHead.formalPars.fpSectionList # NIL) &
					(procHead.formalPars.fpSectionList.next = NIL) & (procHead.formalPars.fpSectionList.const = FALSE) &
					(procHead.formalPars.fpSectionList.var = FALSE) & (procHead.formalPars.fpSectionList.type.qualident # NIL) &
					(procHead.formalPars.fpSectionList.type.qualident.ident.name^ = "Commands.Context");
			END IsContextProc;

		BEGIN
			type := Other;
			IF InModuleScope(procHead) & (procHead.identDef.vis = ModuleParser.Public) & ~(procHead.operator) & ~(procHead.inline) THEN
				IF IsCommandProc(procHead) THEN
					type := CommandProc;
				ELSIF IsContextProc(procHead) THEN
					type := ContextProc;
				END;
			END;
			RETURN type;
		END GetProcedureType;

		PROCEDURE AddBody (root: WMTrees.TreeNode; pnode : ModuleParser.Node; modifiers: SET; pos: LONGINT);
		VAR node: WMTrees.TreeNode; info: TextInfo;
		BEGIN
			node := NewNode(root, Strings.NewString("BODY"));
			info := GetTextInfo(pnode, NIL, FALSE, SortBody, GetColor(modifiers, treeView.clTextDefault.Get()), {});
			NEW(info.pos, editor.text);
			info.pos.SetPosition(pos);
			INCL(info.flags, PosValid);
			tree.SetNodeData(node, info);
		END AddBody;

		PROCEDURE AddImportList(parent: WMTrees.TreeNode; importList: ModuleParser.Import);
		VAR
			n: ModuleParser.NodeList;
			newNode, importNode: WMTrees.TreeNode;
			info : TextInfo;
			import: ModuleParser.Import;
			nofImports : LONGINT;
		BEGIN
			n := importList;
			IF n # NIL THEN
				NEW(importNode);
				info := GetTextInfo(importList, NIL, FALSE, SortIgnore, treeView.clTextDefault.Get(), {});
				tree.SetNodeData(importNode, info);
				tree.SetNodeCaption(importNode, Strings.NewString("IMPORT"));
				tree.AddChildNode(parent, importNode);
			ELSE
				importNode := NIL;
			END;
			nofImports := 0;
			WHILE n # NIL DO
				import := n(ModuleParser.Import);
				newNode := AddInfoItem(importNode, import, import.ident, TRUE, SortIgnore, treeView.clTextDefault.Get(), {});
				IF import.alias # NIL THEN
					AddPostfixToCaption(newNode, Strings.NewString(" := "));
					AddPostfixToCaption(newNode, import.alias.name);
				END;
				IF import.context # NIL THEN
					AddPostfixToCaption(newNode, Strings.NewString(" IN "));
					AddPostfixToCaption(newNode, import.context.name);
				END;
				IF (newNode # NIL) THEN INC(nofImports); END;
				n := n.next;
			END;
			IF (importNode # NIL) THEN AddNumberPostfixToCaption(importNode, nofImports); END;
		END AddImportList;

		PROCEDURE AddDefinitions(parent: WMTrees.TreeNode; definitions: ModuleParser.Definition);
		VAR n, p: ModuleParser.NodeList; defNode, newNode: WMTrees.TreeNode;
		BEGIN
			n := definitions;
			WHILE n # NIL DO
				defNode := AddInfoItem(parent, n, n(ModuleParser.Definition).ident, TRUE, SortIgnore, WMGraphics.Green, {WMGraphics.FontItalic});
				p := n(ModuleParser.Definition).procs;
				WHILE p # NIL DO
					newNode := AddProcHead(defNode, p(ModuleParser.ProcHead));
					p := p.next;
				END;
				n := n.next;
			END;
		END AddDefinitions;

		PROCEDURE AddDeclSeq(parent: WMTrees.TreeNode; declSeq: ModuleParser.DeclSeq);
		VAR n: ModuleParser.NodeList; newNode: WMTrees.TreeNode; info : TextInfo;
		BEGIN
			n := declSeq;
			WHILE n # NIL DO
				declSeq := n(ModuleParser.DeclSeq);
				IF (declSeq.constDecl # NIL) THEN
					NEW(newNode);
					info := GetTextInfo(declSeq.constDecl, NIL, HasPublicConsts(declSeq.constDecl), SortIgnore, treeView.clTextDefault.Get(), {});
					tree.SetNodeData(newNode, info);
					tree.SetNodeCaption(newNode, Strings.NewString("CONST"));
					tree.AddChildNode(parent, newNode);
					AddConstDecl(newNode, declSeq.constDecl);
				END;
				IF declSeq.typeDecl # NIL THEN
					AddTypeDecl(parent, declSeq.typeDecl);
				END;
				IF (declSeq.varDecl # NIL) THEN
					NEW(newNode);
					info := GetTextInfo(declSeq.varDecl, NIL, HasPublicVars(declSeq.varDecl), SortIgnore, treeView.clTextDefault.Get(), {});
					tree.SetNodeData(newNode, info);
					tree.SetNodeCaption(newNode, Strings.NewString("VAR"));
					tree.AddChildNode(parent, newNode);
					AddVarDecl(newNode, declSeq.varDecl);
				END;
				IF declSeq.procDecl # NIL THEN
					AddProcDecl(parent, declSeq.procDecl);
				END;
				n := n.next;
			END;
		END AddDeclSeq;

		PROCEDURE AddProcDecl(treeNode: WMTrees.TreeNode; procDecl: ModuleParser.ProcDecl);
		VAR n: ModuleParser.NodeList; newNode: WMTrees.TreeNode;
		BEGIN
			n := procDecl;
			WHILE n # NIL DO
				procDecl := n(ModuleParser.ProcDecl);
				newNode := AddProcHead(treeNode, procDecl.head);
				IF (procDecl.declSeq # NIL) & (newNode # NIL) THEN
					AddDeclSeq(newNode, procDecl.declSeq);
				END;
				IF procDecl.bodyPos # 0 THEN
					AddBody (newNode, procDecl,  {}, procDecl.bodyPos);
				END;
				n := n.next;
			END;
		END AddProcDecl;

		PROCEDURE AddProcHead(treeNode: WMTrees.TreeNode; procHead: ModuleParser.ProcHead): WMTrees.TreeNode;
		VAR
			newNode: WMTrees.TreeNode; caption: Strings.String;
			color : LONGINT; image : WMGraphics.Image; type : LONGINT; d : ANY;
		BEGIN
			IF (procHead # NIL) THEN
				color := GetColor(procHead.modifiers, ColorProcedure);
				newNode :=  AddIdentDef(treeNode, procHead, procHead.identDef, SortProcedure, color, {WMGraphics.FontBold});
				IF procHead.operator THEN
					IF procHead.identDef.vis = ModuleParser.Public THEN
							(* remove visibility sign (ugly) *)
						caption := tree.GetNodeCaption(newNode);
						Strings.TrimRight(caption^, '*');
					END;
					AddPrefixToCaption(newNode, Strings.NewString('"'));
					AddPostfixToCaption(newNode, Strings.NewString('"'));
					IF procHead.identDef.vis = ModuleParser.Public THEN
							(* add visibility sign (still ugly) *)
						AddPostfixToCaption(newNode, Strings.NewString("*"));
					END;
				END;
				IF procHead.constructor THEN
					AddPrefixToCaption(newNode, Strings.NewString("& "));
				END;
				IF procHead.inline THEN
					AddPrefixToCaption(newNode, Strings.NewString("-"));
				END;

				type := GetProcedureType(procHead);
				IF (type = CommandProc) OR (type = ContextProc) THEN
					tree.Acquire;
					d := tree.GetNodeData(newNode);
					IF (d # NIL) & (d IS TextInfo) THEN INCL(d(TextInfo).flags, CanExecute); END;
					tree.Release;
				END;

				IF ShowImages THEN
					CASE type OF
						|CommandProc: image := WMGraphics.LoadImage(ImageCommandProc, TRUE);
						|ContextProc: image := WMGraphics.LoadImage(ImageContextProc, TRUE);
					ELSE
						image := NIL;
					END;
					IF image # NIL THEN
						tree.Acquire; tree.SetNodeImage(newNode, image); tree.Release;
					END;
				END;

				IF (ModuleParser.Overwrite IN procHead.modifiers) THEN
					AddPostfixToCaption(newNode, Strings.NewString(" [overwrite]"));
				END;

				IF (ModuleParser.Overwritten IN procHead.modifiers) THEN
					AddPostfixToCaption(newNode, Strings.NewString(" [overwritten]"));
				END;

				AddFormalPars(newNode, procHead.formalPars);
				RETURN newNode;
			ELSE
				RETURN NIL;
			END
		END AddProcHead;

		PROCEDURE AddFormalPars(parent: WMTrees.TreeNode; formalPars: ModuleParser.FormalPars);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF formalPars # NIL THEN
				AddFPSection(parent, formalPars.fpSectionList);
				NEW(newNode);
				tree.SetNodeCaption(newNode, Strings.NewString("RETURN"));
				IF formalPars.returnType # NIL THEN
					AddType(newNode, formalPars.returnType, TRUE);
					tree.AddChildNode(parent, newNode);
				END;
			END;
		END AddFormalPars;

		PROCEDURE AddFPSection(parent: WMTrees.TreeNode; fpSection: ModuleParser.FPSection);
		VAR newNode: WMTrees.TreeNode; n, l: ModuleParser.NodeList; ptr : ANY;
		BEGIN
			n := fpSection;
			WHILE n # NIL DO
				l := n(ModuleParser.FPSection).identList;
				WHILE l # NIL DO
					newNode := AddIdentDef(parent, l, l(ModuleParser.IdentList).identDef, SortIgnore, treeView.clTextDefault.Get(), {});
					(* Make parameters always visible *)
					ptr := tree.GetNodeData(newNode);
					IF (ptr # NIL) & (ptr IS TextInfo) THEN
						EXCL(ptr(TextInfo).flags, NotPublic);
					END;
					IF n(ModuleParser.FPSection).var THEN
						AddPostfixToCaption(newNode, Strings.NewString(" (VAR)"));
					ELSIF n(ModuleParser.FPSection).const THEN
						AddPostfixToCaption(newNode, Strings.NewString(" (CONST)"));
					END;
					AddType(newNode, n(ModuleParser.FPSection).type, FALSE);
					l := l.next;
				END;
				n := n.next;
			END;
		END AddFPSection;

		PROCEDURE AddVarDecl(parent: WMTrees.TreeNode; varDecl: ModuleParser.VarDecl);
		VAR n: ModuleParser.NodeList; nofVariables, nofIdents : LONGINT;
		BEGIN
			n := varDecl; nofVariables := 0;
			WHILE n # NIL DO
				varDecl := n(ModuleParser.VarDecl);
				AddIdentList(parent, varDecl.identList, nofIdents);
				nofVariables := nofVariables + nofIdents;
				n := n.next;
			END;
			AddNumberPostfixToCaption(parent, nofVariables);
		END AddVarDecl;

		PROCEDURE AddTypeDecl(parent: WMTrees.TreeNode; typeDecl: ModuleParser.TypeDecl);
		VAR n: ModuleParser.NodeList; newNode: WMTrees.TreeNode;
		BEGIN
			n := typeDecl;
			WHILE n # NIL DO
				newNode := AddIdentDef(parent, n, n(ModuleParser.TypeDecl).identDef, SortIgnore, ColorTypes, {WMGraphics.FontItalic});
				AddType(newNode, n(ModuleParser.TypeDecl).type, FALSE);
				n := n.next;
			END;
		END AddTypeDecl;

		PROCEDURE AddType(parent: WMTrees.TreeNode; type: ModuleParser.Type; anonymous: BOOLEAN);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF type # NIL THEN
				IF type.qualident # NIL THEN
					newNode := AddQualident(parent, type.qualident, treeView.clTextDefault.Get(), {});
				ELSIF type.array # NIL THEN
					AddArray(parent, type.array);
				ELSIF type.record # NIL THEN
					AddRecord(parent, type.record, anonymous, TRUE);
				ELSIF type.pointer # NIL THEN
					AddPointer(parent, type.pointer);
				ELSIF type.object # NIL THEN
					AddObject(parent, type.object, anonymous, TRUE);
				ELSIF type.procedure # NIL THEN
					AddProcedure(parent, type.procedure);
				END;
			END;
		END AddType;

		PROCEDURE AddRecord(parent: WMTrees.TreeNode; record: ModuleParser.Record; anonymous, addSuperRecords: BOOLEAN);
		VAR p: WMTrees.TreeNode;
		BEGIN
			IF record # NIL THEN
				IF anonymous THEN p := NewNode(parent, Strings.NewString("RECORD"));
				ELSE p := parent;
				END;
				IF addSuperRecords THEN AddSuperRecords(parent, record); END;
				IF record.super # NIL THEN
					AddPostfixToCaption(p, Strings.NewString(" ("));
					AddPostfixToCaption(p, record.super.ident.name);
					AddPostfixToCaption(p, Strings.NewString(")"));
				END;
				AddFieldDecl(p, record.fieldList);
			END;
		END AddRecord;

		PROCEDURE AddFieldDecl(parent: WMTrees.TreeNode; fieldDecl: ModuleParser.FieldDecl);
		VAR newNode: WMTrees.TreeNode; n, l: ModuleParser.NodeList;
		BEGIN
			n := fieldDecl;
			WHILE n # NIL DO
				l := n(ModuleParser.FieldDecl).identList;
				WHILE l # NIL DO
					newNode := AddIdentDef(parent, l, l(ModuleParser.IdentList).identDef, SortIgnore, treeView.clTextDefault.Get(), {});
					AddType(newNode, n(ModuleParser.FieldDecl).type, FALSE);
					l := l.next;
				END;
				n := n.next;
			END;
		END AddFieldDecl;

		PROCEDURE AddPointer(parent: WMTrees.TreeNode; pointer: ModuleParser.Pointer);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF pointer # NIL THEN
				newNode := NewNode(parent, Strings.NewString("POINTER TO"));
				IF (pointer.type # NIL) & (pointer.type.record # NIL) & (pointer.type.record.super # NIL) THEN
					AddPostfixToCaption(parent, Strings.NewString(" ("));
					AddPostfixToCaption(parent, pointer.type.record.super.ident.name);
					AddPostfixToCaption(parent, Strings.NewString(")"));
				END;
				AddType(newNode, pointer.type, TRUE);
			END;
		END AddPointer;

		PROCEDURE AddArray(parent: WMTrees.TreeNode; array: ModuleParser.Array);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF array # NIL THEN
				newNode := NewNode(parent, Strings.NewString("ARRAY "));
				IF ~array.open THEN
					IF (array.len # NIL) & (array.len.name # NIL) THEN
						AddPostfixToCaption(newNode, array.len.name);
						AddPostfixToCaption(newNode, Strings.NewString(" "));
					END;
				END;
				AddPostfixToCaption(newNode, Strings.NewString("OF"));
				AddType(newNode, array.base, TRUE);
			END;
		END AddArray;

		PROCEDURE NewNode(parent: WMTrees.TreeNode; caption: Strings.String): WMTrees.TreeNode;
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF parent # NIL THEN
				NEW(newNode);
				tree.SetNodeCaption(newNode, caption);
				tree.AddChildNode(parent, newNode);
			END;
			RETURN newNode;
		END NewNode;

		PROCEDURE AddQualident(parent: WMTrees.TreeNode; qualident: ModuleParser.Qualident; color: LONGINT; style: SET):
				WMTrees.TreeNode;
		VAR newNode: WMTrees.TreeNode;
			n: ModuleParser.NodeList;
		BEGIN
			IF qualident # NIL THEN
				newNode := AddInfoItem(parent, qualident, qualident.ident, TRUE, SortIgnore, color, style);
				n := qualident.next;
				WHILE n # NIL DO
					AddPostfixToCaption(newNode, Strings.NewString(", "));
					AddPostfixToCaption(newNode, n(ModuleParser.Qualident).ident.name);
					n := n.next;
				END;
			END;
			RETURN newNode;
		END AddQualident;

		PROCEDURE AddSuperRecords(parent : WMTrees.TreeNode; record : ModuleParser.Record);
		VAR
			newNode : WMTrees.TreeNode;
			superRecord : ModuleParser.Record;
			moduleNode : ModuleParser.Module;
			node : ModuleParser.Node;
			typeDecl : ModuleParser.TypeDecl;
			caption : ARRAY 256 OF CHAR;
			info : TextInfo;
		BEGIN
			ASSERT(record # NIL);
			superRecord := record.superPtr;
			WHILE (superRecord # NIL) DO
				NEW(newNode);
				info := GetTextInfo(superRecord, NIL, TRUE, SortNo, WMGraphics.Black, {WMGraphics.FontItalic});
				tree.SetNodeData(newNode, info);
				caption := "";
				moduleNode := GetModuleNode(superRecord);
				IF (moduleNode # module) THEN
					Strings.Append(caption, moduleNode.ident.name^); Strings.Append(caption, ".");
				END;
				node := superRecord.parent.parent;
				WHILE (node # NIL) & ~(node IS ModuleParser.TypeDecl) DO node := node.parent; END;
				IF (node # NIL) THEN
					typeDecl := node (ModuleParser.TypeDecl);
					Strings.Append(caption, typeDecl.identDef.ident.name^);
				ELSE
					caption := "ERROR!";
				END;
				tree.SetNodeCaption(newNode, Strings.NewString(caption));
				tree.AddChildNode(parent, newNode);
				AddRecord(newNode, superRecord, FALSE, FALSE);
				info.color := WMGraphics.Black;
				superRecord := superRecord.superPtr;
			END;
		END AddSuperRecords;

		PROCEDURE AddSuperClasses(parent : WMTrees.TreeNode; object : ModuleParser.Object);
		VAR
			newNode : WMTrees.TreeNode;
			superClass : ModuleParser.Object;
			moduleNode : ModuleParser.Module;
			typeDecl : ModuleParser.TypeDecl;
			caption : ARRAY 256 OF CHAR;
			info : TextInfo;
		BEGIN
			ASSERT(object # NIL);
			superClass := object.superPtr;
			WHILE (superClass # NIL) DO
				NEW(newNode);
				info := GetTextInfo(superClass, NIL, TRUE, SortNo, WMGraphics.Black, {WMGraphics.FontItalic});
				tree.SetNodeData(newNode, info);
				caption := "";
				moduleNode := GetModuleNode(superClass);
				IF (moduleNode # module) THEN
					Strings.Append(caption, moduleNode.ident.name^); Strings.Append(caption, ".");
				END;
				typeDecl := superClass.parent.parent (ModuleParser.TypeDecl);
				Strings.Append(caption, typeDecl.identDef.ident.name^);
				tree.SetNodeCaption(newNode, Strings.NewString(caption));
				tree.AddChildNode(parent, newNode);
				AddObject(newNode, superClass, FALSE, FALSE);
				info.color := WMGraphics.Black;
				superClass := superClass.superPtr;
			END;
		END AddSuperClasses;

		PROCEDURE AddObject(parent: WMTrees.TreeNode; object: ModuleParser.Object; anonymous, addSuperClasses: BOOLEAN);
		VAR newNode, p: WMTrees.TreeNode; ptr : ANY; ti : TextInfo; image : WMGraphics.Image;
		BEGIN
			IF object # NIL THEN
				IF anonymous THEN p := NewNode(parent, Strings.NewString("OBJECT"));
				ELSE p := parent;
				END;
				ptr := tree.GetNodeData(p);
				IF (ptr # NIL) & (ptr IS TextInfo) THEN
					ti := ptr (TextInfo);
					ti.color := ColorObjects;
				ELSE ti := NIL;
				END;
				IF ModuleParser.Active IN object.modifiers THEN
					IF (ti # NIL)  THEN
						ti.color := ColorActiveObjects;
					END;
					IF ShowImages THEN
						image := WMGraphics.LoadImage(ImageActive, TRUE);
						IF image # NIL THEN
							tree.Acquire; tree.SetNodeImage(p, image); tree.Release;
						END;
					END;
				END;
				IF (object.super # NIL) & addSuperClasses THEN
					AddPostfixToCaption(p, Strings.NewString(" ("));
					AddPostfixToCaption(p, object.super.ident.name);
					AddPostfixToCaption(p, Strings.NewString(")"));
				END;
				IF object.implements # NIL THEN
					newNode := AddQualident(p, object.implements, treeView.clTextDefault.Get(), {});
					AddPrefixToCaption(newNode, Strings.NewString("Implements "));
				END;
				IF addSuperClasses THEN
					AddSuperClasses(p, object);
				END;
				IF object.declSeq # NIL THEN
					AddDeclSeq(p, object.declSeq);
				END;
				IF object.bodyPos # 0 THEN
					AddBody (p, object, object.modifiers, object.bodyPos);
				END;
			END;
		END AddObject;

		PROCEDURE AddProcedure(parent: WMTrees.TreeNode; proc: ModuleParser.Procedure);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF proc # NIL THEN
				newNode := NewNode(parent, Strings.NewString("PROCEDURE"));
				IF proc.delegate THEN AddPostfixToCaption(newNode, Strings.NewString(" {DELEGATE}")) END;
				AddFormalPars(newNode, proc.formalPars);
			END;
		END AddProcedure;

		PROCEDURE PrefixPostfixToCaption(node: WMTrees.TreeNode; prePost: Strings.String; prefix: BOOLEAN);
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

		PROCEDURE AddPrefixToCaption(node: WMTrees.TreeNode; prefix: Strings.String);
		BEGIN
			PrefixPostfixToCaption(node, prefix, TRUE);
		END AddPrefixToCaption;

		PROCEDURE AddPostfixToCaption(node: WMTrees.TreeNode; postfix: Strings.String);
		BEGIN
			PrefixPostfixToCaption(node, postfix, FALSE);
		END AddPostfixToCaption;

		PROCEDURE AddNumberPostfixToCaption(node : WMTrees.TreeNode; number : LONGINT);
		VAR postfix, nbr : ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToStr(number, nbr);
			postfix := " ("; Strings.Append(postfix, nbr); Strings.Append(postfix, ")");
			PrefixPostfixToCaption(node, Strings.NewString(postfix), FALSE);
		END AddNumberPostfixToCaption;

		PROCEDURE AddIdentList(parent: WMTrees.TreeNode; identList: ModuleParser.IdentList; VAR nofIdents : LONGINT);
		VAR n: ModuleParser.NodeList; newNode: WMTrees.TreeNode;
		BEGIN
			nofIdents := 0;
			n := identList;
			WHILE n # NIL DO
				newNode := AddIdentDef(parent, n, n(ModuleParser.IdentList).identDef, SortIgnore, treeView.clTextDefault.Get(), {});
				INC(nofIdents);
				n := n.next;
			END;
		END AddIdentList;

		PROCEDURE AddConstDecl(parent: WMTrees.TreeNode; constDecl: ModuleParser.ConstDecl);
		VAR
			n: ModuleParser.NodeList;
			newNode: WMTrees.TreeNode;
			c : ModuleParser.ConstDecl;
			nofConstants : LONGINT;
		BEGIN
			n := constDecl; nofConstants := 0;
			WHILE n # NIL DO
				c := n (ModuleParser.ConstDecl);
				newNode := AddIdentDef(parent, c, c.identDef, SortIgnore, treeView.clTextDefault.Get(), {});
				newNode := AddInfoItem(newNode, c, c.expr, IsPublic(c.identDef), SortIgnore, treeView.clTextDefault.Get(), {});
				INC(nofConstants);
				n := n.next;
			END;
			AddNumberPostfixToCaption(parent, nofConstants);
		END AddConstDecl;

		PROCEDURE AddIdentDef(parent: WMTrees.TreeNode; node : ModuleParser.Node; identDef: ModuleParser.IdentDef; sortInfo, color: LONGINT; style: SET):
			WMTrees.TreeNode;
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF identDef # NIL THEN
				newNode := AddInfoItem(parent, node, identDef.ident, IsPublic(identDef), sortInfo, color, style);
				IF identDef.vis = ModuleParser.Public THEN
					AddPostfixToCaption(newNode, Strings.NewString("*"));
				ELSIF identDef.vis = ModuleParser.PublicRO THEN
					AddPostfixToCaption(newNode, Strings.NewString("-"));
				END;
				RETURN newNode;
			ELSE
				RETURN NIL;
			END
		END AddIdentDef;

		PROCEDURE AddInfoItem(parent: WMTrees.TreeNode; node : ModuleParser.Node; infoItem: ModuleParser.InfoItem; isPublic : BOOLEAN; sortInfo, color : LONGINT; style: SET):
			WMTrees.TreeNode;
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF (infoItem # NIL) & (parent # NIL) THEN
				NEW(newNode);
				tree.SetNodeData(newNode, GetTextInfo(node, infoItem, isPublic, sortInfo, color, style));
				tree.SetNodeCaption(newNode, infoItem.name);
				tree.AddChildNode(parent, newNode);
			END;
			RETURN newNode;
		END AddInfoItem;

	END ModuleTree;

VAR
	PrototypeShowTypeHierarchy : WMProperties.BooleanProperty;
	treeFontPlain, treeFontBold, treeFontItalic: WMGraphics.Font;

	PROCEDURE GetColor(modifiers : SET; defaultColor : LONGINT) : LONGINT;
	VAR color : LONGINT;
	BEGIN
		IF (ModuleParser.Exclusive IN modifiers) THEN color := ColorExclusive;
		ELSIF (ModuleParser.HasExclusiveBlock IN modifiers) THEN color := ColorHasExclusiveBlock;
		ELSE
			color := defaultColor;
		END;
		RETURN color;
	END GetColor;

VAR font : WMGraphics.Font;
BEGIN
	NEW(PrototypeShowTypeHierarchy, NIL, Strings.NewString("ShowTypeHierarchy"), Strings.NewString("Show type hierarchy?"));
	PrototypeShowTypeHierarchy.Set(FALSE);

	font := WMGraphics.GetDefaultFont();
	treeFontPlain := WMGraphics.GetFont(font.name, font.size, font.style);
	treeFontBold := WMGraphics.GetFont(font.name, font.size, {WMGraphics.FontBold});
	treeFontItalic := WMGraphics.GetFont(font.name, font.size, {WMGraphics.FontItalic});
END ModuleTrees.

Tar.Create ModuleTreesIcons.tar
	activity.png
	arrow-red.png
	arrow-yellow.png
	arrow-green.png
	arrow-blue.png
~
