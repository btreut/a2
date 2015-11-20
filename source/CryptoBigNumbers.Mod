MODULE CryptoBigNumbers;  (* g.f.	2001.10.07 *)

(* 2002.08.12	g.f.	added neg. numbers, GCD and ModInverse  *)
(* 2002.09.24	g.f.	inceased digit size from 8 bit to 32 bit *)
(* 2002.10.04	g.f.	faster version of ModExp (uses montgomery multiplications now) *)
(* 2005.07.07	g.f.	Fabian Nart's enhancements incorporated *)
(* 2010.01.12	g.f.	interface cleanup, most procedures got funtions *)


IMPORT S := SYSTEM, Streams, Random, Kernel, Out := KernelLog;

CONST
	BufferPoolSize = 16;

TYPE
	digits = POINTER TO ARRAY OF LONGINT;

	BigNumber* = OBJECT
			VAR
				len-: LONGINT;  (** number of significant 'digits' *)
				neg-: BOOLEAN;
				d-: digits;

				PROCEDURE & Init( bitsize: LONGINT );
				VAR n: LONGINT;
				BEGIN
					IF bitsize # 0 THEN
						n := SHORT( (bitsize + 31) DIV 32 );
						INC( n, (-n) MOD 16 );
						NEW( d, n );
					END;
					len := 0;  neg := FALSE
				END Init;
				
				PROCEDURE Mask*( bits: LONGINT );
				VAR w, b: LONGINT;
				BEGIN
					w := bits DIV 32;  b := bits MOD 32;  len := w;
					IF b # 0 THEN  INC( len );
						d[w] := S.VAL( LONGINT,  S.VAL( SET, d[w] ) * {0..b} )
					END
				END Mask;

				
				PROCEDURE IsZero*( ): BOOLEAN;
				BEGIN
					RETURN (len = 0) OR ((len = 1) & (d[0] = 0))
				END IsZero;
				
				PROCEDURE EQ* ( b: BigNumber ): BOOLEAN;
				BEGIN
					RETURN Cmp( SELF, b ) = 0
				END EQ;
				
				PROCEDURE NEQ* ( b: BigNumber ): BOOLEAN;
				BEGIN
					RETURN Cmp( SELF, b ) # 0
				END NEQ;
				
				PROCEDURE GT* ( b: BigNumber ): BOOLEAN;
				BEGIN
					RETURN Cmp( SELF, b ) > 0
				END GT;
				
				PROCEDURE GEQ* ( b: BigNumber ): BOOLEAN;
				BEGIN
					RETURN Cmp( SELF, b ) >= 0
				END GEQ;



				PROCEDURE Shift*( n: LONGINT );
				VAR right: BOOLEAN;  w, bits, i, l: LONGINT;  a, b: LONGINT;
				BEGIN
					IF len = 0 THEN  RETURN  END;
					IF n < 0 THEN  right := TRUE;  n := ABS( n )  ELSE  right := FALSE  END;
					w := n DIV 32;  bits := n MOD 32;
					IF ~right THEN  
						adjust( len + w + 1 );
						IF w > 0 THEN
							FOR i := len - 1 TO 0 BY -1 DO  d[i + w] := d[i]  END;
							FOR i := 0 TO w - 1 DO  d[i] := 0  END;
							INC( len, w )
						END;
						IF bits > 0 THEN  
							d[len] := 0;
							FOR i := len TO 0 BY -1 DO  
								a := d[i];
								IF i > 0 THEN  b := d[i - 1]  ELSE  b := 0  END;
								d[i] := LSH( a, bits ) + LSH( b, -32 + bits )
							END;
							IF d[len] # 0 THEN  INC( len )  END;
						END
					ELSE
						IF w > 0 THEN
							FOR i := 0 TO len - w - 1 DO  d[i] := d[i + w]  END;
							DEC( len, w )
						END;
						IF bits > 0 THEN  
							l := len;
							FOR i := 0 TO  l - 1 DO  a := d[i];
								IF i < l - 1 THEN  b := d[i + 1]  ELSE  b := 0  END;
								d[i] := LSH( a, -bits ) + LSH( b, 32 - bits )
							END;
							IF d[l - 1] = 0 THEN  DEC( len )  END;
						END
					END;
				END Shift;
				

				PROCEDURE Dec*;
				VAR i: LONGINT;
				BEGIN
					i := 0;
					IF IsZero( ) THEN  len := 1;  neg := TRUE;  d[0] := 1
					ELSIF neg THEN
						WHILE (d[i] = -1) & (i < len) DO  d[i] := 0;  INC( i )  END;
						IF i = len THEN  d[i] := 1;  INC( len )  ELSE  INC( d[i] )  END
					ELSE
						WHILE d[i] = 0 DO  d[i] := -1;  INC( i )  END;
						DEC( d[i] );  fixlen( d, len )
					END
				END Dec;

				PROCEDURE Inc*;
				VAR i: LONGINT;
				BEGIN
					i := 0;
					IF ~neg THEN
						WHILE (d[i] = -1) & (i < len) DO  d[i] := 0;  INC( i )  END;
						IF i = len THEN  d[i] := 1;  INC( len )  ELSE  INC( d[i] )  END
					ELSE
						WHILE d[i] = 0 DO  d[i] := -1;  INC( i )  END;
						DEC( d[i] );  fixlen( d, len );
						IF len = 0 THEN  neg := FALSE  END
					END
				END Inc;

				PROCEDURE Negate*;
				BEGIN
					IF ~IsZero( ) THEN  neg := ~neg  END
				END Negate;
	
				PROCEDURE BitSize*( ): LONGINT;
				VAR n, t: LONGINT;
				BEGIN
					IF len = 0 THEN  RETURN 0
					ELSE  n := (len - 1) * 32
					END;
					t := d[len - 1];
					WHILE t # 0 DO  INC( n );  t := LSH( t, -1 )  END;
					RETURN n 
				END BitSize;

				PROCEDURE BitSet*( n: LONGINT ): BOOLEAN;
				VAR w, bit: LONGINT;
				BEGIN
					w := n DIV 32;  bit := n MOD 32;
					IF w >= len THEN  RETURN FALSE
					ELSE  RETURN  bit IN S.VAL( SET, d[w] )
					END
				END BitSet;


				PROCEDURE adjust( newlen: LONGINT );
				VAR n, i: LONGINT;  nd: digits;
				BEGIN
					n := 16;
					WHILE n < newlen DO  INC( n, 16 )  END;
					IF LEN( d ) < n THEN
						NEW( nd, n );
						FOR i := 0 TO LEN( d^ ) - 1 DO  nd[i] := d[i]  END;
						d := nd
					END;
				END adjust;

			END BigNumber;

	dig2 = ARRAY 2 OF LONGINT;
	dig3 = ARRAY 3 OF LONGINT;

	Montgomery = OBJECT
				VAR
					bits: LONGINT;	(* of R *)
					r, n, t1, t2: BigNumber;

				PROCEDURE & Init( x: BigNumber );
				BEGIN
					Copy( x, n );  bits := x.len*32;
					AssignInt( r, 1 );  r.Shift( bits );	(* r := R *)
					r := Sub( r, ModInverse( n, r ) );   (* r := R - (1/n)  (mod R) *)
					n.adjust( 2*x.len );  r.adjust( 2*x.len );
					NEW( t1, 2*bits );  NEW( t2, 2*bits );
				END Init;

				PROCEDURE Convert( VAR val: BigNumber ); 	(* val := val ^ R mod n *)
				VAR i: LONGINT;
				BEGIN
					FOR i := 0 TO bits - 1 DO  
						val.Shift( 1 );
						IF ucmp( val, n ) >= 0 THEN  val := Sub( val, n )  END
					END
				END Convert;

				PROCEDURE Reduce( VAR val: BigNumber ); 	(* val := val ^ (1/R) mod n *)
				BEGIN
					Copy( val, t1 );  t1.Mask( bits - 1 ); 	(* val mod R *)
					mul( t1.d, r.d, t2.d, t1.len, r.len, t2.len );  t2.Mask( bits - 1 ); 	(* mod R *)
					mul( t2.d, n.d, t1.d, t2.len, n.len, t1.len );
					add( t1.d, val.d, val.d, t1.len, val.len, val.len );  val.Shift( -bits ); 	(* div R *)
					IF ucmp( val, n ) >= 0 THEN  sub( val.d, n.d, val.d, val.len, n.len, val.len )  END;
				END Reduce;


				PROCEDURE Mult( a, b: BigNumber ): BigNumber;
				VAR c: BigNumber;
				BEGIN
					NEW( c, 0 );
					mul( a.d, b.d, c.d, a.len, b.len, c.len );
					Reduce( c );
					RETURN c
				END Mult;

			END  Montgomery;


VAR
	bufferPool: ARRAY BufferPoolSize OF digits;
	nextFreeBuffer: LONGINT;

	randomgenerator: Random.Generator;


	PROCEDURE max( a, b: LONGINT ): LONGINT;
	BEGIN
		IF a >= b THEN  RETURN a  ELSE  RETURN b  END;
	END max;

	PROCEDURE LessThan( x, y: LONGINT ): BOOLEAN;  (* unsigned < *)
	VAR a, b: LONGINT;
	BEGIN
		a := LSH( x, -1 );  b := LSH( y, -1 );
		IF a = b THEN  RETURN (x MOD 2) < (y MOD 2)  ELSE  RETURN a < b  END
	END LessThan;

	PROCEDURE LessOrEqual( x, y: LONGINT ): BOOLEAN;  (* unsigned <= *)
	VAR a, b: LONGINT;
	BEGIN
		IF x = y THEN  RETURN TRUE
		ELSE
			a := LSH( x, -1 );  b := LSH( y, -1 );
			IF a = b THEN  RETURN (x MOD 2) < (y MOD 2)  ELSE  RETURN a < b  END
		END
	END LessOrEqual;

	PROCEDURE RandomBytes*( VAR buf: ARRAY OF CHAR;  p: LONGINT;  n: LONGINT );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO n - 1 DO buf[p + i] := CHR( ENTIER( randomgenerator.Uniform()*256 ) ) END
	END RandomBytes;



	PROCEDURE adjust( VAR d: digits;  dl, len: LONGINT );
	VAR n, i: LONGINT;  nd: digits;
	BEGIN
		ASSERT( d # NIL );
		n := 16;
		WHILE n < len DO  INC( n, 16)  END;
		IF LEN( d ) < n THEN
			NEW( nd, n );
			FOR i := 0 TO dl - 1 DO nd[i] := d[i] END;
			d := nd
		END;
	END adjust;


	(** random number with len 'bits' *)
	PROCEDURE NewRand*( bits: LONGINT;  top, bottom: SHORTINT ): BigNumber;
	VAR n, len, i, topbit: LONGINT;  topword: SET;  b: BigNumber;
	BEGIN
		len := bits;  INC( len, (-len) MOD 32 );
		NEW( b, len );
		n := len DIV 32;
		FOR i := 0 TO n -1 DO
			b.d[i] := randomgenerator.Integer()
		END;
		b.len := (bits + 31) DIV 32;
		topbit := (bits - 1)  MOD 32;
		topword := S.VAL( SET, b.d[b.len - 1] ) * {0..topbit};
		IF top > 0 THEN INCL( topword, topbit ) END;
		b.d[b.len - 1] := S.VAL( LONGINT, topword );
		IF (bottom > 0) & ~ODD( b.d[0] ) THEN  INC( b.d[0] )  END;
		RETURN b
	END NewRand;

	PROCEDURE NewRandRange*( range: BigNumber ): BigNumber;	(** 0 < b < range DIV 2 - 1*)
	VAR  b: BigNumber;
	BEGIN
		b := NewRand( range.BitSize( ) - 1, 0, 0 );
		b.Dec;
		RETURN b
	END NewRandRange;

	PROCEDURE fixlen( VAR d: digits;  VAR len: LONGINT );
	BEGIN
		WHILE (len > 0) & (d[len - 1] = 0) DO  DEC( len )  END;
	END fixlen;

	PROCEDURE h2i( c: CHAR ): LONGINT;
	VAR v: LONGINT;
	BEGIN
		CASE c OF
		| '0'..'9':  v := ORD( c ) - ORD( '0' )
		| 'a'..'f':  v := ORD( c ) - ORD( 'a' ) + 10
		| 'A'..'F':  v := ORD( c ) - ORD( 'A' ) + 10
		ELSE  HALT( 99 )
		END;
		RETURN v
	END h2i;

	PROCEDURE AssignHex*( VAR b: BigNumber;  CONST hex: ARRAY OF CHAR;  len: LONGINT );
	VAR n, w, pos: LONGINT;
	BEGIN
		ASSERT( len <= LEN( hex ) - 1);
		NEW( b, 4*len );  b.len := (4*len + 31) DIV 32;
		n := b.len - 1;  w := 0;  pos := 0;
		WHILE len > 0 DO
			w := w*16 + h2i( hex[pos] );  INC( pos );  DEC( len );
			IF len MOD 8 = 0 THEN  b.d[n] := w;  w := 0;  DEC( n )  END;
		END;
		fixlen( b.d, b.len )
	END AssignHex;

	PROCEDURE AssignBin*( VAR b: BigNumber;  CONST buf: ARRAY OF CHAR;  pos, len: LONGINT );
	VAR n, w: LONGINT;
	BEGIN
		ASSERT( (pos + len) <= LEN( buf ) );
		NEW( b, 8*len );  b.len := SHORT( (8*len + 31) DIV 32 );
		n := b.len - 1;  w := 0;
		WHILE len > 0 DO
			w := w*256 + ORD( buf[pos] );  INC( pos );  DEC( len );
			IF len MOD 4 = 0 THEN  b.d[n] := w;  w := 0;  DEC( n )  END;
		END;
		fixlen( b.d, b.len )
	END AssignBin;

	(** Returns the value of b as a binary string 'data' starting at ofs.
		The Length of 'data' must be longer or equal to 4*b.len + ofs. *)
	PROCEDURE GetBinaryValue*( VAR b: BigNumber; VAR data: ARRAY OF CHAR; ofs: LONGINT );
	VAR j, n, tmp: LONGINT;
	BEGIN
		ASSERT( LEN( data ) >= 4 * b.len + ofs );
		FOR n := b.len-1 TO 0 BY -1 DO
			tmp := b.d[n];
			FOR j := 3 TO 0 BY - 1 DO
				data[ ofs + j ] := CHR( tmp MOD 256 );
				tmp := tmp DIV 256
			END;
			INC( ofs, 4 )
		END
	END GetBinaryValue;

	PROCEDURE AssignInt*( VAR b: BigNumber;  val: LONGINT );
	BEGIN
		NEW( b, 64 );
		IF val < 0 THEN  b.neg := TRUE;  val := ABS( val ) END;
		IF val # 0 THEN  b.len := 1;  b.d[0] := val  ELSE  b.len := 0   END
	END AssignInt;

	PROCEDURE cmpd( VAR a, b: digits;  len: LONGINT ): SHORTINT;
	VAR i: LONGINT;
	BEGIN
		i := len - 1;
		WHILE (i >= 0) & (a[i] = b[i]) DO  DEC( i )  END;
		IF i < 0 THEN  RETURN 0
		ELSE
			IF LessThan( b[i], a[i] ) THEN  RETURN 1  ELSE  RETURN -1  END
		END
	END cmpd;

	PROCEDURE ucmp( VAR a, b: BigNumber ): SHORTINT;   (* 1: |a| > |b|;  0: a = b;  -1:  |a| < |b| *)
	BEGIN
		IF a.len > b.len THEN  RETURN 1
		ELSIF a.len < b.len THEN  RETURN -1
		ELSE  RETURN cmpd( a.d, b.d, a.len )
		END
	END ucmp;

	PROCEDURE Cmp*( a, b: BigNumber ): SHORTINT;   (** 1: a > b;  0: a = b;  -1:  a < b *)
	BEGIN
		IF a.neg # b.neg THEN
			IF a.neg THEN  RETURN -1  ELSE  RETURN 1  END
		ELSIF a.neg THEN  RETURN ucmp( a, b ) * (-1)
		ELSE  RETURN ucmp( a, b )
		END
	END Cmp;

	PROCEDURE copy( a, b: digits;  len: LONGINT );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO len - 1 DO  b[i] := a[i]  END
	END copy;

	PROCEDURE Copy*( VAR a, b: BigNumber );   (** b := a *)
	BEGIN
		ASSERT( (a # NIL) & (ADDRESSOF( a ) # ADDRESSOF( b )) );
		IF (b = NIL) OR (LEN( b.d^ ) < a.len) THEN  NEW( b, a.len*32 )  END;
		copy( a.d, b.d, a.len );  b.len := a.len
	END Copy;

	PROCEDURE Invert( x: LONGINT ): LONGINT;
	BEGIN
		RETURN S.VAL( LONGINT, -S.VAL( SET, x ) )
	END Invert;

	PROCEDURE add( a, b: digits; VAR c: digits;  al, bl: LONGINT;  VAR cl: LONGINT );
	VAR i, n: LONGINT;  A, B, x: LONGINT;  carry: BOOLEAN;
	BEGIN
		n := max( al, bl );  carry := FALSE;
		IF LEN( c^ ) < (n + 1) THEN  adjust( c, cl, n + 1 )  END;
		FOR i := 0 TO n - 1 DO
			IF i >= al THEN  A := 0  ELSE  A := a[i]  END;
			IF i >= bl THEN  B := 0  ELSE  B := b[i]  END;
			x := A + B;
			IF carry THEN  INC( x );  carry := LessOrEqual( Invert( A ), B )  
			ELSE  carry := LessThan( x, B )  
			END;
			c[i]:= x
		END;
		IF carry  THEN  c[n] := 1;  INC( n )  END;
		cl := n
	END add;

	PROCEDURE sub( a, b: digits;  VAR c: digits;  al, bl: LONGINT;  VAR cl: LONGINT );
	VAR i, n: LONGINT;  A, B, x: LONGINT;  borrow: BOOLEAN;
	BEGIN
		n := max( al, bl );  borrow := FALSE;
		IF LEN( c^ ) < n THEN  adjust( c, cl, n )  END;
		FOR i := 0 TO n - 1 DO
			IF i >= al THEN  A := 0  ELSE  A := a[i]  END;
			IF i >= bl THEN  B := 0  ELSE  B := b[i]  END;
			x := A - B;
			IF borrow THEN  DEC( x );  borrow := LessOrEqual( A, B )  ELSE  borrow := LessThan( A, B )  END;
			c[i]:= x
		END;
		ASSERT( ~borrow );
		WHILE (n > 0) & (c[n - 1] = 0) DO  DEC( n )  END;
		cl := n
	END sub;

	PROCEDURE Add*( a, b: BigNumber ): BigNumber;   (**  a + b *)
	VAR sd: digits;  l, sl: LONGINT;  c: BigNumber;
	BEGIN
		ASSERT( (a # NIL) & (b # NIL) );
		l := max( a.len, b.len ) + 1;
		NEW( c, l*32 );  sd := c.d;
		IF a.neg = b.neg THEN  add( a.d, b.d, sd, a.len, b.len, sl );  c.neg := a.neg
		ELSE
			IF ucmp( a, b ) >= 0 THEN  sub( a.d, b.d, sd, a.len, b.len, sl );  c.neg :=  a.neg
			ELSE  sub( b.d, a.d, sd, b.len, a.len, sl );  c.neg := ~a.neg
			END
		END;
		IF sd # c.d THEN  adjust( c.d, 0, sl );  copy( sd, c.d, sl )  END;
		c.len := sl;
		IF c.IsZero( ) THEN  c.neg := FALSE  END;
		RETURN c
	END Add;

	PROCEDURE Sub*( a, b: BigNumber ): BigNumber;   (**  a - b  *)
	VAR sd: digits;  l, sl: LONGINT;  c: BigNumber;
	BEGIN
		ASSERT( (a # NIL) & (b # NIL) );
		l := max( a.len, b.len ) + 1;
		NEW( c, l*32 );  sd := c.d;
		IF a.neg # b.neg THEN  add( a.d, b.d, sd, a.len, b.len, sl );  c.neg := a.neg
		ELSE
			IF ucmp( a, b ) >= 0  THEN  sub( a.d, b.d, sd, a.len, b.len, sl );  c.neg :=  a.neg
			ELSE  sub( b.d, a.d, sd, b.len, a.len, sl );  c.neg := ~a.neg
			END
			END;
		IF sd # c.d THEN  adjust( c.d, 0, sl );  copy( sd, c.d, sl )  END;
		c.len := sl;
		IF c.IsZero( ) THEN  c.neg := FALSE  END;
		RETURN c
	END Sub;


	PROCEDURE MulAdd( VAR high, low: LONGINT;  b, c, d: LONGINT );  	(* high | low := b * c + d *)
	VAR bh, bl, ch, cl, u, t, sum: LONGINT;
	BEGIN
		bh := LSH( b, -16 );  bl := b MOD 10000H;
		ch := LSH( c, -16 );  cl := c MOD 10000H;
		low := bl*cl;  t := ch*bl;  u := cl*bh;  high := bh*ch;
		INC( t, u );
		IF LessThan( t, u ) THEN  INC( high, 10000H )  END;
		u := t*10000H;  INC( low, u );
		IF LessThan( low, u ) THEN  INC( high )  END;
		INC( high, LSH( t, -16 ) );

		sum := low + d;
		IF LessThan( sum, low ) THEN  INC( high )  END;
		low := sum
	END MulAdd;



	PROCEDURE mul( a, b: digits; VAR c: digits;  al, bl: LONGINT;  VAR cl: LONGINT );  (* c := a*b *)
	VAR
		prod, sum, tmp, mulc: LONGINT;  addc: BOOLEAN;  i, j: LONGINT;  pl: LONGINT;
		p: digits;
	BEGIN
		pl := 0;  NEW( p, al + bl + 2 );
		FOR i := 0 TO al + bl + 1 DO  p[i] := 0  END;	(* clear acc *)
		FOR i := 0 TO bl - 1 DO
			mulc := 0;  addc := FALSE;  pl := i;
			FOR j := 0 TO al - 1 DO
				tmp := p[pl];
				MulAdd( mulc, prod, a[j], b[i], mulc );
				sum := prod + tmp;
				IF addc THEN  INC( sum );  addc := LessOrEqual( Invert( prod ), tmp )
				ELSE  addc := LessThan( sum, tmp )
				END;
				p[pl] := sum;  INC( pl );
			END;
			IF addc OR (mulc # 0) THEN
				IF addc THEN  INC( mulc )  END;
				p[pl] := mulc;  INC( pl )
			END;
		END;
		c := p;  cl := pl;  fixlen( c, cl );
	END mul;

	PROCEDURE muls( a: digits;  b: LONGINT; c: digits;  al: LONGINT;  VAR cl: LONGINT );  (* c := a * b *)
	VAR carry: LONGINT;  i: LONGINT;
	BEGIN
		carry := 0;  cl := al;
		FOR i := 0 TO al - 1 DO
			MulAdd( carry, c[i], a[i], b, carry );
		END;
		IF carry # 0 THEN  c[cl] := carry;  INC( cl )  END
	END muls;

	PROCEDURE Mul*( a, b: BigNumber ): BigNumber;   (**  a * b  *)
	VAR pd: digits;  pl: LONGINT;  c: BigNumber;
	BEGIN
		ASSERT( (a # NIL) & (b # NIL) );
		IF (a.len = 0) OR (b.len = 0) THEN  AssignInt( c, 0 );  RETURN c  END;
		NEW( c, 32 );
		IF a.len >= b.len THEN
			mul( a.d, b.d, pd, a.len, b.len, pl )
		ELSE
			mul( b.d, a.d, pd, b.len, a.len, pl )
		END;
		c.d := pd;  c.len := pl;  c.neg := a.neg # b.neg;
		RETURN c
	END Mul;

	PROCEDURE div64( CONST a: dig2;  VAR b: LONGINT ): LONGINT;   (* a div b *)
	VAR bit: LONGINT;  q, r: LONGINT;  overflow: BOOLEAN;
	BEGIN
		IF a[1] = 0 THEN
			IF (a[0] >= 0) & (b >= 0 ) THEN  RETURN a[0] DIV b
			ELSIF LessThan( a[0], b ) THEN  RETURN 0
			ELSIF a[0] = b THEN  RETURN 1
			END;
			bit := 31
		ELSIF a[1] = b THEN  RETURN -1
		ELSE bit := 63
		END;
		q := 0;  r := 0;
		WHILE (bit >= 0) & ~(bit MOD 32 IN S.VAL( SET, a[bit DIV 32]) ) DO  DEC( bit )  END;
		WHILE bit >= 0 DO
			overflow := r < 0;  r := ASH( r, 1 );
			IF bit MOD 32 IN S.VAL( SET, a[bit DIV 32] ) THEN  INC( r )  END;
			IF overflow OR LessOrEqual( b, r ) THEN  r := r - b;
				IF bit < 32 THEN  INCL( S.VAL( SET, q ), bit )  ELSE  q := -1  END;
			END;
			DEC( bit )
		END;
		RETURN q
	END div64;

	PROCEDURE div96( CONST a: dig3;  CONST b: dig2 ): LONGINT;   (* a div b *)
	VAR bit: LONGINT;  r: dig2;  q: LONGINT;  overflow, borrow: BOOLEAN;

		PROCEDURE ge( CONST a, b: dig2 ): BOOLEAN;
		BEGIN
			IF a[1] = b[1] THEN  RETURN ~LessThan( a[0], b[0] )
			ELSE  RETURN ~LessThan( a[1], b[1] )
			END
		END ge;

		PROCEDURE shift( VAR x: dig2 );
		BEGIN
			overflow := x[1] < 0;  x[1] := ASH( x[1], 1 );
			IF x[0] < 0 THEN  INC( x[1] )  END;
			x[0] := ASH( x[0], 1 );
		END shift;

	BEGIN
		IF a[2] = 0 THEN
			IF LessThan( a[1], b[1] ) THEN  RETURN 0  END;
			bit := 63
		ELSE  bit := 95
		END;
		q := 0;  r[0] := 0;  r[1] := 0;
		WHILE (bit >= 0) & ~(bit MOD 32 IN S.VAL( SET, a[bit DIV 32]) ) DO  DEC( bit )  END;
		WHILE bit >= 0 DO
			shift( r );	(* r := r*2 *)
			IF bit MOD 32 IN S.VAL( SET, a[bit DIV 32] ) THEN  INC( r[0] )  END;
			IF overflow OR ge( r, b ) THEN
				borrow := LessOrEqual( r[0], b[0] );  r[0] := r[0] - b[0];  r[1] := r[1] - b[1];
				IF borrow  THEN  DEC( r[1] )  END;
				IF bit < 32 THEN  INCL( S.VAL( SET, q ), bit )  ELSE  q := -1  END;
			END;
			DEC( bit )
		END;
		RETURN q
	END div96;

	PROCEDURE Div2*( a, b: BigNumber;  VAR q, r: BigNumber );   (** q := a div b;  r := a mod b *)
	VAR x: LONGINT;  td, sd, bd, qd: digits;  i, tail, bl, tl, sl, ql, qi: LONGINT;
		t3: dig3;  t2, d0: dig2;
		aq, ar: ADDRESS;
	BEGIN
		aq := ADDRESSOF( q );   ar := ADDRESSOF( r );
		ASSERT( (a # NIL) & (b # NIL) & ~b.IsZero( ) & ~b.neg & (aq # ar) );
		NEW( q, a.len*32 );  qd := q.d;

		x := ucmp( a, b );
		IF x < 0 THEN  AssignInt( q, 0 );  Copy( a, r )
		ELSIF x = 0 THEN  AssignInt( q, 1 );  AssignInt( r, 0 )
		ELSE
			td := GetBuffer();
			sd := GetBuffer();
			bd := b.d;  bl := b.len;  d0[1] := bd[bl - 1];
			IF bl > 1 THEN  d0[0] := bd[bl - 2]  ELSE  d0[0] := 0  END;
			FOR i := 1 TO bl DO  td[bl - i] := a.d[a.len - i]  END;
			tl := bl;  tail := a.len - bl;  ql := tail + 1;  qi := ql;
			LOOP
				IF tl < bl THEN  x := 0;
				ELSE i := tl  - 1;
					IF d0[0] = 0 THEN
						IF tl > bl THEN  t2[1] := td[i];  DEC( i )  ELSE  t2[1] := 0  END;
						t2[0] := td[i];
						x := div64( t2, d0[1] );
					ELSE
						IF tl > bl THEN  t3[2] := td[i];  DEC( i )  ELSE  t3[2] := 0  END;
						t3[1] := td[i];
						IF i > 0 THEN  t3[0] := td[i - 1]  ELSE  t3[0] := 0   END;
						x := div96( t3, d0 );
					END
				END;
				IF x # 0 THEN  muls( bd, x, sd, bl, sl );
					WHILE (sl > tl) OR ((sl = tl) & (cmpd( sd, td, sl ) > 0)) DO
						sub( sd, bd, sd, sl, bl, sl );  DEC( x );
					END;
					sub( td, sd, td, tl, sl, tl );
				END;
				IF (qi = ql) & (x = 0) THEN  DEC( ql );  DEC( qi )  ELSE  DEC( qi );  qd[qi] := x  END;
				IF tail = 0 THEN  EXIT  END;
				DEC( tail );
				FOR i := tl TO 1 BY -1 DO  td[i] := td[i - 1]  END;
				td[0] := a.d[tail];  INC( tl );
			END;
			q.len := ql;
			NEW( r, tl*32 );  copy( td, r.d, tl );  r.len := tl;
			RecycleBuffer( td );
			RecycleBuffer( sd )
		END;
		IF q.len = 0 THEN  q.neg := FALSE  ELSE  q.neg := a.neg  END;
		IF (r.len # 0) & a.neg THEN  q.Dec;  r := Sub( b, r )  END;
	END Div2;

	PROCEDURE ModWord*( VAR a: BigNumber;  b: LONGINT ): LONGINT;   (**  a mod b *)
	VAR x: LONGINT;  td, sd, bd: digits;  tail, tl, sl, bl: LONGINT;  t2: dig2;
	BEGIN
		ASSERT( a # NIL );
		td := GetBuffer();
		sd := GetBuffer();
		bd := GetBuffer();
		bd[0] := b;  bl := 1;  td[0] := a.d[a.len - 1];  tl := 1;  tail := a.len - 1;
		LOOP
			IF tl > 1 THEN  t2[1] := td[1]  ELSE  t2[1] := 0  END;
			t2[0] := td[0];
			x := div64( t2, b );
			IF x # 0 THEN  muls( bd, x, sd, bl, sl );
				WHILE (sl > tl) OR ((sl = tl) & (cmpd( sd, td, sl ) > 0)) DO
					sub( sd, bd, sd, sl, bl, sl );  DEC( x );
				END;
				sub( td, sd, td, tl, sl, tl );
			END;
			IF tail <= 0 THEN  EXIT  END;
			DEC( tail );
			IF td[0] = 0 THEN  tl := 1  ELSE td[1] := td[0];  tl := 2  END;
			td[0] := a.d[tail];
		END;
		x := td[0];
		RecycleBuffer( td );
		RecycleBuffer( sd );
		RecycleBuffer( bd );
		RETURN x
	END ModWord;

	PROCEDURE Div*( a, b: BigNumber ): BigNumber; 	(**   a DIV b  *)
	VAR dummy, q: BigNumber;
	BEGIN
		Div2( a, b, q, dummy );
		RETURN q
	END Div;

	PROCEDURE Mod*( a, b: BigNumber ): BigNumber; 	(**   a MOD b  *)
	VAR dummy, r: BigNumber;
	BEGIN
		Div2( a, b, dummy, r );
		RETURN r
	END Mod;


	PROCEDURE Exp*( a, b: BigNumber ): BigNumber;   (**  a ^ b  *)
	VAR v: digits; i: LONGINT; vl: LONGINT;  e: BigNumber;
	BEGIN
		NEW( e, 8192 );
		NEW( v, 256 );
		copy( a.d, v, a.len );  vl := a.len;
		IF ODD( b.d[0] ) THEN  copy( a.d, e.d, a.len );  e.len := a.len  ELSE  e.len := 1; e.d[0] := 1  END;
		FOR i := 1 TO b.BitSize( ) - 1 DO
			mul( v, v, v, vl, vl, vl );
			IF b.BitSet( i ) THEN   mul( v, e.d, e.d, vl, e.len, e.len )  END;
		END;
		fixlen( e.d, e.len );
		RETURN e
	END Exp;

	PROCEDURE ModMul*( a, b, m: BigNumber ): BigNumber;  (**  (a*b) mod m  *)
	VAR p, r: BigNumber;
	BEGIN
		p := Mul( a, b );  r := Mod( p, m );
		RETURN r
	END ModMul;

	PROCEDURE wbits( exp: BigNumber ): LONGINT;
	VAR b, w: LONGINT;
	BEGIN
		(* window bits for exponent size,  for sliding window ModExp functions *)
		b := exp.BitSize( );
		IF b <= 23 THEN  w := 1
		ELSIF b <= 79 THEN  w := 3
		ELSIF b <= 239 THEN  w := 4
		ELSIF b <= 671 THEN  w := 5
		ELSE  w := 6
		END;
		RETURN w
	END wbits;

	PROCEDURE ModExp*( a, b, m: BigNumber ): BigNumber;	(**  a ^ b mod m *)
	VAR
		a0: ARRAY 32 OF BigNumber;  res, d: BigNumber;
		wsize, v, wstart, e, i, j: LONGINT;
		mg: Montgomery;
	BEGIN
		ASSERT( (a # NIL) & (b # NIL) & (m # NIL) );
		IF b.IsZero( ) THEN
			IF a.IsZero( ) THEN HALT( 100 ) END;
			AssignInt( res, 1 );  RETURN  res
		END;
		IF m.IsZero( ) THEN  HALT( 101 )  END;
		IF m.neg THEN  HALT( 102 )  END;

		NEW( mg, m );
		a0[0] := Mod( a, m );  mg.Convert( a0[0] );

		wsize := wbits( b );
		IF wsize > 1 THEN  (* precompute window multipliers *)
			d := mg.Mult( a0[0], a0[0] );  j := ASH( 1, wsize - 1 );
			FOR i := 1 TO j - 1 DO  a0[i] := mg.Mult( a0[i - 1], d )  END;
		END;

		Copy( a0[0], res );  wstart := b.BitSize( ) - 2;
		WHILE wstart >= 0 DO  res := mg.Mult( res, res );
			IF b.BitSet( wstart ) THEN
				v := 1;  e := 0;  i := 1;
				WHILE (i < wsize) & (wstart - i >= 0) DO
					IF b.BitSet( wstart - i ) THEN  v := ASH( v, i - e ) + 1;  e := i  END;
					INC( i )
				END;
				FOR i := 1 TO e DO  res := mg.Mult( res, res )  END;
				res := mg.Mult( res, a0[v DIV 2] );	(*  v will be an odd number < 2^wsize *)
				DEC( wstart, e + 1 );
			ELSE DEC( wstart )
			END
		END;
		mg.Reduce( res );
		RETURN res
	END ModExp;



	PROCEDURE GCD*( a, b: BigNumber ): BigNumber;		(**  gcd( a, b ) *)
	VAR x, y, r: BigNumber;
	BEGIN
		ASSERT( ~a.neg & ~b.neg );
		Copy( a, x );  Copy( b, y );
		LOOP
			IF Cmp( x, y ) > 0 THEN  x := Mod( x, y );
				IF x.IsZero( ) THEN  Copy( y, r );  EXIT  END
			ELSE  y := Mod( y, x ) ;
				IF y.IsZero( ) THEN  Copy( x, r );  EXIT  END
			END;
		END;
		RETURN r
	END GCD;

	PROCEDURE ModInverse*( a, m: BigNumber ): BigNumber;	(** Return x so that (x * a) mod m = 1 *)
	VAR
		q, t, x: BigNumber;  g, v: ARRAY 3 OF BigNumber;  p, i, s, tmp, n: LONGINT;
	BEGIN
		FOR i := 0 TO 2 DO  AssignInt( g[i], 0 ); AssignInt( v[i], 0 ) END;
		Copy( a, g[0] );  Copy( m, g[1] );  AssignInt( v[0], 1 );  AssignInt( v[1], 0 );
		p := 0;  i := 1;  s := 2;  n := 0;
		LOOP
			Div2( g[p], g[i], q, g[s] );  t := Mul( q, v[i] );  v[s] := Add( v[p], t );  INC( n );
			IF g[s].IsZero( ) THEN  EXIT  END;
			tmp := p;  p := i;  i := s;  s := tmp;
		END;
		IF (g[i].len = 1) & (g[i].d[0] = 1) THEN
			IF ODD( n ) THEN  v[i] := Sub( m, v[i] )  END;
			x := Mod( v[i], m )
		ELSE  AssignInt( x, 0 )
		END;
		RETURN x
	END ModInverse;



	(*--------------------------- Text I/O ---------------------------------*)

	PROCEDURE TextWrite*( w: Streams.Writer;  b: BigNumber );
	VAR i: LONGINT;
	BEGIN
		IF b.neg THEN  w.String( "-" ) END;
		IF b.len = 0 THEN  w.String( " 00000000" )
		ELSE i := b.len;
			WHILE i > 0 DO
				DEC( i );  w.Hex( b.d[i], -8 );
				IF i > 0 THEN
					IF i MOD 6 = 0 THEN  w.Ln
					ELSE  w.String( "  " )
					END
				END
			END
		END;
		w.Char( '.' );
	END TextWrite;

	(** writes a hexadecimal representation of b to the standard output *)
	PROCEDURE Print*( b: BigNumber );
	VAR i: LONGINT;
	BEGIN
		IF b.neg THEN Out.String( "-" ) END;
		IF b.len = 0 THEN  Out.String( " 00000000" )
		ELSE  i := b.len;
			WHILE i > 0 DO
				DEC( i );  Out.Hex( b.d[i], -8 );
				IF i > 0 THEN
					IF i MOD 6 = 0 THEN  Out.Ln
					ELSE  Out.String( "  " )
					END
				END
			END
		END;
		Out.Char( '.' );  Out.Ln
	END Print;


	PROCEDURE nibble( r: Streams.Reader ): CHAR;
	VAR c: CHAR;
	BEGIN
		REPEAT
			REPEAT r.Char( c ) UNTIL (c > ' ') OR (r.Available() = 0);
		UNTIL	(r.Available() = 0) OR 
				(c >= '0') & (c <= '9') OR 
				(c >= 'A') & (c <= 'F') OR 
				(c >= 'a') & (c <= 'f') OR (c = '.');
		RETURN c
	END nibble;

	PROCEDURE TextRead*( r: Streams.Reader;  VAR b: BigNumber );
	VAR buf: ARRAY 2048 OF CHAR; i: LONGINT; n: CHAR;
	BEGIN
		i := 0;  n := nibble( r );
		WHILE n # '.' DO buf[i] := n;  INC( i );  n := nibble( r ) END;
		AssignHex( b, buf, i );
	END TextRead;



	(*--------------------------- File I/O ---------------------------------*)

	PROCEDURE FileRead*( r: Streams.Reader;  VAR b: BigNumber );
	VAR i, j: LONGINT;
	BEGIN
		r.RawLInt( j );
		NEW( b, 32 * j );
		b.len := j;
		FOR i := 0 TO j - 1 DO  r.RawLInt( b.d[ i ] )  END
	END FileRead;

	PROCEDURE FileWrite*( w: Streams.Writer;  b: BigNumber );
	VAR i, j: LONGINT;
	BEGIN
		j := b.len;
		w.RawLInt( j );
		FOR i := 0 TO j - 1 DO  w.RawLInt( b.d[ i ] )  END
	END FileWrite;


	(* ------------ buffer pooling to make this module thread-save (F.N.) -----------------------*)

	PROCEDURE GetBuffer( ): digits;
	VAR d: digits;
	BEGIN {EXCLUSIVE}
		IF nextFreeBuffer > -1 THEN
			d := bufferPool[ nextFreeBuffer ];
			DEC( nextFreeBuffer )
		ELSE
			NEW( d, 256 )
		END;
		RETURN d
	END GetBuffer;

	PROCEDURE RecycleBuffer( d: digits );
	BEGIN {EXCLUSIVE}
		IF nextFreeBuffer < BufferPoolSize - 1 THEN
			INC( nextFreeBuffer );
			bufferPool[ nextFreeBuffer ] := d
		END
	END RecycleBuffer;

	PROCEDURE InitRandomgenerator;
	BEGIN
		NEW( randomgenerator );
		randomgenerator.InitSeed( Kernel.GetTicks() );
	END InitRandomgenerator;

BEGIN
	ASSERT( S.VAL( LONGINT, {0}) = 1 );		(* little endian SETs! *)
	FOR nextFreeBuffer := 0 TO BufferPoolSize - 1 DO
		NEW( bufferPool[nextFreeBuffer], 256 )
	END;
	nextFreeBuffer := BufferPoolSize-1;
	InitRandomgenerator();
END CryptoBigNumbers.




