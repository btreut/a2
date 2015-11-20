MODULE PETXMLTree; (** AUTHOR "TF/staubesv"; PURPOSE "XML Structure Viewer for PET"; *)

IMPORT
	Modules, Streams, Diagnostics, CompilerInterface, Strings, Texts, PETTrees, WMTrees,
	XML, XMLObjects, XMLScanner, XMLParser, UTF8Strings;

TYPE

	Tree* = OBJECT(PETTrees.Tree)
	VAR
		diagnostics : Diagnostics.Diagnostics;
		log : Streams.Writer;
		hasErrors : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			diagnostics := NIL;
			log := NIL;
			hasErrors := FALSE;
		END Init;

		PROCEDURE AddSubNode(node : PETTrees.TreeNode; xml : XML.Element );
		VAR
			en : XMLObjects.Enumerator; newNode : PETTrees.TreeNode;
			p : ANY; s, t, c : Strings.String;
		BEGIN
			NEW(newNode);
			tree.AddChildNode(node, newNode);
			SetNodeInfo(newNode, xml.GetPos());

			s := xml.GetName();
			t := xml.GetAttributeValue("name");
			IF (t # NIL) THEN
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

			IF (c # NIL) THEN tree.SetNodeCaption(newNode, c) END;

			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					AddSubNode(newNode, p(XML.Element));
				END
			END;
		END AddSubNode;

		PROCEDURE SetDocument(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; string : Strings.String; node : PETTrees.TreeNode;
		BEGIN
			NEW(node);
			tree.Acquire;
			tree.SetRoot(node);
			tree.SetNodeState(node, {WMTrees.NodeAlwaysExpanded});

			IF xml # NIL THEN
				string := xml.GetName();
				IF (string = NIL) THEN
					tree.SetNodeCaption(node, Strings.NewString("Document"));
				ELSE
					tree.SetNodeCaption(node, string);
				END;
				SetNodeInfo(node, xml.GetPos());
				en := xml.GetContents();

				WHILE en.HasMoreElements() DO
					p := en.GetNext();
					IF p IS XML.Element THEN
						AddSubNode(node, p(XML.Element));
					END
				END
			ELSE
				tree.SetNodeCaption(node, Strings.NewString("No Document"));
			END;
			tree.Release
		END SetDocument;

		PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		VAR diagnostics : Diagnostics.Diagnostics; log : Streams.Writer;
		BEGIN
			diagnostics := SELF.diagnostics;
			log := SELF.log;
			hasErrors := TRUE;
		END Error;

		PROCEDURE AddNodes(parent : PETTrees.TreeNode; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		VAR r : Streams.StringReader;
			scanner : XMLScanner.Scanner;
			parser : XMLParser.Parser;
			doc : XML.Document;
			tr : Texts.TextReader; ch : Texts.Char32; i, p : LONGINT; resstr : ARRAY 7 OF CHAR;
			s : Strings.String;
			text : Texts.Text; out : Streams.Writer; ob : Strings.Buffer; hasErrors : BOOLEAN;
		BEGIN
			AddNodes^(parent, diagnostics, log);
			hasErrors := FALSE;
			text := editor.text;
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
			NEW(scanner, r); scanner.reportError := Error;
			NEW(parser, scanner); parser.reportError := Error;
			doc := parser.Parse();
			IF hasErrors THEN SetTitle("XML Structure (ERRORS)");
			ELSE
				SetTitle("XML Structure");
			END;
			IF doc # NIL THEN
				SetDocument(doc.GetRoot())
			END;
		END AddNodes;

		PROCEDURE SetNodeInfo(node : PETTrees.TreeNode; position : LONGINT);
		BEGIN
			IF (position >= 0) THEN
				NEW(node.pos, editor.text);
				node.pos.SetPosition(position);
			ELSE
				node.pos := NIL;
			END;
		END SetNodeInfo;

	END Tree;

TYPE

	ErrorReporter = OBJECT
	VAR
		diagnostics : Diagnostics.Diagnostics;
		hasErrors : BOOLEAN;

		PROCEDURE ReportError(pos, line, row : LONGINT; CONST msg : ARRAY OF CHAR);
		BEGIN
			diagnostics.Error("PET", pos, Diagnostics.Invalid, msg);
			hasErrors := TRUE;
		END ReportError;

		PROCEDURE &Init(diagnostics : Diagnostics.Diagnostics);
		BEGIN
			ASSERT(diagnostics # NIL);
			SELF.diagnostics := diagnostics;
			hasErrors := FALSE;
		END Init;

	END ErrorReporter;

PROCEDURE ParseText(
	text : Texts.Text; CONST source: ARRAY OF CHAR; pos: LONGINT; CONST pc,opt: ARRAY OF CHAR;
	log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	r : Streams.StringReader;
	scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
	doc : XML.Document;
	tr : Texts.TextReader; ch : Texts.Char32; i, p : LONGINT; resstr : ARRAY 7 OF CHAR;
	s : Strings.String;
	out : Streams.Writer; ob : Strings.Buffer;
	errors : ErrorReporter;
BEGIN
	ASSERT((text # NIL) & (diagnostics # NIL));
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
	NEW(errors, diagnostics);
	NEW(scanner, r); scanner.reportError := errors.ReportError;
	NEW(parser, scanner); parser.reportError := errors.ReportError;
	error := errors.hasErrors;
	doc := parser.Parse();
	IF (log # NIL) THEN
		IF error THEN log.String("XML Parser reports errors"); ELSE log.String("XML Parser: OK"); END;
		log.Update;
	END;
END ParseText;

PROCEDURE GenXMLTree*() : PETTrees.Tree;
VAR tree : Tree;
BEGIN
	NEW(tree); RETURN tree;
END GenXMLTree;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister("XML");
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	CompilerInterface.Register("XML", "XML Parser", "XML", ParseText);
END PETXMLTree.