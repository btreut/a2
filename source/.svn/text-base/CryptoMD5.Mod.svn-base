MODULE CryptoMD5;	(** AUTHOR "G.F."; PURPOSE "MD5"; *)

IMPORT
	S := SYSTEM,  Hashes := CryptoHashes, U := CryptoUtils;

TYPE
	Buffer = ARRAY 16 OF LONGINT;

	Hash* = OBJECT (Hashes.Hash)
		VAR
			A, B, C, D: LONGINT;	(* state *)
			N: LONGINT;	(* total no of chars written *)
			X: Buffer;
			cb: ARRAY 4 OF LONGINT;

		PROCEDURE & Init*;
		BEGIN
			SetNameAndSize( "md5", 16 );
			initialized := FALSE
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			N := 0;
			(* Initialize chaining values *)
			A := 67452301H;  
			B := LONGINT(0EFCDAB89H);  
			C := LONGINT(098BADCFEH);  
			D := 10325476H;
			initialized := TRUE
		END Initialize;

		PROCEDURE Write( ch: CHAR );
		VAR i: LONGINT;
		BEGIN
			i := N MOD 4;  cb[i] := ORD( ch );
			IF i = 3 THEN
				X[N DIV 4 MOD 16] := ((cb[3]*256 + cb[2])*256 + cb[1])*256 + cb[0]
			END;
			INC( N );
			IF N MOD 64 = 0 THEN  MD5( X, A, B, C, D )  END;
		END Write;

		(** data: value to be hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: LONGINT );
		VAR i: LONGINT;
		BEGIN
			ASSERT( initialized );
			FOR i := pos TO pos + len - 1 DO
				(* The following code equals ' Write(data[i]) '. It was copied here for better performance *)
				cb[ N MOD 4 ] := ORD( data[ i ] );
				IF N MOD 4 = 3 THEN
					X[ N DIV 4 MOD 16 ] := ( ( cb[3]*256 + cb[2] )*256 + cb[1] )*256 + cb[0]
				END;
				INC( N );
				IF N MOD 64 = 0 THEN  MD5( X, A, B, C, D )  END;
			END
		END Update;

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
		VAR n: LONGINT;
		BEGIN
			(* Append padding *)
			n := N*8;
			Write( 80X ); (* 1000 0000 *)
			WHILE N MOD 64 # 56 DO
				Write( 0X )	(* 0000 0000 *)
			END;
			(* 64-bit representation of b mod 2^64 *)
			Write( CHR( n MOD 256 ) );  n := n DIV 256;
			Write( CHR( n MOD 256 ) );  n := n DIV 256;
			Write( CHR( n MOD 256 ) );  n := n DIV 256;
			Write( CHR( n MOD 256 ) );
			Write( 0X );  Write( 0X );  Write( 0X );  Write( 0X );

			U.IntToBufferLE( A, buf, pos ); U.IntToBufferLE( B, buf, pos + 4 );
			U.IntToBufferLE( C, buf, pos + 8); U.IntToBufferLE( D, buf, pos + 12 );
		END GetHash;

	END Hash;

(*-----------------------------------------------------------------------------------*)

VAR
	T: ARRAY 65 OF LONGINT;

	(** get an instance of MD5 *)
	PROCEDURE NewHash*( ) : Hashes.Hash;
	VAR h: Hash;
	BEGIN
		NEW( h );  RETURN h
	END NewHash;

	PROCEDURE F1( VAR a: LONGINT;  b, c, d, x, s, t: LONGINT );
	VAR f: LONGINT;
	BEGIN
		f := S.VAL( LONGINT, (S.VAL( SET, b ) * S.VAL( SET, c )) + ((-S.VAL( SET, b )) * S.VAL( SET, d )) );
		a := ROT( a + f + x + t, s ) + b
	END F1;

	PROCEDURE F2( VAR a: LONGINT;  b, c, d, x, s, t: LONGINT );
	VAR f: LONGINT;
	BEGIN
		f := S.VAL( LONGINT, (S.VAL( SET, b ) * S.VAL( SET, d )) + (S.VAL( SET, c ) * (-S.VAL( SET, d ))) );
		a := ROT( a + f + x + t, s ) + b
	END F2;

	PROCEDURE F3( VAR a: LONGINT;  b, c, d, x, s, t: LONGINT );
	VAR f: LONGINT;
	BEGIN
		f := S.VAL( LONGINT, S.VAL( SET, b ) / S.VAL( SET, c ) / S.VAL( SET, d ) );
		a := ROT( a + f + x + t, s ) + b
	END F3;

	PROCEDURE F4( VAR a: LONGINT;  b, c, d, x, s, t: LONGINT );
	VAR f: LONGINT;
	BEGIN
		f := S.VAL( LONGINT, S.VAL( SET, c ) / (S.VAL( SET, b ) + (-S.VAL( SET, d ))) );
		a := ROT( a + f + x + t, s ) + b
	END F4;

	PROCEDURE MD5( CONST X: Buffer; VAR A, B, C, D: LONGINT );
	VAR  a, b, c, d: LONGINT;
	BEGIN
		a := A;  b := B;  c := C;  d := D;

		F1(  a, b, c, d,  X[00], 07, T[01] );		F1(  d, a, b, c,  X[01], 12, T[02] );
		F1(  c, d, a, b,  X[02], 17, T[03] );		F1(  b, c, d, a,  X[03], 22, T[04] );
		F1(  a, b, c, d,  X[04], 07, T[05] );		F1(  d, a, b, c,  X[05], 12, T[06] );
		F1(  c, d, a, b,  X[06], 17, T[07] );		F1(  b, c, d, a,  X[07], 22, T[08] );
		F1(  a, b, c, d,  X[08], 07, T[09] );		F1(  d, a, b, c,  X[09], 12, T[10] );
		F1(  c, d, a, b,  X[10], 17, T[11] );		F1(  b, c, d, a,  X[11], 22, T[12] );
		F1(  a, b, c, d,  X[12], 07, T[13] );		F1(  d, a, b, c,  X[13], 12, T[14] );
		F1(  c, d, a, b,  X[14], 17, T[15] );		F1(  b, c, d, a,  X[15], 22, T[16] );

		F2(  a, b, c, d,  X[01], 05, T[17] );		F2(  d, a, b, c,  X[06], 09, T[18] );
		F2(  c, d, a, b,  X[11], 14, T[19] );		F2(  b, c, d, a,  X[00], 20, T[20] );
		F2(  a, b, c, d,  X[05], 05, T[21] );		F2(  d, a, b, c,  X[10], 09, T[22] );
		F2(  c, d, a, b,  X[15], 14, T[23] );		F2(  b, c, d, a,  X[04], 20, T[24] );
		F2(  a, b, c, d,  X[09], 05, T[25] );		F2(  d, a, b, c,  X[14], 09, T[26] );
		F2(  c, d, a, b,  X[03], 14, T[27] );		F2(  b, c, d, a,  X[08], 20, T[28] );
		F2(  a, b, c, d,  X[13], 05, T[29] );		F2(  d, a, b, c,  X[02], 09, T[30] );
		F2(  c, d, a, b,  X[07], 14, T[31] );		F2(  b, c, d, a,  X[12], 20, T[32] );

		F3(  a, b, c, d,  X[05], 04, T[33] );		F3(  d, a, b, c,  X[08], 11, T[34] );
		F3(  c, d, a, b,  X[11], 16, T[35] );		F3(  b, c, d, a,  X[14], 23, T[36] );
		F3(  a, b, c, d,  X[01], 04, T[37] );		F3(  d, a, b, c,  X[04], 11, T[38] );
		F3(  c, d, a, b,  X[07], 16, T[39] );		F3(  b, c, d, a,  X[10], 23, T[40] );
		F3(  a, b, c, d,  X[13], 04, T[41] );		F3(  d, a, b, c,  X[00], 11, T[42] );
		F3(  c, d, a, b,  X[03], 16, T[43] );		F3(  b, c, d, a,  X[06], 23, T[44] );
		F3(  a, b, c, d,  X[09], 04, T[45] );		F3(  d, a, b, c,  X[12], 11, T[46] );
		F3(  c, d, a, b,  X[15], 16, T[47] );		F3(  b, c, d, a,  X[02], 23, T[48] );

		F4(  a, b, c, d,  X[00], 06, T[49] );		F4(  d, a, b, c,  X[07], 10, T[50] );
		F4(  c, d, a, b,  X[14], 15, T[51] );		F4(  b, c, d, a,  X[05], 21, T[52] );
		F4(  a, b, c, d,  X[12], 06, T[53] );		F4(  d, a, b, c,  X[03], 10, T[54] );
		F4(  c, d, a, b,  X[10], 15, T[55] );		F4(  b, c, d, a,  X[01], 21, T[56] );
		F4(  a, b, c, d,  X[08], 06, T[57] );		F4(  d, a, b, c,  X[15], 10, T[58] );
		F4(  c, d, a, b,  X[06], 15, T[59] );		F4(  b, c, d, a,  X[13], 21, T[60] );
		F4(  a, b, c, d,  X[04], 06, T[61] );		F4(  d, a, b, c,  X[11], 10, T[62] );
		F4(  c, d, a, b,  X[02], 15, T[63] );		F4(  b, c, d, a,  X[09], 21, T[64] );

		INC( A, a );  INC( B, b );  INC( C, c );  INC( D, d );
	END MD5;
	
	PROCEDURE Initialize;
	VAR 
		buf: U.InitBuffer;  i: LONGINT;
	BEGIN
		NEW( buf, 1024 );
		buf.Add( "D76AA478 E8C7B756 242070DB C1BDCEEE F57C0FAF 4787C62A A8304613 FD469501");
		buf.Add( "698098D8 8B44F7AF FFFF5BB1 895CD7BE 6B901122 FD987193 A679438E 49B40821");
		buf.Add( "F61E2562 C040B340 265E5A51 E9B6C7AA D62F105D 02441453 D8A1E681 E7D3FBC8");
		buf.Add( "21E1CDE6 C33707D6 F4D50D87 455A14ED A9E3E905 FCEFA3F8 676F02D9 8D2A4C8A");
		buf.Add( "FFFA3942 8771F681 6D9D6122 FDE5380C A4BEEA44 4BDECFA9 F6BB4B60 BEBFBC70");
		buf.Add( "289B7EC6 EAA127FA D4EF3085 04881D05 D9D4D039 E6DB99E5 1FA27CF8 C4AC5665");
		buf.Add( "F4292244 432AFF97 AB9423A7 FC93A039 655B59C3 8F0CCC92 FFEFF47D 85845DD1");
		buf.Add( "6FA87E4F FE2CE6E0 A3014314 4E0811A1 F7537E82 BD3AF235 2AD7D2BB EB86D391");
		FOR i := 1 TO 64 DO  T[i] := buf.GetInt()  END
	END Initialize;

BEGIN
	Initialize
END CryptoMD5.



