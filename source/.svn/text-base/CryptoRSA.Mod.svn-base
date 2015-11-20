MODULE CryptoRSA;	(** AUTHOR "G.F."; PURPOSE "RSA"; *)

(* Excerpt of Crypt.Mod  jm 23.8.95.*)

IMPORT
	B := CryptoBigNumbers, U := CryptoUtils, MD5 := CryptoMD5, Ciphers := CryptoCiphers,
	Base64 := CryptoBase64, Streams, Clock;

CONST
	chinese = TRUE;
	PrivateKeyMagic = 3F6FF9EBH;

TYPE
	Number = B.BigNumber;
	Buffer = ARRAY 16 OF CHAR;

	Certificate* = OBJECT
		VAR
			authority*: ARRAY 128 OF CHAR;   (** Certifying authority.  *)
			signature*: Number;   (** Signature of key. *)
			next*: Certificate
	END Certificate;

	Key* = OBJECT
		VAR
			name-: ARRAY 128 OF CHAR;   (** Owner of this key. *)
			private-: BOOLEAN;   (** Is this a private key? then the exponent is encrypted *)
			size-: LONGINT;
			exponent-, modulus-: Number;
			p, q, u: Number;   (* for chinese remainder theorem *)
			time-, date-: LONGINT;
			certificates*: Certificate;
			next*: Key;

			PROCEDURE Sign*( CONST digest: ARRAY OF CHAR;  dlen: LONGINT ): Number;
			VAR msg: Number;
			BEGIN
				ASSERT( private );
				B.AssignBin( msg, digest, 0, dlen );
				IF chinese THEN    (* Using chinese remainder: *)
					RETURN ChineseRemainder( msg, exponent, p, q, u )
				ELSE
					RETURN B.ModExp( msg, exponent, modulus );
				END;
			END Sign;


			PROCEDURE Verify*( CONST digest: ARRAY OF CHAR;  dlen: LONGINT;  signature: Number ): BOOLEAN;
			VAR
				msg: Number;
				i, l: LONGINT;
				buf: Buffer;
			BEGIN
				ASSERT(  ~private & (dlen >= 16) );
				msg := B.ModExp( signature, exponent, modulus );
				l := msg.len;
				FOR i := 0 TO 3 DO  l2n( msg.d[l - 1 - i], buf, 4*i )  END;
				FOR i := 0 TO 15 DO
					IF buf[i] # digest[i] THEN  RETURN FALSE  END;
				END;
				RETURN TRUE
			END Verify;


			PROCEDURE Encrypt*( msg: Number ): Number;
			BEGIN
				ASSERT( ~private );
				RETURN B.ModExp( msg, exponent, modulus );
			END Encrypt;

			PROCEDURE Decrypt*( msg: Number ): Number;
			BEGIN
				ASSERT( private );
				IF chinese THEN    (* Using chinese remainder: *)
					RETURN ChineseRemainder( msg, exponent, p, q, u )
				ELSE
					RETURN B.ModExp( msg, exponent, modulus );
				END;
			END Decrypt;

	END Key;

VAR
	one, two: Number;	(* constants *)


	(* converts LONGINT to ARRAY OF CHAR; big endian order *)
	PROCEDURE l2n( l: LONGINT;  VAR buf: Buffer;  pos: LONGINT );
	VAR i: LONGINT;
	BEGIN
		i := pos + 3;
		WHILE i >= pos DO
			buf[i] := CHR( l MOD 256 );
			l := l DIV 256;
			DEC( i )
		END
	END l2n;


	(** Generate public and private keys out of the large primes p and q, using the specified public exponent e.
		The private key's exponent will be enrypted with IDEA and key passwd *)
	PROCEDURE MakeKeys*( p, q, e: Number;  CONST name: ARRAY OF CHAR;   VAR pub, priv: Key );
	VAR
		n, p1, q1, x, d: Number;
	BEGIN
		ASSERT( B.Cmp( p, q ) # 0 );
		n := B.Mul( p, q );
		B.Copy( p, p1 );  p1.Dec;
		B.Copy( q, q1 );  q1.Dec;
		x := B.Mul( p1, q1 );

		d := B.ModInverse( e, x );

		NEW( pub);
		pub.modulus := n;
		pub.exponent := e;
		pub.size := n.len*32;
		pub.private := FALSE;

		NEW( priv );
		priv.modulus := n;
		priv.exponent := d;
		priv.size := n.len*32;
		priv.private := TRUE;

		(* Add stuff needed for the chinese remainder theorem to the private key *)
		IF B.Cmp( p, q ) < 0 THEN  (* p < q *)
			B.Copy( p, priv.p );
			B.Copy( q, priv.q );
		ELSE
			B.Copy( q, priv.p );
			B.Copy( p, priv.q );
		END;
		priv.u := B.ModInverse( priv.p, priv.q );
		Clock.Get( pub.time, pub.date );
		priv.time := pub.time;
		priv.date := pub.date;
		COPY( name, pub.name );
		COPY( name, priv.name );
	END MakeKeys;


	(** returns a new public key with exponent e and modulus m *)
	PROCEDURE PubKey*( e, m: Number ): Key;
		VAR rsa: Key;
	BEGIN
		NEW( rsa );
		rsa.name := "unkown";
		rsa.private := FALSE;
		B.Copy( e, rsa.exponent );
		B.Copy( m, rsa.modulus );
		RETURN rsa
	END PubKey;

	PROCEDURE ChineseRemainder( msg, d, p, q, u: Number ): Number;
	(*
		d: secret exponent
		p, q: prime factors of n
		u = (1/p)  (mod q)
		Precondition: p < q
	*)
	VAR
		temp1, temp2, p2, q2: Number;
	BEGIN
		ASSERT( B.Cmp( p, q ) < 0, 100 );

		(* p2 := [(msg mod p) ^ (d mod (p-1))] mod p *)
		temp1 := B.Sub( p, one );
		temp2 := B.Mod( d, temp1 );		(* temp2 := d mod (p-1)) *)
		temp1 := B.Mod( msg, p );		(* temp1 := msg mod p *)
		p2 := B.ModExp( temp1, temp2, p );

		(* q2 := [(msg mod q) ^ (d mod (q-1))] mod q *)
		temp1 := B.Sub( q, one );
		temp2 := B.Mod( d, temp1 );		(* temp2 := d mod (q-1)) *)
		temp1 := B.Mod( msg, q );		(* temp1 := msg mod q *)
		q2 := B.ModExp( temp1, temp2, q );

		IF B.Cmp( q2, p2 ) = 0 THEN  (* msg < p *)
			RETURN p2
		ELSE
			WHILE B.Cmp( q2, p2 ) < 0 DO  q2 := B.Add( q2, q )  END;
			q2 := B.Sub( q2, p2 );
			temp1 := B.Mul( q2, u );
			temp2 := B.Mod( temp1, q );
			temp1 := B.Mul( p, temp2 );
			RETURN B.Add( temp1, p2 )
		END ;
	END ChineseRemainder;


	PROCEDURE LoadPrivateKey*( r: Streams.Reader;  CONST passwd: ARRAY OF CHAR ): Key;
	VAR
		s: ARRAY 128 OF CHAR;
		c, l: Certificate;
		k: Key;

		cipher: Ciphers.Cipher;
		md5: MD5.Hash;
		digest: ARRAY 16 OF CHAR; pl: LONGINT;
		buf: ARRAY 4096 OF CHAR; bl, n, magic: LONGINT;

	BEGIN
		NEW( k );
		r.String( k.name );
		r.RawBool( k.private );
		ASSERT( k.private );
		r.RawLInt( k.size );
		r.RawLInt( k.time );
		r.RawLInt( k.date );

		r.RawLInt( bl );
		r.Bytes( buf, 0, bl, n );
		ASSERT( n = bl );

		pl := 0;
		WHILE passwd[pl] # 0X DO  INC( pl )  END;
		NEW( md5 );
		md5.Initialize;
		md5.Update( passwd, 0, pl );
		md5.GetHash( digest, 0 );
		cipher := Ciphers.NewCipher("CryptoIDEA");
		cipher.InitKey( digest, 128 );

		cipher.Decrypt( buf, 0, bl );
		bl := 0;
		U.GetLength( buf, bl, magic );
		IF magic # PrivateKeyMagic THEN (* wrong passphrase*)  RETURN NIL  END;
		U.GetBigNumber( buf, bl, k.exponent );
		U.GetBigNumber( buf, bl, k.modulus );
		U.GetBigNumber( buf, bl, k.p );
		U.GetBigNumber( buf, bl, k.q );
		U.GetBigNumber( buf, bl, k.u );

		l := NIL;
		r.String( s );
		WHILE s # "EOC" DO
			NEW( c );
			COPY( s, c.authority );
			B.FileRead( r, c.signature );
			IF l = NIL THEN  k.certificates := c  ELSE  l.next := c  END;
			l := c;
			r.String( s )
		END;
		RETURN k
	END LoadPrivateKey;


	PROCEDURE StorePrivateKey*( w: Streams.Writer;  k: Key;  CONST passwd: ARRAY OF CHAR );
	VAR
		c: Certificate;

		cipher: Ciphers.Cipher;
		md5: MD5.Hash;
		digest: ARRAY 16 OF CHAR; pl: LONGINT;
		buf: ARRAY 4096 OF CHAR; bl: LONGINT;

	BEGIN
		ASSERT( k.private );
		w.Char( '"' ); w.String( k.name ); w.Char( '"' );
		w.RawBool( k.private );
		w.RawLInt( k.size );
		w.RawLInt( k.time );
		w.RawLInt( k.date );

		pl := 0;
		WHILE passwd[pl] # 0X DO  INC( pl )  END;
		NEW( md5 );
		md5.Initialize;
		md5.Update( passwd, 0, pl );
		md5.GetHash( digest, 0 );
		cipher := Ciphers.NewCipher("CryptoIDEA");
		cipher.InitKey( digest, 128 );

		bl := 0;
		U.PutLength( buf, bl, PrivateKeyMagic );
		U.PutBigNumber( buf, bl, k.exponent );
		U.PutBigNumber( buf, bl, k.modulus );
		U.PutBigNumber( buf, bl, k.p );
		U.PutBigNumber( buf, bl, k.q );
		U.PutBigNumber( buf, bl, k.u );
		INC( bl, (-bl) MOD 16 );
		cipher.Encrypt( buf, 0, bl );
		w.RawLInt( bl );
		w.Bytes( buf, 0, bl );

		c := k.certificates;
		WHILE c # NIL DO
			w.String( c.authority );
			B.FileWrite( w, c.signature );
			c := c.next;
		END;
		w.String( "EOC" )
	END StorePrivateKey;

	PROCEDURE StorePublicKey*( w: Streams.Writer; k: Key );	(* openssh format *)
	VAR buf, encoded: ARRAY 4096 OF CHAR; pos: LONGINT;
	BEGIN
		ASSERT( ~k.private );
		w.String( "ssh-rsa " );
		pos := 0;
		U.PutString( buf, pos, "ssh-rsa" );
		U.PutBigNumber( buf, pos, k.exponent );
		U.PutBigNumber( buf, pos, k.modulus );
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
		ASSERT( str = "ssh-rsa" );
		U.GetBigNumber( buf, pos, k.exponent );
		U.GetBigNumber( buf, pos, k.modulus );
		RETURN k
	END LoadPublicKey;

BEGIN
	B.AssignInt( one, 1 );
	B.AssignInt( two, 2 );
END CryptoRSA.

SystemTools.Free CryptoRSA ~