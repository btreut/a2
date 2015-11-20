MODULE CompilerInterface; (** AUTHOR "staubesv"; PURPOSE "Generic compiler interface"; *)
(**
 * The idea of this module is to make it possible for client applications to use multiple different compilers.
 * Compiler can be retrieve by name, file extension of filename.
 *)

IMPORT
	KernelLog, Streams, Commands, Strings, Texts, Diagnostics;

CONST

	ModuleName = "CompilerInterface";

TYPE

	Name* = ARRAY 16 OF CHAR;
	Description* = ARRAY 128 OF CHAR;
	FileExtension* = ARRAY 16 OF CHAR;

	CompileTextProc* = PROCEDURE {DELEGATE} (t : Texts.Text; CONST source: ARRAY OF CHAR; pos: LONGINT; CONST pc,opt: ARRAY OF CHAR;
		log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);

TYPE

	Compiler* = OBJECT
	VAR
		name- : Name;
		description- : Description;
		fileExtension- : FileExtension;

		compileText : CompileTextProc;

		next : Compiler;

		PROCEDURE CompileText*(t : Texts.Text; CONST source: ARRAY OF CHAR; pos: LONGINT; CONST pc,opt: ARRAY OF CHAR;
			log: Streams.Writer; diagnostics : Diagnostics.Diagnostics; VAR error: BOOLEAN);
		VAR
			trap : BOOLEAN;
		BEGIN
			trap := FALSE;
			IF (compileText # NIL) THEN
				compileText(t, source, pos, pc, opt, log, diagnostics, error);
			ELSIF (diagnostics # NIL) THEN
				diagnostics.Error(source, Diagnostics.Invalid, Diagnostics.Invalid, "Text compile procedure not set");
			END;
		FINALLY
			IF trap THEN (* trap will be set in case a trap occurs in the block above *)
				error := TRUE;
				diagnostics.Error(source, Diagnostics.Invalid, Diagnostics.Invalid, "COMPILER TRAPPED");
				log.String("COMPILER TRAPPED!!!"); log.Update;
			END;
		END CompileText;

		PROCEDURE Show(out : Streams.Writer);
		BEGIN
			out.String(name);
			out.String(" ("); out.String(description); out.String(") ");
			out.String("File Extension: "); out.String(fileExtension);
			out.Ln;
		END Show;

		PROCEDURE &Init*(
			CONST name : Name;
			CONST description : Description;
			CONST fileExtension : FileExtension;
			compileText : CompileTextProc
		);
		BEGIN
			SELF.name := name; SELF.description := description; SELF.fileExtension := fileExtension;
			SELF.compileText := compileText;
		END Init;

	END Compiler;

VAR
	compilers : Compiler;

PROCEDURE FindCompilerByName(CONST name : ARRAY OF CHAR) : Compiler;
VAR c : Compiler;
BEGIN
	c := compilers;
	WHILE (c # NIL) & (c.name # name) DO c := c.next; END;
	RETURN c;
END FindCompilerByName;

(** Get compiler object for a specific file extension. Returns NIL if no appropriate compiler found. *)
PROCEDURE GetCompiler*(fileExtension : FileExtension) : Compiler;
VAR c : Compiler;
BEGIN {EXCLUSIVE}
	Strings.UpperCase(fileExtension);
	c := compilers;
	WHILE (c # NIL) & (c.fileExtension # fileExtension) DO c := c.next; END;
	RETURN c;
END GetCompiler;

PROCEDURE GetCompilerByName*(CONST name : ARRAY OF CHAR) : Compiler;
BEGIN {EXCLUSIVE}
	RETURN FindCompilerByName(name);
END GetCompilerByName;

(** Get compiler object for a filename. A compiler is appropriate for a given file name
	if the file extension the compiler requires is part of the filename, e.g. Module.Mod.Bak for the file extension .Mod
	Returns NIL if no appropriate compiler found *)
PROCEDURE GetCompilerByFilename*(filename : ARRAY OF CHAR) : Compiler;
VAR c : Compiler; pos : LONGINT;
BEGIN {EXCLUSIVE}
	Strings.UpperCase(filename);
	c := compilers;
	LOOP
		IF (c = NIL) THEN EXIT; END;
		pos := Strings.Pos(c.fileExtension, filename);
		IF (pos > 0) & (filename[pos-1] = ".") THEN
			EXIT;
		END;
		c := c.next;
	END;
	RETURN c;
END GetCompilerByFilename;

(** Show all registered compilers *)
PROCEDURE Show*(context : Commands.Context);
VAR c : Compiler;
BEGIN {EXCLUSIVE}
	IF (compilers = NIL) THEN
		context.out.String("No compilers registered."); context.out.Ln;
	ELSE
		c := compilers;
		WHILE (c # NIL) DO c.Show(context.out); c := c.next; END;
	END;
END Show;

(** Register a compiler. The name of the compiler must be unique. *)
PROCEDURE Register*(
	CONST name : Name;
	CONST description : Description;
	fileExtension : FileExtension;
	compileText : CompileTextProc);
VAR
	c : Compiler;
BEGIN {EXCLUSIVE}
	ASSERT(compileText # NIL);
	c := FindCompilerByName(name);
	IF (c = NIL) THEN
		Strings.UpperCase(fileExtension);
		NEW(c, name, description, fileExtension, compileText);
		c.next := compilers; compilers := c;
	ELSE
		KernelLog.Enter;
		KernelLog.String(ModuleName); KernelLog.String(": Cannot register compiler '");
		KernelLog.String(name); KernelLog.String("': Name is already in use.");
		KernelLog.Exit;
	END;
END Register;

(** Unregister a compiler *)
PROCEDURE Unregister*(CONST name : Name);
VAR prev : Compiler;
BEGIN {EXCLUSIVE}
	IF (compilers = NIL) THEN RETURN; END;
	IF (compilers.name = name) THEN
		compilers := compilers.next;
	ELSE
		prev := compilers;
		WHILE(prev.next # NIL) & (prev.next.name # name) DO prev := prev.next; END;
		IF (prev.next # NIL) THEN
			prev.next := prev.next.next;
		END;
	END;
END Unregister;

BEGIN
	compilers := NIL;
END CompilerInterface.

CompilerInterface.Show ~

SystemTools.Free CompilerInterface ~