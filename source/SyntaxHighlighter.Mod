MODULE SyntaxHighlighter; (** AUTHOR "staubesv"; PURPOSE "Simple Syntax Highlighter"; *)

IMPORT
	KernelLog,
	Streams, Commands, Strings, Files, Diagnostics, Texts, TextUtilities, XML, XMLScanner, XMLParser, XMLObjects;

CONST
	DefineMask* = {0..5};
	FontMask* = {0..2};

	FontName* = 0;
	FontSize* = 1;
	FontStyle* = 2;
	Color* = 3;
	BgColor* = 4;
	Voff* = 5;

	DefaultBgColor = 0;
	DefaultVoff = 0;

	DefaultHighlighterFile = "SyntaxHighlighter.XML";

	XmlRootElementName = "SyntaxHighlighter";
	XmlHighlighters = "Highlighters";
	XmlHighlighter = "Highlighter";
	XmlWords = "Words";
	XmlTokens = "Tokens";
	XmlAttributeAllowCharacters = "allowCharacters";
	XmlStyles = "Styles";
	XmlStyle = "Style";
	XmlAttributeName = "name";
	XmlAttributeDefaultStyle = "defaultstyle";
	XmlAttributeNumberStyle = "numberStyle";
	XmlAttributeFontName = "fontname";
	XmlAttributeFontSize = "fontsize";
	XmlAttributeFontStyle = "fontstyle";
	XmlAttributeColor = "color";
	XmlAttributeBgColor = "bgcolor";
	XmlAttributeVoff = "voff";
	XmlAttributeStyle = "style";
	XmlAttributeStyleOpen = "styleOpen";
	XmlAttributeStyleClose = "styleClose";
	XmlAttributeStyleContent = "style";
	XmlGroup = "Group";
	XmlRegions = "Regions";
	XmlRegion = "Region";
	XmlAttributeOpen = "open";
	XmlAttributeClose = "close";
	XmlAttributeNesting = "nesting";
	XmlAttributeMultiLine = "multiline";
	XmlDontCare = "*";

	Trace_None = 0;
	Trace_1 = 1;
	Trace_Max = 2;

	Statistics = TRUE;

	NOTCLOSED = MAX(LONGINT) - 128; (* some safety distance to protect against overflow *)

	MaxOpenLength = 32;
	MaxCloseLength = 32;

	MaxWordLength = 32;
	Dim1Length = 128;
	MaxTokenLength = 64;

	Ok = 0;
	StringTooLong = 1;

	Outside = 0;
	OpenString = 1;
	Content = 2;
	CloseString = 3;

	NoMatch = 0;
	Matching = 1;
	OpenMatch = 2;
	CloseMatch = 3;

	(* token types and subtypes*)
	Type_Invalid* = 0;
	Type_Identifier* = 1;
	Type_Number* = 2;
	Type_Token* = 3;
		Subtype_Decimal* = 0;
		Subtype_Hex* = 1;
		Subtype_Float* = 2;
	Subtype_Char* = 3;


	TypeWords = 1;
	TypeTokens = 2;

TYPE
	Identifier = ARRAY 64 OF CHAR;

	Style* = OBJECT
	VAR
		name- : Identifier;
		attributes- : Texts.Attributes;
		defined- : SET;
		next : Style;

		PROCEDURE &Init(CONST name : Identifier; color, bgcolor, voff : LONGINT; CONST fontname : ARRAY OF CHAR; fontsize : LONGINT; fontstyle : SET);
		BEGIN
			ASSERT(name # "");
			SELF.name := name;
			NEW(attributes);
			attributes.Set(color, bgcolor, voff, fontname, fontsize, fontstyle);
			defined := {};
			next := NIL;
		END Init;

	END Style;

	Styles = OBJECT
	VAR
		styles : Style; (* head of list *)

		PROCEDURE &Init;
		BEGIN
			styles := NIL;
		END Init;

		PROCEDURE Add(style : Style);
		BEGIN {EXCLUSIVE}
			ASSERT(FindIntern(style.name) = NIL);
			style.next := styles;
			styles := style;
		END Add;

		PROCEDURE Find(CONST name : ARRAY OF CHAR) : Style;
		BEGIN {EXCLUSIVE}
			RETURN FindIntern(name);
		END Find;

		PROCEDURE FindIntern(CONST name : ARRAY OF CHAR) : Style;
		VAR style : Style;
		BEGIN
			style := styles;
			WHILE (style # NIL) & (style.name # name) DO style := style.next; END;
			RETURN style;
		END FindIntern;

	END Styles;

TYPE

	Word = POINTER TO RECORD
		name : ARRAY MaxWordLength OF CHAR;
		style : Style; (* { style # NIL } *)
		next : Word;
	END;

	DataEntry = RECORD
		open, close  : LONGINT; (* region *)
		region : RegionMatcher; (* { region # NIL } *)
		eol : BOOLEAN;
	END;

	DataArray = POINTER TO ARRAY OF DataEntry;

	State* = OBJECT
	VAR
		matchers : RegionMatcher;

		data : DataArray; (* {data # NIL} *)
		nofData : LONGINT;

		PROCEDURE &Init;
		BEGIN
			matchers := NIL;
			NEW(data, 128);
			nofData := 0;
		END Init;

		PROCEDURE AddMatcher(matcher : RegionMatcher);
		VAR m : RegionMatcher;
		BEGIN
			ASSERT((matcher # NIL) & (matcher.next = NIL));
			IF (matchers = NIL) THEN
				matchers := matcher;
			ELSE
				m := matchers;
				WHILE (m.next # NIL) DO m := m.next; END;
				m.next := matcher;
			END;
		END AddMatcher;

		PROCEDURE ResetMatchers;
		VAR m : RegionMatcher;
		BEGIN
			m := matchers;
			WHILE (m # NIL) DO
				m.ResetMatching;
				m := m.next;
			END;
		END ResetMatchers;

		PROCEDURE GetStyle(position : LONGINT; VAR start, end : LONGINT) : Style;
		VAR style : Style; entry : DataEntry; location : LONGINT;
		BEGIN
			style := NIL;
			IF Find(position, entry) THEN
				location := GetLocation(position, entry);
				IF (location = OpenString) THEN
					style := entry.region.styleOpen;
					start := entry.open; end := entry.open + entry.region.openLength - 1;
				ELSIF (location = Content) THEN
					style := entry.region.styleContent;
					start := entry.open + entry.region.openLength; end := entry.close - entry.region.closeLength;
				ELSIF (location = CloseString) THEN
					style := entry.region.styleClose;
					start := entry.close - entry.region.closeLength + 1; end := entry.close;
				ELSE
					HALT(99);
				END;
			END;
			RETURN style;
		END GetStyle;

		PROCEDURE Find(CONST position : LONGINT; VAR entry : DataEntry) : BOOLEAN;
		VAR l, r, m : LONGINT;
		BEGIN
			(* binary search *)
			l := 0; r := nofData;
			WHILE l < r DO
				m := (r - l) DIV 2 + l;
				IF (position <= data[m].close) THEN r := m;
				ELSE l := m + 1;
				END;
			END;
			IF (r < nofData) & (data[r].open <= position) & (position <= data[r].close) THEN
				entry := data[r];
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Find;

		PROCEDURE FindTriple(position : LONGINT; VAR hasLeft, hasMiddle, hasRight : BOOLEAN; VAR left, middle, right : DataEntry);
		VAR i : LONGINT;
		BEGIN
			hasLeft := FALSE; hasMiddle := FALSE; hasRight := FALSE;
			IF (nofData > 0) THEN
				i := 0;
				WHILE (i < nofData) & (data[i].close < position) DO INC(i); END;
				IF (i > 0) THEN
					hasLeft := TRUE; left := data[i-1];
				END;
				IF (i < nofData) & (data[i].open <= position) & (position <= data[i].close) THEN
					hasMiddle := TRUE; middle := data[i];
				END;
				IF (i < nofData - 1) THEN
					hasRight := TRUE; right := data[i + 1];
				END;
			END;
		END FindTriple;

		PROCEDURE Patch(fromPosition : LONGINT; length : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF (nofData > 0) THEN
				i := 0;
				WHILE (i < nofData) & (data[i].close < fromPosition) DO INC(i); END;
				WHILE (i < nofData) DO
					data[i].close := data[i].close + length;
					IF (data[i].open >= fromPosition) THEN
						data[i].open := data[i].open + length;
					END;
					INC(i);
				END;
			END;
		END Patch;

		PROCEDURE Add(CONST entry : DataEntry);
		VAR insertAt, i : LONGINT;
		BEGIN
			ASSERT(entry.region # NIL);
			insertAt := 0;
			WHILE (insertAt < nofData) & (entry.open > data[insertAt].close) DO INC(insertAt); END;
			INC(nofData); (* we will add one data element ... *)
			IF (nofData >= LEN(data)) THEN EnlargeDataArray; END;
			FOR i := nofData - 1 TO insertAt + 1 BY -1 DO
				data[i] := data[i-1];
			END;
			data[insertAt] := entry;
		END Add;

		PROCEDURE Remove(CONST entry : DataEntry);
		VAR removeIdx, i : LONGINT;
		BEGIN
			IF (nofData > 0) THEN
				removeIdx := 0;
				WHILE (removeIdx < nofData) & (data[removeIdx].open # entry.open) & (data[removeIdx].close # entry.close) DO
					INC(removeIdx);
				END;
				FOR i := removeIdx TO nofData - 2 DO
					data[i] := data[i + 1];
				END;
				DEC(nofData);
			END;
		END Remove;

		PROCEDURE RemoveFrom(position : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF (nofData > 0) THEN
				i := 0;
				WHILE (i < nofData) & (data[i].close < position) DO INC(i); END;
				nofData := i;
			END;
		END RemoveFrom;

		PROCEDURE RemoveFromTo(position, length : LONGINT) : BOOLEAN;
		VAR removedEntries : BOOLEAN; i : LONGINT;
		BEGIN
			removedEntries := FALSE;
			IF (nofData > 0) THEN
				i := 0;
				WHILE (i < nofData) & (data[i].close < position) DO INC(i); END;
				IF (i < nofData - 1) & (position + length - 1 >= data[i].open) THEN
					nofData := i;
					removedEntries := TRUE;
				END;
			END;
			RETURN removedEntries;
		END RemoveFromTo;

		PROCEDURE Clear;
		BEGIN
			nofData := 0;
		END Clear;

		PROCEDURE EnlargeDataArray;
		VAR newData : DataArray; i : LONGINT;
		BEGIN
			NEW(newData, 2 * LEN(data));
			FOR i := 0 TO LEN(data)-1 DO
				newData[i] := data[i];
			END;
			data := newData;
		END EnlargeDataArray;

		PROCEDURE ShowEntry(CONST entry : DataEntry; out : Streams.Writer);
		BEGIN
			ASSERT(out # NIL);
			out.String("From "); out.Int(entry.open, 0); out.String(" to "); out.Int(entry.close, 0);
			out.Ln;
		END ShowEntry;

		PROCEDURE Dump(out : Streams.Writer);
		VAR i : LONGINT;
		BEGIN
			ASSERT(out # NIL);
			out.String("Region dump : "); out.Int(nofData, 0); out.String(" entries"); out.Ln;
			IF (nofData > 0) THEN
				FOR i := 0 TO nofData - 1 DO
					ShowEntry(data[i], out);
				END;
			END;
		END Dump;

	END State;

TYPE

	RegionDescriptor = OBJECT
	VAR
		open, close : Identifier;
		nesting, multiline : BOOLEAN;
		styleOpen, styleClose, styleContent : Style;
		openLength, closeLength : LONGINT;

		next : RegionDescriptor;

		PROCEDURE &Init(CONST open, close : ARRAY OF CHAR; nesting, multiline : BOOLEAN; styleOpen, styleClose, styleContent : Style);
		BEGIN
			Copy(open, SELF.open); openLength := Strings.Length(open); ASSERT((openLength > 0) & (openLength < MaxOpenLength));
			Copy(close, SELF.close); closeLength := Strings.Length(close); ASSERT((closeLength >= 0) & (closeLength < MaxCloseLength));
			SELF.nesting := nesting;
			SELF.multiline := multiline;
			SELF.styleOpen := styleOpen;
			SELF.styleClose := styleClose;
			SELF.styleContent := styleContent;
			next := NIL;
		END Init;

	END RegionDescriptor;

TYPE

	RegionMatcher = OBJECT
	VAR
		open, close : Identifier;
		nesting, multiline : BOOLEAN;
		styleOpen, styleClose, styleContent : Style;
		openLength, closeLength : LONGINT;

		openChars : ARRAY MaxOpenLength OF CHAR;
		closeChars : ARRAY MaxCloseLength OF CHAR;
		firstOpenChar, nofOpenChars, firstCloseChar, nofCloseChars : LONGINT;
		lastChar : CHAR;

		entry : DataEntry;

		level : LONGINT;

		state : LONGINT;
		firstPosition : LONGINT;

		next : RegionMatcher;

		PROCEDURE &Init(descriptor : RegionDescriptor);
		BEGIN
			ASSERT(descriptor # NIL);
			Copy(descriptor.open, SELF.open); openLength := descriptor.openLength;
			Copy(descriptor.close, SELF.close); closeLength := descriptor.closeLength;
			SELF.nesting := descriptor.nesting;
			SELF.multiline := descriptor.multiline;
			SELF.styleOpen := descriptor.styleOpen;
			SELF.styleClose := descriptor.styleClose;
			SELF.styleContent := descriptor.styleContent;
			ResetMatching;
			next := NIL;
		END Init;

		PROCEDURE GetEntry() : DataEntry;
		BEGIN
			RETURN entry;
		END GetEntry;

		PROCEDURE ResetMatching;
		BEGIN
			nofOpenChars := 0; nofCloseChars := 0;
			lastChar := 0X;
			level := 0;
			state := NoMatch;
			firstPosition := MAX(LONGINT);
		END ResetMatching;

		PROCEDURE CheckOpen(reader : Texts.TextReader; position : LONGINT; VAR length : LONGINT) : BOOLEAN;
		VAR char32 : Texts.Char32; oldPosition : LONGINT;
		BEGIN
			ASSERT(reader # NIL);
			length := 0;
			oldPosition := reader.GetPosition();
			reader.SetPosition(position);
			reader.ReadCh(char32);
			WHILE (length < openLength) & (open[length] = CHR(char32)) & ~reader.eot DO reader.ReadCh(char32); INC(length); END;
			IF (length = openLength) THEN
				ResetMatching;
				entry.open := position;
				entry.close := NOTCLOSED;
				entry.region := SELF;
				entry.eol := FALSE;
				state := OpenMatch;
				level := 1;
				firstPosition := position;
			END;
			RETURN length = openLength;
		END CheckOpen;

		PROCEDURE FeedChar(char32 : Texts.Char32; position : LONGINT; VAR newState : LONGINT);
		VAR char : CHAR; openMatch, closeMatch : BOOLEAN;

			PROCEDURE AddToCircularBuffer(char : CHAR; VAR buffer : ARRAY OF CHAR; VAR first, length, maxLength : LONGINT);
			BEGIN
				buffer[(first + length) MOD LEN(buffer)] := char;
				IF (length = maxLength) THEN
					first := (first + 1) MOD LEN(buffer);
				ELSE
					ASSERT(length < maxLength);
					INC(length);
				END;
			END AddToCircularBuffer;

			PROCEDURE CheckBuffer(CONST buffer, compareTo : ARRAY OF CHAR; VAR first, length, maxLength : LONGINT) : BOOLEAN;
			VAR i : LONGINT;
			BEGIN
				ASSERT(length = maxLength);
				i := 0;
				WHILE (i < maxLength) & (buffer[(first + i) MOD LEN(buffer)] = compareTo[i]) DO INC(i); END;
				IF (i = maxLength) THEN
					length := 0; (* clear buffer *)
					RETURN TRUE;
				ELSE
					REPEAT
						first := (first + 1) MOD LEN(buffer);
						DEC(length);
					UNTIL (length = 0) OR (buffer[first] = compareTo[0]);
					RETURN FALSE;
				END;
			END CheckBuffer;

		BEGIN
			ASSERT(level >= 0);
			openMatch := FALSE; closeMatch := FALSE;

			char := CHR(char32);

			IF (level = 0) OR nesting THEN (* allow matching to open string *)
				IF (openLength = 1) THEN
					openMatch := (char = open[0]);
				ELSIF (openLength = 2) THEN
					openMatch := (char = open[1]) & (lastChar = open[0]);
				ELSIF (char = open[0]) OR (nofOpenChars > 0) THEN (* start OR continue to save characters *)
					AddToCircularBuffer(char, openChars, firstOpenChar, nofOpenChars, openLength);
					IF (nofOpenChars = openLength) THEN
						openMatch := CheckBuffer(openChars, open, firstOpenChar, nofOpenChars, openLength);
					END;
				END;
				IF openMatch THEN
					nofOpenChars := 0; lastChar := 0X;
					INC(level);
					IF (level = 1) THEN
						entry.open := position - openLength + 1;
						entry.close := NOTCLOSED;
						entry.region := SELF;
						entry.eol := FALSE;
					END;
				END;
			ELSE
				nofOpenChars := 0;
			END;

			IF ~openMatch & (level > 0) THEN (* allow matching to close string *)
				IF (closeLength = 1) THEN
					closeMatch := (char = close[0]);
				ELSIF (closeLength = 2) THEN
					closeMatch := (char = close[1]) & (lastChar = close[0]);
				ELSIF (closeLength > 0) & ((char = close[0]) OR (nofCloseChars > 0)) THEN
					AddToCircularBuffer(char, closeChars, firstCloseChar, nofCloseChars, closeLength);
					IF (nofCloseChars = closeLength) THEN
						closeMatch := CheckBuffer(closeChars, close, firstCloseChar, nofCloseChars, closeLength);
					END;
				END;
				IF ~multiline & (char = CHR(Texts.NewLineChar)) & (~closeMatch OR (level > 0)) THEN
					nofCloseChars := 0;
					level := 0;
					entry.close := position;
					entry.eol := TRUE;
					(* don't set closeMatch here since entry.end position may be different for EOL match *)
				ELSIF closeMatch THEN
					nofCloseChars := 0; lastChar := 0X;
					DEC(level);
					IF (level = 0) THEN
						entry.close := position;
					END;
				END;
			ELSE
				nofCloseChars := 0; (* clear buffer *)
			END;
			IF ~openMatch & ~closeMatch THEN lastChar := char; END;

			IF (state = NoMatch) THEN
				IF openMatch THEN state := OpenMatch; firstPosition := position;
				ELSIF (nofOpenChars > 0) THEN state := Matching; firstPosition := position;
				END;
			ELSIF (state = Matching) THEN
				IF openMatch THEN state := OpenMatch;
				ELSIF (nofOpenChars = 1) THEN state := Matching; firstPosition := position;
				ELSIF (nofOpenChars > 1) THEN state := Matching;
				ELSE state := NoMatch;
				END;
			ELSIF (state = OpenMatch) THEN
				IF (level = 0) THEN state := CloseMatch; END;
			ELSIF (state = CloseMatch) THEN
				(* no more state transitions until reset *)
			END;
			newState := state;
		END FeedChar;

	END RegionMatcher;

TYPE

	Token* = RECORD
		type-, subtype- : SHORTINT;
		startPosition-, endPosition- : LONGINT;
		value- : ARRAY MaxTokenLength OF CHAR;
		length : LONGINT; (* if type = Type_Identifier: of string value *)
		style- : Style;
	END;

TYPE

	Highlighter* = OBJECT
	VAR
		name : Identifier;
		defaultStyle, numberStyle : Style;

		words : ARRAY Dim1Length OF ARRAY MaxWordLength OF Word;
		wildcardWords : ARRAY MaxWordLength OF Word;
		wildcardsEnabled : BOOLEAN;

		tokens : ARRAY Dim1Length OF RECORD
			length : ARRAY MaxWordLength OF  Word;
			maxLength : LONGINT;
		END;

		regions : RegionDescriptor;
		longestOpen, longestClose : LONGINT;

		regionChars, wordChars, isAllowedCharacter : ARRAY 256 OF BOOLEAN;

		next : Highlighter;

		PROCEDURE &Init(CONST name : ARRAY OF CHAR);
		VAR i, j : LONGINT;
		BEGIN
			ASSERT(name # "");
			Copy(name, SELF.name);
			defaultStyle := NIL; numberStyle := NIL;
			FOR i := 0 TO Dim1Length-1 DO
				FOR j := 0 TO MaxWordLength-1 DO
					words[i][j] := NIL;
					tokens[i].length[j] := NIL;
					tokens[i].maxLength := 0;
				END;
			END;
			FOR i := 0 TO LEN(wildcardWords)-1 DO wildcardWords[i] := NIL; END;
			wildcardsEnabled := FALSE;
			regions := NIL;
			longestOpen := 0; longestClose := 0;
			FOR i := 0 TO LEN(regionChars)-1 DO
				regionChars[i] := FALSE; wordChars[i] := FALSE;
				isAllowedCharacter[i] := FALSE;
			END;
			FOR i := ORD("a") TO ORD("z") DO isAllowedCharacter[i] := TRUE; END;
			FOR i := ORD("A") TO ORD("Z") DO isAllowedCharacter[i] := TRUE; END;
			FOR i := ORD("0") TO ORD("9") DO isAllowedCharacter[i] := TRUE; END;
			next := NIL;
		END Init;

		PROCEDURE IsAllowedCharacter*(character : Texts.Char32) : BOOLEAN;
		BEGIN
			RETURN (character < 256) & isAllowedCharacter[character MOD 256];
		END IsAllowedCharacter;

		PROCEDURE AllowCharacter(character : CHAR);
		BEGIN
			isAllowedCharacter[ORD(character)] := TRUE;
		END AllowCharacter;

		PROCEDURE Scan(reader : Texts.TextReader; from, to : LONGINT; CONST state : State; VAR match : BOOLEAN);
		VAR
			matcher, owner, oldOwner : RegionMatcher; char32 : Texts.Char32; continue : BOOLEAN; entry : DataEntry; oldPosition, position : LONGINT;
			mstate, tempState, nofMatching : LONGINT;

			PROCEDURE CheckLongestMatch(VAR owner : RegionMatcher);
			VAR matcher : RegionMatcher; length, maxLength : LONGINT;
			BEGIN
				ASSERT(owner # NIL);
				maxLength := owner.openLength;
				matcher := state.matchers;
				WHILE (matcher # NIL) DO
					IF (matcher.state = Matching) & (matcher.firstPosition <= owner.firstPosition) THEN
						IF matcher.CheckOpen(reader, matcher.firstPosition, length) & ((matcher.firstPosition < owner.firstPosition) OR (length > maxLength)) THEN
							maxLength := length;
							owner := matcher;
						END;
					END;
					matcher := matcher.next;
				END;
				ASSERT(owner # NIL);
			END CheckLongestMatch;

		BEGIN
			ASSERT((reader # NIL) & (state # NIL));
			IF (traceLevel >= Trace_1) THEN
				KernelLog.String("Scan from ");
				KernelLog.Int(from, 0); KernelLog.String(" to "); KernelLog.Int(to, 0);
				KernelLog.Ln;
			END;
			state.ResetMatchers;
			match := FALSE;
			owner := NIL; continue := FALSE;
			reader.SetPosition(from); position := reader.GetPosition();
			reader.SetDirection(1);
			reader.ReadCh(char32);
			WHILE ~reader.eot & (position <= to) DO
				IF (owner # NIL) THEN
					mstate := owner.state;
					ASSERT(mstate = OpenMatch);
					WHILE (mstate # CloseMatch) & ~reader.eot & (position <= to) DO
						owner.FeedChar(char32, position, mstate);
						reader.ReadCh(char32);
						INC(position);
					END;
					entry := owner.GetEntry();
					state.Add(entry);
					state.ResetMatchers;
					owner := NIL;
				ELSE
					owner := NIL; nofMatching := 0;
					mstate := NoMatch;
					matcher := state.matchers;
					WHILE (matcher # NIL) DO
						matcher.FeedChar(char32, position, tempState);
						IF (tempState = Matching) THEN
							INC(nofMatching);
						ELSIF (tempState = OpenMatch) THEN
							owner := matcher;
						END;
						matcher := matcher.next;
					END;
					match := match OR (owner # NIL);
					IF (owner # NIL) & (nofMatching > 1) THEN
						oldPosition := reader.GetPosition();
						oldOwner := owner;
						CheckLongestMatch(owner);
						IF (owner # oldOwner) THEN
							position := owner.firstPosition + owner.openLength;
							reader.SetPosition(position);
							reader.ReadCh(char32);
						ELSE
							reader.SetPosition(oldPosition);
							reader.ReadCh(char32);
							INC(position);
						END;
					ELSE
						reader.ReadCh(char32);
						INC(position);
					END;
				END;
			END;
		END Scan;

		PROCEDURE RebuildRegions*(reader : Texts.TextReader; CONST state : State);
		VAR ignore : BOOLEAN;
		BEGIN
			ASSERT((reader # NIL) & (state # NIL));
			IF Statistics THEN INC(NnofRebuildRegions); END;
			state.Clear;
			state.ResetMatchers;
			Scan(reader, 0, MAX(LONGINT), state, ignore);
		END RebuildRegions;

		PROCEDURE PatchRegions*(info : Texts.TextChangeInfo;  reader : Texts.TextReader; state : State; VAR fullLayout : BOOLEAN);
		VAR
			char32 : Texts.Char32;

			PROCEDURE NeedRescan(position, length : LONGINT) : BOOLEAN;
			VAR rescan : BOOLEAN; i : LONGINT;
			BEGIN
				rescan := FALSE;
				reader.SetPosition(position);
				i := 0;
				WHILE (i < length) & ~rescan DO
					reader.ReadCh(char32);
					rescan := rescan OR regionChars[ORD(CHR(char32))];
					INC(i);
				END;
				RETURN rescan;
			END NeedRescan;

			PROCEDURE PatchInsert(position, length : LONGINT; VAR fullLayout : BOOLEAN);
			VAR
				hasLeft, hasMiddle, hasRight : BOOLEAN;
				left, middle, right : DataEntry;
				res : BOOLEAN;
				start, end, oldStart, oldEnd : LONGINT;
				ignore, match : BOOLEAN;
				location : LONGINT;
			BEGIN
				IF Statistics THEN INC(NnofPatchInsert); END;
				fullLayout := FALSE;
				state.FindTriple(position, hasLeft, hasMiddle, hasRight, left, middle, right);
				IF hasMiddle & (position > middle.open) THEN
					IF Statistics THEN INC(NnofPatchInsertHit); END;
					location := GetLocation(position, middle);
					IF (location = OpenString) OR ((location = CloseString) & (position > middle.close - middle.region.closeLength + 1)) THEN
						IF Statistics THEN INC(NnofPiOpenClose); END;
						state.RemoveFrom(position);
						Scan(reader, middle.open, MAX(LONGINT), state, ignore);
						fullLayout := TRUE;
					ELSIF middle.region.nesting THEN
						oldStart := middle.open;
						oldEnd := middle.close;
						state.Remove(middle);
						Scan(reader, oldStart, oldEnd + length, state, ignore);
						res := state.Find(position, middle);
						IF 		~res OR
								(middle.open # oldStart) OR
								((oldEnd # NOTCLOSED) & (middle.close # oldEnd + length)) OR
								((oldEnd = NOTCLOSED) & (middle.close # NOTCLOSED)) THEN
							IF Statistics THEN INC(NnofPiNestedFull); END;
							state.RemoveFrom(position);
							Scan(reader, oldStart, MAX(LONGINT), state, ignore);
							fullLayout := TRUE;
						ELSE
							IF Statistics THEN INC(NnofPiNestedSimple); END;
							state.Patch(middle.close + 1, length); (* middle is already patched *)
						END;
					ELSIF NeedRescan(position, length) THEN
						IF Statistics THEN INC(NnofPiRescan); END;
						state.RemoveFrom(position); (* TBD optimize *)
						Scan(reader, middle.open, MAX(LONGINT), state, ignore);
						fullLayout := TRUE;
					ELSE
						IF Statistics THEN INC(NnofPiSimple); END;
						state.Patch(position, length);
					END;
				ELSE
					IF Statistics THEN INC(NnofPiNoHit); END;
					state.Patch(position, length);
					IF NeedRescan(position, length) THEN
						IF Statistics THEN INC(NnofPiNoHitRescan); END;
						start := position - longestOpen + 1;
						IF (longestClose > 0) THEN
							end := position + length + longestClose - 1;
						ELSE
							end := position + length;
						END;
						IF hasLeft & (left.close >= start) THEN start := left.close + 1; END;
						IF hasRight & (right.open + length <= end) THEN end := right.open + length - 1; END; (* manually patched since copy *)
						Scan(reader, start, end, state, match);
						IF match THEN
							IF Statistics THEN INC(NnofPiNoHitFull); END;
							state.RemoveFrom(start);
							Scan(reader, start, MAX(LONGINT), state, match);
							fullLayout := TRUE;
						END;
					END;
				END;
			END PatchInsert;

			PROCEDURE PatchDelete(position, length : LONGINT; VAR fullLayout : BOOLEAN);
			VAR
				hasLeft, hasMiddle, hasRight : BOOLEAN;
				left, middle, right : DataEntry;
				start, end, oldStart, oldEnd : LONGINT;
				match, ignore, res : BOOLEAN;
				location : LONGINT;
			BEGIN
				fullLayout := FALSE;
				state.FindTriple(position, hasLeft, hasMiddle, hasRight, left, middle, right);
				IF hasMiddle THEN
					location := GetLocation(position, middle);
					IF (middle.region.closeLength > 0) THEN end := middle.close - middle.region.closeLength + 1; ELSE end := middle.close; END;
					IF (location = Content) & (position + length - 1 < end) THEN
						oldStart := middle.open;
						oldEnd := middle.close;
						state.Remove(middle);
						Scan(reader, middle.open, middle.close, state, ignore);
						res := state.Find(position, middle);
						IF 		~res OR
								(middle.open # oldStart) OR
								((oldEnd # NOTCLOSED) & (middle.close # oldEnd - length)) OR
								((oldEnd = NOTCLOSED) & (middle.close # NOTCLOSED)) THEN
							state.RemoveFrom(position);
							Scan(reader, oldStart, MAX(LONGINT), state, ignore);
							fullLayout := TRUE;
						ELSE
							state.Patch(middle.close + 1, -length);
						END;
					ELSE
						state.RemoveFrom(position);
						Scan(reader, middle.open, MAX(LONGINT), state, ignore);
						fullLayout := TRUE;
					END;
				ELSE
					start := position - longestOpen + 1;
					IF hasLeft & (left.close >= start) THEN start := left.close + 1; END;
					IF state.RemoveFromTo(position, length) THEN
						Scan(reader, start, MAX(LONGINT), state, ignore);
						fullLayout := TRUE;
					ELSE
						end := position - 1;
						state.Patch(position, -length);
						Scan(reader, start, end, state, match);
						IF match THEN
							state.RemoveFrom(start);
							Scan(reader, start, MAX(LONGINT), state, ignore);
							fullLayout := TRUE;
						END;
					END;
				END;
			END PatchDelete;

		BEGIN
			ASSERT((info.op = Texts.OpInsert) OR (info.op = Texts.OpDelete));
			ASSERT(reader # NIL);
			IF Statistics THEN INC(NnofPatchRegions); END;
			IF traceLevel >= Trace_1 THEN
				IF (info.op = Texts.OpInsert) THEN KernelLog.String("INS ");
				ELSE KernelLog.String("DEL ");
				END;
				KernelLog.Int(info.len, 0); KernelLog.String("@"); KernelLog.Int(info.pos, 0);
				KernelLog.Ln;
			END;
			IF (info.op = Texts.OpInsert) THEN
				PatchInsert(info.pos, info.len, fullLayout);
			ELSE
				PatchDelete(info.pos, info.len, fullLayout);
			END;
		END PatchRegions;

		PROCEDURE GetDefaultStyle*() : Style;
		BEGIN
			RETURN defaultStyle;
		END GetDefaultStyle;

		PROCEDURE GetState*() : State;
		VAR state : State; r : RegionDescriptor; m : RegionMatcher;
		BEGIN
			NEW(state);
			r := regions;
			WHILE (r # NIL) DO
				NEW(m, r); state.AddMatcher(m);
				r := r.next;
			END;
			RETURN state;
		END GetState;

		PROCEDURE MatchToken(char32 : Texts.Char32; reader : Texts.TextReader; VAR lookaheadIdx : LONGINT; VAR token : Token) : BOOLEAN;
		VAR tokensIdx, maxLength, i : LONGINT; t : Word;
		BEGIN
			ASSERT(reader # NIL);
			tokensIdx := char32 MOD Dim1Length;
			maxLength := tokens[tokensIdx].maxLength;
			IF (maxLength > 0) THEN
				(* copy look-ahead into local buffer *)
				WHILE (lookaheadIdx < maxLength) & (char32 > 32) & ~reader.eot DO
					reader.ReadCh(char32);
					IF (char32 > 32) & ~reader.eot THEN
						token.value[lookaheadIdx] := CHR(char32);
						INC(lookaheadIdx);
					END;
				END;
				token.value[lookaheadIdx] := 0X;
				(* compare look-ahead to token list. longest-match first *)
				i := lookaheadIdx;
				WHILE (i > 0) & (token.type = Type_Invalid) DO
					t := tokens[tokensIdx].length[i - 1];
					WHILE (t # NIL) & ~Equal(t.name, token.value, i) DO t := t.next; END;
					IF (t # NIL) THEN
						token.type := Type_Token;
						token.style := t.style;
						ASSERT(token.style # NIL);
						token.endPosition := token.startPosition + i - 1;
						token.value[i] := 0X;
					END;
					DEC(i);
				END;
			END;
			RETURN (token.type # Type_Invalid);
		END MatchToken;

		(* Scan reader at its current position *)
		PROCEDURE GetToken*(reader : Texts.TextReader; position : LONGINT; VAR token : Token);
		VAR char32 : Texts.Char32; idx, i : LONGINT;
		BEGIN
			ASSERT(reader # NIL);
			token.type := Type_Invalid;
			token.startPosition := position;
			token.endPosition := position - 1;
			token.value := "";
			token.style := NIL;

			reader.ReadCh(char32);
			IF (char32 > 32) THEN
				token.value[0] := CHR(char32);
				idx := 1;
				IF ~MatchToken(char32, reader, idx, token) THEN
					ASSERT(idx >= 1);
					(* check validity of lookahead buffer *)
					i := 0;
					WHILE (i < idx) & isAllowedCharacter[ORD(token.value[i])] DO INC(i); END;
					IF (i = idx) THEN
						reader.ReadCh(char32);
						WHILE (char32 > 32) & ~reader.eot & (i < LEN(token.value)) & IsAllowedCharacter(char32) DO
							token.value[i] := CHR(char32);
							INC(i);
							reader.ReadCh(char32);
						END;
						token.endPosition := token.startPosition + i - 1;
						IF (i < LEN(token.value)) THEN
							token.value[i] := 0X;
							token.length := i;
							GetTokenType(token);
						ELSE
							(* token too long .. .skip! *)
							token.type := Type_Invalid;
							WHILE (char32 > 32) & ~reader.eot & IsAllowedCharacter(char32) DO
								reader.ReadCh(char32);
								INC(token.endPosition);
							END;
						END;
					ELSE
						token.value[i] := 0X;
						IF (i > 0) THEN
							token.length := i;
							GetTokenType(token);
						ELSE
							token.type := Type_Invalid;
						END;
					END;
				END;
			ELSE
				(* whitespace or eot -> token.type = Type_Invalid *)
			END;
		END GetToken;

		PROCEDURE GetWordStyle*(reader : Texts.TextReader; position : LONGINT; VAR end : LONGINT) : Style;
		VAR style : Style; token : Token;
		BEGIN
			ASSERT(reader # NIL);
			reader.SetPosition(position);
			GetToken(reader, position, token);
			end := token.endPosition;
			IF (token.type # Type_Invalid) THEN
				IF (token.type # Type_Token) THEN
					style := GetStyle(token.value, token.length); (* keywords have higher priority than numbers *)
					IF (style = NIL) & (token.type = Type_Number) THEN
						style := numberStyle;
					END;
				ELSE
					(* style assigned in MatchToken *)
					style := token.style;
				END;
			ELSE
				style := NIL;
			END;
			RETURN style;
		END GetWordStyle;

		PROCEDURE GetRegionStyle*(position : LONGINT; state : State; VAR start, end : LONGINT) : Style;
		BEGIN
			ASSERT(state # NIL);
			RETURN state.GetStyle(position, start, end);
		END GetRegionStyle;

		PROCEDURE GetStyle*(CONST keyword : ARRAY OF CHAR; length : LONGINT) : Style;
		VAR style : Style; word : Word; i : LONGINT;
		BEGIN
			ASSERT(length > 0);
			style := NIL;
			IF wordChars[ORD(keyword[0])] THEN
				IF (length <= MaxWordLength) THEN
					word := words[ORD(keyword[0]) MOD Dim1Length][length - 1];
					WHILE (word # NIL) & (word.name < keyword) DO word := word.next; END;
					IF (word # NIL) & (word.name = keyword) THEN
						style := word.style;
					END;
				END;
			END;
			IF (style = NIL) & wildcardsEnabled THEN
				i := 0;
				WHILE (i < length) & (i < MaxWordLength) & (style = NIL) DO
					word := wildcardWords[i];
					WHILE (word # NIL) & ~Strings.Match(word.name, keyword) DO word := word.next; END;
					IF (word # NIL) THEN
						style := word.style;
					END;
					INC(i);
				END;
			END;
			RETURN style;
		END GetStyle;

		PROCEDURE AddToken(CONST tokenname : ARRAY OF CHAR; style : Style; VAR res : LONGINT);
		VAR token, t : Word; length, index1, index2 : LONGINT;
		BEGIN
			ASSERT((Strings.Length(tokenname) > 0) & (style # NIL) & (style.name # ""));
			length := Strings.Length(tokenname);
			IF (length <= MaxWordLength) THEN
				NEW(token);
				COPY(tokenname, token.name);
				token.style := style;
				index1 := ORD(token.name[0]) MOD Dim1Length;
				index2 := length - 1;
				IF (tokens[index1].length[index2] = NIL) OR (tokens[index1].length[index2].name > token.name) THEN
					token.next := tokens[index1].length[index2];
					tokens[index1].length[index2] := token;
					IF (length > tokens[index1].maxLength) THEN tokens[index1].maxLength := length; END;
				ELSE
					t := tokens[index1].length[index2];
					WHILE (t.next # NIL) & (t.next.name < token.name) DO t := t.next; END;
					token.next := t.next;
					t.next := token;
				END;
				res := Ok;
			ELSE
				res := StringTooLong;
			END;
		END AddToken;

		PROCEDURE AddWord(CONST keyword : ARRAY OF CHAR; style : Style; VAR res : LONGINT);
		VAR word, w : Word; nofWildcards, index1, index2, length : LONGINT;
		BEGIN
			ASSERT((Strings.Length(keyword) > 0) & (style # NIL) & (style.name # ""));
			length := Strings.Length(keyword);
			IF (length <= MaxWordLength) THEN
				NEW(word);
				Copy(keyword, word.name);
				word.style := style;
				nofWildcards := NofWildcards(word.name);
				IF (nofWildcards = 0) THEN
					index1 := ORD(word.name[0]) MOD Dim1Length;
					index2 := length - 1;
					IF (words[index1][index2] = NIL) OR (words[index1][index2].name > word.name) THEN
						word.next := words[index1][index2];
						words[index1][index2] := word;
					ELSE
						w := words[index1][index2];
						WHILE (w.next # NIL) & (w.next.name < word.name) DO w := w.next; END;
						word.next := w.next;
						w.next := word;
					END;
					wordChars[ORD(word.name[0])] := TRUE;
				ELSE
					wildcardsEnabled := TRUE;
					index1 := length - nofWildcards - 1;
					word.next := wildcardWords[index1];
					wildcardWords[index1]  := word;
				END;
				res := Ok;
			ELSE
				res := StringTooLong;
			END;
		END AddWord;

		PROCEDURE AddRegion(CONST open, close : ARRAY OF CHAR; nesting, multiline : BOOLEAN; styleOpen, styleClose, styleContent : Style);
		VAR region, r : RegionDescriptor; length, i : LONGINT;
		BEGIN
			ASSERT((Strings.Length(open) > 0));
			NEW(region, open, close, nesting, multiline, styleOpen, styleClose, styleContent);
			(* append to list *)
			IF (regions = NIL) THEN
				regions := region;
			ELSE
				r := regions;
				WHILE (r.next # NIL) DO r := r.next; END;
				r.next := region;
			END;
			length := Strings.Length(open); IF (length > longestOpen) THEN longestOpen := length; END;
			FOR i := 0 TO length-1 DO
				regionChars[ORD(open[i])] := TRUE;
			END;

			length := Strings.Length(close); IF (length > longestClose) THEN longestClose := length; END;
			FOR i := 0 TO length-1 DO
				regionChars[ORD(close[i])] := TRUE;
			END;
		END AddRegion;

		PROCEDURE DebugInterface*(code : LONGINT; state : State);
		VAR out : Streams.Writer;
		BEGIN
			ASSERT(state # NIL);
			IF (code = 0) THEN
				NEW(out, KernelLog.Send, 256);
				KernelLog.String("SyntaxHighlighter: Dump:"); KernelLog.Ln;
				state.Dump(out);
			ELSIF (code = 1) THEN
				traceLevel := (traceLevel + 1) MOD (Trace_Max + 1);
				KernelLog.String("SyntaxHighlighter: TraceLevel = ");
				KernelLog.Int(traceLevel, 0); KernelLog.Ln;
			END;
		END DebugInterface;

		PROCEDURE Dump(out : Streams.Writer);

			PROCEDURE DumpWordList(out : Streams.Writer; word : Word);
			BEGIN
				ASSERT((out # NIL) & (word # NIL));
				WHILE (word # NIL) DO out.String(word.name); out.String(" "); word := word.next; END;
			END DumpWordList;

			PROCEDURE DumpTokens(out : Streams.Writer; level : LONGINT);
			VAR i, j : LONGINT;
			BEGIN
				ASSERT(out # NIL);
				FOR i := 0 TO LEN(tokens)-1 DO
					IF (tokens[i].maxLength > 0) THEN
						Indent(out, level); out.Char(CHR(i)); out.String(": ");
						FOR j := 0 TO LEN(tokens[i].length)-1 DO
							IF (tokens[i].length[j] # NIL) THEN
								out.Int(j + 1, 0); out.String(": ");
								DumpWordList(out, tokens[i].length[j]);
							END;
						END;
						out.Ln;
					END;
				END;
			END DumpTokens;

		BEGIN
			ASSERT(out # NIL);
			out.String("Highlighter: "); out.String(name); out.Ln;
			out.String("  Tokens:"); out.Ln;
			DumpTokens(out, 4);
		END Dump;

	END Highlighter;

	Highlighters = OBJECT
	VAR
		list : Highlighter;

		PROCEDURE &Init;
		BEGIN
			list := NIL;
		END Init;

		PROCEDURE Add(highlighter : Highlighter);
		BEGIN {EXCLUSIVE}
			ASSERT(highlighter # NIL);
			highlighter.next := list;
			list := highlighter;
		END Add;

		PROCEDURE Find(CONST name : ARRAY OF CHAR) : Highlighter;
		VAR highlighter : Highlighter;
		BEGIN {EXCLUSIVE}
			highlighter := list;
			WHILE (highlighter # NIL) & (highlighter.name # name) DO highlighter := highlighter.next; END;
			RETURN highlighter;
		END Find;

		PROCEDURE Dump(out : Streams.Writer);
		VAR h : Highlighter;
		BEGIN {EXCLUSIVE}
			ASSERT(out # NIL);
			h := list;
			WHILE (h # NIL) DO h.Dump(out); h := h.next; END;
		END Dump;

	END Highlighters;

VAR
	source : Files.FileName;
	diagnostics : Diagnostics.Diagnostics;
	error, autoinit : BOOLEAN;

	global_highlighters : Highlighters;

	traceLevel : LONGINT;

	(* Statistics (not thread-safe) *)
	NnofRebuildRegions, NnofPatchRegions,
	NnofPatchInsert, NnofPatchInsertHit, NnofPiOpenClose, NnofPiNestedFull, NnofPiNestedSimple,
	NnofPiRescan, NnofPiSimple, NnofPiNoHit, NnofPiNoHitRescan, NnofPiNoHitFull
	: LONGINT;

PROCEDURE GetHighlighter*(CONST name : ARRAY OF CHAR) : Highlighter;
VAR highlighter : Highlighter; diagnostics : Diagnostics.Diagnostics;
BEGIN {EXCLUSIVE}
	IF (global_highlighters = NIL) & autoinit THEN
		autoinit := FALSE; (* only try this once *)
		NEW(diagnostics);
		global_highlighters := Parse(DefaultHighlighterFile, diagnostics, error);
		KernelLog.String("SyntaxHighlighter: Auto-loading "); KernelLog.String(DefaultHighlighterFile);
		KernelLog.String(" ... ");
		IF ~error THEN
			KernelLog.String("done.");
		ELSE
			KernelLog.String("failed.");
			global_highlighters := NIL;
		END;
		KernelLog.Ln;
	END;
	IF (global_highlighters # NIL) THEN
		highlighter := global_highlighters.Find(name);
	ELSE
		highlighter := NIL;
	END;
	RETURN highlighter;
END GetHighlighter;

PROCEDURE GetTokenType(VAR token : Token);
VAR i : LONGINT; tokenDone : BOOLEAN;
BEGIN
	token.type := Type_Identifier;
	IF ('0' <= token.value[0]) & (token.value[0] <= '9') THEN
		token.type := Type_Number;
		i := 0; tokenDone := FALSE;
		WHILE (token.value[i] # 0X) & (i < LEN(token.value)) DO
			IF ~tokenDone & (token.type = Type_Number) THEN
				CASE token.value[i] OF
					|'0'..'9': (* do nothing here *)
					|'A'..'F':
						IF (token.subtype = Subtype_Decimal) THEN token.subtype := Subtype_Hex;
						ELSIF (token.subtype = Subtype_Float) & (token.value[i] # "E") THEN token.type := Type_Identifier;
						END;
					|'X':
						IF (token.subtype = Subtype_Decimal) OR (token.subtype = Subtype_Hex) THEN
							token.subtype := Subtype_Char; tokenDone := TRUE;
						ELSE
							token.type := Type_Identifier;
						END;
					|'h', 'H':
						IF (token.subtype = Subtype_Decimal) OR (token.subtype = Subtype_Hex) THEN
							token.subtype := Subtype_Hex; tokenDone := TRUE;
						ELSE
							token.type := Type_Identifier;
						END;
					|'.':
						IF (token.subtype = Subtype_Decimal) THEN token.subtype := Subtype_Float;
						ELSE token.type := Type_Invalid;
						END;
				ELSE
					token.type := Type_Identifier;
				END;
			ELSE
				token.type := Type_Identifier;
			END;
			INC(i);
		END;
	END;
END GetTokenType;

(*? Actually, the XML framework should take care of unescaping characters *)
PROCEDURE Unescape(string : Strings.String);
VAR insertAt, i : LONGINT; ch : CHAR;
BEGIN
	ASSERT(string # NIL);
	i := 0; insertAt := 0;
	WHILE (i < LEN(string)) DO
		IF (string[i] = "&") THEN
			IF (i + 3 < LEN(string)) & (string[i+2] = "t") & (string[i+3] = ";") THEN
				IF (string[i+1] = "l") THEN
					ch := "<"; i := i + 4;
				ELSIF (string[i+1] = "g") THEN
					ch := ">"; i := i + 4;
				ELSE
					ch := string[i]; INC(i);
				END;
			ELSIF (i + 4 < LEN(string)) & (string[i+1] = "a") & (string[i+2] = "m") & (string[i+3] = "p") & (string[i+4] = ";") THEN
				ch := "&"; i := i + 5;
			ELSIF (i + 5 < LEN(string)) & (string[i+1] = "q") & (string[i+2] = "u") & (string[i+3] = "o") & (string[i+4] = "t") & (string[i+5] = ";") THEN
				ch := '"'; i := i + 6;
			ELSIF (i + 5 < LEN(string)) & (string[i+1] = "a") & (string[i+2] = "p") & (string[i+3] = "o") & (string[i+4] = "s") & (string[i+5] = ";") THEN
				ch := "'"; i := i + 6;
			ELSE
				ch := string[i]; INC(i);
			END;
		ELSE
			ch := string[i]; INC(i);
		END;
		string[insertAt] := ch; INC(insertAt);
	END;
	IF (insertAt < LEN(string)) THEN string[insertAt] := 0X; END;
END Unescape;

PROCEDURE NofWildcards(CONST string : ARRAY OF CHAR) : LONGINT;
VAR nofWildcards, i : LONGINT;
BEGIN
	nofWildcards := 0;
	i := 0;
	WHILE (i < LEN(string)) & (string[i] # 0X) DO
		IF (string[i] = "?") OR (string[i] = "*") THEN INC(nofWildcards); END;
		INC(i);
	END;
	RETURN nofWildcards;
END NofWildcards;

PROCEDURE Equal(CONST s1, s2 : ARRAY OF CHAR; length : LONGINT) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	i := 0;
	WHILE (i < length) & (s1[i] = s2[i]) DO INC(i); END;
	RETURN i = length;
END Equal;

PROCEDURE Indent(out : Streams.Writer; level : LONGINT);
VAR i : LONGINT;
BEGIN
	ASSERT(out # NIL);
	FOR i := 1 TO level DO out.Char(" "); END;
END Indent;

(**
	Example:

	open:	 <!-- 	entry.region.openLength = 4
	close:	 -->	entry.region.closeLength = 3

	String:  <	!	-	-	B	L	A	H	-	-	>
			0	1	2	3	4	5	6	7	8	9	10

	OpenString: 	[0, 3]
	Content: 		[4, 7]
	CloseString:		[8, 10]
*)
PROCEDURE GetLocation(position : LONGINT; CONST entry : DataEntry) : LONGINT;
VAR location, closeLength : LONGINT;
BEGIN
	IF entry.eol THEN closeLength := 0; ELSE closeLength := entry.region.closeLength; END;
	IF (position >= entry.open) THEN
		IF (position <= entry.open + entry.region.openLength - 1) THEN
			location := OpenString;
		ELSIF (position <= entry.close - closeLength) THEN
			location := Content;
		ELSIF (position <= entry.close) THEN
			location := CloseString;
		ELSE
			location := Outside;
		END;
	ELSE
		location := Outside;
	END;
	RETURN location;
END GetLocation;

PROCEDURE ParseStyle(
	CONST element : XML.Element; CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	style : Style; string : Strings.String;
	styleName : Identifier;
	fontname : ARRAY 128 OF CHAR;
	fontsize, color, bgcolor, voff : LONGINT;
	fontstyle : SET;
	defined : SET;
	res : LONGINT;
BEGIN
	ASSERT((element # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlStyle));
	string := element.GetAttributeValue(XmlAttributeName);
	IF (string # NIL) THEN
		COPY(string^, styleName);
		defined := {};

		fontname := "";
		string := element.GetAttributeValue(XmlAttributeFontName);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				INCL(defined, FontName);
				Copy(string^, fontname);
			END;
		ELSE
			diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Style font name missing");
		END;

		fontsize := 0;
		string := element.GetAttributeValue(XmlAttributeFontSize);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				INCL(defined, FontSize);
				Strings.StrToInt(string^, fontsize);
			END;
		ELSE
			diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Style attribute font size missing");
		END;

		string := element.GetAttributeValue(XmlAttributeFontStyle);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				INCL(defined, FontStyle);
				Strings.StrToSet(string^, fontstyle);
			END;
		END;

		color := 0;
		string := element.GetAttributeValue(XmlAttributeColor);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				Strings.HexStrToInt(string^, color, res);
				IF (res = Strings.Ok) THEN
					INCL(defined, Color);
				ELSE
					diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Style attribute color: Invalid value");
				END;
			END;
		ELSE diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Style attribute color missing");
		END;

		bgcolor := 0;
		string := element.GetAttributeValue(XmlAttributeBgColor);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				Strings.HexStrToInt(string^, bgcolor, res);
				IF (res = Strings.Ok) THEN
					INCL(defined, BgColor);
				ELSE
					diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Style attribute background color: Invalid value");
				END;
			END;
		ELSE
			INCL(defined, BgColor);
			bgcolor := DefaultBgColor;
		END;

		voff := 0;
		string := element.GetAttributeValue(XmlAttributeVoff);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # XmlDontCare) THEN
				INCL(defined, Voff);
				Strings.StrToInt(string^, voff);
			END;
		ELSE
			INCL(defined, Voff);
			voff := DefaultVoff;
		END;

		NEW(style, styleName, color, bgcolor, voff, fontname, fontsize, fontstyle);
		style.defined := defined;
		styles.Add(style);
	ELSE
		error := TRUE;
		diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Style name missing");
	END;
END ParseStyle;

PROCEDURE ParseStyles(
	CONST element : XML.Element; CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; enum : XMLObjects.Enumerator; ptr : ANY;
BEGIN
	ASSERT((element # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlStyles));
	enum := element.GetContents();
	WHILE enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr IS XML.Element) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = XmlStyle) THEN
				ParseStyle(ptr(XML.Element), styles, source, diagnostics, error);
			ELSE
				diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Expected style element");
			END;
		END;
	END;
END ParseStyles;

PROCEDURE ParseGroup(
	CONST element : XML.Element; CONST highlighter : Highlighter; CONST styles : Styles;
	CONST type : LONGINT;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; ptr : ANY;
	reader : Streams.StringReader;
	token : ARRAY 128 OF CHAR;
	style : Style; res : LONGINT;
BEGIN
	ASSERT((element # NIL) & (highlighter # NIL) & (styles # NIL) & (diagnostics # NIL));
	ASSERT((type = TypeWords) OR (type = TypeTokens));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlGroup));
	string := element.GetAttributeValue(XmlAttributeStyle);
	IF (string # NIL) THEN
		style := styles.Find(string^);
		IF (style # NIL) THEN
			ptr := element.GetFirst();
			IF (ptr # NIL) & (ptr IS XML.Chars) THEN
				string := ptr(XML.Chars).GetStr();
				IF (string # NIL) THEN
					Unescape(string);
					NEW(reader, LEN(string^));
					reader.Set(string^);
					reader.SkipWhitespace;
					reader.Token(token);
					WHILE (token # "") & (reader.res = Streams.Ok) DO
						IF (type = TypeWords) THEN
							highlighter.AddWord(token, style, res);
						ELSE
							highlighter.AddToken(token, style, res);
						END;
						IF (res # Ok) THEN
							error := TRUE;
							diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Token too long");
						END;
						reader.SkipWhitespace;
						reader.Token(token);
					END;
				ELSE
					diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Empty group (string)");
				END;
			ELSE
				diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Empty group");
			END;
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Could not find style for group...");
		END;
	ELSE
		error := TRUE;
		diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Group name missing");
	END;
END ParseGroup;

PROCEDURE ParseTokens(
	CONST element : XML.Element; CONST highlighter : Highlighter;  CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; enum : XMLObjects.Enumerator; ptr : ANY;
BEGIN
	ASSERT((element # NIL) & (highlighter # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlTokens));
	enum := element.GetContents();
	WHILE enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr IS XML.Element) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = XmlGroup) THEN
				ParseGroup(ptr(XML.Element), highlighter, styles, TypeTokens, source, diagnostics, error);
			ELSE
				diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Expected group element");
			END;
		END;
	END;
END ParseTokens;

PROCEDURE ParseWords(
	CONST element : XML.Element; CONST highlighter : Highlighter;  CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; enum : XMLObjects.Enumerator; ptr : ANY;
	i : LONGINT;
BEGIN
	ASSERT((element # NIL) & (highlighter # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlWords));
	enum := element.GetContents();
	WHILE enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr IS XML.Element) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = XmlGroup) THEN
				ParseGroup(ptr(XML.Element), highlighter, styles, TypeWords, source, diagnostics, error);
			ELSE
				diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Expected group element");
			END;
		END;
	END;
	string := element.GetAttributeValue(XmlAttributeAllowCharacters);
	IF (string # NIL) THEN
		i := 0;
		WHILE (i < LEN(string)) & (string[i] # 0X) DO
			IF (string[i] > " ") THEN highlighter.AllowCharacter(string[i]); END;
			INC(i);
		END;
	END;
	string := element.GetAttributeValue(XmlAttributeNumberStyle);
	IF (string # NIL) THEN
		highlighter.numberStyle := styles.Find(string^);
		IF (highlighter.numberStyle = NIL) THEN
			diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Number style not found");
		END;
	END;
END ParseWords;

PROCEDURE ParseRegion(
	CONST element : XML.Element; CONST highlighter : Highlighter; CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String;
	style : Style;
	styleOpen, styleClose, styleContent : Style;
	open, close : Identifier;
	nesting, multiline : BOOLEAN;
BEGIN
	ASSERT((element # NIL) & (highlighter # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlRegion));

	styleOpen := NIL; styleClose := NIL; styleContent := NIL;

	string := element.GetAttributeValue(XmlAttributeStyleOpen);
	IF (string # NIL) THEN
		style := styles.Find(string^);
		IF (style # NIL) THEN
			styleOpen := style;
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "OpenStyle not found");
		END;
	END;

	string := element.GetAttributeValue(XmlAttributeStyleClose);
	IF (string # NIL) THEN
		style := styles.Find(string^);
		IF (style # NIL) THEN
			styleClose := style;
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "CloseStyle not found");
		END;
	END;

	string := element.GetAttributeValue(XmlAttributeStyleContent);
	IF (string # NIL) THEN
		style := styles.Find(string^);
		IF (style # NIL) THEN
			styleContent := style;
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "ContentStyle not found");
		END;
	END;

	string := element.GetAttributeValue(XmlAttributeOpen);
	IF (string # NIL) THEN
		Copy(string^, open);
		IF (open = "") THEN
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Region attribute open is empty");
		END;
	ELSE
		error := TRUE;
		diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Region attribute open missing");
	END;

	string := element.GetAttributeValue(XmlAttributeClose);
	IF (string # NIL) THEN
		Copy(string^, close);
	ELSE diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Region attribute close missing");
	END;

	nesting := FALSE;
	string := element.GetAttributeValue(XmlAttributeNesting);
	IF (string # NIL) THEN
		Strings.TrimWS(string^);
		Strings.StrToBool(string^, nesting);
	ELSE diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Region attribute nesting missing");
	END;

	multiline := FALSE;
	string := element.GetAttributeValue(XmlAttributeMultiLine);
	IF (string # NIL) THEN
		Strings.TrimWS(string^);
		Strings.StrToBool(string^, multiline);
	ELSE diagnostics.Warning(source, element.GetPos(), Diagnostics.Invalid, "Region attribute multiline missing");
	END;

	IF ~error THEN
		highlighter.AddRegion(open, close, nesting, multiline, styleOpen, styleClose, styleContent);
	END;
END ParseRegion;

PROCEDURE ParseRegions(
	CONST element : XML.Element; CONST highlighter : Highlighter; CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; enum : XMLObjects.Enumerator; ptr : ANY;
BEGIN
	ASSERT((element # NIL) & (highlighter # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlRegions));
	enum := element.GetContents();
	WHILE enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr IS XML.Element) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = XmlRegion) THEN
				ParseRegion(ptr(XML.Element), highlighter, styles, source, diagnostics, error);
			ELSE
				diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Expected region element");
			END;
		END;
	END;
END ParseRegions;

PROCEDURE ParseHighlighter(
	CONST element : XML.Element; CONST highlighters : Highlighters;  CONST styles : Styles;
	CONST source : ARRAY OF  CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	highlighter : Highlighter; string : Strings.String; tokens, words, regions : XML.Element;
BEGIN
	ASSERT((element # NIL) & (highlighters # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlHighlighter));
	string := element.GetAttributeValue(XmlAttributeName);
	IF (string # NIL) THEN
		NEW(highlighter, string^);
		highlighters.Add(highlighter);

		string := element.GetAttributeValue(XmlAttributeDefaultStyle);
		IF (string # NIL) THEN
			Strings.TrimWS(string^);
			IF (string^ # "") & (string^ # XmlDontCare) THEN
				highlighter.defaultStyle := styles.Find(string^);
				IF (highlighter.defaultStyle = NIL) THEN
					error := TRUE;
					diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Default style not found");
				END;
			END;
		END;

		tokens := FindChild(element, XmlTokens);
		IF (tokens # NIL) THEN
			ParseTokens(tokens, highlighter, styles, source, diagnostics, error);
		END;

		words := FindChild(element, XmlWords);
		IF (words # NIL) THEN
			ParseWords(words, highlighter, styles, source, diagnostics, error);
		END;

		regions := FindChild(element, XmlRegions);
		IF (regions # NIL) THEN
			ParseRegions(regions, highlighter, styles, source, diagnostics, error);
		END;
	ELSE
		error := TRUE;
		diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Highlighter name missing");
	END;
END ParseHighlighter;

PROCEDURE ParseHighlighters(
	CONST element : XML.Element; CONST highlighters : Highlighters; CONST styles : Styles;
	CONST source : ARRAY OF CHAR; CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	string : Strings.String; enum : XMLObjects.Enumerator; ptr : ANY;
BEGIN
	ASSERT((element # NIL) & (highlighters # NIL) & (styles # NIL) & (diagnostics # NIL));
	string := element.GetName();
	ASSERT((string # NIL) & (string^ = XmlHighlighters));
	enum := element.GetContents();
	WHILE enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr IS XML.Element) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = XmlHighlighter) THEN
				ParseHighlighter(ptr(XML.Element), highlighters, styles, source, diagnostics, error);
			ELSE
				diagnostics.Warning(source, ptr(XML.Element).GetPos(), Diagnostics.Invalid, "Expected highlighter element");
			END;
		END;
	END;
END ParseHighlighters;

PROCEDURE ParseDocument(
	CONST document : XML.Document;
	CONST source : ARRAY OF CHAR;
	VAR highlighters : Highlighters;
	CONST diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
VAR
	root, element : XML.Element; string : Strings.String;
	styles : Styles;
BEGIN
	ASSERT((document # NIL) & (diagnostics # NIL));
	root := document.GetRoot();
	string := root.GetName();
	IF (string # NIL) & (string^ = XmlRootElementName) THEN

		NEW(styles);
		element := FindChild(root, XmlStyles);
		IF (element # NIL) THEN
			ParseStyles(element, styles, source, diagnostics, error);
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Styles section missing");
		END;

		NEW(highlighters);
		element := FindChild(root, XmlHighlighters);
		IF (element # NIL) THEN
			ParseHighlighters(element, highlighters, styles, source, diagnostics, error);
		ELSE
			error := TRUE;
			diagnostics.Error(source, element.GetPos(), Diagnostics.Invalid, "Highlighters section missing");
		END;
	ELSE
		error := TRUE;
		diagnostics.Error(source, root.GetPos(), Diagnostics.Invalid, "XML root element name mismatch");
	END;
END ParseDocument;

PROCEDURE Parse(CONST filename : ARRAY OF CHAR;  diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN) : Highlighters;
VAR document : XML.Document; highlighters : Highlighters;
BEGIN
	ASSERT(diagnostics # NIL);
	document := LoadDocument(filename, diagnostics, error);
	IF ~error THEN
		NEW(highlighters);
		ParseDocument(document, filename, highlighters, diagnostics, error);
		IF error THEN highlighters := NIL; END;
	ELSE
		highlighters := NIL;
	END;
	RETURN highlighters;
END Parse;

PROCEDURE FindChild(parent : XML.Element; CONST childName : ARRAY OF CHAR) : XML.Element;
VAR child : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; string : Strings.String;
BEGIN
	ASSERT(parent # NIL);
	child := NIL;
	enum := parent.GetContents();
	WHILE (child = NIL) & enum.HasMoreElements() DO
		ptr := enum.GetNext();
		IF (ptr # NIL) THEN
			string := ptr(XML.Element).GetName();
			IF (string # NIL) & (string^ = childName) THEN
				child := ptr(XML.Element);
			END;
		END;
	END;
	RETURN child;
END FindChild;

PROCEDURE TrapHandler(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	error := TRUE;
	diagnostics.Error(source, pos, Diagnostics.Invalid, msg);
END TrapHandler;

PROCEDURE LoadDocument(CONST filename : ARRAY OF CHAR; CONST d: Diagnostics.Diagnostics; VAR e : BOOLEAN) : XML.Document;
VAR file : Files.File; reader : Files.Reader; scanner : XMLScanner.Scanner; parser : XMLParser.Parser; document : XML.Document;
BEGIN
	ASSERT(d # NIL);
	Copy(filename, source);
	document := NIL;
	file := Files.Old(filename);
	IF (file # NIL) THEN
		NEW(reader, file, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		parser.reportError := TrapHandler;
		error := FALSE;
		diagnostics := d;
		document := parser.Parse();
		e := error;
		IF error THEN
			document := NIL;
		END;
	ELSE
		e := TRUE;
		d.Error(filename, Diagnostics.Invalid, Diagnostics.Invalid, "File not found");
	END;
	diagnostics := NIL; source := "";
	ASSERT(error OR (document # NIL));
	RETURN document;
END LoadDocument;

PROCEDURE Copy(CONST source : ARRAY OF CHAR; VAR target : ARRAY OF CHAR);
BEGIN
	Strings.ConcatX(source, "", target);
END Copy;

PROCEDURE HighlightText*(text : Texts.Text; highlighter : Highlighter);
VAR
	state : State; style : Style;
	reader : Texts.TextReader; char32 : Texts.Char32; attributes : Texts.Attributes;
	readerPosition, lastEnd, regionStart, regionEnd : LONGINT;
BEGIN
	ASSERT((text # NIL) & (highlighter # NIL));
	text.AcquireWrite;
	style := highlighter.GetDefaultStyle();
	IF (style # NIL) & (style.attributes # NIL) THEN
		attributes := style.attributes;
	ELSE
		attributes := TextUtilities.GetDefaultAttributes();
	END;
	text.SetAttributes(0, text.GetLength(), attributes);

	NEW(reader, text);
	state := highlighter.GetState();
	highlighter.RebuildRegions(reader, state);
	reader.SetPosition(0);

	lastEnd := -1;
	WHILE ~reader.eot DO
		style := NIL;
		readerPosition := reader.GetPosition();
		reader.ReadCh(char32);
		IF (lastEnd < readerPosition)  THEN
			style := highlighter.GetRegionStyle(readerPosition, state, regionStart, regionEnd);
			IF (style # NIL) THEN
				lastEnd := regionEnd;
			ELSE
				IF highlighter.IsAllowedCharacter(char32) THEN
					style := highlighter.GetWordStyle(reader, readerPosition, lastEnd);
				END;
			END;
		END;
		IF (style # NIL) THEN
			text.SetAttributes(readerPosition, lastEnd - readerPosition + 1, style.attributes);
			reader.SetPosition(lastEnd);
		END;
	END;
	text.ReleaseWrite;
END HighlightText;

PROCEDURE Highlight*(context : Commands.Context); (** filename highlighterName ~ *)
VAR
	file : Files.File; filename : Files.FileName; highlighterName : Identifier;
	highlighter : Highlighter;
	text : Texts.Text; format, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	context.arg.SkipWhitespace; context.arg.String(highlighterName);
	highlighter := GetHighlighter(highlighterName);
	IF (highlighter # NIL) THEN
		NEW(text);
		TextUtilities.LoadAuto(text, filename, format, res);
		IF (res = 0) THEN
			IF (format = 0) OR (format = 1) THEN (* Oberon rsp. Bluebottle text format *)
				HighlightText(text, highlighter);
				file := Files.Old(filename);
				IF (file # NIL) THEN
					file.GetName(filename);
					CASE format OF
						|0: TextUtilities.StoreOberonText(text, filename, res);
						|1: TextUtilities.StoreText(text, filename, res);
						|2: TextUtilities.ExportUTF8(text, filename, res);
					ELSE
						res := -99; (* file format not known *)
					END;
					IF (res = 0) THEN
						context.out.String("Highlighted file "); context.out.String(filename); context.out.Ln;
					ELSE
						context.error.String("Could not store file "); context.error.String(filename);
						context.error.String(" , res = "); context.error.Int(res, 0); context.error.Ln;
					END;
				ELSE
					context.error.String(filename); context.error.String(": Could not resolve full filename.");
					context.error.Ln;
				END;
			ELSE
				context.error.String(filename); context.error.String(": Unsupported text format.");
				context.error.Ln;
			END;
		ELSE
			context.error.String("Could not open file "); context.error.String(filename);
			context.error.String(", res = "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String("Highligher "); context.error.String(highlighterName);
		context.error.String(" not found."); context.error.Ln;
	END;
END Highlight;

PROCEDURE ClearStats*(context : Commands.Context);
BEGIN
	NnofRebuildRegions := 0; NnofPatchRegions := 0;
	NnofPatchInsert := 0; NnofPatchInsertHit := 0; NnofPiOpenClose := 0; NnofPiNestedFull := 0; NnofPiNestedSimple := 0;
	NnofPiRescan := 0; NnofPiSimple := 0; NnofPiNoHit := 0; NnofPiNoHitRescan := 0; NnofPiNoHitFull := 0;
	context.out.String("SyntaxHighlighter: Statistics cleared."); context.out.Ln;
END ClearStats;

PROCEDURE Dump*(context : Commands.Context);
BEGIN {EXCLUSIVE}
	IF (global_highlighters # NIL) THEN
		global_highlighters.Dump(context.out);
	ELSE
		context.out.String("No highlighters available."); context.out.Ln;
	END;
END Dump;

PROCEDURE Open*(context : Commands.Context); (** filename ~ *)
VAR filename : Files.FileName; diagnostics : Diagnostics.DiagnosticsList; newHighlighters : Highlighters;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.String(filename);
	NEW(diagnostics);
	newHighlighters := Parse(filename, diagnostics, error);
	IF ~error THEN
		global_highlighters := newHighlighters;
		context.out.String("SyntaxHighlighter: Loaded data from "); context.out.String(filename);
		context.out.Ln;
	END;
	diagnostics.ToStream(context.out, Diagnostics.All);
END Open;

BEGIN
	source := "";
	diagnostics := NIL;
	error := FALSE; autoinit := TRUE;
	global_highlighters := NIL;
	traceLevel := Trace_None;
END SyntaxHighlighter.

SyntaxHighlighter.Open SyntaxHighlighter.XML ~

SyntaxHighlighter.Dump ~

WMPerfMonPluginModVars.Install SyntaxHighlighter
	SyntaxHighlighter.NnofRebuildRegions SyntaxHighlighter.NnofPatchRegions
	SyntaxHighlighter.NnofPatchInsert SyntaxHighlighter.NnofPatchInsertHit SyntaxHighlighter.NnofPiOpenClose
	SyntaxHighlighter.NnofPiNestedFull SyntaxHighlighter.NnofPiNestedSimple,
	SyntaxHighlighter.NnofPiRescan SyntaxHighlighter.NnofPiSimple SyntaxHighlighter.NnofPiNoHit SyntaxHighlighter.NnofPiNoHitRescan
	SyntaxHighlighter.NnofPiNoHitFull
~