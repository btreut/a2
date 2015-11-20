MODULE WMTaskScheduler; (** AUTHOR "staubesv; minor adaptation PH"; PURPOSE "GUI for TaskScheduler"; *)
(**
Usage:
WMTaskScheduler.Open ~
-load and store task lists from GUI
-create new tasks in GUI
-edit or remove task by right-mouse-click popup
-at planned task trigger time, task signals optically and by activating icommand that was set in GUI
*)


IMPORT
	Modules, Kernel, Commands, Dates, Strings, Files, TaskScheduler,
	WMRectangles, WMGraphics, WMGraphicUtilities, WMWindowManager, WMRestorable, WMMessages,
	WMComponents, WMStandardComponents, WMEditors, WMDialogs, WMCalendar, WMDropDownLists,
	WMPopups;

CONST

	WindowWidth = 400;
	WindowHeight = 200;

	Bearing = 5;
	Border = 5;

	(* TaskView.dateStringType *)
	NotInitialized = 0;
	Today = 1;
	Tomorrow = 2;
	ThisWeek = 3;
	Date = 4;

	(* Window.selectMode *)
	Select_Today = 0;
	Select_ThisWeek = 1;
	Select_All = 2;

TYPE
	ClickInfo = OBJECT
	VAR cmd : Strings.String;
	END ClickInfo;

TYPE

	TaskView = OBJECT(WMComponents.VisualComponent)
	VAR
		task : TaskScheduler.Task;
		taskInfo : TaskScheduler.TaskInfo;
		timestamp : LONGINT;

		image : WMGraphics.Image;

		indicateTriggered : BOOLEAN;
		indicationValue : LONGINT;
		indicationStep : LONGINT;

		dateStringType : LONGINT;

		dateString : ARRAY 32 OF CHAR;
		timeString : ARRAY 32 OF CHAR;

		fontName : WMGraphics.Font;

		PROCEDURE &New(task : TaskScheduler.Task);
		BEGIN
			ASSERT(task # NIL);
			SELF.task := task;
			task.user := SELF; (* TODO: Don't store in Task object to allow multiple views... *)
			Init;
			fontName := WMGraphics.GetFont("Oberon", 12, {WMGraphics.FontBold});
			indicateTriggered := FALSE;
			indicationValue := 256;
			indicationStep := -256;
			ASSERT(indicationValue MOD ABS(indicationStep) = 0); (*PH 20110616 fix MOD by neg number*)
			fillColor.Set(WMGraphics.White);
			UpdateTaskInfo(TRUE);
		END New;

	 	PROCEDURE UpdateTaskInfo(forceUpdate : BOOLEAN);
	 	BEGIN
	 		IF forceUpdate OR (timestamp # task.timestamp) THEN
				timestamp := task.timestamp;
				taskInfo := task.GetInfo();
				IF (taskInfo.image # "") THEN
					image := WMGraphics.LoadImage(taskInfo.image, TRUE);
				ELSE
					image := DefaultImage;
				END;
				Strings.FormatDateTime("dd.mm.yyyy", taskInfo.trigger, dateString);
				Strings.FormatDateTime("hh:nn", taskInfo.trigger, timeString);
				dateStringType := Date;
			END;
	 	END UpdateTaskInfo;

		PROCEDURE GetFillColor(secondsLeft : LONGINT) : LONGINT;
		BEGIN
			RETURN WMGraphicUtilities.InterpolateColorLinear(LONGINT(0FFFF00C0H), LONGINT(0FF0000FFH), ENTIER(256 * ((3600 - secondsLeft) / 3600)));
		END GetFillColor;

		PROCEDURE GetIndicationColor() : LONGINT;
		BEGIN
			IF (indicationValue = 256) THEN
				indicationStep := -256;
			ELSIF (indicationValue = 0) THEN
				indicationStep := 256;
			END;
			indicationValue := indicationValue + indicationStep;
			RETURN WMGraphicUtilities.InterpolateColorLinear(LONGINT(0FFFF00C0H), LONGINT(0FF0000FFH), indicationValue);
		END GetIndicationColor;

		PROCEDURE Update( dt : Dates.DateTime);
		VAR
			trigger : Dates.DateTime;
			newDateString : ARRAY 32 OF CHAR;
			lastFillColor, newFillColor : LONGINT;
			days, hours, minutes, seconds : LONGINT;
		BEGIN
			COPY(dateString, newDateString);
			trigger := task.GetTrigger();

			IF (task.timestamp # timestamp) THEN
				timestamp := task.timestamp;
				dateStringType := NotInitialized; (* force invalidating of displayed date & time *)
			ELSE
				IF SameDay(trigger, dt) THEN
					IF (dateStringType # Today) THEN newDateString := "Today"; dateStringType := Today; END;
					lastFillColor := fillColor.Get();
					task.LeftFrom(dt, days, hours, minutes, seconds);
					seconds := ToSeconds(days, hours, minutes, seconds);
					IF ~indicateTriggered & (seconds < 3600) THEN
						newFillColor := GetFillColor(seconds);
						IF (seconds = 0) THEN task.TriggerNow; indicateTriggered:=TRUE END; (* what, if in this specific second, no Check was done ? *)
					ELSIF indicateTriggered & (seconds = 0) THEN
						newFillColor := GetIndicationColor();
					ELSE
						newFillColor := LONGINT(0FFFF00C0H);
					END;
					IF (newFillColor # lastFillColor) THEN
						fillColor.Set(newFillColor);
					END;
				ELSIF IsTomorrow(dt, trigger) THEN
					IF (dateStringType # Tomorrow) THEN newDateString := "Tomorrow"; dateStringType := Tomorrow; END;
					fillColor.Set(LONGINT(0EEEEFFFFH));
				ELSIF SameWeek(trigger, dt) THEN
					IF (dateStringType # ThisWeek) THEN Strings.FormatDateTime("wwww", trigger, newDateString); dateStringType := ThisWeek; END;
					fillColor.Set(LONGINT(0EEEEFFFFH));
				ELSIF (dateStringType # Date) THEN
					Strings.FormatDateTime("dd.mm.yyyy", trigger, newDateString); dateStringType := Date;
					fillColor.Set(WMGraphics.White);
				END;
			END;
			IF (newDateString # dateString) THEN
				Acquire;
				COPY(newDateString, dateString);
				Strings.FormatDateTime("hh:nn", trigger, timeString);
				Release;
				Invalidate;
			END;
		END Update;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR days, hours, minutes, seconds : LONGINT;
		BEGIN
			PointerUp^(x, y, keys);
			task.Left(days, hours, minutes, seconds);
			IF (ToSeconds(days, hours, minutes, seconds) = 0) THEN
				task.Confirm;
				indicateTriggered := FALSE;
				indicationStep := -256;
				indicationValue := 256;
			END;
		END PointerUp;
		
		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR popup : WMPopups.Popup; str : ARRAY 256 OF CHAR; command, s : Strings.String; clickInfo:ClickInfo;
		BEGIN
			PointerDown^(x, y, keys);
			IF 2 IN keys THEN
				NEW(popup);

				NEW(clickInfo);
				clickInfo.cmd:=Strings.NewString("Edit"); (* call command cmd on Popup click *)
				popup.AddParButton("Edit", RightClickAction, clickInfo);
				
				NEW(clickInfo);
				clickInfo.cmd := Strings.NewString("Remove"); (* open file in cmdPar on Popup click *)
				popup.AddParButton("Remove", RightClickAction, clickInfo);
				
				ToWMCoordinates(x,y,x,y);
				popup.Popup(x, y); 
			END
		END PointerDown;
		
		PROCEDURE RightClickAction(sender, data: ANY);
		VAR error : BOOLEAN; inputWindow:InputWindow;
		BEGIN
			IF (data # NIL) & (data IS ClickInfo) THEN
				IF data(ClickInfo).cmd # NIL THEN
					IF data(ClickInfo).cmd^="Edit" THEN
						NEW(inputWindow, 100, 100, 420, 240);
						inputWindow.SetTaskContent(task);
						inputWindow.EditTask(task, error);
						inputWindow.Close; 
						UpdateTaskInfo(TRUE);
					ELSIF data(ClickInfo).cmd^ = "Remove" THEN  task.list.Remove(task);
					END;
				END
			END
		END RightClickAction;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			x, dx, dy, height : LONGINT;
			string : ARRAY 1024 OF CHAR; temp : ARRAY 32 OF CHAR;
			font : WMGraphics.Font;
			canvasState : WMGraphics.CanvasState;
		BEGIN
			UpdateTaskInfo(FALSE);
			canvas.SaveState(canvasState);
			DrawBackground^(canvas);
			WMGraphicUtilities.DrawBevel(canvas, GetClientRect(), 2, FALSE, WMGraphics.Black, WMGraphics.ModeCopy);
			height := bounds.GetHeight() - 2 * Border;
			IF (image # NIL) THEN
				canvas.ScaleImage(image, WMRectangles.MakeRect(0, 0, image.width, image.height),
					WMRectangles.MakeRect(Border, Border, height, height), WMGraphics.ModeSrcOverDst, WMGraphics.ScaleBilinear);
			END;
			x := 2 * Border + height;
			canvas.SetColor(WMGraphics.Black);
			(* Task trigger date *)
			WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(x, Border, x + 50, Border + 20), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, dateString);
			(* Task trigger time *)
			COPY(timeString, string);
			IF (taskInfo.repeatType # TaskScheduler.Once) THEN
				TaskScheduler.GetRepeatTypeString(taskInfo.repeatType, temp);
				Strings.Append(string, " ("); Strings.Append(string, temp); Strings.Append(string, ")");
			END;
			WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(x + 60, Border, x + 1024, Border + 20), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, string);

			IF (fontName # NIL) THEN canvas.SetFont(fontName); END;
			(* Task name *)
			IF (taskInfo.name # "") THEN
				font := canvas.GetFont();
				font.GetStringSize(taskInfo.name, dx, dy);
				canvas.SetColor(WMGraphics.Blue);
				WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(x, Border + 20, x + dx, Border + 40), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, taskInfo.name);
				canvas.SetColor(WMGraphics.Black);
				x := x + dx + 5;
			END;
			string := "";
			IF (taskInfo.description # "") THEN Strings.Append(string, taskInfo.description); END;
			IF (taskInfo.command # "") THEN
				Strings.Append(string, " (cmd="); Strings.Append(string, taskInfo.command); Strings.Append(string, ")");
			END;
			WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(x, Border + 20, x + 1024, Border + 40), FALSE, WMGraphics.AlignLeft, WMGraphics.AlignCenter, string);
			canvas.RestoreState(canvasState);
		END DrawBackground;

	END TaskView;

CONST
	Waiting = 0;
	Ok = 1;
	Cancel = 2;

TYPE

	InputWindow = OBJECT(WMComponents.FormWindow)
	VAR
		okBtn, cancelBtn : WMStandardComponents.Button;
		timeEditor, dateEditor, nameEditor, descriptionEditor, commandEditor : WMEditors.Editor;

		imageList, repeatList : WMDropDownLists.DropDownList;

		calendar : WMCalendar.Calendar;
		control : WMCalendar.CalendarController;

		state : LONGINT;

		PROCEDURE &New(x, y, width, height : LONGINT);
		BEGIN
			Init(width, height, FALSE);
			state := Waiting;
			SetTitle(Strings.NewString("Task Scheduler - Edit Task"));
			SetContent(CreateForm());
			WMWindowManager.AddWindow(SELF, x, y);
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel, leftPanel, rightPanel, line : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			dt : Dates.DateTime;
			string : ARRAY 32 OF CHAR;
			ignoreRes : LONGINT;

			PROCEDURE CreateLabel(CONST caption : ARRAY OF CHAR; width : LONGINT) : WMStandardComponents.Label;
			VAR label : WMStandardComponents.Label;
			BEGIN
				NEW(label); label.alignment.Set(WMComponents.AlignLeft);
				label.bounds.SetWidth(width);
				label.caption.SetAOC(caption);
				RETURN label;
			END CreateLabel;

			PROCEDURE CreateEditor(VAR editor : WMEditors.Editor);
			BEGIN
				NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
				editor.multiLine.Set(FALSE);
				editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
				editor.tv.showBorder.Set(TRUE);
				editor.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			END CreateEditor;

		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			(* Ok and cancel button *)
			NEW(line); line.alignment.Set(WMComponents.AlignBottom);
			line.bearing.Set(WMRectangles.MakeRect(5, 5, 5, 5));
			line.bounds.SetHeight(20);

			NEW(okBtn); okBtn.alignment.Set(WMComponents.AlignRight);
			okBtn.caption.SetAOC("Ok");
			okBtn.onClick.Add(ButtonHandler);
			line.AddContent(okBtn);

			NEW(cancelBtn); cancelBtn.alignment.Set(WMComponents.AlignRight);
			cancelBtn.caption.SetAOC("Cancel");
			cancelBtn.onClick.Add(ButtonHandler);
			line.AddContent(cancelBtn);

			panel.AddContent(line);

			dt := Dates.Now();

			NEW(leftPanel); leftPanel.alignment.Set(WMComponents.AlignLeft);
			leftPanel.bearing.Set(WMRectangles.MakeRect(5, 5, 10, 0));
			leftPanel.bounds.SetWidth(150);
			panel.AddContent(leftPanel);

			NEW(line); line.alignment.Set(WMComponents.AlignTop);
			line.bounds.SetHeight(20);
			line.AddContent(CreateLabel("Time:", 40));
			CreateEditor(timeEditor);
			timeEditor.alignment.Set(WMComponents.AlignClient);
			Strings.FormatDateTime("hh:nn", dt, string);
			timeEditor.SetAsString(string);
			line.AddContent(timeEditor);
			leftPanel.AddContent(line);

			NEW(line); line.alignment.Set(WMComponents.AlignTop);
			line.bearing.Set(WMRectangles.MakeRect(0, 5, 0, 0));
			line.bounds.SetHeight(20);
			line.AddContent(CreateLabel("Date:", 40));
			CreateEditor(dateEditor);
			dateEditor.alignment.Set(WMComponents.AlignClient);
			Strings.FormatDateTime("dd.mm.yyyy", dt, string);
			dateEditor.SetAsString(string);
			line.AddContent(dateEditor);
			leftPanel.AddContent(line);

			NEW(control); control.alignment.Set(WMComponents.AlignTop);
			control.bearing.Set(WMRectangles.MakeRect(0, 10, 0, 0));
			control.bounds.SetHeight(20);
			leftPanel.AddContent(control);

			NEW(calendar); calendar.alignment.Set(WMComponents.AlignClient);
			calendar.onSelect.Add(HandleDateSelected);
			leftPanel.AddContent(calendar);

			control.SetCalendar(calendar);

			NEW(rightPanel); rightPanel.alignment.Set(WMComponents.AlignClient);
			rightPanel.bearing.Set(WMRectangles.MakeRect(0, 5, 5, 0));
			panel.AddContent(rightPanel);

			NEW(line); line.alignment.Set(WMComponents.AlignTop);
			line.bounds.SetHeight(20);
			line.AddContent(CreateLabel("Name:", 40));
			CreateEditor(nameEditor);
			nameEditor.alignment.Set(WMComponents.AlignClient);
			line.AddContent(nameEditor);
			rightPanel.AddContent(line);

			NEW(line); line.alignment.Set(WMComponents.AlignTop);
			line.bounds.SetHeight(20);
			line.bearing.Set(WMRectangles.MakeRect(0, 5, 0, 0));
			line.AddContent(CreateLabel("Repeat:", 40));

			NEW(repeatList); repeatList.alignment.Set(WMComponents.AlignLeft);
			repeatList.bounds.SetWidth(80);
			repeatList.bearing.Set(WMRectangles.MakeRect(0, 0, 5, 0));
			repeatList.maxGridHeight.Set(500);
			repeatList.model.Add(TaskScheduler.Once, "No", ignoreRes);
			repeatList.model.Add(TaskScheduler.EverySecond, "Second", ignoreRes);
			repeatList.model.Add(TaskScheduler.EveryMinute, "Minute", ignoreRes);
			repeatList.model.Add(TaskScheduler.Hourly, "Hourly", ignoreRes);
			repeatList.model.Add(TaskScheduler.Daily, "Daily", ignoreRes);
			repeatList.model.Add(TaskScheduler.Weekly, "Weekly", ignoreRes);
			repeatList.model.Add(TaskScheduler.Monthly, "Monthly", ignoreRes);
			repeatList.model.Add(TaskScheduler.Yearly, "Yearly", ignoreRes);
			repeatList.mode.Set(WMDropDownLists.Mode_SelectOnly);
			line.AddContent(repeatList);
			rightPanel.AddContent(line);
			repeatList.SelectKey(TaskScheduler.Once);

			line.AddContent(CreateLabel("Image:", 40));

			NEW(imageList); imageList.alignment.Set(WMComponents.AlignClient);
			line.AddContent(imageList);

			CreateEditor(commandEditor); commandEditor.alignment.Set(WMComponents.AlignBottom);
			commandEditor.bounds.SetHeight(20);
			commandEditor.bearing.Set(WMRectangles.MakeRect(5, 0, 0, 0));
			rightPanel.AddContent(commandEditor);

			label := CreateLabel("Command:", 100); label.alignment.Set(WMComponents.AlignBottom);
			label.bounds.SetHeight(20);
			label.bearing.Set(WMRectangles.MakeRect(10, 0, 0, 0));
			rightPanel.AddContent(label);

			label := CreateLabel("Description:", 100); label.alignment.Set(WMComponents.AlignTop);
			label.bounds.SetHeight(20);
			label.bearing.Set(WMRectangles.MakeRect(0, 10, 0, 0));
			rightPanel.AddContent(label);

			CreateEditor(descriptionEditor); descriptionEditor.alignment.Set(WMComponents.AlignClient);
			descriptionEditor.multiLine.Set(TRUE);
			descriptionEditor.SetAsString("NoDescription");
			rightPanel.AddContent(descriptionEditor);

			RETURN panel;
		END CreateForm;

		PROCEDURE GetNewTask() : TaskScheduler.Task;
		VAR task : TaskScheduler.Task; error : BOOLEAN;
		BEGIN
			NEW(task);
			EditTask(task, error);
			IF error THEN task := NIL; END;
			RETURN task;
		END GetNewTask;

		PROCEDURE EditTask(VAR task : TaskScheduler.Task; VAR error : BOOLEAN);
		VAR info : TaskScheduler.TaskInfo; ok : BOOLEAN;
		BEGIN
			ASSERT(task # NIL);
			REPEAT
				BEGIN {EXCLUSIVE}
					AWAIT((state = Ok) OR (state = Cancel));
					ok := (state = Ok);
				END;
				IF ok THEN
					GetTaskContent(info, error);
					IF error THEN
						WMDialogs.Error("Error", "Check the red fields for errors");
						state := Waiting;
					END;
				END;
			UNTIL (state = Ok) OR (state = Cancel);
			IF ~error THEN task.SetInfo(info) END;
		END EditTask;

		PROCEDURE GetTaskContent(VAR info : TaskScheduler.TaskInfo; VAR error : BOOLEAN);
		VAR
			image, temp : Strings.String;
			entry : WMDropDownLists.Entry;

			PROCEDURE GetNumbers(stringArray : Strings.StringArray; VAR nbrArray : ARRAY OF LONGINT) : BOOLEAN;
			VAR i, j : LONGINT; error : BOOLEAN;
			BEGIN
				ASSERT(LEN(nbrArray) >= LEN(stringArray));
				FOR i := 0 TO LEN(nbrArray)-1 DO nbrArray[i] := 0; END;
				error := FALSE;
				FOR i := 0 TO LEN(stringArray)-1 DO
					Strings.TrimWS(stringArray[i]^);
					FOR j := 0 TO LEN(stringArray[i])-1 DO
						IF (stringArray[i][j] < "0") & ("9" < stringArray[i][j]) THEN error := TRUE; END;
					END;
					IF ~error THEN Strings.StrToInt(stringArray[i]^, nbrArray[i]); END;
				END;
				RETURN error;
			END GetNumbers;

			PROCEDURE ParseTime(VAR dt : Dates.DateTime) : BOOLEAN;
			VAR
				string : ARRAY 32 OF CHAR;
				time : ARRAY 3 OF LONGINT;
				stringArray : Strings.StringArray;
				error : BOOLEAN;
			BEGIN
				error := FALSE;
				timeEditor.GetAsString(string);
				stringArray := Strings.Split(string, ":");
				IF (1 <= LEN(stringArray)) & (LEN(stringArray) <= 3) THEN
					error := GetNumbers(stringArray, time);
					error := error OR ((time[0] < 0) & (23 < time[0])) OR ((time[1] < 0) & (59 < time[1])) OR ((time[2] < 0) & (59 < time[2]));
				ELSE
					error := TRUE;
				END;
				IF error THEN
					timeEditor.fillColor.Set(WMGraphics.Red);
				ELSE
					dt.hour := time[0];
					dt.minute := time[1];
					dt.second := time[2];
					timeEditor.fillColor.Set(WMGraphics.White);
				END;
				RETURN ~error;
			END ParseTime;

			PROCEDURE ParseDate(VAR dt : Dates.DateTime) : BOOLEAN;
			VAR
				string : ARRAY 32 OF CHAR;
				date : ARRAY 3 OF LONGINT;
				stringArray : Strings.StringArray;
				entry : WMDropDownLists.Entry;
				error : BOOLEAN;
			BEGIN
				error := FALSE;
				dateEditor.GetAsString(string);
				stringArray := Strings.Split(string, ".");
				IF (LEN(stringArray) = 3) THEN
					error := GetNumbers(stringArray, date);
					error := error OR (date[2] < 0) OR ((date[1] < 1) & (12 < date[1])) OR ((date[0] < 1) & (Dates.NofDays(date[2], date[1]) < date[0]));
				ELSE
					error := TRUE;
				END;
				IF error THEN
					dateEditor.fillColor.Set(WMGraphics.Red);
				ELSE
					dt.year := date[2];
					dt.month := date[1];
					dt.day := date[0];
					dateEditor.fillColor.Set(WMGraphics.White);
				END;
				RETURN ~error;
			END ParseDate;

			PROCEDURE GetString(editor : WMEditors.Editor; VAR string : ARRAY OF CHAR;  maxLength : LONGINT) : BOOLEAN;
			VAR value : ARRAY 1024 OF CHAR;
			BEGIN
				editor.GetAsString(value);
				Strings.TrimWS(value);
				IF (Strings.Length(value) < maxLength) THEN
					COPY(value, string);
					editor.fillColor.Set(WMGraphics.White);
					RETURN TRUE;
				ELSE
					editor.fillColor.Set(WMGraphics.Red);
					RETURN FALSE;
				END;
			END GetString;

		BEGIN
			error := ~ParseTime(info.trigger);
			error := error OR ~ParseDate(info.trigger);
			IF ~error THEN ASSERT(Dates.ValidDateTime(info.trigger)); END;
			error := error OR ~GetString(nameEditor, info.name, TaskScheduler.NameLength);
			error := error OR ~GetString(descriptionEditor, info.description, TaskScheduler.DescriptionLength);
			error := error OR ~GetString(commandEditor, info.command, TaskScheduler.CommandLength);
			entry := imageList.GetSelection();
			IF (entry # NIL) THEN
				Strings.TrimWS(entry.name^);
				IF (Strings.Length(entry.name^) < TaskScheduler.ImageNameLength) THEN
					COPY(entry.name^, info.image);
					imageList.fillColor.Set(WMGraphics.White);
				ELSE
					imageList.fillColor.Set(WMGraphics.Red);
					error := TRUE;
				END;
			ELSE
				info.image := "";
			END;
			entry := repeatList.GetSelection();
			IF (entry # NIL) THEN
				info.repeatType := entry.key;
				repeatList.fillColor.Set(WMGraphics.White);
			ELSE
				repeatList.fillColor.Set(WMGraphics.Red);
				error := TRUE;
			END;
		END GetTaskContent;

		(* Fill out the form with the task content. Does not modify the task! *)
		PROCEDURE SetTaskContent(task : TaskScheduler.Task);
		VAR string : ARRAY 1024 OF CHAR; info : TaskScheduler.TaskInfo;
		BEGIN
			ASSERT(task # NIL);
			info := task.GetInfo();
			ASSERT(Dates.ValidDateTime(info.trigger));
			IF (info.trigger.second # 0) THEN
				Strings.FormatDateTime("hh:nn:ss", info.trigger, string);
			ELSE
				Strings.FormatDateTime("hh:nn", info.trigger, string);
			END;
			timeEditor.SetAsString(string);
			Strings.FormatDateTime("dd.mm.yyyy", info.trigger, string);
			dateEditor.SetAsString(string);
			calendar.year.Set(info.trigger.year);
			calendar.month.Set(info.trigger.month);
			nameEditor.SetAsString(info.name);
			CASE info.repeatType OF
				|TaskScheduler.Unknown: string := "Unknown";
				|TaskScheduler.Once: string := "No";
				|TaskScheduler.EverySecond: string := "Second";
				|TaskScheduler.EveryMinute: string := "Minute";
				|TaskScheduler.Hourly: string := "Hourly";
				|TaskScheduler.Weekly: string := "Weekly";
				|TaskScheduler.Monthly: string := "Monthly";
				|TaskScheduler.Yearly: string := "Yearly";
			ELSE
				string := "Unknown";
			END;
			(* TODO
			repeatList.selection.Set(Strings.NewString(string));
			imageList.selection.Set(Strings.NewString(info.image));
			*)
			descriptionEditor.SetAsString(info.description);
			commandEditor.SetAsString(info.command);
		END SetTaskContent;

		PROCEDURE ButtonHandler(sender, data : ANY);
		BEGIN
			IF (sender = okBtn) THEN
				SetState(Ok);
			ELSIF (sender = cancelBtn) THEN
				SetState(Cancel);
			END;
		END ButtonHandler;

		PROCEDURE HandleDateSelected(sender, data : ANY);
		VAR date : WMCalendar.SelectionWrapper; dt : Dates.DateTime; dateString : ARRAY 32 OF CHAR;
		BEGIN
			IF (data # NIL) & (data IS WMCalendar.SelectionWrapper) THEN
				date := data (WMCalendar.SelectionWrapper);
				dt.year := date.year; dt.month := date.month; dt.day := date.day;
				dt.hour := 0; dt.minute := 0; dt.second := 0;
				Strings.FormatDateTime("dd.mm.yyyy", dt, dateString);
				dateEditor.SetAsString(dateString);
			END;
		END HandleDateSelected;

		PROCEDURE SetState(state : LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.state := state;
		END SetState;

	END InputWindow;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		taskList : TaskScheduler.TaskList;
		newTasks, currentTasks : TaskScheduler.TaskArray;

		scrollpanel : WMStandardComponents.Panel;

		selectMode : LONGINT;

		statusLabel : WMStandardComponents.Label;
		lastNofSelectedTasks, lastNofTasks : LONGINT;

		filenameEditor : WMEditors.Editor;
		loadBtn, storeBtn, addBtn, todayBtn, thisWeekBtn, allBtn : WMStandardComponents.Button;

		inputWindow : InputWindow;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE &New(context : WMRestorable.Context);
		VAR filename : Files.FileName; configuration : WMRestorable.XmlElement; mode : LONGINT;
		BEGIN
			IncCount;
			IF (context # NIL) THEN
				Init(context.r - context.l, context.b - context.t, TRUE);
			ELSE
				Init(WindowWidth, WindowHeight, TRUE);
			END;

			NEW(taskList);
			NEW(newTasks, 20); TaskScheduler.Clear(newTasks);
			NEW(currentTasks, 20); TaskScheduler.Clear(currentTasks);
			inputWindow := NIL;

			alive := TRUE; dead := FALSE;
			NEW(timer);

			lastNofSelectedTasks := -1; lastNofTasks := -1; (* force invalidation *)

			SetContent(CreateForm());
			SetTitle(Strings.NewString("Task Scheduler"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMTaskScheduler.png", TRUE));

			IF (context # NIL) THEN
				WMRestorable.AddByContext(SELF, context);
				configuration := WMRestorable.GetElement(context, "Configuration");
				IF (configuration # NIL) THEN
					WMRestorable.LoadLongint(configuration, "mode", mode);
					SetSelectMode(mode);
					WMRestorable.LoadString(configuration, "filename", filename);
					Load(filename);
				END;
			ELSE
				SetSelectMode(Select_Today);
				WMWindowManager.DefaultAddWindow(SELF)
			END;
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, toolbar, statusbar : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(statusbar); statusbar.alignment.Set(WMComponents.AlignBottom);
			statusbar.bounds.SetHeight(20);
			statusbar.fillColor.Set(0CCCCCCFFH);
			panel.AddContent(statusbar);

			NEW(allBtn); allBtn.alignment.Set(WMComponents.AlignRight);
			allBtn.caption.SetAOC("All");
			allBtn.isToggle.Set(TRUE);
			allBtn.onClick.Add(ButtonHandler);
			statusbar.AddContent(allBtn);

			NEW(thisWeekBtn); thisWeekBtn.alignment.Set(WMComponents.AlignRight);
			thisWeekBtn.caption.SetAOC("This Week");
			thisWeekBtn.isToggle.Set(TRUE);
			thisWeekBtn.onClick.Add(ButtonHandler);
			statusbar.AddContent(thisWeekBtn);

			NEW(todayBtn); todayBtn.alignment.Set(WMComponents.AlignRight);
			todayBtn.caption.SetAOC("Today");
			todayBtn.isToggle.Set(TRUE);
			todayBtn.onClick.Add(ButtonHandler);
			statusbar.AddContent(todayBtn);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignClient);
			statusLabel.textColor.Set(WMGraphics.Black);
			statusbar.AddContent(statusLabel);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			panel.AddContent(toolbar);

			NEW(addBtn); addBtn.alignment.Set(WMComponents.AlignRight);
			addBtn.caption.SetAOC("Add");
			addBtn.onClick.Add(ButtonHandler);
			toolbar.AddContent(addBtn);

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignRight);
			storeBtn.caption.SetAOC("Store");
			storeBtn.onClick.Add(ButtonHandler);
			toolbar.AddContent(storeBtn);

			NEW(loadBtn); loadBtn.alignment.Set(WMComponents.AlignRight);
			loadBtn.caption.SetAOC("Load");
			loadBtn.onClick.Add(ButtonHandler);
			toolbar.AddContent(loadBtn);

			NEW(filenameEditor); filenameEditor.alignment.Set(WMComponents.AlignClient);
			filenameEditor.multiLine.Set(FALSE);
			filenameEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			filenameEditor.tv.showBorder.Set(TRUE);
			filenameEditor.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			filenameEditor.SetAsString("Tasks.txt");
			toolbar.AddContent(filenameEditor);

			NEW(scrollpanel); scrollpanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(scrollpanel);

			RETURN panel;
		END CreateForm;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR filename : Files.FileName;
		BEGIN
			IF (sender = loadBtn) THEN
				filenameEditor.GetAsString(filename);
				Load(filename);
			ELSIF (sender = storeBtn) THEN
				filenameEditor.GetAsString(filename);
				Store(filename);
			ELSIF (sender = addBtn) THEN
				AddTask;
			ELSIF (sender = todayBtn) THEN
				SetSelectMode(Select_Today);
			ELSIF (sender = thisWeekBtn) THEN
				SetSelectMode(Select_ThisWeek);
			ELSIF (sender = allBtn) THEN
				SetSelectMode(Select_All);
			END;
		END ButtonHandler;

		PROCEDURE AddTask;
		VAR task : TaskScheduler.Task;
		BEGIN
			IF (inputWindow = NIL) THEN
				NEW(inputWindow, 100, 100, 420, 240);
				task := inputWindow.GetNewTask();
				inputWindow.Close; inputWindow := NIL;
				IF (task # NIL) THEN
					taskList.Add(task);
				END;
			END;
		END AddTask;

		PROCEDURE EditTask(task : TaskScheduler.Task);
		VAR error : BOOLEAN;
		BEGIN
			ASSERT(task # NIL);
			IF (inputWindow = NIL) THEN
				NEW(inputWindow, 100, 100, 420, 240);
				inputWindow.SetTaskContent(task);
				inputWindow.EditTask(task, error);
			END;
		END EditTask;

		PROCEDURE Load(CONST filename : ARRAY OF CHAR);
		VAR message : ARRAY 1024 OF CHAR;
		BEGIN
			taskList.Reset;
			IF ~taskList.Load(filename) THEN
				message := "Could not load tasks from file ";
				Strings.Append(message, filename);
				WMDialogs.Error("Task Scheduler", message);
			ELSE
				timer.Wakeup;
			END;
		END Load;

		PROCEDURE Store(CONST filename : ARRAY OF CHAR);
		VAR message : ARRAY 1024 OF CHAR;
		BEGIN
			IF ~taskList.Store(filename) THEN
				message := "Could not store tasks to file ";
				Strings.Append(message, filename);
				WMDialogs.Error("Task Scheduler", message);
			END;
		END Store;

		PROCEDURE SetSelectMode(mode : LONGINT);
		BEGIN
			todayBtn.SetPressed(FALSE);
			thisWeekBtn.SetPressed(FALSE);
			allBtn.SetPressed(FALSE);
			IF (mode = Select_Today) THEN
				todayBtn.SetPressed(TRUE);
			ELSIF (mode = Select_ThisWeek) THEN
				thisWeekBtn.SetPressed(TRUE);
			ELSIF (mode = Select_All) THEN
				allBtn.SetPressed(TRUE);
			END;
			selectMode := mode;
			timer.Wakeup;
		END SetSelectMode;

		PROCEDURE Close;
		BEGIN
			Close^;
			IF (inputWindow # NIL) THEN inputWindow.Close; END;
			alive := FALSE;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			DecCount;
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement; filename : Files.FileName;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					filenameEditor.GetAsString(filename);
					WMRestorable.StoreString(configuration, "filename", filename);
					WMRestorable.StoreLongint(configuration, "mode", selectMode);
					x.ext(WMRestorable.Storage).Add("WMTaskScheduler", "WMTaskScheduler.Restore", SELF, configuration);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE Selector(time : Dates.DateTime; task : TaskScheduler.Task) : BOOLEAN;
		BEGIN
			ASSERT(task # NIL);
			RETURN
						((selectMode = Select_Today) & SameDay(time, task.GetTrigger())) OR
						((selectMode = Select_ThisWeek) & SameWeek(time, task.GetTrigger())) OR
						(selectMode = Select_All);

		END Selector;

		PROCEDURE CreateTaskViews(tasks : TaskScheduler.TaskArray);
		VAR taskView : TaskView; i : LONGINT;
		BEGIN
			ASSERT(tasks # NIL);
			FOR i := 0 TO LEN(tasks)-1 DO
				IF (tasks[i] # NIL) THEN
					NEW(taskView, tasks[i]); taskView.alignment.Set(WMComponents.AlignTop);
					taskView.bounds.SetHeight(50);
					taskView.bearing.Set(WMRectangles.MakeRect(Bearing, Bearing, Bearing, 0));
					taskView.Invalidate;
					scrollpanel.AddContent(taskView);
				END;
			END;
			scrollpanel.AlignSubComponents;
			CSChanged;
		END CreateTaskViews;

		PROCEDURE RemoveTaskViews(tasks : TaskScheduler.TaskArray);
		VAR i : LONGINT;
		BEGIN
			ASSERT(tasks # NIL);
			FOR i := 0 TO LEN(tasks)-1 DO
				IF (tasks[i] # NIL) & (tasks[i].user # NIL) & (tasks[i].user IS TaskView) THEN
					scrollpanel.RemoveContent(tasks[i].user(TaskView));
					tasks[i] := NIL;
				END;
			END;
		END RemoveTaskViews;

		PROCEDURE UpdateTaskViews( dt : Dates.DateTime; tasks : TaskScheduler.TaskArray);
		VAR i : LONGINT;
		BEGIN
			ASSERT(tasks # NIL);
			FOR i := 0 TO LEN(tasks)-1 DO
				IF (tasks[i] # NIL) & (tasks[i].user # NIL) & (tasks[i].user IS TaskView) THEN
					tasks[i].user(TaskView).Update(dt);
				END;
			END;
		END UpdateTaskViews;

		PROCEDURE UpdateStatusLabel(nofSelectedTasks, nofTasks : LONGINT);
		VAR caption : ARRAY 256 OF CHAR; nbr : ARRAY 16 OF CHAR;
		BEGIN
			caption := "Displaying ";
			Strings.IntToStr(nofSelectedTasks, nbr); Strings.Append(caption, nbr);
			Strings.Append(caption, " of ");
			Strings.IntToStr(nofTasks, nbr); Strings.Append(caption, nbr);
			Strings.Append(caption, " tasks");
			statusLabel.caption.SetAOC(caption);
		END UpdateStatusLabel;

		PROCEDURE CheckTasks;
		VAR dt : Dates.DateTime; nofSelectedTasks, nofTasks : LONGINT;
		BEGIN
			dt := Dates.Now();
			taskList.Select(Selector, dt, newTasks, nofSelectedTasks, nofTasks);
			IF (nofSelectedTasks # lastNofSelectedTasks) OR (nofTasks # lastNofTasks) THEN
				lastNofSelectedTasks := nofSelectedTasks; lastNofTasks := nofTasks;
				UpdateStatusLabel(nofSelectedTasks, nofTasks);
			END;
			(* remove old tasks if necessary *)
			IF ~TaskScheduler.IsEqual(newTasks, currentTasks) THEN
				RemoveTaskViews(currentTasks);
				TaskScheduler.Copy(newTasks, currentTasks);
				CreateTaskViews(currentTasks);
				scrollpanel.Invalidate;
			END;
			UpdateTaskViews(dt, currentTasks);
		END CheckTasks;

	BEGIN {ACTIVE}
		WHILE alive DO
			CheckTasks;
			timer.Sleep(500);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Window;

VAR
	DefaultImage : WMGraphics.Image;
	nofWindows : LONGINT;

PROCEDURE SameDay( dt1, dt2 : Dates.DateTime) : BOOLEAN;
BEGIN
	RETURN (dt1.day = dt2.day) & (dt1.month = dt2.month) & (dt1.year = dt2.year);
END SameDay;

PROCEDURE IsTomorrow(start, end : Dates.DateTime) : BOOLEAN;
BEGIN
	RETURN (start.day = end.day - 1) & (start.month = end.month) & (start.year = end.year);
END IsTomorrow;

PROCEDURE SameWeek(dt1, dt2 : Dates.DateTime) : BOOLEAN;
VAR year1, year2, week1, week2, ignoreWeekDay : LONGINT;
BEGIN
	Dates.WeekDate(dt1, year1, week1, ignoreWeekDay);
	Dates.WeekDate(dt2, year2, week2, ignoreWeekDay);
	RETURN (year1 = year2) & (week1 = week2);
END SameWeek;

PROCEDURE ToSeconds(days, hours, minutes, seconds : LONGINT) : LONGINT;
BEGIN
	RETURN (days * 86400) + (hours * 3600) + (minutes * 60) + seconds;
END ToSeconds;

PROCEDURE Open*(context : Commands.Context);
VAR window : Window;
BEGIN
	NEW(window, NIL);
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context)
END Restore;

PROCEDURE Init;
BEGIN
	nofWindows := 0;
	DefaultImage := WMGraphics.LoadImage("WMTaskScheduler.tar://Unknown.png", TRUE);
END Init;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Init;
	Modules.InstallTermHandler(Cleanup);
END WMTaskScheduler.

WMTaskScheduler.Open ~

SystemTools.Free WMTaskScheduler WMTaskScheduler TaskScheduler 
SystemTools.Free WMClock~
