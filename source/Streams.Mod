(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Streams;   (** AUTHOR "pjm/be"; PURPOSE "I/O buffering and formatted writing and reading"; *)

IMPORT SYSTEM;

CONST
	Ok* = 0;   (** zero result code means no error occurred *)
	EOF* = 4201;   (** error returned when Receive reads past end of file or stream *)

	EOT* = 1AX;   (** EOT character *)

	StringFull = 4202;
	FormatError* = 4203;   (** error returned when ReadInt fails *)

	DefaultWriterSize* = 4096;
	DefaultReaderSize* = 4096;

CONST
	CR = 0DX;  LF = 0AX;  TAB = 9X;  SP = 20X;

VAR
	H, L: INTEGER;
TYPE
	(** Any stream output procedure or method. *)
	Sender* = PROCEDURE {DELEGATE} ( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );

	(** Any stream input procedure or method. *)
	Receiver* = PROCEDURE {DELEGATE} ( VAR buf: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );

	Connection* = OBJECT

		PROCEDURE Send*( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		END Send;

		PROCEDURE Receive*( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		END Receive;

		PROCEDURE Close*;
		END Close;

	END Connection;

	(** A writer buffers output before it is sent to a Sender.  Must not be shared between processes. *)
TYPE
	Writer* = OBJECT
	VAR
		tail: LONGINT;
		buf: POINTER TO ARRAY OF CHAR;
		res*: LONGINT; (** result of last output operation. *)
		send: Sender;
		sent*: LONGINT;  (** count of sent bytes *)
		(* buf[0..tail-1] contains data to write. *)

		PROCEDURE & InitWriter*( send: Sender;  size: LONGINT );
		BEGIN
			ASSERT ( send # NIL );
			NEW( buf, size );  SELF.send := send;  Reset
		END InitWriter;

		PROCEDURE Reset*;
		BEGIN
			tail := 0;  res := Ok;  sent := 0
		END Reset;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN FALSE
		END CanSetPos;

		PROCEDURE SetPos*( pos: LONGINT );
		BEGIN
			HALT( 1234 )
		END SetPos;

		PROCEDURE Update*;
		BEGIN
			IF (res = Ok) THEN
				send( buf^, 0, tail, TRUE , res );
				IF res = Ok THEN INC( sent, tail );  tail := 0 END
			END
		END Update;

	(** Current write position. *)
		PROCEDURE Pos*( ): LONGINT;
		BEGIN
			RETURN sent + tail
		END Pos;

		(** -- Write raw binary data -- *)

	(** Write one byte. *)
		PROCEDURE Char*( x: CHAR );
		BEGIN
			IF (tail = LEN( buf )) & (res = Ok) THEN
				send( buf^, 0, tail, FALSE , res );
				IF res = Ok THEN INC( sent, tail );  tail := 0 END
			END;
			IF res = Ok THEN buf[tail] := x;  INC( tail ) END
		END Char;

	(** Write len bytes from x, starting at ofs. *)
		PROCEDURE Bytes*(CONST x: ARRAY OF CHAR;  ofs, len: LONGINT );
		VAR n: LONGINT;
		BEGIN
			ASSERT ( len >= 0 );
			LOOP
				n := LEN( buf ) - tail;   (* space available *)
				IF n = 0 THEN
					IF res = Ok THEN  (* send current buffer *)
						send( buf^, 0, tail, FALSE , res );
						IF res = Ok THEN INC( sent, tail );  tail := 0 ELSE EXIT END
					ELSE
						EXIT  (* should not be writing on an erroneous rider *)
					END;
					n := LEN( buf )
				END;
				IF n > len THEN n := len END;
				ASSERT ( tail + n <= LEN( buf ) );   (* index check *)
				SYSTEM.MOVE( ADDRESSOF( x[ofs] ), ADDRESSOF( buf[tail] ), n );  INC( tail, n );
				IF len = n THEN EXIT END;   (* done *)
				INC( ofs, n );  DEC( len, n )
			END
		END Bytes;

	(** Write a SHORTINT. *)
		PROCEDURE RawSInt*( x: SHORTINT );
		BEGIN
			Char( SYSTEM.VAL( CHAR, x ) )
		END RawSInt;

	(** Write an INTEGER. *)
		PROCEDURE RawInt*( x: INTEGER );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes2, x ), 0, 2 )
		END RawInt;

	(** Write a LONGINT. *)
		PROCEDURE RawLInt*( x: LONGINT );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4 )
		END RawLInt;

	(** Write a HUGEINT. *)
		PROCEDURE RawHInt*( x: HUGEINT );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8 )
		END RawHInt;

	(** Write a 64 bit value in network byte order (most significant byte first) *)
		PROCEDURE Net64*( x: HUGEINT );
		BEGIN
			Net32(LONGINT( x DIV 100000000H MOD 100000000H ));
			Net32(LONGINT( x MOD 100000000H ));
		END Net64;

	(** Write a 32 bit value in network byte order (most significant byte first) *)
		PROCEDURE Net32*( x: LONGINT );
		BEGIN
			Char( CHR( x DIV 1000000H MOD 100H ) );  Char( CHR( x DIV 10000H MOD 100H ) );  Char( CHR( x DIV 100H MOD 100H ) );
			Char( CHR( x MOD 100H ) )
		END Net32;

	(** Write a 16 bit value in network byte order (most significant byte first) *)
		PROCEDURE Net16*( x: LONGINT );
		BEGIN
			Char( CHR( x DIV 100H MOD 100H ) );  Char( CHR( x MOD 100H ) )
		END Net16;

	(** write unsigned byte *)
		PROCEDURE Net8*( x: LONGINT );
		BEGIN
			Char( CHR( x MOD 100H ) )
		END Net8;

	(** Write a SET. *)
		PROCEDURE RawSet*( x: SET );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4 )
		END RawSet;

	(** Write a BOOLEAN. *)
		PROCEDURE RawBool*( x: BOOLEAN );
		BEGIN
			IF x THEN Char( 1X ) ELSE Char( 0X ) END
		END RawBool;

	(** Write a REAL. *)
		PROCEDURE RawReal*( x: REAL );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4 )
		END RawReal;

	(** Write a LONGREAL. *)
		PROCEDURE RawLReal*( x: LONGREAL );
		BEGIN
			Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8 )
		END RawLReal;

	(** Write a 0X-terminated string, including the 0X terminator. *)
		PROCEDURE RawString*(CONST x: ARRAY OF CHAR );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE x[i] # 0X DO Char( x[i] );  INC( i ) END;
			Char( 0X )
		END RawString;

	(** Write a number in a compressed format. *)
		PROCEDURE RawNum*( x: LONGINT );
		BEGIN
			WHILE (x < -64) OR (x > 63) DO Char( CHR( x MOD 128 + 128 ) );  x := x DIV 128 END;
			Char( CHR( x MOD 128 ) )
		END RawNum;

		(** -- Write formatted data -- *)

	(** Write an ASCII end-of-line (CR/LF). *)
		PROCEDURE Ln*;
		BEGIN
			Char( CR );  Char( LF )
		END Ln;

	(** Write a 0X-terminated string, excluding the 0X terminator. *)
		PROCEDURE String*(CONST x: ARRAY OF CHAR );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE x[i] # 0X DO Char( x[i] );  INC( i ) END
		END String;

	(** Write an integer in decimal right-justified in a field of at least w characters. *)
		PROCEDURE Int*( x: HUGEINT; w: LONGINT );
		VAR i: SIZE; x0: HUGEINT;
			a: ARRAY 21 OF CHAR;
		BEGIN
			IF x < 0 THEN
				IF x = MIN( HUGEINT ) THEN
					DEC( w, 20 );
					WHILE w > 0 DO Char( " " );  DEC( w ) END;
					String( "-9223372036854775808" );  RETURN
				ELSE DEC( w );  x0 := -x
				END
			ELSE x0 := x
			END;
			i := 0;
			REPEAT a[i] := CHR( x0 MOD 10 + 30H );  x0 := x0 DIV 10;  INC( i ) UNTIL x0 = 0;
			WHILE w > i DO Char( " " );  DEC( w ) END;
			IF x < 0 THEN Char( "-" ) END;
			REPEAT DEC( i );  Char( a[i] ) UNTIL i = 0
		END Int;

	(** Write a SET in Oberon notation. *)
		PROCEDURE Set*( s: SET );   (* from P. Saladin *)
		VAR i, last: LONGINT;  dots: BOOLEAN;
		BEGIN
			Char( "{" );  last := MIN( LONGINT );  dots := FALSE;
			FOR i := MIN( SET ) TO MAX( SET ) DO
				IF i IN s THEN
					IF last = (i - 1) THEN
						IF dots THEN String( ".." );  dots := FALSE END;
						IF (i = MAX( SET )) OR ~((i + 1) IN s) THEN Int( i, 1 ) END
					ELSE
						IF last >= MIN( SET ) THEN String( ", " ) END;
						Int( i, 1 );  dots := TRUE
					END;
					last := i
				END
			END;
			Char( "}" )
		END Set;

		(**
			Write an integer in hexadecimal right-justified in a field of at least ABS(w) characters.
			If w < 0 THEN w least significant hex digits of x are written (potentially including leading zeros)
		*)
		PROCEDURE Hex*(x: HUGEINT; w: LONGINT);
		VAR filler: CHAR; i,maxw: LONGINT; a: ARRAY 20 OF CHAR; y: HUGEINT;
		BEGIN
			IF w < 0 THEN filler := '0'; w := -w; maxw := w ELSE filler := ' '; maxw := 16 END;
			i := 0;
			REPEAT
				y := x MOD 10H;
				IF y < 10 THEN a[i] := CHR(y+ORD('0')) ELSE a[i] := CHR(y-10+ORD('A')) END;
				x := x DIV 10H;
				INC(i);
			UNTIL (x=0) OR (i=maxw);
			WHILE w > i DO Char(filler);  DEC( w ) END;
			REPEAT DEC( i ); Char( a[i] ) UNTIL i = 0
		END Hex;

		(** Write "x" as a hexadecimal address. Do not use Hex because of arithmetic shift of the sign !*)
		PROCEDURE Address* (x: ADDRESS);
		BEGIN
			Hex(x,-2*SIZEOF(ADDRESS));
		END Address;

		PROCEDURE Pair( ch: CHAR;  x: LONGINT );
		BEGIN
			IF ch # 0X THEN Char( ch ) END;
			Char( CHR( ORD( "0" ) + x DIV 10 MOD 10 ) );  Char( CHR( ORD( "0" ) + x MOD 10 ) )
		END Pair;

	(** Write the date and time in ISO format (yyyy-mm-dd hh:mm:ss).  The t and d parameters are in Oberon time and date format.
			If all parameters are within range, the output string is exactly 19 characters wide.  The t or d parameter can be -1, in which
			case the time or date respectively are left out. *)
		PROCEDURE Date*( t, d: LONGINT );
		VAR ch: CHAR;
		BEGIN
			IF d # -1 THEN
				Int( 1900 + d DIV 512, 4 );   (* year *)
				Pair( "-", d DIV 32 MOD 16 );   (* month *)
				Pair( "-", d MOD 32 );   (* day *)
				ch := " " (* space between date and time *)
			ELSE
				ch := 0X (* no space before time *)
			END;
			IF t # -1 THEN
				Pair( ch, t DIV 4096 MOD 32 );   (* hour *)
				Pair( ":", t DIV 64 MOD 64 );   (* min *)
				Pair( ":", t MOD 64 ) (* sec *)
			END
		END Date;

	(** Write the date and time in RFC 822/1123 format without the optional day of the week (dd mmm yyyy hh:mm:ss SZZZZ) .
			The t and d parameters are in Oberon time and date format.  The tz parameter specifies the time zone offset in minutes
			(from -720 to 720 in steps of 30).  If all parameters are within range, the output string is exactly 26 characters wide.
			The t, d or tz parameter can be -1, in which case the time, date or timezone respectively are left out. *)
		PROCEDURE Date822*( t, d, tz: LONGINT );
		VAR i, m: LONGINT;  ch: CHAR;
		BEGIN
			IF d # -1 THEN
				Int( d MOD 32, 2 );   (* day *)
				m := (d DIV 32 MOD 16 - 1) * 4;   (* month *)
				FOR i := m TO m + 3 DO Char( months[i] ) END;
				Int( 1900 + d DIV 512, 5 );   (* year *)
				ch := " " (* space *)
			ELSE
				ch := 0X (* no space *)
			END;
			IF t # -1 THEN
				Pair( ch, t DIV 4096 MOD 32 );   (* hour *)
				Pair( ":", t DIV 64 MOD 64 );   (* min *)
				Pair( ":", t MOD 64 );   (* sec *)
				ch := " " (* space *)
			ELSE
				(* leave ch as before *)
			END;
			IF tz # -1 THEN
				IF ch # 0X THEN Char( ch ) END;
				IF tz >= 0 THEN Pair( "+", tz DIV 60 ) ELSE Pair( "-", (-tz) DIV 60 ) END;
				Pair( 0X, ABS( tz ) MOD 60 )
			END
		END Date822;


	(** Write LONGREAL x  using n character positions. *)
		PROCEDURE Float*( x: LONGREAL;  n: LONGINT );
		(* BM 1993.4.22. Do not simplify rounding! *)
		VAR e, h, l, i: LONGINT;  z: LONGREAL;
			d: ARRAY 16 OF CHAR;
		BEGIN
			e := ExpoL( x );
			IF e = 2047 THEN
				WHILE n > 9 DO Char( " " );  DEC( n ) END;
				NaNCodeL( x, h, l );
				IF (h # 0) OR (l # 0) THEN String( "      NaN" )
				ELSIF x < 0 THEN String( "     -INF" )
				ELSE String( "      INF" )
				END
			ELSE
				IF n <= 9 THEN n := 1 ELSE DEC( n, 8 ) END;
				REPEAT Char( " " );  DEC( n ) UNTIL n <= 15;   (* 0 <= n <= 15 fraction digits *)
				IF (e # 0) & (x < 0) THEN Char( "-" );  x := -x ELSE Char( " " ) END;
				IF e = 0 THEN
					h := 0;  l := 0 (* no denormals *)
				ELSE
					e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
					z := Ten( e + 1 );
					IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Ten( -e ) END;
					IF x >= 10 THEN x := x * Ten( -1 ) + 0.5D0 / Ten( n );  INC( e )
					ELSE
						x := x + 0.5D0 / Ten( n );
						IF x >= 10 THEN x := x * Ten( -1 );  INC( e ) END
					END;
					x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
				END;
				i := 15;
				WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
				WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
				Char( d[0] );  Char( "." );  i := 1;
				WHILE i <= n DO Char( d[i] );  INC( i ) END;
				IF e < 0 THEN String( "E-" );  e := -e ELSE String( "E+" ) END;
				Char( CHR( e DIV 100 + ORD( "0" ) ) );  e := e MOD 100;  Char( CHR( e DIV 10 + ORD( "0" ) ) );  Char( CHR( e MOD 10 + ORD( "0" ) ) )
			END
		END Float;

	(** Write LONGREAL x in a fixed point notation. n is the overall minimal length for the output field, f the number of fraction digits following the decimal point, D the fixed exponent (printed only when D # 0). *)
		PROCEDURE FloatFix*( x: LONGREAL;  n, f, D: LONGINT );
		(* BM 1993.4.22. Do not simplify rounding! / JG formatting adjusted *)
		VAR e, h, l, i: LONGINT;  r, z: LONGREAL;
			d: ARRAY 16 OF CHAR;
			s: CHAR;  dot: BOOLEAN;
		BEGIN
			e := ExpoL( x );
			IF (e = 2047) OR (ABS( D ) > 308) THEN
				WHILE n > 9 DO Char( " " );  DEC( n ) END;
				NaNCodeL( x, h, l );
				IF (h # 0) OR (l # 0) THEN String( "      NaN" )
				ELSIF x < 0 THEN String( "     -INF" )
				ELSE String( "      INF" )
				END
			ELSE
				IF D = 0 THEN IF (f=0) THEN dot := FALSE; DEC( n, 1 ) ELSE dot := TRUE; DEC(n,2);  END;  ELSE dot := TRUE; DEC( n, 7 ) END;
				IF n < 2 THEN n := 2 END;
				IF f < 0 THEN f := 0 END;
				IF n < f + 2 THEN n := f + 2 END;
				DEC( n, f );
				IF (e # 0) & (x < 0) THEN s := "-";  x := -x ELSE s := " " END;
				IF e = 0 THEN
					h := 0;  l := 0;  DEC( e, D - 1 ) (* no denormals *)
				ELSE
					e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
					z := Ten( e + 1 );
					IF x >= z THEN x := x / z;  INC( e ) ELSE x := x * Ten( -e ) END;
					DEC( e, D - 1 );  i := -(e + f);
					IF i <= 0 THEN r := 5 * Ten( i ) ELSE r := 0 END;
					IF x >= 10 THEN x := x * Ten( -1 ) + r;  INC( e )
					ELSE
						x := x + r;
						IF x >= 10 THEN x := x * Ten( -1 );  INC( e ) END
					END;
					x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
				END;
				i := 15;
				WHILE i > 7 DO d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i ) END;
				WHILE i >= 0 DO d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i ) END;
				IF n <= e THEN n := e + 1 END;
				IF e > 0 THEN
					WHILE n > e DO Char( " " );  DEC( n ) END;
					Char( s );  e := 0;
					WHILE n > 0 DO
						DEC( n );
						IF e < 16 THEN Char( d[e] );  INC( e ) ELSE Char( "0" ) END
					END;
					IF dot THEN
					Char( "." )
					END;
				ELSE
					WHILE n > 1 DO Char( " " );  DEC( n ) END;
					Char( s );  Char( "0" );  IF dot THEN Char( "." );  END;
					WHILE (0 < f) & (e < 0) DO Char( "0" );  DEC( f );  INC( e ) END
				END;
				WHILE f > 0 DO
					DEC( f );
					IF e < 16 THEN Char( d[e] );  INC( e ) ELSE Char( "0" ) END
				END;
				IF D # 0 THEN
					IF D < 0 THEN String( "E-" );  D := -D ELSE String( "E+" ) END;
					Char( CHR( D DIV 100 + ORD( "0" ) ) );  D := D MOD 100;  Char( CHR( D DIV 10 + ORD( "0" ) ) );  Char( CHR( D MOD 10 + ORD( "0" ) ) )
				END
			END
		END FloatFix;

	END Writer;

	(** A special writer that buffers output to be fetched by GetString or GetRawString. *)
	StringWriter* = OBJECT (Writer)

		PROCEDURE & InitStringWriter*( size: LONGINT );
		BEGIN
			InitWriter( Send, size )
		END InitStringWriter;

		PROCEDURE Send( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		BEGIN
			res := StringFull
		END Send;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN TRUE;
		END CanSetPos;

	(* Set the position for the writer *)
		PROCEDURE SetPos*( pos: LONGINT );
		BEGIN
			IF pos > LEN( buf ) THEN pos := LEN( buf ) END;
			tail := pos;  sent := 0;  res := Ok;
		END SetPos;

		PROCEDURE Update;
		(* nothing to do *)
		END Update;

	(** Return the contents of the string writer (0X-terminated). *)
		PROCEDURE Get*( VAR s: ARRAY OF CHAR );
		VAR i, m: LONGINT;
		BEGIN
			m := LEN( s ) - 1;  i := 0;
			WHILE (i # tail) & (i < m) DO s[i] := buf[i];  INC( i ) END;
			s[i] := 0X;  tail := 0;  res := Ok
		END Get;

	(** Return the contents of the string writer (not 0X-terminated).  The len parameters returns the string length. *)
		PROCEDURE GetRaw*( VAR s: ARRAY OF CHAR;  VAR len: LONGINT );
		VAR i, m: LONGINT;
		BEGIN
			m := LEN( s );  i := 0;
			WHILE (i # tail) & (i < m) DO s[i] := buf[i];  INC( i ) END;
			len := i;  tail := 0;  res := Ok
		END GetRaw;

	END StringWriter;

TYPE
	(** A reader buffers input received from a Receiver.  Must not be shared between processes. *)
	Reader* = OBJECT
	VAR
		head, tail: LONGINT;
		buf: POINTER TO ARRAY OF CHAR;
		res*: LONGINT;   (** result of last input operation. *)
		receive: Receiver;
		received*: LONGINT;   (** count of received bytes *)
		(* buf[buf.head..buf.tail-1] contains data to read. *)

		PROCEDURE & InitReader*( receive: Receiver;  size: LONGINT );
		BEGIN
			ASSERT ( receive # NIL );
			IF (buf = NIL) OR (LEN(buf) # size) THEN
				NEW( buf, size );
			END;
			SELF.receive := receive;  Reset
		END InitReader;

	(** reset the reader by dropping the bytes in the buffer, resetting the result code and setting received to 0.
			This is used by seekable extensions of the reader *)
		PROCEDURE Reset*;
		BEGIN
			head := 0;  tail := 0;  res := Ok;  received := 0
		END Reset;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN FALSE
		END CanSetPos;

		PROCEDURE SetPos*( pos: LONGINT );
		BEGIN
			HALT( 1234 )
		END SetPos;

	(** Return bytes currently available in input buffer. *)
		PROCEDURE Available*( ): LONGINT;
		VAR n: LONGINT;
		BEGIN
			IF (res = Ok) THEN
				IF (head = tail) THEN head := 0;  receive( buf^, 0, LEN( buf ), 0, tail, res );  INC( received, tail );
				ELSIF (tail # LEN( buf )) THEN
					receive( buf^, tail, LEN( buf ) - tail, 0, n, res );   (* poll *)
					INC( tail, n );  INC( received, n )
				END;
				IF res = EOF THEN res := Ok END  (* ignore EOF here *)
			END;
			RETURN tail - head
		END Available;

	(** Current read position. *)
		PROCEDURE Pos*( ): LONGINT;
		BEGIN
			RETURN received - (tail - head)
		END Pos;

		(** -- Read raw binary data -- *)

	(** Read one byte. x=0X if no success (e.g. file ended) *)
		PROCEDURE Char*( VAR x: CHAR );
		BEGIN
			IF (head = tail) & (res = Ok) THEN head := 0;  receive( buf^, 0, LEN( buf ), 1, tail, res );  INC( received, tail ) END;
			IF res = Ok THEN x := buf[head];  INC( head ) ELSE x := 0X END
		END Char;

	(** Like Read, but return result. Return 0X if no success (e.g. file ended) *)
		PROCEDURE Get*( ): CHAR;
		BEGIN
			IF (head = tail) & (res = Ok) THEN head := 0;  receive( buf^, 0, LEN( buf ), 1, tail, res );  INC( received, tail ) END;
			IF res = Ok THEN INC( head );  RETURN buf[head - 1] ELSE RETURN 0X END
		END Get;

	(** Like Get, but leave the byte in the input buffer. *)
		PROCEDURE Peek*( ): CHAR;
		BEGIN
			IF (head = tail) & (res = Ok) THEN
				head := 0;  receive( buf^, 0, LEN( buf ), 1, tail, res );  INC( received, tail );
				IF res = EOF THEN  (* ignore EOF here *)
					res := Ok;  tail := 0; RETURN 0X (* Peek returns 0X at eof *)
				END
			END;
			IF res = Ok THEN RETURN buf[head] ELSE RETURN 0X END
		END Peek;

	(** Read size bytes into x, starting at ofs.  The len parameter returns the number of bytes that were actually read. *)
		PROCEDURE Bytes*( VAR x: ARRAY OF CHAR;  ofs, size: LONGINT;  VAR len: LONGINT );
		VAR n: LONGINT;
		BEGIN
			ASSERT ( size >= 0 );
			len := 0;
			LOOP
				n := tail - head;   (* bytes available *)
				IF n = 0 THEN  (* no data available *)
					head := 0;
					IF res = Ok THEN  (* fill buffer *)
						receive( buf^, 0, LEN( buf ), 1, tail, res );  INC( received, tail )
					END;
					IF res # Ok THEN  (* should not be reading from erroneous rider *)
						WHILE size # 0 DO x[ofs] := 0X;  INC( ofs );  DEC( size ) END;   (* clear rest of buffer *)
						IF (res = EOF) & (len # 0) THEN res := Ok END;   (* ignore EOF if some data being returned *)
						EXIT
					END;
					n := tail
				END;
				IF n > size THEN n := size END;
				ASSERT ( ofs + n <= LEN( x ) );   (* index check *)
				SYSTEM.MOVE( ADDRESSOF( buf[head] ), ADDRESSOF( x[ofs] ), n );  INC( head, n );  INC( len, n );
				IF size = n THEN EXIT END;   (* done *)
				INC( ofs, n );  DEC( size, n )
			END
		END Bytes;

	(** Skip n bytes on the reader. *)
		PROCEDURE SkipBytes*( n: LONGINT );
		VAR ch: CHAR;
		BEGIN
			WHILE n > 0 DO ch := Get();  DEC( n ) END
		END SkipBytes;

	(** Read a SHORTINT. *)
		PROCEDURE RawSInt*( VAR x: SHORTINT );
		BEGIN
			x := SYSTEM.VAL( SHORTINT, Get() )
		END RawSInt;

	(** Read an INTEGER. *)
		PROCEDURE RawInt*( VAR x: INTEGER );
		VAR x0, x1: CHAR;
		BEGIN
			x0 := Get();  x1 := Get();   (* defined order *)
			x := ORD( x1 ) * 100H + ORD( x0 )
		END RawInt;

	(** Read a LONGINT. *)
		PROCEDURE RawLInt*( VAR x: LONGINT );
		VAR ignore: LONGINT;
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
		END RawLInt;

	(** Read a HUGEINT. *)
		PROCEDURE RawHInt*( VAR x: HUGEINT );
		VAR ignore: LONGINT;
		BEGIN
			Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8, ignore )
		END RawHInt;

		(** Read a 64 bit value in network byte order (most significant byte first) *)
		PROCEDURE Net64*( ): HUGEINT;
		BEGIN
			RETURN Net32() * 100000000H + Net32()
		END Net64;

	(** Read a 32 bit value in network byte order (most significant byte first) *)
		PROCEDURE Net32*( ): LONGINT;
		BEGIN
			RETURN LONG( ORD( Get() ) ) * 1000000H + LONG( ORD( Get() ) ) * 10000H + LONG( ORD( Get() ) ) * 100H + LONG( ORD( Get() ) )
		END Net32;

	(** Read an unsigned 16bit value in network byte order (most significant byte first) *)
		PROCEDURE Net16*( ): LONGINT;
		BEGIN
			RETURN LONG( ORD( Get() ) ) * 100H + LONG( ORD( Get() ) )
		END Net16;

	(** Read an unsigned byte *)
		PROCEDURE Net8*( ): LONGINT;
		BEGIN
			RETURN LONG( ORD( Get() ) )
		END Net8;

	(** Read a SET. *)
		PROCEDURE RawSet*( VAR x: SET );
		VAR ignore: LONGINT;
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
		END RawSet;

	(** Read a BOOLEAN. *)
		PROCEDURE RawBool*( VAR x: BOOLEAN );
		BEGIN
			x := (Get() # 0X)
		END RawBool;

	(** Read a REAL. *)
		PROCEDURE RawReal*( VAR x: REAL );
		VAR ignore: LONGINT;
		BEGIN
			Bytes( SYSTEM.VAL( Bytes4, x ), 0, 4, ignore )
		END RawReal;

	(** Read a LONGREAL. *)
		PROCEDURE RawLReal*( VAR x: LONGREAL );
		VAR ignore: LONGINT;
		BEGIN
			Bytes( SYSTEM.VAL( Bytes8, x ), 0, 8, ignore )
		END RawLReal;

	(** Read a 0X-terminated string.  If the input string is larger than x, read the full string and assign the truncated 0X-terminated value to x. *)
		PROCEDURE RawString*( VAR x: ARRAY OF CHAR );
		VAR i, m: LONGINT;  ch: CHAR;
		BEGIN
			i := 0;  m := LEN( x ) - 1;
			LOOP
				ch := Get();   (* also returns 0X on error *)
				IF ch = 0X THEN EXIT END;
				IF i < m THEN x[i] := ch;  INC( i ) END
			END;
			x[i] := 0X
		END RawString;

	(** Read a number in a compressed format. *)
		PROCEDURE RawNum*( VAR x: LONGINT );
		VAR ch: CHAR;  n, y: LONGINT;
		BEGIN
			n := 0;  y := 0;  ch := Get();
			WHILE ch >= 80X DO INC( y, LSH( LONG( ORD( ch ) ) - 128, n ) );  INC( n, 7 );  ch := Get() END;
			x := ASH( LSH( LONG( ORD( ch ) ), 25 ), n - 25 ) + y
		END RawNum;

		(** -- Read formatted data (uses Peek for one character lookahead) -- *)

	 (** Read an integer value in decimal or hexadecimal.  If hex = TRUE, recognize the "H" postfix for hexadecimal numbers. *)

		PROCEDURE Int*( VAR x: LONGINT;  hex: BOOLEAN );
		VAR vd, vh, sgn, d: LONGINT;  ch: CHAR;  ok: BOOLEAN;
		BEGIN
			vd := 0;  vh := 0;  sgn := 1;  ok := FALSE;
			IF Peek() = "-" THEN sgn := -1;  ch := Get() END;
			LOOP
				ch := Peek();
				IF (ch >= "0") & (ch <= "9") THEN d := ORD( ch ) - ORD( "0" )
				ELSIF hex & (CAP( ch ) >= "A") & (CAP( ch ) <= "F") THEN d := ORD( CAP( ch ) ) - ORD( "A" ) + 10
				ELSE EXIT
				END;
				vd := 10 * vd + d;  vh := 16 * vh + d;   (* ignore overflow *)
				ch := Get();  ok := TRUE
			END;
			IF hex & (CAP( ch ) = "H") THEN  (* optional "H" present *)
				vd := vh;   (* use the hex value *)
				ch := Get()
			END;
			x := sgn * vd;
			IF (res = 0) & ~ok THEN res := FormatError END
		END Int;

	(** Return TRUE iff at the end of a line (or file). *)
		PROCEDURE EOLN*( ): BOOLEAN;
		VAR ch: CHAR;
		BEGIN
			ch := Peek();  RETURN (ch = CR) OR (ch = LF) OR (res # Ok)
		END EOLN;

	(** Read all characters until the end of the line (inclusive).  If the input string is larger than x, read the full string and assign
			the truncated 0X-terminated value to x. *)
		PROCEDURE Ln*( VAR x: ARRAY OF CHAR );
		VAR i, m: LONGINT;  ch: CHAR;
		BEGIN
			i := 0;  m := LEN( x ) - 1;
			LOOP
				ch := Peek();
				IF (ch = CR) OR (ch = LF) OR (res # Ok) THEN EXIT END;
				IF i < m THEN x[i] := ch;  INC( i ) END;
				ch := Get()
			END;
			x[i] := 0X;
			IF ch = CR THEN ch := Get() END;
			IF Peek() = LF THEN ch := Get() END
		END Ln;

	(** Read all characters until the end of the line (inclusive) or an <EOT> character.
			If the input string is larger than x, read the full string and assign the truncated 0X-terminated
			value to x. *)
		PROCEDURE LnEOT*( VAR x: ARRAY OF CHAR );
		VAR i, m: LONGINT;  ch: CHAR;
		BEGIN
			i := 0;  m := LEN( x ) - 1;
			LOOP
				ch := Peek();
				IF (ch = CR) OR (ch = LF) OR (ch = EOT) OR (res # Ok) THEN EXIT END;
				IF i < m THEN x[i] := ch;  INC( i ) END;
				ch := Get()
			END;
			x[i] := 0X;
			IF ch = CR THEN ch := Get() END;
			IF Peek() = LF THEN ch := Get() END;
			IF ch = EOT THEN ch := Get() END
		END LnEOT;

	(** Skip over all characters until the end of the line (inclusive). *)
		PROCEDURE SkipLn*;
		VAR ch: CHAR;
		BEGIN
			LOOP
				ch := Peek();
				IF (ch = CR) OR (ch = LF) OR (res # Ok) THEN EXIT END;
				ch := Get()
			END;
			IF ch = CR THEN ch := Get() END;
			IF Peek() = LF THEN ch := Get() END
		END SkipLn;

	(** Skip over space and TAB characters. *)
		PROCEDURE SkipSpaces*;
		VAR ch: CHAR;
		BEGIN
			LOOP
				ch := Peek();
				IF (ch # TAB) & (ch # SP) THEN EXIT END;
				ch := Get()
			END
		END SkipSpaces;

	(** Skip over space, TAB and EOLN characters. *)
		PROCEDURE SkipWhitespace*;
		VAR ch: CHAR;
		BEGIN
			LOOP
				ch := Peek();
				IF (ch # SP) & (ch # CR) & (ch # LF) & (ch # TAB) THEN EXIT END;
				ch := Get()
			END
		END SkipWhitespace;

	(** Read a token, consisting of any string of characters terminated by space, TAB or EOLN. *)
		PROCEDURE Token*( VAR token: ARRAY OF CHAR );
		VAR j, max: LONGINT;  ch: CHAR;
		BEGIN
			j := 0;  max := LEN( token ) - 1;
			LOOP
				ch := Peek();
				IF (ch = SP) OR (ch = CR) OR (ch = LF) OR (ch = TAB) OR (res # Ok) THEN EXIT END;
				IF j < max THEN token[j] := ch;  INC( j ) END;
				ch := Get()
			END;
			token[j] := 0X
		END Token;

	(** Read an optionally "" or '' enquoted string.  Will not read past the end of a line. *)
		PROCEDURE String*( VAR string: ARRAY OF CHAR );
		VAR c, delimiter: CHAR;  i, len: LONGINT;
		BEGIN
			c := Peek();
			IF (c # "'") & (c # '"') THEN Token( string )
			ELSE
				delimiter := Get();  c := Peek();  i := 0;  len := LEN( string ) - 1;
				WHILE (i < len) & (c # delimiter) & (c # CR) & (c # LF) & (res = Ok) DO string[i] := Get();  INC( i );  c := Peek() END;
				IF (c = delimiter) THEN c := Get() END;
				string[i] := 0X
			END
		END String;

		(** First skip whitespace, then read string *)
		PROCEDURE GetString*(VAR string : ARRAY OF CHAR): BOOLEAN;
		VAR c: CHAR;
		BEGIN
			SkipWhitespace;
			c := Peek();
			String(string);
			RETURN (string[0] # 0X) OR (c = "'") OR (c = '"');
		END GetString;

		(** First skip whitespace, then read integer *)
		PROCEDURE GetInteger*(VAR integer : LONGINT; isHexadecimal : BOOLEAN): BOOLEAN;
		BEGIN
			SkipWhitespace;
			Int(integer, isHexadecimal);
			RETURN res = Ok;
		END GetInteger;

		(** First skip whitespace, then read 1 byte character *)
		PROCEDURE GetChar*(VAR ch : CHAR): BOOLEAN;
		BEGIN
			SkipWhitespace;
			Char(ch);
			RETURN ch # 0X;
		END GetChar;

	END Reader;

TYPE
	(** A special reader that buffers input set by SetString or SetRawString. *)
	StringReader* = OBJECT (Reader)

		PROCEDURE & InitStringReader*( size: LONGINT );
		BEGIN
			InitReader( Receive, size )
		END InitStringReader;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN
			RETURN TRUE
		END CanSetPos;

	(** Set the reader position *)
		PROCEDURE SetPos*( pos: LONGINT );
		BEGIN
			IF pos > LEN( buf ) THEN pos := LEN( buf ) END;
			head := pos;  tail := LEN( buf );  received := LEN( buf );  res := Ok;
		END SetPos;

		PROCEDURE Receive( VAR buf: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		BEGIN
			IF min = 0 THEN res := Ok ELSE res := EOF END;
			len := 0;
		END Receive;

	(** Set the contents of the string buffer.  The s parameter is a 0X-terminated string. *)
		PROCEDURE Set*(CONST  s: ARRAY OF CHAR );
		VAR len: LONGINT;
		BEGIN
			len := 0;
			WHILE s[len] # 0X DO INC( len ) END;
			IF len > LEN( buf ) THEN len := LEN( buf ) END;
			head := 0;  tail := len;  received := len;  res := Ok;
			IF len > 0 THEN
				SYSTEM.MOVE( ADDRESSOF( s[0] ), ADDRESSOF( buf[0] ), len )
			END;
		END Set;

	(** Set the contents of the string buffer.  The len parameter specifies the size of the buffer s. *)
		PROCEDURE SetRaw*(CONST s: ARRAY OF CHAR;  ofs, len: LONGINT );
		BEGIN
			IF len > LEN( buf ) THEN len := LEN( buf ) END;
			head := 0;  tail := len;  received := len;  res := Ok;
			ASSERT ( (len >= 0) & (ofs + len <= LEN( s )) );   (* index check *)
			IF len > 0 THEN
				SYSTEM.MOVE( ADDRESSOF( s[ofs] ), ADDRESSOF( buf[0] ), len )
			END;
		END SetRaw;

	END StringReader;

	Bytes2 = ARRAY 2 OF CHAR;
	Bytes4 = ARRAY 4 OF CHAR;
	Bytes8 = ARRAY 8 OF CHAR;

VAR
	months: ARRAY 12 * 4 + 1 OF CHAR;


	(** Open a writer to the specified stream sender.  Update must be called after writing to ensure the buffer is written to the stream. *)
	PROCEDURE OpenWriter*( VAR b: Writer;  send: Sender );
	BEGIN
		NEW( b, send, DefaultWriterSize )
	END OpenWriter;

(** Open a reader from the specified stream receiver. *)
	PROCEDURE OpenReader*( VAR b: Reader;  receive: Receiver );
	BEGIN
		NEW( b, receive, DefaultReaderSize )
	END OpenReader;

(** Copy the contents of a reader to a writer *)
	PROCEDURE Copy* (r: Reader; w: Writer);
	VAR char: CHAR;
	BEGIN
		WHILE r.res = Ok DO
			r.Char (char);
			IF r.res = Ok THEN w.Char (char) END
		END;
	END Copy;

	(** from module Reals.Mod *)


(*** the following procedures stem from Reals.Mod and are needed for Writer.Float and Writer.FloatFix *)

(** Returns the NaN code (0 <= h < 1048576, MIN(LONGINT) <= l <= MAX(LONGINT)) or (-1,-1) if not NaN/Infinite. *)
	PROCEDURE NaNCodeL( x: LONGREAL;  VAR h, l: LONGINT );
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, h );  SYSTEM.GET( ADDRESSOF( x ) + L, l );
		IF ASH( h, -20 ) MOD 2048 = 2047 THEN  (* Infinite or NaN *)
			h := h MOD 100000H (* lowest 20 bits *)
		ELSE h := -1;  l := -1
		END
	END NaNCodeL;

(** Returns the shifted binary exponent (0 <= e < 2048). *)
	PROCEDURE ExpoL( x: LONGREAL ): LONGINT;
	VAR i: LONGINT;
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, i );  RETURN ASH( i, -20 ) MOD 2048
	END ExpoL;

(** Convert hexadecimal to LONGREAL. h and l are the high and low parts.*)
	PROCEDURE RealL( h, l: LONGINT ): LONGREAL;
	VAR x: LONGREAL;
	BEGIN
		SYSTEM.PUT( ADDRESSOF( x ) + H, h );  SYSTEM.PUT( ADDRESSOF( x ) + L, l );  RETURN x
	END RealL;

(** Returns 10^e (e <= 308, 308 < e delivers IEEE-code +INF). *)
	PROCEDURE Ten( e: LONGINT ): LONGREAL;   (* naiive version *)
	VAR r: LONGREAL;
	BEGIN
		IF e < -307 THEN RETURN 0
		ELSIF 308 < e THEN RETURN RealL( 2146435072, 0 )
		END;
		r := 1;
		WHILE (e > 0) DO r := r * 10;  DEC( e );  END;
		WHILE (e < 0) DO r := r / 10;  INC( e );  END;
		RETURN r;
	END Ten;

	PROCEDURE InitHL;
	VAR i: ADDRESS;  dmy: INTEGER;  littleEndian: BOOLEAN;
	BEGIN
		dmy := 1;  i := ADDRESSOF( dmy );
		SYSTEM.GET( i, littleEndian );   (* indirection via i avoids warning on SUN cc -O *)
		IF littleEndian THEN H := 4;  L := 0 ELSE H := 0;  L := 4 END
	END InitHL;


BEGIN
	months := " Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec";  InitHL;
END Streams.

(**
Notes:
o	Any single buffer instance must not be accessed by more than one process concurrently.
o 	The interface is blocking (synchronous).  If an output buffer is full, it is written with a synchronous write, which returns
	only when all the data has been written.   If an input buffer is empty, it is read with a synchronous read, which only returns
	once some data has been read.  The only exception is the Available() procedure, which "peeks" at the input stream
	and returns 0 if no data is currently available.
o 	All procedures set res to the error code reported by the lower-level I/O operation (non-zero indicates error).
	 E.g. closing an underlying TCP connection will result in the Read* procedures returning a non-zero error code.
o 	res is sticky.  Once it becomes non-zero, it remains non-zero.
o 	The only way to detect end of file is to attempt to read past the end of file, which returns a non-zero error code.
o 	All output written to an erroneous buffer is ignored.
o 	The value returned when reading from an erroneous buffer is undefined, except for the Read procedure, which returns 0X.
o 	ReadBytes sets the len parameter to the number of bytes that were actually read, e.g. if size = 10, and only 8 bytes are read, len is 8.
o 	Raw format is little-endian 2's complement integers, IEEE reals and 0X-terminated strings.
o 	Syntax for ReadInt with hex = FALSE: num = ["-"] digit {digit}. digit = "0".."9".
o 	Syntax for ReadInt with hex = TRUE: ["-"] hexdigit {hexdigit} ["H"|"h"]. hexdigit = digit | "A".."F" | "a".."f".
o 	ReadInt with hex = TRUE allows "A".."F" as digits, and looks for a "H" character after the number.
	If present, the number is interpreted as hexadecimal.  If hexadecimal digits are present, but no "H" flag,
	the resulting decimal value is undefined.
o 	ReadInt ignores overflow.
o 	A Sender sends len bytes from buf at ofs to output and returns res non-zero on error.  It waits until all the data is written,
	or an error occurs.
o 	A Receiver receives up to size bytes from input into buf at ofs and returns the number of bytes read in len.
	It returns res non-zero on error.  It waits until at least min bytes (possibly zero) are available, or an error occurs.
o 	EOLN and ReadLn recognize the following end-of-line characters: CR, LF and CR/LF.
o 	To read an unstructured file token-by-token: WHILE (r.res = 0) DO SkipWhitespace; ReadToken END
o 	To read a line structured file token-by-token: WHILE r.res = 0 DO SkipSpaces; WHILE ~EOLN DO ReadToken; SkipSpaces END END
o 	A string writer is not flushed when it becomes full, but res is set to a non-zero value.
o 	Update has no effect on a string writer.
o 	GetString can be called on a string writer to return the buffer contents and reset it to empty.
o 	GetString always appends a 0X character to the buffer, but returns the true length (excluding the added 0X) in the len parameter,
	so it can also be used for binary data that includes 0X characters.
o 	Receive procedure should set res to EOF when attempting to read past the end of file.
*)


(*
to do:
o stream byte count
o read formatted data
o reads for all formatted writes
o write reals
o low-level version that can be used in kernel (below KernelLog)
*)
