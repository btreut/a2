(**
	@description
	The documentation parser parses a documentation comment according to the following EBNF (taken from Compiler Suite - Generic DCoocumentation Generation by Florian Negele, slightly modified)
	and stores the result in a data structure defined in module [[FoxDocumentationParser]].

	{{{
	Documentation = {Document}.
	Document      = {NewLine} Description {Section}.

	Description   = {Paragraph}.
	Paragraph     = CodeBlock | TextBlock | Heading | ListItem  | Table | Line.

	Section       = SectionMarker Title Contents.
	SectionMarker = "@" | "@@" | "@@@".

	CodeBlock     = "{{{" any text "}}}".

	Contents      = {Paragraph}.
	Title         = Text.
	TextBlock     = Text.

	Heading       = HeadingMarker Text.
	HeadingMarker = "=" | "==" | "===" .

	ListItem      = ItemMarker Text.
	ItemMarker    = NumberMarker | BulletMarker.
	NumberMarker  = "#" | "##" | "###".
	BulletMarker  = "*" | "**" | "***".

	Table         = Row {Row}.
	Row           = Cell {Cell}.
	Cell          = CellMarker {TextElement}.
	CellMarker    = HeaderMarker | DataMarker.
	HeaderMarker  = "|=".
	DataMarker    = "|".
	Line          = "----".

	Text          = {TextElement}.
	TextElement   = Default | Italic | Bold | Link | URL | Label | Code | LineBreak.
	Default       = word.

	Italic        = ItalicMarker {TextElement} ItalicMarker.
	ItalicMarker  = "/".

	Bold          = BoldMarker {TextElement} BoldMarker.
	BoldMarker    = "*".

	Underline          = UnderlineMarker {TextElement} UnderlineMarker.
	UnderlineMarker    = "_".

	Link          = "[[" Target [ "|"  {TextElement} ] "]]".
	Target        = word.

	URL           = "[[" url "]]" |
	                "[[" url "|" {TextElement} "]]".

	Label         = "<<" Target ">>".

	Code          = "{{{" {TextElement} "}}}".

	LineBreak     = "\\".
	}}}

	@author Felix Friedrich
*)
(** Parser for documentation comments. Independent of the programming language Oberon.
	Inspired and partially cloned from Florian Negele's Compiler Suite.
*)
MODULE FoxDocumentationParser;

IMPORT Scanner := FoxDocumentationScanner, Tree := FoxDocumentationTree, D := Debugging;

CONST Trace = FALSE;

	TYPE
		Token*= Scanner.Token;
		ParagraphType*=Tree.ParagraphType;
		ElementType*=Tree.ElementType;

		Parser*= OBJECT
		VAR
			current: Scanner.Symbol;
			scanner: Scanner.Scanner;
			inList,italic,bold,link,code, underline: BOOLEAN;
			previous: Token;
			whitespace: BOOLEAN;

			PROCEDURE & Init*(scanner: Scanner.Scanner);
			BEGIN
				SELF.scanner := scanner;
				inList := FALSE; italic := FALSE; bold := FALSE; link := FALSE; code := FALSE; underline := FALSE;
				Next;
			END Init;

			PROCEDURE Next;
			BEGIN
				previous := current.token; whitespace := current.hasWhitespace;scanner.GetNextSymbol(current);
			END Next;

			PROCEDURE IsCurrent(token: Token): BOOLEAN;
			BEGIN RETURN current.token = token
			END IsCurrent;

			PROCEDURE SkipSpace(): LONGINT;
			VAR num: LONGINT;
			BEGIN
				num := 0;
				WHILE current.token = Token.NewLine DO Next; INC(num) END;
				RETURN num
			END SkipSpace;

			PROCEDURE Expect(token: Token);
			BEGIN
				IF current.token = token THEN Next
				ELSE D.String("error in parsing"); D.Ln;
				END;
			END Expect;

			PROCEDURE Get(token: Token): BOOLEAN;
			BEGIN
				IF current.token = token THEN
					Next; RETURN TRUE
				ELSE RETURN FALSE
				END;
			END Get;

			PROCEDURE ParseDocument*(document: Tree.Document);
			VAR num: LONGINT;
			BEGIN
				num := SkipSpace();
				IF current.token # Token.Section THEN
					ParseParagraphs(document.description)
				END;
				ParseSections(document.sections);
			END ParseDocument;

			PROCEDURE ParseSections(sections: Tree.Sections);
			VAR section: Tree.Section; num: LONGINT;
			BEGIN
				num := SkipSpace();
				WHILE current.token # Token.EndOfText DO
					num := SkipSpace();
					section := sections.AppendNew(current.level);
					section.SetLabel(current.string);
					Expect(Token.Section);
					IF (section.label = NIL) & (current.token = Token.LabelBegin) THEN
						section.SetLabel(current.string);
						Next;
						Expect(Token.LabelEnd);
					END;
					ParseText(section.title,Token.NewLine);
					ParseParagraphs(section.contents); (* will skip end spaces if succesfull *)
				END;
			END ParseSections;

			PROCEDURE ParseRow(cells: Tree.Text);
			VAR element: Tree.TextElement;
			BEGIN
				WHILE (current.token = Token.Pipe) OR (current.token = Token.Header) DO
					IF Trace THEN TRACE("ParseRow", current.position) END;
					IF current.token = Token.Header THEN element := cells.AppendNew(ElementType.HeaderCell) ELSE element := cells.AppendNew(ElementType.DataCell) END;
					Next; ParseText(element.text, Token.NewLine);
				END;
			END ParseRow;

			PROCEDURE ParseTable(rows: Tree.Text);
			VAR rowElement: Tree.TextElement;
			BEGIN
				WHILE (current.token = Token.Pipe) OR (current.token = Token.Header) DO
					rowElement := rows.AppendNew(ElementType.Row);
					ParseRow(rowElement.text); Next;
				END;
			END ParseTable;

			PROCEDURE TextStart(sentinel: Token): BOOLEAN;
			BEGIN
				RETURN
				(* not end of text or sentinel *)
				~IsCurrent( Token.EndOfText) & ~IsCurrent( sentinel)
				(* not a section start *)
				& ~IsCurrent(Token.Section)
				(* not a paragraph end *)
				& (~IsCurrent(Token.NewLine) OR (previous # Token.NewLine))
				(* not a heading *)
				& ~IsCurrent(Token.Heading)
				(* not a list *)
				& ~IsCurrent(Token.Number) & ~IsCurrent(Token.Bullet) &~IsCurrent(Token.LeftDescription)
				(* not a table *)
				& ~IsCurrent(Token.Pipe) & ~IsCurrent(Token.Header)
			END TextStart;

			(* insert whitespace, if present *)

			PROCEDURE ParseText(text: Tree.Text; sentinel: Token);
			VAR element: Tree.TextElement; pos: LONGINT;
				PROCEDURE Whitespace;
				BEGIN
					IF whitespace THEN text.WriteWhitespace() END
				END Whitespace;
			BEGIN
				(* sentinel for stopping parsing when, for example, italic or boldface ends *)
				WHILE TextStart(sentinel) DO
					IF ~italic & Get(Token.LeftItalic) THEN
						italic := TRUE;
						Whitespace;
						element := text.AppendNew(ElementType.Italic);
						ParseText(element.text, Token.RightItalic);
						italic := FALSE;
					ELSIF ~bold & Get(Token.LeftBold) THEN
						bold := TRUE;
						Whitespace;
						element := text.AppendNew(ElementType.Bold);
						ParseText(element.text, Token.RightBold);
						bold := FALSE
					ELSIF ~underline & Get(Token.LeftUnderline) THEN
						underline := TRUE;
						Whitespace;
						element := text.AppendNew(ElementType.Underline);
						ParseText(element.text, Token.RightUnderline);
						underline := FALSE
					ELSIF ~link & Get(Token.LinkBegin) THEN
						Whitespace;
						element := text.AppendNew(ElementType.Link);
						element.SetString(current.string);
						Expect(Token.String);
						IF Get(Token.Pipe) THEN link := TRUE; ParseText(element.text,Token.LinkEnd); link := FALSE; END;
						Expect(Token.LinkEnd);
					ELSIF Get(Token.LabelBegin) THEN
						Whitespace;
						element := text.AppendNew(ElementType.Label);
						element.SetString(current.string);
						Expect(Token.String);
						Expect(Token.LabelEnd);
					ELSIF Get(Token.CodeBegin) THEN
						Whitespace;
						code := TRUE;
						element := text.AppendNew(ElementType.Code);
						element.SetString(current.string);
						Expect(Token.CodeEnd);
						(*ParseText(element.text, Token.CodeEnd);*)
						code := FALSE
					ELSIF Get(Token.LineBreak) THEN
						element := text.AppendNew(ElementType.LineBreak);
					ELSIF Get(Token.NewLine) THEN
						(*element := text.AppendNew(ElementType.LineBreak);*)
					ELSE
						IF current.hasWhitespace THEN text.WriteWhitespace END;
						element := text.AppendNew(ElementType.Default);
						element. SetString(current.string);
						Next;
					END;
				END;
			END ParseText;

			PROCEDURE ParseParagraphs(paragraphs: Tree.Paragraphs);
			VAR paragraph: Tree.Paragraph; element: Tree.TextElement; nl: LONGINT;
			BEGIN
				nl := SkipSpace();
				WHILE (current.token # Token.EndOfText) & (current.token # Token.Section)  DO
					CASE current.token OF
					Token.Heading:
						inList := FALSE;
						paragraph := paragraphs.AppendNew(ParagraphType.Heading);
						paragraph.SetLevel(current.level);
						paragraph.SetLabel(current.string);
						Next;
						IF (paragraph.label = NIL) & (current.token = Token.LabelBegin) THEN
							paragraph.SetLabel(current.string);
							Next;
							Expect(Token.LabelEnd);
						END;
						ParseText(paragraph.text, Token.NewLine);
					|Token.Number :
						inList := TRUE;
						paragraph := paragraphs.AppendNew(ParagraphType.Number); paragraph.SetLevel(current.level);
						Next; ParseText(paragraph.text, Token.EndOfText);
					|Token.LeftDescription:
						inList := TRUE;
						paragraph := paragraphs.AppendNew(ParagraphType.Description); paragraph.SetLevel(current.level);
						Next; ParseText(paragraph.description, Token.RightDescription); ParseText(paragraph.text, Token.LeftDescription);
					|Token.Description:
						inList := TRUE;
						paragraph := paragraphs.AppendNew(ParagraphType.Description); paragraph.SetLevel(current.level);
						paragraph.description.WriteString(current.string^); Next; ParseText(paragraph.text, Token.Description);
					|Token.Bullet:
						inList := TRUE;
						paragraph := paragraphs.AppendNew(ParagraphType.Bullet); paragraph.SetLevel(current.level);
						Next; ParseText(paragraph.text, Token.EndOfText);
					|Token.CodeBegin :
						inList := FALSE;
						paragraph := paragraphs.AppendNew(ParagraphType.Code);
						Next;
						element := paragraph.text.AppendNew(ElementType.Default); element.SetString(current.string); Expect(Token.CodeEnd);
					|Token.Pipe, Token.Header :
						paragraph := paragraphs.AppendNew(ParagraphType.Table);
						ParseTable(paragraph.text);
						Next;
					|Token.Line :
						inList := FALSE;
						paragraph := paragraphs.AppendNew(ParagraphType.Line);
						Next;
					ELSE
						inList := FALSE;
						paragraph := paragraphs.AppendNew(ParagraphType.TextBlock); ParseText(paragraph.text, Token.EndOfText);
					END;
					inList := FALSE;
					nl := SkipSpace();
					IF nl > 1 THEN inList := FALSE END;
				END;
			END ParseParagraphs;

		END Parser;


END FoxDocumentationParser.
