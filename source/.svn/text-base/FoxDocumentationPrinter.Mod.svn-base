MODULE FoxDocumentationPrinter; (** AUTHOR ""; PURPOSE ""; *)

IMPORT Tree := FoxDocumentationTree, Scanner := FoxDocumentationScanner, Streams;

CONST debug=FALSE;

TYPE
	ParagraphType=Tree.ParagraphType;
	ElementType= Tree.ElementType;
	Printer*= OBJECT
	VAR writer: Streams.Writer;

		PROCEDURE &InitPrinter*(writer: Streams.Writer);
		BEGIN SELF.writer := writer
		END InitPrinter;

		PROCEDURE Section*(section: Tree.Section);
		BEGIN
			IF debug THEN writer.Ln; writer.String("//// Section with level "); writer.Int(section.level,1); writer.String("//// "); END;
			writer.Ln;
			Chars("@", section.level);
			IF section.label # NIL THEN writer.String(section.label^) END;
			Text(section.title); writer.Ln;
			ParagraphList(section.contents);
		END Section;

		PROCEDURE SectionList*(sections: Tree.Sections);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO sections.Length()-1 DO
				Section(sections.GetSection(i));
			END;
		END SectionList;

		PROCEDURE Document*(document: Tree.Document);
		BEGIN
			ParagraphList(document.description);
			SectionList(document.sections);
		END Document;

		PROCEDURE Chars*(c: CHAR; rep: LONGINT);
		BEGIN
			WHILE rep>0 DO writer.Char(c); DEC(rep) END;
		END Chars;

		PROCEDURE Paragraph*(paragraph: Tree.Paragraph);
		BEGIN
			IF debug THEN
				writer.Ln;
				writer.String("//// paragraph of type ");
				CASE paragraph.type OF
				ParagraphType.Heading: writer.String("Heading");
				|ParagraphType.TextBlock: writer.String("TextBlock");
				|ParagraphType.Number: writer.String("Number");
				|ParagraphType.Bullet: writer.String("Bullet")
				|ParagraphType.Code: writer.String("Code")
				|ParagraphType.Table: writer.String("Table");
				|ParagraphType.Line: writer.String("Line");
				|ParagraphType.Description: writer.String("Description")
				END;
				writer.String("//// ");
			END;
			writer.Ln;
			CASE paragraph.type OF
			ParagraphType.Heading: Chars('=', paragraph.level);
				IF paragraph.label # NIL THEN writer.String(paragraph.label^); END;
				Text(paragraph.text);
			|ParagraphType.Description: writer.String("#"); Text(paragraph.description); writer.String("#"); Text(paragraph.text);
			|ParagraphType.TextBlock: Text(paragraph.text);
			|ParagraphType.Number: Chars('#', paragraph.level); Text(paragraph.text);
			|ParagraphType.Bullet: Chars('*', paragraph.level); Text(paragraph.text);
			|ParagraphType.Code: writer.String("{{{"); writer.Ln; Text(paragraph.text); writer.Ln; writer.String("}}}");
			|ParagraphType.Table: Text(paragraph.text);
			|ParagraphType.Line: writer.String("----");
			ELSE HALT(200)
			END;
			writer.Ln;
		END Paragraph;

		PROCEDURE ParagraphList*(paragraphs: Tree.Paragraphs);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO paragraphs.Length()-1 DO
				Paragraph(paragraphs.GetParagraph(i))
			END;
		END ParagraphList;

		PROCEDURE PrintText*(textElement: Tree.TextElement; separator: CHAR);
		BEGIN
			IF textElement.text.Length() = 0 THEN
				IF textElement.string # NIL THEN
					writer.String(textElement.string^);
				END;
			ELSE
				Text(textElement.text);
			END;
		END PrintText;

		PROCEDURE TextElement*(textElement: Tree.TextElement);
		BEGIN
			IF debug THEN
				writer.Ln; writer.String("//// TextElement:");
				CASE textElement.type OF
				ElementType.Default : writer.String("Default")
				|ElementType.Italic :  writer.String("Italic")
				|ElementType.Bold :  writer.String("Bold")
				|ElementType.HeaderCell :  writer.String("HeaderCell")
				|ElementType.DataCell :  writer.String("DataCell")
				|ElementType.Row :  writer.String("Row")
				|ElementType.Link :  writer.String("Link")
				|ElementType.WeakLink :  writer.String("Link")
				|ElementType.Label :  writer.String("Label")
				|ElementType.Code :  writer.String("Code")
				|ElementType.LineBreak :  writer.String("LineBreak")
				ELSE END;
				writer.String("//// ");
			END;
			(*
			IF separator # 0X THEN
				writer.Char(separator)
			END;
			*)
			CASE textElement.type OF
			ElementType.Default : PrintText(textElement,0X);
			|ElementType.Whitespace: writer.String(" ");
			|ElementType.Italic : writer.String("/"); PrintText(textElement,0X); writer.String("/");
			|ElementType.Underline : writer.String("_"); PrintText(textElement,0X); writer.String("_");
			|ElementType.Bold : writer.String("*"); PrintText(textElement,0X); writer.String("*");
			|ElementType.HeaderCell : writer.String("|="); PrintText(textElement,' ');
			|ElementType.DataCell : writer.String("|"); PrintText(textElement,' ');
			|ElementType.Row : PrintText(textElement,0X); writer.Ln;
			|ElementType.Link, ElementType.WeakLink :
				writer.String("[["); writer.String(textElement.string^);
				IF textElement.text.Length()#0 THEN
					writer.String("|");  Text(textElement.text);
				END;
				writer.String("]]");
			|ElementType.Label : writer.String("<<"); writer.String(textElement.string^); writer.String(">>");
			|ElementType.Code : writer.String("{{{"); PrintText(textElement,0X); writer.String("}}}");
			|ElementType.LineBreak : writer.String("\\");
			END;
		END TextElement;

		PROCEDURE Text*(text: Tree.Text);
		VAR element: Tree.TextElement; i: LONGINT;
		BEGIN
			FOR i := 0 TO text.Length()-1 DO
				element := text.GetElement(i);
				TextElement(element);
			END;
		END Text;

	END Printer;

END FoxDocumentationPrinter.
