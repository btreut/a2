MODULE WMPerfMonComponents; (** AUTHOR "staubesv"; PURPOSE "Components used by the Performance Monitor application"; *)

IMPORT
	Plugins := WMPerfMonPlugins,
	Streams, Modules, Strings, KernelLog,
	WMRestorable, WMMessages, WMProperties,
	WMWindowManager, XML, WMComponents, WMStandardComponents, WMDiagramComponents,
	WMGrids, WMStringGrids, WMEditors, WMRectangles, WMGraphics, WMEvents;

CONST

	(** View types *)
	UnknownView* = 0;
	GraphView* = 1;
	GridView* = 2;
	ChartView* = 3;

	(* Default width and height of plugin windows *)
	DefaultPwWidth = 600; DefaultPwHeight = 200;

	(* If smaller than this size, the plugin windows will be scaled *)
	MinPwWidth = 200; MinPwHeight = 100;

	Tab = 9X;

	BgFillColor* = 0444444FFH;
	TextColor* = WMGraphics.White;
	LineHeight* = 20;
	ButtonWidth* = 80;
	PerfViewFillColor = 0444444FFH;
	PerfViewColor = LONGINT(0FF0000FFH);

	UseSkinColors* = FALSE;

TYPE

	PluginContainer* =  OBJECT(WMComponents.VisualComponent)
	VAR
		pluginViews : PluginView;
		nbrOfPlugins : LONGINT;

		PROCEDURE SetPluginHeights;
		VAR p : PluginView; height, h : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			IF pluginViews # NIL THEN
				rect := bounds.Get(); h := rect.b - rect.t;
				height := h DIV nbrOfPlugins ;
				p := pluginViews; WHILE p # NIL DO p.bounds.SetHeight(height); p := p.next; END;
				pluginViews.bounds.SetHeight(height + (h MOD nbrOfPlugins));
			END;
		END SetPluginHeights;

		PROCEDURE Resized;
		BEGIN
			SetPluginHeights;
			Resized^;
		END Resized;

		PROCEDURE AlignSubComponents;
		BEGIN
			SetPluginHeights;
			AlignSubComponents^;
		END AlignSubComponents;

		(* Only used in LocatePlugins! *)
		PROCEDURE AddPlugin*(plugin : Plugins.Plugin; viewType : LONGINT);
		VAR pv : PluginView; graphView : PluginGraphView; gridView : PluginGridView;
		BEGIN
			ASSERT(plugin # NIL);
			ASSERT((viewType = GraphView) OR (viewType = GridView));
			IF viewType = GraphView THEN
				NEW(graphView, plugin); pv := graphView;
			ELSE
				NEW(gridView, plugin); pv := gridView;
			END;
			pv.alignment.Set(WMComponents.AlignTop);
			pv.next := pluginViews; pluginViews := pv;
			INC(nbrOfPlugins);
			AddContent(pv);
		END AddPlugin;

		(** Returns FALSE if no plugins found *)
		PROCEDURE LocatePlugins*() : BOOLEAN;
		BEGIN
			HALT(301); RETURN FALSE; (* abstract *)
		END LocatePlugins;

		PROCEDURE &Init*;
		VAR l : WMStandardComponents.Label;
		BEGIN
			Init^;
			IF ~LocatePlugins() THEN
				l := NewLabel("No plugins found.", WMComponents.AlignClient, 0, 0);
				l.alignH.Set(WMGraphics.AlignCenter); l.alignV.Set(WMGraphics.AlignCenter);
				AddContent(l);
			END;
			SetNameAsString(StrPluginContainer);
		END Init;

	END PluginContainer;

TYPE

	UpdateInfo = RECORD
		events : SET;
		perf : REAL;
		sampleInterval, sampleBufferSize, screenInterval : LONGINT;
	END;

	(* Displays a list of all plugins registered at Updater. The user may select a plugin and open a window for it *)
	SelectionComponent* = OBJECT (WMComponents.VisualComponent)
	VAR
		openGraphBtn, openGridBtn, openChartBtn, refreshBtn : WMStandardComponents.Button;

		grid : WMStringGrids.StringGrid;
		spacings : WMGrids.Spacings;

		applyBtn, clearBtn : WMStandardComponents.Button;
		sampleIntervalEditor, sampleBufferSizeEditor, screenIntervalEditor : WMEditors.TextField;
		cpuTimeLabel : Indicator;

		updateInfo, synchronizedUpdateInfo : UpdateInfo;
		w : Streams.StringWriter;
		alive, dead, update : BOOLEAN;

		PROCEDURE Resized;
		VAR sum, w, i : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			rect := bounds.Get(); w := rect.r - rect.l;
			FOR i := 0 TO LEN(spacings)-1 DO sum := sum + spacings[i]; END;
			IF w > sum THEN
				grid.Acquire;
				grid.model.Acquire;
				spacings[1] := spacings[1] + (w - sum) DIV 2;
				spacings[2] := spacings[2] + (w - sum) DIV 2 + (w - sum) MOD 2;
				grid.model.Release;
				grid.Release;
			END;
			Resized^;
		END Resized;

		PROCEDURE CreatePluginWindows(viewType : LONGINT);
		VAR
			graphWindow : PluginGraphWindow; gridWindow : PluginGridWindow; chartWindow : PluginChartWindow;
			p : Plugins.Plugin; changed : BOOLEAN;
			scol, srow, ecol, erow, row : LONGINT;
			ptr : ANY;
		BEGIN
			ASSERT((viewType = GraphView) OR (viewType = GridView) OR (viewType = ChartView));
			grid.GetSelection(scol, srow, ecol, erow);
			IF (srow >= 1) & (erow >= 1) THEN
				FOR row := srow TO erow DO
					grid.Acquire;
					grid.model.Acquire;
					ptr := grid.model.GetCellData(0, row);
					grid.model.Release;
					grid.Release;
					IF (ptr # NIL) & (ptr IS Plugins.Plugin) THEN
						p := ptr (Plugins.Plugin);
						IF (viewType = GraphView) THEN
							NEW(graphWindow, p, NIL);
							changed := TRUE;
						ELSIF (viewType = GridView) THEN
							NEW(gridWindow, p, NIL);
							changed := TRUE;
						ELSIF (viewType = ChartView) THEN
							NEW(chartWindow, p, NIL);
							changed := TRUE;
						ELSE
							(* TODO: do something *)
						END;
					END;
				END;
				IF changed THEN UpdateGrid; END;
			END;
		END CreatePluginWindows;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR b : WMStandardComponents.Button; ui, si, bs : LONGINT;
		BEGIN
			IF (sender # NIL) & (sender IS WMStandardComponents.Button) THEN
				b := sender (WMStandardComponents.Button);
				IF b = openGraphBtn THEN
					CreatePluginWindows(GraphView);
				ELSIF b = openGridBtn THEN
					CreatePluginWindows(GridView);
				ELSIF b = openChartBtn THEN
					CreatePluginWindows(ChartView);
				ELSIF b = refreshBtn THEN
					UpdateGrid;
				ELSIF b = applyBtn THEN
					GetSampleParameters(ui, bs, si);
					Plugins.updater.SetIntervals(ui, bs, si); (* VAR parameters*)
					SetSampleParameters(ui, bs, si);
				ELSIF b = clearBtn THEN
					Plugins.updater.ClearAll;
				END;
			END;
		END ButtonHandler;

		PROCEDURE GetSampleParameters(VAR ui, bs, si : LONGINT);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			sampleIntervalEditor.GetAsString(string); Strings.StrToInt(string, ui);
			screenIntervalEditor .GetAsString(string); Strings.StrToInt(string, si);
			sampleBufferSizeEditor.GetAsString(string); Strings.StrToInt(string, bs);
		END GetSampleParameters;

		PROCEDURE SetSampleParameters(ui, bs, si : LONGINT);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToStr(ui, string); sampleIntervalEditor.SetAsString(string);
			Strings.IntToStr(bs, string); sampleBufferSizeEditor.SetAsString(string);
			Strings.IntToStr(si, string); screenIntervalEditor .SetAsString(string);
		END SetSampleParameters;

		PROCEDURE UpdateGrid;
		VAR ca : Plugins.PluginArray; row : LONGINT;
		BEGIN
			ca := Plugins.updater.GetPlugins();
			IF ca # NIL THEN
				grid.Acquire;
				grid.model.Acquire;
				grid.model.SetNofRows(LEN(ca)+1);
				FOR row := 0 TO LEN(ca)-1 DO
					grid.model.SetCellTextAOC(0, row+1, 0, ca[row].p.name);
					grid.model.SetCellTextAOC(1, row+1, 0, ca[row].p.description);
					grid.model.SetCellTextAOC(2, row+1, 0, ca[row].p.devicename);
					grid.model.SetTextAlign(3, row+1, WMGraphics.AlignCenter);
					IF ca[row].IsActive() THEN
						grid.model.SetCellText(3, row+1, StrYes);
					ELSE
						grid.model.SetCellText(3, row+1, StrNo);
					END;
					grid.model.SetCellData(0, row+1, ca[row]);
				END;
				grid.model.Release;
				grid.Release;
			ELSE
				grid.Acquire;
				grid.model.Acquire;
				grid.model.SetNofRows(2);
				grid.model.SetCellText(0, 1, StrNotAvailable);
				grid.model.SetCellText(1, 1, StrNotAvailable);
				grid.model.SetCellText(2, 1, StrNotAvailable);
				grid.model.SetCellText(2, 1, StrNotAvailable);
				grid.model.Release;
				grid.Release;
			END;
		END UpdateGrid;

		PROCEDURE CreateSelectionPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel; line : WMStandardComponents.Panel;
		BEGIN
			panel := NewGroupPanel("Plugins", WMComponents.AlignClient, 0);

			line := NewPanel(WMComponents.AlignBottom, 0, LineHeight); panel.AddContent(line);

			openGraphBtn := NewButton("Graph", ButtonHandler); line.AddContent(openGraphBtn);
			openGridBtn := NewButton("Grid", ButtonHandler); line.AddContent(openGridBtn);
			openChartBtn := NewButton("Chart", ButtonHandler); line.AddContent(openChartBtn);
			line.AddContent(NewLabel("  Select a plugin and press Graph, Grid or Both", WMComponents.AlignClient, 0, 0));
			refreshBtn := NewButton("Refresh", ButtonHandler); refreshBtn.alignment.Set(WMComponents.AlignRight);
			line.AddContent(refreshBtn);

			NEW(grid);
			grid.fixedCols.Set(1); grid.fixedRows.Set(1);
			grid.bounds.SetExtents(500, 200); grid.alignment.Set(WMComponents.AlignClient);
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(TRUE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(TRUE);
			grid.allowColResize.Set(TRUE); grid.allowRowResize.Set(FALSE);
			NEW(spacings, 4); spacings[0] := 130; spacings[1] := 250; spacings[2] := 250; spacings[3] := 70;
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(4); grid.SetColSpacings(spacings);
			grid.model.SetNofRows(2);
			grid.model.SetCellText(0, 0, Strings.NewString("Plugin"));
			grid.model.SetCellText(1, 0, Strings.NewString("Description"));
			grid.model.SetCellText(2, 0, Strings.NewString("Device"));
			grid.model.SetCellText(3, 0, Strings.NewString("Status"));
			grid.model.Release;
			grid.Release;
			panel.AddContent(grid);

			RETURN panel;
		END CreateSelectionPanel;

		PROCEDURE CreateBottomPanel() : WMStandardComponents.GroupPanel;
		VAR panel : WMStandardComponents.GroupPanel;
		BEGIN
			panel := NewGroupPanel("Global sampling options", WMComponents.AlignBottom, 45);

			panel.AddContent(NewLabel(" Sample Interval [ms]: ", WMComponents.AlignLeft, 120, 0));
			sampleIntervalEditor := NewTextField(40); panel.AddContent(sampleIntervalEditor);

			panel.AddContent(NewLabel("  Screen Interval [ms]: ", WMComponents.AlignLeft, 120, 0));
			screenIntervalEditor := NewTextField(40); panel.AddContent(screenIntervalEditor );

			panel.AddContent(NewLabel(" Averaging [samples]: ", WMComponents.AlignLeft, 120, 0));
			sampleBufferSizeEditor := NewTextField(40); panel.AddContent(sampleBufferSizeEditor);

			SetSampleParameters(Plugins.updater.sampleInterval, Plugins.updater.sampleBufferSize, Plugins.updater.screenInterval);

			cpuTimeLabel := NewIndicator(" 0.0%", WMComponents.AlignLeft, 120, 0); panel.AddContent(cpuTimeLabel);

			clearBtn := NewButton("Clear", ButtonHandler); clearBtn.alignment.Set(WMComponents.AlignRight);
			panel.AddContent(clearBtn);

			applyBtn := NewButton("Apply", ButtonHandler); applyBtn.alignment.Set(WMComponents.AlignRight);
			panel.AddContent(applyBtn);

			RETURN panel;
		END CreateBottomPanel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrSelectionComponent);
			alive := TRUE; dead := FALSE; update := FALSE; NEW(w, 64);

			AddContent(CreateBottomPanel());
			AddContent(CreateSelectionPanel());

			UpdateGrid;

			Plugins.updater.AddListener({Plugins.EventPerfUpdate} + {Plugins.EventParametersChanged} + {Plugins.EventPluginsChanged}, EventHandler);
		END Init;

		PROCEDURE EventHandler(events : SET; perf : REAL);
		BEGIN {EXCLUSIVE}
			updateInfo.events := events;
			updateInfo.perf := perf;
			updateInfo.sampleInterval := Plugins.updater.sampleInterval;
			updateInfo.sampleBufferSize := Plugins.updater.sampleBufferSize;
			updateInfo.screenInterval := Plugins.updater.screenInterval;
			update := TRUE;
		END EventHandler;

		PROCEDURE Finalize;
		BEGIN
			Plugins.updater.RemoveListener(EventHandler);
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			(* Release obj lock to force condition evaluation *)
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Finalize^;
		END Finalize;

		PROCEDURE Update;
		VAR string : ARRAY 64 OF CHAR;
		BEGIN
			IF (Plugins.EventPerfUpdate IN synchronizedUpdateInfo.events) THEN
				w.String(" CPU:"); w.FloatFix(synchronizedUpdateInfo.perf, 5, 1, 0); w.Char("%"); w.Update;
				w.Get(string); SELF.cpuTimeLabel.SetCaption(string);
			END;
			IF (Plugins.EventParametersChanged IN synchronizedUpdateInfo.events) THEN
				SetSampleParameters(synchronizedUpdateInfo.sampleInterval, synchronizedUpdateInfo.sampleBufferSize, synchronizedUpdateInfo.screenInterval);
			END;
			IF (Plugins.EventPluginsChanged IN synchronizedUpdateInfo.events) THEN
				UpdateGrid;
			END;
		END Update;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE} AWAIT(update OR ~alive);
				synchronizedUpdateInfo := updateInfo;
				update := FALSE;
			END;
			IF alive THEN Update; END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END SelectionComponent;

TYPE


	Indicator* = OBJECT(WMStandardComponents.Panel)
	VAR
		value : ARRAY 128 OF CHAR;
		textColor : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrIndicator);
			value := "";
			textColor := 0;
		END Init;

		PROCEDURE SetCaption*(CONST x : ARRAY OF CHAR);
		BEGIN
			Acquire; COPY(x, value); Release;
			Invalidate;
		END SetCaption;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			canvas.SetColor(textColor);
			Acquire;
			WMGraphics.DrawStringInRect(canvas, GetClientRect(), FALSE, WMComponents.AlignNone, WMGraphics.AlignCenter, value);
			Release;
		END DrawBackground;
	END Indicator;

TYPE

	(** Base class for plugin views *)
	PluginView* = OBJECT(WMStandardComponents.GroupPanel)
	VAR
		plugin : Plugins.Plugin;

		statistics : WMDiagramComponents.Statistics;

		next : PluginView;

		PROCEDURE &New*(plugin : Plugins.Plugin);
		VAR caption : ARRAY 128 OF CHAR;
		BEGIN
			Init;
			ASSERT(plugin # NIL);
			SELF.plugin := plugin;
			IF ~UseSkinColors THEN fillColor.Set(0); textColor.Set(TextColor); END;
			caption := "  "; Strings.Append(caption, plugin.p.name);
			IF plugin.p.devicename # "" THEN
				Strings.Append(caption, " ("); Strings.Append(caption, plugin.p.devicename); Strings.Append(caption, ")");
			END;
			SELF.caption.SetAOC(caption);
			InitStats(plugin.datamodel.GetNofDimensions());
			InitView;
			plugin.IncNbrOfClients;
			SetNameAsString(StrPluginView);
		END New;

		PROCEDURE InitView*;
		BEGIN
			HALT(301); (* abstract *)
		END InitView;

		(** Update statistics field. Returns TRUE if succeeded, FALSE if values not up to date *)
		PROCEDURE UpdateStats*() : BOOLEAN;
		BEGIN
			plugin.datamodel.Acquire; plugin.datamodel.GetStatistics(statistics); plugin.datamodel.Release;
			IF statistics.valid THEN
				IF plugin.p.scale # 1.0 THEN
					ScaleDataset(plugin.p.scale, statistics.cur);
					ScaleDataset(plugin.p.scale, statistics.min);
					ScaleDataset(plugin.p.scale, statistics.max);
					ScaleDataset(plugin.p.scale, statistics.avg);
					ScaleDataset(plugin.p.scale, statistics.sum);
				END;
			END;
			RETURN statistics.valid;
		END UpdateStats;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			plugin.DecNbrOfClients;
		END Finalize;

		PROCEDURE ScaleDataset(scale : REAL; VAR dataset : WMDiagramComponents.Dataset);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(dataset)-1 DO
				dataset[i] := dataset[i] * scale;
			END;
		END ScaleDataset;

		PROCEDURE InitStats(dimensions : LONGINT);
		BEGIN
			NEW(statistics.cur, dimensions);
			NEW(statistics.min, dimensions); NEW(statistics.max, dimensions);
			NEW(statistics.sum, dimensions); NEW(statistics.avg, dimensions);
		END InitStats;
	END PluginView;


	(* The panel of a PluginView consists of three elements:
	 * 	- a Label describing the plugin (title)
	 *	- a PerfViewPanel graphically visualizing the measurements
	 *	- a Label showing the measurements as numbers
	 *)
	PluginGraphView* = OBJECT(PluginView)
	VAR
		stats : Streams.StringWriter;

		pview : WMDiagramComponents.MultiPointView;
		info : Indicator;

		PROCEDURE Update;
		BEGIN
			ShowStats;
			Invalidate;
		END Update;

		PROCEDURE Resized*;
		BEGIN
			IF bounds.GetHeight() < 100 THEN
				info.visible.Set(FALSE);
			ELSE
				info.visible.Set(TRUE);
			END;
			Resized^;
		END Resized;

		PROCEDURE InitView*;
		VAR temp : ARRAY 16 OF CHAR;
		BEGIN
			NEW(pview);
			pview.alignment.Set(WMComponents.AlignClient);
			IF ~UseSkinColors THEN pview.fillColor.Set(PerfViewFillColor); pview.color.Set(PerfViewColor); END;
			pview.showValues.Set(TRUE); pview.autoMin.Set(FALSE);
			pview.SetExtModel(plugin.datamodel);
			pview.SetExtUpdate(Update);

			NEW(info); info.bounds.SetHeight(LineHeight); info.alignment.Set(WMComponents.AlignBottom);
			IF ~UseSkinColors THEN info.fillColor.Set(LONGINT(0CCCCCCFFH)); info.textColor := WMGraphics.Black; END;
			info.SetFont(WMGraphics.GetFont("Courier", 10, {}));
			pview.min.Set(plugin.p.min); IF plugin.p.max # 0 THEN pview.max.Set(plugin.p.max); END;
			pview.autoMin.Set(plugin.p.autoMin); pview.autoMax.Set(plugin.p.autoMax);
			COPY(plugin.p.unit, temp);
			IF plugin.p.perSecond THEN Strings.Append(temp, "/s"); END;
			pview.unit.SetAOC(temp);

			AddInternalComponent(info);
			AddInternalComponent(pview);

			NEW(stats, 256);

			SetNameAsString(StrPluginGraphView);
		END InitView;

		PROCEDURE ShowStats;
		VAR string : ARRAY 256 OF CHAR; statsMax0 : REAL;

			PROCEDURE ShowUnit;
			BEGIN
				IF plugin.p.statsUnit # "" THEN
					stats.String(plugin.p.statsUnit);
					IF plugin.p.perSecond THEN stats.String("/s"); END;
				END;
			END ShowUnit;

			PROCEDURE ShowPercent(value : REAL);
			BEGIN
				IF plugin.p.showPercent & (plugin.p.max > 0) THEN
					stats.String(" ("); stats.FloatFix(100.0 * value / statsMax0, 5, 1, 0); stats.String("%)")
				END;
			END ShowPercent;

			PROCEDURE ShowValue(CONST name : ARRAY OF CHAR; value : REAL);
			BEGIN
				stats.String(name); stats.FloatFix(value, plugin.p.minDigits, plugin.p.fraction, 0); ShowUnit; ShowPercent(value);
			END ShowValue;

		BEGIN
			IF UpdateStats() THEN
				stats.Reset; statsMax0 := plugin.p.max * plugin.p.scale;
				ShowValue(" Cur: ", statistics.cur[0]); stats.Char(Tab);
				ShowValue("Min: ", statistics.min[0]); stats.Char(Tab);
				ShowValue("Max: ", statistics.max[0]); stats.Char(Tab);
				ShowValue("Avg: ", statistics.avg[0]);

				IF ~plugin.p.perSecond & plugin.p.showSum THEN
					stats.Char(Tab); stats.String("Tot: "); stats.FloatFix(statistics.sum[0], plugin.p.minDigits, plugin.p.fraction, 0); ShowUnit;
				END;

				stats.Update; stats.Get(string); info.SetCaption(string);
			END;
		END ShowStats;

	END PluginGraphView;

TYPE

	PluginGridView = OBJECT(PluginView)
	VAR
		grid : WMStringGrids.StringGrid;
		ds : Plugins.DatasetDescriptor;
		spacings : WMGrids.Spacings;
		nofRows : LONGINT;

		PROCEDURE NbrToStr(nbr :LONGREAL; VAR string : ARRAY OF CHAR);
		BEGIN
			IF nbr < MAX(LONGINT) THEN
				Strings.IntToStr(ENTIER(nbr), string);
			ELSE
				Strings.FloatToStr(nbr, 0, 0, 3, string);
			END;
		END NbrToStr;

		PROCEDURE UpdateGrid(sender, data : ANY);
		CONST MaxLength = 32;
		VAR row : LONGINT; string : ARRAY MaxLength OF CHAR;
		BEGIN
			IF UpdateStats() THEN
				grid.Acquire;
				grid.model.Acquire;
				FOR row := 1 TO nofRows-1 DO
					NbrToStr(statistics.cur[row-1], string); grid.model.SetCellTextAOC(2, row, MaxLength, string);
					NbrToStr(statistics.min[row-1], string); grid.model.SetCellTextAOC(3, row, MaxLength, string);
					NbrToStr(statistics.max[row-1], string); grid.model.SetCellTextAOC(4, row, MaxLength, string);
					NbrToStr(statistics.avg[row-1], string); grid.model.SetCellTextAOC(5, row, MaxLength, string);
					NbrToStr(statistics.sum[row-1], string); grid.model.SetCellTextAOC(6, row, MaxLength, string);
					IF ds # NIL THEN
						string := "";
						IF (WMDiagramComponents.Hidden IN ds[row-1].flags) THEN
							grid.model.SetCellText(7, row, StrHidden);
						ELSIF (WMDiagramComponents.Sum IN ds[row-1].flags) THEN
							grid.model.SetCellText(7, row, StrSum);
						ELSIF (WMDiagramComponents.Maximum IN ds[row-1].flags) THEN
							grid.model.SetCellText(7, row, StrMax);
						ELSE
							grid.model.SetCellText(7, row, StrNormal);
						END;
					ELSE
						grid.model.SetCellText(7, row, StrNormal);
					END;
				END;
				grid.model.Release;
				grid.Release;
			END;
		END UpdateGrid;

		PROCEDURE InitGrid;
		VAR col, row : LONGINT;
		BEGIN
			NEW(grid);
			grid.fixedRows.Set(1);
			grid.bounds.SetExtents(500, 200); grid.alignment.Set(WMComponents.AlignClient);
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(TRUE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(TRUE);
			grid.allowColResize.Set(TRUE); grid.allowRowResize.Set(FALSE);

			NEW(spacings, 8);
			spacings[0] := 30; spacings[1] := 120; spacings[2] := 80; spacings[3] := 80;
			spacings[4] := 80; spacings[5] := 80; spacings[6] := 80; spacings[7] := 40;

			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(8); grid.SetColSpacings(spacings);
			grid.model.SetNofRows(nofRows);
			(* column titles *)
			grid.model.SetCellText(0, 0, StrColor);
			grid.model.SetCellText(1, 0, StrName);
			grid.model.SetCellText(2, 0, StrCurrent);
			grid.model.SetCellText(3, 0, StrMin);
			grid.model.SetCellText(4, 0, StrMax);
			grid.model.SetCellText(5, 0, StrAvg);
			grid.model.SetCellText(6, 0, StrSum);
			grid.model.SetCellText(7, 0, StrMode);
			(* static grid content *)
			FOR row := 1 TO nofRows-1 DO
				FOR col := 2 TO 6 DO
					grid.model.SetTextAlign(col, row, WMGraphics.AlignRight);
				END;
				grid.model.SetTextAlign(7, row, WMGraphics.AlignCenter);
				grid.model.SetCellColors(0, row, ds[row-1].color, grid.clTextDefault.Get());
				grid.model.SetCellText(1, row, Strings.NewString(ds[row-1].name));
			END;
			grid.model.Release;
			grid.Release;
		END InitGrid;

		PROCEDURE InitView;
		BEGIN
			ds := plugin.p.datasetDescriptor;
			IF ds # NIL THEN
				nofRows := LEN(ds) + 1;
			ELSE
				nofRows := 2;
			END;
			InitGrid;
			AddInternalComponent(grid);
			UpdateGrid(NIL, NIL);
			plugin.datamodel.onChanged.Add(UpdateGrid);
			SetNameAsString(StrPluginGridView);
		END InitView;

		PROCEDURE Resized;
		VAR sum, w, i : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			rect := bounds.Get(); w := rect.r - rect.l - 20 (*scrollbar width*);
			FOR i := 0 TO LEN(spacings)-1 DO
				sum := sum + spacings[i];
			END;
			IF w = sum THEN
				(* do nothing *)
			ELSIF w > sum THEN (* enlarge grid *)
				grid.Acquire;
				grid.model.Acquire;
				FOR i := 0 TO LEN(spacings)-1 DO
					spacings[i] := spacings[i] + (w - sum) DIV 8;
				END;
				spacings[LEN(spacings)-1] := spacings[LEN(spacings)-1] + (w - sum) MOD 8;
				grid.model.Release;
				grid.Release;
			ELSE (* make spacings smaller *)
				grid.Acquire;
				grid.model.Acquire;
				FOR i := 0 TO LEN(spacings)-1 DO
					spacings[i] := w DIV 8;
				END;
				spacings[LEN(spacings)-1] := spacings[LEN(spacings)-1] + (w MOD 8);
				grid.model.Release;
				grid.Release;
			END;
			Resized^;
		END Resized;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			plugin.datamodel.onChanged.Remove(UpdateGrid);
		END Finalize;

	END PluginGridView;

TYPE

	PluginChartView = OBJECT(PluginView)
	VAR
		barChart : WMDiagramComponents.BarChart;
		ds : Plugins.DatasetDescriptor;
		heights : POINTER TO ARRAY OF LONGREAL;

		PROCEDURE InitView;
		VAR
			labels : POINTER TO ARRAY OF Strings.String;
			colors : POINTER TO ARRAY OF LONGINT;
			i : LONGINT;
		BEGIN
			ds := plugin.p.datasetDescriptor;
			NEW(heights, LEN(ds));
			NEW(labels, LEN(ds));
			NEW(colors, LEN(ds));
			FOR i := 0 TO LEN(ds)-1 DO
				heights[i] := 0.0;
				labels[i] := Strings.NewString(ds[i].name);
				colors[i] := ds[i].color;
			END;
			NEW(barChart); barChart.alignment.Set(WMComponents.AlignClient);
			barChart.backgroundColor.Set(WMGraphics.White);
			barChart.textColor.Set(WMGraphics.Black);
			barChart.SetData(heights^, LEN(heights));
			barChart.SetLabels(labels^);
			barChart.SetColors(colors^);
			AddInternalComponent(barChart);
			UpdateChart(NIL, NIL);
			plugin.datamodel.onChanged.Add(UpdateChart);
			SetNameAsString(StrPluginGridView);
		END InitView;

		PROCEDURE UpdateChart(sender, data : ANY);
		VAR max : REAL;  i : LONGINT;

			PROCEDURE FindMax() : REAL;
			VAR i : LONGINT; max : REAL;
			BEGIN
				max := 0.0;
				FOR i := 0 TO LEN(statistics.cur)-1 DO
					IF (statistics.cur[i] > max) THEN max := statistics.cur[i]; END;
				END;
				RETURN max;
			END FindMax;

		BEGIN
			IF UpdateStats() THEN
				max := FindMax();
				IF (max > 0.0) THEN
					FOR i := 0 TO LEN(heights)-1 DO
						heights[i] := statistics.cur[i] / max;
					END;
				ELSE
					FOR i := 0 TO LEN(heights)-1 DO
						heights[i] := 0.0;
					END;
				END;
				barChart.SetData(heights^, LEN(heights));
			END;
		END UpdateChart;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			plugin.datamodel.onChanged.Remove(UpdateChart);
		END Finalize;

	END PluginChartView;

TYPE

	(** Simple multipointview component that is XML capabale *)
	PerfMonSimpleGraph* = OBJECT(WMComponents.VisualComponent)
	VAR
		plugin- : WMProperties.StringProperty;
		showValues- : WMProperties.BooleanProperty;

		label : WMStandardComponents.Label;
		pview : WMDiagramComponents.MultiPointView;
		pluginInstance : Plugins.Plugin;

		PROCEDURE & Init*;
		BEGIN
			Init^;

			NEW(plugin, PrototypePlugin, NIL, NIL); properties.Add(plugin);
			NEW(showValues, PrototypeShowValues, NIL, NIL); properties.Add(showValues);

			label := NewLabel("No plugin specified", WMComponents.AlignClient, 0, 0);
			label.alignV.Set(WMGraphics.AlignCenter);
			label.alignH.Set(WMGraphics.AlignCenter);
			AddContent(label);

			NEW(pview);
			pview.alignment.Set(WMComponents.AlignClient);
			pview.visible.Set(FALSE);
			IF ~UseSkinColors THEN pview.fillColor.Set(PerfViewFillColor); pview.color.Set(PerfViewColor); END;
			pview.showValues.Set(TRUE); pview.autoMin.Set(FALSE);
			AddContent(pview);

			InstallPlugin;

			SetNameAsString(StrPerfMonSimpleGraph);
			SetGenerator("WMPerfMonComponents.GenPerfMonSimpleGraph");
		END Init;

		PROCEDURE InitDiagram(pluginInstance : Plugins.Plugin; index : LONGINT);
		VAR temp : ARRAY 16 OF CHAR;
		BEGIN
			ASSERT(plugin # NIL);
			pluginInstance.IncNbrOfClients();
			pview.SetExtModel(pluginInstance.datamodel);
			pview.min.Set(pluginInstance.p.min); IF pluginInstance.p.max # 0 THEN pview.max.Set(pluginInstance.p.max); END;
			pview.autoMin.Set(pluginInstance.p.autoMin); pview.autoMax.Set(pluginInstance.p.autoMax);
			COPY(pluginInstance.p.unit, temp);
			IF pluginInstance.p.perSecond THEN Strings.Append(temp, "/s"); END;
			pview.unit.SetAOC(temp);
		END InitDiagram;

		PROCEDURE InstallPlugin;
		VAR string : Strings.String; msg : ARRAY 32 OF CHAR; index : LONGINT;
		BEGIN
			label.visible.Set(TRUE); pview.visible.Set(FALSE);
			IF pluginInstance # NIL THEN
				pluginInstance.DecNbrOfClients();
				pluginInstance := NIL;
			END;
			string := plugin.Get();
			IF string # NIL THEN
				pluginInstance := Plugins.updater.GetByFullname(string^, index, msg);
				IF pluginInstance # NIL THEN
					InitDiagram(pluginInstance, index);
					label.visible.Set(FALSE); pview.visible.Set(TRUE);
				ELSE
					label.caption.SetAOC(msg);
				END;
			ELSE
				label.caption.SetAOC("No plugin specified");
			END;
		END InstallPlugin;

		PROCEDURE RecacheProperties*;
		BEGIN
			RecacheProperties^;
			pview.showValues.Set(showValues.Get());
			InstallPlugin;
		END RecacheProperties;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF (property = plugin) THEN
				RecacheProperties;
				Invalidate;
			ELSIF (property = showValues) THEN
				pview.showValues.Set(showValues.Get());
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE Finalize*;
		BEGIN
			IF pluginInstance # NIL THEN
				pluginInstance.DecNbrOfClients();
				pluginInstance := NIL;
			END;
			Finalize^;
		END Finalize;

	END PerfMonSimpleGraph;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	PluginWindow* = OBJECT (WMComponents.FormWindow)
	VAR
		plugin : Plugins.Plugin;
		width, height : LONGINT;

		PROCEDURE CreateForm*() : WMComponents.VisualComponent;
		BEGIN
			HALT(301); RETURN NIL; (* abstract *)
		END CreateForm;

		PROCEDURE Resized(width, height : LONGINT);
		BEGIN
			IF (width >= MinPwWidth) & (height >= MinPwHeight) THEN
				scaling := FALSE;
				SELF.width := width; SELF.height := height;
			ELSE
				scaling := TRUE;
			END;
			Resized^(width, height);
		END Resized;

		PROCEDURE SetActive*(active : BOOLEAN);
		BEGIN
			plugin.SetActive(active);
		END SetActive;

		PROCEDURE &New*(plugin : Plugins.Plugin; c : WMRestorable.Context);
		VAR
			size, configuration : XML.Element;
			vc : WMComponents.VisualComponent;
			scale : BOOLEAN;
		BEGIN
			ASSERT(plugin # NIL);
			SELF.plugin := plugin;
			scaling := FALSE; scale := FALSE;

			vc := CreateForm();

			IF c # NIL THEN
				width := c.r - c.l; height :=  c.b - c.t;
				size := WMRestorable.GetElement(c, "Data\Size");
				IF size # NIL THEN
					WMRestorable.LoadLongint(size, "Width", width);
					WMRestorable.LoadLongint(size, "Height", height);
					IF (width < MinPwWidth) OR (height < MinPwHeight) THEN
						scale := TRUE;
					END;
				END;
			ELSE
				width := DefaultPwWidth; height := DefaultPwHeight;
			END;

			Init(width, height, FALSE);
			SetContent(vc);
			IF (plugin.p.devicename # "") THEN
				SetTitle(Strings.NewString(plugin.p.devicename));
			ELSE
				SetTitle(Strings.NewString(plugin.p.name));
			END;

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				configuration := WMRestorable.GetElement(c, "Data\Configuration");
				LoadFromXml(configuration);
				IF scale THEN Resized(c.r - c.l, c.b - c.t); END;
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
			END;
			IncCount;
		END New;

		(** Load plugin state from XML element *)
		PROCEDURE LoadFromXml(configuration : XML.Element);
		VAR active : BOOLEAN;
		BEGIN
			IF configuration # NIL THEN
				WMRestorable.LoadBoolean(configuration, "Active", active); plugin.SetActive(active);
				WMRestorable.LoadBoolean(configuration, "PerSecond", plugin.p.perSecond);
			END;
		END LoadFromXml;

		(** Store plugin state into XML element. Can be overwritten to be extended *)
		PROCEDURE StoreToXml() : XML.Element;
		VAR elem, data : XML.Element;
		BEGIN
			NEW(data); data.SetName("Data");
			NEW(elem); elem.SetName("View"); data.AddContent(elem);
			IF (SELF IS PluginGraphWindow) THEN
				WMRestorable.StoreLongint(elem, "Type", GraphView);
			ELSIF (SELF IS PluginGridWindow) THEN
				WMRestorable.StoreLongint(elem, "Type", GridView);
			ELSE
				WMRestorable.StoreLongint(elem, "Type", UnknownView);
			END;
			NEW(elem); elem.SetName("Identification"); data.AddContent(elem);
			WMRestorable.StoreString(elem, "Name", plugin.p.name);
			WMRestorable.StoreString(elem, "Device", plugin.p.devicename);
			NEW(elem); elem.SetName("Configuration"); data.AddContent(elem);
			WMRestorable.StoreBoolean(elem, "Active", plugin.IsActive());
			WMRestorable.StoreBoolean(elem, "PerSecond", plugin.p.perSecond);
			NEW(elem); elem.SetName("Size"); data.AddContent(elem);
			WMRestorable.StoreLongint(elem, "Width", width);
			WMRestorable.StoreLongint(elem, "Height", height);
			RETURN data;
		END StoreToXml;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR data : XML.Element;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					data := StoreToXml();
					x.ext(WMRestorable.Storage).Add("WMPerfMonPluginsPlugin", "WMPerfMonComponents.RestorePlugin", SELF, data);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Close;
		BEGIN
			Close^; DecCount;
		END Close;

	END PluginWindow;

TYPE

	PluginGraphWindow* = OBJECT (PluginWindow)
	VAR
		graphView : PluginGraphView;
		stop, clear, automin, automax, perSecond, legend : WMStandardComponents.Button;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR
			b : WMStandardComponents.Button; string : ARRAY 32 OF CHAR;
			gridWindow : PluginGridWindow;
		BEGIN
			b := sender (WMStandardComponents.Button);
			IF b = stop THEN
				SetActive(~plugin.IsActive());
			ELSIF b = clear THEN
				plugin.Reset;
			ELSIF b = automin THEN
				graphView.pview.autoMin.Set(~graphView.pview.autoMin.Get());
				IF graphView.pview.autoMin.Get() THEN automin.caption.SetAOC("AutoMin:On"); ELSE automin.caption.SetAOC("AutoMin:Off"); END;
			ELSIF b = automax THEN
				graphView.pview.autoMax.Set(~graphView.pview.autoMax.Get());
				IF graphView.pview.autoMax.Get() THEN automax.caption.SetAOC("AutoMax:On"); ELSE automax.caption.SetAOC("AutoMax:Off"); END;
			ELSIF b = perSecond THEN
				plugin.p.perSecond := ~plugin.p.perSecond;
				IF plugin.p.perSecond THEN
					string := ""; Strings.Append(string, plugin.p.unit); Strings.Append(string, "/s");
					graphView.pview.unit.SetAOC(string);
					perSecond.caption.SetAOC("PerSecond:On");
				ELSE
					graphView.pview.unit.SetAOC(plugin.p.unit);
					perSecond.caption.SetAOC("PerSecond:Off");
				END;
			ELSIF b = legend THEN
				NEW(gridWindow, plugin, NIL);
			END;
		END ButtonHandler;

		PROCEDURE CreateForm*(): WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel;
		BEGIN
			panel := NewPanel(WMComponents.AlignClient, 0, 0); panel.bearing.Set(WMRectangles.MakeRect(2,5,2,2));

			toolbar := NewPanel(WMComponents.AlignBottom, 0, 20);
			panel.AddContent(toolbar);

			NEW(graphView, plugin); graphView.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(graphView);

			NEW(stop); stop.bounds.SetWidth(100); stop.alignment.Set(WMComponents.AlignLeft);
			stop.onClick.Add(ButtonHandler);
			toolbar.AddContent(stop);

			NEW(clear); clear.bounds.SetWidth(100); clear.alignment.Set(WMComponents.AlignLeft);
			clear.onClick.Add(ButtonHandler); clear.caption.SetAOC("Clear");
			toolbar.AddContent(clear);

			NEW(automin); automin.bounds.SetWidth(100); automin.alignment.Set(WMComponents.AlignLeft);
			automin.onClick.Add(ButtonHandler);
			toolbar.AddContent(automin);

			NEW(automax); automax.bounds.SetWidth(100); automax.alignment.Set(WMComponents.AlignLeft);
			automax.onClick.Add(ButtonHandler);
			toolbar.AddContent(automax);

			NEW(perSecond); perSecond.bounds.SetWidth(100); perSecond.alignment.Set(WMComponents.AlignLeft);
			perSecond.onClick.Add(ButtonHandler);
			toolbar.AddContent(perSecond);

			IF LEN(plugin.p.datasetDescriptor) > 1 THEN
				NEW(legend); legend.bounds.SetWidth(100); legend.alignment.Set(WMComponents.AlignLeft);
				legend.onClick.Add(ButtonHandler); legend.caption.SetAOC("Legend");
				toolbar.AddContent(legend);
			END;

			IF plugin.p.autoMin THEN automin.caption.SetAOC("AutoMin:On"); graphView.pview.autoMin.Set(TRUE);
			ELSE automin.caption.SetAOC("AutoMin:Off"); graphView.pview.autoMin.Set(FALSE);
			END;
			IF plugin.p.autoMax THEN automax.caption.SetAOC("AutoMax:On"); graphView.pview.autoMax.Set(TRUE);
			ELSE automax.caption.SetAOC("AutoMax:Off"); graphView.pview.autoMax.Set(FALSE);
			END;
			IF plugin.IsActive() THEN stop.caption.SetAOC("Counter:On"); ELSE stop.caption.SetAOC("Counter:Off"); END;
			IF plugin.p.perSecond THEN perSecond.caption.SetAOC("PerSecond:On"); ELSE perSecond.caption.SetAOC("PerSecond:Off"); END;

			RETURN panel;
		END CreateForm;

		PROCEDURE LoadFromXml*(configuration : XML.Element);
		BEGIN
			LoadFromXml^(configuration);
			IF configuration # NIL THEN
				WMRestorable.LoadBoolean(configuration, "AutoMin", plugin.p.autoMin);
				WMRestorable.LoadBoolean(configuration, "AutoMax", plugin.p.autoMax);
			END;
		END LoadFromXml;

		PROCEDURE StoreToXml() : XML.Element;
		VAR elem, data : XML.Element;
		BEGIN
			data := StoreToXml^();
			NEW(elem); elem.SetName("GraphView"); data.AddContent(elem);
			WMRestorable.StoreBoolean(elem, "AutoMin", graphView.pview.autoMin.Get());
			WMRestorable.StoreBoolean(elem, "AutoMax", graphView.pview.autoMax.Get());
			RETURN data;
		END StoreToXml;

	END PluginGraphWindow;

TYPE

	PluginGridWindow* = OBJECT(PluginWindow)
	VAR
		gridView : PluginGridView;
		allBtn, noneBtn, toggleBtn, graphBtn : WMStandardComponents.Button;

		PROCEDURE SetHide(hide : BOOLEAN);
		VAR i : LONGINT; ds : Plugins.DatasetDescriptor;
		BEGIN
			ds := gridView.plugin.p.datasetDescriptor;
			FOR i := 0 TO LEN(ds)-1 DO
				IF hide THEN
					INCL(ds[i].flags, WMDiagramComponents.Hidden);
				ELSE
					EXCL(ds[i].flags, WMDiagramComponents.Hidden);
				END;
			END;
		END SetHide;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR
			ds : Plugins.DatasetDescriptor; scol, srow, ecol, erow, row : LONGINT;
			graphWindow : PluginGraphWindow;
			nofHidden : LONGINT;
			hide : BOOLEAN;
		BEGIN
			IF sender = allBtn THEN
				SetHide(FALSE);
			ELSIF sender = noneBtn THEN
				SetHide(TRUE);
			ELSIF sender = toggleBtn THEN
				gridView.grid.GetSelection(scol, srow, ecol, erow);
				ds := gridView.plugin.p.datasetDescriptor;
				IF (srow >= 1) & (erow >= 1) THEN
					IF (srow = erow) THEN
						(* toggle between Normal, Sum, Maximum, Hidden *)
						IF (WMDiagramComponents.Hidden IN ds[srow-1].flags) THEN
							(* Hidden -> Normal *)
							ds[srow-1].flags := ds[srow-1].flags - {WMDiagramComponents.Hidden, WMDiagramComponents.Sum, WMDiagramComponents.Maximum};
						ELSIF ({WMDiagramComponents.Hidden, WMDiagramComponents.Sum, WMDiagramComponents.Maximum} * ds[srow-1].flags = {}) THEN
							(* Normal -> Sum *)
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Sum, ds);
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Maximum, ds);
							INCL(ds[srow-1].flags, WMDiagramComponents.Sum);
						ELSIF (WMDiagramComponents.Sum IN ds[srow-1].flags) THEN
							(* Sum -> Maximum *)
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Sum, ds);
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Maximum, ds);
							INCL(ds[srow-1].flags, WMDiagramComponents.Maximum);
						ELSE
							(* Maximum -> Hidden *)
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Sum, ds);
							WMDiagramComponents.ClearFlag(WMDiagramComponents.Maximum, ds);
							INCL(ds[srow-1].flags, WMDiagramComponents.Hidden);
						END;
					ELSE
						nofHidden := WMDiagramComponents.GetNumberOf(WMDiagramComponents.Hidden, row-1, erow-1, ds);
						hide := nofHidden < (erow - srow + 1);
						FOR row := srow TO erow DO
							IF hide THEN
								INCL(ds[row-1].flags, WMDiagramComponents.Hidden);
							ELSE
								EXCL(ds[row-1].flags, WMDiagramComponents.Hidden);
							END;
						END;
					END;
				END;
			ELSIF sender = graphBtn THEN
				NEW(graphWindow, plugin, NIL);
			ELSE
			END;
		END ButtonHandler;

		PROCEDURE CreateForm*(): WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			panel := NewPanel(WMComponents.AlignClient, 0, 0); panel.bearing.Set(WMRectangles.MakeRect(2,5,2,2));

			toolbar := NewPanel(WMComponents.AlignBottom, 0, 20);
			panel.AddContent(toolbar);

			label := NewLabel(" Display in graph: ", WMComponents.AlignLeft, 120, 0); toolbar.AddContent(label);
			allBtn := NewButton("All", ButtonHandler); toolbar.AddContent(allBtn);
			noneBtn := NewButton("None", ButtonHandler);	toolbar.AddContent(noneBtn);
			toggleBtn := NewButton("Toggle Selected", ButtonHandler); toolbar.AddContent(toggleBtn);
			graphBtn := NewButton("Graph", ButtonHandler); graphBtn.alignment.Set(WMComponents.AlignRight);
			toolbar.AddContent(graphBtn);

			NEW(gridView, plugin); gridView.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(gridView);

			RETURN panel;
		END CreateForm;

	END PluginGridWindow;

TYPE

	PluginChartWindow* = OBJECT(PluginWindow)
	VAR
		chartView : PluginChartView;
		verticalBtn : WMStandardComponents.Button;
		vertical : BOOLEAN;

		PROCEDURE ButtonHandler(sender, data : ANY);
		BEGIN
			IF (sender = verticalBtn) THEN
				vertical := ~vertical;
				chartView.barChart.SetVertical(vertical);
			END;
		END ButtonHandler;

		PROCEDURE CreateForm*(): WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel;
		BEGIN
			panel := NewPanel(WMComponents.AlignClient, 0, 0); panel.bearing.Set(WMRectangles.MakeRect(2,5,2,2));

			toolbar := NewPanel(WMComponents.AlignBottom, 0, 20);
			panel.AddContent(toolbar);

			verticalBtn := NewButton("Vertical", ButtonHandler); toolbar.AddContent(verticalBtn);
			verticalBtn.isToggle.Set(TRUE);
			vertical := FALSE;

			NEW(chartView, plugin); chartView.alignment.Set(WMComponents.AlignClient);
			chartView.barChart.SetVertical(FALSE);
			panel.AddContent(chartView);

			RETURN panel;
		END CreateForm;

	END PluginChartWindow;

VAR
	PrototypePlugin : WMProperties.StringProperty;
	PrototypeShowValues : WMProperties.BooleanProperty;

	StrPluginContainer, StrSelectionComponent,
	StrPluginView, StrPluginGraphView, StrPluginGridView,
	StrPerfMonSimpleGraph, StrYes, StrNo, StrNotAvailable, StrIndicator,
	StrColor, StrName, StrCurrent, StrMin, StrMax, StrAvg, StrSum, StrMode, StrHidden, StrNormal : Strings.String;

	nofWindows : LONGINT;

PROCEDURE GenPerfMonSimpleGraph*() : XML.Element;
VAR sg : PerfMonSimpleGraph;
BEGIN
	NEW(sg); RETURN sg;
END GenPerfMonSimpleGraph;

PROCEDURE InitStrings;
BEGIN
	StrPluginContainer := Strings.NewString("PluginContainer");
	StrSelectionComponent := Strings.NewString("SelectionComponent");
	StrPluginView := Strings.NewString("PluginView");
	StrPluginGraphView := Strings.NewString("PluginGraphView");
	StrPluginGridView := Strings.NewString("PluginGridView");
	StrPerfMonSimpleGraph := Strings.NewString("PerfMonSimpleGraph");
	StrYes := Strings.NewString("Yes");
	StrNo := Strings.NewString("No");
	StrNotAvailable := Strings.NewString("n/a");
	StrIndicator := Strings.NewString("Indicator");
	StrColor := Strings.NewString("Color");
	StrName := Strings.NewString("Name");
	StrCurrent := Strings.NewString("Current");
	StrMin := Strings.NewString("Min");
	StrMax := Strings.NewString("Max");
	StrAvg := Strings.NewString("Avg");
	StrSum := Strings.NewString("Sum");
	StrMode := Strings.NewString("Mode");
	StrHidden := Strings.NewString("Hidden");
	StrNormal := Strings.NewString("Normal");
END InitStrings;

PROCEDURE InitPrototypes;
VAR  plPerfMonSimpleGraph : WMProperties.PropertyList;
BEGIN
	NEW(plPerfMonSimpleGraph); WMComponents.propertyListList.Add("PerfMonSimpleGraph", plPerfMonSimpleGraph);
	NEW(PrototypePlugin, NIL, Strings.NewString("Plugin"), Strings.NewString("Fullname of PerfMon plugin to be displayed"));
	plPerfMonSimpleGraph.Add(PrototypePlugin);
	NEW(PrototypeShowValues, NIL, Strings.NewString("ShowValues"), Strings.NewString("Show minimum and maximum values in diagram"));
	PrototypeShowValues.Set(FALSE);
END InitPrototypes;

PROCEDURE NewButton*(CONST caption : ARRAY OF CHAR; handler : WMEvents.EventListener) : WMStandardComponents.Button;
VAR button : WMStandardComponents.Button;
BEGIN
	NEW(button); button.alignment.Set(WMComponents.AlignLeft); button.bounds.SetWidth(ButtonWidth);
	button.caption.SetAOC(caption); button.onClick.Add(handler);
	RETURN button;
END NewButton;

PROCEDURE NewGroupPanel*(CONST caption : ARRAY OF CHAR; alignment, height : LONGINT) : WMStandardComponents.GroupPanel;
VAR panel : WMStandardComponents.GroupPanel;
BEGIN
	NEW(panel); panel.alignment.Set(alignment); panel.bounds.SetHeight(height);
	panel.bearing.Set(WMRectangles.MakeRect(2,5,2,2));
	panel.caption.SetAOC(caption);
	IF ~UseSkinColors THEN
		panel.fillColor.Set(BgFillColor); panel.textColor.Set(WMGraphics.White);
	END;
	RETURN panel;
END NewGroupPanel;

PROCEDURE NewIndicator*(CONST caption : ARRAY OF CHAR; alignment, width, height : LONGINT) : Indicator;
VAR i : Indicator;
BEGIN
	NEW(i); i.alignment.Set(alignment); i.bounds.SetExtents(width, height);
	i.SetCaption(caption);
	IF ~UseSkinColors THEN
		i.fillColor.Set(BgFillColor); i.textColor := TextColor;
	END;
	RETURN i;
END NewIndicator;

PROCEDURE NewLabel*(CONST caption : ARRAY OF CHAR; alignment, width, height : LONGINT) : WMStandardComponents.Label;
VAR label : WMStandardComponents.Label;
BEGIN
	NEW(label); label.alignment.Set(alignment); label.bounds.SetExtents(width, height);
	label.caption.SetAOC(caption);
	IF ~UseSkinColors THEN
		label.fillColor.Set(BgFillColor); label.textColor.Set(TextColor);
	END;
	RETURN label;
END NewLabel;

PROCEDURE NewTextField*(width : LONGINT) : WMEditors.TextField;
VAR textfield : WMEditors.TextField;
BEGIN
	NEW(textfield); textfield.bounds.SetWidth(width); textfield.alignment.Set(WMComponents.AlignLeft);
	IF ~UseSkinColors THEN  textfield.fillColor.Set(WMGraphics.White); END;
	RETURN textfield;
END NewTextField;

PROCEDURE NewPanel*(alignment, width, height : LONGINT) : WMStandardComponents.Panel;
VAR panel : WMStandardComponents.Panel;
BEGIN
	NEW(panel); panel.alignment.Set(alignment); panel.bounds.SetExtents(width, height);
	IF ~UseSkinColors THEN
		panel.fillColor.Set(BgFillColor);
	END;
	RETURN panel;
END NewPanel;

PROCEDURE RestorePlugin*(c : WMRestorable.Context);
VAR
	identification, view : XML.Element;
	name : Plugins.Name;  devicename : Plugins.DeviceName; plugin : Plugins.Plugin;
	graphWindow : PluginGraphWindow; gridWindow : PluginGridWindow;
	viewType : LONGINT;
BEGIN
	ASSERT(c # NIL);
	name := ""; devicename := "";
	identification := WMRestorable.GetElement(c, "Data\Identification");
	IF identification # NIL THEN
		WMRestorable.LoadString(identification, "Name", name);
		WMRestorable.LoadString(identification, "Device", devicename);
		IF name # "" THEN
			plugin := Plugins.updater.GetByName(name, devicename);
			IF plugin # NIL THEN
				view := WMRestorable.GetElement(c, "Data\View");
				IF view # NIL THEN
					WMRestorable.LoadLongint(view, "Type", viewType);
					IF viewType = GraphView THEN
						NEW(graphWindow, plugin, c);
					ELSIF viewType = GridView THEN
						NEW(gridWindow, plugin, c);
					ELSE
						KernelLog.String("WMPerfMon: Error: Unknown view type."); KernelLog.Ln;
					END;
				ELSE
					KernelLog.String("WMPerfMon: Error: Could not determine view type of plugin to be restored."); KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("WMPerfMon: Plugin "); KernelLog.String(name); KernelLog.String(" on device ");
				KernelLog.String(devicename); KernelLog.String(" not available."); KernelLog.Ln;
			END;
		END;
	END;
END RestorePlugin;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg; msg : WMMessages.Message; m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	InitStrings;
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonComponents.
