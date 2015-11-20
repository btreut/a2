MODULE WMPerfMonPluginCpu; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor CPU load plugin"; *)
(**
 * History:
 *
 *	16.02.2006	First Release (staubesv)
 *	23.06.2006	Adapted to WMPerfMonPlugins (staubesv)
 *	12.03.2007	Moved CPU number detection to WMPerfMonPlugins.Mod (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, Strings, Objects, Machine, Modules;

CONST

	CpuLoadAll = 9999;

	ModuleName = "WMPerfMonPluginCpu";

TYPE

	CpuLoadHelper = OBJECT(WMPerfMonPlugins.Helper);
	VAR
		cpuLoad : ARRAY Machine.MaxCPU OF REAL; (* in % *)
		nbrOfCpus : LONGINT;

		lastTimeStamp, timestamp : HUGEINT;
		lastCycles : ARRAY Machine.MaxCPU OF HUGEINT;

		PROCEDURE Update;
		VAR cpuNbr : LONGINT; dCycles, total : LONGREAL;
		BEGIN
			timestamp := Machine.GetTimer();

			IF lastTimeStamp # 0 THEN
				total := timestamp - lastTimeStamp;
				FOR cpuNbr := 0 TO Machine.MaxCPU-1 DO
					IF Objects.idleCycles[cpuNbr] # 0 THEN
						dCycles := Objects.idleCycles[cpuNbr] - lastCycles[cpuNbr];
						cpuLoad[cpuNbr] := 100.0 - SHORT(100.0 * (dCycles / total));
					END;
				END;
			END;

			FOR cpuNbr := 0 TO Machine.MaxCPU-1 DO lastCycles[cpuNbr] := Objects.idleCycles[cpuNbr]; END;
			lastTimeStamp := timestamp;
		END Update;

		(** Return the number of CPUs *)
		PROCEDURE GetNbrOfCpus() : LONGINT;
		VAR nbrOfCpus, cpuNbr : LONGINT;
		BEGIN
			(* Determine number of CPUs *)
			nbrOfCpus := 0;
			FOR cpuNbr := 0 TO Machine.MaxCPU-1 DO
				IF Objects.idleCycles[cpuNbr] # 0 THEN
					(* TODO: Improve number of CPU detection *)
					INC(nbrOfCpus);
				END;
			END;
			RETURN nbrOfCpus;
		END GetNbrOfCpus;

		PROCEDURE &New*;
		BEGIN
			nbrOfCpus := GetNbrOfCpus();
		END New;

	END CpuLoadHelper;

TYPE

	CpuParameter* = POINTER TO RECORD (WMPerfMonPlugins.Parameter);
		processorID* : LONGINT;
	END;

	CpuLoad* = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		processorID : LONGINT;
		h : CpuLoadHelper;

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR nbr : ARRAY 4 OF CHAR;
		BEGIN
			p.name := "CPU Load"; p.description := "100% - % the idle thread is running";
			p.modulename := ModuleName;
			p.min := 0; p.max := 100; p.unit := "%"; p.minDigits := 6; p.fraction := 2;

			processorID := p(CpuParameter).processorID;
			IF processorID = CpuLoadAll THEN
				p.devicename := "All Processors";
			ELSE
				p.devicename := "";
				Strings.IntToStr(processorID, nbr);
				Strings.Append(p.devicename, "Processor P"); Strings.Append(p.devicename, nbr);
			END;

			p.helper := cpuLoadHelper; h := cpuLoadHelper;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR cpu : LONGINT; sum : REAL;
		BEGIN
			IF processorID = CpuLoadAll THEN
				FOR cpu := 0 TO Machine.MaxCPU-1 DO
					sum := sum + h.cpuLoad[cpu]
				END;
				dataset[0] := sum / h.nbrOfCpus;
			ELSE
				dataset[0] :=  h.cpuLoad[processorID];
			END;
		END UpdateDataset;

	END CpuLoad;

TYPE

	ReadyCounter = OBJECT(WMPerfMonPlugins.Plugin);

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "NumReady"; p.description := "Number of processes in ready queue";
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.minDigits := 2;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := Objects.NumReady();
		END UpdateDataset;

	END ReadyCounter;

VAR
	(* Facilitates integration into Performance Monitor application *)
	nbrOfCpus- : LONGINT;
	cpuLoadHelper : CpuLoadHelper;

PROCEDURE InitPlugins;
VAR
	readyCounter : ReadyCounter; par : WMPerfMonPlugins.Parameter;
	c : CpuLoad; cpar : CpuParameter; proc : LONGINT;
BEGIN
	NEW(par); NEW(readyCounter, par);
	NEW(cpar); cpar.processorID := 0; NEW(c, cpar);
	IF cpuLoadHelper.nbrOfCpus > 1 THEN
		FOR proc := 1 TO cpuLoadHelper.nbrOfCpus-1 DO
			NEW(cpar); cpar.processorID := proc; NEW(c, cpar);
		END;
		NEW(cpar); cpar.processorID := CpuLoadAll; NEW(c, cpar);
	END;
END InitPlugins;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	NEW(cpuLoadHelper); nbrOfCpus := cpuLoadHelper.nbrOfCpus;
	InitPlugins;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginCpu.

WMPerfMonPluginProcessors.Install ~ 	SystemTools.Free WMPerfMonPluginProcessors ~
