(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE BootConsole; (** AUTHOR "pjm"; PURPOSE "Boot console"; *)
(*
Config strings:
	BootVol# = prefix [hash] [cache] alias [volpar] ["|" fspar].	(* # is "1".."9" *)
	alias = gen gen .	(* defines a volume and file system generator *)
	gen = mod "." cmd .

Examples:
	BootVol1="AOS AosFS IDE0#2"
	BootVol2="RAM RamFS 2000 4096"

	AosFS="DiskVolumes.New DiskFS.NewFS"
	RamFS="RAMVolumes.New DiskFS.NewFS"
	RFS="RfsClientProxy.New RfsFS.NewFS"
*)

IMPORT
	Machine, Trace, KernelLog, Modules, Streams, Objects, Files, Commands;

CONST
	ModuleName = "Console";
	TraceBoot = FALSE;

PROCEDURE BootCommand(CONST config: ARRAY OF CHAR; flags: SET);
VAR i, j, res: LONGINT; par: ARRAY 32 OF CHAR; s: ARRAY 256 OF CHAR;
BEGIN
	COPY(config, par);
	i := 0; j := 0; WHILE par[j] # 0X DO INC(j) END;
	LOOP
		Machine.GetConfig(par, s);
		IF s # "" THEN
			IF TraceBoot THEN Trace.String("Bootconsole:Commands.Call: "); Trace.String(s); Trace.Ln END;
			Commands.Call(s, flags, res, s);
			IF (res # Commands.Ok) THEN KernelLog.Enter; KernelLog.String(s); KernelLog.Exit END
		END;
		INC(i);
		IF i = 10 THEN EXIT END;
		par[j] := CHR(ORD("0") + i); par[j+1] := 0X
	END
END BootCommand;

PROCEDURE GetString(VAR i: LONGINT; CONST r : ARRAY OF CHAR; VAR s: ARRAY OF CHAR): BOOLEAN;
VAR j: LONGINT;
BEGIN
	WHILE r[i] = " " DO INC(i) END;
	j := 0; WHILE r[i] > " " DO s[j] := r[i]; INC(j); INC(i) END;
	s[j] := 0X;
	IF TraceBoot THEN Trace.String("GetString: "); Trace.String(s); Trace.Ln END;
	RETURN j # 0
END GetString;

PROCEDURE Error(CONST config, val: ARRAY OF CHAR; i: LONGINT);
VAR j: LONGINT; s: ARRAY 32 OF CHAR;
BEGIN
	s := "BootConsole: Bad ";
	KernelLog.String(s);
	j := 0; WHILE s[j] # 0X DO INC(j) END; INC(i, j);
	KernelLog.String(config);
	j := 0; WHILE config[j] # 0X DO INC(j) END; INC(i, j);
	KernelLog.Char("="); KernelLog.Char(22X); INC(i, 2);
	KernelLog.String(val); KernelLog.Char(22X); KernelLog.Ln;
	WHILE i > 0 DO KernelLog.Char(" "); DEC(i) END;
	KernelLog.Char("^"); KernelLog.Ln
END Error;

PROCEDURE Generate(CONST name: ARRAY OF CHAR; par: Files.Parameters): BOOLEAN;
VAR
	factory : Files.FileSystemFactory; res: LONGINT; msg: ARRAY 256 OF CHAR;
	moduleName, procedureName : Modules.Name;
BEGIN
	Commands.Split(name, moduleName, procedureName, res, msg);
	IF (res = Commands.Ok) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF (factory # NIL) THEN
			factory(par);
			RETURN TRUE;
		ELSE
			KernelLog.String(ModuleName); KernelLog.String(": File system alias unknown"); KernelLog.Ln;
		END;
	ELSE
		KernelLog.String(ModuleName); KernelLog.String(": ");  KernelLog.String(msg); KernelLog.Ln;
	END;
	RETURN FALSE;
END Generate;

PROCEDURE OpenVolume(CONST config: ARRAY OF CHAR);
VAR
	i, j, k: LONGINT; parvol, parfs: Files.Parameters;
	volReady : BOOLEAN;
	prefix, alias: Files.Prefix; gen: ARRAY 64 OF CHAR; s: ARRAY 256 OF CHAR;
	argVol, argFs : Streams.StringReader;
BEGIN
	Machine.GetConfig(config, s); (* s = prefix alias [volpar] ["|" fspar] . *)
	IF s = "" THEN RETURN END;
	i := 0;
	IF ~GetString(i, s, prefix) THEN Error(config, s, i); RETURN END;
	IF ~GetString(i, s, alias) THEN Error(config, s, i); RETURN END;

	(* generate volume generator parameter *)
	IF s[i] = " " THEN INC(i) END;
	j := 0; WHILE (s[i] # 0X) & (s[i] # "|") DO s[j] := s[i]; INC(i); INC(j) END;
	IF s[i] = "|" THEN INC(i) END;
	s[j] := 0X;
	NEW(argVol, j+1); argVol.SetRaw(s, 0, j+1);
	NEW(parvol, NIL, argVol, NIL, NIL, NIL);

	(* generate file system generator parameter *)
	j := 0; WHILE s[i] # 0X DO s[j] := s[i]; INC(i); INC(j) END;
	s[j] := 0X;
	NEW(argFs, j+1); argFs.SetRaw(s, 0, j+1);
	NEW(parfs, NIL, argFs, NIL, NIL, NIL);

	(* call volume generator *)
	Machine.GetConfig(alias, s);	(* s = gen gen . ; gen = mod "." cmd . *)
	k := 0;
	IF ~GetString(k, s, gen) THEN Error(alias, s, k); RETURN END;

	(* call volume generator *)
	volReady := FALSE;
	IF gen = "NIL" THEN volReady := TRUE
	ELSE
		IF Generate(gen, parvol) & (parvol.vol # NIL) THEN
			INCL(parvol.vol.flags, Files.Boot); parfs.vol := parvol.vol;
			volReady := TRUE
		END
	END;
	IF volReady THEN
		COPY(prefix, parfs.prefix);
		(* call file system generator *)
		IF GetString(k, s, gen) THEN
			IF Generate(gen, parfs) THEN parvol.vol := NIL END
		ELSE
			Error(alias, s, k)
		END
	END;
	IF Files.This(prefix) = NIL THEN
		KernelLog.String("BootConsole: Mount failed on "); KernelLog.String(config); KernelLog.Ln;
		IF parvol.vol # NIL THEN
			parvol.vol.Finalize()	(* unmount volume *)
		END
	END;
	parfs.out.Update; parfs.error.Update;
	parvol.out.Update; parvol.error.Update;
END OpenVolume;

PROCEDURE OpenVolumes;
VAR config: ARRAY 16 OF CHAR; i: LONGINT;
BEGIN
	config := "BootVol#";
	FOR i := 1 TO 9 DO
		config[7] := CHR(ORD("0") + i); config[8] := 0X;
		OpenVolume(config)
	END
END OpenVolumes;

BEGIN
	OpenVolumes;
	BootCommand("Boot", {Commands.Wait});
	BootCommand("BootSystem", {});
	Objects.Terminate();
END BootConsole.
