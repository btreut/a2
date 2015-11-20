MODULE OdUtil;
(* WebDAV, Copyright 2003-7, Edgar Schwarz.
Author.    Edgar Schwarz, edgar@edgarschwarz.de, (es)
Contents. Some Strings: Logging, Lists, ...
Remarks. Local variables are copied for lack of access in parent.
Remarks. TODO: Merge Strings from DAVChain.
*)
IMPORT Clock, Streams, Files, TFLog, Strings, KernelLog;

CONST
	eth = FALSE;
(* $IF ~eth THEN *)
	ModeWriter * = 1;
	ModeFile * = 2;
(* $END *)

TYPE
	Array8 = ARRAY 8 OF CHAR;

TYPE
	Log* = OBJECT (TFLog.Log)
	VAR
		appName : ARRAY 64 OF CHAR;
		logPos : LONGINT;
		logLine : ARRAY 1024 OF CHAR;
		kind : LONGINT;
		locked : BOOLEAN;
		disableLogToOut : BOOLEAN;
		f : Files.File;
(* $IF ~eth THEN *)
		w : Streams.Writer;
		fsw : Files.Writer;
		mode: INTEGER;
(* $ELSE
		w : Files.Writer;
$END *)

		PROCEDURE &Init*(logName : ARRAY OF CHAR);
		BEGIN
			COPY(logName, appName)
		END Init;

		PROCEDURE SetLogFile*(fn : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			IF f # NIL THEN Files.Register(f) END;
			IF fn = "" THEN f := NIL
			ELSE
				f := Files.Old(fn);
				IF f = NIL THEN f := Files.New(fn) END;
(* $IF ~eth THEN *)
				Files.OpenWriter(fsw, f, f.Length());
				w := fsw;
				mode := ModeFile;
(* $ELSE
				Files.OpenWriter(w, f, f.Length())
$END *)
			END
		END SetLogFile;

		PROCEDURE SetLogWriter * (w: Streams.Writer);
		BEGIN {EXCLUSIVE}
			SELF.w := w;
			mode := ModeWriter;
		END SetLogWriter;

		PROCEDURE SetLogToOut*(enabled : BOOLEAN);
		BEGIN {EXCLUSIVE}
			disableLogToOut := ~enabled
		END SetLogToOut;

		PROCEDURE SetKind(kind : LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.kind := kind
		END SetKind;

		PROCEDURE InternalLn;
		BEGIN
			logPos := 0; kind := TFLog.Unknown;
			IF ~disableLogToOut THEN
				KernelLog.Enter;
				IF kind = TFLog.Information THEN KernelLog.String("[I] ") END;
				IF kind = TFLog.Warning THEN KernelLog.String("[W] ") END;
				IF kind = TFLog.Error THEN KernelLog.String("[E] ") END;
				KernelLog.String(appName); KernelLog.String(" : "); KernelLog.String(logLine);
				KernelLog.Exit
			END;
			logLine[0] := 0X;
IF ~eth THEN
			IF mode = ModeWriter THEN w.Ln(); w.Update();
			ELSIF (mode = ModeFile) & (f # NIL) THEN w.Ln(); w.Update(); f.Update() END
ELSE (*
			IF f # NIL THEN Streams.WriteLn(w); Streams.Update(w); f.Update() END;
*) END;
		END InternalLn;

		PROCEDURE Ln*;
		BEGIN {EXCLUSIVE}
			InternalLn
		END Ln;

		PROCEDURE Enter*;
		BEGIN {EXCLUSIVE}
			AWAIT(~locked); locked := TRUE
		END Enter;

		PROCEDURE Exit*;
		BEGIN {EXCLUSIVE}
			InternalLn;
			locked := FALSE
		END Exit;

		PROCEDURE InternalChar(x: CHAR);
		BEGIN
			IF logPos >= LEN(logLine) - 1 THEN InternalLn END;
			logLine[logPos] := x; logLine[logPos + 1] := 0X; INC(logPos);
IF ~eth THEN
			IF mode = ModeWriter THEN w.Char(x);
			ELSIF (mode = ModeFile) & (f # NIL ) THEN w.Char(x) END
ELSE (*
			IF f # NIL THEN Streams.Write(w, x) END
*) END
		END InternalChar;

		PROCEDURE Char*(x: CHAR);
		BEGIN {EXCLUSIVE}
			InternalChar(x)
		END Char;

		PROCEDURE InternalString*(VAR x: ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			WHILE (i < LEN(x)) & (x[i] # 0X) DO InternalChar(x[i]); INC(i) END
		END InternalString;

		PROCEDURE String*(x: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			InternalString(x)
		END String;

		PROCEDURE Hex*(x, w: LONGINT);
		VAR i, j: LONGINT; buf: ARRAY 10 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF w >= 0 THEN j := 8 ELSE j := 2; w := -w END;
			FOR i := j+1 TO w DO InternalChar(" ") END;
			FOR i := j-1 TO 0 BY -1 DO
				buf[i] := CHR(x MOD 10H + 48);
				IF buf[i] > "9" THEN
					buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
				END;
				x := x DIV 10H
			END;
			buf[j] := 0X;
			InternalString(buf)
		END Hex;

		PROCEDURE Int*(x, w: LONGINT);
		VAR i, x0: LONGINT; a: ARRAY 12 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF x < 0 THEN
				IF x = MIN(LONGINT) THEN
					DEC(w, 11);
					WHILE w > 0 DO Char(" "); DEC(w) END;
					a := "-2147483648"; InternalString(a);
					RETURN
				ELSE
					DEC(w); x0 := -x
				END
			ELSE
				x0 := x
			END;
			i := 0;
			REPEAT
				a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
			UNTIL x0 = 0;
			WHILE w > i DO InternalChar(" "); DEC(w) END;
			IF x < 0 THEN InternalChar("-") END;
			REPEAT DEC(i); InternalChar(a[i]) UNTIL i = 0
		END Int;

		PROCEDURE TimeStamp*;
		TYPE TimeDate = RECORD h, m, s, day,month,year: LONGINT END;
			VAR s : ARRAY 32 OF CHAR;
				now : TimeDate;

			PROCEDURE LZ(v, len: LONGINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
			VAR i: LONGINT;
			BEGIN
				FOR i := 1 TO len DO s[pos+len-i] := CHR(ORD("0")+v MOD 10); v := v DIV 10 END;
				INC(pos, len)
			END LZ;

			PROCEDURE GetTime(VAR dt: TimeDate);
			BEGIN
				Clock.Get(dt.h, dt.year);
				dt.s := dt.h MOD 64; dt.h := dt.h DIV 64;
				dt.m := dt.h MOD 64; dt.h := dt.h DIV 64;
				dt.h := dt.h MOD 24;
				dt.day := dt.year MOD 32; dt.year := dt.year DIV 32;
				dt.month := dt.year MOD 16; dt.year := dt.year DIV 16;
				INC(dt.year, 1900)
			END GetTime;

			PROCEDURE TimeDateToStr(dt: TimeDate; VAR s: ARRAY OF CHAR);
			VAR p: LONGINT;
			BEGIN
				LZ(dt.day, 2, s, p); s[p] := "."; INC(p);
				LZ(dt.month, 2, s, p); s[p] := "."; INC(p);
				LZ(dt.year, 2, s, p); s[p] := " "; INC(p);
				LZ(dt.h, 2, s, p); s[p] := ":"; INC(p);
				LZ(dt.m, 2, s, p); s[p] := ":"; INC(p);
				LZ(dt.s, 2, s, p); s[p] := 0X
			END TimeDateToStr;

		BEGIN
			GetTime(now);
			TimeDateToStr(now, s);
			InternalString(s); InternalChar(" ")
		END TimeStamp;

		PROCEDURE Close*;
		BEGIN
			IF f # NIL THEN Files.Register(f)
			END
		END Close;

	END Log;

CONST
	CollCh * = "/";
TYPE
	Link * = OBJECT (* POINTER TO RECORD *)
		 VAR next * : Link;
		PROCEDURE &link*;
			BEGIN next := NIL;
			END link;
		PROCEDURE add * (new: Link);
	   	 VAR old: Link;
			BEGIN old := SELF;
				WHILE old.next # NIL DO old := old.next;  END;
				old.next := new;
			END add;
	END Link;
(* Simple list of strings which allow appending and iteration.  Usage:  *)
CONST
	LineLen * = 128;
TYPE
	Line * = ARRAY LineLen OF CHAR;
	Lines * = OBJECT (* POINTER TO RECORD *)
		VAR
			line * : Line;
			next * : Lines;

		PROCEDURE &init*;
			BEGIN line[0] := 0X; next := SELF;
			END init;

		(** Append a new line at the end. *)
		PROCEDURE add * (CONST line: ARRAY OF CHAR);
		    VAR old, new: Lines;
			BEGIN old := SELF;
				IF old = old.next THEN (* first entry *)
					COPY(line, old.line); old.next := NIL;
				ELSE (* additional entry *)
					NEW(new); COPY(line, new.line); new.next := NIL;
					WHILE old.next # NIL DO old := old.next;  END;
					old.next := new;
				END;
			END add;
		(** Find lines which also are in SELF. *)
		PROCEDURE in * (target: Lines): Lines;
		    VAR in, self: Lines;
			BEGIN
				NEW(in);
				WHILE target # NIL DO
					self := SELF;
					LOOP
						IF self = NIL THEN EXIT; END;
						IF self.line = target.line THEN in.add(target.line); EXIT; END;
						self := self.next;
					END;
					target := target.next;
				END;
				IF in = in.next THEN in := NIL; END;
				RETURN in;
			END in;

		(** Find lines which aren't  in SELF. *)
		PROCEDURE notIn * (target: Lines): Lines;
		    VAR notIn, self: Lines;
			BEGIN
				NEW(notIn);
				WHILE target # NIL DO
					self := SELF;
					LOOP
						IF self = NIL THEN notIn.add(target.line); EXIT; END;
						IF self.line = target.line THEN EXIT; END;
						self := self.next;
					END;
					target := target.next;
				END;
				IF notIn = notIn.next THEN notIn := NIL; END;
				RETURN notIn;
			END notIn;
	END Lines;

Dict *= OBJECT
	VAR
		key* : ARRAY 64 OF CHAR;
		value* : ANY;
		next* : Dict;

	PROCEDURE &Init*;
	BEGIN
		key := "";
		next := NIL;
	END Init;

	PROCEDURE EqualsI(VAR buf: ARRAY OF CHAR; with: ARRAY OF CHAR): BOOLEAN;
	VAR j: LONGINT;
	BEGIN
		j := 0; WHILE (with[j] # 0X) & (CAP(buf[j]) = CAP(with[j])) DO INC(j) END;
		RETURN CAP(with[j]) = CAP(buf[j])
	END EqualsI;

	PROCEDURE has*(fieldName: ARRAY OF CHAR) : BOOLEAN;
	VAR af: Dict;
	BEGIN
		af := SELF;
		WHILE (af # NIL) & (~EqualsI(af.key, fieldName)) DO af := af.next END;
		RETURN af # NIL
	END has;

	PROCEDURE get*(fieldName: ARRAY OF CHAR; VAR value : ANY) : BOOLEAN;
	VAR af: Dict;
	BEGIN
		af := SELF;
		WHILE (af # NIL) & (~EqualsI(af.key, fieldName)) DO af := af.next END;
		IF af # NIL THEN
			value := af.value;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END get;

	PROCEDURE set*(fieldName: ARRAY OF CHAR;  value: ANY);
	VAR a: Dict;
	BEGIN
		IF SELF.key = "" THEN COPY(fieldName, key); END; (* Use also anchor. *)
		a := SELF; WHILE (a.next # NIL) & (a.key # fieldName) DO a := a.next END;
		IF (a.key # fieldName) THEN
			NEW(a.next); a := a.next
		END;
		COPY(fieldName, a.key); a.value := value;
	END set;
END Dict;

VAR
	MsgLog * : Log; (* If # NIL use it for Msg<n> *)

(*****************  Procedures  ************************)
(* Add a trailing '/' *)
PROCEDURE padColl*(VAR conf: ARRAY OF CHAR);
BEGIN
	IF conf = "" THEN
		COPY(CollCh, conf);
	ELSIF conf[Strings.Length(conf)-1] # CollCh THEN
		Strings.Append(conf, CollCh);
	END;
END padColl;

(* Remove a trailing '/' *)
PROCEDURE unpadColl*(VAR conf: ARRAY OF CHAR);
BEGIN
	IF conf # "" THEN
		IF (conf[Strings.Length(conf)-1] = CollCh) THEN
			conf[Strings.Length(conf)-1] := 0X;
		END;
	END;
END unpadColl;
(* don't write anything. Just for counting what's written to a writer. *)
PROCEDURE Dev0 * (CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN END Dev0;



(* Some utility procedures to write a couple of strings. with a linefeed. A blank is inserted automatically.
	To concat two string on the output add a "" parameter as glue in between. *)
PROCEDURE I * (i: LONGINT): Array8;
VAR s: Array8;
BEGIN
	Strings.IntToStr(i, s);
	RETURN s;
END I;

PROCEDURE B * (b: BOOLEAN): Array8;
VAR s: Array8;
BEGIN
	IF b THEN s := "TRUE";
	ELSE s := "FALSE"; END;
	RETURN s;
END B;

PROCEDURE msg1(CONST s1: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.String(s1);
	ELSE
		KernelLog.String(s1);
	END;
END msg1;
PROCEDURE Msg1 * (CONST s1: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg1(s1); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg1(s1); KernelLog.Exit;
	END;
END Msg1;

PROCEDURE msg2(CONST s1,s2: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		IF s1 # "" THEN MsgLog.String(s1); MsgLog.Char(' '); END; msg1(s2);
	ELSE
		IF s1 # "" THEN KernelLog.String(s1); KernelLog.Char(' '); END; msg1(s2);
	END;
END msg2;
PROCEDURE Msg2*(CONST s1,s2: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg2(s1, s2); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg2(s1,s2); KernelLog.Exit;
	END;
END Msg2;

PROCEDURE msg3(CONST s1,s2,s3: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		IF s1 # "" THEN MsgLog.String(s1); MsgLog.Char(' '); END; msg2(s2,s3);
	ELSE
		IF s1 # "" THEN KernelLog.String(s1); KernelLog.Char(' '); END; msg2(s2,s3);
	END;
END msg3;
PROCEDURE Msg3*(CONST s1,s2,s3: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg3(s1, s2, s3); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg3(s1,s2,s3); KernelLog.Exit;
	END;
END Msg3;

PROCEDURE msg4(CONST s1,s2,s3,s4: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		IF s1 # "" THEN MsgLog.String(s1); MsgLog.Char(' '); END; msg3(s2,s3,s4);
	ELSE
		IF s1 # "" THEN KernelLog.String(s1); KernelLog.Char(' '); END; msg3(s2,s3,s4);
	END;
END msg4;
PROCEDURE Msg4*(CONST s1,s2,s3,s4: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg4(s1, s2, s3, s4); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg4(s1,s2,s3,s4); KernelLog.Exit;
	END;
END Msg4;

PROCEDURE msg5(CONST s1,s2,s3,s4,s5: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		IF s1 # "" THEN MsgLog.String(s1); MsgLog.Char(' '); END; msg4(s2,s3,s4,s5);
	ELSE
		IF s1 # "" THEN KernelLog.String(s1); KernelLog.Char(' '); END; msg4(s2,s3,s4,s5);
	END;
END msg5;
PROCEDURE Msg5*(CONST s1,s2,s3,s4,s5: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg5(s1, s2, s3, s4, s5); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg5(s1,s2,s3,s4,s5); KernelLog.Exit;
	END;
END Msg5;

PROCEDURE msg6(CONST s1,s2,s3,s4,s5,s6: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		IF s1 # "" THEN MsgLog.String(s1); MsgLog.Char(' '); END; msg5(s2,s3,s4,s5,s6);
	ELSE
		IF s1 # "" THEN KernelLog.String(s1); KernelLog.Char(' '); END; msg5(s2,s3,s4,s5,s6);
	END;
END msg6;

PROCEDURE Msg6*(CONST s1,s2,s3,s4,s5,s6: ARRAY OF CHAR);
BEGIN
	IF MsgLog # NIL THEN
		MsgLog.Enter; msg6(s1, s2, s3, s4, s5, s6); MsgLog.Exit;
	ELSE
		KernelLog.Enter; msg6(s1,s2,s3,s4,s5,s6); KernelLog.Exit;
	END;
END Msg6;

BEGIN
	MsgLog := NIL;
END OdUtil.

System.Free OdUtil ~