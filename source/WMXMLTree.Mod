MODULE WMXMLTree; (** AUTHOR "TF"; PURPOSE "Simple XML Viewer"; *)

IMPORT
	Streams, XML, XMLObjects, WMGraphics,
	WMComponents, WMStandardComponents, WMTextView, WMEditors, WMEvents, Strings, TextUtilities, Texts,
	WMTrees, XMLScanner, XMLParser, UTF8Strings;

TYPE

	Error* = RECORD
		pos- : LONGINT;
		line-, row- : LONGINT;
		msg- : ARRAY 128 OF CHAR;
	END;

	ErrorList* = POINTER TO ARRAY OF Error;

TYPE

	XMLView* = OBJECT(WMComponents.VisualComponent)
	VAR
		tree : WMTrees.Tree;
		treeView : WMTrees.TreeView;
		toolbar : WMStandardComponents.Panel;
		errorMsg : WMEditors.Editor;
		refresh- : WMStandardComponents.Button;
		onRefresh- : WMEvents.EventSource;
		label- : WMStandardComponents.Label;
		hasErrors :BOOLEAN;
		highlight : WMTextView.Highlight;

		(** Show error messages in XMLView? Default: FALSE *)
		showErrorMessage* : BOOLEAN;

		errorList : ErrorList;

		text : Texts.Text;

		editor : WMEditors.Editor;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrXMLView);

			NEW(onRefresh, SELF, NIL, NIL, NIL);

			NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			AddContent(toolbar);

			NEW(label); label.alignment.Set(WMComponents.AlignTop);
			label.fillColor.Set(0CCCCCCFFH);
			label.caption.SetAOC("XML Structure (alpha)");
			label.bounds.SetHeight(20);
			SELF.AddContent(label);

			NEW(refresh); refresh.caption.SetAOC("Refresh"); refresh.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(refresh);
			refresh.onClick.Add(Refresh);

			NEW(errorMsg);
			errorMsg.bounds.SetHeight(150); errorMsg.alignment.Set(WMComponents.AlignTop);
			errorMsg.visible.Set(FALSE);
			AddContent(errorMsg);

			NEW(treeView); treeView.alignment.Set(WMComponents.AlignClient);
			treeView.onClickNode.Add(Click);
			AddContent(treeView);
			tree := treeView.GetTree();
		END Init;

		PROCEDURE SetEditor*(e: WMEditors.Editor);
		BEGIN
			IF e = editor THEN RETURN END;
			IF (highlight # NIL) & (editor # NIL) THEN
				editor.tv.RemoveHighlight(highlight);
				highlight := NIL
			END;
			text := e.text;
			editor := e;
			highlight := editor.tv.CreateHighlight();
			highlight.SetColor(LONGINT(0DDDD0060H));
			highlight.SetKind(WMTextView.HLOver)
		END SetEditor;

		PROCEDURE Click(sender, data : ANY);
		VAR p : ANY; a, b : LONGINT;
		BEGIN
			IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
				tree.Acquire;
				p := tree.GetNodeData(data(WMTrees.TreeNode));
				tree.Release;
				IF (p # NIL) & (p IS XML.Element) THEN
					IF editor # NIL THEN
						text.AcquireRead;
						editor.tv.cursor.SetPosition(p(XML.Element).GetPos());
						editor.tv.cursor.SetVisible(TRUE);
						editor.tv.FindCommand(p(XML.Element).GetPos()-1, a, b);
						IF highlight # NIL THEN highlight.SetFromTo(a, b) END;
						text.ReleaseRead;
					END
				END
			END;
		END Click;

		PROCEDURE AddSubNode(node : WMTrees.TreeNode; xml : XML.Element );
		VAR en : XMLObjects.Enumerator;
			p : ANY; s,t,c : Strings.String;
			newNode : WMTrees.TreeNode;
		BEGIN
			NEW(newNode);
			tree.AddChildNode(node, newNode);
			tree.SetNodeData(newNode, xml);

			s := xml.GetName();
			t := xml.GetAttributeValue("name");
			IF (t#NIL) THEN
				NEW(c,Strings.Length(s^) + Strings.Length(t^) + 1 + 4);
				c[0] := 0X;
				IF (s # NIL) THEN
					Strings.Append(c^,s^);
					Strings.Append(c^,': ');
				END;
				Strings.Append(c^,'"');
				Strings.Append(c^,t^);
				Strings.Append(c^,'"');
			ELSE
				c := s;
			END;

			IF c # NIL THEN tree.SetNodeCaption(newNode, c) END;

			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					AddSubNode(newNode, p(XML.Element));
				END
			END;
		END AddSubNode;

		PROCEDURE SetDocument(xml : XML.Element);
		VAR en : XMLObjects.Enumerator;
			p : ANY;
			node : WMTrees.TreeNode;
		BEGIN
			NEW(node);
			tree.Acquire;
			tree.SetRoot(node);
			tree.SetNodeState(node, {WMTrees.NodeAlwaysExpanded});
			tree.SetNodeData(node, xml);

			IF xml # NIL THEN
				en := xml.GetContents();

				WHILE en.HasMoreElements() DO
					p := en.GetNext();
					IF p IS XML.Element THEN
						AddSubNode(node, p(XML.Element));
					END
				END
			END;
			tree.Release
		END SetDocument;

		(* Return a copy of the errorList or NIL in case of no errors *)
		PROCEDURE GetErrorList*() : ErrorList;
		VAR result : ErrorList; i : LONGINT;
		BEGIN
			IF errorList # NIL THEN
				NEW(result, LEN(errorList));
				FOR i := 0 TO LEN(errorList)-1 DO
					result[i] := errorList[i];
				END;
			END;
			RETURN result;
		END GetErrorList;

		PROCEDURE AddErrorToList(pos, line, row : LONGINT; CONST msg : ARRAY OF CHAR);
		VAR temp : ErrorList; i : LONGINT;
		BEGIN
			IF errorList = NIL THEN
				i := 0;
				NEW(errorList, 1);
			ELSE
				NEW(temp, LEN(errorList)+1);
				FOR i := 0 TO LEN(errorList)-1 DO
					temp[i] := errorList[i];
				END;
				errorList := temp;
			END;
			errorList[i].pos := pos;
			errorList[i].line := line;
			errorList[i].row := row;
			COPY(msg, errorList[i].msg);
		END AddErrorToList;

		PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		VAR tw : TextUtilities.TextWriter;
		BEGIN
			AddErrorToList(pos, line, row, msg);
			NEW(tw, errorMsg.text);
			tw.SetFontStyle({WMGraphics.FontBold});
			tw.String(msg); tw.Ln;
			tw.SetFontStyle({});
			tw.String("at pos "); tw.Int(pos, 0); tw.String(" (in line "); tw.Int(line, 0); tw.String(" row "); tw.Int(row, 0); tw.String(")"); tw.Ln;
			tw.Ln;
			hasErrors := TRUE;
			tw.Update
		END Error;

		PROCEDURE Refresh*(sender, data : ANY);
		VAR r : Streams.StringReader;
			scanner : XMLScanner.Scanner;
			parser : XMLParser.Parser;
			doc : XML.Document;
			tr : Texts.TextReader; ch : Texts.Char32; i, p : LONGINT; resstr : ARRAY 7 OF CHAR;
			out : Streams.Writer;
			ob : Strings.Buffer;
			s : Strings.String;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Refresh, sender, data)
			ELSE
				errorMsg.text.AcquireWrite;
				errorMsg.text.Delete(0, errorMsg.text.GetLength());
				errorMsg.text.ReleaseWrite;
				errorList := NIL;
				hasErrors := FALSE;

				IF text = NIL THEN RETURN END;
				text.AcquireRead;
				NEW(ob, (text.GetLength() * 3 DIV 2)); (* heuristic to avoid growing in most cases *)
				out := ob.GetWriter();

				NEW(tr, text);
				FOR i := 0 TO text.GetLength() - 1 DO
					tr.ReadCh(ch); p := 0;
					IF (ch > 0) & UTF8Strings.EncodeChar(ch, resstr, p) THEN out.String(resstr) END
				END;
				out.Update;
				text.ReleaseRead;

				NEW(r, ob.GetLength() + 1);
				s := ob.GetString();
				r.SetRaw(s^, 0, ob.GetLength());

				hasErrors := FALSE;
				NEW(scanner, r); scanner.reportError := Error;
				NEW(parser, scanner); parser.reportError := Error;
				doc := parser.Parse();
				errorMsg.visible.Set(showErrorMessage & hasErrors);
				IF hasErrors THEN errorMsg.tv.firstLine.Set(0);
					label.caption.SetAOC("XML Structure (ERRORS)");
					label.fillColor.Set(0FF0000FFH);
				ELSE
					label.caption.SetAOC("XML Structure");
					label.fillColor.Set(0CCCCCCFFH);
				END;
				IF doc # NIL THEN
					SetDocument(doc.GetRoot())
				END;
				onRefresh.Call(SELF);
			END
		END Refresh;

	END XMLView;

VAR
	StrXMLView : Strings.String;

BEGIN
	StrXMLView := Strings.NewString("XMLView");
END WMXMLTree.