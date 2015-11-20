MODULE StreamUtilities; (** AUTHOR "Patrick Hunziker"; PURPOSE "stream utilities"; *)
(* daisychaining of readers or writers with 'logging side-stream', or with size limitation*)

IMPORT Streams, SYSTEM (*, KernelLog, Commands*);

CONST
	ReaderBufSize = Streams.DefaultReaderSize;
	WriterBufSize = Streams.DefaultWriterSize;

(* writer that can daisychained with another writer that extracts a copy of the data flow to a monitor stream*)
TYPE	WriterMonitor* = OBJECT (Streams.Writer);
		VAR out, monitor : Streams.Writer;

		PROCEDURE &Init*(out:Streams.Writer; monitor: Streams.Writer);
		BEGIN
			InitWriter(Sender, WriterBufSize);
			SELF.out := out;
			SELF.monitor:=monitor;
			Reset;
		END Init;

		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		BEGIN
			out.Bytes(outBuf, ofs, len);
			monitor.Bytes(outBuf, ofs, len);
			INC(sent,len);
			IF propagate THEN out.Update; monitor.Update END;
			res:=out.res;
		END Sender;

		PROCEDURE CanSetPos*(): BOOLEAN;
		BEGIN RETURN out.CanSetPos()
		END CanSetPos;

		PROCEDURE SetPos*(pos: LONGINT);
		BEGIN Reset; out.SetPos(pos);
		END SetPos;

		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN out.Pos()
		END Pos;

	END WriterMonitor;

TYPE  Encryptor*=PROCEDURE{DELEGATE}( VAR buf: ARRAY OF CHAR;  pos, len: LONGINT );

(* encrypting writer that can daisychained with another writer *)
TYPE	EncryptingWriter* = OBJECT (Streams.Writer);
		VAR out : Streams.Writer; encrypt: Encryptor; buf: POINTER TO ARRAY OF CHAR;

		PROCEDURE &Init*(out:Streams.Writer; encrypt:Encryptor);
		BEGIN
			InitWriter(Sender, WriterBufSize);
			NEW(buf, WriterBufSize);
			SELF.out := out;
			SELF.encrypt:=encrypt;
			Reset;
		END Init;

		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR i:LONGINT;
		BEGIN
			FOR i:=0 TO len-1 DO buf[i]:=outBuf[ofs+i] END;
			IF encrypt#NIL THEN encrypt(buf^,0,len); END;
			out.Bytes(buf^, 0, len);
			INC(sent,len);
			IF propagate THEN out.Update END;
			res:=out.res;
		END Sender;

		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN out.Pos()
		END Pos;

	END EncryptingWriter;

	TYPE  Decryptor*=PROCEDURE{DELEGATE}( VAR buf: ARRAY OF CHAR;  pos, len: LONGINT );

	(* reader that can daisychained with another reader that reads and decrypts a stream*)
	DecryptingReader* = OBJECT(Streams.Reader)
		VAR in: Streams.Reader;
			decrypt:Decryptor;

		PROCEDURE &Init*(in: Streams.Reader; decrypt: Decryptor);
		BEGIN
			InitReader(Receiver, ReaderBufSize);
			SELF.in := in;
			SELF.decrypt:=decrypt;
		END Init;

		PROCEDURE Receiver(VAR inBuf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		BEGIN
			ASSERT((size > 0) & (min <= size) & (min >= 0));
			in.Bytes(inBuf, ofs, size, len);
			IF decrypt#NIL THEN decrypt(inBuf, ofs, len); END;
			INC(received,len);
			res:=in.res;
		END Receiver;

		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN in.Pos()
		END Pos;

	END DecryptingReader;


TYPE

	WriteEntry = POINTER TO RECORD buf: POINTER TO ARRAY OF CHAR; len: LONGINT; propagate: BOOLEAN; next: WriteEntry END;

(* writer that writes asynchronously - updates are delayed until the thread is ready for it
	useful to avoid file writing delay problems.
	Caution: Pos() and SetPos() enforce synchronisation.
	*)

	AsynchronousWriter= OBJECT(Streams.Writer)
	VAR
		first, last: WriteEntry;
		free: WriteEntry;
		size: LONGINT;
		sender: Streams.Sender;

		PROCEDURE & InitWriter(sender: Streams.Sender; size: LONGINT);
		BEGIN
			first := NIL; last := NIL; free := NIL;
			SELF.size := size;
			SELF.sender := sender;
			InitWriter^(Add, size);
			Reset;
		END InitWriter;

		PROCEDURE Add(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR entry: WriteEntry;
		BEGIN
			IF ~ToLastEntry(outBuf, ofs, len, propagate, res) THEN
				entry := GetFreeEntry(MAX(SELF.size, len));
				SYSTEM.MOVE(ADDRESS OF outBuf[ofs], ADDRESS OF entry.buf[0], len);
				entry.len := len;
				entry.propagate := propagate;
				PutEntry(entry)
			END;
		END Add;

		(* check last entry for enough space to host data. If available, remove from list and return *)
		PROCEDURE ToLastEntry(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT): BOOLEAN;
		BEGIN{EXCLUSIVE}
			IF last = NIL THEN RETURN FALSE
			ELSIF last.propagate # propagate THEN RETURN FALSE
			ELSIF (last.len + len > LEN(last.buf^)) THEN RETURN FALSE
			ELSE
				SYSTEM.MOVE(ADDRESS OF outBuf[ofs], ADDRESS OF last.buf[last.len], len);
				INC(last.len, len);
				res := 0;
				RETURN TRUE
			END;
		END ToLastEntry;

		PROCEDURE GetFreeEntry(len: LONGINT): WriteEntry;
		VAR entry: WriteEntry;
		BEGIN{EXCLUSIVE}
			IF free = NIL THEN NEW(entry) ELSE entry := free; free := free.next END;
			IF (entry.buf = NIL) OR (LEN(entry.buf)< len) THEN NEW(entry.buf, len) END;
			entry.len := 0; entry.propagate := FALSE;
			RETURN entry
		END GetFreeEntry;

		PROCEDURE ReturnEntry(entry: WriteEntry);
		BEGIN{EXCLUSIVE}
			entry.next := free;
			free := entry
		END ReturnEntry;

		PROCEDURE PutEntry(entry: WriteEntry);
		BEGIN{EXCLUSIVE}
			IF last = NIL THEN first := entry; last := entry
			ELSE last.next := entry; last := entry END;
			entry.next := NIL;
		END PutEntry;

		PROCEDURE GetEntry(): WriteEntry;
		VAR entry: WriteEntry;
		BEGIN{EXCLUSIVE}
			AWAIT(first # NIL);
			entry := first;
			first := first.next;
			IF first = NIL THEN last := NIL END;
			RETURN entry
		END GetEntry;

		PROCEDURE ProcessWrites;
		VAR entry: WriteEntry;
		BEGIN
			LOOP
				entry := GetEntry();

				sender(entry.buf^, 0, entry.len, entry.propagate, res);

				ReturnEntry(entry);
			END;
		END ProcessWrites;

	BEGIN{ACTIVE}
		ProcessWrites;
	END AsynchronousWriter;


	AsynchronousForwarder* = OBJECT (AsynchronousWriter);
		VAR out: Streams.Writer;

		PROCEDURE &Init*(out:Streams.Writer);
		BEGIN
			SELF.out := out;
			InitWriter(Sender, WriterBufSize);
		END Init;

		PROCEDURE CanSetPos*(): BOOLEAN;
		BEGIN RETURN out.CanSetPos()
		END CanSetPos;

		PROCEDURE SetPos*(pos: LONGINT);
		BEGIN{EXCLUSIVE}
			AWAIT(first = NIL);
			Reset; out.SetPos(pos);
		END SetPos;

		PROCEDURE Pos*(): LONGINT;
		BEGIN{EXCLUSIVE}
			AWAIT(first = NIL);
			RETURN out.Pos()
		END Pos;

		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		BEGIN
			out.Bytes(outBuf, ofs, len);
			IF propagate THEN out.Update END;
			INC(sent,len);
			res:=out.res;
		END Sender;

	END AsynchronousForwarder;

	(* reader that can daisychained with another reader that extracts a copy of the data flow to a monitor stream*)
	ReaderMonitor* = OBJECT(Streams.Reader)
		VAR in: Streams.Reader;
			monitor: Streams.Writer;

		PROCEDURE &Init*(in: Streams.Reader; monitor: Streams.Writer);
		BEGIN
			InitReader(Receiver, ReaderBufSize);
			SELF.in := in;
			SELF.monitor:=monitor;
		END Init;

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		BEGIN
			ASSERT((size > 0) & (min <= size) & (min >= 0));
			in.Bytes(buf, ofs, size, len);
			INC(received,len);
			res:=in.res;
			monitor.Bytes(buf, ofs, len);
			monitor.Update;
		END Receiver;

		PROCEDURE CanSetPos*(): BOOLEAN;
		BEGIN RETURN in.CanSetPos()
		END CanSetPos;

		PROCEDURE SetPos*(pos: LONGINT);
		BEGIN Reset; in.SetPos(pos)
		END SetPos;

		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN in.Pos()
		END Pos;

	END ReaderMonitor;

	LimitedWriter* = OBJECT (Streams.Writer);
		VAR out : Streams.Writer;
			size, remain-: LONGINT;

		PROCEDURE &Init*(out:Streams.Writer; size: LONGINT);
		BEGIN
			InitWriter(Sender, MIN(size, WriterBufSize));
			SELF.out := out;
			SELF.size:=size; remain:=size;
		END Init;

		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR num:LONGINT;
		BEGIN
			num:=MIN(remain,len);
			out.Bytes(outBuf, ofs, num);
			DEC(remain, num);
			IF propagate THEN out.Update END;
			IF num<len THEN res:=Streams.EOF ELSE res:=out.res END;
		END Sender;

		PROCEDURE Reset*;
		BEGIN
			remain:=size;
		END Reset;

	END LimitedWriter;

	LimitedReader* = OBJECT (Streams.Reader);
		VAR in : Streams.Reader;
			total, remain-: LONGINT;

		PROCEDURE &Init*(in:Streams.Reader; size: LONGINT);
		BEGIN
			InitReader(Receiver, MIN(size, ReaderBufSize));
			SELF.in := in;
			total:=size; remain:=size;
		END Init;

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR num:LONGINT;
		BEGIN
			ASSERT(size >= 0);
			IF (remain=0) THEN len:=0; res:=Streams.EOF; RETURN END;
			in.Bytes(buf, ofs, MIN(remain,size), len);
			DEC(remain,len); INC(received,len);
			res:=in.res;
		END Receiver;

		PROCEDURE Reset*;
		BEGIN
			remain:=total;
		END Reset;
	END LimitedReader;
	
	(* convert stream to Base64 encoding on-the-fly *)
TYPE	Base64Writer* = OBJECT (Streams.Writer);
		VAR out : Streams.Writer;  buf: POINTER TO ARRAY OF CHAR;
			group, i, ll: LONGINT; done:BOOLEAN;
		
		PROCEDURE &Init*(out:Streams.Writer);
		BEGIN
			IF ~tablesReady THEN InitTables END;
			InitWriter(Sender, WriterBufSize);
			NEW(buf, WriterBufSize);
			SELF.out := out;
			Reset;
		END Init;
		
		PROCEDURE Reset*;
		BEGIN
			Reset^;
			group := 0;  i := 0;  ll := 0; done:=FALSE;
		END Reset;
	
		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR ix:LONGINT;
		BEGIN
			IF done THEN res:=Streams.EOF; RETURN END;
			ix := ofs; (* encoding snipped from CryptoBase64 *)
			WHILE ix < ofs+len DO
				group := group*100H + ORD( outBuf[ix] );  INC( ix );  INC( i );
				IF i = 3 THEN  
					out.Char( etab[group DIV 40000H MOD 64] );
					out.Char( etab[group DIV 1000H MOD 64] );
					out.Char( etab[group DIV 40H MOD 64] );
					out.Char( etab[group MOD 64] );
					INC(sent,4);
					INC( ll, 4 );
					IF ll >= 72 THEN  out.Ln;  ll := 0  END;
					group := 0;
					i := 0  
				END;
			END;
			
			IF propagate THEN out.Update END;
			res:=out.res;
		END Sender;
		
		PROCEDURE Close*; (*required termination of a Base64 sequence*)
		BEGIN
			Update;
			IF i > 0 THEN   (* encode rest *)
				IF i = 1 THEN  group := group*100H  END;
				out.Char( etab[group DIV 400H MOD 64] );  
				out.Char( etab[group DIV 10H MOD 64] );  
				IF i = 1 THEN  out.Char( '=' )  ELSE  out.Char( etab[group*4 MOD 64] )  END;
				out.Char( '=' );  
			END;
			out.Update;
			res:=out.res;
		END Close;

		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN out.Pos()
		END Pos;

	END Base64Writer;
	
		(* decode Base64 stream to cleartext on-the-fly *)
	Base64Reader* = OBJECT(Streams.Reader)
		VAR in: Streams.Reader;
			i, rest, code, group: LONGINT;
			done:BOOLEAN;

		PROCEDURE &Init*(in: Streams.Reader);
		BEGIN
			InitReader(Receiver, ReaderBufSize);
			SELF.in := in;
			in.SkipSpaces;
			IF ~tablesReady THEN InitTables END;
			Reset;
		END Init;
		
		PROCEDURE Reset*;
		BEGIN
			Reset^;
			group := 0;  i := 0; code:=0; done:=FALSE;
		END Reset;

		PROCEDURE Receiver(VAR inBuf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR c:CHAR; size4: LONGINT;
		BEGIN
			size4:=size DIV 4 * 4; (* a multiple of 4*)
			ASSERT((size > 0) & (min <= size4) & (min >= 0));
			len:=0;
			IF done THEN res:=Streams.EOF; RETURN 
			ELSE res:=Streams.Ok 
			END;
			(* decoding snipped from CryptoBase64 *)
			REPEAT  in.Char( c )  UNTIL (c > ' ') OR (c = 0X) OR (in.res#Streams.Ok); 
			IF (in.res=Streams.Ok) THEN
				code := dtab[ORD( c )]; 
				WHILE (code >= 0) & (in.res=Streams.Ok) & (len< size4) DO
					group := group*64 + code;  INC( i );
					IF i = 4 THEN  
						inBuf[ofs+len] := CHR( group DIV 10000H MOD 100H );  INC( len );
						inBuf[ofs+len] := CHR( group DIV 100H MOD 100H );  INC( len );
						inBuf[ofs+len] := CHR( group MOD 100H );  INC( len );
						group := 0;  i := 0
					END;
					REPEAT  in.Char( c )  UNTIL (c > ' ') OR (c = 0X) OR (in.res#Streams.Ok);
					code := dtab[ORD( c )];  
				END;
				
				IF c = '=' THEN   (* decode rest *)
					IF i < 2 THEN  res:=Streams.FormatError;   
					ELSE
						group := group*64;  rest := 2;  in.Char( c );  
						IF in.res=Streams.Ok THEN
						IF c = '=' THEN  group := group*64;  rest := 1  END;
							inBuf[ofs+len] := CHR( group DIV 10000H );  INC( len ); 
							IF rest = 2 THEN  inBuf[ofs+len] := CHR( group DIV 100H MOD 100H );  INC( len )  END;
							done:=TRUE;
						ELSE res:=in.res
						END;
					END;
				END;
			ELSE
				res:=in.res;
			END;
			INC(received,len);
		END Receiver;
		
		PROCEDURE Pos*(): LONGINT;
		BEGIN RETURN in.Pos()
		END Pos;

	END Base64Reader;
	
TYPE TYPE DumpWriter*= OBJECT(Streams.Writer);
		PROCEDURE Send* ( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		BEGIN
			res:=Streams.Ok;
		END Send;
	END DumpWriter;



	VAR (*tables for Base64*)
		etab: ARRAY 64 OF CHAR;
		dtab: ARRAY 128 OF INTEGER;
		tablesReady:BOOLEAN;

	PROCEDURE InitTables;
		VAR i, max: INTEGER;
		BEGIN
			max := ORD("Z") - ORD("A");
			FOR i := 0 TO max DO
				etab[i] := CHR( i + ORD("A") )
			END;
			INC(max);
			FOR i := max TO max + ORD("z") - ORD("a") DO
				etab[i] := CHR( i - max + ORD("a") )
			END;
			max := max + ORD("z") - ORD("a") + 1;
			FOR i := max TO max + ORD("9") - ORD("0") DO
				etab[i] := CHR( i - max + ORD("0") )
			END;
			etab[62] := "+";
			etab[63] := "/";
			FOR i := 0 TO 127 DO  dtab[i] := -1  END;
			FOR i := 0 TO 63 DO  dtab[ORD( etab[i] )] := i  END;
			tablesReady:=TRUE;
		END InitTables;


	(*open a monitoring writer on the out stream*)
	PROCEDURE OpenWriterMonitor*(VAR w: Streams.Writer; out:Streams.Writer; monitor: Streams.Writer);
	VAR wm: WriterMonitor;
	BEGIN
		NEW(wm, out, monitor); w:=wm;
	END OpenWriterMonitor;


	PROCEDURE OpenAsynchronousForwarder*(out: Streams.Writer): Streams.Writer;
	VAR a: AsynchronousForwarder;
	BEGIN
		NEW(a, out); RETURN a
	END OpenAsynchronousForwarder;


	(*open a monitoring reader on the in stream*)
	PROCEDURE OpenReaderMonitor*(VAR r: Streams.Reader; in:Streams.Reader; monitor: Streams.Writer);
	VAR rm: ReaderMonitor;
		BEGIN
			NEW(rm, in, monitor); r:=rm;
		END OpenReaderMonitor;

	(*open a size limited writer r on the out stream*)
	PROCEDURE OpenLimitedWriter*(VAR w: Streams.Writer; out: Streams.Writer; size:LONGINT);
	VAR lw: LimitedWriter;
		BEGIN
			NEW(lw, out, size); w:=lw;
		END OpenLimitedWriter;

	(*open a size limited reader r on the in stream*)
	PROCEDURE OpenLimitedReader*(VAR r: Streams.Reader; in: Streams.Reader; size:LONGINT);
	VAR lr: LimitedReader;
		BEGIN
			NEW(lr, in, size); r:=lr;
		END OpenLimitedReader;
(*
(* application example: reader/writer monitors *)
PROCEDURE Test*(context:Commands.Context);
VAR w, log: Streams.Writer;
	r:Streams.Reader;
	s: ARRAY 64 OF CHAR;
	res:BOOLEAN;
BEGIN
	NEW(log, KernelLog.Send, WriterBufSize);

	OpenReaderMonitor(r, context.arg, log); (*monitor the context.arg reader and send monitored input to log *)
	res:=r.GetString(s);

	OpenWriterMonitor(w, context.out, log);(* monitor the context.out writer and send monitored data to log*)
	w.String("holla"); w.Ln;
	w.Update;
END Test;

(* application example: size limited streams *)
PROCEDURE Test2*(context:Commands.Context);
VAR w, log: Streams.Writer;
	r:Streams.Reader;
	s: ARRAY 64 OF CHAR;
	res:BOOLEAN;
BEGIN
	NEW(log, KernelLog.Send, WriterBufSize);

	OpenLimitedReader(r, context.arg, 7); (*monitor the context.arg reader and send monitored input to log *)
	res:=r.GetString(s);
	log.String(s); log.Ln;
	res:=r.GetString(s);
	log.String(s); log.Ln;
	log.Update;

	OpenLimitedWriter(w, log, 6);(* monitor the context.out writer and send monitored data to log*)
	w.String("123456789"); w.Ln; w.Update;
END Test2;
*)
(*
PROCEDURE TestAsync*;
VAR log: Streams.Writer; i: LONGINT;
BEGIN
	NEW(log, KernelLog.Send,128);
	log := OpenAsynchronousForwarder(log);
	FOR i := 0 TO 200 DO
		log.String(" Hallo from asynch "); log.Ln; log.Update;
	END;
	KernelLog.String(" D O N E "); KernelLog.Ln;
END TestAsync;


PROCEDURE TestAsync2*;
VAR log: AsynchronousWriter; i: LONGINT;
BEGIN
	NEW(log, KernelLog.Send,128);
	FOR i := 0 TO 200 DO
		log.String(" Hallo from asynch2 "); log.Ln; log.Update;
	END;
	KernelLog.String(" D O N E "); KernelLog.Ln;
END TestAsync2;

PROCEDURE TestEncode(VAR buf: ARRAY OF CHAR; pos,len:LONGINT);
VAR i:LONGINT;
BEGIN
	FOR i:=pos TO pos+len-1 DO
		IF (buf[i]>="!") & (buf[i]<"~") THEN buf[i]:=CHR(ORD(buf[i])+1) END;
	END;
END TestEncode;

PROCEDURE TestDecode(VAR buf: ARRAY OF CHAR; pos,len:LONGINT);
VAR i:LONGINT;
BEGIN
	FOR i:=pos TO pos+len-1 DO
		IF (buf[i]>"!") & (buf[i]<="~") THEN buf[i]:=CHR(ORD(buf[i])-1) END;
	END;
END TestDecode;

PROCEDURE TestCrypt*(context:Commands.Context);
VAR log: Streams.Writer; secretwriter: EncryptingWriter; secretreader:DecryptingReader; 
	i: LONGINT; 
	string:ARRAY 64 OF CHAR; res:BOOLEAN;
BEGIN
	NEW(log, KernelLog.Send,128);
	
	NEW(secretreader, context.arg, TestDecode);
	res:=secretreader.GetString(string);
	log.String("decoded secret: "); log.String(string); log.Ln; log.String("encoded secret: ");  log.Update;
	
	NEW(secretwriter, log, TestEncode);
	secretwriter.String(string); secretwriter.Update;
END TestCrypt;
*)
(*
PROCEDURE TestBase64*(context:Commands.Context);
VAR secretwriter: Base64Writer; 
	secretreader:Base64Reader; 
	string:ARRAY 64 OF CHAR;
BEGIN
	NEW(secretwriter, context.out);
	secretwriter.String("admin:1234"); (* expect "YWRtaW46MTIzNA==" *)
	secretwriter.Close;
	context.out.Ln; context.out.Update;
	
	NEW(secretreader, context.arg);
	secretreader.String(string);
	context.out.String(string); (* given the argument "YWRtaW46MTIzNA==", expect "admin:1234" *)
	context.out.Ln; context.out.Update;
END TestBase64;
*)
END StreamUtilities.

SystemTools.FreeDownTo StreamUtilities ~

StreamUtilities.Test hello ~
StreamUtilities.Test2 abcd efghijk ~
StreamUtilities.TestAsync abcd efghijk ~
StreamUtilities.TestCrypt IfmmpXpsme ~
StreamUtilities.TestBase64 YWRtaW46MTIzNA== ~

StreamUtilities.TestAsync

StreamUtilities.TestAsync2

