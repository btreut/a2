MODULE CryptoTestHashes;	(** AUTHOR "F.N."; PURPOSE "Hashes Test"; *)

IMPORT
	Hashes := CryptoHashes,	Utils := CryptoUtils, Kernel, Out := KernelLog;

	(* data: binary, exphash: hexadecimal *)
	PROCEDURE CheckHash( CONST modname, data, exphash: ARRAY OF CHAR );
	VAR
		temp: ARRAY 1024 OF CHAR;
		hash: ARRAY 128 OF CHAR;
		h: Hashes.Hash;
	BEGIN
		h := Hashes.NewHash( modname );
		h.Initialize;
		h.Update( data, 0, LEN( data )-1 );
		h.GetHash( hash, 0 );
		Out.Ln; Out.String( "************************************" );
		Out.Ln; Out.String( "Checking: " ); Out.String( h.name );
		Out.Ln; Out.String( "Value:" ); Out.Ln; Out.String( "      '" ); Out.String( data ); Out.String( "'" );
		Out.Ln; Out.String( "Computed Hash:" ); Utils.PrintHex( hash, 0, h.size );
		Utils.Hex2Bin( exphash, 0, temp, 0, h.size );
		Out.Ln; Out.String( "Expected Hash:" ); Utils.PrintHex( temp, 0, h.size );
	END CheckHash;



	PROCEDURE MeasureTime( CONST modname: ARRAY OF CHAR );
	VAR
		c, i : LONGINT;
		milliTimer : Kernel.MilliTimer;
		buf: ARRAY 1024 OF CHAR;
		hash: ARRAY 1024 OF CHAR;
		h: Hashes.Hash;
	BEGIN
		h := Hashes.NewHash( modname );
		Out.Ln; Out.String( "************************************" );
		Out.Ln; Out.String( "Measuring: " ); Out.String( h.name ); Out.Ln;
		FOR i := 0 TO 999 DO buf[i] := 'a' END;
		Kernel.SetTimer(milliTimer, 0);
		FOR c := 1 TO 10 DO
			h.Initialize;
			FOR i := 1 TO 1000 DO h.Update( buf, 0, 1000 ) END;
			Out.Char( "." )
		END;
		h.GetHash( hash, 0 );
		Out.String( "hashed 10 MB in " ); Out.Int( Kernel.Elapsed(milliTimer), 0 ); Out.String( " msec" );
		Out.Ln;
	END MeasureTime;

	PROCEDURE TestMD5*;
	BEGIN
		CheckHash( "CryptoMD5", "", "D41D8CD98F00B204E9800998ECF8427E" );
		CheckHash( "CryptoMD5", 
						"abc", 
						"900150983CD24FB0D6963F7D28E17F72" );
		CheckHash( "CryptoMD5", 
						"abcdefghijklmnopqrstuvwxyz",
						"C3FCD3D76192E4007DFB496CCA67E13B");
		MeasureTime( "CryptoMD5" );
	END TestMD5;

	PROCEDURE TestSHA1*;
	BEGIN
		CheckHash( "CryptoSHA1", "", "DA39A3EE5E6B4B0D3255BFEF95601890AFD80709" );
		CheckHash( "CryptoSHA1", "abc", "A9993E364706816ABA3E25717850C26C9CD0D89D" );
		CheckHash( "CryptoSHA1", 
						"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
						"84983E441C3BD26EBAAE4AA1F95129E5E54670F1");
		MeasureTime( "CryptoSHA1" );
	END TestSHA1;

	PROCEDURE TestSHA256*;
	BEGIN
		CheckHash( "CryptoSHA256", 
				"abc", 
				"BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD" );
		CheckHash( "CryptoSHA256", 
				"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
				"248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1" );
		MeasureTime( "CryptoSHA256" );
	END TestSHA256;

	PROCEDURE TestSHA3*;
	BEGIN
		CheckHash( "CryptoSHA3", 
				"", 
				"a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a" );
		CheckHash( "CryptoSHA3", 
				"abc", 
				"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532" );
		CheckHash( "CryptoSHA3", 
				"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
				"41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376" );
		MeasureTime( "CryptoSHA3" );	
	END TestSHA3;

END CryptoTestHashes.


SystemTools.Free 
	CryptoTestHashes 
	CryptoSHA3 CryptoKeccakSponge CryptoKeccakF1600 
	CryptoMD5 CryptoSHA1 CryptoSHA256 
	CryptoHashes
	~

CryptoTestHashes.TestMD5  ~
CryptoTestHashes.TestSHA1  ~
CryptoTestHashes.TestSHA256  ~
CryptoTestHashes.TestSHA3  ~
