MODULE WMPerfMonPluginMemory; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor memory utilization plugin"; *)

IMPORT
	SYSTEM, Machine, Heaps, Modules, WMPerfMonPlugins;

CONST
	ModuleName = "WMPerfMonPluginMemory";

TYPE

	(* Heaps.GetHeapInfo is a slow operation. HeapHelper provides its results to multiple plugins *)
	HeapHelper = OBJECT(WMPerfMonPlugins.Helper)
	VAR
		free, total, largest : SIZE;

		PROCEDURE Update;
		BEGIN
			Heaps.GetHeapInfo(total, free, largest);
		END Update;

	END HeapHelper;

TYPE

	HeapStats = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : HeapHelper;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Heap"; p.description := "Heap statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE; p.unit := "KB"; p.minDigits := 7;
			p.noSuperSampling := TRUE;
			p.helper := heapHelper; h := heapHelper;
			NEW(ds, 3);
			ds[0].name := "Size"; INCL(ds[0].flags, WMPerfMonPlugins.Maximum);
			ds[1].name := "Free";
			ds[2].name := "LargestBlock"; INCL(ds[2].flags, WMPerfMonPlugins.Standalone);
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := h.total DIV 1024;
			dataset[1] := h.free DIV 1024;
			dataset[2] := h.largest DIV 1024;
		END UpdateDataset;

	END HeapStats;

TYPE

	StackSize = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : HeapHelper;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "StackSize"; p.description := "Approximate size of stack"; p.modulename := ModuleName;
			p.autoMax := TRUE; p.unit := "KB"; p.minDigits := 6;
			p.noSuperSampling := TRUE;
			p.helper := heapHelper; h := heapHelper;
		END Init;

		PROCEDURE UpdateDataset;
		VAR current, totMem, lowFree, highFree : SIZE;
		BEGIN
			Machine.GetFreeK(totMem, lowFree, highFree);
			current := ((totMem - lowFree - highFree) - (h.total DIV 1024));
			dataset[0] := current;
		END UpdateDataset;

	END StackSize;

TYPE

	MemoryLoad* = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : HeapHelper;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR total, lowFree, highFree : SIZE;
		BEGIN
			p.name := "MemoryUsage"; p.description := "Stack & Heap memory usage"; p.modulename := ModuleName;
			Machine.GetFreeK(total, lowFree, highFree);
			p.max := Machine.Ensure32BitAddress (total) DIV 1024; p.autoMax := FALSE; p.unit := "MB"; p.showPercent := TRUE;
			p.scale := 1024; p.minDigits := 7; p.fraction := 0; p.statsUnit := "KB";
			p.helper := heapHelper; h := heapHelper;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR current, totMem, lowFree, highFree : SIZE;
		BEGIN
			Machine.GetFreeK(totMem, lowFree, highFree);
			(* Memory mapped for heap and stack - free memory on heap *)
			current := ((totMem - lowFree - highFree) - (h.free DIV 1024));
			dataset[0] := current / 1024;
		END UpdateDataset;

	END MemoryLoad;

VAR
	heapHelper : HeapHelper;

PROCEDURE InitPlugins;
VAR
	par : WMPerfMonPlugins.Parameter;
	hs : HeapStats; ml : MemoryLoad;
	ss : StackSize;
BEGIN
	NEW(par); NEW(hs, par);
	NEW(par); NEW(ml, par);
	NEW(par); NEW(ss, par);
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	NEW(heapHelper);
	InitPlugins;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginMemory.

WMPerfMonPluginMemory.Install ~	SystemTools.Free WMPerfMonPluginMemory ~
