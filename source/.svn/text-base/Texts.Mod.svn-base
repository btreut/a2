MODULE Texts;	(** AUTHOR "TF"; PURPOSE "Basic Unicode text system"; *)

IMPORT
	KernelLog, Streams, Kernel, WMEvents, Locks, Strings, FP1616, UTF8Strings,
	XML, XMLParser, XMLScanner, XMLObjects, Files;

CONST
	OpInsert* = 0;
	OpDelete* = 1;
	OpAttributes* = 2;
	OpMulti* = 3;

	NewLineChar* = 10;
	TabChar* = 9;
	SpaceChar* = 32;
	ObjectChar* = -1;
	LabelChar* = -2;

	UsePieceTable = TRUE;

	TraceHard = FALSE;

TYPE
	UCS32String* = ARRAY OF LONGINT;
	PUCS32String* = POINTER TO UCS32String;
	Char32* = LONGINT;

	FontInfo* = OBJECT
	VAR
		fontcache* : ANY;
		name* : ARRAY 32 OF CHAR;
		size* : LONGINT;
		style* : SET;

		PROCEDURE IsEqual*(f : FontInfo): BOOLEAN;
		BEGIN
			RETURN (name = f.name) & (size = f.size) & (style = f.style)
		END IsEqual;

		PROCEDURE Clone*() : FontInfo;
		VAR f : FontInfo;
		BEGIN
			NEW(f);
			f.fontcache := fontcache; COPY(name, f.name); f.size := size; f.style := style;
			RETURN f
		END Clone;
	END FontInfo;

	Attributes* = OBJECT
	VAR
		color*, bgcolor* : LONGINT;
		voff* : LONGINT;
		fontInfo* : FontInfo;

		PROCEDURE Set* (color, bgcolor, voff : LONGINT; CONST name : ARRAY OF CHAR; size : LONGINT; style : SET);
		BEGIN
			SELF.color := color;
			SELF.bgcolor := bgcolor;
			SELF.voff := voff;
			NEW(fontInfo);
			COPY(name, fontInfo.name);
			fontInfo.size := size;
			fontInfo.style := style
		END Set;

		PROCEDURE IsEqual*(attr : Attributes) : BOOLEAN;
		BEGIN
			RETURN (attr # NIL) & (color = attr.color) & (bgcolor = attr.bgcolor) & (voff = attr.voff) &
				( (fontInfo = NIL) & (attr.fontInfo = NIL) OR fontInfo.IsEqual(attr.fontInfo))
		END IsEqual;

		PROCEDURE Clone*():Attributes;
		VAR a : Attributes;
		BEGIN
			NEW(a);
			a.color := color; a.bgcolor := bgcolor; a.voff := voff; IF fontInfo # NIL THEN a.fontInfo := fontInfo.Clone() END;
			RETURN a
		END Clone;
	END Attributes;

	AttributeChangerProc* = PROCEDURE {DELEGATE} (VAR attributes : Attributes; userData : ANY);

	StyleChangedMsg* = OBJECT
	END StyleChangedMsg;

	ParagraphStyle* = OBJECT
	VAR
		name* : ARRAY 128 OF CHAR;				(* name of the paragraph style *)
		alignment* : LONGINT;						(* 0 = left, 1 = center, 2 = right, 3 = justified *)
		spaceBefore* : LONGINT;					(* space before paragraph [mm] *)
		spaceAfter* : LONGINT;						(* space after paragrapg [mm] *)
		leftIndent* : LONGINT;						(* left Indent [mm] *)
		rightIndent* : LONGINT;						(* right Indent [mm] *)
		firstIndent* : LONGINT;						(* first Line Indent [mm] *)
		charStyle* : CharacterStyle;					(* default character style *)
		tabStops* : ARRAY 256 OF CHAR;			(* tabStop String *)

		PROCEDURE IsEqual*(style : ParagraphStyle) : BOOLEAN;
		BEGIN
			RETURN (style # NIL) & (name = style.name) & (alignment = style.alignment) & (spaceBefore = style.spaceBefore) &
				(spaceAfter = style.spaceAfter) & (leftIndent = style.leftIndent) & (rightIndent = style.rightIndent) &
				(firstIndent = style.firstIndent) & (charStyle = style.charStyle) & (tabStops = style.tabStops)
		END IsEqual;

		PROCEDURE Clone*(): ParagraphStyle;
		VAR newStyle : ParagraphStyle; newName : ARRAY 128 OF CHAR;
		BEGIN
			NEW(newStyle);
			COPY(name,newName);
			Strings.Append(newName,"COPY");
			WHILE GetParagraphStyleByName(newName) # NIL DO
				Strings.Append(newName,"COPY");
			END;
			COPY(newName, newStyle.name);
			newStyle.alignment := alignment;
			newStyle.spaceBefore := spaceBefore;
			newStyle.spaceAfter := spaceAfter;
			newStyle.leftIndent := leftIndent;
			newStyle.rightIndent := rightIndent;
			newStyle.firstIndent := firstIndent;
			newStyle.charStyle := charStyle;
			COPY(tabStops, newStyle.tabStops);

			RETURN newStyle;
		END Clone;

	END ParagraphStyle;

	ParagraphStyleArray* = POINTER TO ARRAY OF ParagraphStyle;

	CharacterStyle* = OBJECT
	VAR
		fontcache* : ANY;
		name* : ARRAY 128 OF CHAR;				(* name of the character style *)
		family* : ARRAY 32 OF CHAR;				(* font family *)
		style* : SET;									(* font style; 0 = bold, 1 = italic *)
		size* : LONGINT;							(* font size [pt]; 1pt == 1/72inch == 0,3527777778mm *)
		leading* : LONGINT;							(* baseline distance [pt] - usually 120% of font size *)
		baselineShift* : LONGINT;					(* baseline shift up/down [pt] *)
		tracking* : LONGINT;						(* character spacing [pt] *)

		scaleHorizontal* : LONGINT;					(* horizontal character scale *)
		scaleVertical* : LONGINT;					(* vertical character scale *)
		color* : LONGINT;							(* character color *)
		bgColor* : LONGINT;						(* character background color *)

		PROCEDURE &New*;
		BEGIN
			fontcache := NIL;
		END New;

		PROCEDURE IsEqual*(cstyle : CharacterStyle) : BOOLEAN;
		BEGIN
			RETURN (cstyle # NIL) & (name = cstyle.name) & (family = cstyle.family) & (style = cstyle.style) & (leading = cstyle.leading) &
			(baselineShift = cstyle.baselineShift) & (tracking = cstyle.tracking) &
			(scaleHorizontal = cstyle.scaleHorizontal) & (scaleVertical = cstyle.scaleVertical) & (color = cstyle.color) &
			(bgColor = cstyle.bgColor)
		END IsEqual;

		PROCEDURE Clone*(): CharacterStyle;
		VAR newStyle : CharacterStyle; newName : ARRAY 128 OF CHAR;
		BEGIN
			NEW(newStyle);
			COPY(name, newName);
			Strings.Append(newName, "COPY");
			WHILE GetCharacterStyleByName(newName) # NIL DO
				Strings.Append(newName,"COPY");
			END;
			COPY(newName, newStyle.name);
			COPY(family, newStyle.family);
			newStyle.style := style;
			newStyle.size := size;
			newStyle.leading := leading;
			newStyle.baselineShift := baselineShift;
			newStyle.tracking := tracking;
			newStyle.scaleHorizontal := scaleHorizontal;
			newStyle.scaleVertical := scaleVertical;
			newStyle.color := color;
			newStyle.bgColor := bgColor;

			RETURN newStyle;
		END Clone;

	END CharacterStyle;

	CharacterStyleArray* = POINTER TO ARRAY OF CharacterStyle;

CONST
	HLOver* = 0; HLUnder* = 1; HLWave* = 2;

TYPE

	HighlightStyle* = OBJECT
	VAR
		kind*: LONGINT;

		PROCEDURE IsEqual*(hstyle: HighlightStyle) : BOOLEAN;
		BEGIN
			RETURN (hstyle # NIL) & (kind = hstyle.kind);
		END IsEqual;

	END HighlightStyle;

	Link* = Strings.String;

	Piece* = OBJECT
	VAR
		next*, prev* : Piece;
		len*, startpos* : LONGINT;
		attributes* : Attributes;
		pstyle* : ParagraphStyle;
		cstyle* : CharacterStyle;
		link* : Link;

		(** Return a copy of the piece, prev/next pointers nil and pos 0 *)
		PROCEDURE Clone*() : Piece;
		BEGIN
			HALT(301); (* Abstract *)
			RETURN NIL
		END Clone;

		(** Split the UnicodePiece at pos in text position and return right piece *)
		PROCEDURE Split*(pos : LONGINT; VAR right : Piece);
		BEGIN
			HALT(301); (* Abstract *)
		END Split;

		(** Merge right to self; return true if ok *)
		PROCEDURE Merge*(right : Piece) : BOOLEAN;
		BEGIN
			HALT(301); (* Abstract *)
			RETURN FALSE
		END Merge;

	END Piece;

	UnicodePiece* = OBJECT(Piece)
		(** index in text position; index and (index + length) must be in the piece *)
		PROCEDURE GetUCS32Buf*(index : LONGINT; length : LONGINT; VAR ucs : UCS32String; VAR res : LONGINT);
		END GetUCS32Buf;

		(** index in text position; index and (index + length) must be in the piece *)
		PROCEDURE GetUCS32*(index : LONGINT;  VAR ucs : Char32);
		END GetUCS32;
	END UnicodePiece;

	MemUnicodePiece* = OBJECT(UnicodePiece)
	VAR
		buffer : PUCS32String;

		PROCEDURE SetBuf(CONST buffer : UCS32String);
		VAR i : LONGINT;
		BEGIN
			WHILE buffer[i] # 0 DO INC(i) END; len := i;
			NEW(SELF.buffer, len);
			FOR i := 0 TO len - 1 DO SELF.buffer[i] := buffer[i] END
		END SetBuf;

		PROCEDURE SetBufAsUTF8(CONST buffer : ARRAY OF CHAR);
		VAR length, i, idx : LONGINT;
		BEGIN
			length := UTF8Strings.Length(buffer);
			NEW(SELF.buffer, length);
			i := 0; idx := 0;
			WHILE (i < length) & UTF8Strings.DecodeChar(buffer, idx, SELF.buffer[i]) DO INC(i); END;
		END SetBufAsUTF8;

		(** Return a copy of the piece, prev/next pointers nil and pos 0 *)
		PROCEDURE Clone*() : Piece;
		VAR m : MemUnicodePiece; i : LONGINT;
		BEGIN
			NEW(m);
			m.len := len;
			IF attributes # NIL THEN m.attributes := attributes.Clone() END;
			IF cstyle # NIL THEN m.cstyle := cstyle END;
			IF pstyle # NIL THEN m.pstyle := pstyle END;
			IF link # NIL THEN m.link := link END;
			NEW(m.buffer, LEN(buffer));
			FOR i := 0 TO LEN(buffer) - 1 DO m.buffer[i] := buffer[i] END;
			RETURN m
		END Clone;

		(** index in text position; index and (index + length) must be in the piece *)
		PROCEDURE GetUCS32Buf*(index : LONGINT; length : LONGINT; VAR ucs : UCS32String; VAR res : LONGINT);
		VAR i, j : LONGINT;
		BEGIN
			i := index - startpos; IF (i < 0) OR (i >= len) THEN ucs[0] := 0; res := -1; RETURN END;
			j := 0;
			WHILE (j < LEN(ucs)) & (j < length) & (i < len) DO ucs[j] := buffer[i]; INC(i); INC(j) END;
			IF (j < length) & (i >= len) THEN res := -1 ELSE res := 0 END;
			IF (j > LEN(ucs) - 1) THEN j := LEN(ucs) -1 END;
			ucs[j] := 0
		END GetUCS32Buf;

		PROCEDURE GetUCS32*(index : LONGINT; VAR ucs : Char32);
		VAR i: LONGINT;
		BEGIN
			i := index - startpos; IF (i < 0) OR (i >= len) THEN ucs := 0 ELSE ucs := buffer[i] END;
		END GetUCS32;

		(** Split the UnicodePiece at pos in text position and return right piece *)
		PROCEDURE Split*(pos : LONGINT; VAR right : Piece);
		VAR mp : MemUnicodePiece; i, j : LONGINT;
		BEGIN
			IF pos - startpos < len THEN
				(* create right part *)
				NEW(mp);
				IF attributes # NIL THEN mp.attributes := attributes.Clone() END;
				IF cstyle # NIL THEN mp.cstyle := cstyle END;
				IF pstyle # NIL THEN mp.pstyle := pstyle END;
				IF link # NIL THEN mp.link := link END;
				NEW(mp.buffer, len - (pos - startpos));
				mp.len := len - (pos - startpos); mp.startpos := pos;
				j := 0; FOR i := pos - startpos TO len - 1 DO mp.buffer[j] := buffer[i]; INC(j) END;
				(* adjust own length *)
				len := (pos - startpos);
				IF len <= 0 THEN
					KernelLog.String("BUG BUG BUG BUG BUG BUG BUG BUG"); KernelLog.Ln;
				END;
				(* linking *)
				mp.next := next; IF next # NIL THEN next.prev := mp END; mp.prev := SELF; next := mp;
				right := mp
			ELSE right := next
			END
		END Split;

		(** Merge right to self; return true if ok *)
		PROCEDURE Merge*(right : Piece) : BOOLEAN;
		VAR temp : PUCS32String; i, j : LONGINT;
		BEGIN
			IF right = NIL THEN RETURN FALSE END;
			IF right = SELF THEN KernelLog.String("Consistency Check in Texts Failed"); KernelLog.Ln END;
			IF (right.len > 1) & (right.next = NIL) THEN RETURN FALSE END; (* avoid overgreedily merging *)
			IF  (right IS MemUnicodePiece) & (right # SELF) &
				((attributes = NIL) & (right.attributes = NIL) OR (attributes # NIL) & attributes.IsEqual(right.attributes)) &
				((cstyle = NIL) & (right.cstyle = NIL) & (pstyle = NIL) & (right.pstyle = NIL) OR
				(cstyle # NIL) & cstyle.IsEqual(right.cstyle) & (pstyle # NIL) & pstyle.IsEqual(right.pstyle)) &
				(link = right.link) &
				(len < 1000) THEN
				NEW(temp, len + right.len);
				FOR i := 0 TO len - 1 DO temp[i] := buffer[i] END;
				WITH right : MemUnicodePiece DO
					j := len; FOR i := 0 TO right.len - 1 DO temp[j] := right.buffer[i]; INC(j) END;
				END;
				buffer := temp;
				len := len + right.len; next := right.next; IF next # NIL THEN next.prev := SELF END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END Merge;

	END MemUnicodePiece;

	ObjectPiece* = OBJECT(Piece)
	VAR
		object* : ANY;

		PROCEDURE &Init*;
		BEGIN
			len := 1
		END Init;

		(** Return a copy of the piece, prev/next pointers nil and pos 0 *)
		PROCEDURE Clone*() : Piece;
		VAR p : ObjectPiece;
		BEGIN
			NEW(p);
			p.len := len;
			IF attributes # NIL THEN p.attributes := attributes.Clone() END;
			IF cstyle # NIL THEN p.cstyle := cstyle END;
			IF pstyle # NIL THEN p.pstyle := pstyle END;
			IF link # NIL THEN p.link := link END;
			p.object := object;
			RETURN p
		END Clone;

		PROCEDURE Split*(pos : LONGINT; VAR right : Piece);
		BEGIN
			IF pos - startpos < len THEN
				KernelLog.String("Should never happen"); KernelLog.Ln;
			ELSE right := next; (* KernelLog.String("Huga right is next"); KernelLog.Ln; *)
			END
		END Split;

		(** Merge right to self; return true if ok *)
		PROCEDURE Merge*(right : Piece) : BOOLEAN;
		BEGIN
			RETURN FALSE
		END Merge;

	END ObjectPiece;

	LabelPiece* = OBJECT(Piece)
	VAR
		label* : Strings.String;

		PROCEDURE &Init*;
		BEGIN
			len := 1
		END Init;

		(** Return a copy of the piece, prev/next pointers nil and pos 0 *)
		PROCEDURE Clone*() : Piece;
		VAR p :  LabelPiece;
		BEGIN
			NEW(p);
			p.len := len;
			p.label := label;
			RETURN p
		END Clone;

		PROCEDURE Split*(pos : LONGINT; VAR right : Piece);
		BEGIN
			IF pos - startpos < len THEN
				KernelLog.String("Should never happen"); KernelLog.Ln;
			ELSE right := next; (* KernelLog.String("Huga right is next"); KernelLog.Ln; *)
			END
		END Split;

		(** Merge right to self; return true if ok *)
		PROCEDURE Merge*(right : Piece) : BOOLEAN;
		BEGIN
			RETURN FALSE
		END Merge;
	END LabelPiece;

	(* Used to translate an internal position into a display position and vice versa *)
	PositionTranslator* = PROCEDURE {DELEGATE} (pos : LONGINT) : LONGINT;

	(** a TextPosition is assigned to a text and positioned with SetPosition. If
		the text is changed after the position was set, the position is updated *)
	TextPosition* = OBJECT
	VAR
		position : LONGINT;
		data* : ANY;
		text- : UnicodeText;
		GetInternalPos, GetDisplayPos : PositionTranslator;
		nextInternalPos* : LONGINT;

		PROCEDURE &New*(t : UnicodeText);
		BEGIN
			text := t; text.RegisterPositionObject(SELF); position := 0;
		END New;

		(** Listens for text changes *)
		PROCEDURE Changed*(op, pos, len :  LONGINT);
		BEGIN
			IF TraceHard THEN
				KernelLog.String("TextPosition : ChangeRequest"); KernelLog.Int(op, 5); KernelLog.Int(pos, 5); KernelLog.Int(len, 5);KernelLog.Ln;
			END;

			IF (position >= pos) & (op = OpInsert) THEN
				IF ((GetInternalPos # NIL) & (GetDisplayPos # NIL)) THEN
					position := GetDisplayPos(nextInternalPos);
				ELSE
					INC(position, len);
				END;
			ELSIF (position >= pos) & (position <= pos + len)  & (op = OpDelete) THEN
				position := pos;
			ELSIF (position > pos) & (op = OpDelete) THEN
				IF position < len THEN KernelLog.String("WRONG"); KernelLog.String(" pos ="); KernelLog.Int(pos, 5);
				KernelLog.String(" len ="); KernelLog.Int(len, 5);
				KernelLog.String(" position = "); KernelLog.Int(position, 0); KernelLog.Ln;
				KernelLog.Ln END;
				DEC(position, len)
			END
		END Changed;

		(** Position in elements from text start.  *)
		PROCEDURE SetPosition*(pos : LONGINT);
		BEGIN
			IF pos < 0 THEN pos := 0 ELSIF pos > text.GetLength() THEN pos := text.GetLength() END;
			position := pos
		END SetPosition;

		(** Returns position in elements from the text start *)
		PROCEDURE GetPosition*():LONGINT;
		BEGIN
			RETURN position
		END GetPosition;

		(* Sets the callback function for display-to-internal-position translation *)
		PROCEDURE SetInternalPositionTranslator*(getInternalPos : PositionTranslator);
		BEGIN
			GetInternalPos := getInternalPos;
		END SetInternalPositionTranslator;

		(* Sets the callback function for internal-to-display-position translation *)
		PROCEDURE SetDisplayPositionTranslator*(getDisplayPos : PositionTranslator);
		BEGIN
			GetDisplayPos := getDisplayPos;
		END SetDisplayPositionTranslator;
	END TextPosition;

	(** a reader may not be shared by processes, must text must be hold by process *)
	TextReader* = OBJECT(TextPosition)
	VAR
		piece : Piece;
		backwards : BOOLEAN;
		eot- : BOOLEAN;
		voff-, color-, bgcolor- : LONGINT;
		font- : FontInfo;
		attributes- : Attributes;
		cstyle- : CharacterStyle;
		pstyle- : ParagraphStyle;
		link- : Link;
		object- : ANY;

		PROCEDURE &New*(t : UnicodeText);
		BEGIN
			New^(t); backwards := FALSE;
		END New;

		(* Clones the properties of an other reader to this reader *)
		PROCEDURE CloneProperties*(CONST otherReader : TextReader);
		BEGIN
			voff := otherReader.voff;
			color := otherReader.color;
			bgcolor := otherReader.bgcolor;
			IF font # NIL THEN font := otherReader.font.Clone(); END;
			IF otherReader.attributes # NIL THEN attributes := otherReader.attributes.Clone(); END;
			IF otherReader.cstyle # NIL THEN cstyle := otherReader.cstyle.Clone(); END;
			IF otherReader.pstyle # NIL THEN pstyle := otherReader.pstyle.Clone(); END;
			IF otherReader.link # NIL THEN link := Strings.NewString(otherReader.link^); END;
			object := otherReader.object;
		END CloneProperties;

		(** Listens for text changes *)
		PROCEDURE Changed*(op, pos, len :  LONGINT);
		BEGIN
			Changed^(op, pos, len); piece := NIL
		END Changed;

		PROCEDURE ReadCh*(VAR ucs32 : LONGINT);
		VAR res : LONGINT; tfont: FontInfo;
			tempObj : ObjectPiece;
		BEGIN
			eot := (backwards) & (position = 0) OR (~backwards) & (position = text.GetLength());
			IF eot THEN ucs32 := 0; RETURN END;
			IF (piece = NIL) OR (piece.startpos > position) OR (piece.startpos + piece.len <= position) THEN
				text.FindPiece(position, piece);
				IF (piece # NIL) & (piece IS ObjectPiece) THEN tempObj := piece(ObjectPiece); object := tempObj.object;
				ELSIF (piece # NIL) & (piece IS LabelPiece) THEN object := piece(LabelPiece);
				ELSE object := NIL
				END;
				IF piece = NIL THEN res := -1; ucs32 := 0; RETURN END;
				attributes := piece.attributes;
				cstyle := piece.cstyle;
				pstyle := piece.pstyle;
				link := piece.link;
				IF cstyle # NIL THEN
					voff := cstyle.baselineShift; color := cstyle.color; bgcolor := cstyle.bgColor;
					NEW(tfont); COPY(cstyle.family, tfont.name); tfont.size := ENTIER(FP1616.FixpToFloat(cstyle.size)); tfont.style := cstyle.style;
					font := tfont;
				ELSIF pstyle # NIL THEN
					voff := pstyle.charStyle.baselineShift; color := pstyle.charStyle.color; bgcolor := pstyle.charStyle.bgColor;
					NEW(tfont); COPY(pstyle.charStyle.family, tfont.name); tfont.size := ENTIER(FP1616.FixpToFloat(pstyle.charStyle.size)); tfont.style := pstyle.charStyle.style;
					font := tfont;
				ELSIF attributes # NIL THEN voff := attributes.voff; color := attributes.color; bgcolor := attributes.bgcolor; font := attributes.fontInfo
				ELSE voff := 0; color := 0FFH; bgcolor := 0; font := NIL
				END;
			END;

			IF TraceHard THEN
				IF res # 0 THEN
					KernelLog.String("  piece "); KernelLog.Int(piece.startpos, 5); KernelLog.String(" piepst :"); KernelLog.Int(position, 5);
					KernelLog.Ln;
					HALT(99);
				END;
			END;
			IF piece IS UnicodePiece THEN piece(UnicodePiece).GetUCS32(position, ucs32)
			ELSIF piece IS ObjectPiece THEN ucs32 := ObjectChar
			ELSIF piece IS LabelPiece THEN ucs32 := LabelChar
			END;
			IF backwards THEN DEC(position) ELSE INC(position) END
		END ReadCh;

		(** Position in elements from text start.  *)
		PROCEDURE SetPosition*(pos : LONGINT);
		VAR length : LONGINT;
		BEGIN
			length := text.GetLength();
			IF pos < 0 THEN
				pos := 0;
			ELSIF pos > length THEN
				pos := length;
			END;
			position := pos;
			eot := (backwards & (position = 0)) OR (~backwards & (position = length));
		END SetPosition;

		(** Direction the text is read. dir >= 0 --> forward; dir < 0 --> backwards
		      Backwards can be very slow depending on the text *)
		PROCEDURE SetDirection*(dir : LONGINT);
		BEGIN
			backwards := dir < 0;
			eot := (backwards & (position = 0)) OR (~backwards & (position = text.GetLength()));
		END SetDirection;

	END TextReader;

	TextChangeInfo* = OBJECT
	VAR
		timestamp*, op*, pos*, len* : LONGINT;
	END TextChangeInfo;

	UndoManager*= OBJECT

		PROCEDURE InsertText*(pos: LONGINT; text: Text);
		END InsertText;

		PROCEDURE DeleteText*(pos: LONGINT; text: Text);
		END DeleteText;

		PROCEDURE BeginObjectChange*(pos: LONGINT);
		END BeginObjectChange;

		PROCEDURE ObjectChanged*(pos, len, type: LONGINT; obj: ANY);
		END ObjectChanged;

		PROCEDURE EndObjectChange*(len, type: LONGINT; to: ANY);
		END EndObjectChange;

		PROCEDURE SetText*(text: Text);
		END SetText;

		PROCEDURE Undo*;
		END Undo;

		PROCEDURE Redo*;
		END Redo;

		(** Called when the write lock on the associated text is released. Can be used to notify listeners
			that are interestes in the current number of available undos/redos *)
		PROCEDURE InformListeners*;
		END InformListeners;

	END UndoManager;

TYPE
	(** UnicodeText offers an editable unicode text abstraction, basing on UnicodePiece *)
	UnicodeText* = OBJECT
	VAR
		first : Piece;
		length : LONGINT;
		nofPieces : LONGINT;

		posObjects : Kernel.FinalizedCollection;
		pop, ppos, plen : LONGINT;
		timestamp : LONGINT;
		upOp, upPos, upLen : LONGINT;
		onTextChanged* : WMEvents.EventSource;
		lock : Locks.RWLock;
		pieceTableOk : BOOLEAN;
		pieceTable : POINTER TO ARRAY OF Piece;
		isUTF- : BOOLEAN;	(* is false by default, which prevents the text from being reformatted if not utf *)

		um: UndoManager;

		PROCEDURE &New*;
		BEGIN
			NEW(lock);
			IF UsePieceTable THEN NEW(pieceTable, 256) END;
			pieceTableOk := FALSE;
			NEW(posObjects); timestamp := 0;
			upOp := -1; upPos := 0; upLen := 0;
			nofPieces := 0;
			isUTF := FALSE;
			NEW(onTextChanged, SELF, onTextChangedStr, NIL, NIL);
		END New;

		(* Marks the text as utf-formatted. Only utf-formatted texts are treated by the bidi algorithm. *)
		PROCEDURE SetUTF*(utf : BOOLEAN);
		BEGIN
			IF forceUTF THEN
				isUTF := TRUE;
			ELSIF unforceUTF THEN
				isUTF := FALSE;
			ELSE
				isUTF := utf;
			END;
		END SetUTF;

		PROCEDURE SetUndoManager*(u: UndoManager);
		BEGIN
			um := u;
			IF um # NIL THEN
				um.SetText(SELF)
			END
		END SetUndoManager;

		(** acquire a write lock on the object *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite
		END AcquireWrite;

		(** release the write lock on the object *)
		PROCEDURE ReleaseWrite*;
		VAR removeLock : BOOLEAN;
			op, pos, len, localtimestamp : LONGINT;
		BEGIN
			removeLock := lock.GetWLockLevel() = 1;
			IF removeLock THEN op := upOp; pos := upPos; len := upLen; localtimestamp := GetTimestamp(); upOp := -1 END;
			lock.ReleaseWrite;
			IF removeLock & (op >= 0) THEN InformListeners(localtimestamp, op, pos, len) END;
		END ReleaseWrite;

		(** Returns TRUE if the calling thread owns the write lock for this text, FALSE otherwise *)
		PROCEDURE HasWriteLock*() : BOOLEAN;
		BEGIN
			RETURN lock.HasWriteLock();
		END HasWriteLock;

		(** acquire a write lock on the object *)
		PROCEDURE AcquireRead*;
		BEGIN
			lock.AcquireRead
		END AcquireRead;

		(** release the write lock on the object *)
		PROCEDURE ReleaseRead*;
		BEGIN
			lock.ReleaseRead
		END ReleaseRead;

		(** Returns TRUE if the calling thread owns the read lock for this text, FALSE otherwise *)
		PROCEDURE HasReadLock*() : BOOLEAN;
		BEGIN
			RETURN lock.HasReadLock();
		END HasReadLock;

		PROCEDURE InformListeners(timestamp, op, pos, len : LONGINT);
		VAR updateInfo : TextChangeInfo; um : UndoManager;
		BEGIN
			NEW(updateInfo);
			updateInfo.timestamp := timestamp; updateInfo.op := op; updateInfo.pos := pos; updateInfo.len := len;
			onTextChanged.Call(updateInfo);
			um := SELF.um;
			IF (um # NIL) THEN um.InformListeners; END;
		END InformListeners;

		PROCEDURE UpdatePieceTable;
		VAR cur : Piece; len, i : LONGINT;
		BEGIN
			IF LEN(pieceTable^) < nofPieces THEN NEW(pieceTable, nofPieces * 2) END;
			len := LEN(pieceTable^);
			cur := first; i := 0; pieceTable[0] := first;
			WHILE (cur # NIL) & (i < len) DO pieceTable[i] := cur; cur := cur.next; INC(i) END;
			pieceTableOk := i = nofPieces;
			IF ~pieceTableOk THEN KernelLog.Int(i, 0); KernelLog.String(" vs "); KernelLog.Int(nofPieces, 0); KernelLog.Ln END;
		END UpdatePieceTable;

		(* Return the piece that contains pos or the last piece if pos is not found *)
		PROCEDURE FindPiece(pos : LONGINT; VAR piece : Piece);
		VAR a, b, m : LONGINT;
		BEGIN
			IF UsePieceTable THEN
				IF ~pieceTableOk THEN UpdatePieceTable END
			END;
			IF pieceTableOk THEN
				a := 0; b := nofPieces - 1;
				ASSERT(pieceTable[0] = first);
				WHILE (a < b) DO m := (a + b) DIV 2;
					piece := pieceTable[m];
					IF piece.startpos + piece.len <= pos THEN a := m + 1 ELSE b := m END
				END;
				piece := pieceTable[a];
				IF piece = NIL THEN RETURN END;

				IF ~(piece.startpos + piece.len >= pos) THEN
					IF FALSE (*debug*) THEN
						KernelLog.String("pos = "); KernelLog.Int(pos, 0); KernelLog.Ln;
						KernelLog.String("startpos = "); KernelLog.Int(piece.startpos, 0);  KernelLog.Ln;
						KernelLog.String("len = "); KernelLog.Int(piece.len, 0);  KernelLog.Ln;
					END;
				END;

			ELSE
				piece := first; IF piece = NIL THEN RETURN END;
				LOOP
					IF (piece.next = NIL) OR (piece.startpos + piece.len > pos) THEN RETURN END;
					piece := piece.next
				END
			END
		END FindPiece;

		PROCEDURE SendPositionUpdate(obj: ANY; VAR cont: BOOLEAN);
		BEGIN
			cont := TRUE;
			IF obj IS TextPosition THEN
				obj(TextPosition).Changed(pop, ppos, plen)
			END
		END SendPositionUpdate;

		PROCEDURE UpdatePositionObjects(op, pos, len : LONGINT);
		BEGIN
			SELF.pop := op; SELF.ppos := pos; SELF.plen := len;
			posObjects.Enumerate(SendPositionUpdate)
		END UpdatePositionObjects;

		PROCEDURE AccumulateChanges(op, pos, len : LONGINT);
		BEGIN
			IF upOp >= 0 THEN
				IF (upOp = OpInsert) & (op = OpAttributes) & (pos = upPos) & (len = upLen) THEN (* ignore *)
				ELSE upOp := OpMulti
				END
			ELSE upOp := op; upPos := pos; upLen := len
			END;
		END AccumulateChanges;

		(** Register a position object on the text. The TextPosition objects are automatically be updated if the text is changed.
			TextPosition objects are automatically unregistred by the garbage collector *)
		PROCEDURE RegisterPositionObject*(po : TextPosition);
		BEGIN
			posObjects.Add(po, NIL)
		END RegisterPositionObject;

		(** Split the piece list at pos and return left and right. left or right can be NIL if at end/begin *)
		PROCEDURE GetSplittedPos(pos : LONGINT; VAR left, right: Piece);
		VAR p, t : Piece;
		BEGIN
			FindPiece(pos, p);
			IF p = NIL THEN left := NIL; right := NIL; RETURN END;
			IF p.startpos = pos THEN left := p.prev; right := p
			ELSE t := p.next; left := p; p.Split(pos, right);
				IF right # t THEN
					pieceTableOk := FALSE; INC(nofPieces)
				END
			END
		END GetSplittedPos;

		(** Insert a piece at position pos into the text. Index in characters/objects *)
		PROCEDURE InsertPiece*(pos : LONGINT; n : Piece);
		VAR l, r, cur : Piece;
			chpos, chlen : LONGINT;
		BEGIN
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			IF pos > length THEN pos := length END;

			INC(length, n.len);
			chpos := pos; chlen := n.len;
			IF first = NIL THEN n.next := NIL; n.prev := NIL; first := n; nofPieces := 1; pieceTableOk := FALSE
			ELSE
				GetSplittedPos(pos, l, r);
				IF l = NIL THEN n.next := first; first.prev := n; first := n
				ELSE l.next := n; n.prev := l; n.next := r; IF r # NIL THEN r.prev := n END
				END;

				INC(nofPieces);
				IF r = NIL THEN
				(* optimize loading by re-establishing the pieceTable *)
					IF nofPieces < LEN(pieceTable^) THEN pieceTable[nofPieces - 1] := n
					ELSE pieceTableOk := FALSE
					END
				ELSE pieceTableOk := FALSE
				END;
				cur := n; WHILE cur # NIL DO cur.startpos := pos; INC(pos, cur.len); cur := cur.next END;
				cur := n; IF cur.Merge(cur.next) THEN DEC(nofPieces); pieceTableOk := FALSE END;
				IF (cur.prev # NIL) & cur.prev.Merge(cur) THEN DEC(nofPieces); pieceTableOk := FALSE END
			END;
			AccumulateChanges(OpInsert, chpos, chlen);
			UpdatePositionObjects(OpInsert, chpos, chlen)
		END InsertPiece;

		PROCEDURE InsertObject*(obj: XML.Element);
		END InsertObject;

		(** Insert a UCS32 buffer at position pos into the text. Index in characters/objects *)
		PROCEDURE InsertUCS32* (pos : LONGINT; CONST buf : UCS32String);
		VAR n : MemUnicodePiece; p : Piece; t: Text;
		BEGIN
			ASSERT(lock.HasWriteLock(), 3000);
			IF buf[0] = 0 THEN RETURN END;
			IF pos > GetLength() THEN pos := GetLength() END;
			NEW(n); n.SetBuf(buf);
			FindPiece(pos, p);
			IF (p # NIL) THEN
				n.attributes := p.attributes;
				n.cstyle := p.cstyle;
				n.pstyle := p.pstyle;
				n.link := p.link;
			END;
			IF um # NIL THEN
				NEW(t);
				t.AcquireWrite;
				t.InsertUCS32(0, buf);
				um.InsertText(pos, t);
				t.ReleaseWrite;
			END;
			InsertPiece(pos, n);
		END InsertUCS32;

		PROCEDURE InsertUTF8*(pos : LONGINT; CONST buf : ARRAY OF CHAR);
		VAR n : MemUnicodePiece; p : Piece; text : Text;
		BEGIN
			ASSERT(lock.HasWriteLock(), 3000);
			IF (buf[0] # 0X) THEN
				IF (pos > GetLength()) THEN pos := GetLength(); END;
				NEW(n); n.SetBufAsUTF8(buf);
				FindPiece(pos, p);
				IF (p # NIL) THEN
					n.attributes := p.attributes;
					n.cstyle := p.cstyle;
					n.pstyle := p.pstyle;
					n.link := p.link;
				END;
				IF (um # NIL) THEN
					NEW(text);
					text.AcquireWrite;
					text.InsertUTF8(0, buf);
					um.InsertText(pos, text);
					text.ReleaseWrite;
				END;
				InsertPiece(pos, n);
			END;
		END InsertUTF8;

		(** Delete len characters from position pos  *)
		PROCEDURE Delete* (pos, len : LONGINT);
		VAR al, ar, bl, br, cur: Piece; p : LONGINT; t: Text;
		BEGIN
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			(* don't do illegal changes *)
			IF (len <= 0) OR (pos < 0) OR (pos + len > length) OR (first = NIL) THEN RETURN END;
			IF length = 0 THEN first := NIL; nofPieces := 0; pieceTableOk := FALSE
			ELSE
				GetSplittedPos(pos, al, ar);
				GetSplittedPos(pos + len, bl, br);

				IF um # NIL THEN
					NEW(t);
					t.AcquireWrite;
					t.CopyFromText(SELF, pos, len, 0);
					um.DeleteText(pos, t);
					t.ReleaseWrite;
				END;

				IF al # NIL THEN
					cur := al.next; WHILE (cur # NIL) & (cur # br) DO pieceTableOk := FALSE; DEC(nofPieces); cur := cur.next END;
					al.next := br; IF br # NIL THEN br.prev := al END;
					cur := al
				ELSE
					cur := first; WHILE (cur # NIL) & (cur # br) DO pieceTableOk := FALSE; DEC(nofPieces); cur := cur.next END;
					IF br # NIL THEN br.startpos := 0; br.prev := NIL END;
					first := br; cur := first
				END;
				IF cur # NIL THEN
					(* update the start positions of all the following pieces *)
					p := cur.startpos; WHILE cur # NIL DO cur.startpos := p; INC(p, cur.len); cur := cur.next END;
					IF (al # NIL) & al.Merge(al.next) THEN DEC(nofPieces) END
				END
			END;
			DEC(length, len);
			IF (first = NIL) & (length # 0) THEN KernelLog.String("ERROR : No text but length > 0 ! "); KernelLog.Ln END;
			AccumulateChanges(OpDelete, pos, len);
			UpdatePositionObjects(OpDelete, pos, len)
		END Delete;

		PROCEDURE CopyFromText*(fromText: UnicodeText; fromPos, len, destPos : LONGINT);
		VAR fromP, toP, curP : Piece; pos : LONGINT; t: Text;
		BEGIN
			ASSERT(lock.HasWriteLock(), 3000);
			ASSERT(fromText.lock.HasReadLock(), 3000);
			ASSERT(fromText # NIL);
			ASSERT(fromPos >= 0);
			ASSERT(len >= 0);
			ASSERT(fromPos + len <= fromText.length);
			ASSERT(destPos >= 0);
			ASSERT((fromText # SELF) OR ((destPos < fromPos) OR (destPos >  fromPos + len))); (* Avoid recursive copy *)

			fromText.GetSplittedPos(fromPos, curP, fromP);
			fromText.GetSplittedPos(fromPos + len, curP, toP);

			curP := fromP; pos := destPos;

			WHILE (curP # NIL) & (curP # toP) DO
				InsertPiece(pos, curP.Clone());
				INC(pos, curP.len);
				curP := curP.next
			END;

			IF um # NIL THEN
				NEW(t);
				t.AcquireWrite;
				t.CopyFromText(SELF, destPos, len, 0);
				um.InsertText(destPos, t);
				t.ReleaseWrite;
			END;
		END CopyFromText;

		PROCEDURE AttributeChanger(VAR attr : Attributes; userData : ANY);
		BEGIN
			IF (userData # NIL) & (userData IS Attributes) THEN attr := userData(Attributes) END;
		END AttributeChanger;

		(** Set piece attributes for charater at position pos to pos + len. [Must hold write lock] *)
		PROCEDURE SetAttributes*(pos, len : LONGINT; attr : Attributes);
		BEGIN
			UpdateAttributes(pos, len, AttributeChanger, attr)
		END SetAttributes;

		(** Calls the attributeChanger procedure for all pieces so the attributes can be changed. userData
			is forwarded to the attributeChanger as context.
		 [Must hold write lock] *)
		PROCEDURE UpdateAttributes*(pos, len : LONGINT; attributeChanger : AttributeChangerProc; userData : ANY);
		VAR al, ar, bl, br, cur : Piece;
		BEGIN
			IF len = 0 THEN RETURN END;
			(* don't do illegal changes *)
			IF (len <= 0) OR (pos < 0) OR (pos + len > length) OR (first = NIL) THEN RETURN END;
			ASSERT(attributeChanger # NIL);
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			GetSplittedPos(pos, al, ar);
			GetSplittedPos(pos + len, bl, br);
			cur := ar;
			IF um # NIL THEN um.BeginObjectChange(pos) END;
			WHILE cur # br DO
				IF um # NIL THEN
					IF cur.attributes = NIL THEN
						um.ObjectChanged(cur.startpos, cur.len, 102, NIL)
					ELSE
						um.ObjectChanged(cur.startpos, cur.len, 102, cur.attributes.Clone())
					END
				END;
				attributeChanger(cur.attributes, userData);
				cur := cur.next
			END;
			IF um # NIL THEN
				IF userData # NIL THEN
					um.EndObjectChange(len, 102, userData(Attributes).Clone())
				ELSE
					um.EndObjectChange(len, 102, NIL)
				END
			END;
			(* try merging *)
			WHILE (cur # NIL) & (cur # al) DO
				IF cur.prev # NIL THEN
					IF cur.prev.Merge(cur) THEN DEC(nofPieces); pieceTableOk := FALSE END
				END;
				cur := cur.prev
			END;
			AccumulateChanges(OpAttributes, pos, len);
			UpdatePositionObjects(OpAttributes, pos, len)
		END UpdateAttributes;

		(** Set piece character style for character at position pos to pos + len. [Must hold lock] *)
		PROCEDURE SetCharacterStyle*(pos, len : LONGINT; cstyle : CharacterStyle);
		VAR al, ar, bl, br, cur : Piece;
		BEGIN
			IF len = 0 THEN RETURN END;
			(* don't do illegal changes *)
			IF (len <= 0) OR (pos < 0) OR (pos + len > length) OR (first = NIL) THEN RETURN END;
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			GetSplittedPos(pos, al, ar);
			GetSplittedPos(pos + len, bl, br);
			cur := ar;
			IF um # NIL THEN um.BeginObjectChange(pos) END;
			WHILE cur # br DO
				IF um # NIL THEN um.ObjectChanged(cur.startpos, cur.len, 100, cur.cstyle) END;
				cur.cstyle := cstyle;
				cur := cur.next
			END;
			IF um # NIL THEN um.EndObjectChange(len, 100, cstyle)  END;
			(* try merging *)
			WHILE (cur # NIL) & (cur # al) DO
				IF cur.prev # NIL THEN
					IF cur.prev.Merge(cur) THEN DEC(nofPieces); pieceTableOk := FALSE END
				END;
				cur := cur.prev
			END;
			AccumulateChanges(OpAttributes, pos, len);
			UpdatePositionObjects(OpAttributes, pos, len)
		END SetCharacterStyle;

		(** Set piece paragraph style for charater at position pos to pos + len. [Must hold lock] *)
		PROCEDURE SetParagraphStyle*(pos, len : LONGINT; pstyle : ParagraphStyle);
		VAR al, ar, bl, br, cur : Piece;
		BEGIN
			IF len = 0 THEN RETURN END;
			(* don't do illegal changes *)
			IF (len <= 0) OR (pos < 0) OR (pos + len > length) OR (first = NIL) THEN RETURN END;
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			GetSplittedPos(pos, al, ar);
			GetSplittedPos(pos + len, bl, br);
			cur := ar;
			IF um # NIL THEN um.BeginObjectChange(pos) END;
			WHILE cur # br DO
				IF um # NIL THEN um.ObjectChanged(cur.startpos, cur.len, 101, cur.pstyle) END;
				cur.pstyle := pstyle;
				cur := cur.next
			END;
			IF um # NIL THEN um.EndObjectChange(len, 101, pstyle)  END;
			(* try merging *)
			WHILE (cur # NIL) & (cur # al) DO
				IF cur.prev # NIL THEN
					IF cur.prev.Merge(cur) THEN DEC(nofPieces); pieceTableOk := FALSE END
				END;
				cur := cur.prev
			END;
			AccumulateChanges(OpAttributes, pos, len);
			UpdatePositionObjects(OpAttributes, pos, len)
		END SetParagraphStyle;

		(** Set piece link for charater at position pos to pos + len. [Must hold lock] *)
		PROCEDURE SetLink*(pos, len : LONGINT; link :Link);
		VAR al, ar, bl, br, cur : Piece;
		BEGIN
			IF TraceHard THEN
				KernelLog.String("Setting Link: "); KernelLog.String("pos= "); KernelLog.Int(pos, 0);
				KernelLog.String(" length= "); KernelLog.Int(len, 0); KernelLog.Ln;
			END;
			IF len = 0 THEN RETURN END;
			(* don't do illegal changes *)
			IF (len <= 0) OR (pos < 0) OR (pos + len > length) OR (first = NIL) THEN RETURN END;
			ASSERT(lock.HasWriteLock(), 3000);
			INC(timestamp);
			GetSplittedPos(pos, al, ar);
			GetSplittedPos(pos + len, bl, br);
			cur := ar;
			WHILE cur # br DO cur.link := link; cur := cur.next END;
			(* try merging *)
			WHILE (cur # NIL) & (cur # al) DO
				IF cur.prev # NIL THEN
					IF cur.prev.Merge(cur) THEN DEC(nofPieces); pieceTableOk := FALSE END
				END;
				cur := cur.prev
			END;
			AccumulateChanges(OpAttributes, pos, len);
			UpdatePositionObjects(OpAttributes, pos, len)
		END SetLink;

		(** Return length in characters [Must hold lock]*)
		PROCEDURE GetLength* () : LONGINT;
		BEGIN
			ASSERT(lock.HasReadLock(), 3000);
			RETURN length
		END GetLength;

		(** Return the current timestamp [Must hold lock].
		The timestamp can be used to check if an asynchronous change notification reflects the last change. Text
		viewers can use this knowledge to incrementally update the layout. If the notification timestamp #
		GetTimestamp then a full update is needed *)
		PROCEDURE GetTimestamp*() : LONGINT;
		BEGIN
			ASSERT(lock.HasReadLock(), 3000);
			RETURN timestamp
		END GetTimestamp;

		PROCEDURE CheckHealth*;
		VAR cur : Piece;
			pos, i, nof : LONGINT; errors : BOOLEAN;
		BEGIN
			ASSERT(lock.HasReadLock(), 3000);
			nof := 0; pos := 0; cur := first; i := 0; errors := FALSE;
			WHILE cur # NIL DO
				INC(nof);
				IF cur.startpos # pos THEN
					KernelLog.String("Piece #"); KernelLog.Int(i, 4); KernelLog.String(" has wrong start pos"); KernelLog.Ln;
					errors := TRUE
				END;
				IF cur.len = 0 THEN
					KernelLog.String("Piece #"); KernelLog.Int(i, 4); KernelLog.String(" has zero length"); KernelLog.Ln;
					errors := TRUE
				END;
				pos := pos + cur.len;
				cur := cur.next; INC(i);
			END;

			IF pos # length THEN
				KernelLog.String("Piece-List-Length is inconsistent"); KernelLog.Ln;
				KernelLog.String("Measured length "); KernelLog.Int(pos, 4); KernelLog.Ln;
				KernelLog.String("Internal length "); KernelLog.Int(length, 4); KernelLog.Ln;

				errors := TRUE
			END;
			IF nof # nofPieces THEN errors := TRUE; KernelLog.String("ERROR : piece count failed");  KernelLog.Ln;
				KernelLog.String(" nof = "); KernelLog.Int(nof, 0); KernelLog.String(" nofPieces = "); KernelLog.Int(nofPieces, 0); KernelLog.Ln
			END;
			IF ~errors THEN KernelLog.String("Piece list is healthy"); KernelLog.Ln;
			ELSE KernelLog.String("!!! Piece list contains errors !!!!"); KernelLog.Ln
			END;
		END CheckHealth;

		PROCEDURE DumpPieces*;
		VAR cur : Piece; 	buf : PUCS32String;
		BEGIN
			cur := first;
			NEW(buf, 128);
			IF first = NIL THEN KernelLog.String("Empty piece list..."); KernelLog.Ln END;
			WHILE cur # NIL DO
				KernelLog.String("Piece pos = "); KernelLog.Int(cur.startpos, 5); KernelLog.String(" len "); KernelLog.Int(cur.len, 5);
				IF cur.attributes # NIL THEN
					KernelLog.String(" [Attributes : color = ");KernelLog.Hex(cur.attributes.color, 8);
					KernelLog.String(", bgcolor = "); KernelLog.Hex(cur.attributes.bgcolor, 8); KernelLog.String(" ]");
				END;
				IF cur IS UnicodePiece THEN KernelLog.String("[unicode]")
				ELSIF cur IS ObjectPiece THEN KernelLog.String("[object]")
				END;
				 KernelLog.Ln;
				cur := cur.next
			END
		END DumpPieces;
	END UnicodeText;

	Text* = UnicodeText;

VAR
	clipboard* : UnicodeText;
	onTextChangedStr : Strings.String;

	lastSelText : Text;
	lastSelFrom, lastSelTo : TextPosition;

	lastText : Text;
	onLastSelectionChanged-,
	onLastTextChanged- : WMEvents.EventSource;

	pStyles : ParagraphStyleArray; nofPStyles : LONGINT;
	cStyles : CharacterStyleArray; nofCStyles : LONGINT;

	forceUTF*, unforceUTF* : BOOLEAN;

(** Insert the given Paragraph Style into the Paragraph Style Array *)
PROCEDURE AddParagraphStyle*(style: ParagraphStyle);
VAR
	newStyles: ParagraphStyleArray;
	oldStyle: ParagraphStyle;
	cStyle: CharacterStyle;
	i : LONGINT;
BEGIN
	oldStyle := GetParagraphStyleByName(style.name);
	IF (oldStyle = NIL) THEN								(* style does not exist yet - create one *)
		INC(nofPStyles);
		IF nofPStyles > LEN(pStyles) THEN
			NEW(newStyles, LEN(pStyles) * 2);
			FOR i := 0 TO LEN(pStyles)-1 DO newStyles[i] := pStyles[i]; END;
			pStyles := newStyles;
		END;
		pStyles[nofPStyles-1] := style;
	ELSE												(* style does exist - only update style *)
		oldStyle.alignment := style.alignment;
		oldStyle.firstIndent := style.firstIndent;
		oldStyle.leftIndent := style.leftIndent;
		oldStyle.rightIndent := style.rightIndent;
		oldStyle.spaceBefore := style.spaceBefore;
		oldStyle.spaceAfter := style.spaceAfter;
		cStyle := GetCharacterStyleByName(style.charStyle.name);
		IF cStyle # NIL THEN	oldStyle.charStyle := cStyle; END;
		COPY(style.tabStops, oldStyle.tabStops);
	END;
END AddParagraphStyle;

(** Remove the given Paragraph Style from the Paragraph Style Array *)
PROCEDURE RemoveParagraphStyle*(style: ParagraphStyle);
VAR i : LONGINT;
BEGIN
	i := 0; WHILE (i < nofPStyles) & (pStyles[i] # style) DO INC(i) END;
	IF i < nofPStyles THEN
		WHILE (i < nofPStyles-1) DO pStyles[i] := pStyles[i+1]; INC(i); END;
		DEC(nofPStyles);
		pStyles[nofPStyles] := NIL;
	END;
END RemoveParagraphStyle;

(** Return the Paragraph Style with the given Name if any *)
PROCEDURE GetParagraphStyleByName*(CONST name: ARRAY OF CHAR): ParagraphStyle;
VAR
	styleObject: ParagraphStyle;
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

(** Insert the given Character Style into the Character Style Array *)
PROCEDURE AddCharacterStyle*(style: CharacterStyle);
VAR
	newStyles: CharacterStyleArray;
	oldStyle: CharacterStyle;
	i : LONGINT;
BEGIN
	oldStyle := GetCharacterStyleByName(style.name);
	IF (oldStyle = NIL) THEN								(* style does not exist yet - create one *)
		INC(nofCStyles);
		IF nofCStyles > LEN(cStyles) THEN
			NEW(newStyles, LEN(cStyles) * 2);
			FOR i := 0 TO LEN(cStyles)-1 DO newStyles[i] := cStyles[i]; END;
			cStyles := newStyles;
		END;
		cStyles[nofCStyles-1] := style;
	ELSE												(* style does exist - only update style *)
		IF ~oldStyle.IsEqual(style) THEN
			oldStyle.fontcache := NIL;
			COPY(style.family, oldStyle.family);
			oldStyle.style := style.style;
			oldStyle.size := style.size;
			oldStyle.leading := style.leading;
			oldStyle.baselineShift := style.baselineShift;
			oldStyle.color := style.color;
			oldStyle.bgColor := style.bgColor;
			oldStyle.tracking := style.tracking;
			oldStyle.scaleHorizontal := style.scaleHorizontal;
			oldStyle.scaleVertical := style.scaleVertical;
		END;
	END;
END AddCharacterStyle;

(** Remove the given Character Style from  the Character Style Array *)
PROCEDURE RemoveCharacterStyle*(style: CharacterStyle);
VAR i : LONGINT;
BEGIN
	i := 0; WHILE (i < nofCStyles) & (cStyles[i] # style) DO INC(i) END;
	IF i < nofCStyles THEN
		WHILE (i < nofCStyles-1) DO cStyles[i] := cStyles[i+1]; INC(i); END;
		DEC(nofCStyles);
		cStyles[nofCStyles] := NIL;
	END;
END RemoveCharacterStyle;

(** Returns the Character Style with the given Name if any *)
PROCEDURE GetCharacterStyleByName*(CONST name: ARRAY OF CHAR): CharacterStyle;
VAR
	styleObject: CharacterStyle;
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

PROCEDURE GetCharacterStyleArray*(): CharacterStyleArray;
BEGIN
	RETURN cStyles;
END GetCharacterStyleArray;

PROCEDURE GetParagraphStyleArray*(): ParagraphStyleArray;
BEGIN
	RETURN pStyles;
END GetParagraphStyleArray;

(* loads the default styles from the default-style XML *)
PROCEDURE InitDefaultStyles;
VAR reader : Files.Reader; f : Files.File;
BEGIN
	(* Load Default Styles *)
	f := Files.Old("DefaultTextStyles.XML");
	IF f = NIL THEN RETURN END;
	NEW(reader, f, 0);
	LoadStyles(reader, FALSE);
	(* Load User Styles *)
	f := Files.Old("UserTextStyles.XML");
	IF f = NIL THEN RETURN END;
	NEW(reader, f, 0);
	LoadStyles(reader, FALSE);
END InitDefaultStyles;

(* loads the styles from the given reader *)
PROCEDURE LoadStyles*(r: Streams.Reader; verbose: BOOLEAN);
VAR
	parser : XMLParser.Parser;
	scanner : XMLScanner.Scanner;
	defaultStyles : XML.Document;
	root: XML.Element;
	content : XMLObjects.Enumerator;
	ptr : ANY;
	str: Strings.String;
	cStyle : CharacterStyle;
	pStyle : ParagraphStyle;
	tempReal: LONGREAL; tempInt, tempRes : LONGINT;
BEGIN
	NEW(scanner, r);
	NEW(parser, scanner);
	defaultStyles := parser.Parse();

	root := defaultStyles.GetRoot();
	content := root.GetContents(); content.Reset();
	WHILE content.HasMoreElements() DO
		ptr := content.GetNext();
		IF ptr IS XML.Element THEN
			str := ptr(XML.Element).GetName();

			IF (str # NIL) & (str^ = "character-style") THEN					(* character styles *)
				NEW(cStyle);
				str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, cStyle.name) END;
				str := ptr(XML.Element).GetAttributeValue("font-family"); IF str # NIL THEN COPY(str^, cStyle.family) END;
				str := ptr(XML.Element).GetAttributeValue("font-style");
				IF str # NIL THEN
					IF (str^ = "0") THEN cStyle.style := {};
					ELSIF (str^ = "1") THEN cStyle.style := {0};
					ELSIF (str^ = "2") THEN cStyle.style := {1};
					ELSIF (str^ = "3") THEN cStyle.style := {0,1};
					ELSE cStyle.style := {};
					END;
				END;
				str := ptr(XML.Element).GetAttributeValue("font-size"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.size := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("leading"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.leading := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("baseline-shift"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.baselineShift := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("color"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, tempRes); cStyle.color := tempInt; END;
				str := ptr(XML.Element).GetAttributeValue("bgcolor"); IF str # NIL THEN Strings.HexStrToInt(str^, tempInt, tempRes); cStyle.bgColor := tempInt; END;
				str := ptr(XML.Element).GetAttributeValue("tracking"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.tracking := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("h-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleHorizontal := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("v-scale"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); cStyle.scaleVertical := FP1616.FloatToFixp(SHORT(tempReal)); END;
				AddCharacterStyle(cStyle);									(* Load the Style into Texts *)
				IF verbose THEN KernelLog.String("Texts Loading Character Style: "); KernelLog.String(cStyle.name); KernelLog.Ln; END;

			ELSIF (str # NIL) & (str^ = "paragraph-style") THEN				(* paragraph styles *)
				NEW(pStyle);
				str := ptr(XML.Element).GetAttributeValue("name"); IF str # NIL THEN COPY(str^, pStyle.name) END;
				str := ptr(XML.Element).GetAttributeValue("alignment"); IF str # NIL THEN Strings.StrToInt(str^, pStyle.alignment) END;
				str := ptr(XML.Element).GetAttributeValue("first-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.firstIndent := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("left-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.leftIndent := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("right-indent"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.rightIndent :=  FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("space-before"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceBefore := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("space-after"); IF str # NIL THEN Strings.StrToFloat(str^, tempReal); pStyle.spaceAfter := FP1616.FloatToFixp(SHORT(tempReal)); END;
				str := ptr(XML.Element).GetAttributeValue("character-style");
				IF str # NIL THEN
					cStyle := GetCharacterStyleByName(str^);
					IF cStyle # NIL THEN pStyle.charStyle := cStyle; END;
				END;
				str := ptr(XML.Element).GetAttributeValue("tab-stops"); IF str # NIL THEN COPY(str^, pStyle.tabStops) END;
				AddParagraphStyle(pStyle);									(* Load the Style into Texts *)
				IF verbose THEN KernelLog.String("Texts Loading Paragraph Style: "); KernelLog.String(pStyle.name); KernelLog.Ln; END;
			END;
		END;
	END;
END LoadStyles;

PROCEDURE SetLastSelection*(text : Text; from, to : TextPosition);
BEGIN
	ASSERT((text # NIL) & (from # NIL) & (to # NIL));
	BEGIN {EXCLUSIVE}
		lastSelText := text; lastSelFrom := from; lastSelTo := to
	END;
	onLastSelectionChanged.Call(text)
END SetLastSelection;

PROCEDURE ClearLastSelection*;
BEGIN {EXCLUSIVE}
	lastSelText := NIL; lastSelFrom := NIL; lastSelTo := NIL
END ClearLastSelection;

PROCEDURE GetLastSelection*(VAR text : Text; VAR from, to : TextPosition) : BOOLEAN;
BEGIN {EXCLUSIVE}
	text := lastSelText; from := lastSelFrom; to := lastSelTo;
	RETURN text # NIL
END GetLastSelection;

PROCEDURE SetLastText*(text : Text);
BEGIN
	BEGIN {EXCLUSIVE}
		lastText := text
	END;
	onLastTextChanged.Call(text)
END SetLastText;

PROCEDURE GetLastText*() : Text;
BEGIN {EXCLUSIVE}
	RETURN lastText
END GetLastText;

(*! Moved to the TextUtilities
PROCEDURE GetDefaultAttributes* () : Attributes;
VAR defaultAttributes : Attributes;
BEGIN
	NEW(defaultAttributes);
	defaultAttributes.Set(0FFH, 0H, 0, "Oberon", 10, {});
	RETURN defaultAttributes
END GetDefaultAttributes;
*)
BEGIN
	NEW(pStyles, 4); nofPStyles := 0;
	NEW(cStyles, 4); nofCStyles := 0;
	InitDefaultStyles;
	NEW(onTextChangedStr, 16); COPY("onTextChanged", onTextChangedStr^);
	NEW(onLastTextChanged, NIL, Strings.NewString("OnLastTextChanged"),
		Strings.NewString("fired when the last selection is changed"), NIL);
	NEW(onLastSelectionChanged, NIL, Strings.NewString("OnLastSelectionChanged"),
		Strings.NewString("fired when the last marked text is changed"), NIL);
	NEW(clipboard);

	forceUTF := FALSE;
	unforceUTF := TRUE;
END Texts.

