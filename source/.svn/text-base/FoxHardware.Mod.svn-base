(**
	@author Felix Friedrich
	@purpose Hardware Module containing base class of hardware description object for emission of hardware on FPGAs
**)

(*! deprecated -- not used any more in ActiveCells 3 *)
MODULE FoxHardware;

IMPORT ActiveCells := FoxActiveCells, Streams, Diagnostics, Strings, Commands, Files;

TYPE
	Description* = OBJECT
	VAR diagnostics-: Diagnostics.Diagnostics; log-: Streams.Writer;

		PROCEDURE & Init*(d: Diagnostics.Diagnostics; l: Streams.Writer);
		BEGIN
			SELF.diagnostics := d;
			SELF.log := l;
		END Init;

		PROCEDURE Emit*(specification: ActiveCells.Specification): BOOLEAN; (* to be overwritten by implementers *)
		BEGIN
		END Emit;

		PROCEDURE GetHardwarePath*(VAR name: ARRAY OF CHAR);
		BEGIN
		END GetHardwarePath;

	END Description;

	PROCEDURE GetDescription*(CONST name: ARRAY OF CHAR): Description;
	VAR
		procname: ARRAY 256 OF CHAR;
		factory: PROCEDURE (): Description;
		description: Description;
	BEGIN
		description := NIL;
		IF Strings.Length(name) > 0 THEN
			GETPROCEDURE(name,"Get", factory); (* try long name, for example --hardware=FoxML505 *)
			IF factory = NIL THEN (* try short name for example  --hardware=ML505 *)
				procname := "Fox";
				Strings.Append(procname, name);
				GETPROCEDURE(procname,"Get", factory);
			END;
			IF factory # NIL THEN
				description := factory();
				ASSERT(description # NIL);
			END;
		END;
		RETURN description
	END GetDescription;

	PROCEDURE Emit*(context: Commands.Context);
	VAR fileName, hardware: Files.FileName; r: Files.Reader; specification: ActiveCells.Specification; f : Files.File; diagnostics: Diagnostics.StreamDiagnostics; d: Description;
	BEGIN
		IF context.arg.GetString(hardware) & context.arg.GetString(fileName) THEN
			NEW(diagnostics, context.out);
			d := GetDescription(hardware);
			IF d = NIL THEN context.error.String("could not instantiate hardware description "); context.error.String(hardware); context.error.Ln; RETURN END;
			d.Init(diagnostics, context.out);
			specification := ActiveCells.LoadSpecification(fileName, diagnostics, context.out);
			(*
			NEW(specification,"",diagnostics,context.out);
			f := Files.Old(fileName);
			IF f = NIL THEN context.error.String("could not open specification file "); context.error.String(fileName); context.error.Ln; RETURN END;
			NEW(r,f,0);
			IF specification.Read(r) & d.Emit(specification) THEN END;
			*)
			IF specification # NIL THEN
				IF d.Emit(specification) THEN END;
			END;
		END;
	END Emit;

	(* tools *)

	PROCEDURE SizeInBlocks*(sizeInUnits, blockSize: LONGINT): LONGINT;
	BEGIN
		RETURN (sizeInUnits-1) DIV blockSize +1
	END SizeInBlocks;
	
END FoxHardware.

FoxHardware.Emit ML505 TL.spec ~
