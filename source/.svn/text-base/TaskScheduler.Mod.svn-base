MODULE TaskScheduler; (** AUTHOR "staubesv"; PURPOSE "Simple task scheduler"; *)

IMPORT
	Streams, Modules, Kernel, Locks, Dates, Strings, Files, Commands;

CONST
	(* task.repeatType *)
	Unknown* = -1;
	Once* = 0; (** default *)
	EverySecond* = 1;
	EveryMinute* = 2;
	Hourly* = 3;
	Daily* = 4;
	Weekly* = 5;
	Monthly* = 6;
	Yearly* = 7;

	NameLength* = 64;
	DescriptionLength* = 256;
	CommandLength* = 256;
	ImageNameLength* = 256;

TYPE

	TaskInfo* = RECORD
		name* : ARRAY NameLength OF CHAR;
		description* : ARRAY DescriptionLength OF CHAR;
		command* : ARRAY CommandLength OF CHAR;
		image* : ARRAY ImageNameLength OF CHAR;
		repeatType* : LONGINT;
		trigger* : Dates.DateTime;
	END;

TYPE

	Task* = OBJECT
	VAR
		id- : LONGINT;
 	 	timestamp- : LONGINT;

		info : TaskInfo;

		user* : ANY;

		handled : BOOLEAN;

	  	week, weekDay : LONGINT;

		list- : TaskList;
		next : Task;

		PROCEDURE &Init*;
		BEGIN
			id := GetId();
			info.name := ""; info.description := "";
			info.command := "";
			info.image := "";
			info.repeatType := Unknown;
			timestamp := 0;
			user := NIL;
			handled := FALSE;
			list := NIL;
			next := NIL;
		END Init;

		PROCEDURE SetInfo*(CONST info : TaskInfo);
		BEGIN {EXCLUSIVE}
			SELF.info := info;
			INC(timestamp);
		END SetInfo;

		PROCEDURE GetInfo*() : TaskInfo;
		BEGIN {EXCLUSIVE}
			RETURN info;
		END GetInfo;

		PROCEDURE ToStream(out : Streams.Writer);
		VAR string : ARRAY 128 OF CHAR;
		BEGIN {EXCLUSIVE}
			ASSERT(out # NIL);
			Strings.FormatDateTime("dd.mm.yyyy hh:nn:ss", info.trigger, string);
			out.String(string); out.String(" ");
			TypeToStream(out, info.repeatType);
			out.String(' "'); out.String(info.name); out.String('" "');
			out.String(info.description); out.String('" "');
			out.String(info.command); out.String('" "');
			out.String(info.image); out.String('"');
			out.Ln;
		END ToStream;

		PROCEDURE FromStream(in : Streams.Reader) : BOOLEAN;
		VAR string : ARRAY 2048 OF CHAR;
		BEGIN {EXCLUSIVE}
			ASSERT(in # NIL);
			in.SkipWhitespace; in.String(string); Strings.StrToDate(string, info.trigger);
			in.SkipWhitespace; in.String(string); Strings.StrToTime(string, info.trigger);
			info.repeatType := TypeFromStream(in);
			in.SkipWhitespace; in.String(info.name);
			in.SkipWhitespace; in.String(info.description);
			in.SkipWhitespace; in.String(info.command);
			in.SkipWhitespace; in.String(info.image);
			SetTriggerX(info.trigger, info.repeatType);
			RETURN TRUE;
		END FromStream;

		PROCEDURE Confirm*;
		BEGIN
			IF (list # NIL) THEN list.ConfirmTask(SELF); END;
		END Confirm;

		(* Returns time left until next time triggered in seconds or 0 if not triggered anymore *)
		PROCEDURE Left*(VAR days, hours, minutes, seconds : LONGINT);
		VAR currentTime : Dates.DateTime;
		BEGIN
			currentTime := Dates.Now();
			LeftFrom(currentTime, days, hours, minutes, seconds);
		END Left;

		PROCEDURE LeftFrom*(CONST dt : Dates.DateTime; VAR days, hours, minutes, seconds : LONGINT);
		BEGIN {EXCLUSIVE}
			IF (Dates.CompareDateTime(dt, info.trigger) = -1) THEN
				Dates.TimeDifference(dt, info.trigger, days, hours, minutes, seconds);
			ELSE
				days := 0; hours := 0; minutes := 0; seconds := 0;
			END;
		END LeftFrom;

		PROCEDURE SetTrigger*(dt : Dates.DateTime; type : LONGINT);
		BEGIN {EXCLUSIVE}
			SetTriggerX(dt, type);
		END SetTrigger;

		PROCEDURE SetTriggerX(dt : Dates.DateTime; repeatType : LONGINT);
		VAR currentTime : Dates.DateTime; ignoreYear : LONGINT;
		BEGIN
			ASSERT(Dates.ValidDateTime(dt));
			INC(timestamp);
			info.repeatType := repeatType;
			info.trigger := dt;
			IF (repeatType # Once)  THEN
				currentTime := Dates.Now();
				IF (repeatType = EverySecond) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddSeconds(info.trigger, 1);
					END;
				ELSIF (repeatType = EveryMinute) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddMinutes(info.trigger, 1);
					END;
				ELSIF (repeatType = Hourly) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddHours(info.trigger, 1);
					END;
				ELSIF (repeatType = Weekly) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddDays(info.trigger, 7);
					END;
				ELSIF (repeatType = Monthly) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddMonths(info.trigger, 1);
					END;
				ELSIF (repeatType = Yearly) THEN
					WHILE (Dates.CompareDateTime(info.trigger, currentTime) # 1) DO
						Dates.AddYears(info.trigger, 1);
					END;
				END;
			END;
			Dates.WeekDate(info.trigger, ignoreYear, week, weekDay);
		END SetTriggerX;

		PROCEDURE GetTrigger*() : Dates.DateTime;
		BEGIN {EXCLUSIVE}
			RETURN info.trigger;
		END GetTrigger;
		
		PROCEDURE TriggerNow*;
		VAR msg: ARRAY 256 OF CHAR; res:LONGINT;
		BEGIN
			IF Strings.Length(info.command)>0 THEN	
				Commands.Call(info.command, {}, res, msg);
			END;
		END TriggerNow;
		

		PROCEDURE Check(time : Dates.DateTime; VAR left : LONGINT);
		BEGIN
			IF (left = 0) & ~handled THEN
				IF (info.repeatType = Once) THEN
				END;
			END;
		END Check;

	END Task;

	TaskArray* = POINTER TO ARRAY OF Task;

TYPE

	SelectorProcedure* = PROCEDURE {DELEGATE} (time : Dates.DateTime; task : Task) : BOOLEAN;

	EnumeratorProcedure* = PROCEDURE {DELEGATE} (time : Dates.DateTime; task : Task);

	TaskList* = OBJECT
	VAR
		head : Task;
		nofTasks : LONGINT;
		lock : Locks.RWLock;

		PROCEDURE &Init*;
		BEGIN
			head := NIL;
			nofTasks := 0;
			NEW(lock);
		END Init;

		PROCEDURE Load*(CONST filename : ARRAY OF CHAR) : BOOLEAN;
		VAR file : Files.File; in : Files.Reader; task : Task; succeeded : BOOLEAN;
		BEGIN
			file := Files.Old(filename);
			IF (file # NIL) THEN
				succeeded := TRUE;
				Files.OpenReader(in, file, 0);
				lock.AcquireWrite;
				in.SkipWhitespace;
				WHILE succeeded & (in.Available() > 0) & (in.res = Streams.Ok) DO
					NEW(task);
					succeeded := task.FromStream(in);
					IF succeeded THEN
						Add(task);
					END;
					in.SkipWhitespace;
				END;
				succeeded := succeeded OR ~((in.res # Streams.Ok) & (in.res # Streams.EOF));
				lock.ReleaseWrite;
			ELSE
				succeeded := FALSE;
			END;
			RETURN succeeded;
		END Load;

		PROCEDURE Store*(CONST filename : ARRAY OF CHAR) : BOOLEAN;
		VAR file : Files.File; out : Files.Writer; task : Task;
		BEGIN
			file := Files.New(filename);
			IF (file # NIL) THEN
				Files.OpenWriter(out, file, 0);
				lock.AcquireRead;
				task := head;
				WHILE (task # NIL) & ~task.handled DO
					task.ToStream(out);
					task := task.next;
				END;
				out.Update;
				Files.Register(file);
				lock.ReleaseRead;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Store;

		PROCEDURE Reset*;
		BEGIN
			lock.AcquireWrite;
			head := NIL; nofTasks := 0;
			lock.ReleaseWrite;
		END Reset;

		PROCEDURE ConfirmTask*(task : Task);
		BEGIN
			ASSERT(task # NIL);
			lock.AcquireWrite;
			Remove(task); (* TODO: Check race condition... *)
			IF (task.info.repeatType # Once) & (task.info.repeatType # Unknown) THEN
				task.SetTrigger(task.info.trigger, task.info.repeatType);
				Add(task); (* trigger will be adapted -> add again so that the list remains sorted *)
			END;
			lock.ReleaseWrite;
		END ConfirmTask;

		PROCEDURE FindById*(id : LONGINT) : Task;
		VAR task : Task;
		BEGIN
			lock.AcquireRead;
			task := head;
			WHILE (task # NIL) & (task.id # id) DO task := task.next; END;
			lock.ReleaseRead;
			RETURN task;
		END FindById;

		PROCEDURE Select*(selector : SelectorProcedure; CONST dt : Dates.DateTime; VAR tasks : TaskArray; VAR nofSelectedTasks, nofTasks : LONGINT);
		VAR task : Task; i : LONGINT;
		BEGIN
			Clear(tasks);
			lock.AcquireRead;
			(* first count number of selected tasks *)
			nofTasks := SELF.nofTasks;
			nofSelectedTasks := 0;
			task := head;
			WHILE (task # NIL) DO
				IF selector(dt, task) THEN INC(nofSelectedTasks); END;
				task := task.next;
			END;
			IF (nofSelectedTasks > 0) THEN
				IF (tasks = NIL) OR (nofSelectedTasks > LEN(tasks)) THEN
					NEW(tasks, nofSelectedTasks);
				END;
				i := 0;
				task := head;
				WHILE (task # NIL) DO
					IF selector(dt, task) THEN
						tasks[i] := task;
						INC(i);
					END;
					task := task.next;
				END;
			END;
			lock.ReleaseRead;
		END Select;

		PROCEDURE Enumerate*(time : Dates.DateTime; proc : EnumeratorProcedure);
		VAR task : Task;
		BEGIN
			ASSERT(proc # NIL);
			ASSERT(lock.HasReadLock());
			task := head;
			WHILE (task # NIL) DO
				proc(time, task);
				task := task.next;
			END;
		END Enumerate;

		PROCEDURE Add*(task : Task);
		VAR t : Task;
		BEGIN
			ASSERT((task # NIL) & (task.list = NIL));
			task.id := GetId();
			lock.AcquireWrite;
			IF (head = NIL) OR (Dates.CompareDateTime(task.GetTrigger(), head.GetTrigger()) = -1) THEN
				task.next := head;
				head := task;
			ELSE
				t := head;
				WHILE (t # NIL) & (t.next # NIL) & (Dates.CompareDateTime(task.GetTrigger(), t.next.GetTrigger()) = 1) DO t := t.next; END;
				task.next := t.next;
				t.next := task;
			END;
			task.list := SELF;
			INC(nofTasks);
			lock.ReleaseWrite;
		END Add;

		PROCEDURE Remove*(task : Task);
		VAR t : Task;
		BEGIN
			ASSERT((task # NIL) & (task.list = SELF));
			lock.AcquireWrite;
			IF (head = task) THEN
				head := head.next;
				DEC(nofTasks);
			ELSE
				t := head;
				WHILE (t # NIL) & (t.next # task) DO t := t.next; END;
				IF (t.next # NIL) THEN
					t.next := t.next.next;
					DEC(nofTasks);
				END;
			END;
			task.list := NIL;
			lock.ReleaseWrite;
		END Remove;

		(** Returns total number of tasks in this list *)
		PROCEDURE GetNofTasks*() : LONGINT;
		BEGIN
			RETURN nofTasks;
		END GetNofTasks;

	END TaskList;

TYPE

	Scheduler = OBJECT
	VAR
		sleepHint : LONGINT;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE &Init;
		BEGIN
			sleepHint := 1000;
			alive := TRUE; dead := FALSE;
			NEW(timer);
		END Init;

		PROCEDURE Stop;
		BEGIN
			alive := FALSE; timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Stop;

		PROCEDURE Update;
		BEGIN
			sleepHint := 500;
			timer.Wakeup;
		END Update;

		PROCEDURE CheckTask(time : Dates.DateTime; task : Task);
		VAR hint : LONGINT;
		BEGIN
			task.Check(time, hint);
			IF (hint > 0) & (hint < sleepHint) THEN sleepHint := hint; END;
		END CheckTask;

	BEGIN {ACTIVE}
		WHILE alive DO
			sleepHint := MAX(LONGINT);
			taskList.lock.AcquireRead;
			taskList.Enumerate(Dates.Now(), CheckTask);
			taskList.lock.ReleaseRead;
			IF alive THEN timer.Sleep(sleepHint); END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END Scheduler;

VAR
	taskList : TaskList;
	scheduler : Scheduler;
	id : LONGINT;

	StrNoName-, StrNoDescription-, StrNoCommand-, StrNoImage-: Strings.String;

PROCEDURE TypeToStream(out : Streams.Writer; repeatType : LONGINT);
BEGIN
	ASSERT(out # NIL);
	CASE repeatType OF
		|Unknown: out.String("Unknown");
		|Once: out.String("Once");
		|EverySecond: out.String("EverySecond");
		|EveryMinute: out.String("EveryMinute");
		|Hourly: out.String("Hourly");
		|Daily: out.String("Daily");
		|Weekly: out.String("Weekly");
		|Monthly: out.String("Monthly");
		|Yearly: out.String("Yearly");
	ELSE
		out.String("Unknown");
	END;
END TypeToStream;

PROCEDURE TypeFromStream(in : Streams.Reader) : LONGINT;
VAR repeatType : LONGINT; string : ARRAY 32 OF CHAR;
BEGIN
	ASSERT(in # NIL);
	repeatType := Unknown;
	in.SkipWhitespace; in.String(string);
	IF (string = "Once") THEN repeatType := Once;
	ELSIF (string = "EverySecond") THEN repeatType := EverySecond;
	ELSIF (string = "EveryMinute") THEN repeatType := EveryMinute;
	ELSIF (string = "Hourly") THEN repeatType := Hourly;
	ELSIF (string = "Daily") THEN repeatType := Daily;
	ELSIF (string = "Weekly") THEN repeatType := Weekly;
	ELSIF (string = "Monthly") THEN repeatType := Monthly;
	ELSIF (string = "Yearly") THEN repeatType := Yearly;
	END;
	RETURN repeatType;
END TypeFromStream;

PROCEDURE GetId() : LONGINT;
BEGIN {EXCLUSIVE}
	INC(id);
	RETURN id;
END GetId;

PROCEDURE GetTaskList*() : TaskList;
VAR taskList : TaskList;
BEGIN
	NEW(taskList);
	RETURN taskList;
END GetTaskList;

(** Helper functions *)

PROCEDURE GetRepeatTypeString*(repeatType : LONGINT; VAR string : ARRAY OF CHAR);
BEGIN
	CASE repeatType OF
		|Unknown: string := "Unknown";
		|Once: string := "Once";
		|EverySecond: string := "Each Second";
		|EveryMinute: string := "Each Minute";
		|Hourly: string := "Hourly";
		|Daily: string := "Daily";
		|Weekly: string := "Weekly";
		|Monthly: string := "Monthly";
		|Yearly: string := "Yearly";
	ELSE
		string := "Unknown";
	END;
END GetRepeatTypeString;

(** TaskArray helper functions *)

(** Returns TRUE if both task arrays contain exactly the same tasks in the same order, FALSE otherwise *)
PROCEDURE IsEqual*(tasks1, tasks2 : TaskArray) : BOOLEAN;
VAR i : LONGINT;

	PROCEDURE SameElement(t1, t2 : Task) : BOOLEAN;
	BEGIN
		RETURN ((t1 = NIL) & (t2 = NIL)) OR ((t1 # NIL) & (t2 # NIL) & (t1.id = t2.id));
	END SameElement;

BEGIN
	ASSERT((tasks1 # NIL) & (tasks2 # NIL));
	IF (LEN(tasks1) = LEN(tasks2)) THEN
		i := 0;
		WHILE (i < LEN(tasks1)) DO
			IF ~SameElement(tasks1[i], tasks2[i])  THEN RETURN FALSE; END;
			INC(i);
		END;
		RETURN TRUE;
	END;
	RETURN FALSE;
END IsEqual;

PROCEDURE Copy*(from : TaskArray; VAR to : TaskArray);
VAR i : LONGINT;
BEGIN
	ASSERT(from # NIL);
	IF (to = NIL) OR (LEN(to) < LEN(from)) THEN NEW(to, LEN(from)); END;
	FOR i := 0 TO LEN(from)-1 DO to[i] := from[i]; END;
END Copy;

PROCEDURE Clear*(tasks : TaskArray);
VAR i : LONGINT;
BEGIN
	ASSERT(tasks # NIL);
	FOR i := 0 TO LEN(tasks)-1 DO tasks[i] := NIL; END;
END Clear;

PROCEDURE InitStrings;
BEGIN
	StrNoName := Strings.NewString("NoName");
	StrNoDescription := Strings.NewString("NoDescription");
	StrNoCommand := Strings.NewString("NoCommand");
	StrNoImage := Strings.NewString("NoImage");
END InitStrings;

PROCEDURE Cleanup;
BEGIN
	scheduler.Stop;
END Cleanup;

BEGIN
	InitStrings;
	NEW(taskList);
	NEW(scheduler);
	Modules.InstallTermHandler(Cleanup);
END TaskScheduler.

SystemTools.Free WMTaskScheduler TaskScheduler ~
