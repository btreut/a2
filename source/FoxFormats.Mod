MODULE FoxFormats;

IMPORT SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, Strings, Streams, Diagnostics, Options, Files;

CONST
	NoFindPC*=MAX(LONGINT);

TYPE
	SectionName= ARRAY 256 OF CHAR;

	(* container for generated code (intermediate code - binary code) *)
	GeneratedModule*=OBJECT
		VAR
			(* input for (intermediate) code generation *)
			module-: SyntaxTree.Module;
			system-: Global.System;
			findPC-: LONGINT;
			moduleName-: SectionName; (* genasm *)

		PROCEDURE SetFindPC*(findPC: LONGINT);
		BEGIN SELF.findPC := findPC
		END SetFindPC;

		PROCEDURE & Init*(module: SyntaxTree.Module; system: Global.System);
		BEGIN SELF.module := module; SELF.system := system; findPC := NoFindPC
		END Init;

		PROCEDURE SetModuleName*(CONST moduleName: ARRAY OF CHAR);
		BEGIN COPY(moduleName, SELF.moduleName)
		END SetModuleName;

		PROCEDURE SetSystem*(system: Global.System);
		BEGIN SELF.system := system
		END SetSystem;

		PROCEDURE Dump*(w: Streams.Writer);
		BEGIN
			w.String(".module "); w.String(moduleName); w.Ln;
			w.Ln;
		END Dump;

	END GeneratedModule;

	(* symbol file import / export for different implementations *)
	SymbolFileFormat*=OBJECT
		VAR
			diagnostics-:  Diagnostics.Diagnostics; system-: Global.System;
			path-: Files.FileName;

		PROCEDURE &Init*;
		BEGIN diagnostics := NIL; system := NIL; path := ""
		END Init;

		PROCEDURE Initialize*(diagnostics: Diagnostics.Diagnostics; system: Global.System; CONST path: ARRAY OF CHAR);
		BEGIN SELF.diagnostics := diagnostics; SELF.system := system; COPY(path, SELF.path)
		END Initialize;

		PROCEDURE Export*(module: SyntaxTree.Module; importCache: SyntaxTree.ModuleScope): BOOLEAN;
		END Export;

		PROCEDURE Import*(CONST name: ARRAY OF CHAR; importCache: SyntaxTree.ModuleScope): SyntaxTree.Module;
		END Import;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		BEGIN
		END GetOptions;

		PROCEDURE GetExtension*(VAR ext: ARRAY OF CHAR);
		BEGIN HALT(100); (* abstract *)
		END GetExtension;

	END SymbolFileFormat;

	(* object file export for different implementations *)
	ObjectFileFormat*= OBJECT
		VAR diagnostics-: Diagnostics.Diagnostics;
			path-: Files.FileName;
			extension-: Files.FileName;

		PROCEDURE &Init*;
		BEGIN diagnostics := NIL;path := ""
		END Init;

		PROCEDURE Initialize*(diagnostics: Diagnostics.Diagnostics);
		BEGIN SELF.diagnostics := diagnostics;  COPY(path, SELF.path)
		END Initialize;

		PROCEDURE Export*(module: GeneratedModule; symbolFileFormat: SymbolFileFormat): BOOLEAN;
		BEGIN RETURN FALSE
		END Export;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		BEGIN
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat*(): SymbolFileFormat;
		BEGIN RETURN NIL
		END DefaultSymbolFileFormat;

		PROCEDURE ForceModuleBodies*(): BOOLEAN;
		BEGIN RETURN FALSE
		END ForceModuleBodies;

		PROCEDURE SetExtension*(CONST ext: ARRAY OF CHAR);
		BEGIN COPY(ext, SELF.extension);
		END SetExtension;

		PROCEDURE GetExtension*(VAR ext: ARRAY OF CHAR);
		BEGIN COPY(SELF.extension, ext);
		END GetExtension;
		
		PROCEDURE SetPath*(CONST path: ARRAY OF CHAR);
		BEGIN
			COPY(path, SELF.path);
		END SetPath;
		
		PROCEDURE GetPath*(VAR path: ARRAY OF CHAR);
		BEGIN
			COPY(SELF.path, path);
		END GetPath;

	END ObjectFileFormat;

	PROCEDURE GetSymbolFileFormat*(CONST name: ARRAY OF CHAR): SymbolFileFormat;
	VAR
		procname: ARRAY 256 OF CHAR;
		factory: PROCEDURE (): SymbolFileFormat;
		symbolFileFormat: SymbolFileFormat;
	BEGIN
		symbolFileFormat := NIL;
		IF Strings.Length(name) > 0 THEN
			GETPROCEDURE(name,"Get", factory); (* try long name for example -G=OCBinarySymbolFile *)
			IF factory = NIL THEN (* try short name for example -G=Binary *)
				procname := "Fox";
				Strings.Append(procname, name);
				Strings.Append(procname, "SymbolFile");
				GETPROCEDURE(procname,"Get", factory);
			END;
			IF factory # NIL THEN
				symbolFileFormat := factory();
				Assert(symbolFileFormat # NIL,"symbol file factory returned NIL symbol file format");
			END;
		END;
		RETURN symbolFileFormat
	END GetSymbolFileFormat;

	PROCEDURE GetObjectFileFormat*(CONST name: ARRAY OF CHAR): ObjectFileFormat;
	VAR
		procname: ARRAY 256 OF CHAR;
		factory: PROCEDURE (): ObjectFileFormat;
		objectFileFormat: ObjectFileFormat;
	BEGIN
		objectFileFormat := NIL;
		IF Strings.Length(name) > 0 THEN
			GETPROCEDURE(name,"Get", factory); (* try long name for example -G=OCBinaryObjectFile *)
			IF factory = NIL THEN (* try short name for example -G=Binary*)
				procname := "Fox";
				Strings.Append(procname, name);
				Strings.Append(procname, "ObjectFile");
				GETPROCEDURE(procname,"Get", factory);
			END;
			IF factory # NIL THEN
				objectFileFormat := factory();
				Assert(objectFileFormat # NIL,"symbol file factory returned NIL symbol file format");
			END;
		END;
		RETURN objectFileFormat
	END GetObjectFileFormat;

	PROCEDURE Assert(b: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN
		ASSERT(b);
	END Assert;

END FoxFormats.