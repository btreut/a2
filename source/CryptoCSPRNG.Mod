MODULE CryptoCSPRNG;	(** AUTHOR "GF"; PURPOSE "Cryptographically Secure Pseudo-Random Generator."*)
 
 
IMPORT  Machine, Clock, Heaps, SHA3 := CryptoSHA3(*, Out := KernelLog*);


	PROCEDURE CSRand*( VAR rand: ARRAY OF CHAR; bits: LONGINT );
	VAR 
		seed: HUGEINT; i, j, len: LONGINT;
		h: SHA3.Hash;
		buf: ARRAY 64 OF CHAR;
	BEGIN
		ASSERT( (bits MOD 8 = 0) & (bits DIV 8 <= LEN( rand )) );
		seed := Noise();
		FOR i := 0 TO 7 DO  
			buf[i] := CHR( seed MOD 100H );  seed := seed DIV 100H  
		END;
		NEW( h );  h.SetNameAndSize( "", 64 );
		h.Update( buf, 0, 8 );
		h.GetHash( buf, 0 );
		i := 0;  j := 0;  len := bits DIV 8;
		WHILE j < len DO
			IF i = 64 THEN
				h.Initialize;  
				h.Update( buf, 0, 64 );
				h.GetHash( buf, 0 );
				i := 0
			END;
			rand[j] := buf[i];  INC( j ); INC( i )
		END
	END CSRand;
	
	PROCEDURE Noise( ): HUGEINT;
	VAR tm, dt: HUGEINT; t, d: LONGINT;  total, free, largest: SIZE;
	BEGIN
		tm := Machine.GetTimer( );
		Clock.Get( t, d );  
		dt := LONG( d ) * 1000000H + t;
		Heaps.GetHeapInfo( total, free, largest ); 
		RETURN  (tm + 4*dt + Heaps.Nmark) * (Heaps.Ngc + 1) + (total - free + largest )
	END Noise;
	
	(*
	PROCEDURE Test*;
	CONST HT = 09X;
	VAR rand: ARRAY 512 OF CHAR; i: LONGINT;
	BEGIN
		CSRand( rand, 2048 );
		Out.Ln;
		FOR i := 0 TO 255 DO
			Out.Hex( ORD( rand[i] ), -2 );
			IF (i+1) MOD 4 = 0 THEN  Out.Char( HT )  END;
			IF (i+1) MOD 32 = 0 THEN  Out.Ln  END
		END;
		Out.Ln
	END Test;
	*)
	

END CryptoCSPRNG.


	CryptoCSPRNG.Test ~
	
	SystemTools.Free CryptoCSPRNG ~