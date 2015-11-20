(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebHTTPServerTools;	(** AUTHOR "be"; PURPOSE "User interface to HTTPServer"; *)

IMPORT Commands, WebHTTPServer;

CONST
	ModuleName = "WebHTTPServerTools";

PROCEDURE Start*(context : Commands.Context); (** ["\r:" default root directory] ["\l:" log file] *)
VAR c, opt: CHAR; str, root, log, tls: ARRAY 1024 OF CHAR; msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	root := ""; log := "";
	context.arg.SkipWhitespace;
	LOOP
		c := context.arg.Get();
		IF (c # "\") THEN EXIT END;

		opt := CAP(context.arg.Get());
		c := context.arg.Get();
		IF (c # ":") THEN EXIT END;

		context.arg.SkipWhitespace;
		context.arg.String( str);
		context.arg.SkipWhitespace;

		CASE opt OF
		| "R": COPY(str, root)
		| "L": COPY(str, log)
		| "S": COPY(str, tls)
		ELSE EXIT
		END
	END;

	IF tls = "on"  THEN
		WebHTTPServer.StartHTTPS(root, log, msg, res);
		IF (res # WebHTTPServer.Ok) THEN
			context.error.String("Could not start HTTPS server, res: "); context.error.Int(res, 0);
			context.error.String(" ("); context.error.String(msg); context.error.String(")"); context.error.Ln;
		END;
	END;
	WebHTTPServer.StartHTTP(root, log, msg, res);
	IF (res # WebHTTPServer.Ok) THEN
		context.error.String("Could not start HTTP server, res: "); context.error.Int(res, 0);
		context.error.String(" ("); context.error.String(msg); context.error.String(")"); context.error.Ln;
	ELSE
		context.out.String("HTTP server started. Default root directory = '"); context.out.String(root); context.out.String("'; logging ");
		IF (log = "") THEN context.out.String("disabled")
		ELSE context.out.String("to '"); context.out.String(log); context.out.Char("'")
		END;
		context.out.Ln;
	END;
END Start;

PROCEDURE Stop*(context : Commands.Context);
VAR msg : ARRAY 128 OF CHAR; res : LONGINT; stopped : BOOLEAN;
BEGIN
	WebHTTPServer.StopHTTP(msg, res); stopped := (res = WebHTTPServer.Ok);
	WebHTTPServer.StopHTTPS(msg, res); stopped := stopped OR (res = WebHTTPServer.Ok);
	IF stopped THEN
		context.out.String("HTTP/HTTPS Server stopped."); context.out.Ln;
	ELSE
		context.out.String("HTTP/HTTPS server is not running."); context.out.Ln;
	END;
END Stop;

PROCEDURE AddHost*(context : Commands.Context); (** host ["\r:" root directory] ["\d:" default file] ["\e:" error file] *)
VAR c, opt: CHAR; str: ARRAY 256 OF CHAR; host: WebHTTPServer.Host;
BEGIN
	IF context.arg.GetString(str) THEN
		IF (WebHTTPServer.FindHosts(str) = NIL) THEN
			NEW(host, str);
			LOOP
				context.arg.SkipWhitespace;
				c := context.arg.Get();
				IF (c # "\") THEN EXIT END;

				opt := CAP(context.arg.Get());
				c := context.arg.Get();
				IF (c # ":") THEN EXIT END;

				context.arg.SkipWhitespace; context.arg.String(str);

				CASE opt OF
				| "R": host.SetPrefix(str)
				| "D": host.SetDefault(str)
				| "E": host.SetError(str)
				ELSE EXIT
				END
			END;

			WebHTTPServer.AddHost(host);
			context.out.String("Added host '"); context.out.String(host.name); context.out.String("'; root = '"); context.out.String(host.prefix);
			context.out.String("'; default = '"); context.out.String(host.default); context.out.String("'; error = '"); context.out.String(host.error); context.out.Char("'")
		ELSE
			context.out.String(ModuleName); context.out.String(".AddHost: host '"); context.out.String(str); context.out.String("' already present.")
		END
	ELSE
		context.error.String(ModuleName); context.error.String('.AddHost: expected parameters: host ["\r:" root directory] ["\d:" default file] ["\e:" error file]');
	END;
	context.error.Ln;
END AddHost;

PROCEDURE RemoveHost*(context : Commands.Context); (** host *)
VAR hostname: ARRAY 256 OF CHAR; res : LONGINT;
BEGIN
	IF context.arg.GetString(hostname) THEN
		WebHTTPServer.RemoveHost(hostname, res);
		IF (res = WebHTTPServer.Ok) THEN
			context.out.String("Host '"); context.out.String(hostname); context.out.String("' removed."); context.out.Ln;
		ELSE
			context.error.String("Host '"); context.error.String(hostname); context.error.String("' not found."); context.error.Ln;
		END;
	ELSE
		context.error.String(ModuleName); context.error.String(".RemoveHost: expected parameters: host");
		context.error.Ln;
	END;
END RemoveHost;

PROCEDURE ListHosts*(context : Commands.Context);
BEGIN
	context.out.String("Virtual hosts:"); context.out.Ln;
	WebHTTPServer.ShowHosts(context.out);
END ListHosts;

END WebHTTPServerTools.

SystemTools.Free WebHTTPServerTools~
SystemTools.FreeDownTo TCP ~

WebHTTPServerTools.Start \r:E:/Test/ ~

WebHTTPServerTools.Start \r:httproot \l:HTTP.Log ~
WebHTTPServerTools.Start \r:httproot \l:HTTP.Log \s:on ~
WebHTTPServerTools.Stop

WebHTTPServerTools.AddHost livepc \r:FAT:/httproot/test~
WebHTTPServerTools.RemoveHost livepc.inf.ethz.ch~
WebHTTPServerTools.ListHosts

WebSSMPPlugin.Install ~
WebDefaultSSMP.Install ~
