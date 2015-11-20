(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE FSTools; (** AUTHOR "be"; PURPOSE "Files Tools"; *)
(**
 * Usage:
 *
 *	FSTools.Mount prefix alias [volpar] ["|" fspar] ~		Mount the specified volume.
 *	FSTools.Unmount prefix [\f] ~							Unmount the specified volume. Use /f to force unmounting.
 *
 *	FSTools.SetDefault prefix ~							Set the specified volume as default volume.
 *	FSTools.Watch ~										Diplays a list of all mounted file systems
 *
 *	FSTools.CopyFiles [-ioq] {sourcefile " => " destfile} ~	Copy the specified files to
 *	FSTools.RenameFiles [-i] {oldname " => " newname} ~	Rename files
 *	FSTools.DeleteFiles [-i] {file} ~						Delete the specified files
 * 	FSTools.Directory [-ts] ~								Show Directory (t: show creation times, s: show file sizes)
 *
 *	FSTools.Safe ~ 										disallow pattern matching
 *	FSTools.Unsafe ~ 										allow pattern matching
 *
 *	Options i, o and q:
 *
 *	i: 	ignore errors, e.g. continue with deletion of files if a file could not be deleted
 *	o:	force overwriting existing files
 *	q:	quiet mode
 *
 * Examples:
 *
 *	FSTools.Mount FAT FatFS IDE0#4~
 * 	FSTools.Unmount FAT~
 *
 *	FSTools.CopyFiles AOS:Configuration.XML => FAT:Configuration.XML AOS:Test.Mod => FAT:Test.Mod ~
 *	FSTools.RenameFiles Configuration.XML => Configuration.Bak ~
 *	FSTools.DeleteFiles Test.Mod Bimbo.Mod ~
 *	FSTools.Directory -s ~
 *
 * Pattern matching:
 *
 *	Supported by: CopyFiles, RenameFiles, DeleteFiles and Directory
 *
 *	WARNING: If no prefix is specified, the source mask if checked against all files on all mounted volumes, i.e. the command
 *				FSTools.DeleteFiles * ~ would DELETE ALL FILES ON ALL MOUNTED partitions.
 *
 *	The source mask may contain an arbitrary number of '*' (matches any string) and '?' (matches any character) characters.
 *	For operations that have a target, the target mask semantics is the following:
 *
 *		- '?' characters are not allowed in the target mask
 *		- '*' characters are not allowed in the prefix and path
 *		- every occurence of the character '*' is replaced by ...
 *				... the source file name if there is no '.' character on the left side of the '*' character
 *				... the source file extension if there is at least one '.' character on the left side of the '*' character
 *
 *	Notes:
 *		- Files treats the right-most '.*' as file extension, e.g. the file extension of 'AosBimbo.Test.00.Bak.Mod' is '.Mod'
 *
 *)

IMPORT Modules, Commands, Options, Streams, Files, Configuration, Dates, Strings;

CONST
	MaxNameLen = 512; (* Maximum file name length including path and 0X-termination *)

	InitialFilelistSize = 1024;

	(* Layout for Directory operation *)
	Column1 = 30;
	FormatDateTime = "dd.mm.yyyy hh:nn:ss";

	Error = -1;

	CR = 0DX;  LF = 0AX;

TYPE
	String = Strings.String;

	FileList = POINTER TO ARRAY OF String;

	EnumProc = PROCEDURE(context : Commands.Context);

VAR
	unsafeMode : BOOLEAN;

PROCEDURE ExpandAlias(CONST alias : ARRAY OF CHAR; VAR genvol, genfs: ARRAY OF CHAR);
VAR t: ARRAY 64 OF CHAR; i, j, res: LONGINT;
BEGIN
	genvol[0] := 0X; genfs[0] := 0X;
	t := "Files.Alias.";
	i := 0; WHILE t[i] # 0X DO INC(i) END;
	j := 0; WHILE alias[j] # 0X DO t[i] := alias[j]; INC(i); INC(j) END;
	t[i] := 0X;

	Configuration.Get(t, t, res);

	i := 0;
	WHILE (t[i] # 0X) & (t[i] # ";") DO genvol[i] := t[i]; INC(i) END;
	genvol[i] := 0X;

	IF (t[i] = ";") THEN
		j := 0; INC(i);
		WHILE (t[i] # 0X) DO genfs[j] := t[i]; INC(j); INC(i) END;
		genfs[j] := 0X
	END
END ExpandAlias;

PROCEDURE GetFileSystemFactory(CONST name : ARRAY OF CHAR; error : Streams.Writer) : Files.FileSystemFactory;
VAR
	factory : Files.FileSystemFactory;
	moduleName, procedureName : Modules.Name; msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	factory := NIL;
	Commands.Split(name, moduleName, procedureName, res, msg);
	IF (res = Commands.Ok) THEN
		GETPROCEDURE(moduleName, procedureName, factory);
		IF factory = NIL THEN
			error.String('failed to get file system factory with name "'); error.String(name); error.String('"!'); error.Ln;
		END;
	ELSE
		error.String(msg); error.Ln;
	END;
	RETURN factory;
END GetFileSystemFactory;

PROCEDURE Mount*(context : Commands.Context); (** prefix alias [volpar] ["|" fspar] ~ *)
VAR
	factory : Files.FileSystemFactory;
	parvol, parfs: Files.Parameters; i, res: LONGINT;
	alias, genvol, genfs : ARRAY 64 OF CHAR; prefix: Files.Prefix;
BEGIN
	IF context.arg.GetString(prefix) & context.arg.GetString(alias) THEN
		ExpandAlias(alias, genvol, genfs);
		IF (Files.This(prefix) # NIL) THEN
			context.error.String(prefix); context.error.String("; already used"); context.error.Ln;
		ELSIF (genvol = "") OR (genfs = "") THEN
			context.error.String(prefix); context.error.String(": unknown alias "); context.error.String(alias); context.error.Ln;
		ELSE
			IF genvol # "NIL" THEN
				NEW(parvol, context.in, context.arg, context.out, context.error, context.caller);
				parvol.vol := NIL; res := 0;
				COPY(prefix, parvol.prefix);
				factory := GetFileSystemFactory(genvol, context.error);
				IF (factory # NIL) THEN
					factory(parvol);
				END;
				IF (factory = NIL) OR (parvol.vol = NIL) THEN res := 1; END;
			ELSE
				i := 0
			END;
			IF (res = Commands.Ok) THEN
				NEW(parfs, context.in, context.arg, context.out, context.error, context.caller);
				IF (parvol # NIL) THEN parfs.vol := parvol.vol; ELSE parfs.vol := NIL; END;
				COPY(prefix, parfs.prefix);
				factory := GetFileSystemFactory(genfs, context.error);
				IF (factory # NIL) THEN
					factory(parfs);
					IF (Files.This(prefix) = NIL) THEN
						res := 1
					ELSE
						context.out.String(prefix); context.out.String(": mounted"); context.out.Ln;
					END;
				ELSE
					res := 1;
				END;

				IF (res # 0) & (parvol # NIL) & (parvol.vol # NIL) THEN
					parvol.vol.Finalize()	(* unmount volume *)
				END
			ELSE
				(* skip *)
			END
		END;
	ELSE
		context.error.String('Expected parameters: prefix alias ([volpar] ["|" fspar]'); context.error.Ln;
	END;
END Mount;

PROCEDURE Unmount*(context : Commands.Context); (** prefix[\f] *)
VAR prefix: Files.Prefix; fs: Files.FileSystem; i: LONGINT; force: BOOLEAN; option : ARRAY 8 OF CHAR; ch : CHAR;
BEGIN
	context.arg.SkipWhitespace;
	i := 0; ch := context.arg.Peek();
	WHILE (i < LEN(prefix)-1) & (ch # ":") & (ch # "\") & (ch > " ") & (context.arg.res = Streams.Ok) DO
		context.arg.Char(ch); (* consume ch *)
		prefix[i] := ch;
		INC(i);
		ch := context.arg.Peek();
	END;
	prefix[i] := 0X;

	IF (ch = ":") THEN context.arg.Char(ch); (* consume ":" *) END;

	context.arg.SkipWhitespace; context.arg.String(option);
	force := option = "\F";
	fs := Files.This(prefix);
	IF fs # NIL THEN
		IF (fs.vol = NIL) OR force OR ~(Files.Boot IN fs.vol.flags) THEN
			Files.Remove(fs);
			context.out.String(prefix); context.out.Char(":");
			context.out.String(" unmounted"); context.out.Ln;
		ELSE
			context.error.String(prefix); context.error.Char(":");
			context.error.String(" can't unmount boot volume. Use \f parameter to force unmounting."); context.error.Ln;
		END
	ELSE
		context.error.String(prefix); context.error.Char(":"); context.error.String(" not found"); context.error.Ln;
	END
END Unmount;

PROCEDURE SetDefault*(context : Commands.Context); (** prefix *)
VAR prefix: Files.Prefix; fs: Files.FileSystem; i: LONGINT; ft: Files.FileSystemTable;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(prefix);
	fs := Files.This(prefix);
	IF fs # NIL THEN
		Files.Promote(fs);
		Files.GetList(ft);
		IF ft # NIL THEN
			context.out.String("Path: ");
			FOR i := 0 TO LEN(ft)-1 DO
				context.out.String(ft[i].prefix);  context.out.String(" "); context.out.Ln;
			END
		END
	ELSE
		context.error.String(prefix);  context.error.String(": not found"); context.error.Ln;
	END;
END SetDefault;

(* using the NIST standard for Kibi, Mebi & Gibi: http://physics.nist.gov/cuu/Units/binary.html *)
PROCEDURE WriteK( k: LONGINT; out : Streams.Writer);
VAR suffix: ARRAY 3 OF CHAR;
BEGIN
	IF k < 10*1024 THEN COPY("Ki", suffix)
	ELSIF k < 10*1024*1024 THEN COPY("Mi", suffix); k := k DIV 1024
	ELSE COPY("Gi", suffix); k := k DIV (1024*1024)
	END;
	out.Int(k, 1); out.String(suffix); out.String("B");
END WriteK;

PROCEDURE Watch*(context : Commands.Context); (** ~ *)
VAR prefix : Files.Prefix; free, total, i: LONGINT; fs: Files.FileSystem; ft: Files.FileSystemTable; found : BOOLEAN;
BEGIN
	prefix := "";
	context.arg.SkipWhitespace; context.arg.String(prefix);
	found := FALSE;
	Files.GetList(ft);
	IF ft # NIL THEN
		FOR i := 0 TO LEN(ft)-1 DO
			fs := ft[i];
			IF (prefix = "") OR (prefix = fs.prefix) THEN
				found := TRUE;
				context.out.String(fs.prefix);  context.out.String(": "); context.out.String(fs.desc);
				IF fs.vol # NIL THEN
					context.out.String(" on "); context.out.String(fs.vol.name);
					IF Files.ReadOnly IN fs.vol.flags THEN context.out.String(" (read-only)") END;
					IF Files.Removable IN fs.vol.flags THEN context.out.String(" (removable)") END;
					IF Files.Boot IN fs.vol.flags THEN context.out.String(" (boot)") END;
					context.out.Ln; context.out.String("   ");
					free := ENTIER(fs.vol.Available()/1024.0D0 * fs.vol.blockSize);
					total := ENTIER(fs.vol.size/1024.0D0 * fs.vol.blockSize);
					WriteK(free, context.out); context.out.String(" of ");
					WriteK(total, context.out); context.out.String(" free")
				END;
				context.out.Ln
			END;
		END;
	END;
	IF ~found THEN
		IF (prefix = "") THEN
			context.out.String("No file systems found."); context.out.Ln;
		ELSE
			context.out.String("File system "); context.out.String(prefix); context.out.String(" not found.");
			context.out.Ln;
		END;
	END;
END Watch;

(** File operations *)

(* Simple text formatting (assuming the use of fixed fonts) *)
PROCEDURE Align(out : Streams.Writer; CONST string : ARRAY OF CHAR);
VAR spaces, i : LONGINT;
BEGIN
	spaces := Column1 - Strings.Length(string); IF spaces < 0 THEN spaces := 0; END;
	FOR i := 0 TO spaces-1 DO out.Char(" "); END;
END Align;

PROCEDURE Directory*(context : Commands.Context); (** [Options] [pattern] *)
VAR
	options : Options.Options;
	string, pattern : ARRAY 256 OF CHAR;
	enum : Files.Enumerator;
	flags, fileflags : SET;
	count, total : LONGINT;
	time, date, size : LONGINT;
	name : ARRAY MaxNameLen OF CHAR;
	dt : Dates.DateTime;
BEGIN
	NEW(options);
	options.Add("s", "size", Options.Flag);
	options.Add("t", "time", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		flags := {};
		IF options.GetFlag("time") THEN INCL(flags, Files.EnumSize); END;
		IF options.GetFlag("size") THEN INCL(flags, Files.EnumTime); END;

		IF ~context.arg.GetString(pattern) THEN
			pattern := "";
		END;
		NEW(enum); enum.Open(pattern, flags);
		count := 0; total := 0;
		WHILE enum.GetEntry(name, fileflags, time, date, size) DO
			INC(count);
			context.out.String(name);

			IF Files.EnumSize IN flags THEN
				Align(context.out, name);  context.out.Int(size, 10); context.out.Char("B");
				INC(total, size)
			END;

			IF Files.EnumTime IN flags THEN
				IF Files.EnumSize IN flags THEN context.out.String("    "); ELSE Align(context.out, name); END;
				dt := Dates.OberonToDateTime(date, time);
				Strings.FormatDateTime(FormatDateTime, dt, string);
				context.out.String(string);
			END;
			context.out.Ln;
		END;
		enum.Close;
		IF count > 1 THEN
			context.out.Int(count, 0); context.out.String(" files ");
			IF Files.EnumSize IN flags THEN
				context.out.String("use "); WriteK((total+1023) DIV 1024, context.out);
			END
		END;
		context.out.Ln;
	END;
END Directory;

PROCEDURE EnumerateDirectory(
	enum : Files.Enumerator;
	enumProc : EnumProc;
	options : Options.Options;
	context : Commands.Context;
	CONST filemask : ARRAY OF CHAR;
	CONST arguments : ARRAY OF CHAR);
VAR
	name : Files.FileName;
	flags : SET; time, date, size : LONGINT;
	subDirEnum : Files.Enumerator;

	PROCEDURE PrepareContext(context : Commands.Context; CONST currentFile, arguments : ARRAY OF CHAR);
	CONST PlaceHolder = "<#filename#>";
	VAR thisArguments : Strings.String; position : LONGINT;
	BEGIN
		NEW(thisArguments, Strings.Length(arguments) + 1024);
		COPY(arguments, thisArguments^);
		(* replace PlaceHolder string  by current file's name *)
		position := Strings.Pos(PlaceHolder, arguments);
		WHILE (position >= 0) DO
			Strings.Delete(thisArguments^, position, Strings.Length(PlaceHolder));
			Strings.Insert(name, thisArguments^, position);
			position := Strings.Pos(PlaceHolder, thisArguments^);
		END;
		context.arg(Streams.StringReader).InitStringReader(Strings.Length(thisArguments^));
		context.arg(Streams.StringReader).Set(thisArguments^);
	END PrepareContext;

BEGIN
	ASSERT((enum # NIL) & (enumProc # NIL) & (options # NIL) & (context # NIL));
	WHILE enum.GetEntry(name, flags, time, date, size) DO
		IF ~(Files.Directory IN flags) & Strings.Match(filemask, name) THEN
			PrepareContext(context, name, arguments);
			enumProc(context);
			context.out.Update;
			context.error.Update;
		ELSIF options.GetFlag("subdirectories") THEN
			IF options.GetFlag("directories") THEN
				Strings.Append(name, Files.PathDelimiter);
				PrepareContext(context, name, arguments);
				enumProc(context);
				Strings.Append(name, filemask);
			END;
			NEW(subDirEnum);
			subDirEnum.Open(name, {});
			EnumerateDirectory(subDirEnum, enumProc, options, context, filemask, arguments);
			subDirEnum.Close;
		END;
	END;
	enum.Close;
END EnumerateDirectory;

PROCEDURE Enumerate*(context : Commands.Context); (** [Options] pattern commandProc ~ *)
VAR
	options : Options.Options;
	pattern, path,  filemask : Files.FileName;
	commandProcStr, msg : ARRAY 128 OF CHAR;
	arguments : Strings.String;
	enumProc : EnumProc;
	moduleName, procedureName : Modules.Name;
	enum : Files.Enumerator;
	enumContext : Commands.Context;
	arg : Streams.StringReader;
	res : LONGINT;
BEGIN
	NEW(options);
	options.Add("s", "subdirectories", Options.Flag);
	options.Add("d", "directories", Options.Flag);
	IF options.Parse(context.arg, context.out) THEN
		IF context.arg.GetString(pattern) & context.arg.GetString(commandProcStr) THEN
			Commands.Split(commandProcStr, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, enumProc);
				IF (enumProc # NIL) THEN
					Files.SplitPath(pattern, path, filemask);
					NEW(enum);
					enum.Open(path, {});
					NEW(arg, 4096);
					NEW(arguments, context.arg.Available()); Strings.Truncate(arguments^, 0);
					context.arg.Bytes(arguments^, 0, context.arg.Available(), res); (* ignore res *)
					NEW(enumContext, context.in, arg, context.out, context.error, context.caller);

					EnumerateDirectory(enum, enumProc, options, enumContext, filemask, arguments^);
					enum.Close;
				ELSE
					context.out.String("Procedure "); context.out.String(commandProcStr); context.out.String(" not found");
					context.out.Ln;
				END;
			ELSE
				context.out.String("Command procedure error, res: "); context.out.Int(res, 0);
				context.out.String(" ("); context.out.String(msg); context.out.String(")");
				context.out.Ln;
			END;
		ELSE
			context.out.String("FSTools.Enumerate [Options] pattern ~"); context.out.Ln;
		END;
	END;
END Enumerate;

(** Create a new file and optionally fill it with content
	Option c: Transform <LF> into <CR><LF>
	Option r: Remove whitespace at beginning of line
	Option a: Append to file instead of creating new file
*)
PROCEDURE CreateFile*(context : Commands.Context); (** [Options] filename [content] ~ *)
VAR
	options : Options.Options; cr, removeWhitespace : BOOLEAN;
	file : Files.File; filename : Files.FileName; writer : Files.Writer; ch : CHAR; pos: LONGINT;
BEGIN
	NEW(options);
	options.Add("c", "cr", Options.Flag);
	options.Add("r", "remove", Options.Flag);
	options.Add("a", "append", Options.Flag);
	IF options.Parse(context.arg, context.out) THEN
		IF context.arg.GetString(filename) THEN
			cr := options.GetFlag("cr");
			removeWhitespace := options.GetFlag("remove");
			file := NIL;
			IF options.GetFlag("append") THEN
				file := Files.Old(filename);
			END;
			IF file = NIL THEN
				file := Files.New(filename);
				pos := 0;
			ELSE
				pos := file.Length();
			END;
			Files.OpenWriter(writer, file, pos);
			IF removeWhitespace THEN context.arg.SkipWhitespace; END;
			WHILE (context.arg.res = Streams.Ok) DO
				ch := context.arg.Get();
				IF (ch = LF) THEN
					IF cr THEN writer.Char(CR); END;
					IF removeWhitespace THEN context.arg.SkipWhitespace; END;
				END;
				IF ch # 0X THEN
					writer.Char(ch);
				END;
			END;
			writer.Update;
			Files.Register(file);
			context.out.String("Created file "); context.out.String(filename); context.out.Ln;
		ELSE
			context.out.String("FSTools.CreateFile filename [content] ~"); context.out.Ln;
		END;
	END;
END CreateFile;

PROCEDURE CopyTo*(context : Commands.Context); (** targetpath sourcepath {filename} ~ *)
VAR targetPath, sourcePath, targetFullname, sourceFullname,  filename : Files.FileName; overwrite : BOOLEAN; nofFilesCopied, nofErrors,  res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(targetPath);
	context.arg.SkipWhitespace; context.arg.String(sourcePath);

	nofFilesCopied := 0; nofErrors := 0;
	WHILE context.arg.GetString(filename) DO
		COPY(targetPath, targetFullname); Strings.Append(targetFullname, filename);
		COPY(sourcePath, sourceFullname); Strings.Append(sourceFullname, filename);
		overwrite := TRUE;
		Files.CopyFile(sourceFullname, targetFullname, overwrite, res);
		IF (res = Files.Ok) THEN
			INC(nofFilesCopied);
		ELSE
			INC(nofErrors);
			context.error.String("Error: Could not copy file "); context.error.String(sourceFullname);
			context.error.String(" to "); context.error.String(targetFullname); context.error.String(", res: ");
			context.error.Int(res, 0); context.error.Ln;
			RETURN;
		END;
	END;
	context.out.Int(nofFilesCopied, 0); context.out.String(" files copied");
	IF (nofErrors > 0) THEN
		context.out.String(" ("); context.out.Int(nofErrors, 0); context.out.String(" errors)");
	END;
	context.out.Ln;
END CopyTo;

(** Copy files *)
PROCEDURE CopyFiles*(context : Commands.Context); (** [Options] {source  => destination} ~ *)
VAR
	source, destination : FileList;
	overwritten, error, ignoreErrors, quiet : BOOLEAN;
	nofFiles, res, n : LONGINT;
	options: Options.Options;
BEGIN
	NEW(options);
	options.Add("o", "overwrite", Options.Flag); (* overwrite target file if it exists *)
	options.Add("i", "ignore", Options.Flag); (* continue on errors *)
	options.Add("n", "nolist", Options.Flag); (* only allow two arguments *)
	options.Add("q", "quiet", Options.Flag); (* do not print copied file names *)
	IF options.Parse(context.arg, context.error) THEN
		ignoreErrors := options.GetFlag("ignore");
		IF options.GetFlag("nolist") THEN (* source target *)
			nofFiles := GetSimpleFileLists(context, source, destination);
		ELSE (* {source => target} *)
			nofFiles := GetFileLists(context, source, destination);
		END;
		IF nofFiles # Error THEN
			quiet := options.GetFlag("quiet");
			IF ~quiet THEN context.out.String("Copying files..."); context.out.Ln; context.out.Update END;
			n := 0;
			WHILE(n < LEN(source)) & (source[n] # NIL) & (n < LEN(destination)) & (destination[n] # NIL) & (ignoreErrors OR ~error) DO
				IF ~quiet THEN
					context.out.String("   Copy "); context.out.String(source[n]^); context.out.String(" => ");
					context.out.String(destination[n]^); context.out.String(" ... ");
					context.out.Update;
				END;
				overwritten := options.GetFlag("overwrite");
				Files.CopyFile(source[n]^, destination[n]^, overwritten, res);
				IF res = Files.Ok THEN
					IF ~quiet THEN
						context.out.String("done");
						IF overwritten THEN context.out.String(" (overwritten)"); END;
						context.out.Char("."); context.out.Ln;
						context.out.Update;
					END;
					INC(n);
				ELSE
					IF quiet THEN
						context.out.String("   Copy "); context.out.String(source[n]^); context.out.String(" => ");
						context.out.String(destination[n]^);
					END;
					context.error.String("failed "); ShowRes(context.error, res); context.error.Ln;
					context.error.Update;
					error := TRUE;
				END;
			END;
		END;
		IF nofFiles # Error THEN
			context.out.Int(n, 0); context.out.String(" of "); context.out.Int(nofFiles, 0);  context.out.String(" files copied."); context.out.Ln;
		ELSE
			context.out.String("No files copied."); context.out.Ln;
		END;
	END;
END CopyFiles;

PROCEDURE GenerateName(CONST prefix: ARRAY OF CHAR; index: LONGINT; VAR str: ARRAY OF CHAR);
VAR startTime: Dates.DateTime; num: ARRAY 32 OF CHAR;
BEGIN
	startTime := Dates.Now();
	Strings.FormatDateTime("_yyyymmdd__hhnnss",startTime,str);
	Strings.Concat(prefix,str,str);
	IF index # 0 THEN
		Strings.IntToStr(index,num);
		Strings.Append(str,"_");
		Strings.Concat(str,num,str);
	END;
	Strings.Concat(str,".bak",str);
END GenerateName;

PROCEDURE Backup*(context: Commands.Context);
VAR index: LONGINT; fileList: FileList; nofFiles, n, res: LONGINT; str: Files.FileName; overwritten: BOOLEAN;
BEGIN
	overwritten := FALSE;
	nofFiles := GetFileList(context, fileList);
	n := 0;
	WHILE (fileList[n] # NIL) DO
		index := -1;
		REPEAT
			INC(index);
			GenerateName(fileList[n]^, index, str);
		UNTIL Files.Old(str) = NIL;
		Files.CopyFile(fileList[n]^, str, overwritten, res);
		context.out.String("backed up "); context.out.String(fileList[n]^); context.out.String(" in "); context.out.String(str); context.out.Ln;
		ASSERT(~overwritten);
		INC(n);
	END;
END Backup;

(** Delete files *)
PROCEDURE DeleteFiles*(context : Commands.Context); (** [Options] {file} ~ *)
VAR
	filelist : FileList;
	error, ignoreErrors, silent : BOOLEAN;
	nofFiles, res, n, ndone : LONGINT;
	options : Options.Options;
BEGIN
	NEW(options);
	options.Add("i", "ignore", Options.Flag);
	options.Add("s", "silent", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		ignoreErrors := options.GetFlag("ignore");
		silent := options.GetFlag("silent");
		nofFiles := GetFileList(context, filelist);
		IF (nofFiles > 0) THEN
			context.out.String("Deleting files..."); context.out.Ln;
			n := 0; ndone := 0;
			WHILE(filelist[n] # NIL) & (ignoreErrors OR ~error) DO
				res := 0;
				IF ~silent THEN context.out.String("   Delete "); context.out.String(filelist[n]^); context.out.String(" ... "); context.out.Update; END;
				Files.Delete(filelist[n]^, res);
				IF res = Files.Ok THEN
					IF ~silent THEN context.out.String("done."); context.out.Ln; END;
					INC(ndone);
				ELSE
					IF silent THEN
						 context.out.String("   Delete "); context.out.String(filelist[n]^); context.out.String(" ... "); context.out.Update;
					END;
					context.out.String("failed "); ShowRes(context.out, res); context.out.Ln;
					error := TRUE;
				END;
				INC(n);
				context.out.Update;
			END;
			context.out.Int(ndone, 0); context.out.String(" of "); context.out.Int(nofFiles, 0); context.out.String(" files deleted."); context.out.Ln;
		ELSIF (nofFiles = 0) THEN
			context.out.String("No files matching the mask found."); context.out.Ln;
		ELSE
			context.error.String("Syntax Error: No files deleted"); context.error.Ln;
		END;
	END;
END DeleteFiles;

(** Rename files. *)
PROCEDURE RenameFiles*(context : Commands.Context); (** [Options] {source => destination} ~ *)
VAR
	source, target : FileList;
	error, ignoreErrors : BOOLEAN;
	nofFiles, res, n : LONGINT;
	options : Options.Options;
BEGIN
	NEW(options);
	options.Add("i", "ignore", Options.Flag); (* continue on errors *)
	options.Add("n", "nolist", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		ignoreErrors := options.GetFlag("ignore");
		IF options.GetFlag("nolist") THEN
			nofFiles := GetSimpleFileLists(context, source, target);
		ELSE
			nofFiles := GetFileLists(context, source, target);
		END;
		IF nofFiles # Error THEN
			context.out.String("Renaming files..."); context.out.Ln;
			n := 0;
			WHILE(source[n] # NIL) & (target[n] # NIL) & (ignoreErrors OR ~error) DO
				res := 0;
				context.out.String("   Rename "); context.out.String(source[n]^); context.out.String(" => "); context.out.String(target[n]^); context.out.String(" ... ");
				Files.Rename(source[n]^, target[n]^, res);
				IF res # Files.Ok THEN
					context.error.String("failed "); ShowRes(context.error, res); context.error.Ln;
					error := TRUE;
				ELSE
					context.out.String("done."); context.out.Ln;
					INC(n);
				END;
			END;
		END;
		IF nofFiles # Error THEN
			context.out.Int(n, 0); context.out.String(" of "); context.out.Int(nofFiles, 0); context.out.String(" files renamed."); context.out.Ln;
		ELSE
			context.out.String("No files renamed."); context.out.Ln;
		END;
	END;
END RenameFiles;

PROCEDURE CreateDirectory*(context : Commands.Context); (* path ~ *)
VAR path : Files.FileName; res : LONGINT;
BEGIN
	IF context.arg.GetString(path) THEN
		Files.CreateDirectory(path, res);
		IF (res # Files.Ok) THEN
			context.out.String("Could not create directory '"); context.out.String(path); context.out.String("', res: ");
			ShowRes(context.out, res); context.out.Ln;
		END;
	ELSE
		context.out.String("Usage: FSTools.CreateDirectory <path> ~"); context.out.Ln;
	END;
END CreateDirectory;

PROCEDURE DeleteDirectory*(context : Commands.Context); (* path ~ *)
VAR path : Files.FileName; res : LONGINT;
BEGIN
	IF context.arg.GetString(path) THEN
		Files.RemoveDirectory(path, FALSE, res);
		IF (res # Files.Ok) THEN
			context.out.String("Could not delete directory '"); context.out.String(path); context.out.String("', res: ");
			ShowRes(context.out, res); context.out.Ln;
		END;
	ELSE
		context.out.String("Usage: FSTools.DeleteDirectory <path> ~"); context.out.Ln;
	END;
END DeleteDirectory;

(** Compare filenames of two directories and display files that are not present in both directories *)
PROCEDURE CompareDirectories*(context : Commands.Context); (** directory1 directory2 ~ *)
VAR
	fileList1, fileList2 : FileList;
	length1, length2 : LONGINT;
	dirname1, dirname2 : Files.FileName;
	index1, index2 : LONGINT;
	differences : LONGINT;

	PROCEDURE GetSortedFileList(CONST dirname : ARRAY OF CHAR; VAR index : LONGINT) : FileList;
	VAR mask : Files.FileName; fileList : FileList;
	BEGIN
		COPY(dirname, mask);
		Strings.Append(mask, Files.PathDelimiter);
		Strings.Append(mask, "*");
		NEW(fileList, 128);
		InsertFiles(mask, fileList, index);
		IF (index > 0) THEN SortFileList(fileList, index); END;
		ASSERT(fileList # NIL);
		RETURN fileList;
	END GetSortedFileList;

	PROCEDURE CompareEntries(CONST entry1, entry2 : ARRAY OF CHAR) : LONGINT;
	VAR result : LONGINT; prefix : Files.Prefix; filename1, filename2, pathname, path : Files.FileName;
	BEGIN
		Files.SplitName(entry1, prefix, pathname);
		Files.SplitPath(pathname, path, filename1);
		Files.SplitName(entry2, prefix, pathname);
		Files.SplitPath(pathname, path, filename2);
		IF (filename1 < filename2) THEN result := -1;
		ELSIF (filename1 > filename2) THEN result := 1;
		ELSE result := 0;
		END;
		RETURN result;
	END CompareEntries;

BEGIN
	context.arg.SkipWhitespace; context.arg.String(dirname1);
	context.arg.SkipWhitespace; context.arg.String(dirname2);
	differences := 0;
	length1 := 0;
	fileList1 := GetSortedFileList(dirname1, length1);
	length2 := 0;
	fileList2 := GetSortedFileList(dirname2, length2);
	context.out.String(dirname1); context.out.String(": "); context.out.Int(length1, 0); context.out.String(" entries"); context.out.Ln;
	context.out.String(dirname2); context.out.String(": "); context.out.Int(length2, 0); context.out.String(" entries"); context.out.Ln;
	index1 := 0; index2 := 0;
	WHILE (index1 < length1) DO
		WHILE (index2 < length2) & (CompareEntries(fileList1[index1]^, fileList2[index2]^) > 0) DO
			context.out.String(fileList2[index2]^); context.out.Ln;
			INC(differences);
			INC(index2);
		END;
		IF (index2 < length2) & (CompareEntries(fileList1[index1]^, fileList2[index2]^) = 0)THEN
			INC(index2);
		ELSE
			INC(differences);
			context.out.String(fileList1[index1]^); context.out.Ln;
		END;
		INC(index1);
	END;
	WHILE (index2 < length2) DO
		context.out.String(fileList2[index2]^); context.out.Ln;
		INC(differences);
		INC(index2);
	END;
	IF (differences = 0) THEN
		context.out.String("Directories contain the same entries"); context.out.Ln;
	END;
END CompareDirectories;

(** Compare two files by byte-wise comparison of contents *)
PROCEDURE CompareFiles*(context : Commands.Context); (* filename1 filename2 ~ *)
VAR filename : Files.FileName; file1, file2 : Files.File; reader1, reader2 : Files.Reader; ch1, ch2 : CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	file1 := Files.Old(filename);
	IF (file1# NIL) THEN
		context.arg.SkipWhitespace; context.arg.String(filename);
		file2 := Files.Old(filename);
		IF (file2 # NIL) THEN
			IF (file1.Length() = file2.Length()) THEN
				NEW(reader1, file1, 0);
				NEW(reader2, file2, 0);
				REPEAT
					reader1.Char(ch1);
					reader2.Char(ch2);
				UNTIL (ch1 # ch2) OR (reader1.res # Files.Ok) OR (reader2.res # Files.Ok);

				IF (ch1 = ch2) & (reader1.res = reader2.res) & (reader1.res = Streams.EOF) THEN
					context.out.String("Files are equal"); context.out.Ln;
				ELSE
					context.out.String("Content mismatch"); context.out.Ln;
				END;
			ELSE
				context.out.String("Length mismatch"); context.out.Ln;
			END;
		ELSE
			context.error.String("File "); context.error.String(filename); context.error.String(" not found");
			context.error.Ln;
		END;
	ELSE
		context.error.String("File "); context.error.String(filename); context.error.String(" not found");
		context.error.Ln;
	END;
END CompareFiles;

PROCEDURE SortFileList(filelist : FileList; length : LONGINT );
VAR i, j : LONGINT; temp : Strings.String;
BEGIN
	(* bubble sort *)
	FOR i := 0 TO length-1 DO
		FOR j := 0 TO length-2 DO
			IF filelist[j]^ > filelist[j+1]^ THEN
				temp := filelist[j+1];
				filelist[j+1] := filelist[j];
				filelist[j] := temp;
			END;
		END;
	END;
END SortFileList;

PROCEDURE ResizeFilelist(VAR filelist : FileList);
VAR temp : FileList; i : LONGINT;
BEGIN
	NEW(temp, 2 * LEN(filelist));
	FOR i := 0 TO LEN(filelist)-1 DO
		temp[i] := filelist[i];
	END;
	filelist := temp;
END ResizeFilelist;

(* Checks whether a file list entry contains mask characters and adds the corresponding files if it does *)
PROCEDURE InsertFiles(CONST mask : ARRAY OF CHAR; VAR filelist : FileList; VAR index : LONGINT);
VAR
	enum : Files.Enumerator;
	fileflags : SET;
	time, date, size : LONGINT;
	name : ARRAY MaxNameLen OF CHAR;
BEGIN
	NEW(enum); enum.Open(mask, {});
	WHILE enum.GetEntry(name, fileflags, time, date, size) DO
		IF (fileflags * {Files.Directory} = {}) THEN
			IF index >= LEN(filelist) THEN ResizeFilelist(filelist); END;
			filelist[index] := Strings.NewString(name);
			INC(index);
		END;
	END;
	enum.Close;
END InsertFiles;

(* Count the number of occurences of the character 'ch' in the string 'string'. Case-Sensitive! *)
PROCEDURE CountCharacters(CONST string : ARRAY OF CHAR; ch : CHAR) : LONGINT;
VAR count, i : LONGINT;
BEGIN
	count := 0;
	FOR i := 0 TO LEN(string)-1 DO
		IF string[i] = ch THEN INC(count); END;
	END;
	RETURN count;
END CountCharacters;

(* Split full name into prefix, path, filename and file extension *)
PROCEDURE SplitFullName(CONST fullname : ARRAY OF CHAR; VAR prefix, path, filename, extension : ARRAY OF CHAR);
VAR pathname, name : ARRAY 1024 OF CHAR;
BEGIN
	Files.SplitName(fullname, prefix, pathname);
	Files.SplitPath(pathname, path, name);
	Files.SplitExtension(name, filename, extension);
END SplitFullName;

PROCEDURE IsValidTargetMask(context : Commands.Context; CONST mask : ARRAY OF CHAR) : BOOLEAN;
VAR
	prefix : ARRAY Files.PrefixLength OF CHAR;
	filename, extension : ARRAY Files.NameLength OF CHAR;
	path : ARRAY 512 OF CHAR;
BEGIN
	SplitFullName(mask, prefix, path, filename, extension);

	IF (CountCharacters(mask, "?") > 0) THEN
		context.error.String("Syntax Error in "); context.error.String(mask); context.error.String(": '?' matching characters not implemented for target mask"); context.error.Ln;
		RETURN FALSE;
	END;

	IF (CountCharacters(prefix, "*") # 0) OR (CountCharacters(path, "*") # 0) THEN
		context.error.String("Syntax Error in "); context.error.String(mask); context.error.String(": Target prefix/path may not contain '*' characters"); context.error.Ln;
		RETURN FALSE;
	END;

	RETURN TRUE;
END IsValidTargetMask;

(* If the user does not specify a prefix or path for a mask, the mask will include all directories and subdirectories.
	Since this is too dangerous for file operations as delete, we only allow pattern operations if a prefix
	or path is specified within the pattern or the unsafe mode is set *)
PROCEDURE AllowMaskInSafeMode(CONST mask : ARRAY OF CHAR) : BOOLEAN;
VAR prefix : Files.Prefix; pathname, path, filename : Files.FileName;
BEGIN
	Files.SplitName(mask, prefix, pathname);
	Files.SplitPath(pathname, path, filename);
	RETURN (prefix # "") OR ((path # "") & (path # Files.PathDelimiter));
END AllowMaskInSafeMode;

PROCEDURE GetTargetName(CONST sourceMask, targetMask, sourceName : ARRAY OF CHAR) : String;
VAR
	targetName : ARRAY 1024 OF CHAR;
	srcPrefix, srcPath, srcFilename, srcExtension : ARRAY 512 OF CHAR;
	isExtension : BOOLEAN;
	i, j, index : LONGINT;
BEGIN
	SplitFullName(sourceName, srcPrefix, srcPath, srcFilename, srcExtension);
	index := 0;
	FOR i := 0 TO LEN(targetMask)-1 DO
		IF targetMask[i] = "." THEN
			isExtension := TRUE;
			targetName[index] := targetMask[i];
			INC(index);
		ELSIF targetMask[i] = "*" THEN
			IF isExtension THEN
				j := 0; WHILE (j < LEN(srcExtension)) & (srcExtension[j] # 0X) DO targetName[index] := srcExtension[j]; INC(index); INC(j); END;
			ELSE
				j := 0; WHILE (j < LEN(srcFilename)) & (srcFilename[j] # 0X) DO targetName[index] := srcFilename[j]; INC(index); INC(j); END;
			END;
		ELSE
			targetName[index] := targetMask[i];
			INC(index);
		END;
	END;
	IF index < LEN(targetName) THEN targetName[index] := 0X; END;
	RETURN Strings.NewString(targetName);
END GetTargetName;

PROCEDURE InsertFilesAndFixDestination(context : Commands.Context; CONST sourceMask, targetMask : ARRAY OF CHAR; VAR source, target : FileList; VAR index : LONGINT) : BOOLEAN;
VAR
	enum : Files.Enumerator;
	fileflags : SET;
	time, date, size : LONGINT;
	name : ARRAY MaxNameLen OF CHAR;
BEGIN
	IF ~IsValidTargetMask(context, targetMask) THEN RETURN FALSE; END;
	NEW(enum); enum.Open(sourceMask, {});
	WHILE enum.GetEntry(name, fileflags, time, date, size) DO
		IF (fileflags * {Files.Directory} = {}) THEN
			IF index >= LEN(source) THEN ResizeFilelist(source); ResizeFilelist(target); END;
			source[index] := Strings.NewString(name);
			target[index] := GetTargetName(sourceMask, targetMask, name);
			INC(index);
		END;
	END;
	enum.Close;
	RETURN TRUE;
END InsertFilesAndFixDestination;

PROCEDURE IsMask(CONST string : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN Strings.ContainsChar(string, "*", FALSE) OR Strings.ContainsChar(string, "?", FALSE);
END IsMask;

PROCEDURE GetFileList(context : Commands.Context; VAR filelist : FileList) : LONGINT;
VAR filename : ARRAY MaxNameLen OF CHAR; done, error : BOOLEAN; count : LONGINT;
BEGIN
	NEW(filelist, InitialFilelistSize);
	WHILE ~done & ~error DO
		IF context.arg.GetString(filename) THEN
			IF IsMask(filename) THEN
				IF ~(AllowMaskInSafeMode(filename) OR unsafeMode) THEN
					ShowUnsafeMessage(context.out); RETURN 0;
				END;
				InsertFiles(filename, filelist, count);
			ELSE
				IF count >= LEN(filelist) THEN ResizeFilelist(filelist); END;
				filelist[count] := Strings.NewString(filename);
				INC(count);
			END;
		ELSIF context.arg.res = Streams.EOF THEN
			done := TRUE;
		ELSE
			context.error.String("Command parsing error (res: "); context.error.Int(context.arg.res, 0); context.error.String(")");
			error := TRUE;
		END;
	END;
	IF error THEN count := Error; END;
	RETURN count;
END GetFileList;

PROCEDURE GetSimpleFileLists(context : Commands.Context; VAR source, target : FileList) : LONGINT;
VAR sourceFilename, targetFilename : Files.FileName; count : LONGINT;
BEGIN
	IF context.arg.GetString(sourceFilename) & context.arg.GetString(targetFilename) THEN
		count := 1;
		IF IsMask(sourceFilename) OR IsMask(targetFilename) THEN
			IF ~(AllowMaskInSafeMode(sourceFilename) OR unsafeMode) THEN ShowUnsafeMessage(context.out); RETURN 0; END;
			IF ~InsertFilesAndFixDestination(context, sourceFilename, targetFilename, source, target, count) THEN END;
		ELSE
			NEW(source, 1); NEW(target, 1);
			source[0] := Strings.NewString(sourceFilename);
			target[0] := Strings.NewString(targetFilename);
		END;
	ELSE
		count := Error;
		context.error.String("Expected two filenames as arguments"); context.error.Ln;
	END;
	RETURN count;
END GetSimpleFileLists;

PROCEDURE GetFileLists(context : Commands.Context;  VAR source, target : FileList) : LONGINT;
VAR
	filename : ARRAY MaxNameLen OF CHAR; done, error : BOOLEAN; count : LONGINT;
	sourceString, targetString : String;
BEGIN
	NEW(source, InitialFilelistSize); NEW(target, InitialFilelistSize);
	WHILE ~done & ~error DO
		IF context.arg.GetString(filename) THEN
			sourceString := Strings.NewString(filename);
			IF context.arg.GetString(filename) & Strings.Match(filename, "=>") THEN
				IF context.arg.GetString(filename) THEN
					targetString := Strings.NewString(filename);
					IF IsMask(sourceString^) OR IsMask(targetString^) THEN
						IF ~(AllowMaskInSafeMode(sourceString^) OR unsafeMode) THEN ShowUnsafeMessage(context.out); RETURN 0; END;
						IF ~InsertFilesAndFixDestination(context, sourceString^, targetString^, source, target, count) THEN END;
					ELSE
						IF count >= LEN(source) THEN ResizeFilelist(source); ResizeFilelist(target); END;
						source[count] := sourceString;
						target[count] := targetString;
						INC(count);
					END;
				ELSE
					context.error.String("Command parsing error (res: "); context.error.Int(context.arg.res, 0); context.error.String(")");
					context.error.Ln;
					error := TRUE;
				END;
			ELSE
				context.error.String("Command parsing error: Exspected => token, found: "); context.error.String(filename);
				context.error.Ln;
				error := TRUE;
			END;
		ELSIF context.arg.res = Streams.EOF THEN
			done := TRUE;
		ELSE
			context.error.String("Command parsing error (res: "); context.error.Int(context.arg.res, 0); context.error.String(")");
			context.error.Ln;
			error := TRUE;
		END;
	END;
	IF error THEN count := Error; END;
	RETURN count;
END GetFileLists;

PROCEDURE Safe*(context : Commands.Context);
BEGIN
	unsafeMode := FALSE;
	context.out.String("FSTools: SAFE mode."); context.out.Ln;
END Safe;

PROCEDURE Unsafe*(context : Commands.Context);
BEGIN
	unsafeMode := TRUE;
	context.out.String("FSTools: UNSAFE mode now. BE CAREFUL!"); context.out.Ln;
END Unsafe;

PROCEDURE ShowUnsafeMessage(out : Streams.Writer);
BEGIN
	out.String("FSTools: Pattern matching is disabled in SAFE mode. Press FSTools.Unsafe ~ to enable pattern matching."); out.Ln;
END ShowUnsafeMessage;

PROCEDURE ShowRes(out : Streams.Writer; res : LONGINT);
BEGIN
	out.String("(");
	CASE res OF
		Files.VolumeReadOnly: out.String("Target volume is read-only");
		|Files.FsNotFound: out.String("File system not found");
		|Files.FileAlreadyExists: out.String("File already exists");
		|Files.BadFileName: out.String("Bad file name");
		|Files.FileNotFound: out.String("File not found");
	ELSE
		out.String("res: "); out.Int(res, 0);
	END;
	out.String(")");
END ShowRes;

(** Close files -- paradox: open (old) file and call Close method. Intended for systems in a host environment to explicitely release a file handle. *)
PROCEDURE CloseFiles*(context : Commands.Context); (** [Options] {file} ~ *)
VAR
	filelist : FileList;
	nofFiles, res, n, ndone : LONGINT;
	file: Files.File;
BEGIN
	nofFiles := GetFileList(context, filelist);
	n := 0; ndone := 0;
	WHILE (n<nofFiles) & (filelist[n] # NIL) DO
		file := Files.Old(filelist[n]^);
		IF file # NIL THEN file.Close END;
		INC(n);
	END;
END CloseFiles;

(* returns if a file or directory exists. If yes, then fullname is set to filename *)
PROCEDURE Exists*(CONST name: ARRAY OF CHAR; VAR fullName: ARRAY OF CHAR; VAR flags: SET): BOOLEAN;
VAR enum: Files.Enumerator; fname, suffix: Files.FileName; time, date, size: LONGINT;
BEGIN
	NEW(enum);
	enum.Open(name,{});
	IF enum.HasMoreEntries() & enum.GetEntry(fullName, flags, time, date, size) THEN RETURN TRUE ELSE RETURN FALSE END;
END Exists;

END FSTools.

SystemTools.Free FSTools ~

FSTools.DeleteFiles X:*.Bak ~

FSTools.SplitFile BootManager.Bin 0200H BootManagerMBR.Bin BootManagerTail.Bin ~

FSTools.Directory Test.Mod ~