MODULE CryptoSHA256;	(** AUTHOR "G.F."; PURPOSE "SHA-256"; *)

IMPORT
	S := SYSTEM,  Hashes := CryptoHashes, U := CryptoUtils;

CONST
	BlockSize = 64;
	
VAR 
	K256: ARRAY 64 OF LONGINT;
	

TYPE
	Hash* = OBJECT (Hashes.Hash)
		VAR
			hash: ARRAY 8 OF LONGINT;		(* state *)
			Nl, Nh: LONGINT;
			cdata: ARRAY BlockSize OF CHAR;	(* pending data *)
			cn: LONGINT	(* number of chars in cdata *)

		PROCEDURE &Init*;
		BEGIN
			SetNameAndSize( "sha256", 32 ); 
			initialized := FALSE
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			hash[0] := 6A09E667H;	hash[1] := LONGINT( 0BB67AE85H );
			hash[2] := 3C6EF372H;	hash[3] := LONGINT( 0A54FF53AH );
			hash[4] := 510E527FH;	hash[5] := LONGINT( 09B05688CH );
			hash[6] := 1F83D9ABH;	hash[7] := 5BE0CD19H;
			Nl := 0;
			Nh := 0;
			cn := 0;
			initialized := TRUE
		END Initialize;
		
		PROCEDURE HashBlock( CONST buf: ARRAY OF CHAR;  pos: LONGINT );
		VAR a, b, c, d, e, f, g, h, s0, s1, s, T1, T2, i: LONGINT;
			X: ARRAY 16 OF LONGINT
		BEGIN
			a := hash[0];  b := hash[1];  c := hash[2];  d := hash[3];
			e := hash[4];  f := hash[5];  g := hash[6];  h := hash[7];
				
			FOR i := 0 TO 63 DO
				IF i < 16 THEN
					X[i] := U.IntFromBufferBE( buf, pos );  INC( pos, 4 )
				ELSE
					s0 := sigma0( S.VAL( SET, X[(i + 1) MOD 16] ) );
					s1 := sigma1( S.VAL( SET, X[(i + 14) MOD 16] ) );
					s := s0 + s1 + X[(i + 9) MOD 16];
					INC( X[i MOD 16], s );  
				END;
				T1 := X[i MOD 16] + h + Sigma1Ch( S.VAL(SET, e), f, g) + K256[i];
				T2 := Sigma0Maj( S.VAL(SET, a), b, c );
				h := g;  g := f;  f := e;  e := d + T1;
				d := c;  c := b;  b := a;  a := T1 + T2;
			END;
			
			INC( hash[0], a );  INC( hash[1],  b );  INC( hash[2],  c );  INC( hash[3],  d );
			INC( hash[4], e );  INC( hash[5],  f );  INC( hash[6],  g );  INC( hash[7],  h );
		END HashBlock;
	
	
		PROCEDURE HashContextBlock;
		BEGIN
			HashBlock( cdata, 0 );  cn := 0
		END HashContextBlock;
		
		
		(** data: value to be hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: LONGINT );
			VAR n, i, l: LONGINT;
		BEGIN
			ASSERT( initialized );
			l := Nl + len*8;
			IF l < Nl THEN INC( Nh )  (* overflow *)  END;
			Nh := Nh + ASH( len, -29 );  Nl := l;

			IF cn > 0 THEN
				IF cn + len < BlockSize THEN
					i := cn;  INC( cn, len );
					WHILE i < cn  DO  cdata[i] := data[pos];  INC( i ); INC( pos )  END;
					RETURN
				ELSE
					WHILE cn < BlockSize  DO
						cdata[cn] := data[pos];  INC( cn );  INC( pos );  DEC( len )
					END;
					HashContextBlock;
				END
			END;

			n := 0;
			WHILE n < len DIV BlockSize  DO  HashBlock( data, pos );  INC( n )  END;
			len := len MOD BlockSize;
			WHILE cn < len  DO cdata[cn] := data[pos];  INC( cn );  INC( pos )  END;
		END Update;

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
			VAR p, i: LONGINT;
		BEGIN
			cdata[cn] := 80X;  INC( cn );
			IF cn > BlockSize - 8 THEN
				WHILE cn < BlockSize  DO  cdata[cn] := 0X;  INC( cn )  END;
				HashContextBlock;
			END;
			p := BlockSize - 8;
			WHILE cn < p  DO  cdata[cn] := 0X;  INC( cn )  END;
			U.IntToBufferBE( Nh, cdata, p );  U.IntToBufferBE( Nl, cdata, p + 4 );
			HashContextBlock;
			
			FOR i := 0 TO 7 DO  U.IntToBufferBE( hash[i], buf, pos );  INC( pos, 4 )  END;
		END GetHash;

	END Hash;



	(* PROCEDURES *******************************************************************************)

	(** get an instance of SHA256 *)
	PROCEDURE NewHash*( ) : Hashes.Hash;
		VAR h: Hash;
	BEGIN
		NEW( h );  RETURN h
	END NewHash;



	PROCEDURE Sigma0Maj( x: SET; y, z: LONGINT ): LONGINT;
	VAR a, b: LONGINT; 
	BEGIN 
		a := S.VAL( LONGINT, ROT( x , 30 ) / ROT( x, 19 ) / ROT( x, 10 ) );
		b := S.VAL( LONGINT, (x * S.VAL( SET, y )) / 
							  (x * S.VAL( SET, z )) / (S.VAL( SET, y ) * S.VAL( SET, z )) );
		RETURN a + b
	END Sigma0Maj;
	
	PROCEDURE Sigma1Ch( x: SET;  y, z: LONGINT ): LONGINT;
	VAR a, b: LONGINT; 
	BEGIN 
		a := S.VAL( LONGINT, ROT( x , 26 ) / ROT( x, 21 ) / ROT( x, 7 ) );
		b := S.VAL( LONGINT, (x * S.VAL( SET, y )) / ((-x ) * S.VAL( SET, z )) );
		RETURN a + b
	END Sigma1Ch;

	PROCEDURE sigma0( x: SET ): LONGINT;
	BEGIN 
		RETURN S.VAL( LONGINT, ROT( x , 25 ) / ROT( x, 14 ) / LSH( x, -3 ) )
	END sigma0;
	
	PROCEDURE sigma1( x: SET ): LONGINT;
	BEGIN 
		RETURN S.VAL( LONGINT, ROT( x , 15 ) / ROT( x, 13 ) / LSH( x, -10 ) )
	END sigma1;
	


	
	PROCEDURE InitializeK;
	VAR 
		buf: U.InitBuffer; i: LONGINT;
	BEGIN
		NEW( buf, 2048 );
		buf.Add( "428A2F98 71374491 B5C0FBCF E9B5DBA5  " );
		buf.Add( "3956C25B 59F111F1 923F82A4 AB1C5ED5  " );
		buf.Add( "D807AA98 12835B01 243185BE 550C7DC3  " );
		buf.Add( "72BE5D74 80DEB1FE 9BDC06A7 C19BF174  " );
		buf.Add( "E49B69C1 EFBE4786 0FC19DC6 240CA1CC  " );
		buf.Add( "2DE92C6F 4A7484AA 5CB0A9DC 76F988DA  " );
		buf.Add( "983E5152 A831C66D B00327C8 BF597FC7  " );
		buf.Add( "C6E00BF3 D5A79147 06CA6351 14292967  " );
		buf.Add( "27B70A85 2E1B2138 4D2C6DFC 53380D13  " );
		buf.Add( "650A7354 766A0ABB 81C2C92E 92722C85  " );
		buf.Add( "A2BFE8A1 A81A664B C24B8B70 C76C51A3  " );
		buf.Add( "D192E819 D6990624 F40E3585 106AA070  " );
		buf.Add( "19A4C116 1E376C08 2748774C 34B0BCB5  " );
		buf.Add( "391C0CB3 4ED8AA4A 5B9CCA4F 682E6FF3  " );
		buf.Add( "748F82EE 78A5636F 84C87814 8CC70208  " );
		buf.Add( "90BEFFFA A4506CEB BEF9A3F7 C67178F2  " );
		FOR i := 0 TO 63 DO K256[i] := buf.GetInt()  END;
	END InitializeK;

BEGIN
	InitializeK
END CryptoSHA256.