MODULE Diagnostics; (** AUTHOR "staubesv"; PURPOSE "Generic diagnostics reporting facility"; *)

IMPORT Streams;

CONST
	(** Indicate that a position or an errorcode is not valid *)
	Invalid* = MIN(LONGINT);

	(** Entry types *)
	TypeInformation* = 0;
	TypeWarning* = 1;
	TypeError* = 2;

	(** DiagnosticsList.ToStream mask argument *)
	All* = {0..2};

	Tab = 9X;

TYPE

	Diagnostics* = OBJECT

		PROCEDURE Error*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		END Information;

	END Diagnostics;

TYPE

	Entry* = POINTER TO RECORD
		type*: LONGINT;
		source*: ARRAY 128 OF CHAR;
		position*, errorCode*: LONGINT;
		message*: ARRAY 128 OF CHAR;
		next*: Entry;
	END;

	EntryArray* = POINTER TO ARRAY OF Entry;

	EnumProc* = PROCEDURE {DELEGATE} (e : Entry);

TYPE

	DiagnosticsList* = OBJECT(Diagnostics)
	VAR
		(* Intended for subclassing only *)
		entries- : Entry;

		nofErrors- : LONGINT;
		nofWarnings- : LONGINT;
		nofInformations- : LONGINT;

		nofMessages- : LONGINT;

		PROCEDURE Error*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeError, source, position, errorCode, message, nofErrors)
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeWarning, source, position, errorCode, message, nofWarnings);
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InsertSorted(TypeInformation, source, position, errorCode, message, nofInformations);
		END Information;

		PROCEDURE ToStream*(w : Streams.Writer; mask : SET);
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			ASSERT(w # NIL);
			entry := entries;
			WHILE (entry # NIL) DO
				IF (entry.type IN mask) THEN
					Print (w, entry.source, entry.position, entry.errorCode, entry.type, entry.message);
				END;
				entry := entry.next;
			END;
		END ToStream;

		PROCEDURE &Reset*;
		BEGIN {EXCLUSIVE}
			entries := NIL;
			nofErrors := 0; nofWarnings := 0; nofInformations := 0;
			nofMessages := 0;
		END Reset;

		PROCEDURE ForAll*(proc : EnumProc);
		VAR e : Entry;
		BEGIN {EXCLUSIVE}
			ASSERT(proc # NIL);
			e := entries;
			WHILE (e # NIL) DO
				proc(e);
				e := e.next;
			END;
		END ForAll;

		PROCEDURE GetEntries*() : EntryArray;
		VAR e : Entry; result : EntryArray; nofEntries, i : LONGINT;
		BEGIN {EXCLUSIVE}
			result := NIL;
			nofEntries := nofErrors + nofWarnings + nofInformations;
			IF (nofEntries > 0) THEN
				NEW(result, nofEntries);
				e := entries; i := 0;
				WHILE (e # NIL) DO
					result[i] := e; INC(i);
					e := e.next;
				END;
			END;
			RETURN result;
		END GetEntries;

		PROCEDURE InsertSorted(type: LONGINT; CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR; VAR counter: LONGINT);
		VAR prev, entry : Entry;
		BEGIN
			entry := entries; prev := NIL;
			WHILE (entry # NIL) & (entry.position <= position) DO prev := entry; entry := entry.next END;
			IF (entry = NIL) OR (entry.type # type) OR (entry.position # position) OR (entry.errorCode # errorCode) OR (entry.message # message) THEN
				INC(nofMessages); INC (counter);
				entry := NewEntry (type, source, position, errorCode, message, entry);
				IF prev = NIL THEN entries := entry ELSE prev.next := entry END
			END
		END InsertSorted;

		PROCEDURE NewEntry*(type: LONGINT; CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR; next: Entry) : Entry;
		VAR entry : Entry;
		BEGIN
			NEW(entry);
			entry.type := type;
			COPY (source, entry.source);
			entry.position := position;
			entry.errorCode := errorCode;
			COPY (message, entry.message);
			entry.next := next;
			RETURN entry;
		END NewEntry;

	END DiagnosticsList;

TYPE

	StreamDiagnostics* = OBJECT (Diagnostics);
	VAR
		writer: Streams.Writer;

		PROCEDURE &Init *(w: Streams.Writer);
		BEGIN
			ASSERT(w # NIL);
			writer := w;
		END Init;

		PROCEDURE Error* (CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, errorCode, TypeError, message);
		END Error;

		PROCEDURE Warning* (CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, errorCode, TypeWarning, message);
		END Warning;

		PROCEDURE Information* (CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN Print (writer, source, position, errorCode, TypeInformation, message);
		END Information;

	END StreamDiagnostics;

PROCEDURE Print (w: Streams.Writer; CONST source : ARRAY OF CHAR; position, errorCode, type: LONGINT; CONST message: ARRAY OF CHAR);
BEGIN
	w.Char(Tab);
	IF (source # "") THEN w.String (source); END;
	IF (position # Invalid) THEN w.Char ('@'); w.Int(position, 0); END;
	w.Char(Tab);
	IF (type = TypeWarning) THEN
		w.String("warning");
	ELSIF (type = TypeError) THEN
		w.String("error");
	END;
	IF (errorCode # Invalid) THEN
		IF (type # TypeInformation) THEN w.Char (' ') END;
		w.Int(errorCode, 0);
	END;
	IF (type # TypeInformation) THEN w.String(": ") END;
	w.String(message); w.Ln;
	w.Update;
END Print;

END Diagnostics.
