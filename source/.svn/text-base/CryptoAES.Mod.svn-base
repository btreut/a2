MODULE CryptoAES;   (** AES (Rijndael) de/encryption *)

(*	2002.07.22	g.f.  *)

IMPORT  S := SYSTEM, Ciphers := CryptoCiphers, U := CryptoUtils;

CONST
	MaxR = 14;  
	ECB = Ciphers.ECB;  CBC = Ciphers.CBC;  CTR = Ciphers.CTR;
	
	b0 = S.VAL( SET, 0FFH );  b1 = S.VAL( SET, 0FF00H );  
	b2 = S.VAL( SET, 0FF0000H );  b3 = S.VAL( SET, 0FF000000H );

TYPE
	RTable = ARRAY 256 OF SET;

	Ind4 = RECORD a, b, c, d: LONGINT END;

VAR
	e0, e1, e2, e3, e4, d0, d1, d2, d3, d4: RTable;
	rcon: ARRAY 10 OF SET;   (* for 128-bit blocks, Rijndael never uses more than 10 rcon values *)

TYPE
	RKeys = ARRAY 4*(MaxR + 1) OF SET;
	Block = ARRAY 4 OF SET;

	Cipher* = OBJECT (Ciphers.Cipher)
			VAR
				rounds: SHORTINT;
				erkeys, drkeys: RKeys;
				iv: Block;

				PROCEDURE InitKey*( CONST src: ARRAY OF CHAR; keybits: LONGINT );
				BEGIN
					InitKey^( src, keybits );
					IF keybits = 128 THEN  rounds := Init128( erkeys, src )
					ELSIF keybits = 192 THEN  rounds := Init192( erkeys, src )
					ELSE  rounds := Init256( erkeys, src )
					END;
					drkeys := erkeys;  Invert( drkeys, rounds )
				END InitKey;

				PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
				BEGIN
					SetIV^( src, mode );   (* set mode *)
					U.BufferToBlockBE( src, 0, iv );
				END SetIV;
				
				PROCEDURE IncIV;
				VAR i, x: LONGINT;
				BEGIN
					i := 4;
					REPEAT
						DEC( i );
						x := S.VAL( LONGINT, iv[i] ) + 1;  iv[i] := S.VAL( SET, x )
					UNTIL (x # 0) OR (i = 0)
				END IncIV;

				PROCEDURE Encrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR i, j: LONGINT;  x, y: Block;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						U.BufferToBlockBE( buf, ofs + i, x );
						CASE mode OF
						| ECB:
							FOR j := 0 TO 3 DO  x[j] := x[j] / erkeys[j]  END;
							RoundE( erkeys, x, rounds );
						| CBC:
							FOR j := 0 TO 3 DO  x[j] := x[j] / erkeys[j] / iv[j]  END;
							RoundE( erkeys, x, rounds );
							iv := x;
						| CTR:
							FOR j := 0 TO 3 DO  y[j] := iv[j] / erkeys[j]  END;
							RoundE( erkeys, y, rounds );
							FOR j := 0 TO 3 DO  x[j] := x[j] / y[j]  END;
							IncIV
						END;
						U.BlockToBufferBE( x, buf, ofs + i );
						INC( i, blockSize )
					END
				END Encrypt;

				PROCEDURE Decrypt*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
				VAR x0, x, y: Block;  i, j: LONGINT;
				BEGIN
					ASSERT( isKeyInitialized );
					ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
					i := 0;
					WHILE i < len DO
						U.BufferToBlockBE( buf, ofs + i, x0 );
						CASE mode OF
						| ECB:
							FOR j := 0 TO 3 DO  x[j] := x0[j] / drkeys[j]  END;
							RoundD( drkeys, x, rounds );
						| CBC:
							FOR j := 0 TO 3 DO  x[j] := x0[j] / drkeys[j]  END;
							RoundD( drkeys, x, rounds );
							FOR j := 0 TO 3 DO  x[j] := x[j] / iv[j]  END;
							iv := x0;
						| CTR:
							FOR j := 0 TO 3 DO  y[j] := iv[j] / erkeys[j]  END;
							RoundE( erkeys, y, rounds );
							FOR j := 0 TO 3 DO  x[j] := x0[j] / y[j]  END;
							IncIV
						END;
						U.BlockToBufferBE( x, buf, ofs + i );
						INC( i, blockSize )
					END
				END Decrypt;



				PROCEDURE & Init*;
				BEGIN
					SetNameAndBlocksize( "aes", 16 )
				END Init;

			END Cipher;

	PROCEDURE NewCipher*(): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;

(*-------------------------------------------------------------------------------*)



	PROCEDURE Initialize;
	VAR i, si, v1, i2, i4, i8, i9, ib, id, ie, v2, v3, t: LONGINT;
		source: ARRAY 1500 OF CHAR;

		PROCEDURE Append( CONST str: ARRAY OF CHAR );
		VAR j: LONGINT;  c: CHAR;
		BEGIN
			c := str[0];  j := 1;
			WHILE c >= ' ' DO  source[i] := c;  INC( i );  c := str[j];  INC( j )  END
		END Append;

		PROCEDURE GetInt( ): LONGINT;
		VAR x: LONGINT;  c: CHAR;
		BEGIN
			WHILE source[si] = ' ' DO  INC( si )  END;
			x := 0;  c := source[si];  INC( si );
			WHILE c > ' ' DO  x := 10*x + (ORD( c ) - 48);  c := source[si];  INC( si )  END;
			RETURN x
		END GetInt;

		PROCEDURE xor( a, b: LONGINT ): LONGINT;
		BEGIN
			RETURN S.VAL( LONGINT, S.VAL( SET, a ) / S.VAL( SET, b ) )
		END xor;

	BEGIN
		i := 0;
		Append( " 99 124 119 123 242 107 111 197  48   1 103  43 254 215 171 118 " );
		Append( "202 130 201 125 250  89  71 240 173 212 162 175 156 164 114 192 " );
		Append( "183 253 147  38  54  63 247 204  52 165 229 241 113 216  49  21 " );
		Append( "  4 199  35 195  24 150   5 154   7  18 128 226 235  39 178 117 " );
		Append( "  9 131  44  26  27 110  90 160  82  59 214 179  41 227  47 132 " );
		Append( " 83 209   0 237  32 252 177  91 106 203 190  57  74  76  88 207 " );
		Append( "208 239 170 251  67  77  51 133  69 249   2 127  80  60 159 168 " );
		Append( " 81 163  64 143 146 157  56 245 188 182 218  33  16 255 243 210 " );
		Append( "205  12  19 236  95 151  68  23 196 167 126  61 100  93  25 115 " );
		Append( " 96 129  79 220  34  42 144 136  70 238 184  20 222  94  11 219 " );
		Append( "224  50  58  10  73   6  36  92 194 211 172  98 145 149 228 121 " );
		Append( "231 200  55 109 141 213  78 169 108  86 244 234 101 122 174   8 " );
		Append( "186 120  37  46  28 166 180 198 232 221 116  31  75 189 139 138 " );
		Append( "112  62 181 102  72   3 246  14  97  53  87 185 134 193  29 158 " );
		Append( "225 248 152  17 105 217 142 148 155  30 135 233 206  85  40 223 " );
		Append( "140 161 137  13 191 230  66 104  65 153  45  15 176  84 187  22 " );
		si := 0;

		FOR i := 0 TO 255 DO
			v1 := GetInt();

			v2 := ASH( v1, 1 );
			IF v2 >= 256  THEN  v2 := xor( v2, 11BH )  END;
			v3 := xor( v2, v1);

			i2 := ASH( i, 1 );
			IF i2 >= 256 THEN  i2 := xor( i2, 11BH )  END;
			i4 := ASH( i2, 1 );
			IF i4 >= 256 THEN  i4 := xor( i4, 11BH )  END;
			i8 := ASH( i4, 1 );
			IF i8 >= 256 THEN  i8 := xor( i8, 11BH )  END;
			i9 := xor( i8, i);  ib := xor( i9, i2 );  id := xor( i9, i4 );  ie := xor( i8, xor( i4, i2 ) );

			e0[i] := S.VAL( SET, ASH( v2, 24 ) + ASH( v1, 16 ) + ASH( v1, 8 ) + v3 );
			e1[i] := S.VAL( SET, ASH( v3, 24 ) + ASH( v2, 16 ) + ASH( v1, 8 ) + v1 );
			e2[i] := S.VAL( SET, ASH( v1, 24 ) + ASH( v3, 16 ) + ASH( v2, 8 ) + v1 );
			e3[i] := S.VAL( SET, ASH( v1, 24 ) + ASH( v1, 16 ) + ASH( v3, 8 ) + v2 );
			e4[i] := S.VAL( SET, ASH( v1, 24 ) + ASH( v1, 16 ) + ASH( v1, 8 ) + v1 );

			d0[v1] := S.VAL( SET, ASH( ie, 24 ) + ASH( i9, 16 ) + ASH( id, 8 ) + ib );
			d1[v1] := S.VAL( SET, ASH( ib, 24 ) + ASH( ie, 16 ) + ASH( i9, 8 ) + id );
			d2[v1] := S.VAL( SET, ASH( id, 24 ) + ASH( ib, 16 ) + ASH( ie, 8 ) + i9 );
			d3[v1] := S.VAL( SET, ASH( i9, 24 ) + ASH( id, 16 ) + ASH( ib, 8 ) + ie );
			d4[v1] := S.VAL( SET, ASH(  i,  24 ) + ASH(  i, 16 ) + ASH(  i, 8 ) + i );
		END;
		t := 1;
		FOR i := 0 TO 9 DO
			rcon[i] := S.VAL( SET, ASH( t, 24 ) );
			t := ASH( t, 1 );
			IF t >= 256 THEN  t := xor( t, 11BH )  END;
		END;
	END Initialize;

	PROCEDURE ind( s: SET ): LONGINT;   (* get index byte 0 *)
	BEGIN
		RETURN S.VAL( LONGINT, s ) MOD 100H
	END ind;

	PROCEDURE split( s: SET;  VAR b: Ind4 );   (* split word into 4 index bytes *)
	BEGIN
		b.a := S.VAL( LONGINT, s ) MOD 100H;
		b.b := S.VAL( LONGINT, s ) DIV 100H MOD 100H;
		b.c := S.VAL( LONGINT, s ) DIV 10000H MOD 100H;
		b.d := S.VAL( LONGINT, s ) DIV 1000000H MOD 100H;
	END split;

	PROCEDURE Init128( VAR rk: RKeys;  CONST src: ARRAY OF CHAR ): SHORTINT;
	VAR i, p: LONGINT;  ib: Ind4;
	BEGIN
		FOR i := 0 TO 3 DO  rk[i] := U.SetFromBufferBE( src, 4*i )  END;
		p := 0;  i := 0;
		LOOP
			split( rk[p + 3], ib );
			rk[p + 4] := rk[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
			rk[p + 5] := rk[p + 1] / rk[p + 4];
			rk[p + 6] := rk[p + 2] / rk[p + 5];
			rk[p + 7] := rk[p + 3] / rk[p + 6];
			INC( i );
			IF i = 10 THEN  EXIT   END;
			INC( p, 4 );
		END;
		RETURN 10
	END Init128;

	PROCEDURE Init192( VAR rk: RKeys;  CONST src: ARRAY OF CHAR ): SHORTINT;
	VAR i, p: LONGINT;  ib: Ind4;
	BEGIN
		FOR i := 0 TO 5 DO  rk[i] := U.SetFromBufferBE( src, 4*i )  END;
		p := 0;  i := 0;
		LOOP
			split( rk[p + 5], ib );
			rk[p + 6] := rk[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
			rk[p + 7] := rk[p + 1] / rk[p + 6];
			rk[p + 8] := rk[p + 2] / rk[p + 7];
			rk[p + 9] := rk[p + 3] / rk[p + 8];
			INC( i );
			IF i = 8 THEN  EXIT   END;
			rk[p + 10] := rk[p + 4] / rk[p + 9];
			rk[p + 11] := rk[p + 5] / rk[p + 10];
			INC( p, 6 );
		END;
		RETURN 12
	END Init192;

	PROCEDURE Init256( VAR rk: RKeys;  CONST src: ARRAY OF CHAR ): SHORTINT;
	VAR i, p: LONGINT;  ib: Ind4;
	BEGIN
		FOR i := 0 TO 7 DO  rk[i] := U.SetFromBufferBE( src, 4*i )  END;
		p := 0;  i := 0;
		LOOP
			split( rk[p + 7], ib );
			rk[p +   8] := rk[p] / (e4[ib.c]*b3) / (e4[ib.b]*b2) / (e4[ib.a]*b1) / (e4[ib.d]*b0) / rcon[i];
			rk[p +   9] := rk[p + 1] / rk[p + 8];
			rk[p + 10] := rk[p + 2] / rk[p + 9];
			rk[p + 11] := rk[p + 3] / rk[p + 10];
			INC( i );
			IF i = 7 THEN  EXIT   END;
			split( rk[p + 11], ib );
			rk[p + 12] := rk[p + 4] / (e4[ib.d]*b3) / (e4[ib.c]*b2) / (e4[ib.b]*b1) / (e4[ib.a]*b0);
			rk[p + 13] := rk[p + 5] / rk[p + 12];
			rk[p + 14] := rk[p + 6] / rk[p + 13];
			rk[p + 15] := rk[p + 7] / rk[p + 14];
			INC( p, 8 );
		END;
		RETURN 14
	END Init256;

	PROCEDURE Invert( VAR rk: RKeys;  rounds: SHORTINT );
	VAR i, j, k, p: LONGINT;  t: SET;  ib: Ind4;
	BEGIN
		(* invert the order of the round keys: *)
		i := 0;  j := 4*rounds;
		WHILE i < j DO
			FOR k := 0 TO 3 DO  t := rk[i + k];  rk[i + k] := rk[j + k];  rk[j + k] := t  END;
			INC( i, 4 );  DEC( j, 4 );
		END;
		(* apply the inverse MixColumn transform to all round keys but the first and the last: *)
		FOR i := 1 TO rounds - 1 DO
			p := 4*i;  split( rk[p + 0], ib );
			rk[p + 0] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
			split( rk[p + 1], ib );
			rk[p + 1] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
			split( rk[p + 2], ib );
			rk[p + 2] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
			split( rk[p + 3], ib );
			rk[p + 3] := d0[ind( e4[ib.d] )] / d1[ind( e4[ib.c] )] / d2[ind( e4[ib.b] )] / d3[ind( e4[ib.a] )];
		END;
	END Invert;

	PROCEDURE RoundE( CONST rk: RKeys;  VAR b: Block;  rounds: SHORTINT );
	VAR p, r: LONGINT;  t0, t1, t2, t3, s0, s1, s2, s3: Ind4;
	BEGIN
		split( b[0], s0 );  split( b[1], s1 );  split( b[2], s2 );  split( b[3], s3 );
		r := rounds DIV 2;  p := 0;
		LOOP
			split( e0[s0.d]/e1[s1.c]/e2[s2.b]/e3[s3.a]/rk[p + 4], t0 );
			split( e0[s1.d]/e1[s2.c]/e2[s3.b]/e3[s0.a]/rk[p + 5], t1 );
			split( e0[s2.d]/e1[s3.c]/e2[s0.b]/e3[s1.a]/rk[p + 6], t2 );
			split( e0[s3.d]/e1[s0.c]/e2[s1.b]/e3[s2.a]/rk[p + 7], t3 );
			INC( p, 8 );  DEC( r );
			IF r = 0 THEN  EXIT   END;
			split( e0[t0.d]/e1[t1.c]/e2[t2.b]/e3[t3.a]/rk[p + 0], s0 );
			split( e0[t1.d]/e1[t2.c]/e2[t3.b]/e3[t0.a]/rk[p + 1], s1 );
			split( e0[t2.d]/e1[t3.c]/e2[t0.b]/e3[t1.a]/rk[p + 2], s2 );
			split( e0[t3.d]/e1[t0.c]/e2[t1.b]/e3[t2.a]/rk[p + 3], s3 );
		END;
		b[0] := (e4[t0.d]*b3)/(e4[t1.c]*b2)/(e4[t2.b]*b1)/(e4[t3.a]*b0)/rk[p + 0];
		b[1] := (e4[t1.d]*b3)/(e4[t2.c]*b2)/(e4[t3.b]*b1)/(e4[t0.a]*b0)/rk[p + 1];
		b[2] := (e4[t2.d]*b3)/(e4[t3.c]*b2)/(e4[t0.b]*b1)/(e4[t1.a]*b0)/rk[p + 2];
		b[3] := (e4[t3.d]*b3)/(e4[t0.c]*b2)/(e4[t1.b]*b1)/(e4[t2.a]*b0)/rk[p + 3];
	END RoundE;

	PROCEDURE RoundD( CONST rk: RKeys;  VAR b: Block;  rounds: SHORTINT );
	VAR p, r: LONGINT;  t0, t1, t2, t3, s0, s1, s2, s3: Ind4;
	BEGIN
		split( b[0], s0 );  split( b[1], s1 );  split( b[2], s2 );  split( b[3], s3 );
		r := rounds DIV 2;  p := 0;
		LOOP
			split( d0[s0.d]/d1[s3.c]/d2[s2.b]/d3[s1.a]/rk[p + 4], t0 );
			split( d0[s1.d]/d1[s0.c]/d2[s3.b]/d3[s2.a]/rk[p + 5], t1 );
			split( d0[s2.d]/d1[s1.c]/d2[s0.b]/d3[s3.a]/rk[p + 6], t2 );
			split( d0[s3.d]/d1[s2.c]/d2[s1.b]/d3[s0.a]/rk[p + 7], t3 );
			INC( p, 8 );  DEC( r );
			IF r = 0 THEN  EXIT   END;
			split( d0[t0.d]/d1[t3.c]/d2[t2.b]/d3[t1.a]/rk[p + 0], s0 );
			split( d0[t1.d]/d1[t0.c]/d2[t3.b]/d3[t2.a]/rk[p + 1], s1 );
			split( d0[t2.d]/d1[t1.c]/d2[t0.b]/d3[t3.a]/rk[p + 2], s2 );
			split( d0[t3.d]/d1[t2.c]/d2[t1.b]/d3[t0.a]/rk[p + 3], s3 );
		END;
		b[0] := (d4[t0.d]*b3)/(d4[t3.c]*b2)/(d4[t2.b]*b1)/(d4[t1.a]*b0)/rk[p + 0];
		b[1] := (d4[t1.d]*b3)/(d4[t0.c]*b2)/(d4[t3.b]*b1)/(d4[t2.a]*b0)/rk[p + 1];
		b[2] := (d4[t2.d]*b3)/(d4[t1.c]*b2)/(d4[t0.b]*b1)/(d4[t3.a]*b0)/rk[p + 2];
		b[3] := (d4[t3.d]*b3)/(d4[t2.c]*b2)/(d4[t1.b]*b1)/(d4[t0.a]*b0)/rk[p + 3];
	END RoundD;

BEGIN
	Initialize;
END CryptoAES.