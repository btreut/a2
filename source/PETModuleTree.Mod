MODULE PETModuleTree; (** AUTHOR "?"; PURPOSE "Visualize module structure as tree"; *)

IMPORT
	Commands, Diagnostics, Streams, Files, TextUtilities, WMStandardComponents, WMGraphics, WMProperties, WMComponents,
	Strings, WMTrees, FoxScanner, ModuleParser, PETTrees;

CONST
	Title = " Program Structure";
	TitleError = " Program Structure (Errors)";

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
	ColorInterrupt = 00CCCCFFH; (* dark cyan *)

	SortIgnore = 1;
	SortProcedure = 2;
	SortNo = 90;
	SortBody = 99;

	(* Info.flags *)
	NotPublic = 0;

	(* Special procedure types *)
	Other = 0;
	CommandProc = 1; (* PROCEDURE(); *)
	ContextProc = 2; (* PROCEDURE(context : Commands.Context); *)

TYPE

	Name = ARRAY 32 OF CHAR;

TYPE

	TreeNode = OBJECT(PETTrees.TreeNode);
	VAR
		commandName : Strings.String; (* name of command procedure if node represent an executable command *)
		modulename : Name;
		sortHint : LONGINT;
		flags : SET;
		position : LONGINT;

		PROCEDURE &Init;
		BEGIN
			Init^;
			commandName := NIL;
			modulename := "";
			sortHint := SortIgnore;
			flags := {};
			position := 0;
		END Init;

	END TreeNode;

TYPE

	ModuleTree* = OBJECT (PETTrees.Tree)
	VAR
		showTypeHierarchy-, showImportedModules- : WMProperties.BooleanProperty;

		moduleName : Name;

		detailsBtn, publicBtn: WMStandardComponents.Button;
		showPublicOnly : BOOLEAN;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			NEW(showTypeHierarchy, PrototypeShowTypeHierarchy, NIL, NIL); properties.Add(showTypeHierarchy);
			NEW(showImportedModules, PrototypeShowImportedModules, NIL, NIL); properties.Add(showImportedModules);
			moduleName := "NONE";
			showPublicOnly := FALSE;

			NEW(detailsBtn); detailsBtn.alignment.Set(WMComponents.AlignLeft);
			detailsBtn.caption.SetAOC("Details");
			detailsBtn.isToggle.Set(TRUE);
			detailsBtn.SetPressed(FALSE);
			detailsBtn.onClick.Add(ShowDetailsHandler);
			toolbar.AddContent(detailsBtn);

			NEW(publicBtn); publicBtn.alignment.Set(WMComponents.AlignClient);
			publicBtn.caption.SetAOC("PublicOnly");
			publicBtn.SetPressed(FALSE);
			publicBtn.isToggle.Set(TRUE);
			publicBtn.onClick.Add(ShowPublicHandler);
			toolbar.AddContent(publicBtn);
		END Init;

		PROCEDURE PropertyChanged(sender, data : ANY);
		BEGIN
			IF (data = showTypeHierarchy) OR (data = showImportedModules) THEN
				RefreshHandler(NIL, NIL);
			ELSE
				PropertyChanged^(sender, data);
			END;
		END PropertyChanged;

		PROCEDURE ShowDetailsHandler(sender, data : ANY);
		VAR isPressed : BOOLEAN;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ShowPublicHandler, sender, data);
			ELSE
				isPressed := detailsBtn.GetPressed();
				Acquire;
				showTypeHierarchy.Set(isPressed);
				showImportedModules.Set(isPressed);
				Release;
			END;
		END ShowDetailsHandler;

		PROCEDURE ShowPublicHandler(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ShowPublicHandler, sender, data);
			ELSE
				showPublicOnly := ~showPublicOnly;
				publicBtn.SetPressed(showPublicOnly);
				tree.Acquire;
				SetNodeVisibilities(tree.GetRoot(), showPublicOnly);
				tree.Release;
			END;
		END ShowPublicHandler;

		PROCEDURE SetNodeVisibilities(parent : WMTrees.TreeNode; showPublicOnly : BOOLEAN);
		VAR n : WMTrees.TreeNode; state : SET;
		BEGIN
			n := tree.GetChildren(parent);
			WHILE n # NIL DO
				SetNodeVisibilities(n, showPublicOnly);
				state := tree.GetNodeState(n);
				IF (n IS TreeNode) THEN
					IF NotPublic IN n(TreeNode).flags THEN
						IF showPublicOnly THEN INCL(state, WMTrees.NodeHidden) ELSE EXCL(state, WMTrees.NodeHidden); END;
					END;
				END;
				tree.SetNodeState(n, state);
				n := tree.GetNextSibling(n);
			END;
		END SetNodeVisibilities;

		PROCEDURE AddModule(node : WMTrees.TreeNode; module : ModuleParser.Module; expand, showPublicOnly, showTypeHierarchy, showImportedModules : BOOLEAN);
		BEGIN (* tree must be locked!!! *)
			IF (node IS TreeNode) THEN
				SetNodeInfo(node(TreeNode), module, module.ident, TRUE, SortIgnore, treeView.clTextDefault.Get(), {});
			END;
			IF (module.ident # NIL) & (module.ident.name # NIL) THEN
				tree.SetNodeCaption(node, module.ident.name);
			ELSE
				tree.SetNodeCaption(node, StrUNKNOWN);
			END;
			IF (module.context # NIL) & (module.context.name # NIL) THEN
				AddPostfixToCaption(node, StrIN);
				AddPostfixToCaption(node, module.context.name);
			END;
			AddImportList(node, module.importList, showImportedModules);
			AddDefinitions(node, module.definitions);
			AddDeclSeq(node, module.declSeq);
			IF module.bodyPos # 0 THEN
				AddBody (node, module, module.modifiers, module.bodyPos);
			END;
			IF expand THEN tree.SetNodeState(node, {WMTrees.NodeExpanded}); END;
			SetNodeVisibilities(node, showPublicOnly);
		END AddModule;

		PROCEDURE GetNewNode() : PETTrees.TreeNode; (* overwrite *)
		VAR node : TreeNode;
		BEGIN
			NEW(node); RETURN node;
		END GetNewNode;

		PROCEDURE AddNodes(parent : PETTrees.TreeNode; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		VAR module : ModuleParser.Module; scanner : FoxScanner.Scanner; reader : TextUtilities.TextReader;
		BEGIN
			ASSERT(diagnostics # NIL);
			AddNodes^(parent, diagnostics, log);
			NEW(reader, editor.text);
			scanner := FoxScanner.NewScanner("PETModuleTree", reader, 0, diagnostics);
			ModuleParser.Parse(scanner, module);
			IF (module # NIL) THEN
				IF (module.ident # NIL) & (module.ident.name # NIL) THEN
					COPY(module.ident.name^, moduleName);
				ELSE
					moduleName := "UNKOWN";
				END;
				IF showTypeHierarchy.Get() THEN
					ModuleParser.SetSuperTypes(module);
				END;
				AddModule(parent, module, TRUE, showPublicOnly, showTypeHierarchy.Get(), showImportedModules.Get());
				IF module.hasError THEN SetTitle(TitleError);
				ELSE SetTitle(Title);
				END;
			ELSE
				moduleName := "UNKNOWN";
			END;
		END AddNodes;

		PROCEDURE ClickNode*(sender, data : ANY);
		VAR node : WMTrees.TreeNode; extInfo : PETTrees.ExternalInfo;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				node := data(WMTrees.TreeNode);
				IF (node IS TreeNode) & (node(TreeNode).pos = NIL) THEN
					(* Use pos of child (for VAR, CONST and IMPORT) *)
					node := tree.GetChildren(node);
				END;
				tree.Release;

				IF (node # NIL) & (node IS TreeNode) THEN
					IF (node(TreeNode).modulename = moduleName) THEN
						IF (node(TreeNode).pos # NIL) THEN
							SetEditorPosition(node(TreeNode).pos.GetPosition(), TRUE);
						END;
					ELSE
						NEW(extInfo, node(TreeNode).modulename, node(TreeNode).position);
						onGoToFile.Call(extInfo);
					END;
				END
			END
		END ClickNode;

		PROCEDURE MiddleClickNode*(sender, data : ANY);
		VAR commandStr, ignoreMsg : ARRAY 128 OF CHAR; len, ignore : LONGINT;
		BEGIN
			IF (data # NIL) & (data IS TreeNode) & (data(TreeNode).commandName # NIL) & (data(TreeNode).modulename # "") THEN
				COPY(data(TreeNode).modulename, commandStr);
				Strings.Append(commandStr, Commands.Delimiter);
				Strings.Append(commandStr, data(TreeNode).commandName^);
				len := Strings.Length(commandStr);
				IF (commandStr[len-1] = "*") THEN commandStr[len-1] := 0X; END;
				Commands.Activate(commandStr, NIL, {}, ignore, ignoreMsg);
			END;
		END MiddleClickNode;

		PROCEDURE SetNodeInfo(node : TreeNode; mnode : ModuleParser.Node; infoItem: ModuleParser.InfoItem; isPublic : BOOLEAN; sortHint, color: LONGINT; style: SET);
		VAR moduleNode : ModuleParser.Module; font: WMGraphics.Font;
		BEGIN
			node.flags := {};
			IF ~isPublic THEN INCL(node.flags, NotPublic); END;
			node.sortHint := sortHint;
			node.color := color;
			IF style = {} THEN
				font := PETTrees.FontPlain;
			ELSIF style = {WMGraphics.FontBold} THEN
				font := PETTrees.FontBold;
			ELSIF style = {WMGraphics.FontItalic} THEN
				font := PETTrees.FontItalic;
			ELSE
				(* unknown style *)
				font := PETTrees.FontPlain;
			END;
			node.font := font;
			IF (infoItem # NIL) THEN
				IF (mnode # NIL) THEN
					moduleNode := GetModuleNode(mnode);
				ELSE
					moduleNode := NIL;
				END;
				node.position := infoItem.pos;
				IF (moduleNode = NIL) OR ((moduleNode.ident # NIL) & (moduleNode.ident.name # NIL) & (moduleNode.ident.name^ = moduleName)) THEN
					node.external := FALSE;
					node.modulename := moduleName;
					NEW(node.pos, editor.text);
					node.pos.SetPosition(infoItem.pos);
				ELSE
					node.external := TRUE;
					node.pos := NIL;
					COPY(moduleNode.ident.name^, node.modulename);
				END;
			ELSE
				node.modulename := moduleName;
			END;
		END SetNodeInfo;

		PROCEDURE IsPublic(identDef : ModuleParser.IdentDef) : BOOLEAN;
		BEGIN
			RETURN (identDef.vis = ModuleParser.Public) OR (identDef.vis = ModuleParser.PublicRO);
		END IsPublic;

		PROCEDURE IsNodeGreater*(left, right: WMTrees.TreeNode): BOOLEAN;
		VAR leftCaption, rightCaption, leftTmp, rightTmp: Strings.String;
		BEGIN
			IF (left IS TreeNode) & (right IS TreeNode) &
				(left(TreeNode).sortHint >= right(TreeNode).sortHint) &
				(left(TreeNode).font = right(TreeNode).font) &
				(left(TreeNode).sortHint # SortNo) &
				(right(TreeNode).sortHint # SortNo) THEN
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
			WHILE (n # NIL) & (n # n.parent) DO n := n.parent; END;
			IF (n # NIL) & (n IS ModuleParser.Module) THEN
				RETURN n (ModuleParser.Module);
			ELSE
				RETURN NIL;
			END;
		END GetModuleNode;

		PROCEDURE GetProcedureType(procHead : ModuleParser.ProcHead) : LONGINT;
		VAR type : LONGINT;

			PROCEDURE InModuleScope(procHead : ModuleParser.ProcHead) : BOOLEAN;
			VAR module : ModuleParser.Module;
			BEGIN
				IF (procHead # NIL) & (procHead.parent.parent.parent # NIL) & (procHead.parent.parent.parent IS ModuleParser.Module) THEN
					module := procHead.parent.parent.parent (ModuleParser.Module);
					RETURN (module.ident # NIL) & (module.ident.name # NIL) & (module.ident.name^ = moduleName);
				ELSE
					RETURN FALSE;
				END;
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
		VAR node: TreeNode;
		BEGIN
			node := NewNode(root, StrBODY);
			SetNodeInfo(node, pnode, NIL, FALSE, SortBody, GetColor(modifiers, treeView.clTextDefault.Get()), {});
			NEW(node.pos, editor.text);
			node.pos.SetPosition(pos);
		END AddBody;

		PROCEDURE AddImportList(parent: WMTrees.TreeNode; importList: ModuleParser.Import; showImportedModules : BOOLEAN);
		VAR
			module : ModuleParser.Module; filename : Files.FileName;
			n: ModuleParser.NodeList;
			newNode, importNode: TreeNode;
			import: ModuleParser.Import;
			nofImports : LONGINT;
		BEGIN
			n := importList;
			IF n # NIL THEN
				NEW(importNode);
				SetNodeInfo(importNode, importList, NIL, FALSE, SortIgnore, treeView.clTextDefault.Get(), {});
				tree.SetNodeCaption(importNode, StrIMPORT);
				tree.AddChildNode(parent, importNode);
			ELSE
				importNode := NIL;
			END;
			nofImports := 0;
			WHILE n # NIL DO
				import := n(ModuleParser.Import);
				newNode := AddInfoItem(importNode, import, import.ident, TRUE, SortIgnore, treeView.clTextDefault.Get(), {});
				IF import.alias # NIL THEN
					AddPostfixToCaption(newNode, StrBecomes);
					AddPostfixToCaption(newNode, import.alias.name);
				END;
				IF import.context # NIL THEN
					AddPostfixToCaption(newNode, StrIN);
					AddPostfixToCaption(newNode, import.context.name);
				END;
				IF (newNode # NIL) THEN INC(nofImports); END;
				IF showImportedModules THEN
					IF ((import.ident # NIL) & (import.ident.name # NIL)) OR ((import.alias # NIL) & (import.alias.name # NIL)) THEN
						IF (import.context # NIL) THEN COPY(import.context.name^, filename); Strings.Append(filename, "."); ELSE filename := ""; END;
						IF (import.alias # NIL) THEN
							Strings.Append(filename, import.alias.name^);
						ELSE
							Strings.Append(filename, import.ident.name^);
						END;
						Strings.Append(filename, ".Mod");
						module := ModuleParser.ParseFile(filename, NIL);
						IF (module = NIL) THEN
							filename := "I386."; Strings.Append(filename, import.ident.name^); Strings.Append(filename, ".Mod");
							module := ModuleParser.ParseFile(filename, NIL);
						END;
						IF (module # NIL) THEN
							AddModule(newNode, module, FALSE, TRUE, FALSE, FALSE);
						END;
					END;
				END;
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
		VAR n: ModuleParser.NodeList; newNode: TreeNode;
		BEGIN
			n := declSeq;
			WHILE n # NIL DO
				declSeq := n(ModuleParser.DeclSeq);
				IF (declSeq.constDecl # NIL) THEN
					NEW(newNode);
					SetNodeInfo(newNode, declSeq.constDecl, NIL, HasPublicConsts(declSeq.constDecl), SortIgnore, treeView.clTextDefault.Get(), {});
					tree.SetNodeCaption(newNode, StrCONST);
					tree.AddChildNode(parent, newNode);
					AddConstDecl(newNode, declSeq.constDecl);
				END;
				IF declSeq.typeDecl # NIL THEN
					AddTypeDecl(parent, declSeq.typeDecl);
				END;
				IF (declSeq.varDecl # NIL) THEN
					NEW(newNode);
					SetNodeInfo(newNode, declSeq.varDecl, NIL, HasPublicVars(declSeq.varDecl), SortIgnore, treeView.clTextDefault.Get(), {});
					tree.SetNodeCaption(newNode, StrVAR);
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
			newNode: TreeNode; caption: Strings.String;
			color : LONGINT; image : WMGraphics.Image; type : LONGINT;
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
					AddPrefixToCaption(newNode, StrQuote);
					AddPostfixToCaption(newNode, StrQuote);
					IF procHead.identDef.vis = ModuleParser.Public THEN
							(* add visibility sign (still ugly) *)
						AddPostfixToCaption(newNode, StrStar);
					END;
				END;
				IF procHead.constructor THEN
					AddPrefixToCaption(newNode, StrAmpersand);
				END;
				IF procHead.inline THEN
					AddPrefixToCaption(newNode, StrMinus);
				END;

				type := GetProcedureType(procHead);
				IF 	(type = CommandProc) OR (type = ContextProc) &
					(procHead.identDef # NIL) & (procHead.identDef.ident # NIL) & (procHead.identDef.ident.name # NIL) THEN
					newNode.commandName := procHead.identDef.ident.name;
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
					AddPostfixToCaption(newNode, StrOverwrite);
				END;

				IF (ModuleParser.Overwritten IN procHead.modifiers) THEN
					AddPostfixToCaption(newNode, StrOverwritten);
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
				tree.SetNodeCaption(newNode, StrRETURN);
				IF formalPars.returnType # NIL THEN
					AddType(newNode, formalPars.returnType, TRUE);
					tree.AddChildNode(parent, newNode);
				END;
			END;
		END AddFormalPars;

		PROCEDURE AddFPSection(parent: WMTrees.TreeNode; fpSection: ModuleParser.FPSection);
		VAR newNode: TreeNode; n, l: ModuleParser.NodeList;
		BEGIN
			n := fpSection;
			WHILE n # NIL DO
				l := n(ModuleParser.FPSection).identList;
				WHILE l # NIL DO
					newNode := AddIdentDef(parent, l, l(ModuleParser.IdentList).identDef, SortIgnore, treeView.clTextDefault.Get(), {});
					(* Make parameters always visible *)
					EXCL(newNode.flags, NotPublic);
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
				ELSIF type.enum # NIL THEN
					AddEnum(parent, type.enum);
				ELSIF type.cell # NIL THEN
					AddCell(parent, type.cell, anonymous)
				ELSIF type.port # NIL THEN
					AddPort(parent, type.port);
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

		PROCEDURE AddEnum(parent: WMTrees.TreeNode; enum: ModuleParser.Enum);
		VAR p: WMTrees.TreeNode; num: LONGINT;
		BEGIN
			IF enum # NIL THEN
				AddIdentList(parent, enum.identList,num);
			END;
		END AddEnum;

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
				newNode := NewNode(parent, StrARRAY);
				IF ~array.open THEN
					IF (array.len # NIL) & (array.len.name # NIL) THEN
						AddPostfixToCaption(newNode, array.len.name);
						AddPostfixToCaption(newNode, Strings.NewString(" "));
					END;
				END;
				AddPostfixToCaption(newNode, StrOF);
				AddType(newNode, array.base, TRUE);
			END;
		END AddArray;

		PROCEDURE NewNode(parent: WMTrees.TreeNode; caption: Strings.String): TreeNode;
		VAR newNode: TreeNode;
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
			newNode : TreeNode;
			superRecord : ModuleParser.Record;
			moduleNode : ModuleParser.Module;
			node : ModuleParser.Node;
			typeDecl : ModuleParser.TypeDecl;
			caption : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(record # NIL);
			superRecord := record.superPtr;
			WHILE (superRecord # NIL) DO
				NEW(newNode);
				SetNodeInfo(newNode, superRecord, NIL, TRUE, SortNo, WMGraphics.Black, {WMGraphics.FontItalic});
				moduleNode := GetModuleNode(superRecord);
				IF (moduleNode # NIL) & (moduleNode.ident # NIL) & (moduleNode.ident.name # NIL) & (moduleNode.ident.name^ # moduleName) THEN
					COPY(moduleNode.ident.name^, caption); Strings.Append(caption, ".");
				ELSE
					caption := "";
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
				newNode.color := WMGraphics.Black;
				superRecord := superRecord.superPtr;
			END;
		END AddSuperRecords;

		PROCEDURE AddSuperClasses(parent : WMTrees.TreeNode; object : ModuleParser.Object);
		VAR
			newNode : TreeNode;
			superClass : ModuleParser.Object;
			moduleNode : ModuleParser.Module;
			typeDecl : ModuleParser.TypeDecl;
			caption : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(object # NIL);
			superClass := object.superPtr;
			WHILE (superClass # NIL) DO
				NEW(newNode);
				SetNodeInfo(newNode, superClass, NIL, TRUE, SortNo, WMGraphics.Black, {WMGraphics.FontItalic});
				moduleNode := GetModuleNode(superClass);
				IF (moduleNode # NIL) & (moduleNode.ident # NIL) & (moduleNode.ident.name # NIL) & (moduleNode.ident.name^ # moduleName) THEN
					COPY(moduleNode.ident.name^, caption); Strings.Append(caption, ".");
				ELSE
					caption := "";
				END;
				typeDecl := superClass.parent.parent (ModuleParser.TypeDecl);
				Strings.Append(caption, typeDecl.identDef.ident.name^);
				tree.SetNodeCaption(newNode, Strings.NewString(caption));
				tree.AddChildNode(parent, newNode);
				AddObject(newNode, superClass, FALSE, FALSE);
				newNode.color := WMGraphics.Black;
				superClass := superClass.superPtr;
			END;
		END AddSuperClasses;

		PROCEDURE AddObject(parent: WMTrees.TreeNode; object: ModuleParser.Object; anonymous, addSuperClasses: BOOLEAN);
		VAR newNode, p: WMTrees.TreeNode; image : WMGraphics.Image;
		BEGIN
			IF object # NIL THEN
				IF anonymous THEN p := NewNode(parent, Strings.NewString("OBJECT"));
				ELSE p := parent;
				END;
				IF (p IS TreeNode) THEN
					p(TreeNode).color := ColorObjects;
				END;
				IF ModuleParser.Active IN object.modifiers THEN
					IF (p IS TreeNode)  THEN
						p(TreeNode).color := ColorActiveObjects;
					END;
					IF ShowImages THEN
						image := WMGraphics.LoadImage(ImageActive, TRUE);
						IF image # NIL THEN
							tree.Acquire; tree.SetNodeImage(p, image); tree.Release;
						END;
					END;
				END;
				IF (object.super # NIL) & (object.super.ident # NIL) & addSuperClasses THEN
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

		PROCEDURE AddCell(parent: WMTrees.TreeNode; cell: ModuleParser.Cell; anonymous: BOOLEAN);
		VAR newNode, p: WMTrees.TreeNode; image : WMGraphics.Image;
		BEGIN
			IF cell # NIL THEN
				IF anonymous THEN p := NewNode(parent, Strings.NewString("CELL"));
				ELSE p := parent;
				END;
				IF (p IS TreeNode) THEN
					p(TreeNode).color := ColorObjects;
				END;
				IF cell.formalPars # NIL THEN
					AddFormalPars(p, cell.formalPars);
				END;
				IF cell.declSeq # NIL THEN
					AddDeclSeq(p, cell.declSeq);
				END;
				IF cell.bodyPos # 0 THEN
					AddBody (p, cell, cell.modifiers, cell.bodyPos);
				END;
			END;
		END AddCell;

		PROCEDURE AddPort(parent: WMTrees.TreeNode; port:ModuleParser.Port);
		VAR p: WMTrees.TreeNode;
		BEGIN
			p := NewNode(parent, Strings.NewString("PORT"));
		END AddPort;

		PROCEDURE AddProcedure(parent: WMTrees.TreeNode; proc: ModuleParser.Procedure);
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF proc # NIL THEN
				newNode := NewNode(parent, Strings.NewString("PROCEDURE"));
				IF proc.delegate THEN AddPostfixToCaption(newNode, Strings.NewString(" {DELEGATE}")) END;
				AddFormalPars(newNode, proc.formalPars);
			END;
		END AddProcedure;

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

		PROCEDURE AddIdentDef(
			parent: WMTrees.TreeNode;
			node : ModuleParser.Node; identDef: ModuleParser.IdentDef;
			sortHint, color: LONGINT; style: SET) : TreeNode;
		VAR
			newNode: TreeNode;
		BEGIN
			IF identDef # NIL THEN
				newNode := AddInfoItem(parent, node, identDef.ident, IsPublic(identDef), sortHint, color, style);
				IF identDef.vis = ModuleParser.Public THEN
					AddPostfixToCaption(newNode, StrStar);
				ELSIF identDef.vis = ModuleParser.PublicRO THEN
					AddPostfixToCaption(newNode, StrMinus);
				END;
				RETURN newNode;
			ELSE
				RETURN NIL;
			END
		END AddIdentDef;

		PROCEDURE AddInfoItem(
			parent: WMTrees.TreeNode;
			node : ModuleParser.Node; infoItem: ModuleParser.InfoItem;
			isPublic : BOOLEAN; sortHint, color : LONGINT; style: SET) : TreeNode;
		VAR
			newNode: TreeNode;
		BEGIN
			IF (infoItem # NIL) & (parent # NIL) THEN
				NEW(newNode);
				SetNodeInfo(newNode, node, infoItem, isPublic, sortHint, color, style);
				tree.SetNodeCaption(newNode, infoItem.name);
				tree.AddChildNode(parent, newNode);
			END;
			RETURN newNode;
		END AddInfoItem;

	END ModuleTree;

VAR
	PrototypeShowTypeHierarchy, PrototypeShowImportedModules : WMProperties.BooleanProperty;
	StrUNKNOWN, StrVAR, StrCONST, StrIMPORT, StrIN, StrBODY, StrRETURN, StrARRAY, StrOF,
	StrBecomes, StrAmpersand, StrMinus, StrStar, StrQuote, StrOverwritten, StrOverwrite : Strings.String;

PROCEDURE GetColor(modifiers : SET; defaultColor : LONGINT) : LONGINT;
VAR color : LONGINT;
BEGIN
	IF (ModuleParser.Exclusive IN modifiers) THEN color := ColorExclusive;
	ELSIF (ModuleParser.HasExclusiveBlock IN modifiers) THEN color := ColorHasExclusiveBlock;
	ELSIF (ModuleParser.Interrupt IN modifiers) THEN color := ColorInterrupt;
	ELSE
		color := defaultColor;
	END;
	RETURN color;
END GetColor;

PROCEDURE GenModuleTree*() : PETTrees.Tree;
VAR tree : ModuleTree;
BEGIN
	NEW(tree); RETURN tree;
END GenModuleTree;

PROCEDURE InitStrings;
BEGIN
	StrUNKNOWN := Strings.NewString("UNKNOWN");
	StrVAR := Strings.NewString("VAR");
	StrCONST := Strings.NewString("CONST");
	StrIMPORT := Strings.NewString("IMPORT");
	StrIN := Strings.NewString(" IN ");
	StrBODY := Strings.NewString("BODY");
	StrRETURN := Strings.NewString("RETURN");
	StrARRAY := Strings.NewString("ARRAY ");
	StrOF := Strings.NewString("OF");
	StrBecomes := Strings.NewString(" := ");
	StrAmpersand := Strings.NewString("& ");
	StrMinus := Strings.NewString("-");
	StrStar := Strings.NewString("*");
	StrQuote := Strings.NewString('"');
	StrOverwritten := Strings.NewString(" [overwritten]");
	StrOverwrite := Strings.NewString(" [overwrite]");
END InitStrings;

BEGIN
	InitStrings;
	NEW(PrototypeShowTypeHierarchy, NIL, Strings.NewString("ShowTypeHierarchy"), Strings.NewString("Show type hierarchy?"));
	PrototypeShowTypeHierarchy.Set(FALSE);
	NEW(PrototypeShowImportedModules, NIL, Strings.NewString("ShowImportedModules"), Strings.NewString("Show imported modules details?"));
	PrototypeShowImportedModules.Set(FALSE);
END PETModuleTree.

Tar.Create ModuleTreesIcons.tar
	activity.png
	arrow-red.png
	arrow-yellow.png
	arrow-green.png
	arrow-blue.png
~
