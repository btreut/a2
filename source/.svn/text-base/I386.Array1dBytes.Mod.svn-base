(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE Array1dBytes;   (** AUTHOR "fof"; PURPOSE "Collection of all generic procedures on 1d arrays."; **)

IMPORT SYSTEM;

TYPE
	Bytes* = POINTER TO ARRAY OF SYSTEM.BYTE;
	Byte* = SYSTEM.BYTE;
	Word* = ARRAY 2 OF SYSTEM.BYTE;
	DWord* = ARRAY 4 OF SYSTEM.BYTE;
	QWord* = ARRAY 8 OF SYSTEM.BYTE;

	PROCEDURE -AdrCheck*( adr, lower, size: LONGINT );
	(** Check if lower <= adr < upper *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  upper
		MOV	EBX, [ESP+4]	;  lower
		MOV	EAX, [ESP+8]	;  adr
		CMP	EAX, EBX
		JAE	lowerok	;  offset >= adr?
		PUSH	7
		INT	3
		lowerok: ;  offset >= adr
		ADD	ECX, EBX
		CMP	EAX, ECX
		JB	upperok	;  offset < upper?
		PUSH	7
		INT	3
		upperok: ;  offset < upper
		ADD	ESP, 12	;  adjust stack pointer(inline procedure!)
	END AdrCheck;

	PROCEDURE -RangeCheck*( offset, len, upper: LONGINT );
	(** Check if  0<=offset<=offset+len<upper
		If not then  INT 3 is invoked with 7 (TRAP 7=index check fault). *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  upper
		MOV	EBX, [ESP+4]	;  len
		MOV	EAX, [ESP+8]	;  offset
		CMP	EAX, 0
		JAE	lowerok	;  offset >= 0?
		PUSH	7
		INT	3
		lowerok: ;  offset >= 0
		CMP	EBX, 0
		JAE	lenok	;  len >= 0?
		PUSH	7
		INT	3
		lenok: ;  len >= 0
		ADD	EAX, EBX
		CMP	EAX, ECX
		JBE	upperok	;  offset+len <= upper?
		PUSH	7
		INT	3
		upperok: ;  offset+len <= upper
		ADD	ESP, 12	;  adjust stack pointer(inline procedure!)
	END RangeCheck;

	PROCEDURE -RangeCheck2*( x, y, w, h, width, height: LONGINT );
	(** Range checks in 2d fields *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  upper = height
		MOV	EBX, [ESP+8]	;  len = h
		MOV	EAX, [ESP+16]	;  offset = y
		CMP	EAX, 0
		JAE	lowerok	;  offset >= 0?
		PUSH	7
		INT	3
		lowerok: ;  offset >= 0
		CMP	EBX, 0
		JAE	lenok	;  len >= 0?
		PUSH	7
		INT	3
		lenok: ;  len >= 0
		ADD	EAX, EBX
		CMP	EAX, ECX
		JBE	upperok	;  offset+len <= upper?
		PUSH	7
		INT	3
		upperok: ;  offset+len <= upper
		MOV	ECX, [ESP+4]	;  upper = width
		MOV	EBX, [ESP+12]	;  len = w
		MOV	EAX, [ESP+20]	;  offset = x
		CMP	EAX, 0
		JAE	lowerok2	;  offset >= 0?
		PUSH	7
		INT	3
		lowerok2: ;  offset >= 0
		CMP	EBX, 0
		JAE	lenok2	;  len >= 0?
		PUSH	7
		INT	3
		lenok2: ;  len >= 0
		ADD	EAX, EBX
		CMP	EAX, ECX
		JBE	upperok2	;  offset+len <= upper?
		PUSH	7
		INT	3
		upperok2: ;  offset+len <= upper
		ADD	ESP, 24	;  adjust stack pointer(inline procedure!)
	END RangeCheck2;

	PROCEDURE -PatRangeCheck*( offset, step, piecelen, pieces, upper: LONGINT );
	(** Range check for patterned procedures *)
	CODE {SYSTEM.i386}
		MOV	EDI, [ESP]	;  upper
		MOV	EDX, [ESP+4]	;  pieces
		MOV	ECX, [ESP+8]	;  piecelen
		MOV	EBX, [ESP+12]	;  step
		MOV	EAX, [ESP+16]	;  offset
		CMP	EBX, 0
		JAE	piecesok	;  pieces >= 0?
		PUSH	7
		INT	3
		piecesok: ;  pieces >= 0
		CMP	ECX, 0
		JA	piecelenok	;  piecelen > 0?
		PUSH	7
		INT	3
		piecelenok: ;  piecelen > 0
		CMP	EBX, ECX
		JAE	stepok	;  step >= piecelen?
		PUSH	7
		INT	3
		stepok: ;  step >= piecelen > 0
		CMP	EAX, 0
		JAE	lowerok	;  offset >= 0?
		PUSH	7
		INT	3
		lowerok: ;  offset >= 0
		CMP	EDX, 0
		JE	nocalc	;  pieces = 0?
		DEC	EDX
		IMUL	EDX, EBX	;  EDX := (pieces-1)*step	;
		ADD	EDX, ECX	;  INC(EDX, piecelen)
		ADD	EDX, EAX	;  INC(EDX, offset)
		nocalc:
		CMP	EDX, EDI
		JBE	upperok	;  offset+(pieces-1)*step+piecelen <= upper?
		PUSH	7
		INT	3
		upperok:
		ADD	ESP, 20	;  adjust stack pointer(inline procedure!)
	END PatRangeCheck;

	PROCEDURE -MoveB*( srcadr, destadr, len: LONGINT );
	(** Correct move if overlap, might be important for some array operations,
		do not use SYSTEM.MOVE *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  len
		MOV	EDI, [ESP+4]	;  destadr
		MOV	ESI, [ESP+8]	;  srcadr
		CMP	ESI, EDI
		JAE	moveup	;  src adr greater then dest adr, no problem with moving up
		MOV	EAX, ESI
		ADD	EAX, ECX
		CMP	EAX, EDI
		JBE	moveup	;  no overlap, no problem, move up
		MOV	ESI, EAX
		ADD	EDI, ECX
		DEC	ESI
		DEC	EDI
		STD	;  move down since overlap occured
		REP
		MOVSB
		JMP	done
		moveup:
		CLD
		MOV	BL, CL
		SHR	ECX, 2
		AND	BL, 00000003H	;  rest to move after 4 byte move
		REP
		MOVSD	;  move 4 bytes each step
		MOV	CL, BL
		REP
		MOVSB	;  move rest in one byte steps
		done:
		ADD	ESP, 12	;  adjust stack pointer(inline procedure!)
	END MoveB;

	PROCEDURE MoveBPat*( srcadr, destadr, srcstep, deststep, piecelen, pieces: LONGINT );
	(** Patterned move *)
	BEGIN
		WHILE (pieces > 0) DO MoveB( srcadr, destadr, piecelen );  INC( srcadr, srcstep );  INC( destadr, deststep );  DEC( pieces );  END;
	END MoveBPat;

	PROCEDURE FillB*( adr: LONGINT;  byte: SYSTEM.BYTE;  count: LONGINT );
	(** Memory filling for 8 bit types *)
	CODE {SYSTEM.i386}
		MOV	EDI, [EBP+adr]	;  address of dest index
		MOV	ECX, [EBP+count]	;  counter
		MOV	AL, [EBP+byte]	;  value
		CLD	;  incremental
		REP
		STOSB
	END FillB;

	PROCEDURE FillBPat*( adr: LONGINT;  byte: SYSTEM.BYTE;  step, piecelen, pieces: LONGINT );
	(** Patterned filling for 8 bit types *)
	CODE {SYSTEM.i386}
		MOV	ESI, [EBP+adr]	;  address of dest index
		MOV	AL, [EBP+byte]	;  value
		MOV	EBX, [EBP+step]
		MOV	EDX, [EBP+pieces]
		JMP	until
		repeat:
		DEC	EDX
		MOV	ECX, [EBP+piecelen]
		MOV	EDI, ESI
		REP
		STOSB
		ADD	ESI, EBX
		until:
		CMP	EDX, 0
		JNLE	repeat
	END FillBPat;

	PROCEDURE FillW*( adr: LONGINT;  word: Word;  count: LONGINT );
	(** For 16 bit types *)
	CODE {SYSTEM.i386}
		MOV	EDI, [EBP+adr]	;  address of dest index
		MOV	ECX, [EBP+count]	;  counter
		MOV	AX, [EBP+word]	;  value
		CLD	;  incremental
		REP
		STOSW
	END FillW;

	PROCEDURE FillWPat*( adr: LONGINT;  word: Word;  step, piecelen, pieces: LONGINT );
	(** For 16 bit types *)
	CODE {SYSTEM.i386}
		MOV	ESI, [EBP+adr]	;  address of dest index
		MOV	AX, [EBP+word]	;  value
		MOV	EBX, [EBP+step]
		MOV	EDX, [EBP+pieces]
		JMP	until
		repeat:
		DEC	EDX
		MOV	ECX, [EBP+piecelen]
		MOV	EDI, ESI
		REP
		STOSW
		ADD	ESI, EBX
		until:
		CMP	EDX, 0
		JNLE	repeat
	END FillWPat;

	PROCEDURE FillD*( adr: LONGINT;  dword: DWord;  count: LONGINT );
	(** For 32 bit types *)
	CODE {SYSTEM.i386}
		MOV	EDI, [EBP+adr]	;  address of dest index
		MOV	ECX, [EBP+count]	;  counter
		MOV	EAX, [EBP+dword]	;  value
		CLD	;  incremental
		REP
		STOSD
	END FillD;

	PROCEDURE FillDPat*( adr: LONGINT;  dword: DWord;  step, piecelen, pieces: LONGINT );
	(** For 32 bit types *)
	CODE {SYSTEM.i386}
		MOV	ESI, [EBP+adr]	;  address of dest index
		MOV	EAX, [EBP+dword]	;  value
		MOV	EBX, [EBP+step]
		MOV	EDX, [EBP+pieces]
		JMP	until
		repeat:
		DEC	EDX
		MOV	ECX, [EBP+piecelen]
		MOV	EDI, ESI
		REP
		STOSD
		ADD	ESI, EBX
		until:
		CMP	EDX, 0
		JNLE	repeat
	END FillDPat;

	PROCEDURE FillQ*( adr: LONGINT;  qword: QWord;  count: LONGINT );
	(** For 64 bit types  *)
	CODE {SYSTEM.i386, SYSTEM.FPU, SYSTEM.Pentium, SYSTEM.MMX}
		MOV	EAX, 1
		CPUID	;  check cpu
		TEST	EDX, 00800000H	;  does the cpu support mmx extensions?
		JNZ	mmxfound	;  yes, goto mmx found
		MOV	ECX, [EBP+count]
		MOV	EDI, [EBP+adr]
		SHL	ECX, 3
		ADD	ECX, EDI
		LEA	EAX, [EBP+12] ; 12 <-> qword
		MOV	EBX, [EAX]	;  double word part one
		MOV	EDX, [EAX+4]	;  double word part two
		JMP	until
		repeat:
		MOV	EAX, EBX
		STOSD
		MOV	EAX, EDX
		STOSD
		until:
		CMP	EDI, ECX
		JL	repeat	;
		JMP	end
		mmxfound: ;  mmx support
		MOV	ECX, [EBP+count]
		MOV	EDI, [EBP+adr]
		SHL	ECX, 3
		ADD	ECX, EDI
		MOVQ	MMX0, [EBP+qword]
		JMP	until2
		repeat2:
		MOVQ	[EDI], MMX0
		ADD	EDI, 8
		until2:
		CMP	EDI, ECX
		JL	repeat2	;
		end:
	END FillQ;

	PROCEDURE FillG*( adr: LONGINT;  VAR data: ARRAY OF SYSTEM.BYTE;  count: LONGINT );
	(** For geneirc types, slower than Fill[B|W|D|Q] *)
	CODE {SYSTEM.i386}
		MOV	EDI, [EBP+adr]
		MOV	EBX, [EBP+data]
		MOV	EAX, [EBP+count]
		JMP	until
		repeat:
		MOV	ESI, EBX
		MOV	ECX, [EBP+16]	;  LEN(data)
		CLD	;  incremental
		REP
		MOVSB
		DEC	EAX
		until:
		CMP	EAX, 0
		JA	repeat
	END FillG;

	PROCEDURE FillGPat*( adr: LONGINT;  VAR data: ARRAY OF SYSTEM.BYTE;  step, piecelen, pieces: LONGINT );
	(** for generic types, slower than Fill[B|W|D|Q]Pat *)
	CODE {SYSTEM.i386}
		MOV	EBX, [EBP+adr]
		MOV	EDX, [EBP+pieces]
		JMP	untilpieces
		repeatpieces: ;  WHILE pieces > 0 DO
		MOV	EAX, [EBP+piecelen]
		JMP	untilpiecelen
		repeatpiecelen: ;  WHILE piecelen > 0 DO
		MOV	EDI, EBX
		MOV	ESI, [EBP+data]
		MOV	ECX, [EBP+24]	;  LEN(data)
		CLD	;  incremental
		REP
		MOVSB
		untilpiecelen:
		CMP	EAX, 0
		JA	repeatpiecelen	;  end
		untilpieces:
		CMP	EBX, 0
		JA	repeatpieces	;  end
	END FillGPat;

	PROCEDURE Fill*( adr: LONGINT;  VAR data: ARRAY OF SYSTEM.BYTE;  len: LONGINT );
	(** Fill memory [adr, adr+len LEN(data)] with data *)
	BEGIN
		IF LEN( data ) = 1 THEN FillB( adr, data[0], len )
		ELSIF LEN( data ) = 2 THEN FillW( adr, SYSTEM.VAL( Word, data ), len )
		ELSIF LEN( data ) = 4 THEN FillD( adr, SYSTEM.VAL( DWord, data ), len )
		ELSIF LEN( data ) = 8 THEN FillQ( adr, SYSTEM.VAL( QWord, data ), len )
		ELSE FillG( adr, data, len )
		END;
	END Fill;

	PROCEDURE FillPat*( adr: LONGINT;  VAR data: ARRAY OF SYSTEM.BYTE;  step, piecelen, pieces: LONGINT );
	(** Fill memory [adr, adr+step pieces] with data,  patterned *)
	BEGIN
		IF LEN( data ) = 1 THEN FillBPat( adr, data[0], step, piecelen, pieces )
		ELSIF LEN( data ) = 2 THEN FillWPat( adr, SYSTEM.VAL( Word, data ), step, piecelen, pieces )
		ELSIF LEN( data ) = 4 THEN FillDPat( adr, SYSTEM.VAL( DWord, data ), step, piecelen, pieces )
		ELSE FillGPat( adr, data, step, piecelen, pieces )
		END;
	END FillPat;

END Array1dBytes.

Decoder.Decode Array1dBytes.Obj ~
System.Free Array1dBytes  ~
Array1dBytes.Test ~











(**************************** testing ********************************)

	PROCEDURE FillCharPat*( VAR a: ARRAY OF CHAR;  c: CHAR;  offset, step, piecelen, pieces: LONGINT );
	VAR i, j: LONGINT;
	BEGIN
		WHILE (pieces > 0) DO
			i := offset;  j := offset + piecelen;
			WHILE (i < j) DO a[i] := c;  INC( i );  END;
			INC( offset, step );  DEC( pieces );
		END;
	END FillCharPat;

	PROCEDURE FillInt( VAR a: ARRAY OF INTEGER;  i: INTEGER );
	CODE {SYSTEM.i386}

		MOV	EDI, a[EBP] (* address of array in destination index*)
		MOV	ECX, 16[EBP] (* len of array in ECX *)
		MOV	AX, i[EBP] (* ax := i *)

		CLD (* incremental *)
		REP (* repeat incrementing dest index ECX times *)
		STOSW (* store word in ax to destination *)
	END FillInt;

	PROCEDURE FillInt2( VAR a: ARRAY OF INTEGER;  i: INTEGER );   (* nearly same speed as FillInt *)
	BEGIN
		FillW( ADDRESSOF( a ), SYSTEM.VAL( Word, i ), LEN( a ) );
	END FillInt2;

	PROCEDURE Test1( a: QWord );
	VAR adr: LONGINT;
	BEGIN
		adr := ADDRESSOF( a );
	END Test1;

	PROCEDURE Test2( a: LONGREAL );
	VAR adr: LONGINT;
	BEGIN
		adr := ADDRESSOF( a );
	END Test2;

(* Operator procedures *)

	PROCEDURE NegateR;
	VAR x: REAL;
	BEGIN
		x := -x;
	END NegateR;

	PROCEDURE NegateL;
	VAR x: LONGINT;
	BEGIN
		x := -x;
	END NegateL;


	PROCEDURE Do1( op: PROCEDURE;  adr: LONGINT;  len, size: LONGINT );
	CODE {SYSTEM.i386}
		MOV	EDI, adr[EBP]
		MOV	ECX, op[EBP]
		MOV	EBX, len[EBP]
		JMP	until
		repeat:
		MOV	EAX, [EDI]
		CALL	ECX
		MOV	[EDI], EAX
		ADD	EDI, EDX
		DEC	EBX
		until:
		CMP	EBX, 0
		JA	repeat
	END Do1;

TYPE
	QRec = RECORD
		a1, a2, a3, a4, a5, a6, a7, a8: SYSTEM.BYTE
	END;

	PROCEDURE Test3( a: QRec );
	VAR adr: LONGINT;
	BEGIN
		adr := ADDRESSOF( a );
	END Test3;

	PROCEDURE Test4( VAR a: ARRAY OF SYSTEM.BYTE );
	VAR adr: LONGINT;
	BEGIN
		adr := ADDRESSOF( a );
	END Test4;

	PROCEDURE CallTest*;
	VAR a: QWord;  b: LONGREAL;  c: QRec;  time, i: LONGINT;
	BEGIN
		time := Oberon.Time();
		FOR i := 0 TO 10000000 DO Test1( a );  END;
		Out.Int( Oberon.Time() - time, 10 );  Out.Ln;  time := Oberon.Time();
		FOR i := 0 TO 10000000 DO

			Test2( b );
		END;
		Out.Int( Oberon.Time() - time, 10 );  Out.Ln;  time := Oberon.Time();
		FOR i := 0 TO 10000000 DO

			Test3( c );
		END;
		Out.Int( Oberon.Time() - time, 10 );  Out.Ln;  time := Oberon.Time();
		FOR i := 0 TO 10000000 DO Test4( b );  END;
		Out.Int( Oberon.Time() - time, 10 );  Out.Ln;

	END CallTest;

(* Array1dBytes.CallTest *)

	PROCEDURE CallFIllQ;
	VAR b: QWord;
	BEGIN
		FillQ( 123, b, 456 );
	END CallFIllQ;

	PROCEDURE Test*;
	VAR a, b, c: Bytes;  len, i, time, low, high, overlap: LONGINT;  word: Word;  longreal: LONGREAL;
		longreals: POINTER TO ARRAY OF LONGREAL;

		PROCEDURE TMove;
		CONST maxlen = 1000000;  maxtries = 100000;  minlen = 100;
		BEGIN
			len := minlen;
			WHILE (len < maxlen) DO
				NEW( a, 2 * len );  NEW( b, 2 * len );
				IF ADDRESSOF( a[0] ) < ADDRESSOF( b[0] ) THEN
					low := ADDRESSOF( a[0] );  high := ADDRESSOF( b[0] );  overlap := ADDRESSOF( a[len DIV 2] );
				ELSE low := ADDRESSOF( b[0] );  high := ADDRESSOF( a[0] );  overlap := ADDRESSOF( b[len DIV 2] );
				END;
				time := Oberon.Time();
				FOR i := 1 TO maxtries DO MoveB( low, high, len );  END;
				time := Oberon.Time() - time;  Out.String( "Measuring up, len=" );  Out.Int( len, 10 );
				Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
				time := Oberon.Time();
				FOR i := 1 TO maxtries DO MoveB( high, low, len );  END;
				time := Oberon.Time() - time;  Out.String( "Measuring down, len=" );  Out.Int( len, 10 );
				Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
				time := Oberon.Time();
				FOR i := 1 TO maxtries DO MoveB( low, overlap, len );  END;
				time := Oberon.Time() - time;  Out.String( "Measuring overlapped up, len=" );  Out.Int( len, 10 );
				Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
				time := Oberon.Time();
				FOR i := 1 TO maxtries DO MoveB( overlap, low, len );  END;
				time := Oberon.Time() - time;  Out.String( "Measuring overlapped down, len=" );  Out.Int( len, 10 );
				Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
				time := Oberon.Time();
				FOR i := 1 TO maxtries DO SYSTEM.MOVE( high, low, len );  END;
				time := Oberon.Time() - time;  Out.String( "Measuring SYSTEM.MOVE, len=" );  Out.Int( len, 10 );
				Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
				len := len * 10;
			END;
		END TMove;

		PROCEDURE FillArray( VAR a: ARRAY OF LONGREAL;  val: LONGREAL;  len: LONGINT );
		BEGIN
			WHILE (len > 0) DO DEC( len );  a[len] := val;  END;
		END FillArray;

		PROCEDURE TFill;
		CONST maxtries = 1000;  maxlen = 100000;
		VAR ints: POINTER TO ARRAY OF INTEGER;
			longreals: POINTER TO ARRAY OF LONGREAL;
			chars: POINTER TO ARRAY OF CHAR;
			int: INTEGER;  r: LONGREAL;
		BEGIN
			(*
			NEW( longreals, 256 );  longreal := 1.23456789E-20;
			FillQWord( ADDRESSOF( longreals[0] ), SYSTEM.VAL( QWord, longreal ), LEN( longreals ) );
			FOR i := 0 TO LEN( longreals ) - 1 DO
				Out.String( "Fillsuccess?:" );  Out.Int( i, 10 );  Out.String( " , " );  Out.LongReal( longreals[i], 20 );  Out.Ln;
			END;
			NEW( ints, maxlen );  r := 10;  time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillArray( ints^, r, maxlen ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring up, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillQWord( ADDRESSOF( ints[0] ), SYSTEM.VAL( QWord, r ), maxlen ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring down, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();
			*)
			NEW( longreals, maxlen );  r := 10;  time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillArray( longreals^, r, maxlen ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring up, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();

			FOR i := 1 TO maxtries DO FillQ( ADDRESSOF( longreals[0] ), SYSTEM.VAL( QWord, r ), maxlen ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring down, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();

			(*
			NEW( ints, maxlen );  int := 10;  time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillInt( ints^, int ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring up, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillInt2( ints^, int ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring down, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();
			*)
			NEW( chars, 200 );  FillB( ADDRESSOF( chars[0] ), "-", LEN( chars ) );
			FillBPat( ADDRESSOF( chars[0] ), "c", 6, 5, 10 );  Out.String( "chars=" );
			FOR i := 0 TO LEN( chars ) - 1 DO Out.Char( chars[i] );  END;
			Out.Ln;

			NEW( chars, maxlen );  time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillCharPat( chars^, "c", 0, 20, 1, maxlen DIV 20 - 1 ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring up, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();
			FOR i := 1 TO maxtries DO FillBPat( ADDRESSOF( chars[0] ), "c", 20, 1, maxlen DIV 20 - 1 ) END;
			time := Oberon.Time() - time;  Out.String( "Measuring down, len=" );  Out.Int( len, 10 );
			Out.String( ", time=" );  Out.Int( time, 10 );  Out.Ln;   (**)
			time := Oberon.Time();

		END TFill;

	BEGIN
		TMove;
		(*
		TFill;
		*)
	END Test;
