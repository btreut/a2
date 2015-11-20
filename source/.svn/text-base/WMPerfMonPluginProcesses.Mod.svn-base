MODULE WMPerfMonPluginProcesses; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for processes statistics"; *)

IMPORT
	Machine, Modules, Objects, Commands, Strings, WMPerfMonPlugins, ProcessInfo;

CONST
	ModuleName = "WMPerfMonPluginProcesses";

TYPE

	ProcessStatsParameter = OBJECT(WMPerfMonPlugins.Parameter)
	VAR
		process : Objects.Process;

		PROCEDURE &Init(process : Objects.Process);
		BEGIN
			ASSERT(process # NIL);
			SELF.process := process;
		END Init;

	END ProcessStatsParameter;

	ProcessStats= OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		process : Objects.Process; (* warning: reference may keep object alive *)
		lastCycles, currentCycles : Objects.CpuCyclesArray;
		lastTimer : HUGEINT;
		lastSamplesValid : BOOLEAN;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR
			ds : WMPerfMonPlugins.DatasetDescriptor;
			name, temp : WMPerfMonPlugins.Description;
			nofProcessors, id, i : LONGINT;
		BEGIN
			ASSERT((p # NIL) & (p IS ProcessStatsParameter));
			process := p(ProcessStatsParameter).process;

			name := "P";
			Strings.IntToStr(process.id, temp); Strings.AppendX(name, temp);
			id := GetID();
			Strings.IntToStr(id, temp); Strings.AppendX(name, "_"); Strings.AppendX(name, temp);

			COPY(name, p.name);

			p.description := "Process statistics for process ";
			Strings.AppendX(p.description, name);

			p.modulename := ModuleName;
			p.min := 0; p.max := 100;
			p.autoMin := FALSE; p.autoMax := FALSE; p.minDigits := 4;

			FOR i := 0 TO Machine.MaxCPU-1 DO
				lastCycles[i] := 0;
				currentCycles[i] := 0;
			END;
			lastSamplesValid := FALSE; lastTimer := 0;

			nofProcessors := GetNofProcessors(); ASSERT(nofProcessors > 0);

			IF (nofProcessors > 1) THEN
				NEW(ds, nofProcessors + 1);
				ds[0].name := "PALL"; INCL(ds[0].flags, WMPerfMonPlugins.Sum);
				FOR i := 1 TO nofProcessors DO
					ds[i].name := "P";
					Strings.IntToStr(i - 1, temp);
					Strings.Append(ds[i].name, temp);
				END;
			ELSE
				NEW(ds, 1);
				ds[0].name := "Load";
			END;

			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset;
		VAR
			i : LONGINT; timer : HUGEINT;
			pAll, timeDiff, cyclesDiff : LONGREAL;
		BEGIN
			Objects.GetCpuCycles(process, currentCycles, TRUE);
			timer := Machine.GetTimer();
			timeDiff := timer - lastTimer;
			IF lastSamplesValid THEN
				IF (LEN(dataset) = 1) THEN
					dataset[0]  := SHORT(100.00 * LONGREAL(currentCycles[0] - lastCycles[0]) / timeDiff);
				ELSE
					pAll := 0.0;
					FOR i := 1 TO LEN(dataset)-1 DO
						cyclesDiff := currentCycles[i - 1] - lastCycles[i - 1];
						pAll := pAll + cyclesDiff;
						dataset[i] := SHORT(100.0 * cyclesDiff / timeDiff);
					END;
					dataset[0] := SHORT(100.00 * pAll / (LEN(dataset) - 1) / timeDiff);
				END;
			ELSE
				dataset[0] := 0.0;
				lastSamplesValid := TRUE;
			END;
			FOR i := 0 TO Machine.MaxCPU-1 DO
				lastCycles[i] := currentCycles[i];
			END;
			lastTimer := timer;
		END UpdateDataset;

	END ProcessStats;

VAR
	nextID, nofProcessors : LONGINT;

PROCEDURE GetID() : LONGINT;
BEGIN {EXCLUSIVE}
	INC(nextID);
	RETURN nextID;
END GetID;

(** Return the number of CPUs (stupid, but not that important) *)
PROCEDURE GetNofProcessors() : LONGINT;
BEGIN {EXCLUSIVE}
	RETURN nofProcessors;
END GetNofProcessors;

PROCEDURE SetNofProcessors*(context : Commands.Context);
VAR value : LONGINT;
BEGIN {EXCLUSIVE}
	IF context.arg.GetInteger(value, FALSE) & (value > 0) & (value <= Machine.MaxCPU) THEN
		nofProcessors := value;
		context.out.String("NofProcessors set to "); context.out.Int(nofProcessors, 0); context.out.Ln;
	ELSE
		context.error.String("Invalid value of parameter"); context.error.Ln;
	END;
END SetNofProcessors;

PROCEDURE Install*(context : Commands.Context);
VAR
	id : LONGINT;
	stats : ProcessStats; parameter : ProcessStatsParameter;
	process : Objects.Process;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(id, FALSE);
	process := ProcessInfo.GetProcess(id);
	IF (process # NIL) THEN
		NEW(parameter, process);
		NEW(stats, parameter);
		context.out.String("Plugin "); context.out.String(stats.p.name); context.out.String(" installed.");
		context.out.Ln;
	ELSE
		context.error.String("Process ID = "); context.error.Int(id, 0);
		context.error.String(" not found."); context.error.Ln;
	END;
END Install;

PROCEDURE Init;
BEGIN
	nextID := 0;
	nofProcessors := 1;
END Init;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init;
END WMPerfMonPluginProcesses.

WMPerfMonPluginProcesses.Install ~   SystemTools.Free WMPerfMonPluginProcesses ~

WMPerfMonPluginProcesses.SetNofProcessors 4 ~
