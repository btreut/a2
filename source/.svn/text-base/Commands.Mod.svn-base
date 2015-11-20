(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Commands; (** AUTHOR "pjm"; PURPOSE "Commands and parameters"; *)

IMPORT Objects, Modules, Streams, KernelLog, Trace, Machine;

CONST

	(** Activate flags. *)
	Wait* = 0;	(** Wait until the activated command returns. *)
	InheritContext*= 1; (** Inherit context (as far as not overwritten) of the caller *)

	Ok* = 0;
	CommandNotFound* = 3901;
	CommandError* = 3902;
	CommandParseError* = 3903;
	CommandTrapped* = 3904;

	(* Separates module name from procedure name *)
	Delimiter* = ".";

	(* Runner states *)
	Started = 0; Loaded = 1; Finished = 2;

TYPE

	Context* = OBJECT
	VAR
		in-, arg- : Streams.Reader;
		out-, error- : Streams.Writer;
		caller-: OBJECT;
		result*: LONGINT;

		PROCEDURE &Init*(in, arg : Streams.Reader; out, error : Streams.Writer; caller: OBJECT);
		BEGIN
			IF (in = NIL) THEN in := GetEmptyReader(); END;
			IF (arg = NIL) THEN arg := GetEmptyReader()END;
			IF (out = NIL) THEN NEW(out, KernelLog.Send, 128); END;
			IF (error = NIL) THEN NEW(error, KernelLog.Send, 128); END;
			SELF.in := in; SELF.arg := arg; SELF.out := out; SELF.error := error; SELF.caller := caller; SELF.result := Ok;
			ASSERT((in # NIL) & (arg # NIL) & (out # NIL) & (error # NIL));
		END Init;

	END Context;


	(*see StreamUtilities.Mod: reader that can daisychained with another reader that extracts a copy of the data flow to a monitor stream*)
	ReaderMonitor* = OBJECT(Streams.Reader)
		VAR in: Streams.Reader; tracer: Streams.Writer; receive: Streams.Receiver; pos0: LONGINT;

		PROCEDURE &Init(in: Streams.Reader; tracer: Streams.Writer);
		BEGIN
			SELF.tracer := tracer;
			InitReader(Receiver, 1024);
			SELF.in := in;
			pos0 := in.Pos();
		END Init;

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		BEGIN
			ASSERT((size > 0) & (min <= size) & (min >= 0));
			in.Bytes(buf, ofs, size, len);
			tracer.Bytes(buf, ofs, len);
			IF len < size THEN (* end of data indication *)
				tracer.String("~"); tracer.Ln;
			END;
			res:=in.res
		END Receiver;

		PROCEDURE CanSetPos(): BOOLEAN;
		BEGIN RETURN in.CanSetPos()
		END CanSetPos;

		PROCEDURE SetPos(pos: LONGINT);
		BEGIN Reset; pos0 := pos; in.SetPos(pos)
		END SetPos;

		PROCEDURE Pos(): LONGINT;
		BEGIN RETURN Pos^()+pos0;
		END Pos;

	END ReaderMonitor;

	(* Procedure types that can be called be runner thread *)
	CommandProc = PROCEDURE;
	CommandContextProc = PROCEDURE(context : Context);

TYPE

	Runner = OBJECT
	VAR
		moduleName, commandName : Modules.Name;
		context : Context;

		tracer: Streams.Writer; r: ReaderMonitor;

		proc : CommandProc;
		commandProc : CommandContextProc;

		msg : ARRAY 128 OF CHAR; res : LONGINT;

		module : Modules.Module;
		state : LONGINT;
		exception : BOOLEAN;

		PROCEDURE &Init*(CONST moduleName, commandName : Modules.Name; context : Context);
		BEGIN
			SELF.moduleName := moduleName; SELF.commandName := commandName;

			IF (context = NIL) THEN NEW(context, NIL, NIL, NIL, NIL, NIL); END;
			IF trace THEN
				Streams.OpenWriter(tracer, Trace.Send);
				NEW(r , context.arg, tracer); context.arg:=r;
				tracer.String("Commands.Activate ");
				tracer.String(moduleName); tracer.String(Delimiter); tracer.String(commandName); tracer.Char(" ");
			END;
			SELF.context := context;
			res := CommandError; COPY("Error starting command", msg);
			exception := FALSE;
			state := Started;
		END Init;

		PROCEDURE Join(this : LONGINT; VAR res : LONGINT; VAR msg : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			AWAIT(state >= this);
			res := SELF.res; COPY(SELF.msg, msg);
		END Join;

	BEGIN {ACTIVE, SAFE}
		IF ~exception THEN
			exception := TRUE; (* catch exceptions from now on *)
			module := Modules.ThisModule(moduleName, res, msg);
			IF (res = Ok) THEN
				IF commandName # "" THEN
					GETPROCEDURE(moduleName, commandName, proc);
					IF (proc = NIL) THEN
						GETPROCEDURE(moduleName, commandName, commandProc);
					END;
					IF (proc = NIL) & (commandProc = NIL) THEN
						res := CommandNotFound;
						msg := "Command ";
						Modules.Append(moduleName, msg); Modules.Append(Delimiter, msg); Modules.Append(commandName, msg);
						Modules.Append(" not found", msg);
					END;
				END;
			END;
			BEGIN {EXCLUSIVE} state := Loaded; END;
			IF (res = Ok) THEN
				ASSERT((proc # NIL) OR (commandProc # NIL) OR (commandName = ""));
				IF (proc # NIL) THEN
					proc();
					context.out.Update; context.error.Update;
				ELSIF (commandProc # NIL) THEN
					ASSERT(context # NIL);
					commandProc(context);
					context.out.Update; context.error.Update;
					res := context.result;
					IF res # Ok THEN msg := "Command not successful"; END;
				END;
			END;
		ELSE
			res := CommandTrapped; COPY("Exception during command execution", msg);
		END;
		IF trace THEN
			tracer.String(" ~"); tracer.Ln; tracer.Update
		END;
		BEGIN {EXCLUSIVE} state := Finished; END;
	END Runner;

VAR
	emptyString : ARRAY 1 OF CHAR;
	trace: BOOLEAN;
	defaultContext: Context; (* Fallback. Note that this context would be shared by different users -- may be used for tracing though *)


(* Create a ready on a empty string *)

PROCEDURE GetEmptyReader() : Streams.Reader;
VAR reader : Streams.StringReader;
BEGIN
	NEW(reader, 1); reader.SetRaw(emptyString, 0, 1);
	RETURN reader;
END GetEmptyReader;

(** Splits a command string of the form moduleName.commandProcName into its components. Can be used to check whether a
	command string is syntactically correct, i.e. is of the form 'ModuleName "." [ProcedureName]' *)

PROCEDURE Split*(CONST cmdstr : ARRAY OF CHAR; VAR moduleName, procedureName : Modules.Name; VAR res : LONGINT; VAR msg : ARRAY OF CHAR);
VAR i, j : LONGINT; maxlen, cmdlen : LONGINT;
BEGIN
	res := CommandParseError;
	moduleName := ""; procedureName := ""; msg := "";
	maxlen := LEN(moduleName); cmdlen := LEN(cmdstr);
	i := 0; WHILE (i < cmdlen) & (i < maxlen-1) & (cmdstr[i] # Delimiter) & (cmdstr[i] # 0X) DO moduleName[i] := cmdstr[i]; INC(i); END;
	IF (i >= maxlen)  THEN
		COPY("Module name too long", msg);
	ELSIF (i >= cmdlen) THEN
		COPY("Command string not 0X terminated", msg);
	ELSIF (cmdstr[i] # Delimiter) THEN
		COPY('Expected ModuleName "." [ProcedureName]', msg);
	ELSE
		(* We allow cmdstr[i] = 0X. That means the module will be loaded but not command procedure will be started *)
		moduleName[i] := 0X;
		INC(i); (* Skip Delimiter *)
		j := 0;
		WHILE (i < cmdlen) & (j < maxlen-1) & (cmdstr[i] # 0X) DO procedureName[j] := cmdstr[i]; INC(j); INC(i); END;
		IF (i >= cmdlen) THEN
			COPY("Command string not 0X terminated", msg);
		ELSIF (j >= maxlen-1) THEN
			COPY("Command name too long", msg);
		ELSE
			procedureName[j] := 0X;
			res := Ok; COPY("", msg);
		END;
	END;
END Split;

(**	Can be called by a command to retrieve the context associated with its active object. *)

PROCEDURE GetContext*() : Context;
VAR object: ANY;
BEGIN
	object := Objects.ActiveObject();
	IF (object # NIL) & (object IS Runner) & (object(Runner).state = Loaded) THEN RETURN object(Runner).context;
	ELSE RETURN defaultContext
	END;
END GetContext;

(**	Activate a command in its own active object.
	Returns res = Ok if successful, otherwise msg contains error message.
	The command can call GetConext() to get its context, which is also passed directly. *)

PROCEDURE Activate*(CONST cmd : ARRAY OF CHAR; context : Context; flags : SET; VAR res : LONGINT; VAR msg : ARRAY OF CHAR);
VAR moduleName, commandName : Modules.Name; run : Runner;
BEGIN

	Split(cmd, moduleName, commandName, res, msg);
	IF (res = Ok) THEN
		NEW(run, moduleName, commandName, context);
		run.Join(Loaded, res, msg); (* Avoid race condition described in Modules.Mod *)
		IF (res = Ok) & (Wait IN flags) THEN run.Join(Finished, res, msg); END
	END;
END Activate;

(** Activate a string of commands, including their parameters.
	The string is parsed from left to right and Activate is called for every command.
	Parsing stops at the end of the string, or when Activate returns an error.
	The flags are applied to every command, i.e., for sequential execution,
	use the Wait flag (the caller waits until all commands return).
	Syntax:
		cmds = [mode " " ] cmd {";" cmd} .
		mode = "PAR" | "SEQ" .
		cmd = mod ["." proc] [" " params] .
		params = {<any character except ";">} .
*)

PROCEDURE Call*(cmds : ARRAY OF CHAR; flags : SET; VAR res : LONGINT; VAR msg : ARRAY OF CHAR);
VAR  outer, context : Context; arg : Streams.StringReader; i, j, k : LONGINT; mode : ARRAY 5 OF CHAR;
par : POINTER TO ARRAY OF CHAR;
BEGIN
	IF trace THEN 	Trace.String("Commands.Call "); Trace.String(cmds); Trace.String("~ "); Trace.Ln END;
	NEW(par,LEN(cmds));
	i := 0; WHILE (i # 4) & (i # LEN(cmds)) DO mode[i] := cmds[i]; INC(i); END;
	mode[i] := 0X;	(* copy at most first 4 characters *)
	IF mode = "PAR " THEN EXCL(flags, Wait);
	ELSIF mode = "SEQ " THEN INCL(flags, Wait);
	ELSE i := 0;	(* reset to start *)
	END;
	LOOP
		k := 0;
		WHILE (cmds[i] # " ") & (cmds[i] # 09X) & (cmds[i] # 0DX) & (cmds[i] # 0AX) & (cmds[i] # 0X) & (cmds[i] # ";") DO cmds[k] := cmds[i]; INC(k); INC(i); END;
		IF k = 0 THEN EXIT; END;	(* end of string *)
		j := 0;
		IF (cmds[i] # ";") & (cmds[i] # 0X) THEN (* parameters *)
			INC(i); WHILE (cmds[i] # 0X) & (cmds[i] # ";") DO par[j] := cmds[i]; INC(i); INC(j); END;
		END;
		IF cmds[i] = ";" THEN INC(i); END;
		par[j] := 0X; cmds[k] := 0X;
		NEW(arg, j+1); arg.SetRaw(par^, 0, j+1);
		IF InheritContext IN flags THEN
			outer := GetContext();
			NEW(context, outer.in, arg, outer.out, outer.error, outer.caller);
		ELSE
			NEW(context, NIL, arg, NIL, NIL, NIL)
		END;
		Activate(cmds, context, flags, res, msg);
		IF (res # Ok) THEN EXIT; END;
	END;
END Call;

PROCEDURE Init;
VAR s: ARRAY 4 OF CHAR;
BEGIN
	emptyString[0] := 0X;
	Machine.GetConfig("TraceCommands", s);
	trace := (s[0] = "1");
	NEW(defaultContext,NIL,NIL,NIL,NIL,NIL);
END Init;


BEGIN
	Init;

END Commands.
