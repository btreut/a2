MODULE RMSMTP; (** AUTHOR "retmeier"; PURPOSE "A SMTP client"; *)

IMPORT
	SMTPClient, Commands, KernelLog, Strings, Streams, Classes := TFClasses, IMAPClient, IMAPUtilities;

CONST
	DEBUG = TRUE;
	CR = 0DX; LF = 0AX;
	Port = 25;

	OK* = 0;
	CONNECTIONERROR* = 1;
	FROMERROR* = 2;
	TOERROR* = 3;
	CCERROR* = 4;
	BCCERROR* = 5;
	DATAERROR* = 6;
	FINISHERROR* = 7;

TYPE
	String* = Strings.String;


PROCEDURE Send*(context : Commands.Context);
VAR
	message: IMAPClient.Message;
	server, thisHost: ARRAY 1024 OF CHAR;
	ret: LONGINT;
BEGIN
	(* parse the message from the input string *)
	context.arg.SkipWhitespace; context.arg.String(server);
	context.arg.SkipWhitespace; context.arg.String(thisHost);

	NEW(message);
	parse(context, message);

	message.header.date := IMAPUtilities.getRFC822Date();
	ret := SendMessage(message, server, thisHost);
END Send;

PROCEDURE SendMessage*(message: IMAPClient.Message; CONST server, thisHost: ARRAY OF CHAR): LONGINT;
VAR
	smtp: SMTPClient.SMTPSession;
	i, res: LONGINT;
	returnValue: LONGINT;
	w: Streams.Writer;
	p: ANY;
	s: String;
	address: IMAPUtilities.Address;
BEGIN
	(* start communication with server *)
	NEW(smtp);
	smtp.Open(server, thisHost, Port, res);
	IF res # SMTPClient.Ok THEN
		KernelLog.String("Failure: it wasn't possible to connect to server: ");	KernelLog.String(server); KernelLog.Ln();
		RETURN CONNECTIONERROR;
	END;

	(* send MAIL FROM command *)
	IF (message.header.from # NIL) & (message.header.from.GetCount() > 0) THEN
		p := message.header.from.GetItem(0);
		address := p(IMAPUtilities.Address);
		AddressToSMTPString(address, s);
	ELSE
		NEW(s, Strings.Length(thisHost)+1);
		Strings.Copy(thisHost, 0, Strings.Length(thisHost), s^);
	END;

	IF DEBUG THEN
		KernelLog.String("MAIL FROM: "); KernelLog.String(s^); KernelLog.Ln();
	END;

	IF ~smtp.StartMailFrom(s^) THEN
		KernelLog.String("Error occured while trying to send the Command: MAIL FROM. Maybe no from header-field was specified or it was errorous"); KernelLog.Ln();
		smtp.Close();
		RETURN FROMERROR;
	END;

	(* send RCPT TO Commands *)
	IF message.header.to # NIL THEN
		i := 0;
		WHILE i < message.header.to.GetCount() DO
			p := message.header.to.GetItem(i);
			address := p(IMAPUtilities.Address);
			AddressToSMTPString(address, s);
			IF DEBUG THEN
				KernelLog.String("RCPT: "); KernelLog.String(s^); KernelLog.Ln();
			END;

			IF ~smtp.SendTo(s^) THEN
				KernelLog.String("Error occured while trying to send the Command: RCPT TO for the receivers specified in To"); KernelLog.Ln();
				smtp.Close();
				RETURN TOERROR;
			END;
			INC(i);
		END;
	END;
	IF message.header.cc # NIL THEN
		i := 0;
		WHILE i < message.header.cc.GetCount() DO
			p := message.header.cc.GetItem(i);
			address := p(IMAPUtilities.Address);
			AddressToSMTPString(address, s);

			IF ~smtp.SendTo(s^) THEN
				KernelLog.String("Error occured while trying to send the Command: RCPT TO for the receivers specified in Cc"); KernelLog.Ln();
				smtp.Close();
				RETURN CCERROR;
			END;
			INC(i);
		END;
	END;
	IF message.header.bcc # NIL THEN
		i := 0;
		WHILE i < message.header.bcc.GetCount() DO
			p := message.header.bcc.GetItem(i);
			address := p(IMAPUtilities.Address);
			AddressToSMTPString(address, s);

			IF ~smtp.SendTo(s^) THEN
				KernelLog.String("Error occured while trying to send the Command: RCPT TO for the receivers specified in Bcc"); KernelLog.Ln();
				smtp.Close();
				RETURN BCCERROR;
			END;
			INC(i);
		END;
	END;

	(* start sending the message data *)
	IF ~smtp.StartData() THEN
		KernelLog.String("Error occured while trying to send the Command: DATA"); KernelLog.Ln();
		smtp.Close();
		RETURN DATAERROR;
	END;

	s := message.ToString();

	w := smtp.w;
	w.String(s^);
	w.Ln(); w.String("."); w.Ln();

	IF smtp.FinishSendRaw() THEN
		IF DEBUG THEN
			KernelLog.String("send was sucessful"); KernelLog.Ln();
		END;
		returnValue := OK;
	ELSE
		KernelLog.String("send failed"); KernelLog.Ln();
		returnValue := FINISHERROR;
	END;

	smtp.Close();

	RETURN returnValue;
END SendMessage;

PROCEDURE parse*(context : Commands.Context; VAR message: IMAPClient.Message);
VAR
	token: ARRAY 128 OF CHAR;
	buffer: Strings.Buffer;
	string: String;
	w: Streams.Writer;
	c: CHAR;
	headerDone : BOOLEAN;
	pos: LONGINT;
	addresses: Classes.List;
	header: IMAPClient.HeaderElement;
BEGIN
	(* process header of the message *)
	NEW(header);

	context.arg.SkipWhitespace();
	headerDone := FALSE;
	WHILE ~headerDone DO
		pos := context.arg.Pos();
		context.arg.Token(token);

		Strings.UpperCase(token);

		IF token = "TO:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			IMAPUtilities.ParseAddresses(string, addresses);
			header.to := addresses;
		ELSIF token = "CC:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			IMAPUtilities.ParseAddresses(string, addresses);
			header.cc := addresses;
		ELSIF token = "BCC:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			IMAPUtilities.ParseAddresses(string, addresses);
			header.bcc := addresses;
		ELSIF token = "FROM:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			IMAPUtilities.ParseAddresses(string, addresses);
			header.from := addresses;
		ELSIF token = "SENDER:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			IMAPUtilities.ParseAddresses(string, addresses);
			header.sender := addresses;
		ELSIF token = "SUBJECT:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			header.subject := string;
		ELSIF token = "DATE:" THEN
			context.arg.SkipSpaces();
			string := readRestOfLine(context);
			header.date := string;
		ELSE
			headerDone := TRUE;
		END;

	END;
	message.header := header;

	(* process message Body *)
	context.arg.SetPos(pos);

	NEW(buffer, 16);
	w := buffer.GetWriter();

	context.arg.Char(c);
	WHILE c # 0X DO
		w.Char(c);
		context.arg.Char(c);
	END;

	string := buffer.GetString();

	message.message := string;
END parse;

PROCEDURE readRestOfLine*(context : Commands.Context): String;
VAR
	string: String;
	buffer: Strings.Buffer;
	w: Streams.Writer;
	c: CHAR;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	context.arg.Char(c);
	WHILE(c # 0X) & (c # LF) & (c # CR) DO
		w.Char(c);
		context.arg.Char(c);
	END;
	IF c = CR THEN
		c := context.arg.Peek();
		IF c = LF THEN
			c := context.arg.Get();
		END;
	END;
	string := buffer.GetString();
	RETURN string;
END readRestOfLine;

PROCEDURE AddressToSMTPString(address: IMAPUtilities.Address; VAR string: String);
VAR buffer: Strings.Buffer; w: Streams.Writer;
BEGIN
	NEW(buffer, 16);
	w := buffer.GetWriter();
	IF DEBUG THEN
		KernelLog.String("In AddressToSMPTString namePart: "); KernelLog.String(address.namePart^);
		KernelLog.String(" domainPart: "); KernelLog.String(address.domainPart^); KernelLog.Ln();
	END;
	w.String(address.namePart^);
	w.String("@");
	w.String(address.domainPart^);

	string := buffer.GetString();
END AddressToSMTPString;

END RMSMTP.
