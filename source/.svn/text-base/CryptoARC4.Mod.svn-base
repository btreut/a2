MODULE CryptoARC4;	(** AUTHOR "F.N."; PURPOSE "ALLEGED RC4 - stream cipher - keylength: from 1 to 256 bytes"; *)

IMPORT
	Ciphers := CryptoCiphers, BIT;

TYPE
	Cipher* = OBJECT (Ciphers.Cipher)
		VAR
			s: ARRAY 256 OF CHAR; (* state array *)
			i, j: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			SetNameAndBlocksize( "arc4", 1 );
			isKeyInitialized := FALSE
		END Init;

		(** initialize arc4 key. keybits = [8..2048], MUST be multiple of 8. *)
		PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT);
		VAR
			keydata: ARRAY 256 OF CHAR;
			keybytes: LONGINT;
			temp: CHAR;
		BEGIN
			ASSERT( keybits MOD 8 = 0 ); 	ASSERT( keybits >  7); 	ASSERT( keybits < 2049 );
			InitKey^( src, keybits );
			keybytes:= keybits DIV 8;
			i := 0;  j := 0;
			FOR i := 0 TO 255 DO  s[ i ] := CHR( i )  END;
			FOR i := 0 TO 255 DO  keydata[ i ] := src[i MOD keybytes]  END;
			FOR i := 0 TO 255 DO
				j := ( j + ORD( s[i] ) + ORD( keydata[i] ) ) MOD 256;
				temp := s[ i ];
				s[ i ] := s[ j ];
				s[ j ] := temp
			END;
			isKeyInitialized := TRUE;
			FOR i := 0 TO 255 DO  keydata[ i ] := CHR( 0 )  END; (* sniffing protection *)
			i := 0; j := 0;
		END InitKey;

		(** encrypt len bytes starting at position ofs. *)
		PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR; ofs, len: LONGINT );
		VAR
			k, t: LONGINT;
			ch, temp: CHAR;
		BEGIN
			ASSERT( isKeyInitialized );
			FOR k := 0 TO len-1 DO
				(* generation of random byte ch *)
				i := ( i+1 ) MOD 256;
				j := ( j + ORD( s[ i ] ) ) MOD 256;
				temp := s[ i ];
				s[ i ] := s[ j ];
				s[ j ] := temp;
				t := (ORD( s[i] ) + ORD( s[j] )) MOD 256;
				ch := s[ t ];

				(* XOR random byte with next plaintext byte *)
				buf[ ofs + k ] := BIT.CXOR( buf[ ofs + k ], ch );
			END
		END Encrypt;

		(** decrypt len bytes starting at position ofs. *)
		PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR; ofs, len: LONGINT );
		BEGIN
			ASSERT( isKeyInitialized );
			Encrypt( buf, ofs, len )
		END Decrypt;

	END Cipher;


	(** create a new ARC4 cipher object *)
	PROCEDURE NewCipher*() : Ciphers.Cipher;
	VAR c: Cipher;
	BEGIN
		NEW( c ); RETURN c
	END NewCipher;

END CryptoARC4.

 