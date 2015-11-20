MODULE TLS;	(** AUTHOR "F.N."; PURPOSE "RFC 2246: Transport Layer Security v1.0"; *)
(*
	05.2014 -- Timothée Martiel -- Implemented TLS client connection.
*)
IMPORT
	TCP, Streams, Files, IP, KernelLog , Pipes, Kernel, Clock, BIT,
	Ciphers := CryptoCiphers, Utils := CryptoUtils, HMAC := CryptoHMAC,
	CryptoMD5, CryptoSHA1, CryptoRSA, CryptoBigNumbers, PKCS1, X509;

CONST
	(* debugging *)
	Trace = TRUE;

	(** tlsStates *)
	ServerHandshake* = 12;
	ClientHandshake* = 13;

	(* client and server common handshake states *)
	NotAValidHandshakeState = 100; HandshakeFinished = 101; GenerateChangeCipherSpec = 102; AwaitFinished = 103;

	(* server-side handshake states *)
	AwaitClientHello = 201; GenerateServerHello = 202; GenerateServerHelloDone = 203; AwaitClientKeyExchange = 204;
	AwaitChangeSpec = 205; GenerateHelloWithResumption = 210;
	AwaitChangeSpecWithResumption = 211; AwaitFinishedWithResumption = 212;

	(* client-side handshake states *)
	GenerateClientHello = 300; AwaitServerHello = 301; AwaitCertificate = 302; AwaitServerHelloDone = 303; GenerateClientKeyExchange = 304;

	(** available cipher suites *)
	TlsRsaWithNullMd5* = 0001H; TlsRsaWithNullSha* = 0002H; TlsRsaWithRc4128Md5* = 0004H;
	TlsRsaWithRc4128Sha* = 0005H; TlsRsaWithIdeaCbcSha* = 0007H; TlsRsaWithDesCbcSha* = 0009H;
	TlsRsaWith3DesEdeCbcSha* = 000AH;
	(*	not supported
	TlsDhDssWithDesCbcSha* = 000CH; TlsDhDssWith3DesEdeCbcSha* = 000DH;
	TlsDhRsaWithDesCbcSha* = 000FH; TlsDhRsaWith3DesEdeCbcSha* = 0010H;
	TlsDhAnonWithRc4128Md5* = 0018H; TlsDhAnonWithDesCbcSha* = 001AH; TlsDhAnonWith3DesEdeCbcSha* = 001BH;
	*)

	(** record layer content type *)
	ChangeCipherSpec* = 20; Alert* = 21; Handshake* = 22; ApplicationData* = 23; SSLv2ClientHello* = 128;

	(** handshake message types *)
	HelloRequest* = 0; ClientHello* = 1; ServerHello* = 2; Certificate* = 11;
	ServerKeyExchange* = 12; CertificateRequest* = 13; ServerHelloDone* = 14; CertificateVerify* = 15;
	ClientKeyExchange* = 16; Finished* = 20;
	V2ClientHello* = 30;

	(* alert levels *)
	Warning = 1; Fatal = 2;

	(* alert types *)
	NoError = -1;
	CloseNotify = 0; UnexpectedMessage = 10; BadRecordMac = 20; DecryptionFailed = 21;
	RecordOverflow = 22; DecompressionFailure = 30; HandshakeFailure = 40; NoCertificate = 41; (* only SSL 3.0 *)
	BadCertificate = 42; UnsupportedCertificate = 43; CertificateRevoked = 44; CertificateExpired = 45;
	CertificateUnknown = 46; IllegalParameter = 47; UnknownCA = 48; AccessDenied = 49;
	DecodeError = 50; DecryptError = 51; ExportRestriction = 60; ProtocolVersion = 70;
	InsufficientSecurity = 71; InternalError = 80; UserCancelled = 90; NoRenegotiation = 100; UnsupportedExtension=110;

	(** error numbers *)
	Ok* = 0; TLSHandshakeAborted* = 2;

	Suites* = 20;
	Buflen = 18500;
	MaxPHashKernelLogput = 1024;
	MaxKeyBlock = 120;
	MaxPHashSeed = 128;
	MaxPlaintextLength = 16384; 	(* 2^14 *)
	MaxCompressedLength = 17408;	(* 2^14 + 2^10 *)
	MaxCiphertextLength = 18432;	(* 2^14 + 2^11 *)
	SessionIdLength = 16;
	SessionHashtableSize = 1023;	(* 256 * 456 *)
	SessionCleanUpInterval = 60;	(* seconds *)
	DefaultSessionLifetime = 3600; (* seconds *)


TYPE
	SecurityParameters = OBJECT
		VAR
			cipherSuite, cipherKeySize: LONGINT;	(* size in bytes *)
			clientRandom, serverRandom: ARRAY 32 OF CHAR;
	END SecurityParameters;

	ConnectionState = OBJECT
		VAR
			cipher: Ciphers.Cipher;
			mac: HMAC.HMac;
			recordSeq: DoubleLong;
			cipherKey: ARRAY 24 OF CHAR;
			iv: ARRAY 8 OF CHAR;
			macSecret: ARRAY 20 OF CHAR;

		PROCEDURE & Init*;
		BEGIN
			NEW( recordSeq)
		END Init;
	END ConnectionState;

	(*
	DoubleLong = OBJECT	(* 64-bit number, the initial value is -1 *)
		VAR num -: ARRAY 2 OF LONGINT;	(* 64 bits, msb: num[ 0 ] *)

		PROCEDURE & Init*;
		BEGIN
			num[ 0 ] := 0;	num[ 1 ] := -1
		END Init;

		PROCEDURE Inc;
		BEGIN
			ASSERT( ( num[ 0 ] < MAX( LONGINT ) ) OR ( num[ 1 ] < MAX( LONGINT ) ) );
			IF num[ 1 ] < MAX( LONGINT ) THEN
				INC( num[ 1 ] );
				RETURN
			ELSE
				num[ 1 ] := 0;
				INC( num[ 0 ] )
			END
		END Inc;

		(* write the current value of num in big-endian to data starting at ofs *)
		PROCEDURE GetBytes( VAR data: ARRAY OF CHAR; ofs: LONGINT );
		BEGIN
			ASSERT( ofs < LEN( data ) - 7 );
			data[ ofs ] := CHR( num[ 0 ] DIV ( 256*256*256 ) );
			data[ ofs + 1 ] := CHR( num[ 0 ] DIV ( 256*256 ) );
			data[ ofs + 2 ] := CHR( num[ 0 ] DIV 256 );
			data[ ofs + 3 ] := CHR( num[ 0 ] );
			data[ ofs + 4 ] := CHR( num[ 1 ] DIV ( 256*256*256 ) );
			data[ ofs + 5 ] := CHR( num[ 1 ] DIV ( 256*256 ) );
			data[ ofs + 6 ] := CHR( num[ 1 ] DIV 256 );
			data[ ofs + 7 ] := CHR( num[ 1 ] )
		END GetBytes;
	END DoubleLong;
	*)  (*! contains a large gap between 80000000 and 100000000. g.f.	*)
	
	
	DoubleLong = OBJECT	(* 64-bit counter, the initial value is -1 *)
		VAR 
			numH, numL: LONGINT;
	
		PROCEDURE &Init;
		BEGIN
			numH := -1; numL := -1
		END Init;
		
		PROCEDURE Inc;
		BEGIN
			IF numL # -1 THEN  INC( numL )
			ELSIF numH = -1 THEN  numH := 0;  numL := 0
			ELSE  INC( numH );  numL := 0
			END
		END Inc;
		
		(* write the current value of num in big-endian to buf starting at ofs *)
		PROCEDURE GetBytes( VAR buf: ARRAY OF CHAR;  ofs: LONGINT );
		VAR p, val: LONGINT;
		BEGIN
			p := ofs + 7;  val := numL;
			REPEAT
				buf[p] := CHR( val MOD 256 );  
				IF p = ofs + 4 THEN  val := numH  ELSE  val := val DIV 256  END;
				DEC( p )
			UNTIL p < ofs;
		END GetBytes;
	
	END DoubleLong;
	

	(* data expansion function as defined in rfc2246, section 5 *)
	PHash = OBJECT
		VAR hMac: HMAC.HMac;

		(* initialization of a PHash object using h as internal hashing-function *)
		PROCEDURE & Init*( hashname: ARRAY OF CHAR );
		BEGIN
			NEW( hMac, hashname );
		END Init;

		PROCEDURE Expand( VAR secret, seed, outbuf: ARRAY OF CHAR; secretLen, seedLen, outLen: LONGINT );
			VAR
				a: ARRAY 2 * MaxPHashSeed OF CHAR;
				i, iterations: LONGINT;
		BEGIN
			ASSERT( seedLen <= ( MaxPHashSeed  ) );
			ASSERT( outLen <= ( MaxPHashKernelLogput ) );
			hMac.Initialize( secret, secretLen );
			hMac.Update( seed, 0, seedLen );
			hMac.GetMac( a, 0 );	(* a( 1 ) *)
					FOR i := 0 TO seedLen-1 DO		a[ hMac.size + i ] := seed[ i ]		END;	(* concatenate seed to a( 1 ) *)
			iterations := ( outLen DIV hMac.size ) + 1;
			(* iteration *)
			FOR i := 0 TO iterations - 1 DO
				hMac.Initialize( secret, secretLen );
				hMac.Update( a, 0, hMac.size+seedLen );
				hMac.GetMac( outbuf, i*hMac.size );
				(* increment a *)
				hMac.Initialize( secret, secretLen );
				hMac.Update( a, 0, hMac.size );
				hMac.GetMac( a, 0 )
			END
		END Expand;
	END PHash;

	(* pseudorandom stream as defined in rfc2246, section 5 *)
	PRF = OBJECT
		VAR pMD5, pSHA: PHash;

		PROCEDURE & Init*;
		BEGIN
			NEW( pMD5, "CryptoMD5" );	NEW( pSHA, "CryptoSHA1" )
		END Init;

		PROCEDURE GetBytes( VAR secret, seed, outbuf: ARRAY OF CHAR; label: ARRAY OF CHAR; secretLen, seedLen, outLen: LONGINT );
			VAR
				md5Result, shaResult: ARRAY MaxKeyBlock OF CHAR;
				pSeed, s1, s2: ARRAY 128 OF CHAR;
				i, j, l: LONGINT;
		BEGIN
			(* pseed := label::seed *)
			l :=  LEN( label ) - 1;
			FOR i := 0 TO l-1 DO	pSeed[ i ] := label[ i ]	END;
			FOR i := 0 TO seedLen-1 DO	pSeed[ l + i ] := seed[ i ]	END;

			j := secretLen DIV 2 + secretLen MOD 2;	(* j := ceil( secretLen / 2 ) *)
			FOR i := 0 TO j-1 DO			s1[ i ] := secret[ i ]			END;
			FOR i := secretLen-j TO secretLen-1 DO		s2[ i+j-secretLen ] := secret[ i ]		END;

			pMD5.Expand( s1, pSeed, md5Result, j, seedLen+l, outLen );
			pSHA.Expand( s2, pSeed, shaResult, j, seedLen+l, outLen );

			FOR i := 0 TO outLen-1 DO	outbuf[ i ] := BIT.CXOR( md5Result[ i ], shaResult[ i ] )	END
		END  GetBytes;
	END PRF;

	Policy* = OBJECT
		VAR
			cipherSuites -: ARRAY Suites OF LONGINT;
			nofCipherSuites -: LONGINT;	(** number of enabled cipher-suites *)
			sessionResumptionEnabled -: BOOLEAN;
			sessionLifetime -: LONGINT; (** seconds *)

		PROCEDURE &Init*;
		BEGIN
			(* set default values *)
			sessionResumptionEnabled := TRUE;
			sessionLifetime := DefaultSessionLifetime
		END Init;

		(** set n negotiable cipher suites in order of preference*)
		PROCEDURE SetCipherSuites*( VAR s: ARRAY OF LONGINT; n: LONGINT );
			VAR i: LONGINT;
		BEGIN
			ASSERT( n <= Suites );
			FOR i := 0 TO n-1 DO cipherSuites[ i ] := s[ i ] END;
			nofCipherSuites := n
		END SetCipherSuites;

		(** Returns TRUE if the cipher-suite s is supported by this policy *)
		PROCEDURE IsSupported*( s: LONGINT ): BOOLEAN;
			VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO nofCipherSuites - 1 DO
				IF cipherSuites[ i ] = s THEN RETURN TRUE END
			END;
			RETURN FALSE
		END IsSupported;

		(** set whether sessions may be resumed; default is TRUE *)
		PROCEDURE EnableSessionResumption*( enable: BOOLEAN );
		BEGIN	sessionResumptionEnabled := enable
		END EnableSessionResumption;

		(** lifetime of a session in seconds; default: 3600s *)
		PROCEDURE SetSessionLifetime*( t: LONGINT );
		BEGIN
			ASSERT( t >= 0 );
			sessionLifetime := t
		END SetSessionLifetime;

	END Policy;

	Session = OBJECT
		VAR
			id : ARRAY 32 OF CHAR;
			idLength : LONGINT;
			resumable : BOOLEAN;
			cipherSuite : LONGINT;
			preMasterSecret, masterSecret -: ARRAY 48 OF CHAR;
			lifetime: LONGINT;	(* seconds *)
			timer: Kernel.Timer;
			next: Session;

		(** initialize a session.
			If caching is FALSE, no session-id will associated with the new session.
			if cache is TRUE and len is zero, a session id will be randomly generated.
			if cache is TRUE and len is non-zero, a session-id will be read from data *)
		PROCEDURE & Init*( caching: BOOLEAN; VAR data: ARRAY OF CHAR; ofs, len, lifetime: LONGINT );
			VAR i: LONGINT;
		BEGIN
			ASSERT( ofs > -1 );	ASSERT( len > -1 );	ASSERT( ofs + len <= LEN( data ) );	ASSERT( lifetime > 0 );
			resumable := caching;
			IF caching THEN
				IF len = 0 THEN	(* server-side: session-id has to be generated *)
					idLength := SessionIdLength;
					Utils.RandomBytes( id, 0, SessionIdLength )
				ELSE	(* client-side: session-id has been generated by server *)
					idLength := len;
				FOR i := 0 TO len - 1 DO		id[ i ] := data[ ofs + i ]		END
				END
			END;
			cipherSuite := 0;
			SELF.lifetime := lifetime
		END Init;

		(** Marks this Session as not resumable for future Connections *)
		PROCEDURE Invalidate;
		BEGIN
			resumable := FALSE
		END Invalidate;

		(** Sets the PreMasterSecret contained in data, starting at ofs. The lenght of the PreMasterSecret is always 48 bytes *)
		PROCEDURE SetPreMasterSecret( data: ARRAY OF CHAR; ofs: LONGINT );
			VAR i: LONGINT;
		BEGIN
			ASSERT( LEN(data) >= ofs + 48 );
			FOR i := 0 TO 47 DO		preMasterSecret[ i ] := data[ ofs + i ]		END
		END SetPreMasterSecret;

	BEGIN { ACTIVE }
		NEW( timer );
		timer.Sleep( 1000 * lifetime );
		Invalidate( )

	END Session;

	Context* = OBJECT
		VAR
			policy-: Policy;
			rsaCertificate: ARRAY 10000 OF CHAR;
			rsaPrivateKey, rsaPublicKey: CryptoRSA.Key;
			lengthOfRsaCertificate: LONGINT;
			sessionCache: ARRAY SessionHashtableSize OF Session;
			timer: Kernel.Timer;
			active: BOOLEAN;

		PROCEDURE & Init*( p: Policy );
		BEGIN
			policy := p;
		NEW( timer );
				active := TRUE
		END Init;

		PROCEDURE Dispose*;
			BEGIN
			active := FALSE
		END Dispose;

		(** Loads the rsa-certificate specified with filename. The certificate must be DER-formatted *)
		PROCEDURE LoadRsaCertificate*( filename: ARRAY OF CHAR ): LONGINT;
			VAR
				f: Files.File;
				r: Files.Reader;
				i: LONGINT;
		BEGIN
			f := Files.Old(filename);	(* open an old file *)
			IF f # NIL THEN
				Files.OpenReader( r, f, 0);	(* open a buffer on the file *)
				i := 0;
				WHILE r.res # Streams.EOF DO
					rsaCertificate[ i + 6 ] := r.Get( );	(* first six bytes are length-fields of the certificate *)
					INC( i )
				END;
				lengthOfRsaCertificate := i-1;
				IF Trace THEN PrintRsaCertificate( ) END;
				(* length-fields *)
				rsaCertificate[ 0 ] := CHR( ( lengthOfRsaCertificate + 3 ) DIV ( 256 * 256 ) );
				rsaCertificate[ 1 ] := CHR( ( lengthOfRsaCertificate + 3 ) DIV 256 MOD 256 );
				rsaCertificate[ 2 ] := CHR( ( lengthOfRsaCertificate + 3 ) MOD 256 );
				rsaCertificate[ 3 ] := CHR( ( lengthOfRsaCertificate ) DIV ( 256 * 256 ) );
				rsaCertificate[ 4 ] := CHR( ( lengthOfRsaCertificate ) DIV 256 MOD 256 );
				rsaCertificate[ 5 ] := CHR( ( lengthOfRsaCertificate ) MOD 256 );
				INC( lengthOfRsaCertificate, 6 );
				RETURN Ok
			ELSE
				KernelLog.String("RSA Certificate file not found"); KernelLog.Ln;
				RETURN -1;
			END
		END LoadRsaCertificate;

		(** Loads the material needed to establish an rsa private key. Parameters p and q are two big prime numbers,
			e is the public exponent of the public key of the rsa certificate to be used. p, q and e have to be hexadecimal strings.
			pLen, qLen and eLen are the lengths of the hex strings *)
		PROCEDURE LoadRsaPrivateKey*( pHex, qHex, eHex: ARRAY OF CHAR; pLen, qLen, eLen: INTEGER );
			VAR
				p, q, e: CryptoBigNumbers.BigNumber;
				dummy: CryptoRSA.Key;
		BEGIN
			CryptoBigNumbers.AssignHex( p, pHex, pLen );
			CryptoBigNumbers.AssignHex( q, qHex, qLen );
			CryptoBigNumbers.AssignHex( e, eHex, eLen );
			NEW( SELF.rsaPrivateKey );	NEW( dummy );
			CryptoRSA.MakeKeys( p, q, e, "AosTLS", dummy, SELF.rsaPrivateKey );
			IF Trace THEN
				KernelLog.String("RSA-key loaded"); KernelLog.Ln;
				KernelLog.String("   prime p:"); KernelLog.Ln;
				CryptoBigNumbers.Print( p );
				KernelLog.String("   prime q:"); KernelLog.Ln;
				CryptoBigNumbers.Print( q );
				KernelLog.String("   public exponent:"); KernelLog.Ln;
				CryptoBigNumbers.Print( e );
				KernelLog.String("   modulus:"); KernelLog.Ln;
				CryptoBigNumbers.Print( SELF.rsaPrivateKey.modulus );
				KernelLog.String("   private exponent:"); KernelLog.Ln;
				CryptoBigNumbers.Print( SELF.rsaPrivateKey.exponent );
			END
		END LoadRsaPrivateKey;

		(** Fills rsaPublicKey from server certificate. *)
		PROCEDURE GetRsaPublicKey*;
		VAR
			certificate: X509.Certificate;
			reader: Streams.StringReader;
			algorithm: POINTER TO ARRAY OF CHAR;
			e, m: CryptoBigNumbers.BigNumber;
			writer: Streams.StringWriter;
			print: ARRAY 10 * 1024 OF CHAR;
		BEGIN
			IF rsaPublicKey = NIL THEN
				(* Read X509 Certificate *)
				NEW(certificate);
				NEW(reader, lengthOfRsaCertificate);
				(* Skip 6 bytes: they represent the length of the certificate, but are not part of it. *)
				reader.SetRaw(rsaCertificate, 6, lengthOfRsaCertificate);
				certificate.Read(reader);

				(* Get modulus and exponent of public key *)
				rsaPublicKey := certificate.publicKey;
			END
		END GetRsaPublicKey;

		PROCEDURE  PrintRsaCertificate*;
		BEGIN
			KernelLog.String("Certificate [");KernelLog.Int(lengthOfRsaCertificate,3);KernelLog.String("]");KernelLog.Ln;
			KernelLog.Buffer(rsaCertificate, 6, lengthOfRsaCertificate )
		END PrintRsaCertificate;

		(** A new server-side Session-object is created and returned according to the policy settings *)
		PROCEDURE GetNewServerSession*( ): Session;
			VAR
				dummy: ARRAY 1 OF CHAR;
				s: Session;
		BEGIN
			NEW( s, policy.sessionResumptionEnabled, dummy, 0, 0, policy.sessionLifetime );
			RETURN s
		END GetNewServerSession;

		(** look up the session cache for a stored cache associated with the session-id of length len,
			starting at ofs in data. If no session is found, NIL is returned. This method is invoked by a TLS-server. *)
		PROCEDURE FindSessionByID*( VAR data: ARRAY OF CHAR; ofs, idLen: LONGINT ): Session;
			VAR
				i: LONGINT;
				current, previous: Session;	(* fork search *)
		BEGIN
			ASSERT( idLen = SessionIdLength );
			ASSERT( idLen < 33 );	ASSERT( idLen >= 2  );	ASSERT( ofs > -1 );	ASSERT( LEN( data )  >= ofs + idLen );
			IF ~policy.sessionResumptionEnabled THEN RETURN NIL END;
			i := ( ORD( data[ ofs ] ) + 256 * ORD( data[ ofs + 1 ] ) ) MOD SessionHashtableSize;
			current := sessionCache[ i ];
			previous := sessionCache[ i ];
			WHILE current # NIL DO
				IF EqualSessionID( current.id, data, 0, ofs, idLen ) THEN
					IF current.resumable THEN
						IF current # previous THEN	(* if current is NOT the first element in the list *)
							previous.next := current.next;
							current.next := sessionCache[ i ];
							sessionCache[ i ] := current
						END;
						RETURN current
					ELSE
						RETURN NIL
					END
				ELSE
					previous := current;
					current := current.next
				END
			END;
			RETURN NIL
		END FindSessionByID;

		(* stores a given Session-object in the session-cache *)
		PROCEDURE StoreSession( s: Session );
			VAR i: LONGINT;
		BEGIN
			ASSERT( s.resumable );
			i := ORD( s.id[ 0 ] ) + 256 * ORD( s.id[ 1 ] );
			i := i MOD SessionHashtableSize;
			s.next := sessionCache[ i ];
			sessionCache[ i ] := s
		END StoreSession;

		(* returns TRUE iff data1 and data2 contain the same string of length len starting at different offsets *)
		PROCEDURE EqualSessionID( VAR data1, data2: ARRAY OF CHAR; ofs1, ofs2, len: LONGINT ): BOOLEAN;
			VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO len - 1 DO
				IF data1[ ofs1 + i ] # data2[ ofs2 + i ] THEN RETURN FALSE END;
			END;
			RETURN TRUE
		END EqualSessionID;

		(* recursive function *)
		PROCEDURE DeleteUnresumableSessions( s: Session ): Session;
		BEGIN
			IF s = NIL THEN RETURN NIL END;	(* end of recursion *)
			IF s.resumable THEN
				s.next := DeleteUnresumableSessions( s.next );
				RETURN s
			ELSE
				RETURN DeleteUnresumableSessions( s.next )
			END
		END DeleteUnresumableSessions;

		(* delete unresumable sessions *)
		PROCEDURE CleanUpSessionCache;
			VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO SessionHashtableSize - 1 DO
				sessionCache[ i ] := DeleteUnresumableSessions( sessionCache[ i ] )
			END
		END CleanUpSessionCache;

	BEGIN { ACTIVE }
		WHILE active DO
			timer.Sleep( SessionCleanUpInterval * 1000 );
			CleanUpSessionCache( )
		END

	END Context;

	Connection* = OBJECT ( TCP.Connection )
		VAR
			conn: TCP.Connection;
			in: Streams.Reader;
			out, appDataWriter: Streams.Writer;
			appDataReader: Streams.Reader;
			applicationDataPipe: Pipes.Pipe;
			context: Context;
			session: Session;
			tlsErrorCause -: LONGINT;	(** alert type that lead to failure *)
			handshakeState: LONGINT;
			outbuf, inbuf: ARRAY Buflen OF CHAR; (* buffers for outgoing and incoming messages *)
			hsMD5send, hsMD5verify: CryptoMD5.Hash;	(* handshake hash functions; to be used in the Finished messages *)
			hsSHAsend, hsSHAverify: CryptoSHA1.Hash;	(* handshake hash functions; to be used in the Finished messages *)
			pendingSecurityParameters: SecurityParameters;
			currentWriteState, pendingWriteState, currentReadState, pendingReadState: ConnectionState;
			client: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			state := TCP.Unused;
			tlsErrorCause := NoError;
			(* establish application-data-out-buffer *)
			NEW( applicationDataPipe, 1024 * 1024(*4096*) ); (* is this a good size? *)
			(*Streams.OpenWriter( appDataWriter, applicationDataPipe.Send );*)
			NEW(appDataWriter, applicationDataPipe.Send, 1024*1024);
			Streams.OpenReader( appDataReader, applicationDataPipe.Receive );
			NEW( hsMD5send );	NEW( hsSHAsend );
			NEW( hsMD5verify );	NEW( hsSHAverify );
			NEW( pendingWriteState );	NEW( currentWriteState );
			NEW( pendingReadState );	NEW( currentReadState );
			NEW( pendingSecurityParameters );

			hsMD5send.Initialize( );	hsSHAsend.Initialize( );
			hsMD5verify.Initialize( );	hsSHAverify.Initialize( )
		END Init;



		PROCEDURE AwaitStateNotEqual*(s : LONGINT);
		BEGIN { EXCLUSIVE}
			AWAIT(state # s);
		END AwaitStateNotEqual;

		PROCEDURE AwaitStateEqual*(s : LONGINT);
		BEGIN { EXCLUSIVE}
			AWAIT(state = s);
		END AwaitStateEqual;

		PROCEDURE SetState*(s : SHORTINT);
		BEGIN { EXCLUSIVE}
			state := s;
		END SetState;

		PROCEDURE ChangeWriteState;
		BEGIN
			currentWriteState := pendingWriteState;
			NEW( pendingWriteState )
		END ChangeWriteState;

		PROCEDURE ChangeReadState;
		BEGIN
			currentReadState := pendingReadState;
			NEW( pendingReadState )
		END ChangeReadState;

		(** Must be called before Open *)
		PROCEDURE SetContext*( cxt: Context  );
		BEGIN
			ASSERT( conn = NIL );
			context := cxt
		END SetContext;

		(** open a TLS connection (only use once per Connection instance). Use IP.NilPort for lport to automatically assign
		an unused local port. Use IP.NilAdr for fip to open a passive connection. *)
		PROCEDURE Open*(  lport: LONGINT; fip: IP.Adr; fport: LONGINT; VAR res: LONGINT );
		BEGIN
			(*ASSERT( IP.IsNilAdr(fip) );	(* only server-side is implemented *)*)
			ASSERT( context # NIL );	(* context must be set before calling Open *)
			ASSERT( conn = NIL );	(* invoke this method only once per instance *)
			client := ~IP.IsNilAdr(fip);
			
			(* open TCPConnection *)
			NEW( SELF.conn );
			SELF.conn.Open( lport, fip, fport, res );
			IF res # TCP.Ok THEN RETURN END;
			SetState(conn.state);
			res := Ok;
			IF client THEN Connect END;
			ASSERT( conn # NIL )
		END Open;

		(* set a TCP Connection for communication; this method should only be invoked by the Accept-method *)
		PROCEDURE SetConnection*( c: TCP.Connection );
		BEGIN
			ASSERT( conn = NIL );	ASSERT( State()= TCP.Unused );
			conn := c;
			Streams.OpenReader( in, SELF.conn.Receive );	Streams.OpenWriter( out, SELF.conn.Send );
			SetState(ServerHandshake);
			handshakeState := AwaitClientHello
		END SetConnection;

		(** Call this method only on a passive (listenig server-side) TLS.Connection. Non blocking *)
		PROCEDURE Accept*( VAR client: TCP.Connection; VAR res: LONGINT );
			VAR
				newTLSConn: Connection;
				newTCPConn: TCP.Connection;
		BEGIN
			ASSERT( State() = TCP.Listen );
			ASSERT ( SELF.conn # NIL );
			SELF.conn.Accept( newTCPConn, res );
			IF res # TCP.Ok THEN RETURN END;
			NEW( newTLSConn );
			newTLSConn.SetContext( SELF.context );
			newTLSConn.SetConnection( newTCPConn );
			client := newTLSConn;
			res := Ok
		END Accept;

		(** Sets up the TCP connection for a client-side connection. *)
		PROCEDURE Connect*;
		BEGIN
			Streams.OpenReader( in, SELF.conn.Receive );
			Streams.OpenWriter( out, SELF.conn.Send );
			SetState(ClientHandshake);
			handshakeState := GenerateClientHello
		END Connect;

		(** Close this TLS.Connection *)
		PROCEDURE Close*;
		BEGIN
			IF Trace THEN KernelLog.String("Close"); KernelLog.Ln; END;
			ASSERT( SELF.conn # NIL );
			IF ( State() = TCP.Established ) OR ( State() = ServerHandshake ) THEN
				SendWarning( CloseNotify )
			END;
			conn.Close();
			applicationDataPipe.Close();
			handshakeState := NotAValidHandshakeState;
			SetState(TCP.Closed);
		END Close;

		(** Send secured data *)
		PROCEDURE Send*( CONST data: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT );
			VAR i, size: LONGINT;
		BEGIN {EXCLUSIVE}
			AWAIT((state = TCP.Established) OR (state = TCP.Closed));
			IF state = TCP.Established THEN
				WHILE len > 0 DO
					IF Trace THEN PrintDirection(TRUE); KernelLog.String("Application Data");KernelLog.Ln END;
					size := len;
					IF size > MaxPlaintextLength THEN		size := MaxPlaintextLength		END;
					FOR i := 0 TO size-1 DO
						outbuf[ i ] := data[ ofs + i ]
					END;
					SendRecord( outbuf, ApplicationData, 0, size );
					INC( ofs, size );
					DEC( len, size )
				END
			ELSE
				res := Streams.EOF;
			END;
		END Send;

		(** Receive secured data *)
		PROCEDURE Receive*( VAR data: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT );
		BEGIN
			applicationDataPipe.Receive(data, ofs, size, min, len ,res);
		END Receive;

		(* Generates the MasterSecret for the current session as described in rfc 2246, section 8 *)
		PROCEDURE GenerateMasterSecret;
			VAR
				prf: PRF;
				seed: ARRAY 64 OF CHAR;
				i: LONGINT;
		BEGIN
			FOR i := 0 TO 31 DO
				seed[ i ] := SELF.pendingSecurityParameters.clientRandom[ i ];
				seed[ i + 32 ] := SELF.pendingSecurityParameters.serverRandom[ i ]
			END;
			NEW( prf );
			prf.GetBytes( SELF.session.preMasterSecret, seed, SELF.session.masterSecret, "master secret", 48, 64, 48 );
			(* discard preMasterSecret *)
			FOR i := 0 TO 47 DO	SELF.session.preMasterSecret[ i ] := CHR( 0 )	END
		END GenerateMasterSecret;

		(* Generates key-material for the pending state *)
		PROCEDURE GenerateKeys;
			VAR
				prf: PRF;
				keyBlock: ARRAY 104 OF CHAR;
				seed: ARRAY 64 OF CHAR;
				i, keyBlockLen, ofs, macSecretSize, cipherKeySize, cipherBlockSize: LONGINT;
		BEGIN
			(* calculate the needed amount of key-material *)
			macSecretSize := SELF.pendingWriteState.mac.size;
			cipherKeySize := SELF.pendingSecurityParameters.cipherKeySize;
			IF SELF.pendingWriteState.cipher # NIL THEN
				cipherBlockSize := SELF.pendingWriteState.cipher.blockSize
			ELSE
				cipherBlockSize := 0
			END;
			keyBlockLen := 2 * macSecretSize + 2 * cipherKeySize;
			IF cipherBlockSize > 1 THEN	(* if a blockcipher is used, initialization vectors are needed *)
			INC( keyBlockLen, 2 * cipherBlockSize )
			END;
			ASSERT( keyBlockLen <= 104 );	(* 3DES-EDE-CBC-SHA needs 104 bytes of keymaterial. all others need less *)
			FOR i := 0 TO 31 DO
				seed[ i ] := SELF.pendingSecurityParameters.serverRandom[ i ];
				seed[ i + 32 ] := SELF.pendingSecurityParameters.clientRandom[ i ]
			END;
			NEW( prf );
			prf.GetBytes( SELF.session.masterSecret, seed, keyBlock, "key expansion", 48, 64, keyBlockLen );
			(* mac secret *)
			FOR i := 0 TO macSecretSize - 1 DO
				IF client THEN
					SELF.pendingWriteState.macSecret[ i ] := keyBlock[ i ];
					SELF.pendingReadState.macSecret[ i ] := keyBlock[ macSecretSize + i ]
				ELSE
					SELF.pendingReadState.macSecret[ i ] := keyBlock[ i ];
					SELF.pendingWriteState.macSecret[ i ] := keyBlock[ macSecretSize + i ]
				END
			END;
			(* keys for encryption and decription *)
			ofs := 2 * macSecretSize;
			FOR i := 0 TO cipherKeySize - 1 DO
				IF client THEN
					SELF.pendingWriteState.cipherKey[ i ] := keyBlock[ ofs + i ];
					SELF.pendingReadState.cipherKey[ i ] := keyBlock[ ofs + cipherKeySize + i ]
				ELSE
					SELF.pendingReadState.cipherKey[ i ] := keyBlock[ ofs + i ];
					SELF.pendingWriteState.cipherKey[ i ] := keyBlock[ ofs + cipherKeySize + i ]
				END
			END;
			(* initialization vectors *)
			IF cipherBlockSize > 1 THEN
				ofs := 2 * macSecretSize + 2 * cipherKeySize;
				FOR i := 0 TO cipherBlockSize - 1 DO
					IF client THEN
						SELF.pendingWriteState.iv[ i ] := keyBlock[ ofs + i ];
						SELF.pendingReadState.iv[ i ] := keyBlock[ ofs + cipherBlockSize + i ]
					ELSE
						SELF.pendingReadState.iv[ i ] := keyBlock[ ofs + i ];
						SELF.pendingWriteState.iv[ i ] := keyBlock[ ofs + cipherBlockSize + i ]
					END
				END
			END
		END GenerateKeys;

		(* initializes a given ConnectionState with the key material contained in the ConnectionState and in
			the given SecurityParameters *)
		PROCEDURE InitializeConnectionState( state: ConnectionState; sp: SecurityParameters );
		BEGIN
			IF state.cipher # NIL THEN
				state.cipher.InitKey( state.cipherKey, 8 * sp.cipherKeySize );
				IF state.cipher.blockSize > 0 THEN
					state.cipher.SetIV( state.iv, Ciphers.CBC )
				END
			END
		END InitializeConnectionState;

		PROCEDURE PrepareConnectionState( state: ConnectionState; cipherSuite: LONGINT ; VAR res : LONGINT);
		BEGIN
			ASSERT( cipherSuite # 0 );
			res := Ok;
			CASE cipherSuite OF
				| TlsRsaWithNullMd5:
					NEW( state.mac, "CryptoMD5" );
					state.cipher := NIL;
				| TlsRsaWithNullSha:
					NEW( state.mac, "CryptoSHA1" );
					state.cipher := NIL;
				| TlsRsaWithRc4128Md5:
					NEW( state.mac, "CryptoMD5" );
					state.cipher := Ciphers.NewCipher( "CryptoARC4" );
				| TlsRsaWithRc4128Sha:
					NEW( state.mac, "CryptoSHA1" );
					state.cipher := Ciphers.NewCipher( "CryptoARC4" );
				| TlsRsaWithIdeaCbcSha:
					NEW( state.mac, "CryptoSHA1" );
					state.cipher := Ciphers.NewCipher( "CryptoIDEA" );
				| TlsRsaWithDesCbcSha:
					NEW( state.mac, "CryptoSHA1" );
					state.cipher := Ciphers.NewCipher( "CryptoDES" );
				| TlsRsaWith3DesEdeCbcSha:
					NEW( state.mac, "CryptoSHA1" );
					state.cipher := Ciphers.NewCipher( "CryptoDES3" );
				ELSE
					res := -1;
			END;
		END PrepareConnectionState;

		PROCEDURE PrepareSecurityParameters( sp: SecurityParameters; cipherSuite: LONGINT ; VAR res : LONGINT);
		BEGIN
			ASSERT( cipherSuite # 0 );
			res := Ok;
			sp.cipherSuite := cipherSuite;
			CASE cipherSuite OF
				| TlsRsaWithNullMd5:
					sp.cipherKeySize := 0;
				| TlsRsaWithNullSha:
					sp.cipherKeySize := 0;
				| TlsRsaWithRc4128Md5:
					sp.cipherKeySize := 16;
				| TlsRsaWithRc4128Sha:
					sp.cipherKeySize := 16;
				| TlsRsaWithIdeaCbcSha:
					sp.cipherKeySize := 16;
				| TlsRsaWithDesCbcSha:
					sp.cipherKeySize := 8;
				| TlsRsaWith3DesEdeCbcSha:
					sp.cipherKeySize := 24;
			ELSE
				res := -1
			END;
		END PrepareSecurityParameters;

	(* **********************************************************************************
		RECORD LAYER
		********************************************************************************** *)

		PROCEDURE SendRecord( VAR data: ARRAY OF CHAR; contentType, ofs, len: LONGINT );
			VAR
				macInput: ARRAY 13 OF CHAR;
				i, length, padLen, blocksize: LONGINT;
				t: LONGINT;
		BEGIN
			ASSERT( len <= MaxPlaintextLength );
			(* increment the number of sent records *)
			currentWriteState.recordSeq.Inc( );
			length := len;
			(* data compression: no other algo than NULL is implemented *)
			(* mac *)
			IF currentWriteState.mac # NIL THEN
				currentWriteState.recordSeq.GetBytes( macInput, 0 );
				macInput[ 8 ] := CHR( contentType );
				macInput[ 9 ] := version[ 0 ];
				macInput[ 10 ] := version[ 1 ];
				macInput[ 11 ] := CHR( len DIV 256 );
				macInput[ 12 ] := CHR( len );
				currentWriteState.mac.Initialize( currentWriteState.macSecret, currentWriteState.mac.size );
				currentWriteState.mac.Update( macInput, 0, 13 );
				currentWriteState.mac.Update( data, ofs, len );
				currentWriteState.mac.GetMac( data, ofs+len );
				INC( length, currentWriteState.mac.size )
			END;
			(* encryption *)
			IF currentWriteState.cipher # NIL THEN	(* encryption has to be done *)
				blocksize := currentWriteState.cipher.blockSize;
				IF blocksize > 1 THEN	(* padding for encryption has to be added *)
					padLen := ( blocksize - ( ( length + 1 ) MOD blocksize ) ) MOD blocksize;	(* padLen = [ 0, blocksize-1 ] *)
					IF padLen > 0 THEN
						FOR i := 0 TO padLen - 1 DO		data[ ofs + length + i ] := CHR( padLen )		END
					END;
					data[ ofs + length + padLen ] := CHR( padLen );
					length := length + padLen + 1
				END;
				currentWriteState.cipher.Encrypt( data, ofs, length );
			END;
			(* record header *)
			out.Char( CHR( contentType ) );
			out.Char( CHR( 3 ) );
			out.Char( CHR( 1 ) );
			out.Char( CHR( length DIV 256 ) );
			out.Char( CHR( length ) );
			out.Bytes( data, ofs, length );
			out.Update;
		END SendRecord;

		(* receive one record *)
		PROCEDURE ReceiveRecord;
			VAR
				macInput: ARRAY 13 OF CHAR;
				verify: ARRAY 20 OF CHAR;
				i, length, len, type, macSize, res, major, minor: LONGINT;
				tt: LONGINT;
		BEGIN
			(* increment the number of received records *)
			currentReadState.recordSeq.Inc( );
			(* record header *)
			type := ORD( in.Get( ) );	(* content type *)
			IF type = 128 THEN (* SSLv2-compatible ClientHello *)
				len := ORD( in.Get() );
				in.Bytes( inbuf, 0, len, length );
				IF len = length THEN
					ReceiveV2Handshake( inbuf, 0, len );
					RETURN
				ELSE
					SendError( InternalError );
					RETURN
				END
			END;
			major := ORD( in.Get() );	minor := ORD( in.Get() );
			IF ( major # 3 ) OR ( minor # 1) THEN  END;	(* version control *)
			len := 256 * ORD( in.Get() ) + ORD( in.Get() );	(* length of payload *)
			IF len > MaxCiphertextLength THEN
				SendError( RecordOverflow );
				RETURN
			END;
			(* payload *)
			in.Bytes( inbuf, 0, len, length );
			IF in.res # Streams.Ok THEN
				IF Trace THEN KernelLog.String("Can't read record: supposed to read:"); KernelLog.Int(len, 7); KernelLog.String(" read: "); KernelLog.Int(length,7);END;
				RETURN
			END;
			(* records with unknown client protocol type are ignored; type=128: SSLv2-compatible ClientHello *)
			IF ( type = 128 ) OR ( type < 20 ) OR ( type > 23 ) THEN	RETURN	END;
			IF length # len THEN
				SendError( IllegalParameter );
				RETURN
			END;
			(* decryption *)
			IF currentReadState.cipher # NIL THEN
				currentReadState.cipher.Decrypt( inbuf, 0, len  );
				IF res # Ciphers.Ok THEN
					IF Trace THEN KernelLog.String("There was a Problem while decrypting record.");KernelLog.Ln END;
					SendError( InternalError );
					RETURN
				END;
				IF currentReadState.cipher.blockSize > 1 THEN	(* padding has to be removed *)
					len := len - ORD( inbuf[ len ] ) - 1;
				END
			END;
			(* mac verification *)
			IF currentReadState.mac # NIL THEN
				macSize := currentReadState.mac.size;
				len := len - macSize;
				currentReadState.recordSeq.GetBytes( macInput, 0 );
				macInput[ 8 ] := CHR( type );
				macInput[ 9 ] := CHR( major );
				macInput[ 10 ] := CHR( minor );
				macInput[ 11 ] := CHR( len DIV 256 );
				macInput[ 12 ] := CHR( len );
				currentReadState.mac.Initialize( currentReadState.macSecret, macSize );
				currentReadState.mac.Update( macInput, 0, 13 );
				currentReadState.mac.Update( inbuf, 0, len );
				currentReadState.mac.GetMac( verify, 0 );
				FOR i := 0 TO macSize - 1 DO
					IF inbuf[ len + i ] # verify[ i ] THEN
						 SendError( BadRecordMac );
						 RETURN
					END
				END
			END;
			(* data compression: no other algo than NULL is implemented *)
			(* dispatching *)
			CASE type OF
				| Handshake:
					ReceiveHandshake( inbuf, 0, len )
				| ApplicationData:
					appDataWriter.Bytes( inbuf, 0, len );
					appDataWriter.Update;
				| Alert:
					ASSERT( len = 2 );
					ReceiveAlert( inbuf, 0, len )
				| ChangeCipherSpec:
					ASSERT( len = 1 );
					Transition( inbuf, ChangeCipherSpec, 0, 0, len )
			END;
		END ReceiveRecord;

	(* **********************************************************************************
		CHANGE CIPHER SPEC PROTOCOL
		********************************************************************************** *)

		PROCEDURE SendChangeCipherSpec;
		BEGIN
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("ChangeCipherSpec: ");KernelLog.Ln END;
			outbuf[ 0 ] := CHR( 1 );
			SendRecord( outbuf, ChangeCipherSpec, 0, 1 );
			ChangeWriteState( )
		END SendChangeCipherSpec;

		PROCEDURE ReceiveChangeCipherSpec( VAR data: ARRAY OF CHAR; ofs: LONGINT );
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("ChangeCipherSpec");KernelLog.Ln END;
			IF ORD( data[ ofs ] ) # 1 THEN (* wrong content of ChangeCipherSpec *)
				SendError( IllegalParameter )
			ELSE
				ChangeReadState( )
			END
		END ReceiveChangeCipherSpec;

	(* **********************************************************************************
		HANDSHAKE PROTOCOL
		********************************************************************************** *)

		PROCEDURE SendHandshake( VAR data: ARRAY OF CHAR; hsType, ofs, len: LONGINT );
			VAR l: LONGINT;
		BEGIN
			ASSERT( len < 256 * 256 * 256 );
			l := len;
			data[ ofs ] := CHR( hsType );
			data[ ofs + 3 ] := CHR( l MOD 256 );	l := l DIV 256;
			data[ ofs + 2 ] := CHR( l MOD 256 );	l := l DIV 256;
			data[ ofs + 1 ] := CHR( l MOD 256 );
			IF hsType # HelloRequest THEN
				(* update the digests used in the finished-messages *)
				IF (hsType # Finished) OR (hsType # ClientHello) THEN (* Finished-msg doesn't contain digest of itself *)
					hsMD5send.Update( data, ofs, len + 4 );
					hsSHAsend.Update( data, ofs, len + 4 )
				END;
				hsMD5verify.Update( data, ofs, len + 4 );
				hsSHAverify.Update( data, ofs, len + 4 )
			END;
			SendRecord( data, Handshake, ofs, len + 4 );
		END SendHandshake;

		(* receives one or more handshake messages *)
		PROCEDURE ReceiveHandshake( VAR data: ARRAY OF CHAR; ofs, len: LONGINT );
			VAR msgLen, hsType, ptr, (*debug*) i: LONGINT;
		BEGIN
			ASSERT( LEN( data ) >= ofs + len );
			ptr := ofs;
			WHILE ptr < ofs + len DO	(* for each handshake message *)
				hsType := ORD( data[ ptr ] );	(* handshake type *)
				msgLen := 256 * 256 * ORD( data[ ptr + 1 ] ) + 256 * ORD( data[ ptr + 2 ] ) + ORD( data[ ptr + 3 ] );
				(* update the digests used in the finished-messages *)
				hsMD5send.Update( data, ptr, msgLen + 4 );
				hsSHAsend.Update( data, ptr, msgLen + 4 );
				IF hsType # Finished THEN (* Finished-msg doesn't contain digest of itself *)
					hsMD5verify.Update( data, ptr, msgLen + 4 );
					hsSHAverify.Update( data, ptr, msgLen + 4 )
				END;
				Transition( data, Handshake, hsType, ptr + 4, msgLen );
				ptr := ptr + 4 + msgLen
			END
		END ReceiveHandshake;

		PROCEDURE ReceiveV2Handshake( VAR data: ARRAY OF CHAR; ofs, len: LONGINT );
		BEGIN
			ASSERT( data[ofs] = CHR( 1 ) );	(* v2ClientHello *)
			(* re-initialize hashes *)
			hsMD5send.Initialize( );	hsSHAsend.Initialize( );
			hsMD5verify.Initialize( );	hsSHAverify.Initialize( );
			(* update the digests used in the finished-messages *)
			hsMD5send.Update( data, ofs, len );
			hsSHAsend.Update( data, ofs, len );
			hsMD5verify.Update( data, ofs, len );
			hsSHAverify.Update( data, ofs, len );
			Transition( data, Handshake, V2ClientHello, ofs, len );
		END ReceiveV2Handshake;

		PROCEDURE StartHandshake;
		BEGIN
			Streams.OpenReader( in, SELF.conn.Receive );
			Streams.OpenWriter( out, SELF.conn.Send );
			SetState(ClientHandshake);
			handshakeState := GenerateClientHello;
			Transition(outbuf, Handshake, 0, 0, 0)
		END StartHandshake;

		PROCEDURE ReceiveClientHello( VAR data: ARRAY OF CHAR; ofs, len: LONGINT ): LONGINT;
			VAR
				nofSuites, i, idLen, idPos, pos, cipherSuite, major, minor, res: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("ClientHello");KernelLog.Ln END;
			pos := ofs;
			(* version check *)
			major := ORD( data[ pos ] );	minor := ORD( data[ pos + 1 ] );
			IF Trace THEN KernelLog.String("  version: ");KernelLog.Int(major,1);KernelLog.String(".");KernelLog.Int(minor,1);KernelLog.Ln END;
			IF ( major < 3  ) OR ( minor < 1 ) THEN (* fatal error: protocol version not supported *)
				SendError( ProtocolVersion );
				RETURN -1
			END;
			INC( pos, 2 );
			(* 32 bytes client random *)
			FOR i := 0 TO 31 DO		pendingSecurityParameters.clientRandom[ i ] := data[ pos + i ]		END;
			INC( pos, 32 );
			IF Trace THEN KernelLog.String("SERVER client random:"); KernelLog.Ln; KernelLog.Buffer(pendingSecurityParameters.clientRandom, 0, 32); KernelLog.Ln END;
			(* session id *)
			idLen := ORD( data[ pos ] );
			idPos := pos + 1;
			INC( pos, idLen + 1 );
			(* cipher-suites *)
			nofSuites := (256 * ORD( data[ pos ] ) + ORD( data[ pos + 1 ] )) DIV 2; (* number of cipher-suites supported by the client *)
			INC( pos, 2 );

			IF idLen = SessionIdLength THEN	(* client attempted session resumption *)
				session := context.FindSessionByID( data, idPos, idLen );
				IF session # NIL THEN
					(* check: is the resumed session's cipher-suite contained by the client-hello ? *)
					FOR i := 0 TO nofSuites - 1 DO
						cipherSuite := 256 * ORD( data[ pos + 2 * i ] ) + ORD( data[ pos + 2 * i + 1 ] );
						IF cipherSuite = session.cipherSuite THEN	(* session resumption *)
							pendingSecurityParameters.cipherSuite := session.cipherSuite;
							IF Trace THEN KernelLog.String("ciphersuite: ");KernelLog.Int(pendingSecurityParameters.cipherSuite, 8 );KernelLog.Ln END;
							RETURN GenerateHelloWithResumption
						END
					END
				END
			END;
			(* establish new session *)
			session := context.GetNewServerSession( );
			(* choose cipher-suite *)
			i := 0;
			LOOP
				cipherSuite := 256 * ORD( data[ pos + 2 * i ] ) + ORD( data[ pos + 2 * i + 1 ] );
				IF Trace THEN KernelLog.String("Server: client accepts cipher suite: "); KernelLog.Int(cipherSuite, 0); KernelLog.Ln END;
				IF context.policy.IsSupported( cipherSuite ) THEN
					EXIT
				END;
				INC( i );
				IF i = nofSuites THEN EXIT END
			END;
			IF cipherSuite = 0 THEN	(* no compatible cipher-suite found *)
				IF Trace THEN KernelLog.String("Server: No common cipher suite found"); KernelLog.Ln END;
				SendError( HandshakeFailure );
				RETURN -1
			END;
			SELF.session.cipherSuite := cipherSuite;
			PrepareSecurityParameters( pendingSecurityParameters, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Server: Error preparing cipher suite"); KernelLog.Ln END;
				SendError( HandshakeFailure );
				RETURN -1
			END;
			PrepareConnectionState( pendingWriteState, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Server: Error preparing pending write state"); KernelLog.Ln END;
				SendError( HandshakeFailure );
				RETURN -1
			END;
			PrepareConnectionState( pendingReadState, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Server: Error preparing pending read state"); KernelLog.Ln END;
				SendError( HandshakeFailure );
				RETURN -1
			END;
			(* ignore compression method *)
			RETURN GenerateServerHello
		END ReceiveClientHello;

		PROCEDURE SendClientHello(VAR data: ARRAY OF CHAR; ofs: LONGINT);
		VAR
			pos, i: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("ClientHello");KernelLog.Ln END;
			ASSERT( ofs > 3 );

			pos := ofs;

			(* client version *)
			data[ pos ] := version[ 0 ];	data[ pos + 1 ] := version[ 1 ];	(* only 3.1 is supported *)
			INC( pos, 2 );

			(* client random bytes generation*)
			Create32RandomBytes( pendingSecurityParameters.clientRandom );
			FOR i := 0 TO 31 DO	data[ pos + i ] := pendingSecurityParameters.clientRandom[ i ]	END;	(* copy random to outbuf *)
			INC( pos, 32 );

			(* session-id *)
			IF session # NIL THEN
				(* if a previous session is available, ask server to resume it. *)
				data[ pos ] := CHR( session.idLength );
				INC(pos);
				FOR i := 0 TO session.idLength - 1 DO data[pos + i] := session.id[i] END;
				INC(pos, session.idLength)
			ELSE
				data[pos] := 0X;
				INC(pos)
			END;

			(* cipher-suite: length, then suite *)
			data[pos] := CHR((2 * context.policy.nofCipherSuites) DIV 256);
			data[pos + 1] := CHR((2 * context.policy.nofCipherSuites) MOD 256);
			INC(pos, 2);
			FOR i := 0 TO context.policy.nofCipherSuites - 1 DO
				data[ pos ] := CHR(context.policy.cipherSuites[i] DIV 256);
				data[ pos + 1 ] := CHR(context.policy.cipherSuites[i] MOD 256);
				INC( pos, 2 )
			END;

			(* compression-method *)
			data[ pos ] := 1X;
			INC( pos );
			data[ pos ] := 0X;
			INC( pos );

			SendHandshake( data, ClientHello, ofs - 4, pos - ofs)
		END SendClientHello;

		PROCEDURE ReceiveV2ClientHello( VAR data: ARRAY OF CHAR; ofs, len: LONGINT ): LONGINT;
			VAR nofSuites, idLen, challengeLen, i, cipherSuite, res: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("SSLv2.0 ClientHello");KernelLog.Ln END;
			nofSuites := ( 256 * ORD(data[ofs+3]) + ORD(data[ofs+4]) ) DIV 3;
			idLen := 256 * ORD(data[ofs+5]) + ORD(data[ofs+6]);
			challengeLen := 256 * ORD(data[ofs+7]) + ORD(data[ofs+8]);
			(* if an SSLv2.0-ClientHello is received, a new session has to be established, because a client sends an TLSv1.0-ClientHello when resuming a session *)
			session := context.GetNewServerSession( );
			(* choose cipher-suite *)
			INC( ofs, 9);
			i := 0;
			LOOP
				cipherSuite := 256*256*ORD( data[ ofs + 3 * i ] ) + 256 * ORD( data[ ofs + 3 * i + 1 ] ) + ORD( data[ ofs + 3 * i + 2 ] );
				IF context.policy.IsSupported( cipherSuite ) THEN
					EXIT
				END;
				INC( i );
				IF (i = nofSuites) OR (ofs + 3 * i + 2 >= LEN(data)) THEN EXIT END
			END;
			IF cipherSuite = 0 THEN	(* no compatible cipher-suite found *)
				SendError( HandshakeFailure );
				RETURN -1
			END;
			SELF.session.cipherSuite := cipherSuite;
			PrepareSecurityParameters( pendingSecurityParameters, cipherSuite, res );
			IF res < 0 THEN
				SendError( HandshakeFailure );
				RETURN -1
			END;
			PrepareConnectionState( pendingWriteState, cipherSuite, res );
			IF res < 0 THEN
				SendError( HandshakeFailure );
				RETURN -1
			END;
			PrepareConnectionState( pendingReadState, cipherSuite, res );
			IF res < 0 THEN
				SendError( HandshakeFailure );
				RETURN -1
			END;
			INC( ofs, nofSuites * 3 );
			(* session id *)
			IF idLen = SessionIdLength THEN	(* client attempted session resumption *)
				session := context.FindSessionByID( data, ofs, idLen );
				IF session # NIL THEN
					RETURN GenerateHelloWithResumption
				END
			END;
			INC( ofs, idLen );
			(* 32 bytes client random *)
			FOR i := 0 TO 31-challengeLen DO		pendingSecurityParameters.clientRandom[ i ] := CHR(0)		END;
			FOR i := 0 TO challengeLen-1 DO		pendingSecurityParameters.clientRandom[ 32-challengeLen + i ] := data[ ofs + i ]		END;
			RETURN GenerateServerHello
		END ReceiveV2ClientHello;

		PROCEDURE ReceiveServerHello(VAR data: ARRAY OF CHAR; ofs, len: LONGINT): LONGINT;
		VAR
			pos, major, minor, i, idLen, idPos, cipherSuite, res: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("ServerHello");KernelLog.Ln END;
			pos := ofs;

			(* version check *)
			major := ORD( data[ pos ] );	minor := ORD( data[ pos + 1 ] );
			IF ( major < 3  ) OR ( minor < 1 ) THEN (* fatal error: protocol version not supported *)
				IF Trace THEN KernelLog.String("Incompatible protocol version"); KernelLog.Ln END;
				RETURN -1
			END;
			INC( pos, 2 );

			(* 32 bytes server random *)
			FOR i := 0 TO 31 DO		pendingSecurityParameters.serverRandom[ i ] := data[ pos + i ]		END;
			INC( pos, 32 );

			(* session id *)
			idLen := ORD( data[ pos ] );
			idPos := pos + 1;
			INC( pos, idLen + 1 );

			IF session # NIL THEN
				(* See if session was restored *)
				session := context.FindSessionByID(data, idPos, idLen);
			END;
			IF session = NIL THEN
				(* create a new session *)
				NEW(session, TRUE, data, idPos, idLen, context.policy.sessionLifetime);
			END;

			(* cipher-suite selected by the server*)
			cipherSuite := 250 * ORD( data[ pos] ) + ORD( data[ pos + 1 ] );
			SELF.session.cipherSuite := cipherSuite;
			PrepareSecurityParameters( pendingSecurityParameters, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Failed to Prepare TLS security parameters"); KernelLog.Ln END;
				RETURN -1
			END;
			PrepareConnectionState( pendingWriteState, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Failed to Prepare TLS pending write state"); KernelLog.Ln END;
				RETURN -1
			END;
			PrepareConnectionState( pendingReadState, cipherSuite, res );
			IF res < 0 THEN
				IF Trace THEN KernelLog.String("Failed to Prepare TLS pending read state"); KernelLog.Ln END;
				RETURN -1
			END;

			(* ignore compression method *)
			RETURN AwaitCertificate
		END ReceiveServerHello;

		PROCEDURE SendServerHello( VAR data: ARRAY OF CHAR; ofs: LONGINT );
			VAR i, pos: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("ServerHello");KernelLog.Ln END;
			ASSERT( ofs > 3 );
			pos := ofs;
			(* server version *)
			data[ pos ] := version[ 0 ];	data[ pos + 1 ] := version[ 1 ];	(* only 3.1 is supported *)
			INC( pos, 2 );
			(* server random bytes generation*)
			Create32RandomBytes( pendingSecurityParameters.serverRandom );
			FOR i := 0 TO 31 DO	data[ pos + i ] := pendingSecurityParameters.serverRandom[ i ]	END;	(* copy random to outbuf *)
			INC( pos, 32 );
			(* session-id *)
			data[ pos ] := CHR( session.idLength );
			INC( pos );
			FOR i := 0 TO session.idLength - 1 DO		data[ pos + i ] := session.id[ i ]		END;	(* copy session-id to data *)
			INC( pos, session.idLength );
			(* cipher-suite *)
			data[ pos ] := CHR( pendingSecurityParameters.cipherSuite DIV 250 );
			data[ pos + 1 ] := CHR( pendingSecurityParameters.cipherSuite MOD 250 );
			INC( pos, 2 );
			(* compression-method *)
			data[ pos ] := CHR( 0 );
			INC( pos );
			SendHandshake( data, ServerHello, ofs-4, pos-ofs )
		END SendServerHello;

		PROCEDURE SendClientKeyExchange(VAR data: ARRAY OF CHAR; ofs: LONGINT): LONGINT;
		VAR
			length: LONGINT;
		BEGIN
			IF Trace THEN
				PrintDirection(TRUE);
				KernelLog.String("Client Key Exchange"); KernelLog.Ln
			END;
			context.GetRsaPublicKey;

			(* Premaster secret *)
			session.preMasterSecret[0] := version[0];
			session.preMasterSecret[1] := version[1];
			Utils.RandomBytes(session.preMasterSecret, 2, 46);

			PKCS1.Encrypt(session.preMasterSecret, 0, 48, context.rsaPublicKey, 2, data, ofs + 2, length);
			ASSERT(length # 0);
			data[ofs] := CHR(length DIV 256);
			data[ofs + 1] := CHR(length MOD 256);
			SendHandshake(data, ClientKeyExchange, ofs - 4, length + 2);

			(* Generate master secret. Done in the end, because premaster secret is eraased. *)
			GenerateMasterSecret;
			GenerateKeys;
			InitializeConnectionState( SELF.pendingWriteState, SELF.pendingSecurityParameters );
			InitializeConnectionState( SELF.pendingReadState, SELF.pendingSecurityParameters );

			RETURN GenerateChangeCipherSpec
		END SendClientKeyExchange;

		PROCEDURE ReceiveClientKeyExchange(CONST data: ARRAY OF CHAR; ofs, len: LONGINT );
			VAR
				encryptedPremasterSecret, premasterSecret: CryptoBigNumbers.BigNumber;
				tmp: ARRAY 512 OF CHAR;
				i: LONGINT;
		BEGIN
			INC( ofs, 2 ); DEC( len, 2 );	(* the two first bytes have to be ignored *)
			IF Trace THEN
				PrintDirection(FALSE);
				KernelLog.String("ClientKeyExchange");KernelLog.Ln;
			END;
			(* decryption of the PreMasterSecret *)
			CryptoBigNumbers.AssignBin( encryptedPremasterSecret, data, ofs, len );
			premasterSecret := SELF.context.rsaPrivateKey.Decrypt( encryptedPremasterSecret  );
			IF  premasterSecret = NIL THEN
				IF Trace THEN KernelLog.String("Decryption of PreMasterSecret was NOT successful!");KernelLog.Ln END;
				SendError( IllegalParameter )
			END;
			CryptoBigNumbers.GetBinaryValue( premasterSecret, tmp, 0 );

			(* pkcs#1 block type 2 has to be used *)
			IF ( tmp[ 0 ] # CHR( 0 ) ) OR ( tmp[ 1 ] # CHR( 2 ) )THEN	SendError( IllegalParameter ) END;
			i := 10;	(* there are at least 8 padding bytes *)
			WHILE tmp[ i ] # CHR( 0 ) DO	INC( i )	END;	(* padding ends with a zero-byte *)
			INC( i );
			SELF.session.SetPreMasterSecret( tmp, i );

			GenerateMasterSecret( );
			GenerateKeys( );
			InitializeConnectionState( SELF.pendingWriteState, SELF.pendingSecurityParameters );
			InitializeConnectionState( SELF.pendingReadState, SELF.pendingSecurityParameters )
		END ReceiveClientKeyExchange;

		PROCEDURE ReceiveCertificate( VAR data: ARRAY OF CHAR; ofs, len: LONGINT ): LONGINT;
		VAR
			pos, length, lengthP3: LONGINT;
		BEGIN
			IF Trace THEN
				PrintDirection(FALSE);
				KernelLog.String("Certificate"); KernelLog.Ln;
			END;

			(* Get Certificate Length. First 3 bytes: length + 3, next 3 bytes: length *)
			lengthP3 := ORD(data[ofs]) * 256 * 256 + ORD(data[ofs + 1]) * 256 + ORD(data[ofs + 2]);
			length := ORD(data[ofs + 3]) * 256 * 256 + ORD(data[ofs + 4]) * 256 + ORD(data[ofs + 5]);
			(*ASSERT(lengthP3 = length + 3);*)
			context.lengthOfRsaCertificate := length;

			(* Get content, including first 6 bytes *)
			FOR pos := 0  TO length + 5 DO
				context.rsaCertificate[pos] := data[pos + ofs]
			END;

			(* Check certificate *)
			RETURN AwaitServerHelloDone
		END ReceiveCertificate;

		PROCEDURE SendCertificate( VAR data: ARRAY OF CHAR; ofs: LONGINT );
			VAR i: LONGINT;
		BEGIN
			ASSERT( ofs > 3 );
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("Certificate");KernelLog.Ln END;
			FOR i := 0 TO context.lengthOfRsaCertificate-1 DO
				data[ ofs + i ] := context.rsaCertificate[ i ];
			END;
			SendHandshake( data, Certificate, ofs-4, context.lengthOfRsaCertificate );
		END SendCertificate;

		PROCEDURE SendServerHelloDone( VAR data: ARRAY OF CHAR; ofs: LONGINT );
		BEGIN
			ASSERT( ofs > 3 );
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("ServerHelloDone");KernelLog.Ln END;
			SendHandshake( data, ServerHelloDone, ofs-4, 0 )
		END SendServerHelloDone;

		PROCEDURE ReceiveServerHelloDone(CONST data: ARRAY OF CHAR; ofs, len: LONGINT): LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("ServerHelloDone"); KernelLog.Ln END;
			RETURN GenerateClientKeyExchange
		END ReceiveServerHelloDone;

		PROCEDURE SendFinished( VAR data: ARRAY OF CHAR; ofs: LONGINT );
			VAR
				seed: ARRAY 36 OF CHAR;
				verifyData: ARRAY 12 OF CHAR;
				i: LONGINT;
				prf: PRF;
		BEGIN
			IF Trace THEN PrintDirection(TRUE); KernelLog.String("Finished");KernelLog.Ln END;
			ASSERT( ofs > 3 );
			hsMD5send.GetHash( seed, 0 );	hsSHAsend.GetHash( seed, 16 );	(* concatenate md5 and sha output *)
			NEW( prf );
			IF client THEN
				prf.GetBytes( SELF.session.masterSecret, seed, verifyData, "client finished", 48, 36, 12 )
			ELSE
				prf.GetBytes( SELF.session.masterSecret, seed, verifyData, "server finished", 48, 36, 12 )
			END;

			FOR i := 0 TO 11 DO
				data[ ofs + i ] := verifyData[ i ]
			END;
			SendHandshake( data, Finished, ofs-4, 12 )
		END SendFinished;

		PROCEDURE ReceiveFinished(CONST data: ARRAY OF CHAR; ofs, len: LONGINT );
			VAR
				seed: ARRAY 36 OF CHAR;
				verifyData: ARRAY 12 OF CHAR;
				prf: PRF;
				i: LONGINT;
		BEGIN
			IF Trace THEN PrintDirection(FALSE); KernelLog.String("Finished"); KernelLog.Ln END;
			ASSERT( len = 12 );
			hsMD5verify.GetHash( seed, 0 );	hsSHAverify.GetHash( seed, 16 );	(* concatenate md5 and sha output *)
			NEW( prf );
			IF client THEN
				prf.GetBytes( SELF.session.masterSecret, seed, verifyData, "server finished", 48, 36, 12 )
			ELSE
				prf.GetBytes( SELF.session.masterSecret, seed, verifyData, "client finished", 48, 36, 12 )
			END;
			FOR i := 0 TO 11 DO
				IF verifyData[ i ] # data[ ofs + i ] THEN
					SendError( DecryptError );
					RETURN
				END
			END
		END ReceiveFinished;

	(* **********************************************************************************
		ALERT PROTOCOL
		********************************************************************************** *)

		PROCEDURE ReceiveAlert( VAR data: ARRAY OF CHAR; ofs, len: LONGINT );
			VAR level, description, ptr: LONGINT;
		BEGIN
			ptr := ofs;
			WHILE ptr < ofs + len DO	(* for each Alert-message *)
				level := ORD( data[ ptr ] );
				description := ORD( data[ ptr + 1 ] );
				IF level = Warning THEN
					ReceiveWarning( description )
				ELSIF level = Fatal THEN
					ReceiveError( description )
				ELSE	(* illegal level *)
					SendError( IllegalParameter )
				END;
				INC( ptr, 2 )
			END
		END ReceiveAlert;

		PROCEDURE ReceiveWarning( desc: LONGINT);
		BEGIN
			(* always send an error; this could be more sophisticated *)
			tlsErrorCause := desc;
			SendError( CloseNotify )
		END ReceiveWarning;

		PROCEDURE ReceiveError( alertType: LONGINT);
		BEGIN
			IF Trace THEN
				PrintDirection(FALSE);
				KernelLog.String("Error");KernelLog.Ln;
				KernelLog.String("  alertType: ");KernelLog.Int(alertType, 3);KernelLog.Ln;
			END;
			IF session # NIL THEN 		SELF.session.Invalidate( )		END;
			SELF.conn.Close( );
			applicationDataPipe.Close();
			SetState(TCP.Closed);
		END ReceiveError;

		PROCEDURE SendWarning( alertType: LONGINT );
		BEGIN
			IF Trace THEN
				PrintDirection(TRUE);
				KernelLog.String("Warning");KernelLog.Ln;
				KernelLog.String("  alertType: ");KernelLog.Int(alertType, 3);KernelLog.Ln;
			END;
			outbuf[ 0 ] := CHR( 1 );	(* level: warning *)
			outbuf[ 1 ] := CHR( alertType );
			SendRecord( outbuf, Alert, 0, 2 );
		END SendWarning;

		PROCEDURE SendError( alertType: LONGINT );
		BEGIN
			IF Trace THEN
				PrintDirection(TRUE);
				KernelLog.String("Error");KernelLog.Ln;
				KernelLog.String("  alertType: ");KernelLog.Int(alertType, 3);KernelLog.Ln;
			END;
			outbuf[ 0 ] := CHR( 2 );	(* level: fatal *)
			outbuf[ 1 ] := CHR( alertType );
			SendRecord( outbuf, Alert, 0, 2 );
			IF session # NIL THEN		SELF.session.Invalidate( )		END;
			SELF.conn.Close( );
			applicationDataPipe.Close();
			SetState(TCP.Closed);
		END SendError;

	(* **********************************************************************************
		FINITE STATE MACHINE
		********************************************************************************** *)

		PROCEDURE Transition( VAR data: ARRAY OF CHAR; action, subAction, ofs, len: LONGINT );
			VAR dummy: ARRAY 1 OF CHAR;
				res : LONGINT;
		BEGIN
			IF action = ChangeCipherSpec THEN
				CASE handshakeState OF
					| AwaitChangeSpec:
						ReceiveChangeCipherSpec( data, ofs );
						handshakeState := AwaitFinished
					| AwaitChangeSpecWithResumption:
						ReceiveChangeCipherSpec( data, ofs );
						handshakeState := AwaitFinishedWithResumption
				ELSE
					SendError( UnexpectedMessage )
				END
			ELSIF action = Handshake THEN
				IF State()= ServerHandshake THEN
					CASE handshakeState OF
						| AwaitClientHello:
							IF subAction = ClientHello THEN
								handshakeState := ReceiveClientHello( data, ofs, len );
								Transition( dummy, Handshake, 0, 0, 0 )
							ELSIF subAction = V2ClientHello THEN
								handshakeState := ReceiveV2ClientHello( data, ofs, len );
								Transition( dummy, Handshake, 0, 0, 0 )
							ELSE	 (* fatal error *)
								SendError( UnexpectedMessage )
							END
						| GenerateServerHello:	(* establish new session *)
							SendServerHello( outbuf, 4 );
							SendCertificate( outbuf, 4 );
							handshakeState := GenerateServerHelloDone;
							Transition( dummy, Handshake, 0, 0, 0 )
						| GenerateServerHelloDone:
							SendServerHelloDone( outbuf, 4 );
							handshakeState := AwaitClientKeyExchange;
						| AwaitClientKeyExchange:
							IF subAction = ClientKeyExchange THEN
								ReceiveClientKeyExchange( data, ofs, len );
								handshakeState := AwaitChangeSpec;
							ELSE (* fatal error *)
								SendError( UnexpectedMessage )
							END
						| AwaitFinished:
							IF subAction = Finished THEN
								ReceiveFinished( data, ofs, len );
								handshakeState := GenerateChangeCipherSpec;
								Transition( dummy, Handshake, 0, 0, 0 )
							ELSE (* fatal error *)
								SendError( UnexpectedMessage )
							END
						| GenerateChangeCipherSpec:
							SendChangeCipherSpec;
							SendFinished( outbuf, 4 );
							handshakeState := HandshakeFinished;
							SetState(TCP.Established);
							IF SELF.context.policy.sessionResumptionEnabled THEN
								SELF.context.StoreSession( SELF.session )
							END
						| GenerateHelloWithResumption:	(* session resumption *)
							SendServerHello( outbuf, 4 );
							PrepareSecurityParameters( pendingSecurityParameters, pendingSecurityParameters.cipherSuite, res );
							IF res < 0 THEN
								SendError( UnexpectedMessage )
							END;
							PrepareConnectionState( pendingWriteState, pendingSecurityParameters.cipherSuite,res );
							IF res < 0 THEN
								SendError( HandshakeFailure );
							END;
							PrepareConnectionState( pendingReadState, pendingSecurityParameters.cipherSuite, res );
							IF res < 0 THEN
								SendError( HandshakeFailure );
							END;
							GenerateKeys( );
							InitializeConnectionState( SELF.pendingWriteState, SELF.pendingSecurityParameters );
							InitializeConnectionState( SELF.pendingReadState, SELF.pendingSecurityParameters );
							SendChangeCipherSpec;
							SendFinished( outbuf, 4 );
							handshakeState := AwaitChangeSpecWithResumption
						| AwaitFinishedWithResumption:
							IF subAction = Finished THEN
								ReceiveFinished( data, ofs, len );
								handshakeState := HandshakeFinished;
								SetState(TCP.Established);
							ELSE (* fatal error *)
								SendError( UnexpectedMessage )
							END
					END (* CASE *)
				ELSIF State() = ClientHandshake THEN
					CASE handshakeState OF
						 GenerateClientHello:
						 	SendClientHello(outbuf, 4);
						 	handshakeState := AwaitServerHello
						|AwaitServerHello:
							handshakeState := ReceiveServerHello(data, ofs, len);
						|AwaitCertificate:
							handshakeState := ReceiveCertificate(data, ofs, len);
						|AwaitServerHelloDone:
							handshakeState := ReceiveServerHelloDone(data, ofs, len);
							Transition(dummy, Handshake, 0, 0, 0)
						|GenerateClientKeyExchange:
							handshakeState := SendClientKeyExchange(outbuf, 4);
							Transition(dummy, Handshake, 0, 0, 0)
						|GenerateChangeCipherSpec:
							SendChangeCipherSpec;
							SendFinished(outbuf, 4);
							handshakeState := AwaitChangeSpec
						|AwaitChangeSpec:
							ReceiveChangeCipherSpec(data, ofs);
							handshakeState := AwaitFinished
						|AwaitFinished:
							ReceiveFinished(data, ofs, len);
							SetState(TCP.Established);
					END
				ELSIF State() = TCP.Established THEN
					IF subAction = ClientHello THEN (* the only handshake msg a server should receive after a finished handshake *)
						SetState(ServerHandshake);
						handshakeState := ReceiveClientHello( data, ofs, len );
						Transition( dummy, Handshake, 0, 0, 0 )
					ELSE (* fatal error *)
						SendError( UnexpectedMessage )
					END
				END
			END;
		END Transition;

	(* **********************************************************************************
		UTILITIES
		********************************************************************************** *)

		PROCEDURE Create32RandomBytes( VAR data: ARRAY OF CHAR );
			VAR i, time, date, timestamp: LONGINT;
		BEGIN
			ASSERT( LEN( data ) >  31 );
			(* 4 bytes timestamp *)
			Clock.Get( date, time );
			timestamp := BIT.LXOR( date, time );
			FOR i := 3 TO 0 BY -1 DO
				data[ i ] := CHR( timestamp );
				timestamp := timestamp DIV 256
			END;
			(* 28 random bytes *)
			Utils.RandomBytes( data, 4, 28 )
		END Create32RandomBytes;

		(** Prints the correct S > C or C > S depending on current action and state *)
		PROCEDURE PrintDirection(send: BOOLEAN);
		BEGIN
			IF client & send THEN
				KernelLog.String("CLIENT: C > S ")
			ELSIF client & ~send THEN
				KernelLog.String("CLIENT: S > C ")
			ELSIF ~client & send THEN
				KernelLog.String("SERVER: S > C ")
			ELSE
				KernelLog.String("SERVER: C > S ")
			END
		END PrintDirection;

	BEGIN { ACTIVE }
		AwaitStateNotEqual(TCP.Unused);
		IF client THEN
			StartHandshake;
			REPEAT
				ReceiveRecord
			UNTIL (State() = TCP.Established) OR (State() = TCP.Closed);
			IF State() = TCP.Established THEN
				REPEAT
					ReceiveRecord
				UNTIL (State() = TCP.Closed) OR (in.res # Streams.Ok);
				Close
			END
		ELSE
			IF State() # TCP.Listen THEN
				(* listen for incoming messages *)
				REPEAT
					ReceiveRecord( )
				UNTIL (State() = TCP.Closed) OR (in.res # Streams.Ok);
				Close();
			END;
		END
	END Connection;
VAR
	version: ARRAY 2 OF CHAR;

BEGIN
	version[ 0 ] := CHR( 3 ); (* this implementation supports only TLS 1.0 = SSL 3.1 *)
	version[ 1 ] := CHR( 1 );
END TLS.


System.Free WebHTTPServerTools WebHTTPServer TLSServices TLS ~
Aos.Call WebHTTPServerTools.Start~