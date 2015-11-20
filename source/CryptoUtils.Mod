MODULE CryptoUtils; (** AUTHOR "GF"; PURPOSE ""; *)

IMPORT S := SYSTEM, Out := KernelLog, Random, Kernel, B := CryptoBigNumbers;


TYPE 
	InitBuffer* = OBJECT	(**   buffer supporting initialization of large tables with hex values  *)
	VAR 
		buf: POINTER TO ARRAY OF CHAR;
		in, out: LONGINT;
		
		PROCEDURE & Init*( size: LONGINT );
		BEGIN
			NEW( buf, size );  in := 0;  out := 0;
		END Init;
		
		PROCEDURE Add*( CONST x: ARRAY OF CHAR );
		VAR  i: LONGINT;  c: CHAR;
		BEGIN
			c := x[0];  i := 1;
			WHILE c # 0X DO 
				buf[in] := c;  INC( in );  c := x[i];  INC( i )
			END;
			buf[in] := ' ';  INC( in );  buf[in] := 0X
		END Add;
		
		
		PROCEDURE GetInt*( ): LONGINT;
		VAR x: LONGINT; c: CHAR;
		BEGIN
			WHILE (buf[out] <= ' ') & (buf[out] # 0X) DO  INC( out )  END;
			c := buf[out];  INC( out );  x := 0;
			REPEAT
				IF (c >= '0') & (c <= '9')  THEN  x := 16*x + (ORD( c ) - ORD( '0' ))
				ELSIF (c >= 'A') & (c <= 'F') THEN  x := 16*x + (ORD( c ) - ORD( 'A' ) + 10)
				ELSIF (c >= 'a') & (c <= 'f') THEN  x := 16*x + (ORD( c ) - ORD( 'a' ) + 10)
				ELSE  HALT( 100 )
				END;
				c := buf[out];  INC( out )
			UNTIL c <= ' ';
			RETURN x
		END GetInt;
		
		PROCEDURE GetSet*(): SET;
		BEGIN
			RETURN S.VAL( SET, GetInt() )
		END GetSet;
		
	END InitBuffer


VAR
	hexd: ARRAY 17 OF CHAR;	(* constant *)




	PROCEDURE PrintHex*( CONST buf: ARRAY OF CHAR;  p, n: LONGINT );
	VAR ch, i: LONGINT;
	BEGIN
		FOR i := 0 TO n - 1 DO
			IF i MOD 4 = 0 THEN
				IF i MOD 24 = 0 THEN Out.Ln  END;
				Out.String( "   " )
			END;
			ch := ORD( buf[p + i] );
			Out.Char( hexd[ch DIV 10H] );
			Out.Char( hexd[ch MOD 10H] );
		END
	END PrintHex;

	PROCEDURE PrintBufferString*( CONST buf: ARRAY OF CHAR;  pos: LONGINT );
	VAR i, p, len: LONGINT;
	BEGIN
		p := pos;
		GetLength( buf, p, len );
		FOR i := 0 TO len - 1 DO Out.Char( buf[p + i] )  END
	END PrintBufferString;

	PROCEDURE PrintPackage*( CONST buf: ARRAY OF CHAR;  len: LONGINT );
	VAR i: LONGINT;  c: CHAR;
	BEGIN
		FOR i := 0 TO len - 1 DO
			IF i MOD 24 = 0 THEN Out.Ln END;
			IF i MOD 4 = 0 THEN Out.Char( ' ' ) END;
			c := buf[i];
			Out.Char( hexd[ ORD( c ) DIV 16] );
			Out.Char( hexd[ ORD( c ) MOD 16] );
		END ;
		Out.Ln
	END PrintPackage;



	(*==========  packet buffer <---> program data  ===========*)


	PROCEDURE PutLength*( VAR buf: ARRAY OF CHAR;  VAR pos: LONGINT;  len: LONGINT );
	VAR i: INTEGER;
	BEGIN
		FOR i := 3 TO 0 BY -1 DO
			buf[pos + i] := CHR( len MOD 256 );  len := len DIV 256
		END;
		INC( pos, 4 )
	END PutLength;


	PROCEDURE GetLength*( CONST buf: ARRAY OF CHAR;  VAR pos, len: LONGINT );
	BEGIN
		len :=	ASH( LONG( ORD( buf[pos] ) ), 24 ) +
				ASH( LONG( ORD( buf[pos + 1] ) ), 16 ) +
				ASH( LONG( ORD( buf[pos + 2] ) ), 8 ) +
				ORD( buf[pos + 3] );
		INC( pos, 4 );
	END GetLength;


	PROCEDURE GetInt*( CONST buf: ARRAY OF CHAR;  pos: LONGINT ): LONGINT;
	BEGIN
		RETURN	ASH( LONG( ORD( buf[pos] ) ), 24 ) +
				ASH( LONG( ORD( buf[pos + 1] ) ), 16 ) +
				ASH( LONG( ORD( buf[pos + 2] ) ), 8 ) +
				ORD( buf[pos + 3] );
	END GetInt;


	PROCEDURE PutChar*( VAR buf: ARRAY OF CHAR;  VAR pos: LONGINT;  ch: CHAR );
	BEGIN
		buf[pos] := ch;  INC( pos )
	END PutChar;

	PROCEDURE GetChar*( CONST buf: ARRAY OF CHAR;  VAR pos: LONGINT;  VAR ch: CHAR );
	BEGIN
		ch := buf[pos];  INC( pos )
	END GetChar;

	PROCEDURE PutString*( VAR buf: ARRAY OF CHAR;  VAR pos: LONGINT;  CONST str: ARRAY OF CHAR );
	VAR i, len: LONGINT;
	BEGIN
		len := 0;
		WHILE (len < LEN(str)) & (str[len] # 0X) DO INC( len ) END;
		PutLength( buf, pos, len );
		FOR i := 0 TO len -1 DO buf[pos] := str[i];  INC( pos )  END ;
	END PutString;

	PROCEDURE GetString*( CONST buf: ARRAY OF CHAR;  VAR pos: LONGINT;  VAR str: ARRAY OF CHAR );
	VAR i, len: LONGINT;
	BEGIN
		GetLength( buf, pos, len );
		FOR i := 0 TO len -1 DO str[i] := buf[pos];  INC( pos )  END;
		str[len] := 0X
	END GetString;


	PROCEDURE PutArray*(	VAR buf: ARRAY OF CHAR;  VAR pos: LONGINT;
							CONST arr: ARRAY OF CHAR;  apos, len: LONGINT  );
	VAR i: LONGINT;
	BEGIN
		PutLength( buf, pos, len );
		FOR i := 0 TO len -1 DO buf[pos] := arr[apos + i];  INC( pos )  END
	END PutArray;


	PROCEDURE PutBigNumber*( VAR buf: ARRAY OF CHAR;  VAR pos: LONGINT;  b: B.BigNumber );
	VAR i, j, len, x: LONGINT;  tmp: ARRAY 2048 OF CHAR;
	BEGIN
		len := 0;
		FOR i := b.len - 1 TO 0 BY -1 DO
			(* store 'digits' in network byte order (big endian) *)
			x := b.d[i];
			FOR j := 3 TO 0 BY -1 DO
				tmp[len + j] := CHR( x MOD 256 );  x := x DIV 256
			END;
			INC( len, 4 )
		END;
		j := 0;
		WHILE tmp[j] = 0X DO  INC( j );  DEC( len )  END;
		IF ORD( tmp[j] ) >= 128 THEN  PutLength( buf, pos, len + 1 );  buf[pos] := 0X;  INC( pos )
		ELSE  PutLength( buf, pos, len );
		END;
		FOR i := 0 TO len - 1 DO  buf[pos] := tmp[j + i];  INC( pos )  END;
	END PutBigNumber;

	PROCEDURE GetBigNumber*( CONST buf: ARRAY OF CHAR;  VAR pos: LONGINT;  VAR b: B.BigNumber );
	VAR
		len: LONGINT;
	BEGIN
		GetLength( buf, pos, len );
		B.AssignBin( b, buf, pos, len );
		INC( pos, len )
	END GetBigNumber;


	(*----------------   misc   -------------------------------*)

	(** convert 2*len hex nibbles into len bytes *)
	PROCEDURE Hex2Bin*(	CONST hex: ARRAY OF CHAR;  hp: LONGINT;
							VAR bin: ARRAY OF CHAR;  bp: LONGINT;
							len: LONGINT );
	VAR
		i: INTEGER;  h, b: LONGINT; c: CHAR;
	BEGIN
		i := 0;
		WHILE i < 2*len DO 		(* parse one nibble at a time *)
			c := hex[hp + i];
			IF (c >= '0') & (c <= '9') THEN h := ORD( c ) - ORD( '0' );
			ELSIF (c >= 'a') & (c <= 'f') THEN h := ORD( c ) - ORD( 'a' ) + 10;
			ELSIF (c >= 'A') & (c <= 'F') THEN h := ORD( c ) - ORD( 'A' ) + 10;
			ELSIF c = 0X THEN
				Out.String( "### error: hex source too short" ); Out.Ln;
				HALT( 99 )
			ELSE
				Out.String( "### format error in hex string" ); Out.Ln;
				HALT( 99 )
			END;
			IF ODD( i ) THEN bin[bp] := CHR( b + h );  INC( bp )
			ELSE b :=  h * 16
			END;
			INC( i );
		END
	END Hex2Bin;


	(** convert len bytes  into 2*len hex nibbles *)
	PROCEDURE Bin2Hex*(	CONST bin: ARRAY OF CHAR;  bp: LONGINT;
							VAR hex: ARRAY OF CHAR;  hp: LONGINT;
							len: LONGINT );
	VAR i, c: LONGINT;
	BEGIN
		FOR i := 0 TO len - 1 DO
			c := ORD( bin[ bp + i] );
			hex[hp] := hexd[ c DIV 16];  INC( hp );
			hex[hp] := hexd[ c MOD 16];  INC( hp );
		END
	END Bin2Hex;


	(** fill len pseudo-random bytes into buf, starting at posistion ofs *)
	PROCEDURE RandomBytes*( VAR buf: ARRAY OF CHAR;  ofs, len: LONGINT );
	VAR
		i: LONGINT;
		rg: Random.Generator;
	BEGIN
		NEW( rg );
		rg.InitSeed( Kernel.GetTicks() );
		FOR i := 0 TO len - 1 DO buf[ ofs + i ] := CHR( ENTIER( rg.Uniform()*256 ) ) END
	END RandomBytes;


	PROCEDURE XORBlock*( VAR block, iv: ARRAY OF S.BYTE );
	VAR a1, a2: ADDRESS; s1, s2: SET; i: LONGINT;
	BEGIN
		a1 := ADDRESSOF( block );  a2 := ADDRESSOF( iv );
		FOR i := 1 TO LEN( block ) DIV 4 DO
			S.GET( a1, s1 );  S.GET( a2, s2 );  S.PUT( a1, s1 / s2 );
			INC( a1, 4 ); INC( a2, 4 )
		END
	END XORBlock;


	(* copy char buffer to 32-bit words in block. big endian format *)
	PROCEDURE BufferToBlockBE*( CONST buf: ARRAY OF CHAR; pos: LONGINT; VAR block: ARRAY OF S.BYTE );
	VAR i: LONGINT; a: ADDRESS;
	BEGIN
		a := ADDRESSOF( block );
		FOR i := 1 TO LEN( block ) DIV 4 DO
			S.PUT( a,
					ASH( LONG( ORD( buf[pos + 0] ) ), 24 ) +
					ASH( LONG( ORD( buf[pos + 1] ) ), 16 ) +
					ASH( LONG( ORD( buf[pos + 2] ) ), 8 ) +
					ORD( buf[pos + 3] ) );
			INC( a, 4 );  INC( pos, 4 )
		END
	END BufferToBlockBE;
	
	
	(* copy char buffer to 32-bit words in block. little endian format *)
	PROCEDURE BufferToBlockLE*( CONST buf: ARRAY OF CHAR;  pos: LONGINT;  VAR block: ARRAY OF S.BYTE );
	VAR i: LONGINT;  a: ADDRESS;
	BEGIN
		a := ADDRESSOF( block );
		FOR i := 1 TO LEN( block ) DIV 4 DO
			S.PUT( a,
					ASH( LONG( ORD( buf[pos + 3] ) ), 24 ) +
					ASH( LONG( ORD( buf[pos + 2] ) ), 16 ) +
					ASH( LONG( ORD( buf[pos + 1] ) ), 8 ) +
					ORD( buf[pos + 0] ) );
			INC( a, 4 );  INC( pos, 4 )
		END
	END BufferToBlockLE;

	(* copy 32bit words in block to char buffer. big endian format *)
	PROCEDURE BlockToBufferBE*( CONST block: ARRAY OF S.BYTE;  VAR buf: ARRAY OF CHAR; pos: LONGINT );
	VAR a: ADDRESS; i, w: LONGINT;
	BEGIN
		a := ADDRESSOF( block );
		FOR i := 1 TO LEN( block ) DIV 4 DO
			S.GET( a, w );  INC( a, 4 );
			buf[pos + 3] := CHR( w MOD 256 );  w := w DIV 256;
			buf[pos + 2] := CHR( w MOD 256 );  w := w DIV 256;
			buf[pos + 1] := CHR( w MOD 256 );  w := w DIV 256;
			buf[pos + 0] := CHR( w MOD 256 );
			INC( pos, 4 )
		END
	END BlockToBufferBE;

	(* copy 32bit words in block to char buffer. little endian format *)
	PROCEDURE BlockToBufferLE*( CONST block: ARRAY OF S.BYTE;  VAR buf: ARRAY OF CHAR;  pos: LONGINT );
	VAR a: ADDRESS;  i, w: LONGINT;
	BEGIN
		a := ADDRESSOF( block );
		FOR i := 1 TO LEN( block ) DIV 4 DO
			S.GET( a, w );  INC( a, 4 );
			buf[pos + 0] := CHR( w MOD 100H );  w := w DIV 100H;
			buf[pos + 1] := CHR( w MOD 100H );  w := w DIV 100H;
			buf[pos + 2] := CHR( w MOD 100H );  w := w DIV 100H;
			buf[pos + 3] := CHR( w MOD 100H );
			INC( pos, 4 )
		END
	END BlockToBufferLE;
	
	PROCEDURE SetToBufferBE*( val: SET;  VAR buf: ARRAY OF CHAR;  pos: LONGINT );
	BEGIN
		IntToBufferBE( S.VAL( LONGINT, val ), buf, pos );
	END SetToBufferBE;

	PROCEDURE IntToBufferBE*( val: LONGINT;  VAR buf: ARRAY OF CHAR;  pos: LONGINT );
	BEGIN
		buf[pos + 3] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 2] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 1] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 0] := CHR( val MOD 256 );
	END IntToBufferBE;
	
	PROCEDURE SetToBufferLE*( val: SET;  VAR buf: ARRAY OF CHAR;  pos: LONGINT );
	BEGIN
		IntToBufferLE( S.VAL( LONGINT, val ), buf, pos );
	END SetToBufferLE;
	
	PROCEDURE IntToBufferLE*( val: LONGINT;  VAR buf: ARRAY OF CHAR;  pos: LONGINT );
	BEGIN
		buf[pos + 0] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 1] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 2] := CHR( val MOD 256 );  val := val DIV 256;
		buf[pos + 3] := CHR( val MOD 256 );
	END IntToBufferLE;
	
	
	PROCEDURE SetFromBufferBE*( CONST buf: ARRAY OF CHAR;  pos: LONGINT ): SET;
	BEGIN
		RETURN  S.VAL( SET, IntFromBufferBE( buf, pos ) )
	END SetFromBufferBE;
	
	PROCEDURE IntFromBufferBE*( CONST buf: ARRAY OF CHAR;  pos: LONGINT ): LONGINT;
	BEGIN
		RETURN	ASH( LONG( ORD( buf[pos + 0] ) ), 24 ) +
					ASH( LONG( ORD( buf[pos + 1] ) ), 16 ) +
					ASH( LONG( ORD( buf[pos + 2] ) ), 8 ) +
					ORD( buf[pos + 3] );
	END IntFromBufferBE;


	PROCEDURE SetFromBufferLE*( CONST buf: ARRAY OF CHAR;  pos: LONGINT ): SET;
	BEGIN
		RETURN  S.VAL( SET, IntFromBufferLE( buf, pos ) )
	END SetFromBufferLE;

	PROCEDURE IntFromBufferLE*( CONST buf: ARRAY OF CHAR;  pos: LONGINT ): LONGINT;
	BEGIN
		RETURN	ASH( LONG( ORD( buf[pos + 3] ) ), 24 ) +
					ASH( LONG( ORD( buf[pos + 2] ) ), 16 ) +
					ASH( LONG( ORD( buf[pos + 1] ) ), 8 ) +
					ORD( buf[pos] );
	END IntFromBufferLE;
	


BEGIN
	hexd := "0123456789ABCDEF";
END CryptoUtils.



