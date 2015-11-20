MODULE Checksum;	(** AUTHOR "GF"; PURPOSE "compute md5, sha1 and sha3 checksums" *)

IMPORT Commands, Files, Streams, Hashes := CryptoHashes;

VAR 
	hexdigits: ARRAY 17 OF CHAR;


	PROCEDURE MD5*( c: Commands.Context );
	BEGIN
		Do( c, Hashes.NewHash( "CryptoMD5" ) )
	END MD5;
	
	PROCEDURE SHA1*( c: Commands.Context );
	BEGIN
		Do( c, Hashes.NewHash( "CryptoSHA1" ) )
	END SHA1;

	PROCEDURE SHA3*( c: Commands.Context );
	VAR h: Hashes.Hash;
	BEGIN
		h := Hashes.NewHash( "CryptoSHA3" );
	(*	h.SetNameAndSize( "", 32 )	*)	(* 256 bit, default *)
		Do( c, h )
	END SHA3;
	
	
	PROCEDURE Do( c: Commands.Context; h: Hashes.Hash );
	VAR 
		f: Files.File;  r: Files.Reader;
		fname: ARRAY 256 OF CHAR;
	BEGIN
		WHILE OpenNextFile( c, f ) DO
			Files.OpenReader( r, f, 0 );
			ComputeHash( r, h, c.out );
			f.GetName( fname );
			c.out.String( '    ' );  c.out.String( fname );  c.out.Ln;		
			c.out.Update		
		END;
	END Do;

	PROCEDURE OpenNextFile( c: Commands.Context;  VAR f: Files.File ): BOOLEAN;
	VAR 
		fname: ARRAY 64 OF CHAR;
	BEGIN
		IF c.arg.GetString( fname ) THEN
			f := Files.Old( fname );
			IF f = NIL THEN
				c.error.String( "File " );  c.error.String( fname );  c.error.String( " not fond" ); 
				c.error.Ln; c.error.Update;
				RETURN FALSE
			ELSE
				RETURN TRUE
			END
		ELSE
			RETURN FALSE
		END
	END OpenNextFile;


	PROCEDURE ComputeHash( r: Files.Reader; h: Hashes.Hash; out: Streams.Writer );
	VAR 
		buf: ARRAY 128 OF CHAR;  
		got, i, x: LONGINT;
	BEGIN
		h.Initialize;
		WHILE r.Available() > 0 DO
			r.Bytes( buf, 0, 64, got );
			h.Update( buf, 0, got )
		END;
		h.GetHash( buf, 0 );  
		FOR i := 0 TO h.size - 1 DO
			x := ORD( buf[i] );
			out.Char( hexdigits[x DIV 16] );
			out.Char( hexdigits[x MOD 16] )
		END;
	END ComputeHash;


BEGIN 
	hexdigits := "0123456789abcdef"
END Checksum.



	Checksum.MD5  
			Files.Mod 
			Unix.UnixFiles.Mod
			Loader.Mod
			NoFile.Mod
			~
	
	Checksum.SHA1  Files.Mod  ~
	
	Checksum.SHA3  Files.Mod  ~
	
	SystemTools.Free Checksum ~
