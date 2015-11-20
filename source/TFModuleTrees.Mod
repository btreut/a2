MODULE TFModuleTrees; (** AUTHOR "tf"; PURPOSE "parse tree with links to text"; *)

IMPORT
	WMStandardComponents, WMGraphics, WMProperties, WMComponents,
	Strings, KernelLog, WMTrees, PETTrees,

	BimboScanner, TFAOParser, TS := TFTypeSys, ST := TFScopeTools,
	Kernel, WMPopups, WMTextView, WMEditors, TextUtilities, Texts, WMDialogs,
	Diagnostics, Streams, Raster, WMRectangles,
	WMStringGrids, WMGrids, WMWindowManager, WMMessages;

CONST
	ProcOther = 0;
	ProcCommand = 1;
	ImageCommandProc = "ModuleTreesIcons.tar://arrow-red.png";
	DoAutoRefresh = FALSE;

TYPE
	Reference = POINTER TO RECORD
		next : Reference;
		fp, tp, np : LONGINT;
		no : TS.NamedObject;
	END;
	RefArray = POINTER TO ARRAY OF Reference;

	Comment = POINTER TO RECORD
		next : Comment;
		fp, tp : LONGINT;
		h : WMTextView.Highlight;
	END;

	CurrentHighlights = POINTER TO RECORD
		next : CurrentHighlights;
		h : WMTextView.Highlight;
	END;

	TextInfo = OBJECT(PETTrees.TreeNode)
	VAR
		next : TextInfo;
		fp, tp : LONGINT;
		name : Strings.String;
		def : TS.NamedObject;
	END TextInfo;


	SelectWindow*  = OBJECT (WMComponents.FormWindow)
	VAR edit : WMEditors.Editor;
		list : WMStringGrids.StringGrid;
		spacings : WMGrids.Spacings;
		curEditStr : ARRAY 64 OF CHAR;
		table : TS.ObjectList;
		scope: TS.Scope;
		firstLevel : BOOLEAN;
		destinationText : Texts.Text;
		startPos, cursorPos : LONGINT;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			ep, sb, sr, gb, gr, d : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(200, 160); panel.fillColor.Set(0); panel.takesFocus.Set(TRUE);

			(* right shadow *)
			NEW(sr); sr.bounds.SetWidth(4); sr.alignment.Set(WMComponents.AlignRight); sr.fillColor.Set(0);
			panel.AddContent(sr);

			NEW(d); d.bounds.SetHeight(4); d.alignment.Set(WMComponents.AlignTop); d.fillColor.Set(0);
			sr.AddContent(d);

			NEW(gr); gr.alignment.Set(WMComponents.AlignClient); gr.fillColor.Set(080H);
			sr.AddContent(gr);

			(* bottom shadow *)
			NEW(sb); sb.bounds.SetHeight(4); sb.alignment.Set(WMComponents.AlignBottom); sb.fillColor.Set(0);
			panel.AddContent(sb);

			NEW(d); d.bounds.SetWidth(4); d.alignment.Set(WMComponents.AlignLeft); d.fillColor.Set(0);
			sb.AddContent(d);

			NEW(gb); gb.alignment.Set(WMComponents.AlignClient); gb.fillColor.Set(080H);
			sb.AddContent(gb);

			(* edit panel *)
			NEW(ep); ep.alignment.Set(WMComponents.AlignClient); ep.fillColor.Set(LONGINT(0DDDD00EEH));
			panel.AddContent(ep);

			NEW(edit); edit.bounds.SetHeight(20); edit.alignment.Set(WMComponents.AlignTop); edit.tv.showBorder.Set(TRUE);
			edit.tv.defaultTextBgColor.Set(0);

			edit.tv.borders.Set(WMRectangles.MakeRect(3, 3, 2, 2));
			edit.allowIME := FALSE;
			edit.multiLine.Set(FALSE);
			edit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			ep.AddContent(edit);
			NEW(list); list.alignment.Set(WMComponents.AlignClient);
			NEW(spacings, 2); spacings[0] := 60; spacings[1] := 140;
			list.SetExtKeyEventHandler(ListKeyPressed);
			list.Acquire;
			list.defaultRowHeight.Set(25);
			list.cellDist.Set(0);
			list.clCell.Set(LONGINT(0FFFFFFA0H));
			(*list.SetColSpacings(spacings);
			list.SetFont(WMGraphics.GetFont("Single", 20, {})); *)
			list.Release;
			ep.AddContent(list);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*(text: Texts.Text; startPos, cursorPos, x, y :LONGINT; CONST prefix : ARRAY OF CHAR; scope : TS.Scope; first: BOOLEAN);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			edit.onEnter.Add(Ok);
			edit.tv.SetExtKeyEventHandler(EditKeyPressed);
			SELF.table := table;
			SELF.firstLevel := first;
			SELF.scope := scope;
			SELF.destinationText := text;
			SELF.startPos := startPos;
			SELF.cursorPos := cursorPos;

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {});
			manager.SetFocus(SELF);
			edit.text.onTextChanged.Add(TextChanged);
			edit.SetAsString(prefix);
			edit.SetFocus;
		END New;

		PROCEDURE ListKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			IF keySym = 0FF0DH THEN handled := TRUE; Ok(SELF, NIL); (*edit.SetFocus*) 
			ELSIF keySym = 0FF1BH THEN ScheduleHide
			END;
		END ListKeyPressed;

		PROCEDURE EditKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
(*			IF keySym = 0FF08H THEN
				IF curEditStr = "" THEN ScheduleHide
				ELSE edit.KeyPressed(ucs, flags, keySym, handled)
				END
			ELS*)
			IF keySym = 0FF0DH THEN handled := TRUE; Ok(SELF, NIL)
			ELSIF keySym = 0FF54H (*CursorDown*) THEN list.SetFocus
			ELSIF keySym = 0FF1BH (*ESC *)THEN ScheduleHide
			ELSE
				(*handled := FALSE; *)
				edit.KeyPressed(ucs, flags, keySym, handled)
			END;
		END EditKeyPressed;

		PROCEDURE ScheduleHide;
		VAR msg : WMMessages.Message;
		BEGIN
			msg.msgType := WMMessages.MsgExt;
			msg.ext := SELF;
			IF ~sequencer.Add(msg) THEN KernelLog.String("IME Editor out of sync") END;
		END ScheduleHide;

		PROCEDURE WriteSelected;
		VAR ac, ar, bc, br : LONGINT;
			p : ANY;
			index, i : LONGINT;
			str, newStr : ARRAY 1024 OF CHAR;
			signature : TS.ProcedureSignature;
			singleSuggestion : TS.NamedObject;
		BEGIN
			list.Acquire;
			list.model.Acquire;
			list.GetSelection(ac, ar, bc, br);
			p := list.model.GetCellData(0, ar);
			list.model.Release;
			list.Release;
			IF (p # NIL) & (p IS TS.NamedObject) THEN
				singleSuggestion := p(TS.NamedObject);
				index := 0;
				destinationText.AcquireWrite;
				TextUtilities.SubTextToStrAt(destinationText, startPos, cursorPos -  startPos, index, str);
				IF Strings.StartsWith2(str, singleSuggestion.name^) THEN
					destinationText.Delete(startPos, cursorPos - startPos);
					GetInsertString(singleSuggestion, newStr);
					TextUtilities.StrToText(destinationText, startPos, newStr);
				END;
				destinationText.ReleaseWrite;
			END
		END WriteSelected;

		PROCEDURE ClearSelection;
		BEGIN
			list.Acquire;
			list.model.Acquire;
			list.model.SetNofRows(0);
			list.model.Release;
			list.Release;
		END ClearSelection;

		PROCEDURE Ok*(sender, data:ANY);
		BEGIN
			WriteSelected;
			ScheduleHide
		END Ok;

		PROCEDURE TextChanged*(sender, data:ANY);
		VAR nof, i : LONGINT;
			suggestionStr : ARRAY 1024 OF CHAR;
		BEGIN
			(* avoid recursion *)
			edit.text.onTextChanged.Remove(TextChanged);

			(* find the character candidates *)
			edit.GetAsString(curEditStr);
			NEW(table);
			FindSuggestions(scope, firstLevel,curEditStr, table);

			list.Acquire;
			list.model.Acquire;
			list.SetTopPosition(0, 0, TRUE);
			list.SetSelection(0, 0, 0, 0);
			list.model.SetNofRows(table.nofObjs);
			list.model.SetNofCols(1);

			FOR i := 0 TO table.nofObjs -1 DO
				GetInsertString(table.objs[i], suggestionStr);
				list.model.SetCellText(0, i, Strings.NewString(suggestionStr));
				list.model.SetCellData(0, i, table.objs[i]);
			END;
			list.model.Release;
			list.Release;
			edit.text.onTextChanged.Add(TextChanged)
		END TextChanged;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			ScheduleHide
		END FocusLost;

		PROCEDURE Hide;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF);
		END Hide;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) THEN
				IF (x.ext = SELF) THEN Hide
				END
			ELSE Handle^(x)
			END
		END Handle;

	END SelectWindow;

	ModuleTree* = OBJECT (PETTrees.Tree)
		VAR
			nextUseBtn, renameBtn, publicBtn: WMStandardComponents.Button;
			updateTimer : WMStandardComponents.Timer;
			useHighlights : CurrentHighlights;
			currentNode : TextInfo;
			definitions : TextInfo;
			currentUse : Reference;
			actualParameter : Reference;
			modified : BOOLEAN;
			module : TS.Module;
			posKeeper : TextUtilities.TextPositionKeeper;
			comments : Comment;
			references : Reference;
			errorHighlights, tempHighlights: CurrentHighlights;
			singleSuggestion : TS.NamedObject;
			suggestionStart : LONGINT;

			cursorScope : TS.Scope;
			cursorIsFirstLevelScope : BOOLEAN;

		PROCEDURE & Init*;
		BEGIN
			Init^;

			treeView.SetExtContextMenuHandler(ContextMenu);

			NEW(renameBtn); renameBtn.alignment.Set(WMComponents.AlignLeft);
			renameBtn.caption.SetAOC("Rename");
			renameBtn.onClick.Add(RenameHandler);
			toolbar.AddContent(renameBtn);

			NEW(nextUseBtn); nextUseBtn.alignment.Set(WMComponents.AlignLeft);
			nextUseBtn.caption.SetAOC("Next Use");
			nextUseBtn.onClick.Add(NextUseHandler);
			toolbar.AddContent(nextUseBtn);

			NEW(publicBtn); publicBtn.alignment.Set(WMComponents.AlignLeft);
			publicBtn.caption.SetAOC("public");
			publicBtn.isToggle.Set(TRUE);
			publicBtn.onClick.Add(PublicBtnHandler);
			toolbar.AddContent(publicBtn);

			treeView.onStartDrag.Add(OnStartDrag);
			NEW(updateTimer);
			updateTimer.onTimer.Add(RefreshHandler);
			updateTimer.interval.Set(100);
		END Init;

		PROCEDURE OnStartDrag(sender, data : ANY);
		VAR w, h: LONGINT; img: WMGraphics.Image; canvas: WMGraphics.BufferCanvas;
		BEGIN
			NEW(img);
			treeView.MeasureNode(treeView.draggedNode, w, h);
			Raster.Create(img, w, h, Raster.BGRA8888);
			NEW(canvas, img);
			canvas.SetColor(LONGINT(0FF00FFFFH));
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FF00FFFFH), WMGraphics.ModeCopy);
			KernelLog.String("w= "); KernelLog.Int(w, 0); KernelLog.String("h= "); KernelLog.Int(h, 0); KernelLog.Ln;
			canvas.DrawString(5, h -  10, "huga");
			IF StartDrag(treeView.draggedNode, img, 0, 0, NIL, NIL) THEN
				KernelLog.String("drag started"); KernelLog.Ln;
			END;
		END OnStartDrag;

		PROCEDURE SetEditor*(e: WMEditors.Editor);
		BEGIN
			IF e = editor THEN RETURN END;
			IF (highlight # NIL) & (editor # NIL) THEN
				editor.tv.onCtrlClicked.Remove(Follow);
				editor.text.onTextChanged.Remove(TextChanged);
				editor.macros.Remove(HandleMacro);
			END;
			SetEditor^(e);
			editor.text.onTextChanged.Add(TextChanged);
			editor.macros.Add(HandleMacro);
			editor.tv.onCtrlClicked.Add(Follow);
			NEW(posKeeper, editor.text);
		END SetEditor;

		PROCEDURE BrowseToDefinition*(sender, data : ANY);
		VAR pos : LONGINT;
			no : TS.NamedObject;
			scope : TS.Scope;
			ident : ARRAY 64 OF CHAR;
			definition : ARRAY 256 OF CHAR;

			PROCEDURE GetTypeScope(type : TS.Type) : TS.Scope;
			BEGIN
				CASE type.kind OF
					|TS.TObject :  RETURN type.object.scope
					|TS.TArray : RETURN GetTypeScope(type.array.base)
					|TS.TPointer : RETURN GetTypeScope(type.pointer.type)
					|TS.TRecord : RETURN type.record.scope
				ELSE
				END;
				RETURN NIL
			END GetTypeScope;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.BrowseToDefinition, sender, data);
				RETURN
			END;

			COPY(data(PETTrees.ExternalDefinitionInfo).definition, definition);

			pos := Strings.Pos(".", definition);
			IF pos > 0 THEN
				Strings.Copy(definition, 0, pos, ident);
				Strings.Delete(definition, 0, pos + 1)
			END;
			IF module.name^ = ident THEN
				IF module.scope = NIL THEN
					KernelLog.String("The module has no scope."); KernelLog.Ln;
				END
			END;

			scope := module.scope;
			WHILE (definition # "") & (scope # NIL) DO
				pos := Strings.Pos(".", definition);
				IF pos > 0 THEN
					Strings.Copy(definition, 0, pos, ident);
					Strings.Delete(definition, 0, pos + 1)
				ELSE COPY(definition, ident); definition := ""
				END;
				no := scope.Find(ident, FALSE);
				IF no # NIL THEN scope := no.scope END;
				IF no IS TS.TypeDecl THEN scope := GetTypeScope(no(TS.TypeDecl).type) END;
			END;
			IF no # NIL THEN
				IF SelectNodeByNamedObject(no, TRUE) THEN END;
			ELSE
				KernelLog.String("Definition not found"); KernelLog.Ln;
			END
		END BrowseToDefinition;

		PROCEDURE Complete*(sender, data : ANY);
		VAR pos, index, i : LONGINT;
			str : ARRAY 64 OF CHAR;
			newStr : ARRAY 1024 OF CHAR;
			signature : TS.ProcedureSignature;
			x, y : LONGINT;
			selector : SelectWindow;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Complete, sender, data);
				RETURN
			END;
			tree.Acquire;
			editor.text.AcquireWrite;
			IF modified THEN
				Refresh(tree.GetRoot());
			END;

			pos := editor.tv.cursor.GetPosition();

			IF (singleSuggestion # NIL) & (pos - suggestionStart > 0) THEN
				index := 0;
				TextUtilities.SubTextToStrAt(editor.text, suggestionStart, pos -  suggestionStart, index, str);
				IF Strings.StartsWith2(str, singleSuggestion.name^) THEN
					editor.text.Delete(suggestionStart, pos - suggestionStart);
					GetInsertString(singleSuggestion, newStr);
					TextUtilities.StrToText(editor.text, suggestionStart, newStr);
				END
			ELSE
				index := 0;
				TextUtilities.SubTextToStrAt(editor.text, suggestionStart, pos -  suggestionStart, index, str);
				IF editor.tv.FindScreenPos(pos, x, y) THEN
					editor.tv.ToWMCoordinates(x, y, x, y);
					NEW(selector, editor.text, suggestionStart, pos, x, y, str, cursorScope, cursorIsFirstLevelScope)
				END;
			END;
		FINALLY
			editor.text.ReleaseWrite;
			tree.Release;
		END Complete;

		PROCEDURE ContextMenu(sender : ANY; x, y: LONGINT);
		VAR wmx, wmy : LONGINT;
			popup: WMPopups.Popup;
		BEGIN
			NEW(popup);
			IF ~modified THEN
				popup.AddParButton("Rename", RenameHandler, NIL);
				popup.AddParButton("SelectRange", SelectRangeHandler, NIL);
			END;
			IF currentNode # NIL THEN
				IF HasActualParameters(currentNode.def) THEN
					popup.AddParButton("Delete actual parameters", DelActualParameterHandler, NIL);
				END;
			END;
			treeView.Acquire; treeView.ToWMCoordinates(x, y, wmx, wmy); treeView.Release;
			popup.Popup(wmx, wmy)
		END ContextMenu;

		(* Caller must hold text and tree lock *)
		PROCEDURE Refresh(rootNode: WMTrees.TreeNode);
		VAR
			p : TFAOParser.Parser;
			scanner: BimboScanner.Scanner;
			
			done : BOOLEAN;
			cr : Reference; count, i : LONGINT; refs : RefArray; 
			t0, t1, res : LONGINT;
			child: WMTrees.TreeNode;
	
			PROCEDURE QuickSort(references: RefArray; lo, hi: LONGINT);
			VAR i, j: LONGINT; x, t: Reference;
			BEGIN
				i := lo; j := hi;
				x := references[(lo+hi) DIV 2];

				WHILE (i <= j) DO
					WHILE (posKeeper.GetPos(references[i].fp) < posKeeper.GetPos(x.fp)) DO INC(i) END;
					WHILE (posKeeper.GetPos(x.fp) < posKeeper.GetPos(references[j].fp)) DO DEC(j) END;
					IF (i <= j) THEN
						t := references[i]; references[i] := references[j]; references[j] := t;
						INC(i); DEC(j)
					END
				END;

				IF (lo < j) THEN QuickSort(references, lo, j) END;
				IF (i < hi) THEN QuickSort(references, i, hi) END
			END QuickSort;
		BEGIN
			child := tree.GetChildren(rootNode);
			WHILE child # NIL DO
				tree.RemoveNode(child);
				child := tree.GetChildren(rootNode)				
			END;
			
			done := FALSE;
			IF DoAutoRefresh THEN
				updateTimer.Stop(SELF, NIL);
			END;
			t0 := Kernel.GetTicks();
			currentNode := NIL;

			scanner := BimboScanner.InitWithText(editor.text, 0);
			NEW(p); p.Parse(scanner); module := p.m;
			(* TODO: check for parse errors *)
			IF module # NIL THEN
				ClearHighlights;
				ClearErrorHighlights;
				posKeeper.Clear;

				tree.SetNodeState(rootNode, {WMTrees.NodeAlwaysExpanded});
				tree.SetNodeCaption(rootNode, module.name);

				tree.SetNodeData(rootNode, GetTextInfo(module.name^, module.pos.a, module.pos.b, 0FFH, {WMGraphics.FontBold}, module));
				definitions := NIL; references := NIL; singleSuggestion := NIL; actualParameter := NIL;
				IF module.altPos.valid THEN
					NEW(references); references.no := module;
					references.fp := posKeeper.AddPos(module.altPos.a);
					references.tp := posKeeper.AddPos(module.altPos.b);
				END;
				TraverseScope(rootNode, module.scope);

				comments := NIL;
				SearchUses(module.scope, references);

(*				This seems to lose a reference.
				IF references # NIL THEN
					(* copy references into an array for easy sortation *)
					cr := references; count := 0; WHILE cr # NIL DO INC(count); cr := cr.next END;
					NEW(refs, count); cr := references; i:= 0; WHILE cr # NIL DO refs[i] := cr; INC(i); cr := cr.next END;
					QuickSort(refs, 0, LEN(refs^) -1);
					(* recreate the linear list for reuse *)
					references := refs[0]; cr := references;
					FOR i := 1 TO count - 1 DO cr.next := refs[i]; cr := cr.next; END;
					refs[count - 1].next := NIL;
				(*	KernelLog.String("reference count= "); KernelLog.Int(count, 0); KernelLog.Ln; *)
				END; *)

				modified := FALSE;
			END;
			t1 := Kernel.GetTicks();
			KernelLog.Int((t1-t0), 0); KernelLog.String("ms"); KernelLog.Ln;
			done := TRUE;
		(* Need to catch errors to release locks and let the editing continue*)
		FINALLY
			IF ~done THEN
				TextUtilities.Store(editor.text, "crashtext.txt", "UTF-8", res)
			END
		END Refresh;

		PROCEDURE AddNodes(parent : PETTrees.TreeNode; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		BEGIN
			AddNodes^(parent, diagnostics, log);
			Refresh(parent)
		END AddNodes;
		
		PROCEDURE HighlightReferences(no : TS.NamedObject);
		VAR
			cur : CurrentHighlights;
			cr : Reference;
		BEGIN
			ClearHighlights();
			cr := references;
			WHILE cr # NIL DO
				IF cr.no = no THEN
					NEW(cur); cur.next := useHighlights; useHighlights := cur;
					cur.h := editor.tv.CreateHighlight();
					cur.h.SetColor(07FFF3380H);
					cur.h.SetFromTo(posKeeper.GetPos(cr.fp),posKeeper.GetPos(cr.tp));
				END;
				cr := cr.next
			END;			
		END HighlightReferences;
		
		PROCEDURE SelectReferences(d : TextInfo; gotoDef : BOOLEAN);
		BEGIN
			editor.DisableUpdate;
			currentNode := d;
			currentUse := NIL;
			
			HighlightReferences(d.def);
			IF gotoDef THEN
				editor.tv.cursor.SetPosition(posKeeper.GetPos(currentNode.fp));
				editor.tv.cursor.SetVisible(TRUE);
			END;
			highlight.SetFromTo(posKeeper.GetPos(currentNode.fp), posKeeper.GetPos(currentNode.tp));
			editor.EnableUpdate;
			editor.Invalidate()
		END SelectReferences;

		PROCEDURE SelectActualParameters(def : TS.NamedObject);
		VAR
			cur : CurrentHighlights;
			cr : Reference; tp : LONGINT;
		BEGIN
			editor.DisableUpdate;

			cr := actualParameter;
			WHILE cr # NIL DO
				IF cr.no = def THEN
					NEW(cur); cur.next := useHighlights; useHighlights := cur;
					cur.h := editor.tv.CreateHighlight();
					cur.h.SetColor(000FF3380H);
					IF cr.np # -1 THEN tp := posKeeper.GetPos(cr.np) ELSE tp := posKeeper.GetPos(cr.tp) END;
					cur.h.SetFromTo(posKeeper.GetPos(cr.fp), tp);
				END;
				cr := cr.next
			END;
			editor.EnableUpdate;
			editor.Invalidate()
		END SelectActualParameters;

		PROCEDURE HasActualParameters(def : TS.NamedObject) : BOOLEAN;
		VAR
			cr : Reference;
		BEGIN
			cr := actualParameter;
			WHILE cr # NIL DO
				IF cr.no = def THEN RETURN TRUE END;
				cr := cr.next
			END;
			RETURN FALSE
		END HasActualParameters;

		PROCEDURE ClickNode(sender, data : ANY);
		VAR
			d: ANY;
			text : Texts.Text;
		BEGIN
			currentNode := NIL;
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				d := tree.GetNodeData(data(WMTrees.TreeNode));
				tree.Release;
				IF (d # NIL) & (d IS TextInfo) THEN
					IF d(TextInfo).def # NIL THEN
						KernelLog.String("def.name= "); KernelLog.String(d(TextInfo).def.name^); KernelLog.Ln;
						ST.ID(d(TextInfo).def);
					ELSE KernelLog.String("def.name=NIL"); KernelLog.Ln
					END;
					text := editor.text;
					text.AcquireRead;
					SelectReferences(d(TextInfo), TRUE);
					SelectActualParameters(d(TextInfo).def);
					text.ReleaseRead;
					editor.SetFocus()
				END
			END
		END ClickNode;

		PROCEDURE ClearHighlights;
		VAR cc : Comment;
			cur : CurrentHighlights;
		BEGIN
			editor.DisableUpdate;
			(* remove comment highlights *)
			cc := comments;
			WHILE cc # NIL DO
				IF cc.h # NIL THEN editor.tv.RemoveHighlight(cc.h) END;
				cc := cc.next
			END;

			(* remove use highlight *)
			cur := useHighlights;
			WHILE cur # NIL DO
				editor.tv.RemoveHighlight(cur.h);
				cur := cur.next
			END;
			useHighlights := NIL;

			editor.EnableUpdate;
			editor.Invalidate()
		END ClearHighlights;

		PROCEDURE ClearErrorHighlights;
		VAR cur : CurrentHighlights;
		BEGIN
			editor.DisableUpdate;
			cur := errorHighlights;
			WHILE cur # NIL DO
				editor.tv.RemoveHighlight(cur.h);
				cur := cur.next
			END;
			errorHighlights := NIL;

			cur := tempHighlights;
			WHILE cur # NIL DO
				editor.tv.RemoveHighlight(cur.h);
				cur := cur.next
			END;
			tempHighlights := NIL;

			singleSuggestion := NIL;
			editor.EnableUpdate;
			editor.Invalidate()
		END ClearErrorHighlights;

		PROCEDURE PublicBtnHandler(sender, data: ANY);
		VAR
			node : WMTrees.TreeNode;
			d : ANY;
			no : TS.NamedObject;
			public : BOOLEAN;
		BEGIN
			tree.Acquire;
			public := publicBtn.GetPressed();
			node := tree.GetRoot();
			WHILE node # NIL DO
				node := GetNextNode(node, FALSE);
				d := tree.GetNodeData(node);
				IF (d # NIL) & (d IS TextInfo) THEN
					IF (d(TextInfo).def # NIL) & (d(TextInfo).def IS TS.NamedObject) THEN
						no := d(TextInfo).def(TS.NamedObject);
						IF public & (no.exportState = {}) THEN
							tree.InclNodeState(node, WMTrees.NodeHidden)
						ELSE
							tree.ExclNodeState(node, WMTrees.NodeHidden)
						END
					END
				END
			END;
			tree.Release;
		END PublicBtnHandler;

		PROCEDURE RenameHandler(sender, data: ANY);
		VAR name, curname : ARRAY 64 OF CHAR;
			instances, replacements : LONGINT;
			cur : Reference;

			PROCEDURE Replace(a, b : LONGINT; CONST  old, new : ARRAY OF CHAR) : BOOLEAN;
			VAR oldname : ARRAY 64 OF CHAR;
			BEGIN
				TextUtilities.SubTextToStr(editor.text, a, b - a, oldname);
				IF oldname = old THEN
					editor.text.Delete(a, b - a);
					TextUtilities.StrToText(editor.text, a, new);
					RETURN TRUE
				ELSE
					KernelLog.String(curname); KernelLog.String(" expected "); KernelLog.String(oldname); KernelLog.String(" found. Not replaced"); KernelLog.Ln;
					RETURN FALSE
				END
			END Replace;

		BEGIN
			IF currentNode = NIL THEN RETURN END;
			tree.Acquire;

			(*editor.text.debug := TRUE; *)
			editor.text.AcquireWrite;
(*			IF modified THEN
				Refresh(tree.GetRoot());
			END; *)
(* TODO: find the current node again *)
			IF ~modified THEN
				WMDialogs.Information("Not up to date", "Refresh first")
			ELSE
				instances := 0; replacements := 0;
				COPY(currentNode.def.name^, curname);
				COPY(curname, name);
				IF WMDialogs.QueryString("Rename the identifier (No warning for collisions !)", name) = 0 THEN
					IF name # curname THEN
						IF Replace(posKeeper.GetPos(currentNode.fp),posKeeper.GetPos( currentNode.tp), curname, name) THEN
							INC(replacements);
							cur := references;
							WHILE cur # NIL DO
								IF cur.no = currentNode.def THEN
									INC(instances);
									IF Replace(posKeeper.GetPos(cur.fp), posKeeper.GetPos(cur.tp), curname, name) THEN INC(replacements) END
								END;
								cur := cur.next
							END
						END
					END
				END;
				KernelLog.String("instances= "); KernelLog.Int(instances, 0); KernelLog.String("replacements= "); KernelLog.Int(replacements, 0); KernelLog.Ln;
			END;
			editor.text.ReleaseWrite;
			(* editor.text.debug := FALSE; *)
			tree.Release;
			RefreshHandler(sender, data)
		END RenameHandler;

		PROCEDURE SelectRangeHandler(sender, data: ANY);
		VAR
			a, b, ch : LONGINT;
			r : Texts.TextReader;
		BEGIN
			IF currentNode = NIL THEN RETURN END;
			IF currentNode.def = NIL THEN RETURN END;

			IF ~currentNode.def.pos.valid OR ~currentNode.def.altPos.valid THEN
				KernelLog.String("Positions not valid"); KernelLog.Ln;
				RETURN
			END;
			tree.Acquire;
			editor.text.AcquireWrite;
			a := currentNode.def.pos.a;
			b := currentNode.def.altPos.b + 1;

			IF currentNode.def.preComment # NIL THEN
				a := currentNode.def.preComment.first.pos.a
			END;

			NEW(r, editor.text); r.SetDirection(-1); r.SetPosition(a);
			REPEAT
				r.ReadCh(ch);
				DEC(a)
			UNTIL (r.eot) OR (ch = Texts.NewLineChar);

			IF ~r.eot THEN r.ReadCh(ch); IF ch = Texts.NewLineChar THEN DEC(a) END END;

			NEW(r, editor.text); r.SetDirection(1); r.SetPosition(b);
			REPEAT
				r.ReadCh(ch);
				INC(b)
			UNTIL (r.eot) OR (ch = Texts.NewLineChar);

			editor.tv.selection.SetFromTo(a, b);
			editor.text.ReleaseWrite;
			tree.Release;
			RefreshHandler(sender, data)
		END SelectRangeHandler;

		PROCEDURE DelActualParameterHandler(sender, data: ANY);
		VAR
			a, b, instances : LONGINT;
			cur : Reference;
		BEGIN
			IF currentNode = NIL THEN RETURN END;
			tree.Acquire;
			editor.text.AcquireWrite;
			instances := 0;
			a := posKeeper.GetPos(currentNode.fp);
			b := posKeeper.GetPos(currentNode.tp);
			editor.text.Delete(a, b - a);

			cur := actualParameter;
			WHILE cur # NIL DO
				IF cur.no = currentNode.def THEN
					IF cur.np # -1 THEN b := posKeeper.GetPos(cur.np) ELSE b := posKeeper.GetPos(cur.tp) END;
					a := posKeeper.GetPos(cur.fp);
					editor.text.Delete(a, b - a);
					INC(instances);
				END;
				cur := cur.next
			END;
			KernelLog.String("instances= "); KernelLog.Int(instances, 0);  KernelLog.Ln;
			editor.text.ReleaseWrite;
			tree.Release;
			RefreshHandler(sender, data)
		END DelActualParameterHandler;

		PROCEDURE NextUseHandler(sender, data : ANY);
		VAR
			text : Texts.Text;
		BEGIN
			IF currentNode # NIL THEN
				IF currentUse = NIL THEN currentUse := references END;
				REPEAT currentUse := currentUse.next UNTIL (currentUse = NIL) OR (currentUse.no = currentNode.def);
				IF currentUse # NIL THEN
					text := editor.text;
					text.AcquireRead;
					editor.tv.cursor.SetPosition(posKeeper.GetPos(currentUse.fp));
					editor.tv.cursor.SetVisible(TRUE);
					text.ReleaseRead;
					editor.SetFocus()
				END
			END
		END NextUseHandler;

		PROCEDURE GetTextInfo(CONST name: ARRAY OF CHAR; fp, tp: LONGINT; color: LONGINT; style: SET; def : TS.NamedObject): TextInfo;
		VAR newInfo: TextInfo; font: WMGraphics.Font;
		BEGIN
			NEW(newInfo); newInfo.next := definitions; definitions := newInfo;
			newInfo.name := Strings.NewString(name);
			newInfo.color := color;
			IF style = {} THEN
				font := treeFontOberon10Plain
			ELSIF style = {WMGraphics.FontBold} THEN
				font := treeFontOberon10Bold
			ELSIF style = {WMGraphics.FontItalic} THEN
				font := treeFontOberon10Italic
			ELSE
				(* unknown style *)
				font := treeFontOberon10Plain
			END;
			newInfo.def := def;
			newInfo.font := font;
			newInfo.fp := posKeeper.AddPos(fp);

			NEW(newInfo.pos, editor.text);
			newInfo.pos.SetPosition(fp);

			newInfo.tp := posKeeper.AddPos(tp);
			RETURN newInfo
		END GetTextInfo;

		PROCEDURE NewNode(parent: WMTrees.TreeNode; caption: Strings.String; ti : TextInfo): WMTrees.TreeNode;
		VAR newNode: WMTrees.TreeNode;
		BEGIN
			IF parent # NIL THEN
				NEW(newNode);
				tree.SetNodeCaption(newNode, caption);
				tree.SetNodeData(newNode, ti);
				tree.AddChildNode(parent, newNode)
			END;
			RETURN newNode
		END NewNode;

		PROCEDURE TraverseTypeScope(curNode : WMTrees.TreeNode;t : TS.Type);
		BEGIN
			IF (t = NIL) THEN
				KernelLog.String("Illegal type def"); KernelLog.Ln;
				RETURN;
			END;
			CASE t.kind OF
				|TS.TAlias : (*DumpDesignator(t.qualident) *)
				|TS.TObject :
					IF t.object # NIL THEN
						TraverseScope(curNode, t.object.scope);
					END;
				|TS.TArray : TraverseTypeScope(curNode, t.array.base);
				|TS.TPointer : TraverseTypeScope(curNode, t.pointer.type)
				|TS.TRecord : TraverseScope(curNode, t.record.scope)
			(*	|TS.TProcedure : DumpProcedure(t.procedure) *)
			ELSE
			END
		END TraverseTypeScope;

		PROCEDURE TraverseProcDecl(curNode : WMTrees.TreeNode; p : TS.ProcDecl);
		VAR params, node : WMTrees.TreeNode;
			cur : TS.NamedObject;
			i : LONGINT;
			ti : TextInfo;
		BEGIN
			IF (p.signature # NIL) & (p.signature.params # NIL) THEN
				params := NewNode(curNode, Strings.NewString("Parameter"), NIL);
				FOR i := 0 TO p.signature.params.nofObjs - 1 DO
					cur := p.signature.params.objs[i];
					ti := GetTextInfo("", cur.pos.a, cur.pos.b, 0AAFFH, {}, cur);
					node := NewNode(params, cur.name, ti);
				END
			END;
			IF p.scope # NIL THEN
			(*	locals := NewNode(curNode, Strings.NewString("Locals"), NIL); *)
				TraverseScope(curNode, p.scope)
			END
		END TraverseProcDecl;

		PROCEDURE MakeReference(no : TS.NamedObject; from, to : LONGINT);
		VAR nr : Reference;
		BEGIN
			NEW(nr); nr.next := references; references := nr;
			nr.no := no; nr.fp := posKeeper.AddPos(from); nr.tp := posKeeper.AddPos(to)
		END MakeReference;

		PROCEDURE UnknownIdentifierError(scope: TS.Scope; first : BOOLEAN; ident : TS.Ident);
		VAR s : ARRAY 1024 OF CHAR;
			cur : CurrentHighlights;
			color : LONGINT;
			suggestions : TS.ObjectList;
			nofSuggestions : LONGINT;
		BEGIN
			color := LONGINT(0FF000080H);
			TS.s.GetString(ident.name, s);
		(*	KernelLog.String("*** Unknown identifier :"); KernelLog.String(s); KernelLog.Ln; *)
			IF editor.tv.cursor.GetPosition() = ident.pos.b THEN
				suggestionStart := ident.pos.a;
				cursorScope := scope;
				cursorIsFirstLevelScope := first;
				color := LONGINT(0FF800080H);
				NEW(suggestions);
				FindSuggestions(scope, first, s, suggestions);
				IF suggestions.nofObjs > 0 THEN color := LONGINT(000008080H) END;
				IF suggestions.nofObjs = 1 THEN singleSuggestion := suggestions.objs[0] END;
			END;
			NEW(cur); cur.next := errorHighlights; errorHighlights := cur;
			cur.h := editor.tv.CreateHighlight();
			cur.h.SetColor(color);

			cur.h.SetFromTo(ident.pos.a, ident.pos.b);
		END UnknownIdentifierError;

		(* Add scope declarations to the tree *)
		PROCEDURE TraverseScope(curNode : WMTrees.TreeNode; scope : TS.Scope);
		VAR i : LONGINT;
			last, cur : TS.NamedObject;
			node : WMTrees.TreeNode;
			ti : TextInfo;
			imports, consts, vars : WMTrees.TreeNode;
			type : TS.Type;
			procType : LONGINT;
			image : WMGraphics.Image;
			d : ANY;

			PROCEDURE Insert(parent : WMTrees.TreeNode; color : LONGINT; style : SET);
			BEGIN
				ti := GetTextInfo("", cur.pos.a, cur.pos.b, color, style, cur);
				IF cur.altPos.valid THEN MakeReference(cur, cur.altPos.a, cur.altPos.b) END;
				node := NewNode(parent, cur.name, ti);
			END Insert;

		BEGIN
			IF scope = NIL THEN RETURN END;
			FOR i := 0 TO scope.elements.nofObjs - 1 DO
				cur := scope.elements.objs[i];
				IF cur IS TS.Const THEN
					IF consts = NIL THEN
						NEW(consts);
						tree.SetNodeCaption(consts, Strings.NewString("CONST"));
						tree.AddChildNode(curNode, consts)
					END;
					Insert(consts, 0FFFFH, {WMGraphics.FontBold});
				ELSIF cur IS TS.TypeDecl THEN
					(* In case of an object type, the name is defined by the type name, the
					    name at the end of the OBJECT block is a non functional use. Copy
					    the alternative position value *)
					IF (cur(TS.TypeDecl).type.kind = TS.TObject) THEN
						cur(TS.TypeDecl).altPos := cur(TS.TypeDecl).type.object.altPos
					END;
					Insert(curNode, 0FFFFH, {WMGraphics.FontItalic});
					IF (cur(TS.TypeDecl).type.kind = TS.TObject) & (cur(TS.TypeDecl).type.object.scope.superQualident # NIL) THEN
						AddPostfixToCaption(node, Strings.NewString(" ("));
						AddPostfixToCaption(node, ST.QualidentToString(scope, cur(TS.TypeDecl).type.object.scope.superQualident));
						AddPostfixToCaption(node, Strings.NewString(")"));
					ELSIF (cur(TS.TypeDecl).type.kind = TS.TPointer) THEN
						IF (cur(TS.TypeDecl).type.pointer.type.kind = TS.TRecord) &
						  (cur(TS.TypeDecl).type.pointer.type.record.scope.superQualident # NIL) THEN
							AddPostfixToCaption(node, Strings.NewString(" ("));
							AddPostfixToCaption(node, ST.QualidentToString(scope, cur(TS.TypeDecl).type.pointer.type.record.scope.superQualident));
							AddPostfixToCaption(node, Strings.NewString(")"));
						END
					END;
					TraverseTypeScope(node, cur(TS.TypeDecl).type);
				ELSIF cur IS TS.Var THEN
					IF vars = NIL THEN
						NEW(vars);
						tree.SetNodeCaption(vars, Strings.NewString("VAR"));
						tree.AddChildNode(curNode, vars)
					END;
					Insert(vars, 07C0000FFH, {});
					IF type # cur(TS.Var).type THEN TraverseTypeScope(node, cur(TS.Var).type) END; type := cur(TS.Var).type
				ELSIF cur IS TS.ProcDecl THEN
					Insert(curNode, 0FFH, {WMGraphics.FontBold});

					IF scope = module.scope THEN
						procType := GetProcedureType(cur(TS.ProcDecl));

						IF (procType = ProcCommand) THEN
							tree.Acquire;
							d := tree.GetNodeData(node);
						(*	IF (d # NIL) & (d IS TextInfo) THEN INCL(d(TextInfo).flags, CanExecute) END; *)
							image := WMGraphics.LoadImage(ImageCommandProc, TRUE);
							tree.SetNodeImage(node, image);
							tree.Release;
						END;
					END;
					TraverseProcDecl(node, cur(TS.ProcDecl))
				ELSIF cur IS TS.Import THEN
					IF imports = NIL THEN
						NEW(imports);
						tree.SetNodeCaption(imports, Strings.NewString("IMPORTS"));
						tree.AddChildNode(curNode, imports)
					END;
					Insert(imports, 0FFH, {});
				END;
				last := cur;
			END
		END TraverseScope;

		PROCEDURE GetNextNode(this : WMTrees.TreeNode; ignoreChildren : BOOLEAN) : WMTrees.TreeNode;
		VAR state : SET;
		BEGIN
			state := tree.GetNodeState(this);
			IF ~ignoreChildren  & (tree.GetChildren(this) # NIL) THEN RETURN tree.GetChildren(this);
			ELSIF tree.GetNextSibling(this) # NIL THEN RETURN tree.GetNextSibling(this);
			ELSIF tree.GetParent(this) # NIL THEN RETURN GetNextNode(tree.GetParent(this), TRUE)
			ELSE RETURN NIL
			END;
		END GetNextNode;

		PROCEDURE SelectNodeByNamedObject(no : TS.NamedObject; gotoDef: BOOLEAN) : BOOLEAN;
		VAR node : WMTrees.TreeNode;
			d : ANY;
		BEGIN
			tree.Acquire;
			node := tree.GetRoot();
			WHILE node # NIL DO
				node := GetNextNode(node, FALSE);
				d := tree.GetNodeData(node);
				IF (d # NIL) & (d IS TextInfo) THEN
					IF d(TextInfo).def = no THEN
						treeView.SelectNode(node);
						tree.ExpandToRoot(node);
						SelectReferences(d(TextInfo), gotoDef);
						tree.Release;
						RETURN TRUE;
					END
				END
			END;
			tree.Release;
			RETURN FALSE
		END SelectNodeByNamedObject;

		PROCEDURE FindScopeByPos(pos : LONGINT);
		VAR cur : TextInfo;
			cand, scope : TS.NamedObject;
			candDist, dist : LONGINT;
		BEGIN
			cur := definitions;
			scope := NIL;
			WHILE cur # NIL DO
				cand := cur.def;

				IF (cand IS TS.ProcDecl) OR
					(cand IS TS.TypeDecl) & (cand(TS.TypeDecl).type.kind = TS.TObject) THEN
					KernelLog.String("#");
					IF cand.pos.valid & cand.altPos.valid THEN
						dist := cand.altPos.b - cand.pos.a;
						IF (pos >= cand.pos.a) & (pos <= cand.altPos.b) &
							((scope = NIL) OR (dist < candDist)) THEN
							candDist := dist;
							scope := cand;
							editor.tv.selection.SetFromTo(cand.pos.a, cand.altPos.b);
						END
					END
				END;
				KernelLog.String("  "); KernelLog.String(cand.name^); KernelLog.Ln;
				cur := cur.next
			END;
			IF scope = NIL THEN scope := module END;
			KernelLog.String("  -->  "); KernelLog.String(scope.name^); KernelLog.Ln;
		END FindScopeByPos;

		PROCEDURE FindIdentByPos(pos : LONGINT);
		VAR cur : Reference; ct : TextInfo; c : LONGINT;
			msg : PETTrees.ExternalDefinitionInfo;
			filename, definition : ARRAY 256 OF CHAR;
			m : TS.Module;
		BEGIN
			(* Search uses *)
			cur := references; c := 0;
			WHILE cur # NIL DO
				INC(c);
				IF (pos >= posKeeper.GetPos(cur.fp)) & (pos <= posKeeper.GetPos(cur.tp)) THEN
					IF ~SelectNodeByNamedObject(cur.no, TRUE) THEN
						(* Ask PET to load and show in different tab *)
						ST.ID(cur.no);
						ST.GetSourceReference(cur.no, filename, definition);
						KernelLog.String("filename= "); KernelLog.String(filename); KernelLog.Ln;
						NEW(msg, filename, definition);
						onGoToDefinition.Call(msg);
					END;
					RETURN
				ELSE cur := cur.next
				END
			END;
			KernelLog.String("references searched c= "); KernelLog.Int(c, 0); KernelLog.Ln;
			(* not found search for definitions*)
			ct := definitions; c := 0;
			WHILE ct # NIL DO
				c := 0;
				IF (pos >= posKeeper.GetPos(ct.fp)) & (pos <= posKeeper.GetPos(ct.tp)) THEN
					IF (ct.def # NIL) & (ct.def IS TS.Import) THEN
						m := TS.ns.GetModule(ct.def(TS.Import).import^);
						IF m = NIL THEN
							m := TS.ReadSymbolFile(ct.def(TS.Import).import^)
						END;
						IF (m # NIL) & (m.filename # NIL) THEN
							COPY(m.filename^,  filename);
							definition := "";
							KernelLog.String("filename= "); KernelLog.String(filename); KernelLog.Ln;
							NEW(msg, filename, definition);
							onGoToDefinition.Call(msg);
						END
					ELSIF ~ SelectNodeByNamedObject(ct.def, TRUE) THEN
						KernelLog.String("Definition not found in tree : "); KernelLog.Ln;
						ST.ID(ct.def);
					END;
					RETURN
				ELSE ct := ct.next
				END
			END;
			KernelLog.String("definitions searched c= "); KernelLog.Int(c, 0); KernelLog.Ln;
			KernelLog.String("Not found"); KernelLog.String(" pos= "); KernelLog.Int(pos, 0); KernelLog.Ln;

		END FindIdentByPos;

		PROCEDURE HandleMacro*(sender, data: ANY);
		VAR md : WMEditors.MacroData; text : Texts.Text; cursor : WMTextView.PositionMarker;
		BEGIN
			IF (data # NIL) & (data IS WMEditors.MacroData) THEN
				md := data(WMEditors.MacroData);
				IF md.keySym = 0FFC9H THEN
					text := md.text; cursor := md.cursor;
					md.handled := TRUE;
					FindIdentByPos(cursor.GetPosition())
				ELSIF md.keySym = 0FFC2H THEN
					RefreshHandler(sender, data);
					md.handled := TRUE
				END;
			END
		END HandleMacro;

		PROCEDURE Follow(sender, data : ANY);
		BEGIN
			FindIdentByPos(editor.tv.cursor.GetPosition())
		END Follow;

		PROCEDURE AddComments(c : TS.Comments);
		VAR cur : TS.Comment;
			nc : Comment;
		BEGIN
			IF c = NIL THEN RETURN END;
			cur := c.first;
			WHILE cur # NIL DO
				NEW(nc); nc.next := comments; comments := nc;
				nc.fp := posKeeper.AddPos(cur.pos.a);
				nc.tp := posKeeper.AddPos(cur.pos.b);
				cur := cur.next
			END
		END AddComments;

		PROCEDURE SearchUses*(d : TS.Scope;  VAR ref : Reference);
		VAR i : LONGINT;
			last, cur : TS.NamedObject;
			nr : Reference;
			lastVarType : TS.Type;

			PROCEDURE CheckExpressionList(e : TS.ExpressionList; sig : TS.ProcedureSignature; scope : TS.Scope);
			VAR i, a, b : LONGINT; nr, f : Reference;
			BEGIN
				i := 0;
				f := NIL;
				WHILE e # NIL DO
					CheckExpression(e.expression, scope);
					IF (sig # NIL) & (sig.params # NIL)  THEN
						IF i < sig.params.nofObjs THEN
							a := -1; b := -1; GetExpressionRange(e.expression, a, b);
							IF (a >= 0) & (b > a) THEN
								NEW(nr); nr.next := actualParameter; actualParameter := nr; nr.np := -1;
								nr.no := sig.params.objs[i];
								nr.fp := posKeeper.AddPos(a);
								nr.tp := posKeeper.AddPos(b);
								IF f # NIL THEN f.np := nr.fp END; f := nr;
							END
						ELSE
							GetExpressionRange(e.expression, a, b);
							KernelLog.String("pos = "); KernelLog.Int(a, 0); KernelLog.String(" more parameter than expected ")
						END
					END;
					INC(i);
					e := e.next
				END
			END CheckExpressionList;

			PROCEDURE GetDesignatorRange(d : TS.Designator; VAR a, b : LONGINT);
			BEGIN
				IF d IS TS.Ident THEN
					IF (a = -1) OR (d(TS.Ident).pos.a < a) THEN a := d(TS.Ident).pos.a END;
					IF d(TS.Ident).pos.b > b THEN b := d(TS.Ident).pos.b END;
				ELSIF d IS TS.Index THEN
				ELSIF d IS TS.ActualParameters THEN
				END;
				IF (d.next # NIL) THEN
					GetDesignatorRange(d.next, a, b)
				END
			END GetDesignatorRange;

			PROCEDURE GetExpressionRange(e : TS.Expression; VAR a, b : LONGINT);
			VAR ta, tb : LONGINT;
			BEGIN
				ta := -1; tb := -1; IF e =  NIL THEN RETURN END;
				IF e.kind = TS.ExpressionPrimitive THEN
				ELSIF e.kind = TS.ExpressionUnary THEN
					GetExpressionRange(e.a, ta, tb);
					IF a = -1 THEN a := ta END;
					IF (ta # -1) & (ta < a) THEN a := ta END;IF (tb > b) THEN b := tb END;
				ELSIF e.kind = TS.ExpressionBinary THEN
					GetExpressionRange(e.a, ta, tb);
					IF a = -1 THEN a := ta END;
					IF (ta # -1) & (ta < a) THEN a := ta END;IF (tb > b) THEN b := tb END;
					ta := -1; tb := -1;
					GetExpressionRange(e.b, ta, tb);
					IF a = -1 THEN a := ta END;
					IF (ta # -1) & (ta < a) THEN a := ta END;IF (tb > b) THEN b := tb END;
				ELSIF e.kind = TS.ExpressionDesignator THEN
					GetDesignatorRange(e.designator, a, b)
				END
			END GetExpressionRange;

			PROCEDURE CheckExpression(e : TS.Expression; scope : TS.Scope);
			VAR t : TS.Type;
				sr : TS.SetRange;
			BEGIN
				IF e = NIL THEN KernelLog.String("Expression is NIL"); RETURN END;
				IF e.kind = TS.ExpressionPrimitive THEN
					IF e.basicType = TS.BasicSet THEN
						sr := e.setValue.setRanges;
						WHILE sr # NIL DO
							IF sr.a # NIL THEN CheckExpression(sr.a, scope) END;
							IF sr.b # NIL THEN CheckExpression(sr.b, scope) END;
							sr := sr.next
						END;
					END;
				ELSIF e.kind = TS.ExpressionUnary THEN
					CheckExpression(e.a, scope);
				ELSIF e.kind = TS.ExpressionBinary THEN
					CheckExpression(e.a, scope);
					IF e.op # TS.OpIs THEN CheckExpression(e.b, scope)
					ELSE
						t := ST.FindType(e.b.designator, scope);
						CheckDesignator(e.b.designator, scope);
						IF t = NIL THEN KernelLog.String("pos = "); KernelLog.Int(e.b.designator(TS.Ident).pos.a, 0); KernelLog.String(" Type not found ") END;
					END
				ELSIF e.kind = TS.ExpressionDesignator THEN
					CheckDesignator(e.designator, scope)
				END;
			END CheckExpression;

			PROCEDURE CheckSuperClass(o : TS.Class; scope : TS.Scope);
			VAR st : TS.Type;
			BEGIN
				IF (o.scope.super = NIL) & (o.scope.super # NIL) THEN
				(*	KernelLog.String("Searching for super type :");  ST.ShowDesignator(o.super); KernelLog.Ln; *)
					st := ST.DealiaseType(ST.FindType(o.scope.superQualident, scope));
					IF st # NIL THEN
						IF st.kind = TS.TObject THEN
							o.scope.super := st.object.scope;
						ELSE KernelLog.String("super type is not an class"); KernelLog.Ln;
						END
					(* ELSE KernelLog.String("No information about super type "); KernelLog.Ln; *)
					END
				END
			END CheckSuperClass;

			PROCEDURE CheckDesignator(d : TS.Designator; scope : TS.Scope);
			VAR no: TS.NamedObject;
				curScope : TS.Scope;
				type, temptype : TS.Type;

				first : BOOLEAN;
				s : ARRAY 64 OF CHAR;
				m : TS.Module;
				te : TS.ExpressionList;
				lastpos : LONGINT;

				PROCEDURE SetReference(id : TS.Ident; no : TS.NamedObject);
				BEGIN
					NEW(nr); nr.next := ref; ref := nr;
					nr.no := no;
					nr.fp := posKeeper.AddPos(id.pos.a);
					nr.tp := posKeeper.AddPos(id.pos.b);
				END SetReference;

			BEGIN
				first := TRUE;
				curScope := scope;
				WHILE d # NIL DO
					IF d IS TS.Ident THEN
						lastpos := d(TS.Ident).pos.a;
						TS.s.GetString(d(TS.Ident).name, s);
						IF first & (s = "SELF") THEN
							curScope := scope.parent;
							(* look for object or module represented by SELF*)
							WHILE (curScope.parent # NIL) & (curScope.owner # NIL) &
								~((curScope.owner IS TS.Class) OR (curScope.owner IS TS.Module)) DO
								curScope := curScope.parent
							END;
							IF curScope = NIL THEN
								KernelLog.String("SELF could not be resolved"); KernelLog.Ln;
							END;
						ELSIF first & (s = "SYSTEM") THEN
							d := d.next;
							IF d # NIL THEN
								IF d IS TS.Ident THEN
									TS.s.GetString(d(TS.Ident).name, s);
									IF s = "VAL" THEN
										d := d.next;
										IF d # NIL THEN
											IF d IS TS.ActualParameters THEN
												te := d(TS.ActualParameters).expressionList;
												IF te # NIL THEN
													IF te.expression.kind = TS.ExpressionDesignator THEN
														temptype := ST.FindType(te.expression.designator, scope);
														IF temptype = NIL THEN KernelLog.String("pos = "); KernelLog.Int(te.expression.designator(TS.Ident).pos.a, 0); KernelLog.String(" Type not found ") END;
													END;
													te := te.next;
													CheckExpression(te.expression, scope);
												ELSE
													KernelLog.String("type arameter expeced"); KernelLog.Ln;
												END
											ELSE
												KernelLog.String("parameters expeced"); KernelLog.Ln;
											END
										ELSE
											KernelLog.String("Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(s); KernelLog.String("Ident expeced"); KernelLog.Ln;

										END
									END
								ELSE
									KernelLog.String(s); KernelLog.String("Ident expeced"); KernelLog.Ln;
								END
							ELSE
								KernelLog.String("Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(s); KernelLog.String("incomplete SYSTEM call"); KernelLog.Ln;
							END
						ELSE
							IF curScope # NIL THEN
								no := curScope.Find(s, first);
								IF (no = NIL) THEN
									UnknownIdentifierError(curScope, first, d(TS.Ident));
									RETURN;
								END;
								(* check if it is a super call or reference *)
								IF (no IS TS.ProcDecl) & (d.next # NIL) & (d.next IS TS.Dereference) THEN
									no.scope.parent.FixSuperScope;
									IF no.scope.parent.super # NIL THEN
										no := no.scope.parent.super.Find(s, FALSE)
									ELSE KernelLog.String("   super is NIL"); KernelLog.String(s); KernelLog.Ln;
									END
								END;
				 				SetReference(d(TS.Ident), no);
								IF no IS TS.Var THEN
									type := ST.DealiaseType(no(TS.Var).type);
									IF type # NIL THEN
										IF type.kind = TS.TRecord THEN curScope := type.record.scope
										ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
									END
								ELSIF no IS TS.ProcDecl THEN
									IF no(TS.ProcDecl).signature # NIL THEN
										type := ST.DealiaseType(no(TS.ProcDecl).signature.return);
										IF type # NIL THEN
											IF type.kind = TS.TRecord THEN curScope := type.record.scope
											ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
										END
									END;
								ELSIF no IS TS.Import THEN
									m := TS.GetModule(no(TS.Import));
									IF m # NIL THEN
										curScope := m.scope;
(*										ELSE
										KernelLog.String("No symbol information for : "); KernelLog.String(no(TS.Import).import^); KernelLog.Ln *)
									END
								ELSIF no IS TS.Const THEN
									IF d.next # NIL THEN
									END
(*									ELSE
									KernelLog.String(" Pos= "); KernelLog.Int(d(TS.Ident).pos.a, 0);  KernelLog.String(" : ");
									KernelLog.String("variable, const or procedure expected but "); ST.ID(no); KernelLog.Ln; *)
								END
							ELSE
								KernelLog.String("no scope"); KernelLog.Ln;
							END
						END
					ELSIF d IS TS.Dereference THEN IF d.next # NIL THEN d := d.next END;
					ELSIF d IS TS.Index THEN
						(* automatic dealiasing if index access *)
						IF (type # NIL) & (type.kind = TS.TPointer) THEN
							type := ST.DealiaseType(type.pointer.type) END;
						IF (type = NIL) OR ( type.kind # TS.TArray) THEN
							IF type # NIL THEN ST.ShowType(type) END;
							KernelLog.String("Type is not an array pos= "); KernelLog.Int(lastpos, 0);  KernelLog.Ln
						ELSE
							type := ST.DealiaseType(type.array.base);
							IF type # NIL THEN
								IF type.kind = TS.TRecord THEN curScope := type.record.scope
								ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
							END
						END;
						CheckExpressionList(d(TS.Index).expressionList, NIL,  scope);
					ELSIF d IS TS.ActualParameters THEN
						(* no is the item before "(" *)
						IF no # NIL THEN
							IF no IS TS.ProcDecl THEN
								CheckExpressionList(d(TS.ActualParameters).expressionList, no(TS.ProcDecl).signature, scope)
							ELSIF (no IS TS.Var) THEN
								type := ST.DealiaseType(no(TS.Var).type);
								IF  (type # NIL) & (type.kind = TS.TProcedure) THEN
									(* delegate *)
									IF type.procedure = NIL THEN
										KernelLog.String("no(TS.Var).type.procedure"); KernelLog.Ln;
									ELSIF type.procedure.signature = NIL THEN
										KernelLog.String("no(TS.Var).type.procedure.signature"); KernelLog.Ln;
									ELSE
										CheckExpressionList(d(TS.ActualParameters).expressionList, type.procedure.signature, scope)
									END;
								ELSE
								 	(* type guard *)
									IF d(TS.ActualParameters).expressionList # NIL THEN
										IF d(TS.ActualParameters).expressionList.next # NIL THEN
											KernelLog.String("lastpos= "); KernelLog.Int(lastpos, 0);
											KernelLog.String(" Can only guard for one type at once."); KernelLog.Ln
										ELSE
											IF d(TS.ActualParameters).expressionList.expression.kind = TS.ExpressionDesignator THEN
												type := ST.DealiaseType(ST.FindType(d(TS.ActualParameters).expressionList.expression.designator, scope));
												IF type # NIL THEN
													IF type.kind = TS.TRecord THEN curScope := type.record.scope
													ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
												END;
												CheckDesignator(d(TS.ActualParameters).expressionList.expression.designator, scope);
											ELSE
												KernelLog.String("Type expected"); KernelLog.Ln
											END
										END
									END
								END
							ELSE (* huh ? *)
								HALT(12345);
							END
						ELSE
							(* not found... fallback *)
							CheckExpressionList(d(TS.ActualParameters).expressionList, NIL, scope)
							(* probably because of a not found
							KernelLog.String("lastpos= "); KernelLog.Int(lastpos, 0);
							KernelLog.String(" No proc"); KernelLog.Ln *)
						END
					END;
					first := FALSE;

					(* Auto dereferencing *)
					IF type # NIL THEN
						IF type.kind = TS.TPointer THEN type := ST.DealiaseType(type.pointer.type) END;
						IF type # NIL THEN
							IF type.kind = TS.TRecord THEN curScope := type.record.scope
							ELSIF type.kind = TS.TObject THEN curScope := type.object.scope END
						END
					END;
					d := d.next
				END
			END CheckDesignator;

			PROCEDURE CheckCases(case : TS.Case; scope : TS.Scope);
			VAR cr : TS.CaseRange;
			BEGIN
				WHILE case # NIL DO
					cr := case.caseRanges;
					WHILE cr # NIL DO
						CheckExpression(cr.a, scope);
						IF cr.b # NIL THEN CheckExpression(cr.b, scope) END;
						cr := cr.next
					END;
					IF case.statements # NIL THEN SearchStatements(case.statements, scope) END;
					case := case.next
				END
			END CheckCases;

			PROCEDURE SearchStatements(s : TS.Statement; scope : TS.Scope);
			VAR ts : TS.Statement; t : TS.Type;
			BEGIN
				WHILE s # NIL DO
					AddComments(s.preComment); AddComments(s.postComment);
					IF s IS TS.Assignment THEN
						CheckDesignator(s(TS.Assignment).designator, scope);
						CheckExpression(s(TS.Assignment).expression, scope);
					ELSIF s IS TS.ProcedureCall THEN
						CheckDesignator(s(TS.ProcedureCall).designator, scope)
					ELSIF s IS TS.StatementBlock THEN
						SearchStatements(s(TS.StatementBlock).statements, scope);
					ELSIF s IS TS.IFStatement THEN
						CheckExpression(s(TS.IFStatement).expression, scope);
						SearchStatements(s(TS.IFStatement).then, scope);
						ts := s(TS.IFStatement).else;
						IF ts # NIL THEN
							SearchStatements(ts, scope);
						END;
					ELSIF s IS TS.WHILEStatement THEN
						CheckExpression(s(TS.WHILEStatement).expression, scope);
						SearchStatements(s(TS.WHILEStatement).statements, scope);
					ELSIF s IS TS.REPEATStatement THEN
						SearchStatements(s(TS.REPEATStatement).statements, scope);
						CheckExpression(s(TS.REPEATStatement).expression, scope);
					ELSIF s IS TS.LOOPStatement THEN
						SearchStatements(s(TS.LOOPStatement).statements, scope);
					ELSIF s IS TS.FORStatement THEN
						CheckDesignator(s(TS.FORStatement).variable, scope);
						CheckExpression(s(TS.FORStatement).fromExpression, scope);
						CheckExpression(s(TS.FORStatement).toExpression, scope);
						IF s(TS.FORStatement).byExpression # NIL THEN
							CheckExpression(s(TS.FORStatement).byExpression, scope);
						END;
						SearchStatements(s(TS.FORStatement).statements, scope);
					ELSIF s IS TS.RETURNStatement THEN
						IF s(TS.RETURNStatement).expression # NIL THEN CheckExpression(s(TS.RETURNStatement).expression, scope) END;
					ELSIF s IS TS.AWAITStatement THEN
						CheckExpression(s(TS.AWAITStatement).expression, scope);
					ELSIF s IS TS.WITHStatement THEN
						CheckDesignator(s(TS.WITHStatement).variable, scope);
						t := ST.FindType(s(TS.WITHStatement).type, scope);
						IF t = NIL THEN KernelLog.String("pos = "); KernelLog.Int(s(TS.WITHStatement).type(TS.Ident).pos.a, 0); KernelLog.String(" Type not found "); KernelLog.Ln;  END;
						SearchStatements(s(TS.WITHStatement).statements, scope);
					ELSIF s IS TS.CASEStatement THEN
						CheckExpression(s(TS.CASEStatement).expression, scope);
						CheckCases(s(TS.CASEStatement).cases, scope);
						IF s(TS.CASEStatement).else # NIL THEN
							SearchStatements(s(TS.CASEStatement).else, scope)
						END;
					END;
					s := s.next
				END
			END SearchStatements;

			PROCEDURE CheckSignature(sig : TS.ProcedureSignature);
			VAR i : LONGINT; cur : TS.NamedObject; t : TS.Type;
			BEGIN
				IF sig = NIL THEN RETURN END;
				IF sig.return # NIL THEN CheckType(sig.return) END;
				IF sig.params # NIL THEN
					t := NIL;
					FOR i := 0 TO sig.params.nofObjs - 1 DO
						cur := sig.params.objs[i];
						IF cur IS TS.Var THEN IF t # cur(TS.Var).type THEN CheckType(cur(TS.Var).type) END; t := cur(TS.Var).type
						ELSE KernelLog.String("non- variable as a parameter"); KernelLog.Ln
						END
					END
				END
			END CheckSignature;

			PROCEDURE CheckProcedure(p : TS.ProcDecl);
			BEGIN
				CheckSignature(p.signature);
				SearchUses(p.scope, ref);
			END CheckProcedure;

			PROCEDURE CheckType(t : TS.Type);
			BEGIN
				IF t = NIL THEN
					(* TODO: what ? *)
					RETURN
				END;
				CASE t.kind OF
					|TS.TAlias : CheckDesignator(t.qualident, t.container)
					|TS.TObject : CheckDesignator(t.object.scope.superQualident, t.container); CheckSuperClass(t.object, t.container); SearchUses(t.object.scope, ref)
					|TS.TArray : IF t.array.expression # NIL THEN CheckExpression(t.array.expression, t.container) END;
								CheckType(t.array.base)
					|TS.TPointer : CheckType(t.pointer.type)
					|TS.TRecord : CheckDesignator(t.record.scope.superQualident, t.container); SearchUses(t.record.scope, ref)
					|TS.TProcedure : (* CheckDeclarations(t.procedure.scope)*)
				ELSE
					KernelLog.String("t.kind= "); KernelLog.Int(t.kind, 0); KernelLog.Ln
				END
			END CheckType;

		BEGIN
			IF d = NIL THEN RETURN END;
			IF d.ownerBody # NIL THEN SearchStatements(d.ownerBody, d) END;
			FOR i := 0 TO d.elements.nofObjs - 1 DO
				cur := d.elements.objs[i];
				AddComments(cur.preComment); AddComments(cur.postComment);
				IF cur IS TS.Const THEN CheckExpression(cur(TS.Const).expression, d)
				ELSIF cur IS TS.TypeDecl THEN
					IF (cur(TS.TypeDecl).type.kind= TS.TObject) & (cur(TS.TypeDecl).type.object = NIL) THEN
						KernelLog.String("cur.name^= "); KernelLog.String(cur.name^); KernelLog.String(" will now lead to halt "); KernelLog.Ln;
					END;
					CheckType(cur(TS.TypeDecl).type)
				ELSIF cur IS TS.Var THEN
					IF (cur(TS.Var).type.kind= TS.TObject) & (cur(TS.Var).type.object = NIL) THEN
						KernelLog.String("cur.name^= "); KernelLog.String(cur.name^); KernelLog.String(" will now lead to halt "); KernelLog.Ln;
					END;
					IF lastVarType # cur(TS.Var).type THEN CheckType(cur(TS.Var).type) END; lastVarType := cur(TS.Var).type;
				ELSIF cur IS TS.ProcDecl THEN CheckProcedure(cur(TS.ProcDecl))
				END;
				last := cur
			END
		END SearchUses;

		PROCEDURE TextChanged(sender, data : ANY);
		BEGIN
			modified := TRUE;
			IF DoAutoRefresh THEN
				updateTimer.Stop(SELF, NIL);
				updateTimer.Start(SELF, NIL)
			END
		END TextChanged;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF (editor # NIL) & (editor.text # NIL) THEN
				editor.text.onTextChanged.Remove(TextChanged)
			END
		END Finalize;

	END ModuleTree;

VAR
	PrototypeShowTypeHierarchy, PrototypeShowImportedModules : WMProperties.BooleanProperty;
	treeFontOberon10Plain, treeFontOberon10Bold, treeFontOberon10Italic: WMGraphics.Font;
	PMTonBrowseExternal : Strings.String;

PROCEDURE GetInsertString(ident : TS.NamedObject; VAR newStr : ARRAY OF CHAR);
VAR signature : TS.ProcedureSignature;
	i : LONGINT;
BEGIN
	COPY(ident.name^, newStr);
	IF ident IS TS.ProcDecl THEN
		signature := ident(TS.ProcDecl).signature;
		IF signature # NIL THEN
			IF signature.params.nofObjs > 0 THEN Strings.Append(newStr, "(") END;
			FOR i := 0 TO signature.params.nofObjs - 1 DO
				Strings.Append(newStr, signature.params.objs[i].name^);
				IF i < signature.params.nofObjs - 1 THEN
					Strings.Append(newStr, ", ")
				END
			END;
			IF signature.params.nofObjs > 0 THEN Strings.Append(newStr, ")") END
		END;
	END;
END GetInsertString;

PROCEDURE FindSuggestions(scope : TS.Scope; first: BOOLEAN; prefix : ARRAY OF CHAR;	suggestions : TS.ObjectList);
VAR ol : TS.ObjectList;
	i: LONGINT;
BEGIN
	IF scope = NIL THEN RETURN END;
	NEW(ol);
	scope.FindCandidates(prefix, first, TRUE, ol);
	i := 0; WHILE i < ol.nofObjs DO
		IF Strings.StartsWith2(prefix, ol.objs[i].name^) THEN
			suggestions.Add(ol.objs[i]);
		END;
		INC(i)
	END;
END FindSuggestions;

(** returns the type of the procedure *)
PROCEDURE GetProcedureType(proc : TS.ProcDecl) : LONGINT;
VAR type : LONGINT;
BEGIN
	type := ProcOther;
	IF (proc.signature = NIL) OR (proc.signature.params = NIL) & (proc.signature.return = NIL) THEN
		type := ProcCommand;
	END;
	RETURN type;
END GetProcedureType;

PROCEDURE GenModuleTree*() : PETTrees.Tree;
VAR tree : ModuleTree;
BEGIN
	NEW(tree); RETURN tree;
END GenModuleTree;


BEGIN
	PMTonBrowseExternal := Strings.NewString("Browse into another file");
	PMTonBrowseExternal := Strings.NewString("fired to browse to a definition in another file");
	treeFontOberon10Plain := WMGraphics.GetFont("Oberon", 10, {});
	treeFontOberon10Bold := WMGraphics.GetFont("Oberon", 10, {WMGraphics.FontBold});
	treeFontOberon10Italic := WMGraphics.GetFont("Oberon", 10, {WMGraphics.FontItalic});

	NEW(PrototypeShowTypeHierarchy, NIL, Strings.NewString("ShowTypeHierarchy"), Strings.NewString("Show type hierarchy?"));
	PrototypeShowTypeHierarchy.Set(FALSE);
	NEW(PrototypeShowImportedModules, NIL, Strings.NewString("ShowImportedModules"), Strings.NewString("Show imported modules details?"));
	PrototypeShowImportedModules.Set(FALSE);
END TFModuleTrees.

Tar.Create ModuleTreesIcons.tar
	activity.png
	arrow-red.png
	arrow-yellow.png
	arrow-green.png
	arrow-blue.png
~
