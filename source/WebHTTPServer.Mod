MODULE WebHTTPServer; (** AUTHOR "pjm/tf/be"; PURPOSE "HTTP/1.1 Server";*)

IMPORT
	KernelLog, Machine, Kernel, Objects, WebHTTP, AosLog := TFLog, Modules, Streams, Files,
	IP, TCP, TCPServices, Classes := TFClasses, Clock, Dates, Strings;

CONST
	Ok* = TCPServices.Ok;
	Error* = -1;

	Major* = 1; Minor* = 1;

	FileBufSize = 4096;
	ServerVersion* = "A2 HTTP Server/1.0";
	DocType* = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">';
	Tab = 09X;

	Timeout = 300*1000;  (* [ms] timeout for keep-alive *)

	MaxErrors = 10;

	Log = FALSE;


TYPE
	Name* = ARRAY 64 OF CHAR;

	(** abstract HTTP plugin *)
	HTTPPlugin* = OBJECT
	VAR
		name*: Name;

		PROCEDURE &Init*(CONST name: Name);
		BEGIN COPY(name, SELF.name)
		END Init;

		(** if CanHandle returns TRUE, the Handler procedure will be called *)
		PROCEDURE CanHandle* (host: Host; VAR header : WebHTTP.RequestHeader; secure: BOOLEAN) : BOOLEAN;
		BEGIN HALT(301);
			RETURN FALSE
		END CanHandle;

		(** default LocateResource method *)
		PROCEDURE LocateResource*(host: Host; VAR header: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader; VAR f: Files.File);
		VAR
			name, ext: Files.FileName; i, d, t: LONGINT; modsince: ARRAY 32 OF CHAR;
			path : ARRAY 1024 OF CHAR;

			PROCEDURE Add(CONST s: ARRAY OF CHAR);
			VAR j, k: LONGINT; ch: CHAR;
			BEGIN
				j := 0; k := 0;
				LOOP
					IF i = LEN(name) THEN reply.statuscode := WebHTTP.RequestURITooLong; EXIT END;
					ch := s[j];
					IF ch = "." THEN k := 0 END;
					name[i] := ch; ext[k] := ch;
					IF ch = 0X THEN EXIT END;
					INC(i); INC(j); INC(k)
				END;
			END Add;

		BEGIN
			i := 0; reply.statuscode := WebHTTP.OK;
			Add(host.prefix); WebHTTP.GetPath(header.uri, path); Add(path);
			IF (reply.statuscode = WebHTTP.OK) THEN
				f := Files.Old(name);
				IF (f # NIL) & (Files.Directory IN f.flags) THEN (* do not send directory offals *)
					Strings.Concat("http://", header.host, reply.location);
					Strings.Append(reply.location, header.uri);
					Strings.Append(reply.location, "/");
					reply.statuscode := WebHTTP.ObjectMoved
				ELSE
					IF (name[i-1] = "/") THEN
						Strings.Concat("http://", header.host, reply.contentlocation);
						Strings.Append(reply.contentlocation, header.uri);
						Strings.Append(reply.contentlocation, host.default);
						Add(host.default)
					END;

					IF (reply.statuscode = WebHTTP.OK) THEN
						f := Files.Old(name);
						IF f # NIL THEN
							f.GetDate(t, d);
							Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.OberonToDateTime(d, t), reply.lastmodified);
							IF WebHTTP.GetAdditionalFieldValue(header.additionalFields, "If-Modified-Since", modsince) &
								(modsince = reply.lastmodified)
							THEN
								reply.statuscode := WebHTTP.NotModified;
								f := NIL
							ELSE
								(* TODO: move to Configuration.XML / separate plugins *)
								IF ext = ".html" THEN COPY("text/html; charset=utf-8", reply.contenttype)
								ELSIF ext = ".txt" THEN COPY("text/plain", reply.contenttype)
								ELSIF ext = ".css" THEN COPY("text/css", reply.contenttype)
								ELSIF ext = ".gif" THEN COPY("image/gif", reply.contenttype)
								ELSIF ext = ".jpg" THEN COPY("image/jpeg", reply.contenttype)
								ELSIF ext = ".pdf" THEN COPY("application/pdf", reply.contenttype)
								ELSIF ext = ".xsl" THEN COPY("text/xsl", reply.contenttype)
								ELSIF ext = ".xml" THEN COPY("text/xml", reply.contenttype)
								ELSE COPY("application/octet-stream", reply.contenttype)
								END
							END
						ELSE
							reply.statuscode := WebHTTP.NotFound; COPY("text/html", reply.contenttype);
							f := Files.Old(host.error);
						END
					END
				END
			END
		END LocateResource;

		(* handles a HTTP request *)
		PROCEDURE Handle*(host: Host; VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR out: Streams.Writer);
		BEGIN HALT(301)
		END Handle;
	END HTTPPlugin;

	(* default plugin for all hosts. Each host has this default plugin *)
	DefaultPlugin = OBJECT(HTTPPlugin)

		PROCEDURE CanHandle(host : Host; VAR header: WebHTTP.RequestHeader; secure : BOOLEAN): BOOLEAN;
		BEGIN RETURN TRUE
		END CanHandle;

		PROCEDURE Handle (host: Host; VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR out: Streams.Writer);
		VAR f: Files.File; fr: Files.Reader; c: WebHTTP.ChunkedOutStream; w: Streams.Writer;
		BEGIN
			IF (request.method IN {WebHTTP.GetM, WebHTTP.HeadM}) THEN
				LocateResource(host, request, reply, f);
				IF Log THEN
					WebHTTP.LogRequestHeader(log, request);
					WebHTTP.LogResponseHeader(log, reply)
				END;

				IF (reply.statuscode = WebHTTP.OK) OR (reply.statuscode = WebHTTP.NotFound) THEN
					IF (f # NIL) THEN
						reply.contentlength := f.Length();
						WebHTTP.SendResponseHeader(reply, out);
						IF (request.method = WebHTTP.GetM) THEN
							Files.OpenReader(fr, f, 0);
							SendData(fr, out)
						END
					ELSE
						reply.statuscode := WebHTTP.NotFound;
						(*WebHTTP.SendResponseHeader(reply, out);*)

						IF (request.method = WebHTTP.GetM) THEN
							NEW(c, w, out, request, reply);
							WebHTTP.SendResponseHeader(reply, out);
							WebHTTP.WriteHTMLStatus(reply, w); 
							w.Update;
							c.Close
						(* *) ELSE WebHTTP.SendResponseHeader(reply, out);
						END
					END
				ELSIF (reply.statuscode = WebHTTP.NotModified) THEN
					WebHTTP.SendResponseHeader(reply, out)
				ELSIF (reply.statuscode = WebHTTP.ObjectMoved) THEN
					(*WebHTTP.SendResponseHeader(reply, out);*)
					IF (request.method = WebHTTP.GetM) THEN
						NEW(c, w, out, request, reply);
						WebHTTP.SendResponseHeader(reply, out);
						WebHTTP.WriteHTMLStatus(reply, w);
						w.Update;
						c.Close
					(* *) ELSE WebHTTP.SendResponseHeader(reply, out);
					END
				END
			ELSE
				reply.statuscode := WebHTTP.NotImplemented;
				WebHTTP.WriteStatus(reply, out)
			END
		END Handle;
	END DefaultPlugin;

	Statistics = OBJECT
	VAR
		bucket : LONGINT;
		secondBuckets: ARRAY 60 OF LONGINT;
		timer : Kernel.Timer;
		avg : LONGINT;
		alive : BOOLEAN;
		logCounter: LONGINT;

		PROCEDURE Hit;
		BEGIN {EXCLUSIVE}
			INC(secondBuckets[bucket]);
			INC(nofRequests)
		END Hit;

		PROCEDURE Update;
		BEGIN {EXCLUSIVE}
			avg := avg + secondBuckets[bucket];
			bucket := (bucket + 1) MOD 60;
			avg := avg - secondBuckets[bucket];
			secondBuckets[bucket] := 0;
			requestsPerMinute := avg;

			logCounter := (logCounter + 1) MOD 40H;
			IF (logCounter = 0) THEN
				FlushW3CLog
			END
		END Update;

		PROCEDURE Kill;
		BEGIN
			alive := FALSE;
			timer.Wakeup
		END Kill;

	BEGIN {ACTIVE}
		NEW(timer); alive := TRUE;
		WHILE alive DO
			timer.Sleep(1000);
			Update
		END;
	END Statistics;

	HostList* = OBJECT
	VAR
		host*: Host;
		next*: HostList;
	END HostList;

	Host* = OBJECT
	VAR
		name-: Name;
		plugins : Classes.List;
		prefix-, default-, error-: Files.FileName;

		PROCEDURE &Init*(CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, SELF.name);
			COPY("", prefix);
			COPY("index.html", default);
			COPY("error.html", error);

			NEW(plugins);
			(* install default plugin *)
			plugins.Add(defaultPlugin);
		END Init;

		PROCEDURE AddPlugin*(pi : HTTPPlugin);
		BEGIN {EXCLUSIVE}
			IF plugins.IndexOf(pi) >= 0 THEN KernelLog.String("Plugin already plugged in"); KernelLog.Ln
			ELSE
				plugins.Add(pi)
			END
		END AddPlugin;

		PROCEDURE RemovePlugin*(pi : HTTPPlugin);
		BEGIN {EXCLUSIVE}
			plugins.Remove(pi)
		END RemovePlugin;

		PROCEDURE SetPrefix*(CONST Prefix: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			COPY(Prefix, prefix)
		END SetPrefix;

		PROCEDURE SetDefault*(CONST Default: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			COPY(Default, default)
		END SetDefault;

		PROCEDURE SetError*(CONST Error: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			COPY(Error, error)
		END SetError;

		PROCEDURE Handle*(
			VAR request: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR out: Streams.Writer; secure : BOOLEAN
		);
		VAR i: LONGINT; pi: HTTPPlugin; p: ANY; exit: BOOLEAN;
		BEGIN
			BEGIN {EXCLUSIVE}
				exit := FALSE;
				i := plugins.GetCount()-1;
				WHILE (i >= 0) & (~exit) DO
					p := plugins.GetItem(i);
					IF p(HTTPPlugin).CanHandle(SELF, request, secure) THEN pi := p(HTTPPlugin); exit := TRUE END;
					DEC(i);
				END;
			END;
			IF pi # NIL THEN
				IF Log THEN
					log.String("request handled by "); log.String(pi.name); log.Ln
				END;
				pi.Handle(SELF, request, reply, in, out);
			ELSE
				HALT(99)
			END;
		END Handle;

	END Host;

	HTTPAgent = OBJECT (TCPServices.Agent)
	VAR
		res, len : LONGINT;
		body, closeRequested: BOOLEAN;
		out: Streams.Writer; in, inR: Streams.Reader;
		o : ANY;
		h, th : Host;
		i : LONGINT;
		request : WebHTTP.RequestHeader;
		reply: WebHTTP.ResponseHeader;
		value: ARRAY 128 OF CHAR;
		timeout: Objects.Timer;
		dechunk: WebHTTP.ChunkedInStream;
		consecutiveErrors: LONGINT;
		secure : BOOLEAN;
		listenerProc : ListenerProc;

		PROCEDURE HandleTimeout;
		BEGIN client.Close
		END HandleTimeout;

	BEGIN {ACTIVE}
		NEW(timeout);
		(* open streams *)
		Streams.OpenReader(in, client.Receive);
		Streams.OpenWriter(out, client.Send);
		Machine.AtomicInc(nofConnects);

		(* read request *)
		request.fadr := client.fip;
		request.fport := client.fport;

		consecutiveErrors := 0;

		REPEAT
			Objects.SetTimeout(timeout, HandleTimeout, Timeout);
			WebHTTP.ParseRequest(in, request, res, log);
			IF Log THEN WebHTTP.LogRequestHeader(log,request) END;
			Objects.CancelTimeout(timeout);
			IF (client.state = TCP.Established) THEN
				IF (Strings.Pos("hunked", request.transferencoding) > 0) THEN
					NEW(dechunk, in, inR)
				ELSE
					inR := in
				END;

					(* handle request *)
				GetDefaultResponseHeader(request, reply);
				len := 0; body := FALSE;
				hitStat.Hit;
				IF (res = WebHTTP.OK) THEN
					i := 0; WHILE (request.host[i] # 0X) & (request.host[i] # ":") DO INC(i) END;
					request.host[i] := 0X;
					h := defaultHost;
					hosts.Lock;
					i := hosts.GetCount()-1;
					WHILE (i >= 0) DO
						o := hosts.GetItem(i); th := o(Host);
						IF Strings.Match(th.name, request.host) THEN h := th; i := 0 END;
						DEC(i)
					END;
					hosts.Unlock;
					IF Log THEN
						log.String(request.uri); log.String(" handled by ");
						IF (h.name = "") THEN log.String(" default host")
						ELSE log.String(h.name)
						END;
						log.Ln
					END;
					h.Handle(request, reply, inR, out, secure);
					listenerProc := listener;
					IF (listenerProc # NIL) THEN
						listenerProc(request, reply);
					END;
				ELSE
					reply.statuscode := res;
					WebHTTP.WriteStatus(reply, out)
				END;
				
				out.Update; (*PH*)(* ignore out.res *)
				
				IF logEnabled THEN W3CLog(request, reply) END;

				IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Connection", value) THEN
					closeRequested := Strings.Pos("lose", value) > 0
				ELSE
					closeRequested := FALSE
				END;

				IF (reply.statuscode >= 400) THEN
					INC(consecutiveErrors);
					IF (consecutiveErrors = MaxErrors) THEN client.Close END
				ELSE
					consecutiveErrors := 0
				END;
				
			END
		UNTIL closeRequested OR ((request.maj = 1) & (request.min = 0)) OR (client.state # TCP.Established);
		Terminate
	END HTTPAgent;

	ListenerProc* = PROCEDURE {DELEGATE} (request : WebHTTP.RequestHeader; response : WebHTTP.ResponseHeader);

VAR
	http: TCPServices.Service;
	https: TCPServices.TLSService;
	hosts : Classes.List;
	log : AosLog.Log;
	hitStat : Statistics;
	nofRequests* : LONGINT;
	requestsPerMinute* : LONGINT;
	nofConnects* : LONGINT;
	defaultHost : Host;
	defaultPlugin: DefaultPlugin;

	logEnabled : BOOLEAN;
	logWriter : Streams.Writer;
	logFile : Files.File;

	listener* : ListenerProc;

PROCEDURE GetRequests*():LONGINT;
BEGIN
	RETURN nofRequests
END GetRequests;

PROCEDURE NewHTTPAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: HTTPAgent;
BEGIN
	NEW(a, c, s); a.secure := FALSE; RETURN a
END NewHTTPAgent;

PROCEDURE NewHTTPSAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: HTTPAgent;
BEGIN
	NEW(a, c, s); a.secure := TRUE; RETURN a
END NewHTTPSAgent;

PROCEDURE OpenW3CLog(CONST fn: ARRAY OF CHAR);
VAR w : Files.Writer;
BEGIN
	logFile := Files.Old(fn);
	IF logFile = NIL THEN
		logFile := Files.New(fn); Files.Register(logFile);
		Files.OpenWriter(w, logFile, 0);
		w.String("#Version: 1.0"); w.Ln;
		w.String("#Fields: date"); w.Char(Tab);
		w.String("time"); w.Char(Tab);
		w.String("cs-method"); w.Char(Tab);
		w.String("cs(host)"); w.Char(Tab);
		w.String("cs-uri"); w.Char(Tab);
		w.String("x-result"); w.Char(Tab);
		w.String("c-ip"); w.Char(Tab);
		w.String("cs(user-agent)"); w.Char(Tab);
		w.String("cs(referer)"); w.Ln
	ELSE
		Files.OpenWriter(w, logFile, logFile.Length())
	END;
	logWriter := w;
	logEnabled := TRUE
END OpenW3CLog;

PROCEDURE W3CLog(request : WebHTTP.RequestHeader; reply: WebHTTP.ResponseHeader);
VAR time, date: LONGINT; s: ARRAY 36 OF CHAR;
BEGIN {EXCLUSIVE}
	Clock.Get(time, date);
	logWriter.Date( -1, date); logWriter.Char(Tab);
	logWriter.Date(time, -1); logWriter.Char(Tab);
	WebHTTP.GetMethodName(request.method,s); logWriter.String(s);
	logWriter.Char(Tab);
	IF request.host # "" THEN logWriter.String(request.host) ELSE logWriter.String("-") END; logWriter.Char(Tab);
	IF request.uri # "" THEN logWriter.String(request.uri) ELSE logWriter.String("-") END; logWriter.Char(Tab);
	logWriter.Int(reply.statuscode, 1); logWriter.Char(Tab);
	IP.AdrToStr(request.fadr, s); logWriter.String(s); logWriter.Char(Tab);
	IF request.useragent # "" THEN logWriter.String(request.useragent) ELSE logWriter.String("-") END; logWriter.Char(Tab);
	IF request.referer # "" THEN  logWriter.String(request.referer) ELSE logWriter.String( "-") END; logWriter.Char(Tab);
	logWriter.Ln
END W3CLog;

PROCEDURE FlushW3CLog*;
BEGIN
	IF logEnabled THEN
		logWriter.Update; logFile.Update
	END
END FlushW3CLog;

PROCEDURE GetDefaultResponseHeader*(VAR r: WebHTTP.RequestHeader; VAR h: WebHTTP.ResponseHeader);
BEGIN
	h.maj := r.maj; h.min := r.min;
	COPY(ServerVersion, h.server);
	h.statuscode := WebHTTP.OK;
	Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.Now(), h.date);
	h.location := ""; h.contenttype := ""; h.contentlocation := ""; h.transferencoding := "";
	h.contentlength := -1; h.lastmodified := "";
	h.additionalFields := NIL
END GetDefaultResponseHeader;

(** Sends all availabe data from src to dst *)
PROCEDURE SendData*(src: Streams.Reader; dst: Streams.Writer);
VAR len: LONGINT; buf: ARRAY FileBufSize OF CHAR;
BEGIN
	WHILE (src.res = Streams.Ok) DO
		src.Bytes(buf, 0, FileBufSize, len);
		dst.Bytes(buf, 0, len)
	END
END SendData;

(** Add a new virtual host *)
PROCEDURE AddHost*(host: Host);
BEGIN {EXCLUSIVE}
	hosts.Add(host)
END AddHost;

(** get a list of matching hosts (wildcards permitted, "*" returns all hosts) *)
PROCEDURE FindHosts*(CONST host: ARRAY OF CHAR): HostList;
VAR i: LONGINT; o: ANY; l, p, old: HostList;
BEGIN {EXCLUSIVE}
	NEW(l);
	IF (host = "") THEN l.host := defaultHost;
	ELSE
		p := l; old := NIL;
		FOR i := 0 TO hosts.GetCount()-1 DO
			o := hosts.GetItem(i);
			IF Strings.Match(host, o(Host).name) THEN
				p.host := o(Host); NEW(p.next); old := p; p := p.next
			END
		END;
		IF (old # NIL) THEN old.next := NIL END
	END;
	IF (l.host = NIL) THEN l := NIL END;
	RETURN l
END FindHosts;

(** remove the virtual host given by name *)
PROCEDURE RemoveHost*(CONST host : ARRAY OF CHAR; VAR res : LONGINT);
VAR i : LONGINT; o, h : ANY;
BEGIN {EXCLUSIVE}
	hosts.Lock;
	FOR i := 0 TO hosts.GetCount() - 1 DO
		o := hosts.GetItem(i); IF o(Host).name= host THEN h := o(Host) END;
	END;
	hosts.Unlock;
	IF (h # NIL) THEN
		hosts.Remove(h); res := Ok;
	ELSE
		res := Error; (* host not found *)
	END
END RemoveHost;

(** Start the basic Server functionality. *)
PROCEDURE StartHTTP*(root : ARRAY OF CHAR; CONST logFile: ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (http = NIL) THEN
		Strings.Trim(root, " "); defaultHost.SetPrefix(root);
		IF (logFile # "") THEN OpenW3CLog(logFile) END;

		NEW(http, WebHTTP.HTTPPort,  NewHTTPAgent, res);
		IF (res = TCPServices.Ok) THEN
			COPY("", msg);
			IF Log THEN log.Enter; log.TimeStamp; log.String("Started"); log.Exit END
		ELSE
			http := NIL; COPY("TCP Error", msg);
		END;
	ELSE
		res := Error; COPY("HTTP server is already running", msg);
	END;
END StartHTTP;

(** Start the basic Server functionality. *)
PROCEDURE StartHTTPS*(root : ARRAY OF CHAR; CONST  logFile: ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (https = NIL) THEN
		Strings.Trim(root, " "); defaultHost.SetPrefix(root);
		IF (logFile # "") THEN OpenW3CLog(logFile) END;

		NEW(https, WebHTTP.HTTPSPort,  NewHTTPSAgent, res);
		IF (res = TCPServices.Ok) THEN
			COPY("", msg);
			IF Log THEN log.Enter; log.TimeStamp; log.String("Started"); log.Exit END
		ELSE
			 https := NIL; COPY("TCP Error", msg);
		END;
	ELSE
		res := Error; COPY("HTTPS server is already running", msg);
	END
END StartHTTPS;

(** Stop the server *)
PROCEDURE StopHTTP*(VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (http # NIL) THEN
		res := Ok; COPY("", msg);
		http.Stop; http := NIL;
		defaultHost.SetPrefix("");
		IF Log THEN log.Enter; log.TimeStamp; log.String("Stopped"); log.Exit END
	ELSE
		res := Error; COPY("HTTP server is not running", msg);
	END;
END StopHTTP;

(** Stop the server *)
PROCEDURE StopHTTPS*(VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	IF (https # NIL) THEN
		res := Ok; COPY("", msg);
		https.Stop; https := NIL;
		defaultHost.SetPrefix("");
		IF Log THEN log.Enter; log.TimeStamp; log.String("Stopped"); log.Exit END
	ELSE
		res := Error; COPY("HTTP server is not running", msg);
	END;
END StopHTTPS;

(** enumerate all installed hosts *)
PROCEDURE ShowHosts*(out : Streams.Writer);
VAR
	i : LONGINT; o : ANY;

	PROCEDURE PrintHost(h: Host);
	VAR p: ANY; i: LONGINT;
	BEGIN
		out.String("Host: ");
		IF (h.name = "") THEN out.String("default host")
		ELSE out.String(h.name)
		END;
		out.String("; root: '"); out.String(h.prefix); out.String("'; default: '"); out.String(h.default);
		out.String("'; error = '"); out.String(h.error); out.Char("'"); out.Ln;
		h.plugins.Lock;
		FOR i := 0 TO h.plugins.GetCount()-1 DO
			p := h.plugins.GetItem(i);
			out.String("   plugin: "); out.String(p(HTTPPlugin).name); out.Ln
		END;
		h.plugins.Unlock
	END PrintHost;

BEGIN {EXCLUSIVE}
	ASSERT(out # NIL);
	hosts.Lock;
	PrintHost(defaultHost);
	FOR i := 0 TO hosts.GetCount() - 1 DO
		o := hosts.GetItem(i);
		PrintHost(o(Host))
	END;
	hosts.Unlock
END ShowHosts;

PROCEDURE Cleanup;
VAR t: Kernel.Timer; msg : ARRAY 32 OF CHAR; ignore : LONGINT;
BEGIN
	hitStat.Kill;
	StopHTTP(msg, ignore);
	StopHTTPS(msg, ignore);
	hosts := NIL; defaultHost := NIL;
	FlushW3CLog;
	IF Log THEN log.Close END;
	NEW(t); t.Sleep(100) (* avoid trap in Statistics; replace with Kernel.AwaitDeath *)
END Cleanup;

BEGIN
	IF Log THEN
		NEW(log, "WebHTTP Server");
		log.SetLogToOut(TRUE)
	END;
	listener := NIL;
	NEW(hosts); NEW(hitStat);
	NEW(defaultPlugin, "Default-Plugin");
	NEW(defaultHost, "");
	http := NIL; https := NIL;
	Modules.InstallTermHandler(Cleanup)
END WebHTTPServer.

(** INFO

The HTTP server is always listening to port 80. By default all requests are handled by the default host.
Content-Types are currently coded directly in HTTPPlugin.LocateResource (Types for .html .ssmp .txt .gif .jpg .pdf are known)

The server can be used for multi-hosting (several different domain names resolve to the same ip number but return
different pages for different domains). If a host is unknown or the request is not HTTP/1.1 compatible the default host is called.
Known host-names can be dynamically added and removed. See the WebHTTPServerTools.Mod for a multi-host setup.

Each host can support a number of "Plugins" that can handle special URIs like Form-Post / dynamically generated pages.
See WebWormWatch.Mod for some example plugins.

There is another (experimental) method for dynamically generated pages: "Server Side Modified Pages". Documents with
the name extension ".ssmp" are modified by the server. The patterns "&&"<methodName>" "[<Parameters>] are replaced
by the result of the respective method. See WebWormWatch.Mod WebHTTPServer.Mod WebDefaultSSMP.Mod for examples of SSMP methods.
See public.info.ssmp as an example of a ".ssmp" page.

(currently unavailable:)
There is a helper module that allows to use url-encoded form posts. See TFHTTPServerExample.Mod for a form-post example.
public.form.html contains the form.

The interfaces in all these modules may change.
*)

COMPILE THE SERVER AND EXAMPLES
PC.Compile \s TFLog.Mod WebHTTP.Mod WebHTTPServer.Mod WebSSMPPlugin.Mod WebDefaultSSMP.Mod~

START THE SERVER
Configuration.DoCommands
WebHTTPServerTools.Start \r:../httproot \l:WebHTTP.Log ~
WebHTTPServerTools.AddHost livepc.inf.ethz.ch \r:FAT:/httproot/test~
WebSSMPPlugin.Install~
WebDefaultSSMP.Install~
WebHTTPServerTools.ListHosts~
~

WebHTTPServerTools.Stop ~

WebFTPServerTools.Start \r:httproot \l:httproot/FTP.Log~

FREE THE SERVER
SystemTools.Free WebHTTPServerTools WebDefaultSSMP WebSSMPPlugin WebHTTPServer  WebHTTP~

System.State WebHTTPServer~
SystemTools.FreeDownTo WebHTTPServer ~

FILES
TFLog.Mod WebHTTP.Mod WebSSMPPlugin.Mod WebDefaultSSMP.Mod WebHTTPServer.Mod WebWormWatch.Mod public.form.html public.info.ssmp~

Statistics.Log

W3C Log File

#Version: 1.0
#Fields: date	time	cs-method	cs(host)	cs-uri	c-ip	cs(user-agent)	cs(referer)
WebHTTPServer.FlushW3CLog
EditTools.OpenAscii HTTP.Log ~
System.DeleteFiles HTTP.Log~
