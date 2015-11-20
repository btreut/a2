MODULE WMProgressComponents; (** AUTHOR "staubesv"; PURPOSE "Progress indication components and windows"; *)

IMPORT
	KernelLog, Strings, XML, Types, Models, WMGraphicUtilities, WMComponents, WMProperties, WMRectangles, WMGraphics;

TYPE

	ProgressBar* = OBJECT(WMComponents.VisualComponent)
	VAR
		min-, max- : WMProperties.Int32Property;

		current : LONGINT;

		model- : WMProperties.ReferenceProperty;
		modelI : Models.Model;

		isVertical- : WMProperties.BooleanProperty;
		color-: WMProperties.ColorProperty;
		borderColor-: WMProperties.ColorProperty;
		textColor- : WMProperties.ColorProperty;

		showPercents- : WMProperties.BooleanProperty; (* Default: TRUE *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			takesFocus.Set(FALSE);
			NEW(isVertical, PrototypePbIsVertical, NIL, NIL); properties.Add(isVertical);
			NEW(color, PrototypePbColor, NIL, NIL); properties.Add(color);
			NEW(borderColor, PrototypePbBorderColor, NIL, NIL); properties.Add(borderColor);
			NEW(min, PrototypePbMin, NIL, NIL); properties.Add(min);
			NEW(max, PrototypePbMax, NIL, NIL); properties.Add(max);
			current := 0;
			NEW(model, PrototypePbModel, NIL, NIL); properties.Add(model);
			modelI := NIL;
			NEW(showPercents, PrototypePbShowPercents, NIL, NIL); properties.Add(showPercents);
			NEW(textColor, PrototypePbTextColor, NIL, NIL); properties.Add(textColor);
			SetNameAsString(StrProgressBar);
			SetGenerator("WMProgressComponents.GenProgressBar");
		END Init;

		PROCEDURE SetRange*(min, max : LONGINT);
		BEGIN
			Acquire;
			SELF.min.Set(min);
			SELF.max.Set(max);
			Release;
			Invalidate;
		END SetRange;

		PROCEDURE SetCurrent*(current : LONGINT);
		BEGIN
			SetInternal(current, TRUE);
		END SetCurrent;

		PROCEDURE SetInternal(current : LONGINT; updateModel : BOOLEAN);
		VAR changed : BOOLEAN; min, max : LONGINT;
		BEGIN
			min := SELF.min.Get(); max := SELF.max.Get();
			IF (current < min) THEN current := min; ELSIF (current > max) THEN current := max; END;
			Acquire;
			IF (current # SELF.current) THEN
				SELF.current := current; changed := TRUE;
			END;
			Release;
			IF changed THEN
				IF updateModel THEN UpdateModel(current); END;
				Invalidate;
			END;
		END SetInternal;

		PROCEDURE IncPos*;
		VAR max : LONGINT;
		BEGIN
			max := SELF.max.Get();
			Acquire;
			INC(current); IF current > max THEN current := max; END;
			Release;
			Invalidate;
		END IncPos;

		PROCEDURE RecacheProperties;
		VAR any : ANY;
		BEGIN
			RecacheProperties^;
			any := model.Get();
			IF (any # NIL) & (any IS Models.Model) & (any # modelI) THEN
				modelI := any (Models.Model);
				modelI.onChanged.Add(ModelChanged);
				ModelChanged(NIL, NIL);
			ELSIF (modelI # NIL) THEN
				modelI.onChanged.Remove(ModelChanged);
				modelI := NIL;
			END;
		END RecacheProperties;

		PROCEDURE UpdateModel(value : LONGINT);
		VAR integer : Types.Integer; res : LONGINT; model : Models.Model;
		BEGIN
			model := modelI;
			IF (model # NIL) THEN
				integer.value := value;
				model.SetGeneric(integer, res); (* ignore res *)
			END;
		END UpdateModel;

		PROCEDURE ModelChanged(sender, data : ANY);
		VAR integer : Types.Integer; res : LONGINT;
		BEGIN
			Acquire;
			modelI.GetGeneric(integer, res);
			IF (res = Models.Ok) THEN
				SetInternal(integer.value, TRUE);
			ELSE
				KernelLog.String("WMProgressComponents.ModelChanged.res = "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
			Release;
		END ModelChanged;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = min) OR (property = max) THEN
				Invalidate;
			ELSIF (property = color) OR (property = borderColor) OR (property = textColor) OR
				 	(property = showPercents) OR (property = isVertical) THEN
				Invalidate;
			ELSIF (property = model) THEN
				RecacheProperties;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR
			rect: WMRectangles.Rectangle;
			width: LONGINT;
			string : ARRAY 32 OF CHAR;
			min, max, cur, percent, color : LONGINT;
			isVertical : BOOLEAN;
		BEGIN
			min := SELF.min.Get();
			max := SELF.max.Get();
			cur := current;
			IF (cur > max) THEN cur := max; ELSIF (cur < min) THEN cur := min; END;
			isVertical := SELF.isVertical.Get();

			DrawBackground^(canvas);
			IF max > min THEN
				IF ~isVertical THEN
					width := ENTIER((cur - min) / (max - min) * bounds.GetWidth());
					rect := WMRectangles.MakeRect(0, 0, width, bounds.GetHeight());
				ELSE
					width := ENTIER((cur - min) / (max - min) * bounds.GetHeight());
					rect := WMRectangles.MakeRect(0, bounds.GetHeight() - width, bounds.GetWidth(), bounds.GetHeight());
				END;
				canvas.Fill(rect, SELF.color.Get(), WMGraphics.ModeSrcOverDst);
			END;

			rect := GetClientRect();

			IF ~isVertical THEN
				rect.l := width;
			ELSE
				rect.t := rect.b + width;
			END;

			canvas.Fill(rect, fillColor.Get(), WMGraphics.ModeSrcOverDst);

			color := borderColor.Get();
			IF (color # 0) THEN
				WMGraphicUtilities.DrawRect(canvas, GetClientRect(), color, WMGraphics.ModeSrcOverDst);
			END;

			IF showPercents.Get() & (max - min > 0) THEN
				percent := ENTIER(100 * (cur - min) / (max - min)); Strings.IntToStr(percent, string); Strings.Append(string, "%");
				canvas.SetColor(textColor.Get());
				WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, string)
			END;
		END DrawBackground;

	END ProgressBar;

VAR

	(** ProgressBar property prototypes *)
	PrototypePbMin*, PrototypePbMax*: WMProperties.Int32Property;
	PrototypePbModel* : WMProperties.ReferenceProperty;
	PrototypePbIsVertical* : WMProperties.BooleanProperty;
	PrototypePbColor*, PrototypePbBorderColor* : WMProperties.ColorProperty;
	PrototypePbShowPercents* : WMProperties.BooleanProperty;
	PrototypePbTextColor* : WMProperties.ColorProperty;

	StrProgressBar : Strings.String;

PROCEDURE GenProgressBar*() : XML.Element;
VAR pb : ProgressBar;
BEGIN NEW(pb); RETURN pb
END GenProgressBar;

PROCEDURE InitPrototypes;
VAR plProgressBar : WMProperties.PropertyList;
BEGIN
	(* ProgressBar properties *)
	NEW(plProgressBar); WMComponents.propertyListList.Add("ProgressBar", plProgressBar);
	(* colors *)
	NEW(PrototypePbIsVertical, NIL, Strings.NewString("IsVertical"), Strings.NewString("Vertical progress bar?"));
	PrototypePbIsVertical.Set(FALSE);
	NEW(PrototypePbBorderColor, NIL, Strings.NewString("BorderColor"), Strings.NewString("Progressbar border color")); plProgressBar.Add(PrototypePbBorderColor);
	PrototypePbBorderColor.Set(WMGraphics.White);
	NEW(PrototypePbColor, NIL, Strings.NewString("Color"), Strings.NewString("Progressbar color")); plProgressBar.Add(PrototypePbColor);
	PrototypePbColor.Set(WMGraphics.Blue);
	NEW(PrototypePbTextColor, NIL, Strings.NewString("TextColor"), Strings.NewString("Progressbar text color")); plProgressBar.Add(PrototypePbTextColor);
	PrototypePbTextColor.Set(WMGraphics.White);
	(* position *)
	NEW(PrototypePbMin, NIL, Strings.NewString("Min"), Strings.NewString("Minimum position"));
	PrototypePbMin.Set(0);
	NEW(PrototypePbMax, NIL, Strings.NewString("Max"), Strings.NewString("Maximum position"));
	PrototypePbMax.Set(100);
	NEW(PrototypePbModel, NIL, Strings.NewString("Model"), Strings.NewString("Model")); PrototypePbModel.Set(NIL);
	(* other *)
	NEW(PrototypePbShowPercents, NIL, Strings.NewString("ShowPercents"), Strings.NewString("Should the progress also be displayed as text")); plProgressBar.Add(PrototypePbShowPercents);
	PrototypePbShowPercents.Set(TRUE);
END InitPrototypes;

BEGIN
	StrProgressBar := Strings.NewString("ProgressBar");
	InitPrototypes;
END WMProgressComponents.
