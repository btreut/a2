(* Aos, Copyright 2003, Edgar Schwarz, ETH Zurich
Authors.   Edgar Schwarz
Contents. Clientside methods.


09-07-31: robin stoll
 - put everything into OdClient object
 - fixed StoreResult2File, support for missing Content-Length
 - open only one TCP connection per object
 - added Connection: keep-alive
 - added svn dependent procedures/stuff
*)

MODULE OdClient; (** AUTHOR "TF"; PURPOSE "HTTP client"; *)

IMPORT
	TCP, Streams, IP, Files, DNS, WebHTTP, Modules, Kernel,
	XML, XMLObjects, OdAuthBase, OdXml, OdUtil, Strings, MultiLogger,
	Commands;

VAR
	log * : OdUtil.Log;
	traceLevel * : LONGINT;

CONST
	Ok* = 0;
	ResCOULDNOTCONNECT* = -1;
	ResHOSTNOTFOUND* = -2;
	UserAgent = "ObeDAV 0.15";

	ShowDebugWindow = FALSE;


CONST (* Tracelevels *)
(*	TlNone = 0;*)
	TlHeader = 1;
	TlBody = 2;

(*<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*)

TYPE
	(** This realizes the relation between a serverside version controlled configuration (VCC) and a clientside workspace.
		It works also on the members of the VCC to allow easier up and download between client and server.
		With a highspeed connection it doesn't matter to upload also unchanged files. So bookkeping on local changes
		isn't important.
		This isn't quite what is specified for clientside workspaces but should be good enough for a simple process with
		no versioning in the local workspace.
		DeltaV doesn't define any depth header for CHECKIN, CHECKOUT. So Vcc must get the information from the server
		and send requests for single resources.
		 *)

	Vcc * = OBJECT (*POINTER TO RECORD*)
		VAR
			state: ARRAY 16 OF CHAR;
			client : OdClient;
			xml : OdXml.OdXml;
		PROCEDURE &init* ( c : OdClient );
		BEGIN
			client := c;
			xml := client.xml;
		END init;

		(* Split at the last '/' at the moment. *)
		PROCEDURE SplitConfRes(CONST confRes: ARRAY OF CHAR; VAR conf, res: ARRAY OF CHAR);
		CONST CollCh = '/';
		VAR len, pos: LONGINT;
		BEGIN
			len := Strings.Length(confRes);
			pos  := len - 1;
			LOOP
				IF (pos < 0) OR (confRes[pos] = CollCh) THEN EXIT; ELSE DEC(pos); END;
			END;
			IF pos = -1 THEN
				COPY("/", conf); COPY(confRes, res);
			ELSE
				Strings.Copy(confRes, 0, pos+1, conf);
				Strings.Copy(confRes, pos+1, len - pos - 1, res);
			END;
		END SplitConfRes;

		(* Get filelist of server discriminated by version state *)
		PROCEDURE VersionMembers(CONST remote: ARRAY OF CHAR; VAR all, unversioned, checkedin, checkedout: OdUtil.Lines);
		VAR
			res: LONGINT;
			resHeader: WebHTTP.ResponseHeader; out : Streams.Reader;
			doc: XML.Document; root, response, href, prop: XML.Element;
			responses: XMLObjects.Enumerator; p: ANY;
			unpaddedRemote: ARRAY 256 OF CHAR;
			propNames: WebHTTP.AdditionalField; elName, name, resName, confName: OdUtil.Line;
		BEGIN
			NEW(all); NEW(unversioned); NEW(checkedin); NEW(checkedout);
			ShowMethodUrl(WebHTTP.PropfindM, Url(remote, "")); (* Url of the server directory. *)
			propNames := NIL;
			WebHTTP.SetAdditionalFieldValue(propNames, "D:displayname", "");
			WebHTTP.SetAdditionalFieldValue(propNames, "D:getcontentlength", "");
			WebHTTP.SetAdditionalFieldValue(propNames, "D:getlastmodified", "");
			WebHTTP.SetAdditionalFieldValue(propNames, "D:resourcetype", "");
			WebHTTP.SetAdditionalFieldValue(propNames, "D:checked-in", "");
			WebHTTP.SetAdditionalFieldValue(propNames, "D:checked-out", "");
			client.Propfind(Url(remote, ""), "1", propNames, resHeader, out, res);
			doc := client.XmlResult(resHeader, res, out);
			IF doc # NIL THEN
				COPY(remote, unpaddedRemote); OdUtil.unpadColl(unpaddedRemote);
				(* OdXml.LogDoc("VersionMembers", doc); *)
				root := doc.GetRoot(); elName := xml.AbsXmlName(root.GetName());
				IF elName = "DAV:multistatus" THEN
					responses := root.GetContents();
					WHILE responses.HasMoreElements() DO
						p := responses.GetNext();
						response :=  p(XML.Element);
						IF response # NIL THEN
							href := xml.FindElement(response, "DAV:href");
							IF href # NIL THEN
								OdXml.GetCharData(href, name);
								(** ) ls("VersionMembers remote = ", remote); ( **)
								(** ) ls("VersionMembers href = ", name); ( **)
								IF unpaddedRemote = name THEN (* Configuration collection *)
									(* Check for version stuff *)
									state := "unversioned";
									prop := xml.SplitElement(response, "DAV:propstat.DAV:prop.DAV:checked-in");
									IF prop # NIL THEN
										state := "checkedin";
									ELSE
										prop := xml.SplitElement(response, "DAV:propstat.DAV:prop.DAV:checked-out");
										IF prop # NIL THEN
											state := "checkedout"; (* The collection already is a configuration. *)
										END;
									END;
								ELSE
									IF name # "" THEN (* There seems to be a bug leaving a empty named file*)
										SplitConfRes(name, confName, resName);
										all.add(resName);
										prop := xml.SplitElement(response, "DAV:propstat.DAV:prop.DAV:checked-in");
										IF prop # NIL THEN
										(** ) ls("VersionMembers: checkedin = ", resName); ( **)
											checkedin.add(resName);
										ELSE
											prop := xml.SplitElement(response, "DAV:propstat.DAV:prop.DAV:checked-out");
											IF prop # NIL THEN
											(** ) ls("VersionMembers: checkedout = ", resName); ( **)
												checkedout.add(resName);
											ELSE
												(** ) ls("VersionMembers: unversioned = ", resName); ( **)
												unversioned.add(resName);
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
			IF  all                 =  all.next               THEN all                := NIL; END;
			IF  checkedin     = checkedin.next    THEN checkedin    := NIL; END;
			IF  checkedout  = checkedout.next  THEN checkedout  := NIL; END;
			IF  unversioned = unversioned.next THEN unversioned := NIL; END;
		END VersionMembers;

		(* Make URL from resource name. A basename at the moment. *)
		PROCEDURE Url(CONST remote, resName: ARRAY OF CHAR): OdUtil.Line;
		VAR url: OdUtil.Line;
		BEGIN
			IF resName # "" THEN
				Strings.Concat(remote, resName, url);
			ELSE
				COPY(remote, url);
			END;
			RETURN url;
		END Url;

		(* Get filelist of client directory *)
		PROCEDURE ClientMembers(CONST dir: ARRAY OF CHAR): OdUtil.Lines;
		VAR
			enum: Files.Enumerator; time, date, size: LONGINT; entryFlags, flags: SET;
			pattern: ARRAY 128 OF CHAR;
			fileNames: OdUtil.Lines; name: OdUtil.Line;
		BEGIN
			Strings.Concat(dir, "*", pattern);
			entryFlags := {}; flags := {};
			NEW(enum); enum.Open(pattern, flags);
			NEW(fileNames);
			WHILE enum.GetEntry(name, entryFlags, time, date, size) DO
				IF ~ (Files.Directory IN entryFlags) THEN
					fileNames.add(name);
				END;
			END;
			IF fileNames = fileNames.next THEN fileNames := NIL; END;
			RETURN fileNames;
		END ClientMembers;

		(* Get resource names. At the moment just the basename of the file. *)
		PROCEDURE ClientRes(CONST local: ARRAY OF CHAR): OdUtil.Lines;
		VAR res, confRes: OdUtil.Lines; resName, confName: OdUtil.Line;
		BEGIN
			NEW(res);
			confRes := ClientMembers(local);
			WHILE confRes # NIL DO
				(* ls("confRes = ", confRes.line); *)
				SplitConfRes(confRes.line, confName, resName);
				(* ls("resName = ", resName); *)
				res.add(resName);
				confRes := confRes.next;
			END;
			IF res = res.next THEN res := NIL; END;
			RETURN res;
		END ClientRes;

		(* Make absolute filename from resource name. A basename at the moment. *)
		PROCEDURE AbsRes(CONST local, resName: ARRAY OF CHAR): OdUtil.Line;
		VAR absRes: OdUtil.Line;
		BEGIN
			Strings.Concat(local, resName, absRes);
			RETURN absRes;
		END AbsRes;

		(** Put members from client to server workspace. Members which are still on the server but no more
			on the client side are removed on the server. *)
		PROCEDURE put * (CONST remote, local: ARRAY OF CHAR);
		CONST PLog = FALSE;
		VAR
			toDelete, toPut: OdUtil.Lines;
			f: Files.File; in: Files.Reader; out: Streams.Reader;
			reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader;
			doc: XML.Document; lenStr: ARRAY 16 OF CHAR;
			root: XML.Element; s: XML.String;
			url, info: ARRAY 128 OF CHAR; rc: LONGINT;
			all, unversioned, checkedin, checkedout: OdUtil.Lines;
		BEGIN
			toPut := ClientRes(local);
			VersionMembers(remote, all, unversioned, checkedin, checkedout);
			(* DELETE old members which aren't in new ones. *)
			toDelete := toPut.notIn(all);
			WHILE toDelete # NIL DO
				IF PLog THEN ls("Vcc.put: toDelete.line = ", Url(remote, toDelete.line)); END;
				ShowMethodUrl(WebHTTP.DeleteM, Url(remote, toDelete.line));
				client.Delete(Url(remote, toDelete.line), resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "error" THEN
							xml.LogDoc("WebDAVClient.Delete: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  url);
						info := "DAV:error = "; Strings.Append(info, url);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
				toDelete := toDelete.next;
			END;
			(* PUT local members. *)
			WHILE toPut # NIL DO
				f := Files.Old(AbsRes(local, toPut.line));
				IF f # NIL THEN
					IF PLog THEN ls("Vcc.put: toPut = ", Url(remote, toPut.line)); END;
					NEW(in, f, 0);
					WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Type", "application/octet-stream");
					Strings.IntToStr(f.Length(), lenStr);
					WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", lenStr);
					ShowMethodUrl(WebHTTP.PutM, Url(remote, toPut.line));
					client.Put(Url(remote, toPut.line), reqHeader, resHeader, out, in, rc);
					doc := client.XmlResult(resHeader, rc, out);
					IF doc # NIL THEN
						LOOP (*  *)
							root := doc.GetRoot();
							s := root.GetName();
							IF s^ # "error" THEN
								xml.LogDoc("WebDAVClient.Checkout: Unexpected root element = ", doc);
								EXIT;
							END;
							OdXml.GetCharData(root,  url);
							info := "DAV:error = "; Strings.Append(info, url);
							log.Enter; log.String(info); log.Exit;
							EXIT;
						END;
					END;
				END;
				toPut := toPut.next;
			END;
		END put;

		(** Get members from server to client workspace. *)
		PROCEDURE get * (CONST remote, local: ARRAY OF CHAR);
		VAR
			toDelete, all, unversioned, checkedin, checkedout: OdUtil.Lines;
		BEGIN
			VersionMembers(remote, all, unversioned, checkedin, checkedout);
			(* DELETE old members which aren't in new ones. *)
			toDelete := all.notIn(ClientMembers(local));
			WHILE toDelete # NIL DO
				(* Delete(url: ARRAY OF CHAR; VAR con : TCP.Connection;
					VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
				*)
				toDelete := toDelete.next;
			END;
			(* GET local members. *)
			WHILE all # NIL DO
				(* Get*(url : ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader; VAR con : TCP.Connection;
					VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; in : Streams.Reader; VAR res : LONGINT);
				*)
				all := all.next;
			END;
		END get;

		(** Checkin members and then VCC. Subbaselines must be checked in and updated before. If a PUTed resource
			isn't different from the old version no new version is created. *)
		PROCEDURE checkin * (CONST remote, author, desc: ARRAY OF CHAR);
		CONST PLog = TRUE;
		VAR
			all, unversioned, checkedin, checkedout: OdUtil.Lines;
			reqHeader : WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader;
			out : Streams.Reader; rc: LONGINT;
			doc: XML.Document; root: XML.Element; info, rootStr: ARRAY 128 OF CHAR; s: XML.String;
			props: WebHTTP.AdditionalField;
		BEGIN
			(* VERSION-CONTROL new server members. CHECKIN existing. *)
			VersionMembers(remote, all, unversioned, checkedin, checkedout);
			WHILE unversioned # NIL DO
				IF PLog THEN ls("Vcc.checkin: toVersionControl = ", unversioned.line); END;
				(* TODO: Proppatch desc and author *)
				(*     Set DAV:comment and DAV:creator-displayname    *)
				props := NIL;
				WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
				WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
				ShowMethodUrl(WebHTTP.ProppatchM, Url(remote, unversioned.line));
				client.Proppatch(Url(remote, unversioned.line), "set", props, resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out); (* Read potential body. *)
				IF resHeader.statuscode # WebHTTP.OK THEN
					log.Enter; log.String("Vcc.checkin: Proppatch error"); log.Exit;
				END;
				(* Version Control Freeze *)
				ShowMethodUrl(WebHTTP.VersionControlM, Url(remote, unversioned.line));
				client.VersionControlFreeze(Url(remote, unversioned.line), reqHeader, resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					xml.LogDoc("XML body not parsed yet", doc);
				END;
				unversioned := unversioned.next;
			END;
			(* CHECKIN existing server members. *)
			WHILE checkedout # NIL DO
				IF PLog THEN ls("Vcc.checkin: checkedout = ", checkedout.line); END;
				(* Don't check whether it's checked in. Assume before there was a checkout if necessary.  *)
				(*     Set DAV:comment and DAV:creator-displayname    *)
				props := NIL;
				WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
				WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
				ShowMethodUrl(WebHTTP.ProppatchM, Url(remote, checkedout.line));
				client.Proppatch(Url(remote, checkedout.line), "set", props, resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out); (* Read potential body. *)
				IF resHeader.statuscode # WebHTTP.OK THEN
					log.Enter; log.String("Vcc.checkin: Proppatch error"); log.Exit;
				END;
				(*  Checkin *)
				ShowMethodUrl(WebHTTP.CheckinM, Url(remote, checkedout.line));
				client.Checkin(Url(remote, checkedout.line), resHeader, out, rc);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "error" THEN
							xml.LogDoc("WebDAVClient.Checkin: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  rootStr);
						info := "DAV:error = "; Strings.Append(info, rootStr);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
				checkedout := checkedout.next;
			END;
			(*     Set DAV:comment and DAV:creator-displayname    *)
			props := NIL;
			WebHTTP.SetAdditionalFieldValue(props, "DAV:creator-displayname", author);
			WebHTTP.SetAdditionalFieldValue(props, "DAV:comment", desc);
			ShowMethodUrl(WebHTTP.ProppatchM, Url(remote, ""));
			client.Proppatch(Url(remote, ""), "set", props, resHeader, out, rc);
			doc := client.XmlResult(resHeader, rc, out); (* Read potential body. *)
			IF resHeader.statuscode # WebHTTP.OK THEN
				log.Enter; log.String("Vcc.checkin: Configuration Proppatch error"); log.Exit;
			END;
			IF state = "unversioned" THEN
				(* Baseline-control *)
				ShowMethodUrl(WebHTTP.BaselineControlM, Url(remote, ""));
				client.BaselineControlFreeze(Url(remote, ""), reqHeader, resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "error" THEN
							xml.LogDoc("WebDAVClient.BaselineControlFreeze: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  rootStr);
						info := "DAV:error = "; Strings.Append(info, rootStr);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
			ELSIF state = "checkedout" THEN
				(* Checkin *)
				ShowMethodUrl(WebHTTP.CheckinM, Url(remote, ""));
				client.Checkin(Url(remote, ""), resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						s := root.GetName();
						IF s^ # "error" THEN
							xml.LogDoc("WebDAVClient.Checkin: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  rootStr);
						info := "DAV:error = "; Strings.Append(info, rootStr);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
			ELSE
				log.Enter; log.String("WebDAVClient.Vcc.Checkin: unexpected Vcc.state"); log.Exit;
			END;
		END checkin;

		(** Checkout VCC itself and all members. NO subconfigurations. *)
		PROCEDURE checkout * (CONST remote: ARRAY OF CHAR);
		VAR
			resHeader: WebHTTP.ResponseHeader;
			out : Streams.Reader; rc: LONGINT;
			doc: XML.Document; root: XML.Element; info, rootStr: ARRAY 128 OF CHAR; elName: OdUtil.Line;
			all, unversioned, checkedin, checkedout: OdUtil.Lines;
		BEGIN
			VersionMembers(remote, all, unversioned, checkedin, checkedout);
			IF state = "checkedin" THEN
				IF checkedin = NIL THEN NEW(checkedin); END;
				checkedin.add(""); (* Checkout VCC. "" will be converted to VCC url. *)
			END;
			WHILE checkedin # NIL DO
				ShowMethodUrl(WebHTTP.CheckoutM, Url(remote, checkedin.line));
				client.Checkout(Url(remote, checkedin.line), resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						elName := xml.AbsXmlName(root.GetName());
						IF elName # "DAV:error" THEN
							xml.LogDoc("WebDAVClient.Checkout: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  rootStr);
						info := "DAV:error = "; Strings.Append(info, rootStr);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
				checkedin  := checkedin.next;
			END;
		END checkout;

		(** Checkout VCC itself and all members. NO subconfigurations. *)
		PROCEDURE uncheckout * (CONST remote: ARRAY OF CHAR);
		VAR
			reqHeader: WebHTTP.RequestHeader; resHeader: WebHTTP.ResponseHeader;
			out : Streams.Reader; rc: LONGINT;
			doc: XML.Document; root: XML.Element; info, rootStr: ARRAY 128 OF CHAR; elName: OdUtil.Line;
			all, unversioned, checkedin, checkedout: OdUtil.Lines;
		BEGIN
			VersionMembers(remote, all, unversioned, checkedin, checkedout);
			IF state = "checkedout" THEN
				IF checkedout = NIL THEN NEW(checkedout); END;
				checkedout.add(""); (* Checkout VCC. "" will be converted to VCC url. *)
			END;
			WHILE checkedout # NIL DO
				ShowMethodUrl(WebHTTP.UncheckoutM, Url(remote, checkedout.line));
				client.Uncheckout(Url(remote, checkedout.line), reqHeader, resHeader, out, rc);
				doc := client.XmlResult(resHeader, rc, out);
				IF doc # NIL THEN
					LOOP (*  *)
						root := doc.GetRoot();
						elName := xml.AbsXmlName(root.GetName());
						IF elName # "DAV:error" THEN
							xml.LogDoc("WebDAVClient.Uncheckout: Unexpected root element = ", doc);
							EXIT;
						END;
						OdXml.GetCharData(root,  rootStr);
						info := "DAV:error = "; Strings.Append(info, rootStr);
						log.Enter; log.String(info); log.Exit;
						EXIT;
					END;
				END;
				checkedout  := checkedout.next;
			END;
		END uncheckout;

	END Vcc;
TYPE
	Repos * = OBJECT (*POINTER TO RECORD*)
		VAR
		host*, path*: ARRAY 128 OF CHAR;

		PROCEDURE &Init*(CONST host, path: ARRAY OF CHAR);
		BEGIN COPY(host, SELF.host); COPY(path, SELF.path); END Init;

		(** Complete url with prefixed http:// and hostname. *)
		PROCEDURE expand * (VAR url: ARRAY OF CHAR);
		VAR url0: ARRAY 256 OF CHAR;
		BEGIN
			IF url[0] = '/' THEN
				 url0 := "http://"; Strings.Append(url0, host); Strings.Append(url0, url);
				 COPY(url0, url);
			END;
		END expand;
	END Repos;



TYPE
	OdClient* = OBJECT
	VAR
		repos*: Repos;

		basicAuth: ARRAY 64 OF CHAR;

		lw: MultiLogger.LogWindow;
		l: Streams.Writer;
		activity*: ARRAY 256 OF CHAR; (* Rember current activity created by Mkactivity() *)
		server*: ARRAY 32 OF CHAR; (* Special servers: svn, .... *)
		reqLocation*: ARRAY 256 OF CHAR;(* E.g. for CHECKOUT. *)

		xmlInCount: INTEGER;

		xml* : OdXml.OdXml;

		 con : TCP.Connection;

		 reconnect : BOOLEAN;

		 actualHost : ARRAY 256 OF CHAR;
		 actualPort : LONGINT;

		PROCEDURE &Init* ( x : OdXml.OdXml );
		BEGIN
			NEW(repos, "127.0.0.1", "/repos"); (* Default repository. *)

			con := NIL;
			xml := x;
			xmlInCount := 0;
			basicAuth := "";
			server := "";
			reqLocation := "";
			reconnect := FALSE;

			IF ShowDebugWindow THEN
				NEW(lw, "DCT Log", l);

				l.String("Started"); l.Ln; l.Update;
				log.SetLogWriter(l);
			END;

			log.SetLogToOut(FALSE);

		END Init;


		PROCEDURE ParseProps*(doc: XML.Document;  VAR propList: WebHTTP.AdditionalField);
		VAR
			root, response, prop, property, data: XML.Element;
			responses, props, datas: XMLObjects.Enumerator;
			p: ANY;
			s: XML.String;
			propertyName, dataName: OdUtil.Line;
			dataChars: ARRAY 256 OF CHAR; (* Change to str^ to avoid big array ? *)
		BEGIN
			root := doc.GetRoot();
			IF root # NIL THEN
				s := root.GetName();
				IF xml.EqualName(s, "DAV:multistatus") THEN
					xml.xmlns := NIL;
					xml.GetXmlns(root);
					responses := root.GetContents();
					WHILE responses.HasMoreElements() DO
						p := responses.GetNext();
						response :=  p(XML.Element);
						IF response # NIL THEN
							xml.GetXmlns(response);
							(*href := OdXml.FindElement(response, "DAV:href"); OdXml.GetCharData(href, nameData);*)
							prop := xml.SplitElement(response, "DAV:propstat.DAV:prop");
							IF prop = NIL THEN xml.LogDoc("XML element 'props' not found", doc); RETURN; END;
							props := prop.GetContents();
							WHILE props.HasMoreElements() DO
								p := props.GetNext();
								property :=  p(XML.Element);
								propertyName := xml.AbsXmlName(property.GetName());
								datas := property.GetContents(); (* Get enumerator. *)
								IF datas.HasMoreElements() THEN
									p := datas.GetNext();
									IF p IS XML.Element THEN
										data := p(XML.Element);
										dataName := xml.AbsXmlName(data.GetName());
										IF dataName = "DAV:href"  THEN
											OdXml.GetCharData(data, dataChars);
											WebHTTP.SetAdditionalFieldValue(propList, propertyName, dataChars);
										ELSE (* unexpected stuff *)
											OdXml.GetCharData(property, dataChars);
											WebHTTP.SetAdditionalFieldValue(propList, propertyName, dataName);
										END;
									ELSE (* assume it's character data. *)
										OdXml.GetCharData(property, dataChars);
										WebHTTP.SetAdditionalFieldValue(propList, propertyName, dataChars);
									END;
								END;
							END;
						END;
					END;
					(***
					list := propList;
					WHILE list # NIL DO
						OdUtil.Msg3(list .key, ": ", list.value);
						list := list.next;
					END;
					***)
				ELSE
					 xml.LogDoc("DAV:multistatus not found", doc);
				END
			ELSE
				log.Enter; log.String("DCT.Propfind: doc.root not found");  log.Exit;
			END
		END ParseProps;



		PROCEDURE XmlResult * (VAR resHeader: WebHTTP.ResponseHeader; res: LONGINT;
			out : Streams.Reader): XML.Document;
		CONST
			BufSize = 512; XmlInName = "XmlIn0.Log";
		VAR
			f: Files.File;
			scanner: OdXml.Scanner; parser: OdXml.Parser;
			doc: XML.Document;
			fr: Files.Reader; buf: ARRAY BufSize OF CHAR; read: LONGINT;
			xmlInName: ARRAY 16 OF CHAR;
		BEGIN
			(* Logfilename goes from XmlIn0.Log to XmlIn9.Log. *)
			xmlInName := XmlInName; xmlInName[5] := CHR(ORD('0')+xmlInCount); xmlInCount := (xmlInCount+1) MOD 10;
			(**) log.Enter; log.String("xmlInName = "); log.String(xmlInName); log.Exit; (**)
			(* Store to file and dechunk. *)
			StoreResult2File(resHeader, res, out, xmlInName, f);
			IF f # NIL THEN
				NEW(fr, f, 0);
				IF Strings.Pos("text/xml", resHeader.contenttype) > -1 THEN
					(** ) log.Enter; log.String("input in file"); log.Exit; ( **)
					NEW(scanner, fr); NEW(parser, scanner);
					doc := parser.Parse();
					(** ) log.Enter; log.String("parsed"); log.Exit; ( **)
					IF xml.showTree # NIL THEN
						xml.showTree(doc);
					END;
					RETURN doc;
				ELSE
					NEW(fr, f, 0);
					LOOP
						fr.Bytes(buf, 0, BufSize-1, read); buf[read] := 0X;
						IF fr.res # Streams.Ok THEN EXIT; log.Enter; log.String("EXIT res"); log.Exit; END;
						log.Enter; log.String(buf); log.Exit;
						IF read < BufSize-1 THEN EXIT; log.Enter; log.String("EXIT read"); log.Exit; END;
					END;
					RETURN NIL; (* No XML to parse *)
				END;
			ELSE
				log.Enter; log.String( "xml no content" ); log.Exit;
				RETURN NIL;
			END;
		END XmlResult;

		PROCEDURE SvnSetBasicAuth* ( pwd : ARRAY OF CHAR );
		VAR
			userPass64: ARRAY 64 OF CHAR;
		BEGIN
			IF pwd = "" THEN
				basicAuth := "";
			ELSE
				OdAuthBase.EncodeString(pwd, userPass64);
				basicAuth := "Basic ";
				Strings.Append(basicAuth, userPass64);
			END;
		END SvnSetBasicAuth;

		(** Basic authentication means a HTTP header string like:
			"Authorization: Basic " Base64(username ":" password)	*)
		PROCEDURE SetBasicAuth * ( context: Commands.Context );
		VAR userPass : ARRAY 64 OF CHAR;
		BEGIN
			IF context.arg.GetString( userPass ) THEN
				SvnSetBasicAuth ( userPass );
			ELSE
				basicAuth := "";
			END;
		END SetBasicAuth;

		(** Set client trace level to none(0), header(1), body(2) *)
		PROCEDURE SetTraceLevel * ( context: Commands.Context );
		VAR level: LONGINT;
		BEGIN
			IF context.arg.GetInteger( level, FALSE ) THEN
				CASE level OF
					0..2: traceLevel := level;
					ELSE log.String("WebDAVClient.SetTraceLevel (0|1|2)");
				END;
			ELSE
				log.Enter; log.String("WebDAVClient.SetTraceLevel (0|1|2) Current = "); log.Int(traceLevel, 1); log.Exit;
			END;
		END SetTraceLevel;

		(** Set non ObeDAV server. *)
		PROCEDURE SetServer * ( context: Commands.Context );
		VAR name: ARRAY 32 OF CHAR;
		BEGIN
			IF context.arg.GetString( name ) THEN
				COPY(name, server);
			ELSE
				log.Enter; log.String("WebDAVClient.SetServer (''|'svn') Current = '"); log.String(server); log.String("'"); log.Exit;
			END;
		END SetServer;

		PROCEDURE SetReqLocation * ( context: Commands.Context );
		VAR location: ARRAY 256 OF CHAR;
		BEGIN
			IF context.arg.GetString( location ) THEN
				COPY(location, reqLocation);
			ELSE
				log.Enter; log.String('WebDAVClient.SetReqLocation ("<location url>"|"")'); log.Exit;
			END;
		END SetReqLocation;

		PROCEDURE SetActivity * ( context: Commands.Context );
		VAR url: ARRAY 256 OF CHAR;
		BEGIN
			IF context.arg.GetString( url ) THEN
				COPY(url, activity);
			ELSE
				log.Enter; log.String('WebDAVClient.SetActivity ("<activity url>"|"")'); log.Exit;
			END;
		END SetActivity;


		PROCEDURE GetRepos* () : Repos;
		BEGIN
			RETURN repos;
		END GetRepos;

		PROCEDURE SvnSetRepos * ( CONST url : ARRAY OF CHAR );
		VAR
			port: LONGINT;
			s : ARRAY 6 OF CHAR;
		BEGIN
			IF ~WebHTTP.SplitHTTPAdr (url, repos.host, repos.path, port) THEN
				log.Enter; log.String("WebDAVClient.SetRepos: error.");  log.Exit;
			ELSE
				IF (port # 0) & (port # 80) THEN
					Strings.Append ( repos.host, ":" );
					Strings.IntToStr ( port, s );
					Strings.Append ( repos.host, s );
				END;
				log.Enter; log.String("WebDAVClient.repos.host="); log.String(repos.host);
				log.String(",path="); log.String(repos.path);  log.Exit;
			END;
		END SvnSetRepos;

		PROCEDURE SetRepos * ( context: Commands.Context );
		VAR url: ARRAY 256 OF CHAR;

		BEGIN
			IF ~context.arg.GetString( url ) THEN
				log.Enter; log.String( "OdClient.SetRepos <repos url> ~" ); log.Exit;
			ELSE
				SvnSetRepos ( url );
			END;
		END SetRepos;


		PROCEDURE OpenConnection ( CONST url : ARRAY OF CHAR; VAR host, path : ARRAY OF CHAR; VAR port : LONGINT; VAR res : LONGINT ) : BOOLEAN;
		VAR
			fadr : IP.Adr;
		BEGIN
			IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
				IF path = "" THEN path := "/" END;

				IF (con = NIL) OR (con.State() # TCP.Established) OR reconnect OR (actualHost # host) OR (actualPort # port) THEN
					COPY ( host, actualHost );
					actualPort := port;
					NEW(con);
					DNS.HostByName(host, fadr, res);
					IF res = DNS.Ok THEN
						con.KeepAlive(TRUE);
						con.Open(TCP.NilPort, fadr, port, res);
						IF res = TCP.Ok THEN
							reconnect := FALSE;
							RETURN TRUE;
						ELSE
							res := ResCOULDNOTCONNECT;
							log.Enter; log.String ( "Could not connect to "); log.String(host); log.Exit;
						END;
					ELSE
						res := ResHOSTNOTFOUND;
						log.Enter; log.String("Host ");  log.String(host); log.String(" not found : ");log.Exit;
					END;
				ELSE
					RETURN TRUE;
				END;
			END;

			RETURN FALSE;
		END OpenConnection;

		PROCEDURE CloseConnection*;
		BEGIN
			IF con # NIL THEN con.Discard END;
		END CloseConnection;

		(** Generic routine to connect to a server and wait for reply. *)
		PROCEDURE Net(CONST url : ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; xmlReq: XML.Document; VAR out : Streams.Reader; VAR res : LONGINT);
		CONST
			StringWriterSize = 10000;
		VAR
			host : ARRAY 128 OF CHAR; path : ARRAY 256 OF CHAR; xmlSize, port : LONGINT;
			w, aosioWriter : Streams.Writer; x : WebHTTP.AdditionalField;
			buf: ARRAY StringWriterSize OF CHAR; stringWriter: Streams.StringWriter;
		BEGIN
			reqHeader.useragent := UserAgent;
			(* Cleanup responseHeader in case it's reused *)
			resHeader.transferencoding := "";
			resHeader.contentlocation := "";
			resHeader.contenttype := "";
			resHeader.contentlength := -1;
			resHeader.additionalFields := NIL;


			IF OpenConnection ( url, host, path, port, res ) THEN
						IF basicAuth # "" THEN
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Authorization", basicAuth);
						END;
						IF xmlReq # NIL THEN
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Type", 'text/xml; charset="UTF-8"');
							xmlSize := xml.XmlSize(xmlReq); Strings.IntToStr(xmlSize, buf);
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", buf);
						ELSE
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Content-Length", "0");
						END;
						WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Connection", "Keep-Alive");
						(* 				build request 						*)
						NEW(w, con.Send, 1024);
						NEW(out, con.Receive, 1024);
						WebHTTP.WriteRequestLine(w, 1, 1, reqHeader.method, path, host);
						IF reqHeader.referer # "" THEN w.String("Referer: "); w.String(reqHeader.referer); w.Ln END;
						IF reqHeader.useragent # "" THEN w.String("User-Agent: "); w.String(reqHeader.useragent); w.Ln END;
						IF reqHeader.accept # "" THEN w.String("Accept: "); w.String(reqHeader.accept); w.Ln END;
						IF traceLevel >= TlHeader THEN log.Enter; log.String("Host: "); log.String(host); log.Exit; END;
						x := reqHeader.additionalFields;
						WHILE x # NIL DO
							w.String(x.key); w.String(": "); w.String(x.value); w.Ln;
							IF traceLevel >= TlHeader THEN log.Enter; log.String(x.key); log.String(": "); log.String(x.value); log.Exit; END;
							x := x.next
						END;
						w.Ln;	(* mark end of header with empty line *)
						IF xmlReq # NIL THEN (* send request body. *)
							xmlReq.Write(w, NIL, 0);
							IF traceLevel >= TlBody THEN
								IF xmlSize < StringWriterSize THEN
									NEW(stringWriter, StringWriterSize);
									aosioWriter := stringWriter; (* Dummy for the compiler. Is compiler correct ? *)
									xmlReq.Write(aosioWriter, NIL, 0);
									stringWriter.Get(buf);
									log.Enter; log.String(buf); log.Exit;
								ELSE
									log.Enter; log.String("WebDAVClient:Net StringWriterSize too small. Required:"); log.Int(xmlSize,5); log.Exit;
								END;
							END;
						END;
						(*w.Char(0X);*) (* Give XML Scanner an EOF *)
						w.Update;
						(* 				receive reply 						*)
						ParseReply ( out, resHeader, res );
						IF traceLevel >= TlHeader THEN
							WebHTTP.LogResponseHeader(log, resHeader); END;
			END;
		END Net;


		PROCEDURE ParseReply ( out : Streams.Reader; VAR resHeader: WebHTTP.ResponseHeader; VAR res : LONGINT );
		VAR
			state : ARRAY 50 OF CHAR;
		BEGIN
			WebHTTP.ParseReply(out, resHeader, res, log);
			IF res = WebHTTP.OK THEN res := Ok END;

			state := "";

			IF WebHTTP.GetAdditionalFieldValue ( resHeader.additionalFields, "Connection", state ) THEN
			ELSIF WebHTTP.GetAdditionalFieldValue ( resHeader.additionalFields, "Proxy-Connection", state ) THEN
			END;

			IF state = "close" THEN
				reconnect := TRUE;
			END;
		END ParseReply;

		PROCEDURE BaselineControlFreeze * (CONST url: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		BEGIN (* localServer.freezeInitialConfiguration(conf, log, flags); *)
			reqHeader.method := WebHTTP.BaselineControlM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END BaselineControlFreeze;

		PROCEDURE BaselineControlSelect * (CONST url, baseline: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			 VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqBody: OdXml.BaselineControlReq;
			host : ARRAY 128 OF CHAR; path : ARRAY 256 OF CHAR; port : LONGINT;
		BEGIN
			IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
				reqHeader.method := WebHTTP.BaselineControlM;
				(* TODO: Check whether baseline should have a different format. *)
				NEW(reqBody, host, baseline); (* Assume repository is on the same host. *)
				Net(url, reqHeader, resHeader, reqBody, out, res);
			END;
		END BaselineControlSelect;


		PROCEDURE Head*(CONST url : ARRAY OF CHAR; VAR resHeader: WebHTTP.ResponseHeader; VAR res : LONGINT);
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer;
			r : Streams.Reader;
		BEGIN
			IF OpenConnection ( url, host, path, port, res ) THEN

						NEW(w, con.Send, 4096);
						NEW(r, con.Receive, 4096);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.HeadM, path, host);
						IF basicAuth # "" THEN
							w.String('Authorization: '); w.String(basicAuth); w.Ln;
						END;
						w.Ln; w.Update;

						ParseReply ( r, resHeader, res );
						con.Close;
						con := NIL;

			END;
		END Head;



		(** The HTTP versions is ignored and set to 1.1; uri and host are ignored and taken from the url parameter.
		< GET /work/Test.html HTTP/1.1
		?< Host: ketchup.ethz.ch
		?< Content-Length: 0
		?>HTTP/1.1 200 OK
		*)
		PROCEDURE Get*(CONST url : ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer;
			x : WebHTTP.AdditionalField;
		BEGIN
			IF OpenConnection ( url, host, path, port, res ) THEN

						IF basicAuth # "" THEN
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Authorization", basicAuth);
						END;
						WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Connection", "Keep-Alive");
						NEW(w, con.Send, 4096);
						NEW(out, con.Receive, 4096);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.GetM, path, host);
						IF reqHeader.referer # "" THEN w.String("Referer: "); w.String(reqHeader.referer); w.Ln END;
						IF reqHeader.useragent # "" THEN w.String("User-Agent: "); w.String(reqHeader.useragent); w.Ln END;
						IF reqHeader.accept # "" THEN w.String("Accept: "); w.String(reqHeader.accept); w.Ln END;
						x := reqHeader.additionalFields;
						WHILE x # NIL DO
							w.String(x.key);  w.String(": "); w.String(x.value); w.Ln;
							x := x.next
						END;
						w.Ln; w.Update;

						ParseReply ( out, resHeader, res );

			END
		END Get;

		(** The HTTP versions is ignored and set to 1.1; uri and host are ignored and taken from the url parameter *)
		PROCEDURE Put*(CONST url : ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; in : Streams.Reader; VAR res : LONGINT);
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer; (* to connection *)
			x : WebHTTP.AdditionalField;
		BEGIN

			IF OpenConnection ( url, host, path, port, res ) THEN

						IF basicAuth # "" THEN
							WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Authorization", basicAuth);
						END;
						WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Connection", "Keep-Alive");
						NEW(w, con.Send, 1280);
						NEW(out, con.Receive, 1280);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.PutM, path, host);
						IF reqHeader.referer      # "" THEN w.String("Referer: "); w.String(reqHeader.referer); w.Ln END;
						IF reqHeader.useragent # "" THEN w.String("User-Agent: "); w.String(reqHeader.useragent); w.Ln END;
						IF reqHeader.accept # "" THEN w.String("Accept: "); w.String(reqHeader.accept); w.Ln END;
						x := reqHeader.additionalFields;
						WHILE x # NIL DO
							w.String(x.key);  w.String(": "); w.String(x.value); w.Ln();
							x := x.next
						END;
						w.Ln;
						SendData(in, w); (* Send file data *)
						w.Update();

						ParseReply ( out, resHeader, res );

			END
		END Put;

		(**
		< VERSION-CONTROL /work/Test.html HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: 0
		>HTTP/1.1 200 OK
		*)
		PROCEDURE VersionControlFreeze*(CONST url: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		BEGIN
			reqHeader.method := WebHTTP.VersionControlM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END VersionControlFreeze;

		PROCEDURE VersionControlSelect*(CONST url, ver: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		CONST PLog = FALSE;
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer;
			xmlDoc: XML.Document;
			(* For bodytracing. TODO: Update should be converted to Net(). *)
			CONST StringWriterSize = 10000;
			VAR xmlSize: LONGINT; buf: ARRAY StringWriterSize OF CHAR; stringWriter: Streams.StringWriter;
			aosioWriter : Streams.Writer;
		BEGIN
			xmlSize := 0;

			IF OpenConnection ( url, host, path, port, res ) THEN

				xmlDoc := xml.SelectReq("version-control", host, ver);
				IF PLog THEN OdUtil.Msg3("WebDAVClient.VersionControlSelect", url, ver); END;

						NEW(w, con.Send, 4096);
						NEW(out, con.Receive, 4096);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.VersionControlM, path, host);
						IF basicAuth # "" THEN
							w.String('Authorization: '); w.String(basicAuth); w.Ln;
						END;
						w.String('Content-Type: text/xml; charset="utf-8"'); w.Ln;
						w.String("Content-Length: "); w.Int(xml.XmlSize(xmlDoc), 1); w.Ln;
						w.Ln();
						xmlDoc.Write(w, NIL, 0); (* Send XML body *)
						IF traceLevel >= TlBody THEN
							IF xmlSize < StringWriterSize THEN
								NEW(stringWriter, StringWriterSize);
								aosioWriter := stringWriter; (* Dummy for the compiler. Is compiler correct ? *)
								xmlDoc.Write(aosioWriter, NIL, 0);
								stringWriter.Get(buf);
								log.Enter; log.String(buf); log.Exit;
							ELSE
								log.Enter; log.String("WebDAVClient:Net StringWriterSize too small. Required:"); log.Int(xmlSize,5); log.Exit;
							END;
						END;
						w.Char(0X); (* Give XML Scanner an EOF *)
						w.Update();

						ParseReply ( out, resHeader, res );

			END
		END VersionControlSelect;

		(**
		< CHECKOUT /work/Test.html HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: xxx
		<?xml version="1.0" encoding="utf-8" ?>
		<D:checkout xmlns:D="DAV:">
			<D:activity-set>
				<D:href>http://repo.webdav.org/act/fix-bug-23</D:href>
			</D:activity-set>
		</D:checkout>
		>HTTP/1.1 200 OK
		*)
		PROCEDURE Checkout*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
			coReq: OdXml.CheckoutReq;
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
		BEGIN
			IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
				reqHeader.method := WebHTTP.CheckoutM;
				IF server = "svn" THEN
					IF reqLocation # "" THEN
						WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Location", reqLocation);
					END;
					NEW(coReq, host, activity);
				ELSE
					coReq := NIL;
				END;
				Net(url, reqHeader, resHeader, coReq, out, res);
			ELSE
				log.Enter; log.String("Checkout host not found : "); log.String(host); log.Exit
			END;
		END Checkout;

		(**
		< MERGE /work/Test.html HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: xxx
		<?xml version="1.0" encoding="utf-8" ?>
		<D:merge xmlns:D="DAV:">
			<D:source>
				<D:href>http://repo.webdav.org/wrk/svn1</D:href>
			</D:source>
		</D:merge>
		>HTTP/1.1 200 OK
		*)
		PROCEDURE Merge*(CONST url, source: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
			mergeReq: OdXml.MergeSvnReq;
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
		BEGIN
			IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
				reqHeader.method := WebHTTP.MergeM;
				NEW(mergeReq, "D:merge", "D:source", "D:href", source);
				Net(url, reqHeader, resHeader, mergeReq, out, res);
			ELSE
				log.Enter; log.String("Merge host not found : "); log.String(host); log.Exit
			END;
		END Merge;

		(**
		< UNCHECKOUT /work/Test.html HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: 0
		>HTTP/1.1 200 OK
		*)
		PROCEDURE Uncheckout*(CONST url : ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer;
		BEGIN
			IF OpenConnection ( url, host, path, port, res ) THEN

						NEW(w, con.Send, 512);
						NEW(out, con.Receive, 512);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.UncheckoutM, path, host);
						IF basicAuth # "" THEN
							w.String('Authorization: '); w.String(basicAuth); w.Ln;
						END;
						w.Ln();
						w.Char(0X); (* Give XML Scanner an EOF *)
						w.Update();

						ParseReply ( out, resHeader, res );

			END
		END Uncheckout;

		PROCEDURE Report1*(CONST type: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer; (* to connection *)
			xmlDoc: XML.Document;
			s: ARRAY 128 OF CHAR; ok: BOOLEAN;
		BEGIN
			IF type = "version-tree" THEN
				xmlDoc := xml.VersionTreeReq();
			ELSIF type = "compare-baseline" THEN
				ok := WebHTTP.GetAdditionalFieldValue (reqHeader.additionalFields, "compareBaseline", s);
				xmlDoc := xml.Href1Req("compare-baseline", s);
			ELSE
				log.Enter; log.String("Unexpected report type : "); log.String(type); log.Exit;
				RETURN;
			END;

			IF OpenConnection ( reqHeader.uri, host, path, port, res ) THEN

						NEW(w, con.Send, 1280);
						NEW(out, con.Receive, 1280);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.ReportM, path, host);
						IF basicAuth # "" THEN
							w.String('Authorization: '); w.String(basicAuth); w.Ln;
						END;
						IF reqHeader.referer      # "" THEN w.String("Referer: "); w.String(reqHeader.referer); w.Ln END;
						IF reqHeader.useragent # "" THEN w.String("User-Agent: "); w.String(reqHeader.useragent); w.Ln END;
						w.String('Content-Type: text/xml; charset="utf-8"'); w.Ln;
						w.String("Content-Length: "); w.Int(xml.XmlSize(xmlDoc), 1); w.Ln;
						w.Ln;
						xmlDoc.Write(w, NIL, 0); (* Send XML body *)
						w.Char(0X); (* Give XML Scanner an EOF *)
						w.Update();

						ParseReply ( out, resHeader, res );

			END;
			log.Enter; log.String( "" ); log.Exit;
		END Report1;

		(* Already get the request XML doc as a parameter. *)
		PROCEDURE Report*(CONST url, depth: ARRAY OF CHAR; reqBody: XML.Document;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			reqHeader.method := WebHTTP.ReportM;
			IF depth # "" THEN
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Depth", depth);
			END;
			Net(url, reqHeader, resHeader, reqBody, out, res);
		END Report;

		PROCEDURE Propfind*(CONST url, depth: ARRAY OF CHAR; props: WebHTTP.AdditionalField;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader; xmlDoc: XML.Document;
		BEGIN
			reqHeader.method := WebHTTP.PropfindM;
			IF depth # "" THEN
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Depth", depth);
			END;
			IF props # NIL THEN
				xmlDoc := xml.PropfindReq(props);
			ELSE
				xmlDoc := NIL; (* Without body allprop. *)
			END;
			Net(url, reqHeader, resHeader, xmlDoc, out, res);
		END Propfind;


		(* Properties are gives as a list of lines: 1{ name 1{value} } . mode = "set" | "add" *)
		PROCEDURE Proppatch*(CONST url, mode : ARRAY OF CHAR; props: WebHTTP.AdditionalField;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader; xmlDoc: XML.Document;
		BEGIN
			reqHeader.method := WebHTTP.ProppatchM;
			xmlDoc := xml.ProppatchReq(mode, props);
			Net(url, reqHeader, resHeader, xmlDoc, out, res);
		END Proppatch;

		PROCEDURE Checkin*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			reqHeader.method := WebHTTP.CheckinM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END Checkin;

		(** MOVE  RFC2518, 8.9
		>>Request
		MOVE /test/old HTTP/1.1
		Host: webdav.ethz.ch
		Destination: http://webdav.ethz.ch//test/new
		>>Response
		HTTP/1.1 201 Created
		Location: http://webdav.ethz.ch//test/new
		*)
		PROCEDURE Move*(CONST url, destUrl: ARRAY OF CHAR; overwrite: BOOLEAN;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader; xmlDoc: XML.Document;
		BEGIN
			xmlDoc := NIL;
			reqHeader.method := WebHTTP.MoveM;
			WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Destination", destUrl);
			IF ~overwrite THEN (* Default TRUE *)
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Overwrite", "F");
			END;
			Net(url, reqHeader, resHeader, xmlDoc, out, res);
		END Move;

		PROCEDURE Copy*(CONST url, destUrl : ARRAY OF CHAR; overwrite: BOOLEAN;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader; xmlDoc: XML.Document;
		BEGIN
			xmlDoc := NIL;
			reqHeader.method := WebHTTP.CopyM;
			WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Destination", destUrl);
			IF ~overwrite THEN (* Default TRUE *)
				WebHTTP.SetAdditionalFieldValue(reqHeader.additionalFields, "Overwrite", "F");
			END;
			Net(url, reqHeader, resHeader, xmlDoc, out, res);
		END Copy;

		PROCEDURE Delete*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			reqHeader.method := WebHTTP.DeleteM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END Delete;

		(** Make collection.
		< MKCOL /work/Test.html HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: 0
		?>HTTP/1.1 200 OK *)
		PROCEDURE Mkcol*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			reqHeader.method := WebHTTP.MkcolM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END Mkcol;

		(** Make activity. Implemented for subversion. Is just funny URI.
		Remember for later deletion after transaction is finished.
		< MKACTIVITY /repos/!svn/act/1 HTTP/1.1
		< Host: ketchup.ethz.ch
		< Content-Length: 0
		?>HTTP/1.1 200 OK *)
		PROCEDURE Mkactivity*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			COPY(url, activity);
			reqHeader.method := WebHTTP.MkactivityM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END Mkactivity;

		(** Options request to learn about a new server. Example cadaver:   *)
		PROCEDURE Options*(CONST url: ARRAY OF CHAR;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		VAR
			reqHeader : WebHTTP.RequestHeader;
		BEGIN
			reqHeader.method := WebHTTP.OptionsM;
			Net(url, reqHeader, resHeader, NIL, out, res);
		END Options;

		(* Version can be a number. Then it's just a version number of VCSBase and is sent as <host>/version.<version>.
			Or it's a version url string. For VCSBase it must have the form /hist/<version history>.<version number> *)
		PROCEDURE Update*(CONST url, version: ARRAY OF CHAR; VAR reqHeader : WebHTTP.RequestHeader;
			VAR resHeader: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
		CONST PLog = FALSE;
		VAR
			host : ARRAY 128 OF CHAR;
			path : ARRAY 256 OF CHAR;
			port : LONGINT;
			w : Streams.Writer; (* to connection *)
			xmlDoc: XML.Document;
			(* For bodytracing. TODO: Update should be converted to Net(). *)
			CONST StringWriterSize = 10000;
			VAR xmlSize: LONGINT; buf: ARRAY StringWriterSize OF CHAR; stringWriter: Streams.StringWriter;
			aosioWriter : Streams.Writer;
		BEGIN
			xmlSize := 0;

			IF OpenConnection ( url, host, path, port, res ) THEN

				IF PLog THEN OdUtil.Msg3("WebDAVClient.Update", url, version); END;
				xmlDoc := xml.UpdateReq(host, version);

						NEW(w, con.Send, 1280);
						NEW(out, con.Receive, 1280);
						WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.UpdateM, path, host);
						IF basicAuth # "" THEN
							w.String('Authorization: '); w.String(basicAuth); w.Ln;
						END;
						IF reqHeader.referer      # "" THEN w.String("Referer: "); w.String(reqHeader.referer); w.Ln END;
						IF reqHeader.useragent # "" THEN w.String("User-Agent: "); w.String(reqHeader.useragent); w.Ln END;
						IF xmlDoc # NIL THEN
							w.String('Content-Type: text/xml; charset="utf-8"'); w.Ln;
							w.String("Content-Length: "); w.Int(xml.XmlSize(xmlDoc), 1); w.Ln;
							w.Ln;
							xmlDoc.Write(w, NIL, 0); (* Send XML body *)
							IF traceLevel >= TlBody THEN
								IF xmlSize < StringWriterSize THEN
									NEW(stringWriter, StringWriterSize);
									aosioWriter := stringWriter; (* Dummy for the compiler. Is compiler correct ? *)
									xmlDoc.Write(aosioWriter, NIL, 0);
									stringWriter.Get(buf);
									log.Enter; log.String(buf); log.Exit;
								ELSE
									log.Enter; log.String("WebDAVClient:Net StringWriterSize too small. Required:"); log.Int(xmlSize,5); log.Exit;
								END;
							END;
						END;
						w.Char(0X);
						w.Update(); (* Give XML Scanner an EOF *)

						ParseReply ( out, resHeader, res );

			END
		END Update;



	END OdClient;






(* (es) Goodie for short log string statements *)
PROCEDURE ls(CONST prompt, string: ARRAY OF CHAR);
BEGIN
	log.Enter; log.String(prompt); log.String(string); log.Exit;
END ls;
PROCEDURE li(CONST prompt: ARRAY OF CHAR; i: LONGINT);
BEGIN
	log.Enter; log.String(prompt); log.Int(i,1); log.Exit;
END li;



(** Sends all availabe data from src to dst. Goodie copied from WebHTTPServer *)
PROCEDURE SendData*(src: Streams.Reader; dst: Streams.Writer);
CONST Log = TRUE;
	BufSize = 512; (* Smaller than PPP Payload. *)
VAR len: LONGINT; buf: ARRAY BufSize OF CHAR;
	sent: LONGINT; timer: Kernel.Timer;
BEGIN
	NEW(timer);
	IF Log THEN log.Enter; log.String("SendData "); log.TimeStamp(); log.Exit; END;
	sent := 0;
	WHILE (src.res = Streams.Ok) DO
		src.Bytes(buf, 0, BufSize, len);
		dst.Bytes(buf, 0, len); dst.Update;
		sent := sent + len;
		(*timer.Sleep(300);*) (* wtf *)
	END;
	IF Log THEN li("SendData ", sent); END;
END SendData;






PROCEDURE Terminate;
BEGIN
	log.Close;
	(*lw.Close;*)
END Terminate;

(***  Some utility functions for connecting used in Vcc ***)

PROCEDURE ShowMethodUrl * (method: LONGINT; CONST url: ARRAY OF CHAR);
VAR line: ARRAY 256 OF CHAR;
BEGIN
	WebHTTP.GetMethodName(method, line); Strings.Append(line, " "); Strings.Append(line, url);
	log.Enter; log.String(line); log.Exit;
END ShowMethodUrl;

PROCEDURE ShowStatus * (VAR res: WebHTTP.ResponseHeader);
VAR
	realm: ARRAY 64 OF CHAR;
BEGIN
	log.Enter; log.String("HTTP/1.1 "); log.Int(res.statuscode, 4); log.Exit;
	IF res.statuscode = WebHTTP.Unauthorized THEN
		IF WebHTTP.GetAdditionalFieldValue (res.additionalFields, "WWW-Authenticate", realm) THEN
			log.Enter; log.String("Authorization required: "); log.String(realm); log.Exit;
		END;
	END;
END ShowStatus;

PROCEDURE StoreResult2File * (VAR resHeader: WebHTTP.ResponseHeader; res: LONGINT;
	out : Streams.Reader; CONST target: ARRAY OF CHAR; VAR f: Files.File);
CONST
	BufSize = 512;
VAR read : LONGINT;
	timer: Kernel.Timer; slept: LONGINT;
	r: Files.Rider;
	buf : ARRAY BufSize OF CHAR;
	dechunk: WebHTTP.ChunkedInStream; sequential: Streams.Reader;
	chunkSize, remain: LONGINT; token: ARRAY 16 OF CHAR;
BEGIN
	f := NIL;
	IF res = Ok THEN
		ShowStatus(resHeader);
		NEW(timer); slept := 0; read := 0;
		log.Enter; log.String( resHeader.transferencoding ); log.Ln; log.Exit;
		IF (Strings.Pos("hunked", resHeader.transferencoding) > 0) THEN
			(** ) log.Enter; log.String("Chunking"); log.Exit; ( **)
			NEW(dechunk, out, sequential);
			f := Files.New(target);
			f.Set(r, 0);
			remain := 0;
			LOOP
				IF remain = 0 THEN (* Read the chunk size *)
					out.SkipWhitespace();  out.Token(token); out.SkipLn();
					(* log.Enter; AosOut.Memory(ADDRESSOF(token), 16); log.Exit; *)
					Strings.HexStrToInt(token, chunkSize, res);
					(*log.Enter; log.String(token); log.String(":token,size:"); AosOut.Int(chunkSize, 5); log.Exit;*)
					IF chunkSize = 0 THEN
						(* log.Enter; log.String("EXIT chunkSize =  0"); log.Exit; *)
						EXIT;
					END;
					remain := chunkSize;
				END;
				IF remain > BufSize THEN read := BufSize; ELSE read := remain; END;
				out.Bytes (buf, 0, read, read);
				IF out.res #  Streams.Ok THEN
					log.Enter; log.String("EXIT out.res"); log.Exit;
					EXIT;
				END;
				DEC(remain, read);
				(* log.Enter; AosOut.Int(read, 5); log.Exit; *)
				f.WriteBytes(r, buf, 0, read);
			END;
			IF target # "" THEN Files.Register(f); END;
		ELSIF resHeader.contentlength >= 0 THEN
			log.Enter; log.String("resHJeader.contentlength = ");log.Int(resHeader.contentlength,1); log.Exit;
			f := Files.New(target);
			f.Set(r, 0);
			remain := resHeader.contentlength;
			WHILE remain > 0 DO
				IF remain > BufSize THEN read := BufSize; ELSE read := remain; END;
				out.Bytes ( buf, 0, read, read );
				IF out.res #  Streams.Ok THEN
					remain := 0;
					log.Enter; log.String("EXIT out.res"); log.Exit;
				ELSE
					DEC ( remain, read );
					f.WriteBytes(r, buf, 0, read);
				END;
			END;

			IF target # "" THEN Files.Register(f); END;
		ELSE
			(* try to read something; due to some bug or missing content-length *)
			f := Files.New(target);
			f.Set(r, 0);
			LOOP
				out.Bytes ( buf, 0, BufSize, read );
				IF out.res #  Streams.Ok THEN
					log.Enter; log.String("EXIT out.res"); log.Exit;
					EXIT;
				END;
				f.WriteBytes(r, buf, 0, read);
			END;
			IF target # "" THEN Files.Register(f); END;
			log.Enter; log.String( "resHeader.contentlength < 0" ); log.Ln; log.Exit;
		END;
	ELSE
		log.Enter; log.String( "StoreResult2File: res not ok." ); log.Ln; log.Exit;
	END;
END StoreResult2File;



BEGIN
	traceLevel := TlBody;
	NEW(log, "HTTP Client");

	OdUtil.MsgLog := log;
	Modules.InstallTermHandler(Terminate)
END OdClient.
