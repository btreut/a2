MODULE OdPlugin;
(* Aos, Copyright 2001, Pieter Muller, ETH Zurich
Author.    Edgar Schwarz, edgar@edgarschwarz.de, (es)
Contents. WebHTTPServer plugin for a restricted WebDAV/DeltaV which allows BASELINE-CONTROL.
Contents. Commands for DeltaV. Commands from DAVDeltavBase will be redefined. In addition there will be some web stuff.
Contents. - A DeltaV plugin for the WebHTTPServer.defaulthost. The plugin will call DAVDeltavBase.localserver to do it's work.
Contents. - The commands will call the server and wait for a reply.
*)

IMPORT Modules, Clock, Dates, Strings, Streams, Files, TCP, KernelLog, Kernel, Heaps,
	Commands, Objects, AosLog := TFLog, WebHTTP, WebHTTPServer,
	XML, XMLObjects, OdVCSBase, OdCond, OdUtil, OdAuthBase, OdXml, OdDeltavBase;

CONST
	Log = TRUE;
	PluginVersion = "Aos DeltaV Plugin/1.3.3";
	DocType = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">';
	Ok = 0;

TYPE
	(* Plugin for DeltaV. Will be added to WebHTTPServer.default*)
	DeltavPlugin = OBJECT(WebHTTPServer.HTTPPlugin)
		VAR logHeader: BOOLEAN;
		PROCEDURE & InitDeltav*(CONST name: WebHTTPServer.Name);
		BEGIN
			Init(name); logHeader := TRUE;
		END InitDeltav;

		PROCEDURE CanHandle(host: WebHTTPServer.Host; VAR header: WebHTTP.RequestHeader; secure:BOOLEAN): BOOLEAN;
		BEGIN
			CASE header.method OF
				(* Take all with two exceptions. So we get unexpected methods at least for logging. *)
				WebHTTP.HeadM: RETURN FALSE;
				| WebHTTP.GetM: RETURN header.uri[Strings.Length(header.uri)-1] = '/'; (* To send directory listing *)
				ELSE RETURN TRUE;
				(*******************
				WebHTTP.PutM, (* With WebDAV PUT has additional functionality. *)
				WebHTTP.OptionsM,
				(* RFC 2518,  WebDAV *)
				WebHTTP.PropfindM,
				WebHTTP.ProppatchM,
				WebHTTP.MkcolM,
				WebHTTP.DeleteM,
				(*ni*) WebHTTP.CopyM,
				(*ni*) WebHTTP.MoveM,
				(*ni*) WebHTTP.LockM,
				(*ni*) WebHTTP.UnlockM,
				(* RFC 3253, Versioning Extensions to  WebDAV *)
				WebHTTP.VersionControlM,
				WebHTTP.ReportM,
				WebHTTP.CheckoutM,
				WebHTTP.CheckinM,
				WebHTTP.UncheckoutM,
				(*ni*) WebHTTP.MkworkspaceM,
				WebHTTP.UpdateM,
				(*ni*) WebHTTP.LabelM,
				(*ni*) WebHTTP.MergeM,
				WebHTTP.BaselineControlM,
				(*ni*) WebHTTP.MkactivityM: RETURN TRUE;
				ELSE RETURN FALSE;
				****************)
			END;
		END CanHandle;

		(** Server GET directory only. Only called with 'GET /<uri>/' *)
		PROCEDURE GetDir(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR f: Files.File);
		CONST PLog = FALSE; TempFile = "GetDir.Temp";
			PropCh = '_';
		VAR pattern: Files.FileName; (* basicAuth: WebDAVAuthBase.Basic; *)
			enum: Files.Enumerator; prefixLen, len, time, date, size: LONGINT;
			dateTimeStr, timeStr: ARRAY 32 OF CHAR; entryFlags, flags: SET;
			w: Files.Writer;
			name: ARRAY 1024 OF CHAR;
		BEGIN
			(* Don't check authentication for now   *)
			Strings.Concat(host.prefix, request.uri, pattern); Strings.Append(pattern, '*');
			IF PLog THEN  OdUtil.Msg2("WebDAVPlugin.GetDir: pattern = ", pattern); END;
			f := Files.New(TempFile); (* Doesn't work with anonymous file for "large" data. *)
			NEW(w, f, 0);
			flags := {}; entryFlags := {};
			prefixLen := Strings.Length(host.prefix);
			NEW(enum); enum.Open(pattern, flags);
			WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
				len := Strings.Length(name);
				IF PLog THEN  OdUtil.Msg2("WebDAVPlugin.GetDir: name = ", name); END;
				IF (len > 0) & (name[len-1] # PropCh) THEN
					Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.OberonToDateTime(date, time), dateTimeStr);
					Strings.Delete(name, 0, prefixLen);
					w.String(name); IF Files.Directory IN entryFlags THEN w.Char('/'); END;
					w.Char(' '); w.Int(size, 8); w.Char(' '); w.String(dateTimeStr); w.Ln;
				END;
			END;
			response.statuscode := WebHTTP.OK;
			WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Content-Type", 'text/plain');
			w.Update();
			Files.Register(f);
		END GetDir; (* Server *)

		(** Server PUT*)
		PROCEDURE Put(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlDoc: XML.Document);
		VAR confRes, conf, res: OdUtil.Line; xmlErr: OdXml.ErrorRes;
			fn: Files.FileName; f: Files.File; rc: LONGINT; props: OdDeltavBase.VersionProperties;
			s: ARRAY 16 OF CHAR; len: LONGINT;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Put allowed *)
			Strings.Concat(host.prefix, request.uri, fn);
			COPY(request.uri, confRes); conf := "";
			OdDeltavBase.splitConfRes(confRes, conf, res);
			NEW(props, conf, res);
			IF (props.state = "") OR (props.state = "thawed") THEN
				(* Not under version control or checked-out. *)
				f := Files.New(fn);
				IF f = NIL THEN
					response.statuscode := WebHTTP.Conflict;
					NEW(xmlErr, "internal-error: WebDAVPlugin.Put: Can't create file 1"); xmlDoc := xmlErr;
				ELSE
					response.statuscode := WebHTTP.OK;
					IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Length", s) THEN
						Strings.StrToInt(s, len);
						Con2FileNew(in, len, f); (* Asynch with timeout *)
						Files.Register(f);
					END;
				END;
			ELSE (* props.state = "frozen" *)
				(* TODO: Flush buffer. Perhaps close connection ? DAV* dev0 ?*)
				f := Files.New("");
				IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Length", s) THEN
					Strings.StrToInt(s, len);
					Con2FileNew(in, len, f); (* Asynch with timeout *)
				END;
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdCond.MustBeCheckedOutVcr]); xmlDoc := xmlErr;
			END;
		END Put; (* Server *)

		(* WebHTTP.RequestHeader  WebHTTP.ResponseHeader  WebHTTP.AdditionalField   *)
		(** Server CHECKOUT*)
		PROCEDURE Checkout(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader(*unused*); VAR xmlDoc: XML.Document);
		VAR
			confRes, conf, res: OdUtil.Line; xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Checkout allowed *)
			response.statuscode := WebHTTP.OK;
			WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Cache-Control", "no-cache");
			COPY(request.uri, confRes);
			IF OdDeltavBase.isConfiguration(confRes) THEN
				OdDeltavBase.localServer.thawConfiguration(confRes);
			ELSE
				OdDeltavBase.splitConfRes(confRes, conf, res);
				OdDeltavBase.localServer.thawResource(conf, res);
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlDoc := xmlErr;
			END;
		END Checkout; (* Server *)

		(** Server UNCHECKOUT*)
		PROCEDURE Uncheckout(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader(*unused*); VAR xmlOut: XML.Document);
		VAR
			confRes, conf, res: OdUtil.Line; xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Uncheckout allowed *)
			response.statuscode := WebHTTP.OK;
			COPY(request.uri, confRes);
			IF OdDeltavBase.isConfiguration(confRes) THEN
				OdDeltavBase.localServer.unThawConfiguration(confRes);
			ELSE
				OdDeltavBase.splitConfRes(confRes, conf, res);
				OdDeltavBase.localServer.unThawResource(conf, res);
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Uncheckout; (* Server *)

		(** Server REPORT. Similar to PROPFIND.*)
		PROCEDURE Report(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR confRes, baseline0, baseline1, conf, res, propName: OdUtil.Line; body: ARRAY 512 OF CHAR; pos, avail: LONGINT;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes; e: XML.Element;
			contentLength: LONGINT; bodyReader: Files.Reader;
			depth: ARRAY 16 OF CHAR;
		BEGIN
			response.statuscode := WebHTTP.OK; OdDeltavBase.preCond := OdCond.Ok;
			IF ~WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Depth", depth) THEN
				depth := "";
			END;
			IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Length", body) THEN
				Strings.StrToInt(body, contentLength);
				IF contentLength > 0 THEN (* cadaver *)
					(*xmlFile := Files.New("");
					Con2FileNew(in, contentLength, xmlFile); (* Asynch with timeout *)
					IF logHeader THEN
						NEW(bodyReader, xmlFile, 0);
						bodyReader.RawString(body);
						WHILE body # ""  DO l.Enter; l.String(body); l.Exit; bodyReader.RawString(body); END;
					END;
					(* Now parse it *)
					NEW(scanner, xmlFile);
					*)
					NEW(scanner, in);
					NEW(parser, scanner); xmlDoc := parser.Parse();
					e := xmlDoc.GetRoot(); propName := OdX.AbsXmlName(e.GetName());
					(** ) OdDeltavBase.Msg2("REPORT: element name = ", s^); ( **)
					IF propName = "DAV:version-tree" THEN
						COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
						OdDeltavBase.localServer.reportVersionTree(host.name, conf, res, xmlOut);
					ELSIF propName = "DAV:configuration-report" THEN
						COPY(request.uri, conf);
						OdDeltavBase.localServer.webReportConfiguration(host.name, conf, xmlOut);
					ELSIF propName = "DAV:baseline-report" THEN
						COPY(request.uri, baseline0);
						OdDeltavBase.localServer.webReportBaseline(host.name, baseline0, xmlOut, response.statuscode);
					ELSIF propName = "DAV:compare-baseline" THEN
						COPY(request.uri, baseline0);
						e := OdX.FindElement(e, "DAV:href");
						IF e # NIL THEN
							OdXml.GetCharData(e, baseline1);
							OdDeltavBase.localServer.reportCompareBaseline(host.name, baseline0, baseline1,
								xmlOut, response.statuscode);
						ELSE
							response.statuscode := WebHTTP.BadRequest;
							NEW(xmlErr, "ES:error-in-compare-baseline-request"); xmlOut := xmlErr;
						END;
					ELSE (* julian.reschke@greenbytes.de  *)
						response.statuscode := WebHTTP.Forbidden;
						NEW(xmlErr, "D:supported-report"); xmlOut := xmlErr;
					END;
				ELSE
					response.statuscode := WebHTTP.BadRequest;
					NEW(xmlErr, "ES:report-without-request-body"); xmlOut := xmlErr;
				END;
			ELSE
				OdDeltavBase.preCond := OdCond.MustHaveRequestBody;
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				(* Set statuscode to a default error if not already done. *)
				IF response.statuscode = WebHTTP.OK THEN response.statuscode := WebHTTP.Conflict; END;
				(* Create error body. *)
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Report; (* Server *)

		(** Server PROPFIND. *)
		PROCEDURE Propfind(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader;
			VAR response: WebHTTP.ResponseHeader; VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR confRes, baseline, conf, res: OdUtil.Line; body: ARRAY 512 OF CHAR; pos, avail: LONGINT;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes; e: XML.Element; elName: OdUtil.Line;
			contentLength: LONGINT; bodyReader: Files.Reader;
			depth: ARRAY 16 OF CHAR; errMsg: ARRAY 128 OF CHAR;
		BEGIN
			response.statuscode := WebHTTP.MultiStatus; OdDeltavBase.preCond := OdCond.Ok;
			IF ~WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Depth", depth) THEN
				depth := "";
			ELSIF depth # "1" THEN
				(* In case of the client sending something funny just set it to "0" *)
				depth := "0";
			END;
			IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Length", body) THEN
				Strings.StrToInt(body, contentLength);
				IF contentLength > 0 THEN (* cadaver *)
					(*
					xmlFile := Files.New("");
					Con2FileNew(in, contentLength, xmlFile); (* Asynch with timeout *)
					IF logHeader THEN
						NEW(bodyReader, xmlFile, 0);
						bodyReader.RawString(body);
						WHILE body # ""  DO l.Enter; l.String(body); l.Exit; bodyReader.RawString(body); END;
					END;
					(* Now parse it *)
					NEW(scanner, xmlFile);
					*)
					NEW(scanner, in);
					NEW(parser, scanner); xmlDoc := parser.Parse();
					IF xmlDoc # NIL THEN
						e := xmlDoc.GetRoot(); elName := OdX.AbsXmlName(e.GetName());
						(* cadaver example  *)
						IF elName = "DAV:propfind" THEN
							COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
							OdDeltavBase.localServer.propfind(host.name, conf, res, depth, xmlDoc, xmlOut);
						ELSE
							response.statuscode := WebHTTP.BadRequest;
							Strings.Concat("ES:propfind-body-error  first element = ", elName, errMsg);
							NEW(xmlErr, errMsg); xmlOut := xmlErr;
						END;
					ELSE
						response.statuscode := WebHTTP.BadRequest;
						NEW(xmlErr, "ES:propfind-body-error first: couldn't parse XML body"); xmlOut := xmlErr;
					END
				ELSE (* MSWebfolders: Content-Length = 0 *)
					COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
					OdDeltavBase.localServer.propfind(host.name, conf, res, depth, NIL, xmlOut);
				END;
			ELSE (* No body given. Just URI. MS Webfolders. *)
				COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
				OdDeltavBase.localServer.propfind(host.name, conf, res, depth, NIL, xmlOut);
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Propfind; (* Server *)

		(** Server PROPPATCH.  *)
		PROCEDURE Proppatch(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR confRes, baseline, conf, res, line: OdUtil.Line; body: ARRAY 512 OF CHAR; pos, avail: LONGINT;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes; e, patch, proptag, prop, href: XML.Element;
			s, propName: XML.String;
			patches, proptags, props, hrefs: XMLObjects.Enumerator; p: ANY;
			lines: OdUtil.Lines; charData: ARRAY 256 OF CHAR; patchMode, elName: OdUtil.Line;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Proppatch allowed *)
			response.statuscode := WebHTTP.OK; OdDeltavBase.preCond := OdCond.Ok;
			IF in.Available() > 0 THEN (* there is a body *)
				(*
				in.Bytes(body, 0, in.Available(), avail); body[avail] := 0X;
				(** ) OdDeltavBase.Msg3("PROPPATCH: request body = ", body, OdDeltavBase.I(avail)); ( **)
				IF logHeader THEN
					l.Enter; l.String(body); l.Exit;
				END;
				(* Temporary writing to a file because XML scanner wants to read from a file. *)
				xmlFile := Files.New(""); xmlFile.Set(xmlR, 0); Files.WriteString(xmlR, body); xmlFile.Update();
				(* Now parse it *)
				NEW(scanner, xmlFile);
				*)
				NEW(scanner, in);
				NEW(parser, scanner); xmlDoc := parser.Parse();
				e := xmlDoc.GetRoot(); elName := OdX.AbsXmlName(e.GetName());
				(* OdDeltavBase.Msg2("REPORT: element name = ", s^); *)
				IF elName = "DAV:propertyupdate" THEN
					patches := e.GetContents();
					WHILE patches.HasMoreElements() DO
						p := patches.GetNext();
						patch :=  p(XML.Element);
						patchMode  := OdX.AbsXmlName(patch.GetName());
						(* OdDeltavBase.Msg2("patch.Name = ", s^);  *)
						IF patchMode = "DAV:set" THEN
							NEW(lines);
							proptags := patch.GetContents();
							WHILE proptags.HasMoreElements() DO
								p := proptags.GetNext();
								proptag :=  p(XML.Element);
								s  := proptag.GetName();
								(* OdDeltavBase.Msg2("proptag.Name = ", s^);  *)
								props := proptag.GetContents();
								WHILE props.HasMoreElements() DO
									p := props.GetNext();
									prop :=  p(XML.Element);
									propName  := prop.GetName();
									(* OdDeltavBase.Msg2("prop.Name = ", propName^); *)
									OdXml.GetCharData(prop, charData);
									(* OdDeltavBase.Msg4("href.Name = ", s^, " charData = ", charData);  *)
									COPY(propName^, line); lines.add(line);
									COPY(charData, line); lines.add(line);
								END;
							END;
							IF lines = lines.next THEN lines := NIL; END; (* If not a single line was added. *)
							IF lines # NIL THEN
								COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
								OdDeltavBase.localServer.proppatch(conf, res, patchMode, lines, xmlOut);
							END;
						ELSIF patchMode = "DAV:add" THEN
							(* (es) Not official. Used for subbaselines. *)
							NEW(lines);
							proptags := patch.GetContents();
							WHILE proptags.HasMoreElements() DO
								p := proptags.GetNext();
								proptag :=  p(XML.Element);
								s  := proptag.GetName();
								(* OdDeltavBase.Msg2("proptag.Name = ", s^);  *)
								props := proptag.GetContents();
								WHILE props.HasMoreElements() DO
									p := props.GetNext();
									prop :=  p(XML.Element);
									propName  := prop.GetName();
									(* OdDeltavBase.Msg2("prop.Name = ", propName^); *)
									hrefs := prop.GetContents();
									WHILE hrefs.HasMoreElements() DO
										p := hrefs.GetNext();
										href :=  p(XML.Element);
										s  := href.GetName();
										OdXml.GetCharData(href, charData);
										(* OdDeltavBase.Msg4("href.Name = ", s^, " charData = ", charData);  *)
										COPY(propName^, line); lines.add(line);
										COPY(charData, line); lines.add(line);
									END;
								END;
							END;
							IF lines = lines.next THEN lines := NIL; END; (* If not a single line was added. *)
							IF lines # NIL THEN
								COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
								OdDeltavBase.localServer.proppatch(conf, res, patchMode, lines, xmlOut);
							END;
						ELSIF patchMode = "D:remove" THEN
							NEW(lines);
							proptags := patch.GetContents();
							WHILE proptags.HasMoreElements() DO
								p := proptags.GetNext();
								proptag :=  p(XML.Element);
								s  := proptag.GetName();
								(* OdDeltavBase.Msg2("proptag.Name = ", s^);  *)
								props := proptag.GetContents();
								WHILE props.HasMoreElements() DO
									p := props.GetNext();
									prop :=  p(XML.Element);
									propName  := prop.GetName();
									(* OdDeltavBase.Msg2("prop.Name = ", propName^); *)
									hrefs := prop.GetContents();
									WHILE hrefs.HasMoreElements() DO
										p := hrefs.GetNext();
										href :=  p(XML.Element);
										s  := href.GetName();
										OdXml.GetCharData(href, charData);
										(* OdDeltavBase.Msg4("href.Name = ", s^, " charData = ", charData);  *)
										COPY(propName^, line); lines.add(line);
										COPY(charData, line); lines.add(line);
									END;
								END;
							END;
							IF lines = lines.next THEN lines := NIL; END; (* If not a single line was added. *)
							IF lines # NIL THEN
								COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
								OdDeltavBase.localServer.proppatch(conf, res, patchMode, lines, xmlOut);
							END;
						ELSE
							response.statuscode := WebHTTP.BadRequest;
							NEW(xmlErr, "ES:propertyupdate-mode-error"); xmlOut := xmlErr;
						END;
					END;
				ELSE
					response.statuscode := WebHTTP.Forbidden;
					NEW(xmlErr, "ES:propertyupdate-body-error"); xmlOut := xmlErr;
				END;
			ELSE
				OdDeltavBase.preCond := OdCond.MustHaveRequestBody;
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Proppatch; (* Server *)

		(** Server VERSION-CONTROL. Similar to PROPFIND*)
		PROCEDURE VersionControl(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR pos, avail, i: LONGINT; log: OdVCSBase.TLog;  flags: SET; ok: BOOLEAN; flagString: ARRAY 64 OF CHAR;
			confRes, conf, res, ver: OdUtil.Line; body: ARRAY 512 OF CHAR;
			scanner: OdXml.Scanner; parser: OdXml.Parser;
			xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes; e: XML.Element;
			props: OdDeltavBase.VersionProperties;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* VersionControl allowed *)
			response.statuscode := WebHTTP.OK;
			flags := {}; (* VCSBase.MakroBit not used at the moment *)
			COPY(request.uri, confRes); OdDeltavBase.splitConfRes(confRes, conf, res);
			IF in.Available() > 0 THEN (* there is a body *)
				(*
				in.Bytes(body, 0, in.Available(), avail); body[avail] := 0X;
				(** ) OdDeltavBase.Msg3("REPORT: request body = ", body, OdDeltavBase.I(avail)); ( **)
				IF logHeader THEN
					l.Enter; l.String(body); l.Exit;
				END;
				(* Temporary writing to a file because XML scanner wants to read from a file. *)
				xmlFile := Files.New(""); xmlFile.Set(xmlR, 0); Files.WriteString(xmlR, body); xmlFile.Update();
				(* Now parse it *)
				NEW(scanner, xmlFile);
				*)
				NEW(scanner, in);
				NEW(parser, scanner); xmlDoc := parser.Parse();
				IF OdX.FindElement(xmlDoc.GetRoot(), "DAV:version") # NIL THEN
					(* xml:version-control.version.href *)
					OdX.GetVersionControlHref(xmlDoc, ver);
					(** )IF Log THEN OdDeltavBase.Msg2("VERSION-CONTROL: version = ", ver); END; ( **)
					OdDeltavBase.localServer.selectInitialResource(conf, res, ver);
				ELSE
					response.statuscode := WebHTTP.BadRequest;
					NEW(xmlErr, "ES:error-in-version-control-request"); xmlOut := xmlErr;
				END;
			ELSE
				NEW(props, "", request.uri);
				props.get("DAV:creator-displayname", log.author);
				props.get("DAV:comment", log.logText);
				OdDeltavBase.localServer.freezeInitialResource(conf, res, log,  flags);
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END VersionControl; (* Server *)

		(** Server BASELINE-CONTROL*)
		PROCEDURE BaselineControl(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		CONST PLog = FALSE;
		VAR pos, avail, i: LONGINT; log: OdVCSBase.TLog;  flags: SET; ok: BOOLEAN; flagString: ARRAY 64 OF CHAR;
			confRes, conf, ver: OdUtil.Line; body: ARRAY 512 OF CHAR;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes; href: XML.Element;
			props: OdDeltavBase.VersionProperties;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* BaselineControl allowed *)
			response.statuscode := WebHTTP.OK;
			flags := {}; (* VCSBase.MakroBit not used at the moment *)
			COPY(request.uri, conf);
			IF in.Available() > 0 THEN (* there is a body *)
				(*
				in.Bytes(body, 0, in.Available(), avail); body[avail] := 0X;
				(** ) OdDeltavBase.Msg3("BASELINE-CONTROL: request body = ", body, OdDeltavBase.I(avail)); ( **)
				(* Temporary writing to a file because XML scanner wants to read from a file. *)
				IF logHeader THEN
					l.Enter; l.String(body); l.Exit;
				END;
				xmlFile := Files.New(""); xmlFile.Set(xmlR, 0); Files.WriteString(xmlR, body); xmlFile.Update();
				(* Now parse it *)
				NEW(scanner, xmlFile);
				*)
				NEW(scanner, in);
				NEW(parser, scanner); xmlDoc := parser.Parse();
				IF OdX.FindElement(xmlDoc.GetRoot(), "DAV:baseline") # NIL THEN
					(* xml:baseline-control.baseline.href *)
					href := OdX.SplitElement(xmlDoc.GetRoot(), "DAV:baseline.DAV:href");
					IF href # NIL THEN
						OdXml.GetCharData(href, ver);
						IF PLog THEN OdUtil.Msg2("BASELINE-CONTROL: baseline = ", ver); END;
						OdDeltavBase.localServer.selectInitialConfiguration(conf, ver);
					ELSE
						response.statuscode := WebHTTP.BadRequest;
						NEW(xmlErr, "ES:error2-in-baseline-control-request"); xmlOut := xmlErr;
					END;
				ELSE
					response.statuscode := WebHTTP.BadRequest;
					NEW(xmlErr, "ES:error1-in-baseline-control-request"); xmlOut := xmlErr;
				END;
			ELSE
				NEW(props, "", request.uri);
				props.get("DAV:creator-displayname", log.author);
				props.get("DAV:comment", log.logText);
				OdDeltavBase.localServer.freezeInitialConfiguration(conf, log,  flags);
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END BaselineControl; (* Server *)

		(** Server CHECKIN*)
		PROCEDURE Checkin(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		CONST PLog = FALSE;
		VAR confRes, conf, res: OdUtil.Line;
			log: OdVCSBase.TLog;  flags: SET; ok: BOOLEAN; body: ARRAY 512 OF CHAR; avail: LONGINT;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes;
			props: OdDeltavBase.VersionProperties;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Checkin allowed *)
			response.statuscode := WebHTTP.OK;
			flags := {}; (* VCSBase.MakroBit not used at the moment *)
			IF in.Available() > 0 THEN (* there is a body *)
				(*in.Bytes(body, 0, in.Available(), avail); body[avail] := 0X;
				IF PLog THEN OdUtilMsg3("CHECKIN: request body = ", body, OdUtilI(avail)); (**)  END;
				IF logHeader THEN
					l.Enter; l.String(body); l.Exit;
				END;
				(* Temporary writing to a file because XML scanner wants to read from a file. *)
				xmlFile := Files.New(""); xmlFile.Set(xmlR, 0); Files.WriteString(xmlR, body); xmlFile.Update();
				(* Now parse it *)
				NEW(scanner, xmlFile);
				*)
				NEW(scanner, in);
				NEW(parser, scanner); xmlDoc := parser.Parse();
				OdX.GetAuthorDesc(xmlDoc, log.author, log.logText);
				IF PLog THEN OdUtil.Msg4("CHECKIN: url, author, desc = ", request.uri, log.author, log.logText); END;
				COPY(request.uri, confRes);
				IF OdDeltavBase.isConfiguration(confRes) THEN
					OdDeltavBase.localServer.freezeOtherConfiguration(confRes, log, flags);
				ELSE
					OdDeltavBase.splitConfRes(confRes, conf, res);
					OdDeltavBase.localServer.freezeOtherResource(conf, res, log, flags);
				END;
			ELSE
				NEW(props, "", request.uri);
				props.get("DAV:creator-displayname", log.author);
				props.get("DAV:comment", log.logText);
				COPY(request.uri, confRes);
				IF OdDeltavBase.isConfiguration(confRes) THEN
					OdDeltavBase.localServer.freezeOtherConfiguration(confRes, log, flags);
				ELSE
					OdDeltavBase.splitConfRes(confRes, conf, res);
					OdDeltavBase.localServer.freezeOtherResource(conf, res, log,  flags);
				END;
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Checkin; (* Server *)

		(** Server DELETE*)
		PROCEDURE Delete(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Delete allowed *)
			response.statuscode := WebHTTP.NoContent;
			OdDeltavBase.localServer.delete(request.uri);
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Delete; (* Server *)

		(** Server MOVE*)
		PROCEDURE Move(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
			dest: ARRAY 512 OF CHAR;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Move allowed *)
			response.statuscode := WebHTTP.Created;
			IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Destination", dest) THEN
				WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Location", dest);
			END;
			(*********
			OdDeltavBase.localServer.move(request.uri);
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdCond.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
			**********)
		END Move; (* Server *)

		(** Server MKCOL*)
		PROCEDURE Mkcol(host: WebHTTPServer.Host; VAR req: WebHTTP.RequestHeader; VAR res: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		VAR xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(req, res) THEN RETURN; END;
			(* Mkcol allowed *)
			res.statuscode := WebHTTP.Created;
			OdDeltavBase.localServer.mkcol(req.uri, res.statuscode); (* Sets preCond and statuscode. *)
			IF OdDeltavBase.preCond # OdCond.Ok THEN
					NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Mkcol; (* Server *)

		(** Server OPTIONS*)
		PROCEDURE Options(host: WebHTTPServer.Host; VAR req: WebHTTP.RequestHeader; VAR res: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		BEGIN
			res.statuscode := WebHTTP.OK;
			WebHTTP.SetAdditionalFieldValue(res.additionalFields, "DAV", "1");
			OdAuthBase.AddAdditionalFieldValue(res.additionalFields, "DAV", "version-control, checkout-in-place, update, baseline");
			res.contentlength := 0;
		END Options; (* Server *)

		(** Server UPDATE *)
		PROCEDURE Update(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR xmlOut: XML.Document);
		CONST PLog = FALSE;
		VAR pos, avail, i: LONGINT; log: OdVCSBase.TLog;  flags: SET; ok: BOOLEAN; flagString: ARRAY 64 OF CHAR;
			confRes, conf, res, histVer: OdUtil.Line; body: ARRAY 512 OF CHAR;
			scanner: OdXml.Scanner; parser: OdXml.Parser; xmlFile: Files.File; xmlR: Files.Rider;
			xmlDoc: XML.Document; xmlErr: OdXml.ErrorRes;
			basicAuth: OdAuthBase.Basic;
		BEGIN
			(* Check authentication *)
			basicAuth := OdAuthBase.GetAuth(host.name);
			IF ~basicAuth.Authorized(request, response) THEN RETURN; END;
			(* Update allowed *)
			response.statuscode := WebHTTP.OK;
			IF in.Available() > 0 THEN (* there is a body *)
				(*
				in.Bytes(body, 0, in.Available(), avail); body[avail] := 0X;
				IF PLog THEN OdUtilMsg3("UPDATE: request body = ", body, OdUtilI(avail)); END;
				IF logHeader THEN
					l.Enter; l.String(body); l.Exit;
				END;
				(* Temporary writing to a file because XML scanner wants to read from a file. *)
				xmlFile := Files.New(""); xmlFile.Set(xmlR, 0); Files.WriteString(xmlR, body); xmlFile.Update();
				(* Now parse it *)
				NEW(scanner, xmlFile);
				*)
				NEW(scanner, in);
				NEW(parser, scanner); xmlDoc := parser.Parse();
				OdX.GetUpdateVersionName(xmlDoc, histVer);
				IF PLog THEN OdUtil.Msg4("UPDATE: conf, res, histVer = ", conf, res, histVer); END;
				COPY(request.uri, confRes);
				IF OdDeltavBase.isConfiguration(confRes) THEN
					OdDeltavBase.localServer.selectOtherConfiguration(confRes, histVer);
				ELSE
					OdDeltavBase.splitConfRes(confRes, conf, res);
					OdDeltavBase.localServer.selectOtherResource(conf, res, histVer);
				END;
			ELSE
				OdDeltavBase.preCond := OdCond.MustHaveRequestBody;
			END;
			IF OdDeltavBase.preCond # OdCond.Ok THEN
				response.statuscode := WebHTTP.Conflict;
				NEW(xmlErr, OdC.short[OdDeltavBase.preCond]); xmlOut := xmlErr;
			END;
		END Update; (* Server *)

		PROCEDURE Handle* (host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; VAR response: WebHTTP.ResponseHeader;
			VAR in: Streams.Reader; VAR out: Streams.Writer);
		CONST StringWriterSize = 10000;
		VAR
			f: Files.File; fr: Files.Reader; c: WebHTTP.ChunkedOutStream; r: Streams.Reader; w, aosioWriter: Streams.Writer;
			xmlOut: XML.Document; stringWriter: Streams.StringWriter;
			buf: ARRAY StringWriterSize OF CHAR;
		BEGIN
			(* HACK:  *)
			Heaps.GC;	(* force garbage collection *)
			Kernel.GC; (* call Oberon finalizers *)
			f := NIL; xmlOut := NIL; (* just to be sure *)
			response.statuscode := WebHTTP.NotImplemented;
			OdDeltavBase.preCond := OdCond.Ok;
			IF logHeader THEN
				CheckLog();
				WebHTTP.LogRequestHeader(l, request);
			END;
			CASE request.method OF
				   WebHTTP.BaselineControlM: BaselineControl(host, request, response, in, xmlOut);
				| WebHTTP.CheckinM:		      Checkin  		   (host, request, response, in, xmlOut);
				| WebHTTP.CheckoutM:	        Checkout		   (host, request, response, in, xmlOut);
				| WebHTTP.DeleteM:  		     Delete       	    (host, request, response, in, xmlOut);
				| WebHTTP.GetM:  		     	  GetDir      	    (host, request, response, in, f);
				| WebHTTP.MkcolM:        		 Mkcol        	    (host, request, response, in, xmlOut);
				| WebHTTP.MoveM:        		  Move        	    (host, request, response, in, xmlOut);
				| WebHTTP.OptionsM:		     Options     	    (host, request, response, in, xmlOut);
				| WebHTTP.PropfindM:		     Propfind    	    (host, request, response, in, xmlOut);
				| WebHTTP.ProppatchM:		  Proppatch 	    (host, request, response, in, xmlOut);
				| WebHTTP.PutM:        		     Put            	    (host, request, response, in, xmlOut);
				| WebHTTP.ReportM:		       Report	   	   (host, request, response, in, xmlOut);
				| WebHTTP.UncheckoutM:       Uncheckout	   (host, request, response, in, xmlOut);
				| WebHTTP.UpdateM:		      Update       	   (host, request, response, in, xmlOut);
				| WebHTTP.VersionControlM:   VersionControl  (host, request, response, in, xmlOut);
				ELSE
					response.statuscode := WebHTTP.NotImplemented;
					WebHTTP.WriteStatus(response, out);
					IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
					RETURN;
			END;
			IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Connection", buf) THEN
				(* Just reply close even if the request was Keep-Alive *)
				WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Connection", "close");
			END;
			IF response.statuscode = WebHTTP.Unauthorized THEN
				WebHTTP.SendResponseHeader(response, out);
				IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
				(* WebHTTPServer.davCon.Close(); *)
			ELSIF (response.statuscode = WebHTTP.OK) OR (response.statuscode = WebHTTP.NotFound)
			OR  (response.statuscode = WebHTTP.Conflict) OR  (response.statuscode = WebHTTP.Forbidden) THEN
				IF (f # NIL) THEN
					response.contentlength := f.Length();
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
					Files.OpenReader(fr, f, 0);
					WebHTTPServer.SendData(fr, out)
				ELSIF (xmlOut # NIL) THEN
					WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Content-Type", 'text/xml; charset="UTF-8"');
					NEW(c, w, out, request, response); (* Sets response.transferencoding to "chunked" *)
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN
						WebHTTP.LogResponseHeader(l, response);
						NEW(stringWriter, StringWriterSize);
						aosioWriter := stringWriter; (* For compiler. *)
						xmlOut.Write(aosioWriter, 0);
						stringWriter.Get(buf);
						l.Enter; l.String(buf); l.Exit;
					END;
					xmlOut.Write(w, 0);
					w.Ln();
					w.Update();
					c.Close()
				ELSE (* no response data *)
					IF (request.method = WebHTTP.GetM) THEN
						NEW(c, w, out, request, response);
						WebHTTP.SendResponseHeader(response, out);
						IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
						w.String(DocType); w.Ln();
						w.String("<html><head><title>404 - Not Found</title></head>");
						w.String("<body>HTTP 404 - File Not Found<hr><address>");
						w.String(PluginVersion); w.String( "</address></body></html>");
						w.Ln();
						w.Update();
						c.Close()
					ELSE
						WebHTTP.SendResponseHeader(response, out);
						IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
					END;
				END
			ELSIF (response.statuscode = WebHTTP.NotModified) THEN
				WebHTTP.SendResponseHeader(response, out)
			ELSIF (response.statuscode = WebHTTP.ObjectMoved) THEN
				IF (request.method = WebHTTP.GetM) THEN
					NEW(c, w, out, request, response);
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
					w.String(DocType); w.Ln();
					w.String("<html><head><title>Document Moved</title></head>"); w.Ln();
					w.String('<body><h1>Document Moved</h1>This document may be found <a href="http://');
					w.String(request.uri); w.String(">here</a>.<hr><address>");
					w.String(PluginVersion); w.String("</address></body></html>"); w.Ln();
					w.Update();
					c.Close()
				ELSE
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
				END;
			ELSE (* Other statuscode *)
				IF xmlOut # NIL THEN
					WebHTTP.SetAdditionalFieldValue(response.additionalFields, "Content-Type", 'text/xml; charset="UTF-8"');
					NEW(c, w, out, request, response); (* Sets response.transferencoding to "chunked" *)
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN
						WebHTTP.LogResponseHeader(l, response);
						NEW(stringWriter, StringWriterSize);
						aosioWriter := stringWriter; (* For compiler. *)
						xmlOut.Write(aosioWriter, 0);
						stringWriter.Get(buf);
						l.Enter; l.String(buf); l.Exit;
					END;
					xmlOut.Write(w, 0);
					w.Ln();
					w.Update();
					c.Close()
				ELSE
					WebHTTP.SendResponseHeader(response, out);
					IF logHeader THEN WebHTTP.LogResponseHeader(l, response); END;
				END;
			END
		END Handle;
	END DeltavPlugin;

VAR
	log: AosLog.Log;

(** Logging for WebDAV plugin. *)
VAR
	l : AosLog.Log;
	hostNames: ARRAY 1024 OF CHAR;
	logFileBase: Files.FileName;
	day: ARRAY 8 OF CHAR; (* Day of week. *)
VAR
	deltav: DeltavPlugin;
	OdX:OdXml.OdXml;
	OdC:OdCond.OdCond;


(** Sends all available data from a connection to a file. Perhaps more efficient with AosActive.TimeOut ?
	Without reading connection. Seems not to work at the moment. *)
PROCEDURE Con2FileNew(in: Streams.Reader; len: LONGINT; f: Files.File);
CONST SleepMax = 100; SleepTime = 200 (*ms*); BufSize = 1024;
VAR i, read, slept, startTicks: LONGINT;
	fr: Files.Rider; buf: ARRAY BufSize OF CHAR;
	avail, rc: LONGINT; ch: CHAR;
BEGIN
	IF Log THEN
			log.Enter; log.String("Con2File "); log.TimeStamp; log.Exit;
	END;
	slept := 0; startTicks := Kernel.GetTicks(); read := 0;
	f.Set(fr, 0);
	LOOP
		IF read >= len THEN
			IF Log THEN
				log.Enter; log.String("Con2File done "); log.TimeStamp; log.Exit;
			END;
			EXIT;
		END;
		avail := in.Available();
		IF avail  > 0 THEN
			slept := 0;
			IF Log THEN
				log.Enter; log.TimeStamp; log.Int(avail, 5); log.Exit;
			END;
			FOR i := 1 TO avail DO f.Write(fr, in.Get()); END;
			f.Update();
			INC(read, avail);
			slept := 0; startTicks := Kernel.GetTicks();
		ELSE
			IF Kernel.GetTicks() > startTicks + SleepTime THEN
				INC(slept);
				IF slept > SleepMax THEN
					IF Log THEN
						log.Enter; log.TimeStamp; log.String("50x200 ms"); log.Exit;
					END;
					EXIT;
				END;
			END;
			Objects.Yield;
		END;
	END;
END Con2FileNew;

(* PH conn to file: chunk: ARRAY 4096 OF CHAR
		NEW(writer, file, 0);
		NEW(reader, fileClipboard, 0);
		WHILE (reader.res = Streams.Ok) DO
			reader.Bytes(chunk, 0, LEN(chunk), len);
			writer.Bytes(chunk, 0, len);
		END;
		writer.Update;
		Register(file);

*)

(** Sends all available data from a connection to a file. Perhaps more efficient with Objects.TimeOut ?
	Old version with reading from connection after using Streams.Reader. *)
PROCEDURE Con2FileOld(in: Streams.Reader; con: TCP.Connection; len: LONGINT; f: Files.File);
CONST SleepMax = 100; SleepTime = 200 (*ms*); BufSize = 1024;
VAR i, read, slept, startTicks: LONGINT; timer: Kernel.Timer;
	fr: Files.Rider; buf: ARRAY BufSize OF CHAR;
	avail, rc: LONGINT; ch: CHAR;
BEGIN
	IF Log THEN
			log.Enter; log.String("Con2File "); log.TimeStamp; log.Exit;
	END;
	NEW(timer); slept := 0; read := 0; startTicks := Kernel.GetTicks();
	f.Set(fr, 0);
	LOOP
		IF read >= len THEN EXIT; END;
		avail := in.Available();
		IF avail  > 0 THEN
			slept := 0;
			IF Log THEN
				log.Enter; log.TimeStamp; log.Int(avail, 5); l.Exit;
			END;
			FOR i := 1 TO avail DO f.Write(fr, in.Get()); END;
			INC(read, avail);
			EXIT;
		ELSE
			IF Kernel.GetTicks() > startTicks + SleepTime THEN
				INC(slept);
			END;
			IF slept > SleepMax THEN
				IF Log THEN
					log.Enter; log.TimeStamp; log.String("100x200 ms"); l.Exit;
				END;
				EXIT;
			END;
			Objects.Yield;
		END;
	END;
	IF Log THEN
			log.Enter; log.String("Read from con: "); log.TimeStamp; log.Int(len, 5); log.Int(read, 5); log.Exit;
	END;
	IF read < len THEN
		(* read directly from connection *)
		LOOP
			avail := con.Available();
			IF avail > 0 THEN
				(** ) KernelLog.Enter; KernelLog.String("avail = "); KernelLog.Int(avail, 1); KernelLog.Exit; ( **)
				IF avail > BufSize THEN avail := BufSize; END;
				con.Receive(buf, 0, avail, avail, avail, rc);
				f.WriteBytes(fr, buf, 0, avail);
				read := read+avail; slept := 0;
				IF read >= len THEN EXIT; END;
			ELSE
				timer.Sleep(SleepTime);
				INC(slept);
				IF slept = SleepMax THEN
					IF Log THEN
						log.Enter; log.TimeStamp; log.String("50x200 ms"); log.Exit;
					END;
					EXIT;
				END;
				timer.Sleep(SleepTime);
			END;
		END;
	END;
	Files.Register(f);
END Con2FileOld;

(* Find size of an XML object which must be written. *)
PROCEDURE XmlSize(doc: XML.Document): LONGINT;
VAR counter: Streams.Writer;
BEGIN
	Streams.OpenWriter(counter, OdUtil.Dev0); doc.Write(counter, 0); counter.Update();
	RETURN counter.sent;
END XmlSize;




PROCEDURE Install*(context: Commands.Context); (** [{host}]. Host may include wildcards. *)
VAR host: ARRAY 1024 OF CHAR;
	hl: WebHTTPServer.HostList; res:BOOLEAN;
BEGIN
	REPEAT
		res:=context.arg.GetString(host);
		Strings.Trim(host, " ");
		(*IF host = "" THEN RETURN END;*) (*MODIFIED PH*)

		hl := WebHTTPServer.FindHosts(host);
		IF (hl # NIL) THEN
			WHILE (hl # NIL) DO
				IF (hl.host.name # "") THEN
					(* Don't add to default host. *)
					hl.host.AddPlugin(deltav);
					KernelLog.String("DeltaV-Plugin"); KernelLog.String(" added to "); KernelLog.String(hl.host.name);
					KernelLog.Ln;
				ELSE (*add to default host*) (*MODIFIED PH *)
					hl.host.AddPlugin(deltav);
					KernelLog.String("DeltaV-Plugin"); KernelLog.String(" added to default host");
					KernelLog.Ln;
				END;
				hl := hl.next
			END
		ELSE
			KernelLog.String("Host '"); KernelLog.String(host); KernelLog.String("' not found."); KernelLog.Ln
		END
	UNTIL (context.arg.res # Streams.Ok);
END Install;

PROCEDURE Uninstall0(VAR hostNames: ARRAY OF CHAR); (** [{host}]. Host may include wildcards. *)
VAR r: Streams.StringReader; host: ARRAY 1024 OF CHAR;
	hl: WebHTTPServer.HostList;
BEGIN
	NEW(r, Strings.Length(hostNames)); r.Set(hostNames);
	REPEAT
		r.SkipWhitespace;
		r.String(host);
		IF host # "" THEN
			(* WebHTTPServer.FindHosts(host); seems to make problems in this case. *)
			hl := WebHTTPServer.FindHosts(host);
			IF (hl # NIL) THEN
				WHILE (hl # NIL) DO
					IF (hl.host.name # "") THEN
						(* Don't add to default host. *)
						hl.host.RemovePlugin(deltav);
						KernelLog.String("DeltaV-Plugin"); KernelLog.String(" removed from "); KernelLog.String(hl.host.name);
						KernelLog.Ln;
					END;
					hl := hl.next
				END
			ELSE
				KernelLog.String("Host '"); KernelLog.String(host); KernelLog.String("' not found."); KernelLog.Ln
			END
		END
	UNTIL (r.res # Streams.Ok);
END Uninstall0;

PROCEDURE Uninstall*(context:Commands.Context); (** [{host}]. Host may include wildcards. *)
VAR host: ARRAY 1024 OF CHAR;
	hl: WebHTTPServer.HostList; res:BOOLEAN;
BEGIN
	REPEAT
		res:=context.arg.GetString(host);
		Uninstall0(host);
	UNTIL (context.arg.res # Streams.Ok);
	RETURN
END Uninstall;


(* Day of week: "Mon"-"Sun" *)
PROCEDURE Day(VAR day: ARRAY OF CHAR);
VAR d, t: LONGINT;
BEGIN
	Clock.Get(t, d);
	Strings.FormatDateTime("www", Dates.OberonToDateTime(d, t), day);
END Day;

PROCEDURE setLog;
	VAR fileName: Files.FileName; res: LONGINT;
	BEGIN
		Day(day);
		Strings.Concat(logFileBase, ".", fileName); Strings.Append(fileName, day);
		NEW(l, "DeltaV");
		l.SetLogToOut(FALSE);
		Files.Delete(fileName, res);
		l.SetLogFile(fileName); l.SetLogFile(fileName); (* To force registering. *)
		deltav.logHeader := TRUE;
		KernelLog.Enter; KernelLog.String("WebDAVPlugin.setLog "); KernelLog.String(fileName); KernelLog.Exit;
	END setLog;

(* Check whether a logfile for the next day must be used. *)
PROCEDURE CheckLog;
	VAR fileName: ARRAY 128 OF CHAR; today: ARRAY 8 OF CHAR;
	BEGIN
		IF l # NIL THEN
			Day(today);
			IF day # today THEN
				l.Close();
				setLog();
			END;
		END;
	END CheckLog;

PROCEDURE SetLog * (context:Commands.Context); (** <filename>("Mon"-"Sun")*)
	VAR logFileName: ARRAY 128 OF CHAR; res:BOOLEAN;
	BEGIN
		IF l = NIL THEN
			res:=context.arg.GetString(logFileName);
			Strings.Trim(logFileName," ");
			IF logFileName # "" THEN
				COPY(logFileName, logFileBase);
				setLog()
			ELSE
				KernelLog.Enter; KernelLog.String("WebDAVPlugin.SetLog <filename>"); KernelLog.Exit;
			END;
		ELSE
			KernelLog.Enter; KernelLog.String("WebDAVPlugin.SetLog: log already set"); KernelLog.Exit;
		END;
		RETURN;
	END SetLog;

PROCEDURE CloseLog * ;
	BEGIN
		IF l # NIL THEN
			deltav.logHeader := FALSE;
			l.Close();
			l := NIL;
			KernelLog.Enter; KernelLog.String("WebDAVPlugin.CloseLog: done"); KernelLog.Exit;
		ELSE
			KernelLog.Enter; KernelLog.String("WebDAVPlugin.CloseLog: log already closed"); KernelLog.Exit;
		END;
	END CloseLog;


PROCEDURE LogHeaderOn*; BEGIN deltav.logHeader := TRUE; END LogHeaderOn;
PROCEDURE LogHeaderOff*; BEGIN deltav.logHeader := FALSE; END LogHeaderOff;

PROCEDURE Cleanup;
VAR dummy: ANY; t: Kernel.Timer;
BEGIN
	IF Log THEN log.Close END;(* Trace log. *)
	Uninstall0(hostNames);
	CloseLog;
END Cleanup;

BEGIN
	(* Tracelog *)
	IF Log THEN
		NEW(log, "Server");
		log.SetLogToOut(TRUE)
	END;
	hostNames := "";
	NEW(deltav, "DeltaV-Plugin");
	(**)logFileBase := "../httproot/WebDAVLog"; setLog();(**) (* Request, response log *)
	(*logFileBase := "WebDAVLog"; setLog();*) (* Request, response log *)
	Modules.InstallTermHandler(Cleanup);
	NEW(OdC); NEW(OdX);
END OdPlugin.

WebHTTPServerTools.Start \r:../httproot \l:../httproot/HTTP.Log ~
WebHTTPServerTools.Start \r:E:/O \l:HTTP.Log ~

WebHTTPServerTools.AddHost davhost \r:../httproot/dav \l:../httproot/WebHTTPServer.Log ~
WebHTTPServerTools.Stop ~

OdPlugin.Install ~ (*work only without host because default host install was done in source*)
OdPlugin.Install davhost ~
OdPlugin.LogHeaderOn ~

WebDAVPlugin.Uninstall ~


SystemTools.Free WebDAVPlugin DeltavBase VCS VCSBase WebDAVClient WebDAVClientTools~
../httproot/WebDAVLog.Sat

DCT is short for WebDAVClientTools to allow for shorter command lines.
Set a default prefix to allow remote and local use of the commands below.
OCT.SetHost "127.0.0.1" ~ ^"webdav.computational.ch"
OCT.Propfind "/" ~
System.OpenKernelLog ! Shows output.
Some test scenarios as examples.
version-control resource /Test1/index.html
Configuration.DoCommands
DCT.Delete "/Test1/"
DCT.Mkcol "/Test1/"
! create initial version
DCT.Put "/Test1/index.html" index1.html ~
DCT.VersionControlFreeze "/Test1/index.html" "Edgar Schwarz" "Version 1" ~
! second version
DCT.Checkout "/Test1/index.html" ~
DCT.Uncheckout "/Test1/index.html" ~
DCT.Checkout "/Test1/index.html" ~
DCT.Put "/Test1/index.html" index2.html ~
DCT.Checkin "/Test1/index.html" "Edgar Schwarz" "Version 2" ~
! get some info
DCT.Propfind "/Test1/index.html" ~
DCT.Update "/Test1/index.html" "2" ~
DCT.Propfind "/Test1/index.html" ~
DCT.Update "/Test1/index.html" "1" ~
DCT.Propfind "/Test1/index.html" ~
DCT.ReportVersionTree "/Test1/index.html" ~
~
create two baselines in /ws1/
Configuration.DoCommands
DCT.Delete "/ws1/"
DCT.Mkcol "/ws1/"
! version-control Testa.Text, Testb.Text
DCT.Put "/ws1/Testa.Text" Test1.Text
DCT.VersionControlFreeze "/ws1/Testa.Text" "Edgar Schwarz" "Testa.Text version 1"
DCT.Put "/ws1/Testb.Text" Test1.Text
DCT.VersionControlFreeze "/ws1/Testb.Text" "Edgar Schwarz" "Testb.Text version 1"
! baseline-control ws1
DCT.BaselineControlFreeze "/ws1/" "Edgar Schwarz" "ws1 baseline 1"
! new version of Testa.Text
DCT.Checkout "/ws1/Testa.Text"
DCT.Put "/ws1/Testa.Text" Test2.Text
DCT.Checkin "/ws1/Testa.Text" "Edgar Schwarz" "Version 2"
! new version of ws1/
DCT.Checkout "/ws1/"
DCT.Checkin "/ws1/" "Edgar Schwarz" "ws1 baseline 2"
DCT.ReportCompareBaseline "/hist/0ws1_.1" "/hist/0ws1_.2"
DCT.ReportVersionTree "/ws1_"
 version list of baseline
DCT.Get "/dav_" dav_





Builder.Compile * System.Free WebDAVPlugin DeltavBase VCS VCSBase ~

OFSTools.Mount DV AosFS IDE0#05 ~ OFSTools.Unmount DV ~
OFSTools.Mount DV RamFS  VDISK0~

(* Collection DV:deltav.test. exists. OdDeltavBase.localServer,localClient are created with loading. *)
Environment
Repository: v.<resource name>
Release configuration: deltav.rel.
Development configuration: deltav.dev


OdDeltavBase.fiR test Test.html "edgar@edgarschwarz.de" "First version of test1" expand ~~

Old Interface:
VCS.HandleView v.data1.Text 1 VCS.init v.deltav.test. VCS.init v.data1.Text VCS.rlog v.deltav.test. 3
Report VCS.init  <file name> 	; number of versions, -1 if none exist
			shows number of versions in <version number>
CheckIn VCS.New <file name> "<author>" "log text"
			; create new version, first is 1, else increment last
PropFind VCS.rlog <file> <version> VCS.rlog v.data3.Text 1
			; show log text of version in System.log and also in panel
			; tags only will be expanded it log text starts with $
CheckOut  VCS.HandleView <file name> <version number>
			; get version from file and create file <file>.V<version>
			; if it doesn't exist


AddPlugin
PROCEDURE Close;
BEGIN
	log.Close();
	AosHTTPServer.RemoveHost("eth20853.ethz.ch");
	AosHTTPServer.RemoveHost("huga.ethz.ch")
END Close;
VAR pp : PostTestPlugin;
	NEW(pp); AosHTTPServer.standardHost.AddPlugin(pp);
	AosModules.InstallTermHandler(Close)



					ELSIF (WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Type", contentType)) THEN

					KernelLog.Enter(); KernelLog.String("WebDAV: PUT - handling content: "); KernelLog.String(contentType); KernelLog.String(" ");

					KernelLog.String(request.uri); KernelLog.String(" ");

					Strings.UpperCase(contentType);

					IF WebHTTP.GetAdditionalFieldValue(request.additionalFields, "Content-Length", s)

					THEN Strings.StrToInt(s, length);

					ELSE length := -1;

					END;

					Strings.Append(fn,request.uri); (*TODO refine*)

					KernelLog.String(fn); KernelLog.Ln; KernelLog.Exit();

					f:=Files.New(fn);

					IF f # NIL THEN		(*TODO simplify*)

						Files.OpenWriter(fw,f,0);

						c := in.Get();

						len := 1;

						WHILE (in.res = Streams.Ok) & (len < length) DO


							fw.Char(c);

							c := in.Get();

							INC(len);

							IF len MOD 256 = 0 THEN fw.Update() END;

						END;

						IF (in.res = Streams.Ok) THEN

							fw.Char(c);

						END;

						fw.Update(); f.Register0(res);

						IF res#0 THEN KernelLog.String("PUT upload failed: file not registerable: "); KernelLog.String(fn); KernelLog.Ln; END;

					END;

					NEW(context); context.w := out; context.request := r; context.reply := reply; reply.statuscode:=WebHTTP.OK; reply.reasonphrase:="";

					reply.contenttype := "text/html; charset=UTF-8"; reply.contentlength:=0;

					WebHTTP.SendResponseHeader(reply, out);

				END;



				(* pastes the fileClipboard into the file with the given name if it doesn't exist already *)
PROCEDURE Paste*(name: ARRAY OF CHAR; VAR res: LONGINT);
VAR writer : Writer;
	reader : Reader;
	file : File;
	chunk : ARRAY 4096 OF CHAR;
	len : LONGINT;
BEGIN
	IF fileClipboard = NIL THEN RETURN END;
	IF Old(name) # NIL THEN res := FileAlreadyExists;			(* File already exists *)
	ELSE
		file := New(name);
		IF file = NIL THEN res := BadFileName; RETURN END;	(* Bad Filename *)
		NEW(writer, file, 0);
		NEW(reader, fileClipboard, 0);
		WHILE (reader.res = Streams.Ok) DO
			reader.Bytes(chunk, 0, LEN(chunk), len);
			writer.Bytes(chunk, 0, len);
		END;
		writer.Update;
		Register(file);
		res := 0;
	END;
END Paste;

