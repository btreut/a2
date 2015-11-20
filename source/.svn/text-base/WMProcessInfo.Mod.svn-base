MODULE WMProcessInfo; (** AUTHOR "tf/staubesv"; PURPOSE "Components for process visualization"; *)

IMPORT
	SYSTEM, KernelLog,
	Streams, Machine, Modules, Objects, Kernel, Reflection, Strings, ProcessInfo, XML, Commands,
	WMGraphics, WMProperties, WMComponents, WMStandardComponents, WMGrids, WMStringGrids,
	WMPopups, WMDialogs;

CONST

	(* ProcessSelector.sort *)
	None* = 0;
	ID* = 1;
	Priority* = 2;
	Mode* = 3;

	(* States *)
	Paused = 0; Running = 3; RunningRefresh = 4; Terminating = 99; Terminated = 100;

	DefaultRefreshInterval = 500;
	DefaultInterleave = 2;

	MaxNofProcesses = 1000;

TYPE

	Selection* = POINTER TO ARRAY OF Objects.Process;

	ProcessSelector* = OBJECT (WMComponents.VisualComponent)
	VAR
		sort- : WMProperties.Int32Property;
		sortI : LONGINT;

		processes : ARRAY MaxNofProcesses OF Objects.Process;
		nofProcesses : LONGINT;

		colWidth : WMGrids.Spacings;
		grid : WMStringGrids.StringGrid;

		lastProcTime : HUGEINT;

		sw : Streams.StringWriter; (* Only use in procedure Update *)

		nofUpdates, interval, interleave : LONGINT;

		timer : Kernel.Timer;
		state, currentState : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;

			NEW(sort, PrototypeSort, NIL, NIL); properties.Add(sort);
			sortI := sort.Get();

			ProcessInfo.Clear(processes);
			nofProcesses := 0;

			NEW(colWidth, 11);
			grid := CreateGrid();
			AddContent(grid);

			lastProcTime := Machine.GetTimer();
			NEW(sw, 128);

			nofUpdates := 0;
			interval := DefaultRefreshInterval;
			interleave := DefaultInterleave;
			NEW(timer);
			state := Paused;
		END Init;

		PROCEDURE GetSelection*() : Selection;
		VAR
			processes : ARRAY ProcessInfo.MaxNofProcesses OF Objects.Process;
			nofProcesses : LONGINT;
			scol, srow, ecol, erow, id, i : LONGINT;
			selection : Selection;
			str : Strings.String;
		BEGIN
			selection := NIL;
			grid.Acquire;
			grid.model.Acquire;
			grid.GetSelection(scol, srow, ecol, erow);
			IF (srow >= 0) & (srow <= erow) THEN
				ProcessInfo.GetProcesses(processes, nofProcesses);
				NEW(selection, erow - srow + 1);
				FOR i := srow TO erow DO
					str := grid.model.GetCellText(0, i); (* Get the Process ID *)
					Strings.StrToInt(str^, id);
					IF id > 0 THEN
						selection[i - srow] := ProcessInfo.Find(processes, id); (* may be NIL *)
					ELSE
						selection[i - srow] := NIL;
					END;
				END;
			END;
			grid.model.Release;
			grid.Release;
			RETURN selection;
		END GetSelection;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = sort) THEN
				CheckSort;
			ELSIF (property = visible) THEN
				PropertyChanged^(sender, property);
				CheckVisibility;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			CheckVisibility;
			CheckSort;
		END RecacheProperties;

		PROCEDURE CheckVisibility;
		BEGIN
			IF visible.Get() THEN Start;
			ELSE Pause;
			END;
		END CheckVisibility;

		PROCEDURE CheckSort;
		BEGIN {EXCLUSIVE}
			sortI := sort.Get();
			IF (state = Running) THEN
				state := RunningRefresh;
			END;
			timer.Wakeup;
		END CheckSort;

		PROCEDURE CreateGrid() : WMStringGrids.StringGrid;
		VAR
			grid : WMStringGrids.StringGrid;
			str : ARRAY 256 OF CHAR;
			i, dx, dy, minWidth : LONGINT;
			f : WMGraphics.Font;
		BEGIN
			NEW(grid); grid.alignment.Set(WMComponents.AlignClient);

			f := WMGraphics.GetFont("Oberon", 12, {});
			grid.fixedCols.Set(2); grid.fixedRows.Set(1);
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(11);
			grid.model.SetNofRows(2);
			f.GetStringSize("-999999999", minWidth, dy);
			FOR i := 0 TO 5 DO
				GetTitleStr(i, str);
				f.GetStringSize(str, dx, dy);
				colWidth[i] := Strings.Max(dx + 4, 30);
				grid.model.SetCellText(i, 0, Strings.NewString(str));
				grid.model.SetTextAlign(i, 0, WMGraphics.AlignCenter)
			END;
			FOR i := 6 TO 11 - 1 DO
				GetTitleStr(i, str);
				f.GetStringSize(str, dx, dy);
				colWidth[i] := Strings.Max(dx + 4, minWidth+ 40);
				grid.model.SetCellText(i, 0, Strings.NewString(str));
				grid.model.SetTextAlign(i, 0, WMGraphics.AlignCenter)
			END;
			grid.SetColSpacings(colWidth);
			grid.model.Release;
			grid.Release;
			RETURN grid;
		END CreateGrid;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			IF (state < Terminating) THEN state := Running; END;
		END Start;

		PROCEDURE Pause;
		BEGIN {EXCLUSIVE}
			IF (state < Terminating) THEN
				state := Paused;
			END;
		END Pause;

		PROCEDURE Resized;
		VAR width, height, w, add, i : LONGINT; newColWidth : WMGrids.Spacings;
		BEGIN
			width := bounds.GetWidth(); height := bounds.GetHeight();
			NEW(newColWidth, LEN(colWidth));
			FOR i := 0 TO LEN(colWidth)-1 DO
				w := w + colWidth[i];
				newColWidth[i] := colWidth[i];
			END;
			IF w < width THEN
				add := (width - w) DIV 3;
				INC(newColWidth[6], add);
				INC(newColWidth[8], add);
				INC(newColWidth[9], add);
				colWidth := newColWidth;
				grid.SetColSpacings(colWidth);
			END;
			Resized^;
		END Resized;

		PROCEDURE Update;
		VAR
			cycles : Objects.CpuCyclesArray;
			i, posP, beg : LONGINT;
			mod : Modules.Module;
			str : ARRAY 256 OF CHAR;
			t0, t1 : HUGEINT;
			pc : ADDRESS;

			PROCEDURE SetText(line, cell : LONGINT; CONST str : ARRAY OF CHAR);
			VAR s : Strings.String;
			BEGIN
				s := grid.model.GetCellText(cell, line + 1); (* recycle the string *)
				IF s = NIL THEN NEW(s, 64) END;
				COPY(str, s^);
				grid.model.SetTextAlign(cell, line + 1, GetAlign(cell));
				grid.model.SetCellText(cell, line + 1, s)
			END SetText;

		BEGIN
			t1 := Machine.GetTimer() - lastProcTime;
			lastProcTime := Machine.GetTimer();

			grid.model.Acquire;
			grid.model.SetNofRows(nofProcesses + 1);

			FOR i := 0 TO nofProcesses - 1 DO
				ASSERT(processes[i] # NIL);

				(* PID Process ID - 0 *)
				Strings.IntToStr(processes[i].id, str); SetText(i, 0, str);

				(* CPU - processor number - 1 *)
				Strings.IntToStr(processes[i].procID, str); SetText(i, 1, str);

				(* CPU% - 2 *)
				Objects.GetCpuCycles(processes[i], cycles, FALSE);
				t0 := cycles[0];
				Strings.IntToStr(SHORT ((t0 * 100) DIV t1), str);SetText(i, 2, str);


				(* priority - 3 *)
				Strings.IntToStr(processes[i].priority, str); SetText(i, 3, str);

				(* mode - 4 *)
				sw.Reset; ProcessInfo.WriteMode(processes[i].mode, sw); sw.Get(str); SetText(i, 4, str);

				(* PC - 5 *)
				IF mod # NIL THEN DEC(pc, ADDRESSOF(mod.code[0])) END;
				Strings.IntToStr(SYSTEM.VAL (LONGINT, pc), str); SetText(i, 5, str);

				(* active object type - 6 *)
				sw.Reset; ProcessInfo.WriteActiveObject(processes[i], sw); sw.Get(str);
				SetText(i, 6, str);

				(* Module - 7 *)
				pc := processes[i].state.PC;
				mod := Modules.ThisModuleByAdr(pc);
				IF mod # NIL THEN SetText(i, 7, mod.name)
				ELSE  str := "Unknown"; SetText(i, 7, str);
				END;

				(* Procedure - 8 - Module name (prefix) and "pc=xyz" (suffix) suppressed *)
				sw.Reset; Reflection.WriteProc(sw, processes[i].state.PC);
				sw.Get(str);
				IF (str # "NIL") & (mod#NIL) THEN
					posP := 0;
					REPEAT INC(posP) UNTIL  (posP=LEN(str)) OR (str[posP]=0X)  OR (str[posP] = ".");	(* Skip prefix *)
					INC(posP);
					beg := 0;
					REPEAT
						str[beg] := str[posP];
						INC(beg); INC(posP);
					UNTIL (posP=LEN(str)) OR (str[posP]=0X) OR (str[posP] = " ");	(* Here follows "pc=xyz" now suppressed *)
					str[beg] := 0X
				END;
				SetText(i, 8, str);

				(* Waiting on condition - 9 *)
				sw.Reset;  ProcessInfo.WriteWaitingOn(processes[i], sw);  sw.Get(str);
				SetText(i, 9, str);

				(* Flags - 10 *)
				sw.Reset; ProcessInfo.WriteFlags(processes[i].flags, sw); sw.Get(str);
				SetText(i, 10, str);
			END;
			grid.model.Release;
			lastProcTime := Machine.GetTimer();
		END Update;

		PROCEDURE Refresh;
		VAR proc : ProcessInfo.IsGreaterThanProc;
		BEGIN
			Acquire;
			ProcessInfo.GetProcesses(processes, nofProcesses);
			CASE sortI OF
			| ID: proc := ProcessInfo.SortByID;
			| Priority : proc := ProcessInfo.SortByPriority;
			| Mode : proc := ProcessInfo.SortByMode;
			ELSE
				proc := NIL;
			END;
			IF (proc # NIL) THEN
				ProcessInfo.Sort(processes, nofProcesses, proc);
			END;
			Release;
		END Refresh;

		PROCEDURE Finalize; (* override *)
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE}
				state := Terminating;
				timer.Wakeup
			END;
		END Finalize;

	BEGIN {ACTIVE}
		WHILE (state < Terminating) DO
			BEGIN {EXCLUSIVE}
				AWAIT(state # Paused);
				IF (state = RunningRefresh) THEN
					nofUpdates := 0; (* forces Refresh *)
					state := Running;
				END;
				currentState := state;
			END;
			IF (currentState = Running) THEN
				IF (nofUpdates MOD interleave = 0) THEN
					Refresh;
				END;
				Update;
				INC(nofUpdates);
				timer.Sleep(interval);
			ELSIF (currentState = Paused) THEN
				nofProcesses := 0; ProcessInfo.Clear(processes);
			END;
		END;
		nofProcesses := 0; ProcessInfo.Clear(processes);
		BEGIN {EXCLUSIVE} state := Terminated; END
	END ProcessSelector;

TYPE

	SortInfo = OBJECT
	VAR
		mode : LONGINT;
		name : ARRAY 64 OF CHAR;

		PROCEDURE &New*(mode : LONGINT; CONST name : ARRAY OF CHAR);
		BEGIN
			SELF.mode := mode;
			COPY(name, SELF.name);
		END New;

	END SortInfo;

TYPE

	ProcessManager* = OBJECT (WMComponents.VisualComponent)
	VAR
		processSelector : ProcessSelector;

		haltBtn, unbreakHaltBtn, sortBtn, showBtn, cpuLoadBtn : WMStandardComponents.Button;
		sortPopup : WMPopups.Popup;

		nbrOfProcessesLabel : WMStandardComponents.Label;

		toolbar- : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		VAR font : WMGraphics.Font; dx, dy : LONGINT; sortInfo : SortInfo;
		BEGIN
			Init^;
			SetNameAsString(StrProcessManager);

			NEW(toolbar);
			toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignBottom);
			AddContent(toolbar);

			NEW(haltBtn);
			haltBtn.alignment.Set(WMComponents.AlignLeft);
			haltBtn.SetCaption("Halt process");
			haltBtn.onClick.Add(HandleHalt);
			toolbar.AddContent(haltBtn);

			font := haltBtn.GetFont();
			font.GetStringSize(" Halt process ", dx, dy);
			haltBtn.bounds.SetWidth(dx);

			NEW(unbreakHaltBtn);
			unbreakHaltBtn.alignment.Set(WMComponents.AlignLeft);
			unbreakHaltBtn.SetCaption("Halt process unbreakable");
			unbreakHaltBtn.onClick.Add(HandleUnbreakableHalt);
			toolbar.AddContent(unbreakHaltBtn);

			font := unbreakHaltBtn.GetFont();
			font.GetStringSize(" Halt process unbreakable ", dx, dy);
			unbreakHaltBtn.bounds.SetWidth(dx);

			NEW(sortBtn);
			sortBtn.bounds.SetWidth(80); sortBtn.alignment.Set(WMComponents.AlignLeft);
			sortBtn.caption.SetAOC("SortBy:PID");
			sortBtn.onClick.Add(HandleSort);
			toolbar.AddContent(sortBtn);

			NEW(sortPopup);
			NEW(sortInfo, None, "SortBy:None"); sortPopup.AddParButton("None", HandleSortPopup, sortInfo);
			NEW(sortInfo, ID, "SortBy:ID"); sortPopup.AddParButton("ID", HandleSortPopup, sortInfo);
			NEW(sortInfo, Priority, "SortBy:Priority"); sortPopup.AddParButton("Priority", HandleSortPopup, sortInfo);
			NEW(sortInfo, Mode, "SortBy:Mode"); sortPopup.AddParButton("Mode", HandleSortPopup, sortInfo);

			NEW(showBtn);
			showBtn.alignment.Set(WMComponents.AlignLeft);
			showBtn.SetCaption(" Show Stack ");
			showBtn.onClick.Add(HandleShowStack);
			toolbar.AddContent(showBtn);
			font := showBtn.GetFont();
			font.GetStringSize(" Show Stack ", dx, dy);
			showBtn.bounds.SetWidth(dx);

			NEW(cpuLoadBtn); cpuLoadBtn.alignment.Set(WMComponents.AlignLeft);
			cpuLoadBtn.SetCaption("CPU Load");
			cpuLoadBtn.onClick.Add(HandleCpuLoad);
			toolbar.AddContent(cpuLoadBtn);

			NEW(nbrOfProcessesLabel);
			nbrOfProcessesLabel.alignment.Set(WMComponents.AlignClient);
			nbrOfProcessesLabel.textColor.Set(WMGraphics.White);
			toolbar.AddContent(nbrOfProcessesLabel);

			NEW(processSelector); processSelector.alignment.Set(WMComponents.AlignClient);
			AddContent(processSelector);
		END Init;

		PROCEDURE Decision(CONST message : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			RETURN WMDialogs.Confirmation("Confirm terminating process", message) = WMDialogs.ResYes;
		END Decision;

		PROCEDURE HaltThread(unbreakable : BOOLEAN);
		VAR selection : Selection; i : LONGINT;
		BEGIN
			selection := processSelector.GetSelection();
			IF (selection # NIL) THEN
				FOR i := 0 TO LEN(selection)-1 DO
					IF (selection[i] # NIL) THEN
						(* Make these checks before acquiring the locks *)
						IF (Objects.Resistant IN selection[i].flags) THEN
							IF Decision("Teminate a resistant process") THEN
								Objects.TerminateThis(selection[i], unbreakable);
							END
						ELSE
							Objects.TerminateThis(selection[i], unbreakable);
						END;
					END;
				END;
			END;
		END HaltThread;

		PROCEDURE HandleHalt(sender, data : ANY);
		BEGIN
			HaltThread(FALSE);
		END HandleHalt;

		PROCEDURE HandleUnbreakableHalt(sender, data : ANY);
		BEGIN
			HaltThread(TRUE);
		END HandleUnbreakableHalt;

		PROCEDURE HandleSort(sender, data : ANY);
		VAR gx, gy : LONGINT;
		BEGIN
			sortBtn.ToWMCoordinates(0, sortBtn.bounds.GetBottom(), gx, gy);
			sortPopup.Popup(gx, gy);
		END HandleSort;

		PROCEDURE HandleSortPopup(sender, data : ANY);
		VAR sortInfo : SortInfo;
		BEGIN
			IF (data # NIL) & (data IS SortInfo) THEN
				sortPopup.Close;
				sortInfo := data(SortInfo);
				sortBtn.caption.SetAOC(sortInfo.name);
				processSelector.sort.Set(sortInfo.mode);
			END;
		END HandleSortPopup;

		PROCEDURE HandleShowStack(sender, data : ANY);
		VAR selection : Selection; w: Streams.Writer; i : LONGINT;
		BEGIN
			selection := processSelector.GetSelection();
			IF (selection # NIL) THEN
				Streams.OpenWriter(w, KernelLog.Send);
				FOR i := 0 TO LEN(selection)-1 DO
					IF (selection[i] # NIL) THEN
						ProcessInfo.ShowStack(selection[i], w);
						w.Ln;
					END;
				END;
			END;
		END HandleShowStack;

		PROCEDURE HandleCpuLoad(sender, data : ANY);
		VAR selection : Selection; i : LONGINT;
		BEGIN
			selection := processSelector.GetSelection();
			IF (selection # NIL) THEN
				FOR i := 0 TO LEN(selection) - 1 DO
					IF (selection[i] # NIL) THEN
						OpenCpuLoadWindow(selection[i].id);
					END;
				END;
			END;
		END HandleCpuLoad;

	END ProcessManager;

VAR
	StrProcessSelector, StrProcessManager : Strings.String;
	PrototypeSort : WMProperties.Int32Property;

PROCEDURE GetTitleStr(col : LONGINT; VAR x : ARRAY OF CHAR);
BEGIN
	CASE col OF
		| 0 : COPY("PID", x)
		| 1 : COPY("CPU #", x)
		| 2 : COPY("CPU %", x)
		| 3 : COPY("Prio", x)
		| 4 : COPY("Mode", x)
		| 5 : COPY("PC", x)
		| 6 : COPY("Active Object", x)
		| 7 : COPY("Module", x)
		| 8 : COPY("Procedure", x)
		| 9 : COPY("Await condition", x)
		| 10 : COPY("Flags", x);
	ELSE COPY("", x);
	END
END GetTitleStr;

PROCEDURE GetAlign(col : LONGINT) : LONGINT;
BEGIN
	CASE col OF
		| 6, 7, 8, 9, 10 : RETURN WMGraphics.AlignLeft;
		| 3, 1 : RETURN WMGraphics.AlignCenter;
		| 0, 2, 4, 5 : RETURN WMGraphics.AlignRight;
	ELSE RETURN WMGraphics.AlignRight
	END
END GetAlign;

PROCEDURE OpenCpuLoadWindow(pid : LONGINT);
VAR commandString, msg : ARRAY 128 OF CHAR; nbr : ARRAY 16 OF CHAR; res : LONGINT;
BEGIN
	commandString := "WMPerfMonPluginProcesses.Install ";
	Strings.IntToStr(pid, nbr);
	Strings.Append(commandString, nbr);
	Commands.Call(commandString, {}, res, msg);
	IF (res # Commands.Ok) THEN
		KernelLog.String("WMProcessInfo.OpenCpuLoad: Command call failed, res = "); KernelLog.Int(res, 0);
		KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")"); KernelLog.Ln;
	END;
END OpenCpuLoadWindow;

PROCEDURE InitStrings;
BEGIN
	StrProcessSelector := Strings.NewString("ProcessSelector");
	StrProcessManager := Strings.NewString("ProcessManager");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeSort, NIL, Strings.NewString("sort"), Strings.NewString("Sort process list  by 0: None, 1: ID, 2: Priority, 3: Mode"));
	PrototypeSort.Set(ID);
END InitPrototypes;

PROCEDURE GenProcessSelector*() : XML.Element;
VAR ps : ProcessSelector;
BEGIN
	NEW(ps); RETURN ps;
END GenProcessSelector;

PROCEDURE GenProcessManager*() : XML.Element;
VAR pm : ProcessManager;
BEGIN
	NEW(pm); RETURN pm;
END GenProcessManager;

BEGIN
	InitStrings;
	InitPrototypes;
END WMProcessInfo.

SystemTools.Free WMProcessInfo ~

