MODULE WMDiagramComponents;	(** AUTHOR "TF"; PURPOSE "Diagram components"; *)

IMPORT
	Objects, Strings, WMRectangles, WMGraphics, WMEvents, WMProperties, WMStandardComponents,
	WMComponents, Modules, WMGraphicUtilities;

CONST
	(* MultiPointView.style *)
	StyleAuto = 0; 		(* default; StyleAreas if Sum or Max is available, StyleLines otherwise *)
	StyleLines = 1;
	StyleAreas = 2;

	(* DataDescriptor.flags *)
	Hidden* = 0;		(* Don't visualize! *)
	Sum* = 1;			(* This value is the sum of all other values in the same dataset *)
	Maximum* = 2;		(* This value is the maximum that other values in the same dataset can reach *)
	Standalone* =3; 	(* Indicate that this value is not affected by Sum/Maximum of dataset *)

	Invalid = -1;

TYPE

	DataPointModel* = OBJECT
	VAR
		lockedBy : ANY;
		lockLevel : LONGINT;
		viewChanged : BOOLEAN;
		onChanged- : WMEvents.EventSource; (** does not hold the lock, if called *)

		PROCEDURE &New*;
		BEGIN
			NEW(onChanged, SELF, WMComponents.NewString("DataPointModelChanged"), NIL, NIL);
			lockLevel := 0;
		END New;

		(** acquire a read/write lock on the object *)
		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			IF lockedBy = me THEN
				ASSERT(lockLevel # -1);	(* overflow *)
				INC(lockLevel);
			ELSE
				AWAIT(lockedBy = NIL); viewChanged := FALSE;
				lockedBy := me; lockLevel := 1;
			END;
		END Acquire;

		(** release the read/write lock on the object *)
		PROCEDURE Release*;
		VAR hasChanged : BOOLEAN;
		BEGIN
			BEGIN {EXCLUSIVE}
				ASSERT(lockedBy = Objects.ActiveObject(), 3000);
				hasChanged := FALSE;
				DEC(lockLevel);
				IF lockLevel = 0 THEN lockedBy := NIL; hasChanged := viewChanged; END;
			END;
			IF hasChanged THEN onChanged.Call(NIL); END;
		END Release;

	END DataPointModel;

TYPE

	DataDescriptor* = RECORD
		name* : ARRAY 32 OF CHAR;
		unit* : ARRAY 16 OF CHAR;
		color* : LONGINT;
		flags* : SET;
	END;

	DatasetDescriptor* = POINTER TO ARRAY OF DataDescriptor;

	Dataset* = POINTER TO ARRAY OF REAL;
	LongintDataset* = POINTER TO ARRAY OF LONGINT;

	Statistics* = RECORD
		valid- : BOOLEAN;
		cur*, min*, max*, avg*, sum* : Dataset;
		nbrOfSamples- : LONGINT;
	END;

TYPE

	MultiPointModel* = OBJECT(DataPointModel)
	VAR
		descriptor : DatasetDescriptor;

		buffer : POINTER TO ARRAY OF Dataset;
		pos, nofItems, dimensions : LONGINT;
		bufferSize : LONGINT;

		viewSampleCount : LONGINT;

		(* Lifetime statistics - min, max, sum of all value ever received (not just those in buffer) *)
		statistics : BOOLEAN;
		valid : BOOLEAN;
		nbrOfValues : LONGINT;
		cur, min, max, sum : Dataset;

		PROCEDURE &Init*(bufferSize, dimensions : LONGINT);
		VAR i : LONGINT;
		BEGIN
			ASSERT(dimensions >= 1);
			New;
			SELF.bufferSize := bufferSize;
			SELF.dimensions := dimensions;

			(* Initialize buffer *)
			NEW(buffer, bufferSize);
			FOR i := 0 TO bufferSize - 1 DO
				NEW(buffer[i], dimensions);
			END;

			statistics := TRUE; nbrOfValues := 0; valid := FALSE;
			NEW(cur, dimensions); NEW(min, dimensions); NEW(max, dimensions); NEW(sum, dimensions);
		END Init;

		PROCEDURE Reset*;
		VAR i : LONGINT;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			nofItems := 0; pos := 0; viewSampleCount := 0; viewChanged := TRUE;
			(* Reset statistics *)
			IF statistics THEN
				nbrOfValues := 0; valid := FALSE;
				FOR i := 0 TO dimensions-1 DO
					min[i] := MAX(REAL); max[i] := MIN(REAL);
					sum[i] := 0; cur[i] := 0;
				END;
			END;
		END Reset;

		PROCEDURE GetStatistics*(VAR statistics : Statistics);
		VAR i : LONGINT;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			ASSERT(LEN(statistics.cur) = dimensions);
			ASSERT((LEN(statistics.min) = dimensions) & (LEN(statistics.max) = dimensions));
			ASSERT((LEN(statistics.sum) = dimensions) & (LEN(statistics.avg) = dimensions));
			IF valid THEN
				statistics.valid := TRUE;
				statistics.nbrOfSamples := nbrOfValues;
				FOR i := 0 TO dimensions-1 DO
					statistics.cur[i] := cur[i];
					statistics.min[i] := min[i];
					statistics.max[i] := max[i];
					statistics.sum[i] := sum[i];
					statistics.avg[i] := sum[i] / nbrOfValues;
				END;
			ELSE
				statistics.valid := FALSE;
			END;
		END GetStatistics;

		(* Find the max and min value in the model dataset. Model lock must be held *)
		PROCEDURE FindMinMax*(from, len : LONGINT; VAR min, max : REAL);
		VAR bufferIndex, dim : LONGINT; v : REAL; points : Dataset;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			ASSERT((from >= 0) & (len > 0) & (from + len < nofItems));
			min := MAX(REAL); max := MIN(REAL);

			bufferIndex := (pos + bufferSize - nofItems + from) MOD bufferSize;

			WHILE len > 0 DO
				points := buffer[bufferIndex];
				FOR dim := 0 TO dimensions-1 DO
					IF (descriptor = NIL) OR ((descriptor # NIL) & ~(Hidden IN descriptor[dim].flags)) THEN
						v := points[dim];
						min := RMin(min, v); max := RMax(max, v);
					END;
				END;
				bufferIndex := (bufferIndex + 1) MOD bufferSize;
				DEC(len);
			END;
		END FindMinMax;

		(* Find the max and min value in the model dataset for each dimension. Model lock must be held *)
		PROCEDURE FindAllMinMax*(from, len : LONGINT; VAR min, max : REAL);
		VAR bufferIndex, dim : LONGINT; sum : REAL; points : Dataset;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			ASSERT((from >= 0) & (len > 0) & (from + len < nofItems));
			min := MAX(REAL); max := MIN(REAL);

			bufferIndex := (pos + bufferSize - nofItems + from) MOD bufferSize;

			WHILE len > 0 DO
				points := buffer[bufferIndex];

				sum := 0.0;
				FOR dim := 0 TO dimensions-1 DO
					IF (descriptor = NIL) OR ((descriptor # NIL) & ~(Hidden IN descriptor[dim].flags)) THEN
						sum := sum + points[dim];
					END;
				END;
				min := RMin(min, sum);
				max := RMax(max, sum);

				bufferIndex := (bufferIndex + 1) MOD bufferSize;
				DEC(len);
			END;
		END FindAllMinMax;

		PROCEDURE SetDescriptor*(ds : DatasetDescriptor);
		BEGIN
			Acquire; descriptor := ds; Release;
		END SetDescriptor;

		PROCEDURE PutValues*(values : Dataset);
		VAR i : LONGINT; value : REAL;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			ASSERT(LEN(values) = dimensions);
			IF nofItems < bufferSize THEN INC(nofItems) END;
			FOR i := 0 TO dimensions - 1 DO
				buffer[pos][i] := values[i];
			END;
			pos := (pos + 1) MOD bufferSize;
			INC(viewSampleCount);
			viewChanged := TRUE;

			IF statistics THEN
				valid := TRUE; INC(nbrOfValues);
				FOR i := 0 TO dimensions - 1 DO
					value := values[i];
					cur[i] := value;
					IF value < min[i] THEN min[i] := value; END;
					IF value > max[i] THEN max[i] := value; END;
					sum[i] := sum[i] + value;
				END;
			END;
		END PutValues;

		PROCEDURE GetValues*(index : LONGINT; VAR dataset : Dataset);
		VAR dim, bufferIndex : LONGINT;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			ASSERT((dataset # NIL) & (LEN(dataset) = dimensions));
			bufferIndex := (pos + bufferSize - nofItems + index) MOD bufferSize;
			FOR dim := 0 TO dimensions-1 DO
				dataset[dim] := buffer[bufferIndex][dim];
			END;
		END GetValues;

		PROCEDURE GetNofDimensions*() : LONGINT;
		BEGIN (* don't need lock here *)
			RETURN dimensions;
		END GetNofDimensions;

		PROCEDURE GetNofPoints*() : LONGINT;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			RETURN nofItems;
		END GetNofPoints;

	END MultiPointModel;

TYPE

	ExtUpdateHandler* = PROCEDURE {DELEGATE};

TYPE

	MultiPointView* = OBJECT(WMComponents.VisualComponent)
	VAR
		model- : MultiPointModel;

		(* Note: Grid is not rendered when deltaXGrid/deltaXGridSmall are zero *)
		min-, max-, deltax-, deltaXGrid-, deltaXGridSmall-, glassShade-, valueWidth- : WMProperties.Int32Property;
		minI, maxI, deltaxI, deltaXGridI, deltaXGridSmallI, glassShadeI, valueWidthI : LONGINT;

		color-, gridColor- : WMProperties.ColorProperty;
		colorI, gridColorI : LONGINT;

		autoMin-, autoMax-, showValues-: WMProperties.BooleanProperty;
		autoMinI, autoMaxI, showValuesI : BOOLEAN;

		unit- : WMProperties.StringProperty;

		style- : WMProperties.Int32Property;
		styleI : LONGINT;

		extUpdate : ExtUpdateHandler;

		dimensions : LONGINT;

		points : Dataset;
		points0, points1 : LongintDataset;

		PROCEDURE &New*;
		BEGIN
			Init;
			SetNameAsString(StrMultiPointView);
			dimensions := 1; NEW(points0, 1); NEW(points1, 1); NEW(points, 1);
			NEW(model, 1024, 1);
			NEW(min, PrototypeMin, NIL, NIL); properties.Add(min);
			NEW(max, PrototypeMax,  NIL, NIL); properties.Add(max);
			NEW(deltax, PrototypeDeltax,  NIL, NIL); properties.Add(deltax);
			NEW(deltaXGrid, PrototypeDeltaXGrid,  NIL, NIL); properties.Add(deltaXGrid);
			NEW(deltaXGridSmall, PrototypeDeltaXGridSmall,  NIL, NIL); properties.Add(deltaXGridSmall);
			NEW(color, PrototypeColor,  NIL, NIL); properties.Add(color);
			NEW(gridColor, PrototypeGridColor,  NIL, NIL); properties.Add(gridColor);
			NEW(glassShade, PrototypeGlassShade,  NIL, NIL); properties.Add(glassShade);
			NEW(valueWidth, PrototypeValueWidth,  NIL, NIL); properties.Add(valueWidth);
			NEW(autoMin, PrototypeAutoMin,  NIL, NIL); properties.Add(autoMin);
			NEW(autoMax, PrototypeAutoMax,  NIL, NIL); properties.Add(autoMax);
			NEW(showValues, PrototypeShowValues,  NIL, NIL); properties.Add(showValues);
			NEW(unit, PrototypeUnit,  NIL, NIL); properties.Add(unit);
			NEW(style, PrototypeStyle, NIL, NIL); properties.Add(style);
			CacheProperties;
			SetFont(WMGraphics.GetFont("Oberon", 8, {}));
			model.onChanged.Add(Update);
		END New;

		PROCEDURE CacheProperties;
		BEGIN
			minI := min.Get(); maxI := max.Get();
			deltaxI := deltax.Get(); deltaXGridI := deltaXGrid.Get(); deltaXGridSmallI := deltaXGridSmall.Get();
			glassShadeI := glassShade.Get();
			valueWidthI := valueWidth.Get();
			colorI := color.Get(); gridColorI := gridColor.Get();
			autoMinI := autoMin.Get(); autoMaxI := autoMax.Get(); showValuesI := showValues.Get();
			styleI := style.Get();
		END CacheProperties;

		PROCEDURE PropertyChanged(property, data : ANY);
		BEGIN
			IF (property = min) THEN minI := min.Get(); Invalidate;
			ELSIF (property = max) THEN maxI := max.Get(); Invalidate;
			ELSIF (property = deltax) OR (property = deltaXGrid) OR (property = deltaXGridSmall) THEN
				deltaxI := deltax.Get(); deltaXGridI := deltaXGrid.Get(); deltaXGridSmallI := deltaXGridSmall.Get(); Invalidate;
			ELSIF (property = glassShade) THEN glassShadeI := glassShade.Get(); Invalidate;
			ELSIF (property = valueWidth) THEN valueWidthI := valueWidth.Get(); Invalidate;
			ELSIF (property = color) OR (property = gridColor) THEN colorI := color.Get(); gridColorI := gridColor.Get(); Invalidate;
			ELSIF (property = autoMin) OR (property = autoMax) OR (property = showValues) THEN
				autoMinI := autoMin.Get(); autoMaxI := autoMax.Get(); showValuesI := showValues.Get(); Invalidate;
			ELSIF (property = style) THEN
				styleI := style.Get(); Invalidate;
			ELSE
				PropertyChanged^(property, data);
			END;
		END PropertyChanged;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			CacheProperties;
		END Initialize;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			CacheProperties;
		END RecacheProperties;

		PROCEDURE SetExtModel*(model : MultiPointModel);
		BEGIN
			ASSERT(model # NIL);
			Acquire;
			IF model # NIL THEN model.onChanged.Remove(Update); END;
			SELF.model := model;
			SELF.dimensions := model.GetNofDimensions();
			NEW(points0, dimensions);
			NEW(points1, dimensions);
			NEW(points, dimensions);
			model.onChanged.Add(Update);
			Release;
			Invalidate;
		END SetExtModel;

		PROCEDURE SetExtUpdate*(extUpdate : ExtUpdateHandler);
		BEGIN
			Acquire; SELF.extUpdate := extUpdate; Release;
		END SetExtUpdate;

		PROCEDURE Update(sender, data : ANY);
		BEGIN
			IF extUpdate # NIL THEN
				extUpdate();
			ELSE
				Invalidate;
			END;
		END Update;

		PROCEDURE Scale(factor, min : REAL; srcPoints : Dataset; tarPoints : LongintDataset; height, border : LONGINT);
		VAR dim : LONGINT;
		BEGIN
			FOR dim := 0 TO dimensions-1 DO
				tarPoints[dim] := ENTIER(((srcPoints[dim] - min) * factor) * (height - 2 * border));
			END;
		END Scale;

		PROCEDURE DrawLines(canvas : WMGraphics.Canvas; w, h, border : LONGINT; VAR tmin, tmax : REAL);
		VAR
			nofPoints, nofVisible : LONGINT;
			dim, x, index : LONGINT;
			v0, v1 : LONGINT;
			factor : REAL;
		BEGIN
			model.Acquire;
			nofPoints := model.GetNofPoints();
			nofVisible := Strings.Min(nofPoints - 1, w DIV deltaxI + 1);

			IF nofVisible >= 2 THEN
				index := nofPoints - 1;
				model.FindMinMax(index - nofVisible, nofVisible, tmin, tmax);
				IF ~autoMinI THEN tmin := minI; END;
				IF ~autoMaxI THEN tmax := maxI; END;
				IF (tmax - tmin) = 0 THEN factor := 1; ELSE factor := 1 / (tmax - tmin); END;

				model.GetValues(index, points); DEC(index);
				Scale(factor, tmin, points, points0, h, border);

				x := w;
				WHILE (index > 0) & (x >= 0) DO
					FOR dim := 0 TO dimensions-1 DO
						points1[dim] := points0[dim];
					END;

					model.GetValues(index, points);
					Scale(factor, tmin, points, points0, h, border);

					FOR dim := 0 TO dimensions-1 DO
						v0 := points0[dim]; v1 := points1[dim];
						IF (model.descriptor = NIL) THEN
							 canvas.Line(x - deltaxI, (h - border) - v0, x, (h - border) - v1, colorI, WMGraphics.ModeCopy);
						ELSIF ~(Hidden IN model.descriptor[dim].flags) THEN
							 canvas.Line(x - deltaxI, (h - border) - v0, x, (h - border) - v1, model.descriptor[dim].color, WMGraphics.ModeCopy);
						END;
					END;
					x := x - deltaxI;
					DEC(index);
				END;
			END;
			model.Release;
		END DrawLines;

		PROCEDURE DrawAreas(canvas : WMGraphics.Canvas; w, h, border : LONGINT; VAR tmin, tmax : REAL);
		VAR
			nofPoints, nofVisible, nofStandalone : LONGINT;
			dim, index, x, y0, y1, colorLine, color : LONGINT;
			maxSumIdx : LONGINT;
			v0, v1 : LONGINT;
			factor : REAL;
			poly : ARRAY 4 OF WMGraphics.Point2d;
		BEGIN
			model.Acquire;
			nofPoints := model.GetNofPoints();
			nofVisible := Strings.Min(nofPoints - 1, w DIV deltaxI + 1);
			nofStandalone := GetNumberOf(Standalone, 0, MAX(LONGINT), model.descriptor);

			IF nofVisible >= 2 THEN
				maxSumIdx := FindIndexOf(Maximum, model.descriptor);
				IF (maxSumIdx = Invalid) THEN
					maxSumIdx := FindIndexOf(Sum, model.descriptor);
				END;

				index := nofPoints - 1;
				IF (autoMinI OR autoMaxI) THEN
					IF (maxSumIdx # Invalid) THEN
						model.FindMinMax(index - nofVisible, nofVisible, tmin, tmax);
					ELSE
						model.FindAllMinMax(index - nofVisible, nofVisible, tmin, tmax);
					END;
				END;
				IF ~autoMinI THEN tmin := minI; END;
				IF ~autoMaxI THEN tmax := maxI; END;

				(* use min and max for internal computation *)
				IF (tmax - tmin) = 0 THEN factor := 1; ELSE factor := 1 / (tmax - tmin); END;

				model.GetValues(index, points); DEC(index);
				Scale(factor, tmin, points, points0, h, border);

				x := w;
				WHILE (index > 0) & (x >= 0) DO
					FOR dim := 0 TO dimensions-1 DO
						points1[dim] := points0[dim];
					END;
					model.GetValues(index, points);
					Scale(factor, tmin, points, points0, h, border);

					y0 := h - border; y1 := y0;
					FOR dim := 0 TO dimensions-1 DO
						IF (model.descriptor = NIL) OR ({Hidden, Maximum, Sum, Standalone} * model.descriptor[dim].flags = {}) THEN
							v0 := points0[dim]; v1 := points1[dim];
							poly[0].x := x - deltaxI;
							poly[0].y := y0;
							poly[1].x := x - deltaxI;
							poly[1].y := y0 - v0;
							poly[2].x := x;
							poly[2].y := y1 - v1;
							poly[3].x := x;
							poly[3].y := y1;
							IF (model.descriptor = NIL) THEN
								colorLine := colorI;
							ELSE
								colorLine := model.descriptor[dim].color;
							END;
							color := (colorLine - (colorLine MOD 100H)) + 60H;
							canvas.FillPolygonFlat(poly, 4, color, WMGraphics.ModeSrcOverDst);
							canvas.Line(x - deltaxI, y0 - v0, x, y1 - v1, colorLine, WMGraphics.ModeCopy);
							y0 := y0 - v0;
							y1 := y1 - v1;
						END;
					END;
					IF (maxSumIdx # Invalid) THEN
						ASSERT(model.descriptor # NIL);
						IF ~(Hidden IN model.descriptor[maxSumIdx].flags) THEN
							v0 := points0[maxSumIdx]; v1 := points1[maxSumIdx];
							IF (Sum IN model.descriptor[maxSumIdx].flags) THEN
								canvas.Line(x - deltaxI, y0 , x, y1, model.descriptor[maxSumIdx].color, WMGraphics.ModeCopy);
							ELSE (* Maximum *)
								poly[0].x := x - deltaxI;
								poly[0].y := y0;
								poly[1].x := x - deltaxI;
								poly[1].y := h - border - v0;
								poly[2].x := x;
								poly[2].y := h - border - v1;
								poly[3].x := x;
								poly[3].y := y1;
								colorLine := model.descriptor[maxSumIdx].color;
								color := (colorLine - (colorLine MOD 100H)) + 70H;
								canvas.FillPolygonFlat(poly, 4, color, WMGraphics.ModeSrcOverDst);
								canvas.Line(x - deltaxI, h - border - v0 , x, h - border - v1, model.descriptor[maxSumIdx].color, WMGraphics.ModeCopy);
							END;
						END;
					END;
					(* Standalone values are independet of other values in the same dataset and area plotted as curves in front of areas *)
					IF (nofStandalone > 0) THEN
						FOR dim := 0 TO dimensions-1 DO
							v0 := points0[dim]; v1 := points1[dim];
							IF (Standalone IN model.descriptor[dim].flags) THEN
								IF (model.descriptor # NIL) THEN
									colorLine := colorI;
								ELSE
									colorLine := model.descriptor[dim].color;
								END;
								canvas.Line(x - deltaxI, h - border - v0, x, h - border - v1, colorLine, WMGraphics.ModeCopy);
							END;
						END;
					END;
					x := x - deltaxI;
					DEC(index);
				END;
			END;
			model.Release;
		END DrawAreas;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			w, h, yborder, color, t, virtp   : LONGINT;
			mode : LONGINT;
			tmin, tmax : REAL;
			str : ARRAY 16 OF CHAR;
			s : Strings.String;
		BEGIN
			canvas.SetFont(GetFont());
			yborder := 5;
			IF fillColor.Get() # 0 THEN canvas.Fill(GetClientRect(), fillColor.Get(), WMGraphics.ModeCopy); END;
			color := WMGraphicUtilities.ScaleColor(gridColorI, 80H);
			w := bounds.GetWidth(); h := bounds.GetHeight();
			IF showValuesI THEN DEC(w, valueWidthI); END;
			canvas.Line(0, yborder, w, yborder, color, WMGraphics.ModeSrcOverDst);
			canvas.Line(0, h - yborder, w, h - yborder, color, WMGraphics.ModeSrcOverDst);

			virtp := model.viewSampleCount;

			IF deltaXGridSmallI > 0 THEN
				t := w -  (virtp MOD deltaXGridSmallI) * deltaxI;
				WHILE t > 0 DO
					canvas.Line(t, 0, t, h, color, WMGraphics.ModeSrcOverDst);
					DEC(t, deltaxI* deltaXGridSmallI);
				END;
			END;

			IF deltaXGridI > 0 THEN
				t := w - (virtp MOD deltaXGridI) * deltaxI;
				IF virtp MOD deltaXGridI = 0 THEN model.viewSampleCount := 0; END;
				WHILE t > 0 DO
					canvas.Line(t, 0, t, h, gridColorI, WMGraphics.ModeSrcOverDst);
					DEC(t, deltaxI* deltaXGridI);
				END;
			END;

			mode := styleI;
			IF (styleI = StyleAuto) THEN
				IF (GetNumberOf(Maximum, 0, MAX(LONGINT), model.descriptor) > 0) OR (GetNumberOf(Sum, 0, MAX(LONGINT), model.descriptor) > 0) THEN
					mode := StyleAreas;
				ELSE
					mode := StyleLines;
				END;
			END;

			CASE mode OF
				|StyleLines: DrawLines(canvas, w, h, yborder, tmin, tmax);
				|StyleAreas: DrawAreas(canvas, w, h, yborder, tmin, tmax);
			ELSE
				DrawLines(canvas, w, h, yborder, tmin, tmax);
			END;

			IF showValuesI THEN
				canvas.Fill(WMRectangles.MakeRect(w, 0, w + 4, h), 080H, WMGraphics.ModeSrcOverDst);
				canvas.SetColor(colorI);
				Strings.FloatToStr(tmax, 0, 1, 0, str); canvas.DrawString(w + 5, 8 + 5, str);
				Strings.FloatToStr(tmin, 0, 1, 0, str); canvas.DrawString(w + 5, h - 5, str);
				s := unit.Get();
				IF s # NIL THEN canvas.DrawString(w + 10, h DIV 2 + 4, s^); END;
			END;
			IF glassShadeI # 0 THEN
				WMGraphicUtilities.RectGlassShade(canvas, GetClientRect(), glassShadeI, FALSE);
			END;
		END DrawBackground;

		PROCEDURE Finalize;
		BEGIN
			IF model # NIL THEN model.onChanged.Remove(Update); END;
			Finalize^;
		END Finalize;

	END MultiPointView;

TYPE

	(** Graphical represenation of a dataset descriptor *)
	DescriptorView* = OBJECT (WMComponents.VisualComponent)
	VAR
		descriptor : DatasetDescriptor;

		names, colors : POINTER TO ARRAY OF WMStandardComponents.Label;
		checkboxes : POINTER TO ARRAY OF WMStandardComponents.Checkbox;

		checkAllBtn, checkNoneBtn : WMStandardComponents.Button;

		(** Optimum width and height *)
		optWidth-, optHeight- : LONGINT;

		(** onClick handler called by each checkbox *)
		PROCEDURE HandleClick(sender, data : ANY);
		VAR i, state : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(checkboxes)-1 DO
				state := checkboxes[i].state.Get();
				IF (state = WMStandardComponents.Checked) THEN
					EXCL(descriptor[i].flags, Hidden);
				ELSE
					INCL(descriptor[i].flags, Hidden);
				END;
			END;
		END HandleClick;

		PROCEDURE HandleButton(sender, data : ANY);
		VAR i : LONGINT;
		BEGIN
			IF sender = checkAllBtn THEN
				FOR i := 0 TO LEN(checkboxes)-1 DO
					EXCL(descriptor[i].flags, Hidden);
					checkboxes[i].state.Set(WMStandardComponents.Checked);
				END;
			ELSIF sender = checkNoneBtn THEN
				FOR i := 0 TO LEN(checkboxes)-1 DO
					INCL(descriptor[i].flags, Hidden);
					checkboxes[i].state.Set(WMStandardComponents.Unchecked);
				END;
			ELSE
			END;
		END HandleButton;

		PROCEDURE &New*(ds : DatasetDescriptor);
		VAR i : LONGINT; panel : WMStandardComponents.Panel;
		BEGIN
			ASSERT((ds # NIL) & (LEN(ds) >=1));
			descriptor := ds;
			Init;
			SetNameAsString(StrDatasetDescriptorView);
			NEW(names, LEN(ds));
			NEW(colors, LEN(ds));
			NEW(checkboxes, LEN(ds));
			optWidth := 200; optHeight := LEN(ds) * 20;
			FOR i := 0 TO LEN(ds)-1 DO
				NEW(panel);
				panel.alignment.Set(WMComponents.AlignTop); panel.bounds.SetHeight(20);
				panel.fillColor.Set(WMGraphics.White);

				NEW(checkboxes[i]);
				checkboxes[i].alignment.Set(WMComponents.AlignLeft); checkboxes[i].bounds.SetExtents(20, 20);
				checkboxes[i].fillColor.Set(WMGraphics.White);
				checkboxes[i].onClick.Add(HandleClick);
				IF (Hidden IN ds[i].flags) THEN checkboxes[i].state.Set(WMStandardComponents.Unchecked);
				ELSE checkboxes[i].state.Set(WMStandardComponents.Checked);
				END;
				panel.AddInternalComponent(checkboxes[i]);

				NEW(colors[i]);
				colors[i].alignment.Set(WMComponents.AlignLeft); colors[i].bounds.SetWidth(40);
				colors[i].fillColor.Set(WMGraphics.Black);
				colors[i].caption.SetAOC(" __________ "); colors[i].textColor.Set(ds[i].color);
				panel.AddInternalComponent(colors[i]);

				NEW(names[i]);
				names[i].alignment.Set(WMComponents.AlignClient);
				names[i].fillColor.Set(WMGraphics.White);
				names[i].caption.SetAOC(ds[i].name);
				panel.AddInternalComponent(names[i]);

				AddInternalComponent(panel);
			END;

			NEW(panel);
			panel.alignment.Set(WMComponents.AlignBottom); panel.bounds.SetHeight(20);
			panel.fillColor.Set(WMGraphics.White);
			AddInternalComponent(panel);

			NEW(checkAllBtn);
			checkAllBtn.alignment.Set(WMComponents.AlignLeft); checkAllBtn.bounds.SetWidth(optWidth DIV 2);
			checkAllBtn.caption.SetAOC("ALL");
			checkAllBtn.onClick.Add(HandleButton);
			panel.AddInternalComponent(checkAllBtn);

			NEW(checkNoneBtn);
			checkNoneBtn.alignment.Set(WMComponents.AlignClient);
			checkNoneBtn.caption.SetAOC("NONE");
			checkNoneBtn.onClick.Add(HandleButton);
			panel.AddInternalComponent(checkNoneBtn);
		END New;

	END DescriptorView;

TYPE

	(* coordinate system as preparation for more flexible handling of plots *)
	CoordinateSystem= RECORD
		l,t,r,b: LONGREAL;
	END;

	BarChart* = OBJECT(WMComponents.VisualComponent)
	VAR
		barColor-,lineColor- ,textColor-,backgroundColor-: WMProperties.ColorProperty;

		width-,offset-: LONGREAL; (* width and offset of histogram, initialized to width=1, offset = -0.5  *)
		numberData-: LONGINT; (* number of box plot data *)
		heights-: POINTER TO ARRAY OF LONGREAL; (* bin height *)
		labels-: POINTER TO ARRAY OF Strings.String; (* bin label (if any) *)
		colors- : POINTER TO ARRAY OF LONGINT;
		c: CoordinateSystem;
		vertical: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(barColor, NIL, NIL, NIL); properties.Add(barColor);
			barColor.Set(101010A0H);

			NEW(lineColor, NIL, NIL, NIL); properties.Add(lineColor);
			lineColor.Set(0FFH);

			NEW(textColor, NIL, NIL, NIL); properties.Add(textColor);
			textColor.Set(LONGINT(0FF0000FFH));

			NEW(backgroundColor, NIL, NIL, NIL); properties.Add(backgroundColor);
			backgroundColor.Set(LONGINT(0FFFF00FFH));

			heights := NIL; labels := NIL; colors := NIL;
			width := 1; offset := -0.5; numberData := 0;
			c.l := -1; c.t := -1; c.r := 2; c.b := 2;
		END Init;

		PROCEDURE UpdateCoordinateSystem;
		BEGIN
			IF vertical THEN
				c.l := -1; c.r := numberData;
				c.b := 0; c.t := 1;
			ELSE
				c.l := 0; c.r := 1;
				c.b := -1; c.t := numberData;
			END;
		END UpdateCoordinateSystem;

		PROCEDURE SetData*(CONST heights: ARRAY OF LONGREAL; numberData: LONGINT);
		VAR i: LONGINT;
		BEGIN
			IF LEN(heights) < numberData THEN RETURN END;
			Acquire();
			SELF.numberData := numberData;
			NEW(SELF.heights,numberData);
			FOR i := 0 TO numberData-1 DO
				SELF.heights[i] := heights[i];
			END;
			IF (labels # NIL) & (LEN(labels) # numberData) THEN labels := NIL END;
			UpdateCoordinateSystem;
			Release();
			Invalidate;
		END SetData;

		PROCEDURE SetLabels*(CONST labels: ARRAY OF Strings.String);
		VAR i: LONGINT;
		BEGIN
			Acquire();
			IF LEN(labels) < numberData THEN RETURN END;
			NEW(SELF.labels,numberData);
			FOR i := 0 TO numberData-1 DO
				SELF.labels[i] := labels[i]
			END;
			Release();
			Invalidate;
		END SetLabels;

		PROCEDURE SetColors*(CONST colors: ARRAY OF LONGINT);
		VAR i: LONGINT;
		BEGIN
			Acquire();
			IF LEN(colors) < numberData THEN RETURN END;
			NEW(SELF.colors, numberData);
			FOR i := 0 TO numberData-1 DO
				SELF.colors[i] := colors[i]
			END;
			Release();
			Invalidate;
		END SetColors;

		PROCEDURE SetWidthOffset*(width,offset: LONGREAL);
		BEGIN
			Acquire();
			SELF.width := width;
			SELF.offset := offset;
			Release();
			Invalidate;
		END SetWidthOffset;

		PROCEDURE SetVertical*(vertical: BOOLEAN);
		BEGIN
			Acquire;
			SELF.vertical := vertical;
			UpdateCoordinateSystem;
			Release;
			Invalidate;
		END SetVertical;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = textColor) OR (property = barColor) OR (property = lineColor) OR (property = backgroundColor) THEN Invalidate
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR boundary,rect: WMRectangles.Rectangle; i: LONGINT;

			PROCEDURE Point2dToPoint(xr,yr: LONGREAL; VAR x,y: LONGINT);
			BEGIN
				x := ENTIER(boundary.l + (xr-c.l)/(c.r-c.l) * (boundary.r-boundary.l) +0.5);
				y := ENTIER(boundary.b + (yr-c.b)/(c.t-c.b) * (boundary.t-boundary.b) +0.5);
			END Point2dToPoint;

			PROCEDURE Rect2dToRect(xr,yr,wr,hr: LONGREAL; VAR rect: WMRectangles.Rectangle);
			BEGIN
				Point2dToPoint(xr,yr,rect.l,rect.b);
				Point2dToPoint(xr+wr,yr+hr,rect.r,rect.t);
			END Rect2dToRect;

		BEGIN
			DrawBackground^(canvas);
			boundary := GetClientRect();
			canvas.Fill(boundary,backgroundColor.Get(),WMGraphics.ModeSrcOverDst);

			canvas.SetFont(WMGraphics.GetFont("Oberon", 10, {}));
			FOR i := 0 TO numberData-1 DO
				IF vertical THEN
					Rect2dToRect(offset+i*width,0,width,heights[i],rect);
				ELSE
					Rect2dToRect(0,offset+i*width,heights[i],width,rect);
				END;
				IF (colors # NIL) THEN
					canvas.Fill(rect,colors[i],WMGraphics.ModeSrcOverDst);
				ELSE
					canvas.Fill(rect,barColor.Get(),WMGraphics.ModeSrcOverDst);
				END;
				canvas.Line(rect.l,rect.t,rect.r,rect.t,lineColor.Get(),WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l,rect.b,rect.r,rect.b,lineColor.Get(),WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.l,rect.t,rect.l,rect.b,lineColor.Get(),WMGraphics.ModeSrcOverDst);
				canvas.Line(rect.r,rect.t,rect.r,rect.b,lineColor.Get(),WMGraphics.ModeSrcOverDst);
			END;

			IF ~vertical & (labels # NIL) THEN (* labels would better be organized as separate panel but for the time being ... *)
				FOR i := 0 TO numberData-1 DO
					IF  (labels[i] # NIL) THEN
						canvas.SetColor(textColor.Get());
						Rect2dToRect(0,offset+i*width,1,width,rect);
						WMGraphics.DrawStringInRect(canvas, rect, FALSE, WMGraphics.AlignRight, WMGraphics.AlignCenter, labels[i]^)
					END;
				END;
			END;

		END DrawBackground;

	END BarChart;


VAR
	PrototypeUnit : WMProperties.StringProperty;
	PrototypeMin, PrototypeMax, PrototypeDeltax, PrototypeDeltaXGrid, PrototypeDeltaXGridSmall,
	PrototypeGlassShade, PrototypeValueWidth : WMProperties.Int32Property;
	PrototypeColor, PrototypeGridColor : WMProperties.ColorProperty;
	PrototypeAutoMin, PrototypeAutoMax, PrototypeShowValues  : WMProperties.BooleanProperty;
	PrototypeStyle : WMProperties.Int32Property;

	StrMultiPointView, StrDatasetDescriptorView : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrMultiPointView := Strings.NewString("MultiPointView");
	StrDatasetDescriptorView := Strings.NewString("DatasetDescriptorView");
END InitStrings;

PROCEDURE InitProtoTypes;

	PROCEDURE S(CONST s : ARRAY OF CHAR) : Strings.String;
	BEGIN
		RETURN Strings.NewString(s);
	END S;

BEGIN
	NEW(PrototypeUnit, NIL, S("Unit"), S("unit string for the diagram, if any"));
	NEW(PrototypeMin, NIL, S("Min"), S("minimum to assume if not autoMin")); PrototypeMin.Set(0);
	NEW(PrototypeMax, NIL, S("Max"), S("maximum to assume if not autoMax")); PrototypeMax.Set(100);
	NEW(PrototypeDeltax, NIL, S("Deltax"), S("pixel between samples")); PrototypeDeltax.Set(2);
	NEW(PrototypeDeltaXGrid, NIL, S("DeltaXGrid"), S("samples between separator lines")); PrototypeDeltaXGrid.Set(60);
	NEW(PrototypeDeltaXGridSmall, NIL, S("DeltaXGridSmall"),
		S("samples between small separator lines")); PrototypeDeltaXGridSmall.Set(10);

	NEW(PrototypeColor, NIL, S("Color"), S("color of the graph")); PrototypeColor.Set(0CC00FFH);
	NEW(PrototypeGridColor, NIL, S("GridColor"), S("color of the grid")); PrototypeGridColor.Set(LONGINT(0FFCC00FFH));

	NEW(PrototypeGlassShade, NIL, S("GlassShade"), NIL); PrototypeGlassShade.Set(8);
	NEW(PrototypeValueWidth, NIL, S("ValueWidth"), NIL); PrototypeValueWidth.Set(50);
	NEW(PrototypeAutoMin, NIL, S("AutoMin"), NIL); PrototypeAutoMin.Set(TRUE);
	NEW(PrototypeAutoMax, NIL, S("AutoMax"), NIL); PrototypeAutoMax.Set(TRUE);
	NEW(PrototypeShowValues, NIL, S("ShowValues"), NIL); PrototypeShowValues.Set(FALSE);
	NEW(PrototypeStyle, NIL, S("Style"), NIL); PrototypeStyle.Set(StyleAuto);
END InitProtoTypes;

PROCEDURE FindIndexOf*(flag : LONGINT; ds : DatasetDescriptor) : LONGINT;
VAR index, length : LONGINT;
BEGIN
	IF (ds # NIL) THEN
		index := 0; length := LEN(ds);
		WHILE (index < length) & (~(flag IN ds[index].flags) OR (Hidden IN ds[index].flags)) DO INC(index); END;
		IF (index = length) THEN index := Invalid; END;
	ELSE
		index := Invalid;
	END;
	RETURN index;
END FindIndexOf;

PROCEDURE GetNumberOf*(flag : LONGINT; startIndex, endIndex : LONGINT; ds : DatasetDescriptor) : LONGINT;
VAR result, i : LONGINT;
BEGIN
	result := 0;
	IF (ds # NIL) & (0 <= startIndex) & (startIndex <= endIndex) & ((endIndex < LEN(ds)) OR (endIndex = MAX(LONGINT))) THEN
		IF (endIndex = MAX(LONGINT)) THEN endIndex := LEN(ds) - 1; END;
		FOR i := startIndex TO endIndex DO
			IF (flag IN ds[i].flags) THEN INC(result); END;
		END;
	END;
	RETURN result;
END GetNumberOf;

PROCEDURE ClearFlag*(flag : LONGINT; ds : DatasetDescriptor);
VAR i : LONGINT;
BEGIN
	IF (ds # NIL) THEN
		FOR i := 0 TO LEN(ds)-1 DO
			EXCL(ds[i].flags, flag);
		END;
	END;
END ClearFlag;

PROCEDURE RMin(a, b : REAL) : REAL;
BEGIN
	IF a < b THEN RETURN a; ELSE RETURN b; END;
END RMin;

PROCEDURE RMax(a, b : REAL) : REAL;
BEGIN
	IF a> b THEN RETURN a; ELSE RETURN b; END;
END RMax;

PROCEDURE CopyDatasetDescriptor*(ds : DatasetDescriptor) : DatasetDescriptor;
VAR result : DatasetDescriptor; i : LONGINT;
BEGIN
	IF ds # NIL THEN
		NEW(result, LEN(ds));
		FOR i := 0 TO LEN(ds)-1 DO
			COPY(ds[i].name, result[i].name);
			result[i].color := ds[i].color;
			result[i].flags := ds[i].flags;
		END;
	END;
	RETURN result;
END CopyDatasetDescriptor;

PROCEDURE Cleanup;
END Cleanup;

BEGIN
	InitStrings;
	InitProtoTypes;
	Modules.InstallTermHandler(Cleanup);
END WMDiagramComponents.

SystemTools.Free WMDiagramComponents ~


 