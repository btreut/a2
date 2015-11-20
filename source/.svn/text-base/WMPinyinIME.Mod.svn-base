MODULE WMPinyinIME; (** AUTHOR "tf"; PURPOSE "Pinyin input mode editor"; *)

IMPORT
	KernelLog, Modules, Strings, Files, TextUtilities, UTF8Strings,
	WMInputMethods, WMMessages,
	(* visual part *)
	WMRectangles, WMWindowManager, WMComponents, WMStandardComponents, WMEditors,
	WMGraphics, WMStringGrids, WMGrids;

CONST
	imeName* = "Pinyin";

TYPE
	CharInfo = RECORD
		pinyin : ARRAY 8 OF CHAR;
		ucs : LONGINT;
		freq : LONGINT;
		info : String;
	END;

	(* generic sortable list *)
	ListElement = POINTER TO RECORD
		next : ListElement;
	END;

	(* return -1, if a < b; 0, if a = b; 1, if a > b *)
	CompareProc = PROCEDURE {DELEGATE} (a, b : ListElement) : LONGINT;

	PhraseInfo = POINTER TO RECORD (ListElement)
		phrase : String;
		hanzi: String;
		info : String;
	END;

	String = Strings.String;

	ResultList = POINTER TO RECORD (ListElement)
		pinyin : String;
		hanzi : String;
		freq : LONGINT;
	END;

	Characters = POINTER TO ARRAY OF CharInfo;

	Phrases = POINTER TO ARRAY OF PhraseInfo;

	Table = OBJECT
	VAR nofChars : LONGINT;
		characters : Characters;

		phrases : Phrases;
		nofPhrases : LONGINT;

		PROCEDURE LoadCharacters;
		VAR f  : Files.File; r : Files.Reader;
			i : LONGINT; errors : BOOLEAN;
			info: ARRAY 256 OF CHAR;
		BEGIN
			f := Files.Old("PinyinIMETable.txt");
			IF f = NIL THEN
				KernelLog.String("PinyinIMETable.txt not found"); KernelLog.Ln;
				RETURN
			END;
			Files.OpenReader(r, f, 0);

			r.Int(nofChars, FALSE); r.SkipLn;
			IF nofChars <= 0 THEN
				KernelLog.String("PinyinIMETable.txt size illegal"); KernelLog.Ln;
				RETURN
			END;

			NEW(characters, nofChars);
			errors := FALSE;
			i := 0;
			WHILE (i < nofChars) & (r.res = 0) DO
				r.Token(characters[i].pinyin); r.SkipWhitespace;
				IF ~ TextUtilities.GetUTF8Char(r, characters[i].ucs) THEN errors := TRUE END;
				r.SkipWhitespace;
				r.Int(characters[i].freq, FALSE);
				r.Ln(info);
				IF info # ""  THEN characters[i].info := Strings.NewString(info) END;
				INC(i);
			END;
			IF errors OR (i < nofChars) THEN
				nofChars := i;
				KernelLog.String("PinyinIMETable.txt corrupted. Continuing with partial data"); KernelLog.Ln;
			END
		END LoadCharacters;

		PROCEDURE LoadPhrases;
		VAR f  : Files.File; r : Files.Reader;
			i : LONGINT; errors : BOOLEAN;
			pinyin, hanzi, info: ARRAY 256 OF CHAR;
			pi, cur : ListElement;
			n : PhraseInfo; (* dummy root *)
		BEGIN
			NEW(pi); (* dummy root *)
			f := Files.Old("PinyinIMEPhrases.txt");
			IF f = NIL THEN
				KernelLog.String("PinyinIMEPhrases.txt not found"); KernelLog.Ln;
				RETURN
			END;
			Files.OpenReader(r, f, 0);

			errors := FALSE;
			i := 0;
			WHILE (r.res = 0) DO
				r.String(pinyin); r.SkipWhitespace;
				r.String(hanzi); r.SkipWhitespace;
				r.Ln(info);

				NEW(n); n.next := pi.next; pi.next := n;
				IF info # "" THEN n.info := Strings.NewString(info) END;
				n.phrase:= Strings.NewString(pinyin);
				n.hanzi := Strings.NewString(hanzi);
				INC(i)
			END;
			nofPhrases := i;

			Sort(pi, SortPhraseInfoPinyin);

			NEW(phrases, nofPhrases);
			i := 0;
			cur := pi.next;
			WHILE cur # NIL DO
				phrases[i] := cur(PhraseInfo);
				cur := cur.next;
				INC(i)
			END
		END LoadPhrases;

		PROCEDURE FindMatches(CONST s : ARRAY OF CHAR; resultList : ResultList; VAR nofResults : LONGINT);
		VAR i, pos : LONGINT;
			r, tr, cur : ResultList;
			cl : ListElement;
			str : ARRAY 16 OF CHAR;
			t : ARRAY 64 OF CHAR;
		BEGIN
			nofResults := 0;
			(* characters *) (* inefficient *)
			FOR i := 0 TO nofChars - 1 DO
				IF MatchPinyin(s, characters[i].pinyin, TRUE) THEN
					pos := 0; IF UTF8Strings.EncodeChar(characters[i].ucs, str, pos) THEN END;
					NEW(r); r.next := resultList.next; resultList.next := r;
					INC(nofResults);
					r.pinyin := Strings.NewString(characters[i].pinyin);
					r.hanzi := Strings.NewString(str);
					r.freq := characters[i].freq
				END
			END;
			Sort(resultList, CompareResultListFreq);

			(* eliminate duplicate characters *)
			IF resultList.next # NIL THEN
				cur := resultList.next(ResultList);

				WHILE cur.next # NIL DO

					IF cur.hanzi^ = cur.next(ResultList).hanzi^ THEN
						COPY(cur.pinyin^, t);
						Strings.Append(t, "/");
						Strings.Append(t, cur.next(ResultList).pinyin^);
						cur.pinyin := Strings.NewString(t);
						cur.next := cur.next.next;
						DEC(nofResults)
					ELSE cur := cur.next(ResultList)
					END
				END
			END;

			NEW(tr);
			(* phrases *) (* inefficient *)
			IF (nofResults = 0) & (Strings.Length(s) >= 2) THEN
				FOR i := 0 TO nofPhrases - 1 DO
					IF MatchPinyin(s, phrases[i].phrase^, FALSE) THEN
						NEW(r); r.next := tr.next; tr.next := r;
						INC(nofResults);
						r.pinyin := phrases[i].phrase;
						r.hanzi := phrases[i].hanzi;
					END
				END;

				(* phrases by first letters *)
				FOR i := 0 TO nofPhrases - 1 DO
					IF MatchPinyinFirstChars(s, phrases[i].phrase^, FALSE) THEN
						NEW(r); r.next := tr.next; tr.next := r;
						INC(nofResults);
						r.pinyin := phrases[i].phrase;
						r.hanzi := phrases[i].hanzi;
					END
				END
			END;

			(* merge the result lists *)
			cl := resultList;
			WHILE cl.next # NIL DO cl := cl.next END;
			cl.next := tr.next;
		END FindMatches;

	END Table;

TYPE
	IMEWindow*  = OBJECT (WMComponents.FormWindow)
	VAR edit : WMEditors.Editor;
		list : WMStringGrids.StringGrid;
		spacings : WMGrids.Spacings;

		currentMatches : ResultList;
		lastMatch : ResultList;
		curEditStr : ARRAY 64 OF CHAR;

		table : Table;
		ime : IME;

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
			list.SetColSpacings(spacings);
			list.SetFont(WMGraphics.GetFont("Single", 20, {}));
			list.Release;
			ep.AddContent(list);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*(ime : IME; x, y :LONGINT; CONST text : ARRAY OF CHAR; table : Table);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			SELF.ime := ime;
			edit.onEnter.Add(Ok);
			edit.tv.SetExtKeyEventHandler(EditKeyPressed);
			SELF.table := table;

			NEW(currentMatches);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {});
			manager.SetFocus(SELF);
			edit.SetAsString(text);
			edit.SetFocus;
			edit.text.onTextChanged.Add(TextChanged);
		END New;

		PROCEDURE ListKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			IF keySym = 0FF0DH THEN handled := TRUE; edit.SetFocus END;
		END ListKeyPressed;


		PROCEDURE EditKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			IF keySym = 20H THEN (* space *)
				IF curEditStr = "" THEN ScheduleHide
				ELSE WriteSelected;
					(* private change, dont need to evaluate anything *)
					edit.text.onTextChanged.Remove(TextChanged);
					edit.SetAsString("");
					curEditStr := "";
					edit.text.onTextChanged.Add(TextChanged);
					lastMatch := NIL;
					ClearSelection
				END
			ELSIF keySym = 0FF08H THEN
				IF curEditStr = "" THEN ScheduleHide
				ELSE edit.KeyPressed(ucs, flags, keySym, handled)
				END
			ELSIF keySym = 0FF54H THEN list.SetFocus
			ELSE
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
		BEGIN
			list.Acquire;
			list.model.Acquire;
			list.GetSelection(ac, ar, bc, br);
			p := list.model.GetCellData(0, ar);
			list.model.Release;
			list.Release;
			IF (p # NIL) & (p IS ResultList) THEN
				ime.InsertUTF8String(p(ResultList).hanzi^)
			END;
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
		VAR cur : ListElement; nof, i : LONGINT;
		BEGIN
			(* avoid recursion *)
			edit.text.onTextChanged.Remove(TextChanged);

			(* find the character candidates *)
			edit.GetAsString(curEditStr);
			currentMatches.next := NIL;
			table.FindMatches(curEditStr, currentMatches, nof);

			IF currentMatches.next = NIL THEN
				IF lastMatch # NIL THEN
					ime.InsertUTF8String(lastMatch.hanzi^);
					edit.text.AcquireWrite;
					edit.text.Delete(0, edit.text.GetLength() - 1);
					edit.text.ReleaseWrite;
					lastMatch := NIL;
				END
			ELSE lastMatch := currentMatches.next(ResultList)
			END;
			list.Acquire;
			list.model.Acquire;
			list.SetTopPosition(0, 0, TRUE);
			list.SetSelection(0, 0, 0, 0);
			list.model.SetNofRows(nof);
			list.model.SetNofCols(2);

			i := 0; cur := currentMatches.next;
			WHILE cur # NIL DO
				list.model.SetCellText(0, i, cur(ResultList).hanzi);
				list.model.SetCellData(0, i, cur);
				list.model.SetCellText(1, i, cur(ResultList).pinyin);
				list.model.SetCellData(1, i, cur);
				INC(i);
				cur := cur.next
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
			ime.w := NIL;
			lastMatch := NIL
		END Hide;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) THEN
				IF (x.ext = SELF) THEN Hide
				END
			ELSE Handle^(x)
			END
		END Handle;

	END IMEWindow;

TYPE
	IME* = OBJECT(WMInputMethods.IME)
	VAR
		w : IMEWindow;
		table : Table;

		PROCEDURE &Init*;
		BEGIN
			NEW(table); table.LoadCharacters; table.LoadPhrases;
		END Init;

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;

		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keysym : LONGINT);
		VAR x, y, pos : LONGINT; str : ARRAY 8 OF CHAR;
		BEGIN
(*			IF text.isUTF THEN
				KernelLog.String("Chinese characters are currently not allowed in potentially bidirectionally formatted texts.");
				KernelLog.Ln;
			END; *)
			IF (cap[ucs MOD 256] >= "A") & (cap[ucs MOD 256] <= "Z") THEN
				GetCursorScreenPosition(x, y);
				pos := 0; IF UTF8Strings.EncodeChar(ucs, str, pos) THEN END;
				NEW(w, SELF, x, y, str, table);
			ELSE
				InsertChar(ucs);
			END;
		END KeyEvent;

		PROCEDURE Finalize;
		END Finalize;

	END IME;

VAR
	cap : ARRAY 256 OF CHAR; (* lookup for capital characters *)
	isNum : ARRAY 256 OF BOOLEAN;

(** match a pinyin pattern with a given string. If the pattern contains tone information,
	only strings matching the tone are returned. If the pattern does not contain tone
	information, strings with or without tone information will match. Spaces are ignored*)
PROCEDURE MatchPinyin*(pattern, string : ARRAY OF CHAR; complete : BOOLEAN) : BOOLEAN;
VAR i, j, lp, ls : LONGINT; match : BOOLEAN;
BEGIN
	lp := LEN(pattern); ls := LEN(string);
	Strings.Trim(pattern, " "); Strings.Trim(string, " ");
	i := 0; j := 0; match := TRUE;
	REPEAT
		IF ((i >= lp) OR (j >= ls)) THEN RETURN FALSE END;
		IF cap[ORD(pattern[i])] = cap[ORD(string[j])] THEN INC(i); INC(j)
		ELSIF string[j] = " " THEN INC(j) (* skip space *)
		ELSIF pattern[i] = " " THEN INC(i) (* skip space *)
		ELSIF isNum[ORD(string[j])] & ~isNum[ORD(pattern[i])] THEN INC(j)
		ELSE match := FALSE
		END
	UNTIL (pattern[i] = 0X) OR ~match;
	IF complete & match & (~ ((string[j] = 0X) OR isNum[ORD(string[j])] & (string[j + 1] = 0X)) ) THEN
		match := FALSE
	END;
	RETURN match
END MatchPinyin;

PROCEDURE MatchPinyinFirstChars*(pattern, string : ARRAY OF CHAR; complete : BOOLEAN) : BOOLEAN;
VAR i, j, ls : LONGINT; match : BOOLEAN;
BEGIN
	ls := LEN(string);
	Strings.Trim(pattern, " "); Strings.Trim(string, " ");
	i := 0; j := 0; match := TRUE;
	WHILE (pattern[i] # 0X) & (j < ls) & match DO
		IF cap[ORD(pattern[i])] # cap[ORD(string[j])] THEN match := FALSE END;
		INC(i);
		INC(j);
		WHILE(j < ls) & (string[j] # 0X) & (~isNum[ORD(string[j])]) DO INC(j) END;
		INC(j)
	END;
	RETURN match
END MatchPinyinFirstChars;

(* installs the Pinyin IME *)
PROCEDURE Install*;
VAR ime : IME;
BEGIN
	NEW(ime);
	WMInputMethods.InstallIME(ime);
END Install;

(** Merge-sort a single-linked list. The root element is a dummy node *)
(* Algorithm by Simon Tatham *)
PROCEDURE Sort(root: ListElement; compare : CompareProc);	(* root is dummy node *)
VAR m, n, np, nq: LONGINT; p, q, tail: ListElement;
BEGIN
	n := 1;
	REPEAT
		p := root.next; q := p; tail := root; m := 0;
		WHILE p # NIL DO	(* merge sorted lists of length n into sorted lists of length 2*n (sort of) *)
			np := 0;	(* step q over <= n nodes *)
			REPEAT q := q.next; INC(np) UNTIL (q = NIL) OR (np = n);
			nq := n; INC(m);
			LOOP	(* merge list p with np nodes and list q with <= nq nodes at end of tail *)
				IF (np # 0) & ((nq = 0) OR (q = NIL) OR (compare(p, q) <= 0)) THEN
					tail.next := p; tail := p; p := p.next; DEC(np)
				ELSIF (nq # 0) & (q # NIL) THEN
					tail.next := q; tail := q; q := q.next; DEC(nq)
				ELSE	(* (np = 0) & ((nq = 0) OR (q = NIL)) *)
					EXIT
				END
			END;
			tail.next := NIL; p := q
		END;
		n := n*2
	UNTIL m <= 1
END Sort;

PROCEDURE CompareResultListFreq(a, b: ListElement) : LONGINT;
BEGIN
	IF a(ResultList).freq < b(ResultList).freq THEN RETURN -1 END;
	IF a(ResultList).freq > b(ResultList).freq THEN RETURN 1 END;

	(* make sure same characters fall together for the elimination of duplicates *)
	IF a(ResultList).hanzi^ < b(ResultList).hanzi^ THEN RETURN -1 END;
	IF a(ResultList).hanzi^ > b(ResultList).hanzi^ THEN RETURN 1 END;

	(* make sure to get the tones ordered *)
	IF a(ResultList).pinyin^ < b(ResultList).pinyin^ THEN RETURN -1 END;
	IF a(ResultList).pinyin^ > b(ResultList).pinyin^ THEN RETURN 1 END;
	RETURN 0
END CompareResultListFreq;

PROCEDURE SortPhraseInfoPinyin(a, b: ListElement) : LONGINT;
BEGIN
	IF a(PhraseInfo).phrase^ < b(PhraseInfo).phrase^ THEN RETURN -1 END;
	IF a(PhraseInfo).phrase^ > b(PhraseInfo).phrase^ THEN RETURN 1 END;
	RETURN 0
END SortPhraseInfoPinyin;

PROCEDURE InitLookup;
VAR i : LONGINT;
BEGIN
	(* to captial conversion table *)
	FOR i := 0 TO 255 DO cap[i] := CHR(i) END;
	FOR i := ORD("a") TO ORD("z") DO cap[i] := CHR(i - 32) END;
	(* number lookup *)
	FOR i := 0 TO 255 DO isNum[i] := FALSE END;
	FOR i := ORD("0") TO ORD("9") DO isNum[i] := TRUE END
END InitLookup;

PROCEDURE Cleanup;
BEGIN
	IF (WMInputMethods.defaultIME # NIL) & (WMInputMethods.defaultIME IS IME) THEN
		WMInputMethods.defaultIME(IME).Finalize
	END;
	WMInputMethods.InstallIME(NIL);
END Cleanup;

BEGIN
	InitLookup;
	Modules.InstallTermHandler(Cleanup)
END WMPinyinIME.

SystemTools.Free WMPinyinIME ~
WMPinyinIME.Install ~
