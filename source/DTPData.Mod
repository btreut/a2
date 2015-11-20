MODULE DTPData; (** AUTHOR "PL"; PURPOSE "Data Model for simple DTP Editor"; *)

IMPORT
	Files, XML, WMGraphics, Strings, WMWindowManager; (* , DTPFrame; *)

CONST

TYPE

	MetaInformation* = OBJECT
	VAR
		author*, documentName*, documentTitle* : Strings.String;

	END MetaInformation;

	StyleObject* = OBJECT
	VAR name*: ARRAY 64 OF CHAR;				(* unique style name *)

	END StyleObject;

	ParagraphStyleObject* = OBJECT(StyleObject)
	VAR alignment* : LONGINT;						(* 0 = left, 1 = center, 2 = right, 3 = justified *)
		spaceBefore* : REAL;						(* space before paragraph [mm] *)
		spaceAfter* : REAL;							(* space after paragrapg [mm] *)
		leftIndent* : REAL;							(* left Indent [mm] *)
		rightIndent* : REAL;							(* right Indent [mm] *)
		firstIndent* : REAL;							(* first Line Indent [mm] *)
		charStyle* : CharacterStyleObject;

		PROCEDURE Clone*(): ParagraphStyleObject;
		VAR newPSO: ParagraphStyleObject;
		BEGIN
			NEW(newPSO);
			newPSO.name := name;
			newPSO.alignment := alignment;
			newPSO.spaceBefore := spaceBefore;
			newPSO.spaceAfter := spaceAfter;
			newPSO.firstIndent := firstIndent;
			newPSO.leftIndent := leftIndent;
			newPSO.rightIndent := rightIndent;
			newPSO.charStyle := charStyle;
			RETURN newPSO;
		END Clone;

	END ParagraphStyleObject;

	CharacterStyleObject* = OBJECT(StyleObject)
	VAR family* : ARRAY 32 OF CHAR;				(* font family *)
		style* : SET;									(* font style; 0 = bold, 1 = italic *)
		size* : REAL;								(* font size [pt]; 1pt == 1/72inch == 0,3527777778mm *)
		leading* : REAL;								(* baseline distance [pt] - usually 120% of font size *)
		baselineShift* : REAL;						(* baseline shift up/down [pt] *)
		tracking* : REAL;							(* character spacing [pt] *)
		kerning* : REAL;								(* NOT USED - needs appropriate Fonts *)
		scaleHorizontal* : REAL;						(* horizontal character scale *)
		scaleVertical* : REAL;						(* vertical character scale *)
		color* : LONGINT;							(* character color *)
		bgColor* : LONGINT;						(* character background color *)

		PROCEDURE Clone*(): CharacterStyleObject;
		VAR newCSO: CharacterStyleObject;
		BEGIN
			NEW(newCSO);
			newCSO.name := name;
			newCSO.family := family;
			newCSO.style := style;
			newCSO.size := size;
			newCSO.leading := leading;
			newCSO.baselineShift := baselineShift;
			newCSO.color := color;
			newCSO.bgColor := bgColor;
			newCSO.tracking := tracking;
			newCSO.kerning := kerning;
			newCSO.scaleHorizontal := scaleHorizontal;
			newCSO.scaleVertical := scaleVertical;
			RETURN newCSO;
		END Clone;

	END CharacterStyleObject;

	GraphicStyleObject* = OBJECT(StyleObject)
	VAR 											(* NOT IMPLEMENTED ;-) do it yourself *)

	END GraphicStyleObject;

	CustomStyleObject* = OBJECT(StyleObject)
	VAR 											(* NOT IMPLEMENTED ;-) do it yourself *)

	END CustomStyleObject;

	PStyles* = POINTER TO ARRAY OF ParagraphStyleObject;
	CStyles* = POINTER TO ARRAY OF CharacterStyleObject;
	GStyles* = POINTER TO ARRAY OF GraphicStyleObject;
	CustomStyles* = POINTER TO ARRAY OF CustomStyleObject;

	(* root for the data - all units in [mm] *)
	Document* = OBJECT
	VAR
		pageWidth, pageHeight : REAL;
		marginTop, marginBottom, marginLeft, marginRight : REAL;
		facingPages : BOOLEAN;
		meta : MetaInformation;
		objectCounter*: LONGINT;
		copyCounter*: LONGINT;

		nofPStyles*: LONGINT;
		pStyles* : PStyles;
		nofCStyles*: LONGINT;
		cStyles* : CStyles;
		nofGStyles*: LONGINT;
		gStyles* : GStyles;
		nofCustomStyles*: LONGINT;
		customStyles* : CustomStyles;
		defaultParagraphStyle* : ParagraphStyleObject;
		defaultCharacterStyle* : CharacterStyleObject;
		defaultGraphicStyle* : GraphicStyleObject;
		defaultCustomStyle* : CustomStyleObject;

		pages* : ContentPages;
		mpages* : MasterPages;
		contents* : Contents; nofContents* : LONGINT;
		frames* : Frames;

		(* dollyFrame* : FrameObject; *)
		dollyGuide* : GuideObject;

		currentPage*, firstPage*, lastPage* : PageObject;
		pageNumber*, nofPages* : LONGINT;

		currentMPage*, firstMPage*, lastMPage* : MasterPageObject;
		mpageNumber*, nofMPages* : LONGINT;

		PROCEDURE &New*(width, height, margintop,marginbottom, marginleft, marginright : REAL; facingpages : BOOLEAN);
		VAR
		BEGIN
			pageWidth := width;
			pageHeight := height;
			marginTop := margintop;
			marginBottom := marginbottom;
			marginLeft := marginleft;
			marginRight := marginright;
			facingPages := facingpages;

			currentPage := NIL;
			firstPage := NIL;
			lastPage := NIL;
			pageNumber := 0;
			nofPages := 0;

			currentMPage := NIL;
			firstMPage := NIL;
			lastMPage := NIL;
			mpageNumber := 0;
			nofMPages := 0;

			(* dollyFrame := NIL; *)
			dollyGuide := NIL;
			objectCounter := 0; copyCounter := 0;

			NEW(pStyles, 4); nofPStyles := 0;
			NEW(cStyles, 4); nofCStyles := 0;
			NEW(gStyles, 4); nofGStyles := 0;
			NEW(customStyles, 4); nofCustomStyles := 0;
			AddDefaultStyles;
			NEW(contents, 4); nofContents := 0;

		END New;

		PROCEDURE AddDefaultStyles;
		VAR newPStyle: ParagraphStyleObject;
			newCStyle: CharacterStyleObject;
		BEGIN
			NEW(newCStyle);
			newCStyle.name := "defaultCharacterStyle";
			newCStyle.family := "Oberon";
			newCStyle.style := {};
			newCStyle.size := 16;
			newCStyle.leading := 19;
			newCStyle.baselineShift := 0;
			newCStyle.tracking := 0;
			newCStyle.kerning := 0;
			newCStyle.scaleHorizontal := 100;
			newCStyle.scaleVertical := 100;
			newCStyle.color := 0000000FFH;
			newCStyle.bgColor := LONGINT(0FFFFFF00H);

			NEW(newPStyle);
			newPStyle.name := "defaultParagraphStyle";
			newPStyle.alignment := 0;						(* Left Align *)
			newPStyle.spaceBefore := 0;
			newPStyle.spaceAfter := 0;
			newPStyle.leftIndent := 0;
			newPStyle.rightIndent := 0;
			newPStyle.firstIndent := 0;
			newPStyle.charStyle := newCStyle;

			defaultCharacterStyle := newCStyle;
			defaultParagraphStyle := newPStyle;
			AddStyle(newCStyle);
			AddStyle(newPStyle);

		END AddDefaultStyles;

		PROCEDURE AddStyle*(style: StyleObject);
		VAR newPStyles: PStyles;
			newCStyles: CStyles;
			newGStyles: GStyles;
			newCustomStyles: CustomStyles;
			pStyle: ParagraphStyleObject;
			cStyle: CharacterStyleObject;
			i : LONGINT;
		BEGIN
			IF (style IS ParagraphStyleObject) THEN
				pStyle := GetParagraphStyleByName(style.name);
				IF (pStyle = NIL) THEN										(* no style with that name - create one *)
					INC(nofPStyles);
					IF nofPStyles > LEN(pStyles) THEN
						NEW(newPStyles, LEN(pStyles) * 2);
						FOR i := 0 TO LEN(pStyles)-1 DO newPStyles[i] := pStyles[i]; END;
						pStyles := newPStyles;
					END;
					pStyles[nofPStyles-1] := style(ParagraphStyleObject);
				ELSE														(* style with that name already exists - update *)
					pStyle.alignment := style(ParagraphStyleObject).alignment;
					pStyle.firstIndent := style(ParagraphStyleObject).firstIndent;
					pStyle.leftIndent := style(ParagraphStyleObject).leftIndent;
					pStyle.rightIndent := style(ParagraphStyleObject).rightIndent;
					pStyle.spaceBefore := style(ParagraphStyleObject).spaceBefore;
					pStyle.spaceAfter := style(ParagraphStyleObject).spaceAfter;
					pStyle.charStyle := style(ParagraphStyleObject).charStyle;
				END;
			ELSIF (style IS CharacterStyleObject) THEN
				cStyle := GetCharacterStyleByName(style.name);
				IF (cStyle = NIL) THEN										(* no style with that name - create one *)
					INC(nofCStyles);
					IF nofCStyles > LEN(cStyles) THEN
						NEW(newCStyles, LEN(cStyles) * 2);
						FOR i := 0 TO LEN(cStyles)-1 DO newCStyles[i] := cStyles[i]; END;
						cStyles := newCStyles;
					END;
					cStyles[nofCStyles-1] := style(CharacterStyleObject);
				ELSE														(* style with that name already exists - update *)
					COPY(style(CharacterStyleObject).family, cStyle.family);
					cStyle.size := style(CharacterStyleObject).size;
					cStyle.style := style(CharacterStyleObject).style;
					cStyle.leading := style(CharacterStyleObject).leading;
					cStyle.baselineShift := style(CharacterStyleObject).baselineShift;
					cStyle.color := style(CharacterStyleObject).color;
					cStyle.bgColor := style(CharacterStyleObject).bgColor;
					cStyle.tracking := style(CharacterStyleObject).tracking;
					cStyle.kerning := style(CharacterStyleObject).kerning;
					cStyle.scaleHorizontal := style(CharacterStyleObject).scaleHorizontal;
					cStyle.scaleVertical := style(CharacterStyleObject).scaleVertical;
				END;
			ELSIF (style IS GraphicStyleObject) THEN
				INC(nofGStyles);
				IF nofGStyles > LEN(gStyles) THEN
					NEW(newGStyles, LEN(gStyles) * 2);
					FOR i := 0 TO LEN(gStyles)-1 DO newGStyles[i] := gStyles[i]; END;
					gStyles := newGStyles;
				END;
				gStyles[nofGStyles-1] := style(GraphicStyleObject);
			ELSIF (style IS CustomStyleObject) THEN
				INC(nofCustomStyles);
				IF nofCustomStyles > LEN(customStyles) THEN
					NEW(newCustomStyles, LEN(customStyles) * 2);
					FOR i := 0 TO LEN(customStyles)-1 DO newCustomStyles[i] := customStyles[i]; END;
					customStyles := newCustomStyles;
				END;
				customStyles[nofCustomStyles-1] := style(CustomStyleObject);
			ELSE
			END;
		END AddStyle;

		PROCEDURE RemoveStyle*(style: StyleObject);
		VAR i : LONGINT;
		BEGIN
			IF (style IS ParagraphStyleObject) THEN
				IF (style(ParagraphStyleObject).name # "defaultParagraphStyle") THEN
					i := 0; WHILE (i < nofPStyles) & (pStyles[i] # style(ParagraphStyleObject)) DO INC(i) END;
					IF i < nofPStyles THEN
						WHILE (i < nofPStyles-1) DO pStyles[i] := pStyles[i+1]; INC(i); END;
						DEC(nofPStyles);
						pStyles[nofPStyles] := NIL;
					END;
				END;
			ELSIF (style IS CharacterStyleObject) THEN
				IF (style(CharacterStyleObject).name # "defaultCharacterStyle") THEN
					i := 0; WHILE (i < nofCStyles) & (cStyles[i] # style(CharacterStyleObject)) DO INC(i) END;
					IF i < nofCStyles THEN
						WHILE (i < nofCStyles-1) DO cStyles[i] := cStyles[i+1]; INC(i); END;
						DEC(nofCStyles);
						cStyles[nofCStyles] := NIL;
					END;
				END;
			ELSIF (style IS GraphicStyleObject) THEN
				IF (style(GraphicStyleObject) # defaultGraphicStyle) THEN
					i := 0; WHILE (i < nofGStyles) & (gStyles[i] # style(GraphicStyleObject)) DO INC(i) END;
					IF i < nofGStyles THEN
						WHILE (i < nofGStyles-1) DO gStyles[i] := gStyles[i+1]; INC(i); END;
						DEC(nofGStyles);
						gStyles[nofGStyles] := NIL;
					END;
				END;
			ELSIF (style IS CustomStyleObject) THEN
				IF (style(CustomStyleObject) # defaultCustomStyle) THEN
					i := 0; WHILE (i < nofCustomStyles) & (customStyles[i] # style(CustomStyleObject)) DO INC(i) END;
					IF i < nofCustomStyles THEN
						WHILE (i < nofCustomStyles-1) DO customStyles[i] := customStyles[i+1]; INC(i); END;
						DEC(nofCustomStyles);
						customStyles[nofCustomStyles] := NIL;
					END;
				END;
			ELSE
			END;
		END RemoveStyle;

		PROCEDURE GetCharacterStyleByName*(name: ARRAY OF CHAR): CharacterStyleObject;
		VAR styleObject: CharacterStyleObject;
			i : LONGINT;
			found : BOOLEAN;
			match: Strings.String;
		BEGIN
			styleObject := NIL;
			i := 0; found := FALSE;
			WHILE ((i < nofCStyles) & ~found) DO
				match := Strings.NewString(cStyles[i].name);
				IF Strings.Match(match^, name) THEN
					styleObject := cStyles[i]; found := TRUE;
				END;
				INC(i);
			END;
			RETURN styleObject;
		END GetCharacterStyleByName;

		PROCEDURE GetParagraphStyleByName*(name: ARRAY OF CHAR): ParagraphStyleObject;
		VAR styleObject: ParagraphStyleObject;
			i : LONGINT;
			found : BOOLEAN;
			match: Strings.String;
		BEGIN
			styleObject := NIL;
			i := 0; found := FALSE;
			WHILE ((i < nofPStyles) & ~found) DO
				match := Strings.NewString(pStyles[i].name);
				IF Strings.Match(match^, name) THEN
					styleObject := pStyles[i]; found := TRUE;
				END;
				INC(i);
			END;
			RETURN styleObject;
		END GetParagraphStyleByName;

		PROCEDURE AddContent*(content: ContentObject);
		VAR newContents: Contents;
			i : LONGINT;
		BEGIN
			INC(nofContents); (* INC(objectCounter); *)
			IF nofContents > LEN(contents) THEN
				NEW(newContents, LEN(contents) * 2);
				FOR i := 0 TO LEN(contents)-1 DO newContents[i] := contents[i]; END;
				contents := newContents;
			END;
			contents[nofContents-1] := content;
		END AddContent;

		PROCEDURE RemoveContent*(content: ContentObject);
		VAR i : LONGINT;
		BEGIN
			i := 0; WHILE (i < nofContents) & (contents[i] # content) DO INC(i) END;
			IF i < nofContents THEN
				WHILE (i < nofContents-1) DO contents[i] := contents[i+1]; INC(i); END;
				DEC(nofContents);
				contents[nofContents] := NIL;
			END;
		END RemoveContent;

		PROCEDURE GetContentByName*(name: ARRAY OF CHAR): ContentObject;
		VAR contentObject: ContentObject;
			i : LONGINT;
			found : BOOLEAN;
			match: Strings.String;
		BEGIN
			contentObject := NIL;
			i := 0; found := FALSE;
			WHILE ((i < nofContents) & ~found) DO
				match := contents[i].contentName;
				IF Strings.Match(match^, name) THEN
					contentObject := contents[i]; found := TRUE;
				END;
				INC(i);
			END;
			RETURN contentObject;
		END GetContentByName;

		PROCEDURE FixContents*;							(* loop over all contents and fix the links *)
		VAR contentObject: ContentObject;
			i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < nofContents) DO
				contentObject := contents[i];
				contentObject.FixLinks;
				INC(i);
			END;
		END FixContents;

		PROCEDURE FixName*(name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
		VAR counterString : ARRAY 64 OF CHAR;
		BEGIN
			COPY(name, result);
			Strings.Append(result, "c");
			Strings.IntToStr(copyCounter, counterString);
			Strings.Append(result, counterString);
			INC(copyCounter);
			WHILE (GetContentByName(result) # NIL) DO
				Strings.IntToStr(copyCounter, counterString);
				Strings.Append(result, counterString);
				INC(copyCounter);
			END;
		END FixName;

		PROCEDURE AddPage*(after : BOOLEAN);
		VAR newpage : PageObject;
		BEGIN
			NEW(newpage);
			IF lastPage = NIL THEN 							(* document was empty *)
				firstPage := newpage;
				lastPage := newpage;
				INC(pageNumber);
			ELSE											(* there were already pages *)

				IF after THEN 								(* add after current page *)
					newpage.next := currentPage.next;
					currentPage.next := newpage;
					newpage.prev := currentPage;
					IF newpage.next = NIL THEN 			(* current was last page *)
						lastPage := newpage;
					ELSE
						newpage.next.prev := newpage;		(* current was not last page *)
					END;
					INC(pageNumber);
				ELSE										(* add before current page *)
					newpage.prev := currentPage.prev;
					currentPage.prev := newpage;
					newpage.next := currentPage;
					IF newpage.prev = NIL THEN				(* current was first page *)
						firstPage := newpage;
					ELSE
						newpage.prev.next := newpage;		(* current was not first page *)
					END;
				END;

			END;
			currentPage := newpage;						(* change current page *)
			INC(nofPages);
			currentPage.SetOwner(SELF);
			(* UpdatePageNumber; *)
		END AddPage;

		PROCEDURE DeletePage*;
		VAR
		BEGIN
			IF currentPage.prev # NIL THEN					(* not first *)
				IF currentPage.next # NIL THEN				(* not last *)
					currentPage.prev.next := currentPage.next;
					currentPage.next.prev := currentPage.prev;
					currentPage := currentPage.next;
					IF currentPage.prev = NIL THEN firstPage := currentPage; END;
					IF currentPage.next = NIL THEN lastPage := currentPage; END;
					DEC(nofPages);
				ELSE										(* last *)
					currentPage.prev.next := currentPage.next;
					currentPage := currentPage.prev;
					IF currentPage.prev = NIL THEN firstPage := currentPage; END;
					lastPage := currentPage;
					DEC(nofPages); DEC(pageNumber);
				END;
			ELSE											(* first *)
				IF currentPage.next # NIL THEN				(* you can only delete if more than 1 page left *)
					currentPage.next.prev := currentPage.prev;
					currentPage := currentPage.next;
					firstPage := currentPage;
					IF currentPage.next = NIL THEN lastPage := currentPage; END;
					DEC(nofPages);
				END;
			END;
			(* UpdatePageNumber; *)
		END DeletePage;

		PROCEDURE NextPage*;
		BEGIN
			IF currentPage.next # NIL THEN
				currentPage := currentPage.next;
				INC(pageNumber);
			END;
			(* UpdatePageNumber; *)
		END NextPage;

		PROCEDURE PrevPage*;
		BEGIN
			IF currentPage.prev # NIL THEN
				currentPage := currentPage.prev;
				DEC(pageNumber);
			END;
			(* UpdatePageNumber; *)
		END PrevPage;

		PROCEDURE FirstPage*;
		BEGIN
			currentPage := firstPage;
			pageNumber := 1;
			(* UpdatePageNumber; *)
		END FirstPage;

		PROCEDURE LastPage*;
		BEGIN
			currentPage := lastPage;
			pageNumber := nofPages;
			(* UpdatePageNumber; *)
		END LastPage;

		PROCEDURE AddMasterPage*(after: BOOLEAN);
		VAR newpage : MasterPageObject;
		BEGIN
			NEW(newpage);
			IF lastMPage = NIL THEN 						(* document was empty *)
				firstMPage := newpage;
				lastMPage := newpage;
				INC(mpageNumber);
			ELSE											(* there were already pages *)

				IF after THEN 								(* add after current page *)
					newpage.next := currentMPage.next;
					currentMPage.next := newpage;
					newpage.prev := currentMPage;
					IF newpage.next = NIL THEN 			(* current was last page *)
						lastMPage := newpage;
					ELSE
						newpage.next.prev := newpage;		(* current was not last page *)
					END;
					INC(mpageNumber);
				ELSE										(* add before current page *)
					newpage.prev := currentMPage.prev;
					currentMPage.prev := newpage;
					newpage.next := currentMPage;
					IF newpage.prev = NIL THEN				(* current was first page *)
						firstMPage := newpage;
					ELSE
						newpage.prev.next := newpage;		(* current was not first page *)
					END;
				END;

			END;
			currentMPage := newpage;						(* change current page *)
			INC(nofMPages);
			currentMPage.SetOwner(SELF);
		END AddMasterPage;

		PROCEDURE DeleteMasterPage*;
		BEGIN
			IF currentMPage.prev # NIL THEN					(* not first *)
				IF currentMPage.next # NIL THEN				(* not last *)
					currentMPage.prev.next := currentMPage.next;
					currentMPage.next.prev := currentMPage.prev;
					currentMPage := currentMPage.next;
					IF currentMPage.prev = NIL THEN firstMPage := currentMPage; END;
					IF currentMPage.next = NIL THEN lastMPage := currentMPage; END;
					DEC(nofMPages);
				ELSE										(* last *)
					currentMPage.prev.next := currentMPage.next;
					currentMPage := currentMPage.prev;
					IF currentMPage.prev = NIL THEN firstMPage := currentMPage; END;
					lastMPage := currentMPage;
					DEC(nofMPages); DEC(mpageNumber);
				END;
			ELSE											(* first *)
				IF currentMPage.next # NIL THEN				(* you can only delete if more than 1 page left *)
					currentMPage.next.prev := currentMPage.prev;
					currentMPage := currentMPage.next;
					firstMPage := currentMPage;
					IF currentMPage.next = NIL THEN lastMPage := currentMPage; END;
					DEC(nofMPages);
				END;
			END;

		END DeleteMasterPage;

		PROCEDURE NextMasterPage*;
		BEGIN
			IF currentMPage.next # NIL THEN
				currentMPage := currentMPage.next;
				INC(mpageNumber);
			END;

		END NextMasterPage;

		PROCEDURE PrevMasterPage*;
		BEGIN
			IF currentMPage.prev # NIL THEN
				currentMPage := currentMPage.prev;
				DEC(mpageNumber);
			END;

		END PrevMasterPage;

		PROCEDURE FirstMasterPage*;
		BEGIN
			currentMPage := firstMPage;
			mpageNumber := 1;

		END FirstMasterPage;

		PROCEDURE LastMasterPage*;
		BEGIN
			currentMPage := lastMPage;
			mpageNumber := nofMPages;

		END LastMasterPage;

		PROCEDURE SetPageWidth*(pagewidth : REAL);
		BEGIN
			pageWidth := pagewidth;
		END SetPageWidth;

		PROCEDURE GetPageWidth*(): REAL;
		BEGIN
			RETURN pageWidth
		END GetPageWidth;

		PROCEDURE SetPageHeight*(pageheight : REAL);
		BEGIN
			pageHeight := pageheight;
		END SetPageHeight;

		PROCEDURE GetPageHeight*(): REAL;
		BEGIN
			RETURN pageHeight
		END GetPageHeight;

		PROCEDURE SetMargins*(top, bottom, left, right : REAL);
		BEGIN
			marginTop := top;
			marginBottom := bottom;
			marginLeft := left;
			marginRight := right;

		END SetMargins;

		PROCEDURE GetMarginTop*(): REAL;
		BEGIN
			RETURN marginTop
		END GetMarginTop;

		PROCEDURE GetMarginBottom*() : REAL;
		BEGIN
			RETURN marginBottom
		END GetMarginBottom;

		PROCEDURE GetMarginLeft*(): REAL;
		BEGIN
			RETURN marginLeft
		END GetMarginLeft;

		PROCEDURE GetMarginRight*(): REAL;
		BEGIN
			RETURN marginRight
		END GetMarginRight;

		PROCEDURE SetFacingPages*(fpages : BOOLEAN);
		BEGIN
			facingPages := fpages;
		END SetFacingPages;

		PROCEDURE GetFacingPages*(): BOOLEAN;
		BEGIN
			RETURN facingPages
		END GetFacingPages;

		PROCEDURE GetCurrentPage*(): PageObject;
		BEGIN
			RETURN currentPage;
		END GetCurrentPage;

		PROCEDURE GetFirstPage*(): PageObject;
		BEGIN
			RETURN firstPage;
		END GetFirstPage;

		PROCEDURE GetLastPage*(): PageObject;
		BEGIN
			RETURN lastPage;
		END GetLastPage;

		PROCEDURE GetCurrentMasterPage*(): MasterPageObject;
		BEGIN
			RETURN currentMPage;
		END GetCurrentMasterPage;

		PROCEDURE GetFirstMasterPage*(): MasterPageObject;
		BEGIN
			RETURN firstMPage;
		END GetFirstMasterPage;

		PROCEDURE GetLastMasterPage*(): MasterPageObject;
		BEGIN
			RETURN lastMPage;
		END GetLastMasterPage;

		PROCEDURE GetMasterByName*(name: Strings.String): MasterPageObject;
		VAR page, result: MasterPageObject;
			match: Strings.String;
		BEGIN
			result := NIL;
			IF name # NIL THEN
				page := GetFirstMasterPage();
				WHILE page # NIL DO
					match := page.GetName();
					(* KernelLog.String(match^); *)
					IF (match # NIL) & Strings.Match(match^, name^) THEN
						result := page;
					END;
					page := page.next;
				END;
			END;
			RETURN result;
		END GetMasterByName;

		PROCEDURE GetCurrentPageNumber*(): LONGINT;
		BEGIN
			RETURN pageNumber;
		END GetCurrentPageNumber;

		PROCEDURE GetCurrentMasterPageNumber*(): LONGINT;
		BEGIN
			RETURN mpageNumber;
		END GetCurrentMasterPageNumber;

	END Document;

	PageObject* = OBJECT
	VAR
		ownerDocument* : Document;
		masterpage* : MasterPageObject;
		next*, prev* : PageObject;
		firstFrame*, lastFrame*, currentFrame* : FrameObject;
		firstGuide*, lastGuide*, currentGuide* : GuideObject;

		PROCEDURE SetOwner*(doc: Document);
		BEGIN
			ownerDocument := doc;
		END SetOwner;

		PROCEDURE &New*;
		VAR
		BEGIN
			firstFrame := NIL; lastFrame := NIL; currentFrame := NIL;
			firstGuide := NIL; lastGuide := NIL; currentGuide := NIL;
			next := NIL; prev := NIL;
			masterpage := NIL;
		END New;

		PROCEDURE SetMasterPage*(master: MasterPageObject);
		BEGIN
			masterpage := master;
		END SetMasterPage;

		PROCEDURE GetMasterPage*(): MasterPageObject;
		BEGIN
			RETURN masterpage;
		END GetMasterPage;

		PROCEDURE AddFrame*(x, y, w, h : REAL);
		VAR newframe : FrameObject;
		BEGIN
			(* new Frames are added at last position (top) *)
			NEW(newframe); newframe.SetExtent(x,y,w,h);
			IF lastFrame = NIL THEN							(* First frame added *)
				firstFrame := newframe;
				lastFrame := newframe;
			ELSE											(* not first frame added *)
				newframe.prev := lastFrame;
				lastFrame.next := newframe;
				lastFrame := newframe;
			END;
			currentFrame := newframe;						(* change current frame *)

		END AddFrame;

		PROCEDURE InsertFrame*(frame: FrameObject);		(* insert the given frame at front *)
		VAR name : Strings.String;
			content: ContentObject;
			temp: ARRAY 64 OF CHAR;
		BEGIN
			(* check if name of given frame is in use, add content to list *)
			name := frame.GetName();
			content := ownerDocument.GetContentByName(name^);
			IF content # NIL THEN
				ownerDocument.FixName(name^, temp); name := Strings.NewString(temp);
				frame.SetName(name);
				content := frame.GetContent();
				content.contentName := name;
			ELSE
				content := frame.GetContent();
			END;
			ownerDocument.AddContent(content);
			(* insert frame in page *)
			IF lastFrame = NIL THEN							(* First frame added *)
				firstFrame := frame;
				lastFrame := frame;
			ELSE											(* not first frame added *)
				frame.prev := lastFrame;
				lastFrame.next := frame;
				lastFrame := frame;
			END;
			currentFrame := frame;						(* change current frame *)
		END InsertFrame;

		PROCEDURE DeleteFrame*;
		VAR name: Strings.String;
			content: ContentObject;
		BEGIN
			IF currentFrame # NIL THEN
				(* remove content first *)
				name := currentFrame.GetName();
				content := ownerDocument.GetContentByName(name^);
				IF content # NIL THEN
					ownerDocument.RemoveContent(content);
				END;
				(* remove frame *)
				IF (currentFrame.prev = NIL) & (currentFrame.next = NIL) THEN	(* only this frame left *)
					currentFrame := NIL;
					firstFrame := NIL;
					lastFrame := NIL;
				ELSIF currentFrame.prev = NIL THEN				(* frame at back *)
					currentFrame.next.prev := currentFrame.prev;
					currentFrame := currentFrame.next;
					firstFrame := currentFrame;
				ELSIF currentFrame.next = NIL THEN				(* frame at front *)
					currentFrame.prev.next := currentFrame.next;
					currentFrame := currentFrame.prev;
					lastFrame := currentFrame;
				ELSE											(* frame in between *)
					currentFrame.prev.next := currentFrame.next;
					currentFrame.next.prev := currentFrame.prev;
					currentFrame := currentFrame.prev;
				END;
			END;
		END DeleteFrame;

		PROCEDURE NextFrame*;
		BEGIN
			IF (currentFrame # NIL) & (currentFrame.next # NIL) THEN
				currentFrame := currentFrame.next;
			END;
		END NextFrame;

		PROCEDURE PrevFrame*;
		BEGIN
			IF (currentFrame # NIL) & (currentFrame.prev # NIL) THEN
				currentFrame := currentFrame.prev;
			END
		END PrevFrame;

		PROCEDURE AddGuide*(position : REAL; horizontal : BOOLEAN);
		VAR newguide : GuideObject;
		BEGIN
			NEW(newguide, position, horizontal);
			IF lastGuide = NIL THEN							(* first Guide added *)
				firstGuide := newguide;
				lastGuide := newguide;
			ELSE											(* guides are added on top *)
				newguide.prev := lastGuide;
				lastGuide.next := newguide;
				lastGuide := newguide;
			END;
			currentGuide := newguide;						(* change Guide *)
		END AddGuide;

		PROCEDURE DeleteGuide*;
		BEGIN
			IF currentGuide # NIL THEN
				IF (currentGuide.prev = NIL) & (currentGuide.next = NIL) THEN		(* one and only guide *)
					firstGuide := NIL;
					lastGuide := NIL;
					currentGuide := NIL;
				ELSIF (currentGuide.prev = NIL) THEN			(* first guide *)
					currentGuide.next.prev := currentGuide.prev;
					firstGuide := currentGuide.next;
					currentGuide := currentGuide.next;
				ELSIF (currentGuide.next = NIL) THEN			(* last guide *)
					currentGuide.prev.next := currentGuide.next;
					lastGuide := currentGuide.prev;
					currentGuide := currentGuide.prev;
				ELSE											(* between guide *)
					currentGuide.prev.next := currentGuide.next;
					currentGuide.next.prev := currentGuide.prev;
				END;
			END;
		END DeleteGuide;

		PROCEDURE Move2Front*;
		BEGIN
			IF currentFrame # NIL THEN
				IF (currentFrame.prev = NIL) & (currentFrame.next = NIL) THEN	(* one and only frame *)
					firstFrame := currentFrame;
				ELSIF (currentFrame.next = NIL) THEN				(* last frame *)
					(* do nothing *)
				ELSIF (currentFrame.prev = NIL) THEN				(* first frame *)
					currentFrame.next.prev := currentFrame.prev;
					firstFrame := currentFrame.next;
					lastFrame.next := currentFrame;
					currentFrame.prev := lastFrame;
					currentFrame.next := NIL;
				ELSE												(* between *)
					currentFrame.prev.next := currentFrame.next;
					currentFrame.next.prev := currentFrame.prev;
					lastFrame.next := currentFrame;
					currentFrame.prev := lastFrame;
					currentFrame.next := NIL;
				END;
				lastFrame := currentFrame;
			END;
		END Move2Front;

		PROCEDURE Move2Back*;
		VAR
		BEGIN
			IF currentFrame # NIL THEN
				IF (currentFrame.prev = NIL) & (currentFrame.next = NIL) THEN	(* one and only frame *)
					lastFrame := currentFrame;
				ELSIF (currentFrame.next = NIL) THEN				(* last frame *)
					currentFrame.prev.next := currentFrame.next;
					lastFrame := currentFrame.prev;
					firstFrame.prev := currentFrame;
					currentFrame.prev := NIL;
					currentFrame.next := firstFrame;
				ELSIF (currentFrame.prev = NIL) THEN				(* first frame *)
					(* do nothing *)
				ELSE												(* between *)
					currentFrame.prev.next := currentFrame.next;
					currentFrame.next.prev := currentFrame.prev;
					firstFrame.prev := currentFrame;
					currentFrame.prev := NIL;
					currentFrame.next := firstFrame;
				END;
				firstFrame := currentFrame;
			END;
		END Move2Back;

		PROCEDURE Move2FrontStep*;
		VAR
		BEGIN
			IF currentFrame # NIL THEN
				IF (currentFrame.prev = NIL) & (currentFrame.next = NIL) THEN
					firstFrame := currentFrame;
					lastFrame := currentFrame;
				ELSIF (currentFrame.prev = NIL) THEN				(* first frame *)
					IF currentFrame.next.next = NIL THEN			(* only 2 frames - swap *)
						currentFrame.prev := currentFrame.next;
						lastFrame.next := currentFrame;
						lastFrame.prev := NIL;
						currentFrame.next := NIL;
						firstFrame := lastFrame;
						lastFrame := currentFrame;
					ELSE											(* more than 2 frames *)
						currentFrame.prev := currentFrame.next;
						currentFrame.next.next.prev := currentFrame;
						currentFrame.next := currentFrame.next.next;
						currentFrame.prev.next := currentFrame;
						firstFrame := currentFrame.prev;
						firstFrame.prev := NIL;
					END;
				ELSIF (currentFrame.next = NIL) THEN				(* last frame *)
					(* do nothing *)
				ELSE												(* between *)
					IF currentFrame.next.next = NIL THEN			(* 2nd last frame *)
						currentFrame.prev.next := currentFrame.next;
						currentFrame.next.prev := currentFrame.prev;
						currentFrame.prev := currentFrame.next;
						currentFrame.next.next := currentFrame;
						currentFrame.next := NIL;
						lastFrame := currentFrame;
					ELSE											(* "deep" between *)
						currentFrame.prev.next := currentFrame.next;
						currentFrame.next.prev := currentFrame.prev;
						currentFrame.prev := currentFrame.prev.next;
						currentFrame.next := currentFrame.prev.next;
						currentFrame.prev.next.prev := currentFrame;
						currentFrame.prev.next := currentFrame;
					END;
				END;
			END;
		END Move2FrontStep;

		PROCEDURE Move2BackStep*;
		BEGIN
			IF currentFrame # NIL THEN
				IF (currentFrame.prev = NIL) & (currentFrame.next = NIL) THEN
					firstFrame := currentFrame;
					lastFrame := currentFrame;
				ELSIF (currentFrame.prev = NIL) THEN				(* first frame *)
					(* do nothing *)
				ELSIF (currentFrame.next = NIL) THEN				(* last frame *)
					IF currentFrame.prev.prev = NIL THEN			(* only 2 frames - swap *)
						currentFrame.next := currentFrame.prev;
						firstFrame.prev := currentFrame;
						firstFrame.next := NIL;
						currentFrame.prev := NIL;
						lastFrame := firstFrame;
						firstFrame := currentFrame;
					ELSE											(* more than 2 frames *)
						currentFrame.next := currentFrame.prev;
						currentFrame.prev.prev.next := currentFrame;
						currentFrame.prev := currentFrame.prev.prev;
						currentFrame.next.prev := currentFrame;
						lastFrame := currentFrame.next;
						lastFrame.next := NIL;
					END;
				ELSE												(* between *)
					IF currentFrame.prev.prev = NIL THEN			(* 2nd first frame *)
						currentFrame.next.prev := currentFrame.prev;
						currentFrame.prev.next := currentFrame.next;
						currentFrame.next := currentFrame.prev;
						currentFrame.prev.prev := currentFrame;
						currentFrame.prev := NIL;
						firstFrame := currentFrame;
					ELSE											(* "deep" between *)
						currentFrame.next.prev := currentFrame.prev;
						currentFrame.prev.next := currentFrame.next;
						currentFrame.next := currentFrame.next.prev;
						currentFrame.prev := currentFrame.next.prev;
						currentFrame.next.prev.next := currentFrame;
						currentFrame.next.prev := currentFrame;
					END;
				END;
			END;
		END Move2BackStep;

		PROCEDURE SetCurrentFrame*(frame : FrameObject);
		BEGIN
			currentFrame := frame;
		END SetCurrentFrame;

		PROCEDURE GetCurrentFrame*(): FrameObject;
		BEGIN
			RETURN currentFrame;
		END GetCurrentFrame;

		PROCEDURE GetFirstFrame*(): FrameObject;
		BEGIN
			RETURN firstFrame;
		END GetFirstFrame;

		PROCEDURE GetLastFrame*(): FrameObject;
		BEGIN
			RETURN lastFrame;
		END GetLastFrame;

		PROCEDURE GetCurrentGuide*(): GuideObject;
		BEGIN
			RETURN currentGuide;
		END GetCurrentGuide;

		PROCEDURE GetFirstGuide*(): GuideObject;
		BEGIN
			RETURN firstGuide;
		END GetFirstGuide;

		PROCEDURE GetLastGuide*(): GuideObject;
		BEGIN
			RETURN lastGuide;
		END GetLastGuide;

	END PageObject;

	MasterPageObject* = OBJECT(PageObject)
	VAR
		mpageName* : Strings.String;
		next*, prev* : MasterPageObject;

	PROCEDURE &New*;
	BEGIN
		New^;
		mpageName := Strings.NewString("Master");
	END New;

	PROCEDURE SetName*(name: Strings.String);
	BEGIN
		mpageName := name;
	END SetName;

	PROCEDURE GetName*(): Strings.String;
	BEGIN
		RETURN mpageName;
	END GetName;

	END MasterPageObject;

	GuideObject* = OBJECT
	VAR
		horizontal : BOOLEAN;
		position : REAL;
		prev*, next* : GuideObject;

		PROCEDURE &New*(posi : REAL; horiz : BOOLEAN);
		BEGIN
			position := posi; horizontal := horiz;
			prev := NIL; next := NIL;
		END New;

		PROCEDURE SetHorizontal*(isHorizontal : BOOLEAN);
		BEGIN
			horizontal := isHorizontal;
		END SetHorizontal;

		PROCEDURE GetHorizontal*() : BOOLEAN;
		BEGIN
			RETURN horizontal;
		END GetHorizontal;

		PROCEDURE SetPosition*(posi : REAL);
		BEGIN
			position := posi;
		END SetPosition;

		PROCEDURE GetPosition*() : REAL;
		BEGIN
			RETURN position;
		END GetPosition;

		PROCEDURE Clone*(): GuideObject;
		VAR newguide: GuideObject;
		BEGIN
			NEW(newguide, GetPosition(), GetHorizontal());
			RETURN newguide;
		END Clone;

	END GuideObject;

	FrameObject* = OBJECT
	VAR
		frameName : Strings.String;
		frameType : Strings.String;
		x, y, w, h : REAL;
		style : StyleObject;
		content : ContentObject; (* DTPFrame.ContentObject; *)
		textwrapON : BOOLEAN;
		twrapTop, twrapBottom, twrapLeft, twrapRight : REAL;

		next*, prev* : FrameObject;

		PROCEDURE &New*;
		BEGIN
			textwrapON := FALSE;
			twrapTop := 0; twrapBottom := 0; twrapLeft := 0; twrapRight := 0;
			next := NIL; prev := NIL;
			frameName := Strings.NewString("newframe");
			style := NIL;
			content := NIL;
		END New;

		PROCEDURE SetName*(name : Strings.String);
		VAR
		BEGIN
			frameName := name;
		END SetName;

		PROCEDURE GetName*() : Strings.String ;
		VAR
		BEGIN
			RETURN frameName
		END GetName;

		PROCEDURE SetType*(type : Strings.String);
		BEGIN
			frameType := type;
		END SetType;

		PROCEDURE GetType*() : Strings.String;
		VAR
		BEGIN
			RETURN frameType;
		END GetType;

		PROCEDURE FixExtent*;
		VAR cx, cy, cw, ch: REAL;
		BEGIN
			cx := x; cy := y; cw := w; ch := h;
			x := Min(cx, cx+cw); y := Min(cy, cy+ch);
			w := Max(cx, cx+cw)-Min(cx, cx+cw); h := Max(cy, cy+ch)-Min(cy, cy+ch);

		END FixExtent;

		PROCEDURE SetExtent*(x, y, w, h: REAL);
		BEGIN
			SELF.x := x; SELF.y := y; SELF.w := w; SELF.h := h;
		END SetExtent;

		PROCEDURE SetSize*( w, h : REAL);
		VAR
		BEGIN
			SELF.w := w; SELF.h := h;
		END SetSize;

		PROCEDURE SetPosition*(x, y: REAL);
		BEGIN
			SELF.x := x; SELF.y := y;
		END SetPosition;

		PROCEDURE GetX*(): REAL;
		VAR
		BEGIN
			RETURN x;
		END GetX;

		PROCEDURE GetY*(): REAL;
		VAR
		BEGIN
			RETURN y;
		END GetY;

		PROCEDURE GetWidth*(): REAL;
		VAR
		BEGIN
			RETURN w;
		END GetWidth;

		PROCEDURE GetHeight*(): REAL;
		VAR
		BEGIN
			RETURN h;
		END GetHeight;

		PROCEDURE SetStyle*(style : StyleObject);
		BEGIN
			SELF.style := style;
		END SetStyle;

		PROCEDURE GetStyle*() : StyleObject;
		BEGIN
			RETURN style
		END GetStyle;

		PROCEDURE SetContent*(content : ContentObject); (* DTPFrame.ContentObject; *)
		BEGIN
			SELF.content := content;
		END SetContent;

		PROCEDURE GetContent*() : ContentObject; (* DTPFrame.ContentObject; *)
		BEGIN
			RETURN content
		END GetContent;

		PROCEDURE SetWrap*(wrap : BOOLEAN);
		BEGIN
			textwrapON := wrap;
		END SetWrap;

		PROCEDURE GetWrap*() : BOOLEAN;
		BEGIN
			RETURN textwrapON;
		END GetWrap;

		PROCEDURE SetWrapSize*(t, b, l, r : REAL);
		BEGIN
			twrapTop := t; twrapBottom := b;
			twrapLeft := l; twrapRight := r;
		END SetWrapSize;

		PROCEDURE GetWrapTop*(): REAL;
		BEGIN
			RETURN twrapTop
		END GetWrapTop;

		PROCEDURE GetWrapBottom*(): REAL;
		BEGIN
			RETURN twrapBottom
		END GetWrapBottom;

		PROCEDURE GetWrapLeft*(): REAL;
		BEGIN
			RETURN twrapLeft
		END GetWrapLeft;

		PROCEDURE GetWrapRight*(): REAL;
		BEGIN
			RETURN twrapRight
		END GetWrapRight;

		PROCEDURE Clone*(): FrameObject;
		VAR newframe: FrameObject;
			newcontent: ContentObject; (* DTPFrame.ContentObject; *)
		BEGIN
			NEW(newframe);
			newframe.SetName(GetName());					(* maybe change name to avoid conflicts *)
			newframe.SetType(GetType());
			newframe.SetExtent(GetX(), GetY(), GetWidth(), GetHeight());
			newframe.SetStyle(GetStyle());
			newcontent := GetContent();
			newframe.SetContent(newcontent.Clone());
			newframe.SetWrap(GetWrap());
			newframe.SetWrapSize(GetWrapTop(), GetWrapBottom(), GetWrapLeft(), GetWrapRight());
			newframe.prev := NIL; newframe.next := NIL;
			RETURN newframe;
		END Clone;

	END FrameObject;

	ContentObject* = OBJECT
	VAR
		contentName* : Strings.String;
		redrawProc* : PROCEDURE {DELEGATE};
		updatePropsPosition*: PROCEDURE {DELEGATE} (x, y: LONGINT);
		contentWidth*, contentHeight*: LONGINT;
		zoomFactor* : REAL;
		ownerDoc*: Document;
		hasFocus- : BOOLEAN;
		running- : BOOLEAN;

		PROCEDURE &New*;
		BEGIN
			hasFocus := FALSE;
			running := FALSE;
		END New;

		PROCEDURE Clone*(): ContentObject;
		VAR newObj: ContentObject;
		BEGIN
			NEW(newObj); newObj.contentName := Strings.NewString(contentName^);
			newObj.redrawProc := redrawProc; newObj.updatePropsPosition := updatePropsPosition;
			newObj.contentWidth := contentWidth; newObj.contentHeight := contentHeight; newObj.zoomFactor := zoomFactor;
			newObj.ownerDoc := ownerDoc;
			RETURN newObj;
		END Clone;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; x, y, w, h : LONGINT; zoomFactor: REAL; quality, preview: BOOLEAN);
		VAR color: LONGINT;
		BEGIN
			color := LONGINT(0FF0000FFH);
			canvas.Line(x, y, x+w, y+h, color, WMGraphics.ModeCopy);
			canvas.Line(x+w, y, x, y+h, color, WMGraphics.ModeCopy);
		END Draw;

		PROCEDURE Redraw*;
		BEGIN
			IF redrawProc # NIL THEN
				redrawProc;
			ELSE
				(* KernelLog.String("redraw = NIL");KernelLog.Ln; *)
			END;
		END Redraw;

		PROCEDURE UpdatePosition*(x, y: LONGINT);
		BEGIN
			updatePropsPosition(x, y);
		END UpdatePosition;

		PROCEDURE SetSize*(w, h: LONGINT);
		BEGIN
			contentWidth := w; contentHeight := h;
		END SetSize;

		PROCEDURE Resize*(zoomF: REAL);
		BEGIN
			zoomFactor := zoomF;
		END Resize;

		PROCEDURE Show*(x, y: LONGINT);
		END Show;

		PROCEDURE Hide*;
		END Hide;

		PROCEDURE Close*;
		END Close;

		PROCEDURE SetFocus*(focus: BOOLEAN);
		BEGIN
			hasFocus := focus;
		END SetFocus;

		PROCEDURE FocusLost*;
		BEGIN
			hasFocus := FALSE;
		END FocusLost;

		PROCEDURE FocusReceived*;
		BEGIN
			hasFocus := TRUE;
		END FocusReceived;

		PROCEDURE GetPluginPointer*(): WMWindowManager.PointerInfo;
		VAR manager : WMWindowManager.WindowManager;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			RETURN manager.pointerStandard;
		END GetPluginPointer;

		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET);
		END PointerDown;

		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET);
		END PointerMove;

		PROCEDURE PointerUp*(x, y: LONGINT; keys: SET);
		END PointerUp;

		PROCEDURE PointerLeave*;
		END PointerLeave;

		PROCEDURE IsHit*(x, y: LONGINT): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END IsHit;

		PROCEDURE KeyEvent*(ucs: LONGINT; flags: SET; VAR keyCode: LONGINT);
		END KeyEvent;

		PROCEDURE Start*;
		BEGIN
			running := TRUE;
		END Start;

		PROCEDURE Stop*;
		BEGIN
			running := FALSE;
		END Stop;

		PROCEDURE OnPageEnter*;
		END OnPageEnter;

		PROCEDURE OnPageLeave*;
		END OnPageLeave;

		PROCEDURE OnCreate*;
		END OnCreate;

		PROCEDURE OnDelete*;
		END OnDelete;

		PROCEDURE Load*(elem: XML.Element);
		END Load;

		PROCEDURE FixLinks*;
		END FixLinks;

		PROCEDURE Store*(VAR w: Files.Writer);
		BEGIN
			w.String('<node-attribute name="type" value="Frame" />'); w.Ln;
		END Store;

	END ContentObject;

	ContentFactory* = PROCEDURE() : ContentObject;

	ContentPages* = POINTER TO ARRAY OF PageObject;
	MasterPages* = POINTER TO ARRAY OF MasterPageObject;
	Frames* = POINTER TO ARRAY OF FrameObject;
	Contents* = POINTER TO ARRAY OF ContentObject;

(* ------------------------------------- *)
VAR
	dollyFrame*: FrameObject;

PROCEDURE NewObject*(): ContentObject;
VAR newObject: ContentObject;
BEGIN
	NEW(newObject);
	RETURN newObject;
END NewObject;

PROCEDURE Min(a, b: REAL): REAL;
BEGIN
	IF a <= b THEN RETURN a ELSE RETURN b END;
END Min;

PROCEDURE Max(a, b: REAL): REAL;
BEGIN
	IF a >= b THEN RETURN a ELSE RETURN b END;
END Max;

END DTPData.	