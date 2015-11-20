(**
	Documentation tree to represent a module documentation. Independent of source language. \
	Implemented according to Compiler Suite - Generic Documentation Generation by Florian Negele.

	The documentation tree represents the [[docuEBNF|EBNF]] as implemented by [[FoxDocumentationParser]]
	#author# Felix Friedrich
*)
MODULE FoxDocumentationTree;
(**
	@concept
	= FoxDocumentationTree

	All information that has been parsed by the documentation parser is stored in a documentation tree. The documentation tree is implemented in module \
	[[FoxDocumentationTree]].
	The root of such a documentation is a [[FoxDocumenationTree.Document|Document]], it conists of a description and a number of sections. Each [[Section|section]] consist of a title, cotents and \
	can have a label. Sections that actually have a label are merged by the DocumentationBackend. A rough picture is also provided by the [[docuEBNF|EBNF]].

	==docuEBNF EBNF of the documentation in a paragraph

	@@docuEBNF <<docuEBNF>> EBNF of the documentation
		The following EBNF of the documentation cannot be taken literally because some additional rules are implemented in scanner and parser. However it provides a picture \
		of the documentation rules and how they are parsed.
**)


IMPORT Basic := FoxBasic, Scanner := FoxDocumentationScanner, Strings;

TYPE
	String*= Scanner.String;

	ElementType* = ENUM
		Whitespace*, Default*, Italic*, Bold*, Underline*, Link*, WeakLink*, Label*, Code*, LineBreak*, DataCell*, HeaderCell*, Row*
	END;

	(**
		@docuEBNF
		{{{TextElement = String |BeginItalic Text EndItalic | BeginBold Text EndBold | "[[" string | Text "]]" | "<<" String ">>" | "{{{" any text "}}}" | "\\" | "|" Text | "|=" Text | }}}
	**)
	TextElement*= OBJECT
	VAR
		type-: ElementType;
		string-: String;
		text-: Text;

		PROCEDURE &InitTextElement*(type: ElementType);
		BEGIN
			NEW(text,4);
			SELF.type := type;
			string := NIL;
		END InitTextElement;

		PROCEDURE SetString*(string: String);
		BEGIN SELF.string := string
		END SetString;

		PROCEDURE SetType*(t: ElementType);
		BEGIN
			type := t
		END SetType;

	END TextElement;


	(**
		Comment of Text
		@docuEBNF EBNF
		{{{ ElementList = {Element} }}}
	*)
	Text*=OBJECT (Basic.List)

		PROCEDURE AppendNew*(type: ElementType): TextElement;
		VAR textElement: TextElement;
		BEGIN
			NEW(textElement,type); AddElement(textElement); RETURN textElement
		END AppendNew;

		PROCEDURE AddElement*(x: TextElement);
		BEGIN  Add(x)
		END AddElement;

		PROCEDURE GetElement*(index: LONGINT): TextElement;
		VAR x: ANY;
		BEGIN x := Get(index); IF x = NIL THEN RETURN NIL ELSE RETURN x(TextElement) END;
		END GetElement;

		PROCEDURE FindByString*(CONST string: ARRAY OF CHAR): TextElement;
		VAR i: LONGINT; element: TextElement;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				element := GetElement(i);
				IF (element.string#NIL) & (element.string^ = string)  THEN RETURN element END;
			END;
			RETURN NIL
		END FindByString;

		PROCEDURE WriteString*(CONST s: ARRAY OF CHAR);
		VAR e: TextElement;
		BEGIN
			e := AppendNew(ElementType.Default);
			e.string := Strings.NewString(s);
		END WriteString;

		PROCEDURE WriteWhitespace*();
		VAR e: TextElement;
		BEGIN
			e := AppendNew(ElementType.Whitespace);
		END WriteWhitespace;


		PROCEDURE WriteLink*(CONST name, label: ARRAY OF CHAR);
		VAR e: TextElement;
		BEGIN
			e := AppendNew(ElementType.Link);
			e.string := Strings.NewString(name);
			e.text.WriteString(label);
		END WriteLink;

		PROCEDURE WriteWeakLink*(CONST name, label: ARRAY OF CHAR);
		VAR e: TextElement;
		BEGIN
			e := AppendNew(ElementType.WeakLink);
			e.string := Strings.NewString(name);
			e.text.WriteString(label);
		END WriteWeakLink;

		PROCEDURE WriteText*(t: Text);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO t.Length()-1 DO
				AddElement(t.GetElement(i));
			END;
		END WriteText;

		PROCEDURE WriteLabel*(CONST name: ARRAY OF CHAR);
		VAR e: TextElement;
		BEGIN
			e := AppendNew(ElementType.Label);
			e.string := Strings.NewString(name);
		END WriteLabel;

		PROCEDURE Last*(): TextElement;
		BEGIN RETURN GetElement(Length()-1)
		END Last;

		PROCEDURE ForAllElementsDo*(this: PROCEDURE {DELEGATE} (x: TextElement));
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				this(GetElement(i))
			END;
		END ForAllElementsDo;

	END Text;

	Word*=ARRAY 32 OF CHAR;

	ParagraphType* = ENUM
		TextBlock*, Heading*, Bullet*, Number*, Description*, Code*, Line*, Table*
	END;

	(**
		@@docuEBNF EBNF
		{{{ paragraph = Text |  Heading Text | InsertLabel | Bullet Text | Number Text | Description Text | CodeBegin Text CodeEnd | Line | Table Text. }}}
	*)
	Paragraph*=OBJECT
	VAR
		type-: ParagraphType;
		level-: LONGINT;
		text*: Text;
		description-: Text;
		label*: Strings.String;

		PROCEDURE SetLabel*(label: String);
		BEGIN SELF.label := label
		END SetLabel;

		PROCEDURE & InitParagraph*(type: ParagraphType);
		BEGIN SELF.type := type; SELF.level := level; NEW(text,4); NEW(description, 4);
		END InitParagraph;

		PROCEDURE SetLevel*(level: LONGINT);
		BEGIN SELF.level := level
		END SetLevel;


	END Paragraph;


	(**
		@docuEBNF
		 {{{ Paragraphs = {Paragraph}. }}}
	*)
	Paragraphs*=OBJECT (Basic.List)

		PROCEDURE AppendNew*(type: ParagraphType): Paragraph;
		VAR paragraph: Paragraph;
		BEGIN
			NEW(paragraph,type); AddParagraph(paragraph); RETURN paragraph
		END AppendNew;

		PROCEDURE AddParagraph*(x: Paragraph);
		BEGIN  Add(x)
		END AddParagraph;

		PROCEDURE GetParagraph*(index: LONGINT): Paragraph;
		VAR x: ANY;
		BEGIN x := Get(index); IF x = NIL THEN RETURN NIL ELSE RETURN x(Paragraph) END;
		END GetParagraph;

		PROCEDURE Last*(): Paragraph;
		BEGIN RETURN GetParagraph(Length()-1)
		END Last;

		PROCEDURE ForAllParagraphsDo*(this: PROCEDURE {DELEGATE} (x: Paragraph));
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				this(GetParagraph(i))
			END;
		END ForAllParagraphsDo;

	END Paragraphs;

	(**
		@docuEBNF
		{{{ Section = "@"{"@"} Title Contents. }}}
		{{{ Contents = {Paragraph}. }}}
	*)
	Section*=OBJECT
	VAR
		level-: LONGINT;
		title-: Text;
		contents-: Paragraphs;
		label-: String;

		PROCEDURE &InitSection*(level: LONGINT);
		BEGIN NEW(contents,4); SELF.level := level; NEW(title,4); label := NIL;
		END InitSection;

		PROCEDURE SetLabel*(label: String);
		BEGIN SELF.label := label
		END SetLabel;

		PROCEDURE SetContents*(paragraphs: Paragraphs);
		BEGIN contents := paragraphs
		END SetContents;

		PROCEDURE WriteLabel*(CONST l: ARRAY OF CHAR);
		BEGIN
			label := Strings.NewString(l);
		END WriteLabel;

		PROCEDURE WriteHeading*(level: LONGINT; CONST string: ARRAY OF CHAR);
		VAR paragraph: Paragraph;
		BEGIN
			paragraph := contents.AppendNew(ParagraphType.Heading);
			paragraph.SetLevel(level);
			paragraph.text.WriteString(string);
		END WriteHeading;

	END Section;

	(**
		@docuEBNF
		{{{ SectionList = {Section} }}}
	*)
	Sections*=OBJECT (Basic.List)

		PROCEDURE AppendNew*(level: LONGINT): Section;
		VAR section: Section;
		BEGIN
			NEW(section, level); AddSection(section); RETURN section;
		END AppendNew;

		PROCEDURE AddSection*(x: Section);
		BEGIN  Add(x)
		END AddSection;

		PROCEDURE GetSection*(index: LONGINT): Section;
		VAR x: ANY;
		BEGIN x := Get(index); IF x = NIL THEN RETURN NIL ELSE RETURN x(Section) END;
		END GetSection;

		PROCEDURE Last*(): Section;
		BEGIN RETURN GetSection(Length()-1)
		END Last;

		PROCEDURE ForAllSectionsDo*(this: PROCEDURE {DELEGATE} (x: Section));
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				this(GetSection(i))
			END;
		END ForAllSectionsDo;

	END Sections;


	(** a document provides the documentation of a module in a structured way *)
	(**
		@docuEBNF
		{{{ Document = Description {Section}. }}}
		{{{ Description = {Paragraph}. }}}
	*)
	Document*=OBJECT
	VAR
		description-: Paragraphs;
		sections-: Sections;

		PROCEDURE &InitDocument*;
		BEGIN NEW(sections,4); NEW(description,4);
		END InitDocument;

	END Document;

	(**
		@docuEBNF
		{{{Documents = {Document}. }}}
	*)
	Documents*=OBJECT (Basic.List)
		PROCEDURE AddDocument*(x: Document);
		BEGIN  Add(x)
		END AddDocument;

		PROCEDURE GetDocument*(index: LONGINT): Document;
		VAR x: ANY;
		BEGIN x := Get(index); IF x = NIL THEN RETURN NIL ELSE RETURN x(Document) END;
		END GetDocument;

		PROCEDURE ForAllDocumentsDo*(this: PROCEDURE {DELEGATE} (x: Document));
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				this(GetDocument(i))
			END;
		END ForAllDocumentsDo;

	END Documents;

	(** a documentation provides the documentation of several modules *)
	(**
		@docuEBNF
		{{{ Documentation =  {Document}. }}}
	*)
	Documentation*=OBJECT
	VAR
		documents-: Documents

		PROCEDURE &InitDocumentation*;
		BEGIN NEW(documents,4)
		END InitDocumentation;


	END Documentation;

	PROCEDURE NewText*(): Text;
	VAR text: Text;
	BEGIN NEW(text,4); RETURN text
	END NewText;

	PROCEDURE NewTextElement*(type: ElementType): TextElement;
	VAR textElement: TextElement;
	BEGIN NEW(textElement,type); RETURN textElement
	END NewTextElement;

	PROCEDURE NewParagraph*(type: ParagraphType): Paragraph;
	VAR paragraph: Paragraph;
	BEGIN NEW(paragraph,type); RETURN paragraph
	END NewParagraph;

	PROCEDURE NewParagraphs*(): Paragraphs;
	VAR paragraphs: Paragraphs;
	BEGIN NEW(paragraphs,4); RETURN paragraphs
	END NewParagraphs;

	PROCEDURE NewSection*(level: LONGINT): Section;
	VAR section: Section;
	BEGIN NEW(section,level); RETURN section
	END NewSection;

	PROCEDURE NewSections*(level: LONGINT): Sections;
	VAR sections: Sections;
	BEGIN NEW(sections,4); RETURN sections
	END NewSections;

	PROCEDURE NewDocument*(): Document;
	VAR document: Document;
	BEGIN NEW(document); RETURN document
	END NewDocument;

	PROCEDURE Test;
	VAR e: TextElement;
	BEGIN
		e := NewTextElement(ElementType.Default);
	END Test;

END FoxDocumentationTree.
