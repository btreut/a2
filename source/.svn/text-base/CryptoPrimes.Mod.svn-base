MODULE CryptoPrimes;

(*	2002.9.11	g.f.	based on 'bn_prime.c'

		Copyright of the original:    <-- middle click here
*)

IMPORT B := CryptoBigNumbers, Out := KernelLog;

CONST
	N = 2048;

TYPE
	BigNumber = B.BigNumber;

VAR
	one: BigNumber;
	primes: ARRAY N OF LONGINT;


	PROCEDURE NewPrime*( bits: INTEGER;  safe: BOOLEAN ): BigNumber;
	VAR checks, i: INTEGER;  t, p: BigNumber;
	BEGIN
		checks := Checks( bits ); i := 1;
		LOOP
			p := ProbablePrime( bits );
			Out.Char( '.' );
			IF IsPrime( p, checks, FALSE ) THEN
				Out.Char( 'P' );
				IF ~safe THEN  Out.Ln;  RETURN p
				ELSE
					Out.Int( i, 0 );  INC( i );
					(* for "safe prime" generation, check that (p-1)/2 is prime. *)
					B.Copy( p, t );  t.Shift( -1 );
					IF IsPrime( t, checks, FALSE ) THEN
						Out.String( " (safe prime)" ); Out.Ln;
						RETURN p
					END;
					Out.String( " (not safe)" ); Out.Ln;
				END
			END;
		END
	END NewPrime;

	PROCEDURE NewDHPrime*( bits: INTEGER;  safe: BOOLEAN;  add, rem: BigNumber ): BigNumber;
	VAR checks: INTEGER;  t, p: BigNumber;
	BEGIN
		checks := Checks( bits );
		LOOP
			IF safe THEN  p := ProbableDHPrimeSafe( bits, add, rem )
			ELSE p := ProbableDHPrime( bits, add, rem )
			END;
			IF IsPrime( p, checks, FALSE ) THEN
				IF ~safe THEN  RETURN p
				ELSE  (* for "safe prime" generation, check that (p-1)/2 is prime. *)
					B.Copy( p, t );  t.Shift( -1 );
					IF IsPrime( t, checks, FALSE ) THEN  RETURN p  END
				END
			END
		END
	END NewDHPrime;

	PROCEDURE Checks( b: LONGINT ): INTEGER;
	(* number of Miller-Rabin iterations for an error rate  of less than 2^-80
		for random 'b'-bit input, b >= 100 (taken from table 4.4 in the Handbook
		of Applied Cryptography [Menezes, van Oorschot, Vanstone; CRC Press 1996]
	*)
	VAR t: INTEGER;
	BEGIN
		ASSERT( b >= 100 );
		IF b >= 1300 THEN t := 2
		ELSIF b >= 850 THEN t := 3
		ELSIF b >= 650 THEN t := 4
		ELSIF b >= 550 THEN t := 5
		ELSIF b >= 450 THEN t := 6
		ELSIF b >= 400 THEN t := 7
		ELSIF b >= 350 THEN t := 8
		ELSIF b >= 300 THEN t := 9
		ELSIF b >= 250 THEN t := 12
		ELSIF b >= 200 THEN t := 15
		ELSIF b >= 150 THEN t := 18
		ELSE  t := 27
		END;
		RETURN t
	END Checks;



	PROCEDURE ProbablePrime( bits: INTEGER ): BigNumber;
	VAR t: BigNumber;  delta, i: LONGINT; p: BigNumber;
		mods: ARRAY N OF LONGINT;
	BEGIN
		LOOP
			p := B.NewRand( bits, 1, 1 );
			FOR i := 0 TO N - 1 DO  mods[i] := B.ModWord( p, primes[i] )  END;
			(* check that p is not a prime and also that gcd( p-1, primes) = 1 (except for 2) *)
			i := 0;  delta := 0;
			LOOP
				INC( i );
				IF i >= N THEN
					B.AssignInt( t, delta );  p := B.Add( p, t );
					RETURN p
				END;
				IF (mods[i] + delta) MOD primes[i] <= 1 THEN
					INC( delta, 2 );  i := 0;
					IF delta < 0 THEN  (* overfow! try new random *)  EXIT  END;
				END;
			END
		END
	END ProbablePrime;


	PROCEDURE ProbableDHPrime( bits: INTEGER;  add, rem: BigNumber ): BigNumber;
	VAR d, r, p: BigNumber;  i: LONGINT;
	BEGIN
		p := B.NewRand( bits, 0, 1 );

		(* we need (p - rem) mod add = 0 *)
		r := B.Mod( p, add );  p := B.Sub( p, r );
		IF rem.IsZero( ) THEN  p.Inc  ELSE  p := B.Add( p, rem )  END;

		(* we now have a random number 'p' to test. *)
		i := 0;
		LOOP
			INC( i );
			IF i >= N THEN  RETURN p  END;
			B.AssignInt( d, primes[i] );  r := B.Mod( p, d );
			IF r.IsZero( ) THEN  p := B.Add( p, add );  i := 0  END;
		END
	END ProbableDHPrime;

	PROCEDURE ProbableDHPrimeSafe( bits: INTEGER; padd, rem: BigNumber ): BigNumber;
	VAR d, q, r, qr, qadd, p: BigNumber;  i: LONGINT;
	BEGIN
		B.Copy( padd, qadd );  qadd.Shift( -1 );
		q := B.NewRand( bits, 0, 1 );

		r := B.Mod( q, qadd );  q := B.Sub( q, r );
		IF rem.IsZero( ) THEN  q.Inc
		ELSE  B.Copy( rem, r );  r.Shift( -1 );  q := B.Add( q, r )
		END;

		(* we now have a random number  to test. *)
		B.Copy( q, p );  p.Shift( 1 );  p.Inc;

		i := 0;
		LOOP
			INC( i );
			IF i >= N THEN  RETURN p  END;
			B.AssignInt( d, primes[i] );  r := B.Mod( p, d );  qr := B.Mod( q, d );
			IF r.IsZero( ) OR qr.IsZero( ) THEN
				p := B.Add( p, padd );  q := B.Add( q, qadd );  i := 0
			END;
		END
	END ProbableDHPrimeSafe;


	PROCEDURE IsPrime*( a: BigNumber;  checks: INTEGER;  doTrialDiv: BOOLEAN ): BOOLEAN;
	VAR i, k: INTEGER;  A, A1, A1odd, check: BigNumber;
	BEGIN
		IF checks = 0 THEN  checks := Checks( a.BitSize( ) )  END;
		IF ~ODD( a.d[0] ) THEN  RETURN FALSE  END;
		IF doTrialDiv THEN
			FOR i := 1 TO N - 1 DO
				IF B.ModWord( a, primes[i] ) = 0 THEN  RETURN FALSE  END
			END
		END;
		B.Copy( a, A );
		IF A.neg THEN  A.Negate  END;
		B.Copy( A, A1 );  A1.Dec;
		IF A1.IsZero( ) THEN  RETURN FALSE  END;

		(* write  A1  as  A1odd * 2^k *)
		k := 1;  WHILE ~A1.BitSet( k ) DO  INC( k )  END;
		B.Copy( A1, A1odd );  A1odd.Shift( -k );

		FOR i := 1 TO checks DO
			check := B.NewRand( A1.BitSize( ), 0, 0 );
			IF check.GEQ( A1 ) THEN  check := B.Sub( check, A1 )  END;
			check.Inc;
			(* now 1 <= check < A *)
			IF ~witness( check, A, A1, A1odd, k ) THEN   RETURN FALSE  END;
		END;
		RETURN TRUE
	END IsPrime;

	PROCEDURE witness( W, a, a1, a1odd: BigNumber;  k: INTEGER): BOOLEAN;
	VAR w: BigNumber;
	BEGIN
		w := B.ModExp( W, a1odd, a );
		IF w.EQ( one ) THEN  (* probably prime *)  RETURN TRUE  END;
		IF w.EQ( a1 ) THEN   RETURN TRUE  END;
				(* w = -1 (mod a), a is probably prime *)
		WHILE k > 0 DO
			w := B.ModMul( w, w, a );  (* w = w^2 mod a *)
			IF w.EQ( one ) THEN  RETURN FALSE  END;
					(* a is composite, otherwise a previous w would  have been = -1 (mod a) *)
			IF w.EQ( a1 ) THEN  RETURN TRUE  END;
					(* w = -1 (mod a), a is probably prime *)
			DEC( k )
		END;
		(* If we get here, w is the (a-1)/2-th power of the original w, *)
		(* and it is neither -1 nor +1 -- so a cannot be prime *)
		RETURN FALSE
	END witness;

	PROCEDURE Init;
	VAR sieve: ARRAY N OF SET; i, j, p, n: LONGINT;
	BEGIN
		(* compute the first N small primes *)
		FOR i := 0 TO N - 1 DO sieve[i] := {0..31} END;
		primes[0] := 2;  n := 1;  i := 1;
		WHILE n < N DO
			IF i MOD 32 IN sieve[i DIV 32] THEN
				p := 2*i + 1;  primes[n] := p;  INC( n );  j := i;
				WHILE j DIV 32 < N DO  EXCL( sieve[j DIV 32], j MOD 32 );  INC( j, p )  END;
			END;
			INC( i )
		END;
	END Init;

BEGIN
	Init;  B.AssignInt( one, 1 ); 
END CryptoPrimes.

