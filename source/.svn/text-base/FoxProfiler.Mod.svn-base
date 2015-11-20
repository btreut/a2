MODULE FoxProfiler; (** AUTHOR "fof"; PURPOSE "minimal implementation of a compiler supported profiler"; *)

IMPORT KernelLog,Objects,Machine,SYSTEM,Streams,Commands;

CONST
	TraceAdd=FALSE;
	TraceEnter=FALSE;
	MaxModules=1024;
	MaxProcedures=1024;
	MaxProcesses=1024;
	MaxStackSize=1024;

TYPE
	Name = ARRAY 128 OF CHAR;
	Procedures = POINTER TO ARRAY OF Name;
	Modules= ARRAY MaxModules OF Procedures;

	ProcedureTime= RECORD
		calls:LONGINT;
		time,brut: HUGEINT;
	END;
	ProcedureTimes= ARRAY MaxProcedures OF ProcedureTime;

	Process= OBJECT
	VAR
		stackPosition: LONGINT;
		startTime, correcture: ARRAY MaxStackSize OF HUGEINT; (* correcture: time taken for calls to other profiled procedures *)
		module, procedure: ARRAY MaxStackSize OF LONGINT;
		modules: ARRAY MaxModules OF ProcedureTimes;

		PROCEDURE &Init;
		VAR i,j: LONGINT;
		BEGIN
			stackPosition := 0;
			FOR i := 0 TO LEN(modules)-1 DO
				FOR j := 0 TO LEN(modules[i])-1 DO
					modules[i,j].calls := 0;
					modules[i,j].time := 0;
				END;
			END;
		END Init;

		PROCEDURE Enter(moduleId, procedureId: LONGINT; enterTime: HUGEINT);
		BEGIN
			IF TraceEnter THEN log.String("stack position "); log.Int(stackPosition,1); log.Ln; END;
			IF stackPosition < MaxStackSize THEN
				startTime[stackPosition] := GetTimer();
				correcture[stackPosition] := 0;

				(* debugging *)
				module[stackPosition] := moduleId;
				procedure[stackPosition] := procedureId;

				(* book keeping for caller *)
				IF stackPosition > 0 THEN
					(* try to remove time spent in profiler *)
					INC(correcture[stackPosition-1], startTime[stackPosition] -enterTime);
				END;
			END;
			IF (moduleId < MaxModules) & (procedureId < MaxProcedures) THEN
				INC(modules[moduleId,procedureId].calls);
			END;
			INC(stackPosition);
		END Enter;

		PROCEDURE Exit(moduleId, procedureId: LONGINT; enterTime: HUGEINT);
		BEGIN
			DEC(stackPosition);
			IF stackPosition < MaxStackSize THEN
				IF (moduleId < MaxModules) & (procedureId < MaxProcedures) THEN
					INC(modules[moduleId,procedureId].time,enterTime-startTime[stackPosition]-correcture[stackPosition]);
					INC(modules[moduleId,procedureId].brut,enterTime-startTime[stackPosition]);
				END;
				IF stackPosition > 0 THEN
					(* try to remove time spent in procedure plus time spent in profiler *)
					INC(correcture[stackPosition-1], GetTimer()-startTime[stackPosition]);
				END;
				ASSERT(stackPosition >= 0);
				ASSERT(module[stackPosition] = moduleId);
				ASSERT(procedure[stackPosition] = procedureId);
			END;
			IF TraceEnter THEN log.String("stack position "); log.Int(stackPosition,1); log.Ln; END;
		END Exit;

	END Process;

	HashEntryInt = RECORD
		used: BOOLEAN; key, value: LONGINT;
	END;
	HashIntArray = ARRAY 2*MaxProcesses OF HashEntryInt


VAR
	(* modules *)
	modules:Modules;
	numberModules: LONGINT;
	(* process hash table *)
	table: HashIntArray;
	numberProcesses: LONGINT;
	processes: ARRAY MaxProcesses OF Process;
	(* logging *)
	log: Streams.Writer;
	(* timing *)
	frequency: LONGREAL; n: LONGINT;

	PROCEDURE Put*(key, value: LONGINT);
	VAR hash: LONGINT;
	BEGIN
		ASSERT(numberProcesses < LEN(table),5000);
		hash := HashValue(key);
		IF table[hash].used THEN
			ASSERT(table[hash].key = key,5001);
		END;
		table[hash].key := key;
		table[hash].value := value;
		table[hash].used := TRUE;
	END Put;

	PROCEDURE Get*(key: LONGINT):LONGINT;
	BEGIN
		RETURN table[HashValue(key)].value;
	END Get;

	PROCEDURE Has*(key: LONGINT):BOOLEAN;
	BEGIN
		RETURN table[HashValue(key)].used;
	END Has;

	PROCEDURE HashValue(key: LONGINT):LONGINT;
	VAR value, h1, h2, i: LONGINT;
	BEGIN
		value :=key;
		i := 0;
		h1 := value MOD LEN(table);
		h2 := 1; (* Linear probing *)
		REPEAT
			value := (h1 + i*h2) MOD LEN(table);
			INC(i);
		UNTIL((~table[value].used) OR (table[value].key = key) OR (i >= LEN(table)));
		ASSERT(i<LEN(table),5002);
		RETURN value;
	END HashValue;

	PROCEDURE GetProcess(): Process;
	VAR process: ANY; value: LONGINT; key: ADDRESS;
	BEGIN
		process := Objects.ActiveObject();
		key := SYSTEM.VAL(ADDRESS,process) DIV SIZEOF(ADDRESS);
		IF Has(key) THEN
			value := Get(key);
		ELSE
			BEGIN{EXCLUSIVE}
				value := numberProcesses; INC(numberProcesses);
				NEW(processes[value]);
				Put(key,value);
			END;
		END;
		RETURN processes[value]
	END GetProcess;

	PROCEDURE AddModule*(VAR moduleId: LONGINT; procedures: LONGINT; CONST name: ARRAY OF CHAR);
	BEGIN{EXCLUSIVE}
		IF TraceAdd THEN
			log.String("Add Module: "); log.String(name); log.String(", #procs: "); log.Int(procedures,1);
			log.String(", id: "); log.Int(numberModules,1); log.Ln; log.Update;
		END;
		moduleId := numberModules; NEW(modules[moduleId],procedures);
		INC(numberModules);
	END AddModule;

	PROCEDURE AddProcedure*(moduleId, procedureId: LONGINT; CONST name: ARRAY OF CHAR);
	BEGIN
		IF TraceAdd THEN
			log.String("Add procedure: "); log.String(name); log.String(": "); log.Int(moduleId,1); log.String(","); log.Int(procedureId,1); log.Ln; log.Update;
		END;
		COPY(name,modules[moduleId,procedureId]);
	END AddProcedure;

	PROCEDURE GetTimer(): HUGEINT;
	VAR cpuCycles: Objects.CpuCyclesArray;
	BEGIN
		RETURN Objects.CurrentProcessTime();
	END GetTimer;

	PROCEDURE EnterProcedure*(moduleId, procedureId: LONGINT);
	VAR time: HUGEINT; p: Process;
	BEGIN
		time:= GetTimer();
		IF TraceEnter THEN log.String("Enter procedure: "); log.Int(moduleId,1); log.String(", "); log.Int(procedureId,1); log.Ln; log.Update 	END;
		p := GetProcess();
		p.Enter(moduleId,procedureId,time);
	END EnterProcedure;

	PROCEDURE ExitProcedure*(moduleId, procedureId: LONGINT);
	VAR time: HUGEINT; p: Process;
	BEGIN
		time:= GetTimer();
		IF TraceEnter THEN log.String("Exit procedure: "); log.Int(moduleId,1); log.String(", "); log.Int(procedureId,1); log.Ln; log.Update END;
		p := GetProcess();
		p.Exit(moduleId, procedureId, time);
	END ExitProcedure;

	PROCEDURE Initialize*;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(table)-1 DO table[i].used := FALSE END;
		numberProcesses := 0;
	END Initialize;

	PROCEDURE Report*(context: Commands.Context);
	TYPE
		Record=RECORD
			name: ARRAY 256 OF CHAR;
			calls:LONGINT; time,brut: HUGEINT
		END;
		Records=POINTER TO ARRAY OF Record;

	VAR
		i,j,k: LONGINT; records: Records; time,brut: HUGEINT; calls: LONGINT; recordNumber: LONGINT;
		option: ARRAY 32 OF CHAR;
		log: Streams.Writer;
		all,done: BOOLEAN; sort: LONGINT;

		PROCEDURE Sort(id: LONGINT);
		VAR i,j: LONGINT;
		(* stupid bubblesort *)
			PROCEDURE Swap(VAR l,r: Record);
			VAR temp: Record;
			BEGIN
				temp := l; l := r; r := temp
			END Swap;

		BEGIN
			IF id <0 THEN RETURN END;
			FOR i := 0 TO recordNumber-1 DO
				FOR j := i TO recordNumber-1 DO
					IF (id=0) & (records[j].name < records[i].name) THEN Swap(records[i],records[j])
					ELSIF (id=1) & (records[j].calls > records[i].calls) THEN Swap(records[i],records[j])
					ELSIF (id=2) & (records[j].time >records[i].time) THEN Swap(records[i],records[j])
					ELSIF (id=3) & (records[j].brut > records[i].brut) THEN Swap(records[i],records[j])
					END;
				END;
			END;
		END Sort;

		PROCEDURE String(chars: LONGINT; CONST string: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i<LEN(string)) & (i<chars) & (string[i] # 0X) DO
				log.Char(string[i]);INC(i);
			END;
			WHILE(i<chars) DO
				log.Char(" "); INC(i);
			END;
			(*log.Update;*)
		END String;

		PROCEDURE Percent(x: LONGREAL);
		BEGIN
			log.String("["); log.Int(ENTIER(x*100),2); log.String("."); log.Int(ENTIER(x*1000 +0.5) MOD 10, 1); log.String("]");
		END Percent;

	BEGIN
		sort := -1; all := FALSE; done := FALSE;
		WHILE context.arg.GetString(option) & ~done DO
			IF option = "name" THEN sort := 0
			ELSIF option = "calls" THEN sort := 1
			ELSIF option = "time" THEN sort := 2
			ELSIF option = "brut" THEN sort := 3
			ELSIF option = "all" THEN all := TRUE
			ELSE done := TRUE
			END;
		END;

		log := context.out;
		recordNumber := 0;
		FOR i := 0 TO numberModules-1 DO
			INC(recordNumber, LEN(modules[i]));
		END;
		NEW(records,recordNumber);
		recordNumber := 0;
		FOR i := 0 TO numberModules-1 DO
			FOR j := 0 TO LEN(modules[i])-1 DO
				time := 0; calls := 0; brut := 0;
				IF (i< LEN(processes[k].modules)) & (j<LEN(processes[k].modules[i])) THEN
					FOR k := 0 TO numberProcesses-1 DO
						IF processes[k] # NIL THEN
						INC(time, processes[k].modules[i,j].time);
						INC(calls, processes[k].modules[i,j].calls);
						INC(brut, processes[k].modules[i,j].brut);
						END;
					END;
				ELSE calls := -9999999
				END;
				IF (calls > 0) OR all THEN
					records[recordNumber].calls := calls;
					records[recordNumber].time := time;
					records[recordNumber].brut := brut;
					COPY(modules[i,j],records[recordNumber].name);
					INC(recordNumber)
				END;
			END;
		END;

		Sort(sort);
		log.Char(0EX);
		log.String("---  FoxProfiler timing report ----"); log.Ln;
		log.String("processes= "); log.Int(numberProcesses,1); log.Ln;
		String(80,"name"); log.Char(9X);
		String(10,"calls"); log.Char(9X);
		String(18,"time [%]"); log.Char(9X);
		String(18,"brut [%]"); log.Char(9X);
		String(10,"time/call");log.Char(9X);
		String(10,"brut/call"); log.Ln;
		time := 0;
		brut := 0;
		calls := 0;

		FOR i := 0 TO recordNumber-1 DO
			INC(time, records[i].time);
			INC(brut, records[i].brut);
			INC(calls, records[i].calls);
		END;

		FOR i := 0 TO recordNumber-1 DO
			String(80,records[i].name);
			log.Int(records[i].calls,10); log.Char(9X);
			log.Float(records[i].time / frequency,12);
			Percent(records[i].time / time);
			log.Char(9X);
			log.Float(records[i].brut / frequency,12);
			Percent(records[i].brut / brut);
			log.Char(9X);
			log.Float(records[i].time / frequency / records[i].calls,10);
			log.Char(9X);
			log.Float(records[i].brut / frequency / records[i].calls,10);
			log.Ln;
		END;
		log.Update;


		FOR k := 0 TO numberProcesses-1 DO
			IF processes[k].stackPosition # 0 THEN
				log.String("warning: process "); log.Int(k,1); log.String(" still running with a stack of "); log.Int(processes[k].stackPosition,1); log.Ln;
			END;
		END;

		log.String("---------------------------"); log.Ln;
			String(80,"SUM");
			log.Int(calls,10); log.Char(9X);
			log.Float(time / frequency,10); log.Char(9X);
			log.Float(brut / frequency,10); log.Char(9X);
			log.Float(time / frequency / calls,20);
			log.Float(brut / frequency / calls,20);
			log.Ln; log.Update;

		log.String("---------------------------"); log.Ln;
		log.Char(0FX);
		log.Update;
	END Report;

	PROCEDURE Calibrate;
	BEGIN
		frequency := Objects.TimerFrequency();
		log.Ln;  log.String( "Timer reported Frequency: " ); log.FloatFix( frequency, 5, 1,0 );
		log.Ln;  log.Update;
	END Calibrate;

	PROCEDURE Init;
	VAR i: LONGINT;
	BEGIN{EXCLUSIVE}
		FOR i := 0 TO LEN(modules)-1 DO	modules[i] := NIL	END;
		FOR i := 0 TO LEN(table)-1 DO table[i].used := FALSE END;
		numberModules := 0;
		numberProcesses := 0;
		Calibrate;
	END Init;

	PROCEDURE Reset*;
	VAR i,j,k: LONGINT;
	BEGIN{EXCLUSIVE}
		FOR i := 0 TO numberModules-1 DO
			FOR j := 0 TO LEN(modules[i])-1 DO
				IF (i< LEN(processes[k].modules)) & (j<LEN(processes[k].modules[i])) THEN
					FOR k := 0 TO numberProcesses-1 DO
						processes[k].modules[i,j].time := 0;
						processes[k].modules[i,j].calls := 0;
						processes[k].modules[i,j].brut := 0;
					END;
				END;
			END;
		END;
	END Reset;

BEGIN
	NEW(log,KernelLog.Send,1024*1024);
	Init;
END FoxProfiler.

WMUtilities.Call --font=Courier FoxProfiler.Report ~
WMUtilities.Call --font=Courier FoxProfiler.Report time ~
WMUtilities.Call --font=Courier FoxProfiler.Report calls ~
WMUtilities.Call --font=Courier FoxProfiler.Report name ~
WMUtilities.Call --font=Courier FoxProfiler.Report brut ~

WMUtilities.Call --font=Courier FoxProfiler.Report time all ~

Compiler.Compile --profile TuringCoatWnd.Mod ~
TuringCoatWnd.Open

SystemTools.Free TuringCoatWnd FoxProfiler ~

FoxProfiler.Reset
