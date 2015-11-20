MODULE WMColorComponents; (** AUTHOR "FN"; PURPOSE "Color Tools GUI"; *)

IMPORT
	Strings, KernelLog, Raster, Texts, TextUtilities, XML,
	WMStandardComponents, WMGraphics, WMGraphicUtilities, WMComponents, WMRectangles,
	WMEditors, WMWindowManager, WMProperties, WMDropTarget, WMPopups, WMEvents;

TYPE
	ChangeHandler = PROCEDURE {DELEGATE};
	ColorChangeHandler = PROCEDURE {DELEGATE} (sender, color : ANY);

	Color* = OBJECT
	VAR value* : LONGINT
	END Color;

	ColorDropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR setColor : ColorChangeHandler;

		PROCEDURE & Init*(cch : ColorChangeHandler);
		BEGIN
			setColor := cch
		END Init;

		PROCEDURE GetInterface*(type : LONGINT) : WMDropTarget.DropInterface;
		VAR cdi : ColorDropInterface;
		BEGIN
			IF type = WMDropTarget.TypeInt32 THEN
				NEW(cdi, setColor); RETURN cdi
			ELSE
				RETURN NIL
			END
		END GetInterface;

	END ColorDropTarget;

	ColorDropInterface = OBJECT(WMDropTarget.DropInt32)
	VAR setColor : ColorChangeHandler;

		PROCEDURE & Init*(cch : ColorChangeHandler);
		BEGIN
			setColor := cch
		END Init;

		PROCEDURE Set*(i : LONGINT);
		VAR c : Color;
		BEGIN
			NEW(c); c.value := i; setColor(SELF, c)
		END Set;

	END ColorDropInterface;

	(** a controlled input-filed for numeric inputs *)
	NumberInput* = OBJECT(WMComponents.VisualComponent)
	VAR
		input : WMEditors.Editor;
		buttons : WMStandardComponents.Panel;
		caption -: WMStandardComponents.Label;

		min-, max-, value- : WMProperties.Int32Property;

		changeHandler : ChangeHandler;

		PROCEDURE & Init*;
		VAR plus, minus : WMStandardComponents.Button;
		BEGIN
			Init^;
			SetNameAsString(StrNumberInput);
			SetGenerator("WMColorComponents.GenNumberInput");
			(* properties *)
			NEW(min, NIL, Strings.NewString("Min"), Strings.NewString("Minimal value")); properties.Add(min);
			NEW(max, NIL, Strings.NewString("Max"), Strings.NewString("Maximal value")); properties.Add(max);
			NEW(value, NIL, Strings.NewString("Value"), Strings.NewString("Model")); properties.Add(value);
			(* bounds *)
			bounds.SetHeight(21);
			(* caption *)
			NEW(caption); caption.alignment.Set(WMComponents.AlignLeft); AddInternalComponent(caption);
			caption.bounds.SetWidth(10); caption.fillColor.Set(0FFFFFFFFH);
			(* input field *)
			NEW(input); input.multiLine.Set(FALSE); input.bounds.SetWidth(30); input.alignment.Set(WMComponents.AlignLeft);
			input.tv.showBorder.Set(TRUE); AddInternalComponent(input);
			input.tv.textAlignV.Set(WMGraphics.AlignCenter);
			input.text.onTextChanged.Add(ValueChanged);
			(* buttons *)
			NEW(buttons); buttons.bounds.SetWidth(20); buttons.alignment.Set(WMComponents.AlignLeft); AddInternalComponent(buttons);
			(* plus *)
			NEW(plus); plus.bounds.SetHeight(10); plus.SetCaption("+"); plus.useBgBitmaps.Set(FALSE); plus.alignment.Set(WMComponents.AlignTop);
			plus.onClick.Add(Increment); plus.isRepeating.Set(TRUE); buttons.AddInternalComponent(plus);
			(* minus *)
			NEW(minus); minus.bounds.SetHeight(10); minus.SetCaption("-"); minus.useBgBitmaps.Set(FALSE); minus.alignment.Set(WMComponents.AlignTop);
			minus.onClick.Add(Decrement); minus.isRepeating.Set(TRUE); buttons.AddInternalComponent(minus);
		END Init;

		(* update input editor *)
		PROCEDURE RecacheProperties;
		VAR buf : ARRAY 128 OF CHAR;
		BEGIN
			Strings.IntToStr(value.Get(), buf); input.SetAsString(buf)
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, prop : ANY);
		BEGIN
			IF prop = value THEN
				RecacheProperties
			ELSE
				PropertyChanged^(sender, prop)
			END
		END PropertyChanged;

		PROCEDURE Increment(sender, data : ANY);
		BEGIN
			IF value.Get() < max.Get() THEN
				value.Set(value.Get() + 1); PropertyChanged(SELF, value); changeHandler()
			END
		END Increment;

		PROCEDURE Decrement(sender, data : ANY);
		BEGIN
			IF value.Get() > min.Get() THEN
				value.Set(value.Get() - 1); PropertyChanged(SELF, value); changeHandler()
			END
		END Decrement;

		(* called if user modifies the input-field *)
		PROCEDURE ValueChanged(sender, data : ANY);
		VAR buf : ARRAY 128 OF CHAR; new : LONGINT;
		BEGIN
			input.GetAsString(buf);
			IF ~IsNumber(buf) THEN
				RecacheProperties
			ELSE
				Strings.StrToInt(buf, new);
				IF (new # value.Get()) THEN
					IF (new >= min.Get()) & (new <= max.Get()) THEN
						value.Set(new);
						changeHandler()
					ELSE
						RecacheProperties
					END
				END
			END
		END ValueChanged;

	END NumberInput;

	(** gui-component to specify a color in red-green-blue-transparency *)
	NumericColorChooser* = OBJECT(WMStandardComponents.Panel)
	VAR r, g, b, t : NumberInput; (* red, green, blue, transparency *)
		colorChangeHandler : ColorChangeHandler; (* to be called when color has been changed from inside this object *)

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(StrNumericColorChooser);
			SetGenerator("WMColorComponents.GenNumericColorChooser");
			(* red *)
			NEW(r); r.alignment.Set(WMComponents.AlignTop); AddInternalComponent(r);
			r.caption.SetCaption("R"); r.min.Set(0); r.max.Set(255); r.changeHandler := NumberInputChanged;
			(* green *)
			NEW(g); g.alignment.Set(WMComponents.AlignTop); AddInternalComponent(g);
			g.caption.SetCaption("G"); g.min.Set(0); g.max.Set(255); g.changeHandler := NumberInputChanged;
			(* blue *)
			NEW(b); b.alignment.Set(WMComponents.AlignTop); AddInternalComponent(b);
			b.caption.SetCaption("B"); b.min.Set(0); b.max.Set(255); b.changeHandler := NumberInputChanged;
			(* transparency *)
			NEW(t); t.alignment.Set(WMComponents.AlignTop); AddInternalComponent(t);
			t.caption.SetCaption("T"); t.min.Set(0); t.max.Set(255); t.changeHandler := NumberInputChanged;
			(* handler *)
			colorChangeHandler := DefaultColorChangeHandler
		END Init;

		PROCEDURE SetColor*(sender, color : ANY);
		VAR c : LONGINT;
		BEGIN
			IF color IS Color THEN
				c := color(Color).value;
				t.value.Set(c MOD 256); c := c DIV 256;
				b.value.Set(c MOD 256); c := c DIV 256;
				g.value.Set(c MOD 256); c := c DIV 256;
				r.value.Set(c MOD 256);
			END
		END SetColor;

		PROCEDURE SetExternalColorChangeHandler*(cch : ColorChangeHandler);
		BEGIN
			colorChangeHandler := cch
		END SetExternalColorChangeHandler;

		PROCEDURE NumberInputChanged;
		VAR c : Color;
		BEGIN
			NEW(c); c.value := (256*256*256)*r.value.Get() + (256*256)*g.value.Get() + (256)*b.value.Get() + t.value.Get();
			colorChangeHandler(SELF, c)
		END NumberInputChanged;

		PROCEDURE DefaultColorChangeHandler(sender, color : ANY);
		END DefaultColorChangeHandler;

	END NumericColorChooser;

	(** saves a color-value temporarly, color can be dragged from and unto *)
	ColorPot *= OBJECT(WMStandardComponents.Panel)
	VAR dragPossible : BOOLEAN;
		colorChangeHandler : ColorChangeHandler;

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetNameAsString(StrColorPot);
			SetGenerator("WMColorComponents.GenColorPot");
			onStartDrag.Add(MyStartDrag); colorChangeHandler := DefaultColorChangeHandler
		END Init;

		(* draw a line around the panel *)
		PROCEDURE DrawBackground(c : WMGraphics.Canvas);
		VAR rect : WMRectangles.Rectangle; h, w : LONGINT;
		BEGIN
			rect := GetClientRect(); w := rect.r DIV 2; h := rect.b DIV 2;
			(* background *)
			c.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0AAAAAAFFH), WMGraphics.ModeCopy);
			c.Fill(WMRectangles.MakeRect(w, h, 2*w, 2*h), LONGINT(0AAAAAAFFH), WMGraphics.ModeCopy);
			(* current color *)
			DrawBackground^(c);
			(* frame *)
			WMGraphicUtilities.DrawRect(c, GetClientRect(), WMGraphics.Black, WMGraphics.ModeSrcOverDst)
		END DrawBackground;

		(* return a string with the hex representation of the current color. the string is lead by a '0' and terminated by a 'H' *)
		PROCEDURE GetHexValue(VAR hex: ARRAY OF CHAR);
		VAR buf : ARRAY 10 OF CHAR; i : LONGINT;
		BEGIN
			Strings.IntToHexStr(fillColor.Get(), 7, buf);
			hex[0] := '0';
			FOR i := 1 TO 8 DO hex[i] := buf[i-1] END;
			hex[9] := 0X;
		END GetHexValue;

		(* set current color for this pot. color will be displayed in GUI *)
		PROCEDURE SetColor*(sender, color : ANY);
		BEGIN
			IF color IS Color THEN
				fillColor.Set(color(Color).value)
			END
		END SetColor;

		(* default handler; just sets color *)
		PROCEDURE DefaultColorChangeHandler(sender, color : ANY);
		BEGIN
			SetColor(sender, color)
		END DefaultColorChangeHandler;

		(* overwrite default handler *)
		PROCEDURE SetExternalColorChangeHandler*(cch : ColorChangeHandler);
		BEGIN
			colorChangeHandler := cch
		END SetExternalColorChangeHandler;

		(* ----- mouse handlers ----------------------------------------- *)

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			ASSERT(IsCallFromSequencer());
			dragPossible := TRUE
		END PointerDown;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		BEGIN
			dragPossible := FALSE
		END PointerUp;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		BEGIN
			IF dragPossible THEN dragPossible := FALSE; AutoStartDrag() END
		END PointerMove;

		(* ----- drag and drop handlers ----------------------------------- *)

		(* called when a drag-operation has been started *)
		PROCEDURE MyStartDrag(sender, data : ANY);
		VAR img : WMGraphics.Image; c : WMGraphics.BufferCanvas; a : ANY;
		BEGIN
			NEW(img); Raster.Create(img, 15, 15, Raster.BGRA8888);
			NEW(c, img); c.Fill(WMRectangles.MakeRect(0, 0, 15, 15), fillColor.Get(), WMGraphics.ModeCopy);
			IF StartDrag(a, img, 0,0,DragArrived, NIL) THEN KernelLog.String("DraggingStarted"); KernelLog.Ln
			ELSE KernelLog.String("Drag could not be started"); KernelLog.Ln
			END
		END MyStartDrag;

		(* called when color dragged from here has been dropped elsewhere  *)
		PROCEDURE DragArrived(sender, data : ANY);
		VAR di : WMWindowManager.DragInfo;
			dt : WMDropTarget.DropTarget;
			itf : WMDropTarget.DropInterface;
			text : Texts.Text;
			textPos : Texts.TextPosition;
			hex: ARRAY 10 OF CHAR;
			res : LONGINT;
		BEGIN
			IF (data # NIL) & (data IS WMWindowManager.DragInfo) THEN
				di := data(WMWindowManager.DragInfo);
				IF (di.data # NIL) & (di.data IS WMDropTarget.DropTarget) THEN
					dt := di.data(WMDropTarget.DropTarget)
				ELSE RETURN
				END
			ELSE RETURN
			END;
				(* drop text *)
			itf := dt.GetInterface(WMDropTarget.TypeText);
			IF itf # NIL THEN
				text := itf(WMDropTarget.DropText).text;
				textPos := itf(WMDropTarget.DropText).pos;
				IF (text # NIL) & (textPos # NIL) THEN
					text.AcquireWrite; GetHexValue (hex); TextUtilities.StrToText(text, textPos.GetPosition(), hex); text.ReleaseWrite;
				END;
				RETURN
			END;
				(* drop integer *)
			itf := dt.GetInterface(WMDropTarget.TypeInt32);
			IF itf # NIL THEN
				itf(WMDropTarget.DropInt32).Set(fillColor.Get());
				RETURN
			END;

			itf := dt.GetInterface(WMDropTarget.TypeString);
			IF itf # NIL THEN
				GetHexValue(hex); itf(WMDropTarget.DropString).Set(hex, res);
				RETURN;
			END;
		END DragArrived;

		(* called by MyDraggedDropped *)
		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR dt : ColorDropTarget;
		BEGIN
			NEW(dt, colorChangeHandler); dragInfo.data := dt; ConfirmDrag(TRUE, dragInfo)
		END DragDropped;

	END ColorPot;

	(** gui-component to choose and manage colors; consisting of a color palette, a numeric color-input and temporary color-stores *)
	ColorChooser* = OBJECT(WMStandardComponents.Panel)
	VAR title -: WMStandardComponents.Label;
		customPots : WMStandardComponents.Panel;
		numericInputs : NumericColorChooser;
		palette : WMPopups.ColorSwatchPanel;
		showColor : ColorPot;

		onColorChosen : WMEvents.EventSource;
		color : LONGINT;

		PROCEDURE & Init*;
		VAR main, pnl : WMStandardComponents.Panel; pot : ColorPot;
		BEGIN
			Init^;
			SetNameAsString(StrColorChooser);
			SetGenerator("WMColorComponents.GenColorChooser");
			(* title *)
			NEW(title); title.bounds.SetHeight(20); title.alignment.Set(WMComponents.AlignTop);
			title.fillColor.Set(0CCCCCCFFH); title.SetCaption("ColorChooser"); AddInternalComponent(title);
			(* main panel *)
			NEW(main); main.bounds.SetWidth(190); main.alignment.Set(WMComponents.AlignLeft); AddInternalComponent(main);
			(* palette *)
			NEW(palette); palette.alignment.Set(WMComponents.AlignTop); palette.bearing.SetHeight(20); main.AddInternalComponent(palette);
			palette.ChosenColorProc := SetColor;
			(* custom pots for temporary color storage *)
			NEW(customPots); customPots.bounds.SetWidth(19); customPots.alignment.Set(WMComponents.AlignLeft); customPots.bearing.SetWidth(20);
			main.AddInternalComponent(customPots);
			NEW(pot); pot.bearing.SetHeight(2); pot.bounds.SetHeight(19); pot.alignment.Set(WMComponents.AlignTop); customPots.AddInternalComponent(pot);
			NEW(pot); pot.bearing.SetHeight(2); pot.bounds.SetHeight(19); pot.alignment.Set(WMComponents.AlignTop); customPots.AddInternalComponent(pot);
			NEW(pot); pot.bearing.SetHeight(2); pot.bounds.SetHeight(19); pot.alignment.Set(WMComponents.AlignTop); customPots.AddInternalComponent(pot);
			NEW(pot); pot.bearing.SetHeight(2); pot.bounds.SetHeight(19); pot.alignment.Set(WMComponents.AlignTop); customPots.AddInternalComponent(pot);
			(* show color button *)
			NEW(pnl); pnl.alignment.Set(WMComponents.AlignLeft); pnl.bounds.SetWidth(75); main.AddInternalComponent(pnl);
			NEW(showColor); showColor.bounds.SetHeight(82); showColor.bounds.SetHeight(82); showColor.alignment.Set(WMComponents.AlignTop);
			showColor.SetExternalColorChangeHandler(ShowColorChangeHandler);
			pnl.AddInternalComponent(showColor);
			(* numeric inputs *)
			NEW(numericInputs); numericInputs.alignment.Set(WMComponents.AlignRight); numericInputs.bounds.SetWidth(60); main.AddInternalComponent(numericInputs);
			numericInputs.SetExternalColorChangeHandler(SetColor2);
			(* views-registration *)
			NEW(onColorChosen, SELF, Strings.NewString("OnColorChosen"), Strings.NewString("Listeners are called if a new color has been chosen"), NIL);
			onColorChosen.Add(showColor.SetColor);
			onColorChosen.Add(numericInputs.SetColor);
			(* model initialization *)
			SetColor(000000FFH);
		END Init;

		PROCEDURE SetColor(color : LONGINT);
		VAR c : Color;
		BEGIN
			SELF.color := color;
			NEW(c); c.value := color;
			onColorChosen.Call(c)
		END SetColor;

		PROCEDURE SetColor2(sender, color : ANY);
		BEGIN
			IF color IS Color THEN
				SetColor(color(Color).value)
			END
		END SetColor2;

		(* plugin-handler for showColor *)
		PROCEDURE ShowColorChangeHandler(sender, color : ANY);
		BEGIN
			showColor.SetColor(sender, color);
			SetColor2(sender, color)
		END ShowColorChangeHandler;

	END ColorChooser;

VAR
	StrNumberInput, StrNumericColorChooser, StrColorPot, StrColorChooser : Strings.String;

(* ----- helpers --------------------------------------- *)

PROCEDURE IsNumber(CONST str : ARRAY OF CHAR) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	i := 0;
	WHILE str[i] # 0X DO
		IF (str[i] < '0') OR (str[i] > '9') THEN RETURN FALSE END;
		INC(i)
	END;
	RETURN TRUE
END IsNumber;

PROCEDURE InitStrings;
BEGIN
	StrNumberInput := Strings.NewString("NumberInput");
	StrNumericColorChooser := Strings.NewString("NumericColorChooser");
	StrColorPot := Strings.NewString("ColorPot");
	StrColorChooser := Strings.NewString("ColorChooser");
END InitStrings;

PROCEDURE GenNumberInput*() : XML.Element;
VAR numberInput :NumberInput;
BEGIN
	NEW(numberInput); RETURN numberInput;
END GenNumberInput;

PROCEDURE GenNumericColorChooser*() : XML.Element;
VAR numericColorChooser : NumericColorChooser;
BEGIN
	NEW(numericColorChooser); RETURN numericColorChooser;
END GenNumericColorChooser;

PROCEDURE GenColorPot*() : XML.Element;
VAR colorPot : ColorPot;
BEGIN
	NEW(colorPot); RETURN colorPot;
END GenColorPot;

PROCEDURE GenColorChooser*() : XML.Element;
VAR colorChooser : ColorChooser;
BEGIN
	NEW(colorChooser); RETURN colorChooser;
END GenColorChooser;

BEGIN
	InitStrings;
END WMColorComponents.
