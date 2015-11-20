MODULE CryptoTestDH;

IMPORT D := CryptoDiffieHellman, B := CryptoBigNumbers, Kernel, Out := KernelLog;




	PROCEDURE Do( CONST nprime: ARRAY OF CHAR );
	VAR t: LONGINT;
		dh1, dh2: D.DH;
		pub1, pub2: B.BigNumber;
		k1, k2: B.BigNumber;
	BEGIN
		NEW( dh1, 0, nprime );
		pub1 := dh1.GenPubKey( );
		Out.String( "public key 1:" );  Out.Ln;  B.Print( pub1 );  Out.Ln;

		NEW( dh2, 0, nprime );
		pub2 := dh2.GenPubKey( );
		Out.String( "public key 2:" );  Out.Ln;  B.Print( pub2 );  Out.Ln;  Out.Ln;


		k1 := dh1.ComputeKey( pub2 );
		Out.String( "key a:" );  Out.Ln;  B.Print( k1 );  Out.Ln;

		t := Kernel.GetTicks( );
		k2 := dh2.ComputeKey( pub1 );
		t := Kernel.GetTicks( ) - t;
		Out.String( "key b:" );  Out.Ln; B.Print( k2 );   Out.Ln;

		IF (B.Cmp( k1, k2 ) = 0) THEN Out.String( "ok" ) ELSE Out.String( "failed" ) END;
		Out.String( " (" );  Out.Int( t, 1 );  Out.String( " ms)" );  Out.Ln;
	END Do;

	PROCEDURE SSL192*;
	BEGIN
		Do( "dh.ssl.192" )
	END SSL192;

	PROCEDURE SSL512*;
	BEGIN
		Do( "dh.ssl.512"  )
	END SSL512;

	PROCEDURE SSL1024*;
	BEGIN
		Do( "dh.ssl.1024"  )
	END SSL1024;

	PROCEDURE SSH*;
	BEGIN
		Do( "dh.ssh.group1" )
	END SSH;
	
	PROCEDURE SSL2048*;
	BEGIN
		Do( "dh.2048.MODP.256"  )
	END SSL2048;


END CryptoTestDH.

CryptoTestDH.SSL192
CryptoTestDH.SSL512
CryptoTestDH.SSL1024
CryptoTestDH.SSH
CryptoTestDH.SSL2048


SystemTools.Free CryptoTestDH CryptoDiffieHellman  ~
