MODULE HTMLTransformer;	(** AUTHOR "Simon L. Keel"; PURPOSE "transforming HTML to BB-text"; *)

IMPORT
	WebBrowserComponents, XMLTransformer,
	Strings, XML, XMLObjects, DynamicStrings, UTF8Strings, WMGraphics, KernelLog, WMEvents, WMCharCodes,
	WMComponents, WMRectangles, WMTextView, TextUtilities, Texts, WMStandardComponents,
	WMMessages, Streams, WMEditors, WMPopups, Messages := WMMessages;

CONST
	verbose = TRUE;
	(* default generic font families *)
		(* Note: All font-names are case-sensitive! *)
	defSerif = "TimesNewRoman";
	defSansSerif = "Arial";
	defCursive = "ComicSansMS";
	defFantasy = "Arial";
	defMonospace = "CourierNew";
	defaultFont = "Oberon"; (* the default browser-font is defSerif; defaultFont is only used, if defSerif doesn't exist! *)

	(* current text is *)
	cText = 0;
	cNewLine = 1;
	cParagraph = 2;

	alignLeft = 0;
	alignCenter = 1;
	alignRight = 2;
	alignJustify = 3;

VAR
	serif : ARRAY 64 OF CHAR;
	sansSerif : ARRAY 64 OF CHAR;
	cursive : ARRAY 64 OF CHAR;
	fantasy : ARRAY 64 OF CHAR;
	monospace : ARRAY 64 OF CHAR;

TYPE
	String = Strings.String;
	VisualComponent = WMComponents.VisualComponent;

	CharsetConvProc = PROCEDURE {DELEGATE} (VAR input : ARRAY OF CHAR) : String;

	TextStyle = RECORD
		font : String;
		size : LONGINT;
		style : LONGINT;
		color : LONGINT;
		bgcolorPresent : BOOLEAN;
		bgcolor : LONGINT;
		link : String;
		linktarget : String;
		shift : LONGINT;
		align : LONGINT;
		indent : LONGINT;
		enumtype : LONGINT;
		preformatted : BOOLEAN;
		form : Form;
	END;

	OLULStackItem=POINTER TO RECORD
		prev : OLULStackItem;
		value : LONGINT;
	END;

	EmbeddedObject*=POINTER TO RECORD
		prev* : EmbeddedObject;
		object* : VisualComponent;
	END;

	Transformer* = OBJECT
	VAR
		doc: XML.Container;
		url : String;
		baseAddress : String;
		baseTarget : String;
		sequencer : WMMessages.MsgSequencer;
		initWidth : LONGINT;
		loadLink* : WMEvents.EventListener;
		charset : String;
		frameName : String;
		txtElem: XML.Element;
		paragraph : XML.Element;
		title-: String;
		pageBgColor- : LONGINT;
		bgImage- : String;
		embeddedObjectsList- : EmbeddedObject;
		textColor : LONGINT;
		linkColor : LONGINT;
		vlinkColor : LONGINT;
		alinkColor : LONGINT;
		crlfStr : String;
		crlfDoubleStr : String;
		charsetConv : CharsetConvProc;
		currentText : LONGINT;
		olulStackTop : OLULStackItem;
		ulDepth : LONGINT;
		inDL : BOOLEAN;
		currentAlign : LONGINT;
		currentIndent : LONGINT;
		form : Form;
		formButton : FormButton;
		formCheckbox : FormCheckbox;
		formTextInput : FormTextInput;
		formRadioButton : FormRadioButton;
		formMenu : FormMenu;
		formHiddenControl : FormHiddenControl;
		initAlignment : LONGINT;
		isTableContent : BOOLEAN;

		PROCEDURE &Init*(doc: XML.Container; url : String; initWidth : LONGINT; loadLink : WMEvents.EventListener; charset : String; frameName : String);
		VAR
			crlf : ARRAY 5 OF CHAR;
		BEGIN
			SELF.doc := doc;
			SELF.url := url;
			SELF.baseAddress := url;
			SELF.initWidth := initWidth;
			SELF.loadLink := loadLink;
			crlf[0] := 0DX; crlf[1] := 0AX; crlf[2] := 0X;
			crlfStr := Strings.NewString(crlf);
			crlf[2] := 0DX; crlf[3] := 0AX; crlf[4] := 0X;
			crlfDoubleStr := Strings.NewString(crlf);
			IF charset # NIL THEN
				charsetConv := GetCharsetConverter(charset^);
				SELF.charset := charset;
			ELSE
				charsetConv := GetCharsetConverter("iso8859-1");
				SELF.charset := Strings.NewString("iso8859-1");
			END;
			SELF.frameName := frameName;
			textColor := 0000000H;
			linkColor := 00000EEH;
			vlinkColor := 0551A8BH;
			alinkColor := 0EE0000H;
			pageBgColor := 0FFFFFFH;
			currentText := cParagraph;
			ulDepth := 0;
			inDL := FALSE;
			initAlignment := alignLeft;
		END Init;

		PROCEDURE Transform*() : XML.Document;
		VAR
			bbtTxt: XML.Document;
			xmlDecl: XML.XMLDecl;
			pi: XML.ProcessingInstruction;
			s: String;
			style : TextStyle;
		BEGIN
			NEW(bbtTxt);
			(* add header *)
			NEW(xmlDecl);
			s := Strings.NewString("1.0");
			xmlDecl.SetVersion(s^);
			s := Strings.NewString("UTF-8");
			xmlDecl.SetEncoding(s^);
			bbtTxt.AddContent(xmlDecl);
			NEW(pi);
			s := Strings.NewString("bluebottle format");
			pi.SetTarget(s^);
			s := Strings.NewString('version="0.1"');
			pi.SetInstruction(s^);
			bbtTxt.AddContent(pi);
			NEW(pi);
			s := Strings.NewString('xml-stylesheet type="text/xsl"');
			pi.SetTarget(s^);
			s := Strings.NewString('href="http://bluebottle.ethz.ch/bluebottle.xsl"');
			pi.SetInstruction(s^);
			bbtTxt.AddContent(pi);

			NEW(txtElem);
			s := Strings.NewString("Text");
			txtElem.SetName(s^);
			bbtTxt.AddContent(txtElem);

			style.font := Strings.NewString(serif);
			style.size := 3;
			style.style := 0;
			style.color := textColor;
			style.bgcolorPresent := FALSE;
			style.shift := 0;
			style.align := initAlignment;
			style.indent := 0;
			style.enumtype := 0;
			style.preformatted := FALSE;
			style.form := form;

			currentAlign := -1;
			currentIndent := -1;
			SetAlignmentAndIndent(style.align, style.indent);

			TransformContent(doc, style);

			RETURN bbtTxt;
		END Transform;

		PROCEDURE TransformContent(container : XML.Container; style : TextStyle);
		VAR
			enum: XMLObjects.Enumerator;
			p : ANY;
		BEGIN
			enum := container.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					TransformElement(p(XML.Element), style);
				ELSIF (p IS XML.ArrayChars) & ~(p IS XML.Comment) THEN
					AddText(p(XML.ArrayChars).GetStr(), style);
				END;
			END;
		END TransformContent;

		PROCEDURE GetText(container : XML.Container) : String;
		VAR
			enum: XMLObjects.Enumerator;
			p : ANY;
			text, s : String;
		BEGIN
			text := Strings.NewString("");
			enum := container.GetContents();
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				IF (p IS XML.ArrayChars) & ~(p IS XML.Comment) THEN
					s := p(XML.ArrayChars).GetStr();
					text := Strings.ConcatToNew(text^, s^);
				END;
			END;
			RETURN text;
		END GetText;

		PROCEDURE TransformElement(elem : XML.Element; style : TextStyle);
		VAR
			name, s, s2, s3 : String;
			enum: XMLObjects.Enumerator;
			p : ANY;
			i, j, res : LONGINT;
			exitLoop : BOOLEAN;
			aoc : ARRAY 16 OF CHAR;
			olulStackItem : OLULStackItem;
			b : BOOLEAN;
			oldForm : Form;

			PROCEDURE ul;
			BEGIN
				IF olulStackTop = NIL THEN
					NewParagraph(FALSE);
				ELSE
					NewLine(FALSE);
				END;
				INC(style.indent);
				INC(ulDepth);
				s := GetElemAttributeValue(elem, "type", TRUE);
				IF s#NIL THEN
					IF s^="square" THEN
						style.enumtype := 1;
					ELSIF s^="circle" THEN
						style.enumtype := 2;
					ELSE (* "disc" *)
						style.enumtype := 0;
					END;
				ELSE
					IF ulDepth = 2 THEN
						style.enumtype := 2; (* circle *)
					ELSIF ulDepth >= 3 THEN
						style.enumtype := 1; (* square *)
					ELSE
						style.enumtype := 0; (* "disc" *)
					END;
				END;
				NEW(olulStackItem);
				olulStackItem.prev := olulStackTop;
				olulStackTop := olulStackItem;
				olulStackItem.value := 1;
				TransformContent(elem, style);
				olulStackTop := olulStackTop.prev;
				DEC(ulDepth);
				IF olulStackTop = NIL THEN
					NewParagraph(FALSE);
				ELSE
					NewLine(FALSE);
				END;
			END ul;

			PROCEDURE textInput(isPassword : BOOLEAN);
			BEGIN
				s := GetElemAttributeValue(elem, "name", FALSE);
				s2 := GetElemAttributeValue(elem, "value", FALSE);
				IF s2 = NIL THEN s2 := Strings.NewString("") END;
				s3 := GetElemAttributeValue(elem, "size", FALSE);
				IF s3 # NIL THEN
					Strings.StrToInt(s3^, i);
				ELSE
					i := 20
				END;
				s3 := GetElemAttributeValue(elem, "maxlength", FALSE);
				IF s3 # NIL THEN
					Strings.StrToInt(s3^, j);
				ELSE
					j := 0
				END;
				NEW(formTextInput, s, s2, i, j, isPassword);
				style.form.AddFormComponent(formTextInput);
				AddVisualComponent(formTextInput.editor, style);
			END textInput;

		BEGIN
			name := elem.GetName();
			CASE name[0] OF
			|"A":
				IF name^="A" THEN
					s := GetElemAttributeValue(elem, "name", FALSE);
					IF s#NIL THEN
						AddLabel(s);
					END;
					s := GetElemAttributeValue(elem, "href", FALSE);
					IF s#NIL THEN
						style.color := linkColor;
						Strings.TrimWS(s^);
						style.link := ResolveAddress(baseAddress, s);
						s := GetElemAttributeValue(elem, "target", FALSE);
						IF s#NIL THEN
							Strings.TrimWS(s^);
							style.linktarget := s;
						ELSIF baseTarget # NIL THEN
							style.linktarget := baseTarget;
						ELSE
							style.linktarget := frameName;
						END;
					END;
					TransformContent(elem, style);
				ELSIF name^="ABBR" THEN
					TransformContent(elem, style);
				ELSIF name^="ACRONYM" THEN
					TransformContent(elem, style);
				ELSIF name^="ADDRESS" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
					NewLine(FALSE);
				ELSIF name^="APPLET" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="AREA" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"B":
				IF name^="B" THEN
					IF style.style = 0 THEN
						style.style := 1;
					ELSIF style.style = 2 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSIF name^="BASE" THEN
					s := GetElemAttributeValue(elem, "href", FALSE);
					IF s#NIL THEN
						baseAddress := s;
					END;
					baseTarget := GetElemAttributeValue(elem, "target", FALSE);
				ELSIF name^="BASEFONT" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="BDO" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="BIG" THEN
					IF style.size < 7 THEN INC(style.size); END;
					TransformContent(elem, style);
				ELSIF name^="BLOCKQUOTE" THEN
					NewParagraph(FALSE);
					INC(style.indent);
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="BODY" THEN
					s := GetElemAttributeValue(elem, "bgcolor", TRUE);
					IF s#NIL THEN pageBgColor := GetColor(s); END;
					s := GetElemAttributeValue(elem, "text", TRUE);
					IF s#NIL THEN
						textColor := GetColor(s);
						style.color := textColor;
					END;
					s := GetElemAttributeValue(elem, "link", TRUE);
					IF s#NIL THEN linkColor := GetColor(s); END;
					s := GetElemAttributeValue(elem, "vlink", TRUE);
					IF s#NIL THEN vlinkColor := GetColor(s); END;
					s := GetElemAttributeValue(elem, "alink", TRUE);
					IF s#NIL THEN alinkColor := GetColor(s); END;
					s := GetElemAttributeValue(elem, "background", FALSE);
					IF s#NIL THEN
						bgImage := ResolveAddress(baseAddress, s);
					END;

					(* TODO: backround image *)
					TransformContent(elem, style);
				ELSIF name^="BR" THEN
					NewLine(TRUE);
				ELSIF name^="BUTTON" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF Strings.StartsWith2("BB:", name^) THEN
					XMLTransformer.AddContentsOf(XMLTransformer.Transform(elem), txtElem);
					currentAlign := -1;
					currentIndent := -1;
					SetAlignmentAndIndent(style.align, style.indent);
				ELSE TransformContent(elem, style);
				END;
			|"C":
				IF name^="CENTER" THEN
					NewLine(TRUE);
					style.align := alignCenter;
					TransformContent(elem, style);
					NewLine(TRUE);
				ELSIF name^="CITE" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSIF name^="CODE" THEN
					style.font := Strings.NewString(monospace);
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"D":
				IF name^="DD" THEN
					INC(style.indent);
					TransformContent(elem, style);
					NewLine(FALSE);
				ELSIF name^="DEL" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="DFN" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSIF name^="DIR" THEN
					ul();
				ELSIF name^="DIV" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewLine(TRUE);
					TransformContent(elem, style);
					NewLine(TRUE);
				ELSIF name^="DL" THEN
					IF inDL THEN
						INC(style.indent);
						NewLine(FALSE);
					ELSE
						NewParagraph(FALSE);
					END;
					b := inDL;
					inDL := TRUE;
					TransformContent(elem, style);
					IF b THEN
						NewLine(FALSE);
					ELSE
						NewParagraph(FALSE);
					END;
					inDL := b;
				ELSIF name^="DT" THEN
					TransformContent(elem, style);
					NewLine(FALSE);
				ELSE TransformContent(elem, style);
				END;
			|"E":
				IF name^="EM" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"F":
				IF name^="FIELDSET" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="FONT" THEN
					s := GetElemAttributeValue(elem, "size", FALSE);
					IF s#NIL THEN
						Strings.Copy(s^, 0, LEN(s^)-1, aoc);
						Strings.TrimLeft(aoc, ' ');
						Strings.StrToInt(aoc, res);
						IF (aoc[0]='+') OR (aoc[0]='-') THEN
							style.size := style.size + res;
						ELSE
							style.size := res;
						END;
						IF style.size < 1 THEN
							style.size := 1;
						ELSIF style.size > 7 THEN
							style.size := 7;
						END;
					END;
					s := GetElemAttributeValue(elem, "color", TRUE);
					IF s#NIL THEN style.color := GetColor(s); END;
					s := GetElemAttributeValue(elem, "face", FALSE);
					IF s#NIL THEN style.font := GetExistingFontName(s); END;
					TransformContent(elem, style);
				ELSIF name^="FORM" THEN
					oldForm := style.form;
					s := GetElemAttributeValue(elem, "action", FALSE);
					IF s = NIL THEN
						s := baseAddress;
					ELSE
						s := ResolveAddress(baseAddress, s);
					END;
					NEW(style.form, s, loadLink);
					TransformContent(elem, style);
					style.form := oldForm;
				ELSE TransformContent(elem, style);
				END;
			|"G":
				TransformContent(elem, style);
			|"H":
				IF name^="H1" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 6;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="H2" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 5;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="H3" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 4;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="H4" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 3;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="H5" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 2;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="H6" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					style.size := 1;
					style.style := 1;
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="HEAD" THEN
					TransformContent(elem, style);
				ELSIF name^="HR" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSE
							style.align := alignCenter;
						END;
					ELSE
						style.align := alignCenter;
					END;
					NewLine(FALSE);
					AddHR(style.align);
					NewLine(FALSE);
				ELSIF name^="HTML" THEN
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"I":				
				IF name^="I" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSIF name^="IFRAME" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="IMG" THEN
					i := -1; j := -1;
					s := GetElemAttributeValue(elem, "width", FALSE);
					IF s#NIL THEN
						Strings.Copy(s^, 0, LEN(s^)-1, aoc);
						Strings.StrToInt(aoc, i);
					END;
					s := GetElemAttributeValue(elem, "height", FALSE);
					IF s#NIL THEN
						Strings.Copy(s^, 0, LEN(s^)-1, aoc);
						Strings.StrToInt(aoc, j);
					END;
					s := GetElemAttributeValue(elem, "src", FALSE);
					IF s#NIL THEN
						s := ResolveAddress(baseAddress, s);
						AddImage(s, i, j, style);
					END;
				ELSIF name^="INPUT" THEN
					IF style.form # NIL THEN
						s := GetElemAttributeValue(elem, "type", TRUE);
						IF s#NIL THEN
							IF s^="checkbox" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("on") END;
								s3 := GetElemAttributeValue(elem, "checked", FALSE);
								b := FALSE;
								IF s3 # NIL THEN
									b := TRUE;
									Strings.TrimWS(s^);
									IF s3^ = "no" THEN
										b := FALSE;
									END;
								END;
								NEW(formCheckbox, s, s2, b);
								AddText(Strings.NewString(" "), style); AddText(Strings.NewString(" "), style); AddText(Strings.NewString(" "), style);
								style.form.AddFormComponent(formCheckbox);
								AddVisualComponent(formCheckbox.checkbox, style);
								AddText(Strings.NewString(" "), style);
							ELSIF s^="radio" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								IF s = NIL THEN s := Strings.NewString("radioButton") END;
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("on") END;
								s3 := GetElemAttributeValue(elem, "checked", FALSE);
								b := FALSE;
								IF s3 # NIL THEN
									b := TRUE;
									Strings.TrimWS(s^);
									IF s3^ = "no" THEN
										b := FALSE;
									END;
								END;
								NEW(formRadioButton, s, s2, b);
								style.form.AddRadioButton(formRadioButton);
								AddText(Strings.NewString(" "), style); AddText(Strings.NewString(" "), style); AddText(Strings.NewString(" "), style);
								AddVisualComponent(formRadioButton.radioButton, style);
								AddText(Strings.NewString(" "), style);
							ELSIF s^="submit" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("Submit Query") END;
								NEW(formButton, s, s2, style.form.Send);
								style.form.AddFormComponent(formButton);
								AddVisualComponent(formButton.button, style);
								AddText(Strings.NewString(" "), style);
							ELSIF s^="reset" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("Reset") END;
								NEW(formButton, s, s2, style.form.Reset);
								style.form.AddFormComponent(formButton);
								AddVisualComponent(formButton.button, style);
								AddText(Strings.NewString(" "), style);
							ELSIF s^="file" THEN
							ELSIF s^="hidden" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("") END;
								NEW(formHiddenControl, s, s2);
								style.form.AddFormComponent(formHiddenControl);
							ELSIF s^="image" THEN
							ELSIF s^="button" THEN
								s := GetElemAttributeValue(elem, "name", FALSE);
								s2 := GetElemAttributeValue(elem, "value", FALSE);
								IF s2 = NIL THEN s2 := Strings.NewString("") END;
								NEW(formButton, s, s2, NIL); (* when implementing scripts: replace NIL with a function *)
								style.form.AddFormComponent(formButton);
								AddVisualComponent(formButton.button, style);
								AddText(Strings.NewString(" "), style);
							ELSIF s^="password" THEN
								textInput(TRUE);
							ELSE
								textInput(FALSE);
							END;
						ELSE
							textInput(FALSE);
						END;
					END;
				ELSIF name^="INS" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="ISINDEX" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"J":
				TransformContent(elem, style);
			|"K":
				IF name^="KBD" THEN
					style.font := Strings.NewString(monospace);
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"L":
				IF name^="LABEL" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="LEGEND" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="LI" THEN
					NewLine(FALSE);
					IF olulStackTop#NIL THEN
						s := GetElemAttributeValue(elem, "value", FALSE);
						IF s#NIL THEN
							Strings.StrToInt(s^, olulStackTop.value);
						END;
					END;
					i := style.enumtype;
					s := GetElemAttributeValue(elem, "type", FALSE);
					IF s#NIL THEN
						IF s^="square" THEN
							i := 1;
						ELSIF s^="circle" THEN
							i := 2;
						ELSE (* "disc" *)
							i := 0;
						END;
					END;
					CASE i OF
					| 1 : s := Strings.NewString("&#9633; "); (* square *)
					| 2 : s := Strings.NewString("&#9675; "); (* circle *)
					| 3 : IF olulStackTop#NIL THEN  (* 1, 2, 3... *)
							Strings.IntToStr(olulStackTop.value, aoc);
							j :=Strings.Length(aoc);
							IF (j+2) <= (LEN(aoc)-1) THEN
								aoc[j]:='.'; aoc[j+1]:=' '; aoc[j+2]:=0X;
							END;
						ELSE
							aoc := "0. ";
						END;
						s := Strings.NewString(aoc);
					| 4 : IF olulStackTop#NIL THEN  (* a, b, c... *)
							s := IntToABCString(olulStackTop.value, FALSE);
						ELSE
							s := Strings.NewString("0. ");
						END;
					| 5 : IF olulStackTop#NIL THEN (* A, B, C... *)
							s := IntToABCString(olulStackTop.value, TRUE);
						ELSE
							s := Strings.NewString("0. ");
						END;
					| 6 : IF olulStackTop#NIL THEN (* i, ii, iii... *)
							s := IntToRomanString(olulStackTop.value, FALSE);
						ELSE
							s := Strings.NewString("0. ");
						END;
					| 7 : IF olulStackTop#NIL THEN (* I, II, III... *)
							s := IntToRomanString(olulStackTop.value, TRUE);
						ELSE
							s := Strings.NewString("0. ");
						END;
					ELSE  (* 0 *)
						s := Strings.NewString("&#9679; "); (* disc *)
					END;
					AddText(s, style);
					IF olulStackTop#NIL THEN INC(olulStackTop.value); END;
					TransformContent(elem, style);
					NewLine(FALSE);
				ELSIF name^="LINK" THEN
					(* ignore *)
				ELSE TransformContent(elem, style);
				END;
			|"M":
				IF name^="MAP" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="MENU" THEN
					ul();
				ELSIF name^="META" THEN
					s := GetElemAttributeValue(elem, "content", TRUE);
					IF s#NIL THEN
						i := Strings.Pos("charset", s^);
						IF i # -1 THEN
							i := Strings.IndexOfByte('=', i+7, s^) + 1;
							IF i < Strings.Length(s^) THEN
								s := Strings.Substring2(i, s^);
								charsetConv := GetCharsetConverter(s^);
								charset := s;
							END;
						END;
					END;
				ELSE TransformContent(elem, style);
				END;
			|"N":
			(* Frames are handeled in WebBrowserPanel.HTMLPanel
				ELSIF name^="NOFRAMES" THEN
			*)
				IF name^="NOSCRIPT" THEN
					(* TODO: remove if scripts are implemented *)
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"O":
				IF name^="OBJECT" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="OL" THEN
					IF olulStackTop = NIL THEN
						NewParagraph(FALSE);
					ELSE
						NewLine(FALSE);
					END;
					INC(style.indent);
					s := GetElemAttributeValue(elem, "type", FALSE);
					IF s#NIL THEN
						IF s^="a" THEN
							style.enumtype := 4;
						ELSIF s^="A" THEN
							style.enumtype := 5;
						ELSIF s^="i" THEN
							style.enumtype := 6;
						ELSIF s^="I" THEN
							style.enumtype := 7;
						ELSE (* "1" *)
							style.enumtype := 3;
						END;
					ELSE
						style.enumtype := 3;
					END;
					NEW(olulStackItem);
					olulStackItem.prev := olulStackTop;
					olulStackTop := olulStackItem;
					s := GetElemAttributeValue(elem, "start", FALSE);
					IF s#NIL THEN
						Strings.StrToInt(s^, olulStackItem.value);
					ELSE
						olulStackItem.value := 1;
					END;
					TransformContent(elem, style);
					olulStackTop := olulStackTop.prev;
					IF olulStackTop = NIL THEN
						NewParagraph(FALSE);
					ELSE
						NewLine(FALSE);
					END;
				ELSIF name^="OPTGROUP" THEN
					TransformContent(elem, style);
				ELSIF name^="OPTION" THEN
					IF formMenu # NIL THEN
						s := GetElemAttributeValue(elem, "value", FALSE);
						s2 := GetElemAttributeValue(elem, "label", FALSE);
						IF s2 = NIL THEN
							s2 := GetText(elem);
						END;
						s3 := GetElemAttributeValue(elem, "selected", FALSE);
						formMenu.NewItem(s, s2, s3 # NIL);
					END;
				ELSE TransformContent(elem, style);
				END;
			|"P":
				IF name^="P" THEN
					s := GetElemAttributeValue(elem, "align", TRUE);
					IF s # NIL THEN
						Strings.TrimWS(s^);
						IF s^ = "left" THEN
							style.align := alignLeft;
						ELSIF s^ = "center" THEN
							style.align := alignCenter;
						ELSIF s^ = "right" THEN
							style.align := alignRight;
						ELSIF s^ = "justify" THEN
							style.align := alignJustify;
						END;
					END;
					NewParagraph(FALSE);
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSIF name^="PARAM" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="PRE" THEN
					NewParagraph(FALSE);
					style.preformatted := TRUE;
					style.font := Strings.NewString(monospace);
					TransformContent(elem, style);
					NewParagraph(FALSE);
				ELSE TransformContent(elem, style);
				END;
			|"Q":
				IF name^="Q" THEN
					AddText(Strings.NewString('"'), style);
					TransformContent(elem, style);
					AddText(Strings.NewString('"'), style);
				ELSE TransformContent(elem, style);
				END;
			|"R":
				TransformContent(elem, style);
			|"S":
				IF name^="S" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="SAMP" THEN
					style.font := Strings.NewString(monospace);
					TransformContent(elem, style);
				ELSIF name^="SCRIPT" THEN
					(* ignore *)
				ELSIF name^="SELECT" THEN
					IF style.form # NIL THEN
						s := GetElemAttributeValue(elem, "name", FALSE);
						IF s = NIL THEN s := Strings.NewString("defaultMenu") END;
						NEW(formMenu, s);
						style.form.AddFormComponent(formMenu);
						AddVisualComponent(formMenu.button, style);
						AddText(Strings.NewString(" "), style);
						TransformContent(elem, style);
						formMenu := NIL;
					END;
				ELSIF name^="SMALL" THEN
					IF style.size > 1 THEN DEC(style.size); END;
					TransformContent(elem, style);
				ELSIF name^="SPAN" THEN
					TransformContent(elem, style);
				ELSIF name^="STRIKE" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="STRONG" THEN
					IF style.style = 0 THEN
						style.style := 1;
					ELSIF style.style = 2 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSIF name^="STYLE" THEN
					(* ignore *)
				ELSIF name^="SUB" THEN
					IF style.shift = 0 THEN style.shift := 1; END;
					IF style.size >1 THEN DEC(style.size); END;
					TransformContent(elem, style);
				ELSIF name^="SUP" THEN
					IF style.shift = 0 THEN style.shift := -1; END;
					IF style.size >1 THEN DEC(style.size); END;
					TransformContent(elem, style);
				ELSIF name^="SVG" THEN
					AddSVG(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"T":
				IF name^="TABLE" THEN
					AddTable(elem, style);
				ELSIF name^="TEXTAREA" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="TITLE" THEN
					IF title = NIL THEN
						exitLoop := FALSE;
						enum := elem.GetContents();
						WHILE enum.HasMoreElements() & ~exitLoop DO
							p := enum.GetNext();
							IF p IS XML.ArrayChars THEN
								title := p(XML.ArrayChars).GetStr();
								title := ReplaceWhiteSpaces(title);
								title := charsetConv(title^);
								title := TransformCharEnt(title);
								exitLoop := TRUE;
							END;
						END;
					END;
				ELSIF name^="TT" THEN
					style.font := Strings.NewString(monospace);
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			|"U":
				IF name^="U" THEN
					(* to be implemented *)
					TransformContent(elem, style);
				ELSIF name^="UL" THEN
					ul();
				ELSE TransformContent(elem, style);
				END;
			|"V":
				IF name^="VAR" THEN
					IF style.style = 0 THEN
						style.style := 2;
					ELSIF style.style = 1 THEN
						style.style := 3;
					END;
					TransformContent(elem, style);
				ELSE TransformContent(elem, style);
				END;
			ELSE
				TransformContent(elem, style);
			END;
		END TransformElement;

		PROCEDURE SetAlignmentAndIndent(align : LONGINT; indent : LONGINT);
		VAR
			styleAttrPar : XML.Attribute;
			s : String;
			aoc : ARRAY 5 OF CHAR;
		BEGIN
			IF (align # currentAlign) OR (indent # currentIndent) THEN
				NEW(paragraph);
				paragraph.SetName("Paragraph");
				NEW(styleAttrPar); s := Strings.NewString("style"); styleAttrPar.SetName(s^);
				IF align = alignCenter THEN
					s := Strings.NewString("AdHoc 1 ");
				ELSIF align = alignRight THEN
					s := Strings.NewString("AdHoc 2 ");
				ELSIF align = alignJustify THEN
					s := Strings.NewString("AdHoc 3 ");
				ELSE
					s := Strings.NewString("AdHoc 0 "); (* Left-aligned *)
				END;
				IF indent > 0 THEN
					(* firstline indent *)
					Strings.IntToStr(indent * 40, aoc);
					Strings.TrimWS(aoc);
					s := Strings.ConcatToNew(s^, aoc);
					s := Strings.ConcatToNew(s^, " ");
					(* left indent *)
					Strings.IntToStr(indent * 40 + 20, aoc);
					Strings.TrimWS(aoc);
					s := Strings.ConcatToNew(s^, aoc);
					(* right, top, bottom indent *)
					s := Strings.ConcatToNew(s^, " 0 0 0");
				ELSE
					s := Strings.ConcatToNew(s^, "0 0 0 0 0");
				END;
				styleAttrPar.SetValue(s^);
				paragraph.AddAttribute(styleAttrPar);
				txtElem.AddContent(paragraph);
				currentAlign := align;
				currentIndent := indent;
			END;
		END SetAlignmentAndIndent;

		PROCEDURE NewLine(allowMultiple : BOOLEAN);
		VAR
			span : XML.Element;
			styleAttr : XML.Attribute;
			cdata : XML.CDataSect;
			aoc : ARRAY 39 OF CHAR;
		BEGIN
			IF (currentText = cNewLine) & ~allowMultiple THEN RETURN; END;
			currentText := cNewLine;
			NEW(span);	span.SetName("Span");
			aoc := "style";
			NEW(styleAttr); styleAttr.SetName(aoc);
			aoc := "AdHoc Oberon 12 0 0 00000000 00000000";
			styleAttr.SetValue(aoc);
			NEW(cdata);
			cdata.SetStr(crlfStr^);
			span.AddAttribute(styleAttr);
			span.AddContent(cdata);
			paragraph.AddContent(span);
		END NewLine;

		PROCEDURE NewParagraph(allowMultiple : BOOLEAN);
		VAR
			span : XML.Element;
			styleAttr : XML.Attribute;
			cdata : XML.CDataSect;
			aoc : ARRAY 39 OF CHAR;
		BEGIN
			IF (currentText = cParagraph) & ~allowMultiple THEN RETURN; END;
			NEW(cdata);
			IF (currentText = cNewLine) THEN
				cdata.SetStr(crlfStr^);
			ELSE
				cdata.SetStr(crlfDoubleStr^);
			END;
			currentText := cParagraph;
			NEW(span);	span.SetName("Span");
			aoc := "style";
			NEW(styleAttr); styleAttr.SetName(aoc);
			aoc := "AdHoc Oberon 16 0 0 00000000 00000000";
			styleAttr.SetValue(aoc);
			span.AddAttribute(styleAttr);
			span.AddContent(cdata);
			paragraph.AddContent(span);
		END NewParagraph;

		PROCEDURE AddText(txt : String; style : TextStyle);
		VAR
			fontsize : LONGINT;
			baselineshift : LONGINT;
			span : XML.Element;
			s : String;
			aoc : ARRAY 33 OF CHAR;
			styleAttr : XML.Attribute;
			linkAttr : XML.Attribute;
			cdata : XML.CDataSect;
			dyn : DynamicStrings.DynamicString;
		BEGIN
			SetAlignmentAndIndent(style.align, style.indent);
			IF ~style.preformatted THEN
				IF StringHasNewLine(txt^) & StringIsWhiteSpace(txt^) THEN RETURN; END;
				txt := ReplaceWhiteSpaces(txt);
			END;
			txt := charsetConv(txt^);
			txt := TransformCharEnt(txt);
			fontsize := MapFontSize(style.font, style.size);
			baselineshift := MapBaselineShift(style.size);
			NEW(span); aoc := "Span"; span.SetName(aoc);
			IF style.link # NIL THEN
				NEW(linkAttr); aoc := "link"; linkAttr.SetName(aoc);
				span.AddAttribute(linkAttr);
				s := EncodeLinkData(style.link, style.linktarget, url);
				linkAttr.SetValue(s^);
			END;
			NEW(styleAttr); aoc := "style"; styleAttr.SetName(aoc);
			NEW(dyn);
			(* AdHoc *)
			aoc := "AdHoc "; dyn.Append(aoc);
			(* FontName *)
			dyn.Append(style.font^);
			aoc := " "; dyn.Append(aoc);
			(* Fontsize *)
			Strings.IntToStr(fontsize, aoc); dyn.Append(aoc);
			aoc := " "; dyn.Append(aoc);
			(* Fontstyle: normal, bold, italic, bold+italic *)
			Strings.IntToStr(style.style, aoc); dyn.Append(aoc);
			aoc := " "; dyn.Append(aoc);
			(* Baseline-Shift *)
			IF style.shift = 1 THEN
				Strings.IntToStr(baselineshift, aoc);
			ELSIF style.shift = -1 THEN
				Strings.IntToStr(0-baselineshift, aoc);
			ELSE
				aoc := "0";
			END;
			dyn.Append(aoc);
			aoc := " "; dyn.Append(aoc);
			(* Text-Color *)
			Strings.IntToHexStr(style.color * 0100H + 0FFH, 7, aoc);
			dyn.Append(aoc);
			aoc := " ";
			dyn.Append(aoc);
			(* Background-Color *)
			IF style.bgcolorPresent THEN
				Strings.IntToHexStr(style.bgcolor * 0100H + 0FFH, 7, aoc);
			ELSE
				aoc := "00000000";
			END;
			dyn.Append(aoc);
			s := dyn.ToArrOfChar();
			styleAttr.SetValue(s^);
			span.AddAttribute(styleAttr);

			NEW(cdata);
			cdata.SetStr(txt^);
			span.AddContent(cdata);
			paragraph.AddContent(span);
			currentText := cText;
		END AddText;

		PROCEDURE AddImage(src : String; x : LONGINT; y : LONGINT; style : TextStyle);
		VAR
			object : XML.Element;
			img : WebBrowserComponents.StretchImagePanel;
			imgLink : WebBrowserComponents.StretchImageLinkPanel;
			msg : WMTextView.LinkWrapper;
		BEGIN
			SetAlignmentAndIndent(style.align, style.indent);
			NEW(object);
			object.SetName("Object");
			paragraph.AddContent(object);
			IF style.link # NIL THEN
				NEW(msg);
				msg.link := EncodeLinkData(style.link, style.linktarget, url);
				NEW(imgLink, NIL, src, x, y, loadLink, msg);
				object.AddContent(imgLink);
				ToEmbeddedObjectsList(imgLink);
			ELSE
				NEW(img, NIL, src, x, y);
				object.AddContent(img);
				ToEmbeddedObjectsList(img);
			END;
			currentText := cText;
		END AddImage;

		PROCEDURE AddSVG(svgRoot: XML.Element; style : TextStyle);
		VAR
			object : XML.Element;
			svg : WebBrowserComponents.SVGPanel;
			svgLink : WebBrowserComponents.SVGLinkPanel;
			msg : WMTextView.LinkWrapper;
		BEGIN
			SetAlignmentAndIndent(style.align, style.indent);
			NEW(object);
			object.SetName("Object");
			paragraph.AddContent(object);
			IF style.link # NIL THEN
				NEW(msg);
				msg.link := EncodeLinkData(style.link, style.linktarget, url);
				NEW(svgLink, svgRoot, loadLink, msg);
				object.AddContent(svgLink);
				ToEmbeddedObjectsList(svgLink);
			ELSE
				NEW(svg, svgRoot);
				object.AddContent(svg);
				ToEmbeddedObjectsList(svg);
			END;
			currentText := cText;
		END AddSVG;

		PROCEDURE ToEmbeddedObjectsList(obj : VisualComponent);
		VAR
			item : EmbeddedObject;
		BEGIN
			NEW(item);
			item.object := obj;
			item.prev := embeddedObjectsList;
			embeddedObjectsList := item;
		END ToEmbeddedObjectsList;

		PROCEDURE AddHR(align : LONGINT);
		VAR
			object : XML.Element;
			hr : WebBrowserComponents.HR;
		BEGIN
			SetAlignmentAndIndent(align, currentIndent);
			currentText := cText;
			NEW(object);
			object.SetName("Object");
			paragraph.AddContent(object);
			NEW(hr, initWidth);
			object.AddContent(hr);
			ToEmbeddedObjectsList(hr);
		END AddHR;

		PROCEDURE AddTable(tableElem : XML.Element; style : TextStyle);
		VAR
			object : XML.Element;
			table : Table;
		BEGIN
			NewLine(FALSE);
			NEW(object);
			object.SetName("Object");
			NEW(table, tableElem, initWidth, style.align, textColor, linkColor, vlinkColor, alinkColor, url, loadLink, charset, frameName, style.form, baseAddress, baseTarget, sequencer, isTableContent);
			ToEmbeddedObjectsList(table);
			SetAlignmentAndIndent(style.align, style.indent);
			object.AddContent(table);
			paragraph.AddContent(object);
			SetAlignmentAndIndent(style.align, style.indent);
			NewLine(TRUE);
		END AddTable;

		PROCEDURE AddVisualComponent(vc : WMComponents.VisualComponent; style : TextStyle);
		VAR
			object : XML.Element;
		BEGIN
			SetAlignmentAndIndent(style.align, style.indent);
			NEW(object);
			object.SetName("Object");
			object.AddContent(vc);
			paragraph.AddContent(object);
			currentText := cText;
		END AddVisualComponent;

		PROCEDURE AddLabel(s : String);
		VAR
			label : XML.Element;
			nameAttr : XML.Attribute;
			aoc : ARRAY 5 OF CHAR;
		BEGIN
			NEW(label);
			label.SetName("Label");
			NEW(nameAttr); aoc := "name"; nameAttr.SetName(aoc);
			nameAttr.SetValue(s^);
			label.AddAttribute(nameAttr);
			paragraph.AddContent(label);
		END AddLabel;

	END Transformer;


	CellSizes = POINTER TO ARRAY OF LONGINT;

	StringArray = POINTER TO ARRAY OF String;

	CellWrapper = POINTER TO RECORD
		cell : TableCell;
	END;

	TableGrid = POINTER TO ARRAY OF ARRAY OF CellWrapper;

	Table* = OBJECT (VisualComponent)
	VAR
		tableElem : XML.Element;
		parentWidth : LONGINT;
		align- : LONGINT;
		textColor, linkColor, vlinkColor, alinkColor : LONGINT;
		url : String;
		loadLink : WMEvents.EventListener;
		charset : String;
		frameName : String;
		form : Form;
		baseAddress : String;
		baseTarget : String;
		isSubtable : BOOLEAN;
		width : LONGINT;
		relativeWidth : BOOLEAN;
		border : LONGINT;
		rules : BOOLEAN;
		cellspacing : LONGINT;
		relativeCellspacing : BOOLEAN;
		cellpadding : LONGINT;
		relativeCellpadding : BOOLEAN;
		bgColor : LONGINT;
		grid : TableGrid;
		colsCnt : LONGINT;
		rowsCnt : LONGINT;
		minCellWidths, maxCellWidths : CellSizes;
		minTableWidth, maxTableWidth : LONGINT;
		x, y : LONGINT;
		internalWidth, internalHeight : LONGINT;

		PROCEDURE & New*(tableElem : XML.Element; parentWidth : LONGINT; align : LONGINT; textColor, linkColor, vlinkColor, alinkColor : LONGINT; url : String; loadLink : WMEvents.EventListener; charset : String; frameName : String; form : Form; baseAddress : String; baseTarget : String; seq : WMMessages.MsgSequencer; isSubtable : BOOLEAN);
		VAR
			s : String; sequencer: Messages.MsgSequencer;
		BEGIN
			Init;
			IF seq = NIL THEN
				NEW(sequencer, Handle);
				SetSequencer(sequencer);
			ELSE
				SetSequencer(seq);
			END;
			SELF.tableElem := tableElem;
			SELF.parentWidth := parentWidth - 20;
			IF parentWidth < 1 THEN parentWidth := 1 END;
			SELF.textColor := textColor;
			SELF.linkColor := linkColor;
			SELF.vlinkColor := vlinkColor;
			SELF.alinkColor := alinkColor;
			SELF.url := url;
			SELF.loadLink := loadLink;
			SELF.charset := charset;
			SELF.frameName := frameName;
			SELF.form := form;
			SELF.baseAddress := baseAddress;
			SELF.baseTarget := baseTarget;
			SELF.isSubtable := isSubtable;

			(* Get table alignment *)
			s := GetElemAttributeValue(tableElem, "align", TRUE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				IF s^ = "left" THEN
					SELF.align := alignLeft;
				ELSIF s^ = "center" THEN
					SELF.align := alignCenter;
				ELSIF s^ = "right" THEN
					SELF.align := alignRight;
				ELSIF s^ = "justify" THEN
					SELF.align := alignJustify;
				ELSE
					SELF.align := align;
				END;
			ELSE
				SELF.align := align;
			END;

			(* Get table width *)
			s := GetElemAttributeValue(tableElem, "width", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				IF Strings.EndsWith("%", s^) THEN
					relativeWidth := TRUE;
					s := Strings.Substring(0, Strings.Length(s^)-1, s^);
				END;
				Strings.StrToInt(s^, width);
			ELSE
				width := 0;
			END;

			(* Get border width *)
			s := GetElemAttributeValue(tableElem, "border", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				Strings.StrToInt(s^, border);
			ELSE
				border := 0;
			END;

			(* rules? *)
			s := GetElemAttributeValue(tableElem, "rules", TRUE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				rules := (s^ # "none");
			ELSE
				rules := (border > 0);
			END;

			(* Get cellspacing width *)
			s := GetElemAttributeValue(tableElem, "cellspacing", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				IF Strings.EndsWith("%", s^) THEN
					relativeCellspacing := TRUE;
					s := Strings.Substring(0, Strings.Length(s^)-1, s^);
				END;
				Strings.StrToInt(s^, cellspacing);
			ELSE
				cellspacing := 0;
			END;

			(* Get cellpadding width *)
			s := GetElemAttributeValue(tableElem, "cellpadding", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				IF Strings.EndsWith("%", s^) THEN
					relativeCellpadding := TRUE;
					s := Strings.Substring(0, Strings.Length(s^)-1, s^);
				END;
				Strings.StrToInt(s^, cellpadding);
			ELSE
				cellpadding := 0;
			END;

			(* Get & Set background-color *)
			s := GetElemAttributeValue(tableElem, "bgcolor", TRUE);
			IF s # NIL THEN
				fillColor.Set(GetColor(s) * 0100H + 0FFH);
			END;

			(* makes all tables visible: *)
			(* border := 1; rules := TRUE; *)

			internalWidth := 0; internalHeight := 0;
			BuildCellGrid();
			CalculateMinMaxTableWidth();

			IF ~isSubtable THEN AlignCells(); END;
		END New;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			h, w, color, i : LONGINT;
		BEGIN
			DrawBackground^(canvas);

			(* draw border *)
			IF border > 0 THEN
				h := bounds.GetHeight();
				w := bounds.GetWidth();
				color := LONGINT(0808080FFH);
				FOR i := 0 TO border - 1 DO
					canvas.Line(0, 0+i, w-1, 0+i, color, WMGraphics.ModeSrcOverDst);
					canvas.Line(0+i, 0, 0+i, h-1, color, WMGraphics.ModeSrcOverDst);
					canvas.Line(0, h-1-i, w-1, h-1-i, color, WMGraphics.ModeSrcOverDst);
					canvas.Line(w-1-i, 0, w-1-i, h-1, color, WMGraphics.ModeSrcOverDst);
				END;
			END;
		END DrawBackground;

		PROCEDURE BuildCellGrid;
		VAR
			captionCount : LONGINT;
			wantedList : StringArray;
			stopList : StringArray;
			wantedTDTH : StringArray;
			stopAtTable : StringArray;
			newRow : BOOLEAN;
			enum, enum2 : XMLObjects.Enumerator;
			p, p2 : ANY;
			j : LONGINT;
		BEGIN
			NEW(wantedTDTH, 2); wantedTDTH[0] := Strings.NewString("TD"); wantedTDTH[1] := Strings.NewString("TH");
			NEW(stopAtTable, 1); stopAtTable[0] := Strings.NewString("TABLE");

			(* add table caption, if any *)
			captionCount := 0;
			NEW(wantedList, 1); wantedList[0] := Strings.NewString("CAPTION");
			enum := GetElems(tableElem, wantedList, stopAtTable, FALSE);
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				AddCell(p(XML.Element), TRUE);
				INC(captionCount);
			END;
			(* add table header, if any *)
			NEW(wantedList, 1); wantedList[0] := Strings.NewString("THEAD");
			enum := GetElems(tableElem, wantedList, stopAtTable, FALSE);
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				enum2 := GetElems(p(XML.Element), wantedTDTH, stopAtTable, FALSE);
				newRow := TRUE;
				WHILE (enum2.HasMoreElements()) DO
					p2 := enum2.GetNext();
					AddCell(p2(XML.Element), newRow);
					newRow := FALSE;
				END;
			END;
			(* add rows *)
			NEW(stopList, 5); stopList[0] := Strings.NewString("TABLE"); stopList[1] := Strings.NewString("THEAD"); stopList[2] := Strings.NewString("TFOOT"); stopList[3] := Strings.NewString("TR"); stopList[4] := Strings.NewString("CAPTION");
			newRow := TRUE;
			enum := GetElems(tableElem, wantedTDTH, stopList, FALSE);
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				AddCell(p(XML.Element), newRow);
				newRow := FALSE;
			END;
			NEW(wantedList, 1); wantedList[0] := Strings.NewString("TR");
			NEW(stopList, 4); stopList[0] := Strings.NewString("TABLE"); stopList[1] := Strings.NewString("THEAD"); stopList[2] := Strings.NewString("TFOOT"); stopList[3] := Strings.NewString("CAPTION");
			enum := GetElems(tableElem, wantedList, stopList, FALSE);
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				enum2 := GetElems(p(XML.Element), wantedTDTH, stopAtTable, FALSE);
				newRow := TRUE;
				WHILE (enum2.HasMoreElements()) DO
					p2 := enum2.GetNext();
					AddCell(p2(XML.Element), newRow);
					newRow := FALSE;
				END;
			END;
			(* add table footer, if any *)
			NEW(wantedList, 1); wantedList[0] := Strings.NewString("TFOOT");
			newRow := TRUE;
			enum := GetElems(tableElem, wantedList, stopAtTable, FALSE);
			WHILE (enum.HasMoreElements()) DO
				p := enum.GetNext();
				enum2 := GetElems(p(XML.Element), wantedTDTH, stopAtTable, FALSE);
				WHILE (enum2.HasMoreElements()) DO
					p2 := enum2.GetNext();
					AddCell(p2(XML.Element), newRow);
					newRow := FALSE;
				END;
			END;
			(* set colspan = colsCnt for each caption *)
			FOR j := 0 TO captionCount - 1 DO
				IF (grid[0, j] # NIL) & (grid[0, j].cell # NIL) THEN
					grid[0, j].cell.colspan := colsCnt;
				END;
			END;
		END BuildCellGrid;

		PROCEDURE AddCell(elem : XML.Element; newRow : BOOLEAN);
		VAR
			tableCell : TableCell;
			i, j : LONGINT;

			PROCEDURE Add(x, y : LONGINT; tableCell : TableCell);
			VAR
				cellWrapper : CellWrapper;
			BEGIN
				IF y > (rowsCnt - 1) THEN
					GrowY(y);
				END;
				WHILE (x < colsCnt) & (grid[x, y] # NIL) DO
					INC(x);
				END;
				IF x > (colsCnt - 1) THEN
					GrowX(x);
				END;
				NEW(cellWrapper);
				cellWrapper.cell := tableCell;
				grid[x, y] := cellWrapper;
			END Add;

			PROCEDURE GrowX(newX : LONGINT);
			VAR
				newInternalWidth : LONGINT;
				newGrid : TableGrid;
			BEGIN
				IF newX > (internalWidth - 1) THEN
					newInternalWidth := internalWidth;
					WHILE newInternalWidth < newX + 1 DO
						INC(newInternalWidth, 10);
					END;
					NEW(newGrid, newInternalWidth, internalHeight);
					FOR i := 0 TO colsCnt - 1 DO
						FOR j := 0 TO rowsCnt - 1 DO
							newGrid[i, j] := grid[i, j];
						END;
					END;
					internalWidth := newInternalWidth;
					grid := newGrid;
				END;
				colsCnt := newX + 1;
			END GrowX;

			PROCEDURE GrowY(newY : LONGINT);
			VAR
				newInternalHeight : LONGINT;
				newGrid : TableGrid;
			BEGIN
				IF newY > (internalHeight - 1) THEN
					newInternalHeight := internalHeight;
					WHILE newInternalHeight < newY + 1 DO
						INC(newInternalHeight, 10);
					END;
					NEW(newGrid, internalWidth, newInternalHeight);
					FOR i := 0 TO colsCnt - 1 DO
						FOR j := 0 TO rowsCnt - 1 DO
							newGrid[i, j] := grid[i, j];
						END;
					END;
					internalHeight := newInternalHeight;
					grid := newGrid;
				END;
				rowsCnt := newY + 1;
			END GrowY;

		BEGIN
			IF rowsCnt = 0 THEN y := -1; newRow := TRUE END; (* init, if first cell added to the grid *)
			IF newRow THEN
				x := 0;
				INC(y);
			ELSE
				INC(x);
			END;
			NEW(tableCell, sequencer, SELF, elem, textColor, linkColor, vlinkColor, alinkColor, url, loadLink, charset, frameName, form, baseAddress, baseTarget);
			AddContent(tableCell);
			FOR i := 0 TO tableCell.colspan - 1 DO
				FOR j := 0 TO tableCell.rowspan - 1 DO
					IF (i = 0) & (j = 0) THEN
						Add(x, y, tableCell);
					ELSE
						Add(x + i, y + j, NIL);
					END;
				END;
			END;
		END AddCell;

		PROCEDURE CalculateMinMaxTableWidth;
		VAR
			i, j, k : LONGINT;
		BEGIN
			NEW(minCellWidths, colsCnt);
			NEW(maxCellWidths, colsCnt);

			(* calculate minimal cell-widths *)
			FOR j := 0 TO rowsCnt - 1 DO
				FOR i := 0 TO colsCnt - 1 DO
					IF (grid[i, j] # NIL) & (grid[i, j].cell # NIL) THEN
						k := (grid[i, j].cell.minWidth - (grid[i, j].cell.colspan - 1) * cellspacing) DIV grid[i, j].cell.colspan;
						IF k > minCellWidths[i] THEN
							minCellWidths[i] := k;
						END;
					END;
				END;
			END;
			(* sum-up minimal cell-widths *)
			minTableWidth := 0;
			FOR i := 0 TO colsCnt - 1 DO
				INC(minTableWidth, minCellWidths[i]);
			END;
			INC(minTableWidth, 2 * border + (colsCnt + 1) * cellspacing);

			(* calculate maximal cell-widths *)
			FOR j := 0 TO rowsCnt - 1 DO
				FOR i := 0 TO colsCnt - 1 DO
					IF (grid[i, j] # NIL) & (grid[i, j].cell # NIL) THEN
						k := (grid[i, j].cell.maxWidth - (grid[i, j].cell.colspan - 1) * cellspacing) DIV grid[i, j].cell.colspan;
						IF k > maxCellWidths[i] THEN
							maxCellWidths[i] := k;
						END;
					END;
				END;
			END;
			(* sum-up maximal cell-widths *)
			maxTableWidth := 0;
			FOR i := 0 TO colsCnt - 1 DO
				INC(maxTableWidth, maxCellWidths[i]);
			END;
			INC(maxTableWidth, 2 * border + (colsCnt + 1) * cellspacing);

		END CalculateMinMaxTableWidth;

		PROCEDURE AlignCells;
		VAR
			cell : TableCell;
			w, h, i, j, k : LONGINT;
			W, D, d : LONGINT;
			tableWidth, tableHeight : LONGINT;
			targetWidth : LONGINT;
			cellWidths, cellHeights : CellSizes;
			fac : REAL;
			leftIndent, topIndent : LONGINT;
		BEGIN

			NEW(cellWidths, colsCnt);
			NEW(cellHeights, rowsCnt);

			(* CALCULATE CELL-WIDTHS *)
			(* if no table-width specified... *)
			IF width = 0 THEN
				IF maxTableWidth <= parentWidth THEN
					(* take max-width *)
					tableWidth := maxTableWidth;
					FOR i := 0 TO colsCnt - 1 DO
						cellWidths[i] := maxCellWidths[i];
					END;
				ELSIF minTableWidth >= parentWidth THEN
					(* take min-width *)
					tableWidth := minTableWidth;
					FOR i := 0 TO colsCnt - 1 DO
						cellWidths[i] := minCellWidths[i];
					END;
				ELSE
					(* calculate width *)
					W := parentWidth - minTableWidth;
					D := maxTableWidth - minTableWidth;
					IF D < 1 THEN D := 1 END;
					tableWidth := 0;
					FOR i := 0 TO colsCnt - 1 DO
						d := maxCellWidths[i] - minCellWidths[i];
						cellWidths[i] := minCellWidths[i] + ENTIER(d * W / D);
						INC(tableWidth, cellWidths[i]);
					END;
					INC(tableWidth, 2 * border + (colsCnt + 1) * cellspacing);
				END;
			ELSE
			(* table-width specified... *)
				targetWidth := width;
				IF relativeWidth THEN
					targetWidth := ENTIER(targetWidth * parentWidth / 100);
				END;
				IF minTableWidth >= targetWidth THEN
					(* take min-width *)
					tableWidth := minTableWidth;
					FOR i := 0 TO colsCnt - 1 DO
						cellWidths[i] := minCellWidths[i];
					END;
				ELSIF maxTableWidth <= targetWidth THEN
					(* take max-width and blow up *)
					fac := targetWidth / maxTableWidth;
					tableWidth := 0;
					FOR i := 0 TO colsCnt - 1 DO
						cellWidths[i] := ENTIER(maxCellWidths[i] * fac);
						INC(tableWidth, cellWidths[i]);
					END;
					INC(tableWidth, 2 * border + (colsCnt + 1) * cellspacing);
				ELSE
					(* calculate width *)
					W := parentWidth - minTableWidth;
					D := maxTableWidth - minTableWidth;
					IF D < 1 THEN D := 1 END;
					tableWidth := 0;
					FOR i := 0 TO colsCnt - 1 DO
						d := maxCellWidths[i] - minCellWidths[i];
						cellWidths[i] := minCellWidths[i] + ENTIER(d * W / D);
						INC(tableWidth, cellWidths[i]);
					END;
					INC(tableWidth, 2 * border + (colsCnt + 1) * cellspacing);
				END;
			END;

			(* SET CELL-WIDTHS *)
			topIndent := border + cellspacing;
			FOR j := 0 TO rowsCnt - 1 DO
				leftIndent := border + cellspacing;
				FOR i := 0 TO colsCnt - 1 DO
					IF (grid[i, j] # NIL) & (grid[i, j].cell # NIL) THEN
						cell := grid[i, j].cell;
						IF (cell.colspan = 1) & (cell.rowspan = 1) THEN
							cell.SetWidth(cellWidths[i]);
						ELSE
							w := 0;
							FOR k := 0 TO cell.colspan - 1 DO
								INC(w, cellWidths[i + k]);
							END;
							INC(w, (cell.colspan - 1) * cellspacing);
							cell.SetWidth(w);
						END;
					END;
					INC(leftIndent, cellWidths[i] + cellspacing);
				END;
				INC(topIndent, cellHeights[j] + cellspacing);
			END;

			(* CALCULATE CELL-HEIGHTS *)
			FOR j := 0 TO rowsCnt - 1 DO
				FOR i := 0 TO colsCnt - 1 DO
					IF (grid[i, j] # NIL) & (grid[i, j].cell # NIL) THEN
						cell := grid[i, j].cell;
						w := 0;
						FOR k := 0 TO cell.colspan - 1 DO
							INC(w, cellWidths[i + k]);
						END;
						INC(w, (cell.colspan - 1) * cellspacing);
						h := (cell.tv.GetHeight(w)  + 2 * cellpadding) DIV cell.rowspan;
						IF h < 1 THEN h := 1 END;
						IF h < cell.height THEN h := cell.height END;
						IF h > cellHeights[j] THEN
							cellHeights[j] := h;
						END;
					END;
				END;
			END;
			tableHeight := 0;
			FOR j := 0 TO rowsCnt - 1 DO
				INC(tableHeight, cellHeights[j]);
			END;
			INC(tableHeight, 2 * border + (rowsCnt + 1) * cellspacing);

			(* SET CELL HEIGHTS AND ALIGN CELLS *)
			topIndent := border + cellspacing;
			FOR j := 0 TO rowsCnt - 1 DO
				leftIndent := border + cellspacing;
				FOR i := 0 TO colsCnt - 1 DO
					IF (grid[i, j] # NIL) & (grid[i, j].cell # NIL) THEN
						cell := grid[i, j].cell;
						IF (cell.colspan = 1) & (cell.rowspan = 1) THEN
							cell.bounds.SetHeight(cellHeights[j]);
						ELSE
							h := 0;
							FOR k := 0 TO cell.rowspan - 1 DO
								INC(h, cellHeights[j + k]);
							END;
							INC(h, (cell.rowspan - 1) * cellspacing);
							cell.bounds.SetHeight(h);
						END;
						cell.bounds.SetLeft(leftIndent);
						cell.bounds.SetTop(topIndent);
					END;
					INC(leftIndent, cellWidths[i] + cellspacing);
				END;
				INC(topIndent, cellHeights[j] + cellspacing);
			END;

			(* SET TABLE BOUNDS *)
			bounds.SetWidth(tableWidth);
			bounds.SetHeight(tableHeight);

		END AlignCells;

		PROCEDURE ParentTvWidthChanged*(x : LONGINT);
		BEGIN
			parentWidth := x - 20;
			IF parentWidth < 1 THEN parentWidth := 1 END;
			AlignCells();
		END ParentTvWidthChanged;

	END Table;

	TableCell = OBJECT (VisualComponent)
	VAR
		parentTable : Table;
		transformer : Transformer;
		tv : WMTextView.TextView;
		text : Texts.Text;
		minWidth, maxWidth : LONGINT;
		width, height : LONGINT;
		colspan, rowspan : LONGINT;
		bgImage : WebBrowserComponents.TileImagePanel;
		writer : Streams.Writer;
		textWriter : TextUtilities.TextWriter;

		PROCEDURE & New*(seq : WMMessages.MsgSequencer; parentTable : Table; elem : XML.Element; textColor, linkColor, vlinkColor, alinkColor : LONGINT; url : String; loadLink : WMEvents.EventListener; charset : String; frameName : String; form : Form; baseAddress : String; baseTarget : String);
		VAR
			s : String;
			align : LONGINT;
			xmlDoc : XML.Document;
			bbtDecoder : TextUtilities.BluebottleDecoder;
			rec : WMRectangles.Rectangle;
			bgImageName : String;
			item : EmbeddedObject;
			dummy : LONGINT;
		BEGIN
			Init;
			SetSequencer(seq);

			SELF.parentTable := parentTable;

			takesFocus.Set(FALSE);

			(* Get alignment *)
			s := GetElemAttributeValue(elem, "align", TRUE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				IF s^ = "center" THEN
					align := alignCenter;
				ELSIF s^ = "right" THEN
					align := alignRight;
				ELSIF s^ = "justify" THEN
					align := alignJustify;
				ELSE
					align := alignLeft;
				END;
			ELSE
				align := alignLeft;
			END;

			(* Get & Set background-color *)
			s := GetElemAttributeValue(elem, "bgcolor", TRUE);
			IF s = NIL THEN
				s :=  GetElemAttributeValue(elem.GetParent(), "bgcolor", TRUE);
			END;

			IF s # NIL THEN
				fillColor.Set(GetColor(s) * 0100H + 0FFH);
			END;

			(* Get colspan *)
			s := GetElemAttributeValue(elem, "colspan", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				Strings.StrToInt(s^, colspan);
				IF colspan < 1 THEN colspan := 1 END;
			ELSE
				colspan := 1;
			END;

			(* Get rowspan *)
			s := GetElemAttributeValue(elem, "rowspan", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				Strings.StrToInt(s^, rowspan);
				IF rowspan < 1 THEN rowspan := 1 END;
			ELSE
				rowspan := 1;
			END;

			(* Get width *)
			s := GetElemAttributeValue(elem, "width", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				Strings.StrToInt(s^, width);
			END;
			INC(width, 2 * colspan * parentTable.cellpadding + (colspan - 1) * parentTable.cellspacing);

			(* Get height *)
			s := GetElemAttributeValue(elem, "height", FALSE);
			IF s # NIL THEN
				Strings.TrimWS(s^);
				Strings.StrToInt(s^, height);
			END;
			INC(height, 2 * rowspan * parentTable.cellpadding + (rowspan - 1) * parentTable.cellspacing);

			(* Get cell background image (not standard html 4.01) *)
			s := GetElemAttributeValue(elem, "background", FALSE);
			IF s#NIL THEN
				bgImageName := ResolveAddress(baseAddress, s);
				NEW(bgImage, NIL, bgImageName);
				AddContent(bgImage);
			END;

			NEW(transformer, elem, url, 100, loadLink, charset, frameName); (* the initial width is unimportant, because it will be changed soon... *)
			transformer.textColor := textColor;
			transformer.linkColor := linkColor;
			transformer.vlinkColor := vlinkColor;
			transformer.alinkColor := alinkColor;
			transformer.form := form;
			transformer.initAlignment := align;
			transformer.baseAddress := baseAddress;
			transformer.baseTarget := baseTarget;
			transformer.sequencer := seq;
			transformer.isTableContent := TRUE;
			xmlDoc := transformer.Transform();

			NEW(bbtDecoder);
			bbtDecoder.OpenXML(xmlDoc);
			text := bbtDecoder.GetText();

(*			NEW(text);
			NEW(textWriter, text);
			writer := textWriter.GetWriter();
			xmlDoc.Write(writer, 0);
			writer.Update;*)

			NEW(tv);
			
			 tv.SetText(text); (*!??  redundant calls to tv.SetText, implying internal updates ...*)
			tv.onLinkClicked.Add(loadLink);
			AddContent(tv);
			
			tv.alignment.Set(WMComponents.AlignClient);
			rec.l := parentTable.cellpadding; rec.t := parentTable.cellpadding; rec.r := parentTable.cellpadding; rec.b := parentTable.cellpadding;
			tv.borders.Set(rec);
			tv.showBorder.Set(parentTable.rules);
			tv.firstLine.Set(0);

			(* get minimal cell-width *)
			item := transformer.embeddedObjectsList;
			WHILE item # NIL DO
				IF item.object IS Table THEN
					item.object(Table).bounds.SetWidth(item.object(Table).minTableWidth);
				END;
				item := item.prev;
			END;
			(*tv.SetText(text);*)
			tv.GetMinMaxWidth(minWidth, dummy);
			(*KernelLog.String("TableCell.New: minWidth of this cell: "); KernelLog.Int(minWidth, 0);*)
			INC(minWidth, 2 * colspan * parentTable.cellpadding + (colspan - 1) * parentTable.cellspacing);
			IF width > minWidth THEN minWidth := width END;

			(* get maximal cell-width *)
			item := transformer.embeddedObjectsList;
			WHILE item # NIL DO
				IF item.object IS Table THEN
					item.object(Table).bounds.SetWidth(item.object(Table).maxTableWidth);
				END;
				item := item.prev;
			END;
			tv.SetText(text);
			tv.GetMinMaxWidth(dummy, maxWidth);
			(*KernelLog.String(", maxWidth of this cell: "); KernelLog.Int(maxWidth, 0); KernelLog.Ln;*)
			INC(maxWidth, 2 * colspan * parentTable.cellpadding + (colspan - 1) * parentTable.cellspacing);
			
			(*SetSequencer(seq); *)(*!??PH*)
		END New;

		PROCEDURE SetWidth(width : LONGINT);
		VAR
			item : EmbeddedObject;
		BEGIN
			bounds.SetWidth(width);
			item := transformer.embeddedObjectsList;
			WHILE item # NIL DO
				IF item.object IS Table THEN
					item.object(Table).ParentTvWidthChanged(width);
				END;
				item := item.prev;
			END;
			tv.SetText(text);
		END SetWidth;

	END TableCell;

	Form = OBJECT
	VAR
		action : String;
		loadLink : WMEvents.EventListener;
		firstComp, lastComp : FormComponent;
		firstRadioButtonGroup, lastRadioButtonGroup : RadioButtonGroup;

		PROCEDURE &Init*(action : String; loadLink : WMEvents.EventListener);
		BEGIN
			SELF.action := action;
			SELF.loadLink := loadLink;
		END Init;

		PROCEDURE Send(sender, par : ANY);
		VAR
			url, s, t : String;
			curr : FormComponent;
			isFirst : BOOLEAN;
			msg : WMTextView.LinkWrapper;
		BEGIN
			url := action;
			isFirst := TRUE;
			curr := firstComp;
			WHILE curr # NIL DO
				IF curr.IsSuccessful() THEN
					s := curr.GetValue();
					s := Utf82UrlEncodedUtf8(s^);
					s := Strings.ConcatToNew("=", s^);
					t := Utf82UrlEncodedUtf8(curr.name^);
					s := Strings.ConcatToNew(t^, s^);
					IF isFirst THEN
						s := Strings.ConcatToNew("?", s^);
						isFirst := FALSE;
					ELSE
						s := Strings.ConcatToNew("&", s^);
					END;
					url := Strings.ConcatToNew(url^, s^);
				END;
				curr := curr.nextComp;
			END;
			NEW(msg);
			msg.link := EncodeLinkData(url, NIL, NIL);
			loadLink(SELF, msg);
		END Send;

		PROCEDURE Reset(sender, par : ANY);
		VAR
			curr : FormComponent;
		BEGIN
			curr := firstComp;
			WHILE curr # NIL DO
				curr.Reset();
				curr := curr.nextComp;
			END;
		END Reset;

		PROCEDURE AddFormComponent(comp : FormComponent);
		BEGIN
			IF firstComp = NIL THEN
				firstComp := comp;
				lastComp := comp;
			ELSE
				lastComp.nextComp := comp;
				lastComp := comp;
			END;
		END AddFormComponent;

		PROCEDURE AddRadioButton(radioButton : FormRadioButton);
		VAR
			curr : RadioButtonGroup;
		BEGIN
			curr := firstRadioButtonGroup;
			WHILE(curr # NIL) & ~Strings.Equal(Strings.LowerCaseInNew(curr.name^), Strings.LowerCaseInNew(radioButton.name^)) DO
				curr := curr.next;
			END;
			IF curr = NIL THEN
				NEW(curr, radioButton.name);
				IF firstRadioButtonGroup = NIL THEN
					firstRadioButtonGroup := curr;
					lastRadioButtonGroup := curr;
				ELSE
					lastRadioButtonGroup.next := curr;
					lastRadioButtonGroup := curr;
				END;
				AddFormComponent(curr);
			END;
			curr.Add(radioButton);
			radioButton.group := curr;
		END AddRadioButton;

	END Form;

	FormComponent = OBJECT
	VAR
		nextComp : FormComponent;
		name : String;

		PROCEDURE IsSuccessful() : BOOLEAN;
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		END GetValue;

		PROCEDURE Reset;
		END Reset;

	END FormComponent;

	FormButton = OBJECT (FormComponent)
	VAR
		button : WMStandardComponents.Button;
		value : String;
		proc : WMEvents.EventListener;
		active : BOOLEAN;

		PROCEDURE &Init*(name : String; value : String; proc : WMEvents.EventListener);
		VAR
			x, y : LONGINT;
			font : WMGraphics.Font;
		BEGIN
			SELF.name := name;
			SELF.value := value;
			SELF.proc := proc;
			NEW(button);
			value := TransformCharEnt(value);
			button.caption.SetAOC(value^);
			font := button.GetFont();
			font.GetStringSize(value^, x, y);
			button.bounds.SetExtents(x + 18, y + 8);
			button.onClick.Add(Click);
		END Init;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN active & (name # NIL);
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		BEGIN
			IF name # NIL THEN
				RETURN value;
			ELSE
				RETURN NIL;
			END;
		END GetValue;

		PROCEDURE Click(sender, par : ANY);
		BEGIN
			active := TRUE;
			IF proc # NIL THEN proc(sender, par) END;
			active := FALSE;
		END Click;

	END FormButton;

	FormCheckbox = OBJECT (FormComponent)
	VAR
		checkbox : WMStandardComponents.Checkbox;
		value : String;
		init : BOOLEAN;

		PROCEDURE &Init*(name : String; value : String; checked : BOOLEAN);
		BEGIN
			NEW(checkbox);
			checkbox.bounds.SetExtents(12, 12);
			SELF.name := name;
			SELF.value := value;
			init := checked;
			IF checked THEN
				checkbox.state.Set(1);
			ELSE
				checkbox.state.Set(0);
			END;
		END Init;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN (checkbox.state.Get() = 1) & (name # NIL);
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		BEGIN
			IF name # NIL THEN
				RETURN value;
			ELSE
				RETURN NIL;
			END;
		END GetValue;

		PROCEDURE Reset;
		BEGIN
			IF init THEN
				checkbox.state.Set(1);
			ELSE
				checkbox.state.Set(0);
			END;
		END Reset;

	END FormCheckbox;

	FormTextInput = OBJECT (FormComponent)
	VAR
		editor : WMEditors.Editor;
		init : String;

		PROCEDURE &Init*(name : String; value : String; size : LONGINT; maxlength : LONGINT; isPassword : BOOLEAN);
		BEGIN
			NEW(editor);
			editor.multiLine.Set(FALSE);
			editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editor.fillColor.Set(0FFFFFFFFH);
			editor.tv.showBorder.Set(TRUE);
			editor.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			SELF.name := name;
			init := value;
			IF isPassword THEN editor.tv.isPassword.Set(TRUE) END;
			value := TransformCharEnt(value);
			editor.SetAsString(value^);
			editor.bounds.SetExtents(8 * size, 22);
		END Init;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN name # NIL;
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		VAR
			aoc : ARRAY 1024 OF CHAR;
		BEGIN
			IF name # NIL THEN
				editor.GetAsString(aoc);
				RETURN Strings.NewString(aoc);
			ELSE
				RETURN NIL;
			END;
		END GetValue;

		PROCEDURE Reset;
		BEGIN
			editor.SetAsString(init^);
		END Reset;

	END FormTextInput;

	FormRadioButton = OBJECT
	VAR
		next : FormRadioButton;
		radioButton : WMStandardComponents.Checkbox;
		name : String;
		value : String;
		group : RadioButtonGroup;
		init : BOOLEAN;

		PROCEDURE &Init*(name : String; value : String; checked : BOOLEAN);
		BEGIN
			NEW(radioButton);
			radioButton.bounds.SetExtents(12, 12);
			SELF.name := name;
			SELF.value := value;
			init := checked;
			IF checked THEN
				radioButton.state.Set(1);
			ELSE
				radioButton.state.Set(0);
			END;
			radioButton.onClick.Add(Clicked);
		END Init;

		PROCEDURE Clicked(sender, par : ANY);
		BEGIN
			IF radioButton.state.Get() = 0 THEN
				radioButton.state.Set(1);
			END;
			group.ClearOthers(SELF);
		END Clicked;

	END FormRadioButton;

	RadioButtonGroup = OBJECT (FormComponent)
	VAR
		next : RadioButtonGroup;
		firstB, lastB : FormRadioButton;

		PROCEDURE &Init*(name : String);
		BEGIN
			SELF.name := name;
		END Init;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN TRUE;
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		VAR
			curr : FormRadioButton;
		BEGIN
			curr := firstB;
			LOOP
				IF (curr = NIL) OR (curr.radioButton.state.Get() = 1) THEN EXIT END;
				curr := curr.next;
			END;
			IF curr = NIL THEN curr := firstB END;
			RETURN curr.value;
		END GetValue;

		PROCEDURE Reset;
		VAR
			curr : FormRadioButton;
		BEGIN
			curr := firstB;
			LOOP
				IF (curr = NIL) OR curr.init THEN EXIT END;
				curr := curr.next;
			END;
			IF curr = NIL THEN curr := firstB END;
			curr.radioButton.state.Set(1);
			ClearOthers(curr);
		END Reset;

		PROCEDURE Add(radioButton : FormRadioButton);
		BEGIN
			IF firstB = NIL THEN
				firstB := radioButton;
				lastB := radioButton;
			ELSE
				lastB.next := radioButton;
				lastB := radioButton;
			END;
		END Add;

		PROCEDURE ClearOthers(exclude : FormRadioButton);
		VAR
			curr : FormRadioButton;
		BEGIN
			curr := firstB;
			WHILE curr # NIL DO
				IF curr # exclude THEN
					curr.radioButton.state.Set(0);
				END;
				curr := curr.next;
			END;
		END ClearOthers;

	END RadioButtonGroup;

	FormMenuItem = OBJECT
	VAR
		caption- : ARRAY 128 OF CHAR;
		value : String;

		PROCEDURE &New*(caption: ARRAY OF CHAR; value : String);
		BEGIN
			COPY(caption, SELF.caption);
			SELF.value := value;
		END New;

	END FormMenuItem;

	FormMenu = OBJECT (FormComponent)
	VAR
		button : WMStandardComponents.Button;
		popup: WMPopups.Popup;
		init : FormMenuItem;
		current : FormMenuItem;

		PROCEDURE &Init*(name : String);
		BEGIN
			SELF.name := name;
			NEW(button);
			button.caption.SetAOC("[ select ]");
			button.bounds.SetExtents(120, 22);
			NEW(popup);
			button.SetExtPointerDownHandler(MenuHandler);
		END Init;

		PROCEDURE MenuHandler(x, y: LONGINT; keys: SET; VAR handled: BOOLEAN);
		BEGIN
			handled := TRUE;
			button.ToWMCoordinates(0, button.bounds.GetHeight(), x, y);
			popup.Popup(x, y);
		END MenuHandler;

		PROCEDURE MenuPopupHandler(sender, data: ANY);
		BEGIN
			IF (data # NIL) & (data IS FormMenuItem) THEN
				popup.Close;
				button.caption.SetAOC(data(FormMenuItem).caption);
				current := data(FormMenuItem);
			END
		END MenuPopupHandler;

		PROCEDURE NewItem(value : String; label : String; selected : BOOLEAN);
		VAR
			item : FormMenuItem;
			s : String;
		BEGIN
			label := TransformCharEnt(label);
			IF value = NIL THEN value := label END;
			s := Strings.ConcatToNew("[ ", label^);
			s := Strings.ConcatToNew(s^, " ]");
			NEW(item, s^, value);
			IF selected THEN
				init := item;
				current := item;
				button.caption.SetAOC(s^);
			END;
			popup.AddParButton(s^, MenuPopupHandler, item);
		END NewItem;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN current # NIL;
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		BEGIN
			IF name # NIL THEN
				RETURN current.value;
			ELSE
				RETURN NIL;
			END;
		END GetValue;

		PROCEDURE Reset;
		BEGIN
			IF init = NIL THEN
				current := NIL;
				button.caption.SetAOC("[ select ]");
			ELSE
				current := init;
				button.caption.SetAOC(init.caption);
			END;
		END Reset;

	END FormMenu;

	FormHiddenControl = OBJECT (FormComponent)
	VAR
		value : String;

		PROCEDURE &Init*(name : String; value : String);
		BEGIN
			SELF.name := name;
			SELF.value := value;
		END Init;

		PROCEDURE IsSuccessful() : BOOLEAN;
		BEGIN
			RETURN name # NIL;
		END IsSuccessful;

		PROCEDURE GetValue() : String;
		BEGIN
			IF name # NIL THEN
				RETURN value;
			ELSE
				RETURN NIL;
			END;
		END GetValue;

	END FormHiddenControl;


PROCEDURE EncodeLinkData(link, target, url : String) : String;
VAR
	s : String;
	inlineLink : BOOLEAN;
	urlLen : LONGINT;
BEGIN
	ASSERT(link # NIL);
	inlineLink := FALSE;
	IF (url # NIL) & Strings.StartsWith2(url^, link^) THEN
		urlLen := Strings.Length(url^);
		IF (Strings.Length(link^) > urlLen) & (link^[urlLen] = "#") THEN
			inlineLink := TRUE;
		ELSIF (Strings.Length(link^) > (urlLen+1)) & (link^[urlLen] = "/") & (link^[urlLen+1] = "#") THEN
			inlineLink := TRUE;
		END;
	END;
	IF inlineLink THEN
		RETURN Strings.Substring2(Strings.LastIndexOfByte2("#", link^), link^);
	ELSE
		s := target; IF s = NIL THEN s := Strings.NewString("") END;
		s := Strings.ConcatToNew("target=", s^);
		s := Strings.ConcatToNew(s^, ";url=");
		RETURN Strings.ConcatToNew(s^, link^);
	END;
END EncodeLinkData;

PROCEDURE Utf82UrlEncodedUtf8*(VAR in : ARRAY OF CHAR) : String;
VAR
	i, cnt : LONGINT;
	output : String;
	aoc : ARRAY 3 OF CHAR;
BEGIN
	NEW(output, 3 * Strings.Length(in) + 1);
	cnt := 0;
	FOR i := 0 TO Strings.Length(in)-1 DO
		IF (ORD(in[i])=021H) OR (ORD(in[i])=022H) OR (ORD(in[i])=024H) OR ((ORD(in[i]) >= 027H) & (ORD(in[i]) <= 02EH)) OR
				((ORD(in[i]) >= 030H) & (ORD(in[i]) <= 039H)) OR ((ORD(in[i]) >= 041H) & (ORD(in[i]) <= 05AH)) OR
				(ORD(in[i])=05FH) OR ((ORD(in[i]) >= 061H) & (ORD(in[i]) <= 07AH)) THEN
			output^[cnt] := in[i];
			INC(cnt);
		ELSIF ORD(in[i])=020H THEN
			output^[cnt] := '+';
			INC(cnt);
		ELSE
			Strings.IntToHexStr(ORD(in[i]), 1, aoc);
			output^[cnt] := '%';
			output^[cnt+1] := aoc[0];
			output^[cnt+2] := aoc[1];
			INC(cnt, 3);
		END;
	END;
	output^[cnt] := 0X;
	RETURN output;
END Utf82UrlEncodedUtf8;

PROCEDURE GetElems(root : XML.Element; wanted : StringArray; stopAt : StringArray; checkMe : BOOLEAN) : XMLObjects.Enumerator;
VAR
	col : XMLObjects.ArrayCollection;
	enum, enum2 : XMLObjects.Enumerator;
	p, p2 : ANY;
	name : String;
	i : LONGINT;
BEGIN
	NEW(col);
	name := root.GetName();
	IF checkMe THEN
		FOR i := 0 TO LEN(stopAt) - 1 DO
			IF stopAt[i]^ = name^ THEN RETURN col.GetEnumerator() END;
		END;
		FOR i := 0 TO LEN(wanted) - 1 DO
			IF wanted[i]^ = name^ THEN col.Add(root); END;
		END;
	END;
	enum := root.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			enum2 := GetElems(p(XML.Element), wanted, stopAt, TRUE);
			WHILE enum2.HasMoreElements() DO
				p2 := enum2.GetNext();
				col.Add(p2);
			END;
		END;
	END;
	RETURN col.GetEnumerator();
END GetElems;

PROCEDURE GetCharsetConverter(charset : ARRAY OF CHAR) : CharsetConvProc;
BEGIN
	Strings.TrimWS(charset);
	Strings.LowerCase(charset);
	IF charset = "iso8859-1" THEN
		RETURN Iso2Utf8;
	ELSIF charset = "utf-8" THEN
		RETURN Utf82Utf8;
	ELSIF charset = "gb2312" THEN
		RETURN Gb23122Utf8;
	ELSE
		RETURN Iso2Utf8;
	END;
END GetCharsetConverter;

PROCEDURE Iso2Utf8(VAR input : ARRAY OF CHAR) : String;
VAR
	dyn : DynamicStrings.DynamicString;
	dynPos : LONGINT;
	temp : ARRAY 5 OF CHAR;
	i, j, len : LONGINT;
BEGIN
	NEW(dyn);
	dynPos := 0;
	FOR i := 0 TO Strings.Length(input)-1 DO
		IF ORD(input[i]) >= 128 THEN
			len := 0;
			IF UTF8Strings.EncodeChar(ORD(input[i]), temp, len) THEN
				FOR j := 0 TO len-1 DO
					dyn.Put(temp[j], dynPos);
					INC(dynPos);
				END;
			ELSE
				dyn.Put('*', dynPos);
				INC(dynPos);
			END;
		ELSE
			dyn.Put(input[i], dynPos);
			INC(dynPos);
		END;
	END;
	RETURN dyn.ToArrOfChar();
END Iso2Utf8;

PROCEDURE Utf82Utf8(VAR input : ARRAY OF CHAR) : String;
BEGIN
	RETURN Strings.NewString(input);
END Utf82Utf8;

PROCEDURE Gb23122Utf8(VAR input : ARRAY OF CHAR) : String;
BEGIN
	RETURN WMCharCodes.GB2312ToUTF8(Strings.NewString(input));
END Gb23122Utf8;

PROCEDURE GetColor(s : String) : LONGINT;
VAR
	aoc : ARRAY 17 OF CHAR;
	i, res : LONGINT;
BEGIN
	IF s#NIL THEN
		IF (s^[0]='#') THEN
			Strings.Copy(s^, 1, Strings.Length(s^)-1, aoc);
			Strings.HexStrToInt(aoc, i, res);
			RETURN i;
		ELSIF (s[0] >= "0") & (s[0] <="9") OR (CAP(s[0]) >= "A") & (CAP(s[0])<="F")  THEN
			Strings.Copy(s^, 0, Strings.Length(s^), aoc);
			Strings.HexStrToInt(aoc, i, res);
			RETURN i;
		ELSIF s^="black" THEN RETURN 0000000H;
		ELSIF s^="silver" THEN RETURN 0C0C0C0H;
		ELSIF s^="gray" THEN RETURN 0808080H;
		ELSIF s^="white" THEN RETURN 0FFFFFFH;
		ELSIF s^="maroon" THEN RETURN 0800000H;
		ELSIF s^="red" THEN RETURN 0FF0000H;
		ELSIF s^="purple" THEN RETURN 0800080H;
		ELSIF s^="fuchsia" THEN RETURN 0FF00FFH;
		ELSIF s^="green" THEN RETURN 0008000H;
		ELSIF s^="lime" THEN RETURN 000FF00H;
		ELSIF s^="olive" THEN RETURN 0808000H;
		ELSIF s^="yellow" THEN RETURN 0FFFF00H;
		ELSIF s^="navy" THEN RETURN 0000080H;
		ELSIF s^="blue" THEN RETURN 00000FFH;
		ELSIF s^="teal" THEN RETURN 0008080H;
		ELSIF s^="aqua" THEN RETURN 000FFFFH;
		ELSE RETURN 0;
		END;
	END;
	RETURN 0;
END GetColor;

PROCEDURE StringIsWhiteSpace(VAR txt : ARRAY OF CHAR) : BOOLEAN;
VAR
	i : LONGINT;
BEGIN
	FOR i := 0 TO Strings.Length(txt)-1 DO
		IF ORD(txt[i]) > 32 THEN RETURN FALSE END;
	END;
	RETURN TRUE;
END StringIsWhiteSpace;

PROCEDURE StringHasNewLine(VAR txt : ARRAY OF CHAR) : BOOLEAN;
VAR
	i : LONGINT;
BEGIN
	FOR i := 0 TO Strings.Length(txt)-1 DO
		IF (ORD(txt[i]) = 10) OR (ORD(txt[i]) = 13) THEN RETURN TRUE END;
	END;
	RETURN FALSE;
END StringHasNewLine;

PROCEDURE ReplaceWhiteSpaces(VAR txt : String) : String;
VAR
	dyn : DynamicStrings.DynamicString;
	dynPos : LONGINT;
	i : LONGINT;
	ch : CHAR;
	putYet : BOOLEAN;
BEGIN
	TrimLineBreak(txt^);
	NEW(dyn);
	dynPos := 0;
	putYet := FALSE;
	FOR i := 0 TO Strings.Length(txt^)-1 DO
		ch := txt^[i];
		IF (ch = 020X) OR (ch = 9X) OR (ch = 0DX) OR (ch = 0AX) THEN
			IF ~putYet THEN
				dyn.Put(' ', dynPos);
				INC(dynPos);
				putYet := TRUE;
			END;
		ELSE
			dyn.Put(ch, dynPos);
			INC(dynPos);
			putYet := FALSE;
		END;
	END;
	RETURN dyn.ToArrOfChar();
END ReplaceWhiteSpaces;

PROCEDURE TrimLineBreak(VAR string : ARRAY OF CHAR);
VAR i,j: LONGINT;
BEGIN
	j := 0;
	WHILE (ORD(string[j]) = 10) OR (ORD(string[j]) = 13) DO INC(j) END;
	IF (j > 0) THEN
		i := 0;
		WHILE (string[j] # 0X) DO
			string[i] := string[j];
			INC(i); INC(j)
		END;
		string[i] := 0X
	END;
	i := Strings.Length(string)-1;
	WHILE (i >= 0) & ((ORD(string[i]) = 10) OR (ORD(string[i]) = 13)) DO DEC(i) END;
	string[i+1] := 0X;
END TrimLineBreak;

PROCEDURE ResolveAddress*(baseAddress : String; url : String) : String;
VAR
	slashPos, colonPos, upCnt : LONGINT;
BEGIN

	(* if url is absolute address, return it *)
	IF Strings.StartsWith2("http://", url^) OR Strings.StartsWith2("file://", url^) THEN
		RETURN url;
	END;

	(* if url is anchor in the same page, return 'baseAddress+url' *)
	IF Strings.StartsWith2("#", url^) THEN
		RETURN Strings.ConcatToNew(baseAddress^, url^);
	END;

	(* if url starts with "/", return ... *)
	IF url^[0] = '/' THEN
		slashPos := Strings.LastIndexOfByte2("/", baseAddress^);
		IF Strings.StartsWith2("file://", baseAddress^) THEN
			IF slashPos > 6 THEN
				baseAddress := Strings.Substring(0, slashPos, baseAddress^);
			ELSE
				colonPos := Strings.IndexOfByte(":", 7, baseAddress^);
				IF colonPos = -1 THEN
					baseAddress := Strings.Substring(0, slashPos, baseAddress^);
				ELSE
					baseAddress := Strings.Substring(0, colonPos+1, baseAddress^);
					url := Strings.Substring2(1, url^);
				END;
			END;
		ELSIF Strings.StartsWith2("http://", baseAddress^) THEN
			IF slashPos > 6 THEN
				baseAddress := Strings.Substring(0, slashPos, baseAddress^);
			END;
			(* else baseAddress==server w/h terminating "/" *)
		ELSE
			KernelLog.String("unknown protocol: "); KernelLog.String(baseAddress^); KernelLog.Ln;
			(* an assertion that will fail.... *)
			ASSERT(Strings.StartsWith2("file://", baseAddress^));
		END;
		RETURN Strings.ConcatToNew(baseAddress^, url^);
	END;

	(* make sure baseAddress ends with "/" *)
	IF baseAddress^[Strings.Length(baseAddress^) - 1] # '/' THEN
		slashPos := Strings.LastIndexOfByte2("/", baseAddress^);
		IF Strings.StartsWith2("file://", baseAddress^) THEN
			baseAddress := Strings.Substring(0, slashPos+1, baseAddress^);
		ELSIF Strings.StartsWith2("http://", baseAddress^) THEN
			IF slashPos > 6 THEN
				baseAddress := Strings.Substring(0, slashPos+1, baseAddress^);
			ELSE
				baseAddress := Strings.ConcatToNew(baseAddress^, "/");
			END;
		ELSE
			KernelLog.String("unknown protocol: "); KernelLog.String(baseAddress^); KernelLog.Ln;
			(* an assertion that will fail.... *)
			ASSERT(Strings.StartsWith2("file://", baseAddress^));
		END;
	END;

	(* count and cut  "../" on url *)
	upCnt := 0;
	WHILE (Strings.Pos("../", url^) = 0) & (Strings.Length(url^) > 3) DO
		INC(upCnt);
		url := Strings.Substring2(3, url^);
	END;

	(* cut  "./" on url *)
	WHILE (Strings.Pos("./", url^) = 0) & (Strings.Length(url^) > 2) DO
		url := Strings.Substring2(2, url^);
	END;

	(* go up upCnt directories *)
	WHILE (upCnt > 0) & (Strings.LastIndexOfByte("/", Strings.Length(baseAddress^) - 1, baseAddress^) # -1) DO
		baseAddress := Strings.Substring(0, Strings.LastIndexOfByte("/", Strings.Length(baseAddress^) - 2, baseAddress^) + 1, baseAddress^);
		DEC(upCnt);
	END;

	RETURN Strings.ConcatToNew(baseAddress^, url^);

END ResolveAddress;

PROCEDURE GetElemAttributeValue*(elem : XML.Element; key : ARRAY OF CHAR; lowerCase : BOOLEAN) : String;
VAR
	enum: XMLObjects.Enumerator;
	p : ANY;
	s : String;
BEGIN
	enum := elem.GetAttributes();
	WHILE (enum.HasMoreElements()) DO
		p := enum.GetNext();
		IF p IS XML.Attribute THEN
			s := p(XML.Attribute).GetName();
			s := Strings.NewString(s^);
			Strings.LowerCase(s^);
			IF s^ = key THEN
				s := p(XML.Attribute).GetValue();
				s := Strings.NewString(s^);
				IF lowerCase THEN Strings.LowerCase(s^); END;
				RETURN s;
			END;
		END;
	END;
	RETURN NIL;
END GetElemAttributeValue;

PROCEDURE MapFontSize(font : String; size : LONGINT) : LONGINT;
BEGIN
	IF font^ = "Oberon" THEN
		IF size=1 THEN RETURN 8;
		ELSIF size=2 THEN RETURN 10;
		ELSIF size=3 THEN RETURN 12;
		ELSIF size=4 THEN RETURN 14;
		ELSIF size=5 THEN RETURN 16;
		ELSIF size=6 THEN RETURN 20;
		ELSIF size=7 THEN RETURN 24;
		ELSE RETURN 0 END;
	ELSE
		IF size=1 THEN RETURN 11;
		ELSIF size=2 THEN RETURN 12;
		ELSIF size=3 THEN RETURN 15;
		ELSIF size=4 THEN RETURN 18;
		ELSIF size=5 THEN RETURN 24;
		ELSIF size=6 THEN RETURN 30;
		ELSIF size=7 THEN RETURN 48;
		ELSE RETURN 0 END;
	END;
END MapFontSize;

PROCEDURE MapBaselineShift(size : LONGINT) : LONGINT;
BEGIN
	IF size=1 THEN RETURN 2;
	ELSIF size=2 THEN RETURN 3;
	ELSIF size=3 THEN RETURN 3;
	ELSIF size=4 THEN RETURN 4;
	ELSIF size=5 THEN RETURN 5;
	ELSIF size=6 THEN RETURN 6;
	ELSIF size=7 THEN RETURN 10;
	ELSE RETURN 0 END;
END MapBaselineShift;

(* returns the best matching existing font out of a list containing font-names and generic families *)
PROCEDURE GetExistingFontName(f : String) : String;
VAR
	fonts, temp : String;
	pos : LONGINT;
	font : ARRAY 32 OF CHAR;

	PROCEDURE Get(f : ARRAY OF CHAR; alternatives : BOOLEAN) : String;
	VAR
		i, j, last : LONGINT;
	BEGIN
		Strings.Trim(f, ' ');
		Strings.Trim(f, '"');
		Strings.Trim(f, "'");
		last := Strings.Length(f)-1;
		FOR i := 0 TO last DO
			IF f[i]=' ' THEN
				FOR j := i TO last-1 DO
					f[j] := f[j+1];
				END;
				DEC(last);
			END;
		END;
		f[last+1] := 0X;
		IF FontExists(f) THEN RETURN Strings.NewString(f); END;
		IF f="serif" THEN RETURN Strings.NewString(serif);
		ELSIF f="sans-serif" THEN RETURN Strings.NewString(sansSerif);
		ELSIF f="cursive" THEN RETURN Strings.NewString(cursive);
		ELSIF f="fantasy" THEN RETURN Strings.NewString(fantasy);
		ELSIF f="monospace" THEN RETURN Strings.NewString(monospace);
		END;
		IF alternatives THEN
			RETURN NIL;
		ELSE
			RETURN Strings.NewString(defaultFont);
		END;
	END Get;

BEGIN
	fonts := Strings.NewString(f^);
	LOOP
		pos := Strings.Pos(',', fonts^);
		IF pos = -1 THEN
			RETURN Get(fonts^, FALSE);
		ELSE
			Strings.Copy(fonts^, 0, pos, font);
			IF (pos+1) > (Strings.Length(fonts^)-1) THEN RETURN Get(font, FALSE); END;
			temp := Get(font, TRUE);
			IF temp#NIL THEN RETURN temp; END;
			temp := Strings.NewString(fonts^);
			Strings.Copy(temp^, pos+1, Strings.Length(fonts^)-(pos+1), fonts^);
		END;
	END;
END GetExistingFontName;

PROCEDURE FontExists(f : ARRAY OF CHAR) : BOOLEAN;
VAR
	font : WMGraphics.Font;
BEGIN
	font := WMGraphics.GetFont(f, 12, {0});
	RETURN (f = font.name);
END FontExists;

PROCEDURE IntToABCString(val : LONGINT; upperCase : BOOLEAN) : String;
VAR
	i, j, offset : LONGINT;
	aoc : ARRAY 5 OF CHAR;

	PROCEDURE GetChar(i : LONGINT) : CHAR;
	BEGIN
		IF i = 0 THEN
			RETURN '0';
		ELSE
			RETURN CHR(offset+i);
		END;
	END GetChar;

BEGIN
	IF upperCase THEN offset := 64 ELSE offset := 96; END;
	val := val MOD (26*26);
	i := val DIV 26;
	j := val MOD 26;
	IF i = 0 THEN
		aoc := " . ";
		aoc[0] := GetChar(j);
	ELSE
		aoc := "  . ";
		aoc[0] := GetChar(i);
		aoc[1] := GetChar(j);
	END;
	RETURN Strings.NewString(aoc);
END IntToABCString;

PROCEDURE IntToRomanString(val : LONGINT; uppercase : BOOLEAN) : String;
VAR
	dyn : DynamicStrings.DynamicString;
	aoc : ARRAY 3 OF CHAR;
	s : String;
BEGIN
	IF val = 0 THEN RETURN Strings.NewString("0. "); END;
	NEW(dyn);
	WHILE val > 0 DO
		IF val >= 1000 THEN
			aoc := "M"; dyn.Append(aoc); val := val - 1000;
		ELSIF val >= 900 THEN
			aoc := "CM"; dyn.Append(aoc); val := val - 900;
		ELSIF val >= 500 THEN
			aoc := "D"; dyn.Append(aoc); val := val - 500;
		ELSIF val >= 400 THEN
			aoc := "CD"; dyn.Append(aoc); val := val - 400;
		ELSIF val >= 100 THEN
			aoc := "C"; dyn.Append(aoc); val := val - 100;
		ELSIF val >= 90 THEN
			aoc := "XC"; dyn.Append(aoc); val := val - 90;
		ELSIF val >= 50 THEN
			aoc := "L"; dyn.Append(aoc); val := val - 50;
		ELSIF val >= 40 THEN
			aoc := "XL"; dyn.Append(aoc); val := val - 40;
		ELSIF val >= 10 THEN
			aoc := "X"; dyn.Append(aoc); val := val - 10;
		ELSIF val >= 9 THEN
			aoc := "IX"; dyn.Append(aoc); val := val - 9;
		ELSIF val >= 5 THEN
			aoc := "V"; dyn.Append(aoc); val := val - 5;
		ELSIF val >= 4 THEN
			aoc := "IV"; dyn.Append(aoc); val := val - 4;
		ELSIF val >= 1 THEN
			aoc := "I"; dyn.Append(aoc); val := val - 1;
		END;
	END;
	aoc := ". "; dyn.Append(aoc);
	s := dyn.ToArrOfChar();
	IF ~uppercase THEN Strings.LowerCase(s^); END;
	RETURN s;
END IntToRomanString;

PROCEDURE TransformCharEnt*(in : String) : String;
VAR
	ent : ARRAY 32 OF CHAR;
	i, j : LONGINT;
	rep, s1, s2 : String;
	ds: DynamicStrings.DynamicString;
BEGIN
	i:=0;
	LOOP
		IF in^[i]='&' THEN
			j:=i+1;
			LOOP
				IF j >= LEN(in^)-1 THEN EXIT END;
				IF in^[j]=';' THEN
					Strings.Copy(in^, i+1, j-i-1, ent);
					rep := GetCharEnt(ent);
					IF rep#NIL THEN
						NEW(ds);
						ds.FromArrOfChar(in);
						s1 := ds.Extract(0, i);
						s2 := ds.Extract(j+1, LEN(in^)-j-1);
						NEW(ds);
						ds.Append(s1^);
						ds.Append(rep^);
						ds.Append(s2^);
						in := ds.ToArrOfChar();
						i:=i+LEN(rep^)-2;
					END;
					EXIT;
				END;
				INC(j);
			END;
		END;
		INC(i);
		IF i>LEN(in^)-3 THEN EXIT END;
	END;
	RETURN in;
END TransformCharEnt;

PROCEDURE GetCharEnt(VAR ent : ARRAY OF CHAR) : String;
VAR
	temp : String;
	aoc : ARRAY 5 OF CHAR;
	res, suc, len : LONGINT;
BEGIN
	res := 0;
	IF ent[0] = '#' THEN
		temp := Strings.Substring2(1, ent);
		IF Strings.Length(temp^) > 0 THEN
			IF (temp^[0] = 'x') OR (temp^[0] = 'X') THEN
				temp := Strings.Substring2(1, ent);
				Strings.HexStrToInt(temp^, res, suc);
				IF suc # 0 THEN res := 160 END;
			ELSE
				Strings.StrToInt(temp^, res);
			END;
		ELSE
			res := 160;
		END;
	ELSIF ent = "nbsp" THEN res := 160;
	ELSIF ent = "auml" THEN res := 228;
	ELSIF ent = "ouml" THEN res := 246;
	ELSIF ent = "uuml" THEN res := 252;
	ELSIF ent = "Auml" THEN res := 196;
	ELSIF ent = "Ouml" THEN res := 214;
	ELSIF ent = "Uuml" THEN res := 220;
	ELSIF ent = "quot" THEN res := 34;
	ELSIF ent = "copy" THEN res := 169;
	ELSIF ent = "euro" THEN res := 8364;
	ELSIF ent = "iexcl" THEN res := 161;
	ELSIF ent = "cent" THEN res := 162;
	ELSIF ent = "pound" THEN res := 163;
	ELSIF ent = "curren" THEN res := 164;
	ELSIF ent = "yen" THEN res := 165;
	ELSIF ent = "brvbar" THEN res := 166;
	ELSIF ent = "sect" THEN res := 167;
	ELSIF ent = "uml" THEN res := 168;
	ELSIF ent = "ordf" THEN res := 170;
	ELSIF ent = "laquo" THEN res := 171;
	ELSIF ent = "not" THEN res := 172;
	ELSIF ent = "shy" THEN res := 173;
	ELSIF ent = "reg" THEN res := 174;
	ELSIF ent = "macr" THEN res := 175;
	ELSIF ent = "deg" THEN res := 176;
	ELSIF ent = "plusmn" THEN res := 177;
	ELSIF ent = "sup2" THEN res := 178;
	ELSIF ent = "sup3" THEN res := 179;
	ELSIF ent = "acute" THEN res := 180;
	ELSIF ent = "micro" THEN res := 181;
	ELSIF ent = "para" THEN res := 182;
	ELSIF ent = "middot" THEN res := 183;
	ELSIF ent = "cedil" THEN res := 184;
	ELSIF ent = "sup1" THEN res := 185;
	ELSIF ent = "ordm" THEN res := 186;
	ELSIF ent = "raquo" THEN res := 187;
	ELSIF ent = "frac14" THEN res := 188;
	ELSIF ent = "frac12" THEN res := 189;
	ELSIF ent = "frac34" THEN res := 190;
	ELSIF ent = "iquest" THEN res := 191;
	ELSIF ent = "Agrave" THEN res := 192;
	ELSIF ent = "Aacute" THEN res := 193;
	ELSIF ent = "Acirc" THEN res := 194;
	ELSIF ent = "Atilde" THEN res := 195;
	ELSIF ent = "Aring" THEN res := 197;
	ELSIF ent = "AElig" THEN res := 198;
	ELSIF ent = "Ccedil" THEN res := 199;
	ELSIF ent = "Egrave" THEN res := 200;
	ELSIF ent = "Eacute" THEN res := 201;
	ELSIF ent = "Ecirc" THEN res := 202;
	ELSIF ent = "Euml" THEN res := 203;
	ELSIF ent = "Igrave" THEN res := 204;
	ELSIF ent = "Iacute" THEN res := 205;
	ELSIF ent = "Icirc" THEN res := 206;
	ELSIF ent = "Iuml" THEN res := 207;
	ELSIF ent = "ETH" THEN res := 208;
	ELSIF ent = "Ntilde" THEN res := 209;
	ELSIF ent = "Ograve" THEN res := 210;
	ELSIF ent = "Oacute" THEN res := 211;
	ELSIF ent = "Ocirc" THEN res := 212;
	ELSIF ent = "Otilde" THEN res := 213;
	ELSIF ent = "times" THEN res := 215;
	ELSIF ent = "Oslash" THEN res := 216;
	ELSIF ent = "Ugrave" THEN res := 217;
	ELSIF ent = "Uacute" THEN res := 218;
	ELSIF ent = "Ucirc" THEN res := 219;
	ELSIF ent = "Yacute" THEN res := 221;
	ELSIF ent = "THORN" THEN res := 222;
	ELSIF ent = "szlig" THEN res := 223;
	ELSIF ent = "agrave" THEN res := 224;
	ELSIF ent = "aacute" THEN res := 225;
	ELSIF ent = "acirc" THEN res := 226;
	ELSIF ent = "atilde" THEN res := 227;
	ELSIF ent = "aring" THEN res := 229;
	ELSIF ent = "aelig" THEN res := 230;
	ELSIF ent = "ccedil" THEN res := 231;
	ELSIF ent = "egrave" THEN res := 232;
	ELSIF ent = "eacute" THEN res := 233;
	ELSIF ent = "ecirc" THEN res := 234;
	ELSIF ent = "euml" THEN res := 235;
	ELSIF ent = "igrave" THEN res := 236;
	ELSIF ent = "iacute" THEN res := 237;
	ELSIF ent = "icirc" THEN res := 238;
	ELSIF ent = "iuml" THEN res := 239;
	ELSIF ent = "eth" THEN res := 240;
	ELSIF ent = "ntilde" THEN res := 241;
	ELSIF ent = "ograve" THEN res := 242;
	ELSIF ent = "oacute" THEN res := 243;
	ELSIF ent = "ocirc" THEN res := 244;
	ELSIF ent = "otilde" THEN res := 245;
	ELSIF ent = "divide" THEN res := 247;
	ELSIF ent = "oslash" THEN res := 248;
	ELSIF ent = "ugrave" THEN res := 249;
	ELSIF ent = "uacute" THEN res := 250;
	ELSIF ent = "ucirc" THEN res := 251;
	ELSIF ent = "yacute" THEN res := 253;
	ELSIF ent = "thorn" THEN res := 254;
	ELSIF ent = "yuml" THEN res := 255;
	ELSIF ent = "fnof" THEN res := 402;
	ELSIF ent = "Alpha" THEN res := 913;
	ELSIF ent = "Beta" THEN res := 914;
	ELSIF ent = "Gamma" THEN res := 915;
	ELSIF ent = "Delta" THEN res := 916;
	ELSIF ent = "Epsilon" THEN res := 917;
	ELSIF ent = "Zeta" THEN res := 918;
	ELSIF ent = "Eta" THEN res := 919;
	ELSIF ent = "Theta" THEN res := 920;
	ELSIF ent = "Iota" THEN res := 921;
	ELSIF ent = "Kappa" THEN res := 922;
	ELSIF ent = "Lambda" THEN res := 923;
	ELSIF ent = "Mu" THEN res := 924;
	ELSIF ent = "Nu" THEN res := 925;
	ELSIF ent = "Xi" THEN res := 926;
	ELSIF ent = "Omicron" THEN res := 927;
	ELSIF ent = "Pi" THEN res := 928;
	ELSIF ent = "Rho" THEN res := 929;
	ELSIF ent = "Sigma" THEN res := 931;
	ELSIF ent = "Tau" THEN res := 932;
	ELSIF ent = "Upsilon" THEN res := 933;
	ELSIF ent = "Phi" THEN res := 934;
	ELSIF ent = "Chi" THEN res := 935;
	ELSIF ent = "Psi" THEN res := 936;
	ELSIF ent = "Omega" THEN res := 937;
	ELSIF ent = "alpha" THEN res := 945;
	ELSIF ent = "beta" THEN res := 946;
	ELSIF ent = "gamma" THEN res := 947;
	ELSIF ent = "delta" THEN res := 948;
	ELSIF ent = "epsilon" THEN res := 949;
	ELSIF ent = "zeta" THEN res := 950;
	ELSIF ent = "eta" THEN res := 951;
	ELSIF ent = "theta" THEN res := 952;
	ELSIF ent = "iota" THEN res := 953;
	ELSIF ent = "kappa" THEN res := 954;
	ELSIF ent = "lambda" THEN res := 955;
	ELSIF ent = "mu" THEN res := 956;
	ELSIF ent = "nu" THEN res := 957;
	ELSIF ent = "xi" THEN res := 958;
	ELSIF ent = "omicron" THEN res := 959;
	ELSIF ent = "pi" THEN res := 960;
	ELSIF ent = "rho" THEN res := 961;
	ELSIF ent = "sigmaf" THEN res := 962;
	ELSIF ent = "sigma" THEN res := 963;
	ELSIF ent = "tau" THEN res := 964;
	ELSIF ent = "upsilon" THEN res := 965;
	ELSIF ent = "phi" THEN res := 966;
	ELSIF ent = "chi" THEN res := 967;
	ELSIF ent = "psi" THEN res := 968;
	ELSIF ent = "omega" THEN res := 969;
	ELSIF ent = "thetasym" THEN res := 977;
	ELSIF ent = "upsih" THEN res := 978;
	ELSIF ent = "piv" THEN res := 982;
	ELSIF ent = "bull" THEN res := 8226;
	ELSIF ent = "hellip" THEN res := 8230;
	ELSIF ent = "prime" THEN res := 8242;
	ELSIF ent = "Prime" THEN res := 8243;
	ELSIF ent = "oline" THEN res := 8254;
	ELSIF ent = "frasl" THEN res := 8260;
	ELSIF ent = "weierp" THEN res := 8472;
	ELSIF ent = "image" THEN res := 8465;
	ELSIF ent = "real" THEN res := 8476;
	ELSIF ent = "trade" THEN res := 8482;
	ELSIF ent = "alefsym" THEN res := 8501;
	ELSIF ent = "larr" THEN res := 8592;
	ELSIF ent = "uarr" THEN res := 8593;
	ELSIF ent = "rarr" THEN res := 8594;
	ELSIF ent = "darr" THEN res := 8595;
	ELSIF ent = "harr" THEN res := 8596;
	ELSIF ent = "crarr" THEN res := 8629;
	ELSIF ent = "lArr" THEN res := 8656;
	ELSIF ent = "uArr" THEN res := 8657;
	ELSIF ent = "rArr" THEN res := 8658;
	ELSIF ent = "dArr" THEN res := 8659;
	ELSIF ent = "hArr" THEN res := 8660;
	ELSIF ent = "forall" THEN res := 8704;
	ELSIF ent = "part" THEN res := 8706;
	ELSIF ent = "exist" THEN res := 8707;
	ELSIF ent = "empty" THEN res := 8709;
	ELSIF ent = "nabla" THEN res := 8711;
	ELSIF ent = "isin" THEN res := 8712;
	ELSIF ent = "notin" THEN res := 8713;
	ELSIF ent = "ni" THEN res := 8715;
	ELSIF ent = "prod" THEN res := 8719;
	ELSIF ent = "sum" THEN res := 8721;
	ELSIF ent = "minus" THEN res := 8722;
	ELSIF ent = "lowast" THEN res := 8727;
	ELSIF ent = "radic" THEN res := 8730;
	ELSIF ent = "prop" THEN res := 8733;
	ELSIF ent = "infin" THEN res := 8734;
	ELSIF ent = "ang" THEN res := 8736;
	ELSIF ent = "and" THEN res := 8743;
	ELSIF ent = "or" THEN res := 8744;
	ELSIF ent = "cap" THEN res := 8745;
	ELSIF ent = "cup" THEN res := 8746;
	ELSIF ent = "int" THEN res := 8747;
	ELSIF ent = "there4" THEN res := 8756;
	ELSIF ent = "sim" THEN res := 8764;
	ELSIF ent = "cong" THEN res := 8773;
	ELSIF ent = "asymp" THEN res := 8776;
	ELSIF ent = "ne" THEN res := 8800;
	ELSIF ent = "equiv" THEN res := 8801;
	ELSIF ent = "le" THEN res := 8804;
	ELSIF ent = "ge" THEN res := 8805;
	ELSIF ent = "sub" THEN res := 8834;
	ELSIF ent = "sup" THEN res := 8835;
	ELSIF ent = "nsub" THEN res := 8836;
	ELSIF ent = "sube" THEN res := 8838;
	ELSIF ent = "supe" THEN res := 8839;
	ELSIF ent = "oplus" THEN res := 8853;
	ELSIF ent = "otimes" THEN res := 8855;
	ELSIF ent = "perp" THEN res := 8869;
	ELSIF ent = "sdot" THEN res := 8901;
	ELSIF ent = "lceil" THEN res := 8968;
	ELSIF ent = "rceil" THEN res := 8969;
	ELSIF ent = "lfloor" THEN res := 8970;
	ELSIF ent = "rfloor" THEN res := 8971;
	ELSIF ent = "lang" THEN res := 9001;
	ELSIF ent = "rang" THEN res := 9002;
	ELSIF ent = "loz" THEN res := 9674;
	ELSIF ent = "spades" THEN res := 9824;
	ELSIF ent = "clubs" THEN res := 9827;
	ELSIF ent = "hearts" THEN res := 9829;
	ELSIF ent = "diams" THEN res := 9830;
	ELSIF ent = "amp" THEN res := 38;
	ELSIF ent = "lt" THEN res := 60;
	ELSIF ent = "gt" THEN res := 62;
	ELSIF ent = "OElig" THEN res := 338;
	ELSIF ent = "oelig" THEN res := 339;
	ELSIF ent = "Scaron" THEN res := 352;
	ELSIF ent = "scaron" THEN res := 353;
	ELSIF ent = "Yuml" THEN res := 376;
	ELSIF ent = "circ" THEN res := 710;
	ELSIF ent = "tilde" THEN res := 732;
	ELSIF ent = "ensp" THEN res := 8194;
	ELSIF ent = "emsp" THEN res := 8195;
	ELSIF ent = "thinsp" THEN res := 8201;
	ELSIF ent = "zwnj" THEN res := 8204;
	ELSIF ent = "zwj" THEN res := 8205;
	ELSIF ent = "lrm" THEN res := 8206;
	ELSIF ent = "rlm" THEN res := 8207;
	ELSIF ent = "ndash" THEN res := 8211;
	ELSIF ent = "mdash" THEN res := 8212;
	ELSIF ent = "lsquo" THEN res := 8216;
	ELSIF ent = "rsquo" THEN res := 8217;
	ELSIF ent = "sbquo" THEN res := 8218;
	ELSIF ent = "ldquo" THEN res := 8220;
	ELSIF ent = "rdquo" THEN res := 8221;
	ELSIF ent = "bdquo" THEN res := 8222;
	ELSIF ent = "dagger" THEN res := 8224;
	ELSIF ent = "Dagger" THEN res := 8225;
	ELSIF ent = "permil" THEN res := 8240;
	ELSIF ent = "lsaquo" THEN res := 8249;
	ELSIF ent = "rsaquo" THEN res := 8250;
	ELSE RETURN NIL;
	END;

	IF UTF8Strings.EncodeChar(res, aoc, len) THEN
		RETURN Strings.NewString(aoc);
	ELSE
		RETURN Strings.NewString("*");
	END;
END GetCharEnt;

BEGIN
	IF FontExists(defSerif) THEN serif := defSerif; ELSE serif := defaultFont END;
	IF FontExists(defSansSerif) THEN sansSerif := defSansSerif; ELSE sansSerif := defaultFont END;
	IF FontExists(defCursive) THEN cursive := defCursive; ELSE cursive := defaultFont END;
	IF FontExists(defFantasy) THEN fantasy := defFantasy; ELSE fantasy := defaultFont END;
	IF FontExists(defMonospace) THEN monospace := defMonospace; ELSE monospace := defaultFont END;
END HTMLTransformer.
