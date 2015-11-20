MODULE POP3Client; (** AUTHOR "TF"; PURPOSE "Simple POP3 Client"; *)

IMPORT
	Streams, Files, IP, DNS, TCP, Strings, KernelLog;

CONST
	StateIdle = 0;
	StateConnected = 1;
	StateAuthenticate = 2;
	StateTransaction = 3;

	ResOk* = 0;
	ResFailed* = 1;
	ResAlreadyOpen* = 2;
	ResServerNotFound* = 3;
	ResNoConnection* = 4;
	ResUserPassError* = 5;
	ResServerNotReady* = 6;
	ResServerFailed* = 7;

TYPE POP3Client* = OBJECT
	VAR connection : TCP.Connection;
		w : Streams.Writer; (* writer on the control connection *)
		r : Streams.Reader; (* reader on the control connection *)
		state : LONGINT;
		message : ARRAY 513 OF CHAR;

		PROCEDURE Connect*(CONST host: ARRAY OF CHAR; port : LONGINT; CONST user, password: ARRAY OF CHAR;  VAR res : LONGINT);
		VAR fadr : IP.Adr;
		BEGIN {EXCLUSIVE}
			res := 0;
			IF state # StateIdle THEN res := ResAlreadyOpen; RETURN END;
			DNS.HostByName(host, fadr, res);
			IF res = DNS.Ok THEN
				NEW(connection);
				connection.Open(TCP.NilPort, fadr, port, res);
				IF res = TCP.Ok THEN
					Streams.OpenWriter(w, connection.Send);
					Streams.OpenReader(r, connection.Receive);
					state := StateConnected;
					IF ReadResponse(message) THEN state := StateAuthenticate;
						IF Login(user, password) THEN state := StateTransaction
						ELSE res := ResUserPassError
						END
					END
				ELSE res := ResNoConnection
				END;
				IF state = StateIdle THEN connection.Close(); w := NIL; r := NIL END
			ELSE res := ResServerNotFound
			END
		END Connect;

		PROCEDURE Login*(CONST user, password : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			w.String("USER "); w.String(user); w.Ln; w.Update;
			IF ReadResponse(message) THEN
				w.String("PASS "); w.String(password); w.Ln; w.Update;
				IF ReadResponse(message) THEN
					RETURN TRUE
				ELSE RETURN FALSE
				END
			ELSE RETURN FALSE
			END;
		END Login;

		PROCEDURE Quit*;
		BEGIN {EXCLUSIVE}
			w.String("QUIT"); w.Ln; w.Update;
			IF ReadResponse(message) THEN END;
			state := StateIdle;
			connection.Close;
			w := NIL; r := NIL
		END Quit;

		PROCEDURE List*;
		VAR nr, len : LONGINT;
		BEGIN {EXCLUSIVE}
			w.String("LIST"); w.Ln; w.Update;
			IF ReadResponse(message) THEN
				WHILE r.Peek() # "." DO
					r.Int(nr, FALSE); r.SkipWhitespace; r.Int(len, FALSE); r.SkipLn;
					KernelLog.String("Message"); KernelLog.Int(nr, 2); KernelLog.String(" "); KernelLog.Int(len, 0);  KernelLog.Ln;
				END;
				r.SkipLn
			END;
		END List;

		PROCEDURE GetMessage*(nr : LONGINT; CONST filename : ARRAY OF CHAR) : BOOLEAN;
		VAR str : ARRAY 1024 OF CHAR; f : Files.File; fw : Files.Writer;
		BEGIN {EXCLUSIVE}
			f := Files.New(filename);
			IF f # NIL THEN Files.OpenWriter(fw, f, 0)
			ELSE RETURN FALSE
			END;

			w.String("RETR "); w.Int(nr, 0); w.Ln; w.Update;
			IF ReadResponse(message) THEN
				REPEAT
					r.Ln(str);
					IF str # "." THEN
						IF str[0] = "." THEN Strings.Delete(str, 0, 1) END;
						fw.String(str); fw.Ln;
						KernelLog.String(str)
					END
				UNTIL (str = ".") OR (r.res # 0);
				fw.Update;
				Files.Register(f);
				RETURN r.res = 0
			ELSE RETURN FALSE
			END;
		END GetMessage;

		PROCEDURE NOOP*;
		BEGIN {EXCLUSIVE}
			w.String("LIST"); w.Ln; w.Update;
			IF ReadResponse(message) THEN
			END
		END NOOP;

		PROCEDURE ReadResponse(VAR message : ARRAY OF CHAR) : BOOLEAN;
		VAR ch : CHAR; tok : ARRAY 4 OF CHAR;
		BEGIN
			ch := r.Get(); r.Token(tok); r.SkipWhitespace;  r.Ln(message);
			KernelLog.String("message = "); KernelLog.String(message); KernelLog.Ln;
			RETURN ch = "+"
		END ReadResponse;

	END POP3Client;

PROCEDURE Test*;
VAR client : POP3Client; res : LONGINT;
BEGIN
	NEW(client);
	client.Connect("lillian.ethz.ch", 110, "user", "password", res);
	IF res = 0 THEN
		 client.List;
		IF client.GetMessage(2, "test.txt") THEN KernelLog.String(" download ok ") ELSE KernelLog.String("download failed.");   END;
	ELSE KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln;
	END;
	client.Quit;
END Test;

END POP3Client.

POP3Client.Test
SystemTools.Free POP3Client


