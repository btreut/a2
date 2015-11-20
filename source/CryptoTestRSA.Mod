MODULE CryptoTestRSA;

IMPORT
	RSA := CryptoRSA, B := CryptoBigNumbers, P := CryptoPrimes,
	Files, Out := KernelLog, WMDialogs;


CONST
	Size = 1024;
	PrivateKeyFile = "SSH.RSAKey.priv";
	PublicKeyFile = "SSH.RSAKey.pub";

	PROCEDURE Test1*;
	VAR
		pub, priv: RSA.Key;
		p, q, e, signature: B.BigNumber;
		digest: ARRAY 64 OF CHAR;
	BEGIN
		Out.String( "generating RSA Keys" ); Out.Ln;
		p := P.NewPrime( Size DIV 2, FALSE );
		Out.String("p = "); B.Print( p ); Out.Ln;

		q := P.NewPrime( Size DIV 2, FALSE );
		Out.String("q = "); B.Print( q ); Out.Ln;
		B.AssignInt( e, 3 );

		RSA.MakeKeys( p, q, e, "Test Key", pub, priv );
		digest := "Everyone gets Friday off her panties.";
		signature :=  priv.Sign( digest, 32 );
		IF signature # NIL THEN
			IF pub.Verify( digest, 32, signature ) THEN
				Out.String( "sign : verify  ok" ); Out.Ln;
			ELSE
				Out.String( "sign : verify failed" ); Out.Ln;
			END
		ELSE
			Out.String( "error: wrong passphrase for private key" ); Out.Ln
		END;
	END Test1;

	PROCEDURE TestRSAKeyFiles*;
	CONST
		headline = "enter passphrase for opening your private key";
	VAR
		pub, priv: RSA.Key;
		signature: B.BigNumber;
		pw, digest, str: ARRAY 64 OF CHAR;
		f: Files.File; r: Files.Reader;
		i, ignore: LONGINT;
	BEGIN
		f := Files.Old( PrivateKeyFile ); Files.OpenReader( r, f, 0 );
		i := 0;
		REPEAT
			ignore := WMDialogs.QueryPassword( headline, pw );
			r.SetPos( 0 );
			priv := RSA.LoadPrivateKey( r, pw );
			INC( i )
		UNTIL (priv # NIL) OR (i = 3);
		IF priv = NIL THEN
			Out.String( "wrong passphrase" ); Out.Ln;  RETURN
		END;

		f := Files.Old( PublicKeyFile ); Files.OpenReader( r, f, 0 );
		r.SkipWhitespace; r.String( str );
		IF str = "ssh-rsa" THEN
			pub := RSA.LoadPublicKey( r )
		END;

		digest := "Everyone gets Friday off her panties.";
		signature :=  priv.Sign( digest, 32 );
		IF pub.Verify( digest, 32, signature ) THEN
			Out.String( "sign : verify  ok" ); Out.Ln;
		ELSE
			Out.String( "sign : verify failed" ); Out.Ln;
		END
	END TestRSAKeyFiles;


END CryptoTestRSA.


SystemTools.Free CryptoTestRSA CryptoRSA CryptoPrimes CryptoBigNumbers~

CryptoTestRSA.Test1 ~

CryptoTestRSA.TestRSAKeyFiles ~
