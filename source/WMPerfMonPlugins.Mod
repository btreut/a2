MODULE WMPerfMonPlugins; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin framework"; *)
(**
 * The idea behind the Peformance Monitor plugin framework is to facilitate simple performance monitoring / measurement tasks by
 * providing some commonly used services as:
 *	- Sampling (incl. averaging, simple statistics, configurable sampling intervals and sample buffers)
 *	- Visualization of the sampled values / statistics
 *	- Managing self-describing Performance Monitor plugins  and providing access to them
 *
 * This module provides:
 *	- Plugin interface implemented by actual Performance Monitor plugins
 *	- Helper objects that provide access to sampled value to multiple plugins
 *	- Updater object that performs the actual sampling in a single loop for all active Plugins
 *
 * Usage:	WMPerfMonPlugins.Show ~ displays a list of all registered plugins	SystemTools.Free WMPerfMonPlugins ~
 *
 * Possible improvements:
 *	-	Use low-level timer (Machine.GetTimer) everywhere since Objects.ticks is inaccurate/not reliable
 *
 * History:
 *
 *	16.02.2006	First Release (staubesv)
 *	23.06.2006 	Adapted to WMDiagramComponents, support for multidimensional data visualization (staubesv)
 *	19.07.2006	Added EstimateCpuClockrate procedure, load MessagesPlugin per default, plugins can optionally bypass supersampling (staubesv)
 *	24.07.2006 	Added CyclesToMs, MsToString procedures (staubesv)
 *	28.07.2006	Moved GUI-related code to WMPerfMonComponents (staubesv)
 *	16.01.2006	Updater.SetIntervals also clears screenTimer to force appliation of new value, no upper bounds for sample interval,
 *				only consider valid samples when averaging (staubesv)
 *	26.02.2007	Added Updater.RemoveByModuleName, generate colors for datasets with more than 3 datas, configuration in config file  (staubesv)
 *)

IMPORT
	KernelLog, Machine, Objects, Kernel, Modules, Heaps, Commands, Plugins,
	Configuration, Strings, WMDiagramComponents, WMGraphics, Events,
	XML, XMLObjects;

CONST

	EventPluginsChanged* = 0;		(** Plugins have been added, removed, activated or deactivated *)
	EventPerfUpdate* = 1;			(** Updater performance has been updated *)
	EventParametersChanged* = 2;	(** Sampling parameters have changed *)
	EventSampleLoopDone* = 3;		(** All plugin values have been updated *)

	(* How many samples should be used for averaging? *)
	DefaultSampleBufferSize = 10; 	(* samples *)
	DefaultSampleInterval = 50; 		(* ms *)
	DefaultScreenRefresh = 500; 	(* ms *)

	(* DataDescriptor.flags *)
	Hidden* = WMDiagramComponents.Hidden;			(* Don't visualize! *)
	Sum* = WMDiagramComponents.Sum;				(* This value is the sum of all other values in the same dataset *)
	Maximum* = WMDiagramComponents.Maximum;	(* This value is the maximum that other values in the same dataset can reach *)
	Standalone* =WMDiagramComponents.Standalone; 	(* Indicate that this value is not affected by Sum/Maximum of dataset *)

	(* Display registering/unregistering of plugins *)
	Verbose = FALSE;

TYPE

	Name* = ARRAY 32 OF CHAR;
	Description* = ARRAY 128 OF CHAR;
	DeviceName* = ARRAY 128 OF CHAR;
	Dataset* = WMDiagramComponents.Dataset;
	DatasetDescriptor* = WMDiagramComponents.DatasetDescriptor;

	PluginLoader = PROCEDURE;

TYPE

	(** Plugin parameters.  																			*)
	(** A parameter object must be passed as argument for the plugin object's constructor. The fields	*)
	(** may be set later in the Init procedure but shall not be modified after the Init procedure.		*)

	Parameter* = POINTER TO RECORD;

		(** Name and description of the plugin														*)
		name* : Name; description* : Description;

		(** Name of the monitored device if applicable. Default = "" (not applicable)					*)
		devicename* : DeviceName;

		(** Module where counter is implemented													*)
		modulename* : ARRAY 128 OF CHAR;

		(**	Describes names and colors of sampled values											*)
		datasetDescriptor* : WMDiagramComponents.DatasetDescriptor;

		(** If TRUE, the plugin will only be sampled when a screen update occurs. If FALSE, the plugin	*)
		(* will be sampled at the sample rate specified by the Updater object. The average of all 		*)
		(* samples in the sample buffer will then be displayed											*)
		(* Default: FALSE																			*)
		noSuperSampling* : BOOLEAN;

		(** Minimum and maximum value the UpdateCounter procedure will return					*)
		(** Defaults: min = 0; max = 0 (no max)														*)
		min*, max* : LONGINT;

		(** Should the diagram panel automatically detect a min/max value? 						*)
		(** Defaults: autoMin = FALSE; autoMax = FALSE												*)
		autoMin*, autoMax* : BOOLEAN;

		(** Unit of the counter ("/s" will be appended automatically if the field 'perSecond' is TRUE) 	*)
		(** Default: "" (None)																		*)
		unit* : ARRAY 16 OF CHAR;

		(** Shall the counter be interpreted as change per second? Default: FALSE					*)
		perSecond* : BOOLEAN;

		(** Statistic gathering related parameters *)

		(** The stats value will be computed as UpdateCounter() * scale								*)
		(** Default: 0.0 (is interpreted as 1.0 -> don't scale) 											*)
		scale* : REAL;

		(** Minimum number of digits, number of fraction digits										*)
		(** Defaults: minDigits = 0; fraction = 0;														*)
		minDigits*, fraction* : LONGINT;

		(** Unit of the statistics values ("/s" will be appended automatically if 'perSecond' is TRUE)	*)
		(** Default: "" (None)																		*)
		statsUnit* : ARRAY 16 OF CHAR;

		(** If TRUE and 'max' # 0, the statistics values will also be shown as percent of 'max'			*)
		(** Default: FALSE																			*)
		showPercent* : BOOLEAN;

		(** If TRUE and ~perSecond, the sum of all values will be displayed. Default: FALSE				*)
		showSum* : BOOLEAN;

		(** Shall the counter be hidden/excluded  from updater.GetPlugins & SelectionWindow? 		*)
		(** Default: FALSE																			*)
		hide* : BOOLEAN;

		(** Optional list of helper objects															*)
		helper* : Helper;

	END;

TYPE

	Plugin* = OBJECT
	VAR
		(** Plugins update this data set in the UpdateDataset procedure *)
		dataset- : Dataset;

		(** Parameters mustn't be changed after a plugin instance is created  *)
		p- : Parameter;

		datamodel- : WMDiagramComponents.MultiPointModel;

		active : BOOLEAN; (* Update counter / display? *)

		nbrOfClients : LONGINT;

		currentDataset : Dataset; (* Most recent  averaged values *)
		sample, nbrOfSamples, nbrOfValidSamples : LONGINT;
		samples : POINTER TO ARRAY OF Dataset;

		milliTimer : Kernel.MilliTimer;
		lastDataset, temp : Dataset;

		isFirstUpdate : BOOLEAN;

		dimensions : LONGINT;

		link : Plugin;

		(** Plugin interface to be implemented *)

		(** Update Plugin.dataset value(s) *)
		PROCEDURE UpdateDataset*;
		BEGIN
			HALT(301); (* abstract *)
		END UpdateDataset;

		(* Called by constructor after panel has been created for plugin specific initialization *)
		PROCEDURE Init*(p : Parameter);
		BEGIN
			HALT(301); (* abstract *)
		END Init;

		PROCEDURE IncNbrOfClients*;
		BEGIN {EXCLUSIVE}
			IF (nbrOfClients = 0) THEN
				IF ~IsActive() THEN
					SetActive(TRUE);
				END;
			END;
			INC(nbrOfClients);
		END IncNbrOfClients;

		PROCEDURE DecNbrOfClients*;
		BEGIN {EXCLUSIVE}
			DEC(nbrOfClients);
			IF nbrOfClients < 0 THEN
				KernelLog.String("WMPerfMonPlugins: Warning: NbrOfClients < 0"); KernelLog.Ln;
				nbrOfClients := 0;
			END;
			IF (nbrOfClients = 0) THEN
				IF IsActive() THEN
					SetActive(FALSE);
				END;
			END;
		END DecNbrOfClients;

		(** Active sampling for this plugin *)
		PROCEDURE SetActive*(active : BOOLEAN);
		BEGIN
			IF active THEN
				UpdateDataset;
				CopyDataset(dataset, lastDataset);
				SELF.active := TRUE;
			ELSE
				SELF.active := FALSE;
			END;
			updater.NotifyListeners({EventPluginsChanged}, 0);
		END SetActive;

		(** Is sampling activated for this plugin? *)
		PROCEDURE IsActive*() : BOOLEAN;
		BEGIN
			RETURN active;
		END IsActive;

		(** Reset data model *)
		PROCEDURE Reset*;
		BEGIN
			datamodel.Acquire; datamodel.Reset; datamodel.Release;
		END Reset;

		PROCEDURE SetSampleBufferSize*(size : LONGINT);
		VAR i : LONGINT;
		BEGIN (* no concurrency allowed, Plugin.Update may not called at the same time *)
			IF p.noSuperSampling THEN size := 1; END;
			sample := 0; nbrOfValidSamples := 0;
			nbrOfSamples := size;
			NEW(samples, nbrOfSamples);
			FOR i := 0 TO nbrOfSamples-1 DO NEW(samples[i], dimensions); END;
		END SetSampleBufferSize;

		PROCEDURE Finalize*;
		BEGIN
			updater.RemovePlugin(SELF);
		END Finalize;

		PROCEDURE Update;
		VAR i, dim, dTime : LONGINT; sum: REAL;
		BEGIN
			dTime := Kernel.Elapsed(milliTimer);
			Kernel.SetTimer(milliTimer, 0);

			UpdateDataset;

			IF ~isFirstUpdate THEN
				IF p.perSecond & (dTime # 0) THEN
					FOR dim := 0 TO dimensions-1 DO
						temp[dim] := (dataset[dim] - lastDataset[dim]) * (Kernel.Second / dTime);
						lastDataset[dim] := dataset[dim]; dataset[dim] := temp[dim];
					END;
				END;

				IF nbrOfValidSamples < nbrOfSamples THEN INC(nbrOfValidSamples); END;

				FOR dim := 0 TO dimensions-1 DO
					samples[sample][dim] := dataset[dim];
					sum := 0;
					FOR i := 0 TO nbrOfValidSamples-1 DO sum := sum + samples[i][dim]; END;
					currentDataset[dim] := sum / nbrOfValidSamples;
				END;
				sample := (sample + 1) MOD nbrOfSamples;
			ELSE
				isFirstUpdate := FALSE;
			END;
		END Update;

		PROCEDURE UpdateScreen;
		BEGIN
			datamodel.Acquire; datamodel.PutValues(currentDataset); datamodel.Release;
		END UpdateScreen;

		PROCEDURE CopyDataset(source : Dataset; VAR target : Dataset);
		VAR dim : LONGINT;
		BEGIN
			FOR dim := 0 TO dimensions-1 DO target[dim] := source[dim]; END;
		END CopyDataset;

		PROCEDURE Show;
		BEGIN
			KernelLog.String(p.name); KernelLog.String(" ("); KernelLog.String(p.description); KernelLog.String(")");
			IF p.devicename # "" THEN KernelLog.String(" on "); KernelLog.String(p.devicename); END;
			IF p.modulename # "" THEN KernelLog.String(" defined in "); KernelLog.String(p.modulename); END; KernelLog.Char(" ");
			IF active THEN KernelLog.String("[active]"); END;
			IF p.hide THEN KernelLog.String("[hidden]"); END;
		END Show;

		PROCEDURE EvaluateParameter(p : Parameter);
		CONST Decrement = 35;
		VAR r, g, b, a, i, round : LONGINT;
		BEGIN
			IF (p.scale = 0) & (p.statsUnit = "")  THEN COPY(p.unit, p.statsUnit); END;
			IF p.scale = 0 THEN p.scale := 1.0; END;
			IF p.datasetDescriptor = NIL THEN
				NEW(p.datasetDescriptor, 1);
				p.datasetDescriptor[0].name := "Default";
				p.datasetDescriptor[0].color := WMGraphics.Red;
				dimensions := 1;
			ELSE
				IF (LEN(p.datasetDescriptor) > 0) & (p.datasetDescriptor[0].color = 0) THEN p.datasetDescriptor[0].color := WMGraphics.Yellow; END;
				IF (LEN(p.datasetDescriptor) > 1) & (p.datasetDescriptor[1].color = 0) THEN p.datasetDescriptor[1].color := WMGraphics.Green; END;
				IF (LEN(p.datasetDescriptor) > 2) & (p.datasetDescriptor[2].color = 0) THEN p.datasetDescriptor[2].color := WMGraphics.Red; END;
				IF (LEN(p.datasetDescriptor) > 3) THEN
					round := 0;
					r := 255; g := 255; b := 255; a := 200;
					FOR i := 3 TO LEN(p.datasetDescriptor)-1 DO
						IF round = 0 THEN
							p.datasetDescriptor[i].color := WMGraphics.RGBAToColor(r, g, b, a);
						ELSIF round = 1 THEN
							p.datasetDescriptor[i].color := WMGraphics.RGBAToColor(g, r, b, a);
						ELSE
							p.datasetDescriptor[i].color := WMGraphics.RGBAToColor(b, g, r, a);
						END;
						IF (r - Decrement > 0) THEN DEC(r, Decrement);
						ELSIF (g - 2*Decrement > 0) THEN DEC(g, Decrement);
						ELSIF (b - 3*Decrement > 0) THEN DEC(b, Decrement);
						ELSE
							INC(round);
							r := 255; g := 255; b := 255;
						END;
					END;
				END;
				dimensions := LEN(p.datasetDescriptor);
			END;
			NEW(datamodel, 1024, dimensions);
			datamodel.SetDescriptor(p.datasetDescriptor);
		END EvaluateParameter;

		PROCEDURE &New*(p : Parameter);
		BEGIN
			ASSERT(p # NIL); SELF.p := p; active := FALSE;
			isFirstUpdate := TRUE;
			Kernel.SetTimer(milliTimer, 0);
			Init(p);
			EvaluateParameter(p);
			NEW(temp, dimensions);
			NEW(dataset, dimensions); NEW(lastDataset, dimensions); NEW(currentDataset, dimensions);
			updater.AddPlugin(SELF);
		END New;

	END Plugin;

TYPE

	(**
	 * Plugins may optionally use helper objects. Idea: If the sampling of a value is expensive in terms of
	 * required computational power/memory, and this value is used by multiple plugins, the plugins may share
	 * a single implementation/instance of the updater for this value.
	 * The value will be only sampled once in an entire update loop.
	 *)
	Helper* = OBJECT
	VAR
		next : Helper;
		updated : BOOLEAN;

		PROCEDURE Update*;
		BEGIN
			HALT(301); (* abstract *)
		END Update;

	END Helper;

TYPE

	(* Notifies listener about current CPU time usage of updater thread and changes of the plugin list *)
	Notifier = PROCEDURE {DELEGATE} (events : SET; perf : REAL);

	Notifiers = POINTER TO RECORD
		events : SET;
		proc : Notifier;
		next : Notifiers;
	END;

	PluginArray* = POINTER TO ARRAY OF Plugin;

	(* This object...
	 * 	- maintains a list of all plugin instances
	 *	- updates all plugins periodically (value/screen at separate update intervals) & manages size of sampling buffers
	 *	- is a singleton
	 *)
	 Updater = OBJECT
	 VAR
	 	sampleInterval- : LONGINT; (* ms *)
	 	sampleBufferSize- : LONGINT; (* samples *)
	 	screenInterval- : LONGINT; (* ms *)

	 	plugins : Plugin;
	 	notifiers : Notifiers;

	 	(* Fields related to CPU time consumption calculation of the Updater obj *)
	 	lastCycles, lastTimestamp : HUGEINT;
	 	sample : LONGINT; sampleBuffer : POINTER TO ARRAY OF REAL;
	 	me : Objects.Process; (* Process associated to this active object *)

	 	milliTimer : Kernel.MilliTimer;
		left, samplingLeft : LONGINT;
		screenTimer : Kernel.MilliTimer;
		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE AddListener*(events : SET; proc : Notifier);
		VAR nr : Notifiers;
		BEGIN {EXCLUSIVE}
			ASSERT(proc # NIL);
			NEW(nr); nr.proc := proc; nr.events := events;
			nr.next := notifiers.next; notifiers.next := nr;
		END AddListener;

		PROCEDURE RemoveListener*(proc : Notifier);
		VAR n : Notifiers;
		BEGIN {EXCLUSIVE}
			n := notifiers;
			WHILE n.next # NIL DO
				IF (n.next.proc = proc) THEN
					n.next := n.next.next;
				ELSE
					n := n.next;
				END;
			END;
		END RemoveListener;

		PROCEDURE NotifyListeners*(events : SET; perf : REAL);
		VAR n : Notifiers;
		BEGIN
			n := notifiers.next;
			WHILE n # NIL DO
				IF n.events * events # {} THEN
					n.proc(events, perf);
				END;
				n := n.next;
			END;
		END NotifyListeners;

		PROCEDURE GetByFullname*(CONST fullname : ARRAY OF CHAR; VAR index : LONGINT; VAR msg : ARRAY OF CHAR) : Plugin;
		VAR plugin : Plugin; sa : Strings.StringArray; name : Name; i : LONGINT;
		BEGIN {EXCLUSIVE}
			msg := "";
			sa := Strings.Split(fullname, ".");
			IF LEN(sa) = 2 THEN
				COPY(sa[0]^, name);
				plugin := GetByNameX(name, "");
				IF plugin # NIL THEN
					i := 0; WHILE (i < LEN(plugin.p.datasetDescriptor)) & (plugin.p.datasetDescriptor[i].name # sa[1]^)  DO INC(i); END;
					IF (i < LEN(plugin.p.datasetDescriptor)) THEN
						index := i;
					ELSE
						plugin := NIL;
						msg := "Data not found";
					END;
				ELSE
					msg := "Plugin not found";
				END;
			ELSE
				msg := "Incorrect fullname";
			END;
			RETURN plugin;
		END GetByFullname;

		PROCEDURE GetByName*(CONST name : Name; CONST devicename : DeviceName) : Plugin;
		BEGIN {EXCLUSIVE}
			RETURN GetByNameX(name, devicename);
		END GetByName;

		PROCEDURE GetByNameX(CONST name : Name; CONST devicename : DeviceName) : Plugin;
		VAR p : Plugin;
		BEGIN
			p := plugins;
			WHILE p # NIL DO
				IF (p.p.name = name) & (p.p.devicename = devicename) THEN
					RETURN p;
				END;
				p := p.link;
			END;
			RETURN NIL;
		END GetByNameX;

		PROCEDURE RemoveByName*(CONST name : Name; CONST devicename : DeviceName);
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			p := plugins; WHILE (p # NIL) & ~((p.p.name = name) & (p.p.devicename = devicename)) DO p := p.link; END;
			IF p # NIL THEN RemovePluginIntern(p);
			ELSE KernelLog.String("WMCounters: Could not remove plugin "); KernelLog.String(name); KernelLog.Ln;
			END;
		END RemoveByName;

		(** Removes all plugins whose modulename parameter matches the specified modulename *)
		PROCEDURE RemoveByModuleName*(CONST modulename : ARRAY OF CHAR);
		VAR p : Plugin; removed : BOOLEAN;
		BEGIN {EXCLUSIVE}
			LOOP
				removed := FALSE;
				p := plugins; WHILE (p # NIL) & ~(p.p.modulename = modulename) DO p := p.link; END;
				IF p # NIL THEN
					removed := TRUE;
					RemovePluginIntern(p);
				END;
				IF removed = FALSE THEN EXIT; END;
			END;
		END RemoveByModuleName;

		PROCEDURE RemovePlugin*(p : Plugin);
		BEGIN {EXCLUSIVE}
			RemovePluginIntern(p);
		END RemovePlugin;

		PROCEDURE RemovePluginIntern(p : Plugin);
		VAR temp : Plugin; removed : BOOLEAN;
		BEGIN
			IF Verbose THEN KernelLog.String("WMPerfMon: Removing counter "); p.Show;KernelLog.Ln; END;
			IF plugins = p THEN
				plugins := plugins.link; removed := TRUE;
			ELSE
				temp := plugins; WHILE(temp # NIL) & (temp.link # p) DO temp := temp.link; END;
				IF temp # NIL THEN
					temp.link := temp.link.link;
					removed := TRUE;
				END;
			END;
			IF removed THEN
				NotifyListeners({EventPluginsChanged}, 0);
				DEC(NnofPlugins);
				IF p.p.datasetDescriptor # NIL THEN
					DEC(NnofValues, LEN(p.p.datasetDescriptor));
				ELSE
					DEC(NnofValues);
				END;
			END;
		END RemovePluginIntern;

		(** Will not return hidden plugins *)
		PROCEDURE GetPlugins*() : PluginArray;
		VAR p : Plugin; nbrOfPlugins, i : LONGINT; ca : PluginArray;
		BEGIN {EXCLUSIVE}
			IF plugins # NIL THEN
				(* determine size of array *)
				p := plugins; nbrOfPlugins := 0;
				WHILE p # NIL DO
					IF ~p.p.hide THEN INC(nbrOfPlugins); END;
					p := p.link;
				END;
				(* fill array *)
				NEW(ca, nbrOfPlugins);
				p := plugins; i := 0;
				WHILE p # NIL DO
					IF ~p.p.hide THEN ca[i] := p; INC(i); END;
					p := p.link;
				END;
			END;
			RETURN ca;
		END GetPlugins;

		(** Clear statistics of all plugins *)
		PROCEDURE ClearAll*;
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			p := plugins; WHILE p # NIL DO p.Reset; p := p.link; END;
		END ClearAll;

		PROCEDURE Show;
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			KernelLog.String("WMPerfMon: ");
			IF plugins = NIL THEN
				KernelLog.String("No counters installed."); KernelLog.Ln;
			ELSE
				KernelLog.Ln;
				p := plugins; WHILE p # NIL DO p.Show; KernelLog.Ln; p := p.link; END;
			END;
		END Show;

		PROCEDURE SetIntervals*(VAR sampleInterval, sampleBufferSize, screenInterval : LONGINT);
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			IF sampleInterval < 1 THEN sampleInterval := 1; END;
			IF screenInterval < sampleInterval THEN screenInterval := sampleInterval; END;

			IF sampleBufferSize < screenInterval DIV sampleInterval THEN
				sampleBufferSize := screenInterval DIV sampleInterval;
			END;
			ASSERT(sampleBufferSize > 0);

			SELF.sampleInterval := sampleInterval;
			SELF.screenInterval := screenInterval;
			IF sampleBufferSize # SELF.sampleBufferSize THEN
				SELF.sampleBufferSize := sampleBufferSize;
				p := plugins; WHILE p # NIL DO p.SetSampleBufferSize(sampleBufferSize); p := p.link; END;
				NEW(sampleBuffer, sampleBufferSize);
			END;
			NotifyListeners({EventParametersChanged}, 0);
			Kernel.SetTimer(screenTimer, 1);
			timer.Wakeup;
		END SetIntervals;

		PROCEDURE AddPlugin(plugin : Plugin);
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			IF Verbose THEN KernelLog.String("WMPerfMon: Adding counter "); plugin.Show; KernelLog.Ln; END;
			plugin.link := NIL;
			IF (plugins = NIL) THEN
				plugins := plugin;
			ELSE
				p := plugins; WHILE (p.link # NIL) DO p := p.link; END;
				p.link := plugin;
			END;
			plugin.SetSampleBufferSize(sampleBufferSize);
			INC(NnofPlugins);
			IF plugin.p.datasetDescriptor # NIL THEN
				INC(NnofValues, LEN(plugin.p.datasetDescriptor));
			ELSE
				INC(NnofValues);
			END;
			NotifyListeners({EventPluginsChanged}, 0);
		END AddPlugin;

		PROCEDURE UpdatePlugin(p : Plugin);
		BEGIN
			IF p.p.helper # NIL THEN UpdateHelpers(p.p.helper); END;
			p.Update;
		END UpdatePlugin;

		(* Updates plugin counter values / screen representation *)
		PROCEDURE UpdatePlugins(screen : BOOLEAN);
		VAR p : Plugin;
		BEGIN {EXCLUSIVE}
			p := plugins;
			WHILE alive & (p # NIL) DO
				IF p.active THEN
					IF screen THEN
						IF p.p.noSuperSampling THEN
							UpdatePlugin(p);
						END;
						p.UpdateScreen;
					ELSE
						IF ~p.p.noSuperSampling THEN
							UpdatePlugin(p);
						END;
					END;
				END;
				p := p.link;
			END;
		END UpdatePlugins;

		PROCEDURE UpdateHelpers(h : Helper);
		BEGIN (* Caller holds obj lock *)
			WHILE alive & (h # NIL) DO
				IF ~h.updated THEN h.Update; h.updated := TRUE; END;
				h := h.next;
			END;
		END UpdateHelpers;

		(* Sets the update field of all helpers to FALSE *)
		PROCEDURE ResetHelpers;
		VAR p : Plugin; h : Helper;
		BEGIN
			p := plugins;
			WHILE p # NIL DO
				h := p.p.helper;
				WHILE h # NIL DO
					h.updated := FALSE;
					h := h.next;
				END;
				p := p.link;
			END;
		END ResetHelpers;

		(* Calculates % CPU time consumed by this process. Updates field perf *)
		PROCEDURE UpdatePerf;
		VAR timestamp, cycles : HUGEINT; cpuCycles : Objects.CpuCyclesArray; i : LONGINT; value, sum : REAL;
		BEGIN {EXCLUSIVE}
			timestamp := Machine.GetTimer();
			IF lastTimestamp # 0 THEN
				Objects.GetCpuCycles(me, cpuCycles, TRUE);
				FOR i := 0 TO LEN(cpuCycles)-1 DO INC (cycles , cpuCycles[i]); END;
				value := SHORT(100.0 * LONGREAL(cycles - lastCycles) / LONGREAL(timestamp - lastTimestamp));
				sampleBuffer[sample MOD sampleBufferSize] := value; INC(sample);
				lastCycles := cycles;
				FOR i := 0 TO sampleBufferSize-1 DO sum := sum + sampleBuffer[i]; END;
				value := sum / sampleBufferSize;
				NotifyListeners({EventPerfUpdate}, value);
			END;
			lastTimestamp := timestamp;
		END UpdatePerf;

		PROCEDURE Terminate;
		BEGIN
			alive := FALSE; timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Terminate;

		PROCEDURE &New*;
		BEGIN
			NEW(timer); alive := TRUE; dead := FALSE;
			sampleInterval := DefaultSampleInterval;
			sampleBufferSize := DefaultSampleBufferSize;
			screenInterval := DefaultScreenRefresh;
			NEW(sampleBuffer, sampleBufferSize);
			NEW(notifiers); (* head of list *)
		END New;

	 BEGIN {ACTIVE, PRIORITY(Objects.High)}
		me := Objects.CurrentProcess();
		Kernel.SetTimer(screenTimer, screenInterval);
		WHILE alive DO
			Kernel.SetTimer(milliTimer, sampleInterval);

			(* Sampling: sample values of all plugins *)
			UpdatePlugins(FALSE);
			ResetHelpers;

			samplingLeft := Kernel.Left(milliTimer); IF samplingLeft < 0 THEN samplingLeft  := 0; END;
			left := Kernel.Left(screenTimer); IF (left < 0) THEN left := 0; END;

			IF left <= samplingLeft THEN (* screen refresh before next sample update (or now) *)
				IF left > 0 THEN timer.Sleep(left); END;
				UpdatePlugins(TRUE);
				Kernel.SetTimer(screenTimer, screenInterval);
			END;

			NotifyListeners({EventSampleLoopDone}, 0);

			(* Determine how much cpu cycles have been used by this process *)
			UpdatePerf;

			samplingLeft := Kernel.Left(milliTimer);
			IF alive & (samplingLeft > 0) THEN timer.Sleep(samplingLeft); END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Updater;

VAR
	updater- : Updater;

	(* statistics *)
	NnofPlugins-, NnofValues- : LONGINT;

(**	Estimate the processors clock rate.
	This is done by measuring the number of clock cycles within a time interval of 1 second.
	Note: While the GC is running, all interrupts are masked. Therefore, also Objects.ticks is
	not updated which makes the measurement unaccurate.
	@param clockrate: Estimated clockrate in MHz
	@return: TRUE, if the estimation can be considered accurate, FALSE otherwise
*)
PROCEDURE EstimateCpuClockrate*(VAR clockrate : LONGINT) : BOOLEAN;
VAR
	timer : Kernel.Timer; milliTimer : Kernel.MilliTimer;
	startTime, endTime, timeDiff : HUGEINT;
	nbrOfGcRuns : LONGINT;
BEGIN
	NEW(timer); nbrOfGcRuns := Heaps.Ngc;
	Kernel.SetTimer(milliTimer, 1000);
	startTime := Machine.GetTimer();
	WHILE ~Kernel.Expired(milliTimer) DO
		timer.Sleep(1);
		IF nbrOfGcRuns # Heaps.Ngc THEN RETURN FALSE; END;
	END;
	endTime := Machine.GetTimer();
	IF nbrOfGcRuns # Heaps.Ngc THEN RETURN FALSE; END;
	timeDiff := endTime - startTime;
	clockrate := SHORT (timeDiff DIV (1000*1000));
	RETURN TRUE;
END EstimateCpuClockrate;

(** Convert number of cycles (high-res timer) to milliseconds
	@param cycles: Number of cycles
	@param mhz: CPU clockrate in MHz
	@return: Number of milliseconds
*)
PROCEDURE CyclesToMs*(cycles : HUGEINT; mhz : LONGINT) : LONGINT;
BEGIN
	RETURN SHORT (cycles DIV (1000*mhz));
END CyclesToMs;

(** Convert number of milliseconds into string of the form d:h:m:s if m >= 1 or x.xxxs if m < 1*)
PROCEDURE MsToString*(ms : LONGINT; VAR string : ARRAY OF CHAR);
CONST Day=24*60*60*1000; Hour = 60*60*1000; Minute = 60*1000; Second = 1000; Millisecond = 1;

	PROCEDURE Append(divisor : LONGINT; CONST unit : ARRAY OF CHAR);
	VAR nbr : ARRAY 16 OF CHAR; val : LONGINT;
	BEGIN
		val := ms DIV divisor; ms := ms MOD divisor;
		Strings.IntToStr(val, nbr); Strings.Append(string, nbr); Strings.Append(string, unit);
	END Append;

BEGIN
	string := "";
	IF ms >= Minute THEN (* d:h:m:s *)
		IF ms >= Day THEN Append(Day, "d "); END;
		IF ms >= Hour THEN Append(Hour, "h "); END;
		IF ms >= Minute THEN Append(Minute, "m "); END;
		IF ms >= Second THEN Append(Second, "s"); END;
	ELSE (* x.xxxs *)
		Append(Second, "."); Append(100, ""); Append(10, ""); Append(Millisecond, "s");
	END;
END MsToString;

PROCEDURE GetNameDesc*(plugin : Plugins.Plugin; VAR devicename : DeviceName);
BEGIN
	COPY(plugin.name, devicename);
	Strings.Append(devicename, " ("); Strings.Append(devicename, plugin.desc); Strings.Append(devicename, ")");
END GetNameDesc;

(** Show all currently installed performance counters *)
PROCEDURE Show*(context : Commands.Context);
BEGIN
	updater.Show;
END Show;

PROCEDURE LoadPlugin(CONST name : ARRAY OF CHAR);
VAR loaderProc : PluginLoader; msg : Events.Message;
BEGIN
	GETPROCEDURE(name, "Install", loaderProc);
	IF (loaderProc # NIL) THEN
		loaderProc;
	ELSE
		msg := "Could not load plugin "; Strings.Append(msg, name); Strings.Append(msg, " - Install command not found");
		Events.AddEvent("WMPerfMonPlugins", Events.Error, 2, 1, 0, msg, TRUE);
	END;
END LoadPlugin;

PROCEDURE LoadConfiguration;
VAR elem : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; string : XML.String;
BEGIN
	elem := Configuration.GetSection("Applications.Performance Monitor.Plugins");
	IF elem # NIL THEN
		enum := elem.GetContents(); enum.Reset;
		WHILE enum.HasMoreElements() DO
			ptr := enum.GetNext();
			IF ptr IS XML.Element THEN
				string := ptr(XML.Element).GetAttributeValue("value");
				IF (string # NIL) THEN
					IF Strings.Match("TRUE", string^) THEN
						string := ptr(XML.Element).GetAttributeValue("name");
						IF (string # NIL) THEN
							LoadPlugin(string^);
						END;
					END;
				END;
			END;
		END;
	ELSE KernelLog.String("WMPerfMon: Warning: Section 'Applications.Performance Monitor.Plugins' not found in config file."); KernelLog.Ln;
	END;
END LoadConfiguration;

PROCEDURE Cleanup;
BEGIN
	updater.Terminate;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(updater);
	LoadConfiguration;
END WMPerfMonPlugins.
