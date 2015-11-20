MODULE CharacterLineup;	(** AUTHOR "TF"; PURPOSE "Tool to identify a chinese character"; *)

IMPORT
		KernelLog, Modules, WMComponents, WMStandardComponents, WMEditors,
		Strings, UTF8Strings, WMGraphics, UnihanParser, WM := WMWindowManager, WMGrids,
		WMCCGFonts, WMRectangles;

CONST
	MaxCharacterCode = 200000;
	NofCols = 25;
	MaxFilters = 8;

TYPE
	CharacterArray = POINTER TO ARRAY OF WMCCGFonts.Glyph;
	HistoEntry = RECORD ucs, freq : LONGINT; END;
	FilterHisto = POINTER TO ARRAY OF HistoEntry;
	Identifier = OBJECT(WMComponents.FormWindow)
	VAR
		mainPanel, toolbar, infobar, textInfoPanel, selectionPanel, filterPanel, paintBox : WMStandardComponents.Panel;
		characterEdit, pinyinEdit, mandarinEdit, cantoneseEdit, koreanEdit, definitionEdit, codeEdit : WMEditors.Editor;
		characters, filterComponents : WMGrids.GenericGrid;
		toggleFilter : WMStandardComponents.Button;

		curChar :LONGINT;
		fontinfo : WMCCGFonts.GenericFont;
		bigFont : WMGraphics.Font;
		charInfo : UnihanParser.Character;

		allCharacters: CharacterArray;
		nofCharacters: LONGINT;
		filtered : CharacterArray;

		filterArray : ARRAY MaxFilters OF LONGINT;
		nofFilters : LONGINT;

		nofInFilter : LONGINT;

		useFilter : BOOLEAN;

		relevantSubcomponents : FilterHisto;

		PROCEDURE &New*;
			PROCEDURE AddLabelEdit(parent : WMComponents.VisualComponent; VAR e : WMEditors.Editor; CONST caption : ARRAY OF CHAR);
			VAR l : WMStandardComponents.Label;
				g : WMStandardComponents.Panel;
			BEGIN
				NEW(g); g.bounds.SetHeight(30); g.alignment.Set(WMComponents.AlignTop);
				NEW(l); l.bounds.SetWidth(100); l.alignment.Set(WMComponents.AlignLeft); l.caption.SetAOC(caption); g.AddContent(l);
				NEW(e); e.alignment.Set(WMComponents.AlignClient); g.AddContent(e);
				e.multiLine.Set(FALSE);
				e.tv.textAlignV.Set(WMGraphics.AlignCenter);
				parent.AddContent(g)
			END AddLabelEdit;

		BEGIN
			SetTitle(WM.NewString("Hobbes' Chinese Tool"));

			NEW(mainPanel); mainPanel.bounds.SetExtents(800, 600);
			mainPanel.fillColor.Set(0FFFFFFFFH);

			NEW(toolbar); toolbar.bounds.SetHeight(30); toolbar.alignment.Set(WMComponents.AlignTop); mainPanel.AddContent(toolbar);
			NEW(infobar); infobar.bounds.SetHeight(256); infobar.alignment.Set(WMComponents.AlignTop); mainPanel.AddContent(infobar);

			(* information elements *)
			NEW(paintBox); paintBox.bounds.SetWidth(256); paintBox.alignment.Set(WMComponents.AlignLeft); infobar.AddContent(paintBox);
			paintBox.fillColor.Set(0FFFFFFFFH); paintBox.SetExtDrawHandler(PaintCharacter);
			bigFont := WMGraphics.GetFont("Single", 256, {});
			IF bigFont IS WMCCGFonts.Font THEN fontinfo := bigFont(WMCCGFonts.Font).gf END;
			bigFont := WMGraphics.GetFont("Cyberbit", 256, {});

			NEW(textInfoPanel); textInfoPanel.alignment.Set(WMComponents.AlignClient); infobar.AddContent(textInfoPanel);
			AddLabelEdit(textInfoPanel, characterEdit, "Character : ");
			characterEdit.SetFont(WMGraphics.GetFont("Single", 20, {}));
			characterEdit.onEnter.Add(NewCharacter);
			AddLabelEdit(textInfoPanel, pinyinEdit, "Pinyin : ");
			AddLabelEdit(textInfoPanel, mandarinEdit, "Mandarin : ");
			AddLabelEdit(textInfoPanel, cantoneseEdit, "Cantonese : ");
			AddLabelEdit(textInfoPanel, koreanEdit, "Korean : ");
			AddLabelEdit(textInfoPanel, definitionEdit, "Definition : ");
			definitionEdit.multiLine.Set(FALSE);
			definitionEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			AddLabelEdit(textInfoPanel, codeEdit, "Code : ");
			codeEdit.onEnter.Add(NewCode);

			(* filter tool bar *)
			NEW(filterPanel); filterPanel.alignment.Set(WMComponents.AlignTop);
			filterPanel.bounds.SetHeight(80); mainPanel.AddContent(filterPanel);
			NEW(filterComponents); filterComponents.alignment.Set(WMComponents.AlignTop); filterPanel.AddContent(filterComponents);
			filterComponents.bounds.SetHeight(50);
			filterComponents.nofRows.Set(1);
			filterComponents.SetDrawCellProc(DrawFilterComponents);
			filterComponents.defaultColWidth.Set(30); filterComponents.defaultRowHeight.Set(30);
			filterComponents.onClick.Add(FilterSelection);
			NEW(toggleFilter); toggleFilter.onClick.Add(ToggleFilter); toggleFilter.SetCaption("Clear Filter");
			toggleFilter.alignment.Set(WMComponents.AlignTop); filterPanel.AddContent(toggleFilter);

			(* characters *)
			NEW(selectionPanel); selectionPanel.alignment.Set(WMComponents.AlignClient); mainPanel.AddContent(selectionPanel);
			NEW(characters); characters.alignment.Set(WMComponents.AlignClient); selectionPanel.AddContent(characters);
			characters.nofCols.Set(NofCols); characters.nofRows.Set(4);
			characters.defaultColWidth.Set(30); characters.defaultRowHeight.Set(30);
			characters.SetDrawCellProc(DrawAll);
			characters.onSelect.Add(SelectChar);

			Init(mainPanel.bounds.GetWidth(), mainPanel.bounds.GetHeight(), FALSE);
			manager := WM.GetDefaultManager();
			manager.Add(200, 200, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagMinimize});
			SetContent(mainPanel);
			LoadAllCharacters;
			filterComponents.nofCols.Set(LEN(relevantSubcomponents));
			characters.nofRows.Set(nofCharacters DIV NofCols + 1);
			useFilter := TRUE; nofFilters := 0;
			Filter(nofFilters, filterArray);
		END New;

		PROCEDURE LoadAllCharacters;
		VAR temp : CharacterArray;
			g : WMCCGFonts.Glyph;
			i, j, t, nof, nz : LONGINT;
			histo : FilterHisto;

			PROCEDURE UpdateHisto(g : WMCCGFonts.Glyph);
			VAR i, ucs : LONGINT;
			BEGIN
				FOR i := 0 TO g.nofSubComponents - 1 DO
					ucs := g.subComponents[i].refucs;
					IF (ucs >= 0) & (ucs <MaxCharacterCode) THEN
						INC(histo[g.subComponents[i].refucs].freq)
					ELSE
						KernelLog.String("Strange..."); KernelLog.Hex(ucs, 0); KernelLog.Ln
					END
				END
			END UpdateHisto;

		BEGIN
			KernelLog.String("Loading all characters"); KernelLog.Ln;
			IF fontinfo # NIL THEN
				(* subcomponent histogram *)
				NEW(histo, MaxCharacterCode);
				FOR i := 0 TO MaxCharacterCode - 1 DO histo[i].ucs := i; histo[i].freq := 0 END;

				NEW(temp, MaxCharacterCode);
				nof := 0;
				FOR i := 0 TO MaxCharacterCode - 1 DO
					g := fontinfo.GetGlyph(i, 0);
					IF g # NIL THEN
						UpdateHisto(g);
						temp[nof] := g; INC(nof);
						WHILE g.nextVariant # NIL DO
							g := g.nextVariant;
							UpdateHisto(g);
							temp[nof] := g; INC(nof)
						END
					END
				END;
				NEW(allCharacters, nof);
				NEW(filtered, nof);
				FOR i := 0 TO nof - 1 DO allCharacters[i] := temp[i] END;
				nofCharacters := nof
			END;
			KernelLog.Int(nofCharacters, 5); KernelLog.String(" characters available"); KernelLog.Ln;
			KernelLog.String("Sorting histogram"); KernelLog.Ln;
			(* count non-zero *)
			nz := 0; FOR i := 0 TO MaxCharacterCode - 1 DO IF histo[i].freq > 0 THEN INC(nz) END END;
			NEW(relevantSubcomponents, nz);
			nz := 0;
			FOR i := 0 TO MaxCharacterCode - 1 DO
				IF histo[i].freq > 0 THEN
					j := 0; WHILE (j < nz) & (relevantSubcomponents[j].freq > histo[i].freq) DO INC(j) END;
					(* move smaller freq up *)
					t := nz - 1; WHILE t >= j DO relevantSubcomponents[t + 1] := relevantSubcomponents[t]; DEC(t) END;
					relevantSubcomponents[j] := histo[i];
					INC(nz)
				END
			END;
		END LoadAllCharacters;

		PROCEDURE Update;
		VAR codeStr, charString : ARRAY 16 OF CHAR; i : LONGINT;
		BEGIN
			paintBox.Invalidate;
			IF UnihanParser.HasCode(curChar) THEN
				charInfo := UnihanParser.GetCharacter(curChar);
			ELSE charInfo := NIL
			END;
			i := 0; IF UTF8Strings.EncodeChar(curChar, charString, i) THEN characterEdit.SetAsString(charString)
			ELSE characterEdit.SetAsString("")
			END;
			Strings.IntToHexStr(curChar, 0, codeStr);
			codeEdit.SetAsString(codeStr);
			IF charInfo # NIL THEN
				IF charInfo.pinyin # NIL THEN pinyinEdit.SetAsString(charInfo.pinyin^) ELSE pinyinEdit.SetAsString("<unknown>") END;
				IF charInfo.mandarin # NIL THEN mandarinEdit.SetAsString(charInfo.mandarin^) ELSE mandarinEdit.SetAsString("<unknown>") END;
				IF charInfo.cantonese # NIL THEN cantoneseEdit.SetAsString(charInfo.cantonese^) ELSE cantoneseEdit.SetAsString("<unknown>") END;
				IF charInfo.korean # NIL THEN koreanEdit.SetAsString(charInfo.korean^) ELSE koreanEdit.SetAsString("<unknown>") END;
				IF charInfo.definition # NIL THEN definitionEdit.SetAsString(charInfo.definition^) ELSE definitionEdit.SetAsString("<unknown>") END;
			ELSE
				pinyinEdit.SetAsString("<unknown>");
				mandarinEdit.SetAsString("<unknown>");
				cantoneseEdit.SetAsString("<unknown>");
				koreanEdit.SetAsString("<unknown>");
				definitionEdit.SetAsString("<unknown>");
			END
		END Update;

		PROCEDURE IsComponentUsed(glyph : WMCCGFonts.Glyph; code : LONGINT) : BOOLEAN;
		VAR i : LONGINT;
			result : BOOLEAN;
		BEGIN
			result := FALSE;
			IF glyph.ucs = code THEN RETURN TRUE END;
			FOR i := 0 TO glyph.nofSubComponents - 1 DO IF glyph.subComponents[i].refucs = code THEN result := TRUE END END;
			RETURN result
		END IsComponentUsed;

		PROCEDURE Filter(nofSubs : LONGINT; CONST subs : ARRAY OF LONGINT);
		VAR nof, i, j : LONGINT; ok : BOOLEAN;
		BEGIN
			KernelLog.String("Filtering for "); KernelLog.Hex(subs[0], 0); KernelLog.Ln;

			nof := 0;
			FOR i := 0 TO nofCharacters - 1 DO
				ok := TRUE; FOR j := 0 TO nofSubs- 1 DO IF ~IsComponentUsed(allCharacters[i], subs[j]) THEN ok := FALSE END END;
				IF ok THEN filtered[nof] := allCharacters[i]; INC(nof) END;
			END;
			KernelLog.String("remaining : "); KernelLog.Int(nof, 5); KernelLog.Ln;
			nofInFilter := nof
		END Filter;

		PROCEDURE ToggleFilter(sender, data :ANY);
		BEGIN
			nofFilters := 0;
			filterComponents.Invalidate;
			Filter(nofFilters, filterArray);
			characters.Invalidate
		END ToggleFilter;

		PROCEDURE NewCharacter(sender, data :ANY);
		VAR code : ARRAY 16 OF CHAR; i : LONGINT;
		BEGIN
			characterEdit.GetAsString(code);
			i := 0;
			IF UTF8Strings.DecodeChar(code, i, curChar) THEN Update ELSE
				curChar := 0; Update
			END;
		END NewCharacter;

		PROCEDURE NewCode(sender, data :ANY);
		VAR code, res : LONGINT;
			codeStr: ARRAY 9 OF CHAR;
		BEGIN
			codeEdit.GetAsString(codeStr);
			Strings.HexStrToInt(codeStr, code, res);
			IF res = 0 THEN curChar := code; Update END
		END NewCode;

		PROCEDURE SelectChar(sender, data :ANY);
		VAR l, t, r, b, pos : LONGINT;
		BEGIN
			characters.GetSelection(l, t, r, b);
			pos := t * NofCols + l;
			IF useFilter THEN
				IF pos < nofInFilter THEN
					curChar := filtered[pos].ucs;
					Update
				END
			ELSE
				IF pos < nofCharacters THEN
					curChar := allCharacters[pos].ucs;
					Update
				END
			END
		END SelectChar;

		PROCEDURE FilterSelection(sender, data :ANY);
		VAR l, t, r, b, pos : LONGINT;
		BEGIN
			filterComponents.GetSelection(l, t, r, b);
			pos := l;
			IF (relevantSubcomponents # NIL) & (pos < LEN(relevantSubcomponents)) THEN
				IF IsInFilterArray(relevantSubcomponents[pos].ucs) THEN RemoveFromFilter(relevantSubcomponents[pos].ucs)
				ELSE AddToFilter(relevantSubcomponents[pos].ucs)
				END;
				filterComponents.Invalidate;
				Filter(nofFilters, filterArray);
				characters.Invalidate;
				characters.SetTopPosition(0, 0, TRUE);
			END
		END FilterSelection;

		PROCEDURE IsInFilterArray(ucs : LONGINT) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO nofFilters - 1 DO IF filterArray[i] = ucs THEN RETURN TRUE END END;
			RETURN FALSE
		END IsInFilterArray;

		PROCEDURE AddToFilter(ucs : LONGINT);
		BEGIN
			IF nofFilters < MaxFilters - 1 THEN filterArray[nofFilters] := ucs; INC(nofFilters) END
		END AddToFilter;

		PROCEDURE RemoveFromFilter(ucs : LONGINT);
		VAR a, i : LONGINT;
		BEGIN
			a := 0;
			FOR i := 0 TO nofFilters - 1 DO IF filterArray[i] # ucs THEN filterArray[a] := filterArray[i]; INC(a) ELSE DEC(nofFilters) END END;
		END RemoveFromFilter;

		PROCEDURE PaintCharacter(canvas : WMGraphics.Canvas);
		VAR g : WMCCGFonts.Glyph;
			points : ARRAY 2560 OF WMGraphics.Point2d;
		BEGIN
			IF (bigFont IS WMCCGFonts.Font) THEN
				g := bigFont(WMCCGFonts.Font).gf.GetGlyph(curChar, 0);
				IF g # NIL THEN
					bigFont(WMCCGFonts.Font).gf.RenderGlyphReal(canvas, g, 0, 0, 256, 256, 0,
						TRUE, 0FFH, WMGraphics.ModeSrcOverDst, points);
				END;
			END;
		END PaintCharacter;

		PROCEDURE Close;
		BEGIN
			Close^;
			winstance := NIL
		END Close;

		PROCEDURE DrawAll(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR pos : LONGINT;
			points : ARRAY 2560 OF WMGraphics.Point2d;
		BEGIN
			IF WMGrids.CellHighlighted IN state THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy)
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy)
			END;
			pos := y * NofCols + x;
			IF useFilter THEN
				IF pos < nofInFilter THEN
					IF fontinfo # NIL THEN
						IF filtered[pos] # NIL THEN fontinfo.RenderGlyphReal(canvas, filtered[pos], 0, 0, w, h, 0,
							FALSE, 0FFH, WMGraphics.ModeSrcOverDst, points) END
					END
				END
			ELSE
				IF pos < nofCharacters THEN
					IF fontinfo # NIL THEN
						IF allCharacters[pos] # NIL THEN
							fontinfo.RenderGlyphReal(canvas, allCharacters[pos], 0, 0, w, h, 0, FALSE, 0FFH, WMGraphics.ModeSrcOverDst, points) END
					END
				END
			END
		END DrawAll;

		PROCEDURE DrawFilterComponents(canvas : WMGraphics.Canvas; w, h : LONGINT; state : SET; x, y : LONGINT);
		VAR pos : LONGINT; g : WMCCGFonts.Glyph;
			points : ARRAY 2560 OF WMGraphics.Point2d;
		BEGIN
			pos := x;
			IF (relevantSubcomponents # NIL) & (pos < LEN(relevantSubcomponents)) THEN
				IF WMGrids.CellHighlighted IN state THEN
					canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFF00FFH), WMGraphics.ModeCopy)
				ELSE
					canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy)
				END;
				IF IsInFilterArray(relevantSubcomponents[pos].ucs) THEN
					canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), 0FFC0H, WMGraphics.ModeSrcOverDst)
				END;
				IF fontinfo # NIL THEN
					g := fontinfo.GetGlyph(relevantSubcomponents[pos].ucs, 0);
					IF g # NIL THEN fontinfo.RenderGlyphReal(canvas, g, 0, 0, w, h, 0, FALSE, 0FFH, WMGraphics.ModeSrcOverDst, points) END
				END
			END;
		END DrawFilterComponents;

	END Identifier;

VAR
	winstance : Identifier;

PROCEDURE Open*;
BEGIN
	IF winstance = NIL THEN NEW(winstance) END;
END Open;

PROCEDURE Cleanup;
BEGIN
	IF winstance # NIL THEN winstance.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END CharacterLineup.

SystemTools.Free CharacterLineup ~ UnihanParser ~
CharacterLineup.Open ~
