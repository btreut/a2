MODULE SystemTools; (** AUTHOR "TF"; PURPOSE "Access to System Functions"; *)

IMPORT
	Machine, Modules, Objects, Commands, Options, ProcessInfo, Kernel, Streams, Dates, Strings, Plugins, Files, SystemVersion;

CONST
	MaxTimers = 16;

	DateTimeFormat = "dd.mm.yyyy hh:nn:ss";

	CR = 0DX;  LF = 0AX;  TAB = 9X;

	TraceCommands = 1;
	TraceFreeDownTo = 2;

	Trace = {};

	OberonKernel = "Oberon.Kernel";

TYPE

	Module = POINTER TO RECORD
		next: Module;
		checked, imports: BOOLEAN;
		m: Modules.Module
	END;

VAR
	timers : ARRAY MaxTimers OF Dates.DateTime;

PROCEDURE Find(root: Module; m: Modules.Module): Module;
BEGIN
	WHILE (root # NIL) & (root.m # m) DO root := root.next END;
	RETURN root
END Find;

PROCEDURE CopyModules(): Module;
VAR first, last, c: Module; m: Modules.Module;
BEGIN
	NEW(first); first.next := NIL; last := first;
	m := Modules.root;
	WHILE m # NIL DO
		NEW(c); c.checked := FALSE; c.imports := FALSE; c.m := m;
		c.next := NIL; last.next := c; last := c;
		m := m.next
	END;
	RETURN first.next
END CopyModules;

PROCEDURE Imports(root, m: Module; CONST name: ARRAY OF CHAR): BOOLEAN;
VAR i: LONGINT;
BEGIN
	IF ~m.checked THEN
		IF m.m.name # name THEN
			i := 0;
			WHILE i # LEN(m.m.module) DO
				IF (m.m.module[i].name = name) OR Imports(root, Find(root, m.m.module[i]), name) THEN
					m.imports := TRUE; i := LEN(m.m.module)
				ELSE
					INC(i)
				END
			END
		ELSE
			m.imports := TRUE
		END;
		m.checked := TRUE
	END;
	RETURN m.imports
END Imports;

PROCEDURE LockOberon;
VAR c: PROCEDURE;
BEGIN
	IF Modules.ModuleByName (OberonKernel) # NIL THEN
		GETPROCEDURE (OberonKernel, "LockOberon", c);
		IF c # NIL THEN c END
	END;
END LockOberon;

PROCEDURE UnlockOberon;
VAR c: PROCEDURE;
BEGIN
	IF Modules.ModuleByName (OberonKernel) # NIL THEN
		GETPROCEDURE (OberonKernel, "UnlockOberon", c);
		IF c # NIL THEN c END
	END;
END UnlockOberon;

(** List all currently loaded modules *)
PROCEDURE ListModules*(context : Commands.Context);
VAR m: Modules.Module; options: Options.Options; details: BOOLEAN;
BEGIN
	NEW(options);
	options.Add("c", "crc", Options.Flag);
	options.Add("l", "ln", Options.Flag);
	options.Add("b", "base", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		m := Modules.root;
		WHILE m # NIL DO
			context.out.String(m.name);
			IF options.GetFlag("base") THEN context.out.String(" base="); context.out.Hex(m.firstProc,-8) END;
			IF options.GetFlag("crc") THEN context.out.String(" crc="); context.out.Hex(m.crc,-8); context.out.String("") END;
			m := m.next;
			IF m # NIL THEN
				IF options.GetFlag("l") THEN context.out.Ln ELSE context.out.String(" ") END;
			ELSE
				context.out.Ln
			END;
		END;
	END;
END ListModules;

(** List all loaded plugins. *)
PROCEDURE ListPlugins*(context : Commands.Context);
VAR r, p : Plugins.Table; i, j : LONGINT;
BEGIN
	Plugins.main.GetAll(r);
	IF r # NIL THEN
		FOR i := 0 TO LEN(r^)-1 DO
			context.out.Int(i, 1); context.out.Char(" ");
			context.out.String(r[i].name); context.out.Char(" ");
			context.out.String(r[i].desc); context.out.Ln;
			r[i](Plugins.Registry).GetAll(p);
			IF p # NIL THEN
				FOR j := 0 TO LEN(p^)-1 DO
					context.out.Char(TAB); context.out.Int(j, 1); context.out.Char(" ");
					context.out.String(p[j].name); context.out.Char(" ");
					context.out.String(p[j].desc); context.out.Ln;
					context.out.Update;
				END;
			END
		END
	END;
END ListPlugins;

(** List all  commands of the specified module. *)
PROCEDURE ListCommands*(context : Commands.Context); (** module *)
VAR m : Modules.Module; moduleName : Modules.Name; i : LONGINT;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(moduleName);
	m := Modules.ModuleByName(moduleName);
	IF m # NIL THEN
		FOR i := 0 TO LEN(m.command)-1 DO
			context.out.String(m.name); context.out.Char(".");
			context.out.String(m.command[i].name);
			context.out.Ln;
		END
	ELSE
		context.error.String("Module not found"); context.error.Ln
	END;
END ListCommands;

PROCEDURE List*(context : Commands.Context);
VAR string : ARRAY 32 OF CHAR;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(string);
	IF (string = "plugins") THEN ListPlugins(context);
	ELSIF (string = "modules") THEN ListModules(context);
	ELSIF (string = "commands") THEN ListCommands(context);
	ELSE
		context.error.String('Usage: SystemTools.List ("plugins"|"modules"|("commands" moduleName))');
		context.error.Ln;
	END;
END List;

PROCEDURE ModuleIsLoaded(CONST name : Modules.Name) : BOOLEAN;
BEGIN
	RETURN Modules.ModuleByName(name) # NIL;
END ModuleIsLoaded;

(** Show all modules that import 'basemodule' (transitively) and are currently loaded. *)

PROCEDURE WhoImports*(context : Commands.Context); (** basemodule ~ *)
VAR name : Modules.Name; root, m : Module;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(name);
	IF ModuleIsLoaded(name) THEN
		root := CopyModules();
		m := root;
		WHILE m # NIL DO
			IF Imports(root, m, name) THEN
				context.out.String(m.m.name); context.out.Ln;
			END;
			m := m.next;
		END;
	ELSE
		context.error.String("Module "); context.error.String(name); context.error.String(" is not loaded."); context.error.Ln;
	END;
END WhoImports;

(** Check whether the specified module is currenlty loaded. *)

PROCEDURE IsLoaded*(context : Commands.Context);
VAR name : Modules.Name;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(name);
	context.out.String("Module "); context.out.String(name);
	IF ModuleIsLoaded(name) THEN
		context.out.String(" is loaded.");
	ELSE
		context.out.String(" is not loaded.");
	END;
	context.out.Ln;
END IsLoaded;

(** Load the specified module *)
PROCEDURE Load*(context : Commands.Context); (** modulename ~ *)
VAR name : Modules.Name; module : Modules.Module; msg : ARRAY 256 OF CHAR; res : LONGINT;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(name);
	IF ModuleIsLoaded(name) THEN
		context.result := Modules.Ok;
		context.out.String(name); context.out.String(" is already loaded."); context.out.Ln;
	ELSE
		module := Modules.ThisModule(name, res, msg);
		context.result := res;
		IF (res = Modules.Ok) THEN
			context.out.String(name); context.out.String(" loaded."); context.out.Ln;
		ELSE
			context.error.String("Could not load module "); context.error.String(name);
			context.error.String(", res: "); context.error.Int(res, 0);
			IF (msg # "") THEN
				context.error.String(" ("); context.error.String(msg); context.error.String(")");
			END;
			context.error.Ln;
		END;
	END;
END Load;

(** Free all modules that import basemodule (transitively). *)
PROCEDURE FreeDownTo*(context : Commands.Context); (** basemodule ~ *)
VAR
	modulename : ARRAY 128 OF CHAR;
	root, m: Module; res: LONGINT;
	timer: Kernel.Timer; msg: ARRAY 64 OF CHAR;
	nbrOfUnloadedModules : LONGINT;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.String(modulename);
	LockOberon;
	NEW(timer); timer.Sleep(200); (* temporary workaround for race with System.FreeOberon *)
	root := CopyModules();

	nbrOfUnloadedModules := 0;
	m := root;
	WHILE m # NIL DO
		IF Imports(root, m, modulename) THEN
			IF TraceFreeDownTo IN Trace  THEN
				context.out.String(m.m.name); context.out.Ln;
			END;
			Modules.FreeModule(m.m.name, res, msg);
			IF res # 0 THEN
				context.error.String(msg);
			ELSE
				INC(nbrOfUnloadedModules);
			END
		END;
		m := m.next
	END;
	UnlockOberon; (* in case Oberon still running *)
	context.out.String("Unloaded "); context.out.Int(nbrOfUnloadedModules, 0); context.out.String(" modules."); context.out.Ln;
END FreeDownTo;

(** Unload modules from memory *)
PROCEDURE Free*(context : Commands.Context); (** {modulename} ~ *)
VAR name, msg : ARRAY 64 OF CHAR; res : LONGINT;
BEGIN
	WHILE context.arg.GetString(name) DO
		IF name # "" THEN
			context.out.String("Unloading "); context.out.String(name); context.out.String("... ");
			Modules.FreeModule(name, res, msg);
			IF res # 0 THEN context.out.String(msg)
			ELSE context.out.String("done.")
			END;
			context.out.Ln;
		END;
	END;
END Free;

PROCEDURE Kill*(context : Commands.Context); (** pid { pid } ~ *)
VAR process : Objects.Process; pid : LONGINT;
BEGIN {EXCLUSIVE}
	WHILE context.arg.GetInteger(pid, FALSE) DO
		context.out.Int(pid, 0);
		process := ProcessInfo.GetProcess(pid);
		IF process # NIL THEN
			Objects.TerminateThis(process, FALSE);
			context.out.String(" Process killed")
		ELSE
			context.out.String(" Process not found")
		END;
		context.out.Ln;
	END;
END Kill;

PROCEDURE ShowProcesses*(context : Commands.Context); (** [options] ~ *)
VAR
	options : Options.Options;
	processes : ARRAY ProcessInfo.MaxNofProcesses OF Objects.Process;
	nofProcesses : LONGINT;
	string : ARRAY 16 OF CHAR;
	i : LONGINT;
BEGIN
	NEW(options);
	options.Add("s", "sort", Options.String);
	IF options.Parse(context.arg, context.error) THEN
		ProcessInfo.GetProcesses(processes, nofProcesses);
		IF options.GetString("sort", string) THEN
			IF (string = "id") THEN
				ProcessInfo.Sort(processes, nofProcesses, ProcessInfo.SortByID);
			ELSIF (string = "priority") THEN
				ProcessInfo.Sort(processes, nofProcesses, ProcessInfo.SortByPriority);
			ELSIF (string = "mode") THEN
				ProcessInfo.Sort(processes, nofProcesses, ProcessInfo.SortByMode);
			ELSE
				context.error.String("Sort option "); context.error.String(string);
				context.error.String(" unknown... ignore."); context.error.Ln;
			END;
		END;
		FOR i := 0 TO nofProcesses - 1 DO ProcessInfo.ShowProcess(processes[i], context.out); END;
		context.out.Int(nofProcesses, 0); context.out.String(" processes"); context.out.Ln;
		ProcessInfo.Clear(processes);
	END;
END ShowProcesses;

PROCEDURE ShowStacks*(context : Commands.Context);
VAR processes : ARRAY ProcessInfo.MaxNofProcesses OF Objects.Process; nofProcesses, i : LONGINT;
BEGIN
	ProcessInfo.GetProcesses(processes, nofProcesses);
	FOR i := 0 TO nofProcesses - 1 DO ProcessInfo.ShowStack(processes[i], context.out); END;
	ProcessInfo.Clear(processes);
END ShowStacks;

PROCEDURE ShowStack*(context : Commands.Context); (** pid ~ *)
VAR process : Objects.Process; pid : LONGINT;
BEGIN
	context.arg.SkipWhitespace;
	context.arg.Int(pid, FALSE);
	process := ProcessInfo.GetProcess(pid);
	IF (process # NIL) THEN
		context.out.String("Stack of process ID = "); context.out.Int(pid, 0); context.out.Ln;
		ProcessInfo.ShowStack(process, context.out);
	ELSE
		context.error.String("Process ID = "); context.error.Int(pid, 0); context.error.String(" not found.");
		context.error.Ln;
	END;
END ShowStack;

(* Changes the extension, Usage: RenameExtension extFrom extTo~ *)
PROCEDURE RenameExtension*(context : Commands.Context);
VAR
	enumerator : Files.Enumerator;
	oe, ne, temp: ARRAY 16 OF CHAR;
	name, file, ext : Files.FileName; flags : SET; time, date, size, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(oe);
	context.arg.SkipWhitespace; context.arg.String(ne);
	NEW(enumerator);
	temp := "*.";
	Strings.Append(temp, oe);
	enumerator.Open(temp, {});
	temp := ".";
	Strings.Append(temp, ne);
	context.out.String("-- Renaming Extension --"); context.out.Ln;
	WHILE enumerator.HasMoreEntries() DO
		IF enumerator.GetEntry(name, flags, time, date, size) THEN
			Strings.GetExtension(name, file, ext);
			Strings.Append(file, temp);
			context.out.String("Renaming: "); context.out.String(name); context.out.String(" to: "); context.out.String(file);
			Files.Rename(name, file, res);
			IF res = 0 THEN context.out.String("    done"); ELSE context.out.String("   Error!"); END;
			context.out.Ln;
		END;
	END;
	context.out.String("-- all done --"); context.out.Ln;
	enumerator.Close;
END RenameExtension;

PROCEDURE IsDelimiter(ch : CHAR) : BOOLEAN;
BEGIN
	RETURN (ch = " ") OR (ch = CR) OR (ch = LF) OR (ch = TAB) OR (ch = ";") OR (ch = 0X);
END IsDelimiter;

(** Sequentially execute a list of commands .
IMPORTANT: This command is specially handled by command interpreters that support it. It is the only command
in the system for which two tilde characters (only separated by whitespace) are used to delimit the parameter string.
If you change the name of this module or this command, you have to adapt:
- WMTextView.TextView.FindCommandRange *)
PROCEDURE DoCommands*(context : Commands.Context); (** command {"~" command}  "~" *)
VAR
	newContext : Commands.Context;
	commands : Strings.StringArray;
	command, parameters, paramString : Strings.String;
	temp : Strings.String;
	msg : ARRAY 128 OF CHAR;
	cur, available, i, j, k, res : LONGINT;

	PROCEDURE CreateContext(paramString : Strings.String) : Commands.Context;
	VAR c : Commands.Context; arg : Streams.StringReader; dummy : ARRAY 1 OF CHAR;
	BEGIN
		IF (paramString = NIL) THEN
			NEW(arg, 1); dummy := ""; arg.SetRaw(dummy, 0, 1);
		ELSE
			NEW(arg, LEN(paramString)); arg.SetRaw(paramString^, 0, LEN(paramString));
		END;
		NEW(c, context.in, arg, context.out, context.error, context.caller);
		RETURN c;
	END CreateContext;

	PROCEDURE Resize(VAR t: Strings.String; len: LONGINT);
	VAR new: Strings.String; i: LONGINT;
	BEGIN
		NEW(new, len);
		IF t # NIL THEN
			FOR i := 0 TO LEN(t)-1 DO new[i] := t[i] END;
		END;
		t := new;
	END Resize;


BEGIN
	cur := context.arg.Available();
	IF (cur < 1) THEN RETURN; END;
	NEW(temp, cur + 1);
	available := 0;
	WHILE cur > 0 DO
		Resize(temp, available+cur+1);
		context.arg.Bytes(temp^, available, cur, i); (* ignore i *)
		INC(available, cur);
		cur := context.arg.Available();
	END;

	RemoveComments(temp^, available);
	Strings.Truncate (temp^, available);
	commands := Strings.Split(temp^, "~");

	NEW(command, LEN(temp)); NEW(parameters, LEN(temp));
	i := 0;
	LOOP
		Strings.TrimWS(commands[i]^);

		IF (commands[i]^ = "") THEN
			(* This means that two tilde characters were only separated by whitespace. One delimits
			the last command we have executed and the other one delimits the SystemTools.DoCommands parameters *)
			EXIT;
		END;

		(* extract command *)
		j := 0; k := 0;
		WHILE ~IsDelimiter(commands[i][j])  DO command[k] := commands[i][j]; INC(k); INC(j); END;
		command[k] := 0X;
		IF k = 0 THEN EXIT; END;	(* end of string *)

		(* extract parameters *)
		k := 0;
		IF (commands[i][j] # "~") & (commands[i][j] # 0X) THEN
			INC(j); WHILE (commands[i][j] # 0X) & (commands[i][j] # "~") DO parameters[k] := commands[i][j]; INC(k); INC(j); END;
			parameters[k] := 0X;
		END;
		IF k > 0 THEN
			NEW(paramString, k+1);
			FOR j := 0 TO k DO paramString[j] := parameters[j]; END;
		ELSE
			paramString := NIL;
		END;
		newContext := CreateContext(paramString);

		IF TraceCommands IN Trace THEN
			context.out.String("SystemTools.DoCommands: Execute command '"); context.out.String(command^);
			context.out.String("' parameters: ");
			IF (paramString = NIL) THEN context.out.String("None");
			ELSE
				context.out.String("'"); context.out.String(paramString^); context.out.String("'");
			END;
			context.out.Ln;
		END;

		Commands.Activate(command^, newContext, {Commands.Wait}, res, msg);

		IF res # Commands.Ok THEN
			context.error.String("SystemTools.DoCommands: Command: '");
			context.error.String(command^); context.error.String("', parameters: ");
			IF paramString = NIL THEN
				context.error.String("None");
			ELSE
				context.error.String("'"); context.error.String(paramString^); context.error.String("'");
			END;
			context.error.String(" failed: ");
			context.error.String(msg); context.error.String(" (res: "); context.error.Int(res, 0); context.error.String(")");
			context.error.Ln;
			EXIT;
		END;
		INC(i);
		IF i >= LEN(commands) THEN EXIT; END;
	END;
END DoCommands;

(** remove Oberon style comments (parantheses and asterisks) from a string of a certain length.
- comments may be nested arbitrarily
- the operation is performed in situ: comments are replaced with whitespace characters
**)
PROCEDURE RemoveComments(VAR string: ARRAY OF CHAR; length: LONGINT);
VAR
	pos, level: LONGINT;
BEGIN
	level := 0;
	pos := 0;
	WHILE pos <= length - 1 DO
		IF (string[pos] = '(') & (pos + 1 <= length - 1) & (string[pos + 1] = '*') THEN
			(* a comment opened -> replace *)
			INC(level);
			string[pos] := ' '; string[pos + 1] := ' '; INC(pos, 2)
		ELSIF (string[pos] = '*') & (pos + 1 <= length - 1) & (string[pos + 1] = ')') THEN
			(* a comment is closed -> replace *)
			DEC(level);
			string[pos] := ' '; string[pos + 1] := ' '; INC(pos, 2)
		ELSIF level <= 0 THEN
			(* character outside any comment -> leave as is *)
			INC(pos)
		ELSE
			(* character within a comment -> replace *)
			string[pos] := ' '; INC(pos)
		END
	END
END RemoveComments;

PROCEDURE Repeat*(context : Commands.Context); (* nofTimes command [command parameters] ~ *)
VAR
	command, msg : ARRAY 128 OF CHAR;
	parameterPosition : LONGINT;
	nofTimes, res : LONGINT;
BEGIN
	nofTimes := 0; command := "";
	context.arg.SkipWhitespace;	context.arg.Int(nofTimes, FALSE);
	context.arg.SkipWhitespace;	context.arg.String(command);
	IF (nofTimes > 0) & (command # "") THEN
		res := Commands.Ok;
		parameterPosition := context.arg.Pos();
		WHILE (nofTimes > 0) & (res = Commands.Ok) DO
			context.arg.SetPos(parameterPosition);
			Commands.Activate(command, context, {Commands.Wait}, res, msg);
			DEC(nofTimes);
		END;
		IF (res # Commands.Ok) THEN
			context.out.String("Error in command '"); context.out.String(command); context.out.String("', res: ");
			context.out.Int(res, 0); context.out.Ln;
		END;
	END;
END Repeat;

(** Time interval measurement
 	- start/starth [number]: Set timer <number> to current time (number = 0 if omitted)
  	- elapsed/elapsedh [number]: Display time difference between timer <number> and the current time (number = 0 if omitted)
	- diff/diffh number1 number2: Display time difference between the two timers
	*)
PROCEDURE Timer*(context : Commands.Context); (** [  ["start"["h"] [number]] | ["elapsed"["h"] [number]] | ["diff"["h"] number1 number2]  ] ~ *)
VAR
	string : ARRAY 128 OF CHAR; nbr1, nbr2 : LONGINT;

	PROCEDURE ShowUsage;
	BEGIN
		context.out.String('Usage: SystemTools.Timer  [  ["start" [number]] | ["elapsed" [number]] | ["diff" number1 number2]  ]');
		context.out.Ln;
	END ShowUsage;

	PROCEDURE Valid(number : LONGINT) : BOOLEAN;
	BEGIN
		RETURN (0 <= number) & (number < MaxTimers);
	END Valid;

BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace;	context.arg.String(string);
	context.arg.SkipWhitespace;	context.arg.Int(nbr1, FALSE);
	context.arg.SkipWhitespace;	context.arg.Int(nbr2, FALSE);

	IF ~Valid(nbr1) THEN ShowUsage; RETURN; END;

	IF (string = "start") THEN
		timers[nbr1] := Dates.Now();
	ELSIF (string = "elapsed") THEN
		Strings.ShowTimeDifference(timers[nbr1], Dates.Now(), context.out);
	ELSIF Valid(nbr2) THEN
		IF (string = "diff") THEN
			Strings.ShowTimeDifference(timers[nbr1], timers[nbr2], context.out);
		ELSE
			ShowUsage;
		END;
	ELSE
		ShowUsage;
	END;
END Timer;

(** If no parameter is specified, this command displays the system time on Kernel Log. *)
PROCEDURE Time*(context : Commands.Context); (** ~ *)
VAR datetime : Dates.DateTime; string : ARRAY 32 OF CHAR;
BEGIN
	datetime := Dates.Now();
	Strings.FormatDateTime(DateTimeFormat, datetime, string);
	context.out.String(string); context.out.Ln;
END Time;

(** Display the content of the specified file *)
PROCEDURE ShowFile*(context : Commands.Context); (** filename ~ *)
VAR filename : Files.FileName; file : Files.File; reader : Files.Reader; ch : CHAR;
BEGIN
	IF context.arg.GetString(filename) THEN
		file := Files.Old(filename);
		IF (file # NIL) THEN
			Files.OpenReader(reader, file, 0);
			REPEAT
				reader.Char(ch);
				context.out.Char(ch);
			UNTIL (reader.res # Streams.Ok);
		ELSE
			context.error.String("Could not open file "); context.error.String(filename); context.error.Ln;
		END;
	END;
END ShowFile;

(** Display a string on the context output stream  *)
PROCEDURE Show*(context : Commands.Context); (** string ~ *)
VAR ch : CHAR;
BEGIN
	REPEAT
		ch := context.arg.Get();
		IF (ch # 0X) THEN context.out.Char(ch); END;
	UNTIL (context.arg.res # Streams.Ok);
END Show;

(** Print carriage return on the context output stream *)
PROCEDURE Ln*(context : Commands.Context); (** ~ *)
BEGIN
	context.out.Ln;
END Ln;

(** Block for ms milliseconds *)
PROCEDURE Wait*(context : Commands.Context); (** ms ~ *)
VAR timer : Kernel.Timer; milliseconds : LONGINT;
BEGIN
	IF context.arg.GetInteger(milliseconds, FALSE) & (milliseconds > 0) THEN
		NEW(timer);
		timer.Sleep(milliseconds);
	END;
END Wait;

PROCEDURE Reboot*;
BEGIN
	Modules.Shutdown(Modules.Reboot);
END Reboot;

PROCEDURE PowerDown*;
BEGIN
	Modules.Shutdown(Modules.PowerDown);
END PowerDown;

(** Invoke garbage collector *)
PROCEDURE CollectGarbage*(context : Commands.Context);
BEGIN
	context.out.String("Collecting garbage... ");
	Kernel.GC;
	context.out.String("done."); context.out.Ln;
END CollectGarbage;

PROCEDURE Version*(context : Commands.Context);
BEGIN
	context.out.String(Machine.version);context.out.String(" Kernel CRC="); context.out.Hex(SystemVersion.BootCRC, 8);  context.out.Ln;
END Version;

END SystemTools.

SystemTools.Free S  ~
SystemTools.Kill 57 ~

SystemTools.Time ~
SystemTools.Show Hello World ~

SystemTools.DoCommands
	SystemTools.Timer start ~
	SystemTools.Show System Time ~ SystemTools.Time ~ SystemTools.Ln ~
	SystemTools.Show System Time again ~ SystemTools.Time ~ SystemTools.Ln ~
	SystemTools.Wait 2000 ~
	SystemTools.Show Time elapsed: ~ SystemTools.Timer elapsed ~ SystemTools.Ln ~
~

SystemTools.CollectGarbage ~

