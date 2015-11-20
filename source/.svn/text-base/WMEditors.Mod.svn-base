MODULE WMEditors; (** AUTHOR "TF/staubesv"; PURPOSE "Editor components"; *)

IMPORT
	Inputs, Strings, XML, PositionDebugging, UTF8Strings, Texts, TextUtilities, UndoManager, HostClipboard, KernelLog,
	Types, Models,
	Raster, WMRectangles, WMGraphics, WMGraphicUtilities, WMEvents, WMProperties, WMDropTarget,
	WMWindowManager, WMComponents, WMStandardComponents, WMTextView, WMInputMethods, Reals;

CONST
	(* Editor types *)
	None* = 0; (** allow any characters *)
	Decimal* = 1;
	Hex* = 2;
	Ascii* = 3;
	Unicode* = 4; (** default *)

	InitialStringSize= 32;
	MaxStringSize = 2048; (* {MaxStringLength MOD InitialStringLength = 0} *)

	InterclickNone = 0;
	Interclick01 = 1;	(* mouse button 0 & 1 *)
	Interclick02 = 2; (* mouse button 0 & 2 *)
	InterclickCancelled = 99;

	DragMinDistance = 5;
	TextBorder = 4;

TYPE

	SetStringProcedure = PROCEDURE {DELEGATE} (CONST string : ARRAY OF CHAR; position : LONGINT; VAR res : LONGINT);

	DropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		position : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; position : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.position := position;
		END Init;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR sdi : DropString;
		BEGIN
			IF (type = WMDropTarget.TypeString) THEN
				NEW(sdi, originator, setString, position); RETURN sdi;
			ELSE
				RETURN NIL;
			END;
		END GetInterface;

	END DropTarget;

	DropString = OBJECT(WMDropTarget.DropString)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		position : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; position : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.position := position;
		END Init;

		PROCEDURE Set(CONST string : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN
			setString(string, position, res);
		END Set;

	END DropString;

(*
	Example:

	i			0	1	2	3	4	5	6	7
	string[i]		H	E	L	L	O	A	2	0X
	cursor					    |
	selection		*	*	*

	means

	cursorPosition = 4	(min: 0, max: 7)
	curLen = 7
	selection.start = 1, selection.end = 3
*)

	(**
		Simple single line editor that does not support:
			- formatted text / text layouting
			- macros
			- command execution
	*)
	TextField* = OBJECT(WMStandardComponents.Panel)
	VAR
		type- : WMProperties.Int32Property;
		typeI : LONGINT;

		readOnly- : WMProperties.BooleanProperty;
		readOnlyI : BOOLEAN;

		textBorder-: WMProperties.Int32Property;
		textColor- : WMProperties.ColorProperty;
		textColorI : LONGINT;

		alignH- : WMProperties.Int32Property;
		alignV- : WMProperties.Int32Property;

		onEscape-, onEnter-, onChanged- : WMEvents.EventSource;

		ime : WMInputMethods.IME;

		currentFlags : SET;

		string : Texts.PUCS32String; (* 0X-terminated unicode string *)
		cursorPosition : LONGINT;
		curLen : LONGINT; (* excl. 0X, {(string[curLen] = 0) OR (string = NIL)} *)
		selection : RECORD start, end : LONGINT; END; (* -1, -1 means invalid *)

		cursorIsVisible : BOOLEAN;
		selecting, doubleClicking : BOOLEAN;
		selectingCursorPos : LONGINT;
		interclick : LONGINT;

		(* drag'n'drop *)
		dragPossible : BOOLEAN;
		dragString : Strings.String; (* 0X-terminated UTF8 string *)
		dragCopy : BOOLEAN;

		changeDue: BOOLEAN; (* if there is a change due and update must be performed on the model *)

		renderOffsetX : LONGINT;
		lastX, lastY : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(GSTextField);
			SetGenerator("WMEditors.GenTextField");
			NEW(type, typeProto, NIL, NIL); properties.Add(type);
			NEW(readOnly, readOnlyProto, NIL, NIL); properties.Add(readOnly);
			NEW(textColor, textColorProto, NIL, NIL); properties.Add(textColor);
			NEW(textBorder, PrototypeTextBorder,NIL,NIL); properties.Add(textBorder);

			NEW(onEscape, SELF, GSonEscape, GSonEscapeInfo, SELF.StringToCompCommand); events.Add(onEscape);
			NEW(onEnter, SELF, GSonEnter, GSonEnterInfo, SELF.StringToCompCommand); events.Add(onEnter);
			NEW(onChanged, SELF, NIL, NIL, NIL); events.Add(onChanged);

			NEW(alignH, PrototypeAlignH, NIL, NIL); properties.Add(alignH);
			NEW(alignV, PrototypeAlignV, NIL, NIL); properties.Add(alignV);

			ime := WMInputMethods.activeIME;

			currentFlags := {};
			string := NIL;

			cursorPosition := 0;
			curLen := 0;
			selection.start := -1; selection.end := -1;
			cursorIsVisible := FALSE;
			selecting := FALSE; doubleClicking := FALSE;
			selectingCursorPos := -1;
			interclick := InterclickNone;
			dragPossible := FALSE;
			dragString := NIL;
			dragCopy := FALSE;
			renderOffsetX := textBorder.Get();
			lastX := -1; lastY := -1;
			SetPointerInfo(manager.pointerText);
			takesFocus.Set(TRUE);
			SetAttributeValue("Value","");
			changeDue := FALSE;
		END Init;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			Resized;
			RecacheProperties;
		END Initialize;

		PROCEDURE SetCurrentCursorVisibility(isVisible : BOOLEAN);
		BEGIN
			IF (cursorIsVisible # isVisible) THEN
				cursorIsVisible := isVisible;
				Invalidate;
			END;
		END SetCurrentCursorVisibility;

		PROCEDURE PropertyChanged(sender, property : ANY);
		VAR f: WMGraphics.Font;

			PROCEDURE TextHeight(): LONGINT;
			BEGIN
				RETURN MAX (bounds.GetHeight()-2*textBorder.Get(),4);
			END TextHeight;

		BEGIN
			IF (property = type) THEN
				typeI := type.Get();
			ELSIF (property = readOnly) THEN
				readOnlyI := readOnly.Get();
				Invalidate;
			ELSIF (property = textColor) THEN
				textColorI := textColor.Get();
				Invalidate;
			ELSIF (property = font) THEN Invalidate;
			ELSIF (property = alignH) OR (property = alignV) THEN Invalidate
			ELSIF (property = model) THEN Invalidate
			ELSIF (property = scaleFont)& (scaleFont.Get()>0) THEN
				ScaleFont(TextHeight(),scaleFont.Get());
			ELSE
				IF (property = bounds) & (scaleFont.Get()>0) THEN ScaleFont(TextHeight(),scaleFont.Get()); END;
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			typeI := type.Get();
			readOnlyI := readOnly.Get();
			textColorI := textColor.Get();
			Invalidate;
		END RecacheProperties;

		(** Resize the internal buffer so that it can hold a string of the length <min> (incl. 0X).
			The buffer will never be bigger then MaxStringSize *)
		PROCEDURE CheckSize(min : LONGINT);
		VAR size : LONGINT;

			PROCEDURE RoundUpSize(min : LONGINT) : LONGINT;
			VAR size : LONGINT;
			BEGIN
				size := InitialStringSize;
				WHILE (min > size) DO size := size * 2; END;
				IF (size > MaxStringSize) THEN size := MaxStringSize; END;
				RETURN size;
			END RoundUpSize;

			PROCEDURE GrowTo(size : LONGINT);
			VAR newString : Texts.PUCS32String; i : LONGINT;
			BEGIN
				ASSERT((size > LEN(string)) & (size <= MaxStringSize));
				NEW(newString, size);
				FOR i := 0 TO LEN(string)-1 DO newString[i] := string[i]; END;
				string := newString;
			END GrowTo;

		BEGIN (* locked *)
			IF (string = NIL) THEN
				size := RoundUpSize(min);
				NEW(string, size); string[0] := 0;
			ELSIF (LEN(string) < min) THEN
				size := RoundUpSize(min);
				IF (size > LEN(string)) THEN GrowTo(size); END;
			END;
		END CheckSize;

		(** Return current data as 0X-terminated UTF8 string. The string is truncated if necessary *)
		PROCEDURE GetAsString*(VAR x : ARRAY OF CHAR);
		BEGIN
			Acquire;
			IF (string = NIL) THEN
				x[0] := 0X;
			ELSE
				UTF8Strings.UnicodetoUTF8(string^, x);
				x[LEN(x)-1] := 0X;
			END;
			Release;
		END GetAsString;

		(** Set UTF8 string as text. The string is truncated if necessary. *)
		PROCEDURE SetAsString*(CONST x : ARRAY OF CHAR);
		VAR i, length : LONGINT;
		BEGIN
			ASSERT(UTF8Strings.Valid(x));
			IF IsAllowedString(x) THEN
				Acquire;
				IF (string # NIL) & (UTF8Strings.CompareToUnicode(x, string^) = UTF8Strings.CmpEqual) THEN Release; RETURN; END;
				ResetSelection;
				length := UTF8Strings.Length(x) + 1; (* 0X termination *)
				CheckSize(length);
				i := 0; UTF8Strings.UTF8toUnicode(x, string^, i);
				IF (length <= LEN(string)) THEN
					curLen := TextUtilities.UCS32StrLength(string^);
				ELSE (* truncate *)
					curLen := LEN(string) - 1;
					string[curLen] := 0;
				END;
				cursorPosition := curLen;
				Release;
				ASSERT(string[curLen] = 0);
				Invalidate;
				(*Changed;*)
			END;
		END SetAsString;

		PROCEDURE LinkChanged(sender, object : ANY);
		VAR string : Types.String256; res : LONGINT; real: Types.Longreal; m: Models.Model;
		BEGIN
			IF (sender = model) & WMProperties.GetModel(model,m) THEN
				m.GetGeneric(string, res);
				IF (res = Models.Ok) THEN
					SetAsString(string.value);
					SetAttributeValue("Value",string.value);
				END;
			END;
		END LinkChanged;

		PROCEDURE UpdateModel;
		VAR string : Types.String256; res : LONGINT; str: Strings.String; m: Models.Model;
		BEGIN
			GetAsString(string.value);
			IF WMProperties.GetModel(model,m) THEN
				m.SetGeneric(string, res);
			END;
			SetAttributeValue("Value",string.value);
		END UpdateModel;

		PROCEDURE Changed;
		BEGIN
			changeDue := FALSE;
			UpdateModel;
			IF (onChanged # NIL) THEN onChanged.Call(NIL); END;
		END Changed;

		(* Determine the cursor character position given coordinate x in the component coordinate system *)
		PROCEDURE GetCursorPosition(x: LONGINT) : LONGINT;
		VAR
			cursorPosition, code, i : LONGINT;
			found : BOOLEAN; lastDistance : REAL;
			font : WMGraphics.Font;
			g : WMGraphics.GlyphSpacings; gx : REAL;
		BEGIN
			font := GetFont();
			cursorPosition := 0;
			x := x + ABS(renderOffsetX);
			lastDistance := x;
			i := 0; found := FALSE; gx := textBorder.Get();
			WHILE ~found & (i < curLen) DO
				code := string[i];
				IF font.HasChar(code) THEN
					font.GetGlyphSpacings(code, g);
				ELSE
					WMGraphics.FBGetGlyphSpacings(code, g);
				END;
				gx := gx + g.bearing.l + g.width + g.bearing.r;
				IF (ABS(gx - x) < lastDistance) THEN
					lastDistance := ABS(gx - x);
					cursorPosition := i + 1;
				ELSE
					found := TRUE;
				END;
				INC(i);
			END;
			RETURN cursorPosition;
		END GetCursorPosition;

		(* Determine the cursor's x-coordinate of the current cursor position relative to the first characer *)
		PROCEDURE GetCursorCoordinateX() : LONGINT;
		VAR font : WMGraphics.Font; g : WMGraphics.GlyphSpacings; x : REAL; i, code : LONGINT;
		BEGIN
			font := GetFont();
			x := 0.0;
			i := 0;
			WHILE (i < cursorPosition) DO
				code := string[i];
				IF font.HasChar(code) THEN
					font.GetGlyphSpacings(code, g);
				ELSE
					WMGraphics.FBGetGlyphSpacings(code, g);
				END;
				x := x + g.bearing.l + g.width + g.bearing.r;
				INC(i);
			END;
			RETURN ENTIER(x + 0.5);
		END GetCursorCoordinateX;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		CONST CursorWidth = 2; BorderWidth = 1;
		VAR
			font : WMGraphics.Font; g : WMGraphics.GlyphSpacings;
			x, y : LONGINT; cursorX, selectionX0, selectionX1, tw, th: LONGINT; code, i, width, height : LONGINT;
			selectionIsValid : BOOLEAN;
			halign: LONGINT;
			TextBorder: LONGINT;

			PROCEDURE StringSize(VAR w,h: LONGINT);
			VAR code,i: LONGINT;
			BEGIN
				w := 0; h := 0;
				FOR i := 0 TO curLen-1 DO
					code := string[i];
					IF font.HasChar(code) THEN
						font.GetGlyphSpacings(code, g);
					ELSE
						WMGraphics.FBGetGlyphSpacings(code, g);
					END;
					w := w + g.bearing.l + g.width + g.bearing.r;
					h := MAX(h, g.height);
				END;
			END StringSize;

		BEGIN
			Draw^(canvas);
			IF ~visible.Get() OR ~show THEN RETURN END;
			IF ~readOnlyI THEN
				WMGraphicUtilities.DrawBevel(canvas, GetClientRect(), BorderWidth, TRUE, LONGINT(0808080FFH), WMGraphics.ModeCopy)
			END;
			font := GetFont();
			canvas.SetColor(textColorI);
			selectionIsValid := SelectionIsValid();
			cursorX := GetCursorCoordinateX();
			width := bounds.GetWidth();
			height := bounds.GetHeight();

			TextBorder := textBorder.Get();
			StringSize(tw,th);
			CASE alignH.Get() OF
			WMGraphics.AlignRight:
				renderOffsetX := width-TextBorder-tw;
			| WMGraphics.AlignCenter:
				renderOffsetX :=  width DIV 2 - tw DIV 2;
			ELSE (* left *)
				renderOffsetX := TextBorder;
			END;

			CASE alignV.Get() OF
			WMGraphics.AlignBottom:
				y := height -1 - font.GetDescent() - TextBorder;
			| WMGraphics.AlignCenter:
				y := (height - (font.GetAscent() + font.GetDescent()) ) DIV 2 + font.GetAscent();
			ELSE (* top *)
				y := TextBorder + font.GetAscent();
			END;

			(* adaption to be able to edit out of visible area *)
			IF hasFocus & ~readOnlyI THEN
				IF (renderOffsetX + cursorX < TextBorder) THEN
					renderOffsetX :=  -cursorX + TextBorder;
				ELSIF (cursorX + CursorWidth + renderOffsetX > width - TextBorder) THEN
					renderOffsetX := width - cursorX - CursorWidth - TextBorder;
				END;
				cursorX := TextBorder;
			END;

			IF (renderOffsetX < TextBorder) THEN selectionX0 := 0; ELSE selectionX0 := TextBorder; END;
			x := renderOffsetX;
			FOR i := 0 TO curLen - 1 DO
				code := string[i];
				IF font.HasChar(code) THEN
					font.GetGlyphSpacings(code, g);
					font.RenderChar(canvas, x, y, code)
				ELSE
					WMGraphics.FBGetGlyphSpacings(code, g);
					WMGraphics.FBRenderChar(canvas, x, y, code)
				END;
				x := x + g.bearing.l + g.width + g.bearing.r;
				IF (cursorPosition = i + 1) THEN cursorX := ENTIER(x*1.0); END;
				IF (selectionIsValid) THEN
					IF (selection.start = i + 1) THEN selectionX0 := ENTIER(x*1.0); END;
					IF (selection.end = i) THEN selectionX1 := ENTIER(x*1.0 + 0.5); END;
				END;
			END;
			(* draw selection *)
			IF selectionIsValid THEN
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  y - font.GetAscent() , selectionX1, y + font.GetDescent() ), 0FF66H, WMGraphics.ModeSrcOverDst);
				(* for fontsize debugging purposes:
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  y , selectionX1, y+1), LONGINT(0FFFF00AAH), WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  y+th , selectionX1, y+th+1), LONGINT(0FFFF00AAH), WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  y+font.GetDescent() , selectionX1, y+font.GetDescent()+1), LONGINT(0FFFF00AAH), WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  y-font.GetAscent() , selectionX1, y-font.GetAscent()+1), LONGINT(0FFFF00AAH), WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  height-1-TextBorder , selectionX1, height-TextBorder), LONGINT(0FF0000AAH), WMGraphics.ModeSrcOverDst);
				canvas.Fill(WMRectangles.MakeRect(selectionX0,  TextBorder , selectionX1, TextBorder+1), LONGINT(0FF0000AAH), WMGraphics.ModeSrcOverDst);
				*)
			END;
			IF cursorIsVisible & ~readOnlyI THEN
				canvas.Fill(WMRectangles.MakeRect(cursorX, y - th , cursorX + CursorWidth, y + font.GetDescent() ), LONGINT(0FF0000CCH), WMGraphics.ModeSrcOverDst);
			END;
			IF changeDue THEN
				canvas.Fill(WMRectangles.MakeRect(renderOffsetX,  y - font.GetAscent() , x, y + font.GetDescent() ), LONGINT(0FF000066H), WMGraphics.ModeSrcOverDst);
			END;
		END Draw;

		PROCEDURE SelectionIsValid() : BOOLEAN;
		BEGIN
			RETURN (selection.start # -1) & (selection.end # -1) & (selection.end >= selection.start);
		END SelectionIsValid;

		PROCEDURE IsAllowedCharacter(ch : Texts.Char32) : BOOLEAN;
		BEGIN
			IF (typeI = None) THEN
				RETURN TRUE;
			ELSIF (typeI = Decimal) THEN
				RETURN (ORD("0") <= ch) & (ch <= ORD("9")) OR (ch = ORD("-"));
			ELSIF (typeI = Hex) THEN
				RETURN ((ORD("0") <= ch) & (ch <= ORD("9"))) OR ((ORD("a") <= ch) & (ch <=ORD( "f"))) OR ((ORD("A") <= ch) & (ch <= ORD("F")));
			ELSIF (typeI = Ascii) THEN
				RETURN (32 <= ch) & (ch < 128)
			ELSIF (typeI = Unicode) THEN
				RETURN (32 <= ch);
			ELSE
				RETURN FALSE;
			END;
		END IsAllowedCharacter;

		PROCEDURE IsAllowedString(CONST string : ARRAY OF CHAR) : BOOLEAN;
		VAR i : LONGINT; valid : BOOLEAN; ucs : Texts.Char32;
		BEGIN
			i := 0; valid := TRUE;
			REPEAT
				valid := UTF8Strings.DecodeChar(string, i, ucs);
				valid := valid & ((ucs = 0) OR IsAllowedCharacter(ucs));
			UNTIL ~valid OR (ucs = 0);
			RETURN valid;
		END IsAllowedString;

		PROCEDURE IsValidUCS32String(CONST string : Texts.UCS32String) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			i := 0;
			WHILE (i < LEN(string)) & (string[i] # 0) & (IsAllowedCharacter(string[i])) DO INC(i); END;
			RETURN (i < LEN(string)) & (string[i] = 0);
		END IsValidUCS32String;

		PROCEDURE InsertChar(ch : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF IsAllowedCharacter(ch) THEN
				DeleteSelection;
				CheckSize(curLen + 1 + 1); (* plus 0X plus <ch> *)
				IF (curLen + 1 < LEN(string)) THEN
					FOR i := curLen TO cursorPosition BY -1 DO
						string[i + 1] := string[i];
					END;
					string[cursorPosition] := ch;
					INC(curLen);
					INC(cursorPosition);
					WMTextView.cursorBlinker.Show(SELF);
					Invalidate;
				END;
				ASSERT(string[curLen] = 0);
				changeDue := TRUE;
				(*Changed;*)
			END;
		END InsertChar;

		(** Notes: Does not call DeleteSelection, x should already be checked for validity *)
		PROCEDURE InsertStringAt(CONST x : ARRAY OF CHAR; position : LONGINT; VAR res : LONGINT);
		VAR length, i, j, idx : LONGINT; changed, valid : BOOLEAN;
		BEGIN
			ASSERT(UTF8Strings.Valid(x));
			ASSERT(position >= 0);
			res := WMDropTarget.Failed;
			IF IsAllowedString(x) THEN
				length := UTF8Strings.Length(x);
				IF (length > 0) THEN
					Acquire;
					CheckSize(curLen + length + 1);
					IF (curLen + length + 1 <= LEN(string)) THEN
						i := curLen - 1;
						WHILE (i >= position) DO
							string[i + length] := string[i];
							DEC(i);
						END;
						j := 0; idx := 0;
						FOR i := position TO position + length - 1 DO
							valid := UTF8Strings.DecodeChar(x, idx, string[i]);
							INC(j);
						END;
						curLen := curLen + length;
						string[curLen] := 0;
						cursorPosition := position + length;
						changed := TRUE;
					ELSE
						changed := FALSE;
					END;
					Release;
					IF changed THEN
						Invalidate;
						changeDue := TRUE;
					END;
				END;
			END;
		END InsertStringAt;

		PROCEDURE InsertUCS32(atPosition : LONGINT; CONST string : Texts.UCS32String);
		VAR length, i, j : LONGINT; changed : BOOLEAN;
		BEGIN
			ASSERT(atPosition >= 0);
			IF IsValidUCS32String(string) THEN
				length := TextUtilities.UCS32StrLength(string);
				IF (length > 0) THEN
					DeleteSelection;
					Acquire;
					CheckSize(curLen + length + 1);
					IF (curLen + length < LEN(SELF.string)) THEN
						i := curLen - 1;
						WHILE (i >= atPosition) DO
							SELF.string[i + length] := SELF.string[i];
							DEC(i);
						END;
						j := 0;
						FOR i := atPosition TO atPosition + length - 1 DO
							SELF.string[i] := string[j];
							INC(j);
						END;
						curLen := curLen + length;
						SELF.string[curLen] := 0;
						cursorPosition := atPosition + length;
						changed := TRUE;
					ELSE
						changed := FALSE;
					END;
					Release;
					IF changed THEN
						Invalidate;
						changeDue := TRUE;
						(*
						Changed;
						*)
					END;
				END;
			END;
		END InsertUCS32;

		PROCEDURE Backspace;
		VAR i : LONGINT;
		BEGIN
			IF SelectionIsValid() THEN
				DeleteSelection; changeDue := TRUE; (*Changed;*)
			ELSIF (curLen > 0) & (cursorPosition > 0) THEN
				FOR i := cursorPosition-1 TO curLen-1 DO string[i] := string[i+1]; END;
				DEC(curLen);
				DEC(cursorPosition);
				string[curLen] := 0;
				Invalidate;
				changeDue := TRUE;
				(*
				Changed;
				*)
			END;
		END Backspace;

		(* Delete the character on the left hand side of the cursor and invalidate the editor if necessary *)
		PROCEDURE Delete;
		VAR i : LONGINT;
		BEGIN
			IF SelectionIsValid() THEN
				DeleteSelection; (*Changed;*) changeDue := TRUE;
			ELSIF (curLen > 0) & (cursorPosition < curLen) THEN
				FOR i := cursorPosition TO curLen-1 DO string[i] := string[i+1]; END;
				DEC(curLen);
				string[curLen] := 0;
				Invalidate;
				changeDue := TRUE;
				(*Changed;*)
			END;
		END Delete;

		(* Move the cursor to position 0. If a shift key is held, adapt selection, if not, clear selection.
			Invalidate editor if necessary *)
		PROCEDURE Home;
		BEGIN
			IF (Inputs.Shift * currentFlags # {}) THEN
				IF (cursorPosition > 0) THEN
					selection.start := 0;
					IF (selection.end = -1) THEN selection.end := cursorPosition - 1; END;
				END;
			ELSE
				ResetSelection;
			END;
			cursorPosition := 0;
			Invalidate;
		END Home;

		PROCEDURE End;
		BEGIN
			IF (Inputs.Shift * currentFlags # {}) THEN
				IF (cursorPosition < curLen) THEN
					selection.end := curLen - 1;
					IF (selection.start = -1) THEN selection.start := cursorPosition; END;
				END;
			ELSE
				ResetSelection;
			END;
			cursorPosition := curLen;
			Invalidate;
		END End;

		(* Move the cursor on position to left. If a shift key is held down, adapt selection if any, it no shift key is held,
			clear the current selection.  Invalidates the editor if necessary *)
		PROCEDURE CursorLeft;
		BEGIN
			IF (cursorPosition > 0) THEN
				IF (Inputs.Shift * currentFlags # {}) THEN
					IF SelectionIsValid() THEN
						IF (cursorPosition = selection.start + 1) THEN (* clear selection *)
							selection.start := -1; selection.end := -1;
						ELSIF (cursorPosition <= selection.start) THEN (* extend selection to left *)
							selection.start := cursorPosition - 1;
						ELSE (* reduce selection *)
							IF (cursorPosition > 1) THEN
								selection.end := cursorPosition - 2;
							ELSE
								selection.start := -1; selection.end := -1;
							END;
						END;
					ELSE
						(* select the character left to the cursor *)
						selection.start := cursorPosition - 1;
						selection.end := cursorPosition - 1;
					END;
				ELSE
					selection.start := -1; selection.end := -1;
				END;
				DEC(cursorPosition);
				Invalidate;
			ELSIF (Inputs.Shift * currentFlags = {}) THEN
				ResetSelection;
			END;
		END CursorLeft;

		PROCEDURE CursorRight;
		BEGIN
			IF (cursorPosition < curLen ) THEN
				IF (Inputs.Shift * currentFlags # {}) THEN
					IF SelectionIsValid() THEN
						IF (cursorPosition = selection.end) THEN (* clear selection *)
							selection.start := -1; selection.end := -1;
						ELSIF (cursorPosition > selection.end) THEN (* extend selection to right *)
							selection.end := cursorPosition;
						ELSE
							(* reduce selection *)
							IF (cursorPosition < curLen - 1) THEN
								selection.start := cursorPosition + 1;
							ELSE
								selection.start := -1; selection.end := -1;
							END;
						END;
					ELSE
						(* select the character right to the cursor *)
						selection.start := cursorPosition;
						selection.end := cursorPosition;
					END;
				ELSE
					selection.start := -1; selection.end := -1;
				END;
				INC(cursorPosition);
				Invalidate;
			ELSIF (Inputs.Shift * currentFlags = {}) THEN
				ResetSelection;
			END;
		END CursorRight;

		PROCEDURE DeleteSelection;
		VAR nofSelectedCharacters, i : LONGINT;
		BEGIN
			IF SelectionIsValid() THEN
				nofSelectedCharacters := selection.end - selection.start + 1;
				i := selection.start;
				WHILE (i + nofSelectedCharacters <= curLen) DO
					string[i] := string[i + nofSelectedCharacters];
					INC(i);
				END;
				cursorPosition := selection.start;
				curLen := curLen - nofSelectedCharacters;
				selection.start := -1; selection.end := -1;
				ASSERT(string[curLen] = 0);
				Invalidate;
			END;
		END DeleteSelection;

		PROCEDURE CopySelection;
		VAR i : LONGINT; ucs32 : Texts.PUCS32String;
		BEGIN
			IF SelectionIsValid() THEN
				Texts.clipboard.AcquireWrite;
				IF (Texts.clipboard.GetLength() > 0) THEN Texts.clipboard.Delete(0, Texts.clipboard.GetLength()) END;
				NEW(ucs32, selection.end - selection.start + 1 + 1);
				FOR i := selection.start TO selection.end DO
					ucs32[i - selection.start] := string[i];
				END;
				ucs32[LEN(ucs32)-1] := 0;
				Texts.clipboard.InsertUCS32(0, ucs32^);
				Texts.clipboard.ReleaseWrite;
			END;
		END CopySelection;

		PROCEDURE GetSelectionAsString(VAR string : Strings.String) : BOOLEAN;
		VAR i, idx : LONGINT; valid : BOOLEAN;
		BEGIN
			IF SelectionIsValid() THEN
				Acquire;
				NEW(string, 6*LEN(SELF.string));
				i := selection.start; idx := 0; valid := TRUE;
				WHILE valid & (i < LEN(string)-1) & (i <= selection.end) DO
					valid := UTF8Strings.EncodeChar(SELF.string[i], string^, idx);
					INC(i);
				END;
				string[i] := 0X;
				Release;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END GetSelectionAsString;

		PROCEDURE ResetSelection;
		BEGIN
			IF SelectionIsValid() THEN
				selection.start := -1; selection.end := -1;
				Invalidate;
			END;
		END ResetSelection;

		PROCEDURE SelectAll;
		BEGIN
			IF (curLen > 0) THEN
				selection.start := 0;
				selection.end := curLen - 1;
			END;
			Invalidate;
		END SelectAll;

		PROCEDURE Paste;
		VAR text : ARRAY MaxStringSize OF CHAR; valid : BOOLEAN; ignore : LONGINT;
		BEGIN
			Texts.clipboard.AcquireRead;
			IF (0 < Texts.clipboard.GetLength()) & (Texts.clipboard.GetLength() < MaxStringSize) THEN
				TextUtilities.TextToStr(Texts.clipboard, text);
				valid := IsAllowedString(text);
			ELSE
				valid := FALSE;
			END;
			Texts.clipboard.ReleaseRead;
			IF valid THEN
				DeleteSelection;
				InsertStringAt(text, cursorPosition, ignore);
			END;
		END Paste;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; VAR keySym : LONGINT);
		BEGIN
			currentFlags := flags;
			IF readOnlyI THEN RETURN END;
			IF Inputs.Release IN flags THEN RETURN END;
			IF ~enabled.Get() THEN RETURN; END;
			IF keySym = 01H THEN (* Ctrl-A *)
				SelectAll;
			ELSIF keySym = 03H THEN (* Ctrl-C *)
				CopySelection;
 			ELSIF (keySym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
 				(* tv.CopySelection *)
			ELSIF keySym = 0FF51H THEN (* Cursor Left *)
				CursorLeft;
			ELSIF keySym = 0FF53H THEN (* Cursor Right *)
				CursorRight;
			ELSIF keySym = 0FF54H THEN (* Cursor Down *)
			ELSIF keySym = 0FF52H THEN (* Cursor Up *)
			ELSIF keySym = 0FF56H THEN (* Page Down *)
			ELSIF keySym = 0FF55H THEN (* Page Up *)
			ELSIF keySym = 0FF50H THEN (* Cursor Home *)
				Home;
			ELSIF keySym = 0FF57H THEN (* Cursor End *)
				End;
			ELSIF keySym =  016H THEN (* Ctrl-V *)
				Paste;
			ELSIF keySym = 17H THEN (* Ctrl-W *)
			ELSIF keySym = 018H THEN (* Ctrl-X *)
				CopySelection;
				DeleteSelection;
			ELSIF keySym = 0FFFFH THEN (* Delete *)
				Delete;
 			ELSIF keySym = 0FF08H THEN (* Backspace *)
				Backspace;
			ELSIF (keySym = 0FF63H) & (flags * Inputs.Shift # {}) THEN  (* Shift Insert *)
				Paste;
			ELSIF (keySym = 0FF0DH)  THEN (* Enter *)
				onEnter.Call(NIL); Changed;
			ELSIF (keySym = 0FF1BH) THEN (* Escape *)
				onEscape.Call(NIL);
			ELSIF (keySym = 00020H) & (flags * Inputs.Ctrl # {}) (* Ctrl-Space *)  THEN
				(* switch IME on/off and get the newly active IME *)
				ime := WMInputMethods.SwitchIME();
				IF ime # NIL THEN
					SetIMEInterface(ime);
				END
			ELSE
				ime := WMInputMethods.activeIME;
				IF (ime # NIL) & (ucs > 26) THEN
					DeleteSelection;
					SetIMEInterface(ime);
					ime.KeyEvent(ucs, flags, keySym)
				ELSIF (0 <= ucs) & (ucs <= 255) THEN
					InsertChar(ucs);
				END;
			END;
			WMTextView.cursorBlinker.Show(SELF);
		END KeyEvent;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR newCursorPosition, oldInterclick : LONGINT;
		BEGIN
			PointerDown^(x, y, keys);

			oldInterclick := interclick;
			IF (keys * {0, 1} = {0,1}) THEN interclick := Interclick01;
			ELSIF (keys * {0,2} = {0,2}) THEN interclick := Interclick02;
			ELSE interclick := InterclickNone;
			END;
			(* Determine whether to cancel an interclick if any *)
			IF (oldInterclick = InterclickCancelled) OR
				((oldInterclick # InterclickNone) & (interclick # InterclickNone)) THEN
				interclick := InterclickCancelled;
			END;

			newCursorPosition := cursorPosition;
			IF (keys * {0, 1, 2} = {0}) & (interclick = InterclickNone) THEN
				dragPossible := FALSE;
				newCursorPosition := GetCursorPosition(x);
				IF SelectionIsValid() & (selection.start <= newCursorPosition) & (newCursorPosition <= selection.end + 1) THEN
					(* clicked into selected text *)
					dragPossible := TRUE;
					lastX := x; lastY := y;
				ELSE
					IF (lastX # -1) & (lastY # -1) & (ABS(lastX - x) < 2) & (ABS(lastY - y) < 2) THEN (* double click *)
						SelectAll;
						lastX := -1; lastY := -1;
					ELSE
						selecting := TRUE;
						selectingCursorPos := newCursorPosition;
					END;
					lastX := x; lastY := y;
				END;
			ELSE
				ResetSelection;
				selecting := FALSE;
				lastX := -1; lastY := -1;
			END;

			IF (cursorPosition # newCursorPosition) THEN
				cursorPosition := newCursorPosition;
				Invalidate;
			END;
		END PointerDown;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		BEGIN
			PointerUp^(x, y, keys);
			selecting := FALSE;
			selectingCursorPos := -1;
			doubleClicking := FALSE;
			IF (keys * {0,1,2} = {}) THEN
				IF (interclick = Interclick02) THEN
					DeleteSelection;
				END;
				interclick := InterclickNone;
			END;
			IF dragPossible THEN ResetSelection; dragPossible := FALSE; END;
		END PointerUp;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR posX : LONGINT; valid : BOOLEAN; start, end : LONGINT;
		BEGIN
			IF dragPossible THEN
				IF (ABS(x - lastX) > DragMinDistance) OR (ABS(y - lastY) > DragMinDistance) THEN dragPossible := FALSE; AutoStartDrag; END;
			ELSIF selecting THEN
				posX := GetCursorPosition(x);
				IF (0 <= posX) & (posX <= curLen) & (selectingCursorPos # -1) THEN
					valid := TRUE;
					IF (posX > selectingCursorPos) & (posX > 1)THEN
						start := selectingCursorPos; end := posX - 1;
					ELSIF (posX < selectingCursorPos) & (selectingCursorPos > 0) THEN
						start := posX; end := selectingCursorPos - 1;
					ELSE
						valid := FALSE;
					END;
					IF valid & ((start # selection.start) OR (end # selection.end)) THEN
						selection.start := start; selection.end := end;
					END;
					Invalidate;
				END;
			END;
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
			IF changeDue THEN Changed END;
			lastX := -1; lastY := -1;
		END PointerLeave;

		(* Drag away operations *)
		PROCEDURE AutoStartDrag;
		VAR
			image : WMGraphics.Image; canvas : WMGraphics.BufferCanvas;
			font : WMGraphics.Font;
			w, h : LONGINT;
		BEGIN
			IF GetSelectionAsString(dragString) THEN
				w := 0; h := 0;
				font := GetFont();
				font.GetStringSize(dragString^, w, h);
				IF (w > 0) & (h > 0) THEN
					(* render to bitmap *)
					NEW(image); Raster.Create(image, w, h, Raster.BGRA8888);
					NEW(canvas, image);
					canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), 0FF60H, WMGraphics.ModeSrcOverDst);
					canvas.SetColor(textColorI);
					WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(0, 0, w, h), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, dragString^)
				ELSE
					image := NIL;
				END;
				IF ~StartDrag(NIL, image, 0,0,DragWasAccepted, NIL) THEN KernelLog.String("ERROR"); (* ignore *) END;
			END;
		END AutoStartDrag;

		PROCEDURE DragWasAccepted(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
			ds : DropString;
			itf : WMDropTarget.DropInterface;
			targetText, temp : Texts.Text;
			pos, value, res : LONGINT;
		BEGIN
			IF (dragString = NIL) THEN RETURN; END;

			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget);
				ELSE RETURN;
				END;
			ELSE RETURN;
			END;

			IF (typeI = Decimal) OR (typeI = Hex) THEN
				itf := dt.GetInterface(WMDropTarget.TypeInt32);
				IF (itf # NIL) THEN
					Strings.StrToInt(dragString^, value);
					itf(WMDropTarget.DropInt32).Set(value);
					dragString := NIL;
					RETURN;
				END;
			END;

			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				targetText := itf(WMDropTarget.DropText).text;
				IF (targetText # NIL) THEN
					targetText.AcquireWrite;
					pos := itf(WMDropTarget.DropText).pos.GetPosition();
					NEW(temp);
					temp.AcquireWrite;
					TextUtilities.StrToText(temp, 0, dragString^);
					targetText.CopyFromText(temp, 0, temp.GetLength(), pos);
					temp.ReleaseWrite;
					targetText.ReleaseWrite;
				END;
				dragString := NIL;
				RETURN;
			END;

			itf := dt.GetInterface(WMDropTarget.TypeString);
			IF (itf # NIL) THEN
				ds := itf(DropString);
				IF (ds.originator # SELF) OR ~SelectionIsValid() OR ((ds.position < selection.start) & (selection.end < ds.position)) THEN
					itf(WMDropTarget.DropString).Set(dragString^, res);
					dragString := NIL;
				END;
			END;
		END DragWasAccepted;

		PROCEDURE DragOver(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR pos : LONGINT; doInvalidate : BOOLEAN;
		BEGIN
			IF takesFocus.Get() THEN
				doInvalidate := FALSE;
				Acquire;
				pos := GetCursorPosition(x);
				IF (0 <= pos) & (pos <= curLen) THEN
					IF (cursorIsVisible = FALSE) THEN cursorIsVisible := TRUE; doInvalidate := TRUE; END;
					IF (cursorPosition # pos) THEN
						cursorPosition := pos;
						doInvalidate := TRUE;
					END;
				END;
				Release;
				IF doInvalidate THEN Invalidate; END;
			END;
		END DragOver;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dt : DropTarget; pos : LONGINT;
		BEGIN
			IF takesFocus.Get() THEN
				pos := GetCursorPosition(x);
				NEW(dt, SELF, SetDroppedString, pos);
				dragInfo.data := dt;
				IF ~hasFocus & cursorIsVisible THEN cursorIsVisible := FALSE; Invalidate; END;
				ConfirmDrag(TRUE, dragInfo);
			ELSE
				ConfirmDrag(FALSE, dragInfo);
			END;
		END DragDropped;

		PROCEDURE SetDroppedString( CONST string : ARRAY OF CHAR; position : LONGINT; VAR res : LONGINT);
		BEGIN
			Acquire;
			ResetSelection;
			InsertStringAt(string, position, res);
			Release;
		END SetDroppedString;

		(* this function is use by IMEs to set the next cursor position for live-editing bidirectional text *)
		PROCEDURE SetCursorInfo(charsAdded : LONGINT);
		BEGIN
			(* ignore *)
		END SetCursorInfo;

		PROCEDURE GetCurrentCursorPosition() : LONGINT;
		BEGIN
			RETURN cursorPosition;
		END GetCurrentCursorPosition;

		PROCEDURE GetCursorScreenPosition(VAR x, y : LONGINT);
		BEGIN
			Acquire;
			x := GetCursorCoordinateX() + renderOffsetX;
			y := 10;
			ToWMCoordinates(x, y, x, y);
			Release;
		END GetCursorScreenPosition;

		PROCEDURE SetIMEInterface(ime : WMInputMethods.IME);
		VAR i : WMInputMethods.IMEInterface;
		BEGIN
			ASSERT((ime # NIL));
			i.AcquireText := Acquire;
			i.ReleaseText := Release;
			i.InsertUCS32 := InsertUCS32;
			i.GetCursorPosition := GetCurrentCursorPosition;
			i.GetCursorScreenPosition := GetCursorScreenPosition;
			i.SetCursorInfo := SetCursorInfo;
			ime.SetInterface(i);
		END SetIMEInterface;

		PROCEDURE FocusReceived;
		BEGIN
			FocusReceived^;
			cursorIsVisible := TRUE;
			WMTextView.cursorBlinker.Set(SELF, SetCurrentCursorVisibility);
			Invalidate;
		END FocusReceived;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			currentFlags := {};
			WMTextView.cursorBlinker.Remove(SELF);
			cursorIsVisible := FALSE;
			selectingCursorPos := -1;
			Invalidate;
			IF changeDue THEN Changed END;
			IF ime # NIL THEN ime.Hide END;
		END FocusLost;

	END TextField;

	NumberField= OBJECT (TextField)
	VAR
		fractionalDigits-: WMProperties.Int32Property;
		unitModel-: WMProperties.ReferenceProperty;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(GSNumberField);
			SetGenerator("WMEditors.GenNumberField");
			NEW(fractionalDigits, PrototypeFractionalDigits, NIL, NIL); properties.Add(fractionalDigits);
			NEW(unitModel, PrototypeUnit, NIL, NIL); properties.Add(unitModel)
		END Init;

		PROCEDURE GetUnit(VAR u: LONGREAL): BOOLEAN;
		VAR res: LONGINT; real: Types.Longreal; m: Models.Model;
		BEGIN
			IF WMProperties.GetModel(unitModel, m) THEN
				m.GetGeneric(real, res);
				IF (res = Models.Ok) & (real.value # 0) THEN
					u := real.value; RETURN TRUE
				END;
			END;
			RETURN FALSE
		END GetUnit;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			IF unitModel.Get()# NIL THEN LinkChanged(unitModel, unitModel.Get()) END;
			IF model.Get()# NIL THEN LinkChanged(model, model.Get()) END;
		END RecacheProperties;

		PROCEDURE LinkChanged(sender, data : ANY);
		VAR string : Types.String256; res : LONGINT; real: Types.Longreal; unit: LONGREAL; m: Models.Model;
		BEGIN
			IF (sender = model) OR (sender = unitModel) THEN
				res := -1;
				IF WMProperties.GetModel(model,m) THEN
					m.GetGeneric(real, res);
					IF res = Models.Ok THEN
						IF Reals.IsNaNL(real.value) THEN
							SetAsString("--")
						ELSE
							IF GetUnit(unit) THEN real.value := unit * real.value END;
							Types.FloatToString(real.value, fractionalDigits.Get(), string.value);
							SetAsString(string.value);
						END
					ELSE
						m.GetGeneric(string,res);
						IF res = Models.Ok THEN
							SetAsString(string.value);
						END;
					END;
				END;
			END;
		END LinkChanged;

		PROCEDURE UpdateModel;
		VAR string : Types.String256; res : LONGINT; str: Strings.String; real: Types.Longreal; u: LONGREAL; m: Models.Model;
		BEGIN
			GetAsString(string.value);
			IF WMProperties.GetModel(model, m) & ~(m IS Models.String) THEN
				Strings.StrToFloat(string.value, real.value);
				IF GetUnit(u) THEN real.value := real.value / u END;
				m.SetGeneric(real, res);
			END;
		END UpdateModel;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR reference: XML.Element; unitModel: XML.Element;
		BEGIN
			IF property = fractionalDigits THEN
				LinkChanged(model, NIL); Invalidate;
			ELSIF property = unitModel THEN
				LinkChanged(model, NIL); Invalidate
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

	END NumberField;

TYPE

	MacroData* = OBJECT
	VAR
		text* : Texts.Text;
		cursor* : WMTextView.PositionMarker;
		keySym* : LONGINT;
		flags* : SET;
		handled* : BOOLEAN;
	END MacroData;

	Editor* = OBJECT(WMComponents.VisualComponent)
	VAR
		tv- : WMTextView.TextView;
		vScrollbar- : WMStandardComponents.Scrollbar;
		hScrollbar- : WMStandardComponents.Scrollbar;
		ime : WMInputMethods.IME;
		multiLine-, readOnly- : WMProperties.BooleanProperty;
		highlighting- : WMProperties.StringProperty;
		text- : Texts.Text;
		utilreader : Texts.TextReader;
		onEnter-, onEscape- : WMEvents.EventSource;
		macros- : WMEvents.EventSource; (* must be handled directly without queuing, text has writelock, may not trap *)
		macroData : MacroData;
		currentFlags : SET;
		allowIME* : BOOLEAN;
		allowScrollbars- : WMProperties.BooleanProperty;
		undoMgr*: UndoManager.UndoManager;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(GSEditor);
			SetGenerator("WMEditors.GenEditor");
			allowIME := TRUE;
			ime := WMInputMethods.activeIME;
			NEW(multiLine, multiLineProto, NIL, NIL); properties.Add(multiLine);
			NEW(readOnly, readOnlyProto, NIL, NIL); properties.Add(readOnly);
			NEW(highlighting, highlightingProto, NIL, NIL); properties.Add(highlighting);
			NEW(allowScrollbars, allowScrollbarsProto, NIL, NIL); properties.Add(allowScrollbars);
			(* events *)
			NEW(onEnter, SELF, GSonEnter, GSonEnterInfo, SELF.StringToCompCommand); events.Add(onEnter);
			NEW(onEscape, SELF, GSonEscape, GSonEscapeInfo, SELF.StringToCompCommand); events.Add(onEscape);
			NEW(macros, SELF, GSmacros, GSmacrosInfo, SELF.StringToCompCommand); events.Add(macros);

			NEW(vScrollbar);
			vScrollbar.alignment.Set(WMComponents.AlignRight); AddInternalComponent(vScrollbar);
			NEW(hScrollbar);
			hScrollbar.alignment.Set(WMComponents.AlignBottom);
			hScrollbar.vertical.Set(FALSE); AddInternalComponent(hScrollbar);
			takesFocus.Set(TRUE);
			needsTab.Set(TRUE);
			NEW(text);
			NEW(utilreader, text);
			NEW(macroData);
			NEW(tv);
			tv.alignment.Set(WMComponents.AlignClient); AddInternalComponent(tv);
			tv.SetScrollbars(hScrollbar, vScrollbar);
			tv.SetText(text);
			tv.SetExtKeyEventHandler(KeyPressed);
			tv.SetExtPointerDownHandler(MousePressed);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			tv.focusPrevious.Set(focusPrevious.Get());
			tv.focusNext.Set(focusNext.Get());
			tv.takesFocus.Set(takesFocus.Get());
			tv.needsTab.Set(needsTab.Get());
			tv.highlighting.Set(highlighting.Get());
			Resized;
		END Initialize;

		PROCEDURE SetUndoManager*(uMgr: UndoManager.UndoManager);
		BEGIN
			undoMgr := uMgr;
		END SetUndoManager;

		PROCEDURE Undo*;
		BEGIN
			IF undoMgr # NIL THEN
				undoMgr.Undo();
				tv.cursor.SetPosition(undoMgr.actualPos)
			END
		END Undo;

		PROCEDURE Redo*;
		BEGIN
			IF undoMgr # NIL THEN
				undoMgr.Redo();
				tv.cursor.SetPosition(undoMgr.actualPos)
			END
		END Redo;

		PROCEDURE SetFocus*;
		BEGIN
			(* block super call to avoid loop *)
			tv.SetFocus
		END SetFocus;

		PROCEDURE CheckScrollbars;
		BEGIN
			IF allowScrollbars.Get() & multiLine.Get() THEN
				vScrollbar.visible.Set(TRUE); hScrollbar.visible.Set(TRUE)
			ELSE
				vScrollbar.visible.Set(FALSE); hScrollbar.visible.Set(FALSE)
			END
		END CheckScrollbars;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			tv.isMultiLine.Set(multiLine.Get());
			tv.focusPrevious.Set(focusPrevious.Get());
			tv.focusNext.Set(focusNext.Get());
			tv.takesFocus.Set(takesFocus.Get());
			tv.needsTab.Set(needsTab.Get());
			tv.highlighting.Set(highlighting.Get());
			CheckScrollbars
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR reference: XML.Element;
		BEGIN
			IF (property = multiLine) THEN tv.isMultiLine.Set(multiLine.Get()); CheckScrollbars;
			ELSIF (property = focusPrevious) THEN tv.focusPrevious.Set(focusPrevious.Get());
			ELSIF (property = focusNext) THEN tv.focusNext.Set(focusNext.Get());
			ELSIF (property = takesFocus) THEN tv.takesFocus.Set(takesFocus.Get());
			ELSIF (property = needsTab) THEN tv.needsTab.Set(needsTab.Get());
			ELSIF (property = highlighting) THEN tv.highlighting.Set(highlighting.Get());
			ELSIF (property = model) THEN
				reference := model.Get();
				IF (reference # NIL) & (reference IS Models.Text) THEN
					SetText(reference(Models.Text).Get());
				END;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE LinkChanged(sender, data : ANY);
		VAR string : Types.String256; res : LONGINT; real: Types.Longreal; unit: LONGREAL; m: Models.Model;
		BEGIN
			LinkChanged^(sender, data);
		END LinkChanged;


		PROCEDURE SetText*(t : Texts.Text);
		VAR reference: XML.Element; textModel: Models.Text;
		BEGIN
			IF t = NIL THEN RETURN END;
			Acquire;
			text := t;
			NEW(utilreader, text);
			tv.SetText(t);
			Release;
			reference := model.Get();
			IF reference # NIL THEN
				IF reference(Models.Text).Get() # text THEN
					reference(Models.Text).SetReference(text);
				END;
			ELSE
				NEW(textModel); textModel.SetReference(text); model.Set(textModel);
			END;
		END SetText;

		(* this function is use by IMEs to set the next cursor position for live-editing bidirectional text *)
		PROCEDURE SetCursorInfo(charsAdded : LONGINT);
		BEGIN
			IF text.isUTF THEN
				(* compute the next internal position *)
				tv.cursor.SetNextInternalPosition(tv.GetInternalPos(tv.cursor.GetPosition()) + charsAdded);
			END;
		END SetCursorInfo;

		PROCEDURE GetCursorPosition() : LONGINT;
		BEGIN
			RETURN tv.GetInternalPos(tv.cursor.GetPosition());
		END GetCursorPosition;

		PROCEDURE GetCursorScreenPosition(VAR x, y : LONGINT);
		BEGIN
			tv.Acquire;
			text.AcquireRead;
			IF tv.FindScreenPos(tv.cursor.GetPosition(), x, y) THEN END;
			tv.ToWMCoordinates(x, y, x, y);
			text.ReleaseRead;
			tv.Release;
		END GetCursorScreenPosition;

		PROCEDURE SetIMEInterface(ime : WMInputMethods.IME; text : Texts.Text);
		VAR i : WMInputMethods.IMEInterface;
		BEGIN
			ASSERT((ime # NIL) & (text # NIL));
			i.AcquireText := text.AcquireWrite;
			i.ReleaseText := text.ReleaseWrite;
			i.InsertUCS32 := text.InsertUCS32;
			i.GetCursorPosition := GetCursorPosition;
			i.GetCursorScreenPosition := GetCursorScreenPosition;
			i.SetCursorInfo := SetCursorInfo;
			ime.SetInterface(i);
		END SetIMEInterface;

		PROCEDURE FocusReceived;
		BEGIN
			FocusReceived^;
			tv.SetFocus
		END FocusReceived;

		PROCEDURE FocusLost;
		BEGIN
			tv.FocusLost;
			IF ime # NIL THEN ime.Hide END;
			(* When this component loses the keyboard focus, it won't see Inputs.Release messages. Actually, we
			would need the current state of the flags... *)
			currentFlags := {};
		END FocusLost;

		PROCEDURE InsertChar*(ch : Texts.Char32);
		VAR
			buf : ARRAY 2 OF Texts.Char32;
			internalPos : LONGINT;
		BEGIN
			IF tv.selection.b - tv.selection.a # 0 THEN DeleteSelection END;
			buf[0] := ch; buf[1] := 0;

			internalPos := tv.GetInternalPos(tv.cursor.GetPosition());
			tv.cursor.SetNextInternalPosition(internalPos + 1);

			text.InsertUCS32(internalPos, buf); (* cursor moves automagically *)
			PositionDebugging.SetPos(tv.GetInternalPos(tv.cursor.GetPosition()),tv.cursor.GetPosition());
		END InsertChar;

		PROCEDURE InsertString*(CONST string : Texts.UCS32String);
		VAR internalPos : LONGINT;
		BEGIN
			IF tv.selection.b - tv.selection.a # 0 THEN DeleteSelection END;

			internalPos := tv.GetInternalPos(tv.cursor.GetPosition());
			tv.cursor.SetNextInternalPosition(internalPos + 1);

			text.InsertUCS32(internalPos, string); (* cursor moves automagically *)
			PositionDebugging.SetPos(tv.GetInternalPos(tv.cursor.GetPosition()),tv.cursor.GetPosition());
		END InsertString;

		PROCEDURE CopySelection*;
		BEGIN
			tv.CopySelection
		END CopySelection;

		PROCEDURE DeleteSelection*;
		BEGIN
			text.AcquireWrite;
			tv.selection.Sort;
			tv.cursor.SetNextInternalPosition(tv.selection.a);
			text.Delete(tv.selection.a, tv.selection.b - tv.selection.a);
			text.ReleaseWrite
		END DeleteSelection;

		PROCEDURE PasteToHostClipboard*;
		VAR clipboard: Texts.UnicodeText; res : LONGINT;
		BEGIN
			text.AcquireWrite;
			NEW(clipboard);
			clipboard.AcquireWrite;
			HostClipboard.Get(clipboard, res);
			IF (res = HostClipboard.Ok) & (clipboard.GetLength() > 0) THEN
				IF tv.selection.b - tv.selection.a # 0 THEN DeleteSelection() END;
				text.CopyFromText(clipboard, 0, clipboard.GetLength(), tv.cursor.GetPosition());
			END;
			clipboard.ReleaseWrite;
			text.ReleaseWrite
		END PasteToHostClipboard;

		PROCEDURE Paste*;
		VAR
			pos : LONGINT;
		BEGIN
			text.AcquireWrite;
			Texts.clipboard.AcquireRead;
			IF Texts.clipboard.GetLength() > 0 THEN
				IF tv.selection.b - tv.selection.a # 0 THEN DeleteSelection() END;
				pos := tv.GetInternalPos(tv.cursor.GetPosition());
				tv.cursor.SetNextInternalPosition(pos);
				text.CopyFromText(Texts.clipboard, 0, Texts.clipboard.GetLength(),pos)
			END;
			Texts.clipboard.ReleaseRead;
			text.ReleaseWrite
		END Paste;

		PROCEDURE Delete(flags : SET);
		VAR pos : LONGINT;
		BEGIN
			(* get the internal position of the cursor *)
			pos := tv.GetInternalPos(tv.cursor.GetPosition());

			(* shift delete *)
			IF flags * Inputs.Shift # {} THEN
				tv.selection.Sort;
				IF tv.selection.active & (pos >= tv.selection.a) & (pos <= tv.selection.b) THEN
					CopySelection
				END;
			END;
			IF flags * Inputs.Ctrl # {} THEN
				text.Delete(pos, TextUtilities.FindPosWordRight(utilreader, pos) - pos)
			ELSE
				tv.selection.Sort;
				IF tv.selection.active & (pos >= tv.selection.a) & (pos <= tv.selection.b) THEN
					DeleteSelection
				ELSE
					tv.cursor.SetNextInternalPosition(pos);
					text.Delete(pos, 1)
				END
			END
		END Delete;

		PROCEDURE Backspace(word : BOOLEAN);
		VAR pos, np : LONGINT;
		BEGIN
			(* get the internal position of the cursor *)
			pos := tv.GetInternalPos(tv.cursor.GetPosition());

			IF word THEN
				np := TextUtilities.FindPosWordLeft(utilreader, pos - 1);
				text.Delete(np, pos - np)
			ELSE
				tv.selection.Sort;
				IF tv.selection.active & (pos >= tv.selection.a) & (pos <= tv.selection.b) THEN
					DeleteSelection
				ELSE
					tv.cursor.SetNextInternalPosition(pos-1);
					text.Delete(pos - 1, 1)
				END
			END
		END Backspace;

		PROCEDURE Enter(flags : SET);
		VAR
			ctrl : BOOLEAN;
			pos, lineStart, nofWhitespace, i : LONGINT;
			ch : Texts.Char32; buffer : ARRAY 32 OF Texts.Char32; idx : LONGINT;
		BEGIN
			ctrl := flags * Inputs.Ctrl # {};
			IF ctrl THEN (* put into different module ??? *)
				pos := tv.cursor.GetPosition();
				tv.StartCommand(pos, flags * Inputs.Shift # {});
			ELSE
				IF multiLine.Get() THEN
					pos := tv.GetInternalPos(tv.cursor.GetPosition());
					tv.cursor.SetNextInternalPosition(pos+1);

					lineStart := TextUtilities.FindPosLineStart(utilreader, pos);
					nofWhitespace := TextUtilities.CountWhitespace(utilreader, lineStart);
					nofWhitespace := Strings.Min(nofWhitespace, pos - lineStart);

					IF (nofWhitespace > 0) THEN
						idx := 0;
						buffer[idx] := Texts.NewLineChar;
						INC(idx);

						utilreader.SetPosition(lineStart);
						utilreader.SetDirection(1);
						utilreader.ReadCh(ch);

						i := 0;
						WHILE (i < nofWhitespace) & ~utilreader.eot  & (idx < LEN(buffer) - 1) DO
							buffer[idx] := ch;
							INC(idx); INC(i);
							utilreader.ReadCh(ch);
						END;

						buffer[idx] := 0;
						InsertString(buffer);

						(* in the case that 'buffer' was not large enough *)
						WHILE (i < nofWhitespace) & ~utilreader.eot DO
							InsertChar(ch);
							INC(i); utilreader.ReadCh(ch);
						END;
					ELSE
						InsertChar(Texts.NewLineChar);
					END;
				END
			END;
			onEnter.Call(NIL)
		END Enter;

		PROCEDURE IndentLeft;
		BEGIN
			text.AcquireWrite;
			tv.selection.Sort;
			TextUtilities.IndentText(text, tv.selection.a, tv.selection.b, TRUE);
			text.ReleaseWrite
		END IndentLeft;

		PROCEDURE IndentRight;
		BEGIN
			text.AcquireWrite;
			tv.selection.Sort;
			TextUtilities.IndentText(text, tv.selection.a, tv.selection.b, FALSE);
			text.ReleaseWrite
		END IndentRight;

		PROCEDURE MousePressed(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR
			pos, internalPos, a, b : LONGINT; ch : Texts.Char32;
			selectionText : Texts.Text;
			from, to : Texts.TextPosition;
		BEGIN
			IF (Inputs.Alt * currentFlags # {}) & (0 IN keys) THEN
				text.AcquireWrite;
				IF Texts.GetLastSelection(selectionText, from, to) THEN
					selectionText.AcquireWrite;
					a := Strings.Min(from.GetPosition(), to.GetPosition());
					b := Strings.Max(from.GetPosition(), to.GetPosition());

					tv.ViewToTextPos(x, y, pos);
					(* get the internal position of the cursor *)
					internalPos := tv.GetInternalPos(pos);
					utilreader.SetPosition(internalPos);
					utilreader.ReadCh(ch);
					IF utilreader.cstyle # NIL THEN
						handled := TRUE;
						selectionText.SetCharacterStyle(a, b - a, utilreader.cstyle);
					ELSIF utilreader.attributes # NIL THEN
						handled := TRUE;
						selectionText.SetAttributes(a, b - a, utilreader.attributes.Clone())
					END;
					IF utilreader.pstyle # NIL THEN
						selectionText.SetParagraphStyle(a, b - a, utilreader.pstyle);
					END;
					selectionText.ReleaseWrite
				END;
				text.ReleaseWrite
			END
		END MousePressed;

		PROCEDURE KeyPressed*(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		VAR
			textChanged : BOOLEAN;

			PROCEDURE HandleTab;
			BEGIN (* {write lock on text} *)
				tv.selection.Sort;
				IF tv.selection.active THEN
					IF (flags = {}) THEN IndentRight; ELSE IndentLeft; END;
				ELSE
					InsertChar(Texts.TabChar);
				END;
			END HandleTab;

		BEGIN
			textChanged := FALSE;
			handled := TRUE;
			currentFlags := flags;
			tv.SetFlags(flags);
			IF readOnly.Get() THEN RETURN END;
			IF Inputs.Release IN flags THEN RETURN END;
			text.AcquireWrite;
			(* relaying the navigation keys to the view *)
			IF keySym = 14H THEN (* Ctrl-T *)
				text.CheckHealth
			ELSIF keySym = 01H THEN (* Ctrl-A *)
				tv.SelectAll
			ELSIF keySym = 03H THEN (* Ctrl-C *)
				tv.CopySelection
			ELSIF (keySym = Inputs.KsTab) & (flags - Inputs.Shift = {}) THEN (* SHIFT-Tab or Tab *)
				HandleTab;
			ELSIF keySym = 19H THEN (* Ctrl-Y *)
				IF undoMgr # NIL THEN
					undoMgr.Redo
				END
			ELSIF keySym = 1AH THEN (* Ctrl-Z *)
				IF undoMgr # NIL THEN
					undoMgr.Undo
				END
 			ELSIF (keySym = 0FF63H) & (flags * Inputs.Ctrl # {}) THEN  (*Ctrl Insert *)
 				tv.CopySelection
			ELSIF keySym = 0FF51H THEN (* Cursor Left *)
				IF flags * Inputs.Alt # {} THEN IndentLeft
				ELSE tv.CursorLeft(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				END
			ELSIF keySym = 0FF53H THEN (* Cursor Right *)
				IF flags * Inputs.Alt # {} THEN IndentRight
				ELSE tv.CursorRight(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
				END
			ELSIF keySym = 0FF54H THEN (* Cursor Down *)
				tv.CursorDown(flags * Inputs.Shift # {})
			ELSIF keySym = 0FF52H THEN (* Cursor Up *)
				tv.CursorUp(flags * Inputs.Shift # {})
			ELSIF keySym = 0FF56H THEN (* Page Down *)
				tv.PageDown(flags * Inputs.Shift # {})
			ELSIF keySym = 0FF55H THEN (* Page Up *)
				tv.PageUp(flags * Inputs.Shift # {})
			ELSIF keySym = 0FF50H THEN (* Cursor Home *)
				tv.Home(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			ELSIF keySym = 0FF57H THEN (* Cursor End *)
				tv.End(flags * Inputs.Ctrl # {}, flags * Inputs.Shift # {})
			(* end of relay section *)
			ELSIF keySym =  016H THEN (* Ctrl-V *)
				textChanged := TRUE;
				Paste
			ELSIF keySym = 17H THEN (* Ctrl-W *)
				PasteToHostClipboard;
			ELSIF keySym = 018H THEN (* Ctrl-X *)
				textChanged := TRUE;
				CopySelection;
				DeleteSelection
			ELSIF keySym = 0FFFFH THEN (* Delete *)
				textChanged := TRUE;
				Delete(flags)
			ELSIF keySym = 0FF08H THEN (* Backspace *)
				textChanged := TRUE;
				Backspace(flags * Inputs.Ctrl # {})
			ELSIF keySym = 0FF0DH THEN (* CR *)
				textChanged := TRUE;
				Enter(flags);
			ELSIF (keySym = 0FF63H) & (flags * Inputs.Shift # {}) THEN  (* Shift Insert *)
				textChanged := TRUE;
				Paste
			ELSIF (keySym = 0FF1BH) THEN onEscape.Call(NIL); FocusNext (* Escape *)
			ELSIF (keySym = 00020H) & (flags * Inputs.Ctrl # {}) & allowIME (* Ctrl-Space *)  THEN
				(* switch IME on/off and get the newly active IME *)
				ime := WMInputMethods.SwitchIME();
				IF ime # NIL THEN
					text.ReleaseWrite;
					SetIMEInterface(ime, text);
					text.AcquireWrite
				END
			ELSE
				(* get the currently active IME *)
				ime := WMInputMethods.activeIME;
				IF allowIME & (ime # NIL) & (ucs > 26) THEN
					IF tv.selection.b - tv.selection.a # 0 THEN DeleteSelection END;
					SetIMEInterface(ime, text);
					ime.KeyEvent(ucs, flags, keySym);
					textChanged := TRUE;
				ELSE
					macroData.handled := FALSE;
					macroData.flags := flags;
					macroData.keySym := keySym;
					macroData.text := text;
					macroData.cursor := tv.cursor;
					macros.Call(macroData);
					IF ~macroData.handled & (ucs > 26) THEN
						textChanged := TRUE;
						InsertChar(ucs);
					END
				END;
			END;
			text.ReleaseWrite;

			(* The new position must be set after the text lock has been released to guarantee, that the text has been
				reformatted. This leads to the 'flickering bug' when inserting a character at the end of an rtl-line. *)
			IF text.isUTF & textChanged THEN
				text.AcquireRead;
				tv.cursor.SetPosition(tv.GetDisplayPos(tv.cursor.GetNextInternalPosition()));
				text.ReleaseRead;
			END;
		END KeyPressed;

		PROCEDURE GetAsString*(VAR x : ARRAY OF CHAR);
		BEGIN
			TextUtilities.TextToStr(text, x)
		END GetAsString;

		(** Set UTF8 string as text. (Intended for single line case) *)
		PROCEDURE SetAsString*(CONST x : ARRAY OF CHAR);
		BEGIN
			text.AcquireWrite;
			text.Delete(0, text.GetLength());
			TextUtilities.StrToText(text, 0, x);
			text.ReleaseWrite
		END SetAsString;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF ime # NIL THEN ime.Hide END;
			IF tv # NIL THEN tv.Finalize; END;
		END Finalize;

	END Editor;

VAR
	manager : WMWindowManager.WindowManager;

	typeProto : WMProperties.Int32Property;
	textColorProto : WMProperties.ColorProperty;
	multiLineProto, readOnlyProto, allowScrollbarsProto : WMProperties.BooleanProperty;
	highlightingProto : WMProperties.StringProperty;
	GSonEnter, GSonEnterInfo : Strings.String;
	GSonEscape, GSonEscapeInfo : Strings.String;
	GSmacros, GSmacrosInfo : Strings.String;
	GSTextField, GSEditor, GSNumberField : Strings.String;
	GSModel, GSModelInfo : Strings.String;
	PrototypeAlignH, PrototypeAlignV, PrototypeTextBorder: WMProperties.Int32Property;
	PrototypeFractionalDigits*: WMProperties.Int32Property;
	PrototypeUnit*: WMProperties.ReferenceProperty;

PROCEDURE InitStrings;
BEGIN
	GSonEnter := Strings.NewString("onEnter");
	GSonEnterInfo := Strings.NewString("called after the Enter key is pressed in the editor");
	GSonEscape := Strings.NewString("onEscape");
	GSonEscapeInfo := Strings.NewString("called when the Escape key is pressed in the editor");
	GSmacros := Strings.NewString("macros");
	GSmacrosInfo := Strings.NewString("must be handled directly without queuing, text has writelock, may not trap");
	GSTextField := Strings.NewString("TextField");
	GSNumberField := Strings.NewString("NumberField");
	GSEditor := Strings.NewString("Editor");
	GSModel := Strings.NewString("Model");
	GSModelInfo := Strings.NewString("Model used by component");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(typeProto, NIL, Strings.NewString("type"), NIL); typeProto.Set(Unicode);
	NEW(textColorProto, NIL, Strings.NewString("textColor"), Strings.NewString("Text color")); textColorProto.Set(WMGraphics.Black);
	NEW(multiLineProto, NIL, Strings.NewString("multiLine"), NIL); multiLineProto.Set(TRUE);
	NEW(readOnlyProto, NIL, Strings.NewString("readOnly"), NIL); readOnlyProto.Set(FALSE);
	NEW(allowScrollbarsProto, NIL, Strings.NewString("allowScrollbars"), NIL); allowScrollbarsProto.Set(TRUE);
	NEW(highlightingProto, NIL, Strings.NewString("Highlighting"), Strings.NewString("Name of highlighting to be applied"));
	highlightingProto.Set(NIL);
	NEW(PrototypeAlignH, NIL, Strings.NewString("AlignH"), Strings.NewString("horizontal alignment"));
	PrototypeAlignH.Set(WMGraphics.AlignLeft);
	NEW(PrototypeAlignV, NIL, Strings.NewString("AlignV"), Strings.NewString("vertical alignment"));
	PrototypeAlignV.Set(WMGraphics.AlignCenter);
	NEW(PrototypeTextBorder, NIL, Strings.NewString("TextBorder"), Strings.NewString("text boundary"));
	PrototypeTextBorder.Set(4);
	NEW(PrototypeFractionalDigits, NIL, Strings.NewString("FractionalDigits"), Strings.NewString("fractional digits"));
	PrototypeFractionalDigits.Set(0);
	NEW(PrototypeUnit, NIL, Strings.NewString("Unit"), Strings.NewString("unit conversion factor"));

END InitPrototypes;

PROCEDURE GenTextField*() : XML.Element;
VAR t : TextField;
BEGIN
	NEW(t); RETURN t;
END GenTextField;

PROCEDURE GenNumberField*() : XML.Element;
VAR t : NumberField;
BEGIN
	NEW(t); RETURN t;
END GenNumberField;

PROCEDURE GenEditor*() : XML.Element;
VAR e : Editor;
BEGIN
	NEW(e); RETURN e
END GenEditor;

PROCEDURE FindTextField*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : TextField;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS TextField) THEN
		RETURN c (TextField);
	ELSE
		RETURN NIL;
	END;
END FindTextField;

PROCEDURE FindEditor*(CONST uid : ARRAY OF CHAR; component : WMComponents.Component) : Editor;
VAR c : WMComponents.Component;
BEGIN
	ASSERT(component # NIL);
	c := component.FindByUID(uid);
	IF (c # NIL) & (c IS Editor) THEN
		RETURN c (Editor);
	ELSE
		RETURN NIL;
	END;
END FindEditor;

BEGIN
	manager := WMWindowManager.GetDefaultManager();
	InitStrings;
	InitPrototypes;
END WMEditors.



ComponentViewer.Open WMStandardComponents.GenPanel ~
ComponentViewer.Open WMEditors.GenTextField  ~ 