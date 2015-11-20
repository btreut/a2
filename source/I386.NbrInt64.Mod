(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrInt64;   (** AUTHOR "prk & adf"; PURPOSE "MathH with name changes to avoid basic-type conflicts."; *)

IMPORT SYSTEM, NbrInt8, NbrInt16, NbrInt32, Streams;

TYPE
	(** A 64-bit integer type. *)
	Integer* = RECORD
		low, hi: NbrInt32.Integer
	END;

VAR
	MinNbr-, MaxNbr-, One, Two: Integer;

CONST
	(* CC of the FPU-Status Word *)
	Eq = 4000H;  Lt = 100H;  Gt = 000H;

	PROCEDURE -Compare( ): NbrInt32.Integer;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		FILD	QWORD [EBP+8]	;  b- > ST(1)
		FILD	QWORD [EBP+16]	;  a- > ST(0)
		FCOMPP
		DB	9BH, 0DFH, 0E0H	;  FSTSW AX
		AND	EAX, 4500H	;  use c3, c2, c0
	END Compare;

(** Comparison Operators*)
	PROCEDURE ">"*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() = Gt
	END ">";

	PROCEDURE ">"*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a > Long( b )
	END ">";

	PROCEDURE ">"*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a > Long( NbrInt32.Long( b ) )
	END ">";

	PROCEDURE ">"*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a > Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END ">";

	PROCEDURE ">"*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) > b
	END ">";

	PROCEDURE ">"*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) > b
	END ">";

	PROCEDURE ">"*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) > b
	END ">";

	PROCEDURE ">="*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() # Lt
	END ">=";

	PROCEDURE ">="*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a >= Long( b )
	END ">=";

	PROCEDURE ">="*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a >= Long( NbrInt32.Long( b ) )
	END ">=";

	PROCEDURE ">="*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a >= Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END ">=";

	PROCEDURE ">="*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) >= b
	END ">=";

	PROCEDURE ">="*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) >= b
	END ">=";

	PROCEDURE ">="*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) >= b
	END ">=";

	PROCEDURE "<"*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() = Lt
	END "<";

	PROCEDURE "<"*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a < Long( b )
	END "<";

	PROCEDURE "<"*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a < Long( NbrInt32.Long( b ) )
	END "<";

	PROCEDURE "<"*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a < Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "<";

	PROCEDURE "<"*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) < b
	END "<";

	PROCEDURE "<"*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) < b
	END "<";

	PROCEDURE "<"*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) < b
	END "<";

	PROCEDURE "<="*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() # Gt
	END "<=";

	PROCEDURE "<="*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a <= Long( b )
	END "<=";

	PROCEDURE "<="*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a <= Long( NbrInt32.Long( b ) )
	END "<=";

	PROCEDURE "<="*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a <= Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "<=";

	PROCEDURE "<="*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) <= b
	END "<=";

	PROCEDURE "<="*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) <= b
	END "<=";

	PROCEDURE "<="*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) <= b
	END "<=";

	PROCEDURE "="*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() = Eq
	END "=";

	PROCEDURE "="*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a = Long( b )
	END "=";

	PROCEDURE "="*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a = Long( NbrInt32.Long( b ) )
	END "=";

	PROCEDURE "="*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a = Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "=";

	PROCEDURE "="*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) = b
	END "=";

	PROCEDURE "="*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) = b
	END "=";

	PROCEDURE "="*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) = b
	END "=";

	PROCEDURE "#"*( a, b: Integer ): BOOLEAN;
	BEGIN
		RETURN Compare() # Eq
	END "#";

	PROCEDURE "#"*( a: Integer;  b: NbrInt32.Integer ): BOOLEAN;
	BEGIN
		RETURN a # Long( b )
	END "#";

	PROCEDURE "#"*( a: Integer;  b: NbrInt16.Integer ): BOOLEAN;
	BEGIN
		RETURN a # Long( NbrInt32.Long( b ) )
	END "#";

	PROCEDURE "#"*( a: Integer;  b: NbrInt8.Integer ): BOOLEAN;
	BEGIN
		RETURN a # Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "#";

	PROCEDURE "#"*( a: NbrInt32.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( a ) # b
	END "#";

	PROCEDURE "#"*( a: NbrInt16.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) # b
	END "#";

	PROCEDURE "#"*( a: NbrInt8.Integer;  b: Integer ): BOOLEAN;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) # b
	END "#";

(** Monadic Arithmetic Operators*)
	PROCEDURE "-"*( a: Integer ): Integer;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		MOV	EAX, [EBP+12]
		MOV	EBX, [EBP+8]
		MOV	EDX, [EBP+16]
		NEG	EAX
		NEG	EBX
		SBB	EAX, 0
		MOV	[EDX+4], EAX
		MOV	[EDX], EBX
	END "-";

(** Dyadic Assignment Operators *)
	PROCEDURE ":="*( VAR a: Integer;  b: NbrInt32.Integer );
	BEGIN
		a := Long( b )
	END ":=";

	PROCEDURE ":="*( VAR a: Integer;  b: NbrInt16.Integer );
	BEGIN
		a := Long( NbrInt32.Long( b ) )
	END ":=";

	PROCEDURE ":="*( VAR a: Integer;  b: NbrInt8.Integer );
	BEGIN
		a := Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END ":=";

	(** Dyadic Arithmetic Operators*)
(*ASM Version *)
	PROCEDURE "+"*( a, b: Integer ): Integer;
	CODE {SYSTEM.i386}
		MOV	EAX, [EBP+16]
		MOV	EBX, [EBP+20]
		MOV	EDX, [EBP+24]
		ADD	EAX, [EBP+8]
		ADC	EBX, [EBP+12]
		MOV	[EDX+0], EAX
		MOV	[EDX+4], EBX
	END "+";

	PROCEDURE "+"*( a: Integer;  b: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN a + Long( b )
	END "+";

	PROCEDURE "+"*( a: Integer;  b: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN a + Long( NbrInt32.Long( b ) )
	END "+";

	PROCEDURE "+"*( a: Integer;  b: NbrInt8.Integer ): Integer;
	BEGIN
		RETURN a + Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "+";

	PROCEDURE "+"*( a: NbrInt32.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( a ) + b
	END "+";

	PROCEDURE "+"*( a: NbrInt16.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) + b
	END "+";

	PROCEDURE "+"*( a: NbrInt8.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) + b
	END "+";

(* ASM Version*)
	PROCEDURE "-"*( a, b: Integer ): Integer;
	CODE {SYSTEM.i386}
		MOV	EAX, [EBP+16]
		MOV	EBX, [EBP+20]
		MOV	EDX, [EBP+24]
		SUB	EAX, [EBP+8]
		SBB	EBX, [EBP+12]
		MOV	[EDX+0], EAX
		MOV	[EDX+4], EBX
	END "-";

	PROCEDURE "-"*( a: Integer;  b: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN a - Long( b )
	END "-";

	PROCEDURE "-"*( a: Integer;  b: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN a - Long( NbrInt32.Long( b ) )
	END "-";

	PROCEDURE "-"*( a: Integer;  b: NbrInt8.Integer ): Integer;
	BEGIN
		RETURN a - Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "-";

	PROCEDURE "-"*( a: NbrInt32.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( a ) - b
	END "-";

	PROCEDURE "-"*( a: NbrInt16.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) - b
	END "-";

	PROCEDURE "-"*( a: NbrInt8.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) - b
	END "-";

	PROCEDURE "*"*( a, b: Integer ): Integer;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		FILD	QWORD [EBP+a]
		FILD	QWORD [EBP+b]
		FMULP
		MOV	EAX, [EBP+24]
		FISTP	QWORD[EAX]
		FWAIT
	END "*";

	PROCEDURE "*"*( a: Integer;  b: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN a * Long( b )
	END "*";

	PROCEDURE "*"*( a: Integer;  b: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN a * Long( NbrInt32.Long( b ) )
	END "*";

	PROCEDURE "*"*( a: Integer;  b: NbrInt8.Integer ): Integer;
	BEGIN
		RETURN a * Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "*";

	PROCEDURE "*"*( a: NbrInt32.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( a ) * b
	END "*";

	PROCEDURE "*"*( a: NbrInt16.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) * b
	END "*";

	PROCEDURE "*"*( a: NbrInt8.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) * b
	END "*";

	PROCEDURE "DIV"*( a, b: Integer ): Integer;
	VAR cw, cw0: INTEGER;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		MOV	EAX, [EBP+12]	;  b must be positive(check msb)
		CMP	EAX, 0
		JGE	ok
		PUSH	8	;  ASSERT Trap
		INT	3
		ok:
		FNCLEX
		FSTCW	[EBP+cw]
		MOV	[EBP+cw0], 077AH	;  rounding to-infty, allow zero divide, invalid operation
		FLDCW	[EBP+cw0]	;  set rounding to 01, round down
		FILD	QWORD [EBP+a]
		FILD	QWORD [EBP+b]
		FDIVP
		MOV	EAX, [EBP+24]
		FISTP	QWORD[EAX]
		FLDCW	[EBP+cw]	;  reset rounding
		FWAIT
	END "DIV";

	PROCEDURE "DIV"*( a: Integer;  b: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN a DIV Long( b )
	END "DIV";

	PROCEDURE "DIV"*( a: Integer;  b: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN a DIV Long( NbrInt32.Long( b ) )
	END "DIV";

	PROCEDURE "DIV"*( a: Integer;  b: NbrInt8.Integer ): Integer;
	BEGIN
		RETURN a DIV Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "DIV";

	PROCEDURE "DIV"*( a: NbrInt32.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( a ) DIV b
	END "DIV";

	PROCEDURE "DIV"*( a: NbrInt16.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) DIV b
	END "DIV";

	PROCEDURE "DIV"*( a: NbrInt8.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) DIV b
	END "DIV";

	PROCEDURE "MOD"*( a, b: Integer ): Integer;
	VAR cw, cw0: INTEGER;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		MOV	EAX, [EBP+12]	;  b must be positive(check msb)
		CMP	EAX, 0
		JGE	ok
		PUSH	8	;  ASSERT Trap
		INT	3
		ok:
		FNCLEX
		FSTCW	[EBP+cw]
		MOV	[EBP+cw0], 077FH	;  was 77AH- > wrong because zero is not an exception here
		FLDCW	[EBP+cw0]	;  set rounding to 01, round down, mask exceptions
		FILD	QWORD [EBP+a]
		FILD	QWORD [EBP+b]
		FILD	QWORD [EBP+b]
		FDIVR	ST0, ST2	;  ST(0) := a DIV b = ST(2) DIV ST(0)
		FRNDINT
		FMULP
		FSUBP
		MOV	EAX, [EBP+24]
		FISTP	QWORD[EAX]
		FLDCW	[EBP+cw]	;  reset rounding
		FWAIT
	END "MOD";

	PROCEDURE "MOD"*( a: Integer;  b: NbrInt32.Integer ): Integer;
	BEGIN
		RETURN a MOD Long( b )
	END "MOD";

	PROCEDURE "MOD"*( a: Integer;  b: NbrInt16.Integer ): Integer;
	BEGIN
		RETURN a MOD Long( NbrInt32.Long( b ) )
	END "MOD";

	PROCEDURE "MOD"*( a: Integer;  b: NbrInt8.Integer ): Integer;
	BEGIN
		RETURN a MOD Long( NbrInt32.Long( NbrInt16.Long( b ) ) )
	END "MOD";

	PROCEDURE "MOD"*( a: NbrInt32.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( a ) MOD b
	END "MOD";

	PROCEDURE "MOD"*( a: NbrInt16.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( a ) ) MOD b
	END "MOD";

	PROCEDURE "MOD"*( a: NbrInt8.Integer;  b: Integer ): Integer;
	BEGIN
		RETURN Long( NbrInt32.Long( NbrInt16.Long( a ) ) ) MOD b
	END "MOD";

(** Basic functions*)
	PROCEDURE AbsVal( a: Integer ): Integer;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		FILD	QWORD [EBP+a]
		FABS
		MOV	EAX, [EBP+16]
		FISTP	QWORD[EAX]
		FWAIT
	END AbsVal;

	PROCEDURE Abs*( a: Integer ): Integer;
	BEGIN
		IF a > MinNbr THEN RETURN AbsVal( a ) ELSE RETURN a END
	END Abs;

	PROCEDURE Dec*( VAR a: Integer );
	BEGIN
		IF a > MinNbr THEN
			IF a.low = 0 THEN a.hi := a.hi - 1 END;
			a.low := a.low - 1
		END
	END Dec;

	PROCEDURE Inc*( VAR a: Integer );
	BEGIN
		IF a < MaxNbr THEN
			IF a.low = -1 THEN a.hi := a.hi + 1 END;
			a.low := a.low + 1
		END
	END Inc;

	PROCEDURE Odd*( a: Integer ): BOOLEAN;
	BEGIN
		RETURN (a MOD Two) = One
	END Odd;

	PROCEDURE Long*( i: NbrInt32.Integer ): Integer;
	CODE {SYSTEM.i386}
		MOV	EAX, [EBP+i]
		CDQ
		MOV	EBX, [EBP+12]
		MOV	[EBX+0], EAX
		MOV	[EBX+4], EDX
	END Long;

	PROCEDURE IsInt32*( i: Integer ): BOOLEAN;
	BEGIN
		IF (i >= NbrInt32.MinNbr) & (i <= NbrInt32.MaxNbr) THEN RETURN TRUE ELSE RETURN FALSE END
	END IsInt32;

	PROCEDURE Short*( h: Integer ): NbrInt32.Integer;
	BEGIN
		RETURN h.low
	END Short;

	PROCEDURE Max*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 > x2 THEN RETURN x1 ELSE RETURN x2 END
	END Max;

	PROCEDURE Min*( x1, x2: Integer ): Integer;
	BEGIN
		IF x1 < x2 THEN RETURN x1 ELSE RETURN x2 END
	END Min;

	PROCEDURE Sign*( x: Integer ): NbrInt8.Integer;
	VAR sign: NbrInt8.Integer;
	BEGIN
		IF x < 0 THEN sign := -1
		ELSIF x = 0 THEN sign := 0
		ELSE sign := 1
		END;
		RETURN sign
	END Sign;

	(** String conversions. *)
(** Admissible characters include: {" ", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ","}. *)
	PROCEDURE StringToInt*( string: ARRAY OF CHAR;  VAR x: Integer );
	VAR negative: BOOLEAN;  i: NbrInt8.Integer;
	BEGIN
		i := 0;
		(* Pass over any leading white space. *)
		WHILE string[i] = CHR( 20H ) DO NbrInt8.Inc( i ) END;
		(* Determine the sign. *)
		IF string[i] = CHR( 2DH ) THEN negative := TRUE;  NbrInt8.Inc( i ) ELSE negative := FALSE END;
		(* Read in the string and convert it into an integer. *)
		x := 0;
		WHILE string[i] # 0X DO
			IF (CHR( 30H ) <= string[i]) & (string[i] <= CHR( 39H )) THEN x := 10 * x + LONG( ORD( string[i] ) - 30H )
			ELSE
				(* Inadmissible character - it is skipped. *)
			END;
			NbrInt8.Inc( i )
		END;
		IF negative THEN x := -x END
	END StringToInt;

(** LEN(string) >= 27 *)
	PROCEDURE IntToString*( x: Integer;  VAR string: ARRAY OF CHAR );
	VAR positive: BOOLEAN;  i, k: NbrInt8.Integer;
		a: ARRAY 21 OF CHAR;
	BEGIN
		IF x > MinNbr THEN
			(* Determine the sign. *)
			IF x < 0 THEN x := -x;  positive := FALSE ELSE positive := TRUE END;
			(* Convert the integer into a string. *)
			WHILE x > 0 DO a[i] := CHR( Short( x MOD 10 ) + 30H );  x := x DIV 10;  NbrInt8.Inc( i ) END;
			(* Test for zero. *)
			IF i = 0 THEN a[0] := CHR( 30H );  NbrInt8.Inc( i ) END;
			(* Terminate the string. *)
			a[i] := 0X;  k := 0;
			IF ~positive THEN
				(* Write a minus sign. *)
				string[k] := CHR( 2DH );  NbrInt8.Inc( k )
			END;
			(* Rewrite the string in a formatted output, inverting the order stored in a[i]. *)
			REPEAT
				NbrInt8.Dec( i );  string[k] := a[i];  NbrInt8.Inc( k );
				IF (i > 0) & ((i MOD 3) = 0) THEN
					(* Write a comma. *)
					string[k] := CHR( 2CH );  NbrInt8.Inc( k )
				END
			UNTIL i = 0;
			string[k] := 0X
		ELSE COPY( "-9,223,372,036,854,775,808", string )
		END
	END IntToString;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: Integer );
	BEGIN
		NbrInt32.Load( R, x.low );  NbrInt32.Load( R, x.hi )
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: Integer );
	BEGIN
		NbrInt32.Store( W, x.low );  NbrInt32.Store( W, x.hi )
	END Store;

BEGIN
	MinNbr.low := 0;  MinNbr.hi := LONGINT(80000000H);  MaxNbr.low :=LONGINT( 0FFFFFFFFH);  MaxNbr.hi :=LONGINT( 7FFFFFFFH);  One := Long( 1 );
	Two := Long( 2 )
END NbrInt64.