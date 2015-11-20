MODULE SSHAuthorize; 	(* g.f.	2001.12.12 *)

IMPORT T := SSHTransport, U := CryptoUtils, B := CryptoBigNumbers, RSA := CryptoRSA, G := SSHGlobals,
	SHA1 := CryptoSHA1, Strings, Out := KernelLog, Files, WMDialogs, Beep;

TYPE
	Connection* = T.Connection;

CONST
	Closed* = T.Closed;  Connected* = T.Connected;

	ServiceRequest = 5X;  ServiceAccept = 6X;

	UserauthRequest = 32X;  UserauthFailure = 33X;
	UserauthSuccess = 34X;  UserauthBanner = 35X;
	UserauthPkOk = 3CX;

TYPE
	Password = POINTER TO RECORD
		next: Password;
		host, user, pw: ARRAY 64 OF CHAR;
	END;

VAR
	passwords: Password;

	privKey, pubKey: RSA.Key;
	hexd: ARRAY 17 OF CHAR;

	PROCEDURE GetPW( CONST host, user: ARRAY OF CHAR; VAR pw: ARRAY OF CHAR );
	VAR n: Password;
	BEGIN
		n := passwords;  pw := "";
		WHILE n # NIL DO
			IF (n.host = host) & (n.user = user) THEN COPY( n.pw, pw );  RETURN  END;
			n := n.next
		END
	END GetPW;


	PROCEDURE AddPW( CONST host, user, pw: ARRAY OF CHAR );
	VAR n, p: Password;
	BEGIN
		n := passwords;
		WHILE n # NIL DO
			IF (n.host = host) & (n.user = user) THEN
				(* replace pw *)
				COPY( pw, n.pw );  RETURN
			END;
			p := n;  n := n.next
		END;
		IF p = NIL THEN  NEW( passwords );  p := passwords
		ELSE  NEW( p.next );  p := p.next
		END;
		p.next := NIL;
		COPY( host, p.host );
		COPY( user, p.user );
		COPY( pw, p.pw )
	END AddPW;




	PROCEDURE RequestService( VAR ssh: Connection;  CONST service: ARRAY OF CHAR ): BOOLEAN;
	VAR p: T.Packet;  d: LONGINT;  buf: ARRAY 256 OF CHAR;
	BEGIN
		NEW( p, ServiceRequest, 256 );
		p.AppString( service );
		ssh.SendPacket( p );

		IF ssh.ReceivePacket( buf, d ) = ServiceAccept THEN  RETURN TRUE
		ELSE  ssh.Disconnect( 11, "" );  RETURN FALSE
		END
	END RequestService;


	PROCEDURE RequestAuthorizeNone( ssh: Connection;  CONST user: ARRAY OF CHAR ): BOOLEAN;
	VAR p: T.Packet;  msg: ARRAY 512 OF CHAR;  len: LONGINT;
	BEGIN
		NEW( p, UserauthRequest, 256 );
		p.AppString( user );
		p.AppString( "ssh-connection" );
		p.AppString( "none" );

		ssh.SendPacket( p );
		RETURN ssh.ReceivePacket( msg, len ) = UserauthSuccess
	END RequestAuthorizeNone;


	PROCEDURE RequestConnPW( ssh: Connection;  CONST user, host: ARRAY OF CHAR; try: LONGINT );
	VAR p: T.Packet;  headline, pw: ARRAY 64 OF CHAR;  ignore: LONGINT;
	BEGIN
		headline := "SSH: Enter Password for ";
		Strings.Append( headline, user );
		Strings.Append( headline, "@" );
		Strings.Append( headline, host );

		NEW( p, UserauthRequest, 1024 );
		p.AppString( user );
		p.AppString( "ssh-connection" );
		p.AppString( "password" );
		p.AppChar( 0X );
		IF try = 1 THEN  GetPW( host, user, pw ) ELSE  pw := ""  END;
		IF pw = "" THEN
			Beep.Beep( 1000 );
			ignore := WMDialogs.QueryPassword( headline, pw);
			AddPW( host, user, pw );
		END;
		p.AppString( pw );

		ssh.SendPacket( p )
	END RequestConnPW;


	PROCEDURE AuthorizePasswd( ssh: Connection; CONST host, user: ARRAY OF CHAR ): BOOLEAN;
	VAR
		msg: ARRAY 2048 OF CHAR;
		len: LONGINT;  try: INTEGER;
	BEGIN
		try := 1;
		RequestConnPW( ssh, user, host, try );
		LOOP
			CASE ssh.ReceivePacket( msg, len ) OF
			| UserauthBanner:
					U.PrintBufferString( msg, 1 ); Out.Ln;
			| UserauthSuccess:
					Out.String( "password authentication succeeded" );  Out.Ln;
					RETURN TRUE
			| UserauthFailure:
					IF try > 2 THEN
						Out.String( "password authentication failed" );  Out.Ln;
						RETURN FALSE
					ELSE
						INC( try );
						RequestConnPW( ssh, user, host, try )
					END
			ELSE
				Out.String( "SSHAuthorization.AuthorizePasswd: protocol error: got " );  Out.Int( ORD( msg[0] ), 3 );  Out.Ln;
				RETURN FALSE
			END
		END
	END AuthorizePasswd;


	PROCEDURE MakePubKeyBlob( VAR buf: ARRAY OF CHAR;  VAR len: LONGINT );
	BEGIN
		len := 0;
		U.PutString( buf, len, "ssh-rsa" );
		U.PutBigNumber( buf, len, pubKey.exponent );
		U.PutBigNumber( buf, len, pubKey.modulus );
	END MakePubKeyBlob;



	PROCEDURE CheckAuthorizeKey( ssh: Connection;  CONST user: ARRAY OF CHAR ): BOOLEAN;
	VAR p: T.Packet;  buf: ARRAY 512 OF CHAR; len :LONGINT;
	BEGIN
		MakePubKeyBlob( buf, len );

		NEW( p, UserauthRequest, 1024 );
		p.AppString( user );
		p.AppString( "ssh-connection" );
		p.AppString( "publickey" );
		p.AppChar( 0X );  (* false *)
		p.AppString( "ssh-rsa" );
		p.AppArray( buf, 0, len );

		ssh.SendPacket( p );
		IF ssh.ReceivePacket( buf, len ) # UserauthPkOk THEN
			U.PrintBufferString( buf, 1 );  Out.Ln;
			RETURN FALSE
		END;
		RETURN TRUE
	END CheckAuthorizeKey;


	PROCEDURE RequestAuthorizeKey( ssh: Connection;  CONST user: ARRAY OF CHAR ): BOOLEAN;
	CONST
		Asn1DerSha1 = "3021300906052B0E03021A05000414";
		HashLen = 20;
		MsgLen = 15 + HashLen;
		EmSize = 256;
		PadLen = EmSize - MsgLen;
	VAR
		p: T.Packet;
		blob, sig, buf: ARRAY 512 OF CHAR; pos, blen, len :LONGINT;
		signature: B.BigNumber;
		sha1: SHA1.Hash;
		em: ARRAY EmSize OF CHAR;
		i: LONGINT;
	BEGIN
		ASSERT( privKey.size = 2048 );
		MakePubKeyBlob( blob, blen );
		NEW( sha1 );  sha1.Initialize;

		pos := 0;
		U.PutArray( buf, pos, ssh.sessionId, 0, 20 );
		U.PutChar( buf, pos, UserauthRequest );
		U.PutString( buf, pos, user );
		U.PutString( buf, pos, "ssh-connection" );
		U.PutString( buf, pos, "publickey" );
		U.PutChar( buf, pos, 1X );
		U.PutString( buf, pos, "ssh-rsa" );
		U.PutArray( buf, pos, blob, 0, blen );
		sha1.Update( buf, 0, pos );

		(* padding PKCS1 type 1 *)
		em[0] := 0X;  em[1] := 1X;
		FOR i := 2 TO PadLen - 2 DO em[i] := 0FFX  END;
		em[PadLen - 1] := 0X;

		U.Hex2Bin( Asn1DerSha1, 0, em, EmSize - MsgLen, 15 );
		sha1.GetHash( em, EmSize - HashLen );

		signature := privKey.Sign( em, EmSize );
		pos := 0;
		U.PutString( sig, pos, "ssh-rsa" );
		U.PutBigNumber( sig, pos, signature );

		NEW( p, UserauthRequest, 1024 );
		p.AppString( user );
		p.AppString( "ssh-connection" );
		p.AppString( "publickey" );
		p.AppChar( 1X );  (* true *)
		p.AppString( "ssh-rsa" );
		p.AppArray( blob, 0, blen );
		p.AppArray( sig, 0, pos );

		ssh.SendPacket( p );
		IF ssh.ReceivePacket( buf, len ) # UserauthSuccess THEN
			U.PrintBufferString( buf, 1 );  Out.Ln;
			Out.String( "public key  authentication failed" );  Out.Ln;
			RETURN FALSE
		END;
		Out.String( "public key authentication succeeded" );  Out.Ln;
		RETURN TRUE
	END RequestAuthorizeKey;

	PROCEDURE AuthorizeKey( ssh: Connection; CONST user: ARRAY OF CHAR ): BOOLEAN;
	CONST
		headline = "enter passphrase for opening your private key";
	VAR
		f: Files.File; r: Files.Reader; i, ignore: LONGINT;
		pw, str: ARRAY 64 OF CHAR;
	BEGIN
		IF privKey = NIL THEN
			f := Files.Old( G.PrivateKeyFile );
			IF f = NIL THEN
				Out.String( "private key '" ); Out.String( G.PrivateKeyFile );
				Out.String( "' not found" ); Out.Ln;
				RETURN FALSE
			END;
			Files.OpenReader( r, f, 0 );  i := 0;
			REPEAT
				ignore := WMDialogs.QueryPassword( headline, pw );
				r.SetPos( 0 );
				privKey := RSA.LoadPrivateKey( r, pw );
				INC( i )
			UNTIL (privKey # NIL) OR (i = 3);
			IF privKey = NIL THEN
				Out.String( "### error: wrong passphrase" ); Out.Ln;  RETURN FALSE
			END;
		END;
		f := Files.Old( G.PublicKeyFile );
		IF f = NIL THEN
			Out.String( "### error: public key not found" );  Out.Ln;
			RETURN FALSE
		END;
		Files.OpenReader( r, f, 0 );
		IF r.GetString( str ) & (str = "ssh-rsa") THEN
			pubKey := RSA.LoadPublicKey( r )
		END;

		IF CheckAuthorizeKey( ssh, user ) THEN
			RETURN RequestAuthorizeKey( ssh, user )
		END;
		RETURN FALSE
	END AuthorizeKey;


	(** Open an outhorized SSH connection, returns NIL on failure *)
	PROCEDURE OpenConnection*( CONST host, user: ARRAY OF CHAR ): Connection;
	VAR
		ssh: Connection; authorized: BOOLEAN;
	BEGIN
		NEW( ssh, host );
		IF ssh.state = Connected THEN
			IF RequestService( ssh, "ssh-userauth" ) THEN
				authorized := RequestAuthorizeNone( ssh, user );
				IF ~authorized THEN
					Out.String( "trying public key authentication" ); Out.Ln;
					authorized := AuthorizeKey( ssh, user );
				END;
				IF ~authorized THEN
					Out.String( "trying password authentication" ); Out.Ln;
					authorized := AuthorizePasswd( ssh, host, user )
				END;
				IF ~authorized THEN
					ssh.Disconnect( 11, "" );  RETURN NIL
				END;
				RETURN ssh
			ELSE
				RETURN NIL
			END
		ELSE
			RETURN NIL
		END
	END OpenConnection;

BEGIN
	hexd := "0123456789ABCDEF"
END SSHAuthorize.



