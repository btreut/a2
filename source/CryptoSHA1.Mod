MODULE CryptoSHA1;	(** AUTHOR "G.F."; PURPOSE "SHA-1"; *)

IMPORT
	S := SYSTEM,  Hashes := CryptoHashes, U := CryptoUtils;

CONST
	BlockSize = 64;

TYPE
	State = ARRAY 5 OF LONGINT;

	Hash* = OBJECT (Hashes.Hash)
		VAR
			hash: State;
			Nl, Nh: LONGINT;
			cdata: ARRAY BlockSize OF CHAR;	(* pending data *)
			cn: LONGINT	(* number of chars in data *)
			
			
		PROCEDURE &Init*;
		BEGIN
			SetNameAndSize( "sha1", 20 );
			initialized := FALSE
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			hash[0] := LONGINT( 067452301H );
			hash[1] := LONGINT( 0EFCDAB89H );
			hash[2] := LONGINT( 098BADCFEH );
			hash[3] := LONGINT( 010325476H );
			hash[4] := LONGINT( 0C3D2E1F0H );
			Nl := 0;
			Nh := 0;
			cn := 0;
			initialized := TRUE
		END Initialize;
		
		
		PROCEDURE HashContextBlock;
		BEGIN
			HashBlock( hash, cdata, 0 );  cn := 0
		END HashContextBlock;

		(** data: value to be hashed *)
		PROCEDURE Update*( CONST data: ARRAY OF CHAR;  pos, len: LONGINT );
			VAR n, i, l: LONGINT;
		BEGIN
			ASSERT( initialized );
			l := Nl + len *8;
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
			WHILE n < len DIV BlockSize  DO  
				HashBlock( hash, data, pos );  INC( n ); INC( pos, BlockSize )
			END;
			len := len MOD BlockSize;
			WHILE cn < len  DO cdata[cn] := data[pos];  INC( cn );  INC( pos )  END;
		END Update;

		(** get the hashvalue of length SELF.size *)
		PROCEDURE GetHash*( VAR buf: ARRAY OF CHAR;  pos: LONGINT );
			VAR p: LONGINT;
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
			U.BlockToBufferBE( hash, buf, pos )
		END GetHash;

	END Hash;



	(* PROCEDURES *******************************************************************************)

	(** get an instance of SHA1 *)
	PROCEDURE NewHash*( ) : Hashes.Hash;
		VAR h: Hash;
	BEGIN
		NEW( h );  RETURN h
	END NewHash;



	PROCEDURE F1( b, c, d: LONGINT ): LONGINT;
	BEGIN
		RETURN S.VAL( LONGINT, ((S.VAL( SET, c ) / S.VAL( SET, d )) * S.VAL( SET, b )) / S.VAL( SET, d ) )
	END F1;

	PROCEDURE F2( b, c, d: LONGINT ): LONGINT;
	BEGIN
		RETURN S.VAL( LONGINT, S.VAL( SET, b ) / S.VAL( SET, c ) / S.VAL( SET, d ) )
	END F2;

	PROCEDURE F3( b, c, d: LONGINT ): LONGINT;
	BEGIN
		RETURN S.VAL( LONGINT, (S.VAL( SET, b ) * S.VAL( SET, c )) + ((S.VAL( SET, b ) + S.VAL( SET, c )) * S.VAL( SET, d )) )
	END F3;

	PROCEDURE tr0019( a: LONGINT; VAR b: LONGINT; c, d, e: LONGINT; VAR  f: LONGINT; x: SET );
	BEGIN
		f := S.VAL( LONGINT, x ) + e + 5A827999H + ROT( a, 5 ) + F1( b, c, d );
		b := ROT( b, 30 );
	END tr0019;

	PROCEDURE tr2039( a: LONGINT;  VAR b: LONGINT;  c, d, e: LONGINT;  VAR f: LONGINT;  x: SET );
	BEGIN
		f := S.VAL( LONGINT, x ) + e + 6ED9EBA1H + ROT( a, 5 ) + F2( b, c, d );
		b := ROT( b, 30 );
	END tr2039;

	PROCEDURE tr4059( a: LONGINT;  VAR b: LONGINT;  c, d, e: LONGINT;  VAR f: LONGINT;  x: SET);
	BEGIN
		f := S.VAL( LONGINT, x ) + e + LONGINT(8F1BBCDCH) + ROT( a, 5 ) + F3( b, c, d );
		b := ROT( b, 30 )
	END tr4059;

	PROCEDURE tr6079( a: LONGINT;  VAR b: LONGINT;  c, d, e: LONGINT;  VAR f: LONGINT;  x: SET );
	BEGIN
		f := S.VAL( LONGINT, x ) + e + LONGINT(0CA62C1D6H) + ROT( a, 5 ) + F2( b, c, d );
		b := ROT( b, 30 );
	END tr6079;

	PROCEDURE HashBlock( VAR state: State;  CONST buf: ARRAY OF CHAR;  pos: LONGINT );
	VAR 
		A, B, C, D, E, T: LONGINT;
		x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, xa, xb, xc, xd, xe, xf: SET;
	BEGIN
		A := state[0];  B := state[1];  C := state[2];  D := state[3];  E := state[4];

		x0 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( A, B, C, D, E, T, x0 );
		x1 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( T, A, B, C, D, E, x1 );
		x2 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( E, T, A, B, C, D, x2 );
		x3 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( D, E, T, A, B, C, x3 );
		x4 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( C, D, E, T, A, B, x4 );
		x5 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( B, C, D, E, T, A, x5 );
		x6 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( A, B, C, D, E, T, x6 );
		x7 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( T, A, B, C, D, E, x7 );
		x8 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( E, T, A, B, C, D, x8 );
		x9 := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( D, E, T, A, B, C, x9 );
		xa := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( C, D, E, T, A, B, xa );
		xb := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( B, C, D, E, T, A, xb );
		xc := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( A, B, C, D, E, T, xc );
		xd := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( T, A, B, C, D, E, xd );
		xe := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( E, T, A, B, C, D, xe );
		xf  := U.SetFromBufferBE( buf, pos );  INC( pos, 4 );  tr0019( D, E, T, A, B, C, xf  );

		x0 := ROT( x0 / x2 / x8 / xd, 1 );		tr0019( C, D, E, T, A, B, x0 );
		x1 := ROT( x1 / x3 / x9 / xe, 1 );		tr0019( B, C, D, E, T, A, x1 );
		x2 := ROT( x2 / x4 / xa / xf,  1 );		tr0019( A, B, C, D, E, T, x2 );
		x3 := ROT( x3 / x5 / xb / x0, 1 );		tr0019( T, A, B, C, D, E, x3 );

		x4 := ROT( x4 / x6 / xc / x1, 1 );		tr2039( E, T, A, B, C, D, x4 );
		x5 := ROT( x5 / x7 / xd / x2, 1 );		tr2039( D, E, T, A, B, C, x5 );
		x6 := ROT( x6 / x8 / xe / x3, 1 );		tr2039( C, D, E, T, A, B, x6 );
		x7 := ROT( x7 / x9 / xf  / x4, 1 );		tr2039( B, C, D, E, T, A, x7 );
		x8 := ROT( x8 / xa / x0 / x5, 1 );		tr2039( A, B, C, D, E, T, x8 );
		x9 := ROT( x9 / xb / x1 / x6, 1 );		tr2039( T, A, B, C, D, E, x9 );
		xa := ROT( xa / xc / x2 / x7, 1 ); 		tr2039( E, T, A, B, C, D, xa );
		xb := ROT( xb / xd / x3 / x8, 1 );		tr2039( D, E, T, A, B, C, xb );
		xc := ROT( xc / xe / x4 / x9, 1 ); 		tr2039( C, D, E, T, A, B, xc );
		xd := ROT( xd / xf  / x5 / xa, 1 );		tr2039( B, C, D, E, T, A, xd );
		xe := ROT( xe / x0 / x6 / xb, 1 );		tr2039( A, B, C, D, E, T, xe );
		xf  := ROT( xf  / x1 / x7 / xc, 1 );		tr2039( T, A, B, C, D, E, xf  );
		x0 := ROT( x0 / x2 / x8 / xd, 1 );		tr2039( E, T, A, B, C, D, x0 );
		x1 := ROT( x1 / x3 / x9 / xe, 1 );		tr2039( D, E, T, A, B, C, x1 );
		x2 := ROT( x2 / x4 / xa / xf,  1 );		tr2039( C, D, E, T, A, B, x2 );
		x3 := ROT( x3 / x5 / xb / x0, 1 );		tr2039( B, C, D, E, T, A, x3 );
		x4 := ROT( x4 / x6 / xc / x1, 1 );		tr2039( A, B, C, D, E, T, x4 );
		x5 := ROT( x5 / x7 / xd / x2, 1 );		tr2039( T, A, B, C, D, E, x5 );
		x6 := ROT( x6 / x8 / xe / x3, 1 );		tr2039( E, T, A, B, C, D, x6 );
		x7 := ROT( x7 / x9 / xf  / x4, 1 );		tr2039( D, E, T, A, B, C, x7 );

		x8 := ROT( x8 / xa / x0 / x5, 1 );		tr4059( C, D, E, T, A, B, x8 );
		x9 := ROT( x9 / xb / x1 / x6, 1 );		tr4059( B, C, D, E, T, A, x9 );
		xa := ROT( xa / xc / x2 / x7, 1 );		tr4059( A, B, C, D, E, T, xa );
		xb := ROT( xb / xd / x3 / x8, 1 );		tr4059( T, A, B, C, D, E, xb );
		xc := ROT( xc / xe / x4 / x9, 1 );		tr4059( E, T, A, B, C, D, xc );
		xd := ROT( xd / xf  / x5 / xa, 1 );  		tr4059( D, E, T, A, B, C, xd );
		xe := ROT( xe / x0 / x6 / xb, 1 );  		tr4059( C, D, E, T, A, B, xe );
		xf  := ROT( xf  / x1 / x7 / xc, 1 );		tr4059( B, C, D, E, T, A, xf  );
		x0 := ROT( x0 / x2 / x8 / xd, 1 );		tr4059( A, B, C, D, E, T, x0 );
		x1 := ROT( x1 / x3 / x9 / xe, 1 );		tr4059( T, A, B, C, D, E, x1 );
		x2 := ROT( x2 / x4 / xa / xf,  1 );		tr4059( E, T, A, B, C, D, x2 );
		x3 := ROT( x3 / x5 / xb / x0, 1 );		tr4059( D, E, T, A, B, C, x3 );
		x4 := ROT( x4 / x6 / xc / x1, 1 );		tr4059( C, D, E, T, A, B, x4 );
		x5 := ROT( x5 / x7 / xd / x2, 1 );		tr4059( B, C, D, E, T, A, x5 );
		x6 := ROT( x6 / x8 / xe / x3, 1 );		tr4059( A, B, C, D, E, T, x6 );
		x7 := ROT( x7 / x9 / xf  / x4, 1 );		tr4059( T, A, B, C, D, E, x7 );
		x8 := ROT( x8 / xa / x0 / x5, 1 );		tr4059( E, T, A, B, C, D, x8 );
		x9 := ROT( x9 / xb / x1 / x6, 1 );		tr4059( D, E, T, A, B, C, x9 );
		xa := ROT( xa / xc / x2 / x7, 1 );		tr4059( C, D, E, T, A, B, xa );
		xb := ROT( xb / xd / x3 / x8, 1 );		tr4059( B, C, D, E, T, A, xb );

		xc := ROT( xc / xe / x4 / x9, 1 );		tr6079( A, B, C, D, E, T, xc );
		xd := ROT( xd / xf  / x5 / xa, 1 );		tr6079( T, A, B, C, D, E, xd );
		xe := ROT( xe / x0 / x6 / xb, 1 ); 		tr6079( E, T, A, B, C, D, xe );
		xf  := ROT( xf  / x1 / x7 / xc, 1 );		tr6079( D, E, T, A, B, C, xf  );
		x0 := ROT( x0 / x2 / x8 / xd, 1 );		tr6079( C, D, E, T, A, B, x0 );
		x1 := ROT( x1 / x3 / x9 / xe, 1 );		tr6079( B, C, D, E, T, A, x1 );
		x2 := ROT( x2 / x4 / xa / xf,  1 );		tr6079( A, B, C, D, E, T, x2 );
		x3 := ROT( x3 / x5 / xb / x0, 1 );		tr6079( T, A, B, C, D, E, x3 );
		x4 := ROT( x4 / x6 / xc / x1, 1 );		tr6079( E, T, A, B, C, D, x4 );
		x5 := ROT( x5 / x7 / xd / x2, 1 );		tr6079( D, E, T, A, B, C, x5 );
		x6 := ROT( x6 / x8 / xe / x3, 1 );		tr6079( C, D, E, T, A, B, x6 );
		x7 := ROT( x7 / x9 / xf  / x4, 1 );		tr6079( B, C, D, E, T, A, x7 );
		x8 := ROT( x8 / xa / x0 / x5, 1 );		tr6079( A, B, C, D, E, T, x8 );
		x9 := ROT( x9 / xb / x1 / x6, 1 );		tr6079( T, A, B, C, D, E, x9 );
		xa := ROT( xa / xc / x2 / x7, 1 );		tr6079( E, T, A, B, C, D, xa );
		xb := ROT( xb / xd / x3 / x8, 1 );		tr6079( D, E, T, A, B, C, xb );
		xc := ROT( xc / xe / x4 / x9, 1 );		tr6079( C, D, E, T, A, B, xc );
		xd := ROT( xd / xf  / x5 / xa, 1 );		tr6079( B, C, D, E, T, A, xd );
		xe := ROT( xe / x0 / x6 / xb, 1 );		tr6079( A, B, C, D, E, T, xe );
		xf  := ROT( xf  / x1 / x7 / xc, 1 );		tr6079( T, A, B, C, D, E, xf  );

		INC( state[0], E );  INC( state[1], T );  INC( state[2], A );  
		INC( state[3], B );  INC( state[4], C );
	END HashBlock;



END CryptoSHA1.