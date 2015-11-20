MODULE CryptoDSA;	(** AUTHOR "G.F."; PURPOSE "Digital Signature Algorithm DSA"; *)

IMPORT
	B := CryptoBigNumbers, SHA1 := CryptoSHA1, P := CryptoPrimes, U := CryptoUtils, Streams,
	Base64 := CryptoBase64, BIT;

TYPE
	Number = B.BigNumber;

	Signature* = OBJECT
		VAR
			r-	: Number;
			s-	: Number;

			PROCEDURE & Init*( r, s: Number );
			BEGIN
				B.Copy( r, SELF.r );
				B.Copy( s, SELF.s )
			END Init;

	END Signature;

	Key* = OBJECT
		VAR
			name-: ARRAY 128 OF CHAR;   (** Owner of this key. *)
			private-: BOOLEAN;
			p-	: Number;
			q-	: Number;
			g-	: Number;
			y-	: Number;
			inv, r : Number;

			PROCEDURE Sign*( CONST digest: ARRAY OF CHAR;  len: INTEGER  ): Signature;
			VAR  m, xr, ss: Number;  sig: Signature;
			BEGIN
				ASSERT( private );
				IF (len > q.len*4 ) OR (len > 50) THEN  HALT( 102 )  END;

				B.AssignBin( m, digest, 0, len );
				xr := B.Mul( y, r );
				ss := B.Add( xr, m );	(* s := inv( k ) * (m + x*r) mod q *)
				IF B.Cmp( ss, q ) > 0 THEN  ss := B.Sub( ss, q )  END;
				ss := B.ModMul( ss, inv, q );
				NEW( sig, r, ss );
				RETURN sig
			END Sign;

			PROCEDURE Verify*(  CONST digest: ARRAY OF CHAR;  dlen: INTEGER;  sig: Signature ): BOOLEAN;
			VAR
				u, v, w, t1, t2: Number;
			BEGIN
				ASSERT( ~private );
				IF B.Cmp( sig.r, q ) >= 0 THEN  RETURN FALSE  END;
				IF B.Cmp( sig.s, q ) >= 0 THEN  RETURN FALSE  END;
				(* w = inv( s ) mod q *)
				w := B.ModInverse( sig.s, q );
				(* v = m * w mod q *)
				B.AssignBin( v, digest, 0, dlen );
				v := B.ModMul( v, w, q );
				(* u = r * w mod q *)
				u := B.ModMul( sig.r, w, q );
				(* v = (g^v * y^u mod p) mod q *)
				t1 := B.ModExp( g, v, p );
				t2 := B.ModExp( y, u, p);
				v := B.ModMul( t1, t2, p );
				v := B.Mod( v, q );
				RETURN B.Cmp( v, sig.r ) = 0;
			END Verify;

	END Key;

VAR
	one: Number;	(* constant *)


	PROCEDURE GenParams*( dsa: Key;  bits: INTEGER;  CONST seed: ARRAY OF CHAR );
	VAR
		randomseed, pfound: BOOLEAN;
		i, k, n, count: INTEGER;
		test, W, r0: Number;
		sbuf, buf, buf2, md: ARRAY 20 OF CHAR;
		h: SHA1.Hash;
	BEGIN
		IF bits < 512 THEN
			bits := 512;
		ELSE
			bits := (bits + 63) DIV 64 * 64;
		END;
		randomseed := LEN( seed ) < 20;
		IF ~randomseed THEN
			FOR i := 0 TO 19 DO  sbuf[i] := seed[i]  END;
		END;
		B.AssignInt( test, 1 );
		test.Shift( bits - 1 );
		NEW( h );
		pfound := FALSE;
		LOOP (* find q and p *)
			REPEAT (* find q *)
				IF randomseed THEN
					B.RandomBytes( sbuf, 0, 20 );
				END;
				buf := sbuf;
				buf2 := sbuf;
				(* precompute "SEED + 1" *)
				REPEAT
					DEC( i );
					buf[i] := CHR( ORD( buf[i] ) + 1);
				UNTIL (i = 0) OR (buf[i] # 0X );
				h.Initialize;
				h.Update( sbuf, 0, 20 );
				h.GetHash( md, 0 );
				h.Initialize;
				h.Update( buf, 0, 20 );
				h.GetHash( buf2, 0 );
				FOR i := 0 TO 19 DO (* md := md xor buf2*)
					md[ i ] := BIT.CXOR( md[ i ], buf2[ i ] );
				END;
				IF ORD( md[0] ) < 128 THEN
					md[0] := CHR( ORD( md[0] ) + 128 );
				END;
				IF ~ODD( ORD( md[19] ) ) THEN
					md[19] := CHR( ORD( md[19] ) + 1 );
				END;
				B.AssignBin( dsa.q, md, 0, 20 );
			UNTIL P.IsPrime( dsa.q, 50, randomseed );
			count := 0;  n := bits  DIV 160;
			LOOP (* find p *)
				B.AssignInt( W, 0 );
				(* now 'buf' contains "SEED + offset - 1" *)
				FOR k := 0 TO n  DO
					(* obtain "SEED + offset + k" by incrementing: *)
					i := 20;
					REPEAT
						DEC( i );
						buf[i] := CHR( ORD( buf[i] ) + 1)
					UNTIL (i = 0) OR (buf[i] # 0X );
					h.Initialize;
					h.Update( buf, 0, 20 );
					h.GetHash( md, 0 );
					B.AssignBin( r0, md, 0, 20 );
					r0.Shift( 160*k );  W := B.Add( W, r0 );
				END;
				W.Mask( bits - 1);
				W := B.Add( W, test );
				B.Copy( dsa.q, r0 );
				r0.Shift( 1 );
				r0 := B.Mod( W, r0 );
				r0.Dec;
				dsa.p := B.Sub( W, r0 );
				IF B.Cmp( dsa.p, test ) >= 0 THEN
					IF P.IsPrime( dsa.p, 50, TRUE ) THEN
						pfound := TRUE;
						EXIT;
					END;
				END;
				INC( count );
				IF count >= 4096 THEN  EXIT  END;
			END; (* find p *)
			IF pfound THEN  EXIT  END;
		END; (* find q and p *)

		B.Copy( dsa.p, test );
		test.Dec;
		r0 := B.Div( test, dsa.q );	(*  r0 := (p-1)/q *)
		B.AssignInt( test, 2 );
		LOOP (* g := test ^ r0 mod p *)
			dsa.g := B.ModExp( test, r0, dsa.p );
			IF B.Cmp( dsa.g, one ) # 0 THEN  EXIT  END;
			test.Inc;
		END;
	END GenParams;

	PROCEDURE MakeKeys*( bits: INTEGER;  CONST seed: ARRAY OF CHAR;  VAR pub, priv: Key );
	BEGIN
		NEW( priv );
		GenParams( priv, bits, seed );
		REPEAT
			priv.y := B.NewRandRange( priv.q )
		UNTIL ~priv.y.IsZero( );
		NEW( pub );  pub^ := priv^;
		pub.y := B.ModExp( priv.g, priv.y, priv.p );
		priv.private := TRUE;
		priv.r := B.Mod( pub.y, priv.q );	(* r := (g ^ k mod p) mod q *)
		priv.inv := B.ModInverse( priv.y, priv.q )	(* part of 's := inv( k ) * (m + x*r) mod q' *)
	END MakeKeys;


	(** returns a new public key with exponent e and modulus m *)
	PROCEDURE PubKey*( p, q, g, y: Number ): Key;
		VAR dsa: Key;
	BEGIN
		NEW( dsa );
		dsa.name := "unkown";
		dsa.private := FALSE;
		B.Copy( p, dsa.p );
		B.Copy( q, dsa.q );
		B.Copy( g, dsa.g );
		B.Copy( y, dsa.y );
		RETURN dsa
	END PubKey;


	PROCEDURE LoadPrivateKey*( r: Streams.Reader;  CONST passwd: ARRAY OF CHAR ): Key;
	(* TODO *)
	END LoadPrivateKey;

	PROCEDURE StorePrivateKey*( w: Streams.Writer;  k: Key;  CONST passwd: ARRAY OF CHAR );
	(* TODO *)
	END StorePrivateKey;


	PROCEDURE StorePublicKey*( w: Streams.Writer; k: Key );	(* openssh format *)
	VAR buf, encoded: ARRAY 4096 OF CHAR; pos: LONGINT;
	BEGIN
		ASSERT( ~k.private );
		w.String( "ssh-dss " );
		pos := 0;
		U.PutString( buf, pos, "ssh-dss" );
		U.PutBigNumber( buf, pos, k.p );
		U.PutBigNumber( buf, pos, k.q );
		U.PutBigNumber( buf, pos, k.g );
		U.PutBigNumber( buf, pos, k.y );
		Base64.Encode( buf, pos, encoded );
		w.String( encoded );
		w.String( " user@Aos" )
	END StorePublicKey;


	PROCEDURE LoadPublicKey*( r: Streams.Reader ): Key;
	VAR buf: ARRAY 4096 OF CHAR; len, pos: LONGINT;
		str: ARRAY 64 OF CHAR;
		k: Key;
	BEGIN
		NEW( k ); k.private := FALSE;
		len := Base64.DecodeStream( r, buf );
		pos := 0;
		U.GetString( buf, pos, str );
		ASSERT( str = "ssh-dss" );
		U.GetBigNumber( buf, pos, k.p );
		U.GetBigNumber( buf, pos, k.q );
		U.GetBigNumber( buf, pos, k.g );
		U.GetBigNumber( buf, pos, k.y );
		RETURN k
	END LoadPublicKey;

BEGIN
	B.AssignInt( one, 1 );
END CryptoDSA.


System.Free CryptoDSA ~