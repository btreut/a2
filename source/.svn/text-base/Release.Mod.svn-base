
MODULE Release; (** AUTHOR "staubesv"; PURPOSE "Release build tool"; *)
(**
 *
 * Usage:
 *
 * 	Release.Analyze [Options] ~ analyzes the package description file
 *
 * 		Option f, file 		: Package description file to be analyzed [default: Release.Tool]
 *
 *	Release.CheckFiles [Options] filemask ~ lists all files that match to filemask but are not listed in the package description file
 *
 * 		Option f, file 		: Package description file to be analyzed [default: Release.Tool]
 *
 *	Release.Check  [Options] ~ builds all builds described in the package description file to a RAM disk
 *
 *		Option f, file		: Specify the package description file [default: Release.Tool]
 *
 *	Release.Build [Options] BuildName ~
 *
 *		Option b, build		: Compile the specified build (otherwise, open Notepad with compile command)
 *		Option c,compiler 	: Override compiler specified in the package description file
 *		Option exclude		: Exclude packages (specified as space separated list of package names)
 *		Option e, extension	: Override the extension option specified in the package description file
 *		Option f, file		: Specify the package description file [default: Release.Tool]
 *		Option n, nocheck	: Skip file existence and import order checks
 *		Option o, options	: Override the compiler options specified in the package description file
 *		Option p, path		: Override the path option specified in the package description file
 *		Option s, symbolFileExtension : Ovveride the symbolFileExtension option specified in the package description file
 *		Option t, target 	: Override the target option specified in the package description file
 *		Option v, verbose	: Show compiler output (only useful in combination with option --build)
 *		Option w, workers	: Number of worker threads for parallel compilation
 *		Option x, xml		: Generate XML package description file needed by WMInstaller.Mod
 *		Option z, zip		: Generate ZIP file for each package (for now, only together with --build option)
 *
 *		Argument BuildName:	Name of build to be built
 *
 *	Release.FindPosition [Options] BuildName FileName ~ finds the first position in the package description file
 *		where the specified file could be inserted (compile order)
 *
 *		Option f, file		: Specify the package description file [default: Release.Tool]
 *
 *
 *	SystemTools.Free Release ~
 *
 * Based on Release.Mod by pjm
 *
 *
 * BuildDescription =	Header Import BuildSection Packages
 * BuildSection = 		BUILDS {Build} END
 * Build = 				buildName OPENSECTION {BuildParameter} CLOSESECTION
 * Build = 				INCLUDE '"' [buildprefix {" " buildprefix} ] '"' |
 *						COMPILER '"' compileCommand '"' | COMPILEROPTIONS '"' compileOptions '"' |
 *						LINKER '"' linkCommand '"' | LINKEROPTIONS '"' linkOptions '"' |
 *						TARGET '"' target '"' |
 *						EXTENSION '"' objectFileExtension '"' | PATH '"' objectFilePath '"' |
 *						EXCLUDEPACKAGES '"' [ exludedPackage {" " excludedPackage} ] '"'
 *						DISABLED "TRUE" | "FALSE"
 *
 * Packages = { PackageSpec FileList }
 * PackageSpec = PACKAGE packageName ARCHIVE ArchiveName SOURCE SourceName ENDSECTION
 * FileList = { Filename | ReleaseSpec OPENSECTION [ {filename } ] CLOSESECTION }
 * ReleaseSpec = ReleaseName [ { SEPARATOR ReleaseName } ]
 *)

IMPORT
	Modules, Streams, Commands, Options, Files, Dates, Strings, Texts, TextUtilities, ReleaseThreadPool, Diagnostics, WMGraphics, Zip,
	CompilerInterface, Compiler, SyntaxTree := FoxSyntaxTree ;

CONST
	VersionMajor = 1;
	VersionMinor = 0;

	DefaultPackagesFile = "Release.Tool";

	(* Default build settings *)
	DefaultCompiler = "Compiler.Compile";
	DefaultCompileOptions = "";
	DefaultTarget = "" (* default chosen by compiler *);
	DefaultExtension = ""; (* default chosen by compiler *)
	DefaultSymbolFileExtension = ""; (* default chosen by compiler *)
	DefaultPath = "";
	DefaultDisabled = FALSE;

	(** If the prefix of a filename Prefix.Mid.Suffix matches <ReleasePrefix>, both Prefix.Mid.Suffix and Mid.Suffix will be
		included in the archive package. This is only valid for files that do not have the extension (Suffix) Mod *)
	ReleasePrefix = "Release";

	ToolFilename = "CompileCommand.Tool";
	InstallerPackageFile = "InstallerPackages.XML";

	DateTimeFormat = "wwww, mmmm d, yyyy  hh:nn:ss";

	NoFile = -1;
	NoPackages = -2;

	(* Load Oberon text files ignoring text format *)
	OptimizedLoads = TRUE;

	(* If set to TRUE, the file references are re-used for different steps of the build process *)
	KeepFilesOpen = FALSE;

	(* File.flags *)
	ImportsSystem = 0;
	SourceCode = 1;
	HasReleasePrefix = 2; (* filename has prefix <ReleasePrefix> *)

	(* Package.installMode *)
	Undefined = 0;
	Required = 1; (* package must be installed *)
	Yes = 2;	(* per default, install package *)
	No = 3; (* per default, don't install package *)

	(* File.release*)
	All = {0..31};

	MaxBuilds = 16;
	MaxPrefixes = 32;
	MaxNofImports = 64; (* Maximum number of entries in a module import section *)

	Tab = 9X;

	Mode_ShowImported = 0;
	Mode_ShowImporting = 1;

TYPE

	Name = ARRAY 72 OF CHAR;

TYPE

	Statistic = RECORD
		nofFiles : LONGINT;
		nofSources : LONGINT;
	END;


	Statistics = OBJECT
	VAR
		stats : ARRAY MaxPrefixes OF Statistic;

		(* Total number of files and sources *)
		nofFiles : LONGINT;
		nofSources : LONGINT;

		(* Number of files and sources that are contained in all releases *)
		nofFilesAll : LONGINT;
		nofSourcesAll : LONGINT;

		PROCEDURE Get(VAR nofFiles, nofSources : LONGINT; release : SET);
		VAR i : LONGINT;
		BEGIN
			nofFiles := 0; nofSources := 0;
			FOR i := 0 TO MaxPrefixes-1 DO
				IF i IN release THEN
					nofFiles := nofFiles + stats[i].nofFiles;
					nofSources := nofSources + stats[i].nofSources;
				END;
			END;
		END Get;

		PROCEDURE AddFile(file : File);
		VAR i : LONGINT;
		BEGIN
			INC(nofFiles);
			IF file.IsSourceCode() THEN INC(nofSources); END;
			IF (file.release # All) THEN
				FOR i := 0 TO MaxPrefixes-1 DO
					IF i IN file.release THEN
						INC(stats[i].nofFiles);
						IF file.IsSourceCode() THEN INC(stats[i].nofSources); END;
					END;
				END;
			ELSE
				INC(nofFilesAll);
				IF file.IsSourceCode() THEN INC(nofSourcesAll); END;
			END;
		END AddFile;

		PROCEDURE &Reset;
		VAR i : LONGINT;
		BEGIN
			nofFiles := 0;
			nofSources := 0;
			FOR i := 0 TO LEN(stats)-1 DO
				stats[i].nofFiles := 0;
				stats[i].nofSources := 0;
			END;
		END Reset;

	END Statistics;

TYPE

	(* The bitmap is used to analyze  dependencies between modules *)
	Bitmap = OBJECT
	VAR
		map : POINTER TO ARRAY OF SET;
		size : LONGINT;

		PROCEDURE IsSet(bit : LONGINT) : BOOLEAN;
		BEGIN
			ASSERT(( 0 <= bit) & (bit < size));
			RETURN (bit MOD SIZEOF(SET)) IN map[bit DIV SIZEOF(SET)];
		END IsSet;

		PROCEDURE Set(bit : LONGINT);
		BEGIN
			ASSERT((0 <= bit) & (bit  < size));
			INCL(map[bit DIV SIZEOF(SET)], bit MOD SIZEOF(SET));
		END Set;

		PROCEDURE NofBitsSet() : LONGINT;
		VAR nofBitsSet, index, subindex : LONGINT;
		BEGIN
			nofBitsSet := 0;
			FOR index := 0 TO LEN(map)-1 DO
				FOR subindex := 0 TO SIZEOF(SET)-1 DO
					IF subindex IN map[index] THEN INC(nofBitsSet); END;
				END;
			END;
			RETURN nofBitsSet;
		END NofBitsSet;

		PROCEDURE Union(bitmap : Bitmap);
		VAR i : LONGINT;
		BEGIN
			ASSERT((bitmap # NIL) & (bitmap.size = size));
			FOR i := 0 TO LEN(map)-1 DO
				map[i] := map[i] + bitmap.map[i];
			END;
		END Union;

		PROCEDURE &Init(size : LONGINT);
		VAR i : LONGINT;
		BEGIN
			ASSERT(size > 0);
			SELF.size := size;
			NEW(map, (size + SIZEOF(SET)-1) DIV SIZEOF(SET));
			FOR i := 0 TO LEN(map)-1 DO map[i] := {}; END;
		END Init;

	END Bitmap;

TYPE

	Package* = OBJECT
	VAR
		name-, archive-, source- : ARRAY 32 OF CHAR;
		description- : ARRAY 256 OF CHAR;
		installMode : LONGINT; (* Required, Yes, No *)

		nofFiles- : LONGINT;
		nofSources- : LONGINT;

		position- : LONGINT;

		next : Package;

		PROCEDURE &Init(CONST name, archive, source, description  : ARRAY OF CHAR; position : LONGINT);
		BEGIN
			COPY(name, SELF.name);
			COPY(archive, SELF.archive);
			COPY(source, SELF.source);
			COPY(description, SELF.description);
			SELF.position := position;
			installMode := Undefined;
			nofFiles := 0;
			nofSources := 0;
			position := -1;
			next := NIL;
		END Init;

	END Package;

TYPE

	PackageArray* = POINTER TO ARRAY OF Package;

	PackageList* = OBJECT
	VAR
		head, tail : Package;
		nofPackages : LONGINT;

		(* Find the package with the specified name. Returns NIL if package not found *)
		PROCEDURE FindPackage(CONST name : ARRAY OF CHAR) : Package;
		VAR package : Package;
		BEGIN
			package := head.next;
			WHILE (package # NIL) & (package.name # name) DO package := package.next; END;
			RETURN package;
		END FindPackage;

		(* Add package to list. Returns FALSE if a package in the list has the same name *)
		PROCEDURE Add(package : Package) : BOOLEAN;
		BEGIN
			ASSERT((package # NIL) & (package.next = NIL));
			IF FindPackage(package.name) = NIL THEN
				tail.next := package;
				tail := package;
				INC(nofPackages);
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Add;

		PROCEDURE GetAll*() : PackageArray;
		VAR packageArray : PackageArray; package : Package; i : LONGINT;
		BEGIN
			IF (nofPackages > 0) THEN
				NEW(packageArray, nofPackages);
				package := head.next;
				i := 0;
				WHILE (i < nofPackages) DO
					packageArray[i] := package;
					package := package.next;
					INC(i);
				END;
			ELSE
				packageArray := NIL;
			END;
			RETURN packageArray;

		END GetAll;

		PROCEDURE ToStream(out : Streams.Writer);
		VAR package : Package;  nofPackages : LONGINT;
		BEGIN
			ASSERT(out # NIL);
			out.String("Packages: "); out.Ln;
			nofPackages := 0;
			package := head.next;
			WHILE (package # NIL) DO
				out.String("   "); out.String(package.name); out.Int(package.nofFiles, 4);
				out.String(" Files ("); out.Int(package.nofSources, 4); out.String(" source code files)"); out.Ln;
				INC(nofPackages);
				package := package.next;
			END;
			out.String("   "); out.Int(nofPackages, 0); out.String(" packages"); out.Ln;
		END ToStream;

		PROCEDURE &Init;
		BEGIN
			NEW(head, "Head", "", "", "", -1);
			tail := head;
			nofPackages := 0;
		END Init;

	END PackageList;

TYPE

	ModuleInfo = RECORD
		name, context : Name;
		imports : ARRAY MaxNofImports OF Name; (* directly imported modules *)
		nofImports : LONGINT;
		flags : SET;
		isParsed : BOOLEAN;
	END;

TYPE

	File* = OBJECT
	VAR
		module : ModuleInfo; (* if source code *)

		name-, uppercaseName : Files.FileName;

		doCompile : BOOLEAN;

		(* When using array indexes instead of names *)
		index : LONGINT; (* position of this File object in array *)
		importIndices : ARRAY MaxNofImports OF LONGINT;

		(* number of modules that directly or indirectly import this module *)
		nofDependentModules : LONGINT;

		(* number of modules directly or indirectly imported by this module *)
		nofRequiredModules : LONGINT;

		(* job ID in case of using the thread pool for parallel compilation of modules *)
		jobID : LONGINT;

		package- : Package;
		options: ARRAY 8 OF CHAR;
		release- : SET;
		flags-: SET;
		file : Files.File;
		pos : LONGINT; (* Position in package description file *)

		builds : Builds;

		prev-, next- : File;

		PROCEDURE &Init(builds : Builds);
		VAR i : LONGINT;
		BEGIN
			ASSERT(builds # NIL);
			SELF.builds := builds;
			module.name := ""; module.context := "";
			FOR i := 0 TO LEN(module.imports)-1 DO module.imports[i] := ""; END;
			module.nofImports := 0;
			module.flags := {};
			module.isParsed := FALSE;
			COPY("", name);
			doCompile := TRUE;
			package := NIL;
			COPY("", options);
			release := {};
			flags := {};
			file := NIL;
			pos := 0;
			prev := NIL; next := NIL;
		END Init;

		PROCEDURE IsInRelease*(release : SET) : BOOLEAN;
		BEGIN
			RETURN (SELF.release = All) OR (SELF.release * release # {});
		END IsInRelease;

		PROCEDURE IsSourceCode*() : BOOLEAN;
		BEGIN
			RETURN SourceCode IN flags;
		END IsSourceCode;

		PROCEDURE CheckImports*(diagnostics : Diagnostics.Diagnostics; build : BuildObj; VAR error : BOOLEAN);
		VAR file : File; i : LONGINT; temp, message : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT((diagnostics # NIL) & (build # NIL));
			error := FALSE;
			FOR i := 0 TO module.nofImports-1 DO
				file := prev;
				LOOP
					IF (file = NIL) THEN EXIT; END;
					IF (file.module.name = module.imports[i]) & file.IsInRelease(build.include) & ~build.PackageIsExcluded(file.package) THEN (* found *) EXIT; END;
					file := file.prev;
				END;
				IF (file = NIL) THEN
					error := TRUE;
					COPY(build.name, temp);
					Strings.Append(temp, ": Import # not found in file #");
					MakeMessage(message, temp, module.imports[i], name);
					diagnostics.Error(builds.source, pos, Diagnostics.Invalid, message);
				END;
			END;
		END CheckImports;

		PROCEDURE ParseModule*(diagnostics : Diagnostics.Diagnostics);
		VAR
			reader : Streams.Reader;
			pre, mid, suf: Files.FileName;
			message : ARRAY 256 OF CHAR;
			error : BOOLEAN;
		BEGIN
			IF module.isParsed OR ~IsSourceCode() THEN RETURN; END;
			reader := GetReader(SELF, diagnostics);
			IF (reader # NIL) THEN
				GetModuleInfo(reader, module, builds.source, name, pos, diagnostics, error);
				IF ~error THEN
					module.isParsed := TRUE;
					flags := flags + module.flags;
					SplitName(name, pre, mid, suf);
					IF (module.name # mid)  THEN
						MakeMessage(message, "Module name not equal to filename in #", name, "");
						diagnostics.Warning(builds.source, pos, Diagnostics.Invalid, message);
					END;
					CreateContext(module.name, module.context);
				END;
			END;
		END ParseModule;

		PROCEDURE Show*(w : Streams.Writer);
		BEGIN
			w.String(name);
		END Show;

	END File;

TYPE

	WorkerParameters = OBJECT
	VAR
		file : File;
		diagnostics : Diagnostics.Diagnostics;
		importCache : SyntaxTree.ModuleScope;

		PROCEDURE &Init(file : File; diagnostics : Diagnostics.Diagnostics; importCache : SyntaxTree.ModuleScope);
		BEGIN
			ASSERT((file # NIL) & (diagnostics # NIL) & (importCache # NIL));
			SELF.file := file;
			SELF.diagnostics := diagnostics;
			SELF.importCache := importCache;
		END Init;

	END WorkerParameters;

TYPE

	BuildObj* = OBJECT
	VAR
		name- : Name;
		prefixes : ARRAY MaxPrefixes OF Name;
		excludedPackages : Strings.StringArray;
		onlyPackages: Strings.StringArray;
		compiler, compileOptions, linker, linkOptions : ARRAY 128 OF CHAR;
		target : ARRAY 8 OF CHAR;
		extension : ARRAY 8 OF CHAR;
		symbolFileExtension : ARRAY 8 OF CHAR;
		path : Files.FileName;
		disabled : BOOLEAN;
		link: BOOLEAN; (* link packages instead of compiling *)

		(* Used for dependencies analysis *)
		modules : POINTER TO ARRAY OF File;
		bitmap : POINTER TO ARRAY OF Bitmap;

		marked : BOOLEAN; (* Used by Check command *)

		(* List of all files and packages declared in the package description file *)
		files : File;
		packages : PackageList;

		(* Name of the package description file *)
		builds : Builds;

		include : SET;

		position- : LONGINT;

		PROCEDURE &Init;
		VAR i : LONGINT;
		BEGIN
			COPY("", name);
			FOR i := 0 TO LEN(prefixes)-1 DO prefixes[i] := ""; END;
			excludedPackages := NIL;
			onlyPackages := NIL;
			COPY(DefaultCompiler, compiler);
			COPY(DefaultCompileOptions, compileOptions);
			COPY(DefaultTarget, target);
			COPY(DefaultExtension, extension);
			COPY(DefaultSymbolFileExtension, symbolFileExtension);
			COPY(DefaultPath, path);
			disabled := DefaultDisabled;
			modules := NIL; bitmap := NIL;
			marked := FALSE;
			files := NIL;
			packages := NIL;
			builds := NIL;
			include := {};
			position := -1;
		END Init;

		PROCEDURE CompileThisPackage(package: Package): BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			IF (onlyPackages # NIL) THEN
				FOR i := 0 TO LEN(onlyPackages)-1 DO
					IF (package.name = onlyPackages[i]^) THEN
						RETURN TRUE
					END;
				END;
				RETURN FALSE
			END;
			RETURN TRUE
		END CompileThisPackage;


		PROCEDURE PackageIsExcluded(package : Package) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			IF (package = NIL) THEN RETURN FALSE; END;
			IF (excludedPackages # NIL) THEN
				FOR i := 0 TO LEN(excludedPackages)-1 DO
					IF (package.name = excludedPackages[i]^) THEN
						RETURN TRUE;
					END;
				END;
			END;
			RETURN FALSE;
		END PackageIsExcluded;

		PROCEDURE SetOptions(options : Options.Options);
		VAR string : ARRAY 512 OF CHAR;
		BEGIN
			ASSERT(options # NIL);
			IF (options # NIL) THEN
				link := options.GetFlag("link");
				IF options.GetString("compiler", compiler) THEN END;
				IF link THEN
					IF options.GetString("options", linkOptions) THEN END;
				ELSE
					IF options.GetString("options", compileOptions) THEN END;
				END;
				IF options.GetString("target", target) THEN END;
				IF options.GetString("extension", extension) THEN END;
				IF options.GetString("symbolFileExtension", symbolFileExtension) THEN END;
				IF options.GetString("path", path) THEN END;
				IF options.GetString("exclude", string) THEN
					Strings.TrimWS(string);
					excludedPackages := Strings.Split(string, " ");
				END;
				IF options.GetString("only",string) THEN
					Strings.TrimWS(string);
					onlyPackages := Strings.Split(string, " ");
				END;
			END;
		END SetOptions;

		(** List all source code files included in this build to a stream *)
		PROCEDURE ToStream*(w : Streams.Writer; charactersPerLine : LONGINT);
		VAR file : File; color : LONGINT; characterCount : LONGINT; name: Files.FileName;
		BEGIN
			characterCount := 0;
			file := files;
			WHILE (file # NIL) DO
				IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) & file.doCompile  & CompileThisPackage(file.package) THEN
					IF (w IS TextUtilities.TextWriter) THEN
						IF (ImportsSystem IN file.flags) THEN
							color := WMGraphics.Red;
						ELSE
							color := WMGraphics.Black;
						END;
						w(TextUtilities.TextWriter).SetFontColor(color);
					END;
					IF link THEN
						COPY(file.module.name, name)
					ELSE
						COPY(file.name, name)
					END;
					characterCount := characterCount + Strings.Length(name);
					IF (characterCount > charactersPerLine) THEN
						characterCount := 0;
						w.Ln;
					END;
					w.String(name); w.String(" ");
				END;
				file := file.next;
			END;
			IF (w IS TextUtilities.TextWriter) THEN
				w(TextUtilities.TextWriter).SetFontColor(WMGraphics.Black);
			END;
			w.Update;
		END ToStream;

		(** Generate a file that contains the list of all source code files of this build in compile order *)
		PROCEDURE GenerateToolFile*(CONST filename : Files.FileName; VAR res : LONGINT);
		VAR text : Texts.Text; tw : TextUtilities.TextWriter; dateTime : Dates.DateTime; temp : ARRAY 256 OF CHAR;
		BEGIN
			NEW(text); NEW(tw, text);
			tw.SetFontColor(LONGINT(808080FFH)); (* comment grey *)

			tw.String("# "); tw.String(name); tw.Ln;

			dateTime := Dates.Now();
			Strings.FormatDateTime(DateTimeFormat, dateTime, temp);

			tw.String("# "); tw.String(temp); tw.Ln;
			tw.String("# This file has been automatically generated using Release.Mod."); tw.Ln;
			tw.String("# Red colors indicate that a module imports SYSTEM."); tw.Ln;
			tw.SetFontColor(WMGraphics.Black);

			(* Compile command *)
			tw.SetFontStyle({WMGraphics.FontBold});
			tw.String("SystemTools.DoCommands"); tw.Ln;
			tw.SetFontStyle({});
			tw.String("SystemTools.Timer start ~"); tw.Ln;
			IF link THEN
				tw.String(linker);
				GetLinkerOptions(temp);
			ELSE
				tw.String(compiler);
				GetCompilerOptions(temp);
			END;
			tw.String(" "); tw.String(temp); tw.Ln;
			ToStream(tw, 80); (* file list *) tw.Ln; tw.String("~"); tw.Ln;
			tw.String("SystemTools.Show Time elapsed: ~ SystemTools.Ln ~"); tw.Ln;
			tw.String("SystemTools.Timer elapsed ~ SystemTools.Ln ~"); tw.Ln;
			tw.String("~");
			tw.Update;

			TextUtilities.StoreOberonText(text, filename, res);
		END GenerateToolFile;

		(* Generate a XML file describing the packages use by WMInstaller.Mod *)
		PROCEDURE GeneratePackageFile(CONST filename : ARRAY OF CHAR; VAR res : LONGINT);
		VAR
			packageArray : PackageArray; package : Package;
			fullname : Files.FileName; file : Files.File; w : Files.Writer;
			packageNbr, i : LONGINT;

			PROCEDURE WritePackage(package : Package; sources : BOOLEAN; packageNbr : LONGINT; w : Streams.Writer);
			VAR filename : Files.FileName; description : ARRAY 300 OF CHAR; name, installMode : ARRAY 128 OF CHAR;
			BEGIN
				ASSERT((package # NIL) & (w # NIL));
				COPY(package.description, description);
				IF sources THEN
					COPY(package.name, name); Strings.Append(name, " Sources");
					COPY(package.source, filename); Strings.Append(description, " sources");
				ELSE
					COPY(package.name, name);
					COPY(package.archive, filename);
				END;

				w.Char(Tab);
				w.String('<Package nr="'); w.Int(packageNbr, 0);
				w.String('" name="'); w.String(name);
				w.String('" file="'); w.String(filename);
				w.String('" description="'); w.String(description);

				IF (package.installMode = Required) THEN installMode := "required";
				ELSIF (package.installMode = Yes) THEN installMode := "yes";
				ELSIF (package.installMode = No) THEN installMode := "no";
				ELSE installMode := "undefined";
				END;

				w.String('" install="'); w.String(installMode); w.String('"/>'); w.Ln;
			END WritePackage;

		BEGIN
			res := Files.Ok;
			packageArray := packages.GetAll();
			IF (packageArray # NIL) THEN
				COPY(path, fullname); Strings.Append(fullname, filename);
				file := Files.New(fullname);
				IF (file # NIL) THEN
					packageNbr := 1;
					Files.OpenWriter(w, file, 0);
					w.String('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'); w.Ln; w.Ln;
					w.String("<!-- This has been automatically generated by Release.Mod -->"); w.Ln; w.Ln;
					w.String("<Packages>"); w.Ln;
					FOR i := 0 TO LEN(packageArray)-1 DO
						package := packageArray[i];
						IF ~PackageIsExcluded(package) THEN
							WritePackage(package, FALSE, packageNbr, w);
							INC(packageNbr);
							IF (package.source # "") THEN
								WritePackage(package, TRUE, packageNbr, w);
								INC(packageNbr);
							END;
						END;
					END;
					w.String("</Packages>"); w.Ln; w.Update;
					Files.Register(file);
				ELSE
					res := NoFile;
				END;
			ELSE
				res := NoPackages;
			END;
		END GeneratePackageFile;

		PROCEDURE GenerateZipFiles(out, error : Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR err : BOOLEAN);
		VAR packageArray : PackageArray; i, res : LONGINT;

			PROCEDURE AddFile(archive: Zip.Archive; CONST srcname,  dstname: ARRAY OF CHAR; VAR res: LONGINT);
			VAR f: Files.File; r: Files.Rider; pathName, fileName: Files.FileName;
			BEGIN
				f := Files.Old(srcname);
				IF f = NIL THEN
					res := Zip.BadName
				ELSE
					f.Set(r, 0);
					Files.SplitPath(dstname, pathName, fileName);
					Zip.AddEntry(archive, fileName, r, f.Length(), 9, 2, res);
				END;
			END AddFile;

			PROCEDURE DeleteFile(filename : ARRAY OF CHAR; VAR nofFilesDeleted : LONGINT);
			VAR file : Files.File;
			BEGIN
				file := Files.Old(filename);
				IF (file # NIL) THEN
					Files.Delete(filename, res);
					IF (res = Files.Ok) THEN
						INC(nofFilesDeleted);
					ELSE
						out.String(" could not delete existing file, res: "); out.Int(res, 0); out.Ln;
					END;
				END;
			END DeleteFile;

			PROCEDURE GetObjectFileName(file : File; CONST prefix : ARRAY OF CHAR; VAR fileName: ARRAY OF CHAR);
			BEGIN
				COPY(prefix, fileName);
				Strings.Append(fileName, file.module.name);
				Strings.Append(fileName, ".");
				Strings.Append(fileName, extension);
			END GetObjectFileName;

			PROCEDURE GetSymbolFileName(file : File; CONST prefix : ARRAY OF CHAR; VAR fileName : ARRAY OF CHAR);
			BEGIN
				COPY(prefix, fileName);
				Strings.Append(fileName, file.module.name);
				Strings.Append(fileName, ".");
				Strings.Append(fileName, symbolFileExtension);
			END GetSymbolFileName;

			PROCEDURE GetPackageFileName(package : Package; sourceCode : BOOLEAN; VAR filename : ARRAY OF CHAR) : BOOLEAN;
			BEGIN
				ASSERT(package # NIL);
				COPY(path, filename);
				IF ~sourceCode THEN
					Strings.Append(filename, package.archive);
				ELSE
					Strings.Append(filename, package.source);
				END;
				RETURN (filename # path);
			END GetPackageFileName;

			PROCEDURE DeleteOldZipFiles(packageArray : PackageArray);
			VAR filename : Files.FileName; nofFilesDeleted, i : LONGINT;
			BEGIN
				ASSERT(packageArray # NIL);
				out.String("Deleting old archive files ... "); out.Update;
				nofFilesDeleted := 0;
				FOR i := 0 TO LEN(packageArray)-1 DO
					IF GetPackageFileName(packageArray[i], TRUE, filename) THEN DeleteFile(filename, nofFilesDeleted); END;
					IF GetPackageFileName(packageArray[i], FALSE, filename) THEN DeleteFile(filename, nofFilesDeleted); END;
				END;
				out.Int(nofFilesDeleted, 0); out.String(" files deleted."); out.Ln;
			END DeleteOldZipFiles;

			PROCEDURE StripReleasePrefix(file : File; VAR filename: ARRAY OF CHAR);
			VAR pre, mid, suf : Files.FileName;
			BEGIN
				SplitName(file.name, pre, mid, suf);
				ASSERT(pre = ReleasePrefix);
				COPY (mid, filename); Strings.Append(filename, "."); Strings.Append(filename, suf);
			END StripReleasePrefix;

			PROCEDURE GenerateZipFile(package : Package; sourceCode : BOOLEAN; VAR res : LONGINT);
			VAR
				file : File; archiveName, source, dest : Files.FileName;
				archive : Zip.Archive;
				nofFilesAdded : LONGINT;
			BEGIN
				ASSERT(package # NIL);
				res := Zip.Ok;
				IF GetPackageFileName(package, sourceCode, archiveName) THEN
					out.String("Creating archive "); out.String(archiveName); out.String(" ... "); out.Update;
					archive := Zip.CreateArchive(archiveName, res);
					IF (res # Zip.Ok) THEN
						error.String("error: "); Zip.ShowError(res, error); error.Ln;
						RETURN;
					END;
					nofFilesAdded := 0;
					file := files;
					WHILE (file # NIL) DO
						IF (file.package = package) & file.IsInRelease(include) THEN
							IF sourceCode THEN
								IF file.IsSourceCode() THEN
									AddFile(archive, file.name, file.name, res);
									INC(nofFilesAdded);
								END;
							ELSE
								IF file.IsSourceCode() THEN

									GetObjectFileName(file, path, source); GetObjectFileName(file, "", dest);
									AddFile(archive, source, dest, res);
									INC(nofFilesAdded);

									IF (res = Zip.Ok) & (package.source = "") THEN (* Also add source code since no source code package is defined *)
										AddFile(archive, file.name, file.name, res);
									END;

									IF symbolFileExtension # extension THEN
										GetSymbolFileName(file, path, source); GetSymbolFileName(file, "", dest);
										AddFile(archive, source, dest, res);
										INC(nofFilesAdded);
									END

								ELSE
									AddFile(archive, file.name, file.name, res);
									INC(nofFilesAdded);
									IF (res = Zip.Ok) & (HasReleasePrefix IN file.flags) THEN
										StripReleasePrefix(file, dest); AddFile(archive, file.name, dest, res);
										INC(nofFilesAdded);
									END;
								END;
							END;
							IF (res # Zip.Ok) THEN
								error.Ln; error.String("Could not add file "); error.String(file.name);
								error.String(": "); Zip.ShowError(res, error); error.Ln;
								error.Update;
								RETURN;
							END;
						END;
						file := file.next;
					END;
					out.Int(nofFilesAdded, 0); out.String(" files added."); out.Ln; out.Update;
				END;
			END GenerateZipFile;

		BEGIN
			packageArray := packages.GetAll();
			IF (packageArray # NIL) THEN
				DeleteOldZipFiles(packageArray);
				FOR i := 0 TO LEN(packageArray)-1 DO
					IF ~PackageIsExcluded(packageArray[i]) THEN
						GenerateZipFile(packageArray[i], TRUE, res);
						IF (res # Zip.Ok) THEN err := TRUE; RETURN END;
						GenerateZipFile(packageArray[i], FALSE, res);
						IF (res # Zip.Ok) THEN err := TRUE; RETURN END;
					END;
				END;
			ELSE
				diagnostics.Error("", Diagnostics.Invalid, Diagnostics.Invalid, "No packages");
			END;
		END GenerateZipFiles;

		PROCEDURE FindPosition*(CONST filename : ARRAY OF CHAR; diagnostics : Diagnostics.DiagnosticsList) : LONGINT;
		VAR
			file, ref : File; position : LONGINT; pre, suf : ARRAY 32 OF CHAR;
			importOk : ARRAY MaxNofImports OF BOOLEAN; i : LONGINT;

			PROCEDURE Done() : BOOLEAN;
			VAR i : LONGINT;
			BEGIN
				i := 0; WHILE (i < LEN(importOk)) & (importOk[i] = TRUE) DO INC(i); END;
				RETURN (i >= LEN(importOk));
			END Done;

			PROCEDURE Process(f : File);
			VAR i : LONGINT;
			BEGIN
				IF f.IsSourceCode() & f.IsInRelease(include) & ~PackageIsExcluded(f.package)THEN
					FOR i := 0 TO LEN(importOk)-1 DO
						IF (file.module.imports[i] = f.module.name) & ~PackageIsExcluded(file.package)  THEN importOk[i] := TRUE; END;
					END;
				END;
			END Process;

		BEGIN
			NEW(file, builds);
			COPY(filename, file.name);
			SplitName(file.name, pre, file.module.name, suf);
			IF (suf = "Mod") OR (suf="Mdf") OR (suf="Mos") THEN
				INCL(file.flags, SourceCode);
				file.ParseModule(diagnostics);
				IF (diagnostics.nofErrors = 0) THEN
					FOR i := 0 TO LEN(importOk)-1 DO
						IF (file.module.imports[i] # "") THEN importOk[i] := FALSE; ELSE importOk[i] := TRUE; END;
					END;

					position := 0;
					ref := files;
					LOOP
						IF Done() THEN EXIT; END;
						IF (ref = NIL) THEN EXIT; END;
						Process(ref);
						IF (ref.next # NIL) THEN position := ref.next.pos; ELSE position := ref.pos + 100; END;
						ref := ref.next;
					END;
				ELSE
					position := -1;
				END;
			ELSE
				position := 0;
			END;
			RETURN position;
		END FindPosition;

		PROCEDURE FindModule(CONST moduleName : Modules.Name) : File;
		VAR file : File;
		BEGIN
			file := files;
			WHILE (file # NIL) DO
				IF file.IsInRelease(include) & file.IsSourceCode() & ~PackageIsExcluded(file.package) THEN
					IF (file.module.name = moduleName) THEN
						RETURN file;
					END;
				END;
				file := file.next;
			END;
			RETURN NIL;
		END FindModule;

		PROCEDURE FindFile(CONST filename : Files.FileName) : File;
		VAR file : File;
		BEGIN
			file := files;
			WHILE (file # NIL) DO
				IF file.IsInRelease(include) & file.IsSourceCode() & ~PackageIsExcluded(file.package) THEN
					IF (file.name = filename) THEN
						RETURN file;
					END;
				END;
				file := file.next;
			END;
			RETURN NIL;
		END FindFile;

		(** For all files contained in this build check whether they exist. Also try to parse the import section of the source code files *)
		PROCEDURE CheckFiles*(diagnostics : Diagnostics.Diagnostics);
		VAR file : File; message : ARRAY 256 OF CHAR;
		BEGIN
			file := files;
			WHILE (file # NIL) DO
				IF file.IsInRelease(include) & ~PackageIsExcluded(file.package) THEN
					IF (file.file = NIL) THEN
						file.file := Files.Old(file.name);
					END;
					IF (file.file = NIL) THEN
						MakeMessage(message, "File # does not exists (Package #)", file.name, file.package.name);
						diagnostics.Warning(builds.source, file.pos, Diagnostics.Invalid, message);
					ELSIF file.IsSourceCode() THEN
						file.ParseModule(diagnostics);
					END;
					IF ~KeepFilesOpen THEN
						file.file := NIL;
					END;
				END;
				file := file.next;
			END;
		END CheckFiles;

		(** Check the source code files of this build for the import order *)
		PROCEDURE CheckModules*(diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
		VAR file : File; tempError : BOOLEAN;
		BEGIN
			error := FALSE;
			file := files;
			WHILE (file # NIL) DO
				IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) THEN
					tempError := FALSE;
					file.CheckImports(diagnostics, SELF, tempError);
					error := error OR tempError;
				END;
				file := file.next;
			END;
		END CheckModules;

		(** Call both CheckFiles and CheckModules *)
		PROCEDURE DoChecks*(out : Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
		VAR start, start0 : Dates.DateTime;
		BEGIN
			ASSERT((diagnostics # NIL));
			IF (out # NIL) THEN out.String(name); out.String(": Check if all files are present... "); out.Update; END;
			start0 := Dates.Now();
			CheckFiles(diagnostics);
			Strings.ShowTimeDifference(start0, Dates.Now(), out);
			IF (out # NIL) THEN out.String(" done."); out.Ln; out.Update; END;

			IF (out # NIL) THEN out.String(name); out.String(": Check modules and imports... "); out.Update; END;
			start := Dates.Now();
			error := FALSE;
			CheckModules(diagnostics, error);
			Strings.ShowTimeDifference(start, Dates.Now(), out);
			IF (out # NIL) THEN out.String(" done."); out.Ln; out.Update; END;
		END DoChecks;

		(* Analyzes the import dependencies between all modules *)
		PROCEDURE AnalyzeDependencies(out : Streams.Writer);
		VAR
			nofModules : LONGINT;
			file : File;
			ignore, index, i, j : LONGINT;

			PROCEDURE GetIndexOf(file : File; CONST moduleName : Name) : LONGINT;
			VAR f : File;
			BEGIN
				f := file.prev;
				LOOP
					ASSERT(f # NIL);
					IF f.IsSourceCode() & f.IsInRelease(include) & ~PackageIsExcluded(f.package) & (f.module.name = moduleName) THEN
						EXIT;
					END;
					f := f.prev;
				END;
				RETURN f.index;
			END GetIndexOf;

		BEGIN
			modules:= NIL;
			nofModules := GetNofSources(ignore);
			IF (out # NIL) THEN out.String("Analyzing dependencies of "); out.Int(nofModules, 0); out.String(" modules... "); END;
			IF (nofModules > 0) THEN

				(*	Initialize the array of File 'modules' and the fields File.index and File.importIndices. After initialization,
					all File.importIndices contain the indices of directly imported modules *)
				NEW(modules, nofModules);
				index := 0;
				file := files;
				WHILE (file # NIL) DO
					IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) THEN
						file.index := index;
						modules[index] := file;
						FOR i := 0 TO file.module.nofImports-1 DO
							modules[index].importIndices[i] := GetIndexOf(file, file.module.imports[i]);
						END;
						INC(index);
					END;
					file := file.next;
				END;

				(* 	Create a two-dimensional bitmap where bitmap[i] is the import bitmap of the file with file.index = i.
					The import bitmap[i] has all bits j set where j is directly or indirectly imported by the file i . *)
				NEW(bitmap, nofModules);
				FOR i := 0 TO nofModules-1 DO
					NEW(bitmap[i], nofModules);
					FOR j := 0 TO modules[i].module.nofImports-1 DO
						bitmap[i].Set(modules[i].importIndices[j]);
						bitmap[i].Union(bitmap[modules[i].importIndices[j]]);
					END;
				END;

				(*	Initialize fields File.nofDependetModules and File.nofRequiredModules *)
				FOR i := 0 TO nofModules-1 DO
					modules[i].nofDependentModules := 0;
					FOR j := 0 TO nofModules-1 DO
						IF bitmap[j].IsSet(i) THEN INC(modules[i].nofDependentModules); END;
					END;
					modules[i].nofRequiredModules := bitmap[i].NofBitsSet();
				END;
			END;
			IF (out # NIL) THEN out.String("done."); out.Ln; END;
		END AnalyzeDependencies;

		PROCEDURE ShowDependencies(out  : Streams.Writer);
		VAR i, j : LONGINT; temp : File;
		BEGIN
			ASSERT(out # NIL);
			ASSERT((modules # NIL) & (bitmap # NIL));
			(* bubble sort *)
			FOR i := 0 TO LEN(modules)-1 DO
				FOR j := 0 TO LEN(modules)-2 DO
					IF (modules[j].nofDependentModules < modules[j+1].nofDependentModules) THEN
						temp := modules[j];
						modules[j] := modules[j+1];
						modules[j+1] := temp;
					END;
				END;
			END;
			FOR i := 0 TO LEN(modules)-1 DO
				out.String(modules[i].name); out.String(" -- ");
				out.Int(modules[i].nofDependentModules, 0);
				out.String("  ("); out.Int(modules[i].module.nofImports, 0);
				out.String("/"); out.Int(modules[i].nofRequiredModules, 0);
				out.String(")");
				out.Ln;
			END;
		END ShowDependencies;

		(** Clear the doCompile flag of all source code files contained in this build and not excluded *)
		PROCEDURE ClearMarks;
		VAR file : File;
		BEGIN
			file := files;
			WHILE (file # NIL) DO
				IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) THEN
					file.doCompile := FALSE;
				END;
				file := file.next;
			END;
		END ClearMarks;

		(** Set the doCompile flag of all non-excluded source code files in this build that depend on the specified file *)
		PROCEDURE MarkFiles(CONST filename : Files.FileName; VAR inBuild : BOOLEAN; VAR nofNewMarks : LONGINT);
		VAR file : File; nofModules, i, ignore : LONGINT;
		BEGIN
			nofNewMarks := 0;
			file := FindFile(filename);
			IF (file # NIL) THEN
				inBuild := TRUE;
				IF ~file.doCompile THEN
					file.doCompile := TRUE;
					INC(nofNewMarks);
				END;
				nofModules := GetNofSources(ignore);
				FOR i := 0 TO nofModules-1 DO
					IF bitmap[i].IsSet(file.index) THEN
						IF ~modules[i].doCompile THEN
							INC(nofNewMarks);
							modules[i].doCompile := TRUE;
						END;
					END;
				END;
			ELSE
				inBuild := FALSE;
			END;
		END MarkFiles;

		PROCEDURE ShowDependentModules(CONST modulename : Modules.Name; mode : LONGINT;  out : Streams.Writer);
		CONST CharactersPerLine = 60;
		VAR module : File; ignore, nofModules, characterCount, i : LONGINT;
		BEGIN
			ASSERT(out # NIL);
			module := FindModule(modulename);
			IF (module # NIL) THEN
				characterCount := 0;
				nofModules := GetNofSources(ignore);
				IF (mode = Mode_ShowImporting) THEN
					FOR i := 0 TO nofModules-1 DO
						IF bitmap[i].IsSet(module.index) THEN
							out.String(modules[i].name); out.String(" ");
							characterCount := characterCount + Strings.Length(modules[i].name);
							IF (characterCount > CharactersPerLine) THEN characterCount := 0;  out.Ln; out.Update; END;
						END;
					END;
				ELSE
					FOR i := 0 TO nofModules-1 DO
						IF bitmap[module.index].IsSet(i) THEN
							out.String(modules[i].name); out.String(" ");
							characterCount := characterCount + Strings.Length(modules[i].name);
							IF (characterCount > CharactersPerLine) THEN characterCount := 0; out.Ln; out.Update; END;
						END;
					END;
				END;
			ELSE
				out.String("Module "); out.String(modulename); out.String(" not found"); out.Ln;
			END;
			out.Update;
		END ShowDependentModules;

		PROCEDURE GetCompilerOptions(VAR options: ARRAY OF CHAR);
		BEGIN
			COPY(compileOptions, options);
			IF target # "" THEN
				Strings.Append(options, " -b="); Strings.Append(options, target);
			END;
			IF extension # "" THEN
				Strings.Append(options, " --objectFileExtension="); Strings.Append(options, "."); Strings.Append(options, extension);
				Strings.Append(options, " --symbolFileExtension="); Strings.Append(options, "."); Strings.Append(options, symbolFileExtension);
			 END;
			IF path # "" THEN
				Strings.Append(options, " --destPath="); Strings.Append(options, path);
			END;
		END GetCompilerOptions;

		PROCEDURE GetLinkerOptions(VAR options: ARRAY OF CHAR);
		BEGIN
			COPY(linkOptions, options);
		END GetLinkerOptions;

		(* Count the number of source codes files in a specific build *)
		PROCEDURE GetNofSources(VAR nofMarked : LONGINT) : LONGINT;
		VAR file : File; nofSources : LONGINT;
		BEGIN
			nofSources := 0;
			file := files;
			WHILE (file # NIL) DO
				IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) & CompileThisPackage(file.package) THEN
					INC(nofSources);
					IF file.doCompile THEN INC(nofMarked); END;
				END;
				file := file.next;
			END;
			RETURN nofSources;
		END GetNofSources;

		PROCEDURE GetInfo*(VAR nofSources, nofFiles : LONGINT);
		VAR file : File;
		BEGIN
			nofSources := 0; nofFiles := 0;
			file := files;
			WHILE (file # NIL) DO
				IF file.IsInRelease(include) & ~PackageIsExcluded(file.package) THEN
					INC(nofFiles);
					IF file.IsSourceCode() THEN
						INC(nofSources);
					END;
				END;
				file := file.next;
			END;
		END GetInfo;

		PROCEDURE CompileFile(file : File; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer; VAR error : BOOLEAN; importCache : SyntaxTree.ModuleScope);
		VAR
		 	reader : Streams.Reader;
			options : ARRAY 1024 OF CHAR;
			optionsReader : Streams.StringReader;
			message : ARRAY 512 OF CHAR;
			compilerOptions: Compiler.CompilerOptions;
		BEGIN
			ASSERT((file # NIL) & (diagnostics # NIL) & (importCache # NIL));
			reader := GetReader(file, diagnostics);
			IF ~KeepFilesOpen THEN
				file.file := NIL;
			END;
			IF (reader # NIL) THEN
				GetCompilerOptions(options);
				NEW(optionsReader, LEN(options));
				optionsReader.Set(options);
				error := ~Compiler.GetOptions(optionsReader, log, diagnostics, compilerOptions);
				IF ~error THEN
					error := ~Compiler.Modules(file.name, reader, 0, diagnostics, log, compilerOptions, importCache);
				END;
			ELSE
				MakeMessage(message, "File # not found", file.name, "");
				diagnostics.Error("", file.pos, Diagnostics.Invalid, message);
				error := TRUE;
			END;
		END CompileFile;

		(* Job procedure called by worker thread *)
		PROCEDURE CompileJob(parameters : ANY; VAR error : BOOLEAN);
		BEGIN
			ASSERT(
				(parameters # NIL) & (parameters IS WorkerParameters) &
				(parameters(WorkerParameters).file # NIL) & (parameters(WorkerParameters).diagnostics # NIL) &
				(parameters(WorkerParameters).importCache # NIL)
			);
			CompileFile(
				parameters(WorkerParameters).file,
				parameters(WorkerParameters).diagnostics,
				NIL,
				error,
				parameters(WorkerParameters).importCache
			);
		END CompileJob;

		PROCEDURE CreateJob(threadpool : ReleaseThreadPool.ThreadPool; file : File; diagnostics : Diagnostics.Diagnostics; importCache : SyntaxTree.ModuleScope);
		VAR parameters : WorkerParameters; dependencies : ReleaseThreadPool.Dependencies; i, priority : LONGINT;
		BEGIN
			ASSERT((threadpool # NIL) & (file # NIL) & (diagnostics # NIL) & (importCache # NIL));
			NEW(parameters, file, diagnostics, importCache);
			priority := file.nofDependentModules;
			i := 0;
			WHILE (i < file.module.nofImports) DO
				dependencies[i] := modules[file.importIndices[i]].jobID;
				INC(i);
			END;
			dependencies[i] := ReleaseThreadPool.NoMoreDependencies;
			file.jobID := threadpool.CreateJob(CompileJob, parameters, priority, dependencies);
		END CreateJob;

		(** Compile all sources included in this build *)
		PROCEDURE Compile*(nofWorkers : LONGINT; out, error : Streams.Writer; verbose : BOOLEAN; diagnostics : Diagnostics.DiagnosticsList; VAR err : BOOLEAN);
		VAR
			file : File; nofFiles, nofSources, nofMarked, step, steps : LONGINT;
			importCache : SyntaxTree.ModuleScope;
			startTime : Dates.DateTime;
			log : Streams.Writer;
			dummyWriter : Streams.StringWriter;
			threadpool : ReleaseThreadPool.ThreadPool;
		BEGIN
			ASSERT(nofWorkers >= 0);
			nofSources := GetNofSources(nofMarked);
			IF (nofWorkers > 0) THEN
				AnalyzeDependencies(out);
				NEW(threadpool, nofWorkers);
				out.String("Generating jobs to compile build ");
			ELSE
				out.String("Compiling build ");
			END;

			out.String(name); out.String(" (");
			IF (nofMarked # nofSources) THEN out.Int(nofMarked, 0); out.Char("/"); END;
			out.Int(nofSources, 0); out.String(" files)");
			IF (nofWorkers > 0) THEN
				out.String(" using "); out.Int(nofWorkers, 0); out.String(" worker threads");
			END;
			out.String(" ... ");
			IF verbose THEN
				log := out;
			ELSE
				NEW(dummyWriter, 2);
				log := dummyWriter;
				step := ((nofMarked-1) DIV 10) +1; steps := 1;
				out.String(" 00% "); out.Update;
			END;
			startTime := Dates.Now();

			importCache := SyntaxTree.NewModuleScope();
			nofFiles := 0; err := FALSE;
			file := files;
			WHILE (file # NIL) DO
				IF file.IsSourceCode() & file.IsInRelease(include) & ~PackageIsExcluded(file.package) & file.doCompile & CompileThisPackage(file.package) THEN
					IF (nofWorkers = 0) THEN
						CompileFile(file, diagnostics, log, err, importCache);
						IF err THEN
							error.Ln; error.Ln;
							error.String("Error(s) in file "); error.String(file.name); error.Ln;
							diagnostics.ToStream(error, {Diagnostics.TypeError}); error.Ln;
							diagnostics.Reset;
							RETURN;
						END;
					ELSE
						CreateJob(threadpool, file, diagnostics, importCache);
					END;
					INC(nofFiles);
					IF ~verbose & (step # 0) & (nofFiles MOD step = 0) THEN
						out.Int(steps * 10, 0); out.String("% "); out.Update;
						INC(steps);
					END;
				END;
				file := file.next;
			END;
			IF verbose THEN
				out.Int(nofFiles, 0); out.String(" files done in ");
			ELSIF (steps < 11) THEN
				out.String("100% ");
			END;
			out.String(" done in "); Strings.ShowTimeDifference(startTime, Dates.Now(), out);
			out.Ln; out.Update;
			IF (nofWorkers > 0) THEN
				threadpool.AwaitAllDone;
				threadpool.Close;
				err := diagnostics.nofErrors > 0;
				IF (diagnostics.nofMessages > 0) THEN
					diagnostics.ToStream(error, Diagnostics.All); error.Ln;
				END;
				out.String("Compilation time: "); Strings.ShowTimeDifference(startTime, Dates.Now(), out);
				out.Ln; out.Update;
			END;
		END Compile;
	END BuildObj;

TYPE

	Version = RECORD
		major, minor : LONGINT;
	END;


	Builds* = OBJECT
	VAR
		version : Version;

		(* 	All builds described in the build description file *)
		builds- : ARRAY MaxBuilds OF BuildObj;
		nofBuilds : LONGINT;

		packages- : PackageList;

		(*	In the build description file, the user may group files using prefixes, e.g.
			WIN,NATIVE {  filename }. In this example, WIN and NATIVE are prefixes.
			The prefixes array contains each prefix exactly once. The index of specific prefix in this
			are will be used as bit position for the BuildObj.include set. *)
		prefixes : ARRAY MaxPrefixes OF Name;
		nofPrefixes : LONGINT;

		(*	Name of the package description file *)
		source : Files.FileName;

		(*	All files of all builds in the build description file *)
		files : File;

		(* number of files / sources  in <files> list *)
		nofFiles- : LONGINT;
		nofSources- : LONGINT;

		PROCEDURE &Init;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(builds)-1 DO builds[i] := NIL; END;
			nofBuilds := 0;

			NEW(packages);

			FOR i := 0 TO LEN(prefixes)-1 DO prefixes[i] := ""; END;
			nofPrefixes := 0;

			source := "";
			files := NIL;
			nofFiles := 0;
			nofSources := 0;
		END Init;

		(* Add the specified prefix to the prefixes array if its not already contained *)
		PROCEDURE AddPrefix(CONST prefix : Name; diagnostics : Diagnostics.Diagnostics) : BOOLEAN;
		VAR error : BOOLEAN; i : LONGINT;
		BEGIN
			ASSERT((prefix # "") & (diagnostics # NIL));
			error := FALSE;
			(* check whether prefix is already registered *)
			i := 0; WHILE (i < LEN(prefixes)) & (prefixes[i] # prefix) DO INC(i); END;
			IF (i >= LEN(prefixes)) THEN (* new prefix, add it *)
				IF (nofPrefixes < LEN(prefixes)) THEN
					prefixes[nofPrefixes] := prefix;
					INC(nofPrefixes);
				ELSE
					error := TRUE;
					diagnostics.Warning("", Diagnostics.Invalid, Diagnostics.Invalid, "Maximum number of prefixes exceeded");
				END;
			END;
			RETURN ~error;
		END AddPrefix;

		(* Get the index of the specified prefix in the prefixes array. Returns -1 if prefix not found *)
		PROCEDURE GetPrefixIndex(CONST prefix : ARRAY OF CHAR) : LONGINT;
		VAR index : LONGINT;
		BEGIN
			index := 0;
			WHILE (index < nofPrefixes) & (prefixes[index] # prefix) DO INC(index); END;
			IF (index >= nofPrefixes) THEN index := -1; END;
			RETURN index;
		END GetPrefixIndex;

		(* Do checks for all builds *)
		PROCEDURE CheckAll*(out : Streams.Writer; diagnostics : Diagnostics.Diagnostics);
		VAR file : File; build : LONGINT; message : ARRAY 256 OF CHAR; error : BOOLEAN;
		BEGIN
			ASSERT(diagnostics # NIL);
			(* Check whether all files exist and parse modules*)
			out.String("Checking files for all builds... "); out.Update;
			file := files;
			WHILE (file # NIL) DO
				IF (file.file = NIL) THEN
					file.file := Files.Old(file.name);
				END;
				IF (file.file = NIL) THEN
					MakeMessage(message, "File # does not exists (Package #)", file.name, file.package.name);
					IF file.IsSourceCode() THEN
						diagnostics.Error(source, file.pos, Diagnostics.Invalid, message);
					ELSE
						diagnostics.Warning(source, file.pos, Diagnostics.Invalid, message);
					END;
				ELSIF file.IsSourceCode() THEN
					file.ParseModule(diagnostics);
				END;
				IF ~KeepFilesOpen THEN
					file.file := NIL;
				END;
				file := file.next;
			END;
			out.String("done."); out.Ln;

			build := 0;
			WHILE (build < LEN(builds)) & (builds[build] # NIL) DO
				out.String("Checking imports of builds "); out.String(builds[build].name); out.String("... "); out.Update;
				error := FALSE;
				builds[build].CheckModules(diagnostics, error);
				out.String("done."); out.Ln;
				INC(build);
			END;
			out.Update;
		END CheckAll;

		(* Show build statistics *)
		PROCEDURE Show*(w : Streams.Writer; details : BOOLEAN);
		VAR
			statistics : Statistics; build, prefix, nofFiles, nofSources : LONGINT; file : File; options : ARRAY 256 OF CHAR;
			diagnostics : Diagnostics.DiagnosticsList;
			error : BOOLEAN;
		BEGIN
			NEW(statistics);
			w.String("Release statistics:"); w.Ln;
			nofFiles := 0; nofSources := 0;
			file := files;
			WHILE (file # NIL) DO
				statistics.AddFile(file);
				file := file.next;
			END;
			w.Int(statistics.nofFiles, 0); w.String(" files ("); w.Int(statistics.nofSources, 0); w.String(" sources)"); w.Ln;

			w.String("Builds: ");
			IF (builds[0].name # "") THEN
				w.Ln;
				FOR build := 0 TO LEN(builds)-1 DO
					IF (builds[build] # NIL) THEN
						w.String(builds[build].name); w.Ln;
						w.Char(Tab); w.String("Includes: ");
						FOR prefix := 0 TO LEN(builds[build].prefixes)-1 DO
							IF (builds[build].prefixes[prefix] # "") THEN
								w.String(" ["); w.String(builds[build].prefixes[prefix]); w.String("]");
							END;
						END;
						w.Ln;
						w.Char(Tab); w.String("Compile: ");
						w.String(builds[build].compiler); w.String(" "); builds[build].GetCompilerOptions(options); w.String(options); w.Ln;

						statistics.Get(nofFiles, nofSources, builds[build].include);
						nofFiles := nofFiles + statistics.nofFilesAll;
						nofSources := nofSources + statistics.nofSourcesAll;
						w.Char(Tab); w.Int(nofFiles, 0); w.String(" files ("); w.Int(nofSources, 0); w.String(" sources)"); w.Ln;
					END;
				END;
			ELSE
				w.String("none"); w.Ln;
			END;

			packages.ToStream(w);

			IF details THEN
				prefix := 0;
				WHILE (prefix < LEN(prefixes)) & (prefixes[prefix] # "") DO
					w.String(prefixes[prefix]); w.Ln;
					nofFiles := 0;
					file := files;
					WHILE (file # NIL) DO
						IF (file.release # All) & (prefix IN file.release) THEN
							w.Char(Tab); w.String(file.name); w.Ln;
							INC(nofFiles);
						END;
						file := file.next;
					END;
					w.Char(Tab); w.Int(nofFiles, 0); w.String(" files"); w.Ln;
					INC(prefix);

				END;

				NEW(diagnostics);

				FOR build := 0 TO LEN(builds)-1 DO
					IF (builds[build] # NIL) THEN
						w.String("*** Import statistics for build "); w.String(builds[build].name); w.String(" ***"); w.Ln;
						error := FALSE;
						builds[build].DoChecks(w, diagnostics, error); w.Ln;
						IF ~error THEN
							diagnostics.Reset;
							builds[build].AnalyzeDependencies(w); w.Ln;
							builds[build].ShowDependencies(w);
							w.Ln;
						ELSE
							diagnostics.ToStream(w, Diagnostics.All); w.Ln;
						END;
					END;
				END;
			END;
			w.Update;
		END Show;

		PROCEDURE GetReleaseSet(build : BuildObj; VAR release : SET);
		VAR prefix, index : LONGINT;
		BEGIN
			release := {};
			FOR prefix := 0 TO LEN(build.prefixes)-1 DO
				IF (build.prefixes[prefix] # "") THEN
					index := GetPrefixIndex(build.prefixes[prefix]);
					IF (index >= 0) THEN
						INCL(release, index);
					ELSE
						HALT(99);
					END;
				END;
			END;
		END GetReleaseSet;

		(** Get a reference to a BuildObj by name *)
		PROCEDURE GetBuild*(CONST buildname : ARRAY OF CHAR) : BuildObj;
		VAR build : BuildObj; i : LONGINT;
		BEGIN
			build := NIL;
			i := 0; WHILE (i < LEN(builds)) & (builds[i] # NIL) & (builds[i].name # buildname) DO INC(i); END;
			IF (i < LEN(builds)) THEN
				build := builds[i];
			END;
			RETURN build;
		END GetBuild;

		PROCEDURE AddBuild(build : BuildObj; diagnostics : Diagnostics.Diagnostics) : BOOLEAN;
		VAR error : BOOLEAN; i : LONGINT;
		BEGIN
			ASSERT((build # NIL) & (diagnostics # NIL));
			error := FALSE;
			IF (nofBuilds < LEN(builds)) THEN
				build.builds := SELF;
				builds[nofBuilds] := build;
				FOR i := 0 TO LEN(build.prefixes)-1 DO
					IF (build.prefixes[i] # "") THEN error := error OR ~AddPrefix(build.prefixes[i], diagnostics); END;
				END;
				INC(nofBuilds);
			ELSE
				error := TRUE;
				diagnostics.Error(source, Diagnostics.Invalid, Diagnostics.Invalid, "Maximum number of builds exceeded");
			END;
			RETURN ~error;
		END AddBuild;

		PROCEDURE AddFile(CONST filename : ARRAY OF CHAR;  release : SET; package : Package;  pos : LONGINT);
		VAR file, f : File; pre, suf : Files.FileName;
		BEGIN
			ASSERT(package # NIL);
			NEW(file, SELF);
			COPY(filename, file.name);
			COPY(filename, file.uppercaseName);
			Strings.UpperCase(file.uppercaseName);

			SplitName(file.name, pre, file.module.name, suf);
			IF (pre = ReleasePrefix) THEN
				INCL(file.flags, HasReleasePrefix);
			END;
			IF (suf = "Mod") OR (suf="Mdf") OR (suf = "Mos") THEN
				INCL(file.flags, SourceCode);
				INC(nofSources);
				INC(package.nofSources);
			END;

			INC(package.nofFiles);
			file.package := package;
			file.release := release;
			file.pos := pos;

			IF (files = NIL) THEN
				files := file;
			ELSE (* append to list *)
				f := files;
				WHILE (f.next # NIL) DO f := f.next; END;
				f.next := file;
				file.prev := f;
			END;
			INC(nofFiles);
		END AddFile;

		PROCEDURE FindFile(CONST filename : ARRAY OF CHAR) : File;
		VAR file : File;
		BEGIN
			file := files;
			WHILE (file # NIL) & (file.name # filename) DO file := file.next; END;
			RETURN file;
		END FindFile;

		PROCEDURE FindFileCheckCase(CONST filename : ARRAY OF CHAR; VAR caseEqual : BOOLEAN) : File;
		VAR result, file : File; fn : Name;
		BEGIN
			result := NIL;
			COPY(filename, fn); Strings.UpperCase(fn);
			file := files;
			WHILE (file # NIL) & (result = NIL) DO
				IF (filename = file.name) THEN
					caseEqual := TRUE;
					result := file;
				ELSIF (fn = file.uppercaseName) THEN
					caseEqual := FALSE;
					result := file;
				END;
				file := file.next;
			END;
			RETURN result;
		END FindFileCheckCase;

		(* Called by the Parser after parsing is finished *)
		PROCEDURE Initialize(diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
		VAR build, package : LONGINT; message : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(diagnostics # NIL);
			FOR build := 0 TO LEN(builds)-1 DO
				IF (builds[build] # NIL) THEN
					GetReleaseSet(builds[build], builds[build].include);
					builds[build].files := files;
					builds[build].packages := packages;
					IF (builds[build].excludedPackages # NIL) THEN
						FOR package := 0 TO LEN(builds[build].excludedPackages)-1 DO
							IF (packages.FindPackage(builds[build].excludedPackages[package]^) = NIL) THEN
								error := TRUE;
								MakeMessage(message, "Excluded package '#' in build '#' does not exist",
									builds[build].excludedPackages[package]^,
									builds[build].name);
								diagnostics.Error(source, Diagnostics.Invalid, Diagnostics.Invalid, message);
							END;
						END;
					END;
				END;
			END;
		END Initialize;

	END Builds;

CONST
	(* Tokens*)
	PACKAGE = "PACKAGE";
	ARCHIVE = "ARCHIVE";
	SOURCE = "SOURCE";
	DESCRIPTION = "DESCRIPTION";

	OPENSECTION = "{";
	CLOSESECTION = "}";
	SEPARATOR = ",";
	ENDSECTION = "END";

	HEADER = "HEADER";
	VERSION = "VERSION";
	BUILDS = "BUILDS";
	INCLUDE="INCLUDE";
	tIMPORT = "IMPORT";
	COMPILER = "COMPILER";
	COMPILEOPTIONS = "COMPILEOPTIONS";
	LINKER = "LINKER";
	LINKEROPTIONS = "LINKEROPTIONS";
	TARGET = "TARGET";
	EXTENSION="EXTENSION";
	SYMBOLEXTENSION="SYMBOLEXTENSION";
	PATH="PATH";
	EXCLUDEPACKAGES = "EXCLUDEPACKAGES";
	DISABLED = "DISABLED";

TYPE

	Token = ARRAY 256 OF CHAR;

	Scanner = OBJECT
	VAR
		source: Name;
		reader : Streams.Reader;
		diagnostics : Diagnostics.Diagnostics;
		error : BOOLEAN;

		peekMode, peekBufferValid : BOOLEAN;
		peekToken : ARRAY 256 OF CHAR;
		peekError : BOOLEAN;

		pos : LONGINT;
		name : ARRAY 256 OF CHAR;

		PROCEDURE Error(pos : LONGINT; CONST msg, par1, par2 : ARRAY OF CHAR);
		VAR message : ARRAY 128 OF CHAR;
		BEGIN
			error := TRUE;
			MakeMessage(message, msg, par1, par2);
			diagnostics.Error(source, pos, Diagnostics.Invalid, message);
		END Error;

		PROCEDURE Check(CONST token : Token) : BOOLEAN;
		VAR temp : Token;
		BEGIN
			IF Get(temp) & (temp = token) THEN
				RETURN TRUE
			ELSE
				Error(reader.Pos(), "Expected '#' token", token, "");
				RETURN FALSE;
			END;
		END Check;

		PROCEDURE IsIdentifier(CONST token : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			RETURN
				(token # PACKAGE) & (token # ARCHIVE) & (token # SOURCE) & (token # DESCRIPTION) &
			   	(token # OPENSECTION) & (token # CLOSESECTION) & (token # ENDSECTION) &
			   	(token # SEPARATOR) & (token # BUILDS) & (token # HEADER) & (token # VERSION) &
			   	(token # INCLUDE) & (token # COMPILER) & (token # COMPILEOPTIONS) & (token # TARGET) & (token # EXTENSION) & (token # SYMBOLEXTENSION) &
			   	(token # PATH) & (token # EXCLUDEPACKAGES);
		END IsIdentifier;

		PROCEDURE GetIdentifier(VAR identifier : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			IF Get(identifier) THEN
				IF IsIdentifier(identifier) THEN
					RETURN TRUE;
				ELSE
					Error(pos, "Identifier expected but found token #", identifier, "");
				END;
			END;
			RETURN FALSE;
		END GetIdentifier;

		PROCEDURE Peek(VAR token : ARRAY OF CHAR);
		BEGIN
			IF (peekMode = FALSE) THEN
				IF Get(token) THEN
					peekMode := TRUE;
					peekError := FALSE;
					COPY(token, peekToken);
				ELSE
					peekError := TRUE;
					COPY("", peekToken);
				END;
			END;
			COPY(peekToken, token);
		END Peek;

		PROCEDURE Get(VAR token : ARRAY OF CHAR) : BOOLEAN;
		VAR delimiter, ch : CHAR; i : LONGINT; useDelimiter : BOOLEAN;
		BEGIN
			IF (peekMode) THEN
				COPY(peekToken, token);
				peekBufferValid := TRUE;
				peekMode := FALSE;
				IF (peekError) THEN
					Error(reader.Pos(), "ERROR", "", "");
				END;
				RETURN ~peekError;
			END;

			name := "";

			SkipComments;
			delimiter := reader.Peek(); useDelimiter := (delimiter = "'") OR (delimiter = '"');
			IF useDelimiter THEN reader.Char(ch); END;

			pos := reader.Pos();

			i := 0;
			REPEAT
				reader.Char(ch); (* Since we skipped the comments and whitespace, ch cannot be "#" or whitespace *)
				IF useDelimiter & (ch = delimiter) OR (ch=0X) THEN
				ELSE
					token[i] := ch; INC(i);
				END;

				IF (~useDelimiter & (ch # "{") & (ch # "}") & (ch # ",")) THEN
					ch := reader.Peek();
				END;
			UNTIL
				(i >= LEN(token)-1) OR ((reader.res = Streams.EOF) & (ch = 0X)) OR
				(~useDelimiter & (IsWhitespace(ch) OR (ch = "#") OR (ch ="{") OR (ch="}") OR (ch = ","))) OR
				(useDelimiter & (ch = delimiter));


			IF (i = 0) & (reader.res = Streams.EOF) THEN (* end of text *)
				RETURN FALSE
			ELSIF (i < LEN(token)) THEN
				token[i] := 0X;
				COPY(token, name);
				RETURN TRUE;
			ELSE
				Error(reader.Pos(), "Token too long", "", "");
				RETURN FALSE;
			END;
		END Get;

		PROCEDURE IsWhitespace(ch : CHAR) : BOOLEAN;
		BEGIN
			RETURN (ch <= " ");
		END IsWhitespace;

		PROCEDURE SkipComments;
		VAR ch : CHAR;
		BEGIN
			reader.SkipWhitespace;
			ch := reader.Peek();
			WHILE (ch = "#") DO reader.SkipLn; reader.SkipWhitespace; ch := reader.Peek(); END;
		END SkipComments;

		PROCEDURE &Init(CONST source: ARRAY OF CHAR; reader : Streams.Reader; diagnostics : Diagnostics.Diagnostics);
		BEGIN
			COPY (source, SELF.source);
			ASSERT((reader # NIL) & (diagnostics # NIL));
			SELF.reader := reader;
			SELF.diagnostics := diagnostics;
			peekMode := FALSE; peekToken := ""; peekError := FALSE;
			error := FALSE;
		END Init;

	END Scanner;

TYPE

	Parser = OBJECT
	VAR
		scanner : Scanner;
		diagnostics : Diagnostics.Diagnostics;
		log: Streams.Writer;
		error : BOOLEAN;

		currentPackage : Package;

		PROCEDURE Error(pos : LONGINT; CONST msg, par1, par2 : ARRAY OF CHAR);
		VAR message : ARRAY 128 OF CHAR;
		BEGIN
			error := TRUE;
			MakeMessage(message, msg, par1, par2);
			diagnostics.Error(scanner.source, pos, Diagnostics.Invalid, message);
		END Error;

		PROCEDURE Warning(pos : LONGINT; CONST msg, par1, par2 : ARRAY OF CHAR);
		VAR message : ARRAY 128 OF CHAR;
		BEGIN
			MakeMessage(message, msg, par1, par2);
			diagnostics.Warning(scanner.source, pos, Diagnostics.Invalid, message);
		END Warning;

		PROCEDURE IsFilename(CONST token : Token) : BOOLEAN;
		VAR i : LONGINT;
		BEGIN
			i := 1; (* don't allow filenames to start with "." *)
			WHILE (i < LEN(token)) & (token[i] # ".") & (token[i] # 0X) DO INC(i); END;
			RETURN (i < LEN(token)) & (token[i] = ".");
		END IsFilename;

		PROCEDURE Parse(VAR builds : Builds) : BOOLEAN;
		VAR token : Token; v1, v2 : ARRAY 16 OF CHAR;
		BEGIN
			IF builds = NIL THEN NEW(builds) END;
			COPY(scanner.source, builds.source);
			IF ParseHeader(builds) THEN
				IF (builds.version.major = VersionMajor) & (builds.version.minor <= VersionMinor) THEN
					IF ParseImport(builds) THEN (* load included sections *)
					END;
					IF ParseBuilds(builds) THEN END; (* optional *)
					LOOP
						currentPackage := ParsePackageHeader();
						IF (currentPackage # NIL) THEN
							IF builds.packages.Add(currentPackage) THEN
								IF ~ParsePackage(builds, token) THEN
									EXIT;
								END;
							ELSE
								Error(scanner.pos, "Package # is already defined", currentPackage.name, "");
								EXIT;
							END;
						ELSE
							EXIT;
						END;
						scanner.SkipComments;
						IF scanner.reader.Available() < 5 THEN EXIT; END;
					END;
					IF ~error THEN builds.Initialize(diagnostics, error); END;
				ELSE
					VersionToString(VersionMajor, VersionMinor, v1);
					VersionToString(builds.version.major, builds.version.minor, v2);
					Error(Diagnostics.Invalid, "Version mismatch, Release.Mod is version #, tool file is version #", v1, v2);
				END;
			END;
			ASSERT(builds # NIL);
			RETURN ~(error OR scanner.error);
		END Parse;

		(* Import = IMPORT Entries END whereas Entries = FileName *)
		PROCEDURE ParseImport(VAR builds : Builds) : BOOLEAN;
		VAR token : Token; ignore : BOOLEAN; filename: Files.FileName;
		BEGIN
			ASSERT(builds # NIL);
			scanner.Peek(token);
			IF (token = tIMPORT) THEN
				ignore := scanner.Get(token);
				LOOP
					scanner.Peek(token);
					IF (token = ENDSECTION) THEN
						ignore := scanner.Get(token);
						RETURN TRUE;
					ELSIF scanner.IsIdentifier(token) THEN  (* filename *)
						IF IsFilename(token) THEN
							COPY(token, filename);
							IF ~ParseBuildFile(filename, builds, log, diagnostics) THEN
								Error(scanner.pos, "Could not include #", filename, "")
							END;
						ELSE
							Error(scanner.pos, "No filename #",token,"");
							RETURN FALSE
						END;
						ignore := scanner.Get(token);
					END;
				END;
			END;
			RETURN FALSE;
		END ParseImport;


		(* Header = HEADER Entries END whereas Entries = VERSION VersionString *)
		PROCEDURE ParseHeader(builds : Builds) : BOOLEAN;
		VAR token : Token; ignore : BOOLEAN;

			PROCEDURE ParseVersionString(CONST string : ARRAY OF CHAR) : BOOLEAN;
			VAR strings : Strings.StringArray;
			BEGIN
				strings := Strings.Split(string, ".");
				IF (LEN(strings) = 2) THEN
					Strings.StrToInt(strings[0]^, builds.version.major);
					Strings.StrToInt(strings[1]^, builds.version.minor);
					RETURN TRUE;
				ELSE
					Error(scanner.pos, "Expected version string major.minor, found #", string, "");
					RETURN FALSE;
				END;
			END ParseVersionString;

		BEGIN
			ASSERT(builds # NIL);
			scanner.Peek(token);
			IF (token = HEADER) THEN
				ignore := scanner.Get(token);
				LOOP
					scanner.Peek(token);
					IF (token = ENDSECTION) THEN
						ignore := scanner.Get(token);
						RETURN TRUE;
					ELSIF (token = VERSION) THEN
						ignore := scanner.Get(token);
						IF scanner.Get(token) THEN
							IF ~ParseVersionString(token) THEN
								Error(scanner.pos, "Invalid version string: #", token, "");
								EXIT;
							END;
						ELSE
							Error(scanner.pos, "Version number expected", "", "");
							EXIT;
						END;
					ELSE
						Error(scanner.pos, "Expected # or # token", HEADER, ENDSECTION);
						EXIT;
					END;
				END;
			ELSE
				Error(scanner.pos, "# section expected", HEADER, "");
			END;
			RETURN FALSE;
		END ParseHeader;

		(* Builds = [ BUILDS {Build} END ] whereas Build = BuildName "{" prefix {" " perfix} "}" *)
		PROCEDURE ParseBuilds(builds : Builds) : BOOLEAN;
		VAR token : Token; build : BuildObj;
		BEGIN
			ASSERT(builds # NIL);
			scanner.Peek(token);
			IF  (token = BUILDS) THEN
				IF scanner.Get(token) THEN END; (* consume BUILDS *)
				LOOP
					scanner.Peek(token);
					IF (token = ENDSECTION) THEN
						IF scanner.Get(token) THEN END; (* consume token *)
						RETURN TRUE;
					ELSE
						build :=  ParseBuild();
						IF (build # NIL) THEN
							IF ~builds.AddBuild(build, diagnostics) THEN
								EXIT;
							END;
						ELSE
							EXIT;
						END;
					END;
				END;
			END;
			RETURN FALSE;
		END ParseBuilds;

		(* Build = BuildName "{" prefix {"," perfix} "}" *)
		PROCEDURE ParseBuild() : BuildObj;
		VAR
			token : Token; prefix : LONGINT;
			string : ARRAY 256 OF CHAR; stringArray : Strings.StringArray;
			compilerSet, compileOptionsSet, linkerSet, linkOptionsSet, targetSet, includeSet, excludePackagesSet, extensionSet, symbolsSet, pathSet, disabledSet  : BOOLEAN;
			build : BuildObj;

			PROCEDURE CheckOptions;
			BEGIN
				IF ~includeSet THEN Warning(scanner.pos, "# not set in build #", INCLUDE, build.name); END;
				IF ~compilerSet THEN Warning(scanner.pos, "# not set in build #", COMPILER, build.name); END;
				IF ~compileOptionsSet THEN Warning(scanner.pos, "# not set in build #", COMPILEOPTIONS, build.name); END;
				IF ~targetSet THEN Warning(scanner.pos, "# not set in build #", TARGET, build.name); END;
				IF ~extensionSet THEN Warning(scanner.pos, "# not set in build #", EXTENSION, build.name); END;
				IF ~symbolsSet THEN (* no warning since optional *) END;
				IF ~pathSet THEN Warning(scanner.pos, "# not set in build #", PATH, build.name); END;
				IF ~disabledSet THEN Warning(scanner.pos, "# not set in build #", DISABLED, build.name); END;
			END CheckOptions;

		BEGIN
			NEW(build);
			compilerSet := FALSE; compileOptionsSet := FALSE; linkerSet := FALSE; linkOptionsSet := FALSE; targetSet := FALSE; includeSet := FALSE;
			extensionSet := FALSE; symbolsSet := FALSE; pathSet := FALSE; excludePackagesSet := FALSE; disabledSet := FALSE;
			IF scanner.GetIdentifier(build.name) THEN
				build.position := scanner.pos;
				IF scanner.Check(OPENSECTION) THEN
					LOOP
						IF scanner.Get(token) THEN
							IF (token = CLOSESECTION) THEN
								CheckOptions;
								RETURN build;
							ELSIF (token = COMPILER) THEN
								IF compilerSet THEN Error(scanner.pos, "# already set in build #", COMPILER, build.name); ELSE compilerSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.compiler) THEN
									(* continue *)
								END;
							ELSIF (token = COMPILEOPTIONS) THEN
								IF compileOptionsSet THEN Error(scanner.pos, "# already set in build #", COMPILEOPTIONS, build.name); ELSE compileOptionsSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.compileOptions) THEN
									(* continue *)
								END;
							ELSIF (token = LINKER) THEN
								IF linkerSet THEN Error(scanner.pos, '# already set in build #', LINKER, build.name); ELSE linkerSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.linker) THEN
									(* continue *)
								END;
							ELSIF (token = LINKEROPTIONS) THEN
								IF linkOptionsSet THEN Error(scanner.pos, '# already set in build #', LINKEROPTIONS, build.name); ELSE linkOptionsSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.linkOptions) THEN
									(* continue *)
								END;
							ELSIF (token = TARGET) THEN
								IF targetSet THEN Error(scanner.pos, "# already set in build #", TARGET, build.name); ELSE targetSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.target) THEN
									(* continue *)
								END;
							ELSIF (token = EXTENSION) THEN
								IF extensionSet THEN Error(scanner.pos, "# already set in build #", EXTENSION, build.name); ELSE extensionSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.extension) THEN
									(* continue *)
								END;
							ELSIF (token = SYMBOLEXTENSION) THEN
								IF symbolsSet THEN Error(scanner.pos, "# already set in build #", SYMBOLEXTENSION, build.name); ELSE symbolsSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.symbolFileExtension) THEN
									(* continue *)
								END;
							ELSIF (token = PATH) THEN
								IF pathSet THEN Error(scanner.pos, "# already set in build #", PATH, build.name); ELSE pathSet := TRUE; END;
								IF ~scanner.GetIdentifier(build.path) THEN
									(* continue *)
								END;
							ELSIF (token = INCLUDE) THEN
								IF includeSet THEN Error(scanner.pos, "# already set in build #", INCLUDE, build.name); ELSE includeSet := TRUE; END;
								IF scanner.GetIdentifier(string) THEN
									stringArray := Strings.Split(string, " ");
									prefix := 0;
									IF LEN(stringArray) <= LEN(build.prefixes) THEN
										FOR prefix := 0 TO LEN(stringArray)-1 DO
											COPY(stringArray[prefix]^, build.prefixes[prefix]);
										END;
									ELSE
										Error(scanner.pos, "Maximum number of prefixes exceeded.", "", "");
									END;
								END;
							ELSIF (token = EXCLUDEPACKAGES) THEN
								IF excludePackagesSet THEN Error(scanner.pos, "# already set in build #", EXCLUDEPACKAGES, build.name);
								ELSE excludePackagesSet := TRUE;
								END;
								IF scanner.GetIdentifier(string) THEN
									Strings.TrimWS(string);
									IF (string # "") THEN
										build.excludedPackages := Strings.Split(string, " ");
									END;
								END;
							ELSIF (token = DISABLED) THEN
								IF disabledSet THEN Error(scanner.pos, "# already set in build #", DISABLED, build.name);
								ELSE disabledSet := TRUE;
								END;
								IF scanner.GetIdentifier(string) THEN
									Strings.TrimWS(string);
									Strings.UpperCase(string);
									IF (string = "TRUE") THEN
										build.disabled := TRUE;
									ELSIF (string = "FALSE") THEN
										build.disabled := FALSE;
									ELSE
										Warning(scanner.pos, "Wrong value for # in build #", DISABLED, build.name);
										build.disabled := TRUE;
									END;
								ELSE
									(* error reported by scanner.GetIdentifier *)
								END;
							ELSE
								IF includeSet & compilerSet & targetSet & extensionSet & pathSet THEN
									Error(scanner.pos, "Expected # or # token", CLOSESECTION, EXCLUDEPACKAGES);
								ELSE
									Error(scanner.pos, "Expected INCLUDE, COMPILER or COMPILEOPTIONS token", "", "");
								END;
								EXIT;
							END;
						ELSE
							EXIT;
						END;
					END;
				END;
			END;
			RETURN NIL;
		END ParseBuild;

		(* PackageHeader = PACKAGE PackageName ARCHIVE ArchiveName SOURCE SourceArchiveName DESCRIPTION description *)
		PROCEDURE ParsePackageHeader() : Package;
		VAR package : Package; name, archive, source  : ARRAY 32 OF CHAR; description : ARRAY 256 OF CHAR; position : LONGINT;
		BEGIN
			package := NIL;
			IF scanner.Check(PACKAGE) THEN
				position := scanner.pos;
				IF scanner.GetIdentifier(name) &
				  	scanner.Check(ARCHIVE) & scanner.GetIdentifier(archive) &
				  	scanner.Check(SOURCE) & scanner.GetIdentifier(source) &
				  	scanner.Check(DESCRIPTION) & scanner.GetIdentifier(description)
				THEN
				  	NEW(package, name, archive, source, description, position);
				END;
			END;
			RETURN package;
		END ParsePackageHeader;

		(* Package = { FileList | Prefix "{" FileList "}" }
			Prefix = prefix {"," prefix}
			FileList = filename {" " filename} *)
		PROCEDURE ParsePackage(builds : Builds;  VAR token : Token) : BOOLEAN;
		VAR currentRelease : SET; index : LONGINT; pos : LONGINT; nbr : ARRAY 8 OF CHAR; caseEqual : BOOLEAN; file : File;
		BEGIN
			currentRelease := All;
			LOOP
				IF scanner.Get(token) THEN
					index := builds.GetPrefixIndex(token);
					IF (index >= 0) THEN
						IF (currentRelease = All) THEN
							currentRelease := {};
							IF ~ParseBuildPrefixes(builds, token, currentRelease, pos) THEN
								RETURN FALSE;
							END;
						ELSE
							Strings.IntToStr(pos, nbr);
							Error(scanner.pos, "Expected closing brace for tag at position #", nbr, "");
							RETURN FALSE;
						END;
					ELSIF (token = CLOSESECTION) THEN
						IF (currentRelease # All) THEN
							currentRelease := All;
						ELSE
							Error(scanner.pos, "No matching opening bracket", "", "");
							RETURN FALSE;
						END;
					ELSIF (token = ENDSECTION) THEN
						RETURN TRUE;
					ELSIF scanner.IsIdentifier(token) THEN  (* filename *)
						IF IsFilename(token) THEN
							file := builds.FindFileCheckCase(token, caseEqual);
							IF (file # NIL) THEN
								IF caseEqual THEN
									Warning(scanner.pos, "Duplicate file found: #", token, "");
								ELSE
									Warning(scanner.pos, "Same file name with different case found: # vs #", token, file.name);
								END;
							END;
							builds.AddFile(token, currentRelease, currentPackage, scanner.pos);
						ELSE
							diagnostics.Warning(scanner.source, scanner.pos, Diagnostics.Invalid, "Expected filename (not file extension?)");
						END;
					ELSE
						Error(scanner.pos, "Expected identifier, found #", token, "");
					END;
				ELSE
					EXIT;
				END;
			END;
			RETURN (currentRelease = All);
		END ParsePackage;

		PROCEDURE ParseBuildPrefixes(builds : Builds; VAR token : Token; VAR release : SET; VAR pos : LONGINT) : BOOLEAN;
		VAR index : LONGINT; message : ARRAY 128 OF CHAR;
		BEGIN
			index := builds.GetPrefixIndex(token);
			IF (index >= 0) THEN
				INCL(release, index);
			ELSE
				MakeMessage(message, "Unknown build prefix #", token, "");
				diagnostics.Warning(scanner.source, scanner.pos, Diagnostics.Invalid, message);
			END;
			IF scanner.Get(token) THEN
				IF (token = OPENSECTION) THEN
					RETURN TRUE;
				ELSIF (token = SEPARATOR) THEN
					RETURN scanner.Get(token) & ParseBuildPrefixes(builds, token, release, pos);
				ELSE
					Error(scanner.pos, "Expected '{' or ',' token", "", "");
					RETURN FALSE;
				END;
			ELSE
				RETURN FALSE;
			END;
		END ParseBuildPrefixes;

		PROCEDURE &Init(scanner : Scanner; log: Streams.Writer; diagnostics : Diagnostics.Diagnostics);
		BEGIN
			ASSERT((scanner # NIL) & (diagnostics # NIL));
			SELF.scanner := scanner;
			SELF.diagnostics := diagnostics;
			SELF.log := log
		END Init;

	END Parser;

PROCEDURE GetModuleInfo(
					in : Streams.Reader;
					VAR mi : ModuleInfo;
					CONST source, filename : ARRAY OF CHAR;
					errorPosition : LONGINT;
					diagnostics : Diagnostics.Diagnostics;
					VAR error : BOOLEAN);

	PROCEDURE SkipComments(in : Streams.Reader);
	VAR level, oldLevel, oldPosition : LONGINT; ch, nextCh : CHAR;
	BEGIN
		ASSERT((in # NIL) & (in.CanSetPos()));
		level := 0;
		REPEAT
			ASSERT(level >= 0);
			in.SkipWhitespace;
			oldLevel := level;
			oldPosition := in.Pos();
			in.Char(ch); nextCh := in.Peek();
			IF (ch = "(") & (nextCh = "*") THEN
				INC(level); in.Char(ch);
			ELSIF (level > 0) & (ch = "*") & (nextCh = ")") THEN
				DEC(level); in.Char(ch);
			ELSIF (level = 0) THEN
				in.SetPos(oldPosition);
			END;
		UNTIL ((level = 0) & (oldLevel = 0)) OR (in.res # Streams.Ok);
	END SkipComments;

	PROCEDURE SkipProperties (in : Streams.Reader);
	VAR ch : CHAR;
	BEGIN
		in.SkipWhitespace;
		ch := in.Peek();
		IF ch = "{" THEN
			in.Char(ch);
			REPEAT
				in.Char(ch);
			UNTIL (ch = "}") OR (in.res # Streams.Ok)
		END;
	END SkipProperties;


	PROCEDURE GetIdentifier(in : Streams.Reader; VAR identifier : ARRAY OF CHAR);
	VAR ch : CHAR; i : LONGINT;
	BEGIN
		ASSERT(in # NIL);
		i := 0;
		ch := in.Peek();
		WHILE (('a' <= ch) & (ch <= 'z')) OR (('A' <= ch) & (ch <= 'Z')) OR (('0' <= ch) & (ch <= '9')) OR (ch = "_") & (i < LEN(identifier) - 1) DO
			in.Char(identifier[i]); INC(i);
			ch := in.Peek();
		END;
		identifier[i] := 0X;
	END GetIdentifier;

	PROCEDURE GetContext(in : Streams.Reader; ch1, ch2 : CHAR; VAR context : ARRAY OF CHAR; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
	VAR message : ARRAY 512 OF CHAR; ch : CHAR;
	BEGIN
		ASSERT((in # NIL) & (diagnostics # NIL));
		SkipComments(in);
		ch := in.Peek();
		IF (Strings.UP(ch) = ch1) THEN
			in.Char(ch); in.Char(ch);
			IF Strings.UP(ch) = ch2 THEN
				SkipComments(in);
				GetIdentifier(in, context); (* ignore context identifier *)
				IF (context = "") THEN
					error := TRUE;
					MakeMessage(message, "Context identifier missing in file #", filename, "");
					diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
				END;
				SkipComments(in);
			ELSE
				error := TRUE;
				MakeMessage(message, "Expected 'IN' keyword in file #", filename, "");
				diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
			END;
		END;
	END GetContext;

	PROCEDURE GetModuleNameAndContext(in : Streams.Reader; VAR name, context : Name; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
	VAR token, message : ARRAY 512 OF CHAR; ch : CHAR;
	BEGIN
		ASSERT((in # NIL) & (diagnostics # NIL) & (~error));
		name := ""; COPY(Modules.DefaultContext, context);
		SkipComments(in);
		in.SkipWhitespace; in.String(token); Strings.UpperCase(token);
		IF (token = "MODULE") OR (token = "CELLNET") THEN
			SkipComments(in);
			SkipProperties(in);
			SkipComments(in);
			GetIdentifier(in, name);
			IF (name # "") THEN
				SkipComments(in);
				GetContext(in, "I", "N", context, diagnostics, error);
				in.Char(ch);
				IF ~error & (ch # ";") THEN
					error := TRUE;
					MakeMessage(message, "Expected semicolon after module identifier in file #", filename, "");
					diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
				END;
			ELSE
				error := TRUE;
				MakeMessage(message, "Module identifier missing in file #", filename, "");
				diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
			END;
		ELSE
			error := TRUE;
			MakeMessage(message, "MODULE keyword missing in file #, first token is #", filename, token);
			diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
		END;
	END GetModuleNameAndContext;

	PROCEDURE GetImport(in : Streams.Reader; VAR import, context : ARRAY OF CHAR; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
	VAR message : ARRAY 512 OF CHAR;
	BEGIN
		ASSERT((in # NIL) & (diagnostics # NIL));
		SkipComments(in);
		GetIdentifier(in, import);
		IF (import # "") THEN
			GetContext(in, ':', '=', import, diagnostics, error);
			IF ~error THEN GetContext(in, "I", "N", context, diagnostics, error); END;
		ELSE
			error := TRUE;
			MakeMessage(message, "Identifier expected in import section of file #", filename, "");
			diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
		END;
	END GetImport;

	PROCEDURE GetImports(in : Streams.Reader; VAR mi : ModuleInfo; diagnostics : Diagnostics.Diagnostics; VAR error : BOOLEAN);
	VAR string, import, context, message : ARRAY 256 OF CHAR; ch : CHAR;
	BEGIN
		ASSERT((in # NIL) & (in.CanSetPos())  & (diagnostics  #NIL) & (~error));
		SkipComments(in);
		GetIdentifier(in, string); Strings.UpperCase(string);
		IF (string = "IMPORT") THEN
			LOOP
				COPY(mi.context, context);
				GetImport(in, import, context, diagnostics, error);
				IF ~error THEN
					IF (import = "SYSTEM") OR (import = "system") THEN
						INCL(mi.flags, ImportsSystem);
					ELSIF (mi.nofImports < LEN(mi.imports)) THEN
						CreateContext(import, context);
						COPY(import, mi.imports[mi.nofImports]);
						INC(mi.nofImports);
					ELSE
						error := TRUE;
						MakeMessage(message, "Maximum number of supported imports exceeded in module #", filename, "");
						diagnostics.Error(source, Diagnostics.Invalid, Diagnostics.Invalid, message);
						EXIT;
					END;

					SkipComments(in);
					in.Char(ch);
					IF (ch = ",") THEN
						(* continue *)
					ELSIF (ch = ";") THEN
						EXIT;
					ELSE
						error := TRUE;
						MakeMessage(message, "Parsing import section of module # failed", filename, "");
						diagnostics.Error(source, errorPosition, Diagnostics.Invalid, message);
						EXIT;
					END;
				ELSE
					EXIT;
				END;
			END;
		ELSE
			mi.nofImports := 0;
		END;
	END GetImports;

BEGIN
	ASSERT((in # NIL) & (diagnostics # NIL));
	error := FALSE;
	GetModuleNameAndContext(in, mi.name, mi.context, diagnostics, error);
	IF ~error THEN
		ASSERT(mi.nofImports  = 0);
		GetImports(in, mi, diagnostics, error);
	END;
END GetModuleInfo;

PROCEDURE VersionToString(major, minor : LONGINT; VAR string : ARRAY OF CHAR);
VAR temp : ARRAY 16 OF CHAR;
BEGIN
	Strings.IntToStr(major, string); Strings.Append(string, ".");
	Strings.IntToStr(minor, temp); Strings.Append(string, temp);
END VersionToString;

(** SplitName - Split a filename into prefix, middle and suffix, seperated by ".". The prefix may contain dots ("."). *)

PROCEDURE SplitName(CONST name: ARRAY OF CHAR;  VAR pre, mid, suf: ARRAY OF CHAR);
VAR i, j, d0, d1: LONGINT;
BEGIN
	i := 0;  d0 := -1;  d1 := -1;
	WHILE name[i] # 0X DO
		IF name[i] = "." THEN
			d0 := d1;
			d1 := i
		END;
		INC(i)
	END;
	i := 0;
	IF (d0 # -1) & (d1 # d0) THEN (* have prefix *)
		WHILE i # d0 DO pre[i] := name[i]; INC(i) END
	ELSE
		d0 := -1
	END;
	pre[i] := 0X;
	i := d0+1;  j := 0;
	WHILE (name[i] # 0X) & (i # d1) DO mid[j] := name[i];  INC(i);  INC(j) END;
	mid[j] := 0X;  j := 0;
	IF d1 # -1 THEN
		i := d1+1;
		WHILE name[i] # 0X DO suf[j] := name[i];  INC(i);  INC(j) END
	END;
	suf[j] := 0X
END SplitName;

PROCEDURE CreateContext (VAR name: ARRAY OF CHAR; CONST context: ARRAY OF CHAR);
VAR temp: Name;
BEGIN
	IF context # Modules.DefaultContext THEN
		COPY (name, temp);
		COPY (context, name);
		Strings.Append (name, ".");
		Strings.Append (name, temp);
	END;
END CreateContext;

PROCEDURE MakeMessage(VAR msg : ARRAY OF CHAR; CONST string, par0, par1 : ARRAY OF CHAR);
VAR count, m, i, j : LONGINT; par : ARRAY 128 OF CHAR;
BEGIN
	i := 0; m := 0; j := 0;
	FOR count := 0 TO 3 DO
		WHILE (m < LEN(msg)-1) & (i < LEN(string)) & (string[i] # "#")  & (string[i] # 0X) DO
			msg[m] := string[i]; INC(m); INC(i);
		END;
		IF (string[i] = "#") THEN
			INC(i); j := 0;
			IF (count = 0) THEN COPY(par0, par);
			ELSIF (count = 1) THEN COPY(par1, par)
			ELSE par[0] := 0X;
			END;
			WHILE (m < LEN(msg)-1) & (j < LEN(par)) & (par[j] # 0X) DO
				msg[m] := par[j]; INC(m); INC(j);
			END;
		END;
	END;
	msg[m] := 0X;
END MakeMessage;

PROCEDURE GetReader(file : File; diagnostics : Diagnostics.Diagnostics) : Streams.Reader;
VAR
	reader : Streams.Reader;
	fileReader : Files.Reader; ch1, ch2 : CHAR; offset : LONGINT;
	text : Texts.Text; textReader : TextUtilities.TextReader; format, res : LONGINT;
	message : ARRAY 256 OF CHAR;
BEGIN
	ASSERT((file # NIL) & (diagnostics # NIL));
	reader := NIL;
	IF OptimizedLoads THEN
		IF (file.file = NIL) THEN file.file := Files.Old(file.name); END;
		IF (file.file # NIL) THEN
			Files.OpenReader(fileReader, file.file, 0);
			fileReader.Char(ch1);
			fileReader.Char(ch2);
			IF (ch1= 0F0X) & (ch2 = 01X) THEN (* formatted Oberon text, skip formatting information *)
				fileReader.RawLInt(offset);
				fileReader.SetPos(offset);
			ELSE
				fileReader.SetPos(0);
			END;
			reader := fileReader;
		ELSE
			MakeMessage(message, "Could not open file #", file.name, "");
			diagnostics.Error(file.name, file.pos, Diagnostics.Invalid, message);
		END;
	END;
	IF (reader = NIL) THEN
		NEW(text);
		TextUtilities.LoadAuto(text, file.name, format, res);
		IF (res = 0) THEN
			NEW(textReader, text);
			reader := textReader;
		ELSE
			MakeMessage(message, "Could not open file # (Package = )", file.name, "");
			diagnostics.Error(file.name, file.pos, Diagnostics.Invalid, message);
		END;
	END;
	RETURN reader;
END GetReader;

PROCEDURE CallCommand(CONST command, arguments : ARRAY OF CHAR; context : Commands.Context);
VAR
	newContext : Commands.Context; arg : Streams.StringReader;
	msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	NEW(arg, 256); arg.Set(arguments);
	NEW(newContext, NIL, arg, context.out, context.error, context.caller);
	Commands.Activate(command, newContext, {Commands.Wait}, res, msg);
	IF (res #Commands.Ok) THEN
		context.error.String(msg); context.error.Ln;
	END;
END CallCommand;

PROCEDURE ParseBuildDescription*(text : Texts.Text; CONST source: ARRAY OF CHAR; VAR builds : Builds;  log: Streams.Writer; diagnostics : Diagnostics.Diagnostics) : BOOLEAN;
VAR
	parser : Parser; scanner : Scanner;
	reader : Streams.StringReader;
	buffer : POINTER TO ARRAY OF CHAR;
	length : LONGINT;
BEGIN
	ASSERT((text # NIL) & (diagnostics # NIL));
	text.AcquireRead;
	length := text.GetLength();
	text.ReleaseRead;
	IF length = 0 THEN length := 1 END;
	NEW(buffer, length);
	TextUtilities.TextToStr(text, buffer^);
	NEW(reader, LEN(buffer)); reader.SetRaw(buffer^, 0, LEN(buffer));
	NEW(scanner, source, reader, diagnostics);
	NEW(parser, scanner, log, diagnostics);
	RETURN parser.Parse(builds);
END ParseBuildDescription;

PROCEDURE ParseBuildFile*(
	CONST filename : Files.FileName;
	VAR builds : Builds;
	log: Streams.Writer;
	diagnostics : Diagnostics.Diagnostics
	) : BOOLEAN;
VAR text : Texts.Text; format, res : LONGINT; message : ARRAY 256 OF CHAR;
BEGIN
	log.String("Loading package description file "); log.String(filename); log.String(" ... ");
	log.Update;
	NEW(text);
	TextUtilities.LoadAuto(text, filename, format, res);
	IF (res = 0) THEN
		IF ParseBuildDescription(text, filename, builds, log, diagnostics) THEN
			log.String("done."); log.Ln;
			RETURN TRUE;
		ELSE
			log.Ln;
			RETURN FALSE;
		END;
	ELSE
		builds := NIL;
		MakeMessage(message, "Could not open file #", filename, "");
		diagnostics.Error("", Diagnostics.Invalid, Diagnostics.Invalid, message);
		RETURN FALSE;
	END;
END ParseBuildFile;

PROCEDURE ParseText(
	text : Texts.Text;
	CONST source: ARRAY OF CHAR;
	pos: LONGINT; (* ignore *)
	CONST pc, opt: ARRAY OF CHAR;
	log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
VAR
	options : POINTER TO  ARRAY OF CHAR;
	builds : Builds;
BEGIN
	NEW(options,LEN(opt));
	ASSERT((text # NIL) & (diagnostics # NIL));
	error := ~ParseBuildDescription(text, source, builds, log, diagnostics);
	IF ~error THEN
		COPY(opt, options^);
		Strings.TrimWS(options^);
		IF (builds # NIL) & (options^ = "\check") THEN
			builds.CheckAll(log, diagnostics);
		END;
	END;
	IF error THEN
		log.String(" not done");
	ELSE
		log.String(" done");
	END;
	log.Update;
END ParseText;

PROCEDURE CheckBuilds(builds : Builds; nofWorkers : LONGINT; context : Commands.Context; diagnostics : Diagnostics.DiagnosticsList);
VAR
	build : LONGINT; ignore : Streams.StringWriter; error, ignoreError, checkAll : BOOLEAN;

	PROCEDURE CreateRamDisk(context : Commands.Context) : BOOLEAN;
	VAR res : LONGINT; msg : ARRAY 128 OF CHAR; fs : Files.FileSystem;
	BEGIN
		Commands.Call("FSTools.Mount CHECKBUILDS RamFS 500000 4096", {Commands.Wait}, res, msg);
		IF (res # Commands.Ok) THEN
			context.error.String(msg); context.error.Ln;
		END;
		fs := Files.This("CHECKBUILDS");
		RETURN fs # NIL;
	END CreateRamDisk;

	PROCEDURE UnmountRamDisk(context : Commands.Context);
	VAR res : LONGINT; msg : ARRAY 128 OF CHAR;
	BEGIN
		Commands.Call("FSTools.Unmount CHECKBUILDS", {Commands.Wait}, res, msg);
		IF (res # Commands.Ok) THEN
			context.error.String(msg); context.error.Ln;
		END;
	END UnmountRamDisk;

	PROCEDURE DeleteFiles(CONST pattern : ARRAY OF CHAR);
	VAR
		enum : Files.Enumerator; flags : SET; time, date, size : LONGINT; name : Files.FileName;
		res : LONGINT;
	BEGIN
		NEW(enum); enum.Open(pattern, {});
		WHILE enum.GetEntry(name, flags, time, date, size) DO
			Files.Delete(name, res);
		END;
		enum.Close;
	END DeleteFiles;

	PROCEDURE DoCheckAll(builds : Builds) : BOOLEAN;
	VAR i : LONGINT; all : BOOLEAN;
	BEGIN
		ASSERT(builds # NIL);
		all := TRUE;
		WHILE all & (i < LEN(builds.builds)) & (builds.builds[i] # NIL) DO
			all := builds.builds[i].marked;
			INC(i);
		END;
		RETURN all;
	END DoCheckAll;

BEGIN
	ASSERT((builds # NIL) & (context # NIL) &(diagnostics # NIL));
	checkAll := DoCheckAll(builds);
	IF checkAll THEN
		builds.CheckAll(context.out, diagnostics);
	END;
	IF (diagnostics.nofErrors = 0) THEN
		IF CreateRamDisk(context) THEN
			IF (diagnostics.nofErrors = 0) THEN
				NEW(ignore, 1);
				WHILE (build < LEN(builds.builds)) & (builds.builds[build] # NIL) DO
					diagnostics.Reset;
					IF ~checkAll OR ~builds.builds[build].disabled THEN
						error := FALSE;
						IF ~checkAll & builds.builds[build].marked THEN
							builds.builds[build].CheckFiles(diagnostics);
							builds.builds[build].CheckModules(diagnostics, error);
						END;
						IF ~error & builds.builds[build].marked THEN
							COPY("CHECKBUILDS:", builds.builds[build].path);
							(*
							COPY("Obt", builds.builds[build].extension);
							COPY("386", builds.builds[build].target);
							*)
							builds.builds[build].Compile(nofWorkers, context.out, context.error, FALSE, diagnostics, ignoreError);
							DeleteFiles("CHECKBUILDS:*.Obw");
							DeleteFiles("CHECKBUILDS:*.Obt");
							DeleteFiles("CHECKBUILDS:*.Obx");
							DeleteFiles("CHECKBUILDS:*.Sym");
							DeleteFiles("CHECKBUILDS:*.Gof");
						ELSE
							diagnostics.ToStream(context.out, Diagnostics.All);
						END;
					ELSE
						context.out.String("Build "); context.out.String(builds.builds[build].name);
						context.out.String(" is disabled."); context.out.Ln;
					END;
					context.out.Update; context.error.Update;
					INC(build);
				END;
				diagnostics.Reset; (* all error messages already shown *)
			ELSE
				diagnostics.ToStream(context.error, Diagnostics.All); context.error.Ln;
			END;
			UnmountRamDisk(context);
		ELSE
			context.error.String("Could not create RAM disk"); context.error.Ln;
		END;
	ELSE
		diagnostics.ToStream(context.out, Diagnostics.All);
	END;
END CheckBuilds;

(** Find files that match the filemask but are not listed in the build description file *)
PROCEDURE CheckFiles*(context : Commands.Context); (** [Options] filemask ~*)
VAR
	options : Options.Options; diagnostics : Diagnostics.Diagnostics;
	builds : Builds;
	buildFile, mask, fullname, path, filename : Files.FileName;
	enumerator : Files.Enumerator;
	flags : SET;
	ignore : LONGINT;
BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);
	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, buildFile);
		IF options.GetString("file", buildFile) THEN END;

		IF context.arg.GetString(mask) THEN
			NEW(diagnostics);
			IF ParseBuildFile(buildFile, builds, context.out, diagnostics) THEN
				NEW(enumerator); enumerator.Open(mask, {});
				WHILE enumerator.GetEntry(fullname, flags, ignore, ignore, ignore) DO
					IF ~(Files.Directory IN flags) THEN
						Files.SplitPath(fullname, path, filename);
						IF (builds.FindFile(filename) = NIL) THEN
							context.out.String(filename); context.out.Ln;
						END;
					END;
				END;
				enumerator.Close;
			END;
		ELSE
			context.error.String("Expected mask argument."); context.error.Ln;
		END;
	END;
END CheckFiles;

(** Find the text position where the specified file could be inserted into the build description file *)
PROCEDURE FindPosition*(context : Commands.Context); (** [Options] buildname modulename ~ *)
VAR
	builds : Builds; build : BuildObj;
	buildFile, filename : Files.FileName; buildName : Name;
	diagnostics : Diagnostics.DiagnosticsList;
	position : LONGINT;
	options : Options.Options;
BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);

	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, buildFile);
		IF options.GetString("file", buildFile) THEN END;

		context.arg.SkipWhitespace; context.arg.String(buildName);
		context.arg.SkipWhitespace; context.arg.String(filename);
		IF (buildName # "") & (filename # "") THEN
			NEW(diagnostics);
			IF ParseBuildFile(buildFile, builds, context.out, diagnostics) THEN
				build := builds.GetBuild(buildName);
				IF (build # NIL) THEN
					position := build.FindPosition(filename, diagnostics);
					IF (position # -1) THEN
						context.out.String("First text position where the file "); context.out.String(filename);
						context.out.String(" could be inserted: "); context.out.Int(position, 0); context.out.Ln;
					ELSE
						diagnostics.ToStream(context.error, {0..31}); context.error.Ln;
					END;
				ELSE
					context.error.String("Build "); context.error.String(buildName); context.error.String(" not found");
					context.error.Update;
				END;
			ELSE
				diagnostics.ToStream(context.error, {0..31}); context.error.Ln;
			END;
		ELSE
			context.error.String("Usage: Release.FindPosition Release.Tool [options] buildname filename ~ ");
		END;
	END;
END FindPosition;

(** Analyze the builds *)
PROCEDURE Analyze*(context : Commands.Context); (** [Options] ~ *)
VAR filename : Files.FileName; builds : Builds; diagnostics : Diagnostics.DiagnosticsList; options : Options.Options;
BEGIN
	NEW(options);
	options.Add("d", "details", Options.Flag);
	options.Add("f", "file", Options.String);

	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, filename);
		IF options.GetString("file", filename) THEN END;

		IF (filename # "") THEN
			NEW(diagnostics);
			IF ParseBuildFile(filename, builds, context.out, diagnostics) THEN
				builds.Show(context.out, options.GetFlag("details"));
			ELSE
				diagnostics.ToStream(context.error, Diagnostics.All); context.error.Ln;
			END;
		ELSE
			context.error.String("Usage: Release.Analyze [options]  ~"); context.error.Ln;
		END;
	END;
END Analyze;

(** Build specified build (or all of none specified) to a RAM disk *)
PROCEDURE Check*(context : Commands.Context); (** [Options] {buildname} ~ *)
VAR
	filename : Files.FileName; builds : Builds; diagnostics : Diagnostics.DiagnosticsList;
	options : Options.Options; nofWorkers : LONGINT;

	PROCEDURE MarkBuilds(context : Commands.Context; builds : Builds) : BOOLEAN;
	VAR build : BuildObj; name : Name; nofMarked, i : LONGINT; error : BOOLEAN;
	BEGIN
		ASSERT((context # NIL) & (builds # NIL));
		nofMarked := 0;
		REPEAT
			name := "";
			context.arg.SkipWhitespace; context.arg.String(name);
			Strings.TrimWS(name);
			IF (name # "") THEN
				build := builds.GetBuild(name);
				IF (build # NIL) THEN
					INC(nofMarked);
					build.marked := TRUE;
				ELSE
					error := TRUE;
					context.error.String("Build "); context.error.String(name);
					context.error.String(" not found."); context.error.Ln;
				END;
			END;
		UNTIL (name = "");
		IF ~error & (nofMarked = 0) THEN
			FOR i := 0 TO LEN(builds.builds) - 1 DO
				IF (builds.builds[i] # NIL) THEN builds.builds[i].marked := TRUE; END;
			END;
		END;
		RETURN ~error;
	END MarkBuilds;

BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);
	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, filename);
		IF options.GetString("file", filename) THEN END;

		IF (filename # "") THEN
			NEW(diagnostics);
			IF ParseBuildFile(filename, builds, context.out, diagnostics) THEN
				IF MarkBuilds(context, builds) THEN
					IF ~options.GetInteger("workers", nofWorkers) THEN nofWorkers := 0; END;
					CheckBuilds(builds, nofWorkers, context, diagnostics);
				END;
			ELSE
				diagnostics.ToStream(context.error, Diagnostics.All); context.error.Ln;
			END;
		ELSE
			context.error.String('Usage: Release.Check [options] ~'); context.error.Ln;
		END;
	END;
END Check;

PROCEDURE CheckDiagnostics(diagnostics : Diagnostics.DiagnosticsList; warnings: BOOLEAN; out : Streams.Writer) : BOOLEAN;
BEGIN
	ASSERT((diagnostics # NIL) & (out # NIL));
	IF (diagnostics.nofErrors = 0) & (diagnostics.nofMessages > 0) THEN
		IF warnings THEN diagnostics.ToStream(out, Diagnostics.All)
		ELSE diagnostics.ToStream(out, {Diagnostics.TypeInformation, Diagnostics.TypeError})
		END;

		out.Update;
		diagnostics.Reset;
	END;
	RETURN diagnostics.nofErrors = 0;
END CheckDiagnostics;

PROCEDURE ImportInformation(mode : LONGINT; context : Commands.Context);
VAR
	options : Options.Options; diagnostics : Diagnostics.DiagnosticsList;
	builds : Builds; build : BuildObj;
	filename : Files.FileName;
	modulename : Modules.Name;
	buildname : Name;
	error : BOOLEAN;
BEGIN
	NEW(options);
	options.Add("f", "file", Options.String);
	options.Add(0X, "exclude", Options.String);

	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("file", filename) THEN COPY(DefaultPackagesFile, filename); END;
		modulename := "";
		context.arg.SkipWhitespace; context.arg.String(buildname);
		context.arg.SkipWhitespace; context.arg.String(modulename);
		IF (modulename # "") THEN
			NEW(diagnostics);
			IF ParseBuildFile(filename, builds, context.out, diagnostics) THEN
				IF CheckDiagnostics(diagnostics, FALSE, context.out) THEN
					build := builds.GetBuild(buildname);
					IF (build # NIL) THEN
						build.SetOptions(options);
						build.DoChecks(context.out, diagnostics, error);
						IF ~error THEN
							build.AnalyzeDependencies(context.out);
							build.ShowDependentModules(modulename, mode, context.out);
							context.out.Ln; context.out.Update;
						END;
					ELSE
						context.out.String("Build "); context.out.String(buildname); context.out.String(" not found");
						context.out.Ln;
					END;
				END;
			END;
			IF (diagnostics.nofMessages > 0) THEN
				diagnostics.ToStream(context.out, Diagnostics.All);
			END;
		ELSE
			context.out.String("Usage: Release.WhoImports [options] buildname modulename ~"); context.out.Ln;
		END;
	END;
END ImportInformation;

PROCEDURE WhoImports*(context : Commands.Context);
BEGIN
	ImportInformation(Mode_ShowImporting, context);
END WhoImports;

PROCEDURE RequiredModules*(context : Commands.Context);
BEGIN
	ImportInformation(Mode_ShowImported, context);
END RequiredModules;

PROCEDURE Rebuild*(context : Commands.Context); (** [Options] buildname {filenames} ~ *)
VAR
	options : Options.Options;
	diagnostics : Diagnostics.DiagnosticsList;
	builds : Builds; build : BuildObj;
	packagename, filename, fullname : Files.FileName;
	nofNewMarks, nofMarks : LONGINT;
	inBuild : BOOLEAN;
	buildname : ARRAY 32 OF CHAR;
	start0 : Dates.DateTime;
	error : BOOLEAN;
	nofWorkers, res : LONGINT;
BEGIN
	NEW(options);
	options.Add("b", "build", Options.Flag);
	options.Add("c", "compiler", Options.String);
	options.Add("e", "extension", Options.String);
	options.Add("f", "file", Options.String);
	options.Add("o", "options", Options.String);
	options.Add("p", "path", Options.String);
	options.Add("t", "target", Options.String);
	options.Add("v", "verbose", Options.Flag);
	options.Add("w", "workers", Options.Integer);
	options.Add("y", "", Options.Flag);

	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, packagename);
		IF options.GetString("file", packagename) THEN END;

		context.arg.SkipWhitespace; context.arg.String(buildname);

		IF (packagename # "") & (buildname # "") THEN
			start0 := Dates.Now();
			NEW(diagnostics);
			IF ParseBuildFile(packagename, builds, context.out, diagnostics) THEN
				build := builds.GetBuild(buildname);
				IF (build # NIL) THEN
					IF build.disabled THEN
						context.out.String("Warning: Build "); context.out.String(build.name);
						context.out.String(" is disabled."); context.out.Ln;
						context.out.Update;
					END;
					build.SetOptions(options);
					build.DoChecks(context.out, diagnostics, error);

					IF CheckDiagnostics(diagnostics, FALSE, context.out) & ~error THEN

						build.AnalyzeDependencies(context.out);
						build.ClearMarks;

						filename := ""; error := FALSE; nofMarks := 0;
						LOOP
							context.arg.SkipWhitespace; context.arg.String(filename);
							IF (filename = "") THEN EXIT; END;
							IF (Files.Old(filename) # NIL) THEN
								build.MarkFiles(filename, inBuild, nofNewMarks);
								IF inBuild THEN
									nofMarks := nofMarks + nofNewMarks;
								ELSE
									context.out.String("Warning: No depenencies on file "); context.out.String(filename);
									context.out.String("."); context.out.Ln; context.out.Update;
								END;
							ELSE
								context.out.String("Error: File "); context.out.String(filename);
								context.out.String(" does not exist."); context.out.Ln; context.out.Update;
								error := TRUE;
							END;
						END;

						IF ~error THEN
							context.out.Int(nofMarks, 0); context.out.String(" files selected for compilation."); context.out.Ln;
							context.out.Update;

							IF ~options.GetString("path", fullname) THEN fullname := ""; END;
							Strings.Append(fullname, ToolFilename);
							context.out.String("Writing release file to "); context.out.String(fullname);
							context.out.String(" ... "); context.out.Update;
							build.GenerateToolFile(fullname, res);
							IF (res = 0) THEN
								context.out.String("done."); context.out.Ln; context.out.Update;
								IF options.GetFlag("build") THEN
									IF ~options.GetInteger("workers", nofWorkers) THEN nofWorkers := 0; END;
									build.Compile(nofWorkers, context.out, context.error, options.GetFlag("verbose"), diagnostics, error);
								ELSE
									CallCommand("Notepad.Open", fullname, context);
								END;
							ELSE
								IF ~options.GetFlag("build") THEN
									CallCommand("Notepad.Open", fullname, context);
								END;
								context.out.String("error, res: "); context.out.Int(res, 0); context.out.Ln;
							END;
						END;
					END;
				ELSE
					context.error.String("Build "); context.error.String(buildname); context.error.String(" not found."); context.error.Ln;
				END;
			END;

			IF (diagnostics.nofMessages > 0) THEN
				diagnostics.ToStream(context.out, Diagnostics.All);
				context.out.Ln;
			END;
		ELSE
			context.error.String('Usage: Release.ReBuild [options] BuildName {filenames}');
			context.error.Ln;
		END;
	END;
END Rebuild;

(** 	Build the specified build *)
PROCEDURE Build*(context : Commands.Context);  (** [Options] buildname ~ *)
VAR
	filename, fullname : Files.FileName;
	builds : Builds; build : BuildObj;
	diagnostics : Diagnostics.DiagnosticsList;
	options : Options.Options;
	buildname : ARRAY 32 OF CHAR;
	start0 : Dates.DateTime;
	error : BOOLEAN;
	nofWorkers, res : LONGINT;
BEGIN
	NEW(options);
	options.Add("b", "build", Options.Flag);
	options.Add("c", "compiler", Options.String);
	options.Add(0X, "exclude", Options.String);
	options.Add(0X, "only", Options.String);
	options.Add("e", "extension", Options.String);
	options.Add("f", "file", Options.String);
	options.Add("l", "link", Options.Flag);
	options.Add("n", "nocheck", Options.Flag);
	options.Add("o", "options", Options.String);
	options.Add("p", "path", Options.String);
	options.Add("s", "symbolFileExtension", Options.String);
	options.Add("t", "target", Options.String);
	options.Add("v", "verbose", Options.Flag);
	options.Add(0X, "workers", Options.Integer);
	options.Add("x", "xml", Options.Flag);
	options.Add("y", "", Options.Flag);
	options.Add("z", "zip", Options.Flag);
	options.Add("w","warnings",Options.Flag);

	IF options.Parse(context.arg, context.error) THEN

		COPY(DefaultPackagesFile, filename);
		IF options.GetString("file", filename) THEN END;

		context.arg.SkipWhitespace; context.arg.String(buildname);

		IF (filename # "") & (buildname # "") THEN
			start0 := Dates.Now();
			NEW(diagnostics);
			IF ParseBuildFile(filename, builds, context.out, diagnostics) THEN
				build := builds.GetBuild(buildname);
				IF (build # NIL) THEN
					IF build.disabled THEN
						context.out.String("Warning: Build "); context.out.String(build.name);
						context.out.String(" is disabled."); context.out.Ln;
						context.out.Update;
					END;
					build.SetOptions(options);
					IF ~options.GetInteger("workers", nofWorkers) THEN nofWorkers := 0; END;
					IF ~options.GetFlag("nocheck") THEN
						build.DoChecks(context.out, diagnostics, error);
					ELSIF (nofWorkers > 0) THEN
						context.error.String("Incompatible options: nocheck cannot be combined with workers");
						context.error.Ln; context.error.Update;
						RETURN;
					END;

					IF CheckDiagnostics(diagnostics, options.GetFlag("warnings"), context.out) & ~error THEN

						IF ~options.GetString("path", fullname) THEN fullname := ""; 	END;
						Strings.Append(fullname, ToolFilename);
						context.out.String("Writing release file to "); context.out.String(fullname);
						context.out.String(" ... "); context.out.Update;
						build.GenerateToolFile(fullname, res);
						IF (res = 0) THEN
							context.out.String("done."); context.out.Ln; context.out.Update;
							IF options.GetFlag("build") THEN
								IF options.GetFlag("link") THEN
									context.error.String("Incompatible options: link cannot automatically build");
									context.error.Ln; context.error.Update;
									RETURN;
								END;
								build.Compile(nofWorkers, context.out, context.error, options.GetFlag("verbose"), diagnostics, error);
							ELSIF ~options.GetFlag("zip") THEN
								CallCommand("Notepad.Open", fullname, context);
							END;
							IF ~error & options.GetFlag("zip") & CheckDiagnostics(diagnostics, options.GetFlag("warnings"), context.out) THEN
								build.GenerateZipFiles(context.out, context.error, diagnostics, error);
							END;
							IF ~error & options.GetFlag("xml") THEN
								IF ~options.GetString("path", fullname) THEN fullname := ""; END;
								Strings.Append(fullname, InstallerPackageFile);
								context.out.String("Writing XML package description to "); context.out.String(fullname);
								context.out.String(" ... "); context.out.Update;
								build.GeneratePackageFile(InstallerPackageFile, res);
								IF (res = Files.Ok) THEN
									context.out.String("done.");
								ELSE
									context.out.String("error, res: "); context.out.Int(res, 0);
								END;
								context.out.Ln;
							END;
						ELSE
							IF ~options.GetFlag("build") THEN
								CallCommand("Notepad.Open", fullname, context);
							END;
							context.out.String("error, res: "); context.out.Int(res, 0); context.out.Ln;
						END;
					END;
				ELSE
					context.error.String("Build "); context.error.String(buildname); context.error.String(" not found."); context.error.Ln;
				END;
			END;

			IF (diagnostics.nofMessages > 0) THEN
				IF options.GetFlag("warnings") THEN
					diagnostics.ToStream(context.out, Diagnostics.All);
				ELSE
					diagnostics.ToStream(context.out, {Diagnostics.TypeError, Diagnostics.TypeInformation});
				END;
				context.out.Ln;
			END;
		ELSE
			context.error.String('Usage: Release.Build [options] BuildName');
			context.error.Ln;
		END;
	END;
END Build;

PROCEDURE Cleanup;
BEGIN
	CompilerInterface.Unregister("ReleaseTool");
END Cleanup;

BEGIN
	CompilerInterface.Register("ReleaseTool", "Parse release description file", "Tool", ParseText);
	Modules.InstallTermHandler(Cleanup);
END Release.

SystemTools.Free Release ~

Release.FindPosition WinAos Usbdi.Mod ~

Release.Analyze --details ~

Release.Check ~

Release.Build A2 ~

Release.Build --path="../Test/" -b A2 ~
Release.Build --path="../ObjT1/" -bn WinAos ~
Release.Build --path="../TestE/" eWinAos ~

Release.Build --path="../Test/" --xml A2 ~

Release.CheckFiles -f=C2Release.Tool ../../CF/trunk/source/*.* ~

Release.Build --path="../Test/" -z A2 ~

Release.RequiredModules A2 WMTextView ~
Release.WhoImports WinAos WMComponents ~

Release.Tool ~

Release.Build --path="../Test" -b -x="Build Oberon Contributions " A2 ~

Release.Rebuild -b WinAos WMTextView.Mod ~

Release.Build -b  WinAos ~
