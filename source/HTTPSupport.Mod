MODULE HTTPSupport; (** AUTHOR "Luc Blaeser/cs"; PURPOSE "HTTP Webserver Support Module for HTTP-Request Handling";
 contains also code parts from "CSHTTPSupport" by "cs" *)
 (*PH2012 fix behaviour of wellformed POST with urlencoding in body and valid Content-Length*)

IMPORT WebHTTP, Streams, Strings, TFClasses, KernelLog;

TYPE
	HTTPVariable* = POINTER TO RECORD
		name*: ARRAY 1024 OF CHAR;
		value*: ARRAY 1024 OF CHAR;
		isUrlEncoded*: BOOLEAN (** true iff url encoded if the HTTP request *)
	END;

	(** encapsulates the HTTP request header and the variables from POST ord GET *)
	HTTPRequest* = OBJECT
		VAR
			header*: WebHTTP.RequestHeader;
			shortUri*: ARRAY 4096 OF CHAR; (** uri without variables *)

			variables*: TFClasses.List; (** List of HTTPVariable *)

		PROCEDURE &Init*(VAR requestHeader: WebHTTP.RequestHeader; bodyReader: Streams.Reader);
			VAR pos: LONGINT; restLength: LONGINT; uriReader : Streams.StringReader; uriRest : Strings.String;
				contentType: ARRAY 40 OF CHAR;
		BEGIN
			NEW(variables);
			header := requestHeader;
			(* look for variables inURL *)
			pos := Strings.Pos("?", header.uri);
			IF (pos > 0) THEN
				Strings.Copy(header.uri, 0, pos, shortUri);

				restLength := Strings.Length(header.uri)-pos;
				NEW(uriRest, restLength);
				Strings.Copy(header.uri, pos+1, restLength, uriRest^);
				NEW(uriReader, restLength); uriReader.Set(uriRest^);
				ParseVariables(uriReader, TRUE)
			ELSE
				COPY(header.uri, shortUri)
			END;
			(* look for variables in body *)
			IF (requestHeader.method = WebHTTP.PostM) THEN
				IF (WebHTTP.GetAdditionalFieldValue(requestHeader.additionalFields, "Content-Type", contentType)) THEN
					IF (contentType = "application/x-www-form-urlencoded") & (bodyReader # NIL)THEN
						(* look for variables in body *)
						ParseVariables(bodyReader, FALSE)
					END
				END
			END
		END Init;

		PROCEDURE ParseVariables(r: Streams.Reader; isUrlEncoded : BOOLEAN);
			VAR var: HTTPVariable; ch: CHAR; pos, i, size: LONGINT; close: BOOLEAN; s: ARRAY 32 OF CHAR;
				enc: BOOLEAN; (* true iff encoded *)

			PROCEDURE Next;
					VAR c0, c1: CHAR; val : LONGINT;
			BEGIN
				ch := r.Get(); INC(pos); enc := FALSE;
				IF ch = "%" THEN (* next byte is encoded *)
					IF (HasMoreData()) THEN c0 := r.Get(); INC(pos) ELSE c0 := 0X END;
					IF (HasMoreData()) THEN c1 := r.Get(); INC(pos) ELSE c1 := 0X END;
					(* first nibble *)
					val := 0; IF (c0 >='0') & (c0 <='9') THEN val := (ORD(c0) - ORD('0')) * 16 END;
					IF (CAP(c0) >='A') & (CAP(c0) <='F') THEN val := (ORD(CAP(c0)) - ORD('A') + 10) * 16 END;
					(* second nibble *)
					IF (c1 >='0') & (c1 <='9') THEN val := val + ORD(c1) - ORD('0') END;
					IF (CAP(c1) >='A') & (CAP(c1) <='F') THEN val := val + ORD(CAP(c1)) - ORD('A')+10 END;
					ch := CHR(val); enc := TRUE
				ELSIF ch = '+' THEN ch := ' '
				END
			END Next;

			PROCEDURE HasMoreData() : BOOLEAN;
			BEGIN
				RETURN (close & (r.Available() > 0)) OR (~close & (pos < size)) (*PH 2012 fix behaviour of urlencoded POST with Content-Length *)
			END HasMoreData;

		BEGIN
			pos := 0;
			IF (~isUrlEncoded & WebHTTP.HasAdditionalField(header.additionalFields, "Content-Length") 
				& WebHTTP.GetAdditionalFieldValue(header.additionalFields, "Content-Length", s))THEN
				Strings.StrToInt(s, size); close := FALSE;
			ELSE
				close := TRUE;
			END;
			WHILE (HasMoreData()) DO
				NEW(var); var.isUrlEncoded := isUrlEncoded;
				i := 0; Next;
				WHILE ((HasMoreData()) & (enc OR (ch # "=")) & (i < LEN(var.name)-1)) DO
					var.name[i] := ch; INC(i); Next
				END;
				IF (i >= LEN(var.name)-1) THEN
					KernelLog.String("Variable name too long in HTTP request."); KernelLog.Ln;
					WHILE ((HasMoreData()) & (enc OR (ch # "="))) DO Next END
				ELSIF (ch # "=") THEN
					var.name[i] := ch; INC(i)
				END;
				var.name[i] := 0X; (* Strings.LowerCase(var.name); What the hell... why case in-sensitive *)
				i := 0;
				IF (HasMoreData()) THEN Next END;
				WHILE ((HasMoreData()) & (enc OR (ch # "&")) & (i < LEN(var.value)-1)) DO
					var.value[i] := ch; INC(i); Next
				END;
				IF (i >= LEN(var.value)-1) THEN
					KernelLog.String("Variable value too long in HTTP request."); KernelLog.Ln;
					WHILE ((HasMoreData()) & (enc OR (ch # "&"))) DO Next END
				ELSIF (ch # "&") THEN
					var.value[i] := ch; INC(i)
				END;
				var.value[i] := 0X;
				variables.Add(var);
			END;
		END ParseVariables;

		(** returns NIL if variable is not present *)
		PROCEDURE GetVariableByName*(name: ARRAY OF CHAR) : HTTPVariable;
		VAR p: ANY; var: HTTPVariable; i: LONGINT;
		BEGIN
			variables.Lock;
			FOR i := 0 TO variables.GetCount()-1 DO
				p := variables.GetItem(i); var := p(HTTPVariable); (* var # NIL *)
				IF (var.name = name) THEN
					variables.Unlock;
					RETURN var
				END
			END;
			variables.Unlock;
			RETURN NIL
		END GetVariableByName;

		PROCEDURE WriteEncodedUri*(encUri: ARRAY OF CHAR);
		VAR encStr: ARRAY 1024 OF CHAR; p: ANY; var: HTTPVariable; i : LONGINT;
		BEGIN
			COPY(shortUri, encUri);
			variables.Lock;
			FOR i := 0 TO variables.GetCount()-1 DO
				p := variables.GetItem(i); var := p(HTTPVariable); (* var # NIL *)
				IF (i = 0) THEN
					Strings.Append(encUri, "?")
				ELSE
					Strings.Append(encUri, "&")
				END;
				HTTPEncode(var.name, encStr);
				Strings.Append(encUri, encStr);
				Strings.Append(encUri, "=");
				HTTPEncode(var.value, encStr);
				Strings.Append(encUri, encStr)
			END;
			variables.Unlock
		END WriteEncodedUri;


	END HTTPRequest;

	PROCEDURE RemoveVariablesFromURI*(olduri: ARRAY OF CHAR; VAR newuri: ARRAY OF CHAR);
	VAR pos: LONGINT;
	BEGIN
		pos := Strings.Pos("?", olduri);
		IF (pos > 0) THEN
			Strings.Copy(olduri, 0, pos, newuri)
		ELSE
			COPY(olduri, newuri)
		END
	END RemoveVariablesFromURI;

	(** HTTPEncode in by escaping illegal chars , author: "cs" *)
	PROCEDURE HTTPEncode*(in: ARRAY OF CHAR; VAR enc: ARRAY OF CHAR);
	VAR i,o: LONGINT;
		ch: LONGINT;

		PROCEDURE ToHex(in: CHAR;VAR c1: CHAR; VAR c2: CHAR);
			VAR i: INTEGER;
		BEGIN
			i := ORD(in) DIV 16;
			IF i < 10 THEN
				c1 := CHR(30H + i)
			ELSE
				c1 := CHR(37H + i)
			END;
			i := ORD(in) MOD 16;
			IF i < 10 THEN
				c2 := CHR(30H + i)
			ELSE
				c2 := CHR(37H + i)
			END
		END ToHex;

		BEGIN
			o := 0;
			FOR i:= 0 TO Strings.Length(in)-1 DO
				ch := ORD(in[i]);
				(* RFC2396 lowalpha *)
				IF (ch >= 61H ) & (ch <= 7AH) OR
					(* RFC2396 upalpha *)
					(ch >= 41H) & (ch <= 5AH) OR
					(* RFC2396 digit *)
					(ch >= 30H) & (ch <= 39H) OR
					(ch = 2DH) OR (* - *)
					(ch = 5FH) OR (* underscore *)
					(ch = 2EH) OR (* . *)
					(ch = 21H) OR (* ! *)
					(ch = 7EH) OR (* ~ *)
					(ch = 2AH) OR (* * *)
					(ch = 27H) OR (* ' *)
					(ch = 28H) OR (* ( *)
					(ch = 29H) (* ) *)
				THEN
					enc[o]:= CHR(ch); (* transparent *)
					INC(o)
				ELSE (* encode hex *)
					enc[o] := 25X; (* % *)
					ToHex(CHR(ch),enc[o+1],enc[o+2]);
					INC(o,3)
				END
			END;
		enc[o] := 0X
	END HTTPEncode;


END HTTPSupport.

System.Free HTTPSupport ~





[RFC3261] Section 25.1 defines the syntax for the WWW-Authenticate and Proxy-Authenticate header fields as follows.

Proxy-Authenticate  = "Proxy-Authenticate" HCOLON challenge
WWW-Authenticate    = "WWW-Authenticate" HCOLON challenge

challenge           = ("Digest" LWS digest-cln *(COMMA digest-cln))
                      / other-challenge

This protocol defines the following extensions.

challenge           = ("Digest" LWS digest-cln *(COMMA digest-cln))
                      / "NTLM" LWS msspi-cln *(COMMA msspi-cln)
                      / "Kerberos" LWS msspi-cln *(COMMA msspi-cln)
                      / "TLS-DSK" LWS msspi-cln *(COMMA msspi-cln)
                      / other-challenge
digest-cln          = realm / domain / nonce
                      / opaque / stale / algorithm
                      / qop-options / auth-param
algorithm           = "algorithm" EQUAL 
                      ( "MD5" / "MD5-sess"/ "SHA256-sess" / token )
msspi-cln           = realm / opaque 
                      / targetname / gssapi-data / version / sts-uri
targetname          = "targetname" EQUAL target-value
target-value        = DQUOTE ( ntlm-target-val 
                      / ( "sip/" kerberos-target-val)
                      / tls-dsk-target-val ) DQUOTE
ntlm-target-val     = token
kerberos-target-val = token      
tls-dsk-target-val  = token
gssapi-data         = "gssapi-data" EQUAL gssapi-data-value
gssapi-data-value   = quoted-string
version             = "version" EQUAL version-value
version-value       = 1*DIGIT
sts-uri             = "sts-uri" EQUAL DQUOTE absoluteURI DQUOTE


