MODULE TrapWriters; (** AUTHOR "fof"; PURPOSE "trap writer: write traps to different outputs"; *)

IMPORT Streams, Kernel, KernelLog, Trace, Modules;

CONST
	TrapMaxCharacters = 32*1024;
TYPE
	Entry= POINTER TO RECORD factory: WriterFactory; next: Entry END;

	WriterFactory = PROCEDURE (): Streams.Writer;

	TrapWriter = OBJECT (Streams.StringWriter)
	(* pooling trap writer, EXCLUSIVE sections and allocation forbidden within trap! *)
	VAR
		trapped: BOOLEAN;
		first, last: Entry;
		timer: Kernel.Timer;
		contents: ARRAY TrapMaxCharacters OF CHAR;

		PROCEDURE Trapped;
		BEGIN trapped := TRUE;
		END Trapped;
		
		PROCEDURE Char(ch: CHAR);
		BEGIN
			Trace.Char(ch);
			Char^(ch);
		END Char;
		

		PROCEDURE &InitTrapWriter(f: WriterFactory);
		BEGIN
			first := NIL; last := NIL; trapped := FALSE;
			Add(f);
			InitStringWriter (TrapMaxCharacters);
		END InitTrapWriter;

		PROCEDURE Add(f: WriterFactory);
		VAR e: Entry;
		BEGIN
			Remove(f); (* just in case *)
			NEW(e); e.factory := f; e.next := NIL;
			IF first = NIL THEN first := e; last := e
			ELSE last.next := e; last := e
			END;
		END Add;

		PROCEDURE Remove(f: WriterFactory);
		VAR e: Entry;
		BEGIN
			IF first = NIL THEN RETURN
			ELSIF first.factory = f THEN
				first := first.next;
				IF first = NIL THEN last := NIL END;
			ELSE e := first;
				WHILE (e.next # NIL) & (e.next.factory # f) DO
					e := e.next
				END;
				IF e.next # NIL THEN
					IF e.next = last THEN last := e END;
					e.next := e.next.next;
				END;
			END;
		END Remove;

		PROCEDURE RemoveAll;
		BEGIN
			first := NIL; last := NIL;
		END RemoveAll;

		PROCEDURE Write;
		VAR len: LONGINT; writer: Streams.Writer;
			e: Entry;
		BEGIN
			GetRaw (contents, len); Reset;
			e := first;
			WHILE e # NIL DO
				writer := e.factory (); writer.Bytes (contents, 0, len); writer.Update;
				e := e.next
			END;
		END Write;

	BEGIN {ACTIVE}
		NEW(timer);
		LOOP
			 timer.Sleep(100);
			 IF trapped THEN Write; trapped := FALSE
			 ELSIF first = NIL THEN RETURN
			 END;
		END;
	END TrapWriter;

VAR
	defaultWriter: Streams.Writer;
	traceWriter, logWriter: Streams.Writer;
	trapWriter: TrapWriter;

	PROCEDURE InstallTrapWriterFactory*(factory: WriterFactory);
	BEGIN
		IF factory # NIL THEN
			IF trapWriter = NIL THEN
				NEW (trapWriter,factory)
			ELSE
				trapWriter.Add (factory)
			END;
		END
	END InstallTrapWriterFactory;

	PROCEDURE UninstallTrapWriterFactory*(factory: WriterFactory);
	BEGIN
		IF trapWriter # NIL THEN
			trapWriter.Remove(factory);
			IF trapWriter.first = NIL THEN trapWriter := NIL END;
		END
	END UninstallTrapWriterFactory;

	PROCEDURE GetWriter*(): Streams.Writer;
	BEGIN
		IF trapWriter = NIL THEN RETURN defaultWriter
		ELSE RETURN trapWriter
		END
	END GetWriter;

	PROCEDURE Trapped*;
	BEGIN
		IF trapWriter # NIL THEN trapWriter.Trapped; trapWriter.Update END;
	END Trapped;

	PROCEDURE TraceFactory(): Streams.Writer;
	BEGIN
		RETURN traceWriter
	END TraceFactory;

	PROCEDURE LogFactory(): Streams.Writer;
	BEGIN
		RETURN logWriter
	END LogFactory;

	PROCEDURE InstallTraceWriter*;
	BEGIN
		InstallTrapWriterFactory(TraceFactory);
	END InstallTraceWriter;

	PROCEDURE RemoveTraceWriter*;
	BEGIN
		UninstallTrapWriterFactory(TraceFactory)
	END RemoveTraceWriter;

	PROCEDURE InstallLogWriter*;
	BEGIN
		InstallTrapWriterFactory(LogFactory);
	END InstallLogWriter;

	PROCEDURE RemoveLogWriter*;
	BEGIN
		UninstallTrapWriterFactory(LogFactory);
	END RemoveLogWriter;

	PROCEDURE RemoveAll*;
	BEGIN
		IF trapWriter # NIL THEN trapWriter.RemoveAll; trapWriter := NIL END;
	END RemoveAll;

	PROCEDURE Cleanup;
	BEGIN
		RemoveAll
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Streams.OpenWriter(logWriter, KernelLog.Send);
	Streams.OpenWriter(traceWriter, Trace.Send);
	defaultWriter := logWriter;
	trapWriter := NIL;
END TrapWriters.
TrapWriters.InstallTraceWriter
TrapWriters.InstallLogWriter