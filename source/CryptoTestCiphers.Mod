MODULE CryptoTestCiphers;	(** AUTHOR "F.N."; PURPOSE "Ciphers Test"; *)

IMPORT
	U := CryptoUtils,	Ciphers := CryptoCiphers, Kernel,	Commands, Out := KernelLog;

	PROCEDURE  Ecb1*(context : Commands.Context);
		VAR
			hex, bindata, binkey, modname, orig: ARRAY 64 OF CHAR; cipher: Ciphers.Cipher;
			keybits: LONGINT;
	BEGIN
		(* read in the parameter *)
		context.arg.SkipWhitespace; context.arg.String(modname);
		context.arg.SkipWhitespace; context.arg.Int(keybits, FALSE);
		(* encryption *)
		cipher := Ciphers.NewCipher( modname );
		hex := "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";
		U.Hex2Bin( hex, 0, binkey, 0, 24 );	U.Hex2Bin( hex, 0, bindata, 0, 8 );
		orig := bindata; orig[8] := 0X;
		cipher.InitKey( binkey, keybits );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encrypt-Decrypt-Test in ECB-mode: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( binkey, 0, keybits DIV 8 );
		Out.Ln; Out.String( "Original: " ); U.PrintHex( bindata, 0, 8 );
		cipher.Encrypt( bindata, 0, 8 );
		Out.Ln; Out.String( "Encrypted: " ); U.PrintHex( bindata, 0, 8 );
		(* decryption *)
		cipher.Decrypt( bindata, 0, 8 );
		Out.Ln; Out.String( "Decrypted: " ); U.PrintHex( bindata, 0, 8 );
		bindata[8] := 0X; 
		Out.Ln;
		IF bindata = orig THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Ecb1;

	PROCEDURE  Cbc1*(context : Commands.Context);
		VAR
			hex, bindata, binkey, modname, iv, orig: ARRAY 64 OF CHAR; cipher: Ciphers.Cipher;
			keybits: LONGINT;
	BEGIN
		(* read in the parameter *)
		context.arg.SkipWhitespace; context.arg.String(modname);
		context.arg.SkipWhitespace; context.arg.Int(keybits, FALSE);
				(* encryption *)
		cipher := Ciphers.NewCipher( modname );
		hex := "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";
		U.Hex2Bin( hex, 0, binkey, 0, 24 );	U.Hex2Bin( hex, 0, bindata, 0, 8 );
		cipher.InitKey( binkey, keybits );
		U.RandomBytes( iv, 0, cipher.blockSize );
		cipher.SetIV( iv, Ciphers.CBC );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encrypt-Decrypt-Test in CBC-mode: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( binkey, 0, keybits DIV 8 );
		Out.Ln; Out.String( "Original: " ); U.PrintHex( bindata, 0, 8 );
		orig := bindata;  orig[8] := 0X;
		cipher.Encrypt( bindata, 0, 8 );
		Out.Ln; Out.String( "Encrypted: " ); U.PrintHex( bindata, 0, 8 );
		(* decryption *)
		cipher.SetIV( iv, Ciphers.CBC );
		cipher.Decrypt( bindata, 0, 8 );
		Out.Ln; Out.String( "Decrypted: " ); U.PrintHex( bindata, 0, 8 );
		bindata[8] := 0X; 
		Out.Ln;
		IF bindata = orig THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Cbc1;
	
	PROCEDURE  Ctr1*(context : Commands.Context);
		VAR
			hex, bindata, binkey, modname, iv, orig: ARRAY 64 OF CHAR; cipher: Ciphers.Cipher;
			keybits: LONGINT;
	BEGIN
		(* read in the parameter *)
		context.arg.SkipWhitespace; context.arg.String(modname);
		context.arg.SkipWhitespace; context.arg.Int(keybits, FALSE);
				(* encryption *)
		cipher := Ciphers.NewCipher( modname );
		hex := "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";
		U.Hex2Bin( hex, 0, binkey, 0, 24 );	U.Hex2Bin( hex, 0, bindata, 0, 16 );
		cipher.InitKey( binkey, keybits );
		U.RandomBytes( iv, 0, cipher.blockSize );
		cipher.SetIV( iv, Ciphers.CTR );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encrypt-Decrypt-Test in CTR-mode: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( binkey, 0, keybits DIV 8 );
		Out.Ln; Out.String( "Original: " ); U.PrintHex( bindata, 0, 16 );
		orig := bindata;  orig[16] := 0X;
		cipher.Encrypt( bindata, 0, 16 );
		Out.Ln; Out.String( "Encrypted: " ); U.PrintHex( bindata, 0, 16 );
		(* decryption *)
		cipher.SetIV( iv, Ciphers.CTR );
		cipher.Decrypt( bindata, 0, 16 );
		Out.Ln; Out.String( "Decrypted: " ); U.PrintHex( bindata, 0, 16 );
		bindata[16] := 0X; 
		Out.Ln;
		IF bindata = orig THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Ctr1;
	

	(** encrypt input with key (ebc-mode). output is a testvector *)
	PROCEDURE  Ecb2*( CONST modname, input, output, key: ARRAY OF CHAR; datalen, keybits: LONGINT );
		VAR
			cipher: Ciphers.Cipher;
			temp1, temp2: ARRAY 256 OF CHAR;
	BEGIN
		cipher := Ciphers.NewCipher( modname );
		U.Hex2Bin( key, 0, temp1, 0, keybits DIV 8 );
		cipher.InitKey( temp1, keybits );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encryption-Test: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( temp1, 0, keybits DIV 8 );
		U.Hex2Bin( input, 0, temp1, 0, datalen );
		Out.Ln; Out.String( "plaintext: " ); U.PrintHex( temp1, 0, datalen );
		cipher.Encrypt( temp1, 0, datalen );
		Out.Ln; Out.String( "encryption: " ); U.PrintHex( temp1, 0, datalen );
		U.Hex2Bin( output, 0, temp2, 0, datalen );
		Out.Ln; Out.String( "correct encryption: " ); U.PrintHex( temp2, 0, datalen );
		Out.Ln;
		temp1[datalen] := 0X;  temp2[datalen] := 0X;
		IF temp1 = temp2 THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Ecb2;

	(** encrypt input with key (cbc-mode). output is a testvector *)
	PROCEDURE  Cbc2*( CONST modname, input, output, key, iv: ARRAY OF CHAR; datalen, keybits: LONGINT );
		VAR
			cipher: Ciphers.Cipher;
			temp1, temp2: ARRAY 64 OF CHAR;
	BEGIN
		cipher := Ciphers.NewCipher( modname );
		U.Hex2Bin( key, 0, temp1, 0, keybits DIV 8 );
		cipher.InitKey( temp1, keybits );
		U.Hex2Bin( iv, 0, temp2, 0, cipher.blockSize );
		cipher.SetIV( temp2, Ciphers.CBC );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encryption-Test: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( temp1, 0, keybits DIV 8 );
		U.Hex2Bin( input, 0, temp1, 0, datalen );
		Out.Ln; Out.String( "plaintext: " ); U.PrintHex( temp1, 0, datalen );
		cipher.Encrypt( temp1, 0, datalen ); 
		Out.Ln; Out.String( "encryption: " ); U.PrintHex( temp1, 0, datalen );
		U.Hex2Bin( output, 0, temp2, 0, datalen );
		Out.Ln; Out.String( "correct encryption: " ); U.PrintHex( temp2, 0, datalen );
		Out.Ln;
		temp1[datalen] := 0X;  temp2[datalen] := 0X;
		IF temp1 = temp2 THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Cbc2;
	
	(** encrypt input with key (counter-mode). output is a testvector *)
	PROCEDURE  Ctr2*( CONST modname, input, output, key, iv: ARRAY OF CHAR; datalen, keybits: LONGINT );
		VAR
			cipher: Ciphers.Cipher;
			temp1, temp2: ARRAY 64 OF CHAR;
	BEGIN
		cipher := Ciphers.NewCipher( modname );
		U.Hex2Bin( key, 0, temp1, 0, keybits DIV 8 );
		cipher.InitKey( temp1, keybits );
		U.Hex2Bin( iv, 0, temp2, 0, cipher.blockSize );
		cipher.SetIV( temp2, Ciphers.CTR );
		Out.Ln; Out.String( "*********************************" );
		Out.Ln; Out.String( "Encryption-Test: " ); Out.String( cipher.name );
		Out.Ln; Out.String( "Key: " ); U.PrintHex( temp1, 0, keybits DIV 8 );
		U.Hex2Bin( input, 0, temp1, 0, datalen );
		Out.Ln; Out.String( "plaintext: " ); U.PrintHex( temp1, 0, datalen );
		cipher.Encrypt( temp1, 0, datalen ); 
		Out.Ln; Out.String( "encryption: " ); U.PrintHex( temp1, 0, datalen );
		U.Hex2Bin( output, 0, temp2, 0, datalen );
		Out.Ln; Out.String( "correct encryption: " ); U.PrintHex( temp2, 0, datalen );
		Out.Ln;
		temp1[datalen] := 0X;  temp2[datalen] := 0X;
		IF temp1 = temp2 THEN  Out.String( "OK" )  ELSE  Out.String( "FAIL" )  END;
		Out.Ln
	END Ctr2;

	PROCEDURE MeasureTime*(context : Commands.Context);
		VAR
			buf, key: ARRAY 1024 OF CHAR;
			milliTimer : Kernel.MilliTimer;
			i, j, k, t, keybits: LONGINT;
			c: Ciphers.Cipher;
			modname, mode, iv: ARRAY 64 OF CHAR;
	BEGIN
		(* read in the parameter *)
		context.arg.SkipWhitespace; context.arg.String(modname);
		context.arg.SkipWhitespace; context.arg.String(mode);
		context.arg.SkipWhitespace; context.arg.Int(keybits, FALSE);
		(* measure time *)
		FOR i := 0 TO 1023 DO	buf[i] := 'a'	END;
		c := Ciphers.NewCipher( modname );
		c.InitKey( key, keybits );
		IF mode = "CBC" THEN	c.SetIV( iv, Ciphers.CBC )	END;
		Out.Ln; Out.String( "***********************************" );
		Out.Ln; Out.String( "Encrypting 100 MB with " ); Out.String( c.name );
		Kernel.SetTimer(milliTimer, 0);
		FOR k := 0 TO 9 DO
			Out.String( "." );
			FOR j := 0 TO 9 DO
				FOR i := 0 TO 999 DO	c.Encrypt( buf, 0, 1024 )	END(* 100 MB data *)
			END
		END;
		t := Kernel.Elapsed(milliTimer);
		Out.Int( t, 4 ); Out.String( " ms" ); Out.Ln;
	END MeasureTime;


	PROCEDURE DesEcb2*;
		VAR input, output, key: ARRAY 64 OF CHAR;
	BEGIN
		key := "0123456789ABCDEF";
		input := "4E6F772069732074";		output := "3FA40E8A984D4815";
		Ecb2( "CryptoDES", input, output, key, 8, 64 );
	END DesEcb2;
	
	PROCEDURE Des3Ecb2*;
		VAR input, output, key: ARRAY 64 OF CHAR;
	BEGIN
		key := "0123456789ABCDEF23456789ABCDEF01456789ABCDEF0123";
		input := "4E6F772069732074";		output := "314F8327FA7A09A8";
		Ecb2( "CryptoDES3", input, output, key, 8, 192 );
	END Des3Ecb2; 

	PROCEDURE  IdeaEcb2*;
		VAR input, output, key: ARRAY 64 OF CHAR;
	BEGIN
		key := "00010002000300040005000600070008";
		input := "0000000100020003";		output := "11FBED2B01986DE5";
		Ecb2( "CryptoIDEA", input, output, key, 8, 128 );
	END IdeaEcb2;

	PROCEDURE  AesEcb2*;
		VAR input, output, key: ARRAY 128 OF CHAR;
	BEGIN
		key := "8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b";
		input := "6bc1bee22e409f96e93d7e117393172a";		
		output := "bd334f1d6e45f25ff712a214571fa5cc";
		Ecb2( "CryptoAES", input, output, key, 16, 192 );
		
		key := "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4";
		input := "6bc1bee22e409f96e93d7e117393172a";
		output := "f3eed1bdb5d2a03c064b5a7e3db181f8";
		Ecb2( "CryptoAES", input, output, key, 16, 256 );
	END AesEcb2;
	
	
	PROCEDURE  Arc4Ecb2*;
		VAR input, output, key: ARRAY 64 OF CHAR;
	BEGIN
		key := "0123456789abcdef";
		input := "0123456789abcdef";		output := "75b7878099e0c596";
		Ecb2( "CryptoARC4", input, output, key, 8, 64 );
	END Arc4Ecb2;
	
	
	PROCEDURE  CastEcb2*;
		VAR input, output, key: ARRAY 64 OF CHAR;
	BEGIN
		key := "0123456712345678234567893456789A";
		input := "0123456789abcdef";		output := "238B4FE5847E44B2";
		Ecb2( "CryptoCAST", input, output, key, 8, 128 );
		
		output := "EB6A711A2C02271B";
		Ecb2( "CryptoCAST", input, output, key, 8, 80 );
		
		output := "7AC816D16E9B302E";
		Ecb2( "CryptoCAST", input, output, key, 8, 40 );
	END CastEcb2;
	
	
	

	PROCEDURE  DesCbc2*;
		VAR input, output, key, iv: ARRAY 64 OF CHAR;
	BEGIN
		key := "0123456789ABCDEF";		
		iv := "0123456789ABCDEF";
		input := "4E6F772069732074";		output := "96C3D4A6DC1C0117";
		Cbc2( "CryptoDES", input, output, key, iv, 8, 64 );
	END DesCbc2;

	PROCEDURE  IdeaCbc2*;
		VAR input, output, key, iv: ARRAY 64 OF CHAR;
	BEGIN
		key := "00010002000300040005000600070008";		
		iv := "0000000000000000";
		input := "0000000100020003";		output := "11FBED2B01986DE5";
		Cbc2( "CryptoIDEA", input, output, key, iv, 8, 128 );
	END IdeaCbc2;

	PROCEDURE  AesCbc2*;
		VAR input, output, key, iv: ARRAY 256 OF CHAR;
	BEGIN
		key := "2b7e151628aed2a6abf7158809cf4f3c";		
		iv := "000102030405060708090A0B0C0D0E0F";
		input := "6bc1bee22e409f96e93d7e117393172a";		
		output := "7649abac8119b246cee98e9b12e9197d";
		Cbc2( "CryptoAES", input, output, key, iv, 16, 128 );
		
		key := "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4";
		iv := "000102030405060708090A0B0C0D0E0F";
		input := "6bc1bee22e409f96e93d7e117393172a";
		output := "f58c4c04d6e5f1ba779eabfb5f7bfbd6";
		Cbc2( "CryptoAES", input, output, key, iv, 16, 256 );
	END AesCbc2;
	
	PROCEDURE  AesCtr2*;
		VAR input, output, key, iv: ARRAY 256 OF CHAR;
	BEGIN
		key := "2b7e151628aed2a6abf7158809cf4f3c";		
		iv := "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff";
		input := "6bc1bee22e409f96e93d7e117393172a";		
		output := "874d6191b620e3261bef6864990db6ce";
		Ctr2( "CryptoAES", input, output, key, iv, 16, 128 );
		
		key := "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4";
		iv := "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff";
		input := "6bc1bee22e409f96e93d7e117393172a";
		output := "601ec313775789a5b7a7f504bbf3d228";
		Ctr2( "CryptoAES", input, output, key, iv, 16, 256 );
	END AesCtr2;

END CryptoTestCiphers.


     SystemTools.Free  
     		CryptoTestCiphers CryptoDES3 CryptoDES CryptoIDEA 
     		CryptoARC4  CryptoCAST CryptoAES ~

     CryptoTestCiphers.DesEcb2 ~
     CryptoTestCiphers.Des3Ecb2 ~
     CryptoTestCiphers.IdeaEcb2 ~
     CryptoTestCiphers.Arc4Ecb2 ~
     CryptoTestCiphers.BlowfishEcb2 ~
     CryptoTestCiphers.TwofishEcb2 ~
     CryptoTestCiphers.CastEcb2 ~
	CryptoTestCiphers.AesEcb2 ~

     CryptoTestCiphers.DesCbc2 ~
     CryptoTestCiphers.IdeaCbc2 ~
     CryptoTestCiphers.AesCbc2 ~
     
     CryptoTestCiphers.AesCtr2 ~
     
     

     CryptoTestCiphers.Ecb1	CryptoDES	64 ~
     CryptoTestCiphers.Ecb1	CryptoDES3	192 ~
     CryptoTestCiphers.Ecb1	CryptoIDEA	128 ~
     CryptoTestCiphers.Ecb1	CryptoARC4	128 ~
     CryptoTestCiphers.Ecb1	CryptoCAST	128 ~

     CryptoTestCiphers.Cbc1	CryptoDES	64 ~
     CryptoTestCiphers.Cbc1	CryptoDES3	192 ~
     CryptoTestCiphers.Cbc1	CryptoIDEA	128 ~
     
     CryptoTestCiphers.Ctr1		CryptoAES	128 ~
     CryptoTestCiphers.Ctr1		CryptoAES	256 ~

     
     CryptoTestCiphers.MeasureTime	CryptoDES	ECB 64 ~
     CryptoTestCiphers.MeasureTime	CryptoDES	CBC 64 ~
     CryptoTestCiphers.MeasureTime	CryptoDES3	ECB 192 ~
     CryptoTestCiphers.MeasureTime	CryptoDES3	CBC 192 ~
     CryptoTestCiphers.MeasureTime	CryptoAES	ECB 128 ~
     CryptoTestCiphers.MeasureTime	CryptoAES	CBC 128 ~
     CryptoTestCiphers.MeasureTime	CryptoIDEA	ECB 128 ~
     CryptoTestCiphers.MeasureTime	CryptoIDEA	CBC 128 ~
     CryptoTestCiphers.MeasureTime	CryptoARC4	ECB 128 ~


	
