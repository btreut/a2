MODULE WebHTTP; (** AUTHOR "tf/be"; PURPOSE "HTTP parsing"; *)
(* 02.04.2003 es, additional result codes, WebDAV methods. *)
(* 12.04.2003 es, WebDAV result codes. *)


IMPORT IP, TFLog, Streams, Dates, Strings;

CONST
	HTTPPort* = 80;
	HTTPSPort*= 443;

	(** HTTP Result Codes *)
	(*     Informational      *)
	Continue* = 100;
	SwitchingProtocols* = 101;
	Processing* = 102; (* RFC 2518 *)
	(*         Successful        *)
	OK* = 200;
	Created* = 201;
	Accepted*= 202;
	NonAuthoritativeInformation*= 203;
	NoContent*= 204;
	ResetContent*= 205;
	PartialContent*= 206;
	MultiStatus* = 207; (* RFC 2518 *)
	(*	Redirection	*)
	MultipleChoices*= 300;
	ObjectMoved* = 301; (* moved permananently *)
	ObjectMovedTemporarily* = 302;  (* found *)
	SeeOther*= 303;
	NotModified* = 304;
	UseProxy*= 305;
	TemporaryRedirect*= 307;
	(*	Client Error	*)
	BadRequest* = 400;
	Unauthorized* = 401;
	PaymentRequired*= 402;
	Forbidden* = 403;
	NotFound* = 404;
	MethodNotAllowed*= 405;
	NotAcceptable*= 406;
	ProxyAuthenticationRequested*= 407;
	RequestTimeout*= 408;
	Conflict* = 409;
	Gone*= 410;
	LengthRequired* = 411;
	PreconditionFailed* = 412;
	RequestEntityTooLarge*= 413;
	RequestURITooLong* = 414;
	UnsupportedMediaType*= 415;
	RequestedRangeNotSatisfiable*= 416;
	ExpectationFailed*= 417;
	UnprocessableEntity* = 422; (* RFC 2518 *)
	Locked* = 423; (* RFC 2518 *)
	FailedDependency*= 424; (* RFC 2518 *)
	(*      Server Error     *)
	InternalServerError* = 500;
	NotImplemented* = 501;
	BadGateway*= 502;
	ServiceUnavailable*= 503;
	GatewayTimeout*= 504;
	VersionNotSupported* = 505;
	InsufficientStorage* = 507; (* RFC 2518 *)

	(** HTTP methods RFC 2616 Section 5.1.1*)
	UnknownM* = 0; GetM* = 1; HeadM* = 2; PutM* = 3; PostM* = 4; OptionsM* = 5;
	TraceM* = 6; DeleteM* = 7; ConnectM* = 8;

	(** new HTTP methods RFC 2518 Section 8: HTTP Extensions for Distributed Authoring -- WebDAV *)
	PropfindM* = 10; ProppatchM* = 11; MkcolM* = 12; CopyM* = 13; MoveM* = 14; LockM* = 15; UnlockM* = 16;

	(** new HTTP methods RFC 3253 Versioning Extensions to  WebDAV *)
	VersionControlM* = 17; ReportM* = 18; CheckoutM* = 19; CheckinM* = 20; UncheckoutM* = 21;
	MkworkspaceM* = 22; UpdateM* = 23; LabelM* = 24; MergeM* = 25; BaselineControlM* = 26; MkactivityM* = 27;

	(** HTTP date & time format *)
	DateTimeFormat* = "www, dd mmm yyyy hh:nn:ss GMT";

	(* Chunker stuff *)
	BufSize = 400H;
	TokenSize = 10H;
	
	MaxRequestHeaderFields* = 47+10; (* at most 47 standard headers of RFC 2616 plus a number of additional header fields*)
	
	DocType* = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">';
	
TYPE
	AdditionalField* = POINTER TO RECORD
		key* : ARRAY 64 OF CHAR;
		value* : ARRAY 1024 OF CHAR;
		next* : AdditionalField;
	END;

	RequestHeader* = RECORD
		fadr* : IP.Adr;
		fport* : LONGINT;
		method* : LONGINT;
		maj*, min* : LONGINT;
		uri* : ARRAY 4096 OF CHAR;
		host* : ARRAY 256 OF CHAR;
		referer* : ARRAY 256 OF CHAR;
		useragent* : ARRAY 256 OF CHAR;
		accept* : ARRAY 256 OF CHAR;
		transferencoding* : ARRAY 64 OF CHAR;
		additionalFields* : AdditionalField;
	END;

	ResponseHeader* = RECORD
		maj*, min* : LONGINT;
		statuscode* : LONGINT;
		reasonphrase* : ARRAY 256 OF CHAR;
		server* : ARRAY 256 OF CHAR;
		date* : ARRAY 32 OF CHAR;
		location*: ARRAY 1024 OF CHAR;
		contenttype* : ARRAY 64 OF CHAR;
		contentlength* : LONGINT;
		contentlocation*: ARRAY 1024 OF CHAR;
		transferencoding* : ARRAY 64 OF CHAR;
		lastmodified*: ARRAY 32 OF CHAR;
		additionalFields* : AdditionalField;
	END;

	ChunkedOutStream* = OBJECT
		VAR (* General vars: *)
			outW: Streams.Writer;
			buf: ARRAY BufSize OF CHAR;
			bufPos: LONGINT;
			chunked: BOOLEAN;

			(* Chunked mode vars *)
			token: ARRAY TokenSize OF CHAR;

		PROCEDURE &Init*(VAR inW: Streams.Writer; outW: Streams.Writer; VAR request: RequestHeader; VAR reply: ResponseHeader);
		BEGIN
			SELF.outW := outW;
			chunked := Version(request, 1,1);
			IF chunked THEN
				Streams.OpenWriter(inW, Sender);
				COPY("chunked", reply.transferencoding);
				reply.contentlength := -1
			ELSE
				inW := outW
			END
		END Init;

		PROCEDURE Sender(CONST inBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR i: LONGINT;
		BEGIN
			ASSERT(chunked);
			i := ofs;
			WHILE (i < ofs+len) DO
				buf[bufPos] := inBuf[i];
				INC(i);
				INC(bufPos);
				IF bufPos = BufSize THEN WriteChunked END;
				IF propagate THEN outW.Update END
			END
		END Sender;

		PROCEDURE WriteChunked;
		BEGIN (* inv: chunked=TRUE *)
			Strings.IntToHexStr(bufPos, 8, token);
			outW.String(token);
			outW.Ln;
			outW.Bytes(buf, 0, bufPos);
			outW.Ln;
			bufPos := 0
		END WriteChunked;

		PROCEDURE Update*;
		BEGIN
			IF chunked THEN WriteChunked END;
			outW.Update
		END Update;

		PROCEDURE Close*;
		BEGIN
			IF chunked THEN
				IF bufPos > 0 THEN WriteChunked END;
				outW.Char("0");
				outW.Ln;
				outW.Ln
			END;
			outW.Update
		END Close;
	END ChunkedOutStream;

	ChunkedInStream* = OBJECT
		VAR (* General vars: *)
			inR: Streams.Reader;
			remain: LONGINT;
			eof : BOOLEAN;
			(* Chunked mode vars: *)
			chunkSize: LONGINT;
			first : BOOLEAN;

		PROCEDURE &Init*(VAR inR, outR: Streams.Reader);
		BEGIN
			SELF.inR := inR;
			Streams.OpenReader(outR, Receiver);
			eof := FALSE; first := TRUE;
		END Init;

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR i: LONGINT; token: ARRAY 16 OF CHAR; ch: CHAR;
		BEGIN
			IF ~eof THEN
				ASSERT((size > 0) & (min <= size) & (min >= 0));
				len := 0; i := ofs; res := Streams.Ok; chunkSize := -1;
				WHILE (chunkSize # 0) & (res = Streams.Ok) & (len < size) DO
					(* Read the chunk size *)
					IF remain = 0 THEN
						IF ~first THEN inR.SkipLn  END; first := FALSE;
						inR.Token(token);
						inR.SkipLn;
						Strings.HexStrToInt(token, chunkSize, res);
						remain := chunkSize
					END;
					(* Fill data into out buffer *)
					WHILE (res = Streams.Ok) & (len < size) & (remain > 0) DO
						inR.Char(ch);
						res := inR.res;
						buf[i] := ch;
						INC(len); INC(i); DEC(remain)
					END;
				END;
				IF chunkSize = 0 THEN eof := TRUE END
			ELSE
				res := Streams.EOF
			END
		END Receiver;
	END ChunkedInStream;
	
(* writing to stream 'inW' writes 'size' characters to 'outW' and then stops, returning Streams.EOF when attempting to write beyond stream end *)
(* implementation limination: 'remainder' bookkeeping and EOF detection occurs with Update(); but not after each Char() or Bytes(); a too large last data chunk may therefore be written only in part. when EOF is detected *)
		
	LimitedOutStream* = OBJECT
		VAR outW: Streams.Writer;
			buf: ARRAY BufSize OF CHAR;
			bufPos: LONGINT;
			remain-: LONGINT;
	
		PROCEDURE &Init*(VAR inW, outW: Streams.Writer; size : LONGINT);
		BEGIN
			SELF.outW := outW;	
			remain := size;
			bufPos:=0;
			Streams.OpenWriter(inW, Sender);
		END Init;

		PROCEDURE Sender(CONST outBuf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR i: LONGINT;
		BEGIN
			i := ofs;
			res:=outW.res ;
			WHILE (i < ofs+len) & (remain>0) DO
				buf[bufPos] := outBuf[i];
				INC(i);
				INC(bufPos);
				DEC(remain);
				IF (bufPos = BufSize) OR (remain=0) THEN Write END;
				IF propagate THEN outW.Update END
			END;
			IF (remain=0) & (i < ofs+len) THEN res:= Streams.EOF END;
		END Sender;
		
		PROCEDURE Write;
		BEGIN
			outW.Bytes(buf, 0, bufPos);
			bufPos := 0
		END Write;
		
		PROCEDURE Update*;
		BEGIN
			Write;
			outW.Update;
		END Update;
		
		PROCEDURE Padding*(ch: CHAR);
		VAR i:LONGINT;
		BEGIN
			Update; (*compute 'remain'*)
			WHILE remain>0 DO outW.Char(ch); DEC(remain) END;
			outW.Update;
		END Padding;
		
	
	END LimitedOutStream;
	
	LimitedInStream* = OBJECT
		VAR inR: Streams.Reader;
			remain-: LONGINT;
	
		PROCEDURE &Init*(VAR inR, outR: Streams.Reader; size : LONGINT);
		BEGIN
			SELF.inR := inR;	remain := size;
			Streams.OpenReader(outR, Receiver);
		END Init;

		PROCEDURE Receiver(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR l: LONGINT;
		BEGIN
			IF remain > 0 THEN
				ASSERT((size > 0) & (min <= size) & (min >= 0));
				res := Streams.Ok;
				l := size; IF l > remain THEN l := remain END;
				inR.Bytes(buf, ofs, l, len);
				DEC(remain, len);
			ELSE res := Streams.EOF
			END
		END Receiver;
	END LimitedInStream;

PROCEDURE EOL(VAR in: Streams.Reader): BOOLEAN;
BEGIN
	in.SkipSpaces;
	RETURN in.EOLN();
END EOL;

PROCEDURE GetToken(VAR in: Streams.Reader; VAR token: ARRAY OF CHAR);
BEGIN
	in.SkipSpaces; in.Token(token)
END GetToken;

PROCEDURE GetInt(VAR i: LONGINT; CONST buf: ARRAY OF CHAR; VAR x: LONGINT);
VAR ch: CHAR;
BEGIN
	x := 0;
	LOOP
		ch := buf[i];
		IF (ch < "0") OR (ch > "9") THEN EXIT END;
		x := x * 10 + (ORD(ch)-ORD("0")); INC(i)
	END
END GetInt;

PROCEDURE Match(CONST  buf: ARRAY OF CHAR; with: ARRAY OF CHAR; VAR i: LONGINT): BOOLEAN;
VAR j: LONGINT;
BEGIN
	j := 0; WHILE (j<LEN(with)) & (with[j] # 0X) &  (i<LEN(buf)) & (buf[i] = with[j]) DO INC(i); INC(j) END;
	RETURN with[j] = 0X
END Match;

PROCEDURE EqualsI(CONST buf: ARRAY OF CHAR; with: ARRAY OF CHAR): BOOLEAN;
VAR j: LONGINT;
BEGIN
	j := 0; WHILE (with[j] # 0X) & (CAP(buf[j]) = CAP(with[j])) DO INC(j) END;
	RETURN CAP(with[j]) = CAP(buf[j])
END EqualsI;

(** Currently only for additional fields *)
PROCEDURE HasAdditionalField*(af : AdditionalField; fieldName: ARRAY OF CHAR) : BOOLEAN;
BEGIN
	WHILE (af # NIL) & (~EqualsI(af.key, fieldName)) DO af := af.next END;
	RETURN af # NIL
END HasAdditionalField;

(** Currently only for additional fields *)
PROCEDURE GetAdditionalField*(af : AdditionalField; fieldName: ARRAY OF CHAR) : AdditionalField;
BEGIN
	WHILE (af # NIL) & (~EqualsI(af.key, fieldName)) DO af := af.next END;
	RETURN af
END GetAdditionalField;

(** Currently only for additional fields *)
PROCEDURE GetAdditionalFieldValue*(af: AdditionalField; fieldName: ARRAY OF CHAR; VAR value : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	WHILE (af # NIL) & (~EqualsI(af.key, fieldName)) DO af := af.next END;
	IF af # NIL THEN
		COPY(af.value, value);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END GetAdditionalFieldValue;

(** return request property as a string *)
PROCEDURE GetRequestPropertyValue*(VAR header : RequestHeader; propertyName : ARRAY OF CHAR; VAR result : ARRAY OF CHAR);
BEGIN
	IF propertyName = "#ip" THEN IP.AdrToStr(header.fadr, result)
	ELSIF propertyName = "#port" THEN Strings.IntToStr(header.fport, result)
	ELSIF propertyName = "#method" THEN
		CASE header.method OF
			|GetM : COPY("GET", result)
			|HeadM : COPY("HEAD", result)
			|PutM : COPY("PUT", result)
			|PostM : COPY("POST", result)
			|OptionsM : COPY("OPTIONS", result)
		ELSE COPY("unknown", result)
		END
	ELSIF propertyName = "host" THEN COPY(header.host, result)
	ELSIF propertyName = "referer" THEN COPY(header.referer, result)
	ELSIF propertyName = "useragent" THEN COPY(header.useragent, result)
	ELSIF propertyName = "accept" THEN COPY(header.accept, result)
	ELSIF propertyName = "transferencoding" THEN COPY(header.transferencoding, result)
	ELSE
		IF ~GetAdditionalFieldValue(header.additionalFields, propertyName, result) THEN COPY("", result) END
	END
END GetRequestPropertyValue;

(** Currently only for additional fields *)
PROCEDURE SetAdditionalFieldValue*(VAR af: AdditionalField; fieldName, value: ARRAY OF CHAR);
VAR a: AdditionalField;
BEGIN
	IF (af = NIL) THEN NEW(a); af := a
	ELSE
		a := af; WHILE (a.next # NIL) & (a.key # fieldName) DO a := a.next END;
		IF (a.key # fieldName) THEN
			NEW(a.next); a := a.next
		END
	END;
	COPY(fieldName, a.key); COPY(value, a.value)
END SetAdditionalFieldValue;

PROCEDURE GetVersion(VAR ver: ARRAY OF CHAR; VAR maj, min: LONGINT):BOOLEAN;
VAR i: LONGINT;
BEGIN
	i := 0; maj := 0; min := 0;
	IF Match(ver, "HTTP/", i) THEN
		GetInt(i, ver, maj);
		IF ver[i] = "." THEN INC(i) END;
		GetInt(i, ver, min);
		RETURN TRUE
	ELSE RETURN FALSE
	END
END GetVersion;

(** Version - returns TRUE iff the HTTP version specified in h.maj/h.min is bigger or equal to Maj/Min *)
PROCEDURE Version*(VAR h: RequestHeader; Maj, Min: LONGINT): BOOLEAN;
BEGIN
	RETURN (h.maj > Maj) OR ((h.maj = Maj) & (h.min >= Min))
END Version;

PROCEDURE GetMethod*(VAR s: ARRAY OF CHAR; VAR method: LONGINT);
BEGIN
	IF s = "GET" THEN method := GetM
	ELSIF s = "HEAD" THEN method := HeadM
	ELSIF s = "OPTIONS" THEN method := OptionsM
	ELSIF s = "POST" THEN method := PostM
	ELSIF s = "PUT" THEN method := PutM
	ELSIF s = "DELETE" THEN method := DeleteM
	ELSIF s = "TRACE" THEN method := TraceM
	ELSIF s = "CONNECT" THEN method := ConnectM
	(*	WebDAV	*)
	ELSIF s = "PROPFIND" THEN method := PropfindM
	ELSIF s = "PROPPATCH" THEN method := ProppatchM
	ELSIF s = "MKCOL" THEN method := MkcolM
	ELSIF s = "COPY" THEN method := CopyM
	ELSIF s = "MOVE" THEN method := MoveM
	ELSIF s = "LOCK" THEN method := LockM
	ELSIF s = "UNLOCK" THEN method := UnlockM
	(*	DeltaV	*)
	ELSIF s = "VERSION-CONTROL" THEN method := VersionControlM
	ELSIF s = "REPORT" THEN method := ReportM
	ELSIF s = "CHECKOUT" THEN method := CheckoutM
	ELSIF s = "CHECKIN" THEN method := CheckinM
	ELSIF s = "UNCHECKOUT" THEN method := UncheckoutM
	ELSIF s = "MKWORKSPACE" THEN method := MkworkspaceM
	ELSIF s = "UPDATE" THEN method := UpdateM
	ELSIF s = "LABEL" THEN method := LabelM
	ELSIF s = "MERGE" THEN method := MergeM
	ELSIF s = "BASELINE-CONTROL" THEN method := BaselineControlM
	ELSIF s = "MKACTIVITY" THEN method := MkactivityM
	ELSE method := UnknownM
	END
END GetMethod;

PROCEDURE GetMethodName*(code: LONGINT; VAR name: ARRAY OF CHAR);
BEGIN
	CASE code OF
		GetM : COPY("GET", name)
		|HeadM : COPY("HEAD", name);
		|OptionsM : COPY("OPTIONS", name);
		|PostM : COPY("POST", name);
		|PutM : COPY("PUT", name);
		|DeleteM : COPY("DELETE", name);
		|TraceM : COPY("TRACE", name);
		|ConnectM : COPY("CONNECT", name);
		(*	WebDAV	*)
		|PropfindM: COPY("PROPFIND", name);
		|ProppatchM: COPY("PROPPATCH", name);
		|MkcolM: COPY("MKCOL", name);
		|CopyM: COPY("COPY", name);
		|MoveM: COPY("MOVE", name);
		|LockM: COPY("LOCK", name);
		|UnlockM: COPY("UNLOCK", name);
		(*	DeltaV	*)
		|VersionControlM: COPY("VERSION-CONTROL", name);
		|ReportM: COPY("REPORT", name);
		|CheckoutM: COPY("CHECKOUT", name);
		|CheckinM: COPY("CHECKIN", name);
		|UncheckoutM: COPY("UNCHECKOUT", name);
		|MkworkspaceM: COPY("MKWORKSPACE", name);
		|UpdateM: COPY("UPDATE", name);
		|LabelM: COPY("LABEL", name);
		|MergeM: COPY("MERGE", name);
		|BaselineControlM: COPY("BASELINE-CONTROL", name);
		|MkactivityM: COPY("MKACTIVITY", name);
		ELSE COPY("UNKOWN", name)
	END;
END GetMethodName;

PROCEDURE ParseRequest*(VAR in: Streams.Reader; VAR header: RequestHeader; VAR res: LONGINT; log : TFLog.Log);
VAR s: ARRAY 32 OF CHAR; af: AdditionalField; ch :CHAR; wellformed: BOOLEAN;
BEGIN
	header.host[0] := 0X;
	(*in.SkipWhitespace; *)(* optimization PH 2012: to avoid unnecessary work in malformed requests*)
	GetToken(in, s); GetMethod(s, header.method);
	GetToken(in, header.uri);
	GetToken(in, s); 
	wellformed:=GetVersion(s, header.maj, header.min);
	header.host := ""; header.referer := ""; header.useragent := ""; header.accept := ""; header.transferencoding := "";
	header.additionalFields := NIL;
	IF wellformed & EOL(in) & (header.method # UnknownM) & (header.uri # "") THEN
		in.SkipLn();
		IF header.maj >= 1 THEN
			ParseRequestHeaderFields(in,header,res); (* PH120209 disentangled ParseRequestHeaderFields*)
			in.SkipLn;
		ELSE
			IF log # NIL THEN log.Enter; log.String("Unsupported HTTP version :"); log.Int(header.maj, 5); log.Exit END;
			res := VersionNotSupported
		END
	ELSE
		IF EOL(in) THEN in.SkipLn(); END; (*PH Jan 2012*)
		IF log # NIL THEN log.Enter; log.String("Bad request :"); log.Int(header.method, 5); log.Exit END;
		res := BadRequest
	END
END ParseRequest;

PROCEDURE ParseRequestHeaderFields*(VAR in: Streams.Reader; VAR header: RequestHeader; VAR res: LONGINT);
VAR s: ARRAY 32 OF CHAR; af: AdditionalField; ch :CHAR; i:LONGINT;
BEGIN
	i:=0;
	header.additionalFields:=NIL; (*PH 120210*)
	REPEAT
		GetToken(in, s);
		Strings.TrimRight(s, ":");
		IF s = "Host" THEN in.Char(ch); in.Ln(header.host)
		ELSIF s = "Referer" THEN in.Char(ch); in.Ln(header.referer)
		ELSIF s = "User-Agent" THEN in.Char(ch); in.Ln(header.useragent)
		ELSIF s = "Accept" THEN in.Char(ch); in.Ln(header.accept)
		ELSIF s = "Transfer-Encoding" THEN in.Char(ch); in.Ln( header.transferencoding)
		ELSE
			NEW(af); COPY(s, af.key); in.Char(ch); in.Ln(af.value);
			af.next := header.additionalFields; header.additionalFields := af;
			INC(i);
		END;
		IF i > MaxRequestHeaderFields-5 THEN res:=RequestEntityTooLarge; RETURN END; (* hardening against malignant requests*)
	UNTIL (in.res # Streams.Ok) OR in.EOLN();
	res := OK
END ParseRequestHeaderFields;

PROCEDURE ParseReply*(VAR in: Streams.Reader; VAR header: ResponseHeader; VAR res: LONGINT; log : TFLog.Log);
VAR s, sLow: ARRAY 32 OF CHAR; af: AdditionalField;
	i :LONGINT; ch :CHAR; wellformed: BOOLEAN;
BEGIN
	GetToken(in, s); 
	wellformed:=GetVersion(s, header.maj, header.min);
	GetToken(in, s); i := 0; GetInt(i, s, header.statuscode); in.Ln(header.reasonphrase);
	header.server := ""; header.date := ""; header.contenttype := "";
	header.contentlength := -1;
	header.transferencoding := ""; header.additionalFields := NIL;
	header.contentlocation := "";
	IF header.maj >= 1 THEN
		REPEAT
			GetToken(in, s);
			Strings.TrimRight(s, ":");
			(* to understand the Micros**t IIS replies *)
			Strings.Copy(s, 0, 32, sLow);
			Strings.LowerCase(sLow);
			IF sLow = "server" THEN in.Char(ch); in.Ln(header.server)
			ELSIF sLow = "date" THEN in.Char(ch);in.Ln(header.date)
			ELSIF sLow = "location" THEN in.Char(ch);in.Ln(header.location)
			ELSIF sLow = "content-type" THEN in.Char(ch); in.Ln(header.contenttype)
			ELSIF sLow = "content-length" THEN in.Char(ch); in.Ln(s); Strings.StrToInt(s, header.contentlength)
			ELSIF sLow = "content-location" THEN in.Char(ch);in.Ln(header.contentlocation)
			ELSIF sLow = "transfer-encoding" THEN in.Char(ch); in.Ln(header.transferencoding)
			ELSIF sLow = "last-modified" THEN in.Char(ch);in.Ln(header.lastmodified)
			ELSE
				NEW(af); COPY(s, af.key); in.Char(ch); in.Ln(af.value);
				af.next := header.additionalFields; header.additionalFields := af
			END;
		UNTIL (in.res # Streams.Ok) OR in.EOLN();
		in.SkipLn();
		res := OK
	ELSE
		IF log # NIL THEN log.Enter; log.String("Unsupported HTTP version :"); log.Int(header.maj, 5); log.Exit END;
		res := VersionNotSupported
	END;
END ParseReply;

PROCEDURE ModifyReply*(VAR in: Streams.Reader; VAR header: ResponseHeader; VAR res: LONGINT; log : TFLog.Log);
VAR s, sLow: ARRAY 32 OF CHAR; af: AdditionalField;
	i :LONGINT; ch :CHAR;
BEGIN
	REPEAT
		GetToken(in, s);
		Strings.TrimRight(s, ":");
		(* to understand the Microsoft IIS replies *)
		Strings.Copy(s, 0, 32, sLow);
		Strings.LowerCase(sLow);
		IF sLow = "server" THEN in.Char(ch); in.Ln(header.server)
		ELSIF sLow = "date" THEN in.Char(ch);in.Ln(header.date)
		ELSIF sLow = "location" THEN in.Char(ch);in.Ln(header.location)
		ELSIF sLow = "content-type" THEN in.Char(ch); in.Ln(header.contenttype)
		ELSIF sLow = "content-length" THEN in.Char(ch); in.Ln(s); Strings.StrToInt(s, header.contentlength)
		ELSIF sLow = "content-location" THEN in.Char(ch);in.Ln(header.contentlocation)
		ELSIF sLow = "transfer-encoding" THEN in.Char(ch); in.Ln(header.transferencoding)
		ELSIF sLow = "last-modified" THEN in.Char(ch);in.Ln(header.lastmodified)
		ELSE
			NEW(af); COPY(s, af.key); in.Char(ch); in.Ln(af.value); (*! to do: check if a field already exists -> replace instead of append *)
			af.next := header.additionalFields; header.additionalFields := af
		END;
	UNTIL (in.res # Streams.Ok) OR in.EOLN();
	in.SkipLn();
	res := OK
END ModifyReply;

PROCEDURE LogRequestHeader*(log : TFLog.Log; VAR header : RequestHeader);
VAR s : ARRAY 32 OF CHAR; x: AdditionalField;
BEGIN
	log.Enter;
	log.String("BEGIN HTTP-Request Header information ("); log.TimeStamp; log.String(")"); log.Ln;
	log.String(" HTTP request from "); IP.AdrToStr(header.fadr, s); log.String(s); log.String(" : "); log.Int(header.fport, 5); log.Ln;
	log.String("Request: ");
	GetMethodName(header.method, s); log.String(s);
	log.String(" "); log.String(header.uri); log.Ln;
	IF header.host # "" THEN log.String("Host: "); log.String(header.host); log.Ln END;
	IF header.referer # "" THEN log.String("Referer: "); log.String(header.referer); log.Ln END;
	IF header.useragent # "" THEN log.String("User-Agent: "); log.String(header.useragent); log.Ln END;
	IF header.accept # "" THEN log.String("Accept: "); log.String(header.accept); log.Ln END;
	x := header.additionalFields;
	WHILE x # NIL DO
		log.String(x.key); log.String(": "); log.String(x.value); log.Ln;
		x := x.next
	END;
	log.String("END HTTP-Request Header information"); log.Ln; log.Ln;
	log.Exit;
END LogRequestHeader;

PROCEDURE LogResponseHeader*(log : TFLog.Log; VAR header : ResponseHeader);
VAR x: AdditionalField;
BEGIN
	log.Enter;
	log.String("BEGIN HTTP-Reply Header information ("); log.TimeStamp; log.String(")"); log.Ln;
	log.String("Status Code: "); log.Int(header.statuscode, 5); log.String(" Reason: "); log.String(header.reasonphrase); log.Ln;
	IF header.server # "" THEN log.String("Server: "); log.String(header.server); log.Ln END;
	IF header.date # "" THEN log.String("Date: "); log.String(header.date); log.Ln END;
	IF header.location # "" THEN log.String("Location: "); log.String(header.location); log.Ln END;
	IF header.contenttype # "" THEN log.String("Content-Type: "); log.String(header.contenttype); log.Ln END;
	IF header.contentlength # 0 THEN log.String("Content-Length: "); log.Int(header.contentlength, 0); log.Ln END;
	IF header.contentlocation # "" THEN log.String("Content-Location: "); log.String(header.contentlocation); log.Ln END;
	IF header.transferencoding # "" THEN log.String("Transfer-Encoding: "); log.String(header.transferencoding); log.Ln END;
	IF header.lastmodified # "" THEN log.String("Last-Modified: "); log.String(header.lastmodified); log.Ln END;
	x := header.additionalFields;
	WHILE x # NIL DO
		log.String(x.key); log.String(": "); log.String(x.value); log.Ln;
		x := x.next
	END;
	log.String("END HTTP-Reply Header information"); log.Ln; log.Ln;
	log.Exit;
END LogResponseHeader;

PROCEDURE WriteRequestLine*(s: Streams.Writer; maj, min : LONGINT; method : LONGINT; uri, host : ARRAY OF CHAR);
VAR name: ARRAY 32 OF CHAR;
BEGIN
	GetMethodName(method, name);
	IF name = "UNKNOWN" THEN RETURN ELSE s.String(name) END;
	s.String(" "); s.String(uri); s.String(" ");
	s.String("HTTP/"); s.Int(maj, 1); s.String("."); s.Int(min, 1);
	s.Ln();
	IF host # "" THEN s.String("Host: "); s.String(host); s.Ln() END
END WriteRequestLine;


PROCEDURE GetReasonPhrase*(code: LONGINT; VAR phrase: ARRAY OF CHAR);
BEGIN
	(*	Informational	*)
	IF (code =  Continue) THEN COPY("Continue", phrase)
	ELSIF (code = SwitchingProtocols) THEN COPY("Switching Protocols", phrase)
	ELSIF (code =  Processing) THEN COPY("Processing", phrase)
	(*	successful	*)
	ELSIF (code = OK) THEN COPY("OK", phrase);
	ELSIF (code = Created) THEN COPY("Created", phrase)
	ELSIF (code = Accepted) THEN COPY("Accepted", phrase)
	ELSIF (code = NonAuthoritativeInformation) THEN COPY("Non-Authoritative Information", phrase)
	ELSIF (code = NoContent) THEN COPY("No Content", phrase)
	ELSIF (code = ResetContent) THEN COPY("Reset Content", phrase)
	ELSIF (code = PartialContent) THEN COPY("Partial Content", phrase)
	ELSIF (code = MultiStatus) THEN COPY("Multi-Status", phrase)
	(*	Redirection	*)
	ELSIF (code = MultipleChoices) THEN COPY("Multiple Choices", phrase)
	ELSIF (code = ObjectMoved) THEN COPY("Object moved", phrase)
	ELSIF (code = ObjectMovedTemporarily) THEN COPY("Object Moved Temporarily", phrase)
	ELSIF (code = SeeOther) THEN COPY("See Other", phrase)
	ELSIF (code = NotModified) THEN COPY("Not modified", phrase)
	ELSIF (code = UseProxy) THEN COPY("Use Proxy", phrase)
	ELSIF (code = TemporaryRedirect) THEN COPY("Temporary Redirect", phrase)
	(*	Client Error	*)
	ELSIF (code = BadRequest) THEN COPY("Bad request", phrase)
	ELSIF (code = Unauthorized) THEN COPY("Unauthorized", phrase)
	ELSIF (code = PaymentRequired) THEN COPY("Payment Required", phrase)
	ELSIF (code = Forbidden) THEN COPY("Forbidden", phrase)
	ELSIF (code = NotFound) THEN COPY("Not found", phrase)
	ELSIF (code = MethodNotAllowed) THEN COPY("Method Not Allowed", phrase)
	ELSIF (code = NotAcceptable) THEN COPY("Not Acceptable", phrase)
	ELSIF (code = ProxyAuthenticationRequested) THEN COPY("Proxy Authentication Requested", phrase)
	ELSIF (code = RequestTimeout) THEN COPY("Request Timeout", phrase)
	ELSIF (code = Conflict) THEN COPY("Conflict", phrase)
	ELSIF (code = Gone) THEN COPY("Gone", phrase)
	ELSIF (code = LengthRequired) THEN COPY("Length required", phrase)
	ELSIF (code = PreconditionFailed) THEN COPY("Precondition failed", phrase)
	ELSIF (code = RequestEntityTooLarge) THEN COPY("Request Entity Too Large", phrase)
	ELSIF (code = RequestURITooLong) THEN COPY("Request URI too long", phrase)
	ELSIF (code = UnsupportedMediaType) THEN COPY("Unsupported Media Type", phrase)
	ELSIF (code = RequestedRangeNotSatisfiable) THEN COPY("Requested Range Not Satisfiable", phrase)
	ELSIF (code = ExpectationFailed) THEN COPY("Expectation Failed", phrase)
	ELSIF (code = UnprocessableEntity) THEN COPY("Unprocessable Entity", phrase)
	ELSIF (code = Locked) THEN COPY("Locked", phrase)
	ELSIF (code = FailedDependency) THEN COPY("Failed Dependency", phrase)
	(*	Server Error	*)
	ELSIF (code = InternalServerError) THEN COPY("Internal server error", phrase)
	ELSIF (code = NotImplemented) THEN COPY("Operation not implemented", phrase)
	ELSIF (code = BadGateway) THEN COPY("Bad Gateway", phrase)
	ELSIF (code = ServiceUnavailable) THEN COPY("Service Unavailable", phrase)
	ELSIF (code = GatewayTimeout) THEN COPY("Gateway Timeout", phrase)
	ELSIF (code = VersionNotSupported) THEN COPY("HTTP Version not supported", phrase)
	ELSIF (code = InsufficientStorage) THEN COPY("Insufficient Storage", phrase)
	ELSE COPY("Unknown Status Code", phrase) (* Was "HTTP server error" *)
	END;
END GetReasonPhrase;

PROCEDURE WriteStatus*(VAR h: ResponseHeader; VAR dst: Streams.Writer);
BEGIN
	dst.String("HTTP/"); dst.Int(h.maj, 1); dst.String("."); dst.Int(h.min, 1);
	dst.String(" ");dst.Int(h.statuscode, 1); dst.String(" ");
	GetReasonPhrase(h.statuscode, h.reasonphrase);
	dst.String(h.reasonphrase); dst.Ln();
	dst.String("Server: "); dst.String(h.server); dst.Ln()
END WriteStatus;

(* precondition: header statuscode and header reasonphrase are already filled in, e.g. by use of WriteStatus() *)
PROCEDURE WriteHTMLStatus*(VAR h: ResponseHeader; dst: Streams.Writer);
VAR reasonphrase: ARRAY 64 OF CHAR;
BEGIN
	dst.String(DocType); dst.Ln;
	dst.String("<html><head><title>"); dst.Int(h.statuscode,0); dst.String(" - "); dst.String(h.reasonphrase); dst.String("</title></head>");
	dst.String("<body>HTTP "); dst.Int(h.statuscode,0); dst.String(" - "); dst.String(h.reasonphrase); dst.String("<hr><address>");
	dst.String(h.server); dst.String( "</address></body></html>"); dst.Ln;
END WriteHTMLStatus;

PROCEDURE SendResponseHeader*(VAR h: ResponseHeader; VAR dst: Streams.Writer);
VAR s: ARRAY 32 OF CHAR; af: AdditionalField;
BEGIN
	WriteStatus(h, dst);
	Strings.FormatDateTime("www, dd mmm yyyy, hh:nn:ss GMT", Dates.Now(), s);
	dst.String("Date: "); dst.String(s); dst.Ln();
	IF (h.statuscode # NotModified) THEN
		IF (h.location # "") THEN
			dst.String("Location: "); dst.String(h.location); dst.Ln()
		END;
		dst.String("Content-Type: "); dst.String(h.contenttype); dst.Ln();
		IF (h.contentlength >= 0) THEN
			dst.String("Content-Length: "); dst.Int( h.contentlength, 1); dst.Ln()
		END;
		IF (h.contentlocation # "") THEN
			dst.String("Content-Location: "); dst.String(h.contentlocation); dst.Ln()
		END;
		IF (h.transferencoding # "") THEN
			dst.String("Transfer-Encoding: "); dst.String(h.transferencoding); dst.Ln()
		END;
		IF (h.lastmodified # "") THEN
			dst.String("Last-Modified: ");dst.String(h.lastmodified); dst.Ln()
		END;
		af := h.additionalFields;
		WHILE (af # NIL) DO
			dst.String(af.key); dst.String(": "); dst.String(af.value); dst.Ln();
			af := af.next
		END
	END;
	dst.Ln()
END SendResponseHeader;

PROCEDURE SendStatusReply*(code:LONGINT; VAR request: RequestHeader; VAR reply: ResponseHeader; VAR out: Streams.Writer);
VAR w : Streams.Writer; 
	chunker: ChunkedOutStream;
BEGIN
	reply.statuscode := code; 
	GetReasonPhrase(code, reply.reasonphrase);
	reply.contenttype := "text/html; charset=UTF-8";
	NEW(chunker, w, out, request, reply);
	SendResponseHeader(reply, out); 
	WriteHTMLStatus(reply, w); 
	w.Update;
	chunker.Close
END SendStatusReply;

PROCEDURE GetPath*(VAR url, path : ARRAY OF CHAR);
VAR i, j : LONGINT;
	protocol : ARRAY 8 OF CHAR;
BEGIN
	IF Strings.Length(url) < 7 THEN COPY(url, path)
	ELSE
		Strings.Copy(url, 0, 7, protocol); Strings.UpperCase(protocol);
		i := 0;
		IF protocol = "HTTP://" THEN i := 7
		ELSIF protocol = "HTTPS:/" THEN i := 8
		END;
		IF i > 0 THEN
			WHILE  (url[i] # "/") & (url[i] # 0X) DO INC(i) END;
			IF url[i] # 0X THEN j := 0; REPEAT path[j] := url[i]; INC(i); INC(j) UNTIL url[i] = 0X
			ELSE path := "/"
			END
		ELSE COPY(url, path)
		END
	END
END GetPath;

PROCEDURE SplitHTTPAdr*(url : ARRAY OF CHAR; VAR host, path: ARRAY OF CHAR; VAR port: LONGINT): BOOLEAN;
VAR i, j : LONGINT;
BEGIN
	(*assuming HTTP or HTTPS*)
	
	IF (LEN(url)>7) &(url[4] = ":") & (url[5] = "/") & (url[6] = "/") THEN i:=7; port:=HTTPPort;
	ELSIF (LEN(url)>8) & (url[5] = ":") & (url[6] = "/") & (url[7] = "/") THEN i:=8; port:=HTTPSPort;
	ELSE RETURN FALSE
	END;
	
	(* get host *)
	j := 0;
	WHILE (url[i] # ":") & (url[i] # "/") & (url[i] # 0X) DO
		IF j < LEN(host) - 1 THEN host[j] := url[i] ELSE RETURN FALSE END;
		 INC(i); INC(j);
		 IF i = LEN(url) THEN RETURN FALSE END
	END;
	host[j] := 0X;
	(* get port *)
	IF url[i] = ":" THEN
		port := 0;
		INC(i);
		WHILE (i < LEN(url)) & (ORD(url[i]) >= ORD("0")) & (ORD(url[i]) <= ORD("9"))  DO
			port := port * 10 + (ORD(url[i]) - ORD("0"));
			INC(i)
		END
	END;
	j := 0;
	WHILE (i < LEN(url)) & (url[i] # 0X) DO
		IF j < LEN(host) - 1 THEN path[j] := url[i] ELSE RETURN FALSE END;
		 INC(i); INC(j);
		 IF i = LEN(url) THEN RETURN FALSE END
	END;
	path[j] := 0X;
	RETURN TRUE
END SplitHTTPAdr;

END WebHTTP.



SystemTools.FreeDownTo WebHTTP~