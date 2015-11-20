(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE NbrStrings;   (** AUTHOR "fof"; PURPOSE "Overloaded operators for string/base-type assignments.";  **)

(* To change to 64-bit reals, change all code that is in light red. *)

IMPORT Streams, NbrInt, NbrInt8, NbrInt16, NbrInt32, NbrInt64, NbrRat, NbrRe, NbrRe64, NbrCplx;

CONST
	sIntStringLen = 5;  intStringLen = 8;  lIntStringLen = 15;  hIntStringLen = 27;  ratStringLen = 53;  reStringLen = 14;
	lReStringLen = 23;  cplxStringLen = 34;

TYPE
	String* = POINTER TO ARRAY OF CHAR;

	(** Assignment Operators *)
	PROCEDURE ":="*( VAR string: String;  x: CHAR );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < 2) THEN NEW( string, 2 );  END;
		string[0] := x;  string[1] := 0X
	END ":=";

	PROCEDURE ":="*( VAR string: String;  x: ARRAY OF CHAR );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < LEN( x )) THEN NEW( string, LEN( x ) );  END;
		COPY( x, string^ )
	END ":=";

(** String conversion for the core numeric types. *)
	PROCEDURE ":="*( VAR string: String;  x: NbrInt8.Integer );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < sIntStringLen) THEN NEW( string, sIntStringLen );  END;
		NbrInt8.IntToString( x, string^ )
	END ":=";

	PROCEDURE ":="*( VAR string: String;  x: NbrInt16.Integer );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < intStringLen) THEN NEW( string, intStringLen );  END;
		NbrInt16.IntToString( x, string^ )
	END ":=";

(**  PROCEDURE ":="*( VAR string: String;  x: NbrRe32.Integer )
	is not needed because NbrInt.Integer = NbrInt32.Integer.  *)

	PROCEDURE ":="*( VAR string: String;  x: NbrInt64.Integer );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < hIntStringLen) THEN NEW( string, hIntStringLen );  END;
		NbrInt64.IntToString( x, string^ )
	END ":=";

(**  PROCEDURE ":="*( VAR string: String;  x: NbrRe32.Real )
	is not needed because NbrRe.Real = NbrRe32.Real.  *)

	PROCEDURE ":="*( VAR string: String;  x: NbrRe64.Real );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < lReStringLen) THEN NEW( string, lReStringLen );  END;
		NbrRe64.ReToString( x, 15, string^ )
	END ":=";

(** String conversion for the base numeric types. *)
	PROCEDURE ":="*( VAR string: String;  x: NbrInt.Integer );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < lIntStringLen) THEN NEW( string, lIntStringLen );  END;
		NbrInt.IntToString( x, string^ )
	END ":=";

	PROCEDURE ":="*( VAR string: String;  x: NbrRat.Rational );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < ratStringLen) THEN NEW( string, ratStringLen );  END;
		NbrRat.RatToString( x, string^ )
	END ":=";

	PROCEDURE ":="*( VAR string: String;  x: NbrRe.Real );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < reStringLen) THEN NEW( string, reStringLen );  END;
		NbrRe.ReToString( x, 7, string^ )
	END ":=";

(** The returned string will be in Cartesian format.  To get a string in polar format use:  NbrCplx.CplxToPolarString. *)
	PROCEDURE ":="*( VAR string: String;  x: NbrCplx.Complex );
	BEGIN
		IF (string = NIL ) OR (LEN( string ) < cplxStringLen) THEN NEW( string, cplxStringLen );  END;
		NbrCplx.CplxToString( x, 7, string^ );
	END ":=";

(** String concatination *)
	PROCEDURE "+"*( l, r: String ): String;
	VAR i, j: NbrInt32.Integer;  res: String;

		PROCEDURE Copy( src: String ): String;
		BEGIN
			IF src = NIL THEN res := NIL ELSE NEW( res, LEN( src ) );  COPY( src^, res^ ) END;
			RETURN res;
		END Copy;

	BEGIN
		IF (l = NIL ) THEN RETURN Copy( r )
		ELSIF (r = NIL ) THEN RETURN Copy( l )
		ELSE
			i := 0;
			WHILE (l[i] # 0X) DO NbrInt32.Inc( i );  END;
			j := 0;
			WHILE (r[j] # 0X) DO NbrInt32.Inc( j );  NbrInt32.Inc( i );  END;
			IF (res = NIL ) OR (LEN( res ) < i + 1) THEN NEW( res, i + 1 ) END;

			i := 0;
			WHILE (l[i] # 0X) DO res[i] := l[i];  NbrInt32.Inc( i );  END;
			j := 0;
			WHILE (r[j] # 0X) DO res[i] := r[j];  NbrInt32.Inc( j );  NbrInt32.Inc( i );  END;
			res[i] := r[j];

			RETURN res;
		END;
	END "+";

	PROCEDURE "+"*( l: String;  r: CHAR ): String;
	VAR res: String;
	BEGIN
		res := r;  res := l + res;  RETURN res;
	END "+";

	PROCEDURE "+"*( l: CHAR;  r: String ): String;
	VAR res: String;
	BEGIN
		res := l;  res := res + r;  RETURN res;
	END "+";

	PROCEDURE "+"*( l: String;  r: ARRAY OF CHAR ): String;
	VAR res: String;
	BEGIN
		res := r;  res := l + res;  RETURN res;
	END "+";

	PROCEDURE "+"*( l: ARRAY OF CHAR;  r: String ): String;
	VAR res: String;
	BEGIN
		res := l;  res := res + r;  RETURN res;
	END "+";

	(* nopov *)
	(* the following procedures (operators) are not conforming to the new rules:
	
	PROCEDURE "+"*( l, r: ARRAY OF CHAR ): String;
	VAR res: String;
	BEGIN
		res := l;  res := res + r;  RETURN res;
	END "+";

(** Mixing CHAR and ARRAY OF CHAR isn't a problem since CHAR+CHAR is not defined. *)
	PROCEDURE "+"*( l: ARRAY OF CHAR;  r: CHAR ): String;
	VAR res: String;
	BEGIN
		res := l;  res := res + r;  RETURN res;
	END "+";

	PROCEDURE "+"*( l: CHAR;  r: ARRAY OF CHAR ): String;
	VAR res: String;
	BEGIN
		res := l;  res := res + r;  RETURN res;
	END "+";
	*)

(** However, do not mix Nbr and string types.  This would yield non-associative addition, e.g.,
	"Number = " + "10" + "20"  would yield "Number = 1020" instead of "Number = 30"
	Instead use "Number = " + Int(10+20)  yielding "Number = 30". *)
	PROCEDURE Int*( x: NbrInt.Integer ): String;
	VAR res: String;
	BEGIN
		res := x;  RETURN res;
	END Int;

	PROCEDURE Rat*( x: NbrRat.Rational ): String;
	VAR res: String;
	BEGIN
		res := x;  RETURN res;
	END Rat;

	PROCEDURE Re*( x: NbrRe.Real ): String;
	VAR res: String;
	BEGIN
		res := x;  RETURN res;
	END Re;

	PROCEDURE Cplx*( x: NbrCplx.Complex ): String;
	VAR res: String;
	BEGIN
		res := x;  RETURN res;
	END Cplx;

(** Persistence: file IO *)
	PROCEDURE Load*( R: Streams.Reader;  VAR x: String );
	VAR len: LONGINT;
	BEGIN
		R.RawNum( len );
		IF len < 0 THEN x := NIL
		ELSIF len = 0 THEN NEW( x, 1 );  x[0] := 0X
		ELSE NEW( x, len + 1 );  R.RawString( x^ )
		END
	END Load;

	PROCEDURE Store*( W: Streams.Writer;  x: String );
	VAR len: LONGINT;
	BEGIN
		IF x = NIL THEN W.RawNum( -1 )
		ELSE
			len := LEN( x^ );  W.RawNum( len );
			IF len > 0 THEN W.RawString( x^ ) END
		END
	END Store;

END NbrStrings.