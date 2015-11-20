MODULE CSS2Properties;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE ""; *)

IMPORT
	DynamicStrings, XMLObjects, CSS2, WMWindowManager, WMGraphics,
	Raster, GfxImages, GfxFonts, Gfx;

CONST
	(** Colors *)
	Aqua* = LONGINT(0FF00FFFFH);
	Black* =LONGINT( 0FF000000H);
	Blue* = LONGINT(0FF0000FFH);
	Fuchsia* = LONGINT(0FFFF00FFH);
	Gray* = LONGINT(0FF808080H);
	Green* =LONGINT( 0FF008000H);
	Lime* = LONGINT(0FF00FF00H);
	Maroon* = LONGINT(0FF800000H);
	Navy* = LONGINT(0FF000080H);
	Olive* =LONGINT( 0FF808000H);
	Purple* = LONGINT(0FF800080H);
	Red* = LONGINT(0FFFF0000H);
	Silver* = LONGINT(0FFC0C0C0H);
	Teal* = LONGINT(0FF008080H);
	White* = LONGINT(0FFFFFFFFH);
	Yellow* = LONGINT(0FFFFFF00H);
	Transparent* = 00000000H;

	(** font-size: <absolute-size> *)
	XXSmall* = 0; XSmall* = 1; Small* = 2; Medium* = 3; Large* = 4; XLarge* = 5; XXLarge* = 6;

	(** font-size: <relative-size> *)
	Larger* = 7; Smaller* = 8;

	(** Ident.type *)
	None* = 1;
	Inherit* = 2;
	Normal* = 3;
	Auto* = 4;

	(** background-position *)
	Top* = 5; Center* = 6; Bottom* = 7; Left* = 8; Right* = 9;

	(** background-repeat *)
	Repeat* = 5; NoRepeat* = 6;

	(** border-collapse *)
	Collapse* = 5; Separate* = 6;

	(** border-style *)
	Hidden* = 6; Dotted* = 7; Dashed* = 8; Solid* = 9; Double* = 10; Groove* = 11; Ridge* = 12; Inset* = 13; Outset* = 14;

	(** border-width *)
	Thin* = 5; Thick* = 7;

	(** bottom, left, right, top *)
	StaticPosition* = 5;

	(** clear *)
	Clear* = 5;

	(** content *)
	OpenQuote* = 5; CloseQuote* = 6; NoOpenQuote* = 7; NoCloseQuote* = 8;

	(** cursor *)
	Crosshair* = 5; Default* = 6; Pointer* = 7; Move* = 8;
	EResize* = 9; NEResize* = 10; NWResize* = 11; NResize* = 12; SEResize* = 13; SWResize* = 14; SResize* = 15;
	WResize* = 16; Text* = 17; Wait* = 18; Help* = 19;

	(** direction *)
	Ltr* = 5; Rtl* = 6;

	(** display *)
	Inline* = 3; Block* = 4; ListItem* = 5; RunIn* = 6; Compact* = 7; Marker* = 8;
	Table* = 9; InlineTable* = 10; TableRowGroup* = 11; TableHeaderGroup* = 12; TableFooterGroup* = 13; TableRow* = 14;
	TableColumnGroup* = 15; TableColumn* = 16; TableCell* = 17; TableCaption* = 18;

	(** empty-cells *)
	Show* = 5; Hide* = 6;

	(** font *)
	Caption* = 5; Icon* = 6; Menu* = 7; MessageBox* = 8; SmallCaption* = 9; StatusBar* = 10;

	(** font-stretch *)
	Wider* = 5; Narrower* = 6; UltraCondensed* = 7; ExtraCondensed* = 8; Condensed* = 9; SemiCondensed* = 10;
	SemiExpanded* = 11; Expanded* = 12; ExtraExpanded* = 13; UltraExpanded* = 14;

	(** font-style *)
	Italic* = 5; Oblique* = 6;

	(** font-variant *)
	SmallCaps* = 5;

	(** font-weight *)
	Bold* = 5; Bolder* = 6; Lighter* = 7;

	(** list-style-position *)
	Inside* = 5; Outside* = 6;

	(** list-style-type *)
	Disc* = 5; Circle* = 6; Square* = 7; Decimal* = 8; DecimalLeadingZero* = 9; LowerRoman* = 10; UpperRoman* = 11;
	LowerGreek* = 12; LowerAlpha* = 13; LowerLatin* = 14; UpperAlpha* = 15; UpperLatin* = 16;
	Hebrew* = 17; Armenian* = 18; Georgian* = 19; CjkIdeographic* = 20;
	Hiragana* = 21; Katakana* = 22; HiraganaIroha* = 23; KatakanaIroha* = 24;

	(* (** marks *)
	Crop* = 120; Cross* = 121; *)

	(** outline-color *)
	Invert* = 122;

	(** overflow, visibility *)
	Visible* = 7;

	(** position, background-attachment *)
	Static* = 5; Relative* = 6; Absolute* = 7; Fixed* = 8; Scroll* = 9;

	(** text-align *)
	Justify* = 10;

	(** text-decoration *)
	Underline* = 5; Overline* = 6; LineThrough* = 7; Blink* = 8;

	(** text-transform *)
	Capitalize* = 5; Uppercase* = 6; Lowercase* = 7;

	(** unicodeBidi *)
	Embed* = 5; BidiOverride* = 6;

	(** vertical-align *)
	Baseline* = 8; Sub* = 9; Super* = 10; TextTop* = 11; Middle* = 12; TextBottom* = 13;

	(** white-space *)
	Pre* = 5; Nowrap* = 6;

	(* dummy auto *)
	DummyAuto = 0;

VAR
	AbsoluteFontSizes: ARRAY 7 OF SHORTINT;
	defaultColor*: LONGINT;
	defaultCursor*, crosshairCursor*, pointerCursor*, moveCursor*, eResizeCursor*, neResizeCursor*, nwResizeCursor*,
	nResizeCursor*, seResizeCursor*, swResizeCursor*, sResizeCursor*, wResizeCursor*, textCursor*, waitCursor*,
	helpCursor* : WMWindowManager.PointerInfo;
	defaultFont*, captionFont*, iconFont*, menuFont*, messageBoxFont*, smallCaptionFont*, statusBarFont*: GfxFonts.Font;
	thinBorder*, mediumBorder*, thickBorder*: LONGREAL;

TYPE
	String = CSS2.String;

TYPE
	Value* = RECORD specified: CSS2.Term END;
	Color* = RECORD (Value) computed*: RECORD r*, g*, b*, a*: CHAR END END;
	TRBLColor* = RECORD
		top*, right*, bottom*, left*: Color
	END;
	Ident* = RECORD (Value) computed*: SHORTINT END;
	TRBLIdent* = RECORD
		top*, right*, bottom*, left*: Ident
	END;
	Dim* = RECORD (Value) computed*: LONGREAL END;
	OrientDim* = RECORD
		horizontal*, vertical*: Dim
	END;
	TRBLDim* = RECORD
		top*, right*, bottom*, left*: Dim
	END;
	Bool* = RECORD (Value) computed*: BOOLEAN END;
	Img* = RECORD (Value) computed*: GfxImages.Image END;
	Cursor* = RECORD specified: XMLObjects.Collection; computed*: WMWindowManager.PointerInfo END;
	Font* = RECORD (Value) computed*: GfxFonts.Font END;

	ImgTerm = OBJECT (CSS2.Term)
		VAR img: GfxImages.Image
	END ImgTerm;

	AllMediaProperties* = OBJECT
		VAR
			parent: AllMediaProperties;
			replaced, generated: BOOLEAN;
			(* content*, *) counterIncrement*, counterReset*, display*: Ident;

		PROCEDURE & Init*;
		BEGIN
			parent := SELF;
			Initialize()
		END Init;

		PROCEDURE SetParent*(parent: AllMediaProperties);
		BEGIN
			SELF.parent := parent
		END SetParent;

		PROCEDURE GetValue*(name: ARRAY OF CHAR): CSS2.Declaration;
		VAR declaration: CSS2.Declaration;
		BEGIN
			NEW(declaration); declaration.SetProperty(name);
			IF name = "content" THEN
			ELSIF name = "counter-increment" THEN
			ELSIF name = "counter-reset" THEN
			ELSIF name = "display" THEN
				declaration.AddTerm(display.specified)
			ELSE
				declaration := NIL
			END;
			RETURN declaration
		END GetValue;

		PROCEDURE SetValue*(declaration: CSS2.Declaration);
		VAR s: String; terms: XMLObjects.Enumerator; c: ANY; term1: CSS2.Term;
		BEGIN
			s := declaration.GetProperty();
			terms := declaration.GetTerms();
			c := terms.GetNext();
			IF c = NIL THEN RETURN END;
			term1 := c(CSS2.Term);
			IF s^ = "content" THEN

			ELSIF s^ = "counter-increment" THEN

			ELSIF s^ = "counter-reset" THEN

			ELSIF s^ = "display" THEN
				IF ~SetNil(display.specified, term1) & ~SetIdentOrInherit(display.specified, term1) & ~SetNone(display.specified, term1) THEN
					IF term1.IsStringIdent("inline") THEN display.specified := ChangeToIdent(Inline)
					ELSIF term1.IsStringIdent("block") THEN display.specified := ChangeToIdent(Block)
					ELSIF term1.IsStringIdent("list-item") THEN display.specified := ChangeToIdent(ListItem)
					ELSIF term1.IsStringIdent("run-in") THEN display.specified := ChangeToIdent(RunIn)
					ELSIF term1.IsStringIdent("compact") THEN display.specified := ChangeToIdent(Compact)
					ELSIF term1.IsStringIdent("marker") THEN display.specified := ChangeToIdent(Marker)
					ELSIF term1.IsStringIdent("table") THEN display.specified := ChangeToIdent(Table)
					ELSIF term1.IsStringIdent("inline-table") THEN display.specified := ChangeToIdent(InlineTable)
					ELSIF term1.IsStringIdent("table-row-group") THEN display.specified := ChangeToIdent(TableRowGroup)
					ELSIF term1.IsStringIdent("table-header-group") THEN display.specified := ChangeToIdent(TableHeaderGroup)
					ELSIF term1.IsStringIdent("table-footer-group") THEN display.specified := ChangeToIdent(TableFooterGroup)
					ELSIF term1.IsStringIdent("table-row") THEN display.specified := ChangeToIdent(TableRow)
					ELSIF term1.IsStringIdent("table-column-group") THEN display.specified := ChangeToIdent(TableColumnGroup)
					ELSIF term1.IsStringIdent("table-column") THEN display.specified := ChangeToIdent(TableColumn)
					ELSIF term1.IsStringIdent("table-cell") THEN display.specified := ChangeToIdent(TableCell)
					ELSIF term1.IsStringIdent("table-caption") THEN display.specified := ChangeToIdent(TableCaption)
					END
				END
			ELSE
			END
		END SetValue;

		PROCEDURE Initialize*;
		BEGIN
			display.computed := Inline; display.specified := NIL
		END Initialize;

		PROCEDURE ComputeValues*;
		BEGIN
			ComputeIdent(display, parent.display)
		END ComputeValues;

		PROCEDURE IsBlockLevelElement*(): BOOLEAN;
		BEGIN
			RETURN display.computed IN {Block, ListItem, Compact, RunIn, Table, TableCell}
		END IsBlockLevelElement;

		PROCEDURE IsInlineLevelElement*(): BOOLEAN;
		BEGIN
			RETURN display.computed IN {Inline, InlineTable, Compact}
		END IsInlineLevelElement;

	END AllMediaProperties;

	VisualProperties* = OBJECT (AllMediaProperties)
		VAR
			dimensionChanged-: BOOLEAN;
			containingBlock: RECORD
				width, height: LONGREAL
			END;
			ppi*: LONGREAL;
			backgroundAttachment*: Bool;	(* Scroll = TRUE, Fixed = FALSE *)
			backgroundColor*: Color;
			backgroundImage*: Img;
			backgroundPosition*: OrientDim;
			backgroundRepeat*: RECORD horizontal*, vertical*: Bool END;	(* Repeat = TRUE, NoRepeat = FALSE *)
			borderCollapse*: Bool;	(* Collapse = TRUE, Separate = FALSE *)
			borderSpacing*: OrientDim;
			borderColor*: TRBLColor;
			borderStyle*: TRBLIdent;
			borderWidth*, margin*, padding*: TRBLDim;
			top*, right*, bottom*, left*: Dim;
			height*, width*, maxHeight*, maxWidth*, minHeight*, minWidth*: Dim;
			captionSide*: Ident;
			clear*: RECORD left*, right*: Bool END;	(* Clear = TRUE, None = FALSE *)
			clip*: TRBLDim;
			color*: Color;
			cursor*: Cursor;
			direction*: Bool;	(* Ltr = TRUE, Rtl = FALSE *)
			emptyCells*: Bool;	(* Show = TRUE, Hide = FALSE *)
			float*: Ident;
			font*: Font;
			fontSize*: Dim;
			fontFamily*, fontSizeAdjust*, fontStyle*, fontWeight*: CSS2.Term;
			fontStretch*: Ident;
			fontVariant*: Bool;	(* Normal = TRUE, Smallcaps = FALSE *)
			letterSpacing*, wordSpacing*: Dim;
			lineHeight*: Dim;
			listStyleImage*: Img;
			listStylePosition*: Bool; (* Outside = TRUE, Inside = FALSE *)
			listStyleType*: Ident;
			markerOffset*: Dim;
			outlineColor*: Color;	(* Invert = Transparent *)
			outlineStyle*: Ident;
			outlineWidth*: Dim;
			overflow*: Ident;
			position*: Ident;
			quotes*: RECORD (Value) END;
			tableLayout*: Bool;	(* Auto = TRUE, Fixed = FALSE *)
			textAlign*: Ident;
			textDecoration*: RECORD (Value) computed*: SET END;
			textIndent*: Dim;
			textShadow*: RECORD (Value) END;
			textTransform*: Ident;
			unicodeBidi*: Ident;
			verticalAlign*: RECORD (Value) computedLength*: LONGREAL; computed*: SHORTINT END;
			visibility*: Ident;
			whiteSpace*: Ident;
			zIndex*: RECORD (Value) computed*: LONGINT END;	(* Auto = -1 *)

		PROCEDURE &Init*;
		BEGIN
			Init^();
			ppi := 91.44
		END Init;

		PROCEDURE SetParent(parent: AllMediaProperties);
		BEGIN
			IF parent IS VisualProperties THEN SetParent^(parent) END
		END SetParent;

		PROCEDURE GetValue(name: ARRAY OF CHAR): CSS2.Declaration;
		VAR declaration: CSS2.Declaration; term1: CSS2.Term;
		BEGIN
			NEW(declaration); declaration.SetProperty(name);
			IF name = "background-attachment" THEN
				declaration.AddTerm(backgroundAttachment.specified)
			ELSIF name = "background-color" THEN
				declaration.AddTerm(backgroundColor.specified)
			ELSIF name = "background-image" THEN
				declaration.AddTerm(backgroundImage.specified)
			ELSIF name = "background-position" THEN
				declaration.AddTerm(backgroundPosition.horizontal.specified);
				declaration.AddTerm(backgroundPosition.vertical.specified)
			ELSIF name = "background-repeat" THEN
				IF (backgroundRepeat.horizontal.specified # NIL) & backgroundRepeat.horizontal.specified.IsIdent(NoRepeat)
						& (backgroundRepeat.vertical.specified # NIL) & backgroundRepeat.vertical.specified.IsIdent(NoRepeat) THEN
					ChangeToStringIdent(term1, "no-repeat")
				ELSIF (backgroundRepeat.horizontal.specified # NIL) & backgroundRepeat.horizontal.specified.IsIdent(Repeat)
						& (backgroundRepeat.vertical.specified # NIL) & backgroundRepeat.vertical.specified.IsIdent(NoRepeat) THEN
					ChangeToStringIdent(term1, "repeat-x")
				ELSIF (backgroundRepeat.horizontal.specified # NIL) & backgroundRepeat.horizontal.specified.IsIdent(NoRepeat)
						& (backgroundRepeat.vertical.specified # NIL) & backgroundRepeat.vertical.specified.IsIdent(Repeat) THEN
					ChangeToStringIdent(term1, "repeat-y")
				ELSIF (backgroundRepeat.horizontal.specified # NIL) & backgroundRepeat.horizontal.specified.IsIdent(Repeat)
						& (backgroundRepeat.vertical.specified # NIL) & backgroundRepeat.vertical.specified.IsIdent(Repeat) THEN
					ChangeToStringIdent(term1, "repeat")
				END;
				declaration.AddTerm(term1)
			ELSIF name = "border" THEN
				declaration.AddTerm(borderWidth.top.specified);
				declaration.AddTerm(borderStyle.top.specified);
				declaration.AddTerm(borderColor.top.specified)
			ELSIF name = "border-collapse" THEN
				declaration.AddTerm(borderCollapse.specified)
			ELSIF name = "border-color" THEN
				declaration.AddTerm(borderColor.top.specified);
				declaration.AddTerm(borderColor.right.specified);
				declaration.AddTerm(borderColor.bottom.specified);
				declaration.AddTerm(borderColor.left.specified)
			ELSIF name = "border-spacing" THEN
				declaration.AddTerm(borderSpacing.horizontal.specified);
				declaration.AddTerm(borderSpacing.vertical.specified)
			ELSIF name = "border-style" THEN
				declaration.AddTerm(borderStyle.top.specified);
				declaration.AddTerm(borderStyle.right.specified);
				declaration.AddTerm(borderStyle.bottom.specified);
				declaration.AddTerm(borderStyle.left.specified)
			ELSIF name = "border-top" THEN
				declaration.AddTerm(borderWidth.top.specified);
				declaration.AddTerm(borderStyle.top.specified);
				declaration.AddTerm(borderColor.top.specified)
			ELSIF name = "border-right" THEN
				declaration.AddTerm(borderWidth.right.specified);
				declaration.AddTerm(borderStyle.right.specified);
				declaration.AddTerm(borderColor.right.specified)
			ELSIF name = "border-bottom" THEN
				declaration.AddTerm(borderWidth.bottom.specified);
				declaration.AddTerm(borderStyle.bottom.specified);
				declaration.AddTerm(borderColor.bottom.specified)
			ELSIF name = "border-left" THEN
				declaration.AddTerm(borderWidth.left.specified);
				declaration.AddTerm(borderStyle.left.specified);
				declaration.AddTerm(borderColor.left.specified)
			ELSIF name = "border-top-color" THEN
				declaration.AddTerm(borderColor.top.specified)
			ELSIF name = "border-right-color" THEN
				declaration.AddTerm(borderColor.right.specified)
			ELSIF name = "border-bottom-color" THEN
				declaration.AddTerm(borderColor.bottom.specified)
			ELSIF name = "border-left-color" THEN
				declaration.AddTerm(borderColor.left.specified)
			ELSIF name = "border-top-style" THEN
				declaration.AddTerm(borderStyle.top.specified)
			ELSIF name = "border-right-style" THEN
				declaration.AddTerm(borderStyle.right.specified)
			ELSIF name = "border-bottom-style" THEN
				declaration.AddTerm(borderStyle.bottom.specified)
			ELSIF name = "border-left-style" THEN
				declaration.AddTerm(borderStyle.left.specified)
			ELSIF name = "border-top-width" THEN
				declaration.AddTerm(borderWidth.top.specified)
			ELSIF name = "border-right-width" THEN
				declaration.AddTerm(borderWidth.right.specified)
			ELSIF name = "border-bottom-width" THEN
				declaration.AddTerm(borderWidth.bottom.specified)
			ELSIF name = "border-left-width" THEN
				declaration.AddTerm(borderWidth.left.specified)
			ELSIF name = "border-width" THEN
				declaration.AddTerm(borderWidth.top.specified);
				declaration.AddTerm(borderWidth.right.specified);
				declaration.AddTerm(borderWidth.bottom.specified);
				declaration.AddTerm(borderWidth.left.specified)
			ELSIF name = "bottom" THEN
				declaration.AddTerm(bottom.specified)
			ELSIF name = "caption-side" THEN
				declaration.AddTerm(captionSide.specified)
			ELSIF name = "clear" THEN
				IF clear.left.specified.IsIdent(None) & clear.left.specified.IsIdent(None) THEN
					ChangeToStringIdent(term1, "none")
				ELSIF clear.left.specified.IsIdent(Clear) & clear.left.specified.IsIdent(None) THEN
					ChangeToStringIdent(term1, "left")
				ELSIF clear.left.specified.IsIdent(None) & clear.left.specified.IsIdent(Clear) THEN
					ChangeToStringIdent(term1, "right")
				ELSIF clear.left.specified.IsIdent(Clear) & clear.left.specified.IsIdent(Clear) THEN
					ChangeToStringIdent(term1, "both")
				ELSE
				END;
				declaration.AddTerm(term1)
			ELSIF name = "clip" THEN
(*				declaration.AddTerm(.specified)*)
			ELSIF name = "color" THEN
				declaration.AddTerm(color.specified)
			ELSIF name = "cursor" THEN
			ELSIF name = "direction" THEN
				declaration.AddTerm(direction.specified)
			ELSIF name = "empty-cells" THEN
				declaration.AddTerm(emptyCells.specified)
			ELSIF name = "float" THEN
				declaration.AddTerm(float.specified)
			ELSIF name = "font" THEN
				declaration.AddTerm(font.specified);
				declaration.AddTerm(fontStyle);
				declaration.AddTerm(fontVariant.specified);
				declaration.AddTerm(fontWeight);
				IF fontSize.specified # NIL THEN
					fontSize.specified.SetOperator(CSS2.Slash); declaration.AddTerm(fontSize.specified)
				END;
				declaration.AddTerm(lineHeight.specified);
				declaration.AddTerm(fontFamily)
			ELSIF name = "font-family" THEN
				declaration.AddTerm(fontFamily)
			ELSIF name = "font-size" THEN
				declaration.AddTerm(fontSize.specified)
			ELSIF name = "font-size-adjust" THEN
				declaration.AddTerm(fontSizeAdjust)
			ELSIF name = "font-stretch" THEN
				declaration.AddTerm(fontStretch.specified)
			ELSIF name = "font-style" THEN
				declaration.AddTerm(fontStyle)
			ELSIF name = "font-variant" THEN
				declaration.AddTerm(fontVariant.specified)
			ELSIF name = "font-weight" THEN
				declaration.AddTerm(fontWeight)
			ELSIF name = "height" THEN
				declaration.AddTerm(height.specified)
			ELSIF name = "left" THEN
				declaration.AddTerm(left.specified)
			ELSIF name = "letter-spacing" THEN
				declaration.AddTerm(letterSpacing.specified)
			ELSIF name = "line-height" THEN
				declaration.AddTerm(lineHeight.specified)
			ELSIF name = "list-style" THEN
				declaration.AddTerm(listStyleType.specified);
				declaration.AddTerm(listStylePosition.specified);
				declaration.AddTerm(listStyleImage.specified)
			ELSIF name = "list-style-image" THEN
				declaration.AddTerm(listStyleImage.specified)
			ELSIF name = "list-style-position" THEN
				declaration.AddTerm(listStylePosition.specified)
			ELSIF name = "list-style-type" THEN
				declaration.AddTerm(listStyleType.specified)
			ELSIF name = "margin" THEN
				declaration.AddTerm(margin.top.specified);
				declaration.AddTerm(margin.right.specified);
				declaration.AddTerm(margin.bottom.specified);
				declaration.AddTerm(margin.left.specified)
			ELSIF name = "margin-top" THEN
				declaration.AddTerm(margin.top.specified)
			ELSIF name = "margin-right" THEN
				declaration.AddTerm(margin.right.specified)
			ELSIF name = "margin-bottom" THEN
				declaration.AddTerm(margin.bottom.specified)
			ELSIF name = "margin-left" THEN
				declaration.AddTerm(margin.left.specified)
			ELSIF name = "marker-offset" THEN
				declaration.AddTerm(markerOffset.specified)
			ELSIF name = "max-height" THEN
				declaration.AddTerm(maxHeight.specified)
			ELSIF name = "max-width" THEN
				declaration.AddTerm(maxWidth.specified)
			ELSIF name = "min-height" THEN
				declaration.AddTerm(minHeight.specified)
			ELSIF name = "min-width" THEN
				declaration.AddTerm(minWidth.specified)
			ELSIF name = "outline" THEN
				declaration.AddTerm(outlineColor.specified);
				declaration.AddTerm(outlineStyle.specified);
				declaration.AddTerm(outlineWidth.specified)
			ELSIF name = "outline-color" THEN
				declaration.AddTerm(outlineColor.specified)
			ELSIF name = "outline-style" THEN
				declaration.AddTerm(outlineStyle.specified)
			ELSIF name = "outline-width" THEN
				declaration.AddTerm(outlineWidth.specified)
			ELSIF name = "overflow" THEN
				declaration.AddTerm(overflow.specified)
			ELSIF name = "padding" THEN
				declaration.AddTerm(padding.top.specified);
				declaration.AddTerm(padding.right.specified);
				declaration.AddTerm(padding.bottom.specified);
				declaration.AddTerm(padding.left.specified)
			ELSIF name = "padding-top" THEN
				declaration.AddTerm(padding.top.specified)
			ELSIF name = "padding-right" THEN
				declaration.AddTerm(padding.right.specified)
			ELSIF name = "padding-bottom" THEN
				declaration.AddTerm(padding.bottom.specified)
			ELSIF name = "padding-left" THEN
				declaration.AddTerm(padding.left.specified)
			ELSIF name = "position" THEN
				declaration.AddTerm(position.specified)
			ELSIF name = "quotes" THEN
			ELSIF name = "right" THEN
				declaration.AddTerm(right.specified)
			ELSIF name = "table-layout" THEN
				declaration.AddTerm(tableLayout.specified)
			ELSIF name = "text-align" THEN
				declaration.AddTerm(textAlign.specified)
			ELSIF name = "text-decoration" THEN
			ELSIF name = "text-indent" THEN
				declaration.AddTerm(textIndent.specified)
			ELSIF name = "text-shadow" THEN
			ELSIF name = "text-transform" THEN
				declaration.AddTerm(textTransform.specified)
			ELSIF name = "top" THEN
				declaration.AddTerm(top.specified)
			ELSIF name = "unicode-bidi" THEN
				declaration.AddTerm(unicodeBidi.specified)
			ELSIF name = "vertical-align" THEN
				declaration.AddTerm(verticalAlign.specified)
			ELSIF name = "visibility" THEN
				declaration.AddTerm(visibility.specified)
			ELSIF name = "white-space" THEN
				declaration.AddTerm(whiteSpace.specified)
			ELSIF name = "width" THEN
				declaration.AddTerm(width.specified)
			ELSIF name = "word-spacing" THEN
				declaration.AddTerm(wordSpacing.specified)
			ELSIF name = "z-index" THEN
				declaration.AddTerm(zIndex.specified)
			ELSE
				declaration := GetValue^(name)
			END;
			RETURN declaration
		END GetValue;

		PROCEDURE SetValue(declaration: CSS2.Declaration);
		VAR s: String; terms: XMLObjects.Enumerator; c: ANY;
			term1, term2, term3, term4, term5, term6: CSS2.Term; i: LONGINT; imgTerm: ImgTerm;
		BEGIN
			s := declaration.GetProperty();
			terms := declaration.GetTerms();
			c := terms.GetNext();
			IF c # NIL THEN term1 := c(CSS2.Term) ELSE term1 := NIL END;
			IF terms.HasMoreElements() THEN c := terms.GetNext(); term2 := c(CSS2.Term);
				IF terms.HasMoreElements() THEN c := terms.GetNext(); term3 := c(CSS2.Term);
					IF terms.HasMoreElements() THEN c := terms.GetNext(); term4 := c(CSS2.Term)
					END
				END
			END;
			IF s^ = "background-attachment" THEN
				IF ~SetNil(backgroundAttachment.specified, term1) & ~SetIdentOrInherit(backgroundAttachment.specified, term1) THEN
					IF term1.IsStringIdent("scroll") THEN backgroundAttachment.specified := ChangeToIdent(Scroll)
					ELSIF term1.IsStringIdent("fixed") THEN backgroundAttachment.specified := ChangeToIdent(Fixed)
					END
				END
			ELSIF s^ = "background-color" THEN
				SetColor(backgroundColor.specified, term1, FALSE)
			ELSIF s^ = "background-image" THEN
				IF ~SetNil(backgroundImage.specified, term1) & ~SetIdentOrInherit(backgroundImage.specified, term1)
						& ~SetNone(backgroundImage.specified, term1) THEN
					IF term1.GetType() = CSS2.URI THEN
						s := term1.GetStringVal();
						NEW(imgTerm);  imgTerm.img := WMGraphics.LoadImage(s^, TRUE);
						IF imgTerm.img # NIL THEN
							backgroundImage.specified := imgTerm; declaration.RemoveTerm(term1); declaration.AddTerm(imgTerm)
						END
					ELSIF term1 IS ImgTerm THEN backgroundImage.specified := term1
					END
				END
			ELSIF s^ = "background-position" THEN
				IF ~SetNil(backgroundPosition.horizontal.specified, term1) & ~SetNil(backgroundPosition.vertical.specified, term1)
						& ~SetIdentOrInherit(backgroundPosition.horizontal.specified, term1)
						& ~SetIdentOrInherit(backgroundPosition.vertical.specified, term1) THEN
					IF term2 = NIL THEN
						NEW(term2); term2.SetType(CSS2.Percent); term2.SetRealVal(0.5)
					END;
					IF term1.IsStringIdent("top") OR term1.IsStringIdent("bottom") THEN
						term3 := term1; term1 := term2; term2 := term3	(* swap term1, term2 *)
					END;
					IF backgroundPosition.horizontal.specified = NIL THEN NEW(backgroundPosition.horizontal.specified) END;
					IF term1.IsStringIdent("left") THEN
						backgroundPosition.horizontal.specified.SetType(CSS2.Percent); backgroundPosition.horizontal.specified.SetRealVal(0.0)
					ELSIF term1.IsStringIdent("center") THEN
						backgroundPosition.horizontal.specified.SetType(CSS2.Percent); backgroundPosition.horizontal.specified.SetRealVal(0.5)
					ELSIF term1.IsStringIdent("right") THEN
						backgroundPosition.horizontal.specified.SetType(CSS2.Percent);
						backgroundPosition.horizontal.specified.SetRealVal(1.0)
					ELSIF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN
						backgroundPosition.horizontal.specified := term1
					END;
					IF backgroundPosition.vertical.specified = NIL THEN NEW(backgroundPosition.vertical.specified) END;
					IF term2.IsStringIdent("top") THEN
						backgroundPosition.vertical.specified.SetType(CSS2.Percent); backgroundPosition.vertical.specified.SetRealVal(0.0)
					ELSIF term2.IsStringIdent("center") THEN
						backgroundPosition.vertical.specified.SetType(CSS2.Percent); backgroundPosition.vertical.specified.SetRealVal(0.5)
					ELSIF term2.IsStringIdent("bottom") THEN
						backgroundPosition.vertical.specified.SetType(CSS2.Percent); backgroundPosition.vertical.specified.SetRealVal(1.0)
					ELSIF term2.IsLength() OR (term2.GetType() = CSS2.Percent) THEN
						backgroundPosition.vertical.specified := term2
					END
				END
			ELSIF s^ = "background-repeat" THEN
				IF term1 = NIL THEN
					backgroundRepeat.horizontal.specified := NIL; backgroundRepeat.vertical.specified := NIL
				ELSIF term1.IsStringIdent("inherit") THEN
					backgroundRepeat.horizontal.specified := ChangeToIdent(Inherit);
					backgroundRepeat.vertical.specified := ChangeToIdent(Inherit)
				ELSIF term1.IsStringIdent("repeat") THEN
					backgroundRepeat.horizontal.specified := ChangeToIdent(Repeat);
					backgroundRepeat.vertical.specified := ChangeToIdent(Repeat)
				ELSIF term1.IsStringIdent("repeat-x") THEN
					backgroundRepeat.horizontal.specified := ChangeToIdent(Repeat);
					backgroundRepeat.vertical.specified := ChangeToIdent(NoRepeat)
				ELSIF term1.IsStringIdent("repeat-y") THEN
					backgroundRepeat.horizontal.specified := ChangeToIdent(NoRepeat);
					backgroundRepeat.vertical.specified := ChangeToIdent(Repeat)
				ELSIF term1.IsStringIdent("no-repeat") THEN
					backgroundRepeat.horizontal.specified := ChangeToIdent(NoRepeat);
					backgroundRepeat.vertical.specified := ChangeToIdent(NoRepeat)
				END
			ELSIF s^ = "border" THEN
				IF term1.IsStringIdent("inherit") THEN
					borderWidth.top.specified := ChangeToIdent(Inherit);
					borderWidth.right.specified := ChangeToIdent(Inherit);
					borderWidth.bottom.specified := ChangeToIdent(Inherit);
					borderWidth.left.specified := ChangeToIdent(Inherit);
					borderStyle.top.specified := ChangeToIdent(Inherit);
					borderStyle.right.specified := ChangeToIdent(Inherit);
					borderStyle.bottom.specified := ChangeToIdent(Inherit);
					borderStyle.left.specified := ChangeToIdent(Inherit);
					borderColor.top.specified := ChangeToIdent(Inherit);
					borderColor.right.specified := ChangeToIdent(Inherit);
					borderColor.bottom.specified := ChangeToIdent(Inherit);
					borderColor.left.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderWidth(term1) THEN
						BorderWidth(borderWidth.top.specified, term1);
						BorderWidth(borderWidth.right.specified, term1);
						BorderWidth(borderWidth.bottom.specified, term1);
						BorderWidth(borderWidth.left.specified, term1);
						term1 := term2
					END;
					IF IsBorderStyle(term1) THEN
						BorderStyle(borderStyle.top.specified, term1);
						BorderStyle(borderStyle.right.specified, term1);
						BorderStyle(borderStyle.bottom.specified, term1);
						BorderStyle(borderStyle.left.specified, term1);
						term1 := term2
					END;
					IF (term1 # NIL) THEN
						SetColor(borderColor.top.specified, term1, FALSE);
						SetColor(borderColor.right.specified, term1, FALSE);
						SetColor(borderColor.bottom.specified, term1, FALSE);
						SetColor(borderColor.left.specified, term1, FALSE)
					ELSE
						borderColor.top.specified := color.specified;
						borderColor.right.specified := color.specified;
						borderColor.bottom.specified := color.specified;
						borderColor.left.specified := color.specified
					END
				END
			ELSIF s^ = "border-collapse" THEN
				IF ~SetNil(borderCollapse.specified, term1) & ~SetIdentOrInherit(borderCollapse.specified, term1) THEN
					IF term1.IsStringIdent("collapse") THEN borderCollapse.specified := ChangeToIdent(Collapse)
					ELSIF term1.IsStringIdent("separate") THEN borderCollapse.specified := ChangeToIdent(Separate)
					END
				END
			ELSIF s^ = "border-color" THEN
				SetColor(borderColor.top.specified, term1, FALSE);
				IF term2 # NIL THEN
					SetColor(borderColor.right.specified, term2, FALSE);
					IF term3 # NIL THEN
						SetColor(borderColor.bottom.specified, term3, FALSE);
						IF term4 # NIL THEN
							SetColor(borderColor.left.specified, term4, FALSE)
						ELSE
							SetColor(borderColor.left.specified, term2, FALSE)
						END
					ELSE
						SetColor(borderColor.bottom.specified, term1, FALSE);
						SetColor(borderColor.left.specified, term2, FALSE)
					END
				ELSE
					SetColor(borderColor.right.specified, term1, FALSE);
					SetColor(borderColor.bottom.specified, term1, FALSE);
					SetColor(borderColor.left.specified, term1, FALSE)
				END
			ELSIF s^ = "border-spacing" THEN
				IF term1 = NIL THEN
					borderSpacing.horizontal.specified := NIL; borderSpacing.vertical.specified := NIL
				ELSIF term1.IsStringIdent("inherit") THEN
					borderSpacing.horizontal.specified := ChangeToIdent(Inherit);
					borderSpacing.vertical.specified := ChangeToIdent(Inherit)
				ELSE
					IF term1.IsLength() THEN
						borderSpacing.horizontal.specified := term1;
						IF term2 = NIL THEN term2 := term1 END;
						IF term2.IsLength() THEN
							borderSpacing.vertical.specified := term2
						END
					END
				END
			ELSIF s^ = "border-style" THEN
				BorderStyle(borderStyle.top.specified, term1);
				IF term2 # NIL THEN
					BorderStyle(borderStyle.right.specified, term2);
					IF term3 # NIL THEN
						BorderStyle(borderStyle.bottom.specified, term3);
						IF term4 # NIL THEN
							BorderStyle(borderStyle.left.specified, term4)
						ELSE
							BorderStyle(borderStyle.left.specified, term2)
						END
					ELSE
						BorderStyle(borderStyle.bottom.specified, term1);
						BorderStyle(borderStyle.left.specified, term2)
					END
				ELSE
					BorderStyle(borderStyle.right.specified, term1);
					BorderStyle(borderStyle.bottom.specified, term1);
					BorderStyle(borderStyle.left.specified, term1)
				END
			ELSIF s^ = "border-top" THEN
				IF term1.IsStringIdent("inherit") THEN
					borderWidth.top.specified := ChangeToIdent(Inherit);
					borderStyle.top.specified := ChangeToIdent(Inherit);
					borderColor.top.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderWidth(term1) THEN
						BorderWidth(borderWidth.top.specified, term1);
						term1 := term2
					END;
					IF IsBorderStyle(term1) THEN
						BorderStyle(borderStyle.top.specified, term1);
						term1 := term2
					END;
					IF (term1 # NIL) THEN
						SetColor(borderColor.top.specified, term1, FALSE)
					ELSE
						borderColor.top.specified := color.specified
					END
				END
			ELSIF s^ = "border-right" THEN
				IF term1.IsStringIdent("inherit") THEN
					borderWidth.right.specified := ChangeToIdent(Inherit);
					borderStyle.right.specified := ChangeToIdent(Inherit);
					borderColor.right.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderWidth(term1) THEN
						BorderWidth(borderWidth.right.specified, term1);
						term1 := term2
					END;
					IF IsBorderWidth(term1) THEN
						BorderStyle(borderStyle.right.specified, term1);
						term1 := term2
					END;
					IF (term1 # NIL) THEN
						SetColor(borderColor.right.specified, term1, FALSE)
					ELSE
						borderColor.right.specified := color.specified
					END
				END
			ELSIF s^ = "border-bottom" THEN
				IF term1.IsStringIdent("inherit") THEN
					borderWidth.bottom.specified := ChangeToIdent(Inherit);
					borderStyle.bottom.specified := ChangeToIdent(Inherit);
					borderColor.bottom.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderWidth(term1) THEN
						BorderWidth(borderWidth.bottom.specified, term1);
						term1 := term2
					END;
					IF IsBorderWidth(term1) THEN
						BorderStyle(borderStyle.bottom.specified, term1);
						term1 := term2
					END;
					IF (term1 # NIL) THEN
						SetColor(borderColor.bottom.specified, term1, FALSE)
					ELSE
						borderColor.bottom.specified := color.specified
					END
				END
			ELSIF s^ = "border-left" THEN
				IF term1.IsStringIdent("inherit") THEN
					borderWidth.left.specified := ChangeToIdent(Inherit);
					borderStyle.left.specified := ChangeToIdent(Inherit);
					borderColor.left.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderWidth(term1) THEN
						BorderWidth(borderWidth.left.specified, term1);
						term1 := term2
					END;
					IF IsBorderWidth(term1) THEN
						BorderStyle(borderStyle.left.specified, term1);
						term1 := term2
					END;
					IF (term1 # NIL) THEN
						SetColor(borderColor.left.specified, term1, FALSE)
					ELSE
						borderColor.left.specified := color.specified
					END
				END
			ELSIF s^ = "border-top-color" THEN
				SetColor(borderColor.top.specified, term1, FALSE)
			ELSIF s^ = "border-right-color" THEN
				SetColor(borderColor.right.specified, term1, FALSE)
			ELSIF s^ = "border-bottom-color" THEN
				SetColor(borderColor.bottom.specified, term1, FALSE)
			ELSIF s^ = "border-left-color" THEN
				SetColor(borderColor.left.specified, term1, FALSE)
			ELSIF s^ = "border-top-style" THEN
				BorderStyle(borderStyle.top.specified, term1)
			ELSIF s^ = "border-right-style" THEN
				BorderStyle(borderStyle.right.specified, term1)
			ELSIF s^ = "border-bottom-style" THEN
				BorderStyle(borderStyle.bottom.specified, term1)
			ELSIF s^ = "border-left-style" THEN
				BorderStyle(borderStyle.left.specified, term1)
			ELSIF s^ = "border-top-width" THEN
				BorderWidth(borderWidth.top.specified, term1)
			ELSIF s^ = "border-right-width" THEN
				BorderWidth(borderWidth.right.specified, term1)
			ELSIF s^ = "border-bottom-width" THEN
				BorderWidth(borderWidth.bottom.specified, term1)
			ELSIF s^ = "border-left-width" THEN
				BorderWidth(borderWidth.left.specified, term1)
			ELSIF s^ = "border-width" THEN
				BorderWidth(borderWidth.top.specified, term1);
				IF term2 # NIL THEN
					BorderWidth(borderWidth.right.specified, term2);
					IF term3 # NIL THEN
						BorderWidth(borderWidth.bottom.specified, term3);
						IF term4 # NIL THEN
							BorderWidth(borderWidth.left.specified, term4)
						ELSE
							BorderWidth(borderWidth.left.specified, term2)
						END
					ELSE
						BorderWidth(borderWidth.bottom.specified, term1);
						BorderWidth(borderWidth.left.specified, term2)
					END
				ELSE
					BorderWidth(borderWidth.right.specified, term1);
					BorderWidth(borderWidth.bottom.specified, term1);
					BorderWidth(borderWidth.left.specified, term1)
				END
			ELSIF s^ = "bottom" THEN
				BoxOffset(bottom.specified, term1)
			ELSIF s^ = "caption-side" THEN
				IF ~SetNil(captionSide.specified, term1) & ~SetIdentOrInherit(captionSide.specified, term1) THEN
					IF term1.IsStringIdent("top") THEN captionSide.specified := ChangeToIdent(Top)
					ELSIF term1.IsStringIdent("bottom") THEN captionSide.specified := ChangeToIdent(Bottom)
					ELSIF term1.IsStringIdent("left") THEN captionSide.specified := ChangeToIdent(Left)
					ELSIF term1.IsStringIdent("right") THEN captionSide.specified := ChangeToIdent(Right)
					END
				END
			ELSIF s^ = "clear" THEN
				IF term1 = NIL THEN
					clear.left.specified := NIL; clear.right.specified := NIL
				ELSIF term1.IsStringIdent("inherit") THEN
					clear.left.specified := ChangeToIdent(Inherit); clear.right.specified := ChangeToIdent(Inherit)
				ELSIF term1.IsStringIdent("none") THEN
					clear.left.specified := ChangeToIdent(None); clear.right.specified := ChangeToIdent(None)
				ELSIF term1.IsStringIdent("left") THEN
					clear.left.specified := ChangeToIdent(Clear); clear.right.specified := ChangeToIdent(None)
				ELSIF term1.IsStringIdent("right") THEN
					clear.left.specified := ChangeToIdent(None); clear.right.specified := ChangeToIdent(Clear)
				ELSIF term1.IsStringIdent("both") THEN
					clear.left.specified := ChangeToIdent(Clear); clear.right.specified := ChangeToIdent(Clear)
				END
			ELSIF s^ = "clip" THEN
				IF term1 = NIL THEN
					clip.top.specified := NIL; clip.right.specified := NIL; clip.bottom.specified := NIL; clip.left.specified := NIL
				ELSIF term1.IsStringIdent("inherit") THEN
					clip.top.specified := ChangeToIdent(Inherit); clip.right.specified := ChangeToIdent(Inherit);
					clip.bottom.specified := ChangeToIdent(Inherit); clip.left.specified := ChangeToIdent(Inherit)
				ELSIF term1.IsStringIdent("auto") THEN
					clip.top.specified := ChangeToPixel(0.0); clip.right.specified := ChangeToPixel(0.0);
					clip.bottom.specified := ChangeToPixel(0.0); clip.left.specified := ChangeToPixel(0.0)
				ELSIF term1.GetType() = CSS2.Function THEN
					s := term1.GetStringVal();
					IF s^ = "rect" THEN
						terms := term1.GetTerms();
						IF terms.HasMoreElements() THEN c := terms.GetNext(); term1 := c(CSS2.Term);
							IF terms.HasMoreElements() THEN c := terms.GetNext(); term2 := c(CSS2.Term);
								IF terms.HasMoreElements() THEN c := terms.GetNext(); term3 := c(CSS2.Term);
									IF terms.HasMoreElements() THEN c := terms.GetNext(); term4 := c(CSS2.Term);
										IF term1.IsStringIdent("auto") THEN clip.top.specified := ChangeToPixel(0.0)
										ELSIF term1.IsLength() THEN clip.top.specified := term1
										END;
										IF term2.IsStringIdent("auto") THEN clip.right.specified := ChangeToPixel(0.0)
										ELSIF term2.IsLength() THEN clip.right.specified := term2
										END;
										IF term3.IsStringIdent("auto") THEN clip.bottom.specified := ChangeToPixel(0.0)
										ELSIF term3.IsLength() THEN clip.bottom.specified := term3
										END;
										IF term4.IsStringIdent("auto") THEN clip.left.specified := ChangeToPixel(0.0)
										ELSIF term4.IsLength() THEN clip.left.specified := term4
										END
									END
								END
							END
						END
					END
				END
			ELSIF s^ = "color" THEN
				SetColor(color.specified, term1, FALSE)
			ELSIF s^ = "cursor" THEN
				IF ~SetNilCollection(cursor.specified, term1) & ~SetIdentOrInheritCollection(cursor.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Auto)
					ELSIF term1.IsStringIdent("crosshair") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Crosshair)
					ELSIF term1.IsStringIdent("default") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Default)
					ELSIF term1.IsStringIdent("pointer") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Pointer)
					ELSIF term1.IsStringIdent("move") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Move)
					ELSIF term1.IsStringIdent("e-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, EResize)
					ELSIF term1.IsStringIdent("ne-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, NEResize)
					ELSIF term1.IsStringIdent("nw-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, NWResize)
					ELSIF term1.IsStringIdent("n-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, NResize)
					ELSIF term1.IsStringIdent("se-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, SEResize)
					ELSIF term1.IsStringIdent("sw-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, SWResize)
					ELSIF term1.IsStringIdent("s-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, SResize)
					ELSIF term1.IsStringIdent("w-resize") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, WResize)
					ELSIF term1.IsStringIdent("text") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Text)
					ELSIF term1.IsStringIdent("wait") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Wait )
					ELSIF term1.IsStringIdent("help") THEN cursor.specified := NIL; ChangeToIdentCollection(cursor.specified, Help)
					ELSIF term1.GetType() = CSS2.URI THEN
						terms := declaration.GetTerms();
						WHILE terms.HasMoreElements() DO
							c := terms.GetNext();
							IF c(CSS2.Term).GetIntVal() = CSS2.URI THEN cursor.specified.Add(c) END
						END
					END
				END
			ELSIF s^ = "direction" THEN
				IF ~SetNil(direction.specified, term1) & ~SetIdentOrInherit(direction.specified, term1) THEN
					IF term1.IsStringIdent("ltr") THEN direction.specified := ChangeToIdent(Ltr)
					ELSIF term1.IsStringIdent("rtl") THEN direction.specified := ChangeToIdent(Rtl)
					END
				END
			ELSIF s^ = "empty-cells" THEN
				IF ~SetNil(emptyCells.specified, term1) & ~SetIdentOrInherit(emptyCells.specified, term1) THEN
					IF term1.IsStringIdent("show") THEN emptyCells.specified := ChangeToIdent(Show)
					ELSIF term1.IsStringIdent("hide") THEN emptyCells.specified := ChangeToIdent(Hide)
					END
				END
			ELSIF s^ = "float" THEN
				IF ~SetNil(float.specified, term1) & ~SetIdentOrInherit(float.specified, term1) & ~SetNone(float.specified, term1) THEN
					IF term1.IsStringIdent("left") THEN float.specified := ChangeToIdent(Left)
					ELSIF term1.IsStringIdent("right") THEN float.specified := ChangeToIdent(Right)
					END
				END
			ELSIF s^ = "font" THEN
				IF ~SetNil(font.specified, term1) & ~SetIdentOrInherit(font.specified, term1) THEN
					IF term1.IsStringIdent("caption") THEN font.specified := ChangeToIdent(Caption)
					ELSIF term1.IsStringIdent("icon") THEN font.specified := ChangeToIdent(Icon)
					ELSIF term1.IsStringIdent("menu") THEN font.specified := ChangeToIdent(Menu)
					ELSIF term1.IsStringIdent("message-box") THEN font.specified := ChangeToIdent(MessageBox)
					ELSIF term1.IsStringIdent("small-caption") THEN font.specified := ChangeToIdent(SmallCaption)
					ELSIF term1.IsStringIdent("status-bar") THEN font.specified := ChangeToIdent(StatusBar)
					ELSE
					END
				END
			ELSIF s^ = "font-family" THEN
				IF ~SetNil(fontFamily, term1) & ~SetIdentOrInherit(fontFamily, term1) THEN
					fontFamily := term1
				END
			ELSIF s^ = "font-size" THEN
				IF ~SetNil(fontSize.specified, term1) & ~SetIdentOrInherit(fontSize.specified, term1) THEN
					IF term1.GetType() = CSS2.StringIdent THEN
						NEW(fontSize.specified); fontSize.specified.SetType(CSS2.IntDimension); fontSize.specified.SetUnit(CSS2.pt);
						IF term1.IsStringIdent("xx-small") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[XXSmall])
						ELSIF term1.IsStringIdent("x-small") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[XSmall])
						ELSIF term1.IsStringIdent("small") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[Small])
						ELSIF term1.IsStringIdent("medium") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[Medium])
						ELSIF term1.IsStringIdent("large") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[Large])
						ELSIF term1.IsStringIdent("x-large") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[XLarge])
						ELSIF term1.IsStringIdent("xx-large") THEN fontSize.specified.SetIntVal(AbsoluteFontSizes[XXLarge])
						ELSIF term1.IsStringIdent("larger") THEN fontSize.specified := ChangeToIdent(Larger)
						ELSIF term1.IsStringIdent("smaller") THEN fontSize.specified := ChangeToIdent(Smaller)
						END
					ELSIF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN fontSize.specified := term1
					END
				END
			ELSIF s^ = "font-size-adjust" THEN
				IF ~SetIdentOrInherit(fontSizeAdjust, term1) & ~SetNone(fontSizeAdjust, term1) THEN
					IF term1.GetType() IN {CSS2.IntNumber, CSS2.RealNumber} THEN fontSizeAdjust := term1
					END
				END
			ELSIF s^ = "font-stretch" THEN
				IF ~SetNil(fontStretch.specified, term1) & ~SetIdentOrInherit(fontStretch.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN fontStretch.specified := ChangeToIdent(Normal)
					ELSIF term1.IsStringIdent("wider") THEN fontStretch.specified := ChangeToIdent(Wider)
					ELSIF term1.IsStringIdent("narrower") THEN fontStretch.specified := ChangeToIdent(Narrower)
					ELSIF term1.IsStringIdent("ultra-condensed") THEN fontStretch.specified := ChangeToIdent(UltraCondensed)
					ELSIF term1.IsStringIdent("extra-condensed") THEN fontStretch.specified := ChangeToIdent(ExtraCondensed)
					ELSIF term1.IsStringIdent("condensed") THEN fontStretch.specified := ChangeToIdent(Condensed)
					ELSIF term1.IsStringIdent("semi-condensed") THEN fontStretch.specified := ChangeToIdent(SemiCondensed)
					ELSIF term1.IsStringIdent("semi-expanded") THEN fontStretch.specified := ChangeToIdent(SemiExpanded)
					ELSIF term1.IsStringIdent("expanded") THEN fontStretch.specified := ChangeToIdent(Expanded)
					ELSIF term1.IsStringIdent("extra-expanded") THEN fontStretch.specified := ChangeToIdent(ExtraExpanded)
					ELSIF term1.IsStringIdent("ultra-expanded") THEN fontStretch.specified := ChangeToIdent(UltraExpanded)
					END
				END
			ELSIF s^ = "font-style" THEN
				IF ~SetNil(fontStyle, term1) & ~SetIdentOrInherit(fontStyle, term1) THEN
					IF term1.IsStringIdent("normal") THEN fontStyle := ChangeToIdent(Normal)
					ELSIF term1.IsStringIdent("italic") THEN fontStyle := ChangeToIdent(Italic)
					ELSIF term1.IsStringIdent("oblique") THEN fontStyle := ChangeToIdent(Oblique)
					END
				END
			ELSIF s^ = "font-variant" THEN
				IF ~SetNil(fontVariant.specified, term1) & ~SetIdentOrInherit(fontVariant.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN fontVariant.specified := ChangeToIdent(Normal)
					ELSIF term1.IsStringIdent("small-caps") THEN fontVariant.specified := ChangeToIdent(SmallCaps)
					END
				END
			ELSIF s^ = "font-weight" THEN
				IF ~SetNil(fontWeight, term1) & ~SetIdentOrInherit(fontWeight, term1) THEN
					IF term1.IsStringIdent("normal") THEN
						NEW(fontWeight); fontWeight.SetType(CSS2.IntNumber); fontWeight.SetIntVal(400);
					ELSIF term1.IsStringIdent("bold") THEN
						NEW(fontWeight); fontWeight.SetType(CSS2.IntNumber); fontWeight.SetIntVal(700);
					ELSIF term1.IsStringIdent("bolder") THEN fontWeight := ChangeToIdent(Bolder)
					ELSIF term1.IsStringIdent("lighter") THEN fontWeight := ChangeToIdent(Lighter)
					ELSIF term1.GetType() = CSS2.IntNumber THEN
						i := term1.GetIntVal();
						IF (i = 100) OR (i = 200) OR (i = 300) OR (i = 400) OR (i = 500)
								OR (i = 600) OR (i = 700) OR (i = 800) OR (i = 900) THEN
							fontWeight := term1
						END
					END
				END
			ELSIF s^ = "height" THEN
				IF ~SetNil(height.specified, term1) & ~SetIdentOrInherit(height.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN height.specified := ChangeToIdent(Auto)
					ELSIF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN
						height.specified := term1
					END
				END
			ELSIF s^ = "left" THEN
				BoxOffset(left.specified, term1)
			ELSIF s^ = "letter-spacing" THEN
				IF ~SetNil(letterSpacing.specified, term1) & ~SetIdentOrInherit(letterSpacing.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN letterSpacing.specified := ChangeToPixel(0.0)
					ELSIF term1.IsLength() THEN letterSpacing.specified := term1
					END
				END
			ELSIF s^ = "line-height" THEN
				IF ~SetNil(lineHeight.specified, term1) & ~SetIdentOrInherit(lineHeight.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN lineHeight.specified := ChangeToIdent(Normal)
					ELSIF term1.IsLength() OR (term1.GetType() IN {CSS2.IntNumber, CSS2.RealNumber})
							OR (term1.GetType() = CSS2.Percent) THEN
						lineHeight.specified := term1
					END
				END
			ELSIF s^ = "list-style" THEN
				IF term1.IsStringIdent("inherit") THEN
					listStyleImage.specified := ChangeToIdent(Inherit);
					listStylePosition.specified := ChangeToIdent(Inherit);
					listStyleType.specified := ChangeToIdent(Inherit)
				ELSIF term1.IsStringIdent("none") THEN
					listStyleImage.specified := NIL;
					listStyleType.specified := NIL
				ELSE
					IF term1.GetType() = CSS2.URI THEN
						term4 := term1
					ELSIF term1.IsStringIdent("inside") OR term1.IsStringIdent("outside") THEN
						term5 := term1
					ELSE
						term6 := term1
					END;
					IF term2 # NIL THEN
						IF (term2.GetType() = CSS2.URI) & (term4 = NIL) THEN
							term4 := term2
						ELSIF (term2.IsStringIdent("inside") OR term2.IsStringIdent("outside")) & (term5 = NIL) THEN
							term5 := term2
						ELSIF term6 = NIL THEN
							term6 := term2
						END;
						IF term3 # NIL THEN
							IF (term3.GetType() = CSS2.URI) & (term4 = NIL) THEN
								term4 := term3
							ELSIF (term3.IsStringIdent("inside") OR term3.IsStringIdent("outside")) & (term5 = NIL) THEN
								term5 := term3
							ELSIF term6 = NIL THEN
								term6 := term3
							END
						END
					END;
					IF term4 # NIL THEN ListStyleImage(listStyleImage.specified, term4) END;
					IF term5 # NIL THEN ListStylePosition(listStylePosition.specified, term5) END;
					IF term6 # NIL THEN ListStyleType(listStyleType.specified, term6) END
				END
			ELSIF s^ = "list-style-image" THEN
				ListStyleImage(listStyleImage.specified, term1)
			ELSIF s^ = "list-style-position" THEN
				ListStylePosition(listStylePosition.specified, term1)
			ELSIF s^ = "list-style-type" THEN
				ListStyleType(listStyleType.specified, term1)
			ELSIF s^ = "margin" THEN
				MarginWidth(margin.top.specified, term1);
				IF term2 # NIL THEN
					MarginWidth(margin.right.specified, term2);
					MarginWidth(margin.left.specified, term2);
					IF term3 # NIL THEN
						MarginWidth(margin.bottom.specified, term3);
						IF term4 # NIL THEN
							MarginWidth(margin.left.specified, term4)
						ELSE
							MarginWidth(margin.left.specified, term2)
						END
					ELSE
						MarginWidth(margin.bottom.specified, term1)
					END
				ELSE
					MarginWidth(margin.right.specified, term1);
					MarginWidth(margin.bottom.specified, term1);
					MarginWidth(margin.left.specified, term1)
				END
			ELSIF s^ = "margin-top" THEN
				MarginWidth(margin.top.specified, term1)
			ELSIF s^ = "margin-right" THEN
				MarginWidth(margin.right.specified, term1)
			ELSIF s^ = "margin-bottom" THEN
				MarginWidth(margin.bottom.specified, term1)
			ELSIF s^ = "margin-left" THEN
				MarginWidth(margin.left.specified, term1)
			ELSIF s^ = "marker-offset" THEN
				IF ~SetNil(markerOffset.specified, term1) & ~SetIdentOrInherit(markerOffset.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN markerOffset.specified := ChangeToPixel(0.0)
					ELSIF term1.IsLength() THEN markerOffset.specified := term1
					END
				END
			ELSIF s^ = "marks" THEN	(* not implemented *)
			ELSIF s^ = "max-height" THEN
				MaxDimension(maxHeight.specified, term1)
			ELSIF s^ = "max-width" THEN
				MaxDimension(maxWidth.specified, term1)
			ELSIF s^ = "min-height" THEN
				MinDimension(minHeight.specified, term1)
			ELSIF s^ = "min-width" THEN
				MinDimension(minWidth.specified, term1)
			ELSIF s^ = "outline" THEN
				IF term1.IsStringIdent("inherit") THEN
					outlineColor.specified := ChangeToIdent(Inherit);
					outlineStyle.specified := ChangeToIdent(Inherit);
					outlineWidth.specified := ChangeToIdent(Inherit)
				ELSE
					IF IsBorderStyle(term1) THEN term5 := term1
					ELSIF IsBorderWidth(term1) THEN term6 := term1
					ELSE term4 := term1
					END;
					IF term2 # NIL THEN
						IF IsBorderStyle(term2) & (term5 = NIL) THEN term5 := term2
						ELSIF IsBorderWidth(term2) & (term6 = NIL) THEN term6 := term2
						ELSIF term4 = NIL THEN term4 := term2
						END;
						IF term3 # NIL THEN
							IF IsBorderStyle(term3) & (term5 = NIL) THEN term5 := term3
							ELSIF IsBorderWidth(term3) & (term6 = NIL) THEN term6 := term3
							ELSIF term4 = NIL THEN term4 := term3
							END
						END
					END;
					IF term4 # NIL THEN
						IF term4.IsStringIdent("invert") THEN SetColor(outlineColor.specified, term4, TRUE)
						END
					END;
					IF term5 # NIL THEN BorderStyle(outlineStyle.specified, term5) END;
					IF term6 # NIL THEN BorderWidth(outlineWidth.specified, term6) END
				END
			ELSIF s^ = "outline-color" THEN
				SetColor(outlineColor.specified, term1, TRUE)
			ELSIF s^ = "outline-style" THEN
				IF (term1 # NIL) & term1.IsStringIdent("hidden") THEN
					outlineStyle.specified := ChangeToIdent(Hidden)
				ELSE
					BorderStyle(outlineStyle.specified, term1)
				END
			ELSIF s^ = "outline-width" THEN
				BorderWidth(outlineWidth.specified, term1)
			ELSIF s^ = "overflow" THEN
				IF ~SetNil(overflow.specified, term1) & ~SetIdentOrInherit(overflow.specified, term1) THEN
					IF term1.IsStringIdent("visible") THEN overflow.specified := ChangeToIdent(Visible)
					ELSIF term1.IsStringIdent("hidden") THEN overflow.specified := ChangeToIdent(Hidden)
					ELSIF term1.IsStringIdent("scroll") THEN overflow.specified := ChangeToIdent(Scroll)
					ELSIF term1.IsStringIdent("auto") THEN overflow.specified := ChangeToIdent(Auto)
					END
				END
			ELSIF s^ = "padding" THEN
				PaddingWidth(padding.top.specified, term1);
				IF term2 # NIL THEN
					PaddingWidth(padding.right.specified, term2);
					PaddingWidth(padding.left.specified, term2);
					IF term3 # NIL THEN
						PaddingWidth(padding.bottom.specified, term3);
						IF term4 # NIL THEN
							PaddingWidth(padding.left.specified, term4)
						ELSE
							PaddingWidth(padding.left.specified, term2)
						END
					ELSE
						PaddingWidth(padding.bottom.specified, term1)
					END
				ELSE
					PaddingWidth(padding.right.specified, term1);
					PaddingWidth(padding.bottom.specified, term1);
					PaddingWidth(padding.left.specified, term1)
				END
			ELSIF s^ = "padding-top" THEN
				PaddingWidth(padding.top.specified, term1)
			ELSIF s^ = "padding-right" THEN
				PaddingWidth(padding.right.specified, term1)
			ELSIF s^ = "padding-bottom" THEN
				PaddingWidth(padding.bottom.specified, term1)
			ELSIF s^ = "padding-left" THEN
				PaddingWidth(padding.left.specified, term1)
			ELSIF s^ = "position" THEN
				IF ~SetNil(position.specified, term1) & ~SetIdentOrInherit(position.specified, term1) THEN
					IF term1.IsStringIdent("static") THEN position.specified := ChangeToIdent(Static)
					ELSIF term1.IsStringIdent("relative") THEN position.specified := ChangeToIdent(Relative)
					ELSIF term1.IsStringIdent("absolute") THEN position.specified := ChangeToIdent(Absolute)
					ELSIF term1.IsStringIdent("fixed") THEN position.specified := ChangeToIdent(Fixed)
					END
				END
			ELSIF s^ = "quotes" THEN

			ELSIF s^ = "right" THEN
				BoxOffset(right.specified, term1)
			ELSIF s^ = "table-layout" THEN
				IF ~SetNil(tableLayout.specified, term1) & ~SetIdentOrInherit(tableLayout.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN tableLayout.specified := ChangeToIdent(Auto)
					ELSIF term1.IsStringIdent("fixed") THEN tableLayout.specified := ChangeToIdent(Fixed)
					END
				END
			ELSIF s^ = "text-align" THEN
				IF ~SetNil(textAlign.specified, term1) & ~SetIdentOrInherit(textAlign.specified, term1) THEN
					IF term1.IsStringIdent("left") THEN textAlign.specified := ChangeToIdent(Left)
					ELSIF term1.IsStringIdent("right") THEN textAlign.specified := ChangeToIdent(Right)
					ELSIF term1.IsStringIdent("center") THEN textAlign.specified := ChangeToIdent(Center)
					ELSIF term1.IsStringIdent("justify") THEN textAlign.specified := ChangeToIdent(Justify)
					ELSIF term1.GetType() = CSS2.StringVal THEN textAlign.specified := term1
					END
				END
			ELSIF s^ = "text-decoration" THEN
				IF ~SetNil(textDecoration.specified, term1) & ~SetIdentOrInherit(textDecoration.specified, term1)
						& ~SetNone(textDecoration.specified, term1) THEN
				END
			ELSIF s^ = "text-indent" THEN
				IF ~SetNil(textIndent.specified, term1) & ~SetIdentOrInherit(textIndent.specified, term1) THEN
					IF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN
						textIndent.specified := term1
					END
				END
			ELSIF s^ = "text-shadow" THEN

			ELSIF s^ = "text-transform" THEN
				IF ~SetNil(textTransform.specified, term1) & ~SetIdentOrInherit(textTransform.specified, term1) THEN
					IF term1.IsStringIdent("capitalize") THEN textTransform.specified := ChangeToIdent(Capitalize)
					ELSIF term1.IsStringIdent("uppercase") THEN textTransform.specified := ChangeToIdent(Uppercase)
					ELSIF term1.IsStringIdent("lowercase") THEN textTransform.specified := ChangeToIdent(Lowercase)
					END
				END
			ELSIF s^ = "top" THEN
				BoxOffset(top.specified, term1)
			ELSIF s^ = "unicode-bidi" THEN
				IF ~SetNil(unicodeBidi.specified, term1) & ~SetIdentOrInherit(unicodeBidi.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN unicodeBidi.specified := ChangeToIdent(Normal)
					ELSIF term1.IsStringIdent("embed") THEN unicodeBidi.specified := ChangeToIdent(Embed)
					ELSIF term1.IsStringIdent("bidi-override") THEN unicodeBidi.specified := ChangeToIdent(BidiOverride)
					END
				END
			ELSIF s^ = "vertical-align" THEN
				IF ~SetNil(verticalAlign.specified, term1) & ~SetIdentOrInherit(verticalAlign.specified, term1) THEN
					IF term1.IsStringIdent("baseline") THEN verticalAlign.specified := ChangeToIdent(Baseline)
					ELSIF term1.IsStringIdent("sub") THEN verticalAlign.specified := ChangeToIdent(Sub)
					ELSIF term1.IsStringIdent("super") THEN verticalAlign.specified := ChangeToIdent(Super)
					ELSIF term1.IsStringIdent("top") THEN verticalAlign.specified := ChangeToIdent(Top)
					ELSIF term1.IsStringIdent("text-top") THEN verticalAlign.specified := ChangeToIdent(TextTop)
					ELSIF term1.IsStringIdent("middle") THEN verticalAlign.specified := ChangeToIdent(Middle)
					ELSIF term1.IsStringIdent("bottom") THEN verticalAlign.specified := ChangeToIdent(Bottom)
					ELSIF term1.IsStringIdent("text-bottom") THEN verticalAlign.specified := ChangeToIdent(TextBottom)
					ELSIF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN
						verticalAlign.specified := term1
					END
				END
			ELSIF s^ = "visibility" THEN
				IF ~SetNil(visibility.specified, term1) & ~SetIdentOrInherit(visibility.specified, term1) THEN
					IF term1.IsStringIdent("visible") THEN visibility.specified := ChangeToIdent(Visible); dimensionChanged := TRUE
					ELSIF term1.IsStringIdent("hidden") THEN visibility.specified := ChangeToIdent(Hidden); dimensionChanged := TRUE
					ELSIF term1.IsStringIdent("collapse") THEN visibility.specified := ChangeToIdent(Collapse); dimensionChanged := TRUE
					END
				END
			ELSIF s^ = "white-space" THEN
				IF ~SetNil(whiteSpace.specified, term1) & ~SetIdentOrInherit(whiteSpace.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN whiteSpace.specified := ChangeToIdent(Normal)
					ELSIF term1.IsStringIdent("pre") THEN whiteSpace.specified := ChangeToIdent(Pre)
					ELSIF term1.IsStringIdent("nowrap") THEN whiteSpace.specified := ChangeToIdent(Nowrap)
					END
				END
			ELSIF s^ = "width" THEN
				IF ~SetNil(width.specified, term1) & ~SetIdentOrInherit(width.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN width.specified := ChangeToIdent(Auto)
					ELSIF term1.IsLength() OR (term1.GetType() = CSS2.Percent) THEN
						width.specified := term1
					END
				END
			ELSIF s^ = "word-spacing" THEN
				IF ~SetNil(wordSpacing.specified, term1) & ~SetIdentOrInherit(wordSpacing.specified, term1) THEN
					IF term1.IsStringIdent("normal") THEN wordSpacing.specified := ChangeToPixel(0.0)
					ELSIF term1.IsLength() THEN wordSpacing.specified := term1
					END
				END
			ELSIF s^ = "z-index" THEN
				IF ~SetNil(zIndex.specified, term1) & ~SetIdentOrInherit(zIndex.specified, term1) THEN
					IF term1.IsStringIdent("auto") THEN zIndex.specified := ChangeToIdent(Auto)
					ELSIF term1.GetType() = CSS2.IntNumber THEN zIndex.specified := term1
					END
				END
			ELSE
				SetValue^(declaration)
			END
		END SetValue;

		PROCEDURE Initialize;
		BEGIN
			Initialize^();
			backgroundAttachment.computed := TRUE;
			IF parent # SELF THEN
				WITH parent: VisualProperties DO
					color.computed := parent.color.computed;
					borderCollapse.computed := parent.borderCollapse.computed;
					borderSpacing.horizontal.computed := parent.borderSpacing.horizontal.computed;
					borderSpacing.vertical.computed := parent.borderSpacing.vertical.computed;
					captionSide.computed := parent.captionSide.computed;
					cursor.computed := parent.cursor.computed;
					direction.computed := parent.direction.computed;
					emptyCells.computed := parent.emptyCells.computed;
					font.computed := parent.font.computed;
					fontSize.computed := parent.fontSize.computed;
					fontStretch.computed := parent.fontStretch.computed;
					fontVariant.computed := parent.fontVariant.computed;
					letterSpacing.computed := parent.letterSpacing.computed;
					wordSpacing.computed := parent.wordSpacing.computed;
					lineHeight.computed := parent.lineHeight.computed;
					listStyleImage.computed := parent.listStyleImage.computed;
					listStylePosition.computed := parent.listStylePosition.computed;
					listStyleType.computed := parent.listStyleType.computed;
					(* quotes.computed := parent.quotes.computed;	*)
					textAlign.computed := parent.textAlign.computed;
					textIndent.computed := parent.textIndent.computed;
					textTransform.computed := parent.textTransform.computed;
					whiteSpace.computed := parent.whiteSpace.computed
				END
			ELSE
				CSS2.IntToRGBA(defaultColor, color.computed.r, color.computed.g, color.computed.b, color.computed.a);
				borderCollapse.computed := TRUE;
				borderSpacing.horizontal.computed := 0.0; borderSpacing.vertical.computed := 0.0;
				captionSide.computed := Top;
				cursor.computed := defaultCursor;
				direction.computed := TRUE;
				emptyCells.computed := TRUE;
				font.computed := defaultFont;
				fontSize.computed := AbsoluteFontSizes[Medium];
				fontStretch.computed := Normal;
				fontVariant.computed := TRUE;
				letterSpacing.computed := 0.0;
				wordSpacing.computed := 0.0;
				lineHeight.computed := 1.2 * (font.computed.ymax - font.computed.ymin);
				listStyleImage.computed := NIL;
				listStylePosition.computed := TRUE;
				listStyleType.computed := Disc;
				(* quotes.computed := ;	*)
				textAlign.computed := Left;
				textIndent.computed := 0.0;
				textTransform.computed := None;
				whiteSpace.computed := Normal;
			END;
			color.specified := NIL;
			borderCollapse.specified := NIL; borderSpacing.horizontal.specified := NIL; borderSpacing.vertical.specified := NIL;
			captionSide.specified := NIL;
			cursor.specified := NIL;
			direction.specified := NIL;
			emptyCells.specified := NIL;
			font.specified := NIL; fontSize.specified := NIL; fontStretch.specified := NIL; fontVariant.specified := NIL;
			letterSpacing.specified := NIL; wordSpacing.specified := NIL;
			lineHeight.specified := NIL;
			listStyleImage.specified := NIL; listStylePosition.specified := NIL; listStyleType.specified := NIL;
			(* quotes.specified := NIL;	*)
			textAlign.specified := NIL; textIndent.specified := NIL; textTransform.specified := NIL;
			whiteSpace.specified := NIL;
			CSS2.IntToRGBA(Transparent, backgroundColor.computed.r, backgroundColor.computed.g,
				backgroundColor.computed.b, backgroundColor.computed.a);
			backgroundColor.specified := NIL;
			backgroundImage.computed := NIL; backgroundImage.specified := NIL;
			backgroundPosition.horizontal.computed := 0.0; backgroundPosition.horizontal.specified := NIL;
			backgroundPosition.vertical.computed := 0.0; backgroundPosition.vertical.specified := NIL;
			backgroundRepeat.horizontal.computed := TRUE; backgroundRepeat.horizontal.specified := NIL;
			backgroundRepeat.vertical.computed := TRUE; backgroundRepeat.vertical.specified := NIL;
			borderColor.top.computed := color.computed; borderColor.top.specified := NIL;
			borderColor.right.computed := color.computed; borderColor.right.specified := NIL;
			borderColor.bottom.computed := color.computed; borderColor.bottom.specified := NIL;
			borderColor.left.computed := color.computed; borderColor.left.specified := NIL;
			borderStyle.top.computed := None; borderStyle.top.specified := NIL;
			borderStyle.right.computed := None; borderStyle.right.specified := NIL;
			borderStyle.bottom.computed := None; borderStyle.bottom.specified := NIL;
			borderStyle.left.computed := None; borderStyle.left.specified := NIL;
			borderWidth.top.computed := mediumBorder; borderWidth.top.specified := NIL;
			borderWidth.right.computed := mediumBorder; borderWidth.right.specified := NIL;
			borderWidth.bottom.computed := mediumBorder; borderWidth.bottom.specified := NIL;
			borderWidth.left.computed := mediumBorder; borderWidth.left.specified := NIL;
			top.computed := DummyAuto; top.specified := NIL;
			right.computed := DummyAuto; right.specified := NIL;
			bottom.computed := DummyAuto; bottom.specified := NIL;
			left.computed := DummyAuto; left.specified := NIL;
			height.computed := DummyAuto; height.specified := NIL;
			width.computed := DummyAuto; width.specified := NIL;
			maxHeight.computed := DummyAuto; maxHeight.specified := NIL;
			maxWidth.computed := DummyAuto; maxWidth.specified := NIL;
			minHeight.computed := 0.0; minHeight.specified := NIL;
			minWidth.computed := 0.0; minWidth.specified := NIL;
			clear.left.computed := FALSE; clear.left.specified := NIL;
			clear.right.computed := FALSE; clear.right.specified := NIL;
			float.computed := None; float.specified := NIL;
			markerOffset.computed := 0.0; markerOffset.specified := NIL;
			outlineStyle.computed := None; outlineStyle.specified := NIL;
			outlineWidth.computed := mediumBorder; outlineWidth.specified := NIL;
			overflow.computed := Visible; overflow.specified := NIL;
			position.computed := Static; position.specified := NIL;
			tableLayout.computed := TRUE; tableLayout.specified := NIL;
			textDecoration.computed := {}; textDecoration.specified := NIL;
			(* textShadow.computed :=  ; textShadow.specified := NIL;*)
			unicodeBidi.computed := Normal; unicodeBidi.specified := NIL;
			verticalAlign.computed := Baseline; verticalAlign.specified := NIL;
			visibility.computed := Visible; visibility.specified := NIL;
			zIndex.computed := -1; zIndex.specified := NIL
		END Initialize;

		PROCEDURE ComputeValues;
		VAR terms: XMLObjects.Enumerator; term: ANY;
		BEGIN
			ComputeValues^();
			WITH parent: VisualProperties DO
				IF ~generated THEN
					IF display.computed = None THEN
						position.computed := None; float.computed := None
					ELSE
						ComputeIdent(position, parent.position);
						IF position.computed IN {Absolute, Fixed} THEN
							display.computed := Block; float.computed := None
						ELSE
							ComputeIdent(float, parent.float);
							IF float.computed # None THEN
								display.computed := Block
							END
						END
					END
				END;
				ComputeBool(backgroundAttachment, parent.backgroundAttachment, Scroll);
				ComputeColor(backgroundColor, parent.backgroundColor, IntToColor(Transparent));
				ComputeImg(backgroundImage, parent.backgroundImage);
				ComputeBool(backgroundRepeat.horizontal, parent.backgroundRepeat.horizontal, Repeat);
				ComputeBool(backgroundRepeat.vertical, parent.backgroundRepeat.vertical, Repeat);
				IF backgroundPosition.horizontal.specified # NIL THEN
					backgroundPosition.horizontal.computed := backgroundPosition.horizontal.specified.GetRealVal()
				END;
				IF backgroundPosition.vertical.specified # NIL THEN
					backgroundPosition.vertical.computed := backgroundPosition.vertical.specified.GetRealVal()
				END;
				ComputeIdent(borderStyle.top, parent.borderStyle.top);
				ComputeIdent(borderStyle.right, parent.borderStyle.right);
				ComputeIdent(borderStyle.bottom, parent.borderStyle.bottom);
				ComputeIdent(borderStyle.left, parent.borderStyle.left);
				ComputeDim(fontSize, parent.fontSize, ppi, parent.fontSize.computed, parent.font.computed);
				IF display.computed IN {Table, InlineTable} THEN
					ComputeBool(borderCollapse, parent.borderCollapse, Collapse);
					IF borderCollapse.computed THEN borderSpacing.horizontal.computed := 0.0; borderSpacing.vertical.computed := 0.0
					ELSE ComputeDim(borderSpacing.horizontal, parent.borderSpacing.horizontal, ppi, 0.0, font.computed)
					END;
					ComputeDim(borderSpacing.vertical, parent.borderSpacing.vertical, ppi, 0.0, font.computed);
					ComputeBool(tableLayout, parent.tableLayout, Auto)
				END;
				ComputeColor(color, parent.color, IntToColor(defaultColor));
				ComputeColor(borderColor.top, parent.borderColor.top, color);
				ComputeColor(borderColor.right, parent.borderColor.right, color);
				ComputeColor(borderColor.bottom, parent.borderColor.bottom, color);
				ComputeColor(borderColor.left, parent.borderColor.left, color);
				IF display.computed = TableCaption THEN
					ComputeIdent(captionSide, parent.captionSide)
				END;
				IF IsBlockLevelElement() THEN
					ComputeBool(clear.left, parent.clear.left, Clear); ComputeBool(clear.right, parent.clear.right, Clear);
					ComputeIdent(textAlign, parent.textAlign);
					ComputeIdent(whiteSpace, parent.whiteSpace)
				END;
				ComputeCursor(cursor, parent.cursor);
				ComputeBool(direction, parent.direction, Ltr);
				IF display.computed = TableCell THEN ComputeBool(emptyCells, parent.emptyCells, Show) END;
				ComputeFont();
				ComputeIdent(fontStretch, parent.fontStretch);
				ComputeBool(fontVariant, parent.fontVariant, Normal);
				ComputeDim(letterSpacing, parent.letterSpacing, ppi, 0.0, font.computed);
				ComputeDim(wordSpacing, parent.wordSpacing, ppi, 0.0, font.computed);
				IF lineHeight.specified # NIL THEN
					IF lineHeight.specified.IsIdent(Normal) THEN
						lineHeight.computed := 1.2 * (font.computed.ymax - font.computed.ymin)
					ELSIF lineHeight.specified.GetType() = CSS2.Percent THEN
						lineHeight.computed := lineHeight.specified.GetRealVal() * fontSize.computed
					ELSIF lineHeight.specified.IsLength() THEN
						ComputeDim(lineHeight, parent.lineHeight, ppi, 0.0, font.computed)
					END
				ELSE
					lineHeight.computed := 1.2 * (font.computed.ymax - font.computed.ymin)
				END;
				IF display.computed = ListItem THEN
					ComputeImg(listStyleImage, parent.listStyleImage);
					ComputeBool(listStylePosition, parent.listStylePosition, Outside);
					ComputeIdent(listStyleType, parent.listStyleType)
				END;
				IF display.computed = Marker THEN ComputeDim(markerOffset, parent.markerOffset, ppi, 0.0, font.computed) END;
				ComputeColor(outlineColor, parent.outlineColor, IntToColor(Transparent));
				ComputeIdent(outlineStyle, parent.outlineStyle);
				ComputeDim(outlineWidth, parent.outlineWidth, ppi, 0.0, font.computed);
				IF IsBlockLevelElement() OR replaced THEN
					ComputeDim(clip.top, parent.clip.top, ppi, 0.0, font.computed);
					ComputeDim(clip.right, parent.clip.right, ppi, 0.0, font.computed);
					ComputeDim(clip.bottom, parent.clip.bottom, ppi, 0.0, font.computed);
					ComputeDim(clip.left, parent.clip.left, ppi, 0.0, font.computed);
					ComputeIdent(overflow, parent.overflow)
				END;
				IF textDecoration.specified # NIL THEN
					IF textDecoration.specified.IsIdent(Inherit) THEN
						textDecoration.computed := parent.textDecoration.computed
					ELSE
						textDecoration.computed := {};
						(* 	NEW(terms, textDecoration.specified);	*)
						WHILE terms.HasMoreElements() DO
							term := terms.GetNext();
							IF term(CSS2.Term).IsIdent(Underline) THEN INCL(textDecoration.computed, Underline)
							ELSIF term(CSS2.Term).IsIdent(Overline) THEN INCL(textDecoration.computed, Overline)
							ELSIF term(CSS2.Term).IsIdent(LineThrough) THEN INCL(textDecoration.computed, LineThrough)
							ELSIF term(CSS2.Term).IsIdent(Blink) THEN INCL(textDecoration.computed, Blink)
							END
						END
					END
				END;
				ComputeIdent(textTransform, parent.textTransform);
				ComputeIdent(unicodeBidi, parent.unicodeBidi);
				IF visibility.specified = NIL THEN visibility.computed := parent.visibility.computed
				ELSE ComputeIdent(visibility, parent.visibility)
				END;
				IF IsPositioned() THEN
					IF zIndex.specified # NIL THEN
						IF zIndex.specified.IsIdent(Inherit) THEN zIndex.computed := parent.zIndex.computed
						ELSIF zIndex.specified.IsIdent(Auto) THEN zIndex.computed := -1
						ELSIF zIndex.specified.GetType() = CSS2.IntNumber THEN zIndex.computed := zIndex.specified.GetIntVal()
						END
					END
				END
			END
		END ComputeValues;

		PROCEDURE ComputeDimensions*;
		BEGIN
			ComputeContainingBlock();
			WITH parent: VisualProperties DO
				IF position.computed = Static THEN
					top.computed := 0.0; left.computed := 0.0; bottom.computed := 0.0; right.computed := 0.0
				ELSE
					ComputeDim(top, parent.top, ppi, containingBlock.height, font.computed);
					ComputeDim(left, parent.left, ppi, containingBlock.width, font.computed);
					ComputeDim(bottom, parent.bottom, ppi, containingBlock.height, font.computed);
					ComputeDim(right, parent.right, ppi, containingBlock.width, font.computed)
				END;
				IF borderStyle.top.computed # None THEN
					ComputeDim(borderWidth.top, parent.borderWidth.top, ppi, 0.0, font.computed)
				ELSE
					borderWidth.top.computed := 0
				END;
				IF borderStyle.right.computed # None THEN
					ComputeDim(borderWidth.right, parent.borderWidth.right, ppi, 0.0, font.computed);
				ELSE
					borderWidth.right.computed := 0
				END;
				IF borderStyle.bottom.computed # None THEN
					ComputeDim(borderWidth.bottom, parent.borderWidth.bottom, ppi, 0.0, font.computed);
				ELSE
					borderWidth.bottom.computed := 0
				END;
				IF borderStyle.left.computed # None THEN
					ComputeDim(borderWidth.left, parent.borderWidth.left, ppi, 0.0, font.computed);
				ELSE
					borderWidth.left.computed := 0
				END;
				ComputeDim(padding.top, parent.padding.top, ppi, containingBlock.width, font.computed);
				ComputeDim(padding.right, parent.padding.right, ppi, containingBlock.width, font.computed);
				ComputeDim(padding.bottom, parent.padding.bottom, ppi, containingBlock.width, font.computed);
				ComputeDim(padding.left, parent.padding.left, ppi, containingBlock.width, font.computed);
				ComputeDim(margin.left, parent.margin.left, ppi, containingBlock.width, font.computed);
				ComputeDim(margin.right, parent.margin.right, ppi, containingBlock.width, font.computed);
				ComputeDim(width, parent.width, ppi, containingBlock.width, font.computed);
				ComputeWidthsAndMargins();
				IF (maxWidth.specified = NIL) OR maxWidth.specified.IsIdent(None) THEN
					maxWidth.computed := MAX(LONGREAL)
				ELSE
					ComputeDim(maxWidth, parent.maxWidth, ppi, containingBlock.width, font.computed)
				END;
				IF (minWidth.specified = NIL) THEN minWidth.computed := 0.0
				ELSE ComputeDim(minWidth, parent.minWidth, ppi, containingBlock.width, font.computed)
				END;
				IF minWidth.computed > maxWidth.computed THEN maxWidth.computed := minWidth.computed END; (* 10.4 2 *)
				IF width.computed > maxWidth.computed THEN	(* 10.4 3. *)
					width.computed := maxWidth.computed;
					ComputeWidthsAndMargins()
				END;
				IF width.computed < minWidth.computed THEN	(* 10.4 4. *)
					width.computed := minWidth.computed;
					ComputeWidthsAndMargins();
				END;
				ComputeDim(margin.top, parent.margin.top, ppi, containingBlock.height, font.computed);
				ComputeDim(height, parent.height, ppi, containingBlock.height, font.computed);
				ComputeDim(margin.bottom, parent.margin.bottom, ppi, containingBlock.height, font.computed);
				ComputeHeightsAndMargins();
				(*ComputeDim(backgroundPosition.horizontal, parent.backgroundPosition.horizontal, ppi,
					padding.right.computed + width.computed + padding.left.computed, font.computed);
				ComputeDim(backgroundPosition.vertical, parent.backgroundPosition.vertical, ppi,
					padding.top.computed + width.computed + padding.bottom.computed, font.computed);*)
				ComputeDim(textIndent, parent.textIndent, ppi, containingBlock.width, font.computed);
				IF verticalAlign.specified # NIL THEN
					IF verticalAlign.specified.IsIdent(Inherit) THEN
						verticalAlign.computed := parent.verticalAlign.computed;
						verticalAlign.computedLength := parent.verticalAlign.computedLength
					ELSIF verticalAlign.specified.GetType() = CSS2.Ident THEN
						verticalAlign.computed := SHORT(SHORT(verticalAlign.specified.GetIntVal()))
					ELSE
						IF verticalAlign.specified.IsLength() THEN
							verticalAlign.computed := 0;
							verticalAlign.computedLength := GetPixels(verticalAlign.specified, ppi, font.computed)
						ELSIF verticalAlign.specified.GetType() = CSS2.Percent THEN
							verticalAlign.computedLength := verticalAlign.specified.GetRealVal() * lineHeight.computed
						END
					END
				END
			END;
			dimensionChanged := FALSE
		END ComputeDimensions;

		PROCEDURE ComputeWidthsAndMargins;	(* 10.3 *)
		VAR floating: BOOLEAN (* floating = TRUE, normal flow = FALSE *);
			remainingWidth: LONGREAL;
		BEGIN
			IF borderStyle.left.computed = None THEN borderWidth.left.computed := 0.0 END;
			IF borderStyle.right.computed = None THEN borderWidth.right.computed := 0.0 END;
			WITH parent: VisualProperties DO
				IF position.computed # Absolute THEN
					SetZeroIfAutoSize(left); SetZeroIfAutoSize(right);
					IF IsInlineLevelElement() OR floating THEN
						SetZeroIfAutoMargin(margin.left); SetZeroIfAutoMargin(margin.right);
						IF replaced THEN
						END
					ELSIF IsBlockLevelElement() (*& (display.computed # TableCell)*) THEN	(* 10.3.3 *)
						IF IsAutoSize(width) THEN	(* 10.3.3, 3rd "if" *)
							SetZeroIfAutoMargin(margin.left); SetZeroIfAutoMargin(margin.right);
							width.computed := containingBlock.width - margin.left.computed - borderWidth.left.computed
								- padding.left.computed - padding.right.computed - borderWidth.right.computed
								- margin.right.computed;
							(*IF display.computed = Table THEN tableLayout.computed := TRUE END*)
						ELSIF IsAutoMargin(margin.left) & IsAutoMargin(margin.right) THEN
							remainingWidth := containingBlock.width - borderWidth.left.computed - padding.left.computed
								- width.computed - padding.right.computed - borderWidth.right.computed;
							margin.left.computed := remainingWidth / 2; margin.right.computed := remainingWidth / 2
						ELSIF IsAutoMargin(margin.left) OR (direction.computed = FALSE) THEN
							margin.left.computed := containingBlock.width - borderWidth.left.computed - padding.left.computed
								- width.computed - padding.right.computed - borderWidth.right.computed - margin.right.computed
						ELSIF IsAutoMargin(margin.right) OR (direction.computed = TRUE) THEN
							(*margin.right.computed := containingBlock.width - margin.left.computed - borderWidth.left.computed
								- padding.left.computed - width.computed - padding.right.computed - borderWidth.right.computed*)
						END;
					END
				ELSIF ~replaced THEN
					IF (borderStyle.right.specified # NIL) & borderStyle.right.specified.IsIdent(None) THEN
						borderWidth.right.computed := 0.0
					END;
					IF (borderStyle.left.specified # NIL) & borderStyle.left.specified.IsIdent(None) THEN
						borderWidth.left.computed := 0.0
					END;
					IF direction.computed = TRUE THEN SetZeroIfAutoSize(left) END;	(* 10.3.7 1. *)
					IF direction.computed = FALSE THEN SetZeroIfAutoSize(right) END;	(* 10.3.7 2. *)
					IF IsAutoSize(width) THEN	(* 10.3.7 3. *)
						SetZeroIfAutoSize(left); SetZeroIfAutoSize(right)
					END;
					IF IsAutoSize(left) OR IsAutoSize(width) OR IsAutoSize(right) THEN	(* 10.3.7 4. *)
						SetZeroIfAutoMargin(margin.left); SetZeroIfAutoMargin(margin.right)
					END;
					IF IsAutoMargin(margin.left) & IsAutoMargin(margin.right) THEN (* 10.3.7 5. *)
						remainingWidth := containingBlock.width - left.computed - borderWidth.left.computed
							- padding.left.computed - width.computed - padding.right.computed - borderWidth.right.computed
							- right.computed;
						margin.left.computed := remainingWidth / 2;
						margin.right.computed := remainingWidth - margin.left.computed
					ELSIF IsAutoSize(left) THEN (* 10.3.7 6. *)
						left.computed := containingBlock.width - margin.left.computed - borderWidth.left.computed
							- padding.left.computed - width.computed - padding.right.computed - borderWidth.right.computed
							- margin.right.computed - right.computed
					ELSIF IsAutoMargin(margin.left) THEN (* 10.3.7 6. *)
						margin.left.computed := containingBlock.width - left.computed - borderWidth.left.computed
							- padding.left.computed - width.computed - padding.right.computed - borderWidth.right.computed
							- margin.right.computed - right.computed
					ELSIF IsAutoSize(width) THEN (* 10.3.7 6. *)
						width.computed := containingBlock.width - left.computed - margin.left.computed - borderWidth.left.computed
							- padding.left.computed - padding.right.computed - borderWidth.right.computed
							- margin.right.computed - right.computed
					ELSIF IsAutoMargin(margin.right) THEN (* 10.3.7 6. *)
						margin.right.computed := containingBlock.width - left.computed - margin.left.computed
							- borderWidth.left.computed - padding.left.computed - width.computed - padding.right.computed
							- borderWidth.right.computed - right.computed
					ELSIF IsAutoSize(right) THEN (* 10.3.7 6.*)
						right.computed := containingBlock.width - left.computed - margin.left.computed
							- borderWidth.left.computed - padding.left.computed - width.computed - padding.right.computed
							- borderWidth.right.computed - margin.right.computed
					ELSIF direction.computed = TRUE THEN (* 10.3.7 7. *)
						left.computed := containingBlock.width - margin.left.computed - borderWidth.left.computed
							- padding.left.computed - width.computed - padding.right.computed - borderWidth.right.computed
							- margin.right.computed - right.computed
					ELSIF direction.computed = FALSE THEN (* 10.3.7 7. *)
						right.computed := containingBlock.width - left.computed - margin.left.computed
							- borderWidth.left.computed - padding.left.computed - width.computed - padding.right.computed
							- borderWidth.right.computed - margin.right.computed
					END
				ELSE
				END
			END
		END ComputeWidthsAndMargins;

		PROCEDURE ComputeHeightsAndMargins;	(* 10.6 *)
		VAR remainingHeight: LONGREAL;
		BEGIN
				IF borderStyle.top.computed = None THEN borderWidth.top.computed := 0.0 END;
				IF borderStyle.bottom.computed = None THEN borderWidth.bottom.computed := 0.0 END;
			WITH parent: VisualProperties DO
				IF position.computed # Absolute THEN
					SetZeroIfAutoSize(top);
					SetZeroIfAutoMargin(margin.top);
					SetZeroIfAutoMargin(margin.bottom);
					SetZeroIfAutoSize(bottom);
					IF IsInlineLevelElement() THEN
						height.computed := lineHeight.computed
					ELSIF IsBlockLevelElement() THEN	(* height depends on child boxes *)
						SetZeroIfAutoSize(height)
					END
				ELSE	(* 10.3.7 *)
					SetZeroIfAutoSize(top);	(* 10.6.4 1. *)
					IF IsAutoSize(height) THEN SetZeroIfAutoSize(bottom) END;	(* 10.6.4 2. *)
					IF IsAutoSize(height) OR IsAutoSize(bottom) THEN	(* 10.6.4 3. *)
						SetZeroIfAutoMargin(margin.top); SetZeroIfAutoMargin(margin.bottom)
					END;
					IF IsAutoMargin(margin.top) & IsAutoMargin(margin.bottom) THEN	(* 10.6.4 4. *)
						remainingHeight := containingBlock.height - top.computed - borderWidth.top.computed
							- padding.top.computed - height.computed - padding.bottom.computed
							- borderWidth.bottom.computed - bottom.computed;
						margin.top.computed := remainingHeight / 2;
						margin.bottom.computed := remainingHeight - margin.top.computed
					ELSIF IsAutoMargin(margin.top) THEN	(* 10.6.4 5. *)
						margin.top.computed := containingBlock.height - top.computed - borderWidth.top.computed
							- padding.top.computed - height.computed - padding.bottom.computed
							- borderWidth.bottom.computed - margin.bottom.computed - bottom.computed
					ELSIF IsAutoSize(height) THEN	(* 10.6.4 5. *)
						height.computed := containingBlock.height - top.computed - margin.top.computed
							- borderWidth.top.computed - padding.top.computed - padding.bottom.computed
							- borderWidth.bottom.computed - margin.bottom.computed - bottom.computed
					ELSIF IsAutoMargin(margin.bottom) THEN	(* 10.6.4 5. *)
						margin.bottom.computed := containingBlock.height - top.computed - margin.top.computed
							- borderWidth.top.computed - padding.top.computed - height.computed - padding.bottom.computed
							- borderWidth.bottom.computed - bottom.computed
					ELSE	(* 10.6.4 5./6. *)
						bottom.computed := containingBlock.height - top.computed - margin.top.computed
							- borderWidth.top.computed - padding.top.computed - height.computed - padding.bottom.computed
							- borderWidth.bottom.computed - margin.bottom.computed
					END
				END
			END
		END ComputeHeightsAndMargins;

		PROCEDURE ComputeFont;
		VAR fontName: ARRAY GfxFonts.FontNameLen OF CHAR; fnt: GfxFonts.Font; s: String;

			PROCEDURE ExtractPattern(VAR from: ARRAY OF CHAR; pat: ARRAY OF CHAR);
			VAR i: LONGINT; patLen: LONGINT;
			BEGIN
				DynamicStrings.Search(pat, from, i);
				IF i # -1 THEN
					patLen := DynamicStrings.StringLength(pat);
					FOR i := i + patLen TO DynamicStrings.StringLength(from) DO
						from[i - patLen] := from[i]
					END
				END
			END ExtractPattern;

		BEGIN
			WITH parent: VisualProperties DO
				font.computed := parent.font.computed;
				IF (font.specified # NIL) & (font.specified.IsIdent(Inherit)) THEN
					font.computed := parent.font.computed
				ELSE
					IF font.specified # NIL THEN
						CASE font.specified.GetIntVal() OF
						| Caption: font.computed := captionFont;
						| Icon: font.computed := iconFont;
						| Menu: font.computed := menuFont;
						| MessageBox: font.computed := messageBoxFont;
						| SmallCaption: font.computed := smallCaptionFont;
						| StatusBar: font.computed := statusBarFont;
						ELSE
					END
					ELSIF fontFamily # NIL THEN
(*						REPEAT
							term := terms.GetNext();	(* <family-name> *)*)
							s := fontFamily.GetStringVal();
							IF s # NIL THEN COPY(s^, fontName);
								IF fontWeight # NIL THEN
									IF fontWeight.IsIdent(Bolder)
											OR ((fontWeight.GetType() = CSS2.IntNumber) & (fontWeight.GetIntVal() >= 700)) THEN
										DynamicStrings.StringAppend(fontName, "-Bold")
									ELSIF fontWeight.IsIdent(Lighter) THEN	(* not supported *)
									END
								END;
								IF (fontStyle # NIL) THEN
									IF fontStyle.IsIdent(Italic) THEN DynamicStrings.StringAppend(fontName, "-Italic")
									ELSIF fontStyle.IsIdent(Oblique) THEN (* not supported *)
									END
								END;
								fnt := GfxFonts.OpenSize(fontName, SHORT(ENTIER(fontSize.computed + 0.5)));
								IF fnt # NIL THEN font.computed := fnt  END
							END;
(*							term := terms.GetNext()	(* <generic-family> *)
						UNTIL ~terms.HasMoreElements() OR (font.computed # NIL)*)
					ELSE
						COPY(parent.font.computed.name, fontName);
						IF (fontWeight # NIL) & (fontWeight.IsIdent(Lighter)
								OR ((fontWeight.GetType() = CSS2.IntNumber) & (fontWeight.GetIntVal() < 700))) THEN
							ExtractPattern(fontName, "-Bold")
						END;
						IF (fontStyle # NIL) & fontStyle.IsIdent(Normal) THEN ExtractPattern(fontName, "-Italic") END;
						IF parent.font.computed.name # fontName THEN
							fnt := GfxFonts.OpenSize(fontName, SHORT(ENTIER(fontSize.computed + 0.5)));
							IF fnt # NIL THEN font.computed := fnt END
						END
					END
				END
			END
		END ComputeFont;

		PROCEDURE ComputeContainingBlock;
		VAR vp: VisualProperties;
		BEGIN
			vp := parent(VisualProperties);
			WHILE (vp # SELF) & ~vp.IsBlockLevelElement() DO
				vp := vp.parent(VisualProperties)
			END;
			containingBlock.width := vp.width.computed;
			containingBlock.height := vp.height.computed;
(*			IF position = Fixed THEN
				(* containing block := viewport *)
			ELSIF position = Absolute THEN

			ELSE
				IF IsBlockLevel() THEN
					width := left.computed.GetIntVal() + margin.left	*)
		END ComputeContainingBlock;

		PROCEDURE IsPositioned(): BOOLEAN;
		BEGIN
			RETURN position.computed # Static
		END IsPositioned;

	END VisualProperties;

VAR m : WMWindowManager.WindowManager;


	PROCEDURE IsAutoSize*(size: Dim): BOOLEAN;
	BEGIN
		RETURN (size.specified = NIL) OR size.specified.IsIdent(Auto) OR size.specified.IsStringIdent("auto")
	END IsAutoSize;

	PROCEDURE IsAutoMargin*(margin: Dim): BOOLEAN;
	BEGIN
		RETURN (margin.specified # NIL) & (margin.specified.IsIdent(Auto) OR margin.specified.IsStringIdent("auto"))
	END IsAutoMargin;

	PROCEDURE ChangeToIdent(identValue: SHORTINT): CSS2.Term;
	VAR term: CSS2.Term;
	BEGIN
		NEW(term); term.SetType(CSS2.Ident); term.SetIntVal(identValue); RETURN term
	END ChangeToIdent;

	PROCEDURE ChangeToStringIdent(VAR term: CSS2.Term; identValue: ARRAY OF CHAR);
	BEGIN
		IF term = NIL THEN NEW(term) END;
		term.SetType(CSS2.StringIdent);
		term.SetStringVal(identValue)
	END ChangeToStringIdent;

	PROCEDURE SetNil(VAR property: CSS2.Term; term: CSS2.Term): BOOLEAN;
	BEGIN
		IF term = NIL THEN property := NIL; RETURN TRUE
		ELSE RETURN FALSE
		END
	END SetNil;

	PROCEDURE SetIdentOrInherit(VAR property: CSS2.Term; term: CSS2.Term): BOOLEAN;
	BEGIN
		IF term.GetType() = CSS2.Ident THEN
			property := term; RETURN TRUE
		ELSIF term.IsStringIdent("inherit") THEN
			property := ChangeToIdent(Inherit);
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END SetIdentOrInherit;

	PROCEDURE SetNone(VAR property: CSS2.Term; term: CSS2.Term): BOOLEAN;
	BEGIN
		IF term.IsStringIdent("none") THEN
			property := ChangeToIdent(None);
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END SetNone;

	PROCEDURE ChangeToIdentCollection(VAR collection: XMLObjects.Collection; identValue: SHORTINT);
	VAR arrColl: XMLObjects.ArrayCollection; term: CSS2.Term;
	BEGIN
		IF collection = NIL THEN NEW(arrColl); collection := arrColl END;
		NEW(term); term.SetType(CSS2.Ident); term.SetIntVal(identValue);
		collection.Add(term)
	END ChangeToIdentCollection;

	PROCEDURE SetNilCollection(VAR collection: XMLObjects.Collection; term: CSS2.Term): BOOLEAN;
	BEGIN
		IF term = NIL THEN collection := NIL; RETURN TRUE
		ELSE RETURN FALSE
		END
	END SetNilCollection;

	PROCEDURE SetIdentOrInheritCollection(VAR collection: XMLObjects.Collection; term: CSS2.Term): BOOLEAN;
	BEGIN
		IF term.IsStringIdent("inherit") THEN
			collection := NIL;
			ChangeToIdentCollection(collection, Inherit);
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END SetIdentOrInheritCollection;

	(* ppi: pixel per inch *)
	PROCEDURE GetPixels(term: CSS2.Term; ppi: LONGREAL; font: GfxFonts.Font): LONGREAL;
	VAR fact, pixels: LONGREAL; x, y, dx, dy: REAL; map: Raster.Image;
	BEGIN
		IF (term # NIL) & term.IsLength() THEN
			CASE term.GetUnit() OF
			| CSS2.em: fact := font.ptsize / ppi
			| CSS2.ex: GfxFonts.GetMap(font, 'x', x, y, dx, dy, map); fact := -y / ppi
			| CSS2.px: fact := 1.0 / ppi
			| CSS2.in: fact := 1.0
			| CSS2.cm: fact := 1.0 / 2.54
			| CSS2.mm: fact := 1.0 / 25.4
			| CSS2.pt: fact := 1.0 / 72.0
			| CSS2.pc: fact := 1.0 / 6.0
			END;
			IF term.GetType() = CSS2.IntDimension THEN pixels := term.GetIntVal() * ppi * fact
			ELSIF term.GetType() = CSS2.RealDimension THEN pixels := term.GetRealVal() * ppi * fact
			END
		ELSIF (term # NIL) & (((term.GetType() = CSS2.IntNumber) & (term.GetIntVal() = 0))
				OR ((term.GetType() = CSS2.RealNumber) & (term.GetRealVal() = 0.0))) THEN
			pixels := 0.0
		ELSE
			pixels := 0.0
		END;
		RETURN pixels
	END GetPixels;

	PROCEDURE ChangeToPixel(pixelVal: LONGREAL): CSS2.Term;
	VAR term: CSS2.Term;
	BEGIN
		NEW(term); term.SetType(CSS2.RealDimension); term.SetRealVal(pixelVal); term.SetUnit(CSS2.px); RETURN term
	END ChangeToPixel;

	PROCEDURE SetColor(VAR property: CSS2.Term; term: CSS2.Term; invertAllowed: BOOLEAN);
	VAR newTerm: CSS2.Term;
	BEGIN
		IF ~SetNil(property, term) & ~SetIdentOrInherit(property, term) THEN
			IF term.GetType() = CSS2.Color THEN property := term
			ELSE
				NEW(newTerm); newTerm.SetType(CSS2.Color);
				IF term.IsStringIdent("aqua") THEN newTerm.SetIntVal(Aqua); property := newTerm
				ELSIF term.IsStringIdent("black") THEN newTerm.SetIntVal(Black); property := newTerm
				ELSIF term.IsStringIdent("blue") THEN newTerm.SetIntVal(Blue); property := newTerm
				ELSIF term.IsStringIdent("fuchsia") THEN newTerm.SetIntVal(Fuchsia); property := newTerm
				ELSIF term.IsStringIdent("gray") THEN newTerm.SetIntVal(Gray); property := newTerm
				ELSIF term.IsStringIdent("green") THEN newTerm.SetIntVal(Green); property := newTerm
				ELSIF term.IsStringIdent("lime") THEN newTerm.SetIntVal(Lime); property := newTerm
				ELSIF term.IsStringIdent("maroon") THEN newTerm.SetIntVal(Maroon); property := newTerm
				ELSIF term.IsStringIdent("navy") THEN newTerm.SetIntVal(Navy); property := newTerm
				ELSIF term.IsStringIdent("olive") THEN newTerm.SetIntVal(Olive); property := newTerm
				ELSIF term.IsStringIdent("purple") THEN newTerm.SetIntVal(Purple); property := newTerm
				ELSIF term.IsStringIdent("red") THEN newTerm.SetIntVal(Red); property := newTerm
				ELSIF term.IsStringIdent("silver") THEN newTerm.SetIntVal(Silver); property := newTerm
				ELSIF term.IsStringIdent("teal") THEN newTerm.SetIntVal(Teal); property := newTerm
				ELSIF term.IsStringIdent("white") THEN newTerm.SetIntVal(White); property := newTerm
				ELSIF term.IsStringIdent("yellow") THEN newTerm.SetIntVal(Yellow); property := newTerm
				ELSIF term.IsStringIdent("transparent") OR (invertAllowed & term.IsStringIdent("invert")) THEN
					newTerm.SetIntVal(Transparent); property := newTerm
				END
			END
		END
	END SetColor;

	PROCEDURE IsBorderStyle(term: CSS2.Term): BOOLEAN;
	BEGIN
		RETURN (term # NIL) & (term.IsStringIdent("hidden") & term.IsStringIdent("dotted") OR term.IsStringIdent("dashed")
			OR term.IsStringIdent("solid") OR term.IsStringIdent("double") OR term.IsStringIdent("groove")
			OR term.IsStringIdent("ridge") OR term.IsStringIdent("inset") OR term.IsStringIdent("outset")
			OR term.IsIdent(Hidden) OR term.IsIdent(Dotted) OR term.IsIdent(Dashed) OR term.IsIdent(Solid)
			OR term.IsIdent(Double) OR term.IsIdent(Groove) OR term.IsIdent(Ridge)
			OR term.IsIdent(Inset) OR term.IsIdent(Outset))
	END IsBorderStyle;

	PROCEDURE BorderStyle(VAR position: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(position, term) & ~SetIdentOrInherit(position, term) & ~SetNone(position, term) THEN
			IF term.IsStringIdent("hidden") THEN position := ChangeToIdent(Hidden)
			ELSIF term.IsStringIdent("dotted") THEN position := ChangeToIdent(Dotted)
			ELSIF term.IsStringIdent("dashed") THEN position := ChangeToIdent(Dashed)
			ELSIF term.IsStringIdent("solid") THEN position := ChangeToIdent(Solid)
			ELSIF term.IsStringIdent("double") THEN position := ChangeToIdent(Double)
			ELSIF term.IsStringIdent("groove") THEN position := ChangeToIdent(Groove)
			ELSIF term.IsStringIdent("ridge") THEN position := ChangeToIdent(Ridge)
			ELSIF term.IsStringIdent("inset") THEN position := ChangeToIdent(Inset)
			ELSIF term.IsStringIdent("outset") THEN position := ChangeToIdent(Outset)
			ELSIF term.GetType() = CSS2.Ident THEN position := term
			END
		END
	END BorderStyle;

	PROCEDURE IsBorderWidth(term: CSS2.Term): BOOLEAN;
	BEGIN
		RETURN (term # NIL) & (term.IsStringIdent("thin") OR term.IsStringIdent("medium") OR term.IsStringIdent("thick")
			OR term.IsIdent(Thin) OR term.IsIdent(Thick) OR term.IsIdent(Medium) OR term.IsLength())
	END IsBorderWidth;

	PROCEDURE BorderWidth(VAR position: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(position, term) & ~SetIdentOrInherit(position, term) THEN
			IF term.IsStringIdent("thin") THEN position := ChangeToPixel(thinBorder)
			ELSIF term.IsStringIdent("medium") THEN position := ChangeToPixel(mediumBorder)
			ELSIF term.IsStringIdent("thick") THEN position := ChangeToPixel(thickBorder)
			ELSIF term.IsLength() THEN position := term
			END
		END
	END BorderWidth;

	PROCEDURE BoxOffset(VAR position: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(position, term) & ~SetIdentOrInherit(position, term) THEN
			IF term.IsStringIdent("auto") THEN
				position := ChangeToIdent(Auto)
			ELSIF term.IsStringIdent("static-position") THEN
				position := ChangeToIdent(StaticPosition)
			ELSIF term.IsLength() OR (term.GetType() = CSS2.Percent) THEN
				position := term
			END
		END
	END BoxOffset;

(*
	PROCEDURE GetSmallerFont(fontSize: LONGINT): LONGINT;
	VAR i: SHORTINT;
	BEGIN
		i := XXSmall;
		WHILE (i <= XXLarge) & (AbsoluteFontSizes[i] < fontSize) DO INC(i) END;
		IF i = XXSmall THEN i := XXSmall + 1 END;
		RETURN AbsoluteFontSizes[i - 1]
	END GetSmallerFont;

	PROCEDURE GetLargerFont(fontSize: LONGINT): LONGINT;
	VAR i: SHORTINT;
	BEGIN
		i := XXLarge;
		WHILE (XXSmall <= i) & (fontSize < AbsoluteFontSizes[i]) DO DEC(i) END;
		IF i = XXLarge THEN i := XXLarge - 1 END;
		RETURN AbsoluteFontSizes[i + 1]
	END GetLargerFont;
*)

	PROCEDURE ListStyleImage(VAR listStyleImage: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(listStyleImage, term) & ~SetIdentOrInherit(listStyleImage, term) & ~SetNone(listStyleImage, term) THEN
			IF term.GetType() = CSS2.URI THEN listStyleImage := term
			END
		END
	END ListStyleImage;

	PROCEDURE ListStylePosition(VAR listStylePosition: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(listStylePosition, term) & ~SetIdentOrInherit(listStylePosition, term) THEN
			IF term.IsStringIdent("inside") THEN listStylePosition := ChangeToIdent(Inside)
			ELSIF term.IsStringIdent("outside") THEN listStylePosition := ChangeToIdent(Outside)
			END
		END
	END ListStylePosition;

	PROCEDURE ListStyleType(VAR listStyleType: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(listStyleType, term) & ~SetIdentOrInherit(listStyleType, term) OR ~SetNone(listStyleType, term) THEN
			IF term.IsStringIdent("disc") THEN listStyleType := ChangeToIdent(Disc)
			ELSIF term.IsStringIdent("circle") THEN listStyleType := ChangeToIdent(Circle)
			ELSIF term.IsStringIdent("square") THEN listStyleType := ChangeToIdent(Square)
			ELSIF term.IsStringIdent("decimal") THEN listStyleType := ChangeToIdent(Decimal)
			ELSIF term.IsStringIdent("decimal-leading-zero") THEN listStyleType := ChangeToIdent(DecimalLeadingZero)
			ELSIF term.IsStringIdent("lower-roman") THEN listStyleType := ChangeToIdent(LowerRoman)
			ELSIF term.IsStringIdent("upper-roman") THEN listStyleType := ChangeToIdent(UpperRoman)
			ELSIF term.IsStringIdent("lower-greek") THEN listStyleType := ChangeToIdent(LowerGreek)
			ELSIF term.IsStringIdent("lower-alpha") THEN listStyleType := ChangeToIdent(LowerAlpha)
			ELSIF term.IsStringIdent("lower-latin") THEN listStyleType := ChangeToIdent(LowerLatin)
			ELSIF term.IsStringIdent("upper-alpha") THEN listStyleType := ChangeToIdent(UpperAlpha)
			ELSIF term.IsStringIdent("upper-latin") THEN listStyleType := ChangeToIdent(UpperLatin)
			ELSIF term.IsStringIdent("hebrew") THEN listStyleType := ChangeToIdent(Hebrew)
			ELSIF term.IsStringIdent("armenian") THEN listStyleType := ChangeToIdent(Armenian)
			ELSIF term.IsStringIdent("georgian") THEN listStyleType := ChangeToIdent(Georgian)
			ELSIF term.IsStringIdent("cjk-ideographic") THEN listStyleType := ChangeToIdent(CjkIdeographic)
			ELSIF term.IsStringIdent("hiragana") THEN listStyleType := ChangeToIdent(Hiragana)
			ELSIF term.IsStringIdent("katakana") THEN listStyleType := ChangeToIdent(Katakana)
			ELSIF term.IsStringIdent("hiragana-iroha") THEN listStyleType := ChangeToIdent(HiraganaIroha)
			ELSIF term.IsStringIdent("katakana-iroha") THEN listStyleType := ChangeToIdent(KatakanaIroha)
			END
		END
	END ListStyleType;

	PROCEDURE MarginWidth(VAR position: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(position, term) & ~SetIdentOrInherit(position, term) THEN
			IF term.IsStringIdent("auto") THEN position := ChangeToIdent(Auto)
			ELSIF term.IsLength() OR (term.GetType() = CSS2.Percent) THEN position := term
			END
		END
	END MarginWidth;

	PROCEDURE MaxDimension(VAR dimension: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(dimension, term) & ~SetIdentOrInherit(dimension, term) OR ~SetNone(dimension, term) THEN
			IF term.IsLength() OR (term.GetType() = CSS2.Percent) THEN
				dimension := term
			END
		END
	END MaxDimension;

	PROCEDURE MinDimension(VAR dimension: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(dimension, term) & ~SetIdentOrInherit(dimension, term) THEN
			IF term.IsLength() OR (term.GetType() = CSS2.Percent) THEN
				dimension := term
			END
		END
	END MinDimension;

	PROCEDURE PaddingWidth(VAR position: CSS2.Term; term: CSS2.Term);
	BEGIN
		IF ~SetNil(position, term) & ~SetIdentOrInherit(position, term) THEN
			IF term.IsLength() OR (term.GetType() = CSS2.Percent) THEN position := term
			END
		END
	END PaddingWidth;

	PROCEDURE ComputeBool(VAR property: Bool; parentProperty: Bool; trueIdent: LONGINT);
	BEGIN
		IF property.specified # NIL THEN
			IF property.specified.IsIdent(Inherit) THEN property.computed := parentProperty.computed
			ELSE property.computed := property.specified.GetIntVal() = trueIdent
			END
		END
	END ComputeBool;

	PROCEDURE ComputeColor(VAR property: Color; parentProperty, initial: Color);
	BEGIN
		IF property.specified # NIL THEN
			IF property.specified.IsIdent(Inherit) THEN property.computed := parentProperty.computed
			ELSE property.specified.GetColor(property.computed.r, property.computed.g,
				property.computed.b, property.computed.a)
			END
		ELSE
			property := initial; property.specified := NIL
		END
	END ComputeColor;

	PROCEDURE ComputeImg(VAR property: Img; parentProperty: Img);
	VAR name: String; imgTerm: ImgTerm;
	BEGIN
		IF (property.specified # NIL) THEN
			IF property.specified IS ImgTerm THEN
				property.computed := property.specified(ImgTerm).img
			ELSIF property.specified.IsIdent(None) THEN
				property.computed := NIL
			ELSIF property.specified.IsIdent(Inherit) THEN
				property.computed := parentProperty.computed
			ELSE
				name := property.specified.GetStringVal();
				IF name # NIL THEN
					property.computed := WMGraphics.LoadImage(name^, TRUE);
					IF property.computed # NIL THEN
						NEW(imgTerm); imgTerm.img := property.computed; property.specified := imgTerm;
					ELSE property.computed := NIL
					END
				END
			END
		ELSE
			property.computed := NIL
		END
	END ComputeImg;

	PROCEDURE ComputeDim(VAR property: Dim; parentProperty: Dim; ppi, referenceDim: LONGREAL; font: GfxFonts.Font);
	BEGIN
		IF (property.specified # NIL) THEN
			IF property.specified.IsIdent(Inherit) THEN
				property.computed := parentProperty.computed
			ELSIF property.specified.IsIdent(Auto) THEN
				property.computed := DummyAuto
			ELSIF property.specified.GetType() = CSS2.Percent THEN
				property.computed := property.specified.GetRealVal() * referenceDim
			ELSIF property.specified.IsLength() THEN
				property.computed := GetPixels(property.specified, ppi, font)
			END
		END
	END ComputeDim;

	PROCEDURE ComputeIdent(VAR property: Ident; parentProperty: Ident);
	BEGIN
		IF (property.specified # NIL) THEN
			IF property.specified.IsIdent(Inherit) THEN
				property.computed := parentProperty.computed
			ELSE
				property.computed := SHORT(SHORT(property.specified.GetIntVal()))
			END
		END
	END ComputeIdent;

	PROCEDURE ComputeCursor(VAR property: Cursor; parentProperty: Cursor);
	VAR terms: XMLObjects.Enumerator; term: ANY; s: String;
	BEGIN
		IF property.specified # NIL THEN
			terms := property.specified.GetEnumerator();
			term := terms.GetNext();
			IF term(CSS2.Term).GetType() = CSS2.Ident THEN
				CASE term(CSS2.Term).GetIntVal() OF
				| Inherit: property.computed := parentProperty.computed
				| Auto: property.computed := defaultCursor
				| Default: property.computed := defaultCursor
				| Crosshair: property.computed := crosshairCursor
				| Pointer: property.computed := pointerCursor
				| Move: property.computed := moveCursor
				| EResize: property.computed := eResizeCursor
				| NEResize: property.computed := neResizeCursor
				| NWResize: property.computed := nwResizeCursor
				| NResize: property.computed := nResizeCursor
				| SEResize: property.computed := seResizeCursor
				| SWResize: property.computed := swResizeCursor
				| SResize: property.computed := sResizeCursor
				| WResize: property.computed := wResizeCursor
				| Text: property.computed := textCursor
				| Wait: property.computed := waitCursor
				| Help: property.computed := helpCursor
				ELSE
				END
			ELSIF term(CSS2.Term).GetType() = CSS2.URI THEN
				terms := property.specified.GetEnumerator();
				REPEAT
					term := terms.GetNext();
					s := term(CSS2.Term).GetStringVal();
					IF s # NIL THEN
						NEW(property.computed);
						property.computed.img := WMGraphics.LoadImage( s^, TRUE);
					END
				UNTIL ~terms.HasMoreElements() OR (property.computed # NIL)
			END
		END;
	END ComputeCursor;

	PROCEDURE SetZeroIfAutoSize(size: Dim);
	BEGIN
		IF IsAutoSize(size) THEN size.computed := 0.0 END
	END SetZeroIfAutoSize;

	PROCEDURE SetZeroIfAutoMargin(size: Dim);
	BEGIN
		IF IsAutoMargin(size) THEN size.computed := 0.0 END
	END SetZeroIfAutoMargin;

	PROCEDURE ToGfxColor*(color: Color): Gfx.Color;
	VAR c: Gfx.Color;
	BEGIN
		c.r := ORD(color.computed.r); c.g := ORD(color.computed.g); c.b := ORD(color.computed.b); c.a := ORD(color.computed.a);
		RETURN c
	END ToGfxColor;

	PROCEDURE IntToColor(color: LONGINT): Color;
	VAR c1: CSS2.Term; c2: Color;
	BEGIN
		NEW(c1); c1.SetType(CSS2.Color); c1.SetIntVal(color);
		c1.GetColor(c2.computed.r, c2.computed.g, c2.computed.b, c2.computed.a);
		RETURN c2
	END IntToColor;


BEGIN
	AbsoluteFontSizes[XXSmall] := 6;
	AbsoluteFontSizes[XSmall] := 8;
	AbsoluteFontSizes[Small] := 10;
	AbsoluteFontSizes[Medium] := 12;
	AbsoluteFontSizes[Large] := 16;
	AbsoluteFontSizes[XLarge] := 20;
	AbsoluteFontSizes[XXLarge] := 24;
	defaultColor := Black;
	m := WMWindowManager.GetDefaultManager();
	defaultCursor := m.pointerStandard;
	crosshairCursor := m.pointerStandard;
	pointerCursor := m.pointerStandard;
	moveCursor := m.pointerMove;
	eResizeCursor := m.pointerMove;
	neResizeCursor := m.pointerMove;
	nwResizeCursor := m.pointerMove;
	nResizeCursor := m.pointerMove;
	seResizeCursor := m.pointerMove;
	swResizeCursor := m.pointerMove;
	sResizeCursor := m.pointerMove;
	wResizeCursor := m.pointerMove;
	textCursor := m.pointerStandard;
	waitCursor := m.pointerStandard;
	helpCursor := m.pointerStandard;
	defaultFont := GfxFonts.Default;
	captionFont := GfxFonts.Default;
	iconFont := GfxFonts.Default;
	menuFont := GfxFonts.Default;
	messageBoxFont := GfxFonts.Default;
	smallCaptionFont := GfxFonts.Default;
	statusBarFont := GfxFonts.Default;
	thinBorder := 1.0;
	mediumBorder := 3.0;
	thickBorder := 5.0;
END CSS2Properties.