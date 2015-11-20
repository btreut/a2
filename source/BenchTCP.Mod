MODULE BenchTCP;	(* pjm *)

IMPORT Kernel, IP, KernelLog, TCP, DNS, Strings, Commands;

CONST
	BufSize = 32768;	(* multiple of 1024 *)

	CloseTimeout = 10000;	(* ms *)

	EchoPort = 7; DiscardPort = 9; (*ChargenPort = 19;*) TimePort = 37;

	Header = "BenchTCP: ";	(* in log *)

TYPE
	Bytes = POINTER TO ARRAY OF CHAR;

TYPE
	Sender = OBJECT
		VAR c: TCP.Connection; num, num0, res: LONGINT; buf: Bytes; done: BOOLEAN;

		PROCEDURE &Init*(c: TCP.Connection; buf: Bytes; num: LONGINT);
		BEGIN
			ASSERT(LEN(buf^) >= 1024);
			SELF.c := c; SELF.buf := buf; SELF.num := num;
			done := FALSE
		END Init;

		PROCEDURE Join(): LONGINT;
		BEGIN {EXCLUSIVE}
			AWAIT(done);
			RETURN res
		END Join;

	BEGIN {ACTIVE}
		res := 0;
		WHILE (res = 0) & (num > 0) DO
			num0 := LEN(buf^) DIV 1024;
			IF num0 > num THEN num0 := num END;
			c.Send(buf^, 0, num0*1024, FALSE, res);
			DEC(num, num0)
		END;
		BEGIN {EXCLUSIVE} done := TRUE END
	END Sender;

TYPE
	Tester = OBJECT
		VAR
			c: TCP.Connection; num, num0, res, port, total, len: LONGINT; fip: IP.Adr;
			timer: Kernel.MilliTimer; sender: Sender; server: ARRAY 64 OF CHAR;
			time:HUGEINT;

		PROCEDURE &Init*(CONST server: ARRAY OF CHAR; num, port: LONGINT);
		BEGIN
			COPY(server, SELF.server); SELF.num := num; SELF.port := port;
			DNS.HostByName(server, fip, res);
			IF res # 0 THEN Message(server, " DNS lookup failed", res) END
		END Init;

	BEGIN {ACTIVE}
		IF res = 0 THEN
			Message(server, " opening", 0);
			Kernel.SetTimer(timer, 0);
			NEW(c); c.Open(TCP.NilPort, fip, port, res);
			IF res = 0 THEN
				IF port=TimePort THEN
					c.Receive(buf^, 0, 4, 4, len, res);
					total:=len;
					time:=((HUGEINT(ORD(buf[0]))*256+ORD(buf[1]))*256 + ORD(buf[2]))*256 + ORD(buf[3]);
					KernelLog.String("ClientTime: "); KernelLog.Int(time,6); KernelLog.String(" : ");
					KernelLog.Int(time MOD 60,6); time:=time DIV 60; KernelLog.String("sec");
					KernelLog.Int(time MOD 60,6); time:=time DIV 60; KernelLog.String("min");
					KernelLog.Int(time MOD 24,6); time:=time DIV 24; KernelLog.String("hh");
					KernelLog.Int(time,7);  KernelLog.String("days since 1.1.1900");
					KernelLog.Ln;   
				ELSE
					NEW(sender, c, buf, num);
					IF port = EchoPort THEN
						total := num*2;
						WHILE (res = 0) & (num > 0) DO
							num0 := LEN(buf^) DIV 1024;
							IF num0 > num THEN num0 := num END;
							
							c.Receive(buf^, 0, num0*1024, num0*1024, len, res);
							DEC(num, num0)
						END
					ELSE
						total := num
					END;
					IF res = 0 THEN res := sender.Join() END;
				END;
				c.Close();
				IF res = 0 THEN c.AwaitState(TCP.ClosedStates, {}, CloseTimeout, res) END;
				IF (res = 0)&(port#TimePort) THEN Report(Kernel.Elapsed(timer), port, total, server) END
			END;
			IF res # 0 THEN Message(server, " connection failed", res) END
		END
	END Tester;

VAR
	buf: Bytes;


PROCEDURE Message(CONST msg1, msg2: ARRAY OF CHAR; res: LONGINT);
BEGIN
	KernelLog.String(Header); KernelLog.String(msg1); KernelLog.String(msg2);
	IF res # 0 THEN
		KernelLog.String(", res="); KernelLog.Ln;
	END;
	KernelLog.Ln;
END Message;


PROCEDURE Report(ms, port, total: LONGINT; CONST msg: ARRAY OF CHAR);
VAR
	realStr: ARRAY 128 OF CHAR;

BEGIN
	KernelLog.String(Header);
	IF port = DiscardPort THEN KernelLog.String("Discard ");
	ELSIF port = EchoPort THEN KernelLog.String("Echo ");
	ELSE KernelLog.String("Chargen ");
	END;
	KernelLog.Int(total, 0); KernelLog.String("KB, ");
	KernelLog.Int(ms, 0); KernelLog.String("ms, ");
	IF ms # 0 THEN
		KernelLog.Int(ENTIER(total/ms*1000.0), 0); KernelLog.String("KB/s,");
		Strings.FloatToStr(total/1024.0*8/ms*1000.0, 0,0,0,realStr);
		KernelLog.String(realStr); KernelLog.String("Mb/s");
	ELSE
		KernelLog.String(" N/A");
	END;
	KernelLog.String(", "); KernelLog.String(msg);
	KernelLog.Ln;

END Report;


(** server KB *)
PROCEDURE Discard*(context : Commands.Context);
VAR t: Tester; num: LONGINT; server: ARRAY 64 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(server);
	context.arg.SkipWhitespace; context.arg.Int(num, FALSE);
	NEW(t, server, num, DiscardPort);
END Discard;


(** server KB *)
PROCEDURE Echo*(context : Commands.Context);
VAR t: Tester; num: LONGINT; server: ARRAY 64 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(server);
	context.arg.SkipWhitespace; context.arg.Int(num, FALSE);
	NEW(t, server, num, EchoPort);
END Echo;

(** server KB *)
PROCEDURE Time*(context : Commands.Context);
VAR t: Tester; num: LONGINT; server: ARRAY 64 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(server);
	NEW(t, server, 0, TimePort);
END Time;


BEGIN
	NEW(buf, BufSize)
END BenchTCP.

BenchTCP.Discard 192.168.0.2 1000
BenchTCP.Discard portnoy.ethz.ch 10
BenchTCP.Discard lillian.ethz.ch 40000
BenchTCP.Discard bluebottle.ethz.ch 40

BenchTCP.Echo lillian.ethz.ch 40000 ~
BenchTCP.Echo bluebottle.ethz.ch 40

BenchTCP.Time 127.0.0.1 ~

BenchTCP.Echo FE80::230:1BFF:FEAF:EEF2 100000~
BenchTCP.Discard FE80::230:1BFF:FEAF:EEF2 100000~
SystemTools.Free BenchTCP