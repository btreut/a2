MODULE CryptoTwofish;   (** Twofish en/decryption *)

(*	Oberon port, based on twofish.c (vers. 1.0, Apr. 1998),
		2002.07.22	g.f.
 *)

IMPORT S := SYSTEM, Ciphers := CryptoCiphers, U := CryptoUtils;

CONST
	N = 16;

TYPE
	Block = ARRAY 4 OF SET;
	LI = LONGINT;

	SKey = ARRAY 4 OF SET;

VAR
	tab: ARRAY 2, 256 OF SET;

TYPE
	Cipher* = OBJECT (Ciphers.Cipher)
			VAR keybits: LONGINT;
				sbox: ARRAY 4 OF LONGINT;
				subkeys: ARRAY 8 + 2*N OF LONGINT;
				iv: Block;

				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT );
				CONST step = 02020202H;  bump = 01010101H;
				VAR
					i, A, B, m, nsub: LONGINT;
					k32e, k32o: ARRAY 4 OF LONGINT;   (* even/odd key dwords *)
				BEGIN
					InitKey^( src, keybits );  SELF.keybits := keybits;
					FOR i := 0 TO keybits DIV 32 - 1 DO
						IF ODD( i ) THEN  k32o[i DIV 2] := U.IntFromBufferLE( src, i*4 )
						ELSE  k32e[i DIV 2] := U.IntFromBufferLE( src, i*4 )
						END
					END;
					m := keybits DIV 64 - 1;
					FOR i := 0 TO m DO
						(* compute S-box keys using (12,8) Reed-Solomon code over GF(256) *)
						sbox[m - i] := Encode( k32e[i], k32o[i] );   (* reverse order *)
					END;
					nsub := 8 + N*2;
					FOR i := 0 TO nsub DIV 2 - 1 DO
						(* compute round subkeys for PHT *)
						A := f32( i*step, k32e, keybits );  			 (* A uses even key dwords *)
						B := f32( i*step + bump, k32o, keybits );   (* B uses odd  key dwords *)
						B := ROT( B, 8 );
						subkeys[i*2] := A + B;   							(* combine with a PHT *)
						subkeys[i*2 + 1] := ROT( A + 2*B, 9 );
					END
				END InitKey;

				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
				VAR i: INTEGER;
				BEGIN
					SetIV^( src, mode );   (* set mode *)
					FOR i := 0 TO 3 DO  iv[i] := U.SetFromBufferLE( src, 4*i )  END;
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

				PROCEDURE EncryptBlock( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
				VAR x: Block;  t0, t1, i, r: LONGINT;  s0, s1: SET;
				BEGIN
					(* copy in the block, add whitening *)
					FOR i := 0 TO 3 DO
						x[i] := U.SetFromBufferLE( buf, pos + i*4 )/S.VAL( SET, subkeys[i] );
						IF mode = Ciphers.CBC THEN  x[i] := x[i]/iv[i]  END
					END;
					(* main Twofish encryption loop *)
					FOR r := 0 TO N - 1 DO
						t0 := f32( S.VAL( LI, x[0] ), sbox, keybits );
						t1 := f32( ROT( S.VAL( LI, x[1] ), 8 ), sbox, keybits );
						x[3] := ROT( x[3], 1 );
						x[2] := x[2]/S.VAL( SET, t0 + t1 + subkeys[8 + 2*r] );
						x[3] := x[3]/S.VAL( SET, t0 + t1*2 + subkeys[8 + 2*r + 1] );
						x[2] := ROT( x[2], -1 );
						IF r < N - 1 THEN  (* unswap, except for last round *)
							s0 := x[0];  x[0] := x[2];  x[2] := s0;  s1 := x[1];  x[1] := x[3];  x[3] := s1;
						END
					END;
					(* copy out, with whitening *)
					FOR i := 0 TO 3 DO
						x[i] := x[i]/S.VAL( SET, subkeys[4 + i] );  U.SetToBufferLE( x[i], buf, pos + i*4 );
						IF mode = Ciphers.CBC THEN  iv[i] := x[i]  END
					END;
				END EncryptBlock;

				PROCEDURE DecryptBlock( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
				VAR x0, x: Block;  t0, t1, i, r: LONGINT;  s0, s1: SET;
				BEGIN
					(* copy in the block, add whitening *)
					FOR i := 0 TO 3 DO  x0[i] := U.SetFromBufferLE( buf, pos + i*4 );  x[i] := x0[i]/S.VAL( SET, subkeys[4 + i] );   END;
					(* main Twofish decryption loop *)
					FOR r := N - 1 TO 0 BY -1 DO
						t0 := f32( S.VAL( LI, x[0] ), sbox, keybits );
						t1 := f32( ROT( S.VAL( LI, x[1] ), 8 ), sbox, keybits );
						x[2] := ROT( x[2], 1 );  x[2] := x[2]/S.VAL( SET, t0 + t1 + subkeys[8 + 2*r] );
						x[3] := x[3]/S.VAL( SET, t0 + t1*2 + subkeys[8 + 2*r + 1] );  x[3] := ROT( x[3], -1 );
						IF r > 0 THEN  (* unswap, except for last round *)
							s0 := x[0];  x[0] := x[2];  x[2] := s0;
							s1 := x[1];  x[1] := x[3];  x[3] := s1;
						END
					END;
					(* copy out, with whitening *)
					FOR i := 0 TO 3 DO
						x[i] := x[i]/S.VAL( SET, subkeys[i] );
						IF mode = Ciphers.CBC THEN  x[i] := x[i]/iv[i];  iv[i] := x0[i]  END;
						U.SetToBufferLE( x[i], buf, pos + i*4 );
					END;
				END DecryptBlock;

				PROCEDURE & Init*;
				BEGIN
					SetNameAndBlocksize( "twofish", 16 )
				END Init;

			END Cipher;

	PROCEDURE NewCipher*(): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;

(*-------------------------------------------------------------------------------*)

	PROCEDURE m1( x: LONGINT ): SET;
	BEGIN
		RETURN S.VAL( SET, x )
	END m1;

	PROCEDURE mx( x: LONGINT ): SET;
	CONST FDBK = 169H;
	VAR t: SET;
	BEGIN
		t := S.VAL( SET, x DIV 4 );
		IF ODD( x DIV 2 ) THEN  t := t/S.VAL( SET, FDBK DIV 2 )  END;
		IF ODD( x ) THEN  t := t/S.VAL( SET, FDBK DIV 4 )  END;
		RETURN S.VAL( SET, x )/t
	END mx;

	PROCEDURE my( x: LONGINT ): SET;
	CONST FDBK = 169H;
	VAR t1, t2: SET;
	BEGIN
		t1 := S.VAL( SET, x DIV 2 );  t2 := S.VAL( SET, x DIV 4 );
		IF ODD( x DIV 2 ) THEN  t2 := t2/S.VAL( SET, FDBK DIV 2 )  END;
		IF ODD( x ) THEN  t1 := t1/S.VAL( SET, FDBK DIV 2 );  t2 := t2/S.VAL( SET, FDBK DIV 4 )  END;
		RETURN S.VAL( SET, x )/t1/t2
	END my;

	PROCEDURE split( x: LONGINT;  VAR v: SKey );
	BEGIN
		v[0] := S.VAL( SET, x MOD 256 );  x := x DIV 256;
		v[1] := S.VAL( SET, x MOD 256 );  x := x DIV 256;
		v[2] := S.VAL( SET, x MOD 256 );  x := x DIV 256;
		v[3] := S.VAL( SET, x MOD 256 );
	END split;


	PROCEDURE f32( x: LONGINT;  CONST k32: ARRAY OF LONGINT;  keybits: LONGINT ): LONGINT;
	VAR a, b, c, d, l: LONGINT;  k, k1: SKey;
	BEGIN
		(* Run each byte thru 8x8 S-boxes, xoring with key byte at each stage. *)
		(* Note that each byte goes through a different combination of S-boxes.*)
		a := x MOD 256;  x := x DIV 256;
		b := x MOD 256;  x := x DIV 256;
		c := x MOD 256;  x := x DIV 256;
		d := x MOD 256;

		l := ((keybits + 63) DIV 64) MOD 4;
		IF l = 0 THEN  (* 256 bits of key *)
			split( k32[3], k );  a := S.VAL( LI, tab[1, a]/k[0] );  b := S.VAL( LI, tab[0, b]/k[1] );  c := S.VAL( LI, tab[0, c]/k[2] );
			d := S.VAL( LI, tab[1, d]/k[3] );
		END;
		IF l IN {0, 3} THEN  (* 192 <= bits of key *)
			split( k32[2], k );  a := S.VAL( LI, tab[1, a]/k[0] );
			b := S.VAL( LI, tab[1, b]/k[1] );
			c := S.VAL( LI, tab[0, c]/k[2] );
			d := S.VAL( LI, tab[0, d]/k[3] )
		END;
		(* 128 <= bits of key *)
		split( k32[1], k1 );  split( k32[0], k );  a := S.VAL( LI, tab[1, S.VAL( LI, tab[0, S.VAL( LI, tab[0, a]/k1[0] )]/k[0] )] );
		b := S.VAL( LI, tab[0, S.VAL( LI, tab[0, S.VAL( LI, tab[1, b]/k1[1] )]/k[1] )] );
		c := S.VAL( LI, tab[1, S.VAL( LI, tab[1, S.VAL( LI, tab[0, c]/k1[2] )]/k[2] )] );
		d := S.VAL( LI, tab[0, S.VAL( LI, tab[1, S.VAL( LI, tab[1, d]/k1[3] )]/k[3] )] );

		(* Now perform the MDS matrix multiply  *)
		RETURN S.VAL( LI, m1( a )/my( b )/mx( c )/mx( d ) ) +
						ASH( S.VAL( LI, mx( a )/my( b )/my( c )/m1( d ) ), 8 ) +
						ASH( S.VAL( LI, my( a )/mx( b )/m1( c )/my( d ) ), 16 ) +
						ASH( S.VAL( LI, my( a )/m1( b )/my( c )/mx( d ) ), 24 );
	END f32;

	(* RS_MDS_Encode *)
	PROCEDURE Encode( k0, k1: LONGINT ): LONGINT;
	TYPE LI = LONGINT;
	VAR i, j: INTEGER;  g2, g3: SET;  r, b: LONGINT;  g216, g324, g38: SET;
	BEGIN
		r := k1;
		FOR i := 0 TO 1 DO
			IF i # 0 THEN  r := S.VAL( LI, S.VAL( SET, r )/S.VAL( SET, k0 ) )  END;
			FOR j := 0 TO 3 DO
				(* r := g( r ) *)
				 b := ASH( r, -24 ) MOD 256;

				g2 := S.VAL( SET, b*2 );
				IF b > 7FH THEN  g2 := (g2/S.VAL( SET, 14DH ))*S.VAL( SET, 0FFH )  END;
				g216 := S.VAL( SET, ASH( S.VAL( LI, g2 ), 16 ) );

				g3 := S.VAL( SET, b DIV 2 )/g2;
				IF ODD( b ) THEN  g3 := g3/S.VAL( SET, 0A6H )  END;
				g38 := S.VAL( SET, ASH( S.VAL( LI, g3 ), 8 ) );
				g324 := S.VAL( SET, ASH( S.VAL( LI, g38 ), 16 ) );

				r := S.VAL( LI, S.VAL( SET, r*256 )/g324/g216/g38/S.VAL( SET, b ) )
			END
		END;
		RETURN r
	END Encode;



	PROCEDURE Init0;
	VAR
		buf: U.InitBuffer;  i: LONGINT;
	BEGIN
		NEW( buf, 2048 );
		buf.Add( "0A9 067 0B3 0E8 004 0FD 0A3 076 09A 092 080 078 0E4 0DD 0D1 038 " );
		buf.Add( "00D 0C6 035 098 018 0F7 0EC 06C 043 075 037 026 0FA 013 094 048 " );
		buf.Add( "0F2 0D0 08B 030 084 054 0DF 023 019 05B 03D 059 0F3 0AE 0A2 082 " );
		buf.Add( "063 001 083 02E 0D9 051 09B 07C 0A6 0EB 0A5 0BE 016 00C 0E3 061 " );
		buf.Add( "0C0 08C 03A 0F5 073 02C 025 00B 0BB 04E 089 06B 053 06A 0B4 0F1 " );
		buf.Add( "0E1 0E6 0BD 045 0E2 0F4 0B6 066 0CC 095 003 056 0D4 01C 01E 0D7 " );
		buf.Add( "0FB 0C3 08E 0B5 0E9 0CF 0BF 0BA 0EA 077 039 0AF 033 0C9 062 071 " );
		buf.Add( "081 079 009 0AD 024 0CD 0F9 0D8 0E5 0C5 0B9 04D 044 008 086 0E7 " );
		buf.Add( "0A1 01D 0AA 0ED 006 070 0B2 0D2 041 07B 0A0 011 031 0C2 027 090 " );
		buf.Add( "020 0F6 060 0FF 096 05C 0B1 0AB 09E 09C 052 01B 05F 093 00A 0EF " );
		buf.Add( "091 085 049 0EE 02D 04F 08F 03B 047 087 06D 046 0D6 03E 069 064 " );
		buf.Add( "02A 0CE 0CB 02F 0FC 097 005 07A 0AC 07F 0D5 01A 04B 00E 0A7 05A " );
		buf.Add( "028 014 03F 029 088 03C 04C 002 0B8 0DA 0B0 017 055 01F 08A 07D " );
		buf.Add( "057 0C7 08D 074 0B7 0C4 09F 072 07E 015 022 012 058 007 099 034 " );
		buf.Add( "06E 050 0DE 068 065 0BC 0DB 0F8 0C8 0A8 02B 040 0DC 0FE 032 0A4 " );
		buf.Add( "0CA 010 021 0F0 0D3 05D 00F 000 06F 09D 036 042 04A 05E 0C1 0E0 " );
		FOR i := 0 TO 255 DO  tab[0, i] :=  S.VAL( SET, buf.GetInt() )  END;

		buf.Init( 2048 );
		buf.Add( "075 0F3 0C6 0F4 0DB 07B 0FB 0C8 04A 0D3 0E6 06B 045 07D 0E8 04B " );
		buf.Add( "0D6 032 0D8 0FD 037 071 0F1 0E1 030 00F 0F8 01B 087 0FA 006 03F " );
		buf.Add( "05E 0BA 0AE 05B 08A 000 0BC 09D 06D 0C1 0B1 00E 080 05D 0D2 0D5 " );
		buf.Add( "0A0 084 007 014 0B5 090 02C 0A3 0B2 073 04C 054 092 074 036 051 " );
		buf.Add( "038 0B0 0BD 05A 0FC 060 062 096 06C 042 0F7 010 07C 028 027 08C " );
		buf.Add( "013 095 09C 0C7 024 046 03B 070 0CA 0E3 085 0CB 011 0D0 093 0B8 " );
		buf.Add( "0A6 083 020 0FF 09F 077 0C3 0CC 003 06F 008 0BF 040 0E7 02B 0E2 " );
		buf.Add( "079 00C 0AA 082 041 03A 0EA 0B9 0E4 09A 0A4 097 07E 0DA 07A 017 " );
		buf.Add( "066 094 0A1 01D 03D 0F0 0DE 0B3 00B 072 0A7 01C 0EF 0D1 053 03E " );
		buf.Add( "08F 033 026 05F 0EC 076 02A 049 081 088 0EE 021 0C4 01A 0EB 0D9 " );
		buf.Add( "0C5 039 099 0CD 0AD 031 08B 001 018 023 0DD 01F 04E 02D 0F9 048 " );
		buf.Add( "04F 0F2 065 08E 078 05C 058 019 08D 0E5 098 057 067 07F 005 064 " );
		buf.Add( "0AF 063 0B6 0FE 0F5 0B7 03C 0A5 0CE 0E9 068 044 0E0 04D 043 069 " );
		buf.Add( "029 02E 0AC 015 059 0A8 00A 09E 06E 047 0DF 034 035 06A 0CF 0DC " );
		buf.Add( "022 0C9 0C0 09B 089 0D4 0ED 0AB 012 0A2 00D 052 0BB 002 02F 0A9 " );
		buf.Add( "0D7 061 01E 0B4 050 004 0F6 0C2 016 025 086 056 055 009 0BE 091 " );
		FOR i := 0 TO 255 DO  tab[1, i] :=  S.VAL( SET, buf.GetInt() )  END;
	END Init0;	
		
BEGIN
	Init0
END CryptoTwofish.
