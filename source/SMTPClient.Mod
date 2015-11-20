MODULE SMTPClient;
(** AUTHOR "TF"; PURPOSE "SMTP client for sending mail"; *)

(* SMTP RFC 821 client *)

IMPORT
	Mail, IP, DNS, TCP, Streams, KernelLog;

CONST
	Trace = FALSE;
	MaxRecipients* = 20;

	Ok* = 0;
	NotConnected* = 1;
	SendFailed* = 101;
	TooManyRecipients* = 5001;

TYPE
	SMTPSession* = OBJECT(Mail.Sender)
	VAR
		connection : TCP.Connection;
		sendReady, open : BOOLEAN;
		r : Streams.Reader;
		w* : Streams.Writer;

		PROCEDURE &Init*;
		BEGIN sendReady := FALSE; open := FALSE
		END Init;

		PROCEDURE GetSendReady*():BOOLEAN;
		BEGIN RETURN sendReady
		END GetSendReady;

		PROCEDURE GetReplyCode*(VAR code, res :LONGINT);
		VAR msg : ARRAY 256 OF CHAR;
		BEGIN
			r.Ln(msg);
			code := ORD(msg[0]) - ORD("0"); code := code * 10 + ORD(msg[1]) - ORD("0"); code := code * 10 + ORD(msg[2]) - ORD("0");
			IF Trace THEN KernelLog.Enter; KernelLog.String(msg); KernelLog.Exit END;
			WHILE (msg[3] = "-") & (r.res = Streams.Ok) DO
				r.Ln(msg);
				IF Trace THEN KernelLog.Enter; KernelLog.String(msg); KernelLog.Exit END
			END;
			IF r.res = Streams.Ok THEN res := Ok ELSE res := r.res END
		END GetReplyCode;

		PROCEDURE SendCommand*(CONST cmd, arg : ARRAY OF CHAR; VAR res:LONGINT);
		BEGIN
			IF Trace THEN
				KernelLog.Enter; KernelLog.String("CMD:"); KernelLog.String(cmd); KernelLog.String(" "); KernelLog.String(arg); KernelLog.Exit;
			END;
			w.String(cmd); w.String(" "); w.String(arg); w.Ln; w.Update;
			IF w.res = Streams.Ok THEN res := Ok ELSE res := w.res END
		END SendCommand;

		PROCEDURE Open*(CONST server, thisHost : ARRAY OF CHAR; port: LONGINT; VAR result : LONGINT);
		VAR fip : IP.Adr;
				res, reply : LONGINT;
		BEGIN
			result := NotConnected;
			DNS.HostByName(server, fip, res);
			IF res = DNS.Ok THEN
				NEW(connection);
				connection.Open(TCP.NilPort, fip, port, res);
				IF res = TCP.Ok THEN
					open := TRUE;
					Streams.OpenReader(r, connection.Receive);
					Streams.OpenWriter(w, connection.Send);
					GetReplyCode(reply, res);
					IF (res = Streams.Ok) & (reply >= 200) & (reply < 300) THEN
						SendCommand("HELO", thisHost, res);
						IF res = Streams.Ok THEN
							GetReplyCode(reply, res);
							IF (res = Streams.Ok) & (reply >= 200) & (reply < 300) THEN
								sendReady := TRUE;
								result := Ok
							END
						END
					ELSE
						Close
					END
				END
			END
		END Open;

		PROCEDURE Close*;
		VAR res : LONGINT;
		BEGIN
			IF open THEN
				sendReady := FALSE; open := FALSE;
				SendCommand("QUIT", "", res);
				connection.Close
			END
		END Close;

		PROCEDURE StartMailFrom*(CONST fromAddr : ARRAY OF CHAR) : BOOLEAN;
		VAR reply, res: LONGINT;
		BEGIN
			w.String("MAIL FROM:<");  w.String(fromAddr); w.String(">"); w.Ln; w.Update;
			IF w.res = Streams.Ok THEN
				GetReplyCode(reply, res);
				RETURN (res = Ok) & (reply = 250)
			ELSE RETURN FALSE
			END;
		END StartMailFrom;

		PROCEDURE SendTo*(CONST toAddr : ARRAY OF CHAR) :BOOLEAN;
		VAR reply, res: LONGINT;
		BEGIN
			w.String("RCPT TO:<");  w.String(toAddr); w.String(">"); w.Ln; w.Update;
			IF w.res = Streams.Ok THEN
				GetReplyCode(reply, res);
				RETURN (res = Ok) & (reply = 250)
			ELSE RETURN FALSE
			END;
		END SendTo;

		PROCEDURE StartData*() : BOOLEAN;
		VAR reply, res: LONGINT;
		BEGIN
			SendCommand("DATA", "", res);
			IF res = Ok THEN
				GetReplyCode(reply, res);
				RETURN ((res = Ok) & (reply = 354))
			ELSE RETURN FALSE
			END
		END StartData;

		PROCEDURE PrepareToSend*(m: Mail.Message; VAR result : LONGINT);
		VAR name, address : Mail.MailAddress; i: LONGINT;
		BEGIN
			result := SendFailed;
			ASSERT(m # NIL);
			(* FROM *)
			 m.GetFrom(name, address);
			(* TO *)
			 IF StartMailFrom(address) THEN
				FOR i := 0 TO m.GetNofTo() - 1 DO
					m.GetTo(i, name, address); IF ~SendTo(address) THEN Close; RETURN END
				END;
				FOR i := 0 TO m.GetNofCc() - 1 DO
					m.GetCc(i, name, address); IF ~SendTo(address) THEN Close; RETURN END
				END;
				FOR i := 0 TO m.GetNofBcc() - 1 DO
					m.GetBcc(i, name, address); IF ~SendTo(address) THEN Close; RETURN END
				END;
			ELSE Close; RETURN
			END;
			(* DATA *)
			IF StartData() THEN result := Ok ELSE Close END;
		END PrepareToSend;

		PROCEDURE SendRawLine*(CONST s : ARRAY OF CHAR);
		BEGIN
			w.String(s); w.Ln
		END SendRawLine;

		PROCEDURE FinishSendRaw*() : BOOLEAN;
		VAR reply, res: LONGINT;
		BEGIN
			w.Update;
			GetReplyCode(reply, res);
			RETURN (res = Ok) & (reply = 250)
		END FinishSendRaw;

		PROCEDURE SendComplete*(m: Mail.Message; VAR result : LONGINT);
		VAR i: LONGINT;
			name, address : Mail.MailAddress;
			date, id : ARRAY 64 OF CHAR;
			subject, content : ARRAY 256 OF CHAR;
			l : Mail.Line;
		BEGIN {EXCLUSIVE}
			PrepareToSend(m, result);
			IF result = 0 THEN
				m.GetDate(date);
				IF date # "" THEN w.String("Date : "); w.String(date); w.Ln END;

				m.GetSubject(subject);
				IF subject # "" THEN w.String("Subject : "); w.String(subject); w.Ln END;

				m.GetFrom(name, address);
				w.String("From:");
				IF name # "" THEN
					w.String(name); w.String(" <");
					w.String(address); w.String(">");
				ELSE
					w.String(address);
				END;
				w.Ln;

				m.GetSender(name, address);
				IF address # "" THEN
					w.String("Sender:");
					IF name # "" THEN
						w.String(name); w.String(" <");
						w.String(address); w.String(">");
					ELSE
						w.String(address);
					END;
					w.Ln
				END;

				IF m.GetNofReplyTo() > 0 THEN
					w.String("Reply-To:");
					FOR i := 0 TO m.GetNofReplyTo() - 1 DO
						m.GetReplyTo(i, name, address);
						IF name # "" THEN
							w.String(name); w.String(" <");
							w.String(address); w.String(">");
						ELSE
							w.String(address);
						END;
						IF i < m.GetNofReplyTo() - 1 THEN w.String(",") END;
						w.Ln;
					END
				END;

				w.String("To:");
				FOR i := 0 TO m.GetNofTo() - 1 DO
					m.GetTo(i, name, address);
						w.Char(" ");
					IF name # "" THEN
						w.String(name); w.String(" <");
						w.String(address); w.String(">");
					ELSE
						w.String(address);
					END;
					IF i < m.GetNofTo() - 1 THEN w.String(",") END;
					w.Ln;
				END;

				IF m.GetNofCc() > 0 THEN
					w.String("Cc:");
					FOR i := 0 TO m.GetNofCc() - 1 DO
						m.GetCc(i, name, address);
						w.Char(" ");
						IF name # "" THEN
							w.String(name); w.String(" <");
							w.String(address); w.String(">");
						ELSE
							w.String(address);
						END;
						IF i < m.GetNofCc() - 1 THEN w.String(",") END;
						w.Ln;
					END
				END;

				IF m.GetNofBcc() > 0 THEN
					w.String("Bcc:");
					FOR i := 0 TO m.GetNofBcc() - 1 DO
						m.GetBcc(i, name, address);
						w.Char(" ");
						IF name # "" THEN
							w.String(name); w.String(" <");
							w.String(address); w.String(">");
						ELSE
							w.String(address);
						END;
						IF i < m.GetNofBcc() - 1 THEN w.String(",") END;
						w.Ln;
					END;
				END;
				
				IF m.GetNofHeaders() > 0 THEN
					FOR i := 0 TO m.GetNofHeaders() - 1 DO
						m.GetHeader(i, id, content);
						w.String(id); w.String(" : "); w.String(content); w.Ln;
					END;
				END;
				
				w.Ln;

				FOR i := 0 TO m.GetNofLines() - 1 DO
					m.GetLine(i, l);
					IF l.data # NIL THEN w.String(l.data^) END; w.Ln;
				END;
				w.Ln; w.String("."); w.Ln;
				IF FinishSendRaw() THEN result := Ok END
			END;
		END SendComplete;
	END SMTPSession;

END SMTPClient.
