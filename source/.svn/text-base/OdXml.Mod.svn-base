MODULE OdXml; (* System.Free DAVXml ~ DAVXml.Do   DAVXml.File   System.OpenKernelLog *)
(* Create XML structures for DeltaV methods. *)
IMPORT XML, XMLObjects, Streams, Files,
	XMLScanner, XMLParser, Strings, WebHTTP, OdUtil, KernelLog;

CONST
	UpdateVersionTag * = "/version."; (* for allowing to send just a version number with DCT.Update. *)

(***********************************************************************************)
(*                                                                      TYPE                                                                                    *)
(***********************************************************************************)
TYPE
(* Take string and split it in segments delimited by a tag character. *)
StringSplitter* =OBJECT
	VAR s: POINTER TO ARRAY OF CHAR; pos: LONGINT; done: BOOLEAN;
	PROCEDURE &Init*(CONST s: ARRAY OF CHAR);
	BEGIN
		IF s = "" THEN
			done := TRUE; (* In case of caller not testing for empty string. *)
		ELSE
			NEW(SELF.s, Strings.Length(s)+1); COPY(s, SELF.s^); pos := 0; done := FALSE;
		END;
	END Init;
	PROCEDURE Next*(tag: CHAR; VAR segment: ARRAY OF CHAR): BOOLEAN;
	VAR start: LONGINT;
	BEGIN
		IF done THEN segment[0] := 0X; RETURN FALSE; END;
		start := pos;
		LOOP
			IF s[pos] = 0X THEN segment[pos-start] := 0X; done := TRUE; RETURN TRUE;
			ELSIF s[pos] = tag THEN segment[pos-start] := 0X; INC(pos); RETURN TRUE;
			ELSE segment[pos-start] := s[pos]; INC(pos); END;
		END;
	END Next;
END StringSplitter;

(** NEW(doc, "D:merge", "D:source", "D:href", "http://svn.edgarschwarz.de/.....") *)
Attr3Val1Req* =OBJECT(XML.Document);
	PROCEDURE &InitA3V1*(CONST a1, a2, a3, v1: ARRAY OF CHAR); (* http://<host>/>url> *)
	VAR el1, el2, el3: XML.Element; ac1: XML.ArrayChars;
	BEGIN Init();
		SELF.AddContent(xmlDecl);
		NEW(el1); el1.SetName(a1); el1.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(el1);
		NEW(el2); el2.SetName(a2); el1.AddContent(el2);
		NEW(el3); el3.SetName(a3); el2.AddContent(el3);
		NEW(ac1); ac1.SetStr(v1); el3.AddContent(ac1);
	END InitA3V1;
END Attr3Val1Req;

(** NEW(doc, "D:merge", "D:source", "D:href", "http://svn.edgarschwarz.de/.....") *)
MergeSvnReq* =OBJECT(XML.Document);
	PROCEDURE &InitMergeSvnReq*(CONST a1, a2, a3, v1: ARRAY OF CHAR); (* http://<host>/>url> *)
	VAR el1, el2, el3: XML.Element; ac1: XML.ArrayChars;
	BEGIN Init();
		SELF.AddContent(xmlDecl);
		NEW(el1); el1.SetName(a1); el1.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(el1);
		NEW(el2); el2.SetName(a2); el1.AddContent(el2);
		NEW(el3); el3.SetName(a3); el2.AddContent(el3);
		NEW(ac1); ac1.SetStr(v1); el3.AddContent(ac1);
		(* more stuff *)
		NEW(el2); el2.SetName("D:no-auto-merge"); el1.AddContent(el2);
		NEW(el2); el2.SetName("D:no-checkout"); el1.AddContent(el2);
		NEW(el2); el2.SetName("D:prop"); el1.AddContent(el2);
		NEW(el3); el3.SetName("D:checked-in"); el2.AddContent(el3);
		NEW(el3); el3.SetName("D:version-name"); el2.AddContent(el3);
		NEW(el3); el3.SetName("D:resourcety"); el2.AddContent(el3);
		NEW(el3); el3.SetName("D:creationdate"); el2.AddContent(el3);
		NEW(el3); el3.SetName("D:creator-displayname"); el2.AddContent(el3);
	END InitMergeSvnReq;
END MergeSvnReq;

(* XML request and response objects *)
ErrorRes* =OBJECT(XML.Document);
	PROCEDURE &Init1*(CONST error: ARRAY OF CHAR);
	VAR err : XML.Element;
	BEGIN Init();
		SELF.AddContent(xmlDecl);
		NEW(err); err.SetName("D:error"); err.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(err);
		err.AddContent(NameContent(error));
	END Init1;
END ErrorRes;

BaselineControlReq* =OBJECT(XML.Document);
	PROCEDURE &Init1*(CONST host, baseline: ARRAY OF CHAR);
	VAR bc, b, h: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
	BEGIN Init();
		SELF.AddContent(xmlDecl);
		(* baseline-control *)
		NEW(bc); bc.SetName("D:baseline-control"); bc.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(bc);
		(* baseline-control.baseline *)
		NEW(b); b.SetName("D:baseline"); bc.AddContent(b);
		(* baseline-control.baseline.href *)
		NEW(h); h.SetName("D:href"); b.AddContent(h);
		acStr := "http://"; Strings.Append(acStr, host); Strings.Append(acStr, baseline);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
	END Init1;
END BaselineControlReq;

(* Baseline URL is given in request header. *)
BaselineReportReq* =OBJECT(XML.Document);
	PROCEDURE &Init*;
	VAR br: XML.Element;
	BEGIN Init^();
		SELF.AddContent(xmlDecl);
		(* baseline-report *)
		NEW(br); br.SetName("D:baseline-report"); br.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(br);
	END Init;
END BaselineReportReq;
(* configuration-report response. Modeled after version-tree.  *)
ConfigurationReportRes* =OBJECT(XML.Document);
	VAR conf: ARRAY 128 OF CHAR;
		hostPrefix: ARRAY 64 OF CHAR;
	PROCEDURE &Init1*(CONST hostName, conf: ARRAY OF CHAR);
	VAR ms: XML.Element;
	BEGIN (*Init^(); *) Init(); (*???*)
		hostPrefix := "http://"; Strings.Append(hostPrefix, hostName);
		COPY(conf, SELF.conf); SELF.AddContent(xmlDecl);
		NEW(ms); ms.SetName("D:multistatus"); ms.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(ms);
	END Init1;
	(* Info on VCR together with it's current state. *)
	PROCEDURE addVcrState*(CONST host: ARRAY OF CHAR; VAR ms: XML.Element; CONST res, hist : ARRAY OF CHAR; VAR state: ARRAY OF CHAR);
	VAR r, h, ps, v, vs, s: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR;
	BEGIN
		NEW(r); r.SetName("D:response"); ms.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		COPY(hostPrefix, acStr); Strings.Append(acStr, conf); Strings.Append(acStr, '/'); Strings.Append(acStr, res);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.version *)
		NEW(v); v.SetName("D:version"); ps.AddContent(v);
		acStr := "http://"; Strings.Append(acStr, host); Strings.Append(acStr, hist);
		NEW(ac); ac.SetStr(acStr); v.AddContent(ac);
		(* response.propstat.vcrstatus *)
		NEW(vs); vs.SetName("D:vcr-status"); ps.AddContent(vs);
		IF state = "frozen" THEN COPY("checked-in", state); ELSIF state = "thawed" THEN COPY("checked-out", state); END;
		NEW(ac); ac.SetStr(state); vs.AddContent(ac);
		(* response.propstat.status*)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addVcrState;
END ConfigurationReportRes;

(* baseline-report response. Like configuration-report response without state.  *)
BaselineReportRes* =OBJECT(ConfigurationReportRes);
	(* Collect info on VCR. *)
	PROCEDURE addVcr*(CONST host: ARRAY OF CHAR; VAR ms: XML.Element; CONST res, hist: ARRAY OF CHAR);
	VAR r, h, ps, v,  s : XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR;
	BEGIN
		NEW(r); r.SetName("D:response"); ms.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		acStr := "http://"; Strings.Append(acStr, host); Strings.Append(acStr, conf); Strings.Append(acStr, '/'); Strings.Append(acStr, res);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.version *)
		NEW(v); v.SetName("D:version"); ps.AddContent(v);
		acStr := "http://"; Strings.Append(acStr, host); Strings.Append(acStr, hist);
		NEW(ac); ac.SetStr(acStr); v.AddContent(ac);
		(* response.propstat.status*)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addVcr;
END BaselineReportRes;

(* Checkout with activity
<?xml version="1.0" encoding="utf-8" ?>
<D:checkout xmlns:D="DAV:">
	<D:activity-set>
		<D:href>http://repo.webdav.org/act/fix-bug-23</D:href>
	</D:activity-set>
</D:checkout>
*)
CheckoutReq* =OBJECT(XML.Document);
	PROCEDURE &Init1*(CONST host, activity: ARRAY OF CHAR); (* http://<host>/>url> *)
	VAR co, as, h: XML.Element; ac: XML.ArrayChars;
	BEGIN Init();
		SELF.AddContent(xmlDecl);
		(* checkout *)
		NEW(co); co.SetName("D:checkout"); co.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(co);
		(* checkout.activity-set *)
		NEW(as); as.SetName("D:activity-set"); co.AddContent(as);
		(* checkout.activity-set.href *)
		NEW(h); h.SetName("D:href"); as.AddContent(h);
		(* checkout.activity-set.href :=  activity; *)
		NEW(ac); ac.SetStr(activity); h.AddContent(ac);
	END Init1;
END CheckoutReq;

(* compare-baseline report response. Similar to configuration-report response.
	TODO: own sections for added, delete, ...

compare-baseline-report
	(added|deleted)-version
		href <resource>
	changed-version
		href <from>
		href <to>
 *)
CompareBaselineReportRes* =OBJECT(ConfigurationReportRes);
	VAR type * : ARRAY 16 OF CHAR;

(* Scheint nicht zu tun. Compiler meckert.
	(* Override ConfigurationReportRes. *)
	PROCEDURE &Init1*(hostName, conf: ARRAY OF CHAR);
	VAR root: XML.Element;
	BEGIN Init();
		COPY(hostName, SELF.hostName);
		COPY(conf, SELF.conf); SELF.AddContent(xmlDecl);
		NEW(root); root.SetName("D:compare-baseline-report"); root.SetAttributeValue("xmlns:D", "DAV:");
		SELF.AddContent(root);
	END Init1;
*)
	(* Collect info on VCR. ms = multistatus*)
	PROCEDURE addVcrType*(VAR ms: XML.Element; CONST type, from, to: ARRAY OF CHAR);
	CONST Hist = "/hist/";
	VAR typeEl, hrefEl: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
		typeStr: ARRAY 32 OF CHAR;
	BEGIN
		(* <type>-version *)
		COPY("D:", typeStr); Strings.Append(typeStr, type); Strings.Append(typeStr, "-version");
		NEW(typeEl); typeEl.SetName(typeStr); ms.AddContent(typeEl);
		IF type = "changed" THEN (* from *)
			(* <type>-version.href *)
			NEW(hrefEl); hrefEl.SetName("D:href"); typeEl.AddContent(hrefEl);
			COPY(hostPrefix, acStr); Strings.Append(acStr, Hist); Strings.Append(acStr, from);
			NEW(ac); ac.SetStr(acStr); hrefEl.AddContent(ac);
		END;
		IF (type = "changed") OR (type = "added") OR (type = "deleted") THEN
			NEW(hrefEl); hrefEl.SetName("D:href"); typeEl.AddContent(hrefEl);
			COPY(hostPrefix, acStr); Strings.Append(acStr, Hist); Strings.Append(acStr, to);
			NEW(ac); ac.SetStr(acStr); hrefEl.AddContent(ac);
		ELSE
			HALT(99);
		END;
	END addVcrType;
END CompareBaselineReportRes;

VersionTreeRes* =OBJECT(XML.Document);
	VAR hist: ARRAY 128 OF CHAR;
	PROCEDURE &Init1*(CONST hist: ARRAY OF CHAR);
	VAR ms: XML.Element;
	BEGIN (*Init^(); *) Init(); (*???*)
		COPY(hist, SELF.hist); SELF.AddContent(xmlDecl);
		NEW(ms); ms.SetName("D:multistatus"); ms.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(ms);
	END Init1;
	PROCEDURE addVersion*(CONST host, ver: ARRAY OF CHAR; CONST author, date, logText: ARRAY OF CHAR);
	CONST Hist = "/hist/";
	VAR root, r, h, ps, p, s, e: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR;
	BEGIN root := SELF.GetRoot();
		NEW(r); r.SetName("D:response"); root.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		acStr := "http://"; Strings.Append(acStr, host); Strings.Append(acStr, Hist);
		Strings.Append(acStr, hist);
		Strings.Append(acStr, '.'); Strings.Append(acStr, ver);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.prop *)
		NEW(p); p.SetName("D:prop"); ps.AddContent(p);
		(* response.propstat.prop.(version-name|creator-displayname|version-time|comment) *)
		NEW(e); e.SetName("D:version-name"); p.AddContent(e);
		NEW(ac); ac.SetStr(ver); e.AddContent(ac);
		NEW(e); e.SetName("D:creator-displayname"); p.AddContent(e);
		NEW(ac); ac.SetStr(author); e.AddContent(ac);
		NEW(e); e.SetName("D:version-time"); p.AddContent(e);
		NEW(ac); ac.SetStr(date); e.AddContent(ac);
		NEW(e); e.SetName("D:comment"); p.AddContent(e);
		NEW(ac); ac.SetStr(logText); e.AddContent(ac);
		(* response.propstat.status*)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addVersion;
END VersionTreeRes;

PropfindRes* =OBJECT(XML.Document);
	VAR url: ARRAY 128 OF CHAR;
	PROCEDURE &Init1*(CONST url: ARRAY OF CHAR);
	VAR ms: XML.Element;
	BEGIN (* Init^(); *) Init(); (*???*)
		COPY(url, SELF.url); SELF.AddContent(xmlDecl);
		NEW(ms); ms.SetName("D:multistatus"); ms.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(ms);
	END Init1;
	PROCEDURE addVersion*(CONST ver, author, date, logText, state, dateTime: ARRAY OF CHAR; length: LONGINT);
	VAR root, r, h, ps, p, s, e: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR;
		lengthStr: ARRAY 16 OF CHAR;
	BEGIN root := SELF.GetRoot();
		NEW(r); r.SetName("D:response"); root.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		COPY(url, acStr);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.prop *)
		NEW(p); p.SetName("D:prop"); ps.AddContent(p);
		(* response.propstat.prop.(version-name|creator-displayname|version-time|comment) *)
		NEW(e); e.SetName("D:version-name"); p.AddContent(e);
		NEW(ac); ac.SetStr(ver); e.AddContent(ac);
		NEW(e); e.SetName("D:creator-displayname"); p.AddContent(e);
		NEW(ac); ac.SetStr(author); e.AddContent(ac);
		NEW(e); e.SetName("D:version-time"); p.AddContent(e);
		NEW(ac); ac.SetStr(date); e.AddContent(ac);
		NEW(e); e.SetName("D:comment"); p.AddContent(e);
		NEW(ac); ac.SetStr(logText); e.AddContent(ac);
		IF (state = "frozen") OR (state = "thawed") THEN
			IF state = "frozen" THEN
				NEW(e); e.SetName("D:checked-in"); p.AddContent(e);
			ELSIF state = "thawed" THEN
				NEW(e); e.SetName("D:checked-out"); p.AddContent(e);
			END;
			NEW(ac); COPY(url, acStr); Strings.Append(acStr, "."); Strings.Append(acStr, ver);
			ac.SetStr(acStr); e.AddContent(ac);
		END;
		(* response.propstat.prop.(getlastmodified|getcontentlength) *)
		NEW(e); e.SetName("D:getcontentlength"); p.AddContent(e);
		NEW(ac); Strings.IntToStr(length, lengthStr); ac.SetStr(lengthStr); e.AddContent(ac);
		NEW(e); e.SetName("D:getlastmodified"); p.AddContent(e);
		NEW(ac); ac.SetStr(dateTime); e.AddContent(ac);
		(* response.propstat.status*)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addVersion;
END PropfindRes;

PropfindCollectionRes* =OBJECT(XML.Document);
	VAR collection: ARRAY 128 OF CHAR;
		OKPs, notFoundPs, OKP, notFoundP, response: XML.Element;

	PROCEDURE &Init1*(CONST collection: ARRAY OF CHAR);
	VAR ms: XML.Element;
	BEGIN (* Init^(); *) Init(); (*???*)
		COPY(collection, SELF.collection); SELF.AddContent(xmlDecl);
		NEW(ms); ms.SetName("D:multistatus"); ms.SetAttributeValue("xmlns:D", "DAV:"); SELF.AddContent(ms);
	END Init1;

	(* Create a new response element with a href. This reponse element will be use by the following addOK,
		addNotFound, ... *)
	PROCEDURE addResponse * (CONST href: ARRAY OF CHAR);
	VAR multistatus, h: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
	BEGIN
		multistatus := SELF.GetRoot();
		NEW(response); response.SetName("D:response"); multistatus.AddContent(response);
		(* response.href *)
		NEW(h); h.SetName("D:href"); response.AddContent(h);
		COPY(href, acStr);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		OKPs := NIL; notFoundPs := NIL; OKP := NIL; notFoundP := NIL;
	END addResponse;
	(* Create a propstat with a OK status. Use the prop to add the following simple properties. *)
	PROCEDURE addOK * (name: ARRAY OF CHAR; CONST value: ARRAY OF CHAR);
	VAR status, propEl: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
	BEGIN
		IF OKPs = NIL THEN (* Create propstat for successful properties. *)
			(* response.propstat *)
			NEW(OKPs); OKPs.SetName("D:propstat"); response.AddContent(OKPs);
			(* response.propstat.prop *)
			NEW(OKP); OKP.SetName("D:prop"); OKPs.AddContent(OKP);
			(* response.propstat.status *)
			NEW(status); status.SetName("D:status"); OKPs.AddContent(status);
			NEW(ac); acStr := "HTTP/1.1 200 OK"; ac.SetStr(acStr); status.AddContent(ac);
		END;
		IF Strings.Pos("DAV:", name) = 0 THEN Strings.Delete(name, 1, 2); END;
		NEW(propEl); propEl.SetName(name); OKP.AddContent(propEl);
		IF value # "" THEN
			NEW(ac); ac.SetStr(value); propEl.AddContent(ac);
		END;
	END addOK;

	PROCEDURE addResourceType * (CONST type: ARRAY OF CHAR);
	VAR coll, status, propEl: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
	BEGIN
		IF OKPs = NIL THEN (* Create propstat for successful properties. *)
			(* response.propstat *)
			NEW(OKPs); OKPs.SetName("D:propstat"); response.AddContent(OKPs);
			(* response.propstat.prop *)
			NEW(OKP); OKP.SetName("D:prop"); OKPs.AddContent(OKP);
			(* response.propstat.status *)
			NEW(status); status.SetName("D:status"); OKPs.AddContent(status);
			NEW(ac); acStr := "HTTP/1.1 200 OK"; ac.SetStr(acStr); status.AddContent(ac);
		END;
		NEW(propEl); propEl.SetName("D:resourcetype"); OKP.AddContent(propEl);
		IF type = "collection" THEN
			(* <resourcetype> <collection/> </resourcetype> *)
			NEW(coll); coll.SetName("D:collection"); propEl.AddContent(coll);
		END;
	END addResourceType;

	(* Create a propstat with a OK status. Use the prop to add the following simple properties. *)
	PROCEDURE addNotFound * (name: ARRAY OF CHAR);
	VAR status, propEl: XML.Element; ac: XML.ArrayChars; acStr: ARRAY 128 OF CHAR;
	BEGIN
		IF notFoundPs = NIL THEN (* Create propstat for NotFound properties. *)
			(* response.propstat *)
			NEW(notFoundPs); notFoundPs.SetName("D:propstat"); response.AddContent(notFoundPs);
			(* response.propstat.prop *)
			NEW(notFoundP); notFoundP.SetName("D:prop"); notFoundPs.AddContent(notFoundP);
			(* response.propstat.status *)
			NEW(status); status.SetName("D:status"); notFoundPs.AddContent(status);
			NEW(ac); acStr := "HTTP/1.1 404 Not Found"; ac.SetStr(acStr); status.AddContent(ac);
		END;
		IF Strings.Pos("DAV:", name) = 0 THEN Strings.Delete(name, 1, 2); END;
		NEW(propEl); propEl.SetName(name); notFoundP.AddContent(propEl);
	END addNotFound;


	PROCEDURE addConfiguration*(CONST name, version, state: ARRAY OF CHAR);
	VAR multistatus, r, h, ps, p, s, e: XML.Element; ac: XML.ArrayChars;
		acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR;
	BEGIN multistatus := SELF.GetRoot();
		NEW(r); r.SetName("D:response"); multistatus.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		COPY(name, acStr);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.prop *)
		NEW(p); p.SetName("D:prop"); ps.AddContent(p);
		(* response.propstat.prop.version *)
		NEW(e); e.SetName("D:version"); p.AddContent(e);
		NEW(ac); ac.SetStr(version); e.AddContent(ac);
		(* response.propstat.prop.state *)
		NEW(e); e.SetName("D:state"); p.AddContent(e);
		NEW(ac); ac.SetStr(state); e.AddContent(ac);
		(* response.propstat.prop.resourcetype *)
		NEW(e); e.SetName("D:resourcetype"); p.AddContent(e);
		NEW(ac); acStr := "collection"; ac.SetStr(acStr); e.AddContent(ac);
		(* response.propstat.status *)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addConfiguration;

	(** Add information for a collection member
	<D:multistatus xmlns="DAV:">
		<D:response>
		<D:href>http://127.0.0.1/bl0/bl1</href>
		<D:propstat>
			<D:prop>
				<D:getcontentlength>0</getcontentlength>
				<D:getlastmodified>04.Jun.2003 16:38:12</D:getlastmodified>
   	         <D:getlastmodified>Tue, 11 Mar 2003 14:16:03 GMT</D:getlastmodified>
				<D:displayname>bl1<Displayname>
				<D:resourcetype>
					<D:collection />
				</D:resourcetype>
				<D:resourcetype /> for files.
			</D:prop>
			<D:status>HTTP/1.1 200 OK</D:status>
		</D:propstat>
	</D:response>
	*)

	PROCEDURE addMember*(CONST name, type, dateTime: ARRAY OF CHAR; length: LONGINT);
	VAR root, r, h, ps, p, s, rt, e: XML.Element; ac: XML.ArrayChars;
		acStr: ARRAY 128 OF CHAR; statusStr: ARRAY 64 OF CHAR; lengthStr: ARRAY 16 OF CHAR;
	BEGIN root := SELF.GetRoot();
		NEW(r); r.SetName("D:response"); root.AddContent(r);
		(* response.href *)
		NEW(h); h.SetName("D:href"); r.AddContent(h);
		COPY(name, acStr);
		NEW(ac); ac.SetStr(acStr); h.AddContent(ac);
		(* response.propstat *)
		NEW(ps); ps.SetName("D:propstat"); r.AddContent(ps);
		(* response.propstat.prop *)
		NEW(p); p.SetName("D:prop"); ps.AddContent(p);
		(* response.propstat.prop.(getlastmodified|getcontentlength) *)
		NEW(e); e.SetName("D:getcontentlength"); p.AddContent(e);
		NEW(ac); Strings.IntToStr(length, lengthStr); ac.SetStr(lengthStr); e.AddContent(ac);
		NEW(e); e.SetName("D:getlastmodified"); p.AddContent(e);
		NEW(ac); ac.SetStr(dateTime); e.AddContent(ac);
		(* response.propstat.prop.displayname *)
		NEW(e); e.SetName("D:displayname"); p.AddContent(e);
		Files.SplitPath(name, acStr, statusStr);
		NEW(ac); ac.SetStr(statusStr); e.AddContent(ac);
		(* response.propstat.prop.resourcetype *)
		NEW(rt); rt.SetName("D:resourcetype"); p.AddContent(rt);
		IF type = "collection" THEN
			(* <resourcetype> <collection/> </resourcetype> *)
			NEW(e); e.SetName("D:collection"); rt.AddContent(e);
		END;
		(* response.propstat.status*)
		NEW(s); s.SetName("D:status"); ps.AddContent(s);
		NEW(ac); statusStr := "HTTP/1.1 200 OK"; ac.SetStr(statusStr); s.AddContent(ac);
	END addMember;
END PropfindCollectionRes;

	(** Scanner and Parser which have my error procedure which doesn't HALT(99) *)
	Scanner * = OBJECT (XMLScanner.Scanner)
		PROCEDURE &Init*(fr: Streams.Reader);
		BEGIN
			Init^(fr);
			reportError := XMLReportError;
		END Init;
	END Scanner;

	Parser * = OBJECT (XMLParser.Parser)
		PROCEDURE &Init*(s: XMLScanner.Scanner);
		BEGIN
			Init^(s);
			reportError := XMLReportError;
		END Init;
	END Parser;





(***********************************************************************************)
(*                                                                       VAR                                                                                    *)
(***********************************************************************************)

VAR
	xmlDecl: XML.XMLDecl;


TYPE
	OdXml* = OBJECT
	VAR
		showTree* : PROCEDURE (doc: XML.Document);
		logW: Streams.Writer;

		xmlns* : WebHTTP.AdditionalField; (* collect XML namespaces. *)


	PROCEDURE &Init*;
	BEGIN
		showTree := NIL;
		xmlns := NIL;
		NEW(logW, KernelLog.Send, 512);
	END Init;

(***********************************************************************************)
(*                                                                PROCEDURE                                                                             *)
(***********************************************************************************)


PROCEDURE ShowDAVError * (doc: XML.Document): BOOLEAN;
VAR
	el, child: XML.Element; elName, msg: OdUtil.Line;
BEGIN
	el := doc.GetRoot();
	elName  := AbsXmlName(el.GetName());
	IF elName = "DAV:error" THEN
		child := GetFirstChild(el);
		IF child # NIL THEN (* regular error code *)
			msg := AbsXmlName(child.GetName());
		ELSE (* My server at the moment. *)
			GetCharData(el, msg);
		END;
		OdUtil.Msg2("DAV:error =", msg);
		RETURN TRUE;
	END;
	RETURN FALSE;
END ShowDAVError;

PROCEDURE IsDAVError * (doc: XML.Document; VAR name: ARRAY OF CHAR): BOOLEAN;
VAR
	el, child: XML.Element; elName, line: OdUtil.Line;
BEGIN
	el := doc.GetRoot();
	elName  := AbsXmlName(el.GetName());
	IF elName = "DAV:error" THEN
		child := GetFirstChild(el);
		IF child # NIL THEN (* regular error code *)
			line := AbsXmlName(child.GetName());
			COPY(line, name);
		ELSE (* My server at the moment. *)
			GetCharData(el, name);
		END;
		RETURN TRUE;
	END;
	RETURN FALSE;
END IsDAVError;

(* don't write anything. Just for counting what's written to a writer. *)
(*PROCEDURE Dev0(VAR buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN END Dev0;*)
PROCEDURE Dev0(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
BEGIN END Dev0;

(* Find size of an XML object which must be written. *)
PROCEDURE XmlSize*(doc: XML.Document): LONGINT;
VAR counter: Streams.Writer;
BEGIN
	Streams.OpenWriter(counter, Dev0); doc.Write(counter, NIL, 0); counter.Update();
	RETURN counter.sent;
END XmlSize;

(** Collect XML namespaces from an element. No nested scopes. So hope that no namespace is redefined in
a XML body. *)
PROCEDURE GetXmlns * (el: XML.Element);
VAR
	a: ANY; name, value: XML.String;
	attributes: XMLObjects.Enumerator; attr: XML.Attribute;
	tag, ns: ARRAY 32 OF CHAR;
BEGIN
	attributes := el.GetAttributes();
	WHILE attributes.HasMoreElements() DO
		a := attributes.GetNext();
		attr := a(XML.Attribute);
		name := attr.GetName(); value := attr.GetValue();
		IF Strings.Pos("xmlns:", name^) = 0 THEN
			Files.SplitName(name^, tag, ns);
			WebHTTP.SetAdditionalFieldValue(xmlns, ns, value^);
			(* OdUtil.Msg3(name^, "=", value^); *)
		END;
	END;
END GetXmlns;

(** Expand an xmlns for an XML String. *)
PROCEDURE AbsXmlName * (rawName: XML.String):OdUtil.Line;
BEGIN
	RETURN AbsName(rawName^);
END AbsXmlName;

(** Expand an xmlns. *)
PROCEDURE AbsName * (CONST rawName: ARRAY OF CHAR):OdUtil.Line;
VAR absName, absSpace, nameSpace, name: OdUtil.Line; colonPos: LONGINT;
BEGIN
	colonPos := Strings.Pos(":", rawName);
	IF colonPos  > -1 THEN
		Files.SplitName(rawName, nameSpace, name);
		IF nameSpace = "D" THEN (* Defaultnamespace. *)
			Strings.Concat("DAV:", name, absName);
		ELSIF WebHTTP.GetAdditionalFieldValue(xmlns, nameSpace, absSpace) THEN
			Strings.Concat(absSpace, name, absName);
		ELSE
			COPY(rawName, absName);
		END;
	ELSE (* Default *)
		Files.JoinName("DAV", rawName, absName);
	END;
	RETURN absName;
END AbsName;

(* Dummy because compiler doesn't like IF AbsName(s) =  "DAV:jkjk" *)
PROCEDURE EqualName * (name: XML.String; CONST absName: ARRAY OF CHAR): BOOLEAN;
VAR line: OdUtil.Line;
BEGIN
	line := AbsName(name^);
	(*KernelLog.Enter;KernelLog.String(name);KernelLog.String(",");KernelLog.String(line);
	KernelLog.String(",");KernelLog.String(absName);KernelLog.Exit;*)
	RETURN line = absName;
END EqualName;

(* Just for the relevant cases in the moment. *)
(** Write an XML document or element e.g. in case of unexpected elements to the log device set in KernelLog. *)
PROCEDURE LogDoc * (CONST info: ARRAY OF CHAR; doc: XML.Document);
BEGIN
	logW.String(info); logW.Ln;
	doc.Write(logW, NIL, 0);
	logW.Update();
END LogDoc;

PROCEDURE LogEl * (CONST info: ARRAY OF CHAR; el: XML.Element);
BEGIN
	logW.String(info); logW.Ln;
	el.Write(logW, NIL, 0);
	logW.Update();
END LogEl;

(* Get first child element. Would be nice to have that in XML.Mod. *)
PROCEDURE GetFirstChild * (parent: XML.Element): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY;
BEGIN
	enum := parent.GetContents();
	p := enum.GetNext();
	IF p IS XML.Element THEN
		RETURN p(XML.Element);
	ELSE
		RETURN NIL;
	END;
END GetFirstChild;

(* Find an element with a certain type(name) *)
PROCEDURE FindElement*(parent: XML.Element; CONST type: ARRAY OF CHAR): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; s: XML.String; l: OdUtil.Line;
BEGIN
	(*KernelLog.Enter; KernelLog.String(type); KernelLog.Exit; System.OpenKernelLog *)
	enum := parent.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF s # NIL THEN
				l := AbsName(s^);
				IF l = type THEN RETURN e; END
			END;
		END
	END;
	RETURN NIL
END FindElement;

(* Find an element in an element tree by a dot seperated string. *)
PROCEDURE SplitElement*(parent: XML.Element; CONST path: ARRAY OF CHAR): XML.Element;
VAR splitter: StringSplitter; child: XML.Element; name: ARRAY 64 OF CHAR;
BEGIN
	NEW(splitter, path); child := NIL;
	WHILE splitter.Next('.', name) DO
		child := FindElement(parent, name);
		IF child = NIL THEN RETURN NIL; END; (* Error *)
		parent := child;
	END;
	RETURN child;
END SplitElement;



PROCEDURE ConfigurationReportReq*(): XML.Document;
(* es feature *)
VAR doc: XML.Document; cr: XML.Element;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(cr); cr.SetName("D:configuration-report"); cr.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(cr);
	RETURN doc;
END ConfigurationReportReq;

(* update version href *)
PROCEDURE UpdateReq*(CONST host, ver: ARRAY OF CHAR): XML.Document;
CONST PLog = FALSE;
VAR doc: XML.Document; vc,v,h: XML.Element;
	name: ARRAY 128 OF CHAR; versionNumber: LONGINT;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(vc); vc.SetName("D:update"); vc.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(vc);
	NEW(v); v.SetName("D:version"); vc.AddContent(v);
	NEW(h); h.SetName("D:href"); v.AddContent(h);
	name := "http://"; Strings.Append(name, host);
	Strings.StrToInt(ver, versionNumber);
	IF versionNumber > 0 THEN
		(* A version number is given. *)
		Strings.Append(name, UpdateVersionTag);
	END;
	Strings.Append(name, ver);
	IF PLog THEN OdUtil.Msg2("DAVXml.UpdateReq", ver); END;
	h.AddContent(ArrayChars(name));
	RETURN doc;
END UpdateReq;

(* version-tree prop (version-name creator-displayname version-time comment) *)
PROCEDURE VersionTreeReq*(): XML.Document;
VAR
	doc: XML.Document; vt, p, e: XML.Element;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(vt); vt.SetName("D:version-tree"); vt.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(vt);
	NEW(p); p.SetName("D:prop"); vt.AddContent(p);
	NEW(e); e.SetName("D:version-name"); p.AddContent(e);
	NEW(e); e.SetName("D:creator-displayname"); p.AddContent(e);
	NEW(e); e.SetName("D:version-time"); p.AddContent(e);
	NEW(e); e.SetName("D:comment"); p.AddContent(e);
	RETURN doc;
END VersionTreeReq;

(* propertyupdate (set  1{prop <propname> 1{href} } | remove 1{ prop <propname> href } *)
(* Only works for 'set hrefproperties' at the moment. *)
PROCEDURE ProppatchReq*(CONST modeName: ARRAY OF CHAR; props: WebHTTP.AdditionalField): XML.Document;
VAR doc: XML.Document; pu(*propertyupdate*), prop, mode, e : XML.Element;
	ac: XML.ArrayChars; modePropName, key, attrKey, attrVal: ARRAY 128 OF CHAR;
	pos: LONGINT; nameVal: StringSplitter;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	(* propertyupdate *)
	NEW(pu); pu.SetName("D:propertyupdate"); pu.SetAttributeValue("xmlns:D", "DAV:");
	pu.SetAttributeValue("xmlns:SVN", "http://subversion.tigris.org/xmlns/svn/");
	doc.AddContent(pu);
	(* pu.set/remove *)
	Strings.Concat("D:", modeName, modePropName);
	NEW(mode); mode.SetName(modePropName); pu.AddContent(mode);
	(* pu.<mode>.prop *)
	NEW(prop); prop.SetName("D:prop"); mode.AddContent(prop);
	WHILE props # NIL DO
		(* pu.set.prop.<propname> *)
		pos := Strings.Pos(" ", props.key); (* Assume an attribute is following. *)
		IF pos > -1 THEN
			Strings.Copy(props.key, 0, pos, key);
		ELSE
			COPY(props.key, key);
		END;
		NEW(e); e.SetName(key); prop.AddContent(e);
		IF pos > -1 THEN
			Strings.Delete(props.key, 0, pos+1);
			NEW(nameVal, props.key);
			IF nameVal.Next("=", attrKey) THEN
				IF nameVal.Next("=", attrVal) THEN
					e.SetAttributeValue(attrKey, attrVal);
				END;
			END;
			pos := Strings.Pos("=", props.key);
		END;
		IF modeName = "set" THEN
			(* pu.set.prop.<propname>.<value> *)
			NEW(ac); ac.SetStr(props.value); e.AddContent(ac);
		END;
		props := props.next;
	END;
	RETURN doc;
END ProppatchReq;

(* propfind (propname | allprop | prop ( { <propname> } )*)
PROCEDURE PropfindReq * (props: WebHTTP.AdditionalField): XML.Document;
VAR doc: XML.Document; propfind, prop, el: XML.Element;
BEGIN
	prop := NIL;
	NEW(doc);
	doc.AddContent(xmlDecl);

	NEW(propfind);
	propfind.SetName("D:propfind");
	propfind.SetAttributeValue("xmlns:D", "DAV:");
	propfind.SetAttributeValue("xmlns:D2", "http://subversion.tigris.org/xmlns/dav/");
	doc.AddContent(propfind);

	WHILE props # NIL DO
		IF props.key = "D:propname" THEN
			NEW(prop); prop.SetName("D:propname"); propfind.AddContent(prop);
			RETURN doc;
		ELSIF props.key = "D:allprop" THEN
			NEW(prop); prop.SetName("D:allprop"); propfind.AddContent(prop);
			RETURN doc;
		ELSE
			IF prop = NIL THEN
				NEW(prop); prop.SetName("D:prop"); propfind.AddContent(prop);
			END;
			NEW(el); el.SetName(props.key); prop.AddContent(el);
		END;
		props := props.next;
	END;
	RETURN doc;
END PropfindReq;

(* checkin prop (creator-displayname comment) *)
PROCEDURE CheckinReq*(CONST author, desc: ARRAY OF CHAR): XML.Document;
VAR doc: XML.Document; vt, p, e: XML.Element;
	ac: XML.ArrayChars;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(vt); vt.SetName("D:checkin"); vt.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(vt);
	NEW(p); p.SetName("D:prop"); vt.AddContent(p);
	(* Author *) NEW(e);
	NEW(ac); ac.SetStr(author); e.AddContent(ac);
	e.SetName("D:creator-displayname"); p.AddContent(e);
	(* Description *) NEW(e);
	NEW(ac); ac.SetStr(desc); e.AddContent(ac);
	e.SetName("D:comment"); p.AddContent(e);
	RETURN doc;
END CheckinReq;

(* version-control prop (creator-displayname comment) *)
PROCEDURE VersionControlCreateReq*(CONST author, desc: ARRAY OF CHAR): XML.Document;
BEGIN
	RETURN FreezeReq("version-control", author, desc);
END VersionControlCreateReq;

(* <method> prop (creator-displayname comment) *)
PROCEDURE FreezeReq*(CONST method, author, desc: ARRAY OF CHAR): XML.Document;
VAR doc: XML.Document; root, p, e: XML.Element;
	ac: XML.ArrayChars;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(root); root.SetName(method); root.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(root);
	NEW(p); p.SetName("D:prop"); root.AddContent(p);
	(* Author *) NEW(e);
	NEW(ac); ac.SetStr(author); e.AddContent(ac);
	e.SetName("D:creator-displayname"); p.AddContent(e);
	(* Description *) NEW(e);
	NEW(ac); ac.SetStr(desc); e.AddContent(ac);
	e.SetName("D:comment"); p.AddContent(e);
	RETURN doc;
END FreezeReq;

(* <method> version href *)
PROCEDURE SelectReq*(CONST method, host, ver: ARRAY OF CHAR): XML.Document;
VAR doc: XML.Document; vc,v,h: XML.Element;
	name: ARRAY 512 OF CHAR;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	NEW(vc); vc.SetName(method); vc.SetAttributeValue("xmlns:D", "DAV:"); doc.AddContent(vc);
	NEW(v); v.SetName("D:version"); vc.AddContent(v);
	NEW(h); h.SetName("D:href"); v.AddContent(h);
	name := "http://"; Strings.Append(name, host); Strings.Append(name, ver);
	h.AddContent(ArrayChars(name));
	RETURN doc;
END SelectReq;

(* <label> href *)
PROCEDURE Href1Req*(CONST label, href: ARRAY OF CHAR): XML.Document;
VAR doc: XML.Document; label0, href1: XML.Element;
BEGIN
	NEW(doc); doc.AddContent(xmlDecl);
	(* label = version-tree, compare-baseline, ... *)
	NEW(label0); label0.SetName(label);
	label0.SetAttributeValue("xmlns:D", "DAV:");
	doc.AddContent(label0);
	(* href *)
	NEW(href1); href1.SetName("D:href");
	label0.AddContent(href1);
	href1.AddContent(ArrayChars(href));
	RETURN doc;
END Href1Req;

PROCEDURE GetVersionControlHref*(doc: XML.Document; VAR charData: ARRAY OF CHAR);
VAR e: XML.Element;
BEGIN
	e := FindElement(doc.GetRoot(), "DAV:version");
	e := FindElement(e, "DAV:href");
	GetCharData(e, charData);
END GetVersionControlHref;

(* update, version, href: versionName*)
PROCEDURE GetUpdateVersionName*(doc: XML.Document; VAR versionName: ARRAY OF CHAR);
VAR
	e: XML.Element; versionResource: ARRAY 256 OF CHAR; i, dotPos: LONGINT;
	host, path: ARRAY 256 OF CHAR; port: LONGINT;
BEGIN
	e := FindElement(doc.GetRoot(), "DAV:version");
	IF e # NIL THEN
		e := FindElement(e, "DAV:href");
		IF e # NIL THEN
			GetCharData(e, versionResource);
			IF WebHTTP.SplitHTTPAdr(versionResource, host, path, port) THEN END;
			IF Strings.Pos("/hist/", path) = 0 THEN
				Strings.Delete(path, 0, 6);
			ELSE (* Expect "/version.<n>" *)
				Strings.Delete(path, 0, 1);
			END;
			dotPos := -1;
			(* Split <version history>.<version number> *)
			FOR i := 0 TO Strings.Length(path) -1 DO
				IF path[i] = '.' THEN dotPos := i; END;
			END;
			(* Copy versionName (number) *)
			FOR i := dotPos+1 TO Strings.Length(path) DO
				(* Also copies trailing 0X *)
				versionName[i - (dotPos+1)] := path[i];
			END;
		END;
	END;
END GetUpdateVersionName;

(* checkin.prop.(creator-displayname, comment) *)
PROCEDURE GetAuthorDesc*(doc: XML.Document; VAR author, desc: ARRAY OF CHAR);
VAR e0, e1: XML.Element;
BEGIN
	e0 := FindElement(doc.GetRoot(), "DAV:prop");
	IF e0 # NIL THEN
		e1 := FindElement(e0, "DAV:creator-displayname");
		IF e1 # NIL THEN GetCharData(e1, author); ELSE author[0]  := 0X; END;
		e1 := FindElement(e0, "DAV:comment");
		IF e1 # NIL THEN GetCharData(e1, desc); ELSE desc[0]  := 0X; END;
	ELSE
		author[0]  := 0X; desc[0] := 0X;
	END;
END GetAuthorDesc;

PROCEDURE File*; (* System.Free DAVXml ~ DAVXml.Do  DAVXml.File   System.OpenKernelLog *)
VAR f: Files.File; fr: Files.Reader; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; xmlDoc: XML.Document;
	w: Streams.Writer; name: ARRAY 128 OF CHAR;
BEGIN
	f := Files.Old("VersionControl.XML");
	NEW(fr, f, 0);
	IF f # NIL THEN
		KernelLog.Enter; KernelLog.String("File found"); KernelLog.Exit;
		NEW(scanner, fr); NEW(parser, scanner); xmlDoc := parser.Parse();
		Streams.OpenWriter(w, KernelLog.Send); (* gibt das Zeugs im Kernel Log aus *)
		xmlDoc.Write(w, NIL, 0); w.Update();
		GetVersionControlHref(xmlDoc, name);
		w.String(name); w.Update();
	ELSE
		xmlDoc := NIL
	END
END File;

	END OdXml;


(* Like in XMLScanner and XMLParser but doesn't HALT(99) *)
PROCEDURE XMLReportError(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
	BEGIN
		KernelLog.Enter; KernelLog.Char(CHR(9H)); KernelLog.Char(CHR(9H)); KernelLog.String("pos "); KernelLog.Int(pos, 6);
		KernelLog.String(", line "); KernelLog.Int(line, 0); KernelLog.String(", row "); KernelLog.Int(row, 0);
		KernelLog.String("    "); KernelLog.String(msg); KernelLog.Exit;
END XMLReportError;

PROCEDURE NameContent(CONST name: ARRAY OF CHAR): XML.NameContent;
VAR nameContent: XML.NameContent;
BEGIN
	NEW(nameContent); nameContent.SetName(name);
	RETURN nameContent;
END NameContent;

PROCEDURE XmlDecl(CONST version, encoding: ARRAY OF CHAR): XML.XMLDecl;
VAR xmlDecl: XML.XMLDecl;
BEGIN
	NEW(xmlDecl); xmlDecl.SetVersion(version); xmlDecl.SetEncoding(encoding); xmlDecl.SetStandalone(TRUE);
	RETURN xmlDecl;
END XmlDecl;

(* Get character data of an element. *)
PROCEDURE GetCharData*(parent: XML.Element; VAR charData: ARRAY OF CHAR);
VAR enum: XMLObjects.Enumerator; p: ANY; cd: XML.ArrayChars; s: XML.String; i: INTEGER;
BEGIN
	charData[0] := 0X;
	IF parent # NIL THEN
		enum := parent.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.ArrayChars THEN
				cd := p(XML.ArrayChars); s := cd.GetStr();
				IF s # NIL THEN Strings.Append(charData, s^); END;
				IF charData[0] = 0DX THEN i := 0; REPEAT INC(i); charData[i-1] := charData[i]; UNTIL charData[i] = 0X; END;
			ELSE
				COPY("XML element isn't XML.ArrayChars", charData);
			END;
		END;
	ELSE
		COPY("DAVXML.GetCharData: parent was NIL", charData);
	END;
END GetCharData;

(* Get character data string of an element. *)
PROCEDURE GetCharString*(parent: XML.Element): Strings.String;
VAR enum: XMLObjects.Enumerator; p: ANY; cd: XML.ArrayChars;
BEGIN
	IF parent # NIL THEN
		enum := parent.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.ArrayChars THEN
				cd := p(XML.ArrayChars);
				RETURN cd.GetStr();
			ELSE
				(*Strings.NewString("Error: XML element isn't XML.ArrayChars");*)
			END;
		END;
	ELSE
		(*Strings.NewStringCOPY("DAVXML.GetCharData: parent was NIL", charData);*)
	END;
	RETURN NIL;
END GetCharString;


PROCEDURE ArrayChars(CONST str: ARRAY OF CHAR): XML.ArrayChars;
VAR arrayChars: XML.ArrayChars;
BEGIN
	NEW(arrayChars); arrayChars.SetStr(str);
	RETURN arrayChars;
END ArrayChars;


BEGIN
	xmlDecl := XmlDecl("1.0", "UTF-8"); (* Standard header *)
END OdXml.