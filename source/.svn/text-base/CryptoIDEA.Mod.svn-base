MODULE CryptoIDEA;   (* g.f.	2002.07.19 *)

IMPORT S := SYSTEM, Ciphers := CryptoCiphers;

TYPE
	CARD16 = LONGINT;  LI = LONGINT;
	Block = ARRAY 4 OF CARD16;
	KeyBlock = ARRAY 9, 6 OF CARD16;

	Cipher* = OBJECT (Ciphers.Cipher)
			VAR
				ekeys, dkeys: KeyBlock;
				iv: Block;

				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT );
				BEGIN
					ASSERT( keybits = 128 );
					InitKey^( src, keybits );
					CalcEncryptionKeys( src, ekeys );
					CalcDecryptionKeys( ekeys, dkeys )
				END InitKey;

				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
				VAR i: INTEGER;
				BEGIN
					SetIV^( src, mode );   (* set mode *)
					FOR i := 0 TO 3 DO  iv[i] := ORD( src[2*i + 1] )*256 + ORD( src[2*i] )  END
				END SetIV;

				PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR i: LONGINT;
				BEGIN
					ASSERT( isKeyInitialized & (mode IN {Ciphers.ECB, Ciphers.CBC}) );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO  EncryptBlock( buf, ofs + i );  INC( i, blockSize );   END
				END Encrypt;

				PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR i: LONGINT;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO  DecryptBlock( buf, ofs + i );  INC( i, blockSize );   END
				END Decrypt;

				PROCEDURE EncryptBlock( VAR buf: ARRAY OF CHAR;  p: LONGINT );
				VAR b: Block;  i, j: LONGINT;
				BEGIN
					j := p;
					FOR i := 0 TO 3 DO  (* big endian !! *)
						b[i] := ORD( buf[j] )*256 + ORD( buf[j + 1] );  INC( j, 2 );
						IF mode = Ciphers.CBC THEN  b[i] := Xor( b[i], iv[i] )  END
					END;
					IDEACipher( b, ekeys );  j := p;
					FOR i := 0 TO 3 DO  (* big endian !! *)
						buf[j] := CHR( b[i] DIV 256 MOD 256 );  INC( j );
						buf[j] := CHR( b[i] MOD 256 );  INC( j )
					END;
					IF mode = Ciphers.CBC THEN  iv := b  END
				END EncryptBlock;

				PROCEDURE DecryptBlock( VAR buf: ARRAY OF CHAR;  p: LONGINT );
				VAR b0, b: Block;  i, j: LONGINT;
				BEGIN
					j := p;
					FOR i := 0 TO 3 DO  (* big endian !! *)
						b[i] := ORD( buf[j] )*256 + ORD( buf[j + 1] );  INC( j, 2 );
						IF mode = Ciphers.CBC THEN  b0[i] := b[i]  END
					END;
					IDEACipher( b, dkeys );  j := p;
					FOR i := 0 TO 3 DO  (* big endian !! *)
						IF mode = Ciphers.CBC THEN  b[i] := Xor( b[i], iv[i] );  iv[i] := b0[i]  END;
						buf[j] := CHR( b[i] DIV 256 MOD 256 );  INC( j );
						buf[j] := CHR( b[i] MOD 256 );  INC( j );
					END
				END DecryptBlock;

				PROCEDURE & Init*;
				BEGIN
					SetNameAndBlocksize( "idea", 8 );
				END Init;

			END Cipher;

	PROCEDURE NewCipher*(): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;


(*-------------------------------------------------------------------------------*)


	PROCEDURE Inverse( x: CARD16 ): CARD16;
	VAR n1, n2, q, r, b1, b2, t: LONGINT;
	BEGIN
		IF x = 0 THEN  b2 := 0
		ELSE
			n1 := 10001H;  n2 := x MOD 10000H;  b2 := 1;  b1 := 0;
			REPEAT
				r := n1 MOD n2;  q := (n1 - r) DIV n2;
				IF r = 0 THEN
					IF b2 < 0 THEN  INC( b2, 10001H )  END
				ELSE
					n1 := n2;  n2 := r;  t := b2;  b2 := b1 - q*b2;  b1 := t
				END
			UNTIL r = 0
		END;
		RETURN b2 MOD 10000H
	END Inverse;

	PROCEDURE shor( a, b: CARD16 ): CARD16;
	BEGIN
		RETURN S.VAL( LI, S.VAL( SET, LSH( a, 9 ) ) + S.VAL( SET, LSH( b, -7 ) ) ) MOD 10000H;
	END shor;

	PROCEDURE CalcEncryptionKeys( CONST src: ARRAY OF CHAR;  VAR e: KeyBlock );
	VAR s: ARRAY 54 OF CARD16;
		i, j, p: INTEGER;
	BEGIN
		p := 0;
		FOR i := 0 TO 7 DO  s[i] := ORD( src[p] )*256 + ORD( src[p + 1] );  INC( p, 2 )  END;
		i := 8;  j := 0;
		WHILE i < 53 DO
			s[i + 0] := shor( s[j + 1], s[j + 2] );
			s[i + 1] := shor( s[j + 2], s[j + 3] );
			s[i + 2] := shor( s[j + 3], s[j + 4] );
			s[i + 3] := shor( s[j + 4], s[j + 5] );
			s[i + 4] := shor( s[j + 5], s[j + 6] );
			s[i + 5] := shor( s[j + 6], s[j + 7] );
			IF i <= 53 - 7 THEN
				s[i + 6] := shor( s[j + 7], s[j + 0] );
				s[i + 7] := shor( s[j + 0], s[j + 1] )
			END;
			INC( j, 8 );  INC( i, 8 )
		END;
		FOR i := 0 TO 8 DO
			FOR j := 0 TO 5 DO  e[i, j] := s[6*i + j]  END
		END;
	END CalcEncryptionKeys;

	PROCEDURE CalcDecryptionKeys( CONST  e: KeyBlock; VAR d: KeyBlock );
	VAR i, j: INTEGER;  t: CARD16;
	BEGIN
		j := 8;
		FOR i := 0 TO 8 DO
			d[i, 0] := Inverse( e[j, 0] );
			d[i, 1] := (10000H - e[j, 2]) MOD 10000H;
			d[i, 2] := (10000H - e[j, 1]) MOD 10000H;
			d[i, 3] := Inverse( e[j, 3] );
			IF i # 8 THEN
				DEC( j );
				d[i, 4] := e[j, 4];
				d[i, 5] := e[j, 5]
			END;
		END;
		t := d[0, 1];  d[0, 1] := d[0, 2];  d[0, 2] := t;
		t := d[8, 1];  d[8, 1] := d[8, 2];  d[8, 2] := t;
	END CalcDecryptionKeys;

	PROCEDURE IDEACipher( VAR b: Block;  CONST key: KeyBlock );
	VAR i, x1, x2, x3, x4, t1, t2, t3: CARD16;
	BEGIN
		x1 := b[0];  x2 := b[1];  x3 := b[2];  x4 := b[3];
		FOR i := 0 TO 7 DO
			x1 := Mul( x1, key[i, 0] );  x2 := (x2 + key[i, 1]) MOD 10000H;
			x3 := (x3 + key[i, 2]) MOD 10000H;
			x4 := Mul( x4, key[i, 3] );
			t1 := Mul( Xor( x1, x3 ), key[i, 4] );
			t2 := Mul( t1 + Xor( x2, x4 ), key[i, 5] );
			t1 := (t1 + t2) MOD 10000H;
			x1 := Xor( x1, t2 );  x4 := Xor( x4, t1 );
			t3 := Xor( x2, t1 );  x2 := Xor( x3, t2 );
			x3 := t3;
		END;
		b[0] := Mul( x1, key[8, 0] );
		b[1] := (x3 + key[8, 1]) MOD 10000H;
		b[2] := (x2 + key[8, 2]) MOD 10000H;
		b[3] := Mul( x4, key[8, 3] );
	END IDEACipher;

	PROCEDURE Xor( a, b: CARD16 ): CARD16;
	BEGIN
		RETURN S.VAL( LONGINT, S.VAL( SET, a )/S.VAL( SET, b ) )
	END Xor;

	PROCEDURE Mul( a, b: CARD16 ): CARD16;
	VAR p, q: LONGINT;
	BEGIN
		IF a = 0 THEN  p := 10001H - b
		ELSIF b = 0 THEN  p := 10001H - a
		ELSE
			q := (a MOD 10000H)*(b MOD 10000H);
			p := (q MOD 10000H) - LSH( q, -16 );
			IF p <= 0 THEN  INC( p, 10001H )  END
		END;
		RETURN p MOD 10000H;
	END Mul;

END CryptoIDEA.